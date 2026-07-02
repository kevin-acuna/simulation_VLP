# VCSEL_3D — OWP Broadcast con Haces Gaussianos (VCSEL)

> **Estado:** Fase 1 (Fundamento) completada y verificada.
> **Estructura:** espejo de `F_broadcast_Konly/` (core / optimization / simulations / paper).
> **Lenguaje:** MATLAB (verificado en R2024b).

---

## 1. Idea central

Extensión de la arquitectura *broadcast beam-steered OWP* (propuesta F) del emisor **Lambertiano (LED)** al emisor **Gaussiano (VCSEL)**. Un AP en el techo dispara `K` orientaciones de haz (codebook) y cada receptor se posiciona en 3D usando **solo esas K medidas** (sin medición cooperativa K+1), asumiendo `n_r` conocido (IMU).

La diferencia física clave frente al LED:

- **LED (Lambertiano):** patrón `cos^m(φ)`, haz ancho, cobertura amplia y suave.
- **VCSEL (Gaussiano):** patrón `exp(-2(φ/θ_div)²)`, haz estrecho y muy direccional → **más intensidad en boresight** pero **cobertura escasa**: hacen falta muchas orientaciones (`K` grande) o divergencia mayor (`θ_div`) para llenar la sala.

El estudio de Fase 1 caracteriza ese *trade-off* entre **cobertura** y **precisión (PEB)** en función de `K` y `θ_div`.

---

## 2. Modelo físico (constante corregida)

Potencia recibida en la orientación `i` (modelo de potencia emitida fija, campo lejano):

```
μ_i(r) = [C / (θ_div² · d²)] · exp(-2(φ_i/θ_div)²) · cos(ψ)
```

- **`C = 2·P_t·A_det/π`**  ← constante radiométrica **corregida** en esta fase.
  - Antes estaba `P_t·A_det/(2π)` (factor 4 de error → PEB ~4× mayor).
  - Correcta según la irradiancia pico Gaussiana `I₀ = 2P_t/(πw²)`, `w = d·θ_div`
    (Safi et al., *Q-Learning for 3D Coverage in VCSEL-based OWC*, Ec. 8; y `explore_VCSEL_irradiance.m`).
- `d = ‖r − t‖`, `φ_i = arccos(n_{t,i}·n_d)`, `cos(ψ) = −n_r·n_d`, `θ_div` en **radianes**.

Gradiente analítico (usado en el PEB), verificado por diferencias finitas:

```
∇_r μ_i = (μ_i/d) · [ α_i·(n_{t,i} − Q_i·n_d) − n_r/cos(ψ) − 3·n_d ]
α_i     = 4·φ_i / (θ_div²·sin φ_i)      (límite α_i = 4/θ_div² cuando φ_i → 0)
```

FIM y bound broadcast:

```
J_B(r) = (N/σ²) Σᵢ ∇_r μ_i · ∇_r μ_iᵀ        PEB(r) = √(tr(J_B⁻¹))
```

---

## 3. Archivos creados / modificados en la Fase 1

### `core/`
| Archivo | Rol |
|--------|-----|
| `PEB_Gaussian.m` *(modificado)* | Bound de posición (CRLB). Corregida la constante `C`. |
| `gaussian_channel.m` *(nuevo)* | Potencia recibida sin ruido de una orientación (modelo base). |
| `vlp_nls_gaussian.m` *(nuevo)* | Estimador de dirección NLS consciente del patrón Gaussiano (LM). |
| `broadcast_distance_Gaussian.m` *(nuevo)* | Recuperación de distancia: `η̂` perfilado → `d̂`. |
| `generate_codebook.m` *(nuevo)* | Codebooks de orientaciones en casquete esférico (sunflower / rings). |
| `evaluate_codebook.m` *(nuevo)* | PEB + SNR + cobertura por posición sobre el testbed. |
| `run_sweep_K_theta.m` *(nuevo)* | Motor del barrido `(K × θ_div)`. |

### `simulations/`
| Archivo | Rol |
|--------|-----|
| `system_params_VCSEL.m` *(modificado)* | Parámetros + config de codebook y umbrales de cobertura. |
| `validate_gradient_Gaussian.m` *(nuevo)* | Verificación del gradiente y PEB por diferencias finitas. |
| `test_estimator_roundtrip.m` *(nuevo)* | Test end-to-end del pipeline estimador (RMSE ≈ PEB). |
| `sim02_coverage_vs_K_theta.m` *(nuevo)* | Cobertura vs `K` (una curva por `θ_div`). Cachea el barrido. |
| `sim03_PEB_vs_K_theta.m` *(nuevo)* | PEB (media / P90) sobre región cubierta vs `K`. |
| `sim04_accuracy_coverage_tradeoff.m` *(nuevo)* | Frontera de Pareto cobertura vs precisión. |
| `sim05_PEB_heatmaps.m` *(nuevo)* | Mapas espaciales de PEB para configuraciones representativas. |

### Documentación
- `analysis_PEB_Gaussian.md` *(modificado)* — constante `C` actualizada.

---

## 4. Orden recomendado para comprobar y entender (paso a paso)

> Sigue este orden: cada archivo se apoya en el anterior. Los pasos con **▶ EJECUTAR**
> son verificaciones automáticas. Ejecuta desde `VCSEL_3D/simulations/`.

### Paso 1 — `simulations/system_params_VCSEL.m`
Entiende los parámetros del sistema. **Fíjate en:**
- `C_VCSEL = 2 * P_t * A_det / pi;` (constante corregida).
- `theta_div_values`, `K_values`, `theta_cap` (config del codebook).
- `SNR_min_dB` y `PEB_max_cov` (criterio de cobertura).

*Qué comprobar:* que `sigma2 = 10^(-21)*30e6` y las dimensiones de sala `L=W=3, Hmax=1.2, T=[0,0,2]` tienen sentido.

### Paso 2 — `core/gaussian_channel.m`
La fórmula base `μ_i = C/(θ²d²)·exp(-2(φ/θ)²)·cos(ψ)`. **Fíjate en:** las compuertas (FOV, `cosψ>0`, `Q_i>0`).

*Qué comprobar:* que el modelo coincide con la Ec. 8 del paper de referencia (campo lejano `w ≈ d·θ_div`).

### Paso 3 — `core/PEB_Gaussian.m`
El bound. **Fíjate en:** el gradiente `∇_r μ_i` (líneas del bucle sobre orientaciones), el término `α_i` y su límite en `φ→0`, y el manejo de FIM singular/regularización.

*Qué comprobar:* que la constante `C_opt` aquí es igual a la de `system_params`.

### Paso 4 — ▶ EJECUTAR `simulations/validate_gradient_Gaussian.m`
Verifica el gradiente y el PEB contra diferencias finitas.
```powershell
matlab -batch "validate_gradient_Gaussian"
```
**Resultado esperado (ya obtenido):**
```
Max relative gradient error : 1.284e-08
Max relative PEB error      : 6.609e-06
RESULT: PASS (both errors < 1e-04)
```
*Interpretación:* el gradiente analítico es correcto a precisión de máquina. Los puntos con `θ` estrecho salen "uncovered / ill-conditioned" porque un haz estrecho solo ilumina pocas orientaciones → FIM casi rango-deficiente (es el fenómeno físico central del VCSEL).

### Paso 5 — `core/generate_codebook.m`
Cómo se construyen las `K` orientaciones dentro de un casquete de semiángulo `theta_cap` desde el nadir. **Fíjate en:** el mapeo `sunflower` (área-uniforme: `θ = θ_cap·√(frac)`, azimut ángulo áureo).

*Qué comprobar rápido (opcional):*
```powershell
matlab -batch "addpath('../core'); nt=generate_codebook(9,50,'sunflower'); disp(nt); disp(vecnorm(nt))"
```
Todas las columnas deben ser unitarias y con `z<0` (apuntan hacia abajo).

### Paso 6 — `core/vlp_nls_gaussian.m`
Estimador de dirección. **Fíjate en:** parametrización esférica `(θ_d, φ_d, η)`, target normalizado `p_target = μ̂/max(μ̂)`, y el residual `η·R_G(φ) − p_target`.

### Paso 7 — `core/broadcast_distance_Gaussian.m`
Recuperación de distancia. **Fíjate en:** el MLE perfilado de amplitud `η̂ = Σμ̂ᵢRᵢ / ΣRᵢ²` y la inversión `d̂ = √(C·cosψ̂/(θ²·η̂))`.

### Paso 8 — ▶ EJECUTAR `simulations/test_estimator_roundtrip.m`
Verifica el pipeline completo canal → dirección → distancia bajo ruido.
```powershell
matlab -batch "test_estimator_roundtrip"
```
**Resultado esperado (ya obtenido):**
```
Noiseless position error: 0.0000 cm
MC RMSE : 1.62 cm   |   PEB : 1.60 cm   |   RMSE/PEB: 1.01
RESULT: PASS
```
*Interpretación:* `RMSE/PEB ≈ 1` ⇒ el estimador de dos etapas es **eficiente** (alcanza el CRLB). Esto valida a la vez el canal, el bound y ambos estimadores.

### Paso 9 — `core/evaluate_codebook.m`
Cómo se decide "cubierto": `isfinite(PEB) & PEB≤PEB_max_cov & maxSNR_dB≥SNR_min_dB`. Devuelve estadísticas agregadas (cobertura, media/P90 de PEB sobre lo cubierto).

### Paso 10 — `core/run_sweep_K_theta.m`
El motor del barrido `(K × θ_div)`. Genera un codebook por celda y lo evalúa.

*Qué comprobar (barrido rápido en malla gruesa):*
```powershell
matlab -batch "addpath('../core'); system_params_VCSEL; params=struct('T',T,'Pt',P_t,'A_det',A_det,'Psi_FOV',deg2rad(FOV),'sigma2',sigma2,'N',N_samples,'nr',n_r,'SNR_min_dB',SNR_min_dB,'PEB_max_cov',PEB_max_cov); [X,Y,Z]=meshgrid(-L/2:0.5:L/2,-W/2:0.5:W/2,0:0.6:Hmax); pos=[X(:),Y(:),Z(:)]'; run_sweep_K_theta([10 20 30],[9 25],pos,params,theta_cap,'sunflower');"
```
**Comportamiento esperado:** la cobertura **crece con `K` y con `θ_div`** (ej.: θ=10/K=9 → 0%, θ=20/K=25 → 74%, θ=30/K=25 → 78%).

### Paso 11 — ▶ EJECUTAR las simulaciones (figuras)
En orden (sim02 cachea el barrido fino que reutilizan sim03 y sim04):
```powershell
matlab -batch "sim02_coverage_vs_K_theta"     # cachea results/sweep_K_theta.mat + .csv
matlab -batch "sim03_PEB_vs_K_theta"           # lee la caché
matlab -batch "sim04_accuracy_coverage_tradeoff"
matlab -batch "sim05_PEB_heatmaps"
```
Las figuras (pdf/png) y el `.csv` quedan en `simulations/results/`.
El barrido fino (malla 0.2 m, K hasta 49) tarda unos minutos.

---

## 5. Resumen de verificación (ya ejecutado en R2024b)

| Comprobación | Métrica | Resultado |
|-------------|---------|-----------|
| Gradiente analítico vs FD | error rel. máx. | **1.3e-08** ✅ |
| PEB vs FIM por FD | error rel. máx. | **6.6e-06** ✅ |
| Eficiencia del estimador | RMSE / PEB | **1.01** ✅ |
| Física del barrido | cobertura vs `K`, `θ_div` | **monótona creciente** ✅ |

---

## 6. Parámetros de diseño ajustables (`system_params_VCSEL.m`)

- `theta_div_values` — divergencias a barrer [deg].
- `K_values` — número de orientaciones (slots de escaneo).
- `theta_cap` — semiángulo del casquete del codebook [deg] (≈47° cubren las esquinas a H=2 m).
- `SNR_min_dB`, `PEB_max_cov` — endurecen/relajan el criterio de cobertura.

---

## 7. Pendiente (fases siguientes)

- **Fase 2:** `optimization/` (GA para diseñar codebooks óptimos: `PEB_Gaussian_objective/_monitor/optimize_..._parallel`) + Monte-Carlo completo sobre el testbed (CDF RMSE vs PEB, estilo `sim05` de F).
- **Fase 3:** `paper/main.tex` (esqueleto del manuscrito).
