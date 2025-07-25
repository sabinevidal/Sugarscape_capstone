module BigFive

using Agents
using Distributions
using ..BigFiveProcessor
using ..Sugarscape

# Import necessary types from parent Sugarscape module
import ..Sugarscape: SugarscapeAgent, Loan

include("big_five_prompts.jl")
include("big_five_contexts.jl")

export BigFiveSugarscapeAgent, prepare_big_five_traits, create_big_five_agent!, sugarscape_llm_bigfive, build_big_five_movement_context, build_big_five_combat_context, build_big_five_credit_lender_context, build_big_five_culture_context, build_big_five_credit_borrower_context, build_big_five_reproduction_context

@agent struct BigFiveSugarscapeAgent(SugarscapeAgent)
  traits::NamedTuple{
    (:openness, :conscientiousness, :extraversion, :agreeableness, :neuroticism),
    NTuple{5,Float64}
  }
end

"""
    prepare_big_five_traits(big_five_traits_path::AbstractString, N::Int, mvn_dist::Union{MvNormal,Nothing}=nothing)

Prepare Big Five trait samples for N agents. Returns a tuple (traits_samples, mvn_distribution).
If mvn_dist is provided, uses that distribution; otherwise fits one from the data.
"""
function prepare_big_five_traits(big_five_traits_path::AbstractString, N::Int, mvn_dist::Union{MvNormal,Nothing}=nothing)
  mvn = if mvn_dist === nothing
    # Only load data if we need to fit a new distribution
    traits_df = BigFiveProcessor.load_processed_bigfive(big_five_traits_path)
    BigFiveProcessor.fit_mvn_distribution(traits_df)
  else
    mvn_dist
  end

  traits_samples = BigFiveProcessor.sample_agents(mvn, N)
  return (traits_samples, mvn)
end

"""
    create_big_five_agent!(model, pos, vision, metabolism, sugar, age, max_age, sex, has_reproduced,
                          initial_sugar, children, total_inheritance_received, culture,
                          loans_given, loans_owed, diseases, immunity, traits_row)

Create and add a BigFiveSugarscapeAgent to the model with the given parameters and traits.
"""
function create_big_five_agent!(model, pos, vision, metabolism, sugar, age, max_age, sex, has_reproduced, has_spread_culture, has_accepted_culture,
  initial_sugar, children, total_inheritance_received, culture,
  loans_given, loans_owed, diseases, immunity, last_partner_id, last_credit_partner, chose_not_to_attack, chose_not_to_borrow, chose_not_to_lend, chose_not_to_reproduce, chose_not_to_spread_culture, traits_row)
  traits = (
    openness=traits_row.Openness,
    conscientiousness=traits_row.Conscientiousness,
    extraversion=traits_row.Extraversion,
    agreeableness=traits_row.Agreeableness,
    neuroticism=traits_row.Neuroticism,
  )

  add_agent!(pos, BigFiveSugarscapeAgent, model, vision, metabolism, sugar, age, max_age, sex, has_reproduced, has_spread_culture, has_accepted_culture,
    initial_sugar, children, total_inheritance_received, culture,
    loans_given, loans_owed, diseases, immunity, last_partner_id, last_credit_partner,
    chose_not_to_attack, chose_not_to_borrow, chose_not_to_lend, chose_not_to_reproduce, chose_not_to_spread_culture, traits)

  # for agent in allagents(model)
  #   println("Agent $(agent.id): $(agent.traits)")
  # end
end


"""
    sugarscape_llm_bigfive(; kwargs...) -> StandardABM

Convenience constructor that creates a Sugarscape model with Big Five traits enabled,
LLM decisions enabled, and proper MVN distribution handling. All other kwargs are
forwarded to `sugarscape`.
"""
function sugarscape_llm_bigfive(;
  mvn_dist::Union{MvNormal,Nothing}=nothing,
  llm_api_key::AbstractString=get(ENV, "OPENAI_API_KEY", ""),
  big_five_traits_path::AbstractString="data/processed/big5-traits-processed.csv",
  kwargs...)

  # Always enable Big Five and LLM decisions for this constructor
  Sugarscape.sugarscape(;
    big_five_mvn_dist=mvn_dist,
    use_big_five=true,
    use_llm_decisions=true,
    llm_api_key=llm_api_key,
    big_five_traits_path=big_five_traits_path,
    kwargs...)
end

end # module BigFive
