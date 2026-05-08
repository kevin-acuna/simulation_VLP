# Decisión Arquitectónica del Paper — IEEE TCOM Revisión

## 1. El Problema Central

Los comentarios #3 y #5 del Reviewer 2 revelan una **inconsistencia fundamental** en el paper:

| Elemento del paper    | Dice actualmente                  | Realidad del modelo                                       |
| -----------------------| -----------------------------------| -----------------------------------------------------------|
| Abstract              | "without receiver rotation"       | Distance Recovery requiere `n_r = −n̂_d` (rotación del Rx) |
| Table I (Ours)        | Rx Orientation: "Arbitrary"       | Sección II-A asume `n_r = [0,0,1]^T` fijo                 |
| NL estimator (Sec. V) | Usa `L(x,y,z) = αx + βy + γ(z−H)` | **Requiere conocer n_r**                                  |
| GLS/WLS (Sec. VI)     | Usa β_i = (μ_i/μ_1)^{1/m}         | **cos(ψ) se cancela → n_r no aparece**                    |

### La propiedad matemática clave (descubrimiento central)

En la ratio de potencias:

```
β_i = (μ_i / μ_1)^{1/m}

donde μ_i = C · cos^m(ϕ_i) · cos(ψ) / d²
```

El factor `cos(ψ) = n_r · (−d)/d` es **idéntico para todas las orientaciones i** (el Rx no se mueve entre mediciones). Por tanto:

```
β_i = (cos^m(ϕ_i) · cos(ψ)) / (cos^m(ϕ_1) · cos(ψ)))^{1/m} = cos(ϕ_i) / cos(ϕ_1)
```

**β_i es completamente independiente de n_r.**

Esto implica:
- `a_i = n_{t,i} − β_i · n_{t,1}` no depende de n_r
- La matriz M_GLS y M_WLS no dependen de n_r
- **La estimación de dirección n̂_d por GLS/WLS funciona con CUALQUIER orientación del receptor**

Esto NO aplica al estimador NL, que usa explícitamente `(α,β,γ) = n_r` en su función de costo.

---

## 2. Las Opciones de Arquitectura

### OPCIÓN A: "Direction Finding n_r-agnostic + Distance Recovery sin rotación del Rx"

**Concepto:** Mantener 3D localization. Recentrar el paper en direction finding como contribución principal. Reformular distance recovery SIN rotar el Rx.

**Direction Finding (Etapa 1):**
- GLS/WLS con n_r arbitrario (desconocido) → contribución principal
- NL con n_r conocido → comparativa
- Demostrar matemáticamente la cancelación de n_r en las ratios
- Nueva subsección con CDF de error angular + robustez a tilt del PD

**Distance Recovery (Etapa 2, reformulada):**
- LED se orienta a n̂_d (beam-steer del Tx solamente)
- n_r permanece fijo (NO se rota el Rx)
- cos(ψ) se calcula como `n_r · (−n̂_d)` usando n_r conocido y n̂_d estimado
- Fórmula de distancia:
  ```
  d̂ = sqrt(C · |n_r · n̂_d| / P̄_{r,K+1})
  ```
- Si n_r = [0,0,1]^T: `d̂ = sqrt(C · (−n̂_{d,z}) / P̄_{r,K+1})`

**Elimina** la frase "beam-forming symmetry" y la rotación del Rx.

**Table I:** "Arbitrary" para direction finding + nota: "distance recovery requires known n_r"

**Cambios en el paper:**

| Sección | Cambio |
|---|---|
| Abstract | Reescribir: enfatizar direction finding n_r-agnostic. "without receiver rotation" se mantiene (verdad). Mencionar que distance recovery usa n_r conocido |
| Intro (Sec. I) | Reestructurar. Añadir párrafo sobre el concepto antes de contribuciones |
| Sec. II-B2 | Reformular distance recovery sin rotación Rx |
| Sec. III (PEB) | Actualizar gradiente de μ_{K+1} para cos(ψ) ≠ 1 |
| Sec. V (NL) | Aclarar que requiere n_r conocido |
| Sec. VI (GLS/WLS) | Añadir subsección probando la independencia de n_r |
| Sec. VII (Results) | Añadir CDF dirección, robustez a tilt, comparación vs SNR |
| Table I | Cambiar "Arbitrary" → "Arbitrary (DF) / Known (3D)" o nota al pie |

**Ventajas:**
- ✅ Mantiene 3D localization → alto impacto
- ✅ "without receiver rotation" sigue siendo verdad
- ✅ Resuelve completamente Comments #3 y #5
- ✅ La independencia de n_r en GLS/WLS se convierte en contribución nueva
- ✅ El paper gana una propiedad diferenciadora fuerte (robustez a tilt)
- ✅ Coherente con [Chassagne2025] que también usa ratios y dice "Arbitrary"

**Desventajas:**
- ⚠️ Requiere rederivación del CRLB para la medición K+1 (gradiente cambia)
- ⚠️ La precisión en distance recovery puede ser ligeramente menor (cos(ψ) < 1 reduce SNR)
- ⚠️ Esfuerzo medio-alto: reescritura de varias secciones + nuevas simulaciones

**Esfuerzo estimado: ★★★☆☆ (medio-alto)**

---

### OPCIÓN B: "Direction Finding n_r-agnostic + Distance Recovery desde las K mediciones (sin paso extra)"

**Concepto:** Eliminar completamente la medición K+1. Estimar distancia d directamente desde las K mediciones de direction finding, usando n_r conocido.

**Direction Finding (Etapa 1):** Idéntica a Opción A.

**Distance Recovery (Etapa 2, desde K mediciones existentes):**
- Una vez conocido n̂_d, calcular para cada orientación i:
  ```
  cos(ϕ_i) = n_{t,i} · n̂_d   (conocido)
  cos(ψ) = n_r · (−n̂_d)       (conocido si n_r conocido)
  d̂_i = sqrt(C · cos^m(ϕ_i) · cos(ψ) / μ̂_i)
  ```
- Combinar las K estimaciones de d vía weighted average:
  ```
  d̂ = Σ w_i · d̂_i / Σ w_i
  ```
- **NO se necesita una medición adicional K+1**

**Cambios adicionales vs Opción A:**

| Sección | Cambio adicional |
|---|---|
| Sec. II-B | Reformular: distance recovery desde K mediciones, sin paso extra |
| Sec. III (PEB) | PEB basado solo en K mediciones (sin contribución K+1) |
| Algorithm 1 | Simplificar: eliminar paso de "beam-steering para distancia" |
| Sec. VII | Evaluar precisión de la estimación de distancia desde K mediciones |

**Ventajas:**
- ✅ Todo lo de Opción A, más:
- ✅ Arquitectura más simple y elegante (K mediciones, un solo paso)
- ✅ Menor latencia (no hay paso K+1)
- ✅ Resuelve parcialmente Comment #10 (latencia reducida)
- ✅ El PEB es más simple (solo K contribuciones)

**Desventajas:**
- ⚠️ Precisión de distancia potencialmente menor (cos(ϕ_i) < 1 para la mayoría de orientaciones → menor SNR)
- ⚠️ Requiere n_r conocido para estimar distancia
- ⚠️ Pierde la ventaja de la medición alineada (máximo SNR para distancia)
- ⚠️ La rederivación del PEB cambia significativamente (sin contribución K+1)
- ⚠️ Podría debilitar los resultados de precisión 3D

**Esfuerzo estimado: ★★★★☆ (alto)**

---

### OPCIÓN C: "Direction Finding principal + Distance Recovery como extensión (dos variantes)"

**Concepto:** El paper se centra en direction finding. Distance recovery se presenta como una sección corta mostrando dos variantes posibles, sin entrar en detalle profundo.

**Estructura del paper:**
1. Direction Finding: contribución principal, análisis completo, CDF, robustez
2. Distance Recovery: sección breve presentando:
   - **Variante C1:** Con n_r conocido, sin rotación Rx (como Opción A)
   - **Variante C2:** Con rotación Rx (beamformed, como paper original)
   - Tabla comparativa de pros/cons de cada variante
3. Resultados: énfasis en direction finding + resultados 3D para la variante elegida

**Ventajas:**
- ✅ Máxima flexibilidad: cubre todos los escenarios
- ✅ El reviewer ve que se ha reflexionado sobre el tema
- ✅ Mantiene 3D localization

**Desventajas:**
- ⚠️ Puede parecer disperso (dos variantes sin comprometerse con una)
- ⚠️ Más texto total
- ⚠️ El reviewer podría preguntar "¿cuál recomiendan?"

**Esfuerzo estimado: ★★★☆☆ (medio)**

---

### OPCIÓN D: "Direction Finding + Distance Recovery con rotación explícita del Rx (honesto)"

**Concepto:** Mantener la arquitectura actual pero ser transparente. Admitir que distance recovery requiere control del Rx. Reescribir el Abstract y Table I para reflejarlo.

**Cambios:**
- Abstract: "...achieves direction finding without receiver rotation; full 3D localization further requires a single receiver reorientation for distance recovery"
- Table I: "Fixed (DF) / Controlled (3D)"
- Sección II-B2: mantener como está pero aclarar la necesidad de rotación

**Ventajas:**
- ✅ Mínimo esfuerzo de reescritura
- ✅ Honesto y claro
- ✅ No requiere rederivación del CRLB

**Desventajas:**
- ❌ Debilita el claim principal ("without receiver rotation" se pierde parcialmente)
- ❌ Menos atractivo que las otras opciones
- ❌ No explota la propiedad de independencia de n_r

**Esfuerzo estimado: ★★☆☆☆ (bajo)**

---

### OPCIÓN E: "Direction Finding Only (sin 3D)"

**Concepto:** Eliminar distance recovery. El paper es puramente sobre beam-steered direction estimation.

**Ventajas:**
- ✅ Elimina todas las contradicciones
- ✅ Paper limpio y enfocado
- ✅ Mínimas rederivaciones

**Desventajas:**
- ❌ Pierde el claim de "3D localization" → impacto reducido significativamente
- ❌ No aprovecha el trabajo de simulación ya hecho
- ❌ El título y scope cambian drásticamente

**Esfuerzo estimado: ★★★☆☆ (medio, por reestructuración completa)**

---

## 3. Análisis Comparativo

| Criterio | Opción A | Opción B | Opción C | Opción D | Opción E |
|---|:---:|:---:|:---:|:---:|:---:|
| Mantiene 3D claim | ✅ | ✅ | ✅ | ✅ parcial | ❌ |
| "Without Rx rotation" | ✅ | ✅ | ✅ parcial | ❌ | ✅ |
| Resuelve Comment #3 | ✅ | ✅ | ✅ | ✅ | ✅ |
| Resuelve Comment #5 | ✅ | ✅ | ✅ | ✅ | ✅ |
| Explota propiedad n_r-agnostic | ✅ | ✅ | ✅ | ❌ | ✅ |
| Impacto/novelty | ★★★★★ | ★★★★☆ | ★★★★☆ | ★★☆☆☆ | ★★★☆☆ |
| Precisión 3D | ★★★★☆ | ★★★☆☆ | ★★★★☆ | ★★★★★ | N/A |
| Esfuerzo de revisión | ★★★☆☆ | ★★★★☆ | ★★★☆☆ | ★★☆☆☆ | ★★★☆☆ |
| Coherencia global | ★★★★★ | ★★★★☆ | ★★★★☆ | ★★★☆☆ | ★★★★★ |
| Robustez del argumento | ★★★★★ | ★★★★☆ | ★★★☆☆ | ★★★☆☆ | ★★★★★ |

---

## 4. Recomendación: OPCIÓN A

### ¿Por qué Opción A?

1. **Maximiza el impacto** sin sacrificar el 3D claim.
2. **La propiedad n_r-agnostic de GLS/WLS se convierte en una nueva contribución** que responde directamente a los comentarios del reviewer y fortalece el paper.
3. **"Without receiver rotation" sigue siendo verdad**, ya que el distance recovery reformulado no necesita rotar el Rx.
4. **Es coherente**: la arquitectura queda limpia y sin contradicciones.
5. **El esfuerzo es razonable**: la mayor parte del trabajo es reescritura/clarificación, no nuevas derivaciones masivas.

### Contribuciones del paper revisado (con Opción A)

1. **Novel beam-steered single-LED single-PD direction finding** that is provably independent of receiver orientation → works with arbitrary, unknown n_r.
2. **CRLB/PEB analysis** with closed-form FIM expressions and GA-optimized orientation sets.
3. **Closed-form GLS/WLS direction estimators** that exploit the n_r-cancellation property.
4. **3D localization via distance recovery** without receiver rotation, requiring only known (not controlled) n_r.
5. **Robustness analysis** demonstrating centimeter-level direction accuracy under arbitrary PD tilts.

### Estructura del paper revisado (propuesta)

```
I.   INTRODUCTION (reescrita, Comment #1, #2)
     - Problema, estado del arte, gap, concepto clave, contribuciones

II.  SYSTEM MODEL AND PROPOSED LOCALIZATION METHOD (revisada, Comment #3, #5)
     A. System Model (mantener, aclarar n_r)
     B. General Localization Procedure
        1) Direction Finding (K orientaciones)
        2) Distance Recovery (reformulada: sin rotación Rx)

III. POSITION ERROR BOUND (simplificada, Comment #4b)
     A. Fisher Information Matrix (directa, citando Kay)
     B. Gradient Expressions
        1) Direction-Finding Measurements
        2) Distance-Recovery Measurement (actualizada para cos(ψ)≠1)
     C. Formal Definition of the PEB
     D. Number of LED Orientations

IV.  ORIENTATION SET OPTIMIZATION (clarificada, Comments #6, #7, #8)
     - Mapeo explícito θ,φ → n_t
     - Aclarar: offline design ≠ online estimation
     - Aclarar: r no es fijo, se evalúa sobre todo el testbed

V.   NONLINEAR ESTIMATOR (aclarar: requiere n_r conocido)

VI.  LINEAR ESTIMATORS (expandida, Comments #4d, #5)
     A. n_r-Independence of Power Ratios (NUEVA subsección: prueba)
     B. Direction Estimation via GLS
     C. WLS as Practical Simplification
     D. Distance Recovery from Beam-Steered Measurement (reformulada)

VII. SIMULATION RESULTS (expandida, Comments #9, #11, #12, #13)
     A. Direction Finding Performance (NUEVA)
        1) CDF of Angular Error (NUEVA)
        2) Robustness to Receiver Tilt (NUEVA)
     B. 3D Positioning Performance
     C. Performance vs SNR (NUEVA, Comment #11)
     D. Comparison with Existing Methods (NUEVA o expandida, Comment #11)
     E. Computational Complexity

VIII. PRACTICAL CONSIDERATIONS (NUEVA, Comment #10)
     - Latencia, velocidad de beam-steering, efecto de movimiento

IX.  CONCLUSION
```

### Simulaciones nuevas necesarias

1. **CDF de error angular** (direction finding): `||n̂_d − n_d||` o ángulo entre ellos, para GLS/WLS/NL y K=5,9
2. **Robustez a tilt del PD**: Barrer n_r con tilts aleatorios (0°–30° o más), medir degradación de direction finding GLS/WLS vs NL
3. **RMSE vs SNR** para GLS, WLS, NL y CRLB (Comment #11)
4. **Distance recovery reformulada**: Simular d̂ con cos(ψ) ≠ 1 y medir impacto
5. **PEB actualizado**: Rederivación menor del gradiente para μ_{K+1}

### Detalle de la reformulación de Distance Recovery

**Actual (paper original):**
```
n_t = n̂_d,   n_r = −n̂_d   (Rx rotado)
cos(ϕ) = 1,  cos(ψ) = 1
P_{r,K+1} = C / d²
d̂ = sqrt(C / P̄_{r,K+1})
```

**Propuesta (Opción A):**
```
n_t = n̂_d,   n_r = [0,0,1]^T   (Rx fijo, sin rotación)
cos(ϕ) ≈ 1   (LED apunta al Rx)
cos(ψ) = n_r · (−n̂_d) = −n̂_{d,z}   (calculable desde n̂_d)
P_{r,K+1} = C · cos(ψ) / d²
d̂ = sqrt(C · |n̂_{d,z}| / P̄_{r,K+1})
```

**Para n_r genérico conocido:**
```
cos(ψ) = n_r · (−n̂_d)
d̂ = sqrt(C · |n_r · n̂_d| / P̄_{r,K+1})
```

**Impacto en CRLB:**
- El gradiente de μ_{K+1} cambia de `−(2C/d³)·n_d` a una expresión que incluye cos(ψ) y su derivada respecto a r
- Esto afecta la contribución de la medición K+1 al FIM
- El PEB resultante será ligeramente mayor (peor) porque cos(ψ) < 1 en general, reduciendo el SNR de la medición de distancia
- Pero este costo es menor y honesto

### Impacto en las simulaciones existentes

| Archivo | Impacto |
|---|---|
| `PEB_complete.m` | Modificar gradiente de μ_{K+1} (líneas 93-97) |
| `main_3D_withNoise.m` | Modificar distance recovery (líneas 283-296, 310-321, 330-343) para usar cos(ψ) conocido en vez de rotación |
| `vlp_gls.m` | Sin cambios (ya es n_r-agnostic) |
| `vlp_wls.m` | Sin cambios |
| `Experiment_SNR_CRLB.m` | Adaptar vlp_peb_beam para nueva formulación |
| `FigComparisonMethods.m` | Re-ejecutar con nuevos datos |
| **NUEVO** | Script de CDF angular |
| **NUEVO** | Script de robustez a tilt |
| **NUEVO** | Script de RMSE vs SNR para estimadores |

---

## 5. Próximos pasos (si se elige Opción A)

1. **Confirmar la elección** de Opción A
2. **Derivar el gradiente actualizado** de μ_{K+1} para cos(ψ) ≠ 1
3. **Modificar `PEB_complete.m`** y verificar resultados numéricos
4. **Modificar `main_3D_withNoise.m`** para distance recovery sin rotación
5. **Crear scripts** para CDF angular y robustez a tilt
6. **Crear script** RMSE vs SNR
7. **Reescribir secciones** del paper según la nueva estructura
8. **Generar nuevas figuras** y actualizar las existentes
