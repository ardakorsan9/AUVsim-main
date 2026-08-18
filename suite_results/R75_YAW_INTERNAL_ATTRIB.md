# R75_YAW_INTERNAL_ATTRIB

**TASK_ID:** R75_YAW_INTERNAL_ATTRIB_001
**Date:** 2026-08-05 18:05:46
**Verdict:** PASS
**Single source:** guidance_step

## Summary

Instrumented one deterministic R=7.5, u=1.50, T=120s run. Reconstructed P/D/cmd/rate-limit from production equations without modifying controller_law.m / guidance_law.m. Gate: var>=0.70 and relation/coherence>=0.70 on command ripple (RL vs output).

- Acquisition: |e_psi|<=2deg for >=1.0s -> t_acq=6.88 s
- Steady: 3 turns used after t_ss0=22.68 s (T_lap_est=31.6)
- f_g=13.3333 Hz, f_c=40.0000 Hz, target f0=13.3333 Hz

## Metric table (5 rows)

| Source | var/share | |corr| | coh@f0 | amp_ratio@f0 | select |
|---|---:|---:|---:|---:|---:|
| P-yaw | 0.9807 | 0.9962 | 1.0000 | 0.9812 |  |
| D/r_ff | 0.0199 | 0.2266 | 1.0000 | 0.0195 |  |
| guidance_step | 0.9955 | 0.9977 | 1.0000 | 0.9812 | CHOSEN |
| rudder_rate_limiter | 0.3060 | 0.5532 | 1.0000 | 15.7404 |  |

## Support metrics

| Item | Value |
|---|---:|
| e_psi RMS / p95 [deg] | 0.6425 / 0.9249 |
| P / D ripple RMS [deg] | 7.8151 / 0.6982 |
| cmd_sat / delta_r ripple RMS [deg] | 7.9380 / 0.7037 |
| cmd-out diff RMS / MAE [deg] | 7.5266 / 6.0898 |
| rate-limit active % | 82.41 |
| RL sign-flip freq [Hz] | 19.6247 |
| sat % (|cmd_u|>=0.95 dmax) | 26.26 |
| dom f cmd / dr / P / Gstep [Hz] | 13.3333 / 13.3333 / 13.3333 / 13.3333 |
| amp@f0 P/D/cmd/dr [deg] | 10.9957 / 0.2184 / 11.2065 / 0.6752 |
| mean |dpsi_ref| on ticks [deg] | 0.8811 |
| psi_ref change <-> guidance-tick assoc | 1.0000 |

## Classification

**PASS — source = guidance_step** (score=0.995, relation=1.000).

**Recommended next (minimal):** Hold/interpolate yaw_ref (and r_ff) between guidance ticks (ZOH->ramp over dt_g); target >=10% drop in rudder ripple RMS with yaw RMS/p95 regression <=2%.

## Evidence paths

- suite_results/R75_YAW_INTERNAL_ATTRIB.md
- suite_results/R75_YAW_INTERNAL_ATTRIB.mat
- suite_results/R75_YAW_INTERNAL_ATTRIB.png

## MATHEMATICAL_DELTA

```
MATHEMATICAL_DELTA = {
  equations: {
    e_psi = wrap(yaw_ref - psi),
    e_r = r - r_ff,
    P = Kp_psi * e_psi,  D = -Kd_psi * e_r,
    cmd_unsat = P + D,  cmd_sat = clip(cmd_unsat, +/-dmax),
    max_dr = 40deg/s * dt_c,
    delta_r = rate_limit(cmd_sat, max_dr),
    Gstep = Kp_psi * (yaw_ref_ZOH - yaw_ref_linear_interp),
    RLeff = cmd_sat - delta_r,
    x_ripple = x - movmean(x, 1s),
    var_share_P/D = E[x*cmd]/E[cmd^2],  R2 = 1-var(y-a*x)/var(y),
    coh(f0) = |Pxy|^2 / (Pxx*Pyy) @ f0=1/dt_g
  },
  variables_units_frames: {
    angles/cmd [rad] internal, reported [deg]; r,r_ff [rad/s]; f [Hz]
  },
  assumptions: {
    production freeze Kp=32 Kd=13 dt_c=0.0250 dt_g=0.0750 dmax=25deg;
    reconstruct yaw path identical to controller_law; plant via ode45;
    gate: score>=0.70 AND max(|corr|,coh)>=0.70
  },
  parameter_provenance: {
    DERIVED: P,D,cmd,RL flags, spectra, scores from instrumented sim,
    IDENTIFIED: source=guidance_step,
    TUNED: none,
    FIXED: R=7.5,u=1.5,T=120, windows as radial/baseline
  },
  design_reason: 'Bind 13.33 Hz rudder ripple to one internal component quantitatively.',
  rejected_alternatives: {
    production_edit: rejected (audit-only),
    gain_retune: rejected (attribution first)
  },
  evidence: { suite_results/R75_YAW_INTERNAL_ATTRIB.* },
  conclusion: 'PASS: source=guidance_step',
  open_questions: { next=Hold/interpolate yaw_ref (and r_ff) between guidance ticks (ZOH->ramp over dt_g); target >=10% drop in rudder ripple RMS with yaw RMS/p95 regression <=2%. }
}
```
