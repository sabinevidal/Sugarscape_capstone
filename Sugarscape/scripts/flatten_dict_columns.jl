#!/usr/bin/env julia

"""
flatten_dict_columns.jl
=======================
Flatten *any* column that contains a `Dict{String, Number}` represented as a string in a metrics CSV file.

Usage
-----
    julia flatten_dict_columns.jl <input_file> <output_file>

Example
-------
    julia flatten_dict_columns.jl \
        data/for_analysis/culture/movement_culture_llm_metrics_2.csv \
        data/for_analysis/culture/movement_culture_llm_metrics_2_flat.csv

The script will:
1. Read the CSV into a DataFrame.
2. Detect columns whose non-missing entries look like `Dict{…}` strings.
3. Convert each of those dictionary strings into JSON, parse it, and create one new numeric
   column per key with the prefix `<original>_`.
4. Remove the original dictionary column.
5. Write the flattened DataFrame to `<output_file>`.

The code is intentionally generic so it can be re-used for combat, culture, credit or any
other scenario files without having to maintain a specialised pre-processor for every
scenario type.
"""

using CSV
using DataFrames
using JSON3
using Printf
using FilePathsBase: basename, dirname

"""Return `true` if *value* looks like the textual representation of a Dict."""
function _looks_like_dict(value)
    return isa(value, String) && occursin("Dict{", value)
end

"""
Flatten all dictionary-encoded columns *in-place*.
Each key becomes a new column named `<original>_<key>`.
"""
function flatten_dict_columns!(df::DataFrame; prefix_separator::AbstractString = "_")
    dict_cols = filter(col -> any(_looks_like_dict, df[!, col]), names(df))

    if isempty(dict_cols)
        @info "No dictionary columns found – nothing to flatten"
        return df
    end

    @info "Found $(length(dict_cols)) dictionary column(s): $(join(dict_cols, ", "))"

    for col in dict_cols
        col_sym = Symbol(col)
        col_vector = df[!, col_sym]

        # Accumulate all keys to guarantee consistent column order
        keys_union = Set{String}()
        parsed_vec = Vector{Union{Missing, Dict{String, Float64}}}(undef, nrow(df))

        for (i, cell) in enumerate(col_vector)
            if _looks_like_dict(cell)
                # Convert Julia Dict string to JSON: Dict("k"=>1.2,"x"=>3) → {"k":1.2,"x":3}
                # Strip type annotation like `Dict{String, Real}(` or simple `Dict(`
                json_like = replace(cell,
                    r"^Dict\{[^}]*}\(" => "{",
                    "Dict(" => "{",
                    ")" => "}",
                    "=>" => ":") |> strip
                parsed = try
                    JSON3.read(json_like, Dict{String, Float64})
                catch
                    # Fallback simple regex parse if JSON3 fails
                    fallback = Dict{String, Float64}()
                    for m in eachmatch(r"\"([^\"]+)\"\s*:\s*([0-9eE+\-.]+)", json_like)
                        fallback[m.captures[1]] = parse(Float64, m.captures[2])
                    end
                    fallback
                end
                parsed_vec[i] = parsed
                union!(keys_union, keys(parsed))
            else
                parsed_vec[i] = missing
            end
        end

        # Produce new columns
        for k in sort(collect(keys_union))
            new_col_sym = Symbol(col * prefix_separator * k)
            df[!, new_col_sym] = [
                ismissing(parsed_vec[i]) ? missing : get(parsed_vec[i], k, missing) for i in 1:length(parsed_vec)
            ]
        end

        # Remove the original dict column
        select!(df, Not(col_sym))
        @info "Flattened and removed column $(col)"
    end

    return df
end

function main()
    if length(ARGS) < 2
        println("Usage: julia flatten_dict_columns.jl <input_file> <output_file>")
        return
    end

    input_path  = ARGS[1]
    output_path = ARGS[2]

    if !isfile(input_path)
        @error "Input file does not exist: $(input_path)"
        return
    end

    # Ensure output directory exists
    out_dir = dirname(output_path)
    if !isdir(out_dir)
        mkpath(out_dir)
    end

    @info "Reading $(basename(input_path))"
    df = CSV.read(input_path, DataFrame)

    flatten_dict_columns!(df)

    CSV.write(output_path, df)
    @info "Wrote flattened CSV → $(basename(output_path))"
end

if abspath(PROGRAM_FILE) == @__FILE__
    main()
end
