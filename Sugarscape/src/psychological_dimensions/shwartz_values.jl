using Agents

@agent struct ShwartzValuesSugarscapeAgent(SugarscapeAgent)
  values::NamedTuple{
    (:self_direction, :stimulation, :hedonism, :achievement, :power,
      :security, :conformity, :tradition, :benevolence, :universalism),
    NTuple{10,Float64}
  }
end
