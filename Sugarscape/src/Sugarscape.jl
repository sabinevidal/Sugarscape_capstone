module Sugarscape

using Agents, Random, CairoMakie, Observables, Statistics, Distributions

# Core model components
include("core/agents.jl")
include("core/environment.jl")

# Order of includes matters if files depend on each other.
include("utils/metrics.jl")

# core/model_logic.jl depends on core/agents.jl and core/environment.jl (for types and functions)
# and utils/metrics.jl if any metrics are used within model logic directly (not the case here)
include("core/model_logic.jl")

# visualisation/plotting.jl depends on core/model_logic.jl (for sugarscape constructor)
# and utils/metrics.jl (for gini_coefficient)
include("visualisation/plotting.jl")

# visualisation/interactive.jl depends on the core model and provides interactive dashboard functionality
include("visualisation/interactive.jl")

# Public API
export SugarscapeAgent
export sugarscape

export gini_coefficient, morans_i

# Export visualization and recording functions
export run_sugarscape_visualization
export record_sugarscape_animation
export record_wealth_hist_animation
export create_custom_dashboard
export create_reproduction_dashboard

# Extensions
include("extensions/reproduction.jl")

# Export reproduction functions
export mating!, is_fertile

end # module Sugarscape
