# Análisis de Narrativa: Opción A vs. C2

## La pregunta central del usuario

> "En Opción A, si n_r se asume conocido para DR, entonces la propiedad n_r-agnostic del DF pierde impacto."
> "En Opción C2, ¿cómo manejar en la Intro que el Rx se rota? ¿Debo mencionar beam steering del Rx?"

---

## 1. La tensión narrativa de Opción A

### El problema que identificas es real

Si dices "n_r es conocido" para todo el sistema:
- El reviewer lee: "Asumen n_r = [0,0,1]^T conocido"
- Luego lee: "GLS/WLS no dependen de n_r"
- Y piensa: **"¿Y qué? Ya lo conocen de todos modos. ¿Por qué es eso una contribución?"**

La propiedad n_r-agnostic se convierte en un resultado teórico elegante pero sin impacto práctico inmediato, porque el sistema ya asume que n_r está disponible.

### La contra-narrativa posible (robustez)

Podrías argumentar: "En la práctica n_r no es perfectamente conocido (el usuario inclina el teléfono). Que DF no dependa de n_r lo hace robusto a inclinaciones."

**Pero esto es un argumento débil en este contexto:**
- Si n_r es "conocido" para DR pero "no se usa" en DF, el reviewer puede preguntar: "¿El DR es robusto a errores en n_r? Si no, el sistema completo no es robusto."
- El argumento de robustez se fragmenta: DF es robusto, pero DR no → el RMSE 3D final SÍ depende de n_r → ¿dónde queda la ventaja?

### Veredicto sobre Opción A

La narrativa de Opción A es técnicamente limpia pero **narrativamente contradictoria**:
- Dice: "n_r no importa para DF" (contribución)
- Pero: "n_r sí se usa para DR" (misma arquitectura)
- Resultado: el lector se pregunta **por qué se destaca algo que el propio sistema no necesita destacar**

---

## 2. La narrativa de Opción C2

### El concepto clave: separación funcional clara

La historia del paper se convierte en:

> "Proponemos un sistema de dos etapas con propiedades fundamentalmente diferentes:
> **Etapa 1 (Direction Finding)**: Opera con el PD en cualquier orientación fija, incluso desconocida. Esto es posible porque la ratio de potencias cancela matemáticamente la dependencia en n_r.
> **Etapa 2 (Distance Recovery)**: Un único alineamiento cooperativo Tx–Rx maximiza el SNR para estimar la distancia."

Esta separación crea un **contraste narrativo fuerte**:
- DF: pasivo, sin control del Rx, funciona con cualquier tilt → ideal para escenarios reales
- DR: activo, un único alineamiento → precio controlado por la ganancia en SNR

### ¿Se necesita mencionar "beam steering del Rx" en la Introducción?

**NO.** No debes llamarlo "beam steering del Rx" porque:
1. Beam steering implica un mecanismo sofisticado (MEMS, OPA, liquid crystal)
2. Lo que hace el Rx es una **única reorientación** — no un steering dinámico
3. Varios sistemas en Table I ya hacen esto: [Liu2022], [Wang2024], [Shi2025] usan "rotatable PD"

**Cómo presentarlo en la Intro:**

> "The proposed approach operates in two stages. First, the LED is steered through K known orientations while the PD remains at a fixed, arbitrary pose; the resulting power measurements are processed by the proposed closed-form estimators to recover the LED-to-PD direction. We formally prove that this direction estimate is independent of the receiver orientation. Second, a single cooperative measurement with both the LED and PD aligned along the estimated direction yields the LED-to-PD distance, completing the 3D position. Unlike approaches requiring continuous PD rotation [Liu2022, Wang2024, Shi2025] or multi-PD arrays [Qin2020, Li2024], our system requires the PD to remain static during the K direction-finding measurements and performs only a single reorientation for distance recovery."

**Esto es potente porque:**
- Contrasta con la Table I: otros sistemas necesitan rotación continua o arrays; el tuyo necesita UNA sola reorientación
- El DF no necesita nada del Rx → más simple que todos los competidores
- El DR es un paso cooperativo estándar en comunicaciones ópticas

### ¿Cómo evitar que el reviewer diga "¿por qué no usaste n_r conocido en DF?"

**Esta pregunta no tiene sentido matemáticamente, y eso es tu ventaja.**

La cancelación de n_r en las ratios β_i no es una decisión de diseño — es una **consecuencia matemática** de tomar ratios de potencia Lambertiana. No "elegiste" no usar n_r; el modelo lo elimina automáticamente.

> "The n_r-independence of the ratio-based direction estimators is not a design choice but a fundamental mathematical property: the receiver-orientation factor cos ψ appears identically in every received power μ_i and cancels exactly in the ratio β_i = (μ_i/μ_1)^{1/m}. This property holds regardless of whether n_r is known, unknown, or time-varying."

**Esto hace que la propiedad sea más fuerte que en Opción A:**
- No estás diciendo "decidimos no usar n_r" (lo que implicaría que podrías usarlo)
- Estás diciendo "el modelo lo elimina — es una propiedad intrínseca del método"
- Esto justifica por qué DR sí lo usa: DR no está basado en ratios, sino en potencia absoluta

---

## 3. Respuestas sugeridas al Reviewer — Opción C2

### Comment #3:
> "The description of the Distance Recovery stage is confusing, particularly with respect to beam-forming symmetry. The discussion implies n_r = −n̂_d, contradicting the Abstract."

**Respuesta:**

> We thank the reviewer for identifying this inconsistency. In the revised manuscript, we have made the following clarifications:
>
> 1. **We have rewritten the Abstract and Introduction** to clearly distinguish the two stages. The direction-finding stage—which constitutes the core algorithmic contribution—operates with the PD at any fixed orientation and does not require receiver rotation. The distance-recovery stage performs a single cooperative alignment of both the LED and PD along the estimated direction to maximize the received SNR for ranging.
>
> 2. **We have removed the term "beam-forming symmetry"** and replaced it with an explicit description: "the LED is steered to n̂_d and the PD is reoriented to −n̂_d for a single ranging measurement."
>
> 3. **We have added a formal proof (new Section VI-A)** showing that the power-ratio-based direction estimators (GLS/WLS) are mathematically independent of the receiver orientation n_r. This property holds because cos ψ cancels exactly in the ratio β_i = (μ_i/μ_1)^{1/m}. This is a fundamental property of the Lambertian power model under our ratio-based linearization.
>
> 4. **We emphasize** that direction finding alone provides the complete transmitter-to-receiver direction vector n̂_d, which is directly useful for beam-management, tracking, and handover applications. The distance-recovery step extends this to full 3D positioning.
>
> We note that the single PD reorientation required for distance recovery is substantially simpler than the continuous rotation or multi-PD arrays employed by prior single-LED systems [Liu2022, Wang2024, Shi2025, Qin2020]. During the K direction-finding measurements, the PD remains completely passive.

### Comment #5:
> "Table I states Rx orientation is 'arbitrary,' but Section II-A assumes n_r = [0,0,1]^T. If arbitrary, it becomes 6-DoF."

**Respuesta:**

> We thank the reviewer for this important remark. The original Table I was indeed misleading. In the revised manuscript:
>
> 1. **Table I** now distinguishes between direction finding ("Arbitrary") and full 3D positioning ("Controlled"). A footnote clarifies: "Direction estimation is provably independent of the receiver orientation (Proposition 1); distance recovery requires a known or controlled n_r."
>
> 2. **New Proposition 1 (Section VI-A)** formally proves that the GLS/WLS direction estimators do not depend on n_r. Specifically, β_i = (μ_i/μ_1)^{1/m} = cos(ϕ_i)/cos(ϕ_1), which involves only the LED orientation vectors and the displacement direction—the receiver orientation cancels identically. Therefore, direction finding is genuinely "arbitrary" with respect to n_r and does not require its knowledge, avoiding the 6-DoF problem raised by the reviewer.
>
> 3. **The NL estimator**, by contrast, does require known n_r (through the term L(x,y,z) = α x + β y + γ(z−H) in Eq. (XX)). We have added an explicit remark in Section V clarifying this distinction.
>
> 4. **For distance recovery**, n_r must be known or controlled (as in the beam-aligned measurement). This assumption is consistent with [Chassagne2025], which also reports "Arbitrary" in Table I for its direction-finding-based approach but relies on known geometry for ranging.

---

## 4. Respuestas sugeridas al Reviewer — Opción A

### Comment #3:

> We thank the reviewer for this observation. We have **reformulated the distance-recovery stage** to eliminate the need for receiver rotation entirely. In the revised formulation:
>
> - The LED is steered to n̂_d (as before)
> - **The PD remains at its fixed orientation n_r** (no reorientation)
> - The incidence cosine cos ψ = n_r · (−n̂_d) is computed from the estimated direction and the known receiver normal
> - The distance estimate becomes d̂ = √(C · |n_r · n̂_d| / P̄_{r,K+1})
>
> This eliminates the "beam-forming symmetry" assumption and the claim "without receiver rotation" is now fully supported. The cost is a slightly reduced SNR for the ranging measurement (cos ψ < 1 in general), which we quantify in the revised Section VII.

### Comment #5:

> In the revised system, the receiver orientation n_r is assumed **known but fixed** throughout all measurements (direction finding and distance recovery). We have updated Table I to "Fixed (known)."
>
> We note that the GLS/WLS direction estimators are mathematically independent of n_r (proven in new Section VI-A). This means that even if n_r is imperfectly known (e.g., due to user handling), the direction estimate remains accurate. The distance estimate is affected only through cos ψ, which varies smoothly with n_r errors. We have added a robustness analysis in Section VII-A demonstrating that direction-finding accuracy is maintained under random PD tilts.

---

## 5. Evaluación honesta: ¿Cuál narrativa es más sólida?

### Opción C2 gana en narrativa por estas razones:

**1. El contraste DF/DR es más dramático**
- C2: "DF funciona con n_r desconocido. DR requiere una acción. La diferencia destaca la contribución."
- A: "n_r es conocido para todo. DF no lo usa, pero tampoco lo necesita. Menos contraste."

**2. La propiedad n_r-agnostic brilla más**
- C2: "A pesar de que el sistema puede controlar n_r (lo demuestra en DR), DF no lo necesita — esto es una propiedad matemática fundamental, no una simplificación."
- A: "Asumimos n_r conocido. DF no lo usa. OK, ¿y?" → Menos impactante.

**3. Los resultados existentes se mantienen**
- C2: Los PEB, RMSE, CDF son exactamente los mismos → la discusión del reviewer se centra en claridad, no en resultados
- A: Los resultados cambian → el reviewer puede cuestionar diferencias

**4. La respuesta al reviewer es más natural**
- C2: "Usted señaló una contradicción. La hemos corregido siendo transparentes." → El reviewer se siente escuchado
- A: "Usted señaló una contradicción. Hemos cambiado el sistema." → El reviewer puede pensar "¿el sistema original era defectuoso?"

**5. La Introducción fluye mejor**
- C2: "Unlike [Liu2022, Wang2024, Shi2025] that require continuous PD rotation, our DF operates with a completely passive PD. Only a single reorientation is needed for ranging."
- A: "Our system operates with a fixed, known PD orientation throughout." → Menos diferenciación con la competencia.

### Opción A gana en:
- Limpieza teórica (sin contradicciones residuales)
- El claim "without Rx rotation" se mantiene

### Pero el claim "without Rx rotation" no es tan importante como parece:
- El reviewer no dijo "quiero que el sistema no necesite rotación"
- El reviewer dijo "la claim contradice el modelo" → la solución es **corregir la claim**, no necesariamente cambiar el modelo

---

## 6. El argumento definitivo a favor de C2

Imagina que el reviewer lee tu revisión:

**Con Opción A:**
> "Hmm, cambiaron el distance recovery. Los resultados son diferentes a la versión anterior. El PEB empeoró un poco. ¿Es este el mismo sistema? La rederivación del gradiente de μ_{K+1}... déjame verificar... ¿Está bien este término? Tengo nuevas dudas."

**Con Opción C2:**
> "OK, corrigieron el Abstract. Ahora dicen explícitamente que DR requiere una reorientación. Bien, eso es honesto. Y mira, probaron matemáticamente que DF es n_r-independiente. Eso es un resultado interesante. Los números son los mismos. La CDF de error angular es nueva. La robustez a tilt es convincente. El paper es más claro ahora."

**C2 genera menos preguntas nuevas y más satisfacción.**

---

## 7. Recomendación revisada

**Opción C2 es la elección correcta para esta revisión**, por las razones que tu asesor intuyó (mover menos cosas) y por las razones narrativas analizadas aquí:

1. La contribución n_r-agnostic de DF es **más impactante** cuando DR sí usa n_r (contraste)
2. Los resultados existentes se conservan (menos riesgo)
3. La respuesta al reviewer es directa: "corregimos la claim, no el sistema"
4. La Intro no necesita mencionar "beam steering del Rx" — solo "a single cooperative reorientation"
5. Se diferencia de la competencia: "K mediciones con PD pasivo + 1 sola reorientación" < "rotación continua"

### La clave del éxito de C2 está en:
- **Abstract**: reescribir SIN "without receiver rotation". En su lugar: "direction finding independent of receiver orientation"
- **Intro**: presentar DR como un paso cooperativo simple, comparar con los sistemas que requieren rotación continua
- **Nueva Sección VI-A**: prueba formal de la cancelación de n_r
- **Nuevo resultado VII-A**: CDF angular + robustez a tilt (esto es lo que el reviewer verá como "new contribution")
- **Table I**: "Arbitrary (DF)" con nota al pie

### Esquema del Abstract revisado (Opción C2):

> "This paper introduces a single beam-steered LED, single-PD OWP architecture for 3D indoor localization. The core idea is to steer the transmitter through K orientations and exploit RSS variations to estimate the LED-to-PD direction. We prove that the proposed ratio-based direction estimators (GLS/WLS) are mathematically independent of the receiver orientation, enabling robust direction finding without receiver pose knowledge or control. A composite CRLB/PEB analysis characterizes identifiability and guides GA-based orientation-set design. A single beam-aligned ranging measurement then completes the 3D position. Simulations demonstrate centimeter-level 3D accuracy and sub-degree direction error across arbitrary PD tilts."
