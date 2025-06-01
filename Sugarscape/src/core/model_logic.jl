using Agents, Random, Distributions

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
    seed=42,
    season_duration::Int=20, # Y time periods for season length
    winter_growth_divisor::Int=4, # Growth rate is growth_rate / winter_growth_divisor in winter
    enable_pollution::Bool=false,
    pollution_production_rate::Float64=1.0, # α for pollution
    pollution_consumption_rate::Float64=1.0, # β for pollution
    pollution_diffusion_interval::Int=10, # Dα time periods for diffusion
    enable_reproduction::Bool=false, # Enable sexual reproduction
    fertility_age_range::Tuple{Int,Int}=(18, 50), # Age range for fertility
    initial_child_sugar::Int=6, # Sugar given to newborn children
)
    # Convert sugar_caps output to Float64 and ensure _sugar_values is also Float64
    _sugar_capacities_int = sugar_caps(dims, sugar_peaks, max_sugar, 6) # Get as Int first
    _sugar_capacities = Float64.(_sugar_capacities_int) # Convert to Float64
    _sugar_values = deepcopy(_sugar_capacities) # Now _sugar_values is also Float64
    _pollution_values = fill(0.0, dims) # Initialize pollution grid with floats
    space = GridSpaceSingle(dims)

    properties = Dict(
        :growth_rate => growth_rate,
        :N => N, # Initial number of agents
        :w0_dist => w0_dist,
        :metabolic_rate_dist => metabolic_rate_dist,
        :vision_dist => vision_dist,
        :max_age_dist => max_age_dist,
        :sugar_values => _sugar_values, # Use renamed variable
        :sugar_capacities => _sugar_capacities, # Use renamed variable
        :max_sugar => max_sugar,
        :deaths_starvation => 0,
        :deaths_age => 0,
        :total_lifespan_starvation => 0,
        :total_lifespan_age => 0,
        :births => 0, # Track total births from reproduction
        :season_duration => season_duration,
        :winter_growth_divisor => winter_growth_divisor,
        :is_summer_top => true, # Initially summer in the top half
        :current_season_steps => 0,
        :enable_pollution => enable_pollution,
        :pollution => _pollution_values,
        :production_rate => pollution_production_rate, # α
        :consumption_rate => pollution_consumption_rate, # β
        :pollution_diffusion_interval => pollution_diffusion_interval, # Dα
        :current_pollution_diffusion_steps => 0,
        :enable_reproduction => enable_reproduction,
        :initial_child_sugar => initial_child_sugar,
        :fertility_age_range => fertility_age_range,
    )
    model = StandardABM(
        SugarscapeAgent,
        space;
        (agent_step!)=_agent_step!, # Renamed to avoid potential global scope issues
        (model_step!)=_model_step!, # Renamed
        scheduler=Schedulers.Randomly(),
        properties=properties,
        rng=MersenneTwister(seed)
    )
    for _ in 1:N
        # Create initial agents with proper initialization
        vision = rand(abmrng(model), vision_dist[1]:vision_dist[2])
        metabolism = rand(abmrng(model), metabolic_rate_dist[1]:metabolic_rate_dist[2])
        age = 0
        max_age = rand(abmrng(model), max_age_dist[1]:max_age_dist[2])
        sugar = Float64(rand(abmrng(model), w0_dist[1]:w0_dist[2]))
        sex = rand(abmrng(model), (:male, :female))
        has_mated = false

        # Find a random empty position explicitly
        pos = random_empty(model)
        # Use add_agent! with explicit position
        add_agent!(pos, SugarscapeAgent, model, vision, metabolism, sugar, age, max_age, sex, has_mated, sugar)
    end
    return model
end

function _model_step!(model) # Renamed
    # growback!(model) # Call the function from environment.jl
    seasonal_growback!(model) # Call the new seasonal growback function

    # Season flipping logic
    model.current_season_steps += 1
    if model.current_season_steps >= model.season_duration
        model.is_summer_top = !model.is_summer_top
        model.current_season_steps = 0
    end

    # Pollution diffusion logic
    if model.enable_pollution
        model.current_pollution_diffusion_steps += 1
        if model.current_pollution_diffusion_steps >= model.pollution_diffusion_interval
            diffuse_pollution!(model)
            model.current_pollution_diffusion_steps = 0
        end
    end

    # Reproduction logic
    if model.enable_reproduction
        mating!(model)
    end

    return
end

function _agent_step!(agent, model)
    move_and_collect!(agent, model)
    if !model.enable_reproduction
        replacement!(agent, model)
    else
        # With reproduction enabled, only remove dead agents without replacement
        if agent.sugar ≤ 0 || agent.age ≥ agent.max_age
            if agent.sugar <= 0
                model.deaths_starvation += 1
                model.total_lifespan_starvation += agent.age
            end
            if agent.age >= agent.max_age
                model.deaths_age += 1
                model.total_lifespan_age += agent.age
            end
            remove_agent!(agent, model)
        end
    end
end

"""
Calculates the welfare of a position, considering sugar and pollution.
Used when model.enable_pollution is true.
"""
function welfare(pos_tuple, model)
    sugar_at_pos = model.sugar_values[pos_tuple...]
    pollution_at_pos = model.pollution[pos_tuple...]
    return sugar_at_pos / (1.0 + pollution_at_pos) # Added 1.0 to avoid division by zero if pollution is 0 and ensure float division
end

"""
# Movement (M) Rule
Look out as far as vision permits in the four principal lattice directions and identify the unoccupied site(s) having the most sugar; If the greatest sugar value appears on multiple sites then select the nearest one; Move to this site; Collect all the sugar at this new position.
"""
function move_and_collect!(agent, model)
    # Start with current position as default
    current_pos_welfare = model.enable_pollution ? welfare(agent.pos, model) : model.sugar_values[agent.pos...]
    best_positions = [(agent.pos, current_pos_welfare, 0)] # (position, welfare_or_sugar, distance)
    max_welfare_or_sugar = current_pos_welfare
    min_distance = 0

    # Check all positions within vision
    for pos_tuple in nearby_positions(agent, model, agent.vision)
        isempty(pos_tuple, model) || continue # Agent can only move to empty cells

        value_at_pos = model.enable_pollution ? welfare(pos_tuple, model) : model.sugar_values[pos_tuple...]
        distance = euclidean_distance(agent.pos, pos_tuple)

        if value_at_pos > max_welfare_or_sugar
            # Found higher welfare/sugar - reset candidates
            max_welfare_or_sugar = value_at_pos
            min_distance = distance
            best_positions = [(pos_tuple, value_at_pos, distance)]
        elseif value_at_pos == max_welfare_or_sugar
            if distance < min_distance
                # Same welfare/sugar but closer - reset candidates
                min_distance = distance
                best_positions = [(pos_tuple, value_at_pos, distance)]
            elseif distance == min_distance
                # Same welfare/sugar and same distance - add to candidates
                push!(best_positions, (pos_tuple, value_at_pos, distance))
            end
            # If distance > min_distance, ignore (farther away with same welfare/sugar)
        end
    end

    # Choose randomly among the best positions (closest with maximum welfare/sugar)
    chosen_pos, _, _ = rand(abmrng(model), best_positions)
    sugar_collected = model.sugar_values[chosen_pos...]

    move_agent!(agent, chosen_pos, model)

    agent.sugar += (sugar_collected - agent.metabolism)
    model.sugar_values[chosen_pos...] = 0
    agent.age += 1

    if model.enable_pollution
        # Pollution Formation
        produced_pollution = model.production_rate * sugar_collected + model.consumption_rate * agent.metabolism
        model.pollution[chosen_pos...] += produced_pollution
    end

    return
end

# Helper function to calculate Euclidean distance between two positions
function euclidean_distance(pos1, pos2)
    return sqrt(sum((pos1[i] - pos2[i])^2 for i in 1:length(pos1)))
end

"""
Replacement (R[a,b]) Rule
When an agent dies it is replaced by an agent of age 0 having random genetic position on the sugarscape. random initial endowment, and a maximum age randomly selected from the range [a,b]. (Epstein & Axtell, 1996, p 32-33)
"""
function replacement!(agent, model)
    if agent.sugar ≤ 0 || agent.age ≥ agent.max_age
        died_by_starvation = false
        died_by_age = false

        if agent.sugar <= 0
            model.deaths_starvation += 1
            model.total_lifespan_starvation += agent.age
            died_by_starvation = true
        end
        if agent.age >= agent.max_age
            model.deaths_age += 1 # This could double count if agent dies of both.
            # If an agent dies of starvation at max_age, it's counted in both.
            model.total_lifespan_age += agent.age
            died_by_age = true
        end

        remove_agent!(agent, model)

        # Create replacement agent with proper initialization
        vision = rand(abmrng(model), model.vision_dist[1]:model.vision_dist[2])
        metabolism = rand(abmrng(model), model.metabolic_rate_dist[1]:model.metabolic_rate_dist[2])
        age = 0
        max_age = rand(abmrng(model), model.max_age_dist[1]:model.max_age_dist[2])
        sugar = Float64(rand(abmrng(model), model.w0_dist[1]:model.w0_dist[2]))
        sex = rand(abmrng(model), (:male, :female))
        has_mated = false

        # Find a random empty position explicitly
        pos = random_empty(model)
        add_agent!(pos, SugarscapeAgent, model, vision, metabolism, sugar, age, max_age, sex, has_mated, sugar)
    end
end
