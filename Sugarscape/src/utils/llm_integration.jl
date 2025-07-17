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
function call_openai_api(context::Dict, model, rule_prompt, response_format)
    if isempty(model.llm_api_key)
        throw(LLMAPIError("LLM API key is empty but use_llm_decisions=true", nothing, nothing))
    end

    system_prompt = SugarscapePrompts.get_system_prompt() * rule_prompt
    user_prompt = "Agent context:\n" * JSON.json(context)

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
            response_format=response_format,
            metadata=model.llm_metadata,
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



########################### Movement helpers ############################
function _parse_movement_decision(obj)
    move = get(obj, "move", false)
    move_coords = get(obj, "move_coords", nothing)

    # Convert vector to tuple if present
    if move_coords !== nothing && isa(move_coords, Vector) && length(move_coords) == 2 && all(isa(x, Number) for x in move_coords)
        move_coords = (Int(move_coords[1]), Int(move_coords[2]))
    end

    return (move=move, move_coords=move_coords)
end

function get_movement_decision(context::Dict, model)
    movement_response_format = SugarscapePrompts.get_movement_response_format()
    movement_prompt = SugarscapePrompts.get_movement_system_prompt()
    try
        raw_response = call_openai_api(context, model, movement_prompt, movement_response_format)
        decision = _parse_movement_decision(raw_response)
        return decision
    catch e
        throw(LLMAPIError("Failed to get movement decision: $(e)", nothing, nothing))
    end
end

########################### Reproduction helpers ############################
function _parse_reproduction_decision(obj)
    reproduce = get(obj, "reproduce", false)
    partners = get(obj, "partners", nothing)

    return (reproduce=reproduce, partners=partners)
end

function get_reproduction_decision(context::Dict, model)
    reproduction_response_format = SugarscapePrompts.get_reproduction_response_format(context[:max_partners])
    reproduction_prompt = SugarscapePrompts.get_reproduction_system_prompt()
    try
        raw_response = call_openai_api(context, model, reproduction_prompt, reproduction_response_format)
        decision = _parse_reproduction_decision(raw_response)
        return decision
    catch e
        throw(LLMAPIError("Failed to get reproduction decision: $(e)", nothing, nothing))
    end
end

########################### Culture helpers ############################
function _parse_culture_decision(obj)
    # Culture decisions are expected to be a dictionary with culture tags
    spread_culture = get(obj, "spread_culture", false)
    transmit_to = get(obj, "transmit_to", nothing)

    return (spread_culture=spread_culture, transmit_to=transmit_to)
end

function get_culture_decision(context::Dict, model)
    culture_response_format = SugarscapePrompts.get_culture_response_format()
    culture_prompt = SugarscapePrompts.get_culture_system_prompt()
    try
        raw_response = call_openai_api(context, model, culture_prompt, culture_response_format)
        decision = _parse_culture_decision(raw_response)
        return decision
    catch e
        throw(LLMAPIError("Failed to get culture decision: $(e)", nothing, nothing))
    end
end


########################### Credit helpers ############################
"""
    _parse_credit_lender_decision(obj) -> (lend, lend_to)
Parser for credit lending decisions from LLM.
"""
function _parse_credit_lender_decision(obj)
    lend = get(obj, "lend", false)
    lend_to = get(obj, "lend_to", nothing)
    return (lend=lend, lend_to=lend_to)
end

"""
    _parse_credit_borrower_decision(obj) -> (borrow, borrow_from)
Parser for credit borrowing decisions from LLM.
"""
function _parse_credit_borrower_decision(obj)
    borrow = get(obj, "borrow", false)
    borrow_from = get(obj, "borrow_from", nothing)
    return (borrow=borrow, borrow_from=borrow_from)
end

"""
    get_credit_lender_decision(context::Dict, model)
LLM integration for credit lending decisions.
"""
function get_credit_lender_decision(context::Dict, model)
    credit_response_format = SugarscapePrompts.get_credit_lender_response_format()
    credit_prompt = SugarscapePrompts.get_credit_lender_system_prompt()
    try
        raw_response = call_openai_api(context, model, credit_prompt, credit_response_format)
        decision = _parse_credit_lender_decision(raw_response)
        return decision
    catch e
        throw(LLMAPIError("Failed to get credit lender decision: $(e)", nothing, nothing))
    end
end

"""
    get_credit_borrower_decision(context::Dict, model)
LLM integration for credit borrowing decisions.
"""
function get_credit_borrower_decision(context::Dict, model)
    credit_response_format = SugarscapePrompts.get_credit_borrower_response_format()
    credit_prompt = SugarscapePrompts.get_credit_borrower_system_prompt()
    try
        raw_response = call_openai_api(context, model, credit_prompt, credit_response_format)
        decision = _parse_credit_borrower_decision(raw_response)
        return decision
    catch e
        throw(LLMAPIError("Failed to get credit borrower decision: $(e)", nothing, nothing))
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
