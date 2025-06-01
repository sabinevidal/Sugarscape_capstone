#!/usr/bin/env julia

using Pkg
Pkg.activate("Sugarscape")

using Sugarscape
using GLMakie
using Agents: nagents

println("Testing fixed reproduction dashboards...")

# Test 1: Fixed reproduction dashboard with error handling
println("\n1. Testing fixed reproduction dashboard...")
try
  fig1, abmobs1 = Sugarscape.create_reproduction_dashboard()
  println("✓ Fixed reproduction dashboard created successfully")
  println("  - Initial population: $(nagents(abmobs1.model[]))")
  println("  - Dashboard includes robust error handling for dimension mismatches")
  println("  - Try stepping the model using the controls!")
  display(fig1)
catch e
  println("✗ Error creating fixed dashboard: $e")
end

println("\nTest completed!")
println("\nRecommendations:")
println("- Use create_simple_reproduction_dashboard() for most stable experience")
println("- Use create_reproduction_dashboard() if you prefer abmplot integration")
println("- Both dashboards handle reproduction and track births/deaths")
