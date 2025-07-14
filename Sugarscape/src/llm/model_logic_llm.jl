using Agents, Random, Distributions, DotEnv
DotEnv.load!()

# =============================================================================
# LLM-enabled Sugarscape model logic                                          #
# =============================================================================

# NOTE: This file contains the LLM-enabled implementation of the Sugarscape model.
# It builds on the shared utilities in `shared.jl` and provides LLM-specific
# guards and helpers for agent decision-making.

# -----------------------------------------------------------------------------
# LLM integration types & helpers (kept verbatim)                              |
# -----------------------------------------------------------------------------

const LLMDecision = NamedTuple{(
    :move, :move_coords, :combat, :combat_target,
    :credit, :credit_partner, :reproduce, :reproduce_with
  ),Tuple{Bool,Union{Nothing,Tuple{Int,Int}},Bool,Union{Nothing,Int},
    Bool,Union{Nothing,Int},Bool,Union{Nothing,Int}}}

function should_act(agent, model, ::Val{R}) where {R}
  !model.use_llm_decisions && return false
  if !haskey(model.llm_decisions, agent.id)
    error("Agent $(agent.id) missing LLM decision when use_llm_decisions=true")
  end
  return getfield(model.llm_decisions[agent.id], R)
end

function get_decision(agent, model)
  if !haskey(model.llm_decisions, agent.id)
    error("Agent $(agent.id) missing LLM decision when use_llm_decisions=true")
  end
  return model.llm_decisions[agent.id]
end

"""
    idle!(agent, model)

Handles agent metabolism and ageing when movement is skipped.
Collects sugar at current position, applies metabolism, and ages the agent.
"""
function idle!(agent, model)
  sugar_collected = model.sugar_values[agent.pos...]
  agent.sugar += sugar_collected
  model.sugar_values[agent.pos...] = 0

  agent.sugar -= agent.metabolism
  agent.age += 1

  if model.enable_pollution
    produced_pollution = model.production_rate * sugar_collected +
                         model.consumption_rate * agent.metabolism
    model.pollution[agent.pos...] += produced_pollution
  end
end

"""
    llm_move!(agent, model, target_pos)

Attempt to move `agent` to `target_pos` proposed by an LLM. The move is allowed
only if the cell is empty, within the agent's vision and inside the grid
bounds. If the target is invalid or `nothing`, the agent stays idle.
"""
function llm_move!(agent, model, target_pos)
  # If no target specified, agent stays idle
  pos_before = agent.pos

  if target_pos === nothing
    idle!(agent, model)
    return
  end

  # Defensive: ensure we have a tuple of integers
  if !(target_pos isa Tuple{Int,Int})
    idle!(agent, model)
    return
  end

  if isempty(target_pos, model) &&
     euclidean_distance(agent.pos, target_pos) <= agent.vision &&
     all(1 .<= target_pos .<= size(getfield(model, :space)))
    _do_move!(agent, model, target_pos)
  else
    # Invalid target - agent stays idle
    idle!(agent, model)
  end
end

# -----------------------------------------------------------------------------
# Constructor: sugarscape_llm                                                  |
# -----------------------------------------------------------------------------

"""
    sugarscape_llm(; kwargs...) -> StandardABM

Create a Sugarscape model with LLM decision-making enabled.  This largely
mirrors the original constructor but keeps explicit parameters to control LLM
API usage.
"""
function sugarscape_llm(;  # signature mirrors original for brevity
  dims=(50, 50),
  gridspace_metric::Symbol=:manhattan,
  sugar_peaks=((10, 40), (40, 10)),
  growth_rate=1,
  N=100,
  w0_dist=(5, 25),
  metabolic_rate_dist=(1, 4),
  vision_dist=(1, 6),
  max_age_dist=(60, 100),
  max_sugar=4,
  seed=42,
  season_duration::Int=20,
  winter_growth_divisor::Int=4,
  enable_seasonality::Bool=true,
  enable_pollution::Bool=false,
  pollution_production_rate::Float64=1.0,
  pollution_consumption_rate::Float64=1.0,
  pollution_diffusion_interval::Int=10,
  enable_reproduction::Bool=false,
  fertility_age_range::Tuple{Int,Int}=(18, 50),
  male_fertility_start::Int=12,
  male_fertility_end::Int=50,
  female_fertility_start::Int=12,
  female_fertility_end::Int=40,
  initial_child_sugar::Int=6,
  enable_culture::Bool=false,
  culture_tag_length::Int=11,
  culture_copy_prob::Float64=1 / 11,
  enable_combat::Bool=false,
  combat_limit::Int=50,
  enable_disease::Bool=false,
  disease_transmission_rate::Float64=0.1,
  disease_immunity_length::Int=32,
  disease_infection_probability::Float64=0.1,
  disease_recovery_probability::Float64=0.1,
  disease_mortality_probability::Float64=0.1,
  disease_mutation_probability::Float64=0.1,
  enable_credit::Bool=false,
  interest_rate::Float64=0.10,
  duration::Int=10,
  child_amount::Int=25,
  # LLM-specific
  use_llm_decisions::Bool=true,
  llm_api_key::AbstractString=get(ENV, "OPENAI_API_KEY", ""),
  llm_model::String=get(ENV, "LLM_MODEL", "gpt-4.1-nano"),
  llm_temperature::Float64=0.0,
  llm_max_tokens::Int=1000,
)
  # == Environment setup (same as core) ==
  _sugar_cap_int = sugar_caps(dims, sugar_peaks, max_sugar, 6)
  _sugar_cap = Float64.(_sugar_cap_int)
  _sugar_values = deepcopy(_sugar_cap)
  _pollution = fill(0.0, dims)

  space = GridSpaceSingle(dims, metric=gridspace_metric)

  properties = Dict(
    :growth_rate => growth_rate,
    :N => N,
    :w0_dist => w0_dist,
    :metabolic_rate_dist => metabolic_rate_dist,
    :vision_dist => vision_dist,
    :max_age_dist => max_age_dist,
    :sugar_values => _sugar_values,
    :sugar_capacities => _sugar_cap,
    :max_sugar => max_sugar,
    :deaths_starvation => 0,
    :deaths_age => 0,
    :total_lifespan_starvation => 0,
    :total_lifespan_age => 0,
    :births => 0,
    :reproduction_counts_history => Vector{Dict{Int,Int}}(),
    :season_duration => season_duration,
    :winter_growth_divisor => winter_growth_divisor,
    :is_summer_top => true,
    :current_season_steps => 0,
    :enable_seasonality => enable_seasonality,
    :enable_pollution => enable_pollution,
    :pollution => _pollution,
    :production_rate => pollution_production_rate,
    :consumption_rate => pollution_consumption_rate,
    :pollution_diffusion_interval => pollution_diffusion_interval,
    :current_pollution_diffusion_steps => 0,
    :enable_reproduction => enable_reproduction,
    :initial_child_sugar => initial_child_sugar,
    :fertility_age_range => fertility_age_range,
    :male_fertility_start => male_fertility_start,
    :male_fertility_end => male_fertility_end,
    :female_fertility_start => female_fertility_start,
    :female_fertility_end => female_fertility_end,
    :total_inheritances => 0,
    :total_inheritance_value => 0.0,
    :generational_wealth_transferred => 0.0,
    :enable_culture => enable_culture,
    :culture_tag_length => culture_tag_length,
    :culture_copy_prob => culture_copy_prob,
    :enable_combat => enable_combat,
    :combat_limit => combat_limit,
    :combat_kills => 0,
    :combat_sugar_stolen => 0.0,
    :agents_moved_combat => Set{Int}(),
    :enable_disease => enable_disease,
    :disease_transmission_rate => disease_transmission_rate,
    :disease_immunity_length => disease_immunity_length,
    :disease_infection_probability => disease_infection_probability,
    :disease_recovery_probability => disease_recovery_probability,
    :disease_mortality_probability => disease_mortality_probability,
    :disease_mutation_probability => disease_mutation_probability,
    :enable_credit => enable_credit,
    :interest_rate => interest_rate,
    :duration => duration,
    :child_amount => child_amount,
    # ------- LLM specifics -------
    :use_llm_decisions => use_llm_decisions,
    :llm_decisions => Dict{Int,LLMDecision}(),
    :llm_api_key => llm_api_key,
    :llm_model => llm_model,
    :llm_temperature => llm_temperature,
    :llm_max_tokens => llm_max_tokens,
  )

  model = StandardABM(
    SugarscapeAgent,
    space;
    (agent_step!)=_agent_step_llm!,
    (model_step!)=_model_step_llm!,
    scheduler=Schedulers.Randomly(),
    properties=properties,
    rng=MersenneTwister(seed),
  )

  # --- Agent initialisation (same as core) ---
  for _ in 1:N
    vision = rand(abmrng(model), vision_dist[1]:vision_dist[2])
    metabolism = rand(abmrng(model), metabolic_rate_dist[1]:metabolic_rate_dist[2])
    age = 0
    max_age = rand(abmrng(model), max_age_dist[1]:max_age_dist[2])
    sugar = Float64(rand(abmrng(model), w0_dist[1]:w0_dist[2]))
    sex = rand(abmrng(model), (:male, :female))
    has_reproduced = false
    children = Int[]
    total_inheritance_received = 0.0
    culture = initialize_culture(culture_tag_length, model)

    pos = random_empty(model)
    loans_given = Dict{Int,Vector{Sugarscape.Loan}}()
    loans_owed = Dict{Int,Vector{Sugarscape.Loan}}()
    diseases = BitVector[]
    immunity = falses(model.disease_immunity_length)
    
    add_agent!(pos, SugarscapeAgent, model, vision, metabolism, sugar, age, max_age,
      sex, has_reproduced, sugar, children, total_inheritance_received,
      culture, loans_given, loans_owed, diseases, immunity)
  end


  return model
end

# ----------------------------------------------------------------------------
# Model-level step (inherits from core but adds LLM decision caching)          |
# ----------------------------------------------------------------------------
function _model_step_llm!(model)
  # Individual LLM requests are handled inside each agent step

  # Delegate remaining logic to shared rule implementation
  # (copy from core but keep identical — duplication avoided for clarity)

  if model.enable_seasonality
    seasonal_growback!(model)
    model.current_season_steps += 1
    if model.current_season_steps >= model.season_duration
      model.is_summer_top = !model.is_summer_top
      model.current_season_steps = 0
    end
  else
    growback!(model)
  end

  model.agents_moved_combat = Set{Int}()
  model.enable_combat && combat!(model)

  if model.enable_pollution
    model.current_pollution_diffusion_steps += 1
    if model.current_pollution_diffusion_steps >= model.pollution_diffusion_interval
      pollution_diffusion!(model)
      model.current_pollution_diffusion_steps = 0
    end
  end

  model.enable_culture && culture_spread!(model)

  if model.enable_credit
    tick = abmtime(model)
    pay_loans!(model, tick)
    make_loans!(model, tick)
  end

  if model.enable_disease
    disease_transmission!(model)
    immune_response!(model)
  end

  return
end

# ----------------------------------------------------------------------------
# Agent-level step                                           |
# ----------------------------------------------------------------------------
function _agent_step_llm!(agent, model)
  # ---------------------------------------------------------
  # Movement Phase
  # Either combat or movement
  # Each require separate decisions with different response formats
  # Can do each decision request and action in a separate if else block since they are
  # mutually exclusive
  # ---------------------------------------------------------

  if model.enable_combat
    # TO BE IMPLEMENTED
    # combat_context
    # get_combat_decision (context, response format)
    # combat_action
  else
    # movement_context
    movement_context = build_agent_movement_context(agent, model)
    movement_decision = SugarscapeLLM.get_movement_decision(movement_context, model)
    # get_movement_decision (context, response format)
    # movement_action
    llm_move!(agent, model, movement_decision.move_coords)
  end


  # ---------------------------------------------------------
  # Post-movement death / reproduction phase
  # Inheritance -> Death -> Reproduction
  # Inheritance only happens with reproduction
  # Death without reproduction leads to replacement and does not require a decision
  # 2 branches:
  # 1. Repro enabled: Inheritance -> Death -> Reproduction
  # 2. Repro disabled: Death -> Replacement
  # ---------------------------------------------------------

  if model.enable_reproduction
    if agent.sugar ≤ 0 || agent.age ≥ agent.max_age
      cause = agent.sugar ≤ 0 ? :starvation : :age
      death!(agent, model, cause)
    end
    reproduction!(agent, model)

    # reproduction_action
  else
    Sugarscape.death_replacement!(agent, model)
  end


  # ---------------------------------------------------------
  # Culture phase
  # TO BE IMPLEMENTED
  # ---------------------------------------------------------
  if model.enable_culture
    culture_spread!(agent, model)
  end



  # ---------------------------------------------------------
  # Credit phase
  # ---------------------------------------------------------
  if model.enable_credit
    # LLM or rule-based credit action
    credit!(agent, model)
  end

end

# -----------------------------------------------------------------------------
# Generic helpers for combat movement etc are imported from shared.jl          |
# -----------------------------------------------------------------------------
