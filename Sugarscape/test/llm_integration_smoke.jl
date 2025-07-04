using Test
using Sugarscape
using Agents

# Mock call_openai_api to return valid JSON without network calls
const LLM = Sugarscape.SugarscapeLLM
function LLM.call_openai_api(contexts::Vector, model)
  # Return mock decisions that match the expected JSON structure
  return [Dict(
    "move" => false,
    "move_coords" => nothing,
    "combat" => false,
    "combat_target" => nothing,
    "credit" => false,
    "credit_partner" => nothing,
    "reproduce" => false,
    "reproduce_with" => nothing
  ) for _ in contexts]
end

@testset "LLM enabled smoke run" begin
  model = Sugarscape.sugarscape(; dims=(10, 10), N=4, seed=42,
    growth_rate=0)
  model.use_llm_decisions = true
  step!(model, 5)
  @test abmtime(model) == 5
end
