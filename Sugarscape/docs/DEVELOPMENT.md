# Sugarscape LLM Development Guide

## Quick Start

### 1. Initial Setup
```bash
cd Sugarscape_capstone/Sugarscape

# Development dependencies are already installed
# Set up environment variables
cp .env.example .env
# Edit .env with your OpenAI API key
```

### 2. Development Workflows

#### Prompt Iteration
1. Start CLI testing: `julia --project=. scripts/dev_llm_prompt.jl`
2. Edit prompt in `src/utils/llm_integration.jl`
3. Re-run CLI test to see changes

#### Visual Testing
1. Start dashboard: `julia --project=. scripts/dev_dashboard.jl`
2. Edit prompt code in separate editor
3. Use parameter sliders to test different configurations
4. Changes auto-reload via Revise.jl

#### Performance Testing
1. Run benchmarks: `julia --project=. scripts/dev_performance_test.jl`
2. Monitor performance across different model sizes
3. Compare LLM vs rule-based performance

### 3. Best Practices

#### Prompt Development
- Start with temperature=0.0 for reproducible testing
- Use small models (N<50) for rapid iteration
- Test edge cases with specific agent configurations
- Monitor API response quality and schema compliance

#### Performance Optimisation
- Benchmark regularly with different model sizes
- Monitor API usage and costs
- Profile memory usage for large simulations

#### Code Organisation
- Keep prompt changes in feature branches
- Document prompt changes and their effects
- Use consistent formatting for prompts
- Test with multiple agent configurations

### 4. Troubleshooting

#### Common Issues
- **API Key Not Found**: Check `.env` file and environment variables
- **Revise Not Working**: Restart Julia with `--project`
- **Performance Issues**: Use smaller models for testing
- **Schema Errors**: Check LLM response format in CLI test

#### Debugging Tips
- Use CLI test to inspect raw API responses
- Check dashboard for visual feedback
- Monitor console output for error messages

## Development Tools

### CLI Testing Harness
**File**: `scripts/dev_llm_prompt.jl`

Tests individual agent prompts with detailed output:
- Agent context sent to LLM
- Raw API response
- Parsed decision structure
- Error handling and validation

**Usage**: `julia --project=. scripts/dev_llm_prompt.jl`

### Development Dashboard
**File**: `scripts/dev_dashboard.jl`

Interactive dashboard with LLM integration:
- Visual indicators for LLM decisions
- Parameter sliders for real-time testing
- Hot-reloading via Revise.jl
- Performance monitoring

**Usage**: `julia --project=. scripts/dev_dashboard.jl`

**Visual Indicators**:
- 🔴 Red agents: Combat intent (LLM)
- 🔵 Blue agents: Movement intent (LLM)
- 🟢 Green agents: Stay/other (LLM)
- ⭐ Star markers: Combat decisions
- ♦ Diamond markers: Movement decisions

### Performance Benchmarks
**File**: `scripts/dev_performance_test.jl`

Comprehensive performance testing:
- LLM integration benchmarks across model sizes
- Temperature setting performance analysis
- LLM vs rule-based comparison
- Memory usage profiling

**Usage**: `julia --project=. scripts/dev_performance_test.jl`

## LLM Integration Architecture

### Decision Flow
1. **Model Creation**: Initialize with `use_llm_decisions = true`
2. **Decision Population**: Call `populate_llm_decisions!()` before each step
3. **Agent Actions**: Agents use LLM decisions instead of rule-based logic
4. **Visual Feedback**: Dashboard shows LLM decision types

### Error Handling
- **Strict Mode**: When `use_llm_decisions = true`, any LLM failure raises immediate error
- **No Fallback**: System fails fast rather than silently using rule-based logic
- **Clear Messages**: Descriptive error messages for debugging

### Configuration Options
- `llm_api_key`: OpenAI API key
- `llm_temperature`: Creativity level (0.0-1.0)
- `llm_model`: Model to use (default: gpt-4o)
- `llm_max_tokens`: Maximum response length

## Development Workflows

### 1. Rapid Prompt Iteration
```bash
# Terminal 1: Start CLI tester
julia --project=. scripts/dev_llm_prompt.jl

# Terminal 2: Edit prompts
# Edit src/utils/llm_integration.jl
# Re-run CLI tester to see changes
```

### 2. Visual Development
```bash
# Start interactive dashboard
julia --project=. scripts/dev_dashboard.jl

# Edit prompts in separate editor
# Use parameter sliders to test configurations
# Changes auto-reload via Revise.jl
```

### 3. Performance Profiling
```bash
# Run comprehensive benchmarks
julia --project=. scripts/dev_performance_test.jl

# Monitor performance across different:
# - Model sizes (10x10, 20x20, 30x30)
# - Agent counts (25, 100, 225)
# - Temperature settings (0.0, 0.2, 0.5, 1.0)
```

## Testing Strategy

### Unit Testing
- Test individual prompt components
- Validate JSON schema compliance
- Test error handling paths

### Integration Testing
- Test full simulation workflows
- Validate visual feedback systems
- Test parameter interactions

### Performance Testing
- Benchmark different model sizes
- Profile memory usage
- Compare LLM vs rule-based performance

## Environment Configuration

### Required Environment Variables
```bash
# .env file
OPENAI_API_KEY=sk-your-api-key-here
LLM_MODEL=gpt-4o
LLM_TEMPERATURE=0.2
LLM_MAX_TOKENS=1000
```

### Development Dependencies
Already installed in main project:
- `Revise.jl` - Hot-reloading
- `BenchmarkTools.jl` - Performance testing
- `JSON.jl` - JSON parsing
- `GLMakie.jl` - Interactive visualisation

## Code Quality Guidelines

### Prompt Engineering
- Use clear, structured prompts
- Include context about agent state
- Specify exact JSON schema requirements
- Test with edge cases

### Error Handling
- Fail fast on LLM errors
- Provide descriptive error messages
- Log API responses for debugging
- Validate all JSON responses

### Performance Considerations
- Use temperature=0.0 for deterministic testing
- Monitor API costs during development
- Profile memory usage with large models
- Benchmark regularly during development

## Common Development Patterns

### Testing New Prompts
1. Start with CLI tester for rapid iteration
2. Use temperature=0.0 for reproducible results
3. Test with small models first (N<50)
4. Gradually increase complexity

### Visual Debugging
1. Use development dashboard for real-time feedback
2. Monitor agent colours and markers
3. Use parameter sliders to test configurations
4. Check console output for errors

### Performance Optimisation
1. Benchmark before making changes
2. Profile memory usage
3. Test with different model sizes
4. Compare LLM vs rule-based performance

## Success Criteria

The development environment is successful when:

1. **Hot Reloading**: Code changes apply immediately via Revise.jl
2. **Interactive Testing**: Prompt tweaks visible in real-time
3. **Strict Error Handling**: LLM failures raise immediate errors
4. **Clear Error Messages**: Descriptive failure information
5. **Schema Validation**: Automated detection of response errors
6. **Performance Monitoring**: Clear metrics for optimisation
7. **Visual Feedback**: Accurate dashboard displays
8. **CLI Tools**: Raw response inspection capabilities
9. **Comprehensive Testing**: Multiple validation approaches
10. **Fail-Fast Behaviour**: Immediate errors prevent false measurements

This development environment transforms LLM prompt development from a slow, expensive process into a fast, interactive, and reliable workflow.
