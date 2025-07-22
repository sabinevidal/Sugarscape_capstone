#!/usr/bin/env julia

"""
run_sugarscape_export.jl
========================

Simple command-line utility to run a Sugarscape simulation for a given number
of steps and export the collected agent- and model-level data (`adata`, `mdata`)
to CSV files.

Usage
-----
    julia run_sugarscape_export.jl [N_STEPS] [OUTPUT_PREFIX]

Arguments
---------
* `N_STEPS`        – (optional, default = 1000) Number of steps to simulate.
* `OUTPUT_PREFIX`  – (optional, default = "sugarscape") Prefix that will be used
                     for the generated `*-adata.csv` and `*-mdata.csv` files.

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
using Sugarscape

function main()
    # ---------------------------------------------------------------------
    # Parse command-line arguments
    # ---------------------------------------------------------------------
    n_steps = length(ARGS) ≥ 1 ? parse(Int, ARGS[1]) : 100
    output_prefix = length(ARGS) ≥ 2 ? ARGS[2] : "sugarscape"

    println("🔧 Running Sugarscape for $n_steps steps …")

    # ---------------------------------------------------------------------
    # Initialise model (pure rule-based by default)
    # ---------------------------------------------------------------------
    model = Sugarscape.sugarscape(enable_combat=true)

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
        m -> length(allagents(m)) > 0 ? mean(a.sugar for a in allagents(m)) : 0.0,
        m -> sum(a.sugar for a in allagents(m))
    ]

    # ---------------------------------------------------------------------
    # Execute simulation and collect data
    # ---------------------------------------------------------------------
    adf, mdf = run!(model, n_steps; adata=adata, mdata=mdata)

    # ---------------------------------------------------------------------
    # Create results directory if it doesn't exist
    results_dir = joinpath(@__DIR__, "results")
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
