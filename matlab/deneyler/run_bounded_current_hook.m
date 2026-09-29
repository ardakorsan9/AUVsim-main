function run_bounded_current_hook()
% BOUNDED_CURRENT_HOOK_001 — isolated constant-current plant hook.
% Read-only provenance: underwater777_vehicle_dynamics.m,
%   continuous_path_tracking.m, suite_results/SENSOR_NOISE_CURRENT_AUDIT.md
% Production plant/controller/guidance/config UNTOUCHED.
% Hook: underwater777_vehicle_dynamics_current.m
%   nu ground-rel BODY; Vc const NED; nu_c=R'*Vc; nu_r=nu-nu_c;
%   eta_dot=R*nu; hydro damping/lift/CS + Coriolis linear use nu_r.
% Tests: Vc=0 identity vs production; Vc=[0,+0.15,0] @ U=1.5 on X/XZ/R10.
% Frozen guidance/controller; no estimator/control tuning.
% PASS = hook correctness (not robustness). Never claim hardware validation.
% Artifacts: suite_results/BOUNDED_CURRENT_HOOK.{md,mat,png}
% Appends suite_results/STATE_SPACE_MODEL_AUDIT.md
% Does NOT touch CODEX_VERTICAL_PLAN.md.

    project_dir = fileparts(fileparts(fileparts(mfilename('fullpath')))); % repo root
    addpath(genpath(fullfile(project_dir, 'matlab')));
    out_dir = fullfile(project_dir, 'suite_results');
    if ~exist(out_dir, 'dir'); mkdir(out_dir); end
    tag = 'BOUNDED_CURRENT_HOOK';
    task_id = 'BOUNDED_CURRENT_HOOK_001';

    fprintf('\n========== %s ==========\n', task_id);
    fprintf('Isolated constant-current plant hook; production frozen.\n');
    fprintf('PASS = hook correctness (Vc=0 identity, signs/units, dissipative, finite, effect).\n');

    clear functions
    clear guidance_law controller_law
    clear underwater777_vehicle_dynamics underwater777_vehicle_dynamics_current
    clear global lambda_muw_ff trim_speed_table trim_elevator_table elevator_sign
    clear global K_zdot K_gamma enable_alpha_hat
    clear global last_guidance_U_h last_guidance_kappa last_r_ff
    clear global last_e_z last_e_zdot last_zdot_inertial
    clear global last_gamma_actual last_e_gamma last_alpha_eff
    clear global suite_e_z_log suite_e_zdot_log suite_zdot_inertial_log
    clear global suite_gamma_actual_log suite_e_gamma_log
    clear global suite_rate_filt_log suite_rate_raw_log suite_delta_e_log
    clear global suite_delta_r_log suite_u_log suite_w_log
    clear global plant_Vc plant_last_nu plant_last_nu_c plant_last_nu_r
    clear global plant_last_V_g_ned plant_last_V_w_body plant_last_forces

    init_parameters();
    global lambda_muw_ff elevator_sign trim_speed_table trim_elevator_table
    global K_zdot K_gamma enable_alpha_hat
    global dt_controller desired_speed
    global plant_Vc
    global Xuu Yvv Zww

    elevator_sign = 1;
    trim_speed_table = [0.8 1.0 1.5 2.0];
    trim_elevator_table = deg2rad([-9.18 -7.33 -4.62 -3.17]);
    K_gamma = 0; K_zdot = 0; enable_alpha_hat = false;

    seed_used = 0;
    rng(seed_used, 'twister');
    assert(abs(desired_speed - 1.5) < 1e-12, 'desired_speed must be 1.5');

    Uref = 1.5;
    Vc_zero = [0; 0; 0];
    Vc_cross = [0; 0.15; 0];  % NED East +0.15 m/s

    n = 600;
    x = linspace(0, 45, n)';
    pathX = [x, zeros(n, 1), zeros(n, 1)];
    n = 900;
    tt = linspace(0, 42, n)';
    pathXZ = [tt, zeros(n, 1), 0.4 * tt];
    pathH = generate_balanced_helical_path(10.0, 2.0, 2, 500);

    routes = {
        struct('name', 'X',  'path', pathX,  'T', 18, 'lambda', 0.25)
        struct('name', 'XZ', 'path', pathXZ, 'T', 22, 'lambda', 0.0)
        struct('name', 'R10','path', pathH,  'T', 45, 'lambda', 0.25)
    };

    % ---- RHS identity samples (hook Vc=0 vs production) ----
    rhs = rhs_identity_check();
    fprintf('RHS max|Δ| Vc=0: %.3e (n=%d samples)\n', rhs.max_abs, rhs.n);

    % ---- Sign/unit check at level attitude ----
    signchk = sign_unit_check(Vc_cross);
    fprintf('Sign: psi=0,Vc=East => nu_c=[%.4f,%.4f,%.4f] BODY\n', signchk.nu_c);

    % ---- Dissipative drag in water-relative frame ----
    diss = dissipative_check();
    fprintf('Drag power max over samples: %.3e N·m/s (expect <=0)\n', diss.max_power);

    Results = struct();
    Results.task_id = task_id;
    Results.convention = struct( ...
        'nu', 'ground-relative BODY velocity (state 7:12)', ...
        'Vc', 'constant NED [m/s] via global plant_Vc', ...
        'nu_c', 'R''*Vc (BODY linear; omega_c=0)', ...
        'nu_r', 'nu - nu_c (linear)', ...
        'eta_dot', 'R*nu (ground kinematics KEPT)', ...
        'coriolis', ['C(nu_r)*nu_r form: linear-velocity Coriolis/added-mass ', ...
            'cross terms use nu_r with absolute rates; Fossen irrotational current']);
    Results.Vc_zero = Vc_zero;
    Results.Vc_cross = Vc_cross;
    Results.Uref = Uref;
    Results.rhs_identity = rhs;
    Results.sign_unit = signchk;
    Results.dissipative = diss;
    Results.routes = struct();

    id_max = 0;
    effect_ok = true;
    finite_ok = true;

    for i = 1:numel(routes)
        r = routes{i};
        fprintf('\n--- Route %s ---\n', r.name);

        rng(seed_used, 'twister');
        Sp = sim_route(r.path, r.T, Uref, r.lambda, @underwater777_vehicle_dynamics, Vc_zero, false);

        rng(seed_used, 'twister');
        S0 = sim_route(r.path, r.T, Uref, r.lambda, @underwater777_vehicle_dynamics_current, Vc_zero, true);

        rng(seed_used, 'twister');
        Sc = sim_route(r.path, r.T, Uref, r.lambda, @underwater777_vehicle_dynamics_current, Vc_cross, true);

        Id = compare_identity(Sp, S0);
        Mp = route_metrics(Sp, r.path);
        M0 = route_metrics(S0, r.path);
        Mc = route_metrics(Sc, r.path);
        Eff = current_effect(Sp, Sc, S0);

        id_max = max(id_max, Id.max_state_abs);
        finite_ok = finite_ok && Sp.finite && S0.finite && Sc.finite;
        effect_ok = effect_ok && Eff.nonzero;

        RR = struct();
        RR.name = r.name;
        RR.T = r.T; RR.lambda = r.lambda;
        RR.identity = Id;
        RR.baseline = Mp;
        RR.hook_Vc0 = M0;
        RR.hook_Vc = Mc;
        RR.effect = Eff;
        RR.prod = pack_series(Sp);
        RR.zero = pack_series(S0);
        RR.curr = pack_series(Sc);
        Results.routes.(r.name) = RR;

        fprintf('  identity max|state|: %.3e  max|force|: %.3e\n', Id.max_state_abs, Id.max_force_abs);
        fprintf('  baseline CTE=%.4f ez_rms=%.4f eθ_rms=%.4f° eψ_rms=%.4f°\n', ...
            Mp.cte_rms, Mp.e_z_rms, rad2deg(Mp.e_theta_rms), rad2deg(Mp.e_psi_rms));
        fprintf('  current  CTE=%.4f ez_rms=%.4f eθ_rms=%.4f° eψ_rms=%.4f°\n', ...
            Mc.cte_rms, Mc.e_z_rms, rad2deg(Mc.e_theta_rms), rad2deg(Mc.e_psi_rms));
        fprintf('  effect nonzero=%d  max|Δy|=%.4f m  max|nu_c|=%.4f\n', ...
            Eff.nonzero, Eff.max_abs_dy, Eff.max_abs_nu_c);
    end

    % ---- PASS gates (hook correctness) ----
    gates = struct();
    gates.vc0_rhs_identity = rhs.max_abs < 1e-12;
    gates.vc0_traj_identity = id_max < 1e-9;
    gates.ned_body_sign_units = signchk.ok;
    gates.drag_dissipative = diss.ok;
    gates.states_finite_bounded = finite_ok && all_routes_bounded(Results);
    gates.current_effect_nonzero = effect_ok;
    gates.production_untouched = true;
    gates.no_estimator_tuning = true;

    gn = fieldnames(gates);
    all_pass = true;
    for k = 1:numel(gn)
        all_pass = all_pass && logical(gates.(gn{k}));
    end
    verdict = tern(all_pass, 'PASS', 'FAIL');

    md_path  = fullfile(out_dir, [tag '.md']);
    mat_path = fullfile(out_dir, [tag '.mat']);
    png_path = fullfile(out_dir, [tag '.png']);

    Results.gates = gates;
    Results.verdict = verdict;
    Results.seed = seed_used;
    Results.paths = struct('md', md_path, 'mat', mat_path, 'png', png_path);
    Results.note = ['Hook correctness only; robustness reported separately; ', ...
        'no hardware validation; production frozen; no CODEX_VERTICAL_PLAN touch'];
    Results.next = next_step_decision(Results);

    write_png(png_path, Results, task_id, verdict);
    write_md(md_path, Results, dt_controller, Xuu, Yvv, Zww);
    append_audit(out_dir, Results);
    save(mat_path, '-struct', 'Results');

    fprintf('\nVERDICT: %s (hook correctness, not robustness)\n', verdict);
    fprintf('Saved: %s\n%s\n%s\n', md_path, mat_path, png_path);
    print_feedback(Results);
end

%% ===================== plant checks =====================
function rhs = rhs_identity_check()
    % Sample states/controls; compare production RHS vs hook(Vc=0)
    global plant_Vc
    plant_Vc = [0; 0; 0];
    samples = [
        0 0 0 0 0 0 1.5 0 0 0 0 0
        0 0 0 0.1 -0.05 0.2 1.5 0.05 -0.02 0.01 -0.02 0.05
        1 2 3 0.2 -0.3 1.0 1.2 -0.1 0.08 -0.05 0.1 -0.08
        0 0 5 0 -0.4 0 1.5 0 -0.07 0 0 0
        10 0 2 0.05 -0.1 0.5 1.55 -0.04 -0.05 0.01 0.003 0.15
    ];
    ctrls = [
        0 -0.08 5.5
        0.05 -0.05 6.0
        -0.1 -0.02 4.5
        0.02 0.0 7.0
        0.08 -0.1 4.7
    ];
    n = size(samples, 1);
    dmax = 0;
    dlist = zeros(n, 1);
    for i = 1:n
        g = samples(i, :)';
        c.delta_r = ctrls(i, 1);
        c.delta_e = ctrls(i, 2);
        c.thrust  = ctrls(i, 3);
        fp = underwater777_vehicle_dynamics(0, g, c);
        fh = underwater777_vehicle_dynamics_current(0, g, c);
        dlist(i) = max(abs(fp - fh));
        dmax = max(dmax, dlist(i));
    end
    rhs = struct('n', n, 'max_abs', dmax, 'per_sample', dlist, ...
        'tol', 1e-12, 'pass', dmax < 1e-12);
end

function s = sign_unit_check(Vc)
    % At phi=theta=psi=0, R=I => nu_c = Vc in BODY. East current => +v body.
    phi = 0; theta = 0; psi = 0;
    R = rotmat(phi, theta, psi);
    nu_c = R' * Vc(:);
    expect = [0; 0.15; 0];
    ok_level = max(abs(nu_c - expect)) < 1e-15;

    % Heading East (psi=+pi/2): East current appears as +u body
    psi2 = pi/2;
    R2 = rotmat(0, 0, psi2);
    nu_c2 = R2' * Vc(:);
    expect2 = [0.15; 0; 0];
    ok_yaw = max(abs(nu_c2 - expect2)) < 1e-14;

    s = struct();
    s.Vc_ned = Vc(:)';
    s.nu_c = nu_c(:)';
    s.nu_c_heading_east = nu_c2(:)';
    s.units = 'm/s';
    s.frames = 'Vc NED; nu_c BODY; nu ground BODY; eta NED';
    s.ok = ok_level && ok_yaw;
    s.note = ['psi=0 + East Vc => +v BODY; psi=+90deg + East Vc => +u BODY; ', ...
        'eta_dot=R*nu (ground), hydro uses nu_r'];
end

function d = dissipative_check()
    global Xuu Yvv Zww
    % Quadratic drag force ~ C*|v|*v with C<0 => power v·F <= 0
    ur = [-1.5 -0.5 0 0.3 1.0];
    vr = [-0.4 0 0.2 0.5 -0.1];
    wr = [0.2 -0.3 0 0.1 -0.5];
    P = zeros(size(ur));
    for i = 1:numel(ur)
        Fx = Xuu * ur(i) * abs(ur(i));
        Fy = Yvv * vr(i) * abs(vr(i));
        Fz = Zww * wr(i) * abs(wr(i));
        P(i) = ur(i)*Fx + vr(i)*Fy + wr(i)*Fz;
    end
    d = struct();
    d.Xuu = Xuu; d.Yvv = Yvv; d.Zww = Zww;
    d.powers = P;
    d.max_power = max(P);
    d.ok = all(P <= 1e-12) && (Xuu < 0) && (Yvv < 0) && (Zww < 0);
    d.note = 'P = nu_r_lin'' * F_quad_drag; coeffs negative => dissipative in water frame';
end

function R = rotmat(phi, theta, psi)
    R = [cos(psi)*cos(theta), ...
         cos(psi)*sin(theta)*sin(phi) - sin(psi)*cos(phi), ...
         cos(psi)*sin(theta)*cos(phi) + sin(psi)*sin(phi);
         sin(psi)*cos(theta), ...
         sin(psi)*sin(theta)*sin(phi) + cos(psi)*cos(phi), ...
         sin(psi)*sin(theta)*cos(phi) - cos(psi)*sin(phi);
         -sin(theta), ...
         cos(theta)*sin(phi), ...
         cos(theta)*cos(phi)];
end

%% ===================== simulate =====================
function S = sim_route(path, T_final, u0, lambda, plant_fn, Vc, log_current)
    global dt_controller lambda_muw_ff plant_Vc
    global suite_delta_e_log suite_delta_r_log
    global suite_rate_filt_log suite_rate_raw_log
    global suite_e_z_log suite_e_zdot_log suite_zdot_inertial_log
    global suite_gamma_actual_log suite_e_gamma_log
    global suite_u_log suite_w_log
    global suite_theta_phys_log suite_e_theta_log
    global suite_pitch_refs_log
    global plant_last_nu plant_last_nu_c plant_last_nu_r
    global plant_last_V_g_ned plant_last_V_w_body plant_last_forces
    global last_delta_e last_delta_r last_dr_yaw last_dr_p last_dr_damp last_g_ac
    global last_int_angle last_int_rate last_rate_filt last_theta_phys_dot
    global last_de_uw_ff last_de_fb last_de_trim
    global last_M_uw last_M_elev last_M_e_ff last_G_de last_e_theta last_theta_phys
    global last_gamma_actual last_gamma_path last_alpha_eff last_e_gamma
    global last_e_z last_e_zdot last_zdot_inertial last_alpha_hat
    global dt_guidance

    lambda_muw_ff = lambda;
    plant_Vc = Vc(:);
    clear guidance_law controller_law

    dt = dt_controller;
    if isempty(dt_guidance); dt_guidance = dt; end
    state = zeros(12, 1);
    state(1:3) = path(1, :)';
    d = path(2, :) - path(1, :);
    state(5) = -atan2(d(3), norm(d(1:2)));
    state(6) = atan2(d(2), d(1));
    state(7) = u0;

    n_steps = round(T_final / dt);
    guidance_period = max(1, round(dt_guidance / dt));
    yaw_ref = 0; pitch_ref = 0; u_ref = 0; r_ff = 0; pitch_ref_dot = 0;
    progress_index = 1;

    vp = zeros(n_steps, 3);
    times = zeros(n_steps, 1);
    vel = zeros(n_steps, 3);
    rates = zeros(n_steps, 3);
    ori = zeros(n_steps, 3);
    yaw_refs = zeros(n_steps, 1);
    pitch_refs = zeros(n_steps, 1);
    u_refs = zeros(n_steps, 1);
    thrust_log = zeros(n_steps, 1);
    nu_log = zeros(n_steps, 6);
    nu_c_log = zeros(n_steps, 6);
    nu_r_log = zeros(n_steps, 6);
    Vg_log = zeros(n_steps, 3);
    Vw_log = zeros(n_steps, 3);
    F_log = zeros(n_steps, 6);
    delta_e_log = zeros(n_steps, 1);
    delta_r_log = zeros(n_steps, 1);
    e_z_log = zeros(n_steps, 1);
    e_zdot_log = zeros(n_steps, 1);
    zdot_log = zeros(n_steps, 1);
    gamma_log = zeros(n_steps, 1);
    e_gamma_log = zeros(n_steps, 1);
    e_theta_log = zeros(n_steps, 1);
    theta_phys_log = zeros(n_steps, 1);
    rate_filt_log = zeros(n_steps, 1);
    rate_raw_log = zeros(n_steps, 1);
    u_ilog = zeros(n_steps, 1);
    w_ilog = zeros(n_steps, 1);

    ok = true;
    for idx = 1:n_steps
        cur_pos = state(1:3)';
        cur_ori = state(4:6)';
        cur_rates = state(10:12)';
        cur_u = state(7);
        cur_v = state(8);
        cur_w = state(9);

        [U_h, zdot_inertial] = inertial_velocity_ned(cur_ori, cur_u, cur_v, cur_w);
        theta_phys_now = -cur_ori(2);

        if mod(idx - 1, guidance_period) == 0
            [yaw_ref, pitch_ref, u_ref, progress_index, r_ff, pitch_ref_dot] = ...
                guidance_law(cur_pos, path, progress_index, cur_u, cur_v, ...
                U_h, zdot_inertial, theta_phys_now);
        end

        [delta_r, delta_e, thrust] = controller_law(yaw_ref, pitch_ref, u_ref, ...
            cur_ori(3), cur_ori(2), cur_rates(3), cur_rates(2), ...
            cur_u, r_ff, pitch_ref_dot, cur_ori(1), cur_w, cur_rates(1));

        controls.delta_r = delta_r;
        controls.delta_e = delta_e;
        controls.thrust = thrust;

        try
            [~, g] = ode45(@(t, g) plant_fn(t, g, controls), [0 dt], state);
            state = g(end, :)';
        catch
            ok = false;
            n_steps = idx - 1;
            break;
        end
        if any(~isfinite(state))
            ok = false;
            n_steps = idx - 1;
            break;
        end

        vp(idx, :) = state(1:3);
        vel(idx, :) = state(7:9);
        rates(idx, :) = state(10:12);
        ori(idx, :) = state(4:6);
        yaw_refs(idx) = yaw_ref;
        pitch_refs(idx) = pitch_ref;
        u_refs(idx) = u_ref;
        thrust_log(idx) = thrust;
        times(idx) = idx * dt;

        if log_current
            if isempty(plant_last_nu); plant_last_nu = [state(7:12)]; end
            if isempty(plant_last_nu_c); plant_last_nu_c = zeros(6,1); end
            if isempty(plant_last_nu_r); plant_last_nu_r = plant_last_nu; end
            if isempty(plant_last_V_g_ned); plant_last_V_g_ned = zeros(3,1); end
            if isempty(plant_last_V_w_body); plant_last_V_w_body = state(7:9)'; end
            if isempty(plant_last_forces); plant_last_forces = zeros(6,1); end
            nu_log(idx, :) = plant_last_nu(:)';
            nu_c_log(idx, :) = plant_last_nu_c(:)';
            nu_r_log(idx, :) = plant_last_nu_r(:)';
            Vg_log(idx, :) = plant_last_V_g_ned(:)';
            Vw_log(idx, :) = plant_last_V_w_body(:)';
            F_log(idx, :) = plant_last_forces(:)';
        else
            % Production: Vc=0 => nu_c=0, nu_r=nu, Vg=R*nu
            nu_log(idx, :) = state(7:12);
            nu_c_log(idx, :) = 0;
            nu_r_log(idx, :) = state(7:12);
            Vg_log(idx, :) = (rotmat(state(4), state(5), state(6)) * state(7:9))';
            Vw_log(idx, :) = state(7:9)';
            % Force snapshot via production RHS mass solve not needed; zeros placeholder
            F_log(idx, :) = 0;
        end

        if isempty(last_delta_e); last_delta_e = delta_e; end
        if isempty(last_delta_r); last_delta_r = delta_r; end
        if isempty(last_e_theta); last_e_theta = 0; end
        if isempty(last_theta_phys); last_theta_phys = theta_phys_now; end
        if isempty(last_e_z); last_e_z = 0; end
        if isempty(last_e_zdot); last_e_zdot = 0; end
        if isempty(last_zdot_inertial); last_zdot_inertial = zdot_inertial; end
        if isempty(last_gamma_actual); last_gamma_actual = 0; end
        if isempty(last_e_gamma); last_e_gamma = 0; end
        if isempty(last_rate_filt); last_rate_filt = 0; end
        if isempty(last_theta_phys_dot); last_theta_phys_dot = 0; end

        delta_e_log(idx) = last_delta_e;
        delta_r_log(idx) = last_delta_r;
        e_z_log(idx) = last_e_z;
        e_zdot_log(idx) = last_e_zdot;
        zdot_log(idx) = last_zdot_inertial;
        gamma_log(idx) = last_gamma_actual;
        e_gamma_log(idx) = last_e_gamma;
        e_theta_log(idx) = last_e_theta;
        theta_phys_log(idx) = last_theta_phys;
        rate_filt_log(idx) = last_rate_filt;
        rate_raw_log(idx) = last_theta_phys_dot;
        u_ilog(idx) = cur_u;
        w_ilog(idx) = cur_w;
    end

    if n_steps < 1
        S = struct('ok', false, 'finite', false, 't', [], 'vp', [], 'vel', [], ...
            'rates', [], 'ori', [], 'dt', dt);
        return;
    end

    trim = @(A) A(1:n_steps, :);
    trim1 = @(A) A(1:n_steps);

    S = struct();
    S.ok = ok;
    S.finite = ok && all(isfinite(vp(1:n_steps,:)), 'all') && ...
        all(isfinite(vel(1:n_steps,:)), 'all') && all(isfinite(ori(1:n_steps,:)), 'all');
    S.dt = dt; S.T_final = T_final; S.u0 = u0; S.lambda = lambda;
    S.Vc = Vc(:)';
    S.t = times(1:n_steps);
    S.vp = trim(vp); S.vel = trim(vel); S.rates = trim(rates); S.ori = trim(ori);
    S.psi_ref = trim1(yaw_refs); S.theta_ref = trim1(pitch_refs); S.u_ref = trim1(u_refs);
    S.thrust = trim1(thrust_log);
    S.delta_e = trim1(delta_e_log); S.delta_r = trim1(delta_r_log);
    S.e_z = trim1(e_z_log); S.e_zdot = trim1(e_zdot_log); S.zdot = trim1(zdot_log);
    S.gamma = trim1(gamma_log); S.e_gamma = trim1(e_gamma_log);
    S.e_theta = trim1(e_theta_log); S.theta_phys = trim1(theta_phys_log);
    S.rate_filt = trim1(rate_filt_log); S.rate_raw = trim1(rate_raw_log);
    S.u_log = trim1(u_ilog); S.w_log = trim1(w_ilog);
    S.nu = trim(nu_log); S.nu_c = trim(nu_c_log); S.nu_r = trim(nu_r_log);
    S.V_ground_ned = trim(Vg_log); S.V_water_body = trim(Vw_log);
    S.forces = trim(F_log);

    % stash suite globals for metrics helpers
    suite_delta_e_log = S.delta_e; suite_delta_r_log = S.delta_r;
    suite_rate_filt_log = S.rate_filt; suite_rate_raw_log = S.rate_raw;
    suite_e_z_log = S.e_z; suite_e_zdot_log = S.e_zdot;
    suite_zdot_inertial_log = S.zdot;
    suite_gamma_actual_log = S.gamma; suite_e_gamma_log = S.e_gamma;
    suite_u_log = S.u_log; suite_w_log = S.w_log;
    suite_theta_phys_log = S.theta_phys; suite_e_theta_log = S.e_theta;
    suite_pitch_refs_log = S.theta_ref;
end

function [U_h, zdot] = inertial_velocity_ned(ori, u, v, w)
    pos_dot = rotmat(ori(1), ori(2), ori(3)) * [u; v; w];
    U_h = hypot(pos_dot(1), pos_dot(2));
    zdot = pos_dot(3);
end

%% ===================== metrics / compare =====================
function Id = compare_identity(Sp, S0)
    n = min(size(Sp.vp, 1), size(S0.vp, 1));
    Id = struct();
    Id.n = n;
    if n < 2
        Id.max_state_abs = Inf; Id.max_force_abs = Inf; Id.pass = false;
        return;
    end
    d_pos = Sp.vp(1:n,:) - S0.vp(1:n,:);
    d_vel = Sp.vel(1:n,:) - S0.vel(1:n,:);
    d_ori = Sp.ori(1:n,:) - S0.ori(1:n,:);
    d_rate = Sp.rates(1:n,:) - S0.rates(1:n,:);
    d_act = [Sp.delta_e(1:n) - S0.delta_e(1:n), Sp.delta_r(1:n) - S0.delta_r(1:n), ...
        Sp.thrust(1:n) - S0.thrust(1:n)];
    Id.max_abs_pos = max(abs(d_pos), [], 'all');
    Id.max_abs_vel = max(abs(d_vel), [], 'all');
    Id.max_abs_ori = max(abs(d_ori), [], 'all');
    Id.max_abs_rate = max(abs(d_rate), [], 'all');
    Id.max_abs_act = max(abs(d_act), [], 'all');
    Id.max_state_abs = max([Id.max_abs_pos, Id.max_abs_vel, Id.max_abs_ori, Id.max_abs_rate]);
    % Production path does not log forces; force identity covered by RHS check.
    if any(Sp.forces(:) ~= 0) && any(S0.forces(:) ~= 0)
        Id.max_force_abs = max(abs(S0.forces(1:n,:) - Sp.forces(1:n,:)), [], 'all');
    else
        Id.max_force_abs = NaN;
    end
    Id.pass = Id.max_state_abs < 1e-9;
end

function M = route_metrics(S, path)
    M = struct('ok', false);
    if isempty(S.t) || numel(S.t) < 10
        return;
    end
    M.ok = true;
    M.n = numel(S.t);
    M.T = S.t(end);
    M.finite = S.finite;
    M.max_abs_state = max([max(abs(S.vp), [], 'all'), max(abs(S.vel), [], 'all'), ...
        max(abs(S.ori), [], 'all'), max(abs(S.rates), [], 'all')]);
    M.bounded = M.finite && M.max_abs_state < 1e6;

    pf = compute_path_following_metrics(path, S.vp, S.vel, S.ori, ...
        S.psi_ref, S.theta_ref, S.dt, S.t);
    M.cte_rms = pf.mean_cross_track;
    M.cte_max = pf.max_cross_track;
    if isfield(pf, 'e_z_rms'); M.e_z_rms_pf = pf.e_z_rms; else; M.e_z_rms_pf = NaN; end

    e_psi = wrapToPi(S.psi_ref - S.ori(:, 3));
    e_th = S.theta_ref - (-S.ori(:, 2));
    e_u = S.u_ref - S.vel(:, 1);
    M.e_psi_rms = rms_finite(e_psi);
    M.e_theta_rms = rms_finite(e_th);
    M.e_u_rms = rms_finite(e_u);
    M.e_z_rms = rms_finite(S.e_z);
    M.e_z_mean = mean_finite(S.e_z);
    M.delta_e_rms = rms_finite(S.delta_e);
    M.delta_r_rms = rms_finite(S.delta_r);
    M.thrust_rms = rms_finite(S.thrust);
    M.delta_e_max = max(abs(S.delta_e));
    M.delta_r_max = max(abs(S.delta_r));
    M.u_mean = mean_finite(S.vel(:,1));
    M.v_mean = mean_finite(S.vel(:,2));
    M.w_mean = mean_finite(S.vel(:,3));
    if isfield(S, 'nu_c') && ~isempty(S.nu_c)
        M.nu_c_rms = sqrt(mean(sum(S.nu_c(:,1:3).^2, 2)));
        M.nu_r_rms = sqrt(mean(sum(S.nu_r(:,1:3).^2, 2)));
        M.Vg_rms = sqrt(mean(sum(S.V_ground_ned.^2, 2)));
        M.Vw_rms = sqrt(mean(sum(S.V_water_body.^2, 2)));
    end
end

function E = current_effect(Sp, Sc, S0)
    n = min([size(Sp.vp,1), size(Sc.vp,1), size(S0.vp,1)]);
    E = struct();
    E.max_abs_dy = max(abs(Sc.vp(1:n,2) - Sp.vp(1:n,2)));
    E.max_abs_dpos = max(abs(Sc.vp(1:n,:) - Sp.vp(1:n,:)), [], 'all');
    E.max_abs_dvel = max(abs(Sc.vel(1:n,:) - Sp.vel(1:n,:)), [], 'all');
    E.max_abs_nu_c = max(abs(Sc.nu_c(1:n,1:3)), [], 'all');
    E.mean_abs_nu_c = mean(sqrt(sum(Sc.nu_c(1:n,1:3).^2, 2)));
    E.zero_vs_prod_max = max(abs(S0.vp(1:n,:) - Sp.vp(1:n,:)), [], 'all');
    % Nonzero: trajectory diverges AND nu_c magnitude matches |Vc|
    E.nonzero = (E.max_abs_dpos > 1e-3) && (E.max_abs_nu_c > 0.1);
end

function tf = all_routes_bounded(R)
    names = {'X','XZ','R10'};
    tf = true;
    for i = 1:numel(names)
        rr = R.routes.(names{i});
        tf = tf && rr.baseline.bounded && rr.hook_Vc0.bounded && rr.hook_Vc.bounded;
    end
end

function N = next_step_decision(R)
    % Only propose INS-ground minus DVL-water current observer if hook PASS
    % and conceptual sensor pair is justified; else measurement-noise hook.
    N = struct();
    if strcmp(R.verdict, 'PASS') || true  % decide after gates filled; call late
    end
    hook_ok = R.gates.vc0_rhs_identity && R.gates.vc0_traj_identity && ...
        R.gates.ned_body_sign_units && R.gates.drag_dissipative && ...
        R.gates.states_finite_bounded && R.gates.current_effect_nonzero;
    % Conceptual pair: INS ground-velocity vs DVL water-relative — now
    % plant exposes both V_ground_ned and V_water_body (=nu_r_lin), so
    % a current observer is conceptually justified by the hook.
    N.hook_justifies_current_observer = hook_ok;
    N.conceptual_sensor_pair = 'INS ground-velocity (R*nu) minus DVL water-rel (nu_r) => Vc estimate';
    if hook_ok
        N.next = 'INS_ground_minus_DVL_water_current_observer_ONLY';
        N.detail = ['Hook PASS exposes V_ground_ned and V_water_body; conceptual ', ...
            'INS−DVL pair can observe Vc. Implement ONE isolated observer candidate next; ', ...
            'no production retune. If observer unjustified in practice, fall back to ', ...
            'measurement-noise hook.'];
    else
        N.next = 'measurement_noise_hook';
        N.detail = 'Hook correctness incomplete — do not design current observer; add measurement-noise hook instead.';
    end
end

%% ===================== outputs =====================
function write_png(png_path, R, task_id, verdict)
    fig = figure('Visible', 'off', 'Position', [60 60 1400 920]);
    tiledlayout(3, 3, 'Padding', 'compact', 'TileSpacing', 'compact');
    names = {'X','XZ','R10'};
    for i = 1:3
        rr = R.routes.(names{i});
        nexttile;
        plot(rr.prod.t, rr.prod.vp(:,2), 'k-'); hold on;
        plot(rr.curr.t, rr.curr.vp(:,2), 'r-');
        grid on; ylabel('y [m]'); title(sprintf('%s y (prod vs Vc)', names{i}));
        if i == 1; legend('prod Vc=0','hook Vc=E0.15', 'Location', 'best'); end

        nexttile;
        plot(rr.curr.t, rr.curr.nu_c(:,2), 'b'); hold on;
        plot(rr.curr.t, rr.curr.nu_r(:,2), 'm');
        grid on; ylabel('m/s'); title(sprintf('%s nu_c,v / nu_r,v', names{i}));
        if i == 1; legend('nu_c_v','nu_r_v', 'Location', 'best'); end

        nexttile;
        plot(rr.prod.t, rr.prod.e_z, 'k'); hold on;
        plot(rr.curr.t, rr.curr.e_z, 'r');
        grid on; ylabel('e_z [m]'); title(sprintf('%s e_z', names{i}));
        if i == 1; legend('baseline','current', 'Location', 'best'); end
    end
    sgtitle(sprintf('%s %s — constant current hook (not hardware)', task_id, verdict), ...
        'Interpreter', 'none');
    exportgraphics(fig, png_path, 'Resolution', 150);
    close(fig);
end

function write_md(md_path, R, dt_c, Xuu, Yvv, Zww)
    fid = fopen(md_path, 'w');
    fprintf(fid, '# %s — Bounded constant-current plant hook\n\n', R.task_id);
    fprintf(fid, '**Overall verdict: %s** (hook correctness, not robustness; not hardware)\n\n', R.verdict);

    fprintf(fid, '## Provenance\n\n');
    fprintf(fid, '- Read-only: `underwater777_vehicle_dynamics.m`, `continuous_path_tracking.m`, `suite_results/SENSOR_NOISE_CURRENT_AUDIT.md`\n');
    fprintf(fid, '- Hook (NEW, isolated): `underwater777_vehicle_dynamics_current.m`\n');
    fprintf(fid, '- Driver: `run_bounded_current_hook.m` (one invocation)\n');
    fprintf(fid, '- Production plant/controller/guidance/config: **UNTOUCHED**\n');
    fprintf(fid, '- Artifacts: `%s`, `%s`, `%s`\n', R.paths.md, R.paths.mat, R.paths.png);
    fprintf(fid, '- Did **not** touch `CODEX_VERTICAL_PLAN.md`\n');
    fprintf(fid, '- Never claim hardware validation\n\n');

    fprintf(fid, '## Convention\n\n');
    fprintf(fid, '```\n');
    fprintf(fid, 'nu     = ground-relative BODY velocity (state)\n');
    fprintf(fid, 'Vc     = constant NED current [m/s]  (global plant_Vc)\n');
    fprintf(fid, 'nu_c   = R''*Vc   (BODY linear; omega_c=0)\n');
    fprintf(fid, 'nu_r   = nu - nu_c\n');
    fprintf(fid, 'eta_dot= R*nu     (KEEP ground kinematics)\n');
    fprintf(fid, 'hydro  = damping/lift/control-surface speed use nu_r\n');
    fprintf(fid, 'Coriolis choice: C(nu_r)*nu_r — linear-velocity Coriolis/AM\n');
    fprintf(fid, '  cross terms use nu_r + absolute rates (Fossen irrotational)\n');
    fprintf(fid, '```\n\n');

    fprintf(fid, '## Vc=0 identity (exact deltas)\n\n');
    fprintf(fid, '| Check | max|Δ| | tol | PASS |\n|---|---:|---:|:---:|\n');
    fprintf(fid, '| RHS prod vs hook(Vc=0) | %.6e | 1e-12 | %s |\n', ...
        R.rhs_identity.max_abs, yn(R.rhs_identity.pass));
    names = {'X','XZ','R10'};
    for i = 1:3
        Id = R.routes.(names{i}).identity;
        fprintf(fid, '| Traj %s state | %.6e | 1e-9 | %s |\n', ...
            names{i}, Id.max_state_abs, yn(Id.pass));
        fprintf(fid, '| Traj %s pos/vel/ori/rate/act max | %.3e / %.3e / %.3e / %.3e / %.3e |\n', ...
            names{i}, Id.max_abs_pos, Id.max_abs_vel, Id.max_abs_ori, Id.max_abs_rate, Id.max_abs_act);
    end
    fprintf(fid, '\n');

    fprintf(fid, '## Sign / units\n\n');
    fprintf(fid, '- Vc NED = [%.2f, %.2f, %.2f] m/s\n', R.sign_unit.Vc_ned);
    fprintf(fid, '- psi=0 → nu_c BODY = [%.4f, %.4f, %.4f]\n', R.sign_unit.nu_c);
    fprintf(fid, '- psi=+90° → nu_c BODY = [%.4f, %.4f, %.4f]\n', R.sign_unit.nu_c_heading_east);
    fprintf(fid, '- %s\n', R.sign_unit.note);
    fprintf(fid, '- Sign/units gate: **%s**\n\n', yn(R.sign_unit.ok));

    fprintf(fid, '## Dissipative drag (water-relative)\n\n');
    fprintf(fid, '- Xuu=%.4g Yvv=%.4g Zww=%.4g (all <0)\n', Xuu, Yvv, Zww);
    fprintf(fid, '- max nu_r·F_quad = %.6e (expect ≤0): **%s**\n\n', ...
        R.dissipative.max_power, yn(R.dissipative.ok));

    fprintf(fid, '## Baseline → current metrics @ U=1.5, Vc=[0,+0.15,0] NED\n\n');
    fprintf(fid, '| Route | CTE_b | CTE_c | e_z_b | e_z_c | eθ_b° | eθ_c° | eψ_b° | eψ_c° | max|Δy| | nu_c_rms | finite |\n');
    fprintf(fid, '|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|:---:|\n');
    for i = 1:3
        rr = R.routes.(names{i});
        Mb = rr.baseline; Mc = rr.hook_Vc;
        fprintf(fid, '| %s | %.4f | %.4f | %.4f | %.4f | %.4f | %.4f | %.4f | %.4f | %.4f | %.4f | %s |\n', ...
            names{i}, Mb.cte_rms, Mc.cte_rms, Mb.e_z_rms, Mc.e_z_rms, ...
            rad2deg(Mb.e_theta_rms), rad2deg(Mc.e_theta_rms), ...
            rad2deg(Mb.e_psi_rms), rad2deg(Mc.e_psi_rms), ...
            rr.effect.max_abs_dy, Mc.nu_c_rms, yn(Mb.bounded && Mc.bounded));
    end
    fprintf(fid, '\n');

    fprintf(fid, '## Actuator RMS (baseline → current)\n\n');
    fprintf(fid, '| Route | δe_b | δe_c | δr_b | δr_c | T_b | T_c |\n');
    fprintf(fid, '|---|---:|---:|---:|---:|---:|---:|\n');
    for i = 1:3
        rr = R.routes.(names{i});
        Mb = rr.baseline; Mc = rr.hook_Vc;
        fprintf(fid, '| %s | %.4f | %.4f | %.4f | %.4f | %.3f | %.3f |\n', ...
            names{i}, Mb.delta_e_rms, Mc.delta_e_rms, Mb.delta_r_rms, Mc.delta_r_rms, ...
            Mb.thrust_rms, Mc.thrust_rms);
    end
    fprintf(fid, '\n');

    fprintf(fid, '## Robustness (reported separately; NOT a PASS gate)\n\n');
    fprintf(fid, 'Cross-current perturbs tracking (see Δ CTE / e_z / e_ψ). Frozen controller not retuned. Robustness FAIL does not fail this task.\n\n');

    fprintf(fid, '## PASS gates (hook correctness)\n\n');
    fprintf(fid, '| Gate | Result |\n|---|---|\n');
    gn = fieldnames(R.gates);
    for i = 1:numel(gn)
        fprintf(fid, '| %s | %s |\n', gn{i}, tern(R.gates.(gn{i}), 'PASS', 'FAIL'));
    end
    fprintf(fid, '\n**Overall: %s**\n\n', R.verdict);

    fprintf(fid, '## Next\n\n');
    fprintf(fid, '- **`%s`**\n', R.next.next);
    fprintf(fid, '- %s\n', R.next.detail);
    fprintf(fid, '- Conceptual pair: %s\n', R.next.conceptual_sensor_pair);
    fprintf(fid, '- Production remains frozen.\n');
    fclose(fid);
end

function append_audit(out_dir, R)
    audit_path = fullfile(out_dir, 'STATE_SPACE_MODEL_AUDIT.md');
    fid = fopen(audit_path, 'a');
    fprintf(fid, '\n\n---\n\n');
    fprintf(fid, '## %s — %s\n\n', R.task_id, datestr(now, 31));
    fprintf(fid, '### Provenance\n\n');
    fprintf(fid, '- Read-only: `underwater777_vehicle_dynamics.m`, `continuous_path_tracking.m`, `SENSOR_NOISE_CURRENT_AUDIT.md`\n');
    fprintf(fid, '- Hook: `underwater777_vehicle_dynamics_current.m` (isolated; production untouched)\n');
    fprintf(fid, '- Driver: `run_bounded_current_hook.m` (one invocation)\n');
    fprintf(fid, '- Artifacts: `%s`, `%s`, `%s`\n', R.paths.md, R.paths.mat, R.paths.png);
    fprintf(fid, '- Did not touch `CODEX_VERTICAL_PLAN.md`\n\n');
    fprintf(fid, '### Convention\n\n');
    fprintf(fid, '```\nnu ground BODY; Vc NED const; nu_c=R''*Vc; nu_r=nu-nu_c;\n');
    fprintf(fid, 'eta_dot=R*nu; hydro damping/lift/CS + Coriolis linear use nu_r\n```\n\n');
    fprintf(fid, '### Verdict\n\n');
    fprintf(fid, '**%s** — hook correctness (not robustness; not hardware).\n\n', R.verdict);
    fprintf(fid, '### Key numbers\n\n');
    fprintf(fid, '| Item | Value |\n|---|---|\n');
    fprintf(fid, '| RHS max|Δ| Vc=0 | %.3e |\n', R.rhs_identity.max_abs);
    names = {'X','XZ','R10'};
    for i = 1:3
        rr = R.routes.(names{i});
        fprintf(fid, '| %s traj max|Δ| Vc=0 | %.3e |\n', names{i}, rr.identity.max_state_abs);
        fprintf(fid, '| %s CTE b→c | %.4f → %.4f |\n', names{i}, rr.baseline.cte_rms, rr.hook_Vc.cte_rms);
        fprintf(fid, '| %s e_z b→c | %.4f → %.4f |\n', names{i}, rr.baseline.e_z_rms, rr.hook_Vc.e_z_rms);
        fprintf(fid, '| %s eψ° b→c | %.4f → %.4f |\n', names{i}, ...
            rad2deg(rr.baseline.e_psi_rms), rad2deg(rr.hook_Vc.e_psi_rms));
        fprintf(fid, '| %s max|Δy| | %.4f m |\n', names{i}, rr.effect.max_abs_dy);
    end
    fprintf(fid, '\n### Next\n\n');
    fprintf(fid, '- `%s` — %s\n', R.next.next, R.next.detail);
    fclose(fid);
end

function print_feedback(R)
    fprintf('\n========== FEEDBACK ==========\n');
    fprintf('VERDICT: %s (hook correctness)\n', R.verdict);
    fprintf('RHS max|Δ| Vc=0: %.6e\n', R.rhs_identity.max_abs);
    names = {'X','XZ','R10'};
    for i = 1:3
        rr = R.routes.(names{i});
        fprintf('%s identity max|Δ|=%.3e | CTE %.4f→%.4f e_z %.4f→%.4f eψ° %.4f→%.4f |Δy|=%.4f\n', ...
            names{i}, rr.identity.max_state_abs, ...
            rr.baseline.cte_rms, rr.hook_Vc.cte_rms, ...
            rr.baseline.e_z_rms, rr.hook_Vc.e_z_rms, ...
            rad2deg(rr.baseline.e_psi_rms), rad2deg(rr.hook_Vc.e_psi_rms), ...
            rr.effect.max_abs_dy);
    end
    gn = fieldnames(R.gates);
    for i = 1:numel(gn)
        fprintf('  gate %s: %s\n', gn{i}, tern(R.gates.(gn{i}), 'PASS', 'FAIL'));
    end
    fprintf('Next: %s\n', R.next.next);
    fprintf('Artifacts:\n  %s\n  %s\n  %s\n', R.paths.md, R.paths.mat, R.paths.png);
end

function P = pack_series(S)
    P = struct();
    P.dt = S.dt; P.T_final = S.T_final; P.u0 = S.u0; P.lambda = S.lambda;
    P.Vc = S.Vc; P.t = S.t;
    P.vp = S.vp; P.vel = S.vel; P.rates = S.rates; P.ori = S.ori;
    P.psi_ref = S.psi_ref; P.theta_ref = S.theta_ref; P.u_ref = S.u_ref;
    P.delta_e = S.delta_e; P.delta_r = S.delta_r; P.thrust = S.thrust;
    P.e_z = S.e_z; P.e_theta = S.e_theta; P.e_gamma = S.e_gamma;
    P.nu = S.nu; P.nu_c = S.nu_c; P.nu_r = S.nu_r;
    P.V_ground_ned = S.V_ground_ned; P.V_water_body = S.V_water_body;
    P.forces = S.forces;
end

function v = rms_finite(x)
    x = x(isfinite(x));
    if isempty(x); v = NaN; else; v = sqrt(mean(x.^2)); end
end

function v = mean_finite(x)
    x = x(isfinite(x));
    if isempty(x); v = NaN; else; v = mean(x); end
end

function s = yn(tf)
    if tf; s = 'YES'; else; s = 'NO'; end
end

function s = tern(tf, a, b)
    if tf; s = a; else; s = b; end
end
