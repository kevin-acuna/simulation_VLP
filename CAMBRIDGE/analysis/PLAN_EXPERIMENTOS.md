# Plan de experimentos: VLP 3D con un LED fijo y un PD reorientable (testbed Cambridge)

*Elaborado el 17/10/2026, a partir de los datos y análisis de `analysis/`, `demo/`,
`database_acquisition/`, `simulations/` y `ExpValidation_Journal/`.*

---

## 0. Resumen ejecutivo

**Afirmación central del paper 1.** Con un único LED fijo y un único PD que se reorienta a K
orientaciones conocidas, se estima la posición 3D a escala de centímetros en todo el volumen de
trabajo. El método está validado frente a ground truth trazable, con separación estricta entre
calibración y test, y se compara con la cota teórica (PEB). Además, se caracteriza qué pasa cuando
las hipótesis no se cumplen: menos orientaciones, orientaciones con error, orientaciones bloqueadas
y menos puntos de calibración.

**Regla de diseño.** Primero se adquiere **un dataset maestro, regular y rico**, con K = 10 y
registros largos. Casi todas las preguntas (K mínimo, puntos de calibración, sensibilidad a errores
de orientación y oclusiones) se responden **offline** sobre ese dataset. Solo se hacen
experimentos físicos para lo que no se puede emular: geometría real del tilt, orientaciones
arbitrarias conocidas, nivel de señal real con el PD bloqueado y repetibilidad.

**Este fin de semana (≈ 40 h de máquina):**

| Orden | Experimento | Duración | ¿Hace falta alguien presente? |
|---|---|---|---|
| 1 | E0: metrología del ground truth e inspección mecánica | 1.5 h | Sí |
| 2 | E3: identificación del modelo del tilt del MTRS (±3°) | ≈ 2 h | Al inicio |
| 3 | **E1: rejilla 3D maestra** (196 posiciones, K = 10), sábado por la noche | ≈ 15 h | No (auto-resume) |
| 4 | E5: señal real con el PD bloqueado y suelo de ruido | ≈ 1 h | Sí |
| 5 | E4: orientaciones arbitrarias conocidas (tilt aleatorio) | ≈ 2.5 h | No |
| 6 | E2: repetibilidad y ruido (subconjunto con más registros) | ≈ 1.7 h | No |
| 7 | E8: test ciego con posiciones aleatorias (demo), domingo por la noche | ≈ 13 h | No |

**Para la reunión con el asesor:** demo en vivo, cuatro figuras ya disponibles (125 posiciones con
3.9 cm, error frente a K, el VLP detectando la escala Z del gantry y el test aleatorio con 3.3 cm),
este plan y tres decisiones a pedirle (sección 8).

---

## 1. Qué tenemos ya

| Dataset | Condiciones | Resultado / uso | Limitaciones |
|---|---|---|---|
| `RSS_Distribution/points.csv` (`campaign_20261013-182008_grid141x141x1-xy0to1400-s10-z-300_K1-off65_pd0_tilt0_100ms`) | PD plano (adaptador 0°), K = 1, rejilla de 10 mm en 1400 × 1400 mm, z = −300, 4 LEDs | Mapa de RSS denso, calibración del LED | Una sola altura |
| `Lambertian_order_LED_500khz/points.csv` | El mismo barrido recortado | A, m y posición XY del LED (281.1, 904.8) | Una sola altura: el m aparente cambia con la distancia |
| `campaign_20261014-185628_grid5x5x2-xy100to1300-s300-z-600to-300_K10-off65_pd15_tilt0_100ms` + `campaign_20261015-000723_grid5x5x3-xy100to1300-s300-z-200to0_K10-off65_pd15_tilt0_100ms` | Adaptador 15°, K = 10 (65 + 36k), rejilla de 5 × 5 en XY con paso de 300 mm, 5 alturas, 1 muestra de 100 ms | **125 posiciones: 3.9 cm de media** (3.66 cm con el LED en 281.1, 904.8), sin fallos; con K = 5, 4.0 cm; con K = 3, 5.2 cm | Paso grueso; una muestra (sin estimar ruido); el offset se ajusta con los propios datos |
| `demo/data/demo_20261016-113422_random-xy100to1300-z-600to0_K5-off65_pd15_tilt0_100ms` | Posiciones aleatorias, K = 5 | **Puntos 1–47: 3.28 cm de media** (mediana 3.36, P90 5.74) | Desde el punto 48 el tilt del MTRS se fue solo a ~3° (incidente) |
| `demo/data/demo_20261016-103131_random-xy100to1300-z-600to0_K5-off66p5_pd15_tilt0_100ms` | Posiciones aleatorias, K = 5, 13 puntos | 5.4 cm de media | Un punto con 19.6 cm sin explicar |
| `Frecuency_Response/` | Barrido de 5 kHz a 1 MHz | Respuesta del enlace | — |

**Resultados que ya son publicables:**

1. **SQ ≫ cos^1.9 ≫ cos** como respuesta del PDA100A2: la prueba de forma de las K RSS no depende
   de A ni de m.
2. **GLS ≈ NLS** y WLS es peor, como predice la teoría.
3. **El propio VLP detectó la mala escala del eje Z del gantry** (0.63–0.65 estimado contra 0.6
   medido con cinta) antes de medirla. Es una demostración de autoconsistencia muy convincente.
4. **K = 5 rinde prácticamente como K = 10.** Con K = 3 funciona, pero sin redundancia.
5. **Integridad:** en el incidente del 16/10, el residuo de ajuste de la forma subió del 0.77 % al
   3 % al aparecer un error de actitud de ~3°. Es decir, el algoritmo puede **detectar** que sus
   orientaciones están mal.

---

## 2. Brechas que señalaría un revisor (y cómo se cierran)

| # | Brecha | Por qué importa | Cómo se cierra |
|---|---|---|---|
| G1 | Ground truth en Z con una única medida con cinta (s_z = 0.6) | Todo el error vertical depende de esto | **E0**: medir la altura real del PD en cada nivel de z, con repeticiones e incertidumbre |
| G2 | Calibración y test no separados: el offset, el LED y A, m se ajustan con los mismos datos que se evalúan | Riesgo de sobreajuste; un revisor lo detecta enseguida | **Protocolo congelado** (sección 3): se calibra con los datos del 13–15/10 y se testea con los del fin de semana |
| G3 | Una sola muestra por orientación: no hay estimación de σ | Sin σ no hay comparación honesta con PEB/CRLB | Registros de 300 ms divisibles en 3 × 100 ms (E1) y E2 con más registros |
| G4 | Rejilla de 5 × 5 con paso de 300 mm | Pocos puntos para mapas espaciales y para estudiar la calibración | **E1**: 7 × 7 × 4 con paso de 200 mm, que comparte puntos con la rejilla antigua |
| G5 | Sesgo vertical residual (de +0.5 a −2.3 cm con la altura): el modelo cos^m del LED falla con la distancia | Es el error dominante tras corregir la geometría | Analizar E1 por alturas; **E7** (PD plano a otras alturas) para un modelo del LED dependiente de la distancia, como spline o PINN |
| G6 | No se conoce cómo inclina el tilt del MTRS las normales (incidente del 16/10) | No se pueden usar orientaciones con tilt ni explicar el incidente | **E3** |
| G7 | La robustez a orientaciones imperfectas está afirmada, no demostrada | Es la propiedad clave para IMU, dron y ADR | **E4** (físico) + **A5** (offline sobre E1) |
| G8 | La robustez a oclusiones no está demostrada | Reclamo atractivo, aún sin evidencia | **E5** (nivel real con el PD bloqueado) + **A4** (offline) |
| G9 | Repetibilidad entre días no medida (el offset derivó 0.5° en 10 h) | Estabilidad del sistema | Puntos comunes entre E1 y las campañas del 14–15/10, y E2 |
| G10 | Luz ambiente no controlada ni registrada (el AC del PD varía entre 10 y 100 mV) | Robustez y reproducibilidad | Registrar el estado de las luces en cada sesión; **E6** opcional |
| G11 | Test aleatorio corto (47 puntos válidos) | Un CDF con 47 puntos es débil | **E8**: unos 200 puntos aleatorios |

---

## 3. Principios metodológicos (fijarlos antes de mirar resultados)

1. **Separación calibración / test (congelada desde hoy).**
   - **Conjunto de calibración:** barrido plano del 13/10 y campañas del 14–15/10. Con ellos se
     fijan A, m, la posición XY del LED, el offset del MTRS y el tilt del adaptador.
   - **Conjunto de test:** todo lo que se adquiera desde el 17/10 (E1, E4, E8). Se evalúa **sin
     reajustar nada**.
   - Los hiperparámetros se guardan en un fichero con fecha (como `demo/config/demo.toml`) y no se
     tocan.
   - Es la respuesta directa a la nota del docx: "los datos de test nunca fueron considerados".
2. **Medido frente a calibrado.** Cada parámetro tiene un origen declarado (tabla de la sección 6,
   A3). Lo que se pueda medir físicamente, se mide (E0). Lo que se calibre con datos, se calibra
   con el conjunto de calibración.
3. **Sesgo frente a varianza.** Cada error se descompone en sesgo (desajuste del modelo) y varianza
   (ruido). La varianza sale de registros repetidos o segmentados y se compara con el PEB. El sesgo
   se explica con el presupuesto de errores.
4. **Lo físico y lo offline, separados explícitamente** (tabla de la sección 4). En el paper, cada
   resultado offline dice qué dato real lo sustenta.
5. **Trazabilidad.** Anotar en cada sesión el commit de `database_acquisition` y de la demo, el
   estado de las luces, los 4 LEDs encendidos y las tensiones y corrientes de los drivers. Ya
   existen `logs/` y `session.json`.
6. **Mismas condiciones que las campañas del 14–15/10**, para poder juntar datasets: 4 LEDs
   encendidos (en esas campañas lo estaban), adaptador de 15°, offset nominal de 65°, registros de
   10 MSa/s, CH1 a ~75 mV/div sin recortes.

---

## 4. Qué se responde con datos físicos y qué offline

| Pregunta | ¿Físico u offline? | Dataset | Notas |
|---|---|---|---|
| Error 3D en el volumen y por altura | Físico | **E1** (+ 14–15/10) | Figuras principales |
| K mínimo | Offline | E1, K = 10 | Subconjuntos casi uniformes, como en el informe |
| Mínimo número de puntos de calibración | Offline | E1 + 14–15/10 + barrido plano | A2 |
| Sensibilidad a cada parámetro de calibración | Offline | E1 | A3 (diagrama de tornado) |
| **Orientaciones conocidas pero arbitrarias** (fuera del codebook) | **Físico** | **E4** con las normales medidas | Requiere el modelo de E3 |
| **Error de medida de pose** (leo n̂ ≠ n) | Offline | E1 con normales perturbadas | A5, escenarios 1 y 2 de `Sensitivity_report.tex` |
| **Error de actuación no observado** (comando ≠ real) | **Físico** + offline | **E4** procesado con las normales *comandadas* (tilt 0) | El mismo dato que el caso conocido |
| Sesgo común de actitud (fallo de IMU o del montaje) | Físico | **E3** procesado con tilt 0 y el incidente del 16/10 | Error común conocido de ±3° |
| Oclusión de orientaciones | Offline + nivel real | **E5** (nivel bloqueado real) mezclado en E1 | A4 |
| Ruido σ y comparación con el PEB | Físico | E1 (segmentos) + **E2** | A1 |
| Repetibilidad (reposicionado y entre días) | Físico | E2 + puntos comunes | A7 |
| Modelo del LED frente a la distancia | Físico | **E7** + E1 | A6 |
| Generalización sin rejilla | Físico | **E8** | CDF ciego |

**Rejilla regular frente a posiciones aleatorias:** hacen falta **las dos**, con papeles distintos.

| Rejilla regular (E1) | Aleatorias (E8, demo) |
|---|---|
| Mapas espaciales y error por altura | Estimación **insesgada** del rendimiento en el volumen |
| Subconjuntos controlados para estudiar la calibración y K | Sin solapamiento con la rejilla de calibración: generalización real |
| Puntos comunes con la rejilla antigua (repetibilidad entre días) | Es exactamente el escenario de uso (y la demo) |

En el paper, la rejilla es el dataset principal; el aleatorio, la validación ciega independiente.

**Ojo con las oclusiones en este testbed.** El PD gira sobre su propio centro y el LED está fijo,
así que **el rayo LED–PD es el mismo para las K orientaciones**. Un obstáculo en el camino bloquea
todas las orientaciones a la vez. La oclusión de *algunas* orientaciones solo es física si es
**temporal**: alguien pasa o una mano tapa el PD durante una de las K adquisiciones. También lo es
en el **ADR de pirámide**, donde se tapa una cara. Por eso aquí la oclusión se estudia así: con E5
se mide el nivel real de señal con el PD bloqueado, que no es cero por NLOS y luz ambiente, y en
A4 se sustituyen *k* orientaciones de E1 por esos valores reales.

---

## 5. Catálogo de experimentos físicos (por prioridad)

Tiempos de referencia medidos el 14/10: **4.2 min por posición con K = 10**. La rotación del MTRS a
1.5°/s es el 85 % del tiempo. Cada registro adicional de 100 ms añade ≈ 0.9 s por orientación.
Confirmar siempre con *Preview*.

> **Sobre los congelamientos del osciloscopio.** Ocurren aproximadamente una vez cada 2000–5000
> descargas, y la continuación automática solo funciona si alguien reinicia el osciloscopio. Para
> las sesiones nocturnas, mejor **un registro largo** (por ejemplo 300 ms = 3 Mpts) que varios
> cortos. Los datos parecen indicar que el riesgo depende más del número de descargas que de su
> tamaño. Además, el registro largo se puede **trocear offline en 3 × 100 ms** para estimar σ: se
> guardan las formas de onda.

### E0 — Metrología del ground truth e inspección mecánica (prioridad 1, sábado temprano, 1.5 h)

**Para qué:** cerrar G1 y comprobar el montaje después del incidente.

- **Altura real del centro del PD** en z = 0, −200, −300, −400 y −600, con 3 repeticiones cada una.
  Usar telémetro láser o regla desde el suelo, o desde una referencia fija.
  - Se obtiene la tabla z_cmd → Z_PD, la linealidad de s_z y una incertidumbre (±mm).
  - **No tocar la configuración del eje Z del controlador**: se perdería la comparabilidad con los
    datos anteriores. Mejor documentar el mapeo medido.
- **LED:** posición XY con plomada y altura H_LED (hoy se supone 3.0 m), con incertidumbre.
- **MTRS:**
  - lectura de tilt = 0 a varios ángulos (comprobar que no varía con la rotación);
  - apriete del adaptador de 15° y de la platina;
  - holgura del cable del PD (que no tire al girar).
- **Adaptador:** inclinación real con un inclinómetro, por ejemplo el de un móvil, a varios ángulos.
- **Condiciones:**
  - anotar tensiones y corrientes de los drivers de los 4 LEDs (docx: V1 = 16, I1 = 0.350…);
  - CH1 a 75 mV/div, WaveGen 1 con la salida ON, 4 LEDs encendidos;
  - estado de las luces de la sala (decidir **una** condición para todo el fin de semana y anotarla).

### E1 — Rejilla 3D maestra (prioridad 1, **sábado por la noche**, ≈ 15 h)

**Para qué:** el dataset principal del paper (G2, G3, G4, G5, G9).

**Configuración en `database_acquisition`:**

| Parámetro | Valor |
|---|---|
| X, Y | 100 → 1300, paso 200 (7 × 7) |
| Z | −600 → 0, paso 200 (4 niveles: 0, −200, −400, −600) |
| K | 10, offset 65°, adaptador 15° (anotado) |
| Tilt del MTRS | Fixed 0 (ahora se comanda en cada posición) |
| Registro | **300 ms a 10 MSa/s**, 1 muestra (o 100 ms × 3 si el riesgo de congelamiento no preocupa) |
| Pasadas | 1 |
| Formas de onda | **Sí**: segmentación offline, ruido y frecuencias |
| Etiqueta | `E1_grid3D` |

**Tamaño:** 196 posiciones, 1960 medidas, ≈ 14.5–15.5 h y unos 3 GB (hay 353 GB libres).

**Puntos comunes con las campañas del 14–15/10:**
- en XY, (100, 700, 1300)², 9 posiciones por nivel;
- en Z, los niveles 0, −200 y −600.

Son **27 posiciones repetidas tras 3 días**, que dan la repetibilidad entre días (G9).

**Salidas del análisis:**
- error 3D por posición y por altura;
- mapas de error y CDF;
- análisis offline A1–A6.

### E3 — Modelo del tilt del MTRS (prioridad 1, **antes de E1**, ≈ 2 h)

**Para qué:** saber cómo modifica el tilt del MTRS las normales del PD (G6). Es requisito para E4,
para usar tilt en la demo y para explicar el incidente.

**Configuración:** 3 sesiones con tilt fijo de **−3°, 0° y +3°**.
- XY ∈ {100, 700, 1300}², z = −300: 9 posiciones, comunes con la rejilla del 14/10.
- K = 10, 100 ms × 1.
- ≈ 40 min por sesión.

**Análisis:**
- Ajustar el modelo n(θ, τ) = R(τ; eje)·n₀(θ), con el eje del tilt fijo en el laboratorio **o**
  girando con la platina.
- Comparar la lectura del encoder del tilt durante la rotación (patrón sinusoidal del incidente).
- La sesión con tilt 0 da también la **repetibilidad entre días** de 9 posiciones.
- La sesión con ±3° procesada con tilt 0 **reproduce el incidente de forma controlada**: un sesgo
  común de actitud conocido, para A5 y la detección por residuo.

### E5 — Nivel real con el PD bloqueado y suelo de ruido (prioridad 2, domingo por la mañana, ≈ 1 h)

**Para qué:** dar realismo al estudio de oclusiones (G8) y medir el ruido de fondo.

1. **PD bloqueado** (tapa opaca o tarjeta fijada al carro del gantry por encima del PD, sin tocar la
   platina del MTRS): 9 posiciones, K = 10, 100 ms × 3. Se obtiene el RSS bloqueado real (NLOS +
   ambiente) por posición.
2. **Salida del WaveGen 1 en OFF** (el LED de 500 kHz sin modular) en 3 posiciones, K = 10. Da el
   suelo de ruido en 500 kHz, y con él el umbral de detección (por ejemplo, la media + 5σ).
   - El programa no arranca con la salida apagada: hay que hacerlo con un barrido corto aparte o
     con la demo/exp01.
   - Alternativa sin tocar el WaveGen: usar como suelo de ruido un bin FFT vacío (p. ej. 400 kHz)
     de las formas de onda de E1.

### E4 — Orientaciones arbitrarias conocidas (prioridad 2, domingo, ≈ 2.5 h)

**Para qué:** demostrar que el método **no necesita un codebook**: basta con conocer las normales
(G7).

**Configuración:**
- XY ∈ {250, 550, 850, 1150}² (entre los puntos de la rejilla) y z ∈ {−300, −600}: 32 posiciones.
- K = 10, tilt **Random U[−3°, 3°] para cada posición × orientación** (semilla guardada).
- 300 ms × 1.

**Análisis (el mismo dato da dos experimentos):**
- **R1, orientaciones conocidas:** estimador con las normales *medidas* (modelo de E3 + encoders).
  Se espera el mismo error que con E1.
- **R3, actuación no observada:** estimador con las normales *comandadas sin tilt* (como si el tilt
  fuera 0). Se espera una degradación en función de la dispersión del tilt, que se compara con la
  aproximación de momentos de `Sensitivity_report.tex`.

### E2 — Repetibilidad y ruido (prioridad 2, domingo, ≈ 1.7 h)

**Para qué:** σ empírico por orientación y repetibilidad del reposicionado (G3, G9).

**Configuración:** las 9 posiciones de E3 a z = −300, K = 10, **300 ms × 4** (12 segmentos de
100 ms) y **2 pasadas**.

**Análisis:**
- varianza del estimador por posición, frente al PEB calculado con el σ medido;
- repetibilidad del reposicionado, entre pasadas.

### E8 — Test ciego con posiciones aleatorias (prioridad 2, **domingo por la noche**, ≈ 13 h)

**Para qué:** CDF insesgado e independiente (G11). Sirve además como ensayo general de la demo.

**Configuración en la demo:** Random en toda la región, K = 5, tilt Fixed 0, 1 muestra de 100 ms
(o 300 ms), semilla anotada, `max_points` 0. Unos 200 puntos.

**Análisis:**
- CDF con la configuración congelada;
- comparación con E1 sobre los subconjuntos K = 5.

### E6 — Luz ambiente (opcional, prioridad 3, ≈ 1.3 h)

Las 9 posiciones de E2, K = 10, con luces encendidas y apagadas. Se obtiene el efecto en σ, en el
recorte y en el error. Es el típico experimento que pide un revisor de *Sensors J* o *TIM*.

### E7 — PD plano a otras alturas: modelo del LED frente a la distancia (prioridad 1 para el paper, **después de la reunión**)

**Para qué:** cerrar G5, la mayor fuente de error residual. Es también la base de la calibración
quasi-Lambertiana (eje B de `ExpValidation_Journal`) y del PINN de `proposal_journal.md`.

**Configuración:**
- **Requiere cambiar al adaptador de 0°**: por eso se hace al final, cuando ya no haga falta el de
  15°.
- K = 1, paso de 25 mm (57 × 57), z = −600 y z = 0 (≈ 2 h por altura). z = −300 ya existe.

**Análisis:**
- m aparente frente a la distancia;
- modelo L(φ, d) o spline;
- re-estimación de E1 con el nuevo modelo: se espera que desaparezca el sesgo vertical.

### Fase 2 y siguientes (no este fin de semana)

| Id | Experimento | Valor | Requisito |
|---|---|---|---|
| E9 | **Rotación continua sin parar**: capturas de 100 ms mientras el MTRS gira a 1.5°/s, ángulo por timestamp del encoder | Cientos de orientaciones en el mismo tiempo que K = 10; elimina los tiempos de asentamiento | Modo nuevo en `database_acquisition`; prueba de viabilidad con 5–10 posiciones |
| E10 | **IMU** en el soporte del PD | Orientación "medida con error" real (escenario R2), camino al dron | Compra; sincronización |
| E11 | **Trayectoria**: gantry en movimiento + rotación continua | Tracking, filtro con modelo de movimiento | E9 |
| E12 | **Multi-LED**: los 4 LEDs ya se registran en cada medida | Paper aparte con datos casi gratis: diversidad espacial + angular | Posición de los 4 LEDs (E0 extendido) |
| E13 | **ADR de pirámide** (5 PD) | Estimación instantánea; oclusión física de una cara | Construcción del receptor |
| E14 | **Dron** | Aplicación | E10, E13 |

---

## 6. Análisis offline (sobre los datos del fin de semana)

| Id | Análisis | Datos | Figura o tabla |
|---|---|---|---|
| **A1** | Error frente a K y frente al estimador (GLS/WLS/NLS) **contra el PEB** (respuesta SQ, A y m calibrados, σ medido) | E1, E2 | Error frente a K con la curva del PEB; varianza empírica frente al PEB |
| **A2** | **Mínimo número de puntos de calibración**: N_cal ∈ {1, 2, 3, 5, 10, 20, 50, …}; estrategias aleatoria / esquinas / centro / una altura / varias alturas; 200 sorteos; test en las posiciones no usadas y en E8 | E1 + 14–15/10 + plano | Error frente a N_cal (mediana y percentiles) por estrategia |
| **A3** | **Sensibilidad a los parámetros**: perturbar A, m, LED x/y/h, offset, tilt del adaptador, s_z y altura de la base ±δ (con su incertidumbre de E0) | E1 | Tornado: Δerror por parámetro → presupuesto de errores y qué medir mejor |
| **A4** | **Oclusiones**: sustituir k ∈ {1, …, K−3} orientaciones por niveles bloqueados reales (E5) o parciales (×0.1…0.9); comparar sin detección, umbral de suelo de ruido y residuo robusto (exclusión iterativa o subconjuntos) | E1, E5 | Error frente a número de orientaciones bloqueadas, con y sin detección |
| **A5** | **Errores de orientación**: (a) independientes por orientación, (b) rotación común, con σ ∈ {0.25, 0.5, 1, 2, 3}°; puntos físicos de E3 (±3° común) y E4 (actuación) | E1, E3, E4 | Error frente a σ_orientación, simulación sobre datos reales + puntos físicos, frente a la cota con pose incierta (`rx_pose_error_peb.m`) |
| **A6** | **Modelo del LED**: cos^m frente a m(d), spline o PINN; efecto en el sesgo vertical por altura | E7, E1 | Sesgo vertical por altura, antes y después |
| **A7** | **Repetibilidad**: entre pasadas (E2), entre días (27 + 9 puntos comunes), deriva del offset | E1, E2, E3 | Tabla de repetibilidad |
| **A8** | **Integridad**: el residuo de forma (fit_rms) como detector de fallos de orientación; ROC sobre E1 (sano) frente a E3 ±3°, E4 en modo R3 y el incidente | E1, E3, E4, demo | Curva ROC; caso del incidente del 16/10 |

**Origen declarado de cada parámetro (para A3 y para el paper):**

| Parámetro | Origen preferido | Respaldo |
|---|---|---|
| Altura del PD por nivel (s_z, base) | **Medido (E0)** | Triangulación VLP (ya coincidió) |
| Posición XY y altura del LED | **Medido (E0)** | Ajuste con el barrido plano |
| A, m (o modelo del LED) | Calibrado: barrido plano | In situ con N_cal puntos (A2) |
| Offset del MTRS | Medido (alineación) **o** calibrado con N_cal | Ajuste por forma |
| Tilt del adaptador | Medido (inclinómetro) | Ajuste por forma (14.8°) |
| Respuesta del PD | SQ, Bastiaens 2020 (ψ_3dB = 0.61 rad) | Prueba de forma |

---

## 7. Plan del fin de semana (horas orientativas)

### Sábado
| Hora | Qué | Comprobaciones |
|---|---|---|
| Ahora → +1.5 h | **E0** metrología e inspección | Anotar todo en un `E0_metrologia.md` dentro de `analysis/` |
| +1.5 h → +3.5 h | **E3** (3 sesiones: tilt −3, 0, +3) | Ver en el log que no aparece "moved by itself"; cada sesión, ≈ 40 min |
| Mientras corre E3 | Control de calidad rápido: forma de las RSS de la sesión con tilt 0 contra las del 14/10 en las mismas posiciones | Si difiere más de 2 %, revisar el montaje antes de E1 |
| ~18:00 → domingo ~09:00 | **E1** rejilla 3D maestra | Auto-resume activo; disco libre; luces en el estado elegido; WaveGen 1 en ON; los 4 LEDs encendidos |

### Domingo
| Hora | Qué | Comprobaciones |
|---|---|---|
| 09:00 | Revisar E1: log, posiciones completas, recortes, tilt leído = 0 | Si se congeló el osciloscopio: reiniciarlo, y la sesión sigue sola |
| 09:30 → 10:30 | **E5** (PD bloqueado y suelo de ruido) | Necesita a alguien presente |
| 10:30 → 13:00 | **E4** (tilt aleatorio) | — |
| 13:00 → 14:45 | **E2** (repetibilidad) | — |
| 14:45 → 16:00 | **E6** (opcional) o ensayo de la demo para el asesor | — |
| ~19:00 → lunes | **E8** test ciego con la demo | Tilt Fixed 0; anotar la semilla |

**Lista de comprobación antes de cada sesión:**
- [ ] Kinesis cerrado; el MTRS lee tilt 0 a varios ángulos.
- [ ] WaveGen 1 con la salida ON (tras cualquier reinicio del osciloscopio); 4 LEDs encendidos; drivers con los mismos V/I.
- [ ] CH1 a ~75 mV/div; sin recortes en *Preview*.
- [ ] Luces de la sala en el estado elegido (anotarlo en la etiqueta o en una nota).
- [ ] Adaptador de 15° apretado; cable del PD con holgura.
- [ ] Zona del gantry despejada; parada de emergencia accesible.
- [ ] Etiqueta de la sesión = id del experimento (E1_grid3D, E3_tiltm3, …).

---

## 8. Reunión con el asesor (la semana que viene)

**Objetivo:** que vea el sistema funcionando, que valide el **alcance del paper 1** y que decida
sobre compras y extensiones.

**Agenda (40–45 min):**
1. **Demo en vivo (10 min).** K = 5 y tilt 0; ~3.6 min por punto, así que lanzarla al empezar la
   reunión. Mientras se mueve, explicar la figura polar de RSS por orientación.
2. **Resultados (10 min):**
   - 125 posiciones: 3.9 cm (3.7 con el LED ajustado);
   - error frente a K;
   - SQ frente a coseno;
   - **el VLP detectó la escala Z del gantry**;
   - test aleatorio de la demo: 3.3 cm (47 puntos) y, si ya está, E8 (~200 puntos);
   - el incidente del tilt como prueba de **detección de fallos por residuo**.
3. **Plan (10 min):** las secciones 0, 2 y 4 de este documento: brechas y cómo se cierran.
4. **Decisiones que pedirle (10 min):**
   - **Revista objetivo y enfoque.** El contenido (calibración, ground truth, presupuesto de
     errores, sensibilidad) encaja mejor con **IEEE TIM** o **IEEE Sensors Journal**. **IoT-J**
     sería posible si se enfatiza el receptor pasivo y la escalabilidad (`target_venues.md`). Hay
     que evitar solapar con el TCOM.
   - **Alcance del paper 1:** E1 + A1–A5 + A8 (y E7/A6 si llega a tiempo). Rotación continua, IMU,
     multi-LED, ADR y dron quedan para papers 2+.
   - **Compras:** un rotador más rápido (hoy la rotación es el 85 % del tiempo) y una IMU (E10).

**Material para llevar:**
- este plan;
- figuras de `Experiment_01_3D_estimation/figures`;
- figura del incidente: residuo y error frente al punto;
- tabla de la sección 1.

---

## 9. Riesgos y cómo mitigarlos

| Riesgo | Mitigación |
|---|---|
| El osciloscopio se congela de noche | Registros largos únicos (menos descargas); auto-resume (requiere a alguien que lo reinicie); revisar por la mañana |
| El tilt se mueve solo otra vez | Ya se comanda en cada posición y se avisa en el log; revisar `mtrs_tilt_deg` en el control de calidad |
| Cambios de configuración a mitad de campaña | No tocar el eje Z del controlador, ni el adaptador, ni el offset durante el fin de semana |
| Querer hacer todo | Paper 1 = E0, E1, E3, E4, E5, E2, E8 + A1–A5, A8. El resto, solo después de la reunión |
| Sesgo vertical residual (modelo del LED) | E7 + A6 justo después de la reunión |
| Mirar el test antes de congelar la calibración | Congelar `demo.toml` / los hiperparámetros de MATLAB **hoy**, con fecha |

---

## 10. Estructura tentativa del paper 1

1. Introducción: VLP con un solo LED y diversidad angular en el receptor; dual de TCOM/broadcast.
2. Modelo: LED quasi-Lambertiano y PD con respuesta SQ; estimadores GLS/WLS/NLS y recuperación de
   distancia (dual de `broadcast_distance`); PEB.
3. Testbed y protocolo: gantry, MTRS, adaptador, osciloscopio por LAN, adquisición y ground truth
   (E0).
4. Calibración e identificación del modelo: SQ frente a coseno; LED; geometría; **detección de la
   escala Z**; presupuesto de calibración (A2, A3).
5. Resultados: rejilla 3D (E1); test ciego (E8); frente a K y frente al PEB (A1); repetibilidad
   (A7).
6. Robustez: orientaciones arbitrarias conocidas (E4-R1); errores de orientación (A5, E3, E4-R3);
   oclusiones (A4, E5); integridad (A8).
7. Discusión: fuentes de sesgo (modelo del LED), tiempo de adquisición, hacia IMU, ADR y dron.
8. Conclusiones; dataset abierto (los formatos de `database_acquisition` ya lo permiten).
