# Sugarscape Rule Implementation Plan

## 1. Constants, Types, and Agent Attributes

- **Verify**: All constants (e.g. `M`, `CULTURECOUNT`, `MAXVISION`, etc.) are present and used with correct constraints.
- **Check**: Agent struct includes all required fields: position, sex, vision, age, max_age, metabolism, sugar, initial_sugar, culture, children, loans, diseases, immunity, etc.
- **Ensure**: All invariants (e.g. vision < MAXVISION < M, culture tag length odd, etc.) are enforced at agent creation and during simulation.
- **Action**: Add validation functions for agent and model invariants, called at initialization and periodically.

---

## 2. Rule M: Movement

- **Check**: Movement is only to unoccupied sites within vision in cardinal directions.
- **Ensure**: Welfare calculation (with/without pollution) is correct.
- **Tie-breaking**: If multiple sites have max welfare, choose the nearest; if still tied, choose randomly.
- **Action**: Add/verify tests for all tie-breaking and edge cases.

---

## 3. Rule S: Reproduction

- **Check**: Reproduction only occurs between fertile, opposite-sex neighbours, and only if at least one has an empty neighbouring site.
- **Ensure**: Child inherits genetic and cultural characteristics via crossover.
- **Track**: Children are registered in both parents' `children` lists.
- **Action**: Add/verify fertility checks, child placement, and parent-child linkage.

---

## 4. Rule I: Inheritance

- **Check**: On death, agent's sugar is divided equally (integer division) among living children.
- **Ensure**: Only living children inherit; if no living children, wealth is lost.
- **Action**: Implement/verify loan dispersal among children if credit is enabled and inheritance is active.
- **Track**: Inheritance metrics for analysis.

---

## 5. Rule K: Culture

- **Check**: For each agent, each neighbour may flip one randomly chosen bit to match the agent.
- **Ensure**: Culture tag length is odd and consistent for all agents.
- **Tribe**: Blue if 0s > 1s, Red otherwise.
- **Action**: Add/verify functions for cultural transmission, tribe assignment, and group membership.

---

## 6. Rule Cα: Combat

- **Check**: Agents may attack only weaker, culturally different agents within vision.
- **Retaliation**: Disallow attacks if a stronger enemy could retaliate.
- **Reward**: Attacker receives site sugar + min(α, victim's sugar).
- **Remove**: Victim is killed and removed from the model.
- **Action**: Add/verify retaliation logic, reward calculation, and correct update of agent/model state.

---

## 7. Rule Ldr: Credit

- **Check**: Lending/borrowing eligibility per age, sex, and wealth.
- **Ensure**: Loans are only between neighbours, with correct principal, duration, and interest.
- **Repayment**: On due date, borrower pays if able; else pays half and refinances.
- **Death**: If lender dies, debt is cancelled unless inheritance is active; then children become creditors.
- **Action**: Add/verify loan book management, repayment, and inheritance integration.

---

## 8. Rule E: Disease

- **Transmission**: Each agent may receive a random disease from each neighbour.
- **Immunity**: If disease is a substring of immunity, agent is immune; else, mutate immunity to reduce Hamming distance.
- **Penalty**: Each non-immune disease reduces sugar.
- **Action**: Add/verify disease transmission, immunity update, and sugar penalty logic.

---

## 9. Growback, Pollution, and Seasonal Rules

- **Growback**: Sugar regrows at each site up to capacity.
- **Seasonal**: Growth rate varies by season and region.
- **Pollution**: Produced by sugar collection and metabolism; diffuses periodically.
- **Action**: Add/verify correct application of these rules and their toggles.

---

## 10. Rule Application Sequence

- **Order**: Ensure rules are applied in the correct sequence per tick:
  1. Growback/SeasonalGrowback
  2. Movement/Combat/PollutionDiffusion
  3. Inheritance/Death/Replacement/Reproduction
  4. Culture
  5. Credit (PayLoans, MakeLoans)
  6. Disease (Transmission, ImmuneResponse)
- **Action**: Add/verify model step logic matches the specification.

---

## 11. Documentation

- **Document**: Each rule, method, and agent attribute with reference to the specification.
- **Usage**: Provide clear instructions for enabling/disabling rules and configuring parameters.

---

## 12. Robustness and Best Practices

- **Error handling**: For all edge cases (e.g. no empty sites, all neighbours dead, etc.).
- **Performance**: Profile and optimise bottlenecks, especially in large grids or populations.
- **Code quality**: Ensure DRY, SOLID, KISS, and YAGNI principles throughout.


Can you write a checklist in a new file 'action_plan.md' to outline all the items in the audit we need to address.
