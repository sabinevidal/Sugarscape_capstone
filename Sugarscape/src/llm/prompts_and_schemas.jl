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
  - An agent can reproduce with up to max_partners eligible partners per turn.
  - A partner is eligible if they:
    - Are of the opposite sex
    - Are within the agent’s vision range
    - Are fertile
    - Either the agent or the partner has at least one empty neighboring site.
  - Reproduction occurs if:
    - At least one of the two agents has an empty adjacent site (i.e. an unoccupied neighboring cell).
  - From the set of eligible partners (those who meet all criteria above), select up to max_partners partners for reproduction.
  - If no partners are eligible, do not reproduce.
  - Reproduction is only possible if at least one of the agent or the eligible partner has at least one empty neighboring site. Check both empty_nearby_positions for the agent and partner_empty_nearby_positions for each partner.
  - If no eligible partners are found, or no valid empty site exists for either the agent or the partner, no reproduction occurs.
  """
end

"""
    get_culture_system_prompt() -> String
Returns the system prompt used for LLM culture decisions in Sugarscape.
"""
function get_culture_system_prompt()
  return """
  CULTURE RULE:
  For each neighbouring agent:
  - RANDOMLY select ONLY ONE tag position (not more than one).
  - Compare the agent's own value at that position to the neighbour's value.
  - If the values are the same: do nothing.
  - If the values are different: return a decision to flip the neighbour's tag at that index to match the agent's.

  Important:
  - You must return AT MOST ONE decision per neighbour.
  - Do NOT return multiple tag positions for the same neighbour.
  - Only include neighbours where a tag was selected AND disagreement was found.
  - Repeat this for ALL neighbours.
  - When specifying tag positions, use 1-based indexing (the first tag is index 1).
  """
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
      # "reasoning_for_choice" => Dict(
      #   "type" => ["string"],
      #   "description" => "Reasoning for the choice of movement coordinates, if not applicable, the reason for not moving, max 2 sentences."
      # )
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
      # "reasoning_for_choice" => Dict(
      #   "type" => ["string"],
      #   "description" => "Reasoning for the choice of partners or, if not applicable, the reason for not reproducing, max 2 sentences."
      # )
    ),
    "required" => [
      "agent_id", "reproduce", "partners"
    ],
    "additionalProperties" => false
  )
end


"""
    get_culture_decision_schema() -> Dict
Returns the structured schema definition for a culture decision.
"""
function get_culture_decision_schema()
  return Dict(
    "type" => "object",
    "properties" => Dict(
      "agent_id" => Dict(
        "type" => "integer",
        "description" => "Unique identifier for the agent"
      ),
      "spread_culture" => Dict(
        "type" => "boolean",
        "description" => "Whether the agent should spread culture"
      ),
      "transmit_to" => Dict(
        "type" => ["array", "null"],
        "items" => Dict(
          "type" => "object",
          "properties" => Dict(
            "target_id" => Dict(
              "type" => "integer",
              "description" => "ID of the neighbouring agent to spread culture to"
            ),
            "tag_index" => Dict(
              "type" => "integer",
              "minItems" => 1,
              "maxItems" => 1,
              "description" => "Index (1-based) of the tag being modified"
            )
          ),
          "required" => ["target_id", "tag_index"],
          "additionalProperties" => false
        ),
        "description" => "Array of objects specifying which neighbouring agents to spread culture to and which tag index to modify; null if not spreading"
      ),
      "reasoning_for_choice" => Dict(
        "type" => ["string"],
        "description" => "Reasoning for the choice of who to spread culture to or, if not applicable, the reason for not spreading culture, max 2 sentences."
      )
    ),
    "required" => [
      "agent_id", "spread_culture", "transmit_to", "reasoning_for_choice"
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
    get_culture_response_format() -> Dict
Returns the OpenAI response format configuration for culture decisions.
"""
function get_culture_response_format()
  return Dict(
    "type" => "json_schema",
    "json_schema" => Dict(
      "name" => "culture_response",
      "schema" => get_culture_decision_schema(),
      "strict" => true
    ),
  )
end

###############################################################################
end # module SugarscapePrompts
