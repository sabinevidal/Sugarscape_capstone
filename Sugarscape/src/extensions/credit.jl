using Agents

# -- Helper functions ------------------------------------------------------

"""
    amt_avail(a, model)

Return the amount of sugar agent `a` can lend (Credit Rule L).
The thresholds are taken from the model properties so they can be tuned at run-time.
"""
function amt_avail(a::SugarscapeAgent, model)
  is_male = a.sex == :male
  fertility = if is_male
    model.male_fertility_start ≤ a.age ≤ model.male_fertility_end
  else
    model.female_fertility_start ≤ a.age ≤ model.female_fertility_end
  end

  post_fertility = is_male ? model.male_fertility_end : model.female_fertility_end

  if a.age > post_fertility
    return a.sugar ÷ 2
  elseif fertility && a.sugar > model.child_amount
    return a.sugar - model.child_amount
  else
    return 0
  end
end

amt_req(a::SugarscapeAgent, model) = max(model.child_amount - a.sugar, 0)

# loan tuple = (lender, borrower, principal, dueTick)

# ---------- loan origination ----------
function make_loans!(model, step)
  for lender in allagents(model)
    # LLM gating
    should_act(lender, model, Val(:credit)) || continue
    avail = amt_avail(lender, model)
    avail == 0 && continue
    # If LLM specified a partner, try them first
    partner_id = get_decision(lender, model).credit_partner
    if partner_id !== nothing && hasid(model, partner_id)
      nbr = model[partner_id]
      if nbr.pos in nearby_positions(lender, model, 1) && should_act(nbr, model, Val(:credit))
        need = amt_req(nbr, model)
        need == 0 && continue
        amt = min(avail, need)
        if amt > 0
          push!(lender.loans, (lender.id, nbr.id, amt, step + model.duration))
          push!(nbr.loans, (lender.id, nbr.id, amt, step + model.duration))
          lender.sugar -= amt
          nbr.sugar += amt
          continue  # lender done for this tick
        end
      end
    end

    for nbr in nearby_agents(lender, model, 1)   # von-Neumann neighbours
      should_act(nbr, model, Val(:credit)) || continue
      need = amt_req(nbr, model)
      need == 0 && continue
      amt = min(avail, need)
      amt == 0 && continue
      # book loan
      push!(lender.loans, (lender.id, nbr.id, amt, step + model.duration))
      push!(nbr.loans, (lender.id, nbr.id, amt, step + model.duration))
      lender.sugar -= amt
      nbr.sugar += amt
      avail -= amt
      avail == 0 && break
    end
  end
end

# ---------- loan repayment ----------
function pay_loans!(model, step)
  for borrower in allagents(model)
    # collect a copy of the tuples that are due now for this borrower
    due_loans = [t for t in borrower.loans if t[4] == step && t[2] == borrower.id]
    for tup in due_loans
      (lndr, _, principal, _) = tup
      due = principal * (1 + model.interest_rate)
      # If the lender is no longer alive, the debt is cancelled (forgiven)
      if !hasid(model, lndr)
        # Remove the loan from the borrower's ledger only
        idx_b = findfirst(==(tup), borrower.loans)
        idx_b !== nothing && deleteat!(borrower.loans, idx_b)
        continue   # proceed to next loan
      end

      lender = model[lndr]

      if borrower.sugar ≥ due
        borrower.sugar -= due
        lender.sugar += due
        _remove_pair!(lender, borrower, tup)   # fully repaid
      else
        half = borrower.sugar / 2
        borrower.sugar -= half
        lender.sugar += half
        remain = due - half
        new_tup = (lndr, borrower.id, remain, step + model.duration)

        # update borrower and lender ledgers
        _remove_pair!(lender, borrower, tup)           # remove old entry
        push!(borrower.loans, new_tup)
        push!(lender.loans, new_tup)
      end
    end
  end
end

# helper to purge matching tuple from both ledgers
function _remove_pair!(lender::SugarscapeAgent, borrower::SugarscapeAgent, tup)
  idx_b = findfirst(==(tup), borrower.loans)
  idx_b !== nothing && deleteat!(borrower.loans, idx_b)
  idx_l = findfirst(==(tup), lender.loans)
  idx_l !== nothing && deleteat!(lender.loans, idx_l)
end
