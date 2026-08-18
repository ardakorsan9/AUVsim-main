function run_pitch_xz_climb_trim_ff()
% PITCH_XZ_CLIMB_TRIM_FF_001 — climb equilibrium elevator feedforward
% delta_e_climb_ff = sat(k_gamma*gamma_ref, +/-2.8793deg), k_gamma=2.8793/21.8014.
% Not integrator memory: int_angle(0)=0. One deterministic XZ λ=0 run.
% Outputs: suite_results/PITCH_XZ_CLIMB_TRIM_FF.{md,mat,png}

    project_dir = fileparts(mfilename('fullpath'));
    addpath(project_dir);
    out_dir = fullfile(project_dir, 'suite_results');
    if ~exist(out_dir, 'dir'); mkdir(out_dir); end
    tag = 'PITCH_XZ_CLIMB_TRIM_FF';

    clear functions
    clear guidance_law controller_law
    clear global lambda_muw_ff trim_speed_table trim_elevator_table elevator_sign
    clear global K_zdot K_gamma enable_alpha_hat

    init_parameters();
    global lambda_muw_ff elevator_sign trim_speed_table trim_elevator_table
    global K_zdot K_gamma enable_alpha_hat
    global dt_controller delta_e_max
    global Kp_angle Ki_angle

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

    k_gamma = 2.8793 / 21.8014;
    de_climb_lim_deg = 2.8793;
    path_pitch_deg = rad2deg(atan2(0.4, 1));

    fprintf('\n========== PITCH_XZ_CLIMB_TRIM_FF_001 ==========\n');
    fprintf('XZ λ=0 climb FF | k_gamma=%.10f | lim=±%.4f° | path_pitch=%.4f°\n', ...
        k_gamma, de_climb_lim_deg, path_pitch_deg);

    m = run_one(path, T_final, u0, k_gamma, de_climb_lim_deg);
    G = gate(m, base);

    % ---- PNG ----
    L = m.logs;
    lim_deg = rad2deg(delta_e_max);
    ia_max = deg2rad(8) / max(Ki_angle, 1e-6);
    fig = figure('Visible', 'off', 'Color', 'w', 'Position', [40 40 1400 1000]);

    subplot(3,2,1); hold on; grid on;
    plot(L.t, rad2deg(L.theta_ref), 'k-', 'LineWidth', 1.5);
    plot(L.t, rad2deg(L.theta_phys), 'b-', 'LineWidth', 1.2);
    yline(m.path_pitch_deg, 'g--', 'path');
    xline(m.acq_time_s, 'm--', 'acq');
    ylabel('\theta [deg]'); xlabel('t [s]');
    title(sprintf('\\theta_{ref}/\\theta | dip=%.3f° (improve %.1f%%)', ...
        m.dip_deg, G.dip_improve_pct));
    legend({'\theta_{ref}','\theta_{phys}'}, 'Location', 'best');

    subplot(3,2,2); hold on; grid on;
    plot(L.t, rad2deg(L.e_th), 'b-', 'LineWidth', 1.2);
    yline(0.5, 'k--'); yline(-0.5, 'k--'); yline(0, 'k:');
    xline(m.acq_time_s, 'm--');
    ylabel('e_\theta [deg]'); xlabel('t [s]');
    title(sprintf('e_\\theta | MAE_{acq}=%.4f° (improve %.1f%%)', ...
        m.acq.mae_deg, G.acq_mae_improve_pct));

    subplot(3,2,3); hold on; grid on;
    plot(L.t, rad2deg(L.q), 'r-', 'LineWidth', 1.1);
    plot(L.t, rad2deg(L.q_ref), 'k--', 'LineWidth', 1.1);
    xline(m.acq_time_s, 'm--');
    ylabel('[deg/s]'); xlabel('t [s]');
    title(sprintf('q / q_{ref} | chatter=%.4f °/s', m.chatter_dps));
    legend({'q','q_{ref}'}, 'Location', 'best');

    subplot(3,2,4); hold on; grid on;
    plot(L.t, L.int_angle, 'b-', 'LineWidth', 1.2);
    yline(0, 'k--', 'ia0=0');
    yline(ia_max, 'r:'); yline(-ia_max, 'r:');
    xline(m.acq_time_s, 'm--');
    ylabel('int\_angle [rad·s]'); xlabel('t [s]');
    title(sprintf('int\\_angle | t0=%.6f (cold start)', L.int_angle(1)));

    subplot(3,2,5); hold on; grid on;
    plot(L.t, rad2deg(L.de_trim), 'g-', 'LineWidth', 1.0);
    plot(L.t, rad2deg(L.de_climb_ff), 'm-', 'LineWidth', 1.2);
    plot(L.t, rad2deg(L.de_fb), 'b-', 'LineWidth', 1.1);
    plot(L.t, rad2deg(L.de_unsat), 'k--', 'LineWidth', 1.0);
    plot(L.t, rad2deg(L.de), 'r-', 'LineWidth', 1.2);
    yline(lim_deg, 'k:'); yline(-lim_deg, 'k:');
    yline(de_climb_lim_deg, 'm:'); yline(-de_climb_lim_deg, 'm:');
    xline(m.acq_time_s, 'm--');
    ylabel('\delta_e [deg]'); xlabel('t [s]');
    title(sprintf('\\delta_e | climbFF(t0)=%.3f° sat=%.2f%%', ...
        rad2deg(L.de_climb_ff(1)), m.elev_sat_pct));
    legend({'\delta_{e,trim}','climbFF','\delta_{e,fb}','unsat','final','lim'}, ...
        'Location', 'best');

    subplot(3,2,6); hold on; grid on;
    plot(L.t, rad2deg(L.de), 'r-', 'LineWidth', 1.2);
    yline(lim_deg, 'k--'); yline(-lim_deg, 'k--');
    xline(m.acq_time_s, 'm--');
    ylabel('\delta_e final [deg]'); xlabel('t [s]');
    title(sprintf('\\delta_e vs limits | final(t0)=%.3f°', rad2deg(L.de(1))));

    sgtitle(sprintf('PITCH_XZ_CLIMB_TRIM_FF | %s | \\lambda=0', ...
        tern(G.pass,'PASS','FAIL')));

    png_path = fullfile(out_dir, [tag '.png']);
    exportgraphics(fig, png_path, 'Resolution', 150);
    close(fig);

    % ---- MAT ----
    task = struct();
    task.task_id = 'PITCH_XZ_CLIMB_TRIM_FF_001';
    task.verdict = tern(G.pass, 'PASS', 'FAIL');
    task.pass = G.pass;
    task.gates = G;
    task.base = base;
    task.k_gamma = k_gamma;
    task.de_climb_lim_deg = de_climb_lim_deg;
    task.production_change = [ ...
        'controller_law.m: delta_e_climb_ff=sat(k_gamma*pitch_ref,+/-2.8793deg) ', ...
        'added to elevator sum; int_angle(0)=0'];
    task.lambda_muw_ff = 0;
    task.T_final = T_final;
    task.u0 = u0;
    mat_path = fullfile(out_dir, [tag '.mat']);
    save(mat_path, 'task', 'm', 'path', 'base', 'G', 'k_gamma');

    % ---- MD ----
    md_path = fullfile(out_dir, [tag '.md']);
    fid = fopen(md_path, 'w');
    fprintf(fid, '# PITCH_XZ_CLIMB_TRIM_FF\n\n');
    fprintf(fid, '**TASK_ID:** PITCH_XZ_CLIMB_TRIM_FF_001\n');
    fprintf(fid, '**Date:** %s\n', datestr(now, 31));
    fprintf(fid, '**Verdict:** **%s**\n\n', tern(G.pass,'PASS','FAIL'));

    fprintf(fid, '## Change\n\n');
    fprintf(fid, '- Production: `controller_law.m` climb equilibrium FF ');
    fprintf(fid, '`delta_e_climb_ff = sat(k_gamma*gamma_ref, ±%.4f°)`, ', de_climb_lim_deg);
    fprintf(fid, '`k_gamma=%.10f`, `gamma_ref=pitch_ref` (physical pitch / climb path).\n', k_gamma);
    fprintf(fid, '- Added to elevator sum: `de_unsat = de_trim + de_uw_ff + de_climb_ff + de_fb`.\n');
    fprintf(fid, '- `int_angle(0)=0` (no I warm-start). λ=0 => Muw FF≡0.\n');
    fprintf(fid, '- Driver: `run_pitch_xz_climb_trim_ff.m` (this file).\n');
    fprintf(fid, '- No Muw λ, gain, guidance, plant, actuator-init, or I-warm-start change.\n\n');

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

    fprintf(fid, '## Elev@t0 / I@t0\n\n');
    fprintf(fid, '- de_trim=%.3f° climbFF=%.3f° de_fb=%.3f° de_unsat=%.3f° de_final=%.3f°\n', ...
        rad2deg(L.de_trim(1)), rad2deg(L.de_climb_ff(1)), rad2deg(L.de_fb(1)), ...
        rad2deg(L.de_unsat(1)), rad2deg(L.de(1)));
    fprintf(fid, '- int_angle(t0)=%.6f rad·s (cold; no warm-start)\n\n', L.int_angle(1));

    fprintf(fid, '## Evidence paths\n\n');
    fprintf(fid, '- suite_results/%s.md\n', tag);
    fprintf(fid, '- suite_results/%s.mat\n', tag);
    fprintf(fid, '- suite_results/%s.png\n\n', tag);

    fprintf(fid, '## MATHEMATICAL_DELTA\n\n');
    fprintf(fid, '```\n');
    fprintf(fid, 'MATHEMATICAL_DELTA = {\n');
    fprintf(fid, '  equations: {\n');
    fprintf(fid, '    k_gamma = 2.8793/21.8014,  %% deg/deg = rad/rad\n');
    fprintf(fid, '    gamma_ref = pitch_ref,    %% physical pitch / climb-path ref [rad]\n');
    fprintf(fid, '    de_climb_ff = sat(k_gamma*gamma_ref, +/- deg2rad(2.8793)),\n');
    fprintf(fid, '    de_unsat = de_trim(u) + de_uw_ff + de_climb_ff + de_fb,\n');
    fprintf(fid, '    int_angle(0) = 0,\n');
    fprintf(fid, '    dip = path_pitch - min(theta_phys)_acq\n');
    fprintf(fid, '  },\n');
    fprintf(fid, '  variables_units_frames: {\n');
    fprintf(fid, '    gamma_ref, pitch_ref, theta_phys [rad] physical-pitch frame (theta_phys=-theta),\n');
    fprintf(fid, '    de_climb_ff, de_trim, de_fb, de [rad] body elevator; reported [deg],\n');
    fprintf(fid, '    k_gamma [-] dimensionless (elevator rad per pitch-ref rad)\n');
    fprintf(fid, '  },\n');
    fprintf(fid, '  parameter_provenance: {\n');
    fprintf(fid, '    DERIVED: k_gamma=%.10f from ATTRIB λ=0 steady mean(de_fb)=+2.8793°\n', k_gamma);
    fprintf(fid, '             / XZ path_pitch=21.8014° (PITCH_XZ_INTERNAL_ATTRIB.mat, n=272),\n');
    fprintf(fid, '    DERIVED: bound=±2.8793° = |de_fb_eq| (same IDENTIFIED equilibrium),\n');
    fprintf(fid, '    IDENTIFIED: cold I => de_fb(0)=0 while climb needs ~+2.88°; FF supplies it,\n');
    fprintf(fid, '    TUNED: none,\n');
    fprintf(fid, '    FIXED: lambda=0, u0=1.5, T=22s, XZ z=0.4x, yaw+pitch gains frozen,\n');
    fprintf(fid, '           int_angle(0)=0, prev_delta_e(0)=0 (prior candidates rejected)\n');
    fprintf(fid, '  },\n');
    fprintf(fid, '  design_reason: ''Literature climb trim FF: k_gamma*gamma_ref, not I memory.'',\n');
    fprintf(fid, '  rejected_alternatives: {\n');
    fprintf(fid, '    prev_delta_e=de_trim: FAILED/reverted,\n');
    fprintf(fid, '    int_angle warm-start: FAILED (steady p95 +24.2%%)/reverted,\n');
    fprintf(fid, '    gain_retune: frozen, Muw_lambda: frozen at 0\n');
    fprintf(fid, '  },\n');
    fprintf(fid, '  evidence: { suite_results/%s.* },\n', tag);
    fprintf(fid, '  conclusion: ''%s'',\n', ...
        tern(G.pass,'PASS: keep climb equilibrium FF','FAIL: revert production'));
    fprintf(fid, '  open_questions: { next_target_only }\n');
    fprintf(fid, '}\n');
    fprintf(fid, '```\n');
    fclose(fid);

    fprintf('dip=%.4f° (improve %.1f%%) acqMAE=%.4f° (improve %.1f%%) sat=%.2f%%\n', ...
        m.dip_deg, G.dip_improve_pct, m.acq.mae_deg, G.acq_mae_improve_pct, m.elev_sat_pct);
    fprintf('steady RMS Δ%%=%+.1f p95 Δ%%=%+.1f | Verdict=%s\n', ...
        G.rms_reg_pct, G.p95_reg_pct, tern(G.pass,'PASS','FAIL'));
    fprintf('Wrote suite_results/%s.{md,mat,png}\n', tag);

    assignin('base', 'PITCH_XZ_CLIMB_TRIM_FF_PASS', G.pass);
end

function m = run_one(path, T_final, u0, k_gamma, de_climb_lim_deg)
    global dt_controller delta_e_max
    global suite_delta_e_log suite_de_fb_log suite_de_trim_log suite_de_uw_ff_log
    global suite_int_angle_log
    global lambda_muw_ff
    global Kp_angle Ki_angle

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
    de_muw = suite_de_uw_ff_log(:);
    int_angle = suite_int_angle_log(:);
    if isempty(de); de = zeros(size(t)); end
    if isempty(de_fb); de_fb = zeros(size(t)); end
    if isempty(de_trim); de_trim = zeros(size(t)); end
    if isempty(de_muw); de_muw = zeros(size(t)); end
    if isempty(int_angle); int_angle = zeros(size(t)); end
    de = align_len(de, numel(t));
    de_fb = align_len(de_fb, numel(t));
    de_trim = align_len(de_trim, numel(t));
    de_muw = align_len(de_muw, numel(t));
    int_angle = align_len(int_angle, numel(t));

    % Reconstruct climb FF (matches controller_law; no CPT logging change)
    lim_c = deg2rad(de_climb_lim_deg);
    de_climb_ff = max(min(k_gamma * theta_ref, lim_c), -lim_c);
    de_unsat = de_trim + de_muw + de_climb_ff + de_fb;

    pitch_ref_dot = [0; diff(theta_ref)] / dt;
    q_ref = 0.8 * pitch_ref_dot + Kp_angle * e_th + Ki_angle * int_angle;

    W = compute_pitch_window_metrics(t, e_th, s, s_total, 'mode', 'persistent');
    mask_acq = W.mask_acq;
    mask_steady = W.mask_steady;

    th_dot = [0; diff(theta_phys)] / dt;
    lim = delta_e_max;
    path_pitch = atan2(0.4, 1);

    m = struct();
    m.acq_time_s = W.acq_time_s;
    m.acq = W.acq;
    m.steady = W.steady;
    m.n_acq = W.n_acq;
    m.n_steady = W.n_steady;
    m.window_mode = W.mode;
    m.persistent_ok = W.persistent_ok;
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
        m.overshoot_deg = rad2deg(max(0, max(th_acq) - final_ref));
    else
        m.overshoot_deg = NaN;
    end
    m.settling_s = m.acq_time_s;
    if any(mask_steady)
        de_ss = de(mask_steady);
        m.elev_sat_pct = 100 * mean(abs(de_ss) >= 0.98 * lim);
        dth_ss = th_dot(mask_steady);
        if numel(dth_ss) < 5
            m.chatter_dps = pm.pitch_chatter_dps;
        else
            m.chatter_dps = rad2deg(std(hf_local(detrend(dth_ss), dt)));
        end
    else
        m.elev_sat_pct = NaN;
        m.chatter_dps = NaN;
    end
    m.path_pitch_deg = rad2deg(path_pitch);
    m.logs = struct('t', t, 'theta_ref', theta_ref, 'theta_phys', theta_phys, ...
        'e_th', e_th, 'q', q, 'q_ref', q_ref, 'int_angle', int_angle, ...
        'de', de, 'de_unsat', de_unsat, 'de_trim', de_trim, 'de_fb', de_fb, ...
        'de_muw', de_muw, 'de_climb_ff', de_climb_ff, ...
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

    G.g_acq = ~isnan(m.acq_time_s) && ~isnan(base.acq_s) && ...
        (m.acq_time_s <= base.acq_s + 1e-9);
    G.g_os = ~isnan(m.overshoot_deg) && (m.overshoot_deg <= base.overshoot_deg + 1e-6);
    G.g_sat = ~isnan(m.elev_sat_pct) && (m.elev_sat_pct <= 1.0);
    G.g_chatter = ~isnan(m.chatter_dps) && ...
        (m.chatter_dps <= max(base.chatter_dps * 1.5, base.chatter_dps + 0.01));

    % Persistent-absent => settling NaN => g_acq false (FAIL under original gates).
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
