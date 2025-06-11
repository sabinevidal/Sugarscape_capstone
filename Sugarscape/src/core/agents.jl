using Agents

@agent struct SugarscapeAgent(GridAgent{2})
    vision::Int
    metabolism::Int
    sugar::Float64
    age::Int
    max_age::Int
    sex::Symbol
    has_mated::Bool
    initial_sugar::Float64
    children::Vector{Int}  # IDs of child agents
    total_inheritance_received::Float64  # Track total inheritance received
    culture::BitVector  # Cultural tag
end
