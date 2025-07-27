### A Pluto.jl notebook ###
# v0.19.32

using Markdown
using InteractiveUtils

# ╔═╡ 8a2b4c40-5c8e-11ee-1234-0123456789ab
begin
    using PlutoUI
    using Glob
    using CSV
    using DataFrames
    using JSON3
    using Tables
    using FileIO
    using Statistics
    using Dates
end

# ╔═╡ 1a2b3c40-5c8e-11ee-1234-0123456789ab
md"""
# 📘 Sugarscape Data Loader

This notebook loads and preprocesses output data from Sugarscape simulation runs.

**Purpose:**
- Load model-level metric files (`model_metrics.csv`)
- Load agent-level log files (`agents.csv`)
- Extract run metadata from folder names or `config.json`
- Handle different architectures (rule-based, LLM-mimic, LLM-diverse)
- Handle different scenarios (credit-only, combat-only, reproduction+combat, etc.)

**Output:**
- `model_metrics_df`: Combined model-level time series data
- `agent_data_df`: Combined agent-level longitudinal data

Both DataFrames include metadata columns for scenario, architecture, and run_id.
"""

# ╔═╡ 2a2b3c40-5c8e-11ee-1234-0123456789ab
md"""
## 🔧 Configuration
"""

# ╔═╡ 3a2b3c40-5c8e-11ee-1234-0123456789ab
# Base data directory
const DATA_DIR = "/data/for_analysis"

# ╔═╡ 4a2b3c40-5c8e-11ee-1234-0123456789ab
# Results output directory
const RESULTS_DIR = "/notebooks/results"

# ╔═╡ 5a2b3c40-5c8e-11ee-1234-0123456789ab
md"""
## 📁 Available Scenarios

Select which scenarios to include in the analysis:
"""

# ╔═╡ 6a2b3c40-5c8e-11ee-1234-0123456789ab
# Get available scenario folders
available_scenarios = [d for d in readdir(DATA_DIR) if isdir(joinpath(DATA_DIR, d))]

# ╔═╡ 7a2b3c40-5c8e-11ee-1234-0123456789ab
@bind selected_scenarios MultiCheckBox(available_scenarios, default=available_scenarios)

# ╔═╡ 8a2b3c40-5c8e-11ee-1234-0123456789ac
md"""
Selected scenarios: $(join(selected_scenarios, ", "))

**Include initial agent data?** $(@bind include_initial CheckBox(default=false))
"""

# ╔═╡ 9a2b3c40-5c8e-11ee-1234-0123456789ab
md"""
## 🛠️ Utility Functions
"""

# ╔═╡ 1b2b3c40-5c8e-11ee-1234-0123456789ab
"""
Parse filename to extract metadata (scenario, architecture, run_id)
"""
function parse_filename(filename::String)
    # Remove .csv extension
    base = replace(filename, ".csv" => "")

    # Split by underscores
    parts = split(base, "_")

    # Extract components
    scenario = ""
    architecture = ""
    run_id = ""
    file_type = ""

    # Handle different filename patterns
    if length(parts) >= 4
        if parts[1] == "movement"
            # Pattern: movement_scenario_architecture_type_runid
            if length(parts) == 5
                scenario = parts[2]
                architecture = parts[3]
                file_type = parts[4]
                run_id = parts[5]
            elseif length(parts) == 6
                # Pattern: movement_scenario1_scenario2_architecture_type_runid
                scenario = join(parts[2:3], "_")
                architecture = parts[4]
                file_type = parts[5]
                run_id = parts[6]
            elseif length(parts) == 7
                # Pattern: movement_scenario1_scenario2_scenario3_architecture_type_runid
                scenario = join(parts[2:4], "_")
                architecture = parts[5]
                file_type = parts[6]
                run_id = parts[7]
            end
        elseif parts[1] == "full"
            # Pattern: full_stack_architecture_type_runid
            scenario = "fullstack"
            architecture = parts[3]
            file_type = parts[4]
            run_id = parts[5]
        end
    end

    return (scenario=scenario, architecture=architecture, run_id=run_id, file_type=file_type)
end

# ╔═╡ 2b2b3c40-5c8e-11ee-1234-0123456789ab
"""
Flatten traits column containing named tuples or dictionaries
"""
function flatten_traits_column!(df::DataFrame, col::Symbol)
    if col ∉ names(df)
        return df
    end

    # Check if traits column exists and has data
    if all(ismissing, df[!, col])
        return df
    end

    # Get first non-missing trait to determine structure
    first_trait = nothing
    for trait in df[!, col]
        if !ismissing(trait)
            first_trait = trait
            break
        end
    end

    if first_trait === nothing
        return df
    end

    # Parse trait string if it's a string representation
    if isa(first_trait, String)
        # Handle named tuple format: "(openness = 4.3, conscientiousness = 4.06, ...)"
        if startswith(first_trait, "(") && endswith(first_trait, ")")
            trait_names = String[]
            for row in eachrow(df)
                if !ismissing(row[col])
                    trait_str = row[col]
                    # Remove parentheses and split by commas
                    inner = trait_str[2:end-1]
                    pairs = split(inner, ", ")
                    for pair in pairs
                        name, _ = split(pair, " = ")
                        name = strip(name)
                        if name ∉ trait_names
                            push!(trait_names, name)
                        end
                    end
                end
            end

            # Create columns for each trait
            for trait_name in trait_names
                col_name = Symbol(titlecase(replace(trait_name, "_" => "")))
                df[!, col_name] = Float64[]
            end

            # Fill trait columns
            for row in eachrow(df)
                if !ismissing(row[col])
                    trait_str = row[col]
                    inner = trait_str[2:end-1]
                    pairs = split(inner, ", ")
                    trait_dict = Dict{String,Float64}()
                    for pair in pairs
                        name, value = split(pair, " = ")
                        trait_dict[strip(name)] = parse(Float64, strip(value))
                    end

                    for trait_name in trait_names
                        col_name = Symbol(titlecase(replace(trait_name, "_" => "")))
                        if haskey(trait_dict, trait_name)
                            row[col_name] = trait_dict[trait_name]
                        else
                            row[col_name] = missing
                        end
                    end
                else
                    for trait_name in trait_names
                        col_name = Symbol(titlecase(replace(trait_name, "_" => "")))
                        row[col_name] = missing
                    end
                end
            end
        end
    end

    # Remove original traits column
    select!(df, Not(col))

    return df
end

# ╔═╡ 3b2b3c40-5c8e-11ee-1234-0123456789ab
"""
Parse dictionary strings in CSV columns (e.g., credit_network_metrics)
"""
function parse_dict_column(dict_str::String)
    try
        # Remove Dict{String, Real}( prefix and ) suffix
        if startswith(dict_str, "Dict{")
            # Find the opening parenthesis
            start_idx = findfirst('(', dict_str)
            if start_idx !== nothing
                inner = dict_str[start_idx+1:end-1]

                # Parse key-value pairs
                result = Dict{String,Any}()

                # Split by commas, but be careful with nested structures
                pairs = String[]
                current_pair = ""
                paren_count = 0
                quote_count = 0

                for char in inner
                    if char == '"'
                        quote_count = (quote_count + 1) % 2
                    elseif char == '(' && quote_count == 0
                        paren_count += 1
                    elseif char == ')' && quote_count == 0
                        paren_count -= 1
                    elseif char == ',' && paren_count == 0 && quote_count == 0
                        push!(pairs, strip(current_pair))
                        current_pair = ""
                        continue
                    end
                    current_pair *= char
                end
                if !isempty(strip(current_pair))
                    push!(pairs, strip(current_pair))
                end

                for pair in pairs
                    if contains(pair, " => ")
                        key, value = split(pair, " => ", limit=2)
                        key = strip(key, ['"', ' '])
                        value = strip(value, [' '])

                        # Try to parse as number
                        if tryparse(Float64, value) !== nothing
                            result[key] = parse(Float64, value)
                        elseif tryparse(Int, value) !== nothing
                            result[key] = parse(Int, value)
                        else
                            result[key] = strip(value, ['"'])
                        end
                    end
                end

                return result
            end
        end
        return Dict{String,Any}()
    catch e
        @warn "Failed to parse dict string: $dict_str" exception = e
        return Dict{String,Any}()
    end
end

# ╔═╡ 4b2b3c40-5c8e-11ee-1234-0123456789ab
"""
Flatten dictionary columns into separate columns with prefixes
"""
function flatten_dict_columns!(df::DataFrame, dict_cols::Vector{Symbol})
    for col in dict_cols
        if col ∉ names(df)
            continue
        end

        # Collect all unique keys across all rows
        all_keys = Set{String}()
        for row in eachrow(df)
            if !ismissing(row[col]) && isa(row[col], String)
                dict_data = parse_dict_column(row[col])
                union!(all_keys, keys(dict_data))
            end
        end

        # Create new columns for each key
        for key in all_keys
            new_col_name = Symbol("$(col)_$(key)")
            df[!, new_col_name] = Vector{Union{Missing,Real}}(missing, nrow(df))
        end

        # Fill the new columns
        for (i, row) in enumerate(eachrow(df))
            if !ismissing(row[col]) && isa(row[col], String)
                dict_data = parse_dict_column(row[col])
                for key in all_keys
                    new_col_name = Symbol("$(col)_$(key)")
                    if haskey(dict_data, key)
                        df[i, new_col_name] = dict_data[key]
                    end
                end
            end
        end

        # Remove original column
        select!(df, Not(col))
    end

    return df
end

# ╔═╡ 5b2b3c40-5c8e-11ee-1234-0123456789ab
"""
Load and process a single CSV file
"""
function load_csv_file(filepath::String, metadata::NamedTuple)
    try
        df = CSV.read(filepath, DataFrame)

        # Add metadata columns
        df[!, :scenario] .= metadata.scenario
        df[!, :architecture] .= metadata.architecture
        df[!, :run_id] .= metadata.run_id
        df[!, :file_type] .= metadata.file_type

        # Rename time column to tick if it exists
        if "time" ∈ names(df)
            rename!(df, :time => :tick)
        end

        # Ensure tick is Int if it exists
        if "tick" ∈ names(df)
            df[!, :tick] = Int.(df[!, :tick])
        end

        return df
    catch e
        @warn "Failed to load $filepath" exception = e
        return nothing
    end
end

# ╔═╡ 6b2b3c40-5c8e-11ee-1234-0123456789ab
"""
Harmonize DataFrame columns across different scenarios
"""
function harmonize_dataframes!(dfs::Vector{DataFrame}, df_type::String)
    if isempty(dfs)
        return dfs
    end

    # Collect all unique column names
    all_columns = Set{String}()
    for df in dfs
        union!(all_columns, names(df))
    end

    # Add missing columns to each DataFrame
    for df in dfs
        for col in all_columns
            if col ∉ names(df)
                # Add missing column with appropriate type
                if col == "tick"
                    df[!, Symbol(col)] = Vector{Union{Missing,Int}}(missing, nrow(df))
                elseif contains(col, "_id") || contains(col, "count") || contains(col, "nagents")
                    df[!, Symbol(col)] = Vector{Union{Missing,Int}}(missing, nrow(df))
                else
                    df[!, Symbol(col)] = Vector{Union{Missing,Float64}}(missing, nrow(df))
                end
            end
        end

        # Sort columns consistently
        metadata_cols = ["scenario", "architecture", "run_id", "file_type"]
        if "tick" ∈ names(df)
            metadata_cols = ["tick", metadata_cols...]
        end

        other_cols = [col for col in names(df) if col ∉ metadata_cols]
        sort!(other_cols)

        select!(df, [metadata_cols..., other_cols...])
    end

    return dfs
end

# ╔═╡ 7b2b3c40-5c8e-11ee-1234-0123456789ab
md"""
## 📊 Data Loading
"""

# ╔═╡ 8b2b3c40-5c8e-11ee-1234-0123456789ab
# Load all data files
begin
    model_dfs = DataFrame[]
    agent_dfs = DataFrame[]

    total_files = 0
    loaded_files = 0

    for scenario in selected_scenarios
        scenario_dir = joinpath(DATA_DIR, scenario)
        if !isdir(scenario_dir)
            continue
        end

        # Find all CSV files in scenario directory
        csv_files = glob("*.csv", scenario_dir)
        total_files += length(csv_files)

        for csv_file in csv_files
            filename = basename(csv_file)
            metadata = parse_filename(filename)

            # Skip initial agent files unless requested
            if contains(filename, "initial") && !include_initial
                continue
            end

            # Load the file
            df = load_csv_file(csv_file, metadata)
            if df !== nothing
                loaded_files += 1

                # Categorize by file type
                if contains(filename, "metrics")
                    push!(model_dfs, df)
                elseif contains(filename, "agents")
                    # Flatten traits column if it exists
                    if "traits" ∈ names(df)
                        flatten_traits_column!(df, :traits)
                    end
                    push!(agent_dfs, df)
                end
            end
        end
    end

    @info "Loaded $loaded_files out of $total_files CSV files"
end

# ╔═╡ 9b2b3c40-5c8e-11ee-1234-0123456789ab
md"""
## 🔧 Data Processing
"""

# ╔═╡ 1c2b3c40-5c8e-11ee-1234-0123456789ab
# Process model metrics data
begin
    if !isempty(model_dfs)
        # Identify dictionary columns that need flattening
        dict_columns = Symbol[]
        for df in model_dfs
            for col in names(df)
                if any(row -> !ismissing(row) && isa(row, String) && startswith(row, "Dict{"), df[!, col])
                    push!(dict_columns, Symbol(col))
                end
            end
        end
        dict_columns = unique(dict_columns)

        # Flatten dictionary columns
        for df in model_dfs
            flatten_dict_columns!(df, dict_columns)
        end

        # Harmonize columns
        harmonize_dataframes!(model_dfs, "metrics")

        # Combine all model DataFrames
        model_metrics_df = vcat(model_dfs...)

        # Sort by scenario, architecture, run_id, tick
        if "tick" ∈ names(model_metrics_df)
            sort!(model_metrics_df, [:scenario, :architecture, :run_id, :tick])
        else
            sort!(model_metrics_df, [:scenario, :architecture, :run_id])
        end
    else
        model_metrics_df = DataFrame()
    end
end

# ╔═╡ 2c2b3c40-5c8e-11ee-1234-0123456789ab
# Process agent data
begin
    if !isempty(agent_dfs)
        # Harmonize columns
        harmonize_dataframes!(agent_dfs, "agents")

        # Combine all agent DataFrames
        agent_data_df = vcat(agent_dfs...)

        # Sort by scenario, architecture, run_id, tick, id
        if "tick" ∈ names(agent_data_df) && "id" ∈ names(agent_data_df)
            sort!(agent_data_df, [:scenario, :architecture, :run_id, :tick, :id])
        elseif "tick" ∈ names(agent_data_df)
            sort!(agent_data_df, [:scenario, :architecture, :run_id, :tick])
        else
            sort!(agent_data_df, [:scenario, :architecture, :run_id])
        end
    else
        agent_data_df = DataFrame()
    end
end

# ╔═╡ 3c2b3c40-5c8e-11ee-1234-0123456789ab
md"""
## 📈 Data Summary
"""

# ╔═╡ 4c2b3c40-5c8e-11ee-1234-0123456789ab
# Generate summary statistics
begin
    summary_stats = Dict{String,Any}()

    # Model metrics summary
    if !isempty(model_metrics_df)
        summary_stats["model_runs"] = nrow(unique(model_metrics_df[!, [:scenario, :architecture, :run_id]]))
        summary_stats["model_scenarios"] = length(unique(model_metrics_df.scenario))
        summary_stats["model_architectures"] = length(unique(model_metrics_df.architecture))
        if "tick" ∈ names(model_metrics_df)
            summary_stats["model_ticks_range"] = (minimum(model_metrics_df.tick), maximum(model_metrics_df.tick))
        end
    end

    # Agent data summary
    if !isempty(agent_data_df)
        summary_stats["agent_runs"] = nrow(unique(agent_data_df[!, [:scenario, :architecture, :run_id]]))
        summary_stats["unique_agents"] = length(unique(agent_data_df.id))
        summary_stats["agent_scenarios"] = length(unique(agent_data_df.scenario))
        summary_stats["agent_architectures"] = length(unique(agent_data_df.architecture))
        if "tick" ∈ names(agent_data_df)
            summary_stats["agent_ticks_range"] = (minimum(agent_data_df.tick), maximum(agent_data_df.tick))
        end
    end

    summary_stats
end

# ╔═╡ 5c2b3c40-5c8e-11ee-1234-0123456789ab
md"""
### 📊 Summary Statistics

**Model Metrics Data:**
- Runs loaded: $(get(summary_stats, "model_runs", 0))
- Scenarios: $(get(summary_stats, "model_scenarios", 0))
- Architectures: $(get(summary_stats, "model_architectures", 0))
- Tick range: $(get(summary_stats, "model_ticks_range", "N/A"))

**Agent Data:**
- Runs loaded: $(get(summary_stats, "agent_runs", 0))
- Unique agents: $(get(summary_stats, "unique_agents", 0))
- Scenarios: $(get(summary_stats, "agent_scenarios", 0))
- Architectures: $(get(summary_stats, "agent_architectures", 0))
- Tick range: $(get(summary_stats, "agent_ticks_range", "N/A"))
"""

# ╔═╡ 6c2b3c40-5c8e-11ee-1234-0123456789ab
md"""
## 🔍 Data Preview
"""

# ╔═╡ 7c2b3c40-5c8e-11ee-1234-0123456789ab
md"""
### Model Metrics DataFrame Preview
"""

# ╔═╡ 8c2b3c40-5c8e-11ee-1234-0123456789ab
if !isempty(model_metrics_df)
    first(model_metrics_df, 5)
else
    md"No model metrics data loaded."
end

# ╔═╡ 9c2b3c40-5c8e-11ee-1234-0123456789ab
md"""
### Agent Data DataFrame Preview
"""

# ╔═╡ 1d2b3c40-5c8e-11ee-1234-0123456789ab
if !isempty(agent_data_df)
    first(agent_data_df, 5)
else
    md"No agent data loaded."
end

# ╔═╡ 2d2b3c40-5c8e-11ee-1234-0123456789ab
md"""
## 💾 Export Data

**Export harmonized data?** $(@bind export_data CheckBox(default=false))
"""

# ╔═╡ 3d2b3c40-5c8e-11ee-1234-0123456789ab
# Export data if requested
if export_data
    try
        if !isempty(model_metrics_df)
            model_export_path = joinpath(RESULTS_DIR, "combined_model_metrics.csv")
            CSV.write(model_export_path, model_metrics_df)
            @info "Exported model metrics to $model_export_path"
        end

        if !isempty(agent_data_df)
            agent_export_path = joinpath(RESULTS_DIR, "combined_agents.csv")
            CSV.write(agent_export_path, agent_data_df)
            @info "Exported agent data to $agent_export_path"
        end

        # Export summary
        summary_export_path = joinpath(RESULTS_DIR, "data_summary.json")
        open(summary_export_path, "w") do f
            JSON3.pretty(f, summary_stats)
        end
        @info "Exported summary to $summary_export_path"

        md"✅ Data exported successfully to `$(RESULTS_DIR)`"
    catch e
        md"❌ Export failed: $e"
    end
else
    md"Export disabled. Check the box above to export data."
end

# ╔═╡ 4d2b3c40-5c8e-11ee-1234-0123456789ab
md"""
## 🎯 Filtering Functions

These functions can be used in other notebooks to filter the loaded data:
"""

# ╔═╡ 5d2b3c40-5c8e-11ee-1234-0123456789ab
"""
Filter data by scenario(s)
"""
function filter_by_scenario(df::DataFrame, scenarios::Union{String,Vector{String}})
    if isa(scenarios, String)
        scenarios = [scenarios]
    end
    return filter(row -> row.scenario ∈ scenarios, df)
end

# ╔═╡ 6d2b3c40-5c8e-11ee-1234-0123456789ab
"""
Filter data by architecture(s)
"""
function filter_by_architecture(df::DataFrame, architectures::Union{String,Vector{String}})
    if isa(architectures, String)
        architectures = [architectures]
    end
    return filter(row -> row.architecture ∈ architectures, df)
end

# ╔═╡ 7d2b3c40-5c8e-11ee-1234-0123456789ab
"""
Filter data by run_id(s)
"""
function filter_by_run_id(df::DataFrame, run_ids::Union{String,Vector{String}})
    if isa(run_ids, String)
        run_ids = [run_ids]
    end
    return filter(row -> row.run_id ∈ run_ids, df)
end

# ╔═╡ 8d2b3c40-5c8e-11ee-1234-0123456789ab
"""
Filter data by tick range
"""
function filter_by_tick_range(df::DataFrame, min_tick::Int, max_tick::Int)
    if "tick" ∉ names(df)
        @warn "No tick column found in DataFrame"
        return df
    end
    return filter(row -> min_tick <= row.tick <= max_tick, df)
end

# ╔═╡ 9d2b3c40-5c8e-11ee-1234-0123456789ab
md"""
## 📋 Column Information

### Model Metrics Columns
$(if !isempty(model_metrics_df)
    join(["- `$(col)`" for col in names(model_metrics_df)], "\n")
else
    "No model metrics data loaded."
end)

### Agent Data Columns
$(if !isempty(agent_data_df)
    join(["- `$(col)`" for col in names(agent_data_df)], "\n")
else
    "No agent data loaded."
end)
"""

# ╔═╡ 1e2b3c40-5c8e-11ee-1234-0123456789ab
md"""
---
**📝 Usage Notes:**

1. **Data Access:** The main outputs are `model_metrics_df` and `agent_data_df`
2. **Filtering:** Use the provided filter functions to subset data by scenario, architecture, run_id, or tick range
3. **Traits:** Big Five and Schwartz traits are automatically flattened into separate columns (e.g., `Openness`, `Conscientiousness`)
4. **Dictionary Columns:** Complex metrics (like network metrics) are flattened with prefixes (e.g., `credit_network_metrics_density`)
5. **Missing Data:** Missing columns are added with appropriate default types across all DataFrames

**🔗 Next Steps:**
- Use this data in analysis notebooks
- Filter by specific scenarios or architectures as needed
- Combine with visualization notebooks for plotting

**📊 Example Usage:**
```julia
# Filter for credit scenarios only
credit_data = filter_by_scenario(model_metrics_df, "credit")

# Compare rule vs LLM architectures
rule_data = filter_by_architecture(agent_data_df, "rule")
llm_data = filter_by_architecture(agent_data_df, "llm")

# Focus on early simulation steps
early_data = filter_by_tick_range(model_metrics_df, 0, 50)
```
"""

# ╔═╡ Cell order:
# ╟─1a2b3c40-5c8e-11ee-1234-0123456789ab
# ╠═8a2b4c40-5c8e-11ee-1234-0123456789ab
# ╟─2a2b3c40-5c8e-11ee-1234-0123456789ab
# ╠═3a2b3c40-5c8e-11ee-1234-0123456789ab
# ╠═4a2b3c40-5c8e-11ee-1234-0123456789ab
# ╟─5a2b3c40-5c8e-11ee-1234-0123456789ab
# ╠═6a2b3c40-5c8e-11ee-1234-0123456789ab
# ╟─7a2b3c40-5c8e-11ee-1234-0123456789ab
# ╟─8a2b3c40-5c8e-11ee-1234-0123456789ac
# ╟─9a2b3c40-5c8e-11ee-1234-0123456789ab
# ╠═1b2b3c40-5c8e-11ee-1234-0123456789ab
# ╠═2b2b3c40-5c8e-11ee-1234-0123456789ab
# ╠═3b2b3c40-5c8e-11ee-1234-0123456789ab
# ╠═4b2b3c40-5c8e-11ee-1234-0123456789ab
# ╠═5b2b3c40-5c8e-11ee-1234-0123456789ab
# ╠═6b2b3c40-5c8e-11ee-1234-0123456789ab
# ╟─7b2b3c40-5c8e-11ee-1234-0123456789ab
# ╠═8b2b3c40-5c8e-11ee-1234-0123456789ab
# ╟─9b2b3c40-5c8e-11ee-1234-0123456789ab
# ╠═1c2b3c40-5c8e-11ee-1234-0123456789ab
# ╠═2c2b3c40-5c8e-11ee-1234-0123456789ab
# ╟─3c2b3c40-5c8e-11ee-1234-0123456789ab
# ╠═4c2b3c40-5c8e-11ee-1234-0123456789ab
# ╟─5c2b3c40-5c8e-11ee-1234-0123456789ab
# ╟─6c2b3c40-5c8e-11ee-1234-0123456789ab
# ╟─7c2b3c40-5c8e-11ee-1234-0123456789ab
# ╠═8c2b3c40-5c8e-11ee-1234-0123456789ab
# ╟─9c2b3c40-5c8e-11ee-1234-0123456789ab
# ╠═1d2b3c40-5c8e-11ee-1234-0123456789ab
# ╟─2d2b3c40-5c8e-11ee-1234-0123456789ab
# ╠═3d2b3c40-5c8e-11ee-1234-0123456789ab
# ╟─4d2b3c40-5c8e-11ee-1234-0123456789ab
# ╠═5d2b3c40-5c8e-11ee-1234-0123456789ab
# ╠═6d2b3c40-5c8e-11ee-1234-0123456789ab
# ╠═7d2b3c40-5c8e-11ee-1234-0123456789ab
# ╠═8d2b3c40-5c8e-11ee-1234-0123456789ab
# ╟─9d2b3c40-5c8e-11ee-1234-0123456789ab
# ╟─1e2b3c40-5c8e-11ee-1234-0123456789ab
