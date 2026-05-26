# Propuestas de Extensión del Paper TCOM para Conference Papers

> **Paper base:** *"Model-Based Beam-Steered Optical Wireless Positioning with Single-LED Single-Photodiode for 3D Localization"* — IEEE TCOM (en revisión)

---

## 1. Resumen del Paper TCOM (versión RV2 — Mayo 2026)

El paper presenta una arquitectura OWP con un solo LED beam-steered y un solo PD para localización 3D indoor. Contribuciones principales (5 items en Section I):

- **Arquitectura single-LED single-PD** con beam steering en K orientaciones, n_r-independiente
- **DEB y PEB** (Direction/Position Error Bound) derivados analíticamente vía Schur complement de la FIM (Slepian-Bangs + perfil de η)
- **Optimización GA** del conjunto de orientaciones para minimizar RMS-DEB sobre 1,792 posiciones 3D (Table III: K=3→9, RMS-DEB 1.30°→0.36°)
- **Estimadores closed-form GLS/WLS**: ratio-based linearization → eigenvector de 3×3 matrix, latencia μs (GLS: 0.025 ms, WLS: 0.018 ms)
- **NLS iterativo**: Levenberg-Marquardt en reparametrización esférica, near-efficient (≈1.00× DEB), latencia 0.65 ms
- **n_r-independencia** (Section VI-C): prueba formal para los tres estimadores; validación MC con tilts aleatorios (<3% degradación)
- **Resultados (K=5, abstract APE)**: direction finding sub-grado (GLS: 0.54°, WLS: 0.61°, NLS: 0.52°); 3D positioning cm-level (GLS: 2.00 cm, WLS: 2.25 cm, NLS: 1.90 cm); PEB: 1.64 cm RMSE
- **Resultados K=9**: GLS 1.46 cm APE, NLS 1.26 cm APE → approaching PEB (1.10 cm)
- **Baseline comparison**: vs. [Chassagne2025] K=3 SVD → 4.4× mejora (GLS K=5: 2.52 cm vs 11.05 cm RMSE)
- **SNR analysis (Fig. 5 + Fig. 9)**: bounds + estimators siguen 1/√SNR; NLS tracks DEB ≈1.00×, GLS ≈1.3×, WLS ≈1.6× (gaps constantes, estructurales)
- **Future work declarado** (Section VIII): (i) experimental validation, (ii) integration with beam-steered OWC links + intelligent refresh strategy, (iii) optical ISAC
- **Limitación arquitectónica identificada**: la medición cooperativa K+1 requiere PD steering (una reorientación tras DF) y no escala a N receptores
- **Puntos clave de los reviewers** (que informan extensiones):
  - R3-C4: multipath/NLOS no abordado — extensión natural
  - R3-C3: sincronización TX↔RX no analizada en detalle
  - R3-C7: comparación con otros metaheurísticos (PSO, DE, SA) queda como trabajo futuro
  - R2-C13: NLS NO es MLE (es NLS sobre targets normalizados); GLS es MLE del modelo linealizado de ratios

---

## 2. Congresos Objetivo y Deadlines

> **Actualizado:** 26 Mayo 2026. Deadlines verificados en los sitios oficiales.

### 2.1 ⚡ URGENTE — Deadlines en los próximos días

| Congreso | Lugar | Fechas evento | **Deadline** | Tipo | Papers candidatos |
|----------|-------|---------------|--------------|------|-------------------|
| **ISWCS 2026** | Gold Coast, Australia | 24–26 Ago 2026 | **🚨 31 May 2026** | Conference (5p) | F, G, H, I |
| **PIMRC 2026 Workshop** | Singapore | Sep–Oct 2026 | **⚠️ 5 Jun 2026** | Workshop (5–6p) | F, H, I, G |

> ISWCS: **Deadline en 5 días (31 Mayo).** Probablemente demasiado tarde salvo que haya trabajo ya avanzado. PIMRC Workshop en 10 días.

---

### 2.2 Deadlines 2026 Q3 (Ago–Sep 2026)

| Congreso | Lugar | Fechas evento | **Deadline** | Tipo | Papers candidatos |
|----------|-------|---------------|--------------|------|-------------------|
| **GLOBECOM 2026 Workshop** | Macau, China | 7–11 Dic 2026 | **12 Ago 2026** | Workshop (6p) | F, D, H, G, A |
| **IEEE ISAC 2026** ⭐ | Lisboa, Portugal | 16–18 Nov 2026 | **11 Sep 2026** | Conference (6p) | A, L, G, F |

> **ISAC 2026** es el primer congreso dedicado exclusivamente a Integrated Sensing and Communications (IEEE ComSoc + SPS + Aerospace). Debut histórico — máxima visibilidad para paper A (ISAC óptico) o L (RL adaptativo). Deadline extendido desde el 1 Jun original.
>
> **GLOBECOM 2026 Workshops relevantes:** WS-01 "7th Workshop on Emerging Topics in 6G Communications"; buscar también workshops de OWC, ISAC, o 6G Sensing al publicarse la lista completa.

---

### 2.3 Deadlines 2026 Q4 (Oct–Nov 2026)

| Congreso | Lugar | Fechas evento | **Deadline** | Tipo | Papers candidatos |
|----------|-------|---------------|--------------|------|-------------------|
| **ICC 2027** | Washington DC, EE.UU. | 30 May–3 Jun 2027 | **26 Oct 2026** | Symposium (6p) | A, F, G, H, I |
| **WCNC 2027** | Panama City, Panama | Mar–Abr 2027 | **31 Oct 2026** | Symposium (6p) | A, F, G, I, D |
| **ICASSP 2027** | Toronto, Canada | 16–21 May 2027 | **~Sep–Oct 2026** *(TBC)* | Conference (5p) | L, E, N |

> ICC 2027 tracks relevantes: *Optical Wireless Communications (SAC)*, *Signal Processing for Communications*, *Localization & Positioning*.
>
> WCNC 2027 tracks: *Wireless Localization & Sensing*, *Optical Wireless*, *AI/ML for Wireless*.
>
> ICASSP 2027 (IEEE Signal Processing Society): venue principal para L (RL), E (GLS+NN), N (ML universal). Deadline aún no publicado oficialmente; históricamente entre Sep–Oct del año anterior.

---

### 2.4 Journals (rolling — sin deadline fijo)

| Journal | IF | Review típico | Papers candidatos |
|---------|----|---------------|-------------------|
| **IEEE Trans. Communications (TCOM)** | ~7.2 | 3–6 meses | A, K, J, N |
| **IEEE/OSA J. Lightwave Technology (JLT)** | ~4.7 | 3–4 meses | C, A, K |
| **IEEE Photonics Journal** | ~2.4 | 2–3 meses | C (opc.) |
| **IEEE Trans. Signal Processing (TSP)** | ~5.4 | 3–5 meses | J, L |
| **IEEE Signal Processing Letters** | ~3.9 | 2–3 meses (4p) | E, L (carta) |
| **IEEE Wireless Communications Letters** | ~4.6 | 2–3 meses (4p) | F, G (carta) |
| **IEEE JSAC** | ~13.0 | 4–6 meses | M (Cambridge) |
| **IEEE IoT Journal** | ~10.0 | 3–5 meses | N |

---

### 2.5 Deadlines ya cerrados (referencia)

| Congreso | Lugar | Fechas evento | Deadline | Estado |
|----------|-------|---------------|----------|--------|
| CSNDSP 2026 | Edinburgh, UK | 15–17 Jul 2026 | 31 Ene 2026 | ❌ Cerrado |
| SPAWC 2026 | Atenas, Grecia | 6–9 Sep 2026 | 22 Mar 2026 | ❌ Cerrado |
| VTC 2026-Fall | Boston, EE.UU. | 6–9 Sep 2026 | 21 Mar 2026 | ❌ Cerrado |
| PIMRC 2026 Symposium | Singapore | Sep–Oct 2026 | 16 Abr 2026 (firm) | ❌ Cerrado |
| ECOC 2026 | Málaga, España | 20–24 Sep 2026 | 22 Abr 2026 (extendido) | ❌ Cerrado |
| ISWCS 2026 | Gold Coast, AU | 24–26 Ago 2026 | 31 May 2026 | ⚠️ 5 días (prob. cerrado efectivo) |
| GLOBECOM 2026 Symposium (ONS/SPC) | Macau | 7–11 Dic 2026 | 15 Mar 2026 | ❌ Cerrado |

---

### 2.6 Vista de conjunto: papel → venue recomendado

| Paper | Venue principal | Deadline | Alternativa |
|-------|-----------------|----------|-------------|
| **F** (broadcast K-only, sim) | **GLOBECOM 2026 WS** | 12 Ago 2026 | ISAC 2026 (11 Sep) |
| **V** ⭐ (TCOM+F exp.+NL calib.) | **TCOM / JLT** | rolling | IEEE Photonics J |
| **H** (beam tracking) | GLOBECOM 2026 WS | 12 Ago 2026 | WCNC 2027 |
| **I** (two-stage adaptive) | GLOBECOM 2026 WS | 12 Ago 2026 | WCNC 2027 |
| **G** (ML observability) | ISAC 2026 | 11 Sep 2026 | WCNC 2027 |
| **A** (ISAC óptico, exp.) | **ISAC 2026** ⭐ | 11 Sep 2026 | ICC/WCNC 2027 |
| **L** (RL adaptativo) | **ICASSP 2027** | ~Sep–Oct 2026 | ISAC 2026 |
| **E** (GLS+NN) | IEEE SP Letters | rolling | ICASSP 2027 |
| **D** (multi-receptor) | GLOBECOM 2026 WS | 12 Ago 2026 | WCNC 2027 |
| **N** (ML universal) | ICASSP 2027 | ~Sep–Oct 2026 | IEEE IoT-J |
| **C** (non-Lamb. exp.) | **JLT** | rolling | IEEE Photonics J |
| **J** (framework teórico) | TSP o TCOM | rolling | — |
| **K** (multi-LED exp.) | TCOM o JLT | rolling | — |
| **M** (TL Cambridge) | **JSAC** | rolling | NeurIPS WS |

---

## 3. Propuestas de Extensión

### 3.0 Resumen Comparativo de Todas las Propuestas

> **Nota estratégica:** El usuario dispone de testbed completo + múltiples gimbals + LiFi dongle. Esta ventaja convierte los papers experimentales en **la contribución de mayor impacto y diferenciación**. Los papers puramente teóricos (J, I, G) sirven como fundamento y companion, pero el foco de ejecución debe ser experimental. Un grupo sin hardware no puede competir en ese espacio.

#### Tabla principal

| ID | Título tentativo | Venue | Contenido | Complejidad | Tiempo est. |
|----|-----------------|-------|-----------|-------------|-------------|
| **F** | *"Broadcast Beam-Steered OWP: IMU-Assisted Distance Recovery Without Cooperative Alignment"* | Conference (Workshop) | Simulación | ★★☆ | 2–3 meses |
| **V** ⚡⭐ | *"Experimental Beam-Steered OWP with Broadcast Distance Recovery and Quasi-Lambertian Calibration"* | **Journal (TCOM / JLT)** | **Experimental** (testbed + R(φ) calibrado) | ★★☆ | 3–4 meses |
| **A** ⚡ | *"Experimental ISAC with Gimbal-Steered LiFi: Simultaneous Indoor Positioning and High-Speed OWC"* | **Journal (TCOM / JLT)** | **Experimental** (LiFi dongle + gimbal) | ★★★ | 4–6 meses |
| **K** ⚡ | *"Multi-LED Beam-Steered OWP: Diversity Gain and Joint Orientation Design with Mechanical Gimbals"* | **Journal (TCOM / JLT)** | **Experimental** (múltiples gimbals) | ★★★ | 5–7 meses |
| **J** | *"Generalized Beam-Steered OWP Beyond Lambertian Emission: Bounds, Hybrid Estimator, and Reference Normalization"* | Journal (TSP / TCOM) | Simulación | ★★★ | 4–5 meses |
| **C** ⚡ | *"Experimental Validation of Non-Lambertian Beam-Steered OWP with Real Emission Pattern Calibration"* | Journal (JLT) | **Experimental** (goniómetro + testbed) | ★★★★ | 6–8 meses |
| **H** ⚡ | *"Real-Time Beam Tracking for Beam-Steered OWP via Gimbal Servo Control"* | Journal o Conf. Symp. | **Experimental** (servo + móvil) | ★★★ | 5–7 meses |
| **I** | *"Adaptive Two-Stage Orientation Design for Precision Beam-Steered OWP"* | Conference (Symposium) | Simulación (+ opcional exp.) | ★★☆ | 2–3 meses |
| **G** | *"Fundamental Observability Limits for ML-Based Single-PD Optical Wireless Positioning"* | Conference (Workshop) | Simulación | ★★☆ | 2–3 meses |
| **D** | *"Broadcast Beam-Steered OWP for Multi-User Concurrent Localization"* | Conference (Workshop) | Simulación | ★☆☆ | 1–2 meses |
| **L** 🤖 | *"Deep RL for Adaptive Beam Orientation Selection in Single-LED OWP"* | **ICASSP / IEEE SP Letters** | Simulación (Python) | ★★☆ | 2–3 meses |
| **N** 🤖 | *"Pattern-Conditioned Universal ML Model for Cross-LED Beam-Steered OWP"* | **Journal (TCOM / IoT-J)** | Simulación (+ opc. exp.) | ★★★ | 3 meses (N₁) |
| **M** 🤖⚡ | *"Physics-Informed Transfer Learning for Generalizable Beam-Steered OWP"* | **Journal (JSAC / TCOM)** | Sim + Exp (Cambridge) | ★★★ | Durante pasantía |
| **E** | *"Physics-Informed Neural Correction for GLS Direction Finding in Beam-Steered OWP"* | **IEEE SP Letters** | Simulación | ★★☆ | 2–3 meses |

*⚡ = aprovecha directamente el hardware disponible (testbed + gimbals + LiFi dongle)*
*🤖 = trabajo ML/RL puro, portfolio GitHub, visible a industria AI*
*⭐ = prioridad inmediata (pipeline directo F → V)*

#### Dependencias entre propuestas

| ID | Prerequisito académico | Prerequisito práctico (hardware) | Puede hacerse solo |
|----|------------------------|----------------------------------|--------------------||
| **F** | Solo TCOM | — | ✅ Sí, prioritario |
| **V** ⚡⭐ | **TCOM + F + GLOBECOM** (extensión journal) | Testbed 3D (disponible) | ✅ Sí — **siguiente tras F** |
| **A** ⚡ | Solo TCOM | LiFi dongle + gimbal (disponible) | ✅ Sí — empezar en paralelo con F |
| **K** ⚡ | TCOM + F (arquitectura K-only multi-LED) | Múltiples gimbals (disponible) | ⚠️ Tras F |
| **L** 🤖 | Solo TCOM + Python/RL skills | — | ✅ Sí — empezar cuando se quiera |
| **J** | Solo TCOM | — | ✅ Sí. Puede correr en paralelo con C |
| **C** ⚡ | TCOM + J (companion teórico recomendado) | Testbed + goniómetro (disponible) | ✅ Sí — C y J en paralelo |
| **H** ⚡ | TCOM + beneficia de J | Gimbal con servo control (disponible) | ✅ Sí (con Lambertiano basta) |
| **I** | TCOM + beneficia de J | — (o validar exp. con testbed) | ✅ Sí |
| **G** | Solo TCOM | — | ✅ Sí, o como sección de F |
| **D** | **F** (necesita broadcast) | — | ⚠️ Tras F |
| **N** 🤖 | Solo TCOM + simulador Python (compartido con L); banco de datasheets | — (opc. 2–3 LEDs) | ✅ Sí — paper standalone, simulación |
| **M** 🤖⚡ | **L** (simulador Python como dominio origen); E independiente, no requerido | Pasantía Cambridge (3 meses) | ⚠️ Necesita L primero + pasantía |
| **E** | Solo TCOM | — | ✅ Sí (más esfuerzo) |

#### Orden de ejecución recomendado (actualizado 26 Mayo 2026)

```
⭐ PIPELINE PRIORITARIO (lo más directo — hacer PRIMERO):
  1. F (simulación)     [K-only distance recovery → GLOBECOM WS, deadline 12 Ago]
  2. V (experimental)   [TCOM+F validado + R(φ) calibrado → Journal (TCOM/JLT)]
     └→ F y V comparten framework; V extiende GLOBECOM a journal
     └→ Testbed ya disponible; R(φ) se mide con el mismo setup
  3. H (experimental)   [Beam tracking con Pseudo-Quad TX → Journal o ICC/WCNC 2027]
     └→ Reutiliza mismo testbed + gimbal de V
     └→ Extiende DF (V) a tracking dinámico: acquisition → tracking mode

PARALELO (iniciar cuando pipeline F→V esté encaminado):
  L 🤖              [RL adaptativo: Python puro, ICASSP 2027, alta visibilidad ML]
  A ⚡              [LiFi dongle + gimbal → ISAC experimental, alto impacto]

MEDIO PLAZO:
  J               [teoría NL general: companion teórico profundo de V]
  K ⚡            [múltiples gimbals → multi-LED experimental, muy novedoso]
  I               [dos etapas: puede validarse con testbed]
  G               [observabilidad ML: complemento de F, bajo esfuerzo]

CAMBRIDGE (durante pasantía):
  M 🤖⚡         [TL + prior físico + co-authorship Haas → JSAC]

OPCIONAL / LARGO PLAZO:
  D, E, N
```

**Mapa de dependencias visual (revisado):**

```
               TCOM + GLOBECOM (enviado)
                 |          \
                 F           A ⚡
                 |
                 V ⚡⭐
                 |
                 H ⚡        [tracking = extensión natural de V]
                /|\
               / | \
              D  K  (informa J, C como journals más profundos)
                 |
              J + C ⚡ (companion teórico + experimental avanzado)

  Independientes: L 🤖, G, I, E, N
  Cambridge: M (requiere L)
```

#### Impacto vs. esfuerzo (con hardware disponible)

| Zona | Propuestas | Estrategia |
|------|-----------|------------|
| **⭐ Prioridad máxima** | **F → V → H** | F→GLOBECOM; V→Journal; H→Journal o conf. Pipeline directo, mismo testbed |
| **Paralelo (simulación)** | **L** | L→ICASSP 2027 (ML career track) |
| **Alta prioridad experimental** | **A** | Hardware disponible; impacto único; ISAC 2026 o Journal |
| **Media prioridad experimental** | **K** | Requiere más setup; Journal |
| **Teórico profundo** | **J, C** | J+C son versiones profundas del tema NL que V toca ligeramente |
| **Opcional** | **D, G, I, E, N** | Bajo esfuerzo o nicho |

---

### Propuesta F: Broadcast K-only Architecture — Distance Recovery sin Medición Cooperativa ⭐

**Idea central:** Eliminar la medición cooperativa (K+1) del pipeline TCOM. En vez de reapuntar LED y PD para medir distancia, extraer d directamente de las K mediciones de direction finding, usando η̂ (estimado de las potencias) y cos(ψ) (obtenido de n_r vía acelerómetro). Esto convierte el sistema en broadcast: N receptores se localizan simultáneamente con un solo escaneo de K orientaciones.

**Novedad respecto al TCOM:**
- **Eliminación de la medición K+1**: no se requiere PD steering ni cooperación TX↔RX
- **Estimador de η a partir de K mediciones**: η̂ = [Σ μ̂_i Q̂_i^m] / [Σ Q̂_i^{2m}], recuperando la información de distancia que GLS/WLS descartan en las ratios
- **Fórmula de distancia**: d̂ = sqrt(-C·(n_r · n̂_d) / η̂), donde n_r viene de un acelerómetro
- **Derivación del PEB para la arquitectura K-only** (sin K+1): nueva FIM que no asume beam alignment
- **Análisis de sensibilidad**: error en d por incertidumbre de n_r del IMU (~1-2°) → Δd/d ≈ 1%
- **Multi-receptor broadcast**: N PDs estiman dirección + distancia en paralelo sin mediciones dedicadas
- **Comparación formal**: arquitectura cooperativa (TCOM) vs. broadcast (K-only + IMU) en términos de PEB, SNR, latencia, escalabilidad

**Argumento teórico clave:**
- Direction finding: sigue n_r-agnostic (Proposición 1 del TCOM intacta)
- Distance recovery: requiere n_r, pero solo a través de cos(ψ) = -n_r · n_d, que es una función suave — un acelerómetro de ~1° basta
- El trade-off es claro: se pierde n_r-agnosticidad total a cambio de eliminar PD steering + habilitar broadcast + reducir latencia

**Viabilidad:** Muy alta — todo el framework analítico está en el TCOM. Solo se añade:
1. Estimador de η (unas líneas de MATLAB)
2. Nueva derivación de FIM/PEB sin K+1 (modificar PEB_complete.m)
3. Simulaciones MC comparativas

**Target:** GLOBECOM 2026 Workshop (12 Ago) — contribución clara, autocontenida, diferenciada del TCOM.

---

### Propuesta A: Arquitectura Dual-Beam para Posicionamiento y LiFi Ininterrumpido ⭐⭐ (Journal Track) ⚡

> **Hardware disponible:** LiFi dongle (OFDM, mide throughput) + Gimbal posicionamiento + Gimbal LiFi. El receptor necesita PD (posicionamiento) + dongle LiFi receptor (datos) — separación de funciones deliberada y óptima.

**Idea central:** Usar dos gimbals cooperativos: uno con LED NIR para direction finding (K-scan → GLS/NLS → `n̂_d`) y otro con el dongle LiFi que usa `n̂_d` para apuntar y mantener el enlace de datos activo mientras el usuario se mueve. La **contribución central es el acoplamiento cuantitativo DEB → throughput**: cuánta precisión de posicionamiento se necesita para garantizar throughput de LiFi ininterrumpido.

---

#### A.1 Arquitectura y modelo del sistema

```
GIMBAL 1 (posicionamiento):
  LED NIR → K orientaciones → PD receptor → GLS → n̂_d (cada T_pos ms)

GIMBAL 2 (comunicación):
  LiFi dongle → apunta a n̂_d → dongle LiFi receptor → throughput T(δ_θ)

Acoplamiento: δ_θ = error angular = ||n̂_d - n_d|| ~ √DEB
```

**Interferencia entre beams — manejable:**
- Separación espectral: LED NIR posicionamiento (~850 nm) vs. LiFi dongle (~940 nm o visible); filtros ópticos en cada receptor eliminan la otra fuente
- Separación temporal: K-scan dura ~50–100 ms → durante ese tiempo LiFi en modo continuo (el scan no interrumpe datos); el nuevo `n̂_d` actualiza el apuntamiento del Gimbal 2 al final del scan
- Separación espacial: el LiFi apunta directamente al dongle receptor (narrow beam) → el PD de posicionamiento no está en esa trayectoria

**Receptor dual — separación óptima de funciones:**
- PD: ancho de banda bajo, área grande, sensibilidad alta → óptimo para detectar potencia óptica de posicionamiento
- Dongle LiFi: ancho de banda ~100 MHz+, detector rápido → óptimo para OFDM
- Intentar combinarlos en uno implica compromisos en ambos; la separación es la elección de diseño correcta

---

#### A.2 La contribución teórica: bound DEB → Throughput

El throughput del enlace LiFi depende del error de alineación `δ_θ` causado por el DEB de posicionamiento:

```
T(δ_θ) = B · log₂(1 + η_LiFi · cos^m(δ_θ) / σ²_noise)

Con δ_θ ~ √DEB:  T(DEB) = B · log₂(1 + η_LiFi · cos^m(√DEB) / σ²_noise)
```

**Resultado clave:** existe un DEB umbral `DEB*` tal que la degradación de throughput es menor que `ΔT_max` dB:

```
DEB* = arccos((1 + η_LiFi·(1 - ΔT_max/B) / σ²)^{1/m})²
```

Esto da una **especificación de precisión de posicionamiento para garantizar calidad de comunicación** — un bound nuevo que no existe en la literatura OWP.

**Análisis adicional:**
- Tradeoff velocidad de actualización de `n̂_d` (T_pos) vs. velocidad de movimiento del usuario
- Si el usuario se mueve a v m/s y T_pos = 100 ms → acumulación de error angular: θ(t) = arcsin(v·T_pos/d)
- Condición de seguimiento: θ(T_pos) < √DEB* → máxima velocidad admisible del usuario

---

#### A.3 Experimento

1. **Setup:** Gimbal 1 (LED NIR + gimbal motor) + Gimbal 2 (LiFi dongle + gimbal motor), PD + dongle LiFi receptor montados en soporte móvil
2. **Escenario estático:** medir throughput LiFi vs. error de alineación deliberado → verificar modelo T(δ_θ)
3. **Escenario dinámico:** mover el receptor a velocidad v conocida; Gimbal 1 estima `n̂_d` cada T_pos ms; Gimbal 2 apunta → medir throughput continuo
4. **Resultado:** curva throughput vs. velocidad de movimiento, comparada con el bound teórico

---

#### A.4 Estructura del paper (Journal)

| Sección | Contenido |
|---------|-----------|
| I. Intro | Motivación: LiFi requiere alineación precisa; beam-steered OWP como solución; arquitectura dual |
| II. System Model | Dual-gimbal; modelo posicionamiento (TCOM); modelo LiFi (OFDM, throughput vs. SNR) |
| III. Bound DEB-Throughput | Derivación del acoplamiento; DEB* para throughput garantizado; velocidad máxima admisible |
| IV. Diseño del sistema | Criterio de diseño conjunto K (orientaciones) ↔ T_pos ↔ throughput mínimo |
| V. Análisis de interferencia | Espectral, temporal, espacial; condiciones de operación limpia |
| VI. Experimental | Setup dual-gimbal; escenario estático + dinámico; throughput real vs. bound |
| VII. Conclusión | |

**Viabilidad:** Alta — hardware disponible. La teoría de posicionamiento ya existe (TCOM). La parte nueva es el modelo LiFi y el experimento dinámico.

**Target:** IEEE Transactions on Communications (TCOM) companion — directamente relacionado con el paper base. Alternativamente IEEE/OSA J. Lightwave Technology.

---

### Propuesta C: Beam-Steered OWP con Emisores No-Lambertianos — Validación Experimental ⭐⭐ (Journal Track — JLT)

> **Relación con Propuesta J:** Esta propuesta es el complemento experimental de la Propuesta J (teórica). Propuesta J deriva el framework general y los estimadores para `R(φ)` arbitrario; Propuesta C toma ese framework y lo valida con mediciones reales de un LED/liquid lens. Pueden publicarse independientemente o secuencialmente (J primero).

> **Prerequisito conceptual:** Construye sobre Propuesta F (K-only). Calibrar `R(φ)` es imprescindible para la estimación de distancia sin medición cooperativa.

**Idea central:** Con el framework teórico de Propuesta J como base, esta extensión realiza la **validación experimental completa** del OWP con emisores no-Lambertianos reales: caracterizar `R(φ, azimuth)` del LED/liquid lens del LISV, calibrar el NLS con ese patrón medido, y comparar experimentalmente los cuatro estimadores (GLS nominal, GLS m_eff, GLS+Newton, NLS calibrado) contra el DEB numérico.

---

#### C.1 Fuentes de información del patrón R(φ)

Hay dos fuentes disponibles para el sistema VLP del LISV:

| Fuente | Forma | Cuándo usar |
|--------|-------|-------------|
| **Datasheet LED** | `R(φ)` 2D (sin dependencia azimutal) | Simulación de mismatch antes de experimentos; validación del framework |
| **Medición experimental** | `R(φ, azimuth)` tabla 2D completa | Calibración real del sistema; validación end-to-end |

La **dependencia azimutal** en `R(φ, azimuth)` es relevante cuando el LED tiene asimetría: al inclinar una liquid lens, el lóbulo de emisión se deforma y deja de ser de revolución. Para cada orientación de steering `i` (distinto ángulo `θ_i`), la azimut relativa del LED respecto al receptor cambia, por lo que `R(φ_i)` puede variar entre orientaciones. Si la dependencia azimutal es débil, basta `R(φ)`; si es fuerte, se necesita `R(φ, azimuth)` como tabla 2D.

**Estrategia de uso:** datasheet → simulación y análisis de mismatch (Secciones III–V); experimental `R(φ, azimuth)` → calibración completa y validación experimental (Secciones VII–VIII).

---

#### C.2 Análisis matemático riguroso: ¿qué se rompe con R(φ) no-Lambertiano?

La factorización del modelo de observación del TCOM es:

```
μ_i = η · R(φ_i)    donde φ_i = arccos(n_{t,i} · n_d)
```

Esta factorización **sigue siendo válida para cualquier `R(φ)`**. Sin embargo, la estructura algebraica que permite a GLS/WLS tener solución de forma cerrada es específica del Lambertiano.

**Por qué GLS/WLS requieren `R(φ) = cos^m(φ)` exactamente:**

GLS aplica la raíz m-ésima a la ratio de potencias:

```
β_i = (μ_i/μ_1)^{1/m} = (Q_i^m / Q_1^m)^{1/m} = Q_i/Q_1 = (n_{t,i}·n_d)/(n_{t,1}·n_d)
```

Esta operación transforma una ratio de monomios en una **ratio de productos escalares**, produciendo tras multiplicación cruzada el sistema lineal `a_i · n_d = 0` con `a_i = n_{t,i} - β_i·n_{t,1}`. Toda la maquinaria GLS/WLS (SVD, pesos estadísticos, Proposición 1 del TCOM) descansa sobre esta linealización.

**Con `R(φ)` arbitrario, no existe tal truco:**

```
μ_i/μ_1 = R(arccos(n_{t,i}·n_d)) / R(arccos(n_{t,1}·n_d))
```

No hay transformación algebraica de esta ratio que produzca una función lineal en `n_d` para `R` genérica. Se verificaron los siguientes "tricks" y todos fallan por la misma razón — requieren conocer algún ángulo absoluto que depende de `n_d`:

| Trick intentado | Por qué falla |
|-----------------|--------------|
| Raíz `1/m_eff` con m efectivo | Solo aproximado; introduce bias sistemático |
| `z_i = cos(R^{-1}(μ_i/η))` → sistema lineal | Requiere `η` conocido — es el parámetro de molestia |
| Normalizar por `max μ_j` + aplicar `R^{-1}` | Requiere `R(φ_{max})` donde `φ_{max} = arccos(n_{t,max}·n_d)` — circular |
| Lookup table para invertir ratios `R(φ_i)/R(φ_j)` | Recuperar `cos φ_i/cos φ_j` requiere conocer un ángulo de referencia |

La barrera es fundamental: GLS linealiza solo cuando `f(x) = R(arccos(x))` es un **monomio** `x^m`. Ninguna otra función `f` permite linealizar el sistema.

**Qué sí se preserva y cómo queda el cuadro completo:**

| Componente | ¿Se preserva? | Nota |
|------------|---------------|------|
| Modelo `μ_i = η·R(φ_i)` | ✅ Sí | Solo cambia la función de φ |
| **GLS / WLS (exactos)** | ❌ **No** | Requieren monomio `cos^m` |
| GLS / WLS con `m_eff` (best-fit Lambertiano) | ⚠️ Aproximado | Válido si `R(φ) ≈ cos^{m_eff}(φ)` en escala log-log |
| **NLS del TCOM con `R_spline(φ)`** | ✅ Sí — sin cambios algorítmicos | Solo sustituir `cos^m` por `R_spline` en la función de costo |
| FIM y DEB (numéricamente) | ✅ Sí | FIM usa `R'(φ_i)` numérica o analítica desde spline |
| GA de orientaciones | ✅ Sí | Evalúa DEB numérico en cada generación |
| Estimador `η̂` para K-only (Propuesta F) | ✅ Sí, con R calibrado | Mismatch en R → bias en `d̂` |

**Implicación clave para el paper:**

El paso de Lambertiano a no-Lambertiano **cambia la clase del problema de estimación de dirección: de lineal (GLS) a no-lineal (NLS)**. Pero el NLS del TCOM ya es el estimador correcto — solo necesita que se le pase `R_spline(φ)` en lugar de `cos^m(φ)`. **No hay que proponer un algoritmo nuevo.** La contribución es:
1. Demostrar matemáticamente por qué GLS/WLS fallan
2. Cuantificar experimentalmente cuánto degradan
3. Mostrar que el NLS del TCOM (sin cambios de algoritmo) recupera el DEB generalizado con R(φ) calibrado
4. Proponer GLS con `m_eff` como compromiso práctico de forma cerrada cuando no se tiene calibración completa

---

#### C.3 Estimadores generales para R(φ) arbitrario: de cerrado a óptimo

**El MLE perfilado sobre S²** (óptimo, general):

Para cualquier `R(φ)` conocida, el parámetro de molestia `η` puede eliminarse analíticamente para `v` fijo:

```
η̂(v) = Σᵢ μᵢ·R(φᵢ(v)) / Σᵢ R²(φᵢ(v))
```

El estimador MLE se reduce entonces a una **optimización 2D sobre la esfera**:

```
n̂_d = argmax_{v ∈ S²}  [Σᵢ μᵢ · R(arccos(n_{t,i}·v))]²
                         ──────────────────────────────────
                              Σᵢ R²(arccos(n_{t,i}·v))
```

Esto funciona para **cualquier** `R(φ)` — analítica, spline, tabla. Es el MLE exacto para ruido gaussiano y está directamente relacionado con el DEB (la FIM del TCOM generalizado). El NLS del TCOM con `R_spline` converge a este mismo mínimo; la diferencia es algorítmica.

---

**El estimador propuesto: GLS(m_eff) + paso Riemanniano** (cuasi-cerrado, general):

El punto clave es que GLS sigue siendo **útil como inicializador** incluso cuando `R(φ)` no es Lambertiano exacto:

- **Paso 1 — Inicialización (cerrada):** Ajustar `m_eff` en log-log, aplicar GLS → `v⁰` ∈ S²
- **Paso 2 — Refinamiento (1 iteración Newton sobre S²):**

```
gradiente del MLE perfilado en v⁰:
∇_v [Σᵢ μᵢ·R(φᵢ(v))] = Σᵢ μᵢ · R'(φᵢ(v⁰)) · ∂φᵢ/∂v|_{v⁰}
donde ∂φᵢ/∂v = -(n_{t,i} - (n_{t,i}·v)·v) / sin(φᵢ)   ← gradiente proyectado sobre S²

actualización geodésica: v¹ = v⁰ + α·(gradiente proyectado) → normalizar a S²
```

donde `R'(φ)` es la derivada del spline (analítica por tramos). El paso size `α` se obtiene por búsqueda de línea en S² (1D, barato).

**Propiedades:**
- Complejidad total: `O(K)` — comparable a GLS
- Para canal Lambertiano exacto: `v⁰` ya es el MLE → el paso Newton no modifica `v⁰` → **recupera el TCOM como caso especial**
- Para canal suavemente no-Lambertiano: 1–2 pasos bastan para alcanzar el DEB numérico

**Espectro completo de estimadores para el paper:**

```
GLS(m)  →  GLS(m_eff)  →  GLS(m_eff)+Newton(R_spline)  →  NLS(R_spline) completo
[TCOM]    [práctico]       [general, cuasi-cerrado,          [exacto, iterativo]
                            near-optimal, O(K)]
```

GLS "no muere" con R(φ) no-Lambertiano: su rol cambia de **estimador final** a **inicializador de calidad** para un refinamiento de un paso que es general y near-optimal.

---

#### C.4 Representaciones de R(φ) no-analíticas

| Representación | Forma | Derivada `R'(φ)` | Uso típico |
|----------------|-------|------------------|------------|
| **Lookup table** | `{(φ_k, R_k)}` | Diferencias finitas | Medición directa con goniómetro |
| **Spline cúbico** | Polinomios por trozos `p_j(φ)` en `[φ_j, φ_{j+1}]` | Analítica por tramos | Interpolación suave de tabla |
| **Suma de Gaussianas** | `Σ a_k exp(-(φ-μ_k)²/2σ_k²)` | Analítica global | Modelo paramétrico ajustado |
| **Lambertiano generalizado** | `cos^{m(φ)}(φ)` con `m` variable | Semi-analítica | Si el lóbulo es variable con φ |
| **Fourier/Legendre truncado** | `Σ c_k P_k(cos φ)` | Analítica | Representación espectral |

Para esta extensión, el caso más práctico y realista es **spline cúbico sobre tabla medida**: suaviza el ruido de medición y provee derivadas analíticas por tramos que el GA puede evaluar eficientemente.

---

#### C.5 Pipeline de estudio: test directo con cuatro escenarios

En lugar de intentar una fórmula cerrada de DEB para cada tipo de `R(φ)`, se propone un abordaje empírico-computacional. La estimación de dirección en el caso no-Lambertiano es **no-lineal** (solo NLS aplica), por lo que el pipeline completo cambia:

1. **Medir `R(φ)` real para el LED/liquid lens disponible** (goniómetro, paso 1°–2°)
2. **Ajustar spline cúbico** sobre la tabla medida → `R_spline(φ)` con derivada analítica por tramos
3. **Implementar DEB numérico**: reemplazar `m·Q_i^{m-1}` por `R'_spline(φ_i)/R_spline(φ_i)·Q_i` en el gradiente de la FIM
4. **Correr GA con DEB numérico** → orientaciones óptimas para `R(φ)` real
5. **Implementar NLS calibrado**: función de costo `F(v,η) = Σ(η·R_spline(arccos(n_{t,i}·v)) - p_i)²`
6. **Comparar cuatro escenarios** en simulación y experimento:
   - *L*: canal Lambertiano, estimador GLS (baseline TCOM)
   - *NL / GLS-mismatch*: canal no-Lambertiano, estimador GLS (Lambertiano asumido) → bias sistemático cuantificable
   - *NL / NLS-mismatch*: canal no-Lambertiano, NLS con `cos^m` (orden m ajustado por best-fit) → degradación parcial
   - *NL / NLS-calibrado*: canal no-Lambertiano, NLS con `R_spline(φ)` medido → rendimiento óptimo, alcanza DEB
7. **Responder**: ¿Cuánto cuesta el mismatch Lambertiano en términos de RMSE? ¿Vale la pena calibrar R(φ) o basta con un m efectivo?

---

#### C.6 Conexión con la arquitectura broadcast K-only (Propuesta F)

En la arquitectura broadcast (Propuesta F), la recuperación de distancia usa:

```
d̂ = sqrt(-C · cos(ψ) / η̂)
```

donde `η̂` se estima de las potencias absolutas bajo el modelo `μ_i = η · R(φ_i)`. Si `R(φ)` es incorrecto (mismatch Lambertiano), `η̂` tiene bias sistemático → **error en distancia, no solo en dirección**. La calibración de `R(φ)` es por tanto **imprescindible para la arquitectura K-only**, mientras que en el pipeline cooperativo del TCOM el error en dirección es el que domina.

Este acoplamiento convierte Propuestas F + C en un trabajo conjunto coherente: F resuelve la arquitectura (elimina K+1), C resuelve la calibración del modelo de canal.

---

#### C.7 Abordaje experimental completo

1. **Caracterización del patrón de emisión**
   - Montar LED (o LED + liquid lens) en goniómetro
   - Medir potencia óptica a múltiples ángulos `(φ, θ)` con paso 1°–2°
   - Obtener `R(φ)` real vs. `cos^m(φ)` teórico; ajustar spline cúbico y best-fit Lambertiano (m_eff)
   - Repetir para distintos ángulos de steering `θ_steer` (el patrón puede cambiar al inclinar la liquid lens)

2. **Implementación del DEB numérico**
   - Reemplazar `m·Q_i^{m-1}` (gradiente de `cos^m`) por `R'_spline(φ_i)` en el vector de gradiente de la FIM
   - Verificar que el DEB numérico converge al DEB analítico del TCOM cuando `R(φ) = cos^m(φ)`

3. **Optimización GA con R(φ) real**
   - Correr GA minimizando DEB numérico con `R_spline(φ)`
   - Comparar orientaciones óptimas: diseñadas para cos^m vs. diseñadas para `R(φ)` real

4. **Análisis de robustez (mismatch)**
   - Cuantificar degradación de RMSE en los cuatro escenarios (L, NL/GLS-mismatch, NL/NLS-mismatch, NL/NLS-calibrado)
   - Nota: en los escenarios NL, GLS introduce bias sistemático irreducible (no solo ruido aumentado)
   - Incluir análisis para la arquitectura K-only (Propuesta F): el error en `η̂` por mismatch de `R(φ)` se propaga directamente a `d̂`

5. **Validación experimental end-to-end**
   - Setup: LED con steering (gimbal o liquid lens) + PD a posiciones conocidas
   - Medir K potencias reales en múltiples posiciones
   - Aplicar NLS con `R_spline(φ)` calibrado vs. GLS con Lambertiano asumido
   - Comparar error de posición experimental vs. DEB numérico → validar que el NLS calibrado alcanza el bound

---

#### C.8 Estructura del paper (Journal)

| Sección | Contenido |
|---------|----------|
| I. Intro | Motivación: LEDs reales no son Lambertianos; impacto sobre el framework TCOM |
| II. System Model | Modelo `μ_i = η·R(φ_i)` generalizado; representaciones de `R(φ)` (datasheet, spline, tabla 2D) |
| III. DEB Numérico | FIM generalizada con `R'(φ)` numérica; MLE perfilado sobre S² como estimador óptimo general |
| IV. Análisis de mismatch GLS | Por qué GLS falla para `R(φ)` no-Lambertiano; cuantificación del bias; `m_eff` como best-fit |
| V. Estimador GLS(m_eff)+Newton | Paso Riemanniano sobre S²; gradiente proyectado; `O(K)` complejidad; caso Lambertiano como caso especial |
| VI. NLS calibrado (referencia) | NLS del TCOM con `R_spline`; relación con MLE perfilado; benchmarks de convergencia |
| VII. GA con R(φ) real | Orientaciones óptimas bajo `R(φ)` real; comparación vs. orientaciones Lambertiano-óptimas |
| VIII. Extensión K-only | `η̂` con `R_spline`; propagación de mismatch de `R(φ)` a `d̂` |
| IX. Experimental | Caracterización LED (datasheet + goniómetro); validación end-to-end con 4 estimadores |
| X. Conclusión | |

---

**Viabilidad:** Media-alta. Requiere:
- Acceso a goniómetro y LED/liquid lens (disponible en LISV)
- Setup de posicionamiento con ground truth (mesa XY o similar)
- ~3–4 meses experimentales + 2 meses redacción

**Target Journal (por orden de preferencia):**

| Journal | IF | Por qué |
|---------|----|---------|
| **IEEE/OSA J. Lightwave Technology (JLT)** | ~4.7 | Flagship para OWC. Acepta teoría + experimental. Publica non-Lambertian channel papers regularmente. |
| **IEEE Photonics Journal** | ~2.4 | Bueno para contribuciones experimentales en OWC. Review rápido. Open access. |
| **Optics Express** | ~3.8 | Si el énfasis es la caracterización óptica del patrón + posicionamiento. |
| **IEEE Sensors Journal** | ~4.3 | Si se enfoca en el aspecto de sensing/localización con validación experimental. |

**Recomendación:** **JLT** si el paper es fuerte en teoría + experimental (escenarios L + NL-mismatch + NL-calibrado + K-only). **IEEE Photonics Journal** si se prioriza rapidez. La combinación derivación numérica del DEB + calibración experimental + extensión K-only es una contribución autocontenida y ortogonal al TCOM.

---

### Propuesta D: Multi-Receiver Concurrent Localization

**Idea central:** El TCOM menciona que el escaneo periódico de K orientaciones puede servir a múltiples receptores simultáneamente. Esta extensión formaliza el escenario multi-usuario: N PDs en la escena, cada uno estima su dirección independientemente a partir de las mismas K mediciones broadcast.

**Novedad respecto al TCOM:**
- Análisis de capacidad de localización: cuántos usuarios puede soportar el sistema
- DEB como función de la posición de cada receptor (cobertura espacial)
- Scheduling: round-robin de K orientaciones para DF broadcast + slots dedicados para distance recovery
- Comparación con multi-LED tradicional en escenarios densos (robot swarms, warehouses)
- Impacto de NLOS parcial (oclusiones entre usuarios)

**Viabilidad:** Media — analítico sobre DEB existente + simulaciones MC con múltiples PDs. No requiere nuevo hardware.

**Target:** GLOBECOM 2026 Workshop o WCNC 2027.

---

### Propuesta E: Physics-Informed Neural Correction para Direction Finding en Beam-Steered OWP 🤖

> **Paper standalone — pre-Cambridge.** Esta propuesta es un paper de ML aplicado puro, independiente de Transfer Learning y de Propuesta M. Su objetivo es establecer el concepto "physics-informed correction sobre GLS" como contribución propia antes de la pasantía. Propuesta M puede posteriormente usar este concepto como punto de partida para TL, pero no lo requiere.

**Idea central:** GLS es el MLE del modelo linealizado de ratios → es eficiente pero subóptimo cuando el modelo tiene mismatch (patrón no exactamente cos^m, NLOS parcial, FOV edge effects). En vez de reemplazarlo con una red puramente data-driven, se aprende una **corrección residual** que preserva la interpretabilidad física:

```
n̂_d_corrected = n̂_d_GLS + f_θ({μ_i, n_{t,i}})

donde f_θ es un MLP ligero entrenado con (input: mediciones, output: error de GLS)
Las features físicas son: ratios μ_i/μ_j, cos(∠n_{t,i}, n_{t,j}), n̂_d_GLS
```

**Por qué es "physics-informed" (no solo NN):**
- Los features de entrada son cantidades físicas del modelo TCOM (ratios de potencia, geometría de orientaciones)
- La arquitectura asume equivarianza de rotación: rotar todas las orientaciones rota el output igual → constraints en los pesos
- El target de entrenamiento es el error `n̂_d_GLS - n_d`, no `n_d` directamente → el modelo "no puede ignorar" GLS

**Novedad respecto al TCOM:**
- Estimador GLS+NN que supera a GLS, WLS y se acerca al DEB sin el coste de NLS
- Análisis de cuándo el residual es grande: mismatch de modelo, borde del FOV, K pequeño
- Comparación sistemática: GLS / WLS / NLS / GLS+NN / DEB
- Demostrar que GLS+NN es near-optimal para K≥5 con mismatch moderado

**Viabilidad:** Alta — Python + PyTorch. Simulador OWP simple (20 líneas de NumPy). MLP pequeño (2-3 capas). Training en minutos en CPU. Dataset sintético generado directamente del modelo TCOM. ~2–3 meses.

**Relación con Propuesta M:** el concepto aprendido aquí (f_θ como corrector de GLS) es lo que se transfiere en M a un nuevo entorno. Pero E es completo y publicable sin M — la diferencia es que E asume mismo entorno en train y test, M estudia la generalización cross-entorno.

**Target:** **IEEE Signal Processing Letters** (4 páginas, review ~3 meses, IF ~3.9) — venue ideal para contribuciones ML aplicadas a señal. Alternativa: **ICASSP 2027** (6 páginas, deadline ~Sep 2026). Ambos tienen visibilidad directa en la comunidad ML+SP que valora industria AI en París.

---

### Propuesta G: Limitación Fundamental de Observabilidad para ML en OWP con PD Único

**Idea central:** Demostrar formalmente que la limitación de requerir n_r para distance recovery es una propiedad física del canal (no del algoritmo), y que aplica igualmente a métodos ML. Esto posiciona el framework model-based como teóricamente óptimo y desmitifica la idea de que ML puede "superar" los límites físicos.

**Argumento teórico (observabilidad):**

De K mediciones de potencia, cualquier método extrae como máximo 3 parámetros independientes:
- **n_d** (2 DoF): de las ratios entre potencias
- **η = C·cos(ψ)/d²** (1 DoF): del nivel absoluto

Pero η mezcla d (1 DoF) con cos(ψ) que depende de n_r (2 DoF). Para cualquier (r, n_r) existe otro par (r', n_r') que produce **exactamente** las mismas K potencias:
- Misma dirección: n_d' = n_d
- Distinta distancia: d' ≠ d  
- Compensación: cos(ψ')/d'² = cos(ψ)/d²

**El mapeo (r, n_r) → (μ₁,...,μ_K) no es inyectivo** → ningún estimador (ML o no) puede invertirlo.

**Implicaciones para ML:**
- ML con n_r fijo en training: funciona, pero falla si n_r cambia en test
- ML con n_r variable sin darlo como input: label noise irreducible, aprende E[r|μ₁,...,μ_K]
- ML con n_r como input: funciona (equivalente a IMU-assisted model-based)
- ML estimando pose (r + n_r) de K potencias: imposible (mapeo no inyectivo)

**Novedad respecto al TCOM:**
- Prueba formal de no-inyectividad del mapeo
- Comparación experimental: NN vs GLS vs WLS bajo distintos escenarios de n_r
- Cuantificación del error irreducible de ML cuando n_r es desconocido
- Posiciona los bounds del TCOM como límites universales (no solo para model-based)

**Viabilidad:** Alta — es un argumento analítico + simulaciones comparativas ML vs model-based.

**Target:** Puede complementar a Propuesta F (como sección adicional) o ser contribución independiente para WCNC/ICC 2027.

---

### Propuesta K: Multi-LED Beam-Steered OWP con Gimbals Mecánicos ⭐⭐⭐ (Journal Track — TCOM/JLT) ⚡

> **Ventaja hardware:** Requiere múltiples gimbals mecánicos — disponibles en el LISV. Es la propuesta de mayor diferenciación porque pocos grupos en el mundo tienen este setup y la teoría TCOM para analizarlo.

**Idea central:** El TCOM usa un único LED beam-steered. Esta extensión usa **N LEDs cada uno en su propio gimbal**, todos iluminando el mismo receptor (single PD). Cada LED contribuye con K_i mediciones de potencia independientes → la FIM total es la suma de las FIMs individuales → el DEB cae por un factor ~N para mismo K total, o se puede mantener el DEB con K/N orientaciones por LED (sistema N veces más rápido).

---

#### K.1 Modelo y FIM multi-LED

Para N LEDs con posiciones `p_l` y orientaciones `{n_{t,l,i}}`, el receptor en `r` recibe:

```
μ_{l,i} = η_l · (n_{t,l,i} · n_{d,l})^m   con  n_{d,l} = (r - p_l)/||r - p_l||
```

La dirección `n_{d,l}` varía por LED (cada LED "ve" al receptor desde una posición diferente). La FIM total es:

```
J_total(r) = Σ_l J_l(r)
```

donde cada `J_l` es la FIM del LED-l como en el TCOM. La **diversidad espacial** de múltiples LEDs en distintas posiciones rompe las simetrías que limitan el single-LED → el PEB multi-LED puede ser isotrópico incluso con K pequeño.

**Resultado clave esperado:** Con N=2 LEDs en posiciones opuestas del techo y K=5 orientaciones cada uno (K_total=10), el PEB es significativamente menor y más uniforme que single-LED con K=10.

---

#### K.2 Diseño conjunto de orientaciones (GA multi-LED)

El GA del TCOM se extiende para optimizar conjuntamente las N×K orientaciones:

```
{n_{t,l,i}}* = argmin_{n_{t,l,i}} max_{r ∈ Room} DEB_multi(r)
```

El DEB multi-LED depende de la posición del receptor `r` (a diferencia del DEB de un solo LED que solo depende de la dirección). El GA necesita integrar sobre un grid espacial del habitáculo.

**Comparaciones de interés:**
- Single-LED K=10 vs. 2-LED K=5+5 (mismo tiempo de scan)
- Orientaciones independientes vs. orientaciones complementarias diseñadas conjuntamente
- Robustez a oclusión de un LED (NLOS parcial)

---

#### K.3 Experimento con hardware disponible

1. **Setup:** 2–3 LEDs en gimbals mecánicos en posiciones del techo del laboratorio, PD en mesa XYZ (ground truth)
2. **Calibración:** medir `η_l` para cada LED individualmente, verificar modelo de potencia
3. **Escaneo:** cada LED hace K orientaciones (independientemente), registrar K_total potencias
4. **Estimación:** aplicar GLS/NLS multi-LED (vectorizar los K_total residuos)
5. **Validación:** comparar RMSE experimental vs. DEB multi-LED derivado

**Metric clave:** ¿Cuántos LEDs necesito para obtener PEB < 1 cm en toda la habitación?

---

#### K.4 Estructura del paper (Journal)

| Sección | Contenido |
|---------|-----------|
| I. Intro | Limitación single-LED: cobertura y precisión no uniformes; ventaja multi-LED |
| II. System Model | N LEDs beam-steered; FIM multi-LED = suma de FIMs; estimadores multi-LED |
| III. DEB Multi-LED | Diversidad espacial; condición de isotropía; gap single vs. multi |
| IV. GA conjunto | Optimización de N×K orientaciones; comparación independiente vs. conjunto |
| V. Análisis de robustez | NLOS parcial, oclusión de un LED, heterogeneidad de potencias |
| VI. Experimental | Setup multi-gimbal; validación end-to-end; RMSE vs. DEB |
| VII. Conclusión | |

**Viabilidad:** Alta con hardware disponible. La teoría es extensión directa del TCOM (misma FIM, mismos estimadores, sumados). El GA multi-LED es más complejo pero computable.

**Target:** IEEE Transactions on Communications (companion al TCOM) o IEEE/OSA J. Lightwave Technology.

---

### Propuesta J: Framework Teórico General para OWP con Emisores No-Lambertianos ⭐⭐ (Journal Track — TSP/TCOM)

> **Relación con Propuesta C:** Esta propuesta es el **companion teórico** de Propuesta C. No requiere experimentos — solo simulación. Puede someterse 4–6 meses antes que Propuesta C y sirve como fundamento teórico de referencia.

**Idea central (alcance honesto):** El TCOM asume `R(φ) = cos^m(φ)` y deriva GLS como estimador closed-form gracias a esa estructura. Para `R(φ)` arbitrario se demuestra que **NO existe GLS closed-form** (resultado de imposibilidad), y se ofrece como solución práctica un **híbrido GLS-init + Newton refinement** que es near-optimal con coste computacional comparable al GLS clásico. El framework cubre: (i) FIM/DEB universales, (ii) prueba de imposibilidad de cerrado, (iii) híbrido near-closed-form, (iv) elección de medición de referencia, (v) diseño óptimo de orientaciones para `R` arbitrario, y (vi) caso estudio VCSEL.

**Lo que J NO promete:** una familia infinita de GLS closed-form para R distintos. Eso no existe (J.3 lo prueba). Lo que J SÍ entrega: un framework completo donde para cada R real se obtiene un estimador eficiente y un bound asociado.

---

#### J.0 Feasibility breakdown por componente

| Componente | Tarea técnica | Dificultad | Tiempo | Riesgo de no salir |
|------------|---------------|-----------|--------|---------------------|
| **DEB/PEB generalizadas** | FIM con `R'(φ)` para R diferenciable | Baja | 2 sem | Muy bajo — extensión directa del TCOM |
| **Prueba imposibilidad GLS** | Algebraico: GLS linealiza ⇔ R(arccos(·)) es monomio | Media | 2–3 sem | Bajo — argumento auto-contenido |
| **Híbrido GLS-init + Newton** | m_eff por LSQ, Newton-Riemann en S² con R real | Media | 4 sem | Bajo — Newton estándar, gradiente derivable |
| **Análisis convergencia híbrido** | Radio de captura, condiciones de monotonía | Media-Alta | 3 sem | Medio — puede requerir asumir R log-cóncava o similar |
| **Análisis normalización (Q2)** | β_1 vs β_max vs β_geo, FIM bajo reparametrización | Baja | 2 sem | Muy bajo |
| **Diseño orientaciones para R** | GA con DEB numérico, R arbitraria | Baja | 2 sem | Muy bajo — código GA del TCOM reutilizable |
| **Caso estudio VCSEL** | Gaussian R, simulaciones, comparación 4 estimadores | Baja | 2–3 sem | Muy bajo |
| **Redacción** | — | — | 4–6 sem | — |

**Total realista: 4–5 meses.** Riesgo principal: el análisis de convergencia del híbrido (J.4) puede requerir suposiciones técnicas (log-concavidad de R) que no se cumplen para todos los R. **Fallback:** presentar convergencia como resultado empírico (curvas de iteraciones por habitación) en lugar de teorema. Sigue siendo paper publicable.

---

#### J.1 Motivación: casos extremos que el TCOM no puede manejar

| Fuente de luz | Patrón `R(φ)` | ¿Similar a cos^m? | Aplicación OWP relevante |
|---------------|--------------|-------------------|--------------------------|
| LED estándar | `cos^m(φ)`, m=1–3 | ✅ Sí | Baseline TCOM |
| LED high-power con reflector | `cos^m(φ)`, m=5–20 | ✅ Aproximado | Largo alcance |
| LED + liquid lens steering | Deformado con θ_steer | ⚠️ Solo si θ_steer≈0 | Sistema del LISV |
| **VCSEL** | `exp(-φ²/2σ²)`, σ≈5–15° | ❌ **No** | ToF sensors, LiDAR indoor, precisión sub-mm |
| LED + difusor | Casi uniforme `R≈const` | ❌ **No** | Cobertura amplia, baja precisión |
| LED con reflector parabólico | Multi-lóbulo | ❌ **No** | Sistemas de alto gain |

El caso **VCSEL** es especialmente interesante: VCSELs se usan en sensores ToF (Apple Face ID, LIDAR Velodyne), tienen altísima potencia óptica en ángulo estrecho, y son una tecnología emergente para OWC indoor de alta velocidad. ¿Se puede hacer OWP de precisión con un VCSEL beam-steered? Esta pregunta solo puede responderse con el framework generalizado.

---

#### J.2 Contribuciones teóricas principales

**J.2.1 FIM y DEB para R(φ) arbitrario (derivación cerrada)**

La FIM generalizada para estimación de dirección con cualquier `R(φ)` diferenciable es:

```
J(n_d) = (η/σ²) · Σᵢ [R'(φᵢ)/sin(φᵢ)]² · P_{T_{n_d}}(n_{t,i})
```

donde `P_{T_{n_d}}` es la proyección ortogonal sobre el plano tangente a S² en `n_d`, y `R'(φ) = dR/dφ`. El DEB se obtiene como la traza de J⁻¹.

Esta expresión unifica todos los casos: para `R(φ) = cos^m(φ)`, `R'(φ)/sin(φ) = -m·cos^{m-1}(φ)` recupera exactamente la FIM del TCOM.

**J.2.2 Ángulo óptimo de orientación para R(φ) general**

El FIM por orientación `∝ [R'(φ)/sin(φ)]²` tiene un máximo en:

```
φ_opt(R) = argmax_φ  [R'(φ)/sin(φ)]²
```

Para Lambertiano: `φ_opt = arccos(√((m-1)/m))` (derivable analíticamente).
Para VCSEL `R(φ) = exp(-φ²/2σ²)`: `φ_opt = σ` (el ángulo de semi-divergencia).
Para difusor `R(φ)≈const`: la FIM es ~0 para todo φ → **imposible hacer direction finding** con emisor uniforme (resultado negativo importante).

**J.2.3 Prueba formal de imposibilidad de GLS/WLS para R(φ) genérico**

Prueba algebraica de que GLS linealiza si y solo si `f(x) = R(arccos(x))` es un monomio `x^m`. Ninguna suma, producto o composición de monomios con m distinto funciona. Este es el único resultado formal de imposibilidad para OWP cerrado.

**J.2.4 Espectro de estimadores: de cerrado a óptimo**

```
GLS(m_eff) → GLS(m_eff)+Newton-Riemann → NLS(R_spline) = Profile MLE en S²
[O(K), approx]  [O(K), near-optimal]          [O(K·iter), exacto]
```

Derivación del GLS+Newton como estimador cuasi-cerrado general: justificación matemática, análisis de convergencia (radio de captura), y prueba de que para el caso Lambertiano exacto no modifica la solución GLS.

**J.2.5 Diseño óptimo de orientaciones para R(φ) arbitrario**

Generalización del GA del TCOM: reemplazar `m·Q_i^{m-1}` por `R'(φᵢ)/sin(φᵢ)` en el cálculo del DEB numérico → el GA encuentra el set de K orientaciones que minimiza DEB para cualquier `R(φ)`.

**Resultado esperado:** Para VCSEL (σ=10°), las orientaciones óptimas forman un cono de semi-ángulo ~φ_opt(VCSEL) ≈ 10° → sistema de precisión extrema en cobertura angular reducida. Para LED uniforme, no existe set de K orientaciones que dé DEB finito → límite fundamental.

---

#### J.3 Choice of Reference Measurement: análisis de normalización

El TCOM define `β_i = P_i/P_1` (referencia fija al primer canal). Esta elección no es única — y la decisión afecta tanto el sesgo como la varianza del estimador. J formaliza tres alternativas y caracteriza cuándo conviene cada una.

**J.3.1 Familias de normalización**

| Esquema | Definición | Naturaleza | Efecto en GLS |
|---------|-----------|------------|---------------|
| **β_1 (TCOM)** | `β_i = P_i/P_1` | Anchor determinístico | GLS clásico; sensible a `P_1` ruidoso |
| **β_max** | `β_i = P_i/max_j(P_j)` | Anchor data-dependent | Robusto a outliers en cualquier canal individual; introduce sesgo |
| **β_geo** | `β_i = P_i/(∏_j P_j)^(1/K)` | Media geométrica simétrica | Sin sesgo si todos los canales contribuyen; varianza balanceada |

**J.3.2 FIM bajo reparametrización no-lineal**

Para una transformación `g: μ → β` (con `g` diferenciable), la FIM en β se relaciona con la FIM en μ vía:

```
J_β = (∂g/∂μ)^(-T) · J_μ · (∂g/∂μ)^(-1)
```

Esto significa que **el DEB calculado sobre β_1, β_max o β_geo es matemáticamente equivalente** si los estimadores son MLE — solo cambia el camino computacional. Pero cuando los estimadores son cuasi-MLE (GLS, WLS) la elección de β sí afecta la eficiencia. El análisis cuantifica este gap.

**J.3.3 Resultado esperado**

- **β_1 (TCOM)**: óptimo asintóticamente cuando `P_1` es alto-SNR (orientación 1 cerca del receptor). Riesgo: si `P_1` es bajo-SNR (orientación 1 lejos), el ratio amplifica ruido en todos los canales.
- **β_max**: introduce sesgo `O(σ²/μ_max²)` por estimar el max, pero gana ~3 dB en escenarios donde la primera orientación queda fuera del lóbulo principal del LED.
- **β_geo**: balanceada; típicamente 1–2 dB peor que la mejor de las dos en cada régimen, pero nunca colapsa.

**Recomendación práctica:** β_1 cuando se conoce el mapa de SNR; β_geo como default robusto sin asumir nada sobre la geometría; β_max solo en escenarios con outliers severos (NLOS parcial).

---

#### J.4 Análisis de casos extremos (simulación)

| Caso | R(φ) | φ_opt | Cobertura útil | DEB vs. Lambertiano |
|------|------|-------|----------------|---------------------|
| LED estándar (m=3) | cos³(φ) | ~35° | 0–60° | Referencia TCOM |
| LED colimado (m=20) | cos²⁰(φ) | ~13° | 0–30° | Mejor (pero rango estrecho) |
| **VCSEL (σ=10°)** | exp(-φ²/200) | ~10° | 0–20° | Potencialmente mejor con orientaciones adaptadas |
| LED + difusor | ≈ const | N/A | 0–80° | **Infinito** (no observable) |
| LED asimétrico (liquid lens tilted) | R(φ,az) tabla 2D | depende de az | depende | Requiere FIM 2D |

---

#### J.5 Estructura del paper (Journal)

| Sección | Contenido | Mapeo a J.x |
|---------|-----------|-------------|
| **I. Introduction** | Gap: framework OWP cerrado existe solo para Lambertiano; motivación VCSEL + liquid lens; alcance honesto del paper | — |
| **II. Generalized System Model** | Modelo `μᵢ = η·R(φᵢ)`; clases de emisores; representaciones de R (paramétrico vs. spline) | — |
| **III. Generalized FIM and DEB** | Derivación con `R'(φ)`; sanity check Lambertian; φ_opt para R genérico; resultado de difusor (DEB infinito) | J.2.1, J.2.2 |
| **IV. Impossibility of Closed-Form GLS** | Prueba algebraica: GLS linealiza sii `R(arccos(·))` es monomio; ninguna R "natural" lo cumple salvo cos^m | J.2.3 |
| **V. Hybrid Estimator: GLS-init + Newton Refinement** | m_eff por LSQ; Newton-Riemann en S² con R real; análisis de convergencia (radio de captura); reduce a GLS si R = cos^m | J.2.4 |
| **VI. Choice of Reference Measurement** | β_1 vs β_max vs β_geo; FIM bajo reparametrización no-lineal; régimen óptimo de cada normalización | **J.3 (Q2)** |
| **VII. Optimal Orientation Design for Arbitrary R** | GA con DEB numérico; orientaciones óptimas VCSEL vs. LED estándar; límite del difusor | J.2.5 |
| **VIII. Numerical Study** | DEB y RMSE para 5 emisores × 4 estimadores × 3 normalizaciones; función de K; caso VCSEL detallado | J.4 |
| **IX. Conclusions** | — | — |

**Viabilidad:** Alta — puramente analítico + simulación MATLAB/Python. Sin hardware. Las derivaciones son extensiones directas del TCOM. **~4–5 meses** (ver J.0).

**Target (por orden):**
- **IEEE Transactions on Signal Processing** (IF ~5.4): si el énfasis editorial cae en el resultado de imposibilidad (Sec IV) + híbrido (Sec V) + normalización (Sec VI). TSP valora rigor algebraico y resultados de imposibilidad.
- **IEEE Transactions on Communications (TCOM)** como companion paper natural del TCOM original (mismo grupo de reviewers, extensión obvia, VCSEL atrae a la comunidad de OWC).
- **IEEE Wireless Communications Letters** (4 páginas, rapid): solo si se recorta agresivamente a Sec III + Sec V + caso VCSEL. Sacrifica la sección de normalización, que volvería a ser un letter aparte.

---

### Propuesta L: Deep RL para Selección Adaptativa de Orientaciones en Beam-Steered OWP ⭐⭐ (Conference + Journal Track) 🤖

> **Perfil de investigación:** Esta propuesta es la puerta de entrada al ML profundo en el portfolio OWP. Permite publicar en venues de señal + ML (ICASSP, NeurIPS workshops, IEEE Signal Processing Letters) además de los venues OWC habituales. La implementación es en Python (PyTorch/JAX) — portfolio GitHub directo para empleos en IA.

**Idea central:** La selección de K orientaciones en el TCOM es un diseño offline (GA optimiza antes de instalar). Esta propuesta propone aprender online una **política adaptativa de muestreo**: el agente decide qué orientación medir a continuación en función de todas las mediciones previas del ciclo actual — maximizando la información de Fisher por medición. El resultado: misma precisión que el TCOM con menos mediciones, o mejor precisión con mismo K.

---

#### L.1 Formulación RL del problema de direction finding

**Episodio:** un ciclo de direction finding (K mediciones)

| Componente RL | Definición | Dimensión |
|--------------|-----------|-----------|
| **Estado** `s_t` | Historial: `[(n_{t,1},μ_1), ..., (n_{t,t-1},μ_{t-1})]` + estimación actual `n̂_d^{(t)}` | Variable (t × 4) |
| **Acción** `a_t` | Siguiente orientación `n_{t,t} ∈ S²` (2D en esfera) | 2 (θ, φ) |
| **Recompensa** `r_t` | Ganancia de información: `DEB(t-1) - DEB(t)` o `log det J_t - log det J_{t-1}` | Escalar |
| **Política** `π_θ(a│s)` | Red neuronal que mapea historial → orientación óptima | — |

**Por qué esta recompensa es ideal:** `Δ(log det J)` es la ganancia de información de Fisher — tiene justificación teórica directa y no requiere calcular el RMSE durante entrenamiento.

---

#### L.2 Arquitectura del agente

El historial de mediciones `(n_{t,i}, μ_i)` tiene longitud variable → usar una arquitectura **Transformer o GRU** para codificar el historial:

```
Encoder (Transformer/GRU):  [(n_{t,1},μ_1), ..., (n_{t,t-1},μ_{t-1})]  →  h_t ∈ ℝ^d
Actor (MLP):                 h_t  →  (θ, φ) ∈ [0°,80°] × [0°,360°]
Critic (MLP):                (h_t, a_t)  →  Q-value
```

Algoritmo: **Soft Actor-Critic (SAC)** para acción continua en S² — más estable y eficiente que Q-learning tabular para espacios continuos.

**Alternativa más simple (Propuesta simplificada para conference):**
DQN con acción discretizada: dividir S² en N_grid = 50-100 orientaciones → acción discreta → Q-table neuronal. Más fácil de implementar y explicar.

---

#### L.3 Conexión con resultados analíticos (lo que hace el paper interesante)

**Resultado esperado del agente RL:**
- Tras entrenamiento, el agente aprende a colocar las primeras orientaciones en un patrón de cobertura global (similar al GA del TCOM) y las últimas orientaciones cerca del mínimo esperado (similar a Propuesta I)
- En efecto, el agente "descubre" la estrategia de dos etapas de Propuesta I y la generaliza a K etapas

**Interpretabilidad:** visualizar la política aprendida como secuencia de orientaciones → comparar con:
1. TCOM GA (estático): todas las orientaciones fijadas antes del episodio
2. Propuesta I (dos etapas): K₁ globales + K₂ locales analíticamente derivadas
3. Agente RL (adaptativo): K orientaciones elegidas secuencialmente

**Bound de rendimiento:** el DEB es el bound inferior para cualquier estimador, incluyendo el agente RL. Comparar RMSE del agente vs. DEB permite afirmar si el agente es near-optimal.

---

#### L.4 Extensiones que multiplican las publicaciones

1. **RL + non-Lambertian (Propuesta J+L):** el agente aprende política óptima para R(φ) arbitrario sin necesidad de derivar φ_opt analíticamente → extiende Propuesta I al caso general
2. **RL + multi-LED (Propuesta K+L):** política multi-agente o centralizada para N LEDs → qué LED mide qué orientación a continuación
3. **RL + tracking (Propuesta H+L):** el agente aprende cuándo cambiar de modo acquisition a tracking
4. **Meta-RL:** entrenar en habitaciones variadas → generalización a nuevos entornos sin reentrenamiento

---

#### L.5 Estructura del paper

**Versión conference (6 páginas, ICASSP 2027):**

| Sección | Contenido |
|---------|-----------|
| I. Intro | Limitation of static orientation sets; adaptive sensing as RL problem |
| II. RL formulation | State/action/reward; FIM gain as reward; SAC/DQN algorithm |
| III. Results | RMSE vs. K (adaptive vs. static); comparison with DEB; learned policy visualization |
| IV. Conclusion | |

**Versión journal ampliada (IEEE Trans. Signal Processing):**
Añadir: convergence analysis, interpretation of learned policy, multi-stage generalization, comparison with Propuesta I analytical result.

**Viabilidad:** Alta — solo simulación Python. El simulador OWP es simple (unas líneas de NumPy). La arquitectura SAC es estándar (Stable-Baselines3). El training en GPU es rápido (episodios cortos, baja dimensionalidad).

**Target:** **ICASSP 2027** (deadline ~Sep 2026, IEEE Signal Processing Society — venue ideal para visibilidad ML + signal processing) o **IEEE Signal Processing Letters** (carta rápida 4 páginas).

---

### Propuesta H: Beam Tracking — Mantenimiento de Apuntamiento con Mediciones Mínimas ⭐

**Idea central:** El TCOM repite el K-scan completo en cada ciclo de localización, incluso si el receptor apenas se ha movido. Esta extensión propone una **arquitectura de dos modos**: *Acquisition* (K-scan, igual que el TCOM) y *Tracking* (4 mediciones dithered → actualización de apuntamiento). Una vez que el LED apunta al receptor, el tracking mantiene ese apuntamiento con mucho menos latencia que el K-scan.

---

#### H.1 Arquitectura de dos modos

```
ACQUISITION (K mediciones, ciclo largo)
  → GLS/NLS → n̂_d, d̂
  → Transición a TRACKING cuando ||error|| < umbral

TRACKING (4 mediciones por ciclo, ciclo corto)
  → Pseudo-Quad TX → actualización de dirección
  → Transición a ACQUISITION si tracking falla (pérdida de señal o movimiento brusco)
```

**Ganancia de latencia:** K=9 scan a ~100 Hz (LED con liquid lens) → 90 ms por ciclo. Tracking con 4 mediciones → 40 ms por ciclo. Para movimientos lentos, el tracking reduce la latencia 2–3×.

---

#### H.2 El rastreo "Pseudo-Quad TX": tracking sin hardware extra en el receptor

La idea clave es replicar el principio del Quad-PD (cuatro cuadrantes que dan señal diferencial de desalineación) pero **en el lado del transmisor**, sin modificar el receptor:

Dado el estimado actual `n̂_d^(t)`, calcular dos vectores ortogonales en el plano tangente de S²: `e₁, e₂ ∈ T_{n̂_d}S²`. Crear 4 orientaciones dithered:

```
n_t^(+1) = norm(n̂_d + δ·e₁),  n_t^(-1) = norm(n̂_d - δ·e₁)
n_t^(+2) = norm(n̂_d + δ·e₂),  n_t^(-2) = norm(n̂_d - δ·e₂)
```

Medir potencias `p_{+1}, p_{-1}, p_{+2}, p_{-2}`. Las **señales diferenciales** son:

```
ε₁ = p_{+1} - p_{-1}  ≈  2δ · ∂p/∂(e₁ dirección) · ||grad||
ε₂ = p_{+2} - p_{-2}  ≈  2δ · ∂p/∂(e₂ dirección) · ||grad||
```

Si `n̂_d = n_d` (apuntado perfecto): `ε₁ = ε₂ = 0` (máximo de potencia, gradiente nulo).
Si `n̂_d ≠ n_d`: `(ε₁, ε₂)` apunta hacia `n_d` en el espacio tangente.

**Regla de actualización geodésica:**

```
n̂_d^(t+1) = Exp_{n̂_d^(t)}(α · (ε₁·e₁ + ε₂·e₂))   →   normalizar a S²
```

donde `Exp` es el mapa exponencial sobre la esfera y `α` es el step size (determinístico o adaptivo). Solo **4 mediciones** y **O(1) operaciones** por ciclo de tracking.

**Ventajas vs. Quad-PD físico:**
- Sin hardware extra en el receptor
- Usa el mismo LED beam-steered ya presente
- Naturalmente compatible con liquid lenses (dithering eléctrico de alta frecuencia)
- El modelo es el mismo `μ_i = η·R(φ_i)` del TCOM

---

#### H.3 Extensión con filtro de Kalman en S²

Para receptores con movimiento predecible (velocidad constante), el filtro de Kalman sobre la variedad S² mejora el tracking:

- **Estado:** `[n_d, ω_d]` donde `ω_d ∈ T_{n_d}S²` es la velocidad angular (4 DoF total en TS²)
- **Predicción:** paso geodésico `n_d(t+1|t) = Exp_{n_d(t)}(ω_d(t)·Δt)`
- **Actualización:** las señales diferenciales `(ε₁, ε₂)` actualizan el estado
- **Beneficio:** reduce a 1–2 mediciones por ciclo con buen modelo de movimiento

**Umbral de seguimiento:** el tracking es estable si la velocidad angular del receptor `||ω_d|| < δ / Δt` (el movimiento por ciclo cabe dentro de la zona de captura del dithering). Derivar esta condición es una contribución teórica del paper.

---

#### H.4 Estructura del paper (Conference)

| Sección | Contenido |
|---------|-----------|
| I. Intro | Limitación de latencia del K-scan TCOM; motivación del tracking |
| II. System Model | Modelo TCOM + extensión de modos acquisition/tracking |
| III. Pseudo-Quad TX | Derivación del estimador diferencial; relación con gradiente del MLE perfilado |
| IV. Análisis de convergencia | Radio de captura, condición de estabilidad, velocidad máxima trackable |
| V. KF en S² | Modelo de movimiento + filtro de Kalman geodésico |
| VI. Resultados | Latencia, error de tracking vs velocidad del receptor, comparación KF vs sin KF |
| VII. Conclusión | |

**Viabilidad:** Alta — reutiliza LED/liquid lens del TCOM. No requiere hardware extra. Las 4 mediciones dithered son una modificación mínima del firmware de steering.

**Target:** GLOBECOM 2026 Workshop o PIMRC 2026 — topic *Beam Management*, *Optical Wireless Tracking*, *Low-Latency Localization*.

---

### Propuesta I: Estimación en Dos Etapas con Orientaciones Adaptativas ⭐⭐

**Idea central:** El TCOM usa un único set de K orientaciones diseñadas para cobertura global del hemisferio. Esta extensión propone dividir el escaneo en **dos etapas secuenciales con K₁+K₂ = K total mediciones**: la primera etapa hace una estimación gruesa de `n_d` con orientaciones ampliamente distribuidas; la segunda etapa usa ese conocimiento para concentrar K₂ orientaciones en la zona de máxima información de Fisher, obteniendo un DEB significativamente menor que con K orientaciones globales.

---

#### I.1 Fundamento teórico: ángulo óptimo para máxima información

De la FIM del TCOM, la información de Fisher aportada por la orientación `n_{t,i}` depende del ángulo `φ_i = arccos(n_{t,i}·n_d)`. Para Lambertiano `R(φ) = cos^m(φ)`:

```
J_i(n_d) ∝ m² · cos^{2(m-1)}(φᵢ) · sin²(φᵢ)
```

Esta cantidad tiene un **máximo en φ_opt** que satisface:

```
∂J_i/∂φᵢ = 0   →   cos²(φ_opt) = (m-1)/m   →   φ_opt = arccos(√((m-1)/m))
```

Para `m=1`: φ_opt = 90° (perpendicular). Para `m=2`: φ_opt ≈ 45°. Para `m=5` (LED típico): φ_opt ≈ 26°.

En el set global de K orientaciones del TCOM, solo algunas caen cerca de φ_opt — la mayoría contribuyen subóptimamente. En la segunda etapa, **todas** K₂ orientaciones se colocan exactamente a φ_opt de `n̂_d^(1)`.

---

#### I.2 Diseño de la segunda etapa

Dado `n̂_d^(1)` (estimación gruesa), el set óptimo de K₂ orientaciones de segunda etapa es:

```
n_{t,k}^(2) = Rot(n̂_d^(1), φ_opt) · Rot(ẑ, 2πk/K₂)  para k = 0, ..., K₂-1
```

Es decir, K₂ orientaciones sobre un cono de semi-ángulo φ_opt centrado en `n̂_d^(1)`, uniformemente espaciadas en azimut. Con K₂=3 y espaciado 120°, la FIM de la segunda etapa es **isotrópica** en el plano tangente T_{n_d}S² — ninguna dirección angular se privilegia.

El estimador de segunda etapa combina ambas etapas:

```
n̂_d^(2) = GLS/NLS({mediciones₁, mediciones₂}, {n_{t,1..K₁}, n_{t,1..K₂}^(2)})
```

---

#### I.3 Análisis de ganancia teórica

| Configuración | # Mediciones | FIM por medición | DEB esperado |
|---------------|-------------|-----------------|--------------|
| TCOM K=9 global | 9 | Promedio (varias φᵢ) | Referencia |
| Dos etapas K₁=5, K₂=4 | 9 | K₂ al máximo teórico | < referencia |
| Dos etapas K₁=3, K₂=3 | 6 | K₂ al máximo teórico | ≈ referencia con 33% menos mediciones |

**Pregunta de investigación:** ¿Qué combinación (K₁, K₂) minimiza el DEB total con K₁+K₂ = K fijo? ¿Cómo afecta el error de la primera etapa al diseño de la segunda?

**Error de propagación:** Si `n̂_d^(1)` tiene error angular `Δθ₁`, las orientaciones de segunda etapa se colocan a φ_opt + O(Δθ₁) del verdadero `n_d`. El impacto sobre J₂ es de segundo orden para errores pequeños:

```
J₂(Δθ₁) ≈ J₂(0) · (1 - (∂²J/∂φ²)|_{φ_opt} · Δθ₁² / 2)
```

Para K₁ ≥ 3 con orientaciones globales, `Δθ₁` es típicamente < 5° → impacto < 2% en J₂.

---

#### I.4 Conexión con otras propuestas

- **Propuesta H (Tracking):** La segunda etapa puede funcionar como "micro-tracking" para posiciones estáticas o cuasi-estáticas → combinar con tracking para sistema completo de adquisición fina.
- **Propuesta F (K-only):** La estimación de `η̂` mejora cuando los K₂ de segunda etapa están cerca de n_d (mayor SNR de potencia) → mejor distancia estimada.
- **Propuesta C (Non-Lambertiano):** φ_opt cambia con `R(φ)` real → el diseño de segunda etapa se adapta al patrón calibrado.

---

#### I.5 Estructura del paper (Conference)

| Sección | Contenido |
|---------|-----------|
| I. Intro | Limitación del diseño global: orientaciones subóptimas para el ángulo de mayor información |
| II. FIM y ángulo óptimo | Derivar φ_opt del TCOM; visualización de J(φ) |
| III. Estimación en dos etapas | Diseño del Stage 2 set; estimador combinado; error de propagación |
| IV. Análisis teórico | DEB de dos etapas vs. single-stage (mismo K total); condición de mejora |
| V. Simulación | DEB vs. K₁, K₂; comparación con TCOM single-stage; robustez a error Stage 1 |
| VI. Conclusión | |

**Viabilidad:** Alta — puramente analítico y simulado. No requiere hardware nuevo. Las derivaciones extienden directamente el TCOM (misma FIM, mismos estimadores, nueva estrategia de selección).

**Target:** PIMRC 2026 Workshop o WCNC 2027 — topic *Adaptive Sensing*, *Sequential Localization*, *Optical Wireless Positioning*.

---

### Propuesta M: Transfer Learning para OWP — Colaboración Cambridge (Haas Lab) ⭐⭐⭐ (Journal Track — TCOM/JSAC) 🤖⚡

> **Contexto:** Pasantía de 3 meses en el lab de Harald Haas e Iman Tavakkolnia (Cambridge / Univ. Edinburgh). Haas es el creador del concepto LiFi y su grupo es la referencia mundial en OWC/OWP. Un paper co-authored con este grupo tiene visibilidad inmediata en toda la industria LiFi (pureLiFi, signify, Nokia Bell Labs, Huawei). **Esta es probablemente la publicación de mayor impacto de toda la tesis.**

**Idea central:** El TCOM provee un modelo físico exacto del canal OWP (`μ_i = η·R(φ_i)`). En deployment real, los parámetros del canal (η, R, ruido) varían entre habitaciones, LEDs y condiciones. Transfer Learning usa el conocimiento del modelo físico (TCOM) como **prior inductivo** para adaptar un estimador entrenado en simulación/lab-origen a un entorno destino con pocos datos de calibración — sin reentrenamiento completo.

---

#### M.1 Escenarios de transferencia relevantes

| Escenario | Dominio origen | Dominio destino | Relevancia |
|-----------|---------------|-----------------|------------|
| **Sim-to-real** | Simulador TCOM (Python, parámetros perfectos) | Hardware Cambridge (LEDs reales, ruido real) | Alto — valida el TCOM en entorno externo |
| **Cross-room** | Habitación LISV (UVSQ) | Habitación Cambridge | Alto — generalización geográfica |
| **Cross-LED** | LED Lambertiano calibrado | LED diferente / no-Lambertiano | Alto — conecta con Propuesta J |
| **Cross-K** | Entrenado con K=9 | Desplegado con K=5 | Medio — eficiencia de medición |

---

#### M.2 El prior físico como ventaja de transferencia

La FIM del TCOM define la estructura de la información en el canal OWP. Esta estructura es **independiente de los parámetros específicos** (`η`, `σ²`, `m`) — solo depende de la geometría. Usarla como regularización en el TL:

```
L_total = L_tarea(θ) + λ · L_física(θ)

donde L_física penaliza estimadores que violan la estructura FIM
(e.g., que no son equivariantes bajo rotaciones de n_d)
```

**Resultado esperado:** con el prior físico, el TL necesita 5–10× menos datos de calibración en el dominio destino para alcanzar el mismo error que TL sin prior. Esta es la **contribución cuantificable** del paper.

---

#### M.3 Conexión con Propuesta L (Meta-RL)

El Meta-RL (MAML, Reptile) es la versión RL del transfer learning:
- **Entrenar** el agente de Propuesta L en N habitaciones/configuraciones distintas (simuladas)
- **Few-shot adaptation**: con K mediciones en la habitación destino, el meta-agente adapta su política
- **Resultado**: el agente "sabe cómo aprender a posicionarse" en cualquier habitación nueva

Esto unifica Propuesta L + M en un único framework: **Meta-RL con prior físico para OWP generalizable**.

---

#### M.4 Plan para la pasantía

| Mes | Actividad |
|-----|-----------|
| **Antes de ir** | Construir simulador Python (Propuesta L) basado en TCOM; documentar bien para compartir con Cambridge |
| **Mes 1** | Adaptar el simulador al setup de Cambridge; recopilar datos reales del lab Haas; caracterizar el gap sim-to-real |
| **Mes 2** | Implementar TL/Meta-RL con prior físico; comparar: sin TL / TL estándar / TL+prior TCOM; escribir resultados |
| **Mes 3** | Redacción del paper con Tavakkolnia/Haas; submission o pre-print en arXiv |

**Clave logística:** llegar con el simulador Python funcionando (Propuesta L) y la teoría del prior físico clara (derivada de la FIM del TCOM). Maximizar el tiempo en Cambridge para datos reales y co-authoring.

---

#### M.5 Estructura del paper

| Sección | Contenido |
|---------|-----------|
| I. Intro | Gap: modelos OWP no generalizan; motivación TL; contribución del prior físico |
| II. System Model | TCOM channel model; dominio origen/destino; definición de transferencia |
| III. Prior físico FIM | Derivación del regularizador basado en FIM; invariancias geométricas |
| IV. Framework TL | Arquitectura; loss function; Meta-RL extension (MAML) |
| V. Sim-to-real | Experimento Cambridge: simulador → hardware real; gap de calibración con/sin prior |
| VI. Cross-room / Cross-LED | Transferencia entre habitaciones; conexión con Propuesta J |
| VII. Conclusión | |

**Viabilidad:** Muy alta — la teoría es extensión directa del TCOM; el simulador Python lo construyes antes (Propuesta L); Cambridge provee el hardware real y el co-authorship.

**Target:** **IEEE Journal on Selected Areas in Communications (JSAC)** — el venue más prestigioso para este tipo de trabajo (IF ~13). Alternativa: IEEE TCOM companion o **NeurIPS Workshop on Machine Learning for Physical Sciences**.

---

### Propuesta N: Modelo ML Condicionado en Patrón de Radiación — OWP Universal Cross-LED 🤖

> **Paper standalone, simulación.** Esta propuesta resuelve la limitación más práctica de los modelos ML para OWP: típicamente se entrenan para UN LED específico y no generalizan a otros. Aquí se entrena un modelo único condicionado en el patrón de radiación `R(φ)` que se despliega con cualquier LED sin reentrenamiento — un "modelo universal" para OWP single-LED.

**Idea central:** Entrenar un modelo `f_θ` cuyo input no son solo las mediciones RSS `{μ_i, n_{t,i}}` sino también una representación del patrón de radiación `R(φ)` del LED en uso. La salida es la posición 3D `r̂`. En training, se muestrean aleatoriamente patrones de un banco de datasheets (Lumileds, Cree, OSRAM) → el modelo aprende a explotar el patrón como información lateral. En deployment, basta con cargar el `R(φ)` del LED instalado (de su datasheet) y el modelo funciona sin reentrenamiento.

---

#### N.1 Arquitectura

```
Pattern encoder:    R(φ) muestreado en N_φ ángulos  →  e_R ∈ ℝ^{d_pattern}
                    (MLP o set encoder sobre los muestreos)

Measurement encoder: {(μ_i, n_{t,i})}_{i=1..K}        →  h_meas ∈ ℝ^{d_meas}
                    (Set transformer / DeepSets — permutation invariant)

Conditioning:       FiLM(h_meas, e_R)                  →  h_cond
                    (γ, β = MLP(e_R); h_cond = γ·h_meas + β)

Position head:      h_cond                              →  r̂ ∈ ℝ³
```

**Por qué FiLM:** Feature-wise Linear Modulation es la forma estándar de condicionar redes con información lateral. Permite que el patrón module la representación de las mediciones sin requerir que el patrón se concatene como input plano (lo que llevaría a sobreajuste).

**Permutation invariance:** las K mediciones son un conjunto desordenado (cuando K se diseña offline). Set transformer / DeepSets garantiza que el output no depende del orden → menos parámetros, mejor generalización.

---

#### N.2 Banco de patrones para entrenamiento

Combinar tres fuentes:

| Fuente | Cantidad | Tipo |
|--------|---------|------|
| Datasheets reales | ~20–30 | LEDs comerciales (Lumileds Luxeon, Cree XLamp, OSRAM Oslon, etc.) |
| Lambertianos sintéticos | ~10 | `cos^m(φ)` con m ∈ {1, 2, 5, 10, 20, 50, 100} |
| Patrones extremos | ~5 | Gaussiano (VCSEL), uniforme (difusor), asimétrico (lente cilíndrica) |

**Augmentation:** rotaciones azimutales, scaling, ruido en las muestras del patrón → el modelo se vuelve robusto a errores de calibración del datasheet.

---

#### N.3 Comparaciones que hace el paper interesante

| Comparación | Pregunta científica |
|-------------|---------------------|
| **f_θ universal vs. f_θ_LED1** | ¿Cuánto pierde el modelo universal vs. uno entrenado para un LED específico? |
| **f_θ universal vs. GLS_TCOM** | ¿Supera al estimador clásico cuando el patrón no es Lambertiano? |
| **f_θ universal vs. NLS calibrado** | ¿El modelo aprende algo que NLS no puede capturar? |
| **Out-of-distribution: VCSEL** | ¿El modelo entrenado en patrones "normales" generaliza a patrones extremos no vistos? |
| **Robustez a ruido en R(φ)** | ¿Qué pasa si el patrón cargado tiene 5%/10%/20% de error? |

**Resultado clave esperado:** el modelo universal está dentro de ~1–2 dB del modelo especializado en cada patrón, pero generaliza a 30+ LEDs sin reentrenamiento. NLS especializado lo supera para cada patrón pero requiere recalibración cara para cada LED nuevo.

---

#### N.4 ¿Simulación o experimental?

**Recomendación: simulación pura para el paper base (N₁), experimental como extensión (N₂).**

| Versión | Datos | Esfuerzo | Aporte |
|---------|-------|---------|--------|
| **N₁ (simulación)** | RSS sintético generado del modelo TCOM con cada `R(φ)` del banco | 2–3 meses | Paper completo: prueba el concepto, generaliza a 30+ patrones |
| **N₂ (extensión exp.)** | Validación con 2–3 LEDs reales del LISV de patrones distintos | +2 meses | Sección experimental que valida sim-to-real; refuerza para journal |

**N₁ ya es publicable** porque las datasheets son la realidad — no son "datos sintéticos" arbitrarios. La crítica "esto no funciona en hardware real" se mitiga argumentando que los patrones son los que vienen de la realidad de los LEDs comerciales.

**N₂ sería ideal pero no necesario** para un Conference o SP Letters. Para un Journal sí conviene tener al menos 1–2 LEDs experimentales.

---

#### N.5 Conexión con otras propuestas

- **vs. E (residual correction):** E corrige GLS para UN patrón conocido. N maneja patrones arbitrarios. Son ortogonales — incluso podrían combinarse (corrector residual condicionado en patrón).
- **vs. J (framework teórico no-Lambertiano):** J deriva el MLE/bound para `R(φ)` arbitrario. N aprende ese MLE con NN. J da el bound de referencia.
- **vs. M (Transfer Learning Cambridge):** N es generalización **intra-distribución** (patrones del banco). M es generalización **out-of-distribution** (sim-to-real, cross-room). Son complementarias y forman parejas naturales en el discurso.

---

#### N.6 Estructura del paper

| Sección | Contenido |
|---------|-----------|
| I. Intro | Limitación de modelos ML específicos a un LED; motivación universal |
| II. Problem formulation | OWP con `R(φ)` arbitrario; modelo del canal; banco de patrones |
| III. Architecture | FiLM conditioning; pattern encoder; set transformer measurements |
| IV. Training | Sampling estratificado de patrones; augmentation; loss |
| V. Resultados sim | Universal vs. especializado; OOD a VCSEL; robustez a ruido en R(φ) |
| VI. Experimental (opc.) | 2–3 LEDs reales del LISV; sim-to-real gap |
| VII. Conclusión | |

**Viabilidad:** Alta — simulador Python (parte del simulador de Propuesta L, reutilizable). FiLM y set transformer son estándar en PyTorch. Banco de patrones es público (datasheets). ~3 meses para versión simulación.

**Target:** **IEEE Transactions on Communications** (TCOM, companion natural — generaliza el TCOM a cualquier LED) o **IEEE Internet of Things Journal** (positioning + ML aplicado, IF ~10). Alternativa conference: ICASSP 2027.

---

## 4. Recomendación de Estrategia (actualizado 26 Mayo 2026)

### ⭐⭐⭐ PIPELINE PRIORITARIO: F → V

> **Contexto:** Ya se envió un paper a GLOBECOM conference con validación experimental del TCOM cooperativo (PD controlado en K+1). El pipeline prioritario extiende esto en dos pasos directos.

#### Paso 1: Propuesta F → GLOBECOM 2026 Workshop (deadline 12 Ago)

- **Qué:** Derivación analítica + simulación de la arquitectura broadcast K-only (sin K+1 cooperativo)
- **Esfuerzo:** 2–3 meses (simulación pura)
- **Riesgo:** Bajo

#### Paso 2: Propuesta V → Journal (TCOM companion o JLT)

- **Qué:** Validación experimental de TCOM+F con el testbed 3D, incluyendo corrección del patrón quasi-Lambertiano del LED real
- **Relación:** Extensión journal del GLOBECOM (ya enviado) + F (por enviar)
- **Esfuerzo:** 3–4 meses experimentales + 1–2 meses redacción
- **Riesgo:** Bajo (testbed disponible, framework analítico del TCOM reutilizable)

---

### Plan de ejecución paso a paso

| # | Paso | Timeline | Entregable |
|---|------|----------|------------|
| 1 | **F: Simulación K-only** — Derivar η̂ estimator, PEB K-only, MC comparativa | May–Jul 2026 | Manuscrito GLOBECOM WS |
| 2 | **F: Submit GLOBECOM** | **12 Ago 2026** | Paper enviado |
| 3 | **V-a: Medir R(φ)** del LED real — fijar PD, rotar LED en φ conocidos, registrar potencia | Ago–Sep 2026 | Tabla R(φ) + spline cúbico + m_eff |
| 4 | **V-b: NLS calibrado** — reemplazar cos^m por R_spline en cost function del NLS | Sep 2026 | Código NLS calibrado (cambio mínimo) |
| 5 | **V-c: Validación experimental 3D** — K-only (F) + cooperativo (TCOM) con 4 escenarios | Sep–Nov 2026 | Datos experimentales completos |
| 6 | **V-d: Redacción journal** | Nov–Dic 2026 | Manuscrito TCOM/JLT |
| 7 | **V: Submit Journal** | **Dic 2026–Ene 2027** | Paper enviado |

---

### Los 4 escenarios experimentales de V (columnas de la tabla de resultados)

| Escenario | Direction Finding | Distance Recovery | Qué demuestra |
|-----------|-------------------|-------------------|-----------------|
| **S1:** GLS + cos^m(φ) nominal | Bias por mismatch | Bias en η̂ → error en d̂ | Baseline teórico vs. realidad |
| **S2:** GLS + cos^{m_eff}(φ) | Bias reducido | Bias reducido | Mejora simple (1 parámetro) |
| **S3:** NLS + R_spline(φ) calibrado | **Sin bias** | **Sin bias** en η̂ | Corrección completa model-based |
| **S4:** DEB/PEB numérico con R_spline | Bound correcto | Bound correcto | Referencia teórica real |

> **Contribución clave de V:** No es solo validación (GLOBECOM ya lo hizo con PD controlado). V añade: (i) arquitectura broadcast K-only experimental, (ii) diagnóstico + corrección del mismatch quasi-Lambertiano sin ML, y (iii) cuantificación del gap teoría-experimento con 4 escenarios.

---

### Cómo medir R(φ) con el testbed existente (Paso V-a)

No requiere goniómetro dedicado. Se puede usar el propio testbed:

1. **Fijar el PD** en una posición conocida, orientado verticalmente (n_r = [0,0,1])
2. **Colocar el LED** a distancia conocida d, apuntando directamente al PD (φ = 0)
3. **Rotar el gimbal** del LED en pasos de 2–5°, registrando potencia recibida vs. ángulo de tilt
4. **Normalizar**: R(φ) = P_r(φ) / P_r(0)
5. **Ajustar spline**: `R_spline = spline(phi_meas, R_meas)`
6. **Ajustar m_eff**: `m_eff = argmin_m ||log(R_meas) - m*log(cos(phi_meas))||`

> **Tiempo estimado:** 1–2 sesiones de laboratorio (< 1 semana).

---

### Cómo implementar NLS calibrado (Paso V-b)

Cambio mínimo en el código NLS del TCOM:

```matlab
% TCOM original (1 línea a cambiar en el residual):
residual_i = eta * max(0, dot(n_t_i, v))^m - p_i;

% NLS calibrado:
phi_i = acos(max(-1, min(1, dot(n_t_i, v))));
residual_i = eta * ppval(R_spline, phi_i) - p_i;
```

Para la estimación de η (distancia K-only, Propuesta F):

```matlab
% Original:
eta_hat = sum(mu_hat .* Q.^m) / sum(Q.^(2*m));

% Calibrado:
R_vals = ppval(R_spline, acos(Q));
eta_hat = sum(mu_hat .* R_vals) / sum(R_vals.^2);
```

> **Tiempo estimado:** 1–2 días de implementación + verificación.

---

### Estructura tentativa del paper V (Journal)

| Sección | Contenido |
|---------|-----------|
| I. Intro | TCOM (teoría) + GLOBECOM (validación cooperativa) → este paper: K-only broadcast + calibración NL |
| II. System Model | Recap TCOM + Propuesta F (K-only η̂, d̂ sin K+1) |
| III. Quasi-Lambertian Characterization | Medición R(φ); ajuste m_eff; spline; DEB numérico con R_spline |
| IV. Calibrated Estimators | GLS(m_eff), NLS(R_spline), η̂ calibrado para broadcast |
| V. Experimental Setup | Testbed, protocolo, ground truth |
| VI. Results | 4 escenarios (S1–S4); direction finding + 3D positioning; gap analysis |
| VII. Conclusion | |

**Target journal (por orden):**
- **IEEE Trans. Communications (TCOM)** — companion natural del paper base; valida + extiende
- **IEEE/OSA J. Lightwave Technology (JLT)** — si el énfasis cae en la caracterización óptica
- **IEEE Photonics Journal** — si se prioriza rapidez de review

---

### Relación V vs. C vs. J (para evitar confusión)

| Aspecto | **V** (prioritario) | **C** (deep experimental) | **J** (deep teórico) |
|---------|---------------------|---------------------------|-----------------------|
| R(φ) | Medido, spline, m_eff | Medido + goniómetro + azimut 2D | Arbitrario paramétrico |
| Estimadores | GLS(m_eff) + NLS(R_spline) | + GLS+Newton Riemanniano | + prueba imposibilidad GLS |
| DEB | Numérico con R_spline | Numérico + GA re-optimizado | FIM generalizada cerrada |
| Experimental | Sí (testbed 3D) | Sí (goniómetro + testbed) | No (solo simulación) |
| Complejidad | ★★☆ | ★★★★ | ★★★ |
| Profundidad NL | Pragmática (corregir mismatch) | Completa (4 estimadores) | Fundamental (imposibilidad) |
| Esfuerzo | 3–4 meses | 6–8 meses | 4–5 meses |

> **V es suficiente y autocontenido como journal paper.** C y J son extensiones más profundas del tema NL que pueden hacerse después si se quiere explotar la línea. V NO requiere C ni J como prerequisito.

---

### Plan combinado completo (actualizado 26 Mayo 2026)

| Timeline | Acción | Prioridad |
|----------|--------|-----------|
| **May–Jul 2026** | **Propuesta F** (K-only simulación) para GLOBECOM WS | ⭐⭐⭐ |
| **12 Ago 2026** | **Submit F** a GLOBECOM WS | ⭐⭐⭐ |
| **Ago–Sep 2026** | **V-a:** Medir R(φ) del LED + ajustar spline/m_eff | ⭐⭐⭐ |
| **Sep 2026** | **V-b:** Implementar NLS calibrado + η̂ calibrado | ⭐⭐⭐ |
| **Sep–Nov 2026** | **V-c:** Validación experimental completa (4 escenarios) | ⭐⭐⭐ |
| **Nov–Dic 2026** | **V-d:** Redacción journal | ⭐⭐⭐ |
| **Dic 2026–Ene 2027** | **Submit V** a TCOM/JLT | ⭐⭐⭐ |
| **Ene–Feb 2027** | **H-a:** Implementar Pseudo-Quad TX (4 orientaciones dithered) | ⭐⭐⭐ |
| **Feb–Mar 2027** | **H-b:** Experimento tracking dinámico (receptor móvil a velocidad conocida) | ⭐⭐⭐ |
| **Mar–Abr 2027** | **H-c:** Filtro de Kalman en S² + análisis de convergencia | ⭐⭐⭐ |
| **Abr–May 2027** | **H-d:** Redacción + submit journal o ICC/WCNC 2027 | ⭐⭐⭐ |
| **Sep–Oct 2026** | En paralelo: **Propuesta L** (RL, Python) para ICASSP 2027 | ⭐⭐ |
| **Oct 2026** | En paralelo: **Propuesta A** (ISAC) para ICC/WCNC 2027 | ⭐ |
| **2027+** | Papers profundos: J, C, K según disponibilidad | ⭐ |

---

## 5. Notas sobre Formato

- **PIMRC workshop papers:** Típicamente 5–6 páginas IEEE format
- **GLOBECOM workshop papers:** 6 páginas (5 + 1 overlength con cargo)
- **ICC/WCNC symposium papers:** 6 páginas
- Todos en formato IEEE conference (2 columnas)
- No debe haber overlap significativo con el TCOM (>30% nuevo contenido requerido)

---

## 6. Relevancia por Track/Symposium

### PIMRC 2026
- Track relevante: *Localization and Positioning*, *PHY Layer and Waveform Design*, *Cooperative Communications*

### GLOBECOM 2026 (Macau)
- Symposium: *Optical Networks and Systems (ONS)* o *Signal Processing for Communications (SPC)*
- Workshop: buscar workshops de *OWC*, *ISAC*, o *6G Sensing and Communications*
- El workshop WS-01 "7th Workshop on Emerging Topics in 6G Communications" podría encajar

### ICC/WCNC 2027
- SAC Track: *Optical Wireless Communications*
- Symposium: *Signal Processing for Communications* o *Communication Theory*
