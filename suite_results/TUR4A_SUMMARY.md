# TUR4A_SUMMARY — r_ff = U_h · κ

**Date:** 2026-08-04 17:09:52
**Change:** `r_ff = U_h * kappa` (was `1.15 * u_ref * kappa`)

## U_h definition

**Inertial horizontal speed:** `U_h = hypot(x_dot, y_dot)` where
`[x_dot; y_dot; z_dot] = R(φ,θ,ψ) * [u; v; w]` (same R as plant).
Passed from `continuous_path_tracking` into `guidance_law` as arg 6.
Fallback if omitted: `hypot(u_body, v_body)`.

## Frozen (untouched)

| Param | Value |
|-------|------:|
| `lambda_muw_ff` | **0.25** |
| `dt_controller` | 0.0250 |
| `dt_guidance` | 0.0750 |
| `tau_rate` | 0.0500 |
| `Ki_rate` | 0.000 |
| `Ki_angle` | 0.160 |
| yaw gains / radial CTE FB / pitch/Muw/surge/XZ | **untouched** |

## Circle table (instrumented)

| R (m) | CTE (m) | CTE_ss | r / (U_h κ) | mean r (°/s) | mean U_hκ (°/s) | rudder sat% | |pitch| | chatter |
|------:|-------:|-------:|------------:|-------------:|----------------:|------------:|--------:|--------:|
| 5.0 | 1.516 | 1.174 | **0.789** | 12.60 | 15.98 | 92.4 | 0.14 | 0.0254 |
| 7.5 | 0.309 | 0.324 | **1.029** | 11.72 | 11.38 | 0.0 | 0.11 | 0.0198 |
| 10.0 | 0.275 | 0.284 | **1.017** | 9.05 | 8.90 | 0.0 | 0.09 | 0.0165 |

## Full suite regression (`run_path_suite(false)`)

Baseline = T3B-2 (λ=0.25, old r_ff). Gate: X/XZ/helix CTE ≤5% worse.

| Scenario | CTE now | CTE base | Δ% | |pitch| | chatter |
|----------|--------:|---------:|---:|--------:|--------:|
| X-line | 2.116 | 2.116 | +0.0 | 0.15 | 0.0506 |
| XZ-line | 2.766 | 2.766 | +0.0 | 1.55 | 0.0665 |
| Circle | 1.516 | 1.516 | +0.0 | 0.14 | 0.0254 |
| Helix | 1.675 | 1.666 | +0.5 | 0.21 | 0.0244 |

## Acceptance

| Check | Result |
|-------|--------|
| mean(r)/mean(U_h κ) ≥ 0.95 (R=5 ss) | FAIL (0.789) |
| Circle CTE clearly down vs 1.516 | FAIL (now 1.516) |
| No rudder sat (R=5) | FAIL (92.4%) |
| X/XZ/helix CTE ≤5% worse | PASS |
| λ=0.25 untouched | **YES** |

## Tur 4B needed?

**YES (for R=5 CTE)** — not implemented in this turn.

- Tur4A correctly raised `r_ff` to geometric `U_h·κ`.
- On **R=5**, vehicle is **rudder-authority limited**: commanded rate ↑ → **92% rudder sat**, actual `r` stays ~0.79·(U_h κ) (same lag vs geometry as prior diag), **CTE flat at 1.516 m**.
- On **R=7.5 / 10**, Tur4A alone is healthy (ratio ≥1.02, CTE ~0.3 m, no sat).
- Next lever for R=5 outward CTE is **Tur 4B radial CTE feedback** (or relax R/speed) — deferred per freeze.

## Interpretation

Old `1.15·u_ref·κ` under-commanded yaw rate (u_ref scheduled down on curves), so rudder stayed unsaturated while tracking a soft target. Geometric `U_h·κ` exposes the true R=5 turn-rate ceiling.

## Files touched

- `guidance_law.m` — `r_ff = U_h * kappa_f`
- `continuous_path_tracking.m` — pass inertial U_h
- `run_tur4a.m` — this runner
