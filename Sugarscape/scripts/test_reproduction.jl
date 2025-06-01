using Agents
using Random, Distributions

# Import only the core components
include("../src/core/agents.jl")
include("../src/core/environment.jl")
include("../src/core/model_logic.jl")
include("../src/extensions/reproduction.jl")

# Test reproduction functionality
function test_reproduction_core()
  println("Testing Sugarscape reproduction (core only)...")

  # Create a small model with reproduction enabled
  model = sugarscape(
    dims=(10, 10),
    N=20,  # Small number of agents
    enable_reproduction=true,
    fertility_age_range=(5, 30),  # Broader age range for testing
    initial_child_sugar=4,
    seed=123
  )

  println("Model created successfully!")
  println("Initial agents: ", nagents(model))

  # Check that agents have the required fields
  test_agent = first(allagents(model))
  println("Test agent fields:")
  println("  ID: ", test_agent.id)
  println("  Age: ", test_agent.age)
  println("  Sex: ", test_agent.sex)
  println("  Has mated: ", test_agent.has_mated)

  # Test is_fertile function
  young_agents = [a for a in allagents(model) if is_fertile(a, model)]
  println("Fertile agents: ", length(young_agents), " out of ", nagents(model))

  # Run a few steps
  println("\nRunning simulation steps...")
  for step in 1:5
    step!(model)
    println("Step $step: ", nagents(model), " agents")

    # Check for any agents with negative sugar
    negative_sugar_agents = [a for a in allagents(model) if a.sugar < 0]
    if !isempty(negative_sugar_agents)
      println("  WARNING: ", length(negative_sugar_agents), " agents with negative sugar!")
    end
  end

  println("Test completed successfully!")
  return model
end

# Run the test
test_model = test_reproduction_core()
