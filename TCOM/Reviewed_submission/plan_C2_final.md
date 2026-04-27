# Plan de Acción Final — Opción C2

## Decisión tomada
**Opción C2**: Direction Finding como contribución principal (n_r-agnostic). Distance Recovery beamformed (con reorientación del Rx) presentado transparentemente como extensión para 3D. Resultados existentes se conservan.

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

III. POSITION ERROR BOUND (simplificar)
     A. Fisher Information Matrix (fusión de antiguas III-A + III-B + III-C)
        1) Direction-Finding Measurements
        2) Distance-Recovery Measurement
     B. Position Error Bound
     C. Number of LED Orientations

IV.  ORIENTATION SET OPTIMIZATION (clarificar)

V.   NONLINEAR DIRECTION-FINDING BASELINE (reposicionar como baseline + clarificar n_r)

VI.  LINEAR DIRECTION ESTIMATORS (expandir)
     A. Receiver-Orientation Independence of Power Ratios  ← NUEVA
     B. Direction Estimation via GLS (expandir explicación)
     C. WLS as Practical Simplification (expandir explicación)

VII. SIMULATION RESULTS (expandir significativamente)
     A. Direction-Finding Performance                       ← NUEVA
        1) Angular Error CDF                                ← NUEVA
        2) Robustness to Receiver Tilt                      ← NUEVA
     B. 3D Positioning Performance (existente, reorganizado)
     C. Performance vs SNR                                  ← NUEVA
     D. Computational Complexity (existente)

VIII. CONCLUSION AND FUTURE WORKS

APPENDIX A: Proof of Eq. (β_lin)      (sin cambios)
APPENDIX B: Proof of Eq. (Cov_β)      (sin cambios)
```

Comparación con estructura actual:
- Sec III: de 5 subsecciones → 3 (fusión III-A + III-B)
- Sec VI: de 2 subsecciones → 3 (nueva VI-A)
- Sec VII: de 2 subsecciones → 4 (nuevas VII-A y VII-C)
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
- Contribución 1: Reformular → "...direction finding that is provably independent of the receiver orientation..."
- Contribución 2: CRLB/PEB → mantener
- Contribución 3: GA → mantener
- Contribución 4: GLS/WLS → enfatizar n_r-independence como propiedad
- Contribución 5 (NUEVA): "We demonstrate that GLS/WLS direction finding is robust to arbitrary PD tilts, maintaining sub-degree accuracy across a wide range of receiver orientations."

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
**Estado actual**: Table I dice "Arbitrary" para Ours. Sec II-A dice n_r = [0,0,1]^T.

**Acción** (3 partes):

**Parte 1 — Table I**: Cambiar columna "Rx Orientation" para Ours:
- De: `Arbitrary`
- A: `Arbitrary$^\dagger$`
- Añadir nota: `$\dagger$ Direction finding is provably independent of n_r (Sec. VI-A); distance recovery requires a known/controlled n_r.`

**Parte 2 — Sec II-A** (líneas 114–116): Generalizar ligeramente:
- De: "The receiver is a single PD with fixed normal along the vertical axis n_r = [0,0,1]^T"
- A: "The receiver is a single PD with orientation n_r ∈ S². For concreteness, we set n_r = [0,0,1]^T in the simulations. As shown in Proposition 1 (Section VI-A), the proposed GLS/WLS direction estimators are independent of n_r; therefore, the direction-finding results hold for any receiver orientation. The PEB and NLS baseline are evaluated for the specific case n_r = [0,0,1]^T."

**Parte 3 — Nueva Sec VI-A** "Receiver-Orientation Independence":

> **Proposition 1.** The power ratios β_i = (μ_i/μ_1)^{1/m} and, consequently, the constraint normals a_i = n_{t,i} − β_i n_{t,1}, the matrices M_GLS and M_WLS, and the direction estimates n̂_{d,GLS} and n̂_{d,WLS} are all independent of the receiver orientation n_r.
>
> *Proof.* From (X), μ_i = −C (n_{t,i}·d)^m (n_r·d) / d^{m+3}. The factor (n_r · d)/d^{m+3} is common to all orientations i (the PD does not move between measurements). Therefore:
>
> β_i = (μ_i/μ_1)^{1/m} = [(n_{t,i}·d)^m / (n_{t,1}·d)^m]^{1/m} = (n_{t,i}·d) / (n_{t,1}·d)
>
> which depends only on the LED orientations {n_{t,i}} and the direction d, not on n_r. Since a_i, Â, Σ_β, M_GLS, and M_WLS are all constructed from {β_i} and {n_{t,i}}, the direction estimates are n_r-independent. □
>
> **Remark 1.** The n_r-independence of the ratio-based direction estimators is not a design choice but a fundamental mathematical property: the receiver-orientation factor cos ψ appears identically in every received power μ_i and cancels exactly in the ratio β_i = (μ_i/μ_1)^{1/m}. This property holds regardless of whether n_r is known, unknown, or time-varying.
>
> **Remark 2.** The NL estimator (Sec. V) does depend on n_r through the term L(x,y,z) = αx + βy + γ(z−H). This contrast highlights the practical advantage of the ratio-based approach: direction finding via GLS/WLS requires no receiver pose calibration.

---

### Comment #6 — Tilt-azimuth no aparecen en modelo
**Tipo**: Adición explícita en Sec. IV
**Estado actual**: La Eq. de n_{t,i} en coordenadas esféricas está en línea 450–453, pero no se conecta explícitamente con el CRLB.

**Acción**: Después de la Eq. de n_{t,i} (línea 453), añadir:

> "Substituting this parameterization into the channel model (2)–(3) and hence into the FIM (16), the PEB in (XX) becomes an explicit function of the 2K angular variables {(θ_i, φ_i)}_{i=1}^K. The GA searches over this 2K-dimensional decision space to minimize the RMSE of the PEB evaluated over the 3D testbed."

---

### Comment #7 — 2K unknowns vs K mediciones → underdetermined
**Tipo**: Clarificación (el reviewer confunde diseño con estimación)
**Ubicación**: Sec. IV, después de describir el GA

**Acción**: Añadir un párrafo:

> "We emphasize that the GA optimization is an offline system-design problem, not an online estimation problem. The 2K decision variables (tilt–azimuth pairs) define the orientation set; for each candidate set, the PEB is evaluated analytically over the entire 3D testbed using the closed-form FIM in (16). No measurements are involved in this optimization—only theoretical performance bounds. The ratio of design variables to measurements therefore does not constitute an underdetermined estimation problem. Once the optimal orientation set is fixed, the online estimation of the 3D receiver position uses K power measurements to solve for 3 unknowns (x, y, z), which is overdetermined for K ≥ 4."

---

### Comment #8 — ¿r es fijo en la optimización?
**Tipo**: Clarificación
**Ubicación**: Sec. IV (puede ir en el mismo párrafo que Comment #7)

**Acción**: Añadir:

> "The orientation set is optimized to minimize the RMSE of the PEB averaged over all |R| = 1,792 receiver positions in the 3D testbed (Table II). The position r is therefore not fixed but sweeps the entire spatial grid during fitness evaluation. The resulting orientation set is position-independent and can be deployed universally."

---

### Comment #9 — Fig. 9 redundante con Fig. 2
**Tipo**: Eliminación o reemplazo
**Estado actual**: Necesito verificar qué figuras son Fig. 2 y Fig. 9 en el PDF compilado.

**Mapeo de figuras (por orden de aparición en .tex)**:
- Fig. 1: System geometry (línea 149)
- Fig. 2: Violin plot PEB optimized vs random (línea 488)
- Fig. 3: Heatmap PEB K=5 optimal vs random (línea 494)
- Fig. 4: PEB vs K for different Φ_{1/2} (línea 560)
- Fig. 5: PEB vs SNR (línea 568)
- Fig. 6: CDF of 3D position error (línea 901)
- Fig. 7: 3D position estimates (línea 933)
- Fig. 8: Computation latency (línea 967)

El reviewer dice "Fig. 9" pero hay 8 figuras. Probablemente se refiere a **Fig. 7** (3D position estimates) vs **Fig. 3** (heatmap PEB K=5 optimal), ya que ambas muestran distribución espacial del error para K=5 optimizado.

**Acción**: **Reemplazar Fig. 7** por una nueva figura de **Direction Finding** (CDF angular o robustez a tilt), que aporta información nueva. Los resultados de posición 3D ya están en la CDF (Fig. 6) y Table IV.

---

### Comment #10 — Latencia por mediciones secuenciales
**Tipo**: Nuevo párrafo en Sec. VII-D o al final de VII
**Acción**: Añadir discusión:

> "The proposed system acquires K+1 sequential measurements: K for direction finding and one for distance recovery. With state-of-the-art MEMS micromirrors capable of repositioning in ~100 μs [Liu:25] and N = 1000 samples per orientation at MHz-rate ADCs, each orientation requires approximately 1 ms of acquisition plus 0.1 ms of steering overhead. For K = 5, the total direction-finding window is ~5.5 ms, plus ~1.1 ms for distance recovery (including PD reorientation), totaling ~6.6 ms. At typical pedestrian speeds of 1.4 m/s, the displacement during this window is ~9 mm, which is below the centimeter-level positioning accuracy. For faster motion or larger K, motion compensation techniques from radar/sonar sequential sensing [ref] can be applied."

---

### Comment #11 — Falta baseline MLE + existente + SNR
**Tipo**: Clarificación teórica + nuevas simulaciones + nueva subsección VII-C

**Parte 1 — MLE / NL clarification** (ver `analysis_NL_CRLB.md` para detalles):

El NL **NO es el MLE** ni para dirección ni para posición 3D:
- No es MLE de dirección porque no perfila la distancia (nuisance) vía ratios y no pondera óptimamente.
- No es MLE de posición 3D porque opera en S² (solo dirección) y no usa la medición K+1.
- Un Joint MLE de posición (K+1 mediciones → r) **no es implementable** porque la medición K+1 es adaptiva (depende de n̂_d estimado de las K primeras).
- **GLS es el MLE para el modelo linealizado de ratios** → estadísticamente eficiente para dirección.

Texto para Sec. V (reposicionar NL como baseline):
> "As a baseline for comparison, we develop an iterative nonlinear least-squares (NLS) approach that directly fits the Lambertian power model on S². This method represents the class of numerical estimators commonly employed in optical positioning and serves to benchmark the closed-form GLS/WLS estimators proposed in Section VI. We note that, unlike GLS/WLS, the NLS requires knowledge of n_r and does not apply statistical weighting across orientations."

Texto para Sec. VI (posicionar GLS como eficiente):
> "Under the first-order approximation in (XX), GLS is the maximum-likelihood estimator for the direction parameter and is therefore statistically efficient: it achieves the Cramér–Rao bound of the ratio-based direction model."

Esto responde al reviewer sin necesidad de implementar un Joint MLE.

**Parte 2 — Baseline existente**:
[Chassagne2025] ya está incluido (K=3). Reforzar en el texto:

> "The K=3 baseline [Chassagne2025] represents the only existing single-LED single-PD direction-finding method; it was originally proposed for 2D and we extend it to 3D via SVD."

**Parte 3 — Performance vs SNR** (NUEVA subsección VII-C):
Usar/adaptar `Experiment_SNR_CRLB.m` que ya existe. Crear una nueva simulación:
- Barrer SNR de 0 a 50 dB
- Para cada SNR, ejecutar GLS, WLS, NL y calcular RMSE 3D
- Comparar con PEB teórico
- Generar figura: RMSE vs SNR con curvas para GLS, WLS, NL, CRLB para K=5

**Script necesario**: Nuevo script basado en `Experiment_SNR_CRLB.m` + `main_3D_withNoise.m`

---

### Comment #12 — CRLB con métricas estadísticas en Table IV
**Tipo**: Corrección de tabla + nota
**Estado actual**: Table IV (líneas 910–927) tiene fila "CRLB" con RMSE, CDF 90%, APE.

**Acción**:
1. Cambiar headers de la fila CRLB:
   - "RMSE [cm]" → mantener pero añadir nota
   - Añadir nota debajo de la tabla:
   > "For the CRLB row, 'RMSE' denotes the root-mean-square of the PEB over all testbed positions (a deterministic spatial statistic, not a Monte Carlo estimate); 'CDF 90%' is the 90th percentile of the PEB distribution across the testbed; 'APE' is the mean PEB."

2. Alternativamente, renombrar la fila: "PEB" en vez de "CRLB", y usar headers "RMS-PEB", "PEB₉₀", "Mean PEB".

---

### Comment #13 — Gap NL–CRLB
**Tipo**: Corrección de código + explicación teórica sólida
**Ubicación**: Después de Table IV discussion (línea ~908)

**Acción en 2 pasos**:

**Paso 1 — CORREGIR el NL** (ver sección AUDITORÍA DE CÓDIGO):
Corregir BUG-1,2,3,5 y re-ejecutar. Esto mejorará el NL pero NO lo hará alcanzar el PEB.

**Paso 2 — Explicar el gap con argumentos sólidos** (ver `analysis_NL_CRLB.md`):

El gap tiene **dos causas independientes**, ambas legítimas:

> **(i) Two-stage vs joint estimation.** The PEB represents the bound for joint estimation of r from all K+1 measurements. All estimators in this paper employ a two-stage architecture. The K direction-finding measurements contain distance information (through absolute power levels) that is not used in the two-stage decomposition. Moreover, the K+1 measurement is adaptive (its orientation depends on the direction estimate), so a joint MLE processing all K+1 measurements simultaneously is not feasible. The PEB, evaluated under perfect beam alignment (genie-aided), is therefore an optimistic lower bound that no practical estimator can attain.
>
> **(ii) NLS is not the direction MLE.** The NLS fits absolute powers on S² without statistical weighting, whereas GLS exploits ratios that cancel the nuisance parameters d and n_r and applies the inverse-covariance weighting Σ_β⁻¹. This explains why GLS outperforms NLS despite being closed-form.

**Texto complementario para Sec. III** (interpretar el PEB):
> "The PEB is evaluated at the true position r with the distance-recovery measurement assuming perfect beam alignment (n_{t,K+1} = n_d). This genie-aided formulation follows standard CRLB practice for adaptive sensing systems [Kay, 1993]. Because the K+1-th orientation depends on the direction estimate from the first K measurements, the PEB serves as an optimistic lower bound. All proposed estimators share the same two-stage architecture and are compared against this common benchmark."

---

### Comment #14 — Correcciones gramaticales
**Tipo**: Edición puntual (3 correcciones)

| #   | Línea | Actual                                                                                                   | Corregido                                             |
| -----| -------| ----------------------------------------------------------------------------------------------------------| -------------------------------------------------------|
| 14a | 68    | "They presumes"                                                                                          | "They presume"                                        |
| 14b | 50    | "Therefore, there is a need for dedicated indoor position systems (IPS), which use...are widely studied" | Reescribir completamente (se resuelve con Comment #1) |
| 14c | 61    | "transformer"                                                                                            | "Transformer"                                         |

---

## AUDITORÍA DE CÓDIGO — BUGS ENCONTRADOS

### BUG-1 [CRÍTICO]: NL estimator — varianza de ruido en unidades incorrectas

**Archivo**: `original_bastien_NL_K9.m`, línea 101
```matlab
sigma2 = 30e6*10^(-21.0);  % ← unidades A² (eléctrico)
```

**Problema**: Esta es la varianza eléctrica σ_w². Pero el ruido se aplica a potencia óptica P_r (en W).
En `main_3D_withNoise.m` (línea 74) se hace correctamente:
```matlab
sigma2 = 30e6*10^(-21.0)/(R_pd^2);  % ← convierte a W² (óptico)
```

**Impacto**: El NL usa σ_w² en vez de σ² = σ_w²/R_pd². Como R_pd = 0.63, σ² = σ_w²/0.397, es decir el NL usa ~2.5x MENOS ruido del que debería. Esto hace que el NL parezca mejor de lo que es con el ruido correcto, pero como además tiene BUG-2, los efectos se compensan parcialmente.

**Fix**: `sigma2 = 30e6*10^(-21.0)/(R_pd^2);`

---

### BUG-2 [CRÍTICO]: NL estimator — normalización de potencia inconsistente con función de costo

**Archivo**: `original_bastien_NL_K9.m`, línea 139
```matlab
P_r_noisy{i_pos,i_dir} = (P_r{i_pos,i_dir} + sqrt(sigma2).*randn(1,1000))./(-C);
```

**Problema**: La potencia se divide por `(-C)` = paper_C. Pero la función de costo (línea 171) usa:
```matlab
F_i = sum( ( C.*L.*Q_i.^m_t - P_r_noisy{i_pos,1} ).^2 );
```

El modelo en la unit sphere es: `P_r = -paper_C * Q^m * L`, es decir `P_r = code_C * Q^m * L` (con code_C = -paper_C).

Si normalizamos: `P_r_noisy = P_r / paper_C = -Q^m * L`.
Pero el modelo en la cost function es: `code_C * L * Q^m = -paper_C * L * Q^m`.

Evaluando el residuo cuando noise=0:
```
code_C * L * Q^m - P_r/paper_C = (-paper_C)*L*Q^m - (-Q^m*L) = Q^m*L*(1 - paper_C)
```

**Esto NO es cero** a menos que paper_C = 1 (lo cual no es el caso: paper_C ≈ 2.16e-8).

**Impacto**: La función de costo tiene un offset no nulo → el optimizador NO minimiza el residuo correcto. Esto degrada directamente la calidad de la estimación NL.

**Fix**: Elegir UNA de estas opciones:
- **Opción A** (recomendada): No normalizar. Usar potencia directa:
  ```matlab
  P_r_noisy{i_pos,i_dir} = P_r{i_pos,i_dir} + sqrt(sigma2).*randn(1,1000);
  ```
  Y ajustar la cost function para usar el modelo completo (no unit-sphere).
- **Opción B**: Normalizar correctamente y ajustar la cost function.

---

### BUG-3 [MODERADO]: NL estimator — restricción de esfera unitaria deshabilitada

**Archivo**: `original_bastien_NL_K9.m`, líneas 199, 212
```matlab
% sphereConstraint = x.^2 + y.^2 + z.^2 == 1;  % ← COMENTADO
% prob.Constraints.sphereConstraint = sphereConstraint;  % ← COMENTADO
```

**Problema**: El modelo de la cost function asume que (x,y,z) ∈ S² (unit sphere). Sin esta restricción, el optimizador opera en R³ sin restricción de norma. El resultado se normaliza post-hoc (línea 219: `v_hat./norm(v_hat)`), pero el óptimo encontrado sin la restricción no es el mismo que el óptimo restringido.

**Impacto**: Convergencia a soluciones subóptimas. La normalización post-hoc "arregla" la norma pero no garantiza la dirección óptima.

**Fix**: Rehabilitar la sphere constraint, o reformular usando coordenadas esféricas (θ, φ) con 2 variables en vez de 3 cartesianas + 1 constraint.

---

### BUG-4 [MENOR]: WLS/SVD — ruido en distance recovery con unidades mezcladas

**Archivo**: `main_3D_withNoise.m`, líneas 200, 290, 315
```matlab
P_r_axis_noisy_SVD = (R_pd.*P_r_axis_SVD + sqrt(sigma2).*randn(1,1000))./R_pd;
P_r_axis_noisy_WLS_SVD = (R_pd.*P_r_axis_WLS_SVD + sqrt(sigma2).*randn(1,1000))./R_pd;
P_r_axis_noisy_WLS_Robust = (R_pd.*P_r_axis_WLS_Robust + sqrt(sigma2).*randn(1,1000))./R_pd;
```

**Problema**: `R_pd*P_r` está en A (eléctrico) pero `sqrt(sigma2)` está en W (óptico, porque sigma2 = σ_w²/R_pd²). Se suman A + W → dimensionalmente incorrecto.

**Resultado numérico**: Equivale a usar varianza σ²/R_pd² en vez de σ² para el ruido en DR. El ruido es ~2.5x menor que el correcto → WLS/SVD tienen resultados de distancia ligeramente optimistas.

**Nota**: El GLS (línea 337) hace correctamente:
```matlab
P_r_axis_noisy_GLS = P_r_axis_GLS + sqrt(sigma2).*randn(1,1000);  % ← CORRECTO
```

**Fix**: Para WLS y SVD, usar el mismo patrón que GLS:
```matlab
P_r_axis_noisy = P_r_axis + sqrt(sigma2).*randn(1,1000);
```

---

### Resumen de impacto en resultados del paper

| Método | Bug | Efecto en RMSE | ¿Cambian los resultados? |
|--------|-----|----------------|--------------------------|
| GLS | Ninguno | — | ❌ No |
| WLS | BUG-4 (menor) | RMSE ligeramente optimista | ⚠️ Leve empeoramiento al corregir |
| NL | BUG-1+2+3 | RMSE significativamente afectado | ✅ Sí, puede mejorar significativamente |
| SVD/K=3 | BUG-4 (menor) | RMSE ligeramente optimista | ⚠️ Leve empeoramiento al corregir |
| CRLB | Ninguno | — | ❌ No |

### BUG-5 [MODERADO]: NL usa `fmincon` (general) en vez de `lsqnonlin` (least-squares)

**Archivo**: `original_bastien_NL_K9.m`, línea 217
```matlab
[sol,fval] = solve(prob,x0); % usa optimproblem → fmincon internamente
```

**Problema**: `fmincon` (interior-point) es un optimizador genérico. No explota la estructura de suma de cuadrados del problema NL. Para un MLE Gaussiano (= least-squares), el solver adecuado es `lsqnonlin` con trust-region-reflective, que implementa Gauss-Newton y converge más rápido y a mejores soluciones.

**Impacto**: Convergencia más lenta y posibles mínimos locales. El paper dice "Gauss-Newton" en la discusión de complejidad (línea 960), pero la implementación NO es Gauss-Newton.

**Fix**: Reformular usando `lsqnonlin` o al menos `fmincon` directo con Jacobian analítico. Alternativamente, parametrizar en coordenadas esféricas (θ,φ) → 2 variables, sin constraint de esfera.

---

### ISSUE-1: [RESUELTO] El claim "NL = MLE" — corregido en Comment #11

**Resolución**: Comment #11 Parte 1 ha sido actualizado. El NL se presenta como baseline (NLS), no como MLE. GLS se presenta como el MLE del modelo linealizado de ratios. El Joint MLE no es implementable (medición K+1 adaptiva). Ver `analysis_NL_CRLB.md` Sec. 6 para justificación completa.

---

### ISSUE-2: Comment #9 — no verificamos qué figura es

**Ubicación en plan**: Comment #9

**Problema**: El plan asume que "Fig. 9" = Fig. 7 (3D position estimates) y "Fig. 2" = Violin plot. Pero el paper tiene 8 figuras, no 9. ¿El reviewer cuenta subfigures? ¿Cuenta Table I como float?

**Acción**: Compilar el PDF y verificar la numeración real antes de decidir qué reemplazar. Podría ser que el reviewer cuente las subfiguras de Fig. 3 como Fig. 3a=Fig.3 y Fig.3b=Fig.4, lo cual desplazaría toda la numeración.

---

### ISSUE-3: Comment #10 — números de latencia no verificados

**Ubicación en plan**: Comment #10

**Problema**: El plan usa "MHz-rate ADCs" y "MEMS ~100 μs" sin verificar. Si la ADC es a 10 MHz, N=1000 samples = 0.1 ms (no 1 ms). Esto cambia el argumento significativamente.

**Acción**: Antes de escribir el párrafo de latencia:
1. Definir una frecuencia de muestreo razonable y citarla (e.g., 1 MHz es conservador para fotodiodo)
2. Verificar el tiempo de steering de MEMS con la referencia [Liu:25]
3. Calcular con los números correctos y ENTONCES escribir el párrafo

---

### ISSUE-4: Comment #7 — ¿el GA realmente converge bien?

**Ubicación en plan**: Comment #7

**Problema**: El plan solo aclara que "GA es diseño offline, no estimación." Esto es correcto conceptualmente, pero el reviewer también dice "the solution obtained by GA may not be reliable." ¿Se verificó la convergencia del GA?

**Acción**: Además de la clarificación, añadir evidencia de fiabilidad del GA:
> "The GA was run with 5 independent random initializations for each K. The best-fitness solutions across runs differed by less than X% in RMSE-PEB, confirming convergence."

Si esto no se hizo, **hacerlo** antes de escribir la respuesta. Es un experimento rápido (re-ejecutar el GA unas cuantas veces y comparar).

---

### TYPO en plan: Comment #4c

**Ubicación**: línea 147
```
u_y = [0,0,1]^T  ← INCORRECTO, debería ser [0,1,0]^T
```

---

### Plan de acción para bugs

1. **Corregir BUG-1, BUG-2, BUG-3, BUG-5** en el NL → re-ejecutar → comparar con CRLB
2. **Corregir BUG-4** en WLS/SVD → re-ejecutar → verificar que conclusiones se mantienen
3. **El NL corregido seguirá sin alcanzar el PEB** (por two-stage + no es MLE + PEB es genie-aided). Esto es esperado y se explica en Comment #13.
4. **Verificar que GLS sigue siendo mejor que NL corregido** en direction finding → confirma la narrativa
5. **Actualizar Table IV** con nuevos valores de NL y WLS corregidos
6. **Regenerar Fig. 6** (CDF) con nuevos datos

---

## SIMULACIONES NUEVAS NECESARIAS

### SIM-1: CDF de error angular (Direction Finding)
**Propósito**: Comment #11 (parcial), nueva subsección VII-A-1
**Qué calcular**: Error angular `θ_err = acos(n̂_d · n_d)` en grados para GLS, WLS, NL
**Datos**: Usar las mismas posiciones y ruido que `main_3D_withNoise.m`
**Figura**: CDF del error angular para K=5 y K=9, con GLS, WLS, NL
**Script base**: Modificar `main_3D_withNoise.m` para extraer `v_tr` (dirección real) y `d_hat` (dirección estimada), calcular ángulo entre ellos
**Esfuerzo**: Bajo (la dirección ya se estima; solo falta calcular el ángulo y plotear)

### SIM-2: Robustez a tilts aleatorios del PD
**Propósito**: Nuevo resultado clave (VII-A-2), refuerza Comment #5, demuestra Proposition 1
**Diseño del experimento**:
```
Para cada θ_tilt ∈ {0°, 5°, 10°, 15°, 20°, 25°, 30°}:
    Para cada posición del testbed (con n_r fijo = [0,0,1] en resultados principales):
        1. Generar n_r_tilted = R_z(φ_random) · R_x(θ_tilt) · [0,0,1]ᵀ
           (φ_random uniforme en [0°,360°])
        2. Generar potencias P_{r,i} con ESE n_r_tilted
        3. Estimar dirección con GLS, WLS (sin decirles n_r) y NL (con n_r=[0,0,1] erróneo)
        4. Calcular error angular: acos(n̂_d · n_d)
    Promediar error angular sobre posiciones y realizaciones
```
**Resultado esperado**:
- **GLS/WLS**: curvas PLANAS (error angular constante vs tilt) → confirma Proposition 1
- **NL**: curva CRECIENTE (se degrada porque usa n_r=[0,0,1] pero dato tiene n_r inclinado)
- Este contraste es LA figura más potente del paper revisado

**Nota sobre n_r en las simulaciones principales**:
Todos los resultados principales (Table IV, CDF 3D, CDF angular, RMSE vs SNR) usan n_r = [0,0,1].
Para GLS/WLS esto es válido universalmente (Proposition 1: resultado idéntico con cualquier n_r).
Para PEB y NL es un caso particular (evaluado para n_r = [0,0,1]).
SIM-2 es el ÚNICO experimento que varía n_r.

**Figura**: Curvas de RMSE angular vs θ_tilt, 3 curvas (GLS, WLS, NL)
**Script**: Nuevo, basado en `main_3D_withNoise.m`
**Esfuerzo**: Medio (bucle sobre tilts + regenerar potencias)

### SIM-3: RMSE vs SNR para estimadores
**Propósito**: Comment #11
**Qué hacer**:
1. Barrer SNR de 0 a 50 dB (ajustando σ²)
2. Para cada SNR: ejecutar GLS, WLS, NL sobre posiciones del testbed
3. Calcular RMSE 3D y comparar con PEB
**Figura**: RMSE vs SNR con curvas GLS, WLS, NL, PEB para K=5
**Script base**: Combinar `Experiment_SNR_CRLB.m` con los estimadores de `main_3D_withNoise.m`
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
| 6 | CDF 3D position error | Sin cambios |
| 7 | ~~3D position estimates~~ → **CDF error angular (DF)** | **REEMPLAZAR** (Comment #9) |
| 8 | Computation latency | Sin cambios |
| 9 | **Robustez a tilt del PD** | **NUEVA** |
| 10 | **RMSE vs SNR (estimadores)** | **NUEVA** |

Total: 10 figuras (8 existentes − 1 eliminada + 3 nuevas). Si el límite de figuras es restrictivo, la fig. de robustez a tilt puede ser un subfigure combinado con la CDF angular.

---

## TABLA: ESTADO FINAL

| Tabla | Contenido | Cambio |
|---|---|---|
| I | State-of-the-art single-LED | Corregir "Arbitrary" → "Arbitrary†" con nota |
| II | GA parameters | Sin cambios |
| III | Optimal orientations | Sin cambios |
| IV | Performance metrics | Corregir nomenclatura fila CRLB (Comment #12) |
| V | **Direction-finding angular error** | **NUEVA** (métricas de error angular) |

---

## CÓDIGO: ARCHIVOS A MODIFICAR/CREAR

| Archivo | Acción |
|---|---|
| `vlp_gls.m` | Sin cambios |
| `vlp_wls.m` | Sin cambios |
| `PEB_complete.m` | Sin cambios |
| `original_bastien_NL_K9.m` | **CORREGIR** BUG-1 (sigma2), BUG-2 (normalización), BUG-3 (sphere constraint) |
| `main_3D_withNoise.m` | **CORREGIR** BUG-4 (líneas 200, 290, 315: noise en distance recovery) |
| **NUEVO**: `Fig_CDF_angular.m` | CDF de error angular para DF (SIM-1) |
| **NUEVO**: `Fig_Robustness_tilt.m` | Robustez a tilts del PD (SIM-2) |
| **NUEVO**: `Fig_RMSE_vs_SNR_estimators.m` | RMSE vs SNR para estimadores (SIM-3) |

---

## ORDEN DE EJECUCIÓN

### Fase 0: Corrección de bugs (ANTES de todo lo demás)
0a. [ ] Corregir BUG-1, BUG-2, BUG-3 en `original_bastien_NL_K9.m` (o crear versión corregida)
0b. [ ] Corregir BUG-4 en `main_3D_withNoise.m` (líneas 200, 290, 315)
0c. [ ] Re-ejecutar NL para K=5 y K=9 → generar nuevos .mat
0d. [ ] Re-ejecutar WLS/SVD → generar nuevos .mat
0e. [ ] Comparar NL corregido vs GLS y CRLB → confirmar que GLS > NL > WLS (narrativa Comment #13)
0f. [ ] Verificar que GLS no cambió (sanity check)
0g. [ ] Regenerar Table IV y Fig. 6 (CDF) con datos corregidos

### Fase 1: Simulaciones nuevas (después de Fase 0, pueden correr en paralelo)
1. [ ] SIM-1: CDF error angular → `Fig_CDF_angular.m`
2. [ ] SIM-2: Robustez a tilt → `Fig_Robustness_tilt.m`
3. [ ] SIM-3: RMSE vs SNR → `Fig_RMSE_vs_SNR_estimators.m`

### Fase 2: Reescritura del paper (secuencial)
4. [ ] Abstract (reescribir)
5. [ ] Sec. I: Reestructurar Introducción (Comments #1, #2)
6. [ ] Sec. II-A: Ajustar descripción de n_r (Comment #5, parte 2)
7. [ ] Sec. II-B2: Reescribir Distance Recovery (Comment #3)
8. [ ] Sec. III: Fusionar III-A + III-B, citar Kay (Comment #4b)
9. [ ] Sec. III: Añadir frase sobre dependencia μ_i(r) (Comment #4a)
10. [ ] Sec. IV: Añadir conexión θ,φ → CRLB (Comment #6)
11. [ ] Sec. IV: Añadir párrafo offline design (Comments #7, #8)
12. [ ] Sec. V: Aclarar que NL requiere n_r conocido (Comment #5)
13. [ ] Sec. VI-A: NUEVA — Proposition 1 (n_r-independence) (Comment #5)
14. [ ] Sec. VI-B: Expandir explicación GLS (Comment #4d)
15. [ ] Sec. VI-C: Expandir explicación WLS (Comment #4d)
16. [ ] Sec. IV: Definir u_x, u_y, u_z (Comment #4c)
17. [ ] Sec. VII-A: NUEVA — DF performance + robustez tilt
18. [ ] Sec. VII-C: NUEVA — RMSE vs SNR (Comment #11)
19. [ ] Sec. V: Reposicionar NL como baseline + Sec. VI: GLS como direction MLE (Comments #11, #13)
20. [ ] Table I: Corregir "Arbitrary" (Comment #5)
21. [ ] Table IV: Corregir nomenclatura CRLB (Comment #12)
22. [ ] Sec. VII: Discutir latencia (Comment #10)
23. [ ] Sec. VII: Reemplazar Fig. 7 (Comment #9)
24. [ ] Algorithm 1: Actualizar (Comment #3)
25. [ ] Conclusion: Actualizar
26. [ ] Gramática: 3 correcciones (Comment #14)

### Fase 3: Verificación
27. [ ] Compilar LaTeX, verificar numeración de ecuaciones/figuras/tablas
28. [ ] Verificar coherencia de claims entre Abstract, Intro, y Conclusion
29. [ ] Preparar response letter al reviewer

---

## ABSTRACT PROPUESTO (borrador)

> State-of-the-art optical wireless positioning (OWP) commonly reaches centimeter-level accuracy by relying on dense multi-LED infrastructures, photodiode (PD) arrays, or image-sensor receivers, incurring hardware complexity and deployment cost. This paper introduces a single beam-steered LED, single-PD OWP architecture for three-dimensional (3D) indoor localization. The transmitter is steered through K known orientations while the PD collects the resulting received-signal-strength variations. We develop closed-form direction estimators—a statistically efficient generalized least squares (GLS) and a lightweight weighted least squares (WLS)—and prove that they are mathematically independent of the receiver orientation, enabling direction finding without receiver pose knowledge or control. We derive a composite Cramér–Rao lower bound and position-error bound (PEB) for the joint observation model, and optimize the steering-pattern via a genetic algorithm. A single beam-aligned ranging measurement then recovers the LED-to-PD distance, completing the 3D position. Simulations demonstrate centimeter-level 3D accuracy, sub-degree direction-finding error, and robustness to arbitrary PD tilts.
