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
