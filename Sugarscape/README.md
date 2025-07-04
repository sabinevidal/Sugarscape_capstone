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

## LLM Integration (optional)

The model can delegate each agent's decisions (move, combat, credit, reproduction) to a Large-Language Model such as OpenAI GPT-4.  This feature is **disabled by default** and incurs no network calls unless explicitly switched on.

### 1 · Prerequisites

1. Obtain an OpenAI API key and set it as an environment variable:

   ```bash
   export OPENAI_API_KEY="sk-…"
   ```

2. Ensure the optional dependencies `HTTP.jl` and `JSON.jl` are present – they are already listed in `Project.toml` so `Pkg.instantiate()` will install them automatically.

### 2 · Quick start

```julia
using Sugarscape

# Minimal example with LLM decisions enabled
model = Sugarscape.sugarscape(
    use_llm_decisions = true,
    llm_api_key = ENV["OPENAI_API_KEY"],   # or pass the key string directly
    llm_model   = "gpt-4o",                # any chat-completion model
    dims        = (50, 50),
    N           = 200,
)

# step the simulation – agents will query the LLM once per tick
step!(model, 100)

# You can toggle the feature on/off at runtime:
model.use_llm_decisions = false  # fall back to rule-based behaviour
model.use_llm_decisions = true   # re-enable LLM control
```

### 3 · Batching & determinism

• The library batches all agents into a single API call per tick for efficiency.<br/>
• Set `llm_temperature = 0.0` to obtain deterministic answers (useful for tests & reproducibility).

-If the request fails or returns invalid data the simulation silently falls back to the original rule-based logic, ensuring robustness.
 If the request fails or returns invalid JSON an error will be raised so you can fix the prompt or retry – no silent fallback.

## References
- Epstein, J. M., & Axtell, R. (1996). *Growing Artificial Societies: Social Science from the Bottom Up*. Brookings Institution Press.
- [Agents.jl Documentation](https://juliadynamics.github.io/Agents.jl/stable/)
