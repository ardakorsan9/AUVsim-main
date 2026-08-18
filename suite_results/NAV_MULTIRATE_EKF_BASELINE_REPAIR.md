# NAV_MULTIRATE_EKF_ARTIFACT_REPAIR_001 - Gate 5B evidence repair

**Overall verdict: PASS** - evidence repair only. 12/12 frozen Gate 5A cases pass every integrity gate, 28/28 frozen hard gates pass, 17/17 repair gates pass. **Verdict, method and numerics are frozen. Accuracy remains CHARACTERIZATION ONLY and NOT_CERTIFIED. No promotion is made. Simulation-only.**

## The defect, stated plainly

The prior Gate 5B run `NAV_MULTIRATE_EKF_BASELINE_001` was correct in substance: it passed 12/12 integrity gates and 28/28 hard gates, and its MAT holds the right numbers. What was wrong was the *rendering* of one table in its Markdown report.

- **Defect id:** `MD_INNOVATION_TABLE_FPRINTF_TYPE_MISMATCH`
- **Location:** write_report / innovation and NIS per channel row
- **Emitted (defective):**

```
| `%s` | %.4f / %.1f | %.3f / %.1f | %s / %.1f | %s / %.1f |
```

- **Emitted (corrected):**

```
| `%s` | %.4f / %.1f | %s / %.1f | %s / %.1f | %s / %.1f |
```

- **Mechanism:** %.3f was applied to hdeg(h), which returns a char array. MATLAB fprintf flattens its argument list, so the numeric conversion consumed the character CODES of that string one per conversion, shifted every following argument and recycled the format specification. The rendered table had displaced cells and merged case rows.
- **Fix:** Heading cell conversion changed from %.3f to %s, matching the char returned by hdeg().
- **Blast radius:** Report writer only. No estimator, gate, metric, seed, threshold or numeric touched.
- Corrected conversion present in the frozen driver: YES. Present in this repair driver: YES.

This is worth being blunt about: the defect was a *type* error that MATLAB does not raise. `fprintf` silently accepts a char argument under a numeric conversion and prints its character codes, so the run completed, the gates passed, and the only symptom was a table that a human reader would call garbled. Nothing in the gate set was watching the rendered report, which is why this repair adds a gate that decodes the written MD and checks the table cell by cell against the MAT.

## What this repair changed, and what it did not

| Item | Changed? |
|---|:---:|
| Report-writer conversion for the heading innovation cell (`%.3f` -> `%s`) | YES |
| Output file prefix (`..._REPAIR`) and task label | YES |
| Figure title annotation marking this as an evidence repair | YES |
| Added evidence gates: MD table decode, parity vs prior MAT, prior-artifact immutability | YES |
| Estimator library, any equation, any Jacobian | NO |
| Any Q, R, P0, admission threshold, latency scale or gate threshold | NO |
| Case matrix, labels, seeds, tick counts, decimation | NO |
| Integrity gate set, hard gate set or their semantics | NO |
| Verdict, accuracy status, claim limit, promotion status | NO |

Report-writer defect repair and artifact re-emission. No estimator, gate, threshold, seed, tick count, metric or verdict was changed. No promotion, no tuning, no accuracy claim.

## Process record

- This run: MATLAB 2025b, pid 16124, started 2026-08-08 16:07:30, single `-batch` invocation:

```
/mnt/d/ardak/matlab/bin/matlab.exe -batch "cd('C:/Users/ardak/MATLAB/Projects/AUVsim-main'); run_nav_multirate_ekf_baseline_repair;"
```

- Invocations of MATLAB in this task: **1**. Policy: ONE MATLAB start per task.
- Static review and code reading preceded execution; MATLAB was never started for probing, so the single permitted invocation was spent on the repair run itself.

## Sources read (exactly three, no repo scan)

| # | Source | Used for |
|---|---|---|
| 1 | `navigation_multirate_ekf_baseline.m` | frozen Gate 5B estimator library: statically reviewed, then executed unchanged; not one numeric touched |
| 2 | `run_nav_multirate_ekf_baseline.m` | frozen Gate 5B driver: statically reviewed, defect isolated in write_report, executed here with prefix / task-label changes and the corrected conversion |
| 3 | `NAV_MULTIRATE_EKF_BASELINE.mat` | prior Gate 5B MAT: the parity reference for every series, metric, counter, checksum and the verdict |

navigation_multirate_sensor_chain.m is EXECUTED unchanged to regenerate the frozen bus, and the driver reads it mechanically for its static-marker check exactly as the frozen Gate 5B driver does. It is a frozen execution dependency carried over verbatim, not a new source consulted for this repair.

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

## Parity against the prior MAT (the core of this repair)

A repair that quietly moved a number would be worse than the malformed table it replaces. So every quantity that the repair is forbidden to change is compared field by field against `NAV_MULTIRATE_EKF_BASELINE.mat` with `isequaln`.

- **Declared tolerance: EXACT: isequaln, tolerance 0. Every numeric array must be bitwise identical.**
- Prior verdict read from the prior MAT: `PASS` (overall_pass YES, cases 12/12 YES, hard gates all YES).

| # | Compared field | Present in both | Exactly identical |
|---:|---|:---:|:---:|
| 1 | `task_id` | YES | YES |
| 2 | `gate` | YES | YES |
| 3 | `mode` | YES | YES |
| 4 | `accuracy_status` | YES | YES |
| 5 | `claim_limit` | YES | YES |
| 6 | `no_tuning_rerun` | YES | YES |
| 7 | `static_markers` | YES | YES |
| 8 | `declared_asserts` | YES | YES |
| 9 | `truth_leak_scan` | YES | YES |
| 10 | `truth_blindness` | YES | YES |
| 11 | `cases` | YES | YES |
| 12 | `frozen_case_parity` | YES | YES |
| 13 | `expect_from_gate5a_record` | YES | YES |
| 14 | `per_case` | YES | YES |
| 15 | `case_pass` | YES | YES |
| 16 | `gate_names` | YES | YES |
| 17 | `gate_matrix` | YES | YES |
| 18 | `determinism` | YES | YES |
| 19 | `manager_negative_test` | YES | YES |
| 20 | `metrics` | YES | YES |
| 21 | `showcase` | YES | YES |
| 22 | `ekf_config` | YES | YES |
| 23 | `chain_config_summary` | YES | YES |
| 24 | `hard_gates` | YES | YES |
| 25 | frozen production fingerprint byte counts | YES | YES |

**Parity: 24/24 compared fields exactly identical.**

### Per-case estimate checksums (prior vs repair)

| # | Case | Prior checksum | Repair checksum | Identical |
|---:|---|---|---|:---:|
| 1 | `X_Vc0_lock` | `7F1F5C60` | `7F1F5C60` | YES |
| 2 | `X_Vc0_outage` | `0C1D8318` | `0C1D8318` | YES |
| 3 | `X_Vc_E015_lock` | `60B33CAC` | `60B33CAC` | YES |
| 4 | `X_Vc_E015_outage` | `D8E897A3` | `D8E897A3` | YES |
| 5 | `XZ_Vc0_lock` | `0211D206` | `0211D206` | YES |
| 6 | `XZ_Vc0_outage` | `78DD0008` | `78DD0008` | YES |
| 7 | `XZ_Vc_E015_lock` | `44A561F6` | `44A561F6` | YES |
| 8 | `XZ_Vc_E015_outage` | `BB832448` | `BB832448` | YES |
| 9 | `R10_Vc0_lock` | `87D9737D` | `87D9737D` | YES |
| 10 | `R10_Vc0_outage` | `33D2D9AB` | `33D2D9AB` | YES |
| 11 | `R10_Vc_E015_lock` | `0FF25E86` | `0FF25E86` | YES |
| 12 | `R10_Vc_E015_outage` | `602B180B` | `602B180B` | YES |

The checksum covers position, velocity, Euler angles, quaternion, both biases, current, body water-relative velocity, the covariance diagonal, validity, status, estimate sequence, estimate timestamp, source mask and the total fused count, over every tick of every case. Identical checksums: YES.

### Deliberately excluded from parity, and why

- process: pid, wall-clock start time and invocation string necessarily differ
- sources: this task declares its own three sources (the two frozen .m files and the prior MAT)
- visual_qa / PNG bytes: the repair figure carries an EVIDENCE REPAIR title annotation
- artifact_bytes and artifact_size_note: different file names and sizes by construction
- frozen_fingerprint_before/after: compared by byte count instead of datenum
- verdict / overall_pass / fail_cause: derived, and checked separately against the prior PASS
- repair-only fields, which have no counterpart in the prior MAT

## The prior artifacts were not touched

| Prior artifact | Bytes before | Bytes after | Timestamp unchanged | Content hash unchanged |
|---|---:|---:|:---:|:---:|
| `suite_results\NAV_MULTIRATE_EKF_BASELINE.md` | 25111 | 25111 | YES | YES |
| `suite_results\NAV_MULTIRATE_EKF_BASELINE.mat` | 6495676 | 6495676 | YES | YES |
| `suite_results\NAV_MULTIRATE_EKF_BASELINE.png` | 486613 | 486613 | YES | YES |

All three prior artifacts unchanged: YES. The content hash is a full-file Adler-32 over the raw bytes, computed before the repair run wrote anything and again after every write, so an accidental overwrite could not hide behind an identical byte count. Output paths were also asserted distinct from the baseline paths before any file was opened: YES.

## Frozen hard gates (unchanged set, unchanged semantics)

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

**Frozen hard gates: 28/28 PASS.**

## Repair gates (predeclared for this task, additional to the frozen set)

| # | Repair gate | Result |
|---:|---|:---:|
| 1 | `one_matlab_process` | PASS |
| 2 | `outputs_distinct_from_baseline` | PASS |
| 3 | `sources_exactly_three` | PASS |
| 4 | `defect_recorded_and_fixed` | PASS |
| 5 | `prior_run_was_pass` | PASS |
| 6 | `parity_series_metrics_counters` | PASS |
| 7 | `parity_checksums_exact` | PASS |
| 8 | `parity_frozen_fingerprint_bytes` | PASS |
| 9 | `integrity_12_of_12` | PASS |
| 10 | `hard_gates_28_of_28` | PASS |
| 11 | `innovation_table_12_rows` | PASS |
| 12 | `innovation_table_types_correct` | PASS |
| 13 | `innovation_table_labels_exact` | PASS |
| 14 | `innovation_table_values_match` | PASS |
| 15 | `prior_artifacts_unchanged` | PASS |
| 16 | `repair_png_readable` | PASS |
| 17 | `no_tuning_no_estimator_change` | PASS |

**Repair gates: 17/17 PASS.**

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

## Frozen 12-case matrix (regenerated, parity proved twice over)

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

Labels, tick counts, seeds and DVL availability match the Gate 5A validation record (labels YES, N YES, seeds YES, availability max deviation 0) and, independently, the prior Gate 5B MAT. No case was added, removed or reshaped.

## Accuracy characterization (NOT_CERTIFIED, reproduced unchanged)

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
| `X_Vc0_lock` | 0.0216 / 1.0 | 0.488 / 0.4 | 0.022/0.020/0.030 / 2.5 | 0.012/0.011/0.013 / 0.2 |
| `X_Vc0_outage` | 0.0218 / 1.0 | 0.511 / 0.5 | 0.021/0.020/0.030 / 2.5 | 0.012/0.012/0.016 / 0.2 |
| `X_Vc_E015_lock` | 0.0207 / 0.9 | 0.509 / 0.5 | 0.021/0.021/0.030 / 2.6 | 0.012/0.017/0.015 / 0.2 |
| `X_Vc_E015_outage` | 0.0203 / 0.9 | 0.516 / 0.5 | 0.020/0.021/0.031 / 2.5 | 0.011/0.019/0.017 / 0.2 |
| `XZ_Vc0_lock` | 0.0196 / 0.8 | 0.503 / 0.5 | 0.021/0.021/0.030 / 2.6 | 0.010/0.012/0.014 / 0.2 |
| `XZ_Vc0_outage` | 0.0219 / 1.0 | 0.500 / 0.5 | 0.021/0.021/0.031 / 2.6 | 0.011/0.012/0.015 / 0.2 |
| `XZ_Vc_E015_lock` | 0.0210 / 0.9 | 0.515 / 0.5 | 0.021/0.021/0.030 / 2.5 | 0.012/0.017/0.015 / 0.2 |
| `XZ_Vc_E015_outage` | 0.0199 / 0.9 | 0.528 / 0.5 | 0.021/0.021/0.031 / 2.6 | 0.011/0.017/0.015 / 0.2 |
| `R10_Vc0_lock` | 0.0214 / 1.0 | 0.494 / 0.5 | 0.021/0.020/0.030 / 2.5 | 0.013/0.020/0.016 / 0.4 |
| `R10_Vc0_outage` | 0.0213 / 1.0 | 0.490 / 0.5 | 0.020/0.021/0.031 / 2.5 | 0.013/0.023/0.015 / 0.4 |
| `R10_Vc_E015_lock` | 0.0202 / 0.9 | 0.520 / 0.5 | 0.020/0.020/0.031 / 2.5 | 0.017/0.023/0.015 / 0.4 |
| `R10_Vc_E015_outage` | 0.0208 / 0.9 | 0.505 / 0.5 | 0.020/0.020/0.031 / 2.5 | 0.017/0.023/0.016 / 0.4 |

This is the table the repair exists for. Each row is one frozen case; the depth cell is a scalar RMS with its mean NIS, the heading cell is a scalar RMS in degrees with its mean NIS, and the INS and DVL cells are N/E/D and x/y/z RMS triples with their mean NIS. NIS is reported exactly as measured and was never tuned. Where it sits above the chi-square 95% reference, the causes available in this design are the unmodelled ASSUMED sensor biases and the latency approximation, not a detected fault; where it sits near or below, that is a consistency observation on ASSUMED numerics and still not an accuracy claim.

#### Machine validation of the table above

The written Markdown file is read back from disk and the innovation section is decoded, so the evidence for "the table is now well formed" is the delivered file itself, not the intent of the code that wrote it.

| Check | Result |
|---|:---:|
| Innovation section and table located in the written MD | YES |
| Exactly 12 data rows decoded (found 12) | YES |
| Every row splits into exactly 5 cells | YES |
| Case labels present, in the frozen order | YES |
| Heading / INS / DVL cells type-correct (formatted number or number triple, never character codes) | YES |
| Every decoded cell equals the value re-formatted from the MAT metrics | YES |
| Table validation overall | PASS |

### DVL outage drift and reacquisition (6 outage cases)

| Case | outage window [s] | pos drift [m] | vel drift [m/s] | current drift [m/s] | sigma_pos start->end [m] | reacq latency [s] | reacq jump pos [m] | reacq innovation [m/s] |
|---|---|---:|---:|---:|---|---:|---:|---:|
| `X_Vc0_outage` | 7.20 - 11.16 | 0.024 | -0.0027 | 0.0001 | 0.142 -> 0.142 | 0.140 | 0.0001 | 0.0264 |
| `X_Vc_E015_outage` | 7.20 - 11.16 | 0.019 | -0.0056 | -0.0001 | 0.142 -> 0.142 | 0.140 | 0.0000 | 0.0211 |
| `XZ_Vc0_outage` | 8.80 - 13.64 | 0.029 | -0.0037 | 0.0004 | 0.142 -> 0.142 | 0.260 | 0.0001 | 0.0235 |
| `XZ_Vc_E015_outage` | 8.80 - 13.64 | 0.037 | -0.0060 | 0.0003 | 0.142 -> 0.142 | 0.260 | 0.0000 | 0.0222 |
| `R10_Vc0_outage` | 18.00 - 27.90 | 0.011 | -0.0020 | 0.0001 | 0.143 -> 0.143 | 0.200 | 0.0001 | 0.0595 |
| `R10_Vc_E015_outage` | 18.00 - 27.90 | 0.008 | -0.0051 | 0.0006 | 0.143 -> 0.143 | 0.200 | 0.0000 | 0.0359 |

During the declared outage the DVL emits nothing at all (message gap, not a flagged message), the manager holds the channel out of the source mask, and the estimator degrades to depth + heading + INS aiding. The NED current state is observable only through the DVL/INS pair, so while the DVL is suppressed it receives no correction and its covariance grows on the declared random walk. INS velocity remains available throughout, so the ground solution stays bounded through the outage; these cases exercise DVL suppression and recovery, not a full dead-reckoning collapse.

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

Counter invariants `offered = admitted + rejected_interface` and `admitted = fused + used_for_init + rejected_guard` hold on every channel in every case, and every counter above is identical to the prior MAT.

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

All 9 injected packets were refused (0 admitted, 0 fused), and the estimated trajectory, quaternion and covariance are **bitwise identical** to the clean run: YES.

## Truth blindness

| Evidence | Result |
|---|:---:|
| `run` receives the MEASURED bus only; TRUTH is never passed | YES |
| Bus sanitized to an interface whitelist at entry, raw bus cleared | YES |
| Re-running on the sanitized bus alone is bitwise identical | YES |
| Scrambling every truth-side bus field (Vc, outage flag, route, label, seed) changes nothing | YES |
| Static scan: truth tokens outside the post-hoc scorer / declaration / comments | 0 |

## Determinism

| Check | Result |
|---|:---:|
| Same-input replay bitwise identical | YES |
| Reverse-order replay bitwise identical, 12/12 | YES |
| Replay checksums identical, 12/12 | YES |
| Cross-run reproduction: identical to the prior MAT of a separate MATLAB process | YES |

The last row is new evidence that the prior run could not produce on its own: the same inputs, run in a different process on a different day, reproduce the prior results exactly. That is a stronger determinism statement than same-process replay.

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

- `NAV_MULTIRATE_EKF_BASELINE_REPAIR.png`: 12 panels, 494437 bytes, 2400 x 1725 px, ink fraction 0.219, gray std 50.3.
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
- The repair figure differs from the baseline figure only in the title annotation and panel 12 text, which is why PNG bytes are deliberately excluded from the parity comparison.

## Artifact size budget

| Artifact | Bytes |
|---|---:|
| `NAV_MULTIRATE_EKF_BASELINE_REPAIR.md` | 30748 |
| `NAV_MULTIRATE_EKF_BASELINE_REPAIR.mat` | 6571348 |
| `NAV_MULTIRATE_EKF_BASELINE_REPAIR.png` | 494437 |
| **total** | **7096533 (6.768 MiB)** |

- Budget: **< 300 MiB**. Result: PASS.
- Byte counts measured after the first write of the MD and MAT. The delivered MD/MAT differ only by the few hundred bytes needed to record this measurement and the evidence rechecks, which is immaterial against a 300 MiB budget.
- The MAT stores gate records, per-case verification structs, manager counters, metrics, the parity record and a 20 Hz decimated showcase only. No full-rate multi-case series is archived.

## Post-write rechecks on the delivered artifacts

| Recheck | Result |
|---|:---:|
| Innovation table decoded from the delivered MD | PASS |
| Prior baseline artifacts still unchanged after every write | PASS |
| Each of the three logs grew and carries this task id exactly once | PASS |
| Total artifact bytes under budget (7169541 bytes, 6.837 MiB) | PASS |

Measured on the artifacts written by the immediately preceding pass. The innovation table region is a pure function of the MAT metrics and is byte-identical across writes, so validating it on any pass validates the delivered file.

## Gate decision

- **Gate 5B evidence repair: PASS**
- Basis: 12/12 frozen cases integrity-clean, 28/28 frozen hard gates, 17/17 repair gates, exact parity with the prior MAT across every compared field including all 12 estimate checksums, a machine-decoded and correct innovation table, prior artifacts proved untouched, exact production fingerprints, one MATLAB process, artifacts far under 300 MiB.
- **The Gate 5B verdict itself is unchanged and is not re-decided here.** Gate 5B remains PASS on integrity and interface, exactly as the prior run established it.
- **Accuracy status: NOT_CERTIFIED.** No navigation-accuracy claim is made or implied.
- **No promotion.** Gate 5A remains PASS_FORMALIZED; Gate 4 waiver remains OPEN / shadow-only.
- Claim limit: Integrity and interface only. No navigation-accuracy claim. Simulation-only; nothing here is bench or sea-trial validated.

## Limitations

- This task adds **no** new engineering evidence about the estimator. It re-emits existing evidence correctly. Treating it as progress would be a mistake.
- Every sensor numeric and every filter constant is ASSUMED. Error magnitudes are illustrative only.
- TRUTH is a prescribed kinematic scenario, not a plant or closed-loop run. No tracking, stability, robustness or navigation-accuracy conclusion follows.
- Measurement latency is charged as inflated R rather than compensated by replaying a buffered state to the packet timestamp. That is an approximation, declared, not validated.
- Depth, heading, INS and DVL biases are unmodelled, so the filter is deliberately inconsistent by exactly those biases.
- Horizontal position is unobservable without USBL; only displacement drift is meaningful.
- The new table gate proves the innovation table is well formed. It does not prove any other table in any other report is, and no repo-wide sweep for the same class of defect was performed in this task.
- Simulation-only. Nothing here is hardware, bench or sea-trial evidence.

## Next task

- GATE 5C (named, not attempted here): outage / optional-USBL stress. Extend the declared outage matrix (longer, repeated and overlapping DVL gaps, plus INS and heading dropouts) and admit the OPTIONAL USBL channel as an intermittent, latent, low-rate absolute fix, to test manager behaviour and observability recovery under combined aiding loss. Numerics remain ASSUMED and accuracy remains NOT_CERTIFIED.

## MATHEMATICAL_RECORD

```
MATHEMATICAL_RECORD = {
  task_class: EVIDENCE_REPAIR (no new mathematics; the model below is reproduced verbatim
              from NAV_MULTIRATE_EKF_BASELINE_001 and was re-executed unchanged),
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
  defect: { id: MD_INNOVATION_TABLE_FPRINTF_TYPE_MISMATCH,
            kind: format/argument TYPE mismatch in the report writer,
            detail: numeric conversion applied to a char argument, consuming character
                    codes, shifting all later arguments and recycling the format,
            fix: heading cell conversion %.3f -> %s,
            numerics_affected: none },
  parity: { reference: suite_results/NAV_MULTIRATE_EKF_BASELINE.mat,
            method: isequaln field by field, tolerance 0 (bitwise for numeric arrays),
            fields_compared: 24, fields_identical: 24,
            estimate_checksums_identical: 12/12 },
  evidence_validation: { the written MD is decoded and the innovation table checked
                         row count, cell count, labels, cell TYPES and cell VALUES
                         against the MAT; result PASS },
  parameter_provenance: {
    DERIVED: sigma_a, sigma_g (from declared ASSUMED sensor sigma and rate),
    ASSUMED: all R, P0, bias/current random walks, admission thresholds, latency scales,
    IDENTIFIED: none,  TUNED: none (no rerun after seeing results)
  },
  design_reason: 'A malformed evidence artifact is a defect even when the underlying result
                  is correct, and the honest remedy is to re-emit the same result correctly
                  and prove numerically that nothing moved.',
  rejected_alternatives: {
    hand_edit_the_prior_MD: rejected (an artifact edited by hand is not run evidence),
    overwrite_the_prior_artifacts: rejected (destroys the record of the defect),
    rerun_with_any_numeric_change: rejected (would make parity meaningless),
    treat_the_repair_as_new_evidence: rejected (it is a re-emission, not a result),
    promote_Gate4_waiver: rejected (out of scope, remains shadow-only)
  },
  evidence: { suite_results/NAV_MULTIRATE_EKF_BASELINE_REPAIR.{md,mat,png} },
  conclusion: 'PASS: evidence repair, 12/12 cases integrity-clean, 28/28 frozen hard gates,
                17/17 repair gates, parity with the prior MAT exact, accuracy NOT_CERTIFIED',
  open_questions: { sensor numerics remain ASSUMED; delay compensation approximated;
                    sensor bias states unmodelled; horizontal position unobservable without
                    USBL; other reports were not swept for the same defect class }
}
```

## Artifacts

- `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\NAV_MULTIRATE_EKF_BASELINE_REPAIR.md`
- `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\NAV_MULTIRATE_EKF_BASELINE_REPAIR.mat`
- `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\NAV_MULTIRATE_EKF_BASELINE_REPAIR.png`

Preserved inputs (not modified):

- `suite_results\NAV_MULTIRATE_EKF_BASELINE.md`
- `suite_results\NAV_MULTIRATE_EKF_BASELINE.mat`
- `suite_results\NAV_MULTIRATE_EKF_BASELINE.png`

Root: `C:\Users\ardak\MATLAB\Projects\AUVsim-main`
