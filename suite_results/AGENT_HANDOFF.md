# AGENT_HANDOFF — AUV path following

**Updated:** 2026-08-04 20:25  
**Owner now:** Cursor (implement done — plant table)  
**Paused / later:** yaw smoothness, R=5 speed, roll, LQI/SMC/NMPC, autonomy/AI

## Production freeze (do not thrash)
- `dt_c=0.025`, `dt_g=0.075`, `tau_rate=0.05`, `Ki_rate=0`, `Ki_angle=0.16`
- `lambda_muw_ff=0.25`, Tur4A `r_ff=U_h*κ`, T25 trim
- Production guidance: `K_gamma=0`, `K_zdot=0` (T5 experimental only)
- Pitch accepted as “good enough for now” — do not retune pitch gains

## DONE (skip)
- Tur1–2 timing / Ki_rate / filter
- Tur2.5 trim bias
- Tur3 Muw FF λ=0.25
- Tur4A U_h κ (R=5 = rudder limit; no 4B)
- Tur5A/B on inflated CTE (invalid gates)
- True metrics: `CTE_perp`, settled_before_end, path extend
- Rescore: XZ CTE_perp baseline ~0.75, T5A/B ~0.55 (mid target missed)

## DONE (this handoff)
- **Lean elevator pulse / NMP audit** → `suite_results/PLANT_VERTICAL_TABLE.md`
  - u=1.5/2.0: no inverse/NMP; order `δe→M_e→q→w→θ→ż→z`; delay ≤0.025 s; Muw λ=0.25 **neutral**
  - u=0.8: **constraint/envelope** (δe near limit)
  - Verdict: **keep cascaded**; envelope before LQI; do not start LQI/yaw/roll yet

## NOW
1. Act on plant table if needed (mild envelope / FF schedule only — not pitch gain thrash)
2. Otherwise resume deferred horizontal work when owner switches

## SKIP for now (user OK)
- Full 32-condition matrix
- Controllability Gramian / full A,B ID (unless pulse inconclusive)
- Yaw ref smoothness, R=5 speed scheduler, roll, depth channel, LQI/SMC/NMPC, AI autonomy

## Later roadmap
1. Envelope / mild guidance if required by plant table
2. Yaw smoothness
3. R=5 curvature-aware speed if required
4. Roll / speed / depth channels
5. Autonomy / AI later

## Paths
- Project: `C:\Users\ardak\MATLAB\Projects\AUVsim-main`
- Results: `...\suite_results\`
- MATLAB: `D:\ardak\matlab\bin\matlab.exe`
