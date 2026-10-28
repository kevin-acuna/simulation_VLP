# Test: ¿se puede calibrar también la ALTURA del LED con un solo plano de puntos?

*18/10/2026. Script: `test_led_height.py`; salida en `test_led_height_output.txt` y
`led_height_results.json`; figura en `figures/led_height_profile.png`.*

**Respuesta: no.** Con un solo plano de medida (3 × 3, 4 × 4 o incluso los 19 881 puntos), la altura
del LED **no es identificable**: debe ser conocida, o calibrarse con un segundo plano.

## Resultados
Se ajustan juntos la XY del LED, su altura H, A y m. La altura del PD es conocida (el gantry).

| LED | Puntos | H ajustada | m resultante | Error 3D con esa calibración | Con H = 3.0 m |
|---|---|---|---|---|---|
| 500 kHz | 3 × 3 | 4.33 m | 20.8 | 125 cm | **3.5 cm** |
| 500 kHz | 4 × 4 | 1.30 m | −4.6 | 62 cm | **3.2 cm** |
| 500 kHz | todos | 3.64 m | 12.2 | 51 cm | 3.4 cm |
| 300 kHz | 3 × 3 / 4 × 4 / todos | 3.24 / 3.40 / 3.49 m | 8–11 | 29–58 cm | 7–9 cm |
| 900 kHz | 3 × 3 / 4 × 4 / todos | 1.29 / 4.01 / 4.08 m | 0–17 | 87–133 cm | 13 cm |
| 700 kHz | 3 × 3 / 4 × 4 / todos | 4.25 / 4.39 / 4.15 m | 19–23 | 116–144 cm | 24 cm |

**Estabilidad:** moviendo la rejilla ±10–50 mm, la altura ajustada salta entre **1.2 y 5.5 m**. Con
16 puntos al azar, el P10–P90 va de 1.9 a 4.8 m.

## Por qué
- **El perfil es casi plano** (`figures/led_height_profile.png`). Al pasar la altura de 3.0 a 3.8 m,
  el error del ajuste cambia solo un 0.2–1 %: A y m compensan el cambio.
  - Un LED más alto se ve más lejos (d² mayor), pero también con ángulos más pequeños.
  - Un m mayor y una A mayor reproducen casi el mismo mapa de RSS en un plano.
- **El desajuste del modelo arrastra la altura.** El m aparente varía con φ (`README.md`, sección 5),
  así que con la altura libre el ajuste se va a valores absurdos (m de 12 a 23, o negativo). El error
  3D sale de 0.5 a 1.4 m.
- **Con la altura fija y conocida, todo funciona:** XY, A y m sí se identifican con 9–16 puntos (3.2–3.5
  cm con el LED de 500 kHz).

## Qué hacer
- **Medir la altura del LED** (cinta o telémetro láser, una vez) y calibrar XY, A y m con un plano de
  3 × 3 o 4 × 4 puntos.
- **Alternativa sin medir la altura:** un **segundo plano** de puntos a otra altura del gantry,
  conocida (por ejemplo 9 puntos a z = 360 y 9 a z = 0). Entre los dos planos, la distancia d cambia
  de forma conocida y se separa de A y m. Es la misma idea que permitiría separar la inclinación del
  LED. Requiere el barrido de E7 para comprobarlo.
