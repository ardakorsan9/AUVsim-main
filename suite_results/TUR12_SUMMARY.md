# Tur 1–2 Summary — AUV Path Following Timing / Rate Loop

## Architecture kept (NOT done)
- **Muw feedforward** — not touched
- **Circle `r_ff = U_actual`** — not touched
- **XZ w/zdot guidance redesign** — not touched
- **Roll control** — not touched
- **Random gain thrashing** — not done (Ki_rate=0 and tau only)

## Baseline to keep
**T1B multi-rate + T2A Ki_rate=0 + T2B-3 tau_rate=0.05 s**

| Param | Value |
|-------|-------|
| `dt_controller` | 0.025 s |
| `dt_guidance` | 0.075 s (ZOH) |
| `tau_rate` | **0.05 s** |
| `Ki_rate` | **0** |
| Other gains | unchanged from pre-Tur cascade |

## Before → After (X-line focus)

| Metric | Pre (dt=0.075) | After Tur12 |
|--------|----------------:|------------:|
| mean CTE | 2.071 m | **2.020 m** |
| mean \|pitch err\| | 0.50° | 1.45° (bias from Ki_rate=0) |
| pitch chatter | ~0.547 °/s (diag) | **0.113 °/s** |
| elevator sat | none | none |

### Full suite CTE / chatter (final T2B-3)

| Scenario | CTE mean | \|pitch\| | chatter |
|----------|----------:|----------:|--------:|
| X-line | 2.020 m | 1.45° | 0.113 |
| XZ | 2.565 m | 0.55° | 0.080 |
| Circle | 1.518 m | 1.01° | 0.062 |
| Helix | 1.682 m | 0.73° | 0.048 |

## Stage log

| Stage | Commit theme | Key result |
|-------|--------------|------------|
| **T1A** | dt=0.0375 single-rate, tau preserved (~0.71 s) | CTE/pitch stable; X chatter still ~0.53 (τ kept) |
| **T1B** | dt_c=0.025, dt_g=0.075 ZOH | Stable multi-rate; slight chatter↓ |
| **T2A** | Ki_rate=0 | X chatter 0.50→0.31; pitch bias↑ |
| **T2B-1** | tau/2 ≈0.36 s | X chatter **0.109** (<0.20) |
| **T2B-2** | tau/4 ≈0.18 s | corr↑; chatter floor |
| **T2B-3** | tau=0.05 s | best lag/corr; keep |

## Recommendation
Keep the final stack above. Next architecture work (when ready): Muw-FF, circle r_ff, XZ guidance — **not** more gain thrashing. Pitch mean-error bias on level paths is the main Ki_rate=0 trade-off; optional later: gentle outer trim / angle-I tune only if needed.
