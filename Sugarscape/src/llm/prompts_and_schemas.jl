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
