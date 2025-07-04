using Sugarscape, Statistics, DataFrames, GLMakie, CSV, Dates

"""
    PerformanceTestResult

Structure to store performance test results.
"""
struct PerformanceTestResult
  scenario::String
  agents::Int
  dimensions::Tuple{Int,Int}
  steps::Int
  total_time::Float64
  steps_per_second::Float64
  memory_usage_mb::Float64
  llm_calls::Int
  llm_avg_time::Float64
  errors::Vector{String}
end

"""
    run_llm_performance_test(; scenarios=nothing, steps=100, verbose=true)

Run comprehensive LLM performance tests across different scenarios.

# Arguments
- `scenarios::Vector{NamedTuple}`: Custom scenarios to test (optional)
- `steps::Int=100`: Number of steps to run each scenario
- `verbose::Bool=true`: Whether to print detailed progress

# Returns
- `Vector{PerformanceTestResult}`: Results for each scenario

# Example
```julia
results = run_llm_performance_test(steps=50)
```
"""
function run_llm_performance_test(; scenarios=nothing, steps=100, verbose=true)

  if !haskey(ENV, "OPENAI_API_KEY")
    error("OPENAI_API_KEY not set. Required for LLM performance testing.")
  end

  # Default scenarios if none provided
  if scenarios === nothing
    scenarios = [
      (name="Small LLM", agents=20, dims=(15, 15), llm=true),
      (name="Medium LLM", agents=50, dims=(25, 25), llm=true),
      (name="Large LLM", agents=100, dims=(35, 35), llm=true),
      (name="Small Standard", agents=20, dims=(15, 15), llm=false),
      (name="Medium Standard", agents=50, dims=(25, 25), llm=false),
      (name="Large Standard", agents=100, dims=(35, 35), llm=false),
    ]
  end

  results = PerformanceTestResult[]

  verbose && println("🚀 Starting LLM Performance Test Suite")
  verbose && println("   - Testing $(length(scenarios)) scenarios")
  verbose && println("   - $(steps) steps per scenario")
  verbose && println("   - LLM Temperature: 0.2")
  verbose && println()

  for (i, scenario) in enumerate(scenarios)
    verbose && println("📊 Scenario $(i)/$(length(scenarios)): $(scenario.name)")
    verbose && println("   Agents: $(scenario.agents) | Grid: $(scenario.dims) | LLM: $(scenario.llm)")

    # Record start time and memory
    start_time = time()
    start_memory = Base.gc_live_bytes()

    # Track LLM calls
    llm_calls = 0
    llm_total_time = 0.0
    errors = String[]

    try
      # Create model
      model = sugarscape(
        N=scenario.agents,
        dims=scenario.dims,
        use_llm_decisions=scenario.llm,
        llm_temperature=0.2,
        enable_combat=true,
        enable_reproduction=true,
        enable_credit=true
      )

      # Run simulation
      for step in 1:steps
        if verbose && step % 20 == 0
          print(".")
        end

        # Time LLM calls if enabled
        if scenario.llm
          llm_step_start = time()
          step!(model, sugarscape_agent_step!, sugarscape_model_step!)
          llm_step_time = time() - llm_step_start

          # Count LLM calls (approximate)
          if haskey(model, :llm_decisions)
            llm_calls += length(model.llm_decisions)
          end
          llm_total_time += llm_step_time
        else
          step!(model, sugarscape_agent_step!, sugarscape_model_step!)
        end
      end

      verbose && println()

    catch e
      push!(errors, string(e))
      verbose && println("\n   ❌ Error: $(e)")
    end

    # Calculate metrics
    end_time = time()
    end_memory = Base.gc_live_bytes()

    total_time = end_time - start_time
    steps_per_second = steps / total_time
    memory_usage_mb = (end_memory - start_memory) / (1024 * 1024)
    llm_avg_time = llm_calls > 0 ? llm_total_time / llm_calls : 0.0

    result = PerformanceTestResult(
      scenario.name,
      scenario.agents,
      scenario.dims,
      steps,
      total_time,
      steps_per_second,
      memory_usage_mb,
      llm_calls,
      llm_avg_time,
      errors
    )

    push!(results, result)

    if verbose
      println("   ✅ Completed: $(round(total_time, digits=2))s")
      println("   📈 $(round(steps_per_second, digits=1)) steps/sec")
      println("   💾 $(round(memory_usage_mb, digits=1)) MB memory")
      if scenario.llm
        println("   🤖 $(llm_calls) LLM calls, $(round(llm_avg_time*1000, digits=1))ms avg")
      end
      println()
    end
  end

  verbose && println("🎉 Performance test completed!")
  return results
end

"""
    create_performance_comparison_dashboard(results::Vector{PerformanceTestResult})

Create a dashboard comparing performance test results.

# Arguments
- `results::Vector{PerformanceTestResult}`: Results from performance tests

# Returns
- `GLMakie.Figure`: Interactive comparison dashboard

# Example
```julia
results = run_llm_performance_test()
fig = create_performance_comparison_dashboard(results)
```
"""
function create_performance_comparison_dashboard(results::Vector{PerformanceTestResult})

  # Create figure
  fig = Figure(size=(1400, 1000))

  # Extract data for plotting
  scenarios = [r.scenario for r in results]
  agents = [r.agents for r in results]
  steps_per_sec = [r.steps_per_second for r in results]
  memory_mb = [r.memory_usage_mb for r in results]
  llm_calls = [r.llm_calls for r in results]
  llm_avg_time = [r.llm_avg_time * 1000 for r in results]  # Convert to ms

  # Separate LLM vs Standard scenarios
  llm_scenarios = [i for (i, r) in enumerate(results) if r.llm_calls > 0]
  std_scenarios = [i for (i, r) in enumerate(results) if r.llm_calls == 0]

  # Performance comparison bar chart
  ax1 = Axis(fig[1, 1],
    title="Steps per Second Comparison",
    xlabel="Scenario",
    ylabel="Steps/sec")

  # Color-code LLM vs Standard
  colors = [r.llm_calls > 0 ? :red : :blue for r in results]
  barplot!(ax1, 1:length(scenarios), steps_per_sec,
    color=colors, strokecolor=:black, strokewidth=1)

  # Add legend
  llm_patch = PolyElement(color=:red, strokecolor=:black)
  std_patch = PolyElement(color=:blue, strokecolor=:black)
  Legend(fig[1, 2], [llm_patch, std_patch], ["LLM Enabled", "Standard"],
    "Performance Type")

  # Memory usage comparison
  ax2 = Axis(fig[2, 1],
    title="Memory Usage Comparison",
    xlabel="Scenario",
    ylabel="Memory (MB)")

  barplot!(ax2, 1:length(scenarios), memory_mb,
    color=colors, strokecolor=:black, strokewidth=1)

  # LLM-specific metrics (if any LLM scenarios exist)
  if !isempty(llm_scenarios)
    ax3 = Axis(fig[2, 2],
      title="LLM Call Performance",
      xlabel="Scenario",
      ylabel="Avg Time (ms)")

    llm_indices = llm_scenarios
    llm_avg_times = [llm_avg_time[i] for i in llm_indices]
    llm_names = [scenarios[i] for i in llm_indices]

    barplot!(ax3, 1:length(llm_indices), llm_avg_times,
      color=:orange, strokecolor=:black, strokewidth=1)

    # Set x-axis labels
    ax3.xticks = (1:length(llm_indices), llm_names)
    ax3.xticklabelrotation = π / 4
  end

  # Agent count vs Performance scatter
  ax4 = Axis(fig[3, 1:2],
    title="Agent Count vs Performance",
    xlabel="Number of Agents",
    ylabel="Steps per Second")

  # Scatter plot with different markers for LLM vs Standard
  llm_agents = [agents[i] for i in llm_scenarios]
  llm_perf = [steps_per_sec[i] for i in llm_scenarios]
  std_agents = [agents[i] for i in std_scenarios]
  std_perf = [steps_per_sec[i] for i in std_scenarios]

  if !isempty(llm_scenarios)
    scatter!(ax4, llm_agents, llm_perf,
      color=:red, marker=:circle, markersize=12, label="LLM")
  end

  if !isempty(std_scenarios)
    scatter!(ax4, std_agents, std_perf,
      color=:blue, marker=:diamond, markersize=12, label="Standard")
  end

  if !isempty(llm_scenarios) && !isempty(std_scenarios)
    axislegend(ax4, position=:rt)
  end

  # Set x-axis labels for main charts
  ax1.xticks = (1:length(scenarios), scenarios)
  ax1.xticklabelrotation = π / 4
  ax2.xticks = (1:length(scenarios), scenarios)
  ax2.xticklabelrotation = π / 4

  # Add summary statistics
  summary_text = create_performance_summary(results)
  fig[4, 1:2] = Label(fig, summary_text,
    tellheight=false, fontsize=11,
    halign=:left, valign=:top, justification=:left)

  # Add title
  fig[0, :] = Label(fig, "LLM Performance Analysis Dashboard",
    fontsize=16, font=:bold)

  return fig
end

"""
    create_performance_summary(results::Vector{PerformanceTestResult})

Create a text summary of performance test results.
"""
function create_performance_summary(results::Vector{PerformanceTestResult})

  llm_results = [r for r in results if r.llm_calls > 0]
  std_results = [r for r in results if r.llm_calls == 0]

  summary = "Performance Test Summary\n\n"

  if !isempty(llm_results)
    llm_avg_perf = mean([r.steps_per_second for r in llm_results])
    llm_avg_memory = mean([r.memory_usage_mb for r in llm_results])
    llm_avg_call_time = mean([r.llm_avg_time * 1000 for r in llm_results])

    summary *= "LLM-Enabled Scenarios:\n"
    summary *= "  • Average Performance: $(round(llm_avg_perf, digits=1)) steps/sec\n"
    summary *= "  • Average Memory: $(round(llm_avg_memory, digits=1)) MB\n"
    summary *= "  • Average LLM Call Time: $(round(llm_avg_call_time, digits=1))ms\n\n"
  end

  if !isempty(std_results)
    std_avg_perf = mean([r.steps_per_second for r in std_results])
    std_avg_memory = mean([r.memory_usage_mb for r in std_results])

    summary *= "Standard Scenarios:\n"
    summary *= "  • Average Performance: $(round(std_avg_perf, digits=1)) steps/sec\n"
    summary *= "  • Average Memory: $(round(std_avg_memory, digits=1)) MB\n\n"
  end

  if !isempty(llm_results) && !isempty(std_results)
    llm_avg_perf = mean([r.steps_per_second for r in llm_results])
    std_avg_perf = mean([r.steps_per_second for r in std_results])
    performance_overhead = (std_avg_perf - llm_avg_perf) / std_avg_perf * 100

    summary *= "Performance Impact:\n"
    summary *= "  • LLM Overhead: $(round(performance_overhead, digits=1))% slower\n"
    summary *= "  • Performance Ratio: $(round(std_avg_perf/llm_avg_perf, digits=1)):1\n\n"
  end

  # Error summary
  all_errors = vcat([r.errors for r in results]...)
  if !isempty(all_errors)
    summary *= "Errors Encountered: $(length(all_errors))\n"
    for (i, error) in enumerate(unique(all_errors))
      summary *= "  $(i). $(error)\n"
    end
  else
    summary *= "No errors encountered ✅\n"
  end

  return summary
end

"""
    export_performance_results(results::Vector{PerformanceTestResult}, filename::String)

Export performance test results to CSV.

# Arguments
- `results::Vector{PerformanceTestResult}`: Results to export
- `filename::String`: Output filename (optional, defaults to timestamp)

# Example
```julia
results = run_llm_performance_test()
export_performance_results(results, "performance_test_results.csv")
```
"""
function export_performance_results(results::Vector{PerformanceTestResult}, filename::String="")

  if isempty(filename)
    timestamp = Dates.format(Dates.now(), "yyyymmdd_HHMMSS")
    filename = "performance_test_$(timestamp).csv"
  end

  # Create results directory if it doesn't exist
  results_dir = normpath(joinpath(@__DIR__, "..", "..", "data", "results"))
  if !isdir(results_dir)
    mkpath(results_dir)
  end

  filepath = joinpath(results_dir, filename)

  # Convert to DataFrame
  df = DataFrame(
    scenario=[r.scenario for r in results],
    agents=[r.agents for r in results],
    dimensions_x=[r.dimensions[1] for r in results],
    dimensions_y=[r.dimensions[2] for r in results],
    steps=[r.steps for r in results],
    total_time_sec=[r.total_time for r in results],
    steps_per_second=[r.steps_per_second for r in results],
    memory_usage_mb=[r.memory_usage_mb for r in results],
    llm_calls=[r.llm_calls for r in results],
    llm_avg_time_ms=[r.llm_avg_time * 1000 for r in results],
    errors=[join(r.errors, "; ") for r in results]
  )

  CSV.write(filepath, df)

  println("📁 Performance results exported to: $(abspath(filepath))")
  println("   - $(nrow(df)) scenarios")
  println("   - $(sum(df.llm_calls)) total LLM calls")

  return filepath
end

"""
    run_performance_test_interactive()

Run performance tests with interactive menu and dashboard.
"""
function run_performance_test_interactive()

  println("🏃 LLM Performance Test Suite")
  println("This will test LLM vs Standard performance across different scenarios.")
  println()

  # Check API key
  if !haskey(ENV, "OPENAI_API_KEY")
    println("❌ OPENAI_API_KEY not set")
    println("Please set up your OpenAI API key before running LLM tests.")
    return
  end

  println("API Key: ✅ Found")
  println()

  # Ask for test parameters
  print("Enter number of steps per scenario (default 100): ")
  steps_input = readline()
  steps = isempty(steps_input) ? 100 : parse(Int, steps_input)

  println("Running performance tests with $(steps) steps per scenario...")
  println()

  # Run tests
  results = run_llm_performance_test(steps=steps)

  # Export results
  filepath = export_performance_results(results)

  # Create dashboard
  println("Creating performance comparison dashboard...")
  fig = create_performance_comparison_dashboard(results)

  println("✅ Performance test completed!")
  println("   - Results exported to: $(filepath)")
  println("   - Dashboard created")
  println()

  print("Press Enter to return to menu...")
  readline()

  return results, fig
end
