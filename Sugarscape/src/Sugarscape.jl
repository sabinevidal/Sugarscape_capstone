module Sugarscape

using Agents, Random, CairoMakie, Observables, Statistics, Distributions

# Core model components
include("core/agents.jl")
include("core/environment.jl")

# Extensions that add functions used inside model logic
include("rules/movement.jl")
include("rules/credit.jl")
include("rules/disease.jl")
include("rules/reproduction.jl")
include("rules/culture.jl")
include("rules/combat.jl")
include("rules/inheritance.jl")

# Order of includes matters if files depend on each other.
include("utils/metrics.jl")

# ---------------------------------------------------------------------------
#  New split model logic: shared utilities + core rules + LLM-enabled logic  #
# ---------------------------------------------------------------------------

# Shared helper functions (welfare, movement!, death!, …)
include("core/shared.jl")

# Pure rule-based implementation (no LLM)
include("core/model_logic_core.jl")

# LLM-aware implementation that builds on the shared helpers
include("llm/model_logic_llm.jl")

# LLM prompts and schemas
include("llm/prompts_and_schemas.jl")

# LLM integration utilities
include("utils/llm_integration.jl")

# visualisation/plotting.jl depends on the unified sugarscape constructor
# and utils/metrics.jl (for gini_coefficient)
include("visualisation/plotting.jl")

# visualisation/interactive.jl depends on the core model and provides interactive dashboard functionality
include("visualisation/interactive.jl")

# visualisation/dashboard.jl provides debugging dashboard functionality
include("visualisation/dashboard.jl")

# Performance testing utilities
include("visualisation/performance.jl")

# AI dashboards
include("visualisation/ai_dashboards.jl")

# Public API
export SugarscapeAgent
export sugarscape

export gini_coefficient, morans_i

# Export visualization and recording functions
export run_sugarscape_visualization
export record_wealth_hist_animation
export create_custom_dashboard
export create_reproduction_dashboard
export create_dashboard

# Export Movement functions
export build_agent_movement_context

# Export reproduction functions
export reproduction!, is_fertile, is_fertile_by_age

# Export culture functions
export culture_spread!, cultural_entropy, unique_cultures, mean_hamming_distance, cultural_islands

# Export combat functions
export combat!, combat_death_rate, average_combat_reward, cultural_conflict_intensity, wealth_based_dominance

# Export inheritance functions
export distribute_inheritance, get_inheritance_metrics, calculate_inheritance_concentration

# Export disease functions
export disease_transmission!, immune_response!

# Export credit functions
export make_loans!, pay_loans!, clear_loans_on_death!

# Export LLM integration functions
export get_decision, try_llm_move!, llm_move!
export LLMDecision
export get_individual_agent_decision_with_retry
export _agent_step_llm!, _model_step_llm!

# export decision helpers
export get_reproduction_decision, get_movement_decision

# Export testing functions
export test_single_agent_llm_prompt, run_llm_prompt_test_interactive
export test_single_agent_prompt

# Export performance testing functions
export run_performance_test_interactive

# Export AI dashboard functions
export create_ai_dashboard

# Export culture testing functions
export tribe

# Export disease testing functions (private function but used in tests)
export _subseq

end # module Sugarscape
