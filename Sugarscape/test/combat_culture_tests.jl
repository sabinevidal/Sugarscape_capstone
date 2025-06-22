using Test
using Random
using Sugarscape
using Agents

# Helper for constructing custom agents with explicit fields
function add_custom_agent!(model, pos; sugar, vision=3, metabolism=1, culture_bits::Vector{Bool})
  age = 0
  max_age = 100
  sex = :male
  has_mated = false
  children = Int[]
  total_inheritance_received = 0.0
  culture = BitVector(culture_bits)
  add_agent!(pos, SugarscapeAgent, model, vision, metabolism, sugar, age, max_age, sex, has_mated, sugar, children, total_inheritance_received, culture)
end

@testset "Combat Rule C-α" begin
  # Seed randomness for reproducibility
  rng_seed = 20240620
  model = Sugarscape.sugarscape(; dims=(5, 5), N=0, seed=rng_seed, enable_combat=true, enable_culture=true, culture_tag_length=3,
    vision_dist=(3, 3), w0_dist=(5, 5), metabolic_rate_dist=(1, 1), growth_rate=0)
  # Clear sugar landscape then set custom values
  model.sugar_values .= 0.0

  # Scenario 1: attacker should NOT attack same-tribe target
  add_custom_agent!(model, (2, 2); sugar=10, culture_bits=[false, false, true])  # blue (2 zeros)
  add_custom_agent!(model, (4, 2); sugar=5, culture_bits=[false, true, false])   # also blue
  @test length(allagents(model)) == 2
  combat!(model)
  @test length(allagents(model)) == 2           # nobody died
  attacker = only([ag for ag in allagents(model) if ag.pos == (2, 2)])
  @test attacker.sugar == 10                    # no sugar change

  # Reset model for scenario 2: stronger occupant – no attack
  model = Sugarscape.sugarscape(; dims=(5, 5), N=0, seed=rng_seed, enable_combat=true, enable_culture=true, culture_tag_length=3,
    vision_dist=(3, 3), w0_dist=(5, 5), metabolic_rate_dist=(1, 1), growth_rate=0)
  model.sugar_values .= 0.0
  add_custom_agent!(model, (2, 2); sugar=5, culture_bits=[false, false, true])     # attacker (blue)
  add_custom_agent!(model, (4, 2); sugar=10, culture_bits=[true, true, false])     # victim candidate (red but stronger)
  combat!(model)
  @test length(allagents(model)) == 1          # weaker agent killed
  survivor = first(allagents(model))
  @test survivor.sugar == 10 + 5 - 1           # gained min(5, limit) and paid metabolism
  @test survivor.pos == (2, 2) || survivor.pos == (4, 2)  # moved to target site

  # Scenario 3: legitimate attack – collect site sugar + stolen sugar
  model = Sugarscape.sugarscape(; dims=(5, 5), N=0, seed=rng_seed, enable_combat=true, enable_culture=true, culture_tag_length=3,
    vision_dist=(3, 3), w0_dist=(5, 5), metabolic_rate_dist=(1, 1), growth_rate=0)
  model.sugar_values .= 0.0
  model.sugar_values[4, 2] = 4.0  # site sugar at victim cell
  add_custom_agent!(model, (2, 2); sugar=10, culture_bits=[false, false, true])  # attacker (blue)
  add_custom_agent!(model, (4, 2); sugar=6, culture_bits=[true, true, false])   # victim (red, weaker)
  pre_kills = model.combat_kills
  combat!(model)
  @test model.combat_kills == pre_kills + 1            # one kill recorded
  @test length(allagents(model)) == 1                  # victim removed
  attacker = first(allagents(model))
  # Stolen = min(6, combat_limit=50) = 6, site_sugar = 4, metabolism 1 deducted
  @test isapprox(attacker.sugar, 10 + 6 + 4 - 1; atol=1e-8)
  @test attacker.pos == (4, 2)                           # moved to victim site
  # Ensure movement rule will be skipped later this tick
  @test attacker.id in model.agents_moved_combat
end

@testset "Culture Rule K" begin
  rng_seed = 20240620
  model = Sugarscape.sugarscape(; dims=(3, 3), N=0, seed=rng_seed, enable_culture=true, culture_tag_length=1,
    enable_combat=false, vision_dist=(1, 1), w0_dist=(5, 5), metabolic_rate_dist=(1, 1), growth_rate=0)
  model.sugar_values .= 0.0
  add_custom_agent!(model, (2, 2); sugar=5, culture_bits=[false])  # agent A
  add_custom_agent!(model, (2, 3); sugar=5, culture_bits=[true])   # neighbor B (diff bit)
  culture_spread!(model)
  a = only([ag for ag in allagents(model) if ag.pos == (2, 2)])
  b = only([ag for ag in allagents(model) if ag.pos == (2, 3)])
  @test a.culture[1] == b.culture[1]            # They now agree
end
