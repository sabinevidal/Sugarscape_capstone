#!/usr/bin/env julia

println("=== Enhanced LLM Decision Visualization Dashboard ===")
println("Starting advanced dashboard with comprehensive LLM visual feedback...")

# Load Revise first for hot-reloading
using Revise
using Sugarscape, GLMakie, JSON
using Statistics

# Decision history tracking structure
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

# Global decision history tracker
decision_history = DecisionHistory(15)

function enhanced_agent_color(agent, model)
  if model.use_llm_decisions && haskey(model.llm_decisions, agent.id)
    decision = model.llm_decisions[agent.id]

    # Priority-based color coding (highest priority first)
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

function update_decision_history!(history, model)
  """Update decision trails and statistics"""

  # Reset current counts
  for key in keys(history.decision_counts)
    history.decision_counts[key] = 0
  end

  for agent in Sugarscape.allagents(model)
    agent_id = agent.id

    # Initialize if new agent
    if !haskey(history.agent_trails, agent_id)
      history.agent_trails[agent_id] = [agent.pos]
      history.decision_outcomes[agent_id] = []
    else
      # Add current position to trail
      push!(history.agent_trails[agent_id], agent.pos)

      # Limit trail length
      if length(history.agent_trails[agent_id]) > history.max_trail_length
        popfirst!(history.agent_trails[agent_id])
        if !isempty(history.decision_outcomes[agent_id])
          popfirst!(history.decision_outcomes[agent_id])
        end
      end
    end

    # Count current decisions
    if model.use_llm_decisions && haskey(model.llm_decisions, agent_id)
      decision = model.llm_decisions[agent_id]
      if decision.combat
        history.decision_counts[:combat] += 1
      elseif decision.reproduce
        history.decision_counts[:reproduce] += 1
      elseif decision.credit
        history.decision_counts[:credit] += 1
      elseif decision.move
        history.decision_counts[:move] += 1
      else
        history.decision_counts[:idle] += 1
      end
    end
  end
end

function add_movement_arrows!(ax, model)
  """Add directional arrows for agents with movement intent"""

  arrow_starts_x = Float64[]
  arrow_starts_y = Float64[]
  arrow_directions_x = Float64[]
  arrow_directions_y = Float64[]

  for agent in Sugarscape.allagents(model)
    if model.use_llm_decisions && haskey(model.llm_decisions, agent.id)
      decision = model.llm_decisions[agent.id]
      if decision.move && decision.move_coords !== nothing
        # Calculate arrow direction
        start_x, start_y = agent.pos
        target_x, target_y = decision.move_coords

        # Direction vector (normalized for consistent arrow size)
        dx = target_x - start_x
        dy = target_y - start_y
        length = sqrt(dx^2 + dy^2)

        if length > 0
          # Normalize and scale
          scale = 0.8
          dx_norm = (dx / length) * scale
          dy_norm = (dy / length) * scale

          push!(arrow_starts_x, start_x)
          push!(arrow_starts_y, start_y)
          push!(arrow_directions_x, dx_norm)
          push!(arrow_directions_y, dy_norm)
        end
      end
    end
  end

  if !isempty(arrow_starts_x)
    arrows!(ax, arrow_starts_x, arrow_starts_y, arrow_directions_x, arrow_directions_y,
      color=:blue, arrowsize=12, linewidth=2, alpha=0.8)
  end
end

function add_target_relationship_lines!(ax, model)
  """Add lines showing relationships between agents"""

  for agent in Sugarscape.allagents(model)
    if model.use_llm_decisions && haskey(model.llm_decisions, agent.id)
      decision = model.llm_decisions[agent.id]

      # Combat target lines (red, solid)
      if decision.combat && decision.combat_target !== nothing
        target_agents = [a for a in Sugarscape.allagents(model) if a.id == decision.combat_target]
        if !isempty(target_agents)
          target = target_agents[1]
          lines!(ax, [agent.pos[1], target.pos[1]], [agent.pos[2], target.pos[2]],
            color=:red, linewidth=3, alpha=0.6)
        end
      end

      # Credit partner lines (gold, dashed)
      if decision.credit && decision.credit_partner !== nothing
        partner_agents = [a for a in Sugarscape.allagents(model) if a.id == decision.credit_partner]
        if !isempty(partner_agents)
          partner = partner_agents[1]
          lines!(ax, [agent.pos[1], partner.pos[1]], [agent.pos[2], partner.pos[2]],
            color=:gold, linewidth=2, alpha=0.7, linestyle=:dash)
        end
      end

      # Reproduction partner lines (magenta, dotted)
      if decision.reproduce && decision.reproduce_with !== nothing
        partner_agents = [a for a in Sugarscape.allagents(model) if a.id == decision.reproduce_with]
        if !isempty(partner_agents)
          partner = partner_agents[1]
          lines!(ax, [agent.pos[1], partner.pos[1]], [agent.pos[2], partner.pos[2]],
            color=:magenta, linewidth=2, alpha=0.7, linestyle=:dot)
        end
      end
    end
  end
end

function add_decision_trails!(ax, history)
  """Draw historical movement trails with fading effect"""

  for (agent_id, trail) in history.agent_trails
    if length(trail) > 1
      # Draw trail with fading alpha
      for i in 1:(length(trail)-1)
        alpha = (i / length(trail)) * 0.3  # Fade older positions
        lines!(ax, [trail[i][1], trail[i+1][1]], [trail[i][2], trail[i+1][2]],
          color=(:gray, alpha), linewidth=1)
      end
    end
  end
end

function create_decision_analytics_panel(fig, history)
  """Create real-time decision analytics panel"""

  # Decision distribution bar chart
  analytics_ax = Axis(fig[1, 3],
    title="LLM Decision Distribution",
    xlabel="Decision Type",
    ylabel="Count")

  decision_types = ["Move", "Combat", "Credit", "Reproduce", "Idle"]
  decision_counts = [
    history.decision_counts[:move],
    history.decision_counts[:combat],
    history.decision_counts[:credit],
    history.decision_counts[:reproduce],
    history.decision_counts[:idle]
  ]

  colors = [:dodgerblue, :red, :gold, :magenta, :limegreen]

  barplot!(analytics_ax, 1:5, decision_counts, color=colors)
  analytics_ax.xticks = (1:5, decision_types)
  analytics_ax.xticklabelrotation = π / 4

  # Add percentage labels
  total_decisions = sum(decision_counts)
  if total_decisions > 0
    for (i, count) in enumerate(decision_counts)
      percentage = round((count / total_decisions) * 100, digits=1)
      text!(analytics_ax, i, count + 0.5, text="$count\n($percentage%)",
        align=(:center, :bottom), fontsize=10)
    end
  end

  return analytics_ax
end

function create_decision_legend(fig)
  """Create comprehensive legend for decision visualization"""

  legend_content = """
  Movement Intent (Blue)
  Combat Intent (Red)
  Credit Intent (Gold)
  Reproduction Intent (Magenta)
  Idle/Stay (Green)

  Relationships:
  --- Combat Target (Red)
  --- Credit Partner (Gold)
  ... Reproduce Partner (Magenta)
  --> Movement Direction (Blue)

  Markers:
  Triangle: Movement
  Star: Combat
  Diamond: Credit
  Heart: Reproduction
  Circle: Idle/Stay

  Trails: Gray fading paths
  Size: Based on agent wealth
  """

  fig[2, 3] = Label(fig, legend_content,
    tellheight=false, fontsize=10,
    halign=:left, valign=:top,
    justification=:left)
end

function create_enhanced_dashboard(;
  use_llm_decisions=true,
  llm_api_key=get(ENV, "OPENAI_API_KEY", ""),
  llm_temperature=0.2,
  N=40,
  dims=(25, 25),
  enable_combat=true,
  enable_reproduction=true,
  enable_credit=true
)

  println("Creating enhanced model with LLM integration...")

  # Create model (note: need to set LLM properties after creation)
  model = Sugarscape.sugarscape(;
    N=N,
    dims=dims,
    enable_combat=enable_combat,
    enable_reproduction=enable_reproduction,
    enable_credit=enable_credit
  )

  # Set LLM configuration
  model.use_llm_decisions = use_llm_decisions
  model.llm_api_key = llm_api_key
  model.llm_temperature = llm_temperature

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
    Sugarscape.nagents,
    :deaths_starvation,
    :deaths_age,
    :births
  ]

  # Sugar landscape
  sugarmap(model) = model.sugar_values
  heatkwargs = (colormap=:thermal, colorrange=(0.0, maximum(model.sugar_capacities)))

  println("Creating enhanced interactive dashboard...")

  # Create the main ABM plot with enhanced visualization
  fig, ax, abmobs = Sugarscape.abmplot(
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

  # Create decision analytics panel
  analytics_ax = create_decision_analytics_panel(fig, decision_history)

  # Create legend
  create_decision_legend(fig)

  # Add enhanced visualizations that update each step
  on(abmobs.model) do model
    # Update decision history
    update_decision_history!(decision_history, model)

    # Clear and redraw enhanced overlays
    empty!(ax.scene.plots[end-3:end])  # Remove previous overlays

    # Add movement arrows
    add_movement_arrows!(ax, model)

    # Add relationship lines
    add_target_relationship_lines!(ax, model)

    # Add decision trails
    add_decision_trails!(ax, decision_history)

    # Update analytics
    empty!(analytics_ax)
    decision_types = ["Move", "Combat", "Credit", "Reproduce", "Idle"]
    decision_counts = [
      decision_history.decision_counts[:move],
      decision_history.decision_counts[:combat],
      decision_history.decision_counts[:credit],
      decision_history.decision_counts[:reproduce],
      decision_history.decision_counts[:idle]
    ]
    colors = [:dodgerblue, :red, :gold, :magenta, :limegreen]

    barplot!(analytics_ax, 1:5, decision_counts, color=colors)

    # Add percentage labels
    total_decisions = sum(decision_counts)
    if total_decisions > 0
      for (i, count) in enumerate(decision_counts)
        percentage = round((count / total_decisions) * 100, digits=1)
        text!(analytics_ax, i, count + 0.1, text="$count\n($percentage%)",
          align=(:center, :bottom), fontsize=9)
      end
    end
  end

  # Add title and info
  fig[0, :] = Label(fig, "Enhanced LLM Decision Visualization Dashboard",
    fontsize=16, font=:bold)

  return fig, abmobs
end

# Create and launch the enhanced dashboard
println("✓ Initializing enhanced dashboard...")

# Initialize variables at global scope
fig = nothing
abmobs = nothing

try
  global fig, abmobs
  fig, abmobs = create_enhanced_dashboard(;
    use_llm_decisions=true,
    llm_api_key=get(ENV, "OPENAI_API_KEY", ""),
    llm_temperature=0.2,
    N=40,
    dims=(25, 25),
    enable_combat=true,
    enable_reproduction=true,
    enable_credit=true
  )

  # Display the dashboard
  display(fig)

  println("✓ Enhanced dashboard loaded successfully!")
  println("✓ LLM integration enabled with comprehensive visualization")
  println("✓ Revise.jl active - edit src/utils/llm_integration.jl for hot-reload")
  println()
  println("Enhanced Features:")
  println("  * Granular decision type visualization (5 distinct types)")
  println("  * Movement direction arrows")
  println("  * Target relationship lines (combat/credit/reproduction)")
  println("  * Real-time decision analytics panel")
  println("  * Historical movement trails with fading")
  println("  * Interactive parameter controls")
  println()
  println("Visual Legend:")
  println("  * Movement Intent -> Blue triangles with direction arrows")
  println("  * Combat Intent -> Red stars with target lines")
  println("  * Credit Intent -> Gold diamonds with partner lines")
  println("  * Reproduction Intent -> Magenta hearts with partner lines")
  println("  * Idle Intent -> Green circles")
  println()
  println("Dashboard Controls:")
  println("  * Step: Advance simulation and update all visualizations")
  println("  * Run/Stop: Continuous simulation with real-time updates")
  println("  * Reset: Restart with current code (triggers Revise reload)")
  println("  * Parameter Sliders: Test different LLM/model configurations")
  println()
  println("Development Workflow:")
  println("  1. Edit LLM prompts/logic in src/utils/llm_integration.jl")
  println("  2. Save file (Revise auto-detects changes)")
  println("  3. Click 'Reset' to apply changes")
  println("  4. Observe decision pattern changes in real-time")
  println("  5. Use analytics panel to quantify decision distributions")

catch e
  println("✗ Error creating enhanced dashboard: ", e)
  println("Check that all dependencies are installed and LLM integration is properly configured")
end

# Keep the script alive in non-interactive mode
if !isinteractive()
  println("\nRunning in non-interactive mode. Keeping script alive...")
  if fig !== nothing
    try
      while GLMakie.isopen(fig.scene)
        sleep(0.1)
      end
    catch e
      if e isa InterruptException
        println("Interrupted by user (Ctrl+C).")
      else
        rethrow()
      end
    end
    println("Dashboard window closed. Exiting script.")
  else
    println("Dashboard failed to initialize. Exiting.")
  end
end
