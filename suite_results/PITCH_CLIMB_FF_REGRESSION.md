# PITCH_CLIMB_FF_REGRESSION

**TASK_ID:** PITCH_CLIMB_FF_REGRESSION_001
**Date:** 2026-08-05 20:07:58
**Verdict:** **PASS**

## Change

- **old:** no climb FF (`de_unsat = de_trim + de_uw_ff + de_fb`)
- **new:** `de_climb_ff = sat(k_gamma*gamma_ref, ±2.8793°)`, `k_gamma=0.1320695001`, `gamma_ref=pitch_ref` (physical)
- Elevator sum: `de_unsat = de_trim + de_uw_ff + de_climb_ff + de_fb`
- `int_angle(0)=0`, `prev_delta_e(0)=0`; XZ `λ=0`; X `λ=0.25` (level)
- Driver: `run_pitch_climb_ff_regression.m`. No gains/guidance/plant change.
- Windows: X `first_hold` (match STATE/PITCH_X_TRACK); XZ `persistent` (WINDOW_AUDIT).

## Equations / units / frame / provenance

```
k_gamma = 0.1320695001 = 2.8793/21.8014   [-] elevator rad / pitch-ref rad
gamma_ref = pitch_ref                     [rad] physical pitch (theta_phys=-theta)
de_climb_ff = sat(k_gamma*gamma_ref, +/- deg2rad(2.8793))  [rad] body elevator
de_unsat = de_trim(u) + de_uw_ff + de_climb_ff + de_fb
int_angle(0)=0; prev_delta_e(0)=0
X windows: first_hold ±0.5°/1s; steady=(t≥5∧s<0.88 s_tot)∖acq
XZ windows: persistent |eθ|≤±0.5° to end-excl s<0.88*s_total
provenance: ATTRIB λ=0 steady mean(de_fb)=+2.8793° / path_pitch=21.8014°
```

## X before / after (first_hold / STATE baseline)

| Metric | Baseline | Candidate | Δ% |
|--------|--------:|----------:|---:|
| steady MAE [°] | 0.0637 | 0.0110 | -82.7 |
| steady RMS [°] | 0.0683 | 0.0164 | -75.9 |
| steady p95 [°] | 0.0856 | 0.0419 | -51.1 |
| sat% | 0.00 | 0.00 | — |

## XZ before / after (persistent, λ=0)

| Metric | Baseline | Candidate | Δ% |
|--------|--------:|----------:|---:|
| settling [s] | 14.08 | 6.18 | -56.1 |
| acq MAE [°] | 1.0876 | 0.7549 | -30.6 |
| steady MAE [°] | 0.3502 | 0.1214 | -65.3 |
| steady RMS [°] | 0.3595 | 0.1769 | -50.8 |
| steady p95 [°] | 0.4812 | 0.4039 | -16.1 |
| dip [°] | 2.9630 | 1.7577 | -40.7 |
| overshoot [°] | 0.0000 | 0.0000 | — |
| sat% | 0.00 | 0.00 | — |
| chatter [°/s] | 0.0004 | 0.0046 | — |

## Gates

| Gate | Result |
|------|--------|
| X MAE ≤0.10° | YES (0.0110°) |
| X RMS reg ≤2% | YES (Δ%=-75.9) |
| X p95 reg ≤2% | YES (Δ%=-51.1) |
| XZ MAE ≤0.30° | YES (0.1214°) |
| XZ p95 ≤0.50° | YES (0.4039°) |
| XZ acq improve ≥10% | YES (30.6%) |
| XZ sat ≤1% | YES (0.00%) |
| XZ no new chatter | YES |
| XZ no new overshoot | YES |

**Overall: PASS**

## Evidence

- MATLAB: `run_pitch_climb_ff_regression`
- suite_results/PITCH_CLIMB_FF_REGRESSION.md
- suite_results/PITCH_CLIMB_FF_REGRESSION.mat
- suite_results/PITCH_CLIMB_FF_REGRESSION.png

## Conclusion

PASS: keep climb equilibrium FF in production `controller_law.m`.
Next: freeze checklist / optional Muw schedule revisit with climb FF on.
