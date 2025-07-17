using Agents

@agent struct BigFiveSugarscapeAgent(SugarscapeAgent)
  traits::NamedTuple{
    (:openness, :conscientiousness, :extraversion, :agreeableness, :neuroticism),
    NTuple{5,Float64}
  }
end


"""
    sugarscape_llm_bigfive(; kwargs...) -> StandardABM

Convenience constructor that pre-loads a Big-Five mvn distribution and expects
an LLM API key.  All other kwargs are forwarded to `sugarscape`.
"""
function sugarscape_llm_bigfive(;
  mvn_dist::MvNormal,
  llm_api_key::AbstractString,
  kwargs...)
  sugarscape(; mvn_dist, use_big_five=true,
    use_llm_decisions=true, llm_api_key, kwargs...)
end
