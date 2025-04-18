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


import random
from utils.rmse_calculator import rmse_calculator


n_orientations = 4
ind = [random.uniform(0,60) if i%2==0 else random.uniform(0,360) 
       for i in range(2*n_orientations)]
print(ind)
print(rmse_calculator(ind))
