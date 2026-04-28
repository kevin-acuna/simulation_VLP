# Analisis: DEB, orientaciones optimas, y narrativa del paper

## 1. El problema observado

Con orientaciones PEB-optimizadas (50 deg):
- DF:  GLS: 0.709 | NL-MLE: 0.620 | DEB: 0.558
- 3D:  GLS: 2.71cm | NL-MLE: 2.32cm | PEB: 1.55cm

Con orientaciones DEB-optimizadas (66 deg):
- DF:  GLS: 0.760 | NL-MLE: 0.560 | DEB: 0.518
- 3D:  GLS: 2.90cm | NL-MLE: 2.12cm | PEB: 1.64cm

Observacion: DEB-opt mejora NL-MLE (+10%) pero empeora GLS (-7%) y PEB (-6%).

## 2. Diagnostico

### El DEB y el GLS optimizan cosas diferentes

El DEB mide la Fisher Information del modelo de potencias absolutas:
  mu_i = eta * (n_{t,i} . n_d)^m

El GLS opera sobre ratios:
  beta_i = (mu_i/mu_1)^{1/m} = cos(phi_i)/cos(phi_1)

La FIM del DEB y la informacion efectiva para ratios NO son la misma.

Con 66 deg: los cos^m(phi_i) son mas pequenos -> las potencias son menores
-> los ratios beta_i tienen mas varianza (mu_1 mas chico en el denominador)
-> GLS pierde precision.

Con 50 deg: potencias mas balanceadas -> ratios mas estables -> GLS gana.

### Conclusion tecnica
El set de orientaciones optimo DEPENDE del estimador:
- DEB-opt favorece estimadores de potencia absoluta (NL-MLE)
- PEB-opt favorece estimadores de ratios (GLS/WLS)
- Esto es un resultado teorico genuino, no un bug

## 3. Opciones para el paper

### Opcion A: Un solo set de orientaciones (PEB-opt) para todo
- Usar PEB-opt (el que ya tienes) para todos los estimadores
- NL-MLE usa las mismas orientaciones que GLS/WLS
- DEB se calcula con esas orientaciones
- Narrativa: "We optimize the orientation set to minimize the PEB. 
  All estimators are evaluated under this common configuration."

**Pros:**
- Simple, sin confusion
- GLS/WLS dan sus mejores resultados
- NL-MLE sigue siendo mejor que GLS (2.32 vs 2.71 cm) incluso con orientaciones "suboptimas" para el
- El DEB sigue estando por debajo de todos los estimadores (es un bound valido)
- Consistente con el paper original (orientaciones PEB-opt ya estan en Table III)

**Contras:**
- No se muestra el potencial maximo del NL-MLE
- La GA de DEB que acabas de correr no se usa en el paper

**Esfuerzo:** Minimo. Solo necesitas las orientaciones que ya tienes.

### Opcion B: Dos sets (PEB-opt para GLS/WLS, DEB-opt para NL-MLE)
- En resultados, NL-MLE usa su propio set optimo
- GLS/WLS usan PEB-opt

**Pros:**
- Cada estimador da su mejor resultado

**Contras:**
- Confuso: el reviewer preguntara por que usan sets diferentes
- No es una comparacion justa (diferentes inputs)
- Complica la narrativa sin agregar insight significativo

**Esfuerzo:** Alto en explicacion, bajo en simulacion.

### Opcion C: Derivar un CRLB-DF basado en ratios (futuro trabajo)
- El bound correcto para GLS seria un CRLB del modelo de ratios
- Pero esto requiere una derivacion nueva y no trivial
- Mejor dejarlo como future work

## 4. Recomendacion: OPCION A

Usar UN SOLO set de orientaciones (PEB-opt) para todo. Razones:

1. **Ya tienes todo simulado** con PEB-opt. Table III del paper no cambia.

2. **NL-MLE igualmente supera a GLS** con PEB-opt (2.32 vs 2.71 cm en 3D, 
   0.620 vs 0.709 deg en DF). La narrativa se mantiene.

3. **El DEB es un bound valido** con cualquier orientacion. Con PEB-opt el 
   DEB es 0.558 deg, y NL-MLE logra 0.620 deg (gap del 11%). Esto muestra 
   que NL-MLE se acerca al bound.

4. **La optimizacion GA del DEB** se puede mencionar en una linea:
   "A separate DEB-optimized orientation set further reduces the NL-MLE 
   error to 0.56 deg (from 0.62 deg), confirming that the orientation 
   design influences estimator performance. However, for a fair comparison, 
   all results are reported under the common PEB-optimized configuration."

5. **Evita la confusion de multiples sets**. Un set, tres estimadores, 
   dos bounds (DEB para DF, PEB para 3D). Limpio.

## 5. Narrativa propuesta para el paper

### Seccion III: Position Error Bound
- Mantener PEB como bound conjunto 3D (K+1 mediciones)
- Agregar subseccion III-C: Direction Error Bound (DEB) para K mediciones
- "The DEB serves as a benchmark for the direction-finding stage, 
  while the PEB bounds the complete 3D positioning pipeline."

### Seccion IV: Orientation Optimization
- Mantener GA que minimiza RMS-PEB (ya existente)
- Agregar una frase: "These PEB-optimized orientations are used 
  throughout the simulations for all estimators."
- NO mencionar DEB-optimization en el cuerpo del paper (solo en discusion)

### Seccion V: NL Direction-Finding Baseline
- Presentar NL-MLE como profile MLE (nueva formulacion)
- Comparar con DEB en Sec VII

### Seccion VII: Results
- VII-A: Direction Finding Performance
  - CDF angular: GLS, WLS, NL-MLE, DEB (todos con PEB-opt orientations)
  - Tabla: RMSE, CDF90, APE en grados
  - "NL-MLE achieves sub-degree error and approaches the DEB, validating 
    its MLE interpretation. GLS provides comparable accuracy in closed form."
  
- VII-B: 3D Positioning Performance
  - CDF posicion: GLS, WLS, NL-MLE, PEB (todos con PEB-opt)
  - Tabla: RMSE, CDF90, APE en cm
  - "The direction-finding advantage of NL-MLE propagates to 3D positioning, 
    where it achieves 2.3 cm RMSE versus 2.7 cm for GLS."

- VII-D: Discussion
  - Parrafo sobre orientacion-estimador coupling:
    "The PEB-optimized orientation set was designed to minimize the 
    joint position bound. Separate optimization for the DEB yields a 
    different set that further improves NL-MLE direction accuracy by ~10%, 
    at the expense of GLS/WLS performance. This estimator-dependent 
    sensitivity suggests that co-design of orientation sets and estimation 
    algorithms is a promising direction for future work."

## 6. Que hacer con las simulaciones DEB-opt que ya corriste

- Guardarlas en results/ como referencia
- Usar en system_params.m con nombres claros (orientations_DEB_K5, etc.)
- NO usar como orientaciones principales del paper
- Mencionar como resultado secundario en Discussion (1 parrafo)

## 7. Resumen de accion

| Item | Accion |
|------|--------|
| Orientaciones del paper | PEB-opt (Table III, sin cambios) |
| DEB derivacion | Agregar como Sec III-C (DEB_formulation.tex) |
| NL-MLE formulacion | Agregar como Sec V (NL_MLE_section_revised.tex) |
| Fig nueva: CDF angular | run_DF_comparison.m con PEB-opt orientations |
| Fig existente: CDF 3D | run_3D_comparison.m con PEB-opt (o run_GLS_WLS_estimator.m) |
| DEB-opt orientaciones | Mencionar en Discussion, no usar como principales |
| Tabla nueva: DF metrics | RMSE, CDF90, APE en grados para GLS, WLS, NL-MLE, DEB |
