#!/usr/bin/env julia

"""
Script to generate processed Big Five traits file from raw data.
This script processes the raw Big Five questionnaire data and creates
a CSV file with the five trait columns required by the simulation.
"""

using Pkg
Pkg.activate(".")

using CSV
using DataFrames

# Import the BigFiveProcessor module
include("../src/psychological_dimensions/big_five/big_five_processor.jl")
using .BigFiveProcessor

function main()
    # Define paths
    raw_data_path = "data/raw/big5-data-final.csv"
    processed_data_path = "data/processed/big5-traits_raw.csv"
    
    println("Processing Big Five raw data...")
    println("Input file: $raw_data_path")
    println("Output file: $processed_data_path")
    
    # Check if raw data exists
    if !isfile(raw_data_path)
        error("Raw Big Five data file not found: $raw_data_path")
    end
    
    try
        # Process the raw data to get trait scores
        println("Loading and processing raw data...")
        processed_df = process_raw_bigfive(raw_data_path)
        
        println("Processed data shape: $(size(processed_df))")
        println("Columns: $(names(processed_df))")
        
        # Ensure output directory exists
        mkpath(dirname(processed_data_path))
        
        # Save the processed data
        println("Saving processed data to $processed_data_path...")
        CSV.write(processed_data_path, processed_df)
        
        println("✅ Successfully generated processed Big Five traits file!")
        println("File contains $(nrow(processed_df)) rows with columns: $(names(processed_df))")
        
    catch e
        println("❌ Error processing Big Five data:")
        println(e)
        rethrow(e)
    end
end

if abspath(PROGRAM_FILE) == @__FILE__
    main()
end
