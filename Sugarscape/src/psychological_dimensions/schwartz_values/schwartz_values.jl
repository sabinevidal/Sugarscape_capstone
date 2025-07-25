module SchwartzValues

using Agents
using Distributions
using ..SchwartzValuesProcessor
using ..Sugarscape

# Import necessary types from parent Sugarscape module
import ..Sugarscape: SugarscapeAgent, Loan

include("schwartz_values_contexts.jl")
include("schwartz_values_prompts.jl")

export SchwartzValuesSugarscapeAgent, prepare_schwartz_values, create_schwartz_values_agent!, sugarscape_llm_schwartz, build_schwartz_values_movement_context, build_schwartz_values_reproduction_context

@agent struct SchwartzValuesSugarscapeAgent(SugarscapeAgent)
  schwartz_values::NamedTuple{
    (:self_direction, :stimulation, :hedonism, :achievement, :power,
      :security, :conformity, :tradition, :benevolence, :universalism),
    NTuple{10,Float32}
  }
end

"""
    prepare_schwartz_values(schwartz_values_path::AbstractString, N::Int, mvn_dist::Union{MvNormal,Nothing}=nothing)

Prepare Schwartz values samples for N agents. Returns a tuple (traits_samples, mvn_distribution).
If mvn_dist is provided, uses that distribution; otherwise fits one from the data.
"""
function prepare_schwartz_values(schwartz_values_path::AbstractString, N::Int, mvn_dist::Union{MvNormal,Nothing}=nothing)
  mvn = if mvn_dist === nothing
    # Only load data if we need to fit a new distribution
    values_df = SchwartzValuesProcessor.load_processed_schwartz_values(schwartz_values_path)
    SchwartzValuesProcessor.fit_mvn_distribution(values_df)
  else
    mvn_dist
  end

  values_samples = SchwartzValuesProcessor.sample_agents(mvn, N)
  return (values_samples, mvn)
end

"""
    create_schwartz_values_agent!(model, pos, vision, metabolism, sugar, age, max_age, sex, has_reproduced, has_spread_culture, has_accepted_culture,
                          initial_sugar, children, total_inheritance_received, culture,
                          loans_given, loans_owed, diseases, immunity, values_row)

Create and add a SchwartzValuesSugarscapeAgent to the model with the given parameters and traits.
"""
function create_schwartz_values_agent!(model, pos, vision, metabolism, sugar, age, max_age, sex, has_reproduced, has_spread_culture, has_accepted_culture,
  initial_sugar, children, total_inheritance_received, culture,
  loans_given, loans_owed, diseases, immunity, last_partner_id, last_credit_partner, last_combat_partner, chose_not_to_attack, chose_not_to_borrow, chose_not_to_lend, chose_not_to_reproduce, chose_not_to_spread_culture, values_row)
  schwartz_values = (
    self_direction=values_row.self_direction,
    stimulation=values_row.stimulation,
    hedonism=values_row.hedonism,
    achievement=values_row.achievement,
    power=values_row.power,
    security=values_row.security,
    conformity=values_row.conformity,
    tradition=values_row.tradition,
    benevolence=values_row.benevolence,
    universalism=values_row.universalism,
  )

  add_agent!(pos, SchwartzValuesSugarscapeAgent, model, vision, metabolism, sugar, age, max_age, sex, has_reproduced, has_spread_culture, has_accepted_culture,
    initial_sugar, children, total_inheritance_received, culture,
    loans_given, loans_owed, diseases, immunity, last_partner_id, last_credit_partner, last_combat_partner,
    chose_not_to_attack, chose_not_to_borrow, chose_not_to_lend, chose_not_to_reproduce, chose_not_to_spread_culture, schwartz_values)

  # for agent in allagents(model)
  #   println("Agent $(agent.id): $(agent.traits)")
  # end
end

"""
    sugarscape_llm_schwartz(; kwargs...) -> StandardABM

Convenience constructor that creates a Sugarscape model with Schwartz values enabled,
LLM decisions enabled, and proper MVN distribution handling. All other kwargs are
forwarded to `sugarscape`.
"""
function sugarscape_llm_schwartz(;
  mvn_dist::Union{MvNormal,Nothing}=nothing,
  llm_api_key::AbstractString=get(ENV, "OPENAI_API_KEY", ""),
  schwartz_values_path::AbstractString="data/processed/schwartz-values-processed.csv",
  kwargs...)

  # Always enable Schwartz values and LLM decisions for this constructor
  Sugarscape.sugarscape(;
    schwartz_values_mvn_dist=mvn_dist,
    use_schwartz_values=true,
    use_llm_decisions=true,
    llm_api_key=llm_api_key,
    schwartz_values_path=schwartz_values_path,
    kwargs...)
end

end # module SchwartzValues
