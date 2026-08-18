function run_roll_baseline_audit()
% ROLL_BASELINE_AUDIT_001 — roll baseline + root-cause on accepted X/XZ/R10.
% Read-only: pitch_yaw_closure.mat, LOCAL_SS_LEVEL.mat, LOCAL_SS_CLIMB.mat.
% If closure lacks phi/p/rudder/yaw-rate, re-run accepted closure once with
% diagnostics (no retune; no controller/guidance/plant edit).
% One MATLAB invocation. Artifacts: suite_results/ROLL_BASELINE_AUDIT.{md,mat,png}

    project_dir = fileparts(mfilename('fullpath'));
    addpath(project_dir);
    out_dir = fullfile(project_dir, 'suite_results');
    if ~exist(out_dir, 'dir'); mkdir(out_dir); end
    tag = 'ROLL_BASELINE_AUDIT';
    task_id = 'ROLL_BASELINE_AUDIT_001';

    closure_path = fullfile(out_dir, 'pitch_yaw_closure.mat');
    level_path   = fullfile(out_dir, 'LOCAL_SS_LEVEL.mat');
    climb_path   = fullfile(out_dir, 'LOCAL_SS_CLIMB.mat');
    assert(exist(closure_path, 'file') == 2, 'Missing %s', closure_path);
    assert(exist(level_path, 'file') == 2, 'Missing %s', level_path);
    assert(exist(climb_path, 'file') == 2, 'Missing %s', climb_path);

    Clos = load(closure_path);
    Lss  = load(level_path);
    Css  = load(climb_path);

    fprintf('\n========== %s ==========\n', task_id);
    fprintf('Sources: pitch_yaw_closure.mat / LOCAL_SS_LEVEL.mat / LOCAL_SS_CLIMB.mat\n');

    % ---- Plant roll mode from validated lateral SS ----
    plant = extract_roll_plant(Lss, Css);
    fprintf('Plant roll level: %.4e +/- j%.4f (f=%.3f Hz, zeta=%.4f)\n', ...
        real(plant.level.lam), imag(plant.level.lam), plant.level.f_Hz, plant.level.zeta);
    fprintf('Plant roll climb: %.4e +/- j%.4f (f=%.3f Hz, zeta=%.4f)\n', ...
        real(plant.climb.lam), imag(plant.climb.lam), plant.climb.f_Hz, plant.climb.zeta);

    % ---- Channel inventory on closure MAT ----
    inv = inventory_closure(Clos);
    fprintf('Closure channels: X phi/p/dr=%d/%d/%d | XZ=%d/%d/%d | H=%d/%d/%d\n', ...
        inv.X.has_phi, inv.X.has_p, inv.X.has_dr, ...
        inv.XZ.has_phi, inv.XZ.has_p, inv.XZ.has_dr, ...
        inv.H.has_phi, inv.H.has_p, inv.H.has_dr);

    need_resim = ~(inv.X.ok && inv.XZ.ok && inv.H.ok);
    if need_resim
        fprintf('Missing roll diagnostics on closure MAT → re-run accepted closure once (no retune).\n');
    else
        fprintf('Closure MAT has required roll channels; analyzing stored series.\n');
    end

    % ---- Frozen accepted production stack (match final closure) ----
    clear functions
    clear guidance_law controller_law
    clear global lambda_muw_ff trim_speed_table trim_elevator_table elevator_sign
    clear global K_zdot K_gamma enable_alpha_hat
    clear global last_guidance_U_h last_guidance_kappa last_r_ff

    init_parameters();
    global lambda_muw_ff elevator_sign trim_speed_table trim_elevator_table
    global K_zdot K_gamma enable_alpha_hat
    global dt_controller delta_e_max delta_r_max

    elevator_sign = 1;
    trim_speed_table = [0.8 1.0 1.5 2.0];
    trim_elevator_table = deg2rad([-9.18 -7.33 -4.62 -3.17]);
    K_gamma = 0; K_zdot = 0; enable_alpha_hat = false;
    k_gamma = 0.1320695001;
    de_climb_lim_deg = 2.8793;
    seed_used = 0;
    rng(seed_used, 'twister');

    % Capsule pitch/yaw gates (preserved)
    capX = Clos.capX; capXZ = Clos.capXZ; capH = Clos.capH;
    pathX = Clos.pathX; pathXZ = Clos.pathXZ; pathH = Clos.pathH;

    % ---- Acquire diagnostic timeseries (resim if needed) ----
    if need_resim || ~inv.X.ok
        rng(seed_used, 'twister');
        SX = sim_straight(pathX, 18, 1.5, 0.25, k_gamma, de_climb_lim_deg);
        MX = analyze_route(SX, pathX, 'first_hold', false, plant.level, delta_r_max, delta_e_max);
    else
        SX = series_from_closure_straight(Clos.mX{1});
        MX = analyze_route(SX, pathX, 'first_hold', false, plant.level, delta_r_max, delta_e_max);
    end

    if need_resim || ~inv.XZ.ok
        rng(seed_used, 'twister');
        SXZ = sim_straight(pathXZ, 22, 1.5, 0.0, k_gamma, de_climb_lim_deg);
        MXZ = analyze_route(SXZ, pathXZ, 'persistent', true, plant.climb, delta_r_max, delta_e_max);
    else
        SXZ = series_from_closure_straight(Clos.mXZ{1});
        MXZ = analyze_route(SXZ, pathXZ, 'persistent', true, plant.climb, delta_r_max, delta_e_max);
    end

    if need_resim || ~inv.H.ok
        rng(seed_used, 'twister');
        lambda_muw_ff = 0.25;
        SH = sim_helix(pathH, 45, 1.5, 10.0);
        MH = analyze_route(SH, pathH, 'persistent', false, plant.level, delta_r_max, delta_e_max);
        MH = attach_helix_yaw(MH, SH, pathH, 10.0, delta_r_max);
    else
        SH = series_from_closure_helix(Clos.SH{1});
        MH = analyze_route(SH, pathH, 'persistent', false, plant.level, delta_r_max, delta_e_max);
        MH = attach_helix_yaw(MH, SH, pathH, 10.0, delta_r_max);
        if isfield(Clos, 'MH') && ~isempty(Clos.MH)
            MH.yaw_capsule = Clos.MH{1}.yaw;
            MH.pitch_capsule = Clos.MH{1}.pitch;
        end
    end

    % ---- Pitch/yaw gate preservation vs capsule ----
    py = pitch_yaw_preserve(MX, MXZ, MH, capX, capXZ, capH);

    % ---- Roll gates ----
    gates = roll_gates(MX, MXZ, MH, py);
    hard_pass = gates.hard_pass;
    pref_pass = gates.pref_pass;
    if hard_pass
        verdict = 'PASS';
        root_class = 'NONE_ROLL_WITHIN_HARD_GATES';
        next_opt = 'freeze_roll_no_controller';
        next_detail = 'All hard roll gates PASS; freeze roll baseline; recommend no controller change.';
    else
        verdict = 'FAIL';
        [root_class, next_opt, next_detail] = classify_root(MX, MXZ, MH, plant, gates);
    end

    % ---- Write artifacts ----
    md_path  = fullfile(out_dir, [tag '.md']);
    mat_path = fullfile(out_dir, [tag '.mat']);
    png_path = fullfile(out_dir, [tag '.png']);

    write_png(png_path, SX, SXZ, SH, MX, MXZ, MH, delta_r_max, task_id, verdict);
    write_md(md_path, task_id, verdict, plant, inv, need_resim, MX, MXZ, MH, ...
        gates, py, root_class, next_opt, next_detail, k_gamma, seed_used, ...
        md_path, mat_path, png_path, closure_path, level_path, climb_path);
    append_ss_audit(out_dir, task_id, verdict, plant, MX, MXZ, MH, gates, ...
        root_class, next_opt, next_detail, md_path, mat_path, png_path, need_resim);

    S = struct();
    S.task_id = task_id;
    S.verdict = verdict;
    S.root_class = root_class;
    S.next_opt = next_opt;
    S.next_detail = next_detail;
    S.need_resim = need_resim;
    S.inventory = inv;
    S.plant = plant;
    S.X = MX; S.XZ = MXZ; S.H = MH;
    S.SX = SX; S.SXZ = SXZ; S.SH = SH;
    S.gates = gates;
    S.pitch_yaw_preserve = py;
    S.k_gamma = k_gamma;
    S.seed_used = seed_used;
    S.sources = {closure_path; level_path; climb_path};
    S.paths = struct('md', md_path, 'mat', mat_path, 'png', png_path);
    S.note = ['Roll baseline on accepted X/XZ/R10; diagnostics resim if MAT lacked channels; ' ...
              'no controller edit'];
    save(mat_path, '-struct', 'S');

    fprintf('\nVERDICT: %s | root=%s | next=%s\n', verdict, root_class, next_opt);
    fprintf('Saved: %s\n%s\n%s\n', md_path, mat_path, png_path);
    print_feedback(verdict, MX, MXZ, MH, gates, root_class, next_opt, next_detail, ...
        md_path, mat_path, png_path);
    assignin('base', 'ROLL_BASELINE_AUDIT_PASS', strcmp(verdict, 'PASS'));
end

%% ===================== plant roll from LOCAL_SS =====================
function plant = extract_roll_plant(Lss, Css)
    plant = struct();
    plant.level = roll_mode_from_ss(Lss);
    plant.climb = roll_mode_from_ss(Css);
    plant.frame = 'NED eta + BODY nu; Euler ZYX; lateral [y phi psi v p r] w/ [dr]';
    plant.units = 'phi [rad], p [rad/s], dr [rad]; reported deg / deg/s';
    if isfield(Lss, 'ix_lateral')
        plant.ix_lateral = Lss.ix_lateral;
    else
        plant.ix_lateral = [2, 4, 6, 8, 10, 12];
    end
    plant.cond_Qc_lateral_level = 6.37e5;  % CTRL_OBS capsule
    plant.cond_Qc_lateral_climb = 6.35e5;
end

function m = roll_mode_from_ss(SS)
    ev = SS.eig_A(:);
    % Prefer lateral eigenvalues if partition available
    if isfield(SS, 'A_lateral')
        evL = eig(SS.A_lateral);
    else
        evL = ev;
    end
    [~, k] = max(abs(imag(evL)));
    lam = evL(k);
    if imag(lam) < 0; lam = conj(lam); end
    wn = abs(lam);
    zeta = -real(lam) / max(wn, eps);
    m = struct();
    m.lam = lam;
    m.wn = wn;
    m.zeta = zeta;
    m.f_Hz = imag(lam) / (2 * pi);
    m.T_s = 1 / max(m.f_Hz, eps);
    m.source = 'LOCAL_SS lateral / eig_A';
end

%% ===================== inventory =====================
function inv = inventory_closure(Clos)
    inv = struct();
    inv.X = check_straight_logs(Clos.mX{1});
    inv.XZ = check_straight_logs(Clos.mXZ{1});
    inv.H = check_helix(Clos.SH{1});
end

function c = check_straight_logs(m)
    L = m.logs;
    c.has_phi = isfield(L, 'phi') || isfield(L, 'ori');
    c.has_p = isfield(L, 'p') || isfield(L, 'rates');
    c.has_dr = isfield(L, 'delta_r') || isfield(L, 'dr');
    c.has_r = isfield(L, 'r') || isfield(L, 'rates');
    c.ok = c.has_phi && c.has_p && c.has_dr && c.has_r;
end

function c = check_helix(S)
    c.has_phi = isfield(S, 'ori') && size(S.ori, 2) >= 1;
    c.has_p = isfield(S, 'rates') && size(S.rates, 2) >= 1;
    c.has_dr = isfield(S, 'delta_r');
    c.has_r = isfield(S, 'rates') && size(S.rates, 2) >= 3;
    c.ok = c.has_phi && c.has_p && c.has_dr && c.has_r;
end

%% ===================== sims (diagnostic; frozen stack) =====================
function S = sim_straight(path, T_final, u0, lambda, k_gamma, de_climb_lim_deg) %#ok<INUSD>
    global dt_controller lambda_muw_ff
    lambda_muw_ff = lambda;
    clear guidance_law controller_law
    dt = dt_controller;
    n_steps = round(T_final / dt);

    state = zeros(12, 1);
    state(1:3) = path(1, :)';
    d = path(2, :) - path(1, :);
    state(5) = -atan2(d(3), norm(d(1:2)));
    state(6) = atan2(d(2), d(1));
    state(7) = u0;

    global dt_guidance
    if isempty(dt_guidance); dt_guidance = dt; end
    guidance_period = max(1, round(dt_guidance / dt));
    yaw_ref = 0; pitch_ref = 0; u_ref = u0; r_ff = 0; pitch_ref_dot = 0; pidx = 1;

    S = struct();
    S.dt = dt; S.T_final = T_final; S.u0 = u0; S.lambda = lambda;
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
    S.r_ff = zeros(n_steps, 1);

    global last_delta_e
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
        S.delta_e(k) = last_delta_e;
        S.r_ff(k) = r_ff;
    end
end

function S = sim_helix(path, T_final, u0, R)
    global dt_controller dt_guidance
    global last_guidance_U_h last_guidance_kappa last_r_ff
    global last_delta_e

    clear guidance_law controller_law
    last_guidance_U_h = []; last_guidance_kappa = []; last_r_ff = [];
    last_delta_e = [];
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
        S.delta_e(k) = last_delta_e;
        S.U_h(k) = Uh;
        if isempty(last_guidance_U_h); last_guidance_U_h = Uh; end
        if isempty(last_guidance_kappa); last_guidance_kappa = 1 / R; end
        if isempty(last_r_ff); last_r_ff = r_ff; end
        S.U_h_guid(k) = last_guidance_U_h;
        S.kappa(k) = last_guidance_kappa;
        S.r_ff(k) = last_r_ff;
    end
end

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

%% ===================== analyze =====================
function M = analyze_route(S, path, win_mode, is_xz, plant_mode, dr_max, de_max)
    t = S.t(:);
    dt = S.dt;
    phi = S.ori(:, 1);
    theta_phys = -S.ori(:, 2);
    psi = S.ori(:, 3);
    p = S.rates(:, 1);
    q = S.rates(:, 2);
    r = S.rates(:, 3);
    dr = S.delta_r(:);
    de = S.delta_e(:);
    psi_ref = S.psi_ref(:);
    theta_ref = S.theta_ref(:);
    e_psi = wrapToPi(psi_ref - psi);
    e_th = theta_ref - theta_phys;
    phi_ref = zeros(size(phi));  % ref=0
    e_phi = phi_ref - phi;       % signed error (0 - phi) = -phi

    pm = compute_path_following_metrics(path, S.vp, S.vel, S.ori, ...
        psi_ref, theta_ref, dt, t);
    s = pm.s_prog(:);
    s_total = pm.s_total;
    W = compute_pitch_window_metrics(t, e_th, s, s_total, 'mode', win_mode);

    mask_acq = W.mask_acq;
    mask_ss = W.mask_steady;
    if ~any(mask_ss)
        % Fallback steady: t>=5 & before end
        mask_ss = (t >= 5.0) & W.mask_before_end;
    end

    M = struct();
    M.win_mode = win_mode;
    M.is_xz = is_xz;
    M.settling_s = W.settling_s;
    M.W = W;
    M.plant_mode = plant_mode;

    % Pitch capsule check numbers
    M.pitch = struct();
    M.pitch.acq = W.acq;
    M.pitch.steady = W.steady;
    M.pitch.elev_sat_pct = sat_pct(de, mask_ss, 0.98 * de_max);

    % Yaw wrapped
    M.yaw = struct();
    M.yaw.acq = err_stats(e_psi, mask_acq);
    M.yaw.steady = err_stats(e_psi, mask_ss);
    M.yaw.full = err_stats(e_psi, true(size(e_psi)));

    % Roll phi (ref=0) and p
    M.phi = struct();
    M.phi.acq = signed_stats(phi, mask_acq);      % signed phi about 0
    M.phi.steady = signed_stats(phi, mask_ss);
    M.phi.e_acq = err_stats(e_phi, mask_acq);     % MAE of |0-phi|
    M.phi.e_steady = err_stats(e_phi, mask_ss);

    M.p = struct();
    M.p.acq = signed_stats(p, mask_acq);
    M.p.steady = signed_stats(p, mask_ss);
    M.p.e_acq = err_stats(p, mask_acq);   % |p| MAE/RMS about 0
    M.p.e_steady = err_stats(p, mask_ss);

    % Rudder
    dr_dot = [0; diff(dr)] / dt;
    M.rudder = struct();
    M.rudder.acq = actuator_stats(dr, dr_dot, mask_acq, dr_max);
    M.rudder.steady = actuator_stats(dr, dr_dot, mask_ss, dr_max);
    M.rudder.full = actuator_stats(dr, dr_dot, true(size(dr)), dr_max);

    % Spectral peak + damping proxy (steady)
    M.spec = spectral_roll(phi, p, mask_ss, dt, plant_mode);

    % Correlations / phase (steady)
    M.coup = coupling_stats(phi, p, dr, r, mask_ss, dt);

    % Transient vs steady energy ratio
    if any(mask_acq) && any(mask_ss)
        M.phi_rms_acq_over_ss = rms_local(phi(mask_acq)) / max(rms_local(phi(mask_ss)), eps);
        M.p_rms_acq_over_ss = rms_local(p(mask_acq)) / max(rms_local(p(mask_ss)), eps);
    else
        M.phi_rms_acq_over_ss = NaN;
        M.p_rms_acq_over_ss = NaN;
    end

    % Store series pointers for PNG
    M.series = struct('t', t, 'phi', phi, 'phi_ref', phi_ref, 'p', p, ...
        'dr', dr, 'e_psi', e_psi, 'r', r, 'mask_acq', mask_acq, 'mask_ss', mask_ss);
end

function M = attach_helix_yaw(M, S, path, R, dr_max)
    t = S.t(:);
    dt = S.dt;
    psi = S.ori(:, 3);
    psi_ref = S.psi_ref(:);
    e_psi = wrapToPi(psi_ref - psi);
    r = S.rates(:, 3);
    dr = S.delta_r(:);
    W = M.W;
    mask_yaw = (t >= 5.0) & W.mask_before_end;
    if ~any(mask_yaw); mask_yaw = t >= 5.0; end
    mask_acq_rud = W.mask_acq;
    if ~any(mask_acq_rud) && ~isnan(W.settling_s)
        mask_acq_rud = t < W.settling_s;
    end
    sat_thr = 0.95 * dr_max;
    M.yaw.mae_deg = rad2deg(mean(abs(e_psi(mask_yaw))));
    M.yaw.rms_deg = rad2deg(rms_local(e_psi(mask_yaw)));
    M.yaw.p95_deg = rad2deg(prctile_local(abs(e_psi(mask_yaw)), 95));
    M.yaw.rudder_sat_acq_pct = sat_pct(dr, mask_acq_rud, sat_thr);
    M.yaw.rudder_sat_ss_pct = sat_pct(dr, mask_yaw, sat_thr);
    M.yaw.rudder_sat_full_pct = sat_pct(dr, true(size(dr)), sat_thr);
    Uh_k = S.U_h_guid .* S.kappa;
    valid_ratio = mask_yaw & (abs(S.kappa) > 1e-4) & (abs(S.U_h_guid) > 0.3);
    if any(valid_ratio)
        mean_r = mean(r(valid_ratio));
        mean_Uh_k = mean(Uh_k(valid_ratio));
        if mean_Uh_k < 0; mean_Uh_k = -mean_Uh_k; mean_r = -mean_r; end
        M.yaw.ratio_r_Uh_kappa = mean_r / max(abs(mean_Uh_k), 1e-9);
    else
        M.yaw.ratio_r_Uh_kappa = NaN;
    end
    M.yaw.mask_yaw = mask_yaw;
    M.helix_R = R;
    M.path = path;
end

function st = signed_stats(x, mask)
    st = struct('signed_mean', NaN, 'mae', NaN, 'rms', NaN, 'p95', NaN, 'max', NaN, 'n', 0);
    if ~any(mask); return; end
    v = x(mask);
    st.n = numel(v);
    st.signed_mean = mean(v);
    st.mae = mean(abs(v));
    st.rms = rms_local(v);
    st.p95 = prctile_local(abs(v), 95);
    st.max = max(abs(v));
end

function st = err_stats(e, mask)
    % e in rad → report deg
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

function st = actuator_stats(u, udot, mask, umax)
    st = struct('rms_deg', NaN, 'rate_rms_dps', NaN, 'sat_pct', NaN, 'n', 0);
    if ~any(mask); return; end
    v = u(mask); vd = udot(mask);
    st.n = numel(v);
    st.rms_deg = rad2deg(rms_local(v));
    st.rate_rms_dps = rad2deg(rms_local(vd));
    st.sat_pct = 100 * mean(abs(v) >= 0.95 * umax);
end

function sp = spectral_roll(phi, p, mask, dt, plant_mode)
    sp = struct('phi_f_Hz', NaN, 'p_f_Hz', NaN, 'phi_peak', NaN, 'p_peak', NaN, ...
        'damp_proxy_phi', NaN, 'damp_proxy_p', NaN, ...
        'df_vs_plant_Hz', NaN, 'match_plant', false);
    if sum(mask) < 64; return; end
    [f_phi, P_phi] = onesided_psd(phi(mask), dt);
    [f_p, P_p] = onesided_psd(p(mask), dt);
    % Exclude near-DC (<0.05 Hz)
    ikeep = f_phi > 0.05;
    if ~any(ikeep); return; end
    [sp.phi_peak, i1] = max(P_phi(ikeep));
    ff = f_phi(ikeep); sp.phi_f_Hz = ff(i1);
    ikeep2 = f_p > 0.05;
    [sp.p_peak, i2] = max(P_p(ikeep2));
    ff2 = f_p(ikeep2); sp.p_f_Hz = ff2(i2);

    % Damping proxy: Hilbert envelope decay rate / (2*pi*f) ≈ zeta (rough)
    sp.damp_proxy_phi = damp_proxy_hilbert(phi(mask), dt, sp.phi_f_Hz);
    sp.damp_proxy_p = damp_proxy_hilbert(p(mask), dt, sp.p_f_Hz);

    sp.df_vs_plant_Hz = abs(sp.p_f_Hz - plant_mode.f_Hz);
    sp.match_plant = sp.df_vs_plant_Hz < 0.15 * max(plant_mode.f_Hz, 0.1);
    sp.plant_f_Hz = plant_mode.f_Hz;
    sp.plant_zeta = plant_mode.zeta;
end

function [f, P] = onesided_psd(x, dt)
    x = x(:) - mean(x);
    N = numel(x);
    Nfft = 2^nextpow2(N);
    X = fft(x, Nfft);
    P2 = abs(X / N).^2;
    half = floor(Nfft / 2) + 1;
    P = P2(1:half);
    if half > 2
        P(2:end-1) = 2 * P(2:end-1);
    end
    f = (0:half-1)' / (Nfft * dt);
end

function z = damp_proxy_hilbert(x, dt, f0)
    z = NaN;
    x = x(:) - mean(x);
    if numel(x) < 64 || ~(f0 > 0); return; end
    try
        env = abs(hilbert(x));
    catch
        % Fallback without Signal Processing Toolbox
        X = fft(x);
        n = numel(x);
        h = zeros(n, 1);
        if mod(n, 2) == 0
            h([1 n/2+1]) = 1; h(2:n/2) = 2;
        else
            h(1) = 1; h(2:(n+1)/2) = 2;
        end
        env = abs(ifft(X .* h));
    end
    env = env(:);
    % Fit log(env) = a - sigma*t over middle 60%
    n = numel(env);
    i0 = max(1, round(0.2 * n));
    i1 = min(n, round(0.8 * n));
    tt = ((i0:i1)' - 1) * dt;
    ee = env(i0:i1);
    ee = max(ee, max(ee) * 1e-6);
    pfit = polyfit(tt, log(ee), 1);
    sigma = -pfit(1);  % decay rate [1/s]
    wn = 2 * pi * f0;
    z = sigma / max(wn, eps);
    z = max(min(z, 2), -0.5);  % clamp nonsense
end

function c = coupling_stats(phi, p, dr, r, mask, dt)
    c = struct();
    if sum(mask) < 32
        c.corr_phi_dr = NaN; c.corr_p_dr = NaN;
        c.corr_phi_r = NaN; c.corr_p_r = NaN;
        c.phase_phi_dr_deg = NaN; c.phase_p_dr_deg = NaN;
        c.phase_phi_r_deg = NaN; c.phase_p_r_deg = NaN;
        c.lag_phi_dr_s = NaN; c.lag_p_dr_s = NaN;
        return;
    end
    ph = phi(mask); pp = p(mask); d = dr(mask); rr = r(mask);
    c.corr_phi_dr = corr_local(ph, d);
    c.corr_p_dr = corr_local(pp, d);
    c.corr_phi_r = corr_local(ph, rr);
    c.corr_p_r = corr_local(pp, rr);
    [c.lag_phi_dr_s, c.phase_phi_dr_deg] = lag_phase(ph, d, dt);
    [c.lag_p_dr_s, c.phase_p_dr_deg] = lag_phase(pp, d, dt);
    [c.lag_phi_r_s, c.phase_phi_r_deg] = lag_phase(ph, rr, dt);
    [c.lag_p_r_s, c.phase_p_r_deg] = lag_phase(pp, rr, dt);
end

function [lag_s, phase_deg] = lag_phase(a, b, dt)
    a = a(:) - mean(a); b = b(:) - mean(b);
    n = numel(a);
    maxlag = min(round(2.0 / dt), floor(n / 4));
    [xc, lags] = xcorr(a, b, maxlag, 'coeff');
    [~, im] = max(abs(xc));
    lag_s = lags(im) * dt;
    % Phase at dominant mutual frequency via FFT cross-spectrum
    Nfft = 2^nextpow2(n);
    A = fft(a, Nfft); B = fft(b, Nfft);
    Cxy = A .* conj(B);
    P = abs(Cxy);
    half = floor(Nfft / 2) + 1;
    f = (0:half-1)' / (Nfft * dt);
    Pk = P(1:half);
    ikeep = f > 0.05;
    if ~any(ikeep)
        phase_deg = NaN; return;
    end
    [~, ii] = max(Pk(ikeep));
    ff = f(ikeep);
    f0 = ff(ii);
    idx = find(abs(f - f0) < 1e-12, 1);
    if isempty(idx); idx = find(ikeep); idx = idx(ii); end
    phase_deg = rad2deg(angle(Cxy(idx)));
end

%% ===================== gates / classify =====================
function py = pitch_yaw_preserve(MX, MXZ, MH, capX, capXZ, capH)
    py = struct();
    % Allow 5% vs capsule for diagnostic re-sim numerical drift; gate "preserved"
    tol = 0.05;
    py.X_mae = MX.pitch.steady.mae_deg;
    py.X_ok = ~isnan(py.X_mae) && py.X_mae <= capX.mae_deg * (1 + tol) + 1e-4;
    py.XZ_mae = MXZ.pitch.steady.mae_deg;
    py.XZ_ok = ~isnan(py.XZ_mae) && py.XZ_mae <= capXZ.mae_deg * (1 + tol) + 1e-4;
    py.H_pitch = MH.pitch.steady.mae_deg;
    py.H_pitch_ok = ~isnan(py.H_pitch) && py.H_pitch <= capH.pitch_mae * (1 + tol) + 1e-4;
    if isfield(MH.yaw, 'mae_deg')
        py.H_yaw = MH.yaw.mae_deg;
    else
        py.H_yaw = MH.yaw.steady.mae_deg;
    end
    py.H_yaw_ok = ~isnan(py.H_yaw) && py.H_yaw <= capH.yaw_mae * (1 + tol) + 1e-4;
    py.ok = py.X_ok && py.XZ_ok && py.H_pitch_ok && py.H_yaw_ok;
    py.capX = capX; py.capXZ = capXZ; py.capH = capH;
end

function G = roll_gates(MX, MXZ, MH, py)
    routes = {MX, MXZ, MH};
    names = {'X', 'XZ', 'H'};
    G = struct();
    G.pref = struct(); G.hard = struct();
    hard_ok = true; pref_ok = true;
    for i = 1:3
        M = routes{i}; nm = names{i};
        mae = rad2deg(M.phi.steady.mae);   % MAE of |phi|
        p95 = rad2deg(M.phi.steady.p95);
        mx  = rad2deg(M.phi.steady.max);
        sat = M.rudder.steady.sat_pct;
        if isnan(sat); sat = M.rudder.full.sat_pct; end
        G.pref.(nm) = struct('mae_ok', mae <= 0.5, 'p95_ok', p95 <= 1.0, ...
            'mae', mae, 'p95', p95, 'max', mx, 'sat', sat);
        G.hard.(nm) = struct('mae_ok', mae <= 1.0, 'p95_ok', p95 <= 2.0, ...
            'max_ok', mx <= 5.0, 'sat_ok', sat <= 1.0, ...
            'mae', mae, 'p95', p95, 'max', mx, 'sat', sat);
        pref_ok = pref_ok && G.pref.(nm).mae_ok && G.pref.(nm).p95_ok;
        hard_ok = hard_ok && G.hard.(nm).mae_ok && G.hard.(nm).p95_ok && ...
            G.hard.(nm).max_ok && G.hard.(nm).sat_ok;
    end
    G.py_ok = py.ok;
    G.pref_pass = pref_ok;
    G.hard_pass = hard_ok && py.ok;
end

function [root, next_opt, detail] = classify_root(MX, MXZ, MH, plant, gates)
    % Separate: transient_init | plant_natural_roll | yaw_command_coupling | metric_artifact | UNKNOWN
    routes = {MX, MXZ, MH};
    names = {'X', 'XZ', 'H'};

    plant_match_n = 0;
    yaw_corr_strong = 0;
    transient_dom = 0;
    fail_routes = {};
    for i = 1:3
        M = routes{i}; nm = names{i};
        h = gates.hard.(nm);
        if ~(h.mae_ok && h.p95_ok && h.max_ok && h.sat_ok)
            fail_routes{end+1} = nm; %#ok<AGROW>
        end
        if isfield(M.spec, 'match_plant') && M.spec.match_plant
            plant_match_n = plant_match_n + 1;
        end
        c = M.coup;
        corr_max = max(abs([c.corr_phi_dr, c.corr_p_dr, c.corr_phi_r, c.corr_p_r]));
        if ~isnan(corr_max) && corr_max >= 0.45
            yaw_corr_strong = yaw_corr_strong + 1;
        end
        if ~isnan(M.phi_rms_acq_over_ss) && M.phi_rms_acq_over_ss > 3.0 && ...
                rad2deg(M.phi.steady.mae) < 0.5
            transient_dom = transient_dom + 1;
        end
    end

    helix_fail = any(strcmp(fail_routes, 'H'));
    straight_fail = any(strcmp(fail_routes, 'X')) || any(strcmp(fail_routes, 'XZ'));
    straight_quiet = (gates.hard.X.mae < 0.05) && (gates.hard.XZ.mae < 0.05);

    % Steady bank vs ripple on helix (trim HELIX φ*≈0.02518 rad ≈ 1.443°)
    phi_mean_deg = rad2deg(MH.phi.steady.signed_mean);
    phi_mae_deg = rad2deg(MH.phi.steady.mae);
    phi_rms_deg = rad2deg(MH.phi.steady.rms);
    ac_rms = sqrt(max(phi_rms_deg^2 - phi_mean_deg^2, 0));
    bank_dominated = helix_fail && (abs(phi_mean_deg) > 0.8) && ...
        (abs(phi_mae_deg - abs(phi_mean_deg)) < 0.15 * max(abs(phi_mean_deg), 1e-3));

    any_nan = any(isnan([gates.hard.X.mae, gates.hard.XZ.mae, gates.hard.H.mae]));
    if any_nan
        root = 'metric_artifact';
        next_opt = 'UNKNOWN';
        detail = 'NaN roll metrics — evidence insufficient / window artifact; UNKNOWN next.';
        return;
    end

    if transient_dom >= 2 && ~straight_fail && ~helix_fail
        root = 'transient_initialization';
        next_opt = 'rudder_cross_damping_p_phi';
        detail = 'Acquisition |phi|/|p| >> steady; steady within preferred — init transient; optional light rudder cross-damping on p/phi.';
        return;
    end

    % Helix-only fail, straight silent: yaw/curvature induces bank (+ optional plant-mode ripple)
    if helix_fail && ~straight_fail && straight_quiet
        root = 'yaw_command_induced_coupling';
        sat_bad = gates.hard.H.sat > 1.0;
        if sat_bad
            next_opt = 'physical_authority_envelope';
            detail = sprintf(['Helix-only roll FAIL (ss MAE=%.3f°); X/XZ φ≈0. Yaw/helix induces ', ...
                'roll with rudder saturation → physical authority/envelope.'], phi_mae_deg);
        elseif bank_dominated && ac_rms < 1.0
            % Mean bank ≈ MAE (matches HELIX trim φ*); ripple secondary → need lateral φ regulation
            next_opt = 'scheduled_lateral_LQR_benchmark';
            detail = sprintf(['Helix-only FAIL: steady φ mean≈MAE=%.3f° (≈HELIX trim bank φ*≈1.44°); ', ...
                'AC rms≈%.3f° at plant roll f=%.3f Hz (match=%d, ζ_proxy=%.4f). X/XZ φ≡0 (no yaw). ', ...
                'Root: yaw-command-induced coupling (quasi-steady bank + light plant-mode ripple). ', ...
                'Cross-damping alone will not remove mean bank. Next: scheduled lateral LQR benchmark ', ...
                'on [y φ ψ v p r] (not implement now).'], ...
                phi_mae_deg, ac_rms, MH.spec.p_f_Hz, MH.spec.match_plant, MH.spec.damp_proxy_p);
        elseif MH.spec.match_plant || plant_match_n >= 1
            next_opt = 'rudder_cross_damping_p_phi';
            detail = sprintf(['Helix-only FAIL with spectral match to lightly-damped plant roll ', ...
                '(f=%.3f vs plant %.3f Hz). Next: rudder cross-damping using p/φ.'], ...
                MH.spec.p_f_Hz, plant.level.f_Hz);
        else
            next_opt = 'scheduled_lateral_LQR_benchmark';
            detail = 'Helix-only yaw-induced roll FAIL; next: scheduled lateral LQR benchmark.';
        end
        return;
    end

    if plant_match_n >= 2 && yaw_corr_strong == 0 && straight_fail
        root = 'plant_natural_roll';
        next_opt = 'rudder_cross_damping_p_phi';
        detail = sprintf(['Steady spectral peak matches lightly-damped plant roll ', ...
            '(level f~%.3fHz zeta~%.4f); weak yaw/rudder corr → plant natural mode. ', ...
            'Next: rudder cross-damping using p/phi (bounded; no gain sweep).'], ...
            plant.level.f_Hz, plant.level.zeta);
        return;
    end

    if yaw_corr_strong >= 1 || (helix_fail && straight_fail)
        root = 'yaw_command_induced_coupling';
        sat_bad = gates.hard.H.sat > 1.0 || gates.hard.X.sat > 1.0 || gates.hard.XZ.sat > 1.0;
        mae_big = max([gates.hard.X.mae, gates.hard.XZ.mae, gates.hard.H.mae]) > 2.0;
        if sat_bad || mae_big
            next_opt = 'physical_authority_envelope';
            detail = 'Roll tracks rudder/yaw-rate with sat or large MAE → physical authority/envelope review.';
        elseif straight_fail && helix_fail
            next_opt = 'scheduled_lateral_LQR_benchmark';
            detail = ['Yaw/rudder-coupled roll on straight+helix; lateral controllable but ', ...
                'cond~6.4e5, light roll damping. Next: scheduled lateral LQR benchmark.'];
        else
            next_opt = 'rudder_cross_damping_p_phi';
            detail = 'Yaw-command-induced roll coupling; next: rudder cross-damping on p/phi.';
        end
        return;
    end

    root = 'UNKNOWN';
    next_opt = 'scheduled_lateral_LQR_benchmark';
    detail = ['Evidence insufficient for a single root class. ', ...
        'Next bounded option: scheduled lateral LQR benchmark on validated [y phi psi v p r].'];
end

%% ===================== writers =====================
function write_png(png_path, SX, SXZ, SH, MX, MXZ, MH, dr_max, task_id, verdict)
    fig = figure('Visible', 'off', 'Color', 'w', 'Position', [50 50 1400 900]);
    routes = {SX, SXZ, SH};
    Ms = {MX, MXZ, MH};
    titles = {'X (level)', 'XZ (climb)', 'R10 helix'};
    lim_deg = rad2deg(dr_max);
    for col = 1:3
        S = routes{col}; M = Ms{col};
        t = S.t(:);
        phi = rad2deg(S.ori(:, 1));
        p = rad2deg(S.rates(:, 1));
        dr = rad2deg(S.delta_r(:));
        epsi = rad2deg(wrapToPi(S.psi_ref(:) - S.ori(:, 3)));

        subplot(4, 3, col);
        plot(t, zeros(size(t)), 'k--', 'LineWidth', 0.8); hold on;
        plot(t, phi, 'b', 'LineWidth', 1.0);
        ylabel('\phi [deg]'); title(sprintf('%s — %s', titles{col}, verdict));
        if col == 1; legend('\phi_{ref}=0', '\phi', 'Location', 'best'); end
        grid on;

        subplot(4, 3, col + 3);
        plot(t, p, 'r', 'LineWidth', 1.0);
        ylabel('p [deg/s]'); grid on;

        subplot(4, 3, col + 6);
        plot(t, dr, 'm', 'LineWidth', 1.0); hold on;
        yline(lim_deg, 'k--'); yline(-lim_deg, 'k--');
        ylabel('\delta_r [deg]'); grid on;
        if col == 1; legend('\delta_r', '\pm lim', 'Location', 'best'); end

        subplot(4, 3, col + 9);
        plot(t, epsi, 'Color', [0.1 0.5 0.2], 'LineWidth', 1.0);
        ylabel('e_\psi wrap [deg]'); xlabel('t [s]'); grid on;
        % Annotate steady MAE
        text(0.02, 0.92, sprintf('ss \\phi MAE=%.3f° p95=%.3f°', ...
            rad2deg(M.phi.steady.mae), rad2deg(M.phi.steady.p95)), ...
            'Units', 'normalized', 'FontSize', 8);
    end
    sgtitle(sprintf('%s — \\phi_{ref}/\\phi, p, rudder+limits, yaw error', task_id), ...
        'FontWeight', 'bold');
    exportgraphics(fig, png_path, 'Resolution', 150);
    close(fig);
end

function write_md(md_path, task_id, verdict, plant, inv, need_resim, MX, MXZ, MH, ...
        gates, py, root_class, next_opt, next_detail, k_gamma, seed_used, ...
        md_p, mat_p, png_p, closure_path, level_path, climb_path)
    fid = fopen(md_path, 'w');
    assert(fid > 0);
    fprintf(fid, '# %s — Roll baseline audit\n\n', task_id);
    fprintf(fid, '**Overall verdict: %s**\n\n', verdict);
    fprintf(fid, '## Provenance\n\n');
    fprintf(fid, '- Read-only: `%s`, `%s`, `%s`\n', closure_path, level_path, climb_path);
    fprintf(fid, '- Driver: `run_roll_baseline_audit.m` (one invocation; no controller/plant/guidance edit)\n');
    fprintf(fid, '- Diagnostic re-sim of accepted closure: **%s** (MAT lacked phi/p/rudder on X/XZ logs)\n', ...
        tern(need_resim, 'YES', 'NO'));
    fprintf(fid, '- Frozen stack: climb-FF k_gamma=%.10f; X λ=0.25; XZ λ=0; helix λ=0.25; seed=%d\n', ...
        k_gamma, seed_used);
    fprintf(fid, '- Artifacts: `%s`, `%s`, `%s`\n\n', md_p, mat_p, png_p);

    fprintf(fid, '## Units / frame\n\n');
    fprintf(fid, '- Frame: %s\n', plant.frame);
    fprintf(fid, '- phi [rad] Euler roll, p [rad/s] body roll rate, delta_r [rad]; reports in deg / deg/s\n');
    fprintf(fid, '- phi_ref = 0; e_phi = 0 - phi; e_psi = wrapToPi(psi_ref - psi)\n');
    fprintf(fid, '- Windows: X first_hold (pitch); XZ/helix persistent pitch; report acq + steady\n\n');

    fprintf(fid, '## Plant roll mode (LOCAL_SS)\n\n');
    fprintf(fid, '| Op | λ | f [Hz] | ζ | T [s] |\n');
    fprintf(fid, '|----|---|-------:|--:|------:|\n');
    fprintf(fid, '| Level | %.4e±j%.4f | %.4f | %.4f | %.3f |\n', ...
        real(plant.level.lam), imag(plant.level.lam), plant.level.f_Hz, ...
        plant.level.zeta, plant.level.T_s);
    fprintf(fid, '| Climb | %.4e±j%.4f | %.4f | %.4f | %.3f |\n\n', ...
        real(plant.climb.lam), imag(plant.climb.lam), plant.climb.f_Hz, ...
        plant.climb.zeta, plant.climb.T_s);
    fprintf(fid, 'Lateral controllable; cond(Qc_s)~6.4e5 (CTRL_OBS). Controller has **no** roll feedback (rudder = yaw PD only).\n\n');

    fprintf(fid, '## Closure channel inventory\n\n');
    fprintf(fid, '| Route | phi | p | delta_r | r | ok |\n');
    fprintf(fid, '|-------|:---:|:-:|:-------:|:-:|:--:|\n');
    fprintf(fid, '| X | %d | %d | %d | %d | %d |\n', ...
        inv.X.has_phi, inv.X.has_p, inv.X.has_dr, inv.X.has_r, inv.X.ok);
    fprintf(fid, '| XZ | %d | %d | %d | %d | %d |\n', ...
        inv.XZ.has_phi, inv.XZ.has_p, inv.XZ.has_dr, inv.XZ.has_r, inv.XZ.ok);
    fprintf(fid, '| H | %d | %d | %d | %d | %d |\n\n', ...
        inv.H.has_phi, inv.H.has_p, inv.H.has_dr, inv.H.has_r, inv.H.ok);

    fprintf(fid, '## Roll metrics (phi ref=0)\n\n');
    write_route_md(fid, 'X', MX);
    write_route_md(fid, 'XZ', MXZ);
    write_route_md(fid, 'R10 helix', MH);

    fprintf(fid, '## Pitch/yaw preservation vs capsule\n\n');
    fprintf(fid, '| Route | metric | value | capsule | ok |\n');
    fprintf(fid, '|-------|--------|------:|--------:|:--:|\n');
    fprintf(fid, '| X | pitch ss MAE [°] | %.4f | %.4f | %s |\n', ...
        py.X_mae, py.capX.mae_deg, tern(py.X_ok, 'YES', 'NO'));
    fprintf(fid, '| XZ | pitch ss MAE [°] | %.4f | %.4f | %s |\n', ...
        py.XZ_mae, py.capXZ.mae_deg, tern(py.XZ_ok, 'YES', 'NO'));
    fprintf(fid, '| H | pitch ss MAE [°] | %.4f | %.4f | %s |\n', ...
        py.H_pitch, py.capH.pitch_mae, tern(py.H_pitch_ok, 'YES', 'NO'));
    fprintf(fid, '| H | yaw wrap MAE [°] | %.4f | %.4f | %s |\n\n', ...
        py.H_yaw, py.capH.yaw_mae, tern(py.H_yaw_ok, 'YES', 'NO'));

    fprintf(fid, '## Gates\n\n');
    fprintf(fid, 'Preferred: ss φ MAE≤0.5°, p95≤1°. Hard: MAE≤1°, p95≤2°, max≤5°, rudder sat≤1%%, pitch/yaw preserved.\n\n');
    fprintf(fid, '| Route | MAE | p95 | max | sat%% | pref | hard |\n');
    fprintf(fid, '|-------|----:|----:|----:|-----:|:----:|:----:|\n');
    for nm = {'X', 'XZ', 'H'}
        n = nm{1};
        fprintf(fid, '| %s | %.4f | %.4f | %.4f | %.2f | %s | %s |\n', n, ...
            gates.hard.(n).mae, gates.hard.(n).p95, gates.hard.(n).max, gates.hard.(n).sat, ...
            tern(gates.pref.(n).mae_ok && gates.pref.(n).p95_ok, 'YES', 'NO'), ...
            tern(gates.hard.(n).mae_ok && gates.hard.(n).p95_ok && ...
                 gates.hard.(n).max_ok && gates.hard.(n).sat_ok, 'YES', 'NO'));
    end
    fprintf(fid, '\n- Preferred all routes: **%s**\n', tern(gates.pref_pass, 'PASS', 'FAIL'));
    fprintf(fid, '- Hard + pitch/yaw: **%s**\n\n', tern(gates.hard_pass, 'PASS', 'FAIL'));

    fprintf(fid, '## Root-cause class\n\n');
    fprintf(fid, '- **Class:** `%s`\n', root_class);
    fprintf(fid, '- **Next (one bounded option, not implemented):** `%s`\n', next_opt);
    fprintf(fid, '- Detail: %s\n\n', next_detail);

    fprintf(fid, '## Feedback\n\n');
    fprintf(fid, '- Verdict: **%s**\n', verdict);
    fprintf(fid, '- Key ss φ MAE [°]: X=%.4f, XZ=%.4f, H=%.4f\n', ...
        gates.hard.X.mae, gates.hard.XZ.mae, gates.hard.H.mae);
    fprintf(fid, '- Key ss φ p95 [°]: X=%.4f, XZ=%.4f, H=%.4f\n', ...
        gates.hard.X.p95, gates.hard.XZ.p95, gates.hard.H.p95);
    fprintf(fid, '- Root: %s | Next: %s\n', root_class, next_opt);
    fprintf(fid, '- Files: `%s` `%s` `%s`\n', md_p, mat_p, png_p);
    fclose(fid);
end

function write_route_md(fid, name, M)
    fprintf(fid, '### %s\n\n', name);
    fprintf(fid, 'Settle (pitch window)=%.2f s | win=%s\n\n', M.settling_s, M.win_mode);
    fprintf(fid, '| Window | φ signed_mean [°] | φ MAE | φ RMS | φ p95 | φ max | p MAE [°/s] | p RMS | p p95 | p max |\n');
    fprintf(fid, '|--------|------------------:|------:|------:|------:|------:|------------:|------:|------:|------:|\n');
    for w = {'acq', 'steady'}
        ww = w{1};
        ph = M.phi.(ww); pp = M.p.(ww);
        fprintf(fid, '| %s | %.4f | %.4f | %.4f | %.4f | %.4f | %.4f | %.4f | %.4f | %.4f |\n', ...
            ww, rad2deg(ph.signed_mean), rad2deg(ph.mae), rad2deg(ph.rms), ...
            rad2deg(ph.p95), rad2deg(ph.max), ...
            rad2deg(pp.mae), rad2deg(pp.rms), rad2deg(pp.p95), rad2deg(pp.max));
    end
    fprintf(fid, '\nRudder: acq RMS=%.3f° rateRMS=%.3f°/s sat=%.2f%% | ss RMS=%.3f° rateRMS=%.3f°/s sat=%.2f%%\n', ...
        M.rudder.acq.rms_deg, M.rudder.acq.rate_rms_dps, M.rudder.acq.sat_pct, ...
        M.rudder.steady.rms_deg, M.rudder.steady.rate_rms_dps, M.rudder.steady.sat_pct);
    if isfield(M.yaw, 'mae_deg')
        fprintf(fid, 'Yaw wrap (helix SBE): MAE=%.4f RMS=%.4f p95=%.4f | rud sat acq/ss/full=%.2f/%.2f/%.2f%% | ratio=%.4f\n', ...
            M.yaw.mae_deg, M.yaw.rms_deg, M.yaw.p95_deg, ...
            M.yaw.rudder_sat_acq_pct, M.yaw.rudder_sat_ss_pct, M.yaw.rudder_sat_full_pct, ...
            M.yaw.ratio_r_Uh_kappa);
    else
        fprintf(fid, 'Yaw wrap ss: MAE=%.4f RMS=%.4f p95=%.4f max=%.4f\n', ...
            M.yaw.steady.mae_deg, M.yaw.steady.rms_deg, M.yaw.steady.p95_deg, M.yaw.steady.max_deg);
    end
    fprintf(fid, 'Spectrum ss: φ peak f=%.3f Hz | p peak f=%.3f Hz | damp_proxy φ/p=%.4f/%.4f | vs plant Δf=%.3f Hz match=%d\n', ...
        M.spec.phi_f_Hz, M.spec.p_f_Hz, M.spec.damp_proxy_phi, M.spec.damp_proxy_p, ...
        M.spec.df_vs_plant_Hz, M.spec.match_plant);
    c = M.coup;
    fprintf(fid, 'Coupling ss: corr(φ,dr)=%.3f corr(p,dr)=%.3f corr(φ,r)=%.3f corr(p,r)=%.3f\n', ...
        c.corr_phi_dr, c.corr_p_dr, c.corr_phi_r, c.corr_p_r);
    fprintf(fid, 'Phase/lag: φ↔dr %.1f° / %.3fs | p↔dr %.1f° / %.3fs | φ↔r %.1f° | p↔r %.1f°\n', ...
        c.phase_phi_dr_deg, c.lag_phi_dr_s, c.phase_p_dr_deg, c.lag_p_dr_s, ...
        c.phase_phi_r_deg, c.phase_p_r_deg);
    fprintf(fid, 'Transient ratio RMS_acq/RMS_ss: φ=%.2f p=%.2f\n\n', ...
        M.phi_rms_acq_over_ss, M.p_rms_acq_over_ss);
end

function append_ss_audit(out_dir, task_id, verdict, plant, MX, MXZ, MH, gates, ...
        root_class, next_opt, next_detail, md_path, mat_path, png_path, need_resim)
    audit_path = fullfile(out_dir, 'STATE_SPACE_MODEL_AUDIT.md');
    fid = fopen(audit_path, 'a');
    assert(fid > 0);
    fprintf(fid, '\n\n---\n\n');
    fprintf(fid, '## %s — %s\n\n', task_id, datestr(now, 31));
    fprintf(fid, '### Provenance\n\n');
    fprintf(fid, '- Closure: `suite_results/pitch_yaw_closure.mat` (PITCH_YAW PASS)\n');
    fprintf(fid, '- Models: `LOCAL_SS_LEVEL.mat`, `LOCAL_SS_CLIMB.mat` (lateral COP/dr validated)\n');
    fprintf(fid, '- Driver: `run_roll_baseline_audit.m` (read-only; diagnostic resim=%s)\n', ...
        tern(need_resim, 'YES', 'NO'));
    fprintf(fid, '- Artifacts: `%s`, `%s`, `%s`\n\n', md_path, mat_path, png_path);

    fprintf(fid, '### Math / frame / units\n\n');
    fprintf(fid, '```\n');
    fprintf(fid, 'State: η=[x y z φ θ ψ], ν=[u v w p q r]; inputs [δr δe Xprop]\n');
    fprintf(fid, 'Roll ref: φ_ref = 0; e_φ = 0 - φ; p body roll rate\n');
    fprintf(fid, 'Plant roll (level): λ = %.6e ± j%.6f → f=%.4f Hz, ζ=%.5f\n', ...
        real(plant.level.lam), imag(plant.level.lam), plant.level.f_Hz, plant.level.zeta);
    fprintf(fid, 'Plant roll (climb): λ = %.6e ± j%.6f → f=%.4f Hz, ζ=%.5f\n', ...
        real(plant.climb.lam), imag(plant.climb.lam), plant.climb.f_Hz, plant.climb.zeta);
    fprintf(fid, 'Lateral reduced: [y φ ψ v p r] w/ δr; cond(Qc_s)~6.4e5; controllable\n');
    fprintf(fid, 'Production rudder: δr = sat(Kp_ψ e_ψ - Kd_ψ e_r)  (no φ/p feedback)\n');
    fprintf(fid, 'Windows: X first_hold pitch; XZ/helix persistent pitch; φ metrics on same masks\n');
    fprintf(fid, '```\n\n');

    fprintf(fid, '### Roll baseline (steady φ)\n\n');
    fprintf(fid, '| Route | MAE [°] | p95 [°] | max [°] | rud sat%% | p peak f [Hz] | plant match |\n');
    fprintf(fid, '|-------|--------:|--------:|--------:|---------:|--------------:|:-----------:|\n');
    fprintf(fid, '| X | %.4f | %.4f | %.4f | %.2f | %.3f | %d |\n', ...
        gates.hard.X.mae, gates.hard.X.p95, gates.hard.X.max, gates.hard.X.sat, ...
        MX.spec.p_f_Hz, MX.spec.match_plant);
    fprintf(fid, '| XZ | %.4f | %.4f | %.4f | %.2f | %.3f | %d |\n', ...
        gates.hard.XZ.mae, gates.hard.XZ.p95, gates.hard.XZ.max, gates.hard.XZ.sat, ...
        MXZ.spec.p_f_Hz, MXZ.spec.match_plant);
    fprintf(fid, '| H | %.4f | %.4f | %.4f | %.2f | %.3f | %d |\n\n', ...
        gates.hard.H.mae, gates.hard.H.p95, gates.hard.H.max, gates.hard.H.sat, ...
        MH.spec.p_f_Hz, MH.spec.match_plant);

    fprintf(fid, '### Verdict / root / next\n\n');
    fprintf(fid, '- Verdict: **%s**\n', verdict);
    fprintf(fid, '- Root class: `%s`\n', root_class);
    fprintf(fid, '- Next (not implemented): `%s` — %s\n', next_opt, next_detail);
    fprintf(fid, '- Preferred gates: %s | Hard gates: %s\n\n', ...
        tern(gates.pref_pass, 'PASS', 'FAIL'), tern(gates.hard_pass, 'PASS', 'FAIL'));
    fprintf(fid, '### Next\n\n');
    if strcmp(verdict, 'PASS')
        fprintf(fid, '- Freeze roll baseline; no controller change.\n');
    else
        fprintf(fid, '- Do not implement now; queue single option `%s`.\n', next_opt);
    end
    fclose(fid);
end

function print_feedback(verdict, MX, MXZ, MH, gates, root_class, next_opt, next_detail, ...
        md_path, mat_path, png_path)
    fprintf('\n----- FEEDBACK -----\n');
    fprintf('PASS/FAIL: %s\n', verdict);
    fprintf('ss phi MAE[deg]: X=%.4f XZ=%.4f H=%.4f\n', ...
        gates.hard.X.mae, gates.hard.XZ.mae, gates.hard.H.mae);
    fprintf('ss phi p95[deg]: X=%.4f XZ=%.4f H=%.4f\n', ...
        gates.hard.X.p95, gates.hard.XZ.p95, gates.hard.H.p95);
    fprintf('ss phi max[deg]: X=%.4f XZ=%.4f H=%.4f\n', ...
        gates.hard.X.max, gates.hard.XZ.max, gates.hard.H.max);
    fprintf('rud sat%% ss: X=%.2f XZ=%.2f H=%.2f\n', ...
        gates.hard.X.sat, gates.hard.XZ.sat, gates.hard.H.sat);
    fprintf('spec p f[Hz]: X=%.3f XZ=%.3f H=%.3f (plant level %.3f)\n', ...
        MX.spec.p_f_Hz, MXZ.spec.p_f_Hz, MH.spec.p_f_Hz, MX.spec.plant_f_Hz);
    fprintf('root_class: %s\n', root_class);
    fprintf('next: %s\n', next_opt);
    fprintf('detail: %s\n', next_detail);
    fprintf('files:\n  %s\n  %s\n  %s\n', md_path, mat_path, png_path);
end

%% ===================== helpers =====================
function S = series_from_closure_straight(~)
    error('roll_baseline:NoStraightChannels', ...
        'Closure straight logs lack phi/p/dr; diagnostic resim required.');
end

function S = series_from_closure_helix(SH)
    S = SH;
end

function y = sat_pct(u, mask, thr)
    if ~any(mask); y = NaN; return; end
    y = 100 * mean(abs(u(mask)) >= thr);
end

function r = rms_local(x)
    x = x(:);
    r = sqrt(mean(x.^2));
end

function v = prctile_local(x, p)
    x = sort(x(:));
    n = numel(x);
    if n == 0; v = NaN; return; end
    k = max(1, min(n, round(p / 100 * n)));
    v = x(k);
end

function c = corr_local(a, b)
    a = a(:); b = b(:);
    a = a - mean(a); b = b - mean(b);
    den = rms_local(a) * rms_local(b) * numel(a);
    if den < eps; c = NaN; return; end
    c = sum(a .* b) / (rms_local(a) * rms_local(b) * numel(a)) * numel(a);
    % standard Pearson
    sa = std(a); sb = std(b);
    if sa < eps || sb < eps; c = NaN; return; end
    c = mean(a .* b) / (sa * sb);
end

function s = tern(c, a, b)
    if c; s = a; else; s = b; end
end
