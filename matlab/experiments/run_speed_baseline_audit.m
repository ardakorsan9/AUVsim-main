function run_speed_baseline_audit()
% SPEED_BASELINE_AUDIT_001 — surge-speed baseline + root cause at Uref=1.5
% on accepted X / XZ / R10 + straight bounded step 1.3->1.5->1.3 m/s.
% Read-only: ROLL_PRODUCTION_CLOSURE.mat, controller_law.m, init_parameters.m.
% BODY u = controller variable; Uh / |V| reported separately. No gain change.
% One MATLAB invocation. Artifacts: suite_results/SPEED_BASELINE_AUDIT.{md,mat,png}

    project_dir = fileparts(fileparts(fileparts(mfilename('fullpath')))); % repo root
    addpath(genpath(fullfile(project_dir, 'matlab')));
    out_dir = fullfile(project_dir, 'suite_results');
    if ~exist(out_dir, 'dir'); mkdir(out_dir); end
    tag = 'SPEED_BASELINE_AUDIT';
    task_id = 'SPEED_BASELINE_AUDIT_001';

    closure_path = fullfile(out_dir, 'ROLL_PRODUCTION_CLOSURE.mat');
    ctrl_path = fullfile(project_dir, 'controller_law.m');
    init_path = fullfile(project_dir, 'init_parameters.m');
    assert(exist(closure_path, 'file') == 2, 'Missing %s', closure_path);
    assert(exist(ctrl_path, 'file') == 2, 'Missing %s', ctrl_path);
    assert(exist(init_path, 'file') == 2, 'Missing %s', init_path);

    Clos = load(closure_path);
    assert(strcmp(Clos.verdict, 'PASS'), 'ROLL_PRODUCTION_CLOSURE must be PASS');
    assert(isfield(Clos, 'candidate') && isfield(Clos.candidate, 'X'), ...
        'Closure missing candidate metrics');

    ctrl_txt = fileread(ctrl_path);
    assert(contains(ctrl_txt, 'thrust_trim + Kp_x * (u_ref - u)'), ...
        'controller_law thrust law mismatch');
    assert(contains(ctrl_txt, 'Kp_roll'), 'production roll damp missing');

    fprintf('\n========== %s ==========\n', task_id);
    fprintf('Sources: ROLL_PRODUCTION_CLOSURE.mat / controller_law.m / init_parameters.m\n');
    fprintf('Thrust law: thrust = sat(thrust_trim + Kp_x*(u_ref-u)); BODY u controller var\n');

    clear functions
    clear guidance_law controller_law
    clear global lambda_muw_ff trim_speed_table trim_elevator_table elevator_sign
    clear global K_zdot K_gamma enable_alpha_hat
    clear global last_guidance_U_h last_guidance_kappa last_r_ff
    clear global Kp_roll

    init_parameters();
    global lambda_muw_ff elevator_sign trim_speed_table trim_elevator_table
    global K_zdot K_gamma enable_alpha_hat
    global dt_controller delta_e_max delta_r_max
    global Kp_x thrust_trim thrust_max thrust_min desired_speed Kp_roll u_trim

    elevator_sign = 1;
    trim_speed_table = [0.8 1.0 1.5 2.0];
    trim_elevator_table = deg2rad([-9.18 -7.33 -4.62 -3.17]);
    K_gamma = 0; K_zdot = 0; enable_alpha_hat = false;
    Kp_roll = Clos.Kp_roll;   % frozen production 0.605072
    desired_speed = 1.5;
    Uref = 1.5;

    seed_used = 0;
    rng(seed_used, 'twister');

    phi_eq = Clos.phi_eq;
    lim = struct('dr_max', delta_r_max, 'de_max', delta_e_max, ...
        'dr_rate', deg2rad(40), 'near_frac', 0.80, ...
        'thrust_max', thrust_max, 'thrust_min', thrust_min);
    pitch_gate = Clos.pitch_gate;

    law = struct();
    law.equation = 'thrust = sat(thrust_trim + Kp_x*(u_ref - u); [thrust_min,thrust_max])';
    law.frame = 'BODY u [m/s] controller var; Uh=hypot(xdot,ydot); |V|=||nu_lin||';
    law.units = 'u,u_ref,Uh,|V| [m/s]; thrust [N]; Kp_x [N/(m/s)]';
    law.Kp_x = Kp_x;
    law.thrust_trim = thrust_trim;
    law.thrust_max = thrust_max;
    law.thrust_min = thrust_min;
    law.u_trim = u_trim;
    law.desired_speed = desired_speed;
    law.Kp_roll = Kp_roll;
    law.provenance = 'init_parameters + controller_law (frozen pitch/yaw/roll)';

    nX = 600; xX = linspace(0, 45, nX)';
    pathX = [xX, zeros(nX, 1), zeros(nX, 1)];
    nXZ = 900; xXZ = linspace(0, 42, nXZ)';
    pathXZ = [xXZ, zeros(nXZ, 1), 0.4 * xXZ];
    pathH = generate_balanced_helical_path(10.0, 2.0, 2, 500);
    nS = 700; xS = linspace(0, 55, nS)';
    pathStep = [xS, zeros(nS, 1), zeros(nS, 1)];

    % ---- Route sims at Uref=1.5 (accepted production stack) ----
    fprintf('\n-- X (Uref=%.2f) --\n', Uref);
    rng(seed_used, 'twister');
    [SX, MX] = sim_analyze(pathX, 18, Uref, phi_eq.X, lim, 'first_hold', false, 0, []);

    fprintf('\n-- XZ (Uref=%.2f) --\n', Uref);
    rng(seed_used, 'twister');
    [SXZ, MXZ] = sim_analyze(pathXZ, 22, Uref, phi_eq.XZ, lim, 'persistent', true, 0, []);

    fprintf('\n-- R10 (Uref=%.2f) --\n', Uref);
    rng(seed_used, 'twister');
    [SH, MH] = sim_analyze(pathH, 45, Uref, phi_eq.H, lim, 'persistent', false, 10.0, []);

    % ---- Bounded straight speed step 1.3 -> 1.5 -> 1.3 ----
    fprintf('\n-- STEP 1.3->1.5->1.3 (straight) --\n');
    rng(seed_used, 'twister');
    step_sched = struct('t_edges', [0 8 16 24], 'u_levels', [1.3 1.5 1.3]);
    [SStep, MStep] = sim_analyze(pathStep, 24, 1.3, 0.0, lim, 'first_hold', false, 0, step_sched);

    % ---- Preserve frozen pitch/yaw/roll/path vs ROLL_PRODUCTION_CLOSURE ----
    freeze = freeze_gates(MX, MXZ, MH, Clos.candidate, pitch_gate);

    % ---- Speed gates ----
    [G, verdict, root_class, next_opt, next_detail] = score_speed( ...
        MX, MXZ, MH, MStep, freeze, law);

    md_path  = fullfile(out_dir, [tag '.md']);
    mat_path = fullfile(out_dir, [tag '.mat']);
    png_path = fullfile(out_dir, [tag '.png']);

    write_png(png_path, SX, SXZ, SH, SStep, MX, MXZ, MH, MStep, lim, task_id, verdict);
    write_md(md_path, task_id, verdict, law, MX, MXZ, MH, MStep, G, freeze, ...
        root_class, next_opt, next_detail, seed_used, ...
        md_path, mat_path, png_path, closure_path, ctrl_path, init_path);
    append_ss_audit(out_dir, task_id, verdict, law, MX, MXZ, MH, MStep, G, ...
        root_class, next_opt, next_detail, md_path, mat_path, png_path);

    S = struct();
    S.task_id = task_id;
    S.verdict = verdict;
    S.law = law;
    S.root_class = root_class;
    S.next_opt = next_opt;
    S.next_detail = next_detail;
    S.X = MX; S.XZ = MXZ; S.H = MH; S.Step = MStep;
    S.SX = SX; S.SXZ = SXZ; S.SH = SH; S.SStep = SStep;
    S.gates = G;
    S.freeze = freeze;
    S.phi_eq = phi_eq;
    S.limits = lim;
    S.seed_used = seed_used;
    S.sources = {closure_path; ctrl_path; init_path};
    S.paths = struct('md', md_path, 'mat', mat_path, 'png', png_path);
    S.note = 'Speed baseline; no production edit; BODY u controller variable';
    save(mat_path, '-struct', 'S');

    fprintf('\nVERDICT: %s | root=%s | next=%s\n', verdict, root_class, next_opt);
    fprintf('Saved: %s\n%s\n%s\n', md_path, mat_path, png_path);
    print_feedback(verdict, law, MX, MXZ, MH, MStep, G, freeze, ...
        root_class, next_opt, next_detail, md_path, mat_path, png_path);
    assignin('base', 'SPEED_BASELINE_AUDIT_PASS', strcmp(verdict, 'PASS'));
end

%% ===================== simulate + analyze =====================
function [S, M] = sim_analyze(path, T_final, u0, phi_eq, lim, win_mode, is_xz, R, step_sched)
    global dt_controller desired_speed
    global suite_delta_e_log suite_delta_r_log
    global suite_dr_yaw_log suite_dr_p_log suite_dr_damp_log suite_g_ac_log
    global suite_u_log
    global Kp_x thrust_trim thrust_max thrust_min lambda_muw_ff

    clear guidance_law controller_law
    clear global last_guidance_U_h last_guidance_kappa last_r_ff
    clear global last_delta_e last_delta_r last_dr_yaw last_dr_p last_dr_damp last_g_ac
    clear global last_int_angle last_int_rate last_de_fb last_de_trim last_de_uw_ff

    dt = dt_controller;
    state0 = zeros(12, 1);
    state0(1:3) = path(1, :)';
    d = path(2, :) - path(1, :);
    state0(5) = -atan2(d(3), norm(d(1:2)));
    state0(6) = atan2(d(2), d(1));
    state0(7) = u0;

    if isempty(step_sched)
        desired_speed = 1.5;
        if R > 0
            lambda_muw_ff = 0.25;
        elseif is_xz
            lambda_muw_ff = 0.0;
        else
            lambda_muw_ff = 0.25;
        end
        [vp, times, vel, rates, ori, ~, yaw_refs, pitch_refs, u_refs] = ...
            continuous_path_tracking(path, state0, dt, T_final);
        n = numel(times);
        u_ctrl = align_len(suite_u_log(:), n);
        thrust = reconstruct_thrust(u_refs(:), u_ctrl, thrust_trim, Kp_x, ...
            thrust_min, thrust_max);
    else
        lambda_muw_ff = 0.25;
        [vp, times, vel, rates, ori, yaw_refs, pitch_refs, u_refs, u_ctrl, thrust] = ...
            sim_step_schedule(path, state0, dt, T_final, step_sched);
        n = numel(times);
    end

    S = struct();
    S.dt = dt; S.T_final = T_final; S.u0 = u0; S.R = R; S.is_xz = is_xz;
    S.t = times(:);
    S.vp = vp; S.vel = vel; S.rates = rates; S.ori = ori;
    S.psi_ref = yaw_refs(:); S.theta_ref = pitch_refs(:);
    S.u_ref = u_refs(:);
    S.u_ctrl = u_ctrl(:);                 % BODY u at controller tick
    S.u_body = vel(:, 1);                 % BODY u post-step
    S.v_body = vel(:, 2);
    S.w_body = vel(:, 3);
    [S.Uh, S.Vtot] = speeds_from_state(ori, vel);
    S.thrust = thrust(:);
    S.thrust_trim = thrust_trim * ones(n, 1);
    S.thrust_prop = Kp_x * (S.u_ref - S.u_ctrl);
    S.delta_e = align_len(suite_delta_e_log(:), n);
    S.delta_r = align_len(suite_delta_r_log(:), n);
    S.dr_yaw = align_len(suite_dr_yaw_log(:), n);
    S.dr_p = align_len(suite_dr_p_log(:), n);
    S.dr_damp = align_len(suite_dr_damp_log(:), n);
    S.g_ac = align_len(suite_g_ac_log(:), n);
    S.step_sched = step_sched;

    M = analyze_route(S, path, win_mode, phi_eq, lim, is_xz, step_sched);
    fprintf('  uMAE=%.4f uP95=%.4f signed=%.4f thrMean=%.2f sat=%.2f%% pitchMAE=%.4f cte=%.4f\n', ...
        M.speed.steady.mae, M.speed.steady.p95, M.speed.steady.signed_mean, ...
        M.thrust.steady.mean, M.thrust.full.sat_pct, M.pitch.mae_deg, M.path.mean_cte);
end

function [vp, times, vel, rates, ori, yaw_refs, pitch_refs, u_refs, u_ctrl, thrust] = ...
        sim_step_schedule(path, state, dt, T_final, sched)
% Custom loop mirroring continuous_path_tracking with forced u_ref schedule.
    init_parameters();
    global dt_controller dt_guidance
    global Kp_x thrust_trim thrust_max thrust_min
    global last_int_angle last_int_rate last_delta_e
    global last_delta_r last_dr_yaw last_dr_p last_dr_damp last_g_ac
    global suite_delta_e_log suite_delta_r_log
    global suite_dr_yaw_log suite_dr_p_log suite_dr_damp_log suite_g_ac_log
    global suite_u_log
    dt_controller = dt;
    if isempty(dt_guidance); dt_guidance = dt; end

    n_steps = round(T_final / dt);
    vp = zeros(n_steps, 3);
    times = zeros(n_steps, 1);
    vel = zeros(n_steps, 3);
    rates = zeros(n_steps, 3);
    ori = zeros(n_steps, 3);
    yaw_refs = zeros(n_steps, 1);
    pitch_refs = zeros(n_steps, 1);
    u_refs = zeros(n_steps, 1);
    u_ctrl = zeros(n_steps, 1);
    thrust = zeros(n_steps, 1);
    de_log = zeros(n_steps, 1);
    dr_log = zeros(n_steps, 1);
    dry_log = zeros(n_steps, 1);
    drp_log = zeros(n_steps, 1);
    drd_log = zeros(n_steps, 1);
    gac_log = zeros(n_steps, 1);

    progress_index = 1;
    yaw_ref = 0; pitch_ref = 0; u_ref_g = 0; r_ff = 0; pitch_ref_dot = 0;
    guidance_period = max(1, round(dt_guidance / dt));
    total_time = 0;

    for idx = 1:n_steps
        current_position = state(1:3)';
        current_orientation = state(4:6)';
        current_rates = state(10:12)';
        current_u = state(7);
        current_v = state(8);
        current_w = state(9);
        [U_h, zdot_inertial] = inertial_velocity_ned_local(current_orientation, ...
            current_u, current_v, current_w);
        theta_phys_now = -current_orientation(2);

        if mod(idx - 1, guidance_period) == 0
            [yaw_ref, pitch_ref, u_ref_g, progress_index, r_ff, pitch_ref_dot] = ...
                guidance_law(current_position, path, progress_index, current_u, ...
                current_v, U_h, zdot_inertial, theta_phys_now);
        end
        % Force bounded speed schedule (audit-only; production guidance untouched)
        u_ref = schedule_u(total_time, sched);

        [delta_r, delta_e, thr] = controller_law(yaw_ref, pitch_ref, u_ref, ...
            current_orientation(3), current_orientation(2), current_rates(3), ...
            current_rates(2), current_u, r_ff, pitch_ref_dot, ...
            current_orientation(1), current_w, current_rates(1));

        controls.delta_r = delta_r;
        controls.delta_e = delta_e;
        controls.thrust = thr;

        [~, g] = ode45(@(t, gg) underwater777_vehicle_dynamics(t, gg, controls), ...
            [0 dt], state);
        state = g(end, :)';

        vp(idx, :) = state(1:3);
        vel(idx, :) = state(7:9);
        rates(idx, :) = state(10:12);
        ori(idx, :) = state(4:6);
        yaw_refs(idx) = yaw_ref;
        pitch_refs(idx) = pitch_ref;
        u_refs(idx) = u_ref;
        u_ctrl(idx) = current_u;
        thrust(idx) = thr;
        if isempty(last_delta_e); last_delta_e = delta_e; end
        if isempty(last_delta_r); last_delta_r = delta_r; end
        if isempty(last_dr_yaw); last_dr_yaw = 0; end
        if isempty(last_dr_p); last_dr_p = 0; end
        if isempty(last_dr_damp); last_dr_damp = 0; end
        if isempty(last_g_ac); last_g_ac = 1; end
        de_log(idx) = last_delta_e;
        dr_log(idx) = last_delta_r;
        dry_log(idx) = last_dr_yaw;
        drp_log(idx) = last_dr_p;
        drd_log(idx) = last_dr_damp;
        gac_log(idx) = last_g_ac;
        total_time = total_time + dt;
        times(idx) = total_time;
        if mod(idx, 100) == 0 || idx == n_steps
            fprintf('  step sim %d/%d t=%.2f u=%.3f uref=%.3f thr=%.1f\n', ...
                idx, n_steps, total_time, current_u, u_ref, thr);
        end
    end
    suite_delta_e_log = de_log;
    suite_delta_r_log = dr_log;
    suite_dr_yaw_log = dry_log;
    suite_dr_p_log = drp_log;
    suite_dr_damp_log = drd_log;
    suite_g_ac_log = gac_log;
    suite_u_log = u_ctrl;
end

function u = schedule_u(t, sched)
    edges = sched.t_edges(:);
    levels = sched.u_levels(:);
    u = levels(end);
    for k = 1:(numel(levels))
        if t < edges(k + 1)
            u = levels(k);
            return;
        end
    end
end

function thrust = reconstruct_thrust(u_ref, u, trim, Kp, tmin, tmax)
    thrust = trim + Kp * (u_ref - u);
    thrust = max(min(thrust, tmax), tmin);
end

function [Uh, Vtot] = speeds_from_state(ori, vel)
    n = size(vel, 1);
    Uh = zeros(n, 1);
    Vtot = zeros(n, 1);
    for i = 1:n
        [Uh(i), ~] = inertial_velocity_ned_local(ori(i, :), vel(i, 1), vel(i, 2), vel(i, 3));
        Vtot(i) = norm(vel(i, 1:3));
    end
end

function [U_h, zdot] = inertial_velocity_ned_local(ori, u, v, w)
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
    U_h = hypot(pos_dot(1), pos_dot(2));
    zdot = pos_dot(3);
end

function M = analyze_route(S, path, win_mode, phi_eq, lim, is_xz, step_sched)
    t = S.t(:); dt = S.dt;
    phi = S.ori(:, 1);
    theta_phys = -S.ori(:, 2);
    psi = S.ori(:, 3);
    p = S.rates(:, 1);
    dr = S.delta_r(:);
    de = S.delta_e(:);
    psi_ref = S.psi_ref(:);
    theta_ref = S.theta_ref(:);
    e_psi = wrapToPi(psi_ref - psi);
    e_th = theta_ref - theta_phys;
    tilde = phi - phi_eq;

    % Controller error: e_u = u_ref - BODY_u (matches thrust law)
    e_u = S.u_ref - S.u_ctrl;
    e_Uh = S.u_ref - S.Uh;          % diagnostic only (not controller)
    e_V = S.u_ref - S.Vtot;         % diagnostic only

    pm = compute_path_following_metrics(path, S.vp, S.vel, S.ori, ...
        psi_ref, theta_ref, dt, t);
    s = pm.s_prog(:); s_total = pm.s_total;
    W = compute_pitch_window_metrics(t, e_th, s, s_total, 'mode', win_mode);
    mask_ss = W.mask_steady;
    if ~any(mask_ss)
        mask_ss = (t >= 5.0) & W.mask_before_end;
    end
    mask_yaw = (t >= 5.0) & W.mask_before_end;
    if ~any(mask_yaw); mask_yaw = t >= 5.0; end
    mask_acq = W.mask_acq;
    if ~any(mask_acq)
        mask_acq = (t < 5.0) & W.mask_before_end;
    end

    % Hold: guidance commanding near desired / scheduled level (not curvature cut)
    if isempty(step_sched)
        Udes = 1.5;
        mask_hold = mask_ss & (abs(S.u_ref - Udes) <= 0.08);
        if ~any(mask_hold)
            mask_hold = mask_ss;  % fallback: use pitch steady window
        end
    else
        % Middle plateau at 1.5 (t in [8,16))
        mask_hold = (t >= 8.0) & (t < 16.0);
        mask_ss = mask_hold;
        % Acquisition windows for each rising/falling edge
        mask_acq = ((t >= 8.0) & (t < 14.0)) | ((t >= 16.0) & (t < 22.0));
    end

    M = struct();
    M.win_mode = win_mode; M.is_xz = is_xz;
    M.phi_eq_rad = phi_eq; M.phi_eq_deg = rad2deg(phi_eq);
    M.W = W; M.mask_ss = mask_ss; M.mask_yaw = mask_yaw;
    M.mask_hold = mask_hold; M.mask_acq = mask_acq;
    M.pitch = err_stats_deg(e_th, mask_ss);
    M.pitch.elev_sat_pct = sat_pct(de, mask_ss, 0.98 * lim.de_max);
    M.yaw = err_stats_deg(e_psi, mask_yaw);
    M.tilde = err_stats_deg(tilde, mask_ss);
    M.phi = err_stats_deg(phi, mask_ss);
    M.p = err_stats_deg(p, mask_ss);
    M.p.rms_dps = M.p.rms_deg;
    dr_dot = [0; diff(dr)] / dt;
    M.rudder = actuator_stats(dr, dr_dot, mask_ss, lim.dr_max, lim.near_frac);
    M.rudder_full = actuator_stats(dr, dr_dot, true(size(dr)), lim.dr_max, lim.near_frac);
    M.path = struct();
    M.path.mean_cte = pm.mean_cross_track;
    M.path.max_cte = pm.max_cross_track;
    if isfield(pm, 'CTE_perp_settled_before_end') && isfield(pm.CTE_perp_settled_before_end, 'rms')
        M.path.rms_cte = pm.CTE_perp_settled_before_end.rms;
    else
        M.path.rms_cte = M.path.mean_cte;
    end

    M.speed = struct();
    M.speed.frame = 'BODY_u_controller';
    M.speed.acq = speed_stats(e_u, mask_acq);
    M.speed.steady = speed_stats(e_u, mask_hold);
    M.speed.Uh_steady = speed_stats(e_Uh, mask_hold);
    M.speed.Vtot_steady = speed_stats(e_V, mask_hold);
    M.speed.u_mean = mean_safe(S.u_ctrl, mask_hold);
    M.speed.u_ref_mean = mean_safe(S.u_ref, mask_hold);
    M.speed.Uh_mean = mean_safe(S.Uh, mask_hold);
    M.speed.Vtot_mean = mean_safe(S.Vtot, mask_hold);
    M.speed.frame_gap_Uh = abs(M.speed.u_mean - M.speed.Uh_mean);
    M.speed.frame_gap_V = abs(M.speed.u_mean - M.speed.Vtot_mean);
    M.speed.settling = persistent_settle(t, e_u, mask_hold | ((t >= 5) & W.mask_before_end), 0.05);
    if ~isempty(step_sched)
        M.speed.step = step_metrics(S, sched_edges_safe(step_sched), 0.05);
    else
        M.speed.step = struct();
    end

    thr_dot = [0; diff(S.thrust)] / dt;
    M.thrust = struct();
    M.thrust.steady = thrust_stats(S.thrust, S.thrust_trim, S.thrust_prop, ...
        thr_dot, mask_hold, lim);
    M.thrust.full = thrust_stats(S.thrust, S.thrust_trim, S.thrust_prop, ...
        thr_dot, true(size(S.thrust)), lim);
    M.thrust.acq = thrust_stats(S.thrust, S.thrust_trim, S.thrust_prop, ...
        thr_dot, mask_acq, lim);

    % Proportional offset identity: e ≈ (thrust - thrust_trim)/Kp_x when unsaturated
    global Kp_x
    M.diag = struct();
    M.diag.e_pred_from_thrust = mean_safe((S.thrust - S.thrust_trim) / max(Kp_x, eps), mask_hold);
    M.diag.e_meas = M.speed.steady.signed_mean;
    M.diag.prop_identity_err = abs(M.diag.e_pred_from_thrust - M.diag.e_meas);
    M.diag.thrust_authority_margin = lim.thrust_max - abs(M.thrust.steady.mean);
    M.diag.uref_cut_frac = 1 - mean_safe(S.u_ref, mask_ss) / 1.5;
end

function edges = sched_edges_safe(sched)
    edges = sched;
end

function st = speed_stats(e, mask)
    st = struct('signed_mean', NaN, 'mae', NaN, 'rms', NaN, 'p95', NaN, ...
        'max', NaN, 'n', 0);
    if ~any(mask); return; end
    v = e(mask);
    st.n = numel(v);
    st.signed_mean = mean(v);
    st.mae = mean(abs(v));
    st.rms = rms_local(v);
    st.p95 = prctile_local(abs(v), 95);
    st.max = max(abs(v));
end

function st = thrust_stats(thr, ttrim, tprop, tdot, mask, lim)
    st = struct('mean', NaN, 'rms', NaN, 'rate_rms', NaN, 'near_pct', NaN, ...
        'sat_pct', NaN, 'trim_mean', NaN, 'prop_mean', NaN, 'trim_frac', NaN, 'n', 0);
    if ~any(mask); return; end
    v = thr(mask); vd = tdot(mask);
    st.n = numel(v);
    st.mean = mean(v);
    st.rms = rms_local(v);
    st.rate_rms = rms_local(vd);
    span = lim.thrust_max;  % near upper authority
    st.near_pct = 100 * mean(abs(v) >= 0.80 * span);
    st.sat_pct = 100 * mean((v >= 0.98 * lim.thrust_max) | (v <= lim.thrust_min + 0.02 * abs(lim.thrust_min)));
    st.trim_mean = mean(ttrim(mask));
    st.prop_mean = mean(tprop(mask));
    st.trim_frac = st.trim_mean / max(abs(st.mean), eps);
end

function W = persistent_settle(t, e, mask_valid, band)
    W = struct('settling_s', NaN, 'persistent_ok', false, 'band', band);
    idx = find(mask_valid);
    if isempty(idx); return; end
    for k = 1:numel(idx)
        ii = idx(k);
        if all(abs(e(ii:idx(end))) <= band)
            W.settling_s = t(ii);
            W.persistent_ok = true;
            return;
        end
    end
end

function st = step_metrics(S, sched, band)
    t = S.t(:);
    u = S.u_ctrl(:);
    uref = S.u_ref(:);
    e = uref - u;
    edges = sched.t_edges(:);
    levels = sched.u_levels(:);
    st = struct();
    st.band = band;
    st.legs = struct('t0', {}, 't1', {}, 'uref', {}, 'settle_s', {}, ...
        'persistent_ok', {}, 'overshoot_pct', {}, 'lag_s', {}, 'pass', {});
    for k = 1:numel(levels)
        t0 = edges(k);
        t1 = edges(k + 1);
        m = (t >= t0) & (t < t1);
        uref_k = levels(k);
        % Settling relative to step instant t0
        settle_s = NaN; ok = false;
        idx = find(m);
        for ii = 1:numel(idx)
            j = idx(ii);
            if all(abs(e(j:idx(end))) <= band)
                settle_s = t(j) - t0;
                ok = true;
                break;
            end
        end
        % Overshoot vs step size from previous level
        if k == 1
            u_prev = levels(1);
            step_amp = 0;
        else
            u_prev = levels(k - 1);
            step_amp = uref_k - u_prev;
        end
        if abs(step_amp) < 1e-9
            os_pct = 0;
        else
            if step_amp > 0
                peak = max(u(m));
                os = max(0, peak - uref_k);
            else
                peak = min(u(m));
                os = max(0, uref_k - peak);
            end
            os_pct = 100 * os / abs(step_amp);
        end
        % Lag: time to first enter band after step
        lag_s = NaN;
        for ii = 1:numel(idx)
            if abs(e(idx(ii))) <= band
                lag_s = t(idx(ii)) - t0;
                break;
            end
        end
        pass_k = ok && (settle_s <= 6.0) && (os_pct <= 10.0);
        st.legs(k).t0 = t0;
        st.legs(k).t1 = t1;
        st.legs(k).uref = uref_k;
        st.legs(k).settle_s = settle_s;
        st.legs(k).persistent_ok = ok;
        st.legs(k).overshoot_pct = os_pct;
        st.legs(k).lag_s = lag_s;
        st.legs(k).pass = pass_k;
        st.legs(k).mae = mean(abs(e(m)));
        st.legs(k).signed = mean(e(m));
    end
    % Gate focuses on steps into/out of 1.5 (legs 2 and 3)
    st.pass = all([st.legs.pass]);
    st.worst_settle_s = max([st.legs.settle_s]);
    st.worst_os_pct = max([st.legs.overshoot_pct]);
end

%% ===================== gates / classification =====================
function freeze = freeze_gates(MX, MXZ, MH, Cand, pitch_gate)
    freeze = struct();
    % Absolute pitch gates (production prior)
    freeze.X.pitch_abs = MX.pitch.mae_deg <= pitch_gate.X_mae;
    freeze.XZ.pitch_abs = MXZ.pitch.mae_deg <= pitch_gate.XZ_mae;
    freeze.H.pitch_abs = (MH.pitch.mae_deg <= pitch_gate.H_mae) && ...
        (MH.pitch.p95_deg <= pitch_gate.H_p95) && ...
        (MH.pitch.elev_sat_pct <= pitch_gate.elev_sat);
    % Match closure candidate within 2% or tiny abs eps
    freeze.X.pitch_vs = within_tol(MX.pitch.mae_deg, Cand.X.pitch.mae_deg, 0.02, 1e-3);
    freeze.XZ.pitch_vs = within_tol(MXZ.pitch.mae_deg, Cand.XZ.pitch.mae_deg, 0.02, 1e-3);
    freeze.H.pitch_vs = within_tol(MH.pitch.mae_deg, Cand.H.pitch.mae_deg, 0.02, 1e-3);
    freeze.H.yaw_vs = within_tol(MH.yaw.mae_deg, Cand.H.yaw.mae_deg, 0.02, 1e-3);
    freeze.H.tilde_vs = within_tol(MH.tilde.rms_deg, Cand.H.tilde.rms_deg, 0.02, 1e-3);
    freeze.H.p_vs = within_tol(MH.p.rms_dps, Cand.H.p.rms_dps, 0.02, 1e-3);
    freeze.X.path_vs = within_tol(MX.path.mean_cte, Cand.X.path.mean_cte, 0.02, 1e-3);
    freeze.XZ.path_vs = within_tol(MXZ.path.mean_cte, Cand.XZ.path.mean_cte, 0.02, 1e-3);
    freeze.H.path_vs = within_tol(MH.path.mean_cte, Cand.H.path.mean_cte, 0.02, 1e-3);
    freeze.X.clean = (MX.tilde.mae_deg <= 0.05) && (MX.p.rms_dps <= 0.5);
    freeze.XZ.clean = (MXZ.tilde.mae_deg <= 0.05) && (MXZ.p.rms_dps <= 0.5);
    freeze.pitch_ok = freeze.X.pitch_abs && freeze.XZ.pitch_abs && freeze.H.pitch_abs;
    freeze.roll_ok = freeze.X.clean && freeze.XZ.clean && freeze.H.tilde_vs && freeze.H.p_vs;
    freeze.yaw_ok = freeze.H.yaw_vs;
    freeze.path_ok = freeze.X.path_vs && freeze.XZ.path_vs && freeze.H.path_vs;
    freeze.ok = freeze.pitch_ok && freeze.roll_ok && freeze.yaw_ok && freeze.path_ok;
    freeze.Cand = Cand;
end

function ok = within_tol(a, b, rel, abs_eps)
    if ~(isfinite(a) && isfinite(b)); ok = false; return; end
    ok = abs(a - b) <= max(abs_eps, rel * max(abs(b), abs_eps));
end

function [G, verdict, root_class, next_opt, next_detail] = score_speed(MX, MXZ, MH, MStep, freeze, law)
    G = struct();
    routes = {'X', 'XZ', 'H'};
    Ms = {MX, MXZ, MH};

    G.pref = struct(); G.hard = struct();
    for i = 1:3
        nm = routes{i};
        M = Ms{i};
        G.pref.(nm) = (M.speed.steady.mae <= 0.03) && (M.speed.steady.p95 <= 0.05);
        G.hard.(nm) = (M.speed.steady.mae <= 0.07) && (M.speed.steady.p95 <= 0.10);
        G.sat.(nm) = M.thrust.full.sat_pct <= 1.0;
        G.metrics.(nm) = M.speed.steady;
        G.thrust.(nm) = M.thrust;
    end
    G.pref_all = G.pref.X && G.pref.XZ && G.pref.H;
    G.hard_all = G.hard.X && G.hard.XZ && G.hard.H;
    G.sat_all = G.sat.X && G.sat.XZ && G.sat.H && (MStep.thrust.full.sat_pct <= 1.0);

    G.step = MStep.speed.step;
    G.step_ok = false;
    if isfield(G.step, 'pass')
        G.step_ok = G.step.pass;
    end
    % Require legs that change level (2: 1.3->1.5, 3: 1.5->1.3) if present
    if isfield(G.step, 'legs') && numel(G.step.legs) >= 3
        G.step_ok = G.step.legs(2).pass && G.step.legs(3).pass;
    end

    G.freeze = freeze;
    G.freeze_ok = freeze.ok;

    hard_pass = G.hard_all && G.sat_all && G.step_ok && G.freeze_ok;
    pref_pass = G.pref_all && hard_pass;

    if hard_pass
        verdict = 'PASS';
        if pref_pass
            root_class = 'NONE_SPEED_WITHIN_PREF_GATES';
            next_opt = 'bounded_multi_speed_envelope';
            next_detail = ['SPEED baseline PASS (pref+hard). Recommend next bounded ', ...
                'multi-speed envelope on X/XZ/R10 at {1.0,1.3,1.5,1.7} with frozen attitude.'];
        else
            root_class = 'NONE_SPEED_WITHIN_HARD_GATES';
            next_opt = 'bounded_multi_speed_envelope';
            next_detail = ['SPEED baseline PASS (hard). Pref miss but hard held. ', ...
                'Recommend bounded multi-speed envelope; no gain change.'];
        end
    else
        verdict = 'FAIL';
        [root_class, next_opt, next_detail] = classify_root(MX, MXZ, MH, MStep, G, law);
    end
    G.hard_pass = hard_pass;
    G.pref_pass = pref_pass;
end

function [root_class, next_opt, next_detail] = classify_root(MX, MXZ, MH, MStep, G, law)
    % Ordered discrimination per task taxonomy
    Ms = {MX, MXZ, MH};
    names = {'X', 'XZ', 'H'};

    % 1) Metric/frame: BODY u OK but Uh/|V| misread, or large frame gap explaining gate fail
    frame_issue = false;
    for i = 1:3
        M = Ms{i};
        if M.speed.frame_gap_Uh > 0.05 || M.speed.frame_gap_V > 0.08
            % If BODY hard FAIL but |mean(e_u)| small while Uh error large → frame confusion
            if ~G.hard.(names{i}) && abs(M.speed.steady.signed_mean) <= 0.07 && ...
                    abs(M.speed.Uh_steady.signed_mean) > 0.10
                frame_issue = true;
            end
        end
    end
    if frame_issue
        root_class = 'METRIC_FRAME_ISSUE';
        next_opt = 'audit_speed_metric_frame';
        next_detail = 'BODY u vs Uh/|V| disagreement drives metric; confirm BODY u as sole controller gate before envelope.';
        return;
    end

    % 2) Thrust authority / saturation
    sat_fail = ~G.sat_all;
    near_hi = any(cellfun(@(M) M.thrust.full.near_pct > 5, Ms)) || MStep.thrust.full.near_pct > 5;
    if sat_fail || near_hi
        root_class = 'THRUST_AUTHORITY_SATURATION';
        next_opt = 'audit_thrust_authority_limits';
        next_detail = 'Thrust near/at limits; single audit of authority/clipping before multi-speed envelope.';
        return;
    end

    % 3) Path-energy demand: X hold OK, curved/climb worse
    x_ok = G.hard.X;
    curved_bad = (~G.hard.XZ) || (~G.hard.H);
    if x_ok && curved_bad
        root_class = 'PATH_ENERGY_DEMAND';
        next_opt = 'audit_path_energy_speed_schedule';
        next_detail = 'Straight hold OK; XZ/R10 speed error elevated — path-energy / schedule demand; audit guidance u_ref cut vs drag before envelope.';
        return;
    end

    % 4) Trim-table / thrust_trim bias vs proportional identity
    e_means = [MX.speed.steady.signed_mean, MXZ.speed.steady.signed_mean, MH.speed.steady.signed_mean];
    thr_means = [MX.thrust.steady.mean, MXZ.thrust.steady.mean, MH.thrust.steady.mean];
    e_from_thr = (thr_means - law.thrust_trim) / max(law.Kp_x, eps);
    prop_match = max(abs(e_means - e_from_thr)) < 0.01;
    large_bias = any(abs(e_means) > 0.03);
    % Trim bias if steady thrust far from thrust_trim while e tracks prop law,
    % and bias direction consistent with wrong thrust_trim set-point
    trim_off = abs(mean(thr_means) - law.thrust_trim) > 2.0;
    if prop_match && large_bias && trim_off
        root_class = 'TRIM_TABLE_BIAS';
        next_opt = 'audit_thrust_trim_at_Uref';
        next_detail = sprintf(['Steady e_u≈(T-Ttrim)/Kp_x with |e| large and T≠Ttrim=%.2f N; ', ...
            'single thrust_trim@Uref audit (no gain) before envelope.'], law.thrust_trim);
        return;
    end

    % 5) Proportional steady offset (no integral) — dominant consistent signed bias
    if prop_match && large_bias
        root_class = 'PROPORTIONAL_STEADY_OFFSET';
        next_opt = 'audit_surge_integral_or_trim';
        next_detail = 'P-only surge leaves consistent steady e_u=(Tss-Ttrim)/Kp_x; one minimal trim/I audit before envelope (no Kp_x change).';
        return;
    end

    if ~G.step_ok
        root_class = 'PROPORTIONAL_STEADY_OFFSET';
        next_opt = 'audit_step_settle_surge';
        next_detail = 'Step settle/overshoot FAIL under P-only thrust; single settle audit (trim/I) before envelope.';
        return;
    end

    if ~G.freeze_ok
        root_class = 'UNKNOWN';
        next_opt = 'audit_freeze_regression_source';
        next_detail = 'Frozen pitch/yaw/roll/path gate mismatch vs ROLL_PRODUCTION_CLOSURE; investigate before speed envelope.';
        return;
    end

    root_class = 'UNKNOWN';
    next_opt = 'audit_speed_evidence_gap';
    next_detail = 'Insufficient discrimination among trim/P-offset/authority/path/frame; UNKNOWN — gather one targeted evidence audit.';
end

%% ===================== artifacts =====================
function write_png(png_path, SX, SXZ, SH, SStep, MX, MXZ, MH, MStep, lim, task_id, verdict)
    fig = figure('Visible', 'off', 'Position', [40 40 1400 1000]);
    try
        % Row1: uref/u
        subplot(3, 3, 1); plot_uv(SX, 'X'); title('X: u_{ref}/u');
        subplot(3, 3, 2); plot_uv(SXZ, 'XZ'); title('XZ: u_{ref}/u');
        subplot(3, 3, 3); plot_uv(SH, 'R10'); title('R10: u_{ref}/u');
        % Row2: errors + Uh/|V|
        subplot(3, 3, 4); plot_err(SX); title('X: e_u / e_{Uh} / e_{|V|}');
        subplot(3, 3, 5); plot_err(SXZ); title('XZ: e_u / e_{Uh} / e_{|V|}');
        subplot(3, 3, 6); plot_err(SH); title('R10: e_u / e_{Uh} / e_{|V|}');
        % Row3: thrust + step + attitude
        subplot(3, 3, 7); plot_thrust(SX, SXZ, SH, lim); title('Thrust components');
        subplot(3, 3, 8); plot_step(SStep, lim); title('STEP 1.3->1.5->1.3', 'Interpreter', 'none');
        subplot(3, 3, 9); plot_att(MX, MXZ, MH, MStep); title('Attitude/path (steady)');
        sgtitle(sprintf('%s | %s', task_id, verdict), 'Interpreter', 'none');
        saveas(fig, png_path);
    catch ME
        fprintf('PNG warn: %s\n', ME.message);
    end
    close(fig);
end

function plot_uv(S, ~)
    plot(S.t, S.u_ref, 'k--', S.t, S.u_ctrl, 'b', S.t, S.Uh, 'g:', S.t, S.Vtot, 'm:');
    grid on; xlabel('t [s]'); ylabel('[m/s]');
    legend('u_{ref}', 'u_{body}', 'U_h', '|V|', 'Location', 'best');
end

function plot_err(S)
    eu = S.u_ref - S.u_ctrl;
    eUh = S.u_ref - S.Uh;
    eV = S.u_ref - S.Vtot;
    plot(S.t, eu, 'b', S.t, eUh, 'g:', S.t, eV, 'm:');
    yline(0.05, 'r--'); yline(-0.05, 'r--');
    grid on; xlabel('t [s]'); ylabel('error [m/s]');
    legend('e_u', 'e_{Uh}', 'e_{|V|}', 'Location', 'best');
end

function plot_thrust(SX, SXZ, SH, lim)
    plot(SX.t, SX.thrust, 'b', SXZ.t, SXZ.thrust, 'r', SH.t, SH.thrust, 'k');
    hold on;
    plot(SX.t, SX.thrust_trim, 'b--', SX.t, SX.thrust_prop, 'b:');
    yline(lim.thrust_max, 'r--'); yline(lim.thrust_min, 'r--');
    grid on; xlabel('t [s]'); ylabel('thrust [N]');
    legend('X', 'XZ', 'R10', 'T_{trim}', 'T_{prop}', 'Location', 'best');
end

function plot_step(S, lim)
    yyaxis left;
    plot(S.t, S.u_ref, 'k--', S.t, S.u_ctrl, 'b');
    ylabel('u [m/s]');
    yyaxis right;
    plot(S.t, S.thrust, 'r');
    ylabel('thrust [N]');
    yline(lim.thrust_max, 'r:');
    grid on; xlabel('t [s]');
    legend('u_{ref}', 'u', 'thrust', 'Location', 'best');
end

function plot_att(MX, MXZ, MH, MStep)
    names = {'X', 'XZ', 'R10', 'Step'};
    pitch = [MX.pitch.mae_deg, MXZ.pitch.mae_deg, MH.pitch.mae_deg, MStep.pitch.mae_deg];
    yaw = [MX.yaw.mae_deg, MXZ.yaw.mae_deg, MH.yaw.mae_deg, MStep.yaw.mae_deg];
    cte = [MX.path.mean_cte, MXZ.path.mean_cte, MH.path.mean_cte, MStep.path.mean_cte];
    bar([pitch; yaw; cte]');
    set(gca, 'XTickLabel', names);
    legend('pitchMAE', 'yawMAE', 'CTE', 'Location', 'best');
    ylabel('deg / m'); grid on;
end

function write_md(md_path, task_id, verdict, law, MX, MXZ, MH, MStep, G, freeze, ...
        root_class, next_opt, next_detail, seed, md, mat, png, closure, ctrl, initp)
    fid = fopen(md_path, 'w');
    fprintf(fid, '# %s — Surge-speed baseline / root cause\n\n', task_id);
    fprintf(fid, '**Overall verdict: %s**\n\n', verdict);
    fprintf(fid, '## Provenance\n\n');
    fprintf(fid, '- Read-only: `%s`, `%s`, `%s`\n', closure, ctrl, initp);
    fprintf(fid, '- Driver: `run_speed_baseline_audit.m` (one invocation; no production edit)\n');
    fprintf(fid, '- Artifacts: `%s`, `%s`, `%s`\n', md, mat, png);
    fprintf(fid, '- Seed: %d | Kp_roll frozen=%.6f | Kp_x=%.4g | thrust_trim=%.4g N\n\n', ...
        seed, law.Kp_roll, law.Kp_x, law.thrust_trim);

    fprintf(fid, '## Law / frame / units\n\n');
    fprintf(fid, '```\n%s\nFrame: %s\nUnits: %s\n```\n\n', law.equation, law.frame, law.units);

    fprintf(fid, '## Steady hold metrics (BODY u vs u_ref)\n\n');
    fprintf(fid, '| Route | signed | MAE | RMS | p95 | max | Uh_mean | |V|_mean | frame_gap_Uh |\n');
    fprintf(fid, '|-------|-------:|----:|----:|----:|----:|--------:|--------:|-------------:|\n');
    dump_spd_row(fid, 'X', MX);
    dump_spd_row(fid, 'XZ', MXZ);
    dump_spd_row(fid, 'R10', MH);

    fprintf(fid, '\n## Thrust (steady hold)\n\n');
    fprintf(fid, '| Route | mean | RMS | rateRMS | near%% | sat%% | trim | prop | trim_frac |\n');
    fprintf(fid, '|-------|-----:|----:|--------:|------:|-----:|-----:|-----:|----------:|\n');
    dump_thr_row(fid, 'X', MX);
    dump_thr_row(fid, 'XZ', MXZ);
    dump_thr_row(fid, 'R10', MH);
    dump_thr_row(fid, 'STEP', MStep);

    fprintf(fid, '\n## Step 1.3→1.5→1.3\n\n');
    if isfield(MStep.speed, 'step') && isfield(MStep.speed.step, 'legs')
        fprintf(fid, '| Leg | uref | settle_s | OS%% | lag_s | MAE | signed | PASS |\n');
        fprintf(fid, '|-----|-----:|---------:|----:|------:|----:|-------:|:----:|\n');
        for k = 1:numel(MStep.speed.step.legs)
            L = MStep.speed.step.legs(k);
            fprintf(fid, '| %d | %.2f | %.3f | %.2f | %.3f | %.4f | %.4f | %s |\n', ...
                k, L.uref, L.settle_s, L.overshoot_pct, L.lag_s, L.mae, L.signed, yn(L.pass));
        end
    end

    fprintf(fid, '\n## Coupling / freeze vs ROLL_PRODUCTION_CLOSURE\n\n');
    fprintf(fid, '| Route | pitchMAE | yawMAE | tildeRMS/MAE | pRMS | CTE | freeze |\n');
    fprintf(fid, '|-------|---------:|-------:|-------------:|-----:|----:|:------:|\n');
    fprintf(fid, '| X | %.4f | %.4f | MAE %.4f | %.4f | %.4f | %s |\n', ...
        MX.pitch.mae_deg, MX.yaw.mae_deg, MX.tilde.mae_deg, MX.p.rms_dps, MX.path.mean_cte, yn(freeze.X.clean && freeze.X.pitch_abs));
    fprintf(fid, '| XZ | %.4f | %.4f | MAE %.4f | %.4f | %.4f | %s |\n', ...
        MXZ.pitch.mae_deg, MXZ.yaw.mae_deg, MXZ.tilde.mae_deg, MXZ.p.rms_dps, MXZ.path.mean_cte, yn(freeze.XZ.clean && freeze.XZ.pitch_abs));
    fprintf(fid, '| R10 | %.4f | %.4f | RMS %.4f | %.4f | %.4f | %s |\n', ...
        MH.pitch.mae_deg, MH.yaw.mae_deg, MH.tilde.rms_deg, MH.p.rms_dps, MH.path.mean_cte, yn(freeze.H.pitch_abs && freeze.H.yaw_vs));

    fprintf(fid, '\n## Gate table\n\n');
    fprintf(fid, '| Gate | Result | Detail |\n');
    fprintf(fid, '|------|:------:|--------|\n');
    fprintf(fid, '| Pref u MAE≤0.03 p95≤0.05 (X/XZ/R10) | %s | X=%s XZ=%s H=%s |\n', ...
        yn(G.pref_all), yn(G.pref.X), yn(G.pref.XZ), yn(G.pref.H));
    fprintf(fid, '| Hard u MAE≤0.07 p95≤0.10 (X/XZ/R10) | %s | X=%s XZ=%s H=%s |\n', ...
        yn(G.hard_all), yn(G.hard.X), yn(G.hard.XZ), yn(G.hard.H));
    fprintf(fid, '| Step settle≤6s OS≤10%% ±0.05 | %s | worst_ts=%.3f worst_OS=%.2f |\n', ...
        yn(G.step_ok), nz(G.step, 'worst_settle_s'), nz(G.step, 'worst_os_pct'));
    fprintf(fid, '| Thrust sat≤1%% | %s | X=%.2f XZ=%.2f H=%.2f Step=%.2f |\n', ...
        yn(G.sat_all), MX.thrust.full.sat_pct, MXZ.thrust.full.sat_pct, ...
        MH.thrust.full.sat_pct, MStep.thrust.full.sat_pct);
    fprintf(fid, '| Frozen pitch/yaw/roll/path | %s | pitch=%s yaw=%s roll=%s path=%s |\n', ...
        yn(G.freeze_ok), yn(freeze.pitch_ok), yn(freeze.yaw_ok), yn(freeze.roll_ok), yn(freeze.path_ok));

    fprintf(fid, '\n## Root class / decision\n\n');
    fprintf(fid, '- Root class: **%s**\n', root_class);
    fprintf(fid, '- Verdict: **%s**\n', verdict);
    fprintf(fid, '- Next: `%s`\n', next_opt);
    fprintf(fid, '- Detail: %s\n', next_detail);
    fprintf(fid, '- Production: untouched (no gain / no law edit)\n\n');

    fprintf(fid, '## Feedback\n\n');
    fprintf(fid, '- PASS/FAIL: **%s**\n', verdict);
    fprintf(fid, '- Key: X mae/p95=%.4f/%.4f | XZ=%.4f/%.4f | R10=%.4f/%.4f | step_ok=%s\n', ...
        MX.speed.steady.mae, MX.speed.steady.p95, MXZ.speed.steady.mae, MXZ.speed.steady.p95, ...
        MH.speed.steady.mae, MH.speed.steady.p95, yn(G.step_ok));
    fprintf(fid, '- Root: %s\n', root_class);
    fprintf(fid, '- Files: `%s` `%s` `%s`\n', md, mat, png);
    fprintf(fid, '- Next: %s\n', next_opt);
    fclose(fid);
end

function dump_spd_row(fid, name, M)
    fprintf(fid, '| %s | %.4f | %.4f | %.4f | %.4f | %.4f | %.4f | %.4f | %.4f |\n', ...
        name, M.speed.steady.signed_mean, M.speed.steady.mae, M.speed.steady.rms, ...
        M.speed.steady.p95, M.speed.steady.max, M.speed.Uh_mean, M.speed.Vtot_mean, ...
        M.speed.frame_gap_Uh);
end

function dump_thr_row(fid, name, M)
    T = M.thrust.steady;
    F = M.thrust.full;
    fprintf(fid, '| %s | %.3f | %.3f | %.3f | %.2f | %.2f | %.3f | %.3f | %.3f |\n', ...
        name, T.mean, T.rms, T.rate_rms, T.near_pct, F.sat_pct, T.trim_mean, T.prop_mean, T.trim_frac);
end

function v = nz(S, f)
    if isstruct(S) && isfield(S, f); v = S.(f); else; v = NaN; end
end

function append_ss_audit(out_dir, task_id, verdict, law, MX, MXZ, MH, MStep, G, ...
        root_class, next_opt, next_detail, md, mat, png)
    audit_path = fullfile(out_dir, 'STATE_SPACE_MODEL_AUDIT.md');
    fid = fopen(audit_path, 'a');
    fprintf(fid, '\n\n---\n\n');
    fprintf(fid, '## %s — %s\n\n', task_id, datestr(now, 'yyyy-mm-dd HH:MM:SS'));
    fprintf(fid, '### Provenance\n\n');
    fprintf(fid, '- Read-only: `ROLL_PRODUCTION_CLOSURE.mat`, `controller_law.m`, `init_parameters.m`\n');
    fprintf(fid, '- Driver: `run_speed_baseline_audit.m` (one invocation; production untouched)\n');
    fprintf(fid, '- Artifacts: `%s`, `%s`, `%s`\n\n', md, mat, png);
    fprintf(fid, '### Equations / units / frame\n\n');
    fprintf(fid, '```\n');
    fprintf(fid, 'Thrust law: %s\n', law.equation);
    fprintf(fid, 'Controller variable: BODY u [m/s]; e_u = u_ref - u\n');
    fprintf(fid, 'Reported separately: Uh = hypot(xdot,ydot) [m/s]; |V| = ||[u v w]|| [m/s]\n');
    fprintf(fid, 'Kp_x = %.6g N/(m/s); thrust_trim = %.6g N; limits [%.0f, %.0f] N\n', ...
        law.Kp_x, law.thrust_trim, law.thrust_min, law.thrust_max);
    fprintf(fid, 'u_trim / desired_speed = %.3g / %.3g m/s\n', law.u_trim, law.desired_speed);
    fprintf(fid, 'Guidance may schedule u_ref <= desired_speed (curvature / near_end)\n');
    fprintf(fid, '```\n\n');
    fprintf(fid, '### Steady hold (BODY u)\n\n');
    fprintf(fid, '| Route | signed e_u | MAE | p95 | thr_mean | sat%% |\n');
    fprintf(fid, '|-------|----------:|----:|----:|---------:|-----:|\n');
    fprintf(fid, '| X | %.4f | %.4f | %.4f | %.3f | %.2f |\n', ...
        MX.speed.steady.signed_mean, MX.speed.steady.mae, MX.speed.steady.p95, ...
        MX.thrust.steady.mean, MX.thrust.full.sat_pct);
    fprintf(fid, '| XZ | %.4f | %.4f | %.4f | %.3f | %.2f |\n', ...
        MXZ.speed.steady.signed_mean, MXZ.speed.steady.mae, MXZ.speed.steady.p95, ...
        MXZ.thrust.steady.mean, MXZ.thrust.full.sat_pct);
    fprintf(fid, '| R10 | %.4f | %.4f | %.4f | %.3f | %.2f |\n', ...
        MH.speed.steady.signed_mean, MH.speed.steady.mae, MH.speed.steady.p95, ...
        MH.thrust.steady.mean, MH.thrust.full.sat_pct);
    fprintf(fid, '\n### Verdict / next\n\n');
    fprintf(fid, '- Verdict: **%s**\n', verdict);
    fprintf(fid, '- Root class: **%s**\n', root_class);
    fprintf(fid, '- Pref/Hard/Step/Freeze: %s/%s/%s/%s\n', ...
        yn(G.pref_pass), yn(G.hard_pass), yn(G.step_ok), yn(G.freeze_ok));
    fprintf(fid, '- Next: `%s` — %s\n', next_opt, next_detail);
    fprintf(fid, '- Production: untouched\n\n');
    fprintf(fid, '### Next\n\n');
    fprintf(fid, '- %s\n', next_opt);
    fclose(fid);
end

function print_feedback(verdict, law, MX, MXZ, MH, MStep, G, freeze, ...
        root_class, next_opt, next_detail, md, mat, png)
    fprintf('\n----- FEEDBACK -----\n');
    fprintf('PASS/FAIL: %s\n', verdict);
    fprintf('Key metrics (BODY u hold): X mae/p95/signed=%.4f/%.4f/%.4f | XZ=%.4f/%.4f/%.4f | R10=%.4f/%.4f/%.4f\n', ...
        MX.speed.steady.mae, MX.speed.steady.p95, MX.speed.steady.signed_mean, ...
        MXZ.speed.steady.mae, MXZ.speed.steady.p95, MXZ.speed.steady.signed_mean, ...
        MH.speed.steady.mae, MH.speed.steady.p95, MH.speed.steady.signed_mean);
    fprintf('Thrust mean/sat: X=%.2f/%.2f%% XZ=%.2f/%.2f%% R10=%.2f/%.2f%% | Kp_x=%.3g Ttrim=%.3g\n', ...
        MX.thrust.steady.mean, MX.thrust.full.sat_pct, ...
        MXZ.thrust.steady.mean, MXZ.thrust.full.sat_pct, ...
        MH.thrust.steady.mean, MH.thrust.full.sat_pct, law.Kp_x, law.thrust_trim);
    if isfield(MStep.speed, 'step') && isfield(MStep.speed.step, 'worst_settle_s')
        fprintf('Step: settle_worst=%.3fs OS_worst=%.2f%% pass=%s\n', ...
            MStep.speed.step.worst_settle_s, MStep.speed.step.worst_os_pct, yn(G.step_ok));
    end
    fprintf('Freeze pitch/yaw/roll/path: %s/%s/%s/%s\n', ...
        yn(freeze.pitch_ok), yn(freeze.yaw_ok), yn(freeze.roll_ok), yn(freeze.path_ok));
    fprintf('Root class: %s\n', root_class);
    fprintf('Files: %s | %s | %s\n', md, mat, png);
    fprintf('Next: %s — %s\n', next_opt, next_detail);
end

%% ===================== helpers =====================
function y = align_len(v, n)
    v = v(:);
    if numel(v) >= n
        y = v(1:n);
    else
        y = [v; zeros(n - numel(v), 1)];
    end
end

function st = err_stats_deg(e, mask)
    st = struct('mae_deg', NaN, 'rms_deg', NaN, 'p95_deg', NaN, 'max_deg', NaN, ...
        'signed_mean_deg', NaN, 'n', 0);
    if ~any(mask); return; end
    v = e(mask);
    st.n = numel(v);
    st.signed_mean_deg = rad2deg(mean(v));
    st.mae_deg = rad2deg(mean(abs(v)));
    st.rms_deg = rad2deg(rms_local(v));
    st.p95_deg = rad2deg(prctile_local(abs(v), 95));
    st.max_deg = rad2deg(max(abs(v)));
end

function st = actuator_stats(u, udot, mask, umax, near_frac)
    st = struct('rms_deg', NaN, 'rate_rms_dps', NaN, 'sat_pct', NaN, ...
        'near_pct', NaN, 'n', 0);
    if ~any(mask); return; end
    v = u(mask); vd = udot(mask);
    st.n = numel(v);
    st.rms_deg = rad2deg(rms_local(v));
    st.rate_rms_dps = rad2deg(rms_local(vd));
    st.sat_pct = 100 * mean(abs(v) >= 0.95 * umax);
    st.near_pct = 100 * mean(abs(v) >= near_frac * umax);
end

function y = sat_pct(u, mask, thr)
    if ~any(mask); y = NaN; return; end
    y = 100 * mean(abs(u(mask)) >= thr);
end

function r = rms_local(x)
    x = x(:); r = sqrt(mean(x.^2));
end

function p = prctile_local(x, q)
    x = sort(x(:));
    if isempty(x); p = NaN; return; end
    k = max(1, min(numel(x), round(q / 100 * numel(x))));
    p = x(k);
end

function m = mean_safe(x, mask)
    if ~any(mask); m = NaN; return; end
    m = mean(x(mask));
end

function s = yn(tf)
    if tf; s = 'YES'; else; s = 'NO'; end
end
