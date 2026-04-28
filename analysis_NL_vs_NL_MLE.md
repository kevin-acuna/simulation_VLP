# Por que NL-MLE funciona bien sin orientaciones especiales (y NL_test_K5 no)

## 1. Los dos algoritmos lado a lado

### NL original (NL_test_K5.m)

```
Modelo:     P_r = -C * Q^m * L        (on S^2, sin nuisance)
Datos:      P_r_noisy = (P_r + noise) / (-C)    <- normalizacion por (-C)
Variables:  (x, y, z) en R^3 libre     <- SIN sphere constraint
Solver:     optimproblem/solve -> fmincon (interior-point)
Cost:       sum_i sum_k (C*L*Q_i^m - P_noisy_ik)^2
Init:       x0 = (0, 0, -1) fijo
Post:       v_hat / ||v_hat||           <- normalizacion post-hoc
Depende de n_r: SI (a traves de L = alpha*x + beta*y + gamma*z)
```

### NL-MLE (run_DF_comparison.m)

```
Modelo:     mu_i = eta * (n_{t,i} . n_d)^m    (profile MLE)
Datos:      p_target = mean(P_r_noisy) / max(mean(P_r_noisy))
Variables:  (x, y, z, eta) con ||[x,y,z]|| = 1   <- sphere constraint ACTIVA
Solver:     fmincon directo (SQP)
Cost:       sum_i (eta * Q_i^m - p_target_i)^2
Init:       x0 = orientacion LED con max potencia + eta=1
Post:       v / ||v|| (seguridad, ya deberia ser ~1 por constraint)
Depende de n_r: NO (eta absorbe cos(psi))
```

## 2. Las 5 diferencias que explican todo

### Diferencia 1: Nuisance parameter eta (LA MAS IMPORTANTE)

**NL original**: El modelo C*L*Q^m tiene TRES incognitas enredadas:
- La direccion n_d (a traves de Q_i)
- La distancia d (escondida en ||n|| porque no hay sphere constraint)
- El receptor n_r (a traves de L = n_r . n_d)

El optimizador debe encontrar la direccion, la distancia, Y tolerar
el efecto de n_r simultaneamente. Si la orientacion no "ilumina bien"
al receptor (cos^m(phi_i) pequeno), el residuo se domina por el
desbalance de escalas -> el solver se pierde.

**NL-MLE**: El modelo eta * Q^m tiene SOLO DOS incognitas:
- La direccion n_d (a traves de Q_i)  
- eta (nuisance escalar que absorbe d Y n_r)

eta se adapta automaticamente a cualquier distancia y orientacion del PD.
Para cada candidato n_d, el eta optimo es analitico (Eq. eta_hat).
El solver solo necesita buscar en S^2 (2 DoF), no en R^3.

CONSECUENCIA: NL-MLE funciona con CUALQUIER set de orientaciones porque
eta absorbe la escala. NL original necesitaba orientaciones especiales
porque sin eta, el balance de escalas dependia de la geometria.

### Diferencia 2: Sphere constraint

**NL original**: Comentada. El solver opera en R^3 libre.
||n|| absorbe la distancia d (hack). Pero esto crea un paisaje de
optimizacion no-convexo con multiples minimos: diferentes combinaciones
de (direccion, escala) pueden dar costos similares.

**NL-MLE**: Activa (ceq = x^2+y^2+z^2 - 1). El solver busca SOLO
en S^2. Con eta como variable separada, la distancia se desacopla
de la direccion. El paisaje es mucho mas suave.

### Diferencia 3: Inicializacion

**NL original**: x0 = (0, 0, -1) siempre. Para posiciones lejos
del nadir, esta inicializacion puede estar a 60+ grados del optimo.

**NL-MLE**: x0 = orientacion LED con maxima potencia. Esto es una
heuristica informada que pone la inicializacion cerca del optimo
(tipicamente a <30 grados). Reduce dramaticamente los minimos locales.

### Diferencia 4: Datos de entrada

**NL original**: Usa N=1000 muestras individuales en el sum.
Esto crea un problema de optimizacion con 5000 terminos (5 orient x 1000).
El overhead simbolico de optimproblem recrea el problema en cada posicion.

**NL-MLE**: Usa la MEDIA de N muestras -> 5 terminos.
Con fmincon directo (no optimproblem), el overhead se elimina.
Resultado: busqueda mas rapida en un paisaje mas simple.

### Diferencia 5: Solver

**NL original**: optimproblem/solve -> fmincon interior-point.
El framework simbolico agrega overhead significativo.

**NL-MLE**: fmincon SQP directo. SQP es particularmente bueno
para constraints de igualdad (como la esfera).

## 3. Por que NL original necesitaba orientaciones especiales

Con el NL original (sin eta, sin sphere constraint, init fijo), el solver
podia converger a un minimo local incorrecto cuando:
- Las potencias eran muy desbalanceadas (orientaciones a 50+ grados)
- La escala ||n|| compensaba mal la distancia
- La inicializacion estaba lejos

Las "orientaciones NL-optimizadas" (21,42,21,341,...) tenian elevaciones
bajas (~21-25 grados) que producian potencias mas UNIFORMES. Esto ayudaba
al solver del NL original a converger porque los residuos eran mas
homogeneos en escala.

Con NL-MLE, eta normaliza las escalas automaticamente -> las orientaciones
a 50 grados (PEB-opt) funcionan perfectamente.

## 4. Verificacion con datos

PEB-opt orientations (50 deg):
- NL_test_K5 (original): Necesitaba orientaciones especiales NL-opt
- NL-MLE (nuevo):        RMSE 0.620 deg (funciona bien sin set especial)
- GLS:                    RMSE 0.709 deg

DEB-opt orientations (66 deg):
- NL-MLE:                RMSE 0.560 deg (mejora 10%)
- GLS:                    RMSE 0.760 deg (empeora 7%)

Conclusion: NL-MLE es robusto al set de orientaciones gracias a eta.

## 5. Justificacion para usar NL-MLE en el paper (en vez de NL original)

1. **Es el profile MLE**: Formulacion teorica correcta. El NL original
   era un NLS heuristico sin tratamiento formal del nuisance parameter.

2. **Es n_r-agnostic**: Igual que GLS/WLS. El NL original dependia de n_r.
   Esto hace que NL-MLE sea una comparacion JUSTA con GLS/WLS.

3. **No necesita orientaciones especiales**: Usa las mismas PEB-opt que
   GLS/WLS. Comparacion justa con un solo set de orientaciones.

4. **Sphere constraint explicita**: Matematicamente correcto, no un hack.

5. **Formulacion publicable**: Las ecuaciones mu_i = eta * Q^m,
   la profile likelihood, y el eta analitico son presentables en IEEE TCOM.
   El NL original con su normalizacion por (-C) y sphere constraint OFF
   seria dificil de explicar rigurosamente.

## 6. Respuesta para el reviewer

Si el reviewer pregunta "why use NL-MLE instead of a standard NLS?":

> "The NL-MLE formulates direction finding as a profile maximum-likelihood
> problem with the channel amplitude eta as a nuisance parameter. By
> concentrating out eta analytically (Eq. X), the optimization reduces
> to searching over S^2 with a single sphere-constrained fmincon call.
> This provides three advantages over a generic NLS: (i) it is provably
> the MLE for the direction subproblem, (ii) it does not require knowledge
> of the receiver orientation n_r (since eta absorbs cos(psi)), and
> (iii) it converges reliably with the same orientation set used by
> GLS/WLS, enabling a fair comparison."
