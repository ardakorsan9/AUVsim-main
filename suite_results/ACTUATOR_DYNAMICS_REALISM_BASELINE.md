# ACTUATOR_DYNAMICS_REALISM_BASELINE

**TASK_ID:** ACTUATOR_DYNAMICS_REALISM_BASELINE_001  
**Date:** 2026-08-06 15:54:31  
**Verdict:** **PASS** — deterministic documented shadow-model evidence only.  
**Physical readiness:** **NOT_CERTIFIED**  
**Production edited:** NO · **NL rerun:** NO · **CODEX_VERTICAL_PLAN:** untouched  

## Sources (≤3)

| # | Path |
|---|------|
| 1 | `suite_results/AUV_REALISM_AND_VISUAL_VALIDATION.md` |
| 2 | `suite_results/AUV_VISUAL_EVIDENCE_PACK.md` |
| 3 | `suite_results/ACTUATOR_FEEDBACK_TELEMETRY_ICD.md` |

Command replay: `suite_results/ROLL_PRODUCTION_CLOSURE.mat (candidate.SH R10)`

## Shadow model

```
cmd_m=sat(cmd,±mag); x*=a*x+(1-a)*cmd_m, a=exp(-dt/τ); x+=sat(x*-x,±rate*dt); x=sat(x,±mag); actual dt per sample
```

| Item | Value | Provenance |
|------|-------|------------|
| Elevator mag | ±15 deg | FIXED (pack/ICD) |
| Rudder mag | ±25 deg | FIXED (pack/ICD) |
| Rate limit | ±40 deg/s | FIXED (pack/ICD) |
| PSD marker | 13.33 Hz | DERIVED (pack 1/dt_guidance) |
| Servo τ grid | [0.05 0.1 0.2] s | **ASSUMED** (ICD: no vendor/bench τ) |
| Current / thermal / backlash / HW cert | — | **NOT invented** |

ICD + realism audit document software mag/rate only; no vendor/bench servo τ. Prior SIL separability used τ=0.05 ASSUMED only. This baseline runs ASSUMED τ∈{0.05,0.10,0.20} s.

## Timing (accepted R10 timestamps)

| N | t0 | tf | dt_med | dt_min | dt_max | unique dt |
|---|----|----|--------|--------|--------|-----------|
| 1800 | 0.0250 | 45.0000 | 0.025000 | 0.025000 | 0.025000 | 1 |

Nonuniform `dt` handler enabled (per-sample `exp(-dt/τ)` and `ω_max·dt`). This log is uniform at dt=0.0250 s.

## Metrics (steady t≥5 s)

| τ [s] | Channel | Angle RMSE [deg] | Max err [deg] | Delay [s] | Phase@13.33Hz [deg] | Mag sat % | Rate dwell % | TV [deg] | Chatter [deg/s] | PSD att @13.33Hz | u2*dr proxy ratio |
|------|---------|------------------|---------------|-----------|---------------------|-----------|---------------|----------|-----------------|----------------|-------------------|
| 0.05 | elevator | 0.0043 | 0.0190 | 0.0250 | 119.97 (xcorr; FO-atan=76.6) | 0.00 | 0.00 | 3.45 | 0.2744 | 0.0782 | n/a |
| 0.05 | rudder | 0.5153 | 0.9659 | 0.0500 | 76.57 (xcorr; FO-atan=76.6) | 0.00 | 0.00 | 452.94 | 13.7263 | 0.0784 | 0.9884 |
| 0.10 | elevator | 0.0083 | 0.0354 | 0.0750 | -0.09 (xcorr; FO-atan=83.2) | 0.00 | 0.00 | 2.94 | 0.2519 | 0.0205 | n/a |
| 0.10 | rudder | 0.7063 | 1.6684 | 0.0750 | -0.09 (xcorr; FO-atan=83.2) | 0.00 | 0.00 | 261.99 | 8.8048 | 0.0205 | 0.9828 |
| 0.20 | elevator | 0.0138 | 0.0596 | 0.1500 | -0.18 (xcorr; FO-atan=86.6) | 0.00 | 0.00 | 2.29 | 0.2123 | 0.0052 | n/a |
| 0.20 | rudder | 0.8737 | 2.4845 | 0.0750 | -0.09 (xcorr; FO-atan=86.6) | 0.00 | 0.00 | 149.65 | 5.6234 | 0.0052 | 0.9763 |

Ideal software-command chatter (pack HF metric): δe=**0.3398** / δr=**37.7381** deg/s (G2 context).

## Findings

- Ideal cmd ≡ plant input today; shadow FO+limits introduce measurable lag/attenuation vs that ideal.
- Rate-dwell and PSD attenuation quantify how much R10 command chatter would be filtered by a lagging fin.
- Yaw-moment proxy uses only existing `u^2*δr` relationship (coeff cancels in RMS ratio).
- No hardware certification; τ remains **ASSUMED** until vendor/bench ID.

## Artifacts

- `suite_results/ACTUATOR_DYNAMICS_REALISM_BASELINE.md`
- `suite_results/ACTUATOR_DYNAMICS_REALISM_BASELINE.mat`
- `suite_results/ACTUATOR_DYNAMICS_REALISM_BASELINE.png`
- Driver: `run_actuator_dynamics_realism_baseline.m`

## Next

`actuator_nonlinearity_stub_deadband_backlash` — isolated δr deadband **or** backlash stub; compare chatter/limit-cycle vs this FO baseline; no retune; production frozen.
