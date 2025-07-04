module SugarscapeLLM

###############################################################################
# Phase-2 LLM integration scaffold                                           #
#                                                                            #
# This file provides non-intrusive helper utilities for retrieving decisions #
# from an OpenAI-compatible endpoint and caching them on the Sugarscape      #
# `model`.  At this stage the rest of the ABM does not yet consume those     #
# decisions – that is introduced in Phase 3.                                 #
###############################################################################

using HTTP, JSON, Logging
using ..Agents: nearby_positions, nearby_agents, allagents, isempty

# Parent module alias for convenience
import ..Sugarscape
const SS = Sugarscape

##############################  helper utilities  #############################

"""
    _default_decision() -> LLMDecision
Return a decision where every boolean flag is `false` and every optional field
is `nothing`. Used as a safe fallback whenever the LLM response is unavailable
or malformed.
"""
_default_decision() = (move=false, move_coords=nothing, combat=false, combat_target=nothing,
  credit=false, credit_partner=nothing, reproduce=false, reproduce_with=nothing)

"""
    build_agent_context(agent, model) -> Dict
Collect a lightweight JSON-serialisable summary of the local state that the LLM
can use to decide on the agent's next actions.  The schema is intentionally kept
stable so tests that rely on it do not break when the runtime model evolves.
"""
function build_agent_context(agent, model)
  # Visible lattice positions with sugar (or welfare when pollution enabled)
  visible_positions = Vector{Any}()
  for pos in nearby_positions(agent, model, agent.vision)
    value = model.enable_pollution ? SS.welfare(pos, model) : model.sugar_values[pos...]
    push!(visible_positions, Dict(
      "position" => pos,
      "value" => value,
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
    call_openai_api(contexts::Vector, model) -> Vector{Dict}
Low-level wrapper around the OpenAI Chat Completion endpoint. When `use_llm_decisions=true`,
any failure will raise an error rather than silently falling back.
"""
function call_openai_api(contexts::Vector, model)
  if isempty(model.llm_api_key)
    error("LLM API key is empty but use_llm_decisions=true")
  end

  system_prompt = """
You are an AI controlling agents in a Sugarscape simulation. For each agent, decide whether they should:
1. MOVE: Choose whether to move and optionally specify coordinates
2. COMBAT: Choose whether to attack a neighbour (if enabled)
3. CREDIT: Choose whether to lend to a neighbour (if enabled)
4. REPRODUCE: Choose whether to reproduce with a neighbour (if enabled)

Return a JSON array where each element has the form
{
  \"move\": boolean,
  \"move_coords\": [x,y] | null,
  \"combat\": boolean,
  \"combat_target\": id | null,
  \"credit\": boolean,
  \"credit_partner\": id | null,
  \"reproduce\": boolean,
  \"reproduce_with\": id | null
}
    """

  user_prompt = "Agent contexts:\n" * JSON.json(contexts)

  body = Dict(
    "model" => model.llm_model,
    "messages" => [
      Dict("role" => "system", "content" => system_prompt),
      Dict("role" => "user", "content" => user_prompt),
    ],
    "temperature" => model.llm_temperature,
    "max_tokens" => model.llm_max_tokens,
  )

  headers = [
    "Authorization" => "Bearer $(model.llm_api_key)",
    "Content-Type" => "application/json",
  ]

  try
    resp = HTTP.post("https://api.openai.com/v1/chat/completions", headers, JSON.json(body))
    if resp.status == 200
      j = JSON.parse(String(resp.body))
      content = j["choices"][1]["message"]["content"]
      return JSON.parse(content)
    else
      error("OpenAI API call failed with status $(resp.status)")
    end
  catch err
    error("HTTP error during OpenAI call: $(err)")
  end
end

"""
    _safe_parse_decision(obj) -> LLMDecision
Convert a JSON object into an `LLMDecision`, inserting safe defaults for missing
fields.
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
  if move_coords === JSON.Null
    move_coords = nothing
  end
  if combat_target === JSON.Null
    combat_target = nothing
  end
  if credit_partner === JSON.Null
    credit_partner = nothing
  end
  if reproduce_with === JSON.Null
    reproduce_with = nothing
  end

  return (move=move, move_coords=move_coords, combat=combat, combat_target=combat_target,
    credit=credit, credit_partner=credit_partner, reproduce=reproduce, reproduce_with=reproduce_with)
end

###########################  public entry point  ##############################

"""
    populate_llm_decisions!(model)
Fetches decisions for *all* agents (batch request) and caches them in
`model.llm_decisions`. When `use_llm_decisions=true`, any failure will raise an error.
"""
function populate_llm_decisions!(model)
  # Safety guard
  model.use_llm_decisions || return

  # Build contexts
  contexts = [build_agent_context(a, model) for a in allagents(model)]

  # Obtain decisions (may be empty on failure)
  raw = call_openai_api(contexts, model)

  # Validate response length
  if length(raw) != length(contexts)
    error("LLM returned $(length(raw)) decisions for $(length(contexts)) agents")
  end

  decisions = Vector{Any}(undef, length(contexts))
  for (i, d) in enumerate(raw)
    try
      decisions[i] = _safe_parse_decision(d)
    catch
      error("Failed to parse LLM decision for agent $(contexts[i]["agent_id"]): $(d)")
    end
  end

  # Store in model keyed by agent id
  model.llm_decisions = Dict{Int,SS.LLMDecision}()
  for (i, ctx) in enumerate(contexts)
    model.llm_decisions[ctx["agent_id"]] = decisions[i]
  end
end

###############################################################################
end # module SugarscapeLLM
