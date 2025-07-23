#!/usr/bin/env julia

"""
Test script for the LLM retry wrapper functionality.
This tests the safe_llm_call function with mock failures.
"""

using Test
include("../src/utils/llm_integration.jl")
using Sugarscape
using .SugarscapeLLM

# Mock function that fails a certain number of times before succeeding
mutable struct MockAPICall
    fail_count::Int
    current_attempts::Int
    success_result::Any

    MockAPICall(fail_count, success_result) = new(fail_count, 0, success_result)
end

function (mock::MockAPICall)(args...)
    mock.current_attempts += 1

    if mock.current_attempts <= mock.fail_count
        # Simulate different types of errors
        if mock.current_attempts == 1
            error("HTTP 520 Server Error")
        elseif mock.current_attempts == 2
            error("HTTP 502 Bad Gateway")
        else
            error("Connection timeout")
        end
    else
        return mock.success_result
    end
end

@testset "LLM Retry Wrapper Tests" begin

    @testset "Successful call on first attempt" begin
        mock = MockAPICall(0, "success")
        result = SugarscapeLLM.safe_llm_call(mock, "test_arg")
        @test result == "success"
        @test mock.current_attempts == 1
    end

    @testset "Success after retries" begin
        mock = MockAPICall(2, "success_after_retries")
        result = SugarscapeLLM.safe_llm_call(mock, "test_arg")
        @test result == "success_after_retries"
        @test mock.current_attempts == 3
    end

    @testset "Failure after max retries" begin
        mock = MockAPICall(5, "never_reached")  # Fail more times than default retries
        @test_throws Exception SugarscapeLLM.safe_llm_call(mock, "test_arg")
        @test mock.current_attempts == 3  # Should stop after 3 attempts (default)
    end

    @testset "Custom retry count" begin
        mock = MockAPICall(4, "success_with_custom_retries")
        result = SugarscapeLLM.safe_llm_call(mock, "test_arg"; retries=5)
        @test result == "success_with_custom_retries"
        @test mock.current_attempts == 5
    end

    @testset "Non-retryable error" begin
        function failing_func(args...)
            error("Invalid API key")  # This shouldn't trigger retry
        end

        @test_throws Exception SugarscapeLLM.safe_llm_call(failing_func, "test_arg")
    end

end

println("Running LLM retry wrapper tests...")
# Note: Uncomment the line below to run the tests
# This is commented to avoid running during include
# runtests()
