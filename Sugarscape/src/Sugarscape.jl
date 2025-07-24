module Sugarscape

using Agents, Random, CairoMakie, Observables, Statistics, Distributions

# Core model components
include("core/agents.jl")
include("core/environment.jl")
# Personality trait agent definitions
include("psychological_dimensions/big_five/big_five_processor.jl")
include("psychological_dimensions/big_five/big_five.jl")
include("psychological_dimensions/schwartz_values/schwartz_values_processor.jl")
include("psychological_dimensions/schwartz_values/schwartz_values.jl")

# Import the modules
using .BigFive
using .BigFiveProcessor
using .SchwartzValues
using .SchwartzValuesProcessor

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
include("utils/metrics_sets.jl")
include("visualisation/analytics.jl")

# ---------------------------------------------------------------------------
#  New split model logic: shared utilities + core rules + LLM-enabled logic  #
# ---------------------------------------------------------------------------

# Shared helper functions (welfare, movement!, death!, …)
include("core/shared.jl")

# Pure rule-based implementation (no LLM)
include("core/model_logic_core.jl")

# LLM-aware implementation that builds on the shared helpers
include("llm/model_logic_llm.jl")

include("core/model.jl")

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

# Core Types and Functions
export SugarscapeAgent, sugarscape

# Psychological Dimensions
## Big Five
export BigFiveSugarscapeAgent, prepare_big_five_traits, create_big_five_agent!, sugarscape_llm_bigfive, build_big_five_movement_context
export get_big_five_system_prompt, get_big_five_reproduction_system_prompt, get_big_five_culture_system_prompt
export get_big_five_movement_system_prompt, get_big_five_credit_lender_offer_system_prompt
export get_big_five_credit_lender_respond_system_prompt, get_big_five_credit_borrower_request_system_prompt

export get_big_five_credit_borrower_respond_system_prompt

## Schwartz Values
export SchwartzValuesSugarscapeAgent, build_schwartz_values_movement_context, build_schwartz_values_reproduction_context, sugarscape_llm_schwartz
export get_schwartz_values_system_prompt, get_schwartz_values_movement_system_prompt
export get_schwartz_values_reproduction_system_prompt, process_ess_schwartz_values, load_processed_schwartz_values

# Utility Functions
export gini_coefficient, morans_i

# Metrics
export reproduction_metrics, combat_metrics, culture_metrics, credit_metrics
export reproduction_combat_metrics, reproduction_culture_metrics, credit_reproduction_metrics
export culture_credit_metrics, full_stack_metrics

# Analytics
export Analytics, export_to_csv, create_analytics_pipeline

# Export visualization and recording functions
export record_wealth_hist_animation
export create_custom_dashboard
export create_reproduction_dashboard
export create_dashboard
export create_simple_dashboard

# Export Movement functions

# Export reproduction functions
export reproduction!, is_fertile, is_fertile_by_age

# Export culture functions
export culture_spread!, cultural_entropy, unique_cultures, mean_hamming_distance, cultural_islands

# Export combat functions
export maybe_combat!, combat_death_rate, average_combat_reward, cultural_conflict_intensity, wealth_based_dominance

# Export inheritance functions
export distribute_inheritance, get_inheritance_metrics, calculate_inheritance_concentration

# Export disease functions
export disease_transmission!, immune_response!

# Export credit functions
export credit!, clear_loans_on_death!, will_borrow, can_lend

# Export LLM integration functions
export get_decision
export LLMDecision
export _agent_step_llm!, _model_step_llm!

# Decision Helpers
export get_reproduction_decision, get_movement_decision, get_combat_decision

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
