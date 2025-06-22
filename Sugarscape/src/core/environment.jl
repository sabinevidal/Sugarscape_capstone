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
Sugarscape Growback (Gα) Rule
At each lattice position, sugar grows  back at a rate of a units per time interval up to the capacity at that position. (Epstein & Axtell, 1996)
"""
function growback!(model)
    ## At each position, sugar grows back at a rate of α units
    ## per time-step up to the cell's capacity c.
    @inbounds for pos_tuple in positions(model)
        if model.sugar_values[pos_tuple...] < model.sugar_capacities[pos_tuple...]
            model.sugar_values[pos_tuple...] += model.growth_rate
            # Ensure sugar does not exceed capacity
            if model.sugar_values[pos_tuple...] > model.sugar_capacities[pos_tuple...]
                model.sugar_values[pos_tuple...] = model.sugar_capacities[pos_tuple...]
            end
        end
    end
    return
end

"""
Seasonal Sugarscape Growback Rule
Initially it is summer in the top half of the sugarscape and winter in the bottom half.
Then, every 'Y' (model.season_duration) time periods the seasons flip.
For each site, if the season is summer then sugar grows back at a rate of 'α' (model.growth_rate) units per time interval;
if the season is winter then the growback rate is 'α / ~' (model.growth_rate / model.winter_growth_divisor) units per time interval.
"""
function seasonal_growback!(model)
    grid_height = size(model.sugar_capacities, 2) # Assuming dims are (width, height) for model.sugar_capacities
    mid_point = grid_height ÷ 2

    @inbounds for pos_tuple in positions(model)
        pos_y = pos_tuple[2] # y-coordinate determines top/bottom half

        # Assuming origin (1,1) is top-left, so smaller y is "top"
        # If origin (1,1) is bottom-left, this condition needs to be pos_y > mid_point
        in_top_half = pos_y <= mid_point

        is_summer_season_for_cell = (model.is_summer_top && in_top_half) || (!model.is_summer_top && !in_top_half)

        current_growth_rate = if is_summer_season_for_cell
            model.growth_rate
        else
            model.growth_rate / model.winter_growth_divisor
        end

        # Ensure growth rate results in an integer if sugar_values is Int, or allow float.
        # For now, direct division is used. If growth_rate is Int, integer division will truncate.

        if model.sugar_values[pos_tuple...] < model.sugar_capacities[pos_tuple...]
            potential_sugar = model.sugar_values[pos_tuple...] + current_growth_rate
            model.sugar_values[pos_tuple...] = min(potential_sugar, model.sugar_capacities[pos_tuple...])
        end
    end
    return
end

"""
Pollution Diffusion Rule (Da)
Each 'model.pollution_diffusion_interval' time periods and at each site,
compute the pollution flux - the average pollution level over all von Neumann neighboring sites.
Each site's flux becomes its new pollution level.
"""
function diffuse_pollution!(model)
    dims = size(model.pollution)
    new_pollution = deepcopy(model.pollution) # To store new values temporarily

    for x in 1:dims[1]
        for y in 1:dims[2]
            current_pos = (x, y)
            neighbor_pollution_sum = 0.0
            num_neighbors = 0

            # Get Von Neumann neighbors
            # Using nearby_positions with radius 1 and manhattan metric implicitly gives Von Neumann for GridSpace
            # However, a more direct implementation might be clearer or more efficient if nearby_positions is complex.
            # For now, let's manually iterate to be explicit about Von Neumann.
            # Agents.jl's positions(model) gives tuples, so we construct them for neighbor checks.

            potential_neighbors = [
                (x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)
            ]

            for neighbor_pos_tuple in potential_neighbors
                # Check bounds for non-periodic grids.
                # If your grid is periodic, this check is handled by GridSpace utilities, but here we are direct.
                # Assuming model.space handles periodicity if needed, or we implement it.
                # For simplicity, this assumes a non-periodic grid or that out-of-bounds access is handled by model.pollution access (e.g. if it's padded or Agents.jl handles it)
                # A robust way is to use `nearby_positions` from Agents.jl for a specific position and metric.
                # Let's use a simpler, direct check for Von Neumann, assuming non-periodic for this manual iteration.

                nx, ny = neighbor_pos_tuple
                if 1 <= nx <= dims[1] && 1 <= ny <= dims[2]
                    neighbor_pollution_sum += model.pollution[nx, ny]
                    num_neighbors += 1
                end
            end

            if num_neighbors > 0
                new_pollution[x, y] = neighbor_pollution_sum / num_neighbors
            else
                new_pollution[x, y] = model.pollution[x, y] # Should not happen in a connected grid unless it's a 1x1 grid.
            end
        end
    end

    # Update the model's pollution grid
    model.pollution .= new_pollution # In-place update of the entire grid
    return
end
