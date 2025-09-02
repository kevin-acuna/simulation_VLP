#### Pendientes

* [ ] Realizar las simulaciones para el caso de optimización por cada método.
* [ ] Observaciones en el Paper
* [ ] Definicion del SNR (mix entre Optical y Electrical)
* [ ] INTRODUCCIÓN :  Aqui añadir una tabla con la comparativa de distintos métodos de Single VLP.
* [ ] RESULTADOS: Aqui sería ideal presentar una tabla comparativa de los principales resultados con otros métodos.
* [ ] Corregir las observaciones de LUC, BASTIEN, HONGYU

#### Redacción

* [ ] Redactar la INTRODUCCION
* [ ] Reredacción del ABSTRACT
* [ ] Redactar las CONCLUSIONES
* [ ] Llegar a 25 REFERENCIAS

#### Preguntas a resolver:

* Como armonizar las ideas en un escenario beamstearing de OWP y OWC para lograr un ISAC beamstearing y evitar perder el LOS (habitualmente requiero orientaciones heterogeneas para OWP como una "epilepsia", mientras que para "OWC" seria mejor que siga al usuario (puede tener pausas y mirar a cada usuario? es decir el link TX-RX1, Tx-Rx2, Tx-Rx3, ... puede hacerse en diferentes instantes y sin perder performance o BER ? ) ya que de ser el caso entonces podemos anunciar un escenario con N robots (N>=5) donde el mismo link LOS de comunicacion genera informacion para auto-localizarse, es decir con N-robots se no es necesario escoger las N-orientaciones fijas, sino que se puede usar las N-orientaciones que apuntan hacia los N-robots y asi poder estimar la posicion a cada instante de itempo).


---

JOURNALS TARGET

| Journal                                                    | Time       | Impact Factor | Documents (VLP) | Comment | Experiment                |
| ---------------------------------------------------------- | ---------- | ------------- | --------------- | ------- | ------------------------- |
| IEEE Transactions on Instrumentation and Measurement (TIM) | 21w (5m)   | 5.9 (Q1)     | 14 (2025: 1)    | Good    | Yes (mostly)              |
| IEEE Transactions on Wireless Communications (TWC)         | 35w (9m)   | 10.7 (Q1)    | 10 (2025: 0)    | -       |                           |
| IEEE Transactions on Communications (TCOM)                 | 32w (8m)   | 8.3 (Q1)     | 11 (2025: 3)    | Good    | Experiments / Simulations |
| Journal of Lightwave Technology (JLT)                      | 15.9w (4m) | 4.8 (Q1)      | 21 (2025: 2)    | Good    | Yes (mostly)              |
| Applied Optics                                             | -          | -             | -               | -       |                           |
| IEEE Transactions on Broadcasting                          | 17w (4m)   | 4.8 (Q1)     | 4 (2025: 0)     | -       |                           |
| IEEE Transactions on Green Communications and Networking   | 27w (7m)   | 6.7 (Q1)      | 2 (2025: 2)     | New     |                           |

---

#### PROPUESTAS DE PAPERS Y DE TRABAJOS

* Estudio teórico (optimización) y SIMULACIONES de estimación de la posición en 3D empleando N-PD.
* Estudio teórico (optimización), SIMULACIONES y EXPERIMENTAL de la estimación de posición 3D empleando 1PD y N-Transmisores en BeamStearing (N < 4 sería ideal para obtener ventaja frente a las estructuras tradicionales del VLP).
  * Comentario: Este planteamiento debe pensarse con más detenimiento porque la ventaja de usar Single-VLP es el número de Transmisores, pero si este aumenta entonces debe de justificarse su respectivas ventajas ya no solo frente a un Single-VLP sino tambien a un Tradicional VLP (4 Tx fijos)
* asdasd

#### PLAN DE TRABAJO

| MES       | AÑO | OBJETIVO                                                                       | ACTIVIDADES                                            | TEMA DE INVESTIGACION                                | EVENTO                        |
| --------- | ---- | ------------------------------------------------------------------------------ | ------------------------------------------------------ | ---------------------------------------------------- | ----------------------------- |
| SETIEMBRE | 2025 | JOURNAL<br />CSI REGISTRO<br />REINSCRIPCIÓN<br />REVISION JOURNAL IEEE Trans | Revisión<br />Redacción<br />Visa para UK            | 3D Single VLP MODEL-BASED:<br />TEÓRICO/SIMULACIÓN | JOURNAL 1                     |
| OCTUBRE   | 2025 | BASE DE DATOS<br />PROCESAR SEÑALES                                           |                                                        | 3D Single VLP MODEL-BASED:<br />EXPERIMENTAL         | ICC 2026<br />WCNC 2026       |
| NOVIEMBRE | 2025 | MACHINE LEARNING                                                               | Realizar el entrenamiento<br />empleando ML, DL        | 3D Single VLP DATA-DRIVEN                            | Meeting OPTI-6G<br />(Brunel) |
| DICIEMBRE | 2025 | MACHINE LEARNING<br />VACACIONES (20 DIC)                                      | Realizar el entrenamiento<br />con Physics Informed NN | 3D Single VLP DATA-DRIVEN                            | JOURNAL 2                     |
| ENERO     | 2026 | VACACIONES                                                                     | VACACIONES                                             | VACACIONES                                           | VACACIONES                    |
| FEBRERO   | 2026 | NACIMIENTO DE BEBE                                                             | LICENCIA                                               | LICENCIA                                             | LICENCIA                      |
| MARZO     | 2026 |                                                                                |                                                        |                                                      | PIMRC 2026                    |
| ABRIL     | 2026 |                                                                                |                                                        |                                                      | GLOBECOM<br />2026            |
| MAYO      | 2026 |                                                                                |                                                        |                                                      | IPIN 2026                     |
| JUNIO     | 2026 |                                                                                |                                                        |                                                      |                               |
| JULIO     | 2026 |                                                                                |                                                        |                                                      |                               |
| AGOSTO    | 2026 | VACACIONES                                                                     | VACACIONES                                             | VACACIONES                                           | VACACIONES                    |
| SETIEMBRE | 2026 | INTERCAMBIO A CAMBRIEGE<br />(Ideal: 15 de setiembre)                          | INTERCAMBIO                                            | POR DEFINIR                                          | POR DEFINIR                   |
| OCTUBRE   | 2026 | INTERCAMBIO A CAMBRIEGE                                                        | INTERCAMBIO                                            | POR DEFINIR                                          | POR DEFINIR                   |
| NOVIEMBRE | 2026 | INTERCAMBIO A CAMBRIEGE                                                        | INTERCAMBIO                                            | POR DEFINIR                                          | POR DEFINIR                   |
| DICIEMBRE | 2026 |                                                                                |                                                        |                                                      |                               |
