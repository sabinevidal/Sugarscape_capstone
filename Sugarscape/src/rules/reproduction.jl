"""
Reproduction (S) Rule Implementation
"""

"""
Reproduction Rule:
"""
function build_reproduction_context(agent, model, eligible_partners, max_partners)

  eligible_partners_context = Vector{Dict{String,Any}}()
  for ep in eligible_partners
    if is_fertile(ep, model) && agent.sex != ep.sex
      push!(eligible_partners_context, Dict{String,Any}(
        "id" => ep.id,
        "sugar" => ep.sugar,
        "age" => ep.age,
        "sex" => ep.sex,
        "culture" => ep.culture,
        "empty_nearby_positions_for_partner" => collect(empty_nearby_positions(ep, model)),
      ))
    end
  end

  reproduction_context = Dict{String,Any}(
    "agent_id" => agent.id,
    "position" => agent.pos,
    "sugar" => agent.sugar,
    "min_sugar_for_reproduction" => agent.initial_sugar,
    "age" => agent.age,
    "metabolism" => agent.metabolism,
    "vision" => agent.vision,
    "sex" => agent.sex,
    "eligible_partners" => eligible_partners_context,
    "max_partners" => max_partners,
    # doesn't need to know values of empty_nearby_positions
    "empty_nearby_positions" => collect(empty_nearby_positions(agent, model)),
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
  model.reproduction_counts_step = Dict{Int,Int}()
  is_fertile(agent, model) || return

  # filter nearby agents to only include fertile agents of opposite sex
  nearby = nearby_agents(agent, model, 1)
  eligible_partners = filter(ep -> is_fertile(ep, model) && agent.sex != ep.sex, nearby === nothing ? [] : collect(nearby))


  if eligible_partners === nothing || isempty(eligible_partners)
    return
  end

  max_partners = max_matings(agent)

  if max_partners == 0
    #  Agent cannot afford any matings this turn.
    return
  end

  if model.use_llm_decisions
    # llm specific reproduction logic
    if model.use_big_five
      reproduction_context = build_big_five_reproduction_context(agent, model, eligible_partners, max_partners)
    elseif model.use_schwartz_values
      reproduction_context = build_schwartz_values_reproduction_context(agent, model, eligible_partners, max_partners)
    else
      reproduction_context = build_reproduction_context(agent, model, eligible_partners, max_partners)
    end
    reproduction_decision = SugarscapeLLM.get_reproduction_decision(reproduction_context, model)

    if reproduction_decision.reproduce === false || reproduction_decision.partners === nothing || isempty(reproduction_decision.partners)
      agent.chose_not_to_reproduce = true
      return
    end

    for partner_id in reproduction_decision.partners
      partner = getindex(model, partner_id)
      attempt_reproduction!(agent, partner, model)
    end
  else
    # original reproduction logic
    # pick max_partners random partners from eligible_partners
    partners = rand(abmrng(model), eligible_partners, max_partners)
    for partner in partners
      attempt_reproduction!(agent, partner, model)
    end
  end

  push!(model.reproduction_counts_history, model.reproduction_counts_step)

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
  loans_given = Dict{Int,Vector{Sugarscape.Loan}}()
  loans_owed = Dict{Int,Vector{Sugarscape.Loan}}()
  diseases = BitVector[]
  immunity = falses(model.disease_immunity_length)
  last_partner_id = Int[]
  last_credit_partner = Int[]
  chose_not_to_attack = false
  chose_not_to_borrow = false
  chose_not_to_lend = false
  chose_not_to_reproduce = false
  chose_not_to_spread_culture = false

  # Create child based on whether Big Five traits are enabled
  if model.use_big_five
    traits_sample = BigFiveProcessor.sample_agents(model.big_five_mvn_dist, 1)
    traits_row = traits_sample[1, :]

    child_traits = (
      openness=traits_row.Openness,
      conscientiousness=traits_row.Conscientiousness,
      extraversion=traits_row.Extraversion,
      agreeableness=traits_row.Agreeableness,
      neuroticism=traits_row.Neuroticism
    )

    child = add_agent!(pos, BigFiveSugarscapeAgent, model, vision, metabolism, child_sugar, 0, max_age, sex, false, false, false, child_sugar, Int[], 0.0, culture, loans_given, loans_owed, diseases, immunity, last_partner_id, last_credit_partner, chose_not_to_attack, chose_not_to_borrow, chose_not_to_lend, chose_not_to_reproduce, chose_not_to_spread_culture, child_traits)

  elseif model.use_schwartz_values
    values_sample = SchwartzValuesProcessor.sample_agents(model.schwartz_values_mvn_dist, 1)
    values_row = values_sample[1, :]

    child_values = (
      self_direction=values_row.self_direction,
      stimulation=values_row.stimulation,
      hedonism=values_row.hedonism,
      achievement=values_row.achievement,
      power=values_row.power,
      security=values_row.security,
      conformity=values_row.conformity,
      tradition=values_row.tradition,
      benevolence=values_row.benevolence,
      universalism=values_row.universalism
    )

    child = add_agent!(pos, SchwartzValuesSugarscapeAgent, model, vision, metabolism, child_sugar, 0, max_age, sex, false, false, false, child_sugar, Int[], 0.0, culture, loans_given, loans_owed, diseases, immunity, last_partner_id, last_credit_partner, chose_not_to_attack, chose_not_to_borrow, chose_not_to_lend, chose_not_to_reproduce, chose_not_to_spread_culture, child_values)
  else
    child = add_agent!(pos, SugarscapeAgent, model, vision, metabolism, child_sugar, 0, max_age, sex, false, false, false, child_sugar, Int[], 0.0, culture, loans_given, loans_owed, diseases, immunity, last_partner_id, last_credit_partner, chose_not_to_attack, chose_not_to_borrow, chose_not_to_lend, chose_not_to_reproduce, chose_not_to_spread_culture)
  end

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

function is_fertile_by_age(agent, model)
  min_age, max_age = model.fertility_age_range
  return agent.age >= min_age && agent.age <= max_age
end

"""
    max_matings(agent)
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

  free_cells = union(collect(empty_nearby_positions(agent, model)), collect(empty_nearby_positions(partner, model)))
  isempty(free_cells) && return nothing

  child_pos = rand(abmrng(model), free_cells)
  child_id = create_child(agent, partner, child_pos, model)

  push!(agent.children, child_id)
  push!(partner.children, child_id)

  agent.has_reproduced = true
  partner.has_reproduced = true

  # Add partner IDs to track reproduction partners in this step
  push!(agent.last_partner_id, partner.id)
  push!(partner.last_partner_id, agent.id)

  # Increment per-step reproduction counters stored in the model
  model.reproduction_counts_step[agent.id] = get(model.reproduction_counts_step, agent.id, 0) + 1
  model.reproduction_counts_step[partner.id] = get(model.reproduction_counts_step, partner.id, 0) + 1

  return child_id
end
