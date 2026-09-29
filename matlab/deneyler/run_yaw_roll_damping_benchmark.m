function run_yaw_roll_damping_benchmark()
% YAW_ROLL_DAMPING_BENCHMARK_001 — one coordinated yaw-roll p-damping candidate.
% Read-only: ROLL_TRIM_RELATIVE_AUDIT.mat, LOCAL_SS_LEVEL.mat, LOCAL_SS_CLIMB.mat.
% Isolated driver only; production controller_law / guidance / plant untouched.
% One MATLAB invocation. Artifacts: suite_results/YAW_ROLL_DAMPING_BENCHMARK.{md,mat,png}

    project_dir = fileparts(fileparts(fileparts(mfilename('fullpath')))); % repo root
    addpath(genpath(fullfile(project_dir, 'matlab')));
    out_dir = fullfile(project_dir, 'suite_results');
    if ~exist(out_dir, 'dir'); mkdir(out_dir); end
    tag = 'YAW_ROLL_DAMPING_BENCHMARK';
    task_id = 'YAW_ROLL_DAMPING_BENCHMARK_001';

    trim_path  = fullfile(out_dir, 'ROLL_TRIM_RELATIVE_AUDIT.mat');
    level_path = fullfile(out_dir, 'LOCAL_SS_LEVEL.mat');
    climb_path = fullfile(out_dir, 'LOCAL_SS_CLIMB.mat');
    assert(exist(trim_path, 'file') == 2, 'Missing %s', trim_path);
    assert(exist(level_path, 'file') == 2, 'Missing %s', level_path);
    assert(exist(climb_path, 'file') == 2, 'Missing %s', climb_path);

    Trim = load(trim_path);
    Lss  = load(level_path);
    Css  = load(climb_path);

    fprintf('\n========== %s ==========\n', task_id);
    fprintf('Sources: ROLL_TRIM_RELATIVE_AUDIT / LOCAL_SS_LEVEL / LOCAL_SS_CLIMB\n');
    fprintf('Mode: isolated diag controller; production stack untouched\n');

    % ---- Derive ONE gain (modal Newton zeta target; not a sweep) ----
    zdes = 0.12;
    law = derive_p_damping_law(Lss, Css, zdes);
    fprintf('Law: dr = dr_yaw - Kp*p  (Kphi=0); sign from Bp>0\n');
    fprintf('Kp=%.6f s | zdes=%.2f | level z: %.5f->%.5f | climb z: %.5f->%.5f\n', ...
        law.Kp, zdes, law.level.z_open, law.level.z_cl, law.climb.z_open, law.climb.z_cl);

    phi_eq = struct();
    phi_eq.X = 0.0;
    phi_eq.XZ = 0.0;
    phi_eq.H = Trim.H.phi_eq_rad;   % empirical 1.461 deg; do NOT force bank to 0
    fprintf('phi_eq [deg]: X=0, XZ=0, H=%.4f (%s)\n', ...
        rad2deg(phi_eq.H), Trim.H.phi_eq_label);

    % ---- Frozen production stack (match accepted closure / roll audits) ----
    clear functions
    clear guidance_law controller_law
    clear global lambda_muw_ff trim_speed_table trim_elevator_table elevator_sign
    clear global K_zdot K_gamma enable_alpha_hat
    clear global last_guidance_U_h last_guidance_kappa last_r_ff
    clear global suite_diag_dr

    init_parameters();
    global lambda_muw_ff elevator_sign trim_speed_table trim_elevator_table
    global K_zdot K_gamma enable_alpha_hat
    global dt_controller delta_e_max delta_r_max Kp_psi Kd_psi

    elevator_sign = 1;
    trim_speed_table = [0.8 1.0 1.5 2.0];
    trim_elevator_table = deg2rad([-9.18 -7.33 -4.62 -3.17]);
    K_gamma = 0; K_zdot = 0; enable_alpha_hat = false;
    seed_used = 0;
    rng(seed_used, 'twister');

    % Paths (same geometry as accepted X / XZ / R10)
    nX = 600; xX = linspace(0, 45, nX)';
    pathX = [xX, zeros(nX, 1), zeros(nX, 1)];
    nXZ = 900; xXZ = linspace(0, 42, nXZ)';
    pathXZ = [xXZ, zeros(nXZ, 1), 0.4 * xXZ];
    pathH = generate_balanced_helical_path(10.0, 2.0, 2, 500);

    lim = struct('dr_max', delta_r_max, 'de_max', delta_e_max, ...
        'dr_rate', deg2rad(40), 'near_frac', 0.80);

    % Pitch absolute gates (preserved)
    pitch_gate = struct('X_mae', 0.10, 'XZ_mae', 0.30, ...
        'H_mae', 0.30, 'H_p95', 0.50, 'elev_sat', 1.0);

    % ---- Baseline (Kp=0) then candidate (derived Kp) ----
    cfg0 = law; cfg0.Kp = 0; cfg0.enable = false;
    cfg1 = law; cfg1.enable = true;

    fprintf('\n-- Baseline (no roll damp) --\n');
    B0 = run_suite(pathX, pathXZ, pathH, cfg0, phi_eq, lim, 0.25, 0.0);

    fprintf('\n-- Candidate (p-damping Kp=%.4f) --\n', cfg1.Kp);
    B1 = run_suite(pathX, pathXZ, pathH, cfg1, phi_eq, lim, 0.25, 0.0);

    % ---- Score ----
    [verdict, G, next_opt, next_detail] = score_benchmark(B0, B1, pitch_gate, lim);

    md_path  = fullfile(out_dir, [tag '.md']);
    mat_path = fullfile(out_dir, [tag '.mat']);
    png_path = fullfile(out_dir, [tag '.png']);

    write_png(png_path, B0, B1, phi_eq, task_id, verdict, law);
    write_md(md_path, task_id, verdict, law, phi_eq, Trim, B0, B1, G, ...
        pitch_gate, lim, next_opt, next_detail, seed_used, ...
        md_path, mat_path, png_path, trim_path, level_path, climb_path);
    append_ss_audit(out_dir, task_id, verdict, law, phi_eq, B0, B1, G, ...
        next_opt, next_detail, md_path, mat_path, png_path);

    S = struct();
    S.task_id = task_id;
    S.verdict = verdict;
    S.law = law;
    S.phi_eq = phi_eq;
    S.baseline = B0;
    S.candidate = B1;
    S.gates = G;
    S.next_opt = next_opt;
    S.next_detail = next_detail;
    S.pitch_gate = pitch_gate;
    S.limits = lim;
    S.seed_used = seed_used;
    S.Kp_psi = Kp_psi; S.Kd_psi = Kd_psi;
    S.sources = {trim_path; level_path; climb_path};
    S.paths = struct('md', md_path, 'mat', mat_path, 'png', png_path);
    S.note = ['Isolated yaw-roll p-damping benchmark about phi_eq; ', ...
        'one derived gain; production untouched; reject if gates fail'];
    save(mat_path, '-struct', 'S');

    fprintf('\nVERDICT: %s | next=%s\n', verdict, next_opt);
    fprintf('Saved: %s\n%s\n%s\n', md_path, mat_path, png_path);
    print_feedback(verdict, law, B0, B1, G, next_opt, next_detail, ...
        md_path, mat_path, png_path);
    assignin('base', 'YAW_ROLL_DAMPING_BENCHMARK_PASS', strcmp(verdict, 'PASS'));

    % Cleanup temp derive helper if present
    tmp1 = fullfile(project_dir, 'derive_roll_damp_gain.m');
    tmp2 = fullfile(project_dir, '_tmp_derive_roll_damp_gain.m');
    if exist(tmp1, 'file'); delete(tmp1); end
    if exist(tmp2, 'file'); delete(tmp2); end
end

%% ===================== gain derivation =====================
function law = derive_p_damping_law(Lss, Css, zdes)
    [Kl, Ll] = newton_Kp_for_zeta(Lss.A_lateral, Lss.B_lateral(:), zdes);
    [Kc, Lc] = newton_Kp_for_zeta(Css.A_lateral, Css.B_lateral(:), zdes);
    % Sign from B: Bp>0 => dr = -Kp*p with Kp>0 damps roll mode
    assert(Lss.B_lateral(5) > 0 && Css.B_lateral(5) > 0, 'Bp expected >0');
    Kp = max(Kl, Kc);  % robust: both models reach >= zdes
    law = struct();
    law.equation = 'dr_cmd = sat( dr_yaw + g_ac*( -Kp*p + Kphi*(phi-phi_eq) ) ); Kphi=0';
    law.Kp = Kp;
    law.Kphi = 0;
    law.zdes = zdes;
    law.sign_rule = 'Bp=d(p_dot)/d(dr)>0 => dr_damp=-Kp*p (Kp>0)';
    law.Bp_level = Lss.B_lateral(5);
    law.Bp_climb = Css.B_lateral(5);
    law.Br_level = Lss.B_lateral(6);
    law.Br_climb = Css.B_lateral(6);
    law.level = Ll; law.level.Kp_alone = Kl;
    law.climb = Lc; law.climb.Kp_alone = Kc;
    % Closed-loop poles at robust Kp
    law.level = augment_cl(law.level, Lss.A_lateral, Lss.B_lateral(:), Kp);
    law.climb = augment_cl(law.climb, Css.A_lateral, Css.B_lateral(:), Kp);
    law.anti_conflict = struct('e_psi0_deg', 3.0, 'e_r0_dps', 8.0, ...
        'note', 'g_ac=1/(1+(|e_psi|/e0)^2+(|e_r|/r0)^2); damp attenuated when yaw active');
end

function M = augment_cl(M, A, B, Kp)
    [lam0, ~, ~] = roll_mode_evec(A);
    Krow = [0 0 0 0 Kp 0];
    [lamc, ~, ~] = roll_mode_evec(A - B(:) * Krow);
    M.lam_open = lam0;
    M.lam_cl = lamc;
    M.z_open = -real(lam0) / abs(lam0);
    M.z_cl = -real(lamc) / abs(lamc);
    M.f_open = imag(lam0) / (2 * pi);
    M.f_cl = imag(lamc) / (2 * pi);
end

function [Kp, meta] = newton_Kp_for_zeta(A, B, zdes)
    B = B(:);
    Kp = 0;
    [lamk, ~, ~] = roll_mode_evec(A);
    epsK = 1e-4;
    for iter = 1:6
        [lam_eps, ~, ~] = roll_mode_evec(A - B * [0 0 0 0 (Kp + epsK) 0]);
        dlam = (lam_eps - lamk) / epsK;
        re = real(lamk); im = imag(lamk); wn = abs(lamk);
        z = -re / wn;
        dre = real(dlam); dim = imag(dlam);
        dz = (-dre * wn + re * (re * dre + im * dim) / wn) / (wn^2);
        Kp = Kp + (zdes - z) / max(dz, 1e-9);
        [lamk, ~, ~] = roll_mode_evec(A - B * [0 0 0 0 Kp 0]);
    end
    [lam0, ~, ~] = roll_mode_evec(A);
    meta = struct();
    meta.lam_open = lam0;
    meta.z_open = -real(lam0) / abs(lam0);
    meta.f_open = imag(lam0) / (2 * pi);
    meta.lam_cl = lamk;
    meta.z_cl = -real(lamk) / abs(lamk);
    meta.f_cl = imag(lamk) / (2 * pi);
    meta.newton_iters = 6;
end

function [lam, v, w] = roll_mode_evec(A)
    [V, D] = eig(A);
    d = diag(D);
    wn = abs(d); zeta = -real(d) ./ max(wn, eps);
    osc = (imag(d) > 0.5) & (abs(real(d)) < 3.0);
    if ~any(osc); osc = imag(d) > 0.5; end
    cand = find(osc);
    [~, ii] = min(zeta(cand));
    lam = d(cand(ii));
    if imag(lam) < 0; lam = conj(lam); end
    [~, iv] = min(abs(d - lam));
    v = V(:, iv);
    [Wt, Dt] = eig(A.');
    dt = diag(Dt);
    [~, iw] = min(abs(dt - conj(lam)));
    w = Wt(:, iw);
    w = w / (w' * v);
end

%% ===================== suite sims =====================
function B = run_suite(pathX, pathXZ, pathH, cfg, phi_eq, lim, lamX, lamXZ)
    global lambda_muw_ff
    rng(0, 'twister');
    lambda_muw_ff = lamX;
    SX = sim_route(pathX, 18, 1.5, cfg, lim, false, 0);
    MX = analyze_route(SX, pathX, 'first_hold', phi_eq.X, lim, false);

    rng(0, 'twister');
    lambda_muw_ff = lamXZ;
    SXZ = sim_route(pathXZ, 22, 1.5, cfg, lim, false, 0);
    MXZ = analyze_route(SXZ, pathXZ, 'persistent', phi_eq.XZ, lim, true);

    rng(0, 'twister');
    lambda_muw_ff = 0.25;
    SH = sim_route(pathH, 45, 1.5, cfg, lim, true, 10.0);
    MH = analyze_route(SH, pathH, 'persistent', phi_eq.H, lim, false);
    MH = attach_helix_yaw(MH, SH, lim.dr_max);

    B = struct('X', MX, 'XZ', MXZ, 'H', MH, 'SX', SX, 'SXZ', SXZ, 'SH', SH, 'cfg', cfg);
    fprintf('  X  tildeMAE=%.4f pRMS=%.4f yawMAE=%.4f pitchMAE=%.4f\n', ...
        MX.tilde.mae_deg, MX.p.rms_dps, MX.yaw.mae_deg, MX.pitch.mae_deg);
    fprintf('  XZ tildeMAE=%.4f pRMS=%.4f yawMAE=%.4f pitchMAE=%.4f\n', ...
        MXZ.tilde.mae_deg, MXZ.p.rms_dps, MXZ.yaw.mae_deg, MXZ.pitch.mae_deg);
    fprintf('  H  tildeMAE=%.4f tildeRMS=%.4f pRMS=%.4f yawMAE=%.4f pitchMAE=%.4f\n', ...
        MH.tilde.mae_deg, MH.tilde.rms_deg, MH.p.rms_dps, MH.yaw.mae_deg, MH.pitch.mae_deg);
end

function S = sim_route(path, T_final, u0, cfg, lim, is_helix, R)
    global dt_controller dt_guidance
    global last_guidance_U_h last_guidance_kappa last_r_ff
    global last_delta_e last_de_fb

    clear guidance_law controller_law
    % Reset diagnostic rudder persistents via clear of nested? use local state below
    last_guidance_U_h = []; last_guidance_kappa = []; last_r_ff = [];
    last_delta_e = []; last_de_fb = [];

    dt = dt_controller;
    if isempty(dt_guidance); dt_guidance = dt; end
    n_steps = round(T_final / dt);
    guidance_period = max(1, round(dt_guidance / dt));

    state = zeros(12, 1);
    state(1:3) = path(1, :)';
    d = path(2, :) - path(1, :);
    state(5) = -atan2(d(3), norm(d(1:2)));
    state(6) = atan2(d(2), d(1));
    state(7) = u0;

    yaw_ref = 0; pitch_ref = 0; u_ref = u0; r_ff = 0; pitch_ref_dot = 0; pidx = 1;
    prev_dr = 0;

    S = struct();
    S.dt = dt; S.T_final = T_final; S.u0 = u0; S.is_helix = is_helix; S.R = R;
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
    S.dr_yaw = zeros(n_steps, 1);
    S.dr_p = zeros(n_steps, 1);
    S.dr_phi = zeros(n_steps, 1);
    S.dr_damp = zeros(n_steps, 1);
    S.g_ac = zeros(n_steps, 1);
    S.dr_cmd = zeros(n_steps, 1);
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

        % Production pitch/thrust (discard its rudder — rebuilt below with damp)
        [~, de, thr] = controller_law(yaw_ref, pitch_ref, u_ref, ...
            ori(3), ori(2), rates(3), rates(2), u, r_ff, pitch_ref_dot, ori(1), w);

        [dr, comp, prev_dr] = diag_rudder(yaw_ref, ori(3), rates(3), r_ff, ...
            rates(1), ori(1), cfg, lim, prev_dr, dt);

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
        S.dr_yaw(k) = comp.dr_yaw;
        S.dr_p(k) = comp.dr_p;
        S.dr_phi(k) = comp.dr_phi;
        S.dr_damp(k) = comp.dr_damp;
        S.g_ac(k) = comp.g_ac;
        S.dr_cmd(k) = comp.dr_cmd;
        S.U_h(k) = Uh;
        if isempty(last_guidance_U_h); last_guidance_U_h = Uh; end
        if isempty(last_guidance_kappa)
            if is_helix && R > 0; last_guidance_kappa = 1 / R; else; last_guidance_kappa = 0; end
        end
        if isempty(last_r_ff); last_r_ff = r_ff; end
        S.U_h_guid(k) = last_guidance_U_h;
        S.kappa(k) = last_guidance_kappa;
        S.r_ff(k) = last_r_ff;
    end
end

function [dr, C, prev_dr] = diag_rudder(yaw_ref, psi, r, r_ff, p, phi, cfg, lim, prev_dr, dt)
    global Kp_psi Kd_psi
    e_psi = wrapToPi(yaw_ref - psi);
    e_r = r - r_ff;
    dr_yaw = Kp_psi * e_psi - Kd_psi * e_r;

    % Prefer p cross-damping; phi-phi_eq only if Kphi!=0 (here 0)
    if cfg.enable
        dr_p = -cfg.Kp * p;
        dr_phi = cfg.Kphi * 0;  % Kphi=0: do not force turn bank to zero
    else
        dr_p = 0; dr_phi = 0;
    end

    % Anti-conflict with yaw error/rate
    e_psi0 = deg2rad(cfg.anti_conflict.e_psi0_deg);
    e_r0 = deg2rad(cfg.anti_conflict.e_r0_dps);
    g_ac = 1 / (1 + (e_psi / max(e_psi0, eps))^2 + (e_r / max(e_r0, eps))^2);
    dr_damp = g_ac * (dr_p + dr_phi);

    % Sum BEFORE magnitude / rate limiter (mirrors production order)
    dr_unsat = dr_yaw + dr_damp;
    dr_cmd = max(min(dr_unsat, lim.dr_max), -lim.dr_max);
    max_dr = lim.dr_rate * dt;
    dr = prev_dr + max(min(dr_cmd - prev_dr, max_dr), -max_dr);
    prev_dr = dr;

    C = struct('dr_yaw', dr_yaw, 'dr_p', dr_p, 'dr_phi', dr_phi, ...
        'dr_damp', dr_damp, 'g_ac', g_ac, 'dr_cmd', dr_cmd, 'e_psi', e_psi, 'e_r', e_r);
end

function [Uh, zdot] = inertial_Uh_zdot(ori, u, v, w)
    phi = ori(1); theta = ori(2); psi = ori(3);
    Rm = [cos(psi)*cos(theta), ...
         cos(psi)*sin(theta)*sin(phi) - sin(psi)*cos(phi), ...
         cos(psi)*sin(theta)*cos(phi) + sin(psi)*sin(phi);
         sin(psi)*cos(theta), ...
         sin(psi)*sin(theta)*sin(phi) + cos(psi)*cos(phi), ...
         sin(psi)*sin(theta)*cos(phi) - cos(psi)*sin(phi);
         -sin(theta), cos(theta)*sin(phi), cos(theta)*cos(phi)];
    pos_dot = Rm * [u; v; w];
    Uh = hypot(pos_dot(1), pos_dot(2));
    zdot = pos_dot(3);
end

%% ===================== analyze =====================
function M = analyze_route(S, path, win_mode, phi_eq, lim, is_xz)
    t = S.t(:); dt = S.dt;
    phi = S.ori(:, 1);
    theta_phys = -S.ori(:, 2);
    psi = S.ori(:, 3);
    p = S.rates(:, 1);
    r = S.rates(:, 3);
    dr = S.delta_r(:);
    de = S.delta_e(:);
    psi_ref = S.psi_ref(:);
    theta_ref = S.theta_ref(:);
    e_psi = wrapToPi(psi_ref - psi);
    e_th = theta_ref - theta_phys;
    tilde = phi - phi_eq;

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

    M = struct();
    M.win_mode = win_mode; M.is_xz = is_xz;
    M.phi_eq_rad = phi_eq; M.phi_eq_deg = rad2deg(phi_eq);
    M.W = W; M.mask_ss = mask_ss; M.mask_yaw = mask_yaw;
    M.pitch = err_stats(e_th, mask_ss);
    M.pitch.elev_sat_pct = sat_pct(de, mask_ss, 0.98 * lim.de_max);
    M.pitch.mae_deg = M.pitch.mae_deg; % alias
    M.yaw = err_stats(e_psi, mask_yaw);
    M.tilde = err_stats(tilde, mask_ss);
    M.phi = err_stats(phi, mask_ss);
    M.p = err_stats(p, mask_ss);
    M.p.rms_dps = M.p.rms_deg;  % p already rate; err_stats used rad2deg
    % Fix p: rates should be reported as deg/s via rad2deg — err_stats does that
    dr_dot = [0; diff(dr)] / dt;
    M.rudder = actuator_stats(dr, dr_dot, mask_ss, lim.dr_max, lim.near_frac);
    M.rudder_yawwin = actuator_stats(dr, dr_dot, mask_yaw, lim.dr_max, lim.near_frac);
    M.comp = struct();
    M.comp.dr_yaw_rms_deg = rad2deg(rms_local(S.dr_yaw(mask_ss)));
    M.comp.dr_p_rms_deg = rad2deg(rms_local(S.dr_p(mask_ss)));
    M.comp.dr_phi_rms_deg = rad2deg(rms_local(S.dr_phi(mask_ss)));
    M.comp.dr_damp_rms_deg = rad2deg(rms_local(S.dr_damp(mask_ss)));
    M.comp.g_ac_mean = mean(S.g_ac(mask_ss));
    M.series = struct('t', t, 'phi', phi, 'tilde', tilde, 'p', p, ...
        'e_psi', e_psi, 'dr', dr, 'dr_yaw', S.dr_yaw(:), 'dr_p', S.dr_p(:), ...
        'dr_phi', S.dr_phi(:), 'dr_damp', S.dr_damp(:), 'g_ac', S.g_ac(:), ...
        'mask_ss', mask_ss, 'mask_yaw', mask_yaw);
end

function M = attach_helix_yaw(M, S, dr_max)
    t = S.t(:);
    e_psi = wrapToPi(S.psi_ref(:) - S.ori(:, 3));
    mask_yaw = M.mask_yaw;
    M.yaw = err_stats(e_psi, mask_yaw);
    M.yaw.rudder_sat_ss_pct = sat_pct(S.delta_r(:), mask_yaw, 0.95 * dr_max);
    M.yaw.rudder_sat_full_pct = sat_pct(S.delta_r(:), true(size(S.delta_r(:))), 0.95 * dr_max);
end

function st = err_stats(e, mask)
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

%% ===================== gates =====================
function [verdict, G, next_opt, next_detail] = score_benchmark(B0, B1, pitch_gate, lim) %#ok<INUSD>
    G = struct();
    % R10 preferred improvement: tilde RMS or p_RMS >=10%
    t0 = B0.H.tilde.rms_deg; t1 = B1.H.tilde.rms_deg;
    p0 = B0.H.p.rms_dps;     p1 = B1.H.p.rms_dps;
    G.H.tilde_rms_base = t0; G.H.tilde_rms_cand = t1;
    G.H.p_rms_base = p0; G.H.p_rms_cand = p1;
    G.H.d_tilde_rms_pct = 100 * (t1 - t0) / max(t0, 1e-9);
    G.H.d_p_rms_pct = 100 * (p1 - p0) / max(p0, 1e-9);
    G.H.improve_tilde = (t0 - t1) / max(t0, 1e-9) >= 0.10;
    G.H.improve_p = (p0 - p1) / max(p0, 1e-9) >= 0.10;
    G.H.roll_improve = G.H.improve_tilde || G.H.improve_p;

    % Yaw regression <=2% each of MAE/RMS/p95
    G.H.yaw = regress_gate(B0.H.yaw, B1.H.yaw, 0.02);

    % Pitch gates preserved (absolute + vs baseline <=2%)
    G.X.pitch_abs = B1.X.pitch.mae_deg <= pitch_gate.X_mae;
    G.XZ.pitch_abs = B1.XZ.pitch.mae_deg <= pitch_gate.XZ_mae;
    G.H.pitch_abs = (B1.H.pitch.mae_deg <= pitch_gate.H_mae) && ...
        (B1.H.pitch.p95_deg <= pitch_gate.H_p95) && ...
        (B1.H.pitch.elev_sat_pct <= pitch_gate.elev_sat);
    G.X.pitch_reg = regress_ok(B0.X.pitch.mae_deg, B1.X.pitch.mae_deg, 0.02);
    G.XZ.pitch_reg = regress_ok(B0.XZ.pitch.mae_deg, B1.XZ.pitch.mae_deg, 0.02);
    G.H.pitch_reg = regress_ok(B0.H.pitch.mae_deg, B1.H.pitch.mae_deg, 0.02) && ...
        regress_ok(B0.H.pitch.p95_deg, B1.H.pitch.p95_deg, 0.02);
    G.pitch_ok = G.X.pitch_abs && G.XZ.pitch_abs && G.H.pitch_abs && ...
        G.X.pitch_reg && G.XZ.pitch_reg && G.H.pitch_reg;

    % Actuator: rate RMS / near / sat must not worsen (R10 yaw window)
    a0 = B0.H.rudder_yawwin; a1 = B1.H.rudder_yawwin;
    G.H.act.rate_ok = ~(a1.rate_rms_dps > a0.rate_rms_dps * 1.001 + 1e-9);
    G.H.act.near_ok = ~(a1.near_pct > a0.near_pct + 1e-9);
    G.H.act.sat_ok  = ~(a1.sat_pct  > a0.sat_pct  + 1e-9);
    G.H.act.ok = G.H.act.rate_ok && G.H.act.near_ok && G.H.act.sat_ok;
    G.H.act.base = a0; G.H.act.cand = a1;

    % X/XZ remain clean
    G.X.clean = (B1.X.tilde.mae_deg <= 0.05) && (B1.X.p.rms_dps <= 0.5);
    G.XZ.clean = (B1.XZ.tilde.mae_deg <= 0.05) && (B1.XZ.p.rms_dps <= 0.5);
    G.straight_clean = G.X.clean && G.XZ.clean;

    G.pass = G.H.roll_improve && G.H.yaw.ok && G.pitch_ok && G.H.act.ok && G.straight_clean;

    if G.pass
        verdict = 'PASS';
        next_opt = 'promote_candidate_review';
        next_detail = sprintf(['Candidate PASS: R10 roll improved (d_tildeRMS=%+.1f%%, ', ...
            'd_pRMS=%+.1f%%); yaw/pitch/actuator gates held; X/XZ clean. ', ...
            'Review for optional production promotion (not applied).'], ...
            G.H.d_tilde_rms_pct, G.H.d_p_rms_pct);
    else
        verdict = 'FAIL';
        next_opt = 'reject_revert_diagnostic';
        reasons = {};
        if ~G.H.roll_improve; reasons{end+1} = 'R10 roll improve<10%'; end %#ok<*AGROW>
        if ~G.H.yaw.ok; reasons{end+1} = 'yaw regress>2%'; end
        if ~G.pitch_ok; reasons{end+1} = 'pitch gate fail'; end
        if ~G.H.act.ok; reasons{end+1} = 'actuator worsen'; end
        if ~G.straight_clean; reasons{end+1} = 'X/XZ not clean'; end
        next_detail = ['REJECT diagnostic candidate; production untouched. Reasons: ', ...
            strjoin(reasons, '; '), '.'];
    end
end

function g = regress_gate(b, c, tol)
    g = struct();
    g.d_mae_pct = pct_regress(b.mae_deg, c.mae_deg);
    g.d_rms_pct = pct_regress(b.rms_deg, c.rms_deg);
    g.d_p95_pct = pct_regress(b.p95_deg, c.p95_deg);
    g.ok = (g.d_mae_pct <= 100 * tol) && (g.d_rms_pct <= 100 * tol) && ...
        (g.d_p95_pct <= 100 * tol);
end

function ok = regress_ok(b, c, tol)
    ok = pct_regress(b, c) <= 100 * tol;
end

function p = pct_regress(b, c)
    % Positive => candidate worse
    if ~(isfinite(b) && isfinite(c)); p = Inf; return; end
    p = 100 * (c - b) / max(abs(b), 1e-9);
end

%% ===================== writers =====================
function write_png(png_path, B0, B1, phi_eq, task_id, verdict, law)
    fig = figure('Visible', 'off', 'Position', [40 40 1400 900]);
    titles = {sprintf('R10 (phi_{eq}=%.3f^\\circ)', rad2deg(phi_eq.H)), ...
        'X (phi_{eq}=0)', 'XZ (phi_{eq}=0)'};
    S0s = {B0.SH, B0.SX, B0.SXZ};
    S1s = {B1.SH, B1.SX, B1.SXZ};
    M0s = {B0.H, B0.X, B0.XZ};
    M1s = {B1.H, B1.X, B1.XZ};
    for i = 1:3
        S0 = S0s{i}; S1 = S1s{i}; M0 = M0s{i}; M1 = M1s{i};

        t0 = S0.t; t1 = S1.t;
        peq = M0.phi_eq_deg;

        subplot(5, 3, i);
        plot(t0, rad2deg(S0.ori(:,1)), 'b-', t1, rad2deg(S1.ori(:,1)), 'r-', 'LineWidth', 0.9);
        hold on; yline(peq, 'k--', 'LineWidth', 1.0);
        title(titles{i}); ylabel('\phi [deg]'); grid on;
        if i == 1; legend('base','cand','\phi_{eq}', 'Location', 'best'); end

        subplot(5, 3, 3 + i);
        plot(t0, rad2deg(S0.ori(:,1) - M0.phi_eq_rad), 'b-', ...
             t1, rad2deg(S1.ori(:,1) - M1.phi_eq_rad), 'r-', 'LineWidth', 0.9);
        ylabel('$\tilde\phi$ [deg]', 'Interpreter', 'latex'); grid on;

        subplot(5, 3, 6 + i);
        plot(t0, rad2deg(S0.rates(:,1)), 'b-', t1, rad2deg(S1.rates(:,1)), 'r-', 'LineWidth', 0.9);
        ylabel('p [deg/s]'); grid on;

        subplot(5, 3, 9 + i);
        e0 = wrapToPi(S0.psi_ref - S0.ori(:,3));
        e1 = wrapToPi(S1.psi_ref - S1.ori(:,3));
        plot(t0, rad2deg(e0), 'b-', t1, rad2deg(e1), 'r-', 'LineWidth', 0.9);
        ylabel('e_\psi [deg]'); grid on;

        subplot(5, 3, 12 + i);
        plot(t1, rad2deg(S1.dr_yaw), 'k-', t1, rad2deg(S1.dr_p), 'm-', ...
             t1, rad2deg(S1.dr_damp), 'g-', t1, rad2deg(S1.delta_r), 'r-', 'LineWidth', 0.8);
        ylabel('\delta_r comps'); xlabel('t [s]'); grid on;
        if i == 1
            legend('yaw','p','damp_{ac}','applied', 'Location', 'best');
        end
    end
    sgtitle(sprintf('%s | %s | Kp=%.4f (Kphi=0)', task_id, verdict, law.Kp), ...
        'Interpreter', 'none');
    exportgraphics(fig, png_path, 'Resolution', 140);
    close(fig);
end

function write_md(md_path, task_id, verdict, law, phi_eq, Trim, B0, B1, G, ...
        pitch_gate, lim, next_opt, next_detail, seed_used, ...
        md_p, mat_p, png_p, trim_p, level_p, climb_p)
    fid = fopen(md_path, 'w');
    fprintf(fid, '# %s — Coordinated yaw-roll p-damping benchmark\n\n', task_id);
    fprintf(fid, '**Overall verdict: %s**\n\n', verdict);
    fprintf(fid, '## Provenance\n\n');
    fprintf(fid, '- Read-only: `%s`, `%s`, `%s`\n', trim_p, level_p, climb_p);
    fprintf(fid, '- Driver: `run_yaw_roll_damping_benchmark.m` (one invocation; production untouched)\n');
    fprintf(fid, '- Artifacts: `%s`, `%s`, `%s`\n', md_p, mat_p, png_p);
    fprintf(fid, '- Seed: %d | rudder limits +/-%.0f deg, %.0f deg/s\n\n', ...
        seed_used, rad2deg(lim.dr_max), rad2deg(lim.dr_rate));

    fprintf(fid, '## Law / gain / poles\n\n');
    fprintf(fid, '```\n%s\n', law.equation);
    fprintf(fid, 'Sign: %s | Bp_level=%.4f Bp_climb=%.4f\n', law.sign_rule, law.Bp_level, law.Bp_climb);
    fprintf(fid, 'Gain: Kp=%.6f s (ONE derived; zdes=%.2f; robust max(level,climb))\n', law.Kp, law.zdes);
    fprintf(fid, 'Kphi=0 (no bank-to-zero); phi_eq=0 straight, empirical %.4f deg on R10\n', rad2deg(phi_eq.H));
    fprintf(fid, 'Anti-conflict: g_ac=1/(1+(|e_psi|/ %.1fdeg)^2+(|e_r|/ %.1fdps)^2)\n', ...
        law.anti_conflict.e_psi0_deg, law.anti_conflict.e_r0_dps);
    fprintf(fid, 'Level poles: open f=%.4f Hz z=%.5f -> cl f=%.4f Hz z=%.5f\n', ...
        law.level.f_open, law.level.z_open, law.level.f_cl, law.level.z_cl);
    fprintf(fid, 'Climb poles: open f=%.4f Hz z=%.5f -> cl f=%.4f Hz z=%.5f\n', ...
        law.climb.f_open, law.climb.z_open, law.climb.f_cl, law.climb.z_cl);
    fprintf(fid, 'Per-model Newton K: level=%.6f climb=%.6f\n', ...
        law.level.Kp_alone, law.climb.Kp_alone);
    fprintf(fid, '```\n\n');

    fprintf(fid, '## phi_eq\n\n');
    fprintf(fid, '| Route | phi_eq [deg] | note |\n|-------|-------------:|------|\n');
    fprintf(fid, '| X | 0.0000 | forced_zero_straight |\n');
    fprintf(fid, '| XZ | 0.0000 | forced_zero_straight |\n');
    fprintf(fid, '| H | %.4f | %s (from ROLL_TRIM_RELATIVE_AUDIT) |\n\n', ...
        rad2deg(phi_eq.H), Trim.H.phi_eq_label);

    fprintf(fid, '## Before / after (steady)\n\n');
    fprintf(fid, '| Route | metric | base | cand | d%% |\n|-------|--------|-----:|-----:|---:|\n');
    dump_ba(fid, 'X', B0.X, B1.X);
    dump_ba(fid, 'XZ', B0.XZ, B1.XZ);
    dump_ba(fid, 'H', B0.H, B1.H);
    fprintf(fid, '\nR10 roll improve: tildeRMS d%%=%+.2f (need <=-10) | pRMS d%%=%+.2f (need <=-10) | pass=%s\n\n', ...
        G.H.d_tilde_rms_pct, G.H.d_p_rms_pct, yn(G.H.roll_improve));

    fprintf(fid, '## Gates\n\n');
    fprintf(fid, '| Gate | Result | Detail |\n|------|:------:|--------|\n');
    fprintf(fid, '| R10 tildeRMS or pRMS improve >=10%% | %s | d_tilde=%+.2f%% d_p=%+.2f%% |\n', ...
        yn(G.H.roll_improve), G.H.d_tilde_rms_pct, G.H.d_p_rms_pct);
    fprintf(fid, '| Yaw MAE/RMS/p95 regress <=2%% | %s | d%%=%.2f/%.2f/%.2f |\n', ...
        yn(G.H.yaw.ok), G.H.yaw.d_mae_pct, G.H.yaw.d_rms_pct, G.H.yaw.d_p95_pct);
    fprintf(fid, '| Pitch gates preserved | %s | abs X/XZ/H + reg<=2%% |\n', yn(G.pitch_ok));
    fprintf(fid, '| Rudder rate/near/sat not worsen | %s | rate %.3f->%.3f near %.2f->%.2f sat %.2f->%.2f |\n', ...
        yn(G.H.act.ok), G.H.act.base.rate_rms_dps, G.H.act.cand.rate_rms_dps, ...
        G.H.act.base.near_pct, G.H.act.cand.near_pct, ...
        G.H.act.base.sat_pct, G.H.act.cand.sat_pct);
    fprintf(fid, '| X/XZ remain clean | %s | |\n\n', yn(G.straight_clean));

    fprintf(fid, '## Decision\n\n');
    fprintf(fid, '- Verdict: **%s**\n', verdict);
    fprintf(fid, '- Next: `%s`\n', next_opt);
    fprintf(fid, '- Detail: %s\n\n', next_detail);

    fprintf(fid, '## Feedback\n\n');
    fprintf(fid, '- Verdict: **%s**\n', verdict);
    fprintf(fid, '- Equation/gain: dr=dr_yaw - %.6f*p (Kphi=0); poles level z %.5f->%.5f, climb %.5f->%.5f\n', ...
        law.Kp, law.level.z_open, law.level.z_cl, law.climb.z_open, law.climb.z_cl);
    fprintf(fid, '- R10 before/after: tildeRMS %.4f->%.4f (%+.2f%%); pRMS %.4f->%.4f (%+.2f%%)\n', ...
        G.H.tilde_rms_base, G.H.tilde_rms_cand, G.H.d_tilde_rms_pct, ...
        G.H.p_rms_base, G.H.p_rms_cand, G.H.d_p_rms_pct);
    fprintf(fid, '- Yaw d%% MAE/RMS/p95: %.2f / %.2f / %.2f | act ok=%s | X/XZ clean=%s\n', ...
        G.H.yaw.d_mae_pct, G.H.yaw.d_rms_pct, G.H.yaw.d_p95_pct, yn(G.H.act.ok), yn(G.straight_clean));
    fprintf(fid, '- Next: %s\n', next_opt);
    fprintf(fid, '- Files: `%s` `%s` `%s`\n', md_p, mat_p, png_p);
    fclose(fid);
end

function dump_ba(fid, nm, M0, M1)
    rows = { ...
        'tildeMAE', M0.tilde.mae_deg, M1.tilde.mae_deg; ...
        'tildeRMS', M0.tilde.rms_deg, M1.tilde.rms_deg; ...
        'pRMS', M0.p.rms_dps, M1.p.rms_dps; ...
        'yawMAE', M0.yaw.mae_deg, M1.yaw.mae_deg; ...
        'yawRMS', M0.yaw.rms_deg, M1.yaw.rms_deg; ...
        'yawP95', M0.yaw.p95_deg, M1.yaw.p95_deg; ...
        'pitchMAE', M0.pitch.mae_deg, M1.pitch.mae_deg};
    for i = 1:size(rows, 1)
        b = rows{i, 2}; c = rows{i, 3};
        fprintf(fid, '| %s | %s | %.4f | %.4f | %+.2f |\n', nm, rows{i, 1}, b, c, pct_regress(b, c));
    end
end

function append_ss_audit(out_dir, task_id, verdict, law, phi_eq, B0, B1, G, ...
        next_opt, next_detail, md_path, mat_path, png_path)
    audit = fullfile(out_dir, 'STATE_SPACE_MODEL_AUDIT.md');
    fid = fopen(audit, 'a');
    fprintf(fid, '\n\n---\n\n');
    fprintf(fid, '## %s — %s\n\n', task_id, datestr(now, 'yyyy-mm-dd HH:MM:SS'));
    fprintf(fid, '### Provenance\n\n');
    fprintf(fid, '- Read-only: `ROLL_TRIM_RELATIVE_AUDIT.mat`, `LOCAL_SS_LEVEL.mat`, `LOCAL_SS_CLIMB.mat`\n');
    fprintf(fid, '- Driver: `run_yaw_roll_damping_benchmark.m` (isolated; production untouched)\n');
    fprintf(fid, '- Artifacts: `%s`, `%s`, `%s`\n\n', md_path, mat_path, png_path);
    fprintf(fid, '### Law / poles\n\n');
    fprintf(fid, '```\ndr_cmd = sat_mag_rate( dr_yaw + g_ac*(-Kp*p) ); Kphi=0\n');
    fprintf(fid, 'Kp=%.6f s | zdes=%.2f | Bp_level=%.4f Bp_climb=%.4f\n', ...
        law.Kp, law.zdes, law.Bp_level, law.Bp_climb);
    fprintf(fid, 'Level: f %.4f->%.4f Hz, z %.5f->%.5f\n', ...
        law.level.f_open, law.level.f_cl, law.level.z_open, law.level.z_cl);
    fprintf(fid, 'Climb: f %.4f->%.4f Hz, z %.5f->%.5f\n', ...
        law.climb.f_open, law.climb.f_cl, law.climb.z_open, law.climb.z_cl);
    fprintf(fid, 'phi_eq: X=0 XZ=0 H=%.4f deg (empirical; not forced to 0)\n```\n\n', rad2deg(phi_eq.H));
    fprintf(fid, '### R10 before/after\n\n');
    fprintf(fid, '| metric | base | cand | d%% |\n|--------|-----:|-----:|---:|\n');
    fprintf(fid, '| tildeRMS [deg] | %.4f | %.4f | %+.2f |\n', G.H.tilde_rms_base, G.H.tilde_rms_cand, G.H.d_tilde_rms_pct);
    fprintf(fid, '| pRMS [deg/s] | %.4f | %.4f | %+.2f |\n', G.H.p_rms_base, G.H.p_rms_cand, G.H.d_p_rms_pct);
    fprintf(fid, '| yawMAE [deg] | %.4f | %.4f | %+.2f |\n\n', B0.H.yaw.mae_deg, B1.H.yaw.mae_deg, G.H.yaw.d_mae_pct);
    fprintf(fid, '### Verdict / next\n\n');
    fprintf(fid, '- Verdict: **%s**\n', verdict);
    fprintf(fid, '- Next: `%s` — %s\n', next_opt, next_detail);
    fprintf(fid, '- Production: untouched\n\n');
    fprintf(fid, '### Next\n\n');
    fprintf(fid, '- %s\n', next_opt);
    fclose(fid);
end

function print_feedback(verdict, law, B0, B1, G, next_opt, next_detail, md, mat, png)
    fprintf('\n---- FEEDBACK ----\n');
    fprintf('PASS/FAIL: %s\n', verdict);
    fprintf('Equation: dr = dr_yaw - %.6f*p (Kphi=0); g_ac anti-conflict\n', law.Kp);
    fprintf('Poles level z %.5f->%.5f (f %.3f->%.3f); climb %.5f->%.5f (f %.3f->%.3f)\n', ...
        law.level.z_open, law.level.z_cl, law.level.f_open, law.level.f_cl, ...
        law.climb.z_open, law.climb.z_cl, law.climb.f_open, law.climb.f_cl);
    fprintf('R10 tildeRMS %.4f->%.4f (%+.2f%%) | pRMS %.4f->%.4f (%+.2f%%)\n', ...
        G.H.tilde_rms_base, G.H.tilde_rms_cand, G.H.d_tilde_rms_pct, ...
        G.H.p_rms_base, G.H.p_rms_cand, G.H.d_p_rms_pct);
    fprintf('Yaw d%% MAE/RMS/p95: %.2f / %.2f / %.2f | act_ok=%d | XZclean=%d\n', ...
        G.H.yaw.d_mae_pct, G.H.yaw.d_rms_pct, G.H.yaw.d_p95_pct, G.H.act.ok, G.straight_clean);
    fprintf('Next: %s — %s\n', next_opt, next_detail);
    fprintf('Files: %s | %s | %s\n', md, mat, png);
end

%% ===================== helpers =====================
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

function s = yn(tf)
    if tf; s = 'YES'; else; s = 'NO'; end
end
