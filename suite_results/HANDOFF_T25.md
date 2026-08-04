# HANDOFF — Tur 2.5 (paused)

**Paused at:** 2026-08-04 ~04:17 (user request)  
**Project:** `C:\Users\ardak\MATLAB\Projects\AUVsim-main`  
**Branch:** `master` (local)

## Frozen production stack (do not undo)
- `dt_controller = 0.025`
- `dt_guidance = 0.075` (ZOH)
- `Ki_rate = 0`
- `tau_rate = 0.05`
- **Not started yet:** Muw-FF, circle `r_ff = U_h·κ`, XZ flight-path guidance

## Done before pause
### Tur 1–2 (complete)
Commits: `T1A` … `T2B-3` — see `TUR12_SUMMARY.md`  
Chatter largely solved; keep this stack.

### Tur 2.5 (partial)
Commits already on master:
1. `5ea2d7f` — `T25: add pitch bias diagnostic harness (Tests A-D)`
2. `fdda3f2` — `T25.1: recalibrate pitch trim from closed-loop angle-I`
3. `8c5dce3` — `T25.1: update default trim table after closed-loop refine`

Artifacts present (some uncommitted):
- `suite_results/T25_DIAG.md` — decision-tree notes from Tests A–D
- `T25_testA_level.png`, `T25_testB_symmetry.png`, `T25_testC_Ki_ablation.png`, `T25_testD_compare.png`
- `T25_diag_results.mat`, `T25_suite_results.mat`, `T25_verify_trim.txt`
- Suite PNGs + `summary.txt` modified (post-trim suite likely run; **`T25_SUMMARY.md` NOT written yet**)

## Status of 2.5.1 trim
Trim recalibration commits landed (`fdda3f2`, `8c5dce3`). Verify/suite artifacts exist but were **not** finalized into `T25_SUMMARY.md` and diag/suite result files are largely **uncommitted**. Resume by validating whether post-trim acceptance passed; if not, do 2.5.2 Ki_angle (Test C suggested 1.5× helps bias).

## Unfinished when resuming
1. Read `T25_DIAG.md` + `T25_verify_trim.txt` + current `summary.txt` — check acceptance:
   - Level-flight `|mean(e_θ)| < 0.3°`
   - X-line `mean|e_θ| < 0.7°`, chatter ≤ 0.15, CTE not worse >5%
2. If trim alone insufficient: small `Ki_angle` tweak (2.5.2); conditional trim adapt only if still needed (2.5.3).
3. If pure trim OK but X-line still biased → **guidance depth-I**, not more pitch gains.
4. Write `suite_results/T25_SUMMARY.md` and commit remaining untracked `T25_*` + suite figs if results accepted.
5. **Do not** start Tur 3 (Muw-FF) until Tur 2.5 accepted/closed.

## Working tree at pause
```
M  suite_results/01..04_*.png, summary.txt
?? suite_results/T25_DIAG.md, T25_*.png/mat/txt  (no T25_SUMMARY.md yet)
```

## Resume prompt (copy-paste)
> Tur 2.5 kaldığı yerden devam: HANDOFF_T25.md + T25_DIAG.md oku; trim sonrası suite kabul kriterlerini doğrula; gerekirse 2.5.2/2.5.3; T25_SUMMARY yaz ve commit et. Muw-FF yok.

## Next roadmap after T25 closes
Tur 3 Muw verify+FF → Tur 4 circle r_ff → Tur 5 XZ γ/ż guidance
