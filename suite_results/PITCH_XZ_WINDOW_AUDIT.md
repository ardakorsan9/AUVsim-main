# PITCH_XZ_WINDOW_AUDIT

**TASK_ID:** PITCH_XZ_WINDOW_AUDIT_001
**Date:** 2026-08-05 19:42:23
**Audit verdict:** **PASS** (defs consistent + raw-error reproduce)
**Climb-FF under corrected windows / original gates:** **PASS**

## Metric file

- **old:** inline `first_hold` in `run_pitch_xz_track.m` / `run_pitch_xz_climb_trim_ff.m`
  (settling = end of first |eθ|≤±0.5° for 1.0 s; steady = (t≥5 ∧ s<0.88 s_tot)∖acq)
- **new:** `compute_pitch_window_metrics.m` (`mode='persistent'`)
  (drivers updated to call this; production controller/guidance/plant untouched)

## Equations / windows / units

```
e_theta [rad] = theta_ref - theta_phys,  theta_phys = -theta
band = 0.5 deg
valid = { k | s(k) < 0.88 * s_total }     % end-exclusion
n_end = last index in valid
settle_idx = min { k <= n_end : all(|e_theta(k:n_end)| <= band) }
           = empty => settling_s = NaN (FAIL)
settling_s [s] = t(settle_idx)
mask_acq     = 1:settle_idx                 % [start, settle]
mask_steady  = settle_idx:n_end             % [settle, end-excl]
MAE/RMS/p95 reported in degrees on those masks
dip [deg] = path_pitch - min(theta_phys on acq), path_pitch=atan2(0.4,1)
```

## Reproduce stored MAT scores (old first_hold on raw e_th)

| Check | OK? | stored | recomputed |
|------|:---:|-------:|-----------:|
| base acq_s | YES | 15.05 | 15.05 |
| base steady MAE | YES | 0.3320 | 0.3320 |
| base steady p95 | YES | 0.4445 | 0.4445 |
| base dip | YES | 2.9630 | 2.9630 |
| climb acq_s | YES | 3.35 | 3.35 |
| climb steady MAE | YES | 0.1537 | 0.1537 |
| climb steady p95 | YES | 0.5519 | 0.5519 |
| climb dip | YES | 1.7577 | 1.7577 |

## Old vs new scores

### Baseline λ=0 (PITCH_XZ_TRACK.mat m00)

| Metric | old first_hold | new persistent | Δ |
|--------|---------------:|---------------:|--:|
| settling [s] | 15.0500 | 14.0750 | -0.9750 |
| n_acq | 602 | 563 | |
| n_steady | 278 | 318 | |
| n_end (valid) | 880 | 880 | |
| dip [°] | 2.9630 | 2.9630 | +0.0000 |
| acq MAE [°] | 1.0480 | 1.0876 | +0.0396 |
| steady MAE [°] | 0.3320 | 0.3502 | +0.0182 |
| steady RMS [°] | 0.3393 | 0.3595 | +0.0202 |
| steady p95 [°] | 0.4445 | 0.4812 | +0.0367 |
| steady max\\|e\\| [°] | 0.4596 | 0.4984 | +0.0388 |
| persistent_ok | YES | YES | |

### Climb-FF (PITCH_XZ_CLIMB_TRIM_FF.mat)

| Metric | old first_hold | new persistent | Δ |
|--------|---------------:|---------------:|--:|
| settling [s] | 3.3500 | 6.1750 | +2.8250 |
| n_acq | 134 | 247 | |
| n_steady | 681 | 634 | |
| n_end (valid) | 880 | 880 | |
| dip [°] | 1.7577 | 1.7577 | +0.0000 |
| acq MAE [°] | 0.8740 | 0.7549 | -0.1190 |
| steady MAE [°] | 0.1537 | 0.1214 | -0.0323 |
| steady RMS [°] | 0.2307 | 0.1769 | -0.0539 |
| steady p95 [°] | 0.5519 | 0.4039 | -0.1480 |
| steady max\\|e\\| [°] | 0.6695 | 0.4988 | -0.1707 |
| persistent_ok | NO | YES | |

### Exact masks (new persistent)

- BASE: settle_idx=563 t=14.0750s; mask_acq=1:563 (n=563); mask_steady=563:880 (n=318); end_frac=0.88
- CLIMB: settle_idx=247 t=6.1750s; mask_acq=1:247 (n=247); mask_steady=247:880 (n=634); end_frac=0.88

## Climb-FF gates (original) on corrected windows

Reference baseline = rescored λ=0 persistent windows (not published first_hold numbers).

| Metric | baseline new | climb-FF new | Δ% |
|--------|-------------:|-------------:|---:|
| dip [°] | 2.9630 | 1.7577 | -40.7 |
| acq MAE [°] | 1.0876 | 0.7549 | -30.6 |
| settling [s] | 14.08 | 6.18 | -56.1 |
| steady RMS [°] | 0.3595 | 0.1769 | -50.8 |
| steady p95 [°] | 0.4812 | 0.4039 | -16.0 |
| steady MAE [°] | 0.3502 | 0.1214 | -65.3 |

| Gate | Result |
|------|--------|
| dip improve ≥30% OR acq MAE ≥10% | YES (dip 40.7% / acqMAE 30.6%) |
| steady RMS/p95 regression ≤2% | YES (RMS -50.8% / p95 -16.0%) |
| acq settling not worse | YES |
| overshoot not worse | YES |
| sat ≤1% | YES (0.00%) |
| no new chatter | YES |
| **Overall climb-FF** | **PASS** |

Note: published climb-FF report used first_hold settle=3.35 s while |eθ| left ±0.5° at t≈3.52 s; persistent settle=6.18 s. Published-window gate recompute still FAIL (p95 reg +24.2%).

## Evidence

- MATLAB: `run_pitch_xz_window_audit` (rescore only; no CPT)
- C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\PITCH_XZ_WINDOW_AUDIT.md
- C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\PITCH_XZ_WINDOW_AUDIT.mat
- C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\PITCH_XZ_WINDOW_AUDIT.png
- inputs: suite_results/PITCH_XZ_TRACK.mat, PITCH_XZ_CLIMB_TRIM_FF.mat

## Next target

Climb-FF PASS under corrected windows — consider controlled production promote after freeze checklist.
