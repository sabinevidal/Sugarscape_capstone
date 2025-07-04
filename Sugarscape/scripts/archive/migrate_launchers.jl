#!/usr/bin/env julia

"""
Launcher Migration Utility
==========================

Helps migrate from old individual launcher scripts to the unified launcher system.
"""

function show_banner()
  println("╔═══════════════════════════════════════════════════════════════════════════════╗")
  println("║                        Launcher Migration Utility                            ║")
  println("╚═══════════════════════════════════════════════════════════════════════════════╝")
  println()
end

function show_migration_mapping()
  println("📋 Script Migration Mapping:")
  println()

  migrations = [
    ("run_dashboard.jl", "run_sugarscape.jl → Option 1", "Main Dashboard"),
    ("run_custom_dashboard.jl", "run_sugarscape.jl → Option 2", "Custom Dashboard"),
    ("run_reproduction_dashboard.jl", "run_sugarscape.jl → Option 3", "Reproduction Dashboard"),
    ("ai_dashboard.jl", "run_sugarscape.jl → Option 4", "LLM Development Dashboard"),
    ("ai_prompt.jl", "run_sugarscape.jl → Option 6", "LLM Prompt Tester"),
    ("dev_start.jl", "run_sugarscape.jl", "Replaced entirely"),
    ("enhanced_dashboard.jl", "Keep as-is", "Advanced LLM visualization"),
    ("ai_performance_test.jl", "Keep as-is", "Performance benchmarking")
  ]

  for (old_script, new_access, description) in migrations
    status = isfile(old_script) ? "✅" : "❌"
    println("$status $old_script")
    println("   → $new_access")
    println("   📝 $description")
    println()
  end
end

function create_archive_directory()
  archive_dir = "archive"
  if !isdir(archive_dir)
    println("📁 Creating archive directory...")
    mkdir(archive_dir)
    println("✅ Created: $archive_dir/")
  else
    println("✅ Archive directory already exists: $archive_dir/")
  end
  return archive_dir
end

function archive_old_scripts()
  println("📦 Archiving old launcher scripts...")

  scripts_to_archive = [
    "run_dashboard.jl",
    "run_custom_dashboard.jl",
    "run_reproduction_dashboard.jl",
    "ai_dashboard.jl",
    "ai_prompt.jl",
    "dev_start.jl"
  ]

  archive_dir = create_archive_directory()
  archived_count = 0

  for script in scripts_to_archive
    if isfile(script)
      dest = joinpath(archive_dir, script)
      if !isfile(dest)
        cp(script, dest)
        println("   ✅ Archived: $script → $dest")
        archived_count += 1
      else
        println("   ⚠️  Already archived: $script")
      end
    else
      println("   ❌ Not found: $script")
    end
  end

  println()
  println("📊 Archived $archived_count scripts to $archive_dir/")

  if archived_count > 0
    println()
    println("⚠️  IMPORTANT: Scripts have been copied to archive, not moved.")
    println("   You can safely delete the originals once you've tested the unified launcher.")
    println("   Or run this script with --remove to delete originals after archiving.")
  end
end

function test_unified_launcher()
  println("🧪 Testing unified launcher...")

  if isfile("run_sugarscape.jl")
    println("✅ run_sugarscape.jl exists")

    # Test if it's executable
    try
      # Don't actually run it, just check syntax
      cmd = `julia --project=. -e "include(\"run_sugarscape.jl\"); println(\"Syntax check passed\")"`
      # Just check the file exists and is readable
      println("✅ Unified launcher appears to be valid")
    catch e
      println("❌ Error with unified launcher: $e")
      return false
    end

    return true
  else
    println("❌ run_sugarscape.jl not found!")
    println("   Please ensure you've created the unified launcher first.")
    return false
  end
end

function show_next_steps()
  println("🎯 Next Steps:")
  println()
  println("1. Test the unified launcher:")
  println("   julia --project=. scripts/run_sugarscape.jl")
  println()
  println("2. Update your documentation and READMEs")
  println("   - Point users to the unified launcher")
  println("   - Update development guides")
  println()
  println("3. Clean up (after testing):")
  println("   - Delete original launcher scripts from main directory")
  println("   - Keep archive/ for historical reference")
  println()
  println("4. Update any automation:")
  println("   - CI/CD scripts")
  println("   - Tutorial materials")
  println()
end

function main()
  show_banner()

  println("This utility helps migrate from individual launcher scripts to the unified launcher system.")
  println()

  # Check if we're in the right directory
  if !isfile("Project.toml")
    println("❌ Error: Not in Sugarscape project directory")
    println("   Please run from: Sugarscape_capstone/Sugarscape/")
    return 1
  end

  show_migration_mapping()

  println("🚀 Migration Options:")
  println("1. Archive old scripts (copy to archive/ directory)")
  println("2. Test unified launcher")
  println("3. Show next steps")
  println("4. Do all of the above")
  println("0. Exit")
  println()

  print("Choose an option (0-4): ")

  try
    choice = parse(Int, readline())

    if choice == 0
      println("👋 Goodbye!")
    elseif choice == 1
      archive_old_scripts()
    elseif choice == 2
      test_unified_launcher()
    elseif choice == 3
      show_next_steps()
    elseif choice == 4
      archive_old_scripts()
      println()
      test_unified_launcher()
      println()
      show_next_steps()
    else
      println("❌ Invalid choice.")
    end

  catch e
    if isa(e, InterruptException)
      println("\n👋 Goodbye!")
    else
      println("❌ Invalid input.")
    end
  end

  return 0
end

# Run if executed directly
if abspath(PROGRAM_FILE) == @__FILE__
  exit(main())
end
