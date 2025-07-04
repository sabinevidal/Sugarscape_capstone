using Test
using Sugarscape
using Agents

# Mock call_openai_api to return valid JSON without network calls
const LLM = Sugarscape.SugarscapeLLM
function LLM.call_openai_api(contexts::Vector, model)
  # Return mock decisions that match the expected JSON structure
  return [Dict(
    "move" => false,
    "move_coords" => nothing,
    "combat" => false,
    "combat_target" => nothing,
    "credit" => false,
    "credit_partner" => nothing,
    "reproduce" => false,
    "reproduce_with" => nothing
  ) for _ in contexts]
end

# ---------------------------------------------------------------------------
# Shared helpers & constants
# ---------------------------------------------------------------------------

# Default LLM decision tuple – every field needed by getfield in helper funcs.
const DEFAULT_DEC = (
  move=false, move_coords=nothing,
  combat=false, combat_target=nothing,
  credit=false, credit_partner=nothing,
  reproduce=false, reproduce_with=nothing)

# Inject/override decision for a single agent
function set_decision!(model, agent_id, dec)
  model.llm_decisions[agent_id] = merge(DEFAULT_DEC, dec)
end

# Lightweight custom agent factory (mirrors one from gating tests)
function add_custom_agent!(model, pos; sugar, vision=1, metabolism=0, sex=:male,
  age=0, max_age=100, culture_bit=false)
  initial_sugar = sugar
  children = Int[]
  total_inheritance_received = 0.0
  culture = BitVector([culture_bit])
  loans = NTuple{4,Int}[]
  diseases = BitVector[]
  immunity = falses(model.disease_immunity_length)
  return add_agent!(pos, SugarscapeAgent, model, vision, metabolism, sugar, age,
    max_age, sex, false, initial_sugar, children, total_inheritance_received,
    culture, loans, diseases, immunity)
end

# ---------------------------------------------------------------------------
# 1. Decision helper unit tests
# ---------------------------------------------------------------------------

@testset "Decision Helpers" begin
  model = Sugarscape.sugarscape(; dims=(3, 3), N=0, seed=1, growth_rate=0)
  model.use_llm_decisions = true

  ag = add_custom_agent!(model, (2, 2); sugar=0)

  # --- should_act & get_decision when move=false --------------------------------
  set_decision!(model, ag.id, (move=false,))
  @test !Sugarscape.should_act(ag, model, Val(:move))
  @test Sugarscape.get_decision(ag, model).move_coords === nothing

  # --- should_act & get_decision when move=true ---------------------------------
  set_decision!(model, ag.id, (move=true, move_coords=(2, 3)))
  @test Sugarscape.should_act(ag, model, Val(:move))
  @test Sugarscape.get_decision(ag, model).move_coords == (2, 3)
end

# ---------------------------------------------------------------------------
# 2. idle! behaviour
# ---------------------------------------------------------------------------

@testset "idle!" begin
  model = Sugarscape.sugarscape(; dims=(3, 3), N=0, seed=2, growth_rate=0,
    vision_dist=(1, 1), metabolic_rate_dist=(1, 1), w0_dist=(0, 0))
  model.enable_pollution = false  # simplify assertions

  model.sugar_values .= 0.0
  model.sugar_values[2, 2] = 5.0

  ag = add_custom_agent!(model, (2, 2); sugar=0, metabolism=1)

  Sugarscape.idle!(ag, model)

  @test isapprox(ag.sugar, 4.0; atol=1e-8)  # 5 collected - 1 metabolism
  @test ag.age == 1
  @test model.sugar_values[2, 2] == 0.0
end

# ---------------------------------------------------------------------------
# 3. Movement helper functions
# ---------------------------------------------------------------------------

@testset "Movement Helpers" begin
  # --- _do_move! --------------------------------------------------------------
  model = Sugarscape.sugarscape(; dims=(3, 3), N=0, seed=3, growth_rate=0,
    vision_dist=(1, 1), metabolic_rate_dist=(1, 1), w0_dist=(0, 0))
  model.enable_pollution = false
  model.sugar_values .= 0.0
  model.sugar_values[2, 3] = 5.0

  ag = add_custom_agent!(model, (2, 2); sugar=0, metabolism=1)

  Sugarscape._do_move!(ag, model, (2, 3))

  @test ag.pos == (2, 3)
  @test isapprox(ag.sugar, 4.0; atol=1e-8)
  @test ag.age == 1
  @test model.sugar_values[2, 3] == 0.0

  # --- try_llm_move! valid target -------------------------------------------
  model2 = Sugarscape.sugarscape(; dims=(3, 3), N=0, seed=4, growth_rate=0,
    vision_dist=(1, 1), metabolic_rate_dist=(1, 1), w0_dist=(0, 0))
  model2.enable_pollution = false
  model2.sugar_values .= 0.0
  model2.sugar_values[2, 3] = 5.0
  ag2 = add_custom_agent!(model2, (2, 2); sugar=0, metabolism=1)

  Sugarscape.try_llm_move!(ag2, model2, (2, 3))
  @test ag2.pos == (2, 3)

  # --- try_llm_move! invalid target (fallback) -------------------------------
  model3 = Sugarscape.sugarscape(; dims=(3, 3), N=0, seed=5, growth_rate=0,
    vision_dist=(1, 1), metabolic_rate_dist=(1, 1), w0_dist=(0, 0))
  model3.enable_pollution = false
  model3.sugar_values .= 0.0
  model3.sugar_values[2, 3] = 5.0
  ag3 = add_custom_agent!(model3, (2, 2); sugar=0, metabolism=1)

  Sugarscape.try_llm_move!(ag3, model3, (1, 1))  # outside vision → invalid

  @test ag3.pos != (1, 1)  # fallback chose a different move
  @test ag3.sugar > 0.0     # sugar collected
end
