# Plan de acción para fortalecer las respuestas a los revisores

**Última actualización:** 25-mayo-2026, 14:40

Después de revisar el `response_to_reviewers.html` completo (R1: 7 comentarios, R2: 14 comentarios, R3: 11 comentarios) y cruzarlo con el paper `IEEE_TCOM_RV2.tex`, identifico las siguientes acciones.

---

## ✅ COMPLETADO — Verificaciones en el paper

### A1. ✅ Caption Fig. 2 — "50 random sets"
- **CORREGIDO.** Caption ahora dice: "orange: 50 independently drawn random orientation sets per K."

### A2. ✅ Caption Fig. 3 — "single randomly generated set"
- **CORREGIDO.** Caption ahora dice: "(b) a single random set with tilt–azimuth pairs drawn uniformly from the GA search range."

### A3. ✅ NLS = fmincon/SQP (no Gauss-Newton)
- **YA CORRECTO.** Línea 898: `fmincon (SQP)`. No existe "Gauss-Newton" en el paper.

### A4. ✅ "and" antes de "silicon-photonics"
- **YA CORRECTO.** Línea 68: `...speed \cite{Feng2019}, and silicon-photonics...`

---

## � ALTA PRIORIDAD — Gap importante identificado

### B5. ⭐⭐ RMSE de estimadores (GLS, WLS, NLS) vs SNR
- **Comentarios que resuelve:** R2-C11 ("performance via SNR should also be provided"), R3-C6 ("analyze the impact of different ambient light power levels on the direction estimation stage")
- **Estado actual:** Fig. 5 muestra DEB/PEB **bounds** vs SNR, pero NO el rendimiento real de los estimadores vs SNR. Table IV reporta RMSE a un único punto operativo de SNR. **El reviewer pidió performance vs SNR, no bounds vs SNR.** Este es un gap significativo.
- **Propuesta:** Nueva figura (o superponer en Fig. 5) mostrando:
  - Eje X: SNR (dB)
  - Eje Y: Angular RMSE [°] (para DF) y/o Position RMSE [cm] (para 3D)
  - Curvas: GLS, WLS, NLS + DEB/PEB como referencia
  - Para K=5 (punto operativo principal)
  - Barrer σ² para generar múltiples puntos de SNR (e.g., 5 a 25 dB)
- **Qué demuestra:**
  1. Que los estimadores siguen la pendiente 1/√SNR de los bounds
  2. El gap estimador–bound se mantiene constante (en factor) a lo largo del SNR
  3. A qué SNR los estimadores dejan de ser fiables
  4. Responde R2-C11(b) con datos de estimadores, no solo bounds
  5. Responde R3-C6 mostrando qué pasa con los estimadores a bajo SNR (alta ambient light)
- **Esfuerzo:** Medio. Reutilizar código MC existente, barrer 5-7 valores de σ².
- **Impacto:** MUY ALTO. Es la pieza que cierra la brecha entre Fig. 5 (teórico) y Table IV (un punto).
- **Formato:** Puede ser una nueva Fig. 9, o un panel adicional en la subsección VII-A o VII-B.

---

## 🟡 MEDIA PRIORIDAD — Fortalecen argumentos débiles

### B1. Tabla ambient illuminance → σ² → SNR → DEB/PEB
- **Comentario:** R3-C6
- **Mejora:** Tabla o párrafo mapeando escenarios concretos (dark room, oficina 500 lux, bright 1000 lux) a σ² → SNR → DEB/PEB.
- **Nota:** Si hacemos B5 (estimadores vs SNR), esta tabla se vuelve aún más poderosa porque podemos incluir columnas de GLS/NLS RMSE reales.
- **Esfuerzo:** 1-2 horas (analítico). **Impacto:** Alto.

### B2. Simulación sync error robustness
- **Comentario:** R3-C3
- **Estado:** Argumento más débil de toda la response letter (solo cualitativo).
- **Mejora:** MC contaminando p% de muestras con orientación adyacente.
- **Esfuerzo:** 3-5 horas. **Impacto:** Muy alto.

### B3. ⭐ Error propagation analítico DF→DR (detalle expandido)
- **Comentario:** R3-C10
- **Estado:** Solo discusión cualitativa de las dos fuentes de gap.

**Derivación propuesta:**
La posición estimada es r̂ = t + d̂·n̂_d. El error es:
```
Δr = r̂ - r = d̂·n̂_d - d·n_d
```
Expandiendo por regla del producto:
```
Δr ≈ Δd·n_d + d·Δn_d
```
donde Δd = d̂ - d es el error de distancia y Δn_d = n̂_d - n_d es el error de dirección.

**Clave:** Δn_d ⊥ n_d (porque n̂_d y n_d son ambos unitarios en S², Δn_d es tangente). Por tanto los dos términos son **ortogonales** y:
```
||Δr||² ≈ (Δd)² + d²·||Δn_d||²
         = (Δd)² + d²·θ_err²
```
donde θ_err = ||Δn_d|| ≈ arccos(n̂_d·n_d) es el error angular en radianes.

**Verificación numérica con datos del paper (K=5, GLS):**
- d promedio ≈ 1.5 m (centro del testbed a techo z=2m)
- θ_err = 0.66° = 0.0115 rad (Table II, GLS RMSE)
- Contribución dirección: d·θ_err ≈ 1.5 × 0.0115 ≈ 1.73 cm
- RMSE 3D observado: 2.52 cm (Table IV)
- Contribución distancia (por diferencia en cuadratura): √(2.52² - 1.73²) ≈ 1.83 cm
- **Conclusión:** Ambas fuentes contribuyen de manera comparable (~1.7 cm cada una).

**¿Requiere gráfica?** No estrictamente. La fórmula + verificación numérica en 3-4 líneas de texto es suficiente para un paper TCOM. Una gráfica de barras (contribución DF vs DR por estimador) sería un nice-to-have pero no es necesaria. **Recomendación: solo texto (1 párrafo + 1 ecuación) en Section VII-B.**

**Dónde insertarlo:** Después del párrafo que explica las dos fuentes de gap (línea 927 del .tex), agregar:
```latex
\added{Quantitatively, the position error decomposes as
$\lVert\Delta\mathbf{r}\rVert^2 \approx (\Delta d)^2 + d^2\,\theta_{\mathrm{err}}^2$,
where $\Delta d$ is the distance error and $\theta_{\mathrm{err}}$ the angular 
direction error (in radians), since $\Delta\mathbf{n}_d \perp \mathbf{n}_d$ on 
$\mathbb{S}^2$. For GLS at $K{=}5$: $d\,\theta_{\mathrm{err}} \approx 
1.5\times0.0115 \approx 1.7$\,cm (direction contribution) and 
$\Delta d \approx 1.8$\,cm (distance contribution), summing in quadrature 
to $\approx 2.5$\,cm, consistent with the observed RMSE of $2.52$\,cm 
(Table~\ref{tab:estimation_performance}).}
```
- **Esfuerzo:** 30 min. **Impacto:** Medio-alto. Da rigor al error budget.

### B4. Condición de coplanaridad del FIM
- **Comentario:** R3-C9
- **Mejora:** 1-2 frases en Section III-E.
- **Esfuerzo:** 30 min. **Impacto:** Medio.

---

## 🟢 BAJA PRIORIDAD — No recomendado para esta revisión

| ID | Acción | Razón de no hacer |
|---|---|---|
| C1 | Simulación NLOS / multipath | Abre más preguntas; LOS estándar en OWP |
| C2 | Comparación GA vs PSO/DE | Alto esfuerzo; GA funciona bien empíricamente |
| C3 | Baseline adicional (MLP/fingerprinting) | Paradigma diferente; comparación injusta |

---

## 📋 Resumen actualizado

| ID | Acción | Estado | Esfuerzo | Impacto |
|---|---|---|---|---|
| **A1** | Caption Fig. 2: "50 random sets" | ✅ HECHO | — | — |
| **A2** | Caption Fig. 3: "single random set" | ✅ HECHO | — | — |
| **A3** | NLS = fmincon/SQP | ✅ YA OK | — | — |
| **A4** | "and" before silicon-photonics | ✅ YA OK | — | — |
| **B5** | **RMSE estimadores vs SNR (nueva fig.)** | � PENDIENTE | 4-6 h (MC) | **MUY ALTO** |
| **B3** | Error propagation formula (1 párrafo) | 🟡 PENDIENTE | 30 min | Medio-alto |
| **B4** | FIM coplanaridad discusión | 🟡 PENDIENTE | 30 min | Medio |
| **B1** | Tabla ambient light → SNR | 🟡 PENDIENTE | 1-2 h | Alto |
| **B2** | Simulación sync robustness | 🟡 PENDIENTE | 3-5 h | Muy alto |

### Orden de ejecución recomendado:
1. **B5** — RMSE estimadores vs SNR ← responde directamente a R2-C11 y R3-C6 con datos
2. **B3** — Error propagation (30 min, texto) ← fortalece R3-C10
3. **B4** — FIM coplanaridad (30 min, texto) ← fortalece R3-C9
4. **B1** — Tabla ambient light (con datos de B5 si disponibles)
5. **B2** — Sync robustness (si hay tiempo)
