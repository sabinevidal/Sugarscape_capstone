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

"""
    record_sugarscape_animation(filename::String="sugarvis_dashboard.mp4"; steps::Int=100, framerate::Int=10, model_kwargs...)

Run the Sugarscape model and record an animation of the simulation to `filename`.
"""
function record_sugarscape_animation(filename::String="sugarvis_dashboard.mp4"; steps::Int=100, framerate::Int=10, model_kwargs...)
    _model = sugarscape(; model_kwargs...) # renamed

    fig = Figure(size = (1400, 1000))
    s = Observable(0)

    ax_agent = Axis(fig[1, 1], aspect=DataAspect())
    agent_c(a) = :yellow
    agent_m(a) = :circle
    _fig_ref, _ax_agent_ref, abmp = abmplot(_model; ax=ax_agent, add_controls=false,
                                           agent_color=agent_c, agent_marker=agent_m, agent_size=15)

    current_model_obs = abmp.model # abmp.model is the Observable{StandardABM}

    connect!(ax_agent.title, @lift("Sugarscape Simulation, Step: $($s)"))
    ax_agent.titlealign = :left

    model_dims = @lift(size($current_model_obs.sugar_values))
    # Use `lift` for dynamic updates if model dims could change (unlikely for sugarscape)
    # Set initial limits for ax_agent
    initial_mdims_val = model_dims[]
    xlims!(ax_agent, 0.5, initial_mdims_val[2] + 0.5)
    ylims!(ax_agent, 0.5, initial_mdims_val[1] + 0.5)
    hidedecorations!(ax_agent)

    ax_sugar_hm = Axis(fig[1, 2], title="Sugar Levels", aspect=DataAspect())
    sugar_content = @lift($current_model_obs.sugar_values)
    max_sug_val_obs = @lift($current_model_obs.max_sugar)
    hm = heatmap!(ax_sugar_hm, sugar_content; colormap=:thermal, colorrange=@lift((0, $max_sug_val_obs)))
    # Set initial limits for ax_sugar_hm
    ylims!(ax_sugar_hm, 0.5, initial_mdims_val[1] + 0.5)
    Colorbar(fig[1, 3], hm; label="Sugar", width=15, tellheight=false, vertical=true) # Place colorbar correctly
    hidedecorations!(ax_sugar_hm)

    # Setup reactive updates for limits when model_dims changes
    on(model_dims) do mdims_val
        try
            xlims!(ax_agent, 0.5, mdims_val[2] + 0.5)
            ylims!(ax_agent, 0.5, mdims_val[1] + 0.5)
            ylims!(ax_sugar_hm, 0.5, mdims_val[1] + 0.5)
        catch e
            # Optional: println("Error updating limits: $e")
        end
    end

    ax_hist = Axis(fig[2, 1], xlabel="Wealth", ylabel="Number of Agents", title="Wealth Distribution")
    wealth_data_obs = Observable([0]) # Initialize with a placeholder
    hist!(ax_hist, wealth_data_obs; bins=30, color=:lightblue, strokecolor=:black, strokewidth=1)
    autolimits!(ax_hist)

    ax_gini = Axis(fig[2, 2], xlabel="Step", ylabel="Gini Coefficient", title="Gini Coefficient Over Time")
    gini_history_obs = Observable(Point2f[])
    lines!(ax_gini, gini_history_obs; color=:forestgreen)
    xlims!(ax_gini, 0, steps)
    ylims!(ax_gini, 0, 1)

    rowsize!(fig.layout, 1, Relative(0.5))
    rowsize!(fig.layout, 2, Relative(0.5))
    colsize!(fig.layout, 1, Relative(0.4))
    colsize!(fig.layout, 2, Relative(0.4))
    colsize!(fig.layout, 3, Relative(0.2))

    # Initial state update (step 0)
    function update_dashboard_observables(current_step, model_state)
        s[] = current_step

        all_wealths = [a.wealth for a in allagents(model_state)]
        valid_wealths = filter(w -> w >= 0, all_wealths)
        wealth_data_obs[] = isempty(valid_wealths) ? [0] : valid_wealths
        autolimits!(ax_hist)

        current_gini = isempty(valid_wealths) ? 0.0 : gini_coefficient(valid_wealths) # Handle empty valid_wealths
        current_gini = isnan(current_gini) ? 0.0 : current_gini

        if current_step == 0
             gini_history_obs[] = [Point2f(0, current_gini)]
        else
            push!(gini_history_obs[], Point2f(current_step, current_gini))
            notify(gini_history_obs)
        end
    end

    update_dashboard_observables(0, current_model_obs[])


    record(fig, filename, 1:steps; framerate=framerate) do current_frame_step # current_frame_step is 1 to steps
        Agents.step!(abmp, 1)
        update_dashboard_observables(current_frame_step, current_model_obs[])
    end
    return filename
end


"""
    record_wealth_hist_animation(adata; filename="sugarhist.mp4", steps=50, framerate=3)
This function relies on `adata` which is typically DataFrame output from `run!`.
It will remain largely unchanged but ensure `adata` is correctly passed or generated if needed.
"""
function record_wealth_hist_animation(adata; filename::String="sugarhist.mp4", steps::Int=50, framerate::Int=3)
    figure = Figure(size=(600, 600))
    step_number = Observable(0)
    title_text = @lift("Wealth distribution of individuals, step = $($step_number)")
    Label(figure[1, 1], title_text; fontsize=20, tellwidth=false)
    ax = Axis(figure[2, 1]; xlabel="Wealth", ylabel="Number of agents")

    # Ensure adata is a DataFrame and filter correctly
    # Initial data for step 0
    initial_wealth_for_hist = adata[adata.step .== 0, :wealth]
    histdata = Observable(isempty(initial_wealth_for_hist) ? [0.0] : initial_wealth_for_hist) # ensure numeric if empty

    h = hist!(ax, histdata)
    ylims!(ax, (0, 50)) # Consider autolimits or make this parameterizable

    record(figure, filename, 0:steps; framerate=framerate) do i
        current_wealth_for_hist = adata[adata.step .== i, :wealth]
        histdata[] = isempty(current_wealth_for_hist) ? [0.0] : current_wealth_for_hist
        step_number[] = i
        if !isempty(histdata[]) && all(isfinite, histdata[]) # Ensure data is valid for xlims
            current_max_wealth = maximum(histdata[]; init=-Inf) # Handle empty histdata for maximum
            current_min_wealth = minimum(histdata[]; init=Inf)
            if current_max_wealth > -Inf && current_min_wealth < Inf && current_min_wealth <= current_max_wealth
                xlims!(ax, (min(0, current_min_wealth), max(1, current_max_wealth))) # ensure xlims are valid
            else
                xlims!(ax, (0,1)) # Default if data is problematic
            end
        else
            xlims!(ax, (0,1)) # Default if no data
        end
    end
    return filename
end
