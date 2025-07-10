module Sugarscape

using Agents, Random, CairoMakie, Observables, Statistics, Distributions

# Core model components
include("core/agents.jl")
include("core/environment.jl")

# Extensions that add functions used inside model logic
include("extensions/credit.jl")
include("extensions/disease.jl")
include("extensions/reproduction.jl")
include("extensions/culture.jl")
include("extensions/combat.jl")
include("extensions/inheritance.jl")

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

"""
    sugarscape(; kwargs...) → StandardABM

Unified constructor that dispatches to the pure rule-based implementation or
the LLM-aware implementation depending on the `use_llm_decisions` keyword (or
the `SUGARSCAPE_USE_LLM` environment variable).  All other keyword arguments
are forwarded unchanged to the selected backend.
"""
function sugarscape(; kwargs...)
  # Determine whether to use the LLM backend.
  env_override = get(ENV, "SUGARSCAPE_USE_LLM", "false") == "true"
  use_llm = haskey(kwargs, :use_llm_decisions) ? kwargs[:use_llm_decisions] : env_override

  if use_llm
    return sugarscape_llm(; kwargs...)
  else
    # Remove possible LLM-specific kwargs to avoid MethodErrors
    clean_kwargs = filter(p -> p.first != :use_llm_decisions, collect(kwargs))
    return sugarscape_core(; clean_kwargs...)
  end
end

# LLM integration utilities (populate_llm_decisions!)
include("utils/llm_integration.jl")
using .SugarscapeLLM: populate_llm_decisions!

# visualisation/plotting.jl depends on the unified sugarscape constructor
# and utils/metrics.jl (for gini_coefficient)
include("visualisation/plotting.jl")

# visualisation/interactive.jl depends on the core model and provides interactive dashboard functionality
include("visualisation/interactive.jl")

# visualisation/dashboard.jl provides debugging dashboard functionality
include("visualisation/dashboard.jl")

# Testing utilities for LLM integration
include("visualisation/testing.jl")

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

# Export reproduction functions
export reproduction!, is_fertile

# Export culture functions
export culture_spread!, cultural_entropy, unique_cultures, mean_hamming_distance, cultural_islands

# Export combat functions
export combat!, combat_death_rate, average_combat_reward, cultural_conflict_intensity, wealth_based_dominance

# Export inheritance functions
export distribute_inheritance, get_inheritance_metrics, calculate_inheritance_concentration

# Export disease functions
export disease_transmission!, immune_response!

# Export credit functions
export make_loans!, pay_loans!

# Export LLM integration functions
export get_decision, try_llm_move!
export LLMDecision

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
