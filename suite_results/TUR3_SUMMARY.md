# TUR3_SUMMARY — Muw verify + graduated feedforward

**Status:** ACCEPTED (λ=0.25)  
**Date:** 2026-08-04  
**Branch:** `master` (local)

## Frozen stack (unchanged)

| Param | Value |
|-------|------:|
| `dt_controller` | 0.025 s |
| `dt_guidance` | 0.075 s (ZOH) |
| `tau_rate` | 0.05 s |
| `Ki_rate` | 0 |
| `Ki_angle` | 0.16 |
| trim table | Tur 2.5 accepted |
| circle `r_ff` / XZ guidance / yaw gains | **untouched** |

## T3A findings

| Check | Result |
|-------|--------|
| **Sign** (u>0,w>0) | `Muw·u·w > 0` → body +M → θ_phys↓ (**physical nose-down**). Cancel: `δe_ff = −(Muw·u·w)/(Muuds·u²)`. OL probe confirmed. |
| **Units** | `Muw·u·w` and `Muuds·u²·δe` are **N·m**; `G_de = Muuds·u²` is N·m/rad. |
| **Double-count** | **NO** — single explicit `Muw*u*w` in pitch moment; Coriolis has wq/uq/… not uw; `Zuw·u·w` is heave force; added-mass `Mwdot` is acceleration coupling only. |
| **G_de** | Analytic = numeric ∂M/∂δe (rel err 0). Used in FF denominator with `u_eff² = max(u²,u_min²)`. |
| **λ=0 regression** | Matches T25 suite (X CTE 2.063, \|pitch\| 0.57, chatter 0.0789). |

## λ sweep table (key metrics)

Baseline = T3B-1 (λ=0). Focus: X / XZ / Helix (+ Circle sanity).

| λ | X CTE | X \|pitch\| | X chatter | X de RMS | X de_fb | X resid | XZ \|pitch\| | Helix \|pitch\| | sat |
|--:|------:|------------:|----------:|---------:|--------:|--------:|-------------:|----------------:|----:|
| 0.00 | 2.063 | 0.57 | 0.0789 | 5.608 | 1.588 | 1.814 | 0.94 | 0.26 | 0 |
| **0.25** | **2.116** | **0.15** | **0.0506** | **5.624** | **0.448** | **1.363** | 1.55 | **0.21** | 0 |
| 0.50 | 2.169 | 0.60 | 0.0403 | 5.642 | 1.546 | 0.917 | 1.98 | 0.47 | 0 |
| 0.75 | 2.217 | 0.91 | 0.0643 | 5.632 | 2.359 | 0.709 | 1.99 | 0.47 | 0 |
| 1.00 | 2.229 | 0.96 | 0.0716 | 5.623 | 2.528 | 0.699 | 2.00 | 0.47 | 0 |

Circle (sanity, guidance untouched): λ=0 → pitch 0.40 / chatter 0.0405; λ=0.25 → pitch **0.14** / chatter **0.0237**.

## Decision: λ = 0.25 — ACCEPT

### Why 0.25
- X chatter 0.079→0.051 (−36%), ≤0.12
- X \|pitch\| 0.57→0.15 (−74%); mean eθ bias ≈0
- X de_fb RMS 1.59→0.45 (−72%); residual Muw+Me_ff −25%
- Helix \|pitch\| 0.26→0.21 (−19%)
- Elevator RMS +0.3% (≪15%); **no saturation**
- λ≥0.50 overcompensates X pitch (error grows) → reject 0.50–1.00

### Trade-off (accepted)
- XZ \|pitch\| worsens 0.94→1.55 (climb path; FF fights needed elevator). Deferred to **Tur 5** XZ γ/ż guidance — do not thrash pitch gains.
- X CTE +2.6% (2.063→2.116) — mild; within prior ~5% CTE gate style.

### Rejected
- λ=0.50 / 0.75 / 1.00: X pitch overshoot, XZ worse, helix pitch up vs λ=0.25, de_fb up again.

## Production defaults (T3C)

```
lambda_muw_ff = 0.25
muw_ff_u_min = 0.50
muw_ff_u_lo  = 0.70
muw_ff_u_hi  = 1.20
muw_ff_clamp_deg = 4.0
```

Formula (additive; does not replace feedback):

```
u_eff2 = max(u^2, u_min^2)
raw = -lambda * (Muw * u * w) / (Muuds * u_eff2)
de_uw_ff = b(u) * clamp(raw, ±4 deg)
delta_e = trim + de_uw_ff + de_fb
```

## Commits

| SHA theme | Message |
|-----------|---------|
| T3A | Muw sign/unit/double-count instrumentation |
| T3B-1 | Muw FF infrastructure, lambda=0 regression |
| T3B-2 | Muw FF lambda=0.25 suite |
| T3B-3 | Muw FF lambda=0.50 suite |
| T3B-4 | Muw FF lambda=0.75 suite |
| T3B-5 | Muw FF lambda=1.00 suite |
| T3C | keep best Muw FF lambda + TUR3_SUMMARY |

## Untouched (confirmed)

- `guidance_law.m` circle `r_ff = 1.15*u_ref*kappa` — no edits
- XZ guidance structure / depth-I — no edits
- Yaw gains — no edits
- Rate/angle gains, Ki_rate, tau_rate, trim table — frozen

## Next

**Tur 4** — circle `r_ff` (actual-u based), then **Tur 5** — XZ γ/ż guidance (address XZ pitch regression under Muw-FF).
