function run_pitch_xz_track()
% PITCH_XZ_TRACK_001 — production XZ-line pitch A/B (λ=0.25 vs 0). No gain/FF change.

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
    global dt_controller delta_e_max

    % Frozen production stack (identical to run_pitch_yaw_closure)
    elevator_sign = 1;
    trim_speed_table = [0.8 1.0 1.5 2.0];
    trim_elevator_table = deg2rad([-9.18 -7.33 -4.62 -3.17]);
    K_gamma = 0;
    K_zdot = 0;
    enable_alpha_hat = false;

    n = 900;
    tt = linspace(0, 42, n)';
    path = [tt, zeros(n,1), 0.4*tt];
    T_final = 22;
    u0 = 1.5;

    % Prior PITCH_CLOSURE baselines (hard gate + regression)
    base25 = struct('mae', 0.388, 'p95', 0.437, 'acq', 19.75, 'cte', 0.751, ...
        'elev_fb_rms', 5.133);
    base00 = struct('mae', 0.332, 'p95', NaN, 'acq', 15.05, 'cte', 0.572, ...
        'elev_fb_rms', 2.877);

    fprintf('\n========== PITCH_XZ_TRACK_001 ==========\n');
    fprintf('Production XZ A/B λ=0.25 vs 0 | no gain/FF change\n');

    lambda_muw_ff = 0.25;
    m25 = run_one_xz(path, T_final, u0, 0.25, base25);
    fprintf('λ=0.25  acq=%.2fs |eθ|_ss=%.4f p95=%.4f sat=%.2f%% CTE=%.3f\n', ...
        m25.acq_time_s, m25.steady.mae_deg, m25.steady.p95_deg, ...
        m25.elev_sat_pct, m25.cte_perp_sbe);

    lambda_muw_ff = 0.0;
    m00 = run_one_xz(path, T_final, u0, 0.0, base00);
    fprintf('λ=0     acq=%.2fs |eθ|_ss=%.4f p95=%.4f sat=%.2f%% CTE=%.3f\n', ...
        m00.acq_time_s, m00.steady.mae_deg, m00.steady.p95_deg, ...
        m00.elev_sat_pct, m00.cte_perp_sbe);

    % Baseline (λ=0.25) hard gates + regression; preferred MAE≤0.30 separate
    hard_mae = 0.40; hard_p95 = 0.50; hard_sat = 1.0;
    pref_mae = 0.30;
    g_mae = m25.steady.mae_deg <= hard_mae;
    g_p95 = m25.steady.p95_deg <= hard_p95;
    g_sat = m25.elev_sat_pct <= hard_sat;
    g_reg = m25.pass_regression && m00.pass_regression;
    pass = g_mae && g_p95 && g_sat && g_reg;
    pref25 = m25.steady.mae_deg <= pref_mae;
    pref00 = m00.steady.mae_deg <= pref_mae;

    % A/B winner: acquisition + steady |eθ| + elevator effort
    score = @(m) [m.acq_time_s, m.steady.mae_deg, m.elev_fb_rms_deg];
    s25 = score(m25); s00 = score(m00);
    % lexicographic: fewer worse axes wins; tie-break by sum of relative deltas
    better00 = (s00(1) < s25(1)) + (s00(2) < s25(2)) + (s00(3) < s25(3));
    better25 = (s25(1) < s00(1)) + (s25(2) < s00(2)) + (s25(3) < s00(3));
    if better00 > better25
        winner = 'λ=0';
    elseif better25 > better00
        winner = 'λ=0.25';
    else
        % relative sum
        rel = (s00 - s25) ./ max(abs(s25), 1e-9);
        if sum(rel) < 0; winner = 'λ=0'; else; winner = 'λ=0.25'; end
    end

    if ~pass
        if ~g_mae
            open_issue = sprintf('Baseline λ=0.25 steady MAE %.4f° > 0.40°', m25.steady.mae_deg);
        elseif ~g_p95
            open_issue = sprintf('Baseline λ=0.25 steady p95 %.4f° > 0.50°', m25.steady.p95_deg);
        elseif ~g_sat
            open_issue = sprintf('Baseline λ=0.25 elev sat %.2f%% > 1%%', m25.elev_sat_pct);
        else
            open_issue = 'Unexplained >2% deviation vs PITCH_CLOSURE baselines';
        end
    else
        open_issue = 'none';
    end

    root_cause = ['XZ climb signed eθ bias from level-tuned Muw FF (λ=0.25); ', ...
        'λ=0 reduces FF conflict → faster acq, lower |eθ| and elev effort. ', ...
        'No schedule applied this task.'];

    math_delta = sprintf(['ΔMAE_ss(λ.25)=%+.4f° (%.2f%% of 0.388); ', ...
        'ΔMAE_ss(λ0)=%+.4f° (%.2f%% of 0.332); ', ...
        'Δacq(.25)=%+.2fs Δacq(0)=%+.2fs; e=θ_ref-θ_phys'], ...
        m25.steady.mae_deg - base25.mae, ...
        100*(m25.steady.mae_deg - base25.mae)/base25.mae, ...
        m00.steady.mae_deg - base00.mae, ...
        100*(m00.steady.mae_deg - base00.mae)/base00.mae, ...
        m25.acq_time_s - base25.acq, m00.acq_time_s - base00.acq);

    % ---- PNG: comparative overlays ----
    fig = figure('Visible', 'off', 'Color', 'w', 'Position', [40 40 1300 980]);
    lim_deg = rad2deg(delta_e_max);
    L25 = m25.logs; L00 = m00.logs;

    subplot(3,2,1); hold on; grid on;
    plot(L25.t, rad2deg(L25.theta_ref), 'k-', 'LineWidth', 1.5);
    plot(L25.t, rad2deg(L25.theta_phys), 'b-', 'LineWidth', 1.1);
    plot(L00.t, rad2deg(L00.theta_phys), 'r-', 'LineWidth', 1.1);
    xline(m25.acq_time_s, 'b--', '\lambda.25 acq');
    xline(m00.acq_time_s, 'r--', '\lambda0 acq');
    ylabel('\theta [deg]'); xlabel('t [s]');
    title('\theta_{ref} + \theta(\lambda=.25/0)');
    legend({'\theta_{ref}', '\theta \lambda=.25', '\theta \lambda=0'}, 'Location', 'best');

    subplot(3,2,2); hold on; grid on;
    plot(L25.t, rad2deg(L25.e_th), 'b-', 'LineWidth', 1.1);
    plot(L00.t, rad2deg(L00.e_th), 'r-', 'LineWidth', 1.1);
    yline(0.5, 'k--'); yline(-0.5, 'k--'); yline(0, 'k:');
    xline(m25.acq_time_s, 'b--'); xline(m00.acq_time_s, 'r--');
    ylabel('e_\theta [deg]'); xlabel('t [s]');
    title('e_\theta (\lambda=.25 / 0)');
    legend({'e_\theta \lambda=.25', 'e_\theta \lambda=0'}, 'Location', 'best');

    subplot(3,2,3); hold on; grid on;
    plot(L25.t, rad2deg(L25.q), 'b-', 'LineWidth', 1.0);
    plot(L00.t, rad2deg(L00.q), 'r-', 'LineWidth', 1.0);
    xline(m25.acq_time_s, 'b--'); xline(m00.acq_time_s, 'r--');
    ylabel('q [deg/s]'); xlabel('t [s]');
    title('Pitch-rate q');
    legend({'q \lambda=.25', 'q \lambda=0'}, 'Location', 'best');

    subplot(3,2,4); hold on; grid on;
    plot(L25.t, rad2deg(L25.de), 'b-', 'LineWidth', 1.0);
    plot(L00.t, rad2deg(L00.de), 'r-', 'LineWidth', 1.0);
    yline(lim_deg, 'k--'); yline(-lim_deg, 'k--');
    xline(m25.acq_time_s, 'b--'); xline(m00.acq_time_s, 'r--');
    ylabel('\delta_e [deg]'); xlabel('t [s]');
    title(sprintf('Elevator + limits (\\pm%.1f°)', lim_deg));
    legend({'\delta_e \lambda=.25', '\delta_e \lambda=0'}, 'Location', 'best');

    subplot(3,2,5); hold on; grid on; axis equal;
    plot(path(:,1), path(:,3), 'k--', 'LineWidth', 1.3);
    plot(L25.vp(:,1), L25.vp(:,3), 'b-', 'LineWidth', 1.0);
    plot(L00.vp(:,1), L00.vp(:,3), 'r-', 'LineWidth', 1.0);
    xlabel('X [m]'); ylabel('Z [m]');
    title(sprintf('XZ path (CTE_{sbe} .25=%.3f / 0=%.3f m)', ...
        m25.cte_perp_sbe, m00.cte_perp_sbe));
    legend({'path', '\lambda=.25', '\lambda=0'}, 'Location', 'best');

    subplot(3,2,6); hold on; grid on;
    % Steady window markers: shade post-acq ∩ sbe for λ=0.25 as reference
    t25 = L25.t; msk = L25.mask_steady;
    if any(msk)
        area(t25(msk), ones(nnz(msk),1)*max(abs(rad2deg([L25.e_th; L00.e_th]))), ...
            'FaceColor', [0.85 0.9 1], 'EdgeColor', 'none', 'DisplayName', 'ss \lambda.25');
    end
    plot(L25.t, rad2deg(abs(L25.e_th)), 'b-', 'LineWidth', 1.1);
    plot(L00.t, rad2deg(abs(L00.e_th)), 'r-', 'LineWidth', 1.1);
    yline(0.40, 'k--', 'hard MAE'); yline(0.30, 'g--', 'pref MAE');
    xline(m25.acq_time_s, 'b--'); xline(m00.acq_time_s, 'r--');
    ylabel('|e_\theta| [deg]'); xlabel('t [s]');
    title(sprintf('acq/ss bounds | winner=%s | %s', winner, tern(pass,'PASS','FAIL')));
    legend({'ss window \lambda.25','|e| \lambda=.25','|e| \lambda=0'}, 'Location', 'best');

    sgtitle(sprintf(['PITCH_XZ_TRACK | %s | \\lambda.25 MAE=%.3f° p95=%.3f° | ', ...
        '\\lambda0 MAE=%.3f° | winner %s'], ...
        tern(pass,'PASS','FAIL'), m25.steady.mae_deg, m25.steady.p95_deg, ...
        m00.steady.mae_deg, winner));

    png_path = fullfile(out_dir, 'PITCH_XZ_TRACK.png');
    exportgraphics(fig, png_path, 'Resolution', 150);
    close(fig);

    % ---- MAT ----
    task = struct();
    task.task_id = 'PITCH_XZ_TRACK_001';
    task.pass = pass;
    task.winner = winner;
    task.preferred_closure_mae_lim = pref_mae;
    task.pref25 = pref25;
    task.pref00 = pref00;
    task.gates = struct('mae', g_mae, 'p95', g_p95, 'sat', g_sat, 'regression', g_reg);
    task.open_issue = open_issue;
    task.root_cause = root_cause;
    task.math_delta = math_delta;
    task.base25 = base25;
    task.base00 = base00;
    mat_path = fullfile(out_dir, 'PITCH_XZ_TRACK.mat');
    save(mat_path, 'task', 'm25', 'm00', 'path', 'T_final', 'u0');

    % ---- MD ----
    md_path = fullfile(out_dir, 'PITCH_XZ_TRACK.md');
    fid = fopen(md_path, 'w');
    fprintf(fid, '# PITCH_XZ_TRACK\n\n');
    fprintf(fid, '**TASK_ID:** PITCH_XZ_TRACK_001\n');
    fprintf(fid, '**Date:** %s\n', datestr(now, 31));
    fprintf(fid, '**Verdict:** **%s**\n', tern(pass,'PASS','FAIL'));
    fprintf(fid, '**A/B winner:** **%s** (acq + steady |eθ| + elev effort)\n', winner);
    fprintf(fid, '**Preferred closure MAE≤0.30°:** λ=.25 %s (%.4f°); λ=0 %s (%.4f°) — not applied\n\n', ...
        tern(pref25,'MET','NOT MET'), m25.steady.mae_deg, ...
        tern(pref00,'MET','NOT MET'), m00.steady.mae_deg);
    fprintf(fid, 'Production XZ-line, frozen gains, Tur4A/T25, K_γ=K_ż=0. No code/gain change.\n');
    fprintf(fid, 'Windows: settling = earliest t with |eθ|≤±0.5° for remainder of valid ');
    fprintf(fid, 'interval (s<0.88 s_path); acq=[start,settle], steady=[settle,end-excl]; ');
    fprintf(fid, 'NaN settle => FAIL.\n\n');

    fprintf(fid, '## A/B short table\n\n');
    fprintf(fid, '| Metric | λ=0.25 | λ=0 |\n|--------|-------:|----:|\n');
    fprintf(fid, '| acq time [s] | %.2f | %.2f |\n', m25.acq_time_s, m00.acq_time_s);
    fprintf(fid, '| steady MAE [°] | %.4f | %.4f |\n', m25.steady.mae_deg, m00.steady.mae_deg);
    fprintf(fid, '| steady p95 [°] | %.4f | %.4f |\n', m25.steady.p95_deg, m00.steady.p95_deg);
    fprintf(fid, '| steady signed [°] | %+.4f | %+.4f |\n', m25.steady.signed_deg, m00.steady.signed_deg);
    fprintf(fid, '| elev fb RMS [°] | %.3f | %.3f |\n', m25.elev_fb_rms_deg, m00.elev_fb_rms_deg);
    fprintf(fid, '| elev sat%% | %.2f | %.2f |\n', m25.elev_sat_pct, m00.elev_sat_pct);
    fprintf(fid, '| q ripple RMS [°/s] | %.4f | %.4f |\n', m25.q_ripple_rms_dps, m00.q_ripple_rms_dps);
    fprintf(fid, '| CTE_perp sbe [m] | %.3f | %.3f |\n\n', m25.cte_perp_sbe, m00.cte_perp_sbe);

    write_case_md(fid, 'λ=0.25 (production baseline)', m25);
    write_case_md(fid, 'λ=0', m00);

    fprintf(fid, '## PASS gates (baseline λ=0.25)\n\n');
    fprintf(fid, '| Gate | Result | Detail |\n|------|:------:|--------|\n');
    fprintf(fid, '| steady MAE ≤0.40° | %s | %.4f° |\n', yn(g_mae), m25.steady.mae_deg);
    fprintf(fid, '| steady p95 ≤0.50° | %s | %.4f° |\n', yn(g_p95), m25.steady.p95_deg);
    fprintf(fid, '| elev sat ≤1%% | %s | %.2f%% |\n', yn(g_sat), m25.elev_sat_pct);
    fprintf(fid, '| no >2%% unexplained vs PITCH_CLOSURE | %s | see deltas |\n\n', yn(g_reg));

    fprintf(fid, '## Open issue\n\n%s\n\n', open_issue);
    fprintf(fid, '## Root-cause hypothesis\n\n%s\n\n', root_cause);
    fprintf(fid, '## MATHEMATICAL_DELTA\n\n%s\n\n', math_delta);
    fprintf(fid, '## Files\n\n');
    fprintf(fid, '- `suite_results/PITCH_XZ_TRACK.md`\n');
    fprintf(fid, '- `suite_results/PITCH_XZ_TRACK.mat`\n');
    fprintf(fid, '- `suite_results/PITCH_XZ_TRACK.png`\n');
    fclose(fid);

    fprintf('\nVERDICT: %s | winner: %s\n', tern(pass,'PASS','FAIL'), winner);
    fprintf('Preferred ≤0.30°: λ.25=%s λ0=%s\n', tern(pref25,'MET','NOT'), tern(pref00,'MET','NOT'));
    fprintf('Wrote %s\nWrote %s\nWrote %s\n', md_path, mat_path, png_path);
end

function m = run_one_xz(path, T_final, u0, lam, base)
    global dt_controller delta_e_max
    global suite_delta_e_log suite_de_fb_log
    global lambda_muw_ff

    lambda_muw_ff = lam;
    clear guidance_law controller_law
    dt = dt_controller;
    state0 = zeros(12,1);
    state0(1:3) = path(1,:)';
    d = path(2,:) - path(1,:);
    state0(5) = -atan2(d(3), norm(d(1:2)));
    state0(6) = atan2(d(2), d(1));
    state0(7) = u0;

    [vp, times, vel, rates, ori, ~, yaw_refs, pitch_refs, ~] = ...
        continuous_path_tracking(path, state0, dt, T_final); %#ok<ASGLU>
    pm = compute_path_following_metrics(path, vp, vel, ori, yaw_refs, pitch_refs, dt, times);

    t = times(:);
    theta_ref = pitch_refs(:);
    theta_phys = -ori(:,2);
    e_th = theta_ref - theta_phys;
    q = rates(:,2);
    s = pm.s_prog(:);
    s_total = pm.s_total;

    de = suite_delta_e_log(:);
    de_fb = suite_de_fb_log(:);
    if isempty(de); de = zeros(size(t)); end
    if isempty(de_fb); de_fb = de; end
    if numel(de) ~= numel(t)
        de = de(1:min(end,numel(t)));
        if numel(de) < numel(t); de(end+1:numel(t),1) = de(end); end
    end
    if numel(de_fb) ~= numel(t)
        de_fb = de_fb(1:min(end,numel(t)));
        if numel(de_fb) < numel(t); de_fb(end+1:numel(t),1) = de_fb(end); end
    end

    % Acquisition / steady: persistent ±0.5° settle to end-exclusion (see
    % compute_pitch_window_metrics). Legacy first-hold retained via mode flag.
    W = compute_pitch_window_metrics(t, e_th, s, s_total, 'mode', 'persistent');
    mask_acq = W.mask_acq;
    mask_steady = W.mask_steady;
    mask_sbe = (t >= 5.0) & W.mask_before_end; % CTE/legacy SBE diagnostic only

    th_dot = [0; diff(theta_phys)] / dt;
    q_ref = [0; diff(theta_ref)] / dt;
    de_rate = [0; diff(de)] / dt;
    lim = delta_e_max;

    m = struct();
    m.lambda_muw_ff = lam;
    m.acq_time_s = W.acq_time_s;
    m.n_acq = W.n_acq;
    m.n_steady = W.n_steady;
    m.acq = W.acq;
    m.steady = W.steady;
    m.sbe = eth_stats(e_th(mask_sbe));
    m.window_mode = W.mode;
    m.persistent_ok = W.persistent_ok;

    % Dip / overshoot / lag (acquisition into climb)
    path_pitch = atan2(0.4, 1);
    if any(mask_acq)
        th_acq = theta_phys(mask_acq);
        m.dip_deg = rad2deg(path_pitch - min(th_acq));
        m.min_theta_acq_deg = rad2deg(min(th_acq));
    else
        th_acq = [];
        m.dip_deg = NaN;
        m.min_theta_acq_deg = NaN;
    end
    if any(mask_steady) && ~isempty(th_acq)
        final_ref = mean(theta_ref(mask_steady));
        overshoot = max(0, max(th_acq) - final_ref);
        m.overshoot_deg = rad2deg(overshoot);
        m.lag_mean_deg = rad2deg(mean(e_th(mask_steady)));
        m.lag_rms_deg = rad2deg(rms(e_th(mask_steady)));
    else
        m.overshoot_deg = NaN;
        m.lag_mean_deg = NaN;
        m.lag_rms_deg = NaN;
    end
    m.settling_s = m.acq_time_s;

    % Pitch-rate ripple (steady)
    if any(mask_steady)
        m.q_ripple_rms_dps = rad2deg(rms(q(mask_steady) - mean(q(mask_steady))));
        m.q_rms_dps = rad2deg(rms(q(mask_steady)));
        m.rate_track_mae_dps = rad2deg(mean(abs(q_ref(mask_steady) - q(mask_steady))));
        de_ss = de(mask_steady);
        m.elev_mean_deg = rad2deg(mean(de_ss));
        m.elev_rms_deg = rad2deg(rms(de_ss));
        m.elev_rate_rms_dps = rad2deg(rms(de_rate(mask_steady)));
        m.elev_sat_pct = 100 * mean(abs(de_ss) >= 0.98 * lim);
        m.elev_near_limit_pct = 100 * mean(abs(de_ss) >= 0.90 * lim);
        m.elev_fb_rms_deg = rad2deg(rms(de_fb(mask_steady)));
        dth_ss = th_dot(mask_steady);
        if numel(dth_ss) < 5
            m.chatter_dps = pm.pitch_chatter_dps;
        else
            m.chatter_dps = rad2deg(std(hf_local(detrend(dth_ss), dt)));
        end
    else
        m.q_ripple_rms_dps = NaN;
        m.q_rms_dps = NaN;
        m.rate_track_mae_dps = NaN;
        m.elev_mean_deg = NaN;
        m.elev_rms_deg = NaN;
        m.elev_rate_rms_dps = NaN;
        m.elev_sat_pct = NaN;
        m.elev_near_limit_pct = NaN;
        m.elev_fb_rms_deg = NaN;
        m.chatter_dps = NaN;
    end

    m.cte_perp_sbe = pm.mean_cte_perp;
    m.path_pitch_deg = rad2deg(path_pitch);

    % Regression vs prior: MAE and acq within 2% (or absolute 0.01° / 0.3 s floor)
    mae_lim = max(base.mae * 1.02, base.mae + 0.01);
    acq_lim = max(base.acq * 1.02, base.acq + 0.30);
    g_mae_reg = ~isnan(m.steady.mae_deg) && (m.steady.mae_deg <= mae_lim);
    g_acq_reg = ~isnan(m.acq_time_s) && (m.acq_time_s <= acq_lim);
    if ~isnan(base.p95)
        p95_lim = max(base.p95 * 1.02, base.p95 + 0.01);
        g_p95_reg = m.steady.p95_deg <= p95_lim;
    else
        g_p95_reg = true;
        p95_lim = NaN;
    end
    m.pass_regression = g_mae_reg && g_acq_reg && g_p95_reg;
    m.reg = struct('mae_lim', mae_lim, 'acq_lim', acq_lim, 'p95_lim', p95_lim, ...
        'g_mae', g_mae_reg, 'g_acq', g_acq_reg, 'g_p95', g_p95_reg);

    m.logs = struct('t', t, 'theta_ref', theta_ref, 'theta_phys', theta_phys, ...
        'e_th', e_th, 'q', q, 'q_ref', q_ref, 'de', de, 'de_fb', de_fb, ...
        'vp', vp, 'mask_acq', mask_acq, 'mask_steady', mask_steady, ...
        'mask_sbe', mask_sbe);
    m.pm = pm;
end

function write_case_md(fid, title, m)
    fprintf(fid, '## %s\n\n', title);
    fprintf(fid, '### Acquisition\n\n');
    fprintf(fid, '| Metric | Value |\n|--------|------:|\n');
    fprintf(fid, '| acq / settling [s] | %.2f |\n', m.acq_time_s);
    fprintf(fid, '| signed / MAE / RMS | %+.4f / %.4f / %.4f° |\n', ...
        m.acq.signed_deg, m.acq.mae_deg, m.acq.rms_deg);
    fprintf(fid, '| p95 / max\\|e\\| | %.4f / %.4f° |\n', m.acq.p95_deg, m.acq.max_deg);
    fprintf(fid, '| dip (path−minθ) | %.4f° |\n', m.dip_deg);
    fprintf(fid, '| overshoot | %.4f° |\n', m.overshoot_deg);
    fprintf(fid, '| min θ_acq | %.4f° |\n\n', m.min_theta_acq_deg);

    fprintf(fid, '### Steady\n\n');
    fprintf(fid, '| Metric | Value |\n|--------|------:|\n');
    fprintf(fid, '| signed / MAE / RMS | %+.4f / %.4f / %.4f° |\n', ...
        m.steady.signed_deg, m.steady.mae_deg, m.steady.rms_deg);
    fprintf(fid, '| p95 / max\\|e\\| | %.4f / %.4f° |\n', m.steady.p95_deg, m.steady.max_deg);
    fprintf(fid, '| lag mean / RMS | %+.4f / %.4f° |\n', m.lag_mean_deg, m.lag_rms_deg);
    fprintf(fid, '| q ripple RMS | %.4f °/s |\n', m.q_ripple_rms_dps);
    fprintf(fid, '| rate track MAE | %.4f °/s |\n', m.rate_track_mae_dps);
    fprintf(fid, '| chatter | %.4f °/s |\n', m.chatter_dps);
    fprintf(fid, '| elev mean / RMS / fbRMS | %+.3f / %.3f / %.3f° |\n', ...
        m.elev_mean_deg, m.elev_rms_deg, m.elev_fb_rms_deg);
    fprintf(fid, '| elev rate RMS | %.3f °/s |\n', m.elev_rate_rms_dps);
    fprintf(fid, '| elev near-limit%% / sat%% | %.2f / %.2f |\n', ...
        m.elev_near_limit_pct, m.elev_sat_pct);
    fprintf(fid, '| CTE_perp settled_before_end | %.4f m |\n\n', m.cte_perp_sbe);
end

function s = eth_stats(e)
    if isempty(e)
        s = struct('mae_deg',NaN,'rms_deg',NaN,'signed_deg',NaN,'p95_deg',NaN,'max_deg',NaN);
        return;
    end
    s = struct( ...
        'mae_deg', rad2deg(mean(abs(e))), ...
        'rms_deg', rad2deg(rms(e)), ...
        'signed_deg', rad2deg(mean(e)), ...
        'p95_deg', rad2deg(pctile95(abs(e))), ...
        'max_deg', rad2deg(max(abs(e))));
end

function y = hf_local(x, dt)
    n = max(3, round(0.8 / dt));
    lf = filter(ones(n,1)/n, 1, x(:));
    y = x(:) - lf;
    y(1:min(n,numel(y))) = 0;
end

function v = pctile95(x)
    x = sort(x(:));
    if isempty(x); v = NaN; return; end
    k = max(1, min(numel(x), ceil(0.95 * numel(x))));
    v = x(k);
end

function s = yn(tf)
    if tf; s = 'YES'; else; s = 'NO'; end
end

function s = tern(tf, a, b)
    if tf; s = a; else; s = b; end
end
