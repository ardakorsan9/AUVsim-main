# PROPULSION_POWER_COMPUTE_BASELINE_001 — isolated propulsion / power / compute budget (Gate6)

**Verdict (all gates except the post-write artifact self-check): FAIL**

> FAIL: mandatory gate(s) G3 not met. Conditional gate(s) not met: G3C. No rerun and no tuning performed in this task.

- Promotion: **NONE**. This is an isolated Gate6 budget study.
- Status: **SIMULATION_ONLY / NOT_CERTIFIED**. Gate4 evidence is **shadow-only** here.
- Hardware numerics: **ASSUMED / TO_BE_IDENTIFIED**, emitted as ranges. **No vendor selection.**
- Compute evidence is call rates/counts and host runtime. **It is not WCET** and grants no real-time claim.
- No tuning: every gain, limit and threshold was frozen before the run and verified byte-identical after it.

## Provenance and freeze

- Read-only sources (exactly three): `C:\Users\ardak\MATLAB\Projects\AUVsim-main\run_speed_envelope_audit.m`, `C:\Users\ardak\MATLAB\Projects\AUVsim-main\controller_law.m`, `C:\Users\ardak\MATLAB\Projects\AUVsim-main\underwater777_vehicle_dynamics.m`
- Declarations: `propulsion_power_compute_case.m` (frozen before the run)
- Driver: `run_propulsion_power_compute_baseline.m` (one MATLAB invocation)
- Artifacts: `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\PROPULSION_POWER_COMPUTE_BASELINE.md`, `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\PROPULSION_POWER_COMPUTE_BASELINE.mat`, `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\PROPULSION_POWER_COMPUTE_BASELINE.png`
- Seed 0 (`rng(0,'twister')` before every run) | controller dt = 0.025 s | guidance dt = 0.075 s
- Frozen production values: `thrust_trim=13.4 N`, `Kp_x=25`, `Kp_roll=0.605072`, `thrust in [-100, 300] N`, `delta_e_max=15.000 deg`, `delta_r_max=25.000 deg`, fin rate limit 40 deg/s

### Frozen-string checks (production not edited)

| Check | Needle | Present |
|---|---|:--:|
| climb FF gain | `k_gamma_climb = 0.1320695001` | YES |
| roll damp gain | `Kp_roll = 0.605072` | YES |
| thrust law | `thrust_trim + Kp_x * (u_ref - u)` | YES |
| thrust clamp | `max(min(thrust, thrust_max), thrust_min)` | YES |
| fin rate limit | `max_de = deg2rad(40) * dt` | YES |
| climb FF term | `de_climb_ff` | YES |
| plant thrust input | `Xprop   = controls.thrust;` | YES |
| plant elevator moment | `Muuds*u^2*delta_e` | YES |

### Fingerprints (pre-run vs post-run)

| File | Bytes | SHA-256 (pre) | Identical after run |
|---|--:|---|:--:|
| `controller_law.m` | 9402 | `16b7c20a14f1a1afcc3479351edee66eadecf4d134ed7d17e9e1d6986d9df890` | YES |
| `underwater777_vehicle_dynamics.m` | 6065 | `612e1009f7d65968109be1e8352d472730db65c08b0c15a17e6cde7a9f629558` | YES |
| `guidance_law.m` | 14601 | `2d70cea916107649132ea80eba13cd2c5a3730163f10ebc3fdafb1026513eec3` | YES |
| `continuous_path_tracking.m` | 10845 | `e490453b094f2049dcdabe9a31c3eb628e3740fc8c6137b4fa86add7cdf0641b` | YES |
| `init_parameters.m` | 4205 | `09803f4956b64227403919229781086c367e620f5736cfd680d1b15081237a9a` | YES |
| `generate_balanced_helical_path.m` | 564 | `8773ecbebc7c12d6153b900913abf7a5e8c6847919a0ff15d5a315e8a8f837c1` | YES |
| `run_speed_envelope_audit.m` | 49656 | `06c5ebbc68d3c94c6f72cf30466ece32045812affd55dc6b7b87dc954b4e18fa` | YES |
| `suite_results\CODEX_VERTICAL_PLAN.md` | 43101 | `000ba87721bb75846690d0f4325aad6c58070c0831cb9c199e240b53b6e7931c` | YES |

- Fingerprint result: 8 files byte-identical pre/post run (production untouched)

## Harness (documented deviation)

The actuator has to sit between `controller_law` and the plant, so every route is run through one local fixed-step loop (`guidance_law` -> `controller_law` -> ASSUMED thruster -> `ode45` on `underwater777_vehicle_dynamics`), which is the same loop shape already used for the logged R10 route in `run_speed_envelope_audit.m`. No production file is called differently and none is edited. Absolute tracking numbers on X / XZ can therefore differ slightly from SPEED_ENVELOPE_AUDIT_001, which drives those two routes through `continuous_path_tracking`. The steady window here is `t >= 5 s` and path progress `<= 90%`.

## Predeclared ASSUMED thruster variants

| Variant | Map gain [-] | Lag tau [s] | Slew [N/s] | Deadband [N] | Provenance | Note |
|---|--:|--:|--:|--:|---|---|
| `ideal` | 1.00 | 0.00 | Inf | 0.00 | EXACT_IDENTITY | parity reference: structural pass-through |
| `nominal` | 1.00 | 0.30 | 8 | 0.02 | ASSUMED | mid-range brushless propulsor, TO_BE_IDENTIFIED |
| `slow_low` | 0.85 | 0.60 | 4 | 0.05 | ASSUMED | pessimistic corner (fouling / derate / heavy inertia) |
| `fast_high` | 1.15 | 0.15 | 16 | 0.01 | ASSUMED | optimistic corner (oversized propulsor) |

Realized thrust order of operations: map gain -> production magnitude clamp -> command deadband -> slew limit -> first-order lag -> magnitude clamp. Fins keep the frozen production magnitude and 40 deg/s rate limits inside `controller_law`; only the thrust channel carries the ASSUMED realism.

## Ideal parity (identity proof)

The `ideal` variant has gain 1, no deadband, infinite slew and zero lag, so `actuator_step` returns the production-clamped command through a structural identity branch with no arithmetic. Empirically each case was run twice: once with the actuator bypassed entirely and once through the identity actuator.

| Case | max abs trajectory difference | Bitwise exact |
|---|--:|:--:|
| X@1.00 | 0 | YES |
| X@1.50 | 0 | YES |
| X@2.00 | 0 | YES |
| XZ@1.00 | 0 | YES |
| XZ@1.50 | 0 | YES |
| XZ@2.00 | 0 | YES |
| R10@1.50 | 0 | YES |
| R10@2.00 | 0 | YES |

- Replay: X@1.50 / ideal re-run, max abs difference 0 (all channels bitwise equal)

## Tracking results (frozen hard gates)

Thresholds are the SPEED_ENVELOPE_AUDIT_001 absolute set, verbatim. The frozen gate set contains **no speed-error gate**, so speed error is reported but not gated; thrust saturation is the gated measure of speed authority.

| Case | Variant | pitch MAE | pitch p95 | gamma MAE | yaw MAE | CTE [m] | u MAE | u bias | elev sat% | thr sat% | gates | first limit |
|---|---|--:|--:|--:|--:|--:|--:|--:|--:|--:|:--:|---|
| X@1.00 | `ideal` | 0.1744 | 0.5182 | 0.5543 | 0.0000 | 0.3164 | 0.4026 | -0.4026 | 0.00 | 0.00 | FAIL | pitch_MAE(0.1744>0.10) |
| X@1.00 | `nominal` | 0.0902 | 0.1463 | 0.1185 | 0.0000 | 0.1981 | 1.0727 | -1.0727 | 0.00 | 0.00 | PASS | none |
| X@1.00 | `slow_low` | 0.1692 | 0.2361 | 0.2803 | 0.0000 | 0.1098 | 1.5539 | -1.5539 | 0.00 | 0.00 | FAIL | pitch_MAE(0.1692>0.10) |
| X@1.00 | `fast_high` | 0.1684 | 0.3384 | 0.5455 | 0.0000 | 0.3042 | 0.4401 | -0.4401 | 0.00 | 0.00 | FAIL | pitch_MAE(0.1684>0.10) |
| X@1.50 | `ideal` | 0.0110 | 0.0419 | 0.3311 | 0.0000 | 0.2467 | 0.3176 | -0.3176 | 0.00 | 0.00 | PASS | none |
| X@1.50 | `nominal` | 0.0881 | 0.1402 | 0.0841 | 0.0000 | 0.1748 | 0.6426 | -0.6426 | 0.00 | 0.00 | PASS | none |
| X@1.50 | `slow_low` | 0.2567 | 0.3289 | 0.2473 | 0.0000 | 0.0904 | 1.1131 | -1.1131 | 0.00 | 0.00 | FAIL | pitch_MAE(0.2567>0.10) |
| X@1.50 | `fast_high` | 0.0244 | 0.0816 | 0.3441 | 0.0000 | 0.2416 | 0.3443 | -0.3443 | 0.00 | 0.00 | PASS | none |
| X@2.00 | `ideal` | 0.0350 | 0.0396 | 0.2382 | 0.0000 | 0.1730 | 0.2148 | -0.2148 | 0.00 | 0.00 | PASS | none |
| X@2.00 | `nominal` | 0.0829 | 0.1889 | 0.0874 | 0.0000 | 0.1494 | 0.3069 | -0.3069 | 0.00 | 0.00 | PASS | none |
| X@2.00 | `slow_low` | 0.2696 | 0.3590 | 0.1610 | 0.0000 | 0.0767 | 0.6678 | -0.6678 | 0.00 | 0.00 | FAIL | pitch_MAE(0.2696>0.10) |
| X@2.00 | `fast_high` | 0.0368 | 0.0409 | 0.2285 | 0.0000 | 0.1665 | 0.2484 | -0.2484 | 0.00 | 0.00 | PASS | none |
| XZ@1.00 | `ideal` | 0.2579 | 0.5438 | 0.7772 | 0.0000 | 0.6529 | 0.3358 | -0.3358 | 0.00 | 0.00 | FAIL | pitch_p95(0.5438>0.50) |
| XZ@1.00 | `nominal` | 0.6744 | 1.2336 | 0.8955 | 0.0000 | 0.3441 | 0.6928 | -0.6928 | 0.00 | 0.00 | FAIL | pitch_MAE(0.6744>0.30) |
| XZ@1.00 | `slow_low` | 0.9029 | 1.4379 | 0.6265 | 0.0000 | 0.1088 | 1.3263 | -1.3263 | 0.00 | 0.00 | FAIL | pitch_MAE(0.9029>0.30) |
| XZ@1.00 | `fast_high` | 0.2911 | 0.3871 | 0.8928 | 0.0000 | 0.6140 | 0.3643 | -0.3643 | 0.00 | 0.00 | FAIL | gamma_p95(2.0595>1.50) |
| XZ@1.50 | `ideal` | 0.1537 | 0.5519 | 0.4426 | 0.0000 | 0.3670 | 0.2551 | -0.2551 | 0.00 | 0.00 | FAIL | pitch_p95(0.5519>0.50) |
| XZ@1.50 | `nominal` | 0.3623 | 0.9944 | 0.4003 | 0.0000 | 0.2848 | 0.3991 | -0.3991 | 0.00 | 0.00 | FAIL | pitch_MAE(0.3623>0.30) |
| XZ@1.50 | `slow_low` | 0.7563 | 1.2286 | 0.3413 | 0.0000 | 0.1014 | 0.8932 | -0.8932 | 0.00 | 0.00 | FAIL | pitch_MAE(0.7563>0.30) |
| XZ@1.50 | `fast_high` | 0.1472 | 0.4937 | 0.4389 | 0.0000 | 0.3517 | 0.2862 | -0.2862 | 0.00 | 0.00 | PASS | none |
| XZ@2.00 | `ideal` | 0.3665 | 0.8042 | 0.1693 | 0.0000 | 0.2053 | 0.1562 | -0.1562 | 0.00 | 0.00 | FAIL | pitch_MAE(0.3665>0.30) |
| XZ@2.00 | `nominal` | 0.3524 | 0.9865 | 0.2935 | 0.0000 | 0.1876 | 0.1826 | -0.1826 | 0.00 | 0.00 | FAIL | pitch_MAE(0.3524>0.30) |
| XZ@2.00 | `slow_low` | 0.6708 | 1.2145 | 0.2816 | 0.0000 | 0.0821 | 0.4540 | -0.4540 | 0.00 | 0.00 | FAIL | pitch_MAE(0.6708>0.30) |
| XZ@2.00 | `fast_high` | 0.3947 | 0.8431 | 0.1709 | 0.0000 | 0.1896 | 0.1963 | -0.1963 | 0.00 | 0.00 | FAIL | pitch_MAE(0.3947>0.30) |
| R10@1.50 | `ideal` | 0.0299 | 0.0846 | 0.5980 | 0.1740 | 0.2762 | 0.3478 | -0.3478 | 0.00 | 0.00 | PASS | none |
| R10@1.50 | `nominal` | 0.0904 | 0.2253 | 0.3600 | 0.1880 | 0.2393 | 0.4920 | -0.4920 | 0.00 | 0.00 | PASS | none |
| R10@1.50 | `slow_low` | 0.0781 | 0.1098 | 0.1162 | 0.2580 | 0.1398 | 1.0632 | -1.0632 | 0.00 | 0.00 | PASS | none |
| R10@1.50 | `fast_high` | 0.0466 | 0.1470 | 0.5862 | 0.1802 | 0.2702 | 0.3723 | -0.3723 | 0.00 | 0.00 | PASS | none |
| R10@2.00 | `ideal` | 0.0349 | 0.1270 | 0.4006 | 0.2023 | 0.2176 | 0.2698 | -0.2698 | 0.00 | 0.00 | PASS | none |
| R10@2.00 | `nominal` | 0.0490 | 0.2000 | 0.3259 | 0.2096 | 0.2021 | 0.3382 | -0.3382 | 0.00 | 0.00 | PASS | none |
| R10@2.00 | `slow_low` | 0.0809 | 0.1119 | 0.0850 | 0.2600 | 0.1385 | 0.6755 | -0.6755 | 0.00 | 0.00 | PASS | none |
| R10@2.00 | `fast_high` | 0.0414 | 0.1766 | 0.3991 | 0.2052 | 0.2132 | 0.2985 | -0.2985 | 0.00 | 0.00 | PASS | none |

## Thrust channel

| Case | Variant | mean T [N] | peak abs T [N] | cmd-track RMSE [N] | peak dT/dt [N/s] | slew limit | sat% (hold) | margin to T_max |
|---|---|--:|--:|--:|--:|--:|--:|--:|
| X@1.00 | `ideal` | 3.3358 | 13.3938 | 0.0000 | 9.181 | Inf | 0.00 | 0.9554 |
| X@1.00 | `nominal` | 6.0601 | 13.4000 | 19.4971 | 0.640 | 8 | 0.00 | 0.9553 |
| X@1.00 | `slow_low` | 11.5656 | 13.3959 | 33.1587 | 0.163 | 4 | 0.00 | 0.9553 |
| X@1.00 | `fast_high` | 2.9176 | 13.7687 | 4.3472 | 2.456 | 16 | 0.00 | 0.9541 |
| X@1.50 | `ideal` | 5.4611 | 13.3906 | 0.0000 | 7.585 | Inf | 0.00 | 0.9554 |
| X@1.50 | `nominal` | 6.3158 | 13.4000 | 11.4645 | 0.640 | 8 | 0.00 | 0.9553 |
| X@1.50 | `slow_low` | 11.6411 | 13.3959 | 23.4339 | 0.163 | 4 | 0.00 | 0.9553 |
| X@1.50 | `fast_high` | 5.4870 | 13.8217 | 2.5764 | 2.456 | 16 | 0.00 | 0.9539 |
| X@2.00 | `ideal` | 8.0293 | 13.3875 | 0.0000 | 5.358 | Inf | 0.00 | 0.9554 |
| X@2.00 | `nominal` | 8.0458 | 13.4000 | 4.9155 | 0.640 | 8 | 0.00 | 0.9553 |
| X@2.00 | `slow_low` | 11.7064 | 13.3959 | 14.1694 | 0.163 | 4 | 0.00 | 0.9553 |
| X@2.00 | `fast_high` | 8.2604 | 13.9361 | 1.5044 | 2.456 | 16 | 0.00 | 0.9535 |
| XZ@1.00 | `ideal` | 5.0048 | 13.3938 | 0.0000 | 7.604 | Inf | 0.00 | 0.9554 |
| XZ@1.00 | `nominal` | 5.5931 | 13.4000 | 13.0443 | 0.640 | 8 | 0.00 | 0.9553 |
| XZ@1.00 | `slow_low` | 11.4391 | 13.3959 | 28.7514 | 0.163 | 4 | 0.00 | 0.9553 |
| XZ@1.00 | `fast_high` | 4.9056 | 13.8183 | 2.7929 | 2.456 | 16 | 0.00 | 0.9539 |
| XZ@1.50 | `ideal` | 7.0236 | 13.3906 | 0.0000 | 6.011 | Inf | 0.00 | 0.9554 |
| XZ@1.50 | `nominal` | 7.1560 | 13.4000 | 6.8745 | 0.640 | 8 | 0.00 | 0.9553 |
| XZ@1.50 | `slow_low` | 11.5288 | 13.3959 | 19.6703 | 0.163 | 4 | 0.00 | 0.9553 |
| XZ@1.50 | `fast_high` | 7.1706 | 13.8940 | 1.6981 | 2.456 | 16 | 0.00 | 0.9537 |
| XZ@2.00 | `ideal` | 9.4942 | 13.3875 | 0.0000 | 599.497 | Inf | 0.00 | 0.9554 |
| XZ@2.00 | `nominal` | 9.3312 | 13.4000 | 4.2119 | 0.640 | 8 | 0.00 | 0.9553 |
| XZ@2.00 | `slow_low` | 11.6064 | 13.3959 | 11.0313 | 0.163 | 4 | 0.00 | 0.9553 |
| XZ@2.00 | `fast_high` | 9.7675 | 14.0538 | 3.8153 | 2.456 | 16 | 0.00 | 0.9532 |
| R10@1.50 | `ideal` | 4.7055 | 13.2206 | 0.0000 | 14.082 | Inf | 0.00 | 0.9559 |
| R10@1.50 | `nominal` | 5.1502 | 13.3857 | 9.5590 | 0.640 | 8 | 0.00 | 0.9554 |
| R10@1.50 | `slow_low` | 9.3189 | 13.3959 | 22.9616 | 0.163 | 4 | 0.00 | 0.9553 |
| R10@1.50 | `fast_high` | 4.7047 | 13.7392 | 2.6125 | 2.456 | 16 | 0.00 | 0.9542 |
| R10@2.00 | `ideal` | 6.6552 | 13.1608 | 0.0000 | 14.264 | Inf | 0.00 | 0.9561 |
| R10@2.00 | `nominal` | 6.8085 | 13.3840 | 5.9719 | 0.640 | 8 | 0.00 | 0.9554 |
| R10@2.00 | `slow_low` | 9.3189 | 13.3959 | 14.5928 | 0.163 | 4 | 0.00 | 0.9553 |
| R10@2.00 | `fast_high` | 6.8213 | 13.7672 | 1.8561 | 2.456 | 16 | 0.00 | 0.9541 |

## Propulsion / power / energy budget

### Component-neutral model (ASSUMED / TO_BE_IDENTIFIED ranges)

| Quantity | Range | Status |
|---|---|---|
| seawater density | 1025 kg/m^3 | ASSUMED fixed |
| propulsor disk diameter | 0.1 – 0.18 m | TO_BE_IDENTIFIED |
| propeller efficiency | 0.45 – 0.70 | TO_BE_IDENTIFIED |
| motor efficiency | 0.75 – 0.90 | TO_BE_IDENTIFIED |
| drive/ESC efficiency | 0.90 – 0.97 | TO_BE_IDENTIFIED |
| avionics + compute hotel load | 8 – 25 W | TO_BE_IDENTIFIED |
| fin servo hold / slew | 0.5 – 2.0 W / 3.0 – 12.0 W | TO_BE_IDENTIFIED |
| usable battery energy | 150 – 600 Wh | TO_BE_IDENTIFIED |
| DC bus window | 22.2 – 29.4 V | TO_BE_IDENTIFIED |
| continuous bus current limit | 15 – 40 A | TO_BE_IDENTIFIED |
| reference mission distance | 1.00 km | ASSUMED scaling basis |

Actuator-disk momentum theory gives the ideal (lower-bound) hydrodynamic power for the realized thrust; electrical power is that bound divided by an efficiency-chain range, plus avionics and fin-servo loads. Component-neutral: no vendor, no part number.

Hardware corners evaluated (worst / nominal / best):

| Corner | disk area [m^2] | eta chain | avionics [W] | V bus [V] | usable [Wh] | I cont [A] |
|---|--:|--:|--:|--:|--:|--:|
| worst | 0.00785 | 0.3038 | 25.0 | 22.2 | 150 | 15 |
| nominal | 0.01539 | 0.4435 | 16.5 | 25.8 | 375 | 28 |
| best | 0.02545 | 0.6111 | 8.0 | 29.4 | 600 | 40 |

### Budget per case (worst corner unless stated)

| Case | Variant | hydro ideal [W] | bus mean [W] | bus peak [W] | Wh/km worst | Wh/km best | mission Wh | I peak [A] | energy margin | current margin | endurance [km] |
|---|---|--:|--:|--:|--:|--:|--:|--:|--:|--:|--:|
| X@1.00 | `ideal` | 6.03 | 47.46 | 104.04 | 9.54 | 3.57 | 9.54 | 4.69 | +0.936 | +0.688 | 15.7 |
| X@1.00 | `nominal` | 16.75 | 82.46 | 118.80 | 11.67 | 4.79 | 11.67 | 5.35 | +0.922 | +0.643 | 12.8 |
| X@1.00 | `slow_low` | 30.98 | 129.36 | 138.05 | 15.45 | 6.62 | 15.45 | 6.22 | +0.897 | +0.585 | 9.7 |
| X@1.00 | `fast_high` | 7.28 | 51.22 | 109.59 | 9.71 | 3.67 | 9.71 | 4.94 | +0.935 | +0.671 | 15.4 |
| X@1.50 | `ideal` | 11.70 | 66.02 | 121.23 | 10.18 | 4.09 | 10.18 | 5.46 | +0.932 | +0.636 | 14.7 |
| X@1.50 | `nominal` | 18.43 | 88.11 | 127.57 | 11.62 | 4.84 | 11.62 | 5.75 | +0.923 | +0.617 | 12.9 |
| X@1.50 | `slow_low` | 32.46 | 134.29 | 141.52 | 15.17 | 6.56 | 15.17 | 6.37 | +0.899 | +0.575 | 9.9 |
| X@1.50 | `fast_high` | 12.83 | 69.68 | 127.72 | 10.44 | 4.22 | 10.44 | 5.75 | +0.930 | +0.616 | 14.4 |
| X@2.00 | `ideal` | 20.08 | 93.52 | 139.95 | 11.78 | 4.98 | 11.78 | 6.30 | +0.921 | +0.580 | 12.7 |
| X@2.00 | `nominal` | 23.11 | 103.47 | 142.34 | 12.45 | 5.31 | 12.45 | 6.41 | +0.917 | +0.573 | 12.1 |
| X@2.00 | `slow_low` | 33.82 | 138.75 | 146.29 | 14.94 | 6.52 | 14.94 | 6.59 | +0.900 | +0.561 | 10.0 |
| X@2.00 | `fast_high` | 21.30 | 97.52 | 147.79 | 12.07 | 5.12 | 12.07 | 6.66 | +0.920 | +0.556 | 12.4 |
| XZ@1.00 | `ideal` | 8.26 | 55.31 | 104.19 | 11.60 | 4.40 | 11.60 | 4.69 | +0.923 | +0.687 | 12.9 |
| XZ@1.00 | `nominal` | 13.73 | 73.19 | 114.43 | 12.21 | 4.87 | 12.21 | 5.15 | +0.919 | +0.656 | 12.3 |
| XZ@1.00 | `slow_low` | 28.38 | 121.47 | 129.73 | 15.59 | 6.59 | 15.59 | 5.84 | +0.896 | +0.610 | 9.6 |
| XZ@1.00 | `fast_high` | 9.11 | 57.99 | 109.80 | 11.67 | 4.46 | 11.67 | 4.95 | +0.922 | +0.670 | 12.9 |
| XZ@1.50 | `ideal` | 14.41 | 75.23 | 121.41 | 11.97 | 4.84 | 11.97 | 5.47 | +0.920 | +0.635 | 12.5 |
| XZ@1.50 | `nominal` | 17.71 | 86.07 | 126.07 | 12.60 | 5.18 | 12.60 | 5.68 | +0.916 | +0.621 | 11.9 |
| XZ@1.50 | `slow_low` | 29.66 | 126.01 | 134.05 | 15.34 | 6.54 | 15.34 | 6.04 | +0.898 | +0.597 | 9.8 |
| XZ@1.50 | `fast_high` | 15.32 | 78.21 | 128.13 | 12.15 | 4.94 | 12.15 | 5.77 | +0.919 | +0.615 | 12.3 |
| XZ@2.00 | `ideal` | 22.34 | 101.18 | 140.18 | 13.12 | 5.53 | 13.12 | 6.31 | +0.913 | +0.579 | 11.4 |
| XZ@2.00 | `nominal` | 24.15 | 107.28 | 141.07 | 13.63 | 5.77 | 13.63 | 6.35 | +0.909 | +0.576 | 11.0 |
| XZ@2.00 | `slow_low` | 30.84 | 130.14 | 145.88 | 15.14 | 6.50 | 15.14 | 6.57 | +0.899 | +0.562 | 9.9 |
| XZ@2.00 | `fast_high` | 24.12 | 107.20 | 148.57 | 13.61 | 5.77 | 13.61 | 6.69 | +0.909 | +0.554 | 11.0 |
| R10@1.50 | `ideal` | 8.34 | 64.39 | 119.98 | 11.44 | 4.21 | 11.44 | 5.40 | +0.924 | +0.640 | 13.1 |
| R10@1.50 | `nominal` | 11.83 | 75.87 | 129.00 | 12.20 | 4.66 | 12.20 | 5.81 | +0.919 | +0.613 | 12.3 |
| R10@1.50 | `slow_low` | 24.44 | 117.42 | 147.67 | 14.56 | 5.99 | 14.56 | 6.65 | +0.903 | +0.557 | 10.3 |
| R10@1.50 | `fast_high` | 9.14 | 67.03 | 126.42 | 11.60 | 4.31 | 11.60 | 5.69 | +0.923 | +0.620 | 12.9 |
| R10@2.00 | `ideal` | 13.98 | 82.96 | 138.01 | 12.18 | 4.76 | 12.18 | 6.22 | +0.919 | +0.586 | 12.3 |
| R10@2.00 | `nominal` | 16.39 | 90.90 | 142.17 | 12.75 | 5.06 | 12.75 | 6.40 | +0.915 | +0.573 | 11.8 |
| R10@2.00 | `slow_low` | 24.95 | 119.10 | 152.71 | 14.48 | 5.98 | 14.48 | 6.88 | +0.903 | +0.541 | 10.4 |
| R10@2.00 | `fast_high` | 14.94 | 86.14 | 145.41 | 12.40 | 4.87 | 12.40 | 6.55 | +0.917 | +0.563 | 12.1 |

- Worst-corner energy margin across all runs: **+0.896** | worst-corner current margin: **+0.541**
- Margins are conditional on the ASSUMED ranges above and certify no hardware.

## Fin duty

| Case | Variant | moving duty % | elevator duty % | rudder duty % | elev mag util % | rud mag util % |
|---|---|--:|--:|--:|--:|--:|
| X@1.00 | `ideal` | 5.97 | 5.97 | 0.00 | 51.26 | 0.00 |
| X@1.00 | `nominal` | 3.06 | 3.06 | 0.00 | 25.00 | 0.00 |
| X@1.00 | `slow_low` | 3.75 | 3.75 | 0.00 | 16.83 | 0.00 |
| X@1.00 | `fast_high` | 2.36 | 2.36 | 0.00 | 48.74 | 0.00 |
| X@1.50 | `ideal` | 5.14 | 5.14 | 0.00 | 31.96 | 0.00 |
| X@1.50 | `nominal` | 4.31 | 4.31 | 0.00 | 23.55 | 0.00 |
| X@1.50 | `slow_low` | 4.17 | 4.17 | 0.00 | 15.95 | 0.00 |
| X@1.50 | `fast_high` | 4.31 | 4.31 | 0.00 | 31.09 | 0.00 |
| X@2.00 | `ideal` | 4.17 | 4.17 | 0.00 | 21.97 | 0.00 |
| X@2.00 | `nominal` | 4.03 | 4.03 | 0.00 | 20.30 | 0.00 |
| X@2.00 | `slow_low` | 4.03 | 4.03 | 0.00 | 15.24 | 0.00 |
| X@2.00 | `fast_high` | 4.03 | 4.03 | 0.00 | 21.35 | 0.00 |
| XZ@1.00 | `ideal` | 11.02 | 11.02 | 0.00 | 8.79 | 0.00 |
| XZ@1.00 | `nominal` | 9.77 | 9.77 | 0.00 | 7.65 | 0.00 |
| XZ@1.00 | `slow_low` | 10.57 | 10.57 | 0.00 | 5.78 | 0.00 |
| XZ@1.00 | `fast_high` | 10.11 | 10.11 | 0.00 | 8.71 | 0.00 |
| XZ@1.50 | `ideal` | 8.07 | 8.07 | 0.00 | 8.48 | 0.00 |
| XZ@1.50 | `nominal` | 7.61 | 7.61 | 0.00 | 7.81 | 0.00 |
| XZ@1.50 | `slow_low` | 13.52 | 13.52 | 0.00 | 5.65 | 0.00 |
| XZ@1.50 | `fast_high` | 7.61 | 7.61 | 0.00 | 8.40 | 0.00 |
| XZ@2.00 | `ideal` | 6.36 | 6.36 | 0.00 | 6.93 | 0.00 |
| XZ@2.00 | `nominal` | 7.73 | 7.73 | 0.00 | 6.75 | 0.00 |
| XZ@2.00 | `slow_low` | 16.14 | 16.14 | 0.00 | 5.51 | 0.00 |
| XZ@2.00 | `fast_high` | 7.84 | 7.84 | 0.00 | 6.75 | 0.00 |
| R10@1.50 | `ideal` | 99.33 | 1.61 | 98.83 | 37.42 | 17.03 |
| R10@1.50 | `nominal` | 99.17 | 1.67 | 98.78 | 32.78 | 16.80 |
| R10@1.50 | `slow_low` | 99.56 | 1.67 | 99.17 | 17.25 | 16.73 |
| R10@1.50 | `fast_high` | 99.56 | 1.61 | 99.17 | 36.33 | 16.90 |
| R10@2.00 | `ideal` | 99.44 | 1.44 | 99.44 | 25.95 | 17.03 |
| R10@2.00 | `nominal` | 99.50 | 1.44 | 99.50 | 24.25 | 16.88 |
| R10@2.00 | `slow_low` | 99.67 | 1.44 | 99.67 | 17.04 | 16.67 |
| R10@2.00 | `fast_high` | 99.44 | 1.44 | 99.44 | 25.14 | 16.98 |

"Moving" means fin rate above 5% of the frozen 40 deg/s slew limit.

## Compute evidence

| Quantity | Value |
|---|--:|
| controller call rate | 40 Hz |
| guidance call rate | 13.33 Hz (every 3 control steps) |
| runs executed | 40 |
| guidance calls | 14010 |
| controller calls | 42000 |
| integrator steps | 42000 |
| plant RHS evaluations | 2564886 |
| plant RHS per control step | 61.07 |
| host runtime per control step, mean | 34.043 ms |
| host runtime per control step, p95 (worst run) | 156.809 ms |
| host runtime per control step, max | 1627.458 ms |
| host duty vs control period, mean / max | 1.3617 / 3.2599 |
| total in-loop host time | 1478.2 s |

**Host runtime on a general-purpose OS is NOT a worst-case execution time and carries no real-time guarantee. WCET remains TO_BE_IDENTIFIED on target hardware.**

Note that the host figure includes the `ode45` plant integration, which is simulation overhead and would not exist on the target. It is reported as measured and is deliberately not decomposed into a flight-software estimate.

## Pareto vector (ASSUMED variants)

| Variant | max pitch MAE [deg] | peak thrust [N] | worst-corner mission Wh [Wh/km-mission] | worst-corner peak bus current [A] | fin moving duty [%] | host runtime [ms/step] | non-dominated |
|---|--:|--:|--:|--:|--:|--:|:--:|
| `ideal` | 0.3665 | 13.394 | 13.12 | 6.31 | 99.44 | 30.733 | YES |
| `nominal` | 0.6744 | 13.400 | 13.63 | 6.41 | 99.50 | 30.666 | YES |
| `slow_low` | 0.9029 | 13.396 | 15.59 | 6.88 | 99.67 | 36.009 | NO |
| `fast_high` | 0.3947 | 14.054 | 13.61 | 6.69 | 99.56 | 40.003 | NO |

- Sense: all objectives minimized (worst case over all cases for each variant).
- Non-dominated set: **ideal, nominal**
- The Pareto set ranks ASSUMED variants against each other only. It selects no hardware.

## Gate ledger

| Gate | Class | Result | Detail |
|---|---|:--:|---|
| G1 ideal parity (bitwise vs bypass) | MANDATORY | PASS | 8/8 cases bitwise identical; max/diff/ over cases = 0 |
| G2 finite / bounded states, all runs | MANDATORY | PASS | 40 runs finite and bounded |
| G3 existing pitch/gamma/yaw/actuator gates (ideal) | MANDATORY | FAIL | X@1.00:pitch_MAE(0.1744>0.10); XZ@1.00:pitch_p95(0.5438>0.50); XZ@1.50:pitch_p95(0.5519>0.50); XZ@2.00:pitch_MAE(0.3665>0.30);  |
| G3C existing gates under ASSUMED variants | CONDITIONAL | FAIL | X@1.00/slow_low:pitch_MAE(0.1692>0.10); X@1.00/fast_high:pitch_MAE(0.1684>0.10); X@1.50/slow_low:pitch_MAE(0.2567>0.10); X@2.00/slow_low:pitch_MAE(0.2696>0.10); XZ@1.00/nominal:pitch_MAE(0.6744>0.30); XZ@1.00/slow_low... |
| G4 thrust magnitude/rate limit compliance | MANDATORY | PASS | realized thrust in [-100.000, 300.000] N and within the declared slew limit for all 32 runs |
| G5 battery/current envelope (worst ASSUMED corner) | CONDITIONAL | PASS | worst-corner energy margin 0.896 (XZ@1.00/slow_low), current margin 0.541; CONDITIONAL on ASSUMED hardware ranges.  |
| G6 deterministic replay (bitwise) | MANDATORY | PASS | X@1.50 ideal re-run: max/diff/ = 0 (all channels bitwise equal) |
| G7 exact production / CODEX_VERTICAL_PLAN fingerprints | MANDATORY | PASS | 8 files byte-identical pre/post run (production untouched) |
| G8 readable artifacts (md/mat/png) | MANDATORY | FAIL | pending |

Rule: any MANDATORY gate failing gives FAIL. All mandatory met with a CONDITIONAL gate failing gives PARTIAL, because conditional gates rest on ASSUMED hardware numbers. All gates met gives PASS.

## Decision

- Verdict: **FAIL**
- Limiting gate(s): G3,G3C
- Limiting case: XZ@2.00 / ideal (pitch_MAE(0.3665>0.30))
- Next structure: Tracking, not propulsion, is limiting at the ideal actuator. The next bounded structure is a speed/route-scheduled reference governor for the frozen cascade, evaluated in its own isolated gate before any power budget is reopened. No rerun and no gain change in this task.
- Next gate: `BLOCKED (Gate6B requires PASS)`
- No rerun, no retune, no promotion. Gate6B is unlocked only by a PASS.

## Artifact self-check (post-write) and FINAL VERDICT

| Artifact | Bytes | Readable | Note |
|---|--:|:--:|---|
| `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\PROPULSION_POWER_COMPUTE_BASELINE.png` | 235763 | YES | >= 20000 B required |
| `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\PROPULSION_POWER_COMPUTE_BASELINE.md` | 24145 | YES | required sections present: YES |
| `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\PROPULSION_POWER_COMPUTE_BASELINE.mat` | 12482882 | YES | reloadable via matfile: YES |

- G8 readable artifacts: **PASS**
- Host runtime (whole task, one MATLAB invocation): **1610.4 s**
- Task workspace footprint: **21.2 MiB** against the 300 MiB budget (whole MATLAB process, including its own baseline, 2482.8 MiB)

### FINAL VERDICT: FAIL

FAIL: mandatory gate(s) G3 not met. Conditional gate(s) not met: G3C. No rerun and no tuning performed in this task.

- Promotion: **NONE** (Gate6 isolated budget study).
- Status: **SIMULATION_ONLY / NOT_CERTIFIED**. Gate4 evidence shadow-only.
- Next: `BLOCKED (Gate6B requires PASS)`
