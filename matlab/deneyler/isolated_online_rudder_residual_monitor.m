function varargout = isolated_online_rudder_residual_monitor(op, varargin)
%ISOLATED_ONLINE_RUDDER_RESIDUAL_MONITOR  Causal stateful B2 rudder-health monitor.
%
% Primary residual (deployable sensor-only B2):
%   g_hat = r_IMU / (max(u_DVL, u_floor)^2 * delta_r_cmd)
%   r_B2  = max(0, 1 - g_hat / G_nom)     [dimensionless frac-loss proxy]
%
% Inputs only: known delta_r_cmd [rad], IMU yaw rate r [rad/s], DVL surge u [m/s].
% FORBIDDEN: applied rudder, effectiveness, fault labels, INS xy / B1.
%
% API
%   mon = isolated_online_rudder_residual_monitor('init', frozen)
%   [mon, out] = isolated_online_rudder_residual_monitor('update', mon, sample)
%   mon = isolated_online_rudder_residual_monitor('reset', mon)
%   st  = isolated_online_rudder_residual_monitor('state', mon)
%
% sample fields: .t [s], .delta_r_cmd [rad], .r [rad/s], .u [m/s]
% frozen fields (from feasibility MAT, no retune):
%   G_nom, thr_B2, eps_dr_rad, u_floor, t_warmup_s, Np, persist_s, dt
%
% Units: residual dimensionless; G_nom in 1/(m^2·rad); angles rad; rates rad/s.
% Warmup (t<=t_warmup): no detection, counter held at 0, residual still computed
%   when finite. Gate |delta_r_cmd|<=eps_dr: residual may be NaN/0, counter reset.
% NaN/dropout on any input: residual=NaN, gated=false, counter reset, no latch.
% Alarm: persistence Np consecutive gated exceedances, then LATCHED until reset.

    op = lower(string(op));
    switch op
        case "init"
            varargout{1} = local_init(varargin{1});
        case "update"
            [mon, out] = local_update(varargin{1}, varargin{2});
            varargout{1} = mon;
            varargout{2} = out;
        case "reset"
            varargout{1} = local_reset(varargin{1});
        case "state"
            varargout{1} = local_state(varargin{1});
        otherwise
            error('isolated_online_rudder_residual_monitor:badOp', ...
                'Unknown op="%s". Use init|update|reset|state.', op);
    end
end

%% ------------------------------------------------------------------------
function mon = local_init(frozen)
    req = {'G_nom','thr_B2','eps_dr_rad','u_floor','t_warmup_s','Np','persist_s','dt'};
    for i = 1:numel(req)
        assert(isfield(frozen, req{i}), 'frozen.%s required', req{i});
    end
    assert(frozen.G_nom > 0 && isfinite(frozen.G_nom), 'G_nom must be finite > 0');
    assert(frozen.thr_B2 >= 0 && isfinite(frozen.thr_B2), 'thr_B2 invalid');
    assert(frozen.Np >= 1, 'Np must be >= 1');

    mon = struct();
    mon.cfg = struct();
    mon.cfg.G_nom = double(frozen.G_nom);
    mon.cfg.thr_B2 = double(frozen.thr_B2);
    mon.cfg.eps_dr_rad = double(frozen.eps_dr_rad);
    mon.cfg.u_floor = double(frozen.u_floor);
    mon.cfg.t_warmup_s = double(frozen.t_warmup_s);
    mon.cfg.Np = double(frozen.Np);
    mon.cfg.persist_s = double(frozen.persist_s);
    mon.cfg.dt = double(frozen.dt);
    mon.cfg.channel = 'B2';
    mon.cfg.units = struct( ...
        'delta_r_cmd', 'rad', ...
        'r', 'rad/s', ...
        'u', 'm/s', ...
        'residual', 'dimensionless (frac effectiveness-loss proxy)', ...
        'G_nom', '1/(m^2·rad)');
    mon.cfg.forbidden_inputs = {'delta_r_app','eta_r','fault_active','t_fault','phi_ins'};
    mon = local_reset(mon);
    mon.initialized = true;
end

function mon = local_reset(mon)
    mon.k = 0;
    mon.t = NaN;
    mon.persist_count = 0;
    mon.alarm_latched = false;
    mon.t_alarm_s = NaN;
    mon.last_residual = NaN;
    mon.last_gated = false;
    mon.last_valid = false;
    mon.last_above = false;
    mon.n_valid = 0;
    mon.n_gated = 0;
    mon.n_above = 0;
    mon.n_alarm = 0;
end

function st = local_state(mon)
    st = struct();
    st.k = mon.k;
    st.t = mon.t;
    st.persist_count = mon.persist_count;
    st.alarm_latched = mon.alarm_latched;
    st.t_alarm_s = mon.t_alarm_s;
    st.last_residual = mon.last_residual;
    st.last_gated = mon.last_gated;
    st.cfg = mon.cfg;
end

function [mon, out] = local_update(mon, sample)
    assert(isfield(mon, 'initialized') && mon.initialized, 'Call init first');
    assert(isfield(sample, 't') && isfield(sample, 'delta_r_cmd') && ...
        isfield(sample, 'r') && isfield(sample, 'u'), ...
        'sample needs t, delta_r_cmd, r, u');

    t = double(sample.t);
    dr = double(sample.delta_r_cmd);
    r = double(sample.r);
    u = double(sample.u);

    mon.k = mon.k + 1;
    mon.t = t;

    warmed = isfinite(t) && (t > mon.cfg.t_warmup_s);
    valid = isfinite(t) && isfinite(dr) && isfinite(r) && isfinite(u);
    gated = valid && warmed && (abs(dr) > mon.cfg.eps_dr_rad);

    residual = NaN;
    g_hat = NaN;
    if valid
        u_eff = max(u, mon.cfg.u_floor);
        if abs(dr) > eps(1)
            g_hat = r / (u_eff^2 * dr);
            residual = max(0, 1 - g_hat / mon.cfg.G_nom);
            if ~isfinite(residual)
                residual = 0;
            end
        else
            % Zero command: gain undefined; residual undefined / treated as 0
            residual = 0;
            g_hat = NaN;
        end
        mon.n_valid = mon.n_valid + 1;
    end

    above = gated && isfinite(residual) && (residual > mon.cfg.thr_B2);
    if gated
        mon.n_gated = mon.n_gated + 1;
    end
    if above
        mon.persist_count = mon.persist_count + 1;
        mon.n_above = mon.n_above + 1;
    else
        % Warmup / ungated / NaN dropout / below thr → break persistence streak
        mon.persist_count = 0;
    end

    newly_alarmed = false;
    if (~mon.alarm_latched) && (mon.persist_count >= mon.cfg.Np)
        mon.alarm_latched = true;
        mon.t_alarm_s = t;
        newly_alarmed = true;
    end
    if mon.alarm_latched
        mon.n_alarm = mon.n_alarm + 1;
    end

    mon.last_residual = residual;
    mon.last_gated = gated;
    mon.last_valid = valid;
    mon.last_above = above;

    out = struct();
    out.t = t;
    out.k = mon.k;
    out.residual = residual;
    out.g_hat = g_hat;
    out.valid = valid;
    out.warmed = warmed;
    out.gated = gated;
    out.above = above;
    out.persist_count = mon.persist_count;
    out.alarm = mon.alarm_latched;          % latched
    out.alarm_raw_persist = (mon.persist_count >= mon.cfg.Np) || mon.alarm_latched;
    out.newly_alarmed = newly_alarmed;
    out.t_alarm_s = mon.t_alarm_s;
end
