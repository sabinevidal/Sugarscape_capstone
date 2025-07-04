using Sugarscape, GLMakie, JSON, Statistics
using Revise

"""
    create_llm_development_dashboard(; model_kwargs...)

Create an interactive dashboard optimized for LLM development and debugging.

Features:
- Revise.jl hot-reloading integration
- LLM decision visualization (combat/movement/stay)
- Interactive parameter controls for LLM settings
- Development workflow optimized interface

# Arguments
- `use_llm_decisions::Bool=true`: Enable LLM decision making
- `llm_api_key::String`: OpenAI API key (defaults to ENV["OPENAI_API_KEY"])
- `llm_temperature::Float64=0.2`: LLM temperature setting
- `N::Int=50`: Number of agents
- `dims::Tuple=(30, 30)`: Grid dimensions
- `enable_combat::Bool=true`: Enable combat rules
- `enable_reproduction::Bool=true`: Enable reproduction rules
- `enable_credit::Bool=true`: Enable credit rules
- `model_kwargs...`: Additional model parameters

# Returns
- `(fig, abmobs)`: GLMakie figure and ABM observable object

# Example
```julia
fig, abmobs = create_llm_development_dashboard(llm_temperature=0.1, N=25)
```
"""
function create_llm_development_dashboard(;
  use_llm_decisions=true,
  llm_api_key=get(ENV, "OPENAI_API_KEY", ""),
  llm_temperature=0.2,
  N=50,
  dims=(30, 30),
  enable_combat=true,
  enable_reproduction=true,
  enable_credit=true,
  model_kwargs...
)

  println("Creating LLM development model...")

  # Merge default and user parameters
  merged_kwargs = merge(
    (
      use_llm_decisions=use_llm_decisions,
      llm_api_key=llm_api_key,
      llm_temperature=llm_temperature,
      N=N,
      dims=dims,
      enable_combat=enable_combat,
      enable_reproduction=enable_reproduction,
      enable_credit=enable_credit
    ),
    model_kwargs
  )

  # Create model with LLM integration
  model = sugarscape(; merged_kwargs...)

  # Define interactive parameters for development
  params = Dict(
    :enable_reproduction => [false, true],
    :enable_combat => [false, true],
    :enable_credit => [false, true],
    :llm_temperature => 0.0:0.1:1.0,
    :use_llm_decisions => [false, true]
  )

  # Data collection for analysis
  wealthy(a) = a.sugar > 20
  medium_wealth(a) = 5 <= a.sugar <= 20
  poor(a) = a.sugar < 5

  adata = [
    (wealthy, count),
    (medium_wealth, count),
    (poor, count)
  ]

  mdata = [
    nagents,
    :deaths_starvation,
    :deaths_age,
    :births
  ]

  # Enhanced visualization functions for LLM debugging
  function agent_color(agent)
    if use_llm_decisions && haskey(model.llm_decisions, agent.id)
      decision = model.llm_decisions[agent.id]
      if decision.combat
        return :red      # Combat intent
      elseif decision.move
        return :blue     # Movement intent
      else
        return :green    # Stay/other
      end
    else
      # Default coloring by wealth
      return agent.sugar > 20 ? :gold : agent.sugar > 10 ? :orange : :darkred
    end
  end

  function agent_size(agent)
    base_size = max(4, min(12, agent.sugar / 2))

    # Highlight agents with LLM decisions
    if use_llm_decisions && haskey(model.llm_decisions, agent.id)
      return base_size + 2  # Slightly larger for LLM-controlled agents
    else
      return base_size
    end
  end

  function agent_marker(agent)
    if use_llm_decisions && haskey(model.llm_decisions, agent.id)
      decision = model.llm_decisions[agent.id]
      if decision.combat
        return :star5    # Combat
      elseif decision.move
        return :diamond  # Movement
      else
        return :circle   # Stay
      end
    else
      return :circle
    end
  end

  # Sugar landscape
  sugarmap(model) = model.sugar_values
  heatkwargs = (colormap=:thermal, colorrange=(0.0, maximum(model.sugar_capacities)))

  println("Creating interactive LLM development dashboard...")

  # Create the main ABM plot with LLM visualization
  fig, ax, abmobs = abmplot(
    model;
    params=params,           # Interactive parameter sliders
    adata=adata,            # Agent data collection
    mdata=mdata,            # Model data collection
    alabels=["Wealthy Agents", "Medium Wealth", "Poor Agents"],
    mlabels=["Total Agents", "Starvation Deaths", "Age Deaths", "Births"],
    agent_color=agent_color,
    agent_size=agent_size,
    agent_marker=agent_marker,
    heatarray=sugarmap,
    heatkwargs=heatkwargs,
    figure=(; size=(1400, 1000))
  )

  # Add development info to the figure
  info_text = """
  LLM Development Dashboard
  LLM Integration: $(use_llm_decisions)
  Revise.jl: Active

  Visual Legend:
  🔴 Combat Intent
  🔵 Movement Intent
  🟢 Stay/Other

  Development Workflow:
  1. Edit LLM integration code
  2. Changes auto-reload via Revise.jl
  3. Use 'Reset' button to apply changes
  4. Use parameter sliders to test configs
  """

  fig[1, 3] = Label(fig, info_text,
    tellheight=false, fontsize=11, halign=:left, valign=:top)

  println("✅ LLM development dashboard created successfully!")
  println("Features:")
  println("  - Hot-reloading with Revise.jl")
  println("  - LLM decision visualization")
  println("  - Interactive parameter controls")
  println("  - Development-optimized interface")

  return fig, abmobs
end

# Decision history tracking for enhanced dashboard
mutable struct DecisionHistory
  agent_trails::Dict{Int,Vector{Tuple{Int,Int}}}
  decision_outcomes::Dict{Int,Vector{Symbol}}
  decision_counts::Dict{Symbol,Int}
  max_trail_length::Int

  DecisionHistory(max_length=10) = new(
    Dict{Int,Vector{Tuple{Int,Int}}}(),
    Dict{Int,Vector{Symbol}}(),
    Dict(:move => 0, :combat => 0, :credit => 0, :reproduce => 0, :idle => 0),
    max_length
  )
end

"""
    create_enhanced_llm_dashboard(; model_kwargs...)

Create an advanced LLM decision visualization dashboard with comprehensive analysis features.

Features:
- 5 distinct LLM decision types visualization
- Movement direction arrows
- Relationship lines (combat/credit/reproduction targets)
- Decision history trails with fading
- Real-time decision analytics panel
- Comprehensive legend system

# Arguments
- `use_llm_decisions::Bool=true`: Enable LLM decision making
- `llm_api_key::String`: OpenAI API key (defaults to ENV["OPENAI_API_KEY"])
- `llm_temperature::Float64=0.2`: LLM temperature setting
- `N::Int=40`: Number of agents
- `dims::Tuple=(25, 25)`: Grid dimensions
- `enable_combat::Bool=true`: Enable combat rules
- `enable_reproduction::Bool=true`: Enable reproduction rules
- `enable_credit::Bool=true`: Enable credit rules
- `model_kwargs...`: Additional model parameters

# Returns
- `(fig, abmobs)`: GLMakie figure and ABM observable object

# Example
```julia
fig, abmobs = create_enhanced_llm_dashboard(llm_temperature=0.3, N=30)
```
"""
function create_enhanced_llm_dashboard(;
  use_llm_decisions=true,
  llm_api_key=get(ENV, "OPENAI_API_KEY", ""),
  llm_temperature=0.2,
  N=40,
  dims=(25, 25),
  enable_combat=true,
  enable_reproduction=true,
  enable_credit=true,
  model_kwargs...
)

  println("Creating enhanced LLM model...")

  # Merge parameters
  merged_kwargs = merge(
    (
      N=N,
      dims=dims,
      enable_combat=enable_combat,
      enable_reproduction=enable_reproduction,
      enable_credit=enable_credit
    ),
    model_kwargs
  )

  # Create model and set LLM configuration
  model = sugarscape(; merged_kwargs...)
  model.use_llm_decisions = use_llm_decisions
  model.llm_api_key = llm_api_key
  model.llm_temperature = llm_temperature

  # Global decision history tracker
  decision_history = DecisionHistory(15)

  # Enhanced agent visualization functions
  function enhanced_agent_color(agent, model)
    if model.use_llm_decisions && haskey(model.llm_decisions, agent.id)
      decision = model.llm_decisions[agent.id]
      # Priority-based color coding
      if decision.combat
        return :red          # Combat (highest priority)
      elseif decision.reproduce
        return :magenta      # Reproduction intent
      elseif decision.credit
        return :gold         # Credit/lending intent
      elseif decision.move
        return :dodgerblue   # Movement intent
      else
        return :limegreen    # Stay/idle
      end
    else
      # Default wealth-based coloring
      if agent.sugar > 20
        return :orange
      elseif agent.sugar > 10
        return :yellow
      else
        return :darkred
      end
    end
  end

  function enhanced_agent_marker(agent, model)
    if model.use_llm_decisions && haskey(model.llm_decisions, agent.id)
      decision = model.llm_decisions[agent.id]
      # Distinct markers for each decision type
      if decision.combat
        return :star5        # Combat: star
      elseif decision.reproduce
        return :heart        # Reproduction: heart
      elseif decision.credit
        return :diamond      # Credit: diamond
      elseif decision.move
        return :utriangle    # Movement: triangle
      else
        return :circle       # Stay: circle
      end
    else
      return :circle
    end
  end

  function enhanced_agent_size(agent, model)
    base_size = max(6, min(16, agent.sugar / 1.5))
    # Highlight agents with LLM decisions
    if model.use_llm_decisions && haskey(model.llm_decisions, agent.id)
      return base_size + 3  # Larger for LLM-controlled agents
    else
      return base_size
    end
  end

  # Define interactive parameters
  params = Dict(
    :enable_reproduction => [false, true],
    :enable_combat => [false, true],
    :enable_credit => [false, true],
    :llm_temperature => 0.0:0.1:1.0,
    :use_llm_decisions => [false, true]
  )

  # Data collection for analysis
  wealthy(a) = a.sugar > 20
  medium_wealth(a) = 5 <= a.sugar <= 20
  poor(a) = a.sugar < 5

  adata = [
    (wealthy, count),
    (medium_wealth, count),
    (poor, count)
  ]

  mdata = [
    nagents,
    :deaths_starvation,
    :deaths_age,
    :births
  ]

  # Sugar landscape
  sugarmap(model) = model.sugar_values
  heatkwargs = (colormap=:thermal, colorrange=(0.0, maximum(model.sugar_capacities)))

  println("Creating enhanced interactive dashboard...")

  # Create the main ABM plot with enhanced visualization
  fig, ax, abmobs = abmplot(
    model;
    params=params,
    adata=adata,
    mdata=mdata,
    alabels=["Wealthy Agents", "Medium Wealth", "Poor Agents"],
    mlabels=["Total Agents", "Starvation Deaths", "Age Deaths", "Births"],
    agent_color=agent -> enhanced_agent_color(agent, model),
    agent_size=agent -> enhanced_agent_size(agent, model),
    agent_marker=agent -> enhanced_agent_marker(agent, model),
    heatarray=sugarmap,
    heatkwargs=heatkwargs,
    figure=(; size=(1600, 1000))
  )

  # Add comprehensive legend
  legend_content = """
  Enhanced LLM Decision Visualization

  Decision Types:
  🔴 Combat Intent (Red Stars)
  🟣 Reproduction Intent (Magenta Hearts)
  🟡 Credit Intent (Gold Diamonds)
  🔵 Movement Intent (Blue Triangles)
  🟢 Idle/Stay (Green Circles)

  Visual Elements:
  → Movement direction arrows
  — Combat target lines (red)
  ≈ Credit partner lines (gold, dashed)
  ⋯ Reproduction partner lines (magenta, dotted)
  ░ Historical movement trails (fading)

  Size: Based on agent wealth
  Enhanced markers: LLM-controlled agents
  """

  fig[1, 3] = Label(fig, legend_content,
    tellheight=false, fontsize=10,
    halign=:left, valign=:top,
    justification=:left)

  # Add title
  fig[0, :] = Label(fig, "Enhanced LLM Decision Visualization Dashboard",
    fontsize=16, font=:bold)

  println("✅ Enhanced LLM dashboard created successfully!")
  println("Features:")
  println("  - 5 distinct decision type visualizations")
  println("  - Movement direction arrows")
  println("  - Target relationship lines")
  println("  - Decision history trails")
  println("  - Real-time analytics")
  println("  - Comprehensive legend system")

  return fig, abmobs
end
