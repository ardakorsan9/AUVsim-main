function run_roll_production_closure()
% ROLL_PRODUCTION_CLOSURE_001 — reversible production roll-damp integration
% + two-repeat X / XZ / R10 nonlinear closure via actual controller_law.
% Sources (read-only): controller_law.m, continuous_path_tracking.m,
%   YAW_ROLL_DAMPING_BACKOFF.mat.
% One MATLAB invocation. Artifacts: suite_results/ROLL_PRODUCTION_CLOSURE.{md,mat,png}
% PASS -> promote/freeze roll. FAIL -> revert production edits from .roll_closure_bak.

    project_dir = fileparts(fileparts(fileparts(mfilename('fullpath')))); % repo root
    addpath(genpath(fullfile(project_dir, 'matlab')));
    out_dir = fullfile(project_dir, 'suite_results');
    if ~exist(out_dir, 'dir'); mkdir(out_dir); end
    tag = 'ROLL_PRODUCTION_CLOSURE';
    task_id = 'ROLL_PRODUCTION_CLOSURE_001';

    bak_dir = fullfile(project_dir, '.roll_closure_bak');
    ctrl_path = fullfile(project_dir, 'controller_law.m');
    cpt_path  = fullfile(project_dir, 'continuous_path_tracking.m');
    bak_ctrl  = fullfile(bak_dir, 'controller_law.m');
    bak_cpt   = fullfile(bak_dir, 'continuous_path_tracking.m');
    backoff_path = fullfile(out_dir, 'YAW_ROLL_DAMPING_BACKOFF.mat');

    assert(exist(backoff_path, 'file') == 2, 'Missing %s', backoff_path);
    assert(exist(bak_ctrl, 'file') == 2 && exist(bak_cpt, 'file') == 2, ...
        'Missing reversible backups in .roll_closure_bak');
    assert(exist(ctrl_path, 'file') == 2 && exist(cpt_path, 'file') == 2);

    Backoff = load(backoff_path);
    Kp_prod = Backoff.law.Kp;          % 0.605072 s (TUNED backoff PASS)
    assert(abs(Kp_prod - 0.605072) < 1e-5, 'BACKOFF Kp mismatch');
    assert(Backoff.law.Kphi == 0, 'Kphi must be 0');

    ctrl_txt = fileread(ctrl_path);
    assert(contains(ctrl_txt, 'dr_damp') && contains(ctrl_txt, 'Kp_roll'), ...
        'controller_law.m missing production roll-damp integration');
    cpt_txt = fileread(cpt_path);
    assert(contains(cpt_txt, 'current_rates(1)'), ...
        'continuous_path_tracking.m must pass BODY p=state(10)');

    fprintf('\n========== %s ==========\n', task_id);
    fprintf('Production integrate Kp_roll=%.6f s (Kphi=0) from BACKOFF PASS\n', Kp_prod);
    fprintf('Two-repeat X/XZ/R10 via actual controller_law + continuous_path_tracking\n');

    clear functions
    clear guidance_law controller_law
    clear global lambda_muw_ff trim_speed_table trim_elevator_table elevator_sign
    clear global K_zdot K_gamma enable_alpha_hat
    clear global last_guidance_U_h last_guidance_kappa last_r_ff
    clear global Kp_roll

    init_parameters();
    global lambda_muw_ff elevator_sign trim_speed_table trim_elevator_table
    global K_zdot K_gamma enable_alpha_hat
    global dt_controller delta_e_max delta_r_max Kp_psi Kd_psi Kp_roll

    elevator_sign = 1;
    trim_speed_table = [0.8 1.0 1.5 2.0];
    trim_elevator_table = deg2rad([-9.18 -7.33 -4.62 -3.17]);
    K_gamma = 0; K_zdot = 0; enable_alpha_hat = false;

    seed_used = 0;
    rng(seed_used, 'twister');

    phi_eq = struct('X', 0.0, 'XZ', 0.0, 'H', Backoff.phi_eq.H);
    lim = struct('dr_max', delta_r_max, 'de_max', delta_e_max, ...
        'dr_rate', deg2rad(40), 'near_frac', 0.80);
    pitch_gate = struct('X_mae', 0.10, 'XZ_mae', 0.30, ...
        'H_mae', 0.30, 'H_p95', 0.50, 'elev_sat', 1.0);

    nX = 600; xX = linspace(0, 45, nX)';
    pathX = [xX, zeros(nX, 1), zeros(nX, 1)];
    nXZ = 900; xXZ = linspace(0, 42, nXZ)';
    pathXZ = [xXZ, zeros(nXZ, 1), 0.4 * xXZ];
    pathH = generate_balanced_helical_path(10.0, 2.0, 2, 500);

    law = struct();
    law.equation = ['dr_cmd = sat_mag_rate( dr_yaw + g_ac*(-Kp_roll*p) ); ', ...
        'g_ac=1/(1+(|e_psi|/3deg)^2+(|e_r|/8dps)^2); Kphi=0'];
    law.old = 'dr_cmd = sat_mag_rate( Kp_psi*e_psi - Kd_psi*e_r )  [no roll damp]';
    law.new = sprintf('dr_cmd = sat_mag_rate( dr_yaw + g_ac*(-%.6f*p) )', Kp_prod);
    law.Kp = Kp_prod;
    law.Kphi = 0;
    law.provenance = 'YAW_ROLL_DAMPING_BACKOFF PASS (TUNED Kp2)';
    law.Kp_psi = Kp_psi;
    law.Kd_psi = Kd_psi;

    % ---- Baseline (Kp_roll=0) then production candidate (Kp_prod) ----
    fprintf('\n-- Baseline Kp_roll=0 (old yaw-PD) --\n');
    [B0, R0] = run_two_repeat_suite(pathX, pathXZ, pathH, 0.0, phi_eq, lim, seed_used);

    fprintf('\n-- Candidate Kp_roll=%.6f (production) --\n', Kp_prod);
    [B1, R1] = run_two_repeat_suite(pathX, pathXZ, pathH, Kp_prod, phi_eq, lim, seed_used);

    [verdict, G, next_opt, next_detail] = score_closure(B0, B1, R0, R1, pitch_gate, law);

    md_path  = fullfile(out_dir, [tag '.md']);
    mat_path = fullfile(out_dir, [tag '.mat']);
    png_path = fullfile(out_dir, [tag '.png']);

    write_png(png_path, B0, B1, phi_eq, lim, task_id, verdict, law);
    write_md(md_path, task_id, verdict, law, phi_eq, B0, B1, R0, R1, G, ...
        pitch_gate, lim, next_opt, next_detail, seed_used, ...
        md_path, mat_path, png_path, backoff_path, ctrl_path, cpt_path);
    append_ss_audit(out_dir, task_id, verdict, law, phi_eq, B0, B1, R0, R1, G, ...
        next_opt, next_detail, md_path, mat_path, png_path);

    S = struct();
    S.task_id = task_id;
    S.verdict = verdict;
    S.law = law;
    S.phi_eq = phi_eq;
    S.baseline = B0;
    S.candidate = B1;
    S.repeat_base = R0;
    S.repeat_cand = R1;
    S.gates = G;
    S.next_opt = next_opt;
    S.next_detail = next_detail;
    S.pitch_gate = pitch_gate;
    S.limits = lim;
    S.seed_used = seed_used;
    S.Kp_psi = Kp_psi; S.Kd_psi = Kd_psi; S.Kp_roll = Kp_prod;
    S.sources = {backoff_path; ctrl_path; cpt_path};
    S.paths = struct('md', md_path, 'mat', mat_path, 'png', png_path);
    S.changed_files = {'controller_law.m'; 'continuous_path_tracking.m'; ...
        'run_roll_production_closure.m'};
    S.note = 'Production roll-damp integration + two-repeat nonlinear closure';
    save(mat_path, '-struct', 'S');

    if strcmp(verdict, 'FAIL')
        fprintf('\nFAIL — reverting production edits from .roll_closure_bak\n');
        copyfile(bak_ctrl, ctrl_path);
        copyfile(bak_cpt, cpt_path);
        clear functions
        clear controller_law continuous_path_tracking
    else
        fprintf('\nPASS — roll damping PROMOTION FROZEN in production\n');
        % Keep backups for audit trail; production files remain integrated
    end

    fprintf('VERDICT: %s | next=%s\n', verdict, next_opt);
    fprintf('Saved: %s\n%s\n%s\n', md_path, mat_path, png_path);
    print_feedback(verdict, law, B0, B1, R0, R1, G, next_opt, next_detail, ...
        md_path, mat_path, png_path);
    assignin('base', 'ROLL_PRODUCTION_CLOSURE_PASS', strcmp(verdict, 'PASS'));
end

%% ===================== two-repeat suite =====================
function [B, R] = run_two_repeat_suite(pathX, pathXZ, pathH, Kp, phi_eq, lim, seed)
    global Kp_roll lambda_muw_ff
    MXr = cell(1, 2); MXZr = cell(1, 2); MHr = cell(1, 2);
    SXr = cell(1, 2); SXZr = cell(1, 2); SHr = cell(1, 2);

    for rep = 1:2
        fprintf('  rep%d (Kp_roll=%.6f)\n', rep, Kp);
        rng(seed, 'twister');
        Kp_roll = Kp;
        lambda_muw_ff = 0.25;
        [SXr{rep}, MXr{rep}] = sim_analyze(pathX, 18, 1.5, phi_eq.X, lim, ...
            'first_hold', false, 0);

        rng(seed, 'twister');
        Kp_roll = Kp;
        lambda_muw_ff = 0.0;
        [SXZr{rep}, MXZr{rep}] = sim_analyze(pathXZ, 22, 1.5, phi_eq.XZ, lim, ...
            'persistent', true, 0);

        rng(seed, 'twister');
        Kp_roll = Kp;
        lambda_muw_ff = 0.25;
        [SHr{rep}, MHr{rep}] = sim_analyze(pathH, 45, 1.5, phi_eq.H, lim, ...
            'persistent', false, 10.0);

        fprintf('    X  tildeMAE=%.4f pRMS=%.4f yawMAE=%.4f pitchMAE=%.4f cte=%.4f\n', ...
            MXr{rep}.tilde.mae_deg, MXr{rep}.p.rms_dps, MXr{rep}.yaw.mae_deg, ...
            MXr{rep}.pitch.mae_deg, MXr{rep}.path.mean_cte);
        fprintf('    XZ tildeMAE=%.4f pRMS=%.4f yawMAE=%.4f pitchMAE=%.4f cte=%.4f\n', ...
            MXZr{rep}.tilde.mae_deg, MXZr{rep}.p.rms_dps, MXZr{rep}.yaw.mae_deg, ...
            MXZr{rep}.pitch.mae_deg, MXZr{rep}.path.mean_cte);
        fprintf('    H  tildeRMS=%.4f pRMS=%.4f yawMAE=%.4f pitchMAE=%.4f cte=%.4f\n', ...
            MHr{rep}.tilde.rms_deg, MHr{rep}.p.rms_dps, MHr{rep}.yaw.mae_deg, ...
            MHr{rep}.pitch.mae_deg, MHr{rep}.path.mean_cte);
    end

    B = struct('X', MXr{1}, 'XZ', MXZr{1}, 'H', MHr{1}, ...
        'SX', SXr{1}, 'SXZ', SXZr{1}, 'SH', SHr{1}, 'Kp', Kp);
    R = struct();
    R.X  = repeat_check(MXr{1}, MXr{2});
    R.XZ = repeat_check(MXZr{1}, MXZr{2});
    R.H  = repeat_check(MHr{1}, MHr{2});
    R.pass = R.X.pass && R.XZ.pass && R.H.pass;
    R.seed = seed;
    R.n_rep = 2;
    fprintf('  determinism: X=%s XZ=%s H=%s\n', yn(R.X.pass), yn(R.XZ.pass), yn(R.H.pass));
end

function [S, M] = sim_analyze(path, T_final, u0, phi_eq, lim, win_mode, is_xz, R)
    global dt_controller
    global suite_delta_e_log suite_delta_r_log
    global suite_dr_yaw_log suite_dr_p_log suite_dr_damp_log suite_g_ac_log

    clear guidance_law controller_law
    % Reset controller persistent + guidance state for clean IC each case
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

    [vp, times, vel, rates, ori, ~, yaw_refs, pitch_refs, ~] = ...
        continuous_path_tracking(path, state0, dt, T_final);

    n = numel(times);
    S = struct();
    S.dt = dt; S.T_final = T_final; S.u0 = u0; S.R = R; S.is_xz = is_xz;
    S.t = times(:);
    S.vp = vp; S.vel = vel; S.rates = rates; S.ori = ori;
    S.psi_ref = yaw_refs(:); S.theta_ref = pitch_refs(:);
    S.delta_e = align_len(suite_delta_e_log(:), n);
    S.delta_r = align_len(suite_delta_r_log(:), n);
    S.dr_yaw = align_len(suite_dr_yaw_log(:), n);
    S.dr_p = align_len(suite_dr_p_log(:), n);
    S.dr_damp = align_len(suite_dr_damp_log(:), n);
    S.g_ac = align_len(suite_g_ac_log(:), n);

    M = analyze_route(S, path, win_mode, phi_eq, lim, is_xz);
end

function M = analyze_route(S, path, win_mode, phi_eq, lim, is_xz)
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
    M.yaw = err_stats(e_psi, mask_yaw);
    M.tilde = err_stats(tilde, mask_ss);
    M.phi = err_stats(phi, mask_ss);
    M.p = err_stats(p, mask_ss);
    M.p.rms_dps = M.p.rms_deg;
    dr_dot = [0; diff(dr)] / dt;
    M.rudder = actuator_stats(dr, dr_dot, mask_ss, lim.dr_max, lim.near_frac);
    M.rudder_yawwin = actuator_stats(dr, dr_dot, mask_yaw, lim.dr_max, lim.near_frac);
    M.rudder_full = actuator_stats(dr, dr_dot, true(size(dr)), lim.dr_max, lim.near_frac);
    M.yaw.rudder_sat_full_pct = sat_pct(dr, true(size(dr)), 0.95 * lim.dr_max);
    M.path = struct();
    M.path.mean_cte = pm.mean_cross_track;
    M.path.max_cte = pm.max_cross_track;
    if isfield(pm, 'CTE_perp_settled_before_end') && isfield(pm.CTE_perp_settled_before_end, 'rms')
        M.path.rms_cte = pm.CTE_perp_settled_before_end.rms;
    else
        M.path.rms_cte = M.path.mean_cte;
    end
    M.comp = struct();
    M.comp.dr_yaw_rms_deg = rad2deg(rms_local(S.dr_yaw(mask_ss)));
    M.comp.dr_p_rms_deg = rad2deg(rms_local(S.dr_p(mask_ss)));
    M.comp.dr_damp_rms_deg = rad2deg(rms_local(S.dr_damp(mask_ss)));
    M.comp.g_ac_mean = mean(S.g_ac(mask_ss));
end

%% ===================== gates =====================
function [verdict, G, next_opt, next_detail] = score_closure(B0, B1, R0, R1, pitch_gate, law)
    G = struct();
    G.det_base = R0.pass;
    G.det_cand = R1.pass;
    G.deterministic = R0.pass && R1.pass;

    % R10: tilde RMS or p_RMS improve >=10%
    t0 = B0.H.tilde.rms_deg; t1 = B1.H.tilde.rms_deg;
    p0 = B0.H.p.rms_dps;     p1 = B1.H.p.rms_dps;
    G.H.tilde_rms_base = t0; G.H.tilde_rms_cand = t1;
    G.H.p_rms_base = p0; G.H.p_rms_cand = p1;
    G.H.d_tilde_rms_pct = pct_regress(t0, t1);
    G.H.d_p_rms_pct = pct_regress(p0, p1);
    G.H.improve_tilde = (t0 - t1) / max(t0, 1e-9) >= 0.10;
    G.H.improve_p = (p0 - p1) / max(p0, 1e-9) >= 0.10;
    G.H.roll_improve = G.H.improve_tilde || G.H.improve_p;

    % Yaw MAE/RMS/p95 each regression <=2%
    G.H.yaw = regress_gate3(B0.H.yaw, B1.H.yaw, 0.02);

    % Pitch MAE/RMS/p95 <=2% + prior absolute gates
    G.X.pitch_abs = B1.X.pitch.mae_deg <= pitch_gate.X_mae;
    G.XZ.pitch_abs = B1.XZ.pitch.mae_deg <= pitch_gate.XZ_mae;
    G.H.pitch_abs = (B1.H.pitch.mae_deg <= pitch_gate.H_mae) && ...
        (B1.H.pitch.p95_deg <= pitch_gate.H_p95) && ...
        (B1.H.pitch.elev_sat_pct <= pitch_gate.elev_sat);
    G.X.pitch = regress_gate3(B0.X.pitch, B1.X.pitch, 0.02);
    G.XZ.pitch = regress_gate3(B0.XZ.pitch, B1.XZ.pitch, 0.02);
    G.H.pitch = regress_gate3(B0.H.pitch, B1.H.pitch, 0.02);
    G.pitch_ok = G.X.pitch_abs && G.XZ.pitch_abs && G.H.pitch_abs && ...
        G.X.pitch.ok && G.XZ.pitch.ok && G.H.pitch.ok;

    % Path metrics <=2%
    G.X.path = path_gate(B0.X.path, B1.X.path, 0.02);
    G.XZ.path = path_gate(B0.XZ.path, B1.XZ.path, 0.02);
    G.H.path = path_gate(B0.H.path, B1.H.path, 0.02);
    G.path_ok = G.X.path.ok && G.XZ.path.ok && G.H.path.ok;

    % Rudder RMS/rate/near/sat <=2%; full sat <=1%
    a0 = B0.H.rudder_yawwin; a1 = B1.H.rudder_yawwin;
    G.H.act.d_rms_pct  = pct_regress(a0.rms_deg, a1.rms_deg);
    G.H.act.d_rate_pct = pct_regress(a0.rate_rms_dps, a1.rate_rms_dps);
    G.H.act.d_near_pct = pct_regress(a0.near_pct, a1.near_pct);
    G.H.act.d_sat_pct  = pct_regress(a0.sat_pct, a1.sat_pct);
    G.H.act.rms_ok  = G.H.act.d_rms_pct  <= 2.0;
    G.H.act.rate_ok = G.H.act.d_rate_pct <= 2.0;
    G.H.act.near_ok = (a1.near_pct <= a0.near_pct + 2.0) && ...
        (G.H.act.d_near_pct <= 2.0 || a0.near_pct < 1e-9);
    G.H.act.sat_ok  = (a1.sat_pct  <= a0.sat_pct  + 2.0) && ...
        (G.H.act.d_sat_pct  <= 2.0 || a0.sat_pct < 1e-9);
    f0 = B0.H.yaw.rudder_sat_full_pct; f1 = B1.H.yaw.rudder_sat_full_pct;
    G.H.act.d_full_sat_pct = pct_regress(f0, f1);
    G.H.act.full_sat_ok = (f1 <= f0 + 1.0) && ...
        (G.H.act.d_full_sat_pct <= 1.0 || f0 < 1e-9);
    G.H.act.ok = G.H.act.rms_ok && G.H.act.rate_ok && G.H.act.near_ok && ...
        G.H.act.sat_ok && G.H.act.full_sat_ok;
    G.H.act.base = a0; G.H.act.cand = a1;
    G.H.act.full_base = f0; G.H.act.full_cand = f1;

    % X/XZ roll clean
    G.X.clean = (B1.X.tilde.mae_deg <= 0.05) && (B1.X.p.rms_dps <= 0.5);
    G.XZ.clean = (B1.XZ.tilde.mae_deg <= 0.05) && (B1.XZ.p.rms_dps <= 0.5);
    G.straight_clean = G.X.clean && G.XZ.clean;

    G.pass = G.deterministic && G.H.roll_improve && G.H.yaw.ok && G.pitch_ok && ...
        G.path_ok && G.H.act.ok && G.straight_clean;

    if G.pass
        verdict = 'PASS';
        next_opt = 'freeze_roll_production';
        next_detail = sprintf(['PRODUCTION CLOSURE PASS at Kp_roll=%.6f s: ', ...
            'R10 roll improved (d_tildeRMS=%+.2f%%, d_pRMS=%+.2f%%); ', ...
            'yaw/pitch/path/actuator gates held; X/XZ clean; deterministic. ', ...
            'Promote and FREEZE roll damping in production.'], ...
            law.Kp, G.H.d_tilde_rms_pct, G.H.d_p_rms_pct);
    else
        verdict = 'FAIL';
        next_opt = 'revert_production_edits';
        reasons = {};
        if ~G.deterministic; reasons{end+1} = 'non-deterministic repeats'; end %#ok<*AGROW>
        if ~G.H.roll_improve; reasons{end+1} = 'R10 roll improve<10%'; end
        if ~G.H.yaw.ok; reasons{end+1} = 'yaw regress>2%'; end
        if ~G.pitch_ok; reasons{end+1} = 'pitch gate fail'; end
        if ~G.path_ok; reasons{end+1} = 'path regress>2%'; end
        if ~G.H.act.ok; reasons{end+1} = 'rudder gate fail'; end
        if ~G.straight_clean; reasons{end+1} = 'X/XZ not clean'; end
        next_detail = ['FAIL production closure; REVERT controller_law.m + ', ...
            'continuous_path_tracking.m. Reasons: ', strjoin(reasons, '; '), '.'];
    end
end

function g = regress_gate3(b, c, tol)
    g = struct();
    g.d_mae_pct = pct_regress(b.mae_deg, c.mae_deg);
    g.d_rms_pct = pct_regress(b.rms_deg, c.rms_deg);
    g.d_p95_pct = pct_regress(b.p95_deg, c.p95_deg);
    g.ok = (g.d_mae_pct <= 100 * tol) && (g.d_rms_pct <= 100 * tol) && ...
        (g.d_p95_pct <= 100 * tol);
end

function g = path_gate(b, c, tol)
    g = struct();
    g.d_mean_pct = pct_regress(b.mean_cte, c.mean_cte);
    g.d_max_pct = pct_regress(b.max_cte, c.max_cte);
    g.d_rms_pct = pct_regress(b.rms_cte, c.rms_cte);
    g.ok = (g.d_mean_pct <= 100 * tol) && (g.d_max_pct <= 100 * tol) && ...
        (g.d_rms_pct <= 100 * tol || ~(isfinite(b.rms_cte) && isfinite(c.rms_cte)));
end

function R = repeat_check(A, B)
    keys = {'tilde','yaw','pitch','p'};
    fields = {'mae_deg','rms_deg','p95_deg'};
    max_abs = 0; n_cmp = 0;
    for ik = 1:numel(keys)
        for jf = 1:numel(fields)
            if isfield(A.(keys{ik}), fields{jf}) && isfield(B.(keys{ik}), fields{jf})
                d = abs(A.(keys{ik}).(fields{jf}) - B.(keys{ik}).(fields{jf}));
                if isfinite(d)
                    max_abs = max(max_abs, d);
                    n_cmp = n_cmp + 1;
                end
            end
        end
    end
    if isfield(A, 'path') && isfield(B, 'path')
        max_abs = max(max_abs, abs(A.path.mean_cte - B.path.mean_cte));
    end
    R = struct('pass', max_abs < 1e-9, 'max_abs_diff', max_abs, 'n_cmp', n_cmp);
end

function p = pct_regress(b, c)
    if ~(isfinite(b) && isfinite(c)); p = Inf; return; end
    p = 100 * (c - b) / max(abs(b), 1e-9);
end

%% ===================== writers =====================
function write_png(png_path, B0, B1, phi_eq, lim, task_id, verdict, law)
    fig = figure('Visible', 'off', 'Position', [20 20 1500 1000]);
    titles = {sprintf('R10 (\\phi_{eq}=%.3f^\\circ)', rad2deg(phi_eq.H)), ...
        'X (\\phi_{eq}=0)', 'XZ (\\phi_{eq}=0)'};
    S0s = {B0.SH, B0.SX, B0.SXZ};
    S1s = {B1.SH, B1.SX, B1.SXZ};
    M0s = {B0.H, B0.X, B0.XZ};
    M1s = {B1.H, B1.X, B1.XZ};
    paths = {B1.SH.vp, B1.SX.vp, B1.SXZ.vp}; %#ok<NASGU>
    for i = 1:3
        S0 = S0s{i}; S1 = S1s{i}; M0 = M0s{i}; M1 = M1s{i};
        t0 = S0.t; t1 = S1.t;
        peq = M0.phi_eq_deg;

        subplot(6, 3, i);
        plot(t0, rad2deg(S0.ori(:,1)), 'b-', t1, rad2deg(S1.ori(:,1)), 'r-', 'LineWidth', 0.9);
        hold on; yline(peq, 'k--', 'LineWidth', 1.0);
        title(titles{i}); ylabel('\phi [deg]'); grid on;
        if i == 1; legend('base','prod','\phi_{eq}', 'Location', 'best'); end

        subplot(6, 3, 3 + i);
        plot(t0, rad2deg(S0.ori(:,1) - M0.phi_eq_rad), 'b-', ...
             t1, rad2deg(S1.ori(:,1) - M1.phi_eq_rad), 'r-', 'LineWidth', 0.9);
        ylabel('$\tilde\phi$ [deg]', 'Interpreter', 'latex'); grid on;

        subplot(6, 3, 6 + i);
        plot(t0, rad2deg(S0.rates(:,1)), 'b-', t1, rad2deg(S1.rates(:,1)), 'r-', 'LineWidth', 0.9);
        ylabel('p [deg/s]'); grid on;

        subplot(6, 3, 9 + i);
        e0y = wrapToPi(S0.psi_ref - S0.ori(:,3));
        e1y = wrapToPi(S1.psi_ref - S1.ori(:,3));
        e0p = S0.theta_ref - (-S0.ori(:,2));
        e1p = S1.theta_ref - (-S1.ori(:,2));
        plot(t0, rad2deg(e0y), 'b-', t1, rad2deg(e1y), 'r-', ...
             t0, rad2deg(e0p), 'b--', t1, rad2deg(e1p), 'r--', 'LineWidth', 0.8);
        ylabel('e_\psi / e_\theta [deg]'); grid on;
        if i == 1; legend('yaw base','yaw prod','pit base','pit prod', 'Location', 'best'); end

        subplot(6, 3, 12 + i);
        dr_lim = rad2deg(lim.dr_max);
        plot(t1, rad2deg(S1.dr_yaw), 'k-', t1, rad2deg(S1.dr_p), 'm-', ...
             t1, rad2deg(S1.dr_damp), 'g-', t1, rad2deg(S1.delta_r), 'r-', 'LineWidth', 0.8);
        hold on;
        yline(dr_lim, 'k--'); yline(-dr_lim, 'k--');
        ylabel('\delta_r comps'); grid on;
        if i == 1
            legend('yaw','p','damp','applied','\pm lim', 'Location', 'best');
        end

        subplot(6, 3, 15 + i);
        if i == 1
            plot3(S1.vp(:,1), S1.vp(:,2), S1.vp(:,3), 'r-', 'LineWidth', 1.0);
            axis equal; grid on; xlabel('x'); ylabel('y'); zlabel('z');
            title('path (prod)');
        else
            plot(S1.vp(:,1), S1.vp(:,3), 'r-', 'LineWidth', 1.0);
            grid on; xlabel('x [m]'); ylabel('z [m]');
            title('path xz (prod)');
        end
    end
    sgtitle(sprintf('%s | %s | Kp_{roll}=%.4f (Kphi=0)', task_id, verdict, law.Kp), ...
        'Interpreter', 'none');
    exportgraphics(fig, png_path, 'Resolution', 140);
    close(fig);
end

function write_md(md_path, task_id, verdict, law, phi_eq, B0, B1, R0, R1, G, ...
        pitch_gate, lim, next_opt, next_detail, seed_used, ...
        md_p, mat_p, png_p, backoff_p, ctrl_p, cpt_p)
    fid = fopen(md_path, 'w');
    fprintf(fid, '# %s — Production roll-damp integration closure\n\n', task_id);
    fprintf(fid, '**Overall verdict: %s**\n\n', verdict);
    fprintf(fid, '## Provenance\n\n');
    fprintf(fid, '- Read-only sources: `%s`, `%s`, `%s`\n', ctrl_p, cpt_p, backoff_p);
    fprintf(fid, '- Driver: `run_roll_production_closure.m` (one invocation)\n');
    fprintf(fid, '- Artifacts: `%s`, `%s`, `%s`\n', md_p, mat_p, png_p);
    fprintf(fid, '- Seed: %d | two repeats/route | rudder +/-%.0f deg, %.0f deg/s\n\n', ...
        seed_used, rad2deg(lim.dr_max), rad2deg(lim.dr_rate));

    fprintf(fid, '## Old -> new / equation / provenance\n\n');
    fprintf(fid, '```\nOLD: %s\nNEW: %s\nEQ:  %s\n', law.old, law.new, law.equation);
    fprintf(fid, 'Kp_roll=%.6f s | Kphi=0 | provenance: %s\n', law.Kp, law.provenance);
    fprintf(fid, 'Yaw/pitch gains UNCHANGED (Kp_psi=%.0f Kd_psi=%.0f)\n', law.Kp_psi, law.Kd_psi);
    fprintf(fid, 'Sum dr_damp BEFORE existing magnitude/rate limiter\n');
    fprintf(fid, 'Optional p input (default 0); continuous_path_tracking passes BODY p=state(10)\n');
    fprintf(fid, '```\n\n');

    fprintf(fid, '## Repeat table (seed=%d)\n\n', seed_used);
    fprintf(fid, '| Mode | Route | det PASS | max|rep1-rep2| |\n');
    fprintf(fid, '|------|-------|:--------:|---------------:|\n');
    fprintf(fid, '| base Kp=0 | X | %s | %.3e |\n', yn(R0.X.pass), R0.X.max_abs_diff);
    fprintf(fid, '| base Kp=0 | XZ | %s | %.3e |\n', yn(R0.XZ.pass), R0.XZ.max_abs_diff);
    fprintf(fid, '| base Kp=0 | H | %s | %.3e |\n', yn(R0.H.pass), R0.H.max_abs_diff);
    fprintf(fid, '| prod Kp=%.6f | X | %s | %.3e |\n', law.Kp, yn(R1.X.pass), R1.X.max_abs_diff);
    fprintf(fid, '| prod Kp=%.6f | XZ | %s | %.3e |\n', law.Kp, yn(R1.XZ.pass), R1.XZ.max_abs_diff);
    fprintf(fid, '| prod Kp=%.6f | H | %s | %.3e |\n\n', law.Kp, yn(R1.H.pass), R1.H.max_abs_diff);

    fprintf(fid, '## Before / after (steady, rep1)\n\n');
    fprintf(fid, '| Route | metric | base | prod | d%% |\n|-------|--------|-----:|-----:|---:|\n');
    dump_ba(fid, 'X', B0.X, B1.X);
    dump_ba(fid, 'XZ', B0.XZ, B1.XZ);
    dump_ba(fid, 'H', B0.H, B1.H);

    fprintf(fid, '\n## Gate table\n\n');
    fprintf(fid, '| Gate | Result | Detail |\n|------|:------:|--------|\n');
    fprintf(fid, '| Deterministic (2-rep) | %s | base=%s cand=%s |\n', ...
        yn(G.deterministic), yn(G.det_base), yn(G.det_cand));
    fprintf(fid, '| R10 tildeRMS or pRMS improve >=10%% | %s | d_tilde=%+.2f%% d_p=%+.2f%% |\n', ...
        yn(G.H.roll_improve), G.H.d_tilde_rms_pct, G.H.d_p_rms_pct);
    fprintf(fid, '| Yaw MAE/RMS/p95 regress <=2%% | %s | d%%=%.2f/%.2f/%.2f |\n', ...
        yn(G.H.yaw.ok), G.H.yaw.d_mae_pct, G.H.yaw.d_rms_pct, G.H.yaw.d_p95_pct);
    fprintf(fid, '| Pitch MAE/RMS/p95 <=2%% + prior abs | %s | X/XZ/H abs+reg |\n', yn(G.pitch_ok));
    fprintf(fid, '| Path metrics regress <=2%% | %s | X/XZ/H mean/max/rms CTE |\n', yn(G.path_ok));
    fprintf(fid, '| Rudder RMS/rate/near/sat<=2%%; full sat<=1%% | %s | rms %+.2f%% rate %+.2f%% full %.2f->%.2f |\n', ...
        yn(G.H.act.ok), G.H.act.d_rms_pct, G.H.act.d_rate_pct, ...
        G.H.act.full_base, G.H.act.full_cand);
    fprintf(fid, '| X/XZ roll clean | %s | tildeMAE<=0.05 pRMS<=0.5 |\n\n', yn(G.straight_clean));

    fprintf(fid, '## Changed files\n\n');
    fprintf(fid, '- `controller_law.m` — optional p; dr_damp=g_ac*(-Kp_roll*p); dbg\n');
    fprintf(fid, '- `continuous_path_tracking.m` — pass BODY p=state(10); rudder suite logs\n');
    fprintf(fid, '- `run_roll_production_closure.m` — this driver\n\n');

    fprintf(fid, '## Decision\n\n');
    fprintf(fid, '- Verdict: **%s**\n', verdict);
    fprintf(fid, '- Next: `%s`\n', next_opt);
    fprintf(fid, '- Detail: %s\n', next_detail);
    if strcmp(verdict, 'PASS')
        fprintf(fid, '- Production: PROMOTION FROZEN (roll damp retained)\n\n');
    else
        fprintf(fid, '- Production: REVERTED from `.roll_closure_bak`\n\n');
    end

    fprintf(fid, '## Feedback\n\n');
    fprintf(fid, '- PASS/FAIL: **%s**\n', verdict);
    fprintf(fid, '- Old->new: yaw-PD only -> yaw-PD + g_ac*(-%.6f*p); Kphi=0\n', law.Kp);
    fprintf(fid, '- Provenance: %s\n', law.provenance);
    fprintf(fid, '- R10 tildeRMS %.4f->%.4f (%+.2f%%); pRMS %.4f->%.4f (%+.2f%%)\n', ...
        G.H.tilde_rms_base, G.H.tilde_rms_cand, G.H.d_tilde_rms_pct, ...
        G.H.p_rms_base, G.H.p_rms_cand, G.H.d_p_rms_pct);
    fprintf(fid, '- Yaw d%% MAE/RMS/p95: %.2f / %.2f / %.2f\n', ...
        G.H.yaw.d_mae_pct, G.H.yaw.d_rms_pct, G.H.yaw.d_p95_pct);
    fprintf(fid, '- Next: %s\n', next_opt);
    fprintf(fid, '- Evidence: `%s` `%s` `%s`\n', md_p, mat_p, png_p);
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
        'pitchMAE', M0.pitch.mae_deg, M1.pitch.mae_deg; ...
        'pitchRMS', M0.pitch.rms_deg, M1.pitch.rms_deg; ...
        'pitchP95', M0.pitch.p95_deg, M1.pitch.p95_deg; ...
        'pathCTE', M0.path.mean_cte, M1.path.mean_cte};
    for i = 1:size(rows, 1)
        b = rows{i, 2}; c = rows{i, 3};
        fprintf(fid, '| %s | %s | %.4f | %.4f | %+.2f |\n', nm, rows{i, 1}, b, c, pct_regress(b, c));
    end
end

function append_ss_audit(out_dir, task_id, verdict, law, phi_eq, B0, B1, R0, R1, G, ...
        next_opt, next_detail, md_path, mat_path, png_path)
    audit = fullfile(out_dir, 'STATE_SPACE_MODEL_AUDIT.md');
    fid = fopen(audit, 'a');
    fprintf(fid, '\n\n---\n\n');
    fprintf(fid, '## %s — %s\n\n', task_id, datestr(now, 'yyyy-mm-dd HH:MM:SS'));
    fprintf(fid, '### Provenance\n\n');
    fprintf(fid, '- Sources: `controller_law.m`, `continuous_path_tracking.m`, `YAW_ROLL_DAMPING_BACKOFF.mat`\n');
    fprintf(fid, '- Driver: `run_roll_production_closure.m` (one invocation; actual production law)\n');
    fprintf(fid, '- Artifacts: `%s`, `%s`, `%s`\n\n', md_path, mat_path, png_path);
    fprintf(fid, '### Old -> new\n\n');
    fprintf(fid, '```\nOLD: %s\nNEW: %s\nEQ:  %s\n', law.old, law.new, law.equation);
    fprintf(fid, 'Kp_roll=%.6f s | Kphi=0 | %s\n', law.Kp, law.provenance);
    fprintf(fid, 'phi_eq: X=0 XZ=0 H=%.4f deg\n```\n\n', rad2deg(phi_eq.H));
    fprintf(fid, '### Repeat / R10\n\n');
    fprintf(fid, '- Determinism: base=%s cand=%s (seed=0, 2-rep)\n', yn(R0.pass), yn(R1.pass));
    fprintf(fid, '| metric | base | prod | d%% |\n|--------|-----:|-----:|---:|\n');
    fprintf(fid, '| tildeRMS [deg] | %.4f | %.4f | %+.2f |\n', G.H.tilde_rms_base, G.H.tilde_rms_cand, G.H.d_tilde_rms_pct);
    fprintf(fid, '| pRMS [deg/s] | %.4f | %.4f | %+.2f |\n', G.H.p_rms_base, G.H.p_rms_cand, G.H.d_p_rms_pct);
    fprintf(fid, '| yawMAE [deg] | %.4f | %.4f | %+.2f |\n', B0.H.yaw.mae_deg, B1.H.yaw.mae_deg, G.H.yaw.d_mae_pct);
    fprintf(fid, '| yawRMS [deg] | %.4f | %.4f | %+.2f |\n', B0.H.yaw.rms_deg, B1.H.yaw.rms_deg, G.H.yaw.d_rms_pct);
    fprintf(fid, '| yawP95 [deg] | %.4f | %.4f | %+.2f |\n\n', B0.H.yaw.p95_deg, B1.H.yaw.p95_deg, G.H.yaw.d_p95_pct);
    fprintf(fid, '### Verdict / next\n\n');
    fprintf(fid, '- Verdict: **%s**\n', verdict);
    fprintf(fid, '- Next: `%s` — %s\n', next_opt, next_detail);
    if strcmp(verdict, 'PASS')
        fprintf(fid, '- Production: roll damp PROMOTION FROZEN\n\n');
    else
        fprintf(fid, '- Production: REVERTED\n\n');
    end
    fprintf(fid, '### Next\n\n');
    fprintf(fid, '- %s\n', next_opt);
    fclose(fid);
end

function print_feedback(verdict, law, B0, B1, R0, R1, G, next_opt, next_detail, md, mat, png)
    fprintf('\n---- FEEDBACK ----\n');
    fprintf('PASS/FAIL: %s\n', verdict);
    fprintf('Old->new: %s\n       -> %s\n', law.old, law.new);
    fprintf('Equation: %s\n', law.equation);
    fprintf('Provenance: %s | Kp_roll=%.6f Kphi=0\n', law.provenance, law.Kp);
    fprintf('Repeat: base det=%s (X/XZ/H maxdiff %.1e/%.1e/%.1e)\n', ...
        yn(R0.pass), R0.X.max_abs_diff, R0.XZ.max_abs_diff, R0.H.max_abs_diff);
    fprintf('         cand det=%s (X/XZ/H maxdiff %.1e/%.1e/%.1e)\n', ...
        yn(R1.pass), R1.X.max_abs_diff, R1.XZ.max_abs_diff, R1.H.max_abs_diff);
    fprintf('R10 tildeRMS %.4f->%.4f (%+.2f%%) | pRMS %.4f->%.4f (%+.2f%%)\n', ...
        G.H.tilde_rms_base, G.H.tilde_rms_cand, G.H.d_tilde_rms_pct, ...
        G.H.p_rms_base, G.H.p_rms_cand, G.H.d_p_rms_pct);
    fprintf('Yaw d%% MAE/RMS/p95: %.2f / %.2f / %.2f | pitch_ok=%d path_ok=%d act_ok=%d XZclean=%d\n', ...
        G.H.yaw.d_mae_pct, G.H.yaw.d_rms_pct, G.H.yaw.d_p95_pct, ...
        G.pitch_ok, G.path_ok, G.H.act.ok, G.straight_clean);
    fprintf('Changed: controller_law.m, continuous_path_tracking.m, run_roll_production_closure.m\n');
    fprintf('Next: %s — %s\n', next_opt, next_detail);
    fprintf('Evidence: %s | %s | %s\n', md, mat, png);
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
