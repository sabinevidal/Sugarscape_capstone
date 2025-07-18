module BigFive

using Agents
using Distributions

# Include the core agent types
include("../../core/agents.jl")
include("big_five_prompts.jl")

export BigFiveSugarscapeAgent, prepare_big_five_traits, create_big_five_agent!, sugarscape_llm_bigfive

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
  traits_df = BigFiveProcessor.load_processed_bigfive(big_five_traits_path)

  mvn = if mvn_dist === nothing
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
function create_big_five_agent!(model, pos, vision, metabolism, sugar, age, max_age, sex, has_reproduced,
  initial_sugar, children, total_inheritance_received, culture,
  loans_given, loans_owed, diseases, immunity, traits_row)
  traits = (
    openness=traits_row.Openness,
    conscientiousness=traits_row.Conscientiousness,
    extraversion=traits_row.Extraversion,
    agreeableness=traits_row.Agreeableness,
    neuroticism=traits_row.Neuroticism,
  )

  add_agent!(pos, BigFiveSugarscapeAgent, model, vision, metabolism, sugar, age, max_age, sex, has_reproduced,
    initial_sugar, children, total_inheritance_received, culture,
    loans_given, loans_owed, diseases, immunity,
    traits)
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
  big_five_traits_path::AbstractString="data/processed/big5-traits_raw.csv",
  kwargs...)

  # Always enable Big Five and LLM decisions for this constructor
  sugarscape(;
    mvn_dist=mvn_dist,
    use_big_five=true,
    use_llm_decisions=true,
    llm_api_key=llm_api_key,
    big_five_traits_path=big_five_traits_path,
    kwargs...)
end

end # module BigFive
