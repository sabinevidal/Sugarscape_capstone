#!/usr/bin/env julia

"""
Sugarscape LLM Development Environment
=====================================

Unified entry point for LLM development tools and workflows.
"""

using Pkg

function print_banner()
  println("╔════════════════════════════════════════════════════════════════╗")
  println("║                   Sugarscape LLM Development                  ║")
  println("║                        Environment                            ║")
  println("╚════════════════════════════════════════════════════════════════╝")
  println()
end

function check_environment()
  println("🔧 Checking development environment...")

  # Check if we're in the right directory
  if !isfile("Project.toml")
    println("❌ Error: Not in Sugarscape project directory")
    println("   Please run from: Sugarscape_capstone/Sugarscape/")
    return false
  end

  # Check for required files
  required_files = [
    "src/Sugarscape.jl",
    "src/utils/llm_integration.jl",
    "scripts/ai_prompt.jl",
    "scripts/ai_dashboard.jl",
    "scripts/ai_performance_test.jl",
    ".env.example"
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

  # Check environment variables
  if !haskey(ENV, "OPENAI_API_KEY")
    println("⚠️  Warning: OPENAI_API_KEY not set")
    println("   Create .env file from .env.example and set your API key")
    println("   Or export OPENAI_API_KEY=your-api-key")
    println()
  end

  println("✅ Environment check passed!")
  return true
end

function show_menu()
  println("🚀 Available Development Tools:")
  println()
  println("1. 🧪 AI Prompt Testing Harness")
  println("   Test individual agent prompts with detailed output")
  println("   → julia --project=. scripts/ai_prompt.jl")
  println()
  println("2. 📊 AI Dashboard")
  println("   Interactive dashboard with LLM integration and hot-reloading")
  println("   → julia --project=. scripts/ai_dashboard.jl")
  println()
  println("3. ⚡ AI Performance Benchmarks")
  println("   Comprehensive performance testing and analysis")
  println("   → julia --project=. scripts/ai_performance_test.jl")
  println()
  println("4. 📚 Documentation")
  println("   Development guide and best practices")
  println("   → docs/DEVELOPMENT.md")
  println()
  println("5. 🔧 Environment Setup")
  println("   Set up .env file and configuration")
  println()
  println("6. 🏃 Quick Start")
  println("   Launch development dashboard immediately")
  println()
  println("0. Exit")
  println()
  println("─────────────────────────────────────────────────────────────────")
  print("Choose an option (0-6): ")
end

function setup_environment()
  println("🔧 Setting up development environment...")

  if !isfile(".env")
    if isfile(".env.example")
      println("📄 Creating .env file from template...")
      cp(".env.example", ".env")
      println("✅ .env file created!")
      println("📝 Please edit .env and add your OpenAI API key:")
      println("   OPENAI_API_KEY=sk-your-api-key-here")
      println()
    else
      println("❌ .env.example file not found")
      return false
    end
  else
    println("✅ .env file already exists")
  end

  # Check if dependencies are installed
  println("📦 Checking development dependencies...")

  required_packages = ["Revise", "BenchmarkTools", "JSON", "GLMakie"]

  try
    # Load packages to check if they're available
    for pkg in required_packages
      println("   Checking $pkg...")
      eval(Meta.parse("using $pkg"))
    end
    println("✅ All development dependencies available!")
  catch e
    println("❌ Some dependencies missing. Please install:")
    println("   julia --project=. -e 'using Pkg; Pkg.add([\"Revise\", \"BenchmarkTools\", \"JSON\", \"GLMakie\"])'")
    return false
  end

  println("🎉 Environment setup complete!")
  return true
end

function launch_cli_tester()
  println("🧪 Launching CLI Testing Harness...")

  if !haskey(ENV, "OPENAI_API_KEY")
    println("❌ OPENAI_API_KEY not set. Please set up environment first.")
    return
  end

  # Load and run the CLI tester
  include("ai_prompt.jl")
end

function launch_dashboard()
  println("📊 Launching Development Dashboard...")

  if !haskey(ENV, "OPENAI_API_KEY")
    println("❌ OPENAI_API_KEY not set. Please set up environment first.")
    return
  end

  # Load and run the dashboard
  include("ai_dashboard.jl")
end

function launch_benchmarks()
  println("⚡ Launching Performance Benchmarks...")

  if !haskey(ENV, "OPENAI_API_KEY")
    println("❌ OPENAI_API_KEY not set. Please set up environment first.")
    return
  end

  # Load and run the benchmarks
  include("ai_performance_test.jl")
end

function show_documentation()
  println("📚 Development Documentation:")
  println()

  if isfile("docs/DEVELOPMENT.md")
    println("📖 Full development guide: docs/DEVELOPMENT.md")
    println()
    println("Quick reference:")
    println("- Environment setup: see 'Initial Setup' section")
    println("- Development workflows: see 'Development Workflows' section")
    println("- Troubleshooting: see 'Troubleshooting' section")
    println("- Best practices: see 'Best Practices' section")
    println()

    print("Would you like to view the documentation? (y/n): ")
    response = readline()
    if lowercase(strip(response)) == "y"
      # Try to open with default system viewer
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
  else
    println("❌ Documentation not found: docs/DEVELOPMENT.md")
  end
end

function main()
  print_banner()

  if !check_environment()
    println("❌ Environment check failed. Please fix the issues above.")
    return 1
  end

  # Load environment variables from .env if it exists
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

  while true
    show_menu()

    try
      choice = parse(Int, readline())

      if choice == 0
        println("👋 Goodbye!")
        break
      elseif choice == 1
        launch_cli_tester()
      elseif choice == 2
        launch_dashboard()
      elseif choice == 3
        launch_benchmarks()
      elseif choice == 4
        show_documentation()
      elseif choice == 5
        setup_environment()
      elseif choice == 6
        println("🏃 Quick Start: Launching Development Dashboard...")
        launch_dashboard()
      else
        println("❌ Invalid choice. Please enter 0-6.")
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
      else
        println("❌ Invalid input. Please enter a number 0-6.")
      end
    end
  end

  return 0
end

# Run the main function if this script is executed directly
if abspath(PROGRAM_FILE) == @__FILE__
  exit(main())
end
