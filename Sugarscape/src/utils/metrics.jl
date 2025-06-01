using Agents
using Statistics

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

    total_wealth = sum(sorted_wealths)

    total_wealth == 0 && return 0.0

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
    agents_list = collect(allagents(model)) # Use collect to ensure it's an indexable array
    n = length(agents_list)
    n == 0 && return 0.0 # No agents, no segregation

    wealths = [a.wealth for a in agents_list]
    mean_wealth = sum(wealths) / n

    numerator = 0.0
    denominator = 0.0
    sum_weights = 0.0

    agent_idx_map = Dict(a.id => i for (i, a) in enumerate(agents_list))

    for i in 1:n
        agent_i = agents_list[i]
        deviation_i = agent_i.sugar - mean_wealth
        denominator += deviation_i^2

        for neighbor_pos in nearby_positions(agent_i.pos, model, 1)
            agent_ids_in_pos = ids_in_position(neighbor_pos, model)
            for neighbor_id in agent_ids_in_pos
                if neighbor_id != agent_i.id
                    # Check if neighbor_id is in the map (it should be if agents_list is comprehensive)
                    if haskey(agent_idx_map, neighbor_id)
                        j = agent_idx_map[neighbor_id]
                        agent_j = agents_list[j]
                        deviation_j = agent_j.sugar - mean_wealth
                        numerator += deviation_i * deviation_j # w_ij is 1
                        sum_weights += 1.0
                    end
                end
            end
        end
    end

    (sum_weights == 0 || denominator == 0) && return 0.0

    moran_val = (n / sum_weights) * (numerator / denominator)
    return moran_val
end
