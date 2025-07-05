# AI / LLM Development Dashboards for Sugarscape
# ------------------------------------------------
# This file complements `dashboard.jl` with dashboards that focus on the
# large-language-model (LLM) driven features of the simulation.
#
# It is INCLUDED from `src/Sugarscape.jl`, hence we are already inside the
# `module Sugarscape` scope – no explicit `module` block here.

using GLMakie
using Agents

"""
    create_ai_dashboard(; kwargs...)

Interactive dashboard specialised for **development and debugging of the LLM
integration**.  It mirrors the standard dashboard but adds visual cues that
highlight the decisions returned by the LLM so that you can quickly verify
behaviour.

Keyword arguments forward to `sugarscape` with sensible defaults that favour a
rich, visually interesting simulation whilst remaining lightweight.
"""
function create_ai_dashboard(;
  # LLM-related
  use_llm_decisions::Bool=true,
  llm_api_key::AbstractString=get(ENV, "OPENAI_API_KEY", ""),
  llm_temperature::Float64=0.2,
  # Model size & composition
  N::Int=50,
  dims::Tuple{Int,Int}=(30, 30),
  # Rule toggles
  enable_combat::Bool=true,
  enable_reproduction::Bool=true,
  enable_credit::Bool=true,
  enable_culture::Bool=false,
  seed::Int=42
)
  # -----------------------------------------------------------------------
  # Construct model
  # -----------------------------------------------------------------------
  model = sugarscape(
    use_llm_decisions=use_llm_decisions,
    llm_api_key=llm_api_key,
    llm_temperature=llm_temperature,
    N=N,
    dims=dims,
    enable_combat=enable_combat,
    enable_reproduction=enable_reproduction,
    enable_credit=enable_credit,
    enable_culture=enable_culture,
    seed=seed
  )

  # -----------------------------------------------------------------------
  # Interactive parameters (sliders / toggles)
  # -----------------------------------------------------------------------
  params = Dict(
    :enable_reproduction => [false, true],
    :enable_combat => [false, true],
    :enable_credit => [false, true],
    :llm_temperature => 0.0:0.1:1.0,
    :use_llm_decisions => [false, true]
  )

  # -----------------------------------------------------------------------
  # Data collection helpers
  # -----------------------------------------------------------------------
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

  # -----------------------------------------------------------------------
  # Visual encodings that surface the LLM decisions
  # -----------------------------------------------------------------------
  function agent_color(agent)
    if use_llm_decisions && haskey(model.llm_decisions, agent.id)
      decision = model.llm_decisions[agent.id]
      return decision.combat ? :red : (decision.move ? :blue : :green)
    else
      return agent.sugar > 20 ? :gold : (agent.sugar > 10 ? :orange : :darkred)
    end
  end

  function agent_size(agent)
    base = max(4, min(12, agent.sugar / 2))
    return (use_llm_decisions && haskey(model.llm_decisions, agent.id)) ? base + 2 : base
  end

  function agent_marker(agent)
    if use_llm_decisions && haskey(model.llm_decisions, agent.id)
      decision = model.llm_decisions[agent.id]
      return decision.combat ? :star5 : (decision.move ? :diamond : :circle)
    else
      return :circle
    end
  end

  # Sugar landscape heat-map helper
  sugarmap(m) = m.sugar_values
  heatkwargs = (
    colormap=:thermal,
    colorrange=(0.0, maximum(model.sugar_capacities))
  )

  # -----------------------------------------------------------------------
  # Create dashboard via `Agents.abmplot`
  # -----------------------------------------------------------------------
  fig, ax, abmobs = abmplot(
    model;
    params=params,
    adata=adata,
    mdata=mdata,
    alabels=["Wealthy", "Medium", "Poor"],
    mlabels=["Agents", "Starvation", "Age Deaths", "Births"],
    agent_color=agent_color,
    agent_size=agent_size,
    agent_marker=agent_marker,
    heatarray=sugarmap,
    heatkwargs=heatkwargs,
    figure=(; size=(1400, 1000))
  )

  # Explanatory overlay
  fig[1, 3] = Label(fig,
    "AI / LLM Development Dashboard\n" *
    "LLM enabled: $(use_llm_decisions)\n" *
    "\nLegend:\n" *
    "red ● Combat intent\n" *
    "blue ● Movement intent\n" *
    "green ●Stay / Other",
    tellheight=false,
    fontsize=12,
    halign=:left,
    valign=:top
  )

  return fig, abmobs
end

# legend = vbox(
#     Label(fig, "AI / LLM Development Dashboard", fontsize=12, halign=:left),
#     Label(fig, "LLM enabled: $(use_llm_decisions)", fontsize=10, halign=:left),
#     Label(fig, "Legend:", fontsize=10, halign=:left),
#     Label(fig, "●  Combat intent", color=:red, fontsize=10, halign=:left),
#     Label(fig, "●  Movement intent", color=:blue, fontsize=10, halign=:left),
#     Label(fig, "●  Stay / Other", color=:green, fontsize=10, halign=:left)
#   )

"""
    test_single_agent_prompt(; model_kwargs...)

Run the **minimal single-agent prompt test** that exercises the complete LLM
pipeline (context → OpenAI call → strict parsing) without any interactive
`readline` pauses.  This is a thin convenience wrapper around
`test_single_agent_llm_prompt` defined in `visualisation/testing.jl`, provided
here so that all AI-centric helpers live in one place.

Any keyword arguments are forwarded to the underlying model constructor via
`model_kwargs`.
"""
function test_single_agent_prompt(; model_kwargs...)
  return test_single_agent_llm_prompt(; model_kwargs...)
end
