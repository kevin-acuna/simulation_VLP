#### Elaborado: 01/07/2026 — Última revisión: 01/07/2026 (sesión de análisis con Cascade)
#### Motivo: Plan global de publicaciones para el 3er año del PhD, tras revisar el CSI report del segundo año.

---

## 1. Tracks del año 3

| # | Track | Tipo | Estado |
|---|---|---|---|
| 1 | Tracking usando Beamsteering | Conference | Solo arquitectura/ideas (`Tracks_PROPOSALS/Beam-Tracking.md`) |
| 2 | Estimación 3D con VCSEL | Conference | Plan detallado, simulación apenas iniciada (`VCSEL_3D/`) |
| 3 | Validación Experimental de los métodos model-based | Journal (Q1) | Planificación inicial en `ExpValidation_Journal/` — requiere nueva campaña experimental completa (ver §3) |
| 4 | F_broadcast_Konly | Conference | **Completo, listo para enviar** (`F_broadcast_Konly/paper/main.tex`) |
| 5 | Paper de redes neuronales PINN | Journal | Solo conceptual |
| 6 | Dispositivo multi-LED para posicionamiento real-time | Implementación/paper | Solo conceptual |

Contexto adicional ya existente (no listado como track propio, pero relevante):
- `GLOBECOM_2026/main.tex`: conference **ya enviado**, validación experimental de **TCOM** (método cooperativo K+1) con GLS/WLS, 300 puntos. **El dataset de esta campaña queda invalidado**: el driver del LED transmisor tenía un fallo de alimentación que distorsionaba el patrón de irradiación (ya corregido). Cualquier trabajo futuro requiere una campaña de adquisición nueva.
- `Tracks_PROPOSALS/NL_general_proposal.md`: framework teórico para R(φ) arbitrario (no-Lambertiano general). **Parked**, ver Decisión 4.

---

## 2. Decisiones tomadas

**Decisión 1 — F_broadcast_Konly se envía tal cual, ya.**
El paper (`F_broadcast_Konly/paper/main.tex`) está completo (IEEEtran conference, 6 páginas: 3 contribuciones, PEB_B derivado, análisis paramétrico K/tilt/SNR, Monte Carlo GLS/WLS/NLS, demo multi-usuario). Se envía a conference (GLOBECOM 12 ago 2026, o ISAC como alternativa) sin fusionarlo con el journal experimental.

**Decisión 2 — Estrategia de publicación: Opción 1 (conference + journal separados), no Opción 2 (todo junto).**
- El conference tiene coste marginal ≈0 de enviarse ya; fusionarlo en un journal (Opción 2) lo retrasaría sin ganancia real.
- IEEE exige ~30-50% de contenido nuevo para extender un conference a journal — eso es justo lo que da la Opción 1 de forma natural.
- El journal se reformula para no ser "solo validación" (Decisión 3), resolviendo la objeción de que quede escueto.

**Decisión 3 — El journal (track 3) valida los DOS pipelines (cooperativo TCOM + broadcast F_broadcast_Konly) con una única campaña experimental nueva.**

El dataset de `GLOBECOM_2026` no es reutilizable (driver defectuoso). Como hay que rehacer la campaña completa de todos modos, se diseña desde cero para servir a ambos papers a la vez:
- En cada uno de los ~2000 puntos del testbed se registran: las `K` medidas de dirección, la medición cooperativa `(K+1)`-ésima (TCOM), y la **pose completa del UR5** (posición + orientación del PD).
- Con eso, el mismo dataset se reprocesa en dos pipelines: **cooperativo** (TCOM: dirección + `K+1` para distancia) y **broadcast** (F_broadcast_Konly: dirección + `η̂→d̂` en forma cerrada usando el `n_r` ya conocido por el robot, sin `K+1`).
- Esto responde de forma experimental a la pregunta central de F_broadcast_Konly: *¿cuánto cuesta en la práctica eliminar la medición cooperativa?* — algo que ni `GLOBECOM_2026` ni el conference de F_broadcast (solo simulado) pueden mostrar por sí solos.

Ejes de novedad del journal respecto a `GLOBECOM_2026` (ninguno solapado):
- **(A) Completar estimadores:** añadir NLS (ausente en GLOBECOM_2026) — primera confirmación experimental de que NLS≈bound mientras GLS/WLS tienen gap.
- **(B) Corrección quasi-Lambertiana:** calibrar R(φ) empírico y usarlo en NLS (R_spline) en vez de cos^m puro. Es literalmente el future work que `GLOBECOM_2026` se auto-asignó. Pieza mínima extraída de `NL_general_proposal.md` (ver Decisión 4), beneficia a ambos pipelines por igual.
- **(C) Dataset completo:** ~2000 puntos (vs. 300/1125 de GLOBECOM_2026), permitiendo CDF/heatmaps espaciales rigurosos vs. PEB_C (TCOM) y PEB_B (F_broadcast).
- **(D1) Comparación cooperativo vs. broadcast:** alcance base (Decisión 3), costo marginal nulo al ya loguear la pose del robot.
- **(D2) Barrido deliberado de tilt** (para trazar la curva PEB_B-vs-tilt específicamente, más allá de la pose natural de cada punto): **extensión opcional**, no alcance base — requiere diseño experimental adicional más allá de lo que D1 ya cubre.

**Decisión 4 — NL-general: parked, no se ejecuta como paper completo.**
`Tracks_PROPOSALS/NL_general_proposal.md` queda como registro/futuro trabajo (posible tema para otro estudiante). No se desarrolla su alcance completo (FIM generalizada, perfiles sintéticos batwing/flat-top, demostración formal de incompatibilidad de GLS, estimador híbrido). Solo se extrae la pieza mínima (secciones 2.2–2.4) como eje (B) del journal:
- Calibrar R(φ) real del LED.
- Ajustar `m_eff` escalar y cuantificar el bias si se asume cos^m puro.
- Mostrar que NLS con R_spline(φ) medido elimina ese bias; GLS/WLS lo heredan (requieren monomio para linearizar).

Esto evita el riesgo de "quemar" el journal: al ser calibración práctica de una subsección y no contribución teórica central, no se abre la puerta a que un revisor exija el tratamiento general.

---

## 3. Estado y prioridad de los tracks

| Track | Carpeta | Estado | Prioridad |
|---|---|---|---|
| F_broadcast_Konly (conference) | `F_broadcast_Konly/paper/main.tex` | ✅ Listo para enviar | Máxima — GLOBECOM 12 ago |
| Journal experimental (track 3) | — (sin carpeta aún) | Requiere nueva campaña ~2000 puntos (cooperativo + broadcast + pose UR5) | Alta, depende de disponibilidad de testbed |
| Conference VCSEL 3D (track 2) | `VCSEL_3D/` | Plan detallado, simulación apenas iniciada | Media |
| Conference Tracking (track 1) | `Tracks_PROPOSALS/Beam-Tracking.md` | Solo arquitectura/ideas | Media-baja |
| Journal PINN (track 5) | — | Solo conceptual | Baja (año 3 tardío) |
| Multi-LED device (track 6) | — | Solo conceptual | Baja (año 3 tardío / año 4) |
| NL-general (framework completo) | `Tracks_PROPOSALS/NL_general_proposal.md` | **Parked** — no se ejecuta | — |
| `GLOBECOM_2026` | `GLOBECOM_2026/main.tex` | Enviado; dataset invalidado por fallo de driver (ya corregido) | — |

---

## 4. Hilo transversal potencial: tres niveles de modelo TX/RX

Idea a explotar en uno o más papers (probablemente el journal experimental, eje B):
- **Modelo teórico:** cos(φ)^m y cos(ψ) — usado en todo el análisis de simulación (TCOM, F_broadcast_Konly).
- **Modelo empírico:** datasheet del LED — "implementación" práctica pero aún simulada en MATLAB.
- **Modelo experimental (datos reales):** debería aproximarse al datasheet — es la validación final de los dos anteriores.
