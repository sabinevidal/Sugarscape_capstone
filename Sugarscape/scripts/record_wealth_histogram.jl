using Sugarscape, Agents, CairoMakie, Observables

"""
    main_record_wealth_histogram()

Run the Sugarscape model and record an animation of the wealth distribution histogram.
"""
function main_record_wealth_histogram()
  model = Sugarscape.sugarscape()
  adata, _ = Agents.run!(model, 100, adata=[:wealth]) # Use Agents.run! for data collection
  Sugarscape.record_wealth_hist_animation(adata; filename="sugarhist.mp4", steps=50, framerate=3)
end

# Record the wealth histogram
main_record_wealth_histogram()
