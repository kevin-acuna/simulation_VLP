#### Elaborado: 01/07/2026
#### Venues candidatos para el Journal Track 3 (objetivo: Q1)

El contenido combina: (i) testbed robótico y calibración instrumental, (ii) posicionamiento óptico inalámbrico (VLP/OWP) con beam-steering, (iii) comparación cooperativo vs. broadcast con relevancia para IoT/multi-usuario, y (iv) corrección de modelo (quasi-Lambertiano) vía calibración empírica. Esta combinación orienta la selección de venue.

---

## Candidatos principales

### 1. IEEE Internet of Things Journal (IoT-J)
- **Fit:** el eje (D1) — posicionamiento *broadcast* que sirve simultáneamente a múltiples receptores pasivos sin medición dedicada — es exactamente el tipo de narrativa que valora esta revista (escalabilidad, bajo overhead, aplicabilidad a despliegues IoT densos).
- **Consideración:** enfatizar en la introducción el caso de uso multi-dispositivo/IoT, no solo el 3D positioning per se.
- **Impacto:** muy alto (Q1, JCR top decile en su categoría).

### 2. IEEE Transactions on Instrumentation and Measurement (TIM)
- **Fit:** el paper es, en gran parte, un ejercicio de caracterización instrumental (calibración de `R(φ)`, calibración de `C`, testbed robótico, análisis de ruido/repetibilidad). TIM valora explícitamente contribuciones de "measurement system + calibration methodology".
- **Consideración:** reforzar la sección de calibración (eje B) como contribución metodológica de medición, no solo como paso previo a la posición.
- **Impacto:** alto (Q1).

### 3. IEEE Photonics Journal
- **Fit:** revista de acceso abierto de IEEE Photonics Society, acostumbrada a papers de sistemas OWC/VLP con validación experimental de hardware óptico (LEDs, PDs, beam-steering).
- **Consideración:** buen respaldo si se quiere mantener el énfasis fotónico/óptico del sistema (LED, gimbal, patrón de radiación) sobre el ángulo de "sistema de comunicaciones".
- **Impacto:** alto (Q1/Q2 según año, pero bien indexado y de revisión rápida).

### 4. IEEE Sensors Journal
- **Fit:** el receptor (PD + TIA + amplificador) y su caracterización, junto con el testbed robótico como "sensor de ground truth", encajan con el foco de esta revista en sistemas de sensado y sus aplicaciones (incluye VLP como área reconocida).
- **Consideración:** viable si se enfatiza el receptor/PD y la campaña de datos como contribución de sensado, más que la teoría de estimación.
- **Impacto:** alto (Q1).

### 5. IEEE/OSA Journal of Lightwave Technology (JLT)
- **Fit:** posible si se enmarca fuertemente como sistema de comunicación óptica inalámbrica indoor (beam-steering, enlace óptico, caracterización de canal). Es más exigente en el ángulo "communications/photonics" que en el de "positioning system".
- **Consideración:** venue de mayor prestigio pero también mayor exigencia/tiempo de revisión; considerar solo si el ángulo de "canal óptico" se puede fortalecer.
- **Impacto:** muy alto (Q1 top), pero riesgo de mismatch temático si el foco final es más "positioning" que "communications".

---

## Recomendación de orden de intento

1. **IEEE Internet of Things Journal** — mejor alineación temática con la contribución diferenciadora (D1: broadcast multi-usuario), buen impacto, revisión razonablemente ágil.
2. **IEEE Transactions on Instrumentation and Measurement** — mejor alineación con el contenido de calibración/testbed (ejes A, B, C), como alternativa si IoT-J rechaza por considerarlo "no suficientemente IoT".
3. **IEEE Photonics Journal** o **IEEE Sensors Journal** — alternativas sólidas de Q1 si se prefiere un ángulo más fotónico/sensado.
4. **JLT** — opción de mayor prestigio, a considerar solo si el paper final enfatiza fuertemente el canal óptico de comunicación.

## Nota
Evitar reenviar a **IEEE Transactions on Communications** (donde ya está `TCOM`) para no generar percepción de solapamiento/auto-plagio, salvo que el manuscrito final se diferencie muy claramente en enfoque (comunicaciones vs. sistema experimental de posicionamiento).
