# Revise.jl Hot-Reload Integration Guide

## Overview

The Sugarscape LLM development environment includes robust hot-reload functionality via [Revise.jl](https://github.com/timholy/Revise.jl), enabling rapid iteration on LLM integration code without restarting Julia or losing simulation state.

## How Hot-Reload Works

### 1. Automatic File Watching
- Revise.jl automatically monitors all loaded Julia files for changes
- When you save a file, changes are detected within seconds
- Function definitions, method changes, and new exports are picked up automatically

### 2. Development Dashboard Integration
- The development dashboard (`scripts/dev_dashboard.jl`) loads Revise.jl at startup
- The "Reset" button triggers both `Revise.revise()` and model recreation
- Visual indicators show LLM-driven agent decisions in real-time

### 3. Supported Changes
✅ **Automatically detected:**
- Function definition changes
- Method modifications
- Constant value updates
- Documentation string changes

⚠️ **May require manual reload:**
- Struct definition changes
- Module-level const declarations
- Type annotations changes

❌ **Requires restart:**
- Package dependency changes
- Module structure reorganization

## Development Workflow

### Standard Workflow
1. **Start the development dashboard:**
   ```bash
   julia --project=. scripts/dev_dashboard.jl
   ```

2. **Edit LLM integration code:**
   - Open `src/utils/llm_integration.jl` in your editor
   - Make changes to prompts, validation logic, or error handling
   - Save the file

3. **Apply changes:**
   - Click "Reset" in the dashboard to reload and restart simulation
   - Or use parameter sliders to test different configurations
   - Changes should be visible immediately

4. **Observe results:**
   - Watch agent behavior in the visualization
   - Monitor console output for LLM decisions
   - Use visual indicators (colors/shapes) to see decision patterns

### Quick Testing Workflow
1. **Run hot-reload tests:**
   ```bash
   julia --project=. test/hot_reload_test.jl
   julia --project=. test/interactive_hot_reload_test.jl
   ```

2. **Manual verification:**
   - Edit a simple function in `src/utils/llm_integration.jl`
   - Add a `println("TEST CHANGE")` statement
   - Save and check if output appears

## Testing Hot-Reload Functionality

### Automated Tests
Run the provided test scripts to verify hot-reload infrastructure:

```bash
# Basic infrastructure check
julia --project=. test/hot_reload_test.jl

# Interactive modification test
julia --project=. test/interactive_hot_reload_test.jl
```

### Manual Testing Procedure

1. **Setup test environment:**
   ```julia
   using Revise
   using Sugarscape

   model = Sugarscape.sugarscape(N=5, dims=(10,10))
   model.use_llm_decisions = true
   model.llm_api_key = "test-key"
   ```

2. **Test function modification:**
   - Edit `format_llm_error()` function in `src/utils/llm_integration.jl`
   - Add a comment or change error message format
   - Save the file

3. **Verify change detection:**
   ```julia
   Revise.revise()  # Force immediate reload

   # Test the function
   error = Sugarscape.SugarscapeLLM.LLMValidationError("Test", "field", "value", 1)
   output = Sugarscape.SugarscapeLLM.format_llm_error(error)
   println(output)  # Should show your changes
   ```

4. **Test dashboard integration:**
   - Start the dashboard
   - Make a change to LLM prompt logic
   - Click "Reset" and observe agent behavior changes

### Common Test Modifications

#### 1. Error Message Testing
Add debug information to error formatting:
```julia
function format_llm_error(e::Exception)
  println("DEBUG: Formatting error at $(now())")  # Add this line
  # ... rest of function
end
```

#### 2. Prompt Modification Testing
Modify the system prompt in `call_openai_api()`:
```julia
system_prompt = """
[DEBUG] This is a test modification - $(rand())

You are an AI controlling agents...
"""
```

#### 3. Validation Logic Testing
Add debug output to validation functions:
```julia
function _strict_parse_decision(obj, agent_id)
  println("VALIDATION: Processing agent $agent_id")  # Add this line
  # ... rest of function
end
```

## Best Practices

### 1. Development Setup
- Always start with `using Revise` before loading other packages
- Use the development dashboard for visual feedback
- Keep file changes small and focused for easier debugging

### 2. Code Organization
- Make changes to one function at a time
- Test changes immediately after saving
- Use descriptive commit messages for tracking working versions

### 3. Troubleshooting
- If changes aren't detected, manually run `Revise.revise()`
- Check that files are being watched: `Revise.watched_files`
- Restart Julia if struct definitions change
- Use `@info` or `println()` for debugging visibility

### 4. Performance Considerations
- Revise adds minimal overhead to development
- File watching is efficient and low-impact
- Large files may take slightly longer to reload

## Common Issues and Solutions

### Issue: Changes Not Detected
**Symptoms:** Edits to files don't affect behavior
**Solutions:**
1. Manually run `Revise.revise()`
2. Check if file is in watch list: `keys(Revise.watched_files)`
3. Ensure file was actually saved
4. Restart if struct definitions changed

### Issue: Dashboard Not Updating
**Symptoms:** Visual changes don't appear after file edits
**Solutions:**
1. Click "Reset" button to recreate model
2. Use parameter sliders to trigger updates
3. Check console for error messages
4. Verify LLM integration is enabled

### Issue: Function Errors After Reload
**Symptoms:** Functions work before but fail after reload
**Solutions:**
1. Check for syntax errors in modified code
2. Ensure all required variables are defined
3. Verify function signatures haven't changed incompatibly
4. Check for missing imports or using statements

### Issue: Slow Reload Performance
**Symptoms:** Changes take long time to appear
**Solutions:**
1. Reduce file size by splitting large functions
2. Minimize global state modifications
3. Use `@code_warntype` to check for type instabilities
4. Consider precompilation for large modules

## Advanced Usage

### Custom Reload Triggers
Create custom functions to reload specific components:
```julia
function reload_llm_integration()
    Revise.revise()
    # Additional custom reload logic
    println("LLM integration reloaded")
end
```

### Conditional Development Code
Use environment variables for development-only features:
```julia
if get(ENV, "SUGARSCAPE_DEBUG", "false") == "true"
    println("DEBUG: LLM decision processing...")
end
```

### Performance Monitoring
Track reload performance:
```julia
function timed_reload()
    t = @elapsed Revise.revise()
    println("Reload completed in $(t) seconds")
end
```

## Integration with Other Tools

### VS Code
- Install the Julia extension
- Use "Julia: Execute File in REPL" for hot-reload testing
- Configure auto-save for immediate change detection

### Vim/Neovim
- Use `:w` to save and trigger reload
- Configure auto-commands for automatic reloading
- Use terminal split for dashboard viewing

### Emacs
- Configure julia-mode for seamless integration
- Use `C-c C-c` for evaluation with reload
- Set up auto-save for immediate feedback

## Testing Checklist

Before considering hot-reload functionality complete, verify:

- [ ] Revise.jl loads without errors
- [ ] LLM integration files are watched
- [ ] Manual `Revise.revise()` works
- [ ] Dashboard "Reset" button triggers reload
- [ ] Function modifications are detected
- [ ] Changes appear in simulation behavior
- [ ] Error handling modifications work
- [ ] Prompt changes are applied
- [ ] File restoration works properly
- [ ] No performance degradation during development

## Success Criteria

Hot-reload integration is successful when:

1. **Immediate feedback:** Changes to LLM code are visible within seconds
2. **No restart required:** Development continues without Julia restart
3. **Visual confirmation:** Dashboard shows updated agent behavior
4. **Error handling:** Invalid changes are caught and reported clearly
5. **Development speed:** Iteration cycle is under 10 seconds from edit to test

This hot-reload infrastructure transforms LLM prompt development from a slow, restart-heavy process into a fluid, interactive development experience.
