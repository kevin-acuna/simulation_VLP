# Plan de Acción Final — Opción C2 (Actualizado 06/05/2026)

## Decisión tomada
**Opción C2**: Direction Finding como contribución principal (n_r-agnostic). Distance Recovery beamformed (con reorientación del Rx) presentado transparentemente como extensión para 3D. Resultados existentes se conservan.

---

## ESTADO DE SIMULACIONES (actualizado 06/05/2026)

### ✅ COMPLETADAS

| Simulación | Script | Datos clave |
|---|---|---|
| **SIM-1: DF angular CDF** | `run_DF_comparison_MC_parallel.m` | GLS 0.66°, WLS 0.77°, NL 0.63°, DEB 0.52° (K=5, M=1000) |
| **SIM-2: Robustez a tilt** | `run_nr_random_tilt_MC_parallel.m` | Degradación: GLS +2.24%, WLS +2.62%, NL +1.68%, DEB +1.69% |
| **SIM-4: 3D positioning** | `run_3D_comparison_MC_parallel.m` | GLS 2.52cm, WLS 2.92cm, NL 2.40cm, PEB 1.64cm (K=5, M=1000) |

### ⏳ PENDIENTES

| Simulación | Propósito |
|---|---|
| **SIM-3: RMSE vs SNR** | Comment #11 (performance vs SNR) |

### Resultados numéricos (de `comparison_DF_best.txt`)

**Direction Finding** — GLS/WLS con `orientations_GLS_DF_K5_MC10`, NL/DEB con `orientations_DEB_K5`:
```
Method    RMSE [°]   CDF90 [°]   Mean [°]
GLS       0.6565     0.9936      0.5410
WLS       0.7652     1.1382      0.6101
NL-MLE    0.6296     0.8105      0.5166
DEB       0.5183     0.7513      0.4642
```

**3D Positioning** — mismos sets:
```
Method    RMSE [cm]  CDF90 [cm]  Mean [cm]
GLS       2.52       3.93        2.00
WLS       2.92       4.49        2.25
NL-MLE    2.40       3.23        1.90
PEB       1.64       2.53        1.43
```

**Robustez a tilt** (σ_tilt=5°, max=30°, N_tilt=100, M=1000):
```
Method    Baseline    Random Tilt   Degradation
GLS       0.6567°     0.6714°       +2.24%
WLS       0.7655°     0.7856°       +2.62%
NL-MLE    0.6204°     0.6308°       +1.68%
DEB       0.5183°     0.5271°       +1.69%
```

### Nota: Sets de orientaciones por estimador

- **Set principal** (`orientations_DEB_K5`): Optimizado vía GA con DEB como función de coste (`optimize_DEB_orientations_parallel.m`). Usado por NL-MLE y como referencia para DEB/PEB.
- **Set secundario** (`orientations_GLS_DF_K5_MC10`): Optimizado vía GA con RMSE angular del GLS como función de coste (`optimize_GLS_DF_orientations_parallel.m`). Usado por GLS/WLS para fair comparison (cada estimador opera con su set óptimo).

En el paper, Sec. IV presenta la optimización DEB/PEB como contribución principal. El set GLS se menciona como remark para justificar la comparación justa en simulaciones.

---

## HALLAZGO CLAVE: TODOS LOS ESTIMADORES SON n_r-AGNOSTIC

### Análisis (ver `analysis_nr_agnosticism.md`)

El canal LOS se factoriza como $P_{r,i} = \alpha(\mathbf{n}_r, d) \cdot Q_i^m(\mathbf{v}_{tr})$, con $\alpha$ común a todas las orientaciones:

| Mecanismo | Estimador | Cómo elimina α |
|---|---|---|
| Ratios explícitos | GLS, WLS | $\beta_i = (\mu_i/\mu_1)^{1/m}$ → α cancela |
| Normalización + η libre | NL-MLE | $p_i/\max p_j$ → α cancela; η absorbe residuo |
| FIM teórico | DEB | FIM ∝ α²/σ² — degrada solo vía SNR |

**Implicación**: La Proposition 1 se actualiza para incluir NL-MLE. Los tres estimadores son n_r-independent. La degradación de ~2% es puramente por reducción de SNR (cos ψ baja con tilt), NO por sesgo estructural.

---

## NUEVA ESTRUCTURA DEL PAPER

```
ABSTRACT (reescribir)

I.   INTRODUCTION (reestructurar)
     Notation (sin cambios)

II.  SYSTEM MODEL AND PROPOSED LOCALIZATION METHOD
     A. System Model (ajustes menores)
     B. Localization Procedure
        1) Direction Finding (sin cambios en contenido)
        2) Distance Recovery (reescribir: transparente sobre Rx reorientation)
           - Fórmula de DR: d = sqrt(P_t(m+1)A_det / (2π · P_{K+1}))
           - Común a TODOS los estimadores (NL, GLS, WLS)
           - Único paso que requiere reorientación del Rx

III. DIRECTION ERROR BOUND AND POSITION ERROR BOUND
     A. Fisher Information Matrix (fusionar antiguas III-A+B+C, citar Kay)
        - Modelo estadístico (1 párrafo)
        - FIM vía Slepian-Bangs [Kay 1993]: J = (1/σ²) Σ ∇μ_i ∇μ_i^T
        - Gradientes (de antigua III-C)
     B. Direction Error Bound (DEB)                          ← NUEVA
        - DEFINICIÓN: "We define the Direction Error Bound (DEB) as the
          Cramér-Rao lower bound for the angular estimation error of the
          direction d ∈ S², computed from the K direction-finding measurements only."
        - DEB = f(FIM_DF) — bound para DF solamente
        - Independiente de la etapa de DR
        - Permite evaluar estimadores de dirección en isolation
     C. Position Error Bound (PEB)
        - PEB = f(FIM_DF + FIM_DR) — bound para posición 3D completa
        - Genie-aided: asume beam alignment perfecto en K+1
        - Lower bound optimista (no alcanzable en práctica)
     D. Number of LED Orientations

IV.  ORIENTATION SET OPTIMIZATION
     - Función de coste principal: DEB (o PEB) promediado sobre el testbed
     - GA busca minimizar RMSE del DEB/PEB sobre 1,792 posiciones
     - Resultado: orientations_DEB_K5 (set óptimo para bounds)
     - Remark: los estimadores lineales (GLS/WLS) también pueden optimizarse
       con su propia función de coste (RMSE angular del GLS), produciendo un
       set ligeramente distinto (orientations_GLS_DF_K5). En las simulaciones,
       cada estimador usa su set óptimo para fair comparison.

V.   NONLINEAR DIRECTION ESTIMATOR (NLS)
     - Estimador iterativo sobre modelo normalizado en S²
     - n_r-agnostic vía normalización p_i/max(p_j) + η libre
     - Mejor precisión en DF (0.63° vs GLS 0.66°) — no lineariza
     - Mayor latencia (ms vs μs)

VI.  LINEAR DIRECTION ESTIMATORS
     A. Receiver-Orientation Independence (Proposition 1)
        - Incluye NL-MLE, GLS, WLS — TODOS son n_r-independent
     B. Direction Estimation via GLS (expandir explicación)
     C. WLS as Practical Simplification (expandir explicación)

VII. SIMULATION RESULTS
     A. Direction-Finding Performance                       ← COMPLETADA
        1) Angular Error CDF (DEB, NL, GLS, WLS)
        2) Robustness to Receiver Tilt (todos ~2% degradación)
     B. 3D Positioning Performance (DF + DR, con PEB como bound)
     C. Performance vs SNR                                  ← PENDIENTE (SIM-3)
     D. Computational Complexity

VIII. CONCLUSION AND FUTURE WORKS (+ liquid lenses, smart refresh)

APPENDIX A: Proof of Eq. (β_lin)      (sin cambios)
APPENDIX B: Proof of Eq. (Cov_β)      (sin cambios)
```

### Notas sobre la estructura:

**¿Por qué DR no tiene sección propia?** Distance Recovery es una fórmula cerrada trivial
(d = √(C/P_{K+1})) que se aplica idénticamente a todos los estimadores después del DF.
Se describe completamente en Sec. II-B2 (procedimiento). No requiere derivación ni análisis
adicional — es simplemente la inversión del canal bajo beam alignment.

**¿Por qué Proposition 1 está en Sec VI-A y no antes?** Porque requiere que el lector
conozca tanto el NL (Sec V) como GLS/WLS (Sec VI-B/C). Al colocarla en VI-A, se beneficia
de que Sec V ya introdujo la normalización p/p_max del NL. La proposición unifica ambos
mecanismos (ratios para GLS/WLS, normalización para NL) bajo un solo resultado.

Comparación con estructura actual del paper:
- Sec III: de 5 subsecciones → 4 (FIM, DEB, PEB, K). DEB se DEFINE explícitamente.
- Sec IV: optimización con DEB/PEB como coste principal. GLS-RMSE como remark.
- Sec V: NL reposicionado como estimador completo (no baseline inferior)
- Sec VI: de 2 subsecciones → 3 (nueva VI-A Proposition 1 para los tres estimadores)
- Sec VII: de 2 subsecciones → 4 (nuevas VII-A DF y VII-C SNR)
- Total secciones: 8→8 (no cambia la numeración principal)

---

## PLAN DETALLADO POR COMENTARIO

### Comment #1 — Reorganizar la Introducción
**Tipo**: Reescritura
**Estado actual**: Los párrafos saltan entre temas sin conexión clara. Las referencias se listan sin establecer relaciones.

**Acción**: Reestructurar en 6 bloques lógicos con transiciones claras:

1. **Problema** (párrafo 1): GNSS falla indoor → necesidad de IPS. RF tiene limitaciones.
2. **OWP como alternativa** (párrafo 2): Ventajas ópticas (sin multipath, confinamiento). NIR para posicionamiento sin afectar iluminación.
3. **Paradigmas OWP** (párrafo 3): Data-driven vs model-based. Justificar por qué model-based.
4. **Multi-LED → Single-LED** (párrafo 4): Table I. Multi-LED requiere ≥4 LEDs, infraestructura densa. Single-LED: la mayoría usa multi-PD, rotación del Rx, o sensores auxiliares. Gap: no existe single-LED single-PD 3D con estimadores cerrados.
5. **Beam steering como habilitador** (párrafo 5): Tecnología madura en OWC. Natural extenderla a posicionamiento.
6. **Nuestra propuesta** (párrafo 6): Concepto core + contribuciones. Usar el siguiente framing contrastante:

   > "The proposed approach operates in two stages. First, the LED is steered through K known orientations while the PD remains at a fixed, arbitrary pose; the resulting power measurements are processed by the proposed closed-form estimators to recover the LED-to-PD direction. We formally prove that this direction estimate is independent of the receiver orientation. Second, a single cooperative measurement with both the LED and PD aligned along the estimated direction yields the LED-to-PD distance, completing the 3D position. Unlike approaches requiring continuous PD rotation [Liu2022, Wang2024, Shi2025] or multi-PD arrays [Qin2020, Li2024], our system requires the PD to remain static during the K direction-finding measurements and performs only a single reorientation for distance recovery."

**Líneas afectadas**: ~50–98

---

### Comment #2 — Explicar concepto antes de contribuciones
**Tipo**: Adición de 1 párrafo
**Estado actual**: Línea 81 salta directamente a `\begin{itemize}`.

**Acción**: Insertar antes de las contribuciones:

> "The key idea is to steer a single LED through K predefined orientations while a PD at an unknown position collects the resulting K received-signal-strength measurements. The ratio of received powers between any two orientations cancels distance-dependent and receiver-orientation-dependent terms, yielding linear constraints on the transmitter-to-receiver direction. A closed-form eigenvector solution provides the direction estimate. Subsequently, a single cooperative measurement with both the LED and PD aligned along the estimated direction recovers the LED-to-PD distance, completing the 3D position."

**Actualizar la lista de contribuciones** (líneas 82–88):
- Contribución 1: Reformular → "...direction finding that is provably independent of the receiver orientation for ALL proposed estimators (GLS, WLS, and NLS)..."
- Contribución 2: DEB + PEB → "We derive a direction error bound (DEB) for the direction-finding stage and a position error bound (PEB) for the joint 3D system."
- Contribución 3: GA con dos funciones de coste → "We optimize the LED orientation set via GA using two complementary cost functions (DEB-based and GLS-RMSE-based)."
- Contribución 4: GLS/WLS → closed-form, n_r-independent, μs-level latency
- Contribución 5: NLS → iterative, n_r-independent via normalization, best DF accuracy (near-DEB)
- Contribución 6 (NUEVA): "Monte Carlo simulations with 1,000 trials over 1,792 positions confirm sub-degree DF accuracy, cm-level 3D positioning, and robustness to arbitrary PD tilts (<3% degradation)."

---

### Comment #3 — Distance Recovery confuso, "beam-forming symmetry"
**Tipo**: Reescritura de Sec. II-B2
**Estado actual**: Líneas 195–222. Dice "for beam-forming symmetry, the receiver is oriented to n_r = −n̂_d".

**Acción**: Reescribir Sec. II-B2 así:

> **Distance Recovery**
>
> Once the direction n̂_d has been estimated, the transmitter-to-receiver distance is obtained from a single additional power measurement. The LED is steered to n̂_d so that the beam is directed toward the receiver, and the PD is reoriented to −n̂_d so that it faces the transmitter. This cooperative alignment maximizes both cos ϕ ≈ 1 and cos ψ ≈ 1, thereby maximizing the received power and the SNR of the ranging measurement.
>
> Under this configuration, Eq. (2)–(3) yield P_{r,K+1} = C/d² + n_{K+1}, ...
>
> **Remark.** The PD reorientation is performed once, after the K direction-finding measurements during which the PD remains at an arbitrary fixed pose. This is in contrast to prior single-LED approaches that require continuous PD rotation [Liu2022, Wang2024, Shi2025].

**Eliminar**: la frase "beam-forming symmetry".

**Actualizar Algorithm 1** (línea 826): Cambiar `Set n_r ← −n̂_d` a `Reorient PD to n_r ← −n̂_d` con un comentario que diga "cooperative alignment for ranging".

---

### Comment #4a — Dependencia de μ_i(r) en r
**Tipo**: Adición de 1 frase
**Ubicación**: Después de línea 246 (`\mu_{i}(\mathbf r)=P_{t}\,h_{\mathrm{LOS},i}(\mathbf r)`)

**Texto a añadir**:
> "The dependence on r enters through d(r) = ||r − t||, cos ϕ_i(r) = n_{t,i} · (r−t)/d, and cos ψ(r) = n_r · (t−r)/d in (2)–(3), all of which are explicit functions of the receiver position r."

---

### Comment #4b — Secciones III-A y III-B innecesarias
**Tipo**: Fusión/simplificación
**Estado actual**: Sec III-A (Joint Statistical Model), III-B (Log-Likelihood and Score), III-C (FIM). Líneas 235–310.

**Acción**: Fusionar III-A + III-B + III-C en una sola subsección "Fisher Information Matrix":

1. Mantener el modelo estadístico (1 párrafo, de III-A)
2. Eliminar la derivación de log-likelihood y score (III-B completa)
3. Escribir directamente: "Under i.i.d. Gaussian noise with known variance, the FIM follows from the Slepian–Bangs formula [Kay, 1993]:" → Eq. (16)
4. Mantener las expresiones de gradientes (de III-C)

**Resultado**: ~15 líneas eliminadas, citando Kay directamente.

---

### Comment #4c — u_x, u_y, u_z no definidos
**Tipo**: Corrección puntual
**Ubicación**: Línea 447 (Sec. IV)

**Acción**: Añadir antes de la mención:
> "where u_x = [1,0,0]^T, u_y = [0,1,0]^T, u_z = [0,0,1]^T are the standard Cartesian basis vectors"

O alternativamente, usar la notación e_1, e_2, e_3 definida en Notation.

---

### Comment #4d — GLS/WLS no explicados suficientemente
**Tipo**: Expansión textual en Sec. VI-B y VI-C
**Estado actual**: Las derivaciones van paso a paso pero sin explicar la intuición.

**Acción**: Añadir párrafos explicativos en puntos clave:

1. **Después de Eq. (25) [β_i definition]**: Explicar por qué el ratio cancela la distancia:
   > "The key insight is that the distance d and the receiver-dependent factor cos ψ appear identically in both μ_i and μ_1. Their ratio therefore cancels these common factors, yielding β_i = cos(ϕ_i)/cos(ϕ_1), which depends only on the LED orientations and the displacement direction d."

2. **Después de Eq. (27) [a_i ⊥ d]**: Explicar geométricamente:
   > "Geometrically, each constraint a_i · d = 0 defines a hyperplane through the origin that contains the true direction d. With K−1 such hyperplanes (from K orientations), their intersection yields the direction estimate. The GLS weighting ensures that hyperplanes with lower noise variance (higher SNR) contribute more to the solution."

3. **En WLS (Sec. VI-C)**: Explicar cuándo WLS ≈ GLS:
   > "The diagonal approximation is accurate when the reference orientation i=1 has significantly higher received power than the other orientations (μ_1 ≫ μ_i), because the off-diagonal covariance terms scale with μ_1^{−2} while the diagonal terms scale with μ_i^{−2} + μ_1^{−2}."

---

### Comment #5 — Table I "Arbitrary" vs modelo
**Tipo**: Corrección de Table I + nueva subsección VI-A
**Estado**: 🔬 EVIDENCIA DISPONIBLE (SIM-2 completada, `analysis_nr_agnosticism.md` escrito)

**Acción** (3 partes):

**Parte 1 — Table I**: Cambiar columna "Rx Orientation" para Ours:
- De: `Arbitrary`
- A: `Arbitrary$^\dagger$`
- Añadir nota: `$\dagger$ Direction finding is provably independent of n_r (Sec. VI-A); distance recovery requires a known/controlled n_r.`

**Parte 2 — Sec II-A** (líneas 114–116): Generalizar:
- De: "The receiver is a single PD with fixed normal along the vertical axis n_r = [0,0,1]^T"
- A: "The receiver is a single PD with orientation n_r ∈ S². For concreteness, we set n_r = [0,0,1]^T in the simulations. As shown in Proposition 1 (Section VI-A), ALL proposed direction estimators (GLS, WLS, and NL-MLE) are independent of n_r; therefore, direction-finding results hold for any receiver orientation. The PEB is evaluated for n_r = [0,0,1]^T."

**Parte 3 — Nueva Sec VI-A** "Receiver-Orientation Independence" (ACTUALIZADA):

> **Proposition 1.** All three direction estimators (GLS, WLS, NL-MLE) yield estimates that are independent of the receiver orientation n_r.
>
> *Proof.*
> The LOS channel factorizes as P_{r,i} = α(n_r, d) · Q_i^m, where α = P_t(m+1)A_det/(2πd²) · cos ψ is common to all orientations i.
>
> *(i) GLS/WLS:* β_i = (μ_i/μ_1)^{1/m} = Q_i/Q_1 — the common factor α cancels in the ratio.
>
> *(ii) NL-MLE:* The normalized targets p_{target,i} = μ_i/max_j μ_j = Q_i^m/Q_max^m cancel α. The cost function F(v, η) = Σ(η·Q_i^m(v) − p_{target,i})² with free scale η jointly marginalizes over α.
>
> Since all estimators operate on α-free quantities, their outputs are n_r-independent. □
>
> **Remark 1.** This property holds regardless of whether n_r is known, unknown, or time-varying.
>
> **Remark 2 (Simulation confirmation).** Under random receiver tilts (half-normal σ=5°, max=30°), the direction RMSE degrades by only +2.24% (GLS), +2.62% (WLS), +1.68% (NL-MLE), and +1.69% (DEB). This residual is due to SNR reduction (lower cos ψ), not structural bias. See Sec. VII-A-2.

**Datos de soporte**: `run_nr_random_tilt_MC_parallel.m` (K=5, M=1000, N_tilt=100, 1792 posiciones, 39h de cómputo).

---

### Comment #6 — Tilt-azimuth no aparecen en modelo
**Tipo**: Adición explícita en Sec. IV
**Estado actual**: La Eq. de n_{t,i} en coordenadas esféricas está en línea 450–453, pero no se conecta explícitamente con el CRLB.

**Acción**: Después de la Eq. de n_{t,i} (línea 453), añadir:

> "Substituting this parameterization into the channel model (2)–(3) and hence into the FIM (16), both the DEB and the PEB become explicit functions of the 2K angular variables {(θ_i, φ_i)}_{i=1}^K. The GA searches over this 2K-dimensional decision space to minimize the spatial RMSE of the DEB (or PEB) evaluated over the 3D testbed."

---

### Comment #7 — 2K unknowns vs K mediciones → underdetermined
**Tipo**: Clarificación (el reviewer confunde diseño con estimación)
**Ubicación**: Sec. IV, después de describir el GA

**Acción**: Añadir un párrafo:

> "We emphasize that the GA optimization is an offline system-design problem, not an online estimation problem. The 2K decision variables (tilt–azimuth pairs) define the orientation set; for each candidate set, the PEB (or DEB) is evaluated analytically over the entire 3D testbed using the closed-form FIM in (16). No measurements are involved in this optimization—only theoretical performance bounds. The ratio of design variables to measurements therefore does not constitute an underdetermined estimation problem. Once the optimal orientation set is fixed, the online direction-finding stage uses K power measurements to recover the 2-DoF direction on S², which is overdetermined for K ≥ 3. The subsequent distance-recovery measurement then completes the 3D position."

---

### Comment #8 — ¿r es fijo en la optimización?
**Tipo**: Clarificación
**Ubicación**: Sec. IV (puede ir en el mismo párrafo que Comment #7)

**Acción**: Añadir:

> "The orientation set is optimized to minimize the RMSE of the PEB averaged over all |R| = 1,792 receiver positions in the 3D testbed (Table II). The position r is therefore not fixed but sweeps the entire spatial grid during fitness evaluation. The resulting orientation set is position-independent and can be deployed universally."

---

### Comment #9 — Fig. 9 redundante con Fig. 2
**Tipo**: Clarificación + potencial reemplazo

**Mapeo de figuras (por orden de aparición en .tex)**:
- Fig. 1: System geometry (línea 149)
- Fig. 2: Violin plot PEB optimized vs random (línea 488)
- Fig. 3: Heatmap PEB K=5 optimal vs random (línea 494)
- Fig. 4: PEB vs K for different Φ_{1/2} (línea 560)
- Fig. 5: PEB vs SNR (línea 568)
- Fig. 6: CDF of 3D position error (línea 901)
- Fig. 7: 3D position estimates (línea 933)
- Fig. 8: Computation latency (línea 967)

**Argumento clave**: Las figuras NO son redundantes. Pertenecen a **dos perspectivas distintas**:
- **Fig. 2–5**: Análisis **teórico** (bounds). Evalúan PEB/DEB analíticamente sin ruido ni MC → muestran el potencial del sistema bajo condiciones ideales.
- **Fig. 6–8**: Análisis de **realización** (estimadores). Evalúan GLS, WLS, NL-MLE bajo ruido real con MC trials → muestran el rendimiento práctico.

**Respuesta al reviewer**: "Fig. 2 presents the theoretical PEB across the optimized vs. random orientation sets, providing an analytical design-level perspective. In contrast, Figs. 6–8 report Monte Carlo realizations of the proposed estimators under additive noise and evaluate practical performance metrics (CDF, spatial error distribution, latency). These two sets of figures serve complementary roles—design validation vs. operational assessment—and we believe both are necessary for a complete evaluation."

**Acción adicional**: Se puede reemplazar **Fig. 7** (3D position scatter) por una nueva figura de **CDF angular (DF)** o **robustez a tilt**, ya que Fig. 6 (CDF 3D) ya cubre el rendimiento de posición. Esto aporta información nueva sin crear redundancia.

---

### Comment #10 — Latencia por mediciones secuenciales
**Tipo**: Nuevo párrafo en Sec. VII-D + Conclusion (future work)
**Estrategia de respuesta**: Dos partes: (a) análisis de latencia actual, (b) reconocer como future work con liquid lenses.

**Parte (a) — En Sec. VII-D**, añadir análisis:

> "The proposed system acquires K+1 sequential measurements: K for direction finding and one for distance recovery. With state-of-the-art MEMS micromirrors capable of repositioning in ~100 μs [Liu:25] and N = 1000 samples per orientation at MHz-rate ADCs, each orientation requires approximately 1 ms of acquisition plus 0.1 ms of steering overhead. For K = 5, the total direction-finding window is ~5.5 ms, plus ~1.1 ms for distance recovery (including PD reorientation), totaling ~6.6 ms. At typical pedestrian speeds of 1.4 m/s, the displacement during this window is ~9 mm, which is below the centimeter-level positioning accuracy."

**Parte (b) — En Sec. VIII (Conclusion / Future Work)**, añadir:

> "A thorough experimental investigation of the steering latency and its impact on mobile positioning is left for future work. In particular, we are currently investigating beam steering via electrically tunable liquid lenses, which offer continuous angular control without mechanical parts and switching times on the order of milliseconds [ref_liquid_lenses]. Furthermore, in practical beam-steered OWC links—where the transmitter must already track the receiver for maintaining the communication beam—the direction-finding stage can be integrated into the beam-tracking loop. In such a scenario, the K orientation sweeps need not be performed from scratch at every update cycle; instead, an intelligent refresh strategy can exploit the previous direction estimate to reduce the number of required orientations and accelerate convergence."

**Nota**: La mención de liquid lenses es ongoing work en el laboratorio. No prometer resultados, sino posicionar como future direction.

---

### Comment #11 — Falta baseline MLE + existente + SNR
**Tipo**: Clarificación teórica + nuevas simulaciones + nueva subsección VII-C
**Estado**: ✅ PARCIALMENTE RESUELTO (DF y 3D comparativas listas; SNR pendiente)

**Parte 1 — NL clarification** (ACTUALIZADO con n_r-agnosticism y resultados):

Caracterización actualizada del NL-MLE:
- **Usa potencias normalizadas** $p_i/\max p_j$, NO potencias absolutas → elimina $\alpha(\mathbf{n}_r, d)$
- Es **n_r-agnostic** (vía normalización + parámetro libre η), al igual que GLS/WLS
- Opera en $S^2$ (dirección) con el modelo **no-linealizado** $\eta \cdot Q_i^m(\mathbf{v})$
- Es **aproximadamente el MLE de dirección** sobre el modelo normalizado: bajo Gaussian noise con $N$ grande, la NLS sobre medias normalizadas converge al MLE
- Supera a GLS en DF (0.63° vs 0.66°) porque **evita la linearización** de ratios que GLS requiere
- NO es MLE de posición 3D (opera solo en S², no usa medición K+1)
- Un Joint MLE (K+1 mediciones → r) no es implementable (medición K+1 adaptiva)

**Jerarquía de rendimiento (DF) y justificación**:
```
DEB (0.52°) < NL-MLE (0.63°) < GLS (0.66°) < WLS (0.77°)
  |              |                 |                |
  bound          modelo no-lineal  modelo lineal.   pesos diag.
  teórico        normalizado        + Σ_β⁻¹         simplificados
```
- **NL-MLE < GLS**: NL trabaja con el modelo Lambertiano completo en S²; GLS lineariza β_i ≈ lineal(d)
- **GLS < WLS**: GLS usa Σ_β⁻¹ completa; WLS usa solo la diagonal
- **NL-MLE > DEB**: Gap por (i) ponderación uniforme (no Fisher-optimal), (ii) finite N_samples

Texto para Sec. V (NL-MLE como estimador n_r-agnostic no-lineal):
> "We develop an iterative nonlinear least-squares (NLS) estimator that fits the normalized Lambertian power model on S². The measured power means are divided by their maximum, yielding normalized targets p_i = μ̂_i/max_j μ̂_j that are independent of the receiver orientation (Proposition 1). A free scale parameter η absorbs the unknown normalization constant. The NLS minimizes F(v,η) = Σ(η·(n_{t,i}·v)^m − p_i)² subject to ||v||=1, recovering the direction without knowledge of n_r, d, or P_t. For large N, this NLS is asymptotically equivalent to the direction MLE on the normalized model, which explains its superior performance over the linearized GLS (Table V)."

Texto para Sec. VI (GLS como MLE del modelo linealizado):
> "Under the first-order approximation in (XX), GLS is the maximum-likelihood estimator for the direction parameter of the linearized ratio model and is therefore statistically efficient within that model class. However, the linearization introduces an approximation loss, as evidenced by the NLS outperforming GLS in direction error (Table V). The advantage of GLS lies in its closed-form solution and microsecond-level latency."

**Parte 2 — Baseline existente**:
[Chassagne2025] ya está incluido (K=3). Reforzar en el texto.

**Parte 3 — Comparación realizada** (datos disponibles en `comparison_DF_best.txt`):
- Direction Finding: GLS 0.66°, WLS 0.77°, NL-MLE 0.63°, DEB 0.52° (M=1000, K=5)
- 3D Positioning: GLS 2.52cm, WLS 2.92cm, NL-MLE 2.40cm, PEB 1.64cm

**Parte 4 — Performance vs SNR** (⏳ PENDIENTE — SIM-3):
- Barrer SNR de 0 a 50 dB (ajustando σ²)
- Para cada SNR: ejecutar GLS, WLS, NL sobre posiciones del testbed
- Generar figura: RMSE vs SNR con curvas GLS, WLS, NL, PEB/DEB para K=5

---

### Comment #12 — CRLB con métricas estadísticas en Table IV
**Tipo**: Corrección de tablas + nota
**Estado actual**: Table IV (líneas 910–927) tiene fila "CRLB" con RMSE, CDF 90%, APE.

**Acción** (para AMBAS tablas — DF y 3D):

**Table V (NUEVA — DF angular)**: Renombrar fila bound como "DEB" (no "CRLB"):
> "For the DEB row, 'RMSE' denotes the root-mean-square of the direction error bound over all testbed positions (a deterministic spatial statistic, not a Monte Carlo estimate); 'CDF 90%' is the 90th percentile; 'Mean' is the spatial average."

**Table IV (3D positioning)**: Renombrar fila como "PEB" (no "CRLB"):
> "For the PEB row, 'RMSE', 'CDF 90%', and 'Mean' are deterministic spatial statistics of the position error bound, not Monte Carlo estimates."

En ambos casos, usar nomenclatura "DEB" / "PEB" para distinguir claramente del CRLB genérico.

---

### Comment #13 — Gap NL–CRLB
**Tipo**: Explicación teórica sólida (código ya verificado como correcto)
**Estado**: ✅ RESUELTO — el código NL no tiene bugs; el gap es teórico

**Resultados numéricos actualizados** (M=1000, K=5):
- Direction: NL 0.63° vs DEB 0.52° → gap 21%
- 3D: NL 2.40cm vs PEB 1.64cm → gap 46%
- Nota: NL < GLS en DF (0.63° vs 0.66°) → NL opera directamente sobre potencias no-lineales, evitando la linearización de ratios

**El gap estimadores–bound tiene dos causas**:

> **(i) Two-stage decomposition.** The PEB represents the bound for joint estimation of r from all K+1 measurements. All estimators employ a two-stage architecture (DF + DR). The K DF measurements contain distance information (through absolute power levels) that the ratio/normalization approach discards. A joint MLE is not feasible because the K+1 measurement is adaptive (depends on n̂_d).
>
> **(ii) Genie-aided bounds.** The DEB and PEB are evaluated assuming perfect knowledge or noise-free conditions: the DEB uses the true FIM at the true position; the PEB additionally assumes perfect beam alignment (n_{t,K+1} = n_d). No practical estimator can achieve these bounds. The gap between NL-MLE (0.63°) and DEB (0.52°) is additionally due to NL's uniform weighting (not Fisher-optimal).

Nota: cada estimador ya usa su set de orientaciones ÓPTIMO (NL→DEB_K5, GLS→GLS_DF_K5). El gap NO es por orientaciones subóptimas sino por las razones teóricas arriba.

**Texto complementario para Sec. III** (interpretar el PEB):
> "The PEB is evaluated at the true position r with the distance-recovery measurement assuming perfect beam alignment (n_{t,K+1} = n_d). This genie-aided formulation follows standard CRLB practice for adaptive sensing systems [Kay, 1993]. Because the K+1-th orientation depends on the direction estimate from the first K measurements, the PEB serves as an optimistic lower bound."

---

### Comment #14 — Correcciones gramaticales
**Tipo**: Edición puntual (3 correcciones)

| #   | Línea | Actual                                                                                                   | Corregido                                             |
| -----| -------| ----------------------------------------------------------------------------------------------------------| -------------------------------------------------------|
| 14a | 68    | "They presumes"                                                                                          | "They presume"                                        |
| 14b | 50    | "Therefore, there is a need for dedicated indoor position systems (IPS), which use...are widely studied" | Reescribir completamente (se resuelve con Comment #1) |
| 14c | 61    | "transformer"                                                                                            | "Transformer"                                         |

---

## AUDITORÍA DE CÓDIGO — RESULTADOS (actualizado 28/04/2026)

### Conclusión sobre el NL (actualizado 06/05/2026)

**El algoritmo NL es correcto y su rendimiento es superior al GLS en Direction Finding.**

Caracterización actualizada:
1. **NL usa potencias normalizadas** $p_i/\max p_j$ → elimina $\alpha(\mathbf{n}_r, d)$ → **n_r-agnostic**
2. **NL trabaja con el modelo Lambertiano completo** (no linealizado) en $S^2$ → evita la pérdida por linearización de GLS
3. **NL es aproximadamente el MLE de dirección** sobre el modelo normalizado (para $N$ grande)
4. **NL usa ponderación uniforme** (no Fisher-optimal) → explica el gap residual con DEB

Resultados (K=5, M=1000, cada uno con su set de orientaciones óptimo):
```
DEB: 0.52° (bound) < NL-MLE: 0.63° < GLS: 0.66° < WLS: 0.77°
```

### Implicaciones para el paper

- **NL supera GLS en DF** (0.63° vs 0.66°): esto se debe a que NL no lineariza. GLS compensa con velocidad (closed-form, μs vs ms).
- **Todos son n_r-agnostic**: NL vía normalización; GLS/WLS vía ratios. Confirmado por SIM-2 (degradación < 3%).
- **Sec. V del paper**: NL ya NO se presenta como "baseline inferior". Se presenta como estimador iterativo n_r-agnostic que opera sobre el modelo no-lineal, con mejor precisión pero mayor latencia.
- **La ventaja de GLS/WLS**: closed-form, μs-level, sin necesidad de inicialización ni optimización iterativa.

---

### ISSUE-1: [RESUELTO] Characterización del NL — actualizado

**Resolución**: El NL se caracteriza como NLS sobre el modelo normalizado en S², que es **aproximadamente el MLE de dirección** (no exacto, porque la normalización introduce heteroscedasticidad). Se explica que:
- NL supera GLS en DF porque no lineariza el modelo Lambertiano
- GLS es el MLE del modelo **linealizado** de ratios
- Ambos son n_r-agnostic (NL vía normalización, GLS vía ratios)
- La ventaja de GLS/WLS es computational: closed-form vs iterativo

---

### ISSUE-2: [RESUELTO] Comment #9 — figuras

**Resolución**: Mapeo de figuras completado. Se argumenta que Fig. 2–5 (teórico) y Fig. 6–8 (MC) no son redundantes. Fig. 7 se reemplaza por CDF angular o robustez a tilt.

---

### ISSUE-3: Comment #10 — latencia

**Resolución parcial**: Análisis cuantitativo incluido (~6.6ms para K=5). Liquid lenses como future work. **Pendiente**: verificar ADC rate y MEMS steering time con referencias publicadas.

---

### ISSUE-4: Comment #7 — convergencia GA

**Pendiente**: Re-ejecutar GA con múltiples semillas y reportar consistencia. Ambas optimizaciones (DEB y GLS-RMSE) ya se ejecutaron exitosamente.

---

### Notas menores resueltas

- **Comment #4c**: u_y = [0,1,0]^T (corregido en system_params.m)
- **system_params.m**: sigma2 comment corregido a `σ² = σ_w²/R_p² [W^2] (optical domain)`

---

## SIMULACIONES — ESTADO ACTUALIZADO

### ✅ SIM-1: CDF de error angular (Direction Finding)
**Script**: `fundamentals/estimators/run_DF_comparison_MC_parallel.m`
**Parámetros**: K=5, M_trials=1000, N_pos=1792, N_samples=1000
**Orientaciones**: GLS/WLS → `orientations_GLS_DF_K5_MC10`; NL/DEB → `orientations_DEB_K5`
**Resultados**: `comparison_DF_best.txt`
**Figuras**: CDF angular para DEB, NL-MLE, GLS, WLS (script `plot_DF_MC_comparison.m`)

### ✅ SIM-2: Robustez a tilts aleatorios del PD
**Script**: `fundamentals/nr_robustness/run_nr_random_tilt_MC_parallel.m`
**Parámetros**: K=5, M_trials=1000, N_random_tilt=100, N_pos=1792, σ_tilt=5°, θ_max=30°
**Orientaciones**: GLS/WLS → `orientations_GLS_DF_K5_MC10`; NL/DEB → `orientations_DEB_K5`
**Tiempo de cómputo**: 39.1 horas (24 workers)
**Resultado clave**: Degradación < 3% para TODOS los estimadores → confirma n_r-agnosticism
**Nota IMPORTANTE**: Contrariamente a la hipótesis original, NL-MLE NO se degrada más que GLS/WLS porque TAMBIÉN es n_r-agnostic (normalización p/p_max cancela α). El contraste esperado GLS/WLS plano vs NL creciente **NO se observa** — los tres son planos. Esto es un resultado MÁS FUERTE: todos los estimadores propuestos son robustos a tilt.

### ✅ SIM-4: 3D Positioning (Direction + Distance Recovery)
**Script**: `fundamentals/estimators/run_3D_comparison_MC_parallel.m`
**Parámetros**: K=5, M_trials=1000, N_pos=1792
**Método DR**: Beam alignment (n_t=v_est, n_r=-v_est) + distance recovery via d=√(P_t(m+1)A_det/(2π·P_ax))
**Orientaciones**: GLS/WLS → `orientations_GLS_DF_K5_MC10`; NL/PEB → `orientations_DEB_K5`
**Resultados**: `comparison_DF_best.txt` (sección 3D)

### ⏳ SIM-3: RMSE vs SNR para estimadores
**Propósito**: Comment #11 (performance vs SNR)
**Qué hacer**:
1. Barrer SNR de 0 a 50 dB (ajustando σ²)
2. Para cada SNR: ejecutar GLS, WLS, NL sobre posiciones del testbed
3. Calcular RMSE 3D y comparar con PEB
**Figura**: RMSE vs SNR con curvas GLS, WLS, NL, PEB/DEB para K=5
**Esfuerzo**: Medio

---

## FIGURAS: ESTADO FINAL

| # | Contenido | Estado |
|---|-----------|--------|
| 1 | System geometry | Sin cambios |
| 2 | Violin PEB optimized vs random | Sin cambios |
| 3 | Heatmap PEB K=5 (optimal vs random) | Sin cambios |
| 4 | PEB vs K (Φ_{1/2}) | Sin cambios |
| 5 | PEB vs SNR | Sin cambios |
| 6 | CDF 3D position error | **ACTUALIZAR** con nuevos datos (M=1000, 2 sets orientaciones) |
| 7 | ~~3D position estimates~~ → **CDF error angular (DF)** | **REEMPLAZAR** (Comment #9) ✅ datos listos |
| 8 | Computation latency | Sin cambios |
| 9 | **Robustez a tilt del PD** | **NUEVA** ✅ datos listos |
| 10 | **RMSE vs SNR (estimadores)** | **NUEVA** ⏳ (SIM-3 pendiente) |

Total: 10 figuras (8 existentes − 1 eliminada + 3 nuevas).

---

## TABLA: ESTADO FINAL

| Tabla | Contenido | Cambio |
|---|---|---|
| I | State-of-the-art single-LED | Corregir "Arbitrary" → "Arbitrary†" con nota |
| II | GA parameters | Sin cambios |
| III | Optimal orientations | Añadir: dos sets (GLS-optimized + DEB-optimized) |
| IV | 3D Performance metrics | **ACTUALIZAR** con nuevos datos (M=1000) + renombrar fila CRLB→PEB |
| V | **Direction-finding angular error** | **NUEVA** ✅ (datos de `comparison_DF_best.txt`) |
| VI | **Random tilt degradation** | **NUEVA** ✅ (datos de SIM-2) |

---

## CÓDIGO: ARCHIVOS ACTUALIZADOS

| Archivo | Estado | Función |
|---|---|---|
| `fundamentals/core/vlp_gls.m` | ✅ Sin cambios | GLS direction estimator |
| `fundamentals/core/vlp_wls.m` | ✅ Sin cambios | WLS direction estimator |
| `fundamentals/core/OWC_LOS_channel.m` | ✅ Sin cambios | LOS channel model |
| `fundamentals/core/DEB_complete.m` | ✅ Sin cambios | Direction Error Bound |
| `fundamentals/core/PEB_complete.m` | ✅ Sin cambios | Position Error Bound |
| `fundamentals/estimators/system_params.m` | ✅ Actualizado | Parámetros + 2 sets orientaciones |
| `fundamentals/estimators/run_DF_comparison_MC_parallel.m` | ✅ **COMPLETADO** | MC Direction Finding (K=5, M=1000) |
| `fundamentals/estimators/run_3D_comparison_MC_parallel.m` | ✅ **COMPLETADO** | MC 3D Positioning (K=5, M=1000) |
| `fundamentals/estimators/plot_DF_MC_comparison.m` | ✅ Creado | CDF plots de DF |
| `fundamentals/nr_robustness/run_nr_random_tilt_MC_parallel.m` | ✅ **COMPLETADO** | Robustez a tilt (39h) |
| `fundamentals/nr_robustness/analysis_nr_agnosticism.md` | ✅ Creado | Prueba matemática n_r-agnosticism |
| `fundamentals/optimization/optimize_DEB_orientations_parallel.m` | ✅ Existente | GA para orientaciones DEB |
| `fundamentals/optimization/optimize_GLS_DF_orientations_parallel.m` | ✅ Existente | GA para orientaciones GLS |
| **PENDIENTE**: Script RMSE vs SNR | ⏳ | SIM-3 |

---

## ORDEN DE EJECUCIÓN

### ~~Fase 0~~: ~~Corrección de bugs~~ — ELIMINADA
No hay bugs en el código.

### Fase 1: Simulaciones — ✅ CASI COMPLETADA
1. [x] SIM-1: CDF error angular → `run_DF_comparison_MC_parallel.m` (K=5, M=1000)
2. [x] SIM-2: Robustez a tilt → `run_nr_random_tilt_MC_parallel.m` (39h, 24 workers)
3. [ ] SIM-3: RMSE vs SNR → **PENDIENTE** (nuevo script necesario)
4. [x] SIM-4: 3D Positioning → `run_3D_comparison_MC_parallel.m` (K=5, M=1000)

### Fase 2: Reescritura del paper (secuencial) — ⏳ PENDIENTE
4. [ ] Abstract (reescribir — borrador al final de este doc)
5. [ ] Sec. I: Reestructurar Introducción (Comments #1, #2)
6. [ ] Sec. II-A: Ajustar descripción de n_r — TODOS los estimadores son n_r-agnostic (Comment #5)
7. [ ] Sec. II-B2: Reescribir Distance Recovery (Comment #3)
8. [ ] Sec. III: Fusionar III-A + III-B, citar Kay (Comment #4b)
9. [ ] Sec. III: Añadir frase sobre dependencia μ_i(r) (Comment #4a)
10. [ ] Sec. IV: Añadir conexión θ,φ → CRLB (Comment #6)
11. [ ] Sec. IV: Añadir párrafo offline design (Comments #7, #8)
12. [ ] Sec. IV: Mencionar DOS funciones de coste (DEB y GLS-RMSE)
13. [ ] Sec. V: Reposicionar NL como baseline n_r-agnostic (normalización + η)
14. [ ] Sec. VI-A: NUEVA — Proposition 1 EXTENDIDA (incluye NL-MLE) (Comment #5)
15. [ ] Sec. VI-B: Expandir explicación GLS (Comment #4d)
16. [ ] Sec. VI-C: Expandir explicación WLS (Comment #4d)
17. [ ] Sec. IV: Definir u_x, u_y, u_z (Comment #4c)
18. [ ] Sec. VII-A: NUEVA — DF performance + robustez tilt (datos listos)
19. [ ] Sec. VII-B: 3D positioning (datos listos, actualizar tabla)
20. [ ] Sec. VII-C: NUEVA — RMSE vs SNR (requiere SIM-3)
21. [ ] Sec. V+VI: GLS como direction MLE del modelo linealizado (Comments #11, #13)
22. [ ] Table I: Corregir "Arbitrary" (Comment #5)
23. [ ] Table IV: Corregir nomenclatura CRLB→PEB, actualizar datos (Comment #12)
24. [ ] Table V (NUEVA): Direction-finding angular metrics
25. [ ] Sec. VII: Discutir latencia (Comment #10)
26. [ ] Sec. VII: Reemplazar Fig. 7 (Comment #9) — datos CDF angular listos
27. [ ] Algorithm 1: Actualizar (Comment #3)
28. [ ] Conclusion: Actualizar
29. [ ] Gramática: 3 correcciones (Comment #14)

### Fase 3: Verificación
30. [ ] Compilar LaTeX, verificar numeración de ecuaciones/figuras/tablas
31. [ ] Verificar coherencia de claims entre Abstract, Intro, y Conclusion
32. [ ] Preparar response letter al reviewer

---

## ABSTRACT PROPUESTO (borrador — actualizado 06/05/2026)

> State-of-the-art optical wireless positioning (OWP) commonly reaches centimeter-level accuracy by relying on dense multi-LED infrastructures, photodiode (PD) arrays, or image-sensor receivers, incurring hardware complexity and deployment cost. This paper introduces a single beam-steered LED, single-PD OWP architecture for three-dimensional (3D) indoor localization. The transmitter is steered through K known orientations while the PD collects the resulting received-signal-strength variations. We develop closed-form direction estimators—a statistically efficient generalized least squares (GLS) and a lightweight weighted least squares (WLS)—alongside an iterative nonlinear least-squares (NLS) estimator. We prove that all three estimators are mathematically independent of the receiver orientation, enabling direction finding without receiver pose knowledge or control. We derive a direction error bound (DEB) for the direction-finding stage and a position error bound (PEB) for the complete 3D system, and optimize the steering-pattern via a genetic algorithm using two complementary cost functions. A single beam-aligned ranging measurement then recovers the LED-to-PD distance, completing the 3D position. Simulations over 1,792 testbed positions with 1,000 Monte Carlo trials per position demonstrate sub-degree direction-finding accuracy (GLS: 0.66°, NLS: 0.63°, DEB: 0.52°), centimeter-level 3D positioning (GLS: 2.5 cm, NLS: 2.4 cm, PEB: 1.6 cm), and robustness to random receiver tilts with degradation below 3%.
