function run_trim_alpha_schedule_id()
% TRIM_ALPHA_SCHEDULE_ID_001 — physics-informed alpha_ff schedule from
% exact level/XZ trims; validate on steady A04 logs (R10 held-out).
% Read-only: THRUST_TRIM_U15_AUDIT.mat, ALPHA_DEPTH_P_BACKOFF.mat,
%   SPEED_AWARE_ROLL_COUPLING_AUDIT.mat.
% One MATLAB invocation; no controller simulation/tuning; production untouched.
% Form (only): alpha_ff = c0/max(u_ref,u_min)^2 + c_gamma*gamma_path  [rad]
%   clamp +/-8 deg; u_min=0.9 FIXED; c0,c_gamma DERIVED from level+XZ trims.
% Artifacts: suite_results/TRIM_ALPHA_SCHEDULE_ID.{md,mat,png}

    project_dir = fileparts(fileparts(fileparts(mfilename('fullpath')))); % repo root
    addpath(genpath(fullfile(project_dir, 'matlab')));
    out_dir = fullfile(project_dir, 'suite_results');
    if ~exist(out_dir, 'dir'); mkdir(out_dir); end
    tag = 'TRIM_ALPHA_SCHEDULE_ID';
    task_id = 'TRIM_ALPHA_SCHEDULE_ID_001';

    thrust_path = fullfile(out_dir, 'THRUST_TRIM_U15_AUDIT.mat');
    alpha_path  = fullfile(out_dir, 'ALPHA_DEPTH_P_BACKOFF.mat');
    roll_path   = fullfile(out_dir, 'SPEED_AWARE_ROLL_COUPLING_AUDIT.mat');
    assert(exist(thrust_path, 'file') == 2, 'Missing %s', thrust_path);
    assert(exist(alpha_path, 'file') == 2, 'Missing %s', alpha_path);
    assert(exist(roll_path, 'file') == 2, 'Missing %s', roll_path);

    Trim = load(thrust_path);
    A04b = load(alpha_path);
    Roll = load(roll_path);
    assert(isfield(Trim, 'level') && isfield(Trim, 'climb'), ...
        'THRUST_TRIM missing level/climb');
    assert(isfield(A04b, 'alpha_no_I_Kz04'), 'ALPHA_DEPTH_P_BACKOFF missing A04');
    A04 = A04b.alpha_no_I_Kz04;
    assert(isfield(A04, 'X') && isfield(A04, 'XZ') && isfield(A04, 'H'), ...
        'A04 missing X/XZ/H');

    fprintf('\n========== %s ==========\n', task_id);
    fprintf('Read-only: THRUST_TRIM_U15_AUDIT | ALPHA_DEPTH_P_BACKOFF | SPEED_AWARE_ROLL_COUPLING_AUDIT\n');
    fprintf('Mode: derive+cross-check schedule only (no re-sim, no tuning, production untouched)\n');
    fprintf('Prior: measured-alpha closed (3 fails); A04 clears u/γ/CTE; roll PASS/METRIC_MISMATCH\n');

    %% ---- DERIVE from exact level / XZ trims (no route labels, no R10) ----
    u_min = 0.9;                 % FIXED
    clamp_deg = 8.0;             % FIXED (scaffold)
    clamp_rad = deg2rad(clamp_deg);

    L = trim_point(Trim.level, 0.0, 'level_exact_u15');
    C = trim_point(Trim.climb, atan(0.4), 'XZ_exact_u15_gamma_atan0p4');

    % alpha_hat-frame trim targets: α* = θ_phys − γ = −atan2(w,u)
    % (replaces measured alpha_hat; NOT raw BODY AoA)
    aL = L.alpha_hat_eq;   % rad
    aC = C.alpha_hat_eq;
    uL = L.u; uC = C.u;
    gL = L.gamma_path; gC = C.gamma_path;

    % Two-point solve of alpha_ff = c0/max(u,u_min)^2 + c_gamma*gamma
    c0 = aL * max(uL, u_min)^2;                          % rad*(m/s)^2
    c_gamma = (aC - c0 / max(uC, u_min)^2) / gC;         % dimensionless

    Sched = struct();
    Sched.form = 'alpha_ff=c0/max(u_ref,u_min)^2 + c_gamma*gamma_path';
    Sched.units = struct('alpha_ff', 'rad', 'c0', 'rad*(m/s)^2', ...
        'c_gamma', '1 (rad/rad)', 'u_ref', 'm/s', 'gamma_path', 'rad', ...
        'u_min', 'm/s', 'clamp', 'rad');
    Sched.c0 = c0;
    Sched.c_gamma = c_gamma;
    Sched.u_min = u_min;
    Sched.clamp_rad = clamp_rad;
    Sched.clamp_deg = clamp_deg;
    Sched.provenance = struct( ...
        'c0', 'DERIVED: alpha_L_hat * max(u_L,u_min)^2 from level exact-u trim', ...
        'c_gamma', 'DERIVED: (alpha_XZ_hat - c0/max(u_XZ,u_min)^2)/gamma_XZ from XZ exact-u trim', ...
        'u_min', 'FIXED=0.9', ...
        'clamp', 'FIXED=+/-8deg (alpha_hat scaffold)', ...
        'fit_sources', 'THRUST_TRIM_U15 level+climb only; R10 NOT used (no leakage)', ...
        'alpha_def', 'alpha_hat-frame α*=θ_phys-γ=-atan2(w,u) at trim');
    Sched.trim_level = L;
    Sched.trim_climb = C;

    % Exact recovery cross-check at trim points
    pred_L = eval_alpha_ff(uL, gL, Sched);
    pred_C = eval_alpha_ff(uC, gC, Sched);
    xchk = struct();
    xchk.level_err_deg = rad2deg(wrapToPiLocal(pred_L - aL));
    xchk.climb_err_deg = rad2deg(wrapToPiLocal(pred_C - aC));
    xchk.level_ok = abs(xchk.level_err_deg) < 1e-9;
    xchk.climb_ok = abs(xchk.climb_err_deg) < 1e-9;
    Sched.crosscheck = xchk;

    fprintf('\n-- Schedule (DERIVED) --\n');
    fprintf('  alpha_ff = c0/max(u_ref,u_min)^2 + c_gamma*gamma_path  [rad], clamp +/-%.0f deg\n', clamp_deg);
    fprintf('  c0      = %+.10e  [rad*(m/s)^2]  (= %.6f deg*(m/s)^2)\n', c0, rad2deg(c0));
    fprintf('  c_gamma = %+.10e  [-]             (= %.6f deg/deg)\n', c_gamma, c_gamma);
    fprintf('  u_min   = %.1f FIXED\n', u_min);
    fprintf('  Trim L: u=%.6f γ=%.4f° α_hat*=%+.4f° (BODY α=%+.4f°)\n', ...
        uL, rad2deg(gL), rad2deg(aL), rad2deg(L.alpha_body));
    fprintf('  Trim XZ:u=%.6f γ=%.4f° α_hat*=%+.4f° (BODY α=%+.4f°)\n', ...
        uC, rad2deg(gC), rad2deg(aC), rad2deg(C.alpha_body));
    fprintf('  Cross-check recover: level err=%.3e deg  XZ err=%.3e deg\n', ...
        xchk.level_err_deg, xchk.climb_err_deg);

    %% ---- Validate on steady A04 logs (R10 held-out) ----
    Val = struct();
    Val.X  = validate_case(A04.X,  Sched, 'X',  'alpha_logged');
    Val.XZ = validate_case(A04.XZ, Sched, 'XZ', 'alpha_logged');
    Val.R10 = validate_case(A04.H, Sched, 'R10', 'theta_phys_minus_gamma_act');

    fprintf('\n-- Validation (steady A04; R10 held-out) --\n');
    print_val_row(Val.X);
    print_val_row(Val.XZ);
    print_val_row(Val.R10);

    %% ---- Sensitivity +/-0.1 m/s on u_ref ----
    Sens = struct();
    Sens.du = 0.1;
    for nm = {'X', 'XZ', 'R10'}
        key = nm{1};
        if strcmp(key, 'R10'); src = Val.R10; else; src = Val.(key); end
        Sens.(key) = sens_u(src, Sched, Sens.du);
        fprintf('  Sens %s: MAE@u %+0.1f/%+0.1f = %.4f / %.4f deg (base %.4f)\n', ...
            key, -Sens.du, +Sens.du, Sens.(key).mae_m_deg, Sens.(key).mae_p_deg, src.err.mae_deg);
    end

    %% ---- Gates / verdict ----
    RollNote = struct();
    if isfield(Roll, 'verdict'); RollNote.verdict = char(string(Roll.verdict)); else; RollNote.verdict = '?'; end
    if isfield(Roll, 'class_label'); RollNote.class_label = char(string(Roll.class_label)); else; RollNote.class_label = '?'; end
    if isfield(Roll, 'next_opt'); RollNote.next_opt = char(string(Roll.next_opt)); else; RollNote.next_opt = ''; end

    [verdict, next_opt, next_detail, gates] = decide(Val, Sched, xchk, Sens);

    fprintf('\nVERDICT=%s | next=%s\n', verdict, next_opt);

    md_path  = fullfile(out_dir, [tag '.md']);
    mat_path = fullfile(out_dir, [tag '.mat']);
    png_path = fullfile(out_dir, [tag '.png']);

    write_png(png_path, Val, Sens, Sched, task_id, verdict);
    write_md(md_path, task_id, verdict, next_opt, next_detail, gates, ...
        Sched, Val, Sens, xchk, RollNote, ...
        thrust_path, alpha_path, roll_path, md_path, mat_path, png_path);
    append_ss_audit(out_dir, task_id, verdict, next_opt, next_detail, gates, ...
        Sched, Val, Sens, md_path, mat_path, png_path);

    Out = struct();
    Out.task_id = task_id;
    Out.verdict = verdict;
    Out.next_opt = next_opt;
    Out.next_detail = next_detail;
    Out.gates = gates;
    Out.schedule = Sched;
    Out.validation = Val;
    Out.sensitivity = Sens;
    Out.crosscheck = xchk;
    Out.roll_prior = RollNote;
    Out.sources = {thrust_path; alpha_path; roll_path};
    Out.paths = struct('md', md_path, 'mat', mat_path, 'png', png_path);
    Out.production_edited = false;
    Out.note = ['Physics-informed alpha_ff from exact level/XZ trims only; ', ...
        'R10 held-out; no controller sim/tune; production untouched'];
    save(mat_path, '-struct', 'Out');

    print_feedback(verdict, next_opt, next_detail, Sched, Val, Sens, gates, ...
        md_path, mat_path, png_path);
    assignin('base', 'TRIM_ALPHA_SCHEDULE_ID_PASS', strcmp(verdict, 'PASS'));
end

%% ===================== trim / schedule =====================
function P = trim_point(T, gamma_path, name)
    u = T.x_star(7); w = T.x_star(9); theta = T.x_star(5);
    theta_phys = -theta;
    alpha_body = atan2(w, u);
    alpha_hat_eq = theta_phys - gamma_path;   % = -alpha_body at exact phi=0,v=0
    % Cross-check kinematic identity
    kin_err = wrapToPiLocal(alpha_hat_eq + alpha_body);
    P = struct();
    P.name = name;
    P.u = u; P.w = w; P.theta = theta; P.theta_phys = theta_phys;
    P.gamma_path = gamma_path;
    P.alpha_body = alpha_body;
    P.alpha_hat_eq = alpha_hat_eq;
    P.kin_err_deg = rad2deg(kin_err);
    P.Treq = T.Treq;
    P.pass = logical(T.pass);
    P.provenance = 'PLANT_SOLVE exact-u THRUST_TRIM_U15';
end

function a = eval_alpha_ff(u_ref, gamma_path, Sched)
    u_ref = u_ref(:); gamma_path = gamma_path(:);
    a = Sched.c0 ./ max(u_ref, Sched.u_min).^2 + Sched.c_gamma .* gamma_path;
    a = max(-Sched.clamp_rad, min(Sched.clamp_rad, a));
end

%% ===================== validation =====================
function V = validate_case(HM, Sched, label, truth_mode)
    S = HM.S; M = HM.M;
    t = S.t(:);
    u = S.u_body(:); w = S.w_body(:);
    theta = S.ori(:, 2);
    theta_phys = -theta;
    u_ref = S.u_ref(:);

    % gamma_path: prefer guidance log; else path gamma_ref from metrics
    if isfield(S, 'gamma_path_guid') && ~isempty(S.gamma_path_guid)
        gamma_path = S.gamma_path_guid(:);
    else
        gamma_path = M.ts.gamma_ref(:);
    end

    % Reconstruct gamma_act / logged alpha
    phi = S.ori(:, 1); psi = S.ori(:, 3); v = S.v_body(:);
    [~, ~, VD, Uh] = ned_velocity(phi, theta, psi, u, v, w);
    gamma_act = atan2(VD, max(Uh, 1e-9));
    alpha_body = atan2(w, u);
    alpha_logged_hat = -alpha_body;                 % logged BODY α → hat frame
    alpha_eff = wrapToPiLocal(theta_phys - gamma_act);

    if strcmp(truth_mode, 'alpha_logged')
        measured = alpha_logged_hat;
        truth_name = 'logged -atan2(w,u) [alpha_hat frame]';
    else
        measured = alpha_eff;
        truth_name = 'theta_phys - gamma_act';
    end

    mask = logical(M.mask_ss(:));
    if ~any(mask)
        mask = (t >= 5.0) & (t <= 0.88 * t(end));
    end
    % Prefer speed-hold window when available (steady exact-u regime)
    if isfield(M, 'mask_hold') && any(M.mask_hold(:))
        mask = logical(M.mask_hold(:));
    end

    pred = eval_alpha_ff(u_ref, gamma_path, Sched);
    err = wrapToPiLocal(pred - measured);

    V = struct();
    V.label = label;
    V.truth_mode = truth_mode;
    V.truth_name = truth_name;
    V.held_out = strcmp(label, 'R10');
    V.t = t; V.mask = mask;
    V.u_ref = u_ref; V.u_body = u; V.gamma_path = gamma_path;
    V.gamma_act = gamma_act; V.theta_phys = theta_phys;
    V.alpha_body = alpha_body; V.measured = measured; V.pred = pred; V.err = [];
    V.n_ss = nnz(mask);
    V.err = err_stats(err, mask);
    V.meas_stats = err_stats(measured, mask);
    V.pred_stats = err_stats(pred, mask);
    V.u_ref_mean = mean(u_ref(mask));
    V.gamma_mean_deg = rad2deg(mean(gamma_path(mask)));
    V.sign_ok = sign_agree(pred(mask), measured(mask));
    V.bounded = all(abs(pred) <= Sched.clamp_rad + 1e-12);
    V.continuous_form = true;  % rational continuous in (u_ref,gamma) for u_ref>0
end

function S = sens_u(V, Sched, du)
    mask = V.mask;
    pred_m = eval_alpha_ff(V.u_ref - du, V.gamma_path, Sched);
    pred_p = eval_alpha_ff(V.u_ref + du, V.gamma_path, Sched);
    err_m = wrapToPiLocal(pred_m - V.measured);
    err_p = wrapToPiLocal(pred_p - V.measured);
    em = err_stats(err_m, mask);
    ep = err_stats(err_p, mask);
    S = struct('du', du, ...
        'mae_m_deg', em.mae_deg, 'mae_p_deg', ep.mae_deg, ...
        'p95_m_deg', em.p95_deg, 'p95_p_deg', ep.p95_deg, ...
        'signed_m_deg', em.signed_mean_deg, 'signed_p_deg', ep.signed_mean_deg, ...
        'd_mae_m', em.mae_deg - V.err.mae_deg, ...
        'd_mae_p', ep.mae_deg - V.err.mae_deg);
end

function [verdict, next_opt, next_detail, G] = decide(Val, Sched, xchk, Sens)
    G = struct();
    G.no_r10_leakage = true;   % fit used only level+XZ trims
    G.crosscheck_ok = xchk.level_ok && xchk.climb_ok;
    G.form_ok = true;
    G.u_min_fixed = (Sched.u_min == 0.9);
    G.clamp_ok = (Sched.clamp_deg == 8.0);
    G.bounded = Val.X.bounded && Val.XZ.bounded && Val.R10.bounded;
    G.continuous = Val.X.continuous_form;

    G.X_mae_ok  = Val.X.err.mae_deg  <= 0.20;
    G.XZ_mae_ok = Val.XZ.err.mae_deg <= 0.20;
    G.R10_mae_ok = Val.R10.err.mae_deg <= 0.35;
    G.R10_p95_ok = Val.R10.err.p95_deg <= 0.50;
    G.X_sign_ok = Val.X.sign_ok;
    G.XZ_sign_ok = Val.XZ.sign_ok;
    G.R10_sign_ok = Val.R10.sign_ok;
    G.sign_ok = G.X_sign_ok && G.XZ_sign_ok && G.R10_sign_ok;

    G.X_XZ_mae_ok = G.X_mae_ok && G.XZ_mae_ok;
    G.all_metric_ok = G.X_XZ_mae_ok && G.R10_mae_ok && G.R10_p95_ok && G.sign_ok ...
        && G.bounded && G.continuous && G.no_r10_leakage && G.crosscheck_ok;

    % Sensitivity report (informational; not a hard gate)
    G.sens_du = Sens.du;
    G.sens_X_dmae = [Sens.X.d_mae_m, Sens.X.d_mae_p];
    G.sens_XZ_dmae = [Sens.XZ.d_mae_m, Sens.XZ.d_mae_p];
    G.sens_R10_dmae = [Sens.R10.d_mae_m, Sens.R10.d_mae_p];

    if G.all_metric_ok
        verdict = 'PASS';
        next_opt = 'integrate_trim_alpha_ff_replace_measured_ahat';
        next_detail = sprintf(['PASS: X/XZ MAE=%.3f/%.3f<=0.20; R10 MAE=%.3f<=0.35 p95=%.3f<=0.50; ', ...
            'sign OK; continuous/bounded; no R10 leakage. ', ...
            'Next: replace measured alpha_hat with this alpha_ff schedule (no LPF); ', ...
            'watch elevator-rate on acquisition.'], ...
            Val.X.err.mae_deg, Val.XZ.err.mae_deg, Val.R10.err.mae_deg, Val.R10.err.p95_deg);
    else
        verdict = 'FAIL';
        next_opt = 'outer_gamma_loop_or_INDI';
        reasons = {};
        if ~G.X_mae_ok;  reasons{end+1} = sprintf('X MAE=%.3f>0.20', Val.X.err.mae_deg); end %#ok<*AGROW>
        if ~G.XZ_mae_ok; reasons{end+1} = sprintf('XZ MAE=%.3f>0.20', Val.XZ.err.mae_deg); end
        if ~G.R10_mae_ok; reasons{end+1} = sprintf('R10 MAE=%.3f>0.35', Val.R10.err.mae_deg); end
        if ~G.R10_p95_ok; reasons{end+1} = sprintf('R10 p95=%.3f>0.50', Val.R10.err.p95_deg); end
        if ~G.sign_ok; reasons{end+1} = 'sign mismatch'; end
        if ~G.bounded; reasons{end+1} = 'unbounded'; end
        if ~G.crosscheck_ok; reasons{end+1} = 'trim cross-check fail'; end
        next_detail = ['FAIL: schedule does not meet gates (' strjoin(reasons, '; ') '). ', ...
            'Select next method: outer gamma loop / INDI. Production untouched.'];
    end
end

%% ===================== I/O =====================
function write_png(png_path, Val, Sens, Sched, task_id, verdict)
    fig = figure('Visible', 'off', 'Color', 'w', 'Position', [30 30 1500 1000]);
    cases = {Val.X, Val.XZ, Val.R10};
    for i = 1:3
        V = cases{i};
        % predicted / measured vs time
        subplot(3, 3, i); hold on; grid on;
        plot(V.t, rad2deg(V.measured), 'k-', 'LineWidth', 0.8);
        plot(V.t, rad2deg(V.pred), 'r-', 'LineWidth', 1.1);
        if any(V.mask)
            yl = ylim;
            idx = find(V.mask);
            patch([V.t(idx(1)) V.t(idx(end)) V.t(idx(end)) V.t(idx(1))], ...
                [yl(1) yl(1) yl(2) yl(2)], [0.9 0.95 1], ...
                'EdgeColor', 'none', 'FaceAlpha', 0.25);
            plot(V.t, rad2deg(V.measured), 'k-', 'LineWidth', 0.8);
            plot(V.t, rad2deg(V.pred), 'r-', 'LineWidth', 1.1);
        end
        ylabel('\alpha [deg]');
        title(sprintf('%s pred/meas  MAE=%.3f°', V.label, V.err.mae_deg));
        if i == 1; legend({'meas','\\alpha_{ff}'}, 'Location', 'best'); end
        if i == 2; xlabel('t [s]'); end
    end

    % residual vs time (steady only)
    for i = 1:3
        V = cases{i};
        subplot(3, 3, 3 + i); hold on; grid on;
        e = rad2deg(wrapToPiLocal(V.pred - V.measured));
        plot(V.t, e, 'b-', 'LineWidth', 0.7);
        yline(0, 'k:');
        if any(V.mask)
            plot(V.t(V.mask), e(V.mask), 'r.', 'MarkerSize', 4);
        end
        ylabel('e [deg]');
        title(sprintf('%s resid  p95=%.3f°', V.label, V.err.p95_deg));
        if i == 2; xlabel('t [s]'); end
    end

    % u/gamma residual map (combined steady samples)
    subplot(3, 3, 7); hold on; grid on;
    colors = [0 0.45 0.74; 0.85 0.33 0.1; 0.47 0.67 0.19];
    for i = 1:3
        V = cases{i}; m = V.mask;
        scatter(V.u_ref(m), rad2deg(V.gamma_path(m)), 12, rad2deg(wrapToPiLocal(V.pred(m)-V.measured(m))), 'filled');
    end
    cb = colorbar; ylabel(cb, 'resid [deg]');
    xlabel('u_{ref} [m/s]'); ylabel('\gamma_{path} [deg]');
    title('u/\gamma residual map (steady)');

    subplot(3, 3, 8); hold on; grid on;
    for i = 1:3
        V = cases{i}; m = V.mask;
        plot(V.u_ref(m), rad2deg(wrapToPiLocal(V.pred(m)-V.measured(m))), '.', ...
            'Color', colors(i,:), 'MarkerSize', 8);
    end
    yline(0, 'k:');
    xlabel('u_{ref} [m/s]'); ylabel('resid [deg]');
    title(sprintf('resid vs u  (sens \\pm%.1f m/s)', Sens.du));
    legend({'X','XZ','R10'}, 'Location', 'best');

    subplot(3, 3, 9); axis off;
    txt = {task_id, ...
        sprintf('VERDICT: %s', verdict), ...
        sprintf('c0=%.6e rad(m/s)^2', Sched.c0), ...
        sprintf('c_gamma=%.6e', Sched.c_gamma), ...
        sprintf('u_min=%.1f FIXED | clamp=\\pm%.0fdeg', Sched.u_min, Sched.clamp_deg), ...
        sprintf('X MAE=%.3f  XZ MAE=%.3f  R10 MAE=%.3f p95=%.3f', ...
            Val.X.err.mae_deg, Val.XZ.err.mae_deg, Val.R10.err.mae_deg, Val.R10.err.p95_deg), ...
        sprintf('Sens R10 dMAE @\\pm0.1: %+.3f / %+.3f deg', Sens.R10.d_mae_m, Sens.R10.d_mae_p), ...
        'Fit: level+XZ exact trims only (R10 held-out)'};
    text(0.02, 0.98, txt, 'VerticalAlignment', 'top', 'FontName', 'FixedWidth', 'FontSize', 10);

    sgtitle(sprintf('%s — \\alpha_{ff} schedule vs A04 steady', task_id), 'Interpreter', 'tex');
    exportgraphics(fig, png_path, 'Resolution', 140);
    close(fig);
end

function write_md(md_path, task_id, verdict, next_opt, next_detail, G, ...
        Sched, Val, Sens, xchk, RollNote, ...
        thrust_path, alpha_path, roll_path, md_out, mat_out, png_out)
    fid = fopen(md_path, 'w');
    assert(fid > 0, 'Cannot write %s', md_path);
    fprintf(fid, '# %s — Physics-informed trim alpha_ff schedule\n\n', task_id);
    fprintf(fid, '**Overall verdict: %s**\n\n', verdict);

    fprintf(fid, '## Provenance\n\n');
    fprintf(fid, '- Read-only: `%s`, `%s`, `%s`\n', thrust_path, alpha_path, roll_path);
    fprintf(fid, '- Driver: `run_trim_alpha_schedule_id.m` (one invocation)\n');
    fprintf(fid, '- Artifacts: `%s`, `%s`, `%s`\n', md_out, mat_out, png_out);
    fprintf(fid, '- Production: untouched | No controller simulation/tuning\n');
    fprintf(fid, '- Prior state: measured-alpha closed (3 fails). A04 clears speed/γ/CTE; ');
    fprintf(fid, 'roll audit **%s/%s** (own-eq ripple improves; frozen φ_eq invalid across speeds).\n', ...
        RollNote.verdict, RollNote.class_label);
    fprintf(fid, '- Remaining prior concerns: alpha-LPF acquisition/settling, elevator-rate.\n\n');

    fprintf(fid, '## Equation / coefficients / units\n\n');
    fprintf(fid, '```\n');
    fprintf(fid, 'alpha_ff = c0 / max(u_ref, u_min)^2 + c_gamma * gamma_path   [rad]\n');
    fprintf(fid, 'clamp(alpha_ff, +/-%.0f deg)\n', Sched.clamp_deg);
    fprintf(fid, 'c0      = %+.10e  [rad*(m/s)^2]   provenance: %s\n', Sched.c0, Sched.provenance.c0);
    fprintf(fid, 'c_gamma = %+.10e  [-]              provenance: %s\n', Sched.c_gamma, Sched.provenance.c_gamma);
    fprintf(fid, 'u_min   = %.1f                   provenance: %s\n', Sched.u_min, Sched.provenance.u_min);
    fprintf(fid, 'clamp   = +/-%.0f deg               provenance: %s\n', Sched.clamp_deg, Sched.provenance.clamp);
    fprintf(fid, 'alpha frame: alpha_hat (θ_phys−γ); replaces measured alpha_hat\n');
    fprintf(fid, '```\n\n');

    fprintf(fid, '### Trim anchors (fit only; no route labels)\n\n');
    fprintf(fid, '| Point | u* [m/s] | γ_path [deg] | BODY α=atan2(w,u) [deg] | α_hat*=θ−γ [deg] | Treq [N] |\n');
    fprintf(fid, '|-------|---------:|-------------:|------------------------:|-----------------:|---------:|\n');
    L = Sched.trim_level; C = Sched.trim_climb;
    fprintf(fid, '| level_exact_u15 | %.6f | %.4f | %+.4f | %+.4f | %.6f |\n', ...
        L.u, rad2deg(L.gamma_path), rad2deg(L.alpha_body), rad2deg(L.alpha_hat_eq), L.Treq);
    fprintf(fid, '| XZ_exact_u15 | %.6f | %.4f | %+.4f | %+.4f | %.6f |\n\n', ...
        C.u, rad2deg(C.gamma_path), rad2deg(C.alpha_body), rad2deg(C.alpha_hat_eq), C.Treq);
    fprintf(fid, 'Cross-check recover: level err=%.3e deg | XZ err=%.3e deg | OK=%s\n\n', ...
        xchk.level_err_deg, xchk.climb_err_deg, yn(G.crosscheck_ok));

    fprintf(fid, '## Validation table (steady A04; R10 held-out — no fit leakage)\n\n');
    fprintf(fid, '| Series | Truth | n | u_ref mean | γ mean° | signed mean° | MAE° | p95° | max° | sign | gate |\n');
    fprintf(fid, '|--------|-------|--:|----------:|--------:|-------------:|-----:|-----:|-----:|:----:|:----:|\n');
    write_val_row(fid, Val.X,  G.X_mae_ok);
    write_val_row(fid, Val.XZ, G.XZ_mae_ok);
    write_val_row(fid, Val.R10, G.R10_mae_ok && G.R10_p95_ok);
    fprintf(fid, '\nGates: X/XZ MAE≤0.20 | R10 MAE≤0.35 & p95≤0.50 | correct sign | continuous/bounded | no R10 leakage.\n\n');

    fprintf(fid, '## Sensitivity (±%.1f m/s on u_ref)\n\n', Sens.du);
    fprintf(fid, '| Series | MAE base° | MAE@−du° | MAE@+du° | ΔMAE− | ΔMAE+ |\n');
    fprintf(fid, '|--------|----------:|---------:|---------:|------:|------:|\n');
    for nm = {'X','XZ','R10'}
        key = nm{1};
        if strcmp(key,'R10'); V = Val.R10; else; V = Val.(key); end
        S = Sens.(key);
        fprintf(fid, '| %s | %.4f | %.4f | %.4f | %+.4f | %+.4f |\n', ...
            key, V.err.mae_deg, S.mae_m_deg, S.mae_p_deg, S.d_mae_m, S.d_mae_p);
    end

    fprintf(fid, '\n## Gate table\n\n');
    fprintf(fid, '| Gate | Result | Detail |\n');
    fprintf(fid, '|------|:------:|--------|\n');
    fprintf(fid, '| X MAE ≤ 0.20 deg | %s | %.4f |\n', yn(G.X_mae_ok), Val.X.err.mae_deg);
    fprintf(fid, '| XZ MAE ≤ 0.20 deg | %s | %.4f |\n', yn(G.XZ_mae_ok), Val.XZ.err.mae_deg);
    fprintf(fid, '| R10 MAE ≤ 0.35 deg | %s | %.4f |\n', yn(G.R10_mae_ok), Val.R10.err.mae_deg);
    fprintf(fid, '| R10 p95 ≤ 0.50 deg | %s | %.4f |\n', yn(G.R10_p95_ok), Val.R10.err.p95_deg);
    fprintf(fid, '| Correct sign (X/XZ/R10) | %s | %s/%s/%s |\n', yn(G.sign_ok), ...
        yn(G.X_sign_ok), yn(G.XZ_sign_ok), yn(G.R10_sign_ok));
    fprintf(fid, '| Continuous / bounded | %s | clamp ±%.0f deg |\n', yn(G.continuous && G.bounded), Sched.clamp_deg);
    fprintf(fid, '| No R10 leakage into fit | %s | level+XZ trims only |\n', yn(G.no_r10_leakage));
    fprintf(fid, '| Trim cross-check | %s | recover α* |\n\n', yn(G.crosscheck_ok));

    fprintf(fid, '## Decision\n\n');
    fprintf(fid, '- Verdict: **%s**\n', verdict);
    fprintf(fid, '- Next: `%s`\n', next_opt);
    fprintf(fid, '- Detail: %s\n', next_detail);
    fprintf(fid, '- Production: untouched\n\n');

    fprintf(fid, '## Feedback\n\n');
    fprintf(fid, '- PASS/FAIL: **%s**\n', verdict);
    fprintf(fid, '- Equation: `alpha_ff=c0/max(u_ref,u_min)^2+c_gamma*gamma_path` [rad], clamp ±%.0f°\n', Sched.clamp_deg);
    fprintf(fid, '- Coefficients: c0=%+.10e [rad*(m/s)^2] (DERIVED level); c_gamma=%+.10e (DERIVED XZ); u_min=%.1f FIXED\n', ...
        Sched.c0, Sched.c_gamma, Sched.u_min);
    fprintf(fid, '- Validation: X MAE=%.4f signed=%.4f | XZ MAE=%.4f signed=%.4f | R10 MAE=%.4f p95=%.4f max=%.4f\n', ...
        Val.X.err.mae_deg, Val.X.err.signed_mean_deg, ...
        Val.XZ.err.mae_deg, Val.XZ.err.signed_mean_deg, ...
        Val.R10.err.mae_deg, Val.R10.err.p95_deg, Val.R10.err.max_deg);
    fprintf(fid, '- Evidence: trim recover OK; R10 held-out; sens R10 ΔMAE@±0.1=%+.3f/%+.3f°\n', ...
        Sens.R10.d_mae_m, Sens.R10.d_mae_p);
    fprintf(fid, '- Next: `%s`\n', next_opt);
    fprintf(fid, '- Files: `%s` `%s` `%s`\n', md_out, mat_out, png_out);
    fclose(fid);
end

function write_val_row(fid, V, gate_ok)
    fprintf(fid, '| %s | %s | %d | %.4f | %.3f | %+.4f | %.4f | %.4f | %.4f | %s | %s |\n', ...
        V.label, V.truth_name, V.n_ss, V.u_ref_mean, V.gamma_mean_deg, ...
        V.err.signed_mean_deg, V.err.mae_deg, V.err.p95_deg, V.err.max_deg, ...
        yn(V.sign_ok), yn(gate_ok));
end

function append_ss_audit(out_dir, task_id, verdict, next_opt, next_detail, G, ...
        Sched, Val, Sens, md_path, mat_path, png_path)
    ss_path = fullfile(out_dir, 'STATE_SPACE_MODEL_AUDIT.md');
    fid = fopen(ss_path, 'a');
    assert(fid > 0, 'Cannot append %s', ss_path);
    fprintf(fid, '\n---\n\n');
    fprintf(fid, '## %s — %s\n\n', task_id, datestr(now, 31));
    fprintf(fid, '### Provenance\n\n');
    fprintf(fid, '- Read-only: `THRUST_TRIM_U15_AUDIT.mat`, `ALPHA_DEPTH_P_BACKOFF.mat`, `SPEED_AWARE_ROLL_COUPLING_AUDIT.mat`\n');
    fprintf(fid, '- Driver: `run_trim_alpha_schedule_id.m` (one invocation; production untouched)\n');
    fprintf(fid, '- Artifacts: `%s`, `%s`, `%s`\n\n', md_path, mat_path, png_path);
    fprintf(fid, '### Equation / coefficients\n\n');
    fprintf(fid, '```\n');
    fprintf(fid, 'alpha_ff=c0/max(u_ref,u_min)^2 + c_gamma*gamma_path  [rad], clamp +/-8deg\n');
    fprintf(fid, 'c0=%+.10e [rad*(m/s)^2] DERIVED level α_hat*·u*^2\n', Sched.c0);
    fprintf(fid, 'c_gamma=%+.10e DERIVED (α_XZ*-α_L*)/γ_XZ\n', Sched.c_gamma);
    fprintf(fid, 'u_min=0.9 FIXED; R10 not in fit\n');
    fprintf(fid, '```\n\n');
    fprintf(fid, '### Validation (A04 steady)\n\n');
    fprintf(fid, '| Series | signed° | MAE° | p95° | max° |\n');
    fprintf(fid, '|--------|--------:|-----:|-----:|-----:|\n');
    fprintf(fid, '| X | %+.4f | %.4f | %.4f | %.4f |\n', ...
        Val.X.err.signed_mean_deg, Val.X.err.mae_deg, Val.X.err.p95_deg, Val.X.err.max_deg);
    fprintf(fid, '| XZ | %+.4f | %.4f | %.4f | %.4f |\n', ...
        Val.XZ.err.signed_mean_deg, Val.XZ.err.mae_deg, Val.XZ.err.p95_deg, Val.XZ.err.max_deg);
    fprintf(fid, '| R10 (held-out) | %+.4f | %.4f | %.4f | %.4f |\n\n', ...
        Val.R10.err.signed_mean_deg, Val.R10.err.mae_deg, Val.R10.err.p95_deg, Val.R10.err.max_deg);
    fprintf(fid, '### Verdict / next\n\n');
    fprintf(fid, '- Verdict: **%s**\n', verdict);
    fprintf(fid, '- Gates X/XZ/R10mae/R10p95/sign/bound/leak: %s/%s/%s/%s/%s/%s/%s\n', ...
        yn(G.X_mae_ok), yn(G.XZ_mae_ok), yn(G.R10_mae_ok), yn(G.R10_p95_ok), ...
        yn(G.sign_ok), yn(G.bounded), yn(G.no_r10_leakage));
    fprintf(fid, '- Sens R10 ΔMAE@±0.1 m/s: %+.3f / %+.3f deg\n', Sens.R10.d_mae_m, Sens.R10.d_mae_p);
    fprintf(fid, '- Next: `%s` — %s\n', next_opt, next_detail);
    fprintf(fid, '- Production: untouched\n\n');
    fprintf(fid, '### Next\n\n');
    fprintf(fid, '- %s\n', next_opt);
    fclose(fid);
end

function print_feedback(verdict, next_opt, next_detail, Sched, Val, Sens, G, ...
        md_path, mat_path, png_path)
    fprintf('\n======== FEEDBACK ========\n');
    fprintf('PASS/FAIL: %s\n', verdict);
    fprintf('Equation: alpha_ff=c0/max(u_ref,u_min)^2 + c_gamma*gamma_path [rad], clamp +/-%.0fdeg\n', ...
        Sched.clamp_deg);
    fprintf('c0=%+.10e [rad*(m/s)^2] DERIVED | c_gamma=%+.10e DERIVED | u_min=%.1f FIXED\n', ...
        Sched.c0, Sched.c_gamma, Sched.u_min);
    fprintf('Validation:\n');
    fprintf('  X   signed=%+.4f MAE=%.4f p95=%.4f max=%.4f  (gate MAE<=0.20: %s)\n', ...
        Val.X.err.signed_mean_deg, Val.X.err.mae_deg, Val.X.err.p95_deg, Val.X.err.max_deg, yn(G.X_mae_ok));
    fprintf('  XZ  signed=%+.4f MAE=%.4f p95=%.4f max=%.4f  (gate MAE<=0.20: %s)\n', ...
        Val.XZ.err.signed_mean_deg, Val.XZ.err.mae_deg, Val.XZ.err.p95_deg, Val.XZ.err.max_deg, yn(G.XZ_mae_ok));
    fprintf('  R10 signed=%+.4f MAE=%.4f p95=%.4f max=%.4f  (MAE<=0.35 p95<=0.50: %s/%s)\n', ...
        Val.R10.err.signed_mean_deg, Val.R10.err.mae_deg, Val.R10.err.p95_deg, Val.R10.err.max_deg, ...
        yn(G.R10_mae_ok), yn(G.R10_p95_ok));
    fprintf('Sens ±0.1 m/s ΔMAE: X %+.3f/%+.3f | XZ %+.3f/%+.3f | R10 %+.3f/%+.3f\n', ...
        Sens.X.d_mae_m, Sens.X.d_mae_p, Sens.XZ.d_mae_m, Sens.XZ.d_mae_p, ...
        Sens.R10.d_mae_m, Sens.R10.d_mae_p);
    fprintf('Evidence: trim cross-check OK=%s; no R10 leakage; continuous/bounded=%s\n', ...
        yn(G.crosscheck_ok), yn(G.continuous && G.bounded));
    fprintf('Next: %s\n', next_opt);
    fprintf('Detail: %s\n', next_detail);
    fprintf('Files: %s\n%s\n%s\n', md_path, mat_path, png_path);
end

function print_val_row(V)
    fprintf('  %s: n=%d signed=%+.4f MAE=%.4f p95=%.4f max=%.4f sign=%s truth=%s\n', ...
        V.label, V.n_ss, V.err.signed_mean_deg, V.err.mae_deg, V.err.p95_deg, ...
        V.err.max_deg, yn(V.sign_ok), V.truth_name);
end

%% ===================== utilities =====================
function st = err_stats(e, mask)
    st = struct('n', 0, 'signed_mean_deg', NaN, 'mae_deg', NaN, ...
        'p95_deg', NaN, 'max_deg', NaN, 'rms_deg', NaN);
    e = e(:); mask = logical(mask(:));
    if ~any(mask); return; end
    v = e(mask); v = v(isfinite(v));
    if isempty(v); return; end
    st.n = numel(v);
    st.signed_mean_deg = rad2deg(mean(v));
    st.mae_deg = rad2deg(mean(abs(v)));
    st.rms_deg = rad2deg(sqrt(mean(v.^2)));
    st.p95_deg = rad2deg(local_prctile(abs(v), 95));
    st.max_deg = rad2deg(max(abs(v)));
end

function ok = sign_agree(pred, meas)
    pred = pred(:); meas = meas(:);
    % Require mean signs agree and majority of samples share sign (or near-zero)
    mp = mean(pred); mm = mean(meas);
    if abs(mp) < 1e-6 && abs(mm) < 1e-6
        ok = true; return;
    end
    ok = (sign(mp) == sign(mm)) || (abs(mp) < 1e-4) || (abs(mm) < 1e-4);
    both = (pred .* meas) >= 0 | (abs(pred) < 1e-4) | (abs(meas) < 1e-4);
    ok = ok && (mean(both) >= 0.90);
end

function [VN, VE, VD, Uh] = ned_velocity(phi, theta, psi, u, v, w)
    n = numel(u);
    VN = zeros(n, 1); VE = zeros(n, 1); VD = zeros(n, 1);
    for i = 1:n
        R = [cos(psi(i))*cos(theta(i)), ...
             cos(psi(i))*sin(theta(i))*sin(phi(i)) - sin(psi(i))*cos(phi(i)), ...
             cos(psi(i))*sin(theta(i))*cos(phi(i)) + sin(psi(i))*sin(phi(i)); ...
             sin(psi(i))*cos(theta(i)), ...
             sin(psi(i))*sin(theta(i))*sin(phi(i)) + cos(psi(i))*cos(phi(i)), ...
             sin(psi(i))*sin(theta(i))*cos(phi(i)) - cos(psi(i))*sin(phi(i)); ...
             -sin(theta(i)), cos(theta(i))*sin(phi(i)), cos(theta(i))*cos(phi(i))];
        vel = R * [u(i); v(i); w(i)];
        VN(i) = vel(1); VE(i) = vel(2); VD(i) = vel(3);
    end
    Uh = hypot(VN, VE);
end

function a = wrapToPiLocal(a)
    a = mod(a + pi, 2*pi) - pi;
end

function q = local_prctile(x, p)
    x = sort(x(:));
    x = x(isfinite(x));
    if isempty(x); q = NaN; return; end
    n = numel(x);
    k = max(1, min(n, round(p / 100 * n)));
    q = x(k);
end

function y = yn(tf)
    if tf; y = 'YES'; else; y = 'NO'; end
end
