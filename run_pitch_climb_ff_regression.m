function run_pitch_climb_ff_regression()
% PITCH_CLIMB_FF_REGRESSION_001 — promote climb equilibrium FF; regress X then XZ.
% Production: de_climb_ff=sat(k_gamma*gamma_ref,+/-2.8793deg), k_gamma=0.1320695001,
% gamma_ref=physical pitch_ref; added to elevator sum. int_angle(0)=0, prev_delta_e(0)=0.
% X then XZ in one invocation; persistent masks. Outputs: PITCH_CLIMB_FF_REGRESSION.{md,mat,png}

    project_dir = fileparts(mfilename('fullpath'));
    addpath(project_dir);
    out_dir = fullfile(project_dir, 'suite_results');
    if ~exist(out_dir, 'dir'); mkdir(out_dir); end
    tag = 'PITCH_CLIMB_FF_REGRESSION';

    clear functions
    clear guidance_law controller_law
    clear global lambda_muw_ff trim_speed_table trim_elevator_table elevator_sign
    clear global K_zdot K_gamma enable_alpha_hat

    init_parameters();
    global lambda_muw_ff elevator_sign trim_speed_table trim_elevator_table
    global K_zdot K_gamma enable_alpha_hat
    global dt_controller delta_e_max
    global Kp_angle Ki_angle

    elevator_sign = 1;
    trim_speed_table = [0.8 1.0 1.5 2.0];
    trim_elevator_table = deg2rad([-9.18 -7.33 -4.62 -3.17]);
    K_gamma = 0;
    K_zdot = 0;
    enable_alpha_hat = false;

    k_gamma = 0.1320695001;
    de_climb_lim_deg = 2.8793;

    % X baseline (STATE_CAPSULE / PITCH_X_TRACK steady)
    baseX = struct( ...
        'mae_deg', 0.0637, ...
        'rms_deg', 0.0683, ...
        'p95_deg', 0.0856, ...
        'sat_pct', 0.00, ...
        'chatter_dps', 0.0190, ...
        'overshoot_deg', 0.0);

    % XZ λ=0 persistent baseline (PITCH_XZ_WINDOW_AUDIT / STATE_CAPSULE)
    baseXZ = struct( ...
        'settle_s', 14.08, ...
        'acq_mae_deg', 1.0876, ...
        'mae_deg', 0.3502, ...
        'rms_deg', 0.3595, ...
        'p95_deg', 0.4812, ...
        'sat_pct', 0.00, ...
        'chatter_dps', 0.0004, ...
        'overshoot_deg', 0.0000, ...
        'dip_deg', 2.9630);

    fprintf('\n========== PITCH_CLIMB_FF_REGRESSION_001 ==========\n');
    fprintf('Promote climb FF k_gamma=%.10f lim=±%.4f° | X(first_hold) then XZ(persistent)\n', ...
        k_gamma, de_climb_lim_deg);

    % ---- X (level; λ=0.25; first_hold windows match STATE/PITCH_X_TRACK) ----
    n = 600;
    x = linspace(0, 45, n)';
    pathX = [x, zeros(n,1), zeros(n,1)];
    mX = run_case(pathX, 18, 1.5, 0.25, k_gamma, de_climb_lim_deg, false, 'first_hold');
    GX = gate_X(mX, baseX);
    fprintf('X   settle=%.2fs MAE=%.4f RMS=%.4f p95=%.4f sat=%.2f%% | %s\n', ...
        mX.settling_s, mX.steady.mae_deg, mX.steady.rms_deg, mX.steady.p95_deg, ...
        mX.elev_sat_pct, tern(GX.pass,'PASS','FAIL'));

    % ---- XZ (λ=0; persistent masks per WINDOW_AUDIT) ----
    n = 900;
    tt = linspace(0, 42, n)';
    pathXZ = [tt, zeros(n,1), 0.4*tt];
    mXZ = run_case(pathXZ, 22, 1.5, 0.0, k_gamma, de_climb_lim_deg, true, 'persistent');
    GXZ = gate_XZ(mXZ, baseXZ);
    fprintf(['XZ  settle=%.2fs acqMAE=%.4f MAE=%.4f RMS=%.4f p95=%.4f ', ...
        'sat=%.2f%% dip=%.4f | %s\n'], ...
        mXZ.settling_s, mXZ.acq.mae_deg, mXZ.steady.mae_deg, mXZ.steady.rms_deg, ...
        mXZ.steady.p95_deg, mXZ.elev_sat_pct, mXZ.dip_deg, tern(GXZ.pass,'PASS','FAIL'));

    pass = GX.pass && GXZ.pass;
    fprintf('Overall: %s\n', tern(pass,'PASS','FAIL'));

    % ---- PNG: ref/actual/error/q/elevator for both ----
    lim_deg = rad2deg(delta_e_max);
    fig = figure('Visible', 'off', 'Color', 'w', 'Position', [30 30 1500 1100]);

    LX = mX.logs; LZ = mXZ.logs;

    subplot(5,2,1); hold on; grid on;
    plot(LX.t, rad2deg(LX.theta_ref), 'k-', 'LineWidth', 1.5);
    plot(LX.t, rad2deg(LX.theta_phys), 'b-', 'LineWidth', 1.2);
    xline(mX.settling_s, 'm--');
    ylabel('\theta [deg]'); title(sprintf('X ref/actual | settle=%.2fs', mX.settling_s));
    legend({'\theta_{ref}','\theta_{phys}'}, 'Location', 'best');

    subplot(5,2,2); hold on; grid on;
    plot(LZ.t, rad2deg(LZ.theta_ref), 'k-', 'LineWidth', 1.5);
    plot(LZ.t, rad2deg(LZ.theta_phys), 'b-', 'LineWidth', 1.2);
    xline(mXZ.settling_s, 'm--');
    ylabel('\theta [deg]'); title(sprintf('XZ ref/actual | settle=%.2fs', mXZ.settling_s));
    legend({'\theta_{ref}','\theta_{phys}'}, 'Location', 'best');

    subplot(5,2,3); hold on; grid on;
    plot(LX.t, rad2deg(LX.e_th), 'b-', 'LineWidth', 1.2);
    yline(0.5, 'k--'); yline(-0.5, 'k--'); yline(0, 'k:');
    xline(mX.settling_s, 'm--');
    ylabel('e_\theta [deg]');
    title(sprintf('X error | MAE=%.4f° RMS=%.4f° p95=%.4f°', ...
        mX.steady.mae_deg, mX.steady.rms_deg, mX.steady.p95_deg));

    subplot(5,2,4); hold on; grid on;
    plot(LZ.t, rad2deg(LZ.e_th), 'b-', 'LineWidth', 1.2);
    yline(0.5, 'k--'); yline(-0.5, 'k--'); yline(0, 'k:');
    xline(mXZ.settling_s, 'm--');
    ylabel('e_\theta [deg]');
    title(sprintf('XZ error | MAE=%.4f° p95=%.4f° acqMAE=%.4f°', ...
        mXZ.steady.mae_deg, mXZ.steady.p95_deg, mXZ.acq.mae_deg));

    subplot(5,2,5); hold on; grid on;
    plot(LX.t, rad2deg(LX.q), 'r-', 'LineWidth', 1.1);
    xline(mX.settling_s, 'm--');
    ylabel('q [deg/s]'); title(sprintf('X q | chatter=%.4f °/s', mX.chatter_dps));

    subplot(5,2,6); hold on; grid on;
    plot(LZ.t, rad2deg(LZ.q), 'r-', 'LineWidth', 1.1);
    xline(mXZ.settling_s, 'm--');
    ylabel('q [deg/s]'); title(sprintf('XZ q | chatter=%.4f °/s', mXZ.chatter_dps));

    subplot(5,2,7); hold on; grid on;
    plot(LX.t, rad2deg(LX.de), 'r-', 'LineWidth', 1.2);
    plot(LX.t, rad2deg(LX.de_climb_ff), 'm-', 'LineWidth', 1.0);
    yline(lim_deg, 'k:'); yline(-lim_deg, 'k:');
    xline(mX.settling_s, 'm--');
    ylabel('\delta_e [deg]'); xlabel('t [s]');
    title(sprintf('X elev | sat=%.2f%% climbFF(t0)=%.3f°', ...
        mX.elev_sat_pct, rad2deg(LX.de_climb_ff(1))));
    legend({'\delta_e','climbFF'}, 'Location', 'best');

    subplot(5,2,8); hold on; grid on;
    plot(LZ.t, rad2deg(LZ.de), 'r-', 'LineWidth', 1.2);
    plot(LZ.t, rad2deg(LZ.de_climb_ff), 'm-', 'LineWidth', 1.0);
    yline(lim_deg, 'k:'); yline(-lim_deg, 'k:');
    xline(mXZ.settling_s, 'm--');
    ylabel('\delta_e [deg]'); xlabel('t [s]');
    title(sprintf('XZ elev | sat=%.2f%% climbFF(t0)=%.3f°', ...
        mXZ.elev_sat_pct, rad2deg(LZ.de_climb_ff(1))));
    legend({'\delta_e','climbFF'}, 'Location', 'best');

    subplot(5,2,9); hold on; grid on;
    plot(LX.t, rad2deg(LX.theta_ref), 'k--', LX.t, rad2deg(LX.theta_phys), 'b-');
    ylabel('\theta [deg]'); xlabel('t [s]');
    title(sprintf('X gates: %s', tern(GX.pass,'PASS','FAIL')));

    subplot(5,2,10); hold on; grid on;
    plot(LZ.t, rad2deg(LZ.theta_ref), 'k--', LZ.t, rad2deg(LZ.theta_phys), 'b-');
    ylabel('\theta [deg]'); xlabel('t [s]');
    title(sprintf('XZ gates: %s | overall %s', tern(GXZ.pass,'PASS','FAIL'), ...
        tern(pass,'PASS','FAIL')));

    sgtitle(sprintf('PITCH_CLIMB_FF_REGRESSION | %s | k_\\gamma=%.4f', ...
        tern(pass,'PASS','FAIL'), k_gamma));

    png_path = fullfile(out_dir, [tag '.png']);
    exportgraphics(fig, png_path, 'Resolution', 150);
    close(fig);

    % ---- MAT ----
    task = struct();
    task.task_id = 'PITCH_CLIMB_FF_REGRESSION_001';
    task.verdict = tern(pass, 'PASS', 'FAIL');
    task.pass = pass;
    task.k_gamma = k_gamma;
    task.de_climb_lim_deg = de_climb_lim_deg;
    task.GX = GX;
    task.GXZ = GXZ;
    task.baseX = baseX;
    task.baseXZ = baseXZ;
    task.production_change = [ ...
        'controller_law.m: de_climb_ff=sat(k_gamma*pitch_ref,+/-2.8793deg) ', ...
        'k_gamma=0.1320695001 added to elevator sum; int_angle(0)=0 prev_delta_e(0)=0'];
    mat_path = fullfile(out_dir, [tag '.mat']);
    save(mat_path, 'task', 'mX', 'mXZ', 'GX', 'GXZ', 'baseX', 'baseXZ', 'k_gamma', 'pass');

    % ---- MD ----
    md_path = fullfile(out_dir, [tag '.md']);
    fid = fopen(md_path, 'w');
    fprintf(fid, '# PITCH_CLIMB_FF_REGRESSION\n\n');
    fprintf(fid, '**TASK_ID:** PITCH_CLIMB_FF_REGRESSION_001\n');
    fprintf(fid, '**Date:** %s\n', datestr(now, 31));
    fprintf(fid, '**Verdict:** **%s**\n\n', tern(pass,'PASS','FAIL'));

    fprintf(fid, '## Change\n\n');
    fprintf(fid, '- **old:** no climb FF (`de_unsat = de_trim + de_uw_ff + de_fb`)\n');
    fprintf(fid, '- **new:** `de_climb_ff = sat(k_gamma*gamma_ref, ±%.4f°)`, ', de_climb_lim_deg);
    fprintf(fid, '`k_gamma=%.10f`, `gamma_ref=pitch_ref` (physical)\n', k_gamma);
    fprintf(fid, '- Elevator sum: `de_unsat = de_trim + de_uw_ff + de_climb_ff + de_fb`\n');
    fprintf(fid, '- `int_angle(0)=0`, `prev_delta_e(0)=0`; XZ `λ=0`; X `λ=0.25` (level)\n');
    fprintf(fid, '- Driver: `run_pitch_climb_ff_regression.m`. No gains/guidance/plant change.\n');
    fprintf(fid, '- Windows: X `first_hold` (match STATE/PITCH_X_TRACK); XZ `persistent` (WINDOW_AUDIT).\n\n');

    fprintf(fid, '## Equations / units / frame / provenance\n\n');
    fprintf(fid, '```\n');
    fprintf(fid, 'k_gamma = 0.1320695001 = 2.8793/21.8014   [-] elevator rad / pitch-ref rad\n');
    fprintf(fid, 'gamma_ref = pitch_ref                     [rad] physical pitch (theta_phys=-theta)\n');
    fprintf(fid, 'de_climb_ff = sat(k_gamma*gamma_ref, +/- deg2rad(2.8793))  [rad] body elevator\n');
    fprintf(fid, 'de_unsat = de_trim(u) + de_uw_ff + de_climb_ff + de_fb\n');
    fprintf(fid, 'int_angle(0)=0; prev_delta_e(0)=0\n');
    fprintf(fid, 'X windows: first_hold ±0.5°/1s; steady=(t≥5∧s<0.88 s_tot)∖acq\n');
    fprintf(fid, 'XZ windows: persistent |eθ|≤±0.5° to end-excl s<0.88*s_total\n');
    fprintf(fid, 'provenance: ATTRIB λ=0 steady mean(de_fb)=+2.8793° / path_pitch=21.8014°\n');
    fprintf(fid, '```\n\n');

    fprintf(fid, '## X before / after (first_hold / STATE baseline)\n\n');
    fprintf(fid, '| Metric | Baseline | Candidate | Δ%% |\n');
    fprintf(fid, '|--------|--------:|----------:|---:|\n');
    fprintf(fid, '| steady MAE [°] | %.4f | %.4f | %+.1f |\n', ...
        baseX.mae_deg, mX.steady.mae_deg, pct(mX.steady.mae_deg, baseX.mae_deg));
    fprintf(fid, '| steady RMS [°] | %.4f | %.4f | %+.1f |\n', ...
        baseX.rms_deg, mX.steady.rms_deg, pct(mX.steady.rms_deg, baseX.rms_deg));
    fprintf(fid, '| steady p95 [°] | %.4f | %.4f | %+.1f |\n', ...
        baseX.p95_deg, mX.steady.p95_deg, pct(mX.steady.p95_deg, baseX.p95_deg));
    fprintf(fid, '| sat%% | %.2f | %.2f | — |\n\n', baseX.sat_pct, mX.elev_sat_pct);

    fprintf(fid, '## XZ before / after (persistent, λ=0)\n\n');
    fprintf(fid, '| Metric | Baseline | Candidate | Δ%% |\n');
    fprintf(fid, '|--------|--------:|----------:|---:|\n');
    fprintf(fid, '| settling [s] | %.2f | %.2f | %+.1f |\n', ...
        baseXZ.settle_s, mXZ.settling_s, pct(mXZ.settling_s, baseXZ.settle_s));
    fprintf(fid, '| acq MAE [°] | %.4f | %.4f | %+.1f |\n', ...
        baseXZ.acq_mae_deg, mXZ.acq.mae_deg, pct(mXZ.acq.mae_deg, baseXZ.acq_mae_deg));
    fprintf(fid, '| steady MAE [°] | %.4f | %.4f | %+.1f |\n', ...
        baseXZ.mae_deg, mXZ.steady.mae_deg, pct(mXZ.steady.mae_deg, baseXZ.mae_deg));
    fprintf(fid, '| steady RMS [°] | %.4f | %.4f | %+.1f |\n', ...
        baseXZ.rms_deg, mXZ.steady.rms_deg, pct(mXZ.steady.rms_deg, baseXZ.rms_deg));
    fprintf(fid, '| steady p95 [°] | %.4f | %.4f | %+.1f |\n', ...
        baseXZ.p95_deg, mXZ.steady.p95_deg, pct(mXZ.steady.p95_deg, baseXZ.p95_deg));
    fprintf(fid, '| dip [°] | %.4f | %.4f | %+.1f |\n', ...
        baseXZ.dip_deg, mXZ.dip_deg, pct(mXZ.dip_deg, baseXZ.dip_deg));
    fprintf(fid, '| overshoot [°] | %.4f | %.4f | — |\n', ...
        baseXZ.overshoot_deg, mXZ.overshoot_deg);
    fprintf(fid, '| sat%% | %.2f | %.2f | — |\n', baseXZ.sat_pct, mXZ.elev_sat_pct);
    fprintf(fid, '| chatter [°/s] | %.4f | %.4f | — |\n\n', ...
        baseXZ.chatter_dps, mXZ.chatter_dps);

    fprintf(fid, '## Gates\n\n');
    fprintf(fid, '| Gate | Result |\n|------|--------|\n');
    fprintf(fid, '| X MAE ≤0.10° | %s (%.4f°) |\n', yn(GX.g_mae), mX.steady.mae_deg);
    fprintf(fid, '| X RMS reg ≤2%% | %s (Δ%%=%+.1f) |\n', yn(GX.g_rms), GX.rms_reg_pct);
    fprintf(fid, '| X p95 reg ≤2%% | %s (Δ%%=%+.1f) |\n', yn(GX.g_p95), GX.p95_reg_pct);
    fprintf(fid, '| XZ MAE ≤0.30° | %s (%.4f°) |\n', yn(GXZ.g_mae), mXZ.steady.mae_deg);
    fprintf(fid, '| XZ p95 ≤0.50° | %s (%.4f°) |\n', yn(GXZ.g_p95), mXZ.steady.p95_deg);
    fprintf(fid, '| XZ acq improve ≥10%% | %s (%.1f%%) |\n', ...
        yn(GXZ.g_acq), GXZ.acq_improve_pct);
    fprintf(fid, '| XZ sat ≤1%% | %s (%.2f%%) |\n', yn(GXZ.g_sat), mXZ.elev_sat_pct);
    fprintf(fid, '| XZ no new chatter | %s |\n', yn(GXZ.g_chatter));
    fprintf(fid, '| XZ no new overshoot | %s |\n', yn(GXZ.g_os));
    fprintf(fid, '\n**Overall: %s**\n\n', tern(pass,'PASS','FAIL'));

    fprintf(fid, '## Evidence\n\n');
    fprintf(fid, '- MATLAB: `run_pitch_climb_ff_regression`\n');
    fprintf(fid, '- suite_results/%s.md\n', tag);
    fprintf(fid, '- suite_results/%s.mat\n', tag);
    fprintf(fid, '- suite_results/%s.png\n\n', tag);

    fprintf(fid, '## Conclusion\n\n');
    if pass
        fprintf(fid, 'PASS: keep climb equilibrium FF in production `controller_law.m`.\n');
        fprintf(fid, 'Next: freeze checklist / optional Muw schedule revisit with climb FF on.\n');
    else
        fprintf(fid, 'FAIL: revert production `controller_law.m` (remove de_climb_ff).\n');
        fprintf(fid, 'Next: diagnose failing gate; do not retune gains.\n');
    end
    fclose(fid);

    fprintf('Wrote suite_results/%s.{md,mat,png}\n', tag);
    assignin('base', 'PITCH_CLIMB_FF_REGRESSION_PASS', pass);
end

function m = run_case(path, T_final, u0, lambda, k_gamma, de_climb_lim_deg, is_xz, win_mode)
    global dt_controller delta_e_max
    global suite_delta_e_log suite_de_fb_log suite_de_trim_log suite_de_uw_ff_log
    global suite_int_angle_log
    global lambda_muw_ff

    lambda_muw_ff = lambda;
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

    de = align_len(suite_delta_e_log(:), numel(t));
    de_fb = align_len(suite_de_fb_log(:), numel(t));
    de_trim = align_len(suite_de_trim_log(:), numel(t));
    de_muw = align_len(suite_de_uw_ff_log(:), numel(t));
    int_angle = align_len(suite_int_angle_log(:), numel(t));

    lim_c = deg2rad(de_climb_lim_deg);
    de_climb_ff = max(min(k_gamma * theta_ref, lim_c), -lim_c);
    de_unsat = de_trim + de_muw + de_climb_ff + de_fb;

    W = compute_pitch_window_metrics(t, e_th, s, s_total, 'mode', win_mode);
    mask_acq = W.mask_acq;
    mask_steady = W.mask_steady;

    th_dot = [0; diff(theta_phys)] / dt;
    lim = delta_e_max;

    m = struct();
    m.lambda = lambda;
    m.settling_s = W.settling_s;
    m.acq_time_s = W.acq_time_s;
    m.acq = W.acq;
    m.steady = W.steady;
    m.n_acq = W.n_acq;
    m.n_steady = W.n_steady;
    m.persistent_ok = W.persistent_ok;
    m.window_mode = W.mode;

    if is_xz
        path_pitch = atan2(0.4, 1);
    else
        path_pitch = 0;
    end
    if any(mask_acq)
        th_acq = theta_phys(mask_acq);
        m.dip_deg = rad2deg(path_pitch - min(th_acq));
        if abs(path_pitch) < 1e-9
            m.overshoot_deg = rad2deg(max(abs(th_acq)));
        else
            final_ref = mean(theta_ref(mask_steady));
            m.overshoot_deg = rad2deg(max(0, max(th_acq) - final_ref));
        end
    else
        m.dip_deg = NaN;
        m.overshoot_deg = NaN;
    end

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

    m.logs = struct('t', t, 'theta_ref', theta_ref, 'theta_phys', theta_phys, ...
        'e_th', e_th, 'q', q, 'de', de, 'de_unsat', de_unsat, ...
        'de_trim', de_trim, 'de_fb', de_fb, 'de_muw', de_muw, ...
        'de_climb_ff', de_climb_ff, 'int_angle', int_angle, ...
        'mask_acq', mask_acq, 'mask_steady', mask_steady);
    m.pm = pm;
end

function G = gate_X(m, base)
    G = struct();
    G.rms_reg_pct = pct(m.steady.rms_deg, base.rms_deg);
    G.p95_reg_pct = pct(m.steady.p95_deg, base.p95_deg);
    G.g_mae = ~isnan(m.steady.mae_deg) && (m.steady.mae_deg <= 0.10);
    G.g_rms = ~isnan(m.steady.rms_deg) && (G.rms_reg_pct <= 2);
    G.g_p95 = ~isnan(m.steady.p95_deg) && (G.p95_reg_pct <= 2);
    G.pass = G.g_mae && G.g_rms && G.g_p95;
end

function G = gate_XZ(m, base)
    G = struct();
    G.acq_improve_pct = 100 * (base.acq_mae_deg - m.acq.mae_deg) / base.acq_mae_deg;
    G.g_mae = ~isnan(m.steady.mae_deg) && (m.steady.mae_deg <= 0.30);
    G.g_p95 = ~isnan(m.steady.p95_deg) && (m.steady.p95_deg <= 0.50);
    G.g_acq = ~isnan(m.acq.mae_deg) && (G.acq_improve_pct >= 10);
    G.g_sat = ~isnan(m.elev_sat_pct) && (m.elev_sat_pct <= 1.0);
    G.g_chatter = ~isnan(m.chatter_dps) && ...
        (m.chatter_dps <= max(base.chatter_dps * 1.5, base.chatter_dps + 0.01));
    G.g_os = ~isnan(m.overshoot_deg) && (m.overshoot_deg <= base.overshoot_deg + 1e-6);
    G.pass = G.g_mae && G.g_p95 && G.g_acq && G.g_sat && G.g_chatter && G.g_os;
end

function p = pct(newv, oldv)
    p = 100 * (newv - oldv) / max(abs(oldv), 1e-12);
end

function y = align_len(x, n)
    x = x(:);
    if isempty(x)
        y = zeros(n, 1);
        return;
    end
    if numel(x) >= n
        y = x(1:n);
    else
        y = [x; x(end) * ones(n - numel(x), 1)];
    end
end

function y = hf_local(x, dt)
    n = max(3, round(0.8 / dt));
    lf = filter(ones(n,1)/n, 1, x(:));
    y = x(:) - lf;
    y(1:min(n, numel(y))) = 0;
end

function s = yn(tf)
    if tf; s = 'YES'; else; s = 'NO'; end
end

function s = tern(tf, a, b)
    if tf; s = a; else; s = b; end
end
