# NAV_AVAILABILITY_OUTAGE_VALIDATION_001 - Gate 5C process-compliant validation

**Overall verdict: PASS.** The frozen Gate 5C computation was re-executed in **one MATLAB start**: 24/24 predeclared cases pass every integrity, counter, gap and state-machine check, 32/32 hard gates pass, 17/17 validation gates pass, and 16/16 parity records match the prior evidence (16 of them bitwise exact).

**Accuracy and outage endurance remain CHARACTERIZATION and NOT_CERTIFIED. The Gate 4 waiver remains OPEN / shadow-only. Nothing is promoted. Simulation-only.**

## Why this task exists

`NAV_AVAILABILITY_OUTAGE_STRESS_001` reported PASS on 24/24 cases and 32/32 hard gates, and the numbers were sound. But it used **two MATLAB starts** against a one-start-per-task policy: its first start ran the whole computation and then died inside the report writer, and a second start delivered the artifacts after the reporting defect was repaired. A result you had to run twice to publish is not the same object as a result you ran once, even when the numbers are identical - the second run is unfalsifiable from the outside unless someone reproduces it.

So the prior run is recorded here as **TECHNICAL_PASS / PROCESS_NONCOMPLIANT**, and this task does the only thing that actually settles the question: re-execute the same frozen computation in exactly one start and compare every recorded number against the prior evidence, item by item. Nothing was re-tuned. This task is permitted to change the process verdict and nothing else.

The prior Gate 5C run reported PASS on 24/24 predeclared cases and 32/32 hard gates, but it consumed two MATLAB starts against a one-start-per-task policy. Its first start ran the whole computation and then aborted in the report writer without delivering an artifact; only the reporting layer was repaired between starts. The technical result is therefore retained as shadow evidence and the process result is recorded as non-compliant. This task supersedes the process record only.

## Process record

- MATLAB 2025b, pid 8592, started 2026-08-08 17:57:06, one `-batch` invocation:

```
/mnt/d/ardak/matlab/bin/matlab.exe -batch "cd('C:/Users/ardak/MATLAB/Projects/AUVsim-main'); run_nav_availability_outage_validation;"
```

| Process item | This task | Prior task |
|---|:---:|:---:|
| MATLAB starts | **1** | 2 |
| One-start policy met | YES | NO |
| MATLAB used for probing | NO | NO |
| Static review before execution | YES | YES |
| Sources read | 3 | 3 |
| Declared deviation | none | two starts |

## Sources read (exactly three, no repo scan)

| # | Source | Used for |
|---|---|---|
| 1 | `navigation_multirate_ekf_availability.m` | frozen Gate 5C estimator fork: statically reviewed line by line, executed here UNMODIFIED, and fingerprinted before and after by bytes, timestamp and Adler-32 |
| 2 | `run_nav_availability_outage_stress.m` | frozen Gate 5C driver: statically reviewed for the predeclared schedule, the 24-case matrix, every audit and gate definition, the figure and the report writer. Its harness is transcribed VERBATIM into this file because its subfunctions are file-local and calling its entry point would overwrite the artifacts under test |
| 3 | `NAV_AVAILABILITY_OUTAGE_STRESS.mat` | prior Gate 5C evidence MAT: read statically for the recorded labels, tick counts, seeds, packet counters, health transitions and delays, estimator series, metrics, checksums, gate matrix and verdict. It is the parity reference for this task |

navigation_multirate_sensor_chain.m and navigation_multirate_ekf_baseline.m are EXECUTED unchanged - the first to regenerate the frozen MEASURED bus, the second to reproduce the frozen Gate 5B numeric fingerprint - and are read mechanically only for the static-marker checks. Source 2 already declared both as execution dependencies; they are carried over verbatim and are not new design sources.

## The schedule was transcribed, not re-chosen

Source 2 keeps its harness in file-local subfunctions and writes to the very artifacts this task must preserve, so it cannot be called. Its schedule and harness are therefore copied verbatim into this driver - which is exactly the place a re-validation can go wrong, by quietly "improving" a number. Two independent checks close that hole:

| Transcription check | Result |
|---|:---:|
| Reconstructed declared schedule equals the one recorded in source 3 | YES |
| Estimator config equals the one recorded in source 3 | YES |
| Static markers reproduce the recorded values | YES |
| Declared asserts reproduce the recorded values | YES |

### Literal-text markers on source 2

| Marker | Found |
|---|:---:|
| `src2_dvl_gap` | YES |
| `src2_hdg_gap` | YES |
| `src2_usbl_burst` | YES |
| `src2_usbl_rate` | YES |
| `src2_usbl_t0` | YES |
| `src2_usbl_delay` | YES |
| `src2_usbl_stale` | YES |
| `src2_usbl_faults` | YES |
| `src2_seed_rule` | YES |
| `src2_timing_bound` | YES |
| `src2_scaled_idx` | YES |
| `src2_tb_idx` | YES |
| `src2_neg_idx` | YES |
| `src2_show_i` | YES |
| `src2_showcase_dec` | YES |
| `src2_two_starts` | YES |
| `validation_no_tuning` | YES |
| `all_ok` | YES |

NO_TUNING_RERUN: every schedule number, threshold, dwell time, seed, window, R, Q and P0 in this task is a verbatim transcription of the frozen Gate 5C driver, proved by static markers on its text and by an exact comparison of the reconstructed schedule and estimator config against the ones recorded in the prior MAT. No constant was revisited after seeing a result and no case was rerun with a changed number.

### Static review markers (same set as the prior run)

| Marker | Found |
|---|:---:|
| `chain_dt_base` | YES |
| `chain_usbl_absent` | YES |
| `g5b_never_fuse_usbl` | YES |
| `g5b_joseph` | YES |
| `fork_joseph_identical` | YES |
| `fork_reset_jacobian` | YES |
| `fork_error_state_18` | YES |
| `fork_truth_firewall` | YES |
| `fork_usbl_model` | YES |
| `fork_health_states` | YES |
| `fork_fsm_after_loop` | YES |
| `fork_fsm_no_authority` | YES |
| `fork_admission_unchanged` | YES |
| `no_tuning_rerun` | YES |
| `all_ok` | YES |

### Declared asserts

| Assert | Holds |
|---|:---:|
| `g_matches_chain` | YES |
| `g_matches_gate5b` | YES |
| `dt_base` | YES |
| `U_ground` | YES |
| `usbl_lat_scale_is_U` | YES |
| `chain_task_id` | YES |
| `gate5b_task_id` | YES |
| `gate5c_task_id` | YES |
| `usbl_absent_in_chain` | YES |
| `gate5b_never_fuses_usbl` | YES |
| `gate5c_fuses_usbl` | YES |
| `usbl_not_required_for_init` | YES |
| `shared_QR_unchanged` | YES |
| `ok` | YES |

## The frozen schedule

| Quantity | Value | Units | Provenance |
|---|---|---|---|
| DVL message gap | [0.20 0.62] x T_final | - | ASSUMED |
| heading message gap | [0.30 0.50] x T_final | - | ASSUMED |
| USBL dropout burst | [0.25 0.65] x T_final | - | ASSUMED |
| USBL rate | 1.00 | Hz | ASSUMED |
| USBL first emission | 1.80 | s | ASSUMED |
| USBL delay | 1.10 | s | ASSUMED acoustic + processing |
| USBL noise sigma | [1.50 1.50 0.80] | m NED | ASSUMED |
| USBL bias | [0.40 -0.30 0.10] | m NED | ASSUMED, left unmodelled |
| USBL stale limit | 2.50 | s | ASSUMED ICD |
| USBL malformed packets | 3 | count | ASSUMED, flagged_invalid / stale_beyond_limit / out_of_order_timestamp |
| USBL latency scale | 1.50 | m/s | DERIVED = declared U_ground |
| freshness horizon | max(4.0 x period, stale limit + period, 1.00 s) | s | DERIVED from ICD |
| dwell T_degrade / T_lost / T_reacq / T_clear / T_settle | 0.50 / 2.00 / 0.50 / 1.00 / 3.00 | s | ASSUMED |
| seed rule | seed = 5000000 + 100000*route_index + 1000*current_index + 10*profile_index | - | ASSUMED |
| timing tolerance | 0.010 | s | ASSUMED, two base ticks |

- All outage windows are declared on the BUS ARRIVAL time axis, i.e. the base tick clock the estimator actually sees, so "zero updates inside the gap" is an unambiguous statement about consumed packets.
- On the 2nd, 4th and 6th delivered packet after the dropout burst ends, so each malformed packet is isolated between two healthy ones and cannot by itself create a second staleness event.

## Gate 5B reproduced exactly, then left alone

| # | Frozen case | N | seed | recorded checksum | reproduced | Identical |
|---:|---|---:|---:|---|---|:---:|
| 1 | `X_Vc0_lock` | 3601 | 1736306363 | `7F1F5C60` | `7F1F5C60` | YES |
| 2 | `X_Vc0_outage` | 3601 | 1719528744 | `0C1D8318` | `0C1D8318` | YES |
| 3 | `X_Vc_E015_lock` | 3601 | 70806246 | `60B33CAC` | `60B33CAC` | YES |
| 4 | `X_Vc_E015_outage` | 3601 | 54028627 | `D8E897A3` | `D8E897A3` | YES |
| 5 | `XZ_Vc0_lock` | 4401 | 637068955 | `0211D206` | `0211D206` | YES |
| 6 | `XZ_Vc0_outage` | 4401 | 620291336 | `78DD0008` | `78DD0008` | YES |
| 7 | `XZ_Vc_E015_lock` | 4401 | 2100020421 | `44A561F6` | `44A561F6` | YES |
| 8 | `XZ_Vc_E015_outage` | 4401 | 2083242802 | `BB832448` | `BB832448` | YES |
| 9 | `R10_Vc0_lock` | 9001 | 1001993762 | `87D9737D` | `87D9737D` | YES |
| 10 | `R10_Vc0_outage` | 9001 | 1018771381 | `33D2D9AB` | `33D2D9AB` | YES |
| 11 | `R10_Vc_E015_lock` | 9001 | 746023432 | `0FF25E86` | `0FF25E86` | YES |
| 12 | `R10_Vc_E015_outage` | 9001 | 762801051 | `602B180B` | `602B180B` | YES |

**Gate 5B fingerprint: labels YES, tick counts YES, seeds YES, checksums 12/12 identical -> PASS.**

## Results of the re-run

### Per-case result matrix (24 frozen cases, re-run)

| # | Case | Route | Vc [m/s NED] | N | DVL gap [s] | hdg gap [s] | USBL burst [s] | USBL fused | DVL fused | transitions | health sequence | Integrity |
|---:|---|---|---|---:|---|---|---|---:|---:|---:|---|:---:|
| 1 | `X_Vc0_P1_lock_noUSBL` | X | [0.00 0.00 0.00] | 3601 | none | none | none | 0 | 90 | 0 | N | PASS |
| 2 | `X_Vc0_P2_dvlgap_noUSBL` | X | [0.00 0.00 0.00] | 3601 | 3.60-11.16 | none | none | 0 | 53 | 4 | N>D>P>R>N | PASS |
| 3 | `X_Vc0_P3_dvlgap_USBL` | X | [0.00 0.00 0.00] | 3601 | 3.60-11.16 | none | 4.50-11.70 | 6 | 53 | 4 | N>D>P>R>N | PASS |
| 4 | `X_Vc0_P4_dvlhdggap_USBL` | X | [0.00 0.00 0.00] | 3601 | 3.60-11.16 | 5.40-9.00 | 4.50-11.70 | 6 | 53 | 4 | N>D>P>R>N | PASS |
| 5 | `X_Vc_E015_P1_lock_noUSBL` | X | [0.00 0.15 0.00] | 3601 | none | none | none | 0 | 90 | 0 | N | PASS |
| 6 | `X_Vc_E015_P2_dvlgap_noUSBL` | X | [0.00 0.15 0.00] | 3601 | 3.60-11.16 | none | none | 0 | 53 | 4 | N>D>P>R>N | PASS |
| 7 | `X_Vc_E015_P3_dvlgap_USBL` | X | [0.00 0.15 0.00] | 3601 | 3.60-11.16 | none | 4.50-11.70 | 6 | 53 | 4 | N>D>P>R>N | PASS |
| 8 | `X_Vc_E015_P4_dvlhdggap_USBL` | X | [0.00 0.15 0.00] | 3601 | 3.60-11.16 | 5.40-9.00 | 4.50-11.70 | 6 | 53 | 4 | N>D>P>R>N | PASS |
| 9 | `XZ_Vc0_P1_lock_noUSBL` | XZ | [0.00 0.00 0.00] | 4401 | none | none | none | 0 | 110 | 0 | N | PASS |
| 10 | `XZ_Vc0_P2_dvlgap_noUSBL` | XZ | [0.00 0.00 0.00] | 4401 | 4.40-13.64 | none | none | 0 | 65 | 4 | N>D>P>R>N | PASS |
| 11 | `XZ_Vc0_P3_dvlgap_USBL` | XZ | [0.00 0.00 0.00] | 4401 | 4.40-13.64 | none | 5.50-14.30 | 8 | 65 | 4 | N>D>P>R>N | PASS |
| 12 | `XZ_Vc0_P4_dvlhdggap_USBL` | XZ | [0.00 0.00 0.00] | 4401 | 4.40-13.64 | 6.60-11.00 | 5.50-14.30 | 8 | 65 | 4 | N>D>P>R>N | PASS |
| 13 | `XZ_Vc_E015_P1_lock_noUSBL` | XZ | [0.00 0.15 0.00] | 4401 | none | none | none | 0 | 110 | 0 | N | PASS |
| 14 | `XZ_Vc_E015_P2_dvlgap_noUSBL` | XZ | [0.00 0.15 0.00] | 4401 | 4.40-13.64 | none | none | 0 | 65 | 4 | N>D>P>R>N | PASS |
| 15 | `XZ_Vc_E015_P3_dvlgap_USBL` | XZ | [0.00 0.15 0.00] | 4401 | 4.40-13.64 | none | 5.50-14.30 | 8 | 65 | 4 | N>D>P>R>N | PASS |
| 16 | `XZ_Vc_E015_P4_dvlhdggap_USBL` | XZ | [0.00 0.15 0.00] | 4401 | 4.40-13.64 | 6.60-11.00 | 5.50-14.30 | 8 | 65 | 4 | N>D>P>R>N | PASS |
| 17 | `R10_Vc0_P1_lock_noUSBL` | R10 | [0.00 0.00 0.00] | 9001 | none | none | none | 0 | 225 | 0 | N | PASS |
| 18 | `R10_Vc0_P2_dvlgap_noUSBL` | R10 | [0.00 0.00 0.00] | 9001 | 9.00-27.90 | none | none | 0 | 131 | 4 | N>D>P>R>N | PASS |
| 19 | `R10_Vc0_P3_dvlgap_USBL` | R10 | [0.00 0.00 0.00] | 9001 | 9.00-27.90 | none | 11.25-29.25 | 22 | 131 | 4 | N>D>P>R>N | PASS |
| 20 | `R10_Vc0_P4_dvlhdggap_USBL` | R10 | [0.00 0.00 0.00] | 9001 | 9.00-27.90 | 13.50-22.50 | 11.25-29.25 | 22 | 131 | 4 | N>D>P>R>N | PASS |
| 21 | `R10_Vc_E015_P1_lock_noUSBL` | R10 | [0.00 0.15 0.00] | 9001 | none | none | none | 0 | 225 | 0 | N | PASS |
| 22 | `R10_Vc_E015_P2_dvlgap_noUSBL` | R10 | [0.00 0.15 0.00] | 9001 | 9.00-27.90 | none | none | 0 | 131 | 4 | N>D>P>R>N | PASS |
| 23 | `R10_Vc_E015_P3_dvlgap_USBL` | R10 | [0.00 0.15 0.00] | 9001 | 9.00-27.90 | none | 11.25-29.25 | 22 | 131 | 4 | N>D>P>R>N | PASS |
| 24 | `R10_Vc_E015_P4_dvlhdggap_USBL` | R10 | [0.00 0.15 0.00] | 9001 | 9.00-27.90 | 13.50-22.50 | 11.25-29.25 | 22 | 131 | 4 | N>D>P>R>N | PASS |

## Parity against the prior evidence

Primary requirement is EXACT equality: identical class, size and value, with NaN matching NaN, on every compared quantity including every float. A single DECLARED FALLBACK TOLERANCE of 1e-12 absolute is recorded for floating-point quantities; any item that needs it is reported as TOL rather than EXACT so the reader can see it. Strings, labels, sequences, integers, counters and checksums have no tolerance at all.

### Parity by record

| # | Record | What is compared | Mode | Max abs difference | Result |
|---:|---|---|:---:|---:|:---:|
| 1 | `case_definitions` | labels, routes, currents, profiles, seeds of all 24 cases | EXACT | 0.000e+00 | PASS |
| 2 | `per_case_record` | the entire per-case record: labels, ticks, seeds, windows, integrity gates, packet counters, gap audits, health transitions and delays, manager tables, metrics, checksums and verdicts | EXACT | 0.000e+00 | PASS |
| 3 | `metrics` | post-hoc characterization metrics for all 24 cases | EXACT | 0.000e+00 | PASS |
| 4 | `harness_schedules` | per-case realized bus schedules (offered packet counts, USBL emission plan) | EXACT | 0.000e+00 | PASS |
| 5 | `profiles` | per-case realized outage windows and expected sequences | EXACT | 0.000e+00 | PASS |
| 6 | `estimator_series` | decimated estimator, health and MEASURED series for all 24 cases (position, velocity, attitude, current, covariance diagonal, validity, status, sequence, timestamps, health state, freshness) | EXACT | 0.000e+00 | PASS |
| 7 | `integrity_gate_matrix` | 24 x 15 per-case integrity gate matrix and its names | EXACT | 0.000e+00 | PASS |
| 8 | `determinism` | reverse-order replay results | EXACT | 0.000e+00 | PASS |
| 9 | `ablation` | state-machine ablation results and the static accommodation scan | EXACT | 0.000e+00 | PASS |
| 10 | `manager_negative_test` | injected malformed packets, expected and observed rejection reasons | EXACT | 0.000e+00 | PASS |
| 11 | `truth_blindness` | sanitization, scrambled-truth invariance and the static leak scan | EXACT | 0.000e+00 | PASS |
| 12 | `gate5b_fingerprint` | 12 frozen Gate 5B cases: labels, ticks, seeds and estimate checksums | EXACT | 0.000e+00 | PASS |
| 13 | `static_review` | static markers, declared asserts, truth-token scan | EXACT | 0.000e+00 | PASS |
| 14 | `declared_numerics` | declared schedule, estimator config and chain config summary | EXACT | 0.000e+00 | PASS |
| 15 | `hard_gate_names` | the 32 hard-gate names, in order | EXACT | 0.000e+00 | PASS |
| 16 | `claim_boundary` | accuracy status, outage-limit status, claim limit and the no-tuning statement | EXACT | 0.000e+00 | PASS |

### Per-case parity matrix

| # | Case | prior checksum | re-run checksum | counters | health sequence | timing max diff [s] | series max diff | metrics max diff | Parity |
|---:|---|---|---|:---:|:---:|---:|---:|---:|:---:|
| 1 | `X_Vc0_P1_lock_noUSBL` | `7F1F5C60` | `7F1F5C60` | YES | YES | 0.000e+00 | 0.000e+00 | 0.000e+00 | PASS |
| 2 | `X_Vc0_P2_dvlgap_noUSBL` | `58DF23A4` | `58DF23A4` | YES | YES | 0.000e+00 | 0.000e+00 | 0.000e+00 | PASS |
| 3 | `X_Vc0_P3_dvlgap_USBL` | `548048E7` | `548048E7` | YES | YES | 0.000e+00 | 0.000e+00 | 0.000e+00 | PASS |
| 4 | `X_Vc0_P4_dvlhdggap_USBL` | `F48B3CC7` | `F48B3CC7` | YES | YES | 0.000e+00 | 0.000e+00 | 0.000e+00 | PASS |
| 5 | `X_Vc_E015_P1_lock_noUSBL` | `60B33CAC` | `60B33CAC` | YES | YES | 0.000e+00 | 0.000e+00 | 0.000e+00 | PASS |
| 6 | `X_Vc_E015_P2_dvlgap_noUSBL` | `653D20D0` | `653D20D0` | YES | YES | 0.000e+00 | 0.000e+00 | 0.000e+00 | PASS |
| 7 | `X_Vc_E015_P3_dvlgap_USBL` | `13D97279` | `13D97279` | YES | YES | 0.000e+00 | 0.000e+00 | 0.000e+00 | PASS |
| 8 | `X_Vc_E015_P4_dvlhdggap_USBL` | `1D49977F` | `1D49977F` | YES | YES | 0.000e+00 | 0.000e+00 | 0.000e+00 | PASS |
| 9 | `XZ_Vc0_P1_lock_noUSBL` | `0211D206` | `0211D206` | YES | YES | 0.000e+00 | 0.000e+00 | 0.000e+00 | PASS |
| 10 | `XZ_Vc0_P2_dvlgap_noUSBL` | `48C9BF73` | `48C9BF73` | YES | YES | 0.000e+00 | 0.000e+00 | 0.000e+00 | PASS |
| 11 | `XZ_Vc0_P3_dvlgap_USBL` | `8A030B07` | `8A030B07` | YES | YES | 0.000e+00 | 0.000e+00 | 0.000e+00 | PASS |
| 12 | `XZ_Vc0_P4_dvlhdggap_USBL` | `AA18C93E` | `AA18C93E` | YES | YES | 0.000e+00 | 0.000e+00 | 0.000e+00 | PASS |
| 13 | `XZ_Vc_E015_P1_lock_noUSBL` | `44A561F6` | `44A561F6` | YES | YES | 0.000e+00 | 0.000e+00 | 0.000e+00 | PASS |
| 14 | `XZ_Vc_E015_P2_dvlgap_noUSBL` | `24400253` | `24400253` | YES | YES | 0.000e+00 | 0.000e+00 | 0.000e+00 | PASS |
| 15 | `XZ_Vc_E015_P3_dvlgap_USBL` | `45A42C99` | `45A42C99` | YES | YES | 0.000e+00 | 0.000e+00 | 0.000e+00 | PASS |
| 16 | `XZ_Vc_E015_P4_dvlhdggap_USBL` | `B1511DAF` | `B1511DAF` | YES | YES | 0.000e+00 | 0.000e+00 | 0.000e+00 | PASS |
| 17 | `R10_Vc0_P1_lock_noUSBL` | `87D9737D` | `87D9737D` | YES | YES | 0.000e+00 | 0.000e+00 | 0.000e+00 | PASS |
| 18 | `R10_Vc0_P2_dvlgap_noUSBL` | `2D98BAF6` | `2D98BAF6` | YES | YES | 0.000e+00 | 0.000e+00 | 0.000e+00 | PASS |
| 19 | `R10_Vc0_P3_dvlgap_USBL` | `D5E3E4EC` | `D5E3E4EC` | YES | YES | 0.000e+00 | 0.000e+00 | 0.000e+00 | PASS |
| 20 | `R10_Vc0_P4_dvlhdggap_USBL` | `D998A436` | `D998A436` | YES | YES | 0.000e+00 | 0.000e+00 | 0.000e+00 | PASS |
| 21 | `R10_Vc_E015_P1_lock_noUSBL` | `0FF25E86` | `0FF25E86` | YES | YES | 0.000e+00 | 0.000e+00 | 0.000e+00 | PASS |
| 22 | `R10_Vc_E015_P2_dvlgap_noUSBL` | `B7CF8399` | `B7CF8399` | YES | YES | 0.000e+00 | 0.000e+00 | 0.000e+00 | PASS |
| 23 | `R10_Vc_E015_P3_dvlgap_USBL` | `85D193AA` | `85D193AA` | YES | YES | 0.000e+00 | 0.000e+00 | 0.000e+00 | PASS |
| 24 | `R10_Vc_E015_P4_dvlhdggap_USBL` | `5A60BDFC` | `5A60BDFC` | YES | YES | 0.000e+00 | 0.000e+00 | 0.000e+00 | PASS |

The checksum is an Adler-32 over the **full-rate** estimated state pack - position, velocity, attitude, quaternion, both bias vectors, current, water-relative velocity, the covariance diagonal, validity, status, sequence, timestamps and source mask, plus the fused-packet total. The series columns compare the archived decimated series value by value. Together they say the re-run reproduced the estimator sample for sample, not just in summary.

### Declared semantic differences

- hard gate 26 process_deviation_declared: same name, same value (true), different underlying fact. The prior run declared a two-start DEVIATION; this run declares one-start COMPLIANCE. The gate asks whether the process record is complete and explicit, which both satisfy.
- task_id, gate label, mode string, sources, process record, artifact names, artifact byte counts, timestamps, pid and visual-QA numbers are deliberately NOT compared: they identify the run, not the computation.

### Availability state machine: transitions and timing, both runs

| Case | expected | observed | t_DEGRADED [s] | t_LOST [s] | t_RECOVERING [s] | t_NOMINAL [s] | model error [s] | prior identical |
|---|---|---|---:|---:|---:|---:|---:|:---:|
| `X_Vc0_P1_lock_noUSBL` | N | N | - | - | - | - | n/a | YES |
| `X_Vc0_P2_dvlgap_noUSBL` | N>D>P>R>N | N>D>P>R>N | 5.00 | 6.50 | 11.66 | 14.16 | 0.0000 | YES |
| `X_Vc0_P3_dvlgap_USBL` | N>D>P>R>N | N>D>P>R>N | 5.00 | 9.90 | 11.66 | 14.89 | 0.0000 | YES |
| `X_Vc0_P4_dvlhdggap_USBL` | N>D>P>R>N | N>D>P>R>N | 5.00 | 9.90 | 11.66 | 14.89 | 0.0000 | YES |
| `X_Vc_E015_P1_lock_noUSBL` | N | N | - | - | - | - | n/a | YES |
| `X_Vc_E015_P2_dvlgap_noUSBL` | N>D>P>R>N | N>D>P>R>N | 5.00 | 6.50 | 11.66 | 14.16 | 0.0000 | YES |
| `X_Vc_E015_P3_dvlgap_USBL` | N>D>P>R>N | N>D>P>R>N | 5.00 | 9.90 | 11.66 | 14.89 | 0.0000 | YES |
| `X_Vc_E015_P4_dvlhdggap_USBL` | N>D>P>R>N | N>D>P>R>N | 5.00 | 9.90 | 11.66 | 14.89 | 0.0000 | YES |
| `XZ_Vc0_P1_lock_noUSBL` | N | N | - | - | - | - | n/a | YES |
| `XZ_Vc0_P2_dvlgap_noUSBL` | N>D>P>R>N | N>D>P>R>N | 5.80 | 7.30 | 14.14 | 16.64 | 0.0000 | YES |
| `XZ_Vc0_P3_dvlgap_USBL` | N>D>P>R>N | N>D>P>R>N | 5.80 | 10.90 | 14.14 | 17.89 | 0.0000 | YES |
| `XZ_Vc0_P4_dvlhdggap_USBL` | N>D>P>R>N | N>D>P>R>N | 5.80 | 10.90 | 14.14 | 17.89 | 0.0000 | YES |
| `XZ_Vc_E015_P1_lock_noUSBL` | N | N | - | - | - | - | n/a | YES |
| `XZ_Vc_E015_P2_dvlgap_noUSBL` | N>D>P>R>N | N>D>P>R>N | 5.80 | 7.30 | 14.14 | 16.64 | 0.0000 | YES |
| `XZ_Vc_E015_P3_dvlgap_USBL` | N>D>P>R>N | N>D>P>R>N | 5.80 | 10.90 | 14.14 | 17.89 | 0.0000 | YES |
| `XZ_Vc_E015_P4_dvlhdggap_USBL` | N>D>P>R>N | N>D>P>R>N | 5.80 | 10.90 | 14.14 | 17.89 | 0.0000 | YES |
| `R10_Vc0_P1_lock_noUSBL` | N | N | - | - | - | - | n/a | YES |
| `R10_Vc0_P2_dvlgap_noUSBL` | N>D>P>R>N | N>D>P>R>N | 10.40 | 11.90 | 28.40 | 30.90 | 0.0000 | YES |
| `R10_Vc0_P3_dvlgap_USBL` | N>D>P>R>N | N>D>P>R>N | 10.40 | 16.90 | 28.40 | 32.89 | 0.0000 | YES |
| `R10_Vc0_P4_dvlhdggap_USBL` | N>D>P>R>N | N>D>P>R>N | 10.40 | 16.90 | 28.40 | 32.89 | 0.0000 | YES |
| `R10_Vc_E015_P1_lock_noUSBL` | N | N | - | - | - | - | n/a | YES |
| `R10_Vc_E015_P2_dvlgap_noUSBL` | N>D>P>R>N | N>D>P>R>N | 10.40 | 11.90 | 28.40 | 30.90 | 0.0000 | YES |
| `R10_Vc_E015_P3_dvlgap_USBL` | N>D>P>R>N | N>D>P>R>N | 10.40 | 16.90 | 28.40 | 32.89 | 0.0000 | YES |
| `R10_Vc_E015_P4_dvlhdggap_USBL` | N>D>P>R>N | N>D>P>R>N | 10.40 | 16.90 | 28.40 | 32.89 | 0.0000 | YES |

The model-error column is the difference between the instant the state machine declared a state and the instant predicted independently from the accept log; the tolerance is 0.010 s, two base ticks. The final column is the separate question this task exists to answer: whether those instants came back identical to the prior run.

### Exact packet accounting

| Case | DVL offered/consumed | heading offered | depth offered | INS offered | USBL offered/rejected/consumed | invariant | Match | Prior identical |
|---|---|---:|---:|---:|---|:---:|:---:|:---:|
| `X_Vc0_P1_lock_noUSBL` | 90/90 | 360 | 180 | 899 | 0/0/0 | YES | PASS | YES |
| `X_Vc0_P2_dvlgap_noUSBL` | 53/53 | 360 | 180 | 899 | 0/0/0 | YES | PASS | YES |
| `X_Vc0_P3_dvlgap_USBL` | 53/53 | 360 | 180 | 899 | 9/3/6 | YES | PASS | YES |
| `X_Vc0_P4_dvlhdggap_USBL` | 53/53 | 289 | 180 | 899 | 9/3/6 | YES | PASS | YES |
| `X_Vc_E015_P1_lock_noUSBL` | 90/90 | 360 | 180 | 899 | 0/0/0 | YES | PASS | YES |
| `X_Vc_E015_P2_dvlgap_noUSBL` | 53/53 | 360 | 180 | 899 | 0/0/0 | YES | PASS | YES |
| `X_Vc_E015_P3_dvlgap_USBL` | 53/53 | 360 | 180 | 899 | 9/3/6 | YES | PASS | YES |
| `X_Vc_E015_P4_dvlhdggap_USBL` | 53/53 | 289 | 180 | 899 | 9/3/6 | YES | PASS | YES |
| `XZ_Vc0_P1_lock_noUSBL` | 110/110 | 440 | 220 | 1099 | 0/0/0 | YES | PASS | YES |
| `XZ_Vc0_P2_dvlgap_noUSBL` | 65/65 | 440 | 220 | 1099 | 0/0/0 | YES | PASS | YES |
| `XZ_Vc0_P3_dvlgap_USBL` | 65/65 | 440 | 220 | 1099 | 11/3/8 | YES | PASS | YES |
| `XZ_Vc0_P4_dvlhdggap_USBL` | 65/65 | 353 | 220 | 1099 | 11/3/8 | YES | PASS | YES |
| `XZ_Vc_E015_P1_lock_noUSBL` | 110/110 | 440 | 220 | 1099 | 0/0/0 | YES | PASS | YES |
| `XZ_Vc_E015_P2_dvlgap_noUSBL` | 65/65 | 440 | 220 | 1099 | 0/0/0 | YES | PASS | YES |
| `XZ_Vc_E015_P3_dvlgap_USBL` | 65/65 | 440 | 220 | 1099 | 11/3/8 | YES | PASS | YES |
| `XZ_Vc_E015_P4_dvlhdggap_USBL` | 65/65 | 353 | 220 | 1099 | 11/3/8 | YES | PASS | YES |
| `R10_Vc0_P1_lock_noUSBL` | 225/225 | 900 | 450 | 2249 | 0/0/0 | YES | PASS | YES |
| `R10_Vc0_P2_dvlgap_noUSBL` | 131/131 | 900 | 450 | 2249 | 0/0/0 | YES | PASS | YES |
| `R10_Vc0_P3_dvlgap_USBL` | 131/131 | 900 | 450 | 2249 | 25/3/22 | YES | PASS | YES |
| `R10_Vc0_P4_dvlhdggap_USBL` | 131/131 | 721 | 450 | 2249 | 25/3/22 | YES | PASS | YES |
| `R10_Vc_E015_P1_lock_noUSBL` | 225/225 | 900 | 450 | 2249 | 0/0/0 | YES | PASS | YES |
| `R10_Vc_E015_P2_dvlgap_noUSBL` | 131/131 | 900 | 450 | 2249 | 0/0/0 | YES | PASS | YES |
| `R10_Vc_E015_P3_dvlgap_USBL` | 131/131 | 900 | 450 | 2249 | 25/3/22 | YES | PASS | YES |
| `R10_Vc_E015_P4_dvlhdggap_USBL` | 131/131 | 721 | 450 | 2249 | 25/3/22 | YES | PASS | YES |

### Behaviour inside the declared gaps

| Case | DVL updates in gap | heading updates in gap | USBL fused in burst | DVL resumes | Result |
|---|---:|---:|---:|:---:|:---:|
| `X_Vc0_P1_lock_noUSBL` | 0 | 0 | 0 | YES | PASS |
| `X_Vc0_P2_dvlgap_noUSBL` | 0 | 0 | 0 | YES | PASS |
| `X_Vc0_P3_dvlgap_USBL` | 0 | 0 | 0 | YES | PASS |
| `X_Vc0_P4_dvlhdggap_USBL` | 0 | 0 | 0 | YES | PASS |
| `X_Vc_E015_P1_lock_noUSBL` | 0 | 0 | 0 | YES | PASS |
| `X_Vc_E015_P2_dvlgap_noUSBL` | 0 | 0 | 0 | YES | PASS |
| `X_Vc_E015_P3_dvlgap_USBL` | 0 | 0 | 0 | YES | PASS |
| `X_Vc_E015_P4_dvlhdggap_USBL` | 0 | 0 | 0 | YES | PASS |
| `XZ_Vc0_P1_lock_noUSBL` | 0 | 0 | 0 | YES | PASS |
| `XZ_Vc0_P2_dvlgap_noUSBL` | 0 | 0 | 0 | YES | PASS |
| `XZ_Vc0_P3_dvlgap_USBL` | 0 | 0 | 0 | YES | PASS |
| `XZ_Vc0_P4_dvlhdggap_USBL` | 0 | 0 | 0 | YES | PASS |
| `XZ_Vc_E015_P1_lock_noUSBL` | 0 | 0 | 0 | YES | PASS |
| `XZ_Vc_E015_P2_dvlgap_noUSBL` | 0 | 0 | 0 | YES | PASS |
| `XZ_Vc_E015_P3_dvlgap_USBL` | 0 | 0 | 0 | YES | PASS |
| `XZ_Vc_E015_P4_dvlhdggap_USBL` | 0 | 0 | 0 | YES | PASS |
| `R10_Vc0_P1_lock_noUSBL` | 0 | 0 | 0 | YES | PASS |
| `R10_Vc0_P2_dvlgap_noUSBL` | 0 | 0 | 0 | YES | PASS |
| `R10_Vc0_P3_dvlgap_USBL` | 0 | 0 | 0 | YES | PASS |
| `R10_Vc0_P4_dvlhdggap_USBL` | 0 | 0 | 0 | YES | PASS |
| `R10_Vc_E015_P1_lock_noUSBL` | 0 | 0 | 0 | YES | PASS |
| `R10_Vc_E015_P2_dvlgap_noUSBL` | 0 | 0 | 0 | YES | PASS |
| `R10_Vc_E015_P3_dvlgap_USBL` | 0 | 0 | 0 | YES | PASS |
| `R10_Vc_E015_P4_dvlhdggap_USBL` | 0 | 0 | 0 | YES | PASS |

USBL is fused only from packets the bus declares present and valid, the estimator is never reset on loss or recovery (`single_explicit_initialization` holds in all 24 cases), and the ESTIMATED bus stays VALID through every outage.

### Estimation error and drift (CHARACTERIZATION, NOT_CERTIFIED, unchanged from the prior run)

| Case | pos abs RMSE [m] | pos rel RMSE [m] | vel RMSE [m/s] | yaw RMSE [deg] | depth RMSE [m] | gap drift [m] | drift slope [m/s] |
|---|---:|---:|---:|---:|---:|---:|---:|
| `X_Vc0_P1_lock_noUSBL` | 0.068 | 0.068 | 0.010 | 1.02 | 0.046 | - | - |
| `X_Vc0_P2_dvlgap_noUSBL` | 0.068 | 0.068 | 0.010 | 1.02 | 0.046 | 0.045 | 0.007 |
| `X_Vc0_P3_dvlgap_USBL` | 1.305 | 1.253 | 0.010 | 1.02 | 0.046 | -0.493 | -0.019 |
| `X_Vc0_P4_dvlhdggap_USBL` | 1.603 | 1.549 | 0.010 | 1.01 | 0.046 | 0.619 | 0.016 |
| `X_Vc_E015_P1_lock_noUSBL` | 0.069 | 0.074 | 0.011 | 1.01 | 0.049 | - | - |
| `X_Vc_E015_P2_dvlgap_noUSBL` | 0.069 | 0.074 | 0.011 | 1.01 | 0.049 | 0.039 | 0.005 |
| `X_Vc_E015_P3_dvlgap_USBL` | 1.580 | 1.529 | 0.011 | 1.01 | 0.049 | -1.154 | -0.038 |
| `X_Vc_E015_P4_dvlhdggap_USBL` | 1.054 | 1.038 | 0.011 | 0.98 | 0.049 | -0.128 | -0.008 |
| `XZ_Vc0_P1_lock_noUSBL` | 0.073 | 0.090 | 0.010 | 0.98 | 0.037 | - | - |
| `XZ_Vc0_P2_dvlgap_noUSBL` | 0.073 | 0.090 | 0.010 | 0.98 | 0.037 | 0.055 | 0.006 |
| `XZ_Vc0_P3_dvlgap_USBL` | 2.042 | 1.997 | 0.010 | 0.98 | 0.037 | -0.510 | -0.021 |
| `XZ_Vc0_P4_dvlhdggap_USBL` | 1.489 | 1.451 | 0.010 | 0.99 | 0.037 | -0.135 | -0.005 |
| `XZ_Vc_E015_P1_lock_noUSBL` | 0.075 | 0.085 | 0.010 | 1.06 | 0.037 | - | - |
| `XZ_Vc_E015_P2_dvlgap_noUSBL` | 0.075 | 0.085 | 0.010 | 1.06 | 0.037 | 0.049 | 0.006 |
| `XZ_Vc_E015_P3_dvlgap_USBL` | 0.734 | 0.701 | 0.010 | 1.06 | 0.037 | -0.712 | -0.022 |
| `XZ_Vc_E015_P4_dvlhdggap_USBL` | 0.679 | 0.704 | 0.010 | 1.06 | 0.037 | 0.026 | 0.001 |
| `R10_Vc0_P1_lock_noUSBL` | 9.887 | 0.191 | 0.011 | 0.67 | 0.045 | - | - |
| `R10_Vc0_P2_dvlgap_noUSBL` | 9.887 | 0.191 | 0.011 | 0.68 | 0.045 | 0.102 | 0.005 |
| `R10_Vc0_P3_dvlgap_USBL` | 2.792 | 10.687 | 0.011 | 0.68 | 0.045 | -0.086 | 0.001 |
| `R10_Vc0_P4_dvlhdggap_USBL` | 3.085 | 10.540 | 0.011 | 0.68 | 0.045 | 0.435 | 0.010 |
| `R10_Vc_E015_P1_lock_noUSBL` | 9.893 | 0.183 | 0.012 | 0.66 | 0.046 | - | - |
| `R10_Vc_E015_P2_dvlgap_noUSBL` | 9.893 | 0.183 | 0.012 | 0.68 | 0.046 | 0.086 | 0.005 |
| `R10_Vc_E015_P3_dvlgap_USBL` | 3.492 | 11.394 | 0.012 | 0.68 | 0.046 | 0.104 | 0.005 |
| `R10_Vc_E015_P4_dvlhdggap_USBL` | 3.188 | 11.377 | 0.012 | 0.66 | 0.046 | 0.028 | -0.001 |

These are reproduced, not re-derived from a changed model. They describe the ASSUMED scenario and nothing else; no statement is made about how long this vehicle could actually navigate without aiding.

## Gates

### Per-case integrity gates

| Gate | Cases passing |
|---|:---:|
| `finite_state_covariance` | 24/24 |
| `covariance_symmetric_psd` | 24/24 |
| `monotonic_estimate_time_sequence` | 24/24 |
| `quaternion_norm` | 24/24 |
| `no_invalid_packet_fused` | 24/24 |
| `fused_packet_ordering` | 24/24 |
| `usbl_fused_only_when_present` | 24/24 |
| `estimated_invalid_before_init` | 24/24 |
| `estimated_valid_after_init` | 24/24 |
| `single_explicit_initialization` | 24/24 |
| `manager_counter_invariant` | 24/24 |
| `estimated_interface_complete` | 24/24 |
| `health_states_in_declared_set` | 24/24 |
| `health_transition_adjacency_legal` | 24/24 |
| `health_recompute_deterministic` | 24/24 |

### The 32 hard gates (same names and definitions as the prior run)

| # | Hard gate | Result |
|---:|---|:---:|
| 1 | `finite_and_psd_24_of_24` | PASS |
| 2 | `monotonic_time_and_sequence` | PASS |
| 3 | `quaternion_norm` | PASS |
| 4 | `no_truth_leakage` | PASS |
| 5 | `exact_packet_counters` | PASS |
| 6 | `no_invalid_packet_fused` | PASS |
| 7 | `fused_packet_ordering` | PASS |
| 8 | `usbl_fused_only_when_valid` | PASS |
| 9 | `zero_dvl_updates_in_gap` | PASS |
| 10 | `zero_heading_updates_in_gap` | PASS |
| 11 | `rejects_invalid_stale_out_of_order` | PASS |
| 12 | `health_transition_order_correct` | PASS |
| 13 | `zero_false_transitions_in_lock` | PASS |
| 14 | `detection_timing_within_bound` | PASS |
| 15 | `recovery_timing_within_bound` | PASS |
| 16 | `health_states_declared_set` | PASS |
| 17 | `health_status_only_no_accommodation` | PASS |
| 18 | `no_estimator_reset_on_loss` | PASS |
| 19 | `estimate_valid_through_outage` | PASS |
| 20 | `estimated_interface_complete` | PASS |
| 21 | `deterministic_replay_24_of_24` | PASS |
| 22 | `gate5b_fingerprint_exact` | PASS |
| 23 | `cases_24_of_24` | PASS |
| 24 | `declared_asserts` | PASS |
| 25 | `sources_exactly_three` | PASS |
| 26 | `process_deviation_declared` | PASS |
| 27 | `production_fingerprints_exact` | PASS |
| 28 | `codex_vertical_plan_untouched` | PASS |
| 29 | `gate5b_files_unmodified` | PASS |
| 30 | `gate4_waiver_shadow_only` | PASS |
| 31 | `no_promotion_in_this_task` | PASS |
| 32 | `artifacts_readable_and_bounded` | PASS |

**Hard gates: 32/32 PASS.**

### Validation gates (this task only)

| # | Validation gate | Result |
|---:|---|:---:|
| 1 | `one_matlab_process` | PASS |
| 2 | `static_review_before_execution` | PASS |
| 3 | `sources_exactly_three_no_repo_scan` | PASS |
| 4 | `prior_evidence_loaded_complete` | PASS |
| 5 | `schedule_and_config_identical` | PASS |
| 6 | `full_parity_exact_or_declared_tol` | PASS |
| 7 | `prior_gate5c_artifacts_unmodified` | PASS |
| 8 | `cases_24_of_24` | PASS |
| 9 | `hard_gates_32_of_32` | PASS |
| 10 | `png_validated` | PASS |
| 11 | `md_tables_24_rows` | PASS |
| 12 | `outputs_under_300_MiB` | PASS |
| 13 | `logs_appended_once` | PASS |
| 14 | `no_tuning_no_retune` | PASS |
| 15 | `prior_status_recorded` | PASS |
| 16 | `accuracy_remains_not_certified` | PASS |
| 17 | `gate4_shadow_only` | PASS |

**Validation gates: 17/17 PASS.**

## Invariance evidence, re-established in this process

| Evidence | Result |
|---|:---:|
| Reverse-order replay: estimated state bitwise identical, 24/24 | YES |
| Reverse-order replay: checksums and health timelines identical | YES |
| Disabling the state machine leaves the estimate bitwise identical, 24/24 cases | YES |
| Halving every dwell threshold leaves the estimate bitwise identical | YES |
| ... while the health timeline itself does respond, so the ablation is not vacuous | YES |
| Static scan: no health variable feeds a propagation, gain, covariance, admission or reset (0 violations) | YES |
| USBL truth-reference field present on the bus, absent after sanitization | YES |
| Re-running on the sanitized bus alone is bitwise identical | YES |
| Scrambling every truth-side field changes nothing | YES |
| Static truth-token scan violations | 0 |
| Injected malformed packets refused: 32/32, admitted 0, fused 0 | YES |
| Every injected packet refused for the predeclared reason | YES |
| Injection leaves the clean estimate bitwise untouched | YES |

### Manager negative test detail

| Case | Injected fault | Expected rejection | Observed | Match |
|---|---|---|---|:---:|
| `X_Vc0_P1_lock_noUSBL` | `usbl_flagged_invalid` | `channel_absent` | `channel_absent` | YES |
| `X_Vc0_P1_lock_noUSBL` | `usbl_nonfinite_payload` | `channel_absent` | `channel_absent` | YES |
| `X_Vc0_P1_lock_noUSBL` | `usbl_out_of_icd_bounds` | `channel_absent` | `channel_absent` | YES |
| `X_Vc0_P1_lock_noUSBL` | `usbl_quality_below_admission` | `channel_absent` | `channel_absent` | YES |
| `X_Vc0_P1_lock_noUSBL` | `usbl_stale_beyond_limit` | `channel_absent` | `channel_absent` | YES |
| `X_Vc0_P1_lock_noUSBL` | `usbl_replayed_old_sequence` | `channel_absent` | `channel_absent` | YES |
| `X_Vc0_P1_lock_noUSBL` | `usbl_out_of_order_timestamp` | `channel_absent` | `channel_absent` | YES |
| `X_Vc0_P1_lock_noUSBL` | `dvl_stale_packet_inside_gap` | `stale_age` | `stale_age` | YES |
| `X_Vc0_P2_dvlgap_noUSBL` | `usbl_flagged_invalid` | `channel_absent` | `channel_absent` | YES |
| `X_Vc0_P2_dvlgap_noUSBL` | `usbl_nonfinite_payload` | `channel_absent` | `channel_absent` | YES |
| `X_Vc0_P2_dvlgap_noUSBL` | `usbl_out_of_icd_bounds` | `channel_absent` | `channel_absent` | YES |
| `X_Vc0_P2_dvlgap_noUSBL` | `usbl_quality_below_admission` | `channel_absent` | `channel_absent` | YES |
| `X_Vc0_P2_dvlgap_noUSBL` | `usbl_stale_beyond_limit` | `channel_absent` | `channel_absent` | YES |
| `X_Vc0_P2_dvlgap_noUSBL` | `usbl_replayed_old_sequence` | `channel_absent` | `channel_absent` | YES |
| `X_Vc0_P2_dvlgap_noUSBL` | `usbl_out_of_order_timestamp` | `channel_absent` | `channel_absent` | YES |
| `X_Vc0_P2_dvlgap_noUSBL` | `dvl_stale_packet_inside_gap` | `stale_age` | `stale_age` | YES |
| `X_Vc0_P3_dvlgap_USBL` | `usbl_flagged_invalid` | `not_valid` | `not_valid` | YES |
| `X_Vc0_P3_dvlgap_USBL` | `usbl_nonfinite_payload` | `nonfinite_value` | `nonfinite_value` | YES |
| `X_Vc0_P3_dvlgap_USBL` | `usbl_out_of_icd_bounds` | `out_of_bounds` | `out_of_bounds` | YES |
| `X_Vc0_P3_dvlgap_USBL` | `usbl_quality_below_admission` | `low_quality` | `low_quality` | YES |
| `X_Vc0_P3_dvlgap_USBL` | `usbl_stale_beyond_limit` | `stale_age` | `stale_age` | YES |
| `X_Vc0_P3_dvlgap_USBL` | `usbl_replayed_old_sequence` | `seq_not_increasing` | `seq_not_increasing` | YES |
| `X_Vc0_P3_dvlgap_USBL` | `usbl_out_of_order_timestamp` | `timestamp_not_increasing` | `timestamp_not_increasing` | YES |
| `X_Vc0_P3_dvlgap_USBL` | `dvl_stale_packet_inside_gap` | `stale_age` | `stale_age` | YES |
| `X_Vc0_P4_dvlhdggap_USBL` | `usbl_flagged_invalid` | `not_valid` | `not_valid` | YES |
| `X_Vc0_P4_dvlhdggap_USBL` | `usbl_nonfinite_payload` | `nonfinite_value` | `nonfinite_value` | YES |
| `X_Vc0_P4_dvlhdggap_USBL` | `usbl_out_of_icd_bounds` | `out_of_bounds` | `out_of_bounds` | YES |
| `X_Vc0_P4_dvlhdggap_USBL` | `usbl_quality_below_admission` | `low_quality` | `low_quality` | YES |
| `X_Vc0_P4_dvlhdggap_USBL` | `usbl_stale_beyond_limit` | `stale_age` | `stale_age` | YES |
| `X_Vc0_P4_dvlhdggap_USBL` | `usbl_replayed_old_sequence` | `seq_not_increasing` | `seq_not_increasing` | YES |
| `X_Vc0_P4_dvlhdggap_USBL` | `usbl_out_of_order_timestamp` | `timestamp_not_increasing` | `timestamp_not_increasing` | YES |
| `X_Vc0_P4_dvlhdggap_USBL` | `dvl_stale_packet_inside_gap` | `stale_age` | `stale_age` | YES |

## Isolation, preservation and fingerprints

| Frozen production artifact | Bytes | Unchanged in this run | Matches the Gate 5A/5B/5C record |
|---|---:|:---:|:---:|
| `controller_law.m` | 9402 | YES | YES |
| `guidance_law.m` | 14601 | YES | YES |
| `continuous_path_tracking.m` | 10845 | YES | YES |
| `underwater777_vehicle_dynamics.m` | 6065 | YES | YES |
| `init_parameters.m` | 4205 | YES | YES |
| `underwater777_vehicle_dynamics_current.m` | 7814 | YES | YES |
| `suite_results\CODEX_VERTICAL_PLAN.md` | 43101 | YES | YES |

| Gate 5B file | Bytes | Adler-32 | Unchanged |
|---|---:|---|:---:|
| `navigation_multirate_ekf_baseline.m` | 54872 | `600A2D87` | YES |
| `run_nav_multirate_ekf_baseline_repair.m` | 105179 | `FE972817` | YES |
| `navigation_multirate_sensor_chain.m` | 38787 | `FE1B3A92` | YES |
| `suite_results\NAV_MULTIRATE_EKF_BASELINE.md` | 25111 | `26579162` | YES |
| `suite_results\NAV_MULTIRATE_EKF_BASELINE.mat` | 6495676 | `7467B02E` | YES |
| `suite_results\NAV_MULTIRATE_EKF_BASELINE.png` | 486613 | `008AED70` | YES |
| `suite_results\NAV_MULTIRATE_EKF_BASELINE_REPAIR.md` | 32318 | `8ADA7B8F` | YES |
| `suite_results\NAV_MULTIRATE_EKF_BASELINE_REPAIR.mat` | 6728748 | `2A6AE455` | YES |
| `suite_results\NAV_MULTIRATE_EKF_BASELINE_REPAIR.png` | 494437 | `B491782D` | YES |

| Prior Gate 5C artifact / input | Bytes | Adler-32 | Unchanged |
|---|---:|---|:---:|
| `suite_results\NAV_AVAILABILITY_OUTAGE_STRESS.md` | 52674 | `820180EE` | YES |
| `suite_results\NAV_AVAILABILITY_OUTAGE_STRESS.mat` | 13376162 | `EA4436EA` | YES |
| `suite_results\NAV_AVAILABILITY_OUTAGE_STRESS.png` | 451483 | `F065EA27` | YES |
| `navigation_multirate_ekf_availability.m` | 72784 | `F520557C` | YES |
| `run_nav_availability_outage_stress.m` | 136165 | `7C39947C` | YES |

- The Gate 5B artifact hashes still match the recorded reference: YES.
- `CODEX_VERTICAL_PLAN.md` untouched: YES.
- The three prior Gate 5C artifacts and the two Gate 5C code files are INPUTS here and are byte-, timestamp- and Adler-32-identical after the run: YES.
- Production plant, controller and guidance were never invoked.
- Gate 4 waiver remains **OPEN / shadow-only**; nothing here promotes it.

## Visual QA and artifact budget

- `NAV_AVAILABILITY_OUTAGE_STRESS_VALIDATION.png`: 12 panels, 435083 bytes, 2550 x 1800 px, ink 0.203, gray std 57.3.
- Decoded after writing with `imread`: YES. Thresholds (width>=1400, height>=900, 0.01<ink<0.95, gray std>5, bytes>80000): YES.
- panel 1 parity items: one labelled bar per compared record
- panel 2 per-case parity: checksum, counters, sequence, series, metrics
- panel 3 estimator series max abs difference per case, log axis
- panel 4 health declaration instants, this run against the prior run
- panel 5 metrics max abs difference per case, log axis
- panel 6 health timeline overlay, prior and re-run, showcase case
- panel 7 the 32 hard gates, one labelled bar per gate
- panel 8 the validation gates, one labelled bar per gate
- panel 9 Gate 5B 12-case checksum reproduction
- panel 10 per-case parity table legible at full resolution
- panel 11 preserved prior artifacts with bytes and Adler-32
- panel 12 process record, provenance and claim boundary

| Artifact | Bytes |
|---|---:|
| `NAV_AVAILABILITY_OUTAGE_STRESS_VALIDATION.md` | 45967 |
| `NAV_AVAILABILITY_OUTAGE_STRESS_VALIDATION.mat` | 13475914 |
| `NAV_AVAILABILITY_OUTAGE_STRESS_VALIDATION.png` | 435083 |
| **total** | **13956964 (13.310 MiB)** |

- Budget **< 300 MiB**: PASS.
- The delivered Markdown is read back from disk and both 24-row tables decoded: result table 24 rows (cells YES, labels YES -> PASS), parity table 24 rows (cells YES, labels YES -> PASS).

### Post-write rechecks on the delivered artifacts

| Recheck | Result |
|---|:---:|
| Per-case result table decoded from the delivered MD | PASS |
| Per-case parity table decoded from the delivered MD | PASS |
| Gate 5B files still unchanged after every write | PASS |
| Prior Gate 5C artifacts still unchanged after every write | PASS |
| Each of the three logs grew and carries this task id exactly once | PASS |
| PNG still decodable and readable | PASS |
| Total artifact bytes under budget (13.313 MiB) | PASS |

## Gate decision

- **Gate 5C: FORMALIZED - PASS, process compliant.**
- Basis: one MATLAB start; 24/24 frozen cases integrity-clean; 32/32 hard gates; 17/17 validation gates; 16/16 parity records identical to the prior evidence with 16 bitwise exact and a largest observed difference of 0.000e+00; the frozen Gate 5B fingerprint reproduced 12/12; and every prior artifact proved unmodified.
- GATE 5C FORMALIZED: PASS on integrity and availability state-machine behaviour, PROCESS COMPLIANT. The technical result of NAV_AVAILABILITY_OUTAGE_STRESS_001 (TECHNICAL_PASS / PROCESS_NONCOMPLIANT) is reproduced exactly in a single MATLAB start, so the process objection is discharged and Gate 5C stands as formal evidence. Accuracy and outage endurance remain CHARACTERIZATION and NOT_CERTIFIED; Gate 4 waiver remains OPEN / shadow-only; nothing is promoted.
- The prior run `NAV_AVAILABILITY_OUTAGE_STRESS_001` keeps its recorded status **TECHNICAL_PASS / PROCESS_NONCOMPLIANT**. Its numbers are now corroborated by an independent, process-clean execution rather than by its own second start.
- **Accuracy status: NOT_CERTIFIED. Outage limits: CHARACTERIZATION_NOT_CERTIFIED.** Unchanged by this task, which validates reproducibility and process, not physics.
- **No promotion.** Gate 5B remains as it was; Gate 4 waiver remains OPEN / shadow-only.
- Claim limit: Integrity, interface and availability state-machine behaviour only. No navigation-accuracy and no outage-endurance claim. Simulation-only; nothing here is bench or sea-trial validated.

## Limitations, stated plainly

- This task validates **reproducibility and process**. It does not add one bit of physical evidence: every sensor numeric, filter constant, dwell time and outage window is still ASSUMED, and TRUTH is still a prescribed kinematic scenario.
- Parity is measured on the same machine, the same MATLAB release and the same frozen inputs. It proves the computation is deterministic and the prior record is faithful; it does not prove cross-platform or cross-release reproducibility.
- The harness is a verbatim transcription of source 2 rather than a call into it. The transcription is proved by literal-text markers and by exact comparison of the reconstructed schedule and config against the prior MAT, but a defect present in both the original and the copy would be reproduced, not caught.
- Full-rate estimator series are compared through the Adler-32 state-pack checksum plus the archived decimated series. A difference that is invisible to both is conceivable though vanishingly unlikely; no full-rate series was archived in either run, by budget policy.
- The USBL model, the latency-as-inflated-R approximation, the unmodelled sensor biases and the message-age nature of the health machine are all inherited unchanged from Gate 5C and remain exactly as limited as they were.
- No accommodation policy exists, so nothing here says what the vehicle should *do* about a `POSITION_AID_LOST` declaration.
- Simulation-only. Nothing here is hardware, bench or sea-trial evidence.

## Next task

- GATE 6 (named because Gate 5C is now formalized, NOT attempted here): PROPULSION / POWER / COMPUTE budget and margin. Take the actuator commands and the navigation duty cycle this vertical already produces and close them against a declared thruster and control-surface power model, an energy budget over the mission profile, and a compute-load / latency budget for the estimator and controller rates. Numerics remain ASSUMED and every result remains NOT_CERTIFIED until bench data exists.

## MATHEMATICAL_RECORD

```
MATHEMATICAL_RECORD = {
  task_class: PROCESS_COMPLIANT_REVALIDATION (Gate 5C, isolated, no promotion),
  equations: unchanged from Gate 5C - the estimator library was executed, not edited:
    nominal: p' = v,  v' = R_bn (f_m - b_a) + g_NED,  q' = 0.5 q (x) [0; w_m - b_g],
    measure: z_depth = p_D, z_psi = psi(q), z_ins = v_NED,
             z_dvl = R_bn'(v_NED - c_NED),  z_usbl = p_NED,
    update : P+ = (I-KH) P (I-KH)' + K R_eff K' (Joseph), reset G_thth = I - 0.5[dth]x,
    health : tau_fresh(c) = max(k_fresh*period, stale_limit+period, tau_floor),
             hysteretic dwell machine over NOMINAL/DEGRADED/POSITION_AID_LOST/RECOVERING,
             status only, evaluated after the tick loop, no authority,
  parity_definition: {
    exact: identical class, size and value with NaN matching NaN,
    declared_fallback_tolerance: 1.0e-12 absolute, floats only, reported as TOL when used,
    compared: case definitions, per-case record, metrics, harness schedules, profiles,
              decimated estimator and health series, integrity gate matrix, determinism,
              ablation, negative test, truth blindness, Gate 5B fingerprint, static
              review, declared numerics, hard-gate names, claim boundary,
    not_compared: task identity, process record, artifact names, byte counts,
                  timestamps, pid and visual-QA numbers
  },
  observed: { parity_records 16/16, exact 16, max_abs_diff 0.000e+00,
              per_case_parity 24/24, gate5b_checksums 12/12 },
  parameter_provenance: {
    VALIDATED (this task): reproducibility of every recorded Gate 5C number in a single
             MATLAB start, and preservation of every frozen input and prior artifact,
    DERIVED: sigma_a, sigma_g, tau_fresh, USBL latency scale (= U_ground),
    ASSUMED: all R, P0, dwell times, admission thresholds and the whole outage schedule,
    IDENTIFIED: none,  TUNED: none (NO_TUNING_RERUN, transcription proved verbatim)
  },
  design_reason: 'A result that needed two starts to publish is a result nobody has yet
                  reproduced. Re-deriving it once, cleanly, and diffing every recorded
                  number is the cheapest way to convert a technical pass into evidence.',
  rejected_alternatives: {
    call_the_prior_driver_directly: rejected (it overwrites the artifacts under test),
    edit_the_prior_driver_to_add_a_dry_run_flag: rejected (mutates a frozen input),
    accept_the_prior_PASS_on_its_own_console_output: rejected (unfalsifiable),
    compare_only_summary_metrics: rejected (summaries hide sample-level divergence),
    loosen_parity_to_a_percentage: rejected (a deterministic re-run must be exact),
    re-tune_anything_to_make_parity_close: rejected (would void the whole exercise)
  },
  evidence: { suite_results/NAV_AVAILABILITY_OUTAGE_STRESS_VALIDATION.{md,mat,png} },
  conclusion: 'PASS: 24/24 frozen cases integrity-clean, 32/32 hard gates, 17/17
                validation gates, 16/16 parity records, one MATLAB start;
                accuracy and outage limits remain CHARACTERIZATION / NOT_CERTIFIED',
  open_questions: { cross-release and cross-platform reproducibility untested;
                    a defect shared by original and transcription would survive;
                    no full-rate series archived, parity rests on checksum plus
                    decimated series; accommodation policy still absent }
}
```

## Artifacts

- `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\NAV_AVAILABILITY_OUTAGE_STRESS_VALIDATION.md`
- `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\NAV_AVAILABILITY_OUTAGE_STRESS_VALIDATION.mat`
- `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\NAV_AVAILABILITY_OUTAGE_STRESS_VALIDATION.png`

Preserved inputs (not modified): the Gate 5B library, driver and artifact set; the Gate 5C estimator fork, driver and artifact set; the frozen production files and `CODEX_VERTICAL_PLAN.md`.

Root: `C:\Users\ardak\MATLAB\Projects\AUVsim-main`
