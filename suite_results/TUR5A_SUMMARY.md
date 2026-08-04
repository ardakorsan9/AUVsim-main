# TUR5A_SUMMARY — inertial ż error on pitch_ref

**Date:** 2026-08-04 17:30:08
**Change:** `pitch_ref += K_zdot * (zdot_path - zdot_inertial)` (Kz / depth-I unchanged)
**Overall:** **FAIL** — STOP before Tur5B γ (CTE only −5% vs −15% gate). Keep `K_zdot=0.50`.

## Definition

- `zdot_inertial = (R(φ,θ,ψ)*[u;v;w])_z` passed from `continuous_path_tracking` (arg 7).
- `zdot_path = t_hat(3) * U_along`, `U_along = max(hypot(U_h,zdot), 0.3)`.
- Sign: same family as depth-P (`cte(3)=z−z_path`, corr `−= K·(·)` ≡ `+= K·(z_path−z)`).
- Existing: `Kz=0.050`, `Ki_z=0.006` **untouched**. Rate-limit on pitch_ref kept.

## Frozen

| Param | Value |
|-------|------:|
| `lambda_muw_ff` | **0.25** |
| `dt_controller` | 0.0250 |
| `dt_guidance` | 0.0750 |
| `tau_rate` | 0.0500 |
| `Ki_rate` | 0.000 |
| `Ki_angle` | 0.160 |
| `K_zdot` (selected) | **0.50** |
| Tur4A `r_ff=U_h*κ` / trim T25 / pitch PID | **kept** |
| Tur4B radial FF | **SKIPPED** (per user) |

## XZ K_zdot sweep

Baseline CTE = 2.766 m (Tur4A / T3B-2). Target ≤ 2.351 m (≥15% drop).

| K_zdot | CTE (m) | drop % | \|e_θ\| (°) | mean e_θ (°) | chatter (°/s) | elev sat% |
|-------:|--------:|-------:|------------:|-------------:|--------------:|----------:|
| 0.00 | 2.766 | 0.0 | 1.55 | +1.316 | 0.0665 | 0.0 |
| 0.20 | 2.698 | 2.5 | 1.52 | +1.318 | 0.0708 | 0.0 |
| 0.50 **best** | 2.628 | 5.0 | 1.52 | +1.334 | 0.1110 | 0.0 |
| 1.00 | 2.570 | 7.1 | 1.55 | +1.378 | 0.1374 | 0.0 |

Notes:
- `K=0` reproduces Tur4A XZ CTE=2.766 exactly (wiring OK).
- `K=1.0` best raw CTE but chatter 0.137 > 0.12 → rejected.
- Soft-best `K=0.50`: chatter OK, no elev sat; CTE still far from ≤2.35.

## Optional λ A/B @ best K (XZ only)

| λ | CTE | \|pitch\| | chatter | sat% |
|--:|----:|---------:|--------:|-----:|
| 0.00 | 2.563 | 0.88 | 0.1590 | 0.0 |
| 0.25 | 2.628 | 1.52 | 0.1110 | 0.0 |

Keep λ=0.25 (freeze). λ=0 slightly better CTE but chatter exceeds 0.12.

## Full suite @ K_zdot=0.50, λ=0.25

Regression baseline = Tur4A. Gate: X/circle/helix CTE ≤5% worse.

| Scenario | CTE now | CTE base | Δ% | \|pitch\| | chatter |
|----------|--------:|---------:|---:|--------:|--------:|
| X-line | 2.074 | 2.116 | −2.0 | 0.21 | 0.0914 |
| XZ-line | 2.628 | 2.766 | −5.0 | 1.52 | 0.1110 |
| Circle | 1.518 | 1.516 | +0.1 | 0.15 | 0.0481 |
| Helix | 1.665 | 1.675 | −0.6 | 0.17 | 0.0446 |

## Acceptance (XZ)

| Check | Result |
|-------|--------|
| XZ CTE ≤ 2.351 (≥15% drop) | **FAIL** (2.628, only −5%) |
| Prefer XZ CTE < 2.0 m | **FAIL** |
| \|e_θ\| < 0.8° | **FAIL** (1.52; already 1.55 at K=0 under Muw-FF) |
| chatter < 0.12 °/s | PASS (0.1110) |
| no elevator sat | PASS (0.0%) |
| X/circle/helix CTE ≤5% worse | PASS |
| **Overall T5A** | **FAIL** |

## Verdict

**T5A FAIL — clearly insufficient for CTE gate. STOP before Tur5B** (no γ attempt this turn).

- ż-D term helps directionally (−5% CTE at K=0.50) but saturates against climb authority / Muw-FF pitch bias before the −15% gate.
- Higher K worsens chatter without reaching ≤2.35 m.
- Keep feature on with `K_zdot=0.50` (safe, non-regressing); next lever is geometric γ-guidance (T5B).

## NEXT queue (do NOT implement in this task)

1. **Tur5B γ-guidance** — needed; T5A alone insufficient for XZ CTE.
2. **Yaw ref smoothness** — yaw rises steadily but some refs do not (queued after T5).
3. **R=5 speed scheduler** — if rudder-authority limited circle still needs work (Tur4B radial SKIPPED).
4. **LQI / SMC / NMPC** — only if T5 fails gates after γ attempt.

## Files touched

- `guidance_law.m` — `K_zdot * e_zdot` on pitch_raw
- `continuous_path_tracking.m` — pass inertial zdot
- `init_parameters.m` — `K_zdot` default **0.50**
- `run_tur5a.m` — sweep + suite runner
