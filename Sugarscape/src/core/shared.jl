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
# Movement (M) Rule
Look out as far as vision permits in the four principal lattice directions and
identify the unoccupied site(s) having the most sugar (or highest welfare when
pollution is considered). If the greatest value appears on multiple sites then
select the nearest; if still tied choose randomly. Move to this site and collect
all sugar there.
"""
function movement!(agent, model)
  # Welfare or sugar at the current position (baseline option)
  current_val = model.enable_pollution ? welfare(agent.pos, model) :
                model.sugar_values[agent.pos...]
  best_positions = [(agent.pos, current_val, 0.0)]  # (pos, value, distance)
  max_val = current_val
  min_dist = 0.0

  # Examine neighbourhood within vision range
  for pos in nearby_positions(agent, model, agent.vision)
    # Skip occupied cells – agent can only move to empty ones
    !isempty(pos, model) && continue

    val = model.enable_pollution ? welfare(pos, model) :
          model.sugar_values[pos...]
    dist = euclidean_distance(agent.pos, pos)

    if val > max_val
      max_val = val
      min_dist = dist
      best_positions = [(pos, val, dist)]
    elseif val == max_val
      if dist < min_dist
        min_dist = dist
        best_positions = [(pos, val, dist)]
      elseif dist == min_dist
        push!(best_positions, (pos, val, dist))
      end
    end
  end

  # Choose among best (nearest, then random tie-break)
  chosen_pos, _, _ = rand(abmrng(model), best_positions)
  _do_move!(agent, model, chosen_pos)

  return
end

# -----------------------------------------------------------------------------
# LLM-compatible movement wrapper
# -----------------------------------------------------------------------------

"""
    try_llm_move!(agent, model, target_pos)

Attempt to move `agent` to `target_pos` proposed by an LLM. The move is allowed
only if the cell is empty, within the agent's vision and inside the grid
bounds. Otherwise the function falls back to the standard `movement!` rule so
that the simulation never crashes due to an invalid suggestion.
"""
function try_llm_move!(agent, model, target_pos)
  # Defensive: ensure we have a tuple of integers
  !(target_pos isa Tuple{Int,Int}) && return movement!(agent, model)

  if isempty(target_pos, model) &&
     euclidean_distance(agent.pos, target_pos) <= agent.vision &&
     all(1 .<= target_pos .<= size(getfield(model, :space)))
    _do_move!(agent, model, target_pos)
  else
    movement!(agent, model)
  end
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

  remove_agent!(agent, model)
end
