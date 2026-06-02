https://chatgpt.com/share/e/6a1e060b-10f0-800d-863f-c80f7de83b2f
Nota: Teoria (1 USUARIO: D-F SCAN (GLOBAL LOCALIZATION) + 4 RSS (LOCAL POSITIONING) + THRESHOLD-BASED REACQUISITION) + Validación experimental.

Sí, esa arquitectura de **un solo usuario** me parece buena y, de hecho, más defendible que meter RL desde el inicio.

La estructura sería:

[
\boxed{
\text{D-F Scan}
\rightarrow
\text{Beam lock}
\rightarrow
\text{Fine tracking}
\rightarrow
\text{Reacquisition decision}
}
]

donde el bloque de **fine tracking** puede implementarse de dos formas:

[
\boxed{
\text{RSS-based 4 perturbations}
}
]

o

[
\boxed{
\text{QPD-based angular error}
}
]

Mi recomendación: **no meter RL como contribución principal** en la primera versión. Usaría una política determinista simple para beam management y dejaría RL como extensión futura.

---

# 1. Arquitectura sin RL: sí, me parece suficiente

La arquitectura quedaría así:

## Fase 1 — D-F Scan

El TX transmite (K) orientaciones conocidas:

[
\mathbf n_{t,1},\ldots,\mathbf n_{t,K}.
]

El RX estima la dirección TX-to-RX:

[
\hat{\mathbf n}_d.
]

Esto es la adquisición inicial.

---

## Fase 2 — Beam lock

El TX apunta hacia:

[
\mathbf n_t=\hat{\mathbf n}_d.
]

Aquí empieza el enlace de alta SNR.

---

## Fase 3A — Fine tracking con 4 perturbaciones

El TX envía pequeños pilotos alrededor de la dirección actual:

[
\mathbf n_t^{(+\theta)},\quad
\mathbf n_t^{(-\theta)},\quad
\mathbf n_t^{(+\phi)},\quad
\mathbf n_t^{(-\phi)}.
]

El RX mide:

[
P_{+\theta},\quad P_{-\theta},\quad P_{+\phi},\quad P_{-\phi}.
]

Luego generas dos errores:

[
e_\theta=
\frac{P_{+\theta}-P_{-\theta}}
{P_{+\theta}+P_{-\theta}},
]

[
e_\phi=
\frac{P_{+\phi}-P_{-\phi}}
{P_{+\phi}+P_{-\phi}}.
]

Y actualizas la orientación:

[
\theta_{k+1}=\theta_k+\alpha e_\theta,
]

[
\phi_{k+1}=\phi_k+\alpha e_\phi.
]

Esto no requiere QPD. Solo requiere el PD que ya mide RSS.

Ventaja:

[
\boxed{
\text{mínimo hardware, muy conectado con tu método actual.}
}
]

Desventaja:

[
\boxed{
\text{consume overhead porque necesitas pilotos perturbados.}
}
]

---

## Fase 3B — Fine tracking con QPD

En vez de perturbar el haz, el RX usa un QPD para medir el desplazamiento del spot óptico:

[
e_x=
\frac{I_R-I_L}{I_\Sigma},
\qquad
e_y=
\frac{I_T-I_B}{I_\Sigma}.
]

Eso da un error local de alineamiento:

[
e_x,e_y
\rightarrow
\Delta \theta,\Delta \phi.
]

Entonces el TX corrige suavemente:

[
\theta_{k+1}=\theta_k+\alpha e_x,
]

[
\phi_{k+1}=\phi_k+\alpha e_y.
]

Ventaja:

[
\boxed{
\text{tracking más fluido y menos overhead de pilotos.}
}
]

Desventaja:

[
\boxed{
\text{requiere hardware adicional en el RX.}
}
]

---

# 2. RSS perturbation vs QPD: cómo lo presentaría

Yo no lo plantearía como “uno reemplaza al otro”, sino como dos niveles de arquitectura.

## Nivel 1 — Low-complexity architecture

[
\boxed{
\text{D-F acquisition + RSS perturbation tracking}
}
]

Esta es la contribución más cercana a tu paper actual.

No necesitas QPD, cámara, PSD ni hardware óptico adicional.

Es ideal si quieres decir:

> We propose a low-overhead beam acquisition and tracking protocol using only received-power measurements.

---

## Nivel 2 — Enhanced architecture

[
\boxed{
\text{D-F acquisition + QPD-aided smooth tracking}
}
]

Aquí el D-F sigue siendo necesario para adquisición global, pero el QPD hace el tracking fino.

Esto es más fuerte como arquitectura realista de enlace óptico direccional.

La frase clave sería:

[
\boxed{
\text{D-F provides global acquisition, while QPD provides local error for continuous beam tracking.}
}
]

---

# 3. Readquisición

La lógica de readquisición puede ser completamente determinista. No necesitas RL.

Puedes definir:

[
\mathrm{SNR}*k < \mathrm{SNR}*{\mathrm{th}}
]

o

[
P_{r,k}<P_{\mathrm{th}}.
]

También puedes usar el error de tracking:

[
|e_\theta|>\epsilon_{\theta,\mathrm{th}},
\qquad
|e_\phi|>\epsilon_{\phi,\mathrm{th}}.
]

O, con QPD:

[
\sqrt{e_x^2+e_y^2}>\epsilon_{\mathrm{QPD,th}}.
]

Entonces:

[
\boxed{
\text{if quality is good: keep tracking}
}
]

[
\boxed{
\text{if quality degrades moderately: local reacquisition}
}
]

[
\boxed{
\text{if quality collapses: full D-F scan}
}
]

Yo usaría una estrategia de dos niveles:

## Nivel 1 — Local reacquisition

El TX busca alrededor de la última dirección conocida:

[
\hat{\mathbf n}*d \pm \Delta*{\mathrm{large}}.
]

Esto es más barato que repetir todo el D-F scan.

## Nivel 2 — Full D-F reacquisition

Si el local scan falla:

[
\text{full }K\text{-orientation D-F scan}.
]

Esto es robusto.

---

# 4. ¿Meter RL o no?

Mi opinión: **no lo metas como contribución principal ahora**.

RL puede sonar atractivo, pero tiene varios riesgos:

1. Necesitas justificar el entorno de entrenamiento.
2. Necesitas comparar contra políticas simples.
3. Los reviewers pueden preguntar por generalización.
4. Puede distraer de tu contribución real: D-F-assisted beam acquisition/tracking.
5. Puede hacer que el paper parezca menos físico y más heurístico.

Para ICC, una arquitectura limpia y bien evaluada puede ser más fuerte que una arquitectura con RL metido de forma superficial.

Yo pondría RL solo como una frase de future work:

> The proposed deterministic beam-management logic may be further extended using reinforcement learning to optimize the trade-off between tracking overhead, reacquisition frequency, and effective throughput.

Pero no lo haría central.

---

# 5. Qué versión me parece más fuerte para ICC

La versión más sólida sería:

[
\boxed{
\textbf{Single-user D-F-assisted hybrid beam tracking}
}
]

con dos variantes comparadas:

[
\boxed{
\text{Variant 1: RSS perturbation tracking}
}
]

[
\boxed{
\text{Variant 2: QPD-aided tracking}
}
]

Así el paper no depende de RL y sigue siendo interesante porque compara dos formas de mantener el beam lock después del D-F scan.

---

# 6. Contribuciones posibles del paper

Yo formularía las contribuciones así:

1. **A D-F-assisted beam acquisition protocol** for steerable optical wireless links.

2. **A low-overhead fine-tracking mechanism** based on four local angular perturbations around the locked beam direction.

3. **An enhanced QPD-aided tracking architecture** where the QPD provides local angular error for smoother beam correction.

4. **A threshold-based reacquisition mechanism** that switches between local search and full D-F scan depending on link quality.

5. **A communication-oriented evaluation** in terms of SNR loss, outage probability, tracking overhead, and effective throughput.

Esto suena mucho más a **Optical Network Systems** que decir solo “estimamos posición”.

---

# 7. Baselines que deberías incluir

Para que el argumento sea fuerte, compararía contra:

| Baseline                             | Qué demuestra                             |
| ------------------------------------ | ----------------------------------------- |
| Periodic full D-F scan               | Tu método reduce overhead                 |
| Exhaustive beam sweeping             | Tu método adquiere más rápido             |
| Local perturbation without D-F       | Tu D-F ayuda a evitar mala inicialización |
| Fixed beam without tracking          | Tu tracking mantiene SNR ante movilidad   |
| QPD-only after random initialization | Tu D-F mejora la adquisición inicial      |

La comparación clave sería:

[
\boxed{
\text{effective throughput vs mobility speed}
}
]

No solo error angular.

---

# 8. Métricas principales

Usaría estas:

## Error angular

[
\epsilon_\Omega=
\arccos(\mathbf n_t^\mathsf T\mathbf n_d).
]

## Pérdida de SNR por desalineamiento

[
L_{\mathrm{SNR}}
================

10\log_{10}
\left(\cos^m(\epsilon_\Omega)\right).
]

## Overhead de tracking

[
\eta_{\mathrm{OH}}
==================

\frac{T_{\mathrm{training}}}{T_{\mathrm{frame}}}.
]

## Throughput efectivo

[
R_{\mathrm{eff}}
================

\left(1-\eta_{\mathrm{OH}}\right)
B\log_2(1+\mathrm{SNR}).
]

## Probabilidad de outage

[
P_{\mathrm{out}}
================

\Pr(\mathrm{SNR}<\mathrm{SNR}_{\mathrm{th}}).
]

Estas métricas son las que convierten el trabajo en un paper de comunicaciones, no solo de posicionamiento.

---

# 9. Mi recomendación final

Yo haría:

[
\boxed{
\text{Sin RL en la primera versión.}
}
]

Y estructuraría el paper como:

[
\boxed{
\text{D-F Scan}
\rightarrow
\text{Beam Lock}
\rightarrow
\text{Fine Tracking}
\rightarrow
\text{Adaptive Reacquisition}
}
]

con dos implementaciones de fine tracking:

[
\boxed{
\text{RSS-based four-point perturbation}
}
]

y

[
\boxed{
\text{QPD-aided smooth tracking}
}
]

Si quieres una versión todavía más enfocada, haz que la principal sea RSS perturbation, porque es más cercana a tu contribución original, y presenta QPD como enhanced mode.

La frase central del paper podría ser:

> The proposed architecture uses Direction-Finding for robust initial beam acquisition and switches to low-overhead local beam tracking once the optical link is locked. Reacquisition is triggered only when link quality degrades, thereby reducing training overhead while maintaining high SNR under receiver mobility.

Eso es suficientemente fuerte sin RL.
