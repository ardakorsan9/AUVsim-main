# TRIM_ALPHA_TRANSIENT_GATE_AUDIT_001 — Trim-alpha transient gate raw-metric audit

**Overall verdict: PASS** | **class: METRIC_BUG**

## Provenance

- Read-only: `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\TRIM_ALPHA_FF_RATE_LIMIT.mat`, `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\TRIM_ALPHA_FF_BENCHMARK.mat`, `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\PITCH_FLIGHTPATH_SEMANTICS_AUDIT.mat`
- Driver: `run_trim_alpha_transient_gate_audit.m` (one invocation; no sim; production untouched)
- Artifacts: `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\TRIM_ALPHA_TRANSIENT_GATE_AUDIT.md`, `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\TRIM_ALPHA_TRANSIENT_GATE_AUDIT.mat`, `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\TRIM_ALPHA_TRANSIENT_GATE_AUDIT.png`
- AFF identity cross-check: MATCH

## Definitions (stated)

```
e_gamma = wrapToPi(gamma_ref - gamma_act); gamma_act=atan2(VD,Uh); gamma_ref=atan2(tz,||txy||)
e_theta_att = wrapToPi(theta_ref - theta_phys); attitude tracker error (legacy)
e_theta_req = wrapToPi((gamma_ref-alpha) - theta_phys); required-attitude error
persistent: earliest t_k s.t. |e|<=+/-0.50 deg for all samples with s < 0.88*s_total from k..n_end (enter band and remain)
OS = max(0, signed excursion of signal past mean(ref|steady)) during acq [deg]
initial_dip = max(0, opposite excursion vs final ref during first acq third) [deg]
t10_90 = time for signal to traverse 10%%→90%% of (final_ref - start) [s]; lag=first enter band
PRIOR BUG: PRIOR RATE_LIMIT/AFF: settle/OS from compute_pitch_window_metrics(e_theta_att); OS:=acq |e_theta| peak — mixes legacy attitude with gamma gates
Zeros: within_tol / improve use absolute eps (rate 1e-6, ang 1e-3) — no % on ~0 base
```

## Corrected table — e_gamma persistent (band ±0.50°) P/A04/AFF/RL

| Route | settle[s] | OS° vs γ_ref_ss | dip° | 10-90[s] | lag[s] | γMAE_ss° | γ signed/RMS/p95/max° |
|-------|----------:|---------------:|-----:|---------:|-------:|---------:|----------------------:|
| X | 7.350/4.075/7.375/7.375 | 0.000/0.000/0.768/0.720 | 1.747/2.220/1.473/1.850 | 0.500/0.175/0.075/0.075 | 0.000/0.000/0.000/0.000 | 0.262/0.310/0.190/0.215 | -0.215/0.249/0.451/0.500 |
| XZ | NaN/13.625/8.475/8.650 | 0.000/0.502/0.899/0.885 | 3.650/4.783/3.448/4.262 | 0.475/0.100/0.050/0.050 | 0.000/0.000/0.000/0.000 | 0.443/0.446/0.240/0.295 | -0.295/0.311/0.468/0.499 |
| R10 | 39.000/6.250/2.875/3.325 | 0.913/0.000/0.000/0.000 | 1.908/2.598/1.580/2.017 | 0.500/0.175/0.150/0.150 | 0.000/0.000/0.000/0.000 | 0.318/0.299/0.119/0.145 | -0.136/0.196/0.432/0.496 |

## Attitude error (separate) — persistent |e_θ_att|

| Route | θ_settle[s] P/A04/AFF/RL | θ_OS° | θ_MAE_ss° | prior settle (eth) | prior OS=|eθ|peak |
|-------|-------------------------:|------:|----------:|-------------------:|-------------------:|
| X | 1.675/2.150/6.725/6.100 | 0.000/0.000/0.894/0.770 | 0.035/0.230/0.266/0.238 | 2.650/3.125/3.125/3.350 | 0.620/0.866/2.058/1.498 |
| XZ | 6.175/3.425/6.150/5.750 | 0.000/0.000/0.885/0.744 | 0.121/0.076/0.174/0.117 | 6.175/3.425/6.150/5.750 | 1.754/2.503/3.977/3.350 |
| R10 | 2.225/2.900/2.650/2.975 | 0.000/0.000/0.000/0.000 | 0.041/0.083/0.137/0.116 | 2.225/2.900/2.650/2.975 | 0.703/1.042/2.269/1.769 |

## Actuators — elevator/rudder RMS & rate RMS (γ-windows)

| Route | deRate_ss P/AFF/RL | deRate_acq P/AFF/RL | drRate_ss | drRate_acq | de_rms_ss | de_rms_acq |
|-------|-------------------:|--------------------:|----------:|-----------:|----------:|-----------:|
| X | 0.003187/0.000688/0.0006891 | 0.07655/0.05089/0.08233 | 0/0/0 | 0/0/0 | 0.0833/0.1149/0.1149 | 0.08423/0.1123/0.1128 |
| XZ | 0.004156/0.0005913/0.0006431 | 0.09052/0.06875/0.08042 | 0/0/0 | 0/0/0 | 0.02226/0.01958/0.01939 | 0.03909/0.03927/0.03991 |
| R10 | 0.002393/0.002043/0.001791 | 0.03295/0.07143/0.121 | 0.6706/0.6508/0.6513 | 0.6703/0.6325/0.6411 | 0.09747/0.1524/0.1525 | 0.09633/0.09978/0.1058 |

## Gate boolean verification (≤2% / ≥10%; zeros→abs tol)

| Route | prior vsAFF | prior settle≤2%P | prior act≤2%P | de_ss/acq/dr_ss/acq | corr vsAFF | corr settle | corr act | valid% | bool match |
|-------|:-----------:|:-----------------:|:--------------:|--------------------:|:----------:|:-----------:|:--------:|--------:|:----------:|
| X | NO (-7.2/+27.2%) | NO | YES | 1/1/1/1 | NO (+0.0/+6.2%) | NO | NO | 100.0 | YES |
| XZ | NO (+6.5/+15.8%) | NO | NO | 1/0/1/1 | NO (-2.1/+1.5%) | NO | YES | 100.0 | YES |
| R10 | NO (-12.3/+22.0%) | NO | YES | 1/1/1/1 | NO (-15.7/NaN%) | YES | NO | 100.0 | YES |

## Classification

- Class: **METRIC_BUG**
- eth-peak OS identity: YES | frame_mix: YES | act_FAIL despite steady improve: YES
- Corrected gates all vsAFF/settle/act: NO/NO/NO
- Audit PASS criteria: valid≥95%, defs OK, booleans consistent with numeric rules; does **not** promote controller

## Evidence

- AFF series identity RL.mat vs BENCHMARK.mat: MATCH
- Settle band stated: +/-0.50 deg persistent; end_frac=0.88
- Prior OS = acq |e_theta_att| peak (not OS vs final gamma_ref)
- Prior settle/OS windows from e_theta_att (X:first_hold; XZ/H:persistent)
- X prior act_ok=1 (de_ss 1 de_acq 1 dr_ss 1 dr_acq 1) steady_de P→RL 0.003487→0.001407 acq_de 0.1273→0.122
- X prior set/OS AFF→RL 3.125→3.350 / 2.058→1.498 (imp -7.2/+27.2%); corr γ set/OS 7.375→7.375 / 0.768→0.720 (imp +0.0/+6.2%)
- XZ prior act_ok=0 (de_ss 1 de_acq 0 dr_ss 1 dr_acq 1) steady_de P→RL 0.00397→0.001541 acq_de 0.0813→0.09861
- XZ prior set/OS AFF→RL 6.150→5.750 / 3.977→3.350 (imp +6.5/+15.8%); corr γ set/OS 8.475→8.650 / 0.899→0.885 (imp -2.1/+1.5%)
- R10 prior act_ok=1 (de_ss 1 de_acq 1 dr_ss 1 dr_acq 1) steady_de P→RL 0.00404→0.002123 acq_de 0.1369→0.1278
- R10 prior set/OS AFF→RL 2.650→2.975 / 2.269→1.769 (imp -12.3/+22.0%); corr γ set/OS 2.875→3.325 / 0.000→0.000 (imp -15.7/NaN%)
- class=METRIC_BUG | corr gates vsAFF/settle/act=0/0/0 | frame_mix=1 act_paradox=1 eth_peak_OS=1

## Decision

- Verdict: **PASS**
- Class: **METRIC_BUG**
- Next: `two_repeat_closure_egamma_persistent_gates`
- Detail: METRIC_BUG: prior settle/OS gated on legacy e_theta (OS=|e_θ| peak); actuator acq windows coupled to e_θ settle so steady-rate improve still FAIL. Corrected two-repeat closure: gate settle/OS on persistent |e_gamma|<=0.5deg; OS vs mean(gamma_ref|steady); actuator rates on gamma-derived (or fixed) windows; zeros use abs tol. Do not promote until two-repeat with corrected gates. Note: corrected gamma gates may still FAIL some settle/OS rows — closure must report both; do not treat prior eth-OS as evidence of shaping need.
- Production: untouched (audit does not promote)

## Feedback

- PASS/FAIL: **PASS**
- Class: **METRIC_BUG**
- Next: `two_repeat_closure_egamma_persistent_gates`
- Files: `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\TRIM_ALPHA_TRANSIENT_GATE_AUDIT.md` `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\TRIM_ALPHA_TRANSIENT_GATE_AUDIT.mat` `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\TRIM_ALPHA_TRANSIENT_GATE_AUDIT.png`
