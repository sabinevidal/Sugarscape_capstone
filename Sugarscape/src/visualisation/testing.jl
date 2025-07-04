using Sugarscape, JSON

"""
    test_single_agent_llm_prompt(; model_kwargs...)

Test LLM prompt functionality with a single agent in a minimal environment.

Creates a 1-agent model on a 5x5 grid with deterministic LLM settings for focused testing.
Provides detailed API response analysis including context building, raw responses,
and both strict and safe parsing methods.

# Arguments
- `model_kwargs...`: Additional arguments to pass to the sugarscape model constructor

# Returns
- `(context, response, decision)` tuple if successful, `(nothing, nothing, nothing)` if error

# Example
```julia
ctx, resp, decision = test_single_agent_llm_prompt()
```
"""
function test_single_agent_llm_prompt(; model_kwargs...)
  println("=== Single Agent LLM Prompt Test ===")

  # Check API key
  if !haskey(ENV, "OPENAI_API_KEY")
    println("❌ OPENAI_API_KEY not set")
    return nothing, nothing, nothing
  end

  # Create minimal model for focused testing
  default_kwargs = (
    use_llm_decisions=true,
    N=1,
    dims=(5, 5),
    llm_temperature=0.0,  # Deterministic for testing
    enable_combat=true,
    enable_reproduction=true,
    enable_credit=true
  )

  # Merge with user-provided kwargs
  merged_kwargs = merge(default_kwargs, model_kwargs)

  println("Creating minimal test model:")
  println("  - Agents: $(merged_kwargs.N)")
  println("  - Grid: $(merged_kwargs.dims)")
  println("  - Temperature: $(merged_kwargs.llm_temperature)")
  println("  - Combat: $(merged_kwargs.enable_combat)")
  println("  - Reproduction: $(merged_kwargs.enable_reproduction)")
  println("  - Credit: $(merged_kwargs.enable_credit)")

  m = sugarscape(; merged_kwargs...)
  ag = first(allagents(m))

  # Build and display agent context
  println("\n--- BUILDING AGENT CONTEXT ---")
  ctx = SugarscapeLLM.build_agent_context(ag, m)

  println("Agent Context:")
  println(JSON.json(ctx, 2))

  # Make API call and analyze response
  println("\n--- MAKING API CALL ---")
  local resp, decision

  try
    resp = SugarscapeLLM.call_openai_api(ctx, m)

    println("\n--- RAW API RESPONSE ---")
    println(JSON.json(resp, 2))

    # Parse and validate with strict parsing
    println("\n--- STRICT PARSING ---")
    decision = SugarscapeLLM._strict_parse_decision(resp, ag.id)
    println("✅ Strict parsing successful:")
    println("   Decision: $decision")

    # Also show safe parsing for comparison
    println("\n--- SAFE PARSING (for comparison) ---")
    safe_decision = SugarscapeLLM._safe_parse_decision(resp)
    println("Safe parsing result: $safe_decision")

    # Compare the two approaches
    println("\n--- PARSING COMPARISON ---")
    if decision == safe_decision
      println("✅ Both parsing methods produced identical results")
    else
      println("⚠️  Parsing methods produced different results:")
      println("   Strict: $decision")
      println("   Safe:   $safe_decision")
    end

  catch e
    println("\n--- ERROR OCCURRED ---")
    formatted_error = SugarscapeLLM.format_llm_error(e)
    println("❌ $formatted_error")
    println("\nThis demonstrates strict error handling when use_llm_decisions=true")
    println("The system fails fast rather than using fallback values.")
    return nothing, nothing, nothing
  end

  println("\n--- TEST SUMMARY ---")
  println("✅ Single agent LLM prompt test completed successfully")
  println("✅ Context building: Working")
  println("✅ API communication: Working")
  println("✅ Response parsing: Working")
  println("✅ Error handling: Demonstrated")

  return ctx, resp, decision
end

"""
    run_llm_prompt_test_interactive()

Run the single agent LLM prompt test in an interactive mode.
Displays results and waits for user input between sections.
"""
function run_llm_prompt_test_interactive()
  println("🧪 Interactive LLM Prompt Testing")
  println("This test will:")
  println("  1. Create a minimal 1-agent model")
  println("  2. Build LLM context for the agent")
  println("  3. Make an API call to OpenAI")
  println("  4. Parse and validate the response")
  println("  5. Compare strict vs safe parsing")
  println()

  print("Press Enter to continue...")
  readline()

  ctx, resp, decision = test_single_agent_llm_prompt()

  if ctx !== nothing
    println("\n🎉 Test completed successfully!")
    println("You can now inspect the returned values:")
    println("  - ctx: Agent context sent to LLM")
    println("  - resp: Raw API response")
    println("  - decision: Parsed decision object")
  else
    println("\n❌ Test failed - check your OPENAI_API_KEY and try again")
  end

  println()
  print("Press Enter to return to menu...")
  readline()

  return ctx, resp, decision
end
