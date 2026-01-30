"""
Neural Network Training and Testing for Visible Light Positioning (VLP)
========================================================================
This script trains a neural network using cross-validation to estimate
receiver positions based on received optical power from 4 LED transmitters.

Author: VLP Research
Date: 2026
"""

import numpy as np
import pandas as pd
import matplotlib.pyplot as plt
from sklearn.model_selection import KFold, train_test_split
from sklearn.preprocessing import StandardScaler
from sklearn.metrics import mean_squared_error, mean_absolute_error
from tensorflow import keras
from tensorflow.keras.models import Sequential
from tensorflow.keras.layers import Dense, Dropout, BatchNormalization
from tensorflow.keras.callbacks import EarlyStopping, ReduceLROnPlateau
from tensorflow.keras.optimizers import Adam
import os
import joblib

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


def load_database(database_type='datasheet'):
    """
    Load the VLP database.
    
    Parameters:
    -----------
    database_type : str
        'datasheet' or 'lambertian'
    
    Returns:
    --------
    X : ndarray
        Input features (received optical power from 4 LEDs)
    y : ndarray
        Target positions (x, y coordinates)
    """
    base_path = os.path.dirname(os.path.abspath(__file__))
    db_path = os.path.join(base_path, '..', 'database')
    
    if database_type == 'datasheet':
        file_path = os.path.join(db_path, 'database_datasheet.csv')
    elif database_type == 'lambertian':
        file_path = os.path.join(db_path, 'database_lambertian.csv')
    else:
        raise ValueError("database_type must be 'datasheet' or 'lambertian'")
    
    data = pd.read_csv(file_path, header=None)
    X = data.iloc[:, 0:4].values  # Received power from 4 LEDs
    y = data.iloc[:, 4:6].values  # Position (x, y)
    
    print(f"Database loaded: {file_path}")
    print(f"  - Samples: {X.shape[0]}")
    print(f"  - Input features: {X.shape[1]} (LED power measurements)")
    print(f"  - Output dimensions: {y.shape[1]} (x, y position)")
    
    return X, y


def create_neural_network(input_dim, output_dim):
    """
    Create a neural network model for position estimation.
    
    Parameters:
    -----------
    input_dim : int
        Number of input features
    output_dim : int
        Number of output dimensions
    
    Returns:
    --------
    model : keras.Model
        Compiled neural network model
    """
    # Arquitectura simplificada para ~961 muestras (~350 parámetros)
    # Regla: samples/params >= 10 para buena generalización
    model = Sequential([
        Dense(16, activation='relu', input_shape=(input_dim,)),
        Dense(16, activation='relu'),
        Dense(output_dim, activation='linear')
    ])
    
    # Arquitectura anterior (sobredimensionada para 961 muestras, ~20K parámetros)
    # model = Sequential([
    #     Dense(64, activation='relu', input_shape=(input_dim,)),
    #     BatchNormalization(),
    #     Dropout(0.2),
    #     
    #     Dense(128, activation='relu'),
    #     BatchNormalization(),
    #     Dropout(0.2),
    #     
    #     Dense(64, activation='relu'),
    #     BatchNormalization(),
    #     Dropout(0.1),
    #     
    #     Dense(32, activation='relu'),
    #     
    #     Dense(output_dim, activation='linear')
    # ])
    
    model.compile(
        optimizer=Adam(learning_rate=0.001),
        loss='mse',
        metrics=['mae']
    )
    
    return model


def train_with_cross_validation(X, y, n_folds=5, epochs=200, batch_size=32):
    """
    Train neural network using K-Fold cross-validation.
    
    Parameters:
    -----------
    X : ndarray
        Input features
    y : ndarray
        Target positions
    n_folds : int
        Number of cross-validation folds
    epochs : int
        Maximum training epochs
    batch_size : int
        Training batch size
    
    Returns:
    --------
    results : dict
        Training results including predictions and metrics
    """
    kfold = KFold(n_splits=n_folds, shuffle=True, random_state=42)
    
    fold_results = []
    all_predictions = np.zeros_like(y)
    all_indices = np.zeros(len(y), dtype=int)
    
    print(f"\n{'='*60}")
    print(f"Cross-Validation Training ({n_folds} folds)")
    print(f"{'='*60}")
    
    for fold, (train_idx, val_idx) in enumerate(kfold.split(X)):
        print(f"\nFold {fold + 1}/{n_folds}")
        print("-" * 40)
        
        X_train, X_val = X[train_idx], X[val_idx]
        y_train, y_val = y[train_idx], y[val_idx]
        
        # Normalize features
        scaler = StandardScaler()
        X_train_scaled = scaler.fit_transform(X_train)
        X_val_scaled = scaler.transform(X_val)
        
        # Create and train model
        model = create_neural_network(X.shape[1], y.shape[1])
        
        callbacks = [
            EarlyStopping(monitor='val_loss', patience=20, restore_best_weights=True),
            ReduceLROnPlateau(monitor='val_loss', factor=0.5, patience=10, min_lr=1e-6)
        ]
        
        history = model.fit(
            X_train_scaled, y_train,
            validation_data=(X_val_scaled, y_val),
            epochs=epochs,
            batch_size=batch_size,
            callbacks=callbacks,
            verbose=0
        )
        
        # Predictions
        y_pred = model.predict(X_val_scaled, verbose=0)
        all_predictions[val_idx] = y_pred
        all_indices[val_idx] = val_idx
        
        # Calculate metrics
        rmse = np.sqrt(mean_squared_error(y_val, y_pred))
        mae = mean_absolute_error(y_val, y_pred)
        
        # Position error (Euclidean distance)
        position_errors = np.sqrt(np.sum((y_val - y_pred) ** 2, axis=1))
        mean_pos_error = np.mean(position_errors)
        
        fold_results.append({
            'fold': fold + 1,
            'rmse': rmse,
            'mae': mae,
            'mean_position_error': mean_pos_error,
            'history': history.history
        })
        
        print(f"  RMSE: {rmse:.4f} m")
        print(f"  MAE: {mae:.4f} m")
        print(f"  Mean Position Error: {mean_pos_error:.4f} m")
    
    # Summary
    avg_rmse = np.mean([r['rmse'] for r in fold_results])
    avg_mae = np.mean([r['mae'] for r in fold_results])
    avg_pos_error = np.mean([r['mean_position_error'] for r in fold_results])
    
    print(f"\n{'='*60}")
    print("Cross-Validation Summary")
    print(f"{'='*60}")
    print(f"  Average RMSE: {avg_rmse:.4f} ± {np.std([r['rmse'] for r in fold_results]):.4f} m")
    print(f"  Average MAE: {avg_mae:.4f} ± {np.std([r['mae'] for r in fold_results]):.4f} m")
    print(f"  Average Position Error: {avg_pos_error:.4f} ± {np.std([r['mean_position_error'] for r in fold_results]):.4f} m")
    
    return {
        'fold_results': fold_results,
        'predictions': all_predictions,
        'true_values': y,
        'avg_rmse': avg_rmse,
        'avg_mae': avg_mae,
        'avg_position_error': avg_pos_error
    }


def train_final_model(X, y, test_size=0.2, epochs=200, batch_size=32):
    """
    Train final model with train/test split for testing.
    
    Parameters:
    -----------
    X : ndarray
        Input features
    y : ndarray
        Target positions
    test_size : float
        Fraction of data for testing
    epochs : int
        Maximum training epochs
    batch_size : int
        Training batch size
    
    Returns:
    --------
    results : dict
        Training results including test predictions and metrics
    """
    X_train, X_test, y_train, y_test = train_test_split(
        X, y, test_size=test_size, random_state=42
    )
    
    # Normalize features
    scaler = StandardScaler()
    X_train_scaled = scaler.fit_transform(X_train)
    X_test_scaled = scaler.transform(X_test)
    
    print(f"\n{'='*60}")
    print("Final Model Training")
    print(f"{'='*60}")
    print(f"  Training samples: {len(X_train)}")
    print(f"  Test samples: {len(X_test)}")
    
    # Create and train model
    model = create_neural_network(X.shape[1], y.shape[1])
    
    callbacks = [
        EarlyStopping(monitor='val_loss', patience=20, restore_best_weights=True),
        ReduceLROnPlateau(monitor='val_loss', factor=0.5, patience=10, min_lr=1e-6)
    ]
    
    history = model.fit(
        X_train_scaled, y_train,
        validation_split=0.15,
        epochs=epochs,
        batch_size=batch_size,
        callbacks=callbacks,
        verbose=1
    )
    
    # Test predictions
    y_pred = model.predict(X_test_scaled, verbose=0)
    
    # Calculate metrics
    rmse = np.sqrt(mean_squared_error(y_test, y_pred))
    mae = mean_absolute_error(y_test, y_pred)
    position_errors = np.sqrt(np.sum((y_test - y_pred) ** 2, axis=1))
    
    print(f"\n{'='*60}")
    print("Test Results")
    print(f"{'='*60}")
    print(f"  RMSE: {rmse:.4f} m")
    print(f"  MAE: {mae:.4f} m")
    print(f"  Mean Position Error: {np.mean(position_errors):.4f} m")
    print(f"  Max Position Error: {np.max(position_errors):.4f} m")
    print(f"  Min Position Error: {np.min(position_errors):.4f} m")
    print(f"  Std Position Error: {np.std(position_errors):.4f} m")
    
    return {
        'model': model,
        'scaler': scaler,
        'history': history.history,
        'y_test': y_test,
        'y_pred': y_pred,
        'position_errors': position_errors,
        'rmse': rmse,
        'mae': mae
    }


def plot_results(cv_results, test_results, database_type, save_path=None):
    """
    Generate scientific-quality plots for publication.
    
    Parameters:
    -----------
    cv_results : dict
        Cross-validation results
    test_results : dict
        Final model test results
    database_type : str
        Type of database used
    save_path : str
        Path to save figures
    """
    if save_path is None:
        save_path = os.path.dirname(os.path.abspath(__file__))
    
    y_test = test_results['y_test']
    y_pred = test_results['y_pred']
    position_errors = test_results['position_errors']
    
    # Figure 1: Estimated vs Reference Position (2D scatter)
    fig1, ax1 = plt.subplots(figsize=(6, 5))
    
    ax1.scatter(y_test[:, 0], y_test[:, 1], c='blue', marker='o', 
                s=30, alpha=0.6, label='Reference Position', edgecolors='darkblue', linewidths=0.5)
    ax1.scatter(y_pred[:, 0], y_pred[:, 1], c='red', marker='x', 
                s=30, alpha=0.6, label='Estimated Position', linewidths=1.5)
    
    for i in range(len(y_test)):
        ax1.plot([y_test[i, 0], y_pred[i, 0]], [y_test[i, 1], y_pred[i, 1]], 
                 'gray', alpha=0.3, linewidth=0.5)
    
    ax1.set_xlabel('X Position (m)')
    ax1.set_ylabel('Y Position (m)')
    ax1.set_title(f'Position Estimation - {database_type.capitalize()} Model')
    ax1.legend(loc='upper right')
    ax1.set_aspect('equal', adjustable='box')
    ax1.grid(True, alpha=0.3)
    
    fig1.tight_layout()
    fig1.savefig(os.path.join(save_path, f'position_estimation_{database_type}.png'), 
                 dpi=300, bbox_inches='tight')
    fig1.savefig(os.path.join(save_path, f'position_estimation_{database_type}.pdf'), 
                 bbox_inches='tight')
    
    # Figure 2: X and Y coordinate comparison
    fig2, axes2 = plt.subplots(1, 2, figsize=(10, 4))
    
    # X coordinate
    ax2a = axes2[0]
    ax2a.scatter(y_test[:, 0], y_pred[:, 0], c='steelblue', alpha=0.6, s=20, edgecolors='navy', linewidths=0.3)
    lims_x = [min(y_test[:, 0].min(), y_pred[:, 0].min()) - 0.1, 
              max(y_test[:, 0].max(), y_pred[:, 0].max()) + 0.1]
    ax2a.plot(lims_x, lims_x, 'k--', linewidth=1.5, label='Ideal')
    ax2a.set_xlabel('Reference X (m)')
    ax2a.set_ylabel('Estimated X (m)')
    ax2a.set_title('X Coordinate Estimation')
    ax2a.legend(loc='lower right')
    ax2a.set_aspect('equal', adjustable='box')
    
    # Y coordinate
    ax2b = axes2[1]
    ax2b.scatter(y_test[:, 1], y_pred[:, 1], c='coral', alpha=0.6, s=20, edgecolors='darkred', linewidths=0.3)
    lims_y = [min(y_test[:, 1].min(), y_pred[:, 1].min()) - 0.1, 
              max(y_test[:, 1].max(), y_pred[:, 1].max()) + 0.1]
    ax2b.plot(lims_y, lims_y, 'k--', linewidth=1.5, label='Ideal')
    ax2b.set_xlabel('Reference Y (m)')
    ax2b.set_ylabel('Estimated Y (m)')
    ax2b.set_title('Y Coordinate Estimation')
    ax2b.legend(loc='lower right')
    ax2b.set_aspect('equal', adjustable='box')
    
    fig2.tight_layout()
    fig2.savefig(os.path.join(save_path, f'coordinate_comparison_{database_type}.png'), 
                 dpi=300, bbox_inches='tight')
    fig2.savefig(os.path.join(save_path, f'coordinate_comparison_{database_type}.pdf'), 
                 bbox_inches='tight')
    
    # Figure 3: Position Error Distribution
    fig3, axes3 = plt.subplots(1, 2, figsize=(10, 4))
    
    # Histogram
    ax3a = axes3[0]
    ax3a.hist(position_errors * 100, bins=30, color='steelblue', edgecolor='navy', alpha=0.7)
    ax3a.axvline(np.mean(position_errors) * 100, color='red', linestyle='--', 
                 linewidth=2, label=f'Mean: {np.mean(position_errors)*100:.2f} cm')
    ax3a.axvline(np.median(position_errors) * 100, color='green', linestyle=':', 
                 linewidth=2, label=f'Median: {np.median(position_errors)*100:.2f} cm')
    ax3a.set_xlabel('Position Error (cm)')
    ax3a.set_ylabel('Frequency')
    ax3a.set_title('Position Error Distribution')
    ax3a.legend(loc='upper right')
    
    # CDF
    ax3b = axes3[1]
    sorted_errors = np.sort(position_errors) * 100
    cdf = np.arange(1, len(sorted_errors) + 1) / len(sorted_errors) * 100
    ax3b.plot(sorted_errors, cdf, 'b-', linewidth=2)
    ax3b.axhline(90, color='gray', linestyle='--', alpha=0.5)
    ax3b.axhline(50, color='gray', linestyle='--', alpha=0.5)
    p90_idx = np.argmax(cdf >= 90)
    p50_idx = np.argmax(cdf >= 50)
    ax3b.axvline(sorted_errors[p90_idx], color='red', linestyle=':', 
                 linewidth=1.5, label=f'90th percentile: {sorted_errors[p90_idx]:.2f} cm')
    ax3b.axvline(sorted_errors[p50_idx], color='green', linestyle=':', 
                 linewidth=1.5, label=f'50th percentile: {sorted_errors[p50_idx]:.2f} cm')
    ax3b.set_xlabel('Position Error (cm)')
    ax3b.set_ylabel('Cumulative Probability (%)')
    ax3b.set_title('Cumulative Distribution Function (CDF)')
    ax3b.legend(loc='lower right')
    ax3b.set_ylim([0, 100])
    
    fig3.tight_layout()
    fig3.savefig(os.path.join(save_path, f'error_distribution_{database_type}.png'), 
                 dpi=300, bbox_inches='tight')
    fig3.savefig(os.path.join(save_path, f'error_distribution_{database_type}.pdf'), 
                 bbox_inches='tight')
    
    # Figure 4: Training History
    fig4, axes4 = plt.subplots(1, 2, figsize=(10, 4))
    
    history = test_results['history']
    epochs_range = range(1, len(history['loss']) + 1)
    
    # Loss
    ax4a = axes4[0]
    ax4a.plot(epochs_range, history['loss'], 'b-', linewidth=1.5, label='Training')
    ax4a.plot(epochs_range, history['val_loss'], 'r-', linewidth=1.5, label='Validation')
    ax4a.set_xlabel('Epoch')
    ax4a.set_ylabel('Loss (MSE)')
    ax4a.set_title('Training and Validation Loss')
    ax4a.legend(loc='upper right')
    ax4a.set_yscale('log')
    
    # MAE
    ax4b = axes4[1]
    ax4b.plot(epochs_range, history['mae'], 'b-', linewidth=1.5, label='Training')
    ax4b.plot(epochs_range, history['val_mae'], 'r-', linewidth=1.5, label='Validation')
    ax4b.set_xlabel('Epoch')
    ax4b.set_ylabel('MAE (m)')
    ax4b.set_title('Training and Validation MAE')
    ax4b.legend(loc='upper right')
    
    fig4.tight_layout()
    fig4.savefig(os.path.join(save_path, f'training_history_{database_type}.png'), 
                 dpi=300, bbox_inches='tight')
    fig4.savefig(os.path.join(save_path, f'training_history_{database_type}.pdf'), 
                 bbox_inches='tight')
    
    # Figure 5: Error Heatmap
    fig5, ax5 = plt.subplots(figsize=(6, 5))
    
    scatter = ax5.scatter(y_test[:, 0], y_test[:, 1], c=position_errors * 100, 
                          cmap='RdYlGn_r', s=50, alpha=0.8, edgecolors='black', linewidths=0.3,
                          vmin=0, vmax=10)
    cbar = plt.colorbar(scatter, ax=ax5)
    cbar.set_label('Position Error (cm)')
    ax5.set_xlabel('X Position (m)')
    ax5.set_ylabel('Y Position (m)')
    ax5.set_title(f'Position Error Heatmap - {database_type.capitalize()} Model')
    ax5.set_aspect('equal', adjustable='box')
    
    fig5.tight_layout()
    fig5.savefig(os.path.join(save_path, f'error_heatmap_{database_type}.png'), 
                 dpi=300, bbox_inches='tight')
    fig5.savefig(os.path.join(save_path, f'error_heatmap_{database_type}.pdf'), 
                 bbox_inches='tight')
    
    print(f"\nFigures saved to: {save_path}")
    
    plt.show()


def main():
    """Main function to run VLP neural network training and testing."""
    
    print("="*60)
    print("VLP Neural Network Position Estimation")
    print("="*60)
    
    # Database selection
    print("\nSelect database type:")
    print("  1. Datasheet model")
    print("  2. Lambertian model")
    
    while True:
        choice = input("\nEnter choice (1 or 2): ").strip()
        if choice == '1':
            database_type = 'datasheet'
            break
        elif choice == '2':
            database_type = 'lambertian'
            break
        else:
            print("Invalid choice. Please enter 1 or 2.")
    
    # Load database
    X, y = load_database(database_type)
    
    # Cross-validation training
    cv_results = train_with_cross_validation(X, y, n_folds=5, epochs=200, batch_size=32)
    
    # Final model training and testing
    test_results = train_final_model(X, y, test_size=0.2, epochs=200, batch_size=32)
    
    # Generate plots
    plot_results(cv_results, test_results, database_type)
    
    # Save model and scaler for later use
    save_path = os.path.dirname(os.path.abspath(__file__))
    model_path = os.path.join(save_path, f'vlp_model_{database_type}.keras')
    scaler_path = os.path.join(save_path, f'vlp_scaler_{database_type}.pkl')
    
    test_results['model'].save(model_path)
    joblib.dump(test_results['scaler'], scaler_path)
    
    print(f"\nModel saved to: {model_path}")
    print(f"Scaler saved to: {scaler_path}")
    
    print("\n" + "="*60)
    print("Training and Testing Complete")
    print("="*60)


if __name__ == "__main__":
    main()
