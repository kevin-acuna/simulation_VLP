# Comparativa: Opción A vs. Opción C2 — Decisión Arquitectónica

## Definición precisa de cada opción

### Opción A: "Distance Recovery reformulado SIN rotación del Rx"
- **Direction Finding** (Etapa 1): GLS/WLS, n_r-agnostic (sin cambios)
- **Distance Recovery** (Etapa 2): LED → n̂_d, Rx queda fijo (n_r conocido, no se rota)
- Fórmula: `d̂ = sqrt(C · |n_r · n̂_d| / P̄_{r,K+1})`
- Se **elimina** "beam-forming symmetry" y la frase `n_r = −n̂_d`
- Se mantiene el claim **"without receiver rotation"**

### Opción C2: "Distance Recovery beamformed CON rotación del Rx, presentado transparentemente"
- **Direction Finding** (Etapa 1): GLS/WLS, n_r-agnostic (sin cambios)
- **Distance Recovery** (Etapa 2): LED → n̂_d y Rx → −n̂_d (beamformed, como está actualmente)
- Fórmula original: `d̂ = sqrt(C / P̄_{r,K+1})` (cos ϕ = cos ψ = 1)
- Se **mantiene** la rotación del Rx, pero se **declara explícitamente** como una asunción
- El paper se **recentra** en Direction Finding como contribución principal
- Distance Recovery se presenta como **un paso adicional para 3D**, no como contribución principal
- Se **abandona** el claim "without receiver rotation" (o se califica: "DF without Rx rotation; DR with single Rx reorientation")

### Lo que ambas opciones comparten (no cambia)
- Prueba matemática de que β_i es independiente de n_r → GLS/WLS n_r-agnostic
- Nueva subsección: CDF de error angular (direction finding)
- Nuevo experimento: robustez del DF ante tilts aleatorios del PD
- Reestructuración de la Introducción (Comments #1, #2)
- Simplificación de Sec. III-A/B (Comment #4b)
- Clarificaciones (Comments #4a, 4c, 4d, 6, 7, 8)
- Performance vs SNR (Comment #11)
- Corrección de Table IV (Comment #12)
- Discusión del gap NL–CRLB (Comment #13)
- Correcciones gramaticales (Comment #14)

---

## Comparativa detallada

### 1. Respuesta a Comment #3 (Distance Recovery confuso, "beam-forming symmetry")

| Aspecto | Opción A | Opción C2 |
|---|---|---|
| ¿Se elimina "beam-forming symmetry"? | ✅ Sí, completamente | ✅ Sí, se renombra/clarifica |
| ¿Cómo se resuelve la contradicción? | Reformular: el Rx no se rota. cos(ψ) se calcula de n_r conocido | Transparencia: "DR requires a single Rx reorientation to maximize SNR" |
| Respuesta al reviewer | "We have reformulated distance recovery to operate with a fixed PD. The LED is beam-steered to n̂_d while n_r remains unchanged." | "We have clarified that while direction finding is independent of n_r, the distance-recovery step benefits from aligning the Rx toward the estimated direction to maximize the received signal." |
| Riesgo | ✅ Bajo: la contradicción desaparece | ⚠️ Medio: el reviewer puede insistir en que la rotación del Rx sigue siendo un problema |

### 2. Respuesta a Comment #5 (Table I "Arbitrary" vs n_r fijo)

| Aspecto | Opción A | Opción C2 |
|---|---|---|
| Table I para "Ours" | "Arbitrary (DF) / Known (3D)" + nota al pie | "Arbitrary (DF) / Controlled (3D)" + nota al pie |
| ¿n_r necesario? | Conocido (para distancia), pero NO se rota | Controlable (se rota a −n̂_d para distancia) |
| Coherencia con modelo | ✅ Sección II-A dice n_r = [0,0,1]. Se usa tal cual, sin moverlo | ⚠️ Sección II-A dice n_r fijo, pero Sec II-B2 lo rota → debe aclararse que es un paso extra |
| 6-DoF? | No: n_r conocido = 3-DoF. El reviewer queda satisfecho | No: para DF, n_r no importa. Para DR, n_r se controla = 3-DoF |

### 3. Impacto en el Abstract

| Opción A | Opción C2 |
|---|---|
| "...achieves 3D localization **without receiver rotation**..." ✅ Se mantiene verdadero | "...introduces closed-form direction estimators that are **provably independent of receiver orientation**, and achieves 3D localization via an additional beam-aligned measurement..." |
| Más fuerte comercialmente | Más preciso técnicamente |

### 4. Impacto en la Sección II-B2 (Distance Recovery)

**Opción A — Reescritura:**
```
After direction finding, the LED is steered to n̂_d.
The receiver remains at its fixed orientation n_r.
cos(ϕ) ≈ 1 (LED apunta al Rx)
cos(ψ) = n_r · (−n̂_d) = −n̂_{d,z} (para n_r = [0,0,1])

P_{r,K+1} = C · cos(ψ) / d²

d̂ = sqrt(C · |n_r · n̂_d| / P̄_{r,K+1})
```

**Opción C2 — Clarificación:**
```
After direction finding, the LED is steered to n̂_d
AND the receiver is reoriented to n_r = −n̂_d (single reorientation).
cos(ϕ) = 1, cos(ψ) = 1

P_{r,K+1} = C / d²

d̂ = sqrt(C / P̄_{r,K+1})
```

### 5. Impacto en el CRLB / PEB (Sección III)

| Aspecto | Opción A | Opción C2 |
|---|---|---|
| Gradiente de μ_{K+1} | **Debe rederivarse.** `∇_r μ_{K+1}` incluye cos(ψ) y su derivada, que depende de r. Es más complejo que `−2C/d³ · n_d` | **Sin cambios.** `∇_r μ_{K+1} = −2C/d³ · n_d` permanece |
| PEB numérico | Ligeramente **mayor** (peor) porque cos(ψ) < 1 reduce el SNR de la medición K+1 | **Idéntico** al paper actual (PEB óptimo con beamformed) |
| Tablas de resultados | **Deben recalcularse** (todos los PEB de Table III y Table IV cambian) | **Se mantienen** |
| Código a modificar | `PEB_complete.m` (líneas 93-97): nuevo gradiente. `vlp_peb_beam` en `main_3D_withNoise.m` | Ningún cambio al PEB |

**Detalle de la rederivación (Opción A):**

Con n_t = n̂_d (verdadero), n_r = [0,0,1]:
```
μ_{K+1}(r) = C · cos(ψ) / d² = C · (H − z) / d³
donde d = ||r − t||
```

El gradiente es:
```
∇_r μ_{K+1} = C · ∇_r [(H − z) / d³]
            = C · [−(H−z)·3d / d⁶ · (r−t) + [0,0,−1]/d³]
```
Esto es más complejo y acopla componente z de manera no trivial. No es catastrófico pero requiere verificación cuidadosa.

### 6. Impacto en las simulaciones existentes

| Archivo | Opción A | Opción C2 |
|---|---|---|
| `vlp_gls.m` | Sin cambios | Sin cambios |
| `vlp_wls.m` | Sin cambios | Sin cambios |
| `PEB_complete.m` | **Modificar** gradient μ_{K+1} | Sin cambios |
| `main_3D_withNoise.m` (DR lines 283-343) | **Modificar**: quitar `param_r_axis = {A_det, -v_tr_est, FOV}` y usar n_r fijo | Sin cambios |
| `Experiment_SNR_CRLB.m` | **Modificar** `vlp_peb_beam` | Sin cambios |
| `FigComparisonMethods.m` | **Regenerar** con nuevos datos | Sin cambios (puede añadir nuevas curvas) |
| Table IV en paper | **Recalcular** todos los valores | **Mantener** valores existentes |
| Algorithm 1 | **Modificar** línea 17: quitar `n_r ← −n̂_d` | **Mantener**, aclarar en texto |
| **NUEVO**: CDF angular DF | Crear | Crear |
| **NUEVO**: Robustez a tilt | Crear | Crear |
| **NUEVO**: RMSE vs SNR estimadores | Crear | Crear |

### 7. Impacto en la precisión del sistema

| Métrica | Opción A | Opción C2 |
|---|---|---|
| Precisión Direction Finding | Idéntica | Idéntica |
| SNR de la medición K+1 | **Menor**: cos(ψ) < 1 reduce potencia recibida | **Máximo**: cos(ψ) = 1, máxima potencia |
| Precisión de distancia | Ligeramente peor (menor SNR → mayor varianza de d̂) | Óptima |
| Precisión 3D (RMSE total) | Ligeramente mayor que la actual | Idéntica a la actual |
| PEB teórico | Ligeramente mayor | Idéntico (mejor bound posible) |

**Estimación cuantitativa del impacto en Opción A:**
Para un receptor a 1m de distancia y 30° off-nadir: cos(ψ) ≈ cos(30°) = 0.87. El SNR de la medición K+1 se reduce ~13%. El PEB de la componente de distancia empeora ~7%. Para posiciones cercanas al nadir (bajo el LED): cos(ψ) ≈ 1, impacto mínimo. Para posiciones en los bordes: mayor degradación.

### 8. Impacto en la narrativa del paper

| Aspecto | Opción A | Opción C2 |
|---|---|---|
| **Título** | Sin cambios necesarios | Podría ajustarse para enfatizar "direction finding" |
| **Claim principal** | "3D OWP without Rx rotation" | "Closed-form direction estimation independent of Rx orientation, with beam-steered 3D extension" |
| **Fortaleza narrativa** | ★★★★★ — Claim limpio, simple, potente | ★★★★☆ — Honesto, técnicamente preciso, ligeramente más débil como "selling point" |
| **Contribución nueva (n_r-agnostic)** | Presente, pero embebida en el sistema completo | **Destacada** como contribución central |
| **Position del Distance Recovery** | Parte integral del sistema | Extensión natural, paso adicional |

### 9. Respuesta al Comment #10 (latencia por mediciones secuenciales)

| Opción A | Opción C2 |
|---|---|
| K+1 mediciones totales (K para DF + 1 para DR sin rotación) | K+1 mediciones totales + tiempo de rotación del Rx |
| Latencia total: `(K+1) × t_sample` | Latencia total: `K × t_sample + t_rotation_Rx + t_sample` |
| Argumento: "sin overhead mecánico del Rx" | Debe justificar el overhead de rotación |

### 10. Riesgo ante el reviewer

| Factor de riesgo | Opción A | Opción C2 |
|---|---|---|
| "Aún contradicen el abstract" | ❌ No aplica | ⚠️ Posible si no se reescribe bien |
| "La reformulación es peor que la original" | ⚠️ Posible si la precisión baja mucho | ❌ No aplica |
| "No justifican la rotación del Rx" | ❌ No aplica | ⚠️ Posible, pero se mitiga con el recentramiento en DF |
| "El CRLB cambió, ¿por qué?" | ⚠️ Debe explicarse que cos(ψ) < 1 es el costo de no rotar el Rx | ❌ No aplica |
| "Resultados inconsistentes con v1" | ⚠️ Tablas cambian | ❌ Tablas se mantienen |

---

## Cuadro resumen

| Criterio                        | Opción A                 | Opción C2                |
|----------------------------------|:------------------------:|:------------------------:|
| "Without Rx rotation" se mantiene | ✅ Sí                   | ❌ No (se califica)       |
| Claim de 3D localization         | ✅ Completo              | ✅ Completo               |
| Coherencia con el modelo         | ✅ Total                 | ✅ Con clarificación      |
| n_r-agnostic como contribución   | ✅ Embebida              | ✅ Central                |
| PEB/CRLB del paper               | ⚠️ Rederivación + recálculo | ✅ Sin cambios           |
| Resultados existentes válidos    | ⚠️ Parcialmente          | ✅ Totalmente             |
| Esfuerzo de simulación           | ★★★★☆ Alto              | ★★☆☆☆ Bajo               |
| Esfuerzo de reescritura          | ★★★☆☆ Medio             | ★★★☆☆ Medio              |
| Esfuerzo total                   | ★★★★☆                   | ★★★☆☆                    |
| Riesgo ante reviewer             | ★☆☆☆☆ Bajo              | ★★☆☆☆ Bajo-Medio         |
| Fortaleza del "selling point"    | ★★★★★                   | ★★★★☆                    |
| Precisión 3D final               | ★★★★☆ (leve degradación)| ★★★★★ (óptima)           |
| Elegancia técnica                | ★★★★★                   | ★★★★☆                    |

---

## Análisis cruzado con cada comentario del Reviewer 2

| # | Comentario | Opción A | Opción C2 | ¿Cuál responde mejor? |
|---|---|---|---|---|
| 1 | Intro sin flujo lógico | Igual en ambas | Igual en ambas | **Empate** |
| 2 | Concepto no explicado antes de contribuciones | Igual en ambas | Igual en ambas | **Empate** |
| 3 | Distance Recovery confuso, "beam-forming symmetry" | Elimina la contradicción de raíz | La aclara pero no la elimina | **A** |
| 4a | μ_i(r) dependencia en r | Igual en ambas | Igual en ambas | **Empate** |
| 4b | Secs III-A, III-B innecesarias | Igual en ambas | Igual en ambas | **Empate** |
| 4c | u_x, u_y, u_z no definidos | Igual en ambas | Igual en ambas | **Empate** |
| 4d | GLS/WLS no explicados | Igual en ambas (se expande) | Igual en ambas (se expande) | **Empate** |
| 5 | Table I "Arbitrary" vs modelo | "Arbitrary (DF) / Known (3D)" → coherente | "Arbitrary (DF) / Controlled (3D)" → coherente | **A** (más limpio) |
| 6 | Tilt-azimuth no en modelo | Igual en ambas | Igual en ambas | **Empate** |
| 7 | 2K unknowns vs K measurements | Igual en ambas | Igual en ambas | **Empate** |
| 8 | r fijo en optimización | Igual en ambas | Igual en ambas | **Empate** |
| 9 | Fig. 9 redundante | Igual en ambas | Igual en ambas | **Empate** |
| 10 | Latencia secuencial | Mejor: sin overhead de Rx | Peor: debe justificar rotación Rx | **A** |
| 11 | Falta comparación + SNR | Igual en ambas (nueva simulación) | Igual en ambas (nueva simulación) | **Empate** |
| 12 | CRLB con métricas estadísticas | Igual en ambas (corrección) | Igual en ambas (corrección) | **Empate** |
| 13 | Gap NL–CRLB | Igual en ambas (explicación) | Igual en ambas (explicación) | **Empate** |
| 14 | Gramática | Igual en ambas | Igual en ambas | **Empate** |

**Score: Opción A gana en 3 comentarios (#3, #5, #10). C2 no gana en ninguno. Empate en 11.**

---

## Recomendación final

### Si se prioriza **fortaleza del argumento + bajo riesgo ante el reviewer**: → **Opción A**
- Elimina la contradicción de raíz
- El claim "without Rx rotation" se sostiene
- Table I es coherente
- El precio es la rederivación del CRLB y el recálculo de tablas

### Si se prioriza **mínimo esfuerzo + conservar resultados existentes**: → **Opción C2**
- Todo el trabajo de simulación existente se conserva
- El PEB es óptimo (beamformed)
- El precio es un claim ligeramente más débil y mayor riesgo ante el reviewer

### Mi recomendación: **Opción A**, por tres razones:

1. **El reviewer #2 fue explícito** en señalar la contradicción "without Rx rotation" vs. `n_r = −n̂_d`. Opción C2 la aclara pero no la elimina — un reviewer exigente podría volver a objetar.

2. **La leve degradación en precisión de Opción A es el trade-off honesto** y científicamente interesante: el paper puede discutirlo como "the price of not requiring receiver control." Esto es contenido adicional, no una debilidad.

3. **La rederivación del CRLB no es masiva.** El gradiente de μ_{K+1} cambia de `−2C/d³ · n_d` a una expresión que incluye cos(ψ) y su derivada respecto a r, pero el código ya tiene toda la infraestructura para calcularlo. El esfuerzo incremental es moderado.

### Opción A también permite un argumento poderoso:
> "Our system requires NO hardware control on the receiver side. The PD is a simple, fixed, upward-facing photodiode. All complexity resides in the beam-steering transmitter. This is a key practical advantage for deployment on mobile devices, robots, or wearables."

---

## Estructura propuesta del paper (válida para ambas opciones, con variantes marcadas)

```
I.   INTRODUCTION
     - Reestructurada (Comments #1, #2)
     - Párrafo de concepto antes de contribuciones
     - Lista de contribuciones actualizada: incluir n_r-independence como contribución

II.  SYSTEM MODEL AND LOCALIZATION METHOD
     A. System Model (aclarar n_r y su rol)
     B. Localization Procedure
        1) Direction Finding (K orientaciones, n_r-agnostic)
        2) Distance Recovery
           [A]: n_r fijo, cos(ψ) calculado desde n̂_d
           [C2]: n_r = −n̂_d, beamformed (declarado explícitamente)

III. POSITION ERROR BOUND
     A. FIM (directa, citar Kay — Comment #4b)
     B. Gradient Expressions
        1) Direction-Finding (sin cambios)
        2) Distance-Recovery
           [A]: nuevo gradiente con cos(ψ) ≠ 1
           [C2]: sin cambios
     C. PEB Definition
     D. Number of LED Orientations

IV.  ORIENTATION SET OPTIMIZATION (Comments #6, #7, #8)

V.   NONLINEAR ESTIMATOR (aclarar: requiere n_r conocido)

VI.  LINEAR ESTIMATORS
     A. Receiver-Orientation Independence of Power Ratios (NUEVA — prueba)
     B. Direction Estimation via GLS (expandir — Comment #4d)
     C. WLS as Practical Simplification (expandir — Comment #4d)

VII. SIMULATION RESULTS
     A. Direction-Finding Performance (NUEVA)
        - CDF de error angular
        - Robustez a tilts aleatorios del PD
     B. 3D Positioning Performance
        - CDF de error 3D (GLS, WLS, NL, CRLB)
        - Table IV corregida (Comment #12)
           [A]: valores recalculados
           [C2]: valores mantenidos + corrección nomenclatura
     C. Performance vs SNR (NUEVA — Comment #11)
     D. Computational Complexity

VIII. DISCUSSION
     - Comment #10: latencia y movimiento del usuario
     - Comment #13: gap NL–CRLB explicado
     - [A]: discutir trade-off de no rotar el Rx
     - [C2]: discutir cuándo conviene beamformed vs fixed n_r

IX.  CONCLUSION
```
