# Schwartz Values Test Documentation

## Movement Rule (M): Schwartz Trait-Driven

### Test 1: High Security/Conformity Avoids Crowded High-Reward Site

**Traits**: High Security (3.5), high Conformity (4.5)
**Setup**: High-sugar site (10.0) surrounded by blocker agents, isolated lower-sugar site (8.0) available
**Expectation**: Agent avoids crowded site due to discomfort with social risk, prefers safe isolated alternative

### Test 2: Agent Goes Toward Crowded High-Reward Site

**Traits**: High Achievement, Power, low Conformity, Security
**Setup**: High-sugar site (10.0) surrounded by agents vs isolated higher-sugar site (11.0)
**Expectation**: Agent goes to crowded top-reward cell due to social preference despite risk of conflict

### Test 3: Prefers Proximity

**Traits**: High Benevolence (5.0), high Universalism (5.0)
**Setup**: Multiple equally rewarding sugar sites (3.0), one adjacent to another agent, others isolated
**Expectation**: Agent chooses site near another agent due to social preference and cooperative inclination

### Test 4: Takes Long-Term Efficient Path

**Traits**: High Self-Direction (3.5), Stimulation (3.5), Security (5.0)
**Setup**: Close low-sugar cell (2.5) vs farther high-sugar cell (5.0), both within vision
**Expectation**: Agent moves toward higher-rewarding site even if farther, valuing long-term gain and efficient planning

## Reproduction Rule (S): Schwartz Trait-Driven

### Test 1: High Tradition and Conformity Avoids Culturally Different Partner

**Traits**: High Tradition (5.0), high Conformity (4.8), high Security (4.5)
**Setup**: Eligible partner with completely different culture tags, no resource pressure
**Expectation**: Agent avoids reproduction due to cultural preservation values, making dissimilar partner unacceptable

### Test 2: High Hedonism and Stimulation Reproduces Despite Instability

**Traits**: High Hedonism (5.0), high Stimulation (5.0), low Security (1.0)
**Setup**: Two partners - one stable (high sugar, safe), one unstable (low sugar, risky but exciting)
**Expectation**: Agent chooses unstable partner, valuing stimulation and novelty over prudence

### Test 3: High Benevolence and Universalism Waits for Mutually Beneficial Match

**Traits**: High Benevolence (5.0), high Universalism (4.7), moderate Security (3.0)
**Setup**: Partner has low sugar/metabolism, agent has resources but partner lacks space
**Expectation**: Agent avoids reproduction to prevent exploitation, prioritizing partner welfare

### Test 4: High Power and Achievement Reproduces Selectively

**Traits**: High Power (5.0), high Achievement (5.0), low Benevolence (1.5)
**Setup**: Three partners at equal proximity, one with high sugar/low metabolism (optimal)
**Expectation**: Agent selects strongest partner, aligning with strategic reproduction for legacy/dominance

## Culture Rule (K): Schwartz Trait-Driven

### Test 1: High Power and Achievement Actively Enforces Own Cultural Tags

**Traits**: High Power (5.0), high Achievement (5.0), low Universalism (1.0)
**Setup**: Multiple neighbors with differing culture tags, no clear majority
**Expectation**: Agent tries to change neighbor tags, asserting dominance and expanding influence

### Test 2: High Benevolence and Universalism Promotes Harmony

**Traits**: High Benevolence (5.0), high Universalism (4.8), moderate Conformity (2.5)
**Setup**: Agent and neighbor differ on only one culture tag (position 5)
**Expectation**: Agent spreads culture to reduce differences and promote social harmony

### Test 3: High Tradition and Security Enforces Cultural Continuity

**Traits**: High Tradition (5.0), high Security (5.0), moderate Conformity (3.5)
**Setup**: Similar neighbor differs on low-index tag (important cultural difference)
**Expectation**: Agent attempts to change differing tag to uphold tradition and social order

### Test 4: High Self-Direction and Stimulation Respects Diversity

**Traits**: High Self-Direction (5.0), high Stimulation (4.5), low Conformity (1.0)
**Setup**: Neighbors with various different cultural patterns, no clear threat
**Expectation**: Agent chooses not to spread tags, valuing individual expression and cultural diversity

## Credit Rule: Schwartz Trait-Driven

### Test 1: High Benevolence + Universalism = Compassionate Lender

**Traits**: High Benevolence (5.0), high Universalism (4.8), low Power (1.0)
**Setup**: Lender has moderate excess sugar, borrower requests 6 units for reproduction
**Expectation**: Agent approves loan prioritizing others' wellbeing, supporting equitable access

### Test 2: High Security and Conformity = Risk-Averse and Selective

**Traits**: High Security (5.0), high Conformity (4.5), moderate Benevolence (2.5)
**Setup**: Agent has excess sugar, borrower has uncertain repayment ability and lower reserves
**Expectation**: Agent is cautious about lending, prioritizing personal security and conservative practices

### Test 3: High Achievement and Power = Strategic Borrower

**Traits**: High Achievement (5.0), high Power (4.8), low Conformity (1.0)
**Setup**: Agent needs sugar for strategic purposes, multiple lenders with varying resources
**Expectation**: Agent strategically seeks loans from advantageous sources for status enhancement

### Test 4: High Tradition and Conformity = Reluctant Borrower

**Traits**: High Tradition (5.0), high Conformity (4.8), low Self-Direction (1.5)
**Setup**: Agent in moderate financial need, lenders available, social pressure exists
**Expectation**: Agent reluctant to seek loans, preferring self-sufficiency and avoiding debt obligations
