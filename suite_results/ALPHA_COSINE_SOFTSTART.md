# ALPHA_COSINE_SOFTSTART_001 — Half-cosine 1deg/s trim-alpha soft-start

**Overall verdict: FAIL**

## Provenance

- Read-only: `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\TRIM_ALPHA_TWO_REPEAT_CLOSURE.mat`, `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\TRIM_ALPHA_FF_RATE_LIMIT.mat`, `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\TRIM_ALPHA_TRANSIENT_GATE_AUDIT.mat`
- Isolated helper: `C:\Users\ardak\MATLAB\Projects\AUVsim-main\guidance_law_trim_alpha_ff_cosine_softstart.m` (production guidance untouched)
- Driver: `run_alpha_cosine_softstart.m` (one invocation)
- Artifacts: `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\ALPHA_COSINE_SOFTSTART.md`, `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\ALPHA_COSINE_SOFTSTART.mat`, `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\ALPHA_COSINE_SOFTSTART.png`
- Seed: 0 | P/RL from TWO_REPEAT_CLOSURE; cosine candidate re-simulated

## Exact shaping equation

```
alpha_ff = c0/max(u_ref,u_min)^2 + c_gamma*gamma_path; clamp +/-8deg
at reset: alpha0=alpha_ff(0); Tsoft=pi*|alpha0|/(2*deg2rad(1))
  alpha0~0 => Tsoft=0, skip soft-start (safe)
t<=Tsoft: alpha_cmd = alpha0/2*(1-cos(pi*t/Tsoft))   % peak |dα/dt|=1deg/s
t>Tsoft:  |d alpha_cmd/dt| <= 1deg/s toward alpha_ff (symmetric slew)
pitch_raw = gamma_path + pitch_corr + alpha_cmd   (NO LPF)
e_gamma = wrapToPi(gamma_ref - gamma_act); gamma_act=atan2(VD,Uh)
persistent settle: |e_gamma|<=+/-0.50deg through 0.88*s_total
acquisition: fixed first 5.0s & s<0.88*s_total; steady: t>=5.0s & s<0.88*s_total
UNCHANGED: schedule c0=0.0750139438014 c_gamma=0.0472912477744 | Kz=.04 Ki=0 | speed PI+FF
kD=1.6940741214 Kp=25 Ki=13.83617834 | compare P / RL(2deg/s) / CS(cosine)
Zeros: within_tol / improve use absolute eps — no % on ~0 base
```

## Corrected table — P / RL(2°/s) / CS(cosine)

| Route | uMAE | uP95 | γMAE_ss° | γΔ%P/U | CTE | CTEΔ%P/U | settle[s] | acqMAE° | OS° | dip° | acq RMS/p95/max° |
|-------|-----:|-----:|---------:|--------:|----:|---------:|----------:|--------:|----:|-----:|-----------------:|
| X | 0.3176/0.0006/0.0008 | 0.0036 | 0.331/0.290/0.367 | -11.1/+6.8 | 0.2467/0.0235/0.0368 | +85.1/+87.3 | 7.350/7.375/8.500 | 1.233/0.883/1.108 | 0.000/0.719/0.680 | 1.747/1.850/2.189 | 1.336/2.239/2.256 |
| XZ | 0.2551/0.0014/0.0017 | 0.0097 | 0.443/0.384/0.494 | -11.7/+30.5 | 0.3953/0.1238/0.2006 | +49.2/+63.6 | NaN/8.650/12.125 | 2.119/2.035/2.621 | 0.000/0.802/0.288 | 3.650/4.262/4.769 | 3.090/4.811/4.841 |
| R10 | 0.3478/0.0033/0.0035 | 0.0294 | 0.597/0.144/0.212 | +64.5/+80.3 | 0.2759/0.2096/0.2219 | +19.6/+44.2 | 39.000/3.325/10.700 | 1.527/0.981/1.529 | 0.000/0.206/0.000 | 1.901/2.033/2.502 | 1.722/2.560/2.574 |

## Attitude / own-eq roll / actuators / alpha rate

| Route | θsettle P/RL/CS | θMAE_ss | yaw P→CS | ownT P→CS | φeq° | deR_ss P→CS | deR_acq | drR_ss | satT% | αrate°/s | chatter |
|-------|----------------:|--------:|---------:|----------:|-----:|------------:|--------:|-------:|------:|---------:|:-------:|
| X | 1.675/6.100/6.325 | 0.011/0.265/0.262 | 0.0000→0.0000 | 0.0000→0.0000 | 0.000 | 0.003487→0.002326 | 0.09299→0.09707 | 0→0 | 0.00 | 0.999 | YES |
| XZ | 6.175/5.750/3.725 | 0.154/0.136/0.102 | 0.0000→0.0000 | 0.0000→0.0000 | 0.000 | 0.004156→0.004462 | 0.09052→0.09647 | 0→0 | 0.00 | 1.000 | YES |
| R10 | 2.225/2.975/3.350 | 0.030/0.111/0.105 | 0.1747→0.1358 | 0.3861→0.2400 | 0.854 | 0.003667→0.001423 | 0.09171→0.09844 | 0.6712→0.6506 | 0.00 | 1.000 | YES |

## Gate table

| Gate | Result | Detail |
|------|:------:|--------|
| Prior closure / load ok | YES | |
| u MAE≤0.07 p95≤0.10 | YES | X=YES XZ=YES H=YES |
| Steady γ ≥5% vs P and ≥10% vs U | NO | X ΔP/U=-11.1/+6.8 XZ=-11.7/+30.5 H=+64.5/+80.3 |
| Steady CTE ≥5% vs P and ≥10% vs U | YES | X ΔP/U=+85.1/+87.3 XZ=+49.2/+63.6 H=+19.6/+44.2 |
| Persistent settling improve each route | NO | X/XZ/H setΔ=-15.6/NaN/+72.6% |
| Acq MAE improve each route | NO | X/XZ/H acqΔ=+10.1/-23.7/-0.1% |
| dip/p95/max not >2% worse vs P | NO | |
| Actuator RMS/rate not >2% worse | NO | |
| Yaw/roll not >2% worse (own-eq) | YES | |
| Sat≤1% / no chatter | YES | |

## Evidence

- Determinism: PASS
- note: loaded prior TWO_REPEAT_CLOSURE determinism PASS; cosine single-pass
- X uMAE=0.0008 p95=0.0036 | γMAE P/RL/CS=0.331/0.290/0.367 (ΔP=-11.1% ΔU=+6.8%) | CTE P/RL/CS=0.2467/0.0235/0.0368 (ΔP=+85.1% ΔU=+87.3%)
- X settle P→CS 7.350→8.500 (-15.6%) acqMAE 1.233→1.108 (+10.1%) dip 1.747→2.189 OS 0.000→0.680 | RL set/acq 7.375/0.883
- X act deR_ss 0.003487→0.002326 deR_acq 0.09299→0.09707 drR_ss 0→0 | yaw 0.0000→0.0000 ownT 0.0000→0.0000 satT=0.00% chatter=0 aRate=0.999
- XZ uMAE=0.0017 p95=0.0097 | γMAE P/RL/CS=0.443/0.384/0.494 (ΔP=-11.7% ΔU=+30.5%) | CTE P/RL/CS=0.3953/0.1238/0.2006 (ΔP=+49.2% ΔU=+63.6%)
- XZ settle P→CS NaN→12.125 (NaN%) acqMAE 2.119→2.621 (-23.7%) dip 3.650→4.769 OS 0.000→0.288 | RL set/acq 8.650/2.035
- XZ act deR_ss 0.004156→0.004462 deR_acq 0.09052→0.09647 drR_ss 0→0 | yaw 0.0000→0.0000 ownT 0.0000→0.0000 satT=0.00% chatter=0 aRate=1.000
- R10 uMAE=0.0035 p95=0.0294 | γMAE P/RL/CS=0.597/0.144/0.212 (ΔP=+64.5% ΔU=+80.3%) | CTE P/RL/CS=0.2759/0.2096/0.2219 (ΔP=+19.6% ΔU=+44.2%)
- R10 settle P→CS 39.000→10.700 (+72.6%) acqMAE 1.527→1.529 (-0.1%) dip 1.901→2.502 OS 0.000→0.000 | RL set/acq 3.325/0.981
- R10 act deR_ss 0.003667→0.001423 deR_acq 0.09171→0.09844 drR_ss 0.6712→0.6506 | yaw 0.1747→0.1358 ownT 0.3861→0.2400 satT=0.00% chatter=0 aRate=1.000
- gates det/u/γ/CTE/set/acq/peak/act/yr/sat=1/1/0/1/0/0/0/0/1/1

## Decision

- Verdict: **FAIL**
- Next: `outer_gamma_loop_INDI_audit`
- Detail: FAIL leave production unchanged. Fail: steady gamma <5% vs P or <10% vs U, persistent settling not improve vs P, acq MAE not improve vs P, dip/p95/max >2% worse vs P, actuator RMS/rate >2% worse vs P. Stop trim-alpha shaping; advance to outer gamma-loop/INDI audit.
- Production: untouched

## Feedback

- PASS/FAIL: **FAIL**
- Corrected γMAE° P/RL/CS: X 0.331/0.290/0.367 | XZ 0.443/0.384/0.494 | R10 0.597/0.144/0.212
- Equation: `α0=α_ff(0); Tsoft=π|α0|/(2·1°/s); t≤Tsoft: α=α0/2(1-cos(πt/Tsoft)); else |dα/dt|≤1°/s`
- Files: `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\ALPHA_COSINE_SOFTSTART.md` `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\ALPHA_COSINE_SOFTSTART.mat` `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\ALPHA_COSINE_SOFTSTART.png`
- Next: `outer_gamma_loop_INDI_audit`
