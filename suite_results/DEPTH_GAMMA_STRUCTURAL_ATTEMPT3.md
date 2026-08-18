# DEPTH_GAMMA_STRUCTURAL_ATTEMPT3_001 — Gate-2 attempt 3/3 blocker-fix (delta_alpha + corrected α residual)

**Gate-2 verdict: FAIL**  
**Stamp:** 2026-08-08 03:23:53  
**Attempt:** 3/3  
**Blocker:** `primary_KPI_improve_-68.61%_lt_5.0%`  
**Next exact task:** `closed_loop_actuator_realism_gate`

## Provenance

- Task sources (exactly 3): `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\DEPTH_GAMMA_STRUCTURAL_BLOCKER_FIX.md`, `C:\Users\ardak\MATLAB\Projects\AUVsim-main\guidance_law_depth_gamma_structural_blocker_fix.m`, `C:\Users\ardak\MATLAB\Projects\AUVsim-main\run_depth_gamma_structural_blocker_fix.m`
- Isolated helper: `C:\Users\ardak\MATLAB\Projects\AUVsim-main\guidance_law_depth_gamma_structural_attempt3.m` (production `guidance_law.m` / `controller_law.m` / plant untouched)
- Driver: `run_depth_gamma_structural_attempt3.m` (one MATLAB call)
- Artifacts: `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\DEPTH_GAMMA_STRUCTURAL_ATTEMPT3.md`, `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\DEPTH_GAMMA_STRUCTURAL_ATTEMPT3.mat`, `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\DEPTH_GAMMA_STRUCTURAL_ATTEMPT3.png`
- All Gate-2 attempt-1 and attempt-2 artifacts PRESERVED: `suite_results/DEPTH_GAMMA_STRUCTURAL_GATE.{md,mat,png}` and `suite_results/DEPTH_GAMMA_STRUCTURAL_BLOCKER_FIX.{md,mat,png}`
- Seed: 0 | Kp_roll=0.605072 | production depth P+I frozen
- CODEX_VERTICAL_PLAN.md: untouched

## Primary KPI (declared a priori, before run)

| Field | Value |
|---|---|
| Name | `grid_mean_depth_MAE_m` |
| Definition | Mean over full grid {U=1,1.5,2}×{STEP_P2,STEP_M2,DEPTH_RAMP,X,XZ} of steady-window depth MAE |z_veh-z_path| [m] (NED z-down). Lower is better. |
| Improve need | ≥5.0% |
| Secondary max worse | ≤2.0% (non-safety, only if abs gates PASS) |
| Declared before run | YES |

## Structural design

- Label: DERIVED Gate-2 final attempt: minimally-invasive measured-theta reachability governor
- (1) Decoupling: production-equivalent unconstrained theta0 is formed first; incremental delta_alpha is applied only for nonzero path slope and bounded by scheduled |Gfh theta←δe| times available elevator budget; gamma = theta_phys + alpha (IMPLEMENTED)
- Diagnostics: alpha_act = gamma_act - theta_phys (=atan2(w,u)); aMAE = |alpha_act - alpha_sched(U,mode)|; theta plot: theta_phys vs theta_ref distinct; sgtitle padded
- alpha_level*(U): [-0.0742888 -0.0333395 -0.0188097]
- alpha_climb*(U): [-0.10838 -0.0513342 -0.0296065]
- (2) Governor: exact pass-through while predicted elevator magnitude/rate are within |δe|≤15.0deg and |δė|≤40deg/s after trim/climb-FF budget; when threatened, theta0 is constrained to a reachability tube centered on measured theta_phys, then final theta is rate-limited after all decoupling terms
- (3) AW: depth-I bleed uses controller magnitude/rate residual and is inactive when the residual is zero; Kaw_struct=8
- (4) Bumpless: Cold-start pitch_out=theta_cmd=gamma-delta_alpha; I=0; alpha_sched_f seeded; production prev_delta_e:=de_trim (PRESERVED mapping)
- Rejected: no gamma INDI/PI/LADRC; no depth PI/NDO replace; no polyline shaper; no gain hunting
- Frozen: pitch_corr=-0.050*z_e_f-0.006*z_e_i; K_gamma=0; K_zdot=0

## Old raw vs corrected-baseline vs candidate

| Set | Primary depth MAE [m] | Improve % | Secondary worse% [th,g,a] | Notes |
|---|---:|---:|---|---|
| Old raw (attempt1 abs-α) | 0.269528→0.232264 | 13.83 | [28.25 -0.13 11.26] | attempt1 absolute alpha injection; alpha MAE scored |alpha| about 0 |
| Corrected-baseline (prod, α residual) | 0.269528 (B only) | — | — | same plant/ctrl; α=γ-θ_phys residual about sched |
| Candidate (attempt-3 governor) | 0.269528→0.454460 | -68.61 | [-19.21  89.67 -24.33] | bounded slope-only delta-alpha plus minimally-invasive reachability governor |

## Envelope / windows

- Elevator |δe|≤15.0deg rate≤40deg/s; climb-FF ≤2.8793deg
- Hard: theta<80deg rates<200deg/s |e_z|<5.0m de_sat<25% de_rate_util<1.05
- Win: settle_t0=5.0s end_frac=0.88 depth_band=±0.25m z0=10.0 Lsm=15.0

## Grid results (corrected-baseline → candidate)

| U | Scenario | zMAE B→C | OS B→C | settle B→C | thMAE | gMAE | aMAE | deSat | gov/AW/bump | hardC |
|---:|---|---:|---:|---:|---:|---:|---:|---:|---|:---:|
| 1.0 | STEP_P2 | 0.3222→0.7002 | 0.112→0.357 | 5.00→8.08 | 1.014→0.175 | 2.489→4.313 | 3.065→2.208 | 0.00→0.00 | 633/12/3 | YES |
| 1.0 | STEP_M2 | 0.3477→1.6427 | 0.653→0.000 | 5.00→NaN | 0.825→0.180 | 2.040→5.026 | 3.373→2.560 | 0.00→0.00 | 1120/12/3 | YES |
| 1.0 | DEPTH_RAMP | 0.2328→0.7066 | 0.000→0.000 | 18.85→NaN | 0.034→0.288 | 0.835→1.065 | 3.225→2.211 | 0.00→0.00 | 960/9/3 | YES |
| 1.0 | X | 0.3134→0.3982 | 0.112→0.452 | 5.00→5.00 | 0.604→0.141 | 1.062→1.018 | 2.938→2.159 | 0.00→0.00 | 720/12/3 | YES |
| 1.0 | XZ | 0.4028→0.7464 | 0.000→0.000 | 5.00→NaN | 0.122→0.348 | 0.695→1.894 | 4.002→2.628 | 0.00→0.00 | 718/3/3 | YES |
| 1.5 | STEP_P2 | 0.0704→0.7494 | 0.056→0.530 | 13.78→5.00 | 0.181→0.255 | 0.859→5.355 | 0.666→0.539 | 0.00→0.00 | 351/6/3 | YES |
| 1.5 | STEP_M2 | 0.3038→0.5036 | 0.549→1.071 | 5.00→5.00 | 0.863→0.428 | 2.010→3.846 | 0.906→0.979 | 0.00→0.00 | 810/6/3 | YES |
| 1.5 | DEPTH_RAMP | 0.2027→0.1125 | 0.000→0.000 | 15.83→16.40 | 0.050→0.068 | 0.755→2.466 | 0.597→0.558 | 0.00→0.00 | 357/3/3 | YES |
| 1.5 | X | 0.2739→0.2430 | 0.010→0.024 | 5.00→5.00 | 0.219→0.172 | 0.591→0.629 | 0.588→0.598 | 0.00→0.00 | 66/6/3 | YES |
| 1.5 | XZ | 0.3915→0.2085 | 0.000→0.000 | 5.00→5.00 | 0.083→0.046 | 0.634→0.289 | 0.736→0.748 | 0.00→0.00 | 6/0/3 | YES |
| 2.0 | STEP_P2 | 0.0543→0.1033 | 0.060→0.136 | 13.28→10.55 | 0.197→0.590 | 0.887→1.387 | 0.212→0.386 | 0.00→0.00 | 12/3/3 | YES |
| 2.0 | STEP_M2 | 0.2909→0.3215 | 0.514→0.499 | 5.00→5.00 | 0.880→0.991 | 2.025→2.308 | 0.583→0.485 | 0.00→0.00 | 9/3/3 | YES |
| 2.0 | DEPTH_RAMP | 0.1900→0.0954 | 0.000→0.000 | 14.73→10.95 | 0.090→0.255 | 0.793→1.619 | 0.364→0.176 | 0.00→0.00 | 129/3/3 | YES |
| 2.0 | X | 0.2595→0.1888 | 0.000→0.002 | 5.00→5.00 | 0.086→0.070 | 0.441→0.339 | 0.246→0.182 | 0.00→0.00 | 6/3/3 | YES |
| 2.0 | XZ | 0.3869→0.0967 | 0.000→0.000 | 5.00→5.00 | 0.084→0.304 | 0.623→0.196 | 0.507→0.235 | 0.00→0.00 | 3/0/3 | YES |

## Promotion / Pareto

| Check | Value |
|---|---|
| Grid complete | YES |
| Primary B→C | 0.269528 → 0.454460 m |
| Primary improve | -68.61% (need ≥5.0%) | NO |
| Abs gates (cand) | YES |
| Governor distortion bound | 17.1352 deg max |
| Secondary worse % [th,g,a] | [-19.21  89.67 -24.33] ok=NO |
| Pareto tracking | -68.61% |
| Pareto actuator_margin | 0.00% |
| Pareto energy | N/A (no power model this gate) |
| Pareto estimation | N/A (Gate 5) |
| Pareto timing | N/A (Gate 6B) |
| Pareto safety | 1 |

## Decision

- Verdict: **FAIL**
- Blocker: `primary_KPI_improve_-68.61%_lt_5.0%`
- Detail: Gate-2 attempt 3/3 FAIL; method CLOSED; no attempt4; blocker=primary_KPI_improve_-68.61%_lt_5.0%
- Production: untouched (baseline preserved)
- Prior artifacts: preserved
- Method status: **CLOSED_AFTER_3_ATTEMPTS**; no attempt4.
- Residual risk / waiver: Depth improvement remains structurally coupled to theta/gamma/alpha tracking; production stays frozen and any acceptance requires an explicit waiver.

## Trims

- U=1.0 level pass=YES n=1.48e-06 | climb pass=YES n=5.4e-06
- U=1.5 level pass=YES n=2.53e-06 | climb pass=YES n=2.52e-06
- U=2.0 level pass=YES n=1.07e-06 | climb pass=YES n=1.25e-06

## Next

- Exact next task: `closed_loop_actuator_realism_gate`
