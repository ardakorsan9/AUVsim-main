# R75_YAW_SMOOTHNESS_BASELINE

**TASK_ID:** R75_YAW_SMOOTHNESS_AUDIT_001
**Date:** 2026-08-05 17:53:03
**Verdict:** PASS
**Ripple source class:** reference/guidance

## Summary

Re-analyzed existing WRAP MAT (R=7.5, u=1.50, T=120). No re-sim; no controller/gain change. Quantified yaw-rate/rudder oscillation with 1 s trend removal.

- Acquisition: |e_psi|<=2deg for >=1.0s -> t_acq=5.83 s
- Steady: 3 complete turns after t_ss0=21.62 s (T_lap_est=31.6 s)

## Main metrics

| Window | signal | signed mean | MAE | RMS | p95 | max |
|---|---|---:|---:|---:|---:|---:|
| acq | e_psi [deg] | 8.916 | 8.916 | 9.2728 | 11.448 | 11.627 |
| steady | e_psi [deg] | 0.30164 | 0.30651 | 0.38639 | 0.63035 | 0.66414 |
| steady | |e_psi| [deg] | 0.30651 | 0.30651 | 0.38639 | 0.63035 | 0.66414 |
| steady | r [rad/s] | 0.20481 | 0.20481 | 0.20481 | 0.20668 | 0.20787 |
| steady | U_h*kappa [rad/s] | 0.1989 | 0.1989 | 0.1989 | 0.19914 | 0.1992 |
| steady | r-U_h*kappa [rad/s] | 0.005902 | 0.005902 | 0.0059947 | 0.0077069 | 0.0087693 |
| steady | r ripple 1s-detrend [rad/s] | 3.3525e-06 | 0.000803 | 0.00096784 | 0.0017774 | 0.0025954 |
| steady | rudder ripple 1s-detrend [deg] | 0.00024063 | 0.58203 | 0.70432 | 1.3361 | 1.6715 |
| steady | psi_ref_rate ripple [rad/s] | -5.7563e-06 | 0.27679 | 0.29373 | 0.42947 | 0.43693 |
| steady | psi_rate ripple [rad/s] | 3.5027e-06 | 0.00077749 | 0.00093368 | 0.0017072 | 0.002569 |

| Item | Value |
|---|---:|
| r / (U_h*kappa) mean ratio | 1.0297 |
| r ripple peak-peak [rad/s] | 0.00486 |
| rudder ripple peak-peak [deg] | 3.0713 |
| rudder rate RMS [deg/s] | 38.366 |
| rudder rate p95 |abs| [deg/s] | 40.000 |
| rudder total variation / s [deg/s] | 37.977 |
| rudder signed mean [deg] | 14.279 |
| saturation (|dr|>=0.95 dmax) | 0.00% (0.00 s) |
| near-limit (|dr|>=0.90 dmax) | 0.00% (0.00 s) |
| dom freq r_ripple [Hz] | 0.8809 |
| dom freq rudder_ripple [Hz] | 13.3333 |
| dom freq psi_ref_rate ripple [Hz] | 13.3333 |
| dom freq e_psi [Hz] | 13.3333 |
| f_guidance / f_controller [Hz] | 13.3333 / 40.0000 |
| psi_ref change<->guidance-tick assoc | 1.0000 (align=0) |
| mean |dpsi_ref| step [deg] (exp geometric) | 0.8771 (0.8548) |
| corr(r_ripple, pref_rate_ripple) | 0.0073 |
| corr(dr_ripple, pref_rate_ripple) | 0.3367 |
| corr(dr_ripple, e_psi) | 0.6164 |
| corr(dr_ripple, r_ripple) | 0.5166 |
| E_r / E_pref , E_dr / E_pref | 0.000 , 0.002 |

## Classification

**Class:** reference/guidance

- psi_ref ZOH locked to guidance ticks (assoc=1.000 align=0); dom f_pref=13.333 f_e_psi=13.333 f_dr=13.333 Hz == f_g=13.333; mean |dpsi_ref|=0.877 deg (geom 0.855); body r ripple small/smooth (RMS=0.0010 rad/s, f_r=0.881); corr(dr,e_psi)=0.616 sat=0.00%

**Recommended next (minimal):** Hold/interpolate yaw_ref (and r_ff) between guidance ticks (zero-order hold -> linear/ramp over dt_g) so controller sees continuous refs; target >=10% drop in trend-removed rudder/r RMS with yaw RMS/p95 regression <=2%.

## Evidence paths

- src: suite_results/YAW_CLOSED_METRIC_WRAP.mat (+ .md)
- suite_results/R75_YAW_SMOOTHNESS_BASELINE.md
- suite_results/R75_YAW_SMOOTHNESS_BASELINE.mat
- suite_results/R75_YAW_SMOOTHNESS_BASELINE.csv
- suite_results/R75_YAW_SMOOTHNESS_BASELINE.png

## MATHEMATICAL_DELTA

```
MATHEMATICAL_DELTA = {
  equations: {
    e_psi = wrap(psi_ref - psi),
    Uh_kappa = U_h_guid * kappa,
    x_ripple = x - movmean(x, 1s),
    TV/s = sum(|diff(delta_r)|) / Delta_t_ss,
    dom_f = argmax FFT(|x_ripple_ss|)
  },
  variables_units_frames: {
    e_psi[deg], r,Uh_kappa,r_ripple[rad/s], delta_r[deg], rates[deg/s], f[Hz]
  },
  assumptions: {
    same acq/steady windows as YAW_R75_RADIAL_DIAG; WRAP.S truth signals;
    dt_g=0.075, dt_c=0.025 production freeze; delta_r_max=25deg
  },
  parameter_provenance: {
    DERIVED: ripple/TV/dom_f/corrs/tick_assoc from WRAP.S,
    IDENTIFIED: class=reference_guidance,
    TUNED: none,
    FIXED: windows, 1s trend, sat thresholds 0.90/0.95
  },
  design_reason: 'Quantify oscillation and bind to one source class without retune.',
  rejected_alternatives: {
    re_sim: rejected (WRAP.S complete),
    gain_change: rejected (audit-only),
    measurement_artifact: rejected (sim truth)
  },
  evidence: { suite_results/R75_YAW_SMOOTHNESS_BASELINE.* },
  conclusion: 'PASS: class=reference/guidance',
  open_questions: { follow-up smoothness >=10% with yaw RMS/p95 <=2% regression }
}
```
