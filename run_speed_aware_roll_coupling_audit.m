function run_speed_aware_roll_coupling_audit()
% SPEED_AWARE_ROLL_COUPLING_AUDIT_001 — attribute R10 roll/yaw residual at
% old production speed vs exact-u-hold (A04) candidate; own-equilibrium
% mean/ripple decomposition. Read-only: ALPHA_DEPTH_P_BACKOFF.mat,
% ROLL_PRODUCTION_CLOSURE.mat, underwater777_vehicle_dynamics.m.
% One MATLAB invocation; no gain tuning; production untouched.
% Classify exactly one: METRIC_MISMATCH | SPEED_DAMPING_SHORTFALL | UNKNOWN.
% Artifacts: suite_results/SPEED_AWARE_ROLL_COUPLING_AUDIT.{md,mat,png}

    project_dir = fileparts(mfilename('fullpath'));
    addpath(project_dir);
    out_dir = fullfile(project_dir, 'suite_results');
    if ~exist(out_dir, 'dir'); mkdir(out_dir); end
    tag = 'SPEED_AWARE_ROLL_COUPLING_AUDIT';
    task_id = 'SPEED_AWARE_ROLL_COUPLING_AUDIT_001';

    alpha_path = fullfile(out_dir, 'ALPHA_DEPTH_P_BACKOFF.mat');
    roll_path  = fullfile(out_dir, 'ROLL_PRODUCTION_CLOSURE.mat');
    plant_path = fullfile(project_dir, 'underwater777_vehicle_dynamics.m');
    assert(exist(alpha_path, 'file') == 2, 'Missing %s', alpha_path);
    assert(exist(roll_path, 'file') == 2, 'Missing %s', roll_path);
    assert(exist(plant_path, 'file') == 2, 'Missing %s', plant_path);

    A = load(alpha_path);
    R = load(roll_path);
    assert(isfield(A, 'production') && isfield(A, 'alpha_no_I_Kz04'), ...
        'ALPHA_DEPTH_P_BACKOFF missing production / A04');
    assert(isfield(A.production, 'H') && isfield(A.alpha_no_I_Kz04, 'H'), ...
        'Missing R10 H cases');
    assert(isfield(R, 'phi_eq') && isfield(R, 'candidate') && isfield(R.candidate, 'SH'), ...
        'ROLL_PRODUCTION_CLOSURE missing phi_eq / candidate.SH');

    % Plant coeffs for term signs/units (globals for dynamics RHS); not an
    % evidence timeseries source.
    clear functions
    init_parameters();
    global m W B g_m xg yg zg xb yb zb
    global Kpp Ixx Iyy Izz Yuudr Nuudr
    coeffs = struct('m', m, 'W', W, 'B', B, 'g_m', g_m, ...
        'xg', xg, 'yg', yg, 'zg', zg, 'xb', xb, 'yb', yb, 'zb', zb, ...
        'Kpp', Kpp, 'Ixx', Ixx, 'Iyy', Iyy, 'Izz', Izz, ...
        'Yuudr', Yuudr, 'Nuudr', Nuudr);

    fprintf('\n========== %s ==========\n', task_id);
    fprintf('Sources: ALPHA_DEPTH_P_BACKOFF.mat | ROLL_PRODUCTION_CLOSURE.mat | underwater777_vehicle_dynamics.m\n');
    fprintf('Mode: read-only attribution (no re-sim, no gain, production untouched)\n');
    fprintf('NOTE: R10 helix is time-varying / empirical — NOT an LTI trim.\n');

    frozen_phi_eq = A.phi_eq.H;   % = ROLL closure phi_eq.H = 1.461 deg
    assert(abs(frozen_phi_eq - R.phi_eq.H) < 1e-12, 'phi_eq mismatch P-backoff vs ROLL closure');

    % ---- Cases: old production speed (P) vs exact-u-hold A04 ----
    CaseP = build_case(A.production.H, 'P_prod_speed', frozen_phi_eq, coeffs, false);
    CaseC = build_case(A.alpha_no_I_Kz04.H, 'A04_u_hold', frozen_phi_eq, coeffs, false);

    % Cross-check: ROLL production closure SH (same frozen stack / speed)
    CaseR = build_case_from_roll(R.candidate.SH, R.candidate.H, 'ROLL_prod_closure', ...
        frozen_phi_eq, coeffs);

    fprintf('\n-- Speed (steady BODY u) --\n');
    fprintf('  P : u_mean=%.4f  u_ref=%.4f  Uh=%.4f\n', CaseP.u.mean, CaseP.u.ref_mean, CaseP.u.Uh_mean);
    fprintf('  A04: u_mean=%.4f  u_ref=%.4f  Uh=%.4f\n', CaseC.u.mean, CaseC.u.ref_mean, CaseC.u.Uh_mean);
    fprintf('  ROLL: u_mean=%.4f (closure timeseries)\n', CaseR.u.mean);

    fprintf('\n-- Bank equilibrium (deg) --\n');
    fprintf('  frozen_phi_eq = %.4f (NOT re-fit; production-speed bank)\n', rad2deg(frozen_phi_eq));
    fprintf('  P  mean/med/robust_turn = %.4f / %.4f / %.4f\n', ...
        CaseP.eq.mean_deg, CaseP.eq.median_deg, CaseP.eq.robust_turn_mean_deg);
    fprintf('  A04 mean/med/robust_turn = %.4f / %.4f / %.4f\n', ...
        CaseC.eq.mean_deg, CaseC.eq.median_deg, CaseC.eq.robust_turn_mean_deg);

    fprintf('\n-- Frozen-phi_eq tilde RMS (prior gate metric) --\n');
    fprintf('  P=%.4f  A04=%.4f  (reported 0.4376->0.6642)\n', ...
        CaseP.frozen.rms_deg, CaseC.frozen.rms_deg);
    fprintf('-- Own-eq tilde RMS / MAE / p95 --\n');
    fprintf('  P  RMS=%.4f MAE=%.4f p95=%.4f\n', ...
        CaseP.own.rms_deg, CaseP.own.mae_deg, CaseP.own.p95_deg);
    fprintf('  A04 RMS=%.4f MAE=%.4f p95=%.4f\n', ...
        CaseC.own.rms_deg, CaseC.own.mae_deg, CaseC.own.p95_deg);
    fprintf('-- Detrended ripple RMS / pRMS --\n');
    fprintf('  P  rip=%.4f pRMS=%.4f  | A04 rip=%.4f pRMS=%.4f\n', ...
        CaseP.ripple.rms_deg, CaseP.p.rms_dps, CaseC.ripple.rms_deg, CaseC.p.rms_dps);

    % ---- Compare / classify ----
    Cmp = compare_cases(CaseP, CaseC, CaseR, frozen_phi_eq, coeffs);
    [verdict, class_label, next_opt, next_detail, gates] = decide(Cmp, CaseP, CaseC);

    fprintf('\nCLASS=%s | VERDICT=%s | valid_ss P=%.1f%% A04=%.1f%%\n', ...
        class_label, verdict, 100 * CaseP.valid_frac, 100 * CaseC.valid_frac);

    md_path  = fullfile(out_dir, [tag '.md']);
    mat_path = fullfile(out_dir, [tag '.mat']);
    png_path = fullfile(out_dir, [tag '.png']);

    write_png(png_path, CaseP, CaseC, Cmp, task_id, verdict, class_label);
    write_md(md_path, task_id, verdict, class_label, next_opt, next_detail, ...
        CaseP, CaseC, CaseR, Cmp, gates, coeffs, frozen_phi_eq, ...
        alpha_path, roll_path, plant_path, md_path, mat_path, png_path);
    append_ss_audit(out_dir, task_id, verdict, class_label, next_opt, next_detail, ...
        CaseP, CaseC, Cmp, gates, md_path, mat_path, png_path);

    Out = struct();
    Out.task_id = task_id;
    Out.verdict = verdict;
    Out.class_label = class_label;
    Out.next_opt = next_opt;
    Out.next_detail = next_detail;
    Out.frozen_phi_eq_rad = frozen_phi_eq;
    Out.frozen_phi_eq_deg = rad2deg(frozen_phi_eq);
    Out.CaseP = CaseP;
    Out.CaseC = CaseC;
    Out.CaseR = CaseR;
    Out.Cmp = Cmp;
    Out.gates = gates;
    Out.coeffs = coeffs;
    Out.sources = {alpha_path; roll_path; plant_path};
    Out.paths = struct('md', md_path, 'mat', mat_path, 'png', png_path);
    Out.production_edited = false;
    Out.note = ['R10 helix empirical attribution; own-eq vs frozen-phi_eq; ', ...
        'NOT an LTI trim. No gain/production edit.'];
    save(mat_path, '-struct', 'Out');

    fprintf('\nVERDICT: %s | class=%s | next=%s\n', verdict, class_label, next_opt);
    fprintf('Saved: %s\n%s\n%s\n', md_path, mat_path, png_path);
    print_feedback(verdict, class_label, next_opt, next_detail, CaseP, CaseC, Cmp, gates, ...
        md_path, mat_path, png_path);
    assignin('base', 'SPEED_AWARE_ROLL_COUPLING_AUDIT_PASS', strcmp(verdict, 'PASS'));
end

%% ===================== case builders =====================
function C = build_case(HM, name, frozen_phi_eq, coeffs, ~)
    S = HM.S;
    M = HM.M;
    t = S.t(:);
    dt = S.dt;
    phi = S.ori(:, 1);
    psi = S.ori(:, 3);
    p = S.rates(:, 1);
    q = S.rates(:, 2);
    r = S.rates(:, 3);
    u = S.u_body(:);
    v = S.v_body(:);
    w = S.w_body(:);
    theta = S.ori(:, 2);
    dr = S.delta_r(:);
    de = S.delta_e(:);
    mask = M.mask_ss(:);
    if ~any(mask)
        mask = (t >= 5.0) & (t <= 0.88 * t(end));
    end
    n_tot = numel(t);
    n_ss = nnz(mask);
    valid = mask & isfinite(phi) & isfinite(p) & isfinite(u) & isfinite(dr);
    n_valid = nnz(valid);
    valid_frac = n_valid / max(n_ss, 1);

    eq = identify_own_eq(phi, psi, t, valid);

    tilde_frozen = phi - frozen_phi_eq;
    tilde_own = phi - eq.phi_eq_rad;
    % Detrended ripple = remove persistent mean (same as own-mean when eq=mean)
    phi_ss = phi(valid);
    phi_det = phi - mean(phi_ss);

    C = struct();
    C.name = name;
    C.t = t; C.dt = dt; C.mask = valid; C.mask_raw_ss = mask;
    C.n_tot = n_tot; C.n_ss = n_ss; C.n_valid = n_valid;
    C.valid_frac = valid_frac;
    C.phi = phi; C.p = p; C.psi = psi;
    C.dr = dr; C.de = de;
    C.dr_yaw = S.dr_yaw(:); C.dr_damp = S.dr_damp(:); C.dr_p = S.dr_p(:);
    C.g_ac = S.g_ac(:);
    C.eq = eq;
    C.frozen_phi_eq_rad = frozen_phi_eq;
    C.frozen = err_stats(tilde_frozen, valid);
    C.own = err_stats(tilde_own, valid);
    C.ripple = err_stats(phi_det, valid);   % detrended about steady mean
    C.abs_phi = err_stats(phi, valid);
    C.p_series = p;
    C.p = rate_stats(p, valid);
    C.yaw = yaw_stats(S.psi_ref(:), psi, valid);
    C.u = speed_stats_local(S, valid);
    C.act = actuator_stats_local(dr, de, valid, dt);
    C.dr_comp = struct( ...
        'dr_yaw_rms_deg', rad2deg(rms_local(S.dr_yaw(valid))), ...
        'dr_damp_rms_deg', rad2deg(rms_local(S.dr_damp(valid))), ...
        'dr_p_rms_deg', rad2deg(rms_local(S.dr_p(valid))), ...
        'g_ac_mean', mean(S.g_ac(valid)), ...
        'g_ac_min', min(S.g_ac(valid)));
    C.spec = spectrum_p(p, valid, dt);
    C.terms = roll_moment_terms(phi, theta, u, v, w, p, q, r, valid, coeffs);
    C.authority = rudder_authority(u, dr, valid, coeffs);
    C.prior_M = struct( ...
        'tilde_rms_deg', M.tilde.rms_deg, ...
        'p_rms_dps', M.p.rms_dps, ...
        'yaw_mae_deg', M.yaw.mae_deg, ...
        'phi_eq_used_deg', rad2deg(M.phi_eq_rad));
end

function C = build_case_from_roll(S, M, name, frozen_phi_eq, coeffs)
    % ROLL_PRODUCTION_CLOSURE stores SH without u_body aliases — derive.
    t = S.t(:);
    dt = S.dt;
    phi = S.ori(:, 1);
    psi = S.ori(:, 3);
    p = S.rates(:, 1);
    q = S.rates(:, 2);
    r = S.rates(:, 3);
    u = S.vel(:, 1); v = S.vel(:, 2); w = S.vel(:, 3);
    theta = S.ori(:, 2);
    dr = S.delta_r(:);
    de = S.delta_e(:);
    mask = M.mask_ss(:);
    if ~any(mask)
        mask = (t >= 5.0) & (t <= 0.88 * t(end));
    end
    valid = mask & isfinite(phi) & isfinite(p) & isfinite(u);
    eq = identify_own_eq(phi, psi, t, valid);
    tilde_frozen = phi - frozen_phi_eq;
    tilde_own = phi - eq.phi_eq_rad;
    phi_det = phi - mean(phi(valid));

    % Fake S-like for speed/act helpers
    Sf = struct();
    Sf.u_body = u; Sf.u_ctrl = u; Sf.u_ref = 1.5 * ones(size(u));
    Sf.Uh = hypot(u, 0);  % placeholder; Uh not critical for roll closure cross-check
    if isfield(S, 'Uh'); Sf.Uh = S.Uh(:); end

    C = struct();
    C.name = name;
    C.t = t; C.dt = dt; C.mask = valid;
    C.n_tot = numel(t); C.n_ss = nnz(mask); C.n_valid = nnz(valid);
    C.valid_frac = C.n_valid / max(C.n_ss, 1);
    C.phi = phi; C.p_series = p; C.psi = psi;
    C.dr = dr; C.de = de;
    C.dr_yaw = S.dr_yaw(:); C.dr_damp = S.dr_damp(:); C.dr_p = S.dr_p(:);
    C.g_ac = S.g_ac(:);
    C.eq = eq;
    C.frozen_phi_eq_rad = frozen_phi_eq;
    C.frozen = err_stats(tilde_frozen, valid);
    C.own = err_stats(tilde_own, valid);
    C.ripple = err_stats(phi_det, valid);
    C.abs_phi = err_stats(phi, valid);
    C.p = rate_stats(p, valid);
    C.yaw = yaw_stats(S.psi_ref(:), psi, valid);
    C.u = struct('mean', mean(u(valid)), 'ref_mean', NaN, 'Uh_mean', mean(Sf.Uh(valid)), ...
        'mae_vs_ref', NaN);
    C.act = actuator_stats_local(dr, de, valid, dt);
    C.dr_comp = struct( ...
        'dr_yaw_rms_deg', rad2deg(rms_local(S.dr_yaw(valid))), ...
        'dr_damp_rms_deg', rad2deg(rms_local(S.dr_damp(valid))), ...
        'dr_p_rms_deg', rad2deg(rms_local(S.dr_p(valid))), ...
        'g_ac_mean', mean(S.g_ac(valid)), ...
        'g_ac_min', min(S.g_ac(valid)));
    C.spec = spectrum_p(p, valid, dt);
    C.terms = roll_moment_terms(phi, theta, u, v, w, p, q, r, valid, coeffs);
    C.authority = rudder_authority(u, dr, valid, coeffs);
    C.prior_M = struct('tilde_rms_deg', M.tilde.rms_deg, 'p_rms_dps', M.p.rms_dps, ...
        'yaw_mae_deg', M.yaw.mae_deg, 'phi_eq_used_deg', rad2deg(M.phi_eq_rad));
end

%% ===================== equilibrium / stats =====================
function eq = identify_own_eq(phi, psi, t, mask)
    phi_m = phi(mask);
    psi_m = unwrap(psi(mask));
    t_m = t(mask);
    mean_all = mean(phi_m);
    med_all = median(phi_m);

    turn_idx = floor((psi_m - psi_m(1)) / (2 * pi)) + 1;
    n_turns = max(turn_idx);
    turn_mean = nan(n_turns, 1);
    turn_n = zeros(n_turns, 1);
    for k = 1:n_turns
        ik = turn_idx == k;
        turn_n(k) = nnz(ik);
        if turn_n(k) >= 8
            turn_mean(k) = mean(phi_m(ik));
        end
    end
    valid = isfinite(turn_mean);
    if any(valid)
        robust = median(turn_mean(valid));
        turn_spread = max(turn_mean(valid)) - min(turn_mean(valid));
        turn_stable = turn_spread <= deg2rad(0.35);
    else
        robust = mean_all;
        turn_spread = NaN;
        turn_stable = false;
    end

    n = numel(phi_m);
    mean1 = mean(phi_m(1:floor(n / 2)));
    mean2 = mean(phi_m(floor(n / 2) + 1:end));
    half_stable = abs(mean2 - mean1) <= deg2rad(0.25);

    % Prefer steady mean as "own equilibrium" for trim-relative metrics;
    % also report median + robust turn mean.
    phi_eq = mean_all;
    estimator = 'steady_mean';
    if ~half_stable && turn_stable
        phi_eq = robust;
        estimator = 'median(per_turn_mean)_half_unstable';
    elseif ~half_stable && ~turn_stable
        phi_eq = med_all;
        estimator = 'overall_median_unstable';
    end

    eq = struct();
    eq.phi_eq_rad = phi_eq;
    eq.phi_eq_deg = rad2deg(phi_eq);
    eq.estimator = estimator;
    eq.mean_deg = rad2deg(mean_all);
    eq.median_deg = rad2deg(med_all);
    eq.robust_turn_mean_deg = rad2deg(robust);
    eq.turn_spread_deg = rad2deg(turn_spread);
    eq.turn_stable = turn_stable;
    eq.half_stable = half_stable;
    eq.n_turns = n_turns;
    eq.t_span = [t_m(1), t_m(end)];
    eq.label = 'empirical_steady_bank_NOT_LTI_trim';
end

function st = err_stats(e, mask)
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

function st = yaw_stats(psi_ref, psi, mask)
    e = wrapToPi(psi_ref(:) - psi(:));
    v = e(mask);
    st = struct();
    st.mae_deg = rad2deg(mean(abs(v)));
    st.rms_deg = rad2deg(rms_local(v));
    st.p95_deg = rad2deg(prctile_local(abs(v), 95));
end

function st = speed_stats_local(S, mask)
    st = struct();
    st.mean = mean(S.u_body(mask));
    st.ref_mean = mean(S.u_ref(mask));
    st.Uh_mean = mean(S.Uh(mask));
    st.mae_vs_ref = mean(abs(S.u_ref(mask) - S.u_ctrl(mask)));
end

function st = actuator_stats_local(dr, de, mask, dt)
    dr_dot = [0; diff(dr)] / dt;
    de_dot = [0; diff(de)] / dt;
    st = struct();
    st.dr_rms_deg = rad2deg(rms_local(dr(mask)));
    st.de_rms_deg = rad2deg(rms_local(de(mask)));
    st.dr_rate_rms = rms_local(dr_dot(mask));          % rad/s
    st.de_rate_rms = rms_local(de_dot(mask));
    st.dr_rate_rms_dps = rad2deg(st.dr_rate_rms);
    st.de_rate_rms_dps = rad2deg(st.de_rate_rms);
end

function sp = spectrum_p(p, mask, dt)
    v = p(mask); v = v(:) - mean(v);
    sp = struct('f_peak_Hz', NaN, 'amp_proxy', NaN, 'n', numel(v));
    if numel(v) < 64; return; end
    [f, P] = onesided_psd(v, dt);
    ikeep = f > 0.05;
    if ~any(ikeep); return; end
    ff = f(ikeep); Pp = P(ikeep);
    [~, i1] = max(Pp);
    sp.f_peak_Hz = ff(i1);
    sp.amp_proxy = sqrt(Pp(i1));
    sp.f = ff; sp.P = Pp;
end

%% ===================== physics terms =====================
function T = roll_moment_terms(phi, theta, u, v, w, p, q, r, mask, c)
    % Exact K-moment components from underwater777_vehicle_dynamics (Nm).
    % Evaluated on saved states; helix is NOT an LTI trim.
    phi = phi(mask); theta = theta(mask);
    u = u(mask); v = v(mask); w = w(mask); %#ok<NASGU>
    p = p(mask); q = q(mask); r = r(mask);

    K_grav = (c.yg * c.W - c.yb * c.B) * cos(theta) .* cos(phi) ...
           - (c.zg * c.W - c.zb * c.B) * cos(theta) .* sin(phi);
    K_pp   = c.Kpp * p .* abs(p);                 % quadratic roll damping
    K_qr   = -(c.Izz - c.Iyy) * q .* r;           % inertial product
    K_wp   = -(c.m * c.zg) * w .* p;              % coupling
    K_ur   = +(c.m * c.zg) * u .* r;              % speed*yaw-rate coupling
    K_sum  = K_grav + K_pp + K_qr + K_wp + K_ur;

    T = struct();
    T.units = 'N*m';
    T.note = 'empirical on saved R10 states; not LTI trim residual';
    T.Kpp_coeff = c.Kpp;
    T.m_zg = c.m * c.zg;
    T.Izz_minus_Iyy = c.Izz - c.Iyy;
    T.mean = struct( ...
        'K_grav', mean(K_grav), 'K_pp', mean(K_pp), 'K_qr', mean(K_qr), ...
        'K_wp', mean(K_wp), 'K_ur', mean(K_ur), 'K_sum', mean(K_sum));
    T.rms = struct( ...
        'K_grav', rms_local(K_grav), 'K_pp', rms_local(K_pp), 'K_qr', rms_local(K_qr), ...
        'K_wp', rms_local(K_wp), 'K_ur', rms_local(K_ur), 'K_sum', rms_local(K_sum));
    T.signs = struct( ...
        'Kpp_neg_damping', c.Kpp < 0, ...
        'K_ur_speed_yaw', true, ...
        'K_grav_restoring_neg_phi', true);
    % Series for PNG optional — keep means/rms only to bound MAT size
end

function A = rudder_authority(u, dr, mask, c)
    u = u(mask); dr = dr(mask);
    u2 = u.^2;
    Y_r = c.Yuudr * u2 .* dr;   % N
    N_r = c.Nuudr * u2 .* dr;   % N*m
    A = struct();
    A.units_Y = 'N'; A.units_N = 'N*m'; A.units_G = 'N*m/rad or N/rad';
    A.Yuudr = c.Yuudr; A.Nuudr = c.Nuudr;
    A.u_mean = mean(u);
    A.u2_mean = mean(u2);
    A.G_Y_mean = c.Yuudr * mean(u2);     % N/rad
    A.G_N_mean = c.Nuudr * mean(u2);     % N*m/rad
    A.Y_rms = rms_local(Y_r);
    A.N_rms = rms_local(N_r);
    A.dr_rms_deg = rad2deg(rms_local(dr));
    A.note = 'authority scales as u^2 via Yuudr/Nuudr; no direct K(dr) in plant';
end

%% ===================== compare / decide =====================
function Cmp = compare_cases(P, C, R, frozen_phi_eq, coeffs)
    Cmp = struct();
    Cmp.frozen_phi_eq_deg = rad2deg(frozen_phi_eq);
    Cmp.du_mean = C.u.mean - P.u.mean;
    Cmp.u_ratio = C.u.mean / max(P.u.mean, eps);
    Cmp.u2_ratio = (C.u.mean / max(P.u.mean, eps))^2;
    Cmp.d_phi_eq_mean_deg = C.eq.mean_deg - P.eq.mean_deg;
    Cmp.d_phi_eq_med_deg = C.eq.median_deg - P.eq.median_deg;

    Cmp.frozen_tilde_rms = [P.frozen.rms_deg, C.frozen.rms_deg];
    Cmp.own_tilde_rms = [P.own.rms_deg, C.own.rms_deg];
    Cmp.own_tilde_mae = [P.own.mae_deg, C.own.mae_deg];
    Cmp.own_tilde_p95 = [P.own.p95_deg, C.own.p95_deg];
    Cmp.ripple_rms = [P.ripple.rms_deg, C.ripple.rms_deg];
    Cmp.p_rms = [P.p.rms_dps, C.p.rms_dps];
    Cmp.yaw_mae = [P.yaw.mae_deg, C.yaw.mae_deg];

    Cmp.d_frozen_rms_pct = pct_change(P.frozen.rms_deg, C.frozen.rms_deg);
    Cmp.d_own_rms_pct = pct_change(P.own.rms_deg, C.own.rms_deg);
    Cmp.d_ripple_pct = pct_change(P.ripple.rms_deg, C.ripple.rms_deg);
    Cmp.d_p_rms_pct = pct_change(P.p.rms_dps, C.p.rms_dps);
    Cmp.d_yaw_pct = pct_change(P.yaw.mae_deg, C.yaw.mae_deg);

    Cmp.authority_G_N = [P.authority.G_N_mean, C.authority.G_N_mean];
    Cmp.authority_ratio = C.authority.G_N_mean / max(P.authority.G_N_mean, eps);
    Cmp.K_ur_mean = [P.terms.mean.K_ur, C.terms.mean.K_ur];
    Cmp.K_pp_rms = [P.terms.rms.K_pp, C.terms.rms.K_pp];
    Cmp.K_grav_mean = [P.terms.mean.K_grav, C.terms.mean.K_grav];

    Cmp.dr_yaw_rms = [P.dr_comp.dr_yaw_rms_deg, C.dr_comp.dr_yaw_rms_deg];
    Cmp.dr_damp_rms = [P.dr_comp.dr_damp_rms_deg, C.dr_comp.dr_damp_rms_deg];
    Cmp.g_ac_mean = [P.dr_comp.g_ac_mean, C.dr_comp.g_ac_mean];
    Cmp.dr_rate_rms_dps = [P.act.dr_rate_rms_dps, C.act.dr_rate_rms_dps];
    Cmp.de_rate_rms = [P.act.de_rate_rms, C.act.de_rate_rms];

    % Consistency: frozen metric inflation explained by mean-bank shift?
    % |phi_eq_C - frozen| contributes bias to frozen tilde RMS.
    bias_C = abs(C.eq.mean_deg - rad2deg(frozen_phi_eq));
    Cmp.frozen_bias_A04_deg = bias_C;
    Cmp.mean_shift_explains_frozen = (C.frozen.rms_deg > P.frozen.rms_deg) && ...
        (C.own.rms_deg <= P.own.rms_deg * 1.02 + 1e-6) && ...
        (bias_C >= 0.15);

    Cmp.roll_closure_match_P = abs(R.frozen.rms_deg - P.frozen.rms_deg) < 0.02;
    Cmp.coeffs_Kpp = coeffs.Kpp;
    Cmp.coeffs_Nuudr = coeffs.Nuudr;
end

function [verdict, class_label, next_opt, next_detail, G] = decide(Cmp, P, C)
    % Gates for METRIC_MISMATCH support
    G = struct();
    G.valid_ss_ok = (P.valid_frac >= 0.95) && (C.valid_frac >= 0.95);
    G.own_ripple_ok = (C.own.rms_deg <= P.own.rms_deg * 1.02 + 1e-9) && ...
        (C.ripple.rms_deg <= P.ripple.rms_deg * 1.02 + 1e-9);
    G.p_rms_ok = (C.p.rms_dps <= P.p.rms_dps * 1.02 + 1e-9);
    G.yaw_ok = (C.yaw.mae_deg <= P.yaw.mae_deg * 1.02 + 1e-9);
    % Roll-channel actuators (rudder); elevator de_rate is pitch/alpha side-effect
    G.rudder_act_ok = (C.act.dr_rate_rms_dps <= P.act.dr_rate_rms_dps * 1.02 + 1e-6) && ...
        (C.dr_comp.dr_damp_rms_deg <= P.dr_comp.dr_damp_rms_deg * 1.05 + 1e-6);
    G.mean_shift_ok = abs(Cmp.d_phi_eq_mean_deg) >= 0.15;
    G.frozen_worsens = Cmp.d_frozen_rms_pct > 2;   % +% = worse
    G.own_improves_or_holds = Cmp.d_own_rms_pct <= 2;
    G.decomp_consistent = Cmp.mean_shift_explains_frozen && G.mean_shift_ok;
    G.terms_units_ok = (P.terms.signs.Kpp_neg_damping) && isfinite(P.authority.G_N_mean) && ...
        (Cmp.authority_ratio > 0) && (Cmp.u2_ratio > 0);
    G.u_changed = abs(Cmp.du_mean) >= 0.05;

    G.metric_mismatch = G.valid_ss_ok && G.decomp_consistent && G.own_ripple_ok && ...
        G.p_rms_ok && G.rudder_act_ok && G.frozen_worsens && G.own_improves_or_holds && ...
        G.terms_units_ok && G.u_changed;

    % True damping shortfall: own-eq ripple OR pRMS OR rudder coupling worsens
    own_worse = (C.own.rms_deg > P.own.rms_deg * 1.02 + 1e-9) || ...
        (C.ripple.rms_deg > P.ripple.rms_deg * 1.02 + 1e-9);
    p_worse = C.p.rms_dps > P.p.rms_dps * 1.02 + 1e-9;
    coup_worse = (C.dr_comp.dr_damp_rms_deg > P.dr_comp.dr_damp_rms_deg * 1.05 + 1e-6) && ...
        (abs(C.terms.rms.K_ur) > abs(P.terms.rms.K_ur) * 1.05);
    G.speed_damping_shortfall = G.valid_ss_ok && G.terms_units_ok && G.u_changed && ...
        (own_worse || (p_worse && own_worse) || (own_worse && coup_worse));

    if G.metric_mismatch && ~G.speed_damping_shortfall
        class_label = 'METRIC_MISMATCH';
        verdict = 'PASS';
        next_opt = 'speed_scheduled_phi_eq_or_roll_metric';
        next_detail = sprintf([ ...
            'PASS METRIC_MISMATCH: frozen phi_eq=%.3f deg (prod-speed bank) makes A04 tildeRMS ', ...
            '%.3f->%.3f look worse, but own-eq/detrend ripple %.3f->%.3f and pRMS %.3f->%.3f improve. ', ...
            'Bank mean %.3f->%.3f deg tracks u %.3f->%.3f (u^2 auth ratio=%.3f). ', ...
            'Next: schedule phi_eq or report own-eq tilde; do not retune roll for false regression.'], ...
            Cmp.frozen_phi_eq_deg, P.frozen.rms_deg, C.frozen.rms_deg, ...
            P.own.rms_deg, C.own.rms_deg, P.p.rms_dps, C.p.rms_dps, ...
            P.eq.mean_deg, C.eq.mean_deg, P.u.mean, C.u.mean, Cmp.u2_ratio);
    elseif G.speed_damping_shortfall && ~G.metric_mismatch
        class_label = 'SPEED_DAMPING_SHORTFALL';
        verdict = 'PASS';
        next_opt = 'speed_scheduled_roll_damping';
        next_detail = ['PASS SPEED_DAMPING_SHORTFALL: own-eq ripple/coupling truly worsens at ', ...
            'lower held speed; consider speed-scheduled Kp_roll (not implemented here).'];
    else
        class_label = 'UNKNOWN';
        verdict = 'FAIL';
        next_opt = 'manual_roll_speed_decomp_review';
        next_detail = sprintf([ ...
            'FAIL/UNKNOWN: gates valid=%d decomp=%d own_rip=%d p=%d rudder=%d frozen_worse=%d ', ...
            'own_hold=%d terms=%d u_chg=%d shortfall=%d'], ...
            G.valid_ss_ok, G.decomp_consistent, G.own_ripple_ok, G.p_rms_ok, ...
            G.rudder_act_ok, G.frozen_worsens, G.own_improves_or_holds, ...
            G.terms_units_ok, G.u_changed, G.speed_damping_shortfall);
    end
    G.class = class_label;
    G.pass = strcmp(verdict, 'PASS');
end

%% ===================== I/O =====================
function write_png(png_path, P, C, Cmp, task_id, verdict, class_label)
    fig = figure('Visible', 'off', 'Position', [80 80 1200 900]);
    tl = tiledlayout(fig, 2, 2, 'Padding', 'compact', 'TileSpacing', 'compact');

    % 1) phi raw + own-eq + frozen
    nexttile;
    plot(P.t, rad2deg(P.phi), 'b-', C.t, rad2deg(C.phi), 'r-', 'LineWidth', 0.8); hold on;
    yline(P.eq.mean_deg, 'b--', 'LineWidth', 1.0);
    yline(C.eq.mean_deg, 'r--', 'LineWidth', 1.0);
    yline(Cmp.frozen_phi_eq_deg, 'k:', 'LineWidth', 1.2);
    grid on;
    ylabel('\phi [deg]');
    title(sprintf('\\phi raw + eq (P mean=%.2f, A04 mean=%.2f, frozen=%.2f)', ...
        P.eq.mean_deg, C.eq.mean_deg, Cmp.frozen_phi_eq_deg));
    legend('P', 'A04', 'P eq', 'A04 eq', 'frozen \phi_{eq}', 'Location', 'best');

    % 2) detrended phi
    nexttile;
    plot(P.t, rad2deg(P.phi - mean(P.phi(P.mask))), 'b-', ...
         C.t, rad2deg(C.phi - mean(C.phi(C.mask))), 'r-', 'LineWidth', 0.8);
    grid on;
    ylabel('detrend \phi [deg]');
    title(sprintf('Detrended ripple RMS P=%.3f \\rightarrow A04=%.3f deg', ...
        P.ripple.rms_deg, C.ripple.rms_deg));
    legend('P', 'A04', 'Location', 'best');

    % 3) p spectrum
    nexttile;
    if isfield(P.spec, 'f') && ~isempty(P.spec.f)
        semilogy(P.spec.f, P.spec.P, 'b-', C.spec.f, C.spec.P, 'r-', 'LineWidth', 0.9);
        grid on;
        xlabel('f [Hz]'); ylabel('PSD(p)');
        title(sprintf('p spectrum peaks P=%.2f Hz A04=%.2f Hz | pRMS %.2f\\rightarrow%.2f deg/s', ...
            P.spec.f_peak_Hz, C.spec.f_peak_Hz, P.p.rms_dps, C.p.rms_dps));
        legend('P', 'A04', 'Location', 'best');
    else
        text(0.1, 0.5, 'spectrum unavailable'); axis off;
    end

    % 4) dr components + u^2 authority
    nexttile;
    cats = categorical({'dr_{yaw}RMS', 'dr_{damp}RMS', 'g_{ac}', 'u^2', 'G_N/10'});
    cats = reordercats(cats, {'dr_{yaw}RMS', 'dr_{damp}RMS', 'g_{ac}', 'u^2', 'G_N/10'});
    vals = [Cmp.dr_yaw_rms(1), Cmp.dr_damp_rms(1), Cmp.g_ac_mean(1), ...
            P.authority.u2_mean, Cmp.authority_G_N(1)/10; ...
            Cmp.dr_yaw_rms(2), Cmp.dr_damp_rms(2), Cmp.g_ac_mean(2), ...
            C.authority.u2_mean, Cmp.authority_G_N(2)/10];
    b = bar(cats, vals');
    b(1).FaceColor = [0.2 0.4 0.8];
    b(2).FaceColor = [0.85 0.3 0.25];
    grid on;
    ylabel('mixed units (G_N/10)');
    title(sprintf('dr comps + u^2 auth (ratio=%.3f) | %s / %s', ...
        Cmp.u2_ratio, verdict, class_label));
    legend('P', 'A04', 'Location', 'best');

    title(tl, sprintf('%s — %s / %s', task_id, verdict, class_label), ...
        'Interpreter', 'none');
    exportgraphics(fig, png_path, 'Resolution', 140);
    close(fig);
end

function write_md(md_path, task_id, verdict, class_label, next_opt, next_detail, ...
        P, C, R, Cmp, G, coeffs, frozen_phi_eq, alpha_path, roll_path, plant_path, ...
        md_out, mat_out, png_out)

    fid = fopen(md_path, 'w');
    assert(fid > 0, 'Cannot write %s', md_path);
    fprintf(fid, '# %s — Speed-aware R10 roll/yaw residual attribution\n\n', task_id);
    fprintf(fid, '**Overall verdict: %s** | class: **%s**\n\n', verdict, class_label);

    fprintf(fid, '## Provenance\n\n');
    fprintf(fid, '- Read-only: `%s`, `%s`, `%s`\n', alpha_path, roll_path, plant_path);
    fprintf(fid, '- Driver: `run_speed_aware_roll_coupling_audit.m` (one invocation)\n');
    fprintf(fid, '- Artifacts: `%s`, `%s`, `%s`\n', md_out, mat_out, png_out);
    fprintf(fid, '- Production: untouched | No gain tuning\n');
    fprintf(fid, '- Helix caveat: **empirical / time-varying — NOT an LTI trim**\n\n');

    fprintf(fid, '## Equations / units / frame\n\n');
    fprintf(fid, '```\n');
    fprintf(fid, 'tilde_frozen = phi - phi_eq_frozen   [phi_eq_frozen=%.4f deg from ROLL/ALPHA freeze]\n', ...
        rad2deg(frozen_phi_eq));
    fprintf(fid, 'tilde_own    = phi - phi_eq_own      [own = steady mean (report med/robust too)]\n');
    fprintf(fid, 'ripple       = phi - mean(phi_ss)    [detrended]\n');
    fprintf(fid, 'K roll moment [N*m] =\n');
    fprintf(fid, '  (yg*W-yb*B)*cos(th)*cos(phi) - (zg*W-zb*B)*cos(th)*sin(phi)\n');
    fprintf(fid, '  + Kpp*p*|p| - (Izz-Iyy)*q*r - (m*zg)*w*p + (m*zg)*u*r\n');
    fprintf(fid, '  Kpp=%.4g (neg => damping) | m*zg=%.4g\n', coeffs.Kpp, coeffs.m * coeffs.zg);
    fprintf(fid, 'Rudder authority: Y = Yuudr*u^2*dr [N]; N = Nuudr*u^2*dr [N*m]\n');
    fprintf(fid, '  Yuudr=%.4g  Nuudr=%.4g  (scales as u^2; no direct K(dr))\n', coeffs.Yuudr, coeffs.Nuudr);
    fprintf(fid, 'dr_cmd = sat(dr_yaw + g_ac*(-Kp_roll*p)); BODY p; g_ac in [0,1]\n');
    fprintf(fid, '```\n\n');

    fprintf(fid, '## Speed / bank equilibrium (R10 steady)\n\n');
    fprintf(fid, '| Case | u_mean | u_ref | Uh | phi mean | med | robust turn | estimator | valid_ss |\n');
    fprintf(fid, '|------|-------:|------:|---:|---------:|----:|------------:|-----------|---------:|\n');
    fprintf(fid, '| P prod-speed | %.4f | %.4f | %.4f | %.4f | %.4f | %.4f | %s | %.1f%% |\n', ...
        P.u.mean, P.u.ref_mean, P.u.Uh_mean, P.eq.mean_deg, P.eq.median_deg, ...
        P.eq.robust_turn_mean_deg, P.eq.estimator, 100 * P.valid_frac);
    fprintf(fid, '| A04 u-hold | %.4f | %.4f | %.4f | %.4f | %.4f | %.4f | %s | %.1f%% |\n', ...
        C.u.mean, C.u.ref_mean, C.u.Uh_mean, C.eq.mean_deg, C.eq.median_deg, ...
        C.eq.robust_turn_mean_deg, C.eq.estimator, 100 * C.valid_frac);
    fprintf(fid, '| ROLL closure | %.4f | — | %.4f | %.4f | %.4f | %.4f | %s | %.1f%% |\n\n', ...
        R.u.mean, R.u.Uh_mean, R.eq.mean_deg, R.eq.median_deg, ...
        R.eq.robust_turn_mean_deg, R.eq.estimator, 100 * R.valid_frac);

    fprintf(fid, 'u_A04/u_P = %.4f | (u_A04/u_P)^2 = %.4f | Δphi_eq_mean = %+.4f deg\n\n', ...
        Cmp.u_ratio, Cmp.u2_ratio, Cmp.d_phi_eq_mean_deg);

    fprintf(fid, '## Mean / ripple decomposition (own equilibrium)\n\n');
    fprintf(fid, '| Metric | P | A04 | Δ%% |\n');
    fprintf(fid, '|--------|--:|----:|---:|\n');
    fprintf(fid, '| frozen tilde RMS [deg] | %.4f | %.4f | %+.2f |\n', ...
        P.frozen.rms_deg, C.frozen.rms_deg, Cmp.d_frozen_rms_pct);
    fprintf(fid, '| own-eq tilde MAE [deg] | %.4f | %.4f | %+.2f |\n', ...
        P.own.mae_deg, C.own.mae_deg, pct_change(P.own.mae_deg, C.own.mae_deg));
    fprintf(fid, '| own-eq tilde RMS [deg] | %.4f | %.4f | %+.2f |\n', ...
        P.own.rms_deg, C.own.rms_deg, Cmp.d_own_rms_pct);
    fprintf(fid, '| own-eq tilde p95 [deg] | %.4f | %.4f | %+.2f |\n', ...
        P.own.p95_deg, C.own.p95_deg, pct_change(P.own.p95_deg, C.own.p95_deg));
    fprintf(fid, '| detrended ripple RMS [deg] | %.4f | %.4f | %+.2f |\n', ...
        P.ripple.rms_deg, C.ripple.rms_deg, Cmp.d_ripple_pct);
    fprintf(fid, '| pRMS [deg/s] | %.4f | %.4f | %+.2f |\n', ...
        P.p.rms_dps, C.p.rms_dps, Cmp.d_p_rms_pct);
    fprintf(fid, '| yaw MAE [deg] | %.4f | %.4f | %+.2f |\n', ...
        P.yaw.mae_deg, C.yaw.mae_deg, Cmp.d_yaw_pct);
    fprintf(fid, '| p spectrum peak [Hz] | %.3f | %.3f | — |\n\n', ...
        P.spec.f_peak_Hz, C.spec.f_peak_Hz);

    fprintf(fid, 'Frozen-metric bias on A04: |phi_mean_A04 - frozen| = %.4f deg\n\n', ...
        Cmp.frozen_bias_A04_deg);

    fprintf(fid, '## Rudder / g_ac / authority (u^2)\n\n');
    fprintf(fid, '| Qty | P | A04 |\n');
    fprintf(fid, '|-----|--:|----:|\n');
    fprintf(fid, '| dr_yaw RMS [deg] | %.4f | %.4f |\n', Cmp.dr_yaw_rms(1), Cmp.dr_yaw_rms(2));
    fprintf(fid, '| dr_damp RMS [deg] | %.4f | %.4f |\n', Cmp.dr_damp_rms(1), Cmp.dr_damp_rms(2));
    fprintf(fid, '| g_ac mean | %.4f | %.4f |\n', Cmp.g_ac_mean(1), Cmp.g_ac_mean(2));
    fprintf(fid, '| dr rate RMS [deg/s] | %.4f | %.4f |\n', Cmp.dr_rate_rms_dps(1), Cmp.dr_rate_rms_dps(2));
    fprintf(fid, '| de rate RMS [rad/s] (pitch ch.) | %.4g | %.4g |\n', Cmp.de_rate_rms(1), Cmp.de_rate_rms(2));
    fprintf(fid, '| u^2 mean | %.4f | %.4f |\n', P.authority.u2_mean, C.authority.u2_mean);
    fprintf(fid, '| G_N = Nuudr*u^2 [N·m/rad] | %.4f | %.4f |\n', Cmp.authority_G_N(1), Cmp.authority_G_N(2));
    fprintf(fid, '| authority ratio | — | %.4f |\n\n', Cmp.authority_ratio);

    fprintf(fid, '## Roll-moment terms (steady mean / RMS) [N·m]\n\n');
    fprintf(fid, '| Term | P mean | A04 mean | P RMS | A04 RMS |\n');
    fprintf(fid, '|------|-------:|---------:|------:|--------:|\n');
    fprintf(fid, '| K_grav | %.4e | %.4e | %.4e | %.4e |\n', ...
        P.terms.mean.K_grav, C.terms.mean.K_grav, P.terms.rms.K_grav, C.terms.rms.K_grav);
    fprintf(fid, '| Kpp*p|p| | %.4e | %.4e | %.4e | %.4e |\n', ...
        P.terms.mean.K_pp, C.terms.mean.K_pp, P.terms.rms.K_pp, C.terms.rms.K_pp);
    fprintf(fid, '| -(Izz-Iyy)qr | %.4e | %.4e | %.4e | %.4e |\n', ...
        P.terms.mean.K_qr, C.terms.mean.K_qr, P.terms.rms.K_qr, C.terms.rms.K_qr);
    fprintf(fid, '| -(m zg)wp | %.4e | %.4e | %.4e | %.4e |\n', ...
        P.terms.mean.K_wp, C.terms.mean.K_wp, P.terms.rms.K_wp, C.terms.rms.K_wp);
    fprintf(fid, '| +(m zg)ur | %.4e | %.4e | %.4e | %.4e |\n', ...
        P.terms.mean.K_ur, C.terms.mean.K_ur, P.terms.rms.K_ur, C.terms.rms.K_ur);
    fprintf(fid, '| K_sum | %.4e | %.4e | %.4e | %.4e |\n\n', ...
        P.terms.mean.K_sum, C.terms.mean.K_sum, P.terms.rms.K_sum, C.terms.rms.K_sum);

    fprintf(fid, '## Gate table (classification support)\n\n');
    fprintf(fid, '| Gate | Result | Detail |\n');
    fprintf(fid, '|------|:------:|--------|\n');
    fprintf(fid, '| valid steady samples >=95%% | %s | P=%.1f%% A04=%.1f%% |\n', ...
        yn(G.valid_ss_ok), 100 * P.valid_frac, 100 * C.valid_frac);
    fprintf(fid, '| mean/ripple decomp consistent | %s | frozen bias=%.3f deg |\n', ...
        yn(G.decomp_consistent), Cmp.frozen_bias_A04_deg);
    fprintf(fid, '| own-eq ripple holds/improves | %s | d_own=%+.2f%% d_rip=%+.2f%% |\n', ...
        yn(G.own_ripple_ok), Cmp.d_own_rms_pct, Cmp.d_ripple_pct);
    fprintf(fid, '| pRMS holds/improves | %s | d_p=%+.2f%% |\n', yn(G.p_rms_ok), Cmp.d_p_rms_pct);
    fprintf(fid, '| rudder actuator holds | %s | dr_rate/damp |\n', yn(G.rudder_act_ok));
    fprintf(fid, '| frozen metric worsens | %s | d_frozen=%+.2f%% |\n', ...
        yn(G.frozen_worsens), Cmp.d_frozen_rms_pct);
    fprintf(fid, '| term signs/units OK | %s | Kpp<0, u^2 auth |\n', yn(G.terms_units_ok));
    fprintf(fid, '| METRIC_MISMATCH | %s | |\n', yn(G.metric_mismatch));
    fprintf(fid, '| SPEED_DAMPING_SHORTFALL | %s | |\n\n', yn(G.speed_damping_shortfall));

    fprintf(fid, '## Decision\n\n');
    fprintf(fid, '- Verdict: **%s**\n', verdict);
    fprintf(fid, '- Class: **%s**\n', class_label);
    fprintf(fid, '- Next: `%s`\n', next_opt);
    fprintf(fid, '- Detail: %s\n', next_detail);
    fprintf(fid, '- Production: untouched\n\n');

    fprintf(fid, '## Feedback\n\n');
    fprintf(fid, '- PASS/FAIL: **%s**\n', verdict);
    fprintf(fid, '- Class: **%s**\n', class_label);
    fprintf(fid, '- Evidence: frozen tilde %.4f->%.4f vs own-eq %.4f->%.4f; pRMS %.4f->%.4f; ', ...
        P.frozen.rms_deg, C.frozen.rms_deg, P.own.rms_deg, C.own.rms_deg, ...
        P.p.rms_dps, C.p.rms_dps);
    fprintf(fid, 'phi_eq %.3f->%.3f deg; u %.3f->%.3f; u^2 auth ratio=%.3f\n', ...
        P.eq.mean_deg, C.eq.mean_deg, P.u.mean, C.u.mean, Cmp.u2_ratio);
    fprintf(fid, '- Next: `%s`\n', next_opt);
    fprintf(fid, '- Files: `%s` `%s` `%s`\n', md_out, mat_out, png_out);
    fclose(fid);
end

function append_ss_audit(out_dir, task_id, verdict, class_label, next_opt, next_detail, ...
        P, C, Cmp, G, md_path, mat_path, png_path)
    ss_path = fullfile(out_dir, 'STATE_SPACE_MODEL_AUDIT.md');
    fid = fopen(ss_path, 'a');
    assert(fid > 0, 'Cannot append %s', ss_path);
    fprintf(fid, '\n---\n\n');
    fprintf(fid, '## %s — %s\n\n', task_id, datestr(now, 31));
    fprintf(fid, '### Provenance\n\n');
    fprintf(fid, '- Read-only: `ALPHA_DEPTH_P_BACKOFF.mat`, `ROLL_PRODUCTION_CLOSURE.mat`, `underwater777_vehicle_dynamics.m`\n');
    fprintf(fid, '- Driver: `run_speed_aware_roll_coupling_audit.m` (one invocation; production untouched)\n');
    fprintf(fid, '- Artifacts: `%s`, `%s`, `%s`\n\n', md_path, mat_path, png_path);
    fprintf(fid, '### Decomposition\n\n');
    fprintf(fid, '```\n');
    fprintf(fid, 'frozen phi_eq=%.4f deg | P bank mean=%.4f | A04 bank mean=%.4f\n', ...
        Cmp.frozen_phi_eq_deg, P.eq.mean_deg, C.eq.mean_deg);
    fprintf(fid, 'u: %.4f -> %.4f | u^2 auth ratio=%.4f\n', P.u.mean, C.u.mean, Cmp.u2_ratio);
    fprintf(fid, 'frozen tildeRMS: %.4f -> %.4f (%+.2f%%)\n', ...
        P.frozen.rms_deg, C.frozen.rms_deg, Cmp.d_frozen_rms_pct);
    fprintf(fid, 'own-eq tildeRMS: %.4f -> %.4f (%+.2f%%)\n', ...
        P.own.rms_deg, C.own.rms_deg, Cmp.d_own_rms_pct);
    fprintf(fid, 'pRMS: %.4f -> %.4f (%+.2f%%)\n', P.p.rms_dps, C.p.rms_dps, Cmp.d_p_rms_pct);
    fprintf(fid, 'NOT an LTI trim (helix empirical)\n');
    fprintf(fid, '```\n\n');
    fprintf(fid, '### Verdict / next\n\n');
    fprintf(fid, '- Verdict: **%s**\n', verdict);
    fprintf(fid, '- Class: **%s**\n', class_label);
    fprintf(fid, '- Gates valid/decomp/own/p/rudder: %s/%s/%s/%s/%s\n', ...
        yn(G.valid_ss_ok), yn(G.decomp_consistent), yn(G.own_ripple_ok), ...
        yn(G.p_rms_ok), yn(G.rudder_act_ok));
    fprintf(fid, '- Next: `%s` — %s\n', next_opt, next_detail);
    fprintf(fid, '- Production: untouched\n\n');
    fprintf(fid, '### Next\n\n');
    fprintf(fid, '- %s\n', next_opt);
    fclose(fid);
end

function print_feedback(verdict, class_label, next_opt, next_detail, P, C, Cmp, G, ...
        md_path, mat_path, png_path)
    fprintf('\n======== FEEDBACK ========\n');
    fprintf('PASS/FAIL: %s\n', verdict);
    fprintf('Class: %s\n', class_label);
    fprintf('Evidence: frozen tilde %.4f->%.4f | own-eq %.4f->%.4f | pRMS %.4f->%.4f\n', ...
        P.frozen.rms_deg, C.frozen.rms_deg, P.own.rms_deg, C.own.rms_deg, ...
        P.p.rms_dps, C.p.rms_dps);
    fprintf('         phi_eq %.3f->%.3f deg | u %.3f->%.3f | u^2 ratio=%.3f | valid %.1f/%.1f%%\n', ...
        P.eq.mean_deg, C.eq.mean_deg, P.u.mean, C.u.mean, Cmp.u2_ratio, ...
        100 * P.valid_frac, 100 * C.valid_frac);
    fprintf('Gates: valid=%d decomp=%d own_rip=%d p=%d rudder=%d\n', ...
        G.valid_ss_ok, G.decomp_consistent, G.own_ripple_ok, G.p_rms_ok, G.rudder_act_ok);
    fprintf('Next: %s\n', next_opt);
    fprintf('Detail: %s\n', next_detail);
    fprintf('Files: %s\n%s\n%s\n', md_path, mat_path, png_path);
end

%% ===================== utilities =====================
function y = yn(tf)
    if tf; y = 'YES'; else; y = 'NO'; end
end

function p = pct_change(a, b)
    % positive => b larger than a (worsening for error metrics)
    p = 100 * (b - a) / max(abs(a), 1e-12);
end

function r = rms_local(x)
    x = x(:); x = x(isfinite(x));
    if isempty(x); r = NaN; else; r = sqrt(mean(x.^2)); end
end

function q = prctile_local(x, p)
    x = sort(x(:));
    x = x(isfinite(x));
    if isempty(x); q = NaN; return; end
    n = numel(x);
    k = max(1, min(n, round(p / 100 * n)));
    q = x(k);
end

function [f, P] = onesided_psd(x, dt)
    x = x(:) - mean(x);
    n = numel(x);
    nfft = 2^nextpow2(n);
    X = fft(x, nfft);
    P2 = abs(X / n).^2;
    half = floor(nfft / 2) + 1;
    P = P2(1:half);
    if half > 2
        P(2:end-1) = 2 * P(2:end-1);
    end
    f = (0:half-1)' / (nfft * dt);
end
