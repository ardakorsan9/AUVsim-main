# AUV_MISSION_COMPUTER_INTERFACE_REQUIREMENTS — OPS_MISSION_INTERFACE_PLAN_001

**Date:** 2026-08-08  
**Class:** doc-only interface / architecture readiness  
**MATLAB run:** NO · **model/controller edits:** NO · **CODEX_VERTICAL_PLAN:** untouched  
**Brand / purchase:** none (no vendor selection)  
**Physical / hardware readiness:** **NOT_CERTIFIED**

## Sources (strict, exactly 3)

| # | Path | Role |
|---|------|------|
| 1 | `suite_results/AUV_REALIZATION_READINESS_PLAN.md` | Ordered realization gates; frozen clocks/envelopes; Gate 7 mission+fail-silent; next technical task |
| 2 | `continuous_path_tracking.m` | Deterministic multi-rate path-following core; Guidance→Controller→Plant loop; truth-state usage |
| 3 | `guidance_law.m` | Path geometry → refs; local magnitude/rate limits; no mission-computer API today |

**Evidence / maturity labels** (do not upgrade without new evidence):  
`IMPLEMENTED` · `INTERFACE_SPECIFIED` · `NOT_IMPLEMENTED` · `TO_BE_IDENTIFIED` · `DERIVED` · `FIXED` · `ASSUMED` · `NOT_CERTIFIED`

---

## 1. Verdict

**Mission-computer interface requirements: CREATED (INTERFACE_SPECIFIED).**  
The current sim is a **deterministic path-following core** with **no mission-computer layer**. This document specifies a **logical, versioned message contract** and layering so a future mission computer can sit **above** guidance without rewriting the core. Implementation, HIL, and brand selection are **out of scope**.

**Preserved next technical task (unchanged):** `depth_gamma_speed_scheduled_id_extension`  
**Mission realization work remains Gate 7** (after Gates 3–6 envelopes). This doc is a Gate-7 **interface prep**, not a Gate-7 PASS.

---

## 2. Architecture (must preserve)

### 2.1 Layer boundaries (strict)

```text
Mission  →  Guidance  →  Navigation  →  Controller  →  Actuator
              ↑_______________|  (state / integrity feedback)
```

| Layer | Role | Maturity |
|-------|------|----------|
| **Mission** | Waypoints / segments / mode commands; constrained 3D mission manager; watchdog policy owner (logical) | `NOT_IMPLEMENTED` / `INTERFACE_SPECIFIED` |
| **Guidance** | Path projection, LOS, depth/γ refs, local feasibility shaping → `yaw_ref`, `pitch_ref`, `u_ref`, `r_ff`, `pitch_ref_dot` | `IMPLEMENTED` (`guidance_law.m`) |
| **Navigation** | Truth → measured → estimated; integrity / quality | Truth path `IMPLEMENTED` in loop; measured/estimated / EKF `NOT_IMPLEMENTED` (Gate 5) |
| **Controller** | Attitude/speed loops → `delta_r`, `delta_e`, `thrust` | `IMPLEMENTED` (`controller_law` via `continuous_path_tracking.m`) |
| **Actuator** | Mag/rate limits; future FO/deadband closed-loop | Mag/rate software limits `IMPLEMENTED`; closed-loop realism Gate 3 `NOT_IMPLEMENTED` |

**Non-negotiable:** Mission must **not** bypass Guidance→Controller→Actuator. Mission must **not** write actuator commands directly.

### 2.2 Deterministic path-following core (preserve)

From `continuous_path_tracking.m` (**IMPLEMENTED**):

- Plant + controller advance every `dt_controller`.
- Guidance runs every `guidance_period = round(dt_guidance / dt_controller)` steps with **zero-order hold** of guidance outputs between ticks.
- State order (plant truth today): `x, y, z, φ, θ, ψ, u, v, w, p, q, r`.
- Call chain: `guidance_law` → `controller_law` → `underwater777_vehicle_dynamics`.
- Path input today: `path` matrix + `progress_index` (no mission message schema).

From `guidance_law.m` (**IMPLEMENTED**):

- Arc-length projection, lookahead, CTE, curvature-scheduled `u_ref`, yaw LOS + β compensation, pitch/γ/depth corrections.
- **Local authority already present:** `pitch_ref_max`, `pitch_ref_rate_max`, pitch-corr clamps, yaw slew bound, `u_ref` schedules near end / depth lag.

---

## 3. Timing contract

| Clock | Rate / period | Label | Notes |
|-------|---------------|-------|-------|
| Controller / plant step | **40 Hz** (`dt = 0.025` s) | `FIXED` (interface target for mission-ready twin) | Readiness plan also records an older `dt_controller = 0.0375` s **ASSUMED** default; promote/reconcile under Gate 5/6 compute work — do not silently change production without a gate |
| Guidance | **13.33 Hz** (`dt_guidance = 0.075` s) | `DERIVED` | Marker from readiness / visual pack; ZOH between ticks **IMPLEMENTED** |
| Mission | — | `TO_BE_IDENTIFIED` | Must be ≤ guidance rate or explicitly asynchronously buffered; no numeric rate claimed here |
| Navigation updates | — | `TO_BE_IDENTIFIED` | Gate 5 multirate schedule |
| Actuator feedback | — | `TO_BE_IDENTIFIED` | ICD exists as sim antecedents; HW rate `NOT_CERTIFIED` |

Guidance period relation (**IMPLEMENTED** pattern): `N = round(dt_guidance / dt_controller)` (e.g. 0.075 / 0.025 → 3).

---

## 4. Frames, units, and common header

All mission↔vehicle logical messages share:

| Field | Requirement | Label |
|-------|-------------|-------|
| Units | **SI** (m, m/s, rad, rad/s, N, s) unless a field is explicitly angular-deg in a named legacy diagnostic | `INTERFACE_SPECIFIED` |
| Frames | **NED** for inertial position/velocity/paths; **BODY** for body rates and body-axis velocity components | `INTERFACE_SPECIFIED` (kinematics R·ν already used in core) |
| `t_mono` | Monotonic timestamp [s] | `INTERFACE_SPECIFIED` |
| `seq` | Monotonic sequence (uint32/uint64 wrap policy documented per bus) | `INTERFACE_SPECIFIED` |
| `valid` / `quality` | Validity flag + quality enum/score | `INTERFACE_SPECIFIED` |
| `schema_version` | Semantic version of this message | `INTERFACE_SPECIFIED` |
| `integrity` | CRC/hash or equivalent integrity field | `INTERFACE_SPECIFIED` |
| Heartbeat / stale | Receiver enforces stale timeout; missing heartbeat ⇒ **fail-silent** (see §6) | `INTERFACE_SPECIFIED` |

**No brand, transport, or middleware selection** in this document (ROS/DDS/CAN/etc. = EXTERNAL later).

---

## 5. Versioned logical messages

### 5.1 Mission → Vehicle (downlink)

| Message | Intent | Maturity |
|---------|--------|----------|
| **MissionCommand** | Mode (idle/hold/path_follow/abort_hold), enable flags, constraint set ID, mission_id | `INTERFACE_SPECIFIED` · `NOT_IMPLEMENTED` |
| **WaypointSet** | Ordered NED waypoints `{x,y,z}`, optional speed/heading hints, closed-path flag | `INTERFACE_SPECIFIED` · `NOT_IMPLEMENTED` (today: raw `path` Nx3) |
| **TrajectorySegment** | Arc-parameterized or dense NED polyline segment + validity window + segment_id | `INTERFACE_SPECIFIED` · `NOT_IMPLEMENTED` |

Payload rules (all `INTERFACE_SPECIFIED`):

- Waypoints/segments in **NED**, SI meters.
- Optional hints must be treated as **soft**; guidance local limits win (§6).
- Each message carries common header (§4).
- Mission rate: `TO_BE_IDENTIFIED`; vehicle must accept burst + hold-last-valid until stale.

### 5.2 Vehicle → Mission (uplink)

| Message | Intent | Maturity |
|---------|--------|----------|
| **StateEstimate** | Pose/twist (NED/BODY as tagged), covariance or quality, source tag `{truth,measured,estimated}` | `INTERFACE_SPECIFIED`; today loop uses **plant truth only** (`IMPLEMENTED` as truth-as-feedback) |
| **VehicleHealth** | Nav integrity, watchdog summary, power/compute proxies when available | `INTERFACE_SPECIFIED` · `NOT_IMPLEMENTED` |
| **ActuatorStatus** | Commanded vs (shadow/measured) fin/thrust status, sat/rate-rail flags | Partial suite logs `IMPLEMENTED`; message schema `INTERFACE_SPECIFIED` · HW `NOT_CERTIFIED` |
| **Ack** | Ack/nack of `mission_id` / `segment_id` / `seq`, reject reason codes | `INTERFACE_SPECIFIED` · `NOT_IMPLEMENTED` |

---

## 6. Authority, stale, and fail-silent

| Rule | Requirement | Label |
|------|-------------|-------|
| Local override | **Local magnitude / rate / safety authority always overrides mission** (guidance pitch mag/rate, controller actuator mag/rate ±15°/±25°/±40°/s frozen envelopes, future watchdogs) | `INTERFACE_SPECIFIED`; local mag/rate clamps partially `IMPLEMENTED` in guidance/controller |
| Stale mission | On heartbeat loss or `t_mono`/`seq` stale beyond timeout: **fail-silent** — hold last **safe** local refs or enter **safe-hold** per Gate 7 policy; **do not** invent new path | `INTERFACE_SPECIFIED` · `NOT_IMPLEMENTED` |
| No auto-surface / auto-accommodate | Stale or invalid mission input **must not** auto-surface or auto-accommodate **without HIL-validated** policy | `INTERFACE_SPECIFIED`; HIL = EXTERNAL / Gate 7 evidence |
| Mission cannot raise limits | Mission must not widen actuator or pitch limits beyond local envelope | `INTERFACE_SPECIFIED` |

---

## 7. Truth / measured / estimated + digital-twin log keys

### 7.1 Separation (Gate 5 alignment)

| Stream | Definition | Maturity |
|--------|------------|----------|
| **truth** | Plant state from dynamics (current sim control arguments) | `IMPLEMENTED` in `continuous_path_tracking.m` |
| **measured** | Sensor model outputs (noise/bias/delay/dropout) | `NOT_IMPLEMENTED` |
| **estimated** | Filter/EKF outputs used by guidance/controller in production-ready twin | `NOT_IMPLEMENTED` |

Every controlled channel in future twin logs must be tagged with exactly one of `{truth, measured, estimated}`.

### 7.2 Digital-twin log keys (for sim↔real matching / parameter ID)

Minimum key set (`INTERFACE_SPECIFIED`; many values already logged ad hoc via suite globals — not yet a frozen ICD):

| Key group | Example keys | Purpose |
|-----------|--------------|---------|
| Time / rate | `t_mono`, `seq_ctrl`, `seq_guid`, `dt_controller`, `dt_guidance` | Multirate alignment |
| Mission | `mission_id`, `segment_id`, `wp_seq`, `mission_age`, `mission_valid` | Command provenance |
| Path / guidance | `s_prog`, `cte_y`, `cte_z`, `yaw_ref`, `pitch_ref`, `u_ref`, `r_ff`, `gamma_path`, `gamma_actual` | Path-follow compare |
| State streams | `pose_ned_*_{truth,meas,est}`, `nu_body_*_{truth,meas,est}` | Matching / NEES later |
| Actuator | `delta_e_cmd`, `delta_r_cmd`, `thrust_cmd`, `*_sat`, `*_rate_rail` | Twin vs HIL |
| Health | `nav_integrity`, `actuator_health`, `stale_mission`, `fail_silent_active` | Gate 7 |
| Param ID | `U_op`, `schema_version`, `plant_id_tag`, `ctrl_build_id` | Speed-scheduled ID / regression |

Suite diagnostic globals in `continuous_path_tracking.m` (elevator/rudder attribution, γ/z errors, etc.) are **IMPLEMENTED** research logs; promotion into the frozen twin ICD is Gate 5/7 work.

---

## 8. Mapping: today vs specified

| Item | Status |
|------|--------|
| Path-follow core + guidance ZOH multi-rate | `IMPLEMENTED` |
| Guidance local pitch mag/rate + u_ref scheduling | `IMPLEMENTED` |
| Controller + software fin mag/rate envelopes | `IMPLEMENTED` (frozen metrics in readiness plan) |
| Mission layer / MissionCommand / WaypointSet / TrajectorySegment bus | `INTERFACE_SPECIFIED` · `NOT_IMPLEMENTED` |
| StateEstimate / VehicleHealth / ActuatorStatus / Ack bus | `INTERFACE_SPECIFIED` · `NOT_IMPLEMENTED` |
| Measured/estimated nav chain | `NOT_IMPLEMENTED` (Gate 5) |
| Mission rate numeric value | `TO_BE_IDENTIFIED` |
| Fail-silent mission watchdog in sim | `NOT_IMPLEMENTED` (Gate 7) |
| Brand / radio / SBC purchase | **out of scope** |
| Hardware certification | `NOT_CERTIFIED` |

---

## 9. Relation to realization gates

| Gate | Relation of this ICD |
|------|----------------------|
| Gate 0 | Artifact/disk preflight hygiene (readiness plan append) — applies to all future tasks including mission SIL |
| Gates 1–2 | Vertical plant/structure — **do not block** this ICD; still **next technical work** |
| Gates 3–6 | Envelopes required before Gate 7 mission manager can PASS |
| **Gate 7** | Consumes this ICD: constrained 3D mission manager + watchdog / fail-silent **simulation** |
| Gate 5 | Owns truth/measured/estimated field population behind StateEstimate |
| EXTERNAL | Transport, HIL validation of fail-silent, vendor gear |

---

## 10. Blockers (honest)

1. **Mission rate unset** (`TO_BE_IDENTIFIED`) — cannot freeze mission ZOH/buffer sizing.  
2. **No Mission→Guidance adapter** — path is an in-process `path` array, not versioned messages.  
3. **Truth-as-feedback only** — StateEstimate uplink cannot be claimed measured/estimated until Gate 5.  
4. **Fail-silent / no-auto-surface policy unsimulated** — Gate 7 + HIL still required; this doc does not certify safe-mode.  
5. **Controller clock dual notation** — readiness `0.0375` s ASSUMED default vs this ICD’s **40 Hz FIXED** target; reconcile explicitly in a later gate (no silent production edit here).  
6. **Next technical priority remains vertical ID** — `depth_gamma_speed_scheduled_id_extension`; mission implementation must not leapfrog Gates 1–6.

---

## 11. Non-goals

- MATLAB / controller / guidance code edits  
- `CODEX_VERTICAL_PLAN.md` edits  
- Brand selection, procurement, CAD, wet tests  
- Claiming Gate 7 PASS or HW certification  
- Changing frozen production cascade metrics

---

## 12. Cross-references

- Readiness plan: `suite_results/AUV_REALIZATION_READINESS_PLAN.md`  
- Core loop: `continuous_path_tracking.m`  
- Guidance: `guidance_law.m`  
- **Do not edit:** `suite_results/CODEX_VERTICAL_PLAN.md`
