function run_rudder_fault_mag_speed_coverage()
% RUDDER_FAULT_MAG_SPEED_COVERAGE_001 — clean-sensor R10 mag×speed coverage.
% Grid: U∈{1.5,1.75,2.0} ∩ SPEED_ENVELOPE certified; eta∈{0.75,0.50,0.25}.
% Reuse compatible U=1.5, eta=0.50 from RUDDER_FAULT_BASELINE; else one NL 6DOF/point.
% Injection: half-turn progress; delta_r_app = eta * delta_r_cmd (plant-input only).
% Frozen B2 monitor (no retune). Production controller/guidance/plant FROZEN.
% Coverage PASS iff all 9 detect ≤3 s with no pre-fault alarm.
% Artifacts: suite_results/RUDDER_FAULT_MAG_SPEED_COVERAGE.{md,mat,png}
% Does NOT touch CODEX_VERTICAL_PLAN.md.

    project_dir = fileparts(fileparts(fileparts(mfilename('fullpath')))); % repo root
    addpath(genpath(fullfile(project_dir, 'matlab')));
    out_dir = fullfile(project_dir, 'suite_results');
    if ~exist(out_dir, 'dir'); mkdir(out_dir); end
    tag = 'RUDDER_FAULT_MAG_SPEED_COVERAGE';
    task_id = 'RUDDER_FAULT_MAG_SPEED_COVERAGE_001';
    stamp = datestr(now, 'yyyy-mm-dd HH:MM:SS');

    clear functions
    clear guidance_law controller_law
    clear global lambda_muw_ff trim_speed_table trim_elevator_table elevator_sign
    clear global K_zdot K_gamma enable_alpha_hat
    clear global last_guidance_U_h last_guidance_kappa last_r_ff
    clear global last_delta_e last_delta_r last_de_fb

    init_parameters();
    global lambda_muw_ff elevator_sign trim_speed_table trim_elevator_table
    global K_zdot K_gamma enable_alpha_hat
    global dt_controller delta_e_max delta_r_max

    % Frozen production stack (identical to HELIX_R10 / fault baseline)
    elevator_sign = 1;
    trim_speed_table = [0.8 1.0 1.5 2.0];
    trim_elevator_table = deg2rad([-9.18 -7.33 -4.62 -3.17]);
    K_gamma = 0;
    K_zdot = 0;
    enable_alpha_hat = false;
    lambda_muw_ff = 0.25;

    R = 10.0;
    pitch_h = 2.0;
    num_turns = 2;
    n_path = 500;
    path = generate_balanced_helical_path(R, pitch_h, num_turns, n_path);
    T_final = 45;
    s_half_turn = 0.5 * sqrt((2 * pi * R)^2 + pitch_h^2);

    U_grid = [1.5, 1.75, 2.0];
    eta_grid = [0.75, 0.50, 0.25]; % effectiveness remaining (loss 25/50/75%)

    % ----- Certified speeds (SPEED_ENVELOPE_AUDIT) -----
    env = load_speed_envelope(out_dir);
    assert(env.ok, 'SPEED_ENVELOPE_AUDIT incompatible: %s', env.status);
    for iu = 1:numel(U_grid)
        assert(any(abs(env.intersection_U - U_grid(iu)) < 1e-9), ...
            'U=%.2f not in certified intersection', U_grid(iu));
    end

    % ----- Frozen B2 monitor (NO retune) -----
    frozen = load_frozen_B2(out_dir);
    assert(~frozen.retuned, 'Frozen B2 must not be retuned');
    assert(abs(frozen.dt - dt_controller) < 1e-12, 'dt mismatch frozen vs controller');

    % ----- Reuse compatible baseline U=1.5 eta=0.50 -----
    base = load_baseline_reuse(out_dir, R, 1.5, 0.50, T_final);

    fprintf('\n========== %s ==========\n', task_id);
    fprintf('R=%.1f pitch_h=%.1f T=%.0fs | U=[%s] eta=[%s] | s_inj=%.3f m\n', ...
        R, pitch_h, T_final, num2str(U_grid), num2str(eta_grid), s_half_turn);
    fprintf('Envelope: %s | Baseline reuse: %s\n', env.status, base.status);
    fprintf('Frozen B2: G_nom=%.4f thr=%.4f gate=%.1f° Np=%d (no retune)\n', ...
        frozen.G_nom, frozen.thr_B2, rad2deg(frozen.eps_dr_rad), frozen.Np);

    nU = numel(U_grid); nE = numel(eta_grid);
    points = cell(nU, nE);
    n_new_runs = 0;

    for iu = 1:nU
        for ie = 1:nE
            u0 = U_grid(iu);
            eta_post = eta_grid(ie);
            fprintf('\n--- point U=%.2f eta=%.2f (loss %.0f%%) ---\n', ...
                u0, eta_post, 100 * (1 - eta_post));

            reused = false;
            if abs(u0 - 1.5) < 1e-9 && abs(eta_post - 0.50) < 1e-9 && base.ok
                S = base.S;
                reused = true;
                fprintf('  REUSED suite_results/RUDDER_FAULT_BASELINE.mat\n');
            else
                clear guidance_law controller_law
                clear global last_guidance_U_h last_guidance_kappa last_r_ff
                clear global last_delta_e last_delta_r last_de_fb
                S = simulate_fault_helix(path, T_final, u0, R, s_half_turn, eta_post);
                n_new_runs = n_new_runs + 1;
            end

            M = analyze_fault(S, path, R, delta_e_max, delta_r_max, eta_post);
            Gsurv = gate_survivability(M);
            det = score_monitor_online(S, frozen);

            P = struct();
            P.u0 = u0;
            P.eta_post = eta_post;
            P.loss_pct = 100 * (1 - eta_post);
            P.reused = reused;
            P.S_meta = struct('t_fault_s', S.t_fault_s, 's_fault_m', S.s_fault_m, ...
                'dt', S.dt, 'T_final', S.T_final, 'n_steps', S.n_steps, ...
                's_inject_target', S.s_inject_target, 'hidden_reset', S.hidden_reset);
            P.M = strip_logs(M);
            P.Gsurv = Gsurv;
            P.det = det;
            P.detect_ok = det.detected && (det.delay_s <= 3.0) && ~det.alarm_before_fault;
            P.audit_point_ok = ~isnan(M.fault.t_fault_s) && ...
                abs(M.act.eta_realized_post - eta_post) < 0.05 && ...
                ~S.hidden_reset;
            % Compact logs for MAT (keep monitor + key time series)
            P.log = struct();
            P.log.t = S.t(:);
            P.log.s_prog = S.s_prog(:);
            P.log.eta_r = S.eta_r(:);
            P.log.delta_r_cmd = S.delta_r_cmd(:);
            P.log.delta_r_app = S.delta_r_app(:);
            P.log.r = S.rates(:, 3);
            P.log.u = S.vel(:, 1);
            P.log.residual = det.residual;
            P.log.alarm = det.alarm;
            P.log.gated = det.gated;
            points{iu, ie} = P;

            fprintf(['  inj t=%.2fs s=%.3fm | det=%s delay=%.3fs preFA=%s | ', ...
                'yaw=%.3f CTE=%.3f pitch=%.3f roll=%.3f uMAE=%.3f | ', ...
                'surv=%s prog=%.3f bound=%s\n'], ...
                M.fault.t_fault_s, M.fault.s_fault_m, ...
                tern(det.detected, 'YES', 'MISS'), det.delay_s, ...
                tern(det.alarm_before_fault, 'YES', 'NO'), ...
                M.yaw.mae_deg, M.yaw.cte_perp_sbe, M.pitch.steady.mae_deg, ...
                M.roll.mae_deg, M.speed.mae_abs, ...
                tern(Gsurv.survivability_pass, 'PASS', 'FAIL'), ...
                M.mission.progress_frac, tern(M.mission.bounded, 'YES', 'NO'));
        end
    end

    % ----- Aggregate gates (three separate channels) -----
    G = aggregate_gates(points, U_grid, eta_grid, n_new_runs, env, frozen, base);

    write_all(out_dir, tag, task_id, stamp, points, U_grid, eta_grid, G, ...
        frozen, env, base, path, R, pitch_h, num_turns, T_final, ...
        s_half_turn, lambda_muw_ff, delta_e_max, delta_r_max);

    fprintf('\nAudit=%s DetectCov=%s SurvAll=%s | Coverage=%s | next=%s\n', ...
        tern(G.audit_pass, 'PASS', 'FAIL'), ...
        tern(G.detectability_pass, 'PASS', 'FAIL'), ...
        tern(G.survivability_all_pass, 'PASS', 'FAIL'), ...
        tern(G.coverage_pass, 'PASS', 'FAIL'), G.next_priority);
    fprintf('Wrote suite_results/%s.{md,mat,png} + research log append\n', tag);
end

%% ===================== loads =====================
function env = load_speed_envelope(out_dir)
    env = struct('ok', false, 'status', 'NONE');
    p = fullfile(out_dir, 'SPEED_ENVELOPE_AUDIT.mat');
    if ~exist(p, 'file')
        env.status = 'MISSING';
        return;
    end
    W = load(p);
    if ~isfield(W, 'Cert') || ~isfield(W.Cert, 'intersection_U')
        env.status = 'INCOMPATIBLE';
        return;
    end
    env.ok = true;
    env.source = 'suite_results/SPEED_ENVELOPE_AUDIT.mat';
    env.intersection_U = W.Cert.intersection_U(:).';
    env.intersection_label = W.Cert.intersection_label;
    if isfield(W.Cert, 'H') && isfield(W.Cert.H, 'U')
        env.H_U = W.Cert.H.U;
    else
        env.H_U = env.intersection_U;
    end
    env.audit_complete = isfield(W, 'audit_complete') && W.audit_complete;
    env.verdict = '';
    if isfield(W, 'verdict'); env.verdict = char(string(W.verdict)); end
    env.status = sprintf('REUSED intersect=%s audit=%s', env.intersection_label, ...
        tern(env.audit_complete, 'PASS', '?'));
end

function frozen = load_frozen_B2(out_dir)
    p = fullfile(out_dir, 'ISOLATED_ONLINE_RUDDER_RESIDUAL_MONITOR.mat');
    assert(exist(p, 'file') == 2, 'Missing frozen monitor MAT');
    W = load(p);
    assert(isfield(W, 'frozen'), 'frozen struct missing');
    frozen = W.frozen;
    frozen.loaded_from = 'suite_results/ISOLATED_ONLINE_RUDDER_RESIDUAL_MONITOR.mat';
    frozen.retuned = logical(frozen.retuned);
end

function base = load_baseline_reuse(out_dir, R, u0, eta, T_final)
    base = struct('ok', false, 'status', 'NONE', 'S', []);
    p = fullfile(out_dir, 'RUDDER_FAULT_BASELINE.mat');
    if ~exist(p, 'file')
        base.status = 'MISSING_BASELINE';
        return;
    end
    W = load(p);
    if ~isfield(W, 'task') || ~isfield(W, 'S')
        base.status = 'INCOMPATIBLE';
        return;
    end
    tk = W.task;
    ok = isfield(tk, 'R') && abs(tk.R - R) < 1e-9 && ...
        isfield(tk, 'u0') && abs(tk.u0 - u0) < 1e-9 && ...
        isfield(tk, 'eta_post') && abs(tk.eta_post - eta) < 1e-9 && ...
        isfield(tk, 'T_final') && abs(tk.T_final - T_final) < 1e-9;
    if ~ok
        base.status = 'INCOMPATIBLE_GEOM_OR_ETA';
        return;
    end
    base.ok = true;
    base.S = W.S;
    base.source = 'suite_results/RUDDER_FAULT_BASELINE.mat';
    base.status = sprintf('REUSED U=%.2f eta=%.2f T=%.0f t_f=%.2fs', ...
        tk.u0, tk.eta_post, tk.T_final, W.S.t_fault_s);
    if isfield(W, 'M'); base.M = W.M; end
    if isfield(W, 'G'); base.G = W.G; end
end

%% ===================== simulate (plant-input injection) =====================
function S = simulate_fault_helix(path, T_final, u0, R, s_inject, eta_post)
    global dt_controller dt_guidance
    global last_guidance_U_h last_guidance_kappa last_r_ff
    global last_delta_e last_delta_r last_de_fb

    clear guidance_law controller_law
    dt = dt_controller;
    n_steps = round(T_final / dt);
    guidance_period = max(1, round(dt_guidance / dt));

    state = zeros(12, 1);
    state(1:3) = path(1, :)';
    d = path(2, :) - path(1, :);
    state(5) = -atan2(d(3), norm(d(1:2)));
    state(6) = atan2(d(2), d(1));
    state(7) = u0;

    yaw_ref = 0; pitch_ref = 0; u_ref = u0; r_ff = 0; pitch_ref_dot = 0; pidx = 1;
    t_fault = NaN; s_fault = NaN; fault_on = false;
    hidden_reset = false;

    S = struct();
    S.path = path; S.R = R; S.dt = dt; S.T_final = T_final; S.u0 = u0;
    S.eta_post = eta_post; S.s_inject_target = s_inject;
    S.t = zeros(n_steps, 1);
    S.vp = zeros(n_steps, 3);
    S.vel = zeros(n_steps, 3);
    S.rates = zeros(n_steps, 3);
    S.ori = zeros(n_steps, 3);
    S.psi_ref = zeros(n_steps, 1);
    S.theta_ref = zeros(n_steps, 1);
    S.u_ref = zeros(n_steps, 1);
    S.delta_r_cmd = zeros(n_steps, 1);
    S.delta_r_app = zeros(n_steps, 1);
    S.eta_r = ones(n_steps, 1);
    S.delta_e = zeros(n_steps, 1);
    S.de_fb = zeros(n_steps, 1);
    S.thrust = zeros(n_steps, 1);
    S.U_h = zeros(n_steps, 1);
    S.U_h_guid = zeros(n_steps, 1);
    S.kappa = zeros(n_steps, 1);
    S.r_ff = zeros(n_steps, 1);
    S.s_prog = zeros(n_steps, 1);
    S.progress_index = zeros(n_steps, 1);
    S.fault_active = false(n_steps, 1);
    S.guidance_tick = false(n_steps, 1);

    ds = [0; cumsum(sqrt(sum(diff(path).^2, 2)))];
    s_total_path = ds(end);

    for k = 1:n_steps
        pos = state(1:3)';
        ori = state(4:6)';
        rates = state(10:12)';
        u = state(7); v = state(8); w = state(9);
        [Uh, zdot] = inertial_Uh_zdot(ori, u, v, w);
        theta_phys_now = -ori(2);

        if mod(k - 1, guidance_period) == 0
            [yaw_ref, pitch_ref, u_ref, pidx, r_ff, pitch_ref_dot] = ...
                guidance_law(pos, path, pidx, u, v, Uh, zdot, theta_phys_now);
            S.guidance_tick(k) = true;
        end

        [dr_cmd, de, thr] = controller_law(yaw_ref, pitch_ref, u_ref, ...
            ori(3), ori(2), rates(3), rates(2), u, r_ff, pitch_ref_dot, ori(1), w, rates(1));

        s_now = ds(min(max(pidx, 1), numel(ds)));
        if ~fault_on && s_now >= s_inject
            fault_on = true;
            t_fault = k * dt;
            s_fault = s_now;
        end
        if fault_on
            eta = eta_post;
        else
            eta = 1.0;
        end
        dr_app = eta * dr_cmd;
        controls = struct('delta_r', dr_app, 'delta_e', de, 'thrust', thr);

        [~, g] = ode45(@(tt, gg) underwater777_vehicle_dynamics(tt, gg, controls), ...
            [0 dt], state);
        state = g(end, :)';

        S.t(k) = k * dt;
        S.vp(k, :) = state(1:3);
        S.vel(k, :) = state(7:9);
        S.rates(k, :) = state(10:12);
        S.ori(k, :) = state(4:6);
        S.psi_ref(k) = yaw_ref;
        S.theta_ref(k) = pitch_ref;
        S.u_ref(k) = u_ref;
        S.delta_r_cmd(k) = dr_cmd;
        S.delta_r_app(k) = dr_app;
        S.eta_r(k) = eta;
        S.fault_active(k) = fault_on;
        S.thrust(k) = thr;
        S.s_prog(k) = s_now;
        S.progress_index(k) = pidx;
        if isempty(last_delta_e); last_delta_e = de; end
        if isempty(last_de_fb); last_de_fb = de; end
        S.delta_e(k) = last_delta_e;
        S.de_fb(k) = last_de_fb;
        S.U_h(k) = Uh;
        if isempty(last_guidance_U_h); last_guidance_U_h = Uh; end
        if isempty(last_guidance_kappa); last_guidance_kappa = 1 / R; end
        if isempty(last_r_ff); last_r_ff = r_ff; end
        S.U_h_guid(k) = last_guidance_U_h;
        S.kappa(k) = last_guidance_kappa;
        S.r_ff(k) = last_r_ff;

        if mod(k, 400) == 0 || k == n_steps
            fprintf('  step %d/%d t=%.1fs fault=%d eta=%.2f\n', ...
                k, n_steps, S.t(k), fault_on, eta);
        end
    end

    S.t_fault_s = t_fault;
    S.s_fault_m = s_fault;
    S.s_total_path = s_total_path;
    S.hidden_reset = hidden_reset;
    S.n_steps = n_steps;
end

%% ===================== analyze =====================
function M = analyze_fault(S, path, R, de_max, dr_max, eta_post)
    t = S.t(:);
    dt = S.dt;
    psi = S.ori(:, 3);
    phi = S.ori(:, 1);
    theta_phys = -S.ori(:, 2);
    theta_ref = S.theta_ref(:);
    psi_ref = S.psi_ref(:);
    e_psi = wrapToPi(psi_ref - psi);
    e_th = theta_ref - theta_phys;
    e_phi = wrapToPi(0 - phi);
    q = S.rates(:, 2);
    r = S.rates(:, 3);
    p = S.rates(:, 1);
    de = S.delta_e(:);
    dr_cmd = S.delta_r_cmd(:);
    dr_app = S.delta_r_app(:);
    u = S.vel(:, 1);
    u_ref = S.u_ref(:);

    pm = compute_path_following_metrics(path, S.vp, S.vel, S.ori, ...
        psi_ref, theta_ref, dt, t);
    s = pm.s_prog(:);
    s_total = pm.s_total;

    W = compute_pitch_window_metrics(t, e_th, s, s_total, 'mode', 'persistent');
    rho = hypot(S.vp(:, 1), S.vp(:, 2));
    e_radial = rho - R;

    mask_yaw = (t >= 5.0) & W.mask_before_end;
    if ~any(mask_yaw); mask_yaw = t >= 5.0; end
    mask_acq_rud = W.mask_acq;
    if ~any(mask_acq_rud) && ~isnan(W.settling_s)
        mask_acq_rud = t < W.settling_s;
    end

    sat_thr = 0.95 * dr_max;
    rud_sat_acq = sat_pct(dr_cmd, mask_acq_rud, sat_thr);
    rud_sat_steady = sat_pct(dr_cmd, mask_yaw, sat_thr);
    rud_sat_full = sat_pct(dr_cmd, true(size(dr_cmd)), sat_thr);

    Uh_k = S.U_h_guid .* S.kappa;
    valid_ratio = mask_yaw & (abs(S.kappa) > 1e-4) & (abs(S.U_h_guid) > 0.3);
    if any(valid_ratio)
        mean_r = mean(r(valid_ratio));
        mean_Uh_k = mean(Uh_k(valid_ratio));
        if mean_Uh_k < 0
            mean_Uh_k = -mean_Uh_k;
            mean_r = -mean_r;
        end
        ratio = mean_r / max(abs(mean_Uh_k), 1e-9);
    else
        mean_r = NaN; mean_Uh_k = NaN; ratio = NaN;
    end

    M = struct();
    M.pm = pm; M.W = W; M.s_total = s_total;
    M.fault = struct();
    M.fault.eta_post = eta_post;
    M.fault.t_fault_s = S.t_fault_s;
    M.fault.s_fault_m = S.s_fault_m;
    M.fault.s_inject_target = S.s_inject_target;
    M.fault.equation = 'delta_r_applied(t) = eta_r(t) * delta_r_cmd(t)';
    M.fault.boundary = 'plant-input controls.delta_r only';
    M.fault.hidden_reset = S.hidden_reset;

    tw = 8.0;
    tf = S.t_fault_s;
    if isnan(tf)
        mask_pre = false(size(t));
        mask_post = false(size(t));
    else
        mask_pre = (t >= max(0, tf - tw)) & (t < tf);
        mask_post = (t >= tf) & (t <= min(t(end), tf + tw));
    end
    M.fault.pre = window_stats(t, e_psi, e_th, e_phi, u, u_ref, dr_cmd, dr_app, ...
        s, pm, mask_pre, 'pre');
    M.fault.post = window_stats(t, e_psi, e_th, e_phi, u, u_ref, dr_cmd, dr_app, ...
        s, pm, mask_post, 'post');

    M.pitch = struct();
    M.pitch.acq = W.acq;
    M.pitch.steady = W.steady;
    M.pitch.settling_s = W.settling_s;
    M.pitch.persistent_ok = W.persistent_ok;
    mask_ss = W.mask_steady;
    if any(mask_ss)
        th_dot = [0; diff(theta_phys)] / dt;
        M.pitch.chatter_dps = rad2deg(std(hf_local(detrend(th_dot(mask_ss)), dt)));
        M.pitch.elev_sat_pct = 100 * mean(abs(de(mask_ss)) >= 0.98 * de_max);
    else
        M.pitch.chatter_dps = NaN;
        M.pitch.elev_sat_pct = NaN;
    end

    M.yaw = struct();
    if any(mask_yaw)
        M.yaw.mae_deg = rad2deg(mean(abs(e_psi(mask_yaw))));
        M.yaw.rms_deg = rad2deg(rms(e_psi(mask_yaw)));
        M.yaw.p95_deg = rad2deg(pctile95(abs(e_psi(mask_yaw))));
        M.yaw.signed_deg = rad2deg(mean(e_psi(mask_yaw)));
        M.yaw.max_deg = rad2deg(max(abs(e_psi(mask_yaw))));
    else
        M.yaw.mae_deg = NaN; M.yaw.rms_deg = NaN; M.yaw.p95_deg = NaN;
        M.yaw.signed_deg = NaN; M.yaw.max_deg = NaN;
    end
    M.yaw.rudder_sat_acq_pct = rud_sat_acq;
    M.yaw.rudder_sat_steady_pct = rud_sat_steady;
    M.yaw.rudder_sat_full_pct = rud_sat_full;
    M.yaw.ratio_r_Uh_kappa = ratio;
    M.yaw.n_ratio_valid = nnz(valid_ratio);
    M.yaw.cte_perp_sbe = pm.mean_cte_perp;
    M.yaw.radial_mae_sbe = mean(abs(e_radial(mask_yaw)));

    M.roll = struct();
    M.roll.mae_deg = rad2deg(mean(abs(e_phi(mask_yaw))));
    M.roll.p95_deg = rad2deg(pctile95(abs(e_phi(mask_yaw))));
    M.roll.max_deg = rad2deg(max(abs(phi)));
    M.roll.p_rms_dps = rad2deg(rms(p));

    M.speed = struct();
    M.speed.mae_abs = mean(abs(u(mask_yaw) - u_ref(mask_yaw)));
    M.speed.final_u = u(end);
    M.speed.min_u = min(u);
    M.speed.max_u = max(u);

    ddr = [0; diff(dr_cmd)] / dt;
    M.act = struct();
    M.act.rudder_sat_cmd_full_pct = rud_sat_full;
    M.act.rudder_rate_max_dps = rad2deg(max(abs(ddr)));
    M.act.rudder_rate_rms_dps = rad2deg(rms(ddr));
    M.act.rudder_chatter_dps = rad2deg(std(hf_local(detrend(ddr), dt)));
    M.act.elev_sat_pct = M.pitch.elev_sat_pct;
    M.act.cmd_vs_app_mae_deg = rad2deg(mean(abs(dr_cmd - dr_app)));
    M.act.cmd_vs_app_post_mae_deg = rad2deg(mean(abs(dr_cmd(mask_post) - dr_app(mask_post))));
    ii = mask_post & (abs(dr_cmd) > deg2rad(0.5));
    if any(ii)
        M.act.eta_realized_post = mean(dr_app(ii) ./ dr_cmd(ii));
    elseif any(mask_post)
        M.act.eta_realized_post = eta_post;
    else
        M.act.eta_realized_post = NaN;
    end

    M.mission = struct();
    M.mission.s_final_m = s(end);
    M.mission.s_total_m = s_total;
    M.mission.progress_frac = s(end) / max(s_total, eps);
    M.mission.completed_T = (t(end) >= S.T_final - 0.5 * dt);
    M.mission.near_end = s(end) >= 0.88 * s_total;
    M.mission.completion_ok = M.mission.completed_T && isfinite(s(end));
    st = [S.vp, S.ori, S.vel, S.rates];
    M.mission.bounded = all(isfinite(st(:))) && ...
        (max(abs(phi)) < deg2rad(60)) && ...
        (max(abs(theta_phys)) < deg2rad(60)) && ...
        (min(u) > 0.3) && (max(u) < 3.0) && ...
        (max(abs(p)) < deg2rad(90)) && (max(abs(q)) < deg2rad(90)) && (max(abs(r)) < deg2rad(90));
    M.mission.no_hidden_reset = ~S.hidden_reset;
    M.mission.n_nan = nnz(~isfinite(st(:)));
end

function Wout = window_stats(t, e_psi, e_th, e_phi, u, u_ref, dr_cmd, dr_app, s, pm, mask, label)
    Wout = struct('label', label, 'n', nnz(mask));
    if ~any(mask)
        Wout.t0 = NaN; Wout.t1 = NaN;
        Wout.yaw_mae_deg = NaN; Wout.pitch_mae_deg = NaN; Wout.roll_mae_deg = NaN;
        Wout.speed_mae = NaN; Wout.cte_mean = NaN; Wout.cmd_app_mae_deg = NaN;
        Wout.dr_cmd_mean_deg = NaN; Wout.dr_app_mean_deg = NaN; Wout.s_mean = NaN;
        return;
    end
    Wout.t0 = t(find(mask, 1, 'first'));
    Wout.t1 = t(find(mask, 1, 'last'));
    Wout.yaw_mae_deg = rad2deg(mean(abs(e_psi(mask))));
    Wout.pitch_mae_deg = rad2deg(mean(abs(e_th(mask))));
    Wout.roll_mae_deg = rad2deg(mean(abs(e_phi(mask))));
    Wout.speed_mae = mean(abs(u(mask) - u_ref(mask)));
    if isfield(pm, 'cte_perp_series')
        Wout.cte_mean = mean(abs(pm.cte_perp_series(mask)));
    elseif isfield(pm, 'cross_track_error')
        Wout.cte_mean = mean(abs(pm.cross_track_error(mask)));
    else
        Wout.cte_mean = NaN;
    end
    Wout.cmd_app_mae_deg = rad2deg(mean(abs(dr_cmd(mask) - dr_app(mask))));
    Wout.dr_cmd_mean_deg = rad2deg(mean(dr_cmd(mask)));
    Wout.dr_app_mean_deg = rad2deg(mean(dr_app(mask)));
    Wout.s_mean = mean(s(mask));
end

function G = gate_survivability(M)
    G = struct();
    G.g_pitch_mae = ~isnan(M.pitch.steady.mae_deg) && (M.pitch.steady.mae_deg <= 0.30);
    G.g_pitch_p95 = ~isnan(M.pitch.steady.p95_deg) && (M.pitch.steady.p95_deg <= 0.50);
    G.g_pitch_sat = ~isnan(M.pitch.elev_sat_pct) && (M.pitch.elev_sat_pct <= 1.0);
    G.g_pitch_chatter = ~isnan(M.pitch.chatter_dps) && (M.pitch.chatter_dps <= 0.20);
    G.g_pitch_persist = M.pitch.persistent_ok;
    G.g_yaw_mae = ~isnan(M.yaw.mae_deg) && (M.yaw.mae_deg <= 1.0);
    G.g_yaw_p95 = ~isnan(M.yaw.p95_deg) && (M.yaw.p95_deg <= 2.0);
    G.g_yaw_sat_steady = ~isnan(M.yaw.rudder_sat_steady_pct) && (M.yaw.rudder_sat_steady_pct <= 1.0);
    G.g_yaw_sat_full = ~isnan(M.yaw.rudder_sat_full_pct) && (M.yaw.rudder_sat_full_pct <= 1.0);
    G.g_yaw_sat = G.g_yaw_sat_steady && G.g_yaw_sat_full;
    if M.yaw.n_ratio_valid > 10 && ~isnan(M.yaw.ratio_r_Uh_kappa)
        G.g_ratio = (M.yaw.ratio_r_Uh_kappa >= 0.98) && (M.yaw.ratio_r_Uh_kappa <= 1.02);
        G.ratio_applicable = true;
    else
        G.g_ratio = true;
        G.ratio_applicable = false;
    end
    G.g_r10_hard = G.g_pitch_mae && G.g_pitch_p95 && G.g_pitch_sat && G.g_pitch_chatter && ...
        G.g_pitch_persist && G.g_yaw_mae && G.g_yaw_p95 && G.g_yaw_sat && G.g_ratio;
    G.g_completion = M.mission.completion_ok;
    G.g_bounded = M.mission.bounded;
    G.g_no_reset = M.mission.no_hidden_reset;
    G.survivability_pass = G.g_r10_hard && G.g_completion && G.g_bounded && G.g_no_reset;
end

%% ===================== online B2 monitor =====================
function det = score_monitor_online(S, frozen)
    mon = isolated_online_rudder_residual_monitor('init', frozen);
    n = numel(S.t);
    residual = nan(n, 1);
    alarm = false(n, 1);
    gated = false(n, 1);
    for k = 1:n
        sample = struct('t', S.t(k), 'delta_r_cmd', S.delta_r_cmd(k), ...
            'r', S.rates(k, 3), 'u', S.vel(k, 1));
        [mon, out] = isolated_online_rudder_residual_monitor('update', mon, sample);
        residual(k) = out.residual;
        alarm(k) = out.alarm;
        gated(k) = out.gated;
    end

    tf = S.t_fault_s;
    pre = S.t(:) < tf;
    post = S.t(:) >= tf;
    det = struct();
    det.t_fault_s = tf;
    det.alarm_before_fault = any(alarm(pre));
    if any(alarm & post)
        i_det = find(alarm & post, 1, 'first');
        det.detected = true;
        det.t_detect_s = S.t(i_det);
        det.delay_s = det.t_detect_s - tf;
    else
        det.detected = false;
        det.t_detect_s = NaN;
        det.delay_s = Inf;
    end
    det.missed = ~det.detected;
    det.delay_limit_s = 3.0;
    det.within_3s = det.detected && (det.delay_s <= det.delay_limit_s);
    det.residual = residual;
    det.alarm = alarm;
    det.gated = gated;
    det.t_alarm_s = mon.t_alarm_s;
    post_g = post & gated & isfinite(residual);
    if any(post_g)
        det.post_median_resid = median(residual(post_g));
    else
        det.post_median_resid = NaN;
    end
end

%% ===================== aggregate =====================
function G = aggregate_gates(points, U_grid, eta_grid, n_new_runs, env, frozen, base)
    nU = numel(U_grid); nE = numel(eta_grid);
    detect_ok = false(nU, nE);
    audit_ok = false(nU, nE);
    surv_ok = false(nU, nE);
    delay = nan(nU, nE);
    preFA = false(nU, nE);
    missed = false(nU, nE);

    for iu = 1:nU
        for ie = 1:nE
            P = points{iu, ie};
            detect_ok(iu, ie) = P.detect_ok;
            audit_ok(iu, ie) = P.audit_point_ok;
            surv_ok(iu, ie) = P.Gsurv.survivability_pass;
            delay(iu, ie) = P.det.delay_s;
            preFA(iu, ie) = P.det.alarm_before_fault;
            missed(iu, ie) = P.det.missed;
        end
    end

    G = struct();
    G.n_points = nU * nE;
    G.n_new_nl_runs = n_new_runs;
    G.n_reused = G.n_points - n_new_runs;
    G.detect_ok = detect_ok;
    G.audit_ok = audit_ok;
    G.surv_ok = surv_ok;
    G.delay_s = delay;
    G.pre_fault_alarm = preFA;
    G.missed = missed;

    % Channel 1: audit completeness
    G.audit_pass = all(audit_ok(:)) && env.ok && ~frozen.retuned && base.ok;
    % Channel 2: detectability coverage (PRIMARY coverage gate)
    G.detectability_pass = all(detect_ok(:));
    G.coverage_pass = G.detectability_pass; % explicit alias
    % Channel 3: fixed-horizon survivability (report; not coverage gate)
    G.survivability_all_pass = all(surv_ok(:));
    G.n_detect_ok = nnz(detect_ok);
    G.n_surv_ok = nnz(surv_ok);
    G.n_miss = nnz(missed);
    G.n_preFA = nnz(preFA);

    % Certified demonstrated detectability region (no retune rescue)
    cert_cells = {};
    for iu = 1:nU
        for ie = 1:nE
            if detect_ok(iu, ie)
                cert_cells{end+1} = sprintf('U=%.2f/eta=%.2f', U_grid(iu), eta_grid(ie)); %#ok<AGROW>
            end
        end
    end
    G.certified_detect_cells = cert_cells;
    G.certified_detect_region = strjoin(cert_cells, ', ');

    if G.coverage_pass
        G.next_priority = 'fault_isolation_safe_mode_requirements_audit';
        G.next_note = ['Full mag×speed detectability coverage PASS → next: ', ...
            'fault-isolation / safe-mode requirements audit; production frozen.'];
    else
        G.next_priority = 'distinct_detector_or_actuator_feedback_requirement';
        G.next_note = ['Partial coverage — certify only demonstrated detect cells; ', ...
            'prioritize a distinct detector / actuator-feedback requirement; do NOT retune B2.'];
    end
end

function M2 = strip_logs(M)
    M2 = M;
    if isfield(M2, 'logs'); M2 = rmfield(M2, 'logs'); end
    if isfield(M2, 'pm') && isstruct(M2.pm)
        keep = {'s_prog','s_total','mean_cte_perp','mean_cte','rms_cte'};
        pm2 = struct();
        for i = 1:numel(keep)
            if isfield(M2.pm, keep{i}); pm2.(keep{i}) = M2.pm.(keep{i}); end
        end
        M2.pm = pm2;
    end
    if isfield(M2, 'W') && isstruct(M2.W)
        W2 = struct();
        fn = {'settling_s','persistent_ok','acq','steady'};
        for i = 1:numel(fn)
            if isfield(M2.W, fn{i}); W2.(fn{i}) = M2.W.(fn{i}); end
        end
        M2.W = W2;
    end
end

%% ===================== write =====================
function write_all(out_dir, tag, task_id, stamp, points, U_grid, eta_grid, G, ...
        frozen, env, base, path, R, pitch_h, num_turns, T_final, ...
        s_half, lam, de_max, dr_max)

    png_path = fullfile(out_dir, [tag '.png']);
    write_png(png_path, points, U_grid, eta_grid, G, tag, frozen);

    art_ok = exist(png_path, 'file') == 2;
    G.audit_pass = G.audit_pass && art_ok;

    base_meta = struct('ok', base.ok, 'status', base.status);
    if isfield(base, 'source'); base_meta.source = base.source; end

    task = struct();
    task.id = task_id; task.stamp = stamp; task.tag = tag;
    task.R = R; task.pitch_h = pitch_h; task.num_turns = num_turns;
    task.T_final = T_final; task.U_grid = U_grid; task.eta_grid = eta_grid;
    task.s_half_turn = s_half; task.lambda_muw_ff = lam;
    task.sensor = 'clean ASSUMED-direct IMU r + DVL u (no noise/delay)';
    task.injection = 'half-turn progress; delta_r_app=eta*delta_r_cmd plant-input';
    task.frozen_B2 = frozen;
    task.env = env;
    task.baseline_reuse = base.status;
    task.gates = G;
    task.audit_pass = G.audit_pass;
    task.detectability_pass = G.detectability_pass;
    task.coverage_pass = G.coverage_pass;
    task.survivability_all_pass = G.survivability_all_pass;
    task.next_priority = G.next_priority;

    mat_path = fullfile(out_dir, [tag '.mat']);
    save(mat_path, 'task', 'points', 'U_grid', 'eta_grid', 'G', 'frozen', ...
        'env', 'base_meta', 'path', 'R', 'pitch_h', 'T_final', 's_half', '-v7.3');

    md_path = fullfile(out_dir, [tag '.md']);
    write_md(md_path, tag, task_id, stamp, points, U_grid, eta_grid, G, ...
        frozen, env, base, R, pitch_h, num_turns, T_final, s_half, ...
        lam, de_max, dr_max, art_ok);

    % finalize
    task.gates = G;
    save(mat_path, 'task', 'points', 'U_grid', 'eta_grid', 'G', 'frozen', ...
        'env', 'base_meta', 'path', 'R', 'pitch_h', 'T_final', 's_half', '-v7.3');

    append_research_log(out_dir, tag, task_id, stamp, points, U_grid, eta_grid, G, frozen);
end

function write_png(png_path, points, U_grid, eta_grid, G, tag, frozen)
    nU = numel(U_grid); nE = numel(eta_grid);
    delayM = nan(nU, nE);
    detM = zeros(nU, nE);
    survM = zeros(nU, nE);
    for iu = 1:nU
        for ie = 1:nE
            P = points{iu, ie};
            if isfinite(P.det.delay_s) && P.det.delay_s < 1e6
                delayM(iu, ie) = P.det.delay_s;
            end
            detM(iu, ie) = double(P.detect_ok);
            survM(iu, ie) = double(P.Gsurv.survivability_pass);
        end
    end

    fig = figure('Color', 'w', 'Position', [40 40 1200 780], 'Visible', 'off');

    subplot(2, 2, 1);
    imagesc(1:nE, 1:nU, delayM); axis xy; colorbar;
    set(gca, 'XTick', 1:nE, 'XTickLabel', arrayfun(@(e) sprintf('η=%.2f', e), eta_grid, 'uni', 0));
    set(gca, 'YTick', 1:nU, 'YTickLabel', arrayfun(@(u) sprintf('U=%.2f', u), U_grid, 'uni', 0));
    title('B2 detect delay [s] (Inf/miss = blank)');
    for iu = 1:nU
        for ie = 1:nE
            if isfinite(delayM(iu, ie))
                text(ie, iu, sprintf('%.3f', delayM(iu, ie)), ...
                    'HorizontalAlignment', 'center', 'Color', 'w', 'FontWeight', 'bold');
            else
                text(ie, iu, 'MISS', 'HorizontalAlignment', 'center', 'Color', 'r', 'FontWeight', 'bold');
            end
        end
    end

    subplot(2, 2, 2);
    imagesc(1:nE, 1:nU, detM); axis xy; caxis([0 1]); colorbar;
    set(gca, 'XTick', 1:nE, 'XTickLabel', arrayfun(@(e) sprintf('η=%.2f', e), eta_grid, 'uni', 0));
    set(gca, 'YTick', 1:nU, 'YTickLabel', arrayfun(@(u) sprintf('U=%.2f', u), U_grid, 'uni', 0));
    title(sprintf('Detectability (≤3s, no preFA) | cov=%s', tern(G.coverage_pass, 'PASS', 'FAIL')));

    subplot(2, 2, 3);
    imagesc(1:nE, 1:nU, survM); axis xy; caxis([0 1]); colorbar;
    set(gca, 'XTick', 1:nE, 'XTickLabel', arrayfun(@(e) sprintf('η=%.2f', e), eta_grid, 'uni', 0));
    set(gca, 'YTick', 1:nU, 'YTickLabel', arrayfun(@(u) sprintf('U=%.2f', u), U_grid, 'uni', 0));
    title(sprintf('Fixed-horizon survivability | all=%s', tern(G.survivability_all_pass, 'PASS', 'FAIL')));

    subplot(2, 2, 4);
    hold on;
    colors = lines(nU);
    hL = gobjects(nU, 1);
    for iu = 1:nU
        for ie = 1:nE
            P = points{iu, ie};
            hh = plot(P.log.t, P.log.residual, 'Color', colors(iu, :));
            if ie == 1; hL(iu) = hh; end
        end
    end
    yline(frozen.thr_B2, 'k--', 'thr_B2');
    grid on; xlabel('t [s]'); ylabel('r_{B2}');
    title(sprintf('B2 residuals all points | audit=%s', tern(G.audit_pass, 'PASS', 'FAIL')));
    legend(hL, arrayfun(@(u) sprintf('U=%.2f family', u), U_grid, 'uni', 0), 'Location', 'best');

    sgtitle(sprintf('%s | cov=%s detect=%d/%d surv=%d/%d', tag, ...
        tern(G.coverage_pass, 'PASS', 'FAIL'), G.n_detect_ok, G.n_points, ...
        G.n_surv_ok, G.n_points));
    exportgraphics(fig, png_path, 'Resolution', 150);
    close(fig);
end

function write_md(md_path, tag, task_id, stamp, points, U_grid, eta_grid, G, ...
        frozen, env, base, R, pitch_h, num_turns, T_final, s_half, ...
        lam, de_max, dr_max, art_ok)

    fid = fopen(md_path, 'w');
    fprintf(fid, '# %s\n\n', tag);
    fprintf(fid, '**TASK_ID:** %s\n', task_id);
    fprintf(fid, '**Date:** %s\n', stamp);
    fprintf(fid, '**Audit completeness:** **%s**\n', tern(G.audit_pass, 'PASS', 'FAIL'));
    fprintf(fid, '**Detectability coverage:** **%s**\n', tern(G.detectability_pass, 'PASS', 'FAIL'));
    fprintf(fid, '**Coverage (primary):** **%s**\n', tern(G.coverage_pass, 'PASS', 'FAIL'));
    fprintf(fid, '**Fixed-horizon survivability (all 9):** **%s**\n\n', ...
        tern(G.survivability_all_pass, 'PASS', 'FAIL'));

    fprintf(fid, 'Clean-sensor nonlinear R10 mag×speed coverage. ');
    fprintf(fid, 'Production cascade+guidance+plant **frozen**. B2 params **frozen** (no retune).\n\n');

    fprintf(fid, '## Scope / sources\n\n');
    fprintf(fid, '- Geometry: R=%.1f m, pitch_h=%.1f, turns=%d, T_final=%.0f s, λ_μw=%.2f\n', ...
        R, pitch_h, num_turns, T_final, lam);
    fprintf(fid, '- Certified speeds: `%s` from `%s`\n', env.intersection_label, env.source);
    fprintf(fid, '- Grid U = {%s} m/s (subset of certified intersect)\n', num2str(U_grid));
    fprintf(fid, '- Grid η = {%s} (loss 25/50/75%%)\n', num2str(eta_grid));
    fprintf(fid, '- Injection: s_half_turn=%.6f m; δr_app=η·δr_cmd at plant-input\n', s_half);
    fprintf(fid, '- Baseline reuse: `%s`\n', base.status);
    fprintf(fid, '- New NL 6DOF runs: %d | Reused: %d | Total points: %d\n', ...
        G.n_new_nl_runs, G.n_reused, G.n_points);
    fprintf(fid, '- Sensor: clean ASSUMED-direct IMU r + DVL u (no noise/delay in this gate)\n');
    fprintf(fid, '- δe_max=%.1f° δr_max=%.1f°\n\n', rad2deg(de_max), rad2deg(dr_max));

    fprintf(fid, '## Frozen B2 monitor (unchanged)\n\n');
    fprintf(fid, '| Item | Value |\n|---|---:|\n');
    fprintf(fid, '| G_nom [1/(m^2·rad)] | %.6f |\n', frozen.G_nom);
    fprintf(fid, '| thr_B2 [frac] | %.6f |\n', frozen.thr_B2);
    fprintf(fid, '| \\|δr\\|_gate [deg] | %.1f |\n', rad2deg(frozen.eps_dr_rad));
    fprintf(fid, '| u_floor [m/s] | %.2f |\n', frozen.u_floor);
    fprintf(fid, '| Warmup | t > %.1f s |\n', frozen.t_warmup_s);
    fprintf(fid, '| Persistence | %.2f s (Np=%d @ dt=%.3f) |\n', ...
        frozen.persist_s, frozen.Np, frozen.dt);
    fprintf(fid, '| Retuned | %s |\n', tern(frozen.retuned, 'YES', 'NO'));
    fprintf(fid, '| Source | `%s` |\n\n', frozen.loaded_from);

    fprintf(fid, '## Coverage matrix (detectability)\n\n');
    fprintf(fid, '| U\\\\η |');
    for ie = 1:numel(eta_grid)
        fprintf(fid, ' η=%.2f (loss %.0f%%) |', eta_grid(ie), 100*(1-eta_grid(ie)));
    end
    fprintf(fid, '\n|---:|');
    for ie = 1:numel(eta_grid); fprintf(fid, '---:|'); end
    fprintf(fid, '\n');
    for iu = 1:numel(U_grid)
        fprintf(fid, '| **%.2f** |', U_grid(iu));
        for ie = 1:numel(eta_grid)
            P = points{iu, ie};
            if P.detect_ok
                fprintf(fid, ' DETECT %.3fs |', P.det.delay_s);
            elseif P.det.alarm_before_fault
                fprintf(fid, ' PRE-FAULT |');
            else
                fprintf(fid, ' **MISS** |');
            end
        end
        fprintf(fid, '\n');
    end
    fprintf(fid, '\nCoverage PASS rule: all 9 detect within 3 s with no pre-fault alarm. ');
    fprintf(fid, '**No retune** to rescue misses.\n\n');

    fprintf(fid, '## Per-point report\n\n');
    fprintf(fid, '| U | η | loss%% | reuse | t_f [s] | s_f [m] | det | delay [s] | preFA | ');
    fprintf(fid, 'yawMAE | CTE | pitchMAE | rollMAE | uMAE | ');
    fprintf(fid, 'δrSatF%% | rateMax | chat | η_real | bound | prog | surv |\n');
    fprintf(fid, '|---:|---:|---:|:---:|---:|---:|:---:|---:|:---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|:---:|---:|:---:|\n');
    for iu = 1:numel(U_grid)
        for ie = 1:numel(eta_grid)
            P = points{iu, ie}; M = P.M; d = P.det;
            fprintf(fid, ['| %.2f | %.2f | %.0f | %s | %.2f | %.3f | %s | %s | %s | ', ...
                '%.3f | %.3f | %.3f | %.3f | %.3f | %.2f | %.1f | %.3f | %.3f | %s | %.3f | %s |\n'], ...
                P.u0, P.eta_post, P.loss_pct, tern(P.reused, 'YES', 'NO'), ...
                M.fault.t_fault_s, M.fault.s_fault_m, ...
                tern(d.detected, 'YES', 'MISS'), ...
                tern(isfinite(d.delay_s) && d.delay_s < 1e6, sprintf('%.3f', d.delay_s), 'Inf'), ...
                tern(d.alarm_before_fault, 'YES', 'NO'), ...
                M.yaw.mae_deg, M.yaw.cte_perp_sbe, M.pitch.steady.mae_deg, ...
                M.roll.mae_deg, M.speed.mae_abs, ...
                M.yaw.rudder_sat_full_pct, M.act.rudder_rate_max_dps, ...
                M.act.rudder_chatter_dps, M.act.eta_realized_post, ...
                tern(M.mission.bounded, 'YES', 'NO'), M.mission.progress_frac, ...
                tern(P.Gsurv.survivability_pass, 'PASS', 'FAIL'));
        end
    end
    fprintf(fid, '\n');

    fprintf(fid, '### Command vs applied / pre−post (±8 s) highlights\n\n');
    fprintf(fid, '| U | η | t_f | cmd−app postMAE [°] | pre yaw | post yaw | pre CTE | post CTE | pre δr_cmd | post δr_cmd | post δr_app |\n');
    fprintf(fid, '|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|\n');
    for iu = 1:numel(U_grid)
        for ie = 1:numel(eta_grid)
            P = points{iu, ie}; M = P.M;
            fprintf(fid, '| %.2f | %.2f | %.2f | %.3f | %.3f | %.3f | %.3f | %.3f | %.3f | %.3f | %.3f |\n', ...
                P.u0, P.eta_post, M.fault.t_fault_s, M.act.cmd_vs_app_post_mae_deg, ...
                M.fault.pre.yaw_mae_deg, M.fault.post.yaw_mae_deg, ...
                M.fault.pre.cte_mean, M.fault.post.cte_mean, ...
                M.fault.pre.dr_cmd_mean_deg, M.fault.post.dr_cmd_mean_deg, ...
                M.fault.post.dr_app_mean_deg);
        end
    end
    fprintf(fid, '\n');

    fprintf(fid, '## Separated verdicts\n\n');
    fprintf(fid, '| Channel | Verdict | Rule |\n|---|:---:|---|\n');
    fprintf(fid, '| Audit completeness | **%s** | all points traceable η + artifacts + envelope + frozen B2 + baseline reuse |\n', ...
        tern(G.audit_pass, 'PASS', 'FAIL'));
    fprintf(fid, '| Detectability coverage | **%s** | all 9: detect ≤3 s AND no pre-fault alarm (no retune) |\n', ...
        tern(G.detectability_pass, 'PASS', 'FAIL'));
    fprintf(fid, '| **Coverage (primary)** | **%s** | ≡ detectability coverage |\n', ...
        tern(G.coverage_pass, 'PASS', 'FAIL'));
    fprintf(fid, '| Fixed-horizon survivability | **%s** | all 9: R10 hard ∩ T_final complete ∩ bounded ∩ no-reset (NOT mission-goal) |\n', ...
        tern(G.survivability_all_pass, 'PASS', 'FAIL'));
    fprintf(fid, '| artifacts png | %s | |\n\n', tern(art_ok, 'YES', 'NO'));

    fprintf(fid, '### Certified demonstrated detectability region\n\n');
    if isempty(G.certified_detect_cells)
        fprintf(fid, '- NONE\n\n');
    else
        fprintf(fid, '- %s\n\n', G.certified_detect_region);
    end

    fprintf(fid, '## Next priority\n\n');
    fprintf(fid, '- **`%s`** — %s\n\n', G.next_priority, G.next_note);

    fprintf(fid, '## Files\n\n');
    fprintf(fid, '- `run_rudder_fault_mag_speed_coverage.m` (isolated runner)\n');
    fprintf(fid, '- `isolated_online_rudder_residual_monitor.m` (frozen B2 API; unchanged)\n');
    fprintf(fid, '- `suite_results/%s.md`\n', tag);
    fprintf(fid, '- `suite_results/%s.mat`\n', tag);
    fprintf(fid, '- `suite_results/%s.png`\n', tag);
    fprintf(fid, '- Production: controller_law / guidance / plant **unchanged**; CODEX_VERTICAL_PLAN untouched.\n');
    fclose(fid);
end

function append_research_log(out_dir, tag, task_id, stamp, points, U_grid, eta_grid, G, frozen)
    log_path = fullfile(out_dir, 'PITCH_CONTROL_RESEARCH_LOG.md');
    lfid = fopen(log_path, 'a');
    fprintf(lfid, '\n\n## %s — %s\n\n', task_id, stamp);
    fprintf(lfid, '- Audit: **%s** — Detectability/Coverage: **%s** — Fixed-horizon surv(all): **%s** — clean-sensor R10 U×η matrix; production frozen; B2 frozen (no retune).\n', ...
        tern(G.audit_pass, 'PASS', 'FAIL'), tern(G.coverage_pass, 'PASS', 'FAIL'), ...
        tern(G.survivability_all_pass, 'PASS', 'FAIL'));
    fprintf(lfid, '- Grid: U={%s} ∩ SPEED_ENVELOPE intersect; η={%s} (loss 25/50/75%%); new NL runs=%d reused=%d.\n', ...
        num2str(U_grid), num2str(eta_grid), G.n_new_nl_runs, G.n_reused);
    fprintf(lfid, '- Frozen B2: G_nom=%.4f thr=%.4f gate=%.1f° Np=%d (from ISOLATED_ONLINE; retuned=NO).\n', ...
        frozen.G_nom, frozen.thr_B2, rad2deg(frozen.eps_dr_rad), frozen.Np);
    fprintf(lfid, '- Detect: %d/%d within 3s no-preFA; misses=%d preFA=%d.\n', ...
        G.n_detect_ok, G.n_points, G.n_miss, G.n_preFA);
    % Compact per-point line
    parts = {};
    for iu = 1:numel(U_grid)
        for ie = 1:numel(eta_grid)
            P = points{iu, ie};
            if P.detect_ok
                parts{end+1} = sprintf('U%.2f/η%.2f:%.3fs', P.u0, P.eta_post, P.det.delay_s); %#ok<AGROW>
            else
                parts{end+1} = sprintf('U%.2f/η%.2f:MISS', P.u0, P.eta_post); %#ok<AGROW>
            end
        end
    end
    fprintf(lfid, '- Delays: %s.\n', strjoin(parts, '; '));
    fprintf(lfid, '- Certified detect region: %s.\n', ...
        tern(isempty(G.certified_detect_cells), 'NONE', G.certified_detect_region));
    fprintf(lfid, '- Artifacts: suite_results/%s.{md,mat,png}; driver `run_rudder_fault_mag_speed_coverage.m`.\n', tag);
    fprintf(lfid, '- Next: **`%s`** — production remains frozen; CODEX_VERTICAL_PLAN untouched.\n', ...
        G.next_priority);
    fclose(lfid);
end

%% ===================== helpers =====================
function [Uh, zdot] = inertial_Uh_zdot(ori, u, v, w)
    phi = ori(1); theta = ori(2); psi = ori(3);
    Rm = [cos(psi)*cos(theta), ...
         cos(psi)*sin(theta)*sin(phi) - sin(psi)*cos(phi), ...
         cos(psi)*sin(theta)*cos(phi) + sin(psi)*sin(phi);
         sin(psi)*cos(theta), ...
         sin(psi)*sin(theta)*sin(phi) + cos(psi)*cos(phi), ...
         sin(psi)*sin(theta)*cos(phi) - cos(psi)*sin(phi);
         -sin(theta), ...
         cos(theta)*sin(phi), ...
         cos(theta)*cos(phi)];
    pos_dot = Rm * [u; v; w];
    Uh = hypot(pos_dot(1), pos_dot(2));
    zdot = pos_dot(3);
end

function p = sat_pct(u, mask, thr)
    if ~any(mask); p = NaN; return; end
    p = 100 * mean(abs(u(mask)) >= thr);
end

function y = hf_local(x, dt)
    n = max(3, round(0.8 / dt));
    b = ones(n, 1) / n;
    lf = filter(b, 1, x(:));
    y = x(:) - lf;
    y(1:n) = 0;
end

function v = pctile95(x)
    x = sort(x(:));
    if isempty(x); v = NaN; return; end
    k = max(1, min(numel(x), ceil(0.95 * numel(x))));
    v = x(k);
end

function s = tern(c, a, b)
    if c; s = a; else; s = b; end
end
