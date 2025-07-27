#!/usr/bin/env julia

"""
Preprocess combat metrics CSV files to parse dictionary columns into separate numeric columns.
This script processes all combat metrics files and creates cleaned versions.
"""

using CSV
using DataFrames
using Printf

function parse_dict_string(dict_str::String)
    """Parse a dictionary string and extract key-value pairs."""
    result = Dict{String, Float64}()
    
    # Extract key-value pairs using regex
    # Pattern: "key" => value
    pattern = r"\"([^\"]+)\"\s*=>\s*([0-9.]+)"
    
    for match in eachmatch(pattern, dict_str)
        key = match.captures[1]
        value = parse(Float64, match.captures[2])
        result[key] = value
    end
    
    return result
end

function parse_attack_metrics_dict!(df::DataFrame, col_name::String)
    """Parse attack metrics dictionary column."""
    # Initialize new columns
    df[!, :total_attacks] = Vector{Union{Missing, Int64}}(missing, nrow(df))
    df[!, :red_initiated_attacks] = Vector{Union{Missing, Int64}}(missing, nrow(df))
    df[!, :blue_initiated_attacks] = Vector{Union{Missing, Int64}}(missing, nrow(df))
    df[!, :red_attack_rate] = Vector{Union{Missing, Float64}}(missing, nrow(df))
    df[!, :blue_attack_rate] = Vector{Union{Missing, Float64}}(missing, nrow(df))
    
    # Parse each row
    for i in 1:nrow(df)
        dict_str = df[i, col_name]
        
        if !ismissing(dict_str) && isa(dict_str, String) && contains(dict_str, "Dict{")
            try
                parsed_dict = parse_dict_string(dict_str)
                
                # Extract values
                if haskey(parsed_dict, "total_attacks")
                    df[i, :total_attacks] = Int64(parsed_dict["total_attacks"])
                end
                if haskey(parsed_dict, "red_initiated_attacks")
                    df[i, :red_initiated_attacks] = Int64(parsed_dict["red_initiated_attacks"])
                end
                if haskey(parsed_dict, "blue_initiated_attacks")
                    df[i, :blue_initiated_attacks] = Int64(parsed_dict["blue_initiated_attacks"])
                end
                if haskey(parsed_dict, "red_attack_rate")
                    df[i, :red_attack_rate] = parsed_dict["red_attack_rate"]
                end
                if haskey(parsed_dict, "blue_attack_rate")
                    df[i, :blue_attack_rate] = parsed_dict["blue_attack_rate"]
                end
                
            catch e
                println("   ⚠️ Failed to parse attack metrics row $i: $e")
            end
        end
    end
    
    println("   ✅ Parsed attack metrics into 5 numeric columns")
end

function parse_wealth_percentiles_dict!(df::DataFrame, col_name::String)
    """Parse wealth percentiles dictionary column."""
    # Initialize new columns for percentiles
    df[!, :wealth_p25] = Vector{Union{Missing, Float64}}(missing, nrow(df))
    df[!, :wealth_p50] = Vector{Union{Missing, Float64}}(missing, nrow(df))
    df[!, :wealth_p75] = Vector{Union{Missing, Float64}}(missing, nrow(df))
    df[!, :wealth_p90] = Vector{Union{Missing, Float64}}(missing, nrow(df))
    df[!, :wealth_p95] = Vector{Union{Missing, Float64}}(missing, nrow(df))
    df[!, :wealth_p99] = Vector{Union{Missing, Float64}}(missing, nrow(df))
    
    # Parse each row
    for i in 1:nrow(df)
        dict_str = df[i, col_name]
        
        if !ismissing(dict_str) && isa(dict_str, String) && contains(dict_str, "Dict")
            try
                # Extract percentile values using regex
                # Pattern: :p25 => value or "p25" => value
                percentiles = ["p25", "p50", "p75", "p90", "p95", "p99"]
                
                for p in percentiles
                    # Try both :p25 and "p25" patterns
                    pattern1 = Regex(":$(p)\\s*=>\\s*([0-9.]+)")
                    pattern2 = Regex("\"$(p)\"\\s*=>\\s*([0-9.]+)")
                    
                    match1 = match(pattern1, dict_str)
                    match2 = match(pattern2, dict_str)
                    
                    if match1 !== nothing
                        value = parse(Float64, match1.captures[1])
                        df[i, Symbol("wealth_$(p)")] = value
                    elseif match2 !== nothing
                        value = parse(Float64, match2.captures[1])
                        df[i, Symbol("wealth_$(p)")] = value
                    end
                end
                
            catch e
                println("   ⚠️ Failed to parse wealth percentiles row $i: $e")
            end
        end
    end
    
    println("   ✅ Parsed wealth percentiles into 6 numeric columns")
end

function parse_combat_network_dict!(df::DataFrame, col_name::String)
    """Parse combat network metrics dictionary column."""
    # Initialize new columns for combat network metrics
    df[!, :avg_cultural_distance] = Vector{Union{Missing, Float64}}(missing, nrow(df))
    df[!, :conflict_rate] = Vector{Union{Missing, Float64}}(missing, nrow(df))
    df[!, :potential_conflicts] = Vector{Union{Missing, Int64}}(missing, nrow(df))
    
    # Parse each row
    for i in 1:nrow(df)
        dict_str = df[i, col_name]
        
        if !ismissing(dict_str) && isa(dict_str, String) && contains(dict_str, "Dict{")
            try
                parsed_dict = parse_dict_string(dict_str)
                
                # Extract values
                if haskey(parsed_dict, "avg_cultural_distance")
                    df[i, :avg_cultural_distance] = parsed_dict["avg_cultural_distance"]
                end
                if haskey(parsed_dict, "conflict_rate")
                    df[i, :conflict_rate] = parsed_dict["conflict_rate"]
                end
                if haskey(parsed_dict, "potential_conflicts")
                    df[i, :potential_conflicts] = Int64(parsed_dict["potential_conflicts"])
                end
                
            catch e
                println("   ⚠️ Failed to parse combat network metrics row $i: $e")
            end
        end
    end
    
    println("   ✅ Parsed combat network metrics into 3 numeric columns")
end

function parse_generic_dict!(df::DataFrame, col_name::String)
    """Parse generic dictionary column."""
    println("   ℹ️ Generic dictionary parsing for $(col_name) - keeping as string for now")
    # For now, just keep generic dictionaries as strings
    # Can be extended later if specific patterns are identified
end

function process_metrics_file(input_path::String, output_path::String)
    """Process a single metrics CSV file."""
    println("📁 Processing: $(basename(input_path))")
    
    # Read the original CSV
    df = CSV.read(input_path, DataFrame)
    
    dictionary_columns_found = 0
    
    # Process all columns that might contain dictionaries
    for col_name in names(df)
        col_data = df[!, col_name]
        
        # Check if this column contains dictionary strings
        if eltype(col_data) == String || eltype(col_data) <: Union{Missing, String} || eltype(col_data) == Any
            # Sample a few non-missing values to check for dictionary content
            non_missing_vals = filter(!ismissing, col_data)
            if !isempty(non_missing_vals)
                sample_vals = non_missing_vals[1:min(3, length(non_missing_vals))]
                sample_strs = string.(sample_vals)
                
                if any(contains.(sample_strs, "Dict{"))
                    dictionary_columns_found += 1
                    println("   🔍 Found dictionary column: $(col_name)")
                    
                    # Handle different types of dictionary columns
                    if col_name == "calculate_factional_clustering" || contains(string(col_name), "142")
                        # Combat/attack metrics dictionary
                        parse_attack_metrics_dict!(df, col_name)
                    elseif col_name == "combat_sugar_stolen" || contains(string(col_name), "96")
                        # Combat network metrics dictionary
                        parse_combat_network_dict!(df, col_name)
                    elseif contains(string(col_name), "137") || contains(sample_strs[1], ":p25")
                        # Wealth percentiles dictionary
                        parse_wealth_percentiles_dict!(df, col_name)
                    else
                        # Generic dictionary parsing
                        parse_generic_dict!(df, col_name)
                    end
                    
                    # Remove the original dictionary column
                    select!(df, Not(Symbol(col_name)))
                    println("   🗑️ Removed original dictionary column: $(col_name)")
                end
            end
        end
    end
    
    if dictionary_columns_found == 0
        println("   ℹ️ No dictionary columns found")
    else
        println("   ✅ Processed $(dictionary_columns_found) dictionary columns")
    end
    
    # Write the cleaned CSV
    CSV.write(output_path, df)
    println("   💾 Saved to: $(basename(output_path))")
    
    return df
end

function main()
    # Define base data directory
    base_data_dir = "/Users/sabinevidal/Documents/LIS/Capstone/Sugarscape_capstone/Sugarscape/data/for_analysis"
    
    if !isdir(base_data_dir)
        println("❌ Data directory not found: $base_data_dir")
        return
    end
    
    # Find all scenario directories
    scenario_dirs = filter(d -> isdir(joinpath(base_data_dir, d)), readdir(base_data_dir))
    
    if isempty(scenario_dirs)
        println("❌ No scenario directories found in $base_data_dir")
        return
    end
    
    println("🚀 Starting metrics preprocessing for all scenarios...")
    println("📂 Found scenario directories: $(join(scenario_dirs, ", "))")
    
    total_processed = 0
    
    for scenario in scenario_dirs
        scenario_path = joinpath(base_data_dir, scenario)
        println("\n📁 Processing scenario: $scenario")
        
        # Find all metrics CSV files in this scenario
        csv_files = filter(f -> endswith(f, ".csv") && contains(f, "metrics"), readdir(scenario_path))
        
        if isempty(csv_files)
            println("   ℹ️ No metrics CSV files found in $scenario")
            continue
        end
        
        println("   📊 Found $(length(csv_files)) metrics files")
        scenario_processed = 0
        
        for csv_file in csv_files
            # Skip already processed files
            if contains(csv_file, "_cleaned")
                continue
            end
            
            input_path = joinpath(scenario_path, csv_file)
            
            # Create output filename
            base_name = replace(csv_file, ".csv" => "")
            output_file = "$(base_name)_cleaned.csv"
            output_path = joinpath(scenario_path, output_file)
            
            try
                process_metrics_file(input_path, output_path)
                scenario_processed += 1
                total_processed += 1
            catch e
                println("❌ Failed to process $csv_file: $e")
            end
        end
        
        println("   ✅ Processed $scenario_processed files in $scenario")
    end
    
    println("\n🎉 All scenarios preprocessing complete!")
    println("📊 Total processed: $total_processed files")
    println("💡 Use the '_cleaned.csv' files for analysis")
end

# Run the script
if abspath(PROGRAM_FILE) == @__FILE__
    main()
end
