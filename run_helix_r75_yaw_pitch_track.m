function run_helix_r75_yaw_pitch_track()
% HELIX_R75_YAW_PITCH_TRACK_001 — combined yaw+pitch on R=7.5 helix.
% Analysis/driver only: production controller_law / guidance / plant / gains untouched.
% Geometry: same as HELIX_YAW_PITCH_TRACK but R 5.0->7.5 m;
% pitch_h=2, turns=2, n=500, T=45 s, u0=1.5 unchanged. No retune.
% Evidence: suite_results/HELIX_R75_YAW_PITCH_TRACK.{md,mat,png}

    project_dir = fileparts(mfilename('fullpath'));
    addpath(project_dir);
    out_dir = fullfile(project_dir, 'suite_results');
    if ~exist(out_dir, 'dir'); mkdir(out_dir); end
    tag = 'HELIX_R75_YAW_PITCH_TRACK';

    clear functions
    clear guidance_law controller_law
    clear global lambda_muw_ff trim_speed_table trim_elevator_table elevator_sign
    clear global K_zdot K_gamma enable_alpha_hat
    clear global last_guidance_U_h last_guidance_kappa last_r_ff

    init_parameters();
    global lambda_muw_ff elevator_sign trim_speed_table trim_elevator_table
    global K_zdot K_gamma enable_alpha_hat
    global dt_controller dt_guidance delta_e_max delta_r_max

    % Frozen production stack (climb-FF already in controller_law; no edits)
    elevator_sign = 1;
    trim_speed_table = [0.8 1.0 1.5 2.0];
    trim_elevator_table = deg2rad([-9.18 -7.33 -4.62 -3.17]);
    K_gamma = 0;
    K_zdot = 0;
    enable_alpha_hat = false;
    lambda_muw_ff = 0.25; % Tur3/R75 curved-flight production λ

    R = 7.5;
    pitch_h = 2.0;
    num_turns = 2;
    n_path = 500;
    path = generate_balanced_helical_path(R, pitch_h, num_turns, n_path);
    T_final = 45;
    u0 = 1.5;
    geom_note = sprintf(['R75 helix = canonical suite helix with R 5.0->%.1f m only. ', ...
        'Unchanged: pitch_h=%.1f m/turn, turns=%d, n=%d, T=%.0fs, u0=%.2f m/s. ', ...
        'Source: generate_balanced_helical_path; prior FAIL HELIX_YAW_PITCH_TRACK R=5.'], ...
        R, pitch_h, num_turns, n_path, T_final, u0);

    fprintf('\n========== HELIX_R75_YAW_PITCH_TRACK_001 ==========\n');
    fprintf('%s\n', geom_note);

    S = simulate_helix(path, T_final, u0, R);
    M = analyze_helix(S, path, R, delta_e_max, delta_r_max);
    G = gate_helix(M);
    write_evidence(out_dir, tag, S, M, G, path, R, pitch_h, num_turns, ...
        T_final, u0, geom_note, lambda_muw_ff, delta_e_max, delta_r_max);

    fprintf(['Pitch ss MAE=%.4f p95=%.4f sat=%.2f%% chat=%.4f | ', ...
        'Yaw MAE=%.4f p95=%.4f sat=%.2f%% ratio=%.4f | %s\n'], ...
        M.pitch.steady.mae_deg, M.pitch.steady.p95_deg, M.pitch.elev_sat_pct, ...
        M.pitch.chatter_dps, M.yaw.mae_deg, M.yaw.p95_deg, M.yaw.rudder_sat_pct, ...
        M.yaw.ratio_r_Uh_kappa, tern(G.pass, 'PASS', 'FAIL'));
    fprintf('Wrote suite_results/%s.{md,mat,png}\n', tag);
end

%% ===================== simulate =====================
function S = simulate_helix(path, T_final, u0, R)
    global dt_controller dt_guidance
    global last_guidance_U_h last_guidance_kappa last_r_ff
    global last_delta_e last_de_fb

    clear guidance_law controller_law
    dt = dt_controller;
    n_steps = round(T_final / dt);
    guidance_period = max(1, round(dt_guidance / dt));

    state = zeros(12, 1);
    state(1:3) = path(1, :)';
    d = path(2, :) - path(1, :);
    state(5) = -atan2(d(3), norm(d(1:2))); % internal theta = -physical
    state(6) = atan2(d(2), d(1));
    state(7) = u0;

    yaw_ref = 0; pitch_ref = 0; u_ref = u0; r_ff = 0; pitch_ref_dot = 0; pidx = 1;

    S = struct();
    S.path = path; S.R = R; S.dt = dt; S.T_final = T_final; S.u0 = u0;
    S.t = zeros(n_steps, 1);
    S.vp = zeros(n_steps, 3);
    S.vel = zeros(n_steps, 3);
    S.rates = zeros(n_steps, 3);
    S.ori = zeros(n_steps, 3);
    S.psi_ref = zeros(n_steps, 1);
    S.theta_ref = zeros(n_steps, 1);
    S.u_ref = zeros(n_steps, 1);
    S.delta_r = zeros(n_steps, 1);
    S.delta_e = zeros(n_steps, 1);
    S.de_fb = zeros(n_steps, 1);
    S.U_h = zeros(n_steps, 1);
    S.U_h_guid = zeros(n_steps, 1);
    S.kappa = zeros(n_steps, 1);
    S.r_ff = zeros(n_steps, 1);
    S.guidance_tick = false(n_steps, 1);

    for k = 1:n_steps
        pos = state(1:3)';
        ori = state(4:6)';
        rates = state(10:12)';
        u = state(7); v = state(8); w = state(9);
        [Uh, zdot] = inertial_Uh_zdot(ori, u, v, w);
        theta_phys_now = -ori(2);

        if mod(k - 1, guidance_period) == 0
            [yaw_ref, pitch_ref, u_ref, pidx, r_ff, pitch_ref_dot] = ...
                guidance_law(pos, path, pidx, u, v, Uh, zdot, theta_phys_now);
            S.guidance_tick(k) = true;
        end

        [dr, de, thr] = controller_law(yaw_ref, pitch_ref, u_ref, ...
            ori(3), ori(2), rates(3), rates(2), u, r_ff, pitch_ref_dot, ori(1), w);
        controls = struct('delta_r', dr, 'delta_e', de, 'thrust', thr);
        [~, g] = ode45(@(tt, gg) underwater777_vehicle_dynamics(tt, gg, controls), ...
            [0 dt], state);
        state = g(end, :)';

        S.t(k) = k * dt;
        S.vp(k, :) = state(1:3);
        S.vel(k, :) = state(7:9);
        S.rates(k, :) = state(10:12);
        S.ori(k, :) = state(4:6);
        S.psi_ref(k) = yaw_ref;
        S.theta_ref(k) = pitch_ref;
        S.u_ref(k) = u_ref;
        S.delta_r(k) = dr;
        if isempty(last_delta_e); last_delta_e = de; end
        if isempty(last_de_fb); last_de_fb = de; end
        S.delta_e(k) = last_delta_e;
        S.de_fb(k) = last_de_fb;
        S.U_h(k) = Uh;
        if isempty(last_guidance_U_h); last_guidance_U_h = Uh; end
        if isempty(last_guidance_kappa); last_guidance_kappa = 1 / R; end
        if isempty(last_r_ff); last_r_ff = r_ff; end
        S.U_h_guid(k) = last_guidance_U_h;
        S.kappa(k) = last_guidance_kappa;
        S.r_ff(k) = last_r_ff;

        if mod(k, 200) == 0 || k == n_steps
            fprintf('  step %d/%d t=%.1fs xyz=[%.2f %.2f %.2f]\n', ...
                k, n_steps, S.t(k), state(1), state(2), state(3));
        end
    end
end

%% ===================== analyze =====================
function M = analyze_helix(S, path, R, de_max, dr_max)
    t = S.t(:);
    dt = S.dt;
    psi = S.ori(:, 3);
    theta_phys = -S.ori(:, 2);
    theta_ref = S.theta_ref(:);
    psi_ref = S.psi_ref(:);
    e_psi = wrapToPi(psi_ref - psi);
    e_th = theta_ref - theta_phys;
    q = S.rates(:, 2);
    r = S.rates(:, 3);
    de = S.delta_e(:);
    dr = S.delta_r(:);

    pm = compute_path_following_metrics(path, S.vp, S.vel, S.ori, ...
        psi_ref, theta_ref, dt, t);
    s = pm.s_prog(:);
    s_total = pm.s_total;

    % Pitch: persistent ±0.5° settle → end-exclusion (open helix)
    W = compute_pitch_window_metrics(t, e_th, s, s_total, 'mode', 'persistent');

    % Radial (cylinder): e_r = hypot(x,y) - R  [m]; report on pitch-steady ∩ before-end
    rho = hypot(S.vp(:, 1), S.vp(:, 2));
    e_radial = rho - R;

    % Yaw / rate window: settled_before_end (open-path Frenet), independent of pitch settle
    mask_yaw = (t >= 5.0) & W.mask_before_end;
    if ~any(mask_yaw)
        mask_yaw = t >= 5.0;
    end

    % r/(Uh*kappa) where |kappa| and Uh meaningful
    Uh_k = S.U_h_guid .* S.kappa;
    valid_ratio = mask_yaw & (abs(S.kappa) > 1e-4) & (abs(S.U_h_guid) > 0.3);
    if any(valid_ratio)
        mean_r = mean(r(valid_ratio));
        mean_Uh_k = mean(Uh_k(valid_ratio));
        if mean_Uh_k < 0
            mean_Uh_k = -mean_Uh_k;
            mean_r = -mean_r;
        end
        ratio = mean_r / max(abs(mean_Uh_k), 1e-9);
    else
        mean_r = NaN; mean_Uh_k = NaN; ratio = NaN;
    end

    M = struct();
    M.pm = pm;
    M.W = W;
    M.s_total = s_total;
    M.is_closed = norm(path(1, :) - path(end, :)) < 0.25;
    pitch_h_est = path(end, 3) / 2; % canonical num_turns=2
    M.path_pitch_deg = rad2deg(atan(pitch_h_est / (2 * pi * R)));

    M.pitch = struct();
    M.pitch.acq = W.acq;
    M.pitch.steady = W.steady;
    M.pitch.settling_s = W.settling_s;
    M.pitch.acq_time_s = W.acq_time_s;
    M.pitch.persistent_ok = W.persistent_ok;
    M.pitch.window_mode = W.mode;

    mask_ss = W.mask_steady;
    if any(mask_ss)
        th_dot = [0; diff(theta_phys)] / dt;
        dth_ss = th_dot(mask_ss);
        M.pitch.chatter_dps = rad2deg(std(hf_local(detrend(dth_ss), dt)));
        M.pitch.elev_sat_pct = 100 * mean(abs(de(mask_ss)) >= 0.98 * de_max);
        M.pitch.elev_mean_deg = rad2deg(mean(de(mask_ss)));
        M.pitch.q_rms_dps = rad2deg(rms(q(mask_ss)));
        M.pitch.q_ripple_rms_dps = rad2deg(rms(q(mask_ss) - mean(q(mask_ss))));
        M.pitch.radial_mae_m = mean(abs(e_radial(mask_ss)));
        M.pitch.radial_mean_m = mean(e_radial(mask_ss));
    else
        M.pitch.chatter_dps = NaN;
        M.pitch.elev_sat_pct = NaN;
        M.pitch.elev_mean_deg = NaN;
        M.pitch.q_rms_dps = NaN;
        M.pitch.q_ripple_rms_dps = NaN;
        M.pitch.radial_mae_m = NaN;
        M.pitch.radial_mean_m = NaN;
    end

    M.yaw = struct();
    if any(mask_yaw)
        M.yaw.mae_deg = rad2deg(mean(abs(e_psi(mask_yaw))));
        M.yaw.rms_deg = rad2deg(rms(e_psi(mask_yaw)));
        M.yaw.signed_deg = rad2deg(mean(e_psi(mask_yaw)));
        M.yaw.p95_deg = rad2deg(pctile95(abs(e_psi(mask_yaw))));
        M.yaw.max_deg = rad2deg(max(abs(e_psi(mask_yaw))));
        M.yaw.rudder_sat_pct = 100 * mean(abs(dr(mask_yaw)) >= 0.95 * dr_max);
        M.yaw.rudder_mean_deg = rad2deg(mean(dr(mask_yaw)));
        M.yaw.r_mean_dps = rad2deg(mean(r(mask_yaw)));
    else
        M.yaw.mae_deg = NaN; M.yaw.rms_deg = NaN; M.yaw.signed_deg = NaN;
        M.yaw.p95_deg = NaN; M.yaw.max_deg = NaN;
        M.yaw.rudder_sat_pct = NaN; M.yaw.rudder_mean_deg = NaN;
        M.yaw.r_mean_dps = NaN;
    end
    M.yaw.ratio_r_Uh_kappa = ratio;
    M.yaw.mean_r_rad = mean_r;
    M.yaw.mean_Uh_kappa_rad = mean_Uh_k;
    M.yaw.n_ratio_valid = nnz(valid_ratio);
    M.yaw.cte_perp_sbe = pm.mean_cte_perp;
    M.yaw.e_xy_sbe = pm.horizontal_normal_settled_before_end.mean;
    M.yaw.radial_mae_sbe = mean(abs(e_radial(mask_yaw)));
    M.yaw.radial_mean_sbe = mean(e_radial(mask_yaw));

    % Acquisition (pitch) reported separately — not a hard gate here
    M.acq_report = struct( ...
        'settling_s', W.settling_s, ...
        'mae_deg', W.acq.mae_deg, ...
        'rms_deg', W.acq.rms_deg, ...
        'p95_deg', W.acq.p95_deg, ...
        'signed_deg', W.acq.signed_deg);

    M.logs = struct('t', t, 'e_psi', e_psi, 'e_th', e_th, ...
        'psi', psi, 'psi_ref', psi_ref, ...
        'theta_phys', theta_phys, 'theta_ref', theta_ref, ...
        'q', q, 'r', r, 'de', de, 'dr', dr, ...
        'e_radial', e_radial, 'rho', rho, ...
        'Uh_k', Uh_k, 'mask_yaw', mask_yaw, ...
        'mask_acq', W.mask_acq, 'mask_steady', W.mask_steady, ...
        'mask_before_end', W.mask_before_end, 'valid_ratio', valid_ratio);
end

function G = gate_helix(M)
    G = struct();
    G.g_pitch_mae = ~isnan(M.pitch.steady.mae_deg) && (M.pitch.steady.mae_deg <= 0.30);
    G.g_pitch_p95 = ~isnan(M.pitch.steady.p95_deg) && (M.pitch.steady.p95_deg <= 0.50);
    G.g_pitch_sat = ~isnan(M.pitch.elev_sat_pct) && (M.pitch.elev_sat_pct <= 1.0);
    G.g_pitch_chatter = ~isnan(M.pitch.chatter_dps) && (M.pitch.chatter_dps <= 0.20);
    G.g_pitch_persist = M.pitch.persistent_ok;
    G.g_yaw_mae = ~isnan(M.yaw.mae_deg) && (M.yaw.mae_deg <= 1.0);
    G.g_yaw_p95 = ~isnan(M.yaw.p95_deg) && (M.yaw.p95_deg <= 2.0);
    G.g_yaw_sat = ~isnan(M.yaw.rudder_sat_pct) && (M.yaw.rudder_sat_pct <= 1.0);
    if M.yaw.n_ratio_valid > 10 && ~isnan(M.yaw.ratio_r_Uh_kappa)
        G.g_ratio = (M.yaw.ratio_r_Uh_kappa >= 0.98) && (M.yaw.ratio_r_Uh_kappa <= 1.02);
        G.ratio_applicable = true;
    else
        G.g_ratio = true; % not scored if invalid
        G.ratio_applicable = false;
    end
    G.g_no_ctrl_change = true; % driver/analysis only by construction
    G.pass = G.g_pitch_mae && G.g_pitch_p95 && G.g_pitch_sat && G.g_pitch_chatter && ...
        G.g_pitch_persist && G.g_yaw_mae && G.g_yaw_p95 && G.g_yaw_sat && ...
        G.g_ratio && G.g_no_ctrl_change;
end

%% ===================== evidence =====================
function write_evidence(out_dir, tag, S, M, G, path, R, pitch_h, num_turns, ...
        T_final, u0, geom_note, lam, de_max, dr_max)
    L = M.logs;
    lim_e = rad2deg(de_max);
    lim_r = rad2deg(dr_max);

    fig = figure('Visible', 'off', 'Color', 'w', 'Position', [30 30 1400 1000]);

    subplot(3, 3, [1 4]);
    plot3(path(:, 1), path(:, 2), path(:, 3), 'k--', 'LineWidth', 1.5); hold on;
    plot3(S.vp(:, 1), S.vp(:, 2), S.vp(:, 3), 'b-', 'LineWidth', 1.2);
    plot3(S.vp(1, 1), S.vp(1, 2), S.vp(1, 3), 'go', 'MarkerFaceColor', 'g');
    plot3(S.vp(end, 1), S.vp(end, 2), S.vp(end, 3), 'rs', 'MarkerFaceColor', 'r');
    grid on; axis equal;
    xlabel('X [m]'); ylabel('Y [m]'); zlabel('Z [m]');
    title(sprintf('3D helix overlay | CTE_{sbe}=%.3f m | e_r MAE=%.3f m', ...
        M.yaw.cte_perp_sbe, M.yaw.radial_mae_sbe));
    legend({'path', 'vehicle', 'start', 'end'}, 'Location', 'best');
    view(35, 22);

    subplot(3, 3, 2); hold on; grid on;
    plot(L.t, rad2deg(unwrap(L.psi_ref)), 'k-', 'LineWidth', 1.3);
    plot(L.t, rad2deg(unwrap(L.psi)), 'b-', 'LineWidth', 1.0);
    ylabel('\psi [deg]'); xlabel('t [s]');
    title('\psi_{ref} / \psi (unwrapped display)');
    legend({'\psi_{ref}', '\psi'}, 'Location', 'best');

    subplot(3, 3, 3); hold on; grid on;
    plot(L.t, rad2deg(L.e_psi), 'b-', 'LineWidth', 1.0);
    yline(0, 'k:');
    ylabel('e_\psi wrap [deg]'); xlabel('t [s]');
    title(sprintf('wrapped e_\\psi | MAE=%.3f° p95=%.3f°', M.yaw.mae_deg, M.yaw.p95_deg));

    subplot(3, 3, 5); hold on; grid on;
    plot(L.t, rad2deg(L.theta_ref), 'k-', 'LineWidth', 1.3);
    plot(L.t, rad2deg(L.theta_phys), 'b-', 'LineWidth', 1.0);
    if ~isnan(M.pitch.settling_s); xline(M.pitch.settling_s, 'r--', 'settle'); end
    ylabel('\theta [deg]'); xlabel('t [s]');
    title('\theta_{ref} / \theta_{phys}');
    legend({'\theta_{ref}', '\theta_{phys}'}, 'Location', 'best');

    subplot(3, 3, 6); hold on; grid on;
    plot(L.t, rad2deg(L.e_th), 'b-', 'LineWidth', 1.0);
    yline(0.5, 'k--'); yline(-0.5, 'k--'); yline(0, 'k:');
    if ~isnan(M.pitch.settling_s); xline(M.pitch.settling_s, 'r--'); end
    ylabel('e_\theta [deg]'); xlabel('t [s]');
    title(sprintf('e_\\theta | ss MAE=%.3f° p95=%.3f°', ...
        M.pitch.steady.mae_deg, M.pitch.steady.p95_deg));

    subplot(3, 3, 7); hold on; grid on;
    plot(L.t, rad2deg(L.r), 'b-', 'LineWidth', 1.0);
    plot(L.t, rad2deg(L.q), 'r-', 'LineWidth', 1.0);
    ylabel('[deg/s]'); xlabel('t [s]');
    title(sprintf('r / q | ratio r/(U_h\\kappa)=%.3f', M.yaw.ratio_r_Uh_kappa));
    legend({'r', 'q'}, 'Location', 'best');

    subplot(3, 3, 8); hold on; grid on;
    plot(L.t, rad2deg(L.dr), 'b-', 'LineWidth', 1.0);
    yline(lim_r, 'k--'); yline(-lim_r, 'k--');
    ylabel('\delta_r [deg]'); xlabel('t [s]');
    title(sprintf('rudder \\pm%.0f° | sat=%.2f%%', lim_r, M.yaw.rudder_sat_pct));

    subplot(3, 3, 9); hold on; grid on;
    plot(L.t, rad2deg(L.de), 'b-', 'LineWidth', 1.0);
    yline(lim_e, 'k--'); yline(-lim_e, 'k--');
    if ~isnan(M.pitch.settling_s); xline(M.pitch.settling_s, 'r--'); end
    ylabel('\delta_e [deg]'); xlabel('t [s]');
    title(sprintf('elevator \\pm%.0f° | sat=%.2f%%', lim_e, M.pitch.elev_sat_pct));

    sgtitle(sprintf('HELIX_R75_YAW_PITCH_TRACK | %s | R=%.1f u=%.1f', ...
        tern(G.pass, 'PASS', 'FAIL'), R, u0));

    png_path = fullfile(out_dir, [tag '.png']);
    exportgraphics(fig, png_path, 'Resolution', 150);
    close(fig);

    task = struct();
    task.task_id = 'HELIX_R75_YAW_PITCH_TRACK_001';
    task.pass = G.pass;
    task.gates = G;
    task.geom_note = geom_note;
    task.R = R; task.pitch_h = pitch_h; task.num_turns = num_turns;
    task.T_final = T_final; task.u0 = u0; task.lambda_muw_ff = lam;
    task.controller_changed = false;
    task.x_xz_production_changed = false;
    mat_path = fullfile(out_dir, [tag '.mat']);
    save(mat_path, 'task', 'S', 'M', 'G', 'path');

    md_path = fullfile(out_dir, [tag '.md']);
    fid = fopen(md_path, 'w');
    fprintf(fid, '# HELIX_R75_YAW_PITCH_TRACK\n\n');
    fprintf(fid, '**TASK_ID:** HELIX_R75_YAW_PITCH_TRACK_001\n');
    fprintf(fid, '**Date:** %s\n', datestr(now, 31));
    fprintf(fid, '**Verdict:** **%s**\n\n', tern(G.pass, 'PASS', 'FAIL'));
    fprintf(fid, 'Analysis/driver only. Production `controller_law` / guidance / plant / gains **unchanged**. ');
    fprintf(fid, 'Climb-FF already in production. X/XZ production stack untouched. No retune.\n\n');
    fprintf(fid, '## Geometry / provenance\n\n%s\n\n', geom_note);
    fprintf(fid, '- Frames: NED; internal `theta` negated → physical `theta_phys=-theta`.\n');
    fprintf(fid, '- `e_psi = wrapToPi(psi_ref - psi)` [rad→deg for report].\n');
    fprintf(fid, '- `e_theta = pitch_ref - theta_phys` (physical).\n');
    fprintf(fid, '- Pitch windows: `compute_pitch_window_metrics` **persistent** ±0.5° to s<0.88 s_tot.\n');
    fprintf(fid, '- Path metric: Frenet `CTE_perp` settled_before_end (open helix, not closed).\n');
    fprintf(fid, '- Radial: `e_r = hypot(x,y) - R` [m].\n');
    fprintf(fid, '- Rate match: `r / (U_h_guid * kappa)` on yaw SBE ∩ |κ|>1e-4 ∩ U_h>0.3.\n');
    fprintf(fid, '- λ_Muw=%.2f (curved-flight production).\n\n', lam);

    fprintf(fid, '## Acquisition (pitch, reported separately — not a hard gate)\n\n');
    fprintf(fid, '| Metric | Value |\n|--------|------:|\n');
    fprintf(fid, '| settling [s] | %.2f |\n', M.acq_report.settling_s);
    fprintf(fid, '| MAE / RMS / p95 [°] | %.4f / %.4f / %.4f |\n', ...
        M.acq_report.mae_deg, M.acq_report.rms_deg, M.acq_report.p95_deg);
    fprintf(fid, '| signed [°] | %+.4f |\n\n', M.acq_report.signed_deg);

    fprintf(fid, '## Pitch steady (persistent)\n\n');
    fprintf(fid, '| Metric | Value |\n|--------|------:|\n');
    fprintf(fid, '| MAE / RMS / p95 [°] | %.4f / %.4f / %.4f |\n', ...
        M.pitch.steady.mae_deg, M.pitch.steady.rms_deg, M.pitch.steady.p95_deg);
    fprintf(fid, '| signed / max\\|e\\| [°] | %+.4f / %.4f |\n', ...
        M.pitch.steady.signed_deg, M.pitch.steady.max_deg);
    fprintf(fid, '| elev sat%% | %.2f |\n', M.pitch.elev_sat_pct);
    fprintf(fid, '| chatter [°/s] | %.4f |\n', M.pitch.chatter_dps);
    fprintf(fid, '| q RMS / ripple [°/s] | %.4f / %.4f |\n\n', ...
        M.pitch.q_rms_dps, M.pitch.q_ripple_rms_dps);

    fprintf(fid, '## Yaw (settled_before_end)\n\n');
    fprintf(fid, '| Metric | Value |\n|--------|------:|\n');
    fprintf(fid, '| MAE / RMS / p95 [°] | %.4f / %.4f / %.4f |\n', ...
        M.yaw.mae_deg, M.yaw.rms_deg, M.yaw.p95_deg);
    fprintf(fid, '| signed / max\\|e\\| [°] | %+.4f / %.4f |\n', ...
        M.yaw.signed_deg, M.yaw.max_deg);
    fprintf(fid, '| rudder sat%% | %.2f |\n', M.yaw.rudder_sat_pct);
    fprintf(fid, '| r/(U_h κ) | %.4f (n_valid=%d) |\n', ...
        M.yaw.ratio_r_Uh_kappa, M.yaw.n_ratio_valid);
    fprintf(fid, '| CTE_perp sbe [m] | %.4f |\n', M.yaw.cte_perp_sbe);
    fprintf(fid, '| radial MAE / mean [m] | %.4f / %+.4f |\n\n', ...
        M.yaw.radial_mae_sbe, M.yaw.radial_mean_sbe);

    fprintf(fid, '## PASS gates\n\n');
    fprintf(fid, '| Gate | Result | Detail |\n|------|:------:|--------|\n');
    fprintf(fid, '| pitch ss MAE ≤0.30° | %s | %.4f° |\n', yn(G.g_pitch_mae), M.pitch.steady.mae_deg);
    fprintf(fid, '| pitch ss p95 ≤0.50° | %s | %.4f° |\n', yn(G.g_pitch_p95), M.pitch.steady.p95_deg);
    fprintf(fid, '| pitch elev sat ≤1%% | %s | %.2f%% |\n', yn(G.g_pitch_sat), M.pitch.elev_sat_pct);
    fprintf(fid, '| pitch no chatter (≤0.20 °/s) | %s | %.4f |\n', yn(G.g_pitch_chatter), M.pitch.chatter_dps);
    fprintf(fid, '| pitch persistent settle | %s | t=%.2fs |\n', yn(G.g_pitch_persist), M.pitch.settling_s);
    fprintf(fid, '| yaw MAE ≤1° | %s | %.4f° |\n', yn(G.g_yaw_mae), M.yaw.mae_deg);
    fprintf(fid, '| yaw p95 ≤2° | %s | %.4f° |\n', yn(G.g_yaw_p95), M.yaw.p95_deg);
    fprintf(fid, '| rudder sat ≤1%% | %s | %.2f%% |\n', yn(G.g_yaw_sat), M.yaw.rudder_sat_pct);
    fprintf(fid, '| r/(U_h κ) ∈ [0.98,1.02] | %s | %.4f (applicable=%s) |\n', ...
        yn(G.g_ratio), M.yaw.ratio_r_Uh_kappa, yn(G.ratio_applicable));
    fprintf(fid, '| no X/XZ production change | %s | driver only |\n\n', yn(G.g_no_ctrl_change));

    fprintf(fid, '## MATHEMATICAL_DELTA\n\n');
    fprintf(fid, '```\n');
    fprintf(fid, 'e_psi = wrapToPi(psi_ref - psi)\n');
    fprintf(fid, 'e_theta = pitch_ref - theta_phys,  theta_phys = -theta_internal\n');
    fprintf(fid, 'e_r = hypot(x,y) - R\n');
    fprintf(fid, 'ratio = mean(r) / mean(U_h_guid * kappa)   [sign-normalized]\n');
    fprintf(fid, 'pitch_ss = persistent |e_theta|<=0.5deg to s<0.88*s_total\n');
    fprintf(fid, 'yaw_ss = t>=5 & s<0.88*s_total (open helix Frenet SBE)\n');
    fprintf(fid, 'hist_helix_R5_yaw_FAIL MAE~37.7 rudder_sat~95%% (HELIX_YAW_PITCH_TRACK)\n');
    fprintf(fid, 'hist_R75_circle_yaw MAE~0.3065 (capsule)\n');
    fprintf(fid, '```\n\n');

    fprintf(fid, '## Classification (no controller change)\n\n');
    if G.pass
        fprintf(fid, 'PASS — combined R=7.5 helix yaw+pitch within gates; driver-only; production unchanged.\n\n');
    else
        fail_yaw_auth = (~G.g_yaw_sat) || (~G.g_ratio) || (~G.g_yaw_mae && M.yaw.rudder_sat_pct > 20);
        fail_pitch = ~(G.g_pitch_mae && G.g_pitch_p95 && G.g_pitch_sat && G.g_pitch_chatter && G.g_pitch_persist);
        if fail_yaw_auth && ~fail_pitch
            fprintf(fid, 'FAIL class: **yaw authority margin** (soft). ');
            fprintf(fid, 'Tracking OK if e_psi small; missed sat and/or r/(U_h κ) gates. ');
            fprintf(fid, 'Not metric/window; not controller retune. Pitch channel OK if pitch gates pass.\n\n');
        elseif fail_pitch && G.g_yaw_mae && G.g_yaw_sat
            fprintf(fid, 'FAIL class: **pitch** (unexpected vs climb-FF). Diagnose path-pitch coupling before any gain change.\n\n');
        elseif ~G.g_yaw_mae && M.yaw.rudder_sat_pct <= 1.0 && G.g_ratio
            fprintf(fid, 'FAIL class: **metric/window** candidate (yaw error with unsaturated rudder and good rate match).\n\n');
        else
            fprintf(fid, 'FAIL class: **mixed** — inspect gates; prefer metric then authority before controller.\n\n');
        end
    end

    fprintf(fid, '## Files\n\n');
    fprintf(fid, '- `run_helix_r75_yaw_pitch_track.m` (analysis driver only)\n');
    fprintf(fid, '- `suite_results/HELIX_R75_YAW_PITCH_TRACK.md`\n');
    fprintf(fid, '- `suite_results/HELIX_R75_YAW_PITCH_TRACK.mat`\n');
    fprintf(fid, '- `suite_results/HELIX_R75_YAW_PITCH_TRACK.png`\n');
    fclose(fid);

    % Append research log
    log_path = fullfile(out_dir, 'PITCH_CONTROL_RESEARCH_LOG.md');
    lfid = fopen(log_path, 'a');
    fprintf(lfid, '\n## HELIX_R75_YAW_PITCH_TRACK_001 — %s\n\n', datestr(now, 31));
    fprintf(lfid, '- Verdict: **%s** — combined yaw+pitch on R=%.1f helix (canonical geometry R 5.0->7.5 only; pitch_h=2, turns=2, u0=1.5).\n', ...
        tern(G.pass, 'PASS', 'FAIL'), R);
    fprintf(lfid, '- Driver only (`run_helix_r75_yaw_pitch_track.m`); controller/gains/guidance/plant unchanged; no retune; X/XZ production untouched.\n');
    fprintf(lfid, '- Pitch ss (persistent): MAE=%.4f RMS=%.4f p95=%.4f sat=%.2f%% chat=%.4f settle=%.2fs; acqMAE=%.4f.\n', ...
        M.pitch.steady.mae_deg, M.pitch.steady.rms_deg, M.pitch.steady.p95_deg, ...
        M.pitch.elev_sat_pct, M.pitch.chatter_dps, M.pitch.settling_s, M.acq_report.mae_deg);
    fprintf(lfid, '- Yaw SBE: MAE=%.4f RMS=%.4f p95=%.4f sat=%.2f%%; r/(U_hκ)=%.4f; CTE_perp=%.3f m; e_r MAE=%.3f m.\n', ...
        M.yaw.mae_deg, M.yaw.rms_deg, M.yaw.p95_deg, M.yaw.rudder_sat_pct, ...
        M.yaw.ratio_r_Uh_kappa, M.yaw.cte_perp_sbe, M.yaw.radial_mae_sbe);
    fprintf(lfid, '- Artifacts: suite_results/HELIX_R75_YAW_PITCH_TRACK.{md,mat,png}.\n');
    if G.pass
        fprintf(lfid, '- Next: freeze R75 combined yaw+pitch as combined acceptance; CODEX_VERTICAL_PLAN untouched.\n');
    else
        % Classify: metric vs authority vs controller (no changes this task)
        fail_yaw_auth = (~G.g_yaw_sat) || (~G.g_ratio) || (~G.g_yaw_mae && M.yaw.rudder_sat_pct > 20);
        fail_pitch = ~(G.g_pitch_mae && G.g_pitch_p95 && G.g_pitch_sat && G.g_pitch_chatter && G.g_pitch_persist);
        if fail_yaw_auth && ~fail_pitch
            fprintf(lfid, '- FAIL class: **yaw authority/envelope** (not metric/window; not controller retune). Pitch channel OK.\n');
            fprintf(lfid, '- Next: compare to R75 circle yaw baseline / radius-speed envelope; no gain change; CODEX_VERTICAL_PLAN untouched.\n');
        elseif fail_pitch && G.g_yaw_mae && G.g_yaw_sat
            fprintf(lfid, '- FAIL class: **pitch** (controller/path coupling) — unexpected vs climb-FF PASS; diagnose without retune first.\n');
            fprintf(lfid, '- Next: attribute pitch vs helix climb angle; CODEX_VERTICAL_PLAN untouched.\n');
        else
            fprintf(lfid, '- FAIL class: mixed — check metric/window first, then authority, then controller; no changes this task.\n');
            fprintf(lfid, '- Next: gate-by-gate diagnose; CODEX_VERTICAL_PLAN untouched.\n');
        end
    end
    fclose(lfid);
end

%% ===================== helpers =====================
function [Uh, zdot] = inertial_Uh_zdot(ori, u, v, w)
    phi = ori(1); theta = ori(2); psi = ori(3);
    Rm = [cos(psi)*cos(theta), ...
         cos(psi)*sin(theta)*sin(phi) - sin(psi)*cos(phi), ...
         cos(psi)*sin(theta)*cos(phi) + sin(psi)*sin(phi);
         sin(psi)*cos(theta), ...
         sin(psi)*sin(theta)*sin(phi) + cos(psi)*cos(phi), ...
         sin(psi)*sin(theta)*cos(phi) - cos(psi)*sin(phi);
         -sin(theta), ...
         cos(theta)*sin(phi), ...
         cos(theta)*cos(phi)];
    pos_dot = Rm * [u; v; w];
    Uh = hypot(pos_dot(1), pos_dot(2));
    zdot = pos_dot(3);
end

function y = hf_local(x, dt)
    n = max(3, round(0.8 / dt));
    lf = filter(ones(n, 1) / n, 1, x(:));
    y = x(:) - lf;
    y(1:min(n, numel(y))) = 0;
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
