#### Elaborado: 01/07/2026
#### Track: 3 — Journal (Q1): Validación Experimental de los métodos model-based
#### Estado: Sin empezar — planificación inicial

---

## 1. Resumen del trabajo

Este journal busca dar **validación experimental completa** a los dos pipelines de posicionamiento óptico inalámbrico basados en un único LED con beam-steering (SBL) desarrollados teóricamente por el grupo:

- **Pipeline cooperativo** (`TCOM`): direction finding con `K` orientaciones + distance recovery mediante una medición cooperativa adicional `(K+1)`-ésima (LED alineado al receptor, PD reorientado hacia el LED).
- **Pipeline broadcast** (`F_broadcast_Konly`): direction finding con las **mismas** `K` orientaciones + distance recovery en forma cerrada (`η̂ → d̂`), explotando el conocimiento de la orientación del receptor `n_r`, sin necesidad de la medición `(K+1)`.

El antecedente experimental directo es `GLOBECOM_2026` (*"Experimental Validation of Model-Based 3D Optical Wireless Positioning Using a Single Beam-Steered LED"*), que validó el pipeline cooperativo con GLS/WLS sobre 300 puntos. Sin embargo, **el dataset de esa campaña quedó invalidado**: el driver del LED transmisor tenía un fallo de alimentación que distorsionaba el patrón de irradiación (ya corregido). Este journal parte de una **campaña de adquisición completamente nueva**.

## 2. Objetivos / ejes de contribución

Referencia: `papers_plan_for_PhD.md`, Decisión 3.

- **(A) Completar estimadores.** Añadir NLS (ausente en `GLOBECOM_2026`, que solo usó GLS/WLS) a la comparación experimental. Primera confirmación experimental de que NLS se acerca al bound (PEB) mientras GLS/WLS presentan un gap estructural — ya observado en simulación en `TCOM` y `F_broadcast_Konly`.
- **(B) Corrección quasi-Lambertiana.** Calibrar el patrón de radiación real `R(φ)` del LED (goniómetro o barrido dedicado con el gimbal) y usarlo directamente en NLS (`R_spline(φ)`) en lugar de asumir `cos^m(φ)` puro. Es literalmente el *future work* que `GLOBECOM_2026` se auto-asignó. Pieza mínima extraída de `Tracks_PROPOSALS/NL_general_proposal.md` (framework general, parked — solo se usa esta subsección práctica).
- **(C) Dataset espacial completo.** ~2000 puntos (vs. 300/1125 de `GLOBECOM_2026`), permitiendo CDF y heatmaps espaciales rigurosos comparados contra PEB_C (`TCOM`) y PEB_B (`F_broadcast_Konly`).
- **(D1) Comparación cooperativo vs. broadcast — alcance base.** Con la pose completa del robot (UR5) registrada en cada punto, se reprocesa el mismo dataset con ambos pipelines. Responde experimentalmente a la pregunta central de `F_broadcast_Konly`: *¿cuánto cuesta en la práctica eliminar la medición cooperativa `(K+1)`?*
- **(D2) Barrido deliberado de tilt — extensión opcional.** Validar experimentalmente la curva PEB_B-vs-tilt de `F_broadcast_Konly` variando deliberadamente `n_r` en un subconjunto de puntos. No es alcance base; se añade solo si el tiempo/testbed lo permiten.

## 3. Relación con otros trabajos del grupo

| Documento | Rol en este journal |
|---|---|
| `TCOM/Final_submission_RV2/...` | Teoría del pipeline cooperativo (PEB_C, GLS/WLS/NLS) — validado aquí experimentalmente en full. |
| `F_broadcast_Konly/paper/main.tex` | Teoría del pipeline broadcast (PEB_B) — recibe aquí su primera validación experimental. |
| `GLOBECOM_2026/main.tex` | Antecedente experimental directo (metodología reutilizable, dataset NO reutilizable). |
| `Tracks_PROPOSALS/NL_general_proposal.md` | Fuente de la pieza mínima de calibración quasi-Lambertiana (eje B). Framework completo permanece parked. |

## 4. Estructura tentativa del paper

1. Introducción (motivación: de la teoría a la validación de campo; gap dejado por `GLOBECOM_2026`).
2. Modelo del sistema y resumen de los dos pipelines (cooperativo/broadcast).
3. Testbed experimental (hardware, protocolo de adquisición — ver `dataset_specification.md`).
4. Calibración del patrón de radiación real y corrección quasi-Lambertiana (eje B).
5. Resultados: comparación de estimadores (GLS/WLS/NLS) sobre el dataset completo (eje A, C).
6. Resultados: cooperativo vs. broadcast — precisión vs. costo de medición (eje D1).
7. (Opcional) Sensibilidad a tilt real (eje D2).
8. Conclusiones.

## 5. Próximos pasos

- [ ] Confirmar reparación y estabilidad del driver del LED antes de iniciar la campaña.
- [ ] Definir protocolo de adquisición completo (ver `dataset_specification.md`).
- [ ] Ejecutar barrido de calibración de `R(φ)` (independiente del barrido espacial).
- [ ] Ejecutar campaña espacial completa (~2000 puntos).
- [ ] Reprocesar dataset con GLS/WLS/NLS × {cooperativo, broadcast}.
- [ ] Redactar manuscrito y seleccionar venue (ver `target_venues.md`).
