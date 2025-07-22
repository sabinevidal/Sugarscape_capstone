#!/usr/bin/env julia

using Random
using Agents
using CSV
using DataFrames

include("../src/core/model.jl")
include("../src/psychological_dimensions/big_five/big_five.jl")
include("../src/psychological_dimensions/schwartz_values/schwartz_values.jl")
include("../src/visualisation/analytics.jl")
include("../src/utils/metrics.jl")
include("../src/utils/metrics_sets.jl")

if length(ARGS) == 0
    error("Architecture argument required: rule, llm, bigfive, or schwartz")
end

architecture = ARGS[1]
scenario = "movement_culture_credit"
n_steps = 1000
seed = 42

# ---------------------- Initialise Model ---------------------- #
model = if architecture == "rule"
    sugarscape(; seed=seed, enable_culture=true, enable_credit=true)
elseif architecture == "llm"
    sugarscape(; seed=seed, enable_culture=true, enable_credit=true, use_llm_decisions=true)
elseif architecture == "bigfive"
    sugarscape_llm_bigfive(; seed=seed, enable_culture=true, enable_credit=true)
elseif architecture == "schwartz"
    sugarscape_llm_schwartz(; seed=seed, enable_culture=true, enable_credit=true)
else
    error("Unsupported architecture: $architecture")
end

# ---------------------- Analytics Setup ---------------------- #
output_dir = "data/results/simulations/$(scenario)"
mkpath(output_dir)
output_prefix = "sugarscape_$(scenario)_$(architecture)"
metrics_file = joinpath(output_dir, "$(output_prefix)_metrics.csv")

mdata = culture_credit_metrics
adata = []

analytics = Analytics(; export_dir=output_dir, export_prefix=output_prefix,
    collect_individual_data=false, collect_distributions=false,
    collect_network_metrics=false)

# ---------------------- Run Simulation ---------------------- #
run!(model, agent_step!, n_steps; mdata=mdata, adata=adata)

# ---------------------- Export Metrics ---------------------- #
export_to_csv(analytics)

println("✅ Simulation complete for architecture: $architecture")
println("📁 Results saved to: $(metrics_file)")
