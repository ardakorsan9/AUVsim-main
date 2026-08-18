# NAV_MULTIRATE_SENSOR_CHAIN_VALIDATION_001 - Gate 5A independent, process-compliant validation

**Overall verdict: PASS** - re-establishes the Gate 5A sensor-chain contract evidence inside a single MATLAB process. **No navigation-performance claim is made. No estimator exists. All sensor numerics remain ASSUMED.**

## Why this task exists: recorded process noncompliance

| Item | Prior task | This task |
|---|---|---|
| TASK_ID | `NAV_MULTIRATE_SENSOR_CHAIN_001` | `NAV_MULTIRATE_SENSOR_CHAIN_VALIDATION_001` |
| MATLAB starts used | **4 (NONCOMPLIANT)** | **1 (COMPLIANT)** |
| Technical verdict | TECHNICAL_PASS | PASS |
| Process validity | **process-invalid** | process-valid |
| Can formalize Gate 5A | NO | YES |

PROCESS NONCOMPLIANCE, EXPLICITLY RECORDED: the prior task NAV_MULTIRATE_SENSOR_CHAIN_001 started MATLAB four times, violating the one-invocation-per-task policy. Its TECHNICAL_PASS is therefore technically credible but process-invalid, and could not by itself formalize Gate 5A. This validation re-establishes the identical evidence inside exactly one MATLAB process, so the gate decision rests on a compliant run.

- This run: MATLAB R2025b, pid 22752, started 2026-08-08 14:12:06, single `-batch` invocation:

```
/mnt/d/ardak/matlab/bin/matlab.exe -batch "cd('C:/Users/ardak/MATLAB/Projects/AUVsim-main'); run_nav_multirate_sensor_chain_validation;"
```

- The prior artifacts are **preserved untouched** (YES): `NAV_MULTIRATE_SENSOR_CHAIN.{md,mat,png}` byte counts and modification times are identical before and after this run. `run_nav_multirate_sensor_chain.m` was deliberately **never executed**, because executing it would overwrite the very artifact being validated.

## Sources read (exactly three, no repo scan)

| # | Source | Used for |
|---|---|---|
| 1 | `navigation_multirate_sensor_chain.m` | frozen library under test: statically reviewed, then executed unchanged |
| 2 | `run_nav_multirate_sensor_chain.m` | frozen 12-case matrix definition: statically reviewed only, never invoked |
| 3 | `suite_results/NAV_MULTIRATE_SENSOR_CHAIN.mat` | prior artifact: parity reference and record of the declared upstream rates / hooks |

Exactly three sources. The three upstream sources of the prior task (underwater777_vehicle_dynamics_current.m, run_sensor_noise_current_audit.m, SENSOR_NOISE_CURRENT_AUDIT.mat) are deliberately NOT re-read; their declared rates and hook classification are taken from the prior MAT record instead.

Static review preceded execution and MATLAB was never started for probing, so the single permitted invocation was spent on the validation itself. Frozen-definition markers found in the sources: YES.

| Static marker | Found |
|---|:---:|
| `run_routes` | YES |
| `run_Vc_set` | YES |
| `run_Vc_tag` | YES |
| `run_dvl_set` | YES |
| `run_dvl_tag` | YES |
| `run_label_fmt` | YES |
| `run_case_count` | YES |
| `lib_task_id` | YES |
| `lib_dt_base` | YES |
| `lib_U_ground` | YES |
| `lib_outage_frac` | YES |
| `lib_usbl_case` | YES |
| `lib_est_unavail` | YES |
| `lib_no_shared_state` | YES |
| `all_ok` | YES |

Declared production rates, taken from the prior record rather than re-read: `dt_controller`=0.0250 s, `dt_guidance`=0.0750 s, `tau_rate`=0.0500 s, `U`=1.50 m/s. The base-tick and speed asserts of the original task were re-checked against them: YES.

## No tuning, no numeric change

- Config parity against the prior record: schema identical YES, max relative deviation 0 across every channel rate, period, delay, sigma, bias, scale error, nominal quality, bound, stale limit, dropout limit, tick count and seed offset, plus `dt_base`, `U_ground`, `g`, seabed depth, outage window and DVL bottom-lock range.
- The 12-case matrix was replicated verbatim from the frozen driver source (routes X / XZ / R10, Vc in {[0 0 0], [0 0.15 0]} NED, DVL {lock, outage}), and the replication is proved by the static markers above rather than asserted.
- Nothing was re-tuned, re-scaled, re-seeded or re-modelled. Every number is the frozen ASSUMED value from the library.

## The 16 declared gates, re-evaluated

| # | Declared gate | Result |
|---:|---|:---:|
| 1 | `timing_monotonic` | PASS |
| 2 | `sequence_monotonic` | PASS |
| 3 | `rate_within_one_base_tick` | PASS |
| 4 | `frame_sign_identities` | PASS |
| 5 | `no_truth_leakage` | PASS |
| 6 | `dropout_stale_quality` | PASS |
| 7 | `finite_bounded` | PASS |
| 8 | `estimated_invalid` | PASS |
| 9 | `deterministic_replay` | PASS |
| 10 | `reset_order_sentinel` | PASS |
| 11 | `usbl_optional_absent` | PASS |
| 12 | `all_numerics_assumed` | PASS |
| 13 | `sources_exactly_three` | PASS |
| 14 | `frozen_artifacts_unchanged` | PASS |
| 15 | `visual_qa` | PASS |
| 16 | `case_matrix_complete` | PASS |

**Declared gates: 16/16 PASS. Cases: 12/12 PASS.**

## Validation and process gates

| Validation gate | Result |
|---|:---:|
| `single_matlab_process` | PASS |
| `prior_noncompliance_recorded` | PASS |
| `declared_gates_16_of_16` | PASS |
| `cases_12_of_12` | PASS |
| `static_review_markers` | PASS |
| `config_numerics_identical` | PASS |
| `declared_rate_asserts` | PASS |
| `case_order_identical` | PASS |
| `channel_schema_identical` | PASS |
| `event_and_rate_counts_identical` | PASS |
| `replay_checksum_determinism` | PASS |
| `outage_transitions_identical` | PASS |
| `frame_sign_residual_parity` | PASS |
| `core_error_metric_parity` | PASS |
| `showcase_series_parity` | PASS |
| `estimated_invalid_usbl_absent` | PASS |
| `no_truth_leakage_validated` | PASS |
| `prior_artifacts_preserved` | PASS |
| `codex_vertical_plan_untouched` | PASS |
| `production_fingerprints_exact` | PASS |
| `png_readable` | PASS |
| `artifacts_under_300MiB` | PASS |

**Validation gates: 22/22 PASS.**

## Case matrix re-run (frozen, 12 cases, prior order preserved)

| # | Case | Route | Vc [m/s NED] | DVL | N ticks | seed | peak crab [deg] | DVL avail [%] | pack checksum | Result |
|---:|---|---|---|---|---:|---:|---:|---:|---|:---:|
| 1 | `X_Vc0_lock` | X | [0.00 0.00 0.00] | lock | 3601 | 1736306363 | 0.00 | 99.4 | `8299B036` | PASS |
| 2 | `X_Vc0_outage` | X | [0.00 0.00 0.00] | outage | 3601 | 1719528744 | 0.00 | 78.9 | `1BABAC95` | PASS |
| 3 | `X_Vc_E015_lock` | X | [0.00 0.15 0.00] | lock | 3601 | 70806246 | 5.71 | 99.4 | `0972B238` | PASS |
| 4 | `X_Vc_E015_outage` | X | [0.00 0.15 0.00] | outage | 3601 | 54028627 | 5.71 | 78.9 | `8FD6B2D7` | PASS |
| 5 | `XZ_Vc0_lock` | XZ | [0.00 0.00 0.00] | lock | 4401 | 637068955 | 0.00 | 99.5 | `4008B3C2` | PASS |
| 6 | `XZ_Vc0_outage` | XZ | [0.00 0.00 0.00] | outage | 4401 | 620291336 | 0.00 | 78.2 | `6172B367` | PASS |
| 7 | `XZ_Vc_E015_lock` | XZ | [0.00 0.15 0.00] | lock | 4401 | 2100020421 | 6.15 | 99.5 | `466DB600` | PASS |
| 8 | `XZ_Vc_E015_outage` | XZ | [0.00 0.15 0.00] | outage | 4401 | 2083242802 | 6.15 | 78.2 | `1690B845` | PASS |
| 9 | `R10_Vc0_lock` | R10 | [0.00 0.00 0.00] | lock | 9001 | 1001993762 | 0.00 | 99.8 | `1937B0D8` | PASS |
| 10 | `R10_Vc0_outage` | R10 | [0.00 0.00 0.00] | outage | 9001 | 1018771381 | 0.00 | 78.2 | `1E6BB181` | PASS |
| 11 | `R10_Vc_E015_lock` | R10 | [0.00 0.15 0.00] | lock | 9001 | 746023432 | 5.74 | 99.8 | `9F2BB092` | PASS |
| 12 | `R10_Vc_E015_outage` | R10 | [0.00 0.15 0.00] | outage | 9001 | 762801051 | 5.74 | 78.2 | `DBC9B2DC` | PASS |

Case order, labels, routes, Vc values, outage flags, seeds and tick counts are identical to the prior artifact (see the `case_order` parity category).

## Deterministic parity against the prior MAT

Declared numerical tolerance: relative deviation <= 1e-12 for every floating-point metric (scaled by max(1,|prior|)), and EXACT equality for every count, index, seed, flag, name and schema field. The chain is bitwise deterministic, so the expected deviation is exactly zero; the tolerance exists only to absorb MAT round-trip representation, never model drift.

| Parity category | What is compared | Max relative deviation | Exact fields identical | Result |
|---|---|---:|:---:|:---:|
| `case_order` | case order, labels, routes, Vc, outage flag, seed, N, T_final, per-case gate struct | 0 | YES | PASS |
| `channel_schema` | channel name order, frame, units, presence, per-channel field set, declared rate, delay, sample time | 0 | YES | PASS |
| `event_rate_counts` | scheduled and emitted event counts, achieved rate, max period error, sequence totals, per-channel gate flags | 0 | YES | PASS |
| `outage_transitions` | DVL valid / stale / dropout / init tick counts, outage window, STALE-before-DROPOUT ordering, quality-zero, quality ramp, recovery, USBL absence | 0 | YES | PASS |
| `frame_sign` | nu_r identity residual, R-transpose residual, depth bias, DVL water-vs-ground RMS, INS ground-vs-water RMS, heading-vs-course means, crab, specific-force norm | 0 | YES | PASS |
| `core_error_metrics` | per-channel truth-vs-measured error stats at timestamp and at bus, min absolute error, exact-match count, value bounds, per-case availability | 0 | YES | PASS |
| `showcase_series` | full decimated showcase time series: every truth state plus every measured channel value, timestamp, t_rx, seq, valid, quality, stale age and status | 0 | YES | PASS |

- Whole-struct identity, the strongest available form: `verify` `isequaln` YES, `case_summary` `isequaln` YES, `showcase` `isequaln` YES.
- Max relative deviation over **all** categories: 0 against a declared tolerance of 1e-12.
- Within this run: reverse-order replay bitwise identical 12/12 (checksum identical 12/12), reset sentinel first YES / last YES.

### Replay checksums (Adler-32 over the full MEASURED pack, per case)

| Case | value | timestamp | seq | valid | quality | stale_age | status | combined |
|---|---|---|---|---|---|---|---|---|
| `X_Vc0_lock` | `3BEB13F8` | `58FF1627` | `DF0E119F` | `27EE13CE` | `00781263` | `BF9F11D4` | `62A114A1` | `8299B036` |
| `X_Vc0_outage` | `D4491079` | `803A172D` | `E1DD11A6` | `FAB81290` | `163112F9` | `D5C81267` | `32831351` | `1BABAC95` |
| `X_Vc_E015_lock` | `669014B3` | `58FF1627` | `DF0E119F` | `27EE13CE` | `00781263` | `BF9F11D4` | `62A114A1` | `0972B238` |
| `X_Vc_E015_outage` | `581D1496` | `803A172D` | `E1DD11A6` | `FAB81290` | `163112F9` | `D5C81267` | `32831351` | `8FD6B2D7` |
| `XZ_Vc0_lock` | `529B14C2` | `380C13B7` | `04FE1164` | `5AAD1397` | `42781388` | `F85F132B` | `8CF21528` | `4008B3C2` |
| `XZ_Vc0_outage` | `15151317` | `4899142F` | `F2DE10DE` | `638B13D3` | `654B1483` | `EDDF12DF` | `9F6915B0` | `6172B367` |
| `XZ_Vc_E015_lock` | `6101153F` | `380C13B7` | `04FE1164` | `5AAD1397` | `42781388` | `F85F132B` | `8CF21528` | `466DB600` |
| `XZ_Vc_E015_outage` | `43F314D0` | `4899142F` | `F2DE10DE` | `638B13D3` | `654B1483` | `EDDF12DF` | `9F6915B0` | `1690B845` |
| `R10_Vc0_lock` | `184A14D1` | `191114C7` | `19871164` | `350212AC` | `4EA11326` | `79511569` | `01D711E7` | `1937B0D8` |
| `R10_Vc0_outage` | `8EC1178A` | `D25D12D1` | `239811A6` | `350D12AA` | `35DD1272` | `648914E3` | `01C411E2` | `1E6BB181` |
| `R10_Vc_E015_lock` | `2AC412F2` | `191114C7` | `19871164` | `350212AC` | `4EA11326` | `79511569` | `01D711E7` | `9F2BB092` |
| `R10_Vc_E015_outage` | `80E8164D` | `D25D12D1` | `239811A6` | `350D12AA` | `35DD1272` | `648914E3` | `01C411E2` | `DBC9B2DC` |

The prior task published no checksums, so cross-run parity had to be established through derived metrics and the decimated series. These checksums are published so any future re-run can be compared bit-for-bit without re-deriving a single metric.

## Outage / availability transitions (parity detail)

| Case | STALE ticks (prior / now) | DROPOUT ticks (prior / now) | Identical |
|---|---|---|:---:|
| `X_Vc0_lock` | 0 / 0 | 0 / 0 | YES |
| `X_Vc0_outage` | 140 / 140 | 599 / 599 | YES |
| `X_Vc_E015_lock` | 0 / 0 | 0 / 0 | YES |
| `X_Vc_E015_outage` | 140 / 140 | 599 / 599 | YES |
| `XZ_Vc0_lock` | 0 / 0 | 0 / 0 | YES |
| `XZ_Vc0_outage` | 140 / 140 | 799 / 799 | YES |
| `XZ_Vc_E015_lock` | 0 / 0 | 0 / 0 | YES |
| `XZ_Vc_E015_outage` | 140 / 140 | 799 / 799 | YES |
| `R10_Vc0_lock` | 0 / 0 | 0 / 0 | YES |
| `R10_Vc0_outage` | 140 / 140 | 1799 / 1799 | YES |
| `R10_Vc_E015_lock` | 0 / 0 | 0 / 0 | YES |
| `R10_Vc_E015_outage` | 140 / 140 | 1799 / 1799 | YES |

Bottom-lock cases show zero degradation; declared-outage cases reproduce the full `INIT_WAIT -> OK -> STALE -> DROPOUT -> OK` sequence with quality collapse, monotonic stale growth and a ramped reacquire, identically to the prior run.

## Honesty invariants (why this evidence is usable)

| Invariant | Evidence | Result |
|---|---|:---:|
| ESTIMATED bus INVALID / UNAVAILABLE | every declared field NaN, `valid` false, `quality` 0, status `UNAVAILABLE`, in all 12 cases | YES |
| No estimator was written | Gate 5A implements no EKF / UKF / complementary filter; fabricating one would be an unjustified navigation claim | YES |
| USBL absent | the optional channel never emits: value NaN, status UNAVAILABLE, never valid, in all 12 cases | YES |
| No truth leakage | exact truth matches across all channels and cases = 0; minimum absolute error = 9.76e-09 > 0 | YES |
| All sensor numerics ASSUMED | every channel carries provenance `ASSUMED`; nothing is IDENTIFIED, fitted or bench-derived | YES |
| No navigation-performance claim | channel availability is not observability, and TRUTH is a prescribed kinematic scenario, not a plant or closed-loop run | YES |
| Gate 4 waiver | remains **OPEN / shadow-only**; nothing in this task promotes it | YES |
| Production never called | plant, controller and guidance frozen and never invoked | YES |

## Isolation and fingerprints

| Frozen artifact | Bytes | Unchanged within this run | Identical to the prior run record |
|---|---:|:---:|:---:|
| `controller_law.m` | 9402 | YES | YES |
| `guidance_law.m` | 14601 | YES | YES |
| `continuous_path_tracking.m` | 10845 | YES | YES |
| `underwater777_vehicle_dynamics.m` | 6065 | YES | YES |
| `init_parameters.m` | 4205 | YES | YES |
| `underwater777_vehicle_dynamics_current.m` | 7814 | YES | YES |
| `suite_results\CODEX_VERTICAL_PLAN.md` | 43101 | YES | YES |

- `CODEX_VERTICAL_PLAN.md` is **untouched**: unchanged within this run and byte-and-timestamp identical to the fingerprint recorded by the prior run (YES).
- Production source fingerprints identical to the prior run record: YES.

| Prior artifact | Bytes before | Bytes after | Preserved |
|---|---:|---:|:---:|
| `suite_results\NAV_MULTIRATE_SENSOR_CHAIN.md` | 19275 | 19275 | YES |
| `suite_results\NAV_MULTIRATE_SENSOR_CHAIN.mat` | 327189 | 327189 | YES |
| `suite_results\NAV_MULTIRATE_SENSOR_CHAIN.png` | 266183 | 266183 | YES |

## Visual QA: final PNG readability validated by decoding it

- `NAV_MULTIRATE_SENSOR_CHAIN_VALIDATION.png`: 9 panels, 299 kB, 2407 x 1629 px, ink fraction 0.261, gray std 70.0.
- Decoded after writing with `imread`: YES. Readability thresholds (width>=1400, height>=900, 0.01<ink<0.95, gray std>5, bytes>80000): YES.
- Readability is *validated*, not assumed: the file is re-read from disk, converted to gray, and rejected if it is blank, saturated, contrast-free or undersized.
- declared 16-gate bar panel legible with one labelled bar per gate
- validation / process gate bar panel legible, pending gates drawn grey
- per-case x per-gate raster green across all 12 cases
- showcase DVL trace: prior thick grey trace hidden exactly under this run's red dashed trace
- status raster shows INIT_WAIT -> OK -> STALE -> DROPOUT -> OK on the DVL row
- error-metric parity scatter lies on y = x
- parity deviation bars sit at the zero floor, left of the 1e-12 tolerance line
- declared vs achieved rate bars agree; USBL bar at zero (absent)
- process / honesty / isolation text panel readable at full resolution
- Two gates were still PENDING when the figure was rendered (`visual_qa` / `png_readable`, and `artifacts_under_300MiB`), because each is measured on files that do not exist until after the render. They are drawn grey in the figure and reported as final in this document and in the MAT, rather than pre-judged.

## Artifact size budget

| Artifact | Bytes |
|---|---:|
| `NAV_MULTIRATE_SENSOR_CHAIN_VALIDATION.md` | 15976 |
| `NAV_MULTIRATE_SENSOR_CHAIN_VALIDATION.mat` | 329686 |
| `NAV_MULTIRATE_SENSOR_CHAIN_VALIDATION.png` | 306032 |
| **total** | **651694 (0.62 MiB)** |

- Budget: **< 300 MiB**. Result: PASS.
- Byte counts measured after the first write of the MD and MAT. The final MD/MAT differ only by the few hundred bytes needed to record this measurement, which is immaterial against a 300 MiB budget. Final measured sizes are stored in artifact_bytes_final.
- The MAT stores parity tables, gate records, per-case verification structs, checksums and a 20 Hz decimated showcase only. No full-rate multi-case series is archived, which is what keeps the artifact three orders of magnitude under budget.

## Gate decision

- **Gate 5A: PASS_FORMALIZED**
- Basis: 12/12 frozen cases, 16/16 declared gates, deterministic parity with the prior artifact, zero truth leakage, exact frozen fingerprints, one MATLAB process, artifacts far under 300 MiB.
- Next: Gate5B: multirate EKF + availability manager on this frozen bus contract
- Gate 4 waiver remains OPEN / shadow-only; not promoted by this task
- Claim limit: Sensor-chain contract only. No navigation-performance claim.

### Gate 5B scope (next)

- `multirate_ekf_and_availability_manager`: a multirate measurement update per channel at its own arrival time, delay compensation taken from the `timestamp` field, and an availability manager driven by `valid` / `quality` / `stale_age` (DVL bottom-lock loss, USBL admission if a USBL is ever present).
- Only then may an ESTIMATED bus become VALID, and only under a separately gated navigation-accuracy claim.
- Sensor numerics must move from ASSUMED to bench or sea-trial identified before any such claim. Until then an EKF built on this bus can be verified for consistency but not for accuracy.

## Limitations (unchanged from the prior artifact)

- Every sensor number is ASSUMED. Error magnitudes are illustrative only.
- TRUTH is a prescribed kinematic scenario, not a plant or closed-loop run. No tracking, stability, robustness or navigation-accuracy conclusion follows.
- There is no estimator. Channel availability is not observability, and the ESTIMATED bus is INVALID by design.
- Gate 4 remains FAIL / shadow-only under an open waiver; nothing here promotes it. CUSUM / SIL remain simulation-only.
- This validation establishes *process* validity and *reproducibility* of the prior technical result. It adds no new physical evidence and no new model.

## MATHEMATICAL_RECORD

```
MATHEMATICAL_RECORD = {
  equations: {
    (unchanged from NAV_MULTIRATE_SENSOR_CHAIN_001; re-executed, not re-derived)
    nu_c = R(phi,theta,psi)' * Vc,   nu_r = nu - nu_c,
    eta_dot = R * nu,   f_b = R' * (a_ned - g_ned),
    y_i(t_k) = h_i(x(t_k)) * (1+s_i) + b_i + sigma_i * n_i,  n_i ~ N(0,1),
    t_k = k * T_i,  arrival = t_k + tau_i,  bus = ZOH(latest arrival),
    stale_age(t) = t - timestamp(last VALID sample)
  },
  validation_criteria: {
    process: exactly ONE MATLAB invocation for the whole task,
    coverage: 12/12 frozen cases, 16/16 declared gates,
    parity: max relative deviation 0 <= tol 1e-12 over 7 categories,
    determinism: reverse-order replay + first/last reset sentinels bitwise identical,
    honesty: ESTIMATED INVALID, USBL absent, zero truth matches, all numerics ASSUMED,
    isolation: frozen fingerprints exact, CODEX_VERTICAL_PLAN untouched, prior artifacts preserved,
    budget: artifacts < 300 MiB
  },
  parameter_provenance: {
    ASSUMED: every sensor numeric, seabed, outage window, base tick,
    REUSED_DECLARED: U=1.5, dt_controller/dt_guidance/tau_rate, channel set,
    IDENTIFIED: none,  TUNED: none (this task changed no number)
  },
  design_reason: 'A gate cannot be formalized from a process-noncompliant run; reproduce the identical evidence in one process and prove bitwise parity.',
  rejected_alternatives: {
    accept_prior_TECHNICAL_PASS: rejected (four MATLAB starts, process-invalid),
    re-run_run_nav_multirate_sensor_chain: rejected (would overwrite the artifact under validation),
    re-read_upstream_sources: rejected (would exceed the three-source limit; prior record used instead),
    probe_MATLAB_before_writing: rejected (would consume the single permitted invocation),
    implement_EKF_now: rejected (would fabricate a navigation claim on ASSUMED numerics)
  },
  evidence: { suite_results/NAV_MULTIRATE_SENSOR_CHAIN_VALIDATION.{md,mat,png} },
  conclusion: 'PASS: identical contract evidence reproduced in one MATLAB process with bitwise parity; Gate 5A formalized; no navigation claim',
  open_questions: { sensor numerics remain ASSUMED; observability under DVL outage untested until Gate 5B }
}
```

## Artifacts

- `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\NAV_MULTIRATE_SENSOR_CHAIN_VALIDATION.md`
- `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\NAV_MULTIRATE_SENSOR_CHAIN_VALIDATION.mat`
- `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\NAV_MULTIRATE_SENSOR_CHAIN_VALIDATION.png`

Preserved prior artifacts, not modified: `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\NAV_MULTIRATE_SENSOR_CHAIN.md`, `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\NAV_MULTIRATE_SENSOR_CHAIN.mat`, `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\NAV_MULTIRATE_SENSOR_CHAIN.png`.

Elapsed 25.7 s in a single MATLAB process.
