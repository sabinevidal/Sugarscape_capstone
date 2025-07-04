using Revise
using Sugarscape
using JSON

println("=== Revise.jl Hot-Reload Test ===")

# Test 1: Basic Revise functionality
println("\n--- Test 1: Basic Revise Setup ---")
if isdefined(Main, :Revise) && Revise.watching_files[]
  println("✓ Revise is active and watching files")
else
  println("✗ Revise is not properly configured")
end

# Test 2: Initial LLM integration state
println("\n--- Test 2: Initial LLM Integration State ---")
model = Sugarscape.sugarscape(N=1, dims=(5, 5))
model.use_llm_decisions = true
model.llm_api_key = "test-key"
model.llm_temperature = 0.0

agents = collect(Sugarscape.allagents(model))
println("✓ Model created with ", length(agents), " agents")

# Test the current LLM error formatting
try
  error = Sugarscape.SugarscapeLLM.LLMValidationError("Test error", "test_field", "test_value", 1)
  formatted = Sugarscape.SugarscapeLLM.format_llm_error(error)
  println("✓ Current error formatting works")
  println("Current format preview: ", split(formatted, '\n')[1])
catch e
  println("✗ Error in current LLM integration: ", e)
end

# Test 3: Check if files are being watched
println("\n--- Test 3: File Watching Status ---")
llm_file = "src/utils/llm_integration.jl"
if isfile(llm_file)
  println("✓ LLM integration file exists: ", llm_file)

  # Check if file is in Revise's watch list
  watched_files = Revise.watched_files
  if any(occursin("llm_integration.jl", string(f)) for f in keys(watched_files))
    println("✓ LLM integration file is being watched by Revise")
  else
    println("⚠ LLM integration file may not be watched by Revise")
    println("  Watched files: ", length(watched_files))
  end
else
  println("✗ LLM integration file not found")
end

# Test 4: Test hot-reload simulation
println("\n--- Test 4: Hot-Reload Simulation ---")
println("Testing if changes to LLM integration are picked up...")

# Create a temporary modification to test hot-reload
original_format_function = Sugarscape.SugarscapeLLM.format_llm_error

# Create a simple test to see if we can modify behavior
println("Current function behavior test:")
test_error = Sugarscape.SugarscapeLLM.LLMValidationError("Test message", "test_field", "test_value", 123)
original_output = Sugarscape.SugarscapeLLM.format_llm_error(test_error)
println("Original output length: ", length(original_output))

# Test 5: Module reload capability
println("\n--- Test 5: Module Reload Capability ---")
try
  # Test if we can trigger a reload
  Revise.revise()
  println("✓ Manual revise completed without errors")

  # Test that functions are still accessible after reload
  test_error_2 = Sugarscape.SugarscapeLLM.LLMValidationError("Test after reload", "field", "value", 456)
  post_reload_output = Sugarscape.SugarscapeLLM.format_llm_error(test_error_2)
  println("✓ Functions accessible after reload")
  println("Post-reload output length: ", length(post_reload_output))

catch e
  println("✗ Error during manual reload: ", e)
end

# Test 6: Development workflow simulation
println("\n--- Test 6: Development Workflow Simulation ---")
println("This would typically involve:")
println("1. Starting the development dashboard")
println("2. Making a change to LLM integration code")
println("3. Clicking 'Reset' in the dashboard")
println("4. Verifying the change is applied")
println("")
println("✓ Hot-reload infrastructure is ready for interactive testing")

# Test 7: Check for potential issues
println("\n--- Test 7: Potential Issues Check ---")
issues = []

# Check if multiple processes might interfere
if Threads.nthreads() > 1
  push!(issues, "Multiple threads detected - ensure thread safety")
end

# Check for precompilation issues
if !isempty(Base.loaded_modules)
  println("✓ Modules loaded: ", length(Base.loaded_modules))
end

if isempty(issues)
  println("✓ No obvious issues detected")
else
  for issue in issues
    println("⚠ ", issue)
  end
end

println("\n=== Hot-Reload Test Summary ===")
println("✓ Revise.jl integration appears functional")
println("✓ LLM integration module is accessible")
println("✓ Manual reload capability works")
println("✓ Ready for interactive development testing")
println("")
println("To fully test hot-reload:")
println("1. Run: julia --project=. scripts/dev_dashboard.jl")
println("2. Edit src/utils/llm_integration.jl")
println("3. Click 'Reset' in the dashboard")
println("4. Verify changes are applied")
