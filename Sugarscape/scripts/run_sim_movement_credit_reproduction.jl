#!/usr/bin/env julia

using Random
using Agents
using CSV
using DataFrames
using Dates
using Sugarscape
using DotEnv
using Agents.AgentsIO

DotEnv.load!()

if length(ARGS) == 0
    error("Architecture argument required: rule, llm, bigfive, or schwartz")
end

architecture = ARGS[1]
scenario = "movement_credit_reproduction"
n_steps = 150
seed = 28
llm_metadata = Dict{String,Any}("sugarscape" => "$(scenario)-$(architecture)")
run_number = 1
run_name = "$(scenario)_$(architecture)_run_$(run_number)"

# ---------------------- Initialise Model ---------------------- #
model = if architecture == "rule"
    sugarscape(; seed=seed, enable_credit=true, enable_reproduction=true, llm_metadata=llm_metadata, run_name=run_name)
elseif architecture == "llm"
    sugarscape(; seed=seed, enable_credit=true, enable_reproduction=true, use_llm_decisions=true, llm_metadata=llm_metadata, run_name=run_name)
elseif architecture == "bigfive"
    sugarscape_llm_bigfive(; seed=seed, enable_credit=true, enable_reproduction=true, llm_metadata=llm_metadata, run_name=run_name)
elseif architecture == "schwartz"
    sugarscape_llm_schwartz(; seed=seed, enable_credit=true, enable_reproduction=true, llm_metadata=llm_metadata, run_name=run_name)
else
    error("Unsupported architecture: $architecture")
end

if isempty(model.llm_api_key)
    model.llm_api_key = get(ENV, "OPENAI_API_KEY", "")
end

# ---------------------- Analytics Setup ---------------------- #
timestamp = Dates.format(now(), "yymmdd_HHMM")

output_prefix = "$(scenario)_$(architecture)"
output_dir = "data/results/simulations/$(output_prefix)"
mkpath(output_dir)
metrics_file = joinpath(output_dir, "$(output_prefix)_metrics_$(run_number).csv")
agents_file = joinpath(output_dir, "$(output_prefix)_agents_$(run_number).csv")
initial_agents_file = joinpath(output_dir, "$(output_prefix)_initial_agents_$(run_number).csv")
checkpoint_dir = "data/checkpoints/$(run_name)_checkpoint"
mkpath(checkpoint_dir)
checkpoint_file = joinpath(checkpoint_dir, "model_checkpoint.jld2")

mdata = credit_reproduction_metrics
adata = if architecture == "bigfive"
    # Include traits for Big Five agents
    [
        :pos, :sugar, :age, :vision, :metabolism, :sex,
        :children, :loans_given, :loans_owed, :has_reproduced, :total_inheritance_received,
        :last_partner_id, :last_credit_partner, :chose_not_to_borrow, :chose_not_to_lend, :chose_not_to_reproduce, :traits
    ]
elseif architecture == "schwartz"
    # Include traits for Schwartz agents
    [
        :pos, :sugar, :age, :vision, :metabolism, :sex,
        :children, :loans_given, :loans_owed, :has_reproduced, :total_inheritance_received,
        :last_partner_id, :last_credit_partner, :chose_not_to_borrow, :chose_not_to_lend, :chose_not_to_reproduce, :schwartz_values
    ]
else
    # Standard agent data for other architectures
    [
        :pos, :sugar, :age, :vision, :metabolism, :sex,
        :children, :loans_given, :loans_owed, :has_reproduced, :total_inheritance_received,
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

# Run simulation with offline_run! - writes data every 10 steps
offline_run!(model, n_steps;
    when=1,
    mdata=mdata,
    adata=adata,
    obtainer=custom_obtainer,
    showprogress=true,
    backend=:csv,
    adata_filename=agents_file,
    mdata_filename=metrics_file,
    writing_interval=1,  # Write data every 10 steps
)

AgentsIO.save_checkpoint(checkpoint_file, model)

adf = CSV.read(agents_file, DataFrame)
mdf = CSV.read(metrics_file, DataFrame)

# ---------------------- Export Metrics ---------------------- #

println("✅ Simulation complete for architecture: $architecture")
println("📁 Results saved to: $(metrics_file)")
