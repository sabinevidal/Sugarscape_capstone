using Test
using Random
using Sugarscape
using Agents
using DotEnv
using Logging
using Distributions
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
# @testset "Movement Rule (M): Trait-Driven" begin
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
#   agent_traits = (Openness=1.0, Conscientiousness=2.0, Extraversion=1.0, Agreeableness=2.0, Neuroticism=5.0)
#   agent = Sugarscape.create_big_five_agent!(
#     model, agent_pos, 5, 2, 0, 1, 100, :male, false, 0, Vector{Int}([]), 0, BitVector([]), Dict{Int,Vector{Sugarscape.Loan}}(), Dict{Int,Vector{Sugarscape.Loan}}(), BitVector([]), BitVector([]), agent_traits)

#   Sugarscape.movement!(agent, model)

#   @test log_test_step("Agent moved to isolated site", agent.pos == (1, 3), (1, 3), agent.pos)
#   @test log_test_step("Agent collected sugar from isolated site minus metabolism", agent.sugar == 6.0, 6.0, agent.sugar)
#   @test log_test_step("Isolated sugar site depleted", model.sugar_values[1, 3] == 0.0, 0.0, model.sugar_values[1, 3])
#   @test log_test_step("High-reward site untouched", model.sugar_values[3, 5] == 10.0, 10.0, model.sugar_values[3, 5])

#   ##########################################################################
#   # 2. High Extraversion Goes toward Crowded High-Reward Site
#   ##########################################################################
#   @info "🌀 Testing: Agent goes towards the crowded top-reward cell"
#   """
#   Traits: Low openness, low extraversion, high neuroticism
# Setup:
# 	•	One cell with max sugar (e.g. 5.0) is completely surrounded by other agents
# 	•	Second-best sugar (4.5) is in a more isolated location
# Expectation: Agent goes to the crowded top-reward cell due to social preference and risk of conflict. Picks second-best instead.
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
#   model.sugar_values[1, 3] = 11.0   # another site, lower sugar

#   # Create blocker agents around the high-reward site
#   blocker_positions = [(2, 5), (4, 5), (3, 4)]
#   neutral_traits = (Openness=0.0, Conscientiousness=0.0, Extraversion=0.0, Agreeableness=0.0, Neuroticism=0.0)
#   for pos in blocker_positions
#     Sugarscape.create_big_five_agent!(
#       model, pos, 2, 0, 0, 1, 100, :male, false, 0, Vector{Int}([]), 0, BitVector([]), Dict{Int,Vector{Sugarscape.Loan}}(), Dict{Int,Vector{Sugarscape.Loan}}(), BitVector([]), BitVector([]), neutral_traits)
#   end

#   agent_pos = (3, 3)
#   # Traits for high neuroticism, low openness, low extraversion
#   agent_traits = (Openness=1.0, Conscientiousness=2.0, Extraversion=5.0, Agreeableness=2.0, Neuroticism=1.0)
#   agent = Sugarscape.create_big_five_agent!(
#     model, agent_pos, 5, 2, 0, 1, 100, :male, false, 0, Vector{Int}([]), 0, BitVector([]), Dict{Int,Vector{Sugarscape.Loan}}(), Dict{Int,Vector{Sugarscape.Loan}}(), BitVector([]), BitVector([]), agent_traits)

#   Sugarscape.movement!(agent, model)

#   @test log_test_step("Agent moved to high-reward and social site", agent.pos == (3, 5), (3, 5), agent.pos)
#   @test log_test_step("Agent collected sugar from high-reward site minus metabolism", agent.sugar == 8.0, 8.0, agent.sugar)
#   @test log_test_step("Social sugar site depleted", model.sugar_values[3, 5] == 0.0, 0.0, model.sugar_values[3, 5])
#   @test log_test_step("Low social site untouched", model.sugar_values[1, 3] == 11.0, 11.0, model.sugar_values[1, 3])

#   ##########################################################################
#   # 3. High Extraversion & Agreeableness Prefers Proximity
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
#   agent2_traits = (Openness=3.0, Conscientiousness=3.0, Extraversion=5.0, Agreeableness=5.0, Neuroticism=1.0)
#   agent2 = Sugarscape.create_big_five_agent!(
#     model2, (3, 3), 5, 0, 0, 1, 100, :male, false, 0, Vector{Int}([]), 0, BitVector([]),
#     Dict{Int,Vector{Sugarscape.Loan}}(), Dict{Int,Vector{Sugarscape.Loan}}(), BitVector([]), BitVector([]), agent2_traits)

#   Sugarscape.movement!(agent2, model2)

#   @test log_test_step("Agent chose adjacent social site", agent2.pos == (1, 3), (1, 3), agent2.pos)
#   @test log_test_step("Agent collected sugar from social site", agent2.sugar == equal_val, equal_val, agent2.sugar)
#   @test log_test_step("Adjacent sugar site depleted", model2.sugar_values[1, 3] == 0.0, 0.0, model2.sugar_values[1, 3])


#   ##########################################################################
#   # 4. High Conscientiousness Takes Long-Term Efficient Path
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

#   agent3_traits = (Openness=3.0, Conscientiousness=5.0, Extraversion=3.0, Agreeableness=3.0, Neuroticism=1.0)
#   agent3 = Sugarscape.create_big_five_agent!(
#     model3, (3, 3), 6, 0, 0, 1, 100, :male, false, 0, Vector{Int}([]), 0, BitVector([]),
#     Dict{Int,Vector{Sugarscape.Loan}}(), Dict{Int,Vector{Sugarscape.Loan}}(), BitVector([]), BitVector([]), agent3_traits)

#   Sugarscape.movement!(agent3, model3)

#   @test log_test_step("Agent moved to distant high-reward site", agent3.pos == high_pos, high_pos, agent3.pos)
#   @test log_test_step("Agent collected high reward sugar", agent3.sugar == high_val, high_val, agent3.sugar)
#   @test log_test_step("High reward site depleted", model3.sugar_values[high_pos...] == 0.0, 0.0, model3.sugar_values[high_pos...])
#   @test log_test_step("Low reward site untouched", model3.sugar_values[low_pos...] == low_val, low_val, model3.sugar_values[low_pos...])

#   @info "✅ Movement Rule tests completed successfully"

# end

# ################################################################################
# # Reproduction Rule (S)
# ################################################################################
# @testset "Reproduction Rule (S): Trait-Driven" begin
#   @info "🏃 Starting Reproduction Rule tests..."

#   ##########################################################################
#   # 1. High Neuroticism Avoids Reproduction Despite Eligibility
#   ##########################################################################
#   """
# Traits: High neuroticism, low openness
# Setup:
# 	•	Agent is fertile, has eligible partners, and enough sugar
# 	•	Nearby positions are available for offspring
# Expectation: Agent refuses to reproduce citing anxiety, fear of risk, or uncertainty—even though it’s allowed by the rule.
#   """

#   @info "🌀 Testing: High Neuroticism avoids reproduction despite eligibility"

#   rep_model1 = Sugarscape.sugarscape_llm_bigfive(; dims=(5, 5), N=0, seed=rng_seed,
#     growth_rate=0,
#     vision_dist=(5, 5),
#     metabolic_rate_dist=(0, 0),
#     initial_sugar_dist=(0, 0),
#     enable_reproduction=true)

#   # Focal agent — fertile with high neuroticism
#   focal1_traits = (Openness=1.0, Conscientiousness=2.0, Extraversion=1.0, Agreeableness=1.0, Neuroticism=5.0)
#   focal1_culture = BitVector([true, true, false, false, true])
#   focal1 = Sugarscape.create_big_five_agent!(
#     rep_model1, (3, 3), 5, 0, 20.0, 25, 100, :male, false, 20.0, Int[], 0.0, focal1_culture, Dict(), Dict(), BitVector[], falses(0), focal1_traits)


#   # Eligible partner — neutral traits
#   partner1_culture = BitVector([false, false, true, true, true])
#   partner1 = Sugarscape.create_big_five_agent!(
#     rep_model1, (4, 3), 5, 0, 20.0, 25, 100, :female, false, 20.0, Int[], 0.0, partner1_culture, Dict(), Dict(), BitVector[], falses(0), neutral_traits)

#   # Ensure free nearby cell
#   rep_model1.sugar_values .= 0.0

#   Sugarscape.reproduction!(focal1, rep_model1)

#   @test log_test_step("Agent did not reproduce", focal1.has_reproduced == false, false, focal1.has_reproduced)
#   @test log_test_step("No children created", isempty(focal1.children), true, length(focal1.children))
#   @test log_test_step("Partner did not reproduce", partner1.has_reproduced == false, false, partner1.has_reproduced)

#   ##########################################################################
#   # 2. High Agreeableness and High Conscientiousness Chooses Partner Strategically
#   ##########################################################################
#   """
#   Traits: High agreeableness, high conscientiousness
#   Setup:
#   	•	Multiple eligible partners, all equal on age/sugar
#   	•	One is culturally similar or more cooperative in past interactions
#   Expectation: Agent chooses partner with shared values or higher predicted cooperation, demonstrating “selectivity” based on harmony.
#   """

#   @info "🌀 Testing: High Agreeableness & Conscientiousness strategic partner choice"

#   rep_model2 = BigFive.sugarscape_llm_bigfive(; dims=(6, 6), N=0, seed=rng_seed,
#     growth_rate=0,
#     vision_dist=(6, 6),
#     metabolic_rate_dist=(0, 0),
#     initial_sugar_dist=(0, 0),
#     enable_reproduction=true)

#   # Culture helper
#   same_culture = BitVector([true, true, true, false, false])
#   diff_culture = BitVector([false, false, false, true, true])

#   focal2_traits = (Openness=4.0, Conscientiousness=5.0, Extraversion=3.0, Agreeableness=5.0, Neuroticism=3.0)
#   focal2 = BigFive.create_big_five_agent!(
#     rep_model2, (4, 4), 5, 0, 30.0, 25, 100, :female, false, 30.0, Int[], 0.0, same_culture,
#     Dict(), Dict(), BitVector[], falses(0), focal2_traits)

#   partner_similar = BigFive.create_big_five_agent!(
#     rep_model2, (5, 4), 5, 0, 30.0, 25, 100, :male, false, 30.0, Int[], 0.0, same_culture,
#     Dict(), Dict(), BitVector[], falses(0), neutral_traits)

#   partner_diff = BigFive.create_big_five_agent!(
#     rep_model2, (3, 4), 5, 0, 30.0, 25, 100, :male, false, 30.0, Int[], 0.0, diff_culture,
#     Dict(), Dict(), BitVector[], falses(0), neutral_traits)

#   rep_model2.sugar_values .= 0.0

#   Sugarscape.reproduction!(focal2, rep_model2)

#   @test log_test_step("Agent reproduced", focal2.has_reproduced == true, true, focal2.has_reproduced)
#   @test log_test_step("Similar partner reproduced", partner_similar.has_reproduced == true, true, partner_similar.has_reproduced)
#   @test log_test_step("Different partner not chosen", partner_diff.has_reproduced == false, false, partner_diff.has_reproduced)

#   ##########################################################################
#   # 3. Low Conscientiousness and High Openness Reproduces with First Available
#   ##########################################################################
#   """
#   Traits: Low conscientiousness, high openness, moderate extraversion
#   Setup:
#   	•	Several partners available, but only one has immediate empty space
#   Expectation: Agent reproduces quickly and impulsively with that partner, showing spontaneity and low deliberation.
#   """

#   @info "🌀 Testing: Low Conscientiousness & High Openness reproduces impulsively"

#   rep_model3 = BigFive.sugarscape_llm_bigfive(; dims=(6, 6), N=0, seed=rng_seed,
#     growth_rate=0,
#     vision_dist=(6, 6),
#     metabolic_rate_dist=(0, 0),
#     initial_sugar_dist=(0, 0),
#     enable_reproduction=true)

#   # Focal agent
#   focal3_traits = (Openness=5.0, Conscientiousness=1.0, Extraversion=2.5, Agreeableness=3.0, Neuroticism=3.0)
#   focal3 = BigFive.create_big_five_agent!(
#     rep_model3, (3, 3), 5, 0, 25.0, 25, 100, :female, false, 25.0, Int[], 0.0, BitVector([]), Dict(), Dict(), BitVector[], falses(0), focal3_traits)

#   # Partner A (has empty nearby cell)
#   BigFive.create_big_five_agent!(
#     rep_model3, (4, 3), 5, 0, 25.0, 25, 100, :male, false, 25.0, Int[], 0.0, BitVector([]), Dict(), Dict(), BitVector[], falses(0), neutral_traits)

#   # Partner B (no empty space around)
#   BigFive.create_big_five_agent!(
#     rep_model3, (1, 1), 5, 0, 25.0, 25, 100, :male, false, 25.0, Int[], 0.0, BitVector([]), Dict(), Dict(), BitVector[], falses(0), neutral_traits)
#   # Surround partner B with blockers so no empty cell
#   blocker_positions3 = [(0, 1), (2, 1), (1, 0), (1, 2)]
#   for pos in blocker_positions3
#     if all(1 .<= pos .<= (6, 6))
#       BigFive.create_big_five_agent!(rep_model3, pos, 1, 0, 0.0, 1, 100, :male, false, 0.0, Int[], 0.0, BitVector([]), Dict(), Dict(), BitVector[], falses(0), neutral_traits)
#     end
#   end

#   rep_model3.sugar_values .= 0.0

#   Sugarscape.reproduction!(focal3, rep_model3)

#   @test log_test_step("Agent reproduced", focal3.has_reproduced == true, true, focal3.has_reproduced)
#   @test log_test_step("Total agents increased", length(Sugarscape.allagents(rep_model3)) >= 4, ">=4", length(Sugarscape.allagents(rep_model3)))

# end

# ################################################################################
# # Culture Rule (K)
# ################################################################################
# @testset "Culture Rule (K): Trait-Driven" begin
#   @info "🎭 Starting Culture Rule tests..."

#   ##########################################################################
#   # 1. High Agreeableness Increases Conformity
#   ##########################################################################
#   """
#   Traits: High agreeableness, moderate conscientiousness
#   Setup:
#   	•	Agent has multiple neighbours with differing tags.
#   	•	At least one tag differs between agent and neighbour.
#   Expectation:
#   Agent is more likely to copy (i.e. flip neighbour's tag to match their own), prioritising social harmony and cohesion. Even if tag values are arbitrary, the high agreeableness drives engagement in conformity.
#   """

#   @info "🌀 Testing: High Agreeableness increases conformity"

#   culture_model1 = BigFive.sugarscape_llm_bigfive(; dims=(5, 5), N=0, seed=rng_seed,
#     growth_rate=0,
#     vision_dist=(5, 5),
#     metabolic_rate_dist=(0, 0),
#     initial_sugar_dist=(0, 0),
#     enable_culture=true)

#   # Focal agent with high agreeableness
#   focal_culture = BitVector([true, false, true, false, false])
#   focal1_traits = (Openness=3.0, Conscientiousness=3.0, Extraversion=3.0, Agreeableness=5.0, Neuroticism=2.0)
#   focal1 = BigFive.create_big_five_agent!(
#     culture_model1, (3, 3), 5, 0, 15.0, 25, 100, :male, false, 15.0, Int[], 0.0, focal_culture,
#     Dict(), Dict(), BitVector[], falses(0), focal1_traits)

#   # Neighbor with different culture
#   neighbor_culture = BitVector([false, true, false, true, true])
#   neighbor1 = BigFive.create_big_five_agent!(
#     culture_model1, (4, 3), 5, 0, 15.0, 25, 100, :female, false, 15.0, Int[], 0.0, neighbor_culture,
#     Dict(), Dict(), BitVector[], falses(0), neutral_traits)

#   culture_model1.sugar_values .= 0.0
#   initial_focal_culture = copy(focal1.culture)
#   initial_neighbor_culture = copy(neighbor1.culture)

#   Sugarscape._agent_step_llm!(focal1, culture_model1)

#   # Check if cultural exchange occurred (some tag flipped)
#   culture_changed = focal1.culture != initial_focal_culture || neighbor1.culture != initial_neighbor_culture
#   @test log_test_step("Cultural exchange occurred", culture_changed, true, culture_changed)

#   ##########################################################################
#   # 2. Low Agreeableness + High Openness Avoids Influence
#   ##########################################################################
#   """
#   Traits: Low agreeableness, high openness
#   Setup:
#   	•	Several neighbours, all differing in tag positions
#   Expectation:
#   Agent resists social influence. Even though a tag difference exists, the agent refuses to flip the neighbour's tag, asserting individuality and valuing diversity of identity or culture.
#   """

#   @info "🌀 Testing: Low Agreeableness + High Openness resists influence"

#   culture_model2 = BigFive.sugarscape_llm_bigfive(; dims=(5, 5), N=0, seed=rng_seed,
#     growth_rate=0,
#     vision_dist=(5, 5),
#     metabolic_rate_dist=(0, 0),
#     initial_sugar_dist=(0, 0),
#     enable_culture=true)

#   # Focal agent with low agreeableness, high openness
#   focal2_culture = BitVector([true, true, false, false, true])
#   focal2_traits = (Openness=5.0, Conscientiousness=3.0, Extraversion=3.0, Agreeableness=1.0, Neuroticism=2.0)
#   focal2 = BigFive.create_big_five_agent!(
#     culture_model2, (3, 3), 5, 0, 15.0, 25, 100, :male, false, 15.0, Int[], 0.0, focal2_culture,
#     Dict(), Dict(), BitVector[], falses(0), focal2_traits)

#   # Multiple neighbors with different cultures
#   neighbor2a_culture = BitVector([false, false, true, true, false])
#   BigFive.create_big_five_agent!(
#     culture_model2, (2, 3), 5, 0, 15.0, 25, 100, :female, false, 15.0, Int[], 0.0, neighbor2a_culture,
#     Dict(), Dict(), BitVector[], falses(0), neutral_traits)

#   neighbor2b_culture = BitVector([false, true, true, false, false])
#   BigFive.create_big_five_agent!(
#     culture_model2, (4, 3), 5, 0, 15.0, 25, 100, :female, false, 15.0, Int[], 0.0, neighbor2b_culture,
#     Dict(), Dict(), BitVector[], falses(0), neutral_traits)

#   culture_model2.sugar_values .= 0.0
#   initial_focal2_culture = copy(focal2.culture)

#   Sugarscape._agent_step_llm!(focal2, culture_model2)

#   # Check that focal agent maintained their culture (resisted influence)
#   culture_maintained = focal2.culture == initial_focal2_culture
#   @test log_test_step("Agent maintained individual culture", culture_maintained, true, culture_maintained)

#   ##########################################################################
#   # 3. High Conscientiousness Flips Only When Strategically Beneficial
#   ##########################################################################
#   """
#   Traits: High conscientiousness, moderate agreeableness
#   Setup:
#   	•	Agent differs from multiple neighbours in tags
#   	•	Some neighbours have high sugar levels (optional, to simulate perceived model utility)
#   Expectation:
#   Agent flips the neighbour's tag only when the neighbour is "beneficial", showing selective imitation based on utility rather than automatic conformity. Mimics planned adaptation.
#   """

#   @info "🌀 Testing: High Conscientiousness strategic cultural adaptation"

#   culture_model3 = BigFive.sugarscape_llm_bigfive(; dims=(5, 5), N=0, seed=rng_seed,
#     growth_rate=0,
#     vision_dist=(5, 5),
#     metabolic_rate_dist=(0, 0),
#     initial_sugar_dist=(0, 0),
#     enable_culture=true)

#   # Focal agent with high conscientiousness
#   focal3_culture = BitVector([true, false, true, false, false])
#   focal3_traits = (Openness=3.0, Conscientiousness=5.0, Extraversion=3.0, Agreeableness=3.0, Neuroticism=2.0)
#   focal3 = BigFive.create_big_five_agent!(
#     culture_model3, (3, 3), 5, 0, 10.0, 25, 100, :male, false, 10.0, Int[], 0.0, focal3_culture,
#     Dict(), Dict(), BitVector[], falses(0), focal3_traits)

#   # High-sugar neighbor (beneficial to imitate)
#   beneficial_culture = BitVector([false, true, false, true, true])
#   BigFive.create_big_five_agent!(
#     culture_model3, (4, 3), 5, 0, 50.0, 25, 100, :female, false, 50.0, Int[], 0.0, beneficial_culture,
#     Dict(), Dict(), BitVector[], falses(0), neutral_traits)

#   # Low-sugar neighbor (less beneficial)
#   poor_culture = BitVector([false, false, false, false, true])
#   BigFive.create_big_five_agent!(
#     culture_model3, (2, 3), 5, 0, 2.0, 25, 100, :female, false, 2.0, Int[], 0.0, poor_culture,
#     Dict(), Dict(), BitVector[], falses(0), neutral_traits)

#   culture_model3.sugar_values .= 0.0
#   initial_focal3_culture = copy(focal3.culture)

#   Sugarscape._agent_step_llm!(focal3, culture_model3)

#   # Check if strategic cultural adaptation occurred
#   culture_adapted = focal3.culture != initial_focal3_culture
#   @test log_test_step("Strategic cultural adaptation occurred", culture_adapted, true, culture_adapted)

#   @info "✅ Culture Rule tests completed successfully"
# end

# ################################################################################
# # Credit Rule
# ################################################################################
# @testset "Credit Rule: Trait-Driven" begin
#   @info "💰 Starting Credit Rule tests..."

#   # Create a dummy MVN distribution to bypass data loading in tests
#   # Using identity covariance matrix (5x5 identity)
#   dummy_mvn = MvNormal([3.0, 3.0, 3.0, 3.0, 3.0], [1.0 0.0 0.0 0.0 0.0; 0.0 1.0 0.0 0.0 0.0; 0.0 0.0 1.0 0.0 0.0; 0.0 0.0 0.0 1.0 0.0; 0.0 0.0 0.0 0.0 1.0])

#   ##########################################################################
#   # 1. LENDER – High Agreeableness + Low Neuroticism = Generous
#   ##########################################################################
#   """
#   Traits: High agreeableness, low neuroticism, moderate sugar
#   Setup:
#   	•	Agent is of reproductive age with moderate excess sugar
#   	•	Neighbour requests 5 units, well within lending limit
#   Expectation:
#   Agent approves the loan generously, possibly for the full amount requested. They trust the borrower and are inclined to help.
#   """

#   @info "🌀 Testing: High Agreeableness + Low Neuroticism = Generous Lender"

#   credit_model1 = BigFive.sugarscape_llm_bigfive(; dims=(5, 5), N=0, seed=rng_seed,
#     growth_rate=0,
#     vision_dist=(5, 5),
#     metabolic_rate_dist=(0, 0),
#     initial_sugar_dist=(0, 0),
#     enable_credit=true,
#     mvn_dist=dummy_mvn)

#   # Lender agent with high agreeableness, low neuroticism
#   lender1_traits = (Openness=3.0, Conscientiousness=3.0, Extraversion=3.0, Agreeableness=5.0, Neuroticism=1.0)
#   lender1 = BigFive.create_big_five_agent!(
#     credit_model1, (3, 3), 5, 0, 30.0, 25, 100, :male, false, 30.0, Int[], 0.0, BitVector([]),
#     Dict(), Dict(), BitVector[], falses(0), lender1_traits)

#   # Borrower agent needing sugar (sugar < initial_sugar to be eligible)
#   borrower1_traits = (Openness=3.0, Conscientiousness=3.0, Extraversion=3.0, Agreeableness=3.0, Neuroticism=3.0)
#   borrower1 = BigFive.create_big_five_agent!(
#     credit_model1, (4, 3), 5, 0, 5.0, 25, 100, :female, false, 10.0, Int[], 0.0, BitVector([]),
#     Dict(), Dict(), BitVector[], falses(0), borrower1_traits)

#   credit_model1.sugar_values .= 0.0
#   initial_lender_sugar = lender1.sugar
#   initial_borrower_sugar = borrower1.sugar

#   # Simulate borrower requesting loan
#   Sugarscape.credit!(borrower1, credit_model1)

#   # Check if loan was granted (borrower sugar increased or lender sugar decreased)
#   loan_granted = (borrower1.sugar > initial_borrower_sugar) || (lender1.sugar < initial_lender_sugar)
#   @test log_test_step("Generous loan granted", loan_granted, true, loan_granted)

#   ##########################################################################
#   # 2. LENDER – High Neuroticism = Risk-Averse, Declines Loan
#   ##########################################################################
#   """
#   Traits: Very high neuroticism, moderate agreeableness
#   Setup:
#   	•	Agent is above reproductive age with enough sugar to lend
#   	•	Neighbour requests a valid amount
#   Expectation:
#   Despite being allowed to lend, agent refuses due to anxiety or perceived risk of not being repaid, even in the absence of actual danger.
#   """

#   @info "🌀 Testing: High Neuroticism = Risk-Averse Lender"

#   credit_model2 = BigFive.sugarscape_llm_bigfive(; dims=(5, 5), N=0, seed=rng_seed,
#     growth_rate=0,
#     vision_dist=(5, 5),
#     metabolic_rate_dist=(0, 0),
#     initial_sugar_dist=(0, 0),
#     enable_credit=true,
#     mvn_dist=dummy_mvn)

#   # Risk-averse lender with high neuroticism
#   lender2_traits = (Openness=3.0, Conscientiousness=3.0, Extraversion=2.0, Agreeableness=1.0, Neuroticism=5.0)
#   lender2 = BigFive.create_big_five_agent!(
#     credit_model2, (3, 3), 5, 0, 40.0, 60, 100, :male, false, 40.0, Int[], 0.0, BitVector([]),
#     Dict(), Dict(), BitVector[], falses(0), lender2_traits)

#   # Borrower agent needing sugar (sugar < initial_sugar to be eligible)
#   borrower2_traits = (Openness=3.0, Conscientiousness=1.0, Extraversion=3.0, Agreeableness=3.0, Neuroticism=3.0)
#   borrower2 = BigFive.create_big_five_agent!(
#     credit_model2, (4, 3), 5, 0, 3.0, 25, 100, :female, false, 8.0, Int[], 0.0, BitVector([]),
#     Dict(), Dict(), BitVector[], falses(0), borrower2_traits)

#   credit_model2.sugar_values .= 0.0
#   initial_lender2_sugar = lender2.sugar
#   initial_borrower2_sugar = borrower2.sugar

#   # Simulate borrower requesting loan
#   Sugarscape.credit!(borrower2, credit_model2)

#   # Check if loan was declined (no change in sugar levels)
#   loan_declined = (borrower2.sugar == initial_borrower2_sugar) && (lender2.sugar == initial_lender2_sugar)
#   @test log_test_step("Risk-averse lender declined loan", loan_declined, true, loan_declined)

#   ##########################################################################
#   # 3. BORROWER – Low Conscientiousness Borrows Too Casually
#   ##########################################################################
#   """
#   Traits: Low conscientiousness, moderate neuroticism, moderate sugar
#   Setup:
#   	•	Agent is eligible to borrow (fertile, below reproduction threshold, has income)
#   	•	Several lenders available
#   Expectation:
#   Agent requests the exact needed amount but does not prioritise lender order carefully. May even request from a less optimal lender first, indicating impulsivity or lack of strategic planning.
#   """

#   @info "🌀 Testing: Low Conscientiousness = Impulsive Borrower"

#   credit_model3 = BigFive.sugarscape_llm_bigfive(; dims=(5, 5), N=0, seed=rng_seed,
#     growth_rate=0,
#     vision_dist=(5, 5),
#     metabolic_rate_dist=(0, 0),
#     initial_sugar_dist=(0, 0),
#     enable_credit=true,
#     mvn_dist=dummy_mvn)

#   # Impulsive borrower with low conscientiousness (sugar < initial_sugar to be eligible)
#   borrower3_traits = (Openness=3.0, Conscientiousness=1.0, Extraversion=3.0, Agreeableness=3.0, Neuroticism=3.0)
#   borrower3 = BigFive.create_big_five_agent!(
#     credit_model3, (3, 3), 5, 0, 8.0, 25, 100, :female, false, 15.0, Int[], 0.0, BitVector([]),
#     Dict(), Dict(), BitVector[], falses(0), borrower3_traits)

#   # Multiple potential lenders with different characteristics
#   # Optimal lender (high sugar, generous)
#   optimal_lender_traits = (Openness=3.0, Conscientiousness=3.0, Extraversion=3.0, Agreeableness=5.0, Neuroticism=1.0)
#   BigFive.create_big_five_agent!(
#     credit_model3, (4, 3), 5, 0, 50.0, 30, 100, :male, false, 50.0, Int[], 0.0, BitVector([]),
#     Dict(), Dict(), BitVector[], falses(0), optimal_lender_traits)

#   # Suboptimal lender (lower sugar, less generous)
#   suboptimal_lender_traits = (Openness=3.0, Conscientiousness=3.0, Extraversion=3.0, Agreeableness=2.0, Neuroticism=4.0)
#   BigFive.create_big_five_agent!(
#     credit_model3, (2, 3), 5, 0, 20.0, 30, 100, :male, false, 20.0, Int[], 0.0, BitVector([]),
#     Dict(), Dict(), BitVector[], falses(0), suboptimal_lender_traits)

#   credit_model3.sugar_values .= 0.0
#   initial_borrower3_sugar = borrower3.sugar

#   # Simulate impulsive borrowing behavior
#   Sugarscape.credit!(borrower3, credit_model3)

#   # Check if borrowing occurred (indicating impulsive behavior)
#   borrowing_occurred = borrower3.sugar != initial_borrower3_sugar
#   @test log_test_step("Impulsive borrowing occurred", borrowing_occurred, true, borrowing_occurred)

#   @info "✅ Credit Rule tests completed successfully"

#   ##########################################################################
#   # 4. LENDER – High Conscientiousness Lends Preferentially to Reliable Borrower
#   ##########################################################################

#   """
# Traits & Context:
# 	•	Lender: High conscientiousness (4.3–5.0), moderate agreeableness
# 	•	Borrower 1: High stability—fertile, moderate wealth, strong repayment history
# 	•	Borrower 2: Unstable—low wealth, erratic income, weak repayment history

# Setup Conditions:
# 	•	Both borrowers request a valid loan that the lender can afford under reproductive-age rule constraints (excess sugar above reproduction threshold).
# 	•	Lender must decide how much to lend to each—or possibly only one—up to its limit.

# Expected Behavior:
# 	•	The conscientious lender, valuing planning and reliability, prioritises lending to Borrower 1, either partially or in full.
# 	•	May decline Borrower 2, or offer a minimal loan, citing risk or prudence.
#   """

#   @info "🌀 Testing: High Conscientiousness Lends Preferentially to Reliable Borrower"

#   credit_model4 = BigFive.sugarscape_llm_bigfive(; dims=(5, 5), N=0, seed=rng_seed,
#     growth_rate=0,
#     vision_dist=(5, 5),
#     metabolic_rate_dist=(0, 0),
#     initial_sugar_dist=(0, 0),
#     enable_credit=true,
#     mvn_dist=dummy_mvn)

#   # Conscientious lender with high conscientiousness, moderate agreeableness
#   lender4_traits = (Openness=3.0, Conscientiousness=4.5, Extraversion=3.0, Agreeableness=3.5, Neuroticism=2.0)
#   lender4 = BigFive.create_big_five_agent!(
#     credit_model4, (3, 3), 5, 0, 45.0, 25, 100, :male, false, 45.0, Int[], 0.0, BitVector([]),
#     Dict(), Dict(), BitVector[], falses(0), lender4_traits)

#   # Reliable borrower (Borrower 1) - stable, moderate wealth, good history
#   reliable_borrower_traits = (Openness=3.0, Conscientiousness=4.0, Extraversion=3.0, Agreeableness=3.5, Neuroticism=2.0)
#   reliable_borrower = BigFive.create_big_five_agent!(
#     credit_model4, (4, 3), 5, 0, 15.0, 25, 100, :female, false, 20.0, Int[], 0.0, BitVector([]),
#     Dict(), Dict(), BitVector[], falses(0), reliable_borrower_traits)

#   # Unreliable borrower (Borrower 2) - unstable, low wealth, poor history
#   unreliable_borrower_traits = (Openness=2.0, Conscientiousness=1.5, Extraversion=2.0, Agreeableness=2.0, Neuroticism=4.5)
#   unreliable_borrower = BigFive.create_big_five_agent!(
#     credit_model4, (2, 3), 5, 0, 3.0, 25, 100, :male, false, 5.0, Int[], 0.0, BitVector([]),
#     Dict(), Dict(), BitVector[], falses(0), unreliable_borrower_traits)

#   credit_model4.sugar_values .= 0.0
#   initial_lender4_sugar = lender4.sugar
#   initial_reliable_sugar = reliable_borrower.sugar
#   initial_unreliable_sugar = unreliable_borrower.sugar

#   # Simulate both borrowers requesting loans
#   Sugarscape.credit!(lender4, credit_model4)

#   # Check if reliable borrower received more favorable treatment
#   reliable_loan_granted = reliable_borrower.sugar > initial_reliable_sugar
#   unreliable_loan_granted = unreliable_borrower.sugar > initial_unreliable_sugar

#   # Conscientious lender should prefer reliable borrower
#   preferential_lending = reliable_loan_granted && (!unreliable_loan_granted || (reliable_borrower.sugar - initial_reliable_sugar) > (unreliable_borrower.sugar - initial_unreliable_sugar))
#   @test log_test_step("Conscientious lender prefers reliable borrower", preferential_lending, true, preferential_lending)

#   ##########################################################################
#   # 5. LENDER – High Neuroticism + Low Agreeableness Avoids Risky Borrower
#   ##########################################################################
#   """
# Traits & Context:
# 	•	Lender: Very high neuroticism (4.5–5.0), low agreeableness (1.0–1.8)
# 	•	Borrower 1: Responsible—steady income, good track record
# 	•	Borrower 2: High risk—unstable income, previous defaults

# Setup Conditions:
# 	•	Borrower 1 and Borrower 2 both request loans within the lender’s capacity (reproductive-age excess sugar).
# 	•	Under credit-sharing rules, lender can distribute loan among borrowers.

# Expected Behavior:
# 	1.	Loans to Borrower 1 are small or maybe moderate, depending on lender’s risk threshold.
# 	2.	Loan to Borrower 2 is declined, despite rule allowing it, due to combined trait effects:
# 	•	Neuroticism → amplified risk aversion
# 	•	Low agreeableness → lack of social trust or inclination to help
#   """

#   @info "🌀 Testing: High Neuroticism + Low Agreeableness Avoids Risky Borrower"

#   credit_model5 = BigFive.sugarscape_llm_bigfive(; dims=(5, 5), N=0, seed=rng_seed,
#     growth_rate=0,
#     vision_dist=(5, 5),
#     metabolic_rate_dist=(0, 0),
#     initial_sugar_dist=(0, 0),
#     enable_credit=true,
#     mvn_dist=dummy_mvn)

#   # Neurotic, disagreeable lender
#   lender5_traits = (Openness=3.0, Conscientiousness=3.0, Extraversion=2.0, Agreeableness=1.5, Neuroticism=4.8)
#   lender5 = BigFive.create_big_five_agent!(
#     credit_model5, (3, 3), 5, 0, 40.0, 25, 100, :male, false, 40.0, Int[], 0.0, BitVector([]),
#     Dict(), Dict(), BitVector[], falses(0), lender5_traits)

#   # Responsible borrower (Borrower 1) - steady, good track record
#   responsible_borrower_traits = (Openness=3.0, Conscientiousness=4.2, Extraversion=3.0, Agreeableness=3.8, Neuroticism=2.0)
#   responsible_borrower = BigFive.create_big_five_agent!(
#     credit_model5, (4, 3), 5, 0, 12.0, 25, 100, :female, false, 18.0, Int[], 0.0, BitVector([]),
#     Dict(), Dict(), BitVector[], falses(0), responsible_borrower_traits)

#   # Risky borrower (Borrower 2) - unstable, poor defaults
#   risky_borrower_traits = (Openness=2.5, Conscientiousness=1.2, Extraversion=3.5, Agreeableness=2.0, Neuroticism=4.0)
#   risky_borrower = BigFive.create_big_five_agent!(
#     credit_model5, (2, 3), 5, 0, 4.0, 25, 100, :male, false, 6.0, Int[], 0.0, BitVector([]),
#     Dict(), Dict(), BitVector[], falses(0), risky_borrower_traits)

#   credit_model5.sugar_values .= 0.0
#   initial_lender5_sugar = lender5.sugar
#   initial_responsible_sugar = responsible_borrower.sugar
#   initial_risky_sugar = risky_borrower.sugar

#   # Simulate both borrowers requesting loans
#   Sugarscape.credit!(lender5, credit_model5)

#   # Check lending behavior
#   responsible_loan_granted = responsible_borrower.sugar > initial_responsible_sugar
#   risky_loan_granted = risky_borrower.sugar > initial_risky_sugar

#   # Neurotic + disagreeable lender should avoid risky borrower, may be cautious with responsible one too
#   risk_averse_behavior = !risky_loan_granted && (responsible_loan_granted == false || (responsible_borrower.sugar - initial_responsible_sugar) <= 10.0)
#   @test log_test_step("Neurotic + disagreeable lender avoids risky borrower", risk_averse_behavior, true, risk_averse_behavior)
# end

@testset "Combat Rule: Trait-Driven" begin
  @info "⚔️ Starting Combat Rule tests..."

  ##########################################################################
  # 1. High Agreeableness Avoids Combat Despite Eligibility
  ##########################################################################
  @info "🌀 Testing: Agent avoids combat despite eligibility"
  """
    Traits: High agreeableness, low neuroticism
      (Openness=3.0, Conscientiousness=3.0, Extraversion=2.0, Agreeableness=5.0, Neuroticism=2.0)
Setup:
  • Agent is eligible to attack: target is weaker, culturally different, and within range
Expectation:
  Despite meeting combat conditions, agent refuses to attack to avoid conflict or harming others.
  """

  model = BigFive.sugarscape_llm_bigfive(; dims=(5, 5), N=0, seed=rng_seed,
    growth_rate=0,                      # disable growback
    vision_dist=(5, 5),                 # deterministic vision
    metabolic_rate_dist=(0, 0),         # no metabolism for clarity
    initial_sugar_dist=(0, 0),          # start with zero sugar
    enable_combat=true,
  )

  model.sugar_values .= 0.0        # blank slate

  # Place agent at position (2, 2)
  agent_pos = (2, 2)
  # Create a traits_row object that matches the expected format
  agent_traits_row = (Openness=3.0, Conscientiousness=3.0, Extraversion=3.0, Agreeableness=5.0, Neuroticism=3.0)
  agent = BigFive.create_big_five_agent!(
    model, agent_pos, 5, 2, 10, 1, 100, :male, false, false, false, 0, Vector{Int}([]), 0, BitVector([1, 0, 0, 1, 0]), Dict{Int,Vector{Sugarscape.Loan}}(), Dict{Int,Vector{Sugarscape.Loan}}(), [BitVector([])], BitVector([]), Vector{Int}(), Vector{Int}(), false, false, false, agent_traits_row)

  # Create a weaker target at position (2, 4) - culturally different and within range
  target_pos = (2, 4)
  model.sugar_values[target_pos...] = 2.0  # some sugar on target cell
  target_traits_row = (Openness=3.0, Conscientiousness=3.0, Extraversion=3.0, Agreeableness=3.0, Neuroticism=3.0)
  target = BigFive.create_big_five_agent!(
    model, target_pos, 3, 1, 2, 1, 100, :female, false, false, false, 0, Vector{Int}([]), 0, BitVector([1, 1, 1, 1, 1]), Dict{Int,Vector{Sugarscape.Loan}}(), Dict{Int,Vector{Sugarscape.Loan}}(), [BitVector([])], BitVector([]), Vector{Int}(), Vector{Int}(), false, false, false, target_traits_row)

  Sugarscape.maybe_combat!(agent, model)

  # Check if agreeable agent avoided combat (target should still exist)
  target_exists = hasid(model, target.id)
  @test log_test_step("Agreeable agent avoided combat despite eligibility", target_exists, true, target_exists)


  ##########################################################################
  # 2. High Conscientiousness Selects Target Strategically
  ##########################################################################
  @info "🌀 Testing: Agent selects target strategically"
  """
Traits: High conscientiousness, moderate agreeableness
    (Openness=3.0, Conscientiousness=5.0, Extraversion=3.0, Agreeableness=3.0, Neuroticism=2.0)
Setup:
  • Two valid targets:
    - Target A: culturally different, very low sugar (less reward)
    - Target B: culturally different, higher sugar, farther away
  • Both satisfy combat rule conditions.
Expectation:
  Agent attacks the target that maximizes utility (e.g., highest sugar relative to distance), showing strategic selectivity.
"""

  model = BigFive.sugarscape_llm_bigfive(; dims=(5, 5), N=0, seed=rng_seed,
    growth_rate=0,                      # disable growback
    vision_dist=(5, 5),                 # deterministic vision
    metabolic_rate_dist=(0, 0),         # no metabolism for clarity
    initial_sugar_dist=(0, 0),          # start with zero sugar
    enable_combat=true,
  )

  model.sugar_values .= 0.0        # blank slate

  # Place agent at center
  agent_pos = (3, 3)
  agent_traits_row = (Openness=3.0, Conscientiousness=5.0, Extraversion=3.0, Agreeableness=3.0, Neuroticism=2.0)
  agent = BigFive.create_big_five_agent!(
    model, agent_pos, 5, 5, 10, 1, 100, :male, false, false, false, 0, Vector{Int}([]), 0, BitVector([0, 0, 0, 0, 0]), Dict{Int,Vector{Sugarscape.Loan}}(), Dict{Int,Vector{Sugarscape.Loan}}(), [BitVector([])], BitVector([]), Vector{Int}(), Vector{Int}(), false, false, false, agent_traits_row)

  # Target A: low sugar, close (position 3,2)
  target_a_pos = (3, 2)
  model.sugar_values[target_a_pos...] = 2.0  # low sugar
  target_a_traits_row = (Openness=3.0, Conscientiousness=3.0, Extraversion=3.0, Agreeableness=1.0, Neuroticism=3.0)
  target_a = BigFive.create_big_five_agent!(
    model, target_a_pos, 3, 1, 0, 1, 100, :female, false, false, false, 0, Vector{Int}([]), 0, BitVector([1, 1, 1, 1, 1]), Dict{Int,Vector{Sugarscape.Loan}}(), Dict{Int,Vector{Sugarscape.Loan}}(), [BitVector([])], BitVector([]), Vector{Int}(), Vector{Int}(), false, false, false, target_a_traits_row)

  # Target B: higher sugar, farther (position 3,5)
  target_b_pos = (3, 5)
  model.sugar_values[target_b_pos...] = 8.0  # higher sugar
  target_b_traits_row = (Openness=1.0, Conscientiousness=1.0, Extraversion=1.0, Agreeableness=2.0, Neuroticism=1.0)
  target_b = BigFive.create_big_five_agent!(
    model, target_b_pos, 3, 1, 0, 1, 100, :female, false, false, false, 0, Vector{Int}([]), 0, BitVector([1, 1, 1, 1, 1]), Dict{Int,Vector{Sugarscape.Loan}}(), Dict{Int,Vector{Sugarscape.Loan}}(), [BitVector([])], BitVector([]), Vector{Int}(), Vector{Int}(), false, false, false, target_b_traits_row)

  Sugarscape.maybe_combat!(agent, model)

  # Check if agent attacked the higher-value target (Target B)
  # Target B should be removed if attacked
  target_b_exists = hasid(model, target_b.id)
  target_a_exists = hasid(model, target_a.id)

  @test log_test_step("Agent strategically selected higher-value target",
    !target_b_exists && target_a_exists, false, (!target_b_exists, target_a_exists))

  ##########################################################################
  # 3. High Openness + High Conscientiousness Selects Less Obvious Target Based on Diversity or Efficiency
  ##########################################################################
  @info "🌀 Testing: Agent selects less obvious target for diversity"
  """
Traits: High openness, high conscientiousness, low neuroticism
(
  Openness=5.0,           # Still very open to novelty and difference
  Conscientiousness=3.5,  # Keeps some planning, but lowers inhibition threshold
  Extraversion=3.0,       # Neutral
  Agreeableness=1.5,      # Low — more tolerant of conflict
  Neuroticism=3.0         # Some emotional reactivity, increases urgency
)

Setup:
  • Two eligible combat targets within vision
    - Target A: closer, culturally similar in 3/5 tags, higher sugar (reward = 8)
    - Target B: farther, culturally different in all 5 tags, lower sugar (reward = 6)
  • Neither target is exposed to retaliation
Expectation:
  Agent prefers Target B due to curiosity, value of novelty, or long-term gain from removing a highly dissimilar agent.
  Demonstrates trade-off reasoning and psychological nuance in combat selection.
"""

  model = BigFive.sugarscape_llm_bigfive(; dims=(5, 5), N=0, seed=rng_seed,
    growth_rate=0,                      # disable growback
    vision_dist=(5, 5),                 # deterministic vision
    metabolic_rate_dist=(0, 0),         # no metabolism for clarity
    initial_sugar_dist=(0, 0),          # start with zero sugar
    enable_combat=true,
  )

  model.sugar_values .= 0.0        # blank slate

  # Place agent at center
  agent_pos = (3, 3)
  agent_traits_row = (Openness=5.0, Conscientiousness=2.0, Extraversion=3.0, Agreeableness=2.0, Neuroticism=2.0)
  agent = BigFive.create_big_five_agent!(
    model, agent_pos, 5, 5, 10, 1, 100, :male, false, false, false, 0, Vector{Int}([]), 0, BitVector([0, 0, 0, 0, 0]), Dict{Int,Vector{Sugarscape.Loan}}(), Dict{Int,Vector{Sugarscape.Loan}}(), [BitVector([])], BitVector([]), Vector{Int}(), Vector{Int}(), false, false, false, agent_traits_row)

  # Target A: closer, culturally similar, higher sugar (position 3,2)
  target_a_pos = (3, 2)
  model.sugar_values[target_a_pos...] = 5.0  # higher sugar
  target_a_traits_row = (Openness=1.0, Conscientiousness=1.0, Extraversion=1.0, Agreeableness=1.0, Neuroticism=5.0)
  target_a = BigFive.create_big_five_agent!(
    model, target_a_pos, 3, 1, 2, 1, 100, :female, false, false, false, 0, Vector{Int}([]), 0, BitVector([0, 0, 1, 1, 1]), Dict{Int,Vector{Sugarscape.Loan}}(), Dict{Int,Vector{Sugarscape.Loan}}(), [BitVector([])], BitVector([]), Vector{Int}(), Vector{Int}(), false, false, false, target_a_traits_row)

  # Target B: farther, culturally different, lower sugar (position 3,5)
  target_b_pos = (3, 5)
  model.sugar_values[target_b_pos...] = 4.0  # lower sugar
  target_b_traits_row = (Openness=3.0, Conscientiousness=1.0, Extraversion=1.0, Agreeableness=3.0, Neuroticism=1.0)
  target_b = BigFive.create_big_five_agent!(
    model, target_b_pos, 3, 1, 2, 1, 100, :female, false, false, false, 0, Vector{Int}([]), 0, BitVector([1, 1, 1, 1, 1]), Dict{Int,Vector{Sugarscape.Loan}}(), Dict{Int,Vector{Sugarscape.Loan}}(), [BitVector([])], BitVector([]), Vector{Int}(), Vector{Int}(), false, false, false, target_b_traits_row)

  Sugarscape.maybe_combat!(agent, model)

  # Check if agent attacked the culturally different target (Target B)
  target_b_exists = hasid(model, target_b.id)
  target_a_exists = hasid(model, target_a.id)

  @test log_test_step("Agent selected culturally different target for diversity",
    !target_b_exists && target_a_exists, false, (!target_b_exists, target_a_exists))


end
