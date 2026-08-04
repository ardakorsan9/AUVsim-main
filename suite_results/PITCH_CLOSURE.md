# PITCH_CLOSURE

**Date:** 2026-08-05 01:28:27
**Scope:** XZ acquisition vs steady + λ A/B. No gain retune. No LQI.

## Frozen stack

| Param | Value |
|-------|------:|
| `lambda_muw_ff` (level / production base) | **0.25** |
| Tur4A `r_ff=U_h*κ` / T25 trim | **kept** |
| `K_gamma` / `K_zdot` | **0 / 0** |
| `dt_c` / `dt_g` / `tau_rate` | 0.0250 / 0.0750 / 0.0500 |
| `Ki_angle` / `Ki_rate` | 0.160 / 0.000 |
| Pitch gains | **FROZEN** |

## Acquisition vs steady (XZ, λ=0.25)

Acquisition: first time `|eθ|` stays in ±0.5° for 1 s (else late settle; here acq≈19.8 s).
Steady: after acquisition AND `settled_before_end` (t≥5 s, s<0.88 s_path).

| Metric | Value |
|--------|------:|
| acq time | 19.75 s |
| mean\|eθ\| acq | 1.556° |
| mean\|eθ\| steady | **0.388°** |
| mean signed eθ steady | +0.388° |
| p95\|eθ\| steady | 0.437° |
| chatter steady | ~0 (short ss window; suite full-window ~0.029 °/s) |
| elev sat% steady | 0.0 |
| elev fb RMS steady | 5.133° |
| CTE_perp settled_before_end | 0.751 m |
| path pitch (geom) | 21.80° |

Historical suite mean `|pitch|≈1.44°` is **acquisition-dominated**; true steady is already inside the 0.25–0.40° prefer band.

## λ A/B (same IC)

| Metric | λ=0 | λ=0.25 |
|--------|----:|-------:|
| mean\|eθ\| steady | **0.332** | 0.388 |
| signed eθ steady | +0.332 | +0.388 |
| acq time (s) | **15.05** | 19.75 |
| elev fb RMS steady | **2.877** | 5.133 |
| chatter steady | 0.0004 | 0.0001 |
| CTE_perp sbe | **0.572** | 0.751 |

**A/B winner (XZ climb):** **λ=0** — faster acq, lower elev fb RMS, better CTE_perp; modest `|eθ|` edge.

Level/X still wants λ=0.25 (X hold `|eθ|=0.064°`).

## Quick X check (λ=0.25)

| Metric | Value |
|--------|------:|
| mean\|eθ\| sbe | 0.064° |
| signed eθ | +0.062° |
| chatter | 0.0179 °/s |
| elev sat% | 0.0 |
| CTE_perp sbe | 0.257 m |

## Freeze gates

| Gate | Result | Detail |
|------|:------:|--------|
| X / cruise \|eθ\| ~0.11° | YES | 0.064° |
| XZ steady mean\|eθ\| ≤0.40° | YES | 0.388° |
| XZ p95\|eθ\| ≤0.50° | YES | 0.437° |
| chatter ≤0.12 °/s | YES | suite ~0.029 |
| elev sat 0% | YES | 0.0% |

## Decision

- **Pitch gains FROZEN:** YES — do not retune; do not open LQI.
- XZ steady within gate — freeze and move on.
- **Scheduled λ (NEXT, not implemented):** level `λ=0.25` / climb lower (`λ≈0` when `|pitch_ref|>~8°`). A/B clearly helps climb effort/CTE; `|eθ|` delta alone was small so no code change this turn (<30-line schedule deferred).

## Files

- `run_pitch_yaw_closure.m`
- `suite_results/pitch_yaw_closure.mat`
