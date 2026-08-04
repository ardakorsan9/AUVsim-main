# TUR5B_SUMMARY — gamma path-angle guidance

**Date:** 2026-08-04 18:02:17
**Change:** `pitch_ref = theta_path + K_gamma*e_gamma + Kz*e_z + depth-I` (Tur4B skipped)
**Overall:** **FAIL** — Kg=0.75, K_zdot=0 (drop), alpha=OFF, XZ CTE=2.635 (4.7% vs Tur4A).

## Definition

- `gamma_actual = atan2(zdot_inertial, U_h)`
- `gamma_path = atan2(zdot_path, U_path_h)`, `zdot_path = t_hat(3)*U_along`
- `e_gamma = gamma_path - gamma_actual` (filtered)
- `alpha_eff = theta_phys - gamma_actual`
- `theta_ref = theta_path + K_gamma*e_gamma + Kz*e_z + Ki*int [+ K_zdot term]`
- Optional: `theta_ref = gamma_path + K_gamma*e_gamma + depth + alpha_hat`
- Pitch_ref rate limits **kept**. Yaw / R5 / LQI **not** in this task.

## Frozen

| Param | Value |
|-------|------:|
| `lambda_muw_ff` | **0.25** |
| `dt_controller` | 0.0250 |
| `dt_guidance` | 0.0750 |
| `tau_rate` | 0.0500 |
| `Ki_rate` | 0.000 |
| `Ki_angle` | 0.160 |
| `K_gamma` (selected) | **0.75** |
| `K_zdot` (selected) | **0.00** |
| `enable_alpha_hat` | **false** |
| Tur4A `r_ff=U_h*κ` / trim T25 / pitch PID | **kept** |
| Tur4B radial FF | **SKIPPED** |

## T5B-0 — log only (K_gamma=0, K_zdot=0.50)

No behavior change vs T5A production. Diagnostics on XZ slant:

| Metric | Value |
|--------|------:|
| CTE | 2.628 m |
| \|e_θ\| | 1.52° |
| mean \|θ−γ\| | **2.50°** |
| rms (θ−γ) | 2.52° |
| mean α_eff | +2.50° |
| mean e_γ | +2.01° |
| mean e_z | -0.227 m |
| mean e_zdot | +0.051 m/s |
| mean w | -0.070 m/s |
| mean zdot | +0.551 m/s |
| mean pitch_ref | 23.59° |

**Note on \|θ−γ\|:** On XZ dive (~21.8° path), mean \|θ_phys−γ_actual\| ≈ 2.50°. Small AoA — θ≈γ; gamma FB mainly corrects path-angle lag, not large trim AoA.

## T5B-1 — K_gamma sweep (K_zdot=0)

Baseline CTE = 2.766 m (Tur4A). T5A CTE = 2.628. Target ≤2.351 (≥15%).

| K_gamma | CTE (m) | Δ% vs base | \|e_θ\| (°) | mean e_θ (°) | chatter (°/s) | elev sat% |
|-------:|--------:|-------------:|------------:|-------------:|--------------:|------------:|
| 0.00 | 2.766 | -0.0 | 1.55 | +1.316 | 0.0665 | 0.0 |
| 0.25 | 2.711 | +2.0 | 1.53 | +1.327 | 0.0687 | 0.0 |
| 0.50 | 2.669 | +3.5 | 1.52 | +1.342 | 0.0803 | 0.0 |
| 0.75 **best** | 2.635 | +4.7 | 1.53 | +1.357 | 0.1041 | 0.0 |
| 1.00 | 2.607 | +5.8 | 1.53 | +1.372 | 0.1332 | 0.0 |

## T5B-2 — A/B K_zdot @ best K_gamma=0.75

| K_zdot | CTE | \|pitch\| | chatter | sat% |
|-------:|----:|---------:|--------:|------:|
| 0.00 | 2.635 | 1.53 | 0.1041 | 0.0 |
| 0.50 | 2.572 | 1.56 | 0.1377 | 0.0 |

**Decision:** DROP T5A term — production `K_zdot=0` (no clear benefit).

## T5B-3 — alpha_hat

**Skipped** (gates already met, or gamma not directional enough / STOP).

## Full suite

**Not run** — XZ candidate did not clear gates.

## Acceptance (XZ)

| Check | Result |
|-------|--------|
| XZ CTE ≤ 2.351 (≥15% drop) | FAIL (2.635) |
| Prefer XZ CTE < 2.0 m | FAIL |
| \|e_θ\| < 0.8° | FAIL (1.53) |
| chatter < 0.12 °/s | PASS (0.1041) |
| no elevator sat | PASS (0.0%) |
| X/circle/helix CTE ≤5% worse | n/a (suite skipped) |
| **Overall T5B** | **FAIL** |

## Verdict

**T5B FAIL / STOP** — CTE improve only 4.7% (<10%) with \|e_θ\|~1.53°.
More gain only raises chatter → STOP. Recommend **coupled LQI** (state [ez, ezdot, eθ, q, Iz]).

## NEXT queue (do NOT implement in this task)

1. **Yaw ref smoothness** — yaw rises steadily but some refs do not.
2. **R=5 speed scheduler** — if rudder-authority limited circle still needs work.
3. **Coupled LQI** — state [ez, ezdot, eθ, q, Iz] (T5B gates FAIL).

## Files touched

- `guidance_law.m` — gamma FB (+ optional alpha_hat), diagnostics globals
- `continuous_path_tracking.m` — pass theta_phys; suite gamma logs
- `init_parameters.m` — `K_gamma`, `enable_alpha_hat`; `K_zdot` default updated
- `run_tur5b.m` — this runner
