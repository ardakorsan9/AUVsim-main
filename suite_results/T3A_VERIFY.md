# T3A_VERIFY — Muw sign / units / double-count / G_de

**Status:** COMPLETE (instrumentation only; FF off)
**Date:** 2026-08-04

## Frozen stack

| Param | Value |
|-------|------:|
| dt_controller | 0.025 |
| dt_guidance | 0.075 |
| tau_rate | 0.05 |
| Ki_rate | 0 |
| Ki_angle | 0.16 |
| trim table | Tur 2.5 accepted |
| Muw-FF λ | 0 (off) |
| circle r_ff / XZ guidance / yaw gains | untouched |

## Coefficients

- `Muw = 24.0000`
- `Muuds = -6.1500`
- `elevator_sign = +1`

## 1. Sign (u>0, w>0)

- `M_uw = Muw·u·w = 9.0000 N·m` at u=1.50, w=0.25 (positive).
- Body-axis convention: **+M → +q → +θ_internal → θ_phys↓** (nose-down physically).
- Therefore u>0,w>0 → **physical nose-down** moment.
- Open-loop probe Δθ_phys(w>0 − w=0) = **-30.3201 deg** (nose-down confirmed: 1).
- Elevator: `Muuds<0` so +δe → M_elev<0 → θ_phys↑ (matches elevator_sign=+1).
- Cancel FF (correct sign): `δe_ff = −(Muw·u·w)/(Muuds·u²) = −M_uw/G_de`.

## 2. Units

| Quantity | Unit |
|----------|------|
| Muw | kg (moment coeff) |
| Muw·u·w | **N·m** |
| Muuds | N·m/(rad·(m/s)²) |
| G_de = Muuds·u² | **N·m/rad** |
| M_elev = G_de·δe | **N·m** |

## 3. Double-count

**Verdict: NO_DOUBLE_COUNT**

- Explicit `Muw*u*w` occurrences in dynamics: **2**
- Other uw pitch-moment term: **no**
- Notes: Pitch moment M has exactly one Muw*u*w term. Coriolis/rigid-body companions are w*q, u*q, v*r, v*p, r*p — not u*w. Zuw*u*w is a heave FORCE, not a pitch moment. Added-mass Mwdot/Mqdot live in mass matrix A (acceleration coupling), not as an extra hydrodynamic uw velocity-product moment. Conclusion: NOT double-counted.

## 4. Elevator effectiveness G_de

Formula used for FF: **G_de = Muuds · u²** (equiv. ∂M/∂δe).

| u (m/s) | G_de (N·m/rad) |
|--------:|---------------:|
| 0.8 | -3.9360 |
| 1.0 | -6.1500 |
| 1.5 | -13.8375 |
| 2.0 | -24.6000 |

Numeric ∂M/∂δe @ u=1.5: -13.837500 vs analytic -13.837500 (rel err 0.00e+00).

## 5. λ=0 regression vs T25 suite baseline

| Scenario | Metric | T25 | T3A (FF off) |
|----------|--------|----:|-------------:|
| X | CTE (m) | 2.063 | 2.063 |
| X | mean\|pitch\| (deg) | 0.57 | 0.57 |
| X | chatter (deg/s) | 0.0788 | 0.0789 |
| XZ | mean\|pitch\| (deg) | 0.94 | 0.94 |
| Helix | mean\|pitch\| (deg) | 0.26 | 0.26 |

Regression within tolerance: **YES**

### Moment logs (settle window, FF off)

| Scenario | RMS M_uw | RMS M_elev | RMS(M_uw+M_elev) | mean G_de |
|----------|---------:|-----------:|-----------------:|----------:|
| X | 1.8136 | 1.6723 | 0.1594 | -17.495 |
| XZ | 2.6902 | 0.5188 | 2.2052 | -16.288 |
| HELIX | 1.8751 | 1.3349 | 0.5442 | -12.096 |

## Instrumentation

- `underwater777_vehicle_dynamics.m`: optional globals `diag_last_M_uw`, `diag_last_M_elev`, `diag_last_G_de`, `diag_last_M_total` when `diag_muw_enable=true`.
- Harness: `verify_tur3_muw.m`.
- Equations unchanged; closed-loop identical when FF disabled.
