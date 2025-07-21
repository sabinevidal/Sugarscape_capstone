"""
Combat (L) Rule Implementation for Sugarscape

The Combat Rule allows agents to attack and rob other agents under specific conditions:
1. Target must be within vision range
2. Target must be weaker (less sugar)
3. Target must be culturally different
4. Target's cell must be unoccupied by others
5. Attacker steals min(target.sugar, combat_limit) and kills target
"""

using Agents
using Random

"""
    visible_positions(agent, model)

Get all positions visible to an agent in the four cardinal directions up to their vision range.
Returns a vector of position tuples that are within the model boundaries.
"""
function visible_positions(agent, model)
  positions = []
  for direction in [(1, 0), (-1, 0), (0, 1), (0, -1)]  # cardinal directions
    for distance in 1:agent.vision
      pos = (agent.pos[1] + distance * direction[1],
        agent.pos[2] + distance * direction[2])

      # Handle boundaries (GridSpaceSingle) – access the internal `:space` field
      # via `getfield` to bypass `getproperty`, which would otherwise look into
      # the `properties` Dict and raise a `KeyError` for `:space`.
      if all(1 .<= pos .<= size(getfield(model, :space)))
        push!(positions, pos)
      end
    end
  end
  return positions
end

"""
    get_agents_at_position(model, pos)

Get all agents at a specific position. Returns a vector of agents.
"""
function get_agents_at_position(model, pos)
  # `agents_in_position` is not defined for `GridSpaceSingle`. Instead, we
  # simply filter the existing agents. Because `GridSpaceSingle` guarantees at
  # most one agent per cell, this comprehension is cheap.
  return [agent for agent in allagents(model) if agent.pos == pos]
end

"""
    exposed_to_retaliation(attacker, target_pos, model) -> Bool

Return `true` when *any* stronger enemy (different tribe) can see `target_pos`
within their own vision (Combat Rule C-α 4).
"""
function exposed_to_retaliation(model; attacker, target_pos, future=attacker.sugar)
  for other in allagents(model)
    other.id == attacker.id && continue           # skip self
    culturally_different(attacker, other) || continue
    other.sugar > future || continue              # stronger *after* we cash in
    target_pos in visible_positions(other, model) && return true
  end
  return false
end

"""
    combat!(model)

**Deprecated.** The combat rule now executes asynchronously via
`maybe_combat!(agent, model)` inside each agent step.  This
function is kept for backwards compatibility but simply iterates over
all agents and calls `maybe_combat!`.
"""
function combat!(model)
  !model.enable_combat && return

  for ag in allagents(model)
    maybe_combat!(ag, model)
  end
end

"""
    build_combat_context(agent, model)

Construct the context sent to the LLM for combat decisions.  It
includes a list of eligible target agents (id, position and sugar).
"""
function build_combat_context(agent, model)
  targets = Vector{Dict{String,Any}}()
  for pos in visible_positions(agent, model)
    occs = get_agents_at_position(model, pos)
    length(occs) == 1 || continue
    victim = first(occs)
    culturally_different(agent, victim) || continue
    victim.sugar < agent.sugar || continue
    push!(targets, Dict(
      "id" => victim.id,
      "position" => victim.pos,
      "sugar" => victim.sugar,
    ))
  end
  return Dict(
    "agent_id" => agent.id,
    "position" => agent.pos,
    "sugar" => agent.sugar,
    "vision" => agent.vision,
    "eligible_targets" => targets,
  )
end

"""
    maybe_combat!(attacker, model)

Asynchronous combat rule.  The agent evaluates eligible targets and
either attacks one (based on an LLM decision when enabled) or falls
back to movement via the M-rule.
"""
function maybe_combat!(attacker, model)
  if !model.enable_combat
    movement!(attacker, model)
    return
  end

  candidates = Vector{Tuple{Tuple{Int,Int},SugarscapeAgent,Float64,Float64}}()
  for pos in visible_positions(attacker, model)
    occs = get_agents_at_position(model, pos)
    length(occs) == 1 || continue
    victim = first(occs)
    culturally_different(attacker, victim) || continue
    victim.sugar < attacker.sugar || continue

    site_sugar = model.sugar_values[pos...]
    reward = site_sugar + min(victim.sugar, model.combat_limit)
    reward == 0.0 && continue

    exposed_to_retaliation(model; attacker, target_pos=pos,
                           future=attacker.sugar + reward) && continue

    dist = euclidean_distance(attacker.pos, pos)
    push!(candidates, (pos, victim, reward, dist))
  end

  if model.use_llm_decisions
    decision = get_decision(attacker, model)
    should_attack = decision.combat
    target_id = decision.combat_target

    valid = should_attack && target_id !== nothing &&
            any(c -> c[2].id == target_id, candidates)

    if !valid
      movement!(attacker, model)
      return
    end

    idx = findfirst(c -> c[2].id == target_id, candidates)
    target_pos, victim, reward, _ = candidates[idx]
  else
    isempty(candidates) && return movement!(attacker, model)

    max_reward = maximum(c[3] for c in candidates)
    best = filter(c -> c[3] == max_reward, candidates)
    min_dist = minimum(c[4] for c in best)
    chosen = filter(c -> c[4] == min_dist, best)
    target_pos, victim, reward, _ = rand(abmrng(model), chosen)
  end

  site_sugar = model.sugar_values[target_pos...]
  stolen = min(victim.sugar, model.combat_limit)
  collected = site_sugar + stolen

  death!(victim, model, :combat)
  model.combat_kills += 1

  move_agent!(attacker, target_pos, model)
  attacker.sugar += collected - attacker.metabolism
  attacker.age += 1

  if model.enable_pollution
    produced_pollution = model.production_rate * site_sugar +
                         model.consumption_rate * attacker.metabolism
    model.pollution[target_pos...] += produced_pollution
  end

  model.sugar_values[target_pos...] = 0.0
  model.combat_sugar_stolen += stolen
  push!(model.agents_moved_combat, attacker.id)
end

"""
    combat_death_rate(model)

Calculate the proportion of deaths due to combat.
Returns the ratio of combat kills to total deaths.
"""
function combat_death_rate(model)
  total_deaths = model.deaths_starvation + model.deaths_age + model.combat_kills
  return total_deaths > 0 ? model.combat_kills / total_deaths : 0.0
end

"""
    average_combat_reward(model)

Calculate the average sugar stolen per combat kill.
Returns 0.0 if no combat kills have occurred.
"""
function average_combat_reward(model)
  return model.combat_kills > 0 ? model.combat_sugar_stolen / model.combat_kills : 0.0
end

"""
    cultural_conflict_intensity(model)

Measure the intensity of cultural conflict by calculating the proportion
of culturally different neighbouring pairs relative to all neighbouring pairs.
Higher values indicate more cultural fragmentation and potential for conflict.
"""
function cultural_conflict_intensity(model)
  if !model.enable_culture || nagents(model) < 2
    return 0.0
  end

  total_pairs = 0
  different_pairs = 0

  for agent in allagents(model)
    neighbours = nearby_agents(agent, model, 1)
    for neighbour in neighbours
      total_pairs += 1
      if culturally_different(agent, neighbour)
        different_pairs += 1
      end
    end
  end

  return total_pairs > 0 ? different_pairs / total_pairs : 0.0
end

"""
    wealth_based_dominance(model)

Calculate the correlation between agent wealth and their spatial dominance
(number of weaker neighbours they could potentially attack).
"""
function wealth_based_dominance(model)
  if nagents(model) < 2
    return 0.0
  end

  wealth_dominance_pairs = []

  for agent in allagents(model)
    weaker_neighbours = 0
    total_neighbours = 0

    # Count neighbours within vision that could be attacked
    for pos in visible_positions(agent, model)
      agents_at_pos = get_agents_at_position(model, pos)
      if length(agents_at_pos) == 1
        neighbour = first(agents_at_pos)
        if neighbour.id != agent.id
          total_neighbours += 1
          if neighbour.sugar < agent.sugar && culturally_different(agent, neighbour)
            weaker_neighbours += 1
          end
        end
      end
    end

    dominance = total_neighbours > 0 ? weaker_neighbours / total_neighbours : 0.0
    push!(wealth_dominance_pairs, (agent.sugar, dominance))
  end

  if length(wealth_dominance_pairs) < 2
    return 0.0
  end

  # Calculate correlation coefficient
  wealths = [p[1] for p in wealth_dominance_pairs]
  dominances = [p[2] for p in wealth_dominance_pairs]

  mean_wealth = sum(wealths) / length(wealths)
  mean_dominance = sum(dominances) / length(dominances)

  numerator = sum((w - mean_wealth) * (d - mean_dominance) for (w, d) in zip(wealths, dominances))
  wealth_variance = sum((w - mean_wealth)^2 for w in wealths)
  dominance_variance = sum((d - mean_dominance)^2 for d in dominances)

  if wealth_variance == 0 || dominance_variance == 0
    return 0.0
  end

  return numerator / sqrt(wealth_variance * dominance_variance)
end
