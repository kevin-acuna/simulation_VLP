# Plan de Acción — Minor Revision TCOM-TPS-25-2414.R1

**Manuscrito:** "Model-Based Beam-Steered Optical Wireless Positioning with Single-LED Single-Photodiode for 3D Localization"
**Decisión:** Minor Revision (Editor: Dr. Mohammed Elamassie)
**Plazo:** 30 días desde la recepción del correo (estrictamente aplicado por el sistema editorial).
**Entregables:**
1. Manuscrito revisado (`main.tex` → PDF).
2. Response letter punto por punto, subida como **"supplementary file"** (NO como cover letter — el editor lo advierte explícitamente).

---

## 0. Diagnóstico global

El tema transversal de esta ronda es **consistencia de las afirmaciones (claims)**: el sistema tiene dos etapas con requisitos distintos sobre el receptor:

| Etapa | Requisito sobre el PD |
|---|---|
| Direction finding (D-F, K mediciones) | Orientación **arbitraria y desconocida**, fija durante el barrido. Sin rotación. |
| Distance recovery (medición K+1) | **Una** reorientación cooperativa del PD hacia el LED ($\mathbf{n}_r = -\hat{\mathbf{n}}_d$). |

El editor y el Reviewer 2 señalan que frases como *"full 3D indoor localization without receiver rotation"* (Conclusión, línea 959) sobredimensionan la capacidad del pipeline completo. Todo lo demás (R2#2–4, R3#1–6) son adiciones puntuales de claridad, justificación y discusión. **Ningún comentario cuestiona la técnica**: es una revisión de redacción, alcance y reconocimiento de limitaciones.

### Mapa de tablas (para interpretar los comentarios)
- Table I = `tab:single_led_vlp` (estado del arte, líneas 57–88)
- Table II = `tab:ga_params` (parámetros GA/testbed, líneas 365–399)
- Table III = `tab:optimal_orientations_2col` (orientaciones óptimas)
- Table IV = `tab:DF_performance` | Table V = `tab:tilt_robustness`
- Table VI = `tab:estimation_performance` (posicionamiento 3D, líneas 903–923) ← la "Table VI" de R3#1

---

## 1. EDITOR — Consistencia de claims + reconocer validación por simulación

> *"statements such as 'full 3D indoor localization without receiver rotation' still appear, particularly in the Conclusion... The authors should also... clearly acknowledge the simulation-based nature and practical limitations of the present validation."*

### Acción E.1 — Barrido global de claims (CRÍTICO, hacerlo primero)
Ubicaciones detectadas con afirmaciones a corregir o blindar:

| Línea | Texto actual | Cambio propuesto |
|---|---|---|
| **959 (Conclusión)** | "delivers full 3D indoor localization **without receiver rotation**, cameras, or PD arrays" | **Ocurrencia citada por el editor.** Reemplazar por: *"delivers full 3D indoor localization without cameras or PD arrays: the direction-finding stage operates with the receiver held at an arbitrary, unknown orientation, while completing the 3D position requires a single cooperative PD reorientation for distance recovery."* |
| 98 (Intro) | "the entire beam-steering complexity resides in the infrastructure" | Añadir matiz: *"...resides in the infrastructure; on the receiver side, a single cooperative PD reorientation is required only at the final distance-recovery step."* |
| 102 (Contribución 1) | "achieves full 3D localization without camera sensing or PD arrays" | Añadir al final del bullet: *"The direction-finding stage operates under arbitrary receiver orientation; completing the 3D position requires one cooperative PD reorientation for distance recovery."* |
| 40 (Abstract) | "recover the distance from a single cooperative beam-aligned measurement" | Hacer explícita la reorientación: *"...from a single cooperative beam-aligned measurement in which the PD is reoriented toward the LED."* |
| 965 (Conclusión) | Ya está correctamente matizado ("It requires no receiver rotation **during the $K$ measurements**") | Verificar; no requiere cambio. |

**Verificación:** tras editar, ejecutar búsqueda de los patrones `without receiver rotation`, `without rotation`, `zero receiver movement`, `receiver-orientation-free`, `arbitrary orientation` y releer Abstract, Intro, Tabla I, Sec. II.B, Conclusión completos.

### Acción E.2 — Reconocimiento explícito de validación por simulación
Ver acción R2.2 (misma subsanación, se responde a ambos).

**Response letter:** agradecer, listar cada ubicación corregida con cita textual antes/después.

---

## 2. REVIEWER 1 — Sin comentarios

**Acción:** ninguna en el manuscrito. En la response letter: una línea de agradecimiento ("We thank the reviewer for the positive assessment.").

---

## 3. REVIEWER 2

### R2.1 — No sobredimensionar la naturaleza "orientation-free" (Abstract, Table I, contribuciones)
> Idéntico en esencia al comentario del editor.

**Acción:** cubierto por E.1 (Abstract, contribuciones) + R2.3 (Table I). En la response letter, responder a R2.1 y al editor con la misma tabla de cambios, referenciándose mutuamente.

### R2.2 — Reconocer explícitamente que la evaluación es solo por simulación
**Acción:** añadir una subsección corta al final de la Sec. VII (antes de la Conclusión), p. ej.:

```latex
\subsection{Limitations of the Present Validation}
\label{subsec:limitations}
```

Contenido propuesto (4–6 frases):
1. Todos los resultados provienen de simulaciones Monte Carlo del modelo LOS lambertiano con AWGN; **no se presenta validación experimental** en este trabajo.
2. Idealizaciones asumidas: (i) apuntamiento perfecto del steering (sin jitter ni error de pointing en $\mathbf{n}_{t,i}$); (ii) constante radiométrica $C$ y orden lambertiano $m$ perfectamente calibrados; (iii) receptor estático durante las $K{+}1$ adquisiciones; (iv) canal LOS puro sin reflexiones NLOS (ver discusión en Sec. VI); (v) ruido homocedástico e independiente.
3. Impacto esperado de cada idealización en un despliegue real (1 frase, honesta: pointing error y NLOS son los factores dominantes).
4. Prototipo experimental en curso / planificado como trabajo futuro (enlaza con "Future works (i) experimental validation", línea 967).

**Además:** en la Conclusión (línea 963), cambiar "Monte Carlo simulations... confirmed the effectiveness" por algo como "Monte Carlo simulations... support the effectiveness" y añadir referencia a la nueva subsección de limitaciones.

**Nota:** el Abstract ya dice "Simulations over 1,792 testbed positions..." — está bien, no oculta nada.

### R2.3 — Table I: notación "Arbitrary / Controlled — D-F / 3D" difícil de leer
**Ubicación:** línea 81 (fila "Ours") y nota al pie línea 86.

**Acción:** reestructurar las celdas apiladas con etiquetas explícitas por línea:
- Columna *Rx Orientation*: `Arbitrary (D-F)` / `One reorient. (3D)`
- Columna *2D/3D*: `Direction (D-F)` / `3D position`
- Columna *Error*: `0.54° (D-F)` / `2.00 cm (3D)`

Y reescribir la nota al pie: *"$^\dagger$Two-stage system: during direction finding (D-F) the PD is held at any fixed, unknown orientation (arbitrary, no rotation); completing the 3D position requires a single cooperative PD reorientation toward the transmitter for distance recovery. See Section VI-C."*

Alternativa (si el apilado sigue denso): dividir "Ours" en **dos filas** ("Ours — direction finding" y "Ours — full 3D"). Elegir tras compilar y ver el render.

**Ojo:** la nota usa `\emph{Note:}` (línea 86) y la Tabla VI usa `\textit{Note}` (línea 922) — unificar y respetar `style_rules.txt` (regla 4: no italics).

### R2.4 — Los claims de robustez a tilt aplican a la etapa D-F, no a distance recovery
**Ubicaciones y acciones:**

| Línea | Acción |
|---|---|
| **40 (Abstract)** | "with robustness to random receiver tilts (degradation below 3\%)" → *"with direction-finding robustness to random receiver tilts (degradation below 3\%)"*. |
| 834–838 (Sec. VII.A.2) | Ya es explícitamente D-F ("direction-finding performance under random receiver tilts"). Añadir 1 frase de cierre: *"Note that this robustness property pertains to the direction-finding stage; the distance-recovery measurement is, by design, a cooperative aligned acquisition (Section II-B)."* |
| 963 (Conclusión) | Ya dice "negligible effect on direction-finding accuracy" — correcto, no cambiar. |
| Table V caption (842) | Opcional: "Direction-finding RMSE under random receiver tilt" ya lo dice. OK. |

---

## 4. REVIEWER 3

### R3.1 — Explicación física/geométrica de por qué WLS empeora de K=5 a K=9 (Table VI)
**Ubicación:** línea 899 (Sec. VII.B). Ya existe una frase (aprox. estadística), pero el revisor pide la explicación **física/geométrica**.

**Explicación a desarrollar (mecanismo en 3 pasos):**
1. **Ruido de referencia compartido:** todos los ratios $\hat\beta_i$ se forman contra la misma medición de referencia $\hat\mu_1$ (ec. de $\tilde n_i$, Apéndice B), de modo que sus errores están positivamente correlacionados; la correlación por pares alcanza su máximo ($\rho \to 1/2$) cuando $\mu_i \approx \mu_1$.
2. **Geometría del set K=9:** el set GA-optimizado para K=9 (Table III) llena el espacio angular con azimuts densamente espaciados (~40°) y varios tilts casi idénticos (≈62–67°). Consecuencias geométricas: (i) más orientaciones reciben potencias comparables a la de referencia → correlaciones cruzadas más fuertes; (ii) las normales de restricción $\mathbf{a}_i$ de orientaciones vecinas se vuelven **casi paralelas** → hiperplanos casi redundantes que aportan información angular repetida.
3. **Conteo:** los términos de covarianza que WLS ignora crecen **cuadráticamente** ($\binom{K-1}{2}$: 6 pares en K=5 vs 28 en K=9), mientras la diagonal crece linealmente. GLS pondera esa redundancia vía los off-diagonales de $\mathbf{\Sigma}_\beta$ (efectivamente "descuenta" restricciones correlacionadas); WLS las trata como independientes y **sobre-cuenta el ruido compartido de la referencia**, sesgando la solución del autovector. En K=5 el error de ponderación es pequeño; en K=9 supera la ganancia de las mediciones extra.

**Acción en el manuscrito:** expandir el pasaje de la línea 899 en ~5 frases con este mecanismo (mantener la frase actual como conclusión estadística).

**Verificación opcional (recomendada, da un número citable):** con los scripts de `fundamentals/estimators/`, calcular el coeficiente de correlación medio off-diagonal de $\mathbf{\Sigma}_\beta$ sobre el testbed para los sets K=5 y K=9; incluir el valor en el texto (p. ej., "the average pairwise correlation grows from X at K=5 to Y at K=9").

### R3.2 — Justificar el SNR de referencia de 14 dB (Sec. VII)
**Hecho verificado en el código:** `fundamentals/estimators/run_RMSE_vs_SNR_parallel.m` (líneas 35–38) confirma que 14 dB es el SNR que **resulta** del σ² nominal de `system_params.m`; no es un valor elegido a mano.

**Acción:** añadir 1–2 frases en la primera aparición (línea 459, Sec. IV) y una remisión en la línea 938 (Sec. VII.C):

> *"The reference value of 14 dB is not an arbitrary design choice: it is the testbed-averaged SNR obtained from (7c) when the nominal hardware parameters of Table II ($P_t=0.405$ W, $A_{det}=26.4$ mm², $R_p=0.63$ A/W, $\sigma_w^2=1.19\times10^{-14}$ A²) are evaluated over all 1,792 receiver positions with the $K=5$ set, and is therefore representative of a typical indoor operating environment with a commercial NIR LED and PIN photodiode at a 2 m ceiling height."*

En línea 938: "the nominal operating point ($\mathrm{SNR}=14$ dB, i.e., the testbed-average SNR implied by the Table II parameters; cf. Section IV)".

**Verificar antes de escribir:** recomputar en MATLAB que el promedio (7c) sobre el testbed con K=5 da ≈14 dB, para que el número citado sea exacto.

### R3.3 — Explicar la inicialización del GA (Sec. IV) y cómo evita mínimos locales
**Hecho verificado en el código:** `optimize_DEB_orientations_parallel.m` usa `optimoptions('ga', 'PopulationSize', 300, 'CrossoverFraction', 0.8, 'MutationFcn', @mutationadaptfeasible)` con límites `lb/ub` = Ω y **sin** `CreationFcn` custom → MATLAB usa la creación por defecto para problemas acotados (**población inicial uniforme dentro de Ω**, `gacreationuniform`).

**Acción:** insertar 1–2 frases tras la línea 409 (donde se describen los operadores):

> *"The initial population of $P=300$ individuals is generated by sampling each gene independently and uniformly at random within its bounded domain $\Omega$, providing dense, unbiased coverage of the $2K$-dimensional search space. This population-based multi-point exploration, combined with tournament selection and adaptive feasible mutation (which preserves diversity throughout the run), makes the search robust against entrapment in local minima; independent GA restarts converged to orientation sets with indistinguishable RMS-DEB values."*

**⚠ Verificar la última afirmación** (restarts independientes → mismo RMS-DEB) contra los logs en `fundamentals/optimization/results/` antes de incluirla; si no hay evidencia, ejecutar 3–5 restarts para K=5 o eliminar la frase. La simetría del set K=4 (±45°/135°/225°/315° a tilts iguales, Table III) es un indicio citable de estructura globalmente óptima.

### R3.4 — ¿Se mantiene la independencia de $\mathbf{n}_r$ si domina el multipath NLOS?
**Respuesta honesta:** NO exactamente. La independencia (Sec. VI-C, líneas 792–801) se apoya en la factorización LOS $\mu_i = \eta\,Q_i^m$ con $\eta$ **común** a las K orientaciones. Con NLOS, $\mu_i = \eta\,Q_i^m + P_{\mathrm{NLOS},i}$, donde el término de reflexión depende de $\mathbf{n}_r$ y de la geometría de la sala **de forma distinta para cada orientación** $i$ → los ratios (GLS/WLS) y la max-normalización (NLS) ya no cancelan exactamente → la independencia pasa a ser **aproximada**, con sesgo que escala con la fracción de potencia difusa-a-LOS.

**Acción:** añadir un párrafo al final de `subsec:nr_independence` (tras línea 801):
1. Enunciar la limitación anterior con la descomposición LOS+NLOS.
2. Argumentar por qué el LOS domina en este sistema: haz NIR **dirigido** (lambertiano con $\Phi_{1/2}=45°$ apuntado), enlaces cortos (~2–3 m), primer rebote atenuado por reflectividad y doble propagación; citar literatura de canal óptico indoor (Kahn1997 ya está en la bibliografía; valorar añadir una referencia de canal VLC con componente difusa).
3. Mitigaciones posibles (1 frase): restricción de FOV, gating temporal/frecuencial, o incorporar términos de reflexión al modelo — señalado como trabajo futuro.
4. Enlazar con la nueva subsección de limitaciones (R2.2) y opcionalmente con Future Works (línea 967).

**Response letter:** dejar claro que se agradece la observación, que la independencia es exacta bajo LOS y aproximada bajo NLOS, y citar el nuevo párrafo.

### R3.5 — Añadir discusión/citas sobre edge computing y digital twins (3 papers específicos)
**Naturaleza del comentario:** petición de citas con relevancia tangencial al paper (MEC aéreo, RIS/digital twin, UAV digital twins). Es una petición de tipo "citation request" clásica en revisión.

**Opciones:**
- **(A) Cumplir mínimamente (recomendada, bajo riesgo):** añadir 1–2 frases honestas donde la conexión es legítima — la localización indoor de precisión centimétrica como *servicio habilitador* para gemelos digitales y computación en el borde. Ubicación sugerida: párrafo de aplicaciones de la Intro (final de línea 53) o en Future Works (línea 967). Texto propuesto:
  > *"Beyond navigation and asset tracking, accurate indoor localization is a key enabler for emerging network-intelligence paradigms: centimeter-level position information supports reliability-aware computation offloading in MEC-enabled (aerial) edge computing [X], QoE-aware resource allocation for digital-twin interaction [Y], and cooperation and learning in digital-twin-enabled low-altitude UAV networks [Z]."*
  Añadir las 3 entradas BibTeX (buscar metadatos exactos: título/autores/DOI en IEEE Xplore):
  1. "Reliability-aware computation offloading for delay-sensitive applications in MEC-enabled aerial computing" — IEEE Trans. Green Commun. Netw.
  2. "Generative AI-aided QoE-aware resource allocation for RIS-assisted digital twin interaction with uncertain evolution" — IEEE Trans. Mobile Comput.
  3. "Digital twins for low-altitude UAV networks — cooperation and learning" — IEEE Trans. Mobile Comput.
- **(B) Rechazar cortésmente:** responder que los trabajos, aunque valiosos, quedan fuera del alcance de un paper de posicionamiento óptico modelo-basado, y citar la política de IEEE sobre citas no esenciales. Riesgo: irritar al revisor en una ronda que de otro modo es trámite.

**Recomendación:** opción (A) con redacción mínima y veraz (1 frase en la Intro). **Decisión final del autor.**

### R3.6 — "Subíndice pi" en los rangos x,y de Table II
**Diagnóstico:** en `main.tex` (líneas 393–395) los rangos son correctos y coherentes: sala $3\times3\times2$ m³, $x,y\in[-1.5,1.5]$ m (transmisor centrado en $[0,0,2]$), $z\in[0,1.2]$ m. **No hay π.** La causa más probable de la confusión es la fila "Search range (Ω): $\theta_i\in[0,80°]$, $\varphi_i\in[0,360°]$" (línea 388): el símbolo `\varphi` con subíndice $i$ puede confundirse visualmente con $\pi_i$.

**Acciones:**
1. Recompilar y **verificar visualmente** Table II en el PDF (`build/main.pdf`).
2. Desambiguar la fila del search range con etiquetas explícitas: *"Search range ($\Omega$): tilt $\theta_i\in[0°,80°]$; azimuth $\varphi_i\in[0°,360°]$"*. (No renombrar $\varphi\to\phi$: $\phi_i$ ya es el ángulo de irradiancia — colisión de notación.)
3. En la response letter, aclarar: (i) los rangos x,y son $[-1.5,1.5]$ m, consistentes con la sala de $3\times3\times2$ m³ centrada en el transmisor; (ii) el símbolo es $\varphi$ (azimut, definido en Sec. IV), no $\pi$; se han añadido etiquetas "tilt/azimuth" para evitar ambigüedad.

---

## 5. ORDEN RECOMENDADO DE SUBSANACIÓN

El criterio: primero el bloque de **claims globales** (toca Abstract, Intro, Table I y Conclusión, y condiciona la redacción de todo lo demás), después los bloques de **contenido nuevo**, luego los **menores**, y al final **verificación + response letter**.

| # | Tarea | Comentarios que cierra | Esfuerzo |
|---|---|---|---|
| 1 | Barrido global de claims (Conclusión L959, Intro L98/L102, Abstract L40) | **Editor**, R2#1 | Bajo (crítico) |
| 2 | Reestructurar fila "Ours" y nota de Table I | R2#3, R2#1 | Bajo |
| 3 | Re-alcance de claims de robustez a tilt (Abstract + cierre Sec. VII.A.2) | R2#4 | Bajo |
| 4 | Nueva subsección "Limitations of the Present Validation" (Sec. VII) + ajuste Conclusión | **Editor**, R2#2 | Medio |
| 5 | Párrafo NLOS en `subsec:nr_independence` (enlazado a limitaciones) | R3#4 | Medio |
| 6 | Explicación física/geométrica WLS K=5→K=9 (+ verificación MATLAB opcional de correlaciones) | R3#1 | Medio |
| 7 | Justificación SNR 14 dB (L459 + L938; verificar valor con MATLAB) | R3#2 | Bajo |
| 8 | Frase de inicialización del GA (L409; verificar claim de restarts en logs) | R3#3 | Bajo |
| 9 | Table II: etiquetas tilt/azimuth + verificación visual del PDF | R3#6 | Bajo |
| 10 | Decisión y (si procede) inserción de las 3 citas edge/digital-twin + BibTeX | R3#5 | Bajo (requiere decisión) |
| 11 | Pasada final de estilo (`style_rules.txt`: sin `\emph`/`\textit`, "z" en generalized, ":" antes de ecuaciones, acrónimos) + recompilación limpia | — | Bajo |
| 12 | Redactar response letter punto por punto (Editor, R1, R2×4, R3×6) con citas textuales antes/después; exportar como supplementary file | Todos | Medio |
| 13 | Releer PDF final completo verificando que ningún claim sobreviva al barrido; submit vía el enlace del correo | — | Bajo |

**Razones del orden:**
- 1–3 primero porque el editor condiciona la aceptación a esa consistencia ("This point should therefore be corrected consistently throughout the manuscript") y porque cualquier texto nuevo (tareas 4–8) debe redactarse ya con el vocabulario correcto ("D-F: arbitrary; 3D: one cooperative reorientation").
- 4–5 juntos: la limitación de simulación (R2#2) y la limitación NLOS (R3#4) comparten narrativa y referencias cruzadas.
- 6–8 son independientes entre sí (paralelizables), pero requieren verificaciones en MATLAB antes de fijar números/afirmaciones.
- 9–10 son cosméticos/estratégicos y no bloquean nada.
- 12 al final (aunque conviene ir anotando cada cambio al hacerlo): la response letter debe citar el texto final exacto y los números de página/columna del PDF recompilado.

---

## 6. Material disponible para la response letter

- `style_rules.txt` guarda dos párrafos retirados en la ronda anterior que pueden reutilizarse:
  - El párrafo "cooperative alignment is a sufficient but not necessary condition..." → útil para responder al **Editor** y a **R2#1** (demuestra que la distinción D-F/distance-recovery está bien entendida y que existe una variante broadcast sin reorientación del PD, a costa de conocer burdamente $\mathbf{n}_r$ con un acelerómetro).
  - El párrafo de la variante broadcast en conclusiones → puede mencionarse en la respuesta como trabajo futuro sin reinsertarlo en el paper.
- Estructura sugerida de la response letter: sección por revisor; para cada comentario: (i) comentario citado, (ii) respuesta, (iii) cambios en el manuscrito con texto nuevo en color/negrita y ubicación (sección, página).

## 7. Riesgos / puntos de atención

1. **No introducir nuevos overclaims** al redactar los párrafos nuevos (especialmente en R3#4: reconocer que la independencia es aproximada bajo NLOS; no prometer robustez no demostrada).
2. **Verificar en MATLAB antes de afirmar:** (i) SNR medio = 14 dB exacto con (7c) y K=5; (ii) restarts del GA consistentes; (iii) correlaciones de $\Sigma_\beta$ K=5 vs K=9 si se citan números.
3. La cita de R3#5 es opcional en rigor, pero un rechazo debe estar muy bien argumentado en la response letter; decidir pronto (tarea 10).
4. Al tocar Table I, recompilar y revisar que `\resizebox` no rompa la legibilidad de la fila "Ours" con celdas multilínea.
5. Mantener la regla de `style_rules.txt` sobre italics: las notas de Table I (`\emph{Note:}`) y Table VI (`\textit{Note}`) violan la regla 4 — unificar formato.
6. Fecha del correo → contar los 30 días y fijar fecha objetivo de submission con ~5 días de margen para la relectura final.
