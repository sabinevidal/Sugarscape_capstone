"""
Inheritance (I) Rule Implementation for Sugarscape

When an agent dies, its wealth is equally divided among all its living children.
Only applies when reproduction is enabled.
"""

"""
    distribute_inheritance(agent, model)

Distribute the deceased agent's sugar equally among living children.
Only positive sugar is inherited (debts are ignored).
Uses floor division for inheritance shares.
"""
function distribute_inheritance(agent, model)
  # Only distribute positive wealth
  if agent.sugar <= 0
    return
  end

  # Find living children (filter out dead agent IDs)
  # Using `hasid` from Agents.jl avoids direct access to internal fields like `model.agents`,
  # which are intentionally hidden by Agents.jl's custom `getproperty` overload.
  living_children = filter(child_id -> hasid(model, child_id), agent.children)

  if !isempty(living_children)
    # Use floor division as specified
    inheritance_per_child = floor(Int, agent.sugar / length(living_children))

    # Track inheritance metrics
    model.total_inheritances += length(living_children)
    model.total_inheritance_value += inheritance_per_child * length(living_children)

    for child_id in living_children
      child_agent = model[child_id]
      child_agent.sugar += inheritance_per_child

      # Track individual inheritance received
      child_agent.total_inheritance_received += inheritance_per_child
    end

    # Track generational wealth transfer
    model.generational_wealth_transferred += inheritance_per_child * length(living_children)
  end

  # If no living children, wealth is lost from the system
end

"""
    get_inheritance_metrics(model)

Return current inheritance metrics for analysis.
"""
function get_inheritance_metrics(model)
  avg_inheritance = model.total_inheritances > 0 ?
                    model.total_inheritance_value / model.total_inheritances : 0.0

  return (
    total_inheritances=model.total_inheritances,
    total_inheritance_value=model.total_inheritance_value,
    average_inheritance_per_recipient=avg_inheritance,
    generational_wealth_transferred=model.generational_wealth_transferred,
    inheritance_concentration_ratio=calculate_inheritance_concentration(model)
  )
end

"""
    calculate_inheritance_concentration(model)

Calculate the ratio of agents who have received inheritance vs total agents.
This helps measure wealth concentration through inheritance.
"""
function calculate_inheritance_concentration(model)
  if nagents(model) == 0
    return 0.0
  end

  agents_with_inheritance = count(a -> a.total_inheritance_received > 0, allagents(model))
  return agents_with_inheritance / nagents(model)
end
