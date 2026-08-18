# PITCH_XZ_BUMPLESS_DE_INIT

**TASK_ID:** PITCH_XZ_BUMPLESS_DE_INIT_001
**Date:** 2026-08-05 18:57:27
**Verdict:** **FAIL**

## Change

- Candidate (tested then **reverted**): `controller_law.m` elevator rate-limiter persistent `prev_delta_e` init **0 → de_trim(u)** on first call.
- Production restored: `prev_delta_e = 0` (original).
- Driver: `run_pitch_xz_bumpless_de_init.m` (retained).
- No climb trim, no I warm-start, no gain/guidance/plant change.

## Before / After (λ=0 XZ, same windows)

| Metric | Baseline | Candidate | Δ% |
|--------|--------:|----------:|---:|
| dip [°] | 2.9630 | 3.0032 | +1.4 |
| acq MAE [°] | 1.0480 | 1.0525 | +0.4 |
| acq / settling [s] | 15.05 | 14.98 | -0.5 |
| overshoot [°] | 0.0000 | 0.0000 | — |
| steady RMS [°] | 0.3393 | 0.3384 | -0.3 |
| steady p95 [°] | 0.4445 | 0.4433 | -0.3 |
| steady MAE [°] | 0.3320 | 0.3310 | -0.3 |
| sat% | 0.00 | 0.00 | — |
| chatter [°/s] | 0.0004 | 0.0004 | — |

## Gates

| Gate | Result |
|------|--------|
| dip improve ≥30% OR acq MAE ≥10% | NO (dip -1.4% / acqMAE -0.4%) |
| steady RMS/p95 regression ≤2% | YES |
| acq settling not worse | YES |
| overshoot not worse | YES |
| sat ≤1% | YES (0.00%) |
| no new chatter | YES |

**Overall: FAIL**

## Elev@t0

- de_trim=-4.620° de_fb=0.000° de_unsat=-4.620° de_final=-4.620°

## Evidence paths

- suite_results/PITCH_XZ_BUMPLESS_DE_INIT.md
- suite_results/PITCH_XZ_BUMPLESS_DE_INIT.mat
- suite_results/PITCH_XZ_BUMPLESS_DE_INIT.png

## MATHEMATICAL_DELTA

```
MATHEMATICAL_DELTA = {
  equations: {
    de_trim = interp1(trim_speed_table, trim_elevator_table, |u|),
    prev_delta_e(0) <- de_trim(u0),   % was 0
    de = prev_de + sat(de_cmd - prev_de, +/-40deg/s * dt),
    de_unsat = de_trim + de_muw_ff + de_fb,  % lambda=0 => FF=0
    dip = path_pitch - min(theta_phys)_acq
  },
  variables_units_frames: {
    delta_e, de_trim [rad] body elevator; reported [deg];
    theta_phys=-theta [rad] physical pitch; e_theta=theta_ref-theta_phys
  },
  parameter_provenance: {
    DERIVED: de_trim(u0)=interp1([0.8 1 1.5 2], deg2rad([-9.18 -7.33 -4.62 -3.17]), 1.5),
    IDENTIFIED: prev_delta_e cold-start was rate-limiting trim onto surface,
    TUNED: none,
    FIXED: lambda=0, u0=1.5, T=22s, XZ z=0.4x, yaw+pitch gains frozen
  },
  design_reason: 'Bumpless: remove RL step from 0 to de_trim at t0.',
  rejected_alternatives: {
    climb_trim: deferred, gain_retune: frozen, I_warmstart: out of scope
  },
  evidence: { suite_results/PITCH_XZ_BUMPLESS_DE_INIT.* },
  conclusion: 'FAIL: revert production',
  open_questions: { next_target_only }
}
```
