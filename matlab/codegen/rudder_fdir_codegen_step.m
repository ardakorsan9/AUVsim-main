function [state, out] = rudder_fdir_codegen_step(params, state, in)
%RUDDER_FDIR_CODEGEN_STEP Explicit-state one-step B2 rudder FDIR (fixed ABI).
% DEPLOY_CANDIDATE / NOT_IN_PRODUCTION — isolated runtime; not production path.
% Accepted valid-sample B2 math, warmup, command gate, Np persistence, latch.
% Fail-silent on nonfinite, invalid, or non-increasing seq. rudder_isolated
% is always false (no actuator corroboration; anomaly evidence only).
%
% health_bits (uint32): 1 SAMPLE_INVALID, 2 NONFINITE, 4 SEQ_NONINCREASING,
% 8 CONFIG_INVALID, 16 NOT_INIT. Nonzero => fail-silent.
%
% Constraints: no global/persistent/nargin/assert/error/strings/NaN sentinels.
%
% TASK_ID: RUDDER_FDIR_RUNTIME_001

    t = in.t;
    dr = in.delta_r_cmd;
    r = in.r;
    u = in.u;
    sample_valid = in.sample_valid;
    seq_now = uint32(in.seq);

    hb = uint32(0);
    if ~state.initialized
        hb = bitor(hb, uint32(16));
    end
    if ~params.config_valid
        hb = bitor(hb, uint32(8));
    end
    if ~sample_valid
        hb = bitor(hb, uint32(1));
    end
    if ~(isfinite(t) && isfinite(dr) && isfinite(r) && isfinite(u))
        hb = bitor(hb, uint32(2));
    end
    if state.have_seq && (seq_now <= state.last_seq)
        hb = bitor(hb, uint32(4));
    end

    residual = 0.0;
    g_hat = 0.0;
    valid = false;
    warmed = false;
    gated = false;
    above = false;
    newly_latched = false;

    if hb == uint32(0)
        valid = true;
        warmed = (t > params.t_warmup_s);
        gated = warmed && (abs(dr) > params.eps_dr_rad);

        u_eff = max(u, params.u_floor);
        if abs(dr) > 2.220446049250313e-16
            g_hat = r / (u_eff * u_eff * dr);
            residual = 1.0 - g_hat / params.G_nom;
            if residual < 0.0
                residual = 0.0;
            end
            if ~isfinite(g_hat)
                g_hat = 0.0;
            end
            if ~isfinite(residual)
                residual = 0.0;
            end
        else
            residual = 0.0;
            g_hat = 0.0;
        end

        above = gated && (residual > params.thr_B2);
        if above
            state.persist_count = state.persist_count + 1.0;
        else
            state.persist_count = 0.0;
        end

        if (~state.anomaly_latched) && (state.persist_count >= params.Np)
            state.anomaly_latched = true;
            state.alarm_time_s = t;
            state.alarm_time_valid = true;
            newly_latched = true;
        end

        state.last_seq = seq_now;
        state.have_seq = true;
    else
        state.persist_count = 0.0;
    end

    out = struct();
    out.residual = residual;
    out.g_hat = g_hat;
    out.valid = valid;
    out.warmed = warmed;
    out.gated = gated;
    out.above = above;
    out.persist_count = state.persist_count;
    out.anomaly_latched = state.anomaly_latched;
    out.newly_latched = newly_latched;
    out.alarm_time_s = state.alarm_time_s;
    out.alarm_time_valid = state.alarm_time_valid;
    out.health_bits = hb;
    out.rudder_isolated = false;
end
