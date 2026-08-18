# NAV_MULTIRATE_EKF_BASELINE_001 - Gate 5B isolated multirate EKF + availability manager

**Overall verdict: PASS** - 12/12 frozen Gate 5A cases pass every integrity gate, 28/28 hard gates pass. **Integrity and interface decide this baseline. Accuracy is CHARACTERIZATION ONLY and NOT_CERTIFIED. No promotion is made by this task. Simulation-only.**

## What this task is, and what it deliberately is not

Gate 5A formalized a MEASURED sensor-chain contract with an ESTIMATED bus that was INVALID by construction. Gate 5B is the first task in this line that produces an estimate at all. It is therefore judged on whether the estimator and its availability manager are *structurally trustworthy* - finite, symmetric-PSD, monotonic, truth-blind, deterministic, and incapable of fusing a packet the bus declared unusable - and **not** on how small its errors are. Every sensor numeric upstream is ASSUMED, so an accuracy claim here would be unfounded no matter how good the numbers looked.

- This run: MATLAB 2025b, pid 23744, started 2026-08-08 15:16:39, single `-batch` invocation:

```
/mnt/d/ardak/matlab/bin/matlab.exe -batch "cd('C:/Users/ardak/MATLAB/Projects/AUVsim-main'); run_nav_multirate_ekf_baseline;"
```

Static review of both sources and of the two new files preceded execution, and MATLAB was never started for probing, so the single permitted invocation was spent on the baseline itself.

## Sources read (exactly three, no repo scan)

| # | Source | Used for |
|---|---|---|
| 1 | `navigation_multirate_sensor_chain.m` | frozen Gate 5A sensor-chain library: statically reviewed, then executed unchanged to regenerate the bus |
| 2 | `NAV_MULTIRATE_SENSOR_CHAIN_VALIDATION.mat` | frozen Gate 5A validation record: 12-case matrix, seeds, tick counts, availability and fingerprints |
| 3 | `NAV_MULTIRATE_SENSOR_CHAIN_VALIDATION.md` | frozen Gate 5A validation report: formalized gate decision, declared Gate 5B scope, honesty invariants |

Exactly three sources. run_nav_multirate_sensor_chain.m was NOT read: the frozen 12-case matrix is taken from the Gate 5A validation record instead, and the regenerated matrix is proved identical to it by seed / tick / availability parity.

### Static review markers

| Marker | Found |
|---|:---:|
| `lib_dt_base` | YES |
| `lib_outage_frac` | YES |
| `lib_usbl_absent` | YES |
| `lib_est_unavailable_5a` | YES |
| `lib_dvl_water_relative` | YES |
| `ekf_joseph` | YES |
| `ekf_error_state_18` | YES |
| `ekf_quaternion` | YES |
| `ekf_angle_wrapping` | YES |
| `ekf_dvl_water_model` | YES |
| `ekf_truth_firewall` | YES |
| `ekf_reset_jacobian` | YES |
| `ekf_admission_order` | YES |
| `drv_frozen_12_cases` | YES |
| `drv_no_tuning_rerun` | YES |
| `all_ok` | YES |

## Predeclared model, gates and provenance (fixed before the run)

### State and measurement models (IMPLEMENTED)

```
nominal : p_NED [m], v_NED [m/s], q_bn (body->NED), b_g [rad/s], b_a [m/s^2], c_NED [m/s]
error   : [dp(3) NED | dv(3) NED | dtheta(3) BODY | db_g(3) | db_a(3) | dc(3) NED]  (18)
propagate (IMU 100 Hz, timestamp driven):
  w = w_m - b_g ;  f = f_m - b_a ;  a_NED = R_bn f + [0;0;g]
  p+ = p + v dt + 0.5 a dt^2 ;  v+ = v + a dt ;  q+ = q (x) dq(w dt)
  dv/dt  = -R_bn [f]x dtheta - R_bn db_a ;  dtheta/dt = -[w]x dtheta - db_g
updates (each at its own arrival tick, gated on valid/quality/stale_age/sequence):
  depth      h = p_D                          [m]      H = e3' on dp
  heading    h = psi(q), innovation wrapped   [rad]    H = [0 sin(phi)/cos(th) cos(phi)/cos(th)] on dtheta
  INS vel    h = v_NED                        [m/s]    H = I on dv
  DVL        h = R_bn' (v_NED - c_NED)        [m/s]    H = [R' on dv, -R' on dc, [R'(v-c)]x on dtheta]
  USBL       ABSENT - never emits, never fused
covariance : Joseph  P = (I-KH) P (I-KH)' + K R K', symmetrized, error-state reset
             Jacobian G = I with G_thth = I - 0.5 [dtheta]x, quaternion renormalized
```

### Q / R / initial covariance (predeclared)

| Quantity | Value | Units | Provenance |
|---|---|---|---|
| `sigma_a` | 0.002 | m/s^2/sqrt(Hz) | DERIVED 0.020*sqrt(0.01) from declared ASSUMED accel sigma and rate |
| `sigma_g` | 0.00035 | rad/s/sqrt(Hz) | DERIVED 0.0035*sqrt(0.01) from declared ASSUMED gyro sigma and rate |
| `sigma_bg` | 1e-05 | rad/s/sqrt(s) | ASSUMED gyro bias random walk |
| `sigma_ba` | 0.0001 | m/s^2/sqrt(s) | ASSUMED accel bias random walk |
| `sigma_c` | 0.001 | m/s/sqrt(s) | ASSUMED NED current random walk |
| `R depth` | 0.0004 | m^2 | ASSUMED = declared sensor sigma^2 |
| `R heading` | 7.62e-05 | rad^2 | ASSUMED = declared sensor sigma^2 (0.5 deg) |
| `R ins_vel` | diag(4.0e-04 4.0e-04 9.0e-04) | (m/s)^2 | ASSUMED = declared sensor sigma^2 |
| `R dvl` | diag(1.0e-04 1.0e-04 2.2e-04) | (m/s)^2 | ASSUMED = declared sensor sigma^2 |
| `P0 p` | [0.01 0.01 0.25] | m^2 | ASSUMED; N/E is relative-solution conditioning, not a fix |
| `P0 v` | [0.09 0.09 0.09] | (m/s)^2 | ASSUMED |
| `P0 tilt` | [0.0012 0.0012 0.0027] | rad^2 | ASSUMED (2/2/3 deg) |
| `P0 b_g` | [0.0001 0.0001 0.0001] | (rad/s)^2 | ASSUMED |
| `P0 b_a` | [0.0025 0.0025 0.0025] | (m/s^2)^2 | ASSUMED |
| `P0 c` | [0.25 0.25 0.25] | (m/s)^2 | ASSUMED |
| `q_min_frac` | 0.20 | - | ASSUMED admission floor as a fraction of declared q_nom |
| `nis_scale` | 100 | - | ASSUMED divergence guard = scale x measurement dimension |

R is deliberately **not** inflated to absorb the declared ASSUMED sensor biases (depth +0.050 m, heading +1.0 deg, INS velocity [0.005 0.004 -0.003] m/s, DVL [0.002 -0.002 0.003] m/s plus 0.2% scale). Those biases are unmodelled states, so they appear honestly as innovation bias and NIS above unity. Inflating R until NIS looked consistent would be tuning, and is exactly what this task forbids.

NO_TUNING_RERUN: every Q/R/P0/threshold is the predeclared ASSUMED value; no case-specific constant exists and no rerun was performed after seeing results.

## Hard gates (predeclared and immutable)

| # | Hard gate | Result |
|---:|---|:---:|
| 1 | `finite_state_covariance` | PASS |
| 2 | `covariance_symmetric_psd` | PASS |
| 3 | `monotonic_estimate_time_sequence` | PASS |
| 4 | `quaternion_norm` | PASS |
| 5 | `no_truth_leakage` | PASS |
| 6 | `no_invalid_packet_fused` | PASS |
| 7 | `zero_dvl_updates_in_outage` | PASS |
| 8 | `deterministic_replay` | PASS |
| 9 | `usbl_never_fused` | PASS |
| 10 | `estimated_invalid_before_init` | PASS |
| 11 | `estimated_valid_after_init` | PASS |
| 12 | `estimated_interface_complete` | PASS |
| 13 | `single_explicit_initialization` | PASS |
| 14 | `manager_counter_invariant` | PASS |
| 15 | `fused_packet_ordering` | PASS |
| 16 | `manager_rejects_injected_faults` | PASS |
| 17 | `dvl_resume_without_reset` | PASS |
| 18 | `frozen_case_matrix_parity` | PASS |
| 19 | `cases_12_of_12` | PASS |
| 20 | `declared_asserts` | PASS |
| 21 | `sources_exactly_three` | PASS |
| 22 | `single_matlab_process` | PASS |
| 23 | `production_fingerprints_exact` | PASS |
| 24 | `codex_vertical_plan_untouched` | PASS |
| 25 | `gate4_waiver_shadow_only` | PASS |
| 26 | `no_promotion_in_this_task` | PASS |
| 27 | `visual_qa_png_readable` | PASS |
| 28 | `artifacts_under_300MiB` | PASS |

**Hard gates: 28/28 PASS.**

### Per-case integrity gates (evaluated from the ESTIMATED bus alone, no truth)

| Gate | Cases passing |
|---|:---:|
| `finite_state_covariance` | 12/12 |
| `covariance_symmetric_psd` | 12/12 |
| `monotonic_estimate_time_sequence` | 12/12 |
| `quaternion_norm` | 12/12 |
| `no_invalid_packet_fused` | 12/12 |
| `fused_packet_ordering` | 12/12 |
| `usbl_never_fused` | 12/12 |
| `estimated_invalid_before_init` | 12/12 |
| `estimated_valid_after_init` | 12/12 |
| `single_explicit_initialization` | 12/12 |
| `manager_counter_invariant` | 12/12 |
| `estimated_interface_complete` | 12/12 |

## Frozen 12-case matrix (regenerated, parity proved against the Gate 5A record)

| # | Case | Route | Vc [m/s NED] | DVL | N | seed | DVL avail [%] | EKF avail [%] | init t [s] | fused | checksum | Integrity |
|---:|---|---|---|---|---:|---:|---:|---:|---:|---:|---|:---:|
| 1 | `X_Vc0_lock` | X | [0.00 0.00 0.00] | lock | 3601 | 1736306363 | 99.44 | 99.78 | 0.040 | 1526 | `7F1F5C60` | PASS |
| 2 | `X_Vc0_outage` | X | [0.00 0.00 0.00] | outage | 3601 | 1719528744 | 78.92 | 99.78 | 0.040 | 1506 | `0C1D8318` | PASS |
| 3 | `X_Vc_E015_lock` | X | [0.00 0.15 0.00] | lock | 3601 | 70806246 | 99.44 | 99.78 | 0.040 | 1526 | `60B33CAC` | PASS |
| 4 | `X_Vc_E015_outage` | X | [0.00 0.15 0.00] | outage | 3601 | 54028627 | 78.92 | 99.78 | 0.040 | 1506 | `D8E897A3` | PASS |
| 5 | `XZ_Vc0_lock` | XZ | [0.00 0.00 0.00] | lock | 4401 | 637068955 | 99.55 | 99.82 | 0.040 | 1866 | `0211D206` | PASS |
| 6 | `XZ_Vc0_outage` | XZ | [0.00 0.00 0.00] | outage | 4401 | 620291336 | 78.21 | 99.82 | 0.040 | 1841 | `78DD0008` | PASS |
| 7 | `XZ_Vc_E015_lock` | XZ | [0.00 0.15 0.00] | lock | 4401 | 2100020421 | 99.55 | 99.82 | 0.040 | 1866 | `44A561F6` | PASS |
| 8 | `XZ_Vc_E015_outage` | XZ | [0.00 0.15 0.00] | outage | 4401 | 2083242802 | 78.21 | 99.82 | 0.040 | 1841 | `BB832448` | PASS |
| 9 | `R10_Vc0_lock` | R10 | [0.00 0.00 0.00] | lock | 9001 | 1001993762 | 99.78 | 99.91 | 0.040 | 3821 | `87D9737D` | PASS |
| 10 | `R10_Vc0_outage` | R10 | [0.00 0.00 0.00] | outage | 9001 | 1018771381 | 78.24 | 99.91 | 0.040 | 3771 | `33D2D9AB` | PASS |
| 11 | `R10_Vc_E015_lock` | R10 | [0.00 0.15 0.00] | lock | 9001 | 746023432 | 99.78 | 99.91 | 0.040 | 3821 | `0FF25E86` | PASS |
| 12 | `R10_Vc_E015_outage` | R10 | [0.00 0.15 0.00] | outage | 9001 | 762801051 | 78.24 | 99.91 | 0.040 | 3771 | `602B180B` | PASS |

Case labels, tick counts, seeds and DVL availability are identical to the Gate 5A validation record (labels YES, N YES, seeds YES, availability max deviation 0). Only the frozen 12 were regenerated; no case was added, removed or reshaped.

## Accuracy characterization (NOT_CERTIFIED)

Position is reported as **displacement drift** because USBL is absent: with no absolute fix the estimator defines its own navigation origin at initialization, so an absolute N/E error would just be the origin offset. Absolute error is listed alongside for completeness.

| Case | pos drift RMSE [m] | pos abs RMSE N/E/D [m] | vel RMSE [m/s] | att RMSE r/p/y [deg] | vbw RMSE [m/s] | current RMSE [m/s] |
|---|---:|---|---:|---|---|---:|
| `X_Vc0_lock` | 0.068 | 0.03 / 0.04 / 0.046 | 0.010 | 0.09 / 0.15 / 1.02 | 0.005 / 0.006 / 0.003 | 0.019 |
| `X_Vc0_outage` | 0.074 | 0.03 / 0.05 / 0.047 | 0.010 | 0.09 / 0.09 / 0.99 | 0.009 / 0.006 / 0.007 | 0.020 |
| `X_Vc_E015_lock` | 0.074 | 0.02 / 0.04 / 0.049 | 0.011 | 0.10 / 0.10 / 1.01 | 0.007 / 0.010 / 0.004 | 0.023 |
| `X_Vc_E015_outage` | 0.078 | 0.03 / 0.04 / 0.047 | 0.010 | 0.09 / 0.08 / 0.95 | 0.010 / 0.009 / 0.006 | 0.022 |
| `XZ_Vc0_lock` | 0.090 | 0.04 / 0.05 / 0.037 | 0.010 | 0.12 / 0.08 / 0.98 | 0.006 / 0.005 / 0.008 | 0.021 |
| `XZ_Vc0_outage` | 0.080 | 0.03 / 0.04 / 0.038 | 0.010 | 0.09 / 0.08 / 1.03 | 0.006 / 0.006 / 0.005 | 0.022 |
| `XZ_Vc_E015_lock` | 0.085 | 0.03 / 0.06 / 0.037 | 0.010 | 0.10 / 0.11 / 1.06 | 0.006 / 0.010 / 0.005 | 0.020 |
| `XZ_Vc_E015_outage` | 0.092 | 0.04 / 0.04 / 0.036 | 0.010 | 0.08 / 0.07 / 0.99 | 0.007 / 0.010 / 0.005 | 0.022 |
| `R10_Vc0_lock` | 0.191 | 9.89 / 0.09 / 0.045 | 0.011 | 0.08 / 0.07 / 0.67 | 0.011 / 0.020 / 0.004 | 0.018 |
| `R10_Vc0_outage` | 0.196 | 9.89 / 0.10 / 0.047 | 0.011 | 0.08 / 0.06 / 0.69 | 0.011 / 0.023 / 0.005 | 0.020 |
| `R10_Vc_E015_lock` | 0.183 | 9.89 / 0.09 / 0.046 | 0.012 | 0.10 / 0.21 / 0.66 | 0.014 / 0.021 / 0.007 | 0.021 |
| `R10_Vc_E015_outage` | 0.192 | 9.89 / 0.09 / 0.046 | 0.012 | 0.07 / 0.15 / 0.71 | 0.014 / 0.026 / 0.004 | 0.022 |

### Innovation and NIS per channel (units and frames declared)

| Case | depth innov RMS [m] / NIS | heading innov RMS [deg] / NIS | INS vel innov RMS [m/s] / NIS | DVL innov RMS [m/s] / NIS |
|---|---|---|---|---|
| `X_Vc0_lock` | 0.0216 / 1.0 | 48.000 / 46.0 | 488 / 0.4 | 0.022/0.020/0.030 / 2.5 |
| `0.012/0.011/0.013` | 0.1675 / | `X_Vc0_outage` | 0.0218 / 1.0 | 48.000 / 46.0 | 511 / 0.5 | 0.021/0.020/0.030 / 2.5 |
| `0.012/0.012/0.016` | 0.2279 / | `X_Vc_E015_lock` | 0.0207 / 0.9 | 48.000 / 46.0 | 509 / 0.5 | 0.021/0.021/0.030 / 2.6 |
| `0.012/0.017/0.015` | 0.2041 / | `X_Vc_E015_outage` | 0.0203 / 0.9 | 48.000 / 46.0 | 516 / 0.5 | 0.020/0.021/0.031 / 2.5 |
| `0.011/0.019/0.017` | 0.2097 / | `XZ_Vc0_lock` | 0.0196 / 0.8 | 48.000 / 46.0 | 503 / 0.5 | 0.021/0.021/0.030 / 2.6 |
| `0.010/0.012/0.014` | 0.1888 / | `XZ_Vc0_outage` | 0.0219 / 1.0 | 48.000 / 46.0 | 500 / 0.5 | 0.021/0.021/0.031 / 2.6 |
| `0.011/0.012/0.015` | 0.1992 / | `XZ_Vc_E015_lock` | 0.0210 / 0.9 | 48.000 / 46.0 | 515 / 0.5 | 0.021/0.021/0.030 / 2.5 |
| `0.012/0.017/0.015` | 0.2169 / | `XZ_Vc_E015_outage` | 0.0199 / 0.9 | 48.000 / 46.0 | 528 / 0.5 | 0.021/0.021/0.031 / 2.6 |
| `0.011/0.017/0.015` | 0.1866 / | `R10_Vc0_lock` | 0.0214 / 1.0 | 48.000 / 46.0 | 494 / 0.5 | 0.021/0.020/0.030 / 2.5 |
| `0.013/0.020/0.016` | 0.3772 / | `R10_Vc0_outage` | 0.0213 / 1.0 | 48.000 / 46.0 | 490 / 0.5 | 0.020/0.021/0.031 / 2.5 |
| `0.013/0.023/0.015` | 0.4002 / | `R10_Vc_E015_lock` | 0.0202 / 0.9 | 48.000 / 46.0 | 520 / 0.5 | 0.020/0.020/0.031 / 2.5 |
| `0.017/0.023/0.015` | 0.4160 / | `R10_Vc_E015_outage` | 0.0208 / 0.9 | 48.000 / 46.0 | 505 / 0.5 | 0.020/0.020/0.031 / 2.5 |
| `0.017/0.023/0.016` | 0.4298 / 
NIS is reported exactly as measured and was never tuned. Where it sits above the chi-square 95% reference, the causes available in this design are the unmodelled ASSUMED sensor biases listed above and the latency approximation, not a detected fault; where it sits near or below it, that is a consistency observation on ASSUMED numerics and still not an accuracy claim. Either way NIS is characterization, and the decision on this baseline rests on the integrity gates.

### DVL outage drift and reacquisition (6 outage cases)

| Case | outage window [s] | pos drift [m] | vel drift [m/s] | current drift [m/s] | sigma_pos start->end [m] | reacq latency [s] | reacq jump pos [m] | reacq innovation [m/s] |
|---|---|---:|---:|---:|---|---:|---:|---:|
| `X_Vc0_outage` | 7.20 - 11.16 | 0.024 | -0.0027 | 0.0001 | 0.142 -> 0.142 | 0.140 | 0.0001 | 0.0264 |
| `X_Vc_E015_outage` | 7.20 - 11.16 | 0.019 | -0.0056 | -0.0001 | 0.142 -> 0.142 | 0.140 | 0.0000 | 0.0211 |
| `XZ_Vc0_outage` | 8.80 - 13.64 | 0.029 | -0.0037 | 0.0004 | 0.142 -> 0.142 | 0.260 | 0.0001 | 0.0235 |
| `XZ_Vc_E015_outage` | 8.80 - 13.64 | 0.037 | -0.0060 | 0.0003 | 0.142 -> 0.142 | 0.260 | 0.0000 | 0.0222 |
| `R10_Vc0_outage` | 18.00 - 27.90 | 0.011 | -0.0020 | 0.0001 | 0.143 -> 0.143 | 0.200 | 0.0001 | 0.0595 |
| `R10_Vc_E015_outage` | 18.00 - 27.90 | 0.008 | -0.0051 | 0.0006 | 0.143 -> 0.143 | 0.200 | 0.0000 | 0.0359 |

During the declared outage the DVL emits nothing at all (message gap, not a flagged message), the manager holds the channel out of the source mask, and the estimator degrades to depth + heading + INS aiding. The NED current state is observable only through the DVL/INS pair, so while the DVL is suppressed it receives no correction and its covariance grows on the declared random walk - that growth is certain and is shown in the sigma columns. Whether the current *error* also grows depends on how constant the true current is, and the measured drift is reported above as-is. Note that INS velocity remains available throughout, so the ground solution stays bounded through the outage; this scenario therefore exercises DVL suppression and recovery behaviour, not a full dead-reckoning collapse.

## Availability manager

### Per-channel packet accounting, summed over all 12 cases

| Channel | offered | admitted | rejected (interface) | used for init | rejected (divergence guard) | fused |
|---|---:|---:|---:|---:|---:|---:|
| `imu_gyro` | 34000 | 34000 | 0 | 48 | 0 | 33952 |
| `imu_accel` | 34000 | 34000 | 0 | 48 | 0 | 33952 |
| `depth_pressure` | 3400 | 3400 | 0 | 12 | 0 | 3388 |
| `heading_compass` | 6800 | 6800 | 0 | 12 | 0 | 6788 |
| `ins_vel_ned` | 16988 | 16988 | 0 | 12 | 0 | 16976 |
| `dvl_vel_body_water` | 1510 | 1510 | 0 | 0 | 0 | 1510 |
| `usbl_pos_ned` | 0 | 0 | 0 | 0 | 0 | 0 |

Counter invariants `offered = admitted + rejected_interface` and `admitted = fused + used_for_init + rejected_guard` hold on every channel in every case.

### Manager negative test: malformed packets are offered and must be refused

| # | Injected fault | Expected rejection | Observed | Match |
|---:|---|---|---|:---:|
| 1 | `duplicate_timestamp` | `timestamp_not_increasing` | `timestamp_not_increasing` | YES |
| 2 | `out_of_order_timestamp` | `timestamp_not_increasing` | `timestamp_not_increasing` | YES |
| 3 | `replayed_old_sequence` | `seq_not_increasing` | `seq_not_increasing` | YES |
| 4 | `nonfinite_payload` | `nonfinite_value` | `nonfinite_value` | YES |
| 5 | `quality_below_admission` | `low_quality` | `low_quality` | YES |
| 6 | `stale_beyond_limit` | `stale_age` | `stale_age` | YES |
| 7 | `flagged_dropout_status` | `not_valid` | `not_valid` | YES |
| 8 | `payload_out_of_icd_bounds` | `out_of_bounds` | `out_of_bounds` | YES |
| 9 | `absent_usbl_admission_attempt` | `channel_absent` | `channel_absent` | YES |

All 9 injected packets were refused (0 admitted, 0 fused), and the estimated trajectory, quaternion and covariance are **bitwise identical** to the clean run: YES. The manager was proved to reject, not asserted to.

## Truth blindness

| Evidence | Result |
|---|:---:|
| `run` receives the MEASURED bus only; TRUTH is never passed | YES |
| Bus sanitized to an interface whitelist at entry, raw bus cleared | YES |
| Re-running on the sanitized bus alone is bitwise identical | YES |
| Scrambling every truth-side bus field (Vc, outage flag, route, label, seed) changes nothing | YES |
| Static scan: truth tokens outside the post-hoc scorer / declaration / comments | 0 |

The scrambled-bus test is the decisive one: the true current was replaced with `[99 -99 99]` m/s and the outage flag inverted, and the estimate did not move by one bit.

## Determinism

| Check | Result |
|---|:---:|
| Same-input replay bitwise identical | YES |
| Reverse-order replay bitwise identical, 12/12 | YES |
| Replay checksums identical, 12/12 | YES |

The estimator draws no random numbers and holds no persistent or global state, so execution order cannot influence a result. That is verified, not assumed.

## Isolation and fingerprints

| Frozen artifact | Bytes | Unchanged within this run | Matches Gate 5A record |
|---|---:|:---:|:---:|
| `controller_law.m` | 9402 | YES | YES |
| `guidance_law.m` | 14601 | YES | YES |
| `continuous_path_tracking.m` | 10845 | YES | YES |
| `underwater777_vehicle_dynamics.m` | 6065 | YES | YES |
| `init_parameters.m` | 4205 | YES | YES |
| `underwater777_vehicle_dynamics_current.m` | 7814 | YES | YES |
| `suite_results\CODEX_VERTICAL_PLAN.md` | 43101 | YES | YES |

- `CODEX_VERTICAL_PLAN.md` is untouched: YES.
- Production plant, controller and guidance were never invoked: the estimator consumes a bus and nothing else.
- Gate 4 waiver remains **OPEN / shadow-only**; nothing in this task promotes it.

## Visual QA: the figure is validated by decoding it

- `NAV_MULTIRATE_EKF_BASELINE.png`: 12 panels, 486613 bytes, 2400 x 1725 px, ink fraction 0.218, gray std 50.0.
- Decoded after writing with `imread`: YES. Readability thresholds (width>=1400, height>=900, 0.01<ink<0.95, gray std>5, bytes>80000): YES.
- panel 1 NED track: truth solid vs estimated dashed, initialization marker visible
- panel 2 depth: truth, MEASURED depth packets and estimate overlaid, NED down positive
- panel 3 position displacement error with +/-3 sigma envelope
- panel 4 velocity error NED with +/-3 sigma envelope
- panel 5 attitude error in deg with +/-3 sigma tilt envelope
- panel 6 NED current estimate vs truth with outage shaded
- panel 7 NIS per channel on log axis with chi-square 95% reference lines
- panel 8 availability raster of all seven MEASURED channels plus EKF status
- panel 9 accepted vs rejected updates per channel over all 12 cases
- panel 10 hard-gate bar panel, one labelled bar per gate
- panel 11 per-case metric table legible at full resolution
- panel 12 assumption / boundary text panel legible at full resolution

## Artifact size budget

| Artifact | Bytes |
|---|---:|
| `NAV_MULTIRATE_EKF_BASELINE.md` | 24973 |
| `NAV_MULTIRATE_EKF_BASELINE.mat` | 6490500 |
| `NAV_MULTIRATE_EKF_BASELINE.png` | 486613 |
| **total** | **7002086 (6.68 MiB)** |

- Budget: **< 300 MiB**. Result: PASS.
- The MAT stores gate records, per-case verification structs, manager counters, metrics and a 20 Hz decimated showcase only. No full-rate multi-case series is archived.

## Gate decision

- **Gate 5B baseline: PASS (integrity/interface only)**
- Basis: 12/12 frozen cases pass every integrity gate, 28/28 hard gates pass, deterministic replay, proved truth blindness, proved packet rejection, zero DVL updates through every declared outage, exact frozen fingerprints, one MATLAB process, artifacts far under 300 MiB.
- **Accuracy status: NOT_CERTIFIED.** No navigation-accuracy claim is made or implied.
- **No promotion.** Gate 5A remains PASS_FORMALIZED; Gate 4 waiver remains OPEN / shadow-only.
- Claim limit: Integrity and interface only. No navigation-accuracy claim. Simulation-only; nothing here is bench or sea-trial validated.

## Limitations

- Every sensor numeric and every filter constant is ASSUMED. Error magnitudes are illustrative only.
- TRUTH is a prescribed kinematic scenario, not a plant or closed-loop run. No tracking, stability, robustness or navigation-accuracy conclusion follows.
- Measurement latency is charged as inflated R rather than compensated by replaying a buffered state to the packet timestamp. That is an approximation, declared here, not a validated delay-compensation scheme.
- Depth, heading, INS and DVL biases are unmodelled, so the filter is deliberately inconsistent by exactly those biases. Adding bias states is listed as the next untried structure, not attempted here.
- Horizontal position is unobservable without USBL; only displacement drift is meaningful.
- Sensor numerics must move from ASSUMED to bench or sea-trial identified before any accuracy claim.
- Simulation-only. Nothing here is hardware, bench or sea-trial evidence.

## MATHEMATICAL_RECORD

```
MATHEMATICAL_RECORD = {
  equations: {
    nominal: p' = v,  v' = R_bn (f_m - b_a) + g_NED,  q' = 0.5 q (x) [0; w_m - b_g],
             b_g' = 0, b_a' = 0, c' = 0 (random walk in Q only),
    error  : dp' = dv,  dv' = -R_bn [f]x dtheta - R_bn db_a,
             dtheta' = -[w]x dtheta - db_g,
    measure: z_depth = p_D, z_psi = psi(q) (wrapped), z_ins = v_NED,
             z_dvl = R_bn'(v_NED - c_NED),  USBL absent,
    update : S = H P H' + R_eff,  K = P H' S^-1,  nu = z - h(x),
             P+ = (I-KH) P (I-KH)' + K R_eff K'  (Joseph),  P+ = (P+ + P+')/2,
             R_eff = R/max(q/q_nom, q_floor) + (lat_scale * age)^2 I,
             reset G = I, G_thth = I - 0.5[dtheta]x,  |q| renormalized
  },
  admission: { valid AND status==OK AND finite AND within ICD bounds AND
               quality >= q_min_frac*q_nom AND stale_age <= stale_limit AND
               seq > last_accepted_seq AND timestamp > last_accepted_timestamp },
  hard_gates: { finite state/covariance, symmetric PSD covariance,
               monotonic estimate time/sequence, quaternion norm,
               no truth leakage, no invalid packet fused,
               zero DVL updates in outage, deterministic replay },
  parameter_provenance: {
    DERIVED: sigma_a, sigma_g (from declared ASSUMED sensor sigma and rate),
    ASSUMED: all R, P0, bias/current random walks, admission thresholds, latency scales,
    IDENTIFIED: none,  TUNED: none (no rerun after seeing results)
  },
  design_reason: 'An estimator built on ASSUMED sensor numerics can be verified for integrity
                  and interface behaviour but not for accuracy, so integrity is what is gated.',
  rejected_alternatives: {
    inflate_R_until_NIS_consistent: rejected (tuning, and would hide unmodelled bias),
    add_bias_states_now: rejected (would change the structure under test mid-baseline),
    claim_navigation_accuracy: rejected (every upstream numeric is ASSUMED),
    fuse_USBL: rejected (channel is absent by contract),
    promote_Gate4_waiver: rejected (out of scope, remains shadow-only)
  },
  evidence: { suite_results/NAV_MULTIRATE_EKF_BASELINE.{md,mat,png} },
  conclusion: 'PASS: 12/12 frozen cases integrity-clean, 28/28 hard gates, accuracy NOT_CERTIFIED',
  open_questions: { sensor numerics remain ASSUMED; delay compensation approximated;
                    sensor bias states unmodelled; horizontal position unobservable without USBL }
}
```

## Artifacts

- `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\NAV_MULTIRATE_EKF_BASELINE.md`
- `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\NAV_MULTIRATE_EKF_BASELINE.mat`
- `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\NAV_MULTIRATE_EKF_BASELINE.png`

Root: `C:\Users\ardak\MATLAB\Projects\AUVsim-main`
