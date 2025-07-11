### A1: Setup and Imports
using Sugarscape, CairoMakie, JSON

### A2: Environment Check
println("Checking development environment...")
@assert haskey(ENV, "OPENAI_API_KEY") "Set OPENAI_API_KEY environment variable"

### A3: Model Creation
m = Sugarscape.sugarscape(
    use_llm_decisions=true,
    llm_api_key=ENV["OPENAI_API_KEY"],
    llm_temperature=0.2,
    dims=(20, 20),
    N=30,
    enable_combat=true,
    enable_reproduction=true,
    enable_credit=true
)

### A4: Individual Agent Decision Testing
println("Testing individual LLM decisions...")

# Get decisions for a few agents individually
agents = collect(Sugarscape.allagents(m))
println("Sample LLM decisions:")
for (i, agent) in enumerate(agents[1:3])
    decision = Sugarscape.SugarscapeLLM.get_individual_agent_decision_with_retry(agent, m)
    println("Agent $(agent.id): ", decision)
end

### A5: Visual Feedback
fig, _ = Sugarscape.abmplot(m)
fig

### A6: Step Simulation
println("Stepping simulation...")
step!(m, 10)

# Check results
println("Agents after 10 steps: ", length(Sugarscape.allagents(m)))
println("Total sugar: ", sum(a.sugar for a in Sugarscape.allagents(m)))

### A7: Decision Analysis
println("Decision analysis:")
# Get decisions for all agents
decisions = Dict{Int,Any}()
for agent in Sugarscape.allagents(m)
    try
        decision = Sugarscape.SugarscapeLLM.get_individual_agent_decision_with_retry(agent, m)
        decisions[agent.id] = decision
    catch e
        println("Failed to get decision for agent $(agent.id): $(e)")
    end
end

move_count = count(d -> d.move, values(decisions))
combat_count = count(d -> d.combat, values(decisions))
println("  Agents moving: $move_count")
println("  Agents in combat: $combat_count")
println("  Total decisions obtained: $(length(decisions))")
