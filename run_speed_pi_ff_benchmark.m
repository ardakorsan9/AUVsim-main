function run_speed_pi_ff_benchmark()
% SPEED_PI_FF_BENCHMARK_001 — isolated speed-ref quadratic-drag FF + AW-PI
% Read-only evidence: THRUST_TRIM_U15_AUDIT.mat, SPEED_BASELINE_AUDIT.mat,
% controller_law.m. Linearize surge at exact level/XZ u=1.5 trims in-driver.
% One Ki from documented 2nd-order pole target (no sweep). Production untouched.
% Artifacts: suite_results/SPEED_PI_FF_BENCHMARK.{md,mat,png}; append audit.

    project_dir = fileparts(mfilename('fullpath'));
    addpath(project_dir);
    out_dir = fullfile(project_dir, 'suite_results');
    if ~exist(out_dir, 'dir'); mkdir(out_dir); end
    tag = 'SPEED_PI_FF_BENCHMARK';
    task_id = 'SPEED_PI_FF_BENCHMARK_001';

    thrust_path = fullfile(out_dir, 'THRUST_TRIM_U15_AUDIT.mat');
    speed_path  = fullfile(out_dir, 'SPEED_BASELINE_AUDIT.mat');
    ctrl_path   = fullfile(project_dir, 'controller_law.m');
    assert(exist(thrust_path, 'file') == 2, 'Missing %s', thrust_path);
    assert(exist(speed_path, 'file') == 2, 'Missing %s', speed_path);
    assert(exist(ctrl_path, 'file') == 2, 'Missing %s', ctrl_path);

    Trim = load(thrust_path);
    Sp   = load(speed_path);
    assert(isfield(Trim, 'level') && isfield(Trim, 'climb'), 'Trim audit missing level/climb');
    assert(isfield(Sp, 'law') && isfield(Sp, 'phi_eq'), 'SPEED baseline missing law/phi_eq');

    ctrl_txt = fileread(ctrl_path);
    assert(contains(ctrl_txt, 'thrust_trim + Kp_x * (u_ref - u)'), ...
        'controller_law thrust law mismatch (expect P-only)');
    assert(~contains(ctrl_txt, 'kD * u_ref'), 'production already has drag FF — abort');

    fprintf('\n========== %s ==========\n', task_id);
    fprintf('Evidence: THRUST_TRIM_U15_AUDIT.mat | SPEED_BASELINE_AUDIT.mat | controller_law.m\n');
    fprintf('Production: untouched | one Ki | no sweep\n');

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
    Kp_roll = Sp.law.Kp_roll;
    desired_speed = 1.5;
    Kp_x = Sp.law.Kp_x;                 % keep 25
    assert(abs(Kp_x - 25) < 1e-9, 'Kp_x must remain 25');

    seed_used = 0;
    rng(seed_used, 'twister');

    Ufix = 1.5;
    Treq_L = Trim.level.Treq;
    Treq_XZ = Trim.climb.Treq;
    assert(abs(Trim.level.x_star(7) - Ufix) < 1e-9, 'level trim u* not 1.5');
    assert(abs(Trim.climb.x_star(7) - Ufix) < 1e-9, 'XZ trim u* not 1.5');

    % ---- Quadratic drag FF from exact LEVEL trim (not XZ; R10 unknown) ----
    kD = Treq_L / (Ufix * Ufix);       % Tff = kD * u_ref * |u_ref|
    assert(abs(kD - 3.8117 / (1.5^2)) < 5e-4, 'kD sanity vs stated 3.8117/1.5^2');

    % ---- Linearize surge channel at exact level + XZ; derive one Ki ----
    design = derive_ki(Trim.level, Trim.climb, Kp_x, Ufix, kD, Treq_L, Treq_XZ);
    Ki = design.Ki;
    Kaw = design.Kaw;

    law = struct();
    law.baseline = 'thrust = sat(thrust_trim + Kp_x*(u_ref_eff - u))';
    law.candidate = ['Tff=kD*u_ref_eff*|u_ref_eff|; ', ...
        'Tunsat=Tff+Kp*(u_ref_eff-u)+I; T=sat(Tunsat); ', ...
        'I+=Ki*e*dt + Kaw*(T-Tunsat)*dt (freeze e-int if sat against e); I(0)=0'];
    law.kD = kD;
    law.Kp = Kp_x;
    law.Ki = Ki;
    law.Kaw = Kaw;
    law.thrust_trim_baseline = thrust_trim;
    law.thrust_max = thrust_max;
    law.thrust_min = thrust_min;
    law.Ufix = Ufix;
    law.Treq_level = Treq_L;
    law.Treq_XZ = Treq_XZ;
    law.Treq_R10 = 'UNKNOWN';
    law.design = design;
    law.Kp_roll = Kp_roll;
    law.frame = 'BODY u; u_ref_eff = actual guidance/controller sample (not hardcoded 1.5)';

    fprintf('kD=%.8f  Kp=%.4g  Ki=%.6f  Kaw=%.6f\n', kD, Kp_x, Ki, Kaw);
    fprintf('Poles target: zeta=1/sqrt(2), wn=(b*Kp-a)/(2*zeta); Ki=wn^2/b; robust=min(L,XZ)\n');
    fprintf('  level: a=%.6g b=%.6g wn=%.5g Ki=%.5g\n', design.level.a, design.level.b, ...
        design.level.wn, design.level.Ki);
    fprintf('  XZ:    a=%.6g b=%.6g wn=%.5g Ki=%.5g\n', design.XZ.a, design.XZ.b, ...
        design.XZ.wn, design.XZ.Ki);

    lim = struct('dr_max', delta_r_max, 'de_max', delta_e_max, ...
        'dr_rate', deg2rad(40), 'near_frac', 0.80, ...
        'thrust_max', thrust_max, 'thrust_min', thrust_min);
    phi_eq = Sp.phi_eq;

    nX = 600; xX = linspace(0, 45, nX)';
    pathX = [xX, zeros(nX, 1), zeros(nX, 1)];
    nXZ = 900; xXZ = linspace(0, 42, nXZ)';
    pathXZ = [xXZ, zeros(nXZ, 1), 0.4 * xXZ];
    pathH = generate_balanced_helical_path(10.0, 2.0, 2, 500);
    nS = 700; xS = linspace(0, 55, nS)';
    pathStep = [xS, zeros(nS, 1), zeros(nS, 1)];
    step_sched = struct('t_edges', [0 8 16 24], 'u_levels', [1.3 1.5 1.3]);

    routes = { ...
        struct('name','X',  'path',pathX,    'T',18, 'u0',Ufix, 'phi',phi_eq.X,  'win','first_hold', 'xz',false, 'R',0,  'sched',[]); ...
        struct('name','XZ', 'path',pathXZ,   'T',22, 'u0',Ufix, 'phi',phi_eq.XZ, 'win','persistent', 'xz',true,  'R',0,  'sched',[]); ...
        struct('name','H',  'path',pathH,    'T',45, 'u0',Ufix, 'phi',phi_eq.H,  'win','persistent', 'xz',false, 'R',10, 'sched',[]); ...
        struct('name','Step','path',pathStep,'T',24, 'u0',1.3,   'phi',0.0,       'win','first_hold', 'xz',false, 'R',0,  'sched',step_sched)};

    % ---- Baseline (production P-only) ----
    fprintf('\n===== BASELINE (production P-only) =====\n');
    B = struct();
    for i = 1:numel(routes)
        r = routes{i};
        fprintf('\n-- BASE %s --\n', r.name);
        rng(seed_used, 'twister');
        [B.(r.name).S, B.(r.name).M] = sim_analyze(r, lim, 'baseline', law);
    end

    % ---- Candidate (FF + AW-PI) ----
    fprintf('\n===== CANDIDATE (Tff + AW-PI) =====\n');
    C = struct();
    for i = 1:numel(routes)
        r = routes{i};
        fprintf('\n-- CAND %s --\n', r.name);
        rng(seed_used, 'twister');
        [C.(r.name).S, C.(r.name).M] = sim_analyze(r, lim, 'candidate', law);
    end

    [G, verdict, next_opt, next_detail] = score_candidate(B, C, law);

    md_path  = fullfile(out_dir, [tag '.md']);
    mat_path = fullfile(out_dir, [tag '.mat']);
    png_path = fullfile(out_dir, [tag '.png']);

    write_png(png_path, B, C, lim, task_id, verdict, law);
    write_md(md_path, task_id, verdict, law, B, C, G, next_opt, next_detail, ...
        seed_used, md_path, mat_path, png_path, thrust_path, speed_path, ctrl_path);
    append_ss_audit(out_dir, task_id, verdict, law, B, C, G, next_opt, next_detail, ...
        md_path, mat_path, png_path);

    Out = struct();
    Out.task_id = task_id;
    Out.verdict = verdict;
    Out.law = law;
    Out.design = design;
    Out.baseline = B;
    Out.candidate = C;
    Out.gates = G;
    Out.next_opt = next_opt;
    Out.next_detail = next_detail;
    Out.phi_eq = phi_eq;
    Out.limits = lim;
    Out.seed_used = seed_used;
    Out.sources = {thrust_path; speed_path; ctrl_path};
    Out.paths = struct('md', md_path, 'mat', mat_path, 'png', png_path);
    Out.production_edited = false;
    Out.note = 'Isolated FF+AW-PI candidate; production controller_law untouched';
    save(mat_path, '-struct', 'Out');

    fprintf('\nVERDICT: %s | next=%s\n', verdict, next_opt);
    fprintf('Saved: %s\n%s\n%s\n', md_path, mat_path, png_path);
    print_feedback(verdict, law, B, C, G, next_opt, next_detail, md_path, mat_path, png_path);
    assignin('base', 'SPEED_PI_FF_BENCHMARK_PASS', strcmp(verdict, 'PASS'));
end

%% ===================== Ki derivation (no sweep) =====================
function D = derive_ki(level, climb, Kp, Ufix, kD, Treq_L, Treq_XZ)
    zeta = 1 / sqrt(2);                 % documented 2nd-order damping target
    L = surge_siso(level);
    X = surge_siso(climb);
    L = place_ki(L, Kp, zeta);
    X = place_ki(X, Kp, zeta);
    % Robust: take min Ki so climb (slightly lower a-margin) is not over-aggressive
    Ki = min(L.Ki, X.Ki);
    Kaw = Ki / max(Kp, eps);            % relative back-calculation [1/s]

    D = struct();
    D.method = ['SISO surge FD at exact u=1.5 level/XZ; ', ...
        'zeta=1/sqrt(2); wn=(b*Kp-a)/(2*zeta); Ki=wn^2/b; robust Ki=min(level,XZ)'];
    D.zeta_target = zeta;
    D.Kp_fixed = Kp;
    D.Ki = Ki;
    D.Kaw = Kaw;
    D.kD = kD;
    D.Ufix = Ufix;
    D.Treq_level = Treq_L;
    D.Treq_XZ = Treq_XZ;
    D.level = L;
    D.XZ = X;
    D.no_sweep = true;
    % Closed-loop poles at chosen Ki for both plants
    D.level.cl_at_Ki = cl_poles(L.a, L.b, Kp, Ki);
    D.XZ.cl_at_Ki = cl_poles(X.a, X.b, Kp, Ki);
end

function S = surge_siso(P)
    x0 = P.x_star(:);
    u0 = struct('delta_r', P.u_star(1), 'delta_e', P.u_star(2), 'thrust', P.u_star(3));
    x_scale = [10; 10; 10; 1; 1; 1; 1.5; 0.3; 0.3; 0.2; 0.2; 0.2];
    u_scale = [deg2rad(25); deg2rad(15); 50];
    eps_rel = 1e-4;
    [A1, B1] = scale_aware_fd(x0, u0, x_scale, u_scale, eps_rel);
    [A2, B2] = scale_aware_fd(x0, u0, x_scale, u_scale, eps_rel / 2);
    S = struct();
    S.name = P.name;
    S.a = A2(7, 7);                     % ∂u̇/∂u
    S.b = B2(7, 3);                     % ∂u̇/∂T
    S.a_eps = A1(7, 7); S.b_eps = B1(7, 3);
    S.dA_rel = abs(A2(7, 7) - A1(7, 7)) / max(abs(A1(7, 7)), eps);
    S.dB_rel = abs(B2(7, 3) - B1(7, 3)) / max(abs(B1(7, 3)), eps);
    S.x_star = x0; S.u_star = P.u_star(:); S.Treq = P.Treq;
    S.jac_ok = (S.dA_rel <= 0.01) && (S.dB_rel <= 0.01) && (S.b > 0);
end

function S = place_ki(S, Kp, zeta)
    alpha = S.b * Kp - S.a;             % = 2*zeta*wn under PI with fixed Kp
    assert(alpha > 0, 'Plant+Kp not stabilizing (b*Kp - a <= 0)');
    S.zeta = zeta;
    S.wn = alpha / (2 * zeta);
    S.Ki = (S.wn * S.wn) / S.b;
    S.alpha = alpha;
    S.Ts_2pct = 4.6 / (zeta * S.wn);
    S.poles_design = cl_poles(S.a, S.b, Kp, S.Ki);
end

function ev = cl_poles(a, b, Kp, Ki)
    Acl = [a - b * Kp, b * Ki; -1, 0];
    ev = eig(Acl);
    [~, ord] = sort(real(ev));
    ev = ev(ord);
end

function [A, B] = scale_aware_fd(x0, u0, x_scale, u_scale, eps_rel)
    n = 12; m = 3;
    A = zeros(n); B = zeros(n, m);
    dx = max(eps_rel * x_scale, 1e-9 * x_scale);
    du = max(eps_rel * u_scale, 1e-9 * u_scale);
    for i = 1:n
        xp = x0; xm = x0;
        xp(i) = xp(i) + dx(i); xm(i) = xm(i) - dx(i);
        A(:, i) = (underwater777_vehicle_dynamics(0, xp, u0) - ...
                   underwater777_vehicle_dynamics(0, xm, u0)) / (2 * dx(i));
    end
    for j = 1:m
        up = u0; um = u0;
        switch j
            case 1
                up.delta_r = up.delta_r + du(j); um.delta_r = um.delta_r - du(j);
            case 2
                up.delta_e = up.delta_e + du(j); um.delta_e = um.delta_e - du(j);
            case 3
                up.thrust = up.thrust + du(j); um.thrust = um.thrust - du(j);
        end
        B(:, j) = (underwater777_vehicle_dynamics(0, x0, up) - ...
                   underwater777_vehicle_dynamics(0, x0, um)) / (2 * du(j));
    end
end

%% ===================== simulate =====================
function [S, M] = sim_analyze(route, lim, mode, law)
    global dt_controller desired_speed lambda_muw_ff

    clear guidance_law controller_law
    clear global last_guidance_U_h last_guidance_kappa last_r_ff
    clear global last_delta_e last_delta_r last_dr_yaw last_dr_p last_dr_damp last_g_ac
    clear global last_int_angle last_int_rate last_de_fb last_de_trim last_de_uw_ff

    dt = dt_controller;
    path = route.path;
    state0 = zeros(12, 1);
    state0(1:3) = path(1, :)';
    d = path(2, :) - path(1, :);
    state0(5) = -atan2(d(3), norm(d(1:2)));
    state0(6) = atan2(d(2), d(1));
    state0(7) = route.u0;

    if route.R > 0
        lambda_muw_ff = 0.25;
    elseif route.xz
        lambda_muw_ff = 0.0;
    else
        lambda_muw_ff = 0.25;
    end
    if isempty(route.sched)
        desired_speed = 1.5;
    else
        desired_speed = route.sched.u_levels(1);
    end

    [S] = sim_loop(path, state0, dt, route.T, route.sched, mode, law);
    S.R = route.R; S.is_xz = route.xz; S.mode = mode; S.name = route.name;
    M = analyze_route(S, path, route.win, route.phi, lim, route.xz, route.sched, mode);
    fprintf('  [%s] uMAE=%.4f uP95=%.4f signed=%.4f thr=%.2f sat=%.2f%% Irms=%.3f pitch=%.4f cte=%.4f\n', ...
        mode, M.speed.steady.mae, M.speed.steady.p95, M.speed.steady.signed_mean, ...
        M.thrust.steady.mean, M.thrust.full.sat_pct, M.I.rms, M.pitch.mae_deg, M.path.mean_cte);
end

function S = sim_loop(path, state, dt, T_final, sched, mode, law)
    init_parameters();
    global dt_controller dt_guidance
    global Kp_x thrust_trim thrust_max thrust_min
    global last_delta_e last_delta_r last_dr_yaw last_dr_p last_dr_damp last_g_ac
    global suite_delta_e_log suite_delta_r_log
    global suite_dr_yaw_log suite_dr_p_log suite_dr_damp_log suite_g_ac_log
    global suite_u_log
    dt_controller = dt;
    if isempty(dt_guidance); dt_guidance = dt; end

    n_steps = round(T_final / dt);
    vp = zeros(n_steps, 3); times = zeros(n_steps, 1);
    vel = zeros(n_steps, 3); rates = zeros(n_steps, 3); ori = zeros(n_steps, 3);
    yaw_refs = zeros(n_steps, 1); pitch_refs = zeros(n_steps, 1);
    u_refs = zeros(n_steps, 1); u_ctrl = zeros(n_steps, 1);
    thrust = zeros(n_steps, 1); Tunsat = zeros(n_steps, 1);
    Tff = zeros(n_steps, 1); Tp = zeros(n_steps, 1); Ti = zeros(n_steps, 1);
    de_log = zeros(n_steps, 1); dr_log = zeros(n_steps, 1);
    dry_log = zeros(n_steps, 1); drp_log = zeros(n_steps, 1);
    drd_log = zeros(n_steps, 1); gac_log = zeros(n_steps, 1);

    % Bumpless: I(0)=0
    I = 0;
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
        if isempty(sched)
            u_ref_eff = u_ref_g;         % actual scheduled uref (R10 cut etc.)
        else
            u_ref_eff = schedule_u(total_time, sched);
        end

        % Attitude from production controller; thrust overridden by mode
        [delta_r, delta_e, thr_prod] = controller_law(yaw_ref, pitch_ref, u_ref_eff, ...
            current_orientation(3), current_orientation(2), current_rates(3), ...
            current_rates(2), current_u, r_ff, pitch_ref_dot, ...
            current_orientation(1), current_w, current_rates(1));

        e = u_ref_eff - current_u;
        if strcmp(mode, 'baseline')
            t_ff = thrust_trim;
            t_p = Kp_x * e;
            t_i = 0;
            t_un = t_ff + t_p;
            thr = max(min(t_un, thrust_max), thrust_min);
            % production identity check (thr_prod should match)
            thr = thr_prod;
            t_un = thr_prod;  % logged unsat ~ applied under P-only (post-sat)
            t_ff = thrust_trim;
            t_p = thr - thrust_trim;
            t_i = 0;
        else
            t_ff = law.kD * u_ref_eff * abs(u_ref_eff);
            t_p = law.Kp * e;
            t_un = t_ff + t_p + I;
            thr = max(min(t_un, thrust_max), thrust_min);
            aw = thr - t_un;
            % Back-calculation + freeze when saturation opposes error
            if abs(aw) > 1e-6 && (sign(e) == -sign(aw) || sign(e) == 0)
                I = I + law.Kaw * aw * dt;          % freeze e-int; bleed via AW
            else
                I = I + law.Ki * e * dt + law.Kaw * aw * dt;
            end
            t_i = I;
        end

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
        u_refs(idx) = u_ref_eff;
        u_ctrl(idx) = current_u;
        thrust(idx) = thr;
        Tunsat(idx) = t_un;
        Tff(idx) = t_ff;
        Tp(idx) = t_p;
        Ti(idx) = t_i;
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
        if mod(idx, 200) == 0 || idx == n_steps
            fprintf('  %s sim %d/%d t=%.2f u=%.3f uref=%.3f thr=%.1f I=%.2f\n', ...
                mode, idx, n_steps, total_time, current_u, u_ref_eff, thr, t_i);
        end
    end

    suite_delta_e_log = de_log;
    suite_delta_r_log = dr_log;
    suite_dr_yaw_log = dry_log;
    suite_dr_p_log = drp_log;
    suite_dr_damp_log = drd_log;
    suite_g_ac_log = gac_log;
    suite_u_log = u_ctrl;

    S = struct();
    S.dt = dt; S.T_final = T_final; S.t = times(:);
    S.vp = vp; S.vel = vel; S.rates = rates; S.ori = ori;
    S.psi_ref = yaw_refs(:); S.theta_ref = pitch_refs(:);
    S.u_ref = u_refs(:);                 % u_ref_eff per sample
    S.u_ctrl = u_ctrl(:);
    S.u_body = vel(:, 1);
    S.v_body = vel(:, 2); S.w_body = vel(:, 3);
    [S.Uh, S.Vtot] = speeds_from_state(ori, vel);
    S.thrust = thrust(:);
    S.thrust_unsat = Tunsat(:);
    S.Tff = Tff(:); S.Tp = Tp(:); S.Ti = Ti(:);
    S.delta_e = de_log(:); S.delta_r = dr_log(:);
    S.dr_yaw = dry_log(:); S.dr_p = drp_log(:);
    S.dr_damp = drd_log(:); S.g_ac = gac_log(:);
    S.step_sched = sched;
end

function u = schedule_u(t, sched)
    edges = sched.t_edges(:); levels = sched.u_levels(:);
    u = levels(end);
    for k = 1:numel(levels)
        if t < edges(k + 1)
            u = levels(k); return;
        end
    end
end

function [Uh, Vtot] = speeds_from_state(ori, vel)
    n = size(vel, 1); Uh = zeros(n, 1); Vtot = zeros(n, 1);
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
         -sin(theta), cos(theta)*sin(phi), cos(theta)*cos(phi)];
    pos_dot = R * [u; v; w];
    U_h = hypot(pos_dot(1), pos_dot(2));
    zdot = pos_dot(3);
end

%% ===================== metrics =====================
function M = analyze_route(S, path, win_mode, phi_eq, lim, is_xz, step_sched, mode)
    t = S.t(:); dt = S.dt;
    phi = S.ori(:, 1); theta_phys = -S.ori(:, 2); psi = S.ori(:, 3);
    p = S.rates(:, 1); dr = S.delta_r(:); de = S.delta_e(:);
    e_psi = wrapToPi(S.psi_ref(:) - psi);
    e_th = S.theta_ref(:) - theta_phys;
    tilde = phi - phi_eq;
    e_u = S.u_ref - S.u_ctrl;
    e_Uh = S.u_ref - S.Uh;
    e_V = S.u_ref - S.Vtot;

    pm = compute_path_following_metrics(path, S.vp, S.vel, S.ori, ...
        S.psi_ref, S.theta_ref, dt, t);
    s = pm.s_prog(:); s_total = pm.s_total;
    W = compute_pitch_window_metrics(t, e_th, s, s_total, 'mode', win_mode);
    mask_ss = W.mask_steady;
    if ~any(mask_ss); mask_ss = (t >= 5.0) & W.mask_before_end; end
    mask_yaw = (t >= 5.0) & W.mask_before_end;
    if ~any(mask_yaw); mask_yaw = t >= 5.0; end
    mask_acq = W.mask_acq;
    if ~any(mask_acq); mask_acq = (t < 5.0) & W.mask_before_end; end

    if isempty(step_sched)
        Udes = 1.5;
        mask_hold = mask_ss & (abs(S.u_ref - Udes) <= 0.08);
        if ~any(mask_hold); mask_hold = mask_ss; end
    else
        mask_hold = (t >= 8.0) & (t < 16.0);
        mask_ss = mask_hold;
        mask_acq = ((t >= 8.0) & (t < 14.0)) | ((t >= 16.0) & (t < 22.0));
    end

    M = struct();
    M.mode = mode; M.win_mode = win_mode; M.is_xz = is_xz;
    M.phi_eq_rad = phi_eq; M.W = W;
    M.mask_ss = mask_ss; M.mask_hold = mask_hold; M.mask_acq = mask_acq;
    M.pitch = err_stats_deg(e_th, mask_ss);
    M.pitch.elev_sat_pct = sat_pct(de, mask_ss, 0.98 * lim.de_max);
    M.yaw = err_stats_deg(e_psi, mask_yaw);
    M.tilde = err_stats_deg(tilde, mask_ss);
    M.phi = err_stats_deg(phi, mask_ss);
    M.p = err_stats_deg(p, mask_ss);
    M.p.rms_dps = M.p.rms_deg;
    M.path = struct('mean_cte', pm.mean_cross_track, 'max_cte', pm.max_cross_track);
    if isfield(pm, 'CTE_perp_settled_before_end') && isfield(pm.CTE_perp_settled_before_end, 'rms')
        M.path.rms_cte = pm.CTE_perp_settled_before_end.rms;
    else
        M.path.rms_cte = M.path.mean_cte;
    end

    M.speed = struct();
    M.speed.frame = 'BODY_u_vs_u_ref_eff';
    M.speed.acq = speed_stats(e_u, mask_acq);
    M.speed.steady = speed_stats(e_u, mask_hold);
    M.speed.Uh_steady = speed_stats(e_Uh, mask_hold);
    M.speed.Vtot_steady = speed_stats(e_V, mask_hold);
    M.speed.u_mean = mean_safe(S.u_ctrl, mask_hold);
    M.speed.u_ref_mean = mean_safe(S.u_ref, mask_hold);
    M.speed.Uh_mean = mean_safe(S.Uh, mask_hold);
    M.speed.Vtot_mean = mean_safe(S.Vtot, mask_hold);
    if ~isempty(step_sched)
        M.speed.step = step_metrics(S, step_sched, 0.05);
    else
        M.speed.step = struct();
    end

    thr_dot = [0; diff(S.thrust)] / dt;
    M.thrust = struct();
    M.thrust.steady = thrust_stats(S, thr_dot, mask_hold, lim);
    M.thrust.full = thrust_stats(S, thr_dot, true(size(S.thrust)), lim);
    M.thrust.acq = thrust_stats(S, thr_dot, mask_acq, lim);

    I = S.Ti(:);
    Idot = [0; diff(I)] / dt;
    M.I = struct();
    M.I.mean = mean_safe(I, mask_hold);
    M.I.rms = rms_safe(I, mask_hold);
    M.I.max_abs = max_abs_safe(I, true(size(I)));
    M.I.rate_rms = rms_safe(Idot, mask_hold);
    M.I.chatter = false;
    if any(mask_hold)
        % chatter: high-rate sign flips of I-dot while |I| large
        idh = Idot(mask_hold);
        flips = sum(idh(1:end-1) .* idh(2:end) < 0);
        flip_rate = flips / max(sum(mask_hold) - 1, 1);
        M.I.flip_rate = flip_rate;
        M.I.chatter = (flip_rate > 0.35) && (M.I.rate_rms > 5.0);
    else
        M.I.flip_rate = NaN;
    end
    M.I.windup = (M.I.max_abs > 0.9 * lim.thrust_max) || ...
        (M.thrust.full.sat_pct > 1.0 && abs(M.I.mean) > 20);
end

function st = thrust_stats(S, tdot, mask, lim)
    st = struct('mean', NaN, 'rms', NaN, 'rate_rms', NaN, 'near_pct', NaN, ...
        'sat_pct', NaN, 'Tff_mean', NaN, 'Tp_mean', NaN, 'Ti_mean', NaN, ...
        'unsat_mean', NaN, 'n', 0);
    if ~any(mask); return; end
    v = S.thrust(mask); vd = tdot(mask);
    st.n = numel(v);
    st.mean = mean(v); st.rms = rms_local(v); st.rate_rms = rms_local(vd);
    st.near_pct = 100 * mean(abs(v) >= 0.80 * lim.thrust_max);
    st.sat_pct = 100 * mean((v >= 0.98 * lim.thrust_max) | ...
        (v <= lim.thrust_min + 0.02 * abs(lim.thrust_min)));
    st.Tff_mean = mean(S.Tff(mask));
    st.Tp_mean = mean(S.Tp(mask));
    st.Ti_mean = mean(S.Ti(mask));
    st.unsat_mean = mean(S.thrust_unsat(mask));
end

function st = speed_stats(e, mask)
    st = struct('signed_mean', NaN, 'mae', NaN, 'rms', NaN, 'p95', NaN, 'max', NaN, 'n', 0);
    if ~any(mask); return; end
    v = e(mask); st.n = numel(v);
    st.signed_mean = mean(v); st.mae = mean(abs(v)); st.rms = rms_local(v);
    st.p95 = prctile_local(abs(v), 95); st.max = max(abs(v));
end

function st = step_metrics(S, sched, band)
    t = S.t(:); u = S.u_ctrl(:); uref = S.u_ref(:); e = uref - u;
    edges = sched.t_edges(:); levels = sched.u_levels(:);
    st = struct(); st.band = band;
    st.legs = struct('t0', {}, 't1', {}, 'uref', {}, 'settle_s', {}, ...
        'persistent_ok', {}, 'overshoot_pct', {}, 'lag_s', {}, 'pass', {}, ...
        'mae', {}, 'signed', {});
    for k = 1:numel(levels)
        t0 = edges(k); t1 = edges(k + 1);
        m = (t >= t0) & (t < t1);
        uref_k = levels(k);
        settle_s = NaN; ok = false;
        idx = find(m);
        for ii = 1:numel(idx)
            j = idx(ii);
            if all(abs(e(j:idx(end))) <= band)
                settle_s = t(j) - t0; ok = true; break;
            end
        end
        if k == 1
            step_amp = 0;
        else
            step_amp = uref_k - levels(k - 1);
        end
        if abs(step_amp) < 1e-9
            os_pct = 0;
        else
            if step_amp > 0
                os = max(0, max(u(m)) - uref_k);
            else
                os = max(0, uref_k - min(u(m)));
            end
            os_pct = 100 * os / abs(step_amp);
        end
        lag_s = NaN;
        for ii = 1:numel(idx)
            if abs(e(idx(ii))) <= band
                lag_s = t(idx(ii)) - t0; break;
            end
        end
        pass_k = ok && (settle_s <= 6.0) && (os_pct <= 10.0);
        st.legs(k).t0 = t0; st.legs(k).t1 = t1; st.legs(k).uref = uref_k;
        st.legs(k).settle_s = settle_s; st.legs(k).persistent_ok = ok;
        st.legs(k).overshoot_pct = os_pct; st.legs(k).lag_s = lag_s;
        st.legs(k).pass = pass_k;
        st.legs(k).mae = mean(abs(e(m))); st.legs(k).signed = mean(e(m));
    end
    st.pass = all([st.legs.pass]);
    st.worst_settle_s = max([st.legs.settle_s]);
    st.worst_os_pct = max([st.legs.overshoot_pct]);
end

%% ===================== gates =====================
function [G, verdict, next_opt, next_detail] = score_candidate(B, C, law)
    G = struct();
    names = {'X', 'XZ', 'H'};
    G.pref = struct(); G.hard = struct(); G.sat = struct(); G.reg = struct();
    for i = 1:3
        nm = names{i};
        Mb = B.(nm).M; Mc = C.(nm).M;
        G.pref.(nm) = (Mc.speed.steady.mae <= 0.03) && (Mc.speed.steady.p95 <= 0.05);
        G.hard.(nm) = (Mc.speed.steady.mae <= 0.07) && (Mc.speed.steady.p95 <= 0.10);
        G.sat.(nm) = Mc.thrust.full.sat_pct <= 1.0;
        G.near.(nm) = Mc.thrust.full.near_pct <= 5.0;
        G.rate_ok.(nm) = Mc.thrust.full.rate_rms <= 50.0;  % N/s reasonable
        G.I_ok.(nm) = ~(Mc.I.windup || Mc.I.chatter);
        G.reg.(nm) = regression_ok(Mb, Mc);
        G.base.(nm) = Mb.speed.steady;
        G.cand.(nm) = Mc.speed.steady;
    end
    G.pref_all = G.pref.X && G.pref.XZ && G.pref.H;
    G.hard_all = G.hard.X && G.hard.XZ && G.hard.H;
    G.sat_all = G.sat.X && G.sat.XZ && G.sat.H && (C.Step.M.thrust.full.sat_pct <= 1.0);
    G.near_all = G.near.X && G.near.XZ && G.near.H;
    G.rate_all = G.rate_ok.X && G.rate_ok.XZ && G.rate_ok.H;
    G.I_all = G.I_ok.X && G.I_ok.XZ && G.I_ok.H && ...
        ~(C.Step.M.I.windup || C.Step.M.I.chatter);
    G.reg_all = G.reg.X.ok && G.reg.XZ.ok && G.reg.H.ok;

    G.step = C.Step.M.speed.step;
    G.step_ok = false;
    if isfield(G.step, 'legs') && numel(G.step.legs) >= 3
        G.step_ok = G.step.legs(2).pass && G.step.legs(3).pass;
    elseif isfield(G.step, 'pass')
        G.step_ok = G.step.pass;
    end

    G.jac_ok = law.design.level.jac_ok && law.design.XZ.jac_ok;
    G.poles_stable = all(real(law.design.level.cl_at_Ki) < 0) && ...
        all(real(law.design.XZ.cl_at_Ki) < 0);

    hard_pass = G.hard_all && G.sat_all && G.step_ok && G.reg_all && ...
        G.I_all && G.near_all && G.rate_all && G.jac_ok && G.poles_stable;
    pref_pass = G.pref_all && hard_pass;
    G.hard_pass = hard_pass;
    G.pref_pass = pref_pass;

    if hard_pass
        verdict = 'PASS';
        next_opt = 'two_repeat_production_integration';
        if pref_pass
            next_detail = ['SPEED_PI_FF_BENCHMARK PASS (pref+hard). ', ...
                'Recommend SEPARATE two-repeat production integration of ', ...
                'Tff=kD*uref*|uref| + AW-PI (Kp=25, documented Ki) — not in this task.'];
        else
            next_detail = ['SPEED_PI_FF_BENCHMARK PASS (hard; pref miss). ', ...
                'Recommend SEPARATE two-repeat production integration of FF+AW-PI; ', ...
                'no second Ki sweep.'];
        end
    else
        verdict = 'FAIL';
        next_opt = 'reject_candidate_no_ki_sweep';
        reasons = {};
        if ~G.hard_all; reasons{end+1} = 'hold MAE/p95'; end %#ok<*AGROW>
        if ~G.step_ok; reasons{end+1} = 'step settle/OS'; end
        if ~G.sat_all; reasons{end+1} = 'thrust sat'; end
        if ~G.reg_all; reasons{end+1} = 'attitude/path regression'; end
        if ~G.I_all; reasons{end+1} = 'I windup/chatter'; end
        if ~G.near_all || ~G.rate_all; reasons{end+1} = 'thrust near/rate'; end
        next_detail = ['REJECT single FF+AW-PI candidate (no second Ki sweep). Fail: ', ...
            strjoin(reasons, ', '), sprintf('. Ki was %.4f from pole target.', law.Ki)];
    end
end

function R = regression_ok(Mb, Mc)
    R = struct();
    R.pitch = within_tol(Mc.pitch.mae_deg, Mb.pitch.mae_deg, 0.02, 1e-3);
    R.yaw = within_tol(Mc.yaw.mae_deg, Mb.yaw.mae_deg, 0.02, 1e-3);
    R.tilde = within_tol(Mc.tilde.rms_deg, Mb.tilde.rms_deg, 0.02, 1e-3);
    R.p = within_tol(Mc.p.rms_dps, Mb.p.rms_dps, 0.02, 1e-3);
    R.path = within_tol(Mc.path.mean_cte, Mb.path.mean_cte, 0.02, 1e-3);
    R.ok = R.pitch && R.yaw && R.tilde && R.p && R.path;
    R.detail = sprintf('pitch %s yaw %s tilde %s p %s path %s', ...
        yn(R.pitch), yn(R.yaw), yn(R.tilde), yn(R.p), yn(R.path));
end

function ok = within_tol(a, b, rel, abs_eps)
    if ~(isfinite(a) && isfinite(b)); ok = false; return; end
    % Allow improvement (candidate better than baseline)
    if a <= b + max(abs_eps, rel * max(abs(b), abs_eps)); ok = true; return; end
    ok = false;
end

%% ===================== artifacts =====================
function write_png(png_path, B, C, lim, task_id, verdict, law)
    fig = figure('Visible', 'off', 'Position', [30 30 1600 1100]);
    try
        % Row1: uref/u candidate
        subplot(3, 4, 1); plot_uv(C.X.S); title('CAND X: u_{ref}/u');
        subplot(3, 4, 2); plot_uv(C.XZ.S); title('CAND XZ: u_{ref}/u');
        subplot(3, 4, 3); plot_uv(C.H.S); title('CAND R10: u_{ref}/u');
        subplot(3, 4, 4); plot_uv(C.Step.S); title('CAND STEP');
        % Row2: error + Uh/|V|
        subplot(3, 4, 5); plot_err(C.X.S); title('X e_u / e_{Uh} / e_{|V|}');
        subplot(3, 4, 6); plot_err(C.XZ.S); title('XZ errors');
        subplot(3, 4, 7); plot_err(C.H.S); title('R10 errors');
        subplot(3, 4, 8); plot_err(C.Step.S); title('STEP errors');
        % Row3: T components, I, attitude
        subplot(3, 4, 9); plot_Tcomp(C.X.S, lim); title('X Tff/P/I/T');
        subplot(3, 4, 10); plot_Tcomp(C.XZ.S, lim); title('XZ T components');
        subplot(3, 4, 11); plot_I(C); title(sprintf('I(t) Ki=%.3f', law.Ki));
        subplot(3, 4, 12); plot_att(B, C); title('Attitude/path base vs cand');
        sgtitle(sprintf('%s | %s | kD=%.4f Ki=%.3f', task_id, verdict, law.kD, law.Ki), ...
            'Interpreter', 'none');
        saveas(fig, png_path);
    catch ME
        fprintf('PNG warn: %s\n', ME.message);
    end
    close(fig);
end

function plot_uv(S)
    plot(S.t, S.u_ref, 'k--', S.t, S.u_ctrl, 'b', S.t, S.Uh, 'g:', S.t, S.Vtot, 'm:');
    grid on; xlabel('t [s]'); ylabel('[m/s]');
    legend('u_{ref,eff}', 'u', 'U_h', '|V|', 'Location', 'best');
end

function plot_err(S)
    plot(S.t, S.u_ref - S.u_ctrl, 'b', S.t, S.u_ref - S.Uh, 'g:', S.t, S.u_ref - S.Vtot, 'm:');
    yline(0.05, 'r--'); yline(-0.05, 'r--');
    grid on; xlabel('t'); ylabel('err'); legend('e_u', 'e_{Uh}', 'e_{|V|}', 'Location', 'best');
end

function plot_Tcomp(S, lim)
    plot(S.t, S.Tff, 'k--', S.t, S.Tp, 'b:', S.t, S.Ti, 'g', S.t, S.thrust, 'r', ...
        S.t, S.thrust_unsat, 'm:');
    yline(lim.thrust_max, 'r--'); yline(lim.thrust_min, 'r--');
    grid on; xlabel('t'); ylabel('N');
    legend('Tff', 'P', 'I', 'T', 'Tunsat', 'Location', 'best');
end

function plot_I(C)
    plot(C.X.S.t, C.X.S.Ti, 'b', C.XZ.S.t, C.XZ.S.Ti, 'r', ...
        C.H.S.t, C.H.S.Ti, 'k', C.Step.S.t, C.Step.S.Ti, 'm');
    grid on; xlabel('t'); ylabel('I [N]');
    legend('X', 'XZ', 'R10', 'Step', 'Location', 'best');
end

function plot_att(B, C)
    names = {'X', 'XZ', 'R10'};
    bp = [B.X.M.pitch.mae_deg, B.XZ.M.pitch.mae_deg, B.H.M.pitch.mae_deg];
    cp = [C.X.M.pitch.mae_deg, C.XZ.M.pitch.mae_deg, C.H.M.pitch.mae_deg];
    bc = [B.X.M.path.mean_cte, B.XZ.M.path.mean_cte, B.H.M.path.mean_cte];
    cc = [C.X.M.path.mean_cte, C.XZ.M.path.mean_cte, C.H.M.path.mean_cte];
    bar([bp; cp; bc; cc]');
    set(gca, 'XTickLabel', names);
    legend('B pitch', 'C pitch', 'B CTE', 'C CTE', 'Location', 'best');
    ylabel('deg / m'); grid on;
end

function write_md(md_path, task_id, verdict, law, B, C, G, next_opt, next_detail, ...
        seed, md, mat, png, thrust_p, speed_p, ctrl_p)
    fid = fopen(md_path, 'w');
    fprintf(fid, '# %s — Speed-ref quadratic-drag FF + AW-PI benchmark\n\n', task_id);
    fprintf(fid, '**Overall verdict: %s**\n\n', verdict);
    fprintf(fid, '## Provenance\n\n');
    fprintf(fid, '- Read-only: `%s`, `%s`, `%s`\n', thrust_p, speed_p, ctrl_p);
    fprintf(fid, '- Driver: `run_speed_pi_ff_benchmark.m` (one invocation; production untouched)\n');
    fprintf(fid, '- Artifacts: `%s`, `%s`, `%s`\n', md, mat, png);
    fprintf(fid, '- Seed: %d | Kp_roll frozen=%.6f\n\n', seed, law.Kp_roll);

    fprintf(fid, '## Equations / gains / poles\n\n');
    fprintf(fid, '```\n');
    fprintf(fid, 'Baseline: %s\n', law.baseline);
    fprintf(fid, 'Candidate: %s\n', law.candidate);
    fprintf(fid, 'kD = Treq_level / Ufix^2 = %.10f / %.2f^2 = %.10f N/(m/s)^2\n', ...
        law.Treq_level, law.Ufix, law.kD);
    fprintf(fid, 'Kp = %.4g (frozen); Ki = %.8f; Kaw = Ki/Kp = %.8f\n', law.Kp, law.Ki, law.Kaw);
    fprintf(fid, 'Treq level/XZ = %.6f / %.6f N; R10 exact = UNKNOWN\n', ...
        law.Treq_level, law.Treq_XZ);
    fprintf(fid, 'Design: %s\n', law.design.method);
    fprintf(fid, 'zeta_target = %.6f\n', law.design.zeta_target);
    fprintf(fid, 'Level surge: a=%.8g b=%.8g wn=%.6g Ki_L=%.6g jac_ok=%d\n', ...
        law.design.level.a, law.design.level.b, law.design.level.wn, ...
        law.design.level.Ki, law.design.level.jac_ok);
    fprintf(fid, 'XZ surge:    a=%.8g b=%.8g wn=%.6g Ki_XZ=%.6g jac_ok=%d\n', ...
        law.design.XZ.a, law.design.XZ.b, law.design.XZ.wn, ...
        law.design.XZ.Ki, law.design.XZ.jac_ok);
    fprintf(fid, 'CL poles @Ki (level): %s\n', mat2str(law.design.level.cl_at_Ki.', 4));
    fprintf(fid, 'CL poles @Ki (XZ):    %s\n', mat2str(law.design.XZ.cl_at_Ki.', 4));
    fprintf(fid, 'Frame: %s\n', law.frame);
    fprintf(fid, '```\n\n');

    fprintf(fid, '## Before / after (BODY u hold vs u_ref_eff)\n\n');
    fprintf(fid, '| Route | Base MAE | Base p95 | Cand MAE | Cand p95 | Base thr | Cand thr | Cand I |\n');
    fprintf(fid, '|-------|---------:|---------:|---------:|---------:|---------:|---------:|-------:|\n');
    dump_ba(fid, 'X', B.X.M, C.X.M);
    dump_ba(fid, 'XZ', B.XZ.M, C.XZ.M);
    dump_ba(fid, 'R10', B.H.M, C.H.M);

    fprintf(fid, '\n## Candidate thrust components (steady hold)\n\n');
    fprintf(fid, '| Route | T mean | Tff | P | I | rateRMS | near%% | sat%% |\n');
    fprintf(fid, '|-------|-------:|----:|--:|--:|--------:|------:|-----:|\n');
    dump_tc(fid, 'X', C.X.M);
    dump_tc(fid, 'XZ', C.XZ.M);
    dump_tc(fid, 'R10', C.H.M);
    dump_tc(fid, 'STEP', C.Step.M);

    fprintf(fid, '\n## Step 1.3→1.5→1.3 (candidate)\n\n');
    if isfield(C.Step.M.speed, 'step') && isfield(C.Step.M.speed.step, 'legs')
        fprintf(fid, '| Leg | uref | settle_s | OS%% | lag_s | MAE | signed | PASS |\n');
        fprintf(fid, '|-----|-----:|---------:|----:|------:|----:|-------:|:----:|\n');
        for k = 1:numel(C.Step.M.speed.step.legs)
            L = C.Step.M.speed.step.legs(k);
            fprintf(fid, '| %d | %.2f | %.3f | %.2f | %.3f | %.4f | %.4f | %s |\n', ...
                k, L.uref, L.settle_s, L.overshoot_pct, L.lag_s, L.mae, L.signed, yn(L.pass));
        end
    end

    fprintf(fid, '\n## Attitude / path regression (≤2%% vs baseline)\n\n');
    fprintf(fid, '| Route | pitch B→C | yaw | tildeRMS | pRMS | CTE | OK |\n');
    fprintf(fid, '|-------|----------:|----:|---------:|-----:|----:|:--:|\n');
    dump_reg(fid, 'X', B.X.M, C.X.M, G.reg.X);
    dump_reg(fid, 'XZ', B.XZ.M, C.XZ.M, G.reg.XZ);
    dump_reg(fid, 'R10', B.H.M, C.H.M, G.reg.H);

    fprintf(fid, '\n## Gate table\n\n');
    fprintf(fid, '| Gate | Result | Detail |\n');
    fprintf(fid, '|------|:------:|--------|\n');
    fprintf(fid, '| Pref MAE≤0.03 p95≤0.05 | %s | X=%s XZ=%s H=%s |\n', ...
        yn(G.pref_all), yn(G.pref.X), yn(G.pref.XZ), yn(G.pref.H));
    fprintf(fid, '| Hard MAE≤0.07 p95≤0.10 | %s | X=%s XZ=%s H=%s |\n', ...
        yn(G.hard_all), yn(G.hard.X), yn(G.hard.XZ), yn(G.hard.H));
    fprintf(fid, '| Step ±0.05 @≤6s OS≤10%% | %s | worst_ts=%.3f worst_OS=%.2f |\n', ...
        yn(G.step_ok), nz(G.step, 'worst_settle_s'), nz(G.step, 'worst_os_pct'));
    fprintf(fid, '| Thrust sat≤1%% / near/rate | %s | sat=%s near=%s rate=%s |\n', ...
        yn(G.sat_all && G.near_all && G.rate_all), yn(G.sat_all), yn(G.near_all), yn(G.rate_all));
    fprintf(fid, '| I no windup/chatter | %s | |\n', yn(G.I_all));
    fprintf(fid, '| Attitude/path regression≤2%% | %s | |\n', yn(G.reg_all));
    fprintf(fid, '| Jac/poles OK | %s | jac=%s poles=%s |\n', ...
        yn(G.jac_ok && G.poles_stable), yn(G.jac_ok), yn(G.poles_stable));

    fprintf(fid, '\n## Decision\n\n');
    fprintf(fid, '- Verdict: **%s**\n', verdict);
    fprintf(fid, '- Next: `%s`\n', next_opt);
    fprintf(fid, '- Detail: %s\n', next_detail);
    fprintf(fid, '- Production: untouched (no law edit in this task)\n\n');

    fprintf(fid, '## Feedback\n\n');
    fprintf(fid, '- PASS/FAIL: **%s**\n', verdict);
    fprintf(fid, '- Equations: Tff=kD*uref*|uref|; Tunsat=Tff+Kp*e+I; AW back-calc/freeze; I(0)=0\n');
    fprintf(fid, '- kD=%.8f Ki=%.6f Kaw=%.6f zeta=1/sqrt(2) poles L=%s\n', ...
        law.kD, law.Ki, law.Kaw, mat2str(law.design.level.cl_at_Ki.', 3));
    fprintf(fid, '- Before→After MAE: X %.4f→%.4f | XZ %.4f→%.4f | R10 %.4f→%.4f\n', ...
        B.X.M.speed.steady.mae, C.X.M.speed.steady.mae, ...
        B.XZ.M.speed.steady.mae, C.XZ.M.speed.steady.mae, ...
        B.H.M.speed.steady.mae, C.H.M.speed.steady.mae);
    fprintf(fid, '- Files: `%s` `%s` `%s`\n', md, mat, png);
    fprintf(fid, '- Next: %s\n', next_opt);
    fclose(fid);
end

function dump_ba(fid, name, Mb, Mc)
    fprintf(fid, '| %s | %.4f | %.4f | %.4f | %.4f | %.3f | %.3f | %.3f |\n', ...
        name, Mb.speed.steady.mae, Mb.speed.steady.p95, ...
        Mc.speed.steady.mae, Mc.speed.steady.p95, ...
        Mb.thrust.steady.mean, Mc.thrust.steady.mean, Mc.I.mean);
end

function dump_tc(fid, name, M)
    T = M.thrust.steady; F = M.thrust.full;
    fprintf(fid, '| %s | %.3f | %.3f | %.3f | %.3f | %.3f | %.2f | %.2f |\n', ...
        name, T.mean, T.Tff_mean, T.Tp_mean, T.Ti_mean, T.rate_rms, T.near_pct, F.sat_pct);
end

function dump_reg(fid, name, Mb, Mc, R)
    fprintf(fid, '| %s | %.4f→%.4f | %.4f→%.4f | %.4f→%.4f | %.4f→%.4f | %.4f→%.4f | %s |\n', ...
        name, Mb.pitch.mae_deg, Mc.pitch.mae_deg, Mb.yaw.mae_deg, Mc.yaw.mae_deg, ...
        Mb.tilde.rms_deg, Mc.tilde.rms_deg, Mb.p.rms_dps, Mc.p.rms_dps, ...
        Mb.path.mean_cte, Mc.path.mean_cte, yn(R.ok));
end

function append_ss_audit(out_dir, task_id, verdict, law, B, C, G, next_opt, next_detail, ...
        md, mat, png)
    audit_path = fullfile(out_dir, 'STATE_SPACE_MODEL_AUDIT.md');
    fid = fopen(audit_path, 'a');
    fprintf(fid, '\n\n---\n\n');
    fprintf(fid, '## %s — %s\n\n', task_id, datestr(now, 'yyyy-mm-dd HH:MM:SS'));
    fprintf(fid, '### Provenance\n\n');
    fprintf(fid, '- Read-only: `THRUST_TRIM_U15_AUDIT.mat`, `SPEED_BASELINE_AUDIT.mat`, `controller_law.m`\n');
    fprintf(fid, '- Driver: `run_speed_pi_ff_benchmark.m` (one invocation; production untouched)\n');
    fprintf(fid, '- Artifacts: `%s`, `%s`, `%s`\n\n', md, mat, png);
    fprintf(fid, '### Equations / kD / Ki / poles\n\n');
    fprintf(fid, '```\n');
    fprintf(fid, 'Tff = kD * u_ref_eff * |u_ref_eff|\n');
    fprintf(fid, 'kD = Treq_level/Ufix^2 = %.10f\n', law.kD);
    fprintf(fid, 'Tunsat = Tff + Kp*e + I; T = sat(Tunsat); I(0)=0\n');
    fprintf(fid, 'I += Ki*e*dt + Kaw*(T-Tunsat)*dt  (freeze e-int if sat against e)\n');
    fprintf(fid, 'Kp=%.4g Ki=%.8f Kaw=%.8f  zeta=1/sqrt(2)  Ki=min(Ki_L,Ki_XZ)\n', ...
        law.Kp, law.Ki, law.Kaw);
    fprintf(fid, 'Level a,b,wn,Ki = %.6g, %.6g, %.5g, %.5g\n', ...
        law.design.level.a, law.design.level.b, law.design.level.wn, law.design.level.Ki);
    fprintf(fid, 'XZ    a,b,wn,Ki = %.6g, %.6g, %.5g, %.5g\n', ...
        law.design.XZ.a, law.design.XZ.b, law.design.XZ.wn, law.design.XZ.Ki);
    fprintf(fid, 'CL poles level @Ki: %s\n', mat2str(law.design.level.cl_at_Ki.', 4));
    fprintf(fid, 'CL poles XZ @Ki:    %s\n', mat2str(law.design.XZ.cl_at_Ki.', 4));
    fprintf(fid, '```\n\n');
    fprintf(fid, '### Before / after hold (BODY u)\n\n');
    fprintf(fid, '| Route | Base MAE/p95 | Cand MAE/p95 | Cand thr/I |\n');
    fprintf(fid, '|-------|-------------:|-------------:|-----------:|\n');
    fprintf(fid, '| X | %.4f/%.4f | %.4f/%.4f | %.3f/%.3f |\n', ...
        B.X.M.speed.steady.mae, B.X.M.speed.steady.p95, ...
        C.X.M.speed.steady.mae, C.X.M.speed.steady.p95, ...
        C.X.M.thrust.steady.mean, C.X.M.I.mean);
    fprintf(fid, '| XZ | %.4f/%.4f | %.4f/%.4f | %.3f/%.3f |\n', ...
        B.XZ.M.speed.steady.mae, B.XZ.M.speed.steady.p95, ...
        C.XZ.M.speed.steady.mae, C.XZ.M.speed.steady.p95, ...
        C.XZ.M.thrust.steady.mean, C.XZ.M.I.mean);
    fprintf(fid, '| R10 | %.4f/%.4f | %.4f/%.4f | %.3f/%.3f |\n\n', ...
        B.H.M.speed.steady.mae, B.H.M.speed.steady.p95, ...
        C.H.M.speed.steady.mae, C.H.M.speed.steady.p95, ...
        C.H.M.thrust.steady.mean, C.H.M.I.mean);
    fprintf(fid, '### Verdict / next\n\n');
    fprintf(fid, '- Verdict: **%s**\n', verdict);
    fprintf(fid, '- Pref/Hard/Step/Reg/I: %s/%s/%s/%s/%s\n', ...
        yn(G.pref_pass), yn(G.hard_pass), yn(G.step_ok), yn(G.reg_all), yn(G.I_all));
    fprintf(fid, '- Next: `%s` — %s\n', next_opt, next_detail);
    fprintf(fid, '- Production: untouched\n');
    fclose(fid);
end

function print_feedback(verdict, law, B, C, G, next_opt, next_detail, md, mat, png)
    fprintf('\n----- FEEDBACK -----\n');
    fprintf('PASS/FAIL: %s\n', verdict);
    fprintf('Equations: Tff=kD*uref_eff*|uref_eff|; Tunsat=Tff+Kp*e+I; T=sat; AW back-calc/freeze; I(0)=0\n');
    fprintf('kD=%.8f  Kp=%.4g  Ki=%.6f  Kaw=%.6f  zeta=1/sqrt(2)\n', ...
        law.kD, law.Kp, law.Ki, law.Kaw);
    fprintf('Poles level@Ki: %s | XZ@Ki: %s\n', ...
        mat2str(law.design.level.cl_at_Ki.', 3), mat2str(law.design.XZ.cl_at_Ki.', 3));
    fprintf('Before→After MAE/p95: X %.4f/%.4f→%.4f/%.4f | XZ %.4f/%.4f→%.4f/%.4f | R10 %.4f/%.4f→%.4f/%.4f\n', ...
        B.X.M.speed.steady.mae, B.X.M.speed.steady.p95, C.X.M.speed.steady.mae, C.X.M.speed.steady.p95, ...
        B.XZ.M.speed.steady.mae, B.XZ.M.speed.steady.p95, C.XZ.M.speed.steady.mae, C.XZ.M.speed.steady.p95, ...
        B.H.M.speed.steady.mae, B.H.M.speed.steady.p95, C.H.M.speed.steady.mae, C.H.M.speed.steady.p95);
    fprintf('Gates hard/pref/step/reg/I/sat: %s/%s/%s/%s/%s/%s\n', ...
        yn(G.hard_pass), yn(G.pref_pass), yn(G.step_ok), yn(G.reg_all), yn(G.I_all), yn(G.sat_all));
    fprintf('Files: %s | %s | %s\n', md, mat, png);
    fprintf('Next: %s — %s\n', next_opt, next_detail);
end

%% ===================== helpers =====================
function st = err_stats_deg(e, mask)
    st = struct('mae_deg', NaN, 'rms_deg', NaN, 'p95_deg', NaN, 'max_deg', NaN, ...
        'signed_mean_deg', NaN, 'n', 0);
    if ~any(mask); return; end
    v = e(mask); st.n = numel(v);
    st.signed_mean_deg = rad2deg(mean(v));
    st.mae_deg = rad2deg(mean(abs(v)));
    st.rms_deg = rad2deg(rms_local(v));
    st.p95_deg = rad2deg(prctile_local(abs(v), 95));
    st.max_deg = rad2deg(max(abs(v)));
end

function y = sat_pct(u, mask, thr)
    if ~any(mask); y = NaN; return; end
    y = 100 * mean(abs(u(mask)) >= thr);
end

function r = rms_local(x), x = x(:); r = sqrt(mean(x.^2)); end
function p = prctile_local(x, q)
    x = sort(x(:)); if isempty(x); p = NaN; return; end
    k = max(1, min(numel(x), round(q / 100 * numel(x)))); p = x(k);
end
function m = mean_safe(x, mask)
    if ~any(mask); m = NaN; return; end
    m = mean(x(mask));
end
function m = rms_safe(x, mask)
    if ~any(mask); m = NaN; return; end
    m = rms_local(x(mask));
end
function m = max_abs_safe(x, mask)
    if ~any(mask); m = NaN; return; end
    m = max(abs(x(mask)));
end
function v = nz(S, f)
    if isstruct(S) && isfield(S, f); v = S.(f); else; v = NaN; end
end
function s = yn(tf)
    if tf; s = 'YES'; else; s = 'NO'; end
end
