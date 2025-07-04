using Test
using Sugarscape
using Agents

###############################################################################
# Helper to inject LLM decisions for specific agents
###############################################################################

const DEFAULT_DEC = (move=false, move_coords=nothing,
  combat=false, combat_target=nothing,
  credit=false, credit_partner=nothing,
  reproduce=false, reproduce_with=nothing)

function set_decision!(model, agent_id, dec)
  model.llm_decisions[agent_id] = merge(DEFAULT_DEC, dec)
end

# lightweight agent creator for tests
function add_custom_agent!(model, pos; sugar, vision=1, metabolism=0, sex=:male,
  age=0, max_age=100)
  initial_sugar = sugar
  children = Int[]
  total_inheritance_received = 0.0
  culture = BitVector([false])
  loans = NTuple{4,Int}[]
  diseases = BitVector[]
  immunity = falses(model.disease_immunity_length)

  return add_agent!(pos, SugarscapeAgent, model, vision, metabolism, sugar, age,
    max_age, sex, false, initial_sugar, children, total_inheritance_received,
    culture, loans, diseases, immunity)
end

###############################################################################
# Movement gating
###############################################################################
@testset "LLM gating – Movement" begin
  model = Sugarscape.sugarscape(; dims=(5, 5), N=0, seed=1,
    growth_rate=0, vision_dist=(1, 1), metabolic_rate_dist=(0, 0), w0_dist=(0, 0))
  model.use_llm_decisions = true

  model.sugar_values .= 0.0
  model.sugar_values[3, 3] = 5.0
  model.sugar_values[3, 4] = 10.0

  add_agent!((3, 3), SugarscapeAgent, model, 1, 0, 0.0, 0, 100, :male, false, 0.0,
    Int[], 0.0, BitVector([false]), NTuple{4,Int}[], BitVector[], falses(model.disease_immunity_length))
  ag = first(allagents(model))

  # 1. move=false → idle!
  set_decision!(model, ag.id, (move=false,))
  Sugarscape._agent_step!(ag, model)
  @test ag.pos == (3, 3)
  @test isapprox(ag.sugar, 5.0; atol=1e-8)

  # reset state
  ag.sugar = 0.0
  model.sugar_values[3, 3] = 5.0

  # 2. move to explicit coords
  set_decision!(model, ag.id, (move=true, move_coords=(3, 4)))
  Sugarscape._agent_step!(ag, model)
  @test ag.pos == (3, 4)
end

###############################################################################
# Reproduction gating
###############################################################################
@testset "LLM gating – Reproduction" begin
  model = Sugarscape.sugarscape(; dims=(5, 5), N=0, seed=2,
    enable_reproduction=true, growth_rate=0,
    vision_dist=(1, 1), metabolic_rate_dist=(0, 0), w0_dist=(20, 20))
  model.use_llm_decisions = true
  model.sugar_values .= 0.0

  male = add_agent!((2, 2), SugarscapeAgent, model, 1, 0, 20.0, 25, 100, :male, false, 20.0,
    Int[], 0.0, BitVector([false]), NTuple{4,Int}[], BitVector[], falses(model.disease_immunity_length))
  female = add_agent!((3, 2), SugarscapeAgent, model, 1, 0, 20.0, 25, 100, :female, false, 20.0,
    Int[], 0.0, BitVector([true]), NTuple{4,Int}[], BitVector[], falses(model.disease_immunity_length))

  # Case 1: reproduce=false → should not reproduce
  set_decision!(model, male.id, (reproduce=false,))
  set_decision!(model, female.id, (reproduce=false,))
  Sugarscape.reproduction!(model)
  @test nagents(model) == 2

  # Reset reproduction flags
  male.has_reproduced = false
  female.has_reproduced = false

  # Case 2: reproduce_with explicit partner
  set_decision!(model, male.id, (reproduce=true, reproduce_with=female.id))
  set_decision!(model, female.id, (reproduce=true, reproduce_with=male.id))
  Sugarscape.reproduction!(model)
  @test nagents(model) == 3
end

###############################################################################
# Credit gating
###############################################################################
@testset "LLM gating – Credit" begin
  model = Sugarscape.sugarscape(; dims=(3, 3), N=0, seed=3, enable_credit=true,
    interest_rate=0.0, duration=1, growth_rate=0,
    vision_dist=(1, 1), metabolic_rate_dist=(0, 0), w0_dist=(0, 0))
  model.use_llm_decisions = true
  model.sugar_values .= 0.0

  lender = add_custom_agent!(model, (2, 2); sugar=40, sex=:male, age=55)
  borrower = add_custom_agent!(model, (2, 3); sugar=10, sex=:female, age=25)

  # lender credit=false → no loan
  set_decision!(model, lender.id, (credit=false,))
  set_decision!(model, borrower.id, (credit=true,))
  Sugarscape.make_loans!(model, 0)
  @test isempty(lender.loans)

  # enable credit, explicit partner
  set_decision!(model, lender.id, (credit=true, credit_partner=borrower.id))
  Sugarscape.make_loans!(model, 1)
  @test !isempty(lender.loans)
end

###############################################################################
# Combat gating
###############################################################################
@testset "LLM gating – Combat" begin
  model = Sugarscape.sugarscape(; dims=(3, 3), N=0, seed=4, enable_combat=true,
    combat_limit=10, growth_rate=0,
    vision_dist=(1, 1), metabolic_rate_dist=(0, 0), w0_dist=(0, 0))
  model.use_llm_decisions = true
  model.sugar_values .= 0.0

  attacker = add_custom_agent!(model, (2, 2); sugar=20, sex=:male, age=30)
  victim = add_custom_agent!(model, (2, 3); sugar=5, sex=:female, age=30)
  attacker.culture = BitVector([false])
  victim.culture = BitVector([true])  # ensure different tribes

  # Case 1: combat=false → no attack should occur
  set_decision!(model, attacker.id, (combat=false,))
  set_decision!(model, victim.id, (combat=false,))
  Sugarscape.combat!(model)
  @test nagents(model) == 2
  @test victim in allagents(model)

  # ---------------------------------------------------------------------------
  # Case 2: combat=true with explicit target should result in victim death
  # ---------------------------------------------------------------------------
  model = Sugarscape.sugarscape(; dims=(3, 3), N=0, seed=5, enable_combat=true,
    combat_limit=10, growth_rate=0,
    vision_dist=(1, 1), metabolic_rate_dist=(0, 0), w0_dist=(0, 0))
  model.use_llm_decisions = true
  model.sugar_values .= 0.0

  attacker = add_custom_agent!(model, (2, 2); sugar=20, sex=:male, age=30)
  victim = add_custom_agent!(model, (2, 3); sugar=5, sex=:female, age=30)
  attacker.culture = BitVector([false])
  victim.culture = BitVector([true])

  set_decision!(model, attacker.id, (combat=true, combat_target=victim.id))
  set_decision!(model, victim.id, (combat=false,))
  Sugarscape.combat!(model)
  @test nagents(model) == 1
  @test attacker in allagents(model)
  @test attacker.sugar > 20  # gained sugar from victim
end
