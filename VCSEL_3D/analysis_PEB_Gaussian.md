# Analysis: PEB for Gaussian VCSEL Beam-Steered OWP

## 1. Channel Model

### Received power at orientation i

For a Gaussian VCSEL with divergence θ_div, the noise-free received power is:

```
μ_i(r) = [C / (θ_div² · d²)] · exp(-2(φ_i/θ_div)²) · cos(ψ)
```

where:
- C = P_t · A_det / (2π)  — radiometric constant
- d = ||r - t||  — TX-RX distance
- φ_i = arccos(n_{t,i} · n_d)  — beam angular offset for orientation i
- cos(ψ) = -n_r · n_d  — incidence cosine (receiver)
- θ_div is in radians throughout

### Compact form

Define:
- η = C · cos(ψ) / (θ_div² · d²)  — amplitude parameter
- R_G(φ_i) = exp(-2(φ_i/θ_div)²)  — normalized Gaussian pattern

Then:
```
μ_i = η · R_G(φ_i)
```

This has the **same factorized structure** as the Lambertian case (μ_i = η · Q_i^m), so the FIM methodology applies directly.

---

## 2. Gradient Derivation

### Goal

Compute ∇_r μ_i(r) — the gradient of μ_i with respect to receiver position r = [x, y, z]^T.

### Chain rule decomposition

μ_i depends on r through three intermediate quantities:
1. d(r) = ||r - t||
2. n_d(r) = (r - t)/d
3. cos ψ(r) = -n_r · n_d

And φ_i(r) = arccos(n_{t,i} · n_d(r)).

Write μ_i explicitly:
```
μ_i = C / (θ_div² · d²) · exp(-2φ_i²/θ_div²) · cos(ψ)
```

### Step 1: Gradient of d and n_d

Standard results (same as TCOM):
```
∇_r d = n_d
∇_r n_d = (I₃ - n_d n_d^T) / d
```

### Step 2: Gradient of cos(φ_i) = n_{t,i} · n_d

```
∇_r [n_{t,i} · n_d] = (I₃ - n_d n_d^T) · n_{t,i} / d
```

Let Q_i = cos(φ_i) = n_{t,i} · n_d. Then:
```
∇_r Q_i = (n_{t,i} - Q_i · n_d) / d
```

### Step 3: Gradient of φ_i = arccos(Q_i)

```
∇_r φ_i = -1/sin(φ_i) · ∇_r Q_i = -(n_{t,i} - Q_i · n_d) / (d · sin(φ_i))
```

### Step 4: Gradient of R_G(φ_i) = exp(-2φ_i²/θ_div²)

```
∂R_G/∂φ_i = -4φ_i/θ_div² · R_G(φ_i)

∇_r R_G(φ_i) = (∂R_G/∂φ_i) · ∇_r φ_i
             = [-4φ_i/θ_div² · R_G(φ_i)] · [-(n_{t,i} - Q_i·n_d) / (d·sin(φ_i))]
             = [4φ_i / (θ_div² · d · sin(φ_i))] · R_G(φ_i) · (n_{t,i} - Q_i·n_d)
```

### Step 5: Gradient of η = C·cos(ψ)/(θ_div²·d²)

```
∇_r η = C/(θ_div²) · ∇_r [cos(ψ)/d²]
       = C/(θ_div²) · [(∇_r cos(ψ))/d² + cos(ψ)·∇_r(1/d²)]
```

Where:
```
∇_r cos(ψ) = ∇_r(-n_r · n_d) = -n_r · (I₃ - n_d n_d^T)/d = -(n_r - cos(ψ)·(-n_d))/ d
            Wait, let's be careful. cos(ψ) = -n_r · n_d, so:
∇_r cos(ψ) = -n_r · ∇_r n_d = -(I₃ - n_d n_d^T) · n_r / d
            = -(n_r + cos(ψ)·n_d) / d    [since -n_r·n_d = cos(ψ) → n_r projected = -cos(ψ)n_d + perp]

∇_r(1/d²) = -2/(d³) · n_d
```

So:
```
∇_r η = C/(θ_div² · d²) · [-(n_r + cos(ψ)·n_d)/d - 2cos(ψ)/d · n_d]
       = η · [-(n_r + cos(ψ)·n_d)/(d·cos(ψ)) - 2n_d/d]
       = -(η/d) · [n_r/cos(ψ) + n_d + 2n_d]
       = -(η/d) · [n_r/cos(ψ) + 3n_d]
```

Wait, let me redo this more carefully:
```
∇_r η = (C/(θ_div²)) · [d⁻² · ∇_r cos(ψ) + cos(ψ) · ∇_r(d⁻²)]
       = (C/(θ_div²)) · [d⁻² · (-(n_r + cos(ψ)n_d)/d) + cos(ψ) · (-2d⁻³ n_d)]
       = (C/(θ_div² d³)) · [-(n_r + cos(ψ)n_d) - 2cos(ψ)n_d]
       = (C cos(ψ)/(θ_div² d³)) · [-(n_r/cos(ψ)) - n_d - 2n_d]
       = (η/d) · [-(n_r/cos(ψ)) - 3n_d]
```

### Step 6: Full gradient via product rule

```
∇_r μ_i = (∇_r η) · R_G(φ_i) + η · ∇_r R_G(φ_i)
```

Substituting:
```
∇_r μ_i = (η/d) · R_G(φ_i) · {
    -(n_r/cos(ψ)) - 3n_d
    + [4φ_i / (θ_div² · sin(φ_i))] · (n_{t,i} - Q_i·n_d)
}
```

Or equivalently, factoring out μ_i = η · R_G(φ_i):
```
∇_r μ_i = (μ_i / d) · {
    [4φ_i / (θ_div² · sin(φ_i))] · (n_{t,i} - Q_i·n_d)
    - n_r/cos(ψ)
    - 3n_d
}
```

### Final compact form

```
∇_r μ_i = (μ_i / d) · [α_i · (n_{t,i} - Q_i·n_d) - n_r/cos(ψ) - 3·n_d]
```

where:
```
α_i = 4φ_i / (θ_div² · sin(φ_i))
```

**Note:** When φ_i → 0, the ratio φ_i/sin(φ_i) → 1, so α_i → 4/θ_div² (finite, well-defined).

---

## 3. Comparison with Lambertian Gradient

For reference, the Lambertian gradient (TCOM Eq. 22) is:
```
∇_r μ_i^{LED} = (C_LED/d³) · [m·cos^{m-1}(φ_i)·cos(ψ)·n_{t,i}
                                - cos^m(φ_i)·n_r
                                - (m+3)·cos^m(φ_i)·cos(ψ)·n_d]
```

The Gaussian gradient has a similar three-term structure:
- Term 1: along n_{t,i} (angular discrimination) — weighted by α_i
- Term 2: along n_r (incidence coupling) — same structure
- Term 3: along n_d (radial/distance) — coefficient 3 instead of (m+3)

Key difference: the angular sensitivity term has α_i = 4φ_i/(θ_div²·sin φ_i) which is **inversely proportional to θ_div²**. Smaller divergence → larger gradient → more Fisher information per measurement (but fewer measurements contribute due to coverage).

---

## 4. FIM and PEB

The Fisher Information Matrix:
```
I_B(r) = (N/σ²) · Σᵢ [∇_r μ_i] · [∇_r μ_i]^T
```

summed only over orientations i where:
1. Q_i = n_{t,i} · n_d > 0 (geometrically visible)
2. R_G(φ_i) > threshold (significant signal — e.g., R_G > 0.01)
3. cos(ψ) > 0 and ψ ≤ Ψ_FOV

The PEB:
```
PEB(r) = √(tr(I_B⁻¹(r)))     if I_B is full rank
        = ∞                     otherwise (outage)
```

---

## 5. Special Case: φ_i = 0 (boresight)

When the beam points exactly at the receiver (φ_i = 0):
- R_G(0) = 1 (maximum power)
- α_i = 4/θ_div² (using L'Hôpital: lim φ→0 φ/sin(φ) = 1)
- The gradient becomes: ∇_r μ_i = (μ_i/d)·[4/θ_div²·(n_{t,i} - n_d) - n_r/cos(ψ) - 3n_d]
- But at boresight: n_{t,i} = n_d, so (n_{t,i} - n_d) = 0
- Therefore: ∇_r μ_i = (μ_i/d)·[-n_r/cos(ψ) - 3n_d]

This means **boresight measurements provide only radial + incidence information, not angular discrimination**. Angular information comes from off-axis measurements (φ_i > 0).

---

## 6. Implementation Notes

1. Use φ_i in **radians** throughout (θ_div also in radians)
2. Handle φ_i = 0 via limit: set α_i = 4/θ_div² when φ_i < ε (e.g., ε = 1e-8 rad)
3. Skip orientations where R_G(φ_i) < threshold (e.g., exp(-8) ≈ 0.00034) to avoid numerical noise
4. The 1/θ_div² in the power model means smaller beams deliver higher boresight intensity (for same P_t)
5. Validate gradient numerically with finite differences before trusting the FIM
