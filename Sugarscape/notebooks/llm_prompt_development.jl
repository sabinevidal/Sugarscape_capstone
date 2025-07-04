### A1: Setup and Imports
using Sugarscape, CairoMakie, JSON

### A2: Environment Check
println("Checking development environment...")
@assert haskey(ENV, "OPENAI_API_KEY") "Set OPENAI_API_KEY environment variable"

### A3: Model Creation
m = Sugarscape.sugarscape(
    use_llm_decisions = true,
    llm_api_key = ENV["OPENAI_API_KEY"],
    llm_temperature = 0.2,
    dims = (20, 20),
    N = 30,
    enable_combat = true,
    enable_reproduction = true,
    enable_credit = true
)

### A4: Prompt Testing
println("Testing LLM prompt...")
Sugarscape.populate_llm_decisions!(m)

# Inspect first few decisions
println("Sample LLM decisions:")
for (i, (agent_id, decision)) in enumerate(first(m.llm_decisions, 3))
    println("Agent $agent_id: ", decision)
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
move_count = count(d -> d.move, values(m.llm_decisions))
combat_count = count(d -> d.combat, values(m.llm_decisions))
println("  Agents moving: $move_count")
println("  Agents in combat: $combat_count")
