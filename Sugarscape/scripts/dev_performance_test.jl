using Sugarscape, BenchmarkTools, Statistics

function benchmark_llm_integration()
    println("=== LLM Integration Performance Benchmark ===")

    # Test different model sizes
    sizes = [(10, 10), (20, 20), (30, 30)]
    agent_counts = [25, 100, 225]

    for (size, agents) in zip(sizes, agent_counts)
        println("\n--- Testing $(size[1])x$(size[2]) grid with $agents agents ---")

        model = Sugarscape.sugarscape(
            use_llm_decisions = true,
            N = agents,
            dims = size,
            llm_temperature = 0.0
        )

        # Benchmark LLM decision population
        println("Benchmarking LLM decision population...")
        b1 = @benchmark Sugarscape.populate_llm_decisions!($model)
        println("  Time: $(mean(b1.times) / 1e6) ms")
        println("  Memory: $(b1.memory / 1024) KB")

        # Benchmark full simulation step
        println("Benchmarking full simulation step...")
        b2 = @benchmark step!($model, 1)
        println("  Time: $(mean(b2.times) / 1e6) ms")
        println("  Memory: $(b2.memory / 1024) KB")

        # Benchmark multiple steps
        println("Benchmarking 10 simulation steps...")
        b3 = @benchmark step!($model, 10)
        println("  Time: $(mean(b3.times) / 1e6) ms")
        println("  Memory: $(b3.memory / 1024) KB")
    end
end

function benchmark_prompt_complexity()
    println("\n=== Prompt Complexity Benchmark ===")

    model = Sugarscape.sugarscape(
        use_llm_decisions = true,
        N = 50,
        dims = (25, 25)
    )

    # Test different temperature settings
    temperatures = [0.0, 0.2, 0.5, 1.0]

    for temp in temperatures
        println("\n--- Testing temperature $temp ---")
        model.llm_temperature = temp

        b = @benchmark Sugarscape.populate_llm_decisions!($model)
        println("  Time: $(mean(b.times) / 1e6) ms")
        println("  Memory: $(b.memory / 1024) KB")
    end
end

function benchmark_comparison()
    println("\n=== LLM vs Rule-based Comparison ===")
    
    # Create models with and without LLM
    model_llm = Sugarscape.sugarscape(
        use_llm_decisions = true,
        N = 100,
        dims = (20, 20),
        llm_temperature = 0.0
    )
    
    model_rules = Sugarscape.sugarscape(
        use_llm_decisions = false,
        N = 100,
        dims = (20, 20)
    )
    
    println("\n--- LLM-based decisions ---")
    b_llm = @benchmark step!($model_llm, 1)
    println("  Time: $(mean(b_llm.times) / 1e6) ms")
    println("  Memory: $(b_llm.memory / 1024) KB")
    
    println("\n--- Rule-based decisions ---")
    b_rules = @benchmark step!($model_rules, 1)
    println("  Time: $(mean(b_rules.times) / 1e6) ms")
    println("  Memory: $(b_rules.memory / 1024) KB")
    
    speedup = mean(b_llm.times) / mean(b_rules.times)
    println("\n--- Performance Comparison ---")
    println("  LLM is $(round(speedup, digits=2))x slower than rule-based")
    println("  Memory overhead: $(round((b_llm.memory - b_rules.memory) / 1024, digits=2)) KB")
end

# Run benchmarks
if haskey(ENV, "OPENAI_API_KEY")
    benchmark_llm_integration()
    benchmark_prompt_complexity()
    benchmark_comparison()
else
    println("ERROR: Set OPENAI_API_KEY environment variable for performance testing")
end
