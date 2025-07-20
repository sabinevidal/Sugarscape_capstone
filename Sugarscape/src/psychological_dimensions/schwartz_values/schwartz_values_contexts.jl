"""
Movement (M) Rule Implementation

"""

"""
    build_schwartz_values_movement_context(agent, model) -> Dict
Collect a lightweight JSON-serialisable summary of the local state that the LLM
can use to decide on the agent's next actions.  The schema is intentionally kept
stable so tests that rely on it do not break when the runtime model evolves.
"""
function build_schwartz_values_movement_context(agent, model)
  # Visible lattice positions with sugar (or welfare when pollution enabled)
  visible_positions = Vector{Any}()

  # Use the same nearby_positions logic as movement! to ensure consistency
  for (pos, sugar_value, distance) in Sugarscape.evaluate_nearby_positions(agent, model)
    push!(visible_positions, Dict(
      "position" => pos,
      "sugar_value" => round(sugar_value, digits=2),
      "distance" => round(distance, digits=2),
    ))
  end

  # Neighbours in vision
  neighbours = Vector{Any}()
  occupied_positions = Vector{Any}()
  for nb in nearby_agents(agent, model, agent.vision)
    push!(neighbours, Dict(
      "id" => nb.id,
      "sugar" => round(nb.sugar, digits=2),
      "age" => nb.age,
      "sex" => nb.sex,
      "position" => nb.pos,
      "culture" => nb.culture,
    ))
    push!(occupied_positions, Dict(
      "position" => nb.pos,
    ))
  end

  schwartz_values = hasproperty(agent, :schwartz_values) ? Dict(string(k) => v for (k, v) in pairs(agent.schwartz_values)) : nothing

  return Dict(
    "agent_id" => agent.id,
    "position" => agent.pos,
    "sugar" => round(agent.sugar, digits=2),
    "age" => agent.age,
    "metabolism" => agent.metabolism,
    "vision" => agent.vision,
    "sex" => agent.sex,
    "schwartz_values" => schwartz_values,
    "visible_positions" => visible_positions,
    "culture" => agent.culture,
    # Future use could be allowing the agent to choose where to move based on what neighbours are nearby and what interaction is possible
    "neighbours" => neighbours,
    "occupied_positions" => occupied_positions,
    "enable_combat" => model.enable_combat,
    "enable_reproduction" => model.enable_reproduction,
    "enable_credit" => model.enable_credit,
  )
end

"""
Reproduction Rule:
"""
function build_schwartz_values_reproduction_context(agent, model, eligible_partners, max_partners)

  eligible_partners_context = Vector{Dict{String,Any}}()
  for ep in eligible_partners
    if is_fertile(ep, model) && agent.sex != ep.sex
      neighbour_schwartz_values = hasproperty(ep, :schwartz_values) ? Dict(string(k) => v for (k, v) in pairs(ep.schwartz_values)) : nothing
      push!(eligible_partners_context, Dict{String,Any}(
        "id" => ep.id,
        "sugar" => ep.sugar,
        "age" => ep.age,
        "sex" => ep.sex,
        "culture" => ep.culture,
        "schwartz_values" => neighbour_schwartz_values,
        "empty_nearby_positions_for_partner" => collect(empty_nearby_positions(ep, model)),
      ))
    end
  end

  # Schwartz values (if present)
  schwartz_values = hasproperty(agent, :schwartz_values) ? Dict(string(k) => v for (k, v) in pairs(agent.schwartz_values)) : nothing

  reproduction_context = Dict{String,Any}(
    "agent_id" => agent.id,
    "position" => agent.pos,
    "sugar" => agent.sugar,
    "min_sugar_for_reproduction" => agent.initial_sugar,
    "age" => agent.age,
    "metabolism" => agent.metabolism,
    "vision" => agent.vision,
    "sex" => agent.sex,
    "schwartz_values" => schwartz_values,
    "eligible_partners" => eligible_partners_context,
    "max_partners" => max_partners,
    # doesn't need to know values of empty_nearby_positions
    "empty_nearby_positions" => collect(empty_nearby_positions(agent, model)),
  )

  return reproduction_context
end


"""
    build_schwartz_values_culture_context(agent, model, neighbors)

Build a schwartz values culture context for the agent, including their own culture and the cultures of their neighbors.
"""
function build_schwartz_values_culture_context(agent, model, neighbors)

  schwartz_values = hasproperty(agent, :schwartz_values) ? Dict(string(k) => v for (k, v) in pairs(agent.schwartz_values)) : nothing

  culture_context = Dict(
    "agent_id" => agent.id,
    "culture" => agent.culture,
    "schwartz_values" => schwartz_values,
    "neighbors" => []
  )


  for neighbor in neighbors
    neighbour_schwartz_values = hasproperty(neighbor, :schwartz_values) ? Dict(string(k) => v for (k, v) in pairs(neighbor.schwartz_values)) : nothing
    push!(culture_context["neighbors"], Dict(
      "agent_id" => neighbor.id,
      "culture" => neighbor.culture,
      "schwartz_values" => neighbour_schwartz_values,
    ))
  end

  return culture_context
end


"""
build_schwartz_values_credit_lender_context(agent, model, neighbours, amount_available) -> Dict
"""
function build_schwartz_values_credit_lender_context(agent, model, neighbours, amount_available)
  # Collect neighbours if iterable, else wrap single agent in array
  if neighbours isa Base.Generator || neighbours isa AbstractVector
    nbrs = collect(neighbours)
  else
    nbrs = [neighbours]
  end

  schwartz_values = hasproperty(agent, :schwartz_values) ? Dict(string(k) => v for (k, v) in pairs(agent.schwartz_values)) : nothing

  lender_context = Dict(
    "agent_id" => agent.id,
    "sugar" => agent.sugar,
    "age" => agent.age,
    "schwartz_values" => schwartz_values,
    "can_lend" => true,
    "amount_available" => amount_available,
    "eligible_borrowers" => [],
    "culture" => agent.culture,
  )

  for neighbour in nbrs
    neighbour_schwartz_values = hasproperty(neighbour, :schwartz_values) ? Dict(string(k) => v for (k, v) in pairs(neighbour.schwartz_values)) : nothing
    push!(lender_context["eligible_borrowers"], Dict(
      "agent_id" => neighbour.id,
      "sugar" => neighbour.sugar,
      "age" => neighbour.age,
      "schwartz_values" => neighbour_schwartz_values,
      "culture" => neighbour.culture,
      "will_borrow" => Sugarscape.will_borrow(neighbour, model).will_borrow,
      "amount_required" => Sugarscape.will_borrow(neighbour, model).amount_required
    ))
  end

  return lender_context
end

"""
build_schwartz_values_credit_borrower_context(agent, model, neighbours, amount_required) -> Dict
"""
function build_schwartz_values_credit_borrower_context(agent, model, neighbours, amount_required)
  # Collect neighbours if iterable, else wrap single agent in array
  if neighbours isa Base.Generator || neighbours isa AbstractVector
    nbrs = collect(neighbours)
  else
    nbrs = [neighbours]
  end

  schwartz_values = hasproperty(agent, :schwartz_values) ? Dict(string(k) => v for (k, v) in pairs(agent.schwartz_values)) : nothing

  borrower_context = Dict(
    "agent_id" => agent.id,
    "sugar" => agent.sugar,
    "age" => agent.age,
    "schwartz_values" => schwartz_values,
    "will_borrow" => Sugarscape.will_borrow(agent, model).will_borrow,
    "amount_to_borrow" => amount_required,
    "reproduction_threshold" => agent.initial_sugar,
    "culture" => agent.culture,
    "eligible_lenders" => []
  )

  for neighbour in nbrs
    neighbour_schwartz_values = hasproperty(neighbour, :schwartz_values) ? Dict(string(k) => v for (k, v) in pairs(neighbour.schwartz_values)) : nothing
    push!(borrower_context["eligible_lenders"], Dict(
      "agent_id" => neighbour.id,
      "sugar" => neighbour.sugar,
      "age" => neighbour.age,
      "can_lend" => Sugarscape.can_lend(neighbour, model).can_lend,
      "max_amount" => Sugarscape.can_lend(neighbour, model).max_amount,
      "culture" => neighbour.culture,
      "schwartz_values" => neighbour_schwartz_values,
    ))
  end

  return borrower_context
end
