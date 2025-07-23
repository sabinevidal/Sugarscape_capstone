#!/usr/bin/env julia

using Random
using Agents
using CSV
using DataFrames
using Dates
using Sugarscape

if length(ARGS) == 0
    error("Architecture argument required: rule, llm, bigfive, or schwartz")
end

architecture = ARGS[1]
scenario = "movement_reproduction"
n_steps = 5
seed = 42

# ---------------------- Initialise Model ---------------------- #
model = if architecture == "rule"
    sugarscape(; seed=seed, enable_reproduction=true)
elseif architecture == "llm"
    sugarscape(; seed=seed, enable_reproduction=true, use_llm_decisions=true)
elseif architecture == "bigfive"
    sugarscape_llm_bigfive(; seed=seed, enable_reproduction=true)
elseif architecture == "schwartz"
    sugarscape_llm_schwartz(; seed=seed, enable_reproduction=true)
else
    error("Unsupported architecture: $architecture")
end

# ---------------------- Analytics Setup ---------------------- #
# Generate timestamp for filenames
timestamp = Dates.format(now(), "yymmdd_HHMM")
output_dir = "data/results/simulations/$(scenario)/$(timestamp)"
mkpath(output_dir)
output_prefix = "sugarscape_$(scenario)_$(architecture)"
metrics_file = joinpath(output_dir, "$(output_prefix)_metrics_$(timestamp).csv")
agents_file = joinpath(output_dir, "$(output_prefix)_agents_$(timestamp).csv")
initial_agents_file = joinpath(output_dir, "$(output_prefix)_initial_agents_$(timestamp).csv")

mdata = reproduction_metrics

adata = if architecture == "bigfive"
    # Include traits for Big Five agents
    [
        :pos, :sugar, :age, :vision, :metabolism, :sex,
        :culture, :children, :has_reproduced, :total_inheritance_received,
        :last_partner_id, :last_credit_partner, :traits
    ]
else
    # Standard agent data for other architectures
    [
        :pos, :sugar, :age, :vision, :metabolism, :sex,
        :culture, :children, :has_reproduced, :total_inheritance_received,
        :last_partner_id, :last_credit_partner,
    ]
end



AgentsIO.dump_to_csv(initial_agents_file, allagents(model);
    transform=(c, v) -> v === nothing ? missing : v)

# ---------------------- Run Simulation ---------------------- #

# Custom obtainer function to copy only mutable Vector{Int} arrays
# while leaving other properties as identity (to avoid copying non-copyable types like Tuple)
function custom_obtainer(x)
    if isa(x, Vector{Int})
        return copy(x)  # Copy mutable arrays to capture their state at each step
    else
        return x  # Use identity for all other types
    end
end

# Run the simulation and collect data
adf, mdf = run!(model, n_steps; adata=adata, mdata=mdata, obtainer=custom_obtainer)

# ---------------------- Rename Metrics Columns ---------------------- #
# Map numeric column names to human-readable names for reproduction_metrics
# Note: nagents (first function) already gets its proper name, anonymous functions start from #77
metric_name_map = Dict(
    "#77" => "births",
    "#78" => "deaths_age",
    "#79" => "deaths_starvation",
    "#80" => "gini_coefficient",
    "#81" => "wealth_percentiles",
    "#82" => "pareto_alpha",
    "#83" => "mean_lifespan",
    "#84" => "lifespan_inequality"
)

# Rename columns in the metrics DataFrame
println("📊 Original column names: ", names(mdf))
for (old_name, new_name) in metric_name_map
    if old_name in names(mdf)
        println("🔄 Renaming $old_name to $new_name")
        rename!(mdf, old_name => new_name)
    else
        println("⚠️  Column $old_name not found in DataFrame")
    end
end
println("📊 Final column names: ", names(mdf))

# ---------------------- Export Data ---------------------- #
CSV.write(metrics_file, mdf;
    transform=(c, v) -> v === nothing ? missing : v)
CSV.write(agents_file, adf;
    transform=(c, v) -> v === nothing ? missing : v)

println("✅ Simulation complete for architecture: $architecture")
println("📁 Model metrics saved to: $(metrics_file)")
println("📁 Agent data saved to: $(agents_file)")
