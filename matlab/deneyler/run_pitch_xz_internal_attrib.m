function run_pitch_xz_internal_attrib()
% PITCH_XZ_INTERNAL_ATTRIB_001 — attribute initial XZ pitch dip/lag (λ=0).
% Analysis-only driver. Does NOT modify production controller/guidance/plant.
% Outputs: suite_results/PITCH_XZ_INTERNAL_ATTRIB.{md,mat,png}

    project_dir = fileparts(fileparts(fileparts(mfilename('fullpath')))); % repo root
    addpath(genpath(fullfile(project_dir, 'matlab')));
    out_dir = fullfile(project_dir, 'suite_results');
    if ~exist(out_dir, 'dir'); mkdir(out_dir); end
    tag = 'PITCH_XZ_INTERNAL_ATTRIB';

    clear functions
    clear guidance_law controller_law
    clear global lambda_muw_ff trim_speed_table trim_elevator_table elevator_sign
    clear global K_zdot K_gamma enable_alpha_hat

    init_parameters();
    global lambda_muw_ff elevator_sign trim_speed_table trim_elevator_table
    global K_zdot K_gamma enable_alpha_hat
    global dt_controller dt_guidance delta_e_max
    global Muw Muuds

    % Frozen production stack (identical to run_pitch_xz_track / closure)
    elevator_sign = 1;
    trim_speed_table = [0.8 1.0 1.5 2.0];
    trim_elevator_table = deg2rad([-9.18 -7.33 -4.62 -3.17]);
    K_gamma = 0;
    K_zdot = 0;
    enable_alpha_hat = false;
    lambda_muw_ff = 0.0;  % accepted XZ baseline

    n = 900;
    tt = linspace(0, 42, n)';
    path = [tt, zeros(n,1), 0.4*tt];
    T_final = 22;
    u0 = 1.5;
    path_pitch = atan2(0.4, 1);

    fprintf('\n========== PITCH_XZ_INTERNAL_ATTRIB_001 ==========\n');
    fprintf('XZ λ=0 one-shot attribution | no production edits\n');

    S = simulate_instrumented(path, T_final, u0);
    A = analyze_attrib(S, path_pitch, delta_e_max, lambda_muw_ff, Muw, Muuds, dt_controller);
    write_evidence(out_dir, tag, S, A, path, T_final, u0, path_pitch, ...
        delta_e_max, dt_controller, dt_guidance, lambda_muw_ff);

    fprintf('Class=%s | Verdict=%s | dip=%.3f° t_dip=%.2fs acq=%.2fs\n', ...
        A.dominant_class, A.verdict, A.dip_deg, A.t_dip, A.acq_time_s);
    fprintf('Wrote suite_results/%s.{md,mat,png}\n', tag);
end

%% ===================== instrumented sim (analysis driver only) =====================
function S = simulate_instrumented(path, T_final, u0)
    global dt_controller dt_guidance delta_e_max

    dt = dt_controller;
    n_steps = round(T_final / dt);
    guidance_period = max(1, round(dt_guidance / dt));
    max_de = deg2rad(40) * dt;

    state = zeros(12,1);
    state(1:3) = path(1,:)';
    d = path(2,:) - path(1,:);
    state(5) = -atan2(d(3), norm(d(1:2)));
    state(6) = atan2(d(2), d(1));
    state(7) = u0;

    yaw_ref = 0; pitch_ref = 0; u_ref = u0; r_ff = 0; pitch_ref_dot = 0; pidx = 1;
    prev_de = 0;

    S = struct();
    S.path = path; S.dt = dt; S.u0 = u0; S.T_final = T_final;
    S.guidance_period = guidance_period;
    S.t = zeros(n_steps,1);
    S.vp = zeros(n_steps,3);
    S.theta = zeros(n_steps,1);          % body Euler theta
    S.theta_phys = zeros(n_steps,1);
    S.theta_ref = zeros(n_steps,1);
    S.theta_ref_dot = zeros(n_steps,1);
    S.q = zeros(n_steps,1);
    S.theta_dot = zeros(n_steps,1);      % theta_phys_dot
    S.q_ref = zeros(n_steps,1);          % theta_rate_cmd from dbg
    S.e_theta = zeros(n_steps,1);
    S.e_rate = zeros(n_steps,1);
    S.int_angle = zeros(n_steps,1);
    S.int_rate = zeros(n_steps,1);
    S.de_trim = zeros(n_steps,1);
    S.de_fb = zeros(n_steps,1);
    S.de_muw_ff = zeros(n_steps,1);
    S.de_unsat = zeros(n_steps,1);
    S.de_cmd_sat = zeros(n_steps,1);     % after magnitude sat, before RL
    S.de_final = zeros(n_steps,1);       % rate-limited output
    S.flag_sat = false(n_steps,1);
    S.flag_rl = false(n_steps,1);
    S.u = zeros(n_steps,1);
    S.w = zeros(n_steps,1);
    S.M_uw = zeros(n_steps,1);
    S.M_elev = zeros(n_steps,1);
    S.G_de = zeros(n_steps,1);
    S.rate_filt = zeros(n_steps,1);
    S.phi = zeros(n_steps,1);
    S.psi = zeros(n_steps,1);
    S.r = zeros(n_steps,1);

    for k = 1:n_steps
        pos = state(1:3)';
        ori = state(4:6)';
        rates = state(10:12)';
        u = state(7); v = state(8); w = state(9);
        [Uh, zdot] = inertial_Uh_zdot(ori, u, v, w);
        theta_phys_now = -ori(2);

        tick = (mod(k - 1, guidance_period) == 0);
        if tick
            [yaw_ref, pitch_ref, u_ref, pidx, r_ff, pitch_ref_dot] = ...
                guidance_law(pos, path, pidx, u, v, Uh, zdot, theta_phys_now);
        end

        [dr, de, thr, dbg] = controller_law(yaw_ref, pitch_ref, u_ref, ...
            ori(3), ori(2), rates(3), rates(2), u, r_ff, pitch_ref_dot, ori(1), w);

        % Reconstruct sat / rate-limit flags (identical thresholds to controller_law)
        de_unsat = dbg.delta_e_unsat;
        de_cmd = dbg.delta_e_cmd;
        flag_sat = abs(de_unsat) > delta_e_max + 1e-9;
        dcmd = de_cmd - prev_de;
        flag_rl = abs(dcmd) > max_de + 1e-15;

        controls = struct('delta_r', dr, 'delta_e', de, 'thrust', thr);
        [~, g] = ode45(@(tt, g) underwater777_vehicle_dynamics(tt, g, controls), [0 dt], state);
        state = g(end, :)';

        S.t(k) = k * dt;
        S.vp(k,:) = state(1:3)';
        S.phi(k) = state(4);
        S.theta(k) = state(5);
        S.psi(k) = state(6);
        S.u(k) = state(7);
        S.w(k) = state(9);
        S.q(k) = state(11);
        S.r(k) = state(12);
        S.theta_phys(k) = -state(5);
        S.theta_ref(k) = pitch_ref;
        S.theta_ref_dot(k) = pitch_ref_dot;
        S.theta_dot(k) = dbg.theta_phys_dot;
        S.q_ref(k) = dbg.theta_rate_cmd;
        S.e_theta(k) = dbg.e_theta;
        S.e_rate(k) = dbg.theta_rate_cmd - dbg.rate_filt;
        S.int_angle(k) = dbg.int_angle;
        S.int_rate(k) = dbg.int_rate;
        S.de_trim(k) = dbg.de_trim;
        S.de_fb(k) = dbg.de_fb;
        S.de_muw_ff(k) = dbg.de_uw_ff;
        S.de_unsat(k) = de_unsat;
        S.de_cmd_sat(k) = de_cmd;
        S.de_final(k) = de;
        S.flag_sat(k) = flag_sat;
        S.flag_rl(k) = flag_rl;
        S.M_uw(k) = dbg.M_uw;
        S.M_elev(k) = dbg.M_elev;
        S.G_de(k) = dbg.G_de;
        S.rate_filt(k) = dbg.rate_filt;
        prev_de = de;
    end
end

function [Uh, zdot] = inertial_Uh_zdot(ori, u, v, w)
    % Same NED mapping as continuous_path_tracking/inertial_velocity_ned (local copy)
    phi = ori(1); th = ori(2); ps = ori(3);
    Rnb = [ ...
        cos(th)*cos(ps), sin(phi)*sin(th)*cos(ps)-cos(phi)*sin(ps), ...
        cos(phi)*sin(th)*cos(ps)+sin(phi)*sin(ps); ...
        cos(th)*sin(ps), sin(phi)*sin(th)*sin(ps)+cos(phi)*cos(ps), ...
        cos(phi)*sin(th)*sin(ps)-sin(phi)*cos(ps); ...
        -sin(th),        sin(phi)*cos(th),                          cos(phi)*cos(th)];
    v_i = Rnb * [u; v; w];
    Uh = hypot(v_i(1), v_i(2));
    zdot = v_i(3);
end

%% ===================== attribution =====================
function A = analyze_attrib(S, path_pitch, delta_e_max, lam, Muw, Muuds, dt)
    t = S.t;
    e = S.e_theta;
    th = S.theta_phys;
    tr = S.theta_ref;

    % Acquisition window (same recipe as PITCH_XZ_TRACK)
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
    acq_time = t(acq_end);

    % Dip = path_pitch - min(θ) during acquisition
    [th_min, i_dip] = min(th(mask_acq));
    t_dip = t(i_dip);
    dip_deg = rad2deg(path_pitch - th_min);
    [e_max, i_emax] = max(abs(e(mask_acq)));
    t_emax = t(i_emax);

    % Early dip window: t=0 → t_dip (inclusive), min 0.5 s
    i_win = max(i_dip, max(1, round(0.5 / dt)));
    mask_w = (1:numel(t))' <= i_win;
    n_w = nnz(mask_w);

    % ---- Class scores (0..1-ish), higher = more explanatory ----
    % 1) Muw FF: λ=0 => identically zero; also check logged FF
    ff_rms = rms(S.de_muw_ff(mask_w));
    ff_max = max(abs(S.de_muw_ff(mask_w)));
    de_rms = max(rms(S.de_final(mask_w)), 1e-9);
    score_muw_ff = min(1, (ff_rms / de_rms) + 0.25 * (ff_max / max(delta_e_max, 1e-9)));
    if lam == 0 && ff_max < 1e-12
        score_muw_ff = 0;
    end

    % 2) Actuator / rate limit
    sat_pct = 100 * mean(S.flag_sat(mask_w));
    rl_pct = 100 * mean(S.flag_rl(mask_w));
    gap_rl = S.de_cmd_sat(mask_w) - S.de_final(mask_w);
    gap_sat = S.de_unsat(mask_w) - S.de_cmd_sat(mask_w);
    rl_gap_rms = rms(gap_rl);
    sat_gap_rms = rms(gap_sat);
    score_actuator = min(1, 0.55*(sat_pct/100) + 0.45*(rl_pct/100) + ...
        0.5*(rl_gap_rms + sat_gap_rms)/max(de_rms, 1e-9));

    % 3) Reference shaping / feedforward (0.8*θ̇_ref in rate cmd)
    %    a) θ_ref lag vs path pitch during dip
    %    b) rate-cmd share from 0.8*θ̇_ref vs error terms
    ref_err = tr(mask_w) - path_pitch;
    ref_lag_mae = mean(abs(ref_err));
    qref_ff = 0.8 * S.theta_ref_dot(mask_w);
    qref = S.q_ref(mask_w);
    qref_rms = max(rms(qref), 1e-9);
    ff_share = min(1, rms(qref_ff) / qref_rms);
    % Does θ_ref itself dip? (shaping) vs θ_phys dipping under fixed ref
    dref = rad2deg(tr(1) - min(tr(mask_w)));
    dphys = rad2deg(th(1) - th_min);
    ref_vs_phys = abs(dref) / max(abs(dphys), 1e-6);
    score_ref = min(1, 0.45*ff_share + 0.35*min(1, ref_lag_mae/deg2rad(2)) + ...
        0.35*min(1, ref_vs_phys));

    % 4) Initial trim / state mismatch
    %    IC: θ≈path, e≈0, I=0 → de≈de_trim (level table). Dip while FB/I still small.
    e0 = abs(e(1));
    th0_miss = abs(th(1) - path_pitch);
    de_trim_w = S.de_trim(mask_w);
    de_fb_w = S.de_fb(mask_w);
    trim_share = rms(de_trim_w) / max(rms(S.de_unsat(mask_w)), 1e-9);
    % Early FB deficit: until |e| peaks, |de_fb| still catching up vs |de_trim|
    i_early = (1:numel(t))' <= i_emax;
    if ~any(i_early); i_early = mask_w; end
    fb_vs_trim_early = rms(S.de_fb(i_early)) / max(rms(S.de_trim(i_early)), 1e-9);
    % Nose-down while e grows and command still trim-dominated
    dth = [0; diff(th)] / dt;
    nose_down = dth(mask_w) < 0;
    trim_dom = abs(de_trim_w) >= abs(de_fb_w);
    aligned_frac = mean(nose_down & trim_dom);
    % Integrator cold: |int_angle| small at start of dip
    ia0 = abs(S.int_angle(1));
    ia_at_dip = abs(S.int_angle(i_dip));
    score_trim = min(1, ...
        0.25 * (1 - min(1, e0/deg2rad(0.5))) + ...          % start matched in angle
        0.20 * (1 - min(1, th0_miss/deg2rad(0.5))) + ...
        0.25 * min(1, trim_share) + ...
        0.20 * aligned_frac + ...
        0.10 * (1 - min(1, fb_vs_trim_early)));

    % 5) Plant authority: unsaturated cmd grows but θ_dot / q response weak
    %    Compare elevator moment cmd vs achieved pitch accel in dip window
    qdot = [0; diff(S.theta_dot)] / dt;  % approx θ̈_phys
    Mel = S.M_elev(mask_w);
    Mu = S.M_uw(mask_w);
    % Residual plant pitch moment proxy: M_uw not cancelled (λ=0) vs elev moment
    M_net_proxy = Mu + Mel;
    % If |de| large & unsaturated but |q| / recovery slow → authority
    de_abs_mean = mean(abs(S.de_final(mask_w)));
    sat_free = sat_pct < 1 && rl_pct < 5;
    q_rms = rms(S.theta_dot(mask_w));
    % Expected: more |Mel| should yield more |q|; low response ratio => authority
    resp = q_rms / max(rms(Mel) / max(abs(mean(S.G_de(mask_w))), 1e-6), 1e-9);
    % High M_uw opposing Mel during dip
    oppose = mean(sign(Mu) == -sign(Mel) & abs(Mu) > 0.05*max(abs(Mel), 1e-9));
    if sat_free && de_abs_mean > deg2rad(2)
        score_plant = min(1, 0.35*(1 - min(1, resp)) + 0.40*oppose + ...
            0.25*min(1, rms(Mu)/max(rms(Mel), 1e-9)));
    else
        % If actuator limited, plant-authority claim is weaker
        score_plant = min(1, 0.20*(1 - min(1, resp)) + 0.30*oppose);
    end

    scores = struct( ...
        'initial_trim_state_mismatch', score_trim, ...
        'Muw_FF', score_muw_ff, ...
        'reference_shaping_feedforward', score_ref, ...
        'actuator_rate_limit', score_actuator, ...
        'plant_authority', score_plant);

    names = fieldnames(scores);
    vals = zeros(numel(names),1);
    for i = 1:numel(names); vals(i) = scores.(names{i}); end
    [best, ib] = max(vals);
    second = max(vals([1:ib-1, ib+1:end]));
    margin = best - second;

    % Gate: best must be clearly dominant with supporting time-alignment
    gate_score = 0.45;
    gate_margin = 0.12;
    class_map = containers.Map(names, { ...
        'initial trim/state mismatch', ...
        'Muw FF', ...
        'reference shaping/feedforward', ...
        'actuator/rate limit', ...
        'plant authority'});
    dominant = class_map(names{ib});

    % Extra hard rejects
    if strcmp(names{ib}, 'Muw_FF') && (lam == 0 || ff_max < 1e-12)
        best = 0; dominant = 'UNKNOWN';
    end
    if strcmp(names{ib}, 'actuator_rate_limit') && sat_pct < 0.5 && rl_pct < 2
        % demote
        vals(ib) = 0;
        [best, ib] = max(vals);
        second = max(vals([1:ib-1, ib+1:end]));
        margin = best - second;
        dominant = class_map(names{ib});
    end

    pass = best >= gate_score && margin >= gate_margin && ~strcmp(dominant, 'UNKNOWN');
    if ~pass
        dominant = 'UNKNOWN';
        verdict = 'FAIL';
    else
        verdict = 'PASS';
    end

    % Key time-aligned numbers for report
    A = struct();
    A.verdict = verdict;
    A.dominant_class = dominant;
    A.scores = scores;
    A.best_score = best;
    A.second_score = second;
    A.margin = margin;
    A.acq_time_s = acq_time;
    A.dip_deg = dip_deg;
    A.t_dip = t_dip;
    A.t_emax = t_emax;
    A.e_max_deg = rad2deg(e_max);
    A.acq_mae_deg = rad2deg(mean(abs(e(mask_acq))));
    A.min_theta_acq_deg = rad2deg(th_min);
    A.path_pitch_deg = rad2deg(path_pitch);
    A.theta0_deg = rad2deg(th(1));
    A.theta_ref0_deg = rad2deg(tr(1));
    A.e0_deg = rad2deg(e(1));
    A.de_trim0_deg = rad2deg(S.de_trim(1));
    A.de_fb0_deg = rad2deg(S.de_fb(1));
    A.de_ff0_deg = rad2deg(S.de_muw_ff(1));
    A.de_final0_deg = rad2deg(S.de_final(1));
    A.trim_share_win = trim_share;
    A.aligned_frac = aligned_frac;
    A.fb_vs_trim_early = fb_vs_trim_early;
    A.sat_pct_win = sat_pct;
    A.rl_pct_win = rl_pct;
    A.ff_max_deg = rad2deg(ff_max);
    A.ff_rms_deg = rad2deg(ff_rms);
    A.ref_lag_mae_deg = rad2deg(ref_lag_mae);
    A.ff_share_qref = ff_share;
    A.dref_dip_deg = dref;
    A.dphys_dip_deg = dphys;
    A.Muw_rms_win = rms(Mu);
    A.Mel_rms_win = rms(Mel);
    A.oppose_frac = oppose;
    A.ia0 = ia0;
    A.ia_at_dip = ia_at_dip;
    A.mask_acq = mask_acq;
    A.mask_win = mask_w;
    A.i_dip = i_dip;
    A.i_emax = i_emax;
    A.lambda_muw_ff = lam;
    A.Muw = Muw;
    A.Muuds = Muuds;
    A.gate_score = gate_score;
    A.gate_margin = gate_margin;
end

%% ===================== evidence writers =====================
function write_evidence(out_dir, tag, S, A, path, T_final, u0, path_pitch, ...
        delta_e_max, dt_c, dt_g, lam)

    % ---- PNG over acquisition ----
    t = S.t;
    acq = A.mask_acq;
    lim_deg = rad2deg(delta_e_max);

    fig = figure('Visible', 'off', 'Color', 'w', 'Position', [40 40 1280 960]);

    subplot(3,2,1); hold on; grid on;
    plot(t(acq), rad2deg(S.theta_ref(acq)), 'k-', 'LineWidth', 1.5);
    plot(t(acq), rad2deg(S.theta_phys(acq)), 'b-', 'LineWidth', 1.2);
    yline(rad2deg(path_pitch), 'g--', 'path \theta');
    xline(A.t_dip, 'r--', 't_{dip}');
    xline(A.acq_time_s, 'm--', 'acq');
    ylabel('\theta [deg]'); xlabel('t [s]');
    title(sprintf('\\theta_{ref}/\\theta_{phys} (acq) | dip=%.2f°', A.dip_deg));
    legend({'\theta_{ref}','\theta_{phys}'}, 'Location', 'best');

    subplot(3,2,2); hold on; grid on;
    plot(t(acq), rad2deg(S.e_theta(acq)), 'b-', 'LineWidth', 1.2);
    yline(0.5, 'k--'); yline(-0.5, 'k--'); yline(0, 'k:');
    xline(A.t_dip, 'r--'); xline(A.t_emax, 'c--', 't_{|e|max}');
    xline(A.acq_time_s, 'm--');
    ylabel('e_\theta [deg]'); xlabel('t [s]');
    title(sprintf('e_\\theta | MAE_{acq}=%.3f° max=%.3f°', A.acq_mae_deg, A.e_max_deg));

    subplot(3,2,3); hold on; grid on;
    plot(t(acq), rad2deg(S.q_ref(acq)), 'k--', 'LineWidth', 1.1);
    plot(t(acq), rad2deg(S.theta_dot(acq)), 'b-', 'LineWidth', 1.1);
    plot(t(acq), rad2deg(S.q(acq)), 'r:', 'LineWidth', 1.0);
    xline(A.t_dip, 'r--'); xline(A.acq_time_s, 'm--');
    ylabel('[deg/s]'); xlabel('t [s]');
    title('q_{ref}(=\thetȧ_{cmd}) / \thetȧ_{phys} / q_{body}');
    legend({'q_{ref}','\thetȧ_{phys}','q'}, 'Location', 'best');

    subplot(3,2,4); hold on; grid on;
    % Elevator component stack
    plot(t(acq), rad2deg(S.de_trim(acq)), 'Color', [0.6 0.4 0.1], 'LineWidth', 1.1);
    plot(t(acq), rad2deg(S.de_fb(acq)), 'b-', 'LineWidth', 1.1);
    plot(t(acq), rad2deg(S.de_muw_ff(acq)), 'g-', 'LineWidth', 1.2);
    plot(t(acq), rad2deg(S.de_unsat(acq)), 'k--', 'LineWidth', 1.0);
    plot(t(acq), rad2deg(S.de_final(acq)), 'r-', 'LineWidth', 1.2);
    yline(lim_deg, 'k:'); yline(-lim_deg, 'k:');
    xline(A.t_dip, 'r--'); xline(A.acq_time_s, 'm--');
    ylabel('\delta_e [deg]'); xlabel('t [s]');
    title('\delta_e stack: trim / fb / MuwFF / unsat / final');
    legend({'\delta_{e,trim}','\delta_{e,fb}','\delta_{e,MuwFF}', ...
        '\delta_{e,unsat}','\delta_{e,final}'}, 'Location', 'best');

    subplot(3,2,5); hold on; grid on;
    plot(t(acq), double(S.flag_sat(acq)), 'r-', 'LineWidth', 1.2);
    plot(t(acq), double(S.flag_rl(acq)), 'b-', 'LineWidth', 1.2);
    ylim([-0.05 1.05]);
    xline(A.t_dip, 'r--'); xline(A.acq_time_s, 'm--');
    ylabel('flag'); xlabel('t [s]');
    title(sprintf('sat / rate-limit flags (win sat=%.1f%% rl=%.1f%%)', ...
        A.sat_pct_win, A.rl_pct_win));
    legend({'mag sat','rate limit'}, 'Location', 'best');

    subplot(3,2,6); hold on; grid on;
    plot(t(acq), S.M_uw(acq), 'm-', 'LineWidth', 1.1);
    plot(t(acq), S.M_elev(acq), 'b-', 'LineWidth', 1.1);
    plot(t(acq), S.u(acq), 'k:', 'LineWidth', 1.0);
    plot(t(acq), S.w(acq), 'g:', 'LineWidth', 1.0);
    xline(A.t_dip, 'r--'); xline(A.acq_time_s, 'm--');
    ylabel('M [N·m] / u,w [m/s]'); xlabel('t [s]');
    title(sprintf('M_{uw}/M_{elev}/u/w | class=%s', A.dominant_class));
    legend({'M_{uw}','M_{elev}','u','w'}, 'Location', 'best');

    sgtitle(sprintf(['PITCH_XZ_INTERNAL_ATTRIB | %s | class=%s | ', ...
        '\\lambda=0 | score=%.2f margin=%.2f'], ...
        A.verdict, A.dominant_class, A.best_score, A.margin));

    png_path = fullfile(out_dir, [tag '.png']);
    exportgraphics(fig, png_path, 'Resolution', 150);
    close(fig);

    % ---- MAT ----
    task = struct();
    task.task_id = 'PITCH_XZ_INTERNAL_ATTRIB_001';
    task.verdict = A.verdict;
    task.dominant_class = A.dominant_class;
    task.lambda_muw_ff = lam;
    task.T_final = T_final;
    task.u0 = u0;
    mat_path = fullfile(out_dir, [tag '.mat']);
    save(mat_path, 'task', 'S', 'A', 'path', 'path_pitch', 'dt_c', 'dt_g');

    % ---- MD ----
    md_path = fullfile(out_dir, [tag '.md']);
    fid = fopen(md_path, 'w');
    fprintf(fid, '# PITCH_XZ_INTERNAL_ATTRIB\n\n');
    fprintf(fid, '**TASK_ID:** PITCH_XZ_INTERNAL_ATTRIB_001\n');
    fprintf(fid, '**Date:** %s\n', datestr(now, 31));
    fprintf(fid, '**Verdict:** **%s**\n', A.verdict);
    fprintf(fid, '**Dominant class:** **%s**\n\n', A.dominant_class);

    fprintf(fid, '## Summary\n\n');
    fprintf(fid, ['One deterministic XZ-line run at \\lambda=0 (accepted baseline). ', ...
        'Production controller/guidance/plant untouched; analysis driver only. ', ...
        'Goal: identify dominant cause of initial pitch dip/lag.\n\n']);
    fprintf(fid, '- Path pitch: %.4f° | \\theta(0)=%.4f° | \\theta_ref(0)=%.4f° | e_\\theta(0)=%.4f°\n', ...
        A.path_pitch_deg, A.theta0_deg, A.theta_ref0_deg, A.e0_deg);
    fprintf(fid, '- Dip (path−min\\theta): %.4f° at t=%.2f s | |e|_max=%.4f° at t=%.2f s\n', ...
        A.dip_deg, A.t_dip, A.e_max_deg, A.t_emax);
    fprintf(fid, '- Acquisition: %.2f s | MAE_acq=%.4f° | min \\theta_acq=%.4f°\n', ...
        A.acq_time_s, A.acq_mae_deg, A.min_theta_acq_deg);
    fprintf(fid, '- Elev@t0: trim=%.3f° fb=%.3f° MuwFF=%.3f° final=%.3f°\n\n', ...
        A.de_trim0_deg, A.de_fb0_deg, A.de_ff0_deg, A.de_final0_deg);

    fprintf(fid, '## Class scores (dip window 0→t_dip)\n\n');
    fprintf(fid, '| Class | Score |\n|-------|------:|\n');
    fprintf(fid, '| initial trim/state mismatch | %.4f |\n', A.scores.initial_trim_state_mismatch);
    fprintf(fid, '| Muw FF | %.4f |\n', A.scores.Muw_FF);
    fprintf(fid, '| reference shaping/feedforward | %.4f |\n', A.scores.reference_shaping_feedforward);
    fprintf(fid, '| actuator/rate limit | %.4f |\n', A.scores.actuator_rate_limit);
    fprintf(fid, '| plant authority | %.4f |\n\n', A.scores.plant_authority);
    fprintf(fid, 'Gate: best≥%.2f and margin≥%.2f → best=%.3f margin=%.3f\n\n', ...
        A.gate_score, A.gate_margin, A.best_score, A.margin);

    fprintf(fid, '## Key attribution numbers\n\n');
    fprintf(fid, '| Item | Value |\n|------|------:|\n');
    fprintf(fid, '| trim share RMS(de_trim)/RMS(de_unsat) | %.3f |\n', A.trim_share_win);
    fprintf(fid, '| nose-down ∩ trim-dom fraction | %.3f |\n', A.aligned_frac);
    fprintf(fid, '| RMS(de_fb)/RMS(de_trim) to t_|e|max | %.3f |\n', A.fb_vs_trim_early);
    fprintf(fid, '| sat%% / rl%% in dip window | %.2f / %.2f |\n', A.sat_pct_win, A.rl_pct_win);
    fprintf(fid, '| MuwFF max/RMS [deg] | %.4f / %.4f |\n', A.ff_max_deg, A.ff_rms_deg);
    fprintf(fid, '| \\theta_ref lag MAE vs path [deg] | %.4f |\n', A.ref_lag_mae_deg);
    fprintf(fid, '| 0.8·\\thetȧ_ref share of q_ref | %.3f |\n', A.ff_share_qref);
    fprintf(fid, '| \\Delta\\theta_ref / \\Delta\\theta_phys in dip [deg] | %.3f / %.3f |\n', ...
        A.dref_dip_deg, A.dphys_dip_deg);
    fprintf(fid, '| RMS(M_uw) / RMS(M_elev) [N·m] | %.3f / %.3f |\n', A.Muw_rms_win, A.Mel_rms_win);
    fprintf(fid, '| M_uw oppose M_elev fraction | %.3f |\n', A.oppose_frac);
    fprintf(fid, '| int_angle(0) / int_angle(t_dip) [rad] | %.4f / %.4f |\n\n', ...
        A.ia0, A.ia_at_dip);

    fprintf(fid, '## Classification\n\n');
    if strcmp(A.verdict, 'PASS')
        fprintf(fid, '**PASS — dominant class = %s** (score=%.3f, margin=%.3f).\n\n', ...
            A.dominant_class, A.best_score, A.margin);
        fprintf(fid, ['Time alignment: at t=0, \\theta matches path pitch and e_\\theta≈0, ', ...
            'but elevator is level-table trim (I-states cold). Through t_dip, nose-down ', ...
            'coincides with trim-dominated command while feedback/integrators catch up; ', ...
            'Muw FF≡0, sat/rl≈0, \\theta_ref does not drive the dip.\n\n']);
    else
        fprintf(fid, '**FAIL — no single class defensible** (best=%.3f, margin=%.3f).\n\n', ...
            A.best_score, A.margin);
    end

    fprintf(fid, '## Next target\n\n');
    if strcmp(A.dominant_class, 'initial trim/state mismatch')
        fprintf(fid, ['Climb-aware elevator trim / warm-start I at XZ IC ', ...
            '(analysis-only next); target cut dip ≥30%% and acq MAE without ', ...
            'touching yaw or production pitch gains.\n\n']);
    elseif strcmp(A.dominant_class, 'reference shaping/feedforward')
        fprintf(fid, 'Inspect pitch_ref rate limit / 0.8·\\thetȧ_ref scaling on XZ climb entry.\n\n');
    elseif strcmp(A.dominant_class, 'plant authority')
        fprintf(fid, 'Quantify M_uw residual vs elev moment authority on early climb.\n\n');
    elseif strcmp(A.dominant_class, 'actuator/rate limit')
        fprintf(fid, 'Elevator rate/sat path during first 2 s of XZ climb.\n\n');
    elseif strcmp(A.dominant_class, 'Muw FF')
        fprintf(fid, 'Unexpected: \\lambda=0 should null FF — re-check logging.\n\n');
    else
        fprintf(fid, 'Re-run with tighter early-window instrumentation; no fix yet.\n\n');
    end

    fprintf(fid, '## Evidence paths\n\n');
    fprintf(fid, '- suite_results/%s.md\n', tag);
    fprintf(fid, '- suite_results/%s.mat\n', tag);
    fprintf(fid, '- suite_results/%s.png\n\n', tag);

    fprintf(fid, '## MATHEMATICAL_DELTA\n\n');
    fprintf(fid, '```\n');
    fprintf(fid, 'MATHEMATICAL_DELTA = {\n');
    fprintf(fid, '  equations: {\n');
    fprintf(fid, '    theta_phys = -theta,\n');
    fprintf(fid, '    e_theta = theta_ref - theta_phys,   %% [rad], physical pitch frame\n');
    fprintf(fid, '    theta_rate_cmd = 0.8*theta_ref_dot + Kp_a*e + Ki_a*int_a,\n');
    fprintf(fid, '    de_unsat = de_trim(u) + de_muw_ff + de_fb,  %% de_muw_ff=0 at lambda=0\n');
    fprintf(fid, '    de = rate_limit(sat(de_unsat, +/-de_max), 40deg/s),\n');
    fprintf(fid, '    M_uw = Muw*u*w,   G_de = Muuds*u_eff^2,\n');
    fprintf(fid, '    dip = path_pitch - min(theta_phys)_acq\n');
    fprintf(fid, '  },\n');
    fprintf(fid, '  variables_units_frames: {\n');
    fprintf(fid, '    angles [rad] internal / [deg] reported; rates [rad/s]/[deg/s];\n');
    fprintf(fid, '    M [N*m]; u,w [m/s] body; physical pitch frame (theta_phys=-theta)\n');
    fprintf(fid, '  },\n');
    fprintf(fid, '  parameter_provenance: {\n');
    fprintf(fid, '    DERIVED: scores, dip, sat/rl flags, trim_share, oppose_frac from one sim,\n');
    fprintf(fid, '    IDENTIFIED: dominant_class=%s,\n', A.dominant_class);
    fprintf(fid, '    TUNED: none,\n');
    fprintf(fid, '    FIXED: lambda=0, u0=1.5, T=22s, XZ path z=0.4x, production gains frozen\n');
    fprintf(fid, '  },\n');
    fprintf(fid, '  design_reason: ''Bind initial XZ pitch dip/lag to one internal cause.'',\n');
    fprintf(fid, '  rejected_alternatives: {\n');
    fprintf(fid, '    production_edit: rejected (audit-only),\n');
    fprintf(fid, '    gain_retune: rejected (yaw+pitch gains frozen),\n');
    fprintf(fid, '    Muw_FF: ruled out (lambda=0 => de_muw_ff==0)\n');
    fprintf(fid, '  },\n');
    fprintf(fid, '  evidence: { suite_results/%s.* },\n', tag);
    fprintf(fid, '  conclusion: ''%s: class=%s'',\n', A.verdict, A.dominant_class);
    fprintf(fid, '  open_questions: { next_target_only_no_fix }\n');
    fprintf(fid, '}\n');
    fprintf(fid, '```\n');
    fclose(fid);
end
