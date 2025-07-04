using Test

# Collect all test files in this directory and include them
for file in readdir(@__DIR__)
  endswith(file, ".jl") && file != basename(@__FILE__) && include(file)
end
