module SugarscapeLLM

###############################################################################
# LLM integration scaffold                                                   #
#                                                                            #
# This file provides non-intrusive helper utilities for retrieving decisions #
# from an OpenAI-compatible endpoint and caching them on the Sugarscape      #
# `model`.                                                                   #
#                                                                            #
# Individual agent decision-making implementation.                           #
###############################################################################

using HTTP, JSON, Logging, OpenAI, Dates
using ..Agents: nearby_positions, nearby_agents, allagents, isempty, abmtime

# LLM Decision Logger functionality
"""
    log_decision!(model, agent_id, step, rule, decision::NamedTuple, reasoning)

Log a decision made by an LLM agent to a CSV file.

# Arguments
- `model`: The Sugarscape model
- `agent_id`: ID of the agent making the decision
- `step`: Current simulation step
- `rule`: The rule/decision type (e.g., "movement", "reproduction")
- `decision`: A NamedTuple containing the decision details
- `reasoning`: The LLM's reasoning for the decision
"""
function log_decision!(model, agent_id, step, rule, decision, reasoning)
    run_name = something(model.run_name, "fun_run")
    logdir = "data/logs/$(run_name)"
    mkpath(logdir)
    logfile = joinpath(logdir, "llm_decisions.csv")

    # Create CSV with headers if it doesn't exist
    if !isfile(logfile)
        open(logfile, "w") do io
            println(io, "step,agent_id,rule,decision,reasoning")
        end
    end

    # Append new decision
    open(logfile, "a") do io
        println(io, "$(step),$(agent_id),$(rule),$(JSON.json(decision)),\"$(replace(reasoning, '\n' => " "))\"")
    end
end

# Parent module alias for convenience
import ..Sugarscape

# Import prompts and schemas
using ..SugarscapePrompts
using ..Sugarscape

# Add time function for metrics
import Base: time

############################### Error Types ################################

"""
LLM integration error types for strict error handling when use_llm_decisions=true.
All errors should propagate up to stop the simulation for research integrity.
"""
struct LLMAPIError <: Exception
    message::String
    status_code::Union{Int,Nothing}
    response_body::Union{String,Nothing}
end

struct LLMSchemaError <: Exception
    message::String
    agent_id::Union{Int,Nothing}
    raw_response::Union{Any,Nothing}
end

struct LLMValidationError <: Exception
    message::String
    field::String
    value::Any
    agent_id::Union{Int,Nothing}
end

struct LLMResearchIntegrityError <: Exception
    message::String
    agent_id::Union{Int,Nothing}
    context::String
end

"""
    build_agent_context(agent, model) -> Dict
Collect a lightweight JSON-serialisable summary of the local state that the LLM
can use to decide on the agent's next actions.  The schema is intentionally kept
stable so tests that rely on it do not break when the runtime model evolves.
"""
function build_agent_context(agent, model)
    # Visible lattice positions with sugar (or welfare when pollution enabled)
    visible_positions = Vector{Any}()

    # Use the same nearby_positions logic as movement! to ensure consistency
    for (pos, value, distance) in Sugarscape.evaluate_nearby_positions(agent, model)
        push!(visible_positions, Dict(
            "position" => pos,
            "value" => value,
            "distance" => distance,
            "occupied" => !isempty(pos, model),
        ))
    end

    # Immediate neighbours (Moore radius 1)
    neighbours = Vector{Any}()
    for nb in nearby_agents(agent, model, 1)
        push!(neighbours, Dict(
            "id" => nb.id,
            "sugar" => nb.sugar,
            "age" => nb.age,
            "sex" => nb.sex,
        ))
    end

    return Dict(
        "agent_id" => agent.id,
        "position" => agent.pos,
        "sugar" => agent.sugar,
        "age" => agent.age,
        "metabolism" => agent.metabolism,
        "vision" => agent.vision,
        "sex" => agent.sex,
        "visible_positions" => visible_positions,
        "neighbours" => neighbours,
        # global toggles (supplied in case the model prompt needs them)
        "enable_combat" => model.enable_combat,
        "enable_reproduction" => model.enable_reproduction,
        "enable_credit" => model.enable_credit,
    )
end


##############################  API interaction  ##############################

"""
    safe_llm_call(api_call_func, args...; retries=5) -> Any
Retry wrapper for OpenAI API calls with exponential backoff.
Handles network connectivity issues, HTTP errors, and API rate limiting.

# Arguments
- `api_call_func`: Function to call (should be the actual OpenAI API call)
- `args...`: Arguments to pass to the API call function
- `retries`: Maximum number of retry attempts (default: 5)

# Returns
- Result of successful API call

# Throws
- Re-throws the last exception if all retries are exhausted

# Retryable Errors
- Network errors: EOFError, HTTP.Exceptions.RequestError, IOError, SystemError
- SSL/TLS errors: Certificate issues, handshake failures, SSL connection problems
- JSON parsing errors: Malformed API responses, parsing failures
- HTTP status codes: 408, 429, 502-504, 520-527, 530
- Connection issues: timeouts, resets, DNS failures, host unreachable
- System errors: Socket errors, temporary failures, service unavailable
"""
function safe_llm_call(api_call_func, args...; retries=10)
    delay = 20.0
    last_error = nothing

    for i in 1:retries
        try
            return api_call_func(args...)
        catch e
            last_error = e
            error_str = sprint(showerror, e)

            # Check for specific error conditions that warrant retry
            should_retry = (
                # Network/connection errors
                isa(e, EOFError) ||  # Connection terminated unexpectedly
                isa(e, HTTP.Exceptions.RequestError) ||  # HTTP request errors
                isa(e, Base.IOError) ||  # General IO errors
                isa(e, Base.SystemError) ||  # System-level errors (DNS, socket)
                isa(e, InterruptException) ||  # Process interruption
                isa(e, TaskFailedException) ||  # Async task failures                 # SSL/TLS errors
                isa(e, Base.IOError) && occursin("ssl", lowercase(error_str)) ||                 # HTTP client specific errors
                isa(e, HTTP.Exceptions.ConnectError) ||  # Connection establishment failed
                isa(e, HTTP.Exceptions.TimeoutError) ||  # Request timeout
                isa(e, HTTP.Exceptions.StatusError) ||  # HTTP status error responses                 # JSON parsing errors (malformed API responses)
                isa(e, JSON.ParserError) ||
                isa(e, ArgumentError) && occursin("json", lowercase(error_str)) ||                 # HTTP status codes that should be retried
                occursin("520", error_str) ||  # Server error
                occursin("521", error_str) ||  # Web server is down
                occursin("522", error_str) ||  # Connection timed out
                occursin("523", error_str) ||  # Origin is unreachable
                occursin("524", error_str) ||  # A timeout occurred
                occursin("525", error_str) ||  # SSL handshake failed
                occursin("526", error_str) ||  # Invalid SSL certificate
                occursin("527", error_str) ||  # Railgun error
                occursin("530", error_str) ||  # Origin DNS error
                occursin("502", error_str) ||  # Bad gateway
                occursin("503", error_str) ||  # Service unavailable
                occursin("504", error_str) ||  # Gateway timeout
                occursin("429", error_str) ||  # Rate limit
                occursin("408", error_str) ||  # Request timeout                 # String patterns for various network/API issues
                occursin("timeout", lowercase(error_str)) ||
                occursin("connection", lowercase(error_str)) ||
                occursin("eof", lowercase(error_str)) ||
                occursin("read end of file", lowercase(error_str)) ||
                occursin("connection reset", lowercase(error_str)) ||
                occursin("connection refused", lowercase(error_str)) ||
                occursin("network", lowercase(error_str)) ||
                occursin("dns", lowercase(error_str)) ||
                occursin("ssl", lowercase(error_str)) ||
                occursin("tls", lowercase(error_str)) ||
                occursin("certificate", lowercase(error_str)) ||
                occursin("handshake", lowercase(error_str)) ||
                occursin("socket", lowercase(error_str)) ||
                occursin("host", lowercase(error_str)) ||
                occursin("unreachable", lowercase(error_str)) ||
                occursin("temporary failure", lowercase(error_str)) ||
                occursin("service unavailable", lowercase(error_str)) ||
                occursin("server error", lowercase(error_str)) ||                 # OpenAI API specific errors that should be retried
                occursin("rate limit", lowercase(error_str)) ||
                occursin("quota exceeded", lowercase(error_str)) ||
                occursin("overloaded", lowercase(error_str)) ||
                occursin("temporarily unavailable", lowercase(error_str)) ||
                occursin("internal error", lowercase(error_str))
            )

            if should_retry && i < retries
                @warn "OpenAI API error (attempt $i/$retries). Retrying in $(delay) seconds..." exception = e
                sleep(delay)
                delay *= 2  # Exponential backoff
            else
                # Either not a retryable error or we've exhausted retries
                if i == retries
                    @error "OpenAI API call failed after $retries attempts" exception = e
                end
                rethrow(e)
            end
        end
    end

    # This should never be reached, but just in case
    throw(last_error)
end

"""
    call_openai_api_individual(context::Dict, model) -> Dict
Low-level wrapper around the OpenAI Chat Completion endpoint for individual agent requests.
Uses the individual response format and schema for single agent decisions.
"""
# Helper function for the actual OpenAI API call (to be wrapped with retry logic)
function _make_openai_call(api_key, llm_model, messages, temperature, response_format, metadata)
    response = OpenAI.create_chat(
        api_key,
        llm_model,
        messages;
        temperature=temperature,
        response_format=response_format,
        metadata=metadata,
    )
    return response.response
end

function call_openai_api(context::Dict, rule::String, model, rule_prompt, response_format)
    if isempty(model.llm_api_key)
        throw(LLMAPIError("LLM API key is empty but use_llm_decisions=true", nothing, nothing))
    end

    system_prompt = if model.use_big_five
        big5_prompt = Sugarscape.get_big_five_system_prompt()
        Dict("content" => big5_prompt["content"] * rule_prompt, "name" => big5_prompt["name"])
    elseif model.use_schwartz_values
        schwartz_values_prompt = Sugarscape.get_schwartz_values_system_prompt()
        Dict("content" => schwartz_values_prompt["content"] * rule_prompt, "name" => schwartz_values_prompt["name"])
    else
        std_prompt = SugarscapePrompts.get_system_prompt()
        Dict("content" => std_prompt["content"] * rule_prompt, "name" => std_prompt["name"])
    end
    user_prompt = Dict("content" => "Agent $(context["agent_id"]) context:\n" * JSON.json(context), "name" => rule)

    messages = [
        Dict("role" => "system", "content" => system_prompt["content"], "name" => system_prompt["name"]),
        Dict("role" => "user", "content" => user_prompt["content"], "name" => user_prompt["name"]),
    ]

    local j
    try
        # Use the retry wrapper for the OpenAI API call
        j = safe_llm_call(
            _make_openai_call,
            model.llm_api_key,
            model.llm_model,
            messages,
            model.llm_temperature,
            response_format,
            model.llm_metadata
        )
    catch err
        throw(LLMAPIError("Failed to call OpenAI API: $(err)", nothing, nothing))
    end

    # Validate response structure
    if !haskey(j, "choices") || isempty(j["choices"])
        throw(LLMAPIError("OpenAI API response missing 'choices' field or choices empty",
            nothing, String(j)))
    end

    if !haskey(j["choices"][1], "message") || !haskey(j["choices"][1]["message"], "content")
        throw(LLMAPIError("OpenAI API response missing message content",
            nothing, String(j)))
    end

    content = j["choices"][1]["message"]["content"]

    local parsed_content
    try
        parsed_content = JSON.parse(content)
    catch err
        throw(LLMSchemaError("Failed to parse LLM response content as JSON: $(err)",
            context["agent_id"], content))
    end

    # For individual requests, the response should be a single decision object
    if !isa(parsed_content, Dict)
        throw(LLMSchemaError("LLM response is not a dictionary", context["agent_id"], parsed_content))
    end

    return parsed_content
end




"""
    _safe_parse_decision(obj) -> LLMDecision
Convert a JSON object into an `LLMDecision`, inserting safe defaults for missing
fields. Use this for backwards compatibility when use_llm_decisions=false.
"""
function _safe_parse_decision(obj)
    # fallbacks make the field optional in the reply
    move = get(obj, "move", false)
    move_coords = get(obj, "move_coords", nothing)
    combat = get(obj, "combat", false)
    combat_target = get(obj, "combat_target", nothing)
    credit = get(obj, "credit", false)
    credit_partner = get(obj, "credit_partner", nothing)
    reproduce = get(obj, "reproduce", false)
    reproduce_with = get(obj, "reproduce_with", nothing)

    # normalise `null` to `nothing`
    if move_coords === nothing
        move_coords = nothing
    end
    if combat_target === nothing
        combat_target = nothing
    end
    if credit_partner === nothing
        credit_partner = nothing
    end
    if reproduce_with === nothing
        reproduce_with = nothing
    end

    return (move=move, move_coords=move_coords, combat=combat, combat_target=combat_target,
        credit=credit, credit_partner=credit_partner, reproduce=reproduce, reproduce_with=reproduce_with)
end



########################### Movement helpers ############################
function _parse_movement_decision(obj)
    move = get(obj, "move", false)
    move_coords = get(obj, "move_coords", nothing)
    reasoning = get(obj, "reasoning_for_choice", nothing)

    # Convert vector to tuple if present
    if move_coords !== nothing && isa(move_coords, Vector) && length(move_coords) == 2 && all(isa(x, Number) for x in move_coords)
        move_coords = (Int(move_coords[1]), Int(move_coords[2]))
    end

    return (move=move, move_coords=move_coords, reasoning=reasoning)
end

function get_movement_decision(context::Dict, model)
    movement_response_format = SugarscapePrompts.get_movement_response_format()
    if model.use_big_five
        movement_prompt = get_big_five_movement_system_prompt()
    elseif model.use_schwartz_values
        movement_prompt = get_schwartz_values_movement_system_prompt()
    else
        movement_prompt = SugarscapePrompts.get_movement_system_prompt()
    end
    try
        raw_response = call_openai_api(context, "movement", model, movement_prompt, movement_response_format)
        decision = _parse_movement_decision(raw_response)
        log_decision!(model, context["agent_id"], abmtime(model), "movement", decision.move_coords, decision.reasoning)
        return decision
    catch e
        throw(LLMAPIError("Failed to get movement decision: $(e)", nothing, nothing))
    end
end

########################### Reproduction helpers ############################
function _parse_reproduction_decision(obj)
    reproduce = get(obj, "reproduce", false)
    partners = get(obj, "partners", nothing)
    reasoning = get(obj, "reasoning_for_choice", nothing)

    return (reproduce=reproduce, partners=partners, reasoning=reasoning)
end

function get_reproduction_decision(context::Dict, model)
    reproduction_response_format = SugarscapePrompts.get_reproduction_response_format(context["max_partners"])
    if model.use_big_five
        reproduction_prompt = get_big_five_reproduction_system_prompt()
    elseif model.use_schwartz_values
        reproduction_prompt = get_schwartz_values_reproduction_system_prompt()
    else
        reproduction_prompt = SugarscapePrompts.get_reproduction_system_prompt()
    end
    try
        raw_response = call_openai_api(context, "reproduction", model, reproduction_prompt, reproduction_response_format)
        decision = _parse_reproduction_decision(raw_response)
        log_decision!(model, context["agent_id"], abmtime(model), "reproduction", decision.partners, decision.reasoning)
        return decision
    catch e
        throw(LLMAPIError("Failed to get reproduction decision: $(e)", nothing, nothing))
    end
end

########################### Culture helpers ############################
function _parse_culture_decision(obj)
    # Culture decisions are expected to be a dictionary with culture tags
    spread_culture = get(obj, "spread_culture", false)
    transmit_to = get(obj, "transmit_to", nothing)
    reasoning = get(obj, "reasoning_for_choice", nothing)

    return (spread_culture=spread_culture, transmit_to=transmit_to, reasoning=reasoning)
end

function get_culture_decision(context::Dict, model)
    culture_response_format = SugarscapePrompts.get_culture_response_format()
    if model.use_big_five
        culture_prompt = get_big_five_culture_system_prompt()
    elseif model.use_schwartz_values
        culture_prompt = SchwartzValues.get_schwartz_values_culture_system_prompt()
    else
        culture_prompt = SugarscapePrompts.get_culture_system_prompt()
    end
    try
        raw_response = call_openai_api(context, "culture", model, culture_prompt, culture_response_format)
        decision = _parse_culture_decision(raw_response)
        log_decision!(model, context["agent_id"], abmtime(model), "culture", decision.transmit_to, decision.reasoning)
        return decision
    catch e
        throw(LLMAPIError("Failed to get culture decision: $(e)", nothing, nothing))
    end
end

########################### Combat helpers ############################
function _parse_combat_decision(obj)
    combat = get(obj, "combat", false)
    target = get(obj, "combat_target", nothing)
    reasoning = get(obj, "reasoning_for_choice", nothing)
    return (combat=combat, combat_target=target, reasoning=reasoning)
end

function get_combat_decision(context::Dict, model)
    combat_response_format = SugarscapePrompts.get_combat_response_format()
    combat_prompt = SugarscapePrompts.get_combat_system_prompt()
    try
        raw_response = call_openai_api(context, "combat", model, combat_prompt, combat_response_format)
        decision = _parse_combat_decision(raw_response)
        log_decision!(model, context["agent_id"], abmtime(model), "combat", decision.target, decision.reasoning)
        return decision
    catch e
        throw(LLMAPIError("Failed to get combat decision: $(e)", nothing, nothing))
    end
end


########################### Credit helpers ############################
"""
    _parse_credit_lender_decision(obj) -> (lend, lend_to)
Parser for credit lending decisions from LLM.
"""
function _parse_credit_lender_decision(obj)
    lend = get(obj, "lend", false)
    lend_to = get(obj, "lend_to", nothing)
    reasoning = get(obj, "reasoning_for_choice", nothing)
    return (lend=lend, lend_to=lend_to, reasoning=reasoning)
end

"""
    _parse_credit_borrower_decision(obj) -> (borrow, borrow_from)
Parser for credit borrowing decisions from LLM.
"""
function _parse_credit_borrower_decision(obj)
    borrow = get(obj, "borrow", false)
    borrow_from = get(obj, "borrow_from", nothing)
    reasoning = get(obj, "reasoning_for_choice", nothing)
    return (borrow=borrow, borrow_from=borrow_from, reasoning=reasoning)
end

"""
    get_credit_lender_offer_decision(context::Dict, model)
LLM integration for credit lending decisions.
"""
function get_credit_lender_offer_decision(context::Dict, model)
    credit_response_format = SugarscapePrompts.get_credit_lender_response_format()

    if model.use_big_five
        credit_prompt = SchwartzValues.get_big_five_credit_lender_offer_system_prompt()
    else
        credit_prompt = SugarscapePrompts.get_credit_lender_system_prompt()
    end
    try
        raw_response = call_openai_api(context, "credit_lender", model, credit_prompt, credit_response_format)
        decision = _parse_credit_lender_decision(raw_response)
        log_decision!(model, context["agent_id"], abmtime(model), "credit_lender_offer", decision.lend_to, decision.reasoning)
        return decision
    catch e
        throw(LLMAPIError("Failed to get credit lender decision: $(e)", nothing, nothing))
    end
end

"""
    get_credit_borrower_respond_decision(context::Dict, model)
LLM integration for credit borrowing decisions.
"""
function get_credit_borrower_respond_decision(context::Dict, model)
    credit_response_format = SugarscapePrompts.get_credit_borrower_response_format()

    if model.use_big_five
        credit_prompt = SchwartzValues.get_big_five_credit_borrower_respond_system_prompt()
    elseif model.use_schwartz_values
        credit_prompt = SchwartzValues.get_schwartz_values_credit_borrower_respond_system_prompt()
    else
        credit_prompt = SugarscapePrompts.get_credit_borrower_system_prompt()
    end
    try
        raw_response = call_openai_api(context, "credit_borrower", model, credit_prompt, credit_response_format)
        decision = _parse_credit_borrower_decision(raw_response)
        log_decision!(model, context["agent_id"], abmtime(model), "credit_borrower_respond", decision.borrow_from, decision.reasoning)
        return decision
    catch e
        throw(LLMAPIError("Failed to get credit borrower decision: $(e)", nothing, nothing))
    end
end

"""
    get_credit_lender_respond_decision(context::Dict, model)
LLM integration for credit lending decisions.
"""
function get_credit_lender_respond_decision(context::Dict, model)
    credit_response_format = SugarscapePrompts.get_credit_lender_response_format()

    if model.use_big_five
        credit_prompt = SchwartzValues.get_big_five_credit_lender_respond_system_prompt()
    elseif model.use_schwartz_values
        credit_prompt = SchwartzValues.get_schwartz_values_credit_lender_respond_system_prompt()
    else
        credit_prompt = SugarscapePrompts.get_credit_lender_system_prompt()
    end
    try
        raw_response = call_openai_api(context, "credit_lender", model, credit_prompt, credit_response_format)
        decision = _parse_credit_lender_decision(raw_response)
        log_decision!(model, context["agent_id"], abmtime(model), "credit_lender_respond", decision.lend_to, decision.reasoning)
        return decision
    catch e
        throw(LLMAPIError("Failed to get credit lender decision: $(e)", nothing, nothing))
    end
end

"""
    get_credit_borrower_request_decision(context::Dict, model)
LLM integration for credit borrowing decisions.
"""
function get_credit_borrower_request_decision(context::Dict, model)
    credit_response_format = SugarscapePrompts.get_credit_borrower_response_format()

    if model.use_big_five
        credit_prompt = SchwartzValues.get_big_five_credit_borrower_request_system_prompt()
    elseif model.use_schwartz_values
        credit_prompt = SchwartzValues.get_schwartz_values_credit_borrower_request_system_prompt()
    else
        credit_prompt = SugarscapePrompts.get_credit_borrower_system_prompt()
    end
    try
        raw_response = call_openai_api(context, "credit_borrower", model, credit_prompt, credit_response_format)
        decision = _parse_credit_borrower_decision(raw_response)
        log_decision!(model, context["agent_id"], abmtime(model), "credit_borrower_request", decision.borrow_from, decision.reasoning)
        return decision
    catch e
        throw(LLMAPIError("Failed to get credit borrower decision: $(e)", nothing, nothing))
    end
end

########################### Error Message Helpers ############################

"""
    format_llm_error(e::Exception) -> String
Format LLM integration errors with helpful debugging information.
"""
function format_llm_error(e::Exception)
    if isa(e, LLMAPIError)
        msg = "LLM API Error: $(e.message)"
        if e.status_code !== nothing
            msg *= "\nHTTP Status: $(e.status_code)"
        end
        if e.response_body !== nothing
            # Truncate long responses
            body = length(e.response_body) > 500 ? e.response_body[1:500] * "..." : e.response_body
            msg *= "\nResponse Body: $(body)"
        end
        return msg
    elseif isa(e, LLMSchemaError)
        msg = "LLM Schema Error: $(e.message)"
        if e.agent_id !== nothing
            msg *= "\nAgent ID: $(e.agent_id)"
        end
        if e.raw_response !== nothing
            msg *= "\nRaw Response: $(e.raw_response)"
        end
        return msg
    elseif isa(e, LLMValidationError)
        msg = "LLM Validation Error: $(e.message)"
        if e.agent_id !== nothing
            msg *= "\nAgent ID: $(e.agent_id)"
        end
        msg *= "\nField: $(e.field)"
        msg *= "\nInvalid Value: $(e.value)"
        return msg
    elseif isa(e, LLMResearchIntegrityError)
        msg = "LLM Research Integrity Error: $(e.message)"
        if e.agent_id !== nothing
            msg *= "\nAgent ID: $(e.agent_id)"
        end
        msg *= "\nContext: $(e.context)"
        return msg
    else
        return "Unexpected error: $(e)"
    end
end

end # module SugarscapeLLM
