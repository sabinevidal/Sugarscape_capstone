module SugarscapePrompts

###############################################################################
# LLM Prompts and Schemas                                                   #
#                                                                            #
# This file contains the system prompts and structured schema definitions    #
# used for LLM integration in the Sugarscape model.                         #
#                                                                            #
# Individual agent decision-making implementation.                           #
###############################################################################

"""
    get_system_prompt() -> String
Returns the system prompt used for LLM decision-making in Sugarscape.
"""
function get_system_prompt()
  return """
  You are an AI controlling a single agent in a Sugarscape simulation. Your job is to make decisions for this specific agent based on its current situation and the standard Sugarscape rules.
  """
end

"""
    get_movement_system_prompt() -> String
Returns the system prompt used for LLM movement decisions in Sugarscape.
"""
function get_movement_system_prompt()
  return """
  MOVEMENT RULE:
  - Considering only unoccupied lattice positions, find the nearest position producing maximum welfare;
  - Move to the new position;
  """
end
"""
    get_reproduction_system_prompt() -> String
Returns the system prompt used for LLM reproduction decisions in Sugarscape.
"""
function get_reproduction_system_prompt()
  return """
  REPRODUCTION RULE:
  - An agent may reproduce up to max_partners times per turn.
  - Reproduction occurs if:
    - The partner is of the opposite sex, fertile, and within the agent’s Moore neighborhood.
    - Both agents are fertile, where fertility is defined by age falling within the predefined fertility range.
    - At least one of the two agents has an empty adjacent site (i.e. an unoccupied neighboring cell).
  - From the set of eligible partners (those who meet all criteria above), select up to max_partners
  - Select partners from list of eligible_partners, up to max_partners.
  - If no partners are eligible, do not reproduce.
  - Either the agent or the partner must have an empty neighbouring site.
  - If no eligible partners are found, or no valid empty site exists for either the agent or the partner, no reproduction occurs.
  """
end

"""
    get_individual_decision_schema() -> Dict
Returns the structured schema definition for a single agent decision.
"""
function get_individual_decision_schema()
  return Dict(
    "type" => "object",
    "properties" => Dict(
      "agent_id" => Dict(
        "type" => "integer",
        "description" => "Unique identifier for the agent"
      ),
      "move" => Dict(
        "type" => "boolean",
        "description" => "Whether the agent should move"
      ),
      "move_coords" => Dict(
        "type" => ["array", "null"],
        "items" => Dict("type" => "integer"),
        "minItems" => 2,
        "maxItems" => 2,
        "description" => "Target coordinates [x, y] for movement, null if not moving"
      ),
      "combat" => Dict(
        "type" => "boolean",
        "description" => "Whether the agent should engage in combat"
      ),
      "combat_target" => Dict(
        "type" => ["integer", "null"],
        "description" => "ID of the target agent for combat, null if not fighting"
      ),
      "credit" => Dict(
        "type" => "boolean",
        "description" => "Whether the agent should engage in credit transactions"
      ),
      "credit_partner" => Dict(
        "type" => ["integer", "null"],
        "description" => "ID of the partner agent for credit transactions, null if not lending/borrowing"
      ),
      "reproduce" => Dict(
        "type" => "boolean",
        "description" => "Whether the agent should reproduce"
      ),
      "reproduce_with" => Dict(
        "type" => ["integer", "null"],
        "description" => "ID of the partner agent for reproduction, null if not reproducing"
      )
    ),
    "required" => [
      "agent_id", "move", "move_coords", "combat", "combat_target",
      "credit", "credit_partner", "reproduce", "reproduce_with"
    ],
    "additionalProperties" => false
  )
end

"""
    get_movement_decision_schema() -> Dict
Returns the structured schema definition for a movement decision.
"""
function get_movement_decision_schema()
  return Dict(
    "type" => "object",
    "properties" => Dict(
      "agent_id" => Dict(
        "type" => "integer",
        "description" => "Unique identifier for the agent"
      ),
      "move" => Dict(
        "type" => "boolean",
        "description" => "Whether the agent should move"
      ),
      "move_coords" => Dict(
        "type" => ["array", "null"],
        "items" => Dict("type" => "integer"),
        "minItems" => 2,
        "maxItems" => 2,
        "description" => "Target coordinates [x, y] for movement, null if not moving"
      ),
    ),
    "required" => [
      "agent_id", "move", "move_coords"
    ],
    "additionalProperties" => false
  )
end

"""
    get_reproduction_decision_schema() -> Dict
Returns the structured schema definition for a reproduction decision.
"""
function get_reproduction_decision_schema(max_partners::Int)
  return Dict(
    "type" => "object",
    "properties" => Dict(
      "agent_id" => Dict(
        "type" => "integer",
        "description" => "Unique identifier for the agent"
      ),
      "reproduce" => Dict(
        "type" => "boolean",
        "description" => "Whether the agent should reproduce"
      ),
      "partners" => Dict(
        "type" => ["array", "null"],
        "items" => Dict("type" => "integer"),
        "maxItems" => max_partners,
        "description" => "List of partner IDs for reproduction, null if not reproducing"
      ),
      "reasoning_for_choice" => Dict(
        "type" => ["string"],
        "description" => "Reasoning for the choice of partners or, if not applicable, the reason for not reproducing, max 2 sentences."
      )
    ),
    "required" => [
      "agent_id", "reproduce", "partners", "reasoning_for_choice"
    ],
    "additionalProperties" => false
  )
end

"""
    get_movement_response_format() -> Dict
Returns the OpenAI response format configuration for movement decisions.
"""
function get_movement_response_format()
  return Dict(
    "type" => "json_schema",
    "json_schema" => Dict(
      "name" => "movement_response",
      "schema" => get_movement_decision_schema(),
      "strict" => true
    ),
  )
end

"""
    get_reproduction_response_format() -> Dict
Returns the OpenAI response format configuration for reproduction decisions.
"""
function get_reproduction_response_format(max_partners::Int)
  return Dict(
    "type" => "json_schema",
    "json_schema" => Dict(
      "name" => "reproduction_response",
      "schema" => get_reproduction_decision_schema(max_partners),
      "strict" => true
    ),
  )
end

"""
    get_individual_response_format() -> Dict
Returns the OpenAI response format configuration for individual agent decisions.
"""
function get_individual_response_format()
  return Dict(
    "type" => "json_schema",
    "json_schema" => Dict(
      "name" => "individual_decision_response",
      "schema" => get_individual_decision_schema(),
      "strict" => true
    ),
  )
end

###############################################################################
end # module SugarscapePrompts
