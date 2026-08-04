# YAW_START

**Date:** 2026-08-05 01:30:30
**Scope:** Feasible circles R=7.5 / R=10 only (not R=5). Lean diagnose + cheap fix if warranted.

## Diagnosis

Suite/helix **~35° mean `|eψ|` was R=5 / hard-turn** (rudder-limited in Tur4A), **not** a feasible-circle unwrap bug.

On R=7.5 / 10:

| Check | Result |
|-------|--------|
| Wrapped `eψ` vs unwrapped lag | Match (~0.3° / ~0°) — **not** unwrap/metric artifact |
| `r / (U_h κ)` | **1.03 / 1.02** — rate FF tracks geometry |
| Rudder sat% | **0%** |
| mean `|eψ|` | **0.31° / 0.16°** — already near gate; no gain thrash |

Slope-corr of raw `Δψ` samples is noisy (ZOH ref); lag + rate ratio are the trustworthy signals.

## Numbers (production stack, t≥8 s / last 60%)

| R | mean\|eψ\| | signed eψ | unw lag | r/(Uhκ) | rudder sat% | mean δr | Kr_emp | CTE_perp |
|--:|----------:|----------:|--------:|--------:|-------------:|--------:|-------:|---------:|
| 7.5 | **0.31** | +0.30 | +0.30 | **1.030** | 0.0 | +14.25 | 1.252 | 1.315 |
| 10.0 | **0.16** | -0.01 | -0.01 | **1.018** | 0.0 | +4.46 | 0.501 | **0.284** |

## Cheap fix

**none** — heading error display is already small on feasible radii; `r_ff=U_h*κ` carries the turn. Do **not** add rudder-FF or retune `Kp_psi` until R=7.5 radial CTE is understood.

## Finding

1. **Display/metric:** ~35° was R=5 authority, not continuous-unwrap failure on R=7.5/10.
2. **Control:** rate tracks; steady `|eψ|` ≪ 1° on feasible circles.
3. **Open:** R=7.5 `CTE_perp≈1.32 m` vs R=10 `≈0.28 m` — radial/path issue (like prior CTE confusion), not heading lag. R=5 still rudder-limited (Tur4A).

## NEXT

1. Diagnose R=7.5 radial/`CTE_perp` (geometry vs progress projection vs speed) — not yaw gains.
2. Helix check with same true metrics.
3. R=5 curvature-aware speed only after R=7.5 radial is clean.
4. Do not open LQI for yaw.
