# Sugarscape Specification

## Basic Types and Constants

- M : N1 (1)
- CULTURECOUNT : N1 (2)
- MAXVISION : N1 (3)
- MINMETABOLISM, MAXMETABOLISM : N (4)
- SUGARGROWTH : N1 (5)
- MAXAGE, MINAGE : N1 (6)
- MAXSUGAR : N1 (7)
- DURATION : N1 (8a)
- RATE : A (8b)
- INITIALSUGARMIN, INITIALSUGARMAX : N(9)
- WINNERRATE, SEASONLENGTH : N1 (10)
- PRODUCTION, CONSUMPTION : N (11)
- COMBAT LIMIT : N (12)
- IMMUNITY LENGTH : N (13)
- INITIALPOPULATIONSIZE : N (14)
- POLLUTIONRATE : N (15)
- CHILDAMT : N (16)

- CULTURECOUNT mod 2 = 1
- MINMETABOLISM < MAXMETABOLISM
- MAXAGE < MINAGE
- MAXVISION < M
- INITIALSUGARMIN < INITIALSUGARMAX
- INITIALPOPULATIONSIZE ≤ M ∗ M

(1) The simulation space is represented by a two dimensional M by M matrix of locations. Each location in the simulation space is referenced by two indices representing its position in this matrix;
(2) CULTURECOUNT determines the size of the bit sequence used to represent cultural allegiances. This is always equal to an odd number so that the number of 1’s in the sequence is never equal to the number of 0’s;
(3) Agents can only “see” in the four cardinal directions, that is the locations to the north, south, east and west. Agents are endowed with a random vision strength that indicates how many locations the can “see” in each direction. This endowment is always less than MAXVISION and MAXVISION is always less than M;
(4) Agents consume an amount of sugar (resources) during each turn. This sugar represents the amount of energy required to live. Each agent is endowed, on creation, with a random metabolism between MINMETABOLISM and MAXMETABOLISM;
(5) Agents consume sugar (resources) from the location they occupy. Each location can renew its sugar at a rate determined by SUGARGROWTH. After each turn up to a maximum of SUGARGROWTH units of sugar are added to each location (in accordance with the Growback rule);
(6) MAXAGE and MINAGE are, respectively, the maximum and minimum allowable lifespan for any agent;
(7) MAXSUGAR is the maximum amount of sugar that any location can possibly hold. This is known as the carrying capacity of a location;
(8) RATE and DURATION are used for determining the rate of interest charged for loans and the duration of a loan;
(9) INITIALSUGARMIN and INITIALSUGARMAX are the lower and upper limits for initial endowment of sugar given to a newly created agent;
(10) If seasons are enabled then two seasons, winter and summer are allowed with a duration of SEASONLENGTH turns (ticks) and a new separate lower seasonal grow back rate calculated using WINNERRATE (as determined by the SeasonalGrowback rule);
(11) Pollution can occur at a rate determined by the production and consumption of resources determined by the PRODUCTION and CONSUMPTION constants respectively;
(12) The combat rule posits the maximum reward COMBAT LIMIT that can be given to an agent through killing another agent;
(13) Immunity in agents is represented using a fixed size sequence of bits of length IMMUNIT Y LENGT H;
(14) We have some predetermined initial population size INITIALPOPULATIONSIZE that is used to initialise the simulation;
(15) POLLUTIONRATE determines the number of steps that elapse before pollution levels diffuse to their neighbours;
(16) A certain amount of sugar reserves, CHILDAMT , are required for an agent to have children.

[AGENT] (1)
POSITION == 0 .. M − 1 × 0 .. M − 1 (2)
SEX ::= male | female (3)
BIT ::= 0 | 1 (4)
affiliation ::= red | blue (5)
boolean ::= true | false

(1) AGENT is used as a unique identifier for agents;
(2) POSITION is also used to make specifying indices within the grid so as to make the schemas easier to read and more compact;
(3) All agents have a sex attribute;
(4) BITs are used to encode both culture preferences and diseases of agents;
(5) Every agent has a cultural affiliation of either belonging to the blue tribe or red tribe.

- FEMALEFERTILITYSTART, FEMALEFERTILITYEND : N
- MALEFERTILITYSTART, MALEFERTILITYEND : N

12 ≤ FEMALEFERTILITYSTART ≤ 15
40 ≤ FEMALEFERTILITYEND ≤ 50
12 ≤ MALEFERTILITYSTART ≤ 15
50 ≤ MALEFERTILITYEND ≤ 60
MALEFERTILITYEND = FEMALEFERTILITYEND + 10

- START SUGARMIN, START SUGARMAX : N
- START SUGARMIN = 5
- START SUGARMAX = 25

## Basic Agent Attributes

At a minimum each agent has the following attributes:
- Metabolism Rate (one per resource type): The rate at which an agents resource stores decrease during each simulation step. Different resource types have independent metabolism rates. Once an agent runs out of resources it dies (is removed from the simulation)
- Age: The number of steps that the agent has been present in the simulation
- Maximum Age: The maximum number of steps that an agent is allowed to exist during the simulation run. Once an agent reaches its maximum age it is removed from the simulation
- Sugar Level: The amount of sugar that an agent currently holds. There is no limit to how much sugar an agent can hold;
- Vision: How far in each of the cardinal directions that the agent can see. An agent can only interact with locations and agents that are in its neighbourhood Nvision. To ensure locality all agent values for vision will be less than some predefined maximum and this maximum will be much smaller than the lattice dimension size (M)
- Initial Sugar: The amount of sugar the agent was initialised with on creation;
- Culture Tags: A sequence of bits that represents the culture of an agent; - Children: For each agent we track its children (if any). To apply the Inheritance rule the full list of an agents children is required.
- Loans: Under the credit rule agents are allowed lend and/or borrow sugar for set durations and interest rates so we need to track these loans. For each loan we need to know the lender, the borrower, the loan principal and the due date (represented as the step number);
- Diseases: Diseases are sequences of bits that can be passed between agents. An agent may carry more than one disease;
- Immunity: Each agent has an associated bit sequence that confers immunity against certain diseases. If the bit sequence representing a disease is a subsequence of an agents immunity bit sequence then that agent is considered immune to that disease.

population : P AGENT
position : AGENT → POSITION
sex : AGENT → SEX
vision : AGENT → N1
age : AGENT → N
maxAge : AGENT → N1
metabolism : AGENT → N
agentSugar : AGENT → N
initialSugar : AGENT → N
agentCulture : AGENT → seq BIT
children : AGENT → P AGENT
loanBook : AGENT ↔ (AGENT × (N, N))
agentImmunity : AGENT → seq BIT
diseases : AGENT → P seq BIT

population =
    dom position = dom sex = dom vision
    = dom maxAge = dom agentSugar = dom children
    = dom agentCulture = dom metabolism = dom age
    = dom agentImmunity = dom diseases
dom loanBook ⊆ population
dom(ran loanBook) ⊆ population
∀ x, y : AGENT ; d : seq BIT • x, y ∈ population ∧ x 6= y ⇒
    ((age(x) ≤ maxAge(x) ∧ MINAGE ≤ maxAge(x) ≤ MAXAGE
    ∧ # agentCulture(x) = CULTURECOUNT
    ∧ # agentImmunity(x) = IMMUNITYLENGTH
    ∧ vision(x) ≤ MAXVISION
    ∧ MINMETABOLISM ≤ metabolism(x) ≤ MAXMETABOLISM
    ∧ position(x) = position(y) ⇔ x = y)
d ∈ ran diseases(x) ⇒ # d < IMMUNITYLENGTH

(1) Every existing agent has an associated age, sex, vision, etc. Note that the population holds only the currently existing agent IDs;
(2) Only current members of the population can be lenders;
(3) Only current members of the population can be borrowers
(4) Every agent in the population is guaranteed to have a current age less than the maximum allowed age for that agent, a maximum age less than or equal to the global MAXAGE, a metabolism between the allowed limits and vision less than or equal to the maximum vision. The sequence of bits representing its culture tags is CULTURECOUNT in size while those representing immunity is IMMUNITYLENGTH in size. All diseases are represented by sequences of bits that are shorter than the immunity sequence.

InitialSugarScape
Sugarscape′
step′ = 0 (1)
#population′ = INITIALPOPULATION SIZE (2)
loanBook′ = ∅ (3)
∀ a : AGENT • (4)
a ∈ population′ ⇒
    (age(a) = 0 ∧ diseases′(a) = ∅ ∧ children′(a) = ∅
    ∧ INITIALSUGARMIN ≤ agentSugar′(a) ≤ INITIALSUGARMAX)
    ∧ initialSugar′(a) = agentSugar′(a)

(1) step is set to zero;
(2) The population is set to some initial size;
(3) There are no loans as yet;
(4) Every agent in the starting population has an age of zero, no diseases or children and some initial sugar level within the agreed limits. The other attributes have random values restricted only by the invariants;

## Rules

### Movement - M

- Look out as far as vision permits in each of the four lattice directions, north, south, east and west;
- Considering only unoccupied lattice positions, find the nearest position producing maximum welfare;
- Move to the new position
- Collect all resources at that location

After the rule is applied the following will be the case for every agent:  (1) They will be located within one of the locations in their original neighbourhood (possibly the same position as before);
(2) After every agent has moved:
  a. There will exist no remaining available locations from the original neighbourhood of an agent that would have given a better welfare score than the location that agent now inhabits (we picked the maximum reward);
  b. If there was more than one location with maximum reward then the agent moved to the closest location.
(3) Agent sugar levels increase because they consume all the sugar at their new location (even if the new location is the same as their old location);
(4) Location sugar levels are set to zero everywhere there is an agent present.

### Agent Reproduction - S

1. Select a neighbouring agent at random;
2. If the neighbouring agent is of the opposite sex and if both agents are fertile and at least one of the agents has an empty neighbouring site then a newborn is produced by crossing over the parents’ genetic and cultural characteristics;
3. Repeat for all neighbours.

### Agent Inheritance - I

- When an agent dies its wealth is equally distributed among all its living children.
- Only living children can inherit from a parent. If a child is alive but scheduled to die at the same time as their parent then (because all agents who are due to die will die simultaneously) this child should not inherit from their parent.
- Allow for rounding errors. Resources (sugar) come in discrete amounts so division between children requires integer division.
- Inheritance is separate from the actual death or replacement rule, it reallocates the resources of agents due to die but it does not remove those agents from the simulation.

#### Helper Functions

- The `asSeq` function turns a set of items into a sequence of items. It does not specify the ordering in the sequence.
- The `disperseLoans` function takes in the loan book, a sequence containing all the dying agents and the children of the agents and produces an updated loan book with the loans of the dying agents now dispersed amongst their children. To do this it employs a third function `oneAgentLoans`
- The `oneAgentLoans` function takes in a single agent (who is marked for removal) the loans (in a sequence) held by that agent and the set containing its children. It outputs a new set of loans generated by dispersing all this agents loans amongst its children.
- The `getMother` and `getFather` functions simply take in an agent and the children set and finds the mother (father) of the agent from this set.

(1) First we construct the set of dying agents. Then using this set of dying agents we can construct two functions, one mapping amounts inherited from a female parent and one mapping amounts inherited from a male parent. These sets are then used to update the sugar of each agent;
  a. The function giving the amount each inheriting agent gets from its female parent is constructed by finding all healthy agents who have a dying mother and determining their share of their dying mother’s resources;
  b. The function listing amounts each agent gets from a male parent is constructed in an almost identical manner.
(2) If an agent is dying its sugar level is set to zero (because it is being reallocated to its children);
(3) Otherwise the agents sugar level is its old level plus whatever it inherits from both dying parents;
(4) Finally we update the loanBook using our `disperseLoans` function

### Agent cultural transmission - K

1. Select a neighbouring agent at random;
2. Select a tag randomly;
3. If the neighbour agrees with the agent at that tag position, no change is made; if they disagree, the neighbour’s tag is flipped to agree with the agent’s tag;
4. Repeat for all neighbours.

Group membership: Agents are defined to be members of the Blue group when 0s outnumber 1s on their tag strings, and members of the Red group in the opposite case. There are always an odd number of tags. `tribe` returns the affiliation of an agent based on the number of bits of each type in its culture sequence.
Agent Culture K: Combination of the “agent cultural transmission” and “agent group membership” rules given immediately above.

`flipTags` is a recursive function that takes in a culture tag sequence belonging to an agent, a sequence of neighbouring agents and the mapping containing all agent’s culture tag sequences. It returns a new tag sequence generated by each neighbouring agent flipping one bit chosen at random of the original agent’s tag sequence. It is aided in this by the function `flipBit` that takes in two bit sequences and returns a new sequence equal to the first bit sequence with one bit changed at random to match the other sequence at that position.

The sequence of neighbours is provided by the Culture scheme which employs the `asSeq` function to convert a set of neighbours into a sequence.

(1) For every agent a in the population we allow each other agent that counts a as a neighbour to flip one bit at random of a’s culture bit sequence.

### Agent Combat -Cα

1. Look out as far as vision permits in the four principle lattice directions;
2. Throw out all sites occupied by members of the agent’s own tribe;
3. Throw out all sites occupied by members of different tribes who are wealthier then the agent;
4. The reward of each remaining site is given by the resource level at the site plus, if it is occupied, the minimum of α and the occupant’s wealth;
5. Throw out all sites that are vulnerable to retaliation;
6. Select the nearest position having maximum reward and go there;
7. Gather the resources at the site plus the minimum of α and the occupants wealth if the site was occupied;
8. If the site was occupied then the former occupant is considered “killed” - permanently removed from play.

- The combat rule is really an extension of the movement rule where we are now allowed to move to locations occupied by other agents under certain predefined conditions.
- Only locations within an agents neighbourhood are considered;
- If a location is occupied it must be occupied by an agent belonging to a different tribe who has lower sugar levels;
- We only consider a position already containing an agent from another tribe if there are no other agents from a different tribe within the neighbourhood of that location who are stronger than we will be once we have consumed the resources of the new location (that is agents who may retaliate against us for killing an agent belonging to their own tribe).

- Every agent that is removed from the simulation is also removed from the loanBook;
- No new agents are introduced;
- Location sugar levels are updated;
- Every agent that remains in the population has all its attributes unchanged apart from (possibly) position and sugar;
- We update the sugar levels of each agent using the reward function;
- Every agent has moved somewhere within their old neighbourhood;
- Every agent that is no longer part of the population was removed by combat, that is, there is another agent (the agent that killed them) now situated in their old position;
- If a location available to an agent and the reward of that location is better or equal to that agent’s new position and it was closer than that agents new position to its old position then it must be the case that some other agent has just moved to that location (otherwise we would have moved there);

### Credit - Ldr

- An agent is a potential lender if it is too old to have children, in which case the maximum amount it may lend is one-half of its current wealth;
- An agent is a potential lender if it is of childbearing age and has wealth in excess of the amount necessary to have children, in which case the maximum amount it may lend is the excess wealth;
- An agent is a potential borrower if it is of childbearing age and has insufficient wealth to have a child and has income (resources gathered, minus metabolism, minus other loan obligations) in the present period making it credit-worthy for a loan written at terms specified by the lender;
- If a potential borrower and a potential lender are neighbors then a loan is originated with a duration of d years at the rate of r percent, and the face value of the loan is transferred from the lender to the borrower;
- At the time of the loan due date, if the borrower has sufficient wealth to repay the loan then a transfer from the borrower to the lender is made; else the borrower is required to pay back half of its wealth and a new loan is originated for the remaining sum;
- If the borrower on an active loan dies before the due date then the lender simply takes a loss;
- If the lender on an active loan dies before the due date then the borrower is not required to pay back the loan, unless inheritance rule I is active, in which case the lender’s children now become the borrower’s creditors.

#### Helper Functions - Ldr

- `totalOwed` calculates the total amount owed from a given sequence of loans. We have assumed that interest is simple interest and not compound.
- `canLend(age, male, sugar)` ⇔
    age > MALEFERTILITYEND
      ∨ (MALEFERTILITYSTART ≤ age ≤ MALEFERTILITYEND
        ∧ sugar > CHILDAMT )
  `canLend(age, female, sugar)` ⇔
    age > FEMALEFERTILITY END
      ∨ (FEMALEFERTILITYSTART ≤ age ≤ FEMALEFERTILITYEND
        ∧ sugar > CHILDAMT )
- `willBorrow(age, male, sugar, loans)` ⇔
    (MALEFERTILITYSTART ≤ age ≤ MALEFERTILITYEND
      ∧ sugar < CHILDAMT )
      ∧ sugar > totalOwed(asSeq(loans))
- `willBorrow(age, female, sugar, loans)` ⇔
    (FEMALEFERTILITYSTART ≤ age ≤ FEMALEFERTILITYEND
      ∧ sugar < CHILDAMT)
      ∧ sugar > totalOwed(asSeq(loans))
- `amtAvail` depends on whether an agent can still have children. If they are no longer fertile then they can loan out half their available sugar. If they are still fertile then they have to retain enough sugar to have children.
- `amtReq` is the amount that a lender requires. Amount required is that which gives the borrower enough sugar to have children
  amtReq(sugar) = CHILDAMT − sugar


- `lender(l, (b, (p, d))) = l`
- `borrower(l, (b, (p, d))) = b`
- `amtDue(l, (b, (p, d))) = p + p ∗ RATE ∗ DURATION`
- `principal(l, (b, (p, d))) = p`
- `due(l, (b, (p, d))) = d`

- It is possible that an agent has a loan due and cannot pay this loan off. In this case, according to the rule definition, the borrower must pay half of its sugar to the lender and renegotiate another loan to cover the remainder of its debt. The lender must pay each borrower in sequence the amount of half its sugar. In order to remain true to the rule definition we must, when we have more than one loan due, pay each loan in some sequence (defined using a conflict resolution rule e.g. pay biggest loan first).

- `chooseConflictFreeLoans` returns a sequence of groups of loans that are conflict free (i.e. a borrower can only appear once in each group). Choose the largest conflict free set possible where a set is deemed conflict free if all borrowers only appear in that set at most once.

- `payExclusiveLoans` takes in this sequence of loan sets and processes each set concurrently in the same manner as the Mating rule.

- `makePayments` is a recursive function that goes through a sequence of loans and makes the final payment on each one.

- `sumLoans(〈top〉 a tail) = sumLoans(tail) + amtDue(top)`

- `totalOwed(agent, loans) = sumLoans(asSeq(loans ⊲ ({agent} ⊳ (ran loans))))`
- `totalLoaned(agent, loans) = sumLoans(asSeq({agent} ⊳ loans))`

(1) The new loan book is the old book plus the new loans;
(2) The following properties ensure sugar is updated correctly and that the correct amount of borrowing has taken place:
  a. If an agent is a lender then their new sugar levels decrease by the amount the have lent;
  b. If an agent is a borrower then their sugar has increased by the amount they have borrowed;
  c. Any agent that neither borrowed or lent has the same sugar levels as before;
  d. If there remain any agents who still need to borrow then it is because there are no agents in their neighbourhood who are still in a position to borrow.
(3) The total amount loaned by any agent is no greater than the amount that agent had available;
(4) The total amount borrowed is less than or equal to the amount required by the borrower;
(5) Every loan in this set must have the following properties:
    a. The lender must be in a position to lend;
    b. The borrower must need to borrow;
    c. The amount is less than or equal to the minimum of (i) the amount required by the borrower and (ii) the maximum amount available from the lender;
    d. The due date of the loan is set by the DURATION constant;
    e. the borrower and lender must be neighbours.

### Agent Disease - E

Agent immune response:
- If the disease is a substring of the immune system then end (the agent is immune), else (the agent is infected) go to the following step;
- The substring in the agent immune system having the smallest Hamming distance from the disease is selected and the first bit at which it is different from the disease string is changed to match the disease.

Disease transmission: For each neighbour, a disease that currently afflicts the agent is selected at random and given to the neighbour.
Agent disease processes E: Combination of “agent immune response” and “agent disease transmission” rules given immediately above


#### Helper Functions - E

- `subseq` is a function for determining whether one sequence is a subsequence of another.
- `hammingDistance` calculates the Hamming distance between two bit sequences.
- `applyDiseases` takes in a bit sequence representing the immunity of an agent and a list of diseases that affect the agent and produces a new immunity bit sequence that is updated by the disease list. It uses another function `processInfection` to process each disease in the disease set.
- `processInfection`: `seq BIT × seq BIT → seq BIT`

```
agentImmunity′ = {a : AGENT | a ∈ population •
  a 7→ applyDiseases(agentImmunity(a), asSeq(diseases(a)))}
∀ x : AGENT • x ∈ population ⇒ agentSugar′(x) = agentSugar(x)−
  #{d : seq BIT | d ∈ diseases(a) ∧ ¬ subseq(d, agentImmunity(a)}
```

- `newDiseases`: construct a set of diseases that an agent can catch from its neighbours. It takes the set of neighbours and their current diseases as input and constructs a set of diseases where one disease is chosen from each neighbour.

- transmission:

```
∀ a : AGENT • a ∈ population ⇒
  diseases′(a) = diseases(a) ∪ (1)
    newDiseases(asSeq(visibleAgents(a, position, 1)), diseases)
```

(1) visibleAgents returns the set of neighbours of an agent and this set is then passed to the newDisease function which returns a set of diseases, one chosen from each agent in the neighbour set.


## Rule Application Sequence
{Rule}: The indicates that Rule is optional. We can choose to include it or not in a simulation;
RuleA | RuleB: This indicates that there is a choice of which rule to apply - either one or the other but not both.

```
Tick
[# Growback |# SeasonalGrowback]
[# Movementbasic | (# Movementpollution # PollutionDiffusion) |# Combat]
{# Inheritance}{# Death{[# Replacement |# AgentMating]}}
{# Culture}{# PayLoans # MakeLoans}
{# Transmission # ImmuneResponse}
```
