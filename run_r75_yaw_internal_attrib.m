function run_r75_yaw_internal_attrib()
% RUN_R75_YAW_INTERNAL_ATTRIB  R75_YAW_INTERNAL_ATTRIB_001
% Attribute R=7.5 rudder 13.33 Hz ripple to one internal source:
%   P-yaw | D/r_ff | guidance_step | rudder_rate_limiter
% Production controller_law / guidance_law unchanged. New driver only.
% Evidence: suite_results/R75_YAW_INTERNAL_ATTRIB.{md,mat,png}

    project_dir = fileparts(mfilename('fullpath'));
    addpath(project_dir);
    out_dir = fullfile(project_dir, 'suite_results');
    if ~exist(out_dir, 'dir'); mkdir(out_dir); end
    tag = 'R75_YAW_INTERNAL_ATTRIB';

    clear functions
    clear guidance_law controller_law
    clear global lambda_muw_ff trim_speed_table trim_elevator_table elevator_sign
    clear global K_zdot K_gamma enable_alpha_hat
    clear global last_guidance_U_h last_guidance_kappa last_r_ff

    init_parameters();
    global lambda_muw_ff elevator_sign trim_speed_table trim_elevator_table
    global K_zdot K_gamma enable_alpha_hat
    global dt_controller dt_guidance
    global delta_r_max desired_speed lookahead_distance
    global Kp_psi Kd_psi

    elevator_sign = 1;
    trim_speed_table = [0.8 1.0 1.5 2.0];
    trim_elevator_table = deg2rad([-9.18 -7.33 -4.62 -3.17]);
    K_gamma = 0;
    K_zdot = 0;
    enable_alpha_hat = false;
    lambda_muw_ff = 0.25;

    R = 7.5;
    u0 = 1.5;
    T_final = 120;

    fprintf('\n========== R75_YAW_INTERNAL_ATTRIB_001 ==========\n');
    fprintf('R=%.1f u0=%.2f T=%.0fs dt_c=%.4f dt_g=%.4f Kp=%.0f Kd=%.0f\n', ...
        R, u0, T_final, dt_controller, dt_guidance, Kp_psi, Kd_psi);

    S = simulate_instrumented(R, T_final, u0);
    A = analyze_attrib(S, R, Kp_psi, Kd_psi, delta_r_max, dt_controller, dt_guidance);
    write_evidence(out_dir, tag, S, A, R, u0, T_final, Kp_psi, Kd_psi, ...
        delta_r_max, dt_controller, dt_guidance);

    fprintf('Source=%s | Verdict=%s | var_exp=%.3f | rel=%.3f\n', ...
        A.source, A.verdict, A.best.var_exp, A.best.rel);
    fprintf('Wrote suite_results/%s.{md,mat,png}\n', tag);
end

%% ===================== simulate (instrumented driver) =====================
function S = simulate_instrumented(R, T_final, u0)
    global dt_controller dt_guidance
    global last_guidance_U_h last_guidance_kappa last_r_ff
    global Kp_psi Kd_psi delta_r_max

    n = 600;
    th = linspace(0, 2*pi, n)';
    path = [R*cos(th), R*sin(th), zeros(n,1)];
    dt = dt_controller;
    n_steps = round(T_final / dt);
    guidance_period = max(1, round(dt_guidance / dt));
    max_dr = deg2rad(40) * dt;

    state = zeros(12,1);
    state(1:3) = path(1,:)';
    d = path(2,:) - path(1,:);
    state(5) = -atan2(d(3), norm(d(1:2)));
    state(6) = atan2(d(2), d(1));
    state(7) = u0;

    yaw_ref = 0; pitch_ref = 0; u_ref = u0; r_ff = 0; pitch_ref_dot = 0; pidx = 1;
    prev_dr = 0; % mirror controller persistent for rate-limit flags

    S = struct();
    S.path = path; S.R = R; S.dt = dt;
    S.guidance_period = guidance_period;
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
    S.guidance_tick = false(n_steps,1);
    S.yaw_ref_inc = zeros(n_steps,1);
    S.e_psi = zeros(n_steps,1);
    S.e_r = zeros(n_steps,1);
    S.P = zeros(n_steps,1);
    S.D = zeros(n_steps,1);
    S.delta_r_cmd_unsat = zeros(n_steps,1);
    S.delta_r_cmd_sat = zeros(n_steps,1);
    S.rl_active = false(n_steps,1);
    S.rl_sign = zeros(n_steps,1);
    S.cmd_minus_out = zeros(n_steps,1);

    yaw_ref_prev = 0;
    for k = 1:n_steps
        pos = state(1:3)';
        ori = state(4:6)';
        rates = state(10:12)';
        u = state(7); v = state(8); w = state(9);
        Uh = inertial_Uh(ori, u, v, w);

        tick = (mod(k - 1, guidance_period) == 0);
        if tick
            [yaw_ref, pitch_ref, u_ref, pidx, r_ff, pitch_ref_dot] = ...
                guidance_law(pos, path, pidx, u, v, Uh); %#ok<ASGLU>
        end

        % Reconstruct yaw PD / rate-limit path (identical to controller_law.m)
        e_psi = wrapToPi(yaw_ref - ori(3));
        e_r = rates(3) - r_ff;
        P = Kp_psi * e_psi;
        D = -Kd_psi * e_r;
        cmd_u = P + D;
        cmd_s = max(min(cmd_u, delta_r_max), -delta_r_max);
        dcmd = cmd_s - prev_dr;
        if abs(dcmd) > max_dr + 1e-15
            rl_on = true;
            rl_sg = sign(dcmd);
        else
            rl_on = false;
            rl_sg = 0;
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
        S.guidance_tick(k) = tick;
        if k == 1
            S.yaw_ref_inc(k) = 0;
        else
            S.yaw_ref_inc(k) = wrapToPi(yaw_ref - yaw_ref_prev);
        end
        yaw_ref_prev = yaw_ref;
        S.e_psi(k) = e_psi;
        S.e_r(k) = e_r;
        S.P(k) = P;
        S.D(k) = D;
        S.delta_r_cmd_unsat(k) = cmd_u;
        S.delta_r_cmd_sat(k) = cmd_s;
        S.rl_active(k) = rl_on;
        S.rl_sign(k) = rl_sg;
        S.cmd_minus_out(k) = cmd_s - dr;
        prev_dr = dr;
    end
end

function Uh = inertial_Uh(ori, u, v, w)
    phi = ori(1); th = ori(2); ps = ori(3);
    Rnb = [ ...
        cos(th)*cos(ps), sin(phi)*sin(th)*cos(ps)-cos(phi)*sin(ps), ...
        cos(phi)*sin(th)*cos(ps)+sin(phi)*sin(ps); ...
        cos(th)*sin(ps), sin(phi)*sin(th)*sin(ps)+cos(phi)*cos(ps), ...
        cos(phi)*sin(th)*sin(ps)-sin(phi)*cos(ps); ...
        -sin(th),        sin(phi)*cos(th),                          cos(phi)*cos(th)];
    v_i = Rnb * [u; v; w];
    Uh = hypot(v_i(1), v_i(2));
end

%% ===================== analyze =====================
function A = analyze_attrib(S, R, Kp_psi, Kd_psi, delta_r_max, dt_c, dt_g)
    dt = S.dt;
    t = S.t;
    n = numel(t);
    f0 = 1 / dt_g; % 13.333 Hz expected

    e_psi = S.e_psi;
    % Acquisition / steady windows (same recipe as radial diag)
    band = deg2rad(2);
    in_band = abs(e_psi) <= band;
    need = round(1.0 / dt);
    acq_idx = find_acq(in_band, need);
    if isempty(acq_idx)
        acq_idx = min(n, round(8/dt));
        acq_method = 'fallback_t8';
    else
        acq_method = '|e_psi|<=2deg for >=1.0s';
    end
    t_acq = t(acq_idx);
    Uh_mean_pre = mean(S.U_h(acq_idx:n));
    T_lap_est = 2*pi*R / max(Uh_mean_pre, 0.1);
    t_ss0 = t_acq + 0.5 * T_lap_est;
    i_ss0 = find(t >= t_ss0, 1, 'first');
    if isempty(i_ss0); i_ss0 = acq_idx; end

    th_g = atan2(S.y, S.x);
    th_u = unwrap(th_g);
    th0 = th_u(i_ss0);
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
    if n_turns >= 1
        i_ss = turn_edges(1):(turn_edges(end)-1);
    else
        i_ss = i_ss0:n;
    end
    % Prefer exactly 3 complete turns when available (baseline)
    if n_turns >= 3
        i_ss = turn_edges(1):(turn_edges(4)-1);
        n_turns_used = 3;
    else
        n_turns_used = n_turns;
    end

    win = max(1, round(1.0 / dt)); % 1 s detrend
    detrend1 = @(x) x(:) - movmean(x(:), win);

    P = S.P; D = S.D;
    cmd_u = S.delta_r_cmd_unsat;
    cmd_s = S.delta_r_cmd_sat;
    dr = S.delta_r;
    % Guidance ZOH artifact in command units:
    % yaw_ref_lin = linear interp between guidance-tick samples; ZOH residual drives steps.
    yaw_ref_u = unwrap(S.psi_ref);
    yaw_ref_lin = zoh_to_linear(yaw_ref_u, S.guidance_tick);
    Gstep = Kp_psi * (yaw_ref_u - yaw_ref_lin);
    % Rate-limiter effect on applied command (cmd_sat - rate_limited)
    RLeff = S.cmd_minus_out;

    y = detrend1(cmd_s);           % primary: saturated command ripple
    y_out = detrend1(dr);          % applied rudder ripple
    xP = detrend1(P);
    xD = detrend1(D);
    xG = detrend1(Gstep);
    xRL = detrend1(RLeff);

    iss = i_ss(:);
    yss = y(iss); yout = y_out(iss);
    cands = { ...
        'P-yaw', xP(iss); ...
        'D/r_ff', xD(iss); ...
        'guidance_step', xG(iss); ...
        'rudder_rate_limiter', xRL(iss)};

    % For RL, also score against output ripple (RL acts after cmd)
    target_for = {@(i) yss, @(i) yss, @(i) yss, @(i) yout};

    rows = struct([]);
    for i = 1:4
        x = cands{i,2};
        yt = target_for{i}(i);
        m = score_source(x, yt, dt, f0);
        m.name = cands{i,1};
        % Additive variance share for P/D vs cmd (exact partition of cmd=P+D pre-sat)
        if i <= 2
            m.var_share_add = safe_div(mean(x .* yss), mean(yss.^2));
        else
            m.var_share_add = m.var_exp; % R^2 proxy
        end
        rows = [rows; m]; %#ok<AGROW>
    end

    % Prefer additive share for P/D when selecting; else R^2
    score = zeros(4,1);
    rel = zeros(4,1);
    for i = 1:4
        if i <= 2
            score(i) = rows(i).var_share_add;
        else
            score(i) = rows(i).var_exp;
        end
        rel(i) = max(abs(rows(i).corr), rows(i).coh_f0);
        rows(i).select_score = score(i);
        rows(i).select_rel = rel(i);
    end

    [best_score, ib] = max(score);
    best_rel = rel(ib);
    pass = (best_score >= 0.70) && (best_rel >= 0.70);
    if pass
        source = rows(ib).name;
        verdict = 'PASS';
    else
        source = 'UNKNOWN';
        verdict = 'FAIL';
    end

    % Spectral amplitudes at f0
    amp = @(x) band_amp(x(iss), dt, f0);
    E = @(x) band_energy(x(iss), dt, f0);

    A = struct();
    A.task_id = 'R75_YAW_INTERNAL_ATTRIB_001';
    A.acq_method = acq_method;
    A.t_acq = t_acq;
    A.t_ss0 = t(i_ss0);
    A.T_lap_est = T_lap_est;
    A.n_turns = n_turns;
    A.n_turns_used = n_turns_used;
    A.i_ss = iss;
    A.f0 = f0;
    A.f_g = 1/dt_g;
    A.f_c = 1/dt_c;
    A.rows = rows;
    A.source = source;
    A.verdict = verdict;
    A.best = struct('name', rows(ib).name, 'var_exp', best_score, ...
        'rel', best_rel, 'corr', rows(ib).corr, 'coh_f0', rows(ib).coh_f0, ...
        'idx', ib);

    A.metrics = struct();
    A.metrics.P_rms_deg = rad2deg(rms(xP(iss)));
    A.metrics.D_rms_deg = rad2deg(rms(xD(iss)));
    A.metrics.cmd_unsat_rms_deg = rad2deg(rms(detrend1(cmd_u(iss))));
    A.metrics.cmd_sat_rms_deg = rad2deg(rms(yss));
    A.metrics.dr_rms_deg = rad2deg(rms(yout));
    A.metrics.cmd_out_diff_rms_deg = rad2deg(rms(detrend1(RLeff(iss))));
    A.metrics.cmd_out_diff_mae_deg = rad2deg(mean(abs(RLeff(iss))));
    A.metrics.rl_active_pct = 100 * mean(S.rl_active(iss));
    % Direction reversal frequency of rate-limit sign (active only)
    sg = S.rl_sign(iss);
    act = S.rl_active(iss);
    sg_a = sg; sg_a(~act) = 0;
    flips = sum(sg_a(1:end-1) .* sg_a(2:end) < 0);
    Tss = t(iss(end)) - t(iss(1));
    A.metrics.rl_flip_Hz = flips / max(Tss, eps);
    A.metrics.amp_P_f0_deg = rad2deg(amp(xP));
    A.metrics.amp_D_f0_deg = rad2deg(amp(xD));
    A.metrics.amp_cmd_f0_deg = rad2deg(amp(y));
    A.metrics.amp_dr_f0_deg = rad2deg(amp(y_out));
    A.metrics.amp_G_f0_deg = rad2deg(amp(xG));
    A.metrics.E_P_f0 = E(xP);
    A.metrics.E_D_f0 = E(xD);
    A.metrics.E_cmd_f0 = E(y);
    A.metrics.E_dr_f0 = E(y_out);
    A.metrics.E_G_f0 = E(xG);
    A.metrics.dom_f_cmd = dom_freq(yss, dt);
    A.metrics.dom_f_dr = dom_freq(yout, dt);
    A.metrics.dom_f_P = dom_freq(xP(iss), dt);
    A.metrics.dom_f_G = dom_freq(xG(iss), dt);
    A.metrics.e_psi_rms_deg = rad2deg(rms(e_psi(iss)));
    A.metrics.e_psi_p95_deg = local_p95(abs(rad2deg(e_psi(iss))));
    A.metrics.sat_pct = 100 * mean(abs(cmd_u(iss)) >= 0.95 * delta_r_max);
    tick_ss = S.guidance_tick(iss);
    A.metrics.yaw_ref_step_mean_deg = rad2deg(mean(abs(S.yaw_ref_inc(iss(tick_ss)))));
    % Association: nonzero |dpsi_ref| only on guidance ticks
    nz = abs(S.yaw_ref_inc(iss)) > 1e-12;
    if any(nz)
        A.metrics.psi_ref_tick_assoc = mean(tick_ss(nz));
    else
        A.metrics.psi_ref_tick_assoc = NaN;
    end

    % Store series for plot/mat
    A.series = struct('t', t, 'P', P, 'D', D, 'cmd_u', cmd_u, 'cmd_s', cmd_s, ...
        'dr', dr, 'rl_active', S.rl_active, 'cmd_minus_out', RLeff, 'Gstep', Gstep, ...
        'y_cmd', y, 'y_dr', y_out, 'xP', xP, 'xD', xD, 'xG', xG, 'xRL', xRL);
    A.Kp_psi = Kp_psi;
    A.Kd_psi = Kd_psi;
end

function m = score_source(x, y, dt, f0)
    x = x(:); y = y(:);
    vx = var(x); vy = var(y);
    if vy < 1e-30
        m = struct('corr', 0, 'var_exp', 0, 'coh_f0', 0, 'amp_ratio_f0', 0);
        return;
    end
    c = corrcoef(x, y);
    rho = c(1,2);
    if ~isfinite(rho); rho = 0; end
    % OLS R^2
    a = (x' * y) / max(x' * x, 1e-30);
    resid = y - a * x;
    R2 = max(0, 1 - var(resid) / vy);
    coh = coherence_at_f(x, y, dt, f0);
    ax = band_amp(x, dt, f0);
    ay = band_amp(y, dt, f0);
    m = struct('corr', rho, 'var_exp', R2, 'coh_f0', coh, ...
        'amp_ratio_f0', safe_div(ax, ay), 'a_ols', a, 'vx', vx, 'vy', vy);
end

function coh = coherence_at_f(x, y, dt, f0)
    x = x(:) - mean(x); y = y(:) - mean(y);
    N = numel(x);
    if N < 64
        c = corrcoef(x, y);
        coh = abs(c(1,2));
        if ~isfinite(coh); coh = 0; end
        return;
    end
    nfft = 2^nextpow2(min(N, round(8 / dt))); % ~8 s segments
    nfft = min(nfft, 2^nextpow2(N));
    noverlap = floor(nfft * 0.5);
    win = local_hann(nfft);
    % Welch cross / autospectra
    nseg = 1 + floor((N - nfft) / max(nfft - noverlap, 1));
    if nseg < 1
        nseg = 1; nfft = N; win = local_hann(N); noverlap = 0;
    end
    Pxx = 0; Pyy = 0; Pxy = 0;
    for s = 1:nseg
        i0 = 1 + (s-1) * (nfft - noverlap);
        i1 = i0 + nfft - 1;
        if i1 > N; break; end
        xw = x(i0:i1) .* win;
        yw = y(i0:i1) .* win;
        X = fft(xw, nfft);
        Y = fft(yw, nfft);
        Pxx = Pxx + X .* conj(X);
        Pyy = Pyy + Y .* conj(Y);
        Pxy = Pxy + Y .* conj(X);
    end
    f = (0:nfft-1)' / (nfft * dt);
    [~, k] = min(abs(f - f0));
    den = abs(Pxx(k)) * abs(Pyy(k));
    if den < 1e-30
        coh = 0;
    else
        coh = abs(Pxy(k))^2 / den;
        coh = min(1, max(0, real(coh)));
    end
end

function a = band_amp(x, dt, f0)
    x = x(:) - mean(x);
    N = numel(x);
    win = local_hann(N);
    X = fft(x .* win);
    f = (0:N-1)' / (N * dt);
    [~, k] = min(abs(f - f0));
    % single-sided amplitude (approx)
    a = 2 * abs(X(k)) / sum(win);
end

function E = band_energy(x, dt, f0)
    x = x(:) - mean(x);
    N = numel(x);
    win = local_hann(N);
    X = fft(x .* win);
    f = (0:N-1)' / (N * dt);
    df = 1 / (N * dt);
    bw = max(df, 0.15); % ±0.15 Hz
    mask = (f >= f0 - bw) & (f <= f0 + bw);
    E = sum(abs(X(mask)).^2) / (sum(win)^2);
end

function fdom = dom_freq(x, dt)
    x = x(:) - mean(x);
    N = numel(x);
    win = local_hann(N);
    X = abs(fft(x .* win));
    f = (0:N-1)' / (N * dt);
    kmax = floor(N/2);
    [~, k] = max(X(2:kmax)); % skip DC
    fdom = f(k + 1);
end

function idx = find_acq(in_band, need)
    idx = [];
    run = 0;
    for i = 1:numel(in_band)
        if in_band(i)
            run = run + 1;
            if run >= need
                idx = i;
                return;
            end
        else
            run = 0;
        end
    end
end

function y = local_p95(x)
    x = sort(x(:));
    if isempty(x); y = NaN; return; end
    k = max(1, min(numel(x), ceil(0.95 * numel(x))));
    y = x(k);
end

function z = safe_div(a, b)
    if abs(b) < 1e-30; z = 0; else; z = a / b; end
end

%% ===================== evidence =====================
function write_evidence(out_dir, tag, S, A, R, u0, T_final, Kp, Kd, ...
        delta_r_max, dt_c, dt_g)
    mat_path = fullfile(out_dir, [tag '.mat']);
    png_path = fullfile(out_dir, [tag '.png']);
    md_path  = fullfile(out_dir, [tag '.md']);

    save(mat_path, 'S', 'A', 'R', 'u0', 'T_final', 'Kp', 'Kd', ...
        'delta_r_max', 'dt_c', 'dt_g', '-v7.3');

    % ---- PNG ----
    t = A.series.t;
    iss = A.i_ss;
    tss = t(iss);
    fig = figure('Visible', 'off', 'Position', [40 40 1400 920]);
    tiledlayout(3, 2, 'Padding', 'compact', 'TileSpacing', 'compact');

    nexttile; hold on;
    plot(tss, rad2deg(A.series.P(iss)), 'b');
    plot(tss, rad2deg(A.series.D(iss)), 'r');
    plot(tss, rad2deg(A.series.cmd_u(iss)), 'k--');
    plot(tss, rad2deg(A.series.dr(iss)), 'm');
    ylabel('deg'); title('P, D, unsat cmd, rudder (steady)');
    legend('P','D','cmd_{unsat}','\delta_r','Location','best');
    xlim([tss(1) tss(min(end, round(5/S.dt)+1))]); % zoom first ~5 s steady

    nexttile; hold on;
    plot(tss, rad2deg(A.series.P(iss)), 'b');
    plot(tss, rad2deg(A.series.D(iss)), 'r');
    plot(tss, rad2deg(A.series.cmd_s(iss)), 'k');
    plot(tss, rad2deg(A.series.dr(iss)), 'm');
    ylabel('deg'); title(sprintf('full steady overlay | src=%s', A.source));
    legend('P','D','cmd_{sat}','\delta_r','Location','best');

    nexttile; hold on;
    [fp, Sp_] = onesided_psd(A.series.xP(iss), S.dt);
    [fd, Sd_] = onesided_psd(A.series.xD(iss), S.dt);
    [fc, Sc_] = onesided_psd(A.series.y_cmd(iss), S.dt);
    [fr, Sr_] = onesided_psd(A.series.y_dr(iss), S.dt);
    plot(fp, Sp_, 'b'); plot(fd, Sd_, 'r'); plot(fc, Sc_, 'k'); plot(fr, Sr_, 'm');
    xline(A.f0, 'g--');
    xlim([0 20]); ylabel('amp'); xlabel('Hz');
    title(sprintf('1s-detrend spectrum (f0=%.3f Hz)', A.f0));
    legend('P','D','cmd','\delta_r','f_0','Location','best');

    nexttile; hold on;
    [fg, Sg_] = onesided_psd(A.series.xG(iss), S.dt);
    [fl, Sl_] = onesided_psd(A.series.xRL(iss), S.dt);
    plot(fg, Sg_, 'Color', [0.2 0.6 0.2]);
    plot(fl, Sl_, 'Color', [0.6 0.3 0]);
    plot(fc, Sc_, 'k');
    xline(A.f0, 'g--');
    xlim([0 20]); ylabel('amp'); xlabel('Hz');
    title('guidance-step & RL-effect vs cmd');
    legend('G_{step}','RL_{eff}','cmd','f_0','Location','best');

    nexttile; hold on;
    stem(tss, double(A.series.rl_active(iss)), 'Marker', 'none', 'Color', [0.85 0.4 0]);
    plot(tss, rad2deg(A.series.cmd_minus_out(iss)), 'k');
    ylabel('active / deg'); xlabel('t [s]');
    title(sprintf('rate-limit active (%.1f%%) + cmd-out', A.metrics.rl_active_pct));
    legend('rl_{active}','cmd-out [deg]','Location','best');
    xlim([tss(1) tss(min(end, round(5/S.dt)+1))]);

    nexttile; hold on;
    names = {A.rows.name};
    sc = [A.rows.select_score];
    rl = [A.rows.select_rel];
    bar(1:4, [sc(:), rl(:)]);
    yline(0.70, 'r--');
    set(gca, 'XTick', 1:4, 'XTickLabel', names);
    ylim([0 1.05]);
    title('var-explained / relation (gate >=0.70)');
    legend('var/share','|corr|\vee coh','0.70','Location','best');
    xtickangle(20);

    exportgraphics(fig, png_path, 'Resolution', 130);
    close(fig);

    % ---- MD ----
    fid = fopen(md_path, 'w');
    fprintf(fid, '# R75_YAW_INTERNAL_ATTRIB\n\n');
    fprintf(fid, '**TASK_ID:** R75_YAW_INTERNAL_ATTRIB_001\n');
    fprintf(fid, '**Date:** %s\n', datestr(now, 31));
    fprintf(fid, '**Verdict:** %s\n', A.verdict);
    fprintf(fid, '**Single source:** %s\n\n', A.source);

    fprintf(fid, '## Summary\n\n');
    fprintf(fid, ['Instrumented one deterministic R=%.1f, u=%.2f, T=%.0fs run. ', ...
        'Reconstructed P/D/cmd/rate-limit from production equations without ', ...
        'modifying controller_law.m / guidance_law.m. Gate: var>=0.70 and ', ...
        'relation/coherence>=0.70 on command ripple (RL vs output).\n\n'], R, u0, T_final);
    fprintf(fid, '- Acquisition: %s -> t_acq=%.2f s\n', A.acq_method, A.t_acq);
    fprintf(fid, '- Steady: %d turns used after t_ss0=%.2f s (T_lap_est=%.1f)\n', ...
        A.n_turns_used, A.t_ss0, A.T_lap_est);
    fprintf(fid, '- f_g=%.4f Hz, f_c=%.4f Hz, target f0=%.4f Hz\n\n', A.f_g, A.f_c, A.f0);

    fprintf(fid, '## Metric table (5 rows)\n\n');
    fprintf(fid, '| Source | var/share | |corr| | coh@f0 | amp_ratio@f0 | select |\n');
    fprintf(fid, '|---|---:|---:|---:|---:|---:|\n');
    for i = 1:numel(A.rows)
        r = A.rows(i);
        sel = '';
        if strcmp(A.source, r.name); sel = 'CHOSEN'; end
        fprintf(fid, '| %s | %.4f | %.4f | %.4f | %.4f | %s |\n', ...
            r.name, r.select_score, abs(r.corr), r.coh_f0, r.amp_ratio_f0, sel);
    end

    fprintf(fid, '\n## Support metrics\n\n');
    M = A.metrics;
    fprintf(fid, '| Item | Value |\n|---|---:|\n');
    fprintf(fid, '| e_psi RMS / p95 [deg] | %.4f / %.4f |\n', M.e_psi_rms_deg, M.e_psi_p95_deg);
    fprintf(fid, '| P / D ripple RMS [deg] | %.4f / %.4f |\n', M.P_rms_deg, M.D_rms_deg);
    fprintf(fid, '| cmd_sat / delta_r ripple RMS [deg] | %.4f / %.4f |\n', ...
        M.cmd_sat_rms_deg, M.dr_rms_deg);
    fprintf(fid, '| cmd-out diff RMS / MAE [deg] | %.4f / %.4f |\n', ...
        M.cmd_out_diff_rms_deg, M.cmd_out_diff_mae_deg);
    fprintf(fid, '| rate-limit active %% | %.2f |\n', M.rl_active_pct);
    fprintf(fid, '| RL sign-flip freq [Hz] | %.4f |\n', M.rl_flip_Hz);
    fprintf(fid, '| sat %% (|cmd_u|>=0.95 dmax) | %.2f |\n', M.sat_pct);
    fprintf(fid, '| dom f cmd / dr / P / Gstep [Hz] | %.4f / %.4f / %.4f / %.4f |\n', ...
        M.dom_f_cmd, M.dom_f_dr, M.dom_f_P, M.dom_f_G);
    fprintf(fid, '| amp@f0 P/D/cmd/dr [deg] | %.4f / %.4f / %.4f / %.4f |\n', ...
        M.amp_P_f0_deg, M.amp_D_f0_deg, M.amp_cmd_f0_deg, M.amp_dr_f0_deg);
    fprintf(fid, '| mean |dpsi_ref| on ticks [deg] | %.4f |\n', M.yaw_ref_step_mean_deg);
    fprintf(fid, '| psi_ref change <-> guidance-tick assoc | %.4f |\n', M.psi_ref_tick_assoc);

    fprintf(fid, '\n## Classification\n\n');
    if strcmp(A.verdict, 'PASS')
        fprintf(fid, '**PASS — source = %s** (score=%.3f, relation=%.3f).\n\n', ...
            A.source, A.best.var_exp, A.best.rel);
    else
        fprintf(fid, '**FAIL — UNKNOWN** (best=%s score=%.3f relation=%.3f; need both >=0.70).\n\n', ...
            A.best.name, A.best.var_exp, A.best.rel);
    end

    if strcmp(A.source, 'guidance_step')
        next_c = 'Hold/interpolate yaw_ref (and r_ff) between guidance ticks (ZOH->ramp over dt_g); target >=10% drop in rudder ripple RMS with yaw RMS/p95 regression <=2%.';
    elseif strcmp(A.source, 'P-yaw')
        next_c = 'Reduce P-path step response: interpolate yaw_ref before Kp*e_psi (same as guidance hold) OR mild Kp reduction only if interp unavailable; prefer ref continuity first.';
    elseif strcmp(A.source, 'D/r_ff')
        next_c = 'Smooth/hold r_ff with yaw_ref between guidance ticks; check Kd*e_r contribution at f_g.';
    elseif strcmp(A.source, 'rudder_rate_limiter')
        next_c = 'Raise rudder rate limit or pre-filter cmd before rate limit; verify 13.33 Hz drops without yaw regression.';
    else
        next_c = 'NO_CHANGE';
    end
    fprintf(fid, '**Recommended next (minimal):** %s\n\n', next_c);

    fprintf(fid, '## Evidence paths\n\n');
    fprintf(fid, '- suite_results/%s.md\n', tag);
    fprintf(fid, '- suite_results/%s.mat\n', tag);
    fprintf(fid, '- suite_results/%s.png\n\n', tag);

    fprintf(fid, '## MATHEMATICAL_DELTA\n\n```\n');
    fprintf(fid, 'MATHEMATICAL_DELTA = {\n');
    fprintf(fid, '  equations: {\n');
    fprintf(fid, '    e_psi = wrap(yaw_ref - psi),\n');
    fprintf(fid, '    e_r = r - r_ff,\n');
    fprintf(fid, '    P = Kp_psi * e_psi,  D = -Kd_psi * e_r,\n');
    fprintf(fid, '    cmd_unsat = P + D,  cmd_sat = clip(cmd_unsat, +/-dmax),\n');
    fprintf(fid, '    max_dr = 40deg/s * dt_c,\n');
    fprintf(fid, '    delta_r = rate_limit(cmd_sat, max_dr),\n');
    fprintf(fid, '    Gstep = Kp_psi * (yaw_ref_ZOH - yaw_ref_linear_interp),\n');
    fprintf(fid, '    RLeff = cmd_sat - delta_r,\n');
    fprintf(fid, '    x_ripple = x - movmean(x, 1s),\n');
    fprintf(fid, '    var_share_P/D = E[x*cmd]/E[cmd^2],  R2 = 1-var(y-a*x)/var(y),\n');
    fprintf(fid, '    coh(f0) = |Pxy|^2 / (Pxx*Pyy) @ f0=1/dt_g\n');
    fprintf(fid, '  },\n');
    fprintf(fid, '  variables_units_frames: {\n');
    fprintf(fid, '    angles/cmd [rad] internal, reported [deg]; r,r_ff [rad/s]; f [Hz]\n');
    fprintf(fid, '  },\n');
    fprintf(fid, '  assumptions: {\n');
    fprintf(fid, '    production freeze Kp=%.0f Kd=%.0f dt_c=%.4f dt_g=%.4f dmax=%.0fdeg;\n', ...
        Kp, Kd, dt_c, dt_g, rad2deg(delta_r_max));
    fprintf(fid, '    reconstruct yaw path identical to controller_law; plant via ode45;\n');
    fprintf(fid, '    gate: score>=0.70 AND max(|corr|,coh)>=0.70\n');
    fprintf(fid, '  },\n');
    fprintf(fid, '  parameter_provenance: {\n');
    fprintf(fid, '    DERIVED: P,D,cmd,RL flags, spectra, scores from instrumented sim,\n');
    fprintf(fid, '    IDENTIFIED: source=%s,\n', A.source);
    fprintf(fid, '    TUNED: none,\n');
    fprintf(fid, '    FIXED: R=7.5,u=1.5,T=120, windows as radial/baseline\n');
    fprintf(fid, '  },\n');
    fprintf(fid, '  design_reason: ''Bind 13.33 Hz rudder ripple to one internal component quantitatively.'',\n');
    fprintf(fid, '  rejected_alternatives: {\n');
    fprintf(fid, '    production_edit: rejected (audit-only),\n');
    fprintf(fid, '    gain_retune: rejected (attribution first)\n');
    fprintf(fid, '  },\n');
    fprintf(fid, '  evidence: { suite_results/%s.* },\n', tag);
    fprintf(fid, '  conclusion: ''%s: source=%s'',\n', A.verdict, A.source);
    fprintf(fid, '  open_questions: { next=%s }\n', next_c);
    fprintf(fid, '}\n```\n');
    fclose(fid);
end

function [f, A] = onesided_psd(x, dt)
    x = x(:) - mean(x);
    N = numel(x);
    win = local_hann(N);
    X = fft(x .* win);
    f = (0:floor(N/2))' / (N * dt);
    A = 2 * abs(X(1:numel(f))) / sum(win);
    A(1) = A(1) / 2;
end

function y_lin = zoh_to_linear(y_zoh, tick)
% Replace ZOH staircase with piecewise-linear interp through tick samples.
    y_zoh = y_zoh(:);
    tick = tick(:);
    n = numel(y_zoh);
    idx = find(tick);
    if numel(idx) < 2
        y_lin = y_zoh;
        return;
    end
    if idx(1) ~= 1
        idx = [1; idx];
    end
    if idx(end) ~= n
        idx = [idx; n];
    end
    % Unique sample times
    [idx_u, ~] = unique(idx, 'stable');
    y_u = y_zoh(idx_u);
    y_lin = interp1(idx_u, y_u, (1:n)', 'linear', 'extrap');
end

function w = local_hann(N)
% Periodic/symmetric Hann without Signal Processing Toolbox.
    N = double(N);
    if N <= 1
        w = ones(N, 1);
        return;
    end
    n = (0:N-1)';
    w = 0.5 - 0.5 * cos(2 * pi * n / max(N - 1, 1));
end
