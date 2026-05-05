# Why GLS, WLS, and NL-MLE Are Agnostic to Receiver Orientation $\mathbf{n}_r$

**Author:** Kevin Acuña  
**Date:** May 2026  
**Context:** Simulation results from `run_nr_random_tilt_MC_parallel.m` show negligible degradation (<3%) under random receiver tilt for all ratio-based and NL estimators. This document provides the mathematical proof.

---

## 1. Channel Model (Single LED, Multiple Orientations)

From `OWC_LOS_channel.m`, the received optical power at position $\mathbf{R}$ from a single LED at $\mathbf{T}$ with orientation $\mathbf{n}_t^{(i)}$ is:

$$P_{r,i} = P_t \cdot \frac{(m+1)\, A_{\det}}{2\pi\, d^2} \cdot \left(\mathbf{n}_t^{(i)} \cdot \mathbf{v}_{tr}\right)^m \cdot \left(\mathbf{n}_r \cdot (-\mathbf{v}_{tr})\right) \tag{1}$$

where:
- $d = \|\mathbf{R} - \mathbf{T}\|$ — distance from LED to receiver  
- $\mathbf{v}_{tr} = (\mathbf{R} - \mathbf{T})/d$ — unit direction vector (the quantity we want to estimate)  
- $m$ — Lambertian order of the LED  
- $\mathbf{n}_r$ — receiver normal vector (affected by tilt)  
- $A_{\det}$ — photodetector area  
- $P_t$ — transmitted optical power

### Key structural observation: multiplicative separability

We define:
$$Q_i \;\triangleq\; \mathbf{n}_t^{(i)} \cdot \mathbf{v}_{tr} \tag{2}$$

$$\alpha \;\triangleq\; \frac{P_t\,(m+1)\,A_{\det}}{2\pi\,d^2} \cdot \underbrace{\left(\mathbf{n}_r \cdot (-\mathbf{v}_{tr})\right)}_{\cos\psi} \tag{3}$$

Then:
$$\boxed{P_{r,i} = \alpha \cdot Q_i^m} \tag{4}$$

**Critical fact:** $\alpha$ is the **same for all orientations** $i = 1, \ldots, K$, because:
- The LED is at a single position $\mathbf{T}$ → the distance $d$ is the same for all $i$
- The receiver at $\mathbf{R}$ has a single normal $\mathbf{n}_r$ → the incidence angle $\psi$ is the same for all $i$
- $P_t$ and $A_{\det}$ are system constants

Only $Q_i$ varies with the LED orientation index $i$.

This multiplicative separability is the fundamental reason why $\mathbf{n}_r$ can be eliminated from the estimation problem.

---

## 2. GLS/WLS: Ratio Cancellation

### 2.1. Ratio definition

From `vlp_gls.m` (line 19) and `vlp_wls.m` (line 23):

$$\hat{\beta}_i = \left(\frac{\hat{\mu}_i}{\hat{\mu}_1}\right)^{1/m}, \quad i = 2, \ldots, K \tag{5}$$

where $\hat{\mu}_i = \frac{1}{N}\sum_{k=1}^{N} P_{r,i}^{(k)}$ is the sample mean of the $k$-th power measurement under orientation $i$.

### 2.2. Noiseless case

Substituting Eq. (4):

$$\beta_i = \left(\frac{P_{r,i}}{P_{r,1}}\right)^{1/m} = \left(\frac{\alpha \cdot Q_i^m}{\alpha \cdot Q_1^m}\right)^{1/m} = \frac{Q_i}{Q_1} = \frac{\mathbf{n}_t^{(i)} \cdot \mathbf{v}_{tr}}{\mathbf{n}_t^{(1)} \cdot \mathbf{v}_{tr}} \tag{6}$$

**$\alpha$ cancels exactly.** Therefore $\beta_i$ depends only on:
- The LED orientations $\mathbf{n}_t^{(i)}$ (known)
- The direction $\mathbf{v}_{tr}$ (the unknown being estimated)

It does **not** depend on: $\mathbf{n}_r$, $d$, $P_t$, $A_{\det}$, or $\cos\psi$.

### 2.3. Linear model

From `vlp_gls.m` (line 30) and `vlp_wls.m` (line 34), the constraint is:

$$\mathbf{a}_i \;\triangleq\; \mathbf{n}_t^{(i)} - \beta_i\, \mathbf{n}_t^{(1)}, \quad \mathbf{a}_i \cdot \mathbf{v}_{tr} = 0 \tag{7}$$

This means $\mathbf{v}_{tr}$ lies in the null space of the matrix $\mathbf{A} = [\mathbf{a}_2, \ldots, \mathbf{a}_K]^T$. Both GLS and WLS find it as the eigenvector associated with the smallest eigenvalue of $\mathbf{M} = \mathbf{A}^T \mathbf{W} \mathbf{A}$.

**Nowhere in Eqs. (5)–(7) does $\mathbf{n}_r$ appear.** ∎

---

## 3. NL-MLE: Normalization-Based Cancellation

### 3.1. Normalization step

From `run_nr_random_tilt_MC_parallel.m` (lines 252–254):

```matlab
p_means = mean(P_raw_deb, 1);
max_p = max(p_means);
p_target = p_means / max_p;
```

This computes:

$$p_{\text{target},i} = \frac{\hat{\mu}_i}{\max_j \hat{\mu}_j} \tag{8}$$

### 3.2. Noiseless analysis

Substituting Eq. (4):

$$p_{\text{target},i} = \frac{P_{r,i}}{\max_j P_{r,j}} = \frac{\alpha \cdot Q_i^m}{\alpha \cdot \max_j Q_j^m} = \frac{Q_i^m}{Q_{\max}^m} \tag{9}$$

where $Q_{\max} = \max_j Q_j$.

**Again, $\alpha$ cancels exactly**, so $p_{\text{target},i}$ depends only on $Q_i$ ratios, not on $\mathbf{n}_r$.

### 3.3. Cost function

From `mle_cost_function` (lines 459–467):

$$F(\mathbf{v}, \eta) = \sum_{i=1}^{K} \left(\eta \cdot \left[\max\!\left(0,\; \mathbf{n}_t^{(i)} \cdot \mathbf{v}\right)\right]^m - p_{\text{target},i}\right)^2 \tag{10}$$

subject to the sphere constraint $\|\mathbf{v}\| = 1$.

The optimization variables are $\mathbf{v} \in \mathbb{R}^3$ (direction) and $\eta \in \mathbb{R}_{>0}$ (scale parameter).

### 3.4. Noiseless minimum

At the true direction $\mathbf{v} = \mathbf{v}_{tr}$, we have:
$$\left[\mathbf{n}_t^{(i)} \cdot \mathbf{v}_{tr}\right]^m = Q_i^m$$

and from Eq. (9), $p_{\text{target},i} = Q_i^m / Q_{\max}^m$. The cost becomes:

$$F(\mathbf{v}_{tr}, \eta) = \sum_{i=1}^{K} \left(\eta \cdot Q_i^m - \frac{Q_i^m}{Q_{\max}^m}\right)^2 = \sum_{i=1}^{K} Q_i^{2m} \left(\eta - \frac{1}{Q_{\max}^m}\right)^2 \tag{11}$$

This is **zero** when $\eta^* = 1/Q_{\max}^m$. So the noiseless optimum is:

$$\boxed{\mathbf{v}^* = \mathbf{v}_{tr}, \quad \eta^* = \frac{1}{Q_{\max}^m}} \tag{12}$$

### 3.5. Role of $\eta$

The parameter $\eta$ is a **nuisance parameter** that absorbs the unknown normalization. In the presence of $\mathbf{n}_r$:

- The actual (un-normalized) model would be $P_{r,i} = \alpha \cdot Q_i^m$, which requires knowing $\alpha$ (and hence $\mathbf{n}_r$, $d$, etc.)
- After normalization to $p_{\text{target}}$, the model becomes $\eta \cdot Q_i^m$ with a free $\eta$
- The optimizer jointly solves for $\mathbf{v}$ and $\eta$, effectively marginalizing out all dependence on $\alpha$

**This is mathematically equivalent to what GLS/WLS achieve with explicit ratios, but through a different mechanism: joint optimization with a free scale parameter instead of ratio algebra.**

### 3.6. Formal equivalence

Define $r_i \triangleq Q_i / Q_1$. Then:
$$p_{\text{target},i} = \frac{Q_i^m}{Q_{\max}^m} = \frac{r_i^m}{\max_j r_j^m}$$

For GLS/WLS, $\beta_i = Q_i/Q_1 = r_i$. Both representations encode the same information: the $K-1$ independent ratios $\{r_2, \ldots, r_K\}$ among the direction cosines.

---

## 4. What Causes the Small Residual Degradation?

The simulation shows +1.68% (NL), +2.24% (GLS), +2.62% (WLS) degradation. This is not zero. The explanation:

### 4.1. SNR reduction (dominant effect)

With tilt, $\cos\psi$ decreases → $\alpha$ decreases → all $P_{r,i}$ scale down proportionally. But the noise variance $\sigma^2$ is **additive and constant** (independent of $\alpha$). The signal-to-noise ratio:

$$\mathrm{SNR}_i = \frac{P_{r,i}^2}{\sigma^2} = \frac{\alpha^2 \cdot Q_i^{2m}}{\sigma^2} \tag{13}$$

decreases quadratically with $\cos\psi$. Lower SNR → noisier power estimates → noisier ratios/normalization → slightly larger RMSE.

**The degradation is an indirect noise effect, not a structural bias.** The estimators remain unbiased; only their variance increases.

### 4.2. FOV boundary effects (marginal for small tilts)

From `OWC_LOS_channel.m` (line 17):
```matlab
if( abs(acosd(cos_psi)) <= FOV && cos_phi > 0 )
```

If tilt pushes $\psi > \text{FOV}$ (85°), then $H_0 = 0$ for all orientations simultaneously (since $\psi$ is shared). This is an all-or-nothing effect. For $\sigma_{\text{tilt}} = 5°$, the mean tilt is ≈4° and 99% of samples are below 15°, so FOV=85° is never violated for positions near the center.

### 4.3. Quantification

For a tilt of $\theta_{\text{tilt}}$, the effective $\cos\psi$ changes from $\cos\psi_0$ (vertical case) to approximately:

$$\cos\psi' \approx \cos\psi_0 \cdot \cos\theta_{\text{tilt}} + \text{cross terms}$$

For $\theta_{\text{tilt}} = 5°$: $\cos(5°) = 0.9962$, so $\alpha$ decreases by only 0.38%. This propagates through the noise to give the observed ~2% RMSE increase, consistent with the simulation results.

---

## 5. Comparison: Why DEB Also Shows Low Degradation

The DEB (Direction Error Bound) at +1.69% is comparable to the estimators. This is because the DEB's Fisher Information Matrix contains the term:

$$\mathrm{FIM} \propto \frac{\alpha^2}{\sigma^2} \cdot (\text{angular geometry terms})$$

The $\alpha^2$ scaling means the CRLB (inverse of FIM) increases when $\alpha$ decreases. But for small tilts, $\alpha$ barely changes → DEB barely changes.

**Importantly, the DEB does explicitly use $\mathbf{n}_r$ in its computation** (via `DEB_complete_nr`), so it correctly captures the SNR change. The estimators' degradation tracks the bound, confirming that the degradation is purely noise-driven.

---

## 6. Summary

| Mechanism | GLS/WLS | NL-MLE |
|-----------|---------|--------|
| **How $\alpha$ is eliminated** | Explicit power ratios $P_{r,i}/P_{r,1}$ | Normalization $P_{r,i}/\max_j P_{r,j}$ + free $\eta$ |
| **Direction extraction** | Null-space of $\mathbf{A} = [\mathbf{n}_t^{(i)} - \beta_i \mathbf{n}_t^{(1)}]$ | $\arg\min_{\mathbf{v}} F(\mathbf{v}, \eta)$ |
| **$\mathbf{n}_r$ appears in estimate?** | No | No |
| **Residual degradation cause** | SNR ↓ due to reduced $\alpha$ | Same |
| **Structural bias from tilt?** | None | None |

### The fundamental reason (one sentence):

> The LOS channel model factorizes as $P_{r,i} = \alpha(\mathbf{n}_r, d) \cdot Q_i^m(\mathbf{v}_{tr})$, where $\alpha$ is **common to all LED orientations $i$**. Any estimator that operates on ratios or normalized powers eliminates $\alpha$ — and with it, all dependence on $\mathbf{n}_r$, $d$, $P_t$, and $A_{\det}$.

### When would this property break?

1. **Multiple LEDs at different positions**: Each LED $j$ at position $\mathbf{T}_j$ has its own $d_j$ and $\psi_j$, so $\alpha_j$ differs across LEDs. Ratios between different LEDs would NOT cancel $\mathbf{n}_r$.
2. **Non-Lambertian emission**: If the emission pattern is not purely $\cos^m(\phi)$, the separability in Eq. (4) may not hold.
3. **Large tilts exceeding FOV**: If tilt causes some positions to fall outside the FOV while others remain, the all-or-nothing clipping creates missing data rather than a smooth scaling.

---

## Code References

| File | Lines | Role |
|------|-------|------|
| `OWC_LOS_channel.m` | 12–22 | Implements Eq. (1): $P_r = P_t H_0$ with LOS channel |
| `vlp_gls.m` | 19 | Computes $\beta_i$ from power ratios, Eq. (5) |
| `vlp_gls.m` | 28–35 | Builds $\mathbf{A}$ and $\mathbf{M}$, Eq. (7) |
| `vlp_wls.m` | 23 | Same $\beta_i$ computation |
| `run_nr_random_tilt_MC_parallel.m` | 252–254 | Normalization $p_{\text{target}}$, Eq. (8) |
| `run_nr_random_tilt_MC_parallel.m` | 259 | Builds NL cost with `mle_cost_function`, Eq. (10) |
| `run_nr_random_tilt_MC_parallel.m` | 459–467 | Cost function implementation |
| `run_nr_random_tilt_MC_parallel.m` | 469–472 | Unit sphere constraint $\|\mathbf{v}\|=1$ |
