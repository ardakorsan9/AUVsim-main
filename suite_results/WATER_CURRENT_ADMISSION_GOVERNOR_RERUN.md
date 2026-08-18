# WATER_CURRENT_ADMISSION_GOVERNOR_RERUN_001 — 4B syntax-fix validation exception beyond 3/3

**Verdict: FAIL — Gate 4B syntax-fix validation exception FAIL; causal residual risk remains after authorized rerun.**

Currents: **ASSUMED**. Actuators: **NOT_CERTIFIED**.

## Scope and contract

Exactly three sources: `run_water_current_admission_governor.m`, `guidance_law_water_current_admission_governor.m`, `suite_results/WATER_CURRENT_FEASIBILITY_MAP.mat`.

Prior FAIL artifacts `WATER_CURRENT_ADMISSION_GOVERNOR.{md,mat,png}` preserved. Production frozen. No promotion. Wrapper: `run_water_current_admission_governor_rerun.m`.

Unchanged 32-contract Gate-4A map: 18 FEASIBLE exact pass-through required; prior REFUSE may use only same-route/current speed already FEASIBLE in Gate4A, else bounded hold-last-valid REFUSE.

## Causal FAIL

Single authorized MATLAB validation aborted in `guidance_law_water_current_admission_governor` during candidate-mask construction: `strcmp` route mask (`1x32`) AND `arrayfun` current mask (`32x1`) implicitly expanded to `32x32`, so `find()` returned indices `>32` and `map_cases(candidates)` threw `Index exceeds the number of array elements`. Zero contracts executed. Prior plot-syntax FAIL was already hardened; column-mask default initialization was corrected after this abort but not re-executed (one-invocation constraint).

## Coverage

- Contract declarations: 32/32 (unchanged Gate-4A map).
- Executed contracts: **0/32**.
- Pass-through / RESHAPE / REFUSE decisions: **NOT EVALUATED**.
- Paired nonlinear simulations: **0**.
- Explicit refusal-output tests: **0**.
- Exact 18-case FEASIBLE parity: **NOT VERIFIED**.
- Admitted RESHAPE ≥5% contact reduction: **NOT VERIFIED**.
- Zero hard violations / secondary ≤2% / hold continuity / reset-order sentinel: **NOT VERIFIED**.
- Speeds, progress, original/ref CTE/depth/yaw, rudder magnitude/rate/contact/sat margins: **NOT EVALUATED**.
- Refusal counted as tracking success: 0 (no contract executed).

## Case evidence

|#|ID|Prior|U req|Vc East|Decision/reason|Progress orig/ref|CTE/depth/yaw|Rudder mag/rate/contact/sat/margins|Hold/provenance|Pass|
|--:|---|---|---:|---:|---|---|---|---|---|:---:|
|1|X_U1.0_VE+0.00|FEASIBLE|1.00|+0.00|NOT EVALUATED — mask-orientation abort|n/a|n/a|n/a|hold n/a; Gate-4A map Vc NED m/s ASSUMED|FAIL|
|2|X_U1.0_VE+0.15|FEASIBLE|1.00|+0.15|NOT EVALUATED — mask-orientation abort|n/a|n/a|n/a|hold n/a; Gate-4A map Vc NED m/s ASSUMED|FAIL|
|3|X_U1.0_VE-0.15|FEASIBLE|1.00|-0.15|NOT EVALUATED — mask-orientation abort|n/a|n/a|n/a|hold n/a; Gate-4A map Vc NED m/s ASSUMED|FAIL|
|4|X_U1.0_VE+0.25|REFUSE|1.00|+0.25|NOT EVALUATED — mask-orientation abort|n/a|n/a|n/a|hold n/a; Gate-4A map Vc NED m/s ASSUMED|FAIL|
|5|X_U1.5_VE+0.00|FEASIBLE|1.50|+0.00|NOT EVALUATED — mask-orientation abort|n/a|n/a|n/a|hold n/a; Gate-4A map Vc NED m/s ASSUMED|FAIL|
|6|X_U1.5_VE+0.15|FEASIBLE|1.50|+0.15|NOT EVALUATED — mask-orientation abort|n/a|n/a|n/a|hold n/a; Gate-4A map Vc NED m/s ASSUMED|FAIL|
|7|X_U1.5_VE-0.15|FEASIBLE|1.50|-0.15|NOT EVALUATED — mask-orientation abort|n/a|n/a|n/a|hold n/a; Gate-4A map Vc NED m/s ASSUMED|FAIL|
|8|X_U1.5_VE+0.25|REFUSE|1.50|+0.25|NOT EVALUATED — mask-orientation abort|n/a|n/a|n/a|hold n/a; Gate-4A map Vc NED m/s ASSUMED|FAIL|
|9|X_U2.0_VE+0.00|FEASIBLE|2.00|+0.00|NOT EVALUATED — mask-orientation abort|n/a|n/a|n/a|hold n/a; Gate-4A map Vc NED m/s ASSUMED|FAIL|
|10|X_U2.0_VE+0.15|FEASIBLE|2.00|+0.15|NOT EVALUATED — mask-orientation abort|n/a|n/a|n/a|hold n/a; Gate-4A map Vc NED m/s ASSUMED|FAIL|
|11|X_U2.0_VE-0.15|FEASIBLE|2.00|-0.15|NOT EVALUATED — mask-orientation abort|n/a|n/a|n/a|hold n/a; Gate-4A map Vc NED m/s ASSUMED|FAIL|
|12|X_U2.0_VE+0.25|REFUSE|2.00|+0.25|NOT EVALUATED — mask-orientation abort|n/a|n/a|n/a|hold n/a; Gate-4A map Vc NED m/s ASSUMED|FAIL|
|13|XZ_U1.0_VE+0.00|FEASIBLE|1.00|+0.00|NOT EVALUATED — mask-orientation abort|n/a|n/a|n/a|hold n/a; Gate-4A map Vc NED m/s ASSUMED|FAIL|
|14|XZ_U1.0_VE+0.15|FEASIBLE|1.00|+0.15|NOT EVALUATED — mask-orientation abort|n/a|n/a|n/a|hold n/a; Gate-4A map Vc NED m/s ASSUMED|FAIL|
|15|XZ_U1.0_VE-0.15|FEASIBLE|1.00|-0.15|NOT EVALUATED — mask-orientation abort|n/a|n/a|n/a|hold n/a; Gate-4A map Vc NED m/s ASSUMED|FAIL|
|16|XZ_U1.0_VE+0.25|FEASIBLE|1.00|+0.25|NOT EVALUATED — mask-orientation abort|n/a|n/a|n/a|hold n/a; Gate-4A map Vc NED m/s ASSUMED|FAIL|
|17|XZ_U1.5_VE+0.00|FEASIBLE|1.50|+0.00|NOT EVALUATED — mask-orientation abort|n/a|n/a|n/a|hold n/a; Gate-4A map Vc NED m/s ASSUMED|FAIL|
|18|XZ_U1.5_VE+0.15|FEASIBLE|1.50|+0.15|NOT EVALUATED — mask-orientation abort|n/a|n/a|n/a|hold n/a; Gate-4A map Vc NED m/s ASSUMED|FAIL|
|19|XZ_U1.5_VE-0.15|FEASIBLE|1.50|-0.15|NOT EVALUATED — mask-orientation abort|n/a|n/a|n/a|hold n/a; Gate-4A map Vc NED m/s ASSUMED|FAIL|
|20|XZ_U1.5_VE+0.25|FEASIBLE|1.50|+0.25|NOT EVALUATED — mask-orientation abort|n/a|n/a|n/a|hold n/a; Gate-4A map Vc NED m/s ASSUMED|FAIL|
|21|XZ_U2.0_VE+0.00|FEASIBLE|2.00|+0.00|NOT EVALUATED — mask-orientation abort|n/a|n/a|n/a|hold n/a; Gate-4A map Vc NED m/s ASSUMED|FAIL|
|22|XZ_U2.0_VE+0.15|REFUSE|2.00|+0.15|NOT EVALUATED — mask-orientation abort|n/a|n/a|n/a|hold n/a; Gate-4A map Vc NED m/s ASSUMED|FAIL|
|23|XZ_U2.0_VE-0.15|REFUSE|2.00|-0.15|NOT EVALUATED — mask-orientation abort|n/a|n/a|n/a|hold n/a; Gate-4A map Vc NED m/s ASSUMED|FAIL|
|24|XZ_U2.0_VE+0.25|REFUSE|2.00|+0.25|NOT EVALUATED — mask-orientation abort|n/a|n/a|n/a|hold n/a; Gate-4A map Vc NED m/s ASSUMED|FAIL|
|25|R10_U1.5_VE+0.00|REFUSE|1.50|+0.00|NOT EVALUATED — mask-orientation abort|n/a|n/a|n/a|hold n/a; Gate-4A map Vc NED m/s ASSUMED|FAIL|
|26|R10_U1.5_VE+0.15|REFUSE|1.50|+0.15|NOT EVALUATED — mask-orientation abort|n/a|n/a|n/a|hold n/a; Gate-4A map Vc NED m/s ASSUMED|FAIL|
|27|R10_U1.5_VE-0.15|REFUSE|1.50|-0.15|NOT EVALUATED — mask-orientation abort|n/a|n/a|n/a|hold n/a; Gate-4A map Vc NED m/s ASSUMED|FAIL|
|28|R10_U1.5_VE+0.25|REFUSE|1.50|+0.25|NOT EVALUATED — mask-orientation abort|n/a|n/a|n/a|hold n/a; Gate-4A map Vc NED m/s ASSUMED|FAIL|
|29|R10_U2.0_VE+0.00|REFUSE|2.00|+0.00|NOT EVALUATED — mask-orientation abort|n/a|n/a|n/a|hold n/a; Gate-4A map Vc NED m/s ASSUMED|FAIL|
|30|R10_U2.0_VE+0.15|REFUSE|2.00|+0.15|NOT EVALUATED — mask-orientation abort|n/a|n/a|n/a|hold n/a; Gate-4A map Vc NED m/s ASSUMED|FAIL|
|31|R10_U2.0_VE-0.15|REFUSE|2.00|-0.15|NOT EVALUATED — mask-orientation abort|n/a|n/a|n/a|hold n/a; Gate-4A map Vc NED m/s ASSUMED|FAIL|
|32|R10_U2.0_VE+0.25|REFUSE|2.00|+0.25|NOT EVALUATED — mask-orientation abort|n/a|n/a|n/a|hold n/a; Gate-4A map Vc NED m/s ASSUMED|FAIL|

Every current is provenance-tagged `Gate-4A map Vc NED m/s; ASSUMED`. REFUSE is never tracking success.

## Functional gates

|Gate|Result|
|---|:---:|
|all_32_contracts|FAIL|
|exact_18_feasible_parity|FAIL|
|nonfeasible_only_from_same_row|FAIL|
|admitted_contact_reduction_5pct|FAIL|
|zero_hard_violations|FAIL|
|deterministic_bounded_refusals|FAIL|
|admitted_secondary_within_2pct|FAIL|
|no_refusal_counted_as_tracking_success|PASS|
|production_frozen|PASS|
|working_data_under_300_MiB|PASS|

Residual risk: governor same-route/current candidate selection under 32×1 map structs was not functionally validated; Gate-4 simulation-contract PASS not demonstrated.

Next: **Gate 5 prohibited absent explicit residual-risk waiver; currents ASSUMED and actuators NOT_CERTIFIED.**

`CODEX_VERTICAL_PLAN.md` untouched. Production not promoted.
