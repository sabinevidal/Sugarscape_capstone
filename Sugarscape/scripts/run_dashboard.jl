#!/usr/bin/env julia

"""
Sugarscape Unified Dashboard Launcher
=====================================

Single entry point for all Sugarscape dashboard types.
Usage:
  julia run_dashboard.jl [dashboard_type]

Where dashboard_type can be:
  - main (default): Comprehensive interactive dashboard
  - custom: Basic metrics with custom plots
  - reproduction: Population dynamics focused
"""

# Parse command line arguments
dashboard_type = length(ARGS) >= 1 ? ARGS[1] : "main"

if dashboard_type ∉ ["main", "custom", "reproduction", "simple"]
  println("Error: Invalid dashboard type '$(dashboard_type)'")
  println("Valid options: main, custom, reproduction, simple")
  exit(1)
end

println("Loading Sugarscape $(titlecase(dashboard_type)) Dashboard...")

# Get the project root directory
project_root = dirname(dirname(@__DIR__)) # This should be Sugarscape_capstone
sugarscape_module_dir = joinpath(project_root, "Sugarscape", "src")

# Determine which dashboard file to load
if dashboard_type == "main"
  dashboard_file = joinpath(project_root, "Sugarscape", "src", "visualisation", "dashboard.jl")
  create_function_name = "create_dashboard"
else
  dashboard_file = joinpath(project_root, "Sugarscape", "src", "visualisation", "interactive.jl")
  if dashboard_type == "custom"
    create_function_name = "create_custom_dashboard"
  elseif dashboard_type == "reproduction"
    create_function_name = "create_reproduction_dashboard"
  elseif dashboard_type == "simple"
    create_function_name = "create_simple_dashboard"
  end
end

# Validate paths exist
if !isdir(sugarscape_module_dir)
  error("Could not find Sugarscape module directory: $(sugarscape_module_dir)")
end

if !isfile(dashboard_file)
  error("Could not find dashboard file: $(dashboard_file). Ensure script is run from project root or paths are correct.")
end

# Add to load path and include
push!(LOAD_PATH, sugarscape_module_dir)
include(dashboard_file)

println("Creating $(dashboard_type) interactive dashboard...")

# Create and display the dashboard using the appropriate function
if dashboard_type == "main"
  fig, abmobs = Sugarscape.create_dashboard()
elseif dashboard_type == "custom"
  fig, abmobs = Sugarscape.create_custom_dashboard()
elseif dashboard_type == "reproduction"
  fig, abmobs = Sugarscape.create_reproduction_dashboard()
elseif dashboard_type == "simple"
  fig, abmobs = Sugarscape.create_simple_dashboard()
end

# Display both the figure and the ABM object
display(fig)
display(abmobs)

println("Interactive $(dashboard_type) dashboard window displayed.")
println("Use the controls to step through the simulation or run it continuously.")
println("Press Ctrl+C to exit.")

# Keep the script alive while the GLMakie window is open, if not in an interactive REPL.
if !isinteractive()
  println("Running in non-interactive mode. Keeping script alive...")
  try
    while GLMakie.isopen(fig.scene)
      sleep(0.1) # Keep the loop from busy-waiting
    end
  catch e
    if e isa InterruptException
      println("Interrupted by user (Ctrl+C).")
    else
      rethrow()
    end
  end
  println("Makie window closed or loop interrupted. Exiting script.")
end
