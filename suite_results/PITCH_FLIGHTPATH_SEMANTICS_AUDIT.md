# PITCH_FLIGHTPATH_SEMANTICS_AUDIT_001 — Pitch-ref θ vs flight-path γ semantics audit

**Overall verdict: PASS**

## Provenance

- Read-only: `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\SPEED_PI_FF_BENCHMARK.mat`, `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\THRUST_TRIM_U15_AUDIT.mat`, `C:\Users\ardak\MATLAB\Projects\AUVsim-main\controller_law.m`
- Driver: `run_pitch_flightpath_semantics_audit.m` (one invocation; production untouched)
- Artifacts: `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\PITCH_FLIGHTPATH_SEMANTICS_AUDIT.md`, `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\PITCH_FLIGHTPATH_SEMANTICS_AUDIT.mat`, `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\PITCH_FLIGHTPATH_SEMANTICS_AUDIT.png`
- History: prior pitch MAE definitions NOT overwritten; this audit adds corrected γ/θ_cmd metrics

## Identity (controller_law + guidance contract)

```
controller: e_theta = pitch_ref - theta_phys   => pitch_ref consumed as ATTITUDE
            theta_phys = -theta
climb FF:   gamma_ref = pitch_ref; de_climb_ff = sat(k_gamma*gamma_ref)
            k_gamma = 0.1320695001  (from path_pitch 21.8014 deg)
guidance:   K_gamma=0, enable_alpha_hat=false => pitch_raw = pitch_geom + depth_corr; pitch_geom = atan2(t_z, ||t_xy||) ≈ path flight-path angle gamma_path
kinematics: gamma = theta_phys + alpha, alpha=atan2(w,u) [BODY]
warning:    With roll phi or sway v nonzero, NED gamma_act=atan2(V_D,Uh) differs from theta_phys+atan2(w,u); residual quantifies that approximation.
mismatch:   1 (guidance γ-like ref vs attitude tracker)
```

## Exact-u trim kinematics (THRUST_TRIM_U15; history labels preserved)

| Point | u* | θ_phys [deg] | α=atan2(w,u) [deg] | γ_kin=θ+α | γ_path | resid [deg] | θ_cmd=γ-α |
|-------|---:|-------------:|-------------------:|----------:|-------:|------------:|----------:|
| Level | 1.500 | +1.9102 | -1.9102 | +0.0000 | 0.0000 | +2.649e-16 | +1.9102 |
| XZ | 1.500 | +24.7426 | -2.9412 | +21.8014 | 21.8014 | +0.000e+00 | +24.7426 |
| R10 | UNKNOWN | — | — | — | path tangent (exact geom) | traj resid | α BODY approx |

User check: level θ_phys=+1.910 / w=-0.050 / α≈-1.910; XZ θ_phys=+24.743 / w=-0.077 / α≈-2.942; γ=21.801.

## Corrected metric definitions (additive; do not replace history)

```
gamma_act   = atan2(V_D, hypot(V_N,V_E))     gamma_ref   = atan2(t_hat_z, ||t_hat_xy||)  theta_phys  = -Euler_theta
alpha       = atan2(w,u)                   resid       = gamma_act - (theta_phys+alpha)  theta_cmd   = gamma_ref - alpha            e_theta_legacy = theta_ref - theta_phys    e_gamma        = gamma_ref - gamma_act     e_theta_req    = theta_cmd - theta_phys    ```

## Route table — baseline → speed candidate (steady window)

| Route | u B→C | legacy|θ| MAE° | γ MAE° | θ_req MAE° | α mean° | resid RMS° | CTE m | ref nearer θ_cmd? |
|-------|------:|-----------------:|-------:|-----------:|--------:|-----------:|------:|:-----------------:|
| X | 1.817→1.499 | 0.011→0.191 | 0.331→0.394 | 0.331→0.394 | -1.32→-1.92 | 0.000→0.000 | 0.247→0.290 | 1→1 |
| XZ | 1.755→1.499 | 0.121→0.141 | 0.418→0.669 | 0.418→0.669 | -2.20→-2.98 | 0.000→0.000 | 0.400→0.558 | 1→1 |
| R10 | 1.556→1.199 | 0.041→0.138 | 0.657→1.028 | 0.678→1.042 | -1.83→-3.17 | 0.043→0.027 | 0.269→0.401 | 1→1 |

Note: ref nearer θ_cmd than raw γ is expected when depth-I partially mimics α; construction is still γ_path+depth, not explicit attitude/α.

## Acquisition / steady (candidate; corrected)

| Route | legacy acq/ss MAE° | γ acq/ss MAE° | θ_req acq/ss MAE° | acq_time_s (legacy W) |
|-------|------------------:|--------------:|------------------:|----------------------:|
| X | 0.425 / 0.191 | 1.795 / 0.394 | 1.795 / 0.394 | 2.87 |
| XZ | 0.978 / 0.141 | 2.894 / 0.669 | 2.894 / 0.669 | 5.95 |
| R10 | 0.501 / 0.138 | 1.855 / 1.028 | 1.841 / 1.042 | 9.33 |

## Speed coupling explanation

Guidance builds pitch_ref = gamma_path + depth_corr (K_gamma=0, alpha_hat OFF); controller_law tracks pitch_ref as theta_phys (e_theta=pitch_ref-theta_phys); climb FF aliases gamma_ref:=pitch_ref. Exact-u trim needs theta_phys=gamma-alpha (level alpha=-1.910 deg, XZ alpha=-2.941 deg). Depth-I partially mimics alpha (closed-loop ref often nearer theta_cmd than raw gamma) but is not explicit AoA compensation — speed-dependent. Prior pitch MAE rewarded |pitch_ref-theta_phys| and understates true e_gamma. When SPEED candidate forces BODY u→1.5, alpha→trim and required attitude shifts; legacy pitch + CTE regress.

## Helix labels

- Geometry: `gamma_ref` from exact `generate_balanced_helical_path(10,2,2,*)` Frenet tangent.
- Approximation: BODY `alpha=atan2(w,u)` ignores sway `v` and roll; residual RMS on R10 candidate = 0.027 deg (phi_rms=0.88 deg, v_rms=0.035).

## Gate table

| Gate | Result | Detail |
|------|:------:|--------|
| Controller identity parsed | YES | e_theta / gamma_ref alias |
| Trim α/θ/γ match stated | YES | level α≈-1.910; XZ θ≈24.743 γ≈21.801 |
| Cand α→exact-u trim (X,XZ) | YES | X α→-1.92 XZ α→-2.98 |
| e_gamma > legacy|θ| (X,XZ) | YES | legacy metric understates path error |
| Speed cand u→1.5 + pitch/CTE regress | YES | exposes semantics |
| Kinematic resid RMS≈0 (X,XZ) | YES | phi=v=0 identity holds |

## Decision

- Verdict: **PASS**
- Root: semantic mismatch (γ-command tracked as θ) + speed-dependent α
- Next architecture (exactly one): `measured_trim_alpha_compensation`
- Detail: BOUNDED NEXT (do not implement here): keep attitude cascade; set theta_ref_cmd = gamma_ref_path - alpha_hat before controller. alpha_hat from (1) trim schedule on (u_ref, gamma_ref) using THRUST exact-u level/XZ alphas, and/or (2) measured BODY alpha=atan2(w,u) LPF. Sensors/frames: BODY u,w already in controller_law (12th arg); filter tau~0.3-1s; clamp |alpha_hat| (e.g. 8 deg, existing enable_alpha_hat scaffold). Helix: treat atan2(w,u) as APPROX — monitor resid=gamma_act-(theta_phys+alpha); if |phi| or |v| large, add roll/v correction or fall back to outer gamma later. Reject outer flight-path loop for this step (Tur5B K_gamma already tried; larger sensor/filter surface: needs reliable NED V or reconstructed gamma_act). Correct new metrics: report e_gamma and e_theta_req separately; do not overwrite historical pitch MAE definitions.
- Production: untouched

## Feedback

- PASS/FAIL: **PASS**
- Identity: pitch_ref consumed as θ_phys; guidance emits γ-like; climb FF aliases γ:=pitch_ref
- Trim: level θ_phys=+1.910° α=-1.910°; XZ θ_phys=+24.743° α=-2.941° γ=+21.801°
- Cand steady legacy|θ| / γ MAE°: X 0.191/0.394 | XZ 0.141/0.669 | R10 0.138/1.028
- Files: `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\PITCH_FLIGHTPATH_SEMANTICS_AUDIT.md` `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\PITCH_FLIGHTPATH_SEMANTICS_AUDIT.mat` `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\PITCH_FLIGHTPATH_SEMANTICS_AUDIT.png`
- Next: `measured_trim_alpha_compensation`
