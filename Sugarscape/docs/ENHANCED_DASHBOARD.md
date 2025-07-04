# Enhanced LLM Decision Visualization Dashboard

## Overview

The Enhanced LLM Decision Visualization Dashboard is an advanced development tool that provides comprehensive visual feedback for LLM-driven agent decisions in the Sugarscape simulation. It transforms abstract decision-making processes into intuitive visual representations, enabling rapid iteration and debugging of LLM prompts.

## Features

### 🎨 **Visual Decision Types**
- **5 distinct decision categories** with unique colors and markers
- **Real-time decision distribution** analytics
- **Historical movement trails** with fading effects
- **Interactive parameter controls** for testing different configurations

### 📊 **Advanced Analytics**
- **Decision distribution bar chart** with percentages
- **Real-time statistics** for each decision type
- **Movement pattern analysis** through visual trails
- **Wealth-based agent sizing** for additional context

### 🔧 **Development Integration**
- **Hot-reload support** with Revise.jl
- **Interactive parameter tuning** via sliders
- **Comprehensive visual legend**
- **Development workflow guidance**

## Installation & Setup

### Prerequisites
```bash
# Ensure you're in the correct directory
cd /path/to/Sugarscape_capstone/Sugarscape

# Install required packages (if not already installed)
julia --project=. -e 'using Pkg; Pkg.add.(["Revise", "GLMakie", "Statistics"])'
```

### Environment Configuration
```bash
# Set up environment variables
export OPENAI_API_KEY="your-api-key-here"

# Or create .env file
cp .env.example .env
# Edit .env with your API key
```

## Usage

### Basic Launch
```bash
julia --project=. scripts/enhanced_dashboard.jl
```

### Interactive Launch
```julia
# From Julia REPL
julia> include("scripts/enhanced_dashboard.jl")
```

### Development Mode
```bash
# With hot-reload for development
julia --project=. -e 'using Revise; include("scripts/enhanced_dashboard.jl")'
```

## Visual Elements Guide

### Agent Visualization

#### Decision Type Colors
| Decision Type | Color | Marker | Description |
|---------------|-------|--------|-------------|
| **Combat** | Red | ⭐ Star | Agent intends to engage in combat |
| **Reproduction** | Magenta | ♥ Heart | Agent seeks reproduction partner |
| **Credit** | Gold | ♦ Diamond | Agent wants to lend/borrow |
| **Movement** | Blue | ▲ Triangle | Agent plans to move |
| **Idle** | Green | ● Circle | Agent stays in place |

#### Relationship Lines
| Line Type | Color | Style | Purpose |
|-----------|-------|-------|---------|
| **Combat Target** | Red | Solid | Links agent to combat target |
| **Credit Partner** | Gold | Dashed | Shows credit relationships |
| **Reproduction Partner** | Magenta | Dotted | Indicates reproduction pairs |
| **Movement Arrow** | Blue | Arrow | Shows intended movement direction |

#### Agent Sizing
- **Size**: Based on agent's sugar wealth
- **Enhanced Size**: LLM-controlled agents appear larger
- **Range**: 6-19 pixels (base) + 3 pixels (LLM bonus)

### Analytics Panel

#### Decision Distribution Chart
- **Real-time bar chart** showing count of each decision type
- **Percentage labels** for distribution analysis
- **Color-coded bars** matching agent colors
- **Auto-updating** with each simulation step

#### Movement Trails
- **Historical paths** showing agent movement over time
- **Fading effect** (older positions more transparent)
- **Configurable length** (default: 15 steps)
- **Gray coloring** to avoid visual clutter

## Dashboard Controls

### Interactive Elements
| Control | Function | Usage |
|---------|----------|--------|
| **Step** | Advance one simulation step | Single-click for precise control |
| **Run/Stop** | Continuous simulation | Toggle for real-time observation |
| **Reset** | Restart simulation | Applies code changes via Revise |
| **Parameter Sliders** | Adjust simulation settings | Real-time parameter testing |

### Parameter Controls
- **LLM Temperature**: 0.0 - 1.0 (creativity vs consistency)
- **Enable Combat**: Toggle combat mechanics
- **Enable Reproduction**: Toggle reproduction mechanics
- **Enable Credit**: Toggle credit/lending mechanics
- **Use LLM Decisions**: Switch between LLM and rule-based logic

## Development Workflow

### Hot-Reload Development
1. **Launch Dashboard**
   ```bash
   julia --project=. scripts/enhanced_dashboard.jl
   ```

2. **Edit LLM Code**
   - Open `src/utils/llm_integration.jl` in your editor
   - Modify prompts, logic, or parameters
   - Save the file

3. **Apply Changes**
   - Click "Reset" button in dashboard
   - Revise.jl automatically reloads modified code
   - New simulation starts with updated logic

4. **Observe Results**
   - Watch visual feedback for decision pattern changes
   - Use analytics panel to quantify differences
   - Adjust parameters via sliders for testing

### Debugging Workflow
1. **Identify Issues**
   - Look for unexpected colors/markers
   - Check decision distribution in analytics
   - Observe movement patterns and trails

2. **Analyze Patterns**
   - High combat (red) concentration = aggressive prompts
   - No movement (green dominance) = conservative prompts
   - Missing relationships = validation issues

3. **Iterate Solutions**
   - Adjust prompt language in `llm_integration.jl`
   - Test different temperature settings
   - Validate with parameter controls

## Advanced Features

### Decision History Tracking
```julia
# Access decision history programmatically
decision_history.agent_trails      # Movement trails by agent ID
decision_history.decision_counts   # Current decision distribution
decision_history.max_trail_length  # Configurable trail length
```

### Custom Analytics
```julia
# Create custom analysis functions
function analyze_decision_patterns(history)
    # Custom pattern analysis
    combat_ratio = history.decision_counts[:combat] / sum(values(history.decision_counts))
    return combat_ratio > 0.3  # High combat threshold
end
```

### Performance Optimization
- **Efficient rendering**: Overlays cleared and redrawn only when needed
- **Trail management**: Automatic cleanup of old positions
- **Memory usage**: Bounded data structures prevent memory leaks

## Troubleshooting

### Common Issues

#### Dashboard Won't Launch
```bash
# Check environment
echo $OPENAI_API_KEY

# Verify dependencies
julia --project=. -e 'using Sugarscape, GLMakie, Revise'

# Check for Unicode issues
# Ensure terminal supports UTF-8
```

#### LLM Integration Errors
```
Error: "Agent X missing LLM decision when use_llm_decisions=true"
```
**Solution**:
- Check API key configuration
- Verify network connectivity
- Review LLM integration error handling

#### Visual Rendering Issues
```
Error: "Can't represent character with fallback font"
```
**Solution**:
- Update to latest GLMakie version
- Check system font configuration
- Use ASCII-only legend text

#### Performance Issues
```
Slow rendering or high memory usage
```
**Solution**:
- Reduce agent count (N parameter)
- Decrease trail length
- Close other resource-intensive applications

### Debug Mode
```julia
# Enable debug output
ENV["JULIA_DEBUG"] = "Sugarscape"
include("scripts/enhanced_dashboard.jl")
```

## Configuration Options

### Model Parameters
```julia
create_enhanced_dashboard(;
    use_llm_decisions = true,           # Enable LLM integration
    llm_api_key = "your-key",          # OpenAI API key
    llm_temperature = 0.2,             # LLM creativity (0.0-1.0)
    N = 40,                            # Number of agents
    dims = (25, 25),                   # Grid dimensions
    enable_combat = true,              # Combat mechanics
    enable_reproduction = true,        # Reproduction mechanics
    enable_credit = true               # Credit mechanics
)
```

### Visual Customization
```julia
# Modify decision history settings
decision_history = DecisionHistory(20)  # Longer trails

# Adjust figure size
figure = (; size=(1800, 1200))  # Larger dashboard
```

## API Reference

### Core Functions
- `create_enhanced_dashboard()`: Main dashboard creation
- `enhanced_agent_color()`: Agent color mapping
- `enhanced_agent_marker()`: Agent marker mapping
- `enhanced_agent_size()`: Agent size calculation
- `update_decision_history!()`: History tracking
- `add_movement_arrows!()`: Movement visualization
- `add_target_relationship_lines!()`: Relationship visualization

### Data Structures
- `DecisionHistory`: Tracks agent trails and statistics
- `decision_counts`: Real-time decision distribution
- `agent_trails`: Historical movement paths

## Best Practices

### Development
1. **Start Small**: Begin with low agent counts (N=20-40)
2. **Use Temperature 0.0**: For deterministic testing
3. **Monitor Performance**: Watch for memory/rendering issues
4. **Iterate Frequently**: Make small, focused changes

### Debugging
1. **Visual First**: Trust the visual feedback over logs
2. **Pattern Recognition**: Look for emergent behaviors
3. **Quantify Changes**: Use analytics panel for validation
4. **Parameter Testing**: Use sliders for quick experiments

### Performance
1. **Reasonable Limits**: Keep agent count under 100 for smooth interaction
2. **Trail Management**: Adjust trail length based on performance
3. **Resource Monitoring**: Close dashboard when not actively developing

## Contributing

### Adding New Visualizations
1. Create new visualization function in `enhanced_dashboard.jl`
2. Add to the `on(abmobs.model)` callback
3. Update legend and documentation
4. Test with various model configurations

### Extending Analytics
1. Add new fields to `DecisionHistory`
2. Update `update_decision_history!()` function
3. Create new analytics panels
4. Integrate with existing dashboard layout

---

## Quick Reference

### Launch Commands
```bash
# Basic launch
julia --project=. scripts/enhanced_dashboard.jl

# Development mode
julia --project=. -e 'using Revise; include("scripts/enhanced_dashboard.jl")'

# With custom parameters
julia --project=. -e 'include("scripts/enhanced_dashboard.jl"); create_enhanced_dashboard(N=20)'
```

### Visual Legend
- 🔴 **Red Stars**: Combat intent with target lines
- 🟣 **Magenta Hearts**: Reproduction intent with partner lines
- 🟡 **Gold Diamonds**: Credit intent with partner lines
- 🔵 **Blue Triangles**: Movement intent with direction arrows
- 🟢 **Green Circles**: Idle/stay intent

### Development Cycle
1. **Launch** → 2. **Edit** → 3. **Reset** → 4. **Observe** → 5. **Iterate**

---

*For additional support, refer to the main project documentation or the development guide in `docs/DEVELOPMENT.md`.*
