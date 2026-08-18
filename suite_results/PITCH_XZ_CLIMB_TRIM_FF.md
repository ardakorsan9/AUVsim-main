# PITCH_XZ_CLIMB_TRIM_FF

**TASK_ID:** PITCH_XZ_CLIMB_TRIM_FF_001
**Date:** 2026-08-05 19:20:28
**Verdict:** **FAIL**

## Change

- Production: `controller_law.m` climb equilibrium FF `delta_e_climb_ff = sat(k_gamma*gamma_ref, ±2.8793°)`, `k_gamma=0.1320695001`, `gamma_ref=pitch_ref` (physical pitch / climb path).
- Added to elevator sum: `de_unsat = de_trim + de_uw_ff + de_climb_ff + de_fb`.
- `int_angle(0)=0` (no I warm-start). λ=0 => Muw FF≡0.
- Driver: `run_pitch_xz_climb_trim_ff.m` (this file).
- No Muw λ, gain, guidance, plant, actuator-init, or I-warm-start change.

## Before / After (λ=0 XZ, same windows)

| Metric | Baseline | Candidate | Δ% |
|--------|--------:|----------:|---:|
| dip [°] | 2.9630 | 1.7577 | -40.7 |
| acq MAE [°] | 1.0480 | 0.8740 | -16.6 |
| acq / settling [s] | 15.05 | 3.35 | -77.7 |
| overshoot [°] | 0.0000 | 0.0000 | — |
| steady RMS [°] | 0.3393 | 0.2307 | -32.0 |
| steady p95 [°] | 0.4445 | 0.5519 | +24.2 |
| steady MAE [°] | 0.3320 | 0.1537 | -53.7 |
| sat% | 0.00 | 0.00 | — |
| chatter [°/s] | 0.0004 | 0.0052 | — |

## Gates

| Gate | Result |
|------|--------|
| dip improve ≥30% OR acq MAE ≥10% | YES (dip 40.7% / acqMAE 16.6%) |
| steady RMS/p95 regression ≤2% | NO |
| acq settling not worse | YES |
| overshoot not worse | YES |
| sat ≤1% | YES (0.00%) |
| no new chatter | YES |

**Overall: FAIL**

## Elev@t0 / I@t0

- de_trim=-4.620° climbFF=2.879° de_fb=0.000° de_unsat=-1.741° de_final=-1.000°
- int_angle(t0)=0.000000 rad·s (cold; no warm-start)

## Evidence paths

- suite_results/PITCH_XZ_CLIMB_TRIM_FF.md
- suite_results/PITCH_XZ_CLIMB_TRIM_FF.mat
- suite_results/PITCH_XZ_CLIMB_TRIM_FF.png

## MATHEMATICAL_DELTA

```
MATHEMATICAL_DELTA = {
  equations: {
    k_gamma = 2.8793/21.8014,  % deg/deg = rad/rad
    gamma_ref = pitch_ref,    % physical pitch / climb-path ref [rad]
    de_climb_ff = sat(k_gamma*gamma_ref, +/- deg2rad(2.8793)),
    de_unsat = de_trim(u) + de_uw_ff + de_climb_ff + de_fb,
    int_angle(0) = 0,
    dip = path_pitch - min(theta_phys)_acq
  },
  variables_units_frames: {
    gamma_ref, pitch_ref, theta_phys [rad] physical-pitch frame (theta_phys=-theta),
    de_climb_ff, de_trim, de_fb, de [rad] body elevator; reported [deg],
    k_gamma [-] dimensionless (elevator rad per pitch-ref rad)
  },
  parameter_provenance: {
    DERIVED: k_gamma=0.1320695001 from ATTRIB λ=0 steady mean(de_fb)=+2.8793°
             / XZ path_pitch=21.8014° (PITCH_XZ_INTERNAL_ATTRIB.mat, n=272),
    DERIVED: bound=±2.8793° = |de_fb_eq| (same IDENTIFIED equilibrium),
    IDENTIFIED: cold I => de_fb(0)=0 while climb needs ~+2.88°; FF supplies it,
    TUNED: none,
    FIXED: lambda=0, u0=1.5, T=22s, XZ z=0.4x, yaw+pitch gains frozen,
           int_angle(0)=0, prev_delta_e(0)=0 (prior candidates rejected)
  },
  design_reason: 'Literature climb trim FF: k_gamma*gamma_ref, not I memory.',
  rejected_alternatives: {
    prev_delta_e=de_trim: FAILED/reverted,
    int_angle warm-start: FAILED (steady p95 +24.2%)/reverted,
    gain_retune: frozen, Muw_lambda: frozen at 0
  },
  evidence: { suite_results/PITCH_XZ_CLIMB_TRIM_FF.* },
  conclusion: 'FAIL: revert production',
  open_questions: { next_target_only }
}
```
