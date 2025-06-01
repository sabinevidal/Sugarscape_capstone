#!/usr/bin/env julia
using Sugarscape, ArgParse, Agents # Ensure Agents is imported

s = ArgParseSettings()
@add_arg_table s begin
  "--steps"
  arg_type = Int
  default = 500
  help = "Number of simulation steps"
  "--seed"
  arg_type = Int
  default = 42
  help = "RNG seed"
  "--csv"
  arg_type = String
  default = ""
  help = "If given, dump model & agent data to this CSV prefix"
  "--gui"
  action = :store_true
  help = "Pop up a Makie window instead of batch run"
end

args = parse_args(s)

# Define data collection
adata = [:sugar, :age, :vision, :metabolism, :max_age]
mdata = [nagents, model -> Sugarscape.gini_coefficient([a.sugar for a in allagents(model)])]

if args["gui"]
  # For GUI, data collection is handled by the visualization if needed,
  # or can be omitted if the visualization itself doesn't require `adata`/`mdata`
  # from `run!`. The `abmplot` itself will use the model's current state.
  Sugarscape.run_sugarscape_visualization(; seed=args["seed"])
else
  # Create the model using the constructor from Sugarscape.jl
  model = Sugarscape.sugarscape(; seed=args["seed"])
  # Run the simulation using Agents.run! and pass adata, mdata here
  agent_df, model_df = Agents.run!(model, args["steps"]; adata=adata, mdata=mdata)

  if args["csv"] != ""
    using CSV, DataFrames
    CSV.write(args["csv"] * "_agents.csv", agent_df)
    CSV.write(args["csv"] * "_model.csv", model_df)
  end
end
