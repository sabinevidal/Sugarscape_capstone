# Sugarscape Source Code Documentation

## Directory Structure

### `/src/Sugarscape.jl`
Main module file that orchestrates all components and exports the public API.

### `/src/core/`
**Core simulation components:**

- **`agents.jl`** - Defines `SugarscapeAgent` struct with vision, metabolism, wealth, demographics, culture, loans, diseases, and inheritance tracking
- **`environment.jl`** - Environment dynamics including sugar growback (seasonal/standard), pollution diffusion, and welfare calculations
- **`model_logic.jl`** - Main simulation loop with agent/model stepping, movement rules, death/replacement, and **LLM integration hooks**

### `/src/extensions/`
**Modular rule extensions (all can be enabled/disabled):**

- **`combat.jl`** - Combat rule allowing agents to attack weaker, culturally different neighbours within vision
- **`credit.jl`** - Lending system where agents can borrow/lend sugar with interest
- **`culture.jl`** - Cultural transmission via bit-string tags, tribal classification, and cultural metrics
- **`disease.jl`** - Disease transmission through contact with immunity system and metabolic penalties
- **`inheritance.jl`** - Wealth inheritance from parents to children when agents die
- **`reproduction.jl`** - Sexual reproduction with genetic/cultural crossover and fertility constraints

### `/src/utils/`
**Utility functions:**

- **`llm_integration.jl`** - **Complete LLM decision-making system** with OpenAI API integration, strict validation, and agent context building
- **`metrics.jl`** - Statistical measures including Gini coefficient and Moran's I for spatial autocorrelation

### `/src/visualisation/`
**Visualization components:**

- **`performance_test.jl`** - **Performance testing and analysis** with LLM vs standard comparison, dashboard generation, and CSV export
- **`dashboard.jl`** - **Feature-rich interactive dashboard** with parameter controls, agent monitoring, CSV export, and performance metrics
- **`interactive.jl`** - Custom dashboards including reproduction-focused view with demographic tracking
- **`llm_dashboards.jl`** - **LLM-specific visualizations** including development dashboard with hot-reloading and enhanced visualization with decision trails
- **`plotting.jl`** - Basic visualization functions with heatmaps and step counters
- **`testing.jl`** - **Testing utilities** for single-agent LLM prompt testing and API response analysis

## Key Features

1. **Modular Design** - All rule extensions can be independently enabled/disabled
2. **LLM Integration** - Agents can use AI decision-making instead of standard rules
3. **Comprehensive Tracking** - Detailed inheritance, demographic, and cultural metrics
4. **Interactive Dashboards** - Real-time visualization with parameter adjustment
5. **Data Export** - CSV export functionality for analysis
6. **Performance Monitoring** - Built-in performance tracking and memory monitoring

## Notable Implementation Details

- Uses `GridSpaceSingle` for one-agent-per-cell constraint
- Supports both seasonal and standard sugar growback
- Combat rule extends movement rule (agents can't move twice)
- LLM integration includes strict validation and error handling
- Cultural inheritance uses bit-string crossover
- Disease system uses bit-vector matching for immunity
