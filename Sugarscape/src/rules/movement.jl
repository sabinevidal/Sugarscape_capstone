"""
Movement (M) Rule Implementation

"""

"""
    build_agent_movement_context(agent, model) -> Dict
Collect a lightweight JSON-serialisable summary of the local state that the LLM
can use to decide on the agent's next actions.  The schema is intentionally kept
stable so tests that rely on it do not break when the runtime model evolves.
"""
function build_agent_movement_context(agent, model)
  # Visible lattice positions with sugar (or welfare when pollution enabled)
  visible_positions = Vector{Any}()

  # Use the same nearby_positions logic as movement! to ensure consistency
  for (pos, sugar_value, distance) in Sugarscape.evaluate_nearby_positions(agent, model)
    push!(visible_positions, Dict(
      "position" => pos,
      "sugar_value" => sugar_value,
      "distance" => distance,
    ))
  end

  # Immediate neighbours (Von Neumann radius 1)
  neighbours = Vector{Any}()
  for nb in nearby_agents(agent, model, 1)
    push!(neighbours, Dict(
      "id" => nb.id,
      "sugar" => nb.sugar,
      "age" => nb.age,
      "sex" => nb.sex,
    ))
  end

  # Big Five personality traits (if present)
  big_five_traits = hasproperty(agent, :traits) ? Dict(string(k)=>v for (k,v) in pairs(agent.traits)) : nothing

  return Dict(
    "agent_id" => agent.id,
    "position" => agent.pos,
    "sugar" => agent.sugar,
    "age" => agent.age,
    "metabolism" => agent.metabolism,
    "vision" => agent.vision,
    "sex" => agent.sex,
    "big_five_traits" => big_five_traits,
    "visible_positions" => visible_positions,
    # Future use could be allowing the agent to choose where to move based on what neighbours are nearby and what interaction is possible
    "neighbours" => neighbours,
    "enable_combat" => model.enable_combat,
    "enable_reproduction" => model.enable_reproduction,
    "enable_credit" => model.enable_credit,
  )
end
