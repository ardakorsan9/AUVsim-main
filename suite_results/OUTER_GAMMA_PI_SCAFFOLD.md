# OUTER_GAMMA_PI_SCAFFOLD_001 — Outer gamma-PI scaffold on theta/q cascade

**Overall verdict: FAIL**

**Decision: `REJECT_OUTER_GAMMA_PI_SCAFFOLD`**

## Provenance

- Read-only: `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\OUTER_GAMMA_INDI_AUDIT.mat`, `C:\Users\ardak\MATLAB\Projects\AUVsim-main\controller_law.m`, `C:\Users\ardak\MATLAB\Projects\AUVsim-main\underwater777_vehicle_dynamics.m`
- Driver: `run_outer_gamma_pi_scaffold.m` (one invocation; production untouched)
- Artifacts: `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\OUTER_GAMMA_PI_SCAFFOLD.md`, `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\OUTER_GAMMA_PI_SCAFFOLD.mat`, `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\OUTER_GAMMA_PI_SCAFFOLD.png`
- Prior: GAMMA_INDI_SCAFFOLD FAIL (NMP/RHP-zero sign conflict)
- No gain sweep; FIXED SIMC Kp/Ki from closed-inner T_gamma

## Equations / units (FACT)

```
gamma = -theta + atan2(w,u)                 [rad]  (phi=0,v=0)
e_gamma = wrap(gamma_ref - gamma)           [rad]
theta_path = theta* + (gamma_ref - gamma*)  [rad]
u_i = sat(Ki * int_e, +/-2 deg)          [rad]
dtheta = sat(Kp*e_gamma + u_i, +/-4 deg) [rad]
pitch_ref = theta_path + dtheta             [rad]  (PI on; else path only)
int_e += e_gamma*dt  (freeze if sat against e); int_e += Kaw*(dtheta-u_unsat)*dt
|int_e| <= I_max/Ki; bumpless: int_e(0)=0
Inner: production controller_law theta/q cascade; de mag +/-15deg rate 40deg/s
```

## Gains / poles / provenance

```
Gdc = mean(T_gamma DC) = 0.94040688  [rad/rad]
bwi = mean(bw_theta_cl) = 1.3941422  [rad/s]  (ref 1.39)
tau = 1/bwi = 0.71728695  [s]
wo  = min(0.30, bwi/3) = 0.3  [rad/s]
tc  = 1/wo = 3.3333333  [s]
Kp  = tau/(Gdc*tc) = 0.22882232  [-]
Ki  = 1/(Gdc*tc)   = 0.31901085  [1/s]
Kaw = Ki/Kp       = 1.3941422  [1/s]
FO poles = -0.3, -1.39414 ; zeta=1.3098 (overdamped); sep=bwi/wo=4.647
level Gdc=0.940961 bw_th=1.38128 | climb Gdc=0.939852 bw_th=1.40701 | mean Gdc=0.940407 bwi=1.39414 | FO poles=-0.3, -1.3941 zeta=1.3098 | sep=4.647
```

## Test

- Exact level / XZ-climb trims at U=1.5 from OUTER_GAMMA_INDI_AUDIT (LOCAL_SS)
- Noise-free +/-1 deg gamma steps; settle 5.0s + hold 18.0s; dt=0.025s
- Baseline = production cascade path-only; scaffold = path + outer PI
- PASS: stable/sign OK; agg MAE or settle >=5%; no case MAE/p95 worsen >2%; sat=0; rate; no chatter/OS

## Results table

| OP | step | MAE_b° | MAE_s° | MAEΔ% | p95_b° | p95_s° | set_b | set_s | OS_b° | OS_s° | sat | rate | sign | chat | PASS |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|:---:|:---:|:---:|:---:|
| level | +1 | 0.0499 | 0.0658 | -31.9 | 0.1389 | 0.3321 | 6.38 | 5.38 | 0.139 | 0.352 | 0/0 | YES | YES | YES | NO |
| level | -1 | 0.0473 | 0.0698 | -47.7 | 0.1930 | 0.3623 | 3.75 | 5.80 | 0.052 | 0.387 | 0/0 | YES | YES | YES | NO |
| climb | +1 | 0.4568 | 0.1697 | +62.9 | 0.9452 | 0.2562 | Inf | Inf | 0.963 | 0.023 | 0/0 | YES | YES | YES | YES |
| climb | -1 | 0.5793 | 0.2608 | +55.0 | 1.3413 | 0.5446 | Inf | Inf | 0.000 | 0.571 | 0/0 | YES | YES | YES | NO |

Aggregate: MAE_b=0.2833 MAE_s=0.1415 (Δ+50.0%) | settle_b=11.53 settle_s=11.79 (Δ-2.3%)

## Gates

| Gate | Result | Detail |
|---|:---:|---|
| Stable/bounded | YES | all cases |
| Correct gamma sign | YES | both steps/OPs |
| Agg MAE or settle >=5% | YES | MAEΔ=+50.0% settleΔ=-2.3% |
| No case MAE/p95 worsen >2% | NO | per-case guard |
| Internal states bounded | YES | ||xi|| |
| sat=0 | YES | mag sat |
| rates within limits | YES | <=40 deg/s |
| No chatter/overshoot | NO | xc/OS gates |
| Both OPs PASS | NO | level+1deg[MAE/p95 worsen>2%,overshoot]; level-1deg[MAE/p95 worsen>2%,overshoot]; climb-1deg[overshoot] |

## Decision

- Verdict: **FAIL**
- Choice: **`REJECT_OUTER_GAMMA_PI_SCAFFOLD`**
- Reason: Outer gamma-PI scaffold rejected: level+1deg[MAE/p95 worsen>2%,overshoot]; level-1deg[MAE/p95 worsen>2%,overshoot]; climb-1deg[overshoot] Next: one ADRC audit/candidate on theta/q cascade.
- Next: `ADRC_outer_gamma_audit_candidate`
- Production: untouched

## Feedback

- PASS/FAIL: **FAIL**
- Decision: **REJECT_OUTER_GAMMA_PI_SCAFFOLD**
- Evidence: level+1:MAEb=0.050/s=0.066(Δ-32%),p95b=0.139/s=0.332,setb=6.38/s=5.38 | level-1:MAEb=0.047/s=0.070(Δ-48%),p95b=0.193/s=0.362,setb=3.75/s=5.80 | climb+1:MAEb=0.457/s=0.170(Δ63%),p95b=0.945/s=0.256,setb=Inf/s=Inf | climb-1:MAEb=0.579/s=0.261(Δ55%),p95b=1.341/s=0.545,setb=Inf/s=Inf | aggMAEΔ=50.0% aggSetΔ=-2.3% | gates stable=1 sign=1 agg=1 noworse=0 sat=1 rate=1 int=1 chat=1 os=0 | Kp=0.2288 Ki=0.319
- Files: `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\OUTER_GAMMA_PI_SCAFFOLD.md` `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\OUTER_GAMMA_PI_SCAFFOLD.mat` `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\OUTER_GAMMA_PI_SCAFFOLD.png`
- Next: `ADRC_outer_gamma_audit_candidate`
