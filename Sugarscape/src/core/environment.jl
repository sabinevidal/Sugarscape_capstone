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
function pollution_diffusion!(model)
    new_pollution = similar(model.pollution)   # allocate array with same type & size

    @inbounds for pos in positions(model)      # iterate over every lattice cell
        neighbours = nearby_positions(pos, model, 1)  # Von Neumann neighbourhood (radius 1, manhattan metric inherited from space)
        if isempty(neighbours)
            new_pollution[pos...] = model.pollution[pos...]   # edge-case, e.g. 1×1 grid
        else
            total = zero(eltype(model.pollution))
            @inbounds for npos in neighbours
                total += model.pollution[npos...]
            end
            new_pollution[pos...] = total / length(neighbours)
        end
    end

    # Commit the diffusion step in-place
    model.pollution .= new_pollution
    return
end
