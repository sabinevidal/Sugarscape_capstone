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

################################################################################
# Movement Rule (M)
################################################################################
rng_seed = 0x20240622
neutral_traits = (Openness=0.0, Conscientiousness=0.0, Extraversion=0.0, Agreeableness=0.0, Neuroticism=0.0)
@testset "Movement Rule (M): Trait-Driven" begin
  #   @info "🏃 Starting Movement Rule tests..."

  #   ##########################################################################
  #   # 1. High Neuroticism Avoids Crowded High-Reward Site
  #   ##########################################################################
  #   @info "🌀 Testing: Agent avoids the crowded top-reward cell"
  #   """
  #   Traits: Low openness, low extraversion, high neuroticism
  # Setup:
  # 	•	One cell with max sugar (e.g. 5.0) is completely surrounded by other agents
  # 	•	Second-best sugar (4.5) is in a more isolated location
  # Expectation: Agent avoids the crowded top-reward cell due to anxiety/discomfort around social exposure and risk of conflict. Picks second-best instead.
  # """

  #   model = Sugarscape.sugarscape(; dims=(5, 5), N=0, seed=rng_seed,
  #     growth_rate=0,                      # disable growback
  #     vision_dist=(5, 5),                 # deterministic vision
  #     metabolic_rate_dist=(0, 0),         # no metabolism for clarity
  #     initial_sugar_dist=(0, 0),          # start with zero sugar
  #     use_llm_decisions=true,
  #     use_big_five=true)

  #   model.sugar_values .= 0.0        # blank slate

  #   # Place a high-sugar site north (within vision=2)
  #   model.sugar_values[3, 5] = 10.0  # grid is (x, y)
  #   model.sugar_values[1, 3] = 8.0   # another site, lower sugar

  #   # Create blocker agents around the high-reward site
  #   blocker_positions = [(2, 5), (4, 5), (3, 4)]
  #   neutral_traits = (Openness=0.0, Conscientiousness=0.0, Extraversion=0.0, Agreeableness=0.0, Neuroticism=0.0)
  #   for pos in blocker_positions
  #     Sugarscape.create_big_five_agent!(
  #       model, pos, 2, 0, 0, 1, 100, :male, false, 0, Vector{Int}([]), 0, BitVector([]), Dict{Int,Vector{Sugarscape.Loan}}(), Dict{Int,Vector{Sugarscape.Loan}}(), BitVector([]), BitVector([]), neutral_traits)
  #   end

  #   agent_pos = (3, 3)
  #   # Traits for high neuroticism, low openness, low extraversion
  #   agent_traits = (Openness=-1.0, Conscientiousness=0.0, Extraversion=-1.0, Agreeableness=0.0, Neuroticism=5.0)
  #   agent = Sugarscape.create_big_five_agent!(
  #     model, agent_pos, 5, 0, 0, 1, 100, :male, false, 0, Vector{Int}([]), 0, BitVector([]), Dict{Int,Vector{Sugarscape.Loan}}(), Dict{Int,Vector{Sugarscape.Loan}}(), BitVector([]), BitVector([]), agent_traits)

  #   Sugarscape._agent_step_llm!(agent, model)

  #   @test log_test_step("Agent moved to isolated site", agent.pos == (1, 3), (1, 3), agent.pos)
  #   @test log_test_step("Agent collected sugar from isolated site", agent.sugar == 8.0, 8.0, agent.sugar)
  #   @test log_test_step("Isolated sugar site depleted", model.sugar_values[1, 3] == 0.0, 0.0, model.sugar_values[1, 3])
  #   @test log_test_step("High-reward site untouched", model.sugar_values[3, 5] == 10.0, 10.0, model.sugar_values[3, 5])

  #   ##########################################################################
  #   # 2. High Extraversion & Agreeableness Prefers Proximity
  #   ##########################################################################

  #   """
  #   Traits: High extraversion, high agreeableness, low neuroticism
  # Setup:
  # 	•	Multiple equally rewarding sugar sites (e.g. 3.0) at same distance
  # 	•	One is adjacent to another agent; others are isolated
  # Expectation: Agent chooses site near another agent due to social preference and cooperative inclination.
  # """

  #   @info "🌀 Testing: High Extraversion & Agreeableness prefers proximity"

  #   model2 = Sugarscape.sugarscape(; dims=(5, 5), N=0, seed=rng_seed,
  #     growth_rate=0,                      # disable growback
  #     vision_dist=(5, 5),                 # deterministic vision
  #     metabolic_rate_dist=(0, 0),         # no metabolism for clarity
  #     initial_sugar_dist=(0, 0),          # start with zero sugar
  #     use_llm_decisions=true,
  #     use_big_five=true)

  #   model2.sugar_values .= 0.0

  #   # Equally rewarding sites at equal distance from the focal agent
  #   equal_val = 3.0
  #   sites = [(1, 3), (5, 3), (3, 1)]
  #   for s in sites
  #     model2.sugar_values[s...] = equal_val
  #   end

  #   # Place a neutral neighbour adjacent to the (1,3) site
  #   Sugarscape.create_big_five_agent!(
  #     model2, (1, 2), 2, 0, 0, 1, 100, :male, false, 0, Vector{Int}([]), 0, BitVector([]),
  #     Dict{Int,Vector{Sugarscape.Loan}}(), Dict{Int,Vector{Sugarscape.Loan}}(), BitVector([]), BitVector([]), neutral_traits)

  #   # Create the focal agent with high extraversion & agreeableness
  #   agent2_traits = (Openness=0.0, Conscientiousness=0.0, Extraversion=5.0, Agreeableness=5.0, Neuroticism=1.0)
  #   agent2 = Sugarscape.create_big_five_agent!(
  #     model2, (3, 3), 5, 0, 0, 1, 100, :male, false, 0, Vector{Int}([]), 0, BitVector([]),
  #     Dict{Int,Vector{Sugarscape.Loan}}(), Dict{Int,Vector{Sugarscape.Loan}}(), BitVector([]), BitVector([]), agent2_traits)

  #   Sugarscape._agent_step_llm!(agent2, model2)

  #   @test log_test_step("Agent chose adjacent social site", agent2.pos == (1, 3), (1, 3), agent2.pos)
  #   @test log_test_step("Agent collected sugar from social site", agent2.sugar == equal_val, equal_val, agent2.sugar)
  #   @test log_test_step("Adjacent sugar site depleted", model2.sugar_values[1, 3] == 0.0, 0.0, model2.sugar_values[1, 3])


  #   ##########################################################################
  #   # 3. High Conscientiousness Takes Long-Term Efficient Path
  #   ##########################################################################

  #   """
  # Traits: High conscientiousness, low neuroticism
  # Setup:
  # 	•	One close low-sugar cell (2.5) and a farther high-sugar cell (5.0) both within vision
  # 	•	Path to higher sugar may take 2+ steps or be riskier
  # Expectation: Agent moves toward higher-rewarding site even if farther, valuing long-term gain and efficient planning.
  # """

  #   @info "🌀 Testing: High Conscientiousness takes long-term efficient path"

  #   model3 = Sugarscape.sugarscape(; dims=(6, 6), N=0, seed=rng_seed,
  #     growth_rate=0,
  #     vision_dist=(6, 6),
  #     metabolic_rate_dist=(0, 0),
  #     initial_sugar_dist=(0, 0),
  #     use_llm_decisions=true,
  #     use_big_five=true)

  #   model3.sugar_values .= 0.0

  #   low_val = 2.5
  #   high_val = 5.0
  #   low_pos = (4, 3)    # distance 1
  #   high_pos = (6, 3)   # farther but richer

  #   model3.sugar_values[low_pos...] = low_val
  #   model3.sugar_values[high_pos...] = high_val

  #   agent3_traits = (Openness=0.0, Conscientiousness=5.0, Extraversion=0.0, Agreeableness=0.0, Neuroticism=1.0)
  #   agent3 = Sugarscape.create_big_five_agent!(
  #     model3, (3, 3), 6, 0, 0, 1, 100, :male, false, 0, Vector{Int}([]), 0, BitVector([]),
  #     Dict{Int,Vector{Sugarscape.Loan}}(), Dict{Int,Vector{Sugarscape.Loan}}(), BitVector([]), BitVector([]), agent3_traits)

  #   Sugarscape._agent_step_llm!(agent3, model3)

  #   @test log_test_step("Agent moved to distant high-reward site", agent3.pos == high_pos, high_pos, agent3.pos)
  #   @test log_test_step("Agent collected high reward sugar", agent3.sugar == high_val, high_val, agent3.sugar)
  #   @test log_test_step("High reward site depleted", model3.sugar_values[high_pos...] == 0.0, 0.0, model3.sugar_values[high_pos...])
  #   @test log_test_step("Low reward site untouched", model3.sugar_values[low_pos...] == low_val, low_val, model3.sugar_values[low_pos...])

  #   @info "✅ Movement Rule tests completed successfully"

end

################################################################################
# Reproduction Rule (S)
################################################################################
@testset "Reproduction Rule (S): Trait-Driven" begin
  @info "🏃 Starting Reproduction Rule tests..."

  ##########################################################################
  # 1. High Neuroticism Avoids Reproduction Despite Eligibility
  ##########################################################################
  """
Traits: High neuroticism, low openness
Setup:
	•	Agent is fertile, has eligible partners, and enough sugar
	•	Nearby positions are available for offspring
Expectation: Agent refuses to reproduce citing anxiety, fear of risk, or uncertainty—even though it’s allowed by the rule.
  """

  # @info "🌀 Testing: High Neuroticism avoids reproduction despite eligibility"

  # rep_model1 = Sugarscape.sugarscape_llm_bigfive(; dims=(5, 5), N=0, seed=rng_seed,
  #   growth_rate=0,
  #   vision_dist=(5, 5),
  #   metabolic_rate_dist=(0, 0),
  #   initial_sugar_dist=(0, 0),
  #   enable_reproduction=true)

  # # Focal agent — fertile with high neuroticism
  # focal1_traits = (Openness=1.0, Conscientiousness=1.0, Extraversion=1.0, Agreeableness=1.0, Neuroticism=5.0)
  # focal1 = Sugarscape.create_big_five_agent!(
  #   rep_model1, (3, 3), 5, 0, 20.0, 25, 100, :male, false, 20.0, Int[], 0.0, BitVector([]), Dict(), Dict(), BitVector[], falses(0), focal1_traits)

  # # Eligible partner — neutral traits
  # partner1 = Sugarscape.create_big_five_agent!(
  #   rep_model1, (4, 3), 5, 0, 20.0, 25, 100, :female, false, 20.0, Int[], 0.0, BitVector([]), Dict(), Dict(), BitVector[], falses(0), neutral_traits)

  # # Ensure free nearby cell
  # rep_model1.sugar_values .= 0.0

  # Sugarscape._agent_step_llm!(focal1, rep_model1)

  # @test log_test_step("Agent did not reproduce", focal1.has_reproduced == false, false, focal1.has_reproduced)
  # @test log_test_step("No children created", isempty(focal1.children), true, length(focal1.children))
  # @test log_test_step("Partner did not reproduce", partner1.has_reproduced == false, false, partner1.has_reproduced)

  ##########################################################################
  # 2. High Agreeableness and High Conscientiousness Chooses Partner Strategically
  ##########################################################################
  """
  Traits: High agreeableness, high conscientiousness
  Setup:
  	•	Multiple eligible partners, all equal on age/sugar
  	•	One is culturally similar or more cooperative in past interactions
  Expectation: Agent chooses partner with shared values or higher predicted cooperation, demonstrating “selectivity” based on harmony.
  """

  @info "🌀 Testing: High Agreeableness & Conscientiousness strategic partner choice"

  rep_model2 = Sugarscape.sugarscape_llm_bigfive(; dims=(6, 6), N=0, seed=rng_seed,
    growth_rate=0,
    vision_dist=(6, 6),
    metabolic_rate_dist=(0, 0),
    initial_sugar_dist=(0, 0),
    enable_reproduction=true)

  # Culture helper
  same_culture = BitVector([true, true, true, false, false])
  diff_culture = BitVector([false, false, false, true, true])

  focal2_traits = (Openness=3.0, Conscientiousness=5.0, Extraversion=3.0, Agreeableness=5.0, Neuroticism=3.0)
  focal2 = Sugarscape.create_big_five_agent!(
    rep_model2, (3, 3), 5, 0, 30.0, 25, 100, :female, false, 30.0, Int[], 0.0, same_culture,
    Dict(), Dict(), BitVector[], falses(0), focal2_traits)

  partner_similar = Sugarscape.create_big_five_agent!(
    rep_model2, (4, 3), 5, 0, 30.0, 25, 100, :male, false, 30.0, Int[], 0.0, same_culture,
    Dict(), Dict(), BitVector[], falses(0), neutral_traits)

  partner_diff = Sugarscape.create_big_five_agent!(
    rep_model2, (2, 3), 5, 0, 30.0, 25, 100, :male, false, 30.0, Int[], 0.0, diff_culture,
    Dict(), Dict(), BitVector[], falses(0), neutral_traits)

  rep_model2.sugar_values .= 0.0

  Sugarscape._agent_step_llm!(focal2, rep_model2)

  @test log_test_step("Agent reproduced", focal2.has_reproduced == true, true, focal2.has_reproduced)
  @test log_test_step("Similar partner reproduced", partner_similar.has_reproduced == true, true, partner_similar.has_reproduced)
  @test log_test_step("Different partner not chosen", partner_diff.has_reproduced == false, false, partner_diff.has_reproduced)

  ##########################################################################
  # 3. Low Conscientiousness and High Openness Reproduces with First Available
  ##########################################################################
  """
  Traits: Low conscientiousness, high openness, moderate extraversion
  Setup:
  	•	Several partners available, but only one has immediate empty space
  Expectation: Agent reproduces quickly and impulsively with that partner, showing spontaneity and low deliberation.
  """

  @info "🌀 Testing: Low Conscientiousness & High Openness reproduces impulsively"

  rep_model3 = Sugarscape.sugarscape_llm_bigfive(; dims=(6, 6), N=0, seed=rng_seed,
    growth_rate=0,
    vision_dist=(6, 6),
    metabolic_rate_dist=(0, 0),
    initial_sugar_dist=(0, 0),
    enable_reproduction=true)

  # Focal agent
  focal3_traits = (Openness=5.0, Conscientiousness=1.0, Extraversion=2.5, Agreeableness=3.0, Neuroticism=3.0)
  focal3 = Sugarscape.create_big_five_agent!(
    rep_model3, (3, 3), 5, 0, 25.0, 25, 100, :female, false, 25.0, Int[], 0.0, BitVector([]), Dict(), Dict(), BitVector[], falses(0), focal3_traits)

  # Partner A (has empty nearby cell)
  Sugarscape.create_big_five_agent!(
    rep_model3, (4, 3), 5, 0, 25.0, 25, 100, :male, false, 25.0, Int[], 0.0, BitVector([]), Dict(), Dict(), BitVector[], falses(0), neutral_traits)

  # Partner B (no empty space around)
  Sugarscape.create_big_five_agent!(
    rep_model3, (1, 1), 5, 0, 25.0, 25, 100, :male, false, 25.0, Int[], 0.0, BitVector([]), Dict(), Dict(), BitVector[], falses(0), neutral_traits)
  # Surround partner B with blockers so no empty cell
  blocker_positions3 = [(0, 1), (2, 1), (1, 0), (1, 2)]
  for pos in blocker_positions3
    if all(1 .<= pos .<= (6, 6))
      Sugarscape.create_big_five_agent!(rep_model3, pos, 1, 0, 0.0, 1, 100, :male, false, 0.0, Int[], 0.0, BitVector([]), Dict(), Dict(), BitVector[], falses(0), neutral_traits)
    end
  end

  rep_model3.sugar_values .= 0.0

  Sugarscape._agent_step_llm!(focal3, rep_model3)

  @test log_test_step("Agent reproduced", focal3.has_reproduced == true, true, focal3.has_reproduced)
  @test log_test_step("Total agents increased", length(Sugarscape.allagents(rep_model3)) >= 4, ">=4", length(Sugarscape.allagents(rep_model3)))

end
