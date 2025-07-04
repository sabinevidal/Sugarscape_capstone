using Sugarscape

using Agents
using GLMakie

using Observables, Random
using DataFrames: nrow, ncol, names

# TODO: CHeck this https://juliadynamics.github.io/Agents.jl/stable/examples/agents_visualizations/#Creating-custom-ABM-plots

agent_s_interactive(a) = 8

"""
    create_custom_dashboard(; model_kwargs...)

Create a custom interactive dashboard showing:
- Agent positions with sugar heatmap
- Deaths over time (hunger vs old age)
- Gini coefficient over time
- Wealth histogram

Uses abmplot and ABMObservable for reactive updates.
"""
function create_custom_dashboard()

  initial_pollution_enabled_numeric = 0

  # Parameters for sliders (ranges for the GUI)
  model_params = Dict(
    :enable_pollution => (false, true),
  )

  model = Sugarscape.sugarscape(; enable_pollution=Bool(initial_pollution_enabled_numeric), use_llm_decisions=false)

  # Set up data collection for the ABMObservable
  # For adata, we collect aggregated statistics (following Agents.jl patterns)
  adata = []  # No aggregated agent data needed for our plots

  # We need model data for deaths and Gini coefficient
  mdata = [
    :deaths_starvation,
    :deaths_age,
    model -> Sugarscape.gini_coefficient([a.sugar for a in allagents(model)]),
    nagents
  ]

  # Agent visualization functions
  agent_color(a) = :yellow
  agent_size(a) = 8
  agent_marker(a) = :circle

  # Sugar heatmap function
  sugarmap(model) = model.sugar_values
  max_sugar_capacity = maximum(model.sugar_capacities)
  # Keywords for the heatmap
  max_initial_sugar_capacity = 0.0
  if !isempty(model.sugar_capacities)
    max_initial_sugar_capacity = maximum(model.sugar_capacities)
  end

  heatkwargs = (
    colormap=:thermal,
    colorrange=(0.0, max_sugar_capacity > 0 ? max_initial_sugar_capacity : 4.0)
  )

  # Create the main interactive abmplot - this creates the interactive GLMakie window
  fig, ax, abmobs = abmplot(model;
    agent_color=agent_color,
    agent_size=agent_size,
    agent_marker=agent_marker,
    heatarray=sugarmap,
    heatkwargs=heatkwargs,
    add_controls=true,  # This makes it interactive!
    adata=adata,
    mdata=mdata,
    figure=(; size=(1600, 1000))
  )

  # Now add custom plots to the right of the abmplot following the documentation pattern
  plot_layout = fig[:, end+1] = GridLayout()

  # Create step counter observable that tracks model steps
  step_counter = Observable(0)

  # Update title with step counter - use connect! to properly link observables
  title_text = @lift("Sugarscape Simulation - Step: $($step_counter)")
  connect!(ax.title, title_text)

  # Deaths over time plot
  deaths_layout = plot_layout[1, 1] = GridLayout()
  ax_deaths = Axis(deaths_layout[1, 1], xlabel="Step", ylabel="Deaths per Step",
    title="Deaths by Cause")

  # Create observables for death data using @lift on the model data
  death_data_starvation = @lift begin
    mdf = $(abmobs.mdf)
    if nrow(mdf) == 0
      Point2f[]
    else
      # Calculate deaths per step (difference between consecutive cumulative values)
      steps = 0:(nrow(mdf)-1)
      deaths_cumulative = mdf.deaths_starvation
      deaths_per_step = [i == 1 ? deaths_cumulative[1] : deaths_cumulative[i] - deaths_cumulative[i-1] for i in 1:length(deaths_cumulative)]
      [Point2f(step, deaths) for (step, deaths) in zip(steps, deaths_per_step)]
    end
  end

  death_data_age = @lift begin
    mdf = $(abmobs.mdf)
    if nrow(mdf) == 0
      Point2f[]
    else
      steps = 0:(nrow(mdf)-1)
      deaths_cumulative = mdf.deaths_age
      deaths_per_step = [i == 1 ? deaths_cumulative[1] : deaths_cumulative[i] - deaths_cumulative[i-1] for i in 1:length(deaths_cumulative)]
      [Point2f(step, deaths) for (step, deaths) in zip(steps, deaths_per_step)]
    end
  end

  # Plot death lines
  lines!(ax_deaths, death_data_starvation, color=:red, label="Starvation")
  lines!(ax_deaths, death_data_age, color=:blue, label="Old Age")
  axislegend(ax_deaths, position=:lt)

  # Gini coefficient over time plot
  gini_layout = plot_layout[2, 1] = GridLayout()
  ax_gini = Axis(gini_layout[1, 1], xlabel="Step", ylabel="Gini Coefficient",
    title="Wealth Inequality Over Time")

  gini_data = @lift begin
    mdf = $(abmobs.mdf)
    if nrow(mdf) == 0
      Point2f[]
    else
      steps = 0:(nrow(mdf)-1)
      # The Gini coefficient should be in the third column (after deaths_starvation and deaths_age)
      gini_values = if ncol(mdf) >= 3
        col_name = names(mdf)[3]
        mdf[!, col_name]
      else
        zeros(nrow(mdf))
      end
      [Point2f(step, gini) for (step, gini) in zip(steps, gini_values)]
    end
  end

  lines!(ax_gini, gini_data, color=:darkgreen, linewidth=2)
  ylims!(ax_gini, 0, 1)

  # Wealth histogram
  hist_layout = plot_layout[3, 1] = GridLayout()
  ax_hist = Axis(hist_layout[1, 1], xlabel="Wealth", ylabel="Number of Agents",
    title="Current Wealth Distribution")

  # Extract individual wealth values directly from the model
  wealth_values = @lift begin
    current_model = $(abmobs.model)
    wealth_data = [a.sugar for a in allagents(current_model)]
    filter(w -> w >= 0 && isfinite(w), wealth_data)
  end

  hist!(ax_hist, wealth_values, bins=30, color=(:blue, 0.6),
    strokecolor=:black, strokewidth=1)

  # Set up layout proportions for the custom plots
  rowsize!(plot_layout, 1, Relative(0.33))  # Deaths plot
  rowsize!(plot_layout, 2, Relative(0.33))  # Gini plot
  rowsize!(plot_layout, 3, Relative(0.34))  # Wealth histogram

  # Update step counter and autolimits when model changes
  on(abmobs.model) do model
    step_counter[] += 1
    autolimits!(ax_deaths)
    autolimits!(ax_hist)
  end

  return fig, abmobs
end



"""
    create_reproduction_dashboard()

Create a robust custom interactive dashboard for reproduction-enabled Sugarscape that handles
dynamic population changes without dimension mismatch errors.
"""
function create_reproduction_dashboard()

  # Create model with reproduction enabled and higher initial child sugar to encourage population growth
  model = Sugarscape.sugarscape(;
    enable_reproduction=true,
    fertility_age_range=(15, 50),
    initial_child_sugar=8,
    N=200,
    use_llm_decisions=false,
  )

  # Set up data collection for the ABMObservable
  adata = []  # No aggregated agent data needed for our plots

  # We need model data for deaths, births, and Gini coefficient
  mdata = [
    :deaths_starvation,
    :deaths_age,
    :births,
    model -> Sugarscape.gini_coefficient([a.sugar for a in allagents(model)]),
    nagents
  ]

  # Agent visualization functions
  agent_color(a) = a.sex == :male ? :blue : :pink
  agent_size(a) = 6
  agent_marker(a) = :circle

  # Sugar heatmap function
  sugarmap(model) = model.sugar_values
  max_sugar_capacity = maximum(model.sugar_capacities)
  # Keywords for the heatmap
  max_initial_sugar_capacity = 0.0
  if !isempty(model.sugar_capacities)
    max_initial_sugar_capacity = maximum(model.sugar_capacities)
  end

  heatkwargs = (
    colormap=:thermal,
    colorrange=(0.0, max_sugar_capacity > 0 ? max_initial_sugar_capacity : 4.0)
  )

  # Create the main interactive abmplot
  fig, ax, abmobs = abmplot(model;
    agent_color=agent_color,
    agent_size=agent_size,
    agent_marker=agent_marker,
    heatarray=sugarmap,
    heatkwargs=heatkwargs,
    add_controls=true,
    adata=adata,
    mdata=mdata,
    figure=(; size=(1600, 1000)),
    agentsplotkwargs=(markersize=6, strokewidth=0.5),
  )

  # Add custom plots layout
  plot_layout = fig[:, end+1] = GridLayout()

  # Create step counter observable
  step_counter = Observable(0)

  # Create title that includes both step counter and current agent count
  title_text = @lift begin
    current_model = $(abmobs.model)
    agent_count = Agents.nagents(current_model)
    "Sugarscape Reproduction Dashboard - Step: $($step_counter) | Agents: $(agent_count)"
  end
  connect!(ax.title, title_text)

  # Demographics plot (births vs deaths)
  demo_layout = plot_layout[1, 1] = GridLayout()
  ax_demo = Axis(demo_layout[1, 1], xlabel="Step", ylabel="Count per Step",
    title="Population Dynamics (Births vs Deaths)")

  # Create observables for demographic data
  birth_data = @lift begin
    mdf = $(abmobs.mdf)
    if nrow(mdf) == 0
      Point2f[]
    else
      try
        steps = 0:(nrow(mdf)-1)
        births_cumulative = mdf.births
        births_per_step = [i == 1 ? births_cumulative[1] : max(0, births_cumulative[i] - births_cumulative[i-1]) for i in 1:length(births_cumulative)]
        [Point2f(step, births) for (step, births) in zip(steps, births_per_step)]
      catch e
        @warn "Error computing birth data: $e"
        Point2f[]
      end
    end
  end

  death_data_starvation = @lift begin
    mdf = $(abmobs.mdf)
    if nrow(mdf) == 0
      Point2f[]
    else
      try
        steps = 0:(nrow(mdf)-1)
        deaths_cumulative = mdf.deaths_starvation
        deaths_per_step = [i == 1 ? deaths_cumulative[1] : max(0, deaths_cumulative[i] - deaths_cumulative[i-1]) for i in 1:length(deaths_cumulative)]
        [Point2f(step, deaths) for (step, deaths) in zip(steps, deaths_per_step)]
      catch e
        @warn "Error computing starvation death data: $e"
        Point2f[]
      end
    end
  end

  death_data_age = @lift begin
    mdf = $(abmobs.mdf)
    if nrow(mdf) == 0
      Point2f[]
    else
      try
        steps = 0:(nrow(mdf)-1)
        deaths_cumulative = mdf.deaths_age
        deaths_per_step = [i == 1 ? deaths_cumulative[1] : max(0, deaths_cumulative[i] - deaths_cumulative[i-1]) for i in 1:length(deaths_cumulative)]
        [Point2f(step, deaths) for (step, deaths) in zip(steps, deaths_per_step)]
      catch e
        @warn "Error computing age death data: $e"
        Point2f[]
      end
    end
  end

  # Plot demographic lines
  lines!(ax_demo, birth_data, color=:green, label="Births", linewidth=2)
  lines!(ax_demo, death_data_starvation, color=:red, label="Deaths (Starvation)")
  lines!(ax_demo, death_data_age, color=:blue, label="Deaths (Age)")
  axislegend(ax_demo, position=:lt)

  # Population size over time
  pop_layout = plot_layout[2, 1] = GridLayout()
  ax_pop = Axis(pop_layout[1, 1], xlabel="Step", ylabel="Total Agents",
    title="Population Size")

  pop_data = @lift begin
    mdf = $(abmobs.mdf)
    if nrow(mdf) == 0
      Point2f[]
    else
      try
        steps = 0:(nrow(mdf)-1)
        # Population count should be in the last column (nagents)
        pop_values = if ncol(mdf) >= 5
          col_name = names(mdf)[5]
          mdf[!, col_name]
        else
          zeros(Int, nrow(mdf))
        end
        [Point2f(step, pop) for (step, pop) in zip(steps, pop_values)]
      catch e
        @warn "Error computing population data: $e"
        Point2f[]
      end
    end
  end

  lines!(ax_pop, pop_data, color=:purple, linewidth=2)

  # Wealth distribution
  hist_layout = plot_layout[3, 1] = GridLayout()
  ax_hist = Axis(hist_layout[1, 1], xlabel="Wealth", ylabel="Number of Agents",
    title="Current Wealth Distribution")

  wealth_values = @lift begin
    try
      current_model = $(abmobs.model)
      wealth_data = [a.sugar for a in allagents(current_model)]
      valid_wealth = filter(w -> w >= 0 && isfinite(w), wealth_data)
      isempty(valid_wealth) ? [0.0] : valid_wealth
    catch e
      @warn "Error computing wealth data: $e"
      [0.0]
    end
  end

  hist!(ax_hist, wealth_values, bins=20, color=(:orange, 0.6),
    strokecolor=:black, strokewidth=1)

  # Age distribution
  age_layout = plot_layout[4, 1] = GridLayout()
  ax_age = Axis(age_layout[1, 1], xlabel="Age", ylabel="Number of Agents",
    title="Current Age Distribution")

  age_values = @lift begin
    try
      current_model = $(abmobs.model)
      age_data = [a.age for a in allagents(current_model)]
      isempty(age_data) ? [0] : age_data
    catch e
      @warn "Error computing age data: $e"
      [0]
    end
  end

  hist!(ax_age, age_values, bins=15, color=(:cyan, 0.6),
    strokecolor=:black, strokewidth=1)

  # Set up layout proportions
  rowsize!(plot_layout, 1, Relative(0.25))  # Demographics
  rowsize!(plot_layout, 2, Relative(0.25))  # Population size
  rowsize!(plot_layout, 3, Relative(0.25))  # Wealth histogram
  rowsize!(plot_layout, 4, Relative(0.25))  # Age histogram

  # Update step counter and autolimits when model changes
  on(abmobs.model) do model
    try
      step_counter[] += 1
      autolimits!(ax_demo)
      autolimits!(ax_pop)
      autolimits!(ax_hist)
      autolimits!(ax_age)
    catch e
      @warn "Error updating plots: $e"
    end
  end

  return fig, abmobs
end
