
"""
Movement (M) Rule Implementation

"""

"""
    build_movement_context(agent, model) -> Dict
Collect a lightweight JSON-serialisable summary of the local state that the LLM
can use to decide on the agent's next actions.  The schema is intentionally kept
stable so tests that rely on it do not break when the runtime model evolves.
"""
function build_movement_context(agent, model)
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
    ))
    push!(occupied_positions, Dict(
      "position" => nb.pos,
    ))
  end

  return Dict(
    "agent_id" => agent.id,
    "position" => agent.pos,
    "sugar" => round(agent.sugar, digits=2),
    "age" => agent.age,
    "metabolism" => agent.metabolism,
    "vision" => agent.vision,
    "sex" => agent.sex,
    "visible_positions" => visible_positions,
    # Future use could be allowing the agent to choose where to move based on what neighbours are nearby and what interaction is possible
    "neighbours" => neighbours,
    "occupied_positions" => occupied_positions,
    "enable_combat" => model.enable_combat,
    "enable_reproduction" => model.enable_reproduction,
    "enable_credit" => model.enable_credit,
  )
end

"""
    _do_move!(agent, model, target_pos)

Internal helper that performs the side-effects of moving an `agent` to
`target_pos`: collects sugar, applies metabolism & ageing, and optionally
produces pollution. It is shared by both the vanilla M-rule and LLM-directed
moves so that their bookkeeping stays identical.
"""
function _do_move!(agent, model, target_pos)
  sugar_collected = model.sugar_values[target_pos...]
  move_agent!(agent, target_pos, model)
  agent.sugar += (sugar_collected - agent.metabolism)
  model.sugar_values[target_pos...] = 0
  agent.age += 1

  if model.enable_pollution
    produced_pollution = model.production_rate * sugar_collected +
                         model.consumption_rate * agent.metabolism
    model.pollution[target_pos...] += produced_pollution
  end
end


"""
    llm_move!(agent, model, target_pos)

Attempt to move `agent` to `target_pos` proposed by an LLM. The move is allowed
only if the cell is empty, within the agent's vision and inside the grid
bounds. If the target is invalid or `nothing`, the agent stays idle.
"""
function llm_move!(agent, model, target_pos)
  # If no target specified, agent stays idle
  pos_before = agent.pos

  if target_pos === nothing
    idle!(agent, model)
    return
  end

  # Defensive: ensure we have a tuple of integers
  if !(target_pos isa Tuple{Int,Int})
    idle!(agent, model)
    return
  end

  if isempty(target_pos, model) &&
     euclidean_distance(agent.pos, target_pos) <= agent.vision &&
     all(1 .<= target_pos .<= size(getfield(model, :space)))
    _do_move!(agent, model, target_pos)
  else
    # Invalid target - agent stays idle
    idle!(agent, model)
  end
end

"""
    welfare(pos_tuple, model) -> Float64

Compute the welfare at a grid position. When pollution is enabled, welfare is
sugar ÷ (1 + pollution); otherwise it is simply the amount of sugar in the cell.
The added constant `1.0` protects against division-by-zero and ensures the
computation uses floating-point arithmetic.
"""
function welfare(pos_tuple, model)
  sugar_at_pos = model.sugar_values[pos_tuple...]
  pollution_at_pos = model.pollution[pos_tuple...]
  return sugar_at_pos / (1.0 + pollution_at_pos)
end

"""
    euclidean_distance(pos1, pos2) -> Float64

Return the Euclidean distance between two lattice positions given as tuples.
"""
function euclidean_distance(pos1, pos2)
  return sqrt(sum((pos1[i] - pos2[i])^2 for i in 1:length(pos1)))
end

"""
    evaluate_nearby_positions(agent, model) -> Vector{Tuple{NTuple{2,Int}, Float64, Float64}}

Evaluate all positions within an agent's vision range to find all available move targets.
Returns a vector of tuples containing (position, value, distance) for all visible unoccupied
positions, where value is either sugar or welfare depending on whether pollution is enabled.

The returned positions include all unoccupied cells within vision range, sorted by value
(descending) and then by distance (ascending). The agent's current position is always
included as a baseline option.
"""
function evaluate_nearby_positions(agent, model)
  # Welfare or sugar at the current position (baseline option)
  current_val = model.enable_pollution ? welfare(agent.pos, model) :
                model.sugar_values[agent.pos...]
  all_positions = [(agent.pos, current_val, 0.0)]  # (pos, value, distance)

  for pos in nearby_positions(agent, model, agent.vision)
    # Skip occupied cells – agent can only move to empty ones
    !isempty(pos, model) && continue

    sugar_val = model.enable_pollution ? welfare(pos, model) :
                model.sugar_values[pos...]
    dist = euclidean_distance(agent.pos, pos)

    push!(all_positions, (pos, sugar_val, dist))
  end

  # Sort by value (descending) then by distance (ascending)
  sort!(all_positions, by=x -> (-x[2], x[3]))

  return all_positions
end

"""
    get_best_positions(agent, model) -> Vector{Tuple{NTuple{2,Int}, Float64, Float64}}

Extract the best maximum value positions from all visible positions.
Returns only the positions with the highest value (sugar or welfare), and among
those with equal values, only the nearest ones. This replicates the original
filtering logic of evaluate_nearby_positions.
"""
function get_best_positions(agent, model)
  all_positions = evaluate_nearby_positions(agent, model)

  if isempty(all_positions)
    return all_positions
  end

  # Get the maximum value (first position has highest value due to sorting)
  max_val = all_positions[1][2]
  min_dist = all_positions[1][3]
  best_positions = [all_positions[1]]

  # Find all positions with the same maximum value and minimum distance
  for (pos, val, dist) in all_positions[2:end]
    if val == max_val && dist == min_dist
      push!(best_positions, (pos, val, dist))
    elseif val < max_val
      break  # No more positions with maximum value
    end
  end

  return best_positions
end

"""
# Movement (M) Rule
Look out as far as vision permits in the four principal lattice directions and
identify the unoccupied site(s) having the most sugar (or highest welfare when
pollution is considered). If the greatest value appears on multiple sites then
select the nearest; if still tied choose randomly. Move to this site and collect
all sugar there.
"""
function movement!(agent, model)
  if model.use_llm_decisions
    if model.use_big_five
      movement_context = build_big_five_movement_context(agent, model)
    elseif model.use_schwartz_values
      movement_context = build_schwartz_values_movement_context(agent, model)
    else
      movement_context = build_movement_context(agent, model)
    end
    movement_decision = SugarscapeLLM.get_movement_decision(movement_context, model)

    println("Agent $(agent.id) Movement: ", movement_decision.reasoning)

    llm_move!(agent, model, movement_decision.move_coords)
  else
    best_positions = get_best_positions(agent, model)
    # Choose among best (nearest, then random tie-break)
    chosen_pos, _, _ = rand(abmrng(model), best_positions)
    _do_move!(agent, model, chosen_pos)
  end

  return
end
