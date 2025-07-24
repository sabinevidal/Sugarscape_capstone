"""
Shared utilities for Sugarscape model logic.

This file contains helper functions and generic rule implementations that are
needed by both the pure rule-based model (core) and the LLM-augmented model.
Keeping them here avoids code duplication and ensures consistent behaviour
between the two execution paths.
"""

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
    last_partner_id = Int[]
    last_credit_partner = Int[]

    # Check if this is a Big Five model and create appropriate agent type
    if model.use_big_five
      if isa(agent, BigFiveSugarscapeAgent) && hasproperty(model, :big_five_mvn_dist) && !isnothing(model.big_five_mvn_dist)
        # Create a BigFiveSugarscapeAgent with random traits from the MVN distribution
        traits_sample = BigFiveProcessor.sample_agents(model.big_five_mvn_dist, 1)[1]
        traits = (
          openness=traits_sample.Openness,
          conscientiousness=traits_sample.Conscientiousness,
          extraversion=traits_sample.Extraversion,
          agreeableness=traits_sample.Agreeableness,
          neuroticism=traits_sample.Neuroticism,
        )

        add_agent!(pos, BigFiveSugarscapeAgent, model, vision, metabolism, sugar, age, max_age,
          sex, has_reproduced, sugar, children, total_inheritance_received,
          culture, loans_given, loans_owed, diseases, immunity, last_partner_id, last_credit_partner, traits)
      else
        # Create a regular SugarscapeAgent
        add_agent!(pos, SugarscapeAgent, model, vision, metabolism, sugar, age, max_age,
          sex, has_reproduced, sugar, children, total_inheritance_received,
          culture, loans_given, loans_owed, diseases, immunity, last_partner_id, last_credit_partner)
      end
    elseif model.use_schwartz_values
      if isa(agent, SchwartzValuesSugarscapeAgent) && hasproperty(model, :schwartz_values_mvn_dist) && !isnothing(model.schwartz_values_mvn_dist)
        # Create a SchwartzValuesSugarscapeAgent with random traits from the MVN distribution
        traits_sample = SchwartzValuesProcessor.sample_agents(model.schwartz_values_mvn_dist, 1)[1]
        schwartz_values = (
          self_direction=traits_sample.SelfDirection,
          stimulation=traits_sample.Stimulation,
          hedonism=traits_sample.Hedonism,
          achievement=traits_sample.Achievement,
          power=traits_sample.Power,
          security=traits_sample.Security,
          conformity=traits_sample.Conformity,
          tradition=traits_sample.Tradition,
          benevolence=traits_sample.Benevolence,
          universalism=traits_sample.Universalism,
        )

        add_agent!(pos, SchwartzValuesSugarscapeAgent, model, vision, metabolism, sugar, age, max_age,
          sex, has_reproduced, sugar, children, total_inheritance_received,
          culture, loans_given, loans_owed, diseases, immunity, last_partner_id, last_credit_partner, schwartz_values)
      else
        # Create a regular SugarscapeAgent
        add_agent!(pos, SugarscapeAgent, model, vision, metabolism, sugar, age, max_age,
          sex, has_reproduced, sugar, children, total_inheritance_received,
          culture, loans_given, loans_owed, diseases, immunity, last_partner_id, last_credit_partner)
      end
    else
      # Create a regular SugarscapeAgent when neither use_big_five nor use_schwartz_values is enabled
      add_agent!(pos, SugarscapeAgent, model, vision, metabolism, sugar, age, max_age,
        sex, has_reproduced, sugar, children, total_inheritance_received,
        culture, loans_given, loans_owed, diseases, immunity, last_partner_id, last_credit_partner)
    end
  end
end
