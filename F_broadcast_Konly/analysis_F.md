# Propuesta F: Broadcast Beam-Steered OWP — Distance Recovery Without Cooperative Alignment

> **Target:** GLOBECOM 2026 Workshop (deadline 12 Ago 2026)  
> **Base:** IEEE TCOM RV2 — single-LED single-PD beam-steered OWP

---

## 1. Idea Central

Eliminar la medición cooperativa (K+1) del pipeline TCOM. En vez de reapuntar LED y PD para medir distancia, extraer `d` directamente de las K mediciones de direction finding, asumiendo que `n_r` es conocido (vía IMU/acelerómetro).

**Trade-off clave:**
- Se pierde: n_r-agnosticidad total (distance recovery requiere conocer n_r)
- Se gana: broadcast (N receptores simultáneamente), sin PD steering, menor latencia

---

## 2. Terminología Formal

A lo largo de este documento y del paper:

| Término | Notación LaTeX | Significado |
|---------|----------------|-------------|
| **Broadcast PEB** | `PEB_B` / `\mathrm{PEB}_{\mathrm{B}}` | CRLB para posición 3D usando **solo K mediciones** (sin medición cooperativa). Requiere n_r conocido. |
| **Cooperative PEB** | `PEB_C` / `\mathrm{PEB}_{\mathrm{C}}` | CRLB para posición 3D usando **K+1 mediciones** (K para DF + 1 beam-aligned). Definido en TCOM. |
| **DEB** | `DEB` / `\mathrm{DEB}` | CRLB para dirección en S² usando solo K mediciones. n_r-independiente. Definido en TCOM. |
| **Broadcast FIM** | `J_B` / `\mathcal{I}_{\mathrm{B}}` | Fisher Information Matrix de las K mediciones para estimación de posición. |
| **Cooperative FIM** | `J_C` / `\mathcal{I}_{\mathrm{C}}` | FIM de las K+1 mediciones (TCOM). |

> **Convención:** En el paper, "PEB" sin calificador se referirá al **broadcast PEB** (PEB_B), que es la contribución principal. El cooperative PEB (PEB_C) del TCOM se usa solo como referencia comparativa.

---

## 3. Modelo Matemático

### 3.1 Modelo de Observación (mismo que TCOM)

Para la orientación i-ésima:
```
μ_i(r) = η · Q_i^m
```
donde:
- `Q_i = n_{t,i} · n_d` — dirección coseno entre orientación i-ésima y dirección TX→RX
- `η = C · cos(ψ) / d²` — escalar positivo común a las K mediciones
- `C = P_t(m+1)A_det / (2π)` — constante óptica calibrada
- `cos(ψ) = -n_r · n_d` — coseno del ángulo de incidencia (depende de n_r)

### 3.2 Direction Finding (igual que TCOM, n_r-independiente)

Las ratios β_i = (μ_i/μ_1)^{1/m} = Q_i/Q_1 cancelan η.
→ GLS/WLS/NLS estiman n̂_d sin conocer n_r (Section VI-C del TCOM).

### 3.3 Broadcast Distance Recovery (NUEVO)

Una vez estimado n̂_d, y conociendo n_r (vía IMU):
```
cos(ψ̂) = -n_r · n̂_d
```

El estimador de η a partir de las K mediciones (MLE bajo ruido gaussiano para η dado n_d):
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

## 4. Broadcast Position Error Bound (PEB_B)

### 4.1 Justificación rigurosa

**Pregunta:** ¿Por qué el PEB_B es simplemente la FIM de las K mediciones sin la K+1?

**Respuesta:** El PEB es el CRLB de la estimación de **r** a partir de un conjunto de observaciones. Depende exclusivamente del modelo estadístico de las observaciones, no del estimador empleado.

Cada potencia medida μ_i(r) = η(r) · Q_i(r)^m depende de **r** a través de **tres vías simultáneas**:

1. **n_d(r)** = (r−t)/‖r−t‖ — la dirección (2 DoF en S²)
2. **d(r)** = ‖r−t‖ — la distancia (1 DoF)
3. **cos ψ(r)** = −n_r · n_d(r) — el ángulo de incidencia

El gradiente ∇_r μ_i captura la sensibilidad a las 3 componentes de **r** simultáneamente. Con K ≥ 3 orientaciones no coplanares, la FIM broadcast es rango 3 → la posición 3D es identificable **sin la medición cooperativa**.

**Observación clave:** Los estimadores GLS/WLS del TCOM **descartan voluntariamente** la información de distancia al tomar ratios β_i = (μ_i/μ_1)^{1/m}, porque su objetivo es estimar solo n_d. Pero la información de distancia **está presente** en las K potencias absolutas. El CRLB asume un estimador que aprovecha TODA la información disponible.

### 4.2 Estructura de la información: broadcast vs cooperativo

| Aspecto | Cooperativo (K+1) | Broadcast (K) |
|---------|-------------------|---------------|
| Información de dirección | K gradientes: componentes tangenciales | Idéntico |
| Información de distancia | K gradientes (componente radial) **+ gradiente K+1 puro radial** | K gradientes solamente (componente radial) |
| Gradiente K+1 | ∇_r μ_{K+1} = −2C n_d/d³ (radial puro) | Ausente |
| Información de distancia concentrada | Sí (medición K+1 beam-aligned, SNR máximo) | No (dispersa en K mediciones, no diseñadas para ranging) |
| Dependencia de n_r en el bound | Solo K mediciones (K+1 asume beam alignment perfecto) | Todas las K mediciones |

La medición K+1 aporta un gradiente **puramente radial** (proporcional a n_d), que es exactamente la dirección donde se necesita más información para estimar d. Por eso PEB_C < PEB_B.

### 4.3 Broadcast FIM

El parámetro es r = [x, y, z]^T. La FIM broadcast:
```
J_B(r) = (N/σ²) Σᵢ₌₁ᴷ [∇_r μ_i(r)] [∇_r μ_i(r)]^T
```

El gradiente (Eq. 22 del TCOM, idéntico):
```
∇_r μ_i = (C/d³) [m·cos^{m-1}(φ_i)·cos(ψ)·n_{t,i} − cos^m(φ_i)·n_r − (m+3)·cos^m(φ_i)·cos(ψ)·n_d]
```

### 4.4 Broadcast PEB
```
PEB_B(r) = sqrt(tr(J_B⁻¹(r)))
```

### 4.5 Relación formal con cooperative PEB

La FIM cooperativa añade la contribución de la medición K+1:
```
J_C(r) = J_B(r) + (N/σ²) · [∇_r μ_{K+1}][∇_r μ_{K+1}]^T
```
donde ∇_r μ_{K+1} = −2C n_d/d³ (asumiendo beam alignment perfecto: cos φ = cos ψ = 1).

Como J_C = J_B + M con M ⪰ 0 (semidefinida positiva), por la desigualdad de Loewner:
```
J_C⁻¹ ⪯ J_B⁻¹    ⟹    tr(J_C⁻¹) ≤ tr(J_B⁻¹)    ⟹    PEB_C ≤ PEB_B
```

La **penalización broadcast** se define como:
```
ρ(r) = PEB_B(r) / PEB_C(r) ≥ 1
```

La pregunta central de este paper: **¿cuál es la distribución espacial de ρ(r)?**

### 4.6 Dependencia de n_r

A diferencia del DEB (n_r-independiente), el PEB_B **depende de n_r** a través del gradiente (el término −cos^m(φ_i)·n_r). Esto es consistente: para resolver la ambigüedad distancia-orientación en η = C·cos(ψ)/d², se requiere conocer cos(ψ) = −n_r · n_d, que necesita n_r.

Para las simulaciones iniciales: **n_r = [0,0,1]^T** (receptor horizontal mirando arriba).

---

## 5. Plan de Figuras y Simulaciones

### Filosofía: dos fases separadas

| Fase | Objetivo | Herramienta | Depende de estimador? |
|------|----------|-------------|----------------------|
| **Fase A: Bounds** | Caracterizar PEB_B como función de los parámetros del sistema | FIM analítica | No (solo geometría + SNR) |
| **Fase B: Estimadores** | Validar que NLS alcanza PEB_B; comparar GLS/WLS | Monte Carlo | Sí |

---

### Fase A — Análisis del Broadcast PEB (figuras de diseño del sistema)

> **Novedad clave vs TCOM:** El DEB es n_r-independiente. El PEB_B **sí depende de n_r**. Esto es la contribución teórica central: cuantificar esa dependencia y sus implicaciones de diseño.

#### Variables del análisis paramétrico

| Variable | Rango | Por qué importa |
|----------|-------|-----------------|
| **n_r** (orientación del receptor) | θ_tilt ∈ [0°, 30°], azimut libre | Cuantifica requisito de precisión del IMU; afecta directamente cos(ψ) en η |
| **K** (orientaciones) | 3–9 | Más K → mejor PEB_B, pero más latencia. ¿Cuántos K compensan perder K+1? |
| **Φ_{1/2}** (half-power angle) | 30°, 45°, 60° | Para DEB, 45° era óptimo. ¿Cambia para PEB_B? (la componente radial del gradiente escala distinto) |
| **SNR** | 10–50 dB | Verificar 1/√SNR y comparar pendiente con PEB_C |
| **Posición (heatmap)** | Grid XY a z fija | Distribución espacial de PEB_B y de ρ |

#### Mapa de figuras — Fase A

| Fig. | Contenido | Eje X | Curvas/Colores | Script | Novedad |
|------|-----------|-------|----------------|--------|---------|
| **A1** | Heatmap PEB_B (z=0.8m, K=5, n_r=[0,0,1]) | x | y | `sim01` | Baseline espacial |
| **A2** | Heatmap penalización ρ = PEB_B/PEB_C | x | y | `sim01` | Muestra dónde broadcast es costoso |
| **A3** | RMS-PEB_B vs K | K | Curva PEB_B + curva PEB_C + ratio ρ̄ | `sim02` | ¿Cuántos K para compensar? |
| **A4** | **RMS-PEB_B vs θ_tilt (orientación del receptor)** | θ_tilt [0°–30°] | Curvas para K=3,5,7,9 | `sim06` | **CLAVE**: sensibilidad a n_r |
| **A5** | **RMS-PEB_B vs K para Φ_{1/2} ∈ {30°, 45°, 60°}** | K | 3 curvas (una por Φ) | `sim07` | ¿El LED óptimo para broadcast difiere del de DF? |
| **A6** | RMS-PEB_B vs SNR | SNR [dB] | PEB_B bold + banda K∈{3,...,9} | `sim03` | Confirma 1/√SNR |

#### Detalle de las figuras clave

**Fig. A4 — PEB_B vs orientación del receptor (LA MÁS IMPORTANTE)**

Esta figura NO existe en el TCOM (porque el DEB es n_r-independiente). Es la contribución diferenciadora de este paper.

- Eje X: θ_tilt ∈ [0°, 30°] (ángulo entre n_r y vertical)
- Eje Y: RMS-PEB_B [cm]
- Curvas: K = 3, 5, 7, 9
- Fijo: Φ_{1/2} = 45°, SNR nominal
- Opción: azimut del tilt promediado (isotrópico) o peor caso

Preguntas que responde:
- ¿Cuánto degrada PEB_B si el usuario inclina el teléfono 15°?
- ¿Un IMU de ±2° es suficiente para broadcast positioning?
- ¿Más K mitiga la sensibilidad al tilt?

**Fig. A5 — PEB_B vs K por Φ_{1/2}**

En TCOM, Φ_{1/2}=45° era óptimo para DEB porque maximiza el gradiente angular m·Q^{m-1}. Pero para PEB_B, la información de distancia viene del término −cos^m(φ)·n_r en el gradiente, que escala diferente:
- Φ=30° (m≈3.5): beam estrecho, alta info angular, ¿pero baja info radial?
- Φ=60° (m=1): beam ancho, baja info angular, ¿más info radial?

La pregunta: ¿el LED óptimo para broadcast es distinto del LED óptimo para direction finding?

---

### Fase B — Estimadores (validación Monte Carlo)

| Fig. | Contenido | Script | Estimadores |
|------|-----------|--------|-------------|
| **B1** | CDF 3D error: GLS vs WLS vs NLS vs PEB_B | `sim05` | Los 3 + bound |
| **B2** | RMSE vs SNR: estimadores vs PEB_B | `sim08` | Los 3 + bound |
| **B3** | RMSE vs θ_tilt: estimadores con IMU imperfecto | `sim09` | NLS + PEB_B (mismatched n_r) |
| **B4** | Tabla de resultados (RMSE, CDF90, APE, latencia) | `sim05` | Tabla, no figura |

#### Detalle de figuras Fase B

**Fig. B1 — CDF (ya hecha con sim05, resultado clave)**

NLS ≈ PEB_B confirma que el two-stage (NLS + broadcast_distance) es near-optimal. Esto valida teóricamente que no se necesita un MLE conjunto de una etapa.

**Fig. B3 — Estimador con IMU imperfecto (la más práctica)**

- Se asume n_r = [0,0,1] para el estimador, pero el verdadero n_r tiene tilt θ_err
- Esto introduce **bias** en d̂ (no solo varianza)
- Mide la degradación real vs la curva teórica (Fig. A4)
- Pregunta: ¿hasta cuántos grados de error en n_r es tolerable?

---

### Resumen: qué figuras van en el paper (6 páginas)

Para un workshop de 6 páginas, selección de ~5 figuras + 1 tabla:

| Prioridad | Figura paper | Contenido | Fuente |
|-----------|-------------|-----------|--------|
| ⭐⭐⭐ | Fig. 1 | **PEB_B vs θ_tilt** (n_r sensitivity) — LA novedad | A4 |
| ⭐⭐⭐ | Fig. 2 | **PEB_B vs K** con PEB_C referencia + ρ | A3 |
| ⭐⭐ | Fig. 3 | **CDF 3D** (NLS ≈ PEB_B, GLS/WLS gap) | B1 |
| ⭐⭐ | Fig. 4 | **Heatmap ρ** (penalización espacial) | A2 |
| ⭐ | Fig. 5 | PEB_B vs Φ_{1/2} o vs SNR | A5 o A6 |
| — | Table I | RMSE, CDF90, APE, latencia (GLS/WLS/NLS/PEB_B) | B4 |

---

## 6. Estructura del Paper (6 páginas, GLOBECOM Workshop)

| Sección | Contenido | Figuras |
|---------|-----------|---------|
| I. Intro | Limitación K+1; motivación broadcast; trade-off n_r | — |
| II. System Model | Modelo TCOM; broadcast distance recovery (η̂, d̂); arquitectura | — |
| III. Broadcast PEB | FIM J_B; PEB_B; relación con PEB_C (Loewner); penalización ρ | Fig. 2, 4 |
| IV. Parametric Analysis | PEB_B vs n_r tilt (requisito IMU); PEB_B vs K; vs Φ_{1/2} | **Fig. 1**, 5 |
| V. Estimator Performance | NLS+broadcast_distance = profiled MLE; CDF; tabla | Fig. 3, Table I |
| VI. Conclusion | Trade-off cuantificado; broadcast viable para θ_tilt < X° | — |

---

## 7. Contribuciones Nuevas vs TCOM

1. **Broadcast PEB (PEB_B)** — CRLB para posición 3D usando solo K mediciones; primer bound para la arquitectura sin medición cooperativa
2. **Estimador de amplitud η̂** — recupera información de distancia contenida en las K potencias absolutas, descartada por los estimadores ratio-based (GLS/WLS)
3. **Broadcast distance recovery** — d̂ = sqrt(C·cos(ψ̂)/η̂) con n_r provisto por IMU
4. **Penalización broadcast ρ** — análisis espacial de PEB_B/PEB_C: coste cuantificable de eliminar la medición K+1
5. **Análisis de sensibilidad a n_r** — impacto de la incertidumbre del IMU (Δθ_tilt) sobre la estimación de distancia
6. **Arquitectura broadcast** — N receptores se localizan simultáneamente con un solo ciclo de K orientaciones, sin mediciones dedicadas ni PD steering

---

## 8. Progreso

| Fecha | Acción | Estado |
|-------|--------|--------|
| 26 May 2026 | Crear estructura, análisis teórico, sim01 | 🔄 En curso |
| | sim02, sim03 | ⬜ Pendiente |
| | sim04, sim05 | ⬜ Pendiente |
| | Redacción | ⬜ Pendiente |
