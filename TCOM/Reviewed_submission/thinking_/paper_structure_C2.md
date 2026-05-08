# Estructura del Paper Revisado — Opción C2

## Hilo narrativo global

```
Problema: OWP multi-LED es complejo → single-LED necesita multi-PD o rotación Rx
    ↓
Propuesta: Beam-steered single-LED + single-PD pasivo → Direction Finding cerrado
    ↓
Propiedad clave: GLS/WLS son n_r-agnostic (Proposition 1)
    ↓
Extensión a 3D: una sola reorientación cooperativa Tx-Rx para distancia
    ↓
Resultados: GLS eficiente (MLE linealizado), robusto a tilt, cm-level 3D
```

---

## ABSTRACT

**Qué dice (borrador):**
> Single beam-steered LED + single PD para 3D indoor. K orientaciones → RSS → direction finding cerrado (GLS/WLS). Probamos que GLS/WLS son independientes de n_r. CRLB/PEB + GA para diseño. Una medición beam-aligned para distancia → 3D. Resultados: cm-level 3D, sub-degree DF, robusto a tilts.

**Cambios vs actual:**
- ~~"without receiver rotation"~~ → "direction finding independent of receiver orientation"
- ~~"achieves 3D localization without..."~~ → "a single beam-aligned measurement completes the 3D position"
- Añadir: n_r-independence, angular error, robustez a tilt

**Comments resueltos:** #3 (contradicción abstract), #5 (arbitrary)

---

## I. INTRODUCTION

**Flujo en 6 bloques:**

| # | Bloque | Contenido | Transición al siguiente |
|---|--------|-----------|------------------------|
| 1 | **Problema** | GNSS falla indoor. RF: multipath, meter-level | "OWP ofrece una alternativa..." |
| 2 | **OWP** | Ventajas ópticas. NIR desacopla de iluminación | "Dos paradigmas: data-driven vs model-based..." |
| 3 | **Paradigmas** | Data-driven (opaco, retraining). Model-based (interpretable, co-design) | "Most OWP relies on multi-LED..." |
| 4 | **Multi→Single LED** | Table I. Multi-LED: ≥4 LEDs. Single-LED: multi-PD, rotación Rx, sensores. **Gap: no existe single-LED single-PD 3D con estimadores cerrados n_r-agnostic** | "Recent beam-steering advances..." |
| 5 | **Beam steering** | MEMS, liquid crystal, OPA. Roadmaps OWC/LiFi | "In this work, we exploit beam steering for positioning..." |
| 6 | **Nuestra propuesta** | Concepto core (2 párrafos) + contribuciones (5 items) | "This paper is organized as follows..." |

**Bloque 6 — Concepto core** (NUEVO, antes de contribuciones):
> LED steers through K orientations, PD remains at fixed arbitrary pose. Power ratios cancel d and n_r → linear constraints on direction. Eigenvector solution → closed-form direction. Single cooperative Tx-Rx alignment → distance → 3D. Unlike [Liu2022, Wang2024, Shi2025] (continuous rotation) or [Qin2020, Li2024] (multi-PD arrays), our PD is static during K measurements; only one reorientation for ranging.

**Contribuciones actualizadas:**
1. Novel single-LED single-PD 3D OWP: DF n_r-agnostic + DR via single cooperative alignment
2. CRLB/PEB for composite K+1 observation model
3. GA-based orientation-set design minimizing RMSE-PEB
4. Closed-form GLS (direction MLE linealizado, eficiente) + lightweight WLS
5. **NUEVO**: Robustness demonstration under arbitrary PD tilts

**Comments resueltos:** #1 (intro sin flujo), #2 (concepto no explicado), #14a-c (gramática)

---

## II. SYSTEM MODEL AND PROPOSED LOCALIZATION METHOD

### II-A. System Model

**Contenido:** LED en t=[0,0,H], beam-steerable. PD en r=[x,y,z] desconocido. Modelo Lambertiano h_LOS, RSS, ruido AWGN, SNR.

**Cambio clave** (1 frase, Comment #5):
> "The receiver is a single PD with orientation n_r ∈ S². For concreteness, we set n_r = [0,0,1]ᵀ in the simulations. As shown in Proposition 1 (Section VI-A), the GLS/WLS direction estimators are independent of n_r; the PEB and NLS are evaluated for n_r = [0,0,1]ᵀ."

**Comment resuelto:** #5 (parcial — coherencia con Table I)

### II-B. Localization Procedure

#### II-B-1. Direction Finding
**Sin cambios** en contenido. LED steers K orientations, PD collects {P̄_{r,i}}.

#### II-B-2. Distance Recovery ← REESCRITO
**Cambios:**
- ~~"beam-forming symmetry"~~ → "cooperative alignment"
- Explícito: "LED steered to n̂_d, PD reoriented to −n̂_d. This maximizes cos ϕ ≈ 1 and cos ψ ≈ 1."
- **Remark**: "The PD reorientation is performed once, after K DF measurements during which the PD remains at an arbitrary fixed pose. Unlike [Liu2022, Wang2024, Shi2025] requiring continuous rotation."
- Fórmula: P_{r,K+1} = C/d² (sin cambios)
- Algorithm 1: "Reorient PD to n_r ← −n̂_d" (explicit)

**Comments resueltos:** #3 (beam-forming symmetry, contradicción)

---

## III. POSITION ERROR BOUND ← SIMPLIFICADO

### III-A. Fisher Information Matrix ← FUSIÓN de antiguas III-A + III-B + III-C

**Cambios:**
- ~~Log-Likelihood derivation~~ → Eliminada. Citar Kay directamente.
- Modelo estadístico: 1 párrafo (z ~ N(μ(r), σ²/N · I))
- FIM directo: "Under i.i.d. Gaussian noise, the FIM follows from the Slepian–Bangs formula [Kay, 1993]"
- Añadir frase (Comment #4a): "The dependence on r enters through d(r), cos ϕ_i(r), cos ψ(r)..."
- Mantener gradientes (direction-finding + distance-recovery)

**NUEVO párrafo** (Comment #13 — interpretar PEB):
> "The PEB is evaluated at the true position r with the distance-recovery measurement assuming perfect beam alignment (n_{t,K+1} = n_d). This genie-aided formulation follows standard CRLB practice for adaptive sensing systems [Kay, 1993]. The PEB serves as an optimistic lower bound; all estimators share the same two-stage architecture and are compared against this common benchmark."

**Comments resueltos:** #4a (μ_i(r) dependence), #4b (Secs III-A/B innecesarias), #13 (parcial — PEB interpretation)

### III-B. Position Error Bound
**Sin cambios** en contenido. PEB = sqrt(tr(I⁻¹)).

### III-C. Number of LED Orientations
**Sin cambios.**

---

## IV. ORIENTATION SET OPTIMIZATION ← CLARIFICADO

**Contenido existente:** GA minimiza RMSE-PEB, Table II (params), Table III (orientaciones óptimas), Figs (violin, heatmap, PEB vs K, PEB vs SNR).

**Adiciones:**

1. **Después de Eq. n_{t,i} esférica** (Comment #6):
> "Substituting this parameterization into the channel model and the FIM, the PEB becomes an explicit function of the 2K angles {(θ_i, φ_i)}. The GA searches over this 2K-dimensional space."

2. **Definir u_x, u_y, u_z** (Comment #4c):
> "where u_x = [1,0,0]ᵀ, u_y = [0,1,0]ᵀ, u_z = [0,0,1]ᵀ"

3. **Párrafo offline design** (Comments #7 + #8):
> "The GA is an offline system-design problem, not an online estimation problem. The 2K decision variables define the orientation set; for each candidate, the PEB is evaluated analytically over all 1,792 testbed positions. No measurements are involved — only theoretical bounds. Once fixed, the online estimation uses K measurements for 3 unknowns (overdetermined for K ≥ 4). The GA was run with multiple independent initializations; solutions differed by less than X% in RMSE-PEB, confirming convergence."

**Comments resueltos:** #4c (u_x,u_y,u_z), #6 (tilt-azimuth → CRLB), #7 (2K vs K), #8 (r fijo)

---

## V. NONLINEAR DIRECTION-FINDING BASELINE ← REPOSICIONADO

**Rol:** Baseline comparativo (NLS), NO contribución principal.

**Párrafo introductorio** (NUEVO):
> "As a baseline, we develop an iterative NLS approach that directly fits the Lambertian power model on S². This represents the class of numerical estimators in optical positioning and benchmarks the closed-form GLS/WLS of Section VI."

**Contenido:** Igual que el actual (model on S², Q_i, L, cost function F, constraints, argmin).

**Párrafo al final** (NUEVO):
> "We note that NLS requires knowledge of n_r (through L = αx+βy+γ(z−H)), unlike the ratio-based estimators developed next. Moreover, NLS does not apply statistical weighting across orientations."

**Aclaración sobre MLE** (Comment #11):
> "Although NLS minimizes a sum of squared residuals, it is not equivalent to the MLE for the direction subproblem because it does not profile out the nuisance parameter d (distance) and treats all orientations with equal weight regardless of their SNR."

**Comments resueltos:** #5 (NL requiere n_r — contraste), #11 (MLE clarification), #13 (NL no es MLE)

**Conexión con Sec. VI:** "The ratio-based approach in the next section eliminates both d and n_r from the estimation, yielding a statistically efficient closed-form solution."

---

## VI. LINEAR DIRECTION ESTIMATORS ← EXPANDIDO

### VI-A. Receiver-Orientation Independence of Power Ratios ← NUEVA

**Contenido:**
- **Proposition 1**: β_i = cos(ϕ_i)/cos(ϕ_1) — independiente de n_r y d
- Prueba: cos(ψ) y 1/d^{m+3} son comunes → cancelan en el ratio
- **Remark 1**: Propiedad matemática intrínseca, no decisión de diseño
- **Remark 2**: Contraste con NLS (que sí depende de n_r vía L)

**Conexión con Sec. V:** Justifica por qué GLS/WLS son superiores a NLS (señal limpia, sin nuisance).

**Comments resueltos:** #5 (prueba formal n_r-independence)

### VI-B. Direction Estimation via GLS ← EXPANDIDO

**Contenido existente:** β_i → a_i ⊥ d → residuos → covarianza → Mahalanobis → eigenvector.

**Adiciones** (Comment #4d — intuición):
1. **Después de β_i**: "The ratio cancels d and n_r, yielding β_i = cos(ϕ_i)/cos(ϕ_1) which depends only on direction."
2. **Después de a_i ⊥ d**: "Geometrically, each a_i · d = 0 defines a hyperplane containing the true direction. GLS weights hyperplanes inversely by their noise variance."
3. **Afirmación de eficiencia** (Comment #11):
> "Under the first-order approximation, GLS is the MLE for the ratio-based direction model and achieves the corresponding Cramér–Rao bound."

**Comments resueltos:** #4d (GLS no explicado), #11 (MLE = GLS, no NL)

### VI-C. WLS as Practical Simplification
**Contenido existente** + adición (Comment #4d):
> "The diagonal approximation is accurate when μ_1 ≫ μ_i, because off-diagonal covariance terms scale with μ_1⁻² while diagonal terms scale with μ_i⁻² + μ_1⁻²."

**Algorithm 1:** Actualizado — "Reorient PD to n_r ← −n̂_d" (Comment #3).

**Comments resueltos:** #4d (WLS no explicado)

---

## VII. SIMULATION RESULTS ← EXPANDIDO SIGNIFICATIVAMENTE

### VII-A. Direction-Finding Performance ← NUEVA SUBSECCIÓN

#### VII-A-1. Angular Error CDF ← NUEVO
- CDF de error angular acos(n̂_d · n_d) para GLS, WLS, NLS
- K=5 y K=9
- Sin bound de dirección (GLS es eficiente por teoría, no necesita curva)
- **Narrativa**: "GLS provides the lowest angular error, consistent with its statistical efficiency for the linearized ratio model."

#### VII-A-2. Robustness to Receiver Tilt ← NUEVO
- RMSE angular vs θ_tilt (0°–30°) para GLS, WLS, NLS
- **Resultado clave**: GLS/WLS planas (Proposition 1), NLS creciente
- "This confirms that the n_r-independence proven in Proposition 1 holds in practice."
- **LA figura más potente del paper revisado**

**Comments resueltos:** #5 (demostración experimental n_r-independence), #11 (nuevos resultados)

### VII-B. 3D Positioning Performance ← EXISTENTE, REORGANIZADO
- CDF 3D (Fig. 6) — regenerada con NL/WLS corregidos
- Table IV — corregida:
  - Fila "CRLB" → "PEB" con nota: "RMS-PEB, PEB₉₀, Mean PEB are deterministic spatial statistics over the testbed, not Monte Carlo estimates."
  - Valores NL y WLS actualizados (post bug-fix)
- Texto sobre el gap PEB–estimadores (Comment #13):
> "The GLS estimator outperforms NLS for two reasons: (i) power ratios eliminate nuisance parameters d and n_r, and (ii) GLS applies optimal weighting Σ_β⁻¹. The gap between all estimators and the PEB is attributable to the two-stage architecture and the genie-aided nature of the PEB (which assumes perfect beam alignment for the K+1 measurement)."

**Comments resueltos:** #12 (CRLB métricas), #13 (gap explicado)

### VII-C. Performance vs SNR ← NUEVA SUBSECCIÓN
- RMSE vs SNR (0–50 dB) para GLS, WLS, NLS, PEB
- K=5
- "All estimators converge toward the PEB at high SNR, with GLS tracking it most closely."

**Comments resueltos:** #11 (performance vs SNR)

### VII-D. Computational Complexity ← EXISTENTE
- Sin cambios en contenido
- Añadir párrafo sobre latencia (Comment #10):
> "With MEMS steering (~100 μs) and N=1000 samples at 1 MHz, K=5 DF takes ~5.5 ms plus ~1.1 ms for DR, totaling ~6.6 ms. At 1.4 m/s, displacement is ~9 mm, below cm-level accuracy."
- **Verificar números** con referencias antes de publicar

**Comments resueltos:** #10 (latencia)

### Nota sobre Fig. 9 / Fig. 2 (Comment #9)
- **Verificar** numeración en PDF compilado antes de actuar
- Reemplazar la figura redundante por CDF angular (VII-A-1)

**Comments resueltos:** #9 (redundancia)

---

## VIII. CONCLUSION AND FUTURE WORKS

**Actualizar para reflejar:**
1. Direction finding como contribución central (n_r-agnostic, GLS eficiente)
2. Distance recovery como extensión cooperativa (una reorientación)
3. Robustez a tilt demostrada
4. GLS: μs-latency, cm-level, n_r-independent
5. Future: experimental validation, joint MLE (avoid two-stage), physics-informed NN

---

## APPENDICES (sin cambios)

- Appendix A: Proof of β linearization
- Appendix B: Proof of Cov(β)

---

## TABLE I (CORREGIDA)

| Ours | Arbitrary† | 3D | GLS | 1.54 cm | 3×3×2 | Sim. |

†Direction finding is provably independent of n_r (Proposition 1, Sec. VI-A); distance recovery requires a known/controlled n_r.

**Comment resuelto:** #5

---

## Mapa: Comment → Dónde se resuelve

| # | Comment | Sección(es) donde se resuelve |
|---|---------|-------------------------------|
| 1 | Intro sin flujo | **Sec. I** (reestructurada en 6 bloques) |
| 2 | Concepto no explicado | **Sec. I** bloque 6 (párrafo core antes de contribuciones) |
| 3 | DR confuso, beam-forming symmetry | **Sec. II-B-2** (reescrito) + **Abstract** + **Algorithm 1** |
| 4a | μ_i(r) dependencia en r | **Sec. III-A** (1 frase añadida) |
| 4b | Secs III-A/B innecesarias | **Sec. III-A** (fusionadas, citar Kay) |
| 4c | u_x,u_y,u_z no definidos | **Sec. IV** (definición añadida) |
| 4d | GLS/WLS no explicados | **Sec. VI-B, VI-C** (párrafos intuitivos añadidos) |
| 5 | Table I "Arbitrary" vs modelo | **Table I** (nota †) + **Sec. II-A** (texto) + **Sec. VI-A** (Proposition 1) + **Sec. VII-A-2** (robustez tilt) |
| 6 | Tilt-azimuth → CRLB | **Sec. IV** (conexión explícita) |
| 7 | 2K unknowns vs K measurements | **Sec. IV** (párrafo offline design) |
| 8 | r fijo en optimización | **Sec. IV** (párrafo: r sweeps testbed) |
| 9 | Fig redundante | **Sec. VII-A** (reemplazar por CDF angular) |
| 10 | Latencia secuencial | **Sec. VII-D** (párrafo con cálculo) |
| 11 | Falta MLE + SNR | **Sec. V** (NL ≠ MLE) + **Sec. VI-B** (GLS = direction MLE) + **Sec. VII-C** (RMSE vs SNR) |
| 12 | CRLB métricas | **Table IV** (renombrar fila + nota) |
| 13 | Gap NL–CRLB | **Sec. III-A** (PEB genie-aided) + **Sec. V** (NL ≠ MLE) + **Sec. VII-B** (explicación two-stage + weighting) |
| 14 | Gramática | **Sec. I** (reescritura resuelve 14a,b) + **Sec. I** párrafo 3 (14c: Transformer) |

---

## Verificación de coherencia

| Claim | ¿Dónde se establece? | ¿Dónde se demuestra? | ¿Consistente? |
|-------|----------------------|----------------------|---------------|
| "DF is n_r-independent" | Abstract, Sec. I, Sec. II-A | Sec. VI-A (Proposition 1), Sec. VII-A-2 (tilt experiment) | ✅ |
| "DR requires Rx reorientation" | Abstract, Sec. II-B-2, Algorithm 1 | Sec. VII-B (resultados 3D con DR) | ✅ |
| "GLS is direction MLE" | Sec. VI-B | Theory (Mahalanobis = ML for Gaussian) | ✅ |
| "NLS is a baseline, not MLE" | Sec. V (intro + final paragraphs) | Sec. VII (GLS > NLS) | ✅ |
| "PEB is genie-aided bound" | Sec. III-A (nuevo párrafo) | Standard [Kay, 1993] | ✅ |
| "Gap is architectural" | Sec. III-A, Sec. VII-B | Two-stage + genie-aided explanation | ✅ |
| "GLS > NLS because ratios + weighting" | Sec. V (final), Sec. VII-B | Sec. VII-A (angular CDF), Sec. VII-B (3D CDF) | ✅ |
| n_r = [0,0,1] in sims | Sec. II-A | GLS/WLS universal (Prop.1), PEB/NLS for this case | ✅ |
| "Single cooperative reorientation" | Sec. II-B-2, Sec. I | Compared to [Liu2022,Wang2024,Shi2025] | ✅ |
