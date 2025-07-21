# Sugarscape Visualization Overview

## Overview
This document outlines the current visualization options available in the Sugarscape project, covering both launcher scripts and visualization components.

## Current Visualization Components

### `/src/visualisation/` Components

#### `dashboard.jl` - **Main Interactive Dashboard**
- **Purpose**: Feature-rich interactive dashboard with comprehensive rule controls
- **Shows**:
  - Agent grid with sugar heatmap
  - Agent state table (top 10 agents with detailed info)
  - Interactive parameter sliders for all rules
  - Real-time metrics (deaths, births, Gini coefficient, etc.)
  - Rule status display
  - Performance monitoring (steps/sec, memory usage)
  - CSV export functionality
- **Strengths**: Most comprehensive, production-ready dashboard
- **Use Case**: General research and analysis

#### `interactive.jl` - **Custom Dashboard Collection**
- **Purpose**: Specialized dashboards for specific scenarios
- **Functions**:
  - `create_custom_dashboard()`: Basic dashboard with deaths/Gini/wealth plots
  - `create_reproduction_dashboard()`: Population dynamics focused
- **Shows**:
  - Agent positions with sugar heatmap
  - Time series plots (deaths, births, population)
  - Wealth and age distributions
  - Gender-based agent colouring
- **Strengths**: Focused visualizations for specific research questions
- **Use Case**: Targeted analysis (e.g., population dynamics)

#### `plotting.jl` - **Basic Visualization Utilities**
- **Purpose**: Simple visualization function
- **Shows**: Basic agent plot with sugar heatmap
- **Strengths**: Lightweight, minimal dependencies
- **Use Case**: Quick visualization checks

#### `analytics.jl` - **Empty Placeholder**
- **Status**: No implementation (single empty line)
- **Potential**: Could house advanced analytics functions

#### `performance_test.jl` - **Performance Testing**
- **Purpose**: Benchmark LLM vs rule-based performance
- **Features**: Performance comparison across different model sizes
- **Best for**: Performance optimization

## Launcher Scripts

### Standard Sugarscape Dashboards

#### `run_dashboard.jl` - **Main Dashboard Launcher**
- **Target**: `dashboard.jl`
- **Purpose**: Launch the comprehensive interactive dashboard
- **Best for**: General research and rule exploration

#### `run_custom_dashboard.jl` - **Custom Dashboard Launcher**
- **Target**: `interactive.jl::create_custom_dashboard()`
- **Purpose**: Launch basic custom dashboard
- **Best for**: Simple analysis with basic metrics

#### `run_reproduction_dashboard.jl` - **Reproduction Dashboard Launcher**
- **Target**: `interactive.jl::create_reproduction_dashboard()`
- **Purpose**: Launch population dynamics dashboard
- **Best for**: Reproduction and demographics research

### LLM-Focused Dashboards

#### `ai_dashboard.jl` - **LLM Development Dashboard**
- **Purpose**: Development-focused dashboard with LLM integration
- **Features**:
  - Revise.jl hot-reloading
  - LLM decision visualization (combat/movement/stay)
  - Interactive parameter controls
  - Development workflow optimized
- **Shows**: Basic agent visualization with LLM decision indicators
- **Best for**: LLM development and debugging

#### `enhanced_dashboard.jl` - **Advanced LLM Visualization**
- **Purpose**: Comprehensive LLM decision analysis
- **Features**:
  - 5 distinct LLM decision types visualization
  - Movement direction arrows
  - Relationship lines (combat/credit/reproduction targets)
  - Decision history trails
  - Real-time decision analytics panel
  - Comprehensive legend system
- **Shows**: Detailed LLM decision patterns and relationships
- **Best for**: Advanced LLM analysis and research

### LLM Development Tools

#### `ai_prompt.jl` - **LLM Prompt Testing**
- **Purpose**: Test individual agent prompts
- **Features**: Single-agent context building and API testing
- **Best for**: LLM prompt development and debugging

#### `ai_performance_test.jl` - **LLM Performance Benchmarking**
- **Purpose**: Benchmark LLM vs rule-based performance
- **Features**: Performance comparison across different model sizes
- **Best for**: Performance optimization

#### `dev_start.jl` - **LLM Development Environment**
- **Purpose**: Unified entry point for LLM development
- **Features**: Interactive menu system, environment setup
- **Best for**: Development workflow management

## Current Strengths

1. **Comprehensive Coverage**: Multiple dashboard options for different use cases
2. **LLM Integration**: Sophisticated LLM visualization capabilities
3. **Interactive Controls**: Parameter sliders and real-time updates
4. **Data Export**: CSV export functionality
5. **Performance Monitoring**: Built-in performance tracking
6. **Development Tools**: Hot-reloading and debugging capabilities

## Current Gaps

1. **Empty Analytics**: `analytics.jl` is not implemented
2. **Limited Spatial Analysis**: No spatial pattern analysis tools
3. **No Batch Analysis**: No tools for running multiple scenarios
4. **Missing Comparison Tools**: No side-by-side model comparison
5. **No Statistical Analysis**: Limited statistical analysis beyond Gini coefficient
6. **No Network Analysis**: No agent relationship network visualizations
7. **No Time Series Analysis**: No advanced time series decomposition tools

## Recommendations

### High Priority
1. **Implement `analytics.jl`**: Add statistical analysis functions
2. **Create comparison dashboard**: Side-by-side model comparison
3. **Add spatial analysis tools**: Spatial autocorrelation, clustering analysis

### Medium Priority
1. **Batch analysis tools**: Multiple scenario runner with comparison
2. **Network visualization**: Agent relationship networks
3. **Advanced time series**: Trend analysis, seasonality detection

### Low Priority
1. **3D visualizations**: Height-based wealth visualization
2. **Animation export**: GIF/video export capabilities
3. **Custom colour schemes**: User-defined visualization themes

## Usage Guidelines

- **General Research**: Use `run_dashboard.jl` for comprehensive analysis
- **Population Studies**: Use `run_reproduction_dashboard.jl` for demographics
- **LLM Development**: Use `ai_dashboard.jl` for development, `enhanced_dashboard.jl` for analysis
- **Quick Checks**: Use `plotting.jl` functions for rapid visualization
- **Performance Analysis**: Use `ai_performance_test.jl` for optimization

## Potential Redundancies

- **LLM Launchers**: `ai_dashboard.jl` and `enhanced_dashboard.jl` have overlapping functionality
- **Custom Launchers**: Multiple similar launcher scripts could be consolidated
- **Basic Visualization**: `plotting.jl` functions could be integrated into main dashboards

## Consolidation Plan

### ✅ **IMPLEMENTED: Unified Launcher + Function-Based Architecture**
Created `run_sugarscape.jl` to consolidate 6 of 8 launcher scripts with organized function-based architecture:

**Launcher Consolidation:**
- **Replaces**: `run_dashboard.jl`, `run_custom_dashboard.jl`, `run_reproduction_dashboard.jl`, `ai_dashboard.jl`, `ai_prompt.jl`, `dev_start.jl`
- **Retains**: `enhanced_dashboard.jl` (advanced LLM analysis), `ai_performance_test.jl` (specialized benchmarking)
- **Benefits**: Single entry point, better discovery, reduced maintenance

**Function-Based Architecture:**
All visualization logic moved to `/src/visualisation/` with well-organized functions:
- `dashboard.jl` - Main comprehensive dashboard
- `interactive.jl` - Custom dashboards
- `llm_dashboards.jl` - LLM-specific visualizations (NEW)
- `testing.jl` - Testing utilities (NEW)
- `performance_test.jl` - Performance testing (IMPLEMENTED)
- `plotting.jl` - Foundation functions
- `analytics.jl` - Comprehensive data analysis and research pipeline

### Usage:
```bash
julia --project=. scripts/run_sugarscape.jl
# Interactive menu with all visualization options
```

See `docs/launcher_consolidation_guide.md` for full migration details.

## Conclusion

The project has a solid foundation of visualization tools covering basic research needs and advanced LLM analysis. With the new unified launcher, the tools are now better organized and easier to discover. The main gaps remain in analytical tools and comparison capabilities. The LLM visualization capabilities are particularly strong and represent a unique feature set.
