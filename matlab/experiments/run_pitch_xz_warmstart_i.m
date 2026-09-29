function run_pitch_xz_warmstart_i()
% PITCH_XZ_WARMSTART_I_001 — warm-start pitch angle integrator int_angle(0)
% so de_fb(t0) matches settled XZ λ=0 elevator feedback (ATTRIB steady mean).
% One deterministic XZ λ=0 run; same windows as PITCH_XZ_TRACK λ=0 baseline.
% Production under test: controller_law int_angle warm-start on first call.
% Outputs: suite_results/PITCH_XZ_WARMSTART_I.{md,mat,png}

    project_dir = fileparts(fileparts(fileparts(mfilename('fullpath')))); % repo root
    addpath(genpath(fullfile(project_dir, 'matlab')));
    out_dir = fullfile(project_dir, 'suite_results');
    if ~exist(out_dir, 'dir'); mkdir(out_dir); end
    tag = 'PITCH_XZ_WARMSTART_I';

    clear functions
    clear guidance_law controller_law
    clear global lambda_muw_ff trim_speed_table trim_elevator_table elevator_sign
    clear global K_zdot K_gamma enable_alpha_hat

    init_parameters();
    global lambda_muw_ff elevator_sign trim_speed_table trim_elevator_table
    global K_zdot K_gamma enable_alpha_hat
    global dt_controller delta_e_max
    global Kp_angle Ki_angle Kp_rate Ki_rate

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

    % Derive warm-start target from accepted λ=0 ATTRIB MAT (steady window)
    prov = derive_warmstart_from_attrib(fullfile(out_dir, 'PITCH_XZ_INTERNAL_ATTRIB.mat'), dt_controller);
    ia0_prod = 0.050253445658 / (elevator_sign * Kp_rate * max(Ki_angle, 1e-6));
    ia_max = deg2rad(8) / max(Ki_angle, 1e-6);
    ia0_prod = max(min(ia0_prod, ia_max), -ia_max);

    fprintf('\n========== PITCH_XZ_WARMSTART_I_001 ==========\n');
    fprintf('XZ λ=0 int_angle warm-start | de_fb_eq=%.6f rad (%.4f°) ia0=%.6f\n', ...
        prov.de_fb_eq, rad2deg(prov.de_fb_eq), ia0_prod);

    m = run_one(path, T_final, u0);
    G = gate(m, base);

    % ---- PNG: theta, e_theta, q/q_ref, integrator, elevator components ----
    L = m.logs;
    lim_deg = rad2deg(delta_e_max);
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
    yline(ia0_prod, 'k--', 'ia0');
    yline(ia_max, 'r:'); yline(-ia_max, 'r:');
    xline(m.acq_time_s, 'm--');
    ylabel('int\_angle [rad·s]'); xlabel('t [s]');
    title(sprintf('int\\_angle | t0=%.4f (target %.4f)', L.int_angle(1), ia0_prod));

    subplot(3,2,5); hold on; grid on;
    plot(L.t, rad2deg(L.de_trim), 'g-', 'LineWidth', 1.0);
    plot(L.t, rad2deg(L.de_fb), 'b-', 'LineWidth', 1.1);
    plot(L.t, rad2deg(L.de_ff), 'c-', 'LineWidth', 1.0);
    plot(L.t, rad2deg(L.de_unsat), 'k--', 'LineWidth', 1.0);
    plot(L.t, rad2deg(L.de), 'r-', 'LineWidth', 1.2);
    yline(lim_deg, 'k:'); yline(-lim_deg, 'k:');
    xline(m.acq_time_s, 'm--');
    ylabel('\delta_e [deg]'); xlabel('t [s]');
    title(sprintf('\\delta_e components | t0 fb=%.3f° sat=%.2f%%', ...
        rad2deg(L.de_fb(1)), m.elev_sat_pct));
    legend({'\delta_{e,trim}','\delta_{e,fb}','\delta_{e,FF}','unsat','final','lim'}, ...
        'Location', 'best');

    subplot(3,2,6); hold on; grid on;
    plot(L.t, rad2deg(L.de), 'r-', 'LineWidth', 1.2);
    yline(lim_deg, 'k--'); yline(-lim_deg, 'k--');
    xline(m.acq_time_s, 'm--');
    ylabel('\delta_e final [deg]'); xlabel('t [s]');
    title(sprintf('\\delta_e vs limits | final(t0)=%.3f°', rad2deg(L.de(1))));

    sgtitle(sprintf('PITCH_XZ_WARMSTART_I | %s | \\lambda=0', ...
        tern(G.pass,'PASS','FAIL')));

    png_path = fullfile(out_dir, [tag '.png']);
    exportgraphics(fig, png_path, 'Resolution', 150);
    close(fig);

    % ---- MAT ----
    task = struct();
    task.task_id = 'PITCH_XZ_WARMSTART_I_001';
    task.verdict = tern(G.pass, 'PASS', 'FAIL');
    task.pass = G.pass;
    task.gates = G;
    task.base = base;
    task.provenance = prov;
    task.ia0_prod = ia0_prod;
    task.de_fb_eq_prod = 0.050253445658;
    task.production_change = [ ...
        'controller_law.m: int_angle(0)=de_fb_eq/(sign*Kp_rate*Ki_angle) ', ...
        'on first call (de_fb_eq=ATTRIB steady mean)'];
    task.lambda_muw_ff = 0;
    task.T_final = T_final;
    task.u0 = u0;
    mat_path = fullfile(out_dir, [tag '.mat']);
    save(mat_path, 'task', 'm', 'path', 'base', 'G', 'prov');

    % ---- MD ----
    md_path = fullfile(out_dir, [tag '.md']);
    fid = fopen(md_path, 'w');
    fprintf(fid, '# PITCH_XZ_WARMSTART_I\n\n');
    fprintf(fid, '**TASK_ID:** PITCH_XZ_WARMSTART_I_001\n');
    fprintf(fid, '**Date:** %s\n', datestr(now, 31));
    fprintf(fid, '**Verdict:** **%s**\n\n', tern(G.pass,'PASS','FAIL'));

    fprintf(fid, '## Change\n\n');
    fprintf(fid, '- Production: `controller_law.m` pitch **int_angle** warm-start on ');
    fprintf(fid, 'reset/first call: `int_angle(0)=de_fb_eq/(elevator_sign*Kp_rate*Ki_angle)`, ');
    fprintf(fid, 'bounded by `±deg2rad(8)/Ki_angle`.\n');
    fprintf(fid, '- `de_fb_eq=%.10f rad` (%.4f°) = mean(de_fb) over ATTRIB λ=0 steady window.\n', ...
        prov.de_fb_eq, rad2deg(prov.de_fb_eq));
    fprintf(fid, '- `int_angle(0)=%.6f rad·s` (ia_max=±%.4f).\n', ia0_prod, ia_max);
    fprintf(fid, '- Driver: `run_pitch_xz_warmstart_i.m` (this file).\n');
    fprintf(fid, '- No climb trim/FF, no prev_delta_e init, no gain/guidance/plant change.\n\n');

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
    fprintf(fid, '- de_trim=%.3f° de_fb=%.3f° de_unsat=%.3f° de_final=%.3f°\n', ...
        rad2deg(L.de_trim(1)), rad2deg(L.de_fb(1)), ...
        rad2deg(L.de_unsat(1)), rad2deg(L.de(1)));
    fprintf(fid, '- int_angle(t0)=%.6f rad·s (target %.6f)\n\n', L.int_angle(1), ia0_prod);

    fprintf(fid, '## Evidence paths\n\n');
    fprintf(fid, '- suite_results/%s.md\n', tag);
    fprintf(fid, '- suite_results/%s.mat\n', tag);
    fprintf(fid, '- suite_results/%s.png\n\n', tag);

    fprintf(fid, '## MATHEMATICAL_DELTA\n\n');
    fprintf(fid, '```\n');
    fprintf(fid, 'MATHEMATICAL_DELTA = {\n');
    fprintf(fid, '  equations: {\n');
    fprintf(fid, '    de_fb_eq = mean(de_fb)_steady,  %% ATTRIB λ=0\n');
    fprintf(fid, '    int_angle(0) = de_fb_eq / (elevator_sign * Kp_rate * Ki_angle),\n');
    fprintf(fid, '    int_angle = sat(int_angle, +/- deg2rad(8)/Ki_angle),\n');
    fprintf(fid, '    %% at e≈0, rate≈0, Ki_rate=0: de_fb = sign*Kp_rate*Ki_angle*int_angle\n');
    fprintf(fid, '    dip = path_pitch - min(theta_phys)_acq\n');
    fprintf(fid, '  },\n');
    fprintf(fid, '  variables_units_frames: {\n');
    fprintf(fid, '    int_angle [rad*s] physical-pitch error integral (e_theta=pitch_ref-theta_phys),\n');
    fprintf(fid, '    de_fb, de_fb_eq [rad] body elevator feedback; reported [deg],\n');
    fprintf(fid, '    theta_phys=-theta [rad] physical pitch\n');
    fprintf(fid, '  },\n');
    fprintf(fid, '  parameter_provenance: {\n');
    fprintf(fid, '    DERIVED: de_fb_eq=%.10f rad from PITCH_XZ_INTERNAL_ATTRIB.mat\n', prov.de_fb_eq);
    fprintf(fid, '             steady mask (t>=5 & s<0.88*s_tot & ~acq), n=%d,\n', prov.n_steady);
    fprintf(fid, '    DERIVED: int_angle(0)=%.6f = de_fb_eq/(1*%.2f*%.2f),\n', ...
        ia0_prod, Kp_rate, Ki_angle);
    fprintf(fid, '    IDENTIFIED: cold int_angle => de_fb(0)=0 while climb needs ~+%.2f° fb,\n', ...
        rad2deg(prov.de_fb_eq));
    fprintf(fid, '    TUNED: none,\n');
    fprintf(fid, '    FIXED: lambda=0, u0=1.5, T=22s, XZ z=0.4x, yaw+pitch gains frozen,\n');
    fprintf(fid, '           prev_delta_e(0)=0 (actuator-init candidate rejected)\n');
    fprintf(fid, '  },\n');
    fprintf(fid, '  design_reason: ''Bumpless I: seed angle integrator to settled XZ de_fb.'',\n');
    fprintf(fid, '  rejected_alternatives: {\n');
    fprintf(fid, '    prev_delta_e=de_trim: FAILED/reverted, climb_trim: deferred, gain_retune: frozen\n');
    fprintf(fid, '  },\n');
    fprintf(fid, '  evidence: { suite_results/%s.* },\n', tag);
    fprintf(fid, '  conclusion: ''%s'',\n', tern(G.pass,'PASS: keep int_angle warm-start','FAIL: revert production'));
    fprintf(fid, '  open_questions: { next_target_only }\n');
    fprintf(fid, '}\n');
    fprintf(fid, '```\n');
    fclose(fid);

    fprintf('dip=%.4f° (improve %.1f%%) acqMAE=%.4f° (improve %.1f%%) sat=%.2f%%\n', ...
        m.dip_deg, G.dip_improve_pct, m.acq.mae_deg, G.acq_mae_improve_pct, m.elev_sat_pct);
    fprintf('Verdict=%s | Wrote suite_results/%s.{md,mat,png}\n', ...
        tern(G.pass,'PASS','FAIL'), tag);

    assignin('base', 'PITCH_XZ_WARMSTART_I_PASS', G.pass);
end

function prov = derive_warmstart_from_attrib(mat_path, dt)
    L = load(mat_path);
    S = L.S;
    t = S.t(:);
    e = S.e_theta(:);
    band = deg2rad(0.5);
    hold_n = max(1, round(1.0 / dt));
    acq_end = numel(t);
    in_band = abs(e) <= band;
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

    path = L.path;
    vp = S.vp;
    dp = diff(path); seg = sqrt(sum(dp.^2, 2));
    s_path = [0; cumsum(seg)];
    s_total = s_path(end);
    s = zeros(size(t));
    for i = 1:numel(t)
        d2 = sum((path - vp(i,:)).^2, 2);
        [~, j] = min(d2);
        s(i) = s_path(j);
    end
    mask_sbe = (t >= 5.0) & (s < 0.88 * s_total);
    mask_steady = mask_sbe & ~mask_acq;
    if ~any(mask_steady); mask_steady = mask_sbe; end

    prov = struct();
    prov.source = 'suite_results/PITCH_XZ_INTERNAL_ATTRIB.mat';
    prov.n_steady = nnz(mask_steady);
    prov.de_fb_eq = mean(S.de_fb(mask_steady));
    prov.int_angle_ss = mean(S.int_angle(mask_steady));
    prov.acq_end_s = t(acq_end);
end

function m = run_one(path, T_final, u0)
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
    de_ff = suite_de_uw_ff_log(:);
    int_angle = suite_int_angle_log(:);
    if isempty(de); de = zeros(size(t)); end
    if isempty(de_fb); de_fb = zeros(size(t)); end
    if isempty(de_trim); de_trim = zeros(size(t)); end
    if isempty(de_ff); de_ff = zeros(size(t)); end
    if isempty(int_angle); int_angle = zeros(size(t)); end
    de = align_len(de, numel(t));
    de_fb = align_len(de_fb, numel(t));
    de_trim = align_len(de_trim, numel(t));
    de_ff = align_len(de_ff, numel(t));
    int_angle = align_len(int_angle, numel(t));
    de_unsat = de_trim + de_ff + de_fb;
    % Reconstruct outer rate cmd (q_ref) from logged angle loop state
    pitch_ref_dot = [0; diff(theta_ref)] / dt;
    q_ref = 0.8 * pitch_ref_dot + Kp_angle * e_th + Ki_angle * int_angle;

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
        'e_th', e_th, 'q', q, 'q_ref', q_ref, 'int_angle', int_angle, ...
        'de', de, 'de_unsat', de_unsat, 'de_trim', de_trim, 'de_fb', de_fb, ...
        'de_ff', de_ff, 'mask_acq', mask_acq, 'mask_steady', mask_steady, 'vp', vp);
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
