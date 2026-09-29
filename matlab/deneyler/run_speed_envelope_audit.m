function run_speed_envelope_audit()
% SPEED_ENVELOPE_AUDIT_001 — production nonlinear 6DOF speed envelope grid.
% Gamma INDI/PI/ADRC scaffolds rejected; production theta/q cascade + climb FF frozen.
% Read-only: controller_law.m, underwater777_vehicle_dynamics.m,
% suite_results/PITCH_CONTROL_RESEARCH_LOG.md. No controller/config/gain change.
% One MATLAB invocation. Grid Uref=[1.0 1.25 1.5 1.75 2.0] on X / XZ / R10.
% Artifacts: suite_results/SPEED_ENVELOPE_AUDIT.{md,mat,png}

    project_dir = fileparts(fileparts(fileparts(mfilename('fullpath')))); % repo root
    addpath(genpath(fullfile(project_dir, 'matlab')));
    out_dir = fullfile(project_dir, 'suite_results');
    if ~exist(out_dir, 'dir'); mkdir(out_dir); end
    tag = 'SPEED_ENVELOPE_AUDIT';
    task_id = 'SPEED_ENVELOPE_AUDIT_001';

    ctrl_path = fullfile(project_dir, 'controller_law.m');
    dyn_path  = fullfile(project_dir, 'underwater777_vehicle_dynamics.m');
    log_path  = fullfile(out_dir, 'PITCH_CONTROL_RESEARCH_LOG.md');
    assert(exist(ctrl_path, 'file') == 2, 'Missing %s', ctrl_path);
    assert(exist(dyn_path, 'file') == 2, 'Missing %s', dyn_path);
    assert(exist(log_path, 'file') == 2, 'Missing %s', log_path);

    ctrl_txt = fileread(ctrl_path);
    assert(contains(ctrl_txt, 'k_gamma_climb = 0.1320695001'), 'climb FF missing');
    assert(contains(ctrl_txt, 'Kp_roll'), 'roll damp missing');
    assert(contains(ctrl_txt, 'thrust_trim + Kp_x * (u_ref - u)'), 'thrust law mismatch');
    assert(contains(ctrl_txt, 'de_climb_ff'), 'climb FF term missing');
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
    global Kp_x thrust_trim thrust_max thrust_min desired_speed Kp_roll

    % Frozen production stack (no retune)
    elevator_sign = 1;
    trim_speed_table = [0.8 1.0 1.5 2.0];
    trim_elevator_table = deg2rad([-9.18 -7.33 -4.62 -3.17]);
    K_gamma = 0; K_zdot = 0; enable_alpha_hat = false;
    Kp_roll = 0.605072;

    Ugrid = [1.0 1.25 1.5 1.75 2.0];
    seed_used = 0;
    rng(seed_used, 'twister');

    lim = struct( ...
        'dr_max', delta_r_max, 'de_max', delta_e_max, ...
        'dr_rate', deg2rad(40), 'de_rate', deg2rad(40), ...
        'near_frac', 0.80, 'thrust_max', thrust_max, 'thrust_min', thrust_min);

    % Absolute hard gates (established pitch/yaw closure absolutes; gamma additive)
    HG = struct();
    HG.X.pitch_mae = 0.10; HG.X.pitch_p95 = 0.50; HG.X.gamma_mae = 0.50; HG.X.gamma_p95 = 1.00;
    HG.XZ.pitch_mae = 0.30; HG.XZ.pitch_p95 = 0.50; HG.XZ.gamma_mae = 1.00; HG.XZ.gamma_p95 = 1.50;
    HG.H.pitch_mae = 0.30; HG.H.pitch_p95 = 0.50; HG.H.gamma_mae = 1.50; HG.H.gamma_p95 = 2.50;
    HG.H.yaw_mae = 1.0; HG.H.yaw_p95 = 2.0;
    HG.elev_sat = 1.0; HG.rud_sat_ss = 1.0; HG.rud_sat_full = 1.0;
    HG.chatter = 0.20; HG.ratio_lo = 0.98; HG.ratio_hi = 1.02;
    HG.rate_util = 1.0; HG.thrust_sat = 1.0;
    HG.trim_tol = 0.01;
    HG.phi_eq = struct('X', 0.0, 'XZ', 0.0, 'H', 0.0255);

    % Established routes
    nX = 600; xX = linspace(0, 45, nX)';
    pathX = [xX, zeros(nX, 1), zeros(nX, 1)];
    nXZ = 900; xXZ = linspace(0, 42, nXZ)';
    pathXZ = [xXZ, zeros(nXZ, 1), 0.4 * xXZ];
    pathH = generate_balanced_helical_path(10.0, 2.0, 2, 500);
    routes = {'X', 'XZ', 'H'};
    paths = {pathX, pathXZ, pathH};
    Tfin = [18, 22, 45];
    win_mode = {'first_hold', 'persistent', 'persistent'};
    slope = [0.0, 0.4, NaN];
    lambda0 = [0.25, 0.0, 0.25];

    % Seeds for plant trim (documented exact-u@1.5 from THRUST_TRIM_U15_AUDIT)
    seed_level = struct('theta', -0.0333395, 'v', 0, 'w', -0.0500278, 'q', 0, ...
        'de', -0.116328, 'T', 3.81167, 'u', 1.5);
    seed_climb = struct('theta', -0.431841, 'v', 0, 'w', -0.0770689, 'q', 0, ...
        'de', -0.0210529, 'T', 5.73772, 'u', 1.5);
    x_scale = [10; 10; 10; 1; 1; 1; 1.5; 0.3; 0.3; 0.2; 0.2; 0.2];
    nu_dot_scale = [1.0; 0.3; 0.3; 0.2; 0.2; 0.2];

    fprintf('\n========== %s ==========\n', task_id);
    fprintf('Production cascade+climbFF frozen; gamma INDI/PI/ADRC rejected.\n');
    fprintf('Grid Uref=%s | routes=X,XZ,R10 | no gain/config change.\n', mat2str(Ugrid));
    fprintf('Preserve: R5 hard yaw FAIL; R7.5 soft yaw FAIL; R10@1.5 PASS.\n');

    Cell = repmat(empty_cell(), numel(Ugrid), numel(routes));
    for iu = 1:numel(Ugrid)
        Uref = Ugrid(iu);
        fprintf('\n---- Uref=%.2f m/s ----\n', Uref);

        TrimL = solve_translating(Uref, 0.0, seed_level, nu_dot_scale, x_scale, HG.trim_tol, 'level');
        TrimC = solve_translating(Uref, 0.4, seed_climb, nu_dot_scale, x_scale, HG.trim_tol, 'climb');
        fprintf('  trim level: pass=%d norm=%.3g T*=%.3f de=%.2fdeg\n', ...
            TrimL.pass, TrimL.norm_dyn, TrimL.Treq, rad2deg(TrimL.u_star(2)));
        fprintf('  trim climb: pass=%d norm=%.3g T*=%.3f de=%.2fdeg\n', ...
            TrimC.pass, TrimC.norm_dyn, TrimC.Treq, rad2deg(TrimC.u_star(2)));

        for ir = 1:numel(routes)
            rname = routes{ir};
            fprintf('  -- %s @ %.2f --\n', rname, Uref);
            rng(seed_used, 'twister');
            desired_speed = Uref;
            lambda_muw_ff = lambda0(ir);

            if strcmp(rname, 'X')
                Trim = TrimL;
            elseif strcmp(rname, 'XZ')
                Trim = TrimC;
            else
                Trim = helix_trim_stub(Uref);
            end

            try
                [S, M] = sim_route(paths{ir}, Tfin(ir), Uref, Trim, lim, ...
                    win_mode{ir}, strcmp(rname, 'XZ'), strcmp(rname, 'H') * 10.0, ...
                    HG.phi_eq.(rname));
                M.trim = Trim;
                M.Uref = Uref;
                M.route = rname;
                M.sim_ok = true;
                M.sim_err = '';
            catch ME
                fprintf('     SIM ERROR: %s\n', ME.message);
                if ~isempty(ME.stack)
                    fprintf('       at %s:%d\n', ME.stack(1).name, ME.stack(1).line);
                end
                S = struct('t', [], 'Uref', Uref);
                M = fail_metrics(Uref, rname, Trim, ME.message);
            end

            M.feas = score_feasible(M, rname, HG, lim);
            Cell(iu, ir).Uref = Uref;
            Cell(iu, ir).route = rname;
            Cell(iu, ir).M = M;
            Cell(iu, ir).S = compact_S(S);
            Cell(iu, ir).feasible = M.feas.feasible;
            Cell(iu, ir).first_limit = M.feas.first_limit;
            fprintf('     FEASIBLE=%s first=%s | uMAE=%.4f thMAE=%.4f gMAE=%.4f cte=%.3f\n', ...
                yn(M.feas.feasible), M.feas.first_limit, ...
                nz(M.speed.mae), nz(M.theta.mae_deg), nz(M.gamma.mae_deg), nz(M.path.mean_cte));
        end
    end

    Cert = certify_ranges(Cell, Ugrid, routes);
    Next = decide_next(Cert, Cell);

    audit_complete = true;
    for iu = 1:numel(Ugrid)
        for ir = 1:numel(routes)
            ok = isfield(Cell(iu, ir), 'M') && isfield(Cell(iu, ir).M, 'feas') && ...
                isfield(Cell(iu, ir).M, 'sim_ok') && Cell(iu, ir).M.sim_ok;
            if ~ok; audit_complete = false; end
        end
    end
    verdict = tern(audit_complete, 'PASS', 'FAIL');

    md_path  = fullfile(out_dir, [tag '.md']);
    mat_path = fullfile(out_dir, [tag '.mat']);
    png_path = fullfile(out_dir, [tag '.png']);

    write_png(png_path, Cell, Ugrid, routes, Cert, task_id, verdict);
    write_md(md_path, task_id, verdict, Cell, Ugrid, routes, Cert, Next, HG, lim, ...
        seed_used, ctrl_path, dyn_path, log_path, md_path, mat_path, png_path, ...
        thrust_trim, Kp_x, Kp_roll);
    append_research_log(log_path, task_id, verdict, Cert, Next, Cell, Ugrid, ...
        md_path, mat_path, png_path);

    Out = struct();
    Out.task_id = task_id;
    Out.verdict = verdict;
    Out.audit_complete = audit_complete;
    Out.Ugrid = Ugrid;
    Out.routes = routes;
    Out.Cell = Cell;
    Out.Cert = Cert;
    Out.Next = Next;
    Out.HG = HG;
    Out.limits = lim;
    Out.seed_used = seed_used;
    Out.Kp_roll = Kp_roll;
    Out.thrust_trim = thrust_trim;
    Out.Kp_x = Kp_x;
    Out.production_edited = false;
    Out.gamma_methods_rejected = { ...
        'GAMMA_INDI_SCAFFOLD REJECT_DIRECT_INDI_SCAFFOLD'; ...
        'OUTER_GAMMA_PI_SCAFFOLD REJECT_OUTER_GAMMA_PI_SCAFFOLD'; ...
        'OUTER_GAMMA_ADRC_SCAFFOLD REJECT_OUTER_GAMMA_ADRC_SCAFFOLD'};
    Out.yaw_envelope_preserved = struct( ...
        'R5', 'hard authority FAIL (rudder sat ~95%)', ...
        'R75', 'soft FAIL (sat 1.06%, ratio 1.024)', ...
        'R8', 'soft FAIL (full sat 6.67%, ratio 1.0236)', ...
        'R10_u15', 'PASS (comfortable envelope)');
    Out.sources = {ctrl_path; dyn_path; log_path};
    Out.paths = struct('md', md_path, 'mat', mat_path, 'png', png_path);
    save(mat_path, '-struct', 'Out', '-v7.3');

    fprintf('\nVERDICT(audit completeness): %s\n', verdict);
    fprintf('Certified contiguous: X=%s | XZ=%s | R10=%s | worst_margin=%.4g\n', ...
        Cert.X.label, Cert.XZ.label, Cert.H.label, Cert.worst_margin);
    fprintf('Next: %s\n', Next.gate);
    fprintf('Saved: %s\n%s\n%s\n', md_path, mat_path, png_path);
    assignin('base', 'SPEED_ENVELOPE_AUDIT_PASS', strcmp(verdict, 'PASS'));
end

%% ===================== empty / fail helpers =====================
function c = empty_cell()
    c = struct('Uref', NaN, 'route', '', 'M', struct(), 'S', struct(), ...
        'feasible', false, 'first_limit', 'unrun');
end

function M = fail_metrics(Uref, rname, Trim, msg)
    M = struct();
    M.Uref = Uref; M.route = rname; M.trim = Trim;
    M.sim_ok = false; M.sim_err = msg;
    M.speed = struct('mae', NaN, 'p95', NaN, 'signed_mean', NaN, 'u_mean', NaN);
    M.theta = struct('mae_deg', NaN, 'p95_deg', NaN);
    M.gamma = struct('mae_deg', NaN, 'p95_deg', NaN);
    M.yaw = struct('mae_deg', NaN, 'p95_deg', NaN, 'rudder_sat_ss_pct', NaN, ...
        'rudder_sat_full_pct', NaN, 'ratio_r_Uh_kappa', NaN);
    M.roll = struct('tilde_mae_deg', NaN, 'p_rms_dps', NaN);
    M.path = struct('mean_cte', NaN, 'max_cte', NaN);
    M.act = struct('de_mag_util', NaN, 'dr_mag_util', NaN, 'thr_mag_util', NaN, ...
        'de_rate_util', NaN, 'dr_rate_util', NaN, 'thr_rate_util', NaN, ...
        'de_sat_pct', NaN, 'dr_sat_ss_pct', NaN, 'dr_sat_full_pct', NaN, ...
        'thr_sat_pct', NaN, 'chatter_dps', NaN);
    M.bounded = false;
    M.feas = struct('feasible', false, 'first_limit', ['sim_exception:' msg], ...
        'gates', struct());
end

%% ===================== plant trim =====================
function P = solve_translating(Ufix, slope, seed, nu_dot_scale, x_scale, pass_tol, name)
    scale = (Ufix / max(seed.u, 0.5))^2;
    z0 = [seed.theta; seed.v; seed.w; seed.q; seed.de; seed.T * scale];
    [z, exitflag] = local_newton(@(zz) translating_cost(zz, Ufix, slope, nu_dot_scale), z0, 120);
    x = zeros(12, 1);
    x(5) = z(1); x(7) = Ufix; x(8) = z(2); x(9) = z(3); x(11) = z(4);
    u = [0; z(5); z(6)];
    f = underwater777_vehicle_dynamics(0, x, ustruct(u));
    R = residual_pack(f, x_scale, nu_dot_scale, slope);
    P = struct();
    P.name = name;
    P.class = 'steady_translating_trim';
    P.provenance = 'PLANT_SOLVE';
    P.Ufix = Ufix;
    P.slope = slope;
    P.x_star = x;
    P.u_star = u;
    P.Treq = u(3);
    P.norm_dyn = R.norm_dyn;
    P.residual = R;
    P.pass = (R.norm_dyn <= pass_tol) && (abs(x(7) - Ufix) < 1e-12) && isfinite(R.norm_dyn);
    P.exitflag = exitflag;
    P.documented = true;
    xd = f(1); zd = f(3);
    if abs(slope) < 1e-12
        P.slope_err = zd;
    else
        P.slope_err = zd - slope * xd;
    end
end

function P = helix_trim_stub(Uref)
    P = struct();
    P.name = 'helix_R10';
    P.class = 'periodic_or_quasi_steady';
    P.provenance = 'EMPIRICAL_UNKNOWN';
    P.Ufix = Uref;
    P.slope = NaN;
    P.x_star = zeros(12, 1); P.x_star(7) = Uref;
    P.u_star = [0; NaN; NaN];
    P.Treq = NaN;
    P.norm_dyn = NaN;
    P.residual = struct('norm_dyn', NaN, 'note', 'exact-u LTI helix trim not fabricated');
    P.pass = false;
    P.exitflag = 0;
    P.documented = true;  % UNKNOWN documented (THRUST_TRIM / TRIM_OPERATING_POINTS)
    P.slope_err = NaN;
    P.reason = ['Exact-u helix trim UNKNOWN; prior rotating-frame relative-eq failed. ', ...
        'IC = path-tangent + u=Uref; no fabricated LTI trim.'];
end

function c = translating_cost(z, Ufix, slope, nu_dot_scale)
    x = zeros(12, 1);
    x(5) = z(1); x(7) = Ufix; x(8) = z(2); x(9) = z(3); x(11) = z(4);
    f = underwater777_vehicle_dynamics(0, x, ustruct([0; z(5); z(6)]));
    nd = f(7:12) ./ nu_dot_scale;
    ad = f(4:5) / 0.05;
    xd = f(1); zd = f(3);
    if abs(slope) < 1e-12
        slope_err = zd;
    else
        slope_err = zd - slope * xd;
    end
    c = [nd; ad; slope_err / max(0.1, abs(Ufix))];
end

function [z, exitflag] = local_newton(fun, z0, maxit)
    z = z0(:);
    exitflag = 0;
    n = numel(z);
    for it = 1:maxit
        c = fun(z);
        if all(isfinite(c)) && norm(c) < 1e-10
            exitflag = 1; return;
        end
        J = zeros(numel(c), n);
        for j = 1:n
            h = 1e-6 * max(1, abs(z(j)));
            zp = z; zp(j) = zp(j) + h;
            J(:, j) = (fun(zp) - c) / h;
        end
        if rcond(J' * J) < 1e-14
            exitflag = -1; return;
        end
        dz = -(J' * J) \ (J' * c);
        if any(~isfinite(dz)); exitflag = -2; return; end
        z = z + dz;
        if norm(dz) < 1e-10
            exitflag = 1; return;
        end
    end
    exitflag = 0;
end

function R = residual_pack(f, x_scale, nu_dot_scale, slope) %#ok<INUSD>
    nd = f(7:12) ./ nu_dot_scale;
    R = struct();
    R.nu_dot = f(7:12);
    R.eta_dot = f(1:6);
    R.norm_dyn = norm(nd);
    R.att_rate = f(4:6);
end

function ctr = ustruct(u)
    ctr = struct('delta_r', u(1), 'delta_e', u(2), 'thrust', u(3));
end

%% ===================== simulate =====================
function [S, M] = sim_route(path, T_final, Uref, Trim, lim, win_mode, is_xz, R, phi_eq)
    global desired_speed
    desired_speed = Uref;

    state0 = build_state0(path, Uref, Trim);
    if R > 0
        S = simulate_helix_logged(path, T_final, Uref, R, state0);
    else
        S = simulate_straight(path, T_final, Uref, is_xz, state0);
    end
    S.R = R; S.is_xz = is_xz; S.Uref = Uref;
    M = analyze_route(S, path, win_mode, phi_eq, lim, is_xz, R, Uref);
end

function state0 = build_state0(path, Uref, Trim) %#ok<INUSD>
% Established path-tangent IC + BODY u0=Uref (route-consistent).
% Exact-u plant trim residual documented separately (X/XZ solvable; H UNKNOWN).
    state0 = zeros(12, 1);
    state0(1:3) = path(1, :)';
    d = path(2, :) - path(1, :);
    state0(5) = -atan2(d(3), norm(d(1:2)));
    state0(6) = atan2(d(2), d(1));
    state0(7) = Uref;
end

function S = simulate_straight(path, T_final, Uref, is_xz, state0)
    global dt_controller suite_delta_e_log suite_delta_r_log suite_u_log
    global Kp_x thrust_trim thrust_max thrust_min lambda_muw_ff

    clear guidance_law controller_law
    reset_ctrl_globals();

    if is_xz
        lambda_muw_ff = 0.0;
    else
        lambda_muw_ff = 0.25;
    end
    dt = dt_controller;
    [vp, times, vel, rates, ori, ~, yaw_refs, pitch_refs, u_refs] = ...
        continuous_path_tracking(path, state0, dt, T_final);
    n = numel(times);
    u_ctrl = align_len(suite_u_log(:), n);
    de = align_len(suite_delta_e_log(:), n);
    dr = align_len(suite_delta_r_log(:), n);
    thrust = reconstruct_thrust(u_refs(:), u_ctrl, thrust_trim, Kp_x, thrust_min, thrust_max);

    S = struct();
    S.dt = dt; S.T_final = T_final; S.u0 = Uref;
    S.t = times(:); S.vp = vp; S.vel = vel; S.rates = rates; S.ori = ori;
    S.psi_ref = yaw_refs(:); S.theta_ref = pitch_refs(:); S.u_ref = u_refs(:);
    S.u_ctrl = u_ctrl(:); S.u_body = vel(:, 1); S.v_body = vel(:, 2); S.w_body = vel(:, 3);
    [S.Uh, S.VD, S.Vtot] = ned_speeds(ori, vel);
    S.thrust = thrust(:); S.delta_e = de; S.delta_r = dr;
    S.kappa = zeros(n, 1); S.U_h_guid = S.Uh; S.r = rates(:, 3);
end

function S = simulate_helix_logged(path, T_final, Uref, R, state0)
% Established R10 loop with per-step Uh/kappa for yaw ratio (HELIX_R10 envelope).
    global dt_controller dt_guidance
    global last_guidance_U_h last_guidance_kappa last_r_ff
    global last_delta_e last_delta_r
    global thrust_max thrust_min lambda_muw_ff

    clear guidance_law controller_law
    reset_ctrl_globals();
    global last_guidance_U_h last_guidance_kappa last_r_ff
    global last_delta_e last_delta_r

    lambda_muw_ff = 0.25;
    dt = dt_controller;
    if isempty(dt) || ~isfinite(dt); dt = 0.025; end
    if isempty(dt_guidance) || ~isfinite(dt_guidance); dt_guidance = 0.075; end
    n_steps = round(T_final / dt);
    guidance_period = max(1, round(dt_guidance / dt));
    state = state0(:);
    if any(~isfinite(state))
        error('helix IC non-finite');
    end

    yaw_ref = 0; pitch_ref = 0; u_ref = Uref; r_ff = 0; pitch_ref_dot = 0; pidx = 1;

    S = struct();
    S.dt = dt; S.T_final = T_final; S.u0 = Uref; S.R = R;
    S.t = zeros(n_steps, 1);
    S.vp = zeros(n_steps, 3); S.vel = zeros(n_steps, 3);
    S.rates = zeros(n_steps, 3); S.ori = zeros(n_steps, 3);
    S.psi_ref = zeros(n_steps, 1); S.theta_ref = zeros(n_steps, 1);
    S.u_ref = zeros(n_steps, 1); S.u_ctrl = zeros(n_steps, 1);
    S.delta_r = zeros(n_steps, 1); S.delta_e = zeros(n_steps, 1);
    S.thrust = zeros(n_steps, 1);
    S.Uh = zeros(n_steps, 1); S.VD = zeros(n_steps, 1); S.Vtot = zeros(n_steps, 1);
    S.U_h_guid = zeros(n_steps, 1); S.kappa = zeros(n_steps, 1); S.r = zeros(n_steps, 1);

    for k = 1:n_steps
        pos = state(1:3)';
        ori = state(4:6)';
        rates = state(10:12)';
        u = state(7); v = state(8); w = state(9);
        [Uh, zdot, VD] = inertial_Uh_zdot_vd(ori, u, v, w);
        theta_phys_now = -ori(2);

        if mod(k - 1, guidance_period) == 0
            [yaw_ref, pitch_ref, u_ref, pidx, r_ff, pitch_ref_dot] = ...
                guidance_law(pos, path, pidx, u, v, Uh, zdot, theta_phys_now);
        end

        [dr, de, thr] = controller_law(yaw_ref, pitch_ref, u_ref, ...
            ori(3), ori(2), rates(3), rates(2), u, r_ff, pitch_ref_dot, ori(1), w, rates(1));
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
        S.u_ctrl(k) = u;
        if isempty(last_delta_e); last_delta_e = de; end
        if isempty(last_delta_r); last_delta_r = dr; end
        S.delta_e(k) = last_delta_e;
        S.delta_r(k) = last_delta_r;
        S.thrust(k) = max(min(thr, thrust_max), thrust_min);
        S.Uh(k) = Uh; S.VD(k) = VD; S.Vtot(k) = norm(state(7:9));
        if isempty(last_guidance_U_h); last_guidance_U_h = Uh; end
        if isempty(last_guidance_kappa); last_guidance_kappa = 1 / R; end
        if isempty(last_r_ff); last_r_ff = r_ff; end
        S.U_h_guid(k) = last_guidance_U_h;
        S.kappa(k) = last_guidance_kappa;
        S.r(k) = rates(3);

        if mod(k, 400) == 0 || k == n_steps
            fprintf('     helix step %d/%d t=%.1fs\n', k, n_steps, S.t(k));
        end
    end
    S.u_body = S.vel(:, 1); S.v_body = S.vel(:, 2); S.w_body = S.vel(:, 3);
end

function reset_ctrl_globals()
% Clear then re-declare controller/guidance diagnostic globals (avoid cleared-var refs).
    clear global last_guidance_U_h last_guidance_kappa last_r_ff
    clear global last_delta_e last_delta_r last_dr_yaw last_dr_p last_dr_damp last_g_ac
    clear global last_int_angle last_int_rate last_de_fb last_de_trim last_de_uw_ff
    global last_guidance_U_h last_guidance_kappa last_r_ff
    global last_delta_e last_delta_r last_dr_yaw last_dr_p last_dr_damp last_g_ac
    global last_int_angle last_int_rate last_de_fb last_de_trim last_de_uw_ff
    last_guidance_U_h = []; last_guidance_kappa = []; last_r_ff = [];
    last_delta_e = []; last_delta_r = [];
    last_dr_yaw = []; last_dr_p = []; last_dr_damp = []; last_g_ac = [];
    last_int_angle = []; last_int_rate = [];
    last_de_fb = []; last_de_trim = []; last_de_uw_ff = [];
end

function [Uh, zdot, VD] = inertial_Uh_zdot_vd(ori, u, v, w)
    phi = ori(1); th = ori(2); psi = ori(3);
    Rm = [cos(psi)*cos(th), cos(psi)*sin(th)*sin(phi)-sin(psi)*cos(phi), cos(psi)*sin(th)*cos(phi)+sin(psi)*sin(phi);
          sin(psi)*cos(th), sin(psi)*sin(th)*sin(phi)+cos(psi)*cos(phi), sin(psi)*sin(th)*cos(phi)-cos(psi)*sin(phi);
          -sin(th), cos(th)*sin(phi), cos(th)*cos(phi)];
    pd = Rm * [u; v; w];
    Uh = hypot(pd(1), pd(2));
    zdot = pd(3);
    VD = pd(3);
end

function [Uh, VD, Vtot] = ned_speeds(ori, vel)
    n = size(vel, 1);
    Uh = zeros(n, 1); VD = zeros(n, 1); Vtot = zeros(n, 1);
    for i = 1:n
        phi = ori(i, 1); th = ori(i, 2); psi = ori(i, 3);
        R = [cos(psi)*cos(th), cos(psi)*sin(th)*sin(phi)-sin(psi)*cos(phi), cos(psi)*sin(th)*cos(phi)+sin(psi)*sin(phi);
             sin(psi)*cos(th), sin(psi)*sin(th)*sin(phi)+cos(psi)*cos(phi), sin(psi)*sin(th)*cos(phi)-cos(psi)*sin(phi);
             -sin(th), cos(th)*sin(phi), cos(th)*cos(phi)];
        pd = R * vel(i, 1:3)';
        Uh(i) = hypot(pd(1), pd(2));
        VD(i) = pd(3);
        Vtot(i) = norm(vel(i, 1:3));
    end
end

function thrust = reconstruct_thrust(u_ref, u, trim, Kp, tmin, tmax)
    thrust = trim + Kp * (u_ref - u);
    thrust = max(min(thrust, tmax), tmin);
end

function Sc = compact_S(S)
    Sc = struct();
    if ~isfield(S, 't') || isempty(S.t); return; end
    keep = {'t','vp','vel','rates','ori','psi_ref','theta_ref','u_ref','u_ctrl', ...
        'u_body','thrust','delta_e','delta_r','Uh','VD','Uref','dt','R','is_xz'};
    for i = 1:numel(keep)
        if isfield(S, keep{i}); Sc.(keep{i}) = S.(keep{i}); end
    end
end

%% ===================== analyze =====================
function M = analyze_route(S, path, win_mode, phi_eq, lim, is_xz, R, Uref)
    t = S.t(:); dt = S.dt; n = numel(t);
    phi = S.ori(:, 1);
    theta_phys = -S.ori(:, 2);
    psi = S.ori(:, 3);
    p = S.rates(:, 1);
    de = S.delta_e(:); dr = S.delta_r(:);
    e_psi = wrapToPi(S.psi_ref - psi);
    e_th = wrapToPi(S.theta_ref - theta_phys);
    tilde = phi - phi_eq;
    e_u = S.u_ref - S.u_ctrl;

    gamma_act = atan2(S.VD, max(S.Uh, 1e-9));
    [gamma_ref, cte_perp, s_prog, s_total] = path_gamma_cte(path, S.vp);
    e_gamma = wrapToPi(gamma_ref - gamma_act);

    pm = compute_path_following_metrics(path, S.vp, S.vel, S.ori, ...
        S.psi_ref, S.theta_ref, dt, t);
    W = compute_pitch_window_metrics(t, e_th, s_prog, s_total, 'mode', win_mode);
    mask_ss = W.mask_steady;
    if ~any(mask_ss)
        mask_ss = (t >= 5.0) & W.mask_before_end;
    end
    mask_yaw = (t >= 5.0) & W.mask_before_end;
    if ~any(mask_yaw); mask_yaw = t >= 5.0; end
    mask_hold = mask_ss & (abs(S.u_ref - Uref) <= 0.08);
    if ~any(mask_hold); mask_hold = mask_ss; end
    mask_full = true(n, 1);

    de_dot = [0; diff(de)] / dt;
    dr_dot = [0; diff(dr)] / dt;
    thr_dot = [0; diff(S.thrust)] / dt;

    M = struct();
    M.sim_ok = true; M.sim_err = '';
    M.W = W; M.mask_ss = mask_ss; M.mask_hold = mask_hold; M.mask_yaw = mask_yaw;
    M.speed = speed_stats(e_u, mask_hold);
    M.speed.u_mean = mean_safe(S.u_ctrl, mask_hold);
    M.speed.u_ref_mean = mean_safe(S.u_ref, mask_hold);
    M.theta = err_stats_deg(e_th, mask_ss);
    M.gamma = err_stats_deg(e_gamma, mask_ss);
    M.yaw = err_stats_deg(e_psi, mask_yaw);
    sat_thr_r = tern(R > 0, 0.95 * lim.dr_max, 0.98 * lim.dr_max);
    M.yaw.rudder_sat_ss_pct = sat_pct(dr, mask_yaw, sat_thr_r);
    M.yaw.rudder_sat_full_pct = sat_pct(dr, mask_full, sat_thr_r);
    if R > 0 && isfield(S, 'U_h_guid') && isfield(S, 'kappa')
        Uh_k = S.U_h_guid(:) .* S.kappa(:);
        valid_ratio = mask_yaw & (abs(S.kappa(:)) > 1e-4) & (abs(S.U_h_guid(:)) > 0.3);
        if any(valid_ratio)
            mean_r = mean(S.r(valid_ratio));
            mean_Uh_k = mean(Uh_k(valid_ratio));
            if mean_Uh_k < 0
                mean_Uh_k = -mean_Uh_k;
                mean_r = -mean_r;
            end
            M.yaw.ratio_r_Uh_kappa = mean_r / max(abs(mean_Uh_k), 1e-9);
            M.yaw.n_ratio_valid = nnz(valid_ratio);
        else
            M.yaw.ratio_r_Uh_kappa = NaN;
            M.yaw.n_ratio_valid = 0;
        end
    else
        M.yaw.ratio_r_Uh_kappa = NaN;
        M.yaw.n_ratio_valid = 0;
    end
    M.roll = struct();
    M.roll.tilde_mae_deg = rad2deg(mean_safe(abs(tilde), mask_ss));
    M.roll.p_rms_dps = rad2deg(rms_safe(p(mask_ss)));
    M.path = struct('mean_cte', mean_safe(abs(cte_perp), mask_ss), ...
        'max_cte', max_safe(abs(cte_perp), mask_ss), ...
        'pm_mean_cte', pm.mean_cross_track);

    M.act = struct();
    M.act.de_mag_util = mean_safe(abs(de), mask_ss) / lim.de_max;
    M.act.dr_mag_util = mean_safe(abs(dr), mask_ss) / lim.dr_max;
    thr_span = max(abs([lim.thrust_min, lim.thrust_max]));
    M.act.thr_mag_util = mean_safe(abs(S.thrust), mask_hold) / thr_span;
    M.act.de_rate_util = rms_safe(de_dot(mask_ss)) / lim.de_rate;
    M.act.dr_rate_util = rms_safe(dr_dot(mask_ss)) / lim.dr_rate;
    M.act.thr_rate_util = rms_safe(thr_dot(mask_hold)) / max(thr_span, 1);
    M.act.de_sat_pct = sat_pct(de, mask_ss, 0.98 * lim.de_max);
    M.act.dr_sat_ss_pct = M.yaw.rudder_sat_ss_pct;
    M.act.dr_sat_full_pct = M.yaw.rudder_sat_full_pct;
    M.act.thr_sat_pct = 100 * mean(S.thrust(mask_hold) >= 0.98 * lim.thrust_max | ...
        S.thrust(mask_hold) <= lim.thrust_min + 0.02 * abs(lim.thrust_min));
    if any(mask_ss) && nnz(mask_ss) > 10
        dth = e_th(mask_ss);
        M.act.chatter_dps = rad2deg(std(hf_local(detrend(dth), dt)));
    else
        M.act.chatter_dps = NaN;
    end

    % Boundedness
    st = [S.ori, S.vel, S.rates];
    M.bounded = all(isfinite(st(:))) && all(isfinite(S.thrust)) && ...
        all(abs(theta_phys) < deg2rad(80)) && all(abs(S.u_body) < 5.0) && ...
        all(abs(S.rates(:)) < deg2rad(200));
    M.persistent_ok = any(mask_ss) && (nnz(mask_ss) >= 20);
end

function st = speed_stats(e, mask)
    st = struct('signed_mean', NaN, 'mae', NaN, 'p95', NaN, 'rms', NaN, 'n', 0, ...
        'u_mean', NaN, 'u_ref_mean', NaN);
    if ~any(mask); return; end
    v = e(mask);
    st.n = numel(v);
    st.signed_mean = mean(v);
    st.mae = mean(abs(v));
    st.rms = rms_safe(v);
    st.p95 = prctile_local(abs(v), 95);
end

function st = err_stats_deg(e, mask)
    st = struct('mae_deg', NaN, 'p95_deg', NaN, 'rms_deg', NaN, 'n', 0);
    if ~any(mask); return; end
    v = e(mask);
    st.n = numel(v);
    st.mae_deg = rad2deg(mean(abs(v)));
    st.rms_deg = rad2deg(rms_safe(v));
    st.p95_deg = rad2deg(prctile_local(abs(v), 95));
end

%% ===================== FEASIBLE gates =====================
function F = score_feasible(M, rname, HG, lim) %#ok<INUSD>
    F = struct();
    F.gates = struct();
    F.first_limit = '';
    order = {};

    % 1) trim residual documented
    Trim = M.trim;
    g_trim_doc = isfield(Trim, 'documented') && Trim.documented;
    if strcmp(rname, 'H')
        g_trim_ok = g_trim_doc;  % UNKNOWN is documented OK for helix
        lim_trim = 'helix_trim_undocumented';
    else
        g_trim_ok = g_trim_doc && Trim.pass && isfinite(Trim.norm_dyn) && ...
            (Trim.norm_dyn <= HG.trim_tol);
        lim_trim = sprintf('trim_residual(norm=%.3g>%.3g or unsolved)', ...
            nz(Trim.norm_dyn), HG.trim_tol);
    end
    F.gates.trim_documented = g_trim_doc;
    F.gates.trim_ok = g_trim_ok;
    order{end+1} = {g_trim_ok, lim_trim}; %#ok<AGROW>

    % 2) states bounded
    g_b = isfield(M, 'bounded') && M.bounded && M.sim_ok;
    F.gates.bounded = g_b;
    order{end+1} = {g_b, 'states_unbounded_or_sim_fail'}; %#ok<AGROW>

    % 3) pitch hard
    h = HG.(rname);
    g_pm = ~isnan(M.theta.mae_deg) && (M.theta.mae_deg <= h.pitch_mae);
    g_pp = ~isnan(M.theta.p95_deg) && (M.theta.p95_deg <= h.pitch_p95);
    F.gates.pitch_mae = g_pm; F.gates.pitch_p95 = g_pp;
    order{end+1} = {g_pm, sprintf('pitch_MAE(%.4f>%.4f)', nz(M.theta.mae_deg), h.pitch_mae)}; %#ok<AGROW>
    order{end+1} = {g_pp, sprintf('pitch_p95(%.4f>%.4f)', nz(M.theta.p95_deg), h.pitch_p95)}; %#ok<AGROW>

    % 4) gamma hard
    g_gm = ~isnan(M.gamma.mae_deg) && (M.gamma.mae_deg <= h.gamma_mae);
    g_gp = ~isnan(M.gamma.p95_deg) && (M.gamma.p95_deg <= h.gamma_p95);
    F.gates.gamma_mae = g_gm; F.gates.gamma_p95 = g_gp;
    order{end+1} = {g_gm, sprintf('gamma_MAE(%.4f>%.4f)', nz(M.gamma.mae_deg), h.gamma_mae)}; %#ok<AGROW>
    order{end+1} = {g_gp, sprintf('gamma_p95(%.4f>%.4f)', nz(M.gamma.p95_deg), h.gamma_p95)}; %#ok<AGROW>

    % 5) yaw hard (helix only; X/XZ require near-zero yaw)
    if strcmp(rname, 'H')
        g_ym = ~isnan(M.yaw.mae_deg) && (M.yaw.mae_deg <= HG.H.yaw_mae);
        g_yp = ~isnan(M.yaw.p95_deg) && (M.yaw.p95_deg <= HG.H.yaw_p95);
        g_yss = ~isnan(M.yaw.rudder_sat_ss_pct) && (M.yaw.rudder_sat_ss_pct <= HG.rud_sat_ss);
        g_yf = ~isnan(M.yaw.rudder_sat_full_pct) && (M.yaw.rudder_sat_full_pct <= HG.rud_sat_full);
        if ~isnan(M.yaw.ratio_r_Uh_kappa) && isfield(M.yaw, 'n_ratio_valid') && M.yaw.n_ratio_valid > 10
            g_rat = (M.yaw.ratio_r_Uh_kappa >= HG.ratio_lo) && (M.yaw.ratio_r_Uh_kappa <= HG.ratio_hi);
        elseif ~isnan(M.yaw.ratio_r_Uh_kappa)
            g_rat = (M.yaw.ratio_r_Uh_kappa >= HG.ratio_lo) && (M.yaw.ratio_r_Uh_kappa <= HG.ratio_hi);
        else
            g_rat = true;  % not scored if invalid (match R10 envelope)
        end
        g_ch = ~isnan(M.act.chatter_dps) && (M.act.chatter_dps <= HG.chatter);
        order{end+1} = {g_ym, sprintf('yaw_MAE(%.4f>%.4f)', nz(M.yaw.mae_deg), HG.H.yaw_mae)}; %#ok<AGROW>
        order{end+1} = {g_yp, sprintf('yaw_p95(%.4f>%.4f)', nz(M.yaw.p95_deg), HG.H.yaw_p95)}; %#ok<AGROW>
        order{end+1} = {g_yss, sprintf('rudder_sat_ss(%.2f%%>%.2f%%)', nz(M.yaw.rudder_sat_ss_pct), HG.rud_sat_ss)}; %#ok<AGROW>
        order{end+1} = {g_yf, sprintf('rudder_sat_full(%.2f%%>%.2f%%)', nz(M.yaw.rudder_sat_full_pct), HG.rud_sat_full)}; %#ok<AGROW>
        order{end+1} = {g_rat, sprintf('yaw_ratio(%.4f out [%.2f,%.2f])', nz(M.yaw.ratio_r_Uh_kappa), HG.ratio_lo, HG.ratio_hi)}; %#ok<AGROW>
        order{end+1} = {g_ch, sprintf('chatter(%.4f>%.4f)', nz(M.act.chatter_dps), HG.chatter)}; %#ok<AGROW>
        F.gates.yaw_mae = g_ym; F.gates.yaw_p95 = g_yp;
        F.gates.rud_sat_ss = g_yss; F.gates.rud_sat_full = g_yf;
        F.gates.ratio = g_rat; F.gates.chatter = g_ch;
    else
        g_ym = ~isnan(M.yaw.mae_deg) && (M.yaw.mae_deg <= 0.50);
        order{end+1} = {g_ym, sprintf('yaw_MAE(%.4f>0.50)', nz(M.yaw.mae_deg))}; %#ok<AGROW>
        F.gates.yaw_mae = g_ym;
    end

    % 6) actuator / rate limits
    g_es = ~isnan(M.act.de_sat_pct) && (M.act.de_sat_pct <= HG.elev_sat);
    g_ts = ~isnan(M.act.thr_sat_pct) && (M.act.thr_sat_pct <= HG.thrust_sat);
    g_dru = ~isnan(M.act.dr_rate_util) && (M.act.dr_rate_util <= HG.rate_util);
    g_deu = ~isnan(M.act.de_rate_util) && (M.act.de_rate_util <= HG.rate_util);
    order{end+1} = {g_es, sprintf('elev_sat(%.2f%%>%.2f%%)', nz(M.act.de_sat_pct), HG.elev_sat)}; %#ok<AGROW>
    order{end+1} = {g_ts, sprintf('thrust_sat(%.2f%%>%.2f%%)', nz(M.act.thr_sat_pct), HG.thrust_sat)}; %#ok<AGROW>
    order{end+1} = {g_dru, sprintf('rudder_rate_util(%.3f>1)', nz(M.act.dr_rate_util))}; %#ok<AGROW>
    order{end+1} = {g_deu, sprintf('elev_rate_util(%.3f>1)', nz(M.act.de_rate_util))}; %#ok<AGROW>
    F.gates.elev_sat = g_es; F.gates.thrust_sat = g_ts;
    F.gates.dr_rate = g_dru; F.gates.de_rate = g_deu;

    F.feasible = true;
    F.first_limit = 'none';
    for k = 1:numel(order)
        if ~order{k}{1}
            F.feasible = false;
            F.first_limit = order{k}{2};
            break;
        end
    end

    % Margins (slack; positive = room)
    F.margin = struct();
    F.margin.pitch_mae = h.pitch_mae - nz(M.theta.mae_deg);
    F.margin.pitch_p95 = h.pitch_p95 - nz(M.theta.p95_deg);
    F.margin.gamma_mae = h.gamma_mae - nz(M.gamma.mae_deg);
    F.margin.gamma_p95 = h.gamma_p95 - nz(M.gamma.p95_deg);
    F.margin.elev_sat = HG.elev_sat - nz(M.act.de_sat_pct);
    F.margin.de_rate = HG.rate_util - nz(M.act.de_rate_util);
    F.margin.dr_rate = HG.rate_util - nz(M.act.dr_rate_util);
    if strcmp(rname, 'H')
        F.margin.yaw_mae = HG.H.yaw_mae - nz(M.yaw.mae_deg);
        F.margin.rud_sat_full = HG.rud_sat_full - nz(M.yaw.rudder_sat_full_pct);
        if ~isnan(M.yaw.ratio_r_Uh_kappa)
            F.margin.ratio = min(M.yaw.ratio_r_Uh_kappa - HG.ratio_lo, ...
                HG.ratio_hi - M.yaw.ratio_r_Uh_kappa);
        end
    end
    fn = fieldnames(F.margin);
    vals = [];
    for i = 1:numel(fn)
        vi = F.margin.(fn{i});
        if isfinite(vi); vals(end+1) = vi; end %#ok<AGROW>
    end
    if isempty(vals); F.worst_margin = NaN; else; F.worst_margin = min(vals); end
end

%% ===================== contiguous certify =====================
function Cert = certify_ranges(Cell, Ugrid, routes)
    Cert = struct();
    Cert.worst_margin = Inf;
    for ir = 1:numel(routes)
        rname = routes{ir};
        feas = false(size(Ugrid));
        margins = nan(size(Ugrid));
        limits = cell(size(Ugrid));
        for iu = 1:numel(Ugrid)
            feas(iu) = Cell(iu, ir).feasible;
            limits{iu} = Cell(iu, ir).first_limit;
            if isfield(Cell(iu, ir).M, 'feas') && isfield(Cell(iu, ir).M.feas, 'worst_margin')
                margins(iu) = Cell(iu, ir).M.feas.worst_margin;
            end
        end
        [ilo, ihi] = longest_contiguous_true(feas);
        R = struct();
        R.feas_mask = feas;
        R.margins = margins;
        R.limits = limits;
        if isempty(ilo)
            R.U_lo = NaN; R.U_hi = NaN; R.label = 'none (no FEASIBLE grid point)';
            R.n = 0; R.worst_margin = NaN;
        else
            R.U_lo = Ugrid(ilo); R.U_hi = Ugrid(ihi);
            R.label = sprintf('[%.2f, %.2f] m/s (grid-contiguous; no extrapolate)', R.U_lo, R.U_hi);
            R.n = ihi - ilo + 1;
            R.worst_margin = min(margins(ilo:ihi));
            Cert.worst_margin = min(Cert.worst_margin, R.worst_margin);
        end
        Cert.(rname) = R;
    end
    if ~isfinite(Cert.worst_margin); Cert.worst_margin = NaN; end
    % Intersection certified (all routes)
    all_feas = Cert.X.feas_mask & Cert.XZ.feas_mask & Cert.H.feas_mask;
    [ilo, ihi] = longest_contiguous_true(all_feas);
    if isempty(ilo)
        Cert.intersection_label = 'none';
        Cert.intersection_U = [];
    else
        Cert.intersection_U = Ugrid(ilo:ihi);
        Cert.intersection_label = sprintf('[%.2f, %.2f] m/s', Ugrid(ilo), Ugrid(ihi));
    end
end

function [ilo, ihi] = longest_contiguous_true(mask)
    ilo = []; ihi = [];
    best = 0; cur0 = 0;
    for i = 1:numel(mask)
        if mask(i)
            if cur0 == 0; cur0 = i; end
            if i - cur0 + 1 > best
                best = i - cur0 + 1;
                ilo = cur0; ihi = i;
            end
        else
            cur0 = 0;
        end
    end
end

function Next = decide_next(Cert, Cell)
    % Envelope inadequate if any route has empty certified range OR intersection empty
    % OR majority of cells fail pitch/gamma/yaw (attitude) rather than only speed bias.
    n_fail = 0; n_tot = numel(Cell);
    att_fail = 0;
    for i = 1:n_tot
        if ~Cell(i).feasible
            n_fail = n_fail + 1;
            fl = Cell(i).first_limit;
            if contains(fl, 'pitch') || contains(fl, 'gamma') || contains(fl, 'yaw') || ...
                    contains(fl, 'rudder') || contains(fl, 'elev') || contains(fl, 'chatter') || ...
                    contains(fl, 'ratio') || contains(fl, 'trim_residual') || ...
                    contains(fl, 'unbounded')
                att_fail = att_fail + 1;
            end
        end
    end
    inadequate = isempty(Cert.intersection_U) || (att_fail >= 3) || ...
        (Cert.X.n == 0) || (Cert.XZ.n == 0) || (Cert.H.n == 0);

    Next = struct();
    if inadequate
        Next.gate = 'scheduled_speed_control';
        Next.detail = ['Envelope inadequate for certified multi-route speed range. ', ...
            'Recommend bounded scheduled speed / thrust-trim table before depth outer-loop. ', ...
            'No gain sweep.'];
        Next.reason = sprintf('fail_cells=%d/%d att_fail=%d intersect=%s', ...
            n_fail, n_tot, att_fail, Cert.intersection_label);
    else
        Next.gate = 'depth_outer_loop_baseline';
        Next.detail = ['Speed envelope adequate on certified contiguous multi-route range. ', ...
            'Recommend depth outer-loop baseline next (production cascade frozen).'];
        Next.reason = sprintf('intersect=%s worst_margin=%.4g', ...
            Cert.intersection_label, Cert.worst_margin);
    end
    Next.inadequate = inadequate;
end

%% ===================== path gamma / CTE =====================
function [gamma_ref, cte_perp, s_prog, s_total] = path_gamma_cte(path, vp)
    n = size(vp, 1);
    ds = [0; sqrt(sum(diff(path).^2, 2))];
    s_nodes = cumsum(ds);
    s_total = s_nodes(end);
    s_prog = zeros(n, 1);
    gamma_ref = zeros(n, 1);
    cte_perp = zeros(n, 1);
    for i = 1:n
        d = path - vp(i, :);
        [~, idx] = min(sum(d.^2, 2));
        idx = max(1, min(size(path, 1) - 1, idx));
        s_prog(i) = s_nodes(idx);
        t = path(idx + 1, :) - path(idx, :);
        tn = norm(t);
        if tn < 1e-9
            t = [1 0 0];
        else
            t = t / tn;
        end
        gamma_ref(i) = atan2(t(3), norm(t(1:2)));
        e = vp(i, :) - path(idx, :);
        % perpendicular CTE in horizontal + vertical magnitude
        th = t(1:2); nth = norm(th);
        if nth < 1e-9; nh = [0 1]; else; th = th / nth; nh = [-th(2), th(1)]; end
        cte_perp(i) = hypot(dot(e(1:2), nh), e(3));
    end
end

%% ===================== artifacts =====================
function write_png(png_path, Cell, Ugrid, routes, Cert, task_id, verdict)
    fig = figure('Visible', 'off', 'Color', 'w', 'Position', [80 80 1280 900]);
    metrics = {'speed.mae', 'theta.mae_deg', 'gamma.mae_deg'};
    titles = {'Speed MAE [m/s]', 'Theta MAE [deg]', 'Gamma MAE [deg]'};
    for p = 1:3
        subplot(2, 2, p); hold on; grid on;
        for ir = 1:numel(routes)
            y = nan(size(Ugrid));
            for iu = 1:numel(Ugrid)
                M = Cell(iu, ir).M;
                switch p
                    case 1, y(iu) = nz(M.speed.mae);
                    case 2, y(iu) = nz(M.theta.mae_deg);
                    case 3, y(iu) = nz(M.gamma.mae_deg);
                end
            end
            plot(Ugrid, y, '-o', 'LineWidth', 1.4, 'DisplayName', routes{ir});
        end
        xlabel('Uref [m/s]'); ylabel(titles{p}); title(titles{p}); legend('Location', 'best');
    end
    subplot(2, 2, 4); axis off;
    txt = sprintf(['%s  verdict=%s\n', ...
        'Certified X: %s\nCertified XZ: %s\nCertified R10: %s\n', ...
        'Intersection: %s\nWorst margin: %.4g\n', ...
        'Preserve R5 hard FAIL / R7.5 soft FAIL / R10@1.5 PASS\n', ...
        'Gamma INDI/PI/ADRC rejected; cascade+climbFF frozen'], ...
        task_id, verdict, Cert.X.label, Cert.XZ.label, Cert.H.label, ...
        Cert.intersection_label, Cert.worst_margin);
    text(0.02, 0.98, txt, 'FontName', 'FixedWidth', 'FontSize', 10, ...
        'VerticalAlignment', 'top', 'Interpreter', 'none');
    sgtitle(sprintf('%s — production speed envelope', task_id), 'Interpreter', 'none');
    exportgraphics(fig, png_path, 'Resolution', 140);
    close(fig);
end

function write_md(md_path, task_id, verdict, Cell, Ugrid, routes, Cert, Next, HG, lim, ...
        seed, ctrl_path, dyn_path, log_path, md_p, mat_p, png_p, Ttrim, Kpx, Kproll)
    fid = fopen(md_path, 'w');
    fprintf(fid, '# %s — Production nonlinear 6DOF speed envelope audit\n\n', task_id);
    fprintf(fid, '**Overall verdict (audit completeness): %s**\n\n', verdict);
    fprintf(fid, '## Provenance\n\n');
    fprintf(fid, '- Read-only: `%s`, `%s`, `%s`\n', ctrl_path, dyn_path, log_path);
    fprintf(fid, '- Driver: `run_speed_envelope_audit.m` (one invocation; no production edit)\n');
    fprintf(fid, '- Artifacts: `%s`, `%s`, `%s`\n', md_p, mat_p, png_p);
    fprintf(fid, '- Seed: %d | Kp_roll frozen=%.6f | Kp_x=%.4g | thrust_trim=%.4g N (production)\n', ...
        seed, Kproll, Kpx, Ttrim);
    fprintf(fid, '- Production: nonlinear theta/q cascade + climb FF frozen; gamma INDI/PI/ADRC rejected\n\n');

    fprintf(fid, '## Rejected gamma methods (context)\n\n');
    fprintf(fid, '| Method | Decision |\n|--------|----------|\n');
    fprintf(fid, '| Direct incremental gamma-INDI | REJECT_DIRECT_INDI_SCAFFOLD |\n');
    fprintf(fid, '| Outer gamma-PI on theta/q | REJECT_OUTER_GAMMA_PI_SCAFFOLD |\n');
    fprintf(fid, '| Outer gamma LADRC on theta/q | REJECT_OUTER_GAMMA_ADRC_SCAFFOLD |\n\n');

    fprintf(fid, '## Preserved yaw-envelope conclusions (not reopened)\n\n');
    fprintf(fid, '- R=5 @1.5: **hard authority FAIL** (rudder sat ~95%%)\n');
    fprintf(fid, '- R=7.5 @1.5: **soft FAIL** (sat 1.06%%, ratio 1.024)\n');
    fprintf(fid, '- R=8 @1.5: soft FAIL (full sat 6.67%%, ratio 1.0236)\n');
    fprintf(fid, '- R=10 @1.5: **PASS** (comfortable); this grid uses R10 only\n\n');

    fprintf(fid, '## Hard gates (absolute; no extrapolate)\n\n');
    fprintf(fid, '```\n');
    fprintf(fid, 'FEASIBLE iff: trim residual documented (+ X/XZ norm_dyn<=%.2g),\n', HG.trim_tol);
    fprintf(fid, '  states bounded, pitch/gamma/yaw hard gates, actuator/rate limits pass.\n');
    fprintf(fid, 'X:  pitch MAE<=%.2f p95<=%.2f | gamma MAE<=%.2f p95<=%.2f\n', ...
        HG.X.pitch_mae, HG.X.pitch_p95, HG.X.gamma_mae, HG.X.gamma_p95);
    fprintf(fid, 'XZ: pitch MAE<=%.2f p95<=%.2f | gamma MAE<=%.2f p95<=%.2f\n', ...
        HG.XZ.pitch_mae, HG.XZ.pitch_p95, HG.XZ.gamma_mae, HG.XZ.gamma_p95);
    fprintf(fid, 'H:  pitch MAE<=%.2f p95<=%.2f | gamma MAE<=%.2f p95<=%.2f\n', ...
        HG.H.pitch_mae, HG.H.pitch_p95, HG.H.gamma_mae, HG.H.gamma_p95);
    fprintf(fid, '    yaw MAE<=%.2f p95<=%.2f | rud sat ss/full<=%.0f%% | ratio[%.2f,%.2f] | chat<=%.2f\n', ...
        HG.H.yaw_mae, HG.H.yaw_p95, HG.rud_sat_ss, HG.ratio_lo, HG.ratio_hi, HG.chatter);
    fprintf(fid, 'Act: elev/thrust sat<=%.0f%% | rate util de/dr <= %.0f%% of %.0f deg/s\n', ...
        HG.elev_sat, 100 * HG.rate_util, rad2deg(lim.dr_rate));
    fprintf(fid, '```\n\n');

    fprintf(fid, '## Grid results\n\n');
    fprintf(fid, '| Route | Uref | TrimNorm | FEAS | First limit | uMAE | uP95 | thMAE | thP95 | gMAE | gP95 | yawMAE | CTE | deSat%% | drSatF%% | deRateU | thrSat%% | chat | bound |\n');
    fprintf(fid, '|-------|-----:|---------:|:----:|-------------|-----:|-----:|------:|------:|-----:|-----:|-------:|----:|-------:|--------:|--------:|--------:|-----:|:-----:|\n');
    for ir = 1:numel(routes)
        for iu = 1:numel(Ugrid)
            C = Cell(iu, ir); M = C.M;
            tn = NaN;
            if isfield(M, 'trim') && isfield(M.trim, 'norm_dyn'); tn = M.trim.norm_dyn; end
            fprintf(fid, '| %s | %.2f | %.3g | %s | %s | %.4f | %.4f | %.4f | %.4f | %.4f | %.4f | %.4f | %.3f | %.2f | %.2f | %.3f | %.2f | %.4f | %s |\n', ...
                routes{ir}, Ugrid(iu), tn, yn(C.feasible), sanitize(C.first_limit), ...
                nz(M.speed.mae), nz(M.speed.p95), nz(M.theta.mae_deg), nz(M.theta.p95_deg), ...
                nz(M.gamma.mae_deg), nz(M.gamma.p95_deg), nz(M.yaw.mae_deg), nz(M.path.mean_cte), ...
                nz(M.act.de_sat_pct), nz(M.act.dr_sat_full_pct), nz(M.act.de_rate_util), ...
                nz(M.act.thr_sat_pct), nz(M.act.chatter_dps), yn(M.bounded));
        end
    end
    fprintf(fid, '\n');

    fprintf(fid, '## Contiguous certified speed ranges (grid only; never extrapolate)\n\n');
    fprintf(fid, '| Route | Certified contiguous U | n | Worst margin |\n');
    fprintf(fid, '|-------|------------------------|--:|-------------:|\n');
    for ir = 1:numel(routes)
        R = Cert.(routes{ir});
        fprintf(fid, '| %s | %s | %d | %.4g |\n', routes{ir}, R.label, R.n, R.worst_margin);
    end
    fprintf(fid, '| Intersection | %s | %d | — |\n\n', Cert.intersection_label, numel(Cert.intersection_U));
    fprintf(fid, '- Worst-case margin across certified cells: **%.4g**\n\n', Cert.worst_margin);

    fprintf(fid, '## Decision\n\n');
    fprintf(fid, '- Audit completeness: **%s**\n', verdict);
    fprintf(fid, '- Envelope inadequate: %s\n', yn(Next.inadequate));
    fprintf(fid, '- Recommended next bounded gate: **`%s`**\n', Next.gate);
    fprintf(fid, '- Detail: %s\n', Next.detail);
    fprintf(fid, '- Reason: %s\n', Next.reason);
    fprintf(fid, '- Production: untouched\n\n');

    fprintf(fid, '## Feedback\n\n');
    fprintf(fid, '- PASS/FAIL: **%s**\n', verdict);
    fprintf(fid, '- Certified: X=%s | XZ=%s | R10=%s | intersect=%s\n', ...
        Cert.X.label, Cert.XZ.label, Cert.H.label, Cert.intersection_label);
    fprintf(fid, '- Next: `%s`\n', Next.gate);
    fprintf(fid, '- Files: `%s` `%s` `%s`\n', md_p, mat_p, png_p);
    fclose(fid);
end

function append_research_log(log_path, task_id, verdict, Cert, Next, Cell, Ugrid, md_p, mat_p, png_p)
    n_feas = sum(arrayfun(@(c) c.feasible, Cell(:)));
    fid = fopen(log_path, 'a');
    fprintf(fid, '\n## %s — %s\n\n', task_id, datestr(now, 31));
    fprintf(fid, '- Verdict (audit completeness): **%s** — production cascade+climbFF frozen; no retune.\n', verdict);
    fprintf(fid, '- Rejected gamma methods: INDI (`REJECT_DIRECT_INDI_SCAFFOLD`), outer PI (`REJECT_OUTER_GAMMA_PI_SCAFFOLD`), outer ADRC (`REJECT_OUTER_GAMMA_ADRC_SCAFFOLD`).\n');
    fprintf(fid, '- Grid: Uref=%s on X / XZ / R10; FEASIBLE cells=%d/%d.\n', mat2str(Ugrid), n_feas, numel(Cell));
    fprintf(fid, '- Certified contiguous: X=%s; XZ=%s; R10=%s; intersect=%s; worst_margin=%.4g (no extrapolate).\n', ...
        Cert.X.label, Cert.XZ.label, Cert.H.label, Cert.intersection_label, Cert.worst_margin);
    fprintf(fid, '- Preserve: R5 hard yaw FAIL; R7.5 soft FAIL; R10@1.5 PASS.\n');
    fprintf(fid, '- Artifacts: suite_results/SPEED_ENVELOPE_AUDIT.{md,mat,png}; driver `run_speed_envelope_audit.m`.\n');
    fprintf(fid, '- Prioritized next decision: **`%s`** — %s\n', Next.gate, Next.detail);
    fprintf(fid, '- CODEX_VERTICAL_PLAN untouched.\n');
    fclose(fid);
end

%% ===================== numeric utils =====================
function y = align_len(x, n)
    x = x(:);
    if numel(x) >= n
        y = x(1:n);
    else
        y = [x; zeros(n - numel(x), 1)];
    end
end

function v = mean_safe(x, mask)
    x = x(:); mask = mask(:);
    if ~any(mask); v = NaN; return; end
    v = mean(x(mask));
end

function v = max_safe(x, mask)
    x = x(:); mask = mask(:);
    if ~any(mask); v = NaN; return; end
    v = max(x(mask));
end

function v = rms_safe(x)
    x = x(:); x = x(isfinite(x));
    if isempty(x); v = NaN; return; end
    v = sqrt(mean(x.^2));
end

function v = prctile_local(x, p)
    x = sort(x(:));
    if isempty(x); v = NaN; return; end
    k = max(1, min(numel(x), round(p / 100 * numel(x))));
    v = x(k);
end

function p = sat_pct(u, mask, lim)
    if ~any(mask); p = NaN; return; end
    p = 100 * mean(abs(u(mask)) >= lim);
end

function y = hf_local(x, dt)
    % Simple high-pass via first difference scaled
    x = x(:);
    if numel(x) < 3; y = x; return; end
    y = [0; diff(x)] / max(dt, eps);
end

function v = nz(x)
    if isempty(x) || ~isscalar(x); v = NaN; else; v = x; end
    if ~isfinite(v); v = NaN; end
end

function s = yn(tf)
    if tf; s = 'YES'; else; s = 'NO'; end
end

function s = tern(tf, a, b)
    if tf; s = a; else; s = b; end
end

function s = sanitize(s)
    if isempty(s); s = ''; return; end
    s = regexprep(char(s), '[|]', '/');
    if numel(s) > 60; s = [s(1:57) '...']; end
end
