# Análisis Arquitectónico: Limitaciones del Two-Stage Pipeline y Alternativas

## El problema

El pipeline actual del TCOM tiene dos etapas:
1. **Direction finding** (K mediciones): estima n̂_d — es n_r-agnostic ✅
2. **Distance recovery** (1 medición cooperativa K+1): LED apunta a n̂_d, PD se reorienta a -n̂_d → d = sqrt(C/P̄_{r,K+1})

**Limitación arquitectónica**: la etapa 2 requiere que:
- El LED apunte al receptor (OK, ya tiene beam steering)
- El PD se reoriente hacia el LED (requiere beam steering en el receptor)
- Para N receptores, se necesitan N mediciones dedicadas (no escala)

## Pregunta clave: ¿Se puede estimar d solo con las K mediciones?

### Desarrollo matemático

Del modelo factorizado (eq. 9 del paper):

```
μ_i = η · Q_i^m
```

donde `Q_i = n_{t,i} · n_d` y `η = C·cos(ψ)/d²`.

Después del direction finding, conocemos n̂_d, por tanto podemos calcular:

```
Q̂_i = n_{t,i} · n̂_d   (conocido para todo i)
```

De cualquier medición i:

```
η = μ_i / Q_i^m
```

Con K mediciones, el estimador ML de η (dado n̂_d) es:

```
η̂ = [Σ μ̂_i · Q̂_i^m] / [Σ Q̂_i^{2m}]
```

(Weighted LS con pesos proporcionales a Q_i^{2m}, que da más peso a las orientaciones con mayor señal.)

Ahora, η̂ ≈ C·cos(ψ)/d². Queremos despejar d:

```
d² = C·cos(ψ) / η̂
```

Pero `cos(ψ) = n_r · (-n_d) / d · d = -n_r · n_d` (no depende de d, solo de la geometría angular).

**Resultado:**

```
d = sqrt( -C · (n_r · n̂_d) / η̂ )
```

### Tres escenarios

#### Escenario A: n_r conocido (e.g., IMU/acelerómetro)

Si el receptor tiene un acelerómetro (todo smartphone lo tiene), entonces n_r se conoce vía el vector de gravedad:
- n_r = [0,0,1]^T si está horizontal (caso ideal del paper)
- n_r = R(tilt) · [0,0,1]^T si está inclinado (medido por IMU)

**→ d se puede estimar sin la medición K+1.**

La posición 3D completa es:
```
r̂ = t + d̂ · n̂_d
```

**Propiedades:**
- Direction finding: sigue siendo n_r-agnostic ✅
- Distance recovery: requiere n_r (del IMU) → no n_r-agnostic para d ⚠️
- Pero: el IMU da n_r con ~1-2° de precisión, que es suficiente
- **No se requiere reorientación del PD ni medición cooperativa** ✅
- **Funciona para N receptores simultáneamente** (las K mediciones son broadcast) ✅

#### Escenario B: n_r desconocido (sin IMU)

η contiene dos incógnitas: d y cos(ψ) = -n_r · n_d.

Con solo K mediciones:
- Estimamos n̂_d (2 DoF) ✅
- Estimamos η̂ (1 DoF) ✅
- Pero η = C·cos(ψ)/d² tiene 2 incógnitas: d (1 DoF) y n_r (2 DoF en S²)
- **Subproblema indeterminado**: 1 ecuación, 3 incógnitas

**→ No se puede estimar d sin información adicional sobre n_r.**

Esto justifica por qué el paper necesita la medición K+1: al forzar cos(φ)=cos(ψ)=1, elimina la dependencia en n_r y d se aísla directamente.

#### Escenario C: n_r desconocido + restricción de altura conocida

Si z_r es conocida (e.g., receptor sobre una mesa a altura fija), entonces:
```
d = ||t - r|| = ||(0,0,H) - (x,y,z_r)|| 
```

Con n̂_d conocido: `r̂ = t + d · n̂_d`, y la componente z da:
```
z_r = H + d · (n̂_d)_z  →  d = (z_r - H) / (n̂_d)_z
```

**→ d se obtiene geométricamente sin medir potencia adicional y sin conocer n_r.**

Esto es una restricción común en VLP (piso conocido), pero pierde la generalidad 3D.

---

## Implicaciones arquitectónicas

### Comparación de arquitecturas

| Arquitectura | Mediciones | Requiere n_r | PD steering | Multi-RX | 3D completo |
|---|---|---|---|---|---|
| **TCOM actual** (K+1 cooperativo) | K+1 | No (agnostic) | Sí (reorientar) | No escala (N extra) | Sí |
| **Propuesta: K-only + IMU** | K | Sí (del IMU) | No | Sí (broadcast) | Sí |
| **K-only + altura conocida** | K | No | No | Sí (broadcast) | Pseudo-3D (z fijo) |

### La arquitectura K-only + IMU es superior en casi todo

1. **Elimina la medición cooperativa K+1** — no se requiere beam steering en el receptor
2. **Funciona para N receptores simultáneos** — las K orientaciones son broadcast, cada PD estima su propia dirección y distancia independientemente
3. **La agnosticidad de n_r se preserva donde importa** — el direction finding (la parte difícil, computacionalmente costosa) sigue sin necesitar n_r
4. **El requisito de n_r para distancia es débil** — un acelerómetro de ~1° de precisión (ubícuo en smartphones) es más que suficiente

### ¿Cuánto afecta el error en n_r a la distancia?

La sensibilidad de d a errores en n_r:

```
d = sqrt(C · |cos(ψ)| / η̂)
```

donde `cos(ψ) = -n_r · n_d`.

Para un tilt error δ en n_r:
```
cos(ψ + δ) ≈ cos(ψ) - δ·sin(ψ)
```

El error relativo en d:
```
Δd/d ≈ (1/2) · δ · tan(ψ)
```

Para ψ < 30° (zona útil del FOV) y δ = 2° (IMU):
```
Δd/d ≈ 0.5 × 0.035 × 0.577 ≈ 1%
```

**→ El error en d por incertidumbre de n_r del IMU es ~1%, despreciable frente al error de dirección.**

---

## Respuesta a las dos preocupaciones originales

### Preocupación 1: Latencia del escaneo

**Argumento para el paper:**
- La latencia K×T_reor es una limitación de implementación, no fundamental
- Con MEMS mirrors (~1ms) o OPA (~μs), K=5 toma 5ms → compatible con tracking a 1.4m/s (desplazamiento 7mm)
- El paper puede reconocer que con gimbals mecánicos (~100ms) el sistema es quasi-estático, pero la arquitectura es forward-compatible con steering rápido
- El valor del paper está en el framework teórico (DEB, estimadores, n_r-agnosticidad), no en una implementación específica de steering

### Preocupación 2: Medición cooperativa K+1

**El argumento fuerte:**
La medición cooperativa (K+1) no es estrictamente necesaria. Es una elección de diseño que maximiza SNR para ranging a costa de requerir PD steering.

**Alternativa inmediata (sin cambiar el TCOM):**
- Reconocer en el paper que "if coarse receiver orientation is available (e.g., from an accelerometer), distance can be recovered from the K direction-finding measurements alone, eliminating the cooperative alignment step"
- Esto convierte la Propuesta B (conference paper) en una extensión natural

**Para el conference paper:**
Esta alternativa K-only + IMU es una contribución publicable:
1. Derivar el estimador de η̂ y d̂ a partir de las K mediciones
2. Derivar la CRLB/PEB para esta nueva arquitectura (sin K+1)
3. Comparar con la arquitectura cooperativa del TCOM
4. Analizar multi-receiver performance

---

## ¿Cómo argumentar esto en el TCOM?

En el TCOM actual, la medición cooperativa puede justificarse así:

> "The cooperative alignment measurement (K+1) provides the maximum-SNR ranging observation by forcing cos(φ)=cos(ψ)=1. This is a **sufficient** condition for 3D localization but not a **necessary** one. If coarse knowledge of n_r is available (e.g., from an on-board accelerometer), the nuisance parameter η can be decomposed into d and cos(ψ), enabling distance recovery from the K direction-finding measurements alone—at the cost of requiring receiver orientation knowledge for the distance stage only. We adopt the cooperative formulation here because it preserves full n_r-agnosticism and maximizes ranging SNR; the IMU-assisted variant is left for future investigation."

Esta frase (o similar) en la Sección II-B (Distance Recovery) o en la Conclusión resuelve elegantemente la preocupación.

---

## Resumen ejecutivo

| Pregunta | Respuesta |
|---|---|
| ¿Se puede estimar d sin K+1? | **Sí, si se conoce n_r** (e.g., IMU) |
| ¿Direction finding sigue n_r-agnostic? | **Sí, siempre** (Proposición 1 intacta) |
| ¿Distance recovery es n_r-agnostic sin K+1? | **No** — necesita n_r para separar d de cos(ψ) |
| ¿Es grave necesitar n_r para distancia? | **No** — un acelerómetro da ~1° → error en d ~1% |
| ¿La alternativa K-only escala a N receptores? | **Sí** — K mediciones broadcast → N estimaciones paralelas |
| ¿Es publicable como conference paper? | **Sí** — contribución clara y diferenciada del TCOM |
