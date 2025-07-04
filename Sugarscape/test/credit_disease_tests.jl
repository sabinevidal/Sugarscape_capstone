using Test, Random, Sugarscape, Agents

@testset "Loans conserve sugar" begin
  rng = Random.MersenneTwister(1)
  m = Sugarscape.sugarscape(N=50, seed=1, enable_credit=true, growth_rate=0, metabolic_rate_dist=(0, 0))
  m.sugar_values .= 0.0
  total = sum(a -> a.sugar, allagents(m))
  Agents.step!(m, 50)                      # advance 50 ticks
  @test total == sum(a -> a.sugar, allagents(m))  # conservation
end

@testset "Diseases spread" begin
  rng = Random.MersenneTwister(2)
  m = Sugarscape.sugarscape(N=10, seed=2, enable_disease=true, growth_rate=0, metabolic_rate_dist=(0, 0))
  m.sugar_values .= 0.0
  first_agent = first(allagents(m))
  push!(first_agent.diseases, trues(48))  # seed a disease
  Agents.step!(m, 1)
  @test any(length(a.diseases) > 0 for a in allagents(m))
end
