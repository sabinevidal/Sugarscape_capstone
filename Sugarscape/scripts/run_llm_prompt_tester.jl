#!/usr/bin/env julia

"""
Sugarscape LLM Prompt Tester
===========================

Runs the single-agent interactive LLM prompt test that demonstrates the
end-to-end OpenAI integration (context building → API call → response
validation) with strict error handling.

This script is intended to be invoked either directly:
  julia run_llm_prompt_tester.jl
or indirectly via `scripts/run_sugarscape.jl` (menu option 7).
"""

# Ensure the OpenAI key is available early – avoids constructing the model only
# to fail later.
if !haskey(ENV, "OPENAI_API_KEY")
  println("❌ OPENAI_API_KEY not set.  Please configure it first (see README).")
  exit(1)
end

# -----------------------------------------------------------------------------
# Resolve project paths – we assume the following structure:
#   project_root/
#     Sugarscape/            ← Julia package dir (this file lives in scripts/)
#       src/
#         visualisation/testing.jl
# -----------------------------------------------------------------------------
project_root = dirname(dirname(@__DIR__))  # -> Sugarscape_capstone
sugarscape_module_dir = joinpath(project_root, "Sugarscape", "src")
testing_file = joinpath(sugarscape_module_dir, "visualisation", "testing.jl")

# Sanity checks – fail fast with helpful error messages if something is wrong.
if !isdir(sugarscape_module_dir)
  error("Could not find Sugarscape module directory: $(sugarscape_module_dir)")
end
if !isfile(testing_file)
  error("Could not find testing.jl: $(testing_file)")
end

# Make sure the Sugarscape module is on LOAD_PATH and load the testing helpers.
push!(LOAD_PATH, sugarscape_module_dir)
include(testing_file)

# -----------------------------------------------------------------------------
# Run the interactive test and return the resulting artefacts so that the caller
# (e.g. run_sugarscape.jl) can decide what to do with them.
# -----------------------------------------------------------------------------
ctx, resp, decision = run_llm_prompt_test_interactive()

return ctx, resp, decision
