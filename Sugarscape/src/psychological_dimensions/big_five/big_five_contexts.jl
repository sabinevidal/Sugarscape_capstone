"""
Movement (M) Rule Implementation

"""

"""
    build_big_five_movement_context(agent, model) -> Dict
Collect a lightweight JSON-serialisable summary of the local state that the LLM
can use to decide on the agent's next actions.  The schema is intentionally kept
stable so tests that rely on it do not break when the runtime model evolves.
"""
function build_big_five_movement_context(agent, model)
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

  big_five_traits = hasproperty(agent, :big_five_traits) ? Dict(string(k) => v for (k, v) in pairs(agent.big_five_traits)) : nothing

  return Dict(
    "agent_id" => agent.id,
    "position" => agent.pos,
    "sugar" => round(agent.sugar, digits=2),
    "age" => agent.age,
    "metabolism" => agent.metabolism,
    "vision" => agent.vision,
    "sex" => agent.sex,
    "big_five_traits" => big_five_traits,
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
function build_big_five_reproduction_context(agent, model, eligible_partners, max_partners)

  eligible_partners_context = Vector{Dict{String,Any}}()
  for ep in eligible_partners
    if is_fertile(ep, model) && agent.sex != ep.sex
      neighbour_big_five_traits = hasproperty(ep, :big_five_traits) ? Dict(string(k) => v for (k, v) in pairs(ep.big_five_traits)) : nothing
      push!(eligible_partners_context, Dict{String,Any}(
        "id" => ep.id,
        "sugar" => ep.sugar,
        "age" => ep.age,
        "sex" => ep.sex,
        "culture" => ep.culture,
        "big_five_traits" => neighbour_big_five_traits,
        "empty_nearby_positions_for_partner" => collect(empty_nearby_positions(ep, model)),
      ))
    end
  end

  big_five_traits = hasproperty(agent, :big_five_traits) ? Dict(string(k) => v for (k, v) in pairs(agent.big_five_traits)) : nothing

  reproduction_context = Dict{String,Any}(
    "agent_id" => agent.id,
    "position" => agent.pos,
    "sugar" => agent.sugar,
    "min_sugar_for_reproduction" => agent.initial_sugar,
    "age" => agent.age,
    "metabolism" => agent.metabolism,
    "vision" => agent.vision,
    "sex" => agent.sex,
    "big_five_traits" => big_five_traits,
    "culture" => agent.culture,
    "eligible_partners" => eligible_partners_context,
    "max_partners" => max_partners,
    # doesn't need to know values of empty_nearby_positions
    "empty_nearby_positions" => collect(empty_nearby_positions(agent, model)),
  )

  return reproduction_context
end


"""
    build_big_five_culture_context(agent, model, neighbors)

Build a big five culture context for the agent, including their own culture and the cultures of their neighbors.
"""
function build_big_five_culture_context(agent, model, neighbors)

  big_five_traits = hasproperty(agent, :big_five_traits) ? Dict(string(k) => v for (k, v) in pairs(agent.big_five_traits)) : nothing

  culture_context = Dict(
    "agent_id" => agent.id,
    "culture" => agent.culture,
    "big_five_traits" => big_five_traits,
    "neighbors" => []
  )


  for neighbor in neighbors
    neighbour_big_five_traits = hasproperty(neighbor, :big_five_traits) ? Dict(string(k) => v for (k, v) in pairs(neighbor.big_five_traits)) : nothing
    push!(culture_context["neighbors"], Dict(
      "agent_id" => neighbor.id,
      "culture" => neighbor.culture,
      "big_five_traits" => neighbour_big_five_traits,
    ))
  end

  return culture_context
end


"""
build_big_five_credit_lender_context(agent, model, neighbours, amount_available) -> Dict
"""
function build_big_five_credit_lender_context(agent, model, neighbours, amount_available)
  # Collect neighbours if iterable, else wrap single agent in array
  if neighbours isa Base.Generator || neighbours isa AbstractVector
    nbrs = collect(neighbours)
  else
    nbrs = [neighbours]
  end

  big_five_traits = hasproperty(agent, :big_five_traits) ? Dict(string(k) => v for (k, v) in pairs(agent.big_five_traits)) : nothing

  lender_context = Dict(
    :agent_id => agent.id,
    :sugar => agent.sugar,
    :age => agent.age,
    :big_five_traits => big_five_traits,
    :can_lend => true,
    :amount_available => amount_available,
    :eligible_borrowers => [],
    :culture => agent.culture,
  )

  for neighbour in nbrs
    neighbour_big_five_traits = hasproperty(neighbour, :big_five_traits) ? Dict(string(k) => v for (k, v) in pairs(neighbour.big_five_traits)) : nothing
    push!(lender_context[:eligible_borrowers], Dict(
      :agent_id => neighbour.id,
      :sugar => neighbour.sugar,
      :age => neighbour.age,
      :big_five_traits => neighbour_big_five_traits,
      :culture => neighbour.culture,
      :will_borrow => will_borrow(neighbour, model).will_borrow,
      :amount_required => will_borrow(neighbour, model).amount_required
    ))
  end

  return lender_context
end

"""
build_big_five_credit_borrower_context(agent, model, neighbours, amount_required) -> Dict
"""
function build_big_five_credit_borrower_context(agent, model, neighbours, amount_required)
  # Collect neighbours if iterable, else wrap single agent in array
  if neighbours isa Base.Generator || neighbours isa AbstractVector
    nbrs = collect(neighbours)
  else
    nbrs = [neighbours]
  end

  big_five_traits = hasproperty(agent, :big_five_traits) ? Dict(string(k) => v for (k, v) in pairs(agent.big_five_traits)) : nothing

  borrower_context = Dict(
    :agent_id => agent.id,
    :sugar => agent.sugar,
    :age => agent.age,
    :big_five_traits => big_five_traits,
    :will_borrow => will_borrow(agent, model).will_borrow,
    :amount_to_borrow => amount_required,
    :reproduction_threshold => agent.initial_sugar,
    :culture => agent.culture,
    :eligible_lenders => []
  )

  for neighbour in nbrs
    big_five_traits = hasproperty(neighbour, :big_five_traits) ? Dict(string(k) => v for (k, v) in pairs(neighbour.big_five_traits)) : nothing
    push!(borrower_context[:eligible_lenders], Dict(
      :agent_id => neighbour.id,
      :sugar => neighbour.sugar,
      :age => neighbour.age,
      :can_lend => can_lend(neighbour, model).can_lend,
      :max_amount => can_lend(neighbour, model).max_amount,
      :culture => neighbour.culture,
      :big_five_traits => big_five_traits,
    ))
  end

  return borrower_context
end
