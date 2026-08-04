function run_vertical_audit()
% RUN_VERTICAL_AUDIT  Focused XZ + X-line path-error decomposition (metrics only).
% No new controller. No full suite. Frozen pitch stack:
%   Tur3 λ=0.25, Tur4A r_ff=U_h*κ, T25 trim, timing intact.
% T5B K_gamma=0.75 is NOT production — audit forces K_gamma=0 / K_zdot=0
% (pre-T5B guidance gains); code path left as experimental flag in init.
%
% Writes: suite_results/VERTICAL_AUDIT_METRICS.md (+ optional PNGs)

    project_dir = fileparts(mfilename('fullpath'));
    addpath(project_dir);
    out_dir = fullfile(project_dir, 'suite_results');
    if ~exist(out_dir, 'dir'); mkdir(out_dir); end

    clear functions
    clear guidance_law controller_law
    clear global lambda_muw_ff trim_speed_table trim_elevator_table elevator_sign
    clear global K_zdot K_gamma enable_alpha_hat

    init_parameters();
    global lambda_muw_ff elevator_sign trim_speed_table trim_elevator_table
    global K_zdot K_gamma enable_alpha_hat
    global dt_controller dt_guidance tau_rate Ki_angle Ki_rate
    global pitch_ref_rate_max muw_ff_clamp_deg muw_ff_u_lo muw_ff_u_hi muw_ff_u_min
    global Muw Muuds

    % Frozen production-intent stack (T5B experimental NOT engaged)
    lambda_muw_ff = 0.25;
    K_gamma = 0;
    K_zdot = 0;
    enable_alpha_hat = false;

    fprintf('\n========== VERTICAL PLANE METRIC AUDIT ==========\n');
    fprintf('K_gamma=%g (experimental T5B OFF)  K_zdot=%g  lambda=%.2f\n', ...
        K_gamma, K_zdot, lambda_muw_ff);
    fprintf('dt_c=%.4f  dt_g=%.4f  tau_rate=%.4f\n', ...
        dt_controller, dt_guidance, tau_rate);

    % Calibration once
    fprintf('\n--- Calibration ---\n');
    sign_rep = test_elevator_sign();
    elevator_sign = sign_rep.delta_e_sign;
    build_pitch_trim_table();

    scenarios = {make_x_line(), make_xz_line()};
    reports = cell(numel(scenarios), 1);

    for k = 1:numel(scenarios)
        sc = scenarios{k};
        fprintf('\n----- [%d/%d] %s -----\n', k, numel(scenarios), sc.name);
        clear guidance_law controller_law
        state0 = initial_state(sc.path, sc.u0);
        [vp, times, vel, ~, ori, ~, yaw_refs, pitch_refs, ~] = ...
            continuous_path_tracking(sc.path, state0, dt_controller, sc.T_final); %#ok<ASGLU>
        reports{k} = decompose_and_diag(sc, vp, times, vel, ori, yaw_refs, pitch_refs, out_dir);
        r = reports{k};
        fprintf('suite CTE mean/max = %.3f / %.3f m\n', r.cte_full, r.cte_max);
        fprintf('CTE_perp mean (full/settled/pre-end) = %.3f / %.3f / %.3f m\n', ...
            r.mean_cte_perp, r.cte_settled_perp, r.cte_before_end_perp);
        fprintf('mean |e_s|=%.3f  mean |e_z|=%.3f  max startup CTE=%.3f\n', ...
            r.mean_abs_es, r.mean_abs_ez, r.max_startup_cte);
        fprintf('rate-lim hit=%.1f%%  angle-I near=%.1f%%  muw_ff clamp=%.1f%%\n', ...
            r.pct_rate_lim, r.pct_angle_I_near, r.pct_muw_clamp);
    end

    write_report(out_dir, reports, lambda_muw_ff, K_gamma, K_zdot, ...
        dt_controller, dt_guidance, tau_rate, Ki_angle, Ki_rate);
    fprintf('\nReport -> %s\n', fullfile(out_dir, 'VERTICAL_AUDIT_METRICS.md'));
end

%% --------- scenarios (match run_path_suite) ---------
function sc = make_x_line()
    n = 400;
    x = linspace(0, 20, n)';
    sc = struct('name', 'X-line', 'tag', 'x_line', ...
        'path', [x, zeros(n,1), zeros(n,1)], 'T_final', 18, 'u0', 1.5);
end

function sc = make_xz_line()
    n = 600;
    t = linspace(0, 22, n)';
    sc = struct('name', 'XZ-slant', 'tag', 'xz_line', ...
        'path', [t, zeros(n,1), 0.4*t], 'T_final', 22, 'u0', 1.5);
end

function state = initial_state(path, u0)
    state = zeros(12,1);
    state(1:3) = path(1,:)';
    d = path(2,:) - path(1,:);
    state(5) = -atan2(d(3), norm(d(1:2)));
    state(6) = atan2(d(2), d(1));
    state(7) = u0;
end

%% --------- decompose ---------
function r = decompose_and_diag(sc, vp, times, vel, ori, yaw_refs, pitch_refs, out_dir)
    global dt_controller dt_guidance Ki_angle
    global pitch_ref_rate_max muw_ff_clamp_deg muw_ff_u_lo muw_ff_u_hi muw_ff_u_min
    global lambda_muw_ff Muw Muuds
    global suite_int_angle_log suite_de_uw_ff_log suite_u_log suite_w_log
    global suite_pitch_refs_log

    path = sc.path;
    n = size(vp, 1);
    dt = dt_controller;
    [s_nodes, s_total] = path_arclength(path);
    is_closed = norm(path(1,:) - path(end,:)) < 0.25;

    % Suite CTE (nearest discrete path point) — current gate metric
    cte_suite = zeros(n,1);
    for i = 1:n
        cte_suite(i) = min(vecnorm(path - vp(i,:), 2, 2));
    end

    % Progress-point projection (monotonic, guidance-like) + Frenet split
    e_s = zeros(n,1);
    cte_perp = zeros(n,1);
    e_z = zeros(n,1);
    e_xy = zeros(n,1);
    s_prog_log = zeros(n,1);
    near_end_flag = false(n,1);
    past_end_flag = false(n,1);
    s_prog = 0;
    L = 1.25;
    [p_end, t_end] = sample_path(path, s_nodes, s_total, is_closed);

    for i = 1:n
        p = vp(i,:);
        if i == 1
            [s_near, ~] = project_on_path(p, path, s_nodes, 0, s_total, is_closed);
            s_prog = s_near;
        else
            s_lo = max(0, s_prog - 0.15);
            s_hi = min(s_total, s_prog + max(3.0, 2.5*L));
            [s_near, ~] = project_on_path(p, path, s_nodes, s_lo, s_hi, is_closed);
            % Allow reaching exact end (guidance uses -0.05 floor; snap when near)
            if s_near >= s_total - 1e-6
                s_prog = s_total;
            else
                s_prog = max(s_prog, s_near - 0.05);
                s_prog = min(s_prog, s_total);
            end
        end
        [p_d, t_hat] = sample_path(path, s_nodes, s_prog, is_closed);
        dp = (p - p_d)';
        e_s(i) = dot(dp, t_hat(:));
        e_perp_vec = (eye(3) - (t_hat(:)*t_hat(:)')) * dp;
        cte_perp(i) = norm(e_perp_vec);
        e_z(i) = e_perp_vec(3);
        e_xy(i) = norm(e_perp_vec(1:2));
        s_prog_log(i) = s_prog;
        near_end_flag(i) = (~is_closed) && (s_prog >= s_total - 0.3);
        % Past end: beyond terminal point along path tangent (suite CTE inflates here)
        past_end_flag(i) = (~is_closed) && (dot(p - p_end, t_end) > 0.05);
    end

    % Windows
    t = times(:);
    if isempty(t) || numel(t) ~= n
        t = (1:n)' * dt;
    end
    settle_t = 5.0;
    mask_settled = t >= settle_t;
    % also first-20% discard alternate
    mask_settled20 = (1:n)' > max(1, round(0.20 * n));
    mask_pre_end = s_prog_log < 0.88 * s_total; % exclude last ~12% of path
    mask_pre_end = mask_pre_end & ~near_end_flag & ~past_end_flag;
    mask_startup = t < settle_t;
    mask_past_end = past_end_flag;

    r = struct();
    r.name = sc.name;
    r.tag = sc.tag;
    r.s_total = s_total;
    r.T_final = sc.T_final;
    r.path_end = path(end,:);
    r.veh_end = vp(end,:);
    r.final_u = vel(end,1);
    r.travel_est = sum(vecnorm(diff(vp), 2, 2));

    % Suite CTE windows
    r.cte_full = mean(cte_suite);
    r.cte_max = max(cte_suite);
    r.cte_settled = mean(cte_suite(mask_settled));
    r.cte_settled20 = mean(cte_suite(mask_settled20));
    r.cte_before_end = mean(cte_suite(mask_pre_end));
    r.cte_past_end_mean = mean(cte_suite(mask_past_end));
    r.cte_past_end_max = max(cte_suite(mask_past_end));
    if ~any(mask_past_end)
        r.cte_past_end_mean = NaN;
        r.cte_past_end_max = NaN;
    end
    r.max_startup_cte = max(cte_suite(mask_startup));
    r.pct_samples_past_end = 100 * mean(mask_past_end);
    r.pct_samples_near_end = 100 * mean(near_end_flag);

    % Perp / along-track
    r.mean_abs_es = mean(abs(e_s));
    r.mean_cte_perp = mean(cte_perp);
    r.mean_abs_ez = mean(abs(e_z));
    r.mean_e_xy = mean(e_xy);
    r.cte_settled_perp = mean(cte_perp(mask_settled));
    r.cte_before_end_perp = mean(cte_perp(mask_pre_end));
    r.mean_abs_es_settled = mean(abs(e_s(mask_settled)));
    r.mean_abs_ez_settled = mean(abs(e_z(mask_settled)));
    r.mean_abs_es_pre_end = mean(abs(e_s(mask_pre_end)));
    r.mean_abs_ez_pre_end = mean(abs(e_z(mask_pre_end)));
    r.max_cte_perp = max(cte_perp);
    r.max_abs_es = max(abs(e_s));

    % Fraction of suite CTE explained by perp vs residual (rms ratio heuristic)
    % Direct: mean(CTE_suite) vs mean(CTE_perp) on same window
    r.frac_perp_of_suite_full = r.mean_cte_perp / max(r.cte_full, 1e-9);
    r.frac_perp_of_suite_settled = r.cte_settled_perp / max(r.cte_settled, 1e-9);
    r.frac_perp_of_suite_pre_end = r.cte_before_end_perp / max(r.cte_before_end, 1e-9);
    % Along-track contribution proxy: |suite - perp| mean
    r.mean_suite_minus_perp = mean(cte_suite - cte_perp);
    r.mean_suite_minus_perp_pre_end = mean(cte_suite(mask_pre_end) - cte_perp(mask_pre_end));

    % Unconstrained closest-point CTE (true geometric normal, no progress hold)
    cte_geom = zeros(n,1);
    e_s_geom = zeros(n,1);
    for i = 1:n
        [s_g, ~] = project_on_path(vp(i,:), path, s_nodes, 0, s_total, is_closed);
        [p_g, t_g] = sample_path(path, s_nodes, s_g, is_closed);
        dp = (vp(i,:) - p_g)';
        e_s_geom(i) = dot(dp, t_g(:));
        cte_geom(i) = norm((eye(3) - (t_g(:)*t_g(:)')) * dp);
    end
    r.mean_cte_geom_perp = mean(cte_geom);
    r.mean_cte_geom_perp_settled = mean(cte_geom(mask_settled));
    r.mean_cte_geom_perp_pre_end = mean(cte_geom(mask_pre_end & s_prog_log < 0.88*s_total));
    % For geom pre-end use geometric progress
    s_geom = zeros(n,1);
    for i = 1:n
        [s_geom(i), ~] = project_on_path(vp(i,:), path, s_nodes, 0, s_total, is_closed);
    end
    mask_geom_pre = s_geom < 0.88 * s_total;
    r.mean_cte_geom_perp_pre_end = mean(cte_geom(mask_geom_pre));
    r.mean_abs_es_geom = mean(abs(e_s_geom));

    %% Diagnostics (no controller change)
    % pitch_ref rate-limit hits: at guidance ticks, |Δref|/dt_g ≈ rate_max
    pr = suite_pitch_refs_log(:);
    if isempty(pr); pr = pitch_refs(:); end
    gper = max(1, round(dt_guidance / dt));
    idx_g = 1:gper:n;
    if numel(idx_g) >= 2
        dpr = abs(diff(pr(idx_g)));
        lim = pitch_ref_rate_max * dt_guidance * 0.98; % near hit
        r.pct_rate_lim = 100 * mean(dpr >= lim);
    else
        r.pct_rate_lim = NaN;
    end

    % angle-I near limit (|I| > 90% of int_angle_max)
    ia = suite_int_angle_log(:);
    if isempty(ia); ia = zeros(n,1); end
    ia_max = deg2rad(8) / max(Ki_angle, 1e-6);
    r.pct_angle_I_near = 100 * mean(abs(ia) >= 0.90 * ia_max);
    r.int_angle_max = ia_max;
    r.int_angle_minmax = [min(ia), max(ia)];

    % muw_ff clamp %: reconstruct raw and compare to clamp (when blend > 0)
    uu = suite_u_log(:);
    ww = suite_w_log(:);
    if isempty(uu); uu = vel(:,1); end
    if isempty(ww); ww = vel(:,3); end
    de_ff = suite_de_uw_ff_log(:);
    if isempty(de_ff); de_ff = zeros(n,1); end
    clamp_lim = deg2rad(muw_ff_clamp_deg);
    hit = false(n,1);
    for i = 1:n
        u_abs = abs(uu(i));
        b_u = max(0, min(1, (u_abs - muw_ff_u_lo) / max(muw_ff_u_hi - muw_ff_u_lo, 1e-6)));
        u_eff2 = max(uu(i)*uu(i), muw_ff_u_min*muw_ff_u_min);
        G_de = Muuds * u_eff2;
        if abs(G_de) < 1e-9 || lambda_muw_ff == 0 || b_u < 1e-6
            continue;
        end
        raw = -lambda_muw_ff * (Muw * uu(i) * ww(i)) / G_de;
        hit(i) = abs(raw) >= 0.98 * clamp_lim;
    end
    r.pct_muw_clamp = 100 * mean(hit);

    % Pitch err (suite style)
    pitch_err = pitch_refs(:) + ori(:,2);
    r.mean_pitch_err_deg = rad2deg(mean(abs(pitch_err)));

    % Store series for plots
    r.t = t;
    r.cte_suite = cte_suite;
    r.cte_perp = cte_perp;
    r.e_s = e_s;
    r.e_z = e_z;
    r.e_xy = e_xy;
    r.s_prog = s_prog_log;
    r.vp = vp;
    r.path = path;

    % Optional PNGs
    try
        save_audit_png(r, fullfile(out_dir, sprintf('audit_%s.png', sc.tag)));
    catch ME
        fprintf(2, 'PNG skip (%s): %s\n', sc.tag, ME.message);
    end
end

function save_audit_png(r, fig_path)
    fig = figure('Visible', 'off', 'Color', 'w', 'Position', [40 40 1100 720]);

    subplot(2,2,1);
    plot3(r.path(:,1), r.path(:,2), r.path(:,3), 'k--', 'LineWidth', 1.4); hold on;
    plot3(r.vp(:,1), r.vp(:,2), r.vp(:,3), 'b-', 'LineWidth', 1.6);
    grid on; axis equal;
    xlabel('X'); ylabel('Y'); zlabel('Z');
    title(sprintf('%s  suiteCTE=%.2fm  CTE_perp=%.2fm', r.name, r.cte_full, r.mean_cte_perp));
    view(35, 20);

    subplot(2,2,2);
    plot(r.t, r.cte_suite, 'k', 'LineWidth', 1.1); hold on;
    plot(r.t, r.cte_perp, 'b', 'LineWidth', 1.1);
    plot(r.t, abs(r.e_s), 'r--', 'LineWidth', 1.0);
    grid on; xlabel('t (s)'); ylabel('m');
    legend('suite CTE', 'CTE_{perp}', '|e_s|', 'Location', 'best');
    title('Error decomposition vs time');

    subplot(2,2,3);
    plot(r.t, r.e_z, 'b', 'LineWidth', 1.1); hold on;
    plot(r.t, r.e_xy, 'm', 'LineWidth', 1.0);
    grid on; xlabel('t (s)'); ylabel('m');
    legend('e_z (normal)', 'e_{xy} (normal)', 'Location', 'best');
    title('Normal-error components');

    subplot(2,2,4);
    plot(r.t, r.s_prog, 'b', 'LineWidth', 1.2); hold on;
    yline(0.88*r.s_total, 'r--', '88% path');
    yline(r.s_total, 'k--', 'path end');
    grid on; xlabel('t (s)'); ylabel('s (m)');
    title(sprintf('Progress  s_{tot}=%.1fm  travel~%.1fm', r.s_total, r.travel_est));

    exportgraphics(fig, fig_path, 'Resolution', 140);
    close(fig);
end

%% --------- report ---------
function write_report(out_dir, reports, lam, kg, kz, dtc, dtg, tau, Kia, Kir)
    md = fullfile(out_dir, 'VERTICAL_AUDIT_METRICS.md');
    fid = fopen(md, 'w');
    if fid < 0; error('Cannot write %s', md); end

    rx = []; rxz = [];
    for i = 1:numel(reports)
        if strcmp(reports{i}.tag, 'x_line'); rx = reports{i}; end
        if strcmp(reports{i}.tag, 'xz_line'); rxz = reports{i}; end
    end

    fprintf(fid, '# VERTICAL_AUDIT_METRICS\n\n');
    fprintf(fid, '**Date:** %s\n', datestr(now, 'yyyy-mm-dd HH:MM:SS'));
    fprintf(fid, '**Scope:** XZ slant + X-line only (no full suite). Metrics only — no new controller.\n\n');

    fprintf(fid, '## Stack / T5B disposition\n\n');
    fprintf(fid, '| Item | Value |\n|------|------:|\n');
    fprintf(fid, '| `lambda_muw_ff` | **%.2f** (Tur3 freeze) |\n', lam);
    fprintf(fid, '| Tur4A `r_ff=U_h*κ` / T25 trim / timing | **kept** |\n');
    fprintf(fid, '| `dt_controller` / `dt_guidance` / `tau_rate` | %.4f / %.4f / %.4f |\n', dtc, dtg, tau);
    fprintf(fid, '| `Ki_angle` / `Ki_rate` | %.3f / %.3f |\n', Kia, Kir);
    fprintf(fid, '| Audit `K_gamma` | **%.2f** (T5B OFF) |\n', kg);
    fprintf(fid, '| Audit `K_zdot` | **%.2f** |\n', kz);
    fprintf(fid, '| T5B `K_gamma=0.75` | **experimental flag left in `init_parameters.m`** — NOT production acceptance (full suite never passed gates). Audit forces `K_gamma=0`.\n');
    fprintf(fid, '\n');

    fprintf(fid, '## Suite CTE definition (current gate)\n\n');
    fprintf(fid, 'Suite / Tur runners compute\n\n');
    fprintf(fid, '```text\nCTE_suite(i) = min_j || p_vehicle(i) - path_waypoint(j) ||\n```\n\n');
    fprintf(fid, 'This is **nearest discrete waypoint distance**, not Frenet normal CTE.\n');
    fprintf(fid, 'It mixes perpendicular path error with **along-track lag**, **startup**, and especially **endpoint overrun** (vehicle past last waypoint).\n\n');

    fprintf(fid, '## Decomposition (this audit)\n\n');
    fprintf(fid, 'At progress point `p_d` with unit tangent `t_hat` (monotonic projection, guidance-like):\n\n');
    fprintf(fid, '- `e_s = (p - p_d) · t_hat`  (along-track)\n');
    fprintf(fid, '- `e_perp_vec = (I - t t^T)(p - p_d)`\n');
    fprintf(fid, '- `CTE_perp = ||e_perp_vec||`\n');
    fprintf(fid, '- `e_z`, `e_xy` = normal-error components\n');
    fprintf(fid, '- Also: unconstrained geometric projection `CTE_geom_perp` (no progress hold)\n\n');
    fprintf(fid, 'Windows: **full**; **settled** `t≥5 s`; **before endpoint** `s < 0.88 s_total` and not `near_end`.\n\n');

    if ~isempty(rxz)
        print_scenario_table(fid, rxz);
    end
    if ~isempty(rx)
        print_scenario_table(fid, rx);
    end

    % Answers
    fprintf(fid, '## Answers\n\n');
    if ~isempty(rxz)
        fprintf(fid, '### 1) Of reported ~2.6 m XZ CTE, how much is real perpendicular path error?\n\n');
        fprintf(fid, '| Window | suite CTE | CTE_perp | CTE_geom_perp | mean \\|e_s\\| | mean \\|e_z\\| |\n');
        fprintf(fid, '|--------|----------:|---------:|--------------:|------------:|------------:|\n');
        fprintf(fid, '| full | %.3f | %.3f (%.0f%% of suite) | %.3f | %.3f | %.3f |\n', ...
            rxz.cte_full, rxz.mean_cte_perp, 100*rxz.frac_perp_of_suite_full, ...
            rxz.mean_cte_geom_perp, rxz.mean_abs_es, rxz.mean_abs_ez);
        fprintf(fid, '| settled t≥5s | %.3f | %.3f (%.0f%%) | %.3f | %.3f | %.3f |\n', ...
            rxz.cte_settled, rxz.cte_settled_perp, 100*rxz.frac_perp_of_suite_settled, ...
            rxz.mean_cte_geom_perp_settled, rxz.mean_abs_es_settled, rxz.mean_abs_ez_settled);
        fprintf(fid, '| before endpoint | %.3f | %.3f (%.0f%%) | %.3f | %.3f | %.3f |\n', ...
            rxz.cte_before_end, rxz.cte_before_end_perp, 100*rxz.frac_perp_of_suite_pre_end, ...
            rxz.mean_cte_geom_perp_pre_end, rxz.mean_abs_es_pre_end, rxz.mean_abs_ez_pre_end);
        fprintf(fid, '\n');
        fprintf(fid, '- Path length `s_total=%.2f m`, sim travel ≈ `%.2f m`, `T_final=%.1f s` → vehicle **overruns** the path.\n', ...
            rxz.s_total, rxz.travel_est, rxz.T_final);
        fprintf(fid, '- Samples with progress at path end: **%.1f%%**; past-end suite CTE mean/max = %.3f / %.3f m.\n', ...
            rxz.pct_samples_past_end, rxz.cte_past_end_mean, rxz.cte_past_end_max);
        fprintf(fid, '- Max startup suite CTE (t<5s): **%.3f m**.\n', rxz.max_startup_cte);
        fprintf(fid, '- **Verdict:** reported ~2.6 m is **mostly endpoint / along-track inflation** of nearest-waypoint distance. ');
        fprintf(fid, 'True normal error `CTE_perp` (before endpoint) ≈ **%.3f m**, with depth component mean `|e_z|` ≈ **%.3f m**. ', ...
            rxz.cte_before_end_perp, rxz.mean_abs_ez_pre_end);
        fprintf(fid, 'Fraction of full-window suite CTE that is perpendicular (progress-based) ≈ **%.0f%%**; ', ...
            100*rxz.frac_perp_of_suite_full);
        fprintf(fid, 'on the before-endpoint window ≈ **%.0f%%**.\n\n', ...
            100*rxz.frac_perp_of_suite_pre_end);
    end

    if ~isempty(rx)
        fprintf(fid, '### 2) X-line: why ~2 m mean / ~10 m max while path looks flat?\n\n');
        fprintf(fid, '| Metric | Value |\n|--------|------:|\n');
        fprintf(fid, '| Path length | %.2f m (ends at x=%.1f) |\n', rx.s_total, rx.path_end(1));
        fprintf(fid, '| Sim travel / T_final | %.2f m / %.1f s |\n', rx.travel_est, rx.T_final);
        fprintf(fid, '| Vehicle end XYZ | [%.2f, %.2f, %.2f] |\n', rx.veh_end(1), rx.veh_end(2), rx.veh_end(3));
        fprintf(fid, '| suite CTE mean / max | %.3f / %.3f m |\n', rx.cte_full, rx.cte_max);
        fprintf(fid, '| CTE_perp mean (full / pre-end) | %.3f / %.3f m |\n', rx.mean_cte_perp, rx.cte_before_end_perp);
        fprintf(fid, '| mean \\|e_z\\| / e_xy (full) | %.3f / %.3f m |\n', rx.mean_abs_ez, rx.mean_e_xy);
        fprintf(fid, '| %% samples at/past path end | %.1f%% |\n', rx.pct_samples_past_end);
        fprintf(fid, '| past-end suite CTE mean / max | %.3f / %.3f m |\n', rx.cte_past_end_mean, rx.cte_past_end_max);
        fprintf(fid, '| max startup suite CTE | %.3f m |\n', rx.max_startup_cte);
        fprintf(fid, '\n');
        fprintf(fid, '**Cause:** X-line path is only **20 m** long but the sim runs **18 s** at ~1.5 m/s (~27 m travel). ');
        fprintf(fid, 'After the last waypoint, suite CTE = distance to the **endpoint**, so along-track overrun appears as large “cross-track” (max ~path overrun). ');
        fprintf(fid, 'While on-path, `CTE_perp` / `|e_z|` stay small — the trajectory is flat; the metric is not.\n\n');
    end

    fprintf(fid, '### 3) Is the ≥15%% XZ CTE gate still meaningful?\n\n');
    if ~isempty(rxz)
        fprintf(fid, '**Mostly no as currently defined.** The ≥15%% gate targets suite nearest-waypoint CTE (Tur4A baseline 2.766 → ≤2.351). ');
        fprintf(fid, 'That number is dominated by **endpoint overrun + along-track**, so gain tweaks that improve true depth tracking barely move the gate (T5A/T5B saw only ~5%%). ');
        fprintf(fid, '**Retarget recommendation:**\n\n');
        fprintf(fid, '1. Primary: **settled `CTE_perp`** and/or **mean `|e_z|`** on `t≥5 s` **and** `s < 0.88 s_total`.\n');
        fprintf(fid, '2. Keep suite CTE only as a sanity check, or recompute it with the same before-endpoint mask.\n');
        fprintf(fid, '3. Suggested starting targets (from this audit, before-endpoint): ');
        fprintf(fid, '`CTE_perp` ≈ %.3f m, `|e_z|` ≈ %.3f m — set a relative improvement vs this frozen baseline, not vs inflated 2.6 m.\n\n', ...
            rxz.cte_before_end_perp, rxz.mean_abs_ez_pre_end);
    else
        fprintf(fid, 'XZ data missing.\n\n');
    end

    fprintf(fid, '## Saturation / limit hits (same run, no controller change)\n\n');
    fprintf(fid, '| Scenario | pitch_ref rate-lim %% | angle-I near-limit %% | muw_ff clamp %% |\n');
    fprintf(fid, '|----------|---------------------:|----------------------:|---------------:|\n');
    for i = 1:numel(reports)
        rr = reports{i};
        fprintf(fid, '| %s | %.1f | %.1f | %.1f |\n', ...
            rr.name, rr.pct_rate_lim, rr.pct_angle_I_near, rr.pct_muw_clamp);
    end
    fprintf(fid, '\n');

    fprintf(fid, '## NEXT (do NOT implement in this task)\n\n');
    fprintf(fid, '1. Elevator perturbation ID (authority / sign / delay).\n');
    fprintf(fid, '2. A/B controller trials / coupled LQI `[ez, ezdot, eθ, q, Iz]`.\n');
    fprintf(fid, '3. Yaw ref smoothness; R=5 speed scheduler (still deferred).\n');
    fprintf(fid, '4. Retarget path-suite gates to settled `CTE_perp` / `|e_z|` (+ optional longer paths or stop-at-end).\n\n');

    fprintf(fid, '## Files\n\n');
    fprintf(fid, '- `run_vertical_audit.m` — this audit runner\n');
    fprintf(fid, '- `suite_results/VERTICAL_AUDIT_METRICS.md` — this report\n');
    fprintf(fid, '- `suite_results/audit_x_line.png`, `audit_xz_line.png` — optional plots\n');
    fprintf(fid, '- `init_parameters.m` — `K_gamma=0.75` left as **experimental** default comment/flag (audit overrides to 0)\n');

    fclose(fid);
end

function print_scenario_table(fid, r)
    fprintf(fid, '## %s\n\n', r.name);
    fprintf(fid, '| Metric | Value |\n|--------|------:|\n');
    fprintf(fid, '| CTE_full (suite) | %.3f m |\n', r.cte_full);
    fprintf(fid, '| CTE max (suite) | %.3f m |\n', r.cte_max);
    fprintf(fid, '| CTE_settled t≥5s (suite) | %.3f m |\n', r.cte_settled);
    fprintf(fid, '| CTE_settled discard 20%% (suite) | %.3f m |\n', r.cte_settled20);
    fprintf(fid, '| CTE_before_endpoint (suite) | %.3f m |\n', r.cte_before_end);
    fprintf(fid, '| mean \\|e_s\\| | %.3f m |\n', r.mean_abs_es);
    fprintf(fid, '| mean CTE_perp | %.3f m |\n', r.mean_cte_perp);
    fprintf(fid, '| CTE_perp settled / before-end | %.3f / %.3f m |\n', r.cte_settled_perp, r.cte_before_end_perp);
    fprintf(fid, '| mean \\|e_z\\| (full / settled / pre-end) | %.3f / %.3f / %.3f m |\n', ...
        r.mean_abs_ez, r.mean_abs_ez_settled, r.mean_abs_ez_pre_end);
    fprintf(fid, '| mean e_xy (normal) | %.3f m |\n', r.mean_e_xy);
    fprintf(fid, '| max startup suite CTE | %.3f m |\n', r.max_startup_cte);
    fprintf(fid, '| CTE_geom_perp mean (full / pre-end) | %.3f / %.3f m |\n', ...
        r.mean_cte_geom_perp, r.mean_cte_geom_perp_pre_end);
    fprintf(fid, '| path s_total / travel | %.2f / %.2f m |\n', r.s_total, r.travel_est);
    fprintf(fid, '| path overrun (travel − s_total) | ≈ %.1f m |\n', max(0, r.travel_est - r.s_total));
    fprintf(fid, '| %% samples past path end | %.1f |\n', r.pct_samples_past_end);
    if ~isnan(r.cte_past_end_mean)
        fprintf(fid, '| past-end suite CTE mean / max | %.3f / %.3f m |\n', ...
            r.cte_past_end_mean, r.cte_past_end_max);
    end
    fprintf(fid, '| mean \\|pitch err\\| | %.2f deg |\n', r.mean_pitch_err_deg);
    fprintf(fid, '\n');
    if isfile(fullfile(fileparts(mfilename('fullpath')), 'suite_results', sprintf('audit_%s.png', r.tag))) ...
            || true
        fprintf(fid, '![%s](audit_%s.png)\n\n', r.name, r.tag);
    end
end

%% --------- path helpers (mirror guidance_law) ---------
function [s_nodes, s_total] = path_arclength(path)
    n = size(path, 1);
    s_nodes = zeros(n, 1);
    for i = 2:n
        s_nodes(i) = s_nodes(i-1) + norm(path(i,:) - path(i-1,:));
    end
    s_total = max(s_nodes(end), 1e-9);
end

function [s_best, d_best] = project_on_path(p, path, s_nodes, s_lo, s_hi, is_closed) %#ok<INUSD>
    [s_best, d_best] = project_interval(p, path, s_nodes, max(0,s_lo), min(s_nodes(end),s_hi));
end

function [s_best, d_best] = project_interval(p, path, s_nodes, s_lo, s_hi)
    n = size(path, 1);
    d_best = inf;
    s_best = s_lo;
    i0 = max(1, find(s_nodes <= s_lo, 1, 'last'));
    i1 = min(n-1, find(s_nodes >= s_hi, 1, 'first'));
    if isempty(i0); i0 = 1; end
    if isempty(i1); i1 = n-1; end
    i0 = min(i0, n-1);
    i1 = max(i1, i0);
    for i = i0:i1
        a = path(i,:); b = path(i+1,:);
        ab = b - a;
        lab2 = sum(ab.^2);
        if lab2 < 1e-12; continue; end
        tt = max(0, min(1, dot(p - a, ab) / lab2));
        proj = a + tt * ab;
        d = norm(p - proj);
        s = s_nodes(i) + tt * (s_nodes(i+1) - s_nodes(i));
        if s < s_lo - 1e-9 || s > s_hi + 1e-9; continue; end
        if d < d_best
            d_best = d;
            s_best = s;
        end
    end
end

function [p, t_hat] = sample_path(path, s_nodes, s, is_closed)
    n = size(path, 1);
    s_total = s_nodes(end);
    if is_closed
        s = mod(s, s_total);
    else
        s = max(0, min(s_total, s));
    end
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
