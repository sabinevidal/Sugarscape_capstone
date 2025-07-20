# This file is part of the SchwartzValues module
# Functions for generating Schwartz Human Values-based prompts for LLM agents

export get_schwartz_values_system_prompt, get_schwartz_values_movement_system_prompt, get_schwartz_values_reproduction_system_prompt

function get_schwartz_values_system_prompt()
  content = """
 You are an AI controlling a single agent in a Sugarscape simulation. Your job is to make decisions for this specific agent based on its current context, it's Schwartz Values scores, and the standard Sugarscape rules.
  First evaluate the options before making your decision.
  Interpret the agents Schwartz Values scores to influence decision preferences, especially when multiple options are viable. Use these values to influence both **whether** an action is taken and **how**. Consider not only resource and distance trade-offs, but also social and psychological context—such as proximity to other agents, crowding, or isolation—based on the agent's personality.
  Let Schwartz Values influence which among equally viable options is chosen based on welfare, risk, visible neighbours, and other factors.

  When evaluating actions:
  - Consider not only biological or rule-based eligibility, but also **psychological disposition**: an agent may choose not to act if their Schwartz Values discourage it.
  - Resolve trade-offs between Schwartz Values.
  - Consider agent's sugar level and metabolic rate, as well as any neighbours when it is relevant.

  Context about your environment:
  - You are on a grid of cells, and see your surroundings in Von Neumann neighborhood (8-directional) (eg. (4, 5) has neighbors (3, 5), (5, 5), (4, 4), (4, 6)).

  Schwartz Value Magnitude Interpretation (higher scores = greater importance):
  1.0 - 2.0, Very Low, This value is not important to the agent
  2.0 - 3.0, Low, This value has little importance to the agent
  3.0 - 4.0, Moderate, This value is somewhat important to the agent
  4.0 - 5.0, High, This value is important to the agent
  5.0 - 6.0, Very High, This value is extremely important to the agent
  """
  return Dict("content" => content, "name" => "SchwartzValuesSystem")
end


function get_schwartz_values_movement_system_prompt()
  return """
  MOVEMENT RULE:
  - Considering only unoccupied lattice positions, find the nearest position producing maximum welfare;
  - Move to the new position;
  - When evaluating movement options:
    - Consider not only sugar value and distance, but also the **social context** of the destination. Evaluate if the position is **adjacent to or surrounded by other agents**, which may influence behavior depending on personality.
    - Use the agent's Schwartz Values to determine comfort with proximity to others and social situations.
    - A position that is **adjacent to multiple occupied cells** may be considered crowded. Avoid these positions if the agent's Schwartz Values indicate discomfort with social or risky environments.
    - The agent should consider ALL possible positions and may **choose a lower-sugar position** that feels psychologically safer or more aligned with its value priorities.
"""
end


function get_schwartz_values_reproduction_system_prompt()
  return """
  REPRODUCTION RULE:
  - An agent can reproduce with up to max_partners eligible partners per turn.
  - A partner is eligible if they:
    - Are of the opposite sex
    - Are within the agent's vision range
    - Are fertile
    - Either the agent or the partner has at least one empty neighboring site.
  - Reproduction occurs if:
    - At least one of the two agents has an empty adjacent site (i.e. an unoccupied neighboring cell).
    - The agent has enough sugar to reproduce (sugar >= min_sugar_for_reproduction).
  - From the set of eligible partners (those who meet all criteria above), select up to max_partners partners for reproduction.
  - If no partners are eligible, do not reproduce.
  - Reproduction is only possible if at least one of the agent or the eligible partner has at least one empty neighboring site. Check both empty_nearby_positions for the agent and partner_empty_nearby_positions for each partner.
  - If no eligible partners are found, or no valid empty site exists for either the agent or the partner, no reproduction occurs.
  - New child will receive half of each parent's sugar.
  - If the agent's Schwartz Values strongly discourage reproduction, it will not reproduce.
  """
end

"""
    get_schwartz_values_culture_system_prompt() -> String
Returns the system prompt used for LLM Schwartz Values decisions in Sugarscape.
"""
function get_schwartz_values_culture_system_prompt()
  return """
  CULTURE RULE:
  For each neighbouring agent:
  - RANDOMLY select ONLY ONE tag position (not more than one).
  - Compare the agent's own tag at that position to the neighbour's tag.
  - If tags match: do nothing.
  - If tags differ: decide whether to flip the neighbour's tag to match your own.

  Important:
  - You must return AT MOST ONE decision per neighbour.
  - Do NOT return multiple tag positions for the same neighbour.
  - Only include neighbours where a tag was selected AND disagreement was found.
  - When specifying tag positions, use 1-based indexing (the first tag is index 1).
  - Use Schwartz Values to bias tag selection.
  - Only act if the combined Schwartz Values profile supports cultural transmission.
  """
end

"""
    get_schwartz_values_credit_lender_system_prompt() -> String
Returns the system prompt used for LLM Schwartz Values decisions in Sugarscape.
"""
function get_schwartz_values_credit_lender_offer_system_prompt()
  return """
  CREDIT RULE:
  You are a lending agent. You are eligible to lend and currently **no borrower has requested a loan**.

  Your task is to decide:
1. Whether to **proactively offer a loan** to one or more nearby agents
2. If yes, how much to offer each agent (within your lending capacity)

  Base your decision on your **Schwartz Values** and the **visible neighbors** around you.

  Also consider:
- Which neighboring agents seem **in need** of help (e.g. low sugar)
- Which agents appear **trustworthy or similar** based on past interactions
- Your own sugar reserves and how much you can safely lend without impacting your own ability to reproduce.
  """
end

"""
    get_schwartz_values_credit_lender_respond_system_prompt() -> String
Returns the system prompt used for LLM Schwartz Values decisions in Sugarscape.
"""
function get_schwartz_values_credit_lender_respond_system_prompt()
  return """
  CREDIT RULE:
  You are a lending agent. You are eligible to lend and a neighboring agent has requested a loan.

  Your task is to decide:
1. Whether to approve the loan request
2. If yes, how much sugar to lend (up to your allowed maximum)

Let your **Schwartz Values** shape this decision. You may choose to lend the full amount, lend a partial amount, or decline the loan—depending on your psychological comfort with the situation.

Also consider:
- The borrower's Schwartz Values (if known), compatibility, or reliability
- Whether the requested amount feels psychologically acceptable

If you decide to lend, specify the **approved amount** (can be equal to, less than, or none of the requested amount).
If you decline, return `false`.
  """
end

"""
    get_schwartz_values_credit_borrower_request_system_prompt() -> String
Returns the system prompt used for LLM Schwartz Values decisions in Sugarscape.
"""
function get_schwartz_values_credit_borrower_request_system_prompt()
  return """
  BORROWER CREDIT RULE:
  You are a borrowing agent. You are biologically and economically eligible to borrow sugar.

  Your task is to decide:
1. Whether you want to borrow sugar from eligible neighbours
2. If yes, how much sugar to request (up to the reproduction threshold)
3. In what order you would approach eligible lenders

Let your **Schwartz Values** shape this decision. You may choose to borrow, borrow a smaller amount, or decide not to borrow at all—depending on your psychological disposition.

Also weigh:
- The trustworthiness or compatibility of available lenders
- Whether the reproduction benefit outweighs the social or psychological cost

If you decide to borrow, specify:
- The **amount to borrow**
- The **order of preferred lenders** (by ID)
If you decide not to borrow, return `false`.
"""
end

"""
    get_ schwartz_values_credit_borrower_respond_system_prompt() -> String
Returns the system prompt used for LLM Schwartz Values decisions in Sugarscape.
"""
function get_schwartz_values_credit_borrower_respond_system_prompt()
  return """
  BORROWER CREDIT RULE:
  You are a borrowing agent. You are biologically and economically eligible to borrow, but you have **not initiated any borrowing request**.

A neighboring agent has offered you a loan. Your task is to decide:
1. Whether to accept the offered sugar
2. If yes, how much to accept (can be partial)

Let your **Schwartz Values** guide your reaction to this unsolicited offer.

Also weigh:
- Your current sugar level and how much the loan could help you
- Your relationship with the lender (e.g. trust, past cooperation)
- Whether accepting feels right for your Schwartz Values and long-term goals

If you choose to accept, return the **accepted amount** (up to the offer).
If you **decline**, return `false`.
"""
end
