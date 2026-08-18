# ACTUATOR_RUDDER_DEADBAND_STUB

**TASK_ID:** ACTUATOR_RUDDER_DEADBAND_STUB_001  
**Date:** 2026-08-08 01:00:57  
**Verdict:** **PASS** — deterministic open-loop deadband sensitivity evidence only.  
**Physical readiness:** **NOT_CERTIFIED**  
**Production edited:** NO · **NL rerun:** NO · **CODEX_VERTICAL_PLAN:** untouched  
**Scope note:** Open-loop R10 command replay — **NOT** a closed-loop limit-cycle test.  

## Sources (≤3)

| # | Path |
|---|------|
| 1 | `suite_results/ACTUATOR_DYNAMICS_REALISM_BASELINE.md` |
| 2 | `suite_results/ACTUATOR_DYNAMICS_REALISM_BASELINE.mat` |
| 3 | `run_actuator_dynamics_realism_baseline.m` |

Command replay: `suite_results/ACTUATOR_DYNAMICS_REALISM_BASELINE.mat Results.series (accepted R10 from ROLL_PRODUCTION_CLOSURE candidate.SH)`

## Shadow + deadband model

```
cmd_m=sat(cmd,±25deg); x*=a*x+(1-a)*cmd_m, a=exp(-dt/τ), τ=0.10s ASSUMED; x+=sat(x*-x,±40deg/s*dt); x=sat(x,±25deg); y=deadband_playfree(x,w) with w∈{0,0.10,0.25,0.50}deg ASSUMED
```

**Exact deadband operator + init:** `y = 0 if |x|<=w; else y = x - w*sign(x)  (symmetric, memoryless, play-free; NOT backlash/hysteresis/current). Init: apply to first FO state sample; no internal deadband state.`

| Item | Value | Provenance |
|------|-------|------------|
| Rudder mag | ±25 deg | FIXED (baseline/pack/ICD) |
| Rate limit | ±40 deg/s | FIXED (baseline/pack/ICD) |
| Servo τ | 0.10 s | **ASSUMED** (baseline mid; ICD: no vendor/bench τ) |
| Deadband widths | [0 0.1 0.25 0.5] deg | **ASSUMED** (play-free sensitivity grid) |
| PSD marker | 13.33 Hz | DERIVED (pack 1/dt_guidance) |
| Backlash / hysteresis / current / HW cert | — | **NOT invented** |

## Timing (accepted R10 timestamps)

| N | t0 | tf | dt_med | dt_min | dt_max | unique dt |
|---|----|----|--------|--------|--------|-----------|
| 1800 | 0.0250 | 45.0000 | 0.025000 | 0.025000 | 0.025000 | 1 |

Nonuniform `dt` handler enabled (per-sample `exp(-dt/τ)` and `ω_max·dt`). This log is uniform at dt=0.0250 s.

## Metrics (steady t≥5 s; rudder only)

| w [deg] | Angle RMSE [deg] | Max err [deg] | Bias [deg] | TV [deg] | Chatter [deg/s] | ZC count | Stick events | Deadband dwell % | PSD att @13.33Hz | u2*dr proxy ratio |
|--------|------------------|---------------|------------|----------|-----------------|----------|--------------|-------------------|-----------------|-------------------|
| 0.00 | 0.7063 | 1.6684 | -0.0022 | 261.99 | 8.8048 | 0 | 0 | 0.00 | 0.0205 | 0.9828 |
| 0.10 | 0.7136 | 1.6945 | -0.1022 | 261.99 | 8.8048 | 0 | 0 | 0.00 | 0.0205 | 0.9604 |
| 0.25 | 0.7499 | 1.8445 | -0.2522 | 261.99 | 8.8048 | 0 | 0 | 0.00 | 0.0205 | 0.9269 |
| 0.50 | 0.8666 | 2.0945 | -0.5022 | 261.99 | 8.8048 | 0 | 0 | 0.00 | 0.0205 | 0.8710 |

Ideal software-command chatter (pack HF metric): δr=**37.7381** deg/s (G2 context).

## Findings

- Isolated open-loop sensitivity of a play-free deadband after FO+limits on accepted R10 δr commands.
- Does **not** demonstrate closed-loop limit cycles; that would require a closed-loop experiment.
- Yaw-moment proxy uses only existing `u^2*δr` relationship (coeff cancels in RMS ratio).
- τ and deadband widths remain **ASSUMED**; physical readiness **NOT_CERTIFIED** until vendor/bench ID.
- No severe new open-loop risk flag; return to depth/gamma coupled-plant identification gate.

## Artifacts

- `suite_results/ACTUATOR_RUDDER_DEADBAND_STUB.md`
- `suite_results/ACTUATOR_RUDDER_DEADBAND_STUB.mat`
- `suite_results/ACTUATOR_RUDDER_DEADBAND_STUB.png`
- Driver: `run_actuator_rudder_deadband_stub.m`

## Next

`depth_gamma_coupled_plant_identification_gate`
