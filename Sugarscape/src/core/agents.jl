using Agents

struct Loan
    agent_id::Int
    amount::Float64
    time_due::Int
    interest_rate::Float64
end

@agent struct SugarscapeAgent(GridAgent{2})
    vision::Int
    metabolism::Int
    sugar::Float64
    age::Int
    max_age::Int
    sex::Symbol
    has_reproduced::Bool
    has_spread_culture::Bool
    has_accepted_culture::Bool
    initial_sugar::Float64
    children::Vector{Int}
    total_inheritance_received::Float64
    culture::BitVector
    loans_given::Dict{Int,Vector{Loan}}
    loans_owed::Dict{Int,Vector{Loan}}
    diseases::Vector{BitVector}
    immunity::BitVector
    last_partner_id::Vector{Int}
    last_credit_partner::Vector{Int}
    chose_not_to_attack::Bool
    chose_not_to_borrow::Bool
    chose_not_to_lend::Bool
    chose_not_to_reproduce::Bool
    chose_not_to_spread_culture::Bool
end
