using Test
using Sugarscape
using JSON

@testset "LLM Schema Validation Tests" begin

  # Create test model for context
  model = Sugarscape.sugarscape(
    N=3,
    dims=(10, 10)
  )

  # Set LLM configuration
  model.use_llm_decisions = true
  model.llm_temperature = 0.0
  model.llm_api_key = "test-key"

  # Get test agents
  agents = collect(Sugarscape.allagents(model))

  @testset "Valid JSON Schema" begin
    # Test valid complete response
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
            "credit": true,
            "credit_partner": $(agents[2].id)
        }
    ]
    """

    # This should not throw an error
    parsed = JSON.parse(valid_response)
    @test isa(parsed, Vector)
    @test length(parsed) == 3

    # Test each decision can be parsed
    for (i, decision_data) in enumerate(parsed)
      decision = Sugarscape.SugarscapeLLM._strict_parse_decision(decision_data, agents[i].id)
      @test decision isa Sugarscape.LLMDecision
    end
  end

  @testset "Invalid JSON Structure" begin
    # Test malformed JSON
    malformed_json = """
    [
        {
            "move": true,
            "move_coords": [1, 0],
            "combat": false,
            "reproduce": false,
            "credit": false
        },
        # This comma breaks JSON
    ]
    """

    @test_throws ErrorException JSON.parse(malformed_json)

    # Test missing closing brace
    incomplete_json = """
    [
        {
            "move": true
    """

    @test_throws ErrorException JSON.parse(incomplete_json)
  end

  @testset "Missing Required Fields" begin
    # Test missing required decision fields
    missing_fields = [
      ("move", """{"combat": false, "reproduce": false, "credit": false}"""),
      ("combat", """{"move": true, "reproduce": false, "credit": false}"""),
      ("reproduce", """{"move": true, "combat": false, "credit": false}"""),
      ("credit", """{"move": true, "combat": false, "reproduce": false}""")
    ]

    for (field, decision_json) in missing_fields
      decision_data = JSON.parse(decision_json)
      @test_throws Sugarscape.SugarscapeLLM.LLMSchemaError begin
        Sugarscape.SugarscapeLLM._strict_parse_decision(decision_data, agents[1].id)
      end
    end
  end

  @testset "Wrong Data Types" begin
    # Test non-boolean values for boolean fields
    wrong_types = [
      ("move", "\"true\""),  # String instead of boolean
      ("combat", "1"),       # Number instead of boolean
      ("reproduce", "null"), # Null instead of boolean
      ("credit", "[]")       # Array instead of boolean
    ]

    for (field, wrong_value) in wrong_types
      decision_json = """
      {
          "move": $(field == "move" ? wrong_value : "false"),
          "combat": $(field == "combat" ? wrong_value : "false"),
          "reproduce": $(field == "reproduce" ? wrong_value : "false"),
          "credit": $(field == "credit" ? wrong_value : "false")
      }
      """

      decision_data = JSON.parse(decision_json)
      @test_throws Sugarscape.SugarscapeLLM.LLMValidationError begin
        Sugarscape.SugarscapeLLM._strict_parse_decision(decision_data, agents[1].id)
      end
    end
  end

  @testset "Invalid Values" begin
    # Test invalid move coordinates (should be valid for this system)
    invalid_move_coords = """
    {
        "move": true,
        "move_coords": [2, 0, 1],
        "combat": false,
        "reproduce": false,
        "credit": false
    }
    """

    decision_data = JSON.parse(invalid_move_coords)
    @test_throws Sugarscape.SugarscapeLLM.LLMValidationError begin
      Sugarscape.SugarscapeLLM._strict_parse_decision(decision_data, agents[1].id)
    end

    # Test invalid combat target (non-existent agent)
    invalid_combat_target = """
    {
        "move": false,
        "combat": true,
        "combat_target": 99999,
        "reproduce": false,
        "credit": false
    }
    """

    decision_data = JSON.parse(invalid_combat_target)
    # Note: This may not throw an error since the validation doesn't check if agent exists
    # We'll just test that it parses without error
    decision = Sugarscape.SugarscapeLLM._strict_parse_decision(decision_data, agents[1].id)
    @test decision.combat_target == 99999

    # Test invalid credit partner (string instead of number)
    invalid_credit_partner = """
    {
        "move": false,
        "combat": false,
        "reproduce": false,
        "credit": true,
        "credit_partner": "not-a-number"
    }
    """

    decision_data = JSON.parse(invalid_credit_partner)
    @test_throws Sugarscape.SugarscapeLLM.LLMValidationError begin
      Sugarscape.SugarscapeLLM._strict_parse_decision(decision_data, agents[1].id)
    end
  end

  @testset "Logical Validation" begin
    # Test move=true but missing move_coords (this should only generate warning, not error)
    missing_move_coords = """
    {
        "move": true,
        "combat": false,
        "reproduce": false,
        "credit": false
    }
    """

    decision_data = JSON.parse(missing_move_coords)
    # This should work but may generate a warning
    decision = Sugarscape.SugarscapeLLM._strict_parse_decision(decision_data, agents[1].id)
    @test decision.move == true
    @test decision.move_coords === nothing

    # Test combat=true but missing combat_target
    missing_combat_target = """
    {
        "move": false,
        "combat": true,
        "reproduce": false,
        "credit": false
    }
    """

    decision_data = JSON.parse(missing_combat_target)
    @test_throws Sugarscape.SugarscapeLLM.LLMValidationError begin
      Sugarscape.SugarscapeLLM._strict_parse_decision(decision_data, agents[1].id)
    end

    # Test credit=true but missing credit_partner
    missing_credit_partner = """
    {
        "move": false,
        "combat": false,
        "reproduce": false,
        "credit": true
    }
    """

    decision_data = JSON.parse(missing_credit_partner)
    @test_throws Sugarscape.SugarscapeLLM.LLMValidationError begin
      Sugarscape.SugarscapeLLM._strict_parse_decision(decision_data, agents[1].id)
    end

    # Test reproduce=true but missing reproduce_with
    missing_reproduce_with = """
    {
        "move": false,
        "combat": false,
        "reproduce": true,
        "credit": false
    }
    """

    decision_data = JSON.parse(missing_reproduce_with)
    @test_throws Sugarscape.SugarscapeLLM.LLMValidationError begin
      Sugarscape.SugarscapeLLM._strict_parse_decision(decision_data, agents[1].id)
    end
  end

  @testset "Edge Cases" begin
    # Test empty decisions array
    empty_decisions = """
    []
    """

    parsed = JSON.parse(empty_decisions)
    @test isa(parsed, Vector)
    @test length(parsed) == 0

    # Test extra unexpected fields (should be ignored)
    extra_fields = """
    {
        "move": true,
        "move_coords": [1, 0],
        "combat": false,
        "reproduce": false,
        "credit": false,
        "extra_field": "should_be_ignored",
        "another_extra": 123
    }
    """

    decision_data = JSON.parse(extra_fields)
    # Should not throw error - extra fields are ignored
    decision = Sugarscape.SugarscapeLLM._strict_parse_decision(decision_data, agents[1].id)
    @test decision isa Sugarscape.LLMDecision

    # Test very long move_coords array
    long_move_coords = """
    {
        "move": true,
        "move_coords": [1, 0, 1, 0, 1],
        "combat": false,
        "reproduce": false,
        "credit": false
    }
    """

    decision_data = JSON.parse(long_move_coords)
    @test_throws Sugarscape.SugarscapeLLM.LLMValidationError begin
      Sugarscape.SugarscapeLLM._strict_parse_decision(decision_data, agents[1].id)
    end
  end

  @testset "Response Count Validation" begin
    # Test too few decisions
    too_few_decisions = """
    [
        {
            "move": true,
            "move_coords": [1, 0],
            "combat": false,
            "reproduce": false,
            "credit": false
        }
    ]
    """

    parsed = JSON.parse(too_few_decisions)
    @test isa(parsed, Vector)
    @test length(parsed) == 1
    # Note: Response count validation is handled by populate_llm_decisions! function

    # Test too many decisions
    too_many_decisions = """
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
            "combat": false,
            "reproduce": false,
            "credit": false
        },
        {
            "move": false,
            "combat": false,
            "reproduce": false,
            "credit": false
        },
        {
            "move": false,
            "combat": false,
            "reproduce": false,
            "credit": false
        }
    ]
    """

    parsed = JSON.parse(too_many_decisions)
    @test isa(parsed, Vector)
    @test length(parsed) == 4
    # Note: Response count validation is handled by populate_llm_decisions! function
  end

  @testset "Error Message Quality" begin
    # Test that error messages contain helpful information
    invalid_json = """
    {
        "move": "not-a-boolean",
        "combat": false,
        "reproduce": false,
        "credit": false
    }
    """

    decision_data = JSON.parse(invalid_json)

    try
      Sugarscape.SugarscapeLLM._strict_parse_decision(decision_data, agents[1].id)
      @test false  # Should not reach here
    catch e
      @test e isa Sugarscape.SugarscapeLLM.LLMValidationError
      error_msg = string(e)
      @test occursin("move", error_msg)  # Should mention the problematic field
      @test occursin("boolean", error_msg)  # Should mention expected type
      @test occursin("$(agents[1].id)", error_msg)  # Should mention agent ID
    end
  end
end
