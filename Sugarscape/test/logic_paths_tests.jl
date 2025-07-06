using Test, Sugarscape

@testset "Model logic path constructors" begin
  # Pure rule-based model should build without LLM artefacts
  core_model = Sugarscape.sugarscape_core()
  @test !core_model.use_llm_decisions

  # LLM-enabled model should also build when decision-making is disabled (avoids API calls)
  llm_model = Sugarscape.sugarscape_llm(use_llm_decisions=false)
  @test llm_model.use_llm_decisions == false
  @test haskey(llm_model.properties, :llm_decisions)
end
