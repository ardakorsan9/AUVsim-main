# AGENT_HANDOFF — AUV path following

**Updated:** 2026-08-05 01:30
**Owner now:** Cursor (pitch closure + yaw start done)
**Paused / later:** R=5 speed, roll, LQI/SMC/NMPC, autonomy/AI

## Production freeze (do not thrash)
- `dt_c=0.025`, `dt_g=0.075`, `tau_rate=0.05`, `Ki_rate=0`, `Ki_angle=0.16`
- `lambda_muw_ff=0.25` base, Tur4A `r_ff=U_h*κ`, T25 trim
- Production guidance: `K_gamma=0`, `K_zdot=0`
- **Pitch gains FROZEN** — do not retune; XZ steady `|eθ|≈0.39°` in gate

## DONE (skip)
- Tur1–5 / metric rescore / elevator pulse plant table
- Pitch closure acq/steady + λ A/B → `PITCH_CLOSURE.md`
- Yaw start R=7.5/10 → `YAW_START.md` (|eψ| already ~0.2–0.3°)

## Pitch snapshot
- X `|eθ|≈0.06°` | XZ steady λ=0.25: **0.388°** | λ=0: **0.332°**
- λ=0 better on climb CTE/elev effort → **NEXT scheduled λ** (level 0.25 / climb 0); not implemented
- Historical 1.44° suite pitch = acquisition; steady OK

## Yaw snapshot (R=7.5 / 10)
- R=7.5: `|eψ|=0.31°` r/(Uhκ)=1.030 sat=0% CTE_perp=**1.315** (radial open)
- R=10: `|eψ|=0.16°` r/(Uhκ)=1.018 sat=0% CTE_perp=0.284
- Suite ~35° was **R=5**, not unwrap on feasible circles

## NOW
1. R=7.5 radial / `CTE_perp` (not yaw gains)
2. Helix true-metric check
3. R=5 speed scheduler only after R=7.5 radial clean
4. Optional: tiny climb λ schedule (<30 lines)

## SKIP
- Full 32 matrix, LQI/A,B ID, pitch gain sweep, Ki_rate reopen

## Paths
- Project: `C:\Users\ardak\MATLAB\Projects\AUVsim-main`
- Results: `...\suite_results\`
- MATLAB: `D:\ardak\matlab\bin\matlab.exe`
