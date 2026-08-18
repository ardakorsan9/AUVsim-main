function run_pitch_x_track()
% PITCH_X_TRACK_001 — production X-line pitch track re-measure (no gain/FF change)

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
    global suite_delta_e_log suite_de_fb_log

    % Frozen production stack (identical to run_pitch_yaw_closure)
    elevator_sign = 1;
    trim_speed_table = [0.8 1.0 1.5 2.0];
    trim_elevator_table = deg2rad([-9.18 -7.33 -4.62 -3.17]);
    K_gamma = 0;
    K_zdot = 0;
    enable_alpha_hat = false;
    lambda_muw_ff = 0.25;

    n = 600;
    x = linspace(0, 45, n)';
    path = [x, zeros(n,1), zeros(n,1)];
    T_final = 18;
    u0 = 1.5;
    dt = dt_controller;

    clear guidance_law controller_law
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
    q = rates(:,2); % body pitch rate
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

    % Acquisition: |eθ| in ±0.5° for 1.0 s (cap 6 s) — same as PITCH_CLOSURE
    band = deg2rad(0.5);
    hold_n = max(1, round(1.0 / dt));
    acq_end = numel(t);
    in_band = abs(e_th) <= band;
    for k = 1:(numel(t) - hold_n)
        if all(in_band(k:k+hold_n-1))
            acq_end = k + hold_n - 1;
            break;
        end
    end
    acq_cap = min(numel(t), round(6.0 / dt));
    if acq_end > acq_cap && ~any(in_band(1:acq_cap))
        acq_end = acq_cap;
    end
    mask_acq = (1:numel(t))' <= acq_end;

    % Open-path settled_before_end + post-acquisition steady
    mask_sbe = (t >= 5.0) & (s < 0.88 * s_total);
    mask_steady = mask_sbe & ~mask_acq;
    if ~any(mask_steady)
        mask_steady = mask_sbe;
    end

    % theta_dot from phys; q_ref ≈ pitch_ref_dot via finite diff of theta_ref
    th_dot = [0; diff(theta_phys)] / dt;
    q_ref = [0; diff(theta_ref)] / dt;

    m = struct();
    m.task_id = 'PITCH_X_TRACK_001';
    m.lambda_muw_ff = 0.25;
    m.baseline_mae_deg = 0.064;
    m.acq_time_s = t(acq_end);
    m.n_acq = nnz(mask_acq);
    m.n_steady = nnz(mask_steady);
    m.n_sbe = nnz(mask_sbe);

    m.acq = eth_stats(e_th(mask_acq));
    m.steady = eth_stats(e_th(mask_steady));
    m.sbe = eth_stats(e_th(mask_sbe)); % comparable to PITCH_CLOSURE X check

    % Settling / overshoot / lag on acquisition window into steady
    m.settling_s = m.acq_time_s;
    if any(mask_steady)
        e_ss = e_th(mask_steady);
        th_ss = theta_phys(mask_steady);
        tr_ss = theta_ref(mask_steady);
        % overshoot vs final steady mean ref (level ~0)
        final_ref = mean(tr_ss);
        if abs(final_ref) < 1e-6
            % level: overshoot = max |theta_phys| beyond band during acq
            m.overshoot_deg = rad2deg(max(abs(theta_phys(mask_acq))));
        else
            pk = max(abs(th_ss - final_ref));
            m.overshoot_deg = rad2deg(pk);
        end
        % lag: mean signed (theta_ref - theta_phys) as phase lag proxy
        m.lag_mean_deg = rad2deg(mean(e_ss));
        m.lag_rms_deg = rad2deg(rms(e_ss));
    else
        m.overshoot_deg = NaN;
        m.lag_mean_deg = NaN;
        m.lag_rms_deg = NaN;
    end

    % Rate ripple (steady)
    m.q_ripple_rms_dps = rad2deg(rms(q(mask_steady) - mean(q(mask_steady))));
    m.q_rms_dps = rad2deg(rms(q(mask_steady)));
    m.theta_dot_rms_dps = rad2deg(rms(th_dot(mask_steady)));
    m.q_ref_rms_dps = rad2deg(rms(q_ref(mask_steady)));
    m.rate_track_mae_dps = rad2deg(mean(abs(q_ref(mask_steady) - q(mask_steady))));

    % Elevator (steady)
    de_ss = de(mask_steady);
    de_rate = [0; diff(de)] / dt;
    lim = delta_e_max;
    m.elev_mean_deg = rad2deg(mean(de_ss));
    m.elev_rms_deg = rad2deg(rms(de_ss));
    m.elev_rate_rms_dps = rad2deg(rms(de_rate(mask_steady)));
    m.elev_sat_pct = 100 * mean(abs(de_ss) >= 0.98 * lim);
    m.elev_near_limit_pct = 100 * mean(abs(de_ss) >= 0.90 * lim);
    dth_ss = th_dot(mask_steady);
    if numel(dth_ss) < 5
        m.chatter_dps = pm.pitch_chatter_dps;
    else
        m.chatter_dps = rad2deg(std(hf_local(detrend(dth_ss), dt)));
    end
    if ~isempty(de_fb) && numel(de_fb) == numel(t)
        m.elev_fb_rms_deg = rad2deg(rms(de_fb(mask_steady)));
    else
        m.elev_fb_rms_deg = m.elev_rms_deg;
    end

    m.cte_perp_sbe = pm.mean_cte_perp;
    m.cte_perp_steady = NaN;
    if any(mask_steady)
        % recompute CTE on steady samples via path projection already in pm logs if available
        % use overall sbe CTE from shared metrics (correct open-path window)
        m.cte_perp_steady = m.cte_perp_sbe;
    end

    % Oscillation flag: HF chatter + signed zero-cross density in steady
    e_ss = e_th(mask_steady);
    zc = sum(e_ss(1:end-1) .* e_ss(2:end) < 0);
    zc_rate = zc / max(t(find(mask_steady,1,'last')) - t(find(mask_steady,1,'first')), eps);
    m.zero_cross_per_s = zc_rate;
    m.visible_oscillation = (m.chatter_dps > 0.08) || (zc_rate > 2.0 && m.steady.mae_deg > 0.05);

    % PASS gates
    mae_lim = 0.10;
    p95_lim = 0.20;
    sat_lim = 1.0;
    reg_lim = m.baseline_mae_deg * 1.02; % >2% regression fail
    % Compare regression to same window as baseline (sbe MAE)
    compare_mae = m.sbe.mae_deg;
    g_mae = m.steady.mae_deg <= mae_lim;
    g_p95 = m.steady.p95_deg <= p95_lim;
    g_sat = m.elev_sat_pct <= sat_lim;
    g_osc = ~m.visible_oscillation;
    g_reg = compare_mae <= reg_lim;
    m.pass = g_mae && g_p95 && g_sat && g_osc && g_reg;
    m.gates = struct('mae', g_mae, 'p95', g_p95, 'sat', g_sat, ...
        'no_osc', g_osc, 'no_regression', g_reg, ...
        'compare_mae_sbe', compare_mae, 'reg_lim', reg_lim);

    if ~m.pass
        if ~g_reg
            m.open_issue = sprintf(['Baseline mismatch/regression: sbe MAE=%.4f° vs prior ', ...
                '%.3f° (lim %.4f°). No code change — FAIL if unreproducible.'], ...
                compare_mae, m.baseline_mae_deg, reg_lim);
        elseif ~g_mae
            m.open_issue = sprintf('Steady MAE %.3f° > 0.10°', m.steady.mae_deg);
        elseif ~g_p95
            m.open_issue = sprintf('Steady p95 %.3f° > 0.20°', m.steady.p95_deg);
        elseif ~g_sat
            m.open_issue = sprintf('Elevator sat %.2f%% > 1%%', m.elev_sat_pct);
        else
            m.open_issue = 'Visible steady oscillation detected';
        end
    else
        m.open_issue = 'none';
    end

    % MATHEMATICAL_DELTA vs baseline
    m.math_delta = sprintf(['ΔMAE_sbe=%.4f° (%.2f%% of 0.064°); steady MAE=%.4f°; ', ...
        'signed_ss=%+.4f°; e=θ_ref-θ_phys'], ...
        compare_mae - m.baseline_mae_deg, ...
        100*(compare_mae - m.baseline_mae_deg)/m.baseline_mae_deg, ...
        m.steady.mae_deg, m.steady.signed_deg);

    % ---- PNG ----
    fig = figure('Visible', 'off', 'Color', 'w', 'Position', [50 50 1200 900]);
    lim_deg = rad2deg(lim);

    subplot(3,2,1); hold on; grid on;
    plot(t, rad2deg(theta_ref), 'b-', 'LineWidth', 1.4);
    plot(t, rad2deg(theta_phys), 'r-', 'LineWidth', 1.1);
    xline(m.acq_time_s, 'k--', 'acq', 'LabelVerticalAlignment', 'bottom');
    ylabel('\theta [deg]'); xlabel('t [s]');
    title('\theta_{ref} vs \theta_{phys}');
    legend({'\theta_{ref}', '\theta_{phys}'}, 'Location', 'best');

    subplot(3,2,2); hold on; grid on;
    plot(t, rad2deg(e_th), 'k-', 'LineWidth', 1.1);
    yline(0, 'b-');
    yline(0.5, 'r--'); yline(-0.5, 'r--');
    xline(m.acq_time_s, 'k--');
    ylabel('e_\theta [deg]'); xlabel('t [s]');
    title('e_\theta = \theta_{ref}-\theta_{phys}');

    subplot(3,2,3); hold on; grid on;
    plot(t, rad2deg(q), 'r-', 'LineWidth', 1.0);
    plot(t, rad2deg(q_ref), 'b--', 'LineWidth', 1.0);
    xline(m.acq_time_s, 'k--');
    ylabel('rate [deg/s]'); xlabel('t [s]');
    title('Pitch rate q vs q_{ref}\approx d\theta_{ref}/dt');
    legend({'q', 'q_{ref}'}, 'Location', 'best');

    subplot(3,2,4); hold on; grid on;
    plot(t, rad2deg(de), 'k-', 'LineWidth', 1.1);
    yline(lim_deg, 'r--'); yline(-lim_deg, 'r--');
    xline(m.acq_time_s, 'k--');
    ylabel('\delta_e [deg]'); xlabel('t [s]');
    title(sprintf('Elevator + limits (\\pm%.1f°)', lim_deg));

    subplot(3,2,5); hold on; grid on; axis equal;
    plot(path(:,1), path(:,2), 'b--', 'LineWidth', 1.2);
    plot(vp(:,1), vp(:,2), 'r-', 'LineWidth', 1.0);
    xlabel('X [m]'); ylabel('Y [m]');
    title(sprintf('XY path (CTE_{perp,sbe}=%.3f m)', m.cte_perp_sbe));
    legend({'path', 'vehicle'}, 'Location', 'best');

    subplot(3,2,6); hold on; grid on; axis equal;
    plot(path(:,1), path(:,3), 'b--', 'LineWidth', 1.2);
    plot(vp(:,1), vp(:,3), 'r-', 'LineWidth', 1.0);
    xlabel('X [m]'); ylabel('Z [m]');
    title('XZ path overlay');
    legend({'path', 'vehicle'}, 'Location', 'best');

    sgtitle(sprintf('PITCH_X_TRACK | %s | steady MAE=%.3f° p95=%.3f° sat=%.1f%%', ...
        tern(m.pass,'PASS','FAIL'), m.steady.mae_deg, m.steady.p95_deg, m.elev_sat_pct));

    png_path = fullfile(out_dir, 'PITCH_X_TRACK.png');
    exportgraphics(fig, png_path, 'Resolution', 150);
    close(fig);

    % ---- MAT ----
    logs = struct('t', t, 'theta_ref', theta_ref, 'theta_phys', theta_phys, ...
        'e_th', e_th, 'q', q, 'q_ref', q_ref, 'de', de, 'vp', vp, 'path', path, ...
        'mask_acq', mask_acq, 'mask_steady', mask_steady, 'mask_sbe', mask_sbe);
    mat_path = fullfile(out_dir, 'PITCH_X_TRACK.mat');
    save(mat_path, 'm', 'logs', 'pm');

    % ---- MD ----
    md_path = fullfile(out_dir, 'PITCH_X_TRACK.md');
    fid = fopen(md_path, 'w');
    fprintf(fid, '# PITCH_X_TRACK\n\n');
    fprintf(fid, '**TASK_ID:** PITCH_X_TRACK_001\n');
    fprintf(fid, '**Date:** %s\n', datestr(now, 31));
    fprintf(fid, '**Verdict:** **%s**\n\n', tern(m.pass,'PASS','FAIL'));
    fprintf(fid, 'Production X-line, λ=0.25, yaw frozen, no gain/FF change.\n');
    fprintf(fid, 'Acquisition: |eθ| in ±0.5° for 1 s (cap 6 s).\n');
    fprintf(fid, 'Steady: post-acq AND settled_before_end (t≥5 s, s<0.88 s_path).\n\n');

    fprintf(fid, '## Headline metrics\n\n');
    fprintf(fid, '| # | Metric | Value |\n|---|--------|------:|\n');
    fprintf(fid, '| 1 | steady MAE \\|eθ\\| | %.4f° |\n', m.steady.mae_deg);
    fprintf(fid, '| 2 | steady p95 \\|eθ\\| | %.4f° |\n', m.steady.p95_deg);
    fprintf(fid, '| 3 | steady signed eθ | %+.4f° |\n', m.steady.signed_deg);
    fprintf(fid, '| 4 | elev sat%% steady | %.2f |\n', m.elev_sat_pct);
    fprintf(fid, '| 5 | sbe MAE (vs baseline 0.064°) | %.4f° |\n', m.sbe.mae_deg);
    fprintf(fid, '| 6 | CTE_perp sbe | %.4f m |\n\n', m.cte_perp_sbe);

    fprintf(fid, '## Acquisition\n\n');
    fprintf(fid, '| Metric | Value |\n|--------|------:|\n');
    fprintf(fid, '| acq time | %.2f s |\n', m.acq_time_s);
    fprintf(fid, '| MAE | %.4f° |\n', m.acq.mae_deg);
    fprintf(fid, '| RMS | %.4f° |\n', m.acq.rms_deg);
    fprintf(fid, '| signed | %+.4f° |\n', m.acq.signed_deg);
    fprintf(fid, '| p95 | %.4f° |\n', m.acq.p95_deg);
    fprintf(fid, '| max\\|e\\| | %.4f° |\n', m.acq.max_deg);
    fprintf(fid, '| overshoot proxy | %.4f° |\n\n', m.overshoot_deg);

    fprintf(fid, '## Steady\n\n');
    fprintf(fid, '| Metric | Value |\n|--------|------:|\n');
    fprintf(fid, '| MAE | %.4f° |\n', m.steady.mae_deg);
    fprintf(fid, '| RMS | %.4f° |\n', m.steady.rms_deg);
    fprintf(fid, '| signed | %+.4f° |\n', m.steady.signed_deg);
    fprintf(fid, '| p95 | %.4f° |\n', m.steady.p95_deg);
    fprintf(fid, '| max\\|e\\| | %.4f° |\n', m.steady.max_deg);
    fprintf(fid, '| lag mean / RMS | %+.4f / %.4f° |\n', m.lag_mean_deg, m.lag_rms_deg);
    fprintf(fid, '| q ripple RMS | %.4f °/s |\n', m.q_ripple_rms_dps);
    fprintf(fid, '| rate track MAE \\|q_ref-q\\| | %.4f °/s |\n', m.rate_track_mae_dps);
    fprintf(fid, '| chatter | %.4f °/s |\n', m.chatter_dps);
    fprintf(fid, '| elev mean / RMS | %+.3f / %.3f° |\n', m.elev_mean_deg, m.elev_rms_deg);
    fprintf(fid, '| elev rate RMS | %.3f °/s |\n', m.elev_rate_rms_dps);
    fprintf(fid, '| elev near-limit%% / sat%% | %.2f / %.2f |\n', m.elev_near_limit_pct, m.elev_sat_pct);
    fprintf(fid, '| visible oscillation | %s |\n\n', tern(m.visible_oscillation,'YES','NO'));

    fprintf(fid, '## PASS gates\n\n');
    fprintf(fid, '| Gate | Result | Detail |\n|------|:------:|--------|\n');
    fprintf(fid, '| steady MAE ≤0.10° | %s | %.4f° |\n', yn(g_mae), m.steady.mae_deg);
    fprintf(fid, '| steady p95 ≤0.20° | %s | %.4f° |\n', yn(g_p95), m.steady.p95_deg);
    fprintf(fid, '| elev sat ≤1%% | %s | %.2f%% |\n', yn(g_sat), m.elev_sat_pct);
    fprintf(fid, '| no visible ss oscillation | %s | chat=%.4f zc/s=%.2f |\n', ...
        yn(g_osc), m.chatter_dps, m.zero_cross_per_s);
    fprintf(fid, '| no >2%% regression vs 0.064° | %s | sbe MAE=%.4f° lim=%.4f° |\n\n', ...
        yn(g_reg), compare_mae, reg_lim);

    fprintf(fid, '## Open issue\n\n%s\n\n', m.open_issue);
    fprintf(fid, '## MATHEMATICAL_DELTA\n\n%s\n\n', m.math_delta);
    fprintf(fid, '## Files\n\n');
    fprintf(fid, '- `suite_results/PITCH_X_TRACK.md`\n');
    fprintf(fid, '- `suite_results/PITCH_X_TRACK.mat`\n');
    fprintf(fid, '- `suite_results/PITCH_X_TRACK.png`\n');
    fclose(fid);

    fprintf('\n========== PITCH_X_TRACK ==========\n');
    fprintf('VERDICT: %s\n', tern(m.pass,'PASS','FAIL'));
    fprintf('steady MAE=%.4f  p95=%.4f  signed=%+.4f  sat=%.2f%%  sbe_MAE=%.4f  CTE=%.4f\n', ...
        m.steady.mae_deg, m.steady.p95_deg, m.steady.signed_deg, ...
        m.elev_sat_pct, m.sbe.mae_deg, m.cte_perp_sbe);
    fprintf('Wrote %s\n', md_path);
    fprintf('Wrote %s\n', mat_path);
    fprintf('Wrote %s\n', png_path);
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
