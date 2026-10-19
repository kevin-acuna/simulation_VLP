# Notas: ¿journal ya? y colaboración en ML (18/10/2026)

## 1. Comparación con el estado del arte (carpeta `papers/`)

| Trabajo | Receptor | Dimensión | Experimento | Modelo / método |
|---|---|---|---|---|
| **Wang et al., IEEE TIM 2024** (STRP) | 1 PD inclinado 20°, rotación **manual** (escala de 2°), N = 4 | **2D, altura conocida** | Maqueta **50 × 50 × 30 cm**, 25 posiciones, una altura | RSS **ajustado empíricamente** en esa sala (C₂·(u·n)/d^C₁), metaheurística LS-IGWO, CRLB 2D, reflexión de 1.er orden |
| Liu et al., IEEE Photon. J. 2022 | PD rotatorio horizontal | 2D | Sobre todo simulación | **ML** (random forest + ELM) |
| Shi et al., IEEE PTL 2025 / Performance comparison | PD rotatorio | 2D | Pequeño | LS, CRLB, 4 rotaciones |
| Ma et al. (3D online, 1 LED) | **Varios PDs** + orientación del equipo | 3D | Prototipo, *dataset* público | NLS / SGD (*deep learning*), 1.77 cm |
| Qin et al., Optik 2020 | 3 PDs inclinados + 1 horizontal | 3D | Solo simulación | Cocientes de potencia |

**Conclusión: sí, es suficientemente diferente.** Ningún trabajo con un único LED y un único PD
rotatorio hace **3D**. Todos fijan la altura y estiman solo (x, y). Los 3D de un solo LED usan
**varios PDs**.

### Qué resaltar frente a Wang et al. (en este orden)
1. **3D sin conocer la altura.** La dirección sale de la forma de las K RSS y la distancia en forma
   cerrada de las mismas RSS. Ellos necesitan la altura del receptor.
2. **Escala y realismo.**
   - Nosotros: área de 1.4 × 1.4 m, 5 alturas, LED a 3 m, distancias LED–PD de ~1.7 a 2.4 m.
   - Ellos: una maqueta de ~30 cm. Hay que comparar el **error relativo a la distancia**:
     3.7 cm / ~2 m ≈ **2 %**, frente a ~1–2 cm / ~0.3 m ≈ 3–6 %.
3. **Modelo físico frente a ajuste empírico.**
   - Nosotros: respuesta SQ del PD validada, LED Lambertiano calibrado con **9 puntos** fuera del test,
     y un estimador NLS de ~4 ms.
   - Ellos: el modelo de RSS se ajusta con medidas del mismo entorno y usan una metaheurística
     iterativa.
4. **Presupuesto de calibración.** Cuántos puntos hacen falta (9), dónde ponerlos, y que la XY del LED
   sale de los mismos puntos pero la altura no. Nadie lo estudia.
5. **Sus trabajos futuros son nuestros resultados:**
   - Ellos dicen que la *estimación de la orientación del LED* queda pendiente. Nosotros **detectamos
     la inclinación del LED** (700 kHz, ≈5°).
   - Ellos citan como limitación que *la orientación del objeto debe conocerse de antemano* y como
     trabajo futuro el *posicionamiento y orientación simultáneos*. Nosotros **estimamos el yaw con
     dos LEDs**.
6. **Rigor experimental.**
   - Nosotros: platina motorizada con encoder; 125 posiciones de rejilla + 131 aleatorias + mapa de
     19 881 puntos; K de 3 a 10 medido; autodiagnóstico del eje Z.
   - Ellos: 25 posiciones con rotación manual.
7. **Dataset y herramientas abiertos:** formas de onda crudas, 4 LEDs y verdad terreno. El de Ma et al.
   es el único dataset 3D público y usa varios PDs.

### Lo que un revisor de TIM pediría (y su coste)
- **Comparación con métodos previos sobre nuestros datos.** Su LS / LS-IGWO y un KNN de fingerprint,
  en su versión 2D con la altura conocida para que sea justo. Se hace con datos que ya tenemos.
- **Comparación con la cota** (CRLB/PEB 3D del receptor reorientable). La teoría ya está en
  `simulations/Bounds (3D)`. Falta el ruido medido: se puede estimar *offline* desde las formas de onda
  guardadas (bins vecinos al tono) o con registros repetidos (E2).
- **Reflexiones (NLOS).** Ellos las modelan. Nosotros deberíamos al menos cuantificarlas, por ejemplo
  con el error cerca de las paredes o el suelo del modelo.
- **Incertidumbre de la verdad terreno:** el medidor láser.
- **Un segundo conjunto de test de otro día** (la rejilla E1 o el test ciego E8). Refuerza, pero no es
  imprescindible: las 131 posiciones aleatorias ya son un test independiente.

### Recomendación
**Empezar a redactar ya** (introducción, modelo, testbed, calibración y resultados actuales). En
paralelo, en 2–3 semanas:
1. *baselines* (LS / LS-IGWO / KNN) sobre nuestros datos;
2. PEB con el ruido medido;
3. una campaña complementaria (rejilla densa o test ciego) con verdad terreno medida con láser.

### Dataset: ¿solo depositarlo o también un paper de datos?
- **Para TIM:** depositar los datos con DOI (IEEE DataPort o Zenodo) y citarlos en *Data
  availability*. Basta, y refuerza el artículo.
- **Paper de datos:** es factible y habitual (*IEEE Data Descriptions* — la revista de datos de
  IEEE —, *Scientific Data*, *Data in Brief*).
  - **Contenido:** solo el dataset (protocolo de adquisición, formatos, validación técnica, notas de
    uso), sin resultados científicos nuevos. Hay que reescribir el texto, no copiarlo de TIM.
  - **Política:** comprobar la de la revista elegida sobre datos ya usados en otro artículo.
- **Recomendación:** no hacerlo ahora. Prioridad, TIM. El paper de datos vale la pena cuando el
  dataset sea **más amplio** que lo usado en TIM: rejilla densa, mapas planos a varias alturas,
  ángulos densos, conjuntos aleatorios y condiciones controladas. Encaja como trabajo conjunto con la
  colaboración de ML (dataset + benchmark con *baselines*).

Revista: **IEEE TIM** encaja mejor que nada, porque Wang et al. publicó ahí y el estudio de
calibración es una contribución de medida. Alternativas: *IEEE Sensors Journal* o *IEEE IoT Journal*.

---

## 2. Colaboración con Rizwana Ahmad (machine learning)

Una red que "mejore la precisión" **no es buen aporte**:
- con 125 posiciones etiquetadas se sobreajusta;
- la red no sabe de física y no generaliza a otra sala u otro LED;
- **ya existe** ML con un LED y un PD rotatorio (Liu et al. 2022; Ma et al. con *deep learning*).

Lo valioso es usar el ML **donde el modelo físico falla o donde hacen falta garantías**. Propuestas,
de mayor a menor potencial:

### A. Calibración *few-shot* del patrón del LED con física (*physics-informed*) — **recomendada**
- **Problema real y medido:** el patrón no es cos^m (el m aparente cae de ~11 a ~6). Eso fija un suelo
  de 3.1 cm que ninguna calibración de A y m supera.
- **Idea:** un modelo neuronal pequeño del producto R·L(φ, distancia) con restricciones físicas
  (suavidad, monotonía, simetría y límite Lambertiano). Se entrena con los mapas densos de otros LEDs y
  se adapta a un LED nuevo con **9 puntos**, como en nuestra rejilla 3 × 3.
- **Datos:** ya tenemos 4 LEDs × 19 881 puntos. Para generalizar en distancia haría falta un segundo
  plano (E7).
- **Métrica clara:** bajar de 3.1 cm con los mismos 9 puntos de calibración. Encaja con tu propuesta
  de PINN (`Tracks_PROPOSALS/proposal_journal.md`).

### B. Posicionamiento con incertidumbre garantizada (*conformal prediction*)
- **Idea:** cada estimación va con un radio de confianza calibrado, por ejemplo "el error es < r con
  un 90 % de probabilidad". Se aprende a partir del residuo del ajuste, la amplitud, el ángulo, K y
  demás.
- **Utilidad:** la necesitan robots y drones. El residuo del ajuste ya mostró ser informativo.
- **Datos:** 125 + 131 estimaciones reales, más simulación para entrenar. Las garantías de *conformal*
  se validan con los datos reales.

### C. *Sim-to-real* y diagnóstico de la instalación
- **Idea:** entrenar con un gemelo digital (nuestro modelo físico con parámetros aleatorizados:
  inclinación y altura del LED, m, offset) y ajustar con pocos datos reales.
- **Objetivo:** estimar los **parámetros de la instalación** (pose de cada LED), no solo la posición.
- **Caso real:** el LED de 700 kHz inclinado ≈5° es un ejemplo medido para validar.

### D. Diseño activo de la calibración (*Bayesian optimization* / procesos gaussianos)
- **Idea:** elegir el siguiente punto de calibración según la incertidumbre del modelo, para minimizar
  los puntos.
- **Encaje:** formaliza nuestro hallazgo de que "importa dónde, no cuántos". Se evalúa sobre el mapa
  de 19 881 puntos sin medir nada nuevo.

### E. Paper de *dataset* + benchmark (rápido y citable)
- **Contenido:** dataset abierto con formas de onda crudas, 4 LEDs, orientaciones controladas y verdad
  terreno, junto con tareas de referencia (posición, calibración *few-shot*, yaw) y *baselines* de
  modelo y de ML.
- **Venue:** *Scientific Data*, *Data in Brief* o IEEE DataPort.
- **Contraste:** el de Ma et al. es el único dataset 3D público y usa varios PDs.

### Antecedentes encontrados (búsqueda del 18/10/2026)
Grupos de KU Leuven (Wu, Stevens, De Strycker, Rottenberg) y Ghent/imec (Raes, Knudde, Garbuglia,
Dhaene, Bastiaens). Todos usan **varios LEDs y un PD fijo**, casi siempre en 2D:

| Trabajo | Qué hace | Relación con lo nuestro |
|---|---|---|
| Wu et al., arXiv 2404.18650 (2024), *Optimal calibrating the LED tilt and gain* | Calibra la inclinación y la ganancia del LED con estimador a la CRLB, y estudia **dónde poner las medidas de calibración** | **Muy cercano** a nuestro presupuesto de calibración y a la inclinación del LED de 700 kHz. **Citarlo** y diferenciarse: un solo LED con PD reorientable en 3D; el patrón no es cos^m cerca del eje y eso determina la colocación; XY del LED identificable, altura no |
| Wu et al., IPIN 2024 (*PhyGP*) | GP híbrido física + datos con *Bayesian active learning*, mejor extrapolación | Antecedente directo de la propuesta A (híbrido físico/ML) |
| Raes et al., ISWCS 2021 | GP con patrones de radiación **reales** medidos de 4 LEDs | Muestra que el cos^m ideal sesga (P95 de hasta 14 cm) |
| Knudde et al., IEEE Commun. Lett. 2020; Garbuglia et al., IEEE Photon. J. 2022 | GP eficientes en datos; *active learning* del muestreo | Antecedentes de la propuesta D |
| MetaLoc (ICC 2022) y otros | *Meta-learning* / *few-shot* para fingerprinting RF en escenarios nuevos | Idea parecida en RF, **no** para el patrón del LED |

**Novedad de A:** existe el híbrido física + ML (PhyGP), pero no un **prior aprendido sobre patrones
de emisores** que se adapte a un LED nuevo con ~9 puntos, ni con receptor reorientable en 3D.
- **Novedad real pero acotada.** Para que sea fuerte hacen falta **muchos LEDs distintos**: con 4 el
  prior es pobre.
- **Campaña necesaria:** biblioteca de patrones con 8–10 LEDs (tipos y lentes distintos) y algunos
  inclinados a ángulos conocidos, PD plano y 2 alturas. Con rejilla de 25 mm son ~2 h por LED y
  altura: ~30–40 h en total.

### Otras opciones prácticas con ML (problema bien definido + campaña)
1. **Selección activa de orientaciones** — la más original y práctica.
   - **Problema:** ¿qué orientación medir a continuación, dadas las RSS ya medidas, para llegar a una
     precisión objetivo con el menor número de giros o el menor tiempo? Ataca el cuello de botella
     medido: el 86 % del tiempo es rotación.
   - **Métodos:** diseño experimental bayesiano o una política aprendida (RL / imitation) sobre el
     gemelo digital.
   - **Baselines:** K uniforme y el codebook fijo elegido por CRLB (Shi et al. 2025; nuestro PEB).
   - **Métrica:** error frente a número de giros o tiempo.
   - **Campaña:** ~150 posiciones con **36 ángulos** (cada 10°), ~5.5 min por posición, unas 14 h.
     Permite simular *offline* cualquier secuencia de giros. Con la rotación continua (E9) sería más
     denso aún.
2. **Integridad e incertidumbre** (*conformal prediction* + detección de orientaciones corruptas).
   - **Problema:** dar con cada posición un radio garantizado y detectar o excluir orientaciones
     corruptas (oclusión temporal, error de orientación, luz ambiente).
   - **Campaña:** ~300 posiciones aleatorias (demo, K = 5) en condiciones controladas: tilt del MTRS
     aleatorio no comunicado al estimador, oclusiones programadas con una tarjeta en k orientaciones,
     luces encendidas o apagadas. Unas 18 h.
   - **Métricas:** cobertura real frente a nominal y ROC de detección.
3. **Seguimiento de un receptor en movimiento** (modelo secuencial o filtro híbrido aprendido).
   - **Problema:** posición de un receptor que se mueve mientras el PD gira.
   - **Campaña:** trayectorias del gantry con rotación continua. Requiere desarrollar E9 primero.
4. **Propuesta A** (prior de patrones *few-shot*), con la biblioteca de LEDs indicada arriba.
5. **Paper de dataset + benchmark**: el vehículo natural para cualquiera de las anteriores.

### Propuesta preferida (18/10): estimación de trayectoria con deep learning
**Problema.** Un receptor que **se mueve** mientras el PD **gira de forma continua**. Cada muestra de RSS
se toma en una posición y una orientación distintas, así que el método estático (K orientaciones en
el mismo punto) deja de valer. Se estima la trayectoria 3D a partir del flujo (RSS, ángulo del encoder,
tiempo).

**Antecedentes.** Hay LSTM para VLP con **varios LEDs o varios PDs** (Opt. Express 2021; Sensors
2024, con predicción de trayectoria). **No encontré** seguimiento con un solo LED y un PD que gira de
forma continua.

**Modelos a comparar.**
- Snapshot *stop-and-go* (el método actual).
- NLS en ventana deslizante con modelo de velocidad constante.
- EKF/UKF con nuestro modelo de medida.
- Red secuencial pura (LSTM / TCN / Transformer).
- **Híbrido física + DL** (estilo KalmanNet o capa de medida diferenciable). Es el aporte principal.

**Datos.**
- **Sintéticos ilimitados** del gemelo digital calibrado (patrón y ruido medidos).
- **Reales:** trayectorias del gantry (líneas, círculos, *waypoints* aleatorios) con rotación continua.
  La verdad terreno sale de `trajectory.csv` a 10 Hz, que ya se registra.

**Métricas.** RMSE de trayectoria frente a velocidad del receptor, velocidad de giro, tasa de
actualización y latencia. Generalización a trayectorias, alturas y días no vistos (*sim-to-real*).

**Puntos críticos.**
- A 1.5°/s una vuelta dura 240 s: solo admite receptores lentos (mm/s). Mitigaciones: un rotador más
  rápido, usar 2–4 LEDs (más información por muestra) y registros más cortos (10–20 ms) para subir la
  tasa de muestras.
- **Falta desarrollo:** modo de adquisición continua en `database_acquisition` (gantry en trayectoria +
  MTRS girando + capturas con *timestamp*). Es la E9 del plan.

**"Añadir ML y explorar el número de neuronas"** no basta como aporte, porque ya existe ML con un LED y
un PD rotatorio (Liu 2022). Sirve solo como estudio de arquitectura o *ablation* dentro del paper de
trayectoria, o con un modelo híbrido y pruebas de generalización (otra altura, otro día, otro LED).

### Variante: 1 LED, 1 PD, orientación conocida, trayectoria y PD con inclinaciones pequeñas
**¿Ya se hizo?** En parte:
- **Kim, Park y Kim, *Sensors* 22(17):6488, 2022** (*Single LED, Single PD-Based Adaptive Bayesian
  Tracking*).
  - Usa 1 LED (el más fuerte en cada instante) + 1 PD + IMU, con un filtro de partículas.
  - Es un peatón con la mano inclinada (de ±5° a ±35°); la IMU aporta la orientación **y** la
    navegación inercial (*dead reckoning*).
  - Obtiene < 11 cm en 80–100 m, a altura casi fija (1.2–1.5 m), con la verdad terreno de un recorrido
    marcado.
- **Nuestro arXiv 2603.29400** (LED orientable): robusto a inclinaciones aleatorias del receptor, pero
  sin trayectoria.

**Qué sería nuevo:**
1. **Sin navegación inercial:** solo se conoce la orientación (encoders o IMU), no el desplazamiento.
2. **3D completo**, altura incluida.
3. **Usar las inclinaciones pequeñas y naturales** (oscilación de un dron o de una mano) como
   diversidad angular, con un análisis de observabilidad o PEB en función de su amplitud y del
   movimiento.
4. **Verdad terreno precisa** (gantry + encoders) y trayectorias controladas.
5. **Comparación** del modelo físico (EKF / ventana NLS / filtro de partículas tipo Kim) con DL y con un
   híbrido.

**Factibilidad, con el estimador actual en simulación (estático, K = 5, mismo modelo y LED):**

| Inclinación | 1° | 3° | 5° | 10° | 15° |
|---|---|---|---|---|---|
| Mediana del error, ruido 0.2 % (laboratorio) | 11.0 cm | 3.6 cm | 2.1 cm | 1.1 cm | 0.7 cm |
| Mediana del error, ruido 1 % | 53 cm | 19 cm | 11 cm | 5.3 cm | 3.5 cm |

- El error escala ~ ruido / inclinación. Con 3–5° funciona en el laboratorio; con ruido realista hace
  falta acumular muchas muestras a lo largo de la trayectoria, que es justo lo que aporta el modelo
  secuencial.
- **El punto crítico es el error de orientación.** Con solo 3° de diversidad, 1° de error de la IMU es
  enorme. Por eso "orientación perfectamente conocida" es un supuesto fuerte: hay que estudiar la
  degradación frente al error de orientación (encoders exactos + ruido de IMU sintético).
- **Emulación en el testbed:**
  - adaptador de 0° + tilt del MTRS de ±3° (inclinaciones pequeñas y conocidas por encoder);
  - gantry en trayectoria;
  - rotación opcional para comparar.
- **El tilt va a 0.5°/s y la rotación a 1.5°/s, así que las trayectorias deben ser lentas.** Es
  válido: la física por muestra no depende de la velocidad. Importa la relación entre movimiento y
  cambio de orientación, así que se puede escalar el tiempo.
- **Requisitos:** el modo de adquisición continua (E9) y registros de 20 ms para tener ~3–5 muestras
  por segundo.

### Para la reunión
- **Actualizado tras revisar los antecedentes:** proponer como principal la **selección activa de
  orientaciones (opción 1)**: original, práctica y ligada a un cuello de botella medido.
- **Alternativas:** A (prior de patrones, con biblioteca de LEDs) o la integridad (opción 2), según los
  intereses de ella.
- **El paper de dataset + benchmark** (E), como entregable conjunto, cuando el dataset esté ampliado.
- **Datos para empezar:**
  - el mapa plano de los 4 LEDs;
  - las 125 posiciones × K = 10;
  - las 131 posiciones aleatorias;
  - el modelo físico y su código (`demo/vlp`).
- **Aclarar desde el principio:** autoría, qué datos se comparten y en qué formato (`points.csv` ya
  está documentado).
