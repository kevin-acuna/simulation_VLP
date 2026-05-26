# Propuesta F: Broadcast Beam-Steered OWP — K-only Distance Recovery

> **Target:** GLOBECOM 2026 Workshop (deadline 12 Ago 2026)  
> **Base:** IEEE TCOM RV2 — single-LED single-PD beam-steered OWP

---

## 1. Idea Central

Eliminar la medición cooperativa (K+1) del pipeline TCOM. En vez de reapuntar LED y PD para medir distancia, extraer `d` directamente de las K mediciones de direction finding, asumiendo que `n_r` es conocido (vía IMU/acelerómetro).

**Trade-off clave:**
- Se pierde: n_r-agnosticidad total (distance recovery requiere conocer n_r)
- Se gana: broadcast (N receptores simultáneamente), sin PD steering, menor latencia

---

## 2. Modelo Matemático

### 2.1 Modelo de Observación (mismo que TCOM)

Para la orientación i-ésima:
```
μ_i(r) = η · Q_i^m
```
donde:
- `Q_i = n_{t,i} · n_d` (dirección coseno)
- `η = C · cos(ψ) / d²` (escalar común, nuisance para DF)
- `C = P_t(m+1)A_det / (2π)` (constante óptica)
- `cos(ψ) = -n_r · n_d` (ángulo de incidencia, depende de n_r)

### 2.2 Direction Finding (igual que TCOM, n_r-independiente)

Las ratios β_i = (μ_i/μ_1)^{1/m} = Q_i/Q_1 cancelan η.
→ GLS/WLS/NLS estiman n̂_d sin conocer n_r (Proposición del TCOM, Section VI-C).

### 2.3 Distance Recovery K-only (NUEVO en F)

Una vez estimado n̂_d, y conociendo n_r (vía IMU):
```
cos(ψ̂) = -n_r · n̂_d
```

El estimador de η a partir de las K mediciones (MLE bajo ruido gaussiano):
```
η̂ = Σᵢ μ̂_i · Q̂_i^m / Σᵢ Q̂_i^{2m}
```
donde Q̂_i = n_{t,i} · n̂_d (usa la dirección estimada).

Finalmente, la distancia:
```
d̂ = sqrt(C · cos(ψ̂) / η̂)
```

Y la posición 3D:
```
r̂ = t + d̂ · n̂_d
```

---

## 3. PEB K-only (Bound Teórico)

### 3.1 FIM para K-only

El parámetro a estimar es r = [x, y, z]^T. Con K mediciones:
```
J_Konly(r) = (N/σ²) Σᵢ₌₁ᴷ [∇_r μ_i(r)] [∇_r μ_i(r)]^T
```

El gradiente (idéntico a Eq. 22 del TCOM):
```
∇_r μ_i = (C/d³) [m·cos^{m-1}(φ_i)·cos(ψ)·n_{t,i} - cos^m(φ_i)·n_r - (m+3)·cos^m(φ_i)·cos(ψ)·n_d]
```

**Diferencia con TCOM:** No se añade el gradiente de la medición K+1:
```
∇_r μ_{K+1} = -2C·n_d/d³    ← ELIMINADO en F
```

### 3.2 PEB K-only
```
PEB_Konly(r) = sqrt(tr(J_Konly^{-1}(r)))
```

### 3.3 Relación con PEB TCOM
```
J_TCOM = J_Konly + (N/σ²) · [∇_r μ_{K+1}][∇_r μ_{K+1}]^T
```
Como J_TCOM = J_Konly + PSD matrix, entonces:
```
PEB_Konly ≥ PEB_TCOM    (siempre)
```

La pregunta clave: **¿cuánto peor es PEB_Konly vs PEB_TCOM?**

### 3.4 Dependencia de n_r

A diferencia del DEB (que es n_r-independiente), el PEB_Konly **depende de n_r** a través del gradiente (el término `-cos^m(φ_i)·n_r`). Esto es consistente: para recuperar distancia necesitamos la potencia absoluta, que depende de cos(ψ) = f(n_r, n_d).

Para las simulaciones iniciales: **n_r = [0,0,1]^T** (receptor horizontal mirando arriba).

---

## 4. Plan de Simulaciones

### 4.1 Simulación 1: PEB_Konly heatmap (INMEDIATO)

**Script:** `sim01_PEB_Konly_heatmap.m`

- Calcular PEB_Konly en grid XY a z = 0.8 m
- Comparar con PEB_TCOM (con K+1)
- Orientaciones: DEB-optimizadas del TCOM (K=5)
- Parámetros: Table II del TCOM
- **Figuras:**
  - Fig. 1a: Heatmap PEB_Konly
  - Fig. 1b: Heatmap PEB_TCOM (referencia)
  - Fig. 1c: Ratio PEB_Konly / PEB_TCOM (cuánto peor)

### 4.2 Simulación 2: PEB_Konly vs K

**Script:** `sim02_PEB_vs_K.m`

- RMS-PEB_Konly vs K ∈ {3,...,9}
- Comparar con RMS-PEB_TCOM para cada K
- **Figuras:**
  - Fig. 2: RMS-PEB_Konly y RMS-PEB_TCOM vs K (dos curvas)

### 4.3 Simulación 3: PEB_Konly vs SNR

**Script:** `sim03_PEB_vs_SNR.m`

- PEB_Konly vs SNR ∈ [10, 50] dB
- Verificar que escala como 1/√SNR
- **Figuras:**
  - Fig. 3: PEB_Konly y PEB_TCOM vs SNR

### 4.4 Simulación 4: Sensibilidad a error en n_r

**Script:** `sim04_sensitivity_nr.m`

- n_r con tilt θ_tilt ∈ [0°, 10°] (error del IMU)
- Calcular bias en d̂ causado por error en cos(ψ̂)
- **Figuras:**
  - Fig. 4: Error relativo Δd/d vs θ_tilt

### 4.5 Simulación 5: Monte Carlo del estimador K-only

**Script:** `sim05_MC_Konly.m`

- Implementar η̂ estimator + d̂ = sqrt(C·cos(ψ̂)/η̂)
- 1000 MC trials × 1792 posiciones
- Comparar RMSE contra PEB_Konly
- **Figuras:**
  - Fig. 5: CDF del error 3D (K-only vs TCOM cooperativo)
  - Fig. 6: Scatter 3D de posiciones estimadas

### 4.6 Simulación 6: Comparativa de latencia

- K-only: K mediciones total
- TCOM: K+1 mediciones + 1 reorientación del PD
- **Tabla:** Latencia comparativa

---

## 5. Estructura del Paper (6 páginas, GLOBECOM Workshop)

| Sección | Contenido | Figuras |
|---------|-----------|---------|
| I. Intro | Limitación K+1 cooperativo; motivación broadcast; contribución | — |
| II. System Model | Recap TCOM + K-only distance recovery (η̂, d̂) | — |
| III. K-only PEB | FIM sin K+1; PEB_Konly; relación con PEB_TCOM | Fig. 1, 2 |
| IV. Sensitivity Analysis | Error n_r del IMU → Δd/d; SNR scaling | Fig. 3, 4 |
| V. Simulation Results | MC comparativa; RMSE vs PEB; CDF | Fig. 5 |
| VI. Conclusion | Trade-off; K-only viable para ≤5% PEB penalty | — |

---

## 6. Contribuciones Nuevas vs TCOM

1. **Estimador η̂ de K mediciones** — recupera información de distancia descartada por GLS/WLS
2. **PEB K-only** — nuevo bound para la arquitectura broadcast (sin K+1)
3. **Fórmula de distancia K-only** — d̂ = sqrt(C·cos(ψ̂)/η̂)
4. **Análisis de sensibilidad** — impacto del error de n_r (IMU) sobre d̂
5. **Arquitectura broadcast** — N receptores simultáneamente sin mediciones dedicadas
6. **Comparación cuantitativa** — PEB_Konly vs PEB_TCOM: cost of eliminating K+1

---

## 7. Progreso

| Fecha | Acción | Estado |
|-------|--------|--------|
| 26 May 2026 | Crear estructura, análisis teórico, sim01 | 🔄 En curso |
| | sim02, sim03 | ⬜ Pendiente |
| | sim04, sim05 | ⬜ Pendiente |
| | Redacción | ⬜ Pendiente |
