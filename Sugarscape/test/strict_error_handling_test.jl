#!/usr/bin/env julia

"""
Test script to verify strict LLM error handling implementation.
This demonstrates that the system fails fast with clear error messages
when use_llm_decisions=true and various error conditions occur.
"""

using Test
include("../src/Sugarscape.jl")

function test_strict_error_handling()
  println("🧪 Testing Strict LLM Error Handling")
  println("="^50)

  # Test 1: Missing API Key
  println("\n1️⃣ Testing missing API key...")
  try
    model = Sugarscape.sugarscape(use_llm_decisions=true, llm_api_key="")
    Sugarscape.SugarscapeLLM.populate_llm_decisions!(model)
    @test false  # Should not reach here
  catch e
    @test isa(e, Sugarscape.SugarscapeLLM.LLMAPIError)
    println("✅ Correctly caught LLMAPIError: $(e.message)")
  end

  # Test 2: Invalid decision structure
  println("\n2️⃣ Testing invalid decision parsing...")
  try
    invalid_decision = Dict("invalid" => "structure")
    Sugarscape.SugarscapeLLM._strict_parse_decision(invalid_decision, 123)
    @test false  # Should not reach here
  catch e
    @test isa(e, Sugarscape.SugarscapeLLM.LLMSchemaError)
    println("✅ Correctly caught LLMSchemaError: $(e.message)")
  end

  # Test 3: Missing required fields
  println("\n3️⃣ Testing missing required fields...")
  try
    incomplete_decision = Dict("move" => true)  # Missing other required fields
    Sugarscape.SugarscapeLLM._strict_parse_decision(incomplete_decision, 123)
    @test false  # Should not reach here
  catch e
    @test isa(e, Sugarscape.SugarscapeLLM.LLMSchemaError)
    println("✅ Correctly caught LLMSchemaError for missing field: $(e.message)")
  end

  # Test 4: Invalid field types
  println("\n4️⃣ Testing invalid field types...")
  try
    invalid_type_decision = Dict(
      "move" => "yes",  # Should be boolean
      "combat" => false,
      "credit" => false,
      "reproduce" => false
    )
    Sugarscape.SugarscapeLLM._strict_parse_decision(invalid_type_decision, 123)
    @test false  # Should not reach here
  catch e
    @test isa(e, Sugarscape.SugarscapeLLM.LLMValidationError)
    println("✅ Correctly caught LLMValidationError: $(e.message)")
  end

  # Test 5: Logical validation errors
  println("\n5️⃣ Testing logical validation...")
  try
    illogical_decision = Dict(
      "move" => false,
      "combat" => true,  # True but no target
      "credit" => false,
      "reproduce" => false
    )
    Sugarscape.SugarscapeLLM._strict_parse_decision(illogical_decision, 123)
    @test false  # Should not reach here
  catch e
    @test isa(e, Sugarscape.SugarscapeLLM.LLMValidationError)
    println("✅ Correctly caught LLMValidationError for missing target: $(e.message)")
  end

  # Test 6: Valid decision parsing
  println("\n6️⃣ Testing valid decision parsing...")
  try
    valid_decision = Dict(
      "move" => true,
      "move_coords" => [5, 5],
      "combat" => false,
      "credit" => false,
      "reproduce" => false
    )
    result = Sugarscape.SugarscapeLLM._strict_parse_decision(valid_decision, 123)
    @test result.move == true
    @test result.move_coords == (5, 5)
    @test result.combat == false
    println("✅ Valid decision parsed correctly: move=$(result.move), coords=$(result.move_coords)")
  catch e
    @test false  # Should not error on valid input
    println("❌ Unexpected error: $(e)")
  end

  # Test 7: Error formatting
  println("\n7️⃣ Testing error formatting...")
  api_error = Sugarscape.SugarscapeLLM.LLMAPIError("Test API error", 401, "Unauthorized")
  formatted = Sugarscape.SugarscapeLLM.format_llm_error(api_error)
  @test contains(formatted, "LLM API Error")
  @test contains(formatted, "HTTP Status: 401")
  @test contains(formatted, "Unauthorized")
  println("✅ Error formatting works correctly")

  println("\n🎉 All strict error handling tests passed!")
  println("The system correctly fails fast with descriptive errors when use_llm_decisions=true")
end

# Run tests
if abspath(PROGRAM_FILE) == @__FILE__
  test_strict_error_handling()
end
