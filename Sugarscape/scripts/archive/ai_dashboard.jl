#!/usr/bin/env julia

println("=== Development Dashboard ===")
println("Starting dashboard with Revise.jl integration...")

# Load Revise first for hot-reloading
using Revise
using Sugarscape, GLMakie, JSON

function create_dev_dashboard(;
    use_llm_decisions = true,
    llm_api_key = get(ENV, "OPENAI_API_KEY", ""),
    llm_temperature = 0.2,
    N = 50,
    dims = (30, 30),
    enable_combat = true,
    enable_reproduction = true,
    enable_credit = true
)
    
    println("Creating development model...")
    
    # Create model with LLM integration
    model = Sugarscape.sugarscape(;
        use_llm_decisions = use_llm_decisions,
        llm_api_key = llm_api_key,
        llm_temperature = llm_temperature,
        N = N,
        dims = dims,
        enable_combat = enable_combat,
        enable_reproduction = enable_reproduction,
        enable_credit = enable_credit
    )
    
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
        (poor, a) -> count(a)
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
    
    println("Creating interactive dashboard...")
    
    # CRITICAL: Use abmplot with params for interactive controls
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
    fig[1, 3] = Label(fig, "Development Dashboard\nLLM Integration: $(use_llm_decisions)\nRevise.jl: Active\n\nLegend:\n🔴 Combat Intent\n🔵 Movement Intent\n🟢 Stay/Other", 
                     tellheight=false, fontsize=12, halign=:left, valign=:top)
    
    return fig, abmobs
end

# Create dashboard
println("✓ Initializing development dashboard...")

fig, abmobs = create_dev_dashboard(;
    use_llm_decisions = true,
    llm_api_key = get(ENV, "OPENAI_API_KEY", ""),
    llm_temperature = 0.2,
    N = 50,
    dims = (30, 30),
    enable_combat = true,
    enable_reproduction = true,
    enable_credit = true
)

# Display the dashboard
display(fig)
display(abmobs)

println("✓ Dashboard loaded successfully")
println("✓ LLM integration enabled")
println("✓ Revise.jl active - edit src/utils/llm_integration.jl and use parameter sliders")
println()
println("Dashboard controls:")
println("  - Step: Advance one simulation step")
println("  - Run/Stop: Continuous simulation")
println("  - Reset: Restart with current code")
println("  - Parameter Sliders: Adjust model settings")
println()
println("Visual indicators:")
println("  - Red agents: Combat intent (LLM)")
println("  - Blue agents: Movement intent (LLM)")  
println("  - Green agents: Stay/other (LLM)")
println("  - Gold/Orange/Dark red: Wealth levels (rule-based)")
println()
println("Development workflow:")
println("  1. Edit LLM integration code in src/utils/llm_integration.jl")
println("  2. Changes auto-reload via Revise.jl")
println("  3. Use 'Reset' button to apply changes")
println("  4. Use parameter sliders to test different configurations")

# Keep the script alive while the GLMakie window is open
if !isinteractive()
    println("Running in non-interactive mode. Keeping script alive...")
    try
        while GLMakie.isopen(fig.scene)
            sleep(0.1) # Keep the loop from busy-waiting
        end
    catch e
        if e isa InterruptException
            println("Interrupted by user (Ctrl+C).")
        else
            rethrow()
        end
    end
    println("Dashboard window closed or loop interrupted. Exiting script.")
end
