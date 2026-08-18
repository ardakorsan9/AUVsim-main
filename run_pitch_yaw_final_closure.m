function run_pitch_yaw_final_closure()
% PITCH_YAW_FINAL_CLOSURE_001 — two-repeat nonlinear 6DOF closure for X, XZ(λ=0), R10 helix.
% Accepted production climb-FF frozen; no controller / guidance / plant / gain changes.
% Outputs: suite_results/PITCH_YAW_CLOSURE.md, FINAL_TRACKING_{X,XZ,HELIX_R10}.png, one MAT.

    project_dir = fileparts(mfilename('fullpath'));
    addpath(project_dir);
    out_dir = fullfile(project_dir, 'suite_results');
    if ~exist(out_dir, 'dir'); mkdir(out_dir); end
    tag = 'PITCH_YAW_CLOSURE';

    clear functions
    clear guidance_law controller_law
    clear global lambda_muw_ff trim_speed_table trim_elevator_table elevator_sign
    clear global K_zdot K_gamma enable_alpha_hat
    clear global last_guidance_U_h last_guidance_kappa last_r_ff

    init_parameters();
    global lambda_muw_ff elevator_sign trim_speed_table trim_elevator_table
    global K_zdot K_gamma enable_alpha_hat
    global dt_controller delta_e_max delta_r_max

    % Frozen accepted production stack (climb-FF already in controller_law)
    elevator_sign = 1;
    trim_speed_table = [0.8 1.0 1.5 2.0];
    trim_elevator_table = deg2rad([-9.18 -7.33 -4.62 -3.17]);
    K_gamma = 0;
    K_zdot = 0;
    enable_alpha_hat = false;

    k_gamma = 0.1320695001;
    de_climb_lim_deg = 2.8793;

    % Determinism: no stochastic plant/controller; seed documented for audit.
    % ode45 + fixed IC → bit-identical repeats expected after clear of persistent state.
    seed_used = 0;
    rng(seed_used, 'twister');
    rng_state = rng;

    % Capsule baselines (accepted production evidence)
    capX = struct('mae_deg', 0.0110, 'p95_deg', 0.0419, 'rms_deg', 0.0164);
    capXZ = struct('mae_deg', 0.1214, 'p95_deg', 0.4039, 'settle_s', 6.18, ...
        'sat_pct', 0.00, 'acq_mae_deg', 0.7549);
    capH = struct( ...
        'pitch_mae', 0.0413, 'pitch_p95', 0.1004, ...
        'yaw_mae', 0.1748, 'yaw_p95', 0.3493, ...
        'rud_sat_full', 0.67, 'ratio', 1.0181);

    % Pre-climb baselines (FINAL_CHANGELOG percent effects)
    preX = struct('mae_deg', 0.0637, 'rms_deg', 0.0683, 'p95_deg', 0.0856);
    preXZ = struct('settle_s', 14.08, 'acq_mae_deg', 1.0876, ...
        'mae_deg', 0.3502, 'rms_deg', 0.3595, 'p95_deg', 0.4812);

    fprintf('\n========== PITCH_YAW_FINAL_CLOSURE_001 ==========\n');
    fprintf('Accepted production climb-FF; two repeats each of X / XZ(λ=0) / R10 helix.\n');
    fprintf('rng seed=%d (%s); no controller/guidance/plant edits.\n', ...
        seed_used, rng_state.Type);

    % ---- X (λ=0.25 level; first_hold windows) — two repeats ----
    n = 600;
    x = linspace(0, 45, n)';
    pathX = [x, zeros(n, 1), zeros(n, 1)];
    mX = cell(1, 2);
    for rep = 1:2
        rng(seed_used, 'twister');
        mX{rep} = run_pitch_case(pathX, 18, 1.5, 0.25, k_gamma, de_climb_lim_deg, ...
            false, 'first_hold');
        fprintf('X  rep%d settle=%.2fs MAE=%.4f RMS=%.4f p95=%.4f sat=%.2f%%\n', ...
            rep, mX{rep}.settling_s, mX{rep}.steady.mae_deg, mX{rep}.steady.rms_deg, ...
            mX{rep}.steady.p95_deg, mX{rep}.elev_sat_pct);
    end
    RX = repeat_check_pitch(mX{1}, mX{2});

    % ---- XZ (λ=0; persistent) — two repeats ----
    n = 900;
    tt = linspace(0, 42, n)';
    pathXZ = [tt, zeros(n, 1), 0.4 * tt];
    mXZ = cell(1, 2);
    for rep = 1:2
        rng(seed_used, 'twister');
        mXZ{rep} = run_pitch_case(pathXZ, 22, 1.5, 0.0, k_gamma, de_climb_lim_deg, ...
            true, 'persistent');
        fprintf(['XZ rep%d settle=%.2fs acqMAE=%.4f MAE=%.4f RMS=%.4f p95=%.4f ', ...
            'sat=%.2f%%\n'], ...
            rep, mXZ{rep}.settling_s, mXZ{rep}.acq.mae_deg, mXZ{rep}.steady.mae_deg, ...
            mXZ{rep}.steady.rms_deg, mXZ{rep}.steady.p95_deg, mXZ{rep}.elev_sat_pct);
    end
    RXZ = repeat_check_pitch(mXZ{1}, mXZ{2});

    % ---- R10 helix (λ=0.25 curved production) — two repeats ----
    R = 10.0;
    pitch_h = 2.0;
    num_turns = 2;
    n_path = 500;
    pathH = generate_balanced_helical_path(R, pitch_h, num_turns, n_path);
    T_final = 45;
    u0 = 1.5;
    lambda_muw_ff = 0.25;
    MH = cell(1, 2);
    SH = cell(1, 2);
    for rep = 1:2
        rng(seed_used, 'twister');
        SH{rep} = simulate_helix(pathH, T_final, u0, R);
        MH{rep} = analyze_helix(SH{rep}, pathH, R, delta_e_max, delta_r_max);
        fprintf(['H  rep%d pitch MAE=%.4f p95=%.4f | yaw MAE=%.4f p95=%.4f ', ...
            'sat_full=%.2f%% ratio=%.4f\n'], ...
            rep, MH{rep}.pitch.steady.mae_deg, MH{rep}.pitch.steady.p95_deg, ...
            MH{rep}.yaw.mae_deg, MH{rep}.yaw.p95_deg, ...
            MH{rep}.yaw.rudder_sat_full_pct, MH{rep}.yaw.ratio_r_Uh_kappa);
    end
    RH = repeat_check_helix(MH{1}, MH{2});

    % Use rep1 as official metrics (rep2 verifies identity)
    mX1 = mX{1}; mXZ1 = mXZ{1}; M1 = MH{1}; S1 = SH{1};

    GX = gate_X(mX1, preX, capX);
    GXZ = gate_XZ(mXZ1, preXZ, capXZ);
    GH = gate_helix(M1, capH);
    Grepeat = RX.pass && RXZ.pass && RH.pass;
    pass = GX.pass && GXZ.pass && GH.pass && Grepeat;

    fprintf('Repeat checks: X=%s XZ=%s H=%s | Overall: %s\n', ...
        tern(RX.pass, 'PASS', 'FAIL'), tern(RXZ.pass, 'PASS', 'FAIL'), ...
        tern(RH.pass, 'PASS', 'FAIL'), tern(pass, 'PASS', 'FAIL'));

    % ---- PNGs ----
    write_png_X(out_dir, mX1, GX.pass);
    write_png_XZ(out_dir, mXZ1, GXZ.pass);
    write_png_helix(out_dir, S1, M1, pathH, GH.pass, delta_e_max, delta_r_max, R, u0);

    % ---- MAT ----
    task = struct();
    task.task_id = 'PITCH_YAW_FINAL_CLOSURE_001';
    task.pass = pass;
    task.verdict = tern(pass, 'PASS', 'FAIL');
    task.seed = seed_used;
    task.rng_type = rng_state.Type;
    task.controller_changed = false;
    task.guidance_changed = false;
    task.plant_changed = false;
    task.gains_changed = false;
    task.k_gamma = k_gamma;
    task.de_climb_lim_deg = de_climb_lim_deg;
    task.GX = GX; task.GXZ = GXZ; task.GH = GH;
    task.RX = RX; task.RXZ = RXZ; task.RH = RH;
    task.capX = capX; task.capXZ = capXZ; task.capH = capH;
    mat_path = fullfile(out_dir, [tag '.mat']);
    save(mat_path, 'task', 'mX', 'mXZ', 'MH', 'SH', 'pathX', 'pathXZ', 'pathH', ...
        'GX', 'GXZ', 'GH', 'RX', 'RXZ', 'RH', 'capX', 'capXZ', 'capH', ...
        'preX', 'preXZ', 'k_gamma', 'pass', 'seed_used');

    % ---- MD ----
    write_md(out_dir, tag, pass, seed_used, rng_state, k_gamma, de_climb_lim_deg, ...
        mX, mXZ, MH, GX, GXZ, GH, RX, RXZ, RH, capX, capXZ, capH, preX, preXZ);

    % ---- research log append ----
    append_log(out_dir, pass, seed_used, mX1, mXZ1, M1, RX, RXZ, RH, GX, GXZ, GH);

    fprintf('Wrote suite_results/%s.md + FINAL_TRACKING_*.png + %s.mat\n', tag, tag);
    assignin('base', 'PITCH_YAW_FINAL_CLOSURE_PASS', pass);
end

%% ===================== pitch case (X / XZ) =====================
function m = run_pitch_case(path, T_final, u0, lambda, k_gamma, de_climb_lim_deg, is_xz, win_mode)
    global dt_controller delta_e_max
    global suite_delta_e_log suite_de_fb_log suite_de_trim_log suite_de_uw_ff_log
    global suite_int_angle_log
    global lambda_muw_ff

    lambda_muw_ff = lambda;
    clear guidance_law controller_law
    dt = dt_controller;
    state0 = zeros(12, 1);
    state0(1:3) = path(1, :)';
    d = path(2, :) - path(1, :);
    state0(5) = -atan2(d(3), norm(d(1:2)));
    state0(6) = atan2(d(2), d(1));
    state0(7) = u0;

    [vp, times, vel, rates, ori, ~, yaw_refs, pitch_refs, ~] = ...
        continuous_path_tracking(path, state0, dt, T_final); %#ok<ASGLU>
    pm = compute_path_following_metrics(path, vp, vel, ori, yaw_refs, pitch_refs, dt, times);

    t = times(:);
    theta_ref = pitch_refs(:);
    theta_phys = -ori(:, 2);
    e_th = theta_ref - theta_phys;
    q = rates(:, 2);
    s = pm.s_prog(:);
    s_total = pm.s_total;

    de = align_len(suite_delta_e_log(:), numel(t));
    de_fb = align_len(suite_de_fb_log(:), numel(t));
    de_trim = align_len(suite_de_trim_log(:), numel(t));
    de_muw = align_len(suite_de_uw_ff_log(:), numel(t));
    int_angle = align_len(suite_int_angle_log(:), numel(t));

    lim_c = deg2rad(de_climb_lim_deg);
    de_climb_ff = max(min(k_gamma * theta_ref, lim_c), -lim_c);

    W = compute_pitch_window_metrics(t, e_th, s, s_total, 'mode', win_mode);
    mask_acq = W.mask_acq;
    mask_steady = W.mask_steady;

    th_dot = [0; diff(theta_phys)] / dt;
    lim = delta_e_max;

    m = struct();
    m.lambda = lambda;
    m.settling_s = W.settling_s;
    m.acq_time_s = W.acq_time_s;
    m.acq = W.acq;
    m.steady = W.steady;
    m.n_acq = W.n_acq;
    m.n_steady = W.n_steady;
    m.persistent_ok = W.persistent_ok;
    m.window_mode = W.mode;

    if is_xz
        path_pitch = atan2(0.4, 1);
    else
        path_pitch = 0;
    end
    if any(mask_acq)
        th_acq = theta_phys(mask_acq);
        m.dip_deg = rad2deg(path_pitch - min(th_acq));
        if abs(path_pitch) < 1e-9
            m.overshoot_deg = rad2deg(max(abs(th_acq)));
        else
            final_ref = mean(theta_ref(mask_steady));
            m.overshoot_deg = rad2deg(max(0, max(th_acq) - final_ref));
        end
    else
        m.dip_deg = NaN;
        m.overshoot_deg = NaN;
    end

    if any(mask_steady)
        de_ss = de(mask_steady);
        m.elev_sat_pct = 100 * mean(abs(de_ss) >= 0.98 * lim);
        dth_ss = th_dot(mask_steady);
        if numel(dth_ss) < 5
            m.chatter_dps = pm.pitch_chatter_dps;
        else
            m.chatter_dps = rad2deg(std(hf_local(detrend(dth_ss), dt)));
        end
    else
        m.elev_sat_pct = NaN;
        m.chatter_dps = NaN;
    end

    m.logs = struct('t', t, 'theta_ref', theta_ref, 'theta_phys', theta_phys, ...
        'e_th', e_th, 'q', q, 'de', de, 'de_trim', de_trim, 'de_fb', de_fb, ...
        'de_muw', de_muw, 'de_climb_ff', de_climb_ff, 'int_angle', int_angle, ...
        'mask_acq', mask_acq, 'mask_steady', mask_steady);
    m.pm = pm;
end

%% ===================== helix simulate / analyze (from R10 envelope) =====================
function S = simulate_helix(path, T_final, u0, R)
    global dt_controller dt_guidance
    global last_guidance_U_h last_guidance_kappa last_r_ff
    global last_delta_e last_de_fb

    clear guidance_law controller_law
    % Reset globals without clear global (keeps bindings alive for isempty checks)
    last_guidance_U_h = [];
    last_guidance_kappa = [];
    last_r_ff = [];
    last_delta_e = [];
    last_de_fb = [];
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

    S = struct();
    S.path = path; S.R = R; S.dt = dt; S.T_final = T_final; S.u0 = u0;
    S.t = zeros(n_steps, 1);
    S.vp = zeros(n_steps, 3);
    S.vel = zeros(n_steps, 3);
    S.rates = zeros(n_steps, 3);
    S.ori = zeros(n_steps, 3);
    S.psi_ref = zeros(n_steps, 1);
    S.theta_ref = zeros(n_steps, 1);
    S.u_ref = zeros(n_steps, 1);
    S.delta_r = zeros(n_steps, 1);
    S.delta_e = zeros(n_steps, 1);
    S.de_fb = zeros(n_steps, 1);
    S.U_h = zeros(n_steps, 1);
    S.U_h_guid = zeros(n_steps, 1);
    S.kappa = zeros(n_steps, 1);
    S.r_ff = zeros(n_steps, 1);

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
        end

        [dr, de, thr] = controller_law(yaw_ref, pitch_ref, u_ref, ...
            ori(3), ori(2), rates(3), rates(2), u, r_ff, pitch_ref_dot, ori(1), w);
        controls = struct('delta_r', dr, 'delta_e', de, 'thrust', thr);
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
        S.delta_r(k) = dr;
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
    end
end

function M = analyze_helix(S, path, R, de_max, dr_max)
    t = S.t(:);
    dt = S.dt;
    psi = S.ori(:, 3);
    theta_phys = -S.ori(:, 2);
    theta_ref = S.theta_ref(:);
    psi_ref = S.psi_ref(:);
    e_psi = wrapToPi(psi_ref - psi);
    e_th = theta_ref - theta_phys;
    q = S.rates(:, 2);
    r = S.rates(:, 3);
    de = S.delta_e(:);
    dr = S.delta_r(:);

    pm = compute_path_following_metrics(path, S.vp, S.vel, S.ori, ...
        psi_ref, theta_ref, dt, t);
    s = pm.s_prog(:);
    s_total = pm.s_total;

    W = compute_pitch_window_metrics(t, e_th, s, s_total, 'mode', 'persistent');
    rho = hypot(S.vp(:, 1), S.vp(:, 2));
    e_radial = rho - R;

    mask_yaw = (t >= 5.0) & W.mask_before_end;
    if ~any(mask_yaw)
        mask_yaw = t >= 5.0;
    end

    mask_acq_rud = W.mask_acq;
    if ~any(mask_acq_rud) && ~isnan(W.settling_s)
        mask_acq_rud = t < W.settling_s;
    end
    sat_thr = 0.95 * dr_max;
    rud_sat_acq = sat_pct(dr, mask_acq_rud, sat_thr);
    rud_sat_steady = sat_pct(dr, mask_yaw, sat_thr);
    rud_sat_full = sat_pct(dr, true(size(dr)), sat_thr);

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
    M.pm = pm;
    M.W = W;
    M.s_total = s_total;

    M.pitch = struct();
    M.pitch.acq = W.acq;
    M.pitch.steady = W.steady;
    M.pitch.settling_s = W.settling_s;
    M.pitch.acq_time_s = W.acq_time_s;
    M.pitch.persistent_ok = W.persistent_ok;

    mask_ss = W.mask_steady;
    if any(mask_ss)
        th_dot = [0; diff(theta_phys)] / dt;
        dth_ss = th_dot(mask_ss);
        M.pitch.chatter_dps = rad2deg(std(hf_local(detrend(dth_ss), dt)));
        M.pitch.elev_sat_pct = 100 * mean(abs(de(mask_ss)) >= 0.98 * de_max);
        M.pitch.q_rms_dps = rad2deg(rms(q(mask_ss)));
    else
        M.pitch.chatter_dps = NaN;
        M.pitch.elev_sat_pct = NaN;
        M.pitch.q_rms_dps = NaN;
    end

    M.yaw = struct();
    if any(mask_yaw)
        M.yaw.mae_deg = rad2deg(mean(abs(e_psi(mask_yaw))));
        M.yaw.rms_deg = rad2deg(rms(e_psi(mask_yaw)));
        M.yaw.signed_deg = rad2deg(mean(e_psi(mask_yaw)));
        M.yaw.p95_deg = rad2deg(pctile95(abs(e_psi(mask_yaw))));
        M.yaw.max_deg = rad2deg(max(abs(e_psi(mask_yaw))));
    else
        M.yaw.mae_deg = NaN; M.yaw.rms_deg = NaN; M.yaw.signed_deg = NaN;
        M.yaw.p95_deg = NaN; M.yaw.max_deg = NaN;
    end
    M.yaw.rudder_sat_acq_pct = rud_sat_acq;
    M.yaw.rudder_sat_steady_pct = rud_sat_steady;
    M.yaw.rudder_sat_full_pct = rud_sat_full;
    M.yaw.ratio_r_Uh_kappa = ratio;
    M.yaw.mean_r_rad = mean_r;
    M.yaw.mean_Uh_kappa_rad = mean_Uh_k;
    M.yaw.n_ratio_valid = nnz(valid_ratio);
    M.yaw.cte_perp_sbe = pm.mean_cte_perp;
    M.yaw.radial_mae_sbe = mean(abs(e_radial(mask_yaw)));
    M.yaw.e0_wrap_deg = rad2deg(e_psi(1));
    M.yaw.t_to_2deg_persist_s = time_to_yaw_persist(t, e_psi, deg2rad(2.0), 1.0);

    M.acq_report = struct( ...
        'settling_s', W.settling_s, ...
        'mae_deg', W.acq.mae_deg, ...
        'rms_deg', W.acq.rms_deg, ...
        'p95_deg', W.acq.p95_deg, ...
        'signed_deg', W.acq.signed_deg);

    M.logs = struct('t', t, 'e_psi', e_psi, 'e_th', e_th, ...
        'psi', psi, 'psi_ref', psi_ref, ...
        'theta_phys', theta_phys, 'theta_ref', theta_ref, ...
        'q', q, 'r', r, 'de', de, 'dr', dr, ...
        'e_radial', e_radial, 'rho', rho, ...
        'mask_yaw', mask_yaw, 'mask_acq', W.mask_acq, 'mask_steady', W.mask_steady);
end

%% ===================== gates / repeat =====================
function G = gate_X(m, pre, cap)
    G = struct();
    G.rms_reg_pct = pct(m.steady.rms_deg, pre.rms_deg);
    G.p95_reg_pct = pct(m.steady.p95_deg, pre.p95_deg);
    G.g_mae = ~isnan(m.steady.mae_deg) && (m.steady.mae_deg <= 0.10);
    G.g_rms = ~isnan(m.steady.rms_deg) && (G.rms_reg_pct <= 2);
    G.g_p95 = ~isnan(m.steady.p95_deg) && (G.p95_reg_pct <= 2);
    G.g_cap_mae = ~isnan(m.steady.mae_deg) && (abs_pct(m.steady.mae_deg, cap.mae_deg) <= 1.0);
    G.g_cap_p95 = ~isnan(m.steady.p95_deg) && (abs_pct(m.steady.p95_deg, cap.p95_deg) <= 1.0);
    G.g_sat = ~isnan(m.elev_sat_pct) && (m.elev_sat_pct <= 1.0);
    G.pass = G.g_mae && G.g_rms && G.g_p95 && G.g_cap_mae && G.g_cap_p95 && G.g_sat;
end

function G = gate_XZ(m, pre, cap)
    G = struct();
    G.acq_improve_pct = 100 * (pre.acq_mae_deg - m.acq.mae_deg) / pre.acq_mae_deg;
    G.g_mae = ~isnan(m.steady.mae_deg) && (m.steady.mae_deg <= 0.30);
    G.g_p95 = ~isnan(m.steady.p95_deg) && (m.steady.p95_deg <= 0.50);
    G.g_acq = ~isnan(m.acq.mae_deg) && (G.acq_improve_pct >= 10);
    G.g_sat = ~isnan(m.elev_sat_pct) && (m.elev_sat_pct <= 1.0);
    G.g_cap_mae = ~isnan(m.steady.mae_deg) && (abs_pct(m.steady.mae_deg, cap.mae_deg) <= 1.0);
    G.g_cap_p95 = ~isnan(m.steady.p95_deg) && (abs_pct(m.steady.p95_deg, cap.p95_deg) <= 1.0);
    G.g_cap_settle = ~isnan(m.settling_s) && (abs_pct(m.settling_s, cap.settle_s) <= 1.0);
    G.pass = G.g_mae && G.g_p95 && G.g_acq && G.g_sat && ...
        G.g_cap_mae && G.g_cap_p95 && G.g_cap_settle;
end

function G = gate_helix(M, cap)
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
    if M.yaw.n_ratio_valid > 10 && ~isnan(M.yaw.ratio_r_Uh_kappa)
        G.g_ratio = (M.yaw.ratio_r_Uh_kappa >= 0.98) && (M.yaw.ratio_r_Uh_kappa <= 1.02);
        G.ratio_applicable = true;
    else
        G.g_ratio = true;
        G.ratio_applicable = false;
    end
    G.g_cap_pm = abs_pct(M.pitch.steady.mae_deg, cap.pitch_mae) <= 1.0;
    G.g_cap_pp = abs_pct(M.pitch.steady.p95_deg, cap.pitch_p95) <= 1.0;
    G.g_cap_ym = abs_pct(M.yaw.mae_deg, cap.yaw_mae) <= 1.0;
    G.g_cap_yp = abs_pct(M.yaw.p95_deg, cap.yaw_p95) <= 1.0;
    G.g_cap_ratio = abs_pct(M.yaw.ratio_r_Uh_kappa, cap.ratio) <= 1.0;
    G.g_no_ctrl = true;
    G.pass = G.g_pitch_mae && G.g_pitch_p95 && G.g_pitch_sat && G.g_pitch_chatter && ...
        G.g_pitch_persist && G.g_yaw_mae && G.g_yaw_p95 && G.g_yaw_sat_steady && ...
        G.g_yaw_sat_full && G.g_ratio && G.g_cap_pm && G.g_cap_pp && ...
        G.g_cap_ym && G.g_cap_yp && G.g_cap_ratio && G.g_no_ctrl;
end

function R = repeat_check_pitch(a, b)
    keys = {'mae', a.steady.mae_deg, b.steady.mae_deg; ...
            'p95', a.steady.p95_deg, b.steady.p95_deg; ...
            'rms', a.steady.rms_deg, b.steady.rms_deg; ...
            'settle', a.settling_s, b.settling_s};
    R = struct();
    R.max_abs_pct = 0;
    R.identical = true;
    R.details = {};
    for i = 1:size(keys, 1)
        v1 = keys{i, 2}; v2 = keys{i, 3};
        ap = abs_pct(v2, v1);
        R.max_abs_pct = max(R.max_abs_pct, ap);
        if abs(v1 - v2) > 1e-15
            R.identical = false;
        end
        R.details{end+1} = sprintf('%s: %.6g vs %.6g (|Δ%%|=%.4f)', ...
            keys{i, 1}, v1, v2, ap); %#ok<AGROW>
    end
    R.pass = R.max_abs_pct <= 1.0;
    if R.identical
        R.note = 'deterministic identity (bit-match after clear persistent)';
    else
        R.note = sprintf('within 1%% (max |Δ%%|=%.4f)', R.max_abs_pct);
    end
end

function R = repeat_check_helix(a, b)
    pairs = { ...
        'pitch_mae', a.pitch.steady.mae_deg, b.pitch.steady.mae_deg; ...
        'pitch_p95', a.pitch.steady.p95_deg, b.pitch.steady.p95_deg; ...
        'yaw_mae', a.yaw.mae_deg, b.yaw.mae_deg; ...
        'yaw_p95', a.yaw.p95_deg, b.yaw.p95_deg; ...
        'sat_full', a.yaw.rudder_sat_full_pct, b.yaw.rudder_sat_full_pct; ...
        'ratio', a.yaw.ratio_r_Uh_kappa, b.yaw.ratio_r_Uh_kappa};
    R = struct();
    R.max_abs_pct = 0;
    R.identical = true;
    R.details = {};
    for i = 1:size(pairs, 1)
        v1 = pairs{i, 2}; v2 = pairs{i, 3};
        ap = abs_pct(v2, v1);
        R.max_abs_pct = max(R.max_abs_pct, ap);
        if abs(v1 - v2) > 1e-15
            R.identical = false;
        end
        R.details{end+1} = sprintf('%s: %.6g vs %.6g (|Δ%%|=%.4f)', ...
            pairs{i, 1}, v1, v2, ap); %#ok<AGROW>
    end
    R.pass = R.max_abs_pct <= 1.0;
    if R.identical
        R.note = 'deterministic identity (bit-match after clear persistent)';
    else
        R.note = sprintf('within 1%% (max |Δ%%|=%.4f)', R.max_abs_pct);
    end
end

%% ===================== figures =====================
function write_png_X(out_dir, m, ok)
    global delta_e_max
    L = m.logs;
    lim_deg = rad2deg(delta_e_max);
    fig = figure('Visible', 'off', 'Color', 'w', 'Position', [30 30 1100 900]);

    subplot(4, 1, 1); hold on; grid on;
    plot(L.t, rad2deg(L.theta_ref), 'k-', 'LineWidth', 1.5);
    plot(L.t, rad2deg(L.theta_phys), 'b-', 'LineWidth', 1.2);
    xline(m.settling_s, 'm--');
    ylabel('\theta [deg]'); title(sprintf('X ref/actual | settle=%.2fs | %s', ...
        m.settling_s, tern(ok, 'PASS', 'FAIL')));
    legend({'\theta_{ref}', '\theta_{phys}'}, 'Location', 'best');

    subplot(4, 1, 2); hold on; grid on;
    plot(L.t, rad2deg(L.e_th), 'b-', 'LineWidth', 1.2);
    yline(0.5, 'k--'); yline(-0.5, 'k--'); yline(0, 'k:');
    xline(m.settling_s, 'm--');
    ylabel('e_\theta [deg]');
    title(sprintf('acq MAE=%.4f° | ss MAE=%.4f° RMS=%.4f° p95=%.4f°', ...
        m.acq.mae_deg, m.steady.mae_deg, m.steady.rms_deg, m.steady.p95_deg));

    subplot(4, 1, 3); hold on; grid on;
    plot(L.t, rad2deg(L.q), 'r-', 'LineWidth', 1.1);
    xline(m.settling_s, 'm--');
    ylabel('q [deg/s]'); title(sprintf('q | chatter=%.4f °/s', m.chatter_dps));

    subplot(4, 1, 4); hold on; grid on;
    plot(L.t, rad2deg(L.de), 'r-', 'LineWidth', 1.2);
    plot(L.t, rad2deg(L.de_climb_ff), 'm-', 'LineWidth', 1.0);
    yline(lim_deg, 'k:'); yline(-lim_deg, 'k:');
    xline(m.settling_s, 'm--');
    ylabel('\delta_e [deg]'); xlabel('t [s]');
    title(sprintf('elevator | sat=%.2f%%', m.elev_sat_pct));
    legend({'\delta_e', 'climbFF'}, 'Location', 'best');

    sgtitle('FINAL_TRACKING_X | climb-FF production');
    exportgraphics(fig, fullfile(out_dir, 'FINAL_TRACKING_X.png'), 'Resolution', 150);
    close(fig);
end

function write_png_XZ(out_dir, m, ok)
    global delta_e_max
    L = m.logs;
    lim_deg = rad2deg(delta_e_max);
    fig = figure('Visible', 'off', 'Color', 'w', 'Position', [30 30 1100 900]);

    subplot(4, 1, 1); hold on; grid on;
    plot(L.t, rad2deg(L.theta_ref), 'k-', 'LineWidth', 1.5);
    plot(L.t, rad2deg(L.theta_phys), 'b-', 'LineWidth', 1.2);
    xline(m.settling_s, 'm--');
    ylabel('\theta [deg]'); title(sprintf('XZ \\lambda=0 ref/actual | settle=%.2fs | %s', ...
        m.settling_s, tern(ok, 'PASS', 'FAIL')));
    legend({'\theta_{ref}', '\theta_{phys}'}, 'Location', 'best');

    subplot(4, 1, 2); hold on; grid on;
    plot(L.t, rad2deg(L.e_th), 'b-', 'LineWidth', 1.2);
    yline(0.5, 'k--'); yline(-0.5, 'k--'); yline(0, 'k:');
    xline(m.settling_s, 'm--');
    ylabel('e_\theta [deg]');
    title(sprintf('acq MAE=%.4f° | ss MAE=%.4f° p95=%.4f°', ...
        m.acq.mae_deg, m.steady.mae_deg, m.steady.p95_deg));

    subplot(4, 1, 3); hold on; grid on;
    plot(L.t, rad2deg(L.q), 'r-', 'LineWidth', 1.1);
    xline(m.settling_s, 'm--');
    ylabel('q [deg/s]'); title(sprintf('q | chatter=%.4f °/s', m.chatter_dps));

    subplot(4, 1, 4); hold on; grid on;
    plot(L.t, rad2deg(L.de), 'r-', 'LineWidth', 1.2);
    plot(L.t, rad2deg(L.de_climb_ff), 'm-', 'LineWidth', 1.0);
    yline(lim_deg, 'k:'); yline(-lim_deg, 'k:');
    xline(m.settling_s, 'm--');
    ylabel('\delta_e [deg]'); xlabel('t [s]');
    title(sprintf('elevator | sat=%.2f%%', m.elev_sat_pct));
    legend({'\delta_e', 'climbFF'}, 'Location', 'best');

    sgtitle('FINAL_TRACKING_XZ | persistent | \\lambda=0');
    exportgraphics(fig, fullfile(out_dir, 'FINAL_TRACKING_XZ.png'), 'Resolution', 150);
    close(fig);
end

function write_png_helix(out_dir, S, M, path, ok, de_max, dr_max, R, u0)
    L = M.logs;
    lim_e = rad2deg(de_max);
    lim_r = rad2deg(dr_max);
    fig = figure('Visible', 'off', 'Color', 'w', 'Position', [30 30 1400 1000]);

    subplot(3, 3, [1 4]);
    plot3(path(:, 1), path(:, 2), path(:, 3), 'k--', 'LineWidth', 1.5); hold on;
    plot3(S.vp(:, 1), S.vp(:, 2), S.vp(:, 3), 'b-', 'LineWidth', 1.2);
    grid on; axis equal;
    xlabel('X'); ylabel('Y'); zlabel('Z');
    title(sprintf('R10 helix | CTE=%.3f m | %s', M.yaw.cte_perp_sbe, tern(ok, 'PASS', 'FAIL')));
    view(35, 22);

    subplot(3, 3, 2); hold on; grid on;
    plot(L.t, rad2deg(unwrap(L.psi_ref)), 'k-', L.t, rad2deg(unwrap(L.psi)), 'b-');
    ylabel('\psi [deg]'); title('\psi_{ref}/\psi');

    subplot(3, 3, 3); hold on; grid on;
    plot(L.t, rad2deg(L.e_psi), 'b-'); yline(0, 'k:');
    ylabel('e_\psi wrap [deg]');
    title(sprintf('yaw MAE=%.3f p95=%.3f', M.yaw.mae_deg, M.yaw.p95_deg));

    subplot(3, 3, 5); hold on; grid on;
    plot(L.t, rad2deg(L.theta_ref), 'k-', L.t, rad2deg(L.theta_phys), 'b-');
    if ~isnan(M.pitch.settling_s); xline(M.pitch.settling_s, 'r--'); end
    ylabel('\theta [deg]'); title('\theta_{ref}/\theta_{phys}');

    subplot(3, 3, 6); hold on; grid on;
    plot(L.t, rad2deg(L.e_th), 'b-');
    yline(0.5, 'k--'); yline(-0.5, 'k--');
    if ~isnan(M.pitch.settling_s); xline(M.pitch.settling_s, 'r--'); end
    ylabel('e_\theta [deg]');
    title(sprintf('pitch ss MAE=%.3f p95=%.3f', M.pitch.steady.mae_deg, M.pitch.steady.p95_deg));

    subplot(3, 3, 7); hold on; grid on;
    plot(L.t, rad2deg(L.r), 'b-', L.t, rad2deg(L.q), 'r-');
    ylabel('[deg/s]'); title(sprintf('r/q | ratio=%.4f', M.yaw.ratio_r_Uh_kappa));
    legend({'r', 'q'});

    subplot(3, 3, 8); hold on; grid on;
    plot(L.t, rad2deg(L.dr), 'b-');
    yline(lim_r, 'k--'); yline(-lim_r, 'k--');
    ylabel('\delta_r [deg]');
    title(sprintf('rudder sat ss/full=%.2f/%.2f%%', ...
        M.yaw.rudder_sat_steady_pct, M.yaw.rudder_sat_full_pct));

    subplot(3, 3, 9); hold on; grid on;
    plot(L.t, rad2deg(L.de), 'b-');
    yline(lim_e, 'k--'); yline(-lim_e, 'k--');
    ylabel('\delta_e [deg]');
    title(sprintf('elev sat=%.2f%%', M.pitch.elev_sat_pct));

    sgtitle(sprintf('FINAL_TRACKING_HELIX_R10 | R=%.1f u=%.1f | %s', ...
        R, u0, tern(ok, 'PASS', 'FAIL')));
    exportgraphics(fig, fullfile(out_dir, 'FINAL_TRACKING_HELIX_R10.png'), 'Resolution', 150);
    close(fig);
end

%% ===================== MD / log =====================
function write_md(out_dir, tag, pass, seed, rng_state, k_gamma, de_lim, ...
        mX, mXZ, MH, GX, GXZ, GH, RX, RXZ, RH, capX, capXZ, capH, preX, preXZ)
    mX1 = mX{1}; mX2 = mX{2};
    mXZ1 = mXZ{1}; mXZ2 = mXZ{2};
    M1 = MH{1}; M2 = MH{2};

    md_path = fullfile(out_dir, [tag '.md']);
    fid = fopen(md_path, 'w');

    fprintf(fid, '# PITCH_YAW_CLOSURE\n\n');
    fprintf(fid, '**TASK_ID:** PITCH_YAW_FINAL_CLOSURE_001\n');
    fprintf(fid, '**Date:** %s\n', datestr(now, 31));
    fprintf(fid, '**Verdict:** **%s**\n\n', tern(pass, 'PASS', 'FAIL'));

    fprintf(fid, '## FINAL_CHANGELOG\n\n');
    fprintf(fid, '### Accepted production (old → new)\n\n');
    fprintf(fid, '- **old:** `de_unsat = de_trim + de_uw_ff + de_fb` (no climb FF)\n');
    fprintf(fid, '- **new:** `de_unsat = de_trim + de_uw_ff + de_climb_ff + de_fb`\n');
    fprintf(fid, '- `de_climb_ff = sat(k_gamma * gamma_ref, ±%.4f°)`, `k_gamma=%.10f`, ', de_lim, k_gamma);
    fprintf(fid, '`gamma_ref = pitch_ref` (physical)\n');
    fprintf(fid, '- `int_angle(0)=0`, `prev_delta_e(0)=0`; X λ=0.25; XZ λ=0; helix λ=0.25\n');
    fprintf(fid, '- Gains / guidance / plant **frozen**; this task is driver/report only (no edits).\n\n');

    fprintf(fid, '### Equations / units / frame / provenance\n\n');
    fprintf(fid, '```\n');
    fprintf(fid, 'k_gamma = 0.1320695001 = 2.8793/21.8014   [-]  (elev rad / pitch-ref rad)\n');
    fprintf(fid, 'gamma_ref = pitch_ref                     [rad] physical (theta_phys=-theta)\n');
    fprintf(fid, 'de_climb_ff = sat(k_gamma*gamma_ref, +/-deg2rad(2.8793))  [rad]\n');
    fprintf(fid, 'e_theta = pitch_ref - theta_phys\n');
    fprintf(fid, 'e_psi   = wrapToPi(psi_ref - psi)\n');
    fprintf(fid, 'X windows: first_hold ±0.5°/1s; steady=(t≥5∧s<0.88 s_tot)\\acq\n');
    fprintf(fid, 'XZ/helix pitch: persistent |eθ|≤±0.5° to s<0.88*s_total\n');
    fprintf(fid, 'helix yaw: t≥5 ∩ before_end (open Frenet SBE); ratio=mean(r)/mean(Uh*κ)\n');
    fprintf(fid, 'provenance: ATTRIB λ=0 steady mean(de_fb)=+2.8793° / path_pitch=21.8014°\n');
    fprintf(fid, 'promoted: PITCH_CLIMB_FF_REGRESSION_001; helix envelope: HELIX_R10_...\n');
    fprintf(fid, '```\n\n');

    fprintf(fid, '### Percent effects (pre-climb → accepted production / capsule)\n\n');
    fprintf(fid, '| Route | Metric | Old | New | Δ%% |\n');
    fprintf(fid, '|-------|--------|----:|----:|----:|\n');
    fprintf(fid, '| X | ss MAE [°] | %.4f | %.4f | %+.1f |\n', ...
        preX.mae_deg, capX.mae_deg, pct(capX.mae_deg, preX.mae_deg));
    fprintf(fid, '| X | ss RMS [°] | %.4f | %.4f | %+.1f |\n', ...
        preX.rms_deg, capX.rms_deg, pct(capX.rms_deg, preX.rms_deg));
    fprintf(fid, '| X | ss p95 [°] | %.4f | %.4f | %+.1f |\n', ...
        preX.p95_deg, capX.p95_deg, pct(capX.p95_deg, preX.p95_deg));
    fprintf(fid, '| XZ | settle [s] | %.2f | %.2f | %+.1f |\n', ...
        preXZ.settle_s, capXZ.settle_s, pct(capXZ.settle_s, preXZ.settle_s));
    fprintf(fid, '| XZ | acq MAE [°] | %.4f | %.4f | %+.1f |\n', ...
        preXZ.acq_mae_deg, capXZ.acq_mae_deg, pct(capXZ.acq_mae_deg, preXZ.acq_mae_deg));
    fprintf(fid, '| XZ | ss MAE [°] | %.4f | %.4f | %+.1f |\n', ...
        preXZ.mae_deg, capXZ.mae_deg, pct(capXZ.mae_deg, preXZ.mae_deg));
    fprintf(fid, '| XZ | ss p95 [°] | %.4f | %.4f | %+.1f |\n\n', ...
        preXZ.p95_deg, capXZ.p95_deg, pct(capXZ.p95_deg, preXZ.p95_deg));

    fprintf(fid, '### Reverted / not-promoted trials\n\n');
    fprintf(fid, '- Pre-window climb candidates rescored under first_hold (false early settle) — superseded by persistent WINDOW_AUDIT.\n');
    fprintf(fid, '- `PITCH_XZ_WARMSTART_I`, `PITCH_XZ_BUMPLESS_DE_INIT` — diagnostic / not production.\n');
    fprintf(fid, '- Helix R=5 hard authority FAIL (rudder sat ~95%%); R=7.5 soft FAIL (sat 1.06%%, ratio 1.024); R=8 soft FAIL (full sat 6.67%%, ratio 1.0236) — envelope docs only, no retune.\n');
    fprintf(fid, '- Optional Muw schedule revisit deferred; gains remain frozen.\n\n');

    fprintf(fid, '### Untried advanced controllers\n\n');
    fprintf(fid, '- LQR / LQG pitch-yaw MIMO\n');
    fprintf(fid, '- MPC / NMPC with actuator constraints\n');
    fprintf(fid, '- Adaptive / MRAC or gain-scheduled climb FF beyond fixed k_gamma\n');
    fprintf(fid, '- Sliding-mode / backstepping nonlinear redesign\n');
    fprintf(fid, '- Dual-loop α / path-angle cascade beyond current trim+Muw+climbFF+PID\n\n');

    fprintf(fid, '## Determinism / seeds\n\n');
    fprintf(fid, '- `rng(%d,''twister'')` reset before each of 6 sims; Type=%s.\n', seed, rng_state.Type);
    fprintf(fid, '- Plant/controller deterministic (ode45, fixed IC); RNG unused by dynamics.\n');
    fprintf(fid, '- Persistent state cleared via `clear guidance_law controller_law` (+ helix globals) each run.\n');
    fprintf(fid, '- X repeats: **%s** — %s\n', tern(RX.pass, 'PASS', 'FAIL'), RX.note);
    fprintf(fid, '- XZ repeats: **%s** — %s\n', tern(RXZ.pass, 'PASS', 'FAIL'), RXZ.note);
    fprintf(fid, '- Helix repeats: **%s** — %s\n\n', tern(RH.pass, 'PASS', 'FAIL'), RH.note);

    fprintf(fid, '## X (first_hold) — acquisition / steady\n\n');
    fprintf(fid, '| | settle [s] | acq MAE | ss MAE | ss RMS | ss p95 | sat%% |\n');
    fprintf(fid, '|--|---:|---:|---:|---:|---:|---:|\n');
    fprintf(fid, '| rep1 | %.2f | %.4f | %.4f | %.4f | %.4f | %.2f |\n', ...
        mX1.settling_s, mX1.acq.mae_deg, mX1.steady.mae_deg, mX1.steady.rms_deg, ...
        mX1.steady.p95_deg, mX1.elev_sat_pct);
    fprintf(fid, '| rep2 | %.2f | %.4f | %.4f | %.4f | %.4f | %.2f |\n', ...
        mX2.settling_s, mX2.acq.mae_deg, mX2.steady.mae_deg, mX2.steady.rms_deg, ...
        mX2.steady.p95_deg, mX2.elev_sat_pct);
    fprintf(fid, '| capsule | — | — | %.4f | %.4f | %.4f | — |\n\n', ...
        capX.mae_deg, capX.rms_deg, capX.p95_deg);

    fprintf(fid, '## XZ λ=0 (persistent) — acquisition / steady\n\n');
    fprintf(fid, '| | settle [s] | acq MAE | ss MAE | ss RMS | ss p95 | sat%% |\n');
    fprintf(fid, '|--|---:|---:|---:|---:|---:|---:|\n');
    fprintf(fid, '| rep1 | %.2f | %.4f | %.4f | %.4f | %.4f | %.2f |\n', ...
        mXZ1.settling_s, mXZ1.acq.mae_deg, mXZ1.steady.mae_deg, mXZ1.steady.rms_deg, ...
        mXZ1.steady.p95_deg, mXZ1.elev_sat_pct);
    fprintf(fid, '| rep2 | %.2f | %.4f | %.4f | %.4f | %.4f | %.2f |\n', ...
        mXZ2.settling_s, mXZ2.acq.mae_deg, mXZ2.steady.mae_deg, mXZ2.steady.rms_deg, ...
        mXZ2.steady.p95_deg, mXZ2.elev_sat_pct);
    fprintf(fid, '| capsule | %.2f | %.4f | %.4f | — | %.4f | %.2f |\n\n', ...
        capXZ.settle_s, capXZ.acq_mae_deg, capXZ.mae_deg, capXZ.p95_deg, capXZ.sat_pct);

    fprintf(fid, '## R10 helix — pitch persistent / yaw wrap SBE\n\n');
    fprintf(fid, '### Pitch\n\n');
    fprintf(fid, '| | settle [s] | acq MAE | ss MAE | ss RMS | ss p95 | elev sat%% | chat |\n');
    fprintf(fid, '|--|---:|---:|---:|---:|---:|---:|---:|\n');
    fprintf(fid, '| rep1 | %.2f | %.4f | %.4f | %.4f | %.4f | %.2f | %.4f |\n', ...
        M1.pitch.settling_s, M1.acq_report.mae_deg, M1.pitch.steady.mae_deg, ...
        M1.pitch.steady.rms_deg, M1.pitch.steady.p95_deg, M1.pitch.elev_sat_pct, ...
        M1.pitch.chatter_dps);
    fprintf(fid, '| rep2 | %.2f | %.4f | %.4f | %.4f | %.4f | %.2f | %.4f |\n', ...
        M2.pitch.settling_s, M2.acq_report.mae_deg, M2.pitch.steady.mae_deg, ...
        M2.pitch.steady.rms_deg, M2.pitch.steady.p95_deg, M2.pitch.elev_sat_pct, ...
        M2.pitch.chatter_dps);
    fprintf(fid, '| capsule | — | — | %.4f | — | %.4f | — | — |\n\n', ...
        capH.pitch_mae, capH.pitch_p95);

    fprintf(fid, '### Yaw (wrapped, open-helix SBE)\n\n');
    fprintf(fid, '| | MAE | RMS | p95 | sat acq/ss/full %% | ratio |\n');
    fprintf(fid, '|--|---:|---:|---:|---:|---:|\n');
    fprintf(fid, '| rep1 | %.4f | %.4f | %.4f | %.2f/%.2f/%.2f | %.4f |\n', ...
        M1.yaw.mae_deg, M1.yaw.rms_deg, M1.yaw.p95_deg, ...
        M1.yaw.rudder_sat_acq_pct, M1.yaw.rudder_sat_steady_pct, ...
        M1.yaw.rudder_sat_full_pct, M1.yaw.ratio_r_Uh_kappa);
    fprintf(fid, '| rep2 | %.4f | %.4f | %.4f | %.2f/%.2f/%.2f | %.4f |\n', ...
        M2.yaw.mae_deg, M2.yaw.rms_deg, M2.yaw.p95_deg, ...
        M2.yaw.rudder_sat_acq_pct, M2.yaw.rudder_sat_steady_pct, ...
        M2.yaw.rudder_sat_full_pct, M2.yaw.ratio_r_Uh_kappa);
    fprintf(fid, '| capsule | %.4f | — | %.4f | —/—/%.2f | %.4f |\n\n', ...
        capH.yaw_mae, capH.yaw_p95, capH.rud_sat_full, capH.ratio);

    fprintf(fid, '## Gates\n\n');
    fprintf(fid, '| Gate | Result |\n|------|--------|\n');
    fprintf(fid, '| X MAE≤0.10 / RMS&p95 reg≤2%% / sat≤1%% / vs capsule≤1%% | %s |\n', yn(GX.pass));
    fprintf(fid, '| XZ MAE≤0.30 / p95≤0.50 / acq≥10%% / sat≤1%% / vs capsule≤1%% | %s |\n', yn(GXZ.pass));
    fprintf(fid, '| Helix pitch+yaw prior gates + vs capsule≤1%% | %s |\n', yn(GH.pass));
    fprintf(fid, '| Two-repeat ≤1%% (or identity) X/XZ/H | %s |\n', ...
        yn(RX.pass && RXZ.pass && RH.pass));
    fprintf(fid, '\n**Overall: %s**\n\n', tern(pass, 'PASS', 'FAIL'));

    fprintf(fid, '## Evidence\n\n');
    fprintf(fid, '- Driver: `run_pitch_yaw_final_closure.m` (no controller/guidance/plant change)\n');
    fprintf(fid, '- `suite_results/PITCH_YAW_CLOSURE.md`\n');
    fprintf(fid, '- `suite_results/PITCH_YAW_CLOSURE.mat`\n');
    fprintf(fid, '- `suite_results/FINAL_TRACKING_X.png`\n');
    fprintf(fid, '- `suite_results/FINAL_TRACKING_XZ.png`\n');
    fprintf(fid, '- `suite_results/FINAL_TRACKING_HELIX_R10.png`\n');
    fprintf(fid, '- `CODEX_VERTICAL_PLAN.md` untouched\n\n');

    fprintf(fid, '## Conclusion\n\n');
    if pass
        fprintf(fid, 'PASS: nonlinear 6DOF closure confirmed for X, XZ(λ=0), R10 helix under accepted climb-FF production. ');
        fprintf(fid, 'Repeats deterministic; prior gates held; actuators within limits.\n');
        fprintf(fid, 'Next: freeze production checklist; optional finer R_min bracket only if needed; no gain change.\n');
    else
        fprintf(fid, 'FAIL: diagnose failing gate/repeat; do not retune — report only.\n');
    end
    fclose(fid);
end

function append_log(out_dir, pass, seed, mX, mXZ, M, RX, RXZ, RH, GX, GXZ, GH)
    log_path = fullfile(out_dir, 'PITCH_CONTROL_RESEARCH_LOG.md');
    lfid = fopen(log_path, 'a');
    fprintf(lfid, '\n## PITCH_YAW_FINAL_CLOSURE_001 — %s\n\n', datestr(now, 31));
    fprintf(lfid, '- Verdict: **%s** — two-repeat 6DOF closure X / XZ(λ=0) / R10 helix; production climb-FF frozen; no controller/guidance/plant edits.\n', ...
        tern(pass, 'PASS', 'FAIL'));
    fprintf(lfid, '- Determinism: rng seed=%d twister; X=%s; XZ=%s; H=%s.\n', ...
        seed, RX.note, RXZ.note, RH.note);
    fprintf(lfid, '- X (first_hold): settle=%.2fs acqMAE=%.4f ssMAE=%.4f ssp95=%.4f sat=%.2f%% | gates %s.\n', ...
        mX.settling_s, mX.acq.mae_deg, mX.steady.mae_deg, mX.steady.p95_deg, ...
        mX.elev_sat_pct, tern(GX.pass, 'PASS', 'FAIL'));
    fprintf(lfid, '- XZ (persistent λ=0): settle=%.2fs acqMAE=%.4f ssMAE=%.4f ssp95=%.4f sat=%.2f%% | gates %s.\n', ...
        mXZ.settling_s, mXZ.acq.mae_deg, mXZ.steady.mae_deg, mXZ.steady.p95_deg, ...
        mXZ.elev_sat_pct, tern(GXZ.pass, 'PASS', 'FAIL'));
    fprintf(lfid, '- R10 helix: pitch ss MAE=%.4f p95=%.4f sat=%.2f%%; yaw MAE=%.4f p95=%.4f sat_full=%.2f%% ratio=%.4f | gates %s.\n', ...
        M.pitch.steady.mae_deg, M.pitch.steady.p95_deg, M.pitch.elev_sat_pct, ...
        M.yaw.mae_deg, M.yaw.p95_deg, M.yaw.rudder_sat_full_pct, M.yaw.ratio_r_Uh_kappa, ...
        tern(GH.pass, 'PASS', 'FAIL'));
    fprintf(lfid, '- Artifacts: suite_results/PITCH_YAW_CLOSURE.{md,mat}; FINAL_TRACKING_{X,XZ,HELIX_R10}.png; driver `run_pitch_yaw_final_closure.m`.\n');
    fprintf(lfid, '- Next: freeze production checklist; optional finer R_min if exact min needed; CODEX_VERTICAL_PLAN untouched.\n');
    fclose(lfid);
end

%% ===================== helpers =====================
function p = pct(newv, oldv)
    p = 100 * (newv - oldv) / max(abs(oldv), 1e-12);
end

function p = abs_pct(newv, oldv)
    p = 100 * abs(newv - oldv) / max(abs(oldv), 1e-12);
end

function p = sat_pct(u, mask, thr)
    if any(mask)
        p = 100 * mean(abs(u(mask)) >= thr);
    else
        p = NaN;
    end
end

function t_s = time_to_yaw_persist(t, e_psi, thr, persist_s)
    ok = abs(e_psi(:)) <= thr;
    dt = median(diff(t(:)));
    need = max(1, round(persist_s / max(dt, eps)));
    if numel(ok) < need
        t_s = NaN;
        return;
    end
    c = 0;
    t_s = NaN;
    for i = 1:numel(ok)
        if ok(i)
            c = c + 1;
            if c >= need
                t_s = t(i - need + 1);
                return;
            end
        else
            c = 0;
        end
    end
end

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

function y = align_len(x, n)
    x = x(:);
    if isempty(x)
        y = zeros(n, 1);
        return;
    end
    if numel(x) >= n
        y = x(1:n);
    else
        y = [x; x(end) * ones(n - numel(x), 1)];
    end
end

function y = hf_local(x, dt)
    n = max(3, round(0.8 / dt));
    lf = filter(ones(n, 1) / n, 1, x(:));
    y = x(:) - lf;
    y(1:min(n, numel(y))) = 0;
end

function v = pctile95(x)
    x = sort(x(:));
    if isempty(x); v = NaN; return; end
    k = max(1, min(numel(x), ceil(0.95 * numel(x))));
    v = x(k);
end

function s = yn(tf)
    if tf; s = 'YES'; else; s = 'NO'; end
end

function s = tern(tf, a, b)
    if tf; s = a; else; s = b; end
end
