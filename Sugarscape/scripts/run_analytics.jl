#!/usr/bin/env julia

"""
Analytics Pipeline Example for Sugarscape Model

This script demonstrates how to use the comprehensive analytics pipeline
with the Sugarscape model, including:
- Setting up analytics with various metrics
- Running simulations with data collection
- Exporting results to CSV
- Creating summary reports
- Comparing different experimental conditions
"""

# Set up environment
using Pkg
Pkg.activate(".")

using Sugarscape
using Agents
using DataFrames
using CSV
using Statistics
using Plots
using Random

# Include analytics module
include("../src/visualisation/analytics.jl")

# =============================================================================
# EXAMPLE 1: Basic Analytics Setup and Single Run
# =============================================================================

function example_basic_analytics()
  println("🔬 Example 1: Basic Analytics Setup")

  # Create a model with some rules enabled
  model = sugarscape(;
    dims=(20, 20),
    N=50,
    enable_reproduction=true,
    enable_culture=true,
    enable_combat=false,
    enable_credit=false,
    enable_disease=false,
    use_llm_decisions=false,
    seed=42
  )

  # Set up analytics pipeline
  adata, mdata, analytics = create_analytics_pipeline(model;
    export_dir="data/results",
    export_prefix="basic_example",
    collect_individual_data=false,
    collect_distributions=true,
    collect_network_metrics=true
  )

  # Run simulation for 100 steps
  println("Running simulation for 100 steps...")
  for step in 1:100
    step!(model)

    # Collect data every 10 steps
    if step % 10 == 0
      # Collect agent data
      agent_data = Dict()
      for (i, (afunc, reducer)) in enumerate(adata)
        agents_subset = filter(afunc, collect(allagents(model)))
        agent_data["metric_$i"] = reducer(agents_subset)
      end

      # Collect model data
      model_data = Dict()
      for (i, mfunc) in enumerate(mdata)
        model_data["metric_$i"] = mfunc(model)
      end

      # Export data
      export_analytics_data(analytics, step, agent_data, model_data)

      if step % 50 == 0
        println("  Step $step: $(nagents(model)) agents, Gini: $(round(calculate_gini_coefficient(model), digits=3))")
      end
    end
  end

  # Create summary report
  report = create_summary_report(analytics)
  println("\n" * report)

  # Export final results
  export_to_csv(analytics)
  println("✅ Results exported to $(analytics.export_dir)")

  return analytics
end

# =============================================================================
# EXAMPLE 2: Comparative Analysis with Effect Sizes
# =============================================================================

function example_comparative_analysis()
  println("\n🔬 Example 2: Comparative Analysis")

  # Define experimental conditions
  conditions = [
    (name="Control", params=(enable_combat=false, enable_credit=false)),
    (name="Combat", params=(enable_combat=true, enable_credit=false)),
    (name="Credit", params=(enable_combat=false, enable_credit=true)),
    (name="Both", params=(enable_combat=true, enable_credit=true))
  ]

  results = Dict()

  for (condition_name, params) in conditions
    println("Running condition: $condition_name")

    # Run multiple replicates
    gini_values = Float64[]
    population_values = Float64[]

    for replicate in 1:5
      # Create model with specific parameters
      model = sugarscape(;
        dims=(15, 15),
        N=40,
        enable_reproduction=true,
        enable_culture=true,
        use_llm_decisions=false,
        params...,
        seed=42 + replicate
      )

      # Run simulation
      for step in 1:200
        step!(model)
      end

      # Collect final metrics
      push!(gini_values, calculate_gini_coefficient(model))
      push!(population_values, float(nagents(model)))
    end

    results[condition_name] = Dict(
      "gini" => gini_values,
      "population" => population_values
    )

    println("  Mean Gini: $(round(mean(gini_values), digits=3)) ± $(round(std(gini_values), digits=3))")
    println("  Mean Population: $(round(mean(population_values), digits=1)) ± $(round(std(population_values), digits=1))")
  end

  # Calculate effect sizes
  println("\nEffect Size Analysis:")
  control_gini = results["Control"]["gini"]

  for condition_name in ["Combat", "Credit", "Both"]
    treatment_gini = results[condition_name]["gini"]
    effect_sizes = calculate_effect_sizes(treatment_gini, control_gini)

    println("$condition_name vs Control:")
    println("  Hedges' g: $(round(effect_sizes["hedges_g"], digits=3))")
    println("  95% CI: [$(round(effect_sizes["ci_lower"], digits=3)), $(round(effect_sizes["ci_upper"], digits=3))]")

    # Interpret effect size
    abs_effect = abs(effect_sizes["hedges_g"])
    interpretation = if abs_effect < 0.2
      "negligible"
    elseif abs_effect < 0.5
      "small"
    elseif abs_effect < 0.8
      "medium"
    else
      "large"
    end
    println("  Interpretation: $interpretation effect")
  end

  return results
end

# =============================================================================
# EXAMPLE 3: Distribution Evolution Analysis
# =============================================================================

function example_distribution_evolution()
  println("\n🔬 Example 3: Distribution Evolution Analysis")

  # Create model with all features enabled
  model = sugarscape(;
    dims=(25, 25),
    N=100,
    enable_reproduction=true,
    enable_culture=true,
    enable_combat=true,
    enable_credit=true,
    enable_disease=true,
    use_llm_decisions=false,
    seed=12345
  )

  # Set up analytics with detailed tracking
  adata, mdata, analytics = create_analytics_pipeline(model;
    export_dir="data/results",
    export_prefix="distribution_evolution",
    collect_individual_data=true,
    collect_distributions=true,
    collect_network_metrics=true
  )

  # Track evolution over time
  time_series = Dict(
    "gini" => Float64[],
    "pareto_alpha" => Float64[],
    "top_1_percent" => Float64[],
    "top_10_percent" => Float64[],
    "cultural_entropy" => Float64[],
    "network_density" => Float64[]
  )

  println("Tracking distribution evolution over 500 steps...")

  for step in 1:500
    step!(model)

    # Collect detailed metrics every 25 steps
    if step % 25 == 0
      push!(time_series["gini"], calculate_gini_coefficient(model))
      push!(time_series["pareto_alpha"], calculate_pareto_alpha(model))
      push!(time_series["top_1_percent"], calculate_top_wealth_share(model, 0.01))
      push!(time_series["top_10_percent"], calculate_top_wealth_share(model, 0.10))
      push!(time_series["cultural_entropy"], calculate_cultural_entropy(model))

      network_metrics = calculate_credit_network_metrics(model)
      push!(time_series["network_density"], get(network_metrics, "density", 0.0))

      if step % 100 == 0
        println("  Step $step: Gini=$(round(time_series["gini"][end], digits=3)), " *
                "Pareto α=$(round(time_series["pareto_alpha"][end], digits=2)), " *
                "Top 1%=$(round(time_series["top_1_percent"][end], digits=3))")
      end
    end
  end

  # Create evolution plots
  println("Creating evolution plots...")

  steps = 25:25:500

  # Wealth inequality evolution
  p1 = plot(steps, time_series["gini"],
    title="Wealth Inequality Evolution",
    xlabel="Time Steps",
    ylabel="Gini Coefficient",
    legend=false,
    linewidth=2)

  # Pareto alpha evolution
  p2 = plot(steps, time_series["pareto_alpha"],
    title="Pareto α Evolution",
    xlabel="Time Steps",
    ylabel="Pareto α",
    legend=false,
    linewidth=2)

  # Top wealth shares
  p3 = plot(steps, time_series["top_1_percent"],
    label="Top 1%",
    linewidth=2)
  plot!(p3, steps, time_series["top_10_percent"],
    label="Top 10%",
    linewidth=2)
  plot!(p3, title="Wealth Concentration",
    xlabel="Time Steps",
    ylabel="Share of Total Wealth")

  # Cultural entropy
  p4 = plot(steps, time_series["cultural_entropy"],
    title="Cultural Entropy",
    xlabel="Time Steps",
    ylabel="Entropy",
    legend=false,
    linewidth=2)

  # Combine plots
  combined_plot = plot(p1, p2, p3, p4, layout=(2, 2), size=(800, 600))
  savefig(combined_plot, "data/results/distribution_evolution.png")
  println("📊 Evolution plots saved to data/results/distribution_evolution.png")

  # Export time series data
  df = DataFrame(time_series)
  df.step = steps
  CSV.write("data/results/time_series_evolution.csv", df)
  println("📈 Time series data exported to data/results/time_series_evolution.csv")

  return time_series
end

# =============================================================================
# EXAMPLE 4: Network Analysis Deep Dive
# =============================================================================

function example_network_analysis()
  println("\n🔬 Example 4: Network Analysis Deep Dive")

  # Create model with strong network effects
  model = sugarscape(;
    dims=(20, 20),
    N=80,
    enable_reproduction=true,
    enable_culture=true,
    enable_combat=true,
    enable_credit=true,
    enable_disease=false,
    use_llm_decisions=false,
    seed=98765
  )

  # Track network evolution
  network_evolution = Dict(
    "credit_nodes" => Int[],
    "credit_edges" => Int[],
    "credit_density" => Float64[],
    "credit_avg_degree" => Float64[],
    "combat_conflicts" => Int[],
    "combat_rate" => Float64[],
    "cultural_distance" => Float64[]
  )

  println("Analysing network evolution over 300 steps...")

  for step in 1:300
    step!(model)

    if step % 20 == 0
      # Credit network metrics
      credit_metrics = calculate_credit_network_metrics(model)
      push!(network_evolution["credit_nodes"], get(credit_metrics, "n_nodes", 0))
      push!(network_evolution["credit_edges"], get(credit_metrics, "n_edges", 0))
      push!(network_evolution["credit_density"], get(credit_metrics, "density", 0.0))
      push!(network_evolution["credit_avg_degree"], get(credit_metrics, "avg_degree", 0.0))

      # Combat network metrics
      combat_metrics = calculate_combat_network_metrics(model)
      push!(network_evolution["combat_conflicts"], get(combat_metrics, "potential_conflicts", 0))
      push!(network_evolution["combat_rate"], get(combat_metrics, "conflict_rate", 0.0))
      push!(network_evolution["cultural_distance"], get(combat_metrics, "avg_cultural_distance", 0.0))

      if step % 60 == 0
        println("  Step $step: Credit density=$(round(network_evolution["credit_density"][end], digits=3)), " *
                "Conflict rate=$(round(network_evolution["combat_rate"][end], digits=3))")
      end
    end
  end

  # Network analysis plots
  steps = 20:20:300

  # Credit network evolution
  p1 = plot(steps, network_evolution["credit_density"],
    title="Credit Network Density",
    xlabel="Time Steps",
    ylabel="Network Density",
    legend=false,
    linewidth=2)

  # Combat potential
  p2 = plot(steps, network_evolution["combat_rate"],
    title="Conflict Potential",
    xlabel="Time Steps",
    ylabel="Conflict Rate",
    legend=false,
    linewidth=2)

  # Cultural distance
  p3 = plot(steps, network_evolution["cultural_distance"],
    title="Cultural Distance",
    xlabel="Time Steps",
    ylabel="Average Distance",
    legend=false,
    linewidth=2)

  # Combined network plot
  network_plot = plot(p1, p2, p3, layout=(1, 3), size=(900, 300))
  savefig(network_plot, "data/results/network_evolution.png")
  println("🌐 Network evolution plots saved to data/results/network_evolution.png")

  # Export network data
  network_df = DataFrame(network_evolution)
  network_df.step = steps
  CSV.write("data/results/network_evolution.csv", network_df)
  println("🔗 Network data exported to data/results/network_evolution.csv")

  return network_evolution
end

# =============================================================================
# MAIN EXECUTION
# =============================================================================

function main()
  println("🚀 Sugarscape Analytics Pipeline Examples")
  println("="^50)

  # Ensure results directory exists
  mkpath("data/results")

  # Run examples
  try
    println("\n📊 Running analytics examples...")

    # Example 1: Basic analytics
    analytics1 = example_basic_analytics()

    # Example 2: Comparative analysis
    results2 = example_comparative_analysis()

    # Example 3: Distribution evolution
    evolution3 = example_distribution_evolution()

    # Example 4: Network analysis
    network4 = example_network_analysis()

    println("\n✅ All examples completed successfully!")
    println("\nResults saved to:")
    println("  - data/results/basic_example_metrics.csv")
    println("  - data/results/distribution_evolution.png")
    println("  - data/results/time_series_evolution.csv")
    println("  - data/results/network_evolution.png")
    println("  - data/results/network_evolution.csv")

    println("\n🎯 Key Findings Summary:")
    println("  - Basic analytics pipeline successfully captures comprehensive metrics")
    println("  - Effect size analysis enables robust experimental comparisons")
    println("  - Distribution evolution tracking reveals inequality dynamics")
    println("  - Network analysis provides insights into social structure formation")

  catch e
    println("\n❌ Error running examples: $e")
    println("Make sure you're in the Sugarscape directory and have activated the environment")
    rethrow(e)
  end
end

# Run if script is called directly
if abspath(PROGRAM_FILE) == @__FILE__
  main()
end
