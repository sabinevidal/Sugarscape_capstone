"""
Shared utilities for Sugarscape model logic.

This file contains helper functions and generic rule implementations that are
needed by both the pure rule-based model (core) and the LLM-augmented model.
Keeping them here avoids code duplication and ensures consistent behaviour
between the two execution paths.
"""

# -----------------------------------------------------------------------------
# Welfare / distance helpers
# -----------------------------------------------------------------------------

"""
    welfare(pos_tuple, model) -> Float64

Compute the welfare at a grid position. When pollution is enabled, welfare is
sugar ÷ (1 + pollution); otherwise it is simply the amount of sugar in the cell.
The added constant `1.0` protects against division-by-zero and ensures the
computation uses floating-point arithmetic.
"""
function welfare(pos_tuple, model)
  sugar_at_pos = model.sugar_values[pos_tuple...]
  pollution_at_pos = model.pollution[pos_tuple...]
  return sugar_at_pos / (1.0 + pollution_at_pos)
end

"""
    euclidean_distance(pos1, pos2) -> Float64

Return the Euclidean distance between two lattice positions given as tuples.
"""
function euclidean_distance(pos1, pos2)
  return sqrt(sum((pos1[i] - pos2[i])^2 for i in 1:length(pos1)))
end

# -----------------------------------------------------------------------------
# Movement rule and helpers (M-rule core)
# -----------------------------------------------------------------------------

"""
    _do_move!(agent, model, target_pos)

Internal helper that performs the side-effects of moving an `agent` to
`target_pos`: collects sugar, applies metabolism & ageing, and optionally
produces pollution. It is shared by both the vanilla M-rule and LLM-directed
moves so that their bookkeeping stays identical.
"""
function _do_move!(agent, model, target_pos)
  sugar_collected = model.sugar_values[target_pos...]
  move_agent!(agent, target_pos, model)
  agent.sugar += (sugar_collected - agent.metabolism)
  model.sugar_values[target_pos...] = 0
  agent.age += 1

  if model.enable_pollution
    produced_pollution = model.production_rate * sugar_collected +
                         model.consumption_rate * agent.metabolism
    model.pollution[target_pos...] += produced_pollution
  end
end

"""
    evaluate_nearby_positions(agent, model) -> Vector{Tuple{NTuple{2,Int}, Float64, Float64}}

Evaluate all positions within an agent's vision range to find all available move targets.
Returns a vector of tuples containing (position, value, distance) for all visible unoccupied
positions, where value is either sugar or welfare depending on whether pollution is enabled.

The returned positions include all unoccupied cells within vision range, sorted by value
(descending) and then by distance (ascending). The agent's current position is always
included as a baseline option.
"""
function evaluate_nearby_positions(agent, model)
  # Welfare or sugar at the current position (baseline option)
  current_val = model.enable_pollution ? welfare(agent.pos, model) :
                model.sugar_values[agent.pos...]
  all_positions = [(agent.pos, current_val, 0.0)]  # (pos, value, distance)

  for pos in nearby_positions(agent, model, agent.vision)
    # Skip occupied cells – agent can only move to empty ones
    !isempty(pos, model) && continue

    sugar_val = model.enable_pollution ? welfare(pos, model) :
                model.sugar_values[pos...]
    dist = euclidean_distance(agent.pos, pos)

    push!(all_positions, (pos, sugar_val, dist))
  end

  # Sort by value (descending) then by distance (ascending)
  sort!(all_positions, by=x -> (-x[2], x[3]))

  return all_positions
end

"""
    get_best_positions(agent, model) -> Vector{Tuple{NTuple{2,Int}, Float64, Float64}}

Extract the best maximum value positions from all visible positions.
Returns only the positions with the highest value (sugar or welfare), and among
those with equal values, only the nearest ones. This replicates the original
filtering logic of evaluate_nearby_positions.
"""
function get_best_positions(agent, model)
  all_positions = evaluate_nearby_positions(agent, model)

  if isempty(all_positions)
    return all_positions
  end

  # Get the maximum value (first position has highest value due to sorting)
  max_val = all_positions[1][2]
  min_dist = all_positions[1][3]
  best_positions = [all_positions[1]]

  # Find all positions with the same maximum value and minimum distance
  for (pos, val, dist) in all_positions[2:end]
    if val == max_val && dist == min_dist
      push!(best_positions, (pos, val, dist))
    elseif val < max_val
      break  # No more positions with maximum value
    end
  end

  return best_positions
end

"""
# Movement (M) Rule
Look out as far as vision permits in the four principal lattice directions and
identify the unoccupied site(s) having the most sugar (or highest welfare when
pollution is considered). If the greatest value appears on multiple sites then
select the nearest; if still tied choose randomly. Move to this site and collect
all sugar there.
"""
function movement!(agent, model)
  best_positions = get_best_positions(agent, model)

  # Choose among best (nearest, then random tie-break)
  chosen_pos, _, _ = rand(abmrng(model), best_positions)
  _do_move!(agent, model, chosen_pos)

  return
end



# -----------------------------------------------------------------------------
# Centralised death helper (shared by both logic paths)
# -----------------------------------------------------------------------------

"""
    death!(agent, model, cause::Symbol = :unknown)

Remove an `agent` from the simulation, applying inheritance when reproduction
is enabled and maintaining death statistics. The valid `cause` symbols are
:starvation, :age, and :combat.
"""
function death!(agent, model, cause::Symbol=:unknown)
  # Apply inheritance first (only relevant when reproduction is on)
  if model.enable_reproduction
    distribute_inheritance(agent, model)
  end

  # Stats bookkeeping
  if cause === :starvation
    model.deaths_starvation += 1
    model.total_lifespan_starvation += agent.age
  elseif cause === :age
    model.deaths_age += 1
    model.total_lifespan_age += agent.age
    # :combat is tracked separately in combat.jl
  end

  # Remove any loans involving this agent
  if model.enable_credit
    clear_loans_on_death!(agent, model)
  end
  remove_agent!(agent, model)
end

# -----------------------------------------------------------------------------
# Replacement (R-rule) helper
# -----------------------------------------------------------------------------
function death_replacement!(agent, model)
  if agent.sugar ≤ 0 || agent.age ≥ agent.max_age
    cause = agent.sugar ≤ 0 ? :starvation : :age
    death!(agent, model, cause)

    vision = rand(abmrng(model), model.vision_dist[1]:model.vision_dist[2])
    metabolism = rand(abmrng(model), model.metabolic_rate_dist[1]:model.metabolic_rate_dist[2])
    age = 0
    max_age = rand(abmrng(model), model.max_age_dist[1]:model.max_age_dist[2])
    sugar = Float64(rand(abmrng(model), model.initial_sugar_dist[1]:model.initial_sugar_dist[2]))
    sex = rand(abmrng(model), (:male, :female))
    has_reproduced = false
    children = Int[]
    total_inheritance_received = 0.0
    culture = initialize_culture(model.culture_tag_length, model)

    pos = random_empty(model)
    loans_given = Dict{Int,Vector{Sugarscape.Loan}}()
    loans_owed = Dict{Int,Vector{Sugarscape.Loan}}()
    diseases = BitVector[]
    immunity = falses(model.disease_immunity_length)

    add_agent!(pos, SugarscapeAgent, model, vision, metabolism, sugar, age, max_age,
      sex, has_reproduced, sugar, children, total_inheritance_received,
      culture, loans_given, loans_owed, diseases, immunity)
  end
end
