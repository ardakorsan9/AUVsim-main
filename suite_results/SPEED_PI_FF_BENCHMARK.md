# SPEED_PI_FF_BENCHMARK_001 — Speed-ref quadratic-drag FF + AW-PI benchmark

**Overall verdict: FAIL**

## Provenance

- Read-only: `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\THRUST_TRIM_U15_AUDIT.mat`, `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\SPEED_BASELINE_AUDIT.mat`, `C:\Users\ardak\MATLAB\Projects\AUVsim-main\controller_law.m`
- Driver: `run_speed_pi_ff_benchmark.m` (one invocation; production untouched)
- Artifacts: `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\SPEED_PI_FF_BENCHMARK.md`, `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\SPEED_PI_FF_BENCHMARK.mat`, `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\SPEED_PI_FF_BENCHMARK.png`
- Seed: 0 | Kp_roll frozen=0.605072

## Equations / gains / poles

```
Baseline: thrust = sat(thrust_trim + Kp_x*(u_ref_eff - u))
Candidate: Tff=kD*u_ref_eff*|u_ref_eff|; Tunsat=Tff+Kp*(u_ref_eff-u)+I; T=sat(Tunsat); I+=Ki*e*dt + Kaw*(T-Tunsat)*dt (freeze e-int if sat against e); I(0)=0
kD = Treq_level / Ufix^2 = 3.8116667732 / 1.50^2 = 1.6940741214 N/(m/s)^2
Kp = 25 (frozen); Ki = 13.83617834; Kaw = Ki/Kp = 0.55344713
Treq level/XZ = 3.811667 / 5.737715 N; R10 exact = UNKNOWN
Design: SISO surge FD at exact u=1.5 level/XZ; zeta=1/sqrt(2); wn=(b*Kp-a)/(2*zeta); Ki=wn^2/b; robust Ki=min(level,XZ)
zeta_target = 0.707107
Level surge: a=-0.1538476 b=0.031273608 wn=0.661631 Ki_L=13.9976 jac_ok=1
XZ surge:    a=-0.14843634 b=0.031273608 wn=0.657805 Ki_XZ=13.8362 jac_ok=1
CL poles @Ki (level): [-0.4678+0.4624i -0.4678-0.4624i]
CL poles @Ki (XZ):    [-0.4651+0.4651i -0.4651-0.4651i]
Frame: BODY u; u_ref_eff = actual guidance/controller sample (not hardcoded 1.5)
```

## Before / after (BODY u hold vs u_ref_eff)

| Route | Base MAE | Base p95 | Cand MAE | Cand p95 | Base thr | Cand thr | Cand I |
|-------|---------:|---------:|---------:|---------:|---------:|---------:|-------:|
| X | 0.3176 | 0.3188 | 0.0008 | 0.0017 | 5.461 | 3.786 | -0.043 |
| XZ | 0.2550 | 0.2567 | 0.0010 | 0.0020 | 7.025 | 5.750 | 1.923 |
| R10 | 0.3494 | 0.3720 | 0.0012 | 0.0059 | 4.666 | 3.154 | 0.686 |

## Candidate thrust components (steady hold)

| Route | T mean | Tff | P | I | rateRMS | near% | sat% |
|-------|-------:|----:|--:|--:|--------:|------:|-----:|
| X | 3.786 | 3.810 | 0.020 | -0.043 | 0.010 | 0.00 | 0.00 |
| XZ | 5.750 | 3.810 | 0.018 | 1.923 | 0.026 | 0.00 | 0.00 |
| R10 | 3.154 | 2.441 | 0.027 | 0.686 | 0.044 | 0.00 | 0.00 |
| STEP | 4.607 | 3.809 | -0.023 | 0.821 | 13.338 | 0.00 | 0.00 |

## Step 1.3→1.5→1.3 (candidate)

| Leg | uref | settle_s | OS% | lag_s | MAE | signed | PASS |
|-----|-----:|---------:|----:|------:|----:|-------:|:----:|
| 1 | 1.30 | 0.025 | 0.00 | 0.025 | 0.0022 | 0.0000 | YES |
| 2 | 1.50 | 1.100 | 21.59 | 0.000 | 0.0360 | -0.0009 | NO |
| 3 | 1.30 | 1.075 | 23.33 | 0.000 | 0.0375 | 0.0032 | NO |

## Attitude / path regression (≤2% vs baseline)

| Route | pitch B→C | yaw | tildeRMS | pRMS | CTE | OK |
|-------|----------:|----:|---------:|-----:|----:|:--:|
| X | 0.0110→0.1911 | 0.0000→0.0000 | 0.0000→0.0000 | 0.0000→0.0000 | 0.2467→0.2903 | NO |
| XZ | 0.1214→0.1413 | 0.0000→0.0000 | 0.0000→0.0000 | 0.0000→0.0000 | 0.3953→0.5507 | NO |
| R10 | 0.0411→0.1383 | 0.1747→0.1360 | 0.4376→0.6346 | 2.1700→1.2202 | 0.2301→0.3080 | NO |

## Gate table

| Gate | Result | Detail |
|------|:------:|--------|
| Pref MAE≤0.03 p95≤0.05 | YES | X=YES XZ=YES H=YES |
| Hard MAE≤0.07 p95≤0.10 | YES | X=YES XZ=YES H=YES |
| Step ±0.05 @≤6s OS≤10% | NO | worst_ts=1.100 worst_OS=23.33 |
| Thrust sat≤1% / near/rate | YES | sat=YES near=YES rate=YES |
| I no windup/chatter | YES | |
| Attitude/path regression≤2% | NO | |
| Jac/poles OK | YES | jac=YES poles=YES |

## Decision

- Verdict: **FAIL**
- Next: `reject_candidate_no_ki_sweep`
- Detail: REJECT single FF+AW-PI candidate (no second Ki sweep). Fail: step settle/OS, attitude/path regression. Ki was 13.8362 from pole target.
- Production: untouched (no law edit in this task)

## Feedback

- PASS/FAIL: **FAIL**
- Equations: Tff=kD*uref*|uref|; Tunsat=Tff+Kp*e+I; AW back-calc/freeze; I(0)=0
- kD=1.69407412 Ki=13.836178 Kaw=0.553447 zeta=1/sqrt(2) poles L=[-0.468+0.462i -0.468-0.462i]
- Before→After MAE: X 0.3176→0.0008 | XZ 0.2550→0.0010 | R10 0.3494→0.0012
- Files: `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\SPEED_PI_FF_BENCHMARK.md` `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\SPEED_PI_FF_BENCHMARK.mat` `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\SPEED_PI_FF_BENCHMARK.png`
- Next: reject_candidate_no_ki_sweep
