#!/usr/bin/env julia

"""
run_sugarscape_simulation.jl
============================

Command-line utility to run a Sugarscape simulation with different agent
behaviour models.  The script runs a fixed-length simulation and exports the
collected agent- and model-level data (`adata`, `mdata`) to CSV files.

Usage
-----
    julia run_sugarscape_simulation.jl [MODE]

Arguments
---------
* `MODE` – Type of model to run. One of `rules`, `llm`, `bigfive` or `schwartz`.
           This also determines the output file prefix.

Dependencies
------------
The script relies on `Agents.jl`, `CSV.jl` and `DataFrames.jl`, which are already
listed in the project.  If you run the script outside the main project
environment, uncomment the `Pkg.activate` line below to use the local
`Project.toml`.
"""

using Pkg

# Ensure we can find local modules by adding the project's src directory to LOAD_PATH
push!(LOAD_PATH, joinpath(@__DIR__, "..", "src"))

# Activate the project environment
Pkg.activate(joinpath(@__DIR__, ".."))
Pkg.instantiate()

using Agents, CSV, DataFrames, Statistics, Dates, Printf
using DotEnv

using Sugarscape

DotEnv.load!()

const N_STEPS = 1_000

function main()
    # ---------------------------------------------------------------------
    # Parse command-line argument
    # ---------------------------------------------------------------------
    mode = length(ARGS) ≥ 1 ? lowercase(ARGS[1]) : "rules"

    valid_modes = ["rules", "llm", "bigfive", "schwartz"]
    if !(mode in valid_modes)
        println("❌ Invalid mode. Choose from: rules, llm, bigfive, schwartz")
        return
    end

    output_prefix = mode

    println("🔧 Running Sugarscape ($mode) for $(N_STEPS) steps …")

    # ---------------------------------------------------------------------
    # Initialise model based on selected mode
    # ---------------------------------------------------------------------
    base_kwargs = (
        N=4,
        enable_reproduction=false,
        enable_culture=false,
        enable_credit=true,
        dims=(30, 30),
        sugar_peaks=((10, 40), (40, 10)),
        max_sugar=5,
        fertility_age_range=(15, 55),
        llm_metadata=Dict{String,Any}("output_prefix" => output_prefix)
    )

    model = if mode == "rules"
        Sugarscape.sugarscape(; base_kwargs..., use_llm_decisions=false)
    elseif mode == "llm"
        Sugarscape.sugarscape(; base_kwargs..., use_llm_decisions=true, llm_temperature=0.4)
    elseif mode == "bigfive"
        Sugarscape.sugarscape_llm_bigfive(; base_kwargs..., llm_temperature=0.4)
    else  # schwartz
        Sugarscape.sugarscape_llm_schwartz(; base_kwargs..., llm_temperature=0.4)
    end

    # ---------------------------------------------------------------------
    # Define data to collect
    # ---------------------------------------------------------------------
    adata = [
        :pos,
        :sugar,
        :metabolism,
        :vision,
        :age,
        :max_age
    ]

    # Model data collection
    mdata = [
        m -> length(allagents(m)),
        m -> mean(a.sugar for a in allagents(m)),
        m -> sum(a.sugar for a in allagents(m))
    ]

    # ---------------------------------------------------------------------
    # Execute simulation and collect data
    # ---------------------------------------------------------------------
    adf, mdf = run!(model, N_STEPS; adata=adata, mdata=mdata)

    # ---------------------------------------------------------------------
    # Create results directory if it doesn't exist
    results_dir = abspath(joinpath(@__DIR__, "..", "data", "results"))
    mkpath(results_dir)

    # Generate timestamp for filenames
    timestamp = Dates.format(now(), "yymmdd_HHMM")

    # Define output file paths with timestamp
    adata_file = joinpath(results_dir, "$(timestamp)_$(output_prefix)_adata.csv")
    mdata_file = joinpath(results_dir, "$(timestamp)_$(output_prefix)_mdata.csv")

    # Use the DataFrames returned by run! for exporting
    CSV.write(adata_file, adf)
    CSV.write(mdata_file, mdf)

    println("✅ Simulation finished. Data saved to:\n   • $(adata_file)\n   • $(mdata_file)")
end

if abspath(PROGRAM_FILE) == @__FILE__
    main()
end
