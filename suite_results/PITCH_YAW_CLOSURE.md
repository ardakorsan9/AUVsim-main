# PITCH_YAW_CLOSURE

**TASK_ID:** PITCH_YAW_FINAL_CLOSURE_001
**Date:** 2026-08-05 20:47:33
**Verdict:** **PASS**

## FINAL_CHANGELOG

### Accepted production (old → new)

- **old:** `de_unsat = de_trim + de_uw_ff + de_fb` (no climb FF)
- **new:** `de_unsat = de_trim + de_uw_ff + de_climb_ff + de_fb`
- `de_climb_ff = sat(k_gamma * gamma_ref, ±2.8793°)`, `k_gamma=0.1320695001`, `gamma_ref = pitch_ref` (physical)
- `int_angle(0)=0`, `prev_delta_e(0)=0`; X λ=0.25; XZ λ=0; helix λ=0.25
- Gains / guidance / plant **frozen**; this task is driver/report only (no edits).

### Equations / units / frame / provenance

```
k_gamma = 0.1320695001 = 2.8793/21.8014   [-]  (elev rad / pitch-ref rad)
gamma_ref = pitch_ref                     [rad] physical (theta_phys=-theta)
de_climb_ff = sat(k_gamma*gamma_ref, +/-deg2rad(2.8793))  [rad]
e_theta = pitch_ref - theta_phys
e_psi   = wrapToPi(psi_ref - psi)
X windows: first_hold ±0.5°/1s; steady=(t≥5∧s<0.88 s_tot)\acq
XZ/helix pitch: persistent |eθ|≤±0.5° to s<0.88*s_total
helix yaw: t≥5 ∩ before_end (open Frenet SBE); ratio=mean(r)/mean(Uh*κ)
provenance: ATTRIB λ=0 steady mean(de_fb)=+2.8793° / path_pitch=21.8014°
promoted: PITCH_CLIMB_FF_REGRESSION_001; helix envelope: HELIX_R10_...
```

### Percent effects (pre-climb → accepted production / capsule)

| Route | Metric | Old | New | Δ% |
|-------|--------|----:|----:|----:|
| X | ss MAE [°] | 0.0637 | 0.0110 | -82.7 |
| X | ss RMS [°] | 0.0683 | 0.0164 | -76.0 |
| X | ss p95 [°] | 0.0856 | 0.0419 | -51.1 |
| XZ | settle [s] | 14.08 | 6.18 | -56.1 |
| XZ | acq MAE [°] | 1.0876 | 0.7549 | -30.6 |
| XZ | ss MAE [°] | 0.3502 | 0.1214 | -65.3 |
| XZ | ss p95 [°] | 0.4812 | 0.4039 | -16.1 |

### Reverted / not-promoted trials

- Pre-window climb candidates rescored under first_hold (false early settle) — superseded by persistent WINDOW_AUDIT.
- `PITCH_XZ_WARMSTART_I`, `PITCH_XZ_BUMPLESS_DE_INIT` — diagnostic / not production.
- Helix R=5 hard authority FAIL (rudder sat ~95%); R=7.5 soft FAIL (sat 1.06%, ratio 1.024); R=8 soft FAIL (full sat 6.67%, ratio 1.0236) — envelope docs only, no retune.
- Optional Muw schedule revisit deferred; gains remain frozen.

### Untried advanced controllers

- LQR / LQG pitch-yaw MIMO
- MPC / NMPC with actuator constraints
- Adaptive / MRAC or gain-scheduled climb FF beyond fixed k_gamma
- Sliding-mode / backstepping nonlinear redesign
- Dual-loop α / path-angle cascade beyond current trim+Muw+climbFF+PID

## Determinism / seeds

- `rng(0,'twister')` reset before each of 6 sims; Type=twister.
- Plant/controller deterministic (ode45, fixed IC); RNG unused by dynamics.
- Persistent state cleared via `clear guidance_law controller_law` (+ helix globals) each run.
- X repeats: **PASS** — deterministic identity (bit-match after clear persistent)
- XZ repeats: **PASS** — deterministic identity (bit-match after clear persistent)
- Helix repeats: **PASS** — deterministic identity (bit-match after clear persistent)

## X (first_hold) — acquisition / steady

| | settle [s] | acq MAE | ss MAE | ss RMS | ss p95 | sat% |
|--|---:|---:|---:|---:|---:|---:|
| rep1 | 2.65 | 0.3831 | 0.0110 | 0.0164 | 0.0419 | 0.00 |
| rep2 | 2.65 | 0.3831 | 0.0110 | 0.0164 | 0.0419 | 0.00 |
| capsule | — | — | 0.0110 | 0.0164 | 0.0419 | — |

## XZ λ=0 (persistent) — acquisition / steady

| | settle [s] | acq MAE | ss MAE | ss RMS | ss p95 | sat% |
|--|---:|---:|---:|---:|---:|---:|
| rep1 | 6.18 | 0.7549 | 0.1214 | 0.1769 | 0.4039 | 0.00 |
| rep2 | 6.18 | 0.7549 | 0.1214 | 0.1769 | 0.4039 | 0.00 |
| capsule | 6.18 | 0.7549 | 0.1214 | — | 0.4039 | 0.00 |

## R10 helix — pitch persistent / yaw wrap SBE

### Pitch

| | settle [s] | acq MAE | ss MAE | ss RMS | ss p95 | elev sat% | chat |
|--|---:|---:|---:|---:|---:|---:|---:|
| rep1 | 2.23 | 0.5243 | 0.0413 | 0.0712 | 0.1004 | 0.00 | 0.0157 |
| rep2 | 2.23 | 0.5243 | 0.0413 | 0.0712 | 0.1004 | 0.00 | 0.0157 |
| capsule | — | — | 0.0413 | — | 0.1004 | — | — |

### Yaw (wrapped, open-helix SBE)

| | MAE | RMS | p95 | sat acq/ss/full % | ratio |
|--|---:|---:|---:|---:|---:|
| rep1 | 0.1748 | 0.2041 | 0.3493 | 13.48/0.00/0.67 | 1.0181 |
| rep2 | 0.1748 | 0.2041 | 0.3493 | 13.48/0.00/0.67 | 1.0181 |
| capsule | 0.1748 | — | 0.3493 | —/—/0.67 | 1.0181 |

## Gates

| Gate | Result |
|------|--------|
| X MAE≤0.10 / RMS&p95 reg≤2% / sat≤1% / vs capsule≤1% | YES |
| XZ MAE≤0.30 / p95≤0.50 / acq≥10% / sat≤1% / vs capsule≤1% | YES |
| Helix pitch+yaw prior gates + vs capsule≤1% | YES |
| Two-repeat ≤1% (or identity) X/XZ/H | YES |

**Overall: PASS**

## Evidence

- Driver: `run_pitch_yaw_final_closure.m` (no controller/guidance/plant change)
- `suite_results/PITCH_YAW_CLOSURE.md`
- `suite_results/PITCH_YAW_CLOSURE.mat`
- `suite_results/FINAL_TRACKING_X.png`
- `suite_results/FINAL_TRACKING_XZ.png`
- `suite_results/FINAL_TRACKING_HELIX_R10.png`
- `CODEX_VERTICAL_PLAN.md` untouched

## Conclusion

PASS: nonlinear 6DOF closure confirmed for X, XZ(λ=0), R10 helix under accepted climb-FF production. Repeats deterministic; prior gates held; actuators within limits.
Next: freeze production checklist; optional finer R_min bracket only if needed; no gain change.
