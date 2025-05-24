# Sugarscape Model with Agents.jl

This project implements the Sugarscape agent-based model using the [Agents.jl](https://juliadynamics.github.io/Agents.jl/stable/) framework in Julia.

## Getting Started

1. **Install Julia**: Download and install Julia from [julialang.org](https://julialang.org/downloads/).
2. **Install dependencies**: In the project directory, open a Julia REPL and run:
   ```julia
   using Pkg
   Pkg.instantiate()
   ```
3. **Run the model**:
   - For interactive visualization, run:
     ```julia
     include("scripts/run_visualization.jl")
     ```
   - To record an animation, run:
     ```julia
     include("scripts/record_animation.jl")
     ```
   - The core model logic is in `src/Sugarscape.jl`. You can run and modify it as needed.

## Project Structure
- `src/Sugarscape.jl`: Main module and model code, including functions for interactive visualization and animation recording.
- `scripts/`: Contains scripts to run common tasks.
  - `run_visualization.jl`: Launches an interactive visualization of the model.
  - `record_animation.jl`: Records an animation of the model simulation.
- `Project.toml`: Project dependencies.

## References
- Epstein, J. M., & Axtell, R. (1996). *Growing Artificial Societies: Social Science from the Bottom Up*. Brookings Institution Press.
- [Agents.jl Documentation](https://juliadynamics.github.io/Agents.jl/stable/)
