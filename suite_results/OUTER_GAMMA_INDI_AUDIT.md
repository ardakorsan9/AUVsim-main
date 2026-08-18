# OUTER_GAMMA_INDI_AUDIT_001 — Outer gamma PI vs INDI architecture audit

**Overall verdict: PASS**

**Decision: `INDI_FIRST`**

## Provenance

- Read-only: `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\LOCAL_SS_LEVEL.mat`, `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\LOCAL_SS_CLIMB.mat`, `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\TRIM_ALPHA_TWO_REPEAT_CLOSURE.mat`
- Driver: `run_outer_gamma_indi_audit.m` (one invocation; production untouched)
- Artifacts: `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\OUTER_GAMMA_INDI_AUDIT.md`, `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\OUTER_GAMMA_INDI_AUDIT.mat`, `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\OUTER_GAMMA_INDI_AUDIT.png`
- No controller edit; no gain design/sweep

## Literature (cite; distinguish inference)

1. **Yu et al., Ocean Eng. 2022, DOI 10.1016/j.oceaneng.2022.112458**
   - INFERENCE: hierarchical ALOS + disturbance-rejection motivates outer path-angle layer with inner attitude — not copied as gains
2. **Petrich & Stilwell, Ocean Eng. 2010, DOI 10.1016/j.oceaneng.2009.11.007**
   - INFERENCE: third-order AUV pitch model justifies reduced vertical [theta,w,q]-like dynamics; our 5-state vertical embeds that plus z,u
3. **Smeur et al., INDI cascade, arXiv:1701.07254**
   - INFERENCE: incremental nonlinear dynamic inversion cascade pattern for filtered derivative + control-effectiveness inversion

## Units / frames / equations (FACT)

```
State x=[x y z phi theta psi u v w p q r]: NED [m], Euler ZYX [rad], BODY vel/rates
Input u=[delta_r, delta_e, thrust]: rad, rad, N
theta_phys = -theta
gamma = theta_phys + atan2(w,u)     [phi=0,v=0 exact]
      = -theta + atan2(w,u)
Linear: dgamma = -dtheta + ( -w/(u^2+w^2) ) du + ( u/(u^2+w^2) ) dw
Cgamma_full on x: [0 0 0 0 -1 0  da/du  0  da/dw  0 0 0]
Cgamma_v on [z theta u w q]
Plant signs (LOCAL_SS): de>0 -> +Z/+M (Zuuds/Muuds*u^2)
```

## Cascade context (INFERENCE gains + FACT plant)

```
INFERENCE from frozen production cascade (AGENT_HANDOFF/init_parameters freeze: Kp_angle=1.25 Ki_angle=0.16 Kp_rate=0.95 Kd_damp=0.80 tau_rate=0.05); not re-identified here
Inner: e_theta -> q_cmd (Kp_angle,Ki_angle) -> de (Kp_rate,Kd_damp)
Outer PI sketch: theta_cmd = gamma_path + Kpg*e_gamma + Kig*int(e_gamma) with rate/angle/antiwindup limits (NO gains designed here)
INDI sketch: de = de0 + Gdelta^+ (gamma_dot_ref_f - gamma_dot_f); needs filtered gamma_dot & Gdelta=Cgamma*B_de (NO gains designed here)
```

## Trim kinematics (FACT from LOCAL_SS x*)

| OP | u* | w* | theta_phys [deg] | alpha [deg] | gamma_kin [deg] | de* [deg] |
|---|---:|---:|---:|---:|---:|---:|
| level | 1.81718 | -0.04138 | 1.3044 | -1.3044 | 0.0000 | -4.7228 |
| climb | 1.75462 | -0.06687 | 23.9838 | -2.1824 | 21.8014 | -1.2107 |

## Cgamma (vertical)

```
level Cgamma_v = [0          -1 0.012524341  0.55001853           0]
climb Cgamma_v = [0          -1 0.021687483   0.5690975           0]
```

## Elevator to gamma effectiveness / relative degree / poles-zeros

| Qty | level | climb | drel |
|---|---:|---:|---:|
| reldeg(gamma<-de) | 1 | 1 | — |
| G_delta=Cgamma*B_de [(rad/s)/rad] | -0.224967 | -0.216656 | 3.7% |
| Gdc gamma/de [rad/rad] | 13.7077 | 5.575 | 59.3% |
| Gdc theta_phys/de | 14.5678 | 5.93179 | — |
| cond(Ad) [theta u w q] | 169 | 65.8 | — |
| RHP zero? | YES | YES | — |
| open-loop RHP pole? | YES | YES | — |
| de headroom [deg] | 10.28 | 13.79 | — |

### Poles (Av) / zeros (gamma<-de)

level poles: 0+0i, -2.74788+0i, 0.735048+0i, -0.125898+0i, 0.24107+0i

level zeros: 8.19015+0i, -2.52712+0i, -0.18047+0i, 0+0i

climb poles: 0+0i, -2.74282+0i, 0.487064+0.249318i, 0.487064-0.249318i, -0.168544+0i

climb zeros: 8.03585+0i, -2.56625+0i, -0.172701+0i, 0+0i

## Inner theta/q cascade vs outer gamma bandwidth

| Qty | level | climb |
|---|---:|---:|
| cl stable | 1 | 1 |
| bw theta_phys/theta_cmd [rad/s] | 1.3813 | 1.4070 |
| bw gamma/theta_cmd [rad/s] | 1.3560 | 1.3813 |
| bw ratio (info) | 1.019 | 1.019 |
| w_outer=bw_theta/3 [rad/s] | 0.4604 | 0.4690 |
| |T_gamma|/|Gdc| at w_outer | 1.0251 | 0.9990 |
| phase T_gamma at w_outer [deg] | -31.64 | -30.72 |
| flat/phase OK for 3x sep | 1 | 1 |
| Gdc gamma/theta_cmd | 0.9410 | 0.9399 |

Gate: T_gamma near-DC at bw_theta/3 (design 3x) -> PASS

## PI vs INDI comparison (no gains)

| Topic | Outer gamma PI on theta cascade | Incremental gamma INDI |
|---|---|---|
| Sensors | gamma (recon or NED V) | gamma and filtered gamma_dot; Gdelta |
| Noise | lower (no derivative) | higher (gamma_dot LPF critical) |
| Conditioning | needs stable Gdc and sep>=3 | needs well-conditioned Gdelta (reldeg-1 here) |
| Actuator | bumpless theta_cmd + AW/rate/angle limits | incremental de about trim/current |
| OP variation | schedule Kpg/Kig if Gdc drifts | schedule/adapt Gdelta (drel=3.7%) |
| Failure modes | windup; fights inner if sep lost | wrong Gdelta; filter lag chatter |

## TRIM_ALPHA closure evidence (FACT)

- FACT from TRIM_ALPHA_TWO_REPEAT_CLOSURE: steady γ/CTE potential proved; persistent settle + peak/actuator gates FAIL; cosine soft-start also FAIL — feedforward shaping stopped
- Closure verdict: **FAIL**

## Decision gates

| Gate | Result | Detail |
|---|:---:|---|
| Complete margins | YES | finite Gdc/Gdelta/bw both OPs |
| Sign consistent | YES | sign(Gdc) L/C=+1/+1  sign(Gδ) L/C=-1/-1  Gdc=13.71/5.575  Gδ=-0.225/-0.2167 |
| Authority/headroom | NO | |Gdelta| L/C=0.225/0.2167  dGdelta=3.7%  Gdc L/C=13.71/5.575 dGdc=59.3%  de headroom min=10.28 deg  cond(Ad) max=169 |
| BW sep >=3 | YES | design sep=3 at w_outer=bw_θ/3: L=0.460 C=0.469 rad/s;  |Tγ|/|Gdc| L/C=1.025/0.999  phase L/C=-31.6/-30.7 deg; flat_ok L/C=1/1; bw_θ=1.381/1.407  bw_γ←θcmd=1.356/1.381  cl_stable=1 |
| Reldeg-1 (INDI-ready) | YES | reldeg(γ←δe) L/C=1/1 (INDI Gδ=Markov1) |
| RHP zero absent | NO | — |

## Decision

- Verdict: **PASS**
- Choice: **`INDI_FIRST`**
- Reason: INDI_FIRST: authority gate failed (Gdc/Gdelta OP variation or headroom); RHP zero in open-loop gamma<-de (NMP inverse response). Reldeg-1 gives direct Gdelta=Cgamma*B_de (dGdelta small vs dGdc) for filtered-gamma_dot INDI.
- Next: `implement_incremental_gamma_INDI_scaffold`
- Production: untouched

### Failure modes

- Gdelta OP variation 3.7% (schedule/mismatch risk)
- Helix: BODY alpha approx when phi/v nonzero — resid=gamma_NED-(theta_phys+alpha)
- Outer PI: integrator windup on elevator sat / rate limit during acquisition
- INDI: gamma_dot filter lag/noise -> chatter; bad Gdelta -> wrong increment
- Unmodeled thrust coupling on gamma (Gdelta_thrust nonzero)
- Open-loop RHP plant poles present; relies on inner cascade (stable=1)
- INDI without reliable gamma_dot estimate fails on noisy BODY u,w

## Feedback

- PASS/FAIL: **PASS**
- Decision: **INDI_FIRST**
- Evidence: Gdc L/C=13.71/5.575; Gdelta L/C=-0.225/-0.2167; 3x-flat L/C=1/1; reldeg=1/1
- Files: `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\OUTER_GAMMA_INDI_AUDIT.md` `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\OUTER_GAMMA_INDI_AUDIT.mat` `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\OUTER_GAMMA_INDI_AUDIT.png`
- Next: `implement_incremental_gamma_INDI_scaffold`
