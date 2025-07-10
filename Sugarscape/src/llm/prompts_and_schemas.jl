module SugarscapePrompts

###############################################################################
# LLM Prompts and Schemas                                                   #
#                                                                            #
# This file contains the system prompts and structured schema definitions    #
# used for LLM integration in the Sugarscape model.                         #
###############################################################################

"""
    get_system_prompt() -> String
Returns the system prompt used for LLM decision-making in Sugarscape.
"""
function get_system_prompt()
  return """
  You are an AI controlling agents in a Sugarscape simulation. Your job is to mimic the decision rules as closely as possible.
  """
end

"""
    get_decision_schema() -> Dict
Returns the structured schema definition for agent decisions.
"""
function get_decision_schema()
  # Define the schema for a single decision object
  single_decision_schema = Dict(
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
    # All properties must be listed in `required` to satisfy the OpenAI response_format
    "required" => [
      "agent_id", "move", "move_coords", "combat", "combat_target",
      "credit", "credit_partner", "reproduce", "reproduce_with"
    ],
    "additionalProperties" => false
  )

  # Define the schema for an object containing an array of decision objects
  agent_action_schema = Dict(
    "type" => "object",
    "properties" => Dict(
      "decisions" => Dict(
        "type" => "array",
        "items" => single_decision_schema,
        "description" => "Array of decision objects, one per agent"
      )
    ),
    "required" => ["decisions"],
    "additionalProperties" => false
  )

  return agent_action_schema
end

"""
    get_response_format() -> Dict
Returns the OpenAI response format configuration using the structured schema.
"""
function get_response_format()
  return Dict(
    "type" => "json_schema",
    "json_schema" => Dict(
      "name" => "decision_response",
      "schema" => get_decision_schema(),
      "strict" => true
    ),
  )
end

###############################################################################
end # module SugarscapePrompts
