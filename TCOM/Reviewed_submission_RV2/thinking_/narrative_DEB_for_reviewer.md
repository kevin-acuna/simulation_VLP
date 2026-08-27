# Narrativa del DEB para convencer al Reviewer 2

## El problema del reviewer

El reviewer pidio (Comment #11): "include MLE as baseline" y (Comment #13):
"explain the gap between NL and CRLB". El paper original tenia:
- PEB como bound (3D, K+1 mediciones)
- NL original como baseline (con bugs de formulacion)
- Gap inexplicado entre NL y PEB

## La solucion que propones ahora

### Nuevo framework de bounds: DEB + PEB

La clave es separar el sistema en dos etapas con sus propios bounds:

```
Etapa 1 (Direction Finding): K mediciones -> n_d
  Bound: DEB (nuevo, derivado del profile MLE con eta nuisance)
  Estimadores: GLS, WLS, NL-MLE

Etapa 2 (Distance Recovery): 1 medicion beam-aligned -> d  
  El PEB (K+1 mediciones) bounds la pipeline completa
```

### Por que esto convence al reviewer

1. **Comment #11 resuelto**: NL-MLE ES el MLE de direccion (profile MLE, demostrado).
   No es una afirmacion vaga — la formulacion eta*Q^m con concentracion analitica
   de eta es el MLE formal bajo el modelo Gaussiano.

2. **Comment #13 resuelto**: El gap entre estimadores y PEB se explica:
   - PEB usa K+1 mediciones conjuntas (genie-aided, beam-aligned)
   - Los estimadores usan two-stage (K para dir + 1 para dist)
   - El gap es ARQUITECTONICO, no un defecto de los estimadores
   - Para direction finding SOLO, NL-MLE se acerca al DEB (gap 11%)

3. **El DEB valida los estimadores**: 
   - DEB: 0.558 deg
   - NL-MLE: 0.620 deg (11% del DEB)
   - GLS: 0.709 deg (27% del DEB)
   Esto muestra que GLS es sub-optimo PERO cercano, y NL-MLE es casi optimo.

## Estructura narrativa propuesta

### Sec III: Theoretical Bounds

> "To benchmark direction estimation independently of the distance-recovery
> stage, we derive the Direction Error Bound (DEB). The DEB is the CRLB
> for estimating n_d from the K direction-finding measurements, treating
> the channel amplitude eta = C*cos(psi)/d^2 as a nuisance parameter
> that is profiled out via the Schur complement of the FIM."

Punto clave: el DEB NO depende de n_r. Esto refuerza Proposition 1.

> "Complementing the DEB, the PEB (Sec. III-B) bounds the full 3D position
> estimation from all K+1 measurements. Because the PEB assumes genie-aided
> beam alignment for the (K+1)-th measurement, it serves as an optimistic
> lower bound for any two-stage estimator."

### Sec V: NL-MLE Baseline

> "We formulate the exact profile MLE for direction finding by jointly
> optimizing over n_d in S^2 and concentrating out the nuisance amplitude
> eta. This establishes the performance ceiling for the direction-finding
> stage and serves as a benchmark for the closed-form GLS/WLS."

### Sec VII: Results

Dos subsecciones con narrativa clara:

**VII-A: Direction Finding** (nueva, responde Comment #11)
> "Table V and Fig. X compare the angular RMSE of GLS, WLS, and NL-MLE
> against the DEB for K=5. The NL-MLE achieves 0.62 deg RMSE, within 11%
> of the theoretical DEB (0.56 deg), confirming its MLE interpretation.
> GLS achieves 0.71 deg, a 27% gap to the DEB but obtained in closed form
> at 75x lower latency (0.04 ms vs 3.1 ms). WLS provides a lightweight
> alternative at 0.98 deg."

**VII-B: 3D Positioning** (existente, mejorada)
> "The direction-finding advantage of NL-MLE propagates to 3D positioning
> (Table IV): NL-MLE achieves 2.3 cm RMSE versus 2.7 cm for GLS.
> The remaining gap to the PEB (1.5 cm) is attributable to the two-stage
> architecture: the K direction-finding measurements contain distance
> information (through absolute power levels) that is discarded by
> all two-stage estimators."

## Sobre las orientaciones (PEB-opt vs DEB-opt)

### La narrativa limpia: un solo set

En el paper usar solo PEB-opt. La razon:

> "The orientation set is designed offline by minimizing the RMS-PEB
> over the testbed via a genetic algorithm (Sec. IV). This configuration
> is used for all estimators to ensure a fair comparison."

### Si el reviewer pregunta "why not optimize for DEB?"

Respuesta en Discussion:

> "The PEB-optimized orientation set minimizes the joint 3D bound and
> yields balanced ratios that favor the GLS estimator. A separate
> DEB-optimized set (tilted 66 deg vs 50 deg) further reduces NL-MLE
> angular error by 10% but degrades GLS by 7%, because the more extreme
> power ratios increase the variance of beta_i. This estimator-dependent
> sensitivity to orientation design motivates co-optimization of
> orientation sets and estimation algorithms as future work."

Este parrafo es muy poderoso porque:
1. Muestra que pensaste en la optimizacion DEB
2. Explica POR QUE no la usas (fairness)
3. Abre una linea de future work
4. Demuestra comprension profunda del sistema

## Resumen: que decirle al reviewer

| Pregunta del reviewer | Respuesta |
|---|---|
| "Where is the MLE?" | NL-MLE (Sec V) es el profile MLE formal |
| "Why gap NL-CRLB?" | Gap es two-stage vs joint. DEB valida que NL-MLE es near-optimal para DF |
| "Is PEB valid?" | Si, PEB es genie-aided bound. DEB complementa para DF stage |
| "Why GLS > NL?" | Ahora NL-MLE > GLS en DF Y en 3D. GLS sigue siendo valioso por latencia |
| "Orientations?" | PEB-opt para todos (fair). DEB-opt mejora NL-MLE pero degrada GLS (Discussion) |
