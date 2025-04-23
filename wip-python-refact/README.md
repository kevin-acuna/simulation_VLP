# VLP Simulation Experiments Python Package

This repository contains the Python refactored version of the VLP experiments originally implemented in MATLAB.

## Installation

```bash
pip install -r requirements.txt
```

## Usage

### Experiment 1: Noise Effects

```bash
cd exp_01_noise_effects
python main.py --mode ga --n 10
```

- `--mode predefined` to run with predefined orientations.
- `--n` specifies the number of orientations for GA.

## Project Structure

```
experiments/
├── optical_wireless/           # Optical channel models
├── position_estimators/        # Position estimation algorithms
├── visualization/              # Plotting utilities
└── exp_01_noise_effects/       # Experiment 1: Noise effects
    ├── optimization/           # Genetic algorithm routines
    ├── parameters/             # Setup parameters
    ├── utils/                  # RMSE & estimation wrappers
    └── main.py                # Entry point
```
