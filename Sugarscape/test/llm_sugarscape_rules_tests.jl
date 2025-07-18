using Test
using Random
using Sugarscape
using Agents
using DotEnv
using Logging
DotEnv.load!()

################################################################################
# Helpers
################################################################################

"""
    log_test_step(step_name, condition, expected=nothing, actual=nothing)

Log the result of a test step with clear pass/fail indication.
"""
function log_test_step(step_name, condition, expected=nothing, actual=nothing)
  if condition
    @info "✅ $step_name"
    if expected !== nothing && actual !== nothing
      @info "   Expected: $expected, Got: $actual"
    end
  else
    @info "❌ $step_name"
    if expected !== nothing && actual !== nothing
      @info "   Expected: $expected, Got: $actual"
    end
  end
  return condition
end

"""
    add_custom_agent!(model, pos; kwargs...)

Utility for inserting a `SugarscapeAgent` at a specific position with explicit
attributes so that tests remain deterministic and self-contained.  In addition
to creating the agent it also:

1. Switches the *test* model into `use_llm_decisions = true` mode (this is a
   local change that avoids the expensive network call in the main constructor
   because we toggle the flag *after* model creation).
2. Ensures the model has API key set for individual agent decisions.

Keyword arguments default to sensible values but can be overridden per test.
"""
function add_custom_agent!(model, pos; sugar, initial_sugar=sugar, vision=2, metabolism=0, sex=:male,
  age=0, max_age=100, culture_bits=[false], has_reproduced=false)

  # Ensure the model operates under the LLM gating mechanism.  We toggle the
  # flag here in case the model was created without it.
  model.use_llm_decisions = true

  # Pull API key from ENV if still unset so that individual agent decisions work.
  if isempty(model.llm_api_key)
    model.llm_api_key = get(ENV, "OPENAI_API_KEY", "")
  end

  # Create the agent with deterministic attributes as before
  initial_sugar = initial_sugar
  children = Int[]
  total_inheritance_received = 0.0
  culture = BitVector(culture_bits)
  diseases = BitVector[]
  immunity = falses(model.disease_immunity_length)
  loans_given = Dict{Int,Vector{Sugarscape.Loan}}()
  loans_owed = Dict{Int,Vector{Sugarscape.Loan}}()

  ag = add_agent!(pos, SugarscapeAgent, model, vision, metabolism, sugar, age,
    max_age, sex, has_reproduced, initial_sugar, children,
    total_inheritance_received, culture, loans_given, loans_owed,
    diseases, immunity)

  return ag
end

################################################################################
# Movement Rule (M) – Specification Conformance Tests
################################################################################
# # Seed for deterministic behaviour across all tests in this set
rng_seed = 0x20240622
@testset "Movement Rule (M)" begin
  @info "🏃 Starting Movement Rule tests..."

  ##########################################################################
  # 1. Moves to the max-sugar site within vision
  ##########################################################################
  @info "Testing: Agent moves to max-sugar site within vision"

  model = Sugarscape.sugarscape(; dims=(5, 5), N=0, seed=rng_seed,
    growth_rate=0,                      # disable growback
    vision_dist=(2, 2),                 # deterministic vision
    metabolic_rate_dist=(0, 0),         # no metabolism for clarity
    initial_sugar_dist=(0, 0),                     # start with zero sugar
    use_llm_decisions=true)


  model.sugar_values .= 0.0        # blank slate

  # Place a high-sugar site north (within vision=2)
  model.sugar_values[3, 5] = 10.0  # grid is (x, y)
  model.sugar_values[1, 3] = 8.0   # another site, lower sugar

  agent_pos = (3, 3)
  agent = add_custom_agent!(model, agent_pos; sugar=0, vision=2, metabolism=0)

  _agent_step_llm!(agent, model)

  @test log_test_step("Agent moved to max-sugar site", agent.pos == (3, 5), (3, 5), agent.pos)
  @test log_test_step("Agent collected all sugar", agent.sugar == 10.0, 10.0, agent.sugar)
  @test log_test_step("Sugar site depleted", model.sugar_values[3, 5] == 0.0, 0.0, model.sugar_values[3, 5])

  ##########################################################################
  # 2. Tie-breaking by distance (prefer nearer of equal sugar)
  ##########################################################################
  @info "Testing: Tie-breaking by distance preference"

  model = Sugarscape.sugarscape(; dims=(7, 7), N=0, seed=rng_seed,
    growth_rate=0, vision_dist=(3, 3), metabolic_rate_dist=(0, 0), initial_sugar_dist=(0, 0), use_llm_decisions=true)
  model.sugar_values .= 0.0

  agent_pos = (4, 4)
  # Two sites with identical sugar within vision: one distance 1, another distance 3
  model.sugar_values[5, 4] = 9.0   # east, distance 1
  model.sugar_values[1, 4] = 9.0   # far west, distance 3

  agent = add_custom_agent!(model, agent_pos; sugar=0, vision=3, metabolism=0)

  _agent_step_llm!(agent, model)

  @test log_test_step("Agent chose closer site for tie-breaking", agent.pos == (5, 4), (5, 4), agent.pos)

  ##########################################################################
  # 3. No move if all neighbouring sites are occupied (must stay put)
  ##########################################################################
  @info "Testing: No movement when all neighbours are occupied"

  model = Sugarscape.sugarscape(; dims=(5, 5), N=0, seed=rng_seed,
    growth_rate=0, vision_dist=(1, 1), metabolic_rate_dist=(0, 0), initial_sugar_dist=(0, 0), use_llm_decisions=true)
  model.sugar_values .= 0.0

  focal_pos = (3, 3)

  # Insert focal agent first
  focal_agent = add_custom_agent!(model, focal_pos; sugar=0, vision=1, metabolism=0)

  # Surround focal agent with blockers at the four von-Neumann neighbours
  for pos in ((3, 4), (3, 2), (2, 3), (4, 3))
    add_custom_agent!(model, pos; sugar=0, vision=1, metabolism=0)
  end

  _agent_step_llm!(focal_agent, model)

  @test log_test_step("Agent stayed put when surrounded", focal_agent.pos == focal_pos, focal_pos, focal_agent.pos)

  @test log_test_step("Grid is full as expected", nagents(model) == 5, 5, nagents(model))

  ##########################################################################
  # 4. Multiple agents move to valid spots
  ##########################################################################
  @info "Testing: Multiple agents move to valid spots"

  model = Sugarscape.sugarscape(; dims=(7, 7), N=0, seed=rng_seed,
    growth_rate=0, vision_dist=(2, 2), metabolic_rate_dist=(0, 0), initial_sugar_dist=(0, 0), use_llm_decisions=true)
  model.sugar_values .= 0.0

  # Create multiple sugar sites with different values
  model.sugar_values[2, 2] = 15.0  # highest sugar
  model.sugar_values[4, 4] = 12.0  # medium sugar
  model.sugar_values[6, 6] = 8.0   # lower sugar
  model.sugar_values[1, 1] = 10.0  # another site

  # Place agents at different starting positions and track them individually
  agent1_pos = (3, 3)  # should move to (2, 2) - highest sugar within vision
  agent2_pos = (5, 5)  # should move to (4, 4) - highest sugar within vision
  agent3_pos = (1, 3)  # should move to (1, 1) - only sugar site in vision

  agent1 = add_custom_agent!(model, agent1_pos; sugar=0, vision=2, metabolism=0)
  agent2 = add_custom_agent!(model, agent2_pos; sugar=0, vision=2, metabolism=0)
  agent3 = add_custom_agent!(model, agent3_pos; sugar=0, vision=2, metabolism=0)

  agents = [agent1, agent2, agent3]
  @test length(agents) == 3

  # Move all agents using individual decisions
  for agent in agents
    _agent_step_llm!(agent, model)
  end

  # Check that each specific agent moved to the expected position
  @test log_test_step("Agent 1 moved to highest sugar site", agent1.pos == (2, 2), (2, 2), agent1.pos)
  @test log_test_step("Agent 2 moved to medium sugar site", agent2.pos == (4, 4), (4, 4), agent2.pos)
  @test log_test_step("Agent 3 moved to available sugar site", agent3.pos == (1, 1), (1, 1), agent3.pos)

  # Check that each specific agent collected the expected sugar
  @test log_test_step("Agent 1 collected 15 sugar", agent1.sugar == 15.0, 15.0, agent1.sugar)
  @test log_test_step("Agent 2 collected 12 sugar", agent2.sugar == 12.0, 12.0, agent2.sugar)
  @test log_test_step("Agent 3 collected 10 sugar", agent3.sugar == 10.0, 10.0, agent3.sugar)

  # Check that sugar sites were depleted
  @test log_test_step("Sugar site (2,2) depleted", model.sugar_values[2, 2] == 0.0, 0.0, model.sugar_values[2, 2])
  @test log_test_step("Sugar site (4,4) depleted", model.sugar_values[4, 4] == 0.0, 0.0, model.sugar_values[4, 4])
  @test log_test_step("Sugar site (1,1) depleted", model.sugar_values[1, 1] == 0.0, 0.0, model.sugar_values[1, 1])

  # Check that agents are at different positions (no collisions)
  agent_positions = [agent1.pos, agent2.pos, agent3.pos]
  unique_positions = unique(agent_positions)
  @test log_test_step("All agents moved to different positions", length(unique_positions) == 3, 3, length(unique_positions))

  @info "✅ Movement Rule tests completed successfully"
end

################################################################################
# Reproduction Rule (S) – Specification Conformance Tests
################################################################################

@testset "Reproduction Rule (S)" begin

  ##########################################################################
  # 1. Successful reproduction with opposite sex, fertility & empty cell
  ##########################################################################
  @info "Testing: Successful reproduction with opposite sex, fertility & empty cell"
  model = Sugarscape.sugarscape(; dims=(5, 5), N=0, seed=rng_seed,
    enable_reproduction=true, growth_rate=0,
    vision_dist=(1, 1), metabolic_rate_dist=(0, 0),
    initial_sugar_dist=(20, 20), use_llm_decisions=true)

  model.sugar_values .= 0.0

  # Parents: male & female, fertile age 25, adjacent horizontally with an empty
  # cell above them to host the child.
  add_custom_agent!(model, (3, 3); sugar=20, sex=:male, age=25, vision=1, metabolism=0, culture_bits=[false, false, false])
  add_custom_agent!(model, (4, 3); sugar=20, sex=:female, age=25, vision=1, metabolism=0, culture_bits=[true, true, true])

  @test log_test_step("Number of agents before reproduction", nagents(model) == 2, 2, nagents(model))

  # Test reproduction with a random agent
  focal_agent = random_agent(model)
  @info "Focal agent: $focal_agent"
  Sugarscape.reproduction!(focal_agent, model)

  @test log_test_step("Number of agents after reproduction", nagents(model) == 3, 3, nagents(model))

  # Identify parents and child by reproduction flag
  parents = [a for a in allagents(model) if a.has_reproduced]
  @test log_test_step("Number of parents", length(parents) == 2, 2, length(parents))

  child_candidates = [a for a in allagents(model) if !a.has_reproduced]
  @test log_test_step("Number of child candidates", length(child_candidates) == 1, 1, length(child_candidates))
  child = only(child_candidates)

  # Parents lost half their initial endowment (20/2 = 10)
  @test log_test_step("Parents sugar", all(isapprox(p.sugar, 10.0; atol=1e-8) for p in parents), true, all(isapprox(p.sugar, 10.0; atol=1e-8) for p in parents))

  # Child sugar equals contributions (10 + 10)
  @test log_test_step("Child sugar", isapprox(child.sugar, 20.0; atol=1e-8), true, isapprox(child.sugar, 20.0; atol=1e-8))

  # Child ID recorded in parents' children arrays
  @test log_test_step("Child ID in parents' children arrays", all(child.id in p.children for p in parents), true, all(child.id in p.children for p in parents))

  # Child located in one of the empty neighbouring cells (radius 1) of parents
  possible_child_cells = Set{Tuple{Int,Int}}()
  for par in parents                     # materialise the generators
    for p in nearby_positions(par.pos, model, 1)
      push!(possible_child_cells, p)
    end
  end
  @test log_test_step("Child position in possible child cells", child.pos in possible_child_cells, true, child.pos in possible_child_cells)

  # Child culture bits must come from one of the parents at each index
  parent1, parent2 = parents
  @test log_test_step("Child culture bits match parents", all(child.culture[i] == parent1.culture[i] || child.culture[i] == parent2.culture[i] for i in 1:length(child.culture)), true, all(child.culture[i] == parent1.culture[i] || child.culture[i] == parent2.culture[i] for i in 1:length(child.culture)))

  ##########################################################################
  # 2. No reproduction when no empty neighbouring site
  ##########################################################################
  @info "Testing: No reproduction when no empty neighbouring site"
  model = Sugarscape.sugarscape(; dims=(3, 3), N=0, seed=rng_seed,
    enable_reproduction=true, growth_rate=0,
    vision_dist=(1, 1), metabolic_rate_dist=(0, 0),
    initial_sugar_dist=(20, 20), use_llm_decisions=true)
  model.sugar_values .= 0.0

  # Place fertile male & female adjacent at centre; fill every other cell
  focal_A = (2, 2)
  focal_B = (2, 3)
  add_custom_agent!(model, focal_A; sugar=20, sex=:male, age=25, culture_bits=[false])
  add_custom_agent!(model, focal_B; sugar=20, sex=:female, age=25, culture_bits=[true])

  focal_agent = random_agent(model)

  # Fill remaining 7 cells of the 3×3 grid
  for pos in ((1, 1), (1, 2), (1, 3), (2, 1), (3, 1), (3, 2), (3, 3))
    isempty(pos, model) || continue
    add_custom_agent!(model, pos; sugar=5, sex=:male)
  end

  @test log_test_step("Number of agents before reproduction", nagents(model) == 9, 9, nagents(model))

  Sugarscape.reproduction!(focal_agent, model)

  @test log_test_step("Number of agents after reproduction", nagents(model) == 9, 9, nagents(model))


  ##########################################################################
  # 3. Reproduced with max_partners
  ##########################################################################
  @info "Testing: Agent reproduces with up to max partners"
  model = Sugarscape.sugarscape(; dims=(5, 5), N=0, seed=rng_seed,
    enable_reproduction=true, growth_rate=0,
    vision_dist=(1, 1), metabolic_rate_dist=(0, 0),
    initial_sugar_dist=(20, 20), use_llm_decisions=true)
  model.sugar_values .= 0.0

  model.reproduction_counts_step = Dict{Int,Int}()

  # Place fertile female at centre
  focal_agent = add_custom_agent!(model, (3, 3); sugar=15, initial_sugar=5, sex=:female, age=25, culture_bits=[true])

  # 4 surrounding agents, 3 fertile
  for pos in ((2, 3), (3, 2), (4, 3))
    isempty(pos, model) || continue
    add_custom_agent!(model, pos; sugar=20, sex=:male, age=25, culture_bits=[false])
  end

  # Add one more agent that is not fertile
  add_custom_agent!(model, (3, 4); sugar=20, sex=:male, age=5, culture_bits=[false])

  @test log_test_step("Number of agents before reproduction", nagents(model) == 5, 5, nagents(model))

  Sugarscape.reproduction!(focal_agent, model)

  @test log_test_step("Number of agents after reproduction", nagents(model) == 7, 7, nagents(model))

  steps = get(model.reproduction_counts_step, focal_agent.id, 0)
  # Check reproduction counts step has been updated
  @test log_test_step("Reproduction counts step", steps == 2, 2, steps)


  # Check history has updated for 2 agents with 1 reproduction each, and 1 agent with 2
  history_dicts = collect(values(model.reproduction_counts_history))
  if isempty(history_dicts)
    @test log_test_step("Reproduction counts history", false, [1, 1, 2], [])
  else
    history = only(history_dicts)
    counts = sort(collect(values(history)))
    @test log_test_step("Reproduction counts history", counts == [1, 1, 2], [1, 1, 2], counts)
  end
end

################################################################################
# Culture Rule (K) – Specification Conformance Tests
################################################################################

@testset "Culture Rule (K)" begin

  ##########################################################################
  # 1. Neighbour flips bit to match agent
  ##########################################################################
  model = Sugarscape.sugarscape(; dims=(3, 3), N=0, seed=rng_seed,
    enable_culture=true, culture_tag_length=1,
    enable_combat=false, growth_rate=0,
    vision_dist=(1, 1), metabolic_rate_dist=(0, 0), initial_sugar_dist=(0, 0), use_llm_decisions=true)

  model.sugar_values .= 0.0

  a = add_custom_agent!(model, (2, 2); sugar=0, culture_bits=[false])
  b = add_custom_agent!(model, (2, 3); sugar=0, culture_bits=[true])

  Sugarscape.culture_spread!(a, model)

  @test log_test_step("Agent A culture matches neighbour B", a.culture[1] == b.culture[1], true, a.culture[1] == b.culture[1])


  ##########################################################################
  # 2. No change if bits already match
  ##########################################################################
  model = Sugarscape.sugarscape(; dims=(3, 3), N=0, seed=rng_seed,
    enable_culture=true, culture_tag_length=1,
    growth_rate=0, vision_dist=(1, 1), metabolic_rate_dist=(0, 0), initial_sugar_dist=(0, 0), use_llm_decisions=true)
  model.sugar_values .= 0.0

  c1 = add_custom_agent!(model, (1, 1); sugar=0, culture_bits=[true])
  c2 = add_custom_agent!(model, (1, 2); sugar=0, culture_bits=[true])

  culture_decision = Sugarscape.culture_spread!(c1, model)

  @test log_test_step("Culture bits unchanged for matching agents", c1.culture[1] == c2.culture[1], true, c1.culture[1] == c2.culture[1])

  ##########################################################################
  # 3. Tribe calculation (blue vs red)
  ##########################################################################
  red_agent = add_custom_agent!(model, (3, 1); sugar=0, culture_bits=[true, true, false])
  blue_agent = add_custom_agent!(model, (3, 2); sugar=0, culture_bits=[false, false, true])


  @test log_test_step("Agent A is red tribe", Sugarscape.tribe(red_agent) == :red, true, Sugarscape.tribe(red_agent))
  @test log_test_step("Agent B is blue tribe", Sugarscape.tribe(blue_agent) == :blue, true, Sugarscape.tribe(blue_agent))

  ##########################################################################
  # 4. Multiple tag propagation (only one tag affected)
  ##########################################################################

  model = Sugarscape.sugarscape(; dims=(3, 3), N=0, seed=rng_seed,
    enable_culture=true, culture_tag_length=3,
    vision_dist=(1, 1), metabolic_rate_dist=(0, 0), initial_sugar_dist=(0, 0), use_llm_decisions=true)
  model.sugar_values .= 0.0

  d1 = add_custom_agent!(model, (2, 2); sugar=0, culture_bits=[true, true, true])
  d2 = add_custom_agent!(model, (2, 3); sugar=0, culture_bits=[false, false, false])

  before = copy(d2.culture)

  Sugarscape.culture_spread!(d1, model)

  # Only one tag should have changed (with fixed seed, index is deterministic)
  changed = sum(before .!= d2.culture)
  @test log_test_step("Only one culture tag changed", changed == 1, true, changed)

  # The changed bit matches d1 at that index
  idx = findfirst(before .!= d2.culture)
  if idx === nothing
    @test log_test_step("Changed culture tag matches d1", d2.culture[idx] == d1.culture[idx], true, d2.culture[idx] == d1.culture[idx]) broken = true
  end
  @test log_test_step("Changed culture tag matches d1", d2.culture[idx] == d1.culture[idx], true, d2.culture[idx] == d1.culture[idx])

  ##########################################################################
  # 5. All neighbours update
  ##########################################################################
  model = Sugarscape.sugarscape(; dims=(3, 3), N=0, seed=rng_seed,
    enable_culture=true, culture_tag_length=1,
    vision_dist=(1, 1), metabolic_rate_dist=(0, 0), initial_sugar_dist=(0, 0), use_llm_decisions=true)
  model.sugar_values .= 0.0

  e = add_custom_agent!(model, (2, 2); sugar=0, culture_bits=[true])

  neighbors = [
    add_custom_agent!(model, (2, 1); sugar=0, culture_bits=[false]),
    add_custom_agent!(model, (2, 3); sugar=0, culture_bits=[false]),
    add_custom_agent!(model, (1, 2); sugar=0, culture_bits=[false]),
    add_custom_agent!(model, (3, 2); sugar=0, culture_bits=[false])
  ]

  culture_decision = Sugarscape.culture_spread!(e, model)

  @test log_test_step("All neighbors updated culture", all(n.culture[1] == true for n in neighbors), true, all(n.culture[1] == true for n in neighbors))

  ##########################################################################
  # 5. No nearby neighbours, no culture spread
  ##########################################################################
  model = Sugarscape.sugarscape(; dims=(5, 5), N=0, seed=rng_seed,
    enable_culture=true, culture_tag_length=1,
    vision_dist=(1, 1), metabolic_rate_dist=(0, 0), initial_sugar_dist=(0, 0))
  model.sugar_values .= 0.0

  f = add_custom_agent!(model, (3, 3); sugar=0, culture_bits=[true])

  neighbors = [
    add_custom_agent!(model, (2, 1); sugar=0, culture_bits=[false]),
    add_custom_agent!(model, (5, 3); sugar=0, culture_bits=[false]),
  ]
  Sugarscape.culture_spread!(f, model)
  @test log_test_step("No neighbors updated culture", all(n.culture[1] == false for n in neighbors), true, all(n.culture[1] == false for n in neighbors))
end

################################################################################
# Combat Rule (Cα) – Specification Conformance Tests
################################################################################

@testset "Combat Rule (Cα)" begin
  rng_seed = 0x20240622

  ##########################################################################
  # 1. Cannot attack same-tribe target
  ##########################################################################
  model = Sugarscape.sugarscape(; dims=(5, 5), N=0, seed=rng_seed,
    enable_combat=true, enable_culture=false,
    culture_tag_length=3, combat_limit=50,
    vision_dist=(3, 3), metabolic_rate_dist=(1, 1),
    initial_sugar_dist=(5, 5), growth_rate=0)
  model.sugar_values .= 0.0

  attacker = add_custom_agent!(model, (2, 2); sugar=10, culture_bits=[false, false, true], metabolism=1)  # blue, metabolism 1
  victim = add_custom_agent!(model, (4, 2); sugar=5, culture_bits=[false, true, false], vision=0, metabolism=1)   # red but stronger, cannot see attacker

  Sugarscape.combat!(model)

  # Both agents should still exist, no sugar stolen
  @test length(allagents(model)) == 2
  @test attacker.sugar == 10  # unchanged
  @test victim.sugar == 5

  ##########################################################################
  # 2. Cannot attack stronger other-tribe target
  ##########################################################################
  model = Sugarscape.sugarscape(; dims=(5, 5), N=0, seed=rng_seed,
    enable_combat=true, enable_culture=false,
    culture_tag_length=3, combat_limit=50,
    vision_dist=(3, 3), metabolic_rate_dist=(1, 1),
    initial_sugar_dist=(5, 5), growth_rate=0)
  model.sugar_values .= 0.0

  attacker = add_custom_agent!(model, (2, 2); sugar=5, culture_bits=[false, false, true], vision=3, metabolism=1)   # blue
  victim = add_custom_agent!(model, (4, 2); sugar=10, culture_bits=[true, true, false], vision=0, metabolism=1)    # red but stronger, cannot see attacker

  Sugarscape.combat!(model)

  @test length(allagents(model)) == 2  # nobody killed
  @test attacker.sugar == 5            # unchanged

  ##########################################################################
  # 3. Successful attack on weaker other-tribe target
  ##########################################################################
  model = Sugarscape.sugarscape(; dims=(5, 5), N=0, seed=rng_seed,
    enable_combat=true, enable_culture=false,
    culture_tag_length=3, combat_limit=50,
    vision_dist=(3, 3), metabolic_rate_dist=(1, 1),
    initial_sugar_dist=(5, 5), growth_rate=0)
  model.sugar_values .= 0.0

  # Place sugar at victim location for additional reward
  model.sugar_values[4, 2] = 4.0

  attacker = add_custom_agent!(model, (2, 2); sugar=10, culture_bits=[false, false, true], metabolism=1)  # blue, metabolism 1
  victim = add_custom_agent!(model, (4, 2); sugar=6, culture_bits=[true, true, false], metabolism=1)   # red, weaker, metabolism 1

  pre_kills = model.combat_kills

  Sugarscape.combat!(model)

  @test model.combat_kills == pre_kills + 1
  @test length(allagents(model)) == 1                       # victim removed

  atk = first(allagents(model))
  expected_sugar = 10 + 6 + 4 - 1  # initial + stolen + site - metabolism
  @test isapprox(atk.sugar, expected_sugar; atol=1e-8)
  @test atk.pos == (4, 2)            # moved into victim site
end

################################################################################
# Credit Rule (Ldr) – Specification Conformance Tests
################################################################################

@testset "Credit Rule (Ldr)" begin

  ##########################################################################
  # 1. Loan creation between neighbours (eligibility + transfer)
  ##########################################################################
  model = Sugarscape.sugarscape(; dims=(3, 3), N=0, seed=rng_seed,
    enable_credit=true, interest_rate=0.0,
    duration=10, growth_rate=0,
    vision_dist=(1, 1), metabolic_rate_dist=(0, 0), initial_sugar_dist=(25, 25), use_llm_decisions=true)
  model.sugar_values .= 0.0

  # Lender: post-fertility male, 40 sugar → may lend half (20)
  lender = add_custom_agent!(model, (2, 2); sugar=40, sex=:male, age=55, initial_sugar=40)
  # Borrower: fertile female with insufficient sugar (10), needs 15
  borrower = add_custom_agent!(model, (2, 3); sugar=10, sex=:female, age=25, initial_sugar=25)

  @test log_test_step("Initial loans empty", isempty(lender.loans_given) && isempty(borrower.loans_owed), true, isempty(lender.loans_given) && isempty(borrower.loans_owed))

  # Manually trigger credit logic for the borrower, who should find the lender
  Sugarscape.credit!(borrower, model)

  # A loan of 15 should be created
  @test log_test_step("Lender has given a loan to borrower", haskey(lender.loans_given, borrower.id), true, haskey(lender.loans_given, borrower.id))
  @test log_test_step("Borrower has loans owed", haskey(borrower.loans_owed, lender.id), true, haskey(borrower.loans_owed, lender.id))
  loan = first(lender.loans_given[borrower.id])
  @test log_test_step("Loan principal amount is correct", loan.amount == 15, 15, loan.amount)
  @test log_test_step("Loan due time is correct", loan.time_due == abmtime(model) + 10, abmtime(model) + 10, loan.time_due)
  @test log_test_step("Lender sugar after loan creation", lender.sugar == 25, 25, lender.sugar)
  @test log_test_step("Borrower sugar after loan creation", borrower.sugar == 25, 25, borrower.sugar)

  ##########################################################################
  # 2. Repayment at due date (full repayment, zero interest)
  ##########################################################################
  no_op_agent!(agent, model) = nothing
  no_op_model!(model) = nothing
  # Advance the model time to the loan due date
  step!(model,
    no_op_agent!,    # skip every agent
    no_op_model!,    # skip any model-level logic
    loan.time_due - abmtime(model))
  borrower.sugar = 30 # Ensure enough sugar to repay
  Sugarscape.attempt_pay_loans!(borrower, model)
  @test log_test_step("Borrower's loans cleared after repayment", !haskey(borrower.loans_owed, lender.id) || isempty(borrower.loans_owed[lender.id]), true, !haskey(borrower.loans_owed, lender.id) || isempty(borrower.loans_owed[lender.id]))
  @test log_test_step("Lender's loans cleared after repayment", !haskey(lender.loans_given, borrower.id) || isempty(lender.loans_given[borrower.id]), true, !haskey(lender.loans_given, borrower.id) || isempty(lender.loans_given[borrower.id]))
  @test log_test_step("Lender sugar after repayment", lender.sugar == 40, 40, lender.sugar)
  @test log_test_step("Borrower sugar after repayment", borrower.sugar == 15, 15, borrower.sugar)

  ##########################################################################
  # 3. Loan forgiven when lender dies before due date
  ##########################################################################
  # Re-issue a loan
  Sugarscape.make_loan!(lender, borrower, 15.0, model)
  @test log_test_step("Borrower has loans owing after issuing new loan", haskey(borrower.loans_owed, lender.id), true, haskey(borrower.loans_owed, lender.id))
  # Kill lender, which should trigger clear_loans_on_death!
  Sugarscape.clear_loans_on_death!(lender, model)
  remove_agent!(lender, model)
  @test log_test_step("Borrower's debt cleared when lender dies", !haskey(borrower.loans_owed, lender.id), true, !haskey(borrower.loans_owed, lender.id))
end


@testset "Credit Rule (Ldr) – LLM-Driven Scenarios" begin

  ##########################################################################
  # 1. LLM Borrower Decision Acceptance
  ##########################################################################
  model = Sugarscape.sugarscape(; dims=(3, 3), N=0, seed=rng_seed,
    enable_credit=true, interest_rate=0.0, duration=5, growth_rate=0,
    vision_dist=(1, 1), metabolic_rate_dist=(0, 0), initial_sugar_dist=(0, 0), use_llm_decisions=true)
  model.sugar_values .= 0.0
  lender = add_custom_agent!(model, (2, 2); sugar=20, sex=:male, age=60, initial_sugar=20)
  # Give borrower a small positive sugar to ensure positive income, and set initial_sugar so they need 10
  borrower = add_custom_agent!(model, (2, 3); sugar=1, sex=:female, age=25, initial_sugar=11)

  # Use actual LLM to decide borrow: model will call get_credit_borrower_decision

  Sugarscape.credit!(borrower, model)
  @test log_test_step("Loan created for borrower", haskey(borrower.loans_owed, lender.id), true)
  loan = first(borrower.loans_owed[lender.id])
  # Borrower should receive 10 units to reach initial_sugar=11
  @test log_test_step("Borrower sugar increased", borrower.sugar == 11.0, 11.0, borrower.sugar)
  @test log_test_step("Lender sugar decreased", lender.sugar == 10.0, 10.0, lender.sugar)


  ##########################################################################
  # 2. LLM Lender Decision Acceptance
  ##########################################################################
  model = Sugarscape.sugarscape(; dims=(3, 3), N=0, seed=rng_seed,
    enable_credit=true, interest_rate=0.0, duration=5, growth_rate=0,
    vision_dist=(1, 1), metabolic_rate_dist=(0, 0), initial_sugar_dist=(0, 0), use_llm_decisions=true)
  model.sugar_values .= 0.0
  lender = add_custom_agent!(model, (2, 2); sugar=30, sex=:male, age=60, initial_sugar=30)
  borrower = add_custom_agent!(model, (2, 3); sugar=5, sex=:female, age=25, initial_sugar=15)

  # Use actual LLM to decide lend: model will call get_credit_lender_decision

  Sugarscape.credit!(lender, model)
  @test log_test_step("Loan created by lender", haskey(lender.loans_given, borrower.id), true)
  loan = first(lender.loans_given[borrower.id])
  @test log_test_step("Lender sugar decreased", lender.sugar == 20.0, 20.0, lender.sugar)
  @test log_test_step("Borrower sugar increased", borrower.sugar == 15.0, 15.0, borrower.sugar)


  # ##########################################################################
  # # 3. LLM Prioritization of Multiple Borrowers
  # ##########################################################################
  # model = Sugarscape.sugarscape(; dims=(3, 3), N=0, seed=rng_seed,
  #   enable_credit=true, interest_rate=0.0, duration=5, growth_rate=0,
  #   vision_dist=(1, 1), metabolic_rate_dist=(0, 0), initial_sugar_dist=(0, 0), use_llm_decisions=true)
  # model.sugar_values .= 0.0
  # lender = add_custom_agent!(model, (2, 2); sugar=50, sex=:male, age=60, initial_sugar=50)
  # b1 = add_custom_agent!(model, (2, 1); sugar=1, initial_sugar=10, sex=:female, age=25)
  # b2 = add_custom_agent!(model, (2, 3); sugar=1, initial_sugar=10, sex=:female, age=25)

  # # Use actual LLM to decide borrower prioritization; credit! invokes get_credit_lender_decision

  # Sugarscape.credit!(lender, model)
  # ids = collect(keys(lender.loans_given))
  # @test log_test_step("Loans created in LLM order", ids == [b2.id, b1.id], [b2.id, b1.id], ids)


  # ##########################################################################
  # # 4. LLM Prioritization of Multiple Lenders
  # ##########################################################################
  # model = Sugarscape.sugarscape(; dims=(3, 3), N=0, seed=rng_seed,
  #   enable_credit=true, interest_rate=0.0, duration=5, growth_rate=0,
  #   vision_dist=(1, 1), metabolic_rate_dist=(0, 0), initial_sugar_dist=(0, 0), use_llm_decisions=true)
  # model.sugar_values .= 0.0
  # l1 = add_custom_agent!(model, (1, 2); sugar=20, initial_sugar=20)
  # l2 = add_custom_agent!(model, (3, 2); sugar=20, initial_sugar=20)
  # borrower = add_custom_agent!(model, (2, 2); sugar=1, initial_sugar=30, sex=:female, age=25)

  # # Use actual LLM to decide lender prioritization; credit! invokes get_credit_borrower_decision

  # Sugarscape.credit!(borrower, model)
  # from_ids = collect(keys(borrower.loans_owed))
  # @test log_test_step("Borrower loans taken in LLM order", from_ids == [l1.id, l2.id], [l1.id, l2.id], from_ids)

  ##########################################################################
  # 5. LLM Multiple Loans Given by Single Lender
  ##########################################################################
  model = Sugarscape.sugarscape(; dims=(5, 5), N=0, seed=rng_seed,
    enable_credit=true, interest_rate=0.0, duration=5, growth_rate=0,
    vision_dist=(2, 2), metabolic_rate_dist=(0, 0), initial_sugar_dist=(0, 0), use_llm_decisions=true)
  model.sugar_values .= 0.0

  # One wealthy lender with enough sugar to lend to multiple borrowers
  lender = add_custom_agent!(model, (3, 3); sugar=100, sex=:male, age=60, initial_sugar=100)

  # Multiple borrowers in need within lender's vision
  b1 = add_custom_agent!(model, (2, 3); sugar=2, initial_sugar=12, sex=:female, age=25)
  b2 = add_custom_agent!(model, (4, 3); sugar=3, initial_sugar=13, sex=:female, age=30)
  b3 = add_custom_agent!(model, (3, 2); sugar=1, initial_sugar=11, sex=:male, age=20)

  initial_lender_sugar = lender.sugar

  # Trigger credit decision for lender who should evaluate all potential borrowers
  Sugarscape.credit!(lender, model)

  # Count how many loans were actually given
  total_loans_given = sum(length(loans) for loans in values(lender.loans_given))
  total_borrowers_served = length(lender.loans_given)

  @test log_test_step("Lender gave multiple loans", total_loans_given >= 2, ">=2", total_loans_given)
  @test log_test_step("Lender served multiple borrowers", total_borrowers_served >= 2, ">=2", total_borrowers_served)
  @test log_test_step("Lender sugar decreased after multiple loans", lender.sugar < initial_lender_sugar, true, lender.sugar < initial_lender_sugar)

  ##########################################################################
  # 6. LLM Multiple Loans Taken by Single Borrower
  ##########################################################################
  model = Sugarscape.sugarscape(; dims=(5, 5), N=0, seed=rng_seed,
    enable_credit=true, interest_rate=0.0, duration=5, growth_rate=0,
    vision_dist=(2, 2), metabolic_rate_dist=(0, 0), initial_sugar_dist=(0, 0), use_llm_decisions=true)
  model.sugar_values .= 0.0

  # Multiple potential lenders within borrower's vision
  l1 = add_custom_agent!(model, (2, 3); sugar=30, initial_sugar=30, sex=:male, age=55)
  l2 = add_custom_agent!(model, (4, 3); sugar=25, initial_sugar=25, sex=:male, age=60)
  l3 = add_custom_agent!(model, (3, 2); sugar=35, initial_sugar=35, sex=:female, age=50)

  # One borrower with high sugar needs (large gap between current and initial sugar)
  borrower = add_custom_agent!(model, (3, 3); sugar=5, initial_sugar=50, sex=:female, age=25)

  initial_borrower_sugar = borrower.sugar

  # Trigger credit decision for borrower who should evaluate all potential lenders
  Sugarscape.credit!(borrower, model)

  # Count how many loans were actually taken
  total_loans_taken = sum(length(loans) for loans in values(borrower.loans_owed))
  total_lenders_used = length(borrower.loans_owed)

  @test log_test_step("Borrower took multiple loans", total_loans_taken >= 2, ">=2", total_loans_taken)
  @test log_test_step("Borrower borrowed from multiple lenders", total_lenders_used >= 2, ">=2", total_lenders_used)
  @test log_test_step("Borrower sugar increased after multiple loans", borrower.sugar > initial_borrower_sugar, true, borrower.sugar > initial_borrower_sugar)

end
