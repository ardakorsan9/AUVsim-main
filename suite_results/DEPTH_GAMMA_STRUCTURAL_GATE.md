# DEPTH_GAMMA_STRUCTURAL_GATE_001 — Gate-2 structural depth/γ decoupling+governor+AW

**Gate-2 verdict: PARTIAL**  
**Stamp:** 2026-08-08 02:38:40  
**Blocker:** `secondary_regression_max_28.25%`  
**Next exact task:** `depth_gamma_structural_gate_blocker_fix`

## Provenance

- Task sources (exactly 3): `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\DEPTH_GAMMA_SPEED_SCHEDULED_ID.md`, `C:\Users\ardak\MATLAB\Projects\AUVsim-main\controller_law.m`, `C:\Users\ardak\MATLAB\Projects\AUVsim-main\continuous_path_tracking.m`
- Isolated helper: `C:\Users\ardak\MATLAB\Projects\AUVsim-main\guidance_law_depth_gamma_structural.m` (production `guidance_law.m` / `controller_law.m` / plant untouched)
- Driver: `run_depth_gamma_structural_gate.m` (one MATLAB call)
- Artifacts: `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\DEPTH_GAMMA_STRUCTURAL_GATE.md`, `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\DEPTH_GAMMA_STRUCTURAL_GATE.mat`, `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\DEPTH_GAMMA_STRUCTURAL_GATE.png`
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

- Label: DERIVED from DEPTH_GAMMA_SPEED_SCHEDULED_ID level/climb U={1,1.5,2}
- (1) Decoupling: theta_cmd = gamma_cmd - alpha_sched(U,mode); alpha_sched = blend(alpha_level*, alpha_climb*) IDENTIFIED; gamma = theta_phys + alpha (IMPLEMENTED convention)
- alpha_level*(U): [-0.0742888 -0.0333395 -0.0188097]
- alpha_climb*(U): [-0.10838 -0.0513342 -0.0296065]
- (2) Governor: Feasibility set from elevator |de|<=15.0deg, |de_dot|<=40deg/s, climb-FF |de_ff|<=2.8793deg (k=0.1320695001); Gfh theta/gamma←de DERIVED; clips gamma/theta + rate
- (3) AW: AW on depth-I bleed driven by struct_de_mag_res+struct_de_rate_res from controller_law dbg (mag sat) and rate-limit residual; Kaw_struct=8 (TUNED isolated)
- (4) Bumpless: Cold-start pitch_out=theta_cmd=gamma_path-alpha_sched; I=0; alpha_sched_f seeded; production prev_delta_e:=de_trim (IMPLEMENTED)
- Rejected: no gamma INDI/PI/LADRC; no depth PI/NDO replace; no polyline shaper; no gain hunting
- Frozen: pitch_corr=-0.050*z_e_f-0.006*z_e_i; K_gamma=0; K_zdot=0

## Envelope / windows

- Elevator |δe|≤15.0deg rate≤40deg/s; climb-FF ≤2.8793deg
- Hard: theta<80deg rates<200deg/s |e_z|<5.0m de_sat<25% de_rate_util<1.05
- Win: settle_t0=5.0s end_frac=0.88 depth_band=±0.25m z0=10.0 Lsm=15.0

## Grid results (baseline → candidate)

| U | Scenario | zMAE B→C | OS B→C | settle B→C | thMAE | gMAE | aMAE | deSat | gov/AW/bump | hardC |
|---:|---|---:|---:|---:|---:|---:|---:|---:|---|:---:|
| 1.0 | STEP_P2 | 0.3222→0.3323 | 0.112→0.549 | 5.00→7.35 | 1.014→0.967 | 2.489→1.695 | 1.495→2.438 | 0.00→0.00 | 226/12/3 | YES |
| 1.0 | STEP_M2 | 0.3477→0.5028 | 0.653→0.000 | 5.00→5.00 | 0.825→0.703 | 2.040→2.148 | 1.182→1.878 | 0.00→0.00 | 469/12/3 | YES |
| 1.0 | DEPTH_RAMP | 0.2328→0.3271 | 0.000→0.000 | 18.85→5.00 | 0.034→0.157 | 0.835→1.130 | 1.644→2.712 | 0.00→0.00 | 0/0/3 | YES |
| 1.0 | X | 0.3134→0.3548 | 0.112→0.399 | 5.00→5.00 | 0.604→0.068 | 1.062→0.578 | 1.318→2.185 | 0.00→0.00 | 0/12/3 | YES |
| 1.0 | XZ | 0.4028→0.3353 | 0.000→0.000 | 5.00→5.00 | 0.122→0.265 | 0.695→0.696 | 2.208→3.629 | 0.00→0.00 | 880/0/3 | YES |
| 1.5 | STEP_P2 | 0.0704→0.2467 | 0.056→0.385 | 13.78→5.00 | 0.181→0.906 | 0.859→2.066 | 1.244→1.434 | 0.00→0.00 | 0/6/3 | YES |
| 1.5 | STEP_M2 | 0.3038→0.2067 | 0.549→0.107 | 5.00→5.00 | 0.863→0.818 | 2.010→1.890 | 1.176→1.126 | 0.00→0.00 | 0/6/3 | YES |
| 1.5 | DEPTH_RAMP | 0.2027→0.1590 | 0.000→0.000 | 15.83→5.00 | 0.050→0.281 | 0.755→0.842 | 1.637→1.605 | 0.00→0.00 | 0/0/3 | YES |
| 1.5 | X | 0.2739→0.1054 | 0.010→0.113 | 5.00→5.00 | 0.219→0.068 | 0.591→0.113 | 1.322→1.298 | 0.00→0.00 | 0/6/3 | YES |
| 1.5 | XZ | 0.3915→0.1410 | 0.000→0.000 | 5.00→5.00 | 0.083→0.160 | 0.634→0.390 | 2.205→2.170 | 0.00→0.00 | 0/0/3 | YES |
| 2.0 | STEP_P2 | 0.0543→0.2838 | 0.060→0.388 | 13.28→9.48 | 0.197→0.841 | 0.887→2.149 | 1.226→0.639 | 0.00→0.00 | 0/3/3 | YES |
| 2.0 | STEP_M2 | 0.2909→0.1875 | 0.514→0.245 | 5.00→10.03 | 0.880→0.702 | 2.025→1.646 | 1.177→1.077 | 0.00→0.00 | 6/3/3 | YES |
| 2.0 | DEPTH_RAMP | 0.1900→0.1412 | 0.000→0.000 | 14.73→5.00 | 0.090→0.500 | 0.793→0.938 | 1.636→1.072 | 0.00→0.00 | 0/3/3 | YES |
| 2.0 | X | 0.2595→0.0372 | 0.000→0.041 | 5.00→5.00 | 0.086→0.017 | 0.441→0.046 | 1.323→0.877 | 0.00→0.00 | 0/3/3 | YES |
| 2.0 | XZ | 0.3869→0.1232 | 0.000→0.000 | 5.00→5.00 | 0.084→0.387 | 0.623→0.389 | 2.203→1.446 | 0.00→0.00 | 0/0/3 | YES |

## Promotion / Pareto

| Check | Value |
|---|---|
| Grid complete | YES |
| Primary B→C | 0.269528 → 0.232264 m |
| Primary improve | 13.83% (need ≥5.0%) | YES |
| Abs gates (cand) | YES |
| Secondary worse % [th,g,a] | [28.25 -0.13 11.26] ok=NO |
| Pareto tracking | 13.83% |
| Pareto actuator_margin | 0.00% |
| Pareto energy | N/A (no power model this gate) |
| Pareto estimation | N/A (Gate 5) |
| Pareto timing | N/A (Gate 6B) |
| Pareto safety | 1 |

## Decision

- Verdict: **PARTIAL**
- Blocker: `secondary_regression_max_28.25%`
- Detail: Gate-2 PARTIAL; preserve baseline; blocker=secondary_regression_max_28.25%
- Production: untouched (baseline preserved)

## Trims

- U=1.0 level pass=YES n=1.48e-06 | climb pass=YES n=5.4e-06
- U=1.5 level pass=YES n=2.53e-06 | climb pass=YES n=2.52e-06
- U=2.0 level pass=YES n=1.07e-06 | climb pass=YES n=1.25e-06

## Next

- Exact next task: `depth_gamma_structural_gate_blocker_fix`
