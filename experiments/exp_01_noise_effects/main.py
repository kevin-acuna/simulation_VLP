"""
Main entry point for Experiment 1: Noise Effects.
"""
import sys, os
# allow imports from project root
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))
import click
from optimization.ga_optimizer import run_ga
from parameters.setup_parameters import setup_parameters
from utils.rmse_calculator import rmse_calculator

@click.command()
@click.option('--mode', type=click.Choice(['predefined','ga']), default='ga', help='Run mode')
@click.option('--n', default=3, help='Number of orientations for GA')
def main(mode: str, n: int):
    """
    Run noise effects experiment in predefined or GA mode.
    """
    if mode == 'predefined':
        # Example predefined orientations [theta, rho, ...]
        n_t_s = [0, 50, 5, 120, 5, 240, 5, 0, 5, 20]
        cdf90 = rmse_calculator(n_t_s)
        print(f"CDF 90% RMS Error (predefined): {cdf90:.4f} m")
    else:
        best, cost = run_ga(n)
        print("Best solution found:")
        for i in range(n):
            theta, rho = best[2*i], best[2*i+1]
            print(f"  Orientation {i+1}: theta={theta:.2f}°, rho={rho:.2f}°")
        print(f"RMS Error (GA): {cost:.4f} m")
        # Final evaluation
        final_rms = rmse_calculator(best)
        print(f"Final RMS Error (CDF90): {final_rms:.4f} m")

if __name__ == '__main__':
    main()
