function run_tur5b()
% RUN_TUR5B  Tur5B: gamma (flight-path angle) guidance on pitch_ref.
% One MATLAB batch: T5B-0 log → K_gamma sweep (K_zdot=0) → A/B K_zdot →
% optional alpha if needed → full suite ONCE if candidate passes soft gates.
% Writes suite_results/TUR5B_SUMMARY.md
%
%   e_gamma = gamma_path - gamma_actual
%   theta_ref = theta_path + K_gamma*e_gamma + Kz*e_z + depth-I [± K_zdot]
% Optional: theta_ref = gamma_cmd + alpha_hat

    project_dir = fileparts(fileparts(fileparts(mfilename('fullpath')))); % repo root
    addpath(genpath(fullfile(project_dir, 'matlab')));
    out_dir = fullfile(project_dir, 'suite_results');
    if ~exist(out_dir, 'dir'); mkdir(out_dir); end

    clear functions
    clear guidance_law controller_law
    clear global lambda_muw_ff trim_speed_table trim_elevator_table elevator_sign
    clear global K_zdot K_gamma enable_alpha_hat
    init_parameters();

    global lambda_muw_ff elevator_sign trim_speed_table trim_elevator_table
    global dt_controller dt_guidance tau_rate Ki_rate Ki_angle
    global K_zdot K_gamma enable_alpha_hat delta_e_max

    % Frozen stack — do not reopen pitch PID / depth-P/I / Tur4A / Tur4B
    elevator_sign = 1;
    trim_speed_table = [0.8 1.0 1.5 2.0];
    trim_elevator_table = deg2rad([-9.18 -7.33 -4.62 -3.17]);
    lambda_muw_ff = 0.25;
    enable_alpha_hat = false;

    fprintf('\n========== TUR5B  gamma path-angle guidance ==========\n');
    fprintf('Frozen: dt_c=%.4f dt_g=%.4f tau=%.4f Ki_rate=%.3f Ki_angle=%.3f lam=%.2f\n', ...
        dt_controller, dt_guidance, tau_rate, Ki_rate, Ki_angle, lambda_muw_ff);

    xz_base_cte = 2.766; % Tur4A / T3B-2 baseline
    t5a_cte = 2.628;     % T5A @ K_zdot=0.50

    %% ----- T5B-0: log only (production K_zdot=0.50, K_gamma=0) -----
    fprintf('\n----- T5B-0  log only  K_gamma=0  K_zdot=0.50 -----\n');
    K_gamma = 0;
    K_zdot = 0.50;
    enable_alpha_hat = false;
    clear guidance_law controller_law
    t0 = run_xz_metrics(true);
    t0.K_gamma = 0; t0.K_zdot = 0.50; t0.alpha = 0;
    fprintf('CTE=%.3f  |e_th|=%.2f  |th-g|_mean=%.2f deg  |th-g|_rms=%.2f deg  chatter=%.4f\n', ...
        t0.mean_cte, t0.mean_pitch_err_deg, t0.mean_abs_th_minus_g_deg, ...
        t0.rms_th_minus_g_deg, t0.pitch_chatter_dps);

    %% ----- T5B-1: K_gamma sweep, K_zdot=0 -----
    fprintf('\n----- T5B-1  K_gamma sweep  K_zdot=0 -----\n');
    kg_list = [0, 0.25, 0.50, 0.75, 1.0];
    sweep = struct([]);
    K_zdot = 0;
    enable_alpha_hat = false;
    for i = 1:numel(kg_list)
        K_gamma = kg_list(i);
        fprintf('\n----- XZ  K_gamma=%.2f  K_zdot=0 -----\n', K_gamma);
        clear guidance_law controller_law
        m = run_xz_metrics(false);
        m.K_gamma = K_gamma;
        m.K_zdot = 0;
        m.alpha = 0;
        if isempty(sweep); sweep = m; else; sweep(end+1) = m; end %#ok<AGROW>
        drop = 100 * (xz_base_cte - m.mean_cte) / xz_base_cte;
        fprintf('Kg=%.2f  CTE=%.3f  drop=%.1f%%  |e_th|=%.2f  chatter=%.4f  sat=%.1f%%\n', ...
            K_gamma, m.mean_cte, drop, m.mean_pitch_err_deg, m.pitch_chatter_dps, m.pct_mag_sat);
    end
    best = pick_best_kgamma(sweep, xz_base_cte);
    fprintf('\n*** Best K_gamma=%.2f  CTE=%.3f ***\n', best.K_gamma, best.mean_cte);

    %% ----- T5B-2: A/B K_zdot at best K_gamma -----
    fprintf('\n----- T5B-2  A/B K_zdot @ K_gamma=%.2f -----\n', best.K_gamma);
    ab = struct([]);
    for kz = [0, 0.50]
        K_gamma = best.K_gamma;
        K_zdot = kz;
        enable_alpha_hat = false;
        clear guidance_law controller_law
        m = run_xz_metrics(false);
        m.K_gamma = best.K_gamma;
        m.K_zdot = kz;
        m.alpha = 0;
        if isempty(ab); ab = m; else; ab(end+1) = m; end %#ok<AGROW>
        fprintf('Kzdot=%.2f  CTE=%.3f  |e_th|=%.2f  chatter=%.4f  sat=%.1f%%\n', ...
            kz, m.mean_cte, m.mean_pitch_err_deg, m.pitch_chatter_dps, m.pct_mag_sat);
    end
    % Prefer A (K_zdot=0) unless B clearly better on CTE without gate regression
    a0 = ab(1); a1 = ab(2);
    keep_kzdot = false;
    cte_benefit = a0.mean_cte - a1.mean_cte; % >0 => B better CTE
    if cte_benefit >= 0.05 ...
            && a1.pitch_chatter_dps < 0.12 && a1.pct_mag_sat < 1.0 ...
            && a1.mean_pitch_err_deg <= a0.mean_pitch_err_deg + 0.15
        keep_kzdot = true;
        cand = a1;
        fprintf('K_zdot KEEP 0.50 (CTE benefit %.3f m)\n', cte_benefit);
    else
        keep_kzdot = false;
        cand = a0;
        fprintf('K_zdot DROP -> 0 (no clear benefit; A CTE=%.3f B=%.3f)\n', ...
            a0.mean_cte, a1.mean_cte);
    end
    K_zdot = cand.K_zdot;
    K_gamma = cand.K_gamma;

    %% ----- Gate check before suite / alpha -----
    target = xz_base_cte * 0.85; % 2.351
    soft_pass = cand.mean_cte <= target ...
        && cand.mean_pitch_err_deg < 0.8 ...
        && cand.pitch_chatter_dps < 0.12 ...
        && cand.pct_mag_sat < 1.0;
    directional = (xz_base_cte - cand.mean_cte) / xz_base_cte >= 0.10;
    residual_bias = cand.mean_pitch_err_deg > 0.9;
    stop_chatter = ~directional && cand.mean_pitch_err_deg > 1.3 ...
        && max([sweep.pitch_chatter_dps]) > 0.12;

    alpha_ran = false;
    alpha_m = [];
    if soft_pass
        fprintf('\nGates soft-PASS on XZ candidate — skip alpha, run full suite once.\n');
    elseif stop_chatter && ~directional
        fprintf('\nSTOP: CTE improve <10%% and |e_th|~%.2f with chatter rising — skip alpha/suite.\n', ...
            cand.mean_pitch_err_deg);
    elseif directional && residual_bias && ~soft_pass
        %% ----- T5B-3: alpha_hat only if gamma helps but residual bias -----
        fprintf('\n----- T5B-3  alpha_hat ON @ Kg=%.2f Kzdot=%.2f -----\n', ...
            K_gamma, K_zdot);
        enable_alpha_hat = true;
        clear guidance_law controller_law
        alpha_m = run_xz_metrics(false);
        alpha_m.K_gamma = K_gamma;
        alpha_m.K_zdot = K_zdot;
        alpha_m.alpha = 1;
        alpha_ran = true;
        fprintf('alpha  CTE=%.3f  |e_th|=%.2f  chatter=%.4f  sat=%.1f%%\n', ...
            alpha_m.mean_cte, alpha_m.mean_pitch_err_deg, ...
            alpha_m.pitch_chatter_dps, alpha_m.pct_mag_sat);
        alpha_better = alpha_m.mean_cte < cand.mean_cte - 0.03 ...
            && alpha_m.pitch_chatter_dps < 0.12 && alpha_m.pct_mag_sat < 1.0;
        if alpha_better
            cand = alpha_m;
            fprintf('alpha KEEP\n');
        else
            enable_alpha_hat = false;
            fprintf('alpha DROP (no clear benefit)\n');
        end
        soft_pass = cand.mean_cte <= target ...
            && cand.mean_pitch_err_deg < 0.8 ...
            && cand.pitch_chatter_dps < 0.12 ...
            && cand.pct_mag_sat < 1.0;
    else
        fprintf('\nNo alpha: directional=%d residual_bias=%d soft_pass=%d\n', ...
            directional, residual_bias, soft_pass);
    end

    %% ----- Full suite once if candidate passes (or near CTE gate) -----
    suite = [];
    ran_suite = false;
    near_cte = cand.mean_cte <= target + 0.05; % allow tiny slack for suite confirm
    if soft_pass || (near_cte && cand.pitch_chatter_dps < 0.12 && cand.pct_mag_sat < 1.0)
        K_gamma = cand.K_gamma;
        K_zdot = cand.K_zdot;
        enable_alpha_hat = logical(cand.alpha);
        fprintf('\n----- Full suite @ Kg=%.2f Kzdot=%.2f alpha=%d -----\n', ...
            K_gamma, K_zdot, enable_alpha_hat);
        clear guidance_law controller_law
        suite = run_path_suite(false);
        ran_suite = true;
    else
        fprintf('\nSkip full suite (XZ gates not met). Candidate CTE=%.3f need ≤%.3f\n', ...
            cand.mean_cte, target);
    end

    % Restore production choice into globals for summary / defaults
    K_gamma = cand.K_gamma;
    K_zdot = cand.K_zdot;
    enable_alpha_hat = logical(cand.alpha);

    write_tur5b_summary(out_dir, t0, sweep, best, ab, keep_kzdot, cand, ...
        alpha_ran, alpha_m, suite, ran_suite, xz_base_cte, t5a_cte, ...
        lambda_muw_ff, dt_controller, dt_guidance, tau_rate, Ki_rate, Ki_angle);

    fprintf('\nWrote %s\n', fullfile(out_dir, 'TUR5B_SUMMARY.md'));
    fprintf('FINAL: Kg=%.2f Kzdot=%.2f alpha=%d CTE=%.3f\n', ...
        cand.K_gamma, cand.K_zdot, cand.alpha, cand.mean_cte);
end

function best = pick_best_kgamma(sweep, xz_base)
    target = xz_base * 0.85;
    ok = false(size(sweep));
    for i = 1:numel(sweep)
        ok(i) = sweep(i).mean_cte <= target ...
            && sweep(i).mean_pitch_err_deg < 0.8 ...
            && sweep(i).pitch_chatter_dps < 0.12 ...
            && sweep(i).pct_mag_sat < 1.0;
    end
    if any(ok)
        cands = sweep(ok);
        [~, j] = min([cands.mean_cte]);
        best = cands(j);
        return;
    end
    soft = false(size(sweep));
    for i = 1:numel(sweep)
        soft(i) = sweep(i).pitch_chatter_dps < 0.12 && sweep(i).pct_mag_sat < 5.0;
    end
    if any(soft)
        cands = sweep(soft);
        [~, j] = min([cands.mean_cte]);
        best = cands(j);
        return;
    end
    [~, j] = min([sweep.mean_cte]);
    best = sweep(j);
end

function m = run_xz_metrics(want_gamma_stats)
    global dt_controller delta_e_max
    global suite_delta_e_log suite_e_theta_log
    global suite_theta_phys_log suite_gamma_actual_log suite_alpha_eff_log
    global suite_e_gamma_log suite_e_z_log suite_e_zdot_log suite_w_log
    global suite_zdot_inertial_log suite_pitch_refs_log

    if nargin < 1; want_gamma_stats = false; end

    sc = make_xz();
    dt = dt_controller;
    state0 = initial_state(sc.path, sc.u0);
    [vp, times, vel, ~, ori, ~, yaw_refs, pitch_refs, ~] = ...
        continuous_path_tracking(sc.path, state0, dt, sc.T); %#ok<ASGLU>

    pm = compute_path_following_metrics(sc.path, vp, vel, ori, yaw_refs, pitch_refs, dt, times);
    n = size(vp, 1);
    i0 = max(1, round(2.0/dt));
    pitch_err = pitch_refs(:) + ori(:,2);
    th = -ori(:,2);

    de = suite_delta_e_log(:);
    if isempty(de); de = zeros(n,1); end
    eth = suite_e_theta_log(:);
    if isempty(eth); eth = pitch_err; end
    pct_sat = 100 * mean(abs(de(i0:end)) >= 0.95 * delta_e_max);

    m = struct( ...
        'mean_cte', pm.mean_cte_perp, ...
        'max_cte', pm.max_cte_perp, ...
        'cte_waypoint_legacy', pm.cte_waypoint_legacy_full, ...
        'mean_abs_ez', pm.mean_abs_ez, ...
        'mean_signed_ez', pm.mean_signed_ez, ...
        'mean_pitch_err_deg', pm.mean_pitch_err_deg, ...
        'mean_e_theta_deg', rad2deg(mean(eth(i0:end))), ...
        'pitch_chatter_dps', pm.pitch_chatter_dps, ...
        'pct_mag_sat', pct_sat, ...
        'elevator_rms_deg', rad2deg(rms(de)), ...
        'final_u', vel(end,1), ...
        'mean_abs_th_minus_g_deg', nan, ...
        'rms_th_minus_g_deg', nan, ...
        'mean_alpha_eff_deg', nan, ...
        'mean_e_gamma_deg', nan, ...
        'mean_e_z', nan, ...
        'mean_e_zdot', nan, ...
        'mean_w', nan, ...
        'mean_zdot', nan, ...
        'mean_pitch_ref_deg', nan);

    if want_gamma_stats || true
        thp = suite_theta_phys_log(:);
        ga = suite_gamma_actual_log(:);
        if isempty(thp); thp = th; end
        if isempty(ga); ga = zeros(size(thp)); end
        d = thp(i0:end) - ga(i0:end);
        m.mean_abs_th_minus_g_deg = rad2deg(mean(abs(d)));
        m.rms_th_minus_g_deg = rad2deg(rms(d));
        ae = suite_alpha_eff_log(:);
        if ~isempty(ae); m.mean_alpha_eff_deg = rad2deg(mean(ae(i0:end))); end
        eg = suite_e_gamma_log(:);
        if ~isempty(eg); m.mean_e_gamma_deg = rad2deg(mean(eg(i0:end))); end
        ez = suite_e_z_log(:);
        if ~isempty(ez); m.mean_e_z = mean(ez(i0:end)); end
        ezd = suite_e_zdot_log(:);
        if ~isempty(ezd); m.mean_e_zdot = mean(ezd(i0:end)); end
        ww = suite_w_log(:);
        if ~isempty(ww); m.mean_w = mean(ww(i0:end)); end
        zd = suite_zdot_inertial_log(:);
        if ~isempty(zd); m.mean_zdot = mean(zd(i0:end)); end
        pr = suite_pitch_refs_log(:);
        if isempty(pr); pr = pitch_refs(:); end
        m.mean_pitch_ref_deg = rad2deg(mean(pr(i0:end)));
    end
end

function y = hf_sig(x, dt)
    n = max(3, round(0.8/dt));
    lf = filter(ones(n,1)/n, 1, x(:));
    y = x(:) - lf; y(1:n) = 0;
end

function state = initial_state(path, u0)
    state = zeros(12,1);
    state(1:3) = path(1,:)';
    d = path(2,:) - path(1,:);
    state(5) = -atan2(d(3), norm(d(1:2)));
    state(6) = atan2(d(2), d(1));
    state(7) = u0;
end

function sc = make_xz()
    % Match suite: L=42 → s≈45 m > T_sim travel (~36 m)
    n = 900;
    t = linspace(0,42,n)';
    sc = struct('name','XZ-line','tag','xz_line','path',[t,zeros(n,1),0.4*t],'T',22,'u0',1.5);
end

function write_tur5b_summary(out_dir, t0, sweep, best, ab, keep_kzdot, cand, ...
        alpha_ran, alpha_m, suite, ran_suite, xz_base, t5a_cte, ...
        lam, dtc, dtg, tau, Kir, Kia)
    fid = fopen(fullfile(out_dir, 'TUR5B_SUMMARY.md'), 'w');
    fprintf(fid, '# TUR5B_SUMMARY — gamma path-angle guidance\n\n');
    fprintf(fid, '**Date:** %s\n', datestr(now, 'yyyy-mm-dd HH:MM:SS'));
    fprintf(fid, '**Change:** `pitch_ref = theta_path + K_gamma*e_gamma + Kz*e_z + depth-I`');
    if cand.alpha
        fprintf(fid, ' + `alpha_hat`');
    end
    fprintf(fid, ' (Tur4B skipped)\n');

    target = xz_base * 0.85;
    drop = 100 * (xz_base - cand.mean_cte) / xz_base;
    cte_ok = cand.mean_cte <= target;
    prefer_ok = cand.mean_cte < 2.0;
    pitch_ok = cand.mean_pitch_err_deg < 0.8;
    chat_ok = cand.pitch_chatter_dps < 0.12;
    sat_ok = cand.pct_mag_sat < 1.0;

    % Suite regression
    base = struct('x_cte', 2.116, 'xz_cte', xz_base, 'circle_cte', 1.516, 'helix_cte', 1.675);
    sx = find_suite(suite, 'x_line');
    sxz = find_suite(suite, 'xz_line');
    sc = find_suite(suite, 'circle');
    sh = find_suite(suite, 'helix');
    reg_ok = true;
    if ran_suite
        if ~isempty(sx); reg_ok = reg_ok && (sx.mean_cross_track <= base.x_cte * 1.05); end
        if ~isempty(sc); reg_ok = reg_ok && (sc.mean_cross_track <= base.circle_cte * 1.05); end
        if ~isempty(sh); reg_ok = reg_ok && (sh.mean_cross_track <= base.helix_cte * 1.05); end
        if ~isempty(sxz)
            xz_cte = sxz.mean_cross_track;
            xz_pitch = sxz.mean_pitch_err_deg;
            xz_ch = sxz.pitch_chatter_dps;
            cte_ok = xz_cte <= target;
            prefer_ok = xz_cte < 2.0;
            pitch_ok = xz_pitch < 0.8;
            chat_ok = xz_ch < 0.12;
        else
            xz_cte = cand.mean_cte; xz_pitch = cand.mean_pitch_err_deg; xz_ch = cand.pitch_chatter_dps;
        end
    else
        xz_cte = cand.mean_cte; xz_pitch = cand.mean_pitch_err_deg; xz_ch = cand.pitch_chatter_dps;
    end
    xz_accept = cte_ok && pitch_ok && chat_ok && sat_ok;
    overall = xz_accept && (~ran_suite || reg_ok);
    if ~ran_suite && ~xz_accept
        overall = false;
    end

    fprintf(fid, '**Overall:** **%s**', tern(overall,'PASS','FAIL'));
    fprintf(fid, ' — Kg=%.2f, K_zdot=%s, alpha=%s, XZ CTE=%.3f (%.1f%% vs Tur4A).\n\n', ...
        cand.K_gamma, tern(keep_kzdot,'0.50 (keep)','0 (drop)'), ...
        tern(cand.alpha,'ON','OFF'), xz_cte, drop);

    fprintf(fid, '## Definition\n\n');
    fprintf(fid, '- `gamma_actual = atan2(zdot_inertial, U_h)`\n');
    fprintf(fid, '- `gamma_path = atan2(zdot_path, U_path_h)`, `zdot_path = t_hat(3)*U_along`\n');
    fprintf(fid, '- `e_gamma = gamma_path - gamma_actual` (filtered)\n');
    fprintf(fid, '- `alpha_eff = theta_phys - gamma_actual`\n');
    fprintf(fid, '- `theta_ref = theta_path + K_gamma*e_gamma + Kz*e_z + Ki*int [+ K_zdot term]`\n');
    fprintf(fid, '- Optional: `theta_ref = gamma_path + K_gamma*e_gamma + depth + alpha_hat`\n');
    fprintf(fid, '- Pitch_ref rate limits **kept**. Yaw / R5 / LQI **not** in this task.\n\n');

    fprintf(fid, '## Frozen\n\n');
    fprintf(fid, '| Param | Value |\n|-------|------:|\n');
    fprintf(fid, '| `lambda_muw_ff` | **%.2f** |\n', lam);
    fprintf(fid, '| `dt_controller` | %.4f |\n', dtc);
    fprintf(fid, '| `dt_guidance` | %.4f |\n', dtg);
    fprintf(fid, '| `tau_rate` | %.4f |\n', tau);
    fprintf(fid, '| `Ki_rate` | %.3f |\n', Kir);
    fprintf(fid, '| `Ki_angle` | %.3f |\n', Kia);
    fprintf(fid, '| `K_gamma` (selected) | **%.2f** |\n', cand.K_gamma);
    fprintf(fid, '| `K_zdot` (selected) | **%.2f** |\n', cand.K_zdot);
    fprintf(fid, '| `enable_alpha_hat` | **%s** |\n', tern(cand.alpha,'true','false'));
    fprintf(fid, '| Tur4A `r_ff=U_h*κ` / trim T25 / pitch PID | **kept** |\n');
    fprintf(fid, '| Tur4B radial FF | **SKIPPED** |\n\n');

    fprintf(fid, '## T5B-0 — log only (K_gamma=0, K_zdot=0.50)\n\n');
    fprintf(fid, 'No behavior change vs T5A production. Diagnostics on XZ slant:\n\n');
    fprintf(fid, '| Metric | Value |\n|--------|------:|\n');
    fprintf(fid, '| CTE | %.3f m |\n', t0.mean_cte);
    fprintf(fid, '| \\|e_θ\\| | %.2f° |\n', t0.mean_pitch_err_deg);
    fprintf(fid, '| mean \\|θ−γ\\| | **%.2f°** |\n', t0.mean_abs_th_minus_g_deg);
    fprintf(fid, '| rms (θ−γ) | %.2f° |\n', t0.rms_th_minus_g_deg);
    fprintf(fid, '| mean α_eff | %+.2f° |\n', t0.mean_alpha_eff_deg);
    fprintf(fid, '| mean e_γ | %+.2f° |\n', t0.mean_e_gamma_deg);
    fprintf(fid, '| mean e_z | %+.3f m |\n', t0.mean_e_z);
    fprintf(fid, '| mean e_zdot | %+.3f m/s |\n', t0.mean_e_zdot);
    fprintf(fid, '| mean w | %+.3f m/s |\n', t0.mean_w);
    fprintf(fid, '| mean zdot | %+.3f m/s |\n', t0.mean_zdot);
    fprintf(fid, '| mean pitch_ref | %.2f° |\n', t0.mean_pitch_ref_deg);
    fprintf(fid, '\n**Note on \\|θ−γ\\|:** On XZ dive (~21.8° path), mean \\|θ_phys−γ_actual\\| ≈ %.2f°. ', ...
        t0.mean_abs_th_minus_g_deg);
    if t0.mean_abs_th_minus_g_deg < 3
        fprintf(fid, 'Small AoA — θ≈γ; gamma FB mainly corrects path-angle lag, not large trim AoA.\n\n');
    elseif t0.mean_abs_th_minus_g_deg < 8
        fprintf(fid, 'Moderate AoA — gamma and pitch differ enough that α̂ may help residual bias.\n\n');
    else
        fprintf(fid, 'Large AoA — α̂ or coupled LQI likely needed if gamma alone insufficient.\n\n');
    end

    fprintf(fid, '## T5B-1 — K_gamma sweep (K_zdot=0)\n\n');
    fprintf(fid, 'Baseline CTE = %.3f m (Tur4A). T5A CTE = %.3f. Target ≤%.3f (≥15%%).\n\n', ...
        xz_base, t5a_cte, target);
    fprintf(fid, '| K_gamma | CTE (m) | Δ%% vs base | \\|e_θ\\| (°) | mean e_θ (°) | chatter (°/s) | elev sat%% |\n');
    fprintf(fid, '|-------:|--------:|-------------:|------------:|-------------:|--------------:|------------:|\n');
    for i = 1:numel(sweep)
        s = sweep(i);
        dlt = 100 * (xz_base - s.mean_cte) / xz_base;
        mark = '';
        if abs(s.K_gamma - best.K_gamma) < 1e-9; mark = ' **best**'; end
        fprintf(fid, '| %.2f%s | %.3f | %+.1f | %.2f | %+.3f | %.4f | %.1f |\n', ...
            s.K_gamma, mark, s.mean_cte, dlt, s.mean_pitch_err_deg, ...
            s.mean_e_theta_deg, s.pitch_chatter_dps, s.pct_mag_sat);
    end

    fprintf(fid, '\n## T5B-2 — A/B K_zdot @ best K_gamma=%.2f\n\n', best.K_gamma);
    fprintf(fid, '| K_zdot | CTE | \\|pitch\\| | chatter | sat%% |\n');
    fprintf(fid, '|-------:|----:|---------:|--------:|------:|\n');
    for i = 1:numel(ab)
        a = ab(i);
        fprintf(fid, '| %.2f | %.3f | %.2f | %.4f | %.1f |\n', ...
            a.K_zdot, a.mean_cte, a.mean_pitch_err_deg, a.pitch_chatter_dps, a.pct_mag_sat);
    end
    if keep_kzdot
        fprintf(fid, '\n**Decision:** KEEP `K_zdot=0.50` (clear CTE benefit with gates OK).\n');
    else
        fprintf(fid, '\n**Decision:** DROP T5A term — production `K_zdot=0` (no clear benefit).\n');
    end

    if alpha_ran
        fprintf(fid, '\n## T5B-3 — alpha_hat trial\n\n');
        fprintf(fid, '| Mode | CTE | \\|pitch\\| | chatter | sat%% |\n');
        fprintf(fid, '|------|----:|---------:|--------:|------:|\n');
        fprintf(fid, '| no alpha | %.3f | %.2f | %.4f | %.1f |\n', ...
            ab(1 + keep_kzdot).mean_cte, ab(1 + keep_kzdot).mean_pitch_err_deg, ...
            ab(1 + keep_kzdot).pitch_chatter_dps, ab(1 + keep_kzdot).pct_mag_sat);
        fprintf(fid, '| alpha ON | %.3f | %.2f | %.4f | %.1f |\n', ...
            alpha_m.mean_cte, alpha_m.mean_pitch_err_deg, ...
            alpha_m.pitch_chatter_dps, alpha_m.pct_mag_sat);
        fprintf(fid, '\n**alpha:** %s\n', tern(cand.alpha,'KEPT','DROPPED'));
    else
        fprintf(fid, '\n## T5B-3 — alpha_hat\n\n');
        fprintf(fid, '**Skipped** (gates already met, or gamma not directional enough / STOP).\n');
    end

    if ran_suite
        fprintf(fid, '\n## Full suite @ Kg=%.2f, Kzdot=%.2f, alpha=%d, λ=0.25\n\n', ...
            cand.K_gamma, cand.K_zdot, cand.alpha);
        fprintf(fid, 'Regression baseline = Tur4A. Gate: X/circle/helix CTE ≤5%% worse.\n\n');
        fprintf(fid, '| Scenario | CTE now | CTE base | Δ%% | \\|pitch\\| | chatter |\n');
        fprintf(fid, '|----------|--------:|---------:|-----:|--------:|--------:|\n');
        print_suite_row(fid, 'X-line', sx, base.x_cte);
        print_suite_row(fid, 'XZ-line', sxz, base.xz_cte);
        print_suite_row(fid, 'Circle', sc, base.circle_cte);
        print_suite_row(fid, 'Helix', sh, base.helix_cte);
    else
        fprintf(fid, '\n## Full suite\n\n**Not run** — XZ candidate did not clear gates.\n');
    end

    fprintf(fid, '\n## Acceptance (XZ)\n\n');
    fprintf(fid, '| Check | Result |\n|-------|--------|\n');
    fprintf(fid, '| XZ CTE ≤ %.3f (≥15%% drop) | %s (%.3f) |\n', target, tern(cte_ok,'PASS','FAIL'), xz_cte);
    fprintf(fid, '| Prefer XZ CTE < 2.0 m | %s |\n', tern(prefer_ok,'PASS','FAIL'));
    fprintf(fid, '| \\|e_θ\\| < 0.8° | %s (%.2f) |\n', tern(pitch_ok,'PASS','FAIL'), xz_pitch);
    fprintf(fid, '| chatter < 0.12 °/s | %s (%.4f) |\n', tern(chat_ok,'PASS','FAIL'), xz_ch);
    fprintf(fid, '| no elevator sat | %s (%.1f%%) |\n', tern(sat_ok,'PASS','FAIL'), cand.pct_mag_sat);
    if ran_suite
        fprintf(fid, '| X/circle/helix CTE ≤5%% worse | %s |\n', tern(reg_ok,'PASS','FAIL'));
    else
        fprintf(fid, '| X/circle/helix CTE ≤5%% worse | n/a (suite skipped) |\n');
    end
    fprintf(fid, '| **Overall T5B** | **%s** |\n', tern(overall,'PASS','FAIL'));

    fprintf(fid, '\n## Verdict\n\n');
    if overall
        fprintf(fid, '**T5B PASS** — production: `K_gamma=%.2f`, `K_zdot=%.2f`, alpha=%s.\n', ...
            cand.K_gamma, cand.K_zdot, tern(cand.alpha,'ON','OFF'));
    elseif cte_ok && chat_ok && sat_ok && ~pitch_ok
        fprintf(fid, '**T5B PARTIAL** — CTE/chatter OK but \\|e_θ\\| still high (%.2f°).\n', xz_pitch);
        fprintf(fid, 'Recommend **coupled LQI** next (state [ez, ezdot, eθ, q, Iz]).\n');
    elseif drop < 10 && cand.mean_pitch_err_deg > 1.3
        fprintf(fid, '**T5B FAIL / STOP** — CTE improve only %.1f%% (<10%%) with \\|e_θ\\|~%.2f°.\n', ...
            drop, cand.mean_pitch_err_deg);
        fprintf(fid, 'More gain only raises chatter → STOP. Recommend **coupled LQI** ');
        fprintf(fid, '(state [ez, ezdot, eθ, q, Iz]).\n');
    else
        fprintf(fid, '**T5B FAIL** — best CTE=%.3f (need ≤%.3f). Gamma directional=%s.\n', ...
            xz_cte, target, tern(drop>=10,'yes','weak'));
        fprintf(fid, 'Recommend **coupled LQI** next (state [ez, ezdot, eθ, q, Iz]).\n');
    end

    fprintf(fid, '\n## NEXT queue (do NOT implement in this task)\n\n');
    fprintf(fid, '1. **Yaw ref smoothness** — yaw rises steadily but some refs do not.\n');
    fprintf(fid, '2. **R=5 speed scheduler** — if rudder-authority limited circle still needs work.\n');
    if ~overall
        fprintf(fid, '3. **Coupled LQI** — state [ez, ezdot, eθ, q, Iz] (T5B gates FAIL).\n');
    else
        fprintf(fid, '3. **LQI / SMC / NMPC** — only if later regression needs it.\n');
    end
    fprintf(fid, '\n');

    fprintf(fid, '## Files touched\n\n');
    fprintf(fid, '- `guidance_law.m` — gamma FB (+ optional alpha_hat), diagnostics globals\n');
    fprintf(fid, '- `continuous_path_tracking.m` — pass theta_phys; suite gamma logs\n');
    fprintf(fid, '- `init_parameters.m` — `K_gamma`, `enable_alpha_hat`; `K_zdot` default updated\n');
    fprintf(fid, '- `run_tur5b.m` — this runner\n');
    fclose(fid);
end

function print_suite_row(fid, name, s, base_cte)
    if isempty(s)
        fprintf(fid, '| %s | n/a | %.3f | n/a | n/a | n/a |\n', name, base_cte);
        return;
    end
    dlt = 100 * (s.mean_cross_track - base_cte) / max(base_cte, 1e-9);
    fprintf(fid, '| %s | %.3f | %.3f | %+.1f | %.2f | %.4f |\n', ...
        name, s.mean_cross_track, base_cte, dlt, s.mean_pitch_err_deg, s.pitch_chatter_dps);
end

function r = find_suite(suite, tag)
    r = [];
    if isempty(suite); return; end
    for i = 1:numel(suite)
        nm = suite(i).name;
        if strcmp(tag, 'x_line') && contains(nm, 'X cizgisi'); r = suite(i); return; end
        if strcmp(tag, 'xz_line') && contains(nm, 'XZ'); r = suite(i); return; end
        if strcmp(tag, 'circle') && contains(nm, 'daire'); r = suite(i); return; end
        if strcmp(tag, 'helix') && contains(lower(nm), 'heliks'); r = suite(i); return; end
    end
    idx = struct('x_line',1,'xz_line',2,'circle',3,'helix',4);
    if isfield(idx, tag) && numel(suite) >= idx.(tag)
        r = suite(idx.(tag));
    end
end

function s = tern(c, a, b)
    if c; s = a; else; s = b; end
end
