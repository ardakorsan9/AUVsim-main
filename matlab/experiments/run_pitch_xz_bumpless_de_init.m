function run_pitch_xz_bumpless_de_init()
% PITCH_XZ_BUMPLESS_DE_INIT_001 — seed elevator RL state at de_trim(u0).
% One deterministic XZ λ=0 run; same windows as PITCH_XZ_TRACK λ=0 baseline.
% Production change under test: controller_law prev_delta_e := de_trim (was 0).
% Outputs: suite_results/PITCH_XZ_BUMPLESS_DE_INIT.{md,mat,png}

    project_dir = fileparts(fileparts(fileparts(mfilename('fullpath')))); % repo root
    addpath(genpath(fullfile(project_dir, 'matlab')));
    out_dir = fullfile(project_dir, 'suite_results');
    if ~exist(out_dir, 'dir'); mkdir(out_dir); end
    tag = 'PITCH_XZ_BUMPLESS_DE_INIT';

    clear functions
    clear guidance_law controller_law
    clear global lambda_muw_ff trim_speed_table trim_elevator_table elevator_sign
    clear global K_zdot K_gamma enable_alpha_hat

    init_parameters();
    global lambda_muw_ff elevator_sign trim_speed_table trim_elevator_table
    global K_zdot K_gamma enable_alpha_hat
    global dt_controller delta_e_max

    % Frozen production stack (identical to PITCH_XZ_TRACK λ=0)
    elevator_sign = 1;
    trim_speed_table = [0.8 1.0 1.5 2.0];
    trim_elevator_table = deg2rad([-9.18 -7.33 -4.62 -3.17]);
    K_gamma = 0;
    K_zdot = 0;
    enable_alpha_hat = false;
    lambda_muw_ff = 0.0;

    n = 900;
    tt = linspace(0, 42, n)';
    path = [tt, zeros(n,1), 0.4*tt];
    T_final = 22;
    u0 = 1.5;

    % Baseline from STATE_CAPSULE / PITCH_XZ_TRACK λ=0
    base = struct( ...
        'dip_deg', 2.9630, ...
        'acq_mae_deg', 1.0480, ...
        'acq_s', 15.05, ...
        'overshoot_deg', 0.0000, ...
        'steady_rms_deg', 0.3393, ...
        'steady_p95_deg', 0.4445, ...
        'steady_mae_deg', 0.3320, ...
        'sat_pct', 0.00, ...
        'chatter_dps', 0.0004);

    fprintf('\n========== PITCH_XZ_BUMPLESS_DE_INIT_001 ==========\n');
    fprintf('XZ λ=0 bumpless prev_delta_e=de_trim(u0) | one-shot\n');

    m = run_one(path, T_final, u0);
    G = gate(m, base);

    % ---- PNG ----
    L = m.logs;
    lim_deg = rad2deg(delta_e_max);
    fig = figure('Visible', 'off', 'Color', 'w', 'Position', [40 40 1280 900]);

    subplot(2,2,1); hold on; grid on;
    plot(L.t, rad2deg(L.theta_ref), 'k-', 'LineWidth', 1.5);
    plot(L.t, rad2deg(L.theta_phys), 'b-', 'LineWidth', 1.2);
    yline(m.path_pitch_deg, 'g--', 'path');
    xline(m.acq_time_s, 'm--', 'acq');
    ylabel('\theta [deg]'); xlabel('t [s]');
    title(sprintf('\\theta_{ref}/\\theta | dip=%.3f° (Δ%.1f%%)', ...
        m.dip_deg, G.dip_improve_pct));
    legend({'\theta_{ref}','\theta_{phys}'}, 'Location', 'best');

    subplot(2,2,2); hold on; grid on;
    plot(L.t, rad2deg(L.e_th), 'b-', 'LineWidth', 1.2);
    yline(0.5, 'k--'); yline(-0.5, 'k--'); yline(0, 'k:');
    xline(m.acq_time_s, 'm--');
    ylabel('e_\theta [deg]'); xlabel('t [s]');
    title(sprintf('e_\\theta | MAE_{acq}=%.4f° (Δ%.1f%%)', ...
        m.acq.mae_deg, G.acq_mae_improve_pct));

    subplot(2,2,3); hold on; grid on;
    plot(L.t, rad2deg(L.q), 'r-', 'LineWidth', 1.1);
    xline(m.acq_time_s, 'm--');
    ylabel('q [deg/s]'); xlabel('t [s]');
    title(sprintf('q | chatter=%.4f °/s', m.chatter_dps));

    subplot(2,2,4); hold on; grid on;
    plot(L.t, rad2deg(L.de_unsat), 'k--', 'LineWidth', 1.1);
    plot(L.t, rad2deg(L.de), 'r-', 'LineWidth', 1.2);
    yline(lim_deg, 'k:'); yline(-lim_deg, 'k:');
    xline(m.acq_time_s, 'm--');
    ylabel('\delta_e [deg]'); xlabel('t [s]');
    title(sprintf('\\delta_e unsat/final | t0 final=%.3f° sat=%.2f%%', ...
        rad2deg(L.de(1)), m.elev_sat_pct));
    legend({'\delta_{e,unsat}','\delta_{e,final}','limits'}, 'Location', 'best');

    sgtitle(sprintf('PITCH_XZ_BUMPLESS_DE_INIT | %s | \\lambda=0', ...
        tern(G.pass,'PASS','FAIL')));

    png_path = fullfile(out_dir, [tag '.png']);
    exportgraphics(fig, png_path, 'Resolution', 150);
    close(fig);

    % ---- MAT ----
    task = struct();
    task.task_id = 'PITCH_XZ_BUMPLESS_DE_INIT_001';
    task.verdict = tern(G.pass, 'PASS', 'FAIL');
    task.pass = G.pass;
    task.gates = G;
    task.base = base;
    task.production_change = 'controller_law.m: prev_delta_e init 0 -> de_trim(u)';
    task.lambda_muw_ff = 0;
    task.T_final = T_final;
    task.u0 = u0;
    mat_path = fullfile(out_dir, [tag '.mat']);
    save(mat_path, 'task', 'm', 'path', 'base', 'G');

    % ---- MD ----
    md_path = fullfile(out_dir, [tag '.md']);
    fid = fopen(md_path, 'w');
    fprintf(fid, '# PITCH_XZ_BUMPLESS_DE_INIT\n\n');
    fprintf(fid, '**TASK_ID:** PITCH_XZ_BUMPLESS_DE_INIT_001\n');
    fprintf(fid, '**Date:** %s\n', datestr(now, 31));
    fprintf(fid, '**Verdict:** **%s**\n\n', tern(G.pass,'PASS','FAIL'));

    fprintf(fid, '## Change\n\n');
    fprintf(fid, '- Production: `controller_law.m` elevator rate-limiter persistent ');
    fprintf(fid, '`prev_delta_e` init **0 → de_trim(u)** on first call.\n');
    fprintf(fid, '- Driver: `run_pitch_xz_bumpless_de_init.m` (this file).\n');
    fprintf(fid, '- No climb trim, no I warm-start, no gain/guidance/plant change.\n\n');

    fprintf(fid, '## Before / After (λ=0 XZ, same windows)\n\n');
    fprintf(fid, '| Metric | Baseline | Candidate | Δ%% |\n');
    fprintf(fid, '|--------|--------:|----------:|---:|\n');
    fprintf(fid, '| dip [°] | %.4f | %.4f | %+.1f |\n', ...
        base.dip_deg, m.dip_deg, -G.dip_improve_pct);
    fprintf(fid, '| acq MAE [°] | %.4f | %.4f | %+.1f |\n', ...
        base.acq_mae_deg, m.acq.mae_deg, -G.acq_mae_improve_pct);
    fprintf(fid, '| acq / settling [s] | %.2f | %.2f | %+.1f |\n', ...
        base.acq_s, m.acq_time_s, 100*(m.acq_time_s-base.acq_s)/base.acq_s);
    fprintf(fid, '| overshoot [°] | %.4f | %.4f | — |\n', ...
        base.overshoot_deg, m.overshoot_deg);
    fprintf(fid, '| steady RMS [°] | %.4f | %.4f | %+.1f |\n', ...
        base.steady_rms_deg, m.steady.rms_deg, ...
        100*(m.steady.rms_deg-base.steady_rms_deg)/base.steady_rms_deg);
    fprintf(fid, '| steady p95 [°] | %.4f | %.4f | %+.1f |\n', ...
        base.steady_p95_deg, m.steady.p95_deg, ...
        100*(m.steady.p95_deg-base.steady_p95_deg)/base.steady_p95_deg);
    fprintf(fid, '| steady MAE [°] | %.4f | %.4f | %+.1f |\n', ...
        base.steady_mae_deg, m.steady.mae_deg, ...
        100*(m.steady.mae_deg-base.steady_mae_deg)/base.steady_mae_deg);
    fprintf(fid, '| sat%% | %.2f | %.2f | — |\n', base.sat_pct, m.elev_sat_pct);
    fprintf(fid, '| chatter [°/s] | %.4f | %.4f | — |\n\n', ...
        base.chatter_dps, m.chatter_dps);

    fprintf(fid, '## Gates\n\n');
    fprintf(fid, '| Gate | Result |\n|------|--------|\n');
    fprintf(fid, '| dip improve ≥30%% OR acq MAE ≥10%% | %s (dip %.1f%% / acqMAE %.1f%%) |\n', ...
        yn(G.g_improve), G.dip_improve_pct, G.acq_mae_improve_pct);
    fprintf(fid, '| steady RMS/p95 regression ≤2%% | %s |\n', yn(G.g_steady));
    fprintf(fid, '| acq settling not worse | %s |\n', yn(G.g_acq));
    fprintf(fid, '| overshoot not worse | %s |\n', yn(G.g_os));
    fprintf(fid, '| sat ≤1%% | %s (%.2f%%) |\n', yn(G.g_sat), m.elev_sat_pct);
    fprintf(fid, '| no new chatter | %s |\n', yn(G.g_chatter));
    fprintf(fid, '\n**Overall: %s**\n\n', tern(G.pass,'PASS','FAIL'));

    fprintf(fid, '## Elev@t0\n\n');
    fprintf(fid, '- de_trim=%.3f° de_fb=%.3f° de_unsat=%.3f° de_final=%.3f°\n\n', ...
        rad2deg(L.de_trim(1)), rad2deg(L.de_fb(1)), ...
        rad2deg(L.de_unsat(1)), rad2deg(L.de(1)));

    fprintf(fid, '## Evidence paths\n\n');
    fprintf(fid, '- suite_results/%s.md\n', tag);
    fprintf(fid, '- suite_results/%s.mat\n', tag);
    fprintf(fid, '- suite_results/%s.png\n\n', tag);

    fprintf(fid, '## MATHEMATICAL_DELTA\n\n');
    fprintf(fid, '```\n');
    fprintf(fid, 'MATHEMATICAL_DELTA = {\n');
    fprintf(fid, '  equations: {\n');
    fprintf(fid, '    de_trim = interp1(trim_speed_table, trim_elevator_table, |u|),\n');
    fprintf(fid, '    prev_delta_e(0) <- de_trim(u0),   %% was 0\n');
    fprintf(fid, '    de = prev_de + sat(de_cmd - prev_de, +/-40deg/s * dt),\n');
    fprintf(fid, '    de_unsat = de_trim + de_muw_ff + de_fb,  %% lambda=0 => FF=0\n');
    fprintf(fid, '    dip = path_pitch - min(theta_phys)_acq\n');
    fprintf(fid, '  },\n');
    fprintf(fid, '  variables_units_frames: {\n');
    fprintf(fid, '    delta_e, de_trim [rad] body elevator; reported [deg];\n');
    fprintf(fid, '    theta_phys=-theta [rad] physical pitch; e_theta=theta_ref-theta_phys\n');
    fprintf(fid, '  },\n');
    fprintf(fid, '  parameter_provenance: {\n');
    fprintf(fid, '    DERIVED: de_trim(u0)=interp1([0.8 1 1.5 2], deg2rad([-9.18 -7.33 -4.62 -3.17]), 1.5),\n');
    fprintf(fid, '    IDENTIFIED: prev_delta_e cold-start was rate-limiting trim onto surface,\n');
    fprintf(fid, '    TUNED: none,\n');
    fprintf(fid, '    FIXED: lambda=0, u0=1.5, T=22s, XZ z=0.4x, yaw+pitch gains frozen\n');
    fprintf(fid, '  },\n');
    fprintf(fid, '  design_reason: ''Bumpless: remove RL step from 0 to de_trim at t0.'',\n');
    fprintf(fid, '  rejected_alternatives: {\n');
    fprintf(fid, '    climb_trim: deferred, gain_retune: frozen, I_warmstart: out of scope\n');
    fprintf(fid, '  },\n');
    fprintf(fid, '  evidence: { suite_results/%s.* },\n', tag);
    fprintf(fid, '  conclusion: ''%s'',\n', tern(G.pass,'PASS: bumpless de_trim init','FAIL: revert production'));
    fprintf(fid, '  open_questions: { next_target_only }\n');
    fprintf(fid, '}\n');
    fprintf(fid, '```\n');
    fclose(fid);

    fprintf('dip=%.4f° (improve %.1f%%) acqMAE=%.4f° (improve %.1f%%) sat=%.2f%%\n', ...
        m.dip_deg, G.dip_improve_pct, m.acq.mae_deg, G.acq_mae_improve_pct, m.elev_sat_pct);
    fprintf('Verdict=%s | Wrote suite_results/%s.{md,mat,png}\n', ...
        tern(G.pass,'PASS','FAIL'), tag);

    % Signal for outer wrapper / human: leave production only on PASS
    assignin('base', 'PITCH_XZ_BUMPLESS_PASS', G.pass);
end

function m = run_one(path, T_final, u0)
    global dt_controller delta_e_max
    global suite_delta_e_log suite_de_fb_log suite_de_trim_log suite_de_uw_ff_log
    global lambda_muw_ff

    lambda_muw_ff = 0.0;
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
    de_trim = suite_de_trim_log(:);
    de_ff = suite_de_uw_ff_log(:);
    if isempty(de); de = zeros(size(t)); end
    if isempty(de_fb); de_fb = zeros(size(t)); end
    if isempty(de_trim); de_trim = zeros(size(t)); end
    if isempty(de_ff); de_ff = zeros(size(t)); end
    de = align_len(de, numel(t));
    de_fb = align_len(de_fb, numel(t));
    de_trim = align_len(de_trim, numel(t));
    de_ff = align_len(de_ff, numel(t));
    de_unsat = de_trim + de_ff + de_fb;

    % Acquisition / steady windows — identical to PITCH_XZ_TRACK
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
    mask_sbe = (t >= 5.0) & (s < 0.88 * s_total);
    mask_steady = mask_sbe & ~mask_acq;
    if ~any(mask_steady); mask_steady = mask_sbe; end

    th_dot = [0; diff(theta_phys)] / dt;
    lim = delta_e_max;
    path_pitch = atan2(0.4, 1);

    m = struct();
    m.acq_time_s = t(acq_end);
    m.acq = eth_stats(e_th(mask_acq));
    m.steady = eth_stats(e_th(mask_steady));
    th_acq = theta_phys(mask_acq);
    m.dip_deg = rad2deg(path_pitch - min(th_acq));
    m.min_theta_acq_deg = rad2deg(min(th_acq));
    if any(mask_steady)
        final_ref = mean(theta_ref(mask_steady));
        m.overshoot_deg = rad2deg(max(0, max(th_acq) - final_ref));
    else
        m.overshoot_deg = NaN;
    end
    m.settling_s = m.acq_time_s;
    de_ss = de(mask_steady);
    m.elev_sat_pct = 100 * mean(abs(de_ss) >= 0.98 * lim);
    dth_ss = th_dot(mask_steady);
    if numel(dth_ss) < 5
        m.chatter_dps = pm.pitch_chatter_dps;
    else
        m.chatter_dps = rad2deg(std(hf_local(detrend(dth_ss), dt)));
    end
    m.path_pitch_deg = rad2deg(path_pitch);
    m.logs = struct('t', t, 'theta_ref', theta_ref, 'theta_phys', theta_phys, ...
        'e_th', e_th, 'q', q, 'de', de, 'de_unsat', de_unsat, ...
        'de_trim', de_trim, 'de_fb', de_fb, ...
        'mask_acq', mask_acq, 'mask_steady', mask_steady, 'vp', vp);
    m.pm = pm;
end

function G = gate(m, base)
    G = struct();
    G.dip_improve_pct = 100 * (base.dip_deg - m.dip_deg) / base.dip_deg;
    G.acq_mae_improve_pct = 100 * (base.acq_mae_deg - m.acq.mae_deg) / base.acq_mae_deg;
    G.g_improve = (G.dip_improve_pct >= 30) || (G.acq_mae_improve_pct >= 10);

    rms_reg = 100 * (m.steady.rms_deg - base.steady_rms_deg) / base.steady_rms_deg;
    p95_reg = 100 * (m.steady.p95_deg - base.steady_p95_deg) / base.steady_p95_deg;
    G.rms_reg_pct = rms_reg;
    G.p95_reg_pct = p95_reg;
    G.g_steady = (rms_reg <= 2) && (p95_reg <= 2);

    G.g_acq = m.acq_time_s <= base.acq_s + 1e-9;
    G.g_os = m.overshoot_deg <= base.overshoot_deg + 1e-6;
    G.g_sat = m.elev_sat_pct <= 1.0;
    % no new chatter: allow tiny numeric noise, reject clear growth
    G.g_chatter = m.chatter_dps <= max(base.chatter_dps * 1.5, base.chatter_dps + 0.01);

    G.pass = G.g_improve && G.g_steady && G.g_acq && G.g_os && G.g_sat && G.g_chatter;
end

function y = align_len(x, n)
    x = x(:);
    if numel(x) >= n
        y = x(1:n);
    else
        y = [x; x(end)*ones(n-numel(x),1)];
    end
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
