#!/usr/bin/env julia

"""
Sugarscape AI / LLM Launcher
===========================

Entry point for AI-focused tooling: an interactive development dashboard that
surfaces LLM decisions and a single-agent prompt test that exercises the full
end-to-end OpenAI integration.

Usage:
  julia run_ai.jl [mode]

Where `mode` can be:
  • dev    – interactive dashboard for LLM development (default)
  • prompt – single-agent prompt test (strict parsing)
  • single – quick single-agent prompt test (non-interactive)
"""

# -----------------------------------------------------------------------------
# Parse command-line arguments
# -----------------------------------------------------------------------------
mode = length(ARGS) >= 1 ? ARGS[1] : "dev"
if mode ∉ ["dev", "prompt", "single"]
  println("Error: Invalid mode '$(mode)'")
  println("Valid options: dev, prompt, single")
  exit(1)
end

println("Loading Sugarscape AI $(titlecase(mode)) tool…")

# -----------------------------------------------------------------------------
# Resolve project paths – we assume the following structure:
#   project_root/
#     Sugarscape/            ← Julia package dir (this file lives in scripts/)
#       src/
# -----------------------------------------------------------------------------
project_root = dirname(dirname(@__DIR__))  # -> Sugarscape_capstone
sugarscape_src = joinpath(project_root, "Sugarscape", "src")
ai_dashboards_file = joinpath(sugarscape_src, "visualisation", "ai_dashboards.jl")

# Sanity checks – be helpful if the user moved things around.
if !isdir(sugarscape_src)
  error("Could not find Sugarscape module directory: $(sugarscape_src)")
end
if !isfile(ai_dashboards_file)
  error("Could not find ai_dashboards.jl: $(ai_dashboards_file)")
end

# Make sure the Sugarscape module is on LOAD_PATH and load the new dashboards.
push!(LOAD_PATH, sugarscape_src)

# Explicitly `using` first so that the module is compiled before we `include` –
# avoids duplicate method warnings if the user reloads.
using Sugarscape
include(ai_dashboards_file)  # no-op if already included via Sugarscape.jl

# -----------------------------------------------------------------------------
# Launch chosen mode
# -----------------------------------------------------------------------------
if mode == "dev"
  println("Creating AI development dashboard – press Ctrl+C to quit …")
  fig, abmobs = Sugarscape.create_ai_dashboard()
  display(fig)
  display(abmobs)
  println("Interactive dashboard window displayed.")

  # Keep script alive in non-interactive terminals
  if !isinteractive()
    try
      while GLMakie.isopen(fig.scene)
        sleep(0.1)
      end
    catch e
      if e isa InterruptException
        println("Interrupted by user (Ctrl+C).")
      else
        rethrow()
      end
    end
    println("Makie window closed. Exiting.")
  end

elseif mode == "prompt"
  if !haskey(ENV, "OPENAI_API_KEY")
    println("❌ OPENAI_API_KEY not set.  Please configure it first (see README).")
    exit(1)
  end

  # Run the interactive prompt test and allow the user to inspect artefacts.
  ctx, resp, decision = Sugarscape.run_llm_prompt_test_interactive()

  # In non-interactive shells return the objects so callers can consume them.
  return ctx, resp, decision

elseif mode == "single"
  if !haskey(ENV, "OPENAI_API_KEY")
    println("❌ OPENAI_API_KEY not set.  Please configure it first (see README).")
    exit(1)
  end

  ctx, resp, decision = Sugarscape.test_single_agent_prompt()

  # Provide a succinct summary to stdout so CI pipelines can grep for success.
  if ctx === nothing
    println("❌ Single-agent prompt test failed.")
    exit(1)
  else
    println("✅ Single-agent prompt test completed successfully.")
  end

  return ctx, resp, decision
end
