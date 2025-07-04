using Sugarscape, JSON

println("=== Simple Schema Validation Test ===")

# Create test model
model = Sugarscape.sugarscape(N=3, dims=(10, 10))
model.use_llm_decisions = true
model.llm_temperature = 0.0
model.llm_api_key = "test-key"

# Get test agents
agents = collect(Sugarscape.allagents(model))
println("Created model with ", length(agents), " agents")

# Test valid JSON parsing
println("\n--- Testing Valid JSON ---")
valid_response = """
[
    {
        "move": true,
        "move_coords": [1, 0],
        "combat": false,
        "reproduce": false,
        "credit": false
    },
    {
        "move": false,
        "combat": true,
        "combat_target": $(agents[1].id),
        "reproduce": false,
        "credit": false
    },
    {
        "move": true,
        "move_coords": [0, 1],
        "combat": false,
        "reproduce": true,
        "reproduce_with": $(agents[2].id),
        "credit": true,
        "credit_partner": $(agents[2].id)
    }
]
"""

try
  parsed = JSON.parse(valid_response)
  println("✓ Valid JSON parsed successfully")

  # Test each decision parsing
  for (i, decision_data) in enumerate(parsed)
    decision = Sugarscape.SugarscapeLLM._strict_parse_decision(decision_data, agents[i].id)
    println("✓ Decision $i parsed successfully: ", decision)
  end
catch e
  println("✗ Error parsing valid JSON: ", e)
end

# Test invalid JSON
println("\n--- Testing Invalid JSON ---")
invalid_json = """
[
    {
        "move": "not-a-boolean",
        "combat": false,
        "reproduce": false,
        "credit": false
    }
]
"""

try
  parsed = JSON.parse(invalid_json)
  decision = Sugarscape.SugarscapeLLM._strict_parse_decision(parsed[1], agents[1].id)
  println("✗ Should have failed but didn't!")
catch e
  if isa(e, Sugarscape.SugarscapeLLM.LLMValidationError)
    println("✓ Correctly caught LLMValidationError: ", e.message)
  else
    println("✗ Unexpected error type: ", e)
  end
end

# Test missing required fields
println("\n--- Testing Missing Required Fields ---")
missing_field_json = """
{
    "move": true,
    "combat": false,
    "reproduce": false
}
"""

try
  parsed = JSON.parse(missing_field_json)
  decision = Sugarscape.SugarscapeLLM._strict_parse_decision(parsed, agents[1].id)
  println("✗ Should have failed but didn't!")
catch e
  if isa(e, Sugarscape.SugarscapeLLM.LLMSchemaError)
    println("✓ Correctly caught LLMSchemaError: ", e.message)
  else
    println("✗ Unexpected error type: ", e)
  end
end

# Test logical validation
println("\n--- Testing Logical Validation ---")
logical_error_json = """
{
    "move": false,
    "combat": true,
    "reproduce": false,
    "credit": false
}
"""

try
  parsed = JSON.parse(logical_error_json)
  decision = Sugarscape.SugarscapeLLM._strict_parse_decision(parsed, agents[1].id)
  println("✗ Should have failed but didn't!")
catch e
  if isa(e, Sugarscape.SugarscapeLLM.LLMValidationError)
    println("✓ Correctly caught LLMValidationError: ", e.message)
  else
    println("✗ Unexpected error type: ", e)
  end
end

println("\n=== Schema Validation Test Complete ===")
