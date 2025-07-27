#!/usr/bin/env julia

"""
Script to rename numbered metric columns in CSV files to their actual names.

This script takes CSV files with numbered columns (like #95, #96, #97) and renames them
to their actual metric function names (like combat_kills, combat_sugar_stolen, etc.)
based on the global metric mapping.

Usage:
    julia rename_metric_columns.jl <csv_file_path> [--backup] [--output output_file]
    julia rename_metric_columns.jl <directory_path> --batch [--backup]
    
Examples:
    # Rename columns in a single file
    julia rename_metric_columns.jl data/for_analysis/combat/movement_combat_bigfive_metrics_1.csv
    
    # Rename with backup
    julia rename_metric_columns.jl data/for_analysis/combat/movement_combat_bigfive_metrics_1.csv --backup
    
    # Batch process all CSV files in a directory
    julia rename_metric_columns.jl data/for_analysis/combat/ --batch --backup
    
    # Save to a new file instead of overwriting
    julia rename_metric_columns.jl input.csv --output output_renamed.csv
"""

using CSV
using DataFrames
using Dates
using Sugarscape

# Import the global metric mapping function from our existing script
include("map_metric_columns.jl")

# Function to rename columns in a CSV file
function rename_csv_columns(csv_file_path::String; backup::Bool=false, output_file::Union{String,Nothing}=nothing)
    println("🔄 Processing: $(basename(csv_file_path))")
    
    # Check if file exists
    if !isfile(csv_file_path)
        error("CSV file not found: $csv_file_path")
    end
    
    # Read the CSV file
    df = CSV.read(csv_file_path, DataFrame)
    original_names = names(df)
    
    # Get the column mapping
    mapping, metric_set_name, _ = create_column_mapping(csv_file_path)
    
    # Apply column renaming
    renamed_count = 0
    renamed_columns = String[]
    
    for (old_name, new_name) in mapping
        if old_name in original_names && startswith(old_name, "#")
            println("  📝 Renaming: $old_name → $new_name")
            rename!(df, old_name => new_name)
            push!(renamed_columns, "$old_name → $new_name")
            renamed_count += 1
        end
    end
    
    if renamed_count > 0
        # Determine output file path
        final_output_path = if output_file !== nothing
            output_file
        else
            csv_file_path  # Overwrite original
        end
        
        # Create backup if requested and we're overwriting
        if backup && output_file === nothing
            backup_path = csv_file_path * ".backup"
            if !isfile(backup_path)
                cp(csv_file_path, backup_path)
                println("  💾 Backup created: $(basename(backup_path))")
            else
                println("  ⚠️  Backup already exists: $(basename(backup_path))")
            end
        end
        
        # Write the modified DataFrame
        CSV.write(final_output_path, df)
        
        if output_file !== nothing
            println("  ✅ Renamed CSV saved to: $(basename(final_output_path))")
        else
            println("  ✅ Updated with $renamed_count column renames")
        end
        
        # Show summary
        println("  📊 Metric Set: $metric_set_name")
        println("  📋 Renamed Columns:")
        for rename_info in renamed_columns
            println("    • $rename_info")
        end
        
    else
        println("  ⚠️  No numbered columns found to rename")
    end
    
    return renamed_count, renamed_columns
end

# Function to batch process multiple CSV files in a directory
function batch_rename_csv_files(directory_path::String; backup::Bool=false, recursive::Bool=true)
    println("🔍 Searching for CSV files in: $directory_path")
    
    if !isdir(directory_path)
        error("Directory not found: $directory_path")
    end
    
    # Find CSV files
    csv_files = String[]
    if recursive
        for (root, dirs, files) in walkdir(directory_path)
            for file in files
                if endswith(lowercase(file), ".csv") && contains(file, "metrics")
                    push!(csv_files, joinpath(root, file))
                end
            end
        end
    else
        for file in readdir(directory_path)
            if endswith(lowercase(file), ".csv") && contains(file, "metrics")
                push!(csv_files, joinpath(directory_path, file))
            end
        end
    end
    
    if isempty(csv_files)
        println("❌ No metric CSV files found in $directory_path")
        return
    end
    
    println("📊 Found $(length(csv_files)) metric CSV files")
    
    total_renamed = 0
    total_files_processed = 0
    
    for csv_file in csv_files
        try
            println("\n" * "="^60)
            renamed_count, _ = rename_csv_columns(csv_file; backup=backup)
            total_renamed += renamed_count
            total_files_processed += 1
        catch e
            println("❌ Error processing $(basename(csv_file)): $e")
        end
    end
    
    println("\n" * "="^60)
    println("🎉 Batch processing complete!")
    println("📁 Files processed: $total_files_processed")
    println("📝 Total columns renamed: $total_renamed")
end

# Function to show preview of what would be renamed
function preview_rename(csv_file_path::String)
    println("🔍 Preview of column renaming for: $(basename(csv_file_path))")
    
    if !isfile(csv_file_path)
        error("CSV file not found: $csv_file_path")
    end
    
    # Read just the header
    df = CSV.read(csv_file_path, DataFrame, limit=1)
    original_names = names(df)
    
    # Get the column mapping
    mapping, metric_set_name, _ = create_column_mapping(csv_file_path)
    
    println("📊 Metric Set: $metric_set_name")
    println("📋 Column Renaming Preview:")
    
    rename_count = 0
    for col_name in original_names
        if startswith(col_name, "#") && haskey(mapping, col_name)
            new_name = mapping[col_name]
            println("  • $col_name → $new_name")
            rename_count += 1
        else
            println("  • $col_name (unchanged)")
        end
    end
    
    println("\n📈 Summary: $rename_count columns will be renamed")
    return rename_count
end

# Main execution function
function main()
    if length(ARGS) == 0
        println("Usage:")
        println("  julia rename_metric_columns.jl <csv_file_path> [--backup] [--output output_file]")
        println("  julia rename_metric_columns.jl <directory_path> --batch [--backup]")
        println("  julia rename_metric_columns.jl <csv_file_path> --preview")
        println()
        println("Options:")
        println("  --backup    Create backup of original file(s)")
        println("  --batch     Process all metric CSV files in directory")
        println("  --preview   Show what would be renamed without making changes")
        println("  --output    Specify output file (instead of overwriting)")
        return
    end
    
    input_path = ARGS[1]
    backup = "--backup" in ARGS
    batch_mode = "--batch" in ARGS
    preview_mode = "--preview" in ARGS
    
    output_file = nothing
    if "--output" in ARGS
        output_idx = findfirst(x -> x == "--output", ARGS)
        if output_idx !== nothing && length(ARGS) > output_idx
            output_file = ARGS[output_idx + 1]
        else
            error("--output flag requires a filename argument")
        end
    end
    
    try
        if preview_mode
            if isfile(input_path)
                preview_rename(input_path)
            else
                error("Preview mode requires a single CSV file path")
            end
        elseif batch_mode
            if isdir(input_path)
                batch_rename_csv_files(input_path; backup=backup)
            else
                error("Batch mode requires a directory path")
            end
        else
            if isfile(input_path)
                rename_csv_columns(input_path; backup=backup, output_file=output_file)
            else
                error("File not found: $input_path")
            end
        end
        
    catch e
        println("❌ Error: $e")
        exit(1)
    end
end

# Run main function if script is executed directly
if abspath(PROGRAM_FILE) == @__FILE__
    main()
end
