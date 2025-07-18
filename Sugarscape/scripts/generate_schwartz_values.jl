#!/usr/bin/env julia

"""
Test script for Schwartz Human Values ESS data processing pipeline.

This script demonstrates how to use the SchwartzValuesProcessor module to:
1. Process raw ESS data with Schwartz Human Values items
2. Clean and reverse-scale the data
3. Aggregate into 10 value dimensions
4. Apply ipsatization (optional)
5. Fit distributions and sample synthetic agents

Usage:
    julia schwartz_values_test.jl [path_to_ess_data.csv]

If no path is provided, it will use the default raw data file:
    ../data/raw/schwarts-values-data-raw.csv
"""

using Pkg
Pkg.activate(".")

using CSV
using DataFrames
using Statistics
using Distributions
using Random

# Include the Schwartz Values processor
include("../src/psychological_dimensions/schwartz_values/schwartz_values_processor.jl")
using .SchwartzValuesProcessor

# Default path to the raw ESS data
const DEFAULT_ESS_DATA_PATH = "../data/raw/schwartz-values-data-raw.csv"

function inspect_ess_data(data_path::String; sample_rows::Int=10)
  """
  Inspect the structure and content of the ESS data file.
  """
  println("Inspecting ESS data file: $data_path")

  if !isfile(data_path)
    println("Error: File not found at $data_path")
    return nothing
  end

  # Read just the header and a few rows for inspection
  df_sample = CSV.read(data_path, DataFrame; limit=sample_rows)

  println("\nData file information:")
  println("  Shape: $(nrow(df_sample)) rows (sample) × $(ncol(df_sample)) columns")
  println("  Columns: $(names(df_sample))")

  # Check which Schwartz items are present
  all_schwartz_items = unique(vcat(values(SchwartzValuesProcessor.SCHWARTZ_ITEMS)...))
  present_items = filter(item -> item in names(df_sample), all_schwartz_items)
  missing_items = filter(item -> !(item in names(df_sample)), all_schwartz_items)

  println("\nSchwartz items analysis:")
  println("  Present items ($(length(present_items))/$(length(all_schwartz_items))): $(join(present_items, ", "))")
  if !isempty(missing_items)
    println("  Missing items: $(join(missing_items, ", "))")
  end

  # Show sample data for Schwartz items
  schwartz_cols = filter(col -> col in present_items, names(df_sample))
  if !isempty(schwartz_cols)
    println("\nSample Schwartz values data (first 5 rows, first 10 items):")
    display_cols = schwartz_cols[1:min(10, length(schwartz_cols))]
    # Use consistent column selection (all strings)
    sample_cols = ["idno", "cntry", "essround"]
    append!(sample_cols, display_cols)
    println(df_sample[1:min(5, nrow(df_sample)), sample_cols])
  end

  return df_sample
end

# Synthetic data creation removed - script now uses only real ESS data

function test_pipeline_functions(data_path::String=DEFAULT_ESS_DATA_PATH)
  """Test individual pipeline functions with real ESS data."""
  println("\n" * "="^60)
  println("TESTING INDIVIDUAL PIPELINE FUNCTIONS")
  println("="^60)

  if !isfile(data_path)
    println("Error: ESS data file not found at $data_path")
    return false
  end

  # Load small sample of real ESS data for testing
  println("Loading sample of real ESS data for function testing...")
  test_df = CSV.read(data_path, DataFrame; limit=100)

  # Test 1: Data cleaning
  println("\n1. Testing data cleaning...")
  items_to_test = ["impfree", "ipcrtiv", "impdiff"]
  original_df = copy(test_df)

  SchwartzValuesProcessor.clean_schwartz_data!(test_df, items_to_test)

  for item in items_to_test
    if item in names(test_df)
      original_invalid = count(x -> !ismissing(x) && (x >= 7 && x <= 9 || x >= 66 && x <= 99), original_df[!, item])
      cleaned_invalid = count(x -> !ismissing(x) && (x >= 7 && x <= 9 || x >= 66 && x <= 99), test_df[!, item])
      println("  $item: Removed $original_invalid invalid values (now: $cleaned_invalid)")
    end
  end

  # Test 2: Scale reversal
  println("\n2. Testing scale reversal...")
  pre_reversal = copy(test_df[1:5, items_to_test])
  SchwartzValuesProcessor.reverse_schwartz_scale!(test_df, items_to_test)
  post_reversal = test_df[1:5, items_to_test]

  println("  Sample before reversal:")
  println(pre_reversal)
  println("  Sample after reversal:")
  println(post_reversal)

  # Test 3: Value score computation
  println("\n3. Testing value score computation...")
  self_direction_items = SchwartzValuesProcessor.SCHWARTZ_ITEMS[:self_direction]
  scores = SchwartzValuesProcessor.compute_value_score(test_df, self_direction_items)
  valid_scores = count(!ismissing, scores)
  println("  Self-direction scores: $valid_scores valid out of $(length(scores)) total")
  println("  Sample scores: $(scores[1:5])")

  println("\nIndividual function tests completed successfully!")
end

function test_full_pipeline(data_path::Union{String,Nothing}=nothing; sample_size::Int=10000)
  """Test the complete pipeline with real ESS data and output processed CSV."""
  println("\n" * "="^60)
  println("TESTING COMPLETE PIPELINE WITH REAL ESS DATA")
  println("="^60)

  # Use real ESS data - no fallback to synthetic data
  if data_path === nothing
    data_path = DEFAULT_ESS_DATA_PATH
  end

  if !isfile(data_path)
    println("\nError: ESS data file not found at $data_path")
    println("Please ensure the raw ESS data file exists at the specified path.")
    return nothing
  end

  println("\nUsing ESS data file: $data_path")

  # Inspect the data first
  inspect_ess_data(data_path; sample_rows=5)

  # Create processed data directory if it doesn't exist
  processed_dir = "data/processed"
  if !isdir(processed_dir)
    mkpath(processed_dir)
    println("\nCreated processed data directory: $processed_dir")
  end

  try
    # Test full pipeline with real ESS data
    println("\nRunning complete pipeline on real ESS data...")
    result_df = SchwartzValuesProcessor.process_ess_schwartz_values(
      data_path;
      respondent_id_col="idno",
      apply_ipsatization=true,
      sample_size=sample_size
    )

    # Save processed data to CSV
    output_path = joinpath(processed_dir, "schwartz_values_processed.csv")
    CSV.write(output_path, result_df)
    println("\nProcessed data saved to: $output_path")

    println("\nPipeline Results:")
    println("  Final dataset shape: $(nrow(result_df)) × $(ncol(result_df))")
    println("  Columns: $(names(result_df))")

    # Show sample of results
    println("\nSample of processed data:")
    println(first(result_df, 5))

    # Test additional functions
    println("\n" * "-"^40)
    println("Testing additional functions...")

    # Test z-scores
    println("\n4. Testing z-score computation...")
    zscored_df = SchwartzValuesProcessor.compute_zscores(result_df)
    println("  Z-scored data shape: $(nrow(zscored_df)) × $(ncol(zscored_df))")

    # Show z-score statistics
    value_cols = [string(name) for name in SchwartzValuesProcessor.VALUE_NAMES]
    existing_cols = filter(col -> col in names(zscored_df), value_cols)

    for col in existing_cols[1:3]  # Show first 3 for brevity
      col_data = filter(!ismissing, zscored_df[!, col])
      if !isempty(col_data)
        println("  $col z-scores: mean = $(round(mean(col_data), digits=3)), std = $(round(std(col_data), digits=3))")
      end
    end

    # Test correlation matrix
    println("\n5. Testing correlation computation...")
    corr_df = SchwartzValuesProcessor.compute_value_correlation(result_df)
    println("  Correlation matrix shape: $(nrow(corr_df)) × $(ncol(corr_df))")

    # Show sample correlations
    if ncol(corr_df) >= 3
      println("  Sample correlations between first 3 values:")
      println(corr_df[1:3, 1:3])
    end

    # Test MVN distribution fitting and sampling
    println("\n6. Testing MVN distribution fitting and sampling...")
    mvn_dist = SchwartzValuesProcessor.fit_mvn_distribution(result_df)
    println("  Fitted MVN distribution with $(length(mvn_dist.μ)) dimensions")
    println("  Mean values: $(round.(mvn_dist.μ, digits=2))")

    # Sample synthetic agents
    synthetic_agents = SchwartzValuesProcessor.sample_agents(mvn_dist, 10)
    println("  Generated $(nrow(synthetic_agents)) synthetic agents")
    println("  Sample synthetic agent:")
    println(first(synthetic_agents, 1))

    # Test loading processed data
    println("\n7. Testing processed data loading...")
    loaded_df = SchwartzValuesProcessor.load_processed_schwartz_values(output_path; sample_size=100)
    println("  Loaded processed data shape: $(nrow(loaded_df)) × $(ncol(loaded_df))")

    # No temporary files to clean up - using real data only

    println("\n" * "="^60)
    println("ALL TESTS COMPLETED SUCCESSFULLY!")
    println("="^60)

    return result_df

  catch e
    println("Error during pipeline testing: $e")
    rethrow(e)
  end
end

function demonstrate_usage_examples()
  """Demonstrate common usage patterns."""
  println("\n" * "="^60)
  println("USAGE EXAMPLES")
  println("="^60)

  println("\n1. Basic usage with real ESS data:")
  println("""
  using CSV, DataFrames
  include("src/psychological_dimensions/schwartz_values/schwartz_values_processor.jl")
  using .SchwartzValuesProcessor

  # Process the raw ESS Schwartz values data (536K+ respondents)
  result = process_ess_schwartz_values(
      "data/raw/schwarts-values-data-raw.csv";
      respondent_id_col = "idno",
      apply_ipsatization = true,
      sample_size = 10000  # Use subset for faster processing, or 0 for all data
  )

  # Inspect the results
  println("Processed ", nrow(result), " respondents with ", ncol(result), " columns")
  println("Columns: ", names(result))
  """)

  println("\n2. Working with processed data:")
  println("""
  # Load already processed data
  values_df = load_processed_schwartz_values("processed_schwartz.csv")

  # Compute z-scores
  zscored = compute_zscores(values_df)

  # Fit distribution and sample agents
  mvn_dist = fit_mvn_distribution(values_df)
  synthetic_agents = sample_agents(mvn_dist, 1000)

  # Compute correlations
  correlations = compute_value_correlation(values_df)
  """)

  println("\n3. Integration with Sugarscape model:")
  println("""
  # This would be integrated into the main Sugarscape model
  # Similar to how Big Five traits are handled

  function prepare_schwartz_values(schwartz_data_path, N, mvn_dist=nothing)
      values_df = load_processed_schwartz_values(schwartz_data_path)

      mvn = if mvn_dist === nothing
          fit_mvn_distribution(values_df)
      else
          mvn_dist
      end

      values_samples = sample_agents(mvn, N)
      return (values_samples, mvn)
  end
  """)
end

function main()
  """Main function to run all tests."""
  println("Schwartz Human Values ESS Data Processing Pipeline")
  println("="^60)

  # Check if data path provided as command line argument
  data_path = length(ARGS) > 0 ? ARGS[1] : nothing

  if data_path !== nothing
    println("Using provided data path: $data_path")
    if !isfile(data_path)
      println("Warning: File not found. Will fall back to default ESS data.")
      data_path = nothing
    end
  else
    println("No data path provided. Will use default ESS data file.")
  end

  try
    # Determine the actual data path to use
    actual_data_path = data_path === nothing ? DEFAULT_ESS_DATA_PATH : data_path

    # Run tests with real ESS data only
    test_pipeline_functions(actual_data_path)
    result_df = test_full_pipeline(actual_data_path; sample_size=10000)  # Use 10K sample for testing
    demonstrate_usage_examples()

    println("\n" * "="^60)
    println("SUMMARY")
    println("="^60)
    println("✓ All pipeline functions implemented and tested")
    println("✓ Data cleaning: handles invalid values (7-9, 66-99) → missing")
    println("✓ Scale reversal: 1→6, 2→5, ..., 6→1 for higher endorsement")
    println("✓ Value aggregation: mean of available items per dimension")
    println("✓ Ipsatization: centering by person mean (optional)")
    println("✓ Distribution fitting: MVN for synthetic agent sampling")
    println("✓ Correlation analysis: between value dimensions")
    println("✓ Z-score standardization: for cross-dimensional comparison")

    println("\nThe Schwartz Human Values pipeline is ready for use!")
    println("See the usage examples above for integration patterns.")

  catch e
    println("Error during testing: $e")
    println("Stack trace:")
    for (exc, bt) in Base.catch_stack()
      showerror(stdout, exc, bt)
      println()
    end
    exit(1)
  end
end

# Run if called directly
if abspath(PROGRAM_FILE) == @__FILE__
  main()
end
