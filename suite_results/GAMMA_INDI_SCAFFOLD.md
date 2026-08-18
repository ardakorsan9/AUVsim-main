# GAMMA_INDI_SCAFFOLD_001 — Incremental gamma-INDI scaffold feasibility

**Overall verdict: FAIL**

**Decision: `REJECT_DIRECT_INDI_SCAFFOLD`**

## Provenance

- Read-only: `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\OUTER_GAMMA_INDI_AUDIT.mat`, `C:\Users\ardak\MATLAB\Projects\AUVsim-main\controller_law.m`, `C:\Users\ardak\MATLAB\Projects\AUVsim-main\underwater777_vehicle_dynamics.m`
- Driver: `run_gamma_indi_scaffold.m` (one invocation; production untouched)
- Artifacts: `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\GAMMA_INDI_SCAFFOLD.md`, `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\GAMMA_INDI_SCAFFOLD.mat`, `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\GAMMA_INDI_SCAFFOLD.png`
- No gain sweep; FIXED scaffold

## Equations / units (FACT)

```
gamma = -theta + atan2(w,u)           [rad]  (phi=0,v=0)
e_gamma = wrap(gamma_ref - gamma)     [rad]
nu = gamma_ref_dot + 0.46*e_gamma     [rad/s], clip +/-6 deg/s
de_f, gamma_dot_f: FO LPF tau=0.15s on applied de and d(gamma)/dt
de_indi = de_f + (nu - gamma_dot_f)/Gdelta
Gdelta = -0.2208  [(rad/s)/rad] fixed
de_corr = sat(de_indi - de_base, +/-2 deg)
de = rate_limit(sat(de_base+de_corr, +/-15 deg), 40 deg/s)
Baseline: production theta/q cascade (controller_law); pitch_ref = theta* + (gamma_ref-gamma*)
```

## Test

- Noise-free +/-1 deg gamma steps about exact level/climb trims
- Settle hold 5.0s then hold 18.0s; dt=0.025s
- Compare baseline cascade vs scaffold INDI correction
- PASS if both OPs: stable/bounded, correct sign, MAE or settle improves >=5%, internal bounded, sat=0, rates OK

## Results table

| OP | step | MAE_base° | MAE_scaf° | MAEΔ% | settle_b[s] | settle_s[s] | setΔ% | OS_b° | OS_s° | sat | rateOK | sign | intOK | PASS |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|:---:|:---:|:---:|:---:|
| level | +1 | 0.0499 | 0.9034 | -1711.2 | 6.38 | Inf | -100.0 | 0.139 | 0.162 | 0/0 | YES | NO | YES | NO |
| level | -1 | 0.0473 | 0.9968 | -2008.3 | 3.75 | Inf | -100.0 | 0.052 | 2.125 | 0/0 | YES | YES | YES | NO |
| climb | +1 | 0.4568 | 0.8591 | -88.1 | Inf | Inf | +0.0 | 0.963 | 1.775 | 0/0 | YES | YES | YES | NO |
| climb | -1 | 0.5793 | 0.9818 | -69.5 | Inf | Inf | +0.0 | 0.000 | 0.000 | 0/0 | YES | NO | YES | NO |

## Gates

| Gate | Result | Detail |
|---|:---:|---|
| Both OPs stable/bounded | YES | finite states |
| Correct gamma sign | NO | both steps |
| MAE or settle improve >=5% | NO | per case |
| Internal states bounded | YES | ||xi|| gate |
| sat=0 | YES | mag sat count |
| rates within limits | YES | <=40 deg/s |
| Both OPs PASS | NO | level+1deg[wrong gamma sign,MAE/settle not improved >=5%]; level-1deg[MAE/settle not improved >=5%]; climb+1deg[MAE/settle not improved >=5%]; climb-1deg[wrong gamma sign,MAE/settle not improved >=5%] |

## Decision

- Verdict: **FAIL**
- Choice: **`REJECT_DIRECT_INDI_SCAFFOLD`**
- Reason: Direct incremental gamma-INDI scaffold rejected: level+1deg[wrong gamma sign,MAE/settle not improved >=5%]; level-1deg[MAE/settle not improved >=5%]; climb+1deg[MAE/settle not improved >=5%]; climb-1deg[wrong gamma sign,MAE/settle not improved >=5%] Prefer outer gamma PI/ADRC on theta/q cascade.
- Next: `implement_outer_gamma_PI_or_ADRC`
- Production: untouched

## Feedback

- PASS/FAIL: **FAIL**
- Decision: **REJECT_DIRECT_INDI_SCAFFOLD**
- Evidence: level+1:MAEb=0.050/s=0.903(Δ-1711%),setb=6.38/s=Inf | level-1:MAEb=0.047/s=0.997(Δ-2008%),setb=3.75/s=Inf | climb+1:MAEb=0.457/s=0.859(Δ-88%),setb=Inf/s=Inf | climb-1:MAEb=0.579/s=0.982(Δ-69%),setb=Inf/s=Inf | gates stable=1 sign=0 improve=0 sat=1 rate=1 int=1
- Files: `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\GAMMA_INDI_SCAFFOLD.md` `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\GAMMA_INDI_SCAFFOLD.mat` `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\GAMMA_INDI_SCAFFOLD.png`
- Next: `implement_outer_gamma_PI_or_ADRC`
