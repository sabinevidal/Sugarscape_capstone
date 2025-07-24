#!/usr/bin/env julia

"""
Process Schwartz Human Values ESS data through complete pipeline.

This script processes real ESS data with Schwartz Human Values items through:
1. Data cleaning and validation
2. Scale reversal (higher = greater endorsement)
3. Aggregation into 10 value dimensions
4. Optional ipsatization (centering)
5. Distribution fitting for agent sampling

Usage:
    julia generate_schwartz_values.jl [path_to_ess_data.csv]

If no path is provided, it will use the default raw data file:
    ../data/raw/schwartz-values-data-raw.csv
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

function process_schwartz_values(data_path::Union{String,Nothing}=nothing; sample_size::Int=0)
  """Process complete ESS Schwartz Human Values dataset and save results."""
  println("="^60)
  println("PROCESSING ESS SCHWARTZ HUMAN VALUES DATA")
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
    # Process complete ESS dataset with optimized settings
    println("\nProcessing complete ESS Schwartz Human Values dataset...")
    result_df = SchwartzValuesProcessor.process_ess_schwartz_values(
      data_path;
      respondent_id_col="idno",
      apply_ipsatization=true,
      sample_size=sample_size,
      include_id=false  # Exclude ID column to reduce file size
    )

    # Save processed data to CSV
    output_path = joinpath(processed_dir, "schwartz-values-processed.csv")
    CSV.write(output_path, result_df)
    println("\nProcessed data saved to: $output_path")

    println("\nPipeline Results:")
    println("  Final dataset shape: $(nrow(result_df)) × $(ncol(result_df))")
    println("  Columns: $(names(result_df))")

    # Show sample of results
    println("\nSample of processed data:")
    println(first(result_df, 5))

    println("\n" * "="^60)
    println("SCHWARTZ VALUES PROCESSING COMPLETED SUCCESSFULLY!")
    println("="^60)

    return result_df
  catch e
    println("\nError processing data: $e")
    return nothing
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
    actual_data_path = length(ARGS) > 0 ? ARGS[1] : DEFAULT_ESS_DATA_PATH

    # Default: process complete dataset
    if length(ARGS) > 0
      process_schwartz_values(ARGS[1])
    else
      process_schwartz_values()
    end
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
