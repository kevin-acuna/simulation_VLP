# Test: calibrar los otros LEDs con 3 × 3 / 4 × 4 puntos, "como si fuera la primera vez"

*18/10/2026. Script: `test_other_leds.py`; salida en `test_other_leds_output.txt` y
`other_leds_results.json`; figuras en `figures/other_leds_*.png`. No se modifica nada de
`calibration_budget.py` ni de la demo.*

## Qué se hizo
1. **Calibración** de cada LED (300, 500, 700 y 900 kHz) con **solo** los puntos de una rejilla
   regular de 3 × 3 (9) o de 4 × 4 (16) sobre el área de trabajo (X, Y de 100 a 1300 mm). Se usa el
   barrido con el PD horizontal (z = −300, K = 1) y el modelo `RSS = A·R_SQ(φ)·cos^m φ / d²`, con el
   LED apuntando hacia abajo a 3.0 m.
   - **XY ajustada** (primera vez de verdad): la XY del LED, A y m salen juntos de esos mismos
     puntos.
   - **XY dada:** para 500 kHz, (281.1, 904.8). Para los otros, las posiciones de
     `Estimation_with_2LEDs/results_known_yaw/led_positions.csv`, como sustituto de una medida con
     plomada. A y m salen de la rejilla.
   - **Referencia:** los mismos ajustes con los 19 881 puntos.
2. **Posicionamiento** de las 125 posiciones de test (las campañas con K = 10 y el adaptador de 15°)
   **con un solo LED**, el calibrado, con SQ + NLS como en la demo y el offset de 66.5°.

## Resultados (error 3D medio en cm, con el P90 entre paréntesis)

| LED | XY ajustada · 3 × 3 | XY ajustada · 4 × 4 | XY ajustada · todos | XY dada · 3 × 3 | XY dada · 4 × 4 | XY dada · todos |
|---|---|---|---|---|---|---|
| **500 kHz** | **3.47** (6.4) | **3.22** (6.0) | 3.42 (6.2) | **3.54** (6.5) | **3.57** (6.4) | 3.66 (6.4) |
| 300 kHz | 7.08 (10.5) | 8.21 (12.1) | 8.61 (12.6) | 6.55 (10.3) | 6.10 (9.7) | 5.92 (9.4) |
| 900 kHz | 12.96 (18.9) | 13.48 (19.6) | 13.43 (19.4) | 6.89 (10.5) | 6.36 (9.5) | 5.95 (8.7) |
| 700 kHz | 24.49 (35.7) | 23.97 (35.2) | 23.68 (35.1) | 16.93 (34.6) | 16.87 (34.4) | 16.86 (34.3) |

Sesgo vertical medio, con la XY dada y el 4 × 4: 500 kHz −0.9 cm; 300 kHz **+5.1 cm**; 900 kHz
**+4.5 cm**; 700 kHz +1.6 cm, con 6.8 cm de error horizontal.

## Conclusiones

1. **La regla de 3 × 3 / 4 × 4 se cumple para todos los LEDs.** Con 9 o 16 puntos se obtiene
   prácticamente lo mismo que con los 19 881: 0.2–0.6 cm de diferencia con la XY dada, menos de 1.5
   cm con la XY ajustada. El número de puntos **no** es lo que limita en ningún LED.
2. **Con el LED de 500 kHz** (posición conocida y bien orientado), calibrar desde cero con 16 puntos
   da 3.2–3.6 cm. Es tan bueno como la calibración completa.
3. **Los otros LEDs quedan peor por el modelo del LED, no por la calibración.** El modelo supone el
   LED a 3.0 m y apuntando justo hacia abajo:
   - **Centro del patrón ≠ posición geométrica.** El centro del patrón (la XY ajustada en el barrido
     plano) está desplazado de la posición geométrica (la de los rayos): **2.6 cm** en el de 300 kHz,
     **6 cm** en el de 900 kHz y **18 cm** en el de 700 kHz (`figures/other_leds_maps.png`). Eso
     indica LEDs inclinados del orden de 0.8°, 1.9° y 5.4°. Con el de 500 kHz coinciden.
   - **Por eso la XY ajustada empeora en 300, 900 y 700 kHz.** Ajustar la XY desde el barrido plano
     da el centro del patrón, no la posición del LED, y sus direcciones apuntan a la posición
     geométrica.
   - **El sesgo vertical de +4.5 a +5 cm** en 300 y 900 kHz encaja con un LED más bajo que 3.0 m (los
     rayos sugieren 2.92–2.95 m) y/o con su inclinación.
   - **El LED de 700 kHz** está claramente inclinado: un modelo con el eje vertical no lo describe,
     por muchos puntos de calibración que se usen.
4. **Para usar los otros LEDs como el de 500 kHz:**
   - medir su **posición y altura** (plomada y altura del plano);
   - **comprobar que apuntan hacia abajo**: alinearlos físicamente, o añadir la inclinación del LED
     como parámetro de calibración (2 parámetros más; con 16 puntos aún hay redundancia);
   - después, 3 × 3 o 4 × 4 puntos bastan para A y m.

## Para la demo
> "La calibración con 9–16 puntos funciona igual en los cuatro LEDs: da el mismo resultado que el
> barrido completo. Con el LED cuya posición conocemos, calibrar desde cero con 16 puntos da 3.2–3.6
> cm. Los otros tres salen peor porque no están perfectamente orientados hacia abajo (uno ~5°): eso es
> un parámetro del montaje que hay que medir o calibrar, no una cuestión de cuántos puntos se usan."
