using Agents, CairoMakie, Observables, Random

"""
    run_sugarscape_visualization(; model_kwargs...)

Launch an interactive Sugarscape visualization.
You can pass keyword arguments to the `sugarscape` model constructor.
"""
function run_sugarscape_visualization(; model_kwargs...)
  # Ensure model constructor is accessible, might need Sugarscape.sugarscape if not exported globally
  # or if this file becomes part of a different module scope.
  # For now, assuming sugarscape() is available.
  _model = sugarscape(; model_kwargs...) # renamed model to _model to avoid clash
  fig, ax, abmp = abmplot(_model; add_controls=false, figkwargs=(size = (800, 600)))

  # Check if abmp.model is an Observable or direct model reference
  # Based on Agents.jl typical usage, abmp.model is an Observable
  current_model_observable = abmp.model

  sugar = @lift($current_model_observable.sugar_values)
  max_sugar_obs = @lift($current_model_observable.max_sugar)
  axhm, hm = heatmap(fig[1, 2], sugar; colormap=:thermal, colorrange=@lift((0, $max_sugar_obs)))
  axhm.aspect = AxisAspect(1)
  Colorbar(fig[1, 3], hm, width=15, tellheight=false)
  # Ensure rowsize adjustment is correct based on fig layout
  try # This can error if viewport isn't ready
    rowsize!(fig.layout, 1, axhm.scene.viewport[].widths[2])
  catch e
    # println("Could not set rowsize due to viewport: $e")
  end

  s = Observable(0) # Step counter observable, should be linked to abmp's step counter if possible
  # For abmplot, the step count is implicitly managed.
  # We might need to update `s` based on model evolution if abmplot doesn't expose its step.
  # A simpler way is to just reflect the model's internal step if it has one, or the plot's step.
  # For now, assuming `s` is an independent counter for title.

  # If abmplot has a step counter, use it:
  # s = abmp.s # or similar, depends on abmplot's internals, this is hypothetical
  # If not, we need to update `s` when the model steps.

  t = @lift("Sugarscape, step = $($s)") # If s is manually incremented or tied to model steps.
  connect!(ax.title, t)
  ax.titlealign = :left
  display(fig)
  return fig, abmp # return abmp to allow stepping from outside if needed by run_visualization
end
