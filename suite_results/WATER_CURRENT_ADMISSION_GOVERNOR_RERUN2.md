# WATER_CURRENT_ADMISSION_GOVERNOR_RERUN2_001 — 4B mask-orientation validation exception beyond 3/3

**Verdict: FAIL — Gate 4B FAIL — mask orientation validated (32/32); causal residual risk: admitted RESHAPE XZ_U2.0 VE+/-0.15/+0.25 (rows 22-24) improve contact_index (55.9%/55.9%/36.5%) but depth_rms exceeds +2% secondary bound (0.216->0.358, 0.216->0.358, 0.197->0.317). No production promotion.**

Currents: **ASSUMED**. Actuators: **NOT_CERTIFIED**.

## Scope and contract

Exactly three sources: `run_water_current_admission_governor.m`, `guidance_law_water_current_admission_governor.m`, `suite_results/WATER_CURRENT_FEASIBILITY_MAP.mat`.

Prior artifacts `WATER_CURRENT_ADMISSION_GOVERNOR.{md,mat,png}` and `WATER_CURRENT_ADMISSION_GOVERNOR_RERUN.{md,mat,png}` preserved.

FEASIBLE exact pass-through; otherwise authorize only a FEASIBLE speed from identical route/current row; else REFUSE and hold. No radius invention, refusal-as-success, Vc yaw/crab term, retune, plant/path edit, or external shaper. Production remains frozen.

Coverage: 32/32 contracts; 18 pass-through, 3 admitted RESHAPE, 11 REFUSE; 42 paired nonlinear simulations and 11 explicit refusal tests.

Reset/order sentinel: exact=1, unique=1, count=32, replay=1, hold replay=1.

## Causal residual risk

- Mask orientation: **PASS — route/current/class/exact_speed forced 32x1; source indices 1..32**.
- Failed gate: `admitted_secondary_within_2pct`.
- Failed cases: [22 23 24].
- Mechanism: Fixed-horizon T=22s XZ climb: RESHAPE 2.0->1.5 m/s reduces rudder contact but depth_rms worsens vs refused original; no same-route/current FEASIBLE speed meets both >=5% contact reduction and <=2% secondary depth concurrently under frozen plant.

RESHAPE evidence (contact primary met; depth secondary breached):

|Case|Decision|U req->gov|contact reduction %|depth rms orig->ref|CTE rms orig->ref|yaw rms orig->ref|Pass|
|---:|---|---:|---:|---:|---:|---:|:---:|
|22|RESHAPE|2.00->1.50|55.94|0.216->0.358|0.411->0.389|0.49->0.05|FAIL|
|23|RESHAPE|2.00->1.50|55.94|0.216->0.358|0.411->0.389|0.49->0.05|FAIL|
|24|RESHAPE|2.00->1.50|36.48|0.197->0.317|0.422->0.356|1.09->0.06|FAIL|

## Case evidence

|#|ID|Prior -> decision|U requested -> ref|Reason|Progress orig/ref|CTE rms orig/ref|Depth rms orig/ref|Yaw rms orig/ref deg|dr max orig/ref deg|rate orig/ref deg/s|contact orig/ref %|sat orig/ref %|margins ref pos/rate|Reduction %|Pass|
|--:|---|---|---:|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|:---:|
|1|X_U1.0_VE+0.00|FEASIBLE -> PASS_THROUGH|1.00 -> 1.00|exact Gate-4A FEASIBLE row; exact speed parity|330/330|0.349/0.349|0.349/0.349|0.00/0.00|0.00/0.00|0.00/0.00|0.00/0.00|0.00/0.00|25.00/40.00|0.00|PASS|
|2|X_U1.0_VE+0.15|FEASIBLE -> PASS_THROUGH|1.00 -> 1.00|exact Gate-4A FEASIBLE row; exact speed parity|331/331|0.358/0.358|0.348/0.348|0.10/0.10|3.75/3.75|36.78/36.78|0.00/0.00|0.00/0.00|21.25/3.22|0.00|PASS|
|3|X_U1.0_VE-0.15|FEASIBLE -> PASS_THROUGH|1.00 -> 1.00|exact Gate-4A FEASIBLE row; exact speed parity|331/331|0.358/0.358|0.348/0.348|0.10/0.10|3.75/3.75|36.78/36.78|0.00/0.00|0.00/0.00|21.25/3.22|0.00|PASS|
|4|X_U1.0_VE+0.25|REFUSE -> REFUSE|1.00 -> 0.00|no same-route/current FEASIBLE row; bounded zero hold|NaN/NaN|NaN/NaN|NaN/NaN|NaN/NaN|NaN/NaN|NaN/NaN|NaN/NaN|NaN/NaN|NaN/NaN|NaN|PASS|
|5|X_U1.5_VE+0.00|FEASIBLE -> PASS_THROUGH|1.50 -> 1.50|exact Gate-4A FEASIBLE row; exact speed parity|430/430|0.256/0.256|0.256/0.256|0.00/0.00|0.00/0.00|0.00/0.00|0.00/0.00|0.00/0.00|25.00/40.00|0.00|PASS|
|6|X_U1.5_VE+0.15|FEASIBLE -> PASS_THROUGH|1.50 -> 1.50|exact Gate-4A FEASIBLE row; exact speed parity|431/431|0.263/0.263|0.254/0.254|0.05/0.05|2.11/2.11|21.76/21.76|0.00/0.00|0.00/0.00|22.89/18.24|0.00|PASS|
|7|X_U1.5_VE-0.15|FEASIBLE -> PASS_THROUGH|1.50 -> 1.50|exact Gate-4A FEASIBLE row; exact speed parity|431/431|0.263/0.263|0.254/0.254|0.05/0.05|2.11/2.11|21.76/21.76|0.00/0.00|0.00/0.00|22.89/18.24|0.00|PASS|
|8|X_U1.5_VE+0.25|REFUSE -> REFUSE|1.50 -> 0.00|no same-route/current FEASIBLE row; bounded zero hold|NaN/NaN|NaN/NaN|NaN/NaN|NaN/NaN|NaN/NaN|NaN/NaN|NaN/NaN|NaN/NaN|NaN/NaN|NaN|PASS|
|9|X_U2.0_VE+0.00|FEASIBLE -> PASS_THROUGH|2.00 -> 2.00|exact Gate-4A FEASIBLE row; exact speed parity|527/527|0.171/0.171|0.170/0.170|0.00/0.00|0.00/0.00|0.00/0.00|0.00/0.00|0.00/0.00|25.00/40.00|0.00|PASS|
|10|X_U2.0_VE+0.15|FEASIBLE -> PASS_THROUGH|2.00 -> 2.00|exact Gate-4A FEASIBLE row; exact speed parity|527/527|0.177/0.177|0.167/0.167|0.05/0.05|2.08/2.08|38.57/38.57|0.00/0.00|0.00/0.00|22.92/1.43|0.00|PASS|
|11|X_U2.0_VE-0.15|FEASIBLE -> PASS_THROUGH|2.00 -> 2.00|exact Gate-4A FEASIBLE row; exact speed parity|527/527|0.177/0.177|0.167/0.167|0.05/0.05|2.08/2.08|38.57/38.57|0.00/0.00|0.00/0.00|22.92/1.43|0.00|PASS|
|12|X_U2.0_VE+0.25|REFUSE -> REFUSE|2.00 -> 0.00|no same-route/current FEASIBLE row; bounded zero hold|NaN/NaN|NaN/NaN|NaN/NaN|NaN/NaN|NaN/NaN|NaN/NaN|NaN/NaN|NaN/NaN|NaN/NaN|NaN|PASS|
|13|XZ_U1.0_VE+0.00|FEASIBLE -> PASS_THROUGH|1.00 -> 1.00|exact Gate-4A FEASIBLE row; exact speed parity|578/578|0.751/0.751|0.697/0.697|0.00/0.00|0.00/0.00|0.00/0.00|0.00/0.00|0.00/0.00|25.00/40.00|0.00|PASS|
|14|XZ_U1.0_VE+0.15|FEASIBLE -> PASS_THROUGH|1.00 -> 1.00|exact Gate-4A FEASIBLE row; exact speed parity|580/580|0.705/0.705|0.653/0.653|0.05/0.05|1.99/1.99|11.93/11.93|0.00/0.00|0.00/0.00|23.01/28.07|0.00|PASS|
|15|XZ_U1.0_VE-0.15|FEASIBLE -> PASS_THROUGH|1.00 -> 1.00|exact Gate-4A FEASIBLE row; exact speed parity|580/580|0.705/0.705|0.653/0.653|0.05/0.05|1.99/1.99|11.93/11.93|0.00/0.00|0.00/0.00|23.01/28.07|0.00|PASS|
|16|XZ_U1.0_VE+0.25|FEASIBLE -> PASS_THROUGH|1.00 -> 1.00|exact Gate-4A FEASIBLE row; exact speed parity|582/582|0.620/0.620|0.563/0.563|0.11/0.11|4.81/4.81|40.00/40.00|0.00/0.00|0.00/0.00|20.19/0.00|0.00|PASS|
|17|XZ_U1.5_VE+0.00|FEASIBLE -> PASS_THROUGH|1.50 -> 1.50|exact Gate-4A FEASIBLE row; exact speed parity|762/762|0.407/0.407|0.378/0.378|0.00/0.00|0.00/0.00|0.00/0.00|0.00/0.00|0.00/0.00|25.00/40.00|0.00|PASS|
|18|XZ_U1.5_VE+0.15|FEASIBLE -> PASS_THROUGH|1.50 -> 1.50|exact Gate-4A FEASIBLE row; exact speed parity|764/764|0.389/0.389|0.358/0.358|0.05/0.05|1.93/1.93|13.91/13.91|0.00/0.00|0.00/0.00|23.07/26.09|0.00|PASS|
|19|XZ_U1.5_VE-0.15|FEASIBLE -> PASS_THROUGH|1.50 -> 1.50|exact Gate-4A FEASIBLE row; exact speed parity|764/764|0.389/0.389|0.358/0.358|0.05/0.05|1.93/1.93|13.91/13.91|0.00/0.00|0.00/0.00|23.07/26.09|0.00|PASS|
|20|XZ_U1.5_VE+0.25|FEASIBLE -> PASS_THROUGH|1.50 -> 1.50|exact Gate-4A FEASIBLE row; exact speed parity|766/766|0.356/0.356|0.317/0.317|0.06/0.06|2.24/2.24|28.22/28.22|0.00/0.00|0.00/0.00|22.76/11.78|0.00|PASS|
|21|XZ_U2.0_VE+0.00|FEASIBLE -> PASS_THROUGH|2.00 -> 2.00|exact Gate-4A FEASIBLE row; exact speed parity|900/900|0.409/0.409|0.227/0.227|0.00/0.00|0.00/0.00|0.00/0.00|0.00/0.00|0.00/0.00|25.00/40.00|0.00|PASS|
|22|XZ_U2.0_VE+0.15|REFUSE -> RESHAPE|2.00 -> 1.50|same route/current FEASIBLE map row XZ_U1.5_VE+0.15 at 1.5 m/s|900/764|0.411/0.389|0.216/0.358|0.49/0.05|15.64/1.93|40.00/13.91|0.00/0.00|0.00/0.00|23.07/26.09|55.94|FAIL|
|23|XZ_U2.0_VE-0.15|REFUSE -> RESHAPE|2.00 -> 1.50|same route/current FEASIBLE map row XZ_U1.5_VE-0.15 at 1.5 m/s|900/764|0.411/0.389|0.216/0.358|0.49/0.05|15.64/1.93|40.00/13.91|0.00/0.00|0.00/0.00|23.07/26.09|55.94|FAIL|
|24|XZ_U2.0_VE+0.25|REFUSE -> RESHAPE|2.00 -> 1.50|same route/current FEASIBLE map row XZ_U1.5_VE+0.25 at 1.5 m/s|900/766|0.422/0.356|0.197/0.317|1.09/0.06|19.91/2.24|40.00/28.22|0.00/0.00|0.00/0.00|22.76/11.78|36.48|FAIL|
|25|R10_U1.5_VE+0.00|REFUSE -> REFUSE|1.50 -> 0.00|no same-route/current FEASIBLE row; bounded zero hold|NaN/NaN|NaN/NaN|NaN/NaN|NaN/NaN|NaN/NaN|NaN/NaN|NaN/NaN|NaN/NaN|NaN/NaN|NaN|PASS|
|26|R10_U1.5_VE+0.15|REFUSE -> REFUSE|1.50 -> 0.00|no same-route/current FEASIBLE row; bounded zero hold|NaN/NaN|NaN/NaN|NaN/NaN|NaN/NaN|NaN/NaN|NaN/NaN|NaN/NaN|NaN/NaN|NaN/NaN|NaN|PASS|
|27|R10_U1.5_VE-0.15|REFUSE -> REFUSE|1.50 -> 0.00|no same-route/current FEASIBLE row; bounded zero hold|NaN/NaN|NaN/NaN|NaN/NaN|NaN/NaN|NaN/NaN|NaN/NaN|NaN/NaN|NaN/NaN|NaN/NaN|NaN|PASS|
|28|R10_U1.5_VE+0.25|REFUSE -> REFUSE|1.50 -> 0.00|no same-route/current FEASIBLE row; bounded zero hold|NaN/NaN|NaN/NaN|NaN/NaN|NaN/NaN|NaN/NaN|NaN/NaN|NaN/NaN|NaN/NaN|NaN/NaN|NaN|PASS|
|29|R10_U2.0_VE+0.00|REFUSE -> REFUSE|2.00 -> 0.00|no same-route/current FEASIBLE row; bounded zero hold|NaN/NaN|NaN/NaN|NaN/NaN|NaN/NaN|NaN/NaN|NaN/NaN|NaN/NaN|NaN/NaN|NaN/NaN|NaN|PASS|
|30|R10_U2.0_VE+0.15|REFUSE -> REFUSE|2.00 -> 0.00|no same-route/current FEASIBLE row; bounded zero hold|NaN/NaN|NaN/NaN|NaN/NaN|NaN/NaN|NaN/NaN|NaN/NaN|NaN/NaN|NaN/NaN|NaN/NaN|NaN|PASS|
|31|R10_U2.0_VE-0.15|REFUSE -> REFUSE|2.00 -> 0.00|no same-route/current FEASIBLE row; bounded zero hold|NaN/NaN|NaN/NaN|NaN/NaN|NaN/NaN|NaN/NaN|NaN/NaN|NaN/NaN|NaN/NaN|NaN/NaN|NaN|PASS|
|32|R10_U2.0_VE+0.25|REFUSE -> REFUSE|2.00 -> 0.00|no same-route/current FEASIBLE row; bounded zero hold|NaN/NaN|NaN/NaN|NaN/NaN|NaN/NaN|NaN/NaN|NaN/NaN|NaN/NaN|NaN/NaN|NaN/NaN|NaN|PASS|

Every current is provenance-tagged `Gate-4A map Vc NED m/s; ASSUMED`. REFUSE rows are output-contract tests and are never tracking successes.

## Functional gates

|Gate|Result|
|---|:---:|
|all_32_contracts|PASS|
|exact_18_feasible_parity|PASS|
|nonfeasible_only_from_same_row|PASS|
|admitted_contact_reduction_5pct|PASS|
|zero_hard_violations|PASS|
|deterministic_bounded_refusals|PASS|
|admitted_secondary_within_2pct|FAIL|
|no_refusal_counted_as_tracking_success|PASS|
|production_frozen|PASS|
|working_data_under_300_MiB|PASS|

Only one simulation pair is retained at a time; bounded preallocation estimate is below 20 MiB (<300 MiB).

Next: **Gate 5 prohibited absent explicit residual-risk waiver; currents ASSUMED and actuators NOT_CERTIFIED.**

Gate 4B FAIL — mask orientation validated (32/32); causal residual risk: admitted RESHAPE XZ_U2.0 VE+/-0.15/+0.25 (rows 22-24) improve contact_index (55.9%/55.9%/36.5%) but depth_rms exceeds +2% secondary bound (0.216->0.358, 0.216->0.358, 0.197->0.317). No production promotion.

`CODEX_VERTICAL_PLAN.md` untouched. Production not promoted.
