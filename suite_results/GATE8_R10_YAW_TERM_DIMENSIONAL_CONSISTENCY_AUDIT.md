# GATE8_R10_YAW_TERM_DIMENSIONAL_CONSISTENCY_AUDIT_001

**Verdict PASS.** No exact dimensional or duplicate-scaling inconsistency is proved in the yaw command
equation, so **no corrective candidate is stated**. Instead a single coordinated shadow experiment is
declared with predeclared promotion gates. Hardware **NOT_CERTIFIED**. **Gate9 LOCKED**. Nothing promoted.

- created: 2026-08-09 09:21:25
- certification: NOT_CERTIFIED (simulation-only evidence reused; no HIL, no bench, no hardware). Gate9 LOCKED.
- honesty: IMPLEMENTED = this isolated read-only algebraic audit only. Nothing was simulated and nothing was tuned. No gain, law, path, threshold, shaper, current-FF or promotion change was made. No tracking improvement is claimed anywhere in this artifact.

## 0. Erratum, raised by post-run inspection of the figure

One printed number in the generated artifacts is mislabelled. It is recorded here rather than silently
corrected, because the task bounded this work to a single MATLAB invocation with no retry and the artifacts
were therefore not regenerated.

- **What is wrong.** Determination 6 below, and the title of panel 5 in
  `GATE8_R10_YAW_TERM_DIMENSIONAL_CONSISTENCY_AUDIT.png`, both report the **rate**-limiter dwell as
  `0.8908`. That figure is the **magnitude**-limiter dwell, printed twice. The generator computed it as
  `1 - transmitted_fraction`, and `transmitted_fraction` was defined as the fraction of the horizon on
  which the magnitude limiter did *not* clip, so the expression returns the magnitude dwell by construction.
- **The correct value.** The rate-limiter dwell on this horizon is **0.691667** (830 of 1200 samples),
  read from `R.attrib.rate_sat.dwell_frac` in the frozen source record and independently reproducible from
  the `rate_sat_flag` column of the stored log. The magnitude dwell of `0.890833` is itself correct
  everywhere else it appears, including in determinations 5 and 13 and in shadow gate PG3.
- **Blast radius: none on any conclusion.** No hard gate, no determination class, no coefficient recovery,
  no residual, no leave-one-term-out result and no shadow gate consumes this number. It appears only in two
  pieces of descriptive prose. Every quantitative claim in sections 4 through 8 is unaffected, and shadow
  gate PG7 is stated against "the recorded value" rather than against a transcribed constant, so it remains
  well posed.
- **Generator.** `gate8_yaw_term_audit_core.m` and `gate8_fig_main.m` have been corrected to derive the
  rate dwell from the stored `rate_sat_flag` column. The `.mat` and the two `.png` files in this directory
  were produced by the pre-correction generator and still carry the mislabel; regenerating them is deferred
  to the next permitted invocation.

## 1. Bounded scope

Exactly three sources were read. No repo scan. No simulation, no plant call, no resimulation of any kind.
One MATLAB invocation, no retry.

| # | source | role | fingerprint |
|---|---|---|---|
| 1 | `controller_law.m` | READ | production controller: the yaw command equation, its coefficients, limiter order and sample time | `n=9402.s1=732890.s2=3334742186` |
| 2 | `guidance_law.m` | READ | production guidance: the yaw reference chain, the rate feedforward and its units | `n=14601.s1=1095745.s2=3464382495` |
| 3 | `suite_results/GATE8_R10_CLOSED_LOOP_RAIL_ORIGIN_LOCALISATION.mat` | READ | frozen evidence: the stored nominal R10_U1.5 log used for every numerical claim | `n=271512.s1=35429352.s2=2569622525` |

Evidence read: `GATE8_R10_CLOSED_LOOP_RAIL_ORIGIN_LOCALISATION_001`, verdict PASS, cell R10_U1.5, stored nominal hash `n=153600.s1=19094896.s2=2901292177`, reproduced = 1.
That record localised the rail to `S2_CTRL_TERM_P` with origin_kind `AMBIGUOUS` and declared a BLOCKER. This audit does not
overturn that verdict; it explains the multi-term command scale behind it.

## 2. Frames and units

| quantity | frame | internal unit | logged unit |
|---|---|---|---|
| psi, yaw_ref, e_psi | NED heading | rad | deg |
| r, r_ff, e_r | BODY angular rate | rad/s | deg/s |
| p | BODY roll rate | rad/s | deg/s |
| delta_r and every contribution | rudder deflection | rad | deg |
| kappa_f | path curvature | 1/m | 1/m |
| U_h | inertial horizontal speed | m/s | m/s |
| dt_controller / dt_guidance | - | s | s |

yaw command terms are rudder deflections in deg in every table; internally the production law works in rad. Heading quantities are NED, rate quantities are BODY. Ratios are formed in logged units only where numerator and denominator share the same conversion.

Ratios below are formed in logged units. That is legitimate only because numerator and denominator carry
the same angular conversion, and establishing that identity **is** the rad/deg audit.

## 3. The existing yaw command, reconstructed symbolically

```
e_psi   = wrapToPi(yaw_ref - psi)                              [rad]  NED heading error, wrapped once, single application
e_r     = r - r_ff                                             [rad/s] BODY yaw rate minus guidance rate FF
r_ff    = clamp(U_h * kappa_f, +-deg2rad(40))                  [rad/s] = [m/s]*[1/m]; clamp constant is 40 deg/s
dr_yaw  = Kp_psi*e_psi - Kd_psi*e_r                            [rad]  = Kp_psi*e_psi - Kd_psi*r + Kd_psi*r_ff
g_ac    = 1/(1 + (e_psi/e_psi0)^2 + (e_r/e_r0)^2)              [-]    e_psi0=deg2rad(3), e_r0=deg2rad(8)
dr_p    = -Kp_roll*p                                           [rad]  Kp_roll [s] * p [rad/s]
dr_damp = g_ac * dr_p                                          [rad]
dr_raw  = dr_yaw + dr_damp                                     [rad]  sum BEFORE any limiter
dr_mag  = clamp(dr_raw, +-delta_r_max)                         [rad]  STAGE 1: magnitude
delta_r = dr_prev + clamp(dr_mag - dr_prev, +-deg2rad(40)*dt)  [rad]  STAGE 2: rate, dt = dt_controller
ORDER   = magnitude-then-rate, both after the roll damp is summed in
```

| coefficient | value | dimension | where it comes from |
|---|---|---|---|
| Kp_psi | 32 | [-] rad rudder per rad heading error | controller_law.m, global |
| Kd_psi | 13 | [s] rad rudder per rad/s rate error | controller_law.m, global |
| Kp_roll | 0.605072 | [s] rad rudder per rad/s roll rate | controller_law.m default, YAW_ROLL_DAMPING_BACKOFF PASS |
| e_psi0 | deg2rad(3) = 0.052360 | [rad] | controller_law.m, g_ac corner |
| e_r0 | deg2rad(8) = 0.139626 | should be [rad/s] | controller_law.m, g_ac corner |
| delta_r_max | 25 deg | [rad] internally | production parameter recorded in the evidence |
| rate limit | 40 deg/s -> 1 deg/tick | [rad/s] | deg2rad(40)*dt with dt = 0.025 s |
| k_beta | 1.35 | [-] | guidance_law.m crab compensation |
| r_ff clamp | 40 deg/s | [rad/s] | guidance_law.m, never active here |
| Td = Kd_psi/Kp_psi | 0.40625 s | [s] | derived, scale-invariant |

Signs: `+Kp_psi*e_psi`, `-Kd_psi*e_r`, `-Kp_roll*p`, and the feedforward enters with a **plus** because
`-Kd_psi*(r - r_ff)` expands to `-Kd_psi*r + Kd_psi*r_ff`. `e_psi` is wrapped once with `wrapToPi` and used
once. Roll damp is summed **before** both limiters, exactly as the file header declares.

## 4. Coefficient recovery from the stored log

Requirement: each observed contribution divided by its source signal must reproduce the code coefficient
within numerical tolerance wherever observable. Tolerance 1e-09 relative.

| ratio | code coefficient | observed min | observed max | observed median | spread | rel err | observable samples |
|---|---|---|---|---|---|---|---|
| `term_P_deg / e_psi_deg` | 32 | 32 | 32 | 32 | 0 | 0 | 1195 / 1200 |
| `term_D_deg / r_body_degs` | -13 | -13 | -13 | -13 | 7.11e-15 | 2.73e-16 | 1199 / 1200 |
| `term_FF_deg / r_ff_degs` | 13 | 13 | 13 | 13 | 7.11e-15 | 2.73e-16 | 1200 / 1200 |
| `dr_p_deg / p_body_degs` | -0.605072 | -0.605072 | -0.605072 | -0.605072 | 2.22e-16 | 1.83e-16 | 1197 / 1200 |

All four recover with **zero spread**. There is no hidden rad/deg factor, no duplicated conversion and no
second application of any gain on any of the four paths.

## 5. Structural, conversion, schedule and limiter-order identities

| identity | max residual | unit | rms | reading |
|---|---|---|---|---|
| `dr_yaw - (P + D + FF)` | 1.14e-13 | deg | 2.36e-14 | expansion of -Kd_psi*(r - r_ff) into two logged halves is exact |
| `e_r - (r - r_ff)` | 1.78e-15 | deg/s | 7.41e-16 | rate error is a single subtraction in one frame (BODY), no conversion |
| `r_ff - U_h*kappa_f` | 0 | deg/s | 0 | guidance FF chain: [m/s]*[1/m] = [rad/s]; exactly one rad->deg conversion in the log |
| `dr_damp - g_ac*dr_p` | 8.88e-16 | deg | 1.21e-16 | roll damp scheduled once by the dimensionless g_ac |
| `g_ac - 1/(1+(e_psi/3deg)^2+(e_r/8deg/s)^2)` | 2.22e-16 | - | 4.3e-17 | g_ac reproduced with the corner constants read as 3 deg and 8 deg/s: deg2rad on a RATE is numerically correct |
| `dr_raw - (dr_yaw + dr_damp)` | 5.68e-14 | deg | 1.73e-14 | roll damp is summed BEFORE the limiters, as the header comment states |
| `dr_postmag - clamp(dr_raw, +-25)` | 0 | deg | 0 | STAGE 1 limiter is a pure magnitude clamp on the raw sum |
| `dr_postrate - rate_limit(dr_postmag)` | 3.55e-15 | deg | 1.1e-15 | STAGE 2 limiter = 1 deg/tick from deg2rad(40)*dt with dt = 0.025 s |
| `dr_plant - dr_postrate` | 0 | deg | 0 | plant input equals the controller return value: hooks-off nominal cell |

Worst residual over all 9 identities: 1.14e-13. Limiter ordering is magnitude-then-rate and reproduces exactly.

## 6. Duplicate-scaling test battery

| id | statement | outcome |
|---|---|---|
| DS1 | term_P / e_psi returns Kp_psi with zero spread: no hidden rad<->deg factor on the P path | CONSISTENT |
| DS2 | term_D / r returns -Kd_psi with zero spread: no duplicate conversion on the damping path | CONSISTENT |
| DS3 | term_FF / r_ff returns +Kd_psi: the rate FF is applied exactly once, through Kd_psi only | CONSISTENT |
| DS4 | dr_p / p returns -Kp_roll: roll coupling carries one gain and one schedule | CONSISTENT |
| DS5 | r_ff = U_h*kappa_f exactly: no second speed factor, the retired 1.15*u_ref is absent | CONSISTENT |
| DS6 | g_ac reproduced from 3 deg and 8 deg/s corners: deg2rad applied to a rate is numerically exact | CONSISTENT |
| DS7 | limiter order magnitude-then-rate reproduced, roll damp inside both | CONSISTENT |
| DS8 | e_psi wrapped exactly once and used once | CONSISTENT |

**Dimensional or duplicate-scaling inconsistencies proved: 0 of 8.**

## 7. Envelope excess ledger

| term | peak [deg] | x envelope | median [deg] | x envelope | reaches 25 deg alone |
|---|---|---|---|---|---|
| P | 434.5376 | 17.4 | 156.0755 | 6.24 | 1 |
| D | 197.7222 | 7.91 | 137.7224 | 5.51 | 1 |
| FF | 123.3455 | 4.93 | 114.1767 | 4.57 | 1 |
| ROLLDAMP | 6.2432 | 0.25 | 0.5336 | 0.0213 | 0 |
| RAW_SUM | 466.6729 | 18.7 | 129.8066 | 5.19 | 1 |

## 8. Leave-one-term-out attribution, stored raw command only

This is algebra on the stored signals. Nothing is resimulated and no tracking effect is claimed.

### 8a. As logged, four contributions

| term | peak [deg] | median [deg] | signed share at rail | removal changes limited cmd | max change [deg] | rms change [deg] | saturation flips |
|---|---|---|---|---|---|---|---|
| P | 434.5376 | 156.0755 | +1.3114 | 822 / 1200 | 50 | 34.23 | 302 |
| D | 197.7222 | 137.7224 | -0.8813 | 384 / 1200 | 50 | 21.9 | 158 |
| FF | 123.3455 | 114.1767 | +0.5326 | 307 / 1200 | 50 | 17.23 | 173 |
| ROLLDAMP | 6.2432 | 0.5336 | -0.0007 | 131 / 1200 | 6.243 | 0.5225 | 1 |

### 8b. Physically grouped, three contributions

`term_D` and `term_FF` are the two halves of the single term `-Kd_psi*(r - r_ff)`. Regrouping them is not
cosmetic: term_D and term_FF are the two halves of the single physical term -Kd_psi*(r - r_ff). They oppose each other on 0.9183 of the horizon, so counting them as two independent contributions inflates the number of terms that reach the envelope alone.

| term | peak [deg] | median [deg] | signed share at rail | removal changes limited cmd | reaches envelope alone |
|---|---|---|---|---|---|
| P | 434.5376 | 156.0755 | +1.3114 | 822 / 1200 | 1 |
| RATE_ERR | 189.2906 | 54.6439 | -0.3151 | 238 / 1200 | 1 |
| ROLLDAMP | 6.2432 | 0.5336 | -0.0007 | 131 / 1200 | 0 |

Grouped completeness residual 1.71e-13 deg. Under the grouped decomposition the dominant term is unambiguous
(the proportional term, signed share +1.3114 of the raw command at rail samples), while the rate term still
reaches the envelope on its own during the limit-cycle ripple. The rail therefore remains multi-term, which
is consistent with the frozen record's AMBIGUOUS finding, but part of its "3 of 4 terms rail alone" count is
a decomposition artifact rather than three independent physical drivers.

## 9. Determinations

### 1. rad/deg conversion on every yaw term

**NO_DEFECT_CONSISTENT.** each observed contribution divided by its source signal reproduces the code coefficient with zero spread: Kp_psi 32, -Kd_psi -13, +Kd_psi 13, -Kp_roll -0.605072; worst relative error over the four 2.73e-16. The command is formed in rad and logged in deg exactly once.

### 2. yaw-rate feedforward r_ff = U_h*kappa_f and its single application through Kd_psi

**NO_DEFECT_CONSISTENT.** r_ff reproduces U_h*kappa_f to 0 deg/s; [m/s]*[1/m] = [rad/s] is correct and the retired 1.15*u_ref factor is absent. The FF enters only as +Kd_psi*r_ff inside -Kd_psi*(r - r_ff), so its gain is not independently settable: FF authority is structurally tied to the damping gain. That coupling is a design choice, and in the steady turn it is correct: r_ff median 8.94 deg/s against the kinematic U*kappa of 8.955 deg/s.

### 3. proportional gain magnitude Kp_psi = 32 [-] against a 25 deg rudder envelope

**TUNING_CHOICE.** dimensionally self-consistent: rad in, rad out, dimensionless gain. It is the scale that is extreme: a heading error of 0.7812 deg alone reaches the envelope, i.e. 0.2604 of the g_ac corner e_psi0 = 3 deg. At the corner the code itself declares, Kp_psi*e_psi0 = 96 deg = 3.84x the envelope. The observed sustained median heading error 5.19 deg yields term_P = 166.1 deg = 6.64x the envelope.

### 4. damping gain Kd_psi = 13 s and the split of -Kd_psi*(r - r_ff) into two logged halves

**TUNING_CHOICE.** Kd_psi carries the correct dimension [s]. The two logged halves are individually large (median |term_D| 137.7 deg, |term_FF| 114.2 deg) but oppose each other on 0.9183 of the horizon, so their sum has median magnitude only 54.64 deg. Counting them as two independent contributions overstates how many terms reach the envelope alone. Under the grouped decomposition the rate term still reaches the envelope during the limit-cycle ripple: Kd_psi times the sustained yaw-rate standard deviation 5.771 deg/s is 75.02 deg.

### 5. roll coupling: Kp_roll [s] and the dimensionless g_ac schedule

**COUPLED_SATURATION.** g_ac_median * transmitted_fraction = 0.0266411: the roll-rate damp is attenuated 4.1x by its own scheduler and then algebraically discarded by the magnitude limiter on 0.8908 of the horizon. It is implemented exactly as the header comment declares (summed before the limiters) but its authority is consumed by saturation created by the yaw terms.

### 6. limiter ordering: magnitude then rate, roll damp summed before both

**NO_DEFECT_CONSISTENT.** both stages reproduce exactly (0 deg and 3.55e-15 deg residual) and the order matches the header comment. The rate stage allows 1 deg per tick from deg2rad(40)*dt with dt = 0.025 s; realized slew is pinned at the 40 deg/s envelope, and the rate stage clips on 0.8908 of the horizon.
*(See section 0: `0.8908` here is the magnitude-limiter dwell. The rate-limiter dwell is `0.691667`. The
statement about limiter order and the 1 deg per tick allowance is unaffected.)*

### 7. g_ac corner constants written as deg2rad(3) and deg2rad(8), the second applied to a rate

**NO_DEFECT_LABELLING_ONLY.** e_r0 = deg2rad(8) converts an angle but is compared against a rate. Since deg->rad and (deg/s)->(rad/s) share the same factor the number is correct as 8 deg/s, and g_ac reproduces from the 3 deg and 8 deg/s reading to 2.22e-16. The defect is in the naming only and has no numerical consequence.

### 8. BODY yaw rate r used directly in the damping term instead of the Euler heading rate

**EXACT_FRAME_ASYMMETRY_BOUNDED.** controller_law.m converts BODY rates to the physical PITCH rate explicitly (theta_phys_dot = -q*cos(phi) + r*sin(phi)) but feeds BODY r straight into the yaw damping term, where the Euler heading rate is psi_dot = (q*sin(phi) + r*cos(phi))/cos(theta). Both are [rad/s], so this is a FRAME asymmetry, not a unit error. Bounded here at |cos(phi)/cos(theta) - 1| <= 0.003262, i.e. <= 0.6449 deg on term_D. The q*sin(phi)/cos(theta) cross term cannot be bounded: q is not in the stored log.

### 9. sample-time assumption: dt-implicit guidance filters and the multirate reference

**UNAVAILABLE_PROVENANCE.** yaw_ref is republished every dt_guidance = 0.075 s and held; the log samples it every dt_controller = 0.025 s. Differencing the held signal at the controller rate inflates the apparent reference rate by dt_guid/dt_ctrl = 3x. The stored 105.414 deg/s is therefore NOT comparable with the guidance 40 deg/s slew cap; over the true dt_guidance interval the same increment is 35.1379 deg/s, inside the cap. Separately, every guidance smoother is a fixed-alpha recursion (chi_f 0.28, kappa_f 0.96/0.04, yaw_out 0.35) whose time constant scales with dt_guidance, unlike controller_law.m which pins its pitch-rate filter to a physical tau via exp(-dt/tau). The dt at which those alphas were chosen is not recorded in any permitted source, so the realized versus intended bandwidth cannot be settled here.

### 10. declared units of Kp_psi and Kd_psi

**UNAVAILABLE_PROVENANCE.** ADMISSIBLE_BUT_UNPROVED. A single rad->deg de-scaling (0.0174533) satisfies the envelope test (raw absmax would be 8.145 deg < 25 deg) but drives the median proportional authority to 2.898 deg, BELOW the recorded plant steady-turn requirement of 4.058 deg. The stored data therefore neither proves nor refutes it. The declared unit of Kp_psi and Kd_psi is set in continuous_path_tracking.m, outside the three permitted sources. Kd_psi/Kp_psi = 0.40625 s is a derivative time constant and is invariant under any common mis-scaling of the pair, so the gain ratio cannot discriminate a units defect from a tuning choice. This is why the ratio test is reported as non-discriminating rather than as evidence.

### 11. cfg_used.k_psi = 1.2 carried inside the frozen record

**UNAVAILABLE_PROVENANCE.** the record carries a configuration block whose heading gain is 1.2, but the logged command reproduces the production Kp_psi = 32 exactly, so cfg_used.k_psi is not the gain that produced this log. Which subsystem consumes it cannot be established: the harness is outside the three permitted sources.

### 12. crab compensation k_beta = 1.35 in the yaw reference

**TUNING_CHOICE.** the kinematically exact crab inverse is k_beta = 1, since course = heading + sideslip. k_beta = 1.35 injects a standing -(k_beta-1)*beta into the heading error that an integral-free rudder channel cannot null. In this cell the sideslip is small (|beta| absmax 2.421 deg, sustained median -0.7261 deg), so this contributes only about 0.2541 deg of the 5.19 deg sustained heading error: it is real but it is not the dominant mechanism here.

### 13. dominant mechanism of the multi-term command scale

**EVIDENCED_MECHANISM_NOT_A_DEFECT.** On a constant-curvature path a lookahead course reference leads the achieved heading by L_eff*kappa radians ([m]*[1/m] = [rad]); that offset is geometric and cannot be nulled by the rudder channel, which carries no integral state. The recovered L_eff = 0.9158 m is consistent with the guidance floor L = max(lookahead_distance, 1.0) m attenuated by the chi_f course filter; lookahead_distance itself is set outside the three permitted sources. The recovered geometric offset times the proportional gain, Kp_psi*L_eff*kappa, accounts for the observed sustained term_P of 166.1 deg (predicted 166.1 deg), which is 6.64x the envelope on its own. The plant needs only 4.058 deg of rudder to hold this circle. The channel is therefore a relay: the magnitude limiter clips 0.8908 of the horizon and the loop still holds cross-track to 0.2126 m, so the rail is not a tracking failure and no tracking claim is made either way.

## 10. Why no corrective candidate is stated

No corrective candidate is stated. The rule was predeclared: a candidate is permitted only if exactly one EXACT dimensional or duplicate-scaling inconsistency is proved. 0 were proved. All four yaw coefficients, the feedforward chain, the g_ac schedule and the limiter order reproduce the code exactly from the stored log, so the multi-term command scale is a tuning and architecture property, not a units bug.

The strongest single-factor hypothesis was evaluated rather than assumed:

- ADMISSIBLE_BUT_UNPROVED. A single rad->deg de-scaling (0.0174533) satisfies the envelope test (raw absmax would be 8.145 deg < 25 deg) but drives the median proportional authority to 2.898 deg, BELOW the recorded plant steady-turn requirement of 4.058 deg. The stored data therefore neither proves nor refutes it. The declared unit of Kp_psi and Kd_psi is set in continuous_path_tracking.m, outside the three permitted sources.
- Kd_psi/Kp_psi = 0.40625 s is a derivative time constant and is invariant under any common mis-scaling of the pair, so the gain ratio cannot discriminate a units defect from a tuning choice. This is why the ratio test is reported as non-discriminating rather than as evidence.

## 11. Declared coordinated shadow experiment

**GATE8_R10_YAW_AUTHORITY_COORDINATED_SHADOW_SWEEP**

- why coordinated: Kd_psi/Kp_psi = 0.40625 s is the only dimensionally meaningful invariant recoverable without external provenance, and the feedforward gain is structurally equal to Kd_psi. Scaling either gain alone therefore changes the derivative time constant and the feedforward authority at the same time, which would confound the result. The sweep must scale the pair together at fixed Td.
- scope: exactly one cell, the frozen R10_U1.5 (index 7 of 8), exactly one nominal horizon of 30 s at dt = 0.025 s, hooks off, no Monte Carlo, no second family. Shadow only: the sweep runs against a shadow copy of the law with production files fingerprinted unchanged.
- factor: s, a single common scale applied to (Kp_psi, Kd_psi) as (s*32, s*13), Td held at 0.40625 s
- anchor provenance: every anchor is derived from stored evidence or from a constant already present in the two permitted source files. No anchor is invented and none is a tuned guess.
- caveat: the headroom anchor is algebra on the stored raw command. Changing the gains changes the trajectory, so it is an entry bracket, NOT a prediction of the closed-loop result. The sweep exists precisely because the saturated log cannot identify the right scale: the heading error that sets the command is itself produced by the saturated loop.
- smallest-experiment argument: this is the smallest experiment that can settle the question: one cell, one horizon, one scalar factor, four predeclared points, no new law, no new signal, no shaper, no current feedforward, and every gate computable from the same instrumentation that already exists in the frozen record.

Predeclared anchors:

1. s = 1.000000 : frozen control, must reproduce the stored nominal hash n=153600.s1=19094896.s2=2901292177 bit-for-bit
2. s = 0.260417 : design-point anchor, makes Kp_psi*e_psi0 equal the 25 deg envelope at the g_ac corner the code declares
3. s = 0.053571 : headroom anchor, the algebraic scale at which the STORED raw command peak fits the envelope
4. s = 0.017453 : unit-conversion anchor, a single rad->deg de-scaling, admissible but unproved

Observables to be logged with units, frames and provenance:

- per-term absmax and median against the envelope, for P, the grouped rate term and the roll damp
- magnitude-limiter dwell, rate-limiter dwell, rail dwell, realized slew
- g_ac distribution, and the fraction of the horizon on which the roll damp is transmitted rather than clipped
- sustained heading error, sideslip, and the recovered L_eff*kappa geometric offset
- signed cross-track and depth error, reported as measurements only

### Predeclared promotion gates

| id | requirement |
|---|---|
| PG1 | at s = 1 the shadow reproduces the frozen nominal cell bit-for-bit against hash n=153600.s1=19094896.s2=2901292177. Any mismatch voids the whole sweep. |
| PG2 | the candidate scale drives |dr_raw| absmax <= 25 deg over the full horizon, i.e. the magnitude limiter never engages, measured not assumed. |
| PG3 | magnitude-limiter dwell = 0 and rail dwell = 0, against the recorded 0.890833 and 0.281667. |
| PG4 | standing authority preserved: median |delta_r| >= the recorded plant steady-turn requirement of 4.058 deg, so the de-scaled loop can still hold the R10 circle. This gate is what refutes the unit-conversion anchor if it fails. |
| PG5 | path following no worse than the frozen record: |cte| absmax <= 0.212619 m and median <= 0.100242 m. Declared in advance as a gate, not claimed in advance as a result. |
| PG6 | roll-damp authority restored: the roll damp is transmitted to the plant on >= 0.95 of the horizon, against 0.109167 now. |
| PG7 | rate-limiter dwell strictly below the recorded value and realized slew strictly below the 40 deg/s envelope. |
| PG8 | the rail must not merely migrate: at the candidate scale no single term of the grouped decomposition {P, -Kd*(r-r_ff), g_ac*(-Kp_roll*p)} may reach the envelope alone. |
| PG9 | production, plant, metrics and CODEX_VERTICAL_PLAN fingerprints unchanged pre and post; footprint < 100 MiB; one MATLAB invocation; no retry. |
| PG10 | NO promotion on this sweep even if every gate passes. Promotion additionally requires a second independent cell family and a disturbance case, and Gate9 stays locked with hardware NOT_CERTIFIED. |

### Falsifiers declared in advance

- if PG2 passes but PG4 fails at every anchor, the gain scale is not the binding constraint and the finding is that the guidance geometric offset must be reduced instead, which is a different and larger change
- if PG2 and PG4 both pass only at the unit-conversion anchor, that is the first real evidence for a units defect and the provenance question must then be reopened with the parameter-setting file in scope
- if PG8 fails, the rail is genuinely multi-term and no scalar rescaling can be the answer

## 12. Hard gates for this audit

| id | pass | requirement | detail |
|---|---|---|---|
| HL1 | PASS | exactly three sources read and fingerprinted, no repo scan drove any claim | n=9402.s1=732890.s2=3334742186 | n=14601.s1=1095745.s2=3464382495 | n=271512.s1=35429352.s2=2569622525 |
| HL2 | PASS | the yaw command equation is reconstructed symbolically with every coefficient, schedule, sign, wrap, sample time, frame and unit | 11 equation lines, 10 coefficients transcribed, frames and units declared per term |
| HL3 | PASS | every observable contribution divided by its source signal reproduces the code coefficient within 1e-09 relative | worst relative error 2.73e-16 over 4 coefficients, worst spread 7.11e-15 |
| HL4 | PASS | conversion, schedule, wrap and limiter-order residuals all within 1e-09 | worst residual 1.14e-13 over 9 structural identities |
| HL5 | PASS | leave-one-term-out attribution performed algebraically on the stored raw command only, in both the split and the physically grouped decomposition | grouped completeness residual 1.71e-13 deg; no resimulation, no plant call, no tracking claim |
| HL6 | PASS | every audited item carries exactly one determination among exact defect, tuning choice, unavailable provenance and coupled saturation | 13 items classified |
| HL7 | PASS | a corrective candidate is stated if and only if exactly one exact dimensional or duplicate-scaling inconsistency is proved | proved = 0, candidate stated = 0, shadow experiment declared = 1 |
| HL8 | PASS | the declared shadow experiment is coordinated, single-cell and carries predeclared promotion gates with falsifiers | 10 predeclared gates, 4 anchors, 3 falsifiers, one cell |
| HL9 | PASS | derived log appended once with units, frames and per-column provenance | 1200 x 15 derived log, 15 units, 15 provenance strings, frames struct carried from the frozen record |
| HL10 | PASS | no gain, law, path, threshold, shaper or current-FF edit; production, plant, metrics, CODEX_VERTICAL_PLAN and the frozen evidence unchanged | 7/7 fingerprints identical pre and post |
| HL11 | PASS | no promotion, hardware NOT_CERTIFIED, Gate9 locked, no tracking improvement claimed | declared in the header, the honesty field and the shadow gate PG10 |

## 13. Appended log, units and provenance

Derived log appended once: 1200 rows x 15 columns.

| # | column | unit | provenance |
|---|---|---|---|
| 1 | `t` | s | STORED_LOG | simulation time, copied unchanged |
| 2 | `e_psi_deg` | deg | STORED_LOG | CONTROLLER_PUBLISHED wrapped heading error, NED |
| 3 | `term_P_deg` | deg | STORED_LOG | Kp_psi*e_psi, rudder deg |
| 4 | `term_D_deg` | deg | STORED_LOG | -Kd_psi*r, rudder deg, BODY yaw rate |
| 5 | `term_FF_deg` | deg | STORED_LOG | +Kd_psi*r_ff, rudder deg, guidance rate FF |
| 6 | `term_RATE_ERR_deg` | deg | AUDIT_DERIVED | term_D + term_FF = -Kd_psi*(r - r_ff), the single physical rate-error term |
| 7 | `dr_damp_deg` | deg | STORED_LOG | g_ac*(-Kp_roll*p), rudder deg, BODY roll rate |
| 8 | `dr_raw_deg` | deg | STORED_LOG | dr_yaw + dr_damp before any limiter, rudder deg |
| 9 | `dr_postmag_recon_deg` | deg | AUDIT_DERIVED | magnitude clamp recomputed from dr_raw at the recorded 25 deg envelope |
| 10 | `dr_plant_deg` | deg | STORED_LOG | HARNESS_OBSERVED value handed to the plant, rudder deg |
| 11 | `beta_deg` | deg | AUDIT_DERIVED | atan2(v_body, max(u_body,0.35)) from stored BODY velocities, the guidance definition |
| 12 | `kappa_f_invm` | 1/m | STORED_LOG | GUIDANCE_PUBLISHED filtered path curvature |
| 13 | `L_eff_instant_m` | m | AUDIT_DERIVED | e_psi[rad]/kappa, the implied lookahead lead; [rad]/[1/m] = [m] |
| 14 | `mag_sat_flag` | - | AUDIT_DERIVED | 1 when the magnitude limiter clipped, from the stored flag |
| 15 | `rail_flag` | - | AUDIT_DERIVED | 1 when the plant input sits at the envelope, from the stored flag |

## 14. Preservation and visual QA

- fingerprints unchanged pre and post: 1 (production law, plant, metrics, CODEX_VERTICAL_PLAN and the frozen evidence mat are byte-identical pre and post: the audit only read them.)
  - `continuous_path_tracking.m` : `n=10845.s1=886194.s2=515073390`
  - `controller_law.m` : `n=9402.s1=732890.s2=3334742186`
  - `guidance_law.m` : `n=14601.s1=1095745.s2=3464382495`
  - `underwater777_vehicle_dynamics.m` : `n=6065.s1=426918.s2=1254438441`
  - `compute_path_following_metrics.m` : `n=11604.s1=883372.s2=792990739`
  - `suite_results/CODEX_VERTICAL_PLAN.md` : `n=43101.s1=4310210.s2=3268810005`
  - `suite_results/GATE8_R10_CLOSED_LOOP_RAIL_ORIGIN_LOCALISATION.mat` : `n=271512.s1=35429352.s2=2569622525`
- visual QA: **VISUAL_QA_PASS**, 2/2 files ok, 9/9 checks pass
- visual QA is programmatic: every figure written is re-opened with imfinfo, its pixel size and file size are checked, and a set of content checks is evaluated against the numbers actually plotted. No human eyeball is claimed. The self panel is necessarily measured after it is written, so its own row is recorded in the .mat and in this markdown rather than inside the panel image.

| check | pass | detail |
|---|---|---|
| files_written | 1 | 2/2 PNG files exist, exceed 8 KiB and are at least 600x400 px |
| coefficients_panel_populated | 1 | 4 recovered coefficients, worst relative error 2.73e-16 |
| residual_panel_populated | 1 | 9 structural identities, worst residual 1.14e-13 |
| ledger_axis_covers_envelope | 1 | raw peak 466.7 deg plotted against the 25 deg envelope line |
| loto_both_decompositions_plotted | 1 | split (4 terms) and grouped (3 terms) leave-one-term-out bars both present |
| limiter_chain_monotone_in_magnitude | 1 | raw 466.7 deg -> envelope 25 deg -> sustained median plant input 18 deg |
| anchor_panel_spans_evidence | 1 | anchors ordered s_unit 0.0174533 < s_env 0.0535707 < s_dp 0.260417 < 1 |
| no_promotion_banner | 1 | NOT_CERTIFIED and Gate9 LOCKED printed on the figure and in the markdown |
| verdict_consistent_with_gates | 1 | hard gate table evaluated before the verdict was written |

| figure | KiB | pixels | ok |
|---|---|---|---|
| `suite_results/GATE8_R10_YAW_TERM_DIMENSIONAL_CONSISTENCY_AUDIT.png` | 321.0 | 2025x1575 | 1 |
| `suite_results/GATE8_R10_YAW_TERM_DIMENSIONAL_CONSISTENCY_AUDIT_02_visual_qa.png` | 248.3 | 2025x1575 | 1 |

## 15. Closing statement

The yaw command equation is dimensionally self-consistent everywhere it can be checked against the stored
log: four coefficients recovered with zero spread, one wrap, one conversion per path, the feedforward chain
exact, the schedule exact, and the limiter order exact. The rail therefore does **not** come from a units
bug or a duplicated scaling. It comes from a geometric standing heading offset of order L*kappa on a curved
path multiplied by a large integral-free proportional gain, with the roll-damp channel losing its authority
to the resulting saturation. That distinction is exactly why a corrective edit is withheld and a bounded
coordinated shadow sweep with predeclared gates is declared instead.

No gain, law, path, threshold, shaper or current-feedforward change was made. No tracking improvement is
claimed. Hardware NOT_CERTIFIED. Gate9 LOCKED. Nothing is promoted.
