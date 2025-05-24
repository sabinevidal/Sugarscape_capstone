using Sugarscape, Agents, CairoMakie, Observables

"""
    main_record_animation()

Run the Sugarscape model and record an animation of the simulation.
"""
function main_record_animation()
  Sugarscape.record_sugarscape_animation("sugarvis_dashboard.mp4"; steps=100, framerate=3)
end

# Record the animation
main_record_animation()
