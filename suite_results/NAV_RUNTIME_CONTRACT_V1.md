# NAV_RUNTIME_CONTRACT_V1

**Owner:** Codex contract/verifier layer  
**Source truth:** `navigation_multirate_ekf_availability.m` SHA-256 `248d723a2141ecd067b8d768549febb471d3878636622504ada261d8516b1c20`  
**Claim:** `DEPLOY_CANDIDATE / NOT_IN_PRODUCTION / NOT_CERTIFIED`  

This contract extracts only the accepted Gate 5C reusable navigation math. It does not promote the batch harness, tune Q/R, certify sensors, or grant actuator authority.

## Files and entry points

Cursor may add exactly:

- `nav_codegen_init.m`: returns fixed `params` and validates the frozen constants.
- `nav_codegen_reset.m`: returns a fully finite, explicit cold state.
- `nav_codegen_step.m`: one fixed-shape operation selected by numeric `uint8 in.op`.

No global, persistent, strings, cells, dynamic fields, variable-size arrays, `assert`, `error`, NaN/Inf control sentinels, or heap-oriented constructs are permitted in those files.

## Fixed dimensions, indices, and units

- Error state is exactly 18: position `1:3` NED m, velocity `4:6` NED m/s, attitude error `7:9` BODY rad, gyro bias `10:12` BODY rad/s, accel bias `13:15` BODY m/s^2, current `16:18` NED m/s.
- Nominal state: `p[3], v[3], q[4]` scalar-first body-to-NED, `bg[3], ba[3], c[3]`, covariance `P[18x18]`.
- Seven channel enums: 1 gyro, 2 accel, 3 depth, 4 heading, 5 INS velocity NED, 6 DVL body water-relative, 7 USBL NED position.
- Operations: `uint8(1)` initialize from an admitted measured snapshot, `uint8(2)` paired-IMU propagate, `uint8(3)` one aiding update, `uint8(0)` output/no-op. Any other op fails silent.
- All runtime calculations are double in V1. Single-precision shadow is a later gate, not an implicit cast here.

## Params (frozen Gate 5C constants)

`nav_codegen_init` shall return finite fields and `config_valid` for:

- `g_ned=9.81`.
- Q sigmas `[0, 2.0e-3, 3.5e-4, 1.0e-5, 1.0e-4, 1.0e-3]` for p/a/g/bg/ba/c.
- R: depth `0.020^2`; heading `deg2rad(0.5)^2`; INS diag `[0.020 0.020 0.030]^2`; DVL diag `[0.010 0.010 0.015]^2`; USBL diag `[1.50 1.50 0.80]^2`.
- Latency scales depth/heading/INS/DVL/USBL = `0.60, 0.30, 0.50, 0.50, 1.50`.
- P0 p `[0.10 0.10 0.50]^2`, absolute horizontal `100^2`, v `[0.30 0.30 0.30]^2`, attitude `deg2rad([2 2 3])^2`, bg `[0.010]^2`, ba `[0.050]^2`, c `[0.50]^2`.
- `q_min_frac=0.20`, `q_floor=0.20`, `nis_scale=100`, `dt_prop_max=0.050`, `dt_prop_sub=0.010`, `n_sub_max=5`, `tol_time=1e-12`, `tol_pair=1e-9`.

These values remain `ASSUMED / NOT_CERTIFIED` and must not be retuned.

## State and fixed input ABI

Cold state is finite and contains: `initialized=false`, zero nominal vectors, identity quaternion, zero `P[18x18]`, `last_seq[7] uint32`, `have_seq[7] logical`, `last_ts[7] double`, `have_ts[7] logical`, `last_accept_t[7]`, `have_accept_t[7]`, `est_seq uint32`.

Input is one fixed struct for every op:

- common: `op uint8`, `t`, `sample_valid`.
- initialize: `init_gyro[3]`, `init_accel[3]`, `init_depth`, `init_heading`, `init_ins_vel[3]`, `abs_position_present`, `init_seq[5] uint32`, `init_timestamp[5]` in channel order gyro/accel/depth/heading/INS.
- propagate: `gyro[3]`, `accel[3]`, `gyro_seq`, `accel_seq`, `gyro_timestamp`, `accel_timestamp`.
- update: `channel uint8`, `value[3]`, `dim uint8`, `packet_valid`, `status uint8` (`2` means valid), `quality`, `stale_age`, `seq`, `timestamp`, `present`, `bound_lo[3]`, `bound_hi[3]`, `q_nom`, `stale_limit_s`.

Output is always finite: nominal state copies, covariance diagonal, Euler angles, body water-relative velocity, `initialized`, `valid`, `fused`, `health_bits uint32`, `est_seq`, and `source_mask uint32`. Invalid calls hold the prior navigation state and emit `valid=false`, `fused=false`, a nonzero health bit, and finite output data.

## Operation semantics

### Initialize

Require `config_valid`, `sample_valid`, all measured snapshot values/timestamps finite, strictly positive nonzero sequence numbers, gyro/accel timestamp pairing within `tol_pair`, depth/heading/INS dimensions fixed by the ABI, and monotonically valid snapshot timestamps. Initialize exactly as Gate 5C:

`theta0=asin(clamp(init_accel(1)/g_ned,-1,1))`, `phi0=atan2(-init_accel(2),-init_accel(3))`, wrapped heading, `p=[0;0;depth]`, `v=init_ins_vel`, quaternion from Euler, zero biases/current. Build diagonal P0; use `p_abs` for N/E only when `abs_position_present=true`. Commit the five snapshot channel sequence/timestamps. A new initialize request deterministically replaces prior state.

### Propagate

Require initialized/config valid, valid and finite pair, both sequences and timestamps strictly increasing, gyro/accel timestamps within `tol_pair`, and `dt=gyro_timestamp-last gyro timestamp` in `(0,dt_prop_max]`. For `dt>dt_prop_sub`, use `ceil(dt/dt_prop_sub)` equal substeps and reject if above `n_sub_max`.

For every substep preserve Gate 5C lines 1201-1232 exactly: bias removal, quaternion rotation, NED gravity down, p/v/q propagation, fixed 18-state F, second-order Phi, Qd trapezoid form, covariance propagation and symmetrization.

### Aiding update

Admission order is fixed: supported channel/dim -> present -> packet/status valid -> finite value/timestamp/quality/stale -> bounds -> quality threshold -> stale limit -> sequence increasing -> timestamp increasing -> initialized. On rejection, do not commit the channel manager and do not mutate nominal/P.

Preserve the Gate 5C measurement models for depth, heading, INS velocity, DVL body water-relative velocity, and USBL position. Use latency-aware R. Compute NIS and reject when nonfinite or above `nis_scale*dimension`. Fuse with Joseph form `P=(I-KH)P(I-KH)' + K R K'`, symmetrize, inject all 18 error states, normalize quaternion, then apply the attitude reset Jacobian and symmetrize again. Commit sequence/timestamp only for a fused packet.

Scalar updates use a scalar divide. Three-dimensional updates use a deterministic fixed 3x3 solve; no variable-size matrix solve is permitted.

## Health bits and safety properties

Use these stable bit values (multiple may be ORed):

- 1 `BAD_OP`
- 2 `NOT_INITIALIZED`
- 4 `CONFIG_INVALID`
- 8 `SAMPLE_INVALID`
- 16 `NONFINITE`
- 32 `UNSUPPORTED_CHANNEL_OR_DIM`
- 64 `CHANNEL_ABSENT`
- 128 `STATUS_INVALID`
- 256 `OUT_OF_BOUNDS`
- 512 `LOW_QUALITY`
- 1024 `STALE`
- 2048 `SEQ_NONINCREASING`
- 4096 `TIMESTAMP_NONINCREASING`
- 8192 `IMU_PAIR_MISMATCH`
- 16384 `DT_INVALID_OR_SUBSTEP_CAP`
- 32768 `INNOVATION_GATE`
- 65536 `MATH_NONFINITE`

The production truth firewall is structural: the ABI contains no ground truth, route label, fault label, outage label, plant state, or applied actuator signal. The navigation core outputs estimates/health only and never actuator commands or accommodation authority.

