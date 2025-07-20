# Big Five Test Documentation

## Movement Rule (M): Trait-Driven

### Test 1: High Neuroticism Avoids Crowded High-Reward Site

Traits: Low openness (1.0), low extraversion (1.0), high neuroticism (5.0)
Setup: High-sugar site (10.0) surrounded by blocker agents, isolated lower-sugar site (8.0) available
Expectation: Agent avoids crowded high-reward cell due to anxiety/discomfort, chooses isolated second-best option

### Test 2: High Extraversion Goes Toward Crowded High-Reward Site

Traits: High extraversion (5.0), low neuroticism (1.0)
Setup: Same crowded high-sugar vs isolated lower-sugar scenario
Expectation: Agent goes to crowded top-reward cell due to social preference despite risk of conflict

### Test 3: High Extraversion & Agreeableness Prefers Proximity

Traits: High extraversion (5.0), high agreeableness (5.0), low neuroticism (1.0)
Setup: Multiple equally rewarding sugar sites (3.0), one adjacent to another agent, others isolated
Expectation: Agent chooses site near another agent due to social preference and cooperative inclination

### Test 4: High Conscientiousness Takes Long-Term Efficient Path

Traits: High conscientiousness (5.0), low neuroticism (1.0)
Setup: Close low-sugar cell (2.5) vs farther high-sugar cell (5.0), both within vision
Expectation: Agent moves toward higher-rewarding site even if farther, valuing long-term gain and efficient planning

## Reproduction Rule (S): Trait-Driven

### Test 1: High Neuroticism Avoids Reproduction Despite Eligibility

Traits: High neuroticism (5.0), low openness (1.0)
Setup: Agent is fertile, has eligible partners, enough sugar, nearby positions available
Expectation: Agent refuses to reproduce citing anxiety, fear of risk, or uncertainty

### Test 2: High Agreeableness & Conscientiousness Strategic Partner Choice

Traits: High agreeableness (5.0), high conscientiousness (5.0)
Setup: Multiple eligible partners, one culturally similar, one different
Expectation: Agent chooses partner with shared values/culture, demonstrating selectivity based on harmony

### Test 3: Low Conscientiousness & High Openness Reproduces Impulsively

Traits: Low conscientiousness (1.0), high openness (5.0)
Setup: Several partners available, only one has immediate empty space nearby
Expectation: Agent reproduces quickly and impulsively with available partner, showing spontaneity and low deliberation

## Culture Rule (K): Trait-Driven

### Test 1: High Agreeableness Increases Conformity

Traits: High agreeableness (5.0), moderate conscientiousness (3.0)
Setup: Agent has neighbors with differing cultural tags
Expectation: Agent more likely to engage in cultural exchange, prioritizing social harmony and cohesion

### Test 2: Low Agreeableness & High Openness Resists Influence

Traits: Low agreeableness (1.0), high openness (5.0)
Setup: Multiple neighbors with different cultural tags
Expectation: Agent resists social influence, maintains individual culture, asserting individuality and valuing diversity

### Test 3: High Conscientiousness Strategic Cultural Adaptation

Traits: High conscientiousness (5.0), moderate agreeableness (3.0)
Setup: Neighbors with different tags, some with high sugar (beneficial), others with low sugar
Expectation: Agent adapts culture only when neighbor is "beneficial", showing selective imitation based on utility

## Credit Rule: Trait-Driven

### Test 1: High Agreeableness + Low Neuroticism = Generous Lender

Traits: High agreeableness (5.0), low neuroticism (1.0)
Setup: Lender has moderate excess sugar, borrower requests 5 units within lending limit
Expectation: Agent approves loan generously, trusting borrower and inclined to help

### Test 2: High Neuroticism = Risk-Averse Lender

Traits: Very high neuroticism (5.0), low agreeableness (1.0)
Setup: Lender has enough sugar to lend, borrower requests valid amount
Expectation: Agent refuses loan despite being allowed, due to anxiety or perceived risk

### Test 3: Low Conscientiousness = Impulsive Borrower

Traits: Low conscientiousness (1.0), moderate neuroticism (3.0)
Setup: Borrower eligible, multiple lenders available (optimal vs suboptimal)
Expectation: Agent borrows impulsively without strategic lender selection, indicating lack of planning

### Test 4: High Conscientiousness Prefers Reliable Borrower

Traits: High conscientiousness (4.5), moderate agreeableness (3.5)
Setup: Two borrowers - one reliable/stable, one unreliable/unstable
Expectation: Lender prioritizes reliable borrower, valuing planning and reliability

### Test 5: High Neuroticism + Low Agreeableness Avoids Risky Borrower

Traits: Very high neuroticism (4.8), low agreeableness (1.5)
Setup: Two borrowers - one responsible, one high-risk with poor history
Expectation: Lender avoids risky borrower due to amplified risk aversion and lack of social trust
