#!/usr/bin/env julia

"""
Sugarscape Unified Launcher
===========================

Single entry point for all Sugarscape visualization and development tools.
"""

using Pkg

function print_banner()
  println("╔═══════════════════════════════════════════════════════════════════════════════╗")
  println("║                           Sugarscape Unified Launcher                        ║")
  println("║                    Visualization & Development Tools                          ║")
  println("╚═══════════════════════════════════════════════════════════════════════════════╝")
  println()
end

function check_environment()
  println("🔧 Checking environment...")

  # Check if we're in the right directory
  if !isfile("Project.toml")
    println("❌ Error: Not in Sugarscape project directory")
    println("   Please run from: Sugarscape_capstone/Sugarscape/")
    return false
  end

  # Check for required visualization files
  required_files = [
    "src/Sugarscape.jl",
    "src/visualisation/dashboard.jl",
    "src/visualisation/interactive.jl"
  ]

  missing_files = []
  for file in required_files
    if !isfile(file)
      push!(missing_files, file)
    end
  end

  if !isempty(missing_files)
    println("❌ Missing required files:")
    for file in missing_files
      println("   - $file")
    end
    return false
  end

  println("✅ Environment check passed!")
  return true
end

function show_main_menu()
  println("🚀 Available Sugarscape Tools:")
  println()
  println("📊 VISUALIZATION DASHBOARDS")
  println("1. Main Dashboard - Comprehensive interactive dashboard")
  println("2. Custom Dashboard - Basic metrics with custom plots")
  println("3. Reproduction Dashboard - Population dynamics focused")
  println()
  println("🔬 ANALYTICS & RESEARCH")
  println("4. Analytics Pipeline - Comprehensive data analysis and research")
  println()
  println("🤖 LLM INTEGRATION")
  println("5. LLM Development Dashboard - LLM debugging with hot-reload")
  println("6. Enhanced LLM Dashboard - Advanced LLM decision visualization")
  println("7. LLM Prompt Tester - Test individual agent prompts")
  println("8. LLM Performance Benchmark - Performance testing")
  println()
  println("🔧 UTILITIES")
  println("9. Environment Setup - Configure .env and dependencies")
  println("10. Documentation - View development guides")
  println()
  println("0. Exit")
  println()
  println("─────────────────────────────────────────────────────────────────────────────────")
  print("Choose an option (0-9): ")
end

function setup_environment()
  println("🔧 Setting up development environment...")

  # Setup .env file
  if !isfile(".env")
    if isfile(".env.example")
      println("📄 Creating .env file from template...")
      cp(".env.example", ".env")
      println("✅ .env file created!")
      println("📝 Please edit .env and add your OpenAI API key:")
      println("   OPENAI_API_KEY=sk-your-api-key-here")
    else
      println("❌ .env.example file not found")
      return false
    end
  else
    println("✅ .env file already exists")
  end

  # Check dependencies
  println("📦 Checking dependencies...")
  required_packages = ["GLMakie", "JSON", "BenchmarkTools", "Revise"]

  try
    for pkg in required_packages
      eval(Meta.parse("using $pkg"))
    end
    println("✅ All dependencies available!")
    return true
  catch e
    println("❌ Some dependencies missing. Install with:")
    println("   julia --project=. -e 'using Pkg; Pkg.add([\"GLMakie\", \"JSON\", \"BenchmarkTools\", \"Revise\"])'")
    return false
  end
end

function launch_main_dashboard()
  println("📊 Launching Main Dashboard...")

  try
    # Set up arguments and include the unified dashboard script
    dashboard_script = joinpath(dirname(@__FILE__), "run_dashboard.jl")
    if !isfile(dashboard_script)
      error("Could not find run_dashboard.jl: $(dashboard_script)")
    end

    println("Running main dashboard script...")
    # Set ARGS for the dashboard script and include it
    original_args = copy(ARGS)
    empty!(ARGS)
    push!(ARGS, "main")
    try
      include(dashboard_script)
    finally
      # Restore original ARGS
      empty!(ARGS)
      append!(ARGS, original_args)
    end

    println("✅ Main dashboard launched successfully!")
    println("Features: Interactive controls, agent monitoring, CSV export, performance tracking")

    return true
  catch e
    println("❌ Error launching main dashboard:")
    println("Error: $(e)")
    println("Please check that all dependencies are installed and the environment is set up correctly.")
    return false
  end
end

function launch_custom_dashboard()
  println("📊 Launching Custom Dashboard...")

  try
    # Set up arguments and include the unified dashboard script
    dashboard_script = joinpath(dirname(@__FILE__), "run_dashboard.jl")
    if !isfile(dashboard_script)
      error("Could not find run_dashboard.jl: $(dashboard_script)")
    end

    println("Running custom dashboard script...")
    # Set ARGS for the dashboard script and include it
    original_args = copy(ARGS)
    empty!(ARGS)
    push!(ARGS, "custom")
    try
      include(dashboard_script)
    finally
      # Restore original ARGS
      empty!(ARGS)
      append!(ARGS, original_args)
    end

    println("✅ Custom dashboard launched successfully!")
    println("Features: Deaths over time, Gini coefficient, wealth distribution")

    return true
  catch e
    println("❌ Error launching custom dashboard:")
    println("Error: $(e)")
    println("Please check that all dependencies are installed and the environment is set up correctly.")
    return false
  end
end

function launch_reproduction_dashboard()
  println("📊 Launching Reproduction Dashboard...")

  try
    # Set up arguments and include the unified dashboard script
    dashboard_script = joinpath(dirname(@__FILE__), "run_dashboard.jl")
    if !isfile(dashboard_script)
      error("Could not find run_dashboard.jl: $(dashboard_script)")
    end

    println("Running reproduction dashboard script...")
    # Set ARGS for the dashboard script and include it
    original_args = copy(ARGS)
    empty!(ARGS)
    push!(ARGS, "reproduction")
    try
      include(dashboard_script)
    finally
      # Restore original ARGS
      empty!(ARGS)
      append!(ARGS, original_args)
    end

    println("✅ Reproduction dashboard launched successfully!")
    println("Features: Population dynamics, births vs deaths, age distribution")

    return true
  catch e
    println("❌ Error launching reproduction dashboard:")
    println("Error: $(e)")
    println("Please check that all dependencies are installed and the environment is set up correctly.")
    return false
  end
end

function launch_llm_dev_dashboard()
  println("🤖 Launching LLM Development Dashboard...")

  if !haskey(ENV, "OPENAI_API_KEY")
    println("❌ OPENAI_API_KEY not set. Please set up environment first.")
    return false
  end

  try
    # Get the correct paths - we're running from Sugarscape directory
    sugarscape_module_dir = joinpath(pwd(), "src")
    llm_dashboards_file = joinpath(pwd(), "src", "visualisation", "llm_dashboards.jl")

    # Validate paths exist
    if !isdir(sugarscape_module_dir)
      error("Could not find Sugarscape module directory: $(sugarscape_module_dir)")
    end

    if !isfile(llm_dashboards_file)
      error("Could not find llm_dashboards.jl: $(llm_dashboards_file)")
    end

    # Add to load path and include (following run_dashboard.jl pattern)
    if !(sugarscape_module_dir in LOAD_PATH)
      push!(LOAD_PATH, sugarscape_module_dir)
    end
    include(llm_dashboards_file)

    println("Creating LLM development dashboard with hot-reloading...")
    fig, abmobs = Sugarscape.create_llm_development_dashboard()

    display(fig)
    display(abmobs)

    println("✅ LLM development dashboard launched successfully!")
    println("Features: Revise.jl hot-reloading, LLM decision visualization, parameter controls")

    if !isinteractive()
      try
        while GLMakie.isopen(fig.scene)
          sleep(0.1)
        end
      catch e
        if e isa InterruptException
          println("Dashboard closed by user.")
        else
          rethrow()
        end
      end
    end
  catch e
    println("❌ Error launching LLM development dashboard:")
    println("Error: $(e)")
    println("Please check that all dependencies are installed and the environment is set up correctly.")
    return false
  end
  return true
end

function launch_enhanced_llm_dashboard()
  println("🤖 Launching Enhanced LLM Dashboard...")

  if !haskey(ENV, "OPENAI_API_KEY")
    println("❌ OPENAI_API_KEY not set. Please set up environment first.")
    return false
  end

  try
    # Get the correct paths - we're running from Sugarscape directory
    sugarscape_module_dir = joinpath(pwd(), "src")
    llm_dashboards_file = joinpath(pwd(), "src", "visualisation", "llm_dashboards.jl")

    # Validate paths exist
    if !isdir(sugarscape_module_dir)
      error("Could not find Sugarscape module directory: $(sugarscape_module_dir)")
    end

    if !isfile(llm_dashboards_file)
      error("Could not find llm_dashboards.jl: $(llm_dashboards_file)")
    end

    # Add to load path and include (following run_dashboard.jl pattern)
    if !(sugarscape_module_dir in LOAD_PATH)
      push!(LOAD_PATH, sugarscape_module_dir)
    end
    include(llm_dashboards_file)

    println("Creating enhanced LLM visualization dashboard...")
    fig, abmobs = Sugarscape.create_enhanced_llm_dashboard()

    display(fig)
    display(abmobs)

    println("✅ Enhanced LLM dashboard launched successfully!")
    println("Features: 5 decision types, movement arrows, relationship lines, history trails")

    if !isinteractive()
      try
        while GLMakie.isopen(fig.scene)
          sleep(0.1)
        end
      catch e
        if e isa InterruptException
          println("Dashboard closed by user.")
        else
          rethrow()
        end
      end
    end
  catch e
    println("❌ Error launching enhanced LLM dashboard:")
    println("Error: $(e)")
    println("Please check that all dependencies are installed and the environment is set up correctly.")
    return false
  end
  return true
end

function launch_llm_prompt_tester()
  println("🤖 Launching LLM Prompt Tester...")

  if !haskey(ENV, "OPENAI_API_KEY")
    println("❌ OPENAI_API_KEY not set. Please set up environment first.")
    return false
  end

  try
    # Path to the dedicated launcher script (same directory as this file)
    tester_script = joinpath(dirname(@__FILE__), "run_llm_prompt_tester.jl")

    if !isfile(tester_script)
      error("Could not find run_llm_prompt_tester.jl: $(tester_script)")
    end

    # Execute the script and capture its return value
    original_args = copy(ARGS)
    empty!(ARGS)           # The tester script does not expect any CLI arguments
    try
      ctx_resp_decision = include(tester_script)
    finally
      empty!(ARGS)
      append!(ARGS, original_args)
    end

    return ctx_resp_decision
  catch e
    println("❌ Error launching LLM prompt tester:")
    println("Error: $(e)")
    println("Please check that all dependencies are installed and the environment is set up correctly.")
    return false
  end
end

function launch_llm_benchmark()
  println("🤖 Launching LLM Performance Benchmark...")

  if !haskey(ENV, "OPENAI_API_KEY")
    println("❌ OPENAI_API_KEY not set. Please set up environment first.")
    return false
  end

  try
    # Get the correct paths - we're running from Sugarscape directory
    sugarscape_module_dir = joinpath(pwd(), "src")
    performance_test_file = joinpath(pwd(), "src", "visualisation", "performance.jl")

    # Validate paths exist
    if !isdir(sugarscape_module_dir)
      error("Could not find Sugarscape module directory: $(sugarscape_module_dir)")
    end

    if !isfile(performance_test_file)
      error("Could not find performance.jl: $(performance_test_file)")
    end

    # Add to load path and include (following run_dashboard.jl pattern)
    if !(sugarscape_module_dir in LOAD_PATH)
      push!(LOAD_PATH, sugarscape_module_dir)
    end
    include(performance_test_file)

    println("Starting comprehensive LLM performance testing...")
    results, fig = run_performance_test_interactive()

    display(fig)

    println("✅ LLM performance benchmark completed!")
    println("Features: Multi-scenario testing, performance comparison, results export")

    return results, fig
  catch e
    println("❌ Error launching LLM benchmark:")
    println("Error: $(e)")
    println("Please check that all dependencies are installed and the environment is set up correctly.")
    return false
  end
end

function launch_analytics_pipeline()
  println("🔬 Launching Analytics Pipeline...")

  try
    # Set up arguments and include the analytics script
    analytics_script = joinpath(dirname(@__FILE__), "run_analytics.jl")
    if !isfile(analytics_script)
      error("Could not find run_analytics.jl: $(analytics_script)")
    end

    println("Running analytics pipeline script...")
    println("Features:")
    println("  - Basic analytics setup and single run")
    println("  - Comparative analysis with effect sizes")
    println("  - Distribution evolution analysis")
    println("  - Network analysis deep dive")
    println("  - CSV export and visualisation")
    println()

    # Include the analytics script
    include(analytics_script)

    println("✅ Analytics pipeline completed successfully!")
    println("Results saved to data/results/ directory")

    return true
  catch e
    println("❌ Error launching analytics pipeline:")
    println("Error: $(e)")
    println("Please check that all dependencies are installed and the environment is set up correctly.")
    return false
  end
end

function show_documentation()
  println("📚 Documentation:")
  println()

  docs = [
    ("docs/DEVELOPMENT.md", "Development guide and best practices"),
    ("docs/visualisation_audit.md", "Visualization options audit"),
    ("docs/ENHANCED_DASHBOARD.md", "Enhanced dashboard documentation"),
    ("docs/HOT_RELOAD_GUIDE.md", "Hot reload development guide"),
    ("docs/SCRIPTS_DOCUMENTATION.md", "Scripts documentation")
  ]

  for (file, desc) in docs
    if isfile(file)
      println("✅ $file - $desc")
    else
      println("❌ $file - $desc (missing)")
    end
  end

  println()
  print("Would you like to open the main development guide? (y/n): ")
  response = readline()
  if lowercase(strip(response)) == "y"
    try
      if Sys.ismacos()
        run(`open docs/DEVELOPMENT.md`)
      elseif Sys.islinux()
        run(`xdg-open docs/DEVELOPMENT.md`)
      elseif Sys.iswindows()
        run(`start docs/DEVELOPMENT.md`)
      end
    catch
      println("📄 Please open docs/DEVELOPMENT.md in your preferred viewer")
    end
  end
end

function load_env_file()
  if isfile(".env")
    for line in readlines(".env")
      line = strip(line)
      if !isempty(line) && !startswith(line, "#")
        if contains(line, "=")
          key, value = split(line, "=", limit=2)
          ENV[strip(key)] = strip(value)
        end
      end
    end
  end
end

function main()
  print_banner()

  if !check_environment()
    println("❌ Environment check failed. Please fix the issues above.")
    return 1
  end

  # Load environment variables
  load_env_file()

  while true
    show_main_menu()

    try
      choice = parse(Int, readline())

      if choice == 0
        println("👋 Goodbye!")
        break
      elseif choice == 1
        success = launch_main_dashboard()
        if !success
          println("Dashboard launch failed. Please check the error above.")
        end
      elseif choice == 2
        success = launch_custom_dashboard()
        if !success
          println("Dashboard launch failed. Please check the error above.")
        end
      elseif choice == 3
        success = launch_reproduction_dashboard()
        if !success
          println("Dashboard launch failed. Please check the error above.")
        end
      elseif choice == 4
        success = launch_analytics_pipeline()
        if !success
          println("Analytics pipeline launch failed. Please check the error above.")
        end
      elseif choice == 5
        success = launch_llm_dev_dashboard()
        if success == false
          println("LLM dashboard launch failed. Please check the error above.")
        end
      elseif choice == 6
        success = launch_enhanced_llm_dashboard()
        if success == false
          println("LLM dashboard launch failed. Please check the error above.")
        end
      elseif choice == 7
        result = launch_llm_prompt_tester()
        if result == false
          println("LLM prompt tester launch failed. Please check the error above.")
        end
      elseif choice == 8
        result = launch_llm_benchmark()
        if result == false
          println("LLM benchmark launch failed. Please check the error above.")
        end
      elseif choice == 9
        setup_environment()
      elseif choice == 10
        show_documentation()
      else
        println("❌ Invalid choice. Please enter 0-10.")
      end

      if choice != 0
        println()
        print("Press Enter to continue...")
        readline()
        println()
      end

    catch e
      if isa(e, InterruptException)
        println("\n👋 Goodbye!")
        break
      elseif isa(e, ArgumentError)
        println("❌ Invalid input. Please enter a number 0-10.")
      else
        println("❌ Unexpected error: $(e)")
      end
    end
  end

  return 0
end

# Run the main function if this script is executed directly
if abspath(PROGRAM_FILE) == @__FILE__
  exit(main())
end
