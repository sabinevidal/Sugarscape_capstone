module SchwartzValues

using Agents

# Include the core agent types
include("../../core/agents.jl")
include("schwartz_values_prompts.jl")

export SchwartzValuesSugarscapeAgent

@agent struct SchwartzValuesSugarscapeAgent(SugarscapeAgent)
  schwartz_values::NamedTuple{
    (:self_direction, :stimulation, :hedonism, :achievement, :power,
      :security, :conformity, :tradition, :benevolence, :universalism),
    NTuple{10,Float64}
  }
end

end # module SchwartzValues
