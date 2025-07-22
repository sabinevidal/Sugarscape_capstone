using Test
using Random
using Sugarscape
using Agents
using Agents: remove_agent!

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
attributes so that tests remain deterministic and self-contained. Keyword
arguments default to sensible values but can be overridden per test.
"""
function add_custom_agent!(model, pos; sugar, initial_sugar=sugar, vision=2, metabolism=0, sex=:male,
  age=0, max_age=100, culture_bits=[false],
  has_reproduced=false)

  initial_sugar = initial_sugar
  children = Int[]
  total_inheritance_received = 0.0
  culture = BitVector(culture_bits)
  diseases = BitVector[]
  immunity = falses(model.disease_immunity_length)
  loans_given = Dict{Int,Vector{Sugarscape.Loan}}()
  loans_owed = Dict{Int,Vector{Sugarscape.Loan}}()

  return add_agent!(pos, SugarscapeAgent, model, vision, metabolism, sugar, age,
    max_age, sex, has_reproduced, initial_sugar, children,
    total_inheritance_received, culture, loans_given, loans_owed,
    diseases, immunity)
end

# Seed for deterministic behaviour across all tests in this set
rng_seed = 0x20240622

################################################################################
# Movement Rule (M) – Specification Conformance Tests
################################################################################

@testset "Movement Rule (M)" begin

  ##########################################################################
  # 1. Moves to the max-sugar site within vision
  ##########################################################################
  model = Sugarscape.sugarscape(; dims=(5, 5), N=0, seed=rng_seed,
    growth_rate=0,                      # disable growback
    vision_dist=(2, 2),                 # deterministic vision
    metabolic_rate_dist=(0, 0),         # no metabolism for clarity
    initial_sugar_dist=(0, 0))                     # start with zero sugar

  model.sugar_values .= 0.0        # blank slate

  # Place a high-sugar site north (within vision=2)
  model.sugar_values[3, 5] = 10.0  # grid is (x, y)
  model.sugar_values[1, 3] = 8.0   # another site, lower sugar

  agent_pos = (3, 3)
  add_custom_agent!(model, agent_pos; sugar=0, vision=2, metabolism=0)
  agent = first(allagents(model))

  Sugarscape.movement!(agent, model)

  @test agent.pos == (3, 5)                     # moved to max-sugar site
  @test agent.sugar == 10.0                     # collected all sugar
  @test model.sugar_values[3, 5] == 0.0         # site depleted

  ##########################################################################
  # 2. Tie-breaking by distance (prefer nearer of equal sugar)
  ##########################################################################
  model = Sugarscape.sugarscape(; dims=(7, 7), N=0, seed=rng_seed,
    growth_rate=0, vision_dist=(3, 3), metabolic_rate_dist=(0, 0), initial_sugar_dist=(0, 0))
  model.sugar_values .= 0.0

  agent_pos = (4, 4)
  # Two sites with identical sugar within vision: one distance 1, another distance 3
  model.sugar_values[5, 4] = 9.0   # east, distance 1
  model.sugar_values[1, 4] = 9.0   # far west, distance 3

  add_custom_agent!(model, agent_pos; sugar=0, vision=3, metabolism=0)
  agent = first(allagents(model))

  Sugarscape.movement!(agent, model)

  @test agent.pos == (5, 4)                     # chose closer site

  ##########################################################################
  # 3. Tie-breaking by random choice among equal sugar & equal distance
  ##########################################################################
  model = Sugarscape.sugarscape(; dims=(7, 7), N=0, seed=rng_seed,
    growth_rate=0, vision_dist=(2, 2), metabolic_rate_dist=(0, 0), initial_sugar_dist=(0, 0))
  model.sugar_values .= 0.0

  agent_pos = (4, 4)
  model.sugar_values[4, 6] = 5.0   # north (distance 2)
  model.sugar_values[6, 4] = 5.0   # east  (distance 2)

  add_custom_agent!(model, agent_pos; sugar=0, vision=2, metabolism=0)
  agent = first(allagents(model))

  Sugarscape.movement!(agent, model)

  # With fixed seed, the RNG should make the choice deterministic. Expected outcome
  expected_pos = (4, 6)   # empirically true for rng_seed above; update if implementation changes
  @test agent.pos == expected_pos

  ##########################################################################
  # 4. No move if all neighbouring sites are occupied (must stay put)
  ##########################################################################
  model = Sugarscape.sugarscape(; dims=(5, 5), N=0, seed=rng_seed,
    growth_rate=0, vision_dist=(1, 1), metabolic_rate_dist=(0, 0), initial_sugar_dist=(0, 0))
  model.sugar_values .= 0.0

  focal_pos = (3, 3)
  focal_agent = add_custom_agent!(model, focal_pos; sugar=0, vision=1, metabolism=0)

  # Surround focal agent with blockers at the four von-Neumann neighbours
  for pos in ((3, 4), (3, 2), (2, 3), (4, 3))
    add_custom_agent!(model, pos; sugar=0, vision=1, metabolism=0)
  end

  Sugarscape.movement!(focal_agent, model)

  @test log_test_step("Focal agent cannot move", focal_agent.pos == focal_pos, focal_pos, focal_agent.pos)

  ##########################################################################
  # 5. Multiple agents move to valid spots
  ##########################################################################
  model = Sugarscape.sugarscape(; dims=(7, 7), N=0, seed=rng_seed,
    growth_rate=0, vision_dist=(2, 2), metabolic_rate_dist=(0, 0), initial_sugar_dist=(0, 0))
  model.sugar_values .= 0.0

  # Create multiple sugar sites with different values
  model.sugar_values[2, 2] = 15.0  # highest sugar
  model.sugar_values[4, 4] = 12.0  # medium sugar
  model.sugar_values[6, 6] = 8.0   # lower sugar
  model.sugar_values[1, 1] = 10.0  # another site

  # Place agents at different starting positions
  agent1_pos = (3, 3)  # should move to (2, 2)
  agent2_pos = (5, 5)  # should move to (4, 4)
  agent3_pos = (1, 3)  # should move to (1, 1)

  agent1 = add_custom_agent!(model, agent1_pos; sugar=0, vision=2, metabolism=0)
  agent2 = add_custom_agent!(model, agent2_pos; sugar=0, vision=2, metabolism=0)
  agent3 = add_custom_agent!(model, agent3_pos; sugar=0, vision=2, metabolism=0)

  agents = [agent1, agent2, agent3]
  @test length(agents) == 3

  # Move each agent according to the standard M-rule
  for ag in agents
    Sugarscape.movement!(ag, model)
  end

  # Expected destinations
  @test agent1.pos == (2, 2)
  @test agent2.pos == (4, 4)
  @test agent3.pos == (1, 1)

  # Expected sugar collection (metabolism = 0)
  @test agent1.sugar == 15.0
  @test agent2.sugar == 12.0
  @test agent3.sugar == 10.0

  # Sugar sites depleted
  @test model.sugar_values[2, 2] == 0.0
  @test model.sugar_values[4, 4] == 0.0
  @test model.sugar_values[1, 1] == 0.0

  # No collisions – all agents occupy unique sites
  positions = [agent1.pos, agent2.pos, agent3.pos]
  @test length(unique(positions)) == 3
end

################################################################################
# Reproduction Rule (S) – Specification Conformance Tests
################################################################################

@testset "Reproduction Rule (S)" begin

  ##########################################################################
  # 1. Successful reproduction with opposite sex, fertility & empty cell
  ##########################################################################
  model = Sugarscape.sugarscape(; dims=(5, 5), N=0, seed=rng_seed,
    enable_reproduction=true, growth_rate=0,
    vision_dist=(1, 1), metabolic_rate_dist=(0, 0),
    initial_sugar_dist=(20, 20))  # fixed initial sugar

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
  model = Sugarscape.sugarscape(; dims=(3, 3), N=0, seed=rng_seed,
    enable_reproduction=true, growth_rate=0,
    vision_dist=(1, 1), metabolic_rate_dist=(0, 0),
    initial_sugar_dist=(20, 20))
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
  # 3. Reproduced with max_partners or less
  ##########################################################################
  model = Sugarscape.sugarscape(; dims=(5, 5), N=0, seed=rng_seed,
    enable_reproduction=true, growth_rate=0,
    vision_dist=(1, 1), metabolic_rate_dist=(0, 0),
    initial_sugar_dist=(20, 20))
  model.sugar_values .= 0.0

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

  ##########################################################################
  # 3. No eligible partners for reproduction
  ##########################################################################
  model = Sugarscape.sugarscape(; dims=(5, 5), N=0, seed=rng_seed,
    enable_reproduction=true, growth_rate=0,
    vision_dist=(1, 1), metabolic_rate_dist=(0, 0),
    initial_sugar_dist=(20, 20))
  model.sugar_values .= 0.0

  # Place fertile female at centre
  focal_agent = add_custom_agent!(model, (3, 3); sugar=15, initial_sugar=5, sex=:female, age=25, culture_bits=[true])

  # 4 surrounding agents, all not fertile
  for pos in ((2, 3), (3, 2), (4, 3), (3, 4))
    isempty(pos, model) || continue
    add_custom_agent!(model, pos; sugar=20, sex=:male, age=5, culture_bits=[false])
  end

  @test log_test_step("Number of agents before reproduction", nagents(model) == 5, 5, nagents(model))

  Sugarscape.reproduction!(focal_agent, model)

  @test log_test_step("Number of agents after reproduction", nagents(model) == 5, 5, nagents(model))

end

################################################################################
# Inheritance Rule (I) – Specification Conformance Tests
################################################################################

@testset "Inheritance Rule (I)" begin

  ##########################################################################
  # 1. Wealth split equally among living children
  ##########################################################################
  model = Sugarscape.sugarscape(; dims=(5, 5), N=0, seed=rng_seed,
    enable_reproduction=true,  # inheritance active
    growth_rate=0, vision_dist=(1, 1), metabolic_rate_dist=(0, 0), initial_sugar_dist=(0, 0))

  # Create two children first so their IDs are lower than the parent's ID
  child1 = add_custom_agent!(model, (2, 2); sugar=0, age=5)
  child2 = add_custom_agent!(model, (2, 3); sugar=0, age=5)

  # Create parent with sugar to inherit
  parent = add_custom_agent!(model, (3, 3); sugar=20, age=60, max_age=60)
  parent.children = [child1.id, child2.id]

  # Check pre-conditions
  @test child1.sugar == 0.0 && child2.sugar == 0.0

  Sugarscape.death!(parent, model, :age)  # triggers inheritance

  # Each child gets floor(20 / 2) = 10
  @test isapprox(child1.sugar, 10.0; atol=1e-8)
  @test isapprox(child2.sugar, 10.0; atol=1e-8)

  # Parent removed from model
  @test !hasid(model, parent.id)

  # Model metrics updated
  @test model.total_inheritances == 2
  @test model.total_inheritance_value == 20.0
  @test model.generational_wealth_transferred == 20.0

  ##########################################################################
  # 2. Only living children inherit (one child dies before parent)
  ##########################################################################
  model = Sugarscape.sugarscape(; dims=(5, 5), N=0, seed=rng_seed,
    enable_reproduction=true, growth_rate=0,
    vision_dist=(1, 1), metabolic_rate_dist=(0, 0), initial_sugar_dist=(0, 0))

  childA = add_custom_agent!(model, (1, 1); sugar=0, age=5)
  childB = add_custom_agent!(model, (1, 2); sugar=0, age=5)
  parent = add_custom_agent!(model, (1, 3); sugar=20, age=60, max_age=60)
  parent.children = [childA.id, childB.id]

  # Kill childB first so it's not alive when parent dies
  Sugarscape.death!(childB, model, :starvation)

  Sugarscape.death!(parent, model, :age)

  # Only childA should inherit the whole 20
  @test hasid(model, childA.id)
  @test isapprox(childA.sugar, 20.0; atol=1e-8)

  # childB removed, so cannot be in model
  @test !hasid(model, childB.id)
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
    vision_dist=(1, 1), metabolic_rate_dist=(0, 0), initial_sugar_dist=(0, 0))
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
    growth_rate=0, vision_dist=(1, 1), metabolic_rate_dist=(0, 0), initial_sugar_dist=(0, 0))
  model.sugar_values .= 0.0

  c1 = add_custom_agent!(model, (1, 1); sugar=0, culture_bits=[true])
  c2 = add_custom_agent!(model, (1, 2); sugar=0, culture_bits=[true])

  Sugarscape.culture_spread!(c1, model)

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
    vision_dist=(1, 1), metabolic_rate_dist=(0, 0), initial_sugar_dist=(0, 0))
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
  @test log_test_step("Changed culture tag matches d1", d2.culture[idx] == d1.culture[idx], true, d2.culture[idx] == d1.culture[idx])

  ##########################################################################
  # 5. All neighbours update
  ##########################################################################
  model = Sugarscape.sugarscape(; dims=(3, 3), N=0, seed=rng_seed,
    enable_culture=true, culture_tag_length=1,
    vision_dist=(1, 1), metabolic_rate_dist=(0, 0), initial_sugar_dist=(0, 0))
  model.sugar_values .= 0.0

  e = add_custom_agent!(model, (2, 2); sugar=0, culture_bits=[true])

  neighbors = [
    add_custom_agent!(model, (2, 1); sugar=0, culture_bits=[false]),
    add_custom_agent!(model, (2, 3); sugar=0, culture_bits=[false]),
    add_custom_agent!(model, (1, 2); sugar=0, culture_bits=[false]),
    add_custom_agent!(model, (3, 2); sugar=0, culture_bits=[false])
  ]
  Sugarscape.culture_spread!(e, model)
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

  # ##########################################################################
  # # 1. Loan creation between neighbours (eligibility + transfer)
  # ##########################################################################
  model = Sugarscape.sugarscape(; dims=(3, 3), N=0, seed=rng_seed,
    enable_credit=true, interest_rate=0.0,
    duration=10, growth_rate=0,
    vision_dist=(1, 1), metabolic_rate_dist=(0, 0), initial_sugar_dist=(25, 25))
  model.sugar_values .= 0.0

  # Lender: post-fertility male, 40 sugar → may lend half (20)
  lender = add_custom_agent!(model, (2, 2); sugar=40, sex=:male, age=55, initial_sugar=40)
  # Borrower: fertile female with insufficient sugar (10), needs 15
  borrower = add_custom_agent!(model, (2, 3); sugar=10, sex=:female, age=25, initial_sugar=25)

  @test isempty(lender.loans_given) && isempty(borrower.loans_owed)

  # Manually trigger credit logic for the borrower, who should find the lender
  Sugarscape.credit!(borrower, model)

  # A loan of 15 should be created
  @test haskey(lender.loans_given, borrower.id)
  @test haskey(borrower.loans_owed, lender.id)
  loan = first(lender.loans_given[borrower.id])
  @test loan.amount == 15                 # principal
  @test loan.time_due == abmtime(model) + 10  # due tick
  @test lender.sugar == 25                # 40 − 15
  @test borrower.sugar == 25              # 10 + 15

  ##########################################################################
  # 2. Repayment at due date (full repayment, zero interest)
  ##########################################################################
  # Advance the model time to the loan due date
  step!(model, loan.time_due - abmtime(model))
  borrower.sugar = 30 # Ensure enough sugar to repay
  Sugarscape.attempt_pay_loans!(borrower, model)
  @test !haskey(borrower.loans_owed, lender.id) || isempty(borrower.loans_owed[lender.id])
  @test !haskey(lender.loans_given, borrower.id) || isempty(lender.loans_given[borrower.id])
  @test lender.sugar == 40                # got 15 back
  @test borrower.sugar == 15              # paid 15 back

  ##########################################################################
  # 3. Loan forgiven when lender dies before due date
  ##########################################################################
  # Re-issue a loan
  Sugarscape.make_loan!(lender, borrower, 15.0, model)
  @test haskey(borrower.loans_owed, lender.id)
  # Kill lender, which should trigger clear_loans_on_death!
  Sugarscape.clear_loans_on_death!(lender, model)
  remove_agent!(lender, model)
  # Borrower's debt should be cleared
  @test !haskey(borrower.loans_owed, lender.id)
end

@testset "Credit Rule (Ldr) - Advanced Scenarios" begin
  rng_seed = 0x20240622

  ##########################################################################
  # 4. Partial Repayment and Rollover
  ##########################################################################
  model = Sugarscape.sugarscape(; dims=(3, 3), N=0, seed=rng_seed,
    enable_credit=true, interest_rate=0.1, duration=10,
    growth_rate=0, vision_dist=(1, 1), metabolic_rate_dist=(0, 0),
    initial_sugar_dist=(0, 0))
  model.sugar_values .= 0.0

  lender = add_custom_agent!(model, (2, 2); sugar=50, sex=:male, age=55)
  borrower = add_custom_agent!(model, (2, 3); sugar=10, sex=:female, age=25)

  Sugarscape.make_loan!(lender, borrower, 20.0, model)
  borrower.sugar = 10 # Not enough to repay 20 * 1.1 = 22

  step!(model, 10) # Advance time to due date
  Sugarscape.attempt_pay_loans!(borrower, model)

  @test borrower.sugar == 5.0 # Paid half of wealth (10 / 2)
  @test lender.sugar == 55.0 # Received 5
  @test length(borrower.loans_owed[lender.id]) == 1
  new_loan = first(borrower.loans_owed[lender.id])
  @test new_loan.amount ≈ 17.0 # Rollover amount 22 - 5
  @test new_loan.time_due == 20 # New due date

  ##########################################################################
  # 5. Loan Inheritance on Lender Death
  ##########################################################################
  model = Sugarscape.sugarscape(; dims=(3, 3), N=0, seed=rng_seed,
    enable_credit=true, enable_reproduction=true, interest_rate=0.0,
    duration=10, growth_rate=0, vision_dist=(1, 1),
    metabolic_rate_dist=(0, 0), initial_sugar_dist=(0, 0))
  model.sugar_values .= 0.0

  lender = add_custom_agent!(model, (1, 1); sugar=50, sex=:male, age=55)
  borrower = add_custom_agent!(model, (1, 2); sugar=10, sex=:female, age=25)
  heir = add_custom_agent!(model, (3, 3); sugar=0, sex=:female, age=1)
  lender.children = [heir.id]

  Sugarscape.make_loan!(lender, borrower, 15.0, model)
  Sugarscape.clear_loans_on_death!(lender, model)
  remove_agent!(lender, model)

  @test !hasid(model, lender.id)
  @test haskey(borrower.loans_owed, heir.id)
  @test length(borrower.loans_owed[heir.id]) == 1
  @test haskey(heir.loans_given, borrower.id)
  @test length(heir.loans_given[borrower.id]) == 1
  @test first(heir.loans_given[borrower.id]).amount == 15.0

  ##########################################################################
  # 6. Multiple Loans Repayment
  ##########################################################################
  model = Sugarscape.sugarscape(; dims=(3, 3), N=0, seed=rng_seed,
    enable_credit=true, interest_rate=0.0, duration=5,
    growth_rate=0, vision_dist=(1, 1), metabolic_rate_dist=(0, 0),
    initial_sugar_dist=(0, 0))
  model.sugar_values .= 0.0

  lender1 = add_custom_agent!(model, (1, 1); sugar=50, sex=:male, age=55)
  lender2 = add_custom_agent!(model, (1, 2); sugar=50, sex=:male, age=55)
  borrower = add_custom_agent!(model, (2, 2); sugar=50, sex=:female, age=25)

  Sugarscape.make_loan!(lender1, borrower, 10.0, model)
  Sugarscape.make_loan!(lender2, borrower, 15.0, model)

  step!(model, 5)
  Sugarscape.attempt_pay_loans!(borrower, model)

  @test borrower.sugar == 25.0 # 50 - 10 - 15
  @test lender1.sugar == 60.0
  @test lender2.sugar == 65.0
  @test isempty(borrower.loans_owed)

  ##########################################################################
  # 7. No lending if fertile and no excess income
  ##########################################################################
  model = Sugarscape.sugarscape(; dims=(3, 3), N=0, seed=rng_seed)
  agent = add_custom_agent!(model, (1, 1); sugar=10, metabolism=10, sex=:female, age=25, initial_sugar=10)
  can_lend_result = Sugarscape.can_lend(agent, model)
  @test !can_lend_result.can_lend

  ##########################################################################
  # 8. Lending if not fertile
  ##########################################################################
  model = Sugarscape.sugarscape(; dims=(3, 3), N=0, seed=rng_seed)
  agent = add_custom_agent!(model, (1, 1); sugar=50, sex=:male, age=80, initial_sugar=50)
  can_lend_result = Sugarscape.can_lend(agent, model)
  @test can_lend_result.can_lend
  @test can_lend_result.max_amount == 25.0

  ##########################################################################
  # 9. No borrowing if has enough sugar
  ##########################################################################
  model = Sugarscape.sugarscape(; dims=(3, 3), N=0, seed=rng_seed)
  agent = add_custom_agent!(model, (1, 1); sugar=30, initial_sugar=25, sex=:female, age=30)
  will_borrow_result = Sugarscape.will_borrow(agent, model)
  @test !will_borrow_result.will_borrow

  ##########################################################################
  # 10. No borrowing if no lenders available
  ##########################################################################
  model = Sugarscape.sugarscape(; dims=(3, 3), N=0, seed=rng_seed)
  borrower = add_custom_agent!(model, (2, 2); sugar=10, initial_sugar=25, sex=:female, age=25)
  pre_sugar = borrower.sugar
  neighbours = nearby_agents(borrower, model)

  Sugarscape.attempt_borrow!(borrower, model, 15.0, neighbours)
  @test borrower.sugar == pre_sugar # No change as no neighbours to lend

  ##########################################################################
  # 11. No lending if no borrowers available
  ##########################################################################
  model = Sugarscape.sugarscape(; dims=(3, 3), N=0, seed=rng_seed)
  lender = add_custom_agent!(model, (2, 2); sugar=50, sex=:male, age=55, initial_sugar=50)
  pre_sugar = lender.sugar
  neighbours = nearby_agents(lender, model)

  Sugarscape.attempt_lend!(lender, model, 25.0, neighbours)
  @test lender.sugar == pre_sugar # No change as no neighbours to borrow
end

################################################################################
# Disease Rule (E) – Specification Conformance Tests
################################################################################

@testset "Disease Rule (E)" begin

  # Helper disease bitvector
  disease = BitVector([true, false, true])

  ##########################################################################
  # 1. Immunity substring – no sugar penalty
  ##########################################################################
  model = Sugarscape.sugarscape(; dims=(3, 3), N=0, seed=rng_seed,
    enable_disease=true, disease_immunity_length=6,
    growth_rate=0, vision_dist=(1, 1), metabolic_rate_dist=(0, 0), initial_sugar_dist=(0, 0))

  immune_bits = BitVector([false, true, false, true, false, true])   # disease is subseq
  ag = add_custom_agent!(model, (2, 2); sugar=20)
  ag.immunity = copy(immune_bits)
  push!(ag.diseases, disease)

  Sugarscape.immune_response!(model)
  @test ag.sugar == 20                       # no penalty

  ##########################################################################
  # 2. Immune response flips bit when not immune (penalty once)
  ##########################################################################
  model = Sugarscape.sugarscape(; dims=(3, 3), N=0, seed=rng_seed,
    enable_disease=true, disease_immunity_length=6,
    growth_rate=0, vision_dist=(1, 1), metabolic_rate_dist=(0, 0), initial_sugar_dist=(0, 0))

  ag = add_custom_agent!(model, (2, 2); sugar=20)
  before_imm = BitVector([false, false, false, false, false, false])
  ag.immunity = copy(before_imm)
  push!(ag.diseases, disease)

  Sugarscape.immune_response!(model)

  # One unit sugar penalty applied
  @test ag.sugar == 19
  # Exactly one bit should have flipped in the immunity string
  changed = sum(before_imm .!= ag.immunity)
  @test changed == 1
  # Disease is still not a full substring after single flip
  @test !Sugarscape._subseq(disease, ag.immunity)

  ##########################################################################
  # 3. Disease transmission adds disease to neighbour
  ##########################################################################
  model = Sugarscape.sugarscape(; dims=(3, 3), N=0, seed=rng_seed,
    enable_disease=true, disease_immunity_length=6,
    growth_rate=0, vision_dist=(1, 1), metabolic_rate_dist=(0, 0), initial_sugar_dist=(0, 0))

  src = add_custom_agent!(model, (2, 2); sugar=10)
  dst = add_custom_agent!(model, (2, 3); sugar=10)
  push!(src.diseases, disease)

  Sugarscape.disease_transmission!(model)
  @test any(isequal(disease), dst.diseases)
end
