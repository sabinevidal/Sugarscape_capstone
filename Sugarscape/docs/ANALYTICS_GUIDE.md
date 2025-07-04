# Analytics Pipeline Guide

## Overview

The Sugarscape Analytics Pipeline provides comprehensive metrics collection, analysis, and export capabilities for the Sugarscape agent-based model. This pipeline goes beyond basic Gini coefficient calculations to provide deep insights into wealth distribution evolution, inequality tail indices, network metrics, and effect sizes with confidence intervals.

## Features

### 📊 Core Metrics
- **Wealth Distribution Analysis**: Gini coefficient, Pareto α, percentiles, concentration indices
- **Lifespan Analysis**: Mean lifespan, inequality metrics, distribution moments
- **Cultural Dynamics**: Entropy, diversity, pattern evolution
- **Network Analysis**: Credit/combat relationship metrics, clustering coefficients
- **Environmental Metrics**: Resource depletion, spatial segregation

### 🔬 Advanced Analytics
- **Effect Size Calculations**: Cohen's d, Hedges' g, Glass's delta with confidence intervals
- **Distribution Evolution**: Time series tracking of inequality measures
- **Network Metrics**: Density, degree distributions, clustering coefficients
- **Tail Analysis**: Pareto α estimation, top percentile wealth shares

### 📈 Data Export & Visualisation
- **CSV Export**: Automated data export with configurable intervals
- **Live Plotting**: Real-time metric visualisation during simulation
- **Summary Reports**: Automated generation of key findings
- **Time Series Analysis**: Evolution tracking over simulation steps

## Quick Start

```julia
using Sugarscape
include("src/visualisation/analytics.jl")

# Create model
model = sugarscape(;
    dims=(20, 20),
    N=100,
    enable_reproduction=true,
    enable_culture=true,
    enable_combat=true,
    enable_credit=true,
    use_llm_decisions=false  # Important: Disable LLM for analytics
)

# Set up analytics pipeline
adata, mdata, analytics = create_analytics_pipeline(model;
    export_dir="data/results",
    export_prefix="my_experiment",
    collect_individual_data=false,
    collect_distributions=true,
    collect_network_metrics=true
)

# Run simulation with data collection
for step in 1:1000
    step!(model)

    if step % 10 == 0
        # Collect data using Agents.jl patterns
        agent_data = Dict()
        for (i, (afunc, reducer)) in enumerate(adata)
            agents_subset = filter(afunc, allagents(model))
            agent_data["metric_$i"] = reducer(agents_subset)
        end

        model_data = Dict()
        for (i, mfunc) in enumerate(mdata)
            model_data["metric_$i"] = mfunc(model)
        end

        # Export data
        export_analytics_data(analytics, step, agent_data, model_data)
    end
end

# Generate summary report
report = create_summary_report(analytics)
println(report)
```

## Detailed Metrics Reference

### Wealth Distribution Metrics

#### Gini Coefficient
```julia
gini = calculate_gini_coefficient(model)
```
Measures wealth inequality from 0 (perfect equality) to 1 (perfect inequality).

#### Pareto α Parameter
```julia
alpha = calculate_pareto_alpha(model)
```
Estimates the tail index of the wealth distribution using the Hill estimator. Lower values indicate more inequality in the tail.

#### Wealth Percentiles
```julia
percentiles = calculate_wealth_percentiles(model)
# Returns: Dict with p25, p50, p75, p90, p95, p99
```

#### Top Wealth Shares
```julia
top_1_percent = calculate_top_wealth_share(model, 0.01)
top_10_percent = calculate_top_wealth_share(model, 0.10)
```

#### Wealth Concentration
```julia
concentration = calculate_wealth_concentration(model)
# Returns: Dict with "herfindahl" and "entropy" measures
```

### Lifespan Analysis

#### Mean Lifespan
```julia
mean_age = calculate_mean_lifespan(model)
deceased_lifespan = calculate_mean_lifespan_deceased(model)
```

#### Lifespan Inequality
```julia
age_gini = calculate_lifespan_inequality(model)
```

#### Distribution Moments
```julia
moments = calculate_wealth_distribution_moments(model)
# Returns: mean, variance, skewness, kurtosis
```

### Cultural Dynamics

#### Cultural Entropy
```julia
entropy = calculate_cultural_entropy(model)
```
Measures diversity of cultural patterns across the population.

#### Cultural Diversity
```julia
diversity = calculate_cultural_diversity(model)
# Returns: unique_cultures, max_possible, diversity_ratio
```

### Network Analysis

#### Credit Network Metrics
```julia
credit_network = calculate_credit_network_metrics(model)
# Returns: n_nodes, n_edges, density, avg_degree, max_degree
```

#### Combat Network Metrics
```julia
combat_network = calculate_combat_network_metrics(model)
# Returns: potential_conflicts, conflict_rate, avg_cultural_distance
```

#### Spatial Clustering
```julia
clustering = calculate_clustering_coefficient(model)
segregation = calculate_spatial_segregation(model)  # Moran's I
```

### Effect Size Analysis

For experimental comparisons:

```julia
effect_sizes = calculate_effect_sizes(treatment_data, control_data)
# Returns: cohens_d, hedges_g, glass_delta, ci_lower, ci_upper
```

**Interpretation:**
- |d| < 0.2: negligible effect
- 0.2 ≤ |d| < 0.5: small effect
- 0.5 ≤ |d| < 0.8: medium effect
- |d| ≥ 0.8: large effect

## Advanced Usage

### Custom Analytics Configuration

```julia
analytics = Analytics(;
    export_dir="custom/path",
    export_prefix="experiment_$(now())",
    collect_individual_data=true,     # Collect agent-level data
    collect_distributions=true,       # Track distribution evolution
    collect_network_metrics=true      # Calculate network metrics
)
```

### Integration with Interactive Dashboard

```julia
# In your dashboard script
include("src/visualisation/analytics.jl")

# Create enhanced model data functions
mdata = [
    nagents,
    :deaths_starvation,
    :deaths_age,
    :births,
    model -> calculate_gini_coefficient(model),
    model -> calculate_pareto_alpha(model),
    model -> calculate_top_wealth_share(model, 0.01),
    model -> calculate_cultural_entropy(model),
    model -> calculate_credit_network_metrics(model)["density"],
    model -> calculate_spatial_segregation(model)
]

# Use with abmplot
fig, ax, abmobs = abmplot(model; mdata=mdata, ...)
```

### Time Series Analysis

```julia
time_series = Dict(
    "gini" => Float64[],
    "pareto_alpha" => Float64[],
    "top_1_percent" => Float64[],
    "cultural_entropy" => Float64[]
)

for step in 1:1000
    step!(model)

    if step % 25 == 0
        push!(time_series["gini"], calculate_gini_coefficient(model))
        push!(time_series["pareto_alpha"], calculate_pareto_alpha(model))
        push!(time_series["top_1_percent"], calculate_top_wealth_share(model, 0.01))
        push!(time_series["cultural_entropy"], calculate_cultural_entropy(model))
    end
end

# Export time series
df = DataFrame(time_series)
df.step = 25:25:1000
CSV.write("time_series.csv", df)
```

### Comparative Experiments

```julia
function run_comparative_experiment()
    conditions = [
        ("Control", (enable_combat=false, enable_credit=false)),
        ("Combat", (enable_combat=true, enable_credit=false)),
        ("Credit", (enable_combat=false, enable_credit=true)),
        ("Both", (enable_combat=true, enable_credit=true))
    ]

    results = Dict()

    for (name, params) in conditions
        gini_values = Float64[]

        # Run multiple replicates
        for replicate in 1:10
            model = sugarscape(; use_llm_decisions=false, params..., seed=replicate)

            # Run simulation
            for step in 1:500
                step!(model)
            end

            push!(gini_values, calculate_gini_coefficient(model))
        end

        results[name] = gini_values
    end

    # Calculate effect sizes
    control_data = results["Control"]
    for condition in ["Combat", "Credit", "Both"]
        effect_sizes = calculate_effect_sizes(results[condition], control_data)
        println("$condition vs Control: Hedges' g = $(effect_sizes["hedges_g"])")
        println("  95% CI: [$(effect_sizes["ci_lower"]), $(effect_sizes["ci_upper"])]")
    end

    return results
end
```

## Performance Considerations

### Memory Management
- Set `collect_individual_data=false` for large simulations
- Export data regularly to avoid memory buildup
- Use `reset_analytics!()` between experiments

### Computational Efficiency
- Network metrics are computationally intensive for large populations
- Consider sampling for very large models
- Use parallel processing for comparative experiments

### Export Frequency
- Default: exports every 10 steps
- Adjust based on simulation length and data needs
- Use `export_to_csv()` manually for custom timing

## Examples

Run the comprehensive examples:

```bash
cd Sugarscape
julia scripts/analytics_example.jl
```

This will demonstrate:
1. Basic analytics setup
2. Comparative analysis with effect sizes
3. Distribution evolution tracking
4. Network analysis deep dive

## Troubleshooting

### Common Issues

1. **LLM decision errors**: Always set `use_llm_decisions=false` for non-AI simulations
2. **StatsBase not found**: Add `StatsBase` to your Project.toml
3. **Empty results**: Ensure agents exist when calculating metrics
4. **NaN values**: Check for division by zero in small populations
5. **Memory issues**: Reduce data collection frequency or disable individual data collection

### Performance Tips

1. **Large simulations**: Use sampling for network metrics
2. **Long runs**: Export data frequently to avoid memory issues
3. **Multiple replicates**: Use parallel processing
4. **Custom metrics**: Pre-filter agents to reduce computation

## Integration with Research Workflow

### Publication-Ready Outputs

The analytics pipeline generates publication-ready metrics:

- **Inequality measures**: Gini, Pareto α, top percentile shares
- **Effect sizes**: With confidence intervals for significance testing
- **Network metrics**: Standard social network analysis measures
- **Distribution analysis**: Comprehensive statistical moments

### Reproducibility

- All metrics use deterministic algorithms
- Seed management for reproducible results
- Comprehensive data export for replication
- Automated report generation for documentation

### Statistical Validity

- Effect sizes with confidence intervals
- Multiple replicate support
- Bias-corrected estimates (Hedges' g)
- Robust tail index estimation

## Future Extensions

The analytics pipeline is designed for extensibility:

1. **Custom metrics**: Add new functions following the pattern
2. **Additional distributions**: Extend beyond Pareto analysis
3. **Machine learning**: Use exported data for ML analysis
4. **Real-time analysis**: Streaming analytics for very long simulations

## References

- **Gini coefficient**: Standard inequality measure
- **Pareto α**: Hill, B. M. (1975). A simple general approach to inference about the tail of a distribution
- **Effect sizes**: Cohen, J. (1988). Statistical Power Analysis for the Behavioral Sciences
- **Network metrics**: Wasserman, S. & Faust, K. (1994). Social Network Analysis
