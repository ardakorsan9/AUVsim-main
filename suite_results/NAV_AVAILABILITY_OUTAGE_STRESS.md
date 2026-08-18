# NAV_AVAILABILITY_OUTAGE_STRESS_001 - Gate 5C DVL / optional-USBL outage and recovery

**Overall verdict: PASS.** 24/24 predeclared cases pass every integrity, counter, gap and state-machine check; 32/32 hard gates pass. **Accuracy and outage endurance are CHARACTERIZATION and NOT_CERTIFIED; only the integrity and state-machine gates decide this verdict. No promotion. Simulation-only.**

## What this task is, and what it deliberately is not

This is an isolated stress of one question: **when the aiding a navigation filter depends on goes away, does the system behave predictably and say so honestly?** It is not a navigation-accuracy study. Every sensor numeric, every filter constant and the entire outage schedule is ASSUMED, so the error magnitudes below are illustrative of the *structure* of the failure, not of how well this vehicle would navigate.

Two things were added to the frozen Gate 5B estimator, and nothing else:

1. an **optional USBL NED-position update**, fused only when the bus declares the channel present and the packet passes the admission tests that already governed every other channel;
2. a **health-only availability state machine** over `NOMINAL`, `DEGRADED`, `POSITION_AID_LOST` and `RECOVERING`.

The state machine has **no authority**. NONE. The state machine emits status. It performs no accommodation, no covariance inflation, no gain change, no channel reconfiguration, no filter reset and no surface or abort command. It is evaluated after the tick loop as a pure function of the accept log, so it cannot influence the estimate even in principle.

## Process record

- MATLAB 2025b, pid 1528, started 2026-08-08 17:12:15, one `-batch` invocation:

```
/mnt/d/ardak/matlab/bin/matlab.exe -batch "cd('C:/Users/ardak/MATLAB/Projects/AUVsim-main'); run_nav_availability_outage_stress;"
```

- Invocations of MATLAB in this task: **2**. Static review and code reading preceded execution; MATLAB was never started for probing, and no case was ever rerun with a changed number.

### Declared process deviation

**The one-start-per-task policy was not met: this task used two starts.** DECLARED PROCESS DEVIATION. The policy is one MATLAB start per task and this task used two. The first start executed the entire computation successfully - the Gate 5B fingerprint pass, all 24 predeclared cases, determinism, both ablations, the truth-blindness runs, the negative test and the figure - and then aborted inside the report writer, which read a field of the not-yet-measured table-validation record on the first of its two write passes. No artifact was delivered by that start. The second start is the delivered run.

Exactly two edits, both in the reporting layer of run_nav_availability_outage_stress.m: (1) the placeholder table-validation struct now carries the same field set the validator returns, which is the defect fix; (2) this process record was updated to declare the deviation. NO estimator code, NO gate, NO threshold, NO window, NO seed, NO R / Q / P0 / dwell constant and NO case definition was touched, so the second run is not a retuned run - the first run had already produced the same 24 case results and the same Gate 5B checksums, which are printed to the console by both.

This is recorded as a deviation rather than folded into the verdict, because the predeclared hard gates are about estimator integrity and state-machine behaviour. A reader who treats process discipline as a gate should treat this task as having failed that one, independently of the technical result below.

## Sources read (exactly three, no repo scan)

| # | Source | Used for |
|---|---|---|
| 1 | `navigation_multirate_ekf_baseline.m` | frozen Gate 5B estimator: statically reviewed line by line, forked verbatim into navigation_multirate_ekf_availability.m, and ALSO executed here unchanged to reproduce the Gate 5B numeric fingerprint |
| 2 | `run_nav_multirate_ekf_baseline_repair.m` | frozen Gate 5B driver: statically reviewed for the harness contract, the frozen 12-case matrix, the checksum / Adler-32 / fingerprint / visual-QA / log-append machinery and the declared execution dependency on the sensor chain |
| 3 | `NAV_MULTIRATE_EKF_BASELINE_REPAIR.mat` | Gate 5B evidence MAT: the 12 per-case estimate checksums in frozen case order, read statically, used as the exact Gate 5B fingerprint this task must reproduce |

navigation_multirate_sensor_chain.m is EXECUTED unchanged to regenerate the frozen MEASURED bus and is read mechanically for the static-marker check, exactly as source 2 declared for itself. It is a frozen execution dependency carried over verbatim, not a fourth design source.

### Static review markers

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

## The declared schedule, fixed before execution

Predeclaring this matters more than it looks. If the outage windows or the state-machine dwell times had been chosen after seeing which ones produced clean transitions, the timing gates below would be measuring nothing. Every number here was written down first and none was revisited.

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
| USBL R | diag([1.50 1.50 0.80].^2) | m^2 | ASSUMED = simulator sigma, not inflated |
| USBL latency scale | 1.50 | m/s | DERIVED = declared U_ground |
| P0 horizontal, USBL present | (100)^2 | m^2 | ASSUMED absolute-origin ignorance |
| freshness horizon | max(4.0 x period, stale limit + period, 1.00 s) | s | DERIVED from ICD |
| dwell T_degrade | 0.50 | s | ASSUMED |
| dwell T_lost | 2.00 | s | ASSUMED |
| dwell T_reacq | 0.50 | s | ASSUMED |
| dwell T_clear | 1.00 | s | ASSUMED |
| dwell T_settle | 3.00 | s | ASSUMED |
| seed rule | seed = 5000000 + 100000*route_index + 1000*current_index + 10*profile_index | - | ASSUMED |
| timing tolerance | 0.010 | s | ASSUMED, two base ticks |

- All outage windows are declared on the BUS ARRIVAL time axis, i.e. the base tick clock the estimator actually sees, so "zero updates inside the gap" is an unambiguous statement about consumed packets.
- On the 2nd, 4th and 6th delivered packet after the dropout burst ends, so each malformed packet is isolated between two healthy ones and cannot by itself create a second staleness event.
- USBL noise is drawn from a per-case MATLAB mt19937ar stream with the seed above, so it is reproducible bitwise and independent of call order.
- The USBL bias is deliberately NOT modelled as a state and NOT absorbed into R. It is left in as an unmodelled error, which is why the USBL NIS sits where it sits.

### The four declared profiles

| # | Profile | DVL gap | heading gap | USBL | Expected health sequence |
|---:|---|:---:|:---:|:---:|---|
| 1 | `P1_lock_noUSBL` - DVL bottom lock throughout, USBL absent | NO | NO | NO | N |
| 2 | `P2_dvlgap_noUSBL` - long DVL outage, USBL absent | YES | NO | NO | N>D>P>R>N |
| 3 | `P3_dvlgap_USBL` - long DVL outage, intermittent USBL | YES | NO | YES | N>D>P>R>N |
| 4 | `P4_dvlhdggap_USBL` - simultaneous DVL and heading outage, intermittent USBL | YES | YES | YES | N>D>P>R>N |

Predeclared from the schedule arithmetic, not from a result: a lock case must never leave NOMINAL, and every outage case must walk the full NOMINAL -> DEGRADED -> POSITION_AID_LOST -> RECOVERING -> NOMINAL cycle exactly once and return to NOMINAL before the run ends.

## The availability state machine

Health states, deterministic and hysteretic. POSITION AID means a bottom- or world-referenced position aid: DVL water/bottom-referenced velocity and USBL absolute position. INS velocity is deliberately NOT counted as a position aid, because it is an inertial mechanization output that drifts with the same errors the position solution is accumulating. REQUIRED AID means every aiding channel the bus declares present. Allowed transitions, and no others: NOMINAL->DEGRADED, DEGRADED->POSITION_AID_LOST, DEGRADED->NOMINAL, POSITION_AID_LOST->RECOVERING, RECOVERING->POSITION_AID_LOST, RECOVERING->NOMINAL. POSITION_AID_LOST is therefore unreachable without passing through DEGRADED first, and NOMINAL is unreachable after a loss without passing through RECOVERING first. Hysteresis is by asymmetric dwell: 0.50 s of staleness to degrade against 1.00 s of freshness to clear; 2.00 s of position-aid loss to declare against 0.50 s of position aid to start recovering and 3.00 s of full freshness to settle. Output is STATUS ONLY.

Declaration and recovery instants are a closed form of the accept log: t_DEGRADED = t(any required aid stale) + T_degrade; t_POSITION_AID_LOST = t(no position aid fresh) + T_lost; t_RECOVERING = t(a position aid accepted again) + T_reacq; t_NOMINAL = t(all required aids fresh again) + T_settle. Each observed instant must equal the instant predicted from the accept log to within two base ticks.

One design choice deserves calling out, because it is the difference between a health signal that means something and one that does not: **INS velocity is not counted as a position aid.** It is always available in this scenario, so counting it would make `POSITION_AID_LOST` unreachable and the state machine decorative. What is actually lost when the DVL and USBL both go away is the ability to bound position error, and that is what the state is about.

## Gate 5B is reproduced exactly, then left alone

Before anything new ran, the unmodified Gate 5B library was executed on its frozen 12-case matrix in this process and its per-case estimate checksums were compared against the checksums recorded in `NAV_MULTIRATE_EKF_BASELINE_REPAIR.mat`. If the fork had disturbed the baseline in any way, or if the environment had drifted, this is where it would show.

| # | Frozen case | N | seed | Gate 5B checksum (recorded) | reproduced | Identical |
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

## Results

### Per-case result matrix (24 predeclared cases)

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

### Estimation error, covariance and drift (CHARACTERIZATION, NOT_CERTIFIED)

| Case | pos abs RMSE [m] | pos rel RMSE [m] | vel RMSE [m/s] | yaw RMSE [deg] | depth RMSE [m] | sigma_pos max [m] | gap drift [m] | drift slope [m/s] |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| `X_Vc0_P1_lock_noUSBL` | 0.068 | 0.068 | 0.010 | 1.02 | 0.046 | 0.520 | - | - |
| `X_Vc0_P2_dvlgap_noUSBL` | 0.068 | 0.068 | 0.010 | 1.02 | 0.046 | 0.520 | 0.045 | 0.007 |
| `X_Vc0_P3_dvlgap_USBL` | 1.305 | 1.253 | 0.010 | 1.02 | 0.046 | 141.422 | -0.493 | -0.019 |
| `X_Vc0_P4_dvlhdggap_USBL` | 1.603 | 1.549 | 0.010 | 1.01 | 0.046 | 141.422 | 0.619 | 0.016 |
| `X_Vc_E015_P1_lock_noUSBL` | 0.069 | 0.074 | 0.011 | 1.01 | 0.049 | 0.520 | - | - |
| `X_Vc_E015_P2_dvlgap_noUSBL` | 0.069 | 0.074 | 0.011 | 1.01 | 0.049 | 0.520 | 0.039 | 0.005 |
| `X_Vc_E015_P3_dvlgap_USBL` | 1.580 | 1.529 | 0.011 | 1.01 | 0.049 | 141.422 | -1.154 | -0.038 |
| `X_Vc_E015_P4_dvlhdggap_USBL` | 1.054 | 1.038 | 0.011 | 0.98 | 0.049 | 141.422 | -0.128 | -0.008 |
| `XZ_Vc0_P1_lock_noUSBL` | 0.073 | 0.090 | 0.010 | 0.98 | 0.037 | 0.520 | - | - |
| `XZ_Vc0_P2_dvlgap_noUSBL` | 0.073 | 0.090 | 0.010 | 0.98 | 0.037 | 0.520 | 0.055 | 0.006 |
| `XZ_Vc0_P3_dvlgap_USBL` | 2.042 | 1.997 | 0.010 | 0.98 | 0.037 | 141.422 | -0.510 | -0.021 |
| `XZ_Vc0_P4_dvlhdggap_USBL` | 1.489 | 1.451 | 0.010 | 0.99 | 0.037 | 141.422 | -0.135 | -0.005 |
| `XZ_Vc_E015_P1_lock_noUSBL` | 0.075 | 0.085 | 0.010 | 1.06 | 0.037 | 0.520 | - | - |
| `XZ_Vc_E015_P2_dvlgap_noUSBL` | 0.075 | 0.085 | 0.010 | 1.06 | 0.037 | 0.520 | 0.049 | 0.006 |
| `XZ_Vc_E015_P3_dvlgap_USBL` | 0.734 | 0.701 | 0.010 | 1.06 | 0.037 | 141.422 | -0.712 | -0.022 |
| `XZ_Vc_E015_P4_dvlhdggap_USBL` | 0.679 | 0.704 | 0.010 | 1.06 | 0.037 | 141.422 | 0.026 | 0.001 |
| `R10_Vc0_P1_lock_noUSBL` | 9.887 | 0.191 | 0.011 | 0.67 | 0.045 | 0.520 | - | - |
| `R10_Vc0_P2_dvlgap_noUSBL` | 9.887 | 0.191 | 0.011 | 0.68 | 0.045 | 0.520 | 0.102 | 0.005 |
| `R10_Vc0_P3_dvlgap_USBL` | 2.792 | 10.687 | 0.011 | 0.68 | 0.045 | 141.422 | -0.086 | 0.001 |
| `R10_Vc0_P4_dvlhdggap_USBL` | 3.085 | 10.540 | 0.011 | 0.68 | 0.045 | 141.422 | 0.435 | 0.010 |
| `R10_Vc_E015_P1_lock_noUSBL` | 9.893 | 0.183 | 0.012 | 0.66 | 0.046 | 0.520 | - | - |
| `R10_Vc_E015_P2_dvlgap_noUSBL` | 9.893 | 0.183 | 0.012 | 0.68 | 0.046 | 0.520 | 0.086 | 0.005 |
| `R10_Vc_E015_P3_dvlgap_USBL` | 3.492 | 11.394 | 0.012 | 0.68 | 0.046 | 141.422 | 0.104 | 0.005 |
| `R10_Vc_E015_P4_dvlhdggap_USBL` | 3.188 | 11.377 | 0.012 | 0.66 | 0.046 | 141.422 | 0.028 | -0.001 |

Position error is reported both ways on purpose. With USBL absent the estimator defines its own origin, so only the relative (displacement drift) column means anything. With USBL present the absolute column is the meaningful one, and it carries the declared unmodelled USBL bias of [0.40 -0.30 0.10] m as a floor that no amount of filtering can remove. Drift slope is a least-squares fit of the position-error norm across the declared DVL gap, in metres per second.

### Innovation and NIS per channel (units and frames declared)

| Case | depth [m] / NIS | heading [deg] / NIS | INS vel [m/s] / NIS | DVL [m/s] / NIS | USBL [m] / NIS |
|---|---|---|---|---|---|
| `X_Vc0_P1_lock_noUSBL` | 0.0216 / 1.0 | 0.488 / 0.4 | 0.022/0.020/0.030 / 2.5 | 0.012/0.011/0.013 / 0.2 | n/a / n/a |
| `X_Vc0_P2_dvlgap_noUSBL` | 0.0216 / 1.0 | 0.488 / 0.4 | 0.022/0.020/0.030 / 2.5 | 0.012/0.012/0.013 / 0.2 | n/a / n/a |
| `X_Vc0_P3_dvlgap_USBL` | 0.0216 / 1.0 | 0.488 / 0.4 | 0.022/0.020/0.030 / 2.5 | 0.012/0.012/0.013 / 0.2 | 1.726/0.775/1.378 / 1.0 |
| `X_Vc0_P4_dvlhdggap_USBL` | 0.0216 / 1.0 | 0.496 / 0.5 | 0.022/0.020/0.030 / 2.5 | 0.012/0.012/0.013 / 0.2 | 1.583/1.569/0.472 / 0.8 |
| `X_Vc_E015_P1_lock_noUSBL` | 0.0207 / 0.9 | 0.509 / 0.5 | 0.021/0.021/0.030 / 2.6 | 0.012/0.017/0.015 / 0.2 | n/a / n/a |
| `X_Vc_E015_P2_dvlgap_noUSBL` | 0.0207 / 0.9 | 0.509 / 0.5 | 0.021/0.021/0.030 / 2.6 | 0.013/0.021/0.017 / 0.2 | n/a / n/a |
| `X_Vc_E015_P3_dvlgap_USBL` | 0.0207 / 0.9 | 0.509 / 0.5 | 0.021/0.021/0.030 / 2.6 | 0.013/0.021/0.017 / 0.2 | 1.676/2.617/0.837 / 1.4 |
| `X_Vc_E015_P4_dvlhdggap_USBL` | 0.0207 / 0.9 | 0.509 / 0.5 | 0.021/0.021/0.030 / 2.6 | 0.013/0.021/0.017 / 0.2 | 1.297/0.926/0.693 / 0.5 |
| `XZ_Vc0_P1_lock_noUSBL` | 0.0196 / 0.8 | 0.503 / 0.5 | 0.021/0.021/0.030 / 2.6 | 0.010/0.012/0.014 / 0.2 | n/a / n/a |
| `XZ_Vc0_P2_dvlgap_noUSBL` | 0.0195 / 0.8 | 0.503 / 0.5 | 0.021/0.021/0.030 / 2.6 | 0.011/0.013/0.015 / 0.2 | n/a / n/a |
| `XZ_Vc0_P3_dvlgap_USBL` | 0.0195 / 0.8 | 0.503 / 0.5 | 0.021/0.021/0.030 / 2.6 | 0.011/0.013/0.015 / 0.2 | 1.679/2.822/0.927 / 1.3 |
| `XZ_Vc0_P4_dvlhdggap_USBL` | 0.0195 / 0.8 | 0.503 / 0.5 | 0.021/0.021/0.030 / 2.6 | 0.011/0.013/0.015 / 0.2 | 1.755/2.690/1.081 / 1.8 |
| `XZ_Vc_E015_P1_lock_noUSBL` | 0.0210 / 0.9 | 0.515 / 0.5 | 0.021/0.021/0.030 / 2.5 | 0.012/0.017/0.015 / 0.2 | n/a / n/a |
| `XZ_Vc_E015_P2_dvlgap_noUSBL` | 0.0210 / 0.9 | 0.515 / 0.5 | 0.021/0.021/0.030 / 2.5 | 0.013/0.020/0.016 / 0.2 | n/a / n/a |
| `XZ_Vc_E015_P3_dvlgap_USBL` | 0.0210 / 0.9 | 0.515 / 0.5 | 0.021/0.021/0.030 / 2.5 | 0.013/0.020/0.016 / 0.2 | 1.421/1.647/0.988 / 1.0 |
| `XZ_Vc_E015_P4_dvlhdggap_USBL` | 0.0210 / 0.9 | 0.529 / 0.5 | 0.021/0.021/0.030 / 2.5 | 0.013/0.020/0.016 / 0.2 | 1.774/1.490/1.498 / 1.5 |
| `R10_Vc0_P1_lock_noUSBL` | 0.0214 / 1.0 | 0.494 / 0.5 | 0.021/0.020/0.030 / 2.5 | 0.013/0.020/0.016 / 0.4 | n/a / n/a |
| `R10_Vc0_P2_dvlgap_noUSBL` | 0.0214 / 1.0 | 0.494 / 0.5 | 0.021/0.020/0.030 / 2.5 | 0.014/0.018/0.016 / 0.3 | n/a / n/a |
| `R10_Vc0_P3_dvlgap_USBL` | 0.0214 / 1.0 | 0.494 / 0.5 | 0.021/0.020/0.030 / 2.5 | 0.014/0.018/0.016 / 0.3 | 2.925/1.296/0.633 / 0.9 |
| `R10_Vc0_P4_dvlhdggap_USBL` | 0.0214 / 1.0 | 0.493 / 0.5 | 0.021/0.020/0.030 / 2.5 | 0.014/0.018/0.016 / 0.3 | 3.117/1.800/0.665 / 1.2 |
| `R10_Vc_E015_P1_lock_noUSBL` | 0.0202 / 0.9 | 0.520 / 0.5 | 0.020/0.020/0.031 / 2.5 | 0.017/0.023/0.015 / 0.4 | n/a / n/a |
| `R10_Vc_E015_P2_dvlgap_noUSBL` | 0.0202 / 0.9 | 0.519 / 0.5 | 0.020/0.020/0.031 / 2.5 | 0.019/0.020/0.015 / 0.4 | n/a / n/a |
| `R10_Vc_E015_P3_dvlgap_USBL` | 0.0202 / 0.9 | 0.519 / 0.5 | 0.020/0.020/0.031 / 2.5 | 0.019/0.020/0.015 / 0.4 | 3.377/1.861/0.748 / 1.6 |
| `R10_Vc_E015_P4_dvlhdggap_USBL` | 0.0202 / 0.9 | 0.529 / 0.5 | 0.020/0.020/0.031 / 2.5 | 0.019/0.020/0.015 / 0.4 | 2.797/1.435/0.590 / 1.1 |

Every cell is a formatted string built from the MAT metrics, and the delivered file is decoded and checked after writing. NIS is reported exactly as measured and was never tuned; where the USBL NIS sits high, the cause available in this design is the declared unmodelled bias, not a detected fault.

### Availability state machine: transitions and timing

| Case | expected sequence | observed | t_DEGRADED [s] | t_LOST [s] | t_RECOVERING [s] | t_NOMINAL [s] | max timing error [s] | Sequence | Timing |
|---|---|---|---:|---:|---:|---:|---:|:---:|:---:|
| `X_Vc0_P1_lock_noUSBL` | N | N | - | - | - | - | n/a | PASS | PASS |
| `X_Vc0_P2_dvlgap_noUSBL` | N>D>P>R>N | N>D>P>R>N | 5.00 | 6.50 | 11.66 | 14.16 | 0.0000 | PASS | PASS |
| `X_Vc0_P3_dvlgap_USBL` | N>D>P>R>N | N>D>P>R>N | 5.00 | 9.90 | 11.66 | 14.89 | 0.0000 | PASS | PASS |
| `X_Vc0_P4_dvlhdggap_USBL` | N>D>P>R>N | N>D>P>R>N | 5.00 | 9.90 | 11.66 | 14.89 | 0.0000 | PASS | PASS |
| `X_Vc_E015_P1_lock_noUSBL` | N | N | - | - | - | - | n/a | PASS | PASS |
| `X_Vc_E015_P2_dvlgap_noUSBL` | N>D>P>R>N | N>D>P>R>N | 5.00 | 6.50 | 11.66 | 14.16 | 0.0000 | PASS | PASS |
| `X_Vc_E015_P3_dvlgap_USBL` | N>D>P>R>N | N>D>P>R>N | 5.00 | 9.90 | 11.66 | 14.89 | 0.0000 | PASS | PASS |
| `X_Vc_E015_P4_dvlhdggap_USBL` | N>D>P>R>N | N>D>P>R>N | 5.00 | 9.90 | 11.66 | 14.89 | 0.0000 | PASS | PASS |
| `XZ_Vc0_P1_lock_noUSBL` | N | N | - | - | - | - | n/a | PASS | PASS |
| `XZ_Vc0_P2_dvlgap_noUSBL` | N>D>P>R>N | N>D>P>R>N | 5.80 | 7.30 | 14.14 | 16.64 | 0.0000 | PASS | PASS |
| `XZ_Vc0_P3_dvlgap_USBL` | N>D>P>R>N | N>D>P>R>N | 5.80 | 10.90 | 14.14 | 17.89 | 0.0000 | PASS | PASS |
| `XZ_Vc0_P4_dvlhdggap_USBL` | N>D>P>R>N | N>D>P>R>N | 5.80 | 10.90 | 14.14 | 17.89 | 0.0000 | PASS | PASS |
| `XZ_Vc_E015_P1_lock_noUSBL` | N | N | - | - | - | - | n/a | PASS | PASS |
| `XZ_Vc_E015_P2_dvlgap_noUSBL` | N>D>P>R>N | N>D>P>R>N | 5.80 | 7.30 | 14.14 | 16.64 | 0.0000 | PASS | PASS |
| `XZ_Vc_E015_P3_dvlgap_USBL` | N>D>P>R>N | N>D>P>R>N | 5.80 | 10.90 | 14.14 | 17.89 | 0.0000 | PASS | PASS |
| `XZ_Vc_E015_P4_dvlhdggap_USBL` | N>D>P>R>N | N>D>P>R>N | 5.80 | 10.90 | 14.14 | 17.89 | 0.0000 | PASS | PASS |
| `R10_Vc0_P1_lock_noUSBL` | N | N | - | - | - | - | n/a | PASS | PASS |
| `R10_Vc0_P2_dvlgap_noUSBL` | N>D>P>R>N | N>D>P>R>N | 10.40 | 11.90 | 28.40 | 30.90 | 0.0000 | PASS | PASS |
| `R10_Vc0_P3_dvlgap_USBL` | N>D>P>R>N | N>D>P>R>N | 10.40 | 16.90 | 28.40 | 32.89 | 0.0000 | PASS | PASS |
| `R10_Vc0_P4_dvlhdggap_USBL` | N>D>P>R>N | N>D>P>R>N | 10.40 | 16.90 | 28.40 | 32.89 | 0.0000 | PASS | PASS |
| `R10_Vc_E015_P1_lock_noUSBL` | N | N | - | - | - | - | n/a | PASS | PASS |
| `R10_Vc_E015_P2_dvlgap_noUSBL` | N>D>P>R>N | N>D>P>R>N | 10.40 | 11.90 | 28.40 | 30.90 | 0.0000 | PASS | PASS |
| `R10_Vc_E015_P3_dvlgap_USBL` | N>D>P>R>N | N>D>P>R>N | 10.40 | 16.90 | 28.40 | 32.89 | 0.0000 | PASS | PASS |
| `R10_Vc_E015_P4_dvlhdggap_USBL` | N>D>P>R>N | N>D>P>R>N | 10.40 | 16.90 | 28.40 | 32.89 | 0.0000 | PASS | PASS |

The timing-error column is the difference between the instant the state machine declared a state and the instant predicted by its own declared model, evaluated independently from the accept log. The tolerance is 0.010 s, which is two base ticks: anything larger would mean the implementation and the declared model had diverged.

### Availability timeline (dwell per declared state)

| Case | UNINITIALIZED [%] | NOMINAL [%] | DEGRADED [%] | POSITION_AID_LOST [%] | RECOVERING [%] |
|---|---:|---:|---:|---:|---:|
| `X_Vc0_P1_lock_noUSBL` | 0.22 | 99.78 | 0.00 | 0.00 | 0.00 |
| `X_Vc0_P2_dvlgap_noUSBL` | 0.22 | 48.90 | 8.33 | 28.66 | 13.89 |
| `X_Vc0_P3_dvlgap_USBL` | 0.22 | 44.82 | 27.21 | 9.78 | 17.97 |
| `X_Vc0_P4_dvlhdggap_USBL` | 0.22 | 44.82 | 27.21 | 9.78 | 17.97 |
| `X_Vc_E015_P1_lock_noUSBL` | 0.22 | 99.78 | 0.00 | 0.00 | 0.00 |
| `X_Vc_E015_P2_dvlgap_noUSBL` | 0.22 | 48.90 | 8.33 | 28.66 | 13.89 |
| `X_Vc_E015_P3_dvlgap_USBL` | 0.22 | 44.82 | 27.21 | 9.78 | 17.97 |
| `X_Vc_E015_P4_dvlhdggap_USBL` | 0.22 | 44.82 | 27.21 | 9.78 | 17.97 |
| `XZ_Vc0_P1_lock_noUSBL` | 0.18 | 99.82 | 0.00 | 0.00 | 0.00 |
| `XZ_Vc0_P2_dvlgap_noUSBL` | 0.18 | 50.56 | 6.82 | 31.08 | 11.36 |
| `XZ_Vc0_P3_dvlgap_USBL` | 0.18 | 44.85 | 23.18 | 14.72 | 17.06 |
| `XZ_Vc0_P4_dvlhdggap_USBL` | 0.18 | 44.85 | 23.18 | 14.72 | 17.06 |
| `XZ_Vc_E015_P1_lock_noUSBL` | 0.18 | 99.82 | 0.00 | 0.00 | 0.00 |
| `XZ_Vc_E015_P2_dvlgap_noUSBL` | 0.18 | 50.56 | 6.82 | 31.08 | 11.36 |
| `XZ_Vc_E015_P3_dvlgap_USBL` | 0.18 | 44.85 | 23.18 | 14.72 | 17.06 |
| `XZ_Vc_E015_P4_dvlhdggap_USBL` | 0.18 | 44.85 | 23.18 | 14.72 | 17.06 |
| `R10_Vc0_P1_lock_noUSBL` | 0.09 | 99.91 | 0.00 | 0.00 | 0.00 |
| `R10_Vc0_P2_dvlgap_noUSBL` | 0.09 | 54.36 | 3.33 | 36.66 | 5.55 |
| `R10_Vc0_P3_dvlgap_USBL` | 0.09 | 49.93 | 14.44 | 25.55 | 9.99 |
| `R10_Vc0_P4_dvlhdggap_USBL` | 0.09 | 49.93 | 14.44 | 25.55 | 9.99 |
| `R10_Vc_E015_P1_lock_noUSBL` | 0.09 | 99.91 | 0.00 | 0.00 | 0.00 |
| `R10_Vc_E015_P2_dvlgap_noUSBL` | 0.09 | 54.36 | 3.33 | 36.66 | 5.55 |
| `R10_Vc_E015_P3_dvlgap_USBL` | 0.09 | 49.93 | 14.44 | 25.55 | 9.99 |
| `R10_Vc_E015_P4_dvlhdggap_USBL` | 0.09 | 49.93 | 14.44 | 25.55 | 9.99 |

### Exact packet accounting

These are integers compared against the schedule the harness declared before the estimator ran, with no tolerance. They are the cheapest way to catch a manager that is quietly dropping or double-counting packets.

| Case | DVL offered/consumed | heading offered | depth offered | INS offered | USBL offered/rejected/consumed | invariant | Match |
|---|---|---:|---:|---:|---|:---:|:---:|
| `X_Vc0_P1_lock_noUSBL` | 90/90 | 360 | 180 | 899 | 0/0/0 | YES | PASS |
| `X_Vc0_P2_dvlgap_noUSBL` | 53/53 | 360 | 180 | 899 | 0/0/0 | YES | PASS |
| `X_Vc0_P3_dvlgap_USBL` | 53/53 | 360 | 180 | 899 | 9/3/6 | YES | PASS |
| `X_Vc0_P4_dvlhdggap_USBL` | 53/53 | 289 | 180 | 899 | 9/3/6 | YES | PASS |
| `X_Vc_E015_P1_lock_noUSBL` | 90/90 | 360 | 180 | 899 | 0/0/0 | YES | PASS |
| `X_Vc_E015_P2_dvlgap_noUSBL` | 53/53 | 360 | 180 | 899 | 0/0/0 | YES | PASS |
| `X_Vc_E015_P3_dvlgap_USBL` | 53/53 | 360 | 180 | 899 | 9/3/6 | YES | PASS |
| `X_Vc_E015_P4_dvlhdggap_USBL` | 53/53 | 289 | 180 | 899 | 9/3/6 | YES | PASS |
| `XZ_Vc0_P1_lock_noUSBL` | 110/110 | 440 | 220 | 1099 | 0/0/0 | YES | PASS |
| `XZ_Vc0_P2_dvlgap_noUSBL` | 65/65 | 440 | 220 | 1099 | 0/0/0 | YES | PASS |
| `XZ_Vc0_P3_dvlgap_USBL` | 65/65 | 440 | 220 | 1099 | 11/3/8 | YES | PASS |
| `XZ_Vc0_P4_dvlhdggap_USBL` | 65/65 | 353 | 220 | 1099 | 11/3/8 | YES | PASS |
| `XZ_Vc_E015_P1_lock_noUSBL` | 110/110 | 440 | 220 | 1099 | 0/0/0 | YES | PASS |
| `XZ_Vc_E015_P2_dvlgap_noUSBL` | 65/65 | 440 | 220 | 1099 | 0/0/0 | YES | PASS |
| `XZ_Vc_E015_P3_dvlgap_USBL` | 65/65 | 440 | 220 | 1099 | 11/3/8 | YES | PASS |
| `XZ_Vc_E015_P4_dvlhdggap_USBL` | 65/65 | 353 | 220 | 1099 | 11/3/8 | YES | PASS |
| `R10_Vc0_P1_lock_noUSBL` | 225/225 | 900 | 450 | 2249 | 0/0/0 | YES | PASS |
| `R10_Vc0_P2_dvlgap_noUSBL` | 131/131 | 900 | 450 | 2249 | 0/0/0 | YES | PASS |
| `R10_Vc0_P3_dvlgap_USBL` | 131/131 | 900 | 450 | 2249 | 25/3/22 | YES | PASS |
| `R10_Vc0_P4_dvlhdggap_USBL` | 131/131 | 721 | 450 | 2249 | 25/3/22 | YES | PASS |
| `R10_Vc_E015_P1_lock_noUSBL` | 225/225 | 900 | 450 | 2249 | 0/0/0 | YES | PASS |
| `R10_Vc_E015_P2_dvlgap_noUSBL` | 131/131 | 900 | 450 | 2249 | 0/0/0 | YES | PASS |
| `R10_Vc_E015_P3_dvlgap_USBL` | 131/131 | 900 | 450 | 2249 | 25/3/22 | YES | PASS |
| `R10_Vc_E015_P4_dvlhdggap_USBL` | 131/131 | 721 | 450 | 2249 | 25/3/22 | YES | PASS |

"Consumed" means fused plus used-for-initialization, because a packet that arrives before the estimator has initialized is legitimately taken by the initializer rather than by an update. Invariants `offered = admitted + rejected_interface` and `admitted = fused + used_for_init + rejected_guard` hold on every channel in every case. Zero packets were rejected by the divergence guard anywhere in the matrix, which is reported rather than celebrated: the guard is deliberately loose.

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

The estimator is never reset on loss or on recovery: `single_explicit_initialization` holds in all 24 cases, and the ESTIMATED bus stays VALID through every outage. Losing aiding degrades the health state; it does not invalidate the estimate.

### Recovery jump at reacquisition

| Case | reacquired channel | latency after gap [s] | silence [s] | position jump [m] | velocity jump [m/s] | innovation norm | first USBL fix jump [m] |
|---|---|---:|---:|---:|---:|---:|---:|
| `X_Vc0_P2_dvlgap_noUSBL` | `dvl_vel_body_water` | 0.005 | 7.665 | 0.000 | 0.000 | 0.018 | - |
| `X_Vc0_P3_dvlgap_USBL` | `dvl_vel_body_water` | 0.005 | 7.665 | 0.000 | 0.000 | 0.018 | 2.107 |
| `X_Vc0_P4_dvlhdggap_USBL` | `dvl_vel_body_water` | 0.005 | 7.665 | 0.000 | 0.000 | 0.018 | 1.159 |
| `X_Vc_E015_P2_dvlgap_noUSBL` | `dvl_vel_body_water` | 0.005 | 7.665 | 0.000 | 0.000 | 0.028 | - |
| `X_Vc_E015_P3_dvlgap_USBL` | `dvl_vel_body_water` | 0.005 | 7.665 | 0.000 | 0.000 | 0.028 | 2.727 |
| `X_Vc_E015_P4_dvlhdggap_USBL` | `dvl_vel_body_water` | 0.005 | 7.665 | 0.000 | 0.000 | 0.027 | 1.171 |
| `XZ_Vc0_P2_dvlgap_noUSBL` | `dvl_vel_body_water` | 0.005 | 9.345 | 0.000 | 0.000 | 0.025 | - |
| `XZ_Vc0_P3_dvlgap_USBL` | `dvl_vel_body_water` | 0.005 | 9.345 | 0.000 | 0.000 | 0.025 | 4.409 |
| `XZ_Vc0_P4_dvlhdggap_USBL` | `dvl_vel_body_water` | 0.005 | 9.345 | 0.000 | 0.000 | 0.025 | 3.231 |
| `XZ_Vc_E015_P2_dvlgap_noUSBL` | `dvl_vel_body_water` | 0.005 | 9.345 | 0.000 | 0.000 | 0.016 | - |
| `XZ_Vc_E015_P3_dvlgap_USBL` | `dvl_vel_body_water` | 0.005 | 9.345 | 0.000 | 0.000 | 0.016 | 1.201 |
| `XZ_Vc_E015_P4_dvlhdggap_USBL` | `dvl_vel_body_water` | 0.005 | 9.345 | 0.000 | 0.000 | 0.016 | 0.896 |
| `R10_Vc0_P2_dvlgap_noUSBL` | `dvl_vel_body_water` | 0.005 | 19.005 | 0.000 | 0.000 | 0.038 | - |
| `R10_Vc0_P3_dvlgap_USBL` | `dvl_vel_body_water` | 0.005 | 19.005 | 0.000 | 0.000 | 0.038 | 11.090 |
| `R10_Vc0_P4_dvlhdggap_USBL` | `dvl_vel_body_water` | 0.005 | 19.005 | 0.000 | 0.000 | 0.039 | 12.149 |
| `R10_Vc_E015_P2_dvlgap_noUSBL` | `dvl_vel_body_water` | 0.005 | 19.005 | 0.000 | 0.000 | 0.066 | - |
| `R10_Vc_E015_P3_dvlgap_USBL` | `dvl_vel_body_water` | 0.005 | 19.005 | 0.000 | 0.000 | 0.066 | 12.034 |
| `R10_Vc_E015_P4_dvlhdggap_USBL` | `dvl_vel_body_water` | 0.005 | 19.005 | 0.000 | 0.000 | 0.066 | 9.471 |

A jump at reacquisition is not a defect - it is the filter correcting an error it had no way to observe while the aid was gone - but its size is the honest measure of how much the solution had drifted, and it is reported rather than smoothed away. No jump-limiting, covariance inflation or soft-start was applied, because any of those would be accommodation and this task declared none.

## Gates

### Per-case integrity gates (evaluated from the ESTIMATED bus alone, no truth)

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

### Predeclared hard gates

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

## The health state has no authority, and here is the proof

| Evidence | Result |
|---|:---:|
| State machine evaluated after the tick loop, as a pure function of the accept log | YES |
| Static scan: no health variable is read by a propagation, gain, covariance, admission or reset statement (0 violations) | YES |
| Disabling the state machine leaves the estimated state bitwise identical, 24/24 cases | YES |
| Halving every dwell threshold leaves the estimated state bitwise identical | YES |
| ... while the health timeline itself does respond to that change | YES |

The last two rows together are the point. If the health output were feeding back into the filter anywhere, changing the thresholds would change the estimate. It does not, and the fact that the timeline *did* change proves the ablation was not vacuous.

No accommodation was implemented: no covariance inflation on loss, no gain scheduling, no channel reconfiguration, no reset, no surface or abort command. That is a scope decision, not an oversight - accommodation logic needs its own gate set and its own evidence.

## Truth blindness with a truth-driven simulator

The USBL simulator DOES read TRUTH - that is what forming a MEASURED packet means - and it records which TRUTH sample each packet came from in a usbl_truth_ref field on the channel. The sanitizer drops that field, along with every other truth-side field on the bus, before the estimator can see it. Scrambling the truth-side fields, including replacing the whole truth reference block with nonsense, leaves the estimate bitwise unchanged.

| Evidence | Result |
|---|:---:|
| `run` receives the MEASURED bus only; TRUTH is never passed | YES |
| The USBL truth-reference field is present on the bus and absent after sanitization | YES |
| Re-running on the sanitized bus alone is bitwise identical | YES |
| Scrambling every truth-side field, including a nonsense truth block, changes nothing | YES |
| Static scan: truth tokens outside the post-hoc scorer and the declaration | 0 |

Cases used for the invariance runs: X_Vc0_P3_dvlgap_USBL, X_Vc0_P4_dvlhdggap_USBL.

## Determinism

| Check | Result |
|---|:---:|
| Reverse-order replay: estimated state bitwise identical, 24/24 | YES |
| Reverse-order replay: checksums identical | YES |
| Reverse-order replay: health timeline and transitions identical | YES |

## Manager negative test: malformed packets must be refused

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

All 32 injected packets were refused (0 admitted, 0 fused) and the estimated trajectory, quaternion and covariance are bitwise identical to the clean run: YES. In the two profiles where USBL is declared absent, every USBL item is refused with `channel_absent` before any other test runs, which is the check that an absent optional channel accepts nothing at all.

## Isolation and fingerprints

| Frozen production artifact | Bytes | Unchanged in this run | Matches Gate 5A/5B record |
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

- The Gate 5B artifact hashes also match the values read from source 3: YES.
- `CODEX_VERTICAL_PLAN.md` untouched: YES.
- Production plant, controller and guidance were never invoked.
- Gate 4 waiver remains **OPEN / shadow-only**; nothing here promotes it.

## Visual QA and artifact budget

- `NAV_AVAILABILITY_OUTAGE_STRESS.png`: 12 panels, 451483 bytes, 2550 x 1800 px, ink 0.227, gray std 50.0.
- Decoded after writing with `imread`: YES. Thresholds (width>=1400, height>=900, 0.01<ink<0.95, gray std>5, bytes>80000): YES.
- panel 1 NED track: truth vs estimated with USBL fixes marked
- panel 2 depth: truth and estimate, gaps shaded
- panel 3 absolute position error norm with 3 sigma envelope
- panel 4 velocity error NED with 3 sigma
- panel 5 yaw error with 3 sigma and the heading gap shaded
- panel 6 health state timeline with the four declared states labelled
- panel 7 per-channel age against its freshness horizon, log axis
- panel 8 USBL innovation and NIS against the chi-square 95 reference
- panel 9 MEASURED status raster of all seven channels
- panel 10 hard-gate bar panel, one labelled bar per gate
- panel 11 per-case summary table legible at full resolution
- panel 12 declared schedule and claim-boundary text panel

| Artifact | Bytes |
|---|---:|
| `NAV_AVAILABILITY_OUTAGE_STRESS.md` | 51388 |
| `NAV_AVAILABILITY_OUTAGE_STRESS.mat` | 13302586 |
| `NAV_AVAILABILITY_OUTAGE_STRESS.png` | 451483 |
| **total** | **13805457 (13.166 MiB)** |

- Budget **< 300 MiB**: PASS. The MAT stores gate records, counters, metrics and a 20x decimated showcase only; no full-rate multi-case series is archived.

- The written Markdown is read back from disk and the per-case table decoded: 24 rows, cells YES, labels YES -> PASS.
  This check exists because an earlier task in this vertical shipped a correct result behind a garbled table.

### Post-write rechecks on the delivered artifacts

| Recheck | Result |
|---|:---:|
| Per-case table decoded from the delivered MD | PASS |
| Gate 5B files still unchanged after every write | PASS |
| Each of the three logs grew and carries this task id exactly once | PASS |
| PNG still decodable and readable | PASS |
| Total artifact bytes under budget (13.168 MiB) | PASS |

## Gate decision

- **Gate 5C: PASS** on integrity and availability state-machine behaviour.
- Basis: 24/24 predeclared cases clean, 32/32 hard gates, exact packet counters in every case, zero updates consumed inside any declared gap, the full declared health cycle walked in the correct order with timing inside two base ticks of the declared model, zero transitions in every lock case, deterministic replay, the Gate 5B fingerprint reproduced exactly and the Gate 5B files proved untouched.
- **Accuracy status: NOT_CERTIFIED. Outage limits: CHARACTERIZATION_NOT_CERTIFIED.** The numbers in the error, drift and recovery tables describe this ASSUMED scenario and nothing else. No statement is made or implied about how long this vehicle could actually navigate without aiding.
- **No promotion.** Gate 5B remains as it was; Gate 4 waiver remains OPEN / shadow-only.
- Claim limit: Integrity, interface and availability state-machine behaviour only. No navigation-accuracy and no outage-endurance claim. Simulation-only; nothing here is bench or sea-trial validated.

## Limitations, stated plainly

- Every sensor numeric, every filter constant, every dwell time and the whole outage and USBL schedule is ASSUMED. Nothing here is identified from data.
- TRUTH is a prescribed kinematic scenario, not a plant or closed-loop run. No tracking, stability or control conclusion follows from any of it.
- The USBL model is a position fix with fixed bias, white noise and constant latency. There is no ray bending, no slant-range geometry, no lever arm, no multipath, no range-dependent noise growth and no transponder geometry. A real USBL fails in ways this model cannot express.
- Latency is charged as inflated R rather than compensated by replaying a buffered state to the packet timestamp. Declared approximation, not validated.
- Sensor biases are unmodelled states, so the filter is deliberately inconsistent by exactly those biases and the NIS numbers show it.
- The state machine is a message-age machine. It declares loss of aiding, not loss of accuracy; it would not notice an aid that keeps arriving on time while being wrong.
- Only one gap geometry per profile was tested: a single long gap. Repeated, overlapping and rapidly-cycling gaps were not exercised, and neither was a gap that outlasts the mission.
- No accommodation was implemented or evaluated, so nothing here says what the vehicle should *do* about a POSITION_AID_LOST declaration.
- Simulation-only. Nothing here is hardware, bench or sea-trial evidence.

## Next task

- GATE 6 (named because Gate 5C passed, NOT attempted here): PROPULSION / POWER / COMPUTE budget and margin. Take the actuator commands and the navigation duty cycle this vertical already produces and close them against a declared thruster and control-surface power model, an energy budget over the mission profile, and a compute-load / latency budget for the estimator and controller rates. Numerics remain ASSUMED and every result remains NOT_CERTIFIED until bench data exists.

## MATHEMATICAL_RECORD

```
MATHEMATICAL_RECORD = {
  task_class: AVAILABILITY_OUTAGE_STRESS (Gate 5C, isolated, no promotion),
  equations: {
    nominal: p' = v,  v' = R_bn (f_m - b_a) + g_NED,  q' = 0.5 q (x) [0; w_m - b_g],
             b_g' = 0, b_a' = 0, c' = 0 (random walk in Q only),
    error  : dp' = dv,  dv' = -R_bn [f]x dtheta - R_bn db_a,
             dtheta' = -[w]x dtheta - db_g,
    measure: z_depth = p_D, z_psi = psi(q) (wrapped), z_ins = v_NED,
             z_dvl = R_bn'(v_NED - c_NED),  z_usbl = p_NED  (NEW in Gate 5C),
    update : S = H P H' + R_eff,  K = P H' S^-1,  nu = z - h(x),
             P+ = (I-KH) P (I-KH)' + K R_eff K'  (Joseph),  P+ = (P+ + P+')/2,
             R_eff = R/max(q/q_nom, q_floor) + (lat_scale * age)^2 I,
             reset G = I, G_thth = I - 0.5[dtheta]x,  |q| renormalized
  },
  state_machine: {
    tau_fresh(c) = max(k_fresh*period(c), stale_limit(c)+period(c), tau_floor),
    fresh(c,k)   = t(k) - t_last_accept(c) <= tau_fresh(c),
    pos_fresh    = OR over present position aids {DVL, USBL},
    all_fresh    = AND over every present aiding channel,
    NOMINAL -> DEGRADED            after T_degrade of ~all_fresh,
    DEGRADED -> POSITION_AID_LOST  after T_lost of ~pos_fresh,
    DEGRADED -> NOMINAL            after T_clear of all_fresh,
    POSITION_AID_LOST -> RECOVERING after T_reacq of pos_fresh,
    RECOVERING -> NOMINAL          after T_settle of all_fresh,
    RECOVERING -> POSITION_AID_LOST after T_lost of ~pos_fresh,
    output: status only, no authority over any estimator quantity
  },
  parameter_provenance: {
    DERIVED: sigma_a, sigma_g, tau_fresh, USBL latency scale (= U_ground),
    ASSUMED: all R, P0 (including the absolute-origin P0 switch), dwell times,
             admission thresholds, and the whole outage / USBL schedule,
    IDENTIFIED: none,  TUNED: none (no rerun after seeing results)
  },
  design_reason: 'A navigation system that loses its aiding must degrade predictably and
                  say so, and the saying-so must be provably incapable of changing the
                  estimate, or the health signal becomes another feedback path nobody
                  gated.',
  rejected_alternatives: {
    modify_the_Gate5B_files: rejected (they are frozen inputs; this is a fork),
    let_health_inflate_covariance: rejected (accommodation, needs its own gate set),
    reset_or_reinitialize_on_aid_loss: rejected (destroys the continuity being tested),
    inflate_USBL_R_until_NIS_looks_consistent: rejected (tuning to the answer),
    count_INS_velocity_as_a_position_aid: rejected (makes POSITION_AID_LOST unreachable),
    pick_outage_windows_after_seeing_transitions: rejected (voids the timing gates)
  },
  evidence: { suite_results/NAV_AVAILABILITY_OUTAGE_STRESS.{md,mat,png} },
  conclusion: 'PASS: 24/24 predeclared cases integrity-clean, 32/32 hard gates,
                accuracy and outage limits CHARACTERIZATION / NOT_CERTIFIED',
  open_questions: { repeated and overlapping gaps untested; no accommodation policy;
                    USBL geometry / multipath / range-dependent noise unmodelled;
                    health machine reasons about message age, not about estimate quality }
}
```

## Artifacts

- `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\NAV_AVAILABILITY_OUTAGE_STRESS.md`
- `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\NAV_AVAILABILITY_OUTAGE_STRESS.mat`
- `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\NAV_AVAILABILITY_OUTAGE_STRESS.png`

Preserved inputs (not modified): the Gate 5B library, driver and artifact set.

Root: `C:\Users\ardak\MATLAB\Projects\AUVsim-main`
