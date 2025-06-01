#!/usr/bin/env julia

# This script launches the custom Sugarscape dashboard with all metrics.

println("Loading custom dashboard...")

# Get the project root directory
project_root = dirname(dirname(@__DIR__))
sugarscape_module_dir = joinpath(project_root, "Sugarscape", "src")
interactive_app_file = joinpath(project_root, "Sugarscape", "src", "visualisation", "interactive.jl")

if !isdir(sugarscape_module_dir)
  error("Could not find Sugarscape module directory: $(sugarscape_module_dir). Ensure script is run from project root or paths are correct.")
end

if !isfile(interactive_app_file)
  error("Could not find interactive_app.jl: $(interactive_app_file). Ensure script is run from project root or paths are correct.")
end

push!(LOAD_PATH, sugarscape_module_dir)
include(interactive_app_file)

println("Creating custom dashboard...")

# Create the dashboard with default parameters
fig, abmobs = Sugarscape.create_custom_dashboard()

println("Dashboard created. You can now:")
println("- Step through the simulation using: Agents.step!(abmobs, n)")
println("- Where n is the number of steps to advance")
println("- All plots will update automatically")

display(fig)
display(abmobs)

println("Custom dashboard window displayed.")
println("Close the window or press Ctrl+C in the terminal to exit.")

# Keep the script alive while the window is open, if not in an interactive REPL.
if !isinteractive()
  println("Running in non-interactive mode. Keeping script alive...")
  println("Close the window or press Ctrl+C to exit.")
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
  println("Window closed or loop interrupted. Exiting script.")
end
