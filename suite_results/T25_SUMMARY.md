# T25_SUMMARY — Tur 2.5 Pitch Bias Closeout

**Status:** CLOSED (accepted)  
**Date:** 2026-08-04  
**Branch:** `master` (local)  
**Tur 3 (Muw-FF):** NOT started

## Frozen stack (unchanged)

| Param | Value |
|-------|------:|
| `dt_controller` | 0.025 s |
| `dt_guidance` | 0.075 s (ZOH) |
| `Ki_rate` | 0 |
| `tau_rate` | 0.05 s |
| `Ki_angle` | **0.16** (no 2.5.2 bump) |
| Muw-FF / circle `r_ff` / XZ redesign | **not touched** |

## Decision branch

1. Pre-trim Tests A–D → branch **`2.5.1_trim_recalibrate`** (steady angle-I elevator at level).
2. Applied closed-loop trim fold (commits `fdda3f2`, `8c5dce3`).
3. Post-trim verify: **pure level PASS** and **X-line PASS** → **skip 2.5.2 / 2.5.3**.
4. Close Tur 2.5. Do not thrash pitch gains; do not re-enable `Ki_rate`.

## Trim table (2.5.1)

| u (m/s) | Pre-T25 de (deg) | Post-T25 de (deg) |
|--------:|-----------------:|------------------:|
| 0.8 | -2.75 | -9.18 |
| 1.0 | -2.50 | -7.33 |
| 1.5 | -1.75 | -4.62 |
| 2.0 | -1.25 | -3.17 |

## Before → After

### Pure level (guidance OFF, `pitch_ref=0`, settle ≥10 s)

| Case | mean eθ | mean\|e\| | chatter |
|------|--------:|---------:|--------:|
| Pre u=1.5 (Test A) | -0.638° | 0.638° | 0.0015 |
| Pre u=2.0 (Test A) | -0.427° | 0.427° | 0.0013 |
| **Post u=1.5** | **-0.194°** | **0.194°** | **0.0093** |
| **Post u=2.0** | **-0.133°** | **0.133°** | **0.0071** |

Acceptance: \|mean eθ\|<0.3°, mean\|e\|<0.5°, chatter≤0.15 → **PASS**

### Production X-line (suite)

| Metric | Tur12 | Pre-T25 (Test D) | Post-T25 suite |
|--------|------:|-----------------:|---------------:|
| mean \|pitch err\| | 1.45° | 1.317° | **0.57°** |
| pitch chatter | 0.113 °/s | 0.095 °/s | **0.079 °/s** |
| mean CTE | 2.020 m | 3.005* | **2.063 m** |

\*Test D CTE uses nearest-point Euclidean metric in diag harness (not suite CTE).  
Suite CTE vs Tur12: +2.1% (≤5% limit) → **PASS**  
X-line acceptance: mean\|eθ\|<0.7°, chatter≤0.15 → **PASS**

### Post-trim verify harness (`verify_tur25_trim`)

| Case | mean eθ | mean\|e\| | chatter | notes |
|------|--------:|---------:|--------:|-------|
| Pure u=1.5 | -0.194° | 0.194° | 0.0093 | sat 0%, I not pegged |
| Pure u=2.0 | -0.133° | 0.133° | 0.0071 | sat 0%, I not pegged |
| X-line (diag) | -0.553° | 0.553° | 0.077 | CTE metric differs from suite |

## Acceptance checklist

| Gate | Result |
|------|--------|
| Pure level \|mean eθ\|<0.3° | **PASS** (0.194° / 0.133°) |
| Pure level mean\|e\|<0.5° | **PASS** |
| Pure / X chatter ≤0.15 | **PASS** |
| X-line mean\|eθ\|<0.7° | **PASS** (0.57°) |
| X CTE worsen ≤5% vs Tur12 2.02 m | **PASS** (+2.1% → 2.063 m) |
| 2.5.2 Ki_angle bump | **skipped** (not needed) |
| 2.5.3 conditional trim adapt | **skipped** |
| Guidance depth-I detune | **not needed** |

## Commits

| SHA | Message |
|-----|---------|
| `5ea2d7f` | T25: add pitch bias diagnostic harness (Tests A-D) |
| `fdda3f2` | T25.1: recalibrate pitch trim from closed-loop angle-I |
| `8c5dce3` | T25.1: update default trim table after closed-loop refine |
| *(this)* | T25: closeout summary and verified trim suite |

## Artifacts

- `T25_DIAG.md`, `T25_testA..D_*.png`, `T25_diag_results.mat`
- `T25_verify_trim.txt`, `T25_verify_run.log`
- `T25_suite_results.mat`, suite PNGs + `summary.txt`
- `HANDOFF_T25.md` (pause/resume note)

## Next recommended tur

**Tur 3 — Muw verify + feedforward** (architecture), then Tur 4 circle `r_ff`, Tur 5 XZ γ/ż guidance.  
Do **not** reopen pitch-gain thrashing; frozen stack above remains production baseline.
