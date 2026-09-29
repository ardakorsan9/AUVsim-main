function run_pitch_flightpath_semantics_audit()
% PITCH_FLIGHTPATH_SEMANTICS_AUDIT_001 — read-only θ vs γ semantics audit.
% Inputs (only): SPEED_PI_FF_BENCHMARK.mat, THRUST_TRIM_U15_AUDIT.mat,
%   controller_law.m. One invocation; no production edit.
% Artifacts: suite_results/PITCH_FLIGHTPATH_SEMANTICS_AUDIT.{md,mat,png}
% Appends STATE_SPACE_MODEL_AUDIT.md (history not overwritten).

    project_dir = fileparts(fileparts(fileparts(mfilename('fullpath')))); % repo root
    addpath(genpath(fullfile(project_dir, 'matlab')));
    out_dir = fullfile(project_dir, 'suite_results');
    if ~exist(out_dir, 'dir'); mkdir(out_dir); end
    tag = 'PITCH_FLIGHTPATH_SEMANTICS_AUDIT';
    task_id = 'PITCH_FLIGHTPATH_SEMANTICS_AUDIT_001';

    speed_path  = fullfile(out_dir, 'SPEED_PI_FF_BENCHMARK.mat');
    thrust_path = fullfile(out_dir, 'THRUST_TRIM_U15_AUDIT.mat');
    ctrl_path   = fullfile(project_dir, 'controller_law.m');
    assert(exist(speed_path, 'file') == 2, 'Missing %s', speed_path);
    assert(exist(thrust_path, 'file') == 2, 'Missing %s', thrust_path);
    assert(exist(ctrl_path, 'file') == 2, 'Missing %s', ctrl_path);

    Sp = load(speed_path);
    Trim = load(thrust_path);
    ctrl_txt = fileread(ctrl_path);

    fprintf('\n========== %s ==========\n', task_id);
    fprintf('Read-only: SPEED_PI_FF_BENCHMARK.mat | THRUST_TRIM_U15_AUDIT.mat | controller_law.m\n');
    fprintf('Production: untouched | post-process only (no re-sim)\n');

    % ---- Controller / climb-FF identity from source text ----
    id = parse_controller_identity(ctrl_txt);

    % ---- Exact-u trim kinematics (THRUST_TRIM) ----
    trimK = struct();
    trimK.level = trim_kinematics(Trim.level, 0.0, 'level_exact_u15');
    trimK.climb = trim_kinematics(Trim.climb, atan(0.4), 'XZ_exact_u15_gamma_atan0p4');
    trimK.helix = struct('name', 'R10', 'provenance', 'EMPIRICAL', ...
        'exact_u', 'UNKNOWN', 'note', ...
        'Helix exact-u trim UNKNOWN; use trajectory gamma_act / path tangent only');

    fprintf('Trim level: theta_phys=%+.4f deg  alpha=%+.4f deg  gamma=%+.4f deg  resid=%+.3e deg\n', ...
        rad2deg(trimK.level.theta_phys), rad2deg(trimK.level.alpha), ...
        rad2deg(trimK.level.gamma_kin), rad2deg(trimK.level.resid_kin));
    fprintf('Trim XZ:    theta_phys=%+.4f deg  alpha=%+.4f deg  gamma=%+.4f deg  resid=%+.3e deg\n', ...
        rad2deg(trimK.climb.theta_phys), rad2deg(trimK.climb.alpha), ...
        rad2deg(trimK.climb.gamma_kin), rad2deg(trimK.climb.resid_kin));

    % Regenerate paths (same as SPEED_PI_FF_BENCHMARK driver)
    nX = 600; xX = linspace(0, 45, nX)';
    pathX = [xX, zeros(nX, 1), zeros(nX, 1)];
    nXZ = 900; xXZ = linspace(0, 42, nXZ)';
    pathXZ = [xXZ, zeros(nXZ, 1), 0.4 * xXZ];
    pathH = generate_balanced_helical_path(10.0, 2.0, 2, 500);
    paths = struct('X', pathX, 'XZ', pathXZ, 'H', pathH, 'R10', pathH);

    routes = {'X', 'XZ', 'H'};
    route_label = struct('X', 'X', 'XZ', 'XZ', 'H', 'R10');
    win_note = struct('X', 'first_hold', 'XZ', 'persistent', 'H', 'persistent');

    B = struct(); C = struct();
    for i = 1:numel(routes)
        nm = routes{i};
        lbl = route_label.(nm);
        fprintf('\n-- Analyze %s baseline/candidate --\n', lbl);
        B.(nm) = analyze_series(Sp.baseline.(nm).S, Sp.baseline.(nm).M, ...
            paths.(nm), lbl, win_note.(nm), 'baseline', trimK);
        C.(nm) = analyze_series(Sp.candidate.(nm).S, Sp.candidate.(nm).M, ...
            paths.(nm), lbl, win_note.(nm), 'candidate', trimK);
        print_route_summary(lbl, B.(nm), C.(nm));
    end

    [verdict, root_cause, next_arch, next_detail, gates] = decide(id, trimK, B, C);

    md_path  = fullfile(out_dir, [tag '.md']);
    mat_path = fullfile(out_dir, [tag '.mat']);
    png_path = fullfile(out_dir, [tag '.png']);

    write_png(png_path, B, C, task_id, verdict);
    write_md(md_path, task_id, verdict, id, trimK, B, C, gates, root_cause, ...
        next_arch, next_detail, speed_path, thrust_path, ctrl_path, ...
        md_path, mat_path, png_path);
    append_ss_audit(out_dir, task_id, verdict, id, trimK, B, C, gates, ...
        root_cause, next_arch, next_detail, md_path, mat_path, png_path);

    Out = struct();
    Out.task_id = task_id;
    Out.verdict = verdict;
    Out.identity = id;
    Out.trim = trimK;
    Out.baseline = B;
    Out.candidate = C;
    Out.gates = gates;
    Out.root_cause = root_cause;
    Out.next_arch = next_arch;
    Out.next_detail = next_detail;
    Out.sources = {speed_path; thrust_path; ctrl_path};
    Out.paths = struct('md', md_path, 'mat', mat_path, 'png', png_path);
    Out.production_edited = false;
    Out.note = ['Post-process only from SPEED_PI_FF_BENCHMARK timeseries; ', ...
        'correct metric defs without overwriting history'];
    save(mat_path, '-struct', 'Out');

    fprintf('\nVERDICT: %s | next=%s\n', verdict, next_arch);
    fprintf('Saved: %s\n%s\n%s\n', md_path, mat_path, png_path);
    print_feedback(verdict, id, trimK, B, C, root_cause, next_arch, ...
        next_detail, md_path, mat_path, png_path);
    assignin('base', 'PITCH_FLIGHTPATH_SEMANTICS_AUDIT_PASS', strcmp(verdict, 'PASS'));
end

%% ===================== identity / trim =====================
function id = parse_controller_identity(txt)
    id = struct();
    id.e_theta_is_attitude = contains(txt, 'e_theta = pitch_ref - theta_phys');
    id.theta_phys_def = contains(txt, 'theta_phys = -theta');
    id.climb_ff_aliases_gamma = contains(txt, 'gamma_ref = pitch_ref');
    id.k_gamma_climb = 0.1320695001;
    id.controller_tracks = 'theta_phys (attitude)';
    id.pitch_ref_consumed_as = 'attitude reference (e_theta = pitch_ref - theta_phys)';
    id.climb_ff_treats_as = 'gamma_ref := pitch_ref (path/climb angle semantics in comment)';
    id.guidance_production = ['K_gamma=0, enable_alpha_hat=false => pitch_raw = pitch_geom + depth_corr; ', ...
        'pitch_geom = atan2(t_z, ||t_xy||) ≈ path flight-path angle gamma_path'];
    id.semantic_mismatch = id.e_theta_is_attitude && id.climb_ff_aliases_gamma;
    id.kinematic_exact_phi0_v0 = 'gamma = theta_phys + alpha, alpha=atan2(w,u) [BODY]';
    id.coupling_warning = ['With roll phi or sway v nonzero, NED gamma_act=atan2(V_D,Uh) ', ...
        'differs from theta_phys+atan2(w,u); residual quantifies that approximation.'];
    id.assert_ok = id.e_theta_is_attitude && id.theta_phys_def && id.climb_ff_aliases_gamma;
end

function K = trim_kinematics(P, gamma_path_cmd, name)
    u = P.x_star(7); w = P.x_star(9); theta = P.x_star(5);
    theta_phys = -theta;
    alpha = atan2(w, u);
    gamma_kin = theta_phys + alpha;
    gamma_ned = atan2(P.eta_dot(3), hypot(P.eta_dot(1), P.eta_dot(2)));
    K = struct();
    K.name = name;
    K.u = u; K.w = w; K.v = P.x_star(8);
    K.theta = theta; K.theta_phys = theta_phys;
    K.alpha = alpha;
    K.gamma_path_cmd = gamma_path_cmd;
    K.gamma_kin = gamma_kin;
    K.gamma_ned = gamma_ned;
    K.resid_kin = wrapToPi(gamma_ned - gamma_kin);
    K.theta_cmd_for_gamma = gamma_path_cmd - alpha;  % required attitude
    K.Treq = P.Treq;
    K.pass = P.pass;
    K.provenance = P.provenance;
end

%% ===================== series analysis =====================
function R = analyze_series(S, M, path, label, win_mode, mode, trimK)
    t = S.t(:); dt = S.dt; n = numel(t);
    phi = S.ori(:, 1); theta = S.ori(:, 2); psi = S.ori(:, 3);
    u = S.u_body(:); v = S.v_body(:); w = S.w_body(:);
    theta_phys = -theta;
    theta_ref = S.theta_ref(:);          % controller pitch_ref (attitude-consumed)

    % Exact NED flight path
    [VN, VE, VD, Uh] = ned_velocity(phi, theta, psi, u, v, w);
    gamma_act = atan2(VD, max(Uh, 1e-9));
    alpha = atan2(w, u);                 % BODY AoA approx (ignores v)
    gamma_kin = theta_phys + alpha;
    resid = wrapToPi(gamma_act - gamma_kin);

    % Exact path tangent gamma_ref (Frenet) + CTE
    [gamma_ref, cte_perp, s_prog, s_total, t_hat] = path_gamma_cte(path, S.vp);

    % Required attitude for path gamma under BODY alpha approx
    theta_cmd = wrapToPi(gamma_ref - alpha);

    % Errors under current (wrong/ambiguous) vs corrected semantics
    e_theta_legacy = wrapToPi(theta_ref - theta_phys);   % what prior pitch MAE rewarded
    e_gamma = wrapToPi(gamma_ref - gamma_act);
    e_theta_req = wrapToPi(theta_cmd - theta_phys);      % attitude error vs required
    e_ref_vs_gamma = wrapToPi(theta_ref - gamma_ref);    % does pitch_ref track gamma?
    e_ref_vs_thcmd = wrapToPi(theta_ref - theta_cmd);    % pitch_ref vs required attitude

    % Windows from SPEED mat (history preserved); also recompute on gamma/req
    mask_ss = M.mask_ss(:);
    mask_acq = M.mask_acq(:);
    mask_hold = M.mask_hold(:);
    if ~any(mask_ss); mask_ss = (t >= 5) & (s_prog < 0.88 * s_total); end
    if ~any(mask_acq); mask_acq = (t < 5) & (s_prog < 0.88 * s_total); end
    if ~any(mask_hold); mask_hold = mask_ss; end

    W_legacy = compute_pitch_window_metrics(t, e_theta_legacy, s_prog, s_total, 'mode', win_mode);
    W_gamma  = compute_pitch_window_metrics(t, e_gamma, s_prog, s_total, 'mode', win_mode);
    W_req    = compute_pitch_window_metrics(t, e_theta_req, s_prog, s_total, 'mode', win_mode);

    R = struct();
    R.label = label; R.mode = mode; R.win_mode = win_mode;
    R.t = t; R.dt = dt;
    R.gamma_act = gamma_act; R.gamma_ref = gamma_ref;
    R.theta_phys = theta_phys; R.theta_ref = theta_ref;
    R.theta_cmd = theta_cmd; R.alpha = alpha;
    R.resid = resid; R.cte_perp = cte_perp;
    R.phi = phi; R.v = v; R.u = u; R.w = w;
    R.Uh = Uh; R.VD = VD;
    R.s_prog = s_prog; R.s_total = s_total;
    R.t_hat = t_hat;
    R.mask_ss = mask_ss; R.mask_acq = mask_acq; R.mask_hold = mask_hold;
    R.e_theta_legacy = e_theta_legacy;
    R.e_gamma = e_gamma;
    R.e_theta_req = e_theta_req;
    R.e_ref_vs_gamma = e_ref_vs_gamma;
    R.e_ref_vs_thcmd = e_ref_vs_thcmd;

    R.metrics = struct();
    R.metrics.legacy_theta = err_pack(e_theta_legacy, mask_acq, mask_ss, W_legacy);
    R.metrics.gamma = err_pack(e_gamma, mask_acq, mask_ss, W_gamma);
    R.metrics.theta_req = err_pack(e_theta_req, mask_acq, mask_ss, W_req);
    R.metrics.ref_vs_gamma = err_stats(e_ref_vs_gamma, mask_ss);
    R.metrics.ref_vs_thcmd = err_stats(e_ref_vs_thcmd, mask_ss);
    R.metrics.alpha = err_stats(alpha, mask_ss);
    R.metrics.resid = err_stats(resid, mask_ss);
    R.metrics.cte = cte_stats(cte_perp, mask_ss);
    R.metrics.u = err_stats_lin(u, mask_hold);
    R.metrics.phi_rms_deg = rad2deg(rms_safe(phi(mask_ss)));
    R.metrics.v_rms = rms_safe(v(mask_ss));
    R.metrics.speed_mae_reported = M.speed.steady.mae;
    R.metrics.pitch_mae_reported = M.pitch.mae_deg;
    R.metrics.cte_reported = M.path.mean_cte;

    % Helix labels
    R.approx = struct();
    R.approx.alpha_body = 'alpha=atan2(w,u) BODY; ignores v and roll/v NED coupling';
    R.approx.helix_geometry = 'gamma_ref from exact helix path tangent (Frenet); not constant';
    R.approx.gamma_act = 'gamma_act=atan2(V_D,hypot(V_N,V_E)) exact NED from R(phi,theta,psi)*nu';

    % Trim comparison targets
    switch upper(label)
        case 'X'
            R.trim_target = trimK.level;
        case 'XZ'
            R.trim_target = trimK.climb;
        otherwise
            R.trim_target = trimK.helix;
    end
end

function P = err_pack(e, mask_acq, mask_ss, W)
    P = struct();
    P.acq = err_stats(e, mask_acq);
    P.steady = err_stats(e, mask_ss);
    P.W = W;
    P.acq_time_s = W.acq_time_s;
    P.settling_s = W.settling_s;
    P.persistent_ok = W.persistent_ok;
end

function st = err_stats(e, mask)
    e = e(:); mask = mask(:) & isfinite(e);
    st = struct('n', nnz(mask), 'mae_deg', NaN, 'rms_deg', NaN, ...
        'p95_deg', NaN, 'signed_mean_deg', NaN, 'max_deg', NaN);
    if ~any(mask); return; end
    v = rad2deg(e(mask));
    st.mae_deg = mean(abs(v));
    st.rms_deg = sqrt(mean(v.^2));
    st.p95_deg = local_prctile(abs(v), 95);
    st.signed_mean_deg = mean(v);
    st.max_deg = max(abs(v));
end

function st = err_stats_lin(x, mask)
    x = x(:); mask = mask(:) & isfinite(x);
    st = struct('n', nnz(mask), 'mean', NaN, 'mae_from_mean', NaN, 'std', NaN);
    if ~any(mask); return; end
    v = x(mask);
    st.mean = mean(v); st.std = std(v); st.mae_from_mean = mean(abs(v - mean(v)));
end

function st = cte_stats(cte, mask)
    cte = cte(:); mask = mask(:) & isfinite(cte);
    st = struct('n', nnz(mask), 'mean', NaN, 'rms', NaN, 'p95', NaN, 'max', NaN);
    if ~any(mask); return; end
    v = cte(mask);
    st.mean = mean(v); st.rms = sqrt(mean(v.^2));
    st.p95 = local_prctile(v, 95); st.max = max(v);
end

%% ===================== kinematics helpers =====================
function [VN, VE, VD, Uh] = ned_velocity(phi, theta, psi, u, v, w)
    n = numel(u);
    VN = zeros(n, 1); VE = zeros(n, 1); VD = zeros(n, 1); Uh = zeros(n, 1);
    for i = 1:n
        R = Rzyx(phi(i), theta(i), psi(i));
        V = R * [u(i); v(i); w(i)];
        VN(i) = V(1); VE(i) = V(2); VD(i) = V(3);
        Uh(i) = hypot(V(1), V(2));
    end
end

function R = Rzyx(phi, theta, psi)
    R = [cos(psi)*cos(theta), ...
         cos(psi)*sin(theta)*sin(phi) - sin(psi)*cos(phi), ...
         cos(psi)*sin(theta)*cos(phi) + sin(psi)*sin(phi);
         sin(psi)*cos(theta), ...
         sin(psi)*sin(theta)*sin(phi) + cos(psi)*cos(phi), ...
         sin(psi)*sin(theta)*cos(phi) - cos(psi)*sin(phi);
         -sin(theta), cos(theta)*sin(phi), cos(theta)*cos(phi)];
end

function [gamma_ref, cte_perp, s_prog, s_total, t_hat_log] = path_gamma_cte(path, vp)
    n = size(vp, 1);
    [s_nodes, s_total] = path_arclength_local(path);
    is_closed = norm(path(1,:) - path(end,:)) < 0.25;
    gamma_ref = zeros(n, 1);
    cte_perp = zeros(n, 1);
    s_prog = zeros(n, 1);
    t_hat_log = zeros(n, 3);
    s = 0; L = 1.25;
    for i = 1:n
        p = vp(i, :);
        if i == 1
            [s_near, ~] = project_on_path_local(p, path, s_nodes, 0, s_total, is_closed);
            s = s_near;
            if is_closed; s = mod(s, s_total); end
        else
            if is_closed
                win = max(3.0, 2.5*L);
                s_lo = mod(s - 0.15, s_total);
                [s_near, ~] = project_wrapped_local(p, path, s_nodes, s_lo, win, s_total);
                ds = wrap_arc_local(s_near - s, s_total);
                if ds >= -0.25
                    s = mod(s + max(ds, -0.05), s_total);
                end
            else
                s_lo = max(0, s - 0.15);
                s_hi = min(s_total, s + max(3.0, 2.5*L));
                [s_near, ~] = project_on_path_local(p, path, s_nodes, s_lo, s_hi, is_closed);
                if s_near >= s_total - 1e-6
                    s = s_total;
                else
                    s = max(s, s_near - 0.05);
                    s = min(s, s_total);
                end
            end
        end
        [p_d, t_hat] = sample_path_local(path, s_nodes, s, is_closed);
        th = t_hat(:);
        gamma_ref(i) = atan2(th(3), max(hypot(th(1), th(2)), 1e-9));
        dp = (p(:) - p_d(:));
        e_perp = (eye(3) - (th * th')) * dp;
        cte_perp(i) = norm(e_perp);
        s_prog(i) = s;
        t_hat_log(i, :) = th';
    end
end

function [s_nodes, s_total] = path_arclength_local(path)
    d = vecnorm(diff(path), 2, 2);
    s_nodes = [0; cumsum(d)];
    s_total = s_nodes(end);
    if s_total < 1e-9; s_total = 1e-9; end
end

function [p, t_hat] = sample_path_local(path, s_nodes, s, is_closed)
    s_total = s_nodes(end);
    if is_closed
        s = mod(s, s_total);
    else
        s = min(max(s, 0), s_total);
    end
    idx = find(s_nodes <= s, 1, 'last');
    if isempty(idx); idx = 1; end
    if idx >= numel(s_nodes)
        p = path(end, :);
        t_hat = path(end, :) - path(end-1, :);
    else
        s0 = s_nodes(idx); s1 = s_nodes(idx+1);
        a = (s - s0) / max(s1 - s0, 1e-12);
        p = (1 - a) * path(idx, :) + a * path(idx+1, :);
        t_hat = path(idx+1, :) - path(idx, :);
    end
    nrm = norm(t_hat);
    if nrm < 1e-12
        t_hat = [1, 0, 0];
    else
        t_hat = t_hat / nrm;
    end
end

function [s_near, dmin] = project_on_path_local(p, path, s_nodes, s_lo, s_hi, is_closed)
    % Dense sample in [s_lo,s_hi]
    if s_hi < s_lo; tmp = s_lo; s_lo = s_hi; s_hi = tmp; end
    ns = max(20, ceil((s_hi - s_lo) / 0.25));
    ss = linspace(s_lo, s_hi, ns);
    dmin = inf; s_near = s_lo;
    for k = 1:numel(ss)
        pk = sample_path_local(path, s_nodes, ss(k), is_closed);
        d = norm(p - pk);
        if d < dmin; dmin = d; s_near = ss(k); end
    end
end

function [s_near, dmin] = project_wrapped_local(p, path, s_nodes, s_lo, win, s_total)
    ns = max(40, ceil(win / 0.25));
    ss = mod(s_lo + linspace(0, win, ns), s_total);
    dmin = inf; s_near = ss(1);
    for k = 1:numel(ss)
        pk = sample_path_local(path, s_nodes, ss(k), true);
        d = norm(p - pk);
        if d < dmin; dmin = d; s_near = ss(k); end
    end
end

function ds = wrap_arc_local(ds, L)
    ds = mod(ds + L/2, L) - L/2;
end

%% ===================== decision =====================
function [verdict, root, next_arch, next_detail, G] = decide(id, trimK, B, C)
    G = struct();
    G.identity_assert = id.assert_ok;
    G.trim_level_alpha_matches = abs(rad2deg(trimK.level.alpha) - (-1.910)) < 0.05;
    G.trim_climb_gamma_matches = abs(rad2deg(trimK.climb.gamma_kin) - 21.801) < 0.05;
    G.trim_climb_theta_matches = abs(rad2deg(trimK.climb.theta_phys) - 24.743) < 0.05;

    % Note: closed-loop pitch_ref = gamma_path + depth_corr. Depth-I often
    % partially mimics alpha compensation, so |ref-θ_cmd| < |ref-γ| is common
    % and is NOT evidence that guidance emits attitude. Identity is from code.
    for nm = {'X', 'XZ', 'H'}
        name = nm{1};
        Bb = B.(name); Cc = C.(name);
        G.(name) = struct();
        G.(name).base_ref_nearer_thcmd = Bb.metrics.ref_vs_thcmd.mae_deg <= Bb.metrics.ref_vs_gamma.mae_deg;
        G.(name).cand_ref_nearer_thcmd = Cc.metrics.ref_vs_thcmd.mae_deg <= Cc.metrics.ref_vs_gamma.mae_deg;
        G.(name).legacy_pitch_regresses = Cc.metrics.legacy_theta.steady.mae_deg > ...
            1.02 * Bb.metrics.legacy_theta.steady.mae_deg;
        G.(name).cte_regresses = Cc.metrics.cte.mean > 1.02 * Bb.metrics.cte.mean;
        G.(name).gamma_err_gt_legacy = Cc.metrics.gamma.steady.mae_deg > ...
            Cc.metrics.legacy_theta.steady.mae_deg;  % legacy metric understates path error
        G.(name).gamma_err_cand = Cc.metrics.gamma.steady.mae_deg;
        G.(name).legacy_err_cand = Cc.metrics.legacy_theta.steady.mae_deg;
        G.(name).alpha_shift_deg = Cc.metrics.alpha.signed_mean_deg - Bb.metrics.alpha.signed_mean_deg;
        G.(name).alpha_cand = Cc.metrics.alpha.signed_mean_deg;
        G.(name).u_base = Bb.metrics.u.mean;
        G.(name).u_cand = Cc.metrics.u.mean;
        G.(name).resid_rms_cand = Cc.metrics.resid.rms_deg;
        G.(name).phi_rms_cand = Cc.metrics.phi_rms_deg;
        G.(name).v_rms_cand = Cc.metrics.v_rms;
    end

    G.X.alpha_to_trim = abs(G.X.alpha_cand - rad2deg(trimK.level.alpha)) < 0.15;
    G.XZ.alpha_to_trim = abs(G.XZ.alpha_cand - rad2deg(trimK.climb.alpha)) < 0.15;

    % Audit PASS = diagnosis consistent (not "production pitch OK")
    clear_mismatch = id.semantic_mismatch && G.identity_assert;
    trim_ok = G.trim_level_alpha_matches && G.trim_climb_gamma_matches && G.trim_climb_theta_matches;
    speed_coupling_seen = G.X.legacy_pitch_regresses && G.XZ.legacy_pitch_regresses && ...
        (abs(G.X.u_cand - 1.5) < 0.05) && (abs(G.XZ.u_cand - 1.5) < 0.05);
    legacy_optimistic = G.X.gamma_err_gt_legacy && G.XZ.gamma_err_gt_legacy;
    alpha_moves_to_trim = G.X.alpha_to_trim && G.XZ.alpha_to_trim;
    kin_ok = (G.X.resid_rms_cand < 0.05) && (G.XZ.resid_rms_cand < 0.05);

    if clear_mismatch && trim_ok && speed_coupling_seen && legacy_optimistic && ...
            alpha_moves_to_trim && kin_ok
        verdict = 'PASS';
    else
        verdict = 'FAIL';
    end

    root = ['Guidance builds pitch_ref = gamma_path + depth_corr (K_gamma=0, alpha_hat OFF); ', ...
        'controller_law tracks pitch_ref as theta_phys (e_theta=pitch_ref-theta_phys); ', ...
        'climb FF aliases gamma_ref:=pitch_ref. Exact-u trim needs theta_phys=gamma-alpha ', ...
        sprintf('(level alpha=%.3f deg, XZ alpha=%.3f deg). ', ...
            rad2deg(trimK.level.alpha), rad2deg(trimK.climb.alpha)), ...
        'Depth-I partially mimics alpha (closed-loop ref often nearer theta_cmd than raw gamma) ', ...
        'but is not explicit AoA compensation — speed-dependent. Prior pitch MAE rewarded ', ...
        '|pitch_ref-theta_phys| and understates true e_gamma. When SPEED candidate forces ', ...
        'BODY u→1.5, alpha→trim and required attitude shifts; legacy pitch + CTE regress.'];

    % Single next architecture: measured/trim alpha compensation
    next_arch = 'measured_trim_alpha_compensation';
    next_detail = [ ...
        'BOUNDED NEXT (do not implement here): keep attitude cascade; set ', ...
        'theta_ref_cmd = gamma_ref_path - alpha_hat before controller. ', ...
        'alpha_hat from (1) trim schedule on (u_ref, gamma_ref) using THRUST exact-u ', ...
        'level/XZ alphas, and/or (2) measured BODY alpha=atan2(w,u) LPF. ', ...
        'Sensors/frames: BODY u,w already in controller_law (12th arg); filter tau~0.3-1s; ', ...
        'clamp |alpha_hat| (e.g. 8 deg, existing enable_alpha_hat scaffold). ', ...
        'Helix: treat atan2(w,u) as APPROX — monitor resid=gamma_act-(theta_phys+alpha); ', ...
        'if |phi| or |v| large, add roll/v correction or fall back to outer gamma later. ', ...
        'Reject outer flight-path loop for this step (Tur5B K_gamma already tried; ', ...
        'larger sensor/filter surface: needs reliable NED V or reconstructed gamma_act). ', ...
        'Correct new metrics: report e_gamma and e_theta_req separately; do not overwrite ', ...
        'historical pitch MAE definitions.'];
end

%% ===================== I/O =====================
function write_png(png_path, B, C, task_id, verdict)
    fig = figure('Visible', 'off', 'Color', 'w', 'Position', [40 40 1400 900]);
    routes = {'X', 'XZ', 'H'};
    titles = {'X (level)', 'XZ (climb)', 'R10 helix'};
    for i = 1:3
        nm = routes{i};
        Bb = B.(nm); Cc = C.(nm);
        % row1: gamma
        subplot(5, 3, i);
        plot(Bb.t, rad2deg(Bb.gamma_ref), 'k--', 'LineWidth', 1.0); hold on;
        plot(Bb.t, rad2deg(Bb.gamma_act), 'b'); plot(Cc.t, rad2deg(Cc.gamma_act), 'r');
        grid on; ylabel('\gamma [deg]'); title(sprintf('%s | %s', titles{i}, verdict));
        if i == 1; legend('\gamma_{ref}', 'base \gamma_{act}', 'cand \gamma_{act}', 'Location', 'best'); end
        % row2: theta
        subplot(5, 3, 3 + i);
        plot(Bb.t, rad2deg(Bb.theta_ref), 'k--'); hold on;
        plot(Bb.t, rad2deg(Bb.theta_phys), 'b'); plot(Cc.t, rad2deg(Cc.theta_phys), 'r');
        plot(Cc.t, rad2deg(Cc.theta_cmd), 'm:', 'LineWidth', 1.0);
        grid on; ylabel('\theta [deg]');
        if i == 1; legend('\theta_{ref}(ctrl)', 'base \theta_{phys}', 'cand \theta_{phys}', ...
                '\theta_{cmd}=\gamma_{ref}-\alpha', 'Location', 'best'); end
        % row3: alpha
        subplot(5, 3, 6 + i);
        plot(Bb.t, rad2deg(Bb.alpha), 'b'); hold on;
        plot(Cc.t, rad2deg(Cc.alpha), 'r');
        grid on; ylabel('\alpha [deg]');
        if i == 1; legend('base', 'cand', 'Location', 'best'); end
        % row4: residual
        subplot(5, 3, 9 + i);
        plot(Bb.t, rad2deg(Bb.resid), 'b'); hold on;
        plot(Cc.t, rad2deg(Cc.resid), 'r');
        grid on; ylabel('resid [deg]');
        if i == 1; legend('base', 'cand', 'Location', 'best'); end
        % row5: CTE
        subplot(5, 3, 12 + i);
        plot(Bb.t, Bb.cte_perp, 'b'); hold on;
        plot(Cc.t, Cc.cte_perp, 'r');
        grid on; ylabel('CTE [m]'); xlabel('t [s]');
        if i == 1; legend('base', 'cand', 'Location', 'best'); end
    end
    sgtitle([task_id ' — gamma_ref/act, theta_phys/ref, alpha, residual, CTE'], ...
        'Interpreter', 'none');
    exportgraphics(fig, png_path, 'Resolution', 140);
    close(fig);
end

function write_md(md_path, task_id, verdict, id, trimK, B, C, G, root, next_arch, ...
        next_detail, speed_path, thrust_path, ctrl_path, md_out, mat_out, png_out)
    fid = fopen(md_path, 'w');
    assert(fid > 0);
    fprintf(fid, '# %s — Pitch-ref θ vs flight-path γ semantics audit\n\n', task_id);
    fprintf(fid, '**Overall verdict: %s**\n\n', verdict);
    fprintf(fid, '## Provenance\n\n');
    fprintf(fid, '- Read-only: `%s`, `%s`, `%s`\n', speed_path, thrust_path, ctrl_path);
    fprintf(fid, '- Driver: `run_pitch_flightpath_semantics_audit.m` (one invocation; production untouched)\n');
    fprintf(fid, '- Artifacts: `%s`, `%s`, `%s`\n', md_out, mat_out, png_out);
    fprintf(fid, '- History: prior pitch MAE definitions NOT overwritten; this audit adds corrected γ/θ_cmd metrics\n\n');

    fprintf(fid, '## Identity (controller_law + guidance contract)\n\n');
    fprintf(fid, '```\n');
    fprintf(fid, 'controller: e_theta = pitch_ref - theta_phys   => pitch_ref consumed as ATTITUDE\n');
    fprintf(fid, '            theta_phys = -theta\n');
    fprintf(fid, 'climb FF:   gamma_ref = pitch_ref; de_climb_ff = sat(k_gamma*gamma_ref)\n');
    fprintf(fid, '            k_gamma = %.10f  (from path_pitch 21.8014 deg)\n', id.k_gamma_climb);
    fprintf(fid, 'guidance:   %s\n', id.guidance_production);
    fprintf(fid, 'kinematics: %s\n', id.kinematic_exact_phi0_v0);
    fprintf(fid, 'warning:    %s\n', id.coupling_warning);
    fprintf(fid, 'mismatch:   %d (guidance γ-like ref vs attitude tracker)\n', id.semantic_mismatch);
    fprintf(fid, '```\n\n');

    fprintf(fid, '## Exact-u trim kinematics (THRUST_TRIM_U15; history labels preserved)\n\n');
    fprintf(fid, '| Point | u* | θ_phys [deg] | α=atan2(w,u) [deg] | γ_kin=θ+α | γ_path | resid [deg] | θ_cmd=γ-α |\n');
    fprintf(fid, '|-------|---:|-------------:|-------------------:|----------:|-------:|------------:|----------:|\n');
    L = trimK.level; X = trimK.climb;
    fprintf(fid, '| Level | %.3f | %+.4f | %+.4f | %+.4f | %.4f | %+.3e | %+.4f |\n', ...
        L.u, rad2deg(L.theta_phys), rad2deg(L.alpha), rad2deg(L.gamma_kin), ...
        rad2deg(L.gamma_path_cmd), rad2deg(L.resid_kin), rad2deg(L.theta_cmd_for_gamma));
    fprintf(fid, '| XZ | %.3f | %+.4f | %+.4f | %+.4f | %.4f | %+.3e | %+.4f |\n', ...
        X.u, rad2deg(X.theta_phys), rad2deg(X.alpha), rad2deg(X.gamma_kin), ...
        rad2deg(X.gamma_path_cmd), rad2deg(X.resid_kin), rad2deg(X.theta_cmd_for_gamma));
    fprintf(fid, '| R10 | UNKNOWN | — | — | — | path tangent (exact geom) | traj resid | α BODY approx |\n\n');
    fprintf(fid, 'User check: level θ_phys=+1.910 / w=-0.050 / α≈-1.910; XZ θ_phys=+24.743 / w=-0.077 / α≈-2.942; γ=21.801.\n\n');

    fprintf(fid, '## Corrected metric definitions (additive; do not replace history)\n\n');
    fprintf(fid, '```\n');
    fprintf(fid, 'gamma_act   = atan2(V_D, hypot(V_N,V_E))     % exact NED\n');
    fprintf(fid, 'gamma_ref   = atan2(t_hat_z, ||t_hat_xy||)  % exact path tangent\n');
    fprintf(fid, 'theta_phys  = -Euler_theta\n');
    fprintf(fid, 'alpha       = atan2(w,u)                   % BODY approx (label)\n');
    fprintf(fid, 'resid       = gamma_act - (theta_phys+alpha)  % roll/v coupling\n');
    fprintf(fid, 'theta_cmd   = gamma_ref - alpha            % required attitude\n');
    fprintf(fid, 'e_theta_legacy = theta_ref - theta_phys    % HISTORICAL pitch MAE\n');
    fprintf(fid, 'e_gamma        = gamma_ref - gamma_act     % true flight-path error\n');
    fprintf(fid, 'e_theta_req    = theta_cmd - theta_phys    % attitude vs required\n');
    fprintf(fid, '```\n\n');

    fprintf(fid, '## Route table — baseline → speed candidate (steady window)\n\n');
    fprintf(fid, '| Route | u B→C | legacy|θ| MAE° | γ MAE° | θ_req MAE° | α mean° | resid RMS° | CTE m | ref nearer θ_cmd? |\n');
    fprintf(fid, '|-------|------:|-----------------:|-------:|-----------:|--------:|-----------:|------:|:-----------------:|\n');
    for nm = {'X', 'XZ', 'H'}
        name = nm{1}; Bb = B.(name); Cc = C.(name); g = G.(name);
        fprintf(fid, '| %s | %.3f→%.3f | %.3f→%.3f | %.3f→%.3f | %.3f→%.3f | %+.2f→%+.2f | %.3f→%.3f | %.3f→%.3f | %d→%d |\n', ...
            Bb.label, Bb.metrics.u.mean, Cc.metrics.u.mean, ...
            Bb.metrics.legacy_theta.steady.mae_deg, Cc.metrics.legacy_theta.steady.mae_deg, ...
            Bb.metrics.gamma.steady.mae_deg, Cc.metrics.gamma.steady.mae_deg, ...
            Bb.metrics.theta_req.steady.mae_deg, Cc.metrics.theta_req.steady.mae_deg, ...
            Bb.metrics.alpha.signed_mean_deg, Cc.metrics.alpha.signed_mean_deg, ...
            Bb.metrics.resid.rms_deg, Cc.metrics.resid.rms_deg, ...
            Bb.metrics.cte.mean, Cc.metrics.cte.mean, ...
            g.base_ref_nearer_thcmd, g.cand_ref_nearer_thcmd);
    end
    fprintf(fid, '\nNote: ref nearer θ_cmd than raw γ is expected when depth-I partially mimics α; construction is still γ_path+depth, not explicit attitude/α.\n');

    fprintf(fid, '\n## Acquisition / steady (candidate; corrected)\n\n');
    fprintf(fid, '| Route | legacy acq/ss MAE° | γ acq/ss MAE° | θ_req acq/ss MAE° | acq_time_s (legacy W) |\n');
    fprintf(fid, '|-------|------------------:|--------------:|------------------:|----------------------:|\n');
    for nm = {'X', 'XZ', 'H'}
        name = nm{1}; Cc = C.(name);
        fprintf(fid, '| %s | %.3f / %.3f | %.3f / %.3f | %.3f / %.3f | %.2f |\n', ...
            Cc.label, ...
            Cc.metrics.legacy_theta.acq.mae_deg, Cc.metrics.legacy_theta.steady.mae_deg, ...
            Cc.metrics.gamma.acq.mae_deg, Cc.metrics.gamma.steady.mae_deg, ...
            Cc.metrics.theta_req.acq.mae_deg, Cc.metrics.theta_req.steady.mae_deg, ...
            Cc.metrics.legacy_theta.acq_time_s);
    end

    fprintf(fid, '\n## Speed coupling explanation\n\n');
    fprintf(fid, '%s\n\n', root);

    fprintf(fid, '## Helix labels\n\n');
    fprintf(fid, '- Geometry: `gamma_ref` from exact `generate_balanced_helical_path(10,2,2,*)` Frenet tangent.\n');
    fprintf(fid, '- Approximation: BODY `alpha=atan2(w,u)` ignores sway `v` and roll; residual RMS on R10 candidate = %.3f deg (phi_rms=%.2f deg, v_rms=%.3f).\n\n', ...
        C.H.metrics.resid.rms_deg, C.H.metrics.phi_rms_deg, C.H.metrics.v_rms);

    fprintf(fid, '## Gate table\n\n');
    fprintf(fid, '| Gate | Result | Detail |\n');
    fprintf(fid, '|------|:------:|--------|\n');
    fprintf(fid, '| Controller identity parsed | %s | e_theta / gamma_ref alias |\n', yn(G.identity_assert));
    fprintf(fid, '| Trim α/θ/γ match stated | %s | level α≈-1.910; XZ θ≈24.743 γ≈21.801 |\n', ...
        yn(G.trim_level_alpha_matches && G.trim_climb_gamma_matches && G.trim_climb_theta_matches));
    fprintf(fid, '| Cand α→exact-u trim (X,XZ) | %s | X α→%.2f XZ α→%.2f |\n', ...
        yn(G.X.alpha_to_trim && G.XZ.alpha_to_trim), G.X.alpha_cand, G.XZ.alpha_cand);
    fprintf(fid, '| e_gamma > legacy|θ| (X,XZ) | %s | legacy metric understates path error |\n', ...
        yn(G.X.gamma_err_gt_legacy && G.XZ.gamma_err_gt_legacy));
    fprintf(fid, '| Speed cand u→1.5 + pitch/CTE regress | %s | exposes semantics |\n', ...
        yn(G.X.legacy_pitch_regresses && G.XZ.legacy_pitch_regresses));
    fprintf(fid, '| Kinematic resid RMS≈0 (X,XZ) | %s | phi=v=0 identity holds |\n', ...
        yn(G.X.resid_rms_cand < 0.05 && G.XZ.resid_rms_cand < 0.05));

    fprintf(fid, '\n## Decision\n\n');
    fprintf(fid, '- Verdict: **%s**\n', verdict);
    fprintf(fid, '- Root: semantic mismatch (γ-command tracked as θ) + speed-dependent α\n');
    fprintf(fid, '- Next architecture (exactly one): `%s`\n', next_arch);
    fprintf(fid, '- Detail: %s\n', next_detail);
    fprintf(fid, '- Production: untouched\n\n');

    fprintf(fid, '## Feedback\n\n');
    fprintf(fid, '- PASS/FAIL: **%s**\n', verdict);
    fprintf(fid, '- Identity: pitch_ref consumed as θ_phys; guidance emits γ-like; climb FF aliases γ:=pitch_ref\n');
    fprintf(fid, '- Trim: level θ_phys=%+.3f° α=%+.3f°; XZ θ_phys=%+.3f° α=%+.3f° γ=%+.3f°\n', ...
        rad2deg(L.theta_phys), rad2deg(L.alpha), rad2deg(X.theta_phys), rad2deg(X.alpha), rad2deg(X.gamma_kin));
    fprintf(fid, '- Cand steady legacy|θ| / γ MAE°: X %.3f/%.3f | XZ %.3f/%.3f | R10 %.3f/%.3f\n', ...
        C.X.metrics.legacy_theta.steady.mae_deg, C.X.metrics.gamma.steady.mae_deg, ...
        C.XZ.metrics.legacy_theta.steady.mae_deg, C.XZ.metrics.gamma.steady.mae_deg, ...
        C.H.metrics.legacy_theta.steady.mae_deg, C.H.metrics.gamma.steady.mae_deg);
    fprintf(fid, '- Files: `%s` `%s` `%s`\n', md_out, mat_out, png_out);
    fprintf(fid, '- Next: `%s`\n', next_arch);
    fclose(fid);
end

function append_ss_audit(out_dir, task_id, verdict, id, trimK, B, C, G, root, ...
        next_arch, next_detail, md_path, mat_path, png_path)
    audit_path = fullfile(out_dir, 'STATE_SPACE_MODEL_AUDIT.md');
    fid = fopen(audit_path, 'a');
    assert(fid > 0);
    fprintf(fid, '\n\n---\n\n');
    fprintf(fid, '## %s — %s\n\n', task_id, datestr(now, 'yyyy-mm-dd HH:MM:SS'));
    fprintf(fid, '### Provenance\n\n');
    fprintf(fid, '- Read-only: `SPEED_PI_FF_BENCHMARK.mat`, `THRUST_TRIM_U15_AUDIT.mat`, `controller_law.m`\n');
    fprintf(fid, '- Driver: `run_pitch_flightpath_semantics_audit.m` (one invocation; production untouched)\n');
    fprintf(fid, '- Artifacts: `%s`, `%s`, `%s`\n', md_path, mat_path, png_path);
    fprintf(fid, '- History: prior pitch MAE not overwritten; additive γ / θ_cmd metrics\n\n');
    fprintf(fid, '### Identity\n\n');
    fprintf(fid, '```\n');
    fprintf(fid, 'e_theta = pitch_ref - theta_phys  (attitude tracker)\n');
    fprintf(fid, 'gamma_ref = pitch_ref             (climb FF alias)\n');
    fprintf(fid, 'guidance pitch_geom ≈ gamma_path  (K_gamma=0, alpha_hat OFF)\n');
    fprintf(fid, 'gamma = theta_phys + atan2(w,u)   (phi=0,v=0 exact)\n');
    fprintf(fid, 'semantic_mismatch = %d\n', id.semantic_mismatch);
    fprintf(fid, '```\n\n');
    fprintf(fid, '### Trim check\n\n');
    fprintf(fid, '```\n');
    fprintf(fid, 'level: θ_phys=%+.4f deg α=%+.4f deg γ_kin=%+.4f deg\n', ...
        rad2deg(trimK.level.theta_phys), rad2deg(trimK.level.alpha), rad2deg(trimK.level.gamma_kin));
    fprintf(fid, 'XZ:    θ_phys=%+.4f deg α=%+.4f deg γ_kin=%+.4f deg (path %.4f)\n', ...
        rad2deg(trimK.climb.theta_phys), rad2deg(trimK.climb.alpha), ...
        rad2deg(trimK.climb.gamma_kin), rad2deg(trimK.climb.gamma_path_cmd));
    fprintf(fid, '```\n\n');
    fprintf(fid, '### Steady baseline→candidate (legacy|θ| / γ MAE deg, CTE m)\n\n');
    fprintf(fid, '| Route | legacy B→C | γ B→C | CTE B→C |\n');
    fprintf(fid, '|-------|-----------:|------:|--------:|\n');
    for nm = {'X', 'XZ', 'H'}
        name = nm{1};
        fprintf(fid, '| %s | %.3f→%.3f | %.3f→%.3f | %.3f→%.3f |\n', ...
            B.(name).label, ...
            B.(name).metrics.legacy_theta.steady.mae_deg, C.(name).metrics.legacy_theta.steady.mae_deg, ...
            B.(name).metrics.gamma.steady.mae_deg, C.(name).metrics.gamma.steady.mae_deg, ...
            B.(name).metrics.cte.mean, C.(name).metrics.cte.mean);
    end
    fprintf(fid, '\n### Root / next\n\n');
    fprintf(fid, '- Verdict: **%s**\n', verdict);
    fprintf(fid, '- Root: %s\n', root);
    fprintf(fid, '- Next: `%s` — %s\n', next_arch, next_detail);
    fprintf(fid, '- Production: untouched\n');
    fclose(fid);
end

function print_feedback(verdict, id, trimK, B, C, root, next_arch, next_detail, md, mat, png)
    fprintf('\n----- FEEDBACK -----\n');
    fprintf('PASS/FAIL: %s\n', verdict);
    fprintf('Identity: pitch_ref→θ_phys tracker; guidance γ-like; climbFF γ:=pitch_ref; mismatch=%d\n', ...
        id.semantic_mismatch);
    fprintf('Trim: L θ=%+.3f α=%+.3f | XZ θ=%+.3f α=%+.3f γ=%+.3f\n', ...
        rad2deg(trimK.level.theta_phys), rad2deg(trimK.level.alpha), ...
        rad2deg(trimK.climb.theta_phys), rad2deg(trimK.climb.alpha), ...
        rad2deg(trimK.climb.gamma_kin));
    fprintf('Cand legacy|θ|/γ MAE°: X %.3f/%.3f | XZ %.3f/%.3f | R10 %.3f/%.3f\n', ...
        C.X.metrics.legacy_theta.steady.mae_deg, C.X.metrics.gamma.steady.mae_deg, ...
        C.XZ.metrics.legacy_theta.steady.mae_deg, C.XZ.metrics.gamma.steady.mae_deg, ...
        C.H.metrics.legacy_theta.steady.mae_deg, C.H.metrics.gamma.steady.mae_deg);
    fprintf('Root: %s\n', root);
    fprintf('Files: %s\n%s\n%s\n', md, mat, png);
    fprintf('Next: %s\n%s\n', next_arch, next_detail);
end

function print_route_summary(lbl, Bb, Cc)
    fprintf('  %s u %.3f→%.3f | legacy|θ| %.3f→%.3f | γ %.3f→%.3f | CTE %.3f→%.3f | α %.2f→%.2f | residRMS %.3f→%.3f\n', ...
        lbl, Bb.metrics.u.mean, Cc.metrics.u.mean, ...
        Bb.metrics.legacy_theta.steady.mae_deg, Cc.metrics.legacy_theta.steady.mae_deg, ...
        Bb.metrics.gamma.steady.mae_deg, Cc.metrics.gamma.steady.mae_deg, ...
        Bb.metrics.cte.mean, Cc.metrics.cte.mean, ...
        Bb.metrics.alpha.signed_mean_deg, Cc.metrics.alpha.signed_mean_deg, ...
        Bb.metrics.resid.rms_deg, Cc.metrics.resid.rms_deg);
end

function s = yn(tf)
    if tf; s = 'YES'; else; s = 'NO'; end
end

function p = local_prctile(x, q)
    x = sort(x(:));
    if isempty(x); p = NaN; return; end
    k = max(1, min(numel(x), round(q / 100 * numel(x))));
    p = x(k);
end

function y = rms_safe(x)
    x = x(isfinite(x));
    if isempty(x); y = NaN; else; y = sqrt(mean(x.^2)); end
end
