"""
Combat (C) Rule Implementation for Sugarscape
- Look out as far as directions;
- Throw out all sites occupied by members of the agent's own tribe;
- Throw out all sites occupied by members of different tribes who are wealthier than the agent;
- The reward of each remaining site is given by the resource level at the site plus, if it is occupied, the minimum of a and  the occupant's wealth;
- Throw out all sites that are vulnerable to retaliation;
- Select the nearest position having maximum reward and go there;
- Gather the resources at the site plus the minimum of a and  the occupant's wealth, if the site was occupied;
- If the site was occupied, then the former occupant is considered "killed" - permanently removed from play.
"""

using Agents
using Random

"""
    visible_positions(agent, model)

Get all positions visible to an agent in the four cardinal directions up to their vision range.
Returns a vector of position tuples that are within the model boundaries.
"""
function visible_positions(agent, model)
  # Collect the coordinates of *agents* that are within the agent's vision range
  # using Agents.jl built-in spatial query. We do **not** enumerate empty cells
  # because combat considers only occupied sites.
  positions = Tuple{Int,Int}[]
  for other in nearby_agents(agent, model, agent.vision)
    other.id == agent.id && continue  # skip self
    push!(positions, other.pos)
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
function exposed_to_retaliation(model; attacker, target_pos, future)
  for other in nearby_agents(attacker, model, attacker.vision)
    other.id == attacker.id && continue           # skip self
    culturally_different(attacker, other) || continue
    other.sugar > future || continue              # stronger *after* we cash in
    target_pos in visible_positions(other, model) && return true
  end
  return false
end

"""
    build_combat_context(agent, model)

Construct the context sent to the LLM for combat decisions.  It
includes a list of eligible target agents (id, position and sugar).
"""
function build_combat_context(agent, model, candidates)
  targets = Vector{Dict{String,Any}}()
  for candidate in candidates
    # candidate is a tuple: (position, agent, sugar, distance)
    pos, target_agent, sugar, distance = candidate
    push!(targets, Dict(
      "id" => target_agent.id,
      "position" => target_agent.pos,
      "sugar" => target_agent.sugar,
      "culture" => target_agent.culture
    ))
  end
  return Dict(
    "agent_id" => agent.id,
    "position" => agent.pos,
    "sugar" => agent.sugar,
    "vision" => agent.vision,
    "metabolism" => agent.metabolism,
    "culture" => agent.culture,
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

  candidates = Vector{Tuple{Tuple{Int,Int},Any,Float64,Float64}}()
  # Iterate over *nearby agents* instead of manually scanning positions
  for victim in nearby_agents(attacker, model, attacker.vision)
    victim.id == attacker.id && continue                                   # skip self
    culturally_different(attacker, victim) || continue                     # must be enemy
    victim.sugar < attacker.sugar || continue                              # attacker must be stronger

    pos = victim.pos
    # Reward = current sugar on site + growback that will occur this tick + victim's wealth
    site_sugar = model.sugar_values[pos...]
    reward = site_sugar + model.growth_rate + victim.sugar
    reward == 0.0 && continue

    exposed_to_retaliation(model; attacker, target_pos=pos,
      future=attacker.sugar + reward) && continue

    dist = euclidean_distance(attacker.pos, pos)
    push!(candidates, (pos, victim, reward, dist))
  end

  if model.use_llm_decisions
    # combat context
    if model.use_big_five
      combat_context = build_big_five_combat_context(attacker, model, candidates)
    elseif model.use_schwartz_values
      combat_context = build_schwartz_values_combat_context(attacker, model, candidates)
    else
      combat_context = build_combat_context(attacker, model, candidates)
    end
    # get combat decision
    combat_decision = SugarscapeLLM.get_combat_decision(combat_context, model)

    should_attack = combat_decision.combat
    target_id = combat_decision.combat_target

    if !should_attack || target_id === nothing
      attacker.chose_not_to_attack = true
      movement!(attacker, model)
      return
    end

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
