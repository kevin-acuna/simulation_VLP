# Plan de investigación — Cambridge 2026
## Posicionamiento 3D con un único anclaje óptico fijo y un único fotodiodo reorientable (*receiver-steered single-anchor OWP*)

> **Versión:** v1 — 04/09/2026 (día 2 de la pasantía)
> **Autor:** K. Acuna-Condori (UVSQ/LISV) — pasantía de 3 meses en Cambridge con I. Tavakkolnia
> **Objetivo del documento:** cerrar la *problemática*, los *casos de uso*, la *novedad* y la *contribución* antes de escribir el código de simulación definitivo. Es un documento de trabajo para discusión (contigo y con Iman). Etiquetas: **[V]** verificado contra los textos leídos; **[V-num]** derivación propia verificada numéricamente con `plan/checks/verify_prop1_and_cone_rule.py` (Sec. 3.8); **[H]** hipótesis pendiente.
> **Fuentes leídas íntegramente:** bitácora 03-09-26; TCOM RV3 (`main.tex`); Broadcast (`main.tex`); Wang *et al.* TIM 2024 (STRP, paper de referencia); Shi *et al.* PTL 2025 (SHRP); Shi *et al.* PTL 2026 (STRP vs SHRP + ATAA); Liu *et al.* Photon. J. 2022; Ma *et al.* IoT-J 2024; Qin *et al.* Optik 2020. Complementado con búsqueda web (Sec. 12).

---

## 0. Resumen ejecutivo

**Idea en una frase.** Es el problema *dual* del TCOM: en lugar de barrer el LED por $K$ orientaciones con el PD fijo, dejamos el LED fijo (una luminaria/beacon cualquiera) y barremos el PD por $K$ orientaciones controladas en el marco del receptor. Toda la maquinaria del TCOM/Broadcast (factorización $\mu=\eta\,Q$, DEB/PEB por FIM, diseño del conjunto de orientaciones por GA, estimadores cerrados, recuperación de distancia por amplitud) se traslada con los roles intercambiados. Pero el intercambio **no es simétrico** en tres puntos que constituyen el corazón de la novedad:

1. **Linealidad.** La respuesta angular de un PD desnudo es $\cos\psi$ (orden 1), no $\cos^m\phi$. El modelo queda **lineal** en el vector $\mathbf w=\eta_R\mathbf u^B\in\mathbb R^3$: $\mu_j=\mathbf n_j^B\cdot\mathbf w$. Dirección y amplitud se estiman con un LS lineal ordinario (BLUE; MLE bajo AWGN; alcanza la CRLB), sin ratios, sin orientación de referencia y sin eigendescomposición. **[V-num: Cov$_{\rm emp}$/CRLB = 0.998; RMSE 3D/PEB = 0.996]**
2. **Marco de referencia.** El TX-steering da la dirección en el marco *del mundo*; el RX-steering la da en el marco *del cuerpo* (bearing egocéntrico). Convertir a posición 3D exige conocer la **actitud completa** del receptor. Demuestro (Sec. 3.4) que un scan estático sólo contiene 3 grados de libertad de información $(\mathbf u^B,\eta_R)$, luego **el yaw es inobservable** aunque el LED esté inclinado; con LED axisimétrico lo es incluso con movimiento. Esto convierte la limitación "hay que conocer el heading" de Wang 2024 en un **resultado fundamental**, no algorítmico. **[V-num: FIM$(x,y,z,\zeta)$ singular ($\sigma_{\min}/\sigma_{\max}\sim10^{-17}$) para $K=4,6,12$, LED vertical e inclinado 15°]**
3. **Independencia dual.** El direction-finding es independiente de $\mathbf n_t$, $m$, $P_t$ y del patrón real del LED (sólo debe ser *fijo* durante el scan). Esto ataca directamente el problema "no lambertiano" que reportan Wang 2024 (Tabla III, ajuste $C_1,C_2$) y que nos criticaron en TCOM: sólo la etapa de distancia necesita el patrón, y basta una calibración 1D $g_t(\phi)$. **[V — se sigue de la factorización]**

**Aviso honesto (Sec. 3.8):** con PD desnudo y LED lambertiano fijo ($m{=}2$) el RX-steering es intrínsecamente **menos preciso en los bordes** que el TX-steering, porque el LED no "apunta" al receptor y el PD inclinado pierde $\cos\psi$. Sobre el testbed del TCOM, la RMS-PEB pasa de 1.64 cm (TCOM, $K{=}5$) a ≈3.6 cm (cono LED-céntrico, $K{=}5$) y 8.1 cm (diseño de Wang). Se mitiga con $K$, LED más ancho ($m{=}1$: 2.6 cm), $N$/SNR, y óptica del receptor. El paper debe presentar este trade-off explícitamente, no esconderlo.

**Pregunta de investigación (refinada):**
> *Under what conditions can a single fixed optical anchor and a single actively reorientable photodiode deliver full 3D positioning through controlled receiver-orientation diversity — and what is the optimal way to spend a budget of $K$ reorientations under field-of-view and tilt constraints?*

**Objetivo editorial:** ICC 2027 (deadline 02/10/26, extensión 30/10/26) con simulación + validación experimental preliminar en el testbed CNC de Cambridge; extensión a revista (TWC/TCOM/TIM) con el modelo acoplado a movimiento (dron) y la campaña experimental completa.

---

## 1. Contexto y motivación

### 1.1 De dónde venimos **[V]**

| | TCOM (RV3) | Broadcast (ICC-style) |
|---|---|---|
| Quién se reorienta | LED ($K$ orientaciones $\mathbf n_{t,i}$, marco mundo) | LED (igual) |
| PD | fijo, orientación arbitraria y desconocida durante DF | fijo, orientación **conocida** (IMU) |
| Modelo | $\mu_i=\eta\,Q_i^{m}$, $Q_i=\mathbf n_{t,i}\!\cdot\!\mathbf n_d$, $\eta=C\cos\psi/d^2$ | idem |
| DF | ratios $\beta_i=(\mu_i/\mu_1)^{1/m}$ → hiperplanos → GLS/WLS (eigenvector) ; NLS | idem |
| Distancia | medición $K{+}1$ cooperativa (LED→PD, PD→LED) | amplitud $\hat\eta$ por proyección + $\cos\psi$ conocido |
| Propiedad clave | $\mathbf n_r$-independence del DF | PEB$_\mathrm B$; multiusuario sin coordinación |
| Resultados ($K{=}5$/$9$) | DF 0.52–0.66°; 3D APE 2.0 cm ($K{=}5$) | RMSE 1.73 cm ($K{=}9$, NLS ≈ PEB$_\mathrm B$) |
| Lo que nos criticaron | sin experimento; patrón lambertiano ideal; AWGN homoscedástico; requiere steering preciso | error de IMU no analizado; set no reoptimizado |

### 1.2 El problema dual **[V]**

Testbed de Cambridge: LED fijo en el centro-techo de una estructura; PD montado en el *end-effector* de un CNC 3D (X, Y, Z) con base rotatoria (360°) e inclinable. Es exactamente un **gimbal de 2 DOF (tilt $\theta$, azimut $\varphi$) sobre un posicionador con verdad-terreno sub-mm**. El receptor conoce su actitud (marco CNC = marco mundo) → caso "actitud conocida" ideal para validar la teoría.

### 1.3 Por qué importa

- **Infraestructura de actuación cero.** El anclaje es *cualquier* LED fijo con ID (una luminaria LiFi existente, un beacon IR). Toda la complejidad está en el receptor, que en los casos de uso relevantes (drones, robots con pan-tilt, brazos, smartphones) **ya está actuado y ya conoce su actitud**.
- **Multiusuario trivial.** Cada receptor escanea por su cuenta; no hay scan periódico del LED ni coordinación (mejor incluso que Broadcast en ese aspecto).
- **Bearing egocéntrico.** La dirección al anclaje en el marco del cuerpo es *lo que un dron/robot necesita* para guiado, docking y alineación del receptor LiFi (dual del beam-tracking del TX). Encaja con la línea de Iman (orientación del receptor en LiFi; posicionamiento habilitado por óptica avanzada + ML).
- **ADR sintético.** Un PD reorientable multiplexa en el tiempo lo que un *angle-diversity receiver* (varios PD inclinados: Qin 2020, Li 2024) hace en el espacio: menos componentes, geometría ajustable y adaptativa. Nuestro diseño óptimo de orientaciones **es también** el diseño óptimo de un ADR fijo.

---

## 2. Estado del arte y brechas

### 2.1 Tabla comparativa **[V salvo donde se indica]**

| Año | Trabajo | Config. | Quién gira | Dim. | Diseño de orientaciones | Estimador | Actitud requerida | Validación | Error |
|---|---|---|---|---|---|---|---|---|---|
| 2015 | Huang *et al.* ICOCN | 1 LED / 1 PD inclinado-rotatorio (STRP) | PD | 2D | tilt fijo, azimuts uniformes | KNN fingerprint | heading | Exp. 0.6×0.6×1.1 m | <2.5 cm |
| 2016 | Li *et al.* Opt. Eng. | 1 LED / 1 PD inclinado en plataforma rotatoria **y elevable** | PD (+ traslación z) | "3D" por rebanadas 2D | tilt fijo | geométrico | heading | Exp. | n/d *(snippet web)* |
| 2022 | Liu *et al.* Photon. J. | 1 LED / 1 PD en brazo rotatorio (SHRP) | PD | 2D | 360 rotaciones de 1° | RF + ELM + DBSCAN | heading | Sim. 5×5×3 m, NLOS 1er orden | 1.74 cm |
| 2024 | **Wang *et al.* TIM** (referencia) | 1 LED / STRP | PD | **2D** ($z$ conocido) | $\theta{=}20^\circ$ fijo, $N{=}4$ a 0/90/180/270°, elegidos por CRLB **promediado** | LS (ratios) + IGWO (9.7 ms) | **heading** (Fig. 22, "limitación") + **orientación del LED conocida** (Sec. IV-B) | Sim. 5×5×3 m con NLOS 1er orden; Exp. **50×50×30 cm**, 25 pts, rotación **manual** | ≈0.9 cm APE (1.65 cm junto a pared) — *verificar cifra global* |
| 2025 | Shi *et al.* PTL | 1 LED / SHRP (brazo 20 cm) | PD | 2D | 4 rotaciones de 90°, brazo por CRLB | LS | heading | Sim. 5×5×4 m; Exp. h=0.59 m, 36 pts | 2.52 cm sim / 4.96 cm exp |
| 2026 | Shi *et al.* PTL | STRP vs SHRP | PD | 2D | **ATAA**: tilt adaptado por posición al límite de FOV (iterativo, 2 pasadas) | LS | heading | Sim. (SDSN) | LS 5.03 → ATAA 2.50 cm |
| 2020 | Qin *et al.* Optik | 1 LED / 4 PD (1 horiz + 3 a 25°) | nadie (ADR) | 3D | fijo por hardware | ratios de potencia, cerrado | fijo (vertical) | Sim. 1×1×1.5 m | 2.52 cm |
| 2024 | Ma *et al.* IoT-J | 1 LED / multi-PD + IMU | nadie (ADR) | 3D | fijo por hardware | SQP / SGD (DL) | IMU (arbitraria) | Exp., dataset público | 1.77 cm |
| 2026 | **TCOM (nuestro)** | 1 LED steerable / 1 PD | **LED** | 3D | GA sobre DEB, 3D | GLS/WLS cerrado, NLS | ninguna en DF; 1 reorientación coop. | Sim. 3×3×2 m | 2.0 cm ($K{=}5$) |
| 2026 | **Broadcast (nuestro)** | 1 LED steerable / 1 PD | **LED** | 3D | set del TCOM | NLS + $\hat\eta$ proyección | $\mathbf n_r$ conocido | Sim. | 1.73 cm ($K{=}9$) |
| — | **Este trabajo** | **1 LED fijo / 1 PD reorientable (gimbal 2-DOF)** | **PD** | **3D** | **GA sobre PEB 3D con restricciones (FOV, $\theta_{\max}$) + regla cerrada (cono LED-céntrico)** | **LS lineal cerrado (BLUE), NLS** | **actitud completa (teorema)** | **Sim. + Exp. CNC 3D** | objetivo: cm-level 3D |

Otros relacionados: Zhou–Liu–Lau (TWC 2019) y Shen–Li–Steendam (TWC 2022): límites de estimación conjunta posición+orientación, **multi-LED**; Arfaoui *et al.* (JSAC 2021, con Tavakkolnia) y OJCOMS 2024: posición+orientación por DL en LiFi **multi-AP**; Soltani *et al.* (WCNC 2019, con Tavakkolnia): efecto de la orientación aleatoria del receptor en la ganancia LiFi, *tilt óptimo depende de la posición*; IRS-SPAO single-LED single-PD (IoT-J 2025): diversidad por *slots* de un IRS; VCSEL scanning single-Tx (arXiv 2026): TX-side, pariente del TCOM. Drones: Firefly (DCOSS-IoT 2023, 4 beacons + 1 PD + IMU/baro, decímetros; observa que los errores angulares en el TX ($\cos^m$) pesan más que en el RX ($\cos$)); VLP/INS acoplado con inclinación variable del PD (Satellite Navigation 2025).

### 2.2 Brechas identificadas

- **G1 — No existe 3D genuino por diversidad de orientación del receptor.** Todo lo publicado con 1 LED / 1 PD rotatorio es 2D con $z$ conocido; el único "3D" (Li 2016) usa traslación vertical física.
- **G2 — Diseño de orientaciones ad hoc.** Tilt fijo (20°) y azimuts uniformes; el CRLB sólo se usa para escoger $\theta$ y $N$ *promedio*. Nadie optimiza un *conjunto* 3D con 2 DOF por orientación bajo restricciones de FOV/mecánicas; ATAA adapta el tilt al límite de FOV por posición, sin criterio de información.
- **G3 — Estimadores iterativos/metaheurísticos** (GWO 9.7 ms; ELM; fingerprints) donde el problema admite una solución **lineal cerrada** de µs.
- **G4 — El requisito de heading conocido se declara como "limitación práctica"** sin análisis de observabilidad: ¿es fundamental o algorítmico? (Respuesta: fundamental, Sec. 3.4.)
- **G5 — Dependencia del patrón y la orientación del LED.** Wang muestra que su método necesita $\mathbf n_t$ conocido y que el lambertiano ajusta peor que un fit empírico. Nadie explota que el DF por diversidad del receptor **no depende** del LED.
- **G6 — Receptor móvil.** Ningún trabajo formula la reorientación acoplada a desplazamiento (dron que se inclina se traslada; hover con deriva).
- **G7 — Testbeds diminutos** (50×50×30 cm) y rotación manual. El CNC de Cambridge permite un volumen mucho mayor con verdad-terreno sub-mm y reorientación motorizada.

---

## 3. Formulación del problema

### 3.1 Geometría y marcos **[V]**

- Marco mundo $\mathcal W$: LED en $\mathbf t=[0,0,H]^{\mathsf T}$, eje óptico $\mathbf n_t$ (nominal $-\mathbf u_z$), orden lambertiano $m$ (o patrón calibrado $g_t(\phi)$). Constante radiométrica $C=P_t(m{+}1)A_{\det}/2\pi$.
- Receptor en $\mathbf r$ desconocido, con marco cuerpo $\mathcal B$ y actitud $\mathbf R\in SO(3)$ ($\mathcal B\to\mathcal W$).
- Desplazamiento $\mathbf d=\mathbf r-\mathbf t$, $d=\|\mathbf d\|$, $\mathbf n_d=\mathbf d/d$ (LED→PD), $\mathbf u=-\mathbf n_d$ (PD→LED). En el cuerpo: $\mathbf u^B=\mathbf R^{\mathsf T}\mathbf u$.
- Normal del PD en la $j$-ésima orientación **comandada en el marco cuerpo**: $\mathbf n_j^B=[\sin\theta_j\cos\varphi_j,\ \sin\theta_j\sin\varphi_j,\ \cos\theta_j]^{\mathsf T}$, $j=1..K$; en el mundo $\mathbf n_j^W=\mathbf R\,\mathbf n_j^B$.

### 3.2 Modelo de observación y factorización **[V]**

$$\mu_j=\frac{C}{d^2}\,\underbrace{\cos^m\!\phi}_{(\mathbf n_t\cdot\mathbf n_d)^m}\ \underbrace{\cos\psi_j}_{\mathbf n_j^W\cdot\mathbf u}\ \mathbb 1[\psi_j\le\Psi_{\rm FOV}],\qquad \hat\mu_j\sim\mathcal N(\mu_j,\sigma^2/N).$$

Como $\mathbf n_j^W\cdot\mathbf u=(\mathbf R\mathbf n_j^B)\cdot\mathbf u=\mathbf n_j^B\cdot\mathbf u^B$:

$$\boxed{\ \mu_j=\eta_R\,(\mathbf n_j^B\cdot\mathbf u^B)=\mathbf n_j^B\cdot\mathbf w,\qquad \eta_R=\frac{C\cos^m\phi}{d^2},\qquad \mathbf w\triangleq\eta_R\,\mathbf u^B\in\mathbb R^3\ }$$

Es el dual exacto de $\mu_i=\eta\,Q_i^m$ del TCOM, pero con exponente **1** en el término que varía. Consecuencias inmediatas:

- **Linealidad [V-num]:** $\boldsymbol\mu=\mathbf N\mathbf w$ con $\mathbf N=[\mathbf n_1^B\cdots\mathbf n_K^B]^{\mathsf T}\in\mathbb R^{K\times3}$. Estimador $\hat{\mathbf w}=(\mathbf N^{\mathsf T}\mathbf N)^{-1}\mathbf N^{\mathsf T}\hat{\boldsymbol\mu}$ (BLUE; MLE bajo AWGN; $\mathrm{Cov}=\tfrac{\sigma^2}{N}(\mathbf N^{\mathsf T}\mathbf N)^{-1}$ = CRLB). Luego $\hat{\mathbf u}^B=\hat{\mathbf w}/\|\hat{\mathbf w}\|$, $\hat\eta_R=\|\hat{\mathbf w}\|$. No hay orientación de referencia (adiós al problema de correlación por $\hat\mu_1$ que penalizaba a WLS en TCOM). Con SDSN ($\sigma_j^2=\sigma_0^2+\xi^2\mu_j$, como Shi 2026) el BLUE es un WLS diagonal, también cerrado.
- **Independencia dual [V]:** $\hat{\mathbf u}^B$ no depende de $\mathbf n_t$, $m$, $P_t$, $C$, $d$ ni del patrón del LED (que sólo entra en $\eta_R$). Requisito: LED *fijo* durante el scan y respuesta angular del PD conocida ($\cos\psi$ o una curva calibrada 1D $g_r(\psi)$ — mucho más fácil de medir que el patrón de una luminaria).
- **Identificabilidad de $\mathbf w$:** rank$(\mathbf N)=3\iff$ $K\ge3$ normales **no coplanares** (un cono con $\theta>0$ y $\ge3$ azimuts distintos sirve; Wang con $N{=}4$ cumple). $K{=}3$ justo-determinado; $K\ge4$ sobredeterminado y robusto a *dropouts* de FOV.

### 3.3 Tabla de dualidad TX-steered ↔ RX-steered

| Aspecto | TX-steered (TCOM/Broadcast) | RX-steered (este trabajo) |
|---|---|---|
| Variable barrida | $\mathbf n_{t,i}$ (marco mundo) | $\mathbf n_j^B$ (marco cuerpo) |
| Término que varía | $\cos^m\phi_i$ (orden $m$) | $\cos\psi_j$ (orden 1) |
| Factor común | $\eta=C\cos\psi/d^2$ (absorbe $\mathbf n_r$) | $\eta_R=C\cos^m\phi/d^2$ (absorbe $\mathbf n_t$, $m$) |
| Dirección estimada | $\mathbf n_d$ en $\mathcal W$ (alocéntrica) | $\mathbf u^B$ en $\mathcal B$ (egocéntrica) |
| Independencia | de $\mathbf n_r$ (pose del receptor) | de $\mathbf n_t$, $m$, patrón del LED |
| Modelo en la incógnita | no lineal ($Q^m$) → ratios$^{1/m}$ + eigenvector / NLS | **lineal** en $\mathbf w$ → LS cerrado |
| Sensibilidad angular por medida | $m\,Q_i^{m-1}\,\eta$ ($\approx m\eta$ cerca del eje) | $\eta_R$ (≡ caso $m{=}1$) |
| FIM de DF | $\tilde{\mathbf g}_i=[mQ^{m-1}(\mathbf n_{t,i}\!\cdot\!\mathbf u_\theta),\ mQ^{m-1}(\mathbf n_{t,i}\!\cdot\!\mathbf u_\varphi),\ Q^m]$ | $\tilde{\mathbf g}_j=[\mathbf n_j\!\cdot\!\mathbf u_\theta,\ \mathbf n_j\!\cdot\!\mathbf u_\varphi,\ \mathbf n_j\!\cdot\!\mathbf u]$ |
| Gradiente para PEB | ec. (grad_mu_closed) del TCOM | **la misma ecuación** con $\mathbf n_{t,i}\to\mathbf n_t$ y $\mathbf n_r\to\mathbf n_j^W$ → código reutilizable |
| Para cerrar 3D se necesita | $\mathbf n_r$ conocido (Broadcast) o alineación coop. (TCOM) | **actitud $\mathbf R$ completa** |
| Restricción dura | cobertura lambertiana | **FOV del PD** + $\theta_{\max}$ mecánico |
| Multiusuario | Broadcast: 1 scan sirve a todos | cada RX escanea solo; infraestructura pasiva |
| Latencia | steering MEMS (kHz) | servo/gimbal (decenas–cientos ms) o MEMS delante del PD |

**Predicción cuantitativa [H, parcialmente V-num en Sec. 3.8]:** a igual SNR y geometría comparable, el DEB del RX-steered es ≈ $m\times$ el del TX-steered (la información de Fisher angular escala con $m^2$). Con $\Phi_{1/2}=45^\circ$ ($m{=}2$) esperamos ≈2× peor DEB con PD desnudo; además, el LED fijo no apunta al receptor (pérdida $\cos^m\phi$ en los bordes que el TX-steering evita al orientar el haz). Se recupera con óptica que estreche $g_r(\psi)$ (lente/CPC, "orden lambertiano del receptor" $m_r>1$) a costa de FOV — **es una pregunta de diseño óptico** (interés declarado de Iman) que vale una figura: PEB vs $(\Psi_{\rm FOV},m_r)$.

### 3.4 Qué observa un scan estático — teorema de contenido de información **[V-num]**

> **Proposición 1 (contenido de información de un scan estático).** Para cualquier respuesta angular del receptor de la forma $g_r(\mathbf n_j^B\cdot\mathbf u^B)$ y cualquier patrón del LED, el vector de medias $\boldsymbol\mu(\mathbf r,\mathbf R)$ depende de $(\mathbf r,\mathbf R)$ **únicamente a través de** $(\mathbf u^B,\eta_R)\in\mathbb S^2\times\mathbb R_+$, es decir, de 3 grados de libertad, para cualquier $K$ y cualquier conjunto $\{\mathbf n_j^B\}$.
> *Prueba:* $\mu_j=\eta_R(\mathbf r)\,g_r(\mathbf n_j^B\cdot\mathbf R^{\mathsf T}\mathbf u(\mathbf r))$. $\square$

**Corolarios:**
- **C1 (actitud necesaria).** Con $\mathbf r$ (3 DOF) desconocido, *cualquier* componente adicional desconocida de la actitud (p. ej., el yaw $\zeta$ con pitch/roll dados por el acelerómetro) hace el problema **no identificable**, sea cual sea $K$ y **aunque el LED esté inclinado**. Lo que sí se recupera: $\mathbf u^B$ y $\eta_R$. Con LED vertical y pitch/roll conocidos, $\phi$ es observable, luego $d$ también, y la posición queda en un **círculo horizontal** de radio $d\sin\phi$ centrado en el eje del LED (ambigüedad de yaw).
- **C2 (con actitud completa).** Posición identificable: $\mathbf u^W=\mathbf R\hat{\mathbf u}^B$ fija el rayo desde $\mathbf t$; $\cos\phi=-\mathbf n_t\cdot\mathbf u^W$ conocido; $\eta_R=C\cos^m\phi/d^2$ monótona en $d$ ⇒ $d$ único. Se necesita $K\ge3$ normales no coplanares (para $\mathbf w$).
- **C3 (anclaje axisimétrico).** Si $\mathbf n_t\parallel\mathbf u_z$, la rotación global alrededor del eje vertical del LED deja invariantes todas las medidas ⇒ el yaw es inobservable **incluso con movimiento del receptor**. Romper la simetría requiere un anclaje asimétrico (LED inclinado con $\mathbf n_t$ conocido, patrón no axisimétrico) **y** diversidad traslacional (Sec. 3.6) — candidato a contribución de revista: *estimación conjunta posición+heading con un solo anclaje*.

Esto responde de forma definitiva a la pregunta de la bitácora ("si se monta sobre algo que gire hay que conocer el giro"): **sí, y no hay forma de evitarlo con un scan estático**. Para el dron: IMU con magnetómetro/odometría visual/heading del FC; para el CNC: trivial ($\mathbf R=\mathbf I$).

### 3.5 Recuperación de distancia y posición 3D **[V, reutiliza Broadcast]**

Dos variantes, ambas necesitan $\mathbf R$ y $\cos\phi$:

- **(a) Broadcast-like (sin medición extra).** $\hat\eta_R=\|\hat{\mathbf w}\|$ (o el estimador de proyección de Broadcast, que aquí coincide con el LS), $\hat d=\sqrt{C\,g_t(\hat\phi)/\hat\eta_R}$, $\hat{\mathbf r}=\mathbf t-\hat d\,\mathbf R\hat{\mathbf u}^B$. El patrón del LED entra sólo aquí, y puede ser una **curva calibrada 1D** $g_t(\phi)$ (Wang usa $C_2/d^{C_1}$ ajustado: caso particular).
- **(b) Alineación cooperativa unilateral.** Tras el DF, apuntar el PD a $\hat{\mathbf u}^B$ ($\psi\approx0$) y medir $\mu_{K+1}=\eta_R$ con SNR máxima. Como el LED es fijo no hay coordinación con la infraestructura; es simplemente una fila más en $\mathbf N$ (fusionable en el mismo LS). Bonus: es exactamente la **alineación del receptor LiFi** hacia el AP (ISAC: posicionar y alinear con el mismo scan).

### 3.6 El caso del dron: reorientación acoplada a desplazamiento **[H — formulación a desarrollar]**

Dos fuentes de diversidad de orientación en un dron:
- **Controlada:** micro-gimbal (2 servos, gramos) sobre el dron en hover. La posición deriva unos cm durante el scan (viento, control).
- **Oportunista:** el propio cambio de actitud del multirrotor (pitch/roll para acelerar) marcado por la IMU. Inclinar el cuerpo $\beta$ implica aceleración horizontal $\approx g\tan\beta$ ⇒ **la reorientación implica traslación**, y grande.

Modelo: $\mathbf r_j=\mathbf r_0+\boldsymbol\Delta_j$, con $\boldsymbol\Delta_j$ (i) conocido por preintegración IMU/odometría del FC en ventanas cortas, o (ii) desconocido (ruido). Entonces $\mu_j=C\cos^m\phi_j\,(\mathbf n_j^W\cdot\mathbf u_j)/d_j^2$ y **el factor común ya no cancela**: el LS lineal se sesga y hay que pasar a NLS/ML con el modelo completo (o un LS "compensado en movimiento" a primer orden).

Qué estudiar:
1. **Robustez** (para ICC, análogo a la robustez a tilt del TCOM): degradación del LS estático vs $\sigma_\Delta$ (hover jitter 1–3 cm) y vs $v\,T_{\rm scan}$; condición $v\,T_{\rm scan}\ll\epsilon_{\rm pos}$ como en Broadcast.
2. **Diversidad traslacional como información** (revista): con $\boldsymbol\Delta_j$ conocidos, la variación de $\eta$ con $d_j$ aporta información de **rango sin calibración radiométrica** ($C$ desconocido) — *motion-aided calibration-free ranging*. FIM con parámetros $(\mathbf r_0, \log C)$.
3. **Heading observable** (revista): con anclaje asimétrico + $\boldsymbol\Delta_j$ conocidos, estimación conjunta $(\mathbf r_0,\zeta)$ (Sec. 3.4-C3).
4. **Fusión** (revista): EKF/factor-graph IMU + medidas ópticas por orientación (cf. VLP/INS acoplado, Satellite Navigation 2025).

### 3.7 Restricciones de diseño

- **FOV.** $\mathbf n_j^B\cdot\mathbf u^B\ge\cos\Psi_{\rm FOV}$. Con cono centrado en la vertical del cuerpo y LED a cenit $\phi$ desde el receptor, la orientación "opuesta" ve $\psi=\phi+\theta$ ⇒ $\theta_{\max}\lesssim\Psi_{\rm FOV}-\phi_{\max}$ (en el testbed del TCOM, $\phi_{\max}\approx69^\circ$ y $\Psi_{\rm FOV}=85^\circ$ ⇒ $\theta_{\max}\approx16^\circ$). **Esta es la razón física del 20° de Wang** y del ATAA de Shi. Alternativas: permitir *dropouts* con $K\ge4$ y descartar medidas bajo umbral; o diseño adaptativo LED-céntrico (Sec. 5, C3).
- **Mecánica:** $\theta\le\theta_{\max}$ del gimbal; tiempo de asentamiento por movimiento.
- **Directividad del receptor:** PD desnudo ($m_r{=}1$) vs lente/CPC ($m_r>1$, FOV menor). Trade-off sensibilidad ↔ cobertura ↔ dropouts.
- **Ruido:** AWGN + SDSN; luz ambiente (SNR efectiva).
- **NLOS:** reflexiones de 1er orden (Wang: LS puro falla junto a paredes, 0.8 m). Las orientaciones del PD apuntan mayoritariamente hacia arriba ⇒ menor captación de paredes que un PD horizontal; a cuantificar por simulación con modelo de reflexión estándar (Kahn–Barry) y en el testbed.

### 3.8 Verificación numérica preliminar (04/09) — `plan/checks/verify_prop1_and_cone_rule.py`

Script Python (numpy) con FIM por diferencias finitas, parámetros del TCOM ($P_t=0.405$ W, $\Phi_{1/2}=45^\circ\Rightarrow m=2$, $A_{\det}=26.4$ mm², $\Psi_{\rm FOV}=85^\circ$, $N=1000$, $\sigma^2=3\times10^{-14}$ W², LED en $[0,0,2]$, testbed 3×3×1.2 m, 1792 puntos). Resultados:

| Chequeo | Resultado | Conclusión |
|---|---|---|
| Prop. 1: FIM en $(x,y,z,\zeta)$ con $K\in\{4,6,12\}$ normales aleatorias, LED vertical **e inclinado 15°** | $\sigma_{\min}/\sigma_{\max}\approx10^{-17}$ en todos los casos | rango 3: yaw inobservable en scan estático, **incluso con LED inclinado** ✔ |
| FIM en $(x,y,z)$ con actitud conocida | rango 3 si normales no coplanares; **rango 2** con 3 normales coplanares | condición $K\ge3$ no coplanares ✔ |
| LS lineal ($K{=}5$: nadir + cono 35°) vs CRLB de $\mathbf w$, 20 000 MC | $\mathrm{tr(Cov)/tr(CRLB)}=0.998$; sesgo $7\times10^{-5}$ relativo; DF 0.62° RMS; **RMSE 3D 2.55 cm vs PEB 2.56 cm** | el LS cerrado es eficiente y el plug-in de posición alcanza la PEB ✔ |
| Cono LED-céntrico, $K{=}4$: $\arg\min_{\theta_c}$ PEB exacta en 3 posiciones (cenit del LED 17°, 47°, 69°) | 62.5°, 65°, 70° (fórmula: 62.5°); PEB(20°)/PEB(opt) = **2.36, 2.44, 2.62** (fórmula: 2.35) | regla $\tan\theta_c^\star=2$ válida; la aproximación se degrada en los bordes (acoplamiento $\cos^m\phi$) pero el óptimo se mantiene en 62–70° ✔ |
| Cono **vertical** a 63.4° (no adaptativo) | PEB finita en el centro; **singular** (dropouts de FOV) a 47° y 69° de cenit | el cono grande sólo es viable si se centra en el LED (adaptativo) o con GA consciente de FOV ✔ |

**RMS-PEB sobre el testbed completo (LED vertical, actitud conocida):**

| Diseño | $K$ | RMS | mediana | P90 |
|---|---|---|---|---|
| Wang: cono vertical 20°, 4×90° | 4 | 8.08 cm | 5.06 cm | 12.96 cm |
| cono vertical 20° + nadir | 5 | 8.04 cm | 5.04 cm | 12.89 cm |
| cono vertical 40° + nadir | 5 | 7.89 cm | 2.97 cm | 9.13 cm |
| **cono LED-céntrico 63.4° (adaptativo)** | 4 | 4.02 cm | 2.21 cm | 5.86 cm |
| **cono LED-céntrico 63.4° (adaptativo)** | 5 | **3.60 cm** | 1.97 cm | 5.24 cm |
| **cono LED-céntrico 63.4° (adaptativo)** | 9 | **2.68 cm** | 1.47 cm | 3.91 cm |
| Wang 20°, LED $m{=}1$ ($\Phi_{1/2}=60^\circ$) | 4 | 6.33 cm | 4.82 cm | 9.99 cm |
| LED-céntrico 63.4°, LED $m{=}1$ | 5 | **2.58 cm** | 1.92 cm | 4.09 cm |
| *Referencia TCOM (TX-steered coop.)* | 5 | *1.64 cm* | — | *2.53 cm* |
| *Referencia Broadcast (TX-steered, $\mathbf n_r$ conocido)* | 5 / 9 | *2.49 / 1.72 cm* | — | *3.76 / 2.69 cm* |

Lecturas: (i) el diseño LED-céntrico reduce la RMS-PEB **2.2×** respecto al de Wang a igual $K$; (ii) la mediana es cm-level en todos los diseños razonables, pero la **cola (bordes, cenit ≈70°)** domina la RMS por la pérdida $\cos^m\phi\cdot\cos\psi$ con LED fijo; (iii) un LED más ancho ($m{=}1$) mejora los bordes (2.6 cm) — con RX-steering conviene un anclaje de haz ancho, al revés que en TCOM; (iv) el gap frente a Broadcast a igual $K$ es ≈1.4× y frente a TCOM ≈2.2× — coherente con la predicción del factor $m$. Todo esto todavía sin GA (que debería mejorar sobre el cono puro), sin $N$ ni SNR ajustados al testbed real y sin óptica en el receptor.

---

## 4. Casos de uso

| Caso de uso | Quién da la actitud | Actuación | Tipo de diversidad | ¿Movimiento durante el scan? | Valor del bearing egocéntrico |
|---|---|---|---|---|---|
| **Dron indoor** (inventario en almacén, invernadero, inspección; **precision landing/docking** sobre pad con 1 LED IR) | IMU + magnetómetro/heading del FC | micro-gimbal (controlada) o actitud del cuerpo (oportunista) | ambas | sí (Sec. 3.6) | guiado bearing-only hacia el beacon + descenso por $d$ |
| **AGV/robot móvil con cabezal pan-tilt** (ya llevan pan-tilt para cámara/LiDAR) | odometría + IMU | pan-tilt existente | controlada | pequeño o nulo (parar a medir) | 1 LED por sala/pasillo; corrección de deriva de heading (revista, C3) |
| **Brazo robótico / CNC / herramienta** (el propio testbed) | cinemática del robot | muñeca | controlada | nulo | verificación/calibración de la posición del efector respecto a un beacon de celda |
| **Smartphone / wearable / AR** | IMU del dispositivo | movimiento natural de la mano/cabeza (oportunista, marcada por IMU) | oportunista | sí (deriva) | modelo de orientación aleatoria (Soltani 2019): convertir el "problema" de la orientación aleatoria en *fuente de información* |
| **Receptor LiFi orientable** (ISAC) | conocida | gimbal/ADR conmutado | controlada | nulo | DF = **alineación del receptor al AP** (dual del beam-tracking); posicionamiento single-AP para handover/RA |
| **Entornos con 1 lámpara visible** (pasillos, túneles, minas, cabinas, hospitales) | según plataforma | según plataforma | — | — | motivación estándar single-LED (Ma 2024, Shi 2025) |

**Por qué no una cámara:** peso, potencia, cómputo, privacidad, latencia; el PD opera con IR modulado en oscuridad y da rango por RSS. **Por qué no un ADR fijo:** el PD reorientable es el ADR multiplexado en tiempo con geometría ajustable (y nuestro diseño óptimo sirve para ambos).

---

## 5. Novedad y contribuciones propuestas

**C1 — Formulación 3D y observabilidad del RX-steered single-anchor OWP.** Factorización lineal $\boldsymbol\mu=\mathbf N\mathbf w$; Proposición 1 y corolarios (3 DOF de información; actitud necesaria; yaw inobservable en scan estático; axisimetría ⇒ inobservable incluso con movimiento); condiciones de identificabilidad ($K\ge3$ no coplanares); dualidad formal con el TX-steering e **independencia respecto al LED** (orientación, orden, patrón, potencia). *Nadie ha establecido esto; explica como fundamental la "limitación" de Wang.*

**C2 — Cotas y diseño del conjunto de orientaciones bajo restricciones.** DEB (en $\mathbb S^2$, marco cuerpo) y PEB 3D reutilizando la FIM del TCOM con roles intercambiados; GA sobre RMS-PEB en el testbed 3D con variables $\{(\theta_j,\varphi_j)\}$, restricciones $\theta_j\le\theta_{\max}$, FOV con dropouts, y SDSN. Comparación directa con la configuración de Wang ($20^\circ$, 4×90°) y con ATAA. Estudio PEB vs $(K,\theta_{\max},\Psi_{\rm FOV},m_r,\mathrm{SNR})$.

**C3 — Regla de diseño cerrada: cono LED-céntrico (monopulso óptico) [V-num, Sec. 3.8].** Si el cono de $K$ orientaciones se centra en la dirección estimada $\hat{\mathbf u}^B$ (segunda pasada adaptativa) con semiángulo $\theta_c$ y azimuts uniformes, la FIM se desacopla: $\mathbf N^{\mathsf T}\mathbf N=\mathrm{diag}(\tfrac K2\sin^2\theta_c,\tfrac K2\sin^2\theta_c,K\cos^2\theta_c)$ en el marco de $\mathbf u$. Entonces
$$\mathrm{PEB}^2\approx\frac{d^2\sigma^2}{N K\eta_R^2}\Big[\frac{4}{\sin^2\theta_c}+\frac{1}{4\cos^2\theta_c}\Big]\ \Rightarrow\ \tan\theta_c^\star=2\ (\theta_c^\star\approx63.4^\circ),$$
siempre que $\theta_c\le\Psi_{\rm FOV}$ (¡todas las orientaciones ven el LED a $\psi=\theta_c$, sin dropouts y **sin dependencia de la posición**!). Para el error isotrópico en $\mathbf w$ el óptimo es el "ángulo mágico" $\tan^2\theta=2$ ($54.7^\circ$). Frente a $20^\circ$ (Wang) el factor entre corchetes pasa de 34.5 a 6.25 ⇒ **≈2.3× mejor PEB** (verificado: 2.36–2.62× según posición; RMS sobre el testbed 2.2×). Es la versión con criterio de información del ATAA, y la analogía con el **monopulso por comparación de amplitud** (K=4 cuadrantes + canal suma) conecta con radar/beam-tracking. *Caveats:* ignora el acoplamiento de $\cos\phi(\hat{\mathbf u})$ en el término radial (el óptimo exacto se desplaza a 65–70° en los bordes) y las restricciones de positividad; el óptimo exacto lo da el GA. Dos pasadas ⇒ ~2× latencia; alternativa de una pasada: cono vertical + una orientación cenital (como el $K{=}5$ del TCOM), pero el cono vertical grande produce dropouts de FOV en los bordes (Sec. 3.8), por lo que el diseño de una pasada debe salir del GA con máscara de FOV.

**C4 — Estimadores.** LS lineal cerrado (BLUE/MLE, alcanza la CRLB de $\mathbf w$; O($K$) + un sistema 3×3; sin referencia; µs) y su WLS para SDSN; NLS para $m_r\ne1$ o modelo con movimiento; recuperación de distancia por amplitud con patrón calibrado 1D. Comparación con LS-ratios de Wang y con LS-IGWO (9.7 ms) en igualdad de condiciones. **Respuesta a "¿GLS sigue siendo bueno?": sí, pero aquí está dominado por algo más simple y estadísticamente eficiente.**

**C5 — Validación experimental 3D en el testbed CNC** (primera para 1 LED / 1 PD reorientable en 3D; volumen ≫ 50×50×30 cm; reorientación motorizada; verdad-terreno sub-mm). Incluye la verificación experimental de la independencia del DF respecto a la inclinación del LED (si el LED puede inclinarse) — un resultado muy vendible.

**C6 (revista) — Receptor móvil.** Modelo acoplado reorientación–desplazamiento, robustez a hover jitter, rango sin calibración por diversidad traslacional, heading observable con anclaje asimétrico, fusión IMU.

**Delimitación frente a nuestros propios papers:** TCOM = TX-steered + alineación cooperativa; Broadcast = TX-steered + $\mathbf n_r$ conocido; **este = RX-steered + actitud conocida**, con linealidad, bearing egocéntrico, teorema de actitud, independencia del LED, diseño bajo FOV y experimento. Comparte el estimador de amplitud de Broadcast (se cita, no se reclama).

---

## 6. Preguntas de la bitácora — respuestas preliminares

| Pregunta | Respuesta preliminar | Estado |
|---|---|---|
| **Observabilidad: nº mínimo de reorientaciones** | $K\ge3$ normales no coplanares para $\mathbf w$ (dirección + amplitud); $K{=}3$ justo-determinado; $K\ge4$ recomendado por dropouts de FOV. Con actitud completa ⇒ 3D. Sin actitud completa ⇒ **no identificable** para ningún $K$ (Prop. 1). | [V-num] rango de FIM verificado (Sec. 3.8) |
| **Diseño de orientaciones (GA/PSO, $\theta_{\max}$, FIM)** | GA sobre RMS-PEB con restricciones (reutilizar TCOM); baseline analítica: cono LED-céntrico $\tan\theta_c=2$ (2.2× mejor que Wang en RMS-PEB); comparar con Wang/ATAA; estudiar FOV y $m_r$. | [V-num] regla cerrada verificada; GA por implementar |
| **Estimación 3D: ¿GLS sigue bueno?** | Sí, pero el problema es lineal en $\mathbf w$: LS ordinario es BLUE/MLE y alcanza la CRLB; GLS por ratios es innecesario. NLS sólo para $m_r\ne1$ o movimiento. | [V-num] RMSE 3D/PEB = 0.996 por MC |
| **Desempeño experimental** | Plan en Sec. 8; primero caracterizar LED, PD, gimbal, ruido; luego grilla 3D × $K$ × $N$. | pendiente hardware |
| **"Cuando el dron se reorienta también se desplaza"** | Formulado en Sec. 3.6; para ICC: análisis de robustez; para revista: modelo acoplado con IMU. | [H] |

---

## 7. Metodología y plan de simulación (reutilizando el código del TCOM)

Carpeta propuesta: `CAMBRIDGE/simulations/` (MATLAB, misma estructura que TCOM/Broadcast). Cambios mínimos: (i) `grad_mu` con $\mathbf n_t$ fijo y $\mathbf n_r\to\mathbf n_j^W=\mathbf R\mathbf n_j^B$; (ii) FIM de DF con $m\to1$ en el término del receptor; (iii) GA con genotipo $\{(\theta_j,\varphi_j)\}$ del receptor y restricción $\theta_j\le\theta_{\max}$ + máscara FOV; (iv) estimador LS lineal; (v) recuperación de distancia de Broadcast con $\cos\psi\to\cos^m\phi$.

Parámetros base: los del TCOM (Tabla GA: 3×3×2 m, 1792 puntos, $P_t=0.405$ W, $\Phi_{1/2}=45^\circ$, $A_{\det}=26.4$ mm², $\Psi_{\rm FOV}=85^\circ$, $N=1000$, $\sigma^2=3\times10^{-14}$ W²) **y** los de Wang (5×5×3 m, $\Psi_c=60^\circ$, $\theta=20^\circ$, $N{=}4$) para comparación justa. Añadir el volumen real del CNC de Cambridge cuando se conozca.

**Figuras/tablas objetivo para ICC (6 páginas):**
1. Esquema del sistema + marcos $\mathcal W/\mathcal B$ (gimbal sobre dron / CNC).
2. Tabla SoA (Sec. 2.1 compactada).
3. Heatmap PEB en $z$ fijo: Wang ($20^\circ$, 4×90°) vs GA vs cono LED-céntrico.
4. RMS-PEB vs $K$ para $\theta_{\max}\in\{20^\circ,40^\circ,60^\circ\}$ y vs $\Psi_{\rm FOV}$ (con/sin dropouts).
5. RMS-PEB/DEB vs SNR (pendiente $-1/2$) con banda $K\in[3,9]$; superponer la predicción TX-steered del TCOM (factor $m$).
6. CDF del error 3D por MC: LS, WLS-SDSN, NLS, PEB; y baseline LS-ratios de Wang 2D (con $z$ conocido) para mostrar que el 3D no cuesta precisión.
7. Robustez: (a) error de actitud (IMU) $\sigma_{\rm att}\in[0.5^\circ,5^\circ]$ ⇒ error 3D; (b) inclinación desconocida del LED ⇒ DF inalterado, distancia degradada (independencia dual); (c) hover jitter $\sigma_\Delta$.
8. Tabla de latencia (LS µs vs IGWO 9.7 ms) y resultados experimentales preliminares.

---

## 8. Plan experimental (testbed CNC Cambridge)

1. **Inventario y caracterización** (semana 2–3): LED (patrón angular $g_t(\phi)$ vs lambertiano; potencia; modulación/ID; ¿se puede inclinar?), PD (respuesta angular $g_r(\psi)$, FOV, área, responsividad, ¿lente/CPC?), front-end (ancho de banda, $\sigma^2$ vs luz ambiente), gimbal (precisión/repetibilidad de apuntamiento, tiempo de asentamiento, $\theta_{\max}$), CNC (volumen útil, precisión; verdad-terreno).
2. **Calibración mínima:** $C$ (o $g_t(\phi)$ 1D) en un punto/línea; $g_r(\psi)$ una vez.
3. **Protocolo:** grilla 3D (p. ej., paso 10 cm en X,Y, 3–4 alturas) × conjunto de orientaciones (Wang 20°/4; GA; cono LED-céntrico) × $N$ muestras; repetir con luz ambiente variable; con el LED inclinado si es posible; con una pared cercana (NLOS).
4. **Métricas:** error angular de $\hat{\mathbf u}^B$, error 3D (RMSE, APE, CDF$_{90}$), vs $K$, vs orientación, vs SNR; comparación con LS-ratios 2D de Wang en la misma data.
5. **Emulación de yaw desconocido:** rotar la base un ángulo conocido y tratarlo como desconocido para ilustrar la ambigüedad circular (Prop. 1-C1) y la recuperación con heading.

---

## 9. Riesgos y mitigaciones

| Riesgo | Impacto | Mitigación |
|---|---|---|
| Menor sensibilidad angular del PD ($m_r{=}1$) que el TX-steering ($m$) | DEB ≈ $m\times$ peor a igual SNR | tilts grandes (cono LED-céntrico), $K$ mayor, mayor $N$, óptica ($m_r>1$); presentarlo como trade-off cuantificado, no como debilidad |
| Restricción de FOV limita $\theta$ (20° de Wang) | pérdida de información | dropouts tolerados con $K\ge4$; diseño adaptativo LED-céntrico; FOV amplio |
| Patrón del LED no lambertiano | sesgo en $d$ | DF inmune; calibración 1D $g_t(\phi)$; reportar sensibilidad a error de patrón |
| Error de actitud (IMU/gimbal) | error 3D $\approx d\,\sigma_{\rm att}$ | análisis de propagación; en CNC es despreciable; en dron, cuantificar con $\sigma_{\rm att}\sim1^\circ$ |
| NLOS junto a paredes | sesgo (Wang: LS falla) | orientaciones "hacia arriba" reducen captación; simular 1er orden; medir en testbed; posible mitigación por descarte de orientaciones bajas |
| Latencia mecánica | no apto para dinámica rápida | casos de uso estáticos/hover; MEMS/galvo delante del PD; ADR conmutado con la misma geometría |
| Solapamiento percibido con Wang/Shi o con nuestro Broadcast | rechazo por novedad | delimitación explícita (Sec. 5); 3D + teorema + linealidad + independencia del LED + experimento |
| Hardware no listo a tiempo para ICC | paper sólo simulación | versión sim para 02/10; versión con experimento para 30/10 (decisión en Sec. 11) |

---

## 10. Cronograma (hoy: vie 04/09/2026)

| Semana | Fechas | Hitos |
|---|---|---|
| 1 | 04–11/09 | Este plan + chequeos numéricos (hecho); validar con Iman (**reunión próxima semana**: llevar Anexo A); inventario del testbed; esqueleto `CAMBRIDGE/simulations/` reutilizando TCOM |
| 2 | 14–18/09 | Teoría cerrada (prueba formal de Prop. 1, FIM, LS, PEB del cono con acoplamiento $\cos^m\phi$); PEB vs $K/\theta_{\max}$/FOV/SNR/$m$/$m_r$; GA con máscara FOV; heatmaps |
| 3 | 21–25/09 | MC de estimadores; comparación Wang/ATAA; robustez (actitud, LED inclinado, jitter); caracterización hardware |
| 4 | 28/09–02/10 | **Borrador ICC completo (sim)**; decisión: enviar 02/10 o ir a extensión |
| 5–7 | 05–23/10 | Campaña experimental preliminar; integrar resultados; revisión interna (Iman, Bastien, Luc) |
| 8 | 26–30/10 | **Envío ICC (30/10)** |
| 9–12 | nov | Campaña completa; modelo con movimiento (Sec. 3.6); borrador de revista |

---

## 11. Puntos abiertos para discutir

**Contigo (antes de Iman):**
1. ¿Nombre/identidad del sistema? Propuestas: *receiver-steered OWP*, *single-anchor egocentric OWP*, *gimballed-PD OWP*, *synthetic angle-diversity receiver*.
2. ¿Objetivo ICC = sólo simulación (02/10) o simulación + experimento preliminar (30/10)? Mi recomendación: **30/10 con experimento**, dada la crítica recurrente de falta de validación y que Wang sí tiene experimento.
3. ¿Incluir el caso dron sólo como motivación + robustez (ICC) y dejar el modelo acoplado a la revista? (Mi recomendación: sí.)
4. ~~Verificar numéricamente Prop. 1 y la regla $\tan\theta_c=2$~~ → hecho (Sec. 3.8). Queda **cerrar la prueba formal** de Prop. 1 y derivar la PEB del cono con el acoplamiento $\cos^m\phi$ incluido (óptimo exacto 62–70°).
5. ¿Reclamar la analogía "monopulso óptico"? Es atractiva pero hay que revisar literatura de tracking óptico (quadrant detectors, monopulse) para citar bien.
6. **Cómo presentar el gap frente al TX-steering** (RMS-PEB 3.6 cm vs 1.64 cm a $K{=}5$): como trade-off arquitectural (infraestructura pasiva + bearing egocéntrico + multiusuario ilimitado, a cambio de precisión en bordes) y con palancas claras (LED ancho, $K$, óptica del receptor). ¿Incluimos una figura "TX-steered vs RX-steered vs ADR fijo" a igual presupuesto de medidas?

**Con Iman:**
7. Detalles del testbed: LED (tipo, patrón, $\Phi_{1/2}$ — cuanto más ancho mejor para RX-steering, ¿inclinable?), PD (¿lente?), gimbal ($\theta_{\max}$, precisión), volumen del CNC, front-end y adquisición.
8. Su interés en óptica del receptor ($m_r$, FOV) y en ML: ¿ML como corrección residual del modelo con datos del testbed (hybrid physics-ML) o como política adaptativa de orientación? ¿O baseline KNN/ELM como Wang/Liu?
9. Venue: ICC 2027 vs. alternativas (GLOBECOM ya pasó; PIMRC; OFC). Revista objetivo para la extensión.
10. Conexión con su trabajo de orientación aleatoria del receptor (Soltani 2019) y posición+orientación (Arfaoui 2021): ¿un caso de uso "smartphone con orientación oportunista" como sección?

---

## 12. Referencias (formato corto; completar en `.bib`)

- Acuna-Condori *et al.*, "Model-Based Beam-Steered OWP with Single-LED Single-PD for 3D Localization," IEEE TCOM (RV3, 2026); arXiv:2603.29400.
- Acuna-Condori *et al.*, "Broadcast 3D Indoor Positioning with a Single Beam-Steered LED," (conf., 2026).
- Z. Wang, Z. Liang, R. Liu, X. Li, H. Li, "Design and Performance Analysis for Indoor VLP With Single LED and Single-Tilted-Rotatable PD," IEEE TIM, vol. 73, 5502414, 2024. doi:10.1109/TIM.2024.3383461.
- H. Shi, C. Wang, Y. Zhao, "VLP Using a Single LED and a Single Rotatable Photodetector," IEEE PTL 37(18), 2025. doi:10.1109/LPT.2025.3578979.
- H. Shi, C. Wang, Y. Zhao, "Performance Comparison and Improvement for VLP With a Single LED and a Single Rotatable PD," IEEE PTL 38(2), 2026. doi:10.1109/LPT.2025.3623084.
- R. Liu, Z. Liang, K. Yang, W. Li, "ML Based Visible Light Indoor Positioning With Single-LED and Single Rotatable PD," IEEE Photon. J. 14(3), 2022.
- T. Huang *et al.*, "Visible light indoor positioning fashioned with a single tilted optical receiver," ICOCN 2015.
- Q. Li, J.-Y. Wang, T. Huang, Y. Wang, "3D indoor VLP system with a single transmitter and a single tilted receiver," Opt. Eng. 55(10), 106103, 2016. *(sólo abstract leído)*
- L. Qin, B. Niu, B. Li, Y. Du, "Indoor visible light high precision 3D positioning algorithm based on single LED lamp," Optik 207, 163786, 2020.
- S. Ma *et al.*, "Centimeter-Level 3-D Mobile Online VLP System With Single LED Lamp," IEEE IoT-J 11(1), 2024.
- B. Zhou, A. Liu, V. Lau, "Performance limits of visible light-based user position and orientation estimation using RSS under NLOS," IEEE TWC 18(11), 2019.
- S. Shen, S. Li, H. Steendam, "Hybrid position and orientation estimation for visible light systems…," IEEE TWC 21(8), 2022.
- M. D. Soltani, Z. Zeng, I. Tavakkolnia, H. Haas, M. Safari, "Random Receiver Orientation Effect on Channel Gain in LiFi Systems," IEEE WCNC 2019. *(snippet)*
- M. A. Arfaoui *et al.* (incl. I. Tavakkolnia), "Invoking Deep Learning for Joint Estimation of Indoor LiFi User Position and Orientation," IEEE JSAC 39(9), 2021. *(snippet)*
- "Optical Wireless 3-D Positioning and Device Orientation Estimation," IEEE OJCOMS 2024, doi:10.1109/OJCOMS.2024.3423420. *(snippet; verificar autores)*
- "Firefly: Localizing Drones with VLC and Sensor Fusion," DCOSS-IoT 2023. *(snippet)*
- "Tightly coupled VLP/INS integrated navigation by inclination estimation and blockage handling," Satellite Navigation, 2025. *(snippet)*
- "Simultaneous Position and Orientation Estimation in Single Optical IRS-Assisted VL Systems Using Single LED and Single PD," IEEE IoT-J 2025, doi:10.1109/JIOT.2025.3592703. *(snippet)*
- "A Scanning-Based Indoor OWP System with Single VCSEL," arXiv:2601.18740, 2026. *(snippet)*
- J. M. Kahn, J. R. Barry, "Wireless infrared communications," Proc. IEEE 1997. — S. M. Kay, *Fundamentals of Statistical Signal Processing: Estimation Theory*, 1993.

---

## Anexo A — One-page brief for the meeting with Iman (English)

**Working title.** *Receiver-Steered Single-Anchor Optical Wireless Positioning: 3D Localization with a Single Fixed LED and a Single Reorientable Photodiode.*

**Problem.** A single fixed LED (any luminaire/IR beacon with an ID) at a known position; a single PD on a 2-DOF gimbal whose normal $\mathbf n_j^B$ is commanded in the receiver body frame through $K$ orientations; receiver attitude $\mathbf R$ known (IMU / robot kinematics / CNC). Estimate the 3D position $\mathbf r$ from the $K$ RSS means. Testbed: Cambridge CNC (X,Y,Z) + rotate/tilt end-effector, LED at the ceiling centre.

**Why it is not just the mirror image of our TX-steered work (TCOM'26 / Broadcast'26).**
1. *Linearity.* The PD response is $\cos\psi$ (order 1), so $\mu_j=\mathbf n_j^B\!\cdot\!\mathbf w$ with $\mathbf w=\eta_R\mathbf u^B$: direction and amplitude follow from an ordinary linear LS (BLUE/MLE, attains the CRLB) — no ratios, no reference orientation, microsecond latency. TX steering is nonlinear ($\cos^m$).
2. *Egocentric bearing and an attitude theorem.* A static scan carries exactly 3 DOF of information $(\mathbf u^B,\eta_R)$. Hence full attitude is **necessary** for 3D positioning and yaw is **unobservable** from a static scan even with a tilted LED; with an axisymmetric anchor it is unobservable even under motion. This turns the "heading must be known" caveat of Wang *et al.* (TIM'24) into a fundamental result and motivates asymmetric anchors + motion for joint position–heading estimation (journal).
3. *LED-independence.* Direction finding is independent of the LED orientation, Lambertian order, power and actual pattern (only the distance stage needs a 1-D calibrated pattern) — the dual of our $\mathbf n_r$-independence, and a direct answer to the non-Lambertian-pattern issue reported experimentally by Wang *et al.*

**Gaps in the literature.** All single-LED/single-rotatable-PD works are 2D with known height (Wang'24, Shi'25, Shi'26, Liu'22); orientation sets are ad hoc (20° tilt, 4×90°); estimators are iterative (LS-IGWO, 9.7 ms) or fingerprints; testbeds are 50×50×30 cm with manual rotation; no observability analysis; no mobile-receiver formulation.

**Contributions (ICC'27 target, deadline 2 Oct / ext. 30 Oct).** (i) 3D formulation + observability theorem + duality; (ii) DEB/PEB and GA design of the orientation set under FOV/tilt constraints, plus a closed-form design rule (LED-centred cone with $\tan\theta_c=2$, an optical amplitude-comparison "monopulse"; ≈2.3× lower PEB than the 20° design); (iii) closed-form LS/WLS (SDSN) and NLS estimators; (iv) first 3D experimental validation on the CNC testbed. Journal extension: drone case (reorientation coupled with displacement; IMU fusion; calibration-free ranging via translational diversity; joint heading estimation with asymmetric anchors); receiver optics ($m_r$, FOV) trade-off; hybrid physics–ML residual correction.

**Preliminary numbers (numerical checks, 4 Sep; TCOM parameters, 3×3×1.2 m testbed, 1792 points, bare PD, vertical LED with $\Phi_{1/2}=45^\circ$).** The FIM over $(x,y,z,\text{yaw})$ is singular for any $K$ and for a tilted LED (theorem confirmed). The linear LS attains the CRLB (Cov/CRLB = 0.998) and the plug-in 3D estimate matches the PEB (ratio 0.996). RMS-PEB: Wang-type design (20° cone, $K{=}4$) 8.1 cm; LED-centred cone 63° $K{=}4/5/9$: 4.0/3.6/2.7 cm; with a wider LED ($\Phi_{1/2}=60^\circ$) 2.6 cm at $K{=}5$. For reference, our TX-steered bounds at $K{=}5$ are 1.64 cm (cooperative) and 2.49 cm (broadcast): **receiver steering trades edge accuracy (the fixed LED does not point at the user, and tilting the PD costs $\cos\psi$) for a fully passive infrastructure, an egocentric bearing and unlimited users.** Levers: wide-beam anchor, larger $K$, receiver optics, SNR.

**Use cases.** Indoor drones (docking/precision landing on a single IR beacon; warehouse inventory), AGVs with pan-tilt heads, robot arms/tool tracking, IMU-tagged handheld/AR devices (opportunistic orientation diversity), receiver-side LiFi alignment (ISAC), single-lamp environments (corridors, tunnels, cabins).

**Questions for you.** Testbed details (LED type/pattern/tiltable?, PD optics, gimbal range/accuracy, CNC volume, front-end); your preference on the ML component; venue.

---

## Anexo B — Borrador de título / abstract / contribuciones (English, para reciclar en el paper)

**Title candidates.**
- Receiver-Steered Single-Anchor Optical Wireless Positioning: 3D Localization with a Single Reorientable Photodiode
- Egocentric Direction Finding and 3D Positioning with a Single LED and a Single Gimballed Photodiode
- Synthetic Angle-Diversity Reception for Single-LED 3D Optical Wireless Positioning

**Abstract (draft).** Single-LED optical wireless positioning (OWP) with a single rotatable photodiode (PD) has so far been restricted to two-dimensional estimation with fixed tilt, heuristically chosen rotation angles and iterative solvers. This paper formulates the three-dimensional (3D) problem for a single fixed optical anchor and a single actively reorientable PD whose normal is steered through $K$ known orientations in the receiver body frame. We show that the received-signal-strength model is linear in a scaled bearing vector, which yields a closed-form, statistically efficient least-squares estimator of the anchor direction and of a common amplitude that is independent of the LED orientation, Lambertian order and power. We prove that a static scan carries exactly three degrees of freedom of information, so that full receiver attitude knowledge is necessary and heading is unobservable regardless of the number of orientations, and we characterise when motion and anchor asymmetry restore observability. We derive direction and position error bounds, optimise the orientation set under field-of-view and tilt constraints, and obtain a closed-form design rule — an anchor-centred cone with $\tan\theta_c=2$ — that outperforms the conventional 20° tilt design by a factor of about 2.3 in the position error bound. Monte Carlo simulations and experiments on a 3-axis CNC testbed with a motorised tilt–rotate PD mount demonstrate centimetre-level 3D accuracy with microsecond-level inference. *(cifras a completar)*
