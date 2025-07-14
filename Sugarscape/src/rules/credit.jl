using Agents

"""
build_credit_context(agent, model) -> Dict
Placeholder context builder for Credit rule.
    # context: maximum amount to lend
    # context: amount needed to borrow
    # context: agent's current sugar
    # context: agent's age
"""
function build_credit_context(agent, model)
    # TODO: assemble and return context Dict for LLM decision

    return Dict()
end

"""
attempt_credit!(agent, model)
Placeholder for rule-based credit logic.
"""
function attempt_pay_loans!(borrower, model)
    # Iterate over all outstanding loans grouped by counterparty
    for (other_id, loan_list) in pairs(borrower.loans_owed)
        lender = model[other_id]
        new_list = Loan[]
        for loan in loan_list
            if loan.time_due == abmtime(model)
                # full amount due via simple interest
                due_amount = loan.amount * (1 + model.interest_rate)
                if borrower.sugar >= due_amount
                    # full repayment: transfer and drop loan
                    borrower.sugar -= due_amount
                    lender.sugar += due_amount
                    # Remove the corresponding loan from lender's loans_given
                    if haskey(lender.loans_given, borrower.id)
                        filter!(l -> !(l.agent_id == loan.agent_id && l.amount == loan.amount && l.time_due == loan.time_due), lender.loans_given[borrower.id])
                        if isempty(lender.loans_given[borrower.id])
                            delete!(lender.loans_given, borrower.id)
                        end
                    end
                else
                    # partial repayment: half wealth now
                    payment = borrower.sugar / 2
                    borrower.sugar -= payment
                    lender.sugar += payment
                    # rollover remaining balance as new loan
                    remain = due_amount - payment
                    new_due = abmtime(model) + model.duration
                    push!(new_list, Loan(loan.agent_id, remain, new_due, model.interest_rate))
                end
            else
                # not due yet, keep the loan
                push!(new_list, loan)
            end
        end
        # Clean up empty loan lists
        if isempty(new_list)
            delete!(borrower.loans_owed, other_id)
        else
            borrower.loans_owed[other_id] = new_list
        end
    end
    return
end

function attempt_borrow!(borrower, model, amount)
    neighbours = nearby_agents(borrower, model, 1)
    if neighbours === nothing || isempty(neighbours)
        return
    end

    # Rule-based borrowing: iterate over neighbors who can lend sugar
    needed = amount
    for lender in neighbours
        if needed <= 0
            break
        end
        cl = can_lend(lender, model)
        if cl.can_lend
            avail = cl.max_amount
            amt = min(avail, needed)
            # transfer sugar
            lender.sugar -= amt
            borrower.sugar += amt
            needed -= amt
            # record new loan origination
            make_loan!(lender, borrower, amt, model)
        end
    end
end

function attempt_lend!(lender, model, amount)
    neighbours = nearby_agents(lender, model, 1)
    if neighbours === nothing || isempty(neighbours)
        return
    end

    # Rule-based lending: iterate over neighbors who want loans
    avail = amount
    for borrower in neighbours
        if avail <= 0
            break
        end
        wb = will_borrow(borrower, model)
        if wb.will_borrow
            req = wb.amount_required
            amt = min(avail, req)
            # transfer sugar
            lender.sugar -= amt
            borrower.sugar += amt
            avail -= amt
            # record new loan origination
            make_loan!(lender, borrower, amt, model)
        end
    end
end

"""
credit!(agent, model)
Master credit rule dispatching between rule-based and LLM decisions.
"""
function credit!(agent, model)

    # check if agent owes any loans this step, if so, attempt to pay them
    if has_due_loans(agent, model)
        attempt_pay_loans!(agent, model)
    end

    if !model.use_llm_decisions
        # Rule-based credit logic
        # check if agent needs a loan

        if will_borrow(agent, model).will_borrow
            # attempt to borrow sugar
            attempt_borrow!(agent, model, will_borrow(agent, model).amount_required)

        elseif can_lend(agent, model).can_lend
            # attempt to lend sugar
            attempt_lend!(agent, model, can_lend(agent, model).max_amount)
        end


    else
        # LLM-based credit decision
        context = build_credit_context(agent, model)
        decision = SugarscapeLLM.get_credit_decision(context, model)
        if decision.credit
            attempt_credit!(agent, model)
        end
    end
end

# -- Helper functions ------------------------------------------------------

"""
check_income(agent, model)

Returns amount of extra income available to agent after accounting for metabolism and other obligations.
(resources gathered, minus metabolism, minus other loan obligations)
"""
function check_income(agent::SugarscapeAgent)
    # Calculate income after metabolism and other obligations
    total_loan_amount = sum(loan.amount for loan_list in values(agent.loans_owed) for loan in loan_list; init=0.0)
    income = agent.sugar - agent.metabolism - total_loan_amount
    return income > 0.0 ? income : 0.0
end



"""
    can_lend(agent, model)

Determines whether an agent is eligible to lend sugar in the Sugarscape model, and calculates the maximum amount they can lend.

# Arguments
- `agent`: The agent whose lending capability is being evaluated. Should have fields `sex`, `age`, `is_fertile`, and `sugar`.
- `model`: The simulation model containing fertility parameters (`male_fertility_end`, `female_fertility_end`).

# Returns
- A named tuple `(can_lend, max_amount)`:
    - `can_lend`: `true` if the agent can lend sugar, `false` otherwise.
    - `max_amount`: The maximum amount of sugar the agent can lend (a `Float64`).

# Lending Criteria
- Agents older than their sex-specific maximum fertility age can lend up to half their sugar.
- Fertile agents with excess income (as determined by `check_income(agent)`) can lend up to their excess income.
- Otherwise, agents cannot lend and the maximum amount is zero.

# Notes
- The function relies on the helper function `check_income(agent)` to determine excess income.
"""
function can_lend(agent, model)
    # If agent is older than max fertility age
    if (agent.sex == :male && agent.age > model.male_fertility_end) ||
       (agent.sex == :female && agent.age > model.female_fertility_end)
        return (can_lend=true, max_amount=agent.sugar / 2)
        # If agent is fertile and has excess income
    elseif is_fertile(agent, model) && check_income(agent) > 0.0
        return (can_lend=true, max_amount=check_income(agent))
    else
        return (can_lend=false, max_amount=0.0)
    end
end


"""
    will_borrow(agent, model)

Determines whether an agent is willing to borrow sugar in the given model.

# Arguments
- `agent`: The agent whose borrowing decision is being evaluated.
- `model`: The simulation model containing the agent.

# Returns
- A tuple `(true, amount_required)` if the agent is fertile by age, has less sugar than their initial amount, and has positive income.
- Returns `nothing` otherwise.

# Conditions
- The agent must be fertile by age (`is_fertile_by_age(agent, model)`).
- The agent's current sugar must be less than their initial sugar.
- The agent must have positive income (`check_income(agent) > 0`).
"""
function will_borrow(agent, model)

    if is_fertile_by_age(agent, model) && agent.sugar < agent.initial_sugar && check_income(agent) > 0.0
        return (will_borrow=true, amount_required=amt_req(agent))

    else
        return (will_borrow=false, amount_required=0.0)
    end

end

function total_owed()

end

"""
    amt_req(agent::SugarscapeAgent)
Return the amount of sugar agent needs to borrow.
"""
amt_req(agent::SugarscapeAgent) = max(agent.initial_sugar - agent.sugar, 0)

function has_due_loans(agent, model)
    any(loan -> loan.time_due == abmtime(model),
        (loan for loan_list in values(agent.loans_owed) for loan in loan_list))
end

# ---------- loan origination ----------
"""
    make_loan!(lender, borrower, amt, model)
    Create a new loan of amount `amt` from `lender` to `borrower`.
    Records the loan in both agents' loans_given and loans_owed dictionaries.
"""
function make_loan!(lender::SugarscapeAgent, borrower::SugarscapeAgent, amt::Float64, model)
    due = abmtime(model) + model.duration
    loan = Loan(lender.id, amt, due, model.interest_rate)
    push!(get!(lender.loans_given, borrower.id, Loan[]), loan)
    push!(get!(borrower.loans_owed, lender.id, Loan[]), loan)
end


"""
    clear_loans_on_death(agent, model)

Clean up all loan records when an agent dies:
    - Lender death: forgive debts or transfer to children under inheritance
    - Borrower death: lenders take a loss
    - Finally clear the agent's own loan maps
"""
function clear_loans_on_death!(agent::SugarscapeAgent, model)
    # Lender death: borrowers are forgiven or reassign under inheritance rule I
    for (borrower_id, loan_list) in pairs(agent.loans_given)
        if hasid(model, borrower_id)
            borrower = model[borrower_id]
            if model.enable_reproduction && !isempty(agent.children)
                for child_id in agent.children
                    child = model[child_id]
                    get!(borrower.loans_owed, child_id, Loan[])
                    get!(child.loans_given, borrower_id, Loan[])
                    for loan in loan_list
                        newloan = Loan(child_id, loan.amount, loan.time_due, loan.interest_rate)
                        push!(borrower.loans_owed[child_id], newloan)
                        push!(child.loans_given[borrower_id], newloan)
                    end
                end
            end
            delete!(borrower.loans_owed, agent.id)
        end
    end
    # Borrower death: lenders take a loss
    for (lender_id, _) in pairs(agent.loans_owed)
        if hasid(model, lender_id)
            lender = model[lender_id]
            delete!(lender.loans_given, agent.id)
        end
    end
    # Clear this agent's loan records
    empty!(agent.loans_given)
    empty!(agent.loans_owed)
end
