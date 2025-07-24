# Metric sets for scenario-specific simulation scripts
# Each constant array contains model-level metric functions relevant to a scenario

# Reproduction-only metrics
const reproduction_metrics = [
    nagents,
    model -> model.births,
    model -> model.deaths_age,
    model -> model.deaths_starvation,
    model -> calculate_gini_coefficient(model),
    model -> calculate_wealth_percentiles(model),
    model -> calculate_pareto_alpha(model),
    model -> calculate_mean_lifespan(model),
    model -> calculate_lifespan_inequality(model),
    model -> calculate_decision_entropy(model),
]

# Combat-only metrics
const combat_metrics = [
    model -> model.combat_kills,
    model -> calculate_combat_network_metrics(model),
    model -> calculate_decision_entropy(model),
    nagents
]

# Culture-only metrics
const culture_metrics = [
    model -> calculate_cultural_entropy(model),
    model -> calculate_cultural_diversity(model),
    model -> calculate_spatial_segregation(model),
    model -> calculate_clustering_coefficient(model),
    model -> count_red_tribe(model),
    model -> count_blue_tribe(model),
    model -> calculate_tribe_proportions(model),
    nagents
]

# Credit-only metrics
const credit_metrics = [
    model -> calculate_total_credit_outstanding(model),
    model -> calculate_credit_default_rate(model),
    model -> calculate_credit_network_metrics(model),
    model -> calculate_gini_coefficient(model),
    nagents
]

# Combined scenarios
const reproduction_combat_metrics = vcat(
    [nagents,
        model -> model.births,
        model -> model.deaths_age,
        model -> model.deaths_starvation,
        model -> calculate_gini_coefficient(model),
        model -> calculate_wealth_percentiles(model),
        model -> calculate_pareto_alpha(model),
        model -> calculate_mean_lifespan(model),
        model -> calculate_lifespan_inequality(model)],
    [model -> model.combat_kills,
        model -> calculate_combat_network_metrics(model),
        model -> calculate_decision_entropy(model)]
)

const reproduction_culture_metrics = vcat(
    [nagents,
        model -> model.births,
        model -> model.deaths_age,
        model -> model.deaths_starvation,
        model -> calculate_gini_coefficient(model),
        model -> calculate_wealth_percentiles(model),
        model -> calculate_pareto_alpha(model),
        model -> calculate_mean_lifespan(model),
        model -> calculate_lifespan_inequality(model)],
    [model -> calculate_cultural_entropy(model),
        model -> calculate_cultural_diversity(model),
        model -> calculate_spatial_segregation(model),
        model -> calculate_clustering_coefficient(model),
        model -> count_red_tribe(model),
        model -> count_blue_tribe(model),
        model -> calculate_tribe_proportions(model)]
)

const credit_reproduction_metrics = vcat(
    [nagents,
    model -> model.births,
    model -> model.deaths_age,
    model -> model.deaths_starvation,
    model -> calculate_total_credit_outstanding(model),
    model -> calculate_credit_default_rate(model),
    model -> calculate_credit_network_metrics(model),
    model -> calculate_gini_coefficient(model),
    model -> calculate_wealth_percentiles(model),
    model -> calculate_pareto_alpha(model),
    model -> calculate_mean_lifespan(model),
    model -> calculate_lifespan_inequality(model)]
)

const culture_credit_metrics = vcat(
    [nagents,
        model -> calculate_cultural_entropy(model),
        model -> calculate_cultural_diversity(model),
        model -> calculate_spatial_segregation(model),
        model -> calculate_clustering_coefficient(model)],
    [model -> calculate_total_credit_outstanding(model),
        model -> calculate_credit_default_rate(model),
        model -> calculate_credit_network_metrics(model),
        model -> calculate_gini_coefficient(model)]
)

const full_stack_metrics = vcat(
    [nagents,
    model -> model.births,
    model -> model.deaths_age,
    model -> model.deaths_starvation,
    model -> model.combat_kills,
    model -> calculate_total_credit_outstanding(model),
    model -> calculate_credit_default_rate(model),
    model -> calculate_credit_network_metrics(model),
    model -> calculate_combat_network_metrics(model),
    model -> calculate_decision_entropy(model),
    model -> calculate_gini_coefficient(model),
    model -> calculate_wealth_percentiles(model),
    model -> calculate_pareto_alpha(model),
    model -> calculate_mean_lifespan(model),
    model -> calculate_lifespan_inequality(model),
    model -> calculate_cultural_entropy(model),
    model -> calculate_cultural_diversity(model),
    model -> calculate_spatial_segregation(model),
    model -> calculate_clustering_coefficient(model),
    model -> calculate_trait_summary_stats(model),
    model -> calculate_trait_similarity_metrics(model),
    model -> count_red_tribe(model),
    model -> count_blue_tribe(model),
    model -> calculate_tribe_proportions(model)]
)

export reproduction_metrics,
    combat_metrics,
    culture_metrics,
    credit_metrics,
    reproduction_combat_metrics,
    reproduction_culture_metrics,
    credit_reproduction_metrics,
    culture_credit_metrics,
    full_stack_metrics
