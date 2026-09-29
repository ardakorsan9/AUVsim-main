function run_roll_trim_relative_audit()
% ROLL_TRIM_RELATIVE_AUDIT_001 — separate required/benign turn bank from roll ripple.
% Read-only: ROLL_BASELINE_AUDIT.mat, LOCAL_SS_LEVEL.mat, LOCAL_SS_CLIMB.mat.
% One MATLAB invocation; no re-sim; no controller/guidance/plant edit.
% Artifacts: suite_results/ROLL_TRIM_RELATIVE_AUDIT.{md,mat,png}; append STATE_SPACE_MODEL_AUDIT.md

    project_dir = fileparts(fileparts(fileparts(mfilename('fullpath')))); % repo root
    addpath(genpath(fullfile(project_dir, 'matlab')));
    out_dir = fullfile(project_dir, 'suite_results');
    if ~exist(out_dir, 'dir'); mkdir(out_dir); end
    tag = 'ROLL_TRIM_RELATIVE_AUDIT';
    task_id = 'ROLL_TRIM_RELATIVE_AUDIT_001';

    base_path  = fullfile(out_dir, 'ROLL_BASELINE_AUDIT.mat');
    level_path = fullfile(out_dir, 'LOCAL_SS_LEVEL.mat');
    climb_path = fullfile(out_dir, 'LOCAL_SS_CLIMB.mat');
    assert(exist(base_path, 'file') == 2, 'Missing %s', base_path);
    assert(exist(level_path, 'file') == 2, 'Missing %s', level_path);
    assert(exist(climb_path, 'file') == 2, 'Missing %s', climb_path);

    Base = load(base_path);
    Lss  = load(level_path);
    Css  = load(climb_path);

    fprintf('\n========== %s ==========\n', task_id);
    fprintf('Sources: ROLL_BASELINE_AUDIT.mat / LOCAL_SS_LEVEL.mat / LOCAL_SS_CLIMB.mat\n');
    fprintf('Mode: read-only analysis (no re-sim, no controller edit)\n');

    % Plant globals needed only for exact RHS residual at stored mean (not a traj re-sim)
    clear functions
    clear global last_delta_e last_guidance_U_h last_guidance_kappa last_r_ff
    init_parameters();
    global thrust_trim Kp_x

    plant = extract_roll_plant(Lss, Css);
    fprintf('Plant roll level: f=%.4f Hz zeta=%.5f | climb: f=%.4f Hz zeta=%.5f\n', ...
        plant.level.f_Hz, plant.level.zeta, plant.climb.f_Hz, plant.climb.zeta);

    % ---- X / XZ: phi_eq ≡ 0 ----
    RX = analyze_straight(Base.X, Base.SX, 0.0, 'X', plant.level);
    RXZ = analyze_straight(Base.XZ, Base.SXZ, 0.0, 'XZ', plant.climb);

    % ---- R10 helix: identify phi_eq + residual + trim-relative ripple ----
    RH = analyze_helix_trim_relative(Base.H, Base.SH, plant.level, thrust_trim, Kp_x);

    % ---- Gates / decision ----
    gates = score_gates(RX, RXZ, RH);
    [verdict, class_label, next_opt, next_detail] = decide(RX, RXZ, RH, gates, plant);

    md_path  = fullfile(out_dir, [tag '.md']);
    mat_path = fullfile(out_dir, [tag '.mat']);
    png_path = fullfile(out_dir, [tag '.png']);

    write_png(png_path, RX, RXZ, RH, task_id, verdict);
    write_md(md_path, task_id, verdict, plant, RX, RXZ, RH, gates, ...
        class_label, next_opt, next_detail, md_path, mat_path, png_path, ...
        base_path, level_path, climb_path);
    append_ss_audit(out_dir, task_id, verdict, plant, RX, RXZ, RH, gates, ...
        class_label, next_opt, next_detail, md_path, mat_path, png_path);

    S = struct();
    S.task_id = task_id;
    S.verdict = verdict;
    S.class_label = class_label;
    S.next_opt = next_opt;
    S.next_detail = next_detail;
    S.plant = plant;
    S.X = RX; S.XZ = RXZ; S.H = RH;
    S.gates = gates;
    S.sources = {base_path; level_path; climb_path};
    S.paths = struct('md', md_path, 'mat', mat_path, 'png', png_path);
    S.note = ['Trim-relative roll audit: phi_eq identified on R10 steady; ', ...
        'plant roll residual labels equilibrium vs empirical; no re-sim'];
    save(mat_path, '-struct', 'S');

    fprintf('\nVERDICT: %s | class=%s | next=%s\n', verdict, class_label, next_opt);
    fprintf('Saved: %s\n%s\n%s\n', md_path, mat_path, png_path);
    print_feedback(verdict, RX, RXZ, RH, gates, class_label, next_opt, next_detail, ...
        md_path, mat_path, png_path);
    assignin('base', 'ROLL_TRIM_RELATIVE_AUDIT_PASS', strcmp(verdict, 'PASS'));
end

%% ===================== plant roll mode =====================
function plant = extract_roll_plant(Lss, Css)
    plant = struct();
    plant.level = roll_mode_from_ss(Lss);
    plant.climb = roll_mode_from_ss(Css);
    plant.frame = 'NED eta + BODY nu; Euler ZYX; lateral [y phi psi v p r] w/ [dr]';
    plant.units = 'phi [rad], p [rad/s]; reported deg / deg/s';
end

function m = roll_mode_from_ss(SS)
    A = SS.A_lateral;
    ev = eig(A);
    % Prefer lightly-damped oscillatory mode near known roll band
    wn = abs(ev);
    zeta = -real(ev) ./ max(wn, eps);
    osc = (imag(ev) > 0.5) & (abs(real(ev)) < 0.5);
    if any(osc)
        cand = find(osc);
        [~, k] = min(abs(zeta(cand)));
        lam = ev(cand(k));
    else
        [~, k] = max(imag(ev));
        lam = ev(k);
    end
    m = struct();
    m.lam = lam;
    m.wn = abs(lam);
    m.f_Hz = abs(imag(lam)) / (2 * pi);
    m.zeta = -real(lam) / max(m.wn, eps);
    m.T_s = 1 / max(m.f_Hz, eps);
end

%% ===================== straight (phi_eq=0) =====================
function R = analyze_straight(M, S, phi_eq, name, plant_mode)
    t = S.t(:);
    dt = S.dt;
    phi = S.ori(:, 1);
    p = S.rates(:, 1);
    mask = M.series.mask_ss(:);
    if ~any(mask)
        mask = t >= 5;
    end

    tilde = phi - phi_eq;
    R = struct();
    R.name = name;
    R.phi_eq_rad = phi_eq;
    R.phi_eq_deg = rad2deg(phi_eq);
    R.phi_eq_provenance = 'forced_zero_straight_no_yaw';
    R.phi_eq_label = 'equilibrium_trivial';
    R.mask_ss = mask;
    R.t = t;
    R.dt = dt;
    R.phi = phi;
    R.p = p;
    R.tilde_phi = tilde;
    R.abs = abs_stats(phi, mask);
    R.tilde = signed_err_stats(tilde, mask);
    R.pmet = rate_stats(p, mask);
    R.spec = spectral_ripple(tilde, p, mask, dt, plant_mode);
    R.cycle = struct('n_turns', 0, 'stable', true, 'note', 'N/A straight');
    R.half = struct('mean1_deg', rad2deg(mean(phi(mask))), ...
        'mean2_deg', rad2deg(mean(phi(mask))), 'delta_deg', 0, 'stable', true);
    R.residual = struct('evaluated', false, 'is_small', true, ...
        'note', 'straight phi_eq=0; no helix bank residual required');
    R.plant_mode = plant_mode;
end

%% ===================== helix trim-relative =====================
function R = analyze_helix_trim_relative(M, S, plant_mode, thrust_trim, Kp_x)
    t = S.t(:);
    dt = S.dt;
    phi = S.ori(:, 1);
    p = S.rates(:, 1);
    psi = S.ori(:, 3);
    mask = M.series.mask_ss(:);
    if ~any(mask)
        mask = (t >= 5) & (t <= 0.88 * t(end));
    end

    % ---- Identify phi_eq from turn cycles (robust mean/median) ----
    id = identify_phi_eq(phi, psi, t, mask);
    phi_eq = id.phi_eq_rad;

    tilde = phi - phi_eq;

    % ---- Exact plant residual at window-mean state/input ----
    resid = plant_roll_residual(S, mask, thrust_trim, Kp_x);

    if resid.is_small
        phi_eq_label = 'quasi_equilibrium_bank';
        provenance = sprintf(['IDENTIFIED robust turn %s=%.4f deg; ', ...
            'plant roll residual SMALL → treat as quasi-steady bank'], ...
            id.estimator, rad2deg(phi_eq));
    else
        phi_eq_label = 'empirical_cycle_mean_not_equilibrium';
        provenance = sprintf(['IDENTIFIED robust turn %s=%.4f deg; ', ...
            'plant roll residual NOT small → empirical bank, not equilibrium'], ...
            id.estimator, rad2deg(phi_eq));
    end

    R = struct();
    R.name = 'H_R10';
    R.R_helix = S.R;
    R.phi_eq_rad = phi_eq;
    R.phi_eq_deg = rad2deg(phi_eq);
    R.phi_eq_provenance = provenance;
    R.phi_eq_label = phi_eq_label;
    R.phi_eq_id = id;
    R.mask_ss = mask;
    R.t = t;
    R.dt = dt;
    R.phi = phi;
    R.p = p;
    R.tilde_phi = tilde;
    R.abs = abs_stats(phi, mask);
    R.tilde = signed_err_stats(tilde, mask);
    R.pmet = rate_stats(p, mask);
    R.spec = spectral_ripple(tilde, p, mask, dt, plant_mode);
    R.cycle = id.cycle;
    R.half = id.half;
    R.residual = resid;
    R.plant_mode = plant_mode;
    R.yaw_mae_deg = M.yaw.mae_deg;
end

function id = identify_phi_eq(phi, psi, t, mask)
    phi_m = phi(mask);
    psi_m = unwrap(psi(mask));
    t_m = t(mask);

    % Overall robust candidates
    mean_all = mean(phi_m);
    med_all = median(phi_m);

    % Per-turn means (helix turn = +2π in unwrap(psi))
    turn_idx = floor((psi_m - psi_m(1)) / (2 * pi)) + 1;
    n_turns = max(turn_idx);
    turn_mean = nan(n_turns, 1);
    turn_med = nan(n_turns, 1);
    turn_n = zeros(n_turns, 1);
    for k = 1:n_turns
        ik = turn_idx == k;
        turn_n(k) = nnz(ik);
        if turn_n(k) >= 8
            turn_mean(k) = mean(phi_m(ik));
            turn_med(k) = median(phi_m(ik));
        end
    end
    valid = isfinite(turn_mean);
    if any(valid)
        robust_mean = median(turn_mean(valid));   % robust across turns
        robust_med  = median(turn_med(valid));
    else
        robust_mean = mean_all;
        robust_med = med_all;
    end

    % Prefer robust turn-mean; fall back to overall median if unstable
    phi_eq = robust_mean;
    estimator = 'median(per_turn_mean)';

    % First vs last half stability
    n = numel(phi_m);
    i1 = 1:floor(n / 2);
    i2 = (floor(n / 2) + 1):n;
    mean1 = mean(phi_m(i1));
    mean2 = mean(phi_m(i2));
    half_delta = abs(mean2 - mean1);
    half_stable = half_delta <= deg2rad(0.25);  % <0.25 deg drift

    if any(valid)
        turn_spread = max(turn_mean(valid)) - min(turn_mean(valid));
        turn_stable = turn_spread <= deg2rad(0.35);
    else
        turn_spread = NaN;
        turn_stable = false;
    end

    if ~turn_stable && half_stable
        phi_eq = med_all;
        estimator = 'overall_median_fallback';
    elseif ~half_stable && ~turn_stable
        phi_eq = med_all;
        estimator = 'overall_median_unstable';
    end

    % Confidence
    if turn_stable && half_stable
        conf = 'high';
    elseif turn_stable || half_stable
        conf = 'medium';
    else
        conf = 'low';
    end

    id = struct();
    id.phi_eq_rad = phi_eq;
    id.estimator = estimator;
    id.mean_all_deg = rad2deg(mean_all);
    id.median_all_deg = rad2deg(med_all);
    id.robust_turn_mean_deg = rad2deg(robust_mean);
    id.robust_turn_med_deg = rad2deg(robust_med);
    id.confidence = conf;
    id.half = struct('mean1_deg', rad2deg(mean1), 'mean2_deg', rad2deg(mean2), ...
        'delta_deg', rad2deg(half_delta), 'stable', half_stable);
    id.cycle = struct();
    id.cycle.n_turns = n_turns;
    id.cycle.turn_n = turn_n;
    id.cycle.turn_mean_deg = rad2deg(turn_mean);
    id.cycle.turn_med_deg = rad2deg(turn_med);
    id.cycle.turn_spread_deg = rad2deg(turn_spread);
    id.cycle.stable = turn_stable;
    id.cycle.t_span = [t_m(1), t_m(end)];
end

function resid = plant_roll_residual(S, mask, thrust_trim, Kp_x)
    % Exact underwater777 RHS at steady-window mean state/input.
    % Reconstruct thrust from frozen speed loop (same as TRIM_OPERATING_POINTS).
    n = size(S.vp, 1);
    x = zeros(n, 12);
    x(:, 1:3) = S.vp;
    x(:, 4:6) = S.ori;
    x(:, 7:9) = S.vel;
    x(:, 10:12) = S.rates;
    thr = thrust_trim + Kp_x * (S.u_ref(:) - S.vel(:, 1));
    u = [S.delta_r(:), S.delta_e(:), thr];

    Xw = x(mask, :);
    Uw = u(mask, :);
    x_mean = mean(Xw, 1).';
    u_mean = mean(Uw, 1).';

    % Canonical helix evaluation point (match trim OP convention)
    Rhelix = S.R;
    psi_u = unwrap(S.ori(mask, 3));
    t_m = S.t(mask);
    if numel(t_m) > 2
        Omega = (psi_u(end) - psi_u(1)) / max(t_m(end) - t_m(1), eps);
    else
        Omega = mean(Xw(:, 12));
    end
    x_star = x_mean;
    x_star(1:3) = [Rhelix; 0; 0];
    x_star(6) = 0;
    u_star = u_mean;
    ctr = struct('delta_r', u_star(1), 'delta_e', u_star(2), 'thrust', u_star(3));

    f = underwater777_vehicle_dynamics(0, x_star, ctr);

    nu_dot_scale = [1.0; 0.3; 0.3; 0.2; 0.2; 0.2];
    pass_tol = 0.01;  % 1% normalized
    nu_dot = f(7:12);
    nu_dot_norm = abs(nu_dot) ./ nu_dot_scale;
    norm_dyn = max(nu_dot_norm);
    % Rotating-frame relative residual (incl. attitude rates vs Omega)
    rel = [nu_dot; f(4); f(5); f(6) - Omega];
    rel_scale = [nu_dot_scale; 0.05; 0.05; 0.05];
    rel_norm = abs(rel) ./ rel_scale;
    norm_rel = max(rel_norm);

    p_dot = nu_dot(4);          % roll-rate residual
    p_dot_norm = nu_dot_norm(4);
    phi_dot = f(4);

    is_small = (p_dot_norm <= pass_tol) && (norm_rel <= pass_tol);

    resid = struct();
    resid.evaluated = true;
    resid.x_mean = x_mean;
    resid.u_mean = u_mean;
    resid.x_star = x_star;
    resid.u_star = u_star;
    resid.Omega = Omega;
    resid.f = f;
    resid.nu_dot = nu_dot;
    resid.nu_dot_norm_comp = nu_dot_norm;
    resid.norm_dyn = norm_dyn;
    resid.norm_rel = norm_rel;
    resid.p_dot = p_dot;
    resid.p_dot_norm = p_dot_norm;
    resid.phi_dot = phi_dot;
    resid.pass_tol = pass_tol;
    resid.is_small = is_small;
    if is_small
        resid.class = 'quasi_steady_roll_residual_small';
    else
        resid.class = 'not_quasi_steady_roll_residual';
    end
    resid.note = sprintf(['p_dot=%.4e (norm=%.4g), norm_dyn=%.4g, norm_rel=%.4g ', ...
        '(tol=%.2g); phi*=%.4f deg'], ...
        p_dot, p_dot_norm, norm_dyn, norm_rel, pass_tol, rad2deg(x_mean(4)));
end

%% ===================== stats / spectrum =====================
function st = abs_stats(phi, mask)
    v = phi(mask);
    st = struct();
    st.signed_mean_deg = rad2deg(mean(v));
    st.mae_deg = rad2deg(mean(abs(v)));
    st.rms_deg = rad2deg(rms_local(v));
    st.p95_deg = rad2deg(prctile_local(abs(v), 95));
    st.max_deg = rad2deg(max(abs(v)));
    st.n = numel(v);
end

function st = signed_err_stats(e, mask)
    v = e(mask);
    st = struct();
    st.signed_mean_deg = rad2deg(mean(v));
    st.mae_deg = rad2deg(mean(abs(v)));
    st.rms_deg = rad2deg(rms_local(v));
    st.p95_deg = rad2deg(prctile_local(abs(v), 95));
    st.max_deg = rad2deg(max(abs(v)));
    st.n = numel(v);
end

function st = rate_stats(p, mask)
    v = p(mask);
    st = struct();
    st.signed_mean_dps = rad2deg(mean(v));
    st.mae_dps = rad2deg(mean(abs(v)));
    st.rms_dps = rad2deg(rms_local(v));
    st.p95_dps = rad2deg(prctile_local(abs(v), 95));
    st.max_dps = rad2deg(max(abs(v)));
end

function sp = spectral_ripple(tilde_phi, p, mask, dt, plant_mode)
    sp = struct();
    x = tilde_phi(mask); x = x(:) - mean(x);
    pp = p(mask); pp = pp(:) - mean(pp);
    f_target = plant_mode.f_Hz;
    if numel(x) < 64
        sp.phi_f_Hz = NaN; sp.p_f_Hz = NaN; sp.amp_781_deg = NaN;
        sp.decay_per_cycle = NaN; sp.growth = NaN; sp.match_plant = false;
        sp.damp_proxy = NaN; sp.confidence = 'none';
        return;
    end

    [f, Pphi] = onesided_psd(x, dt);
    [fp, Pp] = onesided_psd(pp, dt);
    ikeep = f > 0.05;
    ff = f(ikeep);
    [~, i1] = max(Pphi(ikeep));
    sp.phi_f_Hz = ff(i1);
    ikeep2 = fp > 0.05;
    ff2 = fp(ikeep2);
    [~, i2] = max(Pp(ikeep2));
    sp.p_f_Hz = ff2(i2);

    % Amplitude / cycle decay from Hilbert envelope at plant roll frequency
    [amp_deg, env_peaks, decay_pc, growth] = cycle_envelope_metrics(x, dt, f_target);
    sp.amp_781_deg = amp_deg;
    sp.target_f_Hz = f_target;
    sp.decay_per_cycle = decay_pc;
    sp.growth = growth;
    sp.env_peaks_deg = env_peaks;
    sp.damp_proxy = damp_proxy_hilbert(x, dt, f_target);
    sp.df_vs_plant_Hz = abs(sp.p_f_Hz - f_target);
    sp.match_plant = sp.df_vs_plant_Hz < 0.15 * max(f_target, 0.1);
    if sp.match_plant && isfinite(decay_pc)
        sp.confidence = 'high';
    elseif sp.match_plant
        sp.confidence = 'medium';
    else
        sp.confidence = 'low';
    end
    sp.Pphi = Pphi; sp.f = f;  % for PNG
end

function [amp_deg, peaks_deg, decay_pc, growth] = cycle_envelope_metrics(x, dt, f0)
    amp_deg = NaN; peaks_deg = []; decay_pc = NaN; growth = NaN;
    x = x(:);
    if numel(x) < 64 || ~(f0 > 0); return; end
    try
        env = abs(hilbert(x));
    catch
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
    amp_deg = rad2deg(mean(env));

    % Peak-per-cycle sampling
    T = 1 / f0;
    n_per = max(4, round(T / dt));
    n_cyc = floor(numel(env) / n_per);
    if n_cyc < 3; return; end
    peaks = zeros(n_cyc, 1);
    for k = 1:n_cyc
        seg = env((k-1)*n_per + 1 : k*n_per);
        peaks(k) = max(seg);
    end
    peaks_deg = rad2deg(peaks);
    % Log-linear fit: peak(k) = A * rho^k
    kk = (0:n_cyc-1)';
    pk = max(peaks, max(peaks) * 1e-9);
    coef = polyfit(kk, log(pk), 1);
    rho = exp(coef(1));           % growth factor per cycle
    decay_pc = 1 - rho;           % >0 decay, <0 growth
    growth = rho - 1;
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
    n = numel(env);
    i0 = max(1, round(0.2 * n));
    i1 = min(n, round(0.8 * n));
    tt = ((i0:i1)' - 1) * dt;
    ee = max(env(i0:i1), max(env) * 1e-6);
    pfit = polyfit(tt, log(ee), 1);
    sigma = -pfit(1);
    wn = 2 * pi * f0;
    z = sigma / max(wn, eps);
    z = max(min(z, 2), -0.5);
end

function y = rms_local(x)
    x = x(:);
    y = sqrt(mean(x.^2));
end

function y = prctile_local(x, p)
    x = sort(x(:));
    if isempty(x); y = NaN; return; end
    n = numel(x);
    k = max(1, min(n, round(p / 100 * n)));
    y = x(k);
end

%% ===================== gates / decision =====================
function G = score_gates(RX, RXZ, RH)
    % Absolute safety: max |phi| <= 5 deg (all routes)
    % Trim-relative hard / preferred on tilde_phi and p
    G = struct();
    G.abs_max_lim_deg = 5.0;
    G.hard = struct('mae', 0.75, 'p95', 1.5, 'max', 2.0, 'p_rms', 3.0);
    G.pref = struct('mae', 0.25, 'p95', 0.5, 'p_rms', 1.0);

    routes = {RX, RXZ, RH};
    names = {'X', 'XZ', 'H'};
    for i = 1:3
        R = routes{i};
        g = struct();
        g.name = names{i};
        g.abs_max_deg = R.abs.max_deg;
        g.abs_max_pass = g.abs_max_deg <= G.abs_max_lim_deg;
        g.tilde_mae = R.tilde.mae_deg;
        g.tilde_p95 = R.tilde.p95_deg;
        g.tilde_max = R.tilde.max_deg;
        g.p_rms = R.pmet.rms_dps;
        g.hard_pass = g.abs_max_pass && ...
            (g.tilde_mae <= G.hard.mae) && (g.tilde_p95 <= G.hard.p95) && ...
            (g.tilde_max <= G.hard.max) && (g.p_rms <= G.hard.p_rms);
        g.pref_pass = g.hard_pass && ...
            (g.tilde_mae <= G.pref.mae) && (g.tilde_p95 <= G.pref.p95) && ...
            (g.p_rms <= G.pref.p_rms);
        G.(names{i}) = g;
    end
    G.abs_all_pass = G.X.abs_max_pass && G.XZ.abs_max_pass && G.H.abs_max_pass;
    G.hard_all_pass = G.X.hard_pass && G.XZ.hard_pass && G.H.hard_pass;
    G.pref_all_pass = G.X.pref_pass && G.XZ.pref_pass && G.H.pref_pass;
end

function [verdict, class_label, next_opt, next_detail] = decide(RX, RXZ, RH, G, plant)
    if G.pref_all_pass
        verdict = 'PASS';
        class_label = 'freeze_roll';
        next_opt = 'freeze_roll_no_controller';
        next_detail = 'Preferred trim-relative ripple gates PASS on X/XZ/R10; freeze roll.';
        return;
    end

    if G.hard_all_pass && ~G.pref_all_pass
        verdict = 'PASS';
        class_label = 'stable_but_lightly_damped';
        next_opt = 'coordinated_yaw_roll_benchmark_about_phi_eq';
        next_detail = sprintf(['Hard trim-relative PASS / preferred FAIL. ', ...
            'Classify stable-but-lightly-damped roll ripple about phi_eq=%.3f deg (%s). ', ...
            'Recommend ONE coordinated yaw-roll benchmark about phi_eq (not zero). ', ...
            'Plant f=%.3f Hz, zeta_proxy=%.4f, amp@plant=%.3f deg.'], ...
            RH.phi_eq_deg, RH.phi_eq_label, plant.level.f_Hz, ...
            RH.spec.damp_proxy, RH.spec.amp_781_deg);
        return;
    end

    % Hard FAIL
    verdict = 'FAIL';
    class_label = 'hard_ripple_fail';
    % One authority/control root
    if ~G.H.hard_pass && G.X.hard_pass && G.XZ.hard_pass
        if ~RH.residual.is_small && (RH.tilde.mae_deg <= G.hard.mae)
            % Shouldn't happen often — bank misclassified
            next_opt = 'revisit_phi_eq_residual';
            next_detail = 'Unexpected: residual not small but tilde within hard — check phi_eq.';
        elseif RH.pmet.rms_dps > G.hard.p_rms || RH.spec.match_plant
            next_opt = 'rudder_roll_damping_authority';
            next_detail = sprintf(['Helix-only hard FAIL on trim-relative ripple ', ...
                '(tilde MAE=%.3f p95=%.3f max=%.3f p_RMS=%.3f). ', ...
                'Root: insufficient roll damping authority (no phi/p feedback; ', ...
                'plant zeta=%.4f; peak f=%.3f Hz match=%d). ', ...
                'phi_eq=%.3f deg is %s — do NOT treat mean bank as error.'], ...
                RH.tilde.mae_deg, RH.tilde.p95_deg, RH.tilde.max_deg, RH.pmet.rms_dps, ...
                plant.level.zeta, RH.spec.p_f_Hz, RH.spec.match_plant, ...
                RH.phi_eq_deg, RH.phi_eq_label);
        else
            next_opt = 'yaw_rudder_coupling_authority';
            next_detail = sprintf(['Helix-only hard FAIL; root: yaw/rudder-induced ', ...
                'roll ripple about empirical bank phi_eq=%.3f deg.'], RH.phi_eq_deg);
        end
    else
        next_opt = 'roll_authority_or_control_root';
        next_detail = 'Hard trim-relative FAIL beyond helix-only; identify roll authority/control root.';
    end
end

%% ===================== PNG =====================
function write_png(png_path, RX, RXZ, RH, task_id, verdict)
    fig = figure('Visible', 'off', 'Color', 'w', 'Position', [80 60 1280 900]);
    routes = {RX, RXZ, RH};
    titles = {'X (phi_{eq}=0)', 'XZ (phi_{eq}=0)', sprintf('R10 helix (phi_{eq}=%.3f^\\circ)', RH.phi_eq_deg)};

    for col = 1:3
        R = routes{col};
        t = R.t;
        % Row 1: absolute phi + phi_eq
        subplot(4, 3, col);
        plot(t, rad2deg(R.phi), 'b', 'LineWidth', 1.0); hold on;
        yline(R.phi_eq_deg, 'r--', 'LineWidth', 1.2);
        if any(R.mask_ss)
            yl = ylim;
            patch([t(find(R.mask_ss,1)) t(find(R.mask_ss,1,'last')) ...
                t(find(R.mask_ss,1,'last')) t(find(R.mask_ss,1))], ...
                [yl(1) yl(1) yl(2) yl(2)], [0.9 0.95 1], ...
                'EdgeColor', 'none', 'FaceAlpha', 0.25);
            uistack(findobj(gca, 'Type', 'line'), 'top');
        end
        ylabel('\phi [deg]'); title(titles{col});
        if col == 1; legend('\phi', '\phi_{eq}', 'Location', 'best'); end
        grid on;

        % Row 2: tilde_phi
        subplot(4, 3, 3 + col);
        plot(t, rad2deg(R.tilde_phi), 'k', 'LineWidth', 0.9); hold on;
        yline(0, 'r--');
        ylabel('$\tilde\phi$ [deg]', 'Interpreter', 'latex');
        if col == 1
            text(0.02, 0.92, sprintf('ss MAE=%.3f^\\circ', R.tilde.mae_deg), ...
                'Units', 'normalized', 'FontSize', 8);
        else
            text(0.02, 0.92, sprintf('ss MAE=%.3f p95=%.3f max=%.3f', ...
                R.tilde.mae_deg, R.tilde.p95_deg, R.tilde.max_deg), ...
                'Units', 'normalized', 'FontSize', 8);
        end
        grid on;

        % Row 3: p
        subplot(4, 3, 6 + col);
        plot(t, rad2deg(R.p), 'm', 'LineWidth', 0.8);
        ylabel('p [deg/s]');
        text(0.02, 0.92, sprintf('ss RMS=%.3f deg/s', R.pmet.rms_dps), ...
            'Units', 'normalized', 'FontSize', 8);
        grid on;

        % Row 4: spectrum / envelope
        subplot(4, 3, 9 + col);
        if isfield(R.spec, 'f') && ~isempty(R.spec.f) && isfield(R.spec, 'Pphi')
            semilogy(R.spec.f, R.spec.Pphi + eps, 'b'); hold on;
            xline(R.plant_mode.f_Hz, 'r--', 'LineWidth', 1.0);
            xlim([0, min(2.0, max(R.spec.f))]);
            ylabel('PSD(\phĩ)');
            xlabel('f [Hz]');
            text(0.02, 0.92, sprintf('peak=%.3f Hz amp=%.3f^\\circ', ...
                R.spec.p_f_Hz, R.spec.amp_781_deg), ...
                'Units', 'normalized', 'FontSize', 8);
        else
            plot(nan, nan);
            text(0.1, 0.5, 'no spectrum');
        end
        grid on;
    end
    sgtitle(sprintf('%s — absolute \\phi+\\phi_{eq}, \\phĩ, p, spectrum | %s', ...
        task_id, verdict), 'FontWeight', 'bold', 'Interpreter', 'tex');
    exportgraphics(fig, png_path, 'Resolution', 150);
    close(fig);
end

%% ===================== MD =====================
function write_md(md_path, task_id, verdict, plant, RX, RXZ, RH, G, ...
        class_label, next_opt, next_detail, md_path_s, mat_path, png_path, ...
        base_path, level_path, climb_path)

    fid = fopen(md_path, 'w');
    fprintf(fid, '# %s — Trim-relative roll audit\n\n', task_id);
    fprintf(fid, '**Overall verdict: %s**\n\n', verdict);

    fprintf(fid, '## Provenance\n\n');
    fprintf(fid, '- Read-only: `%s`, `%s`, `%s`\n', base_path, level_path, climb_path);
    fprintf(fid, '- Driver: `run_roll_trim_relative_audit.m` (one invocation; no re-sim; no controller edit)\n');
    fprintf(fid, '- Artifacts: `%s`, `%s`, `%s`\n\n', md_path_s, mat_path, png_path);

    fprintf(fid, '## Purpose\n\n');
    fprintf(fid, 'Separate required/benign helix turn bank from roll ripple before control design.\n');
    fprintf(fid, 'Absolute φ safety envelope kept separate from trim-relative $\\tilde\\phi=\\phi-\\phi_{eq}$.\n');
    fprintf(fid, 'Do **not** call steady bank an error without plant residual evidence.\n\n');

    fprintf(fid, '## Plant roll mode (LOCAL_SS)\n\n');
    fprintf(fid, '| Op | λ | f [Hz] | ζ | T [s] |\n');
    fprintf(fid, '|----|---|-------:|--:|------:|\n');
    fprintf(fid, '| Level | %.4e±j%.4f | %.4f | %.4f | %.3f |\n', ...
        real(plant.level.lam), imag(plant.level.lam), plant.level.f_Hz, ...
        plant.level.zeta, plant.level.T_s);
    fprintf(fid, '| Climb | %.4e±j%.4f | %.4f | %.4f | %.3f |\n\n', ...
        real(plant.climb.lam), imag(plant.climb.lam), plant.climb.f_Hz, ...
        plant.climb.zeta, plant.climb.T_s);

    fprintf(fid, '## phi_eq provenance\n\n');
    fprintf(fid, '| Route | phi_eq [°] | label | provenance |\n');
    fprintf(fid, '|-------|----------:|-------|------------|\n');
    fprintf(fid, '| X | %.4f | %s | %s |\n', RX.phi_eq_deg, RX.phi_eq_label, RX.phi_eq_provenance);
    fprintf(fid, '| XZ | %.4f | %s | %s |\n', RXZ.phi_eq_deg, RXZ.phi_eq_label, RXZ.phi_eq_provenance);
    fprintf(fid, '| H | %.4f | %s | %s |\n\n', RH.phi_eq_deg, RH.phi_eq_label, RH.phi_eq_provenance);

    id = RH.phi_eq_id;
    fprintf(fid, '### R10 identification detail\n\n');
    fprintf(fid, '- Estimator: **%s** → φ_eq = %.4f°\n', id.estimator, RH.phi_eq_deg);
    fprintf(fid, '- Overall mean/median: %.4f° / %.4f°\n', id.mean_all_deg, id.median_all_deg);
    fprintf(fid, '- Robust turn mean/med: %.4f° / %.4f°\n', ...
        id.robust_turn_mean_deg, id.robust_turn_med_deg);
    fprintf(fid, '- First/last half means: %.4f° / %.4f° (Δ=%.4f°, stable=%d)\n', ...
        id.half.mean1_deg, id.half.mean2_deg, id.half.delta_deg, id.half.stable);
    fprintf(fid, '- Per-turn means [°]: %s (spread=%.4f°, n_turns=%d, stable=%d)\n', ...
        mat2str(id.cycle.turn_mean_deg(:)', 4), id.cycle.turn_spread_deg, ...
        id.cycle.n_turns, id.cycle.stable);
    fprintf(fid, '- Identification confidence: **%s**\n\n', id.confidence);

    fprintf(fid, '## Plant roll residual (exact RHS at mean state/input)\n\n');
    rr = RH.residual;
    fprintf(fid, '- Evaluated at canonical helix point from steady-window mean (thrust reconstructed: thrust_trim+Kp_x(u_ref−u))\n');
    fprintf(fid, '- p_dot = %.6e rad/s² (norm = %.5g vs tol %.2g)\n', ...
        rr.p_dot, rr.p_dot_norm, rr.pass_tol);
    fprintf(fid, '- φ_dot = %.6e rad/s\n', rr.phi_dot);
    fprintf(fid, '- norm_dyn = %.5g | norm_rel (rotating) = %.5g\n', rr.norm_dyn, rr.norm_rel);
    fprintf(fid, '- ν̇_norm_comp = [%s]\n', sprintf('%.4g ', rr.nu_dot_norm_comp));
    fprintf(fid, '- Residual small? **%s** → label **%s**\n', yn(rr.is_small), RH.phi_eq_label);
    fprintf(fid, '- Note: %s\n\n', rr.note);

    fprintf(fid, '## Absolute φ safety envelope (ref=0 context)\n\n');
    fprintf(fid, '| Route | signed_mean [°] | MAE | RMS | p95 | max | abs_max≤5° |\n');
    fprintf(fid, '|-------|----------------:|----:|----:|----:|----:|:----------:|\n');
    routes = {RX, RXZ, RH};
    for ii = 1:3
        R = routes{ii};
        g = G.(route_key(R.name));
        fprintf(fid, '| %s | %.4f | %.4f | %.4f | %.4f | %.4f | %s |\n', ...
            R.name, R.abs.signed_mean_deg, R.abs.mae_deg, R.abs.rms_deg, ...
            R.abs.p95_deg, R.abs.max_deg, yn(g.abs_max_pass));
    end
    fprintf(fid, '\n');

    fprintf(fid, '## Trim-relative ripple $\\tilde\\phi=\\phi-\\phi_{eq}$\n\n');
    fprintf(fid, 'Hard: MAE≤0.75°, p95≤1.5°, max≤2°, p_RMS≤3°/s. Preferred: MAE≤0.25°, p95≤0.5°, p_RMS≤1°/s.\n\n');
    fprintf(fid, '| Route | signed_mean | MAE | RMS | p95 | max | p MAE | p RMS | p p95 | pref | hard |\n');
    fprintf(fid, '|-------|------------:|----:|----:|----:|----:|------:|------:|------:|:----:|:----:|\n');
    for ii = 1:3
        R = routes{ii};
        g = G.(route_key(R.name));
        fprintf(fid, '| %s | %.4f | %.4f | %.4f | %.4f | %.4f | %.4f | %.4f | %.4f | %s | %s |\n', ...
            R.name, R.tilde.signed_mean_deg, R.tilde.mae_deg, R.tilde.rms_deg, ...
            R.tilde.p95_deg, R.tilde.max_deg, R.pmet.mae_dps, R.pmet.rms_dps, ...
            R.pmet.p95_dps, yn(g.pref_pass), yn(g.hard_pass));
    end
    fprintf(fid, '\n');

    fprintf(fid, '### R10 spectrum / cycle decay\n\n');
    sp = RH.spec;
    fprintf(fid, '- Peak f(φ̃)/f(p) = %.4f / %.4f Hz | plant f = %.4f Hz | match = %d | Δf = %.4f Hz\n', ...
        sp.phi_f_Hz, sp.p_f_Hz, sp.target_f_Hz, sp.match_plant, sp.df_vs_plant_Hz);
    fprintf(fid, '- Amplitude @ plant roll (%.3f Hz): **%.4f°**\n', sp.target_f_Hz, sp.amp_781_deg);
    fprintf(fid, '- Cycle-to-cycle decay = %.5f (growth = %.5f); damp_proxy ζ ≈ %.5f\n', ...
        sp.decay_per_cycle, sp.growth, sp.damp_proxy);
    fprintf(fid, '- Spectral confidence: **%s**\n', sp.confidence);
    if ~isempty(sp.env_peaks_deg)
        fprintf(fid, '- Envelope peaks [°] (first/last 5): %s … %s\n', ...
            mat2str(sp.env_peaks_deg(1:min(5,end))', 3), ...
            mat2str(sp.env_peaks_deg(max(1,end-4):end)', 3));
    end
    fprintf(fid, '- Yaw wrap ss MAE = %.4f° (preserved context)\n\n', RH.yaw_mae_deg);

    fprintf(fid, '## Gates summary\n\n');
    fprintf(fid, '- Absolute max≤5° all routes: **%s**\n', yn(G.abs_all_pass));
    fprintf(fid, '- Trim-relative hard all routes: **%s**\n', yn(G.hard_all_pass));
    fprintf(fid, '- Trim-relative preferred all routes: **%s**\n\n', yn(G.pref_all_pass));

    fprintf(fid, '## Decision\n\n');
    fprintf(fid, '- Class: **%s**\n', class_label);
    fprintf(fid, '- Next (one bounded option, not implemented): `%s`\n', next_opt);
    fprintf(fid, '- Detail: %s\n\n', next_detail);

    fprintf(fid, '## Feedback\n\n');
    fprintf(fid, '- Verdict: **%s**\n', verdict);
    fprintf(fid, '- phi_eq [°]: X=%.4f, XZ=%.4f, H=%.4f (%s)\n', ...
        RX.phi_eq_deg, RXZ.phi_eq_deg, RH.phi_eq_deg, RH.phi_eq_label);
    fprintf(fid, '- Residual small: %s (p_dot_norm=%.4g, norm_rel=%.4g)\n', ...
        yn(rr.is_small), rr.p_dot_norm, rr.norm_rel);
    fprintf(fid, '- H tilde MAE/p95/max [°]: %.4f / %.4f / %.4f | p_RMS=%.4f deg/s\n', ...
        RH.tilde.mae_deg, RH.tilde.p95_deg, RH.tilde.max_deg, RH.pmet.rms_dps);
    fprintf(fid, '- Ripple gates: pref=%s hard=%s | amp@%.3fHz=%.4f° decay/cyc=%.4f\n', ...
        yn(G.pref_all_pass), yn(G.hard_all_pass), sp.target_f_Hz, sp.amp_781_deg, sp.decay_per_cycle);
    fprintf(fid, '- Next: %s\n', next_opt);
    fprintf(fid, '- Files: `%s` `%s` `%s`\n', md_path_s, mat_path, png_path);
    fclose(fid);
end

function k = route_key(name)
    if strcmp(name, 'H_R10'); k = 'H'; else; k = name; end
end

function s = yn(tf)
    if tf; s = 'YES'; else; s = 'NO'; end
end

%% ===================== append STATE_SPACE_MODEL_AUDIT =====================
function append_ss_audit(out_dir, task_id, verdict, plant, RX, RXZ, RH, G, ...
        class_label, next_opt, next_detail, md_path, mat_path, png_path)
    audit_path = fullfile(out_dir, 'STATE_SPACE_MODEL_AUDIT.md');
    fid = fopen(audit_path, 'a');
    fprintf(fid, '\n\n---\n\n');
    fprintf(fid, '## %s — %s\n\n', task_id, datestr(now, 'yyyy-mm-dd HH:MM:SS'));
    fprintf(fid, '### Provenance\n\n');
    fprintf(fid, '- Read-only: `ROLL_BASELINE_AUDIT.mat`, `LOCAL_SS_LEVEL.mat`, `LOCAL_SS_CLIMB.mat`\n');
    fprintf(fid, '- Driver: `run_roll_trim_relative_audit.m` (no re-sim; no controller edit)\n');
    fprintf(fid, '- Artifacts: `%s`, `%s`, `%s`\n\n', md_path, mat_path, png_path);

    fprintf(fid, '### Math / frame / units\n\n');
    fprintf(fid, '```\n');
    fprintf(fid, 'tilde_phi = phi - phi_eq\n');
    fprintf(fid, 'X/XZ: phi_eq = 0 (forced)\n');
    fprintf(fid, 'R10: phi_eq = IDENTIFIED robust median(per_turn_mean) = %.6f rad (%.4f deg)\n', ...
        RH.phi_eq_rad, RH.phi_eq_deg);
    fprintf(fid, 'label: %s\n', RH.phi_eq_label);
    fprintf(fid, 'Plant residual at mean (x*,u*): p_dot_norm=%.5g norm_rel=%.5g tol=0.01 → small=%d\n', ...
        RH.residual.p_dot_norm, RH.residual.norm_rel, RH.residual.is_small);
    fprintf(fid, 'Plant roll level: f=%.4f Hz ζ=%.5f\n', plant.level.f_Hz, plant.level.zeta);
    fprintf(fid, 'Gates hard: MAE≤0.75 p95≤1.5 max≤2 p_RMS≤3; pref: MAE≤0.25 p95≤0.5 p_RMS≤1\n');
    fprintf(fid, 'Absolute safety: max|phi|≤5 deg (separate)\n');
    fprintf(fid, '```\n\n');

    fprintf(fid, '### Trim-relative ripple (steady)\n\n');
    fprintf(fid, '| Route | phi_eq [°] | tilde MAE | p95 | max | p_RMS | pref | hard |\n');
    fprintf(fid, '|-------|----------:|----------:|----:|----:|------:|:----:|:----:|\n');
    for nm = {'X', 'XZ', 'H'}
        g = G.(nm{1});
        if strcmp(nm{1}, 'X'); R = RX;
        elseif strcmp(nm{1}, 'XZ'); R = RXZ;
        else; R = RH;
        end
        fprintf(fid, '| %s | %.4f | %.4f | %.4f | %.4f | %.4f | %s | %s |\n', ...
            nm{1}, R.phi_eq_deg, R.tilde.mae_deg, R.tilde.p95_deg, R.tilde.max_deg, ...
            R.pmet.rms_dps, yn(g.pref_pass), yn(g.hard_pass));
    end
    fprintf(fid, '\n');

    fprintf(fid, '### Verdict / class / next\n\n');
    fprintf(fid, '- Verdict: **%s**\n', verdict);
    fprintf(fid, '- Class: `%s`\n', class_label);
    fprintf(fid, '- Next (not implemented): `%s` — %s\n', next_opt, next_detail);
    fprintf(fid, '- Absolute max gate: %s | Hard: %s | Preferred: %s\n\n', ...
        yn(G.abs_all_pass), yn(G.hard_all_pass), yn(G.pref_all_pass));

    fprintf(fid, '### Next\n\n');
    fprintf(fid, '- Do not implement now; queue single option `%s`.\n', next_opt);
    fclose(fid);
end

%% ===================== feedback =====================
function print_feedback(verdict, RX, RXZ, RH, G, class_label, next_opt, next_detail, ...
        md_path, mat_path, png_path)
    fprintf('\n---------- FEEDBACK ----------\n');
    fprintf('PASS/FAIL: %s\n', verdict);
    fprintf('phi_eq provenance: X=0, XZ=0, H=%.4f deg [%s] conf=%s\n', ...
        RH.phi_eq_deg, RH.phi_eq_label, RH.phi_eq_id.confidence);
    fprintf('residual: small=%s p_dot_norm=%.4g norm_rel=%.4g class=%s\n', ...
        yn(RH.residual.is_small), RH.residual.p_dot_norm, RH.residual.norm_rel, ...
        RH.residual.class);
    fprintf('ripple H: MAE=%.4f p95=%.4f max=%.4f p_RMS=%.4f | amp@%.3fHz=%.4f decay=%.4f\n', ...
        RH.tilde.mae_deg, RH.tilde.p95_deg, RH.tilde.max_deg, RH.pmet.rms_dps, ...
        RH.spec.target_f_Hz, RH.spec.amp_781_deg, RH.spec.decay_per_cycle);
    fprintf('gates: abs=%s hard=%s pref=%s | class=%s\n', ...
        yn(G.abs_all_pass), yn(G.hard_all_pass), yn(G.pref_all_pass), class_label);
    fprintf('next: %s\n', next_opt);
    fprintf('detail: %s\n', next_detail);
    fprintf('files: %s | %s | %s\n', md_path, mat_path, png_path);
    fprintf('------------------------------\n');
end
