"""
Genetic algorithm optimizer for VLP orientation using DEAP.
"""
import random
import numpy as np
from deap import base, creator, tools, algorithms
from utils.rmse_calculator import rmse_calculator

def run_ga(n_orientations: int,
           population_size: int = 150,
           max_generations: int = 200,
           cxpb: float = 0.8,
           mutpb: float = 0.2,
           seed: int = None):
    """
    Run GA to optimize transmitter orientations.
    Returns (best_individual, best_cost).
    """
    if seed is not None:
        random.seed(seed)
        np.random.seed(seed)

    nvars = 2 * n_orientations
    low = [0.0, 0.0] * n_orientations
    up = [60.0, 360.0] * n_orientations

    # Define fitness and individual classes
    creator.create("FitnessMin", base.Fitness, weights=(-1.0,))
    creator.create("Individual", list, fitness=creator.FitnessMin)

    toolbox = base.Toolbox()
    # Attribute generators
    attr_theta = lambda: random.uniform(0.0, 60.0)
    attr_rho = lambda: random.uniform(0.0, 360.0)
    toolbox.register("individual",
                     tools.initCycle,
                     creator.Individual,
                     (attr_theta, attr_rho),
                     n_orientations)
    toolbox.register("population", tools.initRepeat, list, toolbox.individual)

    def evaluate(individual):
        return (rmse_calculator(individual),)

    toolbox.register("evaluate", evaluate)
    toolbox.register("mate", tools.cxBlend, alpha=0.5)
    toolbox.register("mutate", tools.mutPolynomialBounded,
                     low=low, up=up, eta=20.0, indpb=1.0/nvars)
    toolbox.register("select", tools.selTournament, tournsize=3)

    # Initialize population
    pop = toolbox.population(n=population_size)
    hof = tools.HallOfFame(1)
    stats = tools.Statistics(lambda ind: ind.fitness.values)
    stats.register("min", np.min)
    stats.register("avg", np.mean)

    # Run GA
    pop, log = algorithms.eaSimple(pop, toolbox,
                                   cxpb=cxpb, mutpb=mutpb,
                                   ngen=max_generations,
                                   stats=stats,
                                   halloffame=hof,
                                   verbose=True)

    best = hof[0]
    best_cost = best.fitness.values[0]
    return best, best_cost

if __name__ == "__main__":
    import click

    @click.command()
    @click.option('--n', type=int, default=3, help='Number of orientations')
    def cli(n):
        best, cost = run_ga(n)
        print(f"Best individual: {best}")
        print(f"Best cost: {cost:.4f}")
    cli()
