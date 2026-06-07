# Propuesta VCSEL: Beam-Steered OWP with VCSEL Sources

> **Título tentativo:** *"VCSEL-Based Beam-Steered Optical Wireless Positioning: Gaussian Beam Model, Performance Bounds, and Comparison with Lambertian LED"*

---

## 1. Motivación y Problema

Los VCSELs (Vertical-Cavity Surface-Emitting Lasers) son una alternativa natural al LED para beam-steered OWP porque:
- **Patrón Gaussiano estrecho** (divergencia ~8°–20° vs ~45°–60° de un LED)
- **Alta velocidad de modulación** (>10 GHz vs ~100 MHz LED) — compatible con OWC simultáneo
- **Eye-safe en NIR** (850 nm, 940 nm) con potencias adecuadas
- **Arrays escalables** (VCSEL arrays para multi-beam o WDM)
- **Topical en 6G/OWC**: múltiples papers recientes sobre VCSEL para indoor OWC (IEEE JLT 2024-2025)

**Pregunta central:** ¿Qué cambia en el framework beam-steered OWP cuando la fuente es un VCSEL con patrón Gaussiano en vez de un LED Lambertiano?

---

## 2. Marco Teórico

### 2.1. Modelo de emisión VCSEL

El patrón de radiación de un VCSEL monomodo se modela como Gaussiano:
```
R_VCSEL(φ) = exp(-2φ² / θ_div²)
```
donde θ_div es la divergencia a 1/e² (típicamente 8°–15° half-angle para VCSEL monomodo).

**Comparación con Lambertiano:**
```
R_LED(φ) = cos^m(φ)     → ancho, m depende de Φ_{1/2}
R_VCSEL(φ) = exp(-2φ²/θ²)  → estrecho, concentrado
```

Para VCSELs multimodo: superposición de Gaussianas (M² > 1):
```
R_VCSEL_MM(φ) = exp(-2φ² / (M²·θ₀²))
```

### 2.2. Implicaciones para beam-steered OWP

**Ventajas del VCSEL:**
- Mayor SNR en la dirección de pointing (beam más concentrado → más potencia por unidad de ángulo sólido)
- Mejor discriminación angular entre orientaciones (gradientes más pronunciados)
- Potencialmente menor número de orientaciones K necesarias

**Desventajas:**
- Cobertura espacial reducida (el beam puede no iluminar posiciones periféricas)
- Mayor sensibilidad a desalineación (beam lock más crítico)
- Menos mediciones con Q_i > 0 por posición (el beam estrecho no llega a todas las orientaciones)

### 2.3. Análisis teórico específico

**GLS con VCSEL:**
- R_VCSEL(φ) = exp(-2φ²/θ²) NO es un monomio → GLS no lineariza exactamente
- PERO: para θ pequeño y φ < θ, se puede aproximar como cos^{m_eff}(φ) con m_eff ≫ 1
- El m_eff equivalente: m_eff ≈ 2/(θ_div² · ln(1/cos(1rad))) — típicamente m_eff > 20

**NLS con VCSEL:**
- Directo: sustituir cos^m por exp(-2φ²/θ²) en el cost function
- Sin cambios algorítmicos
- El parámetro θ_div se calibra una vez (datasheet o medición)

**FIM y PEB para VCSEL:**
- Gradiente: ∇_r μ_i ahora involucra R'_VCSEL(φ) = -(4φ/θ²)·exp(-2φ²/θ²)
- El gradiente es más agudo → FIM con eigenvalues más grandes en la dirección angular
- Pero: fuera del cono θ_div, la señal es ~0 → menos orientaciones contribuyen por posición

### 2.4. Diseño de orientaciones para VCSEL

El beam estrecho cambia fundamentalmente la optimización de orientaciones:
- Con LED (Φ_{1/2}=45°): K=5–9 orientaciones cubren el espacio 3D
- Con VCSEL (θ_div=10°): se necesitan más orientaciones pero cada una aporta más SNR
- Trade-off: **K_VCSEL > K_LED** pero cada medición es de mayor calidad

La optimización GA del TCOM se aplica directamente con R_VCSEL en el DEB numérico.

---

## 3. Simulaciones Propuestas

### 3.1. Parámetros del sistema

| Parámetro | LED (baseline TCOM) | VCSEL monomodo | VCSEL multimodo |
|-----------|--------------------:|:-:|:-:|
| R(φ) | cos^m(φ), m=3 (Φ_{1/2}=45°) | exp(-2φ²/θ²), θ=10° | exp(-2φ²/(M²θ²)), M²=3, θ=10° |
| Potencia | 0.405 W | 5 mW (eye-safe) | 20 mW (array) |
| Divergencia 1/e² | ~45° | ~10° | ~17° |
| Modulación BW | ~100 MHz | >5 GHz | >1 GHz |

Nota: la potencia del VCSEL es menor pero la concentración angular compensa (SNR comparable a distancias cortas).

### 3.2. Figuras propuestas

| Fig # | Contenido | Mensaje clave |
|-------|-----------|---------------|
| 1 | Comparación R(φ): LED vs VCSEL (monomodo y multimodo) | Visualizar la diferencia de patrón |
| 2 | Heatmap PEB: LED vs VCSEL al mismo K | VCSEL: mejor centro, peor periferia |
| 3 | PEB vs K: LED vs VCSEL | VCSEL necesita más K pero converge a mejor PEB |
| 4 | PEB vs θ_div (divergencia VCSEL) | Trade-off divergencia/cobertura |
| 5 | Cobertura: % posiciones con PEB finito vs K | VCSEL tiene "agujeros" de cobertura con K bajo |
| 6 | DEB vs SNR: LED vs VCSEL | VCSEL mejor a SNR equivalente gracias a gradientes agudos |
| 7 | Orientaciones óptimas: LED vs VCSEL (visualización esférica) | Las orientaciones VCSEL son más densas y distribuidas |
| 8 | RMSE estimadores: GLS(m_eff) vs NLS(Gaussian) | NLS es necesario; GLS(m_eff) tiene gap |

---

## 4. Contribuciones

1. **Modelo de canal VCSEL para beam-steered OWP** (Gaussian beam, parámetros realistas)
2. **DEB y PEB para fuente Gaussiana** — comparación analítica/numérica con Lambertiano
3. **Diseño de orientaciones optimizadas** para VCSEL (GA con DEB Gaussiano)
4. **Análisis de cobertura** — mínimo K para PEB finito con beam estrecho
5. **Comparativa LED vs VCSEL** en términos de PEB, cobertura, latencia, y SNR
6. **Compatibilidad con OWC** — argumento de dual-use (positioning + communication)

---

## 5. Viabilidad Teórica

**¿Admite solución?** Sí, completamente:
- El modelo μ_i = η·R_VCSEL(φ_i) preserva la factorización → toda la maquinaria FIM/NLS aplica
- R_VCSEL(φ) es diferenciable → gradientes bien definidos → FIM computable
- La optimización GA funciona directamente con R_VCSEL en la evaluación de DEB
- No hay barrera teórica — es un cambio de función R(φ), no de framework

**¿Qué es nuevo vs NL-general?**
- NL-general trata R(φ) como tabla/spline genérica → framework abstracto
- VCSEL usa un modelo paramétrico concreto → permite insights analíticos:
  - m_eff(θ_div) en forma cerrada
  - Condición de visibilidad simplificada: φ_i < c·θ_div
  - Scaling laws: PEB ∝ θ_div^α (derivable)
  - Comparación fair con LED a misma potencia radiada

---

## 6. Venue y Timeline

- **Target:** IEEE Photonics Technology Letters (4p) o conference (GLOBECOM WS, 6p)
- **Tipo:** Simulación, potencialmente con datos de datasheet VCSEL reales
- **Timeline estimado:** 2-3 meses (framework TCOM ya existe, solo cambiar R(φ))
- **Prerrequisito:** TCOM publicado; NL-general NO es prerequisito (son independientes)
- **Ventaja:** Muy topical (VCSEL para 6G OWC es tema caliente 2024-2026)

---

## 7. Estructura del paper (conference 6p)

| Sección | Contenido |
|---------|-----------|
| I | Intro: VCSEL para OWC/OWP en 6G, ventajas vs LED, gap en positioning |
| II | System model: VCSEL Gaussiano + beam-steered architecture |
| III | FIM y PEB para VCSEL (numérico + insights analíticos) |
| IV | Diseño de orientaciones (GA con DEB Gaussiano) |
| V | Simulaciones: LED vs VCSEL, cobertura, estimadores |
| VI | Conclusión |

---

## 8. Diferencias clave con NL-general

| Aspecto | NL-general | VCSEL |
|---------|-----------|-------|
| R(φ) | Arbitrario (spline, tabla) | Gaussiano paramétrico |
| Enfoque | Framework matemático general | Análisis de sistema específico |
| GLS | Demostrar que falla formalmente | Calcular m_eff y cuantificar gap |
| Contribución | Bounds + estimador híbrido | Diseño de sistema + comparativa |
| Motivación | LEDs comerciales no-ideales | 6G/OWC, eye-safety, multi-Gbps |
| Audiencia | Signal processing, estimation theory | OWC, photonics, 6G systems |
| Experimental | Requiere goniómetro | Basta datasheet VCSEL |
