function params = availability_codegen_init(cfg)
%AVAILABILITY_CODEGEN_INIT Frozen Gate 5C FSM constants plus 7-channel ICD.
% DEPLOY_CANDIDATE / HEALTH_STATUS_ONLY / NOT_IN_PRODUCTION / NOT_CERTIFIED
% Isolated explicit-state runtime. Dwell constants remain ASSUMED / NOT_CERTIFIED.
%
% tau_fresh[i] = max(4*period[i], stale_limit[i]+period[i], 1.0)
%
% TASK_ID: AVAILABILITY_RUNTIME_001

    T_degrade = 0.50;
    T_lost = 2.00;
    T_reacq = 0.50;
    T_clear = 1.00;
    T_settle = 3.00;
    tol_time = 1.0e-12;
    k_fresh = 4.0;
    tau_floor = 1.0;

    present = false(7, 1);
    period = zeros(7, 1);
    stale_limit = zeros(7, 1);
    tau_fresh = zeros(7, 1);

    present(1) = logical(cfg.present(1));
    present(2) = logical(cfg.present(2));
    present(3) = logical(cfg.present(3));
    present(4) = logical(cfg.present(4));
    present(5) = logical(cfg.present(5));
    present(6) = logical(cfg.present(6));
    present(7) = logical(cfg.present(7));

    period(1) = cfg.period(1);
    period(2) = cfg.period(2);
    period(3) = cfg.period(3);
    period(4) = cfg.period(4);
    period(5) = cfg.period(5);
    period(6) = cfg.period(6);
    period(7) = cfg.period(7);

    stale_limit(1) = cfg.stale_limit(1);
    stale_limit(2) = cfg.stale_limit(2);
    stale_limit(3) = cfg.stale_limit(3);
    stale_limit(4) = cfg.stale_limit(4);
    stale_limit(5) = cfg.stale_limit(5);
    stale_limit(6) = cfg.stale_limit(6);
    stale_limit(7) = cfg.stale_limit(7);

    for i = 1:7
        a = k_fresh * period(i);
        b = stale_limit(i) + period(i);
        m = a;
        if b > m
            m = b;
        end
        if tau_floor > m
            m = tau_floor;
        end
        tau_fresh(i) = m;
    end

    config_valid = isfinite(T_degrade) && (T_degrade > 0.0) && ...
        isfinite(T_lost) && (T_lost > 0.0) && ...
        isfinite(T_reacq) && (T_reacq > 0.0) && ...
        isfinite(T_clear) && (T_clear > 0.0) && ...
        isfinite(T_settle) && (T_settle > 0.0) && ...
        isfinite(tol_time) && (tol_time > 0.0) && ...
        isfinite(k_fresh) && (k_fresh > 0.0) && ...
        isfinite(tau_floor) && (tau_floor > 0.0) && ...
        isfinite(period(1)) && (period(1) > 0.0) && ...
        isfinite(stale_limit(1)) && (stale_limit(1) >= 0.0) && ...
        isfinite(tau_fresh(1)) && (tau_fresh(1) > 0.0) && ...
        isfinite(period(2)) && (period(2) > 0.0) && ...
        isfinite(stale_limit(2)) && (stale_limit(2) >= 0.0) && ...
        isfinite(tau_fresh(2)) && (tau_fresh(2) > 0.0) && ...
        isfinite(period(3)) && (period(3) > 0.0) && ...
        isfinite(stale_limit(3)) && (stale_limit(3) >= 0.0) && ...
        isfinite(tau_fresh(3)) && (tau_fresh(3) > 0.0) && ...
        isfinite(period(4)) && (period(4) > 0.0) && ...
        isfinite(stale_limit(4)) && (stale_limit(4) >= 0.0) && ...
        isfinite(tau_fresh(4)) && (tau_fresh(4) > 0.0) && ...
        isfinite(period(5)) && (period(5) > 0.0) && ...
        isfinite(stale_limit(5)) && (stale_limit(5) >= 0.0) && ...
        isfinite(tau_fresh(5)) && (tau_fresh(5) > 0.0) && ...
        isfinite(period(6)) && (period(6) > 0.0) && ...
        isfinite(stale_limit(6)) && (stale_limit(6) >= 0.0) && ...
        isfinite(tau_fresh(6)) && (tau_fresh(6) > 0.0) && ...
        isfinite(period(7)) && (period(7) > 0.0) && ...
        isfinite(stale_limit(7)) && (stale_limit(7) >= 0.0) && ...
        isfinite(tau_fresh(7)) && (tau_fresh(7) > 0.0);

    params = struct();
    params.T_degrade = T_degrade;
    params.T_lost = T_lost;
    params.T_reacq = T_reacq;
    params.T_clear = T_clear;
    params.T_settle = T_settle;
    params.tol_time = tol_time;
    params.k_fresh = k_fresh;
    params.tau_floor = tau_floor;
    params.present = present;
    params.period = period;
    params.stale_limit = stale_limit;
    params.tau_fresh = tau_fresh;
    params.config_valid = config_valid;
end
