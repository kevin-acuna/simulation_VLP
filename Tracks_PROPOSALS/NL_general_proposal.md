# Propuesta NL-general: Beam-Steered OWP Beyond Lambertian Emission

> **Título tentativo:** *"Beam-Steered Optical Wireless Positioning with Arbitrary Emission Patterns: Bounds, Estimators, and Mismatch Analysis"*

---

## 1. Motivación y Problema

El framework TCOM asume un LED con patrón Lambertiano generalizado: R(φ) = cos^m(φ). En la práctica:
- Los LEDs comerciales tienen patrones que difieren del Lambertiano (batwing, side-emitting, flat-top)
- Liquid lenses deforman el lóbulo de emisión al inclinar
- El mismatch Lambertiano introduce **bias sistemático irreducible** en los estimadores

**Pregunta central:** ¿Cómo se comportan los estimadores beam-steered OWP cuando R(φ) ≠ cos^m(φ)? ¿Qué se rompe y qué se preserva?

---

## 2. Marco Teórico

### 2.1. Modelo generalizado

El modelo de canal se mantiene factorizado:
```
μ_i = η · R(φ_i),   donde φ_i = arccos(n_{t,i} · n_d)
```
Pero R(φ) es ahora una función arbitraria (no necesariamente un monomio).

### 2.2. ¿Qué se rompe?

**GLS/WLS requieren monomio cos^m(φ):**
- GLS lineariza vía: β_i = (μ_i/μ_1)^{1/m} = Q_i/Q_1 → producto escalar lineal
- Con R(φ) genérico: μ_i/μ_1 = R(φ_i)/R(φ_1) → NO hay transformación que linearice
- Resultado: **GLS/WLS son fundamentalmente incompatibles** con R(φ) no-Lambertiano

**NLS se adapta directamente:**
- Sustituir cos^m(φ) por R_spline(φ) en la función de costo
- Sin cambios algorítmicos (Levenberg-Marquardt sobre S²)
- Requiere: R(φ) conocido (calibrado o del datasheet)

### 2.3. FIM y DEB generalizados

La FIM para R(φ) arbitrario:
```
I_B(r) = (N/σ²) Σᵢ [∇_r μ_i][∇_r μ_i]^T
```
donde el gradiente ahora es:
```
∇_r μ_i = (η/d) · [R'(φ_i)/sin(φ_i)] · (n_{t,i} - cos(φ_i)·n_d)/d + ... (términos n_r, n_d)
```
Se evalúa numéricamente con R'(φ) = derivada del spline.

El DEB/PEB generalizados se computan numéricamente — no tienen forma cerrada pero son evaluables para cualquier R(φ) dado.

### 2.4. Estimador GLS(m_eff) como aproximación

Si R(φ) es "quasi-Lambertian" (caso frecuente), se puede ajustar un m_eff:
```
m_eff = argmin_m Σ [log R(φ_k) - m·log(cos φ_k)]²
```
y usar GLS con ese m_eff. Esto introduce un bias que depende del grado de no-Lambertianidad.

### 2.5. Estimador híbrido: GLS(m_eff) + Newton(R_spline)

1. Inicialización: GLS con m_eff → v⁰ (closed-form)
2. Refinamiento: 1–2 pasos de Newton sobre S² con el gradiente del MLE perfilado usando R_spline
3. Complejidad O(K), near-optimal

---

## 3. Simulaciones Propuestas

### 3.1. Definir perfiles R(φ) de test

| Perfil | Modelo | Parámetros | Caso de uso |
|--------|--------|------------|-------------|
| Lambertiano (baseline) | cos^m(φ) | m = 1, 3, 10 | Referencia |
| Gaussiano | exp(-φ²/2σ²) | σ = 10°, 20°, 30° | VCSEL, colimado |
| Batwing | cos^m₁(φ) + a·cos^m₂(φ-φ₀) | Ajuste a datasheet | LED comercial típico |
| Flat-top | Σ aₖ cos^{mₖ}(φ) | Multi-lóbulo | Iluminación uniforme |
| Medido (spline) | Tabla interpolada | Del goniómetro | Validación experimental |

### 3.2. Figuras propuestas

| Fig # | Contenido | Variable X | Curvas | Mensaje |
|-------|-----------|-----------|--------|---------|
| 1 | Perfiles R(φ) comparados | φ [deg] | 4-5 perfiles | Visualizar la diversidad de patrones |
| 2 | DEB generalizado vs K | K | Por perfil R(φ) | El DEB depende fuertemente del perfil |
| 3 | RMSE de GLS con mismatch | Grado de no-Lambertianidad | GLS(m), GLS(m_eff), NLS(R) | GLS degrada, NLS calibrado no |
| 4 | Bias de GLS vs φ de mismatch | φ peak del batwing | Bias angular | El bias es sistemático e irreducible |
| 5 | RMSE estimador híbrido vs NLS completo | K o SNR | Híbrido vs NLS vs DEB | Híbrido ≈ NLS con latencia de GLS |
| 6 | Impacto en distancia broadcast (F) | Grado de mismatch | Error en d̂ | R(φ) incorrecto → bias en d̂ |

---

## 4. Contribuciones

1. Demostración formal de por qué GLS/WLS son incompatibles con R(φ) genérico
2. DEB/PEB generalizados (evaluación numérica) para R(φ) arbitrario
3. Estimador híbrido GLS(m_eff)+Newton near-optimal con complejidad O(K)
4. Cuantificación del mismatch Lambertiano: bias en dirección + bias en distancia (broadcast)
5. Guía de diseño: ¿cuándo basta m_eff? ¿cuándo calibrar R(φ)?

---

## 5. Venue y Timeline

- **Target:** IEEE/OSA J. Lightwave Technology (JLT) o IEEE Trans. Communications
- **Tipo:** Journal (8-12 páginas), teórico + simulación
- **Timeline estimado:** 3-4 meses
- **Prerrequisito:** TCOM publicado (para referenciar GLS/NLS)
- **Companion experimental:** Propuesta C (validación con goniómetro)

---

## 6. Estructura del paper

| Sección | Contenido |
|---------|-----------|
| I | Intro: OWP asume Lambertiano, pero LEDs reales no lo son |
| II | System model generalizado: R(φ) arbitrario, factorización preservada |
| III | Análisis: por qué GLS requiere monomio (demostración formal) |
| IV | FIM y DEB generalizados (evaluación numérica) |
| V | Estimadores: GLS(m_eff), NLS(R_spline), Híbrido |
| VI | Mismatch analysis: bias en dirección y en distancia |
| VII | Simulaciones: 4-5 perfiles, comparativa completa |
| VIII | Conclusión + guías de diseño |
