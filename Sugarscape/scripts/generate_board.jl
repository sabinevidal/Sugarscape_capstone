#!/usr/bin/env julia

# -----------------------------------------------------------------------------
# generate_board.jl
# -----------------------------------------------------------------------------
# A small utility for printing the sugar capacity landscape of a Sugarscape
# simulation.  This helps with planning grid size and sugar peak placement.
#
# Usage (with defaults):
#   julia scripts/generate_board.jl
#
# Optional flags:
#   --width <Int>         Width of the grid  (default 50)
#   --height <Int>        Height of the grid (default 50)
#   --peaks "x1,y1,x2,y2,..."  Comma-separated peak coordinates
#                              (default "10,40,40,10")
#   --max-sugar <Int>     Maximum sugar capacity at a peak (default 4)
#   --dia <Int>           Distance divisor controlling hill steepness (default 4)
#
# Example:
#   julia scripts/generate_board.jl --width 30 --height 30 \
#        --peaks "15,15" --max-sugar 5 --dia 4
# -----------------------------------------------------------------------------

using ArgParse
using Sugarscape

"""
    generate_grid(dims, sugar_peaks; max_sugar=4, dia=6)

Return an `Array{Int}` of sugar capacities for the given grid. `dia` controls
how quickly sugar capacity falls off from each peak (default 6, following the
main simulation constructor).
"""
function generate_grid(dims::Tuple{Int,Int}, sugar_peaks::Vector{Tuple{Int,Int}}; max_sugar::Int=4, dia::Int=6)
    return Sugarscape.sugar_caps(dims, sugar_peaks, max_sugar, dia)
end

"""
    print_grid(grid)

Pretty-print the grid to stdout, one row per line, columns separated by spaces.
"""
function print_grid(grid::AbstractMatrix)
    # Iterate over rows (y dimension) so that printing resembles the
    # conventional Cartesian orientation when viewed top-to-bottom.
    for j in 1:size(grid, 2)
        println(join(grid[:, j], " "))
    end
end

function main()
    s = ArgParseSettings()
    @add_arg_table s begin
        "--width"
        help = "Width of the grid"
        arg_type = Int
        default = 50

        "--height"
        help = "Height of the grid"
        arg_type = Int
        default = 50

        "--peaks"
        help = "Comma-separated sugar peak coordinates (x1,y1,x2,y2,...)"
        arg_type = String
        default = "10,40,40,10"

        "--max-sugar"
        help = "Maximum sugar capacity at a peak"
        arg_type = Int
        default = 4

        "--dia"
        help = "Distance divisor controlling hill steepness"
        arg_type = Int
        default = 6
    end

    parsed_args = parse_args(s)

    dims = (parsed_args["width"], parsed_args["height"])

    peak_tokens = split(parsed_args["peaks"], ',')
    if length(peak_tokens) % 2 != 0
        error("--peaks must contain an even number of integers: x1,y1,x2,y2,...")
    end
    sugar_peaks = Tuple{Int,Int}[]
    for i in 1:2:length(peak_tokens)
        push!(sugar_peaks, (parse(Int, peak_tokens[i]), parse(Int, peak_tokens[i+1])))
    end

    max_sugar = parsed_args["max-sugar"]
    dia = parsed_args["dia"]

    grid = generate_grid(dims, sugar_peaks; max_sugar=max_sugar, dia=dia)
    print_grid(grid)
end

if abspath(PROGRAM_FILE) == @__FILE__
    main()
end
