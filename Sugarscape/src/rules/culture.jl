"""
Culture (K) Rule Implementation
Each agent has a cultural tag that spreads through interaction with neighbors.
"""

"""
Cultural transmission rule: agents copy cultural traits from neighbors with small probability.
For each agent:
1. Select a neighboring agent at random;
2. Select a tag randomly;
3. If the neighbor agrees with the agent at that tag position, no change is made;
4. if they disagree, the neighbor’s tag is flipped to agree with the agent’s tag;
5. Repeat for all neighbors.
(Kehoe, 2016, p.35)
"""

function build_culture_context(agent, model, neighbors)
  culture_context = Dict(
    :agent_id => agent.id,
    :agent_culture => agent.culture,
    :neighbors => []
  )

  for neighbor in neighbors
    push!(culture_context[:neighbors], Dict(
      :agent_id => neighbor.id,
      :culture => neighbor.culture
    ))
  end

  return culture_context
end


function culture_spread!(agent, model, check_decision::Bool=false)
  neighbors = collect(nearby_agents(agent, model, 1))
  isempty(neighbors) && return

  if model.use_llm_decisions

    culture_context = build_culture_context(agent, model, neighbors)
    culture_decision = SugarscapeLLM.get_culture_decision(culture_context, model)

    if culture_decision.spread_culture === false || culture_decision.transmit_to === nothing
      return
    end

    llm_attempt_culture_spread!(agent, model, culture_decision)

    if check_decision
      return culture_decision
    end
  else
    attempt_culture_spread!(agent, neighbors, model)
  end
end

"""
Initialize random cultural tag for an agent.
"""
function initialize_culture(tag_length::Int, model)
  return BitVector(rand(abmrng(model), Bool, tag_length))
end

"""
Crossover function for cultural inheritance.
For each bit position, randomly chooses from one of the two parents with 50% probability.
"""
function crossover_culture(c1::BitVector, c2::BitVector, model)::BitVector
  length(c1) != length(c2) && error("Cultural tags must have the same length")
  return BitVector([rand(abmrng(model), Bool) ? c1[i] : c2[i] for i in 1:length(c1)])
end

function attempt_culture_spread!(agent, neighbours, model)
  for neighbour in neighbours
    idx = rand(abmrng(model), 1:length(agent.culture))

    if length(neighbour.culture) != length(agent.culture)
      error("Cultural tags must have uniform length across agents")
    end

    # Rule K-2: flip neighbour's randomly chosen bit so it matches the focal agent
    if neighbour.culture[idx] != agent.culture[idx]
      neighbour.culture[idx] = agent.culture[idx]
    end
  end

end

function llm_attempt_culture_spread!(agent, model, culture_decision)
  for decision in culture_decision.transmit_to
    # extract the target agent and tag index from the LLM decision
    neighbour_id = decision["target_id"]
    idx = decision["tag_index"]
    neighbor = getindex(model, neighbour_id)

    if length(neighbor.culture) != length(agent.culture)
      error("Cultural tags must have uniform length across agents")
    end

    # Rule K-2: flip neighbour's randomly chosen bit so it matches the focal agent
    if neighbor.culture[idx] != agent.culture[idx]
      neighbor.culture[idx] = agent.culture[idx]
    end
  end

end

# ==============================================================================
# Cultural analytics functions
# ==============================================================================

"""
Calculate Shannon entropy of cultural diversity in the population.
Higher entropy indicates more cultural diversity.
"""
function cultural_entropy(model)
  if nagents(model) == 0
    return 0.0
  end

  # Determine the maximum tag length among all agents
  tag_length = maximum(length(a.culture) for a in allagents(model))

  # If no one has a tag, entropy is zero
  tag_length == 0 && return 0.0

  bit_frequencies = zeros(tag_length)

  # Count frequency of 1s at each bit position, guarding against shorter tags
  for agent in allagents(model)
    for i in 1:min(tag_length, length(agent.culture))
      if agent.culture[i]
        bit_frequencies[i] += 1
      end
    end
  end

  # Normalize to probabilities
  bit_frequencies ./= nagents(model)

  # Calculate entropy
  entropy = 0.0
  for freq in bit_frequencies
    if freq > 0 && freq < 1
      entropy -= freq * log2(freq) + (1 - freq) * log2(1 - freq)
    end
  end

  return entropy / tag_length  # Average entropy per bit
end

"""
Count number of unique cultural types in the population.
"""
function unique_cultures(model)
  if nagents(model) == 0
    return 0
  end

  culture_set = Set{BitVector}()
  for agent in allagents(model)
    push!(culture_set, Tuple(agent.culture))
  end

  return length(culture_set)
end

"""
Calculate mean Hamming distance between all pairs of agents.
Higher values indicate more cultural diversity.
"""
function mean_hamming_distance(model)
  agents = collect(allagents(model))
  n = length(agents)

  if n < 2
    return 0.0
  end

  total_distance = 0.0
  pairs = 0

  for i in 1:n
    for j in (i+1):n
      # Use the length common to both tags to avoid BoundsError
      tag_length = min(length(agents[i].culture), length(agents[j].culture))
      if tag_length == 0
        continue
      end
      distance = sum(agents[i].culture[1:tag_length] .⊻ agents[j].culture[1:tag_length])  # XOR gives Hamming distance
      total_distance += distance
      pairs += 1
    end
  end

  return total_distance / pairs
end

"""
Identify cultural islands: contiguous regions of agents with similar cultural tags.
Returns a dictionary mapping culture types to their spatial clustering coefficient.
"""
function cultural_islands(model, similarity_threshold=0.8)
  if nagents(model) == 0
    return Dict{BitVector,Float64}()
  end

  islands = Dict{BitVector,Vector{Tuple{Int,Int}}}()

  # Group agents by similar culture
  for agent in allagents(model)
    culture_found = false
    agent_culture = copy(agent.culture)

    for (existing_culture, positions) in islands
      # Calculate similarity (proportion of matching bits)
      similarity = 1.0 - sum(agent_culture .⊻ existing_culture) / length(agent_culture)

      if similarity >= similarity_threshold
        push!(positions, agent.pos)
        culture_found = true
        break
      end
    end

    if !culture_found
      islands[agent_culture] = [agent.pos]
    end
  end

  # Calculate clustering coefficient for each culture group
  clustering_coeffs = Dict{BitVector,Float64}()

  for (culture, positions) in islands
    if length(positions) < 2
      clustering_coeffs[culture] = 0.0
      continue
    end

    # Calculate average distance between positions of same culture
    total_distance = 0.0
    pairs = 0

    for i in 1:length(positions)
      for j in (i+1):length(positions)
        distance = sqrt(sum((positions[i][k] - positions[j][k])^2 for k in 1:2))
        total_distance += distance
        pairs += 1
      end
    end

    avg_distance = total_distance / pairs
    # Convert distance to clustering coefficient (inverse relationship)
    clustering_coeffs[culture] = 1.0 / (1.0 + avg_distance)
  end

  return clustering_coeffs
end

# === Tribe & Cultural difference helpers (Rule K-3) ===
"""
    tribe(agent) -> Symbol

Return `:blue` when the number of zeros in the cultural bit-string exceeds the
number of ones, otherwise return `:red` (Rule K-3).
"""
function tribe(agent)::Symbol
  ones = count(==(true), agent.culture)
  zeros = length(agent.culture) - ones
  return zeros > ones ? :blue : :red
end

"""
    same_tribe(a, b) -> Bool

True when both agents belong to the same tribe (Rule K-3).
"""
same_tribe(a, b) = tribe(a) == tribe(b)

"""
    culturally_different(agent1, agent2) -> Bool

Agents are culturally different when their tribes differ.  This definition is
used by the Combat extension (Rule C-α 2) and various analytics utilities.
"""
function culturally_different(agent1, agent2)
  return !same_tribe(agent1, agent2)
end
