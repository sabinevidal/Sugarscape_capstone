#!/usr/bin/env julia

"""
Process a single metrics CSV file through the preprocessing pipeline.

Usage:
    julia process_single_file.jl <input_file> <output_file>

Example:
    julia process_single_file.jl data/results/simulations/movement_combat_llm/movement_combat_llm_metrics_1.csv data/for_analysis/combat/movement_combat_llm_metrics_1_processed.csv
"""

include("preprocess_combat_metrics.jl")

function main()
    if length(ARGS) < 2
        println("Usage: julia process_single_file.jl <input_file> <output_file>")
        println("Example: julia process_single_file.jl data/results/simulations/movement_combat_llm/movement_combat_llm_metrics_1.csv data/for_analysis/combat/processed.csv")
        return
    end
    
    input_path = ARGS[1]
    output_path = ARGS[2]
    
    if !isfile(input_path)
        println("❌ Input file not found: $input_path")
        return
    end
    
    # Create output directory if it doesn't exist
    output_dir = dirname(output_path)
    if !isdir(output_dir)
        mkpath(output_dir)
        println("📁 Created output directory: $output_dir")
    end
    
    try
        process_metrics_file(input_path, output_path)
        println("✅ Successfully processed file!")
        println("📄 Input:  $input_path")
        println("📄 Output: $output_path")
    catch e
        println("❌ Error processing file: $e")
    end
end

if abspath(PROGRAM_FILE) == @__FILE__
    main()
end
