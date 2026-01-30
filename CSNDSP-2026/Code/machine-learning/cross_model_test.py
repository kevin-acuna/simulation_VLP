"""
Cross-Model Testing for VLP Neural Network
===========================================
This script loads a trained model (Lambertian) and tests it on a different
database (Datasheet) to evaluate generalization across radiation models.

Author: VLP Research
Date: 2026
"""

import numpy as np
import pandas as pd
import matplotlib.pyplot as plt
from tensorflow import keras
import joblib
from sklearn.metrics import mean_squared_error, mean_absolute_error
import os

# Configure matplotlib for scientific publications
plt.rcParams.update({
    'font.family': 'serif',
    'font.serif': ['Times New Roman', 'DejaVu Serif'],
    'font.size': 11,
    'axes.labelsize': 12,
    'axes.titlesize': 12,
    'xtick.labelsize': 10,
    'ytick.labelsize': 10,
    'legend.fontsize': 10,
    'figure.dpi': 150,
    'savefig.dpi': 300,
    'savefig.bbox': 'tight',
    'axes.grid': True,
    'grid.alpha': 0.3,
    'axes.axisbelow': True,
})


def load_model_and_scaler(model_type='lambertian'):
    """Load trained model and scaler."""
    base_path = os.path.dirname(os.path.abspath(__file__))
    
    model_path = os.path.join(base_path, f'vlp_model_{model_type}.keras')
    scaler_path = os.path.join(base_path, f'vlp_scaler_{model_type}.pkl')
    
    model = keras.models.load_model(model_path)
    scaler = joblib.load(scaler_path)
    
    print(f"Model loaded: {model_path}")
    print(f"Scaler loaded: {scaler_path}")
    
    return model, scaler


def load_database(database_type='datasheet'):
    """Load the VLP database."""
    base_path = os.path.dirname(os.path.abspath(__file__))
    db_path = os.path.join(base_path, '..', 'database')
    
    if database_type == 'datasheet':
        file_path = os.path.join(db_path, 'database_datasheet.csv')
    elif database_type == 'lambertian':
        file_path = os.path.join(db_path, 'database_lambertian.csv')
    else:
        raise ValueError("database_type must be 'datasheet' or 'lambertian'")
    
    data = pd.read_csv(file_path, header=None)
    X = data.iloc[:, 0:4].values
    y = data.iloc[:, 4:6].values
    
    print(f"Database loaded: {file_path}")
    print(f"  - Samples: {X.shape[0]}")
    
    return X, y


def test_model(model, scaler, X, y):
    """Test model on new data."""
    X_scaled = scaler.transform(X)
    y_pred = model.predict(X_scaled, verbose=0)
    
    rmse = np.sqrt(mean_squared_error(y, y_pred))
    mae = mean_absolute_error(y, y_pred)
    position_errors = np.sqrt(np.sum((y - y_pred) ** 2, axis=1))
    
    print(f"\n{'='*60}")
    print("Cross-Model Test Results")
    print(f"{'='*60}")
    print(f"  RMSE: {rmse:.4f} m")
    print(f"  MAE: {mae:.4f} m")
    print(f"  Mean Position Error: {np.mean(position_errors):.4f} m ({np.mean(position_errors)*100:.2f} cm)")
    print(f"  Max Position Error: {np.max(position_errors):.4f} m")
    print(f"  Min Position Error: {np.min(position_errors):.4f} m")
    print(f"  Std Position Error: {np.std(position_errors):.4f} m")
    print(f"  90th Percentile: {np.percentile(position_errors, 90):.4f} m")
    
    return y_pred, position_errors


def plot_cross_model_results(y_true, y_pred, position_errors, model_type, test_type, save_path=None):
    """Generate plots for cross-model testing."""
    if save_path is None:
        save_path = os.path.dirname(os.path.abspath(__file__))
    
    # Figure 1: Estimated vs Reference Position
    fig1, ax1 = plt.subplots(figsize=(6, 5))
    
    ax1.scatter(y_true[:, 0], y_true[:, 1], c='blue', marker='o', 
                s=20, alpha=0.5, label='Reference Position', edgecolors='darkblue', linewidths=0.3)
    ax1.scatter(y_pred[:, 0], y_pred[:, 1], c='red', marker='x', 
                s=20, alpha=0.5, label='Estimated Position', linewidths=1)
    
    ax1.set_xlabel('X Position (m)')
    ax1.set_ylabel('Y Position (m)')
    ax1.set_title(f'Cross-Model Test: {model_type.capitalize()} Model on {test_type.capitalize()} Data')
    ax1.legend(loc='upper right')
    ax1.set_aspect('equal', adjustable='box')
    ax1.grid(True, alpha=0.3)
    
    fig1.tight_layout()
    fig1.savefig(os.path.join(save_path, f'cross_test_{model_type}_on_{test_type}.png'), 
                 dpi=300, bbox_inches='tight')
    fig1.savefig(os.path.join(save_path, f'cross_test_{model_type}_on_{test_type}.pdf'), 
                 bbox_inches='tight')
    
    # Figure 2: Error Distribution
    fig2, axes2 = plt.subplots(1, 2, figsize=(10, 4))
    
    # Histogram
    ax2a = axes2[0]
    ax2a.hist(position_errors * 100, bins=30, color='steelblue', edgecolor='navy', alpha=0.7)
    ax2a.axvline(np.mean(position_errors) * 100, color='red', linestyle='--', 
                 linewidth=2, label=f'Mean: {np.mean(position_errors)*100:.2f} cm')
    ax2a.axvline(np.median(position_errors) * 100, color='green', linestyle=':', 
                 linewidth=2, label=f'Median: {np.median(position_errors)*100:.2f} cm')
    ax2a.set_xlabel('Position Error (cm)')
    ax2a.set_ylabel('Frequency')
    ax2a.set_title('Position Error Distribution')
    ax2a.legend(loc='upper right')
    
    # CDF
    ax2b = axes2[1]
    sorted_errors = np.sort(position_errors) * 100
    cdf = np.arange(1, len(sorted_errors) + 1) / len(sorted_errors) * 100
    ax2b.plot(sorted_errors, cdf, 'b-', linewidth=2)
    ax2b.axhline(90, color='gray', linestyle='--', alpha=0.5)
    ax2b.axhline(50, color='gray', linestyle='--', alpha=0.5)
    p90_idx = np.argmax(cdf >= 90)
    p50_idx = np.argmax(cdf >= 50)
    ax2b.axvline(sorted_errors[p90_idx], color='red', linestyle=':', 
                 linewidth=1.5, label=f'90th percentile: {sorted_errors[p90_idx]:.2f} cm')
    ax2b.axvline(sorted_errors[p50_idx], color='green', linestyle=':', 
                 linewidth=1.5, label=f'50th percentile: {sorted_errors[p50_idx]:.2f} cm')
    ax2b.set_xlabel('Position Error (cm)')
    ax2b.set_ylabel('Cumulative Probability (%)')
    ax2b.set_title('Cumulative Distribution Function (CDF)')
    ax2b.legend(loc='lower right')
    ax2b.set_ylim([0, 100])
    
    fig2.tight_layout()
    fig2.savefig(os.path.join(save_path, f'cross_test_error_{model_type}_on_{test_type}.png'), 
                 dpi=300, bbox_inches='tight')
    fig2.savefig(os.path.join(save_path, f'cross_test_error_{model_type}_on_{test_type}.pdf'), 
                 bbox_inches='tight')
    
    # Figure 3: Error Heatmap
    fig3, ax3 = plt.subplots(figsize=(6, 5))
    
    scatter = ax3.scatter(y_true[:, 0], y_true[:, 1], c=position_errors * 100, 
                          cmap='RdYlGn_r', s=30, alpha=0.8, edgecolors='black', linewidths=0.2,
                          vmin=0, vmax=10)
    cbar = plt.colorbar(scatter, ax=ax3)
    cbar.set_label('Position Error (cm)')
    ax3.set_xlabel('X Position (m)')
    ax3.set_ylabel('Y Position (m)')
    ax3.set_title(f'Error Heatmap: {model_type.capitalize()} Model on {test_type.capitalize()} Data')
    ax3.set_aspect('equal', adjustable='box')
    
    fig3.tight_layout()
    fig3.savefig(os.path.join(save_path, f'cross_test_heatmap_{model_type}_on_{test_type}.png'), 
                 dpi=300, bbox_inches='tight')
    fig3.savefig(os.path.join(save_path, f'cross_test_heatmap_{model_type}_on_{test_type}.pdf'), 
                 bbox_inches='tight')
    
    print(f"\nFigures saved to: {save_path}")
    
    plt.show()


def main():
    """Main function for cross-model testing."""
    
    print("="*60)
    print("VLP Cross-Model Testing")
    print("="*60)
    print("\nTesting Lambertian model on Datasheet data")
    print("(Testing with data the model was NOT trained on)")
    
    # Load Lambertian model
    model, scaler = load_model_and_scaler('lambertian')
    
    # Load Datasheet database
    X, y = load_database('datasheet')
    
    # Test
    y_pred, position_errors = test_model(model, scaler, X, y)
    
    # Plot results
    plot_cross_model_results(y, y_pred, position_errors, 'lambertian', 'datasheet')
    
    print("\n" + "="*60)
    print("Cross-Model Testing Complete")
    print("="*60)


if __name__ == "__main__":
    main()
