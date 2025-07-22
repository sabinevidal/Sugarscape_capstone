#!/usr/bin/env julia

using CSV, DataFrames, ArgParse
include("../src/visualisation/plots/plots.jl")

# Argument parser
function parse_args()
  s = ArgParseSettings()
  @add_arg_table s begin
    "--metrics_file"
    help = "Path to the model-level metrics CSV file"
    arg_type = String
    required = true
    "--agents_file"
    help = "Path to the agent-level CSV file"
    arg_type = String
    required = true
    "--step"
    help = "Step at which to plot agent metrics (default: last step)"
    arg_type = Int
    required = false
    "--output_dir"
    help = "Directory to save plots (default: src/visualisation/plots/figs/)"
    arg_type = String
    required = false
    default = "src/visualisation/plots/figs/"
  end
  return ArgParse.parse_args(s)
end

function main()
  args = parse_args()
  metrics_file = args["metrics_file"]
  agents_file = args["agents_file"]
  step = get(args, "step", nothing)
  output_dir = args["output_dir"]
  mkpath(output_dir)
  println("📊 Plotting model metrics from: $metrics_file")
  plot_model_metrics(metrics_file; output_dir=output_dir)
  println("📊 Plotting agent sugar distribution...")
  plot_agent_metric_distribution(agents_file; step=step, metric=:sugar, output_dir=output_dir)
  if occursin("traits", read(agents_file, String))
    println("📊 Plotting trait scatter (Openness vs Agreeableness)...")
    plot_trait_scatter(agents_file, :Openness, :Agreeableness; step=step, output_dir=output_dir)
  end
  println("✅ Plots saved to $output_dir")
end

main()
