# RUDDER_FDIR_RUNTIME_CONTRACT_V1

Implement exactly three fixed-shape MATLAB Coder entry files:

```text
params = rudder_fdir_codegen_init(frozen)
state = rudder_fdir_codegen_reset(params)
[state,out] = rudder_fdir_codegen_step(params,state,in)
```

`frozen`/`params`: `G_nom,thr_B2,eps_dr_rad,u_floor,t_warmup_s,Np,persist_s,dt` plus `config_valid`.

`in`: scalar `t,delta_r_cmd,r,u`, logical `sample_valid`, `uint32 seq`.

`out` fields exactly: `residual,g_hat,valid,warmed,gated,above,persist_count,anomaly_latched,newly_latched,alarm_time_s,alarm_time_valid,health_bits,rudder_isolated`.

Preserve accepted valid-sample B2 math, warmup, command gate, `Np` persistence and latch-until-reset from `isolated_online_rudder_residual_monitor.m`. Nonfinite, invalid or non-increasing sequence input is fail-silent: finite zero residual/gain outputs, nonzero `uint32 health_bits`, persistence streak reset, existing latch retained. `rudder_isolated` is always false because B2 without actuator corroboration is anomaly evidence only.

All state is explicit. No strings, `assert`, `error`, globals, persistent data, NaN sentinels or dynamic containers.
