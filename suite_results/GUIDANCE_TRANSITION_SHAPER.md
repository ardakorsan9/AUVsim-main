# GUIDANCE_TRANSITION_SHAPER_001 — Isolated mission-geometry transition shaper

**Candidate verdict: FAIL** (first=`CLIMB:pitch_MAE(0.6885>0.3000)`)

**Prioritized next gate: `CLOSE_MISSION_SHAPER_LINE`** — REJECT transition shaper (production untouched). First=`CLIMB:pitch_MAE(0.6885>0.3000)`. Close mission-shaper line after this single failure; document production mission limitations (no segment blender / clothoid in guidance; composite C1 polyline insufficient for SPEED_ENVELOPE hard gates on multi-segment mission).

## Provenance

- Read-only: `run_guidance_mission_baseline.m`, `suite_results/GUIDANCE_MISSION_BASELINE.{md,mat}`
- Baseline stamp: 2026-08-06 06:11:42 | first_fail=`LEVEL:gamma_MAE(0.7356>0.5000)`
- Driver: `run_guidance_transition_shaper.m` (one MATLAB invocation)
- Production plant/controller/guidance: **UNTOUCHED / FROZEN** (no gain tuning)
- Gates: identical SPEED_ENVELOPE / COMBINED absolutes (no relaxation)
- Artifacts: `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\GUIDANCE_TRANSITION_SHAPER.md`, `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\GUIDANCE_TRANSITION_SHAPER.mat`, `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\GUIDANCE_TRANSITION_SHAPER.png`
- Did **not** touch `CODEX_VERTICAL_PLAN.md`
- Stamp: 2026-08-06 06:26:55 | seed=0 | U=1.50 | T_final=96.0s | s_total=115.02m | R_des=10.000m R_meas_min=10.000m

## Geometry / equations

- Intent: ACQ → LEVEL → +4.0m CLIMB → ~90° TURN (R≥10) → LEVEL EXIT
- Design note: ACQ lead-in + C2 quintic climb + Fresnel clothoid κ-ramps about R=10 arc; C0 position + C1 unit tangent; κ continuous 0↔1/R at turn; R_min>=10.
- Continuity: pos_ok=YES tang_ok=YES
- Max climb slope=0.2083 (γ≈11.77 deg) | κ_max=0.1000 | Δψ_cloth=22.92 deg | ang_circ=44.16 deg
- Exit heading≈90.00 deg (target 90)

Equations:

- ACQ/LEVEL/EXIT: r(s)=r0 + s*[cosψ,sinψ,0]
- CLIMB: x=x0+s; z=z0+dz*(10σ^3-15σ^4+6σ^5), σ=s/L_climb (z_s=z_ss=0 at ends)
- Clothoid: κ(s)=κ0+(κ1-κ0)s/L; ψ(s)=ψ0+κ0 s+0.5(κ1-κ0)s^2/L; ẋ=cosψ,ẏ=sinψ
- Circle: κ=1/R; Δψ_cloth=0.5 κ_max L_cloth; ang_circ=π/2-2Δψ_cloth
- Params: L_acq=15.0 L_level=20.0 L_climb=36.0 L_cloth=8.0 R=10.0 dz=4.0
- Provenance: isolated shaper vs baseline raised-cosine L=20 + sharp R10 (GUIDANCE_MISSION_BASELINE build_composite_mission_path)

| Segment | s0 [m] | s1 [m] | L [m] | Scored | Description |
|---|---:|---:|---:|:---:|---|
| ACQ | 0.00 | 15.00 | 15.00 | NO | ACQ lead-in +X z=0.0 L=15.0m (score separate) |
| LEVEL | 15.00 | 35.00 | 20.00 | YES | Level straight +X z=0.0 L=20.0m |
| CLIMB | 35.00 | 71.00 | 36.00 | YES | Quintic smoothstep climb Δz=+4.0m over L=36.0m (C2 z ends) |
| TURN | 71.00 | 94.71 | 23.71 | YES | Clothoid-circle-clothoid left turn R=10.0 ang=90deg L_c=8.0 L_arc=7.71m |
| EXIT | 94.71 | 115.02 | 20.31 | YES | Level exit heading≈90.0deg L=20.0m at z=4.0 |

## Baseline vs candidate (post-ACQ phases)

| Seg | metric | baseline | candidate |
|---|---|---:|---:|
| LEVEL | pitch_MAE | 0.0483 | 0.0047 |
| LEVEL | gamma_MAE | 0.7356 | 0.2438 |
| LEVEL | yaw_MAE | 0.0000 | 0.0000 |
| LEVEL | yaw_p95 | 0.0000 | 0.0000 |
| LEVEL | CTE_mean | 0.199 | 0.253 |
| LEVEL | |ez|_MAE | 0.1709 | 0.2572 |
| LEVEL | roll_MAE | 0.000 | 0.000 |
| LEVEL | u_mean | 1.813 | 1.817 |
| LEVEL | deSat% | 0.00 | 0.00 |
| LEVEL | drSatF% | 0.00 | 0.00 |
| LEVEL | chat | 0.0271 | 0.0016 |
| LEVEL | deRateU | 0.007 | 0.004 |
| LEVEL | drRateU | 0.000 | 0.000 |
| LEVEL | FEAS | NO | YES |
| CLIMB | pitch_MAE | 1.6186 | 0.6885 |
| CLIMB | gamma_MAE | 3.4535 | 1.5938 |
| CLIMB | yaw_MAE | 0.0004 | 0.0000 |
| CLIMB | yaw_p95 | 0.0001 | 0.0000 |
| CLIMB | CTE_mean | 0.673 | 0.226 |
| CLIMB | |ez|_MAE | 0.6473 | 0.2231 |
| CLIMB | roll_MAE | 0.000 | 0.000 |
| CLIMB | u_mean | 1.772 | 1.791 |
| CLIMB | deSat% | 0.00 | 0.00 |
| CLIMB | drSatF% | 0.00 | 0.00 |
| CLIMB | chat | 0.0941 | 0.0595 |
| CLIMB | deRateU | 0.132 | 0.072 |
| CLIMB | drRateU | 0.051 | 0.002 |
| CLIMB | FEAS | NO | NO |
| TURN | pitch_MAE | 0.1673 | 0.0861 |
| TURN | gamma_MAE | 0.5478 | 0.9653 |
| TURN | yaw_MAE | 0.6161 | 0.8370 |
| TURN | yaw_p95 | 2.3221 | 1.6360 |
| TURN | CTE_mean | 0.364 | 0.323 |
| TURN | |ez|_MAE | 0.3069 | 0.3213 |
| TURN | roll_MAE | 1.525 | 1.323 |
| TURN | u_mean | 1.605 | 1.642 |
| TURN | deSat% | 0.00 | 0.00 |
| TURN | drSatF% | 0.00 | 0.00 |
| TURN | chat | 0.0833 | 0.0072 |
| TURN | deRateU | 0.021 | 0.006 |
| TURN | drRateU | 0.908 | 0.921 |
| TURN | FEAS | NO | NO |
| EXIT | pitch_MAE | 0.0988 | 0.1071 |
| EXIT | gamma_MAE | 0.6417 | 0.6171 |
| EXIT | yaw_MAE | 0.5267 | 0.2246 |
| EXIT | yaw_p95 | 2.3418 | 0.7814 |
| EXIT | CTE_mean | 0.225 | 0.071 |
| EXIT | |ez|_MAE | 0.2369 | 0.0486 |
| EXIT | roll_MAE | 0.192 | 0.022 |
| EXIT | u_mean | 1.766 | 1.793 |
| EXIT | deSat% | 0.00 | 0.00 |
| EXIT | drSatF% | 0.00 | 0.00 |
| EXIT | chat | 0.0106 | 0.0068 |
| EXIT | deRateU | 0.005 | 0.004 |
| EXIT | drRateU | 0.604 | 0.392 |
| EXIT | FEAS | NO | NO |

## ACQ (report-only; not a hard gate)

- thMAE=0.0654 gMAE=0.9107 yawMAE=0.0000 CTE=0.175 |ez|=0.1411 u=1.811 roll=0.000 chat=0.0309
- Act: deSat=0.00% drSatF=0.00% thrSat=0.00% |de|_max=5.38 |dr|_max=0.00

## Candidate per-segment hard gates (post-ACQ)

| Seg | FEAS | First | thMAE | gMAE | yawMAE | CTE | |ez| | deSat | drSatF | chat | mono |
|---|:---:|---|---:|---:|---:|---:|---:|---:|---:|---:|:---:|
| LEVEL | YES | none | 0.0047 | 0.2438 | 0.0000 | 0.253 | 0.2572 | 0.00 | 0.00 | 0.0016 | YES |
| CLIMB | NO | pitch_MAE(0.6885>0.3000) | 0.6885 | 1.5938 | 0.0000 | 0.226 | 0.2231 | 0.00 | 0.00 | 0.0595 | YES |
| TURN | NO | yaw_ratio(1.2452) | 0.0861 | 0.9653 | 0.8370 | 0.323 | 0.3213 | 0.00 | 0.00 | 0.0072 | YES |
| EXIT | NO | pitch_MAE(0.1071>0.1000) | 0.1071 | 0.6171 | 0.2246 | 0.071 | 0.0486 | 0.00 | 0.00 | 0.0068 | YES |

## Progress / completion / bounds

- Progress: mono=YES n_back=0 min_ds=0.0000 final_s=114.97/115.02 (100.0%) complete=YES
- Stall: run=0.00s (lim 2.00s) stalled=NO | mean ds/dt=1.770 m/s
- Bounded states: YES

## Transitions (peaks)

| Transition | n | max CTE | max |ez| | peak θerr | peak ψerr | peak δe | peak δr | mono | OK |
|---|---:|---:|---:|---:|---:|---:|---:|:---:|:---:|
| ACQ_LEVEL | 88 | 0.262 | 0.250 | 0.020 | 0.000 | 4.86 | 0.00 | YES | YES |
| LEVEL_CLIMB | 88 | 0.209 | 0.224 | 0.228 | 0.000 | 4.69 | 0.00 | YES | YES |
| CLIMB_TURN | 89 | 0.429 | 0.394 | 0.834 | 0.392 | 4.15 | 1.92 | YES | YES |
| TURN_EXIT | 96 | 0.186 | 0.157 | 0.132 | 1.877 | 6.00 | 7.35 | YES | YES |

Lim CTE=1.50 |ez|=1.00

## Actuator regression vs baseline

- Regression OK: **NO** (first=`CLIMB.de_max_deg base=4.5038 cand=4.8301 worse=1`)
- Tol: sat_eps=0.05 pp | rate_eps=0.02 | chat_eps=0.02 | peak_eps=0.25 deg

## PASS gates

| Gate | Status |
|---|:---:|
| production_untouched | PASS |
| no_tuning | PASS |
| no_relaxed_gates | PASS |
| R_min_design>=10 | YES |
| R_min_meas_ok | YES (10.000) |
| one_6dof_run | YES |
| post_ACQ_hard_gates | NO |
| transition_gates | YES |
| completion_bounds | YES |
| no_actuator_regression | NO |

**Overall candidate: FAIL**

## Production mission limitations (shaper line CLOSED)

- Guidance has no segment blender / clothoid / mode switch (baseline audit NOT_IMPLEMENTED).
- External C1 polyline + ACQ + C2 climb + κ-ramps still may fail SPEED_ENVELOPE hard gates on composite mission.
- First fail this run: `CLIMB:pitch_MAE(0.6885>0.3000)`
- Do not continue mission-shaper iterations; document limitation and stop this line.

## Next bounded roadmap gate

- **`CLOSE_MISSION_SHAPER_LINE`** — REJECT transition shaper (production untouched). First=`CLIMB:pitch_MAE(0.6885>0.3000)`. Close mission-shaper line after this single failure; document production mission limitations (no segment blender / clothoid in guidance; composite C1 polyline insufficient for SPEED_ENVELOPE hard gates on multi-segment mission).
- CODEX_VERTICAL_PLAN untouched.
