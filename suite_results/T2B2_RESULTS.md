# T2B-2 — rate filter tau/4

`tau_rate = tau0/4 ≈ 0.1780 s`

## X-line (T2B-1 → T2B-2)

| Metric | T2B-1 | T2B-2 |
|--------|------:|------:|
| chatter | 0.109 | **0.108** |
| de jitter | 0.469 | **0.401** |
| corr | 0.894 | **0.984** |
| lag est | 0.075 | 0.000 |
| CTE | 2.017 | 2.018 |

Slightly cleaner filter tracking; chatter already saturated near floor. **KEEP / proceed to tens-of-ms**.
