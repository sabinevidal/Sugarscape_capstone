# Sugarscape Scripts Documentation

This document provides an overview of all scripts in the `Sugarscape/scripts/` directory, their purposes, and how to use them.

## 🚀 Quick Start - Unified Launcher (Recommended)

**Single entry point for all Sugarscape tools:**

```bash
cd Sugarscape/
julia --project=. scripts/run_sugarscape.jl
```

**Interactive menu with options:**
- **Visualization Dashboards** (Main, Custom, Reproduction-focused)
- **LLM Integration Tools** (Development, Analysis, Testing, Benchmarking)
- **Analytics & Research** (Comprehensive data analysis pipeline)
- **Utilities** (Environment setup, Documentation)

## 📊 Current Scripts

### `run_sugarscape.jl` (Main Launcher)
**Purpose**: Unified entry point for all Sugarscape visualization and development tools
- **Type**: Interactive menu-driven launcher
- **Features**:
  - Environment validation and setup
  - Interactive menu for choosing tools
  - Environment variable configuration (.env file setup)
  - Dependency checking
  - Documentation access
- **Usage**: `julia --project=. scripts/run_sugarscape.jl`
- **Best for**: New users, quick access to all tools, environment setup

### `run_dashboard.jl` (Unified Dashboard Launcher)
**Purpose**: Launches different types of Sugarscape dashboards
- **Type**: Command-line dashboard launcher
- **Features**:
  - Supports three dashboard types: main, custom, reproduction
  - Unified interface for all dashboard variants
  - Automatic path resolution and validation
- **Usage**:
  - `julia --project=. scripts/run_dashboard.jl main`
  - `julia --project=. scripts/run_dashboard.jl custom`
  - `julia --project=. scripts/run_dashboard.jl reproduction`
- **Best for**: Direct dashboard access without menu navigation

### `run_analytics.jl` (Analytics Pipeline)
**Purpose**: Comprehensive data analysis and research pipeline
- **Type**: Research and analytics suite
- **Features**:
  - Basic analytics setup and single run
  - Comparative analysis with effect sizes
  - Distribution evolution analysis
  - Network analysis deep dive
  - CSV export and visualization
  - Statistical analysis (Gini coefficient, Pareto alpha, etc.)
- **Usage**: `julia --project=. scripts/run_analytics.jl`
- **Best for**: Research, data analysis, experimental comparisons

### `enhanced_dashboard.jl` (Advanced LLM Visualization)
**Purpose**: Advanced LLM decision visualization with comprehensive visual feedback
- **Type**: Advanced GLMakie dashboard with extensive visualization features
- **Features**:
  - Granular decision type visualization (5 distinct types)
  - Movement direction arrows
  - Target relationship lines (combat/credit/reproduction)
  - Real-time decision analytics panel
  - Historical movement trails with fading effects
  - Decision history tracking
  - Interactive parameter controls
  - Revise.jl hot-reloading support
- **Usage**: `julia --project=. scripts/enhanced_dashboard.jl`
- **Best for**: Detailed analysis of LLM decision patterns and agent interactions

## 📁 Archived Scripts

The following scripts have been moved to `scripts/archive/` and are maintained for reference:

### `archive/dev_start.jl`
**Purpose**: Legacy development environment launcher
- **Type**: Interactive menu-driven development launcher
- **Features**: Environment validation, tool selection, documentation access
- **Status**: Superseded by `run_sugarscape.jl`

### `archive/ai_dashboard.jl`
**Purpose**: Legacy AI-powered dashboard with Revise.jl integration
- **Type**: Interactive GLMakie dashboard with LLM debugging features
- **Features**: Hot-reloading, LLM decision visualization, interactive parameter sliders
- **Status**: Superseded by enhanced dashboard functions in `/src/visualisation/llm_dashboards.jl`

### `archive/ai_prompt.jl`
**Purpose**: Legacy CLI testing harness for individual agent LLM prompts
- **Type**: Command-line testing tool
- **Features**: Single agent prompt testing, detailed API call logging, JSON response inspection
- **Status**: Superseded by testing functions in `/src/visualisation/testing.jl`

### `archive/ai_performance_test.jl`
**Purpose**: Legacy performance benchmarking for LLM integration
- **Type**: Benchmarking suite
- **Features**: Multiple model size testing, LLM vs rule-based performance comparison
- **Status**: Superseded by performance testing functions in `/src/visualisation/performance_test.jl`

### `archive/run_custom_dashboard.jl`
**Purpose**: Legacy custom Sugarscape dashboard with all metrics
- **Type**: Enhanced simulation dashboard
- **Features**: Comprehensive metrics collection, custom visualization features
- **Status**: Superseded by `run_dashboard.jl custom`

### `archive/run_reproduction_dashboard.jl`
**Purpose**: Legacy dashboard with reproduction extension focus
- **Type**: Specialized dashboard for reproduction mechanics
- **Features**: Reproduction-specific metrics, population dynamics visualization
- **Status**: Superseded by `run_dashboard.jl reproduction`

## 🔧 Function-Based Architecture

**All visualization logic organized in `/src/visualisation/`:**
- `dashboard.jl` - Main comprehensive dashboard
- `interactive.jl` - Custom dashboards
- `llm_dashboards.jl` - LLM-specific visualizations
- `testing.jl` - Testing utilities
- `performance_test.jl` - Performance testing
- `analytics.jl` - Analytics pipeline
- `plotting.jl` - Foundation functions

## 📊 Usage Guidelines

### For New Users:
1. **Start with**: `run_sugarscape.jl` for environment setup and tool selection
2. **For basic simulation**: Choose Option 1 (Main Dashboard)
3. **For research**: Choose Option 4 (Analytics Pipeline)

### For Development:
1. **For iterative development**: Choose Option 5 (LLM Development Dashboard)
2. **For detailed analysis**: Choose Option 6 (Enhanced LLM Dashboard)
3. **For testing**: Choose Option 7 (LLM Prompt Tester)
4. **For performance benchmarking**: Choose Option 8 (LLM Performance Benchmark)

### For Research:
1. **For comprehensive analysis**: `run_analytics.jl`
2. **For population studies**: `run_dashboard.jl reproduction`
3. **For custom metrics**: `run_dashboard.jl custom`

### For Production/Demo:
1. **Basic simulation**: `run_dashboard.jl main`
2. **Comprehensive analysis**: `run_dashboard.jl custom`
3. **Population studies**: `run_dashboard.jl reproduction`

## 🔧 Prerequisites

### Required Environment Variables:
- `OPENAI_API_KEY`: Required for LLM-enabled scripts
- Recommend using `.env` file for configuration

### Required Dependencies:
- `GLMakie`: For visualization
- `Revise`: For hot-reloading (development scripts)
- `BenchmarkTools`: For performance testing
- `JSON`: For LLM integration
- `Agents.jl`: Core ABM framework
- `DataFrames`, `CSV`, `Statistics`, `Plots`: For analytics

## 📊 Script Categories

| Category | Current Scripts | Purpose |
|----------|----------------|---------|
| **Unified Access** | `run_sugarscape.jl` | Main launcher with interactive menu |
| **Dashboards** | `run_dashboard.jl` | Unified dashboard launcher |
| **Analytics** | `run_analytics.jl` | Research and data analysis |
| **Advanced LLM** | `enhanced_dashboard.jl` | Advanced LLM visualization |
| **Archived** | `archive/*.jl` | Legacy scripts for reference |

## 🚀 Common Command Patterns

```bash
# Quick start with unified launcher
julia --project=. scripts/run_sugarscape.jl

# Direct dashboard access
julia --project=. scripts/run_dashboard.jl main
julia --project=. scripts/run_dashboard.jl custom
julia --project=. scripts/run_dashboard.jl reproduction

# Analytics pipeline
julia --project=. scripts/run_analytics.jl

# Advanced LLM visualization
julia --project=. scripts/enhanced_dashboard.jl
```

## 📚 Documentation

- **Visualization Options**: `docs/visualisation_audit.md`
- **Launcher Migration**: `docs/launcher_consolidation_guide.md`
- **Development Guide**: `docs/DEVELOPMENT.md`
- **Enhanced Dashboard**: `docs/ENHANCED_DASHBOARD.md`
- **Hot Reload Guide**: `docs/HOT_RELOAD_GUIDE.md`

## 🆘 Help

Having issues? The unified launcher includes:
- Environment validation
- Dependency checking
- Setup assistance
- Documentation access

Run the launcher and choose Option 9 (Environment Setup) or Option 10 (Documentation).

---

*Note: This documentation reflects the current unified launcher architecture. Legacy scripts in the archive directory are maintained for reference but are no longer the primary interface.*
