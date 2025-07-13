function build_reproduction_context(agent, model, eligible_partners, max_partners)

  eligible_partners_context = Vector{Dict{Symbol,Any}}()
  for ep in eligible_partners
    if is_fertile(ep, model) && agent.sex != ep.sex
      push!(eligible_partners_context, Dict(
        :id => ep.id,
        :sugar => ep.sugar,
        :age => ep.age,
        :sex => ep.sex,
        :culture => ep.culture,
        :partner_empty_nearby_positions => collect(empty_nearby_positions(ep, model)),
      ))
    end
  end

  reproduction_context = Dict{Symbol,Any}(
    :agent_id => agent.id,
    :position => agent.pos,
    :sugar => agent.sugar,
    :age => agent.age,
    :metabolism => agent.metabolism,
    :vision => agent.vision,
    :sex => agent.sex,
    :eligible_partners => eligible_partners_context,
    :max_partners => max_partners,
    # doesn't need to know values of empty_nearby_positions
    :empty_nearby_positions => collect(empty_nearby_positions(agent, model)),
  )

  return reproduction_context
end

"""
    reproduction!(agent, model)
Handles reproduction for a single agent, checking fertility and eligible partners.
If the agent is fertile, it will attempt to reproduce with eligible partners.
Returns nothing if no reproduction occurs.
"""

function reproduction!(agent, model)
  is_fertile(agent, model) || return

  # filter nearby agents to only include fertile agents of opposite sex
  eligible_partners = filter(ep -> is_fertile(ep, model) && agent.sex != ep.sex, collect(nearby_agents(agent, model, 1)))

  if eligible_partners |> isempty
    return
  end

  @info "Eligible partners for reproduction: $eligible_partners"

  max_partners = max_matings(agent)

  if model.use_llm_decisions
    # llm specific reproduction logic
    reproduction_context = build_reproduction_context(agent, model, eligible_partners, max_partners)
    reproduction_decision = SugarscapeLLM.get_reproduction_decision(reproduction_context, model)

    for partner_id in reproduction_decision.partners
      partner = getindex(model, partner_id)
      @info "Partner llm: $partner"
      attempt_reproduction!(agent, partner, model)
    end
  else
    # original reproduction logic
    # pick max_partners random partners from eligible_partners
    partners = rand(abmrng(model), eligible_partners, max_partners)
    for partner in partners
      @info "Partner original: $partner"
      attempt_reproduction!(agent, partner, model)
    end
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

  # Cultural inheritance always uses crossover so that tag length remains
  # consistent irrespective of whether the K-rule is active.
  culture = crossover_culture(parent1.culture, parent2.culture, model)

  # Create child with inheritance tracking fields
  child = add_agent!(pos, SugarscapeAgent, model, vision, metabolism, child_sugar, 0, max_age, sex, false, child_sugar, Int[], 0.0, culture, NTuple{4,Int}[], BitVector[], falses(model.disease_immunity_length))

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
Return the maximum number of matings an agent can afford *this turn*.

Given the current sugar stock (s) and initial endowment (e₀), the agent
can mate while its sugar after each mating (halving) remains ≥ e₀.
The count is therefore

    floor(log2(s / e₀)) + 1  # if s ≥ e₀
    0                         # otherwise
"""
function max_matings(agent)
  ratio = agent.sugar / agent.initial_sugar
  return max(floor(Int, log2(ratio)) + 1, 0)
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

"""
    attempt_reproduction!(agent, partner, model)
Core reproduction logic extracted so other modules (e.g. LLM-driven partner
selection) can trigger the same behaviour without duplicating code.
Returns the child ID on success, or `nothing` if no free cell was available.
"""
function attempt_reproduction!(agent, partner, model)
  # double check if both agents are fertile
  is_fertile(agent, model) || return nothing
  is_fertile(partner, model) || return nothing

  free_cells = collect(empty_nearby_positions(agent, model))
  isempty(free_cells) && return nothing

  child_pos = rand(abmrng(model), free_cells)
  @info "Creating child at position $child_pos"
  child_id = create_child(agent, partner, child_pos, model)

  push!(agent.children, child_id)
  push!(partner.children, child_id)

  agent.has_reproduced = true
  partner.has_reproduced = true

  # Increment per-step reproduction counters stored in the model
  model.reproduction_counts_step[agent.id] = get(model.reproduction_counts_step, agent.id, 0) + 1
  model.reproduction_counts_step[partner.id] = get(model.reproduction_counts_step, partner.id, 0) + 1

  return child_id
end
