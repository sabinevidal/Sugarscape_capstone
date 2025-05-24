module Sugarscape
using Agents, Random, CairoMakie, Observables

@agent struct SugarSeeker(GridAgent{2})
    vision::Int
    metabolic_rate::Int
    age::Int
    max_age::Int
    wealth::Int
end

# Functions `distances` and `sugar_caps` produce a matrix
# for the distribution of sugar capacities.

@inline function distances(pos, sugar_peaks)
    all_dists = zeros(Int, length(sugar_peaks))
    for (ind, peak) in enumerate(sugar_peaks)
        d = round(Int, sqrt(sum((pos .- peak) .^ 2)))
        all_dists[ind] = d
    end
    return minimum(all_dists)
end

@inline function sugar_caps(dims, sugar_peaks, max_sugar, dia=4)
    sugar_capacities = zeros(Int, dims)
    for i in 1:dims[1], j in 1:dims[2]
        sugar_capacities[i, j] = distances((i, j), sugar_peaks)
    end
    for i in 1:dims[1]
        for j in 1:dims[2]
            sugar_capacities[i, j] = max(0, max_sugar - (sugar_capacities[i, j] ÷ dia))
        end
    end
    return sugar_capacities
end

"""
    gini_coefficient(wealths::AbstractVector{<:Real})

Calculate the Gini coefficient for a vector of wealth values.
Assumes wealths are non-negative.
"""
function gini_coefficient(wealths::AbstractVector{<:Real})
    n = length(wealths)
    n == 0 && return 0.0 # No agents, no inequality (or could be NaN)

    # Ensure wealths are sorted for the Gini calculation formula used
    sorted_wealths = sort(wealths)

    # Gini coefficient is typically for non-negative incomes/wealth
    # Depending on the model, agents might temporarily have negative wealth if not handled
    # For this calculation, we assume non-negative or filter/handle as per model logic
    # If agent wealth can be negative and it's meaningful, this formula might need adjustment
    # or pre-processing of wealths.

    total_wealth = sum(sorted_wealths)

    # If total wealth is zero (e.g., all agents have zero wealth), Gini is 0 (perfect equality)
    total_wealth == 0 && return 0.0

    # Formula: G = ( (2 * sum_i(i * x_i)) / (n * sum_i(x_i)) ) - (n+1)/n
    # where x_i are sorted wealths
    weighted_sum_of_wealths = 0.0
    for i in 1:n
        weighted_sum_of_wealths += i * sorted_wealths[i]
    end

    gini = (2 * weighted_sum_of_wealths) / (n * total_wealth) - (n + 1) / n
    return gini
end

"""
    morans_i(model::StandardABM)

Calculate Moran's I for agent wealth to measure spatial autocorrelation (segregation).
"""
function morans_i(model::StandardABM)
    agents = allagents(model)
    n = nagents(model)
    n == 0 && return 0.0 # No agents, no segregation

    wealths = [a.wealth for a in agents]
    mean_wealth = sum(wealths) / n

    # Numerator and denominator for Moran's I
    numerator = 0.0
    denominator = 0.0
    sum_weights = 0.0

    # Create a mapping from agent ID to its index in the `agents` array for quick lookup
    agent_idx_map = Dict(a.id => i for (i, a) in enumerate(agents))

    for i in 1:n
        agent_i = agents[i]
        deviation_i = agent_i.wealth - mean_wealth
        denominator += deviation_i^2

        # Find neighbors (spatial weights w_ij = 1 if neighbor, 0 otherwise)
        # Consider Moore neighborhood (8 surrounding cells)
        for neighbor_pos in nearby_positions(agent_i.pos, model, 1) # radius 1 for Moore
            # Check if neighbor_pos is occupied by another agent
            agent_ids_in_pos = ids_in_position(neighbor_pos, model)
            for neighbor_id in agent_ids_in_pos
                if neighbor_id != agent_i.id # agent_j is a neighbor of agent_i
                    j = agent_idx_map[neighbor_id]
                    agent_j = agents[j]
                    deviation_j = agent_j.wealth - mean_wealth
                    numerator += deviation_i * deviation_j # w_ij is 1
                    sum_weights += 1.0
                end
            end
        end
    end

    # If sum_weights is 0 (no neighbors found for any agent, e.g., very sparse population or all agents at same pos with no other pos occupied)
    # or if denominator is 0 (all agents have the same wealth)
    # Moran's I is undefined or 0; returning 0 as a convention for no spatial autocorrelation.
    (sum_weights == 0 || denominator == 0) && return 0.0

    moran_val = (n / sum_weights) * (numerator / denominator)
    return moran_val
end

"Create a sugarscape ABM"
function sugarscape(;
    dims=(50, 50),
    sugar_peaks=((10, 40), (40, 10)),
    growth_rate=1,
    N=250,
    w0_dist=(5, 25),
    metabolic_rate_dist=(1, 4),
    vision_dist=(1, 6),
    max_age_dist=(60, 100),
    max_sugar=4,
    seed=42
)
    sugar_capacities = sugar_caps(dims, sugar_peaks, max_sugar, 6)
    sugar_values = deepcopy(sugar_capacities)
    space = GridSpaceSingle(dims)
    properties = Dict(
        :growth_rate => growth_rate,
        :N => N,
        :w0_dist => w0_dist,
        :metabolic_rate_dist => metabolic_rate_dist,
        :vision_dist => vision_dist,
        :max_age_dist => max_age_dist,
        :sugar_values => sugar_values,
        :sugar_capacities => sugar_capacities,
        :max_sugar => max_sugar,
        :deaths_starvation => 0,
        :deaths_age => 0,
        :total_lifespan_starvation => 0,
        :total_lifespan_age => 0,
    )
    model = StandardABM(
        SugarSeeker,
        space;
        agent_step!,
        model_step!,
        scheduler=Schedulers.Randomly(),
        properties=properties,
        rng=MersenneTwister(seed)
    )
    for _ in 1:N
        add_agent_single!(
            model,
            rand(abmrng(model), vision_dist[1]:vision_dist[2]),
            rand(abmrng(model), metabolic_rate_dist[1]:metabolic_rate_dist[2]),
            0,
            rand(abmrng(model), max_age_dist[1]:max_age_dist[2]),
            rand(abmrng(model), w0_dist[1]:w0_dist[2]),
        )
    end
    return model
end

# ## Defining stepping functions
# Now we define the stepping functions that handle the time evolution of the model.
# The model stepping function controls the sugar growth:
function model_step!(model)
    ## At each position, sugar grows back at a rate of α units
    ## per time-step up to the cell's capacity c.
    @inbounds for pos in positions(model)
        if model.sugar_values[pos...] < model.sugar_capacities[pos...]
            model.sugar_values[pos...] += model.growth_rate
        end
    end
    return
end

# The agent stepping function contains the dynamics of the model:
function agent_step!(agent, model)
    move_and_collect!(agent, model)
    replacement!(agent, model)
end

function move_and_collect!(agent, model)
    ## Go through all unoccupied positions within vision, and consider the empty ones.
    ## From those, identify the one with greatest amount of sugar, and go there!
    max_sugar_pos = agent.pos
    max_sugar = model.sugar_values[max_sugar_pos...]
    for pos in nearby_positions(agent, model, agent.vision)
        isempty(pos, model) || continue
        sugar = model.sugar_values[pos...]
        if sugar > max_sugar
            max_sugar = sugar
            max_sugar_pos = pos
        end
    end
    ## Move to the max sugar position (which could be where we are already)
    move_agent!(agent, max_sugar_pos, model)
    ## Collect the sugar there and update wealth (collected - consumed)
    agent.wealth += (model.sugar_values[max_sugar_pos...] - agent.metabolic_rate)
    model.sugar_values[max_sugar_pos...] = 0
    ## age
    agent.age += 1
    return
end

function replacement!(agent, model)
    ## If the agent's sugar wealth become zero or less, it dies
    if agent.wealth ≤ 0 || agent.age ≥ agent.max_age
        if agent.wealth <= 0
            model.deaths_starvation += 1
            model.total_lifespan_starvation += agent.age
        end
        if agent.age >= agent.max_age # agent can die of both starvation and old age simultaneously
            model.deaths_age += 1
            model.total_lifespan_age += agent.age
        end
        remove_agent!(agent, model)
        ## Whenever an agent dies, a young one is added to a random empty position
        add_agent_single!(
            model,
            rand(abmrng(model), model.vision_dist[1]:model.vision_dist[2]),
            rand(abmrng(model), model.metabolic_rate_dist[1]:model.metabolic_rate_dist[2]),
            0, # age
            rand(abmrng(model), model.max_age_dist[1]:model.max_age_dist[2]),
            rand(abmrng(model), model.w0_dist[1]:model.w0_dist[2]) # wealth
        )
    end
end

"""
    run_sugarscape_visualization(; model_kwargs...)

Launch an interactive Sugarscape visualization.
You can pass keyword arguments to the `sugarscape` model constructor.
"""
function run_sugarscape_visualization(; model_kwargs...)

    model = sugarscape(; model_kwargs...)
    fig, ax, abmp = abmplot(model; add_controls=false, figkwargs=(size = (800, 600)))
    sugar = @lift($(abmp.model).sugar_values)
    axhm, hm = heatmap(fig[1, 2], sugar; colormap=:thermal, colorrange=(0, 4))
    axhm.aspect = AxisAspect(1)
    Colorbar(fig[1, 3], hm, width=15, tellheight=false)
    rowsize!(fig.layout, 1, axhm.scene.viewport[].widths[2])
    s = Observable(0)
    t = @lift("Sugarscape, step = $($(s))")
    connect!(ax.title, t)
    ax.titlealign = :left
    display(fig)
    return fig
end

"""
    record_sugarscape_animation(filename::String="sugarvis_dashboard.mp4"; steps::Int=100, framerate::Int=10, model_kwargs...)

Run the Sugarscape model and record an animation of the simulation to `filename`.
You can pass keyword arguments to the `sugarscape` model constructor.
"""
function record_sugarscape_animation(filename::String="sugarvis_dashboard.mp4"; steps::Int=100, framerate::Int=10, model_kwargs...)
    model = sugarscape(; model_kwargs...)

    fig = Figure(size = (1400, 1000))
    s = Observable(0) # Step counter observable

    # --- Agent Plot (Top-Left) ---
    ax_agent = Axis(fig[1, 1], aspect=DataAspect())
    agent_c(a) = :yellow # Brighter color for agents
    agent_m(a) = :circle
    _returned_fig, returned_ax_agent, abmp = abmplot(model; ax=ax_agent, add_controls=false,
                                                     agent_color=agent_c, agent_marker=agent_m, agent_size=15) # Slightly larger
    connect!(returned_ax_agent.title, @lift("Sugarscape Simulation, Step: $($s)"))
    returned_ax_agent.titlealign = :left

    # Get model dimensions (assuming it's available from abmp.model[].sugar_values or similar)
    # This was already being done for the heatmap, ensure it's available here or re-fetch if necessary
    model_dims = size(abmp.model[].sugar_values) # Assuming sugar_values reflects grid dimensions
    xlims!(returned_ax_agent, 0.5, model_dims[2] + 0.5)
    ylims!(returned_ax_agent, 0.5, model_dims[1] + 0.5)

    hidedecorations!(returned_ax_agent) # Re-enable for cleaner look

    # --- Sugar Heatmap (Top-Right) ---
    ax_sugar_hm = Axis(fig[1, 2], title="Sugar Levels", aspect=DataAspect())
    sugar_content = @lift($(abmp.model).sugar_values)
    max_sug_val = abmp.model[].max_sugar
    hm = heatmap!(ax_sugar_hm, sugar_content; colormap=:thermal, colorrange=(0, max_sug_val))
    ylims!(ax_sugar_hm, 0.5, model_dims[1] + 0.5)
    Colorbar(fig[1,2], hm; label="Sugar", width=15, tellheight=false, vertical=true, halign=:right)
    hidedecorations!(ax_sugar_hm) # Re-enable for cleaner look

    # --- Wealth Histogram (Bottom-Left) ---
    ax_hist = Axis(fig[2, 1], xlabel="Wealth", ylabel="Number of Agents", title="Wealth Distribution")
    initial_model_state_for_hist = abmp.model[]
    initial_all_wealths = [a.wealth for a in allagents(initial_model_state_for_hist)]
    initial_valid_wealths = filter(w -> w >= 0, initial_all_wealths)
    current_wealths_obs = Observable(isempty(initial_valid_wealths) ? [0] : initial_valid_wealths)
    hist!(ax_hist, current_wealths_obs; bins=30, color=:lightblue, strokecolor=:black, strokewidth=1)
    autolimits!(ax_hist)

    # --- Gini Coefficient Plot (Bottom-Right) ---
    ax_gini = Axis(fig[2, 2], xlabel="Step", ylabel="Gini Coefficient", title="Gini Coefficient Over Time")
    gini_history_obs = Observable(Point2f[])
    lines!(ax_gini, gini_history_obs; color=:forestgreen)
    xlims!(ax_gini, 0, steps)
    ylims!(ax_gini, 0, 1)

    # Adjust layout for more balanced plot sizes AFTER all axes are created
    rowsize!(fig.layout, 1, Relative(0.5)) # Top row takes 50% height
    rowsize!(fig.layout, 2, Relative(0.5)) # Bottom row takes 50% height
    colsize!(fig.layout, 1, Relative(0.5)) # Left col takes 50% width
    colsize!(fig.layout, 2, Relative(0.5)) # Right col takes 50% width

    # Initial state (step 0)
    s[] = 0
    initial_gini = gini_coefficient(initial_valid_wealths) # Use the pre-calculated valid wealths
    initial_gini = isnan(initial_gini) ? 0.0 : initial_gini
    push!(gini_history_obs[], Point2f(0, initial_gini))
    notify(gini_history_obs) # Notify after push

    # Record loop for model steps 1 to `steps`
    record(fig, filename, 1:steps; framerate=framerate) do current_model_step
        Agents.step!(abmp, 1) # Step the model via ABMObservable. This advances model to current_model_step.
        s[] = current_model_step # Update step counter observable

        current_model_state = abmp.model[] # Get current model state

        # Update Wealth Histogram Data
        all_wealths = [a.wealth for a in allagents(current_model_state)]
        valid_wealths = filter(w -> w >= 0, all_wealths)
        current_wealths_obs[] = isempty(valid_wealths) ? [0] : valid_wealths # Use placeholder if empty
        autolimits!(ax_hist) # Adjust limits dynamically

        # Update Gini Coefficient Data
        current_gini = gini_coefficient(valid_wealths)
        current_gini = isnan(current_gini) ? 0.0 : current_gini

        push!(gini_history_obs[], Point2f(current_model_step, current_gini))
        notify(gini_history_obs) # Notify that the observable's content has changed
    end
    return filename
end

"""
    record_wealth_hist_animation(adata; filename="sugarhist.mp4", steps=50, framerate=3)

Record an animation of the wealth distribution histogram over time using the simulation data in `adata`.
The animation is saved to `filename`. By default, it animates the first 50 steps.
"""
function record_wealth_hist_animation(adata; filename::String="sugarhist.mp4", steps::Int=50, framerate::Int=3)

    figure = Figure(size=(600, 600))
    step_number = Observable(0)
    title_text = @lift("Wealth distribution of individuals, step = $($step_number)")
    Label(figure[1, 1], title_text; fontsize=20, tellwidth=false)
    ax = Axis(figure[2, 1]; xlabel="Wealth", ylabel="Number of agents")
    histdata = Observable(adata[adata.time.==0, :wealth])
    h = hist!(ax, histdata)
    ylims!(ax, (0, 50))

    record(figure, filename, 0:steps; framerate=framerate) do i
        histdata[] = adata[adata.time.==i, :wealth]
        step_number[] = i
        if !isempty(histdata[])
            xlims!(ax, (0, maximum(histdata[])))
        end
    end
    return filename
end

end # module Sugarscape
