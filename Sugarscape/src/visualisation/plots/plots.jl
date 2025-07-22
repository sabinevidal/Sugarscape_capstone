
using CSV, DataFrames, Plots, Statistics, Dates

function plot_model_metrics(file_path::String; output_dir::String="plots/")
  df = CSV.read(file_path, DataFrame)

  # Drop columns where every value is missing
  nonmissing_cols = [name for (name, col) in zip(names(df), eachcol(df)) if !all(ismissing, col)]
  df = df[:, nonmissing_cols]

  metrics = filter(col -> col != "step", names(df))
  steps = (:step in propertynames(df)) ? df.step : collect(1:nrow(df))

  for metric in metrics
    plot(steps, df[!, metric],
      xlabel="Step",
      ylabel=metric,
      label=metric,
      title="Model Metric: $metric")
    savepath = joinpath(output_dir, "$(metric)_plot_$(Dates.format(now(), "yymmdd_HHMM")).png")
    savefig(savepath)
  end
end

function plot_agent_metric_distribution(file_path::String; step=nothing, metric::Symbol, output_dir::String="plots/")
  df = CSV.read(file_path, DataFrame)

  if step !== nothing && :step in propertynames(df)
    df = filter(:step => ==(step), df)
  end

  if !(metric in propertynames(df))
    error("Metric $(metric) not found in agent data.")
  end

  histogram(df[!, metric],
    bins=30,
    xlabel=string(metric),
    ylabel="Frequency",
    title="Agent Metric Distribution: $(metric) at Step $(step)",
    legend=false)
  savepath = joinpath(output_dir, "$(metric)_distribution_step$(step)_$(Dates.format(now(), "yymmdd_HHMM")).png")
  savefig(savepath)
end

function plot_trait_scatter(file_path::String, trait1::Symbol, trait2::Symbol; step=nothing, output_dir::String="plots/")
  df = CSV.read(file_path, DataFrame)

  if step !== nothing && :step in propertynames(df)
    df = filter(:step => ==(step), df)
  end

  if !(:traits in propertynames(df))
    error("No `traits` column found in agent data.")
  end

  trait_values = [NamedTuple(t) for t in df.traits if t !== missing]

  x = [t[trait1] for t in trait_values if haskey(t, trait1)]
  y = [t[trait2] for t in trait_values if haskey(t, trait2)]

  scatter(x, y,
    xlabel=string(trait1),
    ylabel=string(trait2),
    title="Trait Scatter: $(trait1) vs $(trait2)",
    legend=false)
  savepath = joinpath(output_dir, "trait_scatter_$(trait1)_$(trait2)_step$(step)_$(Dates.format(now(), "yymmdd_HHMM")).png")
  savefig(savepath)
end
