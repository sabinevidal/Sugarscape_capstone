using Distributions

"""
    sugarscape(; kwargs...) -> StandardABM

Create a Sugarscape agent-based model that follows the standard rules without
any LLM involvement.  The keyword arguments mirror the original `sugarscape`
constructor, except that all LLM-specific parameters are omitted.
"""
function sugarscape(;
  seed=42,
  # environment
  dims=(50, 50),
  dia=5,
  gridspace_metric::Symbol=:manhattan,
  sugar_peaks=((15, 40), (35, 10)),
  growth_rate=1, enable_seasonality::Bool=false,
  season_duration::Int=20,
  winter_growth_divisor::Int=4,
  enable_pollution::Bool=false,
  pollution_production_rate::Float64=1.0,
  pollution_consumption_rate::Float64=1.0,
  pollution_diffusion_interval::Int=10,

  # agents
  N=100,
  initial_sugar_dist=(5, 25),
  metabolic_rate_dist=(1, 4),
  vision_dist=(1, 6),
  max_age_dist=(60, 100),
  max_sugar=4,

  # reproduction
  enable_reproduction::Bool=false,
  fertility_age_range::Tuple{Int,Int}=(18, 50),
  male_fertility_start::Int=12,
  male_fertility_end::Int=50,
  female_fertility_start::Int=12,
  female_fertility_end::Int=40,
  initial_child_sugar::Int=6,

  # culture
  enable_culture::Bool=false,
  culture_tag_length::Int=11,
  culture_copy_prob::Float64=1 / 11,

  # combat
  enable_combat::Bool=false,
  combat_limit::Int=50,

  # disease
  enable_disease::Bool=false,
  disease_transmission_rate::Float64=0.1,
  disease_immunity_length::Int=32,
  disease_infection_probability::Float64=0.1,
  disease_recovery_probability::Float64=0.1,
  disease_mortality_probability::Float64=0.1,
  disease_mutation_probability::Float64=0.1,

  # credit
  enable_credit::Bool=false,
  interest_rate::Float64=0.10,
  duration::Int=10,

  # LLM
  use_llm_decisions::Bool=false,
  llm_api_key::AbstractString=get(ENV, "OPENAI_API_KEY", ""),
  llm_model::String=get(ENV, "LLM_MODEL", "gpt-4.1-mini"),
  llm_temperature::Float64=0.0,
  llm_max_tokens::Int=1000,
  llm_metadata::AbstractDict=Dict{String,Any}(),
  # llm_log_dir::AbstractString="data/logs",

  # Big Five
  use_big_five::Bool=false,
  big_five_traits_path::AbstractString="data/processed/big5-traits_raw.csv",
  big_five_mvn_dist::Union{MvNormal,Nothing}=nothing,

  # Schwartz Values
  use_schwartz_values::Bool=false,
  schwartz_values_path::AbstractString="data/processed/schwartz-values-data-raw.csv",
  schwartz_values_mvn_dist::Union{MvNormal,Nothing}=nothing,
)
  # -------------------------------------------------------------------------
  # Grid initialisation
  # -------------------------------------------------------------------------
  _sugar_cap_int = sugar_caps(dims, sugar_peaks, max_sugar, 4)
  _sugar_cap = Float64.(_sugar_cap_int)
  _sugar_values = deepcopy(_sugar_cap)
  _pollution = fill(0.0, dims)

  space = GridSpaceSingle(dims, metric=gridspace_metric)

  properties = Dict(
    # Environment / growback
    :growth_rate => growth_rate,
    :dia => dia,
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

    # Population & basic stats
    :N => N,
    :initial_sugar_dist => initial_sugar_dist,
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
    :reproduction_counts_step => Dict{Int,Int}(),

    # Reproduction / inheritance
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

    # Culture
    :enable_culture => enable_culture,
    :culture_tag_length => culture_tag_length,
    :culture_copy_prob => culture_copy_prob,

    # Combat
    :enable_combat => enable_combat,
    :combat_limit => combat_limit,
    :combat_kills => 0,
    :combat_sugar_stolen => 0.0,
    :agents_moved_combat => Set{Int}(),

    # Disease
    :enable_disease => enable_disease,
    :disease_transmission_rate => disease_transmission_rate,
    :disease_immunity_length => disease_immunity_length,
    :disease_infection_probability => disease_infection_probability,
    :disease_recovery_probability => disease_recovery_probability,
    :disease_mortality_probability => disease_mortality_probability,
    :disease_mutation_probability => disease_mutation_probability,

    # Credit
    :enable_credit => enable_credit,
    :interest_rate => interest_rate,
    :duration => duration,

    # LLM
    :use_llm_decisions => use_llm_decisions,
    :llm_decisions => Dict{Int,Any}(),
    :llm_api_key => llm_api_key,
    :llm_model => llm_model,
    :llm_temperature => llm_temperature,
    :llm_max_tokens => llm_max_tokens,
    :llm_metadata => llm_metadata,
    # :llm_log_dir => llm_log_dir,

    # Big Five MvNormal for runtime sampling
    :use_big_five => use_big_five,
    :big_five_traits_path => big_five_traits_path,
    :big_five_mvn_dist => nothing,

    # Schwartz Values
    :use_schwartz_values => use_schwartz_values,
    :schwartz_values_path => schwartz_values_path,
    :schwartz_values_mvn_dist => nothing,

    # Action logging
    :last_actions => String[],
    :last_trait_interactions => Tuple{Int,Int}[],
  )


  # Select agent type based on flags
  agent_type = if use_big_five
    BigFiveSugarscapeAgent
  elseif use_schwartz_values
    SchwartzValuesSugarscapeAgent
  else
    SugarscapeAgent
  end

  model = StandardABM(
    agent_type,
    space;
    (agent_step!)=use_llm_decisions ? _agent_step_llm! : _agent_step!,
    (model_step!)=use_llm_decisions ? _model_step_llm! : _model_step!,
    scheduler=Schedulers.Randomly(),
    properties=properties,
    rng=MersenneTwister(seed),
  )

  # -----------------------------------------------------------------------
  # Initialise population
  # -----------------------------------------------------------------------

  # Prepare Big Five traits if needed
  traits_samples, big_five_mvn = if use_big_five
    prepare_big_five_traits(big_five_traits_path, N, big_five_mvn_dist)
  else
    (nothing, nothing)
  end

  # Store MVN distribution in model for runtime sampling during reproduction
  if use_big_five
    model.big_five_mvn_dist = big_five_mvn
  end

  # Prepare Schwartz values if needed
  schwartz_values_samples, schwartz_values_mvn = if use_schwartz_values
    prepare_schwartz_values(schwartz_values_path, N, schwartz_values_mvn_dist)
  else
    (nothing, nothing)
  end

  # Store MVN distribution in model for runtime sampling during reproduction
  if use_schwartz_values
    model.schwartz_values_mvn_dist = schwartz_values_mvn
  end

  for i in 1:N
    vision = rand(abmrng(model), vision_dist[1]:vision_dist[2])
    metabolism = rand(abmrng(model), metabolic_rate_dist[1]:metabolic_rate_dist[2])
    age = 0
    max_age = rand(abmrng(model), max_age_dist[1]:max_age_dist[2])
    sugar = Float64(rand(abmrng(model), initial_sugar_dist[1]:initial_sugar_dist[2]))
    sex = rand(abmrng(model), (:male, :female))
    has_reproduced = false
    children = Int[]
    total_inheritance_received = 0.0
    culture = initialize_culture(culture_tag_length, model)

    pos = random_empty(model)
    # Fix argument order and types to match SugarscapeAgent constructor
    # The expected signature is:
    # SugarscapeAgent(id, pos, vision, metabolism, sugar, age, max_age, sex, has_reproduced, initial_sugar, children, total_inheritance_received, culture, loans_given, loans_owed, diseases, immunity)
    loans_given = Dict{Int,Vector{Sugarscape.Loan}}()
    loans_owed = Dict{Int,Vector{Sugarscape.Loan}}()
    diseases = BitVector[]
    immunity = falses(model.disease_immunity_length)
    last_partner_id = Int[]
    last_credit_partner = Int[]

    # Create agent arguments for add_agent! (pos, AgentType, model, ...args)
    agent_args = (
      vision, metabolism, sugar, age, max_age, sex, has_reproduced,
      sugar, children, total_inheritance_received, BitVector(culture),
      loans_given, loans_owed, diseases, immunity, last_partner_id, last_credit_partner
    )

    if use_big_five
      traits_row = traits_samples[i, :]
      create_big_five_agent!(model, pos, agent_args..., traits_row)
    elseif use_schwartz_values
      values_row = schwartz_values_samples[i, :]
      create_schwartz_values_agent!(model, pos, agent_args..., values_row)
    else
      add_agent!(pos, SugarscapeAgent, model, agent_args...)
    end
  end

  return model
end
