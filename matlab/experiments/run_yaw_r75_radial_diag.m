function run_yaw_r75_radial_diag()
% RUN_YAW_R75_RADIAL_DIAG  YAW_RADIAL_R75_DIAG_001
% Analytic radial vs Frenet/normal vs reported CTE_perp on R=7.5 circle.
% Production stack only — no gain/FF/guidance/plant changes.
% Writes suite_results/YAW_R75_RADIAL_DIAG.md + MAT/CSV/PNG evidence.

    project_dir = fileparts(fileparts(fileparts(mfilename('fullpath')))); % repo root
    addpath(genpath(fullfile(project_dir, 'matlab')));
    out_dir = fullfile(project_dir, 'suite_results');
    if ~exist(out_dir, 'dir'); mkdir(out_dir); end

    clear functions
    clear guidance_law controller_law
    clear global lambda_muw_ff trim_speed_table trim_elevator_table elevator_sign
    clear global K_zdot K_gamma enable_alpha_hat
    clear global last_guidance_U_h last_guidance_kappa last_r_ff

    init_parameters();
    global lambda_muw_ff elevator_sign trim_speed_table trim_elevator_table
    global K_zdot K_gamma enable_alpha_hat
    global dt_controller dt_guidance tau_rate Ki_angle Ki_rate
    global delta_r_max desired_speed lookahead_distance

    % Frozen production stack
    elevator_sign = 1;
    trim_speed_table = [0.8 1.0 1.5 2.0];
    trim_elevator_table = deg2rad([-9.18 -7.33 -4.62 -3.17]);
    K_gamma = 0;
    K_zdot = 0;
    enable_alpha_hat = false;
    lambda_muw_ff = 0.25;

    R = 7.5;
    u0 = 1.5;
    % Circumference ~47.1 m; schedule u_ref≈1.125 → T_lap≈42 s.
    % Need ≥2 settled full turns after acquisition → T_final=120 s.
    T_final = 120;
    deterministic = true; % no RNG in plant/guidance/controller path

    fprintf('\n========== YAW_RADIAL_R75_DIAG_001 ==========\n');
    fprintf('R=%.1f  T=%.0fs  u0=%.2f  dt_c=%.4f dt_g=%.4f\n', ...
        R, T_final, u0, dt_controller, dt_guidance);
    fprintf('delta_r_max=%.2f deg (init_parameters)  L_look=%.2f  U_des=%.2f\n', ...
        rad2deg(delta_r_max), lookahead_distance, desired_speed);
    fprintf('Deterministic: %s (no seed)\n', tern(deterministic,'YES','NO'));

    S = simulate_circle(R, T_final, u0);
    A = analyze_circle(S, R, delta_r_max);
    write_outputs(out_dir, S, A, R, T_final, u0, deterministic, ...
        delta_r_max, dt_controller, dt_guidance, lookahead_distance, desired_speed);

    fprintf('\nClass: %s | Verdict: %s\n', A.root_class, A.verdict);
    fprintf('Wrote suite_results/YAW_R75_RADIAL_DIAG.md + evidence files\n');
end

%% ===================== simulate =====================
function S = simulate_circle(R, T_final, u0)
    global dt_controller dt_guidance
    global last_guidance_U_h last_guidance_kappa last_r_ff

    n = 600;
    th = linspace(0, 2*pi, n)';
    path = [R*cos(th), R*sin(th), zeros(n,1)];
    dt = dt_controller;
    n_steps = round(T_final / dt);
    guidance_period = max(1, round(dt_guidance / dt));

    state = zeros(12,1);
    state(1:3) = path(1,:)';
    d = path(2,:) - path(1,:);
    state(5) = -atan2(d(3), norm(d(1:2)));
    state(6) = atan2(d(2), d(1));
    state(7) = u0;

    yaw_ref = 0; pitch_ref = 0; u_ref = u0; r_ff = 0; pitch_ref_dot = 0; pidx = 1;

    S = struct();
    S.path = path;
    S.R = R;
    S.dt = dt;
    S.t = zeros(n_steps,1);
    S.x = zeros(n_steps,1); S.y = zeros(n_steps,1); S.z = zeros(n_steps,1);
    S.phi = zeros(n_steps,1); S.theta = zeros(n_steps,1); S.psi = zeros(n_steps,1);
    S.u = zeros(n_steps,1); S.v = zeros(n_steps,1); S.w = zeros(n_steps,1);
    S.p = zeros(n_steps,1); S.q = zeros(n_steps,1); S.r = zeros(n_steps,1);
    S.psi_ref = zeros(n_steps,1);
    S.r_ff = zeros(n_steps,1);
    S.U_h = zeros(n_steps,1);
    S.U_h_guid = zeros(n_steps,1);
    S.kappa = zeros(n_steps,1);
    S.delta_r = zeros(n_steps,1);
    S.u_ref = zeros(n_steps,1);
    S.vp = zeros(n_steps,3);

    for k = 1:n_steps
        pos = state(1:3)';
        ori = state(4:6)';
        rates = state(10:12)';
        u = state(7); v = state(8); w = state(9);
        Uh = inertial_Uh(ori, u, v, w);

        if mod(k - 1, guidance_period) == 0
            [yaw_ref, pitch_ref, u_ref, pidx, r_ff, pitch_ref_dot] = ...
                guidance_law(pos, path, pidx, u, v, Uh); %#ok<ASGLU>
        end

        [dr, de, thr] = controller_law(yaw_ref, pitch_ref, u_ref, ...
            ori(3), ori(2), rates(3), rates(2), u, r_ff, pitch_ref_dot, ori(1), w); %#ok<ASGLU>
        controls = struct('delta_r', dr, 'delta_e', de, 'thrust', thr);
        [~, g] = ode45(@(tt, g) underwater777_vehicle_dynamics(tt, g, controls), [0 dt], state);
        state = g(end, :)';

        S.t(k) = k * dt;
        S.x(k) = state(1); S.y(k) = state(2); S.z(k) = state(3);
        S.phi(k) = state(4); S.theta(k) = state(5); S.psi(k) = state(6);
        S.u(k) = state(7); S.v(k) = state(8); S.w(k) = state(9);
        S.p(k) = state(10); S.q(k) = state(11); S.r(k) = state(12);
        S.psi_ref(k) = yaw_ref;
        S.r_ff(k) = r_ff;
        S.U_h(k) = Uh;
        if isempty(last_guidance_U_h); last_guidance_U_h = Uh; end
        if isempty(last_guidance_kappa); last_guidance_kappa = 1/R; end
        if isempty(last_r_ff); last_r_ff = r_ff; end
        S.U_h_guid(k) = last_guidance_U_h;
        S.kappa(k) = last_guidance_kappa;
        S.delta_r(k) = dr;
        S.u_ref(k) = u_ref;
        S.vp(k,:) = state(1:3);
    end
end

%% ===================== analyze =====================
function A = analyze_circle(S, R, delta_r_max)
    dt = S.dt;
    t = S.t;
    n = numel(t);
    xc = 0; yc = 0; % circle center (path construction)

    % --- Analytic signed radial error ---
    rho = sqrt((S.x - xc).^2 + (S.y - yc).^2);
    e_r = rho - R;  % >0 outside

    % --- Path geometry (analytic for circle) ---
    % path: (R cos th, R sin th), th=atan2(y_path,x_path) along nominal
    % tangent t_hat = (-sin th, cos th, 0), outward normal n_out = (cos th, sin th)
    % For vehicle at (x,y): geometric progress th_g = atan2(y,x)
    th_g = atan2(S.y, S.x);
    t_hat_x = -sin(th_g); t_hat_y = cos(th_g);
    n_hat_x = cos(th_g);  n_hat_y = sin(th_g);  % outward radial unit
    % Analytic path point at geometric angle
    p_ref_x = R * cos(th_g);
    p_ref_y = R * sin(th_g);
    % Signed normal CTE: (p - p_ref)·n_hat  (== e_r for this geometry)
    e_n_analytic = (S.x - p_ref_x).*n_hat_x + (S.y - p_ref_y).*n_hat_y;

    % --- Closed-path Frenet projection (CORRECT wrap) ---
    [e_n_frenet, s_prog_ok, psi_path, p_ref_ok] = frenet_closed(S.path, S.vp);

    % --- Reported CTE_perp (existing metric; may freeze s on closed seam) ---
    vel_dummy = [S.u, S.v, S.w];
    ori_mat = [S.phi, S.theta, S.psi];
    pitch_refs = zeros(n,1);
    pm = compute_path_following_metrics(S.path, S.vp, vel_dummy, ori_mat, ...
        S.psi_ref, pitch_refs, dt, t);
    cte_perp_report = pm.cte_perp_series; % unsigned ||e_perp||
    s_prog_report = pm.s_prog;

    % Bias between reported unsigned CTE and |e_r|
    cte_minus_abs_er = cte_perp_report - abs(e_r);

    % --- Attitudes / course ---
    % NED/body: psi = yaw (rad), positive right-hand about Down
    % path tangent heading: psi_path = atan2(t_y, t_x) [rad]
    % inertial course chi = atan2(ydot, xdot)
    % Use finite-diff inertial velocity for course (truth kinematics)
    xd = [0; diff(S.x)] / dt;
    yd = [0; diff(S.y)] / dt;
    chi = atan2(yd, xd);
    chi(1) = S.psi(1);
    % unwrap chi for continuity in plots
    chi_u = unwrap(chi);
    psi_u = unwrap(S.psi);
    psi_ref_u = unwrap(S.psi_ref);
    psi_path_u = unwrap(psi_path);

    % Task beta = wrap(chi - psi)  [course-yaw; rad]
    beta = wrapToPi(chi - S.psi);
    % Body sideslip for reference
    beta_body = atan2(S.v, max(S.u, 0.35));

    e_psi = wrapToPi(S.psi_ref - S.psi);
    e_course_path = wrapToPi(chi - psi_path);  % course vs path tangent
    e_r_rate = S.r - S.U_h_guid .* S.kappa;   % yaw-rate vs U_h*kappa (guidance tick)

    % Turning radius from kinematics: R_act = U_h / r  (signed)
    R_act = S.U_h ./ max(abs(S.r), 1e-6) .* sign(S.r + eps);
    % Prefer positive for CCW circle (r>0 expected)
    radial_bias_kin = abs(R_act) - R;  % only meaningful when |r| decent

    % --- Acquisition: first entry to |e_psi|<=2° for ≥1.0 s ---
    band = deg2rad(2);
    in_band = abs(e_psi) <= band;
    acq_idx = find_acq(in_band, round(1.0/dt));
    if isempty(acq_idx)
        acq_idx = min(n, round(8/dt)); % fallback
        acq_method = 'fallback_t8_no_1s_band';
    else
        acq_method = '|e_psi|<=2deg for >=1.0s';
    end
    t_acq = t(acq_idx);

    % Lap period from mean settled U_h * kappa after acq
    i_pre = acq_idx:n;
    Uh_mean_pre = mean(S.U_h(i_pre));
    T_lap_est = 2*pi*R / max(Uh_mean_pre, 0.1);

    % Settled start: acq + 0.5 lap (allow transient die)
    t_ss0 = t_acq + 0.5 * T_lap_est;
    i_ss0 = find(t >= t_ss0, 1, 'first');
    if isempty(i_ss0); i_ss0 = acq_idx; end

    % Progress angle for turn boundaries (geometric, continuous)
    th_u = unwrap(th_g);
    th0 = th_u(i_ss0);
    % Find completed turn boundaries after settled start
    turn_edges = i_ss0;
    k_turn = 1;
    while true
        target = th0 + k_turn * 2*pi;
        ii = find(th_u >= target, 1, 'first');
        if isempty(ii) || ii >= n; break; end
        turn_edges(end+1) = ii; %#ok<AGROW>
        k_turn = k_turn + 1;
    end
    n_turns = numel(turn_edges) - 1;
    if n_turns < 2
        warning('Only %d settled turn(s); metrics still computed.', n_turns);
    end

    % Steady window = all complete settled turns (or remaining if <1)
    if n_turns >= 1
        i_ss = turn_edges(1):(turn_edges(end)-1);
    else
        i_ss = i_ss0:n;
    end
    i_acq = 1:max(acq_idx,1);

    % --- Window stats helper ---
    stats = @(x, idx) err_stats(x(idx));

    A = struct();
    A.acq_method = acq_method;
    A.t_acq = t_acq;
    A.acq_idx = acq_idx;
    A.t_ss0 = t(i_ss0);
    A.i_ss0 = i_ss0;
    A.T_lap_est = T_lap_est;
    A.n_turns = n_turns;
    A.turn_edges = turn_edges;
    A.turn_times = t(turn_edges);
    A.Uh_mean_pre = Uh_mean_pre;

    A.e_r = e_r;
    A.e_n_analytic = e_n_analytic;
    A.e_n_frenet = e_n_frenet;
    A.cte_perp_report = cte_perp_report;
    A.s_prog_ok = s_prog_ok;
    A.s_prog_report = s_prog_report;
    A.psi_path = psi_path;
    A.chi = chi;
    A.beta = beta;
    A.beta_body = beta_body;
    A.e_psi = e_psi;
    A.e_course_path = e_course_path;
    A.e_r_rate = e_r_rate;
    A.R_act = R_act;
    A.radial_bias_kin = radial_bias_kin;
    A.th_u = th_u;
    A.psi_path_u = psi_path_u;
    A.psi_ref_u = psi_ref_u;
    A.psi_u = psi_u;
    A.chi_u = chi_u;
    A.p_ref_ok = p_ref_ok;
    A.pm_mean_cte_perp = pm.mean_cte_perp;
    A.pm = pm;

    % Acquisition metrics
    A.acq.e_r = stats(e_r, i_acq);
    A.acq.e_n = stats(e_n_frenet, i_acq);
    A.acq.cte_report = stats(cte_perp_report, i_acq);
    A.acq.abs_e_psi_deg = stats(rad2deg(abs(e_psi)), i_acq);

    % Steady (all complete turns)
    A.ss.e_r = stats(e_r, i_ss);
    A.ss.e_n = stats(e_n_frenet, i_ss);
    A.ss.e_n_analytic = stats(e_n_analytic, i_ss);
    A.ss.cte_report = stats(cte_perp_report, i_ss);
    A.ss.abs_er = stats(abs(e_r), i_ss);
    A.ss.abs_en = stats(abs(e_n_frenet), i_ss);
    A.ss.cte_minus_abs_er = err_stats(cte_minus_abs_er(i_ss));
    % placeholder; overwritten below with sign-aligned (−e_n − e_r)

    % Sign/correlation e_n vs e_r
    % CCW circle + left-normal n_hat=[-ty,tx] points inward ⇒ e_n ≈ −e_r.
    % Agreement uses e_n_vs_radial := −e_n (outward-positive, same as e_r).
    er_ss = e_r(i_ss); en_ss = e_n_frenet(i_ss);
    en_out_ss = -en_ss; % outward-positive normal error
    A.ss.en_minus_er = err_stats(en_out_ss - er_ss); % overwrite with sign-aligned bias
    if std(er_ss) > 1e-9 && std(en_ss) > 1e-9
        C = corrcoef(er_ss, en_ss);
        A.ss.corr_en_er = C(1,2);           % expect ≈ −1 for left-normal
        C2 = corrcoef(er_ss, en_out_ss);
        A.ss.corr_en_out_er = C2(1,2);      % expect ≈ +1
    else
        A.ss.corr_en_er = NaN;
        A.ss.corr_en_out_er = NaN;
    end
    A.ss.sign_agree_frac = mean(sign(er_ss) == sign(en_out_ss) | (abs(er_ss)<1e-4 & abs(en_out_ss)<1e-4));

    % Attitude / rate
    A.ss.e_psi_deg = stats(rad2deg(e_psi), i_ss);
    A.ss.abs_e_psi_deg = stats(rad2deg(abs(e_psi)), i_ss);
    A.ss.e_course_path_deg = stats(rad2deg(e_course_path), i_ss);
    A.ss.e_r_rate = stats(e_r_rate, i_ss);
    A.ss.beta_deg = stats(rad2deg(beta), i_ss);
    A.ss.beta_body_deg = stats(rad2deg(beta_body), i_ss);

    mean_r = mean(S.r(i_ss));
    mean_Uh_k = mean(S.U_h_guid(i_ss) .* S.kappa(i_ss));
    if mean_Uh_k < 0
        mean_Uh_k = -mean_Uh_k;
        mean_r = -mean_r;
    end
    A.ss.mean_r = mean_r;
    A.ss.mean_Uh_kappa = mean_Uh_k;
    A.ss.ratio_r_Uh_kappa = mean_r / max(abs(mean_Uh_k), 1e-9);
    A.ss.mean_Uh = mean(S.U_h(i_ss));
    A.ss.mean_kappa = mean(S.kappa(i_ss));
    A.ss.mean_R_act = mean(abs(R_act(i_ss)));
    A.ss.mean_radial_bias_kin = mean(abs(R_act(i_ss))) - R;
    A.ss.mean_rho = mean(rho(i_ss));
    A.ss.mean_rho_minus_R = mean(rho(i_ss)) - R;

    % Rudder
    dr = S.delta_r;
    dr_ss = dr(i_ss);
    A.ss.rudder_deg = stats(rad2deg(dr), i_ss);
    A.ss.rudder_abs_deg = stats(rad2deg(abs(dr)), i_ss);
    d_dr = [0; diff(dr)] / dt;
    A.ss.rudder_rate_rms_dps = rad2deg(rms(d_dr(i_ss)));
    A.ss.rudder_rate_rms = rms(d_dr(i_ss));
    sat_thr = 0.95 * delta_r_max;
    near_thr = 0.90 * delta_r_max;
    A.ss.sat_pct = 100 * mean(abs(dr_ss) >= sat_thr);
    A.ss.near_limit_pct = 100 * mean(abs(dr_ss) >= near_thr);
    A.ss.near_limit_time_s = sum(abs(dr_ss) >= near_thr) * dt;
    A.ss.sat_time_s = sum(abs(dr_ss) >= sat_thr) * dt;
    A.delta_r_max_deg = rad2deg(delta_r_max);
    A.delta_r_max_src = 'init_parameters.m: delta_r_max = deg2rad(25)';

    % Per-turn stats
    A.turns = struct([]);
    for k = 1:n_turns
        ii = turn_edges(k):(turn_edges(k+1)-1);
        tk = struct();
        tk.k = k;
        tk.t0 = t(turn_edges(k));
        tk.t1 = t(turn_edges(k+1));
        tk.e_r = stats(e_r, ii);
        tk.e_n = stats(e_n_frenet, ii);
        tk.abs_er = stats(abs(e_r), ii);
        tk.abs_en = stats(abs(e_n_frenet), ii);
        tk.cte_report = stats(cte_perp_report, ii);
        tk.abs_e_psi_deg = stats(rad2deg(abs(e_psi)), ii);
        tk.mean_Uh = mean(S.U_h(ii));
        tk.mean_rudder_deg = rad2deg(mean(dr(ii)));
        tk.near_limit_pct = 100 * mean(abs(dr(ii)) >= near_thr);
        tk.ratio_r_Uh_k = mean(S.r(ii)) / max(abs(mean(S.U_h_guid(ii).*S.kappa(ii))), 1e-9);
        if isempty(A.turns); A.turns = tk; else; A.turns(end+1) = tk; end %#ok<AGROW>
    end

    % --- Classification ---
    gate = 0.30; % m
    mean_abs_er = A.ss.abs_er.mean;
    mean_abs_en = A.ss.abs_en.mean;
    mean_cte = A.ss.cte_report.mean;
    bias_cte_vs_er = A.ss.cte_minus_abs_er.mean;
    en_er_ok = abs(A.ss.en_minus_er.signed_mean) < 0.05 && A.ss.corr_en_out_er > 0.95;
    yaw_ok = A.ss.abs_e_psi_deg.mean_abs < 1.0 && abs(A.ss.ratio_r_Uh_kappa - 1) < 0.05;
    actuator_tight = (A.ss.near_limit_pct > 5) || (A.ss.sat_pct > 1) || ...
        (abs(A.ss.rudder_deg.signed_mean) >= 0.85 * A.delta_r_max_deg);

    A.class_notes = {};
    if mean_abs_er <= gate && mean_cte > gate + 0.2 && bias_cte_vs_er > 0.2
        A.root_class = 'A';
        A.class_notes{end+1} = sprintf(['Analytic |e_r| mean=%.3f <=0.30 while reported ', ...
            'CTE_perp mean=%.3f; metric/projection inflation (bias CTE-|e_r|=%.3f).'], ...
            mean_abs_er, mean_cte, bias_cte_vs_er);
    elseif mean_abs_er > gate && mean_abs_en > gate && en_er_ok && yaw_ok && ~actuator_tight
        A.root_class = 'B';
        A.class_notes{end+1} = sprintf(['e_r and outward-aligned (−e_n) agree (corr=%.3f, bias=%.4f) and ', ...
            '|e| >0.30 m; yaw-rate track OK (ratio=%.3f, |eψ|=%.2f°); actuator margin OK ', ...
            '(near-lim=%.1f%% sat=%.1f%%). Guidance/geometry offset.'], ...
            A.ss.corr_en_out_er, A.ss.en_minus_er.signed_mean, A.ss.ratio_r_Uh_kappa, ...
            A.ss.abs_e_psi_deg.mean_abs, A.ss.near_limit_pct, A.ss.sat_pct);
    elseif mean_abs_er > gate && mean_abs_en > gate && en_er_ok && actuator_tight
        A.root_class = 'C';
        A.class_notes{end+1} = sprintf(['e_r≈e_n >0.30 m with rudder near-limit/sat ', ...
            '(near=%.1f%% sat=%.1f%% mean_dr=%.1f° of max %.0f°). Envelope/authority.'], ...
            A.ss.near_limit_pct, A.ss.sat_pct, A.ss.rudder_deg.signed_mean, A.delta_r_max_deg);
    else
        A.root_class = 'INCONCLUSIVE';
        A.class_notes{end+1} = sprintf(['Could not isolate A/B/C cleanly: |e_r|=%.3f |e_n|=%.3f ', ...
            'CTE=%.3f corr_out=%.3f yaw_ok=%d act_tight=%d n_turns=%d.'], ...
            mean_abs_er, mean_abs_en, mean_cte, A.ss.corr_en_out_er, yaw_ok, actuator_tight, n_turns);
    end

    % Extra note if metric also broken while physical offset exists
    if mean_abs_er > gate && bias_cte_vs_er > 0.5
        A.class_notes{end+1} = sprintf(['Note: reported CTE also inflated vs |e_r| ', ...
            '(bias=%.3f); closed-path metric seam bug coexists with physical offset.'], ...
            bias_cte_vs_er);
    end
    if n_turns < 2
        A.verdict = 'FAIL';
        A.class_notes{end+1} = 'Settled complete turns < 2 — window insufficient.';
    elseif strcmp(A.root_class, 'INCONCLUSIVE')
        A.verdict = 'FAIL';
    else
        A.verdict = 'DIAGNOSTIC_PASS';
    end

    A.i_ss = i_ss;
    A.i_acq = i_acq;
    A.gate = gate;
end

function s = err_stats(x)
    x = x(:);
    if isempty(x)
        s = struct('signed_mean',NaN,'mean_abs',NaN,'rms',NaN,'p95_abs',NaN,'max_abs',NaN,'n',0);
        return;
    end
    ax = abs(x);
    s = struct( ...
        'signed_mean', mean(x), ...
        'mean_abs', mean(ax), ...
        'rms', rms(x), ...
        'p95_abs', pctile95(ax), ...
        'max_abs', max(ax), ...
        'n', numel(x));
    % alias fields used above
    s.mean = s.signed_mean;
end

function idx = find_acq(in_band, n_hold)
    c = 0;
    idx = [];
    for i = 1:numel(in_band)
        if in_band(i)
            c = c + 1;
            if c >= n_hold
                idx = i - n_hold + 1;
                return;
            end
        else
            c = 0;
        end
    end
end

function [e_n, s_prog, psi_path, p_ref] = frenet_closed(path, vp)
% Closed-path monotonic projection with arc wrap (unlike compute_path_following_metrics).
    n = size(vp,1);
    [s_nodes, s_total] = path_arclength_local(path);
    is_closed = norm(path(1,:) - path(end,:)) < 0.25;
    L = 1.25;
    e_n = zeros(n,1);
    s_prog = zeros(n,1);
    psi_path = zeros(n,1);
    p_ref = zeros(n,3);
    s = 0;
    for i = 1:n
        p = vp(i,:);
        if i == 1
            [s_near, ~] = project_interval_local(p, path, s_nodes, 0, s_total);
            s = s_near;
        else
            if is_closed
                s_lo = mod(s - 0.15, s_total);
                win = max(3.0, 2.5*L);
                % search wrapped window by unwrapping into [s_lo, s_lo+win]
                [s_near, ~] = project_wrapped(p, path, s_nodes, s_lo, win, s_total);
                ds = wrap_arc_local(s_near - s, s_total);
                if ds < -0.25
                    % ignore large backward snap
                else
                    s = mod(s + max(ds, -0.05), s_total);
                end
            else
                s_lo = max(0, s - 0.15);
                s_hi = min(s_total, s + max(3.0, 2.5*L));
                [s_near, ~] = project_interval_local(p, path, s_nodes, s_lo, s_hi);
                s = max(s, s_near - 0.05);
                s = min(s, s_total);
            end
        end
        [p_d, t_hat] = sample_path_local(path, s_nodes, s, is_closed);
        t_h = t_hat(1:2);
        if norm(t_h) < 1e-9
            t_h = [1, 0];
        else
            t_h = t_h / norm(t_h);
        end
        n_h = [-t_h(2), t_h(1)]; % left-normal of path tangent
        e_n(i) = dot(p(1:2) - p_d(1:2), n_h);
        s_prog(i) = s;
        psi_path(i) = atan2(t_h(2), t_h(1));
        p_ref(i,:) = p_d;
    end
end

function [s_best, d_best] = project_wrapped(p, path, s_nodes, s_lo, win, s_total)
    % Project onto path segments covering [s_lo, s_lo+win] mod s_total
    s_hi = s_lo + win;
    candidates_s = [];
    candidates_d = [];
    if s_hi <= s_total
        [s1, d1] = project_interval_local(p, path, s_nodes, s_lo, min(s_total, s_hi));
        candidates_s(end+1) = s1; candidates_d(end+1) = d1; %#ok<AGROW>
    else
        [s1, d1] = project_interval_local(p, path, s_nodes, s_lo, s_total);
        [s2, d2] = project_interval_local(p, path, s_nodes, 0, mod(s_hi, s_total));
        candidates_s = [s1, s2];
        candidates_d = [d1, d2];
    end
    [d_best, j] = min(candidates_d);
    s_best = candidates_s(j);
end

function [s_nodes, s_total] = path_arclength_local(path)
    n = size(path,1);
    s_nodes = zeros(n,1);
    for i = 2:n
        s_nodes(i) = s_nodes(i-1) + norm(path(i,:) - path(i-1,:));
    end
    s_total = max(s_nodes(end), 1e-9);
end

function [s_best, d_best] = project_interval_local(p, path, s_nodes, s_lo, s_hi)
    n = size(path,1);
    d_best = inf; s_best = s_lo;
    i0 = max(1, find(s_nodes <= s_lo, 1, 'last'));
    i1 = min(n-1, find(s_nodes >= s_hi, 1, 'first'));
    if isempty(i0); i0 = 1; end
    if isempty(i1); i1 = n-1; end
    i0 = min(i0, n-1); i1 = max(i1, i0);
    for i = i0:i1
        a = path(i,:); b = path(i+1,:);
        ab = b - a; lab2 = sum(ab.^2);
        if lab2 < 1e-12; continue; end
        tt = max(0, min(1, dot(p - a, ab) / lab2));
        proj = a + tt * ab;
        d = norm(p - proj);
        s = s_nodes(i) + tt * (s_nodes(i+1) - s_nodes(i));
        if s < s_lo - 1e-9 || s > s_hi + 1e-9; continue; end
        if d < d_best
            d_best = d; s_best = s;
        end
    end
end

function [p, t_hat] = sample_path_local(path, s_nodes, s, is_closed)
    n = size(path,1);
    s_total = s_nodes(end);
    if is_closed; s = mod(s, s_total); else; s = max(0, min(s_total, s)); end
    i = max(1, min(n-1, find(s_nodes <= s, 1, 'last')));
    if isempty(i); i = 1; end
    ds = s_nodes(i+1) - s_nodes(i);
    if ds < 1e-12; tt = 0; else; tt = (s - s_nodes(i)) / ds; end
    p = path(i,:) + tt * (path(i+1,:) - path(i,:));
    tang = path(i+1,:) - path(i,:);
    if norm(tang) < 1e-9
        if i > 1; tang = path(i,:) - path(i-1,:); else; tang = [1,0,0]; end
    end
    t_hat = tang / norm(tang);
end

function ds = wrap_arc_local(ds, s_total)
    ds = mod(ds + s_total/2, s_total) - s_total/2;
end

function Uh = inertial_Uh(ori, u, v, w)
    phi = ori(1); th = ori(2); ps = ori(3);
    Rnb = [ ...
        cos(th)*cos(ps), sin(phi)*sin(th)*cos(ps)-cos(phi)*sin(ps), cos(phi)*sin(th)*cos(ps)+sin(phi)*sin(ps); ...
        cos(th)*sin(ps), sin(phi)*sin(th)*sin(ps)+cos(phi)*cos(ps), cos(phi)*sin(th)*sin(ps)-sin(phi)*cos(ps); ...
        -sin(th),        sin(phi)*cos(th),                           cos(phi)*cos(th)];
    v_n = Rnb * [u; v; w];
    Uh = hypot(v_n(1), v_n(2));
end

function y = pctile95(x)
    x = sort(x(:));
    if isempty(x); y = NaN; return; end
    k = max(1, min(numel(x), ceil(0.95 * numel(x))));
    y = x(k);
end

function s = tern(c, a, b)
    if c; s = a; else; s = b; end
end

%% ===================== write outputs =====================
function write_outputs(out_dir, S, A, R, T_final, u0, deterministic, ...
        delta_r_max, dt_c, dt_g, L_look, U_des)

    tag = 'YAW_R75_RADIAL_DIAG';
    mat_path = fullfile(out_dir, [tag '.mat']);
    csv_path = fullfile(out_dir, [tag '_timeseries.csv']);
    png_path = fullfile(out_dir, [tag '_timeseries.png']);
    md_path  = fullfile(out_dir, 'YAW_R75_RADIAL_DIAG.md');

    save(mat_path, 'S', 'A', 'R', 'T_final', 'u0', 'deterministic', ...
        'delta_r_max', 'dt_c', 'dt_g', 'L_look', 'U_des', '-v7.3');

    % CSV (downsample for size)
    step = max(1, round(0.1 / S.dt)); % 10 Hz
    idx = 1:step:numel(S.t);
    Tcsv = table(S.t(idx), S.x(idx), S.y(idx), A.e_r(idx), A.e_n_frenet(idx), ...
        A.cte_perp_report(idx), A.psi_path(idx), S.psi_ref(idx), A.chi(idx), S.psi(idx), ...
        A.beta(idx), S.r(idx), S.U_h(idx).*S.kappa(idx), S.delta_r(idx), ...
        A.s_prog_ok(idx), A.s_prog_report(idx), ...
        'VariableNames', {'t','x','y','e_r','e_n','cte_perp_report','psi_path', ...
        'psi_ref','chi','psi','beta','r','Uh_kappa','delta_r','s_prog_ok','s_prog_report'});
    writetable(Tcsv, csv_path);

    % Plots
    fig = figure('Visible','off','Position',[50 50 1400 1000]);
    i_ss = A.i_ss;
    tl = tiledlayout(4,2,'Padding','compact','TileSpacing','compact'); %#ok<NASGU>

    nexttile; hold on;
    plot(S.t, A.e_r, 'b'); plot(S.t, A.e_n_frenet, 'r--');
    plot(S.t, A.cte_perp_report, 'k:');
    yline(0.30,'g--'); yline(-0.30,'g--');
    mark_turns(A); ylabel('m'); title('e_r vs e_n vs CTE_{perp,report}');
    legend('e_r','e_n (Frenet wrap)','CTE_{perp} report','±0.30','Location','best');

    nexttile; hold on;
    plot(S.t, rad2deg(A.psi_path_u), 'k');
    plot(S.t, rad2deg(A.psi_ref_u), 'b');
    plot(S.t, rad2deg(A.chi_u), 'g');
    plot(S.t, rad2deg(A.psi_u), 'r--');
    mark_turns(A); ylabel('deg'); title('\psi_{path}/\psi_{ref}/\chi/\psi (unwrap)');
    legend('\psi_{path}','\psi_{ref}','\chi','\psi','Location','best');

    nexttile; hold on;
    plot(S.t, rad2deg(A.beta), 'b'); plot(S.t, rad2deg(A.beta_body), 'r--');
    mark_turns(A); ylabel('deg'); title('\beta=wrap(\chi-\psi) and body atan2(v,u)');
    legend('course-yaw','body','Location','best');

    nexttile; hold on;
    plot(S.t, rad2deg(S.r), 'b'); plot(S.t, rad2deg(S.U_h_guid.*S.kappa), 'r--');
    mark_turns(A); ylabel('deg/s'); title('r vs U_h \kappa');
    legend('r','U_h\kappa','Location','best');

    nexttile; hold on;
    plot(S.t, rad2deg(S.delta_r), 'b');
    yline(rad2deg(delta_r_max),'r--'); yline(-rad2deg(delta_r_max),'r--');
    yline(0.9*rad2deg(delta_r_max),'m:'); yline(-0.9*rad2deg(delta_r_max),'m:');
    mark_turns(A); ylabel('deg'); title(sprintf('rudder (max=%.0f°)', rad2deg(delta_r_max)));

    nexttile; hold on;
    plot(S.t, A.s_prog_ok, 'b'); plot(S.t, A.s_prog_report, 'r--');
    mark_turns(A); ylabel('m'); title('s_{prog} correct wrap vs report metric');
    legend('wrap OK','report (may freeze)','Location','best');

    nexttile; hold on;
    plot(S.x, S.y, 'b');
    th = linspace(0,2*pi,200);
    plot(R*cos(th), R*sin(th), 'k--');
    axis equal; title(sprintf('XY track R=%.1f', R)); xlabel('x'); ylabel('y');

    nexttile; hold on;
    plot(S.t, abs(A.e_r), 'b'); plot(S.t(i_ss), abs(A.e_r(i_ss)), 'g.');
    xline(A.t_acq,'k--'); xline(A.t_ss0,'m--');
    mark_turns(A); ylabel('|e_r| m'); title('acquisition / steady windows');
    legend('|e_r|','steady samples','t_{acq}','t_{ss0}','Location','best');

    exportgraphics(fig, png_path, 'Resolution', 120);
    close(fig);

    % Markdown report
    fid = fopen(md_path, 'w');
    fprintf(fid, '# YAW_R75_RADIAL_DIAG\n\n');
    fprintf(fid, '**TASK_ID:** YAW_RADIAL_R75_DIAG_001  \n');
    fprintf(fid, '**Date:** %s  \n', datestr(now, 31));
    fprintf(fid, '**Verdict:** %s  \n', A.verdict);
    fprintf(fid, '**Root class:** %s  \n\n', A.root_class);

    fprintf(fid, '## Hypothesis\n\n');
    fprintf(fid, 'Reported `CTE_perp≈1.315 m` on R=7.5 is one of: (A) closed-path metric/projection error, ');
    fprintf(fid, '(B) real guidance radial offset, (C) rudder/speed-radius authority limit. ');
    fprintf(fid, 'Yaw gains/FF unchanged; classify from raw time series.\n\n');

    fprintf(fid, '## Run config\n\n');
    fprintf(fid, '| Item | Value |\n|---|---|\n');
    fprintf(fid, '| Stack | production freeze (dt_c=%.4f, dt_g=%.4f, λ=0.25, Kγ=0, Tur4A r_ff=U_hκ, T25 trim) |\n', dt_c, dt_g);
    fprintf(fid, '| R | %.1f m |\n', R);
    fprintf(fid, '| T_final | %.0f s |\n', T_final);
    fprintf(fid, '| u0 | %.2f m/s |\n', u0);
    fprintf(fid, '| desired_speed / lookahead | %.2f m/s / %.2f m |\n', U_des, L_look);
    fprintf(fid, '| delta_r_max | %.2f deg (`init_parameters.m`) |\n', rad2deg(delta_r_max));
    fprintf(fid, '| Deterministic | %s (no RNG; no seed) |\n', tern(deterministic,'YES','NO'));
    fprintf(fid, '| Endpoint mask | none (closed path) |\n\n');

    fprintf(fid, '## Windows\n\n');
    fprintf(fid, '- **Acquisition:** %s → t_acq = %.2f s (samples 1…acq).\n', A.acq_method, A.t_acq);
    fprintf(fid, '- **Settled start:** t_ss0 = acq + 0.5·T_lap = %.2f s (T_lap_est=%.1f s from mean U_h=%.3f).\n', ...
        A.t_ss0, A.T_lap_est, A.Uh_mean_pre);
    fprintf(fid, '- **Steady:** %d complete geometric turns after t_ss0; turn times: ', A.n_turns);
    fprintf(fid, '%.1f ', A.turn_times);
    fprintf(fid, 's.\n');
    fprintf(fid, '- Turn boundaries from unwrap(atan2(y,x)) + 2π k (analytic circle angle).\n\n');

    fprintf(fid, '## Metrics — acquisition\n\n');
    print_err_table(fid, 'e_r', A.acq.e_r);
    print_err_table(fid, 'e_n', A.acq.e_n);
    print_err_table(fid, 'CTE_perp report', A.acq.cte_report);

    fprintf(fid, '\n## Metrics — steady (all complete turns)\n\n');
    fprintf(fid, '| Signal | signed mean | mean abs | RMS | p95 abs | max abs |\n|---|---:|---:|---:|---:|---:|\n');
    print_err_row(fid, 'e_r [m]', A.ss.e_r);
    print_err_row(fid, 'e_n Frenet [m]', A.ss.e_n);
    print_err_row(fid, 'e_n analytic [m]', A.ss.e_n_analytic);
    print_err_row(fid, 'CTE_perp report [m]', A.ss.cte_report);
    print_err_row(fid, 'e_n - e_r [m]', A.ss.en_minus_er);
    print_err_row(fid, 'CTE_report - |e_r| [m]', A.ss.cte_minus_abs_er);
    fprintf(fid, '\n- corr(e_n, e_r) = %.4f; sign agreement = %.1f%%\n', A.ss.corr_en_er, 100*A.ss.sign_agree_frac);
    fprintf(fid, '- legacy `pm.mean_cte_perp` (settled t≥5, closed) = %.3f m\n', A.pm_mean_cte_perp);
    fprintf(fid, '- mean ρ = %.3f m → mean(ρ−R) = %+.3f m\n\n', A.ss.mean_rho, A.ss.mean_rho_minus_R);

    fprintf(fid, '### Attitude / rate / sideslip (steady)\n\n');
    fprintf(fid, '| Signal | signed mean | mean abs | RMS | p95 abs | max abs |\n|---|---:|---:|---:|---:|---:|\n');
    print_err_row(fid, 'e_ψ [deg]', A.ss.e_psi_deg);
    print_err_row(fid, '|e_ψ| [deg]', A.ss.abs_e_psi_deg);
    print_err_row(fid, 'χ−ψ_path [deg]', A.ss.e_course_path_deg);
    print_err_row(fid, 'β=wrap(χ−ψ) [deg]', A.ss.beta_deg);
    print_err_row(fid, 'β_body=atan2(v,u) [deg]', A.ss.beta_body_deg);
    print_err_row(fid, 'r − U_hκ [rad/s]', A.ss.e_r_rate);
    fprintf(fid, '\n- mean(r) = %.5f rad/s (%.3f deg/s)\n', A.ss.mean_r, rad2deg(A.ss.mean_r));
    fprintf(fid, '- mean(U_h·κ) = %.5f rad/s (%.3f deg/s)\n', A.ss.mean_Uh_kappa, rad2deg(A.ss.mean_Uh_kappa));
    fprintf(fid, '- mean(r)/mean(U_h·κ) = **%.4f**\n', A.ss.ratio_r_Uh_kappa);
    fprintf(fid, '- mean U_h = %.3f m/s; mean κ = %.5f 1/m; mean |R_act|=U_h/|r| = %.3f m\n', ...
        A.ss.mean_Uh, A.ss.mean_kappa, A.ss.mean_R_act);
    fprintf(fid, '- kinematic radial bias mean(|R_act|−R) = %+.3f m\n\n', A.ss.mean_radial_bias_kin);

    fprintf(fid, '### Rudder (steady)\n\n');
    fprintf(fid, '| Item | Value |\n|---|---:|\n');
    fprintf(fid, '| delta_r_max | %.2f deg (%s) |\n', A.delta_r_max_deg, A.delta_r_max_src);
    fprintf(fid, '| signed mean | %.2f deg |\n', A.ss.rudder_deg.signed_mean);
    fprintf(fid, '| mean abs | %.2f deg |\n', A.ss.rudder_deg.mean_abs);
    fprintf(fid, '| RMS | %.2f deg |\n', A.ss.rudder_deg.rms);
    fprintf(fid, '| p95 abs | %.2f deg |\n', A.ss.rudder_deg.p95_abs);
    fprintf(fid, '| max abs | %.2f deg |\n', A.ss.rudder_deg.max_abs);
    fprintf(fid, '| rate RMS | %.3f deg/s |\n', A.ss.rudder_rate_rms_dps);
    fprintf(fid, '| saturation (|δr|≥0.95 δmax) | %.2f %% (%.2f s) |\n', A.ss.sat_pct, A.ss.sat_time_s);
    fprintf(fid, '| near-limit (|δr|≥0.90 δmax) | %.2f %% (%.2f s) |\n\n', A.ss.near_limit_pct, A.ss.near_limit_time_s);

    if ~isempty(A.turns)
        fprintf(fid, '### Per-turn steady\n\n');
        fprintf(fid, '| Turn | t0–t1 | mean e_r | mean\\|e_r\\| | mean e_n | mean\\|e_n\\| | CTE_rep | \\|eψ\\| | U_h | δr | near%% | r/(Uhκ) |\n');
        fprintf(fid, '|---:|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|\n');
        for k = 1:numel(A.turns)
            tk = A.turns(k);
            fprintf(fid, '| %d | %.1f–%.1f | %+.3f | %.3f | %+.3f | %.3f | %.3f | %.2f | %.3f | %+.1f | %.1f | %.3f |\n', ...
                tk.k, tk.t0, tk.t1, tk.e_r.signed_mean, tk.abs_er.mean_abs, ...
                tk.e_n.signed_mean, tk.abs_en.mean_abs, tk.cte_report.mean_abs, ...
                tk.abs_e_psi_deg.mean_abs, tk.mean_Uh, tk.mean_rudder_deg, ...
                tk.near_limit_pct, tk.ratio_r_Uh_k);
        end
        fprintf(fid, '\n');
    end

    fprintf(fid, '## Classification\n\n');
    for i = 1:numel(A.class_notes)
        fprintf(fid, '- %s\n', A.class_notes{i});
    end
    fprintf(fid, '\n**Root class: %s** — **%s**\n\n', A.root_class, A.verdict);

    fprintf(fid, '## Evidence paths\n\n');
    fprintf(fid, '- `%s`\n- `%s`\n- `%s`\n- `%s`\n\n', mat_path, csv_path, png_path, md_path);

    fprintf(fid, '## Frames / signs / units\n\n');
    fprintf(fid, '- Position NED-like: x,y horizontal [m]; path `(R cos θ, R sin θ)` CCW.\n');
    fprintf(fid, '- `e_r = √((x−x_c)²+(y−y_c)²) − R` [m], + outward; (x_c,y_c)=(0,0).\n');
    fprintf(fid, '- `e_n = (p−p_ref)·n_hat` [m]; `n_hat = [-t_y, t_x]` left-normal of path tangent; + to left of travel.\n');
    fprintf(fid, '- For this CCW circle, left-normal points **inward** (toward center), so `e_n ≈ −e_r` if vehicle outside… ');
    fprintf(fid, '**check sign carefully in numbers** (see MATHEMATICAL_RECORD).\n');
    fprintf(fid, '- `ψ_path = atan2(t_y, t_x)` [rad]; `χ = atan2(ẏ,ẋ)` [rad]; `ψ` = body yaw [rad]; `β = wrap(χ−ψ)`.\n');
    fprintf(fid, '- Angles reported in deg where noted; rates rad/s unless deg/s labeled.\n');
    fprintf(fid, '- `CTE_perp` report = `‖(I−ttᵀ)(p−p_d)‖` unsigned from `compute_path_following_metrics` (progress may freeze at seam on closed paths).\n\n');

    fprintf(fid, '## MATHEMATICAL_RECORD\n\n');
    fprintf(fid, '```\n');
    fprintf(fid, 'MATHEMATICAL_RECORD = {\n');
    fprintf(fid, '  equations: {\n');
    fprintf(fid, '    e_r = sqrt((x-xc)^2+(y-yc)^2) - R,\n');
    fprintf(fid, '    e_n = (p - p_ref)^T n_hat,  n_hat = [-t_y; t_x], t = path tangent at s_prog,\n');
    fprintf(fid, '    CTE_perp_report = ||(I - t t^T)(p - p_d)||  (unsigned),\n');
    fprintf(fid, '    chi = atan2(ydot, xdot),  beta = wrapToPi(chi - psi),\n');
    fprintf(fid, '    r_ff = U_h * kappa_f (Tur4A),\n');
    fprintf(fid, '    ratio = mean(r)/mean(U_h*kappa)\n');
    fprintf(fid, '  },\n');
    fprintf(fid, '  variables_units_frames: {\n');
    fprintf(fid, '    x,y,z [m] body-to-NED path frame of sim; psi,chi,psi_path [rad] yaw about Down;\n');
    fprintf(fid, '    r [rad/s] body yaw rate; U_h [m/s] inertial horizontal speed; kappa [1/m];\n');
    fprintf(fid, '    delta_r [rad] rudder, + per plant convention; R=7.5[m]\n');
    fprintf(fid, '  },\n');
    fprintf(fid, '  assumptions: {\n');
    fprintf(fid, '    circle center (0,0); flat z=0 path; closed path seam at th=0;\n');
    fprintf(fid, '    geometric turn count via unwrap(atan2(y,x));\n');
    fprintf(fid, '    acquisition |e_psi|<=2deg hold 1s; settled = complete turns after acq+0.5 lap;\n');
    fprintf(fid, '    no sensor noise; truth state for metrics only\n');
    fprintf(fid, '  },\n');
    fprintf(fid, '  parameter_provenance: {\n');
    fprintf(fid, '    DERIVED: e_r, e_n, chi, beta, R_act=U_h/|r|, T_lap=2*pi*R/mean(U_h),\n');
    fprintf(fid, '    IDENTIFIED: mean e_r/e_n/CTE, ratio r/(Uh kappa), rudder near-limit fractions from this run,\n');
    fprintf(fid, '    TUNED: none this task (gains/FF frozen),\n');
    fprintf(fid, '    FIXED_FROM_CODE: delta_r_max=25deg (init_parameters), L=1.25, U_des=1.5,\n');
    fprintf(fid, '      dt_c=0.025, dt_g=0.075, Kp_psi=32, Kd_psi=13, r_ff=U_h*kappa\n');
    fprintf(fid, '  },\n');
    fprintf(fid, '  design_reason: ''Separate metric artifact from physical radial offset without touching yaw gains.'',\n');
    fprintf(fid, '  rejected_alternatives: {\n');
    fprintf(fid, '    yaw_gain_retune: rejected (feasible |e_psi| already ~0.3deg),\n');
    fprintf(fid, '    rudder_FF: rejected (out of scope; would confound class),\n');
    fprintf(fid, '    open_path_0.88_endpoint_mask: rejected (circle is closed)\n');
    fprintf(fid, '  },\n');
    fprintf(fid, '  evidence: {\n');
    fprintf(fid, '    mat: suite_results/YAW_R75_RADIAL_DIAG.mat,\n');
    fprintf(fid, '    csv: suite_results/YAW_R75_RADIAL_DIAG_timeseries.csv,\n');
    fprintf(fid, '    png: suite_results/YAW_R75_RADIAL_DIAG_timeseries.png,\n');
    fprintf(fid, '    prior_report_CTE: YAW_START CTE_perp=1.315m on T=40s window\n');
    fprintf(fid, '  },\n');
    fprintf(fid, '  conclusion: ''see Root class above; correlation of e_n with e_r is geometric identity check, not causation claim'',\n');
    fprintf(fid, '  open_questions: {\n');
    fprintf(fid, '    if class A: fix closed-path s_prog wrap in compute_path_following_metrics,\n');
    fprintf(fid, '    if class B: inspect LOS/lookahead radial equilibrium on circle,\n');
    fprintf(fid, '    if class C: declare R-U envelope / speed schedule before gain work\n');
    fprintf(fid, '  }\n');
    fprintf(fid, '}\n');
    fprintf(fid, '```\n\n');

    fprintf(fid, '## Next bounded task (one)\n\n');
    switch A.root_class
        case 'A'
            fprintf(fid, 'Fix **closed-path `s_prog` wrap** in `compute_path_following_metrics.m` only; re-score R=7.5 with analytic `e_r` gate ≤0.30 m (no controller change).\n');
        case 'B'
            fprintf(fid, 'Inspect guidance LOS/lookahead radial equilibrium on R=7.5 (geometry/projection only); no yaw gain change.\n');
        case 'C'
            fprintf(fid, 'Map R–U_h–rudder authority for R=7.5 (envelope declaration); no yaw gain change.\n');
        otherwise
            fprintf(fid, 'Re-run with longer T or missing-signal instrumentation only; keep controller frozen.\n');
    end

    fprintf(fid, '\n## Changed files\n\n');
    fprintf(fid, '- `run_yaw_r75_radial_diag.m` (new analysis driver)\n');
    fprintf(fid, '- `suite_results/YAW_R75_RADIAL_DIAG.md` (+ mat/csv/png)\n');
    fprintf(fid, '- Controller/guidance/plant: **untouched**\n');
    fclose(fid);
end

function print_err_table(fid, name, s)
    fprintf(fid, '- **%s:** signed_mean=%.4f, mean_abs=%.4f, RMS=%.4f, p95_abs=%.4f, max_abs=%.4f (n=%d)\n', ...
        name, s.signed_mean, s.mean_abs, s.rms, s.p95_abs, s.max_abs, s.n);
end

function print_err_row(fid, name, s)
    fprintf(fid, '| %s | %+.4f | %.4f | %.4f | %.4f | %.4f |\n', ...
        name, s.signed_mean, s.mean_abs, s.rms, s.p95_abs, s.max_abs);
end

function mark_turns(A)
    for k = 1:numel(A.turn_times)
        xline(A.turn_times(k), 'Color', [0.5 0.5 0.5], 'LineStyle', ':');
    end
end
