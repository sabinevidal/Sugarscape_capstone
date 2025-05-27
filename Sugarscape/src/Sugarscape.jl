module Sugarscape

using Agents, Random, CairoMakie, Observables, Statistics, Distributions

# Core model components
include("core/agents.jl")
include("core/environment.jl")
# model_logic.jl needs access to SugarSeeker, sugar_caps, grow_sugar!
# metrics.jl might be needed by model_logic or plotting
# plotting.jl needs sugarscape, gini_coefficient, etc.

# Order of includes matters if files depend on each other.
# utils should be fairly independent or depend only on Agents/Julia Base.
include("utils/metrics.jl")

# core/model_logic.jl depends on core/agents.jl and core/environment.jl (for types and functions)
# and utils/metrics.jl if any metrics are used within model logic directly (not the case here)
include("core/model_logic.jl")

# visualisation/plotting.jl depends on core/model_logic.jl (for sugarscape constructor)
# and utils/metrics.jl (for gini_coefficient)
include("visualisation/plotting.jl")


# Public API
export SugarSeeker # Exporting the agent type
export sugarscape # Exporting the main model constructor

# Exporting stepping functions if they are intended to be called directly by users,
# but typically they are internal to the StandardABM constructor.
# export agent_step!, model_step! # (Original names, if you want to export the wrappers)
# Or, if you don't export them, they are internal.

export gini_coefficient, morans_i # Export utility functions

# Export visualization and recording functions
export run_sugarscape_visualization
export record_sugarscape_animation
export record_wealth_hist_animation

# Directory for future extensions - can be structured with submodules
# Example: include("extensions/TradingExtension.jl")
# module TradingExtension
#   ...
# end
# export TradingExtension

end # module Sugarscape
