# PITCH_XZ_WARMSTART_I

**TASK_ID:** PITCH_XZ_WARMSTART_I_001
**Date:** 2026-08-05 19:10:41
**Verdict:** **FAIL**

## Change

- Candidate (tested then **reverted**): `controller_law.m` pitch **int_angle** warm-start on reset/first call: `int_angle(0)=de_fb_eq/(elevator_sign*Kp_rate*Ki_angle)`, bounded by `±deg2rad(8)/Ki_angle`.
- Production restored: `int_angle(0)=0` (original cold start).
- `de_fb_eq=0.0502529684 rad` (2.8793°) = mean(de_fb) over ATTRIB λ=0 steady window.
- `int_angle(0)=0.330615 rad·s` (ia_max=±0.8727) during candidate run.
- Driver: `run_pitch_xz_warmstart_i.m` (retained).
- No climb trim/FF, no prev_delta_e init, no gain/guidance/plant change.

## Before / After (λ=0 XZ, same windows)

| Metric | Baseline | Candidate | Δ% |
|--------|--------:|----------:|---:|
| dip [°] | 2.9630 | 1.7575 | -40.7 |
| acq MAE [°] | 1.0480 | 0.8739 | -16.6 |
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

- de_trim=-4.620° de_fb=2.879° de_unsat=-1.741° de_final=-1.000°
- int_angle(t0)=0.330615 rad·s (target 0.330615)

## Evidence paths

- suite_results/PITCH_XZ_WARMSTART_I.md
- suite_results/PITCH_XZ_WARMSTART_I.mat
- suite_results/PITCH_XZ_WARMSTART_I.png

## MATHEMATICAL_DELTA

```
MATHEMATICAL_DELTA = {
  equations: {
    de_fb_eq = mean(de_fb)_steady,  % ATTRIB λ=0
    int_angle(0) = de_fb_eq / (elevator_sign * Kp_rate * Ki_angle),
    int_angle = sat(int_angle, +/- deg2rad(8)/Ki_angle),
    % at e≈0, rate≈0, Ki_rate=0: de_fb = sign*Kp_rate*Ki_angle*int_angle
    dip = path_pitch - min(theta_phys)_acq
  },
  variables_units_frames: {
    int_angle [rad*s] physical-pitch error integral (e_theta=pitch_ref-theta_phys),
    de_fb, de_fb_eq [rad] body elevator feedback; reported [deg],
    theta_phys=-theta [rad] physical pitch
  },
  parameter_provenance: {
    DERIVED: de_fb_eq=0.0502529684 rad from PITCH_XZ_INTERNAL_ATTRIB.mat
             steady mask (t>=5 & s<0.88*s_tot & ~acq), n=272,
    DERIVED: int_angle(0)=0.330615 = de_fb_eq/(1*0.95*0.16),
    IDENTIFIED: cold int_angle => de_fb(0)=0 while climb needs ~+2.88° fb,
    TUNED: none,
    FIXED: lambda=0, u0=1.5, T=22s, XZ z=0.4x, yaw+pitch gains frozen,
           prev_delta_e(0)=0 (actuator-init candidate rejected)
  },
  design_reason: 'Bumpless I: seed angle integrator to settled XZ de_fb.',
  rejected_alternatives: {
    prev_delta_e=de_trim: FAILED/reverted, climb_trim: deferred, gain_retune: frozen
  },
  evidence: { suite_results/PITCH_XZ_WARMSTART_I.* },
  conclusion: 'FAIL: revert production',
  open_questions: { next_target_only }
}
```
