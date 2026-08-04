# T1B — Multi-rate guidance ZOH vs rate loop

## Changes
- `dt_controller = 0.025`, `dt_guidance = 0.075`, `tau_rate` unchanged (≈0.7118 s)
- `continuous_path_tracking.m`: plant+controller every `dt_controller`; guidance every `round(dt_guidance/dt)` steps with ZOH of yaw/pitch/u/r_ff/pitch_ref_dot
- Guidance integrators/filters advance only on guidance ticks (`dt_guidance`)
- Controller integrators/filters use `dt_controller` every call
- Gains / Ki_rate / Muw: **unchanged**

## T1A → T1B (run1 = run2 identical)

| Scenario | CTE mean T1A→T1B | \|pitch\| T1A→T1B | chatter T1A→T1B |
|----------|------------------|-------------------|-----------------|
| X-line   | 2.053 → **2.057** | 0.50 → **0.48** | 0.525 → **0.501** |
| XZ       | 2.546 → 2.546 | 0.60 → 0.60 | 0.661 → 0.659 |
| Circle   | 1.525 → 1.535 | 0.44 → **0.42** | 0.167 → 0.190 |
| Helix    | 1.686 → **1.673** | 0.33 → 0.32 | 0.194 → 0.201 |

## Acceptance
- Two runs identical: **PASS**
- Path metrics vs T1A: **PASS** (no meaningful CTE regression; pitch slightly better on X)
- Multi-rate stable at dt_c=0.025: **PASS**
- Chatter < 0.20 on X: still **NO** (0.50) — expected with τ preserved; T2 next

## Verdict
**ACCEPT** — use T1B as Tur-1 baseline for T2A/T2B.
