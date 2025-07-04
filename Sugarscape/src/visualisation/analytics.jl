"""
Analytics Pipeline for Sugarscape Model

This module provides comprehensive analytics for the Sugarscape model including:
- Wealth and lifespan distribution evolution
- Inequality metrics (Gini, Pareto α)
- Network analysis for credit/combat ties
- Effect size calculations with confidence intervals
- CSV export and live plotting support

Uses Agents.jl aggregate helpers for efficient data collection.
"""

using Agents
using Statistics
using DataFrames
using CSV
using Distributions
using StatsBase
using Random
using Dates

# Include the metrics module to use existing functions
include("../utils/metrics.jl")

# =============================================================================
# CORE ANALYTICS PIPELINE
# =============================================================================

"""
    Analytics

Struct to hold analytics configuration and state.
"""
mutable struct Analytics
  # Configuration
  export_dir::String
  export_prefix::String
  collect_individual_data::Bool
  collect_distributions::Bool
  collect_network_metrics::Bool

  # State tracking
  step_counter::Int
  metrics_history::Vector{Dict{String,Any}}
  individual_data_history::Vector{DataFrame}

  # Performance tracking
  computation_times::Dict{String,Vector{Float64}}

  function Analytics(;
    export_dir::String="data/results",
    export_prefix::String="sugarscape_$(Dates.format(now(), "yyyymmdd_HHMMSS"))",
    collect_individual_data::Bool=false,
    collect_distributions::Bool=true,
    collect_network_metrics::Bool=true
  )
    new(
      export_dir,
      export_prefix,
      collect_individual_data,
      collect_distributions,
      collect_network_metrics,
      0,
      Dict{String,Any}[],
      DataFrame[],
      Dict{String,Vector{Float64}}()
    )
  end
end

"""
    create_analytics_pipeline(model; kwargs...)

Create a comprehensive analytics pipeline for the Sugarscape model.
Returns a tuple of (agent_data_functions, model_data_functions, analytics_struct).
"""
function create_analytics_pipeline(model; kwargs...)
  analytics = Analytics(; kwargs...)

  # Create agent data collection functions using Agents.jl patterns
  adata = create_agent_data_functions(model, analytics)

  # Create model data collection functions
  mdata = create_model_data_functions(model, analytics)

  return adata, mdata, analytics
end

# =============================================================================
# AGENT DATA COLLECTION
# =============================================================================

"""
    create_agent_data_functions(model, analytics)

Create agent data collection functions for use with Agents.jl aggregate helpers.
"""
function create_agent_data_functions(model, analytics)
  # Basic wealth categories
  wealth_categories = [
    ("wealthy", a -> a.sugar > 20),
    ("medium_wealth", a -> 5 <= a.sugar <= 20),
    ("poor", a -> a.sugar < 5),
    ("extreme_poverty", a -> a.sugar < 1)
  ]

  # Age categories
  age_categories = [
    ("young", a -> a.age < 20),
    ("adult", a -> 20 <= a.age < 50),
    ("elderly", a -> a.age >= 50)
  ]

  # Demographic categories
  demographic_categories = [
    ("male", a -> a.sex == :male),
    ("female", a -> a.sex == :female),
    ("reproduced", a -> a.has_reproduced),
    ("has_children", a -> length(a.children) > 0),
    ("infected", a -> length(a.diseases) > 0)
  ]

  # Create the agent data collection list
  adata = []

  # Add wealth categories
  for (name, func) in wealth_categories
    push!(adata, (func, length))
    push!(adata, (func, a -> isempty(a) ? 0.0 : sum(agent.sugar for agent in a)))  # Total wealth in category
  end

  # Add age categories
  for (name, func) in age_categories
    push!(adata, (func, length))
    push!(adata, (func, a -> length(a) > 0 ? mean(agent.age for agent in a) : 0.0))  # Average age in category
  end

  # Add demographic categories
  for (name, func) in demographic_categories
    push!(adata, (func, length))
  end

  # Add wealth statistics
  push!(adata, (a -> true, a -> length(a) > 0 ? mean(agent.sugar for agent in a) : 0.0))  # Mean wealth
  push!(adata, (a -> true, a -> length(a) > 0 ? std(agent.sugar for agent in a) : 0.0))   # Wealth std
  push!(adata, (a -> true, a -> length(a) > 0 ? maximum(agent.sugar for agent in a) : 0.0))  # Max wealth
  push!(adata, (a -> true, a -> length(a) > 0 ? minimum(agent.sugar for agent in a) : 0.0))  # Min wealth

  # Add age statistics
  push!(adata, (a -> true, a -> length(a) > 0 ? mean(agent.age for agent in a) : 0.0))  # Mean age
  push!(adata, (a -> true, a -> length(a) > 0 ? std(agent.age for agent in a) : 0.0))   # Age std

  # Add lifespan statistics (for deceased agents)
  push!(adata, (a -> true, a -> calculate_mean_lifespan_deceased(model)))

  return adata
end

# =============================================================================
# MODEL DATA COLLECTION
# =============================================================================

"""
    create_model_data_functions(model, analytics)

Create model data collection functions for comprehensive metrics.
"""
function create_model_data_functions(model, analytics)
  mdata = [
    # Basic counts
    nagents,
    model -> model.deaths_starvation,
    model -> model.deaths_age,
    model -> model.births,
    model -> model.combat_kills,

    # Wealth metrics
    model -> calculate_gini_coefficient(model),
    model -> calculate_wealth_percentiles(model),
    model -> calculate_pareto_alpha(model),
    model -> calculate_wealth_concentration(model),

    # Lifespan metrics
    model -> calculate_mean_lifespan(model),
    model -> calculate_lifespan_inequality(model),

    # Cultural metrics
    model -> calculate_cultural_entropy(model),
    model -> calculate_cultural_diversity(model),

    # Network metrics
    model -> calculate_credit_network_metrics(model),
    model -> calculate_combat_network_metrics(model),

    # Environmental metrics
    model -> sum(model.sugar_values),
    model -> calculate_resource_depletion(model),

    # Distribution metrics
    model -> calculate_wealth_distribution_moments(model),
    model -> calculate_age_distribution_moments(model),

    # Inequality tail indices
    model -> calculate_top_wealth_share(model, 0.1),  # Top 10%
    model -> calculate_top_wealth_share(model, 0.01), # Top 1%

    # Disease metrics (if enabled)
    model -> calculate_disease_prevalence(model),
    model -> calculate_disease_diversity(model),

    # Credit metrics (if enabled)
    model -> calculate_total_credit_outstanding(model),
    model -> calculate_credit_default_rate(model),

    # Spatial metrics
    model -> calculate_spatial_segregation(model),
    model -> calculate_clustering_coefficient(model)
  ]

  return mdata
end

# =============================================================================
# WEALTH DISTRIBUTION ANALYSIS
# =============================================================================

"""
    calculate_gini_coefficient(model)

Calculate the Gini coefficient for wealth distribution.
"""
function calculate_gini_coefficient(model)
  agents_list = collect(allagents(model))
  length(agents_list) == 0 && return 0.0

  wealths = [a.sugar for a in agents_list]
  return gini_coefficient(wealths)
end

"""
    calculate_wealth_percentiles(model)

Calculate key wealth percentiles (25th, 50th, 75th, 90th, 95th, 99th).
"""
function calculate_wealth_percentiles(model)
  agents_list = collect(allagents(model))
  percentiles = [25, 50, 75, 90, 95, 99]

  result = Dict()
  for p in percentiles
    result["p$p"] = 0.0  # Default value
  end

  if length(agents_list) > 0
    wealths = [a.sugar for a in agents_list]
    for p in percentiles
      result["p$p"] = percentile(wealths, p)
    end
  end

  return result
end

"""
    calculate_pareto_alpha(model)

Calculate the Pareto α parameter for the wealth distribution tail.
Uses the top 20% of wealth holders.
"""
function calculate_pareto_alpha(model)
  agents_list = collect(allagents(model))
  length(agents_list) < 10 && return NaN  # Need sufficient data

  wealths = [a.sugar for a in agents_list]
  threshold = percentile(wealths, 80)  # Top 20%

  tail_wealths = filter(w -> w >= threshold, wealths)
  length(tail_wealths) < 5 && return NaN

  # Estimate Pareto α using Hill estimator
  log_ratios = log.(tail_wealths ./ threshold)
  alpha = 1.0 / mean(log_ratios)

  return alpha
end

"""
    calculate_wealth_concentration(model)

Calculate wealth concentration metrics (Herfindahl index, entropy).
"""
function calculate_wealth_concentration(model)
  agents_list = collect(allagents(model))
  length(agents_list) == 0 && return Dict("herfindahl" => 0.0, "entropy" => 0.0)

  wealths = [a.sugar for a in agents_list]
  total_wealth = sum(wealths)

  if total_wealth == 0
    return Dict("herfindahl" => 0.0, "entropy" => 0.0)
  end

  # Calculate shares
  shares = wealths ./ total_wealth

  # Herfindahl index
  herfindahl = sum(shares .^ 2)

  # Entropy (wealth concentration)
  entropy = -sum(s * log(s + 1e-10) for s in shares if s > 0)

  return Dict("herfindahl" => herfindahl, "entropy" => entropy)
end

"""
    calculate_top_wealth_share(model, fraction)

Calculate the share of total wealth held by the top fraction of agents.
"""
function calculate_top_wealth_share(model, fraction)
  agents_list = collect(allagents(model))
  length(agents_list) == 0 && return 0.0

  wealths = [a.sugar for a in agents_list]
  total_wealth = sum(wealths)
  total_wealth == 0 && return 0.0

  sorted_wealths = sort(wealths, rev=true)
  top_n = max(1, round(Int, fraction * length(sorted_wealths)))
  top_wealth = sum(sorted_wealths[1:top_n])

  return top_wealth / total_wealth
end

"""
    calculate_wealth_distribution_moments(model)

Calculate the first four moments of the wealth distribution.
"""
function calculate_wealth_distribution_moments(model)
  agents_list = collect(allagents(model))

  # Default values
  result = Dict("mean" => 0.0, "variance" => 0.0, "skewness" => 0.0, "kurtosis" => 0.0)

  if length(agents_list) > 0
    wealths = [a.sugar for a in agents_list]
    result["mean"] = mean(wealths)
    result["variance"] = var(wealths)
    result["skewness"] = skewness(wealths)
    result["kurtosis"] = kurtosis(wealths)
  end

  return result
end

# =============================================================================
# LIFESPAN ANALYSIS
# =============================================================================

"""
    calculate_mean_lifespan(model)

Calculate the mean age of all current agents.
"""
function calculate_mean_lifespan(model)
  agents_list = collect(allagents(model))
  length(agents_list) == 0 && return 0.0

  ages = [a.age for a in agents_list]
  return mean(ages)
end

"""
    calculate_mean_lifespan_deceased(model)

Calculate the mean lifespan of deceased agents.
"""
function calculate_mean_lifespan_deceased(model)
  total_deaths = model.deaths_starvation + model.deaths_age + model.combat_kills
  total_lifespan = model.total_lifespan_starvation + model.total_lifespan_age

  return total_deaths > 0 ? total_lifespan / total_deaths : 0.0
end

"""
    calculate_lifespan_inequality(model)

Calculate inequality in lifespans using Gini coefficient.
"""
function calculate_lifespan_inequality(model)
  agents_list = collect(allagents(model))
  length(agents_list) == 0 && return 0.0

  ages = [a.age for a in agents_list]
  return gini_coefficient(ages)
end

"""
    calculate_age_distribution_moments(model)

Calculate the first four moments of the age distribution.
"""
function calculate_age_distribution_moments(model)
  agents_list = collect(allagents(model))

  # Default values
  result = Dict("mean" => 0.0, "variance" => 0.0, "skewness" => 0.0, "kurtosis" => 0.0)

  if length(agents_list) > 0
    ages = [a.age for a in agents_list]
    result["mean"] = mean(ages)
    result["variance"] = var(ages)
    result["skewness"] = skewness(ages)
    result["kurtosis"] = kurtosis(ages)
  end

  return result
end

# =============================================================================
# CULTURAL ANALYSIS
# =============================================================================

"""
    calculate_cultural_entropy(model)

Calculate cultural entropy across all agents.
"""
function calculate_cultural_entropy(model)
  !model.enable_culture && return 0.0

  agents_list = collect(allagents(model))
  length(agents_list) == 0 && return 0.0

  # Count unique cultural patterns
  cultural_patterns = Dict{String,Int}()

  for agent in agents_list
    if length(agent.culture) > 0
      pattern = join(Int.(agent.culture), "")
      cultural_patterns[pattern] = get(cultural_patterns, pattern, 0) + 1
    end
  end

  isempty(cultural_patterns) && return 0.0

  # Calculate entropy
  total = sum(values(cultural_patterns))
  entropy = 0.0
  for count in values(cultural_patterns)
    p = count / total
    entropy -= p * log(p)
  end

  return entropy
end

"""
    calculate_cultural_diversity(model)

Calculate cultural diversity metrics.
"""
function calculate_cultural_diversity(model)
  # Default values
  result = Dict(
    "unique_cultures" => 0,
    "max_possible" => 0,
    "diversity_ratio" => 0.0
  )

  if !model.enable_culture
    return result
  end

  agents_list = collect(allagents(model))
  if length(agents_list) == 0
    return result
  end

  # Count unique cultural patterns
  cultural_patterns = Set{String}()

  for agent in agents_list
    if length(agent.culture) > 0
      pattern = join(Int.(agent.culture), "")
      push!(cultural_patterns, pattern)
    end
  end

  diversity = length(cultural_patterns)
  max_diversity = 2^model.culture_tag_length

  result["unique_cultures"] = diversity
  result["max_possible"] = max_diversity
  result["diversity_ratio"] = diversity / max_diversity

  return result
end

# =============================================================================
# NETWORK ANALYSIS
# =============================================================================

"""
    calculate_credit_network_metrics(model)

Calculate network metrics for credit relationships.
"""
function calculate_credit_network_metrics(model)
  !model.enable_credit && return Dict()

  agents_list = collect(allagents(model))
  length(agents_list) == 0 && return Dict()

  # Build adjacency information
  edges = Set{Tuple{Int,Int}}()
  node_degrees = Dict{Int,Int}()

  for agent in agents_list
    node_degrees[agent.id] = 0
    for loan in agent.loans
      lender_id, borrower_id = loan[1], loan[2]
      push!(edges, (lender_id, borrower_id))
      node_degrees[lender_id] = get(node_degrees, lender_id, 0) + 1
      node_degrees[borrower_id] = get(node_degrees, borrower_id, 0) + 1
    end
  end

  n_nodes = length(agents_list)
  n_edges = length(edges)

  # Calculate metrics
  density = n_nodes > 1 ? 2 * n_edges / (n_nodes * (n_nodes - 1)) : 0.0
  avg_degree = length(node_degrees) > 0 ? mean(values(node_degrees)) : 0.0
  max_degree = length(node_degrees) > 0 ? maximum(values(node_degrees)) : 0

  return Dict(
    "n_nodes" => n_nodes,
    "n_edges" => n_edges,
    "density" => density,
    "avg_degree" => avg_degree,
    "max_degree" => max_degree
  )
end

"""
    calculate_combat_network_metrics(model)

Calculate network metrics for combat relationships.
"""
function calculate_combat_network_metrics(model)
  !model.enable_combat && return Dict()

  # Combat creates temporary relationships, so we track cultural similarity
  agents_list = collect(allagents(model))
  length(agents_list) == 0 && return Dict()

  # Count potential conflicts based on cultural differences
  potential_conflicts = 0
  cultural_distance_sum = 0.0

  for i in 1:length(agents_list)
    for j in (i+1):length(agents_list)
      agent1, agent2 = agents_list[i], agents_list[j]

      if length(agent1.culture) > 0 && length(agent2.culture) > 0
        distance = hamming_distance(agent1.culture, agent2.culture)
        cultural_distance_sum += distance

        if distance > 0
          potential_conflicts += 1
        end
      end
    end
  end

  n_pairs = length(agents_list) * (length(agents_list) - 1) / 2
  conflict_rate = n_pairs > 0 ? potential_conflicts / n_pairs : 0.0
  avg_cultural_distance = n_pairs > 0 ? cultural_distance_sum / n_pairs : 0.0

  return Dict(
    "potential_conflicts" => potential_conflicts,
    "conflict_rate" => conflict_rate,
    "avg_cultural_distance" => avg_cultural_distance
  )
end

"""
    hamming_distance(culture1, culture2)

Calculate Hamming distance between two cultural bit vectors.
"""
function hamming_distance(culture1, culture2)
  length(culture1) != length(culture2) && return length(culture1) + length(culture2)
  return sum(culture1 .!= culture2)
end

# =============================================================================
# ENVIRONMENTAL ANALYSIS
# =============================================================================

"""
    calculate_resource_depletion(model)

Calculate resource depletion metrics.
"""
function calculate_resource_depletion(model)
  current_sugar = sum(model.sugar_values)
  max_sugar = sum(model.sugar_capacities)

  depletion_rate = max_sugar > 0 ? 1.0 - (current_sugar / max_sugar) : 0.0

  return Dict(
    "current_sugar" => current_sugar,
    "max_sugar" => max_sugar,
    "depletion_rate" => depletion_rate
  )
end

"""
    calculate_spatial_segregation(model)

Calculate spatial segregation using Moran's I.
"""
function calculate_spatial_segregation(model)
  try
    return morans_i(model)
  catch
    return 0.0
  end
end

"""
    calculate_clustering_coefficient(model)

Calculate clustering coefficient for spatial distribution.
"""
function calculate_clustering_coefficient(model)
  agents_list = collect(allagents(model))
  length(agents_list) < 3 && return 0.0

  clustering_sum = 0.0
  agent_count = 0

  for agent in agents_list
    neighbors = collect(nearby_agents(agent, model, 1))
    length(neighbors) < 2 && continue

    # Count connections between neighbors
    connections = 0
    for i in 1:length(neighbors)
      for j in (i+1):length(neighbors)
        if any(n.id == neighbors[j].id for n in nearby_agents(neighbors[i], model, 1))
          connections += 1
        end
      end
    end

    possible_connections = length(neighbors) * (length(neighbors) - 1) / 2
    clustering_sum += connections / possible_connections
    agent_count += 1
  end

  return agent_count > 0 ? clustering_sum / agent_count : 0.0
end

# =============================================================================
# DISEASE ANALYSIS
# =============================================================================

"""
    calculate_disease_prevalence(model)

Calculate disease prevalence metrics.
"""
function calculate_disease_prevalence(model)
  !model.enable_disease && return 0.0

  agents_list = collect(allagents(model))
  length(agents_list) == 0 && return 0.0

  infected_count = count(a -> length(a.diseases) > 0, agents_list)
  return infected_count / length(agents_list)
end

"""
    calculate_disease_diversity(model)

Calculate disease diversity metrics.
"""
function calculate_disease_diversity(model)
  # Default values
  result = Dict(
    "unique_diseases" => 0,
    "infected_agents" => 0
  )

  if !model.enable_disease
    return result
  end

  agents_list = collect(allagents(model))
  if length(agents_list) == 0
    return result
  end

  # Count unique disease patterns
  disease_patterns = Set{String}()

  for agent in agents_list
    for disease in agent.diseases
      pattern = join(Int.(disease), "")
      push!(disease_patterns, pattern)
    end
  end

  result["unique_diseases"] = length(disease_patterns)
  result["infected_agents"] = count(a -> length(a.diseases) > 0, agents_list)

  return result
end

# =============================================================================
# CREDIT ANALYSIS
# =============================================================================

"""
    calculate_total_credit_outstanding(model)

Calculate total credit outstanding in the system.
"""
function calculate_total_credit_outstanding(model)
  !model.enable_credit && return 0.0

  total = 0.0
  for agent in allagents(model)
    for loan in agent.loans
      total += loan[3]  # Principal amount
    end
  end

  return total / 2  # Divide by 2 since each loan is counted twice
end

"""
    calculate_credit_default_rate(model)

Calculate credit default rate (simplified).
"""
function calculate_credit_default_rate(model)
  !model.enable_credit && return 0.0

  # This is a simplified calculation
  # In a more sophisticated system, we'd track actual defaults
  total_loans = 0
  risky_loans = 0

  for agent in allagents(model)
    for loan in agent.loans
      total_loans += 1
      # Consider loan risky if borrower has less than 2x the principal
      if loan[2] == agent.id && agent.sugar < 2 * loan[3]
        risky_loans += 1
      end
    end
  end

  return total_loans > 0 ? risky_loans / total_loans : 0.0
end

# =============================================================================
# EFFECT SIZE ANALYSIS
# =============================================================================

"""
    calculate_effect_sizes(treatment_data, control_data)

Calculate effect sizes with confidence intervals for experimental comparisons.
"""
function calculate_effect_sizes(treatment_data::Vector{<:Real}, control_data::Vector{<:Real})
  length(treatment_data) == 0 || length(control_data) == 0 && return Dict()

  # Cohen's d
  pooled_std = sqrt(((length(treatment_data) - 1) * var(treatment_data) +
                     (length(control_data) - 1) * var(control_data)) /
                    (length(treatment_data) + length(control_data) - 2))

  cohens_d = pooled_std > 0 ? (mean(treatment_data) - mean(control_data)) / pooled_std : 0.0

  # Hedges' g (bias-corrected)
  correction_factor = 1 - (3 / (4 * (length(treatment_data) + length(control_data)) - 9))
  hedges_g = cohens_d * correction_factor

  # Glass's delta
  control_std = std(control_data)
  glass_delta = control_std > 0 ? (mean(treatment_data) - mean(control_data)) / control_std : 0.0

  # Confidence intervals (simplified)
  n1, n2 = length(treatment_data), length(control_data)
  se = sqrt((n1 + n2) / (n1 * n2) + hedges_g^2 / (2 * (n1 + n2)))

  ci_lower = hedges_g - 1.96 * se
  ci_upper = hedges_g + 1.96 * se

  return Dict(
    "cohens_d" => cohens_d,
    "hedges_g" => hedges_g,
    "glass_delta" => glass_delta,
    "ci_lower" => ci_lower,
    "ci_upper" => ci_upper,
    "n_treatment" => n1,
    "n_control" => n2
  )
end

# =============================================================================
# DATA EXPORT AND PERSISTENCE
# =============================================================================

"""
    export_analytics_data(analytics::Analytics, step::Int, agent_data::Dict, model_data::Dict)

Export analytics data to CSV files.
"""
function export_analytics_data(analytics::Analytics, step::Int, agent_data::Dict, model_data::Dict)
  # Ensure export directory exists
  mkpath(analytics.export_dir)

  # Prepare data for export
  metrics_dict = Dict{String,Any}()
  metrics_dict["step"] = step
  metrics_dict["timestamp"] = now()

  # Flatten agent data
  for (key, value) in agent_data
    if isa(value, Dict)
      for (subkey, subvalue) in value
        metrics_dict["agent_$(key)_$(subkey)"] = subvalue
      end
    else
      metrics_dict["agent_$(key)"] = value
    end
  end

  # Flatten model data
  for (key, value) in model_data
    if isa(value, Dict)
      for (subkey, subvalue) in value
        metrics_dict["model_$(key)_$(subkey)"] = subvalue
      end
    else
      metrics_dict["model_$(key)"] = value
    end
  end

  # Add to history
  push!(analytics.metrics_history, metrics_dict)

  # Export to CSV every 10 steps or if it's the final step
  if step % 10 == 0 || step == 0
    export_to_csv(analytics)
  end
end

"""
    export_to_csv(analytics::Analytics)

Export accumulated analytics data to CSV.
"""
function export_to_csv(analytics::Analytics)
  isempty(analytics.metrics_history) && return

  # Convert to DataFrame
  df = DataFrame(analytics.metrics_history)

  # Export main metrics
  metrics_file = joinpath(analytics.export_dir, "$(analytics.export_prefix)_metrics.csv")
  CSV.write(metrics_file, df)

  # Export individual data if collected
  if analytics.collect_individual_data && !isempty(analytics.individual_data_history)
    individual_file = joinpath(analytics.export_dir, "$(analytics.export_prefix)_individual.csv")
    individual_df = vcat(analytics.individual_data_history...)
    CSV.write(individual_file, individual_df)
  end
end

"""
    create_summary_report(analytics::Analytics)

Create a summary report of the analytics data.
"""
function create_summary_report(analytics::Analytics)
  isempty(analytics.metrics_history) && return "No data collected"

  df = DataFrame(analytics.metrics_history)

  report = """
  # Sugarscape Analytics Summary Report

  Generated: $(now())
  Total Steps: $(length(analytics.metrics_history))

  ## Key Metrics Summary

  """

  # Add key statistics
  if "model_nagents" in names(df)
    report *= "- Final Population: $(last(df.model_nagents))\n"
    report *= "- Population Range: $(minimum(df.model_nagents)) - $(maximum(df.model_nagents))\n"
  end

  if "model_gini_coefficient" in names(df)
    report *= "- Final Gini Coefficient: $(round(last(df.model_gini_coefficient), digits=3))\n"
    report *= "- Gini Range: $(round(minimum(df.model_gini_coefficient), digits=3)) - $(round(maximum(df.model_gini_coefficient), digits=3))\n"
  end

  if "model_deaths_starvation" in names(df)
    report *= "- Total Deaths (Starvation): $(last(df.model_deaths_starvation))\n"
  end

  if "model_deaths_age" in names(df)
    report *= "- Total Deaths (Age): $(last(df.model_deaths_age))\n"
  end

  if "model_births" in names(df)
    report *= "- Total Births: $(last(df.model_births))\n"
  end

  return report
end

"""
    reset_analytics!(analytics::Analytics)

Reset analytics state for new simulation run.
"""
function reset_analytics!(analytics::Analytics)
  analytics.step_counter = 0
  analytics.metrics_history = Dict{String,Any}[]
  analytics.individual_data_history = DataFrame[]
  analytics.computation_times = Dict{String,Vector{Float64}}()
end

# =============================================================================
# UTILITY FUNCTIONS
# =============================================================================

"""
    time_function(func, args...; name="function")

Time a function execution and store the result.
"""
function time_function(func, args...; name="function")
  start_time = time()
  result = func(args...)
  execution_time = time() - start_time

  # Store timing information (could be used for performance analysis)
  return result, execution_time
end

"""
    create_labels_for_dashboard()

Create human-readable labels for dashboard display.
"""
function create_labels_for_dashboard()
  return [
    "Wealthy Agents", "Wealthy Total Wealth", "Medium Wealth Agents", "Medium Total Wealth",
    "Poor Agents", "Poor Total Wealth", "Extreme Poverty", "Extreme Poverty Wealth",
    "Young Agents", "Young Avg Age", "Adult Agents", "Adult Avg Age",
    "Elderly Agents", "Elderly Avg Age", "Male Agents", "Female Agents",
    "Reproduced Agents", "Agents with Children", "Infected Agents",
    "Mean Wealth", "Wealth Std", "Max Wealth", "Min Wealth",
    "Mean Age", "Age Std", "Mean Lifespan (Deceased)"
  ]
end

# Export main functions
export Analytics, create_analytics_pipeline, export_analytics_data, export_to_csv,
  create_summary_report, reset_analytics!, create_labels_for_dashboard
