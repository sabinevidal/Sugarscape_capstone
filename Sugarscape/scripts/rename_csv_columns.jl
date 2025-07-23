#!/usr/bin/env julia

using CSV
using DataFrames
using Glob

"""
Script to rename columns in existing CSV files from Sugarscape simulations.
Usage: julia rename_csv_columns.jl [directory_path]
If no directory is provided, it will process all CSV files in data/results/simulations/
"""

# Define column renaming mappings
const METRICS_COLUMN_MAP = Dict(
    "time" => "simulation_step",
    "nagents" => "population_size",
    "births" => "new_births",
    "deaths_age" => "deaths_by_age",
    "deaths_starvation" => "deaths_by_starvation",
    "gini_coefficient" => "wealth_inequality_gini",
    "wealth_percentiles" => "wealth_distribution",
    "pareto_alpha" => "wealth_pareto_alpha",
    "mean_lifespan" => "average_lifespan",
    "lifespan_inequality" => "lifespan_gini"
)

const AGENTS_COLUMN_MAP = Dict(
    "time" => "simulation_step",
    "id" => "agent_id",
    "pos" => "position",
    "sugar" => "wealth_sugar",
    "age" => "current_age",
    "vision" => "vision_range",
    "metabolism" => "sugar_metabolism",
    "sex" => "gender",
    "culture" => "cultural_tags",
    "children" => "offspring_ids",
    "has_reproduced" => "reproduced_this_step",
    "total_inheritance_received" => "inherited_wealth",
    "last_partner_id" => "reproduction_partners",
    "last_credit_partner" => "credit_partners"
)

function rename_csv_columns(file_path::String, column_map::Dict{String,String})
    """Rename columns in a CSV file according to the provided mapping."""
    println("📄 Processing: $(basename(file_path))")
    
    # Read the CSV file
    df = CSV.read(file_path, DataFrame)
    original_names = names(df)
    
    # Apply column renaming
    renamed_count = 0
    for (old_name, new_name) in column_map
        if old_name in original_names
            println("  🔄 Renaming: $old_name → $new_name")
            rename!(df, old_name => new_name)
            renamed_count += 1
        end
    end
    
    if renamed_count > 0
        # Create backup of original file
        backup_path = file_path * ".backup"
        if !isfile(backup_path)
            cp(file_path, backup_path)
            println("  💾 Backup created: $(basename(backup_path))")
        end
        
        # Write the modified DataFrame back to CSV
        CSV.write(file_path, df)
        println("  ✅ Updated with $renamed_count column renames")
    else
        println("  ⚠️  No matching columns found to rename")
    end
    
    return renamed_count
end

function process_directory(directory_path::String)
    """Process all CSV files in a directory."""
    println("🔍 Searching for CSV files in: $directory_path")
    
    # Find all CSV files recursively
    csv_files = glob("**/*.csv", directory_path)
    
    if isempty(csv_files)
        println("❌ No CSV files found in $directory_path")
        return
    end
    
    println("📊 Found $(length(csv_files)) CSV files")
    
    total_renamed = 0
    
    for csv_file in csv_files
        filename = basename(csv_file)
        
        # Determine file type and apply appropriate column mapping
        if contains(filename, "metrics")
            total_renamed += rename_csv_columns(csv_file, METRICS_COLUMN_MAP)
        elseif contains(filename, "agents") && !contains(filename, "initial")
            total_renamed += rename_csv_columns(csv_file, AGENTS_COLUMN_MAP)
        elseif contains(filename, "initial_agents")
            total_renamed += rename_csv_columns(csv_file, AGENTS_COLUMN_MAP)
        else
            println("⚠️  Skipping unknown file type: $filename")
        end
        
        println()  # Add blank line between files
    end
    
    println("🎉 Processing complete! Total columns renamed: $total_renamed")
end

function main()
    # Get directory path from command line argument or use default
    directory_path = if length(ARGS) > 0
        ARGS[1]
    else
        "data/results/simulations"
    end
    
    # Check if directory exists
    if !isdir(directory_path)
        println("❌ Directory not found: $directory_path")
        println("Usage: julia rename_csv_columns.jl [directory_path]")
        exit(1)
    end
    
    println("🚀 Starting CSV column renaming process...")
    println("📁 Target directory: $directory_path")
    println()
    
    process_directory(directory_path)
end

# Run the script
if abspath(PROGRAM_FILE) == @__FILE__
    main()
end
