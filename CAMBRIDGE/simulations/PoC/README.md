# PoC — RX-steered single-anchor OWP (3D)

Prueba de concepto en MATLAB del posicionamiento 3D con **un LED fijo** y **un PD reorientable**
(gimbal 2-DOF en el marco del cuerpo). Dual del TCOM: ahora barre el receptor, no el LED.

## Archivos

| Archivo | Función |
|---|---|
| `poc_params.m` | Parámetros del sistema (LED, PD, ruido, testbed). Devuelve un struct `P`. |
| `poc_rx_steered_3D.m` | **Script principal.** Hiperparámetros al inicio; lee `poc_params`; MC sobre el testbed; tabla + 3 figuras. |
| `rx_powers.m` | Modelo LOS: $\mu_j=\eta_R\,(\mathbf n_j^B\cdot\mathbf u^B)$ con máscara de FOV. |
| `rx_ls_position.m` | Estimador cerrado: LS lineal $\boldsymbol\mu=\mathbf N\mathbf w$ → $(\hat{\mathbf u}^B,\hat\eta)$ → $\hat d$ → $\hat{\mathbf r}$. Requiere actitud $\mathbf R$. |
| `rx_peb.m` | PEB (CRLB) con el gradiente cerrado del TCOM con roles intercambiados. |
| `rx_cone_normals.m` | Genera $K$ normales en un cono alrededor de un eje (vertical o dirección estimada del LED). |
| `rotm_zyx.m` | Matriz de actitud cuerpo→mundo a partir de yaw/pitch/roll. |

## Uso

```matlab
cd CAMBRIDGE/simulations/PoC
poc_rx_steered_3D                     % diseño por defecto: 'led_centred' (2 etapas)
setenv('POC_DESIGN','wang'); poc_rx_steered_3D   % cono vertical 20° (diseño de Wang 2024)
```

Diseños (`DESIGN`):
- `led_centred` — Etapa A: cono vertical $\theta_A$ (seguro frente al FOV) → LS → $\hat{\mathbf u}^B$; Etapa B: cono de $K_B$ orientaciones centrado en $\hat{\mathbf u}^B$ con $\tan\theta_B=2$ (63.4°); LS sobre todas las medidas.
- `vertical_cone` / `wang` — una sola etapa con el cono vertical.

La actitud del cuerpo (`ATT_DEG`, yaw/pitch/roll) se asume **conocida** por el estimador (IMU / cinemática / CNC);
`ATT_ERR_DEG` inyecta error de actitud para estudiar sensibilidad.

## Resultado de referencia (04/09/2026, parámetros TCOM, 363 posiciones, 200 MC)

| Diseño | Medidas/fix | RMSE [cm] | APE [cm] | P90 [cm] | PEB-RMS [cm] | RMSE/PEB | DF [deg] |
|---|---|---|---|---|---|---|---|
| `led_centred` (A: 4×20°+nadir, B: 4×63.4°) | 9 | **4.22** | 2.61 | 5.87 | 4.16 | 1.013 | 0.66 |
| `wang` (4×20°+nadir) | 5 | 12.48 | 6.99 | 15.38 | 11.17 | 1.118 | 1.85 |

Actitud del cuerpo en ambos casos: yaw 30°, pitch 5°, roll −3° (conocida). El estimador lineal alcanza la cota
(RMSE/PEB ≈ 1) y el diseño LED-céntrico reduce el error ≈3× frente al cono vertical de 20°.
El error crece hacia los bordes (cenit del LED ≈70°) por la pérdida $\cos^m\phi\cdot\cos\psi$ con LED fijo.

Salidas en `results/`: `Fig1_testbed3D_*.png` (verdad-terreno vs estimación), `Fig2_CDF_*.png` (RMSE vs PEB),
`Fig3_orientations_heatmap_*.png` (normales del PD en el cuerpo + mapa de RMSE), `poc_results_*.mat`.
