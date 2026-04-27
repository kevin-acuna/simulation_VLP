# Análisis profundo: NL, MLE, CRLB y coherencia arquitectónica

## 1. El problema central

Hay tres preguntas entrelazadas:
1. ¿El NL es el MLE? ¿En qué sentido?
2. ¿Por qué ningún estimador alcanza el PEB?
3. ¿Cómo hacer todo coherente en la arquitectura C2?

---

## 2. Qué estima cada estimador vs. qué mide el PEB

### Lo que el PEB mide

El PEB usa **K+1 mediciones** (K de direction finding + 1 de distance recovery) y estima **r = (x,y,z) ∈ R³ conjuntamente**:

```
PEB(r) = sqrt(tr(I⁻¹(r)))

donde I(r) = (N/σ²) Σ_{i=1}^{K+1} [∇_r μ_i(r)] [∇_r μ_i(r)]ᵀ
```

Es el bound para un estimador que usa TODAS las mediciones simultáneamente para estimar posición 3D. No distingue entre "etapa de dirección" y "etapa de distancia" — es un bound conjunto.

### Lo que hacen los estimadores (NL, GLS, WLS)

**TODOS** usan una arquitectura de **dos etapas**:

```
Etapa 1: K mediciones → n̂_d (dirección, 2 DoF en S²)
Etapa 2: 1 medición  → d̂   (distancia, 1 DoF en R⁺)
Posición: r̂ = t + d̂ · n̂_d
```

Ninguno estima r = (x,y,z) directamente de las K+1 mediciones. La descomposición en dos etapas introduce **propagación de error** que un estimador conjunto evitaría.

### Consecuencia fundamental

> **Ningún estimador de dos etapas puede alcanzar el PEB conjunto.**

El gap entre los estimadores y el PEB NO es un defecto de GLS, WLS, o NL — es una propiedad inherente de la arquitectura de dos etapas.

Para alcanzar el PEB, se necesitaría un **estimador conjunto (Joint MLE)**:
```
r̂_MLE = argmin_{r∈R³} Σ_{i=1}^{K+1} (z_i - μ_i(r))²
```
que estima (x,y,z) directamente de las K+1 mediciones sin descomponer en dirección + distancia.

---

## 3. ¿El NL es el MLE? — Análisis riguroso

### Qué hace el NL en el paper (Eq. 31-32)

```
n̂_{d,NL} = argmin_{n∈S²} Σ_{i=1}^K Σ_{k=1}^N (P_{r,i,k} + C·Q_i^m·L)²
```

sujeto a Q_i ≥ 0, L ≤ 0, ||n||=1.

Observaciones:
- Opera sobre **S²** (esfera unitaria), no sobre R³
- Usa solo las **K mediciones de DF**, no la medición K+1
- El modelo sobre S² es: `P_{r,i} = -C·Q_i^m·L + n_i` (con d=1)

### El problema de la unidad esfera

El modelo en S² asume d=1: `P_{r,i}(n_d) = -C·Q_i(n_d)^m·L(n_d)`

Pero los datos reales fueron generados con d ≠ 1:
```
P_{r,i,actual} = -C · Q_i^m · L / d^{m+3} + noise
```

El factor `1/d^{m+3}` es una constante multiplicativa común a todas las orientaciones. La buena noticia es que este factor **no cambia qué dirección minimiza la suma de cuadrados** (solo escala los residuos uniformemente). Por tanto, el minimizador en S² encuentra la dirección correcta **a pesar del scaling**.

Sin embargo, los residuos en el mínimo NO son cero — tienen un bias de `C·Q^m·L·(1-1/d^{m+3})`. Esto no afecta la dirección estimada pero sí la interpretación estadística (la varianza de los residuos no corresponde a σ² pura).

### ¿Es el MLE para la dirección?

**Estrictamente, NO.** El MLE para la dirección sería el estimador que maximiza la likelihood marginalizada sobre d (nuisance parameter). La forma correcta de eliminar d como nuisance es tomar **ratios de potencias**, que es exactamente lo que hacen GLS/WLS:

```
β_i = (μ_i/μ_1)^{1/m} → cancela d y n_r
```

El GLS/WLS, al usar ratios, **SÍ es el MLE para la dirección** (bajo la linealización de primer orden de los ratios). Es decir:
- **GLS**: MLE para el modelo linealizado de ratios → **estadísticamente eficiente** para el subproblema de dirección
- **NL**: Heurística iterativa que ajusta potencias absolutas en S² → no es el MLE para dirección

### ¿Cuándo sería el NL = MLE?

El NL sería el MLE para la posición 3D SI:
1. Operara sobre R³ (no S²)
2. Usara las K+1 mediciones (incluyendo distance recovery)
3. No tuviera constraints de Q≥0, L≤0 (estos limitan la región de búsqueda pero no son parte del modelo estadístico)

Es decir, el **true MLE** para posición 3D sería:
```
r̂_MLE = argmin_{r∈R³} Σ_{i=1}^{K+1} (z_i - μ_i(r))²
```

Esto es computacionalmente factible (3 variables, K+1 residuos, sin constraints complicados) y **debería acercarse al PEB** asintóticamente.

---

## 4. Implicaciones para el paper

### ¿Está bien estructurado el paper con el NL?

**El NL tiene sentido como comparativa**, pero su rol debe clarificarse:

| Aspecto | Actual en el paper | Cómo debería ser |
|---|---|---|
| ¿Qué es? | "Constrained NL estimator" | "Direction-finding baseline via NL least squares on S²" |
| ¿Es el MLE? | Implícitamente sí (Sec. VII) | **No**. Es una heurística. GLS es más cercano al MLE de dirección |
| ¿Contra qué se compara? | PEB conjunto (K+1 mediciones, 3D) | PEB conjunto — pero aclarar que TODOS tienen gap por two-stage |
| ¿Requiere n_r? | Sí (a través de L) | Sí — contrastar con GLS/WLS que no lo necesitan |
| ¿Cuál es su valor? | Comparación de precisión | Mostrar que NL iterativo NO supera GLS cerrado → fortalece el caso de GLS |

### Orden en el paper: ¿NL antes o después de GLS/WLS?

**Recomendación: mantener NL antes de GLS/WLS** por estas razones:
1. Pedagogía: NL es el enfoque "natural" (ajustar modelo al dato). GLS/WLS son el aporte elegante.
2. Contraste: el lector ve primero el método "obvio" (NL, iterativo, requiere n_r, lento) y luego la solución cerrada (GLS/WLS, no requiere n_r, rápida, más precisa).
3. El reviewer no pidió mover el NL — solo pidió explicar el gap.

Pero: **renombrar la sección**. De "Nonlinear Estimator" a algo como:
> "Constrained Nonlinear Direction Estimator" o "Iterative Direction Estimator"

Y añadir un párrafo introductorio que diga:
> "Before developing closed-form estimators, we present an iterative nonlinear least-squares approach that directly fits the Lambertian power model on the unit sphere S². Although computationally more expensive and requiring knowledge of n_r, this method serves as a baseline for comparison with the proposed closed-form GLS/WLS estimators developed in Section VI."

---

## 5. Coherencia con el PEB — La solución

### El problema de coherencia

```
PEB = bound para estimador conjunto (K+1 mediciones → r)
Estimadores = dos etapas (K mediciones → n̂_d, 1 medición → d̂)
```

### La solución: ser explícito

Añadir un párrafo al inicio de Sec. VII (Results) o al final de Sec. III (PEB):

> "The PEB in (XX) represents the minimum achievable RMSE for any unbiased estimator that jointly processes all K+1 measurements to estimate r. The estimators developed in Sections V–VI employ a two-stage architecture: direction finding from K measurements followed by distance recovery from one additional measurement. This decomposition incurs an inherent efficiency loss relative to joint estimation, because the FIM for the complete K+1-measurement model is not block-diagonal in the direction and distance parameters. Consequently, the PEB serves as a lower bound that no two-stage estimator can generally attain, while still providing a meaningful benchmark for system design (orientation optimization, K selection, SNR requirements)."

### ¿Se invalida el PEB?

**NO.** El PEB sigue siendo completamente válido:
- Como **benchmark del sistema**: indica el potencial teórico de la configuración (K, orientaciones, SNR)
- Como **objetivo del GA**: la optimización de orientaciones maximiza el potencial del sistema
- Como **bound informativo**: muestra cuánto margen queda entre la arquitectura actual y el límite teórico
- Todos los estimadores se comparan contra el MISMO benchmark → comparación fair

Lo que NO debemos decir es "GLS alcanza el CRLB" o "NL debería alcanzar el CRLB". Lo correcto es:
> "GLS is the closest to the PEB among the proposed two-stage estimators."

---

## 6. ¿Se puede implementar un Joint MLE? — NO directamente

### El problema de la medición adaptiva

La propuesta anterior de un Joint MLE:
```
r̂ = argmin_{r∈R³} Σ_{i=1}^{K+1} (z_i − μ_i(r))²
```
**no es implementable** directamente porque:

- Las K primeras mediciones usan orientaciones **pre-fijas** {n_{t,1},...,n_{t,K}} → independientes de r ✓
- La medición K+1 usa n_{t,K+1} = **n̂_d** (dirección estimada desde los K datos) → depende de los datos ✗

Es decir: no puedes tener las K+1 mediciones "de una vez" porque la K+1-ésima requiere haber procesado las K primeras. El proceso es **inherentemente secuencial/adaptivo**.

### ¿Entonces el PEB es inválido?

**NO.** El PEB sigue siendo válido pero con una interpretación precisa:

El PEB se calcula en el **punto verdadero r**, donde n_{t,K+1} = n_d (la dirección real, no la estimada). Esto es estándar en análisis CRLB de sistemas adaptativos: el bound se evalúa asumiendo que la adaptación es perfecta ("genie-aided"). Es un **lower bound optimista** que asume alineamiento perfecto.

En la práctica, hay un error de steering (n̂_d ≠ n_d) que degrada la medición K+1. Por tanto, el rendimiento real es **doblemente penalizado**:

```
PEB (genie-aided K+1)      ← bound teórico (optimista)
   ↓ gap 1: steering error en K+1
PEB realista                ← lo que realmente se puede lograr
   ↓ gap 2: two-stage decomposition
Estimadores (GLS/WLS/NL)   ← rendimiento práctico
```

### ¿Qué se puede hacer en su lugar?

**Opción viable: K-only Joint MLE** (sin medición K+1)

Un estimador que use **solo las K mediciones pre-fijas** para estimar r directamente:
```
r̂_K = argmin_{r∈R³} Σ_{i=1}^K (z_i − μ_i(r))²
```

Esto SÍ es implementable porque las K orientaciones son fijas. Estima posición directamente de las K potencias, extrayendo TODA la información (dirección Y distancia) simultáneamente.

**Pero**: sería peor que los métodos two-stage con K+1 medición, porque pierde la medición de ranging (que aporta mucha información de distancia con alto SNR). Sería útil solo como curiosidad teórica, no como mejora.

**Conclusión: NO añadir Joint MLE al paper.** La complejidad no aporta al mensaje. En su lugar:

---

## 6b. Argumento para mantener el PEB sin Joint MLE

El PEB se mantiene como benchmark del sistema sin necesidad de validación por Joint MLE. La justificación:

> "The PEB is evaluated at the true receiver position r, with the distance-recovery measurement computed assuming perfect beam alignment (n_{t,K+1} = n_d). This genie-aided formulation follows standard CRLB practice for adaptive sensing systems [Kay, 1993] and provides a meaningful lower bound on the achievable RMSE. All proposed estimators share the same two-stage architecture (direction finding followed by distance recovery) and are compared against this common benchmark."

Esto es honesto, estándar, y no requiere implementar nada nuevo.

---

## 7. ¿Por qué mantener el NL en el paper? — Argumento sólido

### La pregunta: si el NL no es MLE de dirección, ¿por qué incluirlo?

**El NL tiene valor como baseline natural, no como MLE.** Su rol es:

> "Dado el modelo Lambertiano y K mediciones ruidosas, ¿qué pasa si un ingeniero simplemente ajusta el modelo a los datos minimizando los residuos? Esa es la solución NL. Mostramos que esta solución 'obvia' es más lenta, requiere conocer n_r, y aún así no supera a GLS. Esto valida la contribución de GLS."

### Argumentos concretos:

**1. Es el enfoque directo que cualquier lector intentaría:**
El modelo es P_r = f(n_d, d, n_r, n_{t,i}). El enfoque "natural" es minimizar Σ(P_r,obs - f)². No necesita derivaciones especiales. Es lo primero que un practicante probaría.

**2. Representa la clase de métodos iterativos:**
En posicionamiento óptico, muchos trabajos usan Levenberg-Marquardt, Newton, o fmincon. El NL representa esta familia. Compararlo con GLS closed-form es relevante para la comunidad.

**3. Viene del trabajo previo [Chassagne2025]:**
El NL extiende el método del co-autor a 3D. Mantenerlo da continuidad con la literatura previa.

**4. El contraste fortalece GLS:**
"Un método iterativo con N·K evaluaciones de función NO supera a un eigenproblem 3×3. Esto demuestra la potencia de la linealización por ratios."

**5. El reviewer NO pidió eliminarlo:**
El reviewer pidió explicar el gap (Comment #13) y añadir MLE (Comment #11). No pidió quitar el NL.

### Sobre añadir un WNL (weighted NL):

**NO conviene.** Razones:
- Añade complejidad sin insight nuevo
- Un WNL con ponderación óptima convergería esencialmente al GLS (ambos terminan ponderando por SNR)
- La contribución del paper es GLS/WLS, no variantes del NL
- El reviewer no lo pidió

### Cómo renombrar/reposicionar el NL en el paper:

**Título de sección**: "Nonlinear Direction-Finding Baseline" (en vez de "Nonlinear Estimator")

**Párrafo introductorio**:
> "As a baseline for comparison, we first develop an iterative nonlinear least-squares (NLS) approach that directly fits the Lambertian power model on S². This method represents the class of numerical estimators commonly employed in optical positioning [refs] and serves to benchmark the closed-form GLS/WLS estimators proposed in Section VI."

**Párrafo al final de Sec. V**:
> "We note that the NLS formulation requires knowledge of the receiver orientation n_r (through the term L in (XX)), in contrast to the ratio-based estimators developed next. Moreover, as shown in Section VII, the NLS baseline does not outperform the proposed GLS despite its higher computational cost, because it does not exploit the optimal statistical weighting inherent in the GLS formulation."

---

## 7b. ¿Por qué GLS es mejor que NL en direction finding? — Explicación sólida

### El reviewer pensará: "NL ajusta el modelo completo, GLS usa una aproximación linealizada. ¿Cómo puede la aproximación ser mejor?"

La respuesta tiene 3 partes:

### Parte 1: GLS opera sobre una señal más limpia

El NL trabaja con **potencias absolutas**: P_{r,i} = C·cos^m(ϕ_i)·cos(ψ)/d²

Estas potencias dependen de:
- n_d (lo que queremos estimar) ← señal útil
- d (distancia, desconocida) ← nuisance que contamina
- n_r (orientación Rx) ← nuisance que contamina

El NL intenta estimar n_d directamente de esta señal contaminada.

El GLS trabaja con **ratios**: β_i = cos(ϕ_i)/cos(ϕ_1)

Las ratios dependen de:
- n_d (lo que queremos estimar) ← señal útil
- ~~d~~ (cancelado) ← eliminado
- ~~n_r~~ (cancelado) ← eliminado

**GLS opera sobre una señal donde solo queda la información de dirección.** Toda la contaminación ha sido eliminada algebraicamente antes de la estimación. Esto es como filtrar antes de estimar — siempre gana.

### Parte 2: GLS tiene ponderación estadísticamente óptima

GLS construye Σ_β (covarianza de los ratios) y minimiza la distancia de Mahalanobis:

```
||Â^T d||²_{Σ_β^{-1}}
```

Esto da peso inversamente proporcional a la varianza de cada constraint. Las orientaciones con alto SNR (μ_i grande) producen ratios precisas → más peso. Las orientaciones con bajo SNR → menos peso.

El NL trata todas las orientaciones por igual en la suma de cuadrados:
```
Σ_i Σ_k (P_{r,i,k} - model_i)²
```

Las orientaciones donde P_r ≈ 0 (el LED apunta lejos del Rx) contribuyen residuos dominados por ruido que degradan la estimación. El paper ya lo identifica (línea 895): *"giving comparable influence to orientations with negligible received power...which impairs convergence."*

### Parte 3: No es "aproximación vs exacto" — es "suficiente vs contaminado"

La intuición errónea es: "GLS = linealizado = aproximado → debería ser peor que NL = exacto."

La intuición correcta es:
- **GLS usa una estadística suficiente** (los ratios β_i contienen toda la información de dirección disponible en las potencias)
- **GLS pondera óptimamente** esta estadística
- **NL usa las potencias brutas** que están contaminadas por nuisance parameters (d, n_r) y no pondera

Es como en regresión: un WLS con el modelo correcto y pesos óptimos SIEMPRE supera a un OLS sin pesos, incluso si OLS usa el modelo "exacto".

### Texto sugerido para el paper (Sec. VII):

> "The GLS estimator outperforms the NLS baseline for two reasons. First, the power ratios β_i eliminate the nuisance parameters d and n_r from the direction estimation, whereas the NLS cost function retains these unknown quantities. Second, GLS applies statistically optimal weighting through the inverse covariance Σ_β^{−1}, assigning higher weight to orientations with higher SNR. By contrast, the NLS treats all orientations equally, allowing noise-dominated measurements to degrade the solution."

---

## 7c. Respuesta revisada al Reviewer (Comments #11 + #13)

### Comment #11: "include MLE"

> "We have clarified the relationship between the proposed estimators and the maximum-likelihood framework. Under Gaussian noise, the GLS direction estimator is the MLE for the ratio-based linearized model (Appendix A) and is therefore statistically efficient for direction finding: it achieves the Cramér–Rao bound for the direction subproblem when the first-order approximation in (XX) holds, which is accurate for the operating SNR of this system. The NLS baseline (Section V) solves a constrained least-squares problem on S² and serves as a representative of the class of iterative numerical estimators. We have added a remark in Section V clarifying that NLS is not equivalent to the MLE and requires knowledge of n_r, in contrast to GLS/WLS."

### Comment #13: "NL should reach CRLB"

> "We thank the reviewer for this important observation. The apparent expectation that the NLS should approach the CRLB rests on two implicit assumptions that do not hold in our setting:
>
> (i) **Two-stage vs. joint estimation.** The PEB in (XX) represents the bound for joint estimation of r from all K+1 measurements. All estimators in this paper (NLS, GLS, WLS) employ a two-stage architecture—direction finding from K measurements followed by distance recovery from one additional adaptive measurement. Because the K direction-finding measurements also contain distance information (through the absolute power levels) that is discarded in the two-stage decomposition, a gap between the PEB and any two-stage estimator is expected.
>
> (ii) **NLS is not the MLE.** The NLS formulation projects the problem onto S² (fixing d = 1) and does not apply statistical weighting. By contrast, the ratio-based GLS is the MLE for the linearized direction model and applies the inverse-covariance weighting Σ_β^{−1}. This explains why GLS outperforms NLS in both direction and position accuracy despite being a closed-form solution.
>
> In the revised manuscript, we have clarified these distinctions and added direction-finding-specific performance metrics (angular error CDF) to complement the 3D position metrics."

---

---

## 8. Respuestas detalladas a tus preguntas

### P1: "¿El PEB no es de dos etapas? ¿Cómo sería si fuera 2 etapas?"

**El PEB NO es de dos etapas.** El FIM suma las contribuciones de las K+1 mediciones como funciones de r = (x,y,z):

```
I(r) = Σ_{i=1}^{K}   [∇_r μ_i(r)][∇_r μ_i(r)]ᵀ   ← K mediciones DF
      + [∇_r μ_{K+1}(r)][∇_r μ_{K+1}(r)]ᵀ           ← 1 medición DR
```

Cada medición (incluyendo la K+1 beamformed) es una función de la posición r. La FIM las combina **como si un estimador omnisciente procesara TODAS simultáneamente**. No importa que la medición K+1 sea "diferente" (cos ϕ = cos ψ = 1) — simplemente aporta información adicional sobre r a través de un gradiente diferente (`−2C/d³ · n_d`).

**¿Qué sería un estimador "de una etapa" que alcance este PEB?** Un Joint MLE:

```
r̂ = argmin_{(x,y,z)} Σ_{i=1}^{K+1} (z_i − μ_i(x,y,z))²
```

donde:
- `z_i = P̄_{r,i}` = potencia media medida en orientación i
- `μ_i(r) = P_t · h_{LOS,i}(r)` para i = 1,...,K
- `μ_{K+1}(r) = C/d²(r)` para la medición beamformed

Este estimador busca **directamente** las coordenadas (x,y,z) que mejor explican TODAS las K+1 mediciones simultáneamente. No descompone en "primero dirección, luego distancia."

**¿Por qué los estimadores de dos etapas pierden eficiencia?**

Porque las K mediciones de DF contienen información tanto sobre la **dirección** como sobre la **distancia** (a través de la amplitud absoluta de la potencia). Al usar solo ratios para DF, se extrae solo la información de dirección y se descarta la información de distancia contenida en las magnitudes absolutas. Luego, la medición K+1 de DR solo puede recuperar la información de distancia que ella misma proporciona, sin "reciclar" la información de distancia que había en las K mediciones de DF.

**¿Es normal que no se supere el PEB?** Sí, totalmente normal. El PEB es un lower bound teórico para CUALQUIER estimador insesgado. Ningún estimador puede superarlo. Los de dos etapas típicamente no lo alcanzan. Solo el joint MLE lo alcanza asintóticamente (con N→∞).

---

### P2: "¿Por qué dirección es 2 DoF en S²?"

Un vector de dirección en R³ tiene la forma n_d = [n_x, n_y, n_z]ᵀ con la restricción ||n_d|| = 1 (norma unitaria). Eso significa:

```
n_x² + n_y² + n_z² = 1
```

Tres componentes menos una restricción = **2 grados de libertad**.

Estos 2 DoF se pueden parametrizar con ángulos esféricos:
```
n_d = [sin θ cos φ,  sin θ sin φ,  −cos θ]ᵀ
```
donde θ ∈ [0°, 90°] es la elevación y φ ∈ [0°, 360°] el azimuth. Dos números definen completamente la dirección.

**¿Necesito solo 2 mediciones entonces?**

Necesitas **al menos K ≥ 3 orientaciones** (no 2). Esto es porque:

1. Con K orientaciones se forman **K−1 ratios** β_i = (μ_i/μ_1)^{1/m}
2. Cada ratio da **1 constraint lineal**: a_i · d = 0 (un hiperplano en R³)
3. Para determinar una dirección en 2D (S²), necesitas **2 hiperplanos independientes**
4. K−1 ≥ 2 → **K ≥ 3**

Con K = 3: 2 constraints → just-determined (la intersección de 2 planos en R³ da una línea → normalizar da 2 puntos en S², se elige por signo).

Con K ≥ 4: overdetermined → se puede usar least-squares ponderado (GLS/WLS) para mayor robustez al ruido.

Con K = 2: solo 1 constraint → underdetermined → infinitas direcciones posibles → no se puede estimar.

---

### P3: "¿Por qué el NL no es el MLE de dirección? ¿Podría llegar a serlo después de debug?"

**Incluso con el código perfectamente correcto, el NL de la Sec. V NO es el MLE de dirección.** Razones:

**a) No perfila correctamente la distancia (nuisance parameter)**

El MLE de dirección debería maximizar la likelihood **marginalizada** (o profile) sobre d:

```
n̂_d = argmax_{n ∈ S²} max_d L(n, d | data)
```

La forma correcta de eliminar d es observar que las **ratios** μ_i/μ_1 no dependen de d ni de n_r. Esto es exactamente lo que GLS/WLS hacen:

```
β_i = (μ_i/μ_1)^{1/m} = cos(ϕ_i)/cos(ϕ_1) ← solo depende de n_d
```

El GLS minimiza la distancia de Mahalanobis de los residuos de los ratios, que es el criterio ML para el modelo linealizado. **GLS = direction MLE (linealizado).**

El NL, en cambio, ajusta potencias absolutas sobre S² sin perfilar d. Fija d=1 implícitamente al proyectar sobre S². Esto crea un mismatch de amplitud (el dato tiene escala 1/d^{m+3} pero el modelo asume escala 1). Aunque este mismatch NO cambia la dirección óptima (la forma del patrón de potencia es correcta), SÍ cambia la estadística de los residuos → la ponderación implícita del NL no es óptima.

**b) El NL no usa la ponderación estadística correcta**

En el NL: todas las orientaciones i contribuyen por igual a la suma de cuadrados. Pero las orientaciones con mayor potencia recibida (mayor SNR) deberían pesar más. GLS hace esto automáticamente a través de Σ_β^{-1}.

**c) Después del debug, ¿el NL mejoraría?**

Sí, el NL debugeado será mucho mejor que el actual (corrigiendo unidades de ruido, normalización, sphere constraint). Pero seguirá siendo **subóptimo respecto a GLS para dirección**, porque:
- No perfila d correctamente
- No pondera las orientaciones óptimamente
- GLS es el estimador eficiente para el modelo de ratios

**d) ¿Podría reformularse el NL para ser el MLE de dirección?**

Sí, pero eso lo convertiría esencialmente en GLS:
- Si usas ratios para eliminar d → llegas a β_i → llegas a GLS
- Si añades d como variable y resuelves (n_d, d) conjuntamente → llegas al Joint MLE (no solo dirección)

No hay un "NL de dirección" intermedio que sea significativamente mejor que GLS sin ser el Joint MLE completo.

---

### P4: "¿Convendría cambiar el NL al Joint MLE?"

**Esta es la pregunta clave. Analicemos las opciones:**

**Opción 1: Mantener NL actual (debugeado) como baseline iterativo + añadir Joint MLE como validación**

```
Sec V:   NL (direction on S², baseline iterativo)         ← ya existe, debugear
Sec VI:  GLS/WLS (direction, closed-form, contribución)   ← principal
Sec VII: Comparación:
         - NL vs GLS vs WLS vs PEB (two-stage, como ahora)
         - Joint MLE vs PEB (validación, nueva curva)
```

**Pros:**
- Mínima reestructuración del paper
- NL sigue sirviendo como contraste (iterativo vs closed-form)
- Joint MLE valida el PEB y explica el gap

**Contras:**
- 4 estimadores + PEB puede ser mucho contenido

**Opción 2: Reemplazar NL por Joint MLE**

```
Sec V:   Joint MLE (r directamente, iterativo, true MLE)
Sec VI:  GLS/WLS (direction + DR, closed-form)
Sec VII: Joint MLE vs GLS vs WLS vs PEB
```

**Pros:**
- El Joint MLE es el benchmark teórico correcto contra el PEB
- Muestra claramente: Joint MLE ≈ PEB > GLS > WLS → gap = two-stage price

**Contras:**
- Reestructuración de Sec V (nueva formulación)
- Se pierde el contraste NL direction vs GLS direction
- El reviewer podría decir "¿por qué no usan el Joint MLE si es mejor?" → respuesta: latencia (es iterativo)

**Opción 3 (RECOMENDADA): Mantener NL + añadir Joint MLE ligero en resultados**

```
Sec V:   NL (direction, baseline)
Sec VI:  GLS/WLS (direction, contribución)
Sec VII: 
  - Direction-finding: NL vs GLS vs WLS (CDF angular) ← comparación fair
  - 3D positioning: NL vs GLS vs WLS vs Joint MLE vs PEB (CDF 3D) ← full picture
```

El Joint MLE no necesita sección propia — se implementa en ~20 líneas y aparece como UNA curva extra en la CDF de posición 3D.

**¿Se entiende arquitectónicamente?** Sí:
- GLS/WLS = métodos propuestos (rápidos, closed-form, n_r-agnostic)
- NL = baseline iterativo (lento, requiere n_r)
- Joint MLE = "what-if" teórico: muestra el costo de two-stage
- PEB = bound del sistema

Esto es **muy estándar** en papers de posicionamiento. Se compara con un MLE conjunto para validar el bound y luego se muestran métodos prácticos que son subóptimos pero rápidos.

---

### P5: "Define z_i y μ_i(r)"

```
z_i = P̄_{r,i} = (1/N) Σ_{k=1}^N P_{r,i,k}
```
Es la **potencia óptica promedio** medida en la orientación i, promediando N muestras. Es lo que el receptor observa.

```
μ_i(r) = E[P̄_{r,i}] = P_t · h_{LOS,i}(r)
```
Es la **potencia óptica esperada** (sin ruido) en la orientación i, que depende de la posición r del receptor a través del canal h_LOS,i:

```
μ_i(r) = P_t · (m+1)·A_det / (2π·d²) · cos^m(ϕ_i) · cos(ψ)
```

donde d = ||r − t||, cos ϕ_i = n_{t,i}·(r−t)/d, cos ψ = n_r·(t−r)/d.

Para la medición K+1 (beamformed):
```
μ_{K+1}(r) = C / d²(r)    donde C = P_t·(m+1)·A_det/(2π)
```
porque cos ϕ = cos ψ = 1 en la configuración alineada.

---

### P6: "¿El NL no es mejor por bugs o por teoría? ¿Si el NL se hiciera sobre DF podría ser el MLE del modelo no lineal y ser mejor que GLS?"

**Hay tres capas de respuesta:**

**Capa 1 — Bugs (lo que se puede corregir):**
Los bugs (BUG-1,2,3,5 del plan) degradan el NL artificialmente. Después de corregirlos, el NL será mejor que ahora. Pero NO será mejor que GLS para dirección.

**Capa 2 — Arquitectura two-stage (afecta a TODOS):**
Todos los estimadores (NL, GLS, WLS) son two-stage → ninguno alcanza el PEB. Este gap es el mismo para todos. No hace que NL sea peor que GLS.

**Capa 3 — Eficiencia estadística para dirección (por qué GLS > NL):**

El GLS es el MLE para el **modelo linealizado de ratios**. La linealización (delta method) es una excelente aproximación para N grande (N=1000 en nuestro caso). Bajo esta linealización, GLS es **estadísticamente eficiente** = alcanza el CRLB de dirección.

El NL ajusta el **modelo no lineal completo** (potencias absolutas). En teoría, un MLE del modelo completo PODRÍA ser mejor que GLS del modelo linealizado, pero SOLO en regímenes de SNR muy bajo donde la linealización falla. A SNR moderado-alto (el caso del paper), la diferencia es negligible.

**PERO**: el NL actual NO es el MLE del modelo no lineal. Es un least-squares sin ponderación correcta. Incluso si lo reformuláramos como un MLE no lineal correcto:

```
n̂_d = argmax_{n∈S²} max_d  Σ_i log p(z_i | n, d)
```

el beneficio sobre GLS sería marginal en el régimen de operación del paper (N=1000, SNR ~14 dB). Y la complejidad computacional sería mucho mayor (iterativo vs closed-form).

**Resumen visual:**

```
Precisión de dirección (mejor → peor):

MLE no lineal de dirección ≈ GLS >>> NL actual (buggy)
       ↑                       ↑           ↑
  teóricamente óptimo   linealización   no ponderado
  pero iterativo        eficiente       + bugs
                        y cerrado
```

Para posición 3D:
```
Joint MLE ≈ PEB > GLS (two-stage) > NL (two-stage) > WLS (two-stage)
```

**La jerarquía correcta del paper revisado sería:**
- **Joint MLE**: validación teórica del PEB (1 curva en CDF)
- **GLS**: mejor método práctico (cerrado, rápido, n_r-agnostic)
- **WLS**: versión ligera de GLS
- **NL**: baseline iterativo (debugeado, para mostrar que iterativo ≠ mejor)
- **PEB**: benchmark del sistema

---

## 9. Resumen: tabla de verdad

| Afirmación | ¿Es verdad? | Corrección |
|---|---|---|
| "NL es el MLE" | ❌ No | NL es un least-squares en S² para dirección. GLS es el direction MLE (linealizado) |
| "NL debería alcanzar el CRLB" | ❌ No | El CRLB es para estimación conjunta. NL es two-stage |
| "El PEB es inválido" | ❌ No | El PEB es correcto. Es un bound conjunto válido como benchmark |
| "GLS alcanza el PEB" | ❌ No | GLS es el más cercano entre los two-stage, pero no lo alcanza |
| "El gap es por bugs del NL" | ⚠️ Parcial | Hay bugs (BUG-1,2,3,5) pero el gap arquitectónico persistiría con código correcto |
| "GLS es estadísticamente eficiente" | ✅ Sí | Para el subproblema de dirección (modelo linealizado de ratios) |
| "La propiedad n_r-agnostic es fundamental" | ✅ Sí | Es una consecuencia matemática de las ratios Lambertianas |

---

## 9. Cambios al plan C2

### Actualizar Comment #11 (Parte 1):
- De: "NL es el MLE"
- A: "GLS es el MLE para el modelo linealizado de dirección. NL es un baseline iterativo en S². Joint MLE es el verdadero MLE para posición 3D."

### Actualizar Comment #13:
- De: "corregir bugs, luego justificar gap residual"
- A: "corregir bugs Y explicar gap arquitectónico. Opcionalmente, implementar Joint MLE para validar PEB."

### Actualizar Sec. V (NL):
- Renombrar: "Iterative Direction Estimator" o "Constrained NL Direction Estimator"
- Añadir párrafo posicionándolo como baseline comparativo
- Clarificar: requiere n_r, opera en S², no es MLE conjunto

### Añadir párrafo en Sec. III o VII:
- Explicar que PEB es bound conjunto
- Explicar que two-stage tiene gap inherente
- (Opcionalmente) mostrar Joint MLE acercándose al PEB

### Sec VII Results — narrativa:
```
"Among the two-stage estimators, GLS provides the best fidelity to the PEB,
followed by NL and then WLS. The residual gap between GLS and the PEB
is attributable to the two-stage architecture (direction + distance),
not to estimator suboptimality: GLS is provably efficient for the
direction subproblem."
```
