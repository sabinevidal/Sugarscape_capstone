#!/usr/bin/env julia

using JSON3
using Printf

"""
    julia_to_json(data)

Convert Julia data structures to JSON-compatible format.
Handles Julia-specific types like symbols, tuples, and nested structures.
"""
function julia_to_json(data)
  if isa(data, Symbol)
    return string(data)
  elseif isa(data, Tuple)
    return collect(data)
  elseif isa(data, Vector)
    return [julia_to_json(item) for item in data]
  elseif isa(data, Dict)
    return Dict{String,Any}(string(k) => julia_to_json(v) for (k, v) in data)
  elseif isa(data, AbstractArray)
    return [julia_to_json(item) for item in data]
  else
    return data
  end
end

"""
    convert_dict_to_json(input_str, output_file=nothing)

Convert a Julia dictionary string to formatted JSON.
If output_file is provided, saves to file. Otherwise prints to stdout.
"""
function convert_dict_to_json(input_str, output_file=nothing)
  try
    # Parse the Julia expression
    parsed = eval(Meta.parse(input_str))

    # Convert to JSON-compatible format
    json_data = julia_to_json(parsed)

    # Convert to JSON string with pretty formatting
    json_str = JSON3.pretty(json_data)

    if output_file !== nothing
      # Write to file
      open(output_file, "w") do f
        write(f, json_str)
      end
      println("JSON saved to: $output_file")
    else
      # Print to stdout
      println(json_str)
    end

  catch e
    println("Error converting dictionary: $e")
    println("Make sure the input is a valid Julia dictionary expression")
  end
end

"""
    convert_from_file(input_file, output_file=nothing)

Convert a Julia dictionary from a file to JSON.
"""
function convert_from_file(input_file, output_file=nothing)
  try
    # Read the file content
    content = read(input_file, String)
    convert_dict_to_json(content, output_file)
  catch e
    println("Error reading file: $e")
  end
end

# Main execution
if abspath(PROGRAM_FILE) == @__FILE__
  if length(ARGS) == 0
    println("Usage:")
    println("  julia dict_to_json.jl \"Dict(...)\" [output.json]")
    println("  julia dict_to_json.jl --file input.jl [output.json]")
    println()
    println("Examples:")
    println("  julia dict_to_json.jl 'Dict(\"key\" => :value, \"pos\" => (1,2))'")
    println("  julia dict_to_json.jl --file data.jl output.json")
    exit(0)
  end

  if ARGS[1] == "--file"
    if length(ARGS) < 2
      println("Error: Please provide input file path")
      exit(1)
    end

    input_file = ARGS[2]
    output_file = length(ARGS) > 2 ? ARGS[3] : nothing
    convert_from_file(input_file, output_file)
  else
    input_str = ARGS[1]
    output_file = length(ARGS) > 1 ? ARGS[2] : nothing
    convert_dict_to_json(input_str, output_file)
  end
end

# Export functions for interactive use
export julia_to_json, convert_dict_to_json, convert_from_file
