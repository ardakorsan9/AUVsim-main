function run_trim_operating_points()
% TRIM_OPERATING_POINTS_001 — physically consistent operating points from
% PITCH_YAW_CLOSURE.mat + exact plant RHS underwater777_vehicle_dynamics.
% No controller / guidance / plant / gain edits.
% Distinguishes equilibrium, steady translating trim, and helix relative equilibrium.

    project_dir = fileparts(mfilename('fullpath'));
    addpath(project_dir);
    out_dir = fullfile(project_dir, 'suite_results');
    if ~exist(out_dir, 'dir'); mkdir(out_dir); end
    tag = 'TRIM_OPERATING_POINTS';

    clear functions
    clear guidance_law controller_law
    clear global lambda_muw_ff trim_speed_table trim_elevator_table elevator_sign
    clear global K_zdot K_gamma enable_alpha_hat
    clear global last_guidance_U_h last_guidance_kappa last_r_ff

    init_parameters();
    global lambda_muw_ff elevator_sign trim_speed_table trim_elevator_table
    global K_zdot K_gamma enable_alpha_hat
    global dt_controller thrust_trim Kp_x
    global delta_e_max delta_r_max

    elevator_sign = 1;
    trim_speed_table = [0.8 1.0 1.5 2.0];
    trim_elevator_table = deg2rad([-9.18 -7.33 -4.62 -3.17]);
    K_gamma = 0;
    K_zdot = 0;
    enable_alpha_hat = false;

    mat_in = fullfile(out_dir, 'pitch_yaw_closure.mat');
    if ~exist(mat_in, 'file')
        mat_in = fullfile(out_dir, 'PITCH_YAW_CLOSURE.mat');
    end
    C = load(mat_in);
    pathX = C.pathX; pathXZ = C.pathXZ; pathH = C.pathH;
    SH1 = C.SH{1}; MH1 = C.MH{1};
    mX1 = C.mX{1}; mXZ1 = C.mXZ{1};

    % Characteristic scales (SI; floors avoid division by near-zero)
    x_scale = [10; 10; 10; 1; 1; 1; 1.5; 0.3; 0.3; 0.2; 0.2; 0.2];
    u_scale = [deg2rad(25); deg2rad(15); 50];
    nu_dot_scale = [1.0; 0.3; 0.3; 0.2; 0.2; 0.2];  % m/s^2, rad/s^2
    pass_tol = 0.01;  % 1% normalized dynamic residual

    fprintf('\n========== TRIM_OPERATING_POINTS_001 ==========\n');
    fprintf('Source MAT: %s\n', mat_in);
    fprintf('Plant RHS: underwater777_vehicle_dynamics\n');

    %% ---- Capture closed-loop trajectories (X / XZ re-sim; helix from MAT) ----
    Traj = struct();
    Traj.X  = capture_pitch_traj(pathX, 18, 1.5, 0.25);
    Traj.XZ = capture_pitch_traj(pathXZ, 22, 1.5, 0.0);
    Traj.H  = capture_helix_from_SH(SH1, thrust_trim, Kp_x);

    % Prefer closure masks when lengths match; else recompute
    Traj.X.mask  = align_mask(mX1.logs.mask_steady, size(Traj.X.x, 1), Traj.X.t, mX1.logs.t);
    Traj.XZ.mask = align_mask(mXZ1.logs.mask_steady, size(Traj.XZ.x, 1), Traj.XZ.t, mXZ1.logs.t);
    Traj.H.mask  = align_mask(MH1.logs.mask_steady, size(Traj.H.x, 1), Traj.H.t, MH1.logs.t);
    if ~any(Traj.H.mask)
        Traj.H.mask = Traj.H.t >= 5.0 & Traj.H.t <= 0.88 * Traj.H.t(end);
    end

    %% ---- Operating points: window mean + residual + optional refine ----
    OP = struct();
    OP.level = analyze_translating(Traj.X, 'level_U15', pass_tol, ...
        x_scale, u_scale, nu_dot_scale, 0.0, true);
    OP.climb = analyze_translating(Traj.XZ, 'XZ_slope_z0p4x', pass_tol, ...
        x_scale, u_scale, nu_dot_scale, 0.4, true);
    OP.helix = analyze_helix(Traj.H, 10.0, pass_tol, x_scale, u_scale, nu_dot_scale, true);

    %% ---- Report / artifacts ----
    write_png(out_dir, tag, Traj, OP);
    write_md(out_dir, tag, mat_in, OP, pass_tol, x_scale, u_scale, nu_dot_scale);
    append_audit(out_dir, mat_in, OP, pass_tol, x_scale, u_scale, nu_dot_scale);

    task = struct('task_id', 'TRIM_OPERATING_POINTS_001', ...
        'pass_tol', pass_tol, 'mat_source', mat_in, ...
        'plant', 'underwater777_vehicle_dynamics', ...
        'controller_changed', false, 'plant_changed', false);
    save(fullfile(out_dir, [tag '.mat']), 'task', 'OP', 'Traj', 'pass_tol', ...
        'x_scale', 'u_scale', 'nu_dot_scale', '-v7.3');

    fprintf('\nLEVEL: %s  dyn_norm=%.4g  class=%s\n', yn(OP.level.pass), ...
        OP.level.norm_dyn_residual, OP.level.class);
    fprintf('CLIMB: %s  dyn_norm=%.4g  class=%s\n', yn(OP.climb.pass), ...
        OP.climb.norm_dyn_residual, OP.climb.class);
    fprintf('HELIX: %s  dyn_norm=%.4g  class=%s  LTI=%s\n', yn(OP.helix.pass), ...
        OP.helix.norm_dyn_residual, OP.helix.class, yn(OP.helix.lti_eligible));
    fprintf('Wrote suite_results/%s.{md,mat,png} + STATE_SPACE_MODEL_AUDIT.md\n', tag);
end

%% ===================== trajectory capture =====================
function T = capture_pitch_traj(path, T_final, u0, lambda)
    global dt_controller lambda_muw_ff thrust_trim Kp_x
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
    guidance_period = max(1, round(dt_guidance / dt));
    yaw_ref = 0; pitch_ref = 0; u_ref = u0; r_ff = 0; pitch_ref_dot = 0; pidx = 1;

    T = struct();
    T.dt = dt; T.T_final = T_final; T.u0 = u0; T.lambda = lambda;
    T.t = zeros(n_steps, 1);
    T.x = zeros(n_steps, 12);
    T.u = zeros(n_steps, 3);  % [delta_r, delta_e, thrust]
    T.u_ref = zeros(n_steps, 1);

    for k = 1:n_steps
        pos = state(1:3)';
        ori = state(4:6)';
        rates = state(10:12)';
        uu = state(7); vv = state(8); ww = state(9);
        [Uh, zdot] = inertial_Uh_zdot(ori, uu, vv, ww);
        theta_phys_now = -ori(2);

        if mod(k - 1, guidance_period) == 0
            [yaw_ref, pitch_ref, u_ref, pidx, r_ff, pitch_ref_dot] = ...
                guidance_law(pos, path, pidx, uu, vv, Uh, zdot, theta_phys_now);
        end
        [dr, de, thr] = controller_law(yaw_ref, pitch_ref, u_ref, ...
            ori(3), ori(2), rates(3), rates(2), uu, r_ff, pitch_ref_dot, ori(1), ww);
        controls = struct('delta_r', dr, 'delta_e', de, 'thrust', thr);
        [~, g] = ode45(@(tt, gg) underwater777_vehicle_dynamics(tt, gg, controls), ...
            [0 dt], state);
        state = g(end, :)';

        T.t(k) = k * dt;
        T.x(k, :) = state.';
        T.u(k, :) = [dr, de, thr];
        T.u_ref(k) = u_ref;
    end
end

function T = capture_helix_from_SH(S, thrust_trim, Kp_x)
    n = size(S.vp, 1);
    T = struct();
    T.dt = S.dt; T.T_final = S.T_final; T.u0 = S.u0; T.lambda = 0.25; T.R = S.R;
    T.t = S.t(:);
    T.x = zeros(n, 12);
    T.x(:, 1:3) = S.vp;
    T.x(:, 4:6) = S.ori;
    T.x(:, 7:9) = S.vel;
    T.x(:, 10:12) = S.rates;
    % Reconstruct thrust from frozen speed loop (exact controller equation)
    uref = S.u_ref(:);
    uu = S.vel(:, 1);
    thr = thrust_trim + Kp_x * (uref - uu);
    T.u = [S.delta_r(:), S.delta_e(:), thr];
    T.u_ref = uref;
    T.kappa = S.kappa(:);
    T.U_h = S.U_h(:);
    T.r_ff = S.r_ff(:);
end

function mask = align_mask(mask_src, n, t_new, t_src)
    mask_src = mask_src(:);
    if numel(mask_src) == n
        mask = logical(mask_src);
        return;
    end
    % time-based nearest
    if numel(t_src) == numel(mask_src) && ~isempty(t_new)
        mask = false(n, 1);
        for i = 1:n
            [~, j] = min(abs(t_src(:) - t_new(i)));
            mask(i) = logical(mask_src(j));
        end
        return;
    end
    % fallback: last 40% of trajectory after t>=5
    t = t_new(:);
    mask = (t >= 5.0) & (t <= 0.88 * t(end));
end

%% ===================== level / climb translating trim =====================
function P = analyze_translating(Traj, name, pass_tol, x_scale, u_scale, nu_dot_scale, slope, do_refine)
    mask = Traj.mask(:);
    if ~any(mask)
        mask = Traj.t >= 5 & Traj.t <= 0.88 * Traj.t(end);
    end
    Xw = Traj.x(mask, :);
    Uw = Traj.u(mask, :);

    x_mean = mean(Xw, 1).';
    u_mean = mean(Uw, 1).';
    x_std = std(Xw, 0, 1).';
    u_std = std(Uw, 0, 1).';

    % Canonical OP: zero NED origin / heading for level; keep climb attitude
    x_star = x_mean;
    x_star(1:3) = 0;          % position free for translating trim
    if abs(slope) < 1e-12
        x_star(6) = 0;        % yaw free → set 0
    end
    u_star = u_mean;
    ctr = ustruct(u_star);

    f0 = underwater777_vehicle_dynamics(0, x_star, ctr);
    R0 = residual_pack(f0, x_scale, nu_dot_scale, 'translating', 0);

    P = base_point(name, 'steady_translating_trim', x_star, u_star, x_mean, u_mean, ...
        x_std, u_std, f0, R0, Traj, mask);
    P.slope_dz_dx = slope;
    P.source_window = sprintf('closure mask_steady (n=%d, t=[%.2f,%.2f])', ...
        nnz(mask), Traj.t(find(mask,1,'first')), Traj.t(find(mask,1,'last')));

    if do_refine
        P.refined = refine_translating(x_star, u_star, slope, nu_dot_scale);
        fr = underwater777_vehicle_dynamics(0, P.refined.x_star, ustruct(P.refined.u_star));
        Rr = residual_pack(fr, x_scale, nu_dot_scale, 'translating', 0);
        P.refined.f = fr;
        P.refined.residual = Rr;
        % Prefer refined if better
        if Rr.norm_dyn <= R0.norm_dyn
            P.x_star = P.refined.x_star;
            P.u_star = P.refined.u_star;
            P.f = fr;
            P.residual = Rr;
            P.used_refined = true;
        else
            P.used_refined = false;
        end
    else
        P.used_refined = false;
    end

    P.norm_dyn_residual = P.residual.norm_dyn;
    P.pass = P.norm_dyn_residual <= pass_tol;
    if abs(slope) < 1e-12
        P.class = 'steady_translating_trim (level U=1.5)';
    else
        P.class = sprintf('steady_translating_trim (climb z=%.3gx)', slope);
    end
    % Not a static equilibrium (pos_dot allowed nonzero)
    P.is_equilibrium = false;
    P.lti_eligible = P.pass;
end

function R = refine_translating(x0, u0, slope, nu_dot_scale)
    % Free: [theta, v, w, q, delta_e, thrust]  (level/climb sagittal + speed)
    % Fixed: u=x0(7) target speed, phi=p=r=0, psi=0, delta_r=0, pos=0
    Udes = x0(7);
    z0 = [x0(5); x0(8); x0(9); x0(11); u0(2); u0(3)];
    [z, exitflag] = local_newton(@(zz) translating_cost(zz, Udes, slope, nu_dot_scale), z0, 80);

    x = zeros(12, 1);
    x(5) = z(1); x(7) = Udes; x(8) = z(2); x(9) = z(3); x(11) = z(4);
    u = [0; z(5); z(6)];
    R = struct('x_star', x, 'u_star', u, 'exitflag', exitflag, 'z0', z0, 'z', z);
end

function c = translating_cost(z, Udes, slope, nu_dot_scale)
    x = zeros(12, 1);
    x(5) = z(1); x(7) = Udes; x(8) = z(2); x(9) = z(3); x(11) = z(4);
    ctr = ustruct([0; z(5); z(6)]);
    f = underwater777_vehicle_dynamics(0, x, ctr);
    % Dynamic: nu_dot scaled; attitude rates phi_dot,theta_dot ~0; psi_dot free(~0)
    nd = f(7:12) ./ nu_dot_scale;
    ad = f(4:5);  % phi_dot, theta_dot [rad/s]
    % Slope constraint on inertial velocity ratio (translating along path)
    xd = f(1); zd = f(3);
    if abs(slope) < 1e-12
        slope_err = zd;                 % level: no climb rate
    else
        slope_err = zd - slope * xd;    % climb: ż = slope * ẋ
    end
    c = [nd; ad / 0.05; slope_err / max(0.1, abs(Udes))];
end

%% ===================== helix relative equilibrium =====================
function P = analyze_helix(Traj, Rhelix, pass_tol, x_scale, u_scale, nu_dot_scale, do_refine)
    mask = Traj.mask(:);
    Xw = Traj.x(mask, :);
    Uw = Traj.u(mask, :);

    x_mean = mean(Xw, 1).';
    u_mean = mean(Uw, 1).';
    x_std = std(Xw, 0, 1).';
    u_std = std(Uw, 0, 1).';

    % Omega from mean yaw rate or Uh/R
    psi = Xw(:, 6);
    t = Traj.t(mask);
    psi_u = unwrap(psi);
    if numel(t) > 2
        Omega = (psi_u(end) - psi_u(1)) / max(t(end) - t(1), eps);
    else
        Omega = mean(Xw(:, 12));
    end
    Uh_mean = mean(hypot(hypot(Xw(:,7), Xw(:,8)), 0));  % rough
    if isfield(Traj, 'U_h')
        Uh_mean = mean(Traj.U_h(mask));
    end
    Omega_geom = sign(Omega) * abs(Uh_mean) / max(Rhelix, eps);

    x_star = x_mean;
    x_star(1:3) = [Rhelix; 0; 0];  % canonical point on circle
    x_star(6) = 0;                 % heading tangent for rotating frame
    u_star = u_mean;
    ctr = ustruct(u_star);

    f0 = underwater777_vehicle_dynamics(0, x_star, ctr);
    R0 = residual_pack(f0, x_scale, nu_dot_scale, 'helix', Omega);

    % Steadiness of body states (periodic if large std relative to scale)
    body_idx = [4 5 7 8 9 10 11 12];
    body_std_norm = max(abs(x_std(body_idx)) ./ x_scale(body_idx));

    P = base_point('helix_R10', 'rotating_frame_relative_equilibrium', ...
        x_star, u_star, x_mean, u_mean, x_std, u_std, f0, R0, Traj, mask);
    P.Omega = Omega;
    P.Omega_geom = Omega_geom;
    P.R = Rhelix;
    P.body_std_norm = body_std_norm;
    P.source_window = sprintf('closure mask_steady (n=%d, t=[%.2f,%.2f])', ...
        nnz(mask), Traj.t(find(mask,1,'first')), Traj.t(find(mask,1,'last')));

    if do_refine
        P.refined = refine_helix(x_star, u_star, Rhelix, Omega, nu_dot_scale);
        fr = underwater777_vehicle_dynamics(0, P.refined.x_star, ustruct(P.refined.u_star));
        Rr = residual_pack(fr, x_scale, nu_dot_scale, 'helix', Omega);
        P.refined.f = fr;
        P.refined.residual = Rr;
        if Rr.norm_dyn <= R0.norm_dyn
            P.x_star = P.refined.x_star;
            P.u_star = P.refined.u_star;
            P.f = fr;
            P.residual = Rr;
            P.used_refined = true;
        else
            P.used_refined = false;
        end
    else
        P.used_refined = false;
    end

    P.norm_dyn_residual = P.residual.norm_dyn;
    P.norm_rel_residual = P.residual.norm_rel;
    % Helix PASS only as relative equilibrium if rotating-frame residual <=1%
    P.pass = P.norm_rel_residual <= pass_tol;
    if P.pass
        P.class = 'rotating_frame_relative_equilibrium';
        P.lti_eligible = true;  % LTI about relative-eq in rotating frame only
    elseif body_std_norm > 0.05 || P.norm_dyn_residual > pass_tol
        P.class = 'periodic_or_quasi_steady (NOT ordinary LTI trim)';
        P.lti_eligible = false;
        P.pass = false;
    else
        P.class = 'quasi_steady_mean (NOT ordinary LTI trim)';
        P.lti_eligible = false;
        P.pass = false;
    end
    P.is_equilibrium = false;
end

function R = refine_helix(x0, u0, Rhelix, Omega, nu_dot_scale)
    % Free body/attitude/inputs for relative eq: [phi,theta,u,v,w,p,q,r, dr,de,thr]
    z0 = [x0(4); x0(5); x0(7:12); u0(:)];
    [z, exitflag] = local_newton(@(zz) helix_cost(zz, Rhelix, Omega, nu_dot_scale), z0, 100);
    x = zeros(12, 1);
    x(1) = Rhelix; x(2) = 0; x(3) = 0;
    x(4) = z(1); x(5) = z(2); x(6) = 0;
    x(7:12) = z(3:8);
    u = z(9:11);
    R = struct('x_star', x, 'u_star', u, 'exitflag', exitflag, 'z0', z0, 'z', z);
end

function [z, exitflag] = local_newton(fun, z0, maxit)
    % Damped Gauss-Newton (no Optimization Toolbox required)
    z = z0(:);
    exitflag = 0;
    for it = 1:maxit
        c = fun(z);
        c = c(:);
        nrm = norm(c);
        if nrm < 1e-10
            exitflag = 1;
            return;
        end
        m = numel(c); n = numel(z);
        J = zeros(m, n);
        for j = 1:n
            h = 1e-6 * max(1, abs(z(j)));
            zp = z; zp(j) = zp(j) + h;
            J(:, j) = (fun(zp) - c) / h;
        end
        step = -J \ c;
        if any(~isfinite(step))
            step = -pinv(J) * c;
        end
        alpha = 1.0;
        accepted = false;
        for ls = 1:8
            ztry = z + alpha * step;
            ctry = fun(ztry);
            if norm(ctry) < nrm
                z = ztry;
                accepted = true;
                break;
            end
            alpha = 0.5 * alpha;
        end
        if ~accepted
            exitflag = -2;
            return;
        end
        if norm(alpha * step) < 1e-12
            exitflag = 2;
            return;
        end
    end
    exitflag = -1;
end

function c = helix_cost(z, Rhelix, Omega, nu_dot_scale)
    x = zeros(12, 1);
    x(1) = Rhelix; x(4) = z(1); x(5) = z(2); x(6) = 0;
    x(7:12) = z(3:8);
    ctr = ustruct(z(9:11));
    f = underwater777_vehicle_dynamics(0, x, ctr);
    nd = f(7:12) ./ nu_dot_scale;
    % Relative kinematics: phi_dot, theta_dot ~0; psi_dot - Omega ~0
    kin = [f(4); f(5); f(6) - Omega] ./ [0.05; 0.05; 0.05];
    % Radial / vertical drift of NED velocity in rotating sense (approx):
    % at (R,0,0) with psi=0, want ẏ≈0? For CCW about z: ẋ≈0, ẏ≈Omega*R
    % Better: rho_dot = (x*xd + y*yd)/rho ≈ xd at (R,0)
    xd = f(1); yd = f(2); zd = f(3);
    rho_dot = xd;  % at (R,0,*)
    circ_err = yd - Omega * Rhelix;
    c = [nd; kin; rho_dot / 0.1; circ_err / 0.1; zd / 0.1];
end

%% ===================== residual helpers =====================
function R = residual_pack(f, x_scale, nu_dot_scale, mode, Omega)
    R = struct();
    R.f = f;
    R.eta_dot = f(1:6);
    R.nu_dot = f(7:12);
    R.nu_dot_norm_comp = abs(R.nu_dot) ./ nu_dot_scale;
    R.norm_dyn = max(R.nu_dot_norm_comp);
    R.eta_dot_norm_comp = abs(R.eta_dot) ./ x_scale(1:6);  % rough
    if strcmp(mode, 'helix')
        rel = [R.nu_dot; f(4); f(5); f(6) - Omega];
        rel_scale = [nu_dot_scale; 0.05; 0.05; 0.05];
        R.rel = rel;
        R.rel_norm_comp = abs(rel) ./ rel_scale;
        R.norm_rel = max(R.rel_norm_comp);
    else
        % translating: dynamic only for pass; kinematics allowed nonzero
        R.rel = R.nu_dot;
        R.rel_norm_comp = R.nu_dot_norm_comp;
        R.norm_rel = R.norm_dyn;
        R.att_rate = f(4:6);
    end
end

function P = base_point(name, class0, x_star, u_star, x_mean, u_mean, x_std, u_std, f, R, Traj, mask)
    P = struct();
    P.name = name;
    P.class = class0;
    P.x_star = x_star;
    P.u_star = u_star;
    P.x_mean_window = x_mean;
    P.u_mean_window = u_mean;
    P.x_std_window = x_std;
    P.u_std_window = u_std;
    P.f = f;
    P.residual = R;
    P.frames = struct( ...
        'state', '[x y z phi theta psi u v w p q r] NED + body', ...
        'eta', 'NED position [m], Euler ZYX [rad]', ...
        'nu', 'body linear [m/s], body rates [rad/s]', ...
        'theta_phys', 'theta_phys = -theta (controller / path pitch)', ...
        'inputs', 'u*=[delta_r; delta_e; thrust], rudder/elevator [rad], thrust [N]', ...
        'signs', 'elevator_sign=+1; +delta_e via Zuuds/Muuds as in plant RHS');
    P.n_window = nnz(mask);
    P.t_window = [Traj.t(find(mask,1,'first')), Traj.t(find(mask,1,'last'))];
end

function ctr = ustruct(u)
    u = u(:);
    ctr = struct('delta_r', u(1), 'delta_e', u(2), 'thrust', u(3));
end

function s = yn(tf)
    if tf; s = 'PASS'; else; s = 'FAIL'; end
end

%% ===================== plots =====================
function write_png(out_dir, tag, Traj, OP)
    fig = figure('Visible', 'off', 'Position', [50 50 1400 900]);

    names = {'X level', 'XZ climb', 'R10 helix'};
    Ts = {Traj.X, Traj.XZ, Traj.H};
    Os = {OP.level, OP.climb, OP.helix};

    for i = 1:3
        T = Ts{i}; O = Os{i}; mask = T.mask;
        subplot(3, 4, (i-1)*4 + 1);
        plot(T.t, T.x(:,7), 'b'); hold on;
        plot(T.t(mask), T.x(mask,7), 'r.');
        yline(O.x_star(7), 'k--');
        grid on; ylabel('u [m/s]'); title(sprintf('%s | %s', names{i}, tern(O.pass,'PASS','FAIL')));
        if i==3; xlabel('t [s]'); end

        subplot(3, 4, (i-1)*4 + 2);
        th_phys = -T.x(:,5);
        plot(T.t, rad2deg(th_phys), 'b'); hold on;
        plot(T.t(mask), rad2deg(th_phys(mask)), 'r.');
        yline(rad2deg(-O.x_star(5)), 'k--');
        grid on; ylabel('\theta_{phys} [deg]'); title('pitch steadiness');
        if i==3; xlabel('t [s]'); end

        subplot(3, 4, (i-1)*4 + 3);
        plot(T.t, rad2deg(T.u(:,2)), 'b'); hold on;
        plot(T.t, rad2deg(T.u(:,1)), 'g');
        plot(T.t(mask), rad2deg(T.u(mask,2)), 'r.');
        yline(rad2deg(O.u_star(2)), 'k--');
        grid on; ylabel('[deg]'); title('\delta_e (b) / \delta_r (g)');
        if i==3; xlabel('t [s]'); end

        subplot(3, 4, (i-1)*4 + 4);
        fcomp = O.f;
        bar(1:12, fcomp); grid on;
        ylabel('f(x*,u*)'); title(sprintf('resid dyn=%.3g%%', 100*O.norm_dyn_residual));
        set(gca, 'XTick', 1:12, 'XTickLabel', ...
            {'ẋ','ẏ','ż','φ̇','θ̇','ψ̇','u̇','v̇','ẇ','ṗ','q̇','ṙ'}, 'XTickLabelRotation', 45);
    end
    sgtitle(sprintf('%s | red=window, dashed=x*/u*', tag), 'Interpreter', 'none');
    exportgraphics(fig, fullfile(out_dir, [tag '.png']), 'Resolution', 140);
    close(fig);
end

function s = tern(c, a, b)
    if c; s = a; else; s = b; end
end

%% ===================== markdown =====================
function write_md(out_dir, tag, mat_in, OP, pass_tol, x_scale, u_scale, nu_dot_scale)
    fid = fopen(fullfile(out_dir, [tag '.md']), 'w');
    fprintf(fid, '# TRIM_OPERATING_POINTS\n\n');
    fprintf(fid, '**TASK_ID:** TRIM_OPERATING_POINTS_001\n');
    fprintf(fid, '**Date:** %s\n', datestr(now, 31));
    fprintf(fid, '**Plant RHS:** `underwater777_vehicle_dynamics`\n');
    fprintf(fid, '**Source MAT:** `%s`\n', mat_in);
    fprintf(fid, '**Pass tol:** normalized dynamic / rotating-frame residual ≤ %.0f%%\n\n', 100*pass_tol);

    fprintf(fid, '## Classification rules\n\n');
    fprintf(fid, '| Class | Meaning | LTI about x*? |\n|------|---------|---------------|\n');
    fprintf(fid, '| equilibrium | η̇=0 and ν̇=0 | yes (hover) |\n');
    fprintf(fid, '| steady translating trim | ν̇≈0, attitude rates≈0; η̇ allowed (constant velocity) | yes (perturbation about body state) |\n');
    fprintf(fid, '| rotating-frame relative equilibrium | ν̇≈0 and (φ̇,θ̇,ψ̇−Ω)≈0 | yes **only in rotating frame** |\n');
    fprintf(fid, '| periodic / quasi-steady | body state not constant enough or residual > tol | **no** ordinary LTI trim |\n\n');

    fprintf(fid, '## Scaling\n\n');
    fprintf(fid, '```\n');
    fprintf(fid, 'x_scale = [%s]\n', sprintf('%.3g ', x_scale));
    fprintf(fid, 'u_scale = [%s]\n', sprintf('%.3g ', u_scale));
    fprintf(fid, 'nu_dot_scale = [%s]  %% m/s^2, rad/s^2\n', sprintf('%.3g ', nu_dot_scale));
    fprintf(fid, 'norm_dyn = max_i |nu_dot_i|/nu_dot_scale_i\n');
    fprintf(fid, '```\n\n');

    write_point_md(fid, OP.level, pass_tol);
    write_point_md(fid, OP.climb, pass_tol);
    write_point_md(fid, OP.helix, pass_tol);

    fprintf(fid, '## Verdict summary\n\n');
    fprintf(fid, '| Point | Class | PASS | norm_dyn | notes |\n');
    fprintf(fid, '|-------|-------|:----:|---------:|-------|\n');
    fprintf(fid, '| Level U=1.5 | %s | %s | %.4g | LTI=%s |\n', ...
        OP.level.class, yn(OP.level.pass), OP.level.norm_dyn_residual, yn(OP.level.lti_eligible));
    fprintf(fid, '| XZ z=0.4x | %s | %s | %.4g | LTI=%s |\n', ...
        OP.climb.class, yn(OP.climb.pass), OP.climb.norm_dyn_residual, yn(OP.climb.lti_eligible));
    if isfield(OP.helix, 'norm_rel_residual')
        reln = OP.helix.norm_rel_residual;
    else
        reln = OP.helix.norm_dyn_residual;
    end
    fprintf(fid, '| R10 helix | %s | %s | dyn=%.4g rel=%.4g | LTI=%s |\n\n', ...
        OP.helix.class, yn(OP.helix.pass), OP.helix.norm_dyn_residual, reln, ...
        yn(OP.helix.lti_eligible));

    fprintf(fid, '## Artifacts\n\n');
    fprintf(fid, '- `suite_results/TRIM_OPERATING_POINTS.md`\n');
    fprintf(fid, '- `suite_results/TRIM_OPERATING_POINTS.mat`\n');
    fprintf(fid, '- `suite_results/TRIM_OPERATING_POINTS.png`\n');
    fprintf(fid, '- `suite_results/STATE_SPACE_MODEL_AUDIT.md`\n');
    fprintf(fid, '- `CODEX_VERTICAL_PLAN.md` untouched; controller/plant frozen.\n\n');

    fprintf(fid, '## Next\n\n');
    fprintf(fid, 'Linearize only LTI-eligible points (level/climb; helix only if relative-eq PASS). ');
    fprintf(fid, 'Do not treat helix as ordinary inertial LTI trim if classified periodic/quasi-steady.\n');
    fclose(fid);
end

function write_point_md(fid, P, pass_tol)
    fprintf(fid, '## %s — **%s**\n\n', P.name, yn(P.pass));
    fprintf(fid, '- **Class:** %s\n', P.class);
    fprintf(fid, '- **Source window:** %s\n', P.source_window);
    fprintf(fid, '- **Frames/units/signs:** state NED+body SI; u*=[δr,δe,thrust] rad/rad/N; θ_phys=-θ; elev_sign=+1\n');
    if isfield(P, 'used_refined')
        fprintf(fid, '- **Refined solver used:** %s\n', tern(P.used_refined, 'yes', 'no (window mean better/kept)'));
    end
    fprintf(fid, '\n### x* = [η; ν]\n\n');
    fprintf(fid, '```\n');
    fprintf(fid, 'x* = [%s]\n', sprintf('%.6g ', P.x_star));
    fprintf(fid, 'mean(window) = [%s]\n', sprintf('%.6g ', P.x_mean_window));
    fprintf(fid, 'std(window)  = [%s]\n', sprintf('%.3g ', P.x_std_window));
    fprintf(fid, '```\n\n');
    fprintf(fid, '### u*\n\n');
    fprintf(fid, '```\n');
    fprintf(fid, 'u* = [delta_r=%.6g rad (%.4f deg), delta_e=%.6g rad (%.4f deg), thrust=%.6g N]\n', ...
        P.u_star(1), rad2deg(P.u_star(1)), P.u_star(2), rad2deg(P.u_star(2)), P.u_star(3));
    fprintf(fid, 'mean(window) = [%s]\n', sprintf('%.6g ', P.u_mean_window));
    fprintf(fid, 'std(window)  = [%s]\n', sprintf('%.3g ', P.u_std_window));
    fprintf(fid, '```\n\n');
    fprintf(fid, '### f(x*,u*) components\n\n');
    fprintf(fid, '```\n');
    fprintf(fid, 'eta_dot = [%s]\n', sprintf('%.6g ', P.f(1:6)));
    fprintf(fid, 'nu_dot  = [%s]\n', sprintf('%.6g ', P.f(7:12)));
    fprintf(fid, 'nu_dot_norm_comp = [%s]\n', sprintf('%.4g ', P.residual.nu_dot_norm_comp));
    fprintf(fid, 'norm_dyn = %.6g  (PASS if <= %.2g)\n', P.norm_dyn_residual, pass_tol);
    if isfield(P, 'norm_rel_residual')
        fprintf(fid, 'norm_rel (rotating) = %.6g\n', P.norm_rel_residual);
        fprintf(fid, 'Omega = %.6g rad/s (geom Uh/R = %.6g)\n', P.Omega, P.Omega_geom);
    end
    fprintf(fid, '```\n\n');
end

%% ===================== STATE_SPACE_MODEL_AUDIT =====================
function [Uh, zdot] = inertial_Uh_zdot(ori, u, v, w)
    % Same NED mapping as continuous_path_tracking / closure driver
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
    v_ned = R * [u; v; w];
    Uh = hypot(v_ned(1), v_ned(2));
    zdot = v_ned(3);
end

function append_audit(out_dir, mat_in, OP, pass_tol, x_scale, u_scale, nu_dot_scale)
    path_audit = fullfile(out_dir, 'STATE_SPACE_MODEL_AUDIT.md');
    exists = exist(path_audit, 'file') == 2;
    fid = fopen(path_audit, tern(exists, 'a', 'w'));
    if ~exists
        fprintf(fid, '# STATE_SPACE_MODEL_AUDIT\n\n');
        fprintf(fid, 'Living audit of plant equations, trim operating points, and linearization provenance.\n');
        fprintf(fid, 'Controller/guidance/plant production stack frozen unless a later task explicitly changes them.\n\n');
    end

    fprintf(fid, '\n---\n\n## TRIM_OPERATING_POINTS_001 — %s\n\n', datestr(now, 31));
    fprintf(fid, '### Provenance\n\n');
    fprintf(fid, '- Closure evidence: `%s` (PITCH_YAW_CLOSURE PASS)\n', mat_in);
    fprintf(fid, '- Exact plant RHS: `underwater777_vehicle_dynamics.m`\n');
    fprintf(fid, '- Actuator law (read-only): `controller_law.m` (no edits)\n');
    fprintf(fid, '- Driver: `run_trim_operating_points.m`\n');
    fprintf(fid, '- Artifacts: `suite_results/TRIM_OPERATING_POINTS.{md,mat,png}`\n\n');

    fprintf(fid, '### Plant equations (exact RHS structure)\n\n');
    fprintf(fid, '```\n');
    fprintf(fid, 'State g = [η; ν] = [x y z φ θ ψ u v w p q r]^T\n');
    fprintf(fid, '  η in NED [m], Euler ZYX [rad]; ν body [m/s], body rates [rad/s]\n');
    fprintf(fid, 'Inputs: delta_r, delta_e [rad], thrust=Xprop [N]\n');
    fprintf(fid, 'Kinematics:\n');
    fprintf(fid, '  ṙ_pos = R(φ,θ,ψ) * [u;v;w]\n');
    fprintf(fid, '  [φ̇;θ̇;ψ̇] = J(φ,θ) * [p;q;r]\n');
    fprintf(fid, 'Dynamics:\n');
    fprintf(fid, '  A(ν) * ν̇ = τ(η,ν,u_act)   % A = rigid+added mass\n');
    fprintf(fid, '  τ = [X;Y;Z;K;M;N] hydro + restoring + control (Yuudr u² δr, Zuuds/Muuds u² δe, Xprop)\n');
    fprintf(fid, 'Sign convention: theta_phys = -theta (path/controller pitch)\n');
    fprintf(fid, '```\n\n');

    fprintf(fid, '### Assumptions for trim classes\n\n');
    fprintf(fid, '1. **Level U=1.5:** steady translating trim — seek ν̇≈0 with φ̇=θ̇≈0; ẋ allowed; ż≈0.\n');
    fprintf(fid, '2. **XZ z=0.4x:** steady translating trim along slope — ν̇≈0; ż≈0.4 ẋ.\n');
    fprintf(fid, '3. **R10 helix:** relative equilibrium in rotating frame (rate Ω≈ψ̇) — ν̇≈0 and (φ̇,θ̇,ψ̇−Ω)≈0.\n');
    fprintf(fid, '   If residual or body-state variance fails → classify periodic/quasi-steady; **exclude from ordinary inertial LTI**.\n');
    fprintf(fid, '4. Pass gate: max_i |ν̇_i|/scale_i ≤ %.0f%% (helix: rotating-frame residual).\n\n', 100*pass_tol);

    fprintf(fid, '### Operating-point results\n\n');
    fprintf(fid, '| Point | PASS | class | norm_dyn | LTI eligible |\n');
    fprintf(fid, '|-------|:----:|-------|---------:|:------------:|\n');
    fprintf(fid, '| Level | %s | %s | %.4g | %s |\n', yn(OP.level.pass), OP.level.class, OP.level.norm_dyn_residual, yn(OP.level.lti_eligible));
    fprintf(fid, '| Climb | %s | %s | %.4g | %s |\n', yn(OP.climb.pass), OP.climb.class, OP.climb.norm_dyn_residual, yn(OP.climb.lti_eligible));
    fprintf(fid, '| Helix | %s | %s | %.4g | %s |\n\n', yn(OP.helix.pass), OP.helix.class, OP.helix.norm_dyn_residual, yn(OP.helix.lti_eligible));

    fprintf(fid, '### x*, u* (canonical)\n\n');
    fprintf(fid, '```\n');
    fprintf(fid, 'LEVEL x*=[%s]\nLEVEL u*=[%s]\n', sprintf('%.6g ', OP.level.x_star), sprintf('%.6g ', OP.level.u_star));
    fprintf(fid, 'CLIMB x*=[%s]\nCLIMB u*=[%s]\n', sprintf('%.6g ', OP.climb.x_star), sprintf('%.6g ', OP.climb.u_star));
    fprintf(fid, 'HELIX x*=[%s]\nHELIX u*=[%s]\n', sprintf('%.6g ', OP.helix.x_star), sprintf('%.6g ', OP.helix.u_star));
    fprintf(fid, '```\n\n');

    fprintf(fid, '### Scaling used\n\n');
    fprintf(fid, '```\nx_scale=[%s]\nu_scale=[%s]\nnu_dot_scale=[%s]\n```\n\n', ...
        sprintf('%.3g ', x_scale), sprintf('%.3g ', u_scale), sprintf('%.3g ', nu_dot_scale));

    fprintf(fid, '### Next audit step\n\n');
    fprintf(fid, 'Numerical linearization (`numerical_linearize_auv`) only at LTI-eligible points; ');
    fprintf(fid, 'for helix use rotating-frame coordinates if relative-eq PASS, else skip ordinary A,B about inertial mean.\n');
    fclose(fid);
end
