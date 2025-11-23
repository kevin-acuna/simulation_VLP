#!/usr/bin/env python3
"""
Violin Plot Comparison: Optimized vs Random LED Orientations
============================================================

Script para generar violin plots estéticos comparando orientaciones 
optimizadas vs aleatorias usando datos PEB de archivos CSV.

Soporta dos orientaciones:
- HORIZONTAL: Eje X = PEB [cm], Eje Y = Number of orientations (K)
- VERTICAL: Eje X = Number of orientations (K), Eje Y = PEB [cm]

Author: VLP Analysis Team
Date: 2025
"""

import matplotlib as mpl

mpl.rcParams.update({
    "mathtext.fontset": "stix",      # o 'dejavuserif'
    "font.family": "STIXGeneral",    # misma familia para texto normal
})

# =============================================================================
# CONFIGURACIÓN PRINCIPAL
# =============================================================================
# Flag para elegir orientación del plot
PLOT_ORIENTATION = 'vertical'  # Opciones: 'horizontal' o 'vertical'
# =============================================================================

import pandas as pd
import numpy as np
import matplotlib.pyplot as plt
import seaborn as sns
from pathlib import Path
from scipy import stats
from scipy.ndimage import gaussian_filter1d
import warnings
warnings.filterwarnings('ignore')

# Configuración estética
plt.style.use('seaborn-v0_8-whitegrid')
sns.set_palette("husl")

def load_and_process_data(csv_optimized='PEB_optimizadas.csv', csv_random='PEB_aleatorias.csv'):
    """
    Carga y procesa los datos CSV para generar distribuciones RMS por K.
    
    Returns:
        pd.DataFrame: DataFrame con columnas ['K', 'RMS', 'Type']
    """
    print("🔄 Cargando datos desde archivos CSV...")
    
    # Leer archivos CSV
    try:
        df_opt = pd.read_csv(csv_optimized)
        df_rand = pd.read_csv(csv_random)
        print(f"  ✓ Optimizadas: {df_opt.shape[0]} filas × {df_opt.shape[1]} columnas")
        print(f"  ✓ Aleatorias: {df_rand.shape[0]} filas × {df_rand.shape[1]} columnas")
    except Exception as e:
        print(f"  ❌ Error cargando archivos: {e}")
        return None
    
    # Extraer valores K desde los nombres de columnas
    k_values = []
    for col in df_opt.columns:
        if col.startswith('K_'):
            k_values.append(int(col.split('_')[1]))
    k_values = sorted(k_values)
    
    print(f"  📊 Valores K detectados: {k_values}")
    
    # Preparar lista para almacenar datos reorganizados
    data_list = []
    
    # Procesar cada valor de K
    for k in k_values:
        col_name = f'K_{k}'
        
        # Datos optimizados para este K
        opt_data = df_opt[col_name].dropna()
        if len(opt_data) > 0:
            # Calcular RMS para cada valor (en este caso, los valores ya son PEB individuales)
            # Pero queremos la distribución de estos valores, no un RMS global
            for value in opt_data:
                if not np.isnan(value):
                    data_list.append({
                        'K': k,
                        'PEB': value,
                        'Type': 'Optimizadas',
                        'Position': k - 0.15  # Ligeramente arriba
                    })
        
        # Datos aleatorios para este K
        rand_data = df_rand[col_name].dropna()
        if len(rand_data) > 0:
            for value in rand_data:
                if not np.isnan(value):
                    data_list.append({
                        'K': k,
                        'PEB': value,
                        'Type': 'Aleatorias',
                        'Position': k + 0.15  # Ligeramente abajo
                    })
    
    # Convertir a DataFrame
    df_combined = pd.DataFrame(data_list)
    
    if df_combined.empty:
        print("  ❌ No se encontraron datos válidos")
        return None
    
    print(f"  Datos procesados: {len(df_combined)} puntos totales")
    print(f"    - Optimizadas: {len(df_combined[df_combined['Type']=='Optimizadas'])} puntos")
    print(f"    - Aleatorias: {len(df_combined[df_combined['Type']=='Aleatorias'])} puntos")
    
    return df_combined

def create_vertical_split_violin_plot(df, save_path='vertical_violin_comparison_peb.png', figsize=(10, 4), box_width=0.1):
    """
    Crea un violin plot vertical dividido estético donde cada K tiene un violin con
    mitad izquierda (optimizadas) y mitad derecha (aleatorias).
    
    Args:
        df (pd.DataFrame): DataFrame con datos procesados
        save_path (str): Ruta para guardar la figura
        figsize (tuple): Tamaño de la figura
        box_width (float): Ancho de los boxplots (default: 0.08)
    """
    
    # Configurar figura con estilo journal
    plt.rcParams.update({
        'font.family': 'serif',
        'font.serif': ['Times New Roman', 'DejaVu Serif'],
        'font.size': 11,
        'axes.linewidth': 1.2,
        'axes.spines.top': False,
        'axes.spines.right': False,
        'xtick.major.size': 4,
        'ytick.major.size': 4,
        'xtick.minor.size': 2,
        'ytick.minor.size': 2,
        'legend.frameon': True,
        'legend.fancybox': False,
        'legend.shadow': False
    })
    
    fig, ax = plt.subplots(figsize=figsize, dpi=300)
    
    # Paleta de colores para publicación científica (colorblind-friendly)
    colors = {
        'Optimizadas': '#2E8B57',    # Sea Green - más profesional
        'Aleatorias': '#CD853F'      # Peru - contraste óptimo para impresión
    }
    
    k_values = sorted(df['K'].unique())
    
    for i, k in enumerate(k_values):
        # Datos para este K
        data_opt = df[(df['K'] == k) & (df['Type'] == 'Optimizadas')]['PEB'].values*100
        data_rand = df[(df['K'] == k) & (df['Type'] == 'Aleatorias')]['PEB'].values*100
        
        x_center = k
        
        # Crear violin dividido manualmente en orientación vertical
        if len(data_opt) > 10 and len(data_rand) > 10:
            
            # Rango Y común para ambas distribuciones
            y_min = min(np.concatenate([data_opt, data_rand]))
            y_max = max(np.concatenate([data_opt, data_rand]))
            
            # Número de bins adaptativo
            n_bins = 500

            # Histograma para optimizadas (lado izquierdo)
            counts_opt, bins_opt = np.histogram(data_opt, bins=n_bins, range=(y_min, y_max), density=True)
            bin_centers_opt = (bins_opt[:-1] + bins_opt[1:]) / 2
            
            # Suavizar ligeramente los bins
            y_range = np.linspace(y_min, y_max, 200)
            density_opt = np.interp(y_range, bin_centers_opt, counts_opt)
            density_opt = gaussian_filter1d(density_opt, sigma=2.0)
            density_opt = density_opt / np.max(density_opt) * 0.4  # Normalizar ancho
            
            # Histograma para aleatorias (lado derecho)
            counts_rand, bins_rand = np.histogram(data_rand, bins=n_bins, range=(y_min, y_max), density=True)
            bin_centers_rand = (bins_rand[:-1] + bins_rand[1:]) / 2
            
            density_rand = np.interp(y_range, bin_centers_rand, counts_rand)
            density_rand = gaussian_filter1d(density_rand, sigma=2.0)
            density_rand = density_rand / np.max(density_rand) * 0.4
            
            # Crear mitad izquierda (optimizadas)
            x_left = x_center - density_opt
            x_center_line = np.full_like(y_range, x_center)
            
            ax.fill_betweenx(y_range, x_left, x_center_line,
                           facecolor=colors['Optimizadas'], alpha=0.4,
                           edgecolor=colors['Optimizadas'], linewidth=0.7)
            
            # Crear mitad derecha (aleatorias)
            x_right = x_center + density_rand
            
            ax.fill_betweenx(y_range, x_center_line, x_right,
                           facecolor=colors['Aleatorias'], alpha=0.4,
                           edgecolor=colors['Aleatorias'], linewidth=0.7)
            
            # Estadísticas para cada distribución
            q1_opt, median_opt, q3_opt = np.percentile(data_opt, [25, 50, 75])
            q1_rand, median_rand, q3_rand = np.percentile(data_rand, [25, 50, 75])
            
            # Boxplot estilizado para optimizadas (lado izquierdo)
            box_width_vert = box_width
            box_center_opt = x_center - 0.1
            
            # Caja del boxplot (optimizadas)
            box_opt = plt.Rectangle((box_center_opt - box_width_vert/2, q1_opt), 
                                   box_width_vert, q3_opt - q1_opt,
                                   facecolor=colors['Optimizadas'], edgecolor='black', 
                                   linewidth=0.7, alpha=0.8)
            ax.add_patch(box_opt)
            
            # Línea de mediana (optimizadas)
            ax.plot([box_center_opt - box_width_vert/2, box_center_opt + box_width_vert/2], 
                   [median_opt, median_opt], 'black', linewidth=0.7)
            
            # Whiskers (optimizadas)
            p5_opt, p95_opt = np.percentile(data_opt, [5, 95])
            ax.plot([box_center_opt, box_center_opt], [q3_opt, p95_opt], 'black', linewidth=0.7)
            ax.plot([box_center_opt, box_center_opt], [q1_opt, p5_opt], 'black', linewidth=0.7)
            
            # Boxplot estilizado para aleatorias (lado derecho)
            box_center_rand = x_center + 0.1
            
            # Caja del boxplot (aleatorias)
            box_rand = plt.Rectangle((box_center_rand - box_width_vert/2, q1_rand), 
                                    box_width_vert, q3_rand - q1_rand,
                                    facecolor=colors['Aleatorias'], edgecolor='black', 
                                    linewidth=0.7, alpha=0.8)
            ax.add_patch(box_rand)
            
            # Línea de mediana (aleatorias)
            ax.plot([box_center_rand - box_width_vert/2, box_center_rand + box_width_vert/2], 
                   [median_rand, median_rand], 'black', linewidth=0.7)
            
            # Whiskers (aleatorias)
            p5_rand, p95_rand = np.percentile(data_rand, [5, 95])
            ax.plot([box_center_rand, box_center_rand], [q3_rand, p95_rand], 'black', linewidth=0.7)
            ax.plot([box_center_rand, box_center_rand], [q1_rand, p5_rand], 'black', linewidth=0.7)
    
    # Configuración de ejes y etiquetas para orientación vertical
    ax.set_xlim(min(k_values)-0.45, max(k_values)+0.45)
    ax.set_ylim(0, 6.05)
    ax.set_xticks(k_values)
    
    # Etiquetas con formato journal
    ax.set_xlabel('Number of orientations ($K$)', fontsize=18, fontweight='normal')
    ax.set_ylabel('PEB [cm]', fontsize=18, fontweight='normal')
    
    # Mejorar ticks
    ax.tick_params(axis='both', which='major', labelsize=16)
    ax.set_yticks(np.arange(0, 6.05, 1))
    ax.set_yticks(np.arange(0, 6.05, 0.5), minor=True)
    
    # Grid profesional
    ax.grid(True, alpha=0.3, linestyle='-', linewidth=0.5, color='gray')
    ax.set_facecolor('white')
    
    # Spines más definidos
    ax.spines['left'].set_linewidth(1.2)
    ax.spines['bottom'].set_linewidth(1.2)
    
    # Legend estilo journal
    from matplotlib.patches import Patch
    legend_elements = [
        Patch(facecolor=colors['Optimizadas'], edgecolor='black', alpha=0.7, label='Optimized'),
        Patch(facecolor=colors['Aleatorias'], edgecolor='black', alpha=0.7, label='Random')
    ]
    legend = ax.legend(handles=legend_elements, loc='upper right', fontsize=16, 
                      framealpha=1.0, fancybox=False, shadow=False, 
                      borderpad=0.5, columnspacing=0.5, handlelength=1.5,
                      edgecolor='black')
    legend.get_frame().set_linewidth(0.8)
    
    # Ajustar layout
    plt.tight_layout()
    
    # Guardar figura con calidad journal
    plt.savefig(save_path, dpi=300, bbox_inches='tight', facecolor='white', 
                format='png', transparent=False, pad_inches=0.1)
    
    print(f"  Figura guardada: {save_path}")
    
    # Mostrar estadísticas
    print("\n Estadísticas por K:")
    print("=" * 60)
    print(f"{'K':<3} {'Opt_Mean':<10} {'Opt_Std':<10} {'Rand_Mean':<11} {'Rand_Std':<10} {'Mejora%':<8}")
    print("-" * 60)
    
    for k in sorted(df['K'].unique()):
        opt_data = df[(df['K'] == k) & (df['Type'] == 'Optimizadas')]['PEB']
        rand_data = df[(df['K'] == k) & (df['Type'] == 'Aleatorias')]['PEB']
        
        if len(opt_data) > 0 and len(rand_data) > 0:
            opt_mean = np.mean(opt_data)
            opt_std = np.std(opt_data)
            rand_mean = np.mean(rand_data)
            rand_std = np.std(rand_data)
            mejora = (rand_mean - opt_mean) / rand_mean * 100
            
            print(f"{k:<3} {opt_mean:<10.6f} {opt_std:<10.6f} {rand_mean:<11.6f} {rand_std:<10.6f} {mejora:<8.1f}")
    
    return fig, ax

def create_horizontal_split_violin_plot(df, save_path='horizontal_violin_comparison_peb.png', figsize=(10, 10), box_width=0.12):
    """
    Crea un violin plot horizontal dividido estético donde cada K tiene un violin con
    mitad superior (optimizadas) y mitad inferior (aleatorias).
    
    Args:
        df (pd.DataFrame): DataFrame con datos procesados
        save_path (str): Ruta para guardar la figura
        figsize (tuple): Tamaño de la figura
        box_width (float): Ancho de los boxplots (default: 0.12)
    """
    
    # Configurar figura con estilo journal
    plt.rcParams.update({
        'font.family': 'serif',
        'font.serif': ['Times New Roman', 'DejaVu Serif'],
        'font.size': 11,
        'axes.linewidth': 1.2,
        'axes.spines.top': False,
        'axes.spines.right': False,
        'xtick.major.size': 4,
        'ytick.major.size': 4,
        'xtick.minor.size': 2,
        'ytick.minor.size': 2,
        'legend.frameon': True,
        'legend.fancybox': False,
        'legend.shadow': False
    })
    
    fig, ax = plt.subplots(figsize=figsize, dpi=300)
    
    # Paleta de colores para publicación científica (colorblind-friendly)
    colors = {
        'Optimizadas': '#2E8B57',    # Sea Green - más profesional
        'Aleatorias': '#CD853F'      # Peru - contraste óptimo para impresión
    }
    
    k_values = sorted(df['K'].unique())
    
    for i, k in enumerate(k_values):
        # Datos para este K
        data_opt = df[(df['K'] == k) & (df['Type'] == 'Optimizadas')]['PEB'].values*100
        data_rand = df[(df['K'] == k) & (df['Type'] == 'Aleatorias')]['PEB'].values*100
        
        y_center = k
        
        # Crear violin dividido manualmente en orientación horizontal
        if len(data_opt) > 10 and len(data_rand) > 10:
            
            # Usar histogramas para representación fiel de distribuciones no gaussianas
            
            # Rango X común para ambas distribuciones (ahora PEB está en X)
            x_min = min(np.concatenate([data_opt, data_rand]))
            x_max = max(np.concatenate([data_opt, data_rand]))
            
            # Número de bins adaptativo basado en la cantidad de datos
            n_bins = min(int(np.sqrt(len(data_opt))), 60)  # Entre 10-60 bins
            n_bins = 500

            # Histograma para optimizadas (lado superior)
            counts_opt, bins_opt = np.histogram(data_opt, bins=n_bins, range=(x_min, x_max), density=True)
            bin_centers_opt = (bins_opt[:-1] + bins_opt[1:]) / 2
            
            # Suavizar ligeramente los bins para evitar escalones abruptos
            x_range = np.linspace(x_min, x_max, 200)
            density_opt = np.interp(x_range, bin_centers_opt, counts_opt)

            # Aplicar un filtro suave para eliminar puntas y mejorar visualización
            density_opt = gaussian_filter1d(density_opt, sigma=2.0)
            density_opt = density_opt / np.max(density_opt) * 0.4  # Normalizar ancho
            
            # Histograma para aleatorias (lado inferior)
            counts_rand, bins_rand = np.histogram(data_rand, bins=n_bins, range=(x_min, x_max), density=True)
            bin_centers_rand = (bins_rand[:-1] + bins_rand[1:]) / 2
            
            # Suavizar ligeramente los bins
            density_rand = np.interp(x_range, bin_centers_rand, counts_rand)
            density_rand = gaussian_filter1d(density_rand, sigma=2.0)
            density_rand = density_rand / np.max(density_rand) * 0.4  # Normalizar ancho
            
            # Crear mitad superior (optimizadas)
            y_top = y_center + density_opt
            y_center_line = np.full_like(x_range, y_center)
            
            ax.fill_between(x_range, y_center_line, y_top,
                           facecolor=colors['Optimizadas'], alpha=0.4,
                           edgecolor=colors['Optimizadas'], linewidth=0.7)
            
            # Crear mitad inferior (aleatorias)
            y_bottom = y_center - density_rand
            
            ax.fill_between(x_range, y_bottom, y_center_line,
                           facecolor=colors['Aleatorias'], alpha=0.4,
                           edgecolor=colors['Aleatorias'], linewidth=0.7)
            
            # Estadísticas para cada distribución
            q1_opt, median_opt, q3_opt = np.percentile(data_opt, [25, 50, 75])
            q1_rand, median_rand, q3_rand = np.percentile(data_rand, [25, 50, 75])
            
            # Boxplot estilizado para optimizadas (lado superior)
            box_height = box_width
            box_center_opt = y_center + 0.1
            
            # Caja del boxplot (optimizadas)
            box_opt = plt.Rectangle((q1_opt, box_center_opt - box_height/2), 
                                   q3_opt - q1_opt, box_height,
                                   facecolor=colors['Optimizadas'], edgecolor='black', 
                                   linewidth=0.7, alpha=0.8)
            ax.add_patch(box_opt)
            
            # Línea de mediana (optimizadas)
            ax.plot([median_opt, median_opt], 
                   [box_center_opt - box_height/2, box_center_opt + box_height/2], 
                   color='black', linewidth=0.7)
            
            # Whiskers (optimizadas)
            p5_opt, p95_opt = np.percentile(data_opt, [5, 95])
            ax.plot([q3_opt, p95_opt], [box_center_opt, box_center_opt], 
                   color='black', linewidth=0.7)
            ax.plot([q1_opt, p5_opt], [box_center_opt, box_center_opt], 
                   color='black', linewidth=0.7)

            
            # Boxplot estilizado para aleatorias (lado inferior)
            box_center_rand = y_center - 0.1
            
            # Caja del boxplot (aleatorias)
            box_rand = plt.Rectangle((q1_rand, box_center_rand - box_height/2), 
                                    q3_rand - q1_rand, box_height,
                                    facecolor=colors['Aleatorias'], edgecolor='black', 
                                    linewidth=0.7, alpha=0.8)
            ax.add_patch(box_rand)
            
            # Línea de mediana (aleatorias)
            ax.plot([median_rand, median_rand], 
                   [box_center_rand - box_height/2, box_center_rand + box_height/2], 
                   color='black', linewidth=0.7)
            
            # Whiskers (aleatorias)
            p5_rand, p95_rand = np.percentile(data_rand, [5, 95])
            ax.plot([q3_rand, p95_rand], [box_center_rand, box_center_rand], 
                   color='black', linewidth=0.7)
            ax.plot([q1_rand, p5_rand], [box_center_rand, box_center_rand], 
                   color='black', linewidth=0.7)
    
    # Configuración de ejes y etiquetas para publicación
    ax.set_ylim(min(k_values)-0.45, max(k_values)+0.45)
    ax.set_xlim(0, 10)
    ax.set_yticks(k_values)
    ax.invert_yaxis()  # Invertir eje Y para mostrar K en orden ascendente (3,4,5...9)
    
    # Etiquetas con formato journal
    ax.set_ylabel('Number of orientations (K)', fontsize=18, fontweight='normal')
    ax.set_xlabel('Position Error Bound [cm]', fontsize=18, fontweight='normal')
    
    # Mejorar ticks
    ax.tick_params(axis='both', which='major', labelsize=16)
    ax.set_xticks(np.arange(0, 11, 2))
    ax.set_xticks(np.arange(0, 11, 1), minor=True)
    
    # Grid profesional
    ax.grid(True, alpha=0.3, linestyle='-', linewidth=0.5, color='gray')
    ax.set_facecolor('white')
    
    # Spines más definidos
    ax.spines['left'].set_linewidth(1.2)
    ax.spines['bottom'].set_linewidth(1.2)
    
    # Legend estilo journal
    from matplotlib.patches import Patch
    legend_elements = [
        Patch(facecolor=colors['Optimizadas'], edgecolor='black', alpha=0.7, label='Optimized'),
        Patch(facecolor=colors['Aleatorias'], edgecolor='black', alpha=0.7, label='Random')
    ]
    legend = ax.legend(handles=legend_elements, loc='upper right', fontsize=16, 
                      framealpha=1.0, fancybox=False, shadow=False, 
                      borderpad=0.5, columnspacing=0.5, handlelength=1.5,
                      edgecolor='black')
    legend.get_frame().set_linewidth(0.8)
    
    # Ajustar layout
    plt.tight_layout()
    
    # Guardar figura con calidad journal
    plt.savefig(save_path, dpi=300, bbox_inches='tight', facecolor='white', 
                format='png', transparent=False, pad_inches=0.1)
    
    # PDF generation removed per user request
    print(f"  ✓ Figura guardada: {save_path}")
    
    # Mostrar estadísticas
    print("\n📊 Estadísticas por K (en centímetros):")
    print("=" * 75)
    print(f"{'K':<3} {'Opt_Mean[cm]':<12} {'Opt_Std[cm]':<12} {'Rand_Mean[cm]':<13} {'Rand_Std[cm]':<12} {'Mejora%':<8}")
    print("-" * 75)
    
    for k in sorted(df['K'].unique()):
        opt_data = df[(df['K'] == k) & (df['Type'] == 'Optimizadas')]['PEB']
        rand_data = df[(df['K'] == k) & (df['Type'] == 'Aleatorias')]['PEB']
        
        if len(opt_data) > 0 and len(rand_data) > 0:
            # Convertir a centímetros para mostrar estadísticas
            opt_mean_cm = np.mean(opt_data) * 100
            opt_std_cm = np.std(opt_data) * 100
            rand_mean_cm = np.mean(rand_data) * 100
            rand_std_cm = np.std(rand_data) * 100
            mejora = (rand_mean_cm - opt_mean_cm) / rand_mean_cm * 100
            
            print(f"{k:<3} {opt_mean_cm:<12.3f} {opt_std_cm:<12.3f} {rand_mean_cm:<13.3f} {rand_std_cm:<12.3f} {mejora:<8.1f}")
    
    return fig, ax

def main():
    """
    Función principal que ejecuta la generación del violin plot según la orientación seleccionada.
    """
    print(f"🎻 Generando Violin Plot {PLOT_ORIENTATION.title()} - PEB vs K")
    print("=" * 50)
    
    # Cargar y procesar datos
    df = load_and_process_data()
    
    if df is not None:
        if PLOT_ORIENTATION.lower() == 'horizontal':
            # Crear violin plot horizontal
            fig, ax = create_horizontal_split_violin_plot(df)
            print("\n✅ Proceso completado exitosamente!")
            print("📈 El violin plot horizontal muestra:")
            print("   • Eje X: PEB [cm]")
            print("   • Eje Y: Number of orientations (K)")
            print("   • Mitad superior: Orientaciones optimizadas")
            print("   • Mitad inferior: Orientaciones aleatorias")
            
        elif PLOT_ORIENTATION.lower() == 'vertical':
            # Crear violin plot vertical
            fig, ax = create_vertical_split_violin_plot(df)
            print("\n✅ Proceso completado exitosamente!")
            print("📈 El violin plot vertical muestra:")
            print("   • Eje X: Number of orientations (K)")
            print("   • Eje Y: PEB [cm]")
            print("   • Mitad izquierda: Orientaciones optimizadas")
            print("   • Mitad derecha: Orientaciones aleatorias")
            
        else:
            print(f"❌ Orientación '{PLOT_ORIENTATION}' no válida. Use 'horizontal' o 'vertical'")
            return
            
        #plt.show()
        
    else:
        print("❌ No se pudieron cargar los datos")
    
if __name__ == "__main__":
    main()
