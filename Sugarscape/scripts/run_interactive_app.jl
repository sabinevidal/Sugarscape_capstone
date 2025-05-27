#!/usr/bin/env julia

# This script launches the interactive Sugarscape application.

println("Loading interactive visualization...")

# Get the project root directory
project_root = dirname(dirname(@__DIR__)) # This should be Sugarscape_capstone
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

println("Launching application...")

# Call the function defined in interactive.jl
fig_handle, abmobs_handle = create_interactive_app()

display(fig_handle)
display(abmobs_handle)

println("Interactive application window displayed.")
println("Close the window or press Ctrl+C in the terminal to exit.")

# Keep the script alive while the GLMakie window is open, if not in an interactive REPL.
if !isinteractive()
    println("Running in non-interactive mode. Keeping script alive...")
    try
        while GLMakie.isopen(fig_handle.scene)
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
