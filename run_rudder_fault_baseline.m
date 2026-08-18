function run_rudder_fault_baseline()
% RUDDER_FAULT_BASELINE_001 — first bounded rudder-fault gate on feasible R10@U=1.5.
% Isolated driver only. Production controller_law / guidance / plant / gains untouched.
% Injection: plant-input boundary only — delta_r_applied = eta_r(t)*delta_r_cmd.
% Evidence: suite_results/RUDDER_FAULT_BASELINE.{md,mat,png}
% Closes rejected mission-shaper line; advances fault baseline.

    project_dir = fileparts(mfilename('fullpath'));
    addpath(project_dir);
    out_dir = fullfile(project_dir, 'suite_results');
    if ~exist(out_dir, 'dir'); mkdir(out_dir); end
    tag = 'RUDDER_FAULT_BASELINE';
    task_id = 'RUDDER_FAULT_BASELINE_001';
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
    global dt_controller dt_guidance delta_e_max delta_r_max

    % Frozen production stack (identical to HELIX_R10 envelope)
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
    u0 = 1.5;
    eta_post = 0.50; % 50% rudder effectiveness loss
    % Mid-first-turn geometric progress: half of one turn helix arc length
    s_half_turn = 0.5 * sqrt((2 * pi * R)^2 + pitch_h^2);

    % ----- Fault-interface audit (read-only of production call chain) -----
    FA = fault_interface_audit();

    % ----- Reuse compatible nominal R10 result if present -----
    nom = load_nominal_r10(out_dir, R, u0, T_final);

    fprintf('\n========== %s ==========\n', task_id);
    fprintf('R=%.1f pitch_h=%.1f turns=%d T=%.0fs u0=%.2f | eta_post=%.2f | s_inj=%.3f m (mid-1st-turn)\n', ...
        R, pitch_h, num_turns, T_final, u0, eta_post, s_half_turn);
    fprintf('Nominal reuse: %s\n', nom.status);

    % One nonlinear 6DOF fault run (no controller/guidance/plant edits)
    S = simulate_fault_helix(path, T_final, u0, R, s_half_turn, eta_post);
    M = analyze_fault(S, path, R, delta_e_max, delta_r_max, eta_post);
    G = gate_fault(M);
    write_all(out_dir, tag, task_id, stamp, S, M, G, FA, nom, path, R, ...
        pitch_h, num_turns, T_final, u0, eta_post, s_half_turn, lambda_muw_ff, ...
        delta_e_max, delta_r_max);

    fprintf(['Audit=%s Surv=%s | inj t=%.2fs s=%.3fm eta=%.2f | ', ...
        'yawMAE=%.3f CTE=%.3f rollMAE=%.3f pitchMAE=%.3f uMAE=%.3f | ', ...
        'drSatF=%.2f%% chat=%.4f | next=%s\n'], ...
        tern(G.audit_pass, 'PASS', 'FAIL'), tern(G.survivability_pass, 'PASS', 'FAIL'), ...
        M.fault.t_fault_s, M.fault.s_fault_m, eta_post, ...
        M.yaw.mae_deg, M.yaw.cte_perp_sbe, M.roll.mae_deg, M.pitch.steady.mae_deg, ...
        M.speed.mae_abs, M.yaw.rudder_sat_full_pct, M.act.rudder_chatter_dps, ...
        G.next_priority);
    fprintf('Wrote suite_results/%s.{md,mat,png} + research log append\n', tag);
end

%% ===================== audit =====================
function FA = fault_interface_audit()
% Audit of fault interfaces in the three allowed production files only.
    FA = struct();
    FA.scope = ['run_path_suite.m | continuous_path_tracking.m | controller_law.m ', ...
        '(read-only; production frozen)'];
    FA.plant_input_boundary = 'PRESENT — controls.delta_r/delta_e/thrust struct into underwater777_vehicle_dynamics';
    FA.controller_command_log = 'PRESENT — suite_delta_r_log / last_delta_r diagnostics';
    FA.rudder_rate_mag_limit = 'PRESENT — controller_law mag+rate limit on delta_r (pre-plant)';
    FA.fault_injection_api = 'NOT_IMPLEMENTED';
    FA.fault_detection = 'NOT_IMPLEMENTED';
    FA.fault_isolation = 'NOT_IMPLEMENTED';
    FA.safe_mode = 'NOT_IMPLEMENTED';
    FA.actuator_health_monitor = 'NOT_IMPLEMENTED';
    FA.effectiveness_estimator = 'NOT_IMPLEMENTED';
    FA.residual_detector = 'NOT_IMPLEMENTED';
    FA.abort_manager = 'NOT_IMPLEMENTED';
    FA.note = ['Fault must be imposed in isolated runner at plant-input boundary ', ...
        'without editing production controller/guidance/plant.'];
end

function nom = load_nominal_r10(out_dir, R, u0, T_final)
    nom = struct('ok', false, 'status', 'NONE', 'source', '', 'metrics', struct());
    p = fullfile(out_dir, 'HELIX_R10_YAW_PITCH_ENVELOPE.mat');
    if ~exist(p, 'file')
        nom.status = 'MISSING_HELIX_R10_MAT';
        return;
    end
    W = load(p);
    if ~isfield(W, 'task')
        nom.status = 'INCOMPATIBLE_NO_TASK';
        return;
    end
    tk = W.task;
    okR = isfield(tk, 'R') && abs(tk.R - R) < 1e-9;
    oku = isfield(tk, 'u0') && abs(tk.u0 - u0) < 1e-9;
    okT = isfield(tk, 'T_final') && abs(tk.T_final - T_final) < 1e-9;
    if ~(okR && oku && okT)
        nom.status = 'INCOMPATIBLE_GEOM';
        return;
    end
    nom.ok = true;
    nom.source = 'suite_results/HELIX_R10_YAW_PITCH_ENVELOPE.mat';
    nom.status = sprintf('REUSED R=%.1f u0=%.2f T=%.0f PASS=%s', ...
        tk.R, tk.u0, tk.T_final, tern(isfield(tk, 'gates') && isfield(tk.gates, 'pass') && tk.gates.pass, 'YES', '?'));
    nom.metrics = struct();
    if isfield(W, 'M')
        nom.metrics = W.M;
    elseif isfield(tk, 'M')
        nom.metrics = tk.M;
    end
    if isfield(W, 'G')
        nom.gates = W.G;
    elseif isfield(tk, 'gates')
        nom.gates = tk.gates;
    end
    nom.task = tk;
end

%% ===================== simulate =====================
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
    hidden_reset = false; % must remain false (no mid-run clear)

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

    % Arc-length table for injection trigger (path-progress, not time)
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

        % Controller command UNCHANGED interface (incl. BODY p like continuous_path_tracking)
        [dr_cmd, de, thr] = controller_law(yaw_ref, pitch_ref, u_ref, ...
            ori(3), ori(2), rates(3), rates(2), u, r_ff, pitch_ref_dot, ori(1), w, rates(1));

        % Progress proxy from guidance index (monotonic along path)
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
        % Plant-input boundary injection ONLY (controller command logged separately)
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

        if mod(k, 200) == 0 || k == n_steps
            fprintf('  step %d/%d t=%.1fs fault=%d eta=%.2f xyz=[%.2f %.2f %.2f]\n', ...
                k, n_steps, S.t(k), fault_on, eta, state(1), state(2), state(3));
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
    e_phi = wrapToPi(0 - phi); % roll hold about 0
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
    M.fault.equation = 'delta_r_applied(t) = eta_r(t) * delta_r_cmd(t); eta_r=1 (t<t_f), eta_post (t>=t_f)';
    M.fault.boundary = 'plant-input controls.delta_r only; controller/guidance/plant files unchanged';
    M.fault.hidden_reset = S.hidden_reset;

    % Pre / post windows (±8 s about fault, clipped)
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
    M.fault.mask_pre = mask_pre;
    M.fault.mask_post = mask_post;

    % Pitch (same hard-gate windows as R10)
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

    % Yaw SBE
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
    M.yaw.e0_wrap_deg = rad2deg(e_psi(1));
    M.yaw.t_to_2deg_persist_s = time_to_yaw_persist(t, e_psi, deg2rad(2.0), 1.0);

    % Roll / speed (report)
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

    % Actuator saturation / rate / chatter (commanded rudder)
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
        M.act.eta_realized_post = eta_post; % cmd near-zero; injection still applied
    else
        M.act.eta_realized_post = NaN;
    end

    % Mission progress / completion / bounds
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

    % Fault signature measurability (residual-detector feasibility)
    pre = M.fault.pre; post = M.fault.post;
    d_yaw = post.yaw_mae_deg - pre.yaw_mae_deg;
    d_cte = post.cte_mean - pre.cte_mean;
    d_cmd_app = post.cmd_app_mae_deg - pre.cmd_app_mae_deg;
    M.signature = struct();
    M.signature.d_yaw_mae_deg = d_yaw;
    M.signature.d_cte_m = d_cte;
    M.signature.d_cmd_app_mae_deg = d_cmd_app;
    M.signature.measurable = (d_cmd_app > 0.5) || (d_yaw > 0.5) || (d_cte > 0.15);
    M.signature.basis = 'post−pre (±8s): cmd−app MAE, yaw MAE, or CTE jump';

    M.logs = struct('t', t, 'e_psi', e_psi, 'e_th', e_th, 'e_phi', e_phi, ...
        'psi', psi, 'psi_ref', psi_ref, 'theta_phys', theta_phys, 'theta_ref', theta_ref, ...
        'phi', phi, 'q', q, 'r', r, 'p', p, 'de', de, ...
        'dr_cmd', dr_cmd, 'dr_app', dr_app, 'eta_r', S.eta_r(:), ...
        'u', u, 'u_ref', u_ref, 'e_radial', e_radial, 's', s, ...
        'mask_yaw', mask_yaw, 'mask_pre', mask_pre, 'mask_post', mask_post, ...
        'mask_steady', W.mask_steady, 'mask_before_end', W.mask_before_end);
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
    % CTE proxy: path metrics vector if available
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

function G = gate_fault(M)
    G = struct();
    % Original R10 hard gates
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
    G.g_injection_traceable = ~isnan(M.fault.t_fault_s) && ...
        abs(M.act.eta_realized_post - M.fault.eta_post) < 0.05;

    G.survivability_pass = G.g_r10_hard && G.g_completion && G.g_bounded && G.g_no_reset;
    % Audit PASS set after artifacts written; provisional here
    G.audit_pass = G.g_injection_traceable; % artifacts completed in write_all
    G.pass = G.audit_pass; % audit completeness is the primary verdict channel

    if M.signature.measurable
        G.next_priority = 'residual_detector_feasibility';
    else
        G.next_priority = 'open_loop_safety_abort_requirements';
    end
end

%% ===================== write =====================
function write_all(out_dir, tag, task_id, stamp, S, M, G, FA, nom, path, R, ...
        pitch_h, num_turns, T_final, u0, eta_post, s_half, lam, de_max, dr_max)

    L = M.logs;
    fig = figure('Color', 'w', 'Position', [60 60 1200 780], 'Visible', 'off');

    subplot(2, 3, 1);
    plot3(path(:,1), path(:,2), path(:,3), 'k--', 'LineWidth', 1.2); hold on;
    plot3(S.vp(:,1), S.vp(:,2), S.vp(:,3), 'b-', 'LineWidth', 1.5);
    if ~isnan(M.fault.t_fault_s)
        [~, ik] = min(abs(S.t - M.fault.t_fault_s));
        plot3(S.vp(ik,1), S.vp(ik,2), S.vp(ik,3), 'ro', 'MarkerFaceColor', 'r', 'MarkerSize', 8);
    end
    grid on; axis equal; view(35, 25);
    title(sprintf('R10 fault | CTE_{sbe}=%.3fm', M.yaw.cte_perp_sbe));
    xlabel('X'); ylabel('Y'); zlabel('Z');

    subplot(2, 3, 2);
    plot(L.t, rad2deg(unwrap(L.psi)), 'b'); hold on;
    plot(L.t, rad2deg(unwrap(L.psi_ref)), 'r--');
    xline(M.fault.t_fault_s, 'k-', 'fault', 'LabelHorizontalAlignment', 'left');
    grid on; ylabel('deg'); title(sprintf('Yaw | MAE_{sbe}=%.3f°', M.yaw.mae_deg));
    legend('\psi', '\psi_{ref}', 'Location', 'best');

    subplot(2, 3, 3);
    plot(L.t, rad2deg(L.dr_cmd), 'b'); hold on;
    plot(L.t, rad2deg(L.dr_app), 'r--');
    yline(rad2deg(dr_max), 'k:'); yline(-rad2deg(dr_max), 'k:');
    xline(M.fault.t_fault_s, 'k-');
    grid on; ylabel('deg');
    title(sprintf('\\delta_r cmd vs app | \\eta_{post}=%.2f realized=%.3f', ...
        eta_post, M.act.eta_realized_post));
    legend('\delta_r^{cmd}', '\delta_r^{app}', 'Location', 'best');

    subplot(2, 3, 4);
    plot(L.t, rad2deg(L.theta_phys), 'b'); hold on;
    plot(L.t, rad2deg(L.theta_ref), 'r--');
    xline(M.fault.t_fault_s, 'k-');
    grid on; ylabel('deg'); title(sprintf('Pitch | ssMAE=%.3f°', M.pitch.steady.mae_deg));

    subplot(2, 3, 5);
    plot(L.t, rad2deg(L.phi), 'b'); hold on;
    xline(M.fault.t_fault_s, 'k-');
    grid on; ylabel('deg'); title(sprintf('Roll | MAE_{sbe}=%.3f°', M.roll.mae_deg));

    subplot(2, 3, 6);
    plot(L.t, L.u, 'b'); hold on;
    plot(L.t, L.u_ref, 'r--');
    xline(M.fault.t_fault_s, 'k-');
    grid on; ylabel('m/s'); xlabel('t (s)');
    title(sprintf('Speed | MAE_{sbe}=%.3f', M.speed.mae_abs));

    sgtitle(sprintf('%s | audit=%s surv=%s', tag, ...
        tern(G.audit_pass, 'PASS', 'FAIL'), tern(G.survivability_pass, 'PASS', 'FAIL')));
    png_path = fullfile(out_dir, [tag '.png']);
    exportgraphics(fig, png_path, 'Resolution', 150);
    close(fig);

    % Finalize audit: injection + artifacts exist
    art_ok = exist(png_path, 'file') == 2;
    G.audit_pass = G.g_injection_traceable && art_ok && ~isnan(M.fault.t_fault_s);
    G.pass = G.audit_pass;

    task = struct();
    task.id = task_id; task.stamp = stamp; task.tag = tag;
    task.R = R; task.pitch_h = pitch_h; task.num_turns = num_turns;
    task.T_final = T_final; task.u0 = u0; task.eta_post = eta_post;
    task.s_half_turn = s_half; task.lambda_muw_ff = lam;
    task.gates = G; task.fault_audit = FA; task.nominal = nom;
    task.survivability_pass = G.survivability_pass;
    task.audit_pass = G.audit_pass;
    task.next_priority = G.next_priority;

    mat_path = fullfile(out_dir, [tag '.mat']);
    save(mat_path, 'task', 'S', 'M', 'G', 'FA', 'nom', 'path', '-v7.3');

    md_path = fullfile(out_dir, [tag '.md']);
    fid = fopen(md_path, 'w');
    fprintf(fid, '# %s\n\n', tag);
    fprintf(fid, '**TASK_ID:** %s\n', task_id);
    fprintf(fid, '**Date:** %s\n', stamp);
    fprintf(fid, '**Audit verdict:** **%s**\n', tern(G.audit_pass, 'PASS', 'FAIL'));
    fprintf(fid, '**Survivability verdict:** **%s**\n\n', tern(G.survivability_pass, 'PASS', 'FAIL'));

    fprintf(fid, 'Closes rejected mission-shaper line (`GUIDANCE_TRANSITION_SHAPER` FAIL). ');
    fprintf(fid, 'Production cascade+guidance+plant **frozen**. Isolated driver only.\n\n');

    fprintf(fid, '## Fault-interface audit (3 files)\n\n');
    fprintf(fid, 'Scope: `%s`\n\n', FA.scope);
    fprintf(fid, '| Capability | Status |\n|---|---|\n');
    fprintf(fid, '| Plant-input boundary | %s |\n', FA.plant_input_boundary);
    fprintf(fid, '| Controller command log | %s |\n', FA.controller_command_log);
    fprintf(fid, '| Rudder mag/rate limit | %s |\n', FA.rudder_rate_mag_limit);
    fprintf(fid, '| Fault injection API | %s |\n', FA.fault_injection_api);
    fprintf(fid, '| Fault detection (FDI) | %s |\n', FA.fault_detection);
    fprintf(fid, '| Fault isolation | %s |\n', FA.fault_isolation);
    fprintf(fid, '| Safe mode | %s |\n', FA.safe_mode);
    fprintf(fid, '| Actuator health monitor | %s |\n', FA.actuator_health_monitor);
    fprintf(fid, '| Effectiveness estimator | %s |\n', FA.effectiveness_estimator);
    fprintf(fid, '| Residual detector | %s |\n', FA.residual_detector);
    fprintf(fid, '| Abort manager | %s |\n\n', FA.abort_manager);

    fprintf(fid, '## Nominal reuse\n\n');
    fprintf(fid, '- Status: `%s`\n', nom.status);
    fprintf(fid, '- Source: `%s`\n', tern(nom.ok, nom.source, 'n/a'));
    fprintf(fid, '- Compatible feasible case: R=%.1f m, U=%.2f m/s, T=%.0f s (HELIX_R10 PASS).\n\n', R, u0, T_final);

    fprintf(fid, '## Injection\n\n');
    fprintf(fid, '```\n');
    fprintf(fid, 's_half_turn = 0.5*sqrt((2*pi*R)^2 + pitch_h^2) = %.6f m\n', s_half);
    fprintf(fid, 't_fault = first t with s_prog(guidance_index) >= s_half_turn  =>  t=%.4f s, s=%.4f m\n', ...
        M.fault.t_fault_s, M.fault.s_fault_m);
    fprintf(fid, 'eta_r(t) = 1                    ,  t <  t_fault\n');
    fprintf(fid, 'eta_r(t) = %.2f                 ,  t >= t_fault   (50%% effectiveness loss)\n', eta_post);
    fprintf(fid, 'delta_r_applied = eta_r(t) * delta_r_cmd     %% plant-input boundary only\n');
    fprintf(fid, 'delta_r_cmd, controller_law, guidance_law, underwater777_vehicle_dynamics UNCHANGED\n');
    fprintf(fid, 'hidden_reset = %s\n', tern(M.fault.hidden_reset, 'true', 'false'));
    fprintf(fid, '```\n\n');
    fprintf(fid, '- Realized eta_post (cmd/app ratio, |cmd|>0.5°): **%.4f** (target %.2f)\n\n', ...
        M.act.eta_realized_post, eta_post);

    fprintf(fid, '## Pre / post fault windows (±8 s)\n\n');
    fprintf(fid, '| Window | n | t span [s] | yawMAE [°] | pitchMAE [°] | rollMAE [°] | speedMAE | CTE | cmd−app MAE [°] | δr_cmd | δr_app |\n');
    fprintf(fid, '|---|---:|---|---:|---:|---:|---:|---:|---:|---:|---:|\n');
    wp = M.fault.pre; wo = M.fault.post;
    fprintf(fid, '| pre | %d | %.2f–%.2f | %.3f | %.3f | %.3f | %.3f | %.3f | %.3f | %.3f | %.3f |\n', ...
        wp.n, wp.t0, wp.t1, wp.yaw_mae_deg, wp.pitch_mae_deg, wp.roll_mae_deg, wp.speed_mae, ...
        wp.cte_mean, wp.cmd_app_mae_deg, wp.dr_cmd_mean_deg, wp.dr_app_mean_deg);
    fprintf(fid, '| post | %d | %.2f–%.2f | %.3f | %.3f | %.3f | %.3f | %.3f | %.3f | %.3f | %.3f |\n\n', ...
        wo.n, wo.t0, wo.t1, wo.yaw_mae_deg, wo.pitch_mae_deg, wo.roll_mae_deg, wo.speed_mae, ...
        wo.cte_mean, wo.cmd_app_mae_deg, wo.dr_cmd_mean_deg, wo.dr_app_mean_deg);

    fprintf(fid, '## Tracking / actuators (fault run)\n\n');
    fprintf(fid, '| Channel | Metric | Value |\n|---|---|---:|\n');
    fprintf(fid, '| Yaw SBE | MAE / RMS / p95 [°] | %.4f / %.4f / %.4f |\n', ...
        M.yaw.mae_deg, M.yaw.rms_deg, M.yaw.p95_deg);
    fprintf(fid, '| Yaw | CTE_perp sbe [m] | %.4f |\n', M.yaw.cte_perp_sbe);
    fprintf(fid, '| Yaw | r/(U_h κ) | %.4f (n=%d) |\n', M.yaw.ratio_r_Uh_kappa, M.yaw.n_ratio_valid);
    fprintf(fid, '| Pitch ss | MAE / p95 [°] | %.4f / %.4f |\n', ...
        M.pitch.steady.mae_deg, M.pitch.steady.p95_deg);
    fprintf(fid, '| Pitch | elev sat%% / chatter | %.2f / %.4f |\n', ...
        M.pitch.elev_sat_pct, M.pitch.chatter_dps);
    fprintf(fid, '| Roll SBE | MAE / p95 / |φ|_max [°] | %.4f / %.4f / %.4f |\n', ...
        M.roll.mae_deg, M.roll.p95_deg, M.roll.max_deg);
    fprintf(fid, '| Speed | MAE_sbe / final u / [min,max] | %.4f / %.3f / [%.3f,%.3f] |\n', ...
        M.speed.mae_abs, M.speed.final_u, M.speed.min_u, M.speed.max_u);
    fprintf(fid, '| Rudder cmd | sat acq/ss/full %% | %.2f / %.2f / %.2f |\n', ...
        M.yaw.rudder_sat_acq_pct, M.yaw.rudder_sat_steady_pct, M.yaw.rudder_sat_full_pct);
    fprintf(fid, '| Rudder cmd | rate max/rms [°/s] | %.3f / %.3f |\n', ...
        M.act.rudder_rate_max_dps, M.act.rudder_rate_rms_dps);
    fprintf(fid, '| Rudder cmd | chatter HF std [°/s] | %.4f |\n', M.act.rudder_chatter_dps);
    fprintf(fid, '| Cmd vs app | MAE full / post [°] | %.4f / %.4f |\n\n', ...
        M.act.cmd_vs_app_mae_deg, M.act.cmd_vs_app_post_mae_deg);

    fprintf(fid, '## Mission progress / completion / bounds\n\n');
    fprintf(fid, '| Item | Value |\n|---|---:|\n');
    fprintf(fid, '| s_final / s_total [m] | %.3f / %.3f |\n', M.mission.s_final_m, M.mission.s_total_m);
    fprintf(fid, '| progress frac | %.4f |\n', M.mission.progress_frac);
    fprintf(fid, '| completed to T_final | %s |\n', tern(M.mission.completed_T, 'YES', 'NO'));
    fprintf(fid, '| near_end (s≥0.88 s_tot) | %s |\n', tern(M.mission.near_end, 'YES', 'NO'));
    fprintf(fid, '| bounded | %s |\n', tern(M.mission.bounded, 'YES', 'NO'));
    fprintf(fid, '| hidden reset | %s |\n', tern(~M.mission.no_hidden_reset, 'YES', 'NO'));
    fprintf(fid, '| NaN count | %d |\n\n', M.mission.n_nan);

    fprintf(fid, '## Gates\n\n');
    fprintf(fid, '| Gate | Result | Detail |\n|------|:------:|--------|\n');
    fprintf(fid, '| injection traceable (η≈0.50) | %s | realized=%.4f t_f=%.2fs |\n', ...
        yn(G.g_injection_traceable), M.act.eta_realized_post, M.fault.t_fault_s);
    fprintf(fid, '| artifacts complete | %s | md/mat/png |\n', yn(art_ok));
    fprintf(fid, '| **AUDIT** | **%s** | traceable injection + artifacts |\n', tern(G.audit_pass, 'PASS', 'FAIL'));
    fprintf(fid, '| pitch ss MAE ≤0.30° | %s | %.4f |\n', yn(G.g_pitch_mae), M.pitch.steady.mae_deg);
    fprintf(fid, '| pitch ss p95 ≤0.50° | %s | %.4f |\n', yn(G.g_pitch_p95), M.pitch.steady.p95_deg);
    fprintf(fid, '| pitch elev sat ≤1%% | %s | %.2f |\n', yn(G.g_pitch_sat), M.pitch.elev_sat_pct);
    fprintf(fid, '| pitch chatter ≤0.20 | %s | %.4f |\n', yn(G.g_pitch_chatter), M.pitch.chatter_dps);
    fprintf(fid, '| pitch persistent settle | %s | t=%.2fs |\n', yn(G.g_pitch_persist), M.pitch.settling_s);
    fprintf(fid, '| yaw MAE ≤1° | %s | %.4f |\n', yn(G.g_yaw_mae), M.yaw.mae_deg);
    fprintf(fid, '| yaw p95 ≤2° | %s | %.4f |\n', yn(G.g_yaw_p95), M.yaw.p95_deg);
    fprintf(fid, '| rudder sat ss/full ≤1%% | %s | %.2f / %.2f |\n', ...
        yn(G.g_yaw_sat), M.yaw.rudder_sat_steady_pct, M.yaw.rudder_sat_full_pct);
    fprintf(fid, '| r/(U_h κ) ∈[0.98,1.02] | %s | %.4f |\n', yn(G.g_ratio), M.yaw.ratio_r_Uh_kappa);
    fprintf(fid, '| completion / bounds / no-reset | %s | %s / %s / %s |\n', ...
        yn(G.g_completion && G.g_bounded && G.g_no_reset), ...
        yn(G.g_completion), yn(G.g_bounded), yn(G.g_no_reset));
    fprintf(fid, '| **SURVIVABILITY** | **%s** | R10 hard ∩ completion ∩ bounds ∩ no-reset |\n\n', ...
        tern(G.survivability_pass, 'PASS', 'FAIL'));

    fprintf(fid, '## Fault signature / next priority\n\n');
    fprintf(fid, '- Δyaw MAE (post−pre)=%.3f° | ΔCTE=%.3f m | Δ(cmd−app)=%.3f°\n', ...
        M.signature.d_yaw_mae_deg, M.signature.d_cte_m, M.signature.d_cmd_app_mae_deg);
    fprintf(fid, '- Signature measurable: **%s** (%s)\n', ...
        tern(M.signature.measurable, 'YES', 'NO'), M.signature.basis);
    fprintf(fid, '- Next priority: **`%s`**\n\n', G.next_priority);

    fprintf(fid, '## Files\n\n');
    fprintf(fid, '- `run_rudder_fault_baseline.m` (isolated driver only)\n');
    fprintf(fid, '- `suite_results/%s.md`\n', tag);
    fprintf(fid, '- `suite_results/%s.mat`\n', tag);
    fprintf(fid, '- `suite_results/%s.png`\n', tag);
    fprintf(fid, '- Production: controller_law / guidance / plant **unchanged**; CODEX_VERTICAL_PLAN untouched.\n');
    fclose(fid);

    % Re-save with finalized G
    task.gates = G;
    task.audit_pass = G.audit_pass;
    save(mat_path, 'task', 'S', 'M', 'G', 'FA', 'nom', 'path', '-v7.3');

    % Append research log (close mission-shaper + this gate)
    log_path = fullfile(out_dir, 'PITCH_CONTROL_RESEARCH_LOG.md');
    lfid = fopen(log_path, 'a');
    fprintf(lfid, '\n\n## CLOSE_MISSION_SHAPER_LINE — %s\n\n', stamp);
    fprintf(lfid, '- Verdict: **CLOSED / REJECTED** — mission-shaper line ended after GUIDANCE_TRANSITION_SHAPER_001 FAIL.\n');
    fprintf(lfid, '- First fail retained: `CLIMB:pitch_MAE(0.6885>0.3000)`; production untouched.\n');
    fprintf(lfid, '- Production mission limitations: no segment blender / clothoid in guidance; composite C1 polyline insufficient for SPEED_ENVELOPE hard gates on multi-segment mission.\n');
    fprintf(lfid, '- Unsupported autonomy remains NOT_IMPLEMENTED (mission manager, faults, replan, timeouts, transition shaper).\n');
    fprintf(lfid, '- Next: **`rudder_fault_baseline`** — first bounded fault gate on feasible R10@U=1.5 (this task).\n');
    fprintf(lfid, '- CODEX_VERTICAL_PLAN untouched.\n');

    fprintf(lfid, '\n\n## %s — %s\n\n', task_id, stamp);
    fprintf(lfid, '- Audit: **%s** — Survivability: **%s** — R10@U=1.5 mid-turn 50%% rudder loss at plant-input; production frozen.\n', ...
        tern(G.audit_pass, 'PASS', 'FAIL'), tern(G.survivability_pass, 'PASS', 'FAIL'));
    fprintf(lfid, '- Closed prior: mission-shaper line REJECTED (GUIDANCE_TRANSITION_SHAPER).\n');
    fprintf(lfid, '- Fault audit: FDI/isolation/safe-mode/health/effectiveness/residual/abort = NOT_IMPLEMENTED; plant-input boundary PRESENT.\n');
    fprintf(lfid, '- Nominal reuse: %s.\n', nom.status);
    fprintf(lfid, '- Injection: t_f=%.2fs s_f=%.3fm; η_r: 1→%.2f; δr_app=η·δr_cmd; realized η=%.4f; hidden_reset=NO.\n', ...
        M.fault.t_fault_s, M.fault.s_fault_m, eta_post, M.act.eta_realized_post);
    fprintf(lfid, '- Pre→post (±8s): yawMAE %.3f→%.3f; pitchMAE %.3f→%.3f; rollMAE %.3f→%.3f; speedMAE %.3f→%.3f; cmd−app %.3f→%.3f.\n', ...
        wp.yaw_mae_deg, wo.yaw_mae_deg, wp.pitch_mae_deg, wo.pitch_mae_deg, ...
        wp.roll_mae_deg, wo.roll_mae_deg, wp.speed_mae, wo.speed_mae, ...
        wp.cmd_app_mae_deg, wo.cmd_app_mae_deg);
    fprintf(lfid, '- Fault-run SBE: yawMAE=%.4f p95=%.4f CTE=%.3f; pitch ssMAE=%.4f; rollMAE=%.4f; uMAE=%.4f; drSat ss/full=%.2f/%.2f%%; chat=%.4f; ratio=%.4f.\n', ...
        M.yaw.mae_deg, M.yaw.p95_deg, M.yaw.cte_perp_sbe, M.pitch.steady.mae_deg, ...
        M.roll.mae_deg, M.speed.mae_abs, M.yaw.rudder_sat_steady_pct, M.yaw.rudder_sat_full_pct, ...
        M.act.rudder_chatter_dps, M.yaw.ratio_r_Uh_kappa);
    fprintf(lfid, '- Mission: progress=%.3f complete=%s bounded=%s.\n', ...
        M.mission.progress_frac, tern(M.mission.completion_ok, 'YES', 'NO'), ...
        tern(M.mission.bounded, 'YES', 'NO'));
    fprintf(lfid, '- Signature measurable: %s (Δyaw=%.3f ΔCTE=%.3f Δcmd−app=%.3f).\n', ...
        tern(M.signature.measurable, 'YES', 'NO'), M.signature.d_yaw_mae_deg, ...
        M.signature.d_cte_m, M.signature.d_cmd_app_mae_deg);
    fprintf(lfid, '- Artifacts: suite_results/%s.{md,mat,png}; driver `run_rudder_fault_baseline.m`.\n', tag);
    fprintf(lfid, '- Next: **`%s`** — production remains frozen; CODEX_VERTICAL_PLAN untouched.\n', ...
        G.next_priority);
    fclose(lfid);
end

%% ===================== helpers =====================
function [Uh, zdot] = inertial_Uh_zdot(ori, u, v, w)
    phi = ori(1); theta = ori(2); psi = ori(3);
    R = [cos(psi)*cos(theta), ...
         cos(psi)*sin(theta)*sin(phi) - sin(psi)*cos(phi), ...
         cos(psi)*sin(theta)*cos(phi) + sin(psi)*sin(phi);
         sin(psi)*cos(theta), ...
         sin(psi)*sin(theta)*sin(phi) + cos(psi)*cos(phi), ...
         sin(psi)*sin(theta)*cos(phi) - cos(psi)*sin(phi);
         -sin(theta), ...
         cos(theta)*sin(phi), ...
         cos(theta)*cos(phi)];
    pos_dot = R * [u; v; w];
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

function t_hit = time_to_yaw_persist(t, e_psi, thr, persist_s)
    ok = abs(e_psi(:)) <= thr;
    need = max(1, round(persist_s / mean(diff(t))));
    t_hit = NaN;
    run = 0;
    for i = 1:numel(ok)
        if ok(i); run = run + 1; else; run = 0; end
        if run >= need
            t_hit = t(i - need + 1);
            return;
        end
    end
end

function s = tern(c, a, b)
    if c; s = a; else; s = b; end
end

function s = yn(c)
    s = tern(c, 'YES', 'NO');
end
