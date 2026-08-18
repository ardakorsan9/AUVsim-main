# DEPTH_GAMMA_STRUCTURAL_BLOCKER_FIX_001 — Gate-2 attempt 2/3 blocker-fix (delta_alpha + corrected α residual)

**Gate-2 verdict: PARTIAL**  
**Stamp:** 2026-08-08 03:02:03  
**Attempt:** 2/3  
**Blocker:** `secondary_regression_max_20.18%`  
**Next exact task:** `depth_gamma_structural_gate_blocker_fix_attempt3`

## Provenance

- Task sources (exactly 3): `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\DEPTH_GAMMA_STRUCTURAL_GATE.md`, `C:\Users\ardak\MATLAB\Projects\AUVsim-main\guidance_law_depth_gamma_structural.m`, `C:\Users\ardak\MATLAB\Projects\AUVsim-main\run_depth_gamma_structural_gate.m`
- Isolated helper: `C:\Users\ardak\MATLAB\Projects\AUVsim-main\guidance_law_depth_gamma_structural_blocker_fix.m` (production `guidance_law.m` / `controller_law.m` / plant untouched)
- Driver: `run_depth_gamma_structural_blocker_fix.m` (one MATLAB call)
- Artifacts: `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\DEPTH_GAMMA_STRUCTURAL_BLOCKER_FIX.md`, `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\DEPTH_GAMMA_STRUCTURAL_BLOCKER_FIX.mat`, `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\DEPTH_GAMMA_STRUCTURAL_BLOCKER_FIX.png`
- Original Gate-2 artifacts PRESERVED: `suite_results/DEPTH_GAMMA_STRUCTURAL_GATE.{md,mat,png}`
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

- Label: DERIVED Gate-2 blocker-fix: trim-referenced delta_alpha + corrected alpha residual
- (1) Decoupling: theta_cmd = gamma_cmd - delta_alpha; delta_alpha = alpha_sched(mode,U)-alpha_level(U); alpha_sched = blend(alpha_level*, alpha_climb*) IDENTIFIED; gamma = theta_phys + alpha (IMPLEMENTED); level de_trim not double-counted
- Diagnostics: alpha_act = gamma_act - theta_phys (=atan2(w,u)); aMAE = |alpha_act - alpha_sched(U,mode)|; theta plot: theta_phys vs theta_ref distinct; sgtitle padded
- alpha_level*(U): [-0.0742888 -0.0333395 -0.0188097]
- alpha_climb*(U): [-0.10838 -0.0513342 -0.0296065]
- (2) Governor: Feasibility set from elevator |de|<=15.0deg, |de_dot|<=40deg/s, climb-FF |de_ff|<=2.8793deg (k=0.1320695001); Gfh theta/gamma←de DERIVED; clips gamma/theta + rate (PRESERVED)
- (3) AW: AW on depth-I bleed driven by struct_de_mag_res+struct_de_rate_res from controller_law dbg (mag sat) and rate-limit residual; Kaw_struct=8 (PRESERVED)
- (4) Bumpless: Cold-start pitch_out=theta_cmd=gamma-delta_alpha; I=0; alpha_sched_f seeded; production prev_delta_e:=de_trim (PRESERVED mapping)
- Rejected: no gamma INDI/PI/LADRC; no depth PI/NDO replace; no polyline shaper; no gain hunting
- Frozen: pitch_corr=-0.050*z_e_f-0.006*z_e_i; K_gamma=0; K_zdot=0

## Old raw vs corrected-baseline vs candidate

| Set | Primary depth MAE [m] | Improve % | Secondary worse% [th,g,a] | Notes |
|---|---:|---:|---|---|
| Old raw (attempt1 abs-α) | 0.269528→0.232264 | 13.83 | [28.25 -0.13 11.26] | attempt1 absolute alpha injection; alpha MAE scored |alpha| about 0 |
| Corrected-baseline (prod, α residual) | 0.269528 (B only) | — | — | same plant/ctrl; α=γ-θ_phys residual about sched |
| Candidate (delta_α) | 0.269528→0.233640 | 13.32 | [20.18  -6.13 -24.47] | trim-referenced incremental decoupling |

## Envelope / windows

- Elevator |δe|≤15.0deg rate≤40deg/s; climb-FF ≤2.8793deg
- Hard: theta<80deg rates<200deg/s |e_z|<5.0m de_sat<25% de_rate_util<1.05
- Win: settle_t0=5.0s end_frac=0.88 depth_band=±0.25m z0=10.0 Lsm=15.0

## Grid results (corrected-baseline → candidate)

| U | Scenario | zMAE B→C | OS B→C | settle B→C | thMAE | gMAE | aMAE | deSat | gov/AW/bump | hardC |
|---:|---|---:|---:|---:|---:|---:|---:|---:|---|:---:|
| 1.0 | STEP_P2 | 0.3222→0.3637 | 0.112→0.065 | 5.00→5.00 | 1.014→0.977 | 2.489→2.477 | 3.065→2.082 | 0.00→0.00 | 445/36/3 | YES |
| 1.0 | STEP_M2 | 0.3477→0.2424 | 0.653→0.462 | 5.00→5.00 | 0.825→0.718 | 2.040→1.411 | 3.373→2.665 | 0.00→0.00 | 0/36/3 | YES |
| 1.0 | DEPTH_RAMP | 0.2328→0.3784 | 0.000→0.000 | 18.85→NaN | 0.034→0.208 | 0.835→0.656 | 3.225→2.148 | 0.00→0.00 | 222/3/3 | YES |
| 1.0 | X | 0.3134→0.3106 | 0.112→0.065 | 5.00→5.00 | 0.604→0.399 | 1.062→1.294 | 2.938→2.112 | 0.00→0.00 | 0/36/3 | YES |
| 1.0 | XZ | 0.4028→0.4376 | 0.000→0.000 | 5.00→NaN | 0.122→0.338 | 0.695→0.838 | 4.002→2.578 | 0.00→0.00 | 568/0/3 | YES |
| 1.5 | STEP_P2 | 0.0704→0.0354 | 0.056→0.032 | 13.78→13.28 | 0.181→0.295 | 0.859→0.829 | 0.666→0.720 | 0.00→0.00 | 0/9/3 | YES |
| 1.5 | STEP_M2 | 0.3038→0.2726 | 0.549→0.468 | 5.00→5.00 | 0.863→0.807 | 2.010→1.809 | 0.906→0.905 | 0.00→0.00 | 0/9/3 | YES |
| 1.5 | DEPTH_RAMP | 0.2027→0.1756 | 0.000→0.000 | 15.83→12.10 | 0.050→0.075 | 0.755→0.626 | 0.597→0.604 | 0.00→0.00 | 0/0/3 | YES |
| 1.5 | X | 0.2739→0.2661 | 0.010→0.010 | 5.00→5.00 | 0.219→0.216 | 0.591→0.576 | 0.588→0.588 | 0.00→0.00 | 0/9/3 | YES |
| 1.5 | XZ | 0.3915→0.2048 | 0.000→0.000 | 5.00→5.00 | 0.083→0.052 | 0.634→0.279 | 0.736→0.749 | 0.00→0.00 | 0/0/3 | YES |
| 2.0 | STEP_P2 | 0.0543→0.1044 | 0.060→0.137 | 13.28→10.58 | 0.197→0.579 | 0.887→1.378 | 0.212→0.383 | 0.00→0.00 | 6/3/3 | YES |
| 2.0 | STEP_M2 | 0.2909→0.3192 | 0.514→0.499 | 5.00→5.00 | 0.880→0.992 | 2.025→2.301 | 0.583→0.486 | 0.00→0.00 | 6/3/3 | YES |
| 2.0 | DEPTH_RAMP | 0.1900→0.1049 | 0.000→0.000 | 14.73→6.80 | 0.090→0.360 | 0.793→0.687 | 0.364→0.187 | 0.00→0.00 | 0/3/3 | YES |
| 2.0 | X | 0.2595→0.1934 | 0.000→0.002 | 5.00→5.00 | 0.086→0.087 | 0.441→0.351 | 0.246→0.181 | 0.00→0.00 | 0/3/3 | YES |
| 2.0 | XZ | 0.3869→0.0954 | 0.000→0.000 | 5.00→5.00 | 0.084→0.308 | 0.623→0.199 | 0.507→0.235 | 0.00→0.00 | 0/0/3 | YES |

## Promotion / Pareto

| Check | Value |
|---|---|
| Grid complete | YES |
| Primary B→C | 0.269528 → 0.233640 m |
| Primary improve | 13.32% (need ≥5.0%) | YES |
| Abs gates (cand) | YES |
| Secondary worse % [th,g,a] | [20.18  -6.13 -24.47] ok=NO |
| Pareto tracking | 13.32% |
| Pareto actuator_margin | 0.00% |
| Pareto energy | N/A (no power model this gate) |
| Pareto estimation | N/A (Gate 5) |
| Pareto timing | N/A (Gate 6B) |
| Pareto safety | 1 |

## Decision

- Verdict: **PARTIAL**
- Blocker: `secondary_regression_max_20.18%`
- Detail: Gate-2 attempt 2/3 PARTIAL; preserve baseline; blocker=secondary_regression_max_20.18%
- Production: untouched (baseline preserved)
- Original attempt-1 artifacts: preserved

## Trims

- U=1.0 level pass=YES n=1.48e-06 | climb pass=YES n=5.4e-06
- U=1.5 level pass=YES n=2.53e-06 | climb pass=YES n=2.52e-06
- U=2.0 level pass=YES n=1.07e-06 | climb pass=YES n=1.25e-06

## Next

- Exact next task: `depth_gamma_structural_gate_blocker_fix_attempt3`
