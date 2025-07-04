using Sugarscape, JSON

function test_single_agent_prompt()
    println("=== Single Agent LLM Prompt Test ===")

    # Create minimal model
    m = Sugarscape.sugarscape(
        use_llm_decisions=true,
        N=1,
        dims=(5, 5),
        llm_temperature=0.0,  # Deterministic for testing
        enable_combat=true,
        enable_reproduction=true,
        enable_credit=true
    )

    ag = first(Sugarscape.allagents(m))

    # Build context
    ctx = Sugarscape.SugarscapeLLM.build_agent_context(ag, m)

    println("\n--- AGENT CONTEXT ---")
    println(JSON.json(ctx, 2))

    # Make API call
    println("\n--- API CALL ---")
    local resp, decision  # Declare variables in outer scope
    try
        resp = Sugarscape.SugarscapeLLM.call_openai_api(ctx, m)

        println("\n--- RAW RESPONSE ---")
        println(JSON.json(resp, 2))

        # Parse and validate with strict parsing
        println("\n--- STRICT PARSING ---")
        decision = Sugarscape.SugarscapeLLM._strict_parse_decision(resp, ag.id)
        println("✅ Successfully parsed: ", decision)

        # Also show safe parsing for comparison
        println("\n--- SAFE PARSING (for comparison) ---")
        safe_decision = Sugarscape.SugarscapeLLM._safe_parse_decision(resp)
        println("Safe version: ", safe_decision)

    catch e
        println("\n--- ERROR OCCURRED ---")
        formatted_error = Sugarscape.SugarscapeLLM.format_llm_error(e)
        println("❌ ", formatted_error)
        println("\nThis demonstrates strict error handling when use_llm_decisions=true")
        println("The system fails fast rather than using fallback values.")
        return nothing, nothing, nothing
    end

    return ctx, resp, decision
end

# Run test
if haskey(ENV, "OPENAI_API_KEY")
    test_single_agent_prompt()
else
    println("ERROR: Set OPENAI_API_KEY environment variable")
    exit(1)
end
