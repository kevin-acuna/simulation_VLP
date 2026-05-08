# Auditoría y Reestructuración de `fundamentals/`

## Inventario actual: 227+ archivos en 2 carpetas

---

## CLASIFICACIÓN POR USO

### 🟢 ACTIVOS — Generan figuras/datos del paper

| Archivo                                                 | Qué genera                   | Figura/Tabla                   |
| ---------------------------------------------------------| ------------------------------| --------------------------------|
| ~~`Comparison/.../main_3D_withNoise.m`~~                | **OBSOLETO** — usa funciones inline, T=[0,0,0], BUG-4 en DR | Superseded por FigCompare3D |
| `Comparison/.../original_bastien_NL_K9.m`               | NL K=9 results → .mat        | Datos Fig. 6, Table IV         |
| `Comparison/.../FigComparisonMethods.m`                 | Fig_CDF, Fig_Time            | Fig. 6 (CDF), Fig. 8 (Latency) |
| `Comparison/.../FigCompare3D_WLS_GLS.m`                 | **PRINCIPAL**: GLS+WLS+CRLB → .mat + Fig 3D | Fig. 7 + datos para Fig. 6, Table IV |
| `Comparison/.../Violin.../FigPEB_Violin_Comparison_K.m` | Violin plot                  | Fig. 2                         |
| `Comparison/.../Violin.../*.py`                         | Violin (Python)              | Fig. 2 alt                     |
| `OPTIMIZATION/optimize_PEB_orientations_parallel.m`     | GA optimization              | Table III                      |
| `OPTIMIZATION/optimize_NL_orientations_parallel.m`      | GA for NL                    | NL orientations                |
| `OPTIMIZATION/Fig_analyze_PEB_vs_noise.m`               | PEB vs SNR                   | Fig. 5                         |
| `OPTIMIZATION/Fig_analyze_PEB_vs_theta_half.m`          | PEB vs K                     | Fig. 4                         |
| `SNR_CRLB/Experiment_SNR_CRLB.m`                        | PEB vs SNR data              | Base para SIM-3                |

### 🔵 SOPORTE — Funciones llamadas por los activos

| Archivo | Función | Llamada desde |
|---------|---------|--------------|
| `Comparison/.../vlp_gls.m` | GLS estimator | main_3D_withNoise.m |
| `Comparison/.../vlp_wls.m` | WLS estimator | main_3D_withNoise.m |
| `Comparison/.../OWC_LOS_channel.m` | Canal LOS | main_3D, NL scripts |
| `Comparison/.../PEB_complete.m` | Cálculo PEB | main_3D, FigPEB_*.m |
| `OPTIMIZATION/PEB_complete.m` | PEB (DUPLICADO) | optimize_*.m |
| `OPTIMIZATION/PEB_objective.m` | Objetivo GA | optimize_PEB_*.m |
| `OPTIMIZATION/PEB_monitor.m` | Monitor GA | optimize_PEB_*.m |
| `OPTIMIZATION/NL_objective_function.m` | Objetivo NL GA | optimize_NL_orientations_parallel.m |
| `OPTIMIZATION/NL_monitor.m` | Monitor NL GA | optimize_NL_orientations_parallel.m |


### 📦 RESULTADOS — Outputs usados

| Carpeta | Contenido |
|---------|-----------|
| `Comparison/.../methods_errors_time/` | 16 .mat (K5/K9 × GLS/WLS/NL/CRLB) |
| `Comparison/.../Fig_*.png` | 5 figuras PNG del paper |
| `Comparison/.../Violin.../*.png,csv` | Violin data + figs |
| `OPTIMIZATION/optimization/` | GA results por K |
| `OPTIMIZATION/results/` | PEB figures |
| `OPTIMIZATION/analyze_PEB_vs_noise/` | Fig. 5 outputs |
| `OPTIMIZATION/analyze_PEB_vs_theta_half/` | Fig. 4 outputs |
| `SNR_CRLB/results/` | SNR analysis outputs |

### 🟡 VERIFICAR ANTES DE ARCHIVAR

| Archivo | Duda |
|---------|------|
| `FigPEB_Heatmaps.m` | ¿Genera Fig. 3 (heatmap K=5)? |
| `create_orientation_panel.m` | ¿Genera alguna figura del paper? |
| `original_bastien_n3_SVD.m` | Probablemente generó SVD_K3.mat (ya existe) |
| `calculate_PEB.m` | ¿Lo usa algún script activo? |

### 🔴 OBSOLETOS — Archivar directamente

| Archivo                                   | Razón                            |
| -------------------------------------------| ----------------------------------|
| `main_3D_withNoise.m`                     | OBSOLETO: usa funciones inline, T=[0,0,0], BUG-4 |
| `original_bastien_code.m`                 | Superseded por NL_K9             |
| `FigPotencias.m`                          | No genera figura del paper       |
| `testear_angulo_n_t_n_d_evaluar_LOS.m`    | Test (529 bytes)                 |
| `variance_electrica_optical_convertion.m` | Utilidad (143 bytes)             |
| `FigPEB_Heatmaps/`                        | Carpeta vacía                    |
| `previous_PEB.m`                          | PEB antiguo                      |
| `compare_PEB_implementations.m`           | Desarrollo                       |
| `compare_orientation_strategies.m`        | Desarrollo                       |
| `Example_using_PEB_complete.m`            | Tutorial                         |
| `optimize_PEB_orientations.m`             | Serial, superseded por _parallel |
| `README_robustness_fixes.md`              | Doc desarrollo                   |
| `test_NL_monitor.m`                       | Test                             |
| `test_NL_objective.m`                     | Test                             |
| `test_PEB_objective.m`                    | Test                             |
| `test_PEB_robustness.m`                   | Test                             |
| `test_coplanarity_detection.m`            | Test                             |
| `test_good_orientations.m`                | Test                             |
| `NL_test_K5.m`                            | Test                             |
| `NL_test_K9.m`                            | Test                             |
| `test_optimization_K5/`                   | 71 archivos de test              |
| `.mat sin "_fixed"` (K5_GLS.mat etc)      | Versiones antiguas               |

### ⚠️ DUPLICADO

`PEB_complete.m` en Comparison/ y OPTIMIZATION/. Mantener UNO en ubicación compartida.

---

## ESTRUCTURA PROPUESTA

```
fundamentals/
│
├── core/                                    ← Funciones compartidas
│   ├── OWC_LOS_channel.m
│   ├── PEB_complete.m                       ← UNA sola copia
│   ├── vlp_gls.m
│   └── vlp_wls.m
│
├── optimization/                            ← GA para orientaciones
│   ├── optimize_PEB_orientations_parallel.m
│   ├── optimize_NL_orientations_parallel.m
│   ├── PEB_objective.m
│   ├── PEB_monitor.m
│   ├── NL_objective_function.m
│   ├── NL_monitor.m
│   └── results/
│       ├── room_3x3/                        ← Orientaciones por K
│       ├── NL/
│       └── orientation_panel/
│
├── estimators/                              ← Simulación de estimadores
│   ├── FigCompare3D_WLS_GLS.m               ← PRINCIPAL: GLS, WLS, CRLB (N_or como hiperparámetro)
│   │                                         Usa vlp_gls.m y vlp_wls.m (de core/)
│   │                                         T=[0,0,2], sigma2 eléctrico, DR noise correcto
│   │                                         Genera: Fig. 7 + .mat para Fig. 6 y Table IV
│   ├── run_NL_estimator.m                   ← NL (renombrado de original_bastien_NL_K9.m)
│   └── results/
│       ├── K5_GLS_fixed.mat
│       ├── K5_WLS_fixed.mat
│       ├── K5_NL_optimized_fixed.mat
│       ├── K5_CRLB_fixed.mat
│       ├── K9_*_fixed.mat
│       └── SVD_K3.mat
│
├── figures/                                 ← Scripts de figuras
│   ├── FigComparisonMethods.m               ← Fig. 6 + 8
│   ├── FigCompare3D_WLS_GLS.m              ← Fig. 7
│   ├── FigPEB_Violin_Comparison_K.m         ← Fig. 2
│   ├── Fig_analyze_PEB_vs_noise.m           ← Fig. 5
│   ├── Fig_analyze_PEB_vs_theta_half.m      ← Fig. 4
│   ├── Fig_CDF_angular.m                    ← NUEVO (SIM-1)
│   ├── Fig_Robustness_tilt.m                ← NUEVO (SIM-2)
│   ├── Fig_RMSE_vs_SNR_estimators.m         ← NUEVO (SIM-3)
│   ├── violin_plot_comparison.py
│   └── outputs/                             ← PNGs generados
│
├── snr_analysis/
│   ├── Experiment_SNR_CRLB.m
│   └── results/
│
└── _archive/                                ← Obsoletos (no eliminar)
    ├── old_scripts/
    │   ├── main_3D_withNoise.m              ← OBSOLETO (superseded por FigCompare3D)
    │   ├── original_bastien_code.m
    │   ├── original_bastien_n3_SVD.m
    │   ├── previous_PEB.m
    │   ├── optimize_PEB_orientations.m
    │   ├── compare_*.m
    │   ├── Example_using_PEB_complete.m
    │   ├── FigPotencias.m
    │   ├── testear_angulo_*.m
    │   └── variance_electrica_*.m
    ├── tests/
    │   ├── test_*.m (8 archivos)
    │   └── NL_test_*.m (2 archivos)
    ├── test_optimization_K5/                ← 71 archivos
    └── old_mat_files/                       ← .mat sin _fixed
```

---

## VERIFICACIONES PENDIENTES

- [ ] `FigPEB_Heatmaps.m` → ¿genera Fig. 3? Si: `figures/`
- [ ] `create_orientation_panel.m` → No genera fig del paper → `_archive/`
- [ ] `calculate_PEB.m` → No lo usa ningún activo → `_archive/`
- [ ] Los .mat sin "_fixed" → FigComparisonMethods carga "_fixed" → `_archive/`

**REGLA: Nada se elimina. Todo lo que no se usa va a `_archive/`.**
**La ÚNICA excepción es `PEB_complete.m` duplicado: se mantiene 1 copia en `core/`, la otra se elimina (son idénticos).**

---

## RESUMEN

| Categoría | Archivos | Acción |
|-----------|----------|--------|
| 🟢 Activos | ~11 scripts | `optimization/`, `estimators/`, `figures/` |
| 🔵 Soporte | ~9 funciones | `core/` |
| 📦 Resultados | ~16 .mat + ~10 .png | `results/` y `outputs/` |
| 🟡 Verificar | ~4 scripts | Revisar antes de mover |
| 🔴 Obsoletos | ~20 scripts + 71 test files | `_archive/` |
| ⚠️ Duplicado | PEB_complete.m ×2 | 1 copia en `core/` |

**De ~227 archivos dispersos → ~35 activos en 5 carpetas claras + _archive.**
