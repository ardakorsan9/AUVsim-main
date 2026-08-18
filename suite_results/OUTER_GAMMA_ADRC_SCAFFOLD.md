# OUTER_GAMMA_ADRC_SCAFFOLD_001 — FO LADRC outer-gamma scaffold on theta/q cascade

**Overall verdict: FAIL**

**Decision: `REJECT_OUTER_GAMMA_ADRC_SCAFFOLD`**

## Provenance

- Read-only: `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\OUTER_GAMMA_INDI_AUDIT.mat`, `C:\Users\ardak\MATLAB\Projects\AUVsim-main\controller_law.m`, `C:\Users\ardak\MATLAB\Projects\AUVsim-main\underwater777_vehicle_dynamics.m`
- Driver: `run_outer_gamma_adrc_scaffold.m` (one invocation; production untouched)
- Artifacts: `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\OUTER_GAMMA_ADRC_SCAFFOLD.md`, `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\OUTER_GAMMA_ADRC_SCAFFOLD.mat`, `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\OUTER_GAMMA_ADRC_SCAFFOLD.png`
- Prior: GAMMA_INDI_SCAFFOLD FAIL; OUTER_GAMMA_PI_SCAFFOLD FAIL (level regression)
- No gain sweep; FIXED b0=Gdc*bwi, wc<=0.25, wo=min(3wc,0.6*bwi)
- Gate: fixed smooth |gamma_ref| gate: 0 for |g|<=5deg, smoothstep to 1 at 15deg (level baseline already passes; PI regressed it)

## Equations / units (FACT)

```
gamma = -theta + atan2(w,u)                 [rad]  (phi=0,v=0)
e_gamma = wrap(gamma_ref - gamma)           [rad]
theta_path = theta* + (gamma_ref - gamma*)  [rad]
b0 = Gdc * bwi                              [1/s]
wc <= 0.25 rad/s;  wo = min(3*wc, 0.6*bwi)  [rad/s]
z1dot = z2 + b0*u + 2*wo*(gamma - z1)       [rad/s]
z2dot = wo^2 * (gamma - z1)                 [rad/s^2]
u = (wc*e_gamma - z2)/b0                    [rad]  (theta corr)
dtheta = gate(|gamma_ref|) * sat(u,+/-4deg)
pitch_ref = theta_path + dtheta             [rad]  (ADRC on; else path)
gate: 0 for |g_ref|<=5deg; smoothstep to 1 at 15deg
init: z1=gamma, z2=0
Inner: production controller_law theta/q cascade; de mag +/-15deg rate 40deg/s
```

## Gains / poles / gate / provenance

```
Gdc = mean(T_gamma DC) = 0.94040688  [rad/rad]
bwi = mean(bw_theta_cl) = 1.3941422  [rad/s]  (ref 1.39)
b0  = Gdc*bwi = 1.3110609  [1/s]
wc  = 0.25  [rad/s]  (cap 0.25)
wo  = min(3*wc, 0.6*bwi) = 0.75  [rad/s]
poles: ctrl=-0.25 ; ESO=-0.75 (x2) ; plant_FO=-1.39414
sep_ctrl=bwi/wc=5.577 ; sep_eso=bwi/wo=1.859
gate: |gamma_ref| 0..5deg->0, smoothstep->1 at 15deg
level Gdc=0.940961 bw_th=1.38128 | climb Gdc=0.939852 bw_th=1.40701 | mean Gdc=0.940407 bwi=1.39414 | b0=1.31106 1/s | wc=0.25 wo=0.75 | poles ctrl=-0.25 eso=-0.75(x2) plant_fo=-1.394 | sep_c=5.577 sep_e=1.859
```

## Test

- Exact level / XZ-climb trims at U=1.5 from OUTER_GAMMA_INDI_AUDIT (LOCAL_SS)
- Noise-free +/-1 deg gamma steps; settle 5.0s + hold 18.0s; dt=0.025s
- Baseline = production cascade path-only; scaffold = path + gated LADRC
- PASS: stable/sign OK; agg AND climb MAE or settle >=5%; no case MAE/p95 worsen >2%; ESO bounded; sat=0; rate; no chatter/OS

## Results table

| OP | step | MAE_b° | MAE_s° | MAEΔ% | p95_b° | p95_s° | set_b | set_s | OS_b° | OS_s° | gate | z2max°/s | sat | rate | sign | chat | PASS |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|:---:|:---:|:---:|:---:|
| level | +1 | 0.0499 | 0.0499 | +0.0 | 0.1389 | 0.1389 | 6.38 | 6.38 | 0.139 | 0.139 | 0.00 | 0.255 | 0/0 | YES | YES | YES | YES |
| level | -1 | 0.0473 | 0.0473 | +0.0 | 0.1930 | 0.1930 | 3.75 | 3.75 | 0.052 | 0.052 | 0.00 | 0.273 | 0/0 | YES | YES | YES | YES |
| climb | +1 | 0.4568 | 0.2029 | +55.6 | 0.9452 | 0.3327 | Inf | Inf | 0.963 | 0.367 | 1.00 | 0.974 | 0/0 | YES | YES | YES | NO |
| climb | -1 | 0.5793 | 0.1991 | +65.6 | 1.3413 | 0.6050 | Inf | Inf | 0.000 | 0.118 | 1.00 | 0.768 | 0/0 | YES | YES | YES | NO |

Aggregate: MAE_b=0.2833 MAE_s=0.1248 (Δ+56.0%) | settle_b=11.53 settle_s=11.53 (Δ+0.0%)
Climb: MAEΔ=+61.2% settleΔ=+0.0%

## Gates

| Gate | Result | Detail |
|---|:---:|---|
| Stable/bounded | YES | all cases |
| Correct gamma sign | YES | both steps/OPs |
| Agg MAE or settle >=5% | YES | MAEΔ=+56.0% settleΔ=+0.0% |
| Climb MAE or settle >=5% | YES | MAEΔ=+61.2% settleΔ=+0.0% |
| No case MAE/p95 worsen >2% | YES | per-case guard |
| ESO bounded | YES | z1/z2 |
| Internal states bounded | YES | ||xi|| |
| sat=0 | YES | mag sat |
| rates within limits | YES | <=40 deg/s |
| No chatter/overshoot | NO | xc/OS gates |
| Both OPs PASS | NO | climb+1deg[overshoot]; climb-1deg[overshoot] |

## Decision

- Verdict: **FAIL**
- Choice: **`REJECT_OUTER_GAMMA_ADRC_SCAFFOLD`**
- Reason: Outer gamma LADRC scaffold rejected: climb+1deg[overshoot]; climb-1deg[overshoot] Reject ADRC; return to production nonlinear cascade / next roadmap gate.
- Next: `return_production_nonlinear_cascade_next_roadmap_gate`
- Production: untouched

## Feedback

- PASS/FAIL: **FAIL**
- Decision: **REJECT_OUTER_GAMMA_ADRC_SCAFFOLD**
- Evidence: level+1:MAEb=0.050/s=0.050(Δ0%),p95b=0.139/s=0.139,setb=6.38/s=6.38,gate=0.00 | level-1:MAEb=0.047/s=0.047(Δ0%),p95b=0.193/s=0.193,setb=3.75/s=3.75,gate=0.00 | climb+1:MAEb=0.457/s=0.203(Δ56%),p95b=0.945/s=0.333,setb=Inf/s=Inf,gate=1.00 | climb-1:MAEb=0.579/s=0.199(Δ66%),p95b=1.341/s=0.605,setb=Inf/s=Inf,gate=1.00 | aggMAEΔ=56.0% aggSetΔ=0.0% climbMAEΔ=61.2% climbSetΔ=0.0% | gates stable=1 sign=1 agg=1 climb=1 noworse=1 sat=1 rate=1 int=1 eso=1 chat=1 os=0 | b0=1.311 wc=0.25 wo=0.75
- Files: `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\OUTER_GAMMA_ADRC_SCAFFOLD.md` `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\OUTER_GAMMA_ADRC_SCAFFOLD.mat` `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\OUTER_GAMMA_ADRC_SCAFFOLD.png`
- Next: `return_production_nonlinear_cascade_next_roadmap_gate`
