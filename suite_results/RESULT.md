# AUV Path Suite Tuning — Final Result

## Before → After (cascade v1 → this session)

| Scenario | mean CTE | max CTE | mean \|pitch err\| |
|----------|----------|---------|---------------------|
| X-line   | 2.12 → **2.07** m | 10.26 → 10.24 m | 0.16 → 0.50° |
| XZ slant | 4.66 → **2.55** m | 15.34 → **11.99** m | 1.60 → **0.61°** |
| Circle   | 1.71 → **1.53** m | 3.18 → 3.13 m | 0.12 → 0.41° |
| Helix    | 1.66 → 1.67 m | 3.09 → 3.02 m | 0.11 → 0.32° |

**Trim table u=2.0:** FAILED (+24° @ de=-2°) → **OK** (de=-1.25°, θ_phys=+0.48°).

## What changed

1. **`controller_law.m`**: Mid cascade gains + `Kd_damp` on measured pitch rate; heavier rate LPF; no noisy e_rate D.
2. **`guidance_law.m`**: Cold-start `pitch_ref` = path slope (fixes XZ nose-dive); soft depth P+I; faster yaw_ref / χ filter; β crab ×1.35; mild progress hold on large Z lag.
3. **`build_pitch_trim_table.m`**: Coarse→fine search, longer settle, clamp/extrap — u=2.0 now finds level flight.
4. **`run_path_suite(do_calibrate)`**: `false` skips cal for fast iters; final run used full cal.
5. **`init_parameters.m`**: Updated gains + trim seeds from successful search.

## Remaining issues / physical limits

- **Pitch residual chatter (~0.5–1.5° p-p early):** Underactuated pitch + elevator ∝ u² + B>W phugoid; further gain cuts hurt XZ climb.
- **X-line max CTE ~10 m:** Initial depth transient (trim dive vs B>W); mean ~2 m is mostly that start + slow depth I.
- **XZ lag still ~2.5 m mean:** Climb authority ≈ `u·sinθ`; at u≈1.4 and θ≈22° geometry matches path slope, but angle-of-attack / early transient leave a bias that soft depth I only partially clears. Harder depth gain → porpoising (seen in iter2).
- **Circle/helix outward ~1.5–1.7 m:** Persistent yaw lag vs β-augmented yaw_ref; rudder authority (`Nuudr`) and R=5 @ 1.4 m/s limit turn rate. Further β/Kp_ψ mostly inflates yaw-err metric without closing radius much.
- **B=310 > W=305:** Needs continuous nose-down trim / positive pitch_ref on level paths to hold depth.

## Recommend next discussion

Root causes (not more gain thrashing): buoyancy margin, elevator effectiveness vs speed, whether to add stern-plane / thruster depth channel, and whether circle radius or speed should be relaxed for fair path-following.
