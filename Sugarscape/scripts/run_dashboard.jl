#!/usr/bin/env julia

println("Loading Sugarscape Dashboard...")

# Get the project root directory
project_root = dirname(dirname(@__DIR__)) # This should be Sugarscape_capstone
sugarscape_module_dir = joinpath(project_root, "Sugarscape", "src")
dashboard_file = joinpath(project_root, "Sugarscape", "src", "visualisation", "dashboard.jl")


# Validate paths exist
if !isdir(sugarscape_module_dir)
  error("Could not find Sugarscape module directory: $(sugarscape_module_dir)")
end

if !isfile(dashboard_file)
  error("Could not find dashboard.jl: $(dashboard_file). Ensure script is run from project root or paths are correct.")
end

# Add to load path and include
push!(LOAD_PATH, sugarscape_module_dir)
include(dashboard_file)

println("Creating interactive dashboard...")

# Create and display the dashboard
fig, abmobs = Sugarscape.create_dashboard()

# Display both the figure and the ABM object
display(fig)
display(abmobs)

println("Interactive dashboard window displayed.")
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
