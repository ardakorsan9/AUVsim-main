# PLANT_VERTICAL_TABLE

**Date:** 2026-08-04 20:25:00
**Scope:** Lean elevator pulse audit — CL settle (pitch_ref=0, I reset), OL δe pulse (FB off).
**Protocol:** settle 8.0s → pulse 0.75s → recover 6.0s, dt=0.025s. Skip ±0.5° / full 32.
**Block-1 clear:** PASS (expanded u=0.8,2.0)

## Per-speed summary

| u (m/s) | authority Δθ_pk (deg) | inverse? | delay q/θ (s) | Muw λ=0.25 vs 0 | DC θ/(δe·u²) | DC ż/(δe·u²) | recommendation gate |
|--------:|----------------------:|:--------:|--------------:|:---------------|-------------:|-------------:|---------------------|
| 0.8 | 4.66 | no (0%) | 0.256 | **n/a (constrained)** | 0.215 | 0.136 | envelope — δe near limit / sign inconsistent; keep cascaded |
| 1.5 | 3.81 | no (0%) | 0.025 | **neutral** | 0.925 | 1.33 | LQI candidate (min-phase-ish) — keep cascaded until A/B |
| 2.0 | 8.11 | no (0%) | 0.000 | **neutral** | 1.00 | 2.08 | LQI candidate (min-phase-ish) — keep cascaded until A/B |

**Speed spread:** authority ≈ 78%, delay ≈ 273%. → **envelope scheduling** recommended across speed.

## Overall verdict

No lean-set inverse/NMP at **u=1.5 / 2.0** (event order `δe → M_elev → q → w → θ → zdot → z`, delay ≤ 0.025 s, +δe → +θ_phys). **u≈0.8 is constraint-dominated** (elevator near −15° limit, +pulse sign inconsistent) → **envelope** before any LQI. **Keep cascaded** now. Do **not** start LQI/yaw/roll. Muw FF λ=0.25 is **neutral** on vertical at cruise (slightly lower |Δθ| and |ż|; no inverse change).

Muw votes: u=0.8:n/a (constrained), u=1.5:neutral, u=2.0:neutral

## Per-run detail

| tag | valid | settle | event order | Δθ_pk | Δq_pk | first ż | later ż | inv? | delay | DC θ/u² | DC ż/u² |
|-----|:-----:|:------:|-------------|------:|------:|--------:|--------:|:----:|------:|--------:|--------:|
| `u1.5_de+1.0_lam0.00` | ok | 1 | de -> M_elev -> q -> w -> th -> zdot -> z | 4.37 | -2.87 | -0.001 | +0.085 | n | 0.025 | 1.04 | 1.47 |
| `u1.5_de-1.0_lam0.00` | ok | 1 | de -> M_elev -> q -> w -> th -> zdot -> z | -4.44 | 3.01 | +0.000 | -0.086 | n | 0.025 | 1.05 | 1.48 |
| `u1.5_de+1.0_lam0.25` | ok | 1 | de -> M_elev -> q -> w -> th -> zdot -> z | 3.19 | -1.73 | -0.001 | +0.069 | n | 0.025 | 0.80 | 1.18 |
| `u1.5_de-1.0_lam0.25` | ok | 1 | de -> M_elev -> q -> w -> th -> zdot -> z | -3.23 | 1.72 | +0.000 | -0.069 | n | 0.025 | 0.807 | 1.20 |
| `u0.8_de+1.0_lam0.00` | ok* | 1 | de -> M_elev -> zdot -> th -> w -> z -> q | -4.69 | 0.54 | -0.016 | -0.053 | n | 0.325 | -4.91 | -3.57 |
| `u0.8_de-1.0_lam0.00` | ok* | 1 | de -> zdot -> M_elev -> th -> w -> z -> q | -5.09 | 0.69 | -0.015 | -0.057 | n | 0.300 | 5.33 | 3.84 |
| `u0.8_de+1.0_lam0.25` | ok* | 1 | de -> M_elev -> zdot -> th -> w -> z | -4.23 | 0.84 | -0.008 | -0.044 | n | 0.200 | -4.35 | -2.99 |
| `u0.8_de-1.0_lam0.25` | ok* | 1 | de -> zdot -> M_elev -> th -> w -> z | -4.63 | 1.02 | -0.008 | -0.048 | n | 0.200 | 4.78 | 3.26 |
| `u2.0_de+1.0_lam0.00` | ok | 1 | de -> M_elev -> q -> w -> th -> zdot -> z | 9.40 | -6.37 | +0.001 | +0.261 | n | 0.000 | 1.14 | 2.33 |
| `u2.0_de-1.0_lam0.00` | ok | 1 | de -> M_elev -> q -> w -> th -> zdot -> z | -9.81 | 7.03 | -0.001 | -0.269 | n | 0.000 | 1.18 | 2.40 |
| `u2.0_de+1.0_lam0.25` | ok | 1 | de -> M_elev -> q -> w -> th -> zdot -> z | 6.51 | -3.51 | +0.001 | +0.200 | n | 0.000 | 0.83 | 1.78 |
| `u2.0_de-1.0_lam0.25` | ok | 1 | de -> M_elev -> q -> w -> th -> zdot -> z | -6.71 | 3.76 | -0.001 | -0.204 | n | 0.000 | 0.848 | 1.82 |

\*u=0.8 settled with δe near −15° limit (constraint); +pulse sign vs θ_phys inconsistent — do not treat as plant NMP.

## HAM / u²-normalized (cruise u=1.5, λ=0)

| metric | +1° | −1° |
|--------|----:|----:|
| Δθ_pk (deg) | +4.37 | −4.44 |
| Δq_pk (deg/s) | −2.87 | +3.01 |
| later Δż (m/s) | +0.085 | −0.086 |
| DC θ/(δe·u²) | 1.04 | 1.05 |
| DC ż/(δe·u²) | 1.47 | 1.48 |
| onset delay | 0.025 s | 0.025 s |

## Method notes

- Settle: `controller_law` pitch_ref=0, yaw_ref=0; persistents reset each run; `Ki_rate=0`; `Ki_angle=0` except u<1 (0.16 to reach LEVEL). Pulse is OL (FB off).
- Pulse: δe = de_hold_base + pulse + live Muw FF; thrust frozen; rudder=0.
- Inverse: first ≤0.25 s move of zdot/w/z opposite later (mid-pulse→pulse+1.5 s); pulse-return excluded.
- DC-ish: later Δθ, Δż / (δe·u²). Peaks: Δθ_pk, Δq_pk.
- Production gains/guidance **not** modified. No LQI/yaw/roll started.

## Files

- `run_elevator_pulse_audit.m`
- `suite_results/PLANT_VERTICAL_TABLE.md` (this file)
- `suite_results/elevator_pulse_audit.mat`
- `suite_results/elevator_pulse_png/*.png`
