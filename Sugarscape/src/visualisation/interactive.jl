using Sugarscape

using Agents
using GLMakie

agent_s_interactive(a) = 8

# --- INTERACTIVE APPLICATION SETUP ---
function create_interactive_app()
    # Initial model parameters
    initial_num_agents = 200
    initial_pollution_enabled_numeric = 0

    # Parameters for sliders (ranges for the GUI)
    model_params = Dict(
        :N => initial_num_agents:1:500,
        :enable_pollution => (false, true),
    )

    # Create an initial model instance using default/initial parameters
    initial_model = Sugarscape.sugarscape(;
        N = initial_num_agents,
        enable_pollution = Bool(initial_pollution_enabled_numeric) # Use initial for now
    )

    model_generating_function = (current_params) -> begin
        N_val = :N in keys(current_params) ? current_params.N : initial_num_agents
        enable_pollution_val = :enable_pollution in keys(current_params) ? current_params.enable_pollution : initial_pollution_enabled_numeric

        model_instance = Sugarscape.sugarscape(;
            N = current_params.N,
            enable_pollution = Bool(current_params.enable_pollution)
        )
        return model_instance
    end

    # Function to get sugar values for heatmap
    sugarmap(model) = model.sugar_values

    # Keywords for the heatmap
    max_initial_sugar_capacity = 0.0
    if !isempty(initial_model.sugar_capacities)
        max_initial_sugar_capacity = maximum(initial_model.sugar_capacities)
    end
    heatkwargs = (
        colormap = :viridis,
        colorrange = (0.0, max_initial_sugar_capacity > 0 ? max_initial_sugar_capacity : 4.0)
    )

    fig, abmobs = abmexploration(
        initial_model;
        model_generator = model_generating_function,
        agent_step! = Sugarscape._agent_step!,
        model_step! = Sugarscape._model_step!,
        params = model_params,
        agent_size = agent_s_interactive,
        heatarray = sugarmap,
        heatkwargs = heatkwargs,
        figure = (; size = (900, 750)),
    )

    return fig, abmobs
end
