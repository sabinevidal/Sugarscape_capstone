module SchwartzValuesProcessor

using CSV
using DataFrames
using Statistics
using Distributions

export process_ess_schwartz_values, load_processed_schwartz_values, compute_zscores, fit_mvn_distribution, sample_agents, compute_value_correlation

# Schwartz Human Values item mappings (ESS variable names)
# Each value dimension includes both regular and "a" versions where available
const SCHWARTZ_ITEMS = Dict(
    :self_direction => ["impfree", "ipcrtiv", "impfreea", "ipcrtiva"],
    :stimulation => ["impdiff", "ipadvnt", "impdiffa", "ipadvnta"],
    :hedonism => ["impfun", "ipgdtim", "impfuna", "ipgdtima"],
    :achievement => ["ipsuces", "ipshabt", "ipsucesa", "ipshabta"],
    :power => ["imprich", "iprspot", "impricha", "iprspota"],
    :security => ["impsafe", "ipstrgv", "impsafea", "ipstrgva"],
    :conformity => ["ipfrule", "ipbhprp", "ipfrulea", "ipbhprpa"],
    :tradition => ["imptrad", "ipmodst", "imptrada", "ipmodsta"],
    :benevolence => ["iphlppl", "iplylfr", "iphlppla", "iplylfra"],
    :universalism => ["ipudrst", "ipeqopt", "impenv", "ipudrsta", "ipeqopta", "impenva"]
)

# Value dimension names in order
const VALUE_NAMES = [:self_direction, :stimulation, :hedonism, :achievement, :power,
                     :security, :conformity, :tradition, :benevolence, :universalism]

"""
    clean_schwartz_data!(df::DataFrame, items::Vector{String})

Clean Schwartz values data by:
1. Converting valid responses (1-6) to proper numeric values
2. Setting invalid responses (7-9, 66-99) to missing
3. Handling missing data appropriately
"""
function clean_schwartz_data!(df::DataFrame, items::Vector{String})
    for item in items
        if item in names(df)
            # Convert to numeric if not already
            if eltype(df[!, item]) <: AbstractString
                df[!, item] = tryparse.(Float64, df[!, item])
            end
            
            # Set invalid values to missing
            # Valid range: 1-6, Invalid: 7-9, 66-99
            df[!, item] = map(x -> begin
                if ismissing(x)
                    missing
                elseif x >= 1 && x <= 6
                    x
                elseif x >= 7 && x <= 9
                    missing
                elseif x >= 66 && x <= 99
                    missing
                else
                    x  # Keep other values as-is (shouldn't happen in ESS)
                end
            end, df[!, item])
        end
    end
end

"""
    reverse_schwartz_scale!(df::DataFrame, items::Vector{String})

Reverse the Schwartz values scale so higher values reflect greater endorsement.
Original scale: 1 = very much like me, 6 = not like me at all
Reversed scale: 1 = not like me at all, 6 = very much like me
Transformation: new_value = 7 - old_value
"""
function reverse_schwartz_scale!(df::DataFrame, items::Vector{String})
    for item in items
        if item in names(df)
            df[!, item] = map(x -> ismissing(x) ? missing : 7.0 - x, df[!, item])
        end
    end
end

"""
    compute_value_score(df::DataFrame, items::Vector{String}) -> Vector{Union{Missing, Float64}}

Compute the mean score for a Schwartz value dimension from available (non-missing) items.
Returns missing if no valid items are available for a respondent.
"""
function compute_value_score(df::DataFrame, items::Vector{String})
    # Get available items that exist in the dataframe
    available_items = filter(item -> item in names(df), items)
    
    if isempty(available_items)
        return fill(missing, nrow(df))
    end
    
    # Compute row-wise mean of available non-missing values
    scores = Vector{Union{Missing, Float64}}(undef, nrow(df))
    
    for i in 1:nrow(df)
        values = [df[i, item] for item in available_items if !ismissing(df[i, item])]
        
        if isempty(values)
            scores[i] = missing
        else
            scores[i] = mean(values)
        end
    end
    
    return scores
end

"""
    ipsatize_values!(df::DataFrame, value_cols::Vector{String})

Apply ipsatization (centering) to Schwartz values by subtracting each respondent's
mean value score across all 10 dimensions. This controls for individual differences
in scale use.
"""
function ipsatize_values!(df::DataFrame, value_cols::Vector{String})
    # Create ipsatized columns
    for col in value_cols
        df[!, col * "_ipsatized"] = df[!, col]
    end
    
    ipsatized_cols = [col * "_ipsatized" for col in value_cols]
    
    # For each respondent, subtract their mean across all values
    for i in 1:nrow(df)
        values = [df[i, col] for col in ipsatized_cols if !ismissing(df[i, col])]
        
        if !isempty(values)
            person_mean = mean(values)
            
            # Subtract person mean from each value
            for col in ipsatized_cols
                if !ismissing(df[i, col])
                    df[i, col] = df[i, col] - person_mean
                end
            end
        end
    end
end

"""
    process_ess_schwartz_values(path::String; 
                               respondent_id_col::String = "idno",
                               apply_ipsatization::Bool = true,
                               sample_size::Int = 0) -> DataFrame

Process ESS Schwartz Human Values data through the complete pipeline:
1. Load and clean data (handle missing values, invalid responses)
2. Reverse scale (higher = greater endorsement)
3. Aggregate into 10 value dimensions
4. Optionally apply ipsatization (centering)

Returns DataFrame with respondent ID, 10 value scores, and optionally ipsatized scores.
"""
function process_ess_schwartz_values(path::String; 
                                   respondent_id_col::String = "idno",
                                   apply_ipsatization::Bool = true,
                                   sample_size::Int = 0)
    
    # Load data
    println("Loading ESS data from: $path")
    df = CSV.read(path, DataFrame)
    
    if sample_size > 0
        df = df[1:min(sample_size, nrow(df)), :]
        println("Subsampled to $sample_size rows")
    end
    
    println("Original data shape: $(nrow(df)) rows, $(ncol(df)) columns")
    
    # Get all unique Schwartz items from our mapping
    all_items = unique(vcat(values(SCHWARTZ_ITEMS)...))
    existing_items = filter(item -> item in names(df), all_items)
    
    println("Found $(length(existing_items)) out of $(length(all_items)) Schwartz items in data")
    
    # Step 1: Clean data
    println("Cleaning data...")
    clean_schwartz_data!(df, existing_items)
    
    # Step 2: Reverse scale
    println("Reversing scale...")
    reverse_schwartz_scale!(df, existing_items)
    
    # Step 3: Compute value scores
    println("Computing value scores...")
    result_df = DataFrame()
    
    # Add respondent ID if available
    if respondent_id_col in names(df)
        result_df[!, :respondent_id] = df[!, respondent_id_col]
    else
        result_df[!, :respondent_id] = 1:nrow(df)
        println("Warning: Respondent ID column '$respondent_id_col' not found. Using row numbers.")
    end
    
    # Compute scores for each value dimension
    value_cols = String[]
    for value_name in VALUE_NAMES
        col_name = string(value_name)
        push!(value_cols, col_name)
        
        items = SCHWARTZ_ITEMS[value_name]
        scores = compute_value_score(df, items)
        result_df[!, Symbol(col_name)] = scores
        
        # Report availability
        available_items = filter(item -> item in names(df), items)
        valid_scores = count(!ismissing, scores)
        println("  $value_name: $(length(available_items))/$(length(items)) items available, $valid_scores valid scores")
    end
    
    # Step 4: Apply ipsatization if requested
    if apply_ipsatization
        println("Applying ipsatization...")
        ipsatize_values!(result_df, value_cols)
    end
    
    # Remove rows with all missing values
    value_score_cols = [Symbol(col) for col in value_cols]
    before_count = nrow(result_df)
    
    # Keep rows that have at least one non-missing value score
    result_df = result_df[map(row -> any(!ismissing(row[col]) for col in value_score_cols), eachrow(result_df)), :]
    
    after_count = nrow(result_df)
    println("Removed $(before_count - after_count) rows with all missing values")
    println("Final dataset: $after_count respondents")
    
    return result_df
end

"""
    load_processed_schwartz_values(path::String; sample_size::Int = 0) -> DataFrame

Load already processed Schwartz values data from CSV.
Validates that all required value columns are present.
"""
function load_processed_schwartz_values(path::String; sample_size::Int = 0)
    df = CSV.read(path, DataFrame)
    
    # Check for required columns
    required_cols = [string(name) for name in VALUE_NAMES]
    missing_cols = filter(col -> !(col in names(df)), required_cols)
    
    if !isempty(missing_cols)
        throw(ArgumentError("Processed Schwartz values file is missing columns: $(missing_cols)"))
    end
    
    # Keep only complete cases for value columns
    value_cols = [Symbol(col) for col in required_cols]
    df = dropmissing(df, value_cols)
    
    if sample_size > 0
        df = df[1:min(sample_size, nrow(df)), :]
    end
    
    return df
end

"""
    compute_zscores(values_df::DataFrame) -> DataFrame

Compute z-scores for Schwartz values to standardize across dimensions.
"""
function compute_zscores(values_df::DataFrame)
    value_cols = [string(name) for name in VALUE_NAMES]
    existing_cols = filter(col -> col in names(values_df), value_cols)
    
    if isempty(existing_cols)
        throw(ArgumentError("No Schwartz value columns found in DataFrame"))
    end
    
    result_df = copy(values_df)
    
    for col in existing_cols
        col_data = values_df[!, col]
        valid_data = filter(!ismissing, col_data)
        
        if !isempty(valid_data)
            col_mean = mean(valid_data)
            col_std = std(valid_data)
            
            if col_std > 0
                result_df[!, col] = map(x -> ismissing(x) ? missing : (x - col_mean) / col_std, col_data)
            else
                result_df[!, col] = map(x -> ismissing(x) ? missing : 0.0, col_data)
            end
        end
    end
    
    return result_df
end

"""
    fit_mvn_distribution(values_df::DataFrame) -> MvNormal

Fit a multivariate normal distribution to Schwartz values data.
Returns MvNormal distribution for sampling synthetic agents.
"""
function fit_mvn_distribution(values_df::DataFrame)::MvNormal
    value_cols = [string(name) for name in VALUE_NAMES]
    existing_cols = filter(col -> col in names(values_df), value_cols)
    
    if isempty(existing_cols)
        throw(ArgumentError("No Schwartz value columns found in DataFrame"))
    end
    
    # Use only complete cases
    complete_df = dropmissing(values_df, Symbol.(existing_cols))
    
    if nrow(complete_df) == 0
        throw(ArgumentError("No complete cases found for fitting MVN distribution"))
    end
    
    X = Matrix(complete_df[:, existing_cols])
    means = mean(X, dims=1)[:]
    cov_matrix = cov(X, dims=1)
    
    return MvNormal(means, cov_matrix)
end

"""
    sample_agents(mvn::MvNormal, n::Int) -> DataFrame

Sample n synthetic agents from the fitted MvNormal distribution.
Returns DataFrame with Schwartz value columns.
"""
function sample_agents(mvn::MvNormal, n::Int)::DataFrame
    samples = rand(mvn, n)'
    
    # Round to 2 decimal places and ensure reasonable bounds
    samples_rounded = round.(samples, digits=2)
    
    # Create DataFrame with proper column names
    value_cols = [Symbol(string(name)) for name in VALUE_NAMES[1:size(samples, 2)]]
    
    return DataFrame(samples_rounded, value_cols)
end

"""
    compute_value_correlation(values_df::DataFrame) -> DataFrame

Compute correlation matrix between Schwartz values.
Returns symmetric DataFrame with values as rows and columns.
"""
function compute_value_correlation(values_df::DataFrame)::DataFrame
    value_cols = [string(name) for name in VALUE_NAMES]
    existing_cols = filter(col -> col in names(values_df), value_cols)
    
    if isempty(existing_cols)
        throw(ArgumentError("No Schwartz value columns found in DataFrame"))
    end
    
    # Use only complete cases
    complete_df = dropmissing(values_df, Symbol.(existing_cols))
    
    if nrow(complete_df) == 0
        throw(ArgumentError("No complete cases found for correlation computation"))
    end
    
    X = Matrix(complete_df[:, existing_cols])
    corr_matrix = cor(X)
    
    return DataFrame(corr_matrix, Symbol.(existing_cols))
end

end # module