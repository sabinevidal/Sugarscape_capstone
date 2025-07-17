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
      "reasoning_for_choice" => Dict(
        "type" => ["string"],
        "description" => "Reasoning for the choice of movement coordinates, if not applicable, the reason for not moving, max 2 sentences."
      )
    ),
    "required" => [
      "agent_id", "move", "move_coords", "reasoning_for_choice"
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

## ---------------------------------------------------------------------------
## Lender Credit Rule Prompts and Schemas
## ---------------------------------------------------------------------------
"""
    get_credit_lender_system_prompt() -> String
Returns the system prompt used for LLM credit decisions in Sugarscape.
"""
function get_credit_lender_system_prompt()
  return """
  CREDIT RULE:
  You are a lending agent.
  A neighbouring agent has requested a loan from you. Decide whether to approve the loan based on your current wealth, age, and fertility.
  Follow the rules below:
    1.	If you are too old to reproduce, you may lend up to half of your current sugar.
    2.	If you are of reproductive age and have more sugar than needed to reproduce, you may lend only the excess.
    3.	You may lend only to eligible neighbouring agents who request a loan.

  Based on your lending capacity and the borrower's request, decide whether to approve the loan and how much you will lend (up to your maximum allowed).
  If you do not approve the loan, return false.
  """
end

"""
    get_credit_lender_decision_schema() -> Dict
Returns the structured schema definition for a credit decision.
"""
function get_credit_lender_decision_schema()
  return Dict(
    "type" => "object",
    "properties" => Dict(
      "agent_id" => Dict("type" => "integer", "description" => "Unique identifier for the agent"),
      "lend" => Dict("type" => "boolean", "description" => "Whether to lend sugar"),
      "lend_to" => Dict(
        "type" => ["array", "null"],
        "items" => Dict(
          "type" => "object",
          "properties" => Dict(
            "order" => Dict(
              "type" => "integer",
              "description" => "Order in which to lend to this borrower"
            ),
            "borrower_id" => Dict(
              "type" => "integer",
              "description" => "ID of the neighbouring agent to lend sugar to"
            ),
            "lend_amount" => Dict(
              "type" => "number",
              "description" => "Amount of sugar to lend to the borrower"
            )
          ),
          "required" => ["order", "borrower_id", "lend_amount"],
          "additionalProperties" => false
        ),
        "description" => "Array of objects specifying which neighbouring agents to lend sugar to and how much to lend; null if not lending"
      ),
      "reasoning_for_choice" => Dict(
        "type" => ["string"],
        "description" => "Reasoning for the choice of who to lend sugar to and the amount or, if not applicable, the reason for not lending sugar, max 2 sentences."
      )
    ),
    "required" => ["agent_id", "lend", "lend_to", "reasoning_for_choice"],
    "additionalProperties" => false
  )
end

"""
    get_credit_response_format() -> Dict
Returns the OpenAI response format configuration for credit decisions.
"""
function get_credit_lender_response_format()
  return Dict(
    "type" => "json_schema",
    "json_schema" => Dict(
      "name" => "credit_response",
      "schema" => get_credit_lender_decision_schema(),
      "strict" => true
    )
  )
end
###############################################################################
# Borrower Credit Rule Prompts and Schemas
###############################################################################
"""
    get_credit_borrower_system_prompt() -> String
Returns the system prompt used for LLM credit borrowing decisions in Sugarscape.
"""
function get_credit_borrower_system_prompt()
  return """
  CREDIT RULE:
  You are a borrowing agent.
  Based on your current wealth, fertility, and income, decide whether to borrow sugar.
  Follow the rules below:
    1.	You may borrow if you are of reproductive age, have less sugar than needed to reproduce, and have income.
    2.	You may only borrow from eligible neighbouring agents who are able to lend.
    3.	You may request only as much sugar as is needed to reach the reproduction threshold.

  From the list of eligible lenders provided, select which order you want to borrow from and specify the amount to request.
  If you do not wish to borrow, return false.
  """
end

"""
    get_credit_borrower_decision_schema() -> Dict
Returns the structured schema definition for a credit borrowing decision.
"""
function get_credit_borrower_decision_schema()
  return Dict(
    "type" => "object",
    "properties" => Dict(
      "agent_id" => Dict("type" => "integer", "description" => "Unique identifier for the agent"),
      "borrow" => Dict("type" => "boolean", "description" => "Whether to borrow sugar"),
      "borrow_from" => Dict(
        "type" => ["array", "null"],
        "items" => Dict(
          "type" => "object",
          "properties" => Dict(
            "order" => Dict(
              "type" => "integer",
              "description" => "Order in which to borrow from this lender"
            ),
            "lender_id" => Dict(
              "type" => "integer",
              "description" => "ID of the neighbouring agent to borrow sugar from"
            ),
            "requested_amount" => Dict(
              "type" => "number",
              "description" => "Amount of sugar requested from the lender"
            )
          ),
          "required" => ["order", "lender_id", "requested_amount"],
          "additionalProperties" => false
        ),
        "description" => "Array of objects specifying which neighbouring agents to borrow sugar from and how much to request; null if not borrowing"
      ),
      "reasoning_for_choice" => Dict(
        "type" => ["string"],
        "description" => "Reasoning for the choice of who to borrow from and the amount requested or, if not applicable, the reason for not borrowing, max 2 sentences."
      )
    ),
    "required" => ["agent_id", "borrow", "borrow_from", "reasoning_for_choice"],
    "additionalProperties" => false
  )
end

"""
    get_credit_borrower_response_format() -> Dict
Returns the OpenAI response format configuration for credit borrowing decisions.
"""
function get_credit_borrower_response_format()
  return Dict(
    "type" => "json_schema",
    "json_schema" => Dict(
      "name" => "credit_borrower_response",
      "schema" => get_credit_borrower_decision_schema(),
      "strict" => true
    )
  )
end
###############################################################################
end # module SugarscapePrompts
