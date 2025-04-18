import random
import numpy as np
from deap import base, creator, tools, algorithms
from utils.rmse_calculator import rmse_calculator

# GA optimizer without graphics: console-only output

def run_ga(n_orientations: int,
           population_size: int = 150, #150
           max_generations: int = 200, #200
           cxpb: float = 0.8,
           mutpb: float = 0.2,
           seed: int = None):
    """
    Run GA to optimize transmitter orientations.
    Prints progress per generation and final solution.
    Returns best individual and its fitness (CDF 90% RMS Error).
    """
    if seed is not None:
        random.seed(seed)
        np.random.seed(seed)

    nvars = 2 * n_orientations
    # Bounds for each variable: theta in [0,60], rho in [0,360]
    low = [0.0 if i % 2 == 0 else 0.0 for i in range(nvars)]
    up = [60.0 if i % 2 == 0 else 360.0 for i in range(nvars)]

    # Define fitness and individual types
    if not hasattr(creator, 'FitnessMin'):
        creator.create('FitnessMin', base.Fitness, weights=(-1.0,))
    if not hasattr(creator, 'Individual'):
        creator.create('Individual', list, fitness=creator.FitnessMin)

    toolbox = base.Toolbox()
    toolbox.register('attr_theta', random.uniform, 0.0, 60.0)
    toolbox.register('attr_rho', random.uniform, 0.0, 360.0)

    # Individual generator: alternating theta, rho
    def create_individual():
        ind = []
        for _ in range(n_orientations):
            ind.append(toolbox.attr_theta())
            ind.append(toolbox.attr_rho())
        return creator.Individual(ind)

    toolbox.register('individual', create_individual)
    toolbox.register('population', tools.initRepeat, list, toolbox.individual)
    # Custom evaluate: penalize NaN fitness to avoid NAN in GA
    def evaluate_ind(ind):
        f = rmse_calculator(ind)
        if np.isnan(f):  # invalid estimate
            return (float('inf'),)
        return (f,)
    toolbox.register('evaluate', evaluate_ind)
    toolbox.register('mate', tools.cxBlend, alpha=0.5)
    toolbox.register('mutate', tools.mutPolynomialBounded,
                     low=low, up=up, eta=20.0, indpb=1.0/nvars)
    toolbox.register('select', tools.selTournament, tournsize=3)

    pop = toolbox.population(n=population_size)
    hof = tools.HallOfFame(1)
    stats = tools.Statistics(lambda ind: ind.fitness.values)
    stats.register('min', np.min)
    stats.register('avg', np.mean)

    print(f"Starting GA: orientations={n_orientations}, pop_size={population_size}, gens={max_generations}")
    # Use DEAP's generational algorithm with verbose output
    pop, logbook = algorithms.eaSimple(
        pop, toolbox,
        cxpb=cxpb,
        mutpb=mutpb,
        ngen=max_generations,
        stats=stats,
        halloffame=hof,
        verbose=True
    )

    best = hof[0]
    best_cost = best.fitness.values[0]
    print('Best solution found:')
    for i in range(n_orientations):
        theta = best[2*i]
        rho = best[2*i+1]
        print(f"  Orientation {i+1}: theta={theta:.2f}°, rho={rho:.2f}°")
    print(f"CDF 90% RMS Error: {best_cost:.4f} m")

    return best, best_cost
