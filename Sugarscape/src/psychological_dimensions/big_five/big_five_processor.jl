module BigFiveProcessor

using CSV
using DataFrames
using Statistics
using Distributions

export process_raw_bigfive, load_processed_bigfive, compute_zscores, fit_mvn_distribution, sample_agents, compute_trait_correlation

# Big Five question blocks
EXT_items = ["EXT1", "EXT2", "EXT3", "EXT4", "EXT5", "EXT6", "EXT7", "EXT8", "EXT9", "EXT10"]
EST_items = ["EST1", "EST2", "EST3", "EST4", "EST5", "EST6", "EST7", "EST8", "EST9", "EST10"]
AGR_items = ["AGR1", "AGR2", "AGR3", "AGR4", "AGR5", "AGR6", "AGR7", "AGR8", "AGR9", "AGR10"]
CSN_items = ["CSN1", "CSN2", "CSN3", "CSN4", "CSN5", "CSN6", "CSN7", "CSN8", "CSN9", "CSN10"]
OPN_items = ["OPN1", "OPN2", "OPN3", "OPN4", "OPN5", "OPN6", "OPN7", "OPN8", "OPN9", "OPN10"]

# Reverse-scored items
EXT_rev = ["EXT2", "EXT4", "EXT6", "EXT8", "EXT10"]
EST_rev = ["EST2", "EST4"]
AGR_rev = ["AGR1", "AGR3", "AGR5", "AGR7"]
CSN_rev = ["CSN2", "CSN4", "CSN6", "CSN8"]
OPN_rev = ["OPN2", "OPN4", "OPN6"]

function reverse_score!(df::DataFrame, items::Vector{String})
  for item in items
    df[!, item] .= 6 .- df[!, item]
  end
end

function score_trait(df::DataFrame, items::Vector{String})
  # Compute row-wise mean for the selected columns
  mat = Matrix(df[:, items])  # convert sub-DataFrame to numeric matrix
  return mean(mat, dims=2)[:]
end

"""
    process_raw_bigfive(path::String; sample_size::Int = 0)

Loads the Big Five dataset from a CSV file and computes trait scores.
Optionally subsample using `sample_size`.
Returns a DataFrame with the five scored traits.
"""
###########################################################################
# 1. process_raw_bigfive: takes the **item-level** raw TSV, produces trait
#    averages, and returns a DataFrame with the 5 Big-Five columns.
###########################################################################
function process_raw_bigfive(path::String; sample_size::Int=0)
  # Load the file with automatic delimiter detection
  df = CSV.read(path, DataFrame)
  df = dropmissing(df)


  # ---------------------------------------------------------------------
  # Otherwise assume raw questionnaire items in tab-separated format
  # ---------------------------------------------------------------------
  # Combine item lists and define type map for numeric parsing
  all_items = vcat(EXT_items, EST_items, AGR_items, CSN_items, OPN_items)
  types_map = Dict(Symbol(item) => Union{Missing,Float64} for item in all_items)

  # Re-read with explicit types and tab delimiter
  df = CSV.read(path, DataFrame; delim='\t', types=types_map)
  df = dropmissing(df)
  if sample_size > 0
    df = df[1:sample_size, :]
  end

  # Reverse-key responses
  reverse_score!(df, EXT_rev)
  reverse_score!(df, EST_rev)
  reverse_score!(df, AGR_rev)
  reverse_score!(df, CSN_rev)
  reverse_score!(df, OPN_rev)

  # Score traits from items
  scored = DataFrame(
    Extraversion=score_trait(df, EXT_items),
    Neuroticism=score_trait(df, EST_items),
    Agreeableness=score_trait(df, AGR_items),
    Conscientiousness=score_trait(df, CSN_items),
    Openness=score_trait(df, OPN_items)
  )

  return scored
  all_items = vcat(EXT_items, EST_items, AGR_items, CSN_items, OPN_items)
  types_map = Dict(Symbol(item) => Union{Missing,Float64} for item in all_items)
  df = CSV.read(path, DataFrame; delim='\t', types=types_map)
  df = dropmissing(df)
  if sample_size > 0
    df = df[1:sample_size, :]
  end



  # Reverse-key responses
  reverse_score!(df, EXT_rev)
  reverse_score!(df, EST_rev)
  reverse_score!(df, AGR_rev)
  reverse_score!(df, CSN_rev)
  reverse_score!(df, OPN_rev)

  # Score traits
  scored = DataFrame(
    Extraversion=score_trait(df, EXT_items),
    Neuroticism=score_trait(df, EST_items),
    Agreeableness=score_trait(df, AGR_items),
    Conscientiousness=score_trait(df, CSN_items),
    Openness=score_trait(df, OPN_items)
  )

  return scored
end


###########################################################################
# 2. load_processed_bigfive: loads a CSV that already contains the five
#    trait columns. It validates column presence and subsamples if needed.
###########################################################################
function load_processed_bigfive(path::String; sample_size::Int=0)
  df = CSV.read(path, DataFrame; delim=',')
  trait_names = ["Extraversion", "Neuroticism", "Agreeableness", "Conscientiousness", "Openness"]
  missing_cols = filter(c -> !(c in names(df)), trait_names)
  if !isempty(missing_cols)
    throw(ArgumentError("Processed Big Five file is missing columns: $(missing_cols)"))
  end
  df = dropmissing(df[:, trait_names])
  if sample_size > 0
    df = df[1:min(sample_size, nrow(df)), :]
  end
  return df
end

"""
    compute_zscores(traits_df::DataFrame)

Returns a DataFrame of z-scored Big Five traits.
"""
function compute_zscores(traits_df::DataFrame)
  trait_names = names(traits_df)
  means = map(col -> mean(traits_df[!, col]), trait_names)
  stds = map(col -> std(traits_df[!, col]), trait_names)

  zscored = DataFrame()
  for (i, col) in enumerate(trait_names)
    zscored[!, col] = (traits_df[!, col] .- means[i]) ./ stds[i]
  end
  return zscored
end

"""
    fit_mvn_distribution(traits_df::DataFrame) -> MvNormal

Fits a multivariate normal distribution to the scored trait data.
Returns a `MvNormal` distribution object for runtime sampling.
"""
function fit_mvn_distribution(traits_df::DataFrame)::MvNormal
  trait_names = names(traits_df)
  X = Matrix(traits_df[:, trait_names])
  means = mean(X, dims=1)[:]
  cov_matrix = cov(X, dims=1)
  return MvNormal(means, cov_matrix)
end


"""
    sample_agents(mvn::MvNormal, n::Int) -> DataFrame

Samples `n` synthetic agents from the given MvNormal distribution.
Returns a DataFrame with named Big Five trait columns.
"""
function sample_agents(mvn::MvNormal, n::Int)::DataFrame
  samples = rand(mvn, n)'
  # Round all samples to 2 decimal places
  samples_rounded = round.(samples, digits=2)
  samples_clipped = clamp.(samples_rounded, 1.0, 5.0)
  trait_names = [:Extraversion, :Neuroticism, :Agreeableness, :Conscientiousness, :Openness]
  return DataFrame(samples_clipped, trait_names)
end


"""
    compute_trait_correlation(traits_df::DataFrame) -> DataFrame

Computes the Pearson correlation matrix between all Big Five traits.
Returns a symmetric DataFrame with traits as both rows and columns.
"""
function compute_trait_correlation(traits_df::DataFrame)::DataFrame
  mat = Matrix(traits_df[:, names(traits_df)])
  corr_mat = cor(mat)
  return DataFrame(corr_mat, Symbol.(names(traits_df)))
end

end # module
