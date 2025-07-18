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
