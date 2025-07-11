module SugarscapeLLM

###############################################################################
# LLM integration scaffold                                                   #
#                                                                            #
# This file provides non-intrusive helper utilities for retrieving decisions #
# from an OpenAI-compatible endpoint and caching them on the Sugarscape      #
# `model`.                                                                   #
#                                                                            #
# Individual agent decision-making implementation.                           #
###############################################################################

using HTTP, JSON, Logging, OpenAI
using ..Agents: nearby_positions, nearby_agents, allagents, isempty

# Parent module alias for convenience
import ..Sugarscape

# Import prompts and schemas
using ..SugarscapePrompts

# Add time function for metrics
import Base: time

############################### Error Types ################################

"""
LLM integration error types for strict error handling when use_llm_decisions=true.
All errors should propagate up to stop the simulation for research integrity.
"""
struct LLMAPIError <: Exception
  message::String
  status_code::Union{Int,Nothing}
  response_body::Union{String,Nothing}
end

struct LLMSchemaError <: Exception
  message::String
  agent_id::Union{Int,Nothing}
  raw_response::Union{Any,Nothing}
end

struct LLMValidationError <: Exception
  message::String
  field::String
  value::Any
  agent_id::Union{Int,Nothing}
end

struct LLMResearchIntegrityError <: Exception
  message::String
  agent_id::Union{Int,Nothing}
  context::String
end

"""
    build_agent_context(agent, model) -> Dict
Collect a lightweight JSON-serialisable summary of the local state that the LLM
can use to decide on the agent's next actions.  The schema is intentionally kept
stable so tests that rely on it do not break when the runtime model evolves.
"""
function build_agent_context(agent, model)
  # Visible lattice positions with sugar (or welfare when pollution enabled)
  visible_positions = Vector{Any}()

  # Use the same nearby_positions logic as movement! to ensure consistency
  for (pos, value, distance) in Sugarscape.evaluate_nearby_positions(agent, model)
    push!(visible_positions, Dict(
      "position" => pos,
      "value" => value,
      "distance" => distance,
      "occupied" => !isempty(pos, model),
    ))
  end

  @info id = agent.id "visible_positions: $(visible_positions)"

  # Immediate neighbours (Moore radius 1)
  neighbours = Vector{Any}()
  for nb in nearby_agents(agent, model, 1)
    push!(neighbours, Dict(
      "id" => nb.id,
      "sugar" => nb.sugar,
      "age" => nb.age,
      "sex" => nb.sex,
    ))
  end

  return Dict(
    "agent_id" => agent.id,
    "position" => agent.pos,
    "sugar" => agent.sugar,
    "age" => agent.age,
    "metabolism" => agent.metabolism,
    "vision" => agent.vision,
    "sex" => agent.sex,
    "visible_positions" => visible_positions,
    "neighbours" => neighbours,
    # global toggles (supplied in case the model prompt needs them)
    "enable_combat" => model.enable_combat,
    "enable_reproduction" => model.enable_reproduction,
    "enable_credit" => model.enable_credit,
  )
end

##############################  API interaction  ##############################

"""
    call_openai_api_individual(context::Dict, model) -> Dict
Low-level wrapper around the OpenAI Chat Completion endpoint for individual agent requests.
Uses the individual response format and schema for single agent decisions.
"""
function call_openai_api_individual(context::Dict, model)
  if isempty(model.llm_api_key)
    throw(LLMAPIError("LLM API key is empty but use_llm_decisions=true", nothing, nothing))
  end

  system_prompt = SugarscapePrompts.get_system_prompt()
  user_prompt = "Agent context:\n" * JSON.json(context)
  response_format = SugarscapePrompts.get_individual_response_format()

  local j
  try
    # Call the OpenAI Chat Completion endpoint via OpenAI.jl helper
    response = OpenAI.create_chat(
      model.llm_api_key,
      model.llm_model,
      [
        Dict("role" => "system", "content" => system_prompt),
        Dict("role" => "user", "content" => user_prompt),
      ];
      temperature=model.llm_temperature,
      response_format=response_format
    )
    # `response.response` already contains the parsed JSON returned by the API
    j = response.response
  catch err
    throw(LLMAPIError("Failed to call OpenAI API: $(err)", nothing, nothing))
  end

  # Validate response structure
  if !haskey(j, "choices") || isempty(j["choices"])
    throw(LLMAPIError("OpenAI API response missing 'choices' field or choices empty",
      nothing, String(j)))
  end

  if !haskey(j["choices"][1], "message") || !haskey(j["choices"][1]["message"], "content")
    throw(LLMAPIError("OpenAI API response missing message content",
      nothing, String(j)))
  end

  content = j["choices"][1]["message"]["content"]

  local parsed_content
  try
    parsed_content = JSON.parse(content)
  catch err
    throw(LLMSchemaError("Failed to parse LLM response content as JSON: $(err)",
      context["agent_id"], content))
  end

  # For individual requests, the response should be a single decision object
  if !isa(parsed_content, Dict)
    throw(LLMSchemaError("LLM response is not a dictionary", context["agent_id"], parsed_content))
  end

  return parsed_content
end

"""
    _safe_parse_decision(obj) -> LLMDecision
Convert a JSON object into an `LLMDecision`, inserting safe defaults for missing
fields. Use this for backwards compatibility when use_llm_decisions=false.
"""
function _safe_parse_decision(obj)
  # fallbacks make the field optional in the reply
  move = get(obj, "move", false)
  move_coords = get(obj, "move_coords", nothing)
  combat = get(obj, "combat", false)
  combat_target = get(obj, "combat_target", nothing)
  credit = get(obj, "credit", false)
  credit_partner = get(obj, "credit_partner", nothing)
  reproduce = get(obj, "reproduce", false)
  reproduce_with = get(obj, "reproduce_with", nothing)

  # normalise `null` to `nothing`
  if move_coords === nothing
    move_coords = nothing
  end
  if combat_target === nothing
    combat_target = nothing
  end
  if credit_partner === nothing
    credit_partner = nothing
  end
  if reproduce_with === nothing
    reproduce_with = nothing
  end

  return (move=move, move_coords=move_coords, combat=combat, combat_target=combat_target,
    credit=credit, credit_partner=credit_partner, reproduce=reproduce, reproduce_with=reproduce_with)
end

"""
    _strict_parse_decision(obj, agent_id) -> LLMDecision
Convert a JSON object into an `LLMDecision` with strict validation.
All required boolean fields must be present and valid.
Missing fields or invalid types will throw LLMSchemaError or LLMValidationError.
"""
function _strict_parse_decision(obj, agent_id)
  # Accept two formats:
  # 1. Direct decision dict {"move"=>…, …}
  # 2. Wrapper dict {"<agent_id>" => { …decision… }} as occasionally returned
  #    by LLMs following an alternative schema.

  # Ensure we are looking at the actual decision dictionary
  if isa(obj, Dict)
    if length(obj) == 1
      inner_key, inner_val = first(obj)
      if inner_key == string(agent_id) && isa(inner_val, Dict)
        obj = inner_val  # unwrap the decision
      end
    end
  else
    throw(LLMSchemaError("Decision object is not a dictionary", agent_id, obj))
  end

  # Required boolean fields - must be present and boolean
  required_bool_fields = ["move", "combat", "credit", "reproduce"]

  for field in required_bool_fields
    if !haskey(obj, field)
      throw(LLMSchemaError("Missing required field: $field", agent_id, obj))
    end

    value = obj[field]
    if !isa(value, Bool)
      throw(LLMValidationError("Field '$field' must be boolean, got: $(typeof(value))",
        field, value, agent_id))
    end
  end

  # Extract boolean fields
  move = obj["move"]
  combat = obj["combat"]
  credit = obj["credit"]
  reproduce = obj["reproduce"]

  # Optional fields - can be missing but must be correct type if present
  move_coords = nothing
  if haskey(obj, "move_coords") && obj["move_coords"] !== nothing
    coord_val = obj["move_coords"]
    if isa(coord_val, Vector) && length(coord_val) == 2 && all(isa(x, Number) for x in coord_val)
      move_coords = (Int(coord_val[1]), Int(coord_val[2]))
    elseif coord_val !== nothing
      throw(LLMValidationError("Field 'move_coords' must be [x,y] array or null",
        "move_coords", coord_val, agent_id))
    end
  end

  combat_target = nothing
  if haskey(obj, "combat_target") && obj["combat_target"] !== nothing
    target_val = obj["combat_target"]
    if isa(target_val, Number)
      combat_target = Int(target_val)
    elseif target_val !== nothing
      throw(LLMValidationError("Field 'combat_target' must be integer ID or null",
        "combat_target", target_val, agent_id))
    end
  end

  credit_partner = nothing
  if haskey(obj, "credit_partner") && obj["credit_partner"] !== nothing
    partner_val = obj["credit_partner"]
    if isa(partner_val, Number)
      credit_partner = Int(partner_val)
    elseif partner_val !== nothing
      throw(LLMValidationError("Field 'credit_partner' must be integer ID or null",
        "credit_partner", partner_val, agent_id))
    end
  end

  reproduce_with = nothing
  if haskey(obj, "reproduce_with") && obj["reproduce_with"] !== nothing
    repro_val = obj["reproduce_with"]
    if isa(repro_val, Number)
      reproduce_with = Int(repro_val)
    elseif repro_val !== nothing
      throw(LLMValidationError("Field 'reproduce_with' must be integer ID or null",
        "reproduce_with", repro_val, agent_id))
    end
  end

  # Logical validation: if action is true, corresponding target should be provided when applicable
  if move && move_coords === nothing
    @warn "Agent $agent_id chose to move but did not specify coordinates"
  end

  if combat && combat_target === nothing
    throw(LLMValidationError("Agent chose combat=true but no combat_target specified",
      "combat_target", nothing, agent_id))
  end

  if credit && credit_partner === nothing
    throw(LLMValidationError("Agent chose credit=true but no credit_partner specified",
      "credit_partner", nothing, agent_id))
  end

  if reproduce && reproduce_with === nothing
    throw(LLMValidationError("Agent chose reproduce=true but no reproduce_with specified",
      "reproduce_with", nothing, agent_id))
  end

  return (move=move, move_coords=move_coords, combat=combat, combat_target=combat_target,
    credit=credit, credit_partner=credit_partner, reproduce=reproduce, reproduce_with=reproduce_with)
end

###########################  individual agent entry point  ##############################

"""
    get_individual_agent_decision(agent, model) -> LLMDecision
Get a decision for a single agent by making an individual API call.
This is the main entry point for individual agent decision-making.
"""
function get_individual_agent_decision(agent, model)
  # Build single agent context
  context = build_agent_context(agent, model)

  # Make individual API call
  raw_response = call_openai_api_individual(context, model)

  # Parse single decision
  decision = _strict_parse_decision(raw_response, agent.id)

  return decision
end

"""
    get_individual_agent_decision_with_retry(agent, model) -> LLMDecision
Get a decision for a single agent with simple retry logic.
Either returns a valid LLM decision or throws an exception to stop the simulation.
"""
function get_individual_agent_decision_with_retry(agent, model)
  max_retries = 3

  for attempt in 1:max_retries
    try
      return get_individual_agent_decision(agent, model)
    catch e
      @warn "Agent $(agent.id) LLM request failed (attempt $attempt/$max_retries)" exception = (e, catch_backtrace())

      if attempt == max_retries
        @error "Agent $(agent.id) LLM request failed after $max_retries attempts - simulation must fail for research integrity"
        rethrow()
      end

      # Simple delay before retry
      sleep(0.1 * attempt)
    end
  end
end

########################### Error Message Helpers ############################

"""
    format_llm_error(e::Exception) -> String
Format LLM integration errors with helpful debugging information.
"""
function format_llm_error(e::Exception)
  if isa(e, LLMAPIError)
    msg = "LLM API Error: $(e.message)"
    if e.status_code !== nothing
      msg *= "\nHTTP Status: $(e.status_code)"
    end
    if e.response_body !== nothing
      # Truncate long responses
      body = length(e.response_body) > 500 ? e.response_body[1:500] * "..." : e.response_body
      msg *= "\nResponse Body: $(body)"
    end
    return msg
  elseif isa(e, LLMSchemaError)
    msg = "LLM Schema Error: $(e.message)"
    if e.agent_id !== nothing
      msg *= "\nAgent ID: $(e.agent_id)"
    end
    if e.raw_response !== nothing
      msg *= "\nRaw Response: $(e.raw_response)"
    end
    return msg
  elseif isa(e, LLMValidationError)
    msg = "LLM Validation Error: $(e.message)"
    if e.agent_id !== nothing
      msg *= "\nAgent ID: $(e.agent_id)"
    end
    msg *= "\nField: $(e.field)"
    msg *= "\nInvalid Value: $(e.value)"
    return msg
  elseif isa(e, LLMResearchIntegrityError)
    msg = "LLM Research Integrity Error: $(e.message)"
    if e.agent_id !== nothing
      msg *= "\nAgent ID: $(e.agent_id)"
    end
    msg *= "\nContext: $(e.context)"
    return msg
  else
    return "Unexpected error: $(e)"
  end
end

end # module SugarscapeLLM
