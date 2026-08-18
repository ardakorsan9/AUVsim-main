# TRIM_ALPHA_TWO_REPEAT_CLOSURE_001 — Two-repeat corrected e_gamma closure

**Overall verdict: FAIL**

## Provenance

- Read-only: `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\TRIM_ALPHA_FF_RATE_LIMIT.mat`, `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\TRIM_ALPHA_TRANSIENT_GATE_AUDIT.mat`, `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\TRIM_ALPHA_SCHEDULE_ID.mat`
- Isolated helper: `C:\Users\ardak\MATLAB\Projects\AUVsim-main\guidance_law_trim_alpha_ff_rate_limit.m` (production guidance untouched)
- Driver: `run_trim_alpha_two_repeat_closure.m` (one invocation)
- Artifacts: `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\TRIM_ALPHA_TWO_REPEAT_CLOSURE.md`, `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\TRIM_ALPHA_TWO_REPEAT_CLOSURE.mat`, `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\TRIM_ALPHA_TWO_REPEAT_CLOSURE.png`
- Seed: 0 | two repeats | P/U loaded from RATE_LIMIT; candidate re-simulated

## Corrected definitions

```
e_gamma = wrapToPi(gamma_ref - gamma_act); gamma_act=atan2(VD,Uh)
persistent settle: |e_gamma|<=+/-0.50deg through 0.88*s_total
acquisition: fixed first 5.0s & s<0.88*s_total (+ persistent window reported)
steady: t>=5.0s & s<0.88*s_total (last valid path segment)
OS = signed excursion of gamma_act past mean(gamma_ref|ss) during fixed acq
dip = opposite early excursion; attitude e_theta reported separately
actuators: identical fixed acq/steady masks; roll: own-speed phi_eq
Candidate: alpha_ff=c0/u^2+c_g*gamma; |d alpha_cmd/dt|<=2deg/s; Kz=.04 Ki=0; speed PI+FF
c0=0.0750139438014 c_gamma=0.0472912477744 | kD=1.6940741214 Kp=25 Ki=13.83617834
Zeros: within_tol / improve use absolute eps — no % on ~0 base
```

## Determinism

| Route | ok | d_u | d_γMAE | d_θref | d_de |
|-------|:--:|----:|-------:|-------:|-----:|
| X | YES | 0.000e+00 | 0.000e+00 | 0.000e+00 | 0.000e+00 |
| XZ | YES | 0.000e+00 | 0.000e+00 | 0.000e+00 | 0.000e+00 |
| R10 | YES | 0.000e+00 | 0.000e+00 | 0.000e+00 | 0.000e+00 |

Overall repeats: **PASS**

## Corrected table — P / U / C (candidate)

| Route | uMAE | uP95 | γMAE_ss° | γΔ%P/U | CTE | CTEΔ%P/U | settle[s] | acqMAE° | OS° | dip° | acq RMS/p95/max° |
|-------|-----:|-----:|---------:|--------:|----:|---------:|----------:|--------:|----:|-----:|-----------------:|
| X | 0.3176/0.0008/0.0006 | 0.0022 | 0.331/0.394/0.290 | +12.2/+26.3 | 0.2467/0.2903/0.0235 | +90.5/+91.9 | 7.350/9.925/7.375 | 1.233/1.540/0.883 | 0.000/0.000/0.719 | 1.747/2.275/1.850 | 1.058/1.890/1.917 |
| XZ | 0.2551/0.0015/0.0014 | 0.0066 | 0.443/0.711/0.384 | +13.3/+46.1 | 0.3953/0.5507/0.1238 | +68.7/+77.5 | NaN/NaN/8.650 | 2.119/3.181/2.035 | 0.000/0.000/0.802 | 3.650/4.857/4.262 | 2.521/4.292/4.335 |
| R10 | 0.3478/0.0038/0.0033 | 0.0276 | 0.597/1.079/0.144 | +75.8/+86.6 | 0.2759/0.3979/0.2096 | +24.0/+47.3 | 39.000/NaN/3.325 | 1.527/2.162/0.981 | 0.000/0.000/0.206 | 1.901/2.625/2.033 | 1.232/2.085/2.101 |

## Attitude (separate) / own-eq roll / actuators

| Route | θsettle P/U/C | θMAE_ss | yaw P→C | ownT P→C | φeq° | deR_ss P→C | deR_acq | drR_ss | satT% | chatter |
|-------|--------------:|--------:|--------:|---------:|-----:|-----------:|--------:|-------:|------:|:-------:|
| X | 1.675/5.350/6.100 | 0.011/0.191/0.265 | 0.0000→0.0000 | 0.0000→0.0000 | 0.000 | 0.003487→0.001407 | 0.09299→0.1002 | 0→0 | 0.00 | YES |
| XZ | 6.175/5.950/5.750 | 0.154/0.165/0.136 | 0.0000→0.0000 | 0.0000→0.0000 | 0.000 | 0.004156→0.003261 | 0.09052→0.1059 | 0→0 | 0.00 | YES |
| R10 | 2.225/9.325/2.975 | 0.030/0.182/0.111 | 0.1747→0.1361 | 0.3861→0.2597 | 0.854 | 0.003667→0.001119 | 0.09171→0.09899 | 0.6712→0.6499 | 0.00 | YES |

## Gate table

| Gate | Result | Detail |
|------|:------:|--------|
| Repeats deterministic | YES | |
| u MAE≤0.07 p95≤0.10 | YES | X=YES XZ=YES H=YES |
| Steady γ ≥5% vs P and ≥10% vs U | YES | X ΔP/U=+12.2/+26.3 XZ=+13.3/+46.1 H=+75.8/+86.6 |
| Steady CTE ≥5% vs P and ≥10% vs U | YES | X ΔP/U=+90.5/+91.9 XZ=+68.7/+77.5 H=+24.0/+47.3 |
| Persistent settling improve each route | NO | X/XZ/H setΔ=-0.3/NaN/+91.5% |
| Acq MAE improve each route | YES | X/XZ/H acqΔ=+28.4/+3.9/+35.8% |
| dip/p95/max not >2% worse vs P | NO | |
| Actuator RMS/rate not >2% worse | NO | |
| Yaw/roll not >2% worse (own-eq) | YES | |
| Sat≤1% / no chatter | YES | |

## Evidence

- Determinism: PASS
- repeat: X ok=1 d_u=0.000e+00 d_g=0.000e+00 d_th=0.000e+00 d_de=0.000e+00
- repeat: XZ ok=1 d_u=0.000e+00 d_g=0.000e+00 d_th=0.000e+00 d_de=0.000e+00
- repeat: R10 ok=1 d_u=0.000e+00 d_g=0.000e+00 d_th=0.000e+00 d_de=0.000e+00
- X uMAE=0.0006 p95=0.0022 | γMAE P/U/C=0.331/0.394/0.290 (ΔP=+12.2% ΔU=+26.3%) | CTE P/U/C=0.2467/0.2903/0.0235 (ΔP=+90.5% ΔU=+91.9%)
- X settle P→C 7.350→7.375 (-0.3%) acqMAE 1.233→0.883 (+28.4%) dip 1.747→1.850 OS 0.000→0.719
- X act deR_ss 0.003487→0.001407 deR_acq 0.09299→0.1002 drR_ss 0→0 | yaw 0.0000→0.0000 ownT 0.0000→0.0000 satT=0.00% chatter=0
- XZ uMAE=0.0014 p95=0.0066 | γMAE P/U/C=0.443/0.711/0.384 (ΔP=+13.3% ΔU=+46.1%) | CTE P/U/C=0.3953/0.5507/0.1238 (ΔP=+68.7% ΔU=+77.5%)
- XZ settle P→C NaN→8.650 (NaN%) acqMAE 2.119→2.035 (+3.9%) dip 3.650→4.262 OS 0.000→0.802
- XZ act deR_ss 0.004156→0.003261 deR_acq 0.09052→0.1059 drR_ss 0→0 | yaw 0.0000→0.0000 ownT 0.0000→0.0000 satT=0.00% chatter=0
- R10 uMAE=0.0033 p95=0.0276 | γMAE P/U/C=0.597/1.079/0.144 (ΔP=+75.8% ΔU=+86.6%) | CTE P/U/C=0.2759/0.3979/0.2096 (ΔP=+24.0% ΔU=+47.3%)
- R10 settle P→C 39.000→3.325 (+91.5%) acqMAE 1.527→0.981 (+35.8%) dip 1.901→2.033 OS 0.000→0.206
- R10 act deR_ss 0.003667→0.001119 deR_acq 0.09171→0.09899 drR_ss 0.6712→0.6499 | yaw 0.1747→0.1361 ownT 0.3861→0.2597 satT=0.00% chatter=0
- gates det/u/γ/CTE/set/acq/peak/act/yr/sat=1/1/1/1/0/1/0/0/1/1

## Decision

- Verdict: **FAIL**
- Next: `alpha_cmd_soft_start_cosine_1deg_s`
- Detail: FAIL leave production unchanged. Fail: persistent settling not improve vs P, dip/p95/max >2% worse vs P, actuator RMS/rate >2% worse vs P. One final bounded reference shaper: alpha_cmd soft-start cosine envelope with |dα/dt|≤1deg/s (half of current 2deg/s); hold schedule/gains fixed; stop further shaping.
- Production: untouched

## Feedback

- PASS/FAIL: **FAIL**
- Corrected γMAE° P/U/C: X 0.331/0.394/0.290 | XZ 0.443/0.711/0.384 | R10 0.597/1.079/0.144
- Files: `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\TRIM_ALPHA_TWO_REPEAT_CLOSURE.md` `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\TRIM_ALPHA_TWO_REPEAT_CLOSURE.mat` `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\TRIM_ALPHA_TWO_REPEAT_CLOSURE.png`
- Next: `alpha_cmd_soft_start_cosine_1deg_s`
