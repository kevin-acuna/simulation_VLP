# ¿Cuántos puntos hacen falta para calibrar? (LED de 500 kHz)

*Estudio del 18/10/2026. Script: `calibration_budget.py`; salida completa en
`calibration_budget_output.txt` y `results.json`; figuras en `figures/`.*

## Respuesta corta (para la demo)

> **Basta con unos pocos puntos, siempre que cubran toda el área de trabajo.** Con una rejilla regular
> de **3 × 3 (9 puntos)** o **4 × 4 (16 puntos)** sobre el área, el error 3D medio es **3.54–3.57 cm**:
> el mismo que con los **19 881 puntos** del barrido completo (3.66 cm).
>
> - El **mínimo teórico son 2 puntos**: uno debajo del LED (da A) y otro a ~18–20° de ángulo de
>   emisión (da m). Con ese diseño se llega a 3.45–3.7 cm, pero es frágil: si el segundo punto está a
>   15° el error sube a 6.9 cm, y a 12° a 13 cm.
> - **Un solo punto** (debajo del LED) da A pero **no m**. Habría que conocer m con ±0.2 para no
>   perder más de 0.5 cm, algo que ninguna hoja de datos garantiza.
> - **Lo que no hay que hacer** es concentrar los puntos alrededor del LED. Una rejilla de 3 × 3 con
>   10–20 cm de paso centrada en el LED da **17–22 cm** de error.

**Recomendación práctica:** una rejilla regular de 3 × 3 a 4 × 4 que cubra toda el área donde se va a
posicionar, de modo que se alcancen ángulos de emisión de al menos 20–30°. Con el PD plano y K = 1, son
unos 3 minutos de adquisición para 16 puntos: lo que más tarda es mover el gantry 400 mm entre puntos.

---

## 1. Planteamiento

**Modelo** (PD horizontal mirando hacia arriba y LED mirando hacia abajo, así que ψ = φ y
cos φ = h/d):

    RSS = A · R_SQ(φ) · cos(φ)^m / d²   ⇔   log(RSS·d²/R_SQ) = log A + m · log cos φ

| Se considera conocido (físico o medible) | Se calibra con N puntos |
|---|---|
| Posición del LED (281.1, 904.8) mm, a 3.0 m de altura | **A**, la ganancia |
| Respuesta del PD: SQ (Bastiaens 2020, ψ₃dB = 0.61 rad) | **m**, el orden Lambertiano |
| Offset del MTRS: 66.5° | |
| Geometría del testbed (s_z = 0.6, alturas del PD) | |

- **Datos de calibración:** solo el barrido con el **PD horizontal** (adaptador de 0°, K = 1, tilt
  0): `campaign_20261013-182008_grid141x141x1-xy0to1400-s10-z-300_K1-off65_pd0_tilt0_100ms`.
  Son 19 881 puntos cada 10 mm, con h = 1.865 m y φ de 0 a 37.7°. Hay un punto de la rejilla a 4.9 mm
  de la vertical del LED (el "nadir").
- **Puntos reales:** cada punto de calibración es un punto medido de verdad, una muestra de 100 ms.
  El estudio incluye, por tanto, el ruido real y el desajuste real del modelo; no hay nada simulado.
- **Ajuste:** mínimos cuadrados lineales de la ecuación de arriba. Con N = 2 la solución es exacta.

**Métricas de evaluación.** Con los datos inclinados no se calibra nada; solo se usan como test.
1. **3D:** error 3D medio en las 125 posiciones de las dos campañas con K = 10 (adaptador de 15°,
   5 alturas), con SQ + NLS, igual que en la demo.
   - La dirección û y la amplitud β de cada posición no dependen de (A, m): solo la distancia
     d = √(A·cos^m φ̂ / β). Por eso el error se calcula de forma exacta para cualquier (A, m).
2. **Mapa:** error relativo rms del modelo calibrado sobre todo el barrido plano. Es una métrica
   que no usa ningún dato inclinado.

**Montecarlo:** 400 sorteos por cada combinación de patrón y N. Se dan la mediana y el intervalo
P10–P90.

## 2. Referencias

| Calibración | A (V m²) | m | Error 3D | Error de mapa |
|---|---|---|---|---|
| Los 19 881 puntos | 0.06105 | 5.79 | **3.66 cm** | 1.61 % |
| La de `demo.toml` (staged, barrido recortado) | 0.06271 | 6.09 | 3.66 cm | 2.31 % |
| La mejor (A, m) posible para el test (oráculo) | 0.06130 | 6.05 | 3.14 cm | 2.61 % |

El oráculo es **el suelo del modelo cos^m**: ninguna calibración de A y m puede bajar de 3.1 cm. A
partir de unos 10 puntos bien repartidos, **más datos de calibración no mejoran nada**. Lo que limita
es el modelo del patrón (sección 5).

## 3. Resultados

### N = 1: A desde el punto bajo el LED y m supuesto (`figures/sensitivity_A_m.png`)
| m supuesto | 5.0 | 5.5 | 6.0 | **6.2** | 6.4 | 7.0 | 8.0 |
|---|---|---|---|---|---|---|---|
| Error 3D | 11.1 cm | 7.3 cm | 4.1 cm | **3.36 cm** | 3.8 cm | 7.1 cm | 13.5 cm |

Hace falta conocer m con ±0.2 para quedar a menos de 0.5 cm de la calibración completa. **Un punto no
basta.**

### N = 2: el punto bajo el LED más otro a radio r (`figures/where_to_calibrate.png`, izquierda)
| r (m) | 0.10 | 0.30 | 0.45 | 0.50 | 0.55 | **0.60–0.65** | 0.80 | 1.00 | 1.20 |
|---|---|---|---|---|---|---|---|---|---|
| φ del 2.º punto | 3° | 9° | 14° | 15° | 16° | **18–19°** | 23° | 28° | 33° |
| Error 3D (mediana) | 29 cm | 17 cm | 9.8 cm | 6.9 cm | 5.0 cm | **3.5–3.7 cm** | 4.5 cm | 4.3 cm | 3.6 cm |

Con dos puntos, **el segundo tiene que estar lejos del eje: φ ≥ 18°**, es decir, r ≥ 0.6 m a esta
altura. Por debajo de ~15° el error se dispara.

### N puntos con distintos patrones (`figures/error_vs_N.png`, `figures/patterns.png`)

**Error 3D medio en cm.** Mediana [P10–P90] para los patrones aleatorios; valor único para las
rejillas.

| Patrón | N = 2–4 | N ≈ 5–6 | N ≈ 9–10 | N ≈ 16–20 | N ≈ 25–36 | N ≥ 50 |
|---|---|---|---|---|---|---|
| **Rejilla regular n × n sobre el área** (X, Y de 100 a 1300 mm) | 2 × 2: **3.45** | — | 3 × 3: **3.54** | 4 × 4: **3.57** | 5 × 5: 3.63; 6 × 6: 3.68 | 8 × 8: 3.74; 10 × 10: 3.66 |
| Aleatorio en toda el área | 4.74 [3.5–8.3] → 4.01 [3.3–5.1] | 3.92 [3.3–4.7] | 3.78 [3.4–4.3] | 3.69 [3.5–4.1] | 3.68 [3.5–3.9] | 3.67 [3.5–3.9] |
| Aleatorio a menos de 0.6 m del LED | 7.2 [3.5–17] → 4.9 | 4.5 [3.2–8.7] | 4.2 [3.2–6.8] | 4.0 [3.2–5.4] | 4.0 [3.2–5.2] | 3.95 |
| Nadir + radios equiespaciados hasta 0.6 m | 3.7 → 3.3 → 3.7 | 3.9–4.1 | 4.5 | 4.8 | 4.9 | 5.0–5.2 (**empeora con N**) |
| Nadir + anillo de 0.3 m | 17.2 | 17.3 | 17.3 | — | — | — |
| Rejilla de 3 × 3 centrada en el LED, paso de 0.10 / 0.20 / 0.40 m | — | — | 21.8 / 17.3 / 3.8 | — | — | — |
| Rejilla de 5 × 5 centrada en el LED, paso de 0.10 / 0.20 / 0.30 m | — | — | — | 17.1 / 5.1 / 4.0 | — | — |

**Cobertura:** 10 puntos al azar dentro de un radio R alrededor del LED (`where_to_calibrate.png`,
derecha).

| R (m), con su φ máximo | 0.3 (9°) | 0.45 (14°) | 0.6 (18°) | 0.8 (23°) | 1.2 (33°) |
|---|---|---|---|---|---|
| Error 3D (mediana) | 16.6 cm | 10.7 cm | 4.0 cm | 4.3 cm | 3.9 cm |

## 4. Conclusiones

1. **Lo que manda es dónde están los puntos, no cuántos hay.** Los puntos tienen que cubrir el rango
   de ángulos de emisión en el que se va a posicionar: aquí φ de 4 a 38°, con mediana de 21°. Los
   puntos cerca del eje del LED estiman bien A, pero para m dan poca información y además sesgada.
2. **Mínimo:** 2 puntos (nadir + uno a φ ≈ 18–20°). Funciona, pero depende mucho de dónde cae el
   segundo punto, y ese óptimo está ajustado a este conjunto de test. **No es una regla robusta.**
3. **Recomendado:** una **rejilla regular de 3 × 3 a 4 × 4 sobre toda el área de trabajo**. Queda a
   menos de 0.1 cm del barrido completo y es determinista, así que no depende de la suerte. Con
   puntos aleatorios en el área hacen falta unos 10–20 para tener la misma seguridad (P90 ≤ 4.3 cm).
4. **No conviene** el patrón "intuitivo" (rejilla o anillo pequeño alrededor del LED): da 17–22 cm.
   Tampoco un patrón radial denso cerca del eje, que empeora al añadir puntos.
5. **A partir de unos 10 puntos bien repartidos**, el error queda limitado por el modelo cos^m
   (suelo de 3.1 cm), no por la calibración.

## 5. Por qué: el patrón no es cos^m con un único m (`figures/apparent_m_vs_phi.png`)

El m aparente de cada punto, calculado con A tomada del nadir, **no es constante**:

| φ | 2–3° | 5–6° | 8–9° | 10–11° | 13–14° | 15–16° | 18–19° | 20–21° | 25–36° |
|---|---|---|---|---|---|---|---|---|---|
| m aparente (mediana) | 11.0 | 9.2 | 8.7 | 8.4 | 7.4 | 6.8 | 6.3 | 6.0 | **5.9–6.1** |

- **Qué significa:** cerca del eje, el producto R_SQ(φ)·L(φ) cae más rápido que cos^m (es "más
  puntiagudo"). A partir de ~20° se estabiliza en m ≈ 6.
- **No es un error de la posición del LED:** el efecto persiste con el LED en (270, 890) o en
  (300, 885).
- **La causa no se puede separar con estos datos**, que solo fijan el producto R·L. Puede ser el LED
  (su lente), la respuesta del PD cerca de la incidencia normal, o una pequeña inclinación del eje
  del LED.
- **De aquí se derivan las conclusiones anteriores:**
  - los puntos cerca del eje empujan m hacia arriba (8–11), y con m alto el error 3D crece mucho;
  - el sistema trabaja sobre todo a φ > 10°, donde m ≈ 6;
  - una rejilla sobre toda el área pondera los ángulos como el uso real.
- **Mejora natural:** un modelo de patrón con más de un parámetro (m dependiente de φ, o un spline,
  eje B del plan, E7/A6). Bajaría el suelo de 3.1 cm.

## 6. Limitaciones

- **Una sola altura de calibración** (h = 1.865 m). El test está a 5 alturas, con el PD entre 0.955
  y 1.315 m, así que la conclusión ya incluye extrapolar a otras alturas.
- **Una muestra de 100 ms por punto.** Promediar varias muestras por punto reduciría algo la
  dispersión con N pequeño.
- **Adaptador plano.** La calibración requiere el adaptador de 0°. Calibrar *in situ* con el
  adaptador de 15° sería otro estudio.
- **Test con el adaptador inclinado.** El error 3D se mide en posiciones con el adaptador de 15°,
  que solo se usan como test, nunca para ajustar. Si se prefiere no usar ningún dato inclinado, la
  columna de error de mapa (`results.json`) da la misma conclusión: 1.65 % con 3 × 3, 1.63 % con
  4 × 4, 1.61 % con todos los puntos, y 27–36 % con las rejillas de 3 × 3 de 10–20 cm de paso o el
  anillo de 0.3 m alrededor del LED.

## Test con los otros LEDs

`test_other_leds.md` aplica las rejillas de 3 × 3 y 4 × 4 a los LEDs de 300, 700 y 900 kHz, como si
se calibraran por primera vez, y posiciona con cada uno. La regla del número de puntos se cumple en
todos. Los errores mayores de esos LEDs vienen de su posición, altura e inclinación, no de la
calibración.

## Test de la altura del LED

`test_led_height.md`: con un solo plano de puntos **no** se puede calibrar la altura del LED; el ajuste
se va a 1.2–5.5 m. Hay que medirla, o usar un segundo plano a otra altura del gantry.

## Reproducir

```
cd CAMBRIDGE/analysis/Calibration
..\..\database_acquisition\.venv\Scripts\python.exe calibration_budget.py
```

Hiperparámetros al inicio del script: posición del LED, offset, valores de N, sorteos, radios y
tamaños de rejilla. Usa la librería `vlp` de la demo, cuyos estimadores reproducen exactamente el
análisis de MATLAB (3.66 cm en las 125 posiciones).
