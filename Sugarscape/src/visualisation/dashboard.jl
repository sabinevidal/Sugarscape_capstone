using Sugarscape

using Agents
using GLMakie

using DataFrames
using CSV
using Observables
using Statistics
using Dates

"""
    create_dashboard(; model_kwargs...)

Creates an interactive dashboard for the Sugarscape model with:
- Interactive parameters to enable/disable different rules (reproduction, culture, combat)
- Agent state table monitoring with CSV export
- Pausing/stepping through time controls
- Real-time visualization of the world state
"""
function create_dashboard()
  # Initialize model with all rules disabled by default for debugging
  initial_model = sugarscape(;
    dims=(30, 30),
    N=100,
    enable_reproduction=false,
    enable_culture=false,
    enable_combat=false,
    enable_pollution=false,
    seed=42
  )

  # Define interactive parameters for rules
  params = Dict(
    :enable_reproduction => [false, true],
    :enable_culture => [false, true],
    :enable_combat => [false, true],
    :enable_pollution => [false, true],
    :growth_rate => 0.5:0.1:2.0,
    :season_duration => 10:5:50,
    :combat_limit => 10:10:100,
    :culture_copy_prob => 0.0:0.05:1.0
  )

  # Define aggregated agent data to collect (abmexploration only supports aggregated data)
  wealthy(a) = a.sugar > 20
  medium_wealth(a) = 5 <= a.sugar <= 20
  poor(a) = a.sugar < 5
  elderly(a) = a.age > 50
  young(a) = a.age < 20
  male(a) = a.sex == :male
  female(a) = a.sex == :female
  mated(a) = a.has_mated

  adata = [
    (wealthy, count),
    (medium_wealth, count),
    (poor, count),
    (elderly, count),
    (young, count),
    (male, count),
    (female, count),
    (mated, count)
  ]

  # Define model data to collect
  mdata = [
    nagents,
    :deaths_starvation,
    :deaths_age,
    :births,
    :combat_kills,
    :combat_sugar_stolen,
    model -> gini_coefficient([a.sugar for a in allagents(model)]),
    model -> mean([a.sugar for a in allagents(model)]),
    model -> sum(model.sugar_values),
    model -> model.enable_culture ? (hasmethod(cultural_entropy, (typeof(model),)) ? cultural_entropy(model) : 0.0) : 0.0
  ]

  # Agent visualization functions
  agent_color(agent) = begin
    if agent.sugar > 20
      :gold
    elseif agent.sugar > 10
      :orange
    elseif agent.sugar > 5
      :yellow
    else
      :red
    end
  end

  agent_size(agent) = max(4, min(12, agent.sugar / 2))

  # Sugar landscape heatmap
  sugarmap(model) = model.sugar_values
  max_sugar_capacity = maximum(initial_model.sugar_capacities)

  heatkwargs = (
    colormap=:thermal,
    colorrange=(0.0, max_sugar_capacity)
  )

  # Create the main interactive exploration interface
  fig, ax, abmobs = abmplot(
    initial_model;
    params=params,
    adata=adata,
    mdata=mdata,
    alabels=["Wealthy Agents", "Medium Wealth", "Poor Agents", "Elderly",
      "Young", "Males", "Females", "Mated"],
    mlabels=["Agents", "Starvation Deaths", "Age Deaths", "Births",
      "Combat Kills", "Sugar Stolen", "Gini Coefficient",
      "Mean Sugar", "Total Sugar", "Cultural Entropy"],
    agent_color=agent_color,
    agent_size=agent_size,
    heatarray=sugarmap,
    heatkwargs=heatkwargs,
    figure=(; size=(1400, 1000))
  )

  # Insert an empty spacer column to keep the heatmap colourbar (generated automatically
  # by `abmplot`) flush to the main grid and guarantee its tick labels don't encroach on
  # the dashboard text/widgets.
  fig[:, end+1] = GridLayout()  # spacer – no content

  # Add controls/layout section **after** the spacer so widgets start one column further
  # to the right.
  plot_layout = fig[:, end+1] = GridLayout()

  # Constrain the spacer column to a narrow fixed width so the gap only affects the
  # upper portion of the layout and doesn't unnecessarily shrink the widgets below.
  ncols = size(fig.layout)[2]
  colsize!(fig.layout, ncols - 1, Fixed(40))

  # Agent State Table Section
  table_section = plot_layout[1, 1] = GridLayout()
  Label(table_section[1, 1], "Agent State Monitor", tellwidth=false, font=:bold)

  # Create agent state display
  agent_state_text = Observable("")
  current_step = Observable(0)

  # Update agent state display - access agents directly from model
  on(abmobs.model) do model
    current_step[] += 1
    agents_data = []

    # Get individual agent data directly from the model
    agent_list = collect(allagents(model))
    sort!(agent_list, by=a -> a.id)  # Sort by ID for consistent display

    for agent in agent_list[1:min(10, length(agent_list))]  # Show first 10 agents
      push!(agents_data, [
        agent.id,
        agent.pos,
        agent.vision,
        agent.metabolism,
        round(agent.sugar, digits=2),
        agent.age,
        agent.max_age,
        agent.sex,
        agent.has_mated,
        round(agent.initial_sugar, digits=2),
        round(agent.total_inheritance_received, digits=2),
        length(agent.culture) > 0 ? join(Int.(agent.culture), "") : "N/A"
      ])
    end

    # Format as readable text for display
    text_lines = [
      "Step: $(current_step[])",
      "Total Agents: $(length(agent_list))",
      "",
      "ID | Pos      | Vis | Met | Sugar  | Age | MaxAge | Sex    | Mated | InitSug | Inherit | Culture"
    ]

    for agent_data in agents_data
      line = join([
          lpad(string(agent_data[1]), 2),
          rpad(string(agent_data[2]), 8),
          lpad(string(agent_data[3]), 3),
          lpad(string(agent_data[4]), 3),
          lpad(string(agent_data[5]), 6),
          lpad(string(agent_data[6]), 3),
          lpad(string(agent_data[7]), 6),
          rpad(string(agent_data[8]), 6),
          lpad(string(agent_data[9]), 5),
          lpad(string(agent_data[10]), 7),
          lpad(string(agent_data[11]), 7),
          rpad(string(agent_data[12])[1:min(7, length(string(agent_data[12])))], 7)
        ], " | ")
      push!(text_lines, line)
    end

    if length(agent_list) > 10
      push!(text_lines, "... and $(length(agent_list) - 10) more agents")
    end

    agent_state_text[] = join(text_lines, "\n")
  end

  # Display agent state table
  agent_table_area = table_section[2, 1] = GridLayout()
  textbox = Label(agent_table_area[1, 1], agent_state_text,
    tellwidth=false, tellheight=false,
    font="monospace", fontsize=10,
    justification=:left, lineheight=1.2)

  # CSV Export Controls
  export_section = plot_layout[2, 1] = GridLayout()
  Label(export_section[1, 1], "Data Export", tellwidth=false, font=:bold)

  # Ensure results directory exists (./data/results relative to project root)
  results_dir = normpath(joinpath(@__DIR__, "..", "..", "data", "results"))
  if !isdir(results_dir)
    mkpath(results_dir)
  end

  # Export buttons
  export_agents_btn = Button(export_section[2, 1], label="Export Agent Data")
  export_model_btn = Button(export_section[2, 2], label="Export Model Data")

  # CSV export functionality - create agent data directly from model
  on(export_agents_btn.clicks) do _
    try
      timestamp = Dates.format(Dates.now(), "yyyymmdd_HHMMSS")
      model = abmobs.model[]
      agent_list = collect(allagents(model))

      # Create DataFrame with individual agent data
      agent_df = DataFrame(
        step=fill(current_step[], length(agent_list)),
        id=[a.id for a in agent_list],
        pos_x=[a.pos[1] for a in agent_list],
        pos_y=[a.pos[2] for a in agent_list],
        vision=[a.vision for a in agent_list],
        metabolism=[a.metabolism for a in agent_list],
        sugar=[a.sugar for a in agent_list],
        age=[a.age for a in agent_list],
        max_age=[a.max_age for a in agent_list],
        sex=[a.sex for a in agent_list],
        has_mated=[a.has_mated for a in agent_list],
        initial_sugar=[a.initial_sugar for a in agent_list],
        total_inheritance_received=[a.total_inheritance_received for a in agent_list],
        culture=[length(a.culture) > 0 ? join(Int.(a.culture), "") : "" for a in agent_list]
      )

      filename = joinpath(results_dir, "sugarscape_agents_$(timestamp)_step_$(current_step[]).csv")
      CSV.write(filename, agent_df)
      @info "Agent data exported to $(abspath(filename)) ($(length(agent_list)) agents)"
    catch e
      @warn "Error exporting agent data: $e"
    end
  end

  on(export_model_btn.clicks) do _
    if !isempty(abmobs.mdf[])
      timestamp = Dates.format(Dates.now(), "yyyymmdd_HHMMSS")
      filename = joinpath(results_dir, "sugarscape_model_$(timestamp)_step_$(current_step[]).csv")
      CSV.write(filename, abmobs.mdf[])
      @info "Model data exported to $(abspath(filename))"
    else
      @warn "No model data to export"
    end
  end

  # Rule Status Display
  status_section = plot_layout[3, 1] = GridLayout()
  Label(status_section[1, 1], "Active Rules Status", tellwidth=false, font=:bold)

  rule_status_text = Observable("")

  on(abmobs.model) do model
    status_lines = [
      "Reproduction: $(model.enable_reproduction ? "✓" : "✗")",
      "Culture: $(model.enable_culture ? "✓" : "✗")",
      "Combat: $(model.enable_combat ? "✓" : "✗")",
      "Pollution: $(model.enable_pollution ? "✓" : "✗")",
      "",
      "Growth Rate: $(model.growth_rate)",
      "Season Duration: $(model.season_duration)",
      "Combat Limit: $(model.combat_limit)",
      "Culture Copy Prob: $(model.enable_culture ? model.culture_copy_prob : "N/A")"
    ]
    rule_status_text[] = join(status_lines, "\n")
  end

  Label(status_section[2, 1], rule_status_text,
    tellwidth=false, font="monospace", fontsize=12,
    justification=:left)

  # Performance monitoring
  perf_section = plot_layout[4, 1] = GridLayout()
  Label(perf_section[1, 1], "Performance Monitor", tellwidth=false, font=:bold)

  perf_text = Observable("Steps/sec: -- \nMemory: --")
  last_time = Ref(time())
  step_count = Ref(0)

  on(abmobs.model) do model
    step_count[] += 1
    current_time = time()

    if current_time - last_time[] >= 1.0  # Update every second
      steps_per_sec = step_count[] / (current_time - last_time[])
      memory_mb = Base.gc_live_bytes() / 1024 / 1024

      perf_text[] = "Steps/sec: $(round(steps_per_sec, digits=1))\nMemory: $(round(memory_mb, digits=1)) MB"

      last_time[] = current_time
      step_count[] = 0
    end
  end

  Label(perf_section[2, 1], perf_text,
    tellwidth=false, font="monospace", fontsize=12)

  # Initialize the display
  notify(abmobs.model)

  return fig, abmobs
end
