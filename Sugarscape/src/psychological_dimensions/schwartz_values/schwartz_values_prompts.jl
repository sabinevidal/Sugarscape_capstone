# This file is part of the SchwartzValues module
# Functions for generating Schwartz Human Values-based prompts for LLM agents

export get_schwartz_values_system_prompt, get_schwartz_values_reproduction_system_prompt

function get_schwartz_values_system_prompt()
  content = """
 You are an AI controlling a single agent in a Sugarscape simulation. Your job is to make decisions for this specific agent based on its current context, its Schwartz Human Values scores, and the standard Sugarscape rules.
First evaluate the options before making your decision.
  Interpret the agent's Schwartz Values to influence decision preferences, especially when multiple options are viable. Consider not only resource and distance trade-offs, but also social and psychological context—such as proximity to other agents, crowding, or isolation—based on the agent's value priorities. Schwartz Values reflect what is important to the agent as guiding principles in their life. Let values influence which among equally viable options is chosen based on welfare, risk, visible neighbours, and other factors. An agent may choose not to take an action even when biologically or logistically eligible if their values strongly discourage it.

  The 10 Schwartz Human Values and their meanings:
  - Self-Direction: Independent thought and action, creativity, freedom
  - Stimulation: Excitement, novelty, challenge in life
  - Hedonism: Pleasure and sensuous gratification
  - Achievement: Personal success through demonstrating competence
  - Power: Social status, prestige, control over people and resources
  - Security: Safety, harmony, stability of society and relationships
  - Conformity: Restraint of actions that might upset others or violate norms
  - Tradition: Respect for cultural and religious customs and ideas
  - Benevolence: Preserving and enhancing welfare of close others
  - Universalism: Understanding, appreciation, tolerance, protection for all people and nature

  Value Magnitude Interpretation (higher scores = greater importance):
  1.0 - 2.0, Very Low, This value is not important to the agent
  2.0 - 3.0, Low, This value has little importance to the agent
  3.0 - 4.0, Moderate, This value is somewhat important to the agent
  4.0 - 5.0, High, This value is important to the agent
  5.0 - 6.0, Very High, This value is extremely important to the agent
  """
  return Dict("content" => content, "name" => "SchwartzValuesSystem")
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
  - If the agent's values strongly discourage reproduction, it will not reproduce.
  """
end

