using Agents, Random, Distributions, DataFrames

# =============================================================================
# Rule-only Sugarscape model logic (no LLM integration)
# =============================================================================


# =============================================================================
# Model-level scheduler step (rule-only)
# =============================================================================
function _model_step!(model)
  # --- Resource growback (seasonal or regular)
  if model.enable_seasonality
    seasonal_growback!(model)
    model.current_season_steps += 1
    if model.current_season_steps >= model.season_duration
      model.is_summer_top = !model.is_summer_top
      model.current_season_steps = 0
    end
  else
    growback!(model)
  end

  # Reset combat movement registry (asynchronous combat handled per agent)
  model.agents_moved_combat = Set{Int}()

  # Pollution diffusion
  if model.enable_pollution
    model.current_pollution_diffusion_steps += 1
    if model.current_pollution_diffusion_steps >= model.pollution_diffusion_interval
      pollution_diffusion!(model)
      model.current_pollution_diffusion_steps = 0
    end
  end

  # Disease dynamics
  if model.enable_disease
    disease_transmission!(model)
    immune_response!(model)
  end

  return
end

# =============================================================================
# Agent-level step
# =============================================================================
function _agent_step!(agent, model)
  if model.enable_combat
    maybe_combat!(agent, model)
  else
    movement!(agent, model)
  end

  # Death & Reproduction
  if !model.enable_reproduction
    death_replacement!(agent, model)
  else
    if agent.sugar ≤ 0 || agent.age ≥ agent.max_age
      cause = agent.sugar ≤ 0 ? :starvation : :age
      death!(agent, model, cause)
    end
    Sugarscape.reproduction!(agent, model)
  end

  # Culture
  if model.enable_culture
    culture_spread!(agent, model)
  end

  # Credit phase
  if model.enable_credit
    credit!(agent, model)
  end


end
