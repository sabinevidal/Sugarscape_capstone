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

      # Handle boundaries (GridSpaceSingle)
      if all(1 .<= pos .<= size(model.space))
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
  return collect(agents_in_position(pos, model))  # Use Agents.jl built-in
end

"""
    culturally_different(agent1, agent2)

Check if two agents have different cultural tags.
Returns true if their culture BitVectors are different.
"""
function culturally_different(agent1, agent2)
  return agent1.culture != agent2.culture
end

"""
    combat!(model)

Execute the Combat Rule for all agents in the model.
Agents scan their vision for valid targets and attack the most rewarding one.

Combat conditions:
- Target must be weaker (less sugar)
- Target must be culturally different
- Target's position must be unoccupied by other agents
- Reward = min(target.sugar, combat_limit)
"""
function combat!(model)
  # Skip if combat is disabled
  !model.enable_combat && return

  # Get agents in random order to avoid bias
  agents_list = collect(allagents(model))
  shuffle!(abmrng(model), agents_list)

  for attacker in agents_list
    # Skip if attacker was killed earlier in this combat step
    !(attacker.id in keys(model.agents)) && continue

    candidates = []

    # Scan all visible positions for potential targets
    for pos in visible_positions(attacker, model)
      agents_at_pos = get_agents_at_position(model, pos)

      # Only consider positions with exactly one agent (the potential target)
      if length(agents_at_pos) == 1
        target = first(agents_at_pos)

        # Check all combat conditions
        if target.id != attacker.id &&                    # Not self
           target.sugar < attacker.sugar &&              # Target is weaker
           culturally_different(attacker, target)        # Culturally different

          reward = min(target.sugar, model.combat_limit)
          push!(candidates, (pos, target, reward))
        end
      end
    end

    # Execute attack if valid targets exist
    if !isempty(candidates)
      # Select target with maximum reward (break ties randomly)
      max_reward = maximum(c -> c[3], candidates)
      best_candidates = filter(c -> c[3] == max_reward, candidates)
      best_pos, victim, stolen = rand(abmrng(model), best_candidates)

      # Execute combat
      attacker.sugar += stolen
      remove_agent!(victim, model)
      move_agent!(attacker, best_pos, model)

      # Update combat statistics
      model.combat_kills += 1
      model.combat_sugar_stolen += stolen
    end
  end
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
of culturally different neighboring pairs relative to all neighboring pairs.
Higher values indicate more cultural fragmentation and potential for conflict.
"""
function cultural_conflict_intensity(model)
  if !model.enable_culture || nagents(model) < 2
    return 0.0
  end

  total_pairs = 0
  different_pairs = 0

  for agent in allagents(model)
    neighbors = nearby_agents(agent, model, 1)
    for neighbor in neighbors
      total_pairs += 1
      if culturally_different(agent, neighbor)
        different_pairs += 1
      end
    end
  end

  return total_pairs > 0 ? different_pairs / total_pairs : 0.0
end

"""
    wealth_based_dominance(model)

Calculate the correlation between agent wealth and their spatial dominance
(number of weaker neighbors they could potentially attack).
"""
function wealth_based_dominance(model)
  if nagents(model) < 2
    return 0.0
  end

  wealth_dominance_pairs = []

  for agent in allagents(model)
    weaker_neighbors = 0
    total_neighbors = 0

    # Count neighbors within vision that could be attacked
    for pos in visible_positions(agent, model)
      agents_at_pos = get_agents_at_position(model, pos)
      if length(agents_at_pos) == 1
        neighbor = first(agents_at_pos)
        if neighbor.id != agent.id
          total_neighbors += 1
          if neighbor.sugar < agent.sugar && culturally_different(agent, neighbor)
            weaker_neighbors += 1
          end
        end
      end
    end

    dominance = total_neighbors > 0 ? weaker_neighbors / total_neighbors : 0.0
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
