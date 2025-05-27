using Agents

@agent struct SugarSeeker(GridAgent{2})
    vision::Int
    metabolic_rate::Int
    age::Int
    max_age::Int
    wealth::Float64
end
