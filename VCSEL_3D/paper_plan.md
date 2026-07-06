# Plan Maestro — VCSEL Gaussian OWP (target IEEE TWC)

> **Título (principal):** *Localization-Oriented Gaussian Beam Codebook Design for VCSEL-Based Optical Wireless Systems*
> **Target:** IEEE Transactions on Wireless Communications (TWC). Fallback: IEEE TCOM / IEEE JLT.
> **Base de código:** `VCSEL_3D/` (espejo de `F_broadcast_Konly/`). Fase 1 (fundamento) completada y verificada.

---

## 1. Idea central y framing

**No** se vende como *"la versión VCSEL del broadcast OWP"* (eso es incremental). Se vende como un problema de **diseño de sistema wireless**:

> En sistemas VCSEL/OWC de haces estrechos, **la localización misma se vuelve un problema de beam training / codebook design**, sujeto a restricciones de overhead (`K`), cobertura, SNR y PEB.

Reinterpretación de las variables (clave para el framing de comunicaciones):

| Variable | Lectura "óptica" (débil) | Lectura "sistema wireless" (fuerte, TWC) |
|----------|--------------------------|------------------------------------------|
| `K` | número de orientaciones simuladas | **beam-training overhead** (mediciones de sondeo) |
| `θ_div` | divergencia del VCSEL | **variable de diseño** que controla cobertura, SNR, condicionamiento de la FIM, error de posición y posterior alineamiento de haz |
| codebook `{n_{t,i}}` | orientaciones del barrido | **libro de códigos de sondeo** a optimizar bajo restricción de overhead |

**Frase para el abstract:**
> Unlike dense angular scanning or coverage-oriented VCSEL beam control, this work studies finite-length Gaussian beam codebooks for 3D optical wireless localization, explicitly characterizing the coupling between beam divergence, probing overhead, SNR coverage, and position error bounds — and how the resulting position estimate feeds back into data-beam alignment.

---

## 2. Posicionamiento vs. estado del arte

Referencias clave (PDFs ya en `papers/`):

| Línea del SOTA | Qué hacen | Cómo nos diferenciamos |
|----------------|-----------|------------------------|
| VCSEL OWC / grid-of-beams (arXiv 2404.04443, 2102.10024, 2108.06086) | Alta tasa, SINR, clustering, beam activation, cobertura | Hacemos **localization-oriented Gaussian beam probing** con FIM/PEB y estimador eficiente |
| Q-learning VCSEL coverage (`Div_Angle_VCSEL_Final.tex`, arXiv 2602.03526) | Adaptan divergencia para maximizar cobertura/SINR (RL) | Optimizamos `K`, `θ_div` y codebook para **cobertura + precisión de posicionamiento** (bounds, no RL) |
| Single-VCSEL scanning VLP (arXiv 2601.18740, PDF en `papers/`) | Barrido angular denso (1°), AoA+RSS, alta precisión | Estudiamos **codebooks broadcast de K finito**, overhead limitado y diseño **PEB-aware** |
| TCOM propio (LED Lambertiano) | Beam-steered LED, bounds/estimadores | Tratamos el **régimen narrow-beam Gaussiano**, donde cobertura y **condicionamiento de la FIM** cambian radicalmente |

**Diferenciador teórico central (único de este paper):** en el régimen narrow-beam, en cada posición solo unas pocas orientaciones tienen `R_G(φ)` no despreciable → la FIM broadcast puede volverse **casi rango-deficiente**. La cobertura de *posicionamiento* (FIM rango-3 y bien condicionada) es más restrictiva que la cobertura de *comunicación* (SNR suficiente de un solo haz). Esto no existe en el caso Lambertiano.

---

## 3. Terminología formal

| Término | Notación | Significado |
|---------|----------|-------------|
| Codebook de sondeo | `𝒞 = {n_{t,i}}_{i=1}^K` | K orientaciones de haz que el AP dispara en la fase de probing |
| Overhead de probing | `K` | número de mediciones de sondeo (símil beam-training) |
| Divergencia | `θ_div` | semiángulo Gaussiano a 1/e² |
| Broadcast PEB | `PEB_B(r)` / `\mathrm{PEB}` | CRLB de posición 3D usando solo las K medidas, con `n_r` conocido |
| Región de servicio de localización | `𝒮_L` | conjunto de posiciones "cubiertas" (FIM rango-3 bien condicionada + SNR ≥ umbral + PEB ≤ umbral) |
| Cobertura | `C(𝒞) = |𝒮_L| / |testbed|` | fracción de posiciones cubiertas |
| Haz de datos | `k⋆(r̂)` | haz seleccionado tras la localización para transmitir datos |

> **Convención:** "PEB" sin calificador = broadcast PEB (`PEB_B`).

---

## 4. Modelo del sistema

### 4.1 Geometría y protocolo de sondeo finito
AP en el techo `t = [0,0,2]`, sala `3×3×1.2 m`. En la fase de probing el AP dispara secuencialmente `K` haces del codebook `𝒞`; cada receptor mide `K` potencias `{μ̂_i}`. Con `n_r` conocido (IMU) estima `r̂`. Broadcast: N receptores en paralelo, un solo ciclo de K.

### 4.2 Modelo de haz Gaussiano (campo lejano, potencia emitida fija)
Potencia recibida en la orientación `i`:
```
μ_i(r) = [C / (θ_div² · d²)] · exp(-2(φ_i/θ_div)²) · cos(ψ)
```
con **`C = 2·P_t·A_det/π`** (irradiancia pico `I₀ = 2P_t/(πw²)`, `w = d·θ_div`; ref. Safi et al., Ec. 8), `d = ‖r−t‖`, `φ_i = arccos(n_{t,i}·n_d)`, `cos ψ = −n_r·n_d`. Compacto: `μ_i = η · R_G(φ_i)`, `η = C·cosψ/(θ_div²·d²)`, `R_G(φ) = exp(-2(φ/θ_div)²)`.

### 4.3 Receptor y ruido
Fotodiodo área `A_det`, FOV, ruido shot+thermal aditivo gaussiano `σ²`, `N` muestras promediadas por orientación → varianza `σ²/N`.

### 4.4 SNR, cobertura y región de servicio
SNR pico (medida promediada): `SNR_i = μ_i²·N/σ²`. Cubierto ⟺ `isfinite(PEB) ∧ PEB ≤ PEB_max ∧ max_i SNR_i ≥ SNR_min`. (Implementado en `evaluate_codebook.m`.)

### 4.5 Selección de haz de datos asistida por posición (capa de comunicaciones — TWC)
Tras localizar `r̂`, el AP elige el haz de datos `k⋆ = argmax_k SNR_pred(r̂; n_{t,k})` (sobre `𝒞` o un codebook de datos más fino). Como `r̂` tiene error (gobernado por PEB), el haz puede quedar desalineado. Métricas: SNR/tasa/outage del enlace de datos evaluados en la posición **verdadera** con el haz seleccionado según la **estimada**, comparado con genie (CSI perfecta). Historia: haces estrechos dan mayor tasa pico pero exigen menor PEB para alinear ⇒ **óptimo conjunto en `θ_div`, `K`**.

---

## 5. Límites fundamentales

### 5.1 Modelo de observación
`μ̂_i = μ_i(r) + n_i`, `n_i ~ 𝒩(0, σ²/N)`. Parámetro `r = [x,y,z]^T`.

### 5.2 Gradiente y FIM (verificado por diferencias finitas)
```
∇_r μ_i = (μ_i/d)·[ α_i·(n_{t,i} − Q_i·n_d) − n_r/cosψ − 3·n_d ],   α_i = 4φ_i/(θ_div²·sinφ_i)
J_B(r)  = (N/σ²) Σᵢ ∇_r μ_i · ∇_r μ_iᵀ,     PEB_B(r) = √(tr(J_B⁻¹))
```
(límite `α_i = 4/θ_div²` en `φ_i→0`). Verificado: error rel. gradiente `1.3e-08`, PEB `6.6e-06`.

### 5.3 Métricas coverage–accuracy outage
Sobre `𝒮_L`: cobertura `C(𝒞)`, PEB media/P90, outage `1−C`. Frontera de Pareto cobertura vs P90-PEB.

### 5.4 Condicionamiento de la FIM en narrow-beam (contribución teórica)
Cuantificar `cond(J_B)` y rango efectivo vs `θ_div`, `K`: mostrar que existe un `K_min(θ_div)` por debajo del cual la localización 3D es no identificable aunque haya SNR de comunicación. `PEB_Gaussian.m` expone `cond(J_B)` como segunda salida opcional y trata `cond > 1e14` como outage.

---

## 6. Diseño de codebook orientado a localización

### 6.1 Variables de diseño
Orientaciones `{n_{t,i}}`, divergencia `θ_div`, tamaño `K` (overhead).

### 6.2 Formulación de optimización
```
maximizar   C(𝒞)              (cobertura de localización)
sujeto a    P90-PEB(𝒮_L) ≤ ε   y   |𝒞| = K
```
o su dual (minimizar P90-PEB con cobertura ≥ objetivo). **Implementado** como escalarización con GA (espejo del `optimization/` de F): fitness = agregado del *PEB efectivo* `min(PEB, PEB_pen)` con las posiciones sin cubrir fijadas a `PEB_pen` (outage clamp). Métrica del GA = `mean` (da gradiente aun con cobertura baja; `p90` satura en la penalización). Archivos: `optimization/PEB_Gaussian_objective.m`, `PEB_Gaussian_monitor.m`, `optimize_codebook_GA.m`.

### 6.3 Baselines para comparar
Todos en `generate_codebook.m`: `sunflower` (área-uniforme), `rings` (anillos + boresight), **`random`** (aleatorio área-uniforme, promediado sobre semillas en `sim06`), **`dense`** (rejilla uniforme-en-ángulo, símil barrido single-VCSEL). La referencia "dense-scanning de alto overhead" = `dense`/`sunflower` con `K` grande.

### 6.4 Overhead y complejidad
Reportar `K` como overhead de probing; comparar `K_optimizado` vs `K_baseline` para igual cobertura/precisión.

---

## 7. Estimación con K medidas Gaussianas

- **Dirección:** `vlp_nls_gaussian.m` (NLS consciente del patrón, LM). 
- **Distancia:** `broadcast_distance_Gaussian.m` (`η̂` perfilado → `d̂ = √(C·cosψ̂/(θ²·η̂))`). 
- **Identificabilidad:** K ≥ 3 orientaciones activas no coplanares. 
- **Eficiencia CRLB:** verificada — `RMSE/PEB = 1.01` (`test_estimator_roundtrip.m`).

---

## 8. Mapa de figuras ↔ scripts (con estado)

| Fig. | Contenido | Script | Estado |
|------|-----------|--------|--------|
| **1** | Comparación de patrón LED vs VCSEL (mono/multimodo) | `sim01_pattern_comparison` | ✅ Hecho |
| **2** | Cobertura vs `K`, curva por `θ_div` | `sim02_coverage_vs_K_theta` | ✅ Hecho |
| **2b** | **Mapas espaciales de cobertura** (rejilla `θ_div×K`) + cobertura vs altura *(caracterización visual)* | `sim02_b_coverage_maps` | ✅ Hecho |
| **3** | PEB media/P90/**outage** vs `K` por `θ_div` | `sim03_PEB_vs_K_theta` | ✅ Hecho |
| **4** | Frontera Pareto cobertura–precisión *(central)* | `sim04_accuracy_coverage_tradeoff` | ✅ Hecho |
| **5** | Heatmaps de PEB (optimizado vs baseline) | `sim05_PEB_heatmaps` (+`sim06`) | ⚠️ Falta overlay optimizado |
| **6** | Codebook optimizado vs baselines (cobertura/PEB) *(contribución de diseño)* | `sim06_codebook_opt` + `optimization/` | ⚙️ Máquina lista; falta correr GA completo |
| **7** | RMSE vs PEB: CDF 3D + vs SNR *(eficiencia)* | `sim07_montecarlo` | ⚠️ Parcial (1 punto) |
| **8** | LED Lambertiano vs VCSEL Gaussiano | `sim08_led_vs_vcsel` | ❌ Falta |
| **9** | Robustez: pointing / `θ_div` mismatch / error `n_r` | `sim09_robustness` | ❌ Falta |
| **10** | Tasa/outage de datos vs error de posición *(diferenciador TWC)* | `sim10_beam_management` | ❌ Falta |

---

## 9. Gap analysis (estado actual de la base de código)

| # | Resultado requerido para TWC | Estado | Dónde / qué falta |
|---|------------------------------|--------|-------------------|
| 1 | Coverage vs K vs θ_div | ✅ | `sim02` + `run_sweep_K_theta` |
| 2 | PEB media/P90/outage vs K vs θ_div | ✅ | `sim03` + `evaluate_codebook` |
| 3 | Pareto cobertura–precisión | ✅ | `sim04` |
| 4 | Optimizado vs baselines (sunflower/rings/random/dense) | ⚙️ | baselines random/dense + GA **hechos y verificados**; falta correr `optimize_codebook_GA.m` completo (pop150/gen120) |
| 5 | RMSE vs PEB Monte-Carlo (CDF, vs SNR) | ⚠️ | `test_estimator_roundtrip` (1 punto); falta barrido |
| 6 | LED vs VCSEL | ❌ | reutilizar `F_broadcast_Konly/core` (PEB LED) en harness |
| 7 | Robustez (pointing, θ_div mismatch, n_r error) | ❌ | nuevo `sim09` |
| 8 | Métrica de comunicación post-localización | ❌ (clave TWC) | nuevo módulo + `sim10` |

Núcleo teórico (FIM/PEB/estimador eficiente) y ~40% de resultados: **hechos**.

---

## 10. Estructura del paper (condensada de la propuesta TWC)

| Sec. | Contenido | Figuras |
|------|-----------|---------|
| I. Introduction | VCSEL/OWC 6G; límites del dense scanning y del beam control coverage-only; contribuciones | — |
| II. Related Work & Positioning | LED VLP; beam-steered OWP; VCSEL OWC; VCSEL positioning; research gap (§2) | — |
| III. System Model | geometría + protocolo de probing finito; haz Gaussiano; receptor/ruido; SNR/cobertura/región de servicio; selección de haz de datos | 1 |
| IV. Fundamental Limits | observación; FIM; PEB; outage coverage–accuracy; condicionamiento narrow-beam; impacto de `θ_div`,`K` | 2, 3 |
| V. Codebook Design | variables; formulación; baselines; optimización PEB/SNR-constrained; overhead | 4, 6 |
| VI. Estimation | dirección Gaussian-aware; distancia; identificabilidad; eficiencia CRLB | — |
| VII. Numerical Results | setup; validación modelo/gradiente; trade-offs; optimizado vs baselines; RMSE vs PEB; LED vs VCSEL; robustez; beam management | 5,7,8,9,10 |
| VIII. Design Guidelines | elegir `K` y `θ_div`; cuándo VCSEL supera al LED; implementación; limitaciones | — |
| IX. Conclusion | — | — |

> Reglas de escritura (de `rules_for_write_a_paper.md`): ecuaciones numeradas; ":" antes de enumerar; sin espacio tras la ecuación si el párrafo continúa; resolver notación receptor **r** vs residual **r**; cuidar ecuaciones de SNR.

---

## 11. Contribuciones (a defender)

1. **Formulación de la localización VCSEL como diseño de codebook Gaussiano finito** bajo restricción de overhead `K`.
2. **PEB broadcast Gaussiano + análisis de condicionamiento de la FIM** en régimen narrow-beam (región de servicio de localización ⊂ región de comunicación).
3. **Diseño de codebook PEB/cobertura-aware (GA)** con ganancia demostrable frente a baselines (sunflower/rings/random/dense scanning).
4. **Estimador de dos etapas eficiente** (NLS Gaussian-aware + recuperación de distancia) que alcanza el CRLB (`RMSE/PEB ≈ 1`).
5. **Trade-off cobertura–precisión** (frontera de Pareto) como herramienta de diseño de sistema.
6. **Beam management asistido por posición**: acoplamiento entre `θ_div`, `K`, error de posición y tasa/outage del enlace de datos (capa que ancla el paper en TWC).
7. **Comparación justa LED Lambertiano vs VCSEL Gaussiano** (misma potencia/área/testbed): cuándo conviene VCSEL.

---

## 12. Target venues

1. **IEEE TWC** — óptimo si se vende como *finite beam training + localization + beam management for optical wireless*.
2. **IEEE TCOM** — posible, pero cuidar solape con el TCOM propio (LED).
3. **IEEE JLT** — fallback natural si queda más centrado en óptica VCSEL/beam propagation.

Estrategia: escribir desde el inicio como **TWC**, con ruta de fallback a JLT.

---

## 13. Roadmap y progreso

| Fase | Entregable | Estado |
|------|-----------|--------|
| **1. Fundamento** | core (canal, PEB, estimadores, codebook, sweep) + sims 1–5 + validación | ✅ Completado y verificado |
| **1b. Alineación** | este `paper_plan.md` | ✅ |
| **2. Diseño** | `optimization/` (GA) + baselines random/dense + `sim06` | 🔄 Maquinaria lista y verificada; pendiente corrida GA completa |
| **3. Validación** | `sim07` Monte-Carlo (CDF, vs SNR) + `sim08` LED vs VCSEL | ⬜ Pendiente |
| **4. Robustez** | `sim09` (pointing, θ_div mismatch, n_r) | ⬜ Pendiente |
| **5. Comunicaciones (TWC)** | módulo beam management + `sim10` (tasa/outage vs error) | ⬜ Pendiente |
| **6. Redacción** | `paper/main.tex` + figuras finales | ⬜ Pendiente |

---

## 14. Log

| Fecha | Acción | Estado |
|-------|--------|--------|
| 1 Jul 2026 | Fase 1: core + sims 1–5, constante `C` corregida, validación (grad 1e-8, RMSE/PEB=1.01) | ✅ |
| 3 Jul 2026 | Reenfoque a TWC; `paper_plan.md` (framing, gap analysis, mapa de figuras) | ✅ |
| 4 Jul 2026 | Verificación alineación Fase 1 (outage en sim03, cond(FIM) expuesto, comentario constante) | ✅ |
| 4 Jul 2026 | Fase 2: baselines random/dense; `optimization/` (objetivo+monitor+driver GA); `sim06`; GA verificado end-to-end (cov 59.9%) | 🔄 falta corrida GA completa |
| 6 Jul 2026 | `sim02_b_coverage_maps`: mapas binarios de cobertura (θ×K) + cobertura vs altura (Fig. 2b) | ✅ |
