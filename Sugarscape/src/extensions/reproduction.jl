function mating!(model)
  agents = collect(allagents(model))
  shuffle!(abmrng(model), agents)  # for fairness
  for agent in agents
    agent.has_mated && continue  # already mated

    is_fertile(agent, model) || continue

    neighbors = nearby_agents(agent, model, 1)  # Von Neumann or Moore neighborhood
    for partner in neighbors
      if partner.id != agent.id &&
         is_fertile(partner, model) &&
         !partner.has_mated &&
         agent.sex != partner.sex

        free_cells = collect(empty_nearby_positions(agent, model))
        isempty(free_cells) && continue

        # Choose one empty spot for child
        child_pos = rand(abmrng(model), free_cells)

        # Create child using add_agent! directly - this handles ID assignment automatically
        child_id = create_child(agent, partner, child_pos, model)

        # Add child ID to both parents' children lists
        push!(agent.children, child_id)
        push!(partner.children, child_id)

        # Mark both as having mated
        agent.has_mated = true
        partner.has_mated = true

        break  # only one partner per tick
      end
    end
  end

  # Reset mating status
  for agent in allagents(model)
    agent.has_mated = false
  end
end

function create_child(parent1, parent2, pos, model)
  # Each parent contributes half of their initial endowment
  parent1_contribution = parent1.initial_sugar / 2
  parent2_contribution = parent2.initial_sugar / 2
  child_sugar = parent1_contribution + parent2_contribution

  # Subtract contributions from parents
  parent1.sugar -= parent1_contribution
  parent2.sugar -= parent2_contribution

  metabolism = rand(abmrng(model), (parent1.metabolism, parent2.metabolism))
  vision = rand(abmrng(model), (parent1.vision, parent2.vision))
  max_age = rand(abmrng(model), (parent1.max_age, parent2.max_age))
  sex = rand(abmrng(model), (:male, :female))

  # Cultural inheritance through crossover
  culture = if model.enable_culture
    crossover_culture(parent1.culture, parent2.culture, model)
  else
    BitVector()
  end

  # Create child with inheritance tracking fields
  child = add_agent!(pos, SugarscapeAgent, model, vision, metabolism, child_sugar, 0, max_age, sex, false, child_sugar, Int[], 0.0, culture)

  # Track birth in model statistics
  model.births += 1

  return child.id  # Return child ID for parent tracking
end

function is_fertile(agent, model)
  min_age, max_age = model.fertility_age_range
  # Check both age and wealth criteria for fertility
  age_eligible = agent.age ≥ min_age && agent.age ≤ max_age
  wealth_eligible = agent.sugar ≥ agent.initial_sugar  # Must have at least initial endowment
  return age_eligible && wealth_eligible
end

"""
Crossover function for bit vectors (culture and immunity).
Randomly selects bits from each parent.
"""
function crossover(parent1_bits::BitVector, parent2_bits::BitVector, model)
  length1, length2 = length(parent1_bits), length(parent2_bits)
  # Use the minimum length to avoid index errors
  min_length = min(length1, length2)

  child_bits = BitVector(undef, min_length)
  for i in 1:min_length
    child_bits[i] = rand(abmrng(model), Bool) ? parent1_bits[i] : parent2_bits[i]
  end

  return child_bits
end
