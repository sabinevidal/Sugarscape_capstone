#!/usr/bin/env julia

"""
Script to map numbered metric columns to their actual names.

This script reads metric CSV files and creates a mapping from numbered columns
(like #95, #96, #97) to their actual metric function names as defined in metrics_sets.jl.

Usage:
    julia map_metric_columns.jl <csv_file_path> [metric_set_name]

Examples:
    julia map_metric_columns.jl data/for_analysis/combat/movement_combat_bigfive_metrics_1.csv combat_metrics
    julia map_metric_columns.jl data/results/simulations/movement_reproduction_rule/movement_reproduction_rule_metrics_1.csv reproduction_metrics
"""

using CSV
using DataFrames
using Dates
using Sugarscape

# Function to extract metric name from a function expression
function extract_metric_name(func_expr)
    func_str = string(func_expr)

    # Handle simple function names like 'nagents'
    if !contains(func_str, "->")
        return func_str
    end

    # Handle lambda expressions like 'model -> model.combat_kills'
    if contains(func_str, "model.")
        # Extract the property name after 'model.'
        parts = split(func_str, "model.")
        if length(parts) >= 2
            prop_name = split(parts[2], r"[,\)\s]")[1]  # Get first word after model.
            return prop_name
        end
    end

    # Handle function calls like 'model -> calculate_gini_coefficient(model)'
    if contains(func_str, "(model)")
        # Extract function name before (model)
        match_result = match(r"(\w+)\(model\)", func_str)
        if match_result !== nothing
            return match_result.captures[1]
        end
    end

    # Fallback: return the full string
    return func_str
end

# Function to get metric names from a metric set
function get_metric_names(metric_set)
    return [extract_metric_name(func) for func in metric_set]
end

# Function to detect metric set from CSV file path
function detect_metric_set(csv_path)
    path_lower = lowercase(csv_path)

    if contains(path_lower, "combat") && contains(path_lower, "reproduction")
        return "reproduction_combat_metrics"
    elseif contains(path_lower, "combat")
        return "combat_metrics"
    elseif contains(path_lower, "reproduction") && contains(path_lower, "culture")
        return "reproduction_culture_metrics"
    elseif contains(path_lower, "reproduction")
        return "reproduction_metrics"
    elseif contains(path_lower, "culture") && contains(path_lower, "credit")
        return "culture_credit_metrics"
    elseif contains(path_lower, "culture")
        return "culture_metrics"
    elseif contains(path_lower, "credit") && contains(path_lower, "reproduction")
        return "credit_reproduction_metrics"
    elseif contains(path_lower, "credit")
        return "credit_metrics"
    elseif contains(path_lower, "full_stack")
        return "full_stack_metrics"
    else
        return "unknown"
    end
end

# Create a comprehensive global metric mapping
function create_global_metric_mapping()
    # This maps global metric numbers to their actual function names
    # Based on analysis of the CSV files and metric sets
    global_mapping = Dict{Int,String}()

    # Combat metrics (observed: #95, #96, #97)
    global_mapping[95] = "combat_kills"  # model -> model.combat_kills
    global_mapping[96] = "combat_sugar_stolen"  # model -> model.combat_sugar_stolen
    global_mapping[97] = "calculate_factional_clustering"  # model -> calculate_factional_clustering(model)

    # Reproduction metrics (observed: #77-#85)
    global_mapping[77] = "births"  # model -> model.births
    global_mapping[78] = "deaths_age"  # model -> model.deaths_age
    global_mapping[79] = "deaths_starvation"  # model -> model.deaths_starvation
    global_mapping[80] = "calculate_gini_coefficient"  # model -> calculate_gini_coefficient(model)
    global_mapping[81] = "calculate_wealth_percentiles"  # model -> calculate_wealth_percentiles(model)
    global_mapping[82] = "calculate_pareto_alpha"  # model -> calculate_pareto_alpha(model)
    global_mapping[83] = "calculate_mean_lifespan"  # model -> calculate_mean_lifespan(model)
    global_mapping[84] = "calculate_lifespan_inequality"  # model -> calculate_lifespan_inequality(model)
    global_mapping[85] = "calculate_decision_entropy"  # model -> calculate_decision_entropy(model)

    # Culture metrics (observed: #101-#104)
    global_mapping[101] = "calculate_cultural_entropy"  # model -> calculate_cultural_entropy(model)
    global_mapping[102] = "calculate_cultural_diversity"  # model -> calculate_cultural_diversity(model)
    global_mapping[103] = "calculate_spatial_segregation"  # model -> calculate_spatial_segregation(model)
    global_mapping[104] = "calculate_clustering_coefficient"  # model -> calculate_clustering_coefficient(model)
    global_mapping[105] = "count_red_tribe"  # model -> count_red_tribe(model)
    global_mapping[106] = "count_blue_tribe"  # model -> count_blue_tribe(model)
    global_mapping[107] = "calculate_tribe_proportions"  # model -> calculate_tribe_proportions(model)
    global_mapping[108] = "calculate_wealth_percentiles"  # model -> calculate_wealth_percentiles(model)
    global_mapping[109] = "calculate_pareto_alpha"  # model -> calculate_pareto_alpha(model)
    global_mapping[110] = "model.deaths_age"  # model -> model.deaths_age
    global_mapping[111] = "model.deaths_starvation"  # model -> model.deaths_starvation
    global_mapping[112] = "calculate_cultural_initiation_by_tribe"  # model -> calculate_cultural_initiation_by_tribe(model)

    # Credit metrics (observed: #125-#128)
    global_mapping[125] = "total_credit_outstanding"  # model -> calculate_total_credit_outstanding(model)
    global_mapping[126] = "credit_default_rate"  # model -> calculate_credit_default_rate(model)
    global_mapping[127] = "credit_network_metrics"  # model -> calculate_credit_network_metrics(model)
    global_mapping[128] = "gini_coefficient"  # model -> calculate_gini_coefficient(model)

    # Reproduction + Combat metrics (observed: #133-#142)
    # Based on reproduction_combat_metrics order: nagents, births, deaths_age, deaths_starvation, 
    # calculate_gini_coefficient, calculate_wealth_percentiles, calculate_pareto_alpha, 
    # calculate_mean_lifespan, calculate_lifespan_inequality, combat_kills, calculate_factional_clustering
    global_mapping[133] = "births"  # model -> model.births
    global_mapping[134] = "deaths_age"  # model -> model.deaths_age
    global_mapping[135] = "deaths_starvation"  # model -> model.deaths_starvation
    global_mapping[136] = "calculate_gini_coefficient"  # model -> calculate_gini_coefficient(model)
    global_mapping[137] = "calculate_wealth_percentiles"  # model -> calculate_wealth_percentiles(model)
    global_mapping[138] = "calculate_pareto_alpha"  # model -> calculate_pareto_alpha(model)
    global_mapping[139] = "calculate_mean_lifespan"  # model -> calculate_mean_lifespan(model)
    global_mapping[140] = "calculate_lifespan_inequality"  # model -> calculate_lifespan_inequality(model)
    global_mapping[141] = "combat_kills"  # model -> model.combat_kills
    global_mapping[142] = "calculate_factional_clustering"  # model -> calculate_factional_clustering(model)

    # Culture + Credit metrics (observed: #215-#227)
    # Based on culture_credit_metrics order: nagents, calculate_cultural_entropy, calculate_cultural_diversity,
    # calculate_spatial_segregation, calculate_clustering_coefficient, calculate_wealth_percentiles,
    # calculate_pareto_alpha, deaths_age, deaths_starvation, calculate_cultural_initiation_by_tribe,
    # calculate_total_credit_outstanding, calculate_credit_default_rate, calculate_credit_network_metrics, calculate_gini_coefficient
    global_mapping[215] = "calculate_cultural_entropy"  # model -> calculate_cultural_entropy(model)
    global_mapping[216] = "calculate_cultural_diversity"  # model -> calculate_cultural_diversity(model)
    global_mapping[217] = "calculate_spatial_segregation"  # model -> calculate_spatial_segregation(model)
    global_mapping[218] = "calculate_clustering_coefficient"  # model -> calculate_clustering_coefficient(model)
    global_mapping[219] = "calculate_wealth_percentiles"  # model -> calculate_wealth_percentiles(model)
    global_mapping[220] = "calculate_pareto_alpha"  # model -> calculate_pareto_alpha(model)
    global_mapping[221] = "deaths_age"  # model -> model.deaths_age
    global_mapping[222] = "deaths_starvation"  # model -> model.deaths_starvation
    global_mapping[223] = "calculate_cultural_initiation_by_tribe"  # model -> calculate_cultural_initiation_by_tribe(model)
    global_mapping[224] = "calculate_total_credit_outstanding"  # model -> calculate_total_credit_outstanding(model)
    global_mapping[225] = "calculate_credit_default_rate"  # model -> calculate_credit_default_rate(model)
    global_mapping[226] = "calculate_credit_network_metrics"  # model -> calculate_credit_network_metrics(model)
    global_mapping[227] = "calculate_gini_coefficient"  # model -> calculate_gini_coefficient(model)

    # Add more mappings as discovered from other CSV files
    # Full stack metrics, etc.

    return global_mapping
end

# Function to create column mapping using global metric numbers
function create_column_mapping(csv_file_path, metric_set_name=nothing)
    # Read CSV to get column names
    df = CSV.read(csv_file_path, DataFrame, limit=1)  # Only read header
    column_names = names(df)

    # Auto-detect metric set if not provided
    if metric_set_name === nothing
        metric_set_name = detect_metric_set(csv_file_path)
        println("Auto-detected metric set: $metric_set_name")
    end

    # Get the appropriate metric set for reference
    metric_set = if metric_set_name == "combat_metrics"
        combat_metrics
    elseif metric_set_name == "reproduction_metrics"
        reproduction_metrics
    elseif metric_set_name == "culture_metrics"
        culture_metrics
    elseif metric_set_name == "credit_metrics"
        credit_metrics
    elseif metric_set_name == "reproduction_combat_metrics"
        reproduction_combat_metrics
    elseif metric_set_name == "reproduction_culture_metrics"
        reproduction_culture_metrics
    elseif metric_set_name == "credit_reproduction_metrics"
        credit_reproduction_metrics
    elseif metric_set_name == "culture_credit_metrics"
        culture_credit_metrics
    elseif metric_set_name == "full_stack_metrics"
        full_stack_metrics
    else
        error("Unknown metric set: $metric_set_name")
    end

    # Get metric names from the local set for reference
    local_metric_names = get_metric_names(metric_set)

    # Get global metric mapping
    global_mapping = create_global_metric_mapping()

    # Create column mapping
    mapping = Dict{String,String}()

    for col_name in column_names
        if startswith(col_name, "#")
            # Extract the number from the column name
            num_str = col_name[2:end]  # Remove the '#' prefix
            try
                col_num = parse(Int, num_str)

                # Use global mapping if available
                if haskey(global_mapping, col_num)
                    mapping[col_name] = global_mapping[col_num]
                else
                    # Fallback: try to match with local metric set (less reliable)
                    if col_num >= 1 && col_num <= length(local_metric_names)
                        mapping[col_name] = "$(local_metric_names[col_num])_local_fallback"
                    else
                        mapping[col_name] = "unknown_metric_$col_num"
                    end
                end
            catch
                mapping[col_name] = "invalid_column_$col_name"
            end
        else
            # Keep non-numbered columns as-is
            mapping[col_name] = col_name
        end
    end

    return mapping, metric_set_name, local_metric_names
end

# Function to print mapping in a readable format
function print_mapping(mapping, csv_file_path, metric_set_name)
    println("="^80)
    println("METRIC COLUMN MAPPING")
    println("="^80)
    println("CSV File: $csv_file_path")
    println("Metric Set: $metric_set_name")
    println("="^80)

    # Sort by column name for better readability
    sorted_keys = sort(collect(keys(mapping)))

    for col_name in sorted_keys
        metric_name = mapping[col_name]
        if startswith(col_name, "#")
            println("$col_name => $metric_name")
        end
    end

    println("="^80)
end

# Function to save mapping to file
function save_mapping_to_file(mapping, csv_file_path, metric_set_name, output_file=nothing)
    if output_file === nothing
        # Generate output filename based on input CSV
        base_name = splitext(basename(csv_file_path))[1]
        output_file = "$(base_name)_column_mapping.txt"
    end

    open(output_file, "w") do f
        println(f, "METRIC COLUMN MAPPING")
        println(f, "="^50)
        println(f, "CSV File: $csv_file_path")
        println(f, "Metric Set: $metric_set_name")
        println(f, "Generated: $(Dates.now())")
        println(f, "="^50)
        println(f)

        # Sort by column name for better readability
        sorted_keys = sort(collect(keys(mapping)))

        for col_name in sorted_keys
            metric_name = mapping[col_name]
            if startswith(col_name, "#")
                println(f, "$col_name => $metric_name")
            end
        end
    end

    println("Mapping saved to: $output_file")
end

# Function to show available metric sets
function show_available_metric_sets()
    println("Available metric sets:")
    println("- combat_metrics")
    println("- reproduction_metrics")
    println("- culture_metrics")
    println("- credit_metrics")
    println("- reproduction_combat_metrics")
    println("- reproduction_culture_metrics")
    println("- credit_reproduction_metrics")
    println("- culture_credit_metrics")
    println("- full_stack_metrics")
end

# Main execution
function main()
    if length(ARGS) == 0
        println("Usage: julia map_metric_columns.jl <csv_file_path> [metric_set_name]")
        println()
        show_available_metric_sets()
        return
    end

    csv_file_path = ARGS[1]
    metric_set_name = length(ARGS) >= 2 ? ARGS[2] : nothing

    if !isfile(csv_file_path)
        error("CSV file not found: $csv_file_path")
    end

    try
        # Create mapping
        mapping, detected_metric_set, metric_names = create_column_mapping(csv_file_path, metric_set_name)

        # Print mapping
        print_mapping(mapping, csv_file_path, detected_metric_set)

        # Save to file
        save_mapping_to_file(mapping, csv_file_path, detected_metric_set)

        # Show metric set details
        println("\nMetric Set Details:")
        println("Total metrics: $(length(metric_names))")
        for (i, name) in enumerate(metric_names)
            println("  #$i => $name")
        end

    catch e
        println("Error: $e")
        show_available_metric_sets()
    end
end

# Run main function if script is executed directly
if abspath(PROGRAM_FILE) == @__FILE__
    main()
end
