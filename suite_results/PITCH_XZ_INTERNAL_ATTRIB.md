# PITCH_XZ_INTERNAL_ATTRIB

**TASK_ID:** PITCH_XZ_INTERNAL_ATTRIB_001
**Date:** 2026-08-05 18:50:07
**Verdict:** **PASS**
**Dominant class:** **initial trim/state mismatch**

## Summary

One deterministic XZ-line run at \lambda=0 (accepted baseline). Production controller/guidance/plant untouched; analysis driver only. Goal: identify dominant cause of initial pitch dip/lag.

- Path pitch: 21.8014° | \theta(0)=21.7962° | \theta_ref(0)=21.8014° | e_\theta(0)=0.0000°
- Dip (path−min\theta): 2.9630° at t=1.50 s | |e|_max=2.9894° at t=1.60 s
- Acquisition: 15.20 s | MAE_acq=1.0475° | min \theta_acq=18.8384°
- Elev@t0: trim=-4.620° fb=0.000° MuwFF=0.000° final=-1.000°

## Class scores (dip window 0→t_dip)

| Class | Score |
|-------|------:|
| initial trim/state mismatch | 0.7213 |
| Muw FF | 0.0000 |
| reference shaping/feedforward | 0.0059 |
| actuator/rate limit | 0.1496 |
| plant authority | 0.0390 |

Gate: best≥0.45 and margin≥0.12 → best=0.721 margin=0.572

## Key attribution numbers

| Item | Value |
|------|------:|
| trim share RMS(de_trim)/RMS(de_unsat) | 1.803 |
| nose-down ∩ trim-dom fraction | 0.117 |
| RMS(de_fb)/RMS(de_trim) to t_|e|max | 1.382 |
| sat% / rl% in dip window | 0.00 / 5.00 |
| MuwFF max/RMS [deg] | 0.0000 / 0.0000 |
| \theta_ref lag MAE vs path [deg] | 0.0053 |
| 0.8·\thetȧ_ref share of q_ref | 0.009 |
| \Delta\theta_ref / \Delta\theta_phys in dip [deg] | 0.008 / 2.958 |
| RMS(M_uw) / RMS(M_elev) [N·m] | 1.326 / 0.652 |
| M_uw oppose M_elev fraction | 0.117 |
| int_angle(0) / int_angle(t_dip) [rad] | 0.0000 / 0.0463 |

## Classification

**PASS — dominant class = initial trim/state mismatch** (score=0.721, margin=0.572).

Time alignment: at t=0, \theta matches path pitch and e_\theta≈0, but elevator is level-table trim (I-states cold). Through t_dip, nose-down coincides with trim-dominated command while feedback/integrators catch up; Muw FF≡0, sat/rl≈0, \theta_ref does not drive the dip.

## Next target

Climb-aware elevator trim / warm-start I at XZ IC (analysis-only next); target cut dip ≥30% and acq MAE without touching yaw or production pitch gains.

## Evidence paths

- suite_results/PITCH_XZ_INTERNAL_ATTRIB.md
- suite_results/PITCH_XZ_INTERNAL_ATTRIB.mat
- suite_results/PITCH_XZ_INTERNAL_ATTRIB.png

## MATHEMATICAL_DELTA

```
MATHEMATICAL_DELTA = {
  equations: {
    theta_phys = -theta,
    e_theta = theta_ref - theta_phys,   % [rad], physical pitch frame
    theta_rate_cmd = 0.8*theta_ref_dot + Kp_a*e + Ki_a*int_a,
    de_unsat = de_trim(u) + de_muw_ff + de_fb,  % de_muw_ff=0 at lambda=0
    de = rate_limit(sat(de_unsat, +/-de_max), 40deg/s),
    M_uw = Muw*u*w,   G_de = Muuds*u_eff^2,
    dip = path_pitch - min(theta_phys)_acq
  },
  variables_units_frames: {
    angles [rad] internal / [deg] reported; rates [rad/s]/[deg/s];
    M [N*m]; u,w [m/s] body; physical pitch frame (theta_phys=-theta)
  },
  parameter_provenance: {
    DERIVED: scores, dip, sat/rl flags, trim_share, oppose_frac from one sim,
    IDENTIFIED: dominant_class=initial trim/state mismatch,
    TUNED: none,
    FIXED: lambda=0, u0=1.5, T=22s, XZ path z=0.4x, production gains frozen
  },
  design_reason: 'Bind initial XZ pitch dip/lag to one internal cause.',
  rejected_alternatives: {
    production_edit: rejected (audit-only),
    gain_retune: rejected (yaw+pitch gains frozen),
    Muw_FF: ruled out (lambda=0 => de_muw_ff==0)
  },
  evidence: { suite_results/PITCH_XZ_INTERNAL_ATTRIB.* },
  conclusion: 'PASS: class=initial trim/state mismatch',
  open_questions: { next_target_only_no_fix }
}
```
