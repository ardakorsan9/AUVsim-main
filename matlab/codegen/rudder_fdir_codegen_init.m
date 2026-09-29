function params = rudder_fdir_codegen_init(frozen)
%RUDDER_FDIR_CODEGEN_INIT Build fixed Params from frozen B2 monitor fields.
% DEPLOY_CANDIDATE / NOT_IN_PRODUCTION — isolated explicit-state runtime.
% No isolation claim: B2 is anomaly evidence only.
%
% TASK_ID: RUDDER_FDIR_RUNTIME_001

    G_nom = frozen.G_nom;
    thr_B2 = frozen.thr_B2;
    eps_dr_rad = frozen.eps_dr_rad;
    u_floor = frozen.u_floor;
    t_warmup_s = frozen.t_warmup_s;
    Np = frozen.Np;
    persist_s = frozen.persist_s;
    dt = frozen.dt;

    config_valid = isfinite(G_nom) && (G_nom > 0.0) && ...
        isfinite(thr_B2) && (thr_B2 >= 0.0) && ...
        isfinite(eps_dr_rad) && (eps_dr_rad >= 0.0) && ...
        isfinite(u_floor) && (u_floor >= 0.0) && ...
        isfinite(t_warmup_s) && (t_warmup_s >= 0.0) && ...
        isfinite(Np) && (Np >= 1.0) && ...
        isfinite(persist_s) && (persist_s >= 0.0) && ...
        isfinite(dt) && (dt > 0.0);

    params = struct();
    params.G_nom = G_nom;
    params.thr_B2 = thr_B2;
    params.eps_dr_rad = eps_dr_rad;
    params.u_floor = u_floor;
    params.t_warmup_s = t_warmup_s;
    params.Np = Np;
    params.persist_s = persist_s;
    params.dt = dt;
    params.config_valid = config_valid;
end
