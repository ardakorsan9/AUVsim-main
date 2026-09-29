function answers = diag_pitch_chatter()
% DIAG_PITCH_CHATTER  Evidence-based answers for pitch chatter / circle yaw.
% Self-contained: instrumented guidance+controller (parameterized dt).
% Does NOT permanently alter production controller_law / guidance_law.
%
% Writes: suite_results/DIAG_ANSWERS.md and suite_results/diag_*.png

    project_dir = fileparts(fileparts(fileparts(mfilename('fullpath')))); % repo root
    addpath(genpath(fullfile(project_dir, 'matlab')));
    out_dir = fullfile(project_dir, 'suite_results');
    if ~exist(out_dir, 'dir'); mkdir(out_dir); end

    clear_diag_persistents();

    init_parameters();
    global elevator_sign trim_speed_table trim_elevator_table
    global Ki_angle Ki_rate delta_e_max
    global Kp_angle Kp_rate  %#ok<NUSED>

    fprintf('\n========== DIAG PITCH CHATTER ==========\n');
    fprintf('Project: %s\n', project_dir);

    % Quick cal (or reuse globals if already populated from suite)
    if isempty(elevator_sign) || isempty(trim_speed_table)
        fprintf('--- Calibration (elevator sign + trim) ---\n');
        sign_rep = test_elevator_sign();
        elevator_sign = sign_rep.delta_e_sign;
        build_pitch_trim_table();
    else
        fprintf('--- Reusing elevator_sign=%+d and trim table ---\n', elevator_sign);
        fprintf('  trim u=[%s] de_deg=[%s]\n', ...
            num2str(trim_speed_table,'%.1f '), ...
            num2str(rad2deg(trim_elevator_table),'%+.2f '));
    end

    % Save production Ki
    Ki_angle0 = Ki_angle;
    Ki_rate0  = Ki_rate;

    dt0 = 0.075;
    answers = struct();

    %% ===== Baseline X-line =====
    fprintf('\n--- [1] Baseline X-line dt=%.3f ---\n', dt0);
    clear_diag_persistents();
    Ki_angle = Ki_angle0; Ki_rate = Ki_rate0;
    sc_x = make_x_line();
    log_base = run_diag_sim(sc_x.path, sc_x.state0, dt0, sc_x.T_final);
    m_base = compute_metrics(log_base, dt0);
    answers.baseline_x = m_base;
    plot_x_diag(log_base, m_base, fullfile(out_dir, 'diag_x_baseline.png'), 'X-line baseline');

    %% ===== Q1: pitch_ref_raw vibrate? =====
    answers.q1 = struct( ...
        'pitch_ref_raw_std_deg', m_base.pitch_ref_raw_std_deg, ...
        'pitch_ref_raw_pp_deg', m_base.pitch_ref_raw_pp_deg, ...
        'pitch_ref_std_deg', m_base.pitch_ref_std_deg, ...
        'pitch_ref_pp_deg', m_base.pitch_ref_pp_deg, ...
        'pitch_ref_raw_hf_rms_deg', m_base.pitch_ref_raw_hf_rms_deg, ...
        'pitch_ref_hf_rms_deg', m_base.pitch_ref_hf_rms_deg);

    %% ===== Q2: elevator saturation / slew =====
    answers.q2 = struct( ...
        'pct_mag_sat', m_base.pct_de_mag_sat, ...
        'pct_slew_sat', m_base.pct_de_slew_sat, ...
        'delta_e_max_deg', rad2deg(delta_e_max), ...
        'max_abs_de_deg', m_base.max_abs_de_deg, ...
        'max_abs_de_cmd_deg', m_base.max_abs_de_cmd_deg, ...
        'max_abs_de_unsat_deg', m_base.max_abs_de_unsat_deg);

    %% ===== Q4: filter delay (from baseline) =====
    answers.q4 = struct( ...
        'rms_rate_minus_filt_dps', m_base.rms_rate_err_dps, ...
        'peak_rate_minus_filt_dps', m_base.peak_rate_err_dps, ...
        'corr_rate_filt', m_base.corr_rate_filt, ...
        'lag_est_s', m_base.rate_lag_est_s);

    %% ===== Q3: Ki=0 ablations =====
    fprintf('\n--- [3a] Ki_angle=0, Ki_rate keep ---\n');
    clear_diag_persistents();
    Ki_angle = 0; Ki_rate = Ki_rate0;
    log_a = run_diag_sim(sc_x.path, sc_x.state0, dt0, sc_x.T_final);
    m_a = compute_metrics(log_a, dt0);

    fprintf('\n--- [3b] Ki_rate=0, Ki_angle keep ---\n');
    clear_diag_persistents();
    Ki_angle = Ki_angle0; Ki_rate = 0;
    log_r = run_diag_sim(sc_x.path, sc_x.state0, dt0, sc_x.T_final);
    m_r = compute_metrics(log_r, dt0);

    fprintf('\n--- [3c] Both Ki=0 ---\n');
    clear_diag_persistents();
    Ki_angle = 0; Ki_rate = 0;
    log_both = run_diag_sim(sc_x.path, sc_x.state0, dt0, sc_x.T_final);
    m_both = compute_metrics(log_both, dt0);

    answers.q3 = struct( ...
        'chatter_base', m_base.pitch_chatter_dps, ...
        'chatter_Ki_angle0', m_a.pitch_chatter_dps, ...
        'chatter_Ki_rate0', m_r.pitch_chatter_dps, ...
        'chatter_both0', m_both.pitch_chatter_dps, ...
        'theta_pp_base_deg', m_base.theta_pp_deg, ...
        'theta_pp_Ki_angle0_deg', m_a.theta_pp_deg, ...
        'theta_pp_Ki_rate0_deg', m_r.theta_pp_deg, ...
        'theta_pp_both0_deg', m_both.theta_pp_deg, ...
        'de_std_base_deg', m_base.de_std_deg, ...
        'de_std_Ki_angle0_deg', m_a.de_std_deg, ...
        'de_std_Ki_rate0_deg', m_r.de_std_deg, ...
        'de_std_both0_deg', m_both.de_std_deg);

    plot_ablation_compare(log_base, log_both, m_base, m_both, ...
        fullfile(out_dir, 'diag_x_Ki0.png'), 'X-line: baseline vs both Ki=0');

    %% ===== Q5: dt halved =====
    fprintf('\n--- [5] dt halved (0.0375) consistent in guid+ctrl+sim ---\n');
    clear_diag_persistents();
    Ki_angle = Ki_angle0; Ki_rate = Ki_rate0;
    dt_half = dt0 / 2;
    log_h = run_diag_sim(sc_x.path, sc_x.state0, dt_half, sc_x.T_final);
    m_h = compute_metrics(log_h, dt_half);
    answers.q5 = struct( ...
        'dt_base', dt0, ...
        'dt_half', dt_half, ...
        'chatter_base', m_base.pitch_chatter_dps, ...
        'chatter_half', m_h.pitch_chatter_dps, ...
        'theta_pp_base_deg', m_base.theta_pp_deg, ...
        'theta_pp_half_deg', m_h.theta_pp_deg, ...
        'de_std_base_deg', m_base.de_std_deg, ...
        'de_std_half_deg', m_h.de_std_deg, ...
        'pct_slew_base', m_base.pct_de_slew_sat, ...
        'pct_slew_half', m_h.pct_de_slew_sat);
    plot_ablation_compare(log_base, log_h, m_base, m_h, ...
        fullfile(out_dir, 'diag_x_dt_half.png'), 'X-line: dt=0.075 vs 0.0375');

    %% ===== Q6-Q7: Circle =====
    fprintf('\n--- [6/7] Circle scenario ---\n');
    clear_diag_persistents();
    Ki_angle = Ki_angle0; Ki_rate = Ki_rate0;
    sc_c = make_circle();
    log_c = run_diag_sim(sc_c.path, sc_c.state0, dt0, sc_c.T_final);
    m_c = compute_circle_metrics(log_c, 5.0); % R=5
    answers.q6 = m_c.q6;
    answers.q7 = m_c.q7;
    plot_circle_diag(log_c, m_c, fullfile(out_dir, 'diag_circle_yawrate.png'));

    %% ===== Q8: Moment components (X-line) =====
    fprintf('\n--- [8] Moment decomposition (X-line baseline) ---\n');
    mom = analyze_moments(log_base);
    answers.q8 = mom;
    plot_moments(log_base, mom, fullfile(out_dir, 'diag_moments.png'));

    % Restore Ki
    Ki_angle = Ki_angle0;
    Ki_rate = Ki_rate0;

    %% ===== Write DIAG_ANSWERS.md =====
    md_path = fullfile(out_dir, 'DIAG_ANSWERS.md');
    write_answers_md(md_path, answers);
    fprintf('\nWrote %s\n', md_path);
    fprintf('========== DIAG DONE ==========\n');
end

%% ===================== scenarios =====================
function sc = make_x_line()
    n = 400;
    x = linspace(0, 20, n)';
    path = [x, zeros(n,1), zeros(n,1)];
    sc.path = path;
    sc.T_final = 18;
    sc.state0 = initial_state_from_path(path, 1.5);
end

function sc = make_circle()
    n = 500;
    R = 5;
    th = linspace(0, 2*pi, n)';
    path = [R*cos(th), R*sin(th), zeros(n,1)];
    sc.path = path;
    sc.T_final = 35;
    sc.state0 = initial_state_from_path(path, 1.5);
end

function state = initial_state_from_path(path, u0)
    state = zeros(12, 1);
    state(1:3) = path(1, :)';
    d = path(2, :) - path(1, :);
    physical_pitch = atan2(d(3), norm(d(1:2)));
    state(5) = -physical_pitch;
    state(6) = atan2(d(2), d(1));
    state(7) = u0;
end

%% ===================== instrumented sim =====================
function log = run_diag_sim(path, state, dt, T_final)
    n_steps = round(T_final / dt);
    log = alloc_log(n_steps);
    progress_index = 1;
    for idx = 1:n_steps
        pos = state(1:3)';
        ori = state(4:6)';
        rates = state(10:12)';
        u = state(7); v = state(8); w = state(9);

        [yaw_ref, pitch_ref, u_ref, progress_index, r_ff, pitch_ref_dot, gdiag] = ...
            diag_guidance(pos, path, progress_index, u, v, dt);

        [delta_r, delta_e, thrust, cdiag] = diag_controller( ...
            yaw_ref, pitch_ref, u_ref, ori(3), ori(2), rates(3), rates(2), ...
            u, r_ff, pitch_ref_dot, ori(1), dt);

        controls = struct('delta_r', delta_r, 'delta_e', delta_e, 'thrust', thrust);
        try
            [~, g] = ode45(@(t, x) underwater777_vehicle_dynamics(t, x, controls), [0 dt], state);
            state = g(end, :)';
        catch ME
            fprintf(2, 'Sim failed at step %d: %s\n', idx, ME.message);
            log = trim_log(log, idx-1);
            return;
        end

        % Reconstruct pitch moment components at post-step state (controls held)
        mom = pitch_moments(state, delta_e);

        log.t(idx) = idx * dt;
        log.xyz(idx,:) = state(1:3);
        log.phi(idx) = state(4);
        log.theta(idx) = state(5);
        log.psi(idx) = state(6);
        log.u(idx) = state(7);
        log.v(idx) = state(8);
        log.w(idx) = state(9);
        log.p(idx) = state(10);
        log.q(idx) = state(11);
        log.r(idx) = state(12);
        log.yaw_ref(idx) = yaw_ref;
        log.pitch_ref(idx) = pitch_ref;
        log.pitch_ref_raw(idx) = gdiag.pitch_raw;
        log.pitch_geom(idx) = gdiag.pitch_geom;
        log.pitch_f(idx) = gdiag.pitch_f;
        log.u_ref(idx) = u_ref;
        log.r_ff(idx) = r_ff;
        log.kappa_f(idx) = gdiag.kappa_f;
        log.beta_guid(idx) = gdiag.beta;
        log.delta_r(idx) = delta_r;
        log.delta_e(idx) = delta_e;
        log.delta_e_cmd(idx) = cdiag.delta_e_cmd;
        log.delta_e_unsat(idx) = cdiag.delta_e_unsat;
        log.de_trim(idx) = cdiag.de_trim;
        log.theta_phys(idx) = cdiag.theta_phys;
        log.theta_phys_dot(idx) = cdiag.theta_phys_dot;
        log.rate_filt(idx) = cdiag.rate_filt;
        log.theta_rate_cmd(idx) = cdiag.theta_rate_cmd;
        log.slew_sat(idx) = cdiag.slew_sat;
        log.mag_sat(idx) = cdiag.mag_sat;
        log.thrust(idx) = thrust;
        log.M_total(idx) = mom.M_total;
        log.M_rest(idx) = mom.M_rest;
        log.M_ww(idx) = mom.M_ww;
        log.M_qq(idx) = mom.M_qq;
        log.M_uw(idx) = mom.M_uw;
        log.M_uq(idx) = mom.M_uq;
        log.M_elev(idx) = mom.M_elev;
        log.M_other(idx) = mom.M_other;

        if mod(idx, 80) == 0 || idx == n_steps
            fprintf('  step %d/%d t=%.1fs u=%.2f th_phys=%.2f deg de=%.2f deg\n', ...
                idx, n_steps, log.t(idx), u, rad2deg(cdiag.theta_phys), rad2deg(delta_e));
        end
    end
end

function log = alloc_log(n)
    z = zeros(n,1);
    log = struct( ...
        't', z, 'xyz', zeros(n,3), ...
        'phi', z, 'theta', z, 'psi', z, ...
        'u', z, 'v', z, 'w', z, 'p', z, 'q', z, 'r', z, ...
        'yaw_ref', z, 'pitch_ref', z, 'pitch_ref_raw', z, 'pitch_geom', z, 'pitch_f', z, ...
        'u_ref', z, 'r_ff', z, 'kappa_f', z, 'beta_guid', z, ...
        'delta_r', z, 'delta_e', z, 'delta_e_cmd', z, 'delta_e_unsat', z, 'de_trim', z, ...
        'theta_phys', z, 'theta_phys_dot', z, 'rate_filt', z, 'theta_rate_cmd', z, ...
        'slew_sat', z, 'mag_sat', z, 'thrust', z, ...
        'M_total', z, 'M_rest', z, 'M_ww', z, 'M_qq', z, 'M_uw', z, 'M_uq', z, ...
        'M_elev', z, 'M_other', z);
end

function log = trim_log(log, n)
    fn = fieldnames(log);
    for i = 1:numel(fn)
        v = log.(fn{i});
        if size(v,1) >= n
            log.(fn{i}) = v(1:n, :);
        end
    end
end

%% ===================== metrics =====================
function m = compute_metrics(log, dt)
    global delta_e_max
    % skip first 2s for settle metrics where noted
    t = log.t(:);
    i0 = find(t >= 2.0, 1, 'first');
    if isempty(i0); i0 = 1; end

    pr = log.pitch_ref_raw(i0:end);
    pf = log.pitch_ref(i0:end);
    th = log.theta_phys(i0:end);
    de = log.delta_e(i0:end);
    rate = log.theta_phys_dot(i0:end);
    rfilt = log.rate_filt(i0:end);

    m.pitch_ref_raw_std_deg = rad2deg(std(pr));
    m.pitch_ref_raw_pp_deg  = rad2deg(max(pr) - min(pr));
    m.pitch_ref_std_deg     = rad2deg(std(pf));
    m.pitch_ref_pp_deg      = rad2deg(max(pf) - min(pf));
    m.pitch_ref_raw_hf_rms_deg = rad2deg(hf_rms(pr, dt));
    m.pitch_ref_hf_rms_deg     = rad2deg(hf_rms(pf, dt));

    m.pct_de_mag_sat  = 100 * mean(abs(log.delta_e) >= 0.95 * delta_e_max);
    m.pct_de_slew_sat = 100 * mean(log.slew_sat > 0.5);
    m.max_abs_de_deg      = rad2deg(max(abs(log.delta_e)));
    m.max_abs_de_cmd_deg  = rad2deg(max(abs(log.delta_e_cmd)));
    m.max_abs_de_unsat_deg = rad2deg(max(abs(log.delta_e_unsat)));

    derr = rate - rfilt;
    m.rms_rate_err_dps  = rad2deg(rms(derr));
    m.peak_rate_err_dps = rad2deg(max(abs(derr)));
    if std(rate) > 1e-9 && std(rfilt) > 1e-9
        c = corrcoef(rate, rfilt);
        m.corr_rate_filt = c(1,2);
    else
        m.corr_rate_filt = NaN;
    end
    m.rate_lag_est_s = estimate_lag(rate, rfilt, dt);

    % Pitch chatter: std of high-pass d(theta_phys)/dt after detrend
    dth = [0; diff(th)] / dt;
    dth_hf = hf_rms(detrend(dth), dt); % already rms of hf component of rate
    % Better: std of high-freq band of theta (deg), and of dtheta/dt
    m.pitch_chatter_dps = rad2deg(std(hf_signal(detrend(dth), dt)));
    m.theta_pp_deg = rad2deg(max(th) - min(th));
    m.theta_hf_rms_deg = rad2deg(hf_rms(detrend(th), dt));
    m.de_std_deg = rad2deg(std(de));
    m.de_hf_rms_deg = rad2deg(hf_rms(detrend(de), dt));
end

function m = compute_circle_metrics(log, R)
    t = log.t(:);
    i0 = find(t >= 8.0, 1, 'first'); % after settle into turn
    if isempty(i0); i0 = 1; end
    sl = i0:numel(t);

    u = log.u(sl);
    r = log.r(sl);
    r_ff = log.r_ff(sl);
    u_over_R = u / R;  % expected yaw rate magnitude for R=5 circle
    % kappa sign: path is CCW from (R,0) with th 0..2pi -> kappa > 0 typically
    % Compare signed: r should track r_ff and u*kappa ≈ u/R * sign(kappa)
    kappa = log.kappa_f(sl);
    r_geom = u .* kappa; % without 1.15 boost

    % Use last 60% steady
    i_mid = i0 + floor(0.4 * (numel(t) - i0));
    ss = i_mid:numel(t);

    r_ss = log.r(ss);
    rff_ss = log.r_ff(ss);
    uR_ss = log.u(ss) / R;
    % Align sign of u/R with median r_ff
    sgn = sign(median(rff_ss));
    if sgn == 0; sgn = 1; end
    uR_signed = sgn * abs(uR_ss);

    lag_r_ff = mean(rff_ss - r_ss);
    lag_uR   = mean(uR_signed - r_ss);
    ratio_r_ff = mean(r_ss) / max(mean(rff_ss), 1e-9);
    ratio_uR   = mean(r_ss) / max(mean(uR_signed), 1e-9);
    rms_err_ff = rms(rff_ss - r_ss);
    rms_err_uR = rms(uR_signed - r_ss);

    m.q6 = struct( ...
        'mean_r_dps', rad2deg(mean(r_ss)), ...
        'mean_r_ff_dps', rad2deg(mean(rff_ss)), ...
        'mean_u_over_R_dps', rad2deg(mean(uR_signed)), ...
        'mean_r_geom_dps', rad2deg(mean(log.u(ss) .* log.kappa_f(ss))), ...
        'ratio_r_over_rff', ratio_r_ff, ...
        'ratio_r_over_uR', ratio_uR, ...
        'mean_lag_rff_dps', rad2deg(lag_r_ff), ...
        'mean_lag_uR_dps', rad2deg(lag_uR), ...
        'rms_err_rff_dps', rad2deg(rms_err_ff), ...
        'rms_err_uR_dps', rad2deg(rms_err_uR), ...
        'mean_u_ss', mean(log.u(ss)));

    beta = atan2(log.v, max(log.u, 0.35));
    m.q7 = struct( ...
        'phi_mean_deg', rad2deg(mean(log.phi(ss))), ...
        'phi_rms_deg', rad2deg(rms(log.phi(ss))), ...
        'phi_max_abs_deg', rad2deg(max(abs(log.phi(ss)))), ...
        'phi_pp_deg', rad2deg(max(log.phi(ss)) - min(log.phi(ss))), ...
        'beta_mean_deg', rad2deg(mean(beta(ss))), ...
        'beta_rms_deg', rad2deg(rms(beta(ss))), ...
        'beta_max_abs_deg', rad2deg(max(abs(beta(ss)))), ...
        'beta_pp_deg', rad2deg(max(beta(ss)) - min(beta(ss))));

    m.log_sl = sl;
    m.log_ss = ss;
end

function mom = analyze_moments(log)
    % Focus on steady-ish window where chatter visible (2..end)
    t = log.t(:);
    i0 = find(t >= 2.0, 1, 'first');
    if isempty(i0); i0 = 1; end
    sl = i0:numel(t);

    Me = log.M_elev(sl);
    components = { ...
        'M_rest', log.M_rest(sl); ...
        'M_ww',   log.M_ww(sl); ...
        'M_qq',   log.M_qq(sl); ...
        'M_uw',   log.M_uw(sl); ...
        'M_uq',   log.M_uq(sl); ...
        'M_other',log.M_other(sl)};

    % Opposition score: when elevator moment changes, does component go opposite?
    % corr(component, -M_elev) and fraction of samples where sign(comp) == -sign(M_elev)
    names = components(:,1);
    opp_frac = zeros(numel(names),1);
    corr_opp = zeros(numel(names),1);
    rms_c = zeros(numel(names),1);
    for k = 1:numel(names)
        c = components{k,2};
        rms_c(k) = rms(c);
        sMe = sign(Me); sMe(sMe==0) = 1;
        opp_frac(k) = mean(sign(c) == -sMe | abs(c) < 1e-6);
        if std(c) > 1e-9 && std(Me) > 1e-9
            R = corrcoef(c, -Me);
            corr_opp(k) = R(1,2);
        else
            corr_opp(k) = 0;
        end
    end

    % Periodic: look at spectral peak of each vs elevator
    [~, ipk] = max(corr_opp .* (rms_c / max(max(rms_c),1e-9)));

    mom = struct();
    mom.rms_M_elev = rms(Me);
    mom.rms_M_rest = rms(log.M_rest(sl));
    mom.rms_M_ww   = rms(log.M_ww(sl));
    mom.rms_M_qq   = rms(log.M_qq(sl));
    mom.rms_M_uw   = rms(log.M_uw(sl));
    mom.rms_M_uq   = rms(log.M_uq(sl));
    mom.rms_M_other= rms(log.M_other(sl));
    mom.top_opponent = names{ipk};
    mom.top_corr_opp = corr_opp(ipk);
    mom.top_opp_frac = opp_frac(ipk);
    mom.corr_rest_vs_neg_elev = corr_opp(strcmp(names,'M_rest'));
    mom.corr_uw_vs_neg_elev = corr_opp(strcmp(names,'M_uw'));
    mom.corr_qq_vs_neg_elev = corr_opp(strcmp(names,'M_qq'));
    mom.corr_ww_vs_neg_elev = corr_opp(strcmp(names,'M_ww'));
    mom.corr_uq_vs_neg_elev = corr_opp(strcmp(names,'M_uq'));
    mom.corr_other_vs_neg_elev = corr_opp(strcmp(names,'M_other'));
    mom.opp_frac_rest = opp_frac(strcmp(names,'M_rest'));
    mom.opp_frac_uw = opp_frac(strcmp(names,'M_uw'));
    mom.opp_frac_qq = opp_frac(strcmp(names,'M_qq'));

    % Mean signed product (negative => opposing)
    mom.mean_prod_rest = mean(log.M_rest(sl) .* Me);
    mom.mean_prod_uw   = mean(log.M_uw(sl) .* Me);
    mom.mean_prod_qq   = mean(log.M_qq(sl) .* Me);
    mom.mean_prod_ww   = mean(log.M_ww(sl) .* Me);
    mom.mean_prod_uq   = mean(log.M_uq(sl) .* Me);
    mom.mean_prod_other= mean(log.M_other(sl) .* Me);
end

function y = hf_signal(x, dt)
    % Simple high-pass via subtracting moving average (~0.8 s window)
    n = max(3, round(0.8 / dt));
    b = ones(n,1) / n;
    lf = filter(b, 1, x(:));
    % compensate filter delay roughly
    y = x(:) - lf;
    y(1:n) = 0;
end

function v = hf_rms(x, dt)
    y = hf_signal(x, dt);
    v = rms(y(round(0.8/dt)+1:end));
    if isempty(v); v = rms(y); end
end

function lag = estimate_lag(a, b, dt)
    % Cross-correlation lag of b relative to a (positive => b lags a)
    a = a(:) - mean(a); b = b(:) - mean(b);
    maxlag = min(40, floor(numel(a)/4));
    if maxlag < 2 || std(a) < 1e-12 || std(b) < 1e-12
        lag = NaN; return;
    end
    [c, lags] = xcorr(b, a, maxlag, 'coeff');
    [~, ix] = max(c);
    lag = lags(ix) * dt;
end

%% ===================== moment reconstruct =====================
function mom = pitch_moments(g, delta_e)
    global W B xg xb zg zb
    global Mww Mqq Mrp Muq Muw Mvp Muuds
    global Ixx Izz m

    phi = g(4); theta = g(5);
    u = g(7); v = g(8); w = g(9);
    p = g(10); q = g(11); r = g(12);

    M_rest = -(zg*W - zb*B)*sin(theta) - (xg*W - xb*B)*cos(theta)*cos(phi);
    M_ww   = Mww * w * abs(w);
    M_qq   = Mqq * q * abs(q);
    M_uw   = Muw * u * w;
    M_uq   = (Muq - m*xg) * u * q;
    M_elev = Muuds * u^2 * delta_e;
    M_rp   = (Mrp - (Ixx - Izz)) * r * p;
    M_vr   = (m*zg) * v * r;
    M_wq   = -(m*zg) * w * q;
    M_vp   = (Mvp + m*xg) * v * p;
    M_other = M_rp + M_vr + M_wq + M_vp;
    M_total = M_rest + M_ww + M_qq + M_uw + M_uq + M_elev + M_other;

    mom = struct('M_total', M_total, 'M_rest', M_rest, 'M_ww', M_ww, ...
        'M_qq', M_qq, 'M_uw', M_uw, 'M_uq', M_uq, 'M_elev', M_elev, ...
        'M_other', M_other);
end

%% ===================== diag guidance (dt-parameterized) =====================
function [yaw_ref, pitch_ref, u_ref, next_progress_index, r_ff, pitch_ref_dot, d] = ...
        diag_guidance(current_position, path, progress_index, u_body, v_body, dt_nom)

    global lookahead_distance desired_speed
    global pitch_ref_max pitch_ref_rate_max

    persistent s_prog yaw_cont pitch_f z_e_f z_e_i kappa_f chi_f yaw_out pitch_out initialized
    global DIAG_RESET_GUID
    if ~isempty(DIAG_RESET_GUID) && DIAG_RESET_GUID
        s_prog = []; yaw_cont = []; pitch_f = []; z_e_f = []; z_e_i = [];
        kappa_f = []; chi_f = []; yaw_out = []; pitch_out = []; initialized = false;
        DIAG_RESET_GUID = false;
    end
    if isempty(initialized); initialized = false; end
    if isempty(z_e_i); z_e_i = 0; end
    if isempty(pitch_ref_max); pitch_ref_max = deg2rad(25); end
    if isempty(pitch_ref_rate_max); pitch_ref_rate_max = deg2rad(5); end

    d = struct('pitch_raw', 0, 'pitch_geom', 0, 'pitch_f', 0, 'kappa_f', 0, 'beta', 0);

    n = size(path, 1);
    if n < 2
        yaw_ref = 0; pitch_ref = 0; u_ref = desired_speed;
        next_progress_index = 1; r_ff = 0; pitch_ref_dot = 0;
        return;
    end

    [s_nodes, s_total] = path_arclength(path);
    is_closed = norm(path(1,:) - path(end,:)) < 0.25;
    L = max(lookahead_distance, 1.0);

    if ~initialized
        [s_near, ~] = project_on_path(current_position, path, s_nodes, 0, s_total, is_closed);
        s_prog = s_near;
        yaw_cont = nan;
        pitch_f = nan;
        z_e_f = 0; z_e_i = 0; kappa_f = 0; chi_f = nan;
        initialized = true;
        s_prev = [];
    else
        s_prev = s_prog;
        s_lo = s_prog - 0.15;
        s_hi = s_prog + max(3.0, 2.5*L);
        if is_closed
            s_lo = mod(s_lo, s_total);
            s_hi = s_lo + max(3.0, 2.5*L);
        else
            s_lo = max(0, s_lo);
            s_hi = min(s_total, s_hi);
        end
        [s_near, ~] = project_on_path(current_position, path, s_nodes, s_lo, s_hi, is_closed);
        if is_closed
            ds = wrap_arc(s_near - s_prog, s_total);
            if ds >= -0.25
                s_prog = mod(s_prog + max(ds, -0.05), s_total);
            end
        else
            s_prog = max(s_prog, s_near - 0.05);
            s_prog = min(s_prog, s_total);
        end
    end

    near_end = (~is_closed) && (s_prog >= s_total - 0.3);
    [p_path, t_hat] = sample_path(path, s_nodes, s_prog, is_closed);
    s_look = s_prog + L;
    if is_closed; s_look = mod(s_look, s_total); else; s_look = min(s_look, s_total); end
    [~, t_look] = sample_path(path, s_nodes, s_look, is_closed);

    if ~isempty(s_prev) && ~is_closed
        z_below = p_path(3) - current_position(3);
        if z_below > 2.5
            ds_max = max(0.05, 0.55 * max(u_body, 0.3) * dt_nom);
            s_prog = min(s_prog, s_prev + ds_max);
            [p_path, t_hat] = sample_path(path, s_nodes, s_prog, is_closed);
            s_look = min(s_total, s_prog + L);
            [~, t_look] = sample_path(path, s_nodes, s_look, is_closed);
        end
    end

    kappa_raw = path_curvature_at(path, s_nodes, s_prog, is_closed);
    kappa_f = 0.96 * kappa_f + 0.04 * kappa_raw;
    R_abs = 1 / max(abs(kappa_f), 1e-4);

    cte = current_position - p_path;
    t_h = t_hat(1:2);
    if norm(t_h) < 1e-9; t_h = [1, 0]; else; t_h = t_h / norm(t_h); end
    n_h = [-t_h(2), t_h(1)];
    y_e = dot(cte(1:2), n_h);
    z_e_f = 0.93 * z_e_f + 0.07 * cte(3);

    u_ref = desired_speed * (R_abs / (R_abs + 2.5));
    u_ref = max(0.9, min(desired_speed, u_ref));
    if abs(z_e_f) > 3.0; u_ref = min(u_ref, 1.15); end
    if near_end; u_ref = 0.7 * desired_speed; end

    chi_path = atan2(t_look(2), t_look(1));
    if isnan(chi_f); chi_f = chi_path;
    else; chi_f = chi_f + 0.28 * wrapToPi(chi_path - chi_f); end
    chi_los = atan2(-y_e, L + 0.6);
    beta = atan2(v_body, max(u_body, 0.35));
    k_beta = 1.35;
    if near_end
        yaw_raw = atan2(t_hat(2), t_hat(1));
    else
        yaw_raw = wrapToPi(chi_f + 0.75 * chi_los - k_beta * beta);
    end
    if isnan(yaw_cont); yaw_cont = yaw_raw;
    else; yaw_cont = yaw_cont + wrapToPi(yaw_raw - yaw_cont); end

    pitch_path = atan2(t_look(3), max(norm(t_look(1:2)), 1e-6));
    pitch_now = atan2(t_hat(3), max(norm(t_hat(1:2)), 1e-6));
    if near_end; pitch_geom = pitch_now;
    else; pitch_geom = 0.65 * pitch_path + 0.35 * pitch_now; end
    z_e_i = z_e_i + z_e_f * dt_nom;
    z_e_i = max(min(z_e_i, 25), -25);
    pitch_corr = -0.050 * z_e_f - 0.006 * z_e_i;
    pitch_corr = max(min(pitch_corr, deg2rad(9)), deg2rad(-9));
    pitch_raw = pitch_geom + pitch_corr;
    pitch_raw = max(min(pitch_raw, pitch_ref_max), -pitch_ref_max);
    if isnan(pitch_f)
        pitch_f = pitch_raw;
        pitch_out = pitch_raw;
    else
        pitch_f = 0.90 * pitch_f + 0.10 * pitch_raw;
    end

    max_dyaw = deg2rad(40) * dt_nom;
    if isempty(yaw_out)
        yaw_out = yaw_cont;
        pitch_out = pitch_f;
    end
    dy = 0.35 * (yaw_cont - yaw_out);
    dy = max(min(dy, max_dyaw), -max_dyaw);
    yaw_out = yaw_out + dy;

    dp_des = pitch_f - pitch_out;
    dp_max = pitch_ref_rate_max * dt_nom;
    dp = max(min(dp_des, dp_max), -dp_max);
    pitch_out = pitch_out + dp;
    pitch_out = max(min(pitch_out, pitch_ref_max), -pitch_ref_max);

    yaw_ref = yaw_out;
    pitch_ref = pitch_out;
    pitch_ref_dot = dp / dt_nom;
    r_ff = 1.15 * u_ref * kappa_f;
    r_ff = max(min(r_ff, deg2rad(40)), deg2rad(-40));
    next_progress_index = max(1, min(n, 1 + sum(s_nodes <= s_prog)));
    if ~is_closed
        next_progress_index = max(next_progress_index, progress_index);
    end

    d.pitch_raw = pitch_raw;
    d.pitch_geom = pitch_geom;
    d.pitch_f = pitch_f;
    d.kappa_f = kappa_f;
    d.beta = beta;
end

%% ===================== diag controller (dt-parameterized) =====================
function [delta_r, delta_e, thrust, d] = diag_controller(yaw_ref, pitch_ref, u_ref, psi, theta, r, q, u, r_ff, pitch_ref_dot, phi, dt)
    global Kp_psi Kd_psi Kp_x
    global Kp_angle Ki_angle Kp_rate Ki_rate Kaw_pitch Kd_rate Kd_damp
    global delta_r_max delta_e_max thrust_max thrust_min
    global thrust_trim elevator_sign

    persistent prev_delta_e prev_delta_r int_angle int_rate rate_filt prev_e_rate
    global DIAG_RESET_CTRL
    if ~isempty(DIAG_RESET_CTRL) && DIAG_RESET_CTRL
        prev_delta_e = []; prev_delta_r = []; int_angle = []; int_rate = [];
        rate_filt = []; prev_e_rate = [];
        DIAG_RESET_CTRL = false;
    end
    if isempty(prev_delta_e); prev_delta_e = 0; end
    if isempty(prev_delta_r); prev_delta_r = 0; end
    if isempty(int_angle); int_angle = 0; end
    if isempty(int_rate); int_rate = 0; end
    if isempty(rate_filt); rate_filt = 0; end
    if isempty(prev_e_rate); prev_e_rate = 0; end
    if isempty(Kd_rate); Kd_rate = 0; end
    if isempty(Kd_damp); Kd_damp = 0.55; end
    if isempty(elevator_sign); elevator_sign = 1; end
    if nargin < 9 || isempty(r_ff); r_ff = 0; end
    if nargin < 10 || isempty(pitch_ref_dot); pitch_ref_dot = 0; end
    if nargin < 11 || isempty(phi); phi = 0; end

    e_psi = wrapToPi(yaw_ref - psi);
    e_r = r - r_ff;
    delta_r_cmd = Kp_psi * e_psi - Kd_psi * e_r;
    delta_r_cmd = max(min(delta_r_cmd, delta_r_max), -delta_r_max);

    theta_phys = -theta;
    theta_phys_dot = -q * cos(phi) + r * sin(phi);
    rate_filt = 0.90 * rate_filt + 0.10 * theta_phys_dot;

    e_theta = pitch_ref - theta_phys;
    int_angle = int_angle + e_theta * dt;
    int_angle_max = deg2rad(8) / max(Ki_angle, 1e-6);
    int_angle = max(min(int_angle, int_angle_max), -int_angle_max);

    theta_rate_cmd = 0.8 * pitch_ref_dot + Kp_angle * e_theta + Ki_angle * int_angle;
    theta_rate_cmd = max(min(theta_rate_cmd, deg2rad(14)), deg2rad(-14));

    e_rate = theta_rate_cmd - rate_filt;
    de_rate = 0;
    if Kd_rate > 0
        de_rate = (e_rate - prev_e_rate) / dt;
        de_rate = max(min(de_rate, deg2rad(25)), deg2rad(-25));
    end
    prev_e_rate = e_rate;
    int_rate = int_rate + e_rate * dt;

    de_trim = lookup_elevator_trim(abs(u));
    delta_e_I_max = deg2rad(5);
    int_rate_max = delta_e_I_max / max(Ki_rate, 1e-6);
    int_rate = max(min(int_rate, int_rate_max), -int_rate_max);

    u_el = Kp_rate * e_rate + Ki_rate * int_rate + Kd_rate * de_rate - Kd_damp * rate_filt;
    delta_e_unsat = de_trim + elevator_sign * u_el;
    delta_e_cmd = max(min(delta_e_unsat, delta_e_max), -delta_e_max);
    mag_sat = abs(delta_e_unsat) > delta_e_max + 1e-9;

    Kaw = Kaw_pitch;
    aw_err = delta_e_cmd - delta_e_unsat;
    int_rate = int_rate + Kaw * aw_err * dt;
    int_rate = max(min(int_rate, int_rate_max), -int_rate_max);
    if abs(aw_err) > 1e-4 && sign(e_theta) == sign(elevator_sign * aw_err)
        int_angle = int_angle - 0.5 * e_theta * dt;
    end

    max_dr = deg2rad(40) * dt;
    max_de = deg2rad(40) * dt;
    delta_r = prev_delta_r + max(min(delta_r_cmd - prev_delta_r, max_dr), -max_dr);
    de_step = delta_e_cmd - prev_delta_e;
    slew_sat = abs(de_step) > max_de + 1e-12;
    delta_e = prev_delta_e + max(min(de_step, max_de), -max_de);
    prev_delta_r = delta_r;
    prev_delta_e = delta_e;

    thrust = thrust_trim + Kp_x * (u_ref - u);
    thrust = max(min(thrust, thrust_max), thrust_min);

    d = struct( ...
        'delta_e_cmd', delta_e_cmd, 'delta_e_unsat', delta_e_unsat, ...
        'de_trim', de_trim, 'theta_phys', theta_phys, ...
        'theta_phys_dot', theta_phys_dot, 'rate_filt', rate_filt, ...
        'theta_rate_cmd', theta_rate_cmd, 'slew_sat', double(slew_sat), ...
        'mag_sat', double(mag_sat));
end

function de = lookup_elevator_trim(u)
    global trim_speed_table trim_elevator_table delta_e_trim
    if isempty(trim_speed_table) || isempty(trim_elevator_table)
        de = delta_e_trim; return;
    end
    de = interp1(trim_speed_table, trim_elevator_table, u, 'linear', 'extrap');
end

function clear_diag_persistents()
    % Local-function persistents: signal reset via global flag
    global DIAG_RESET_GUID DIAG_RESET_CTRL
    DIAG_RESET_GUID = true;
    DIAG_RESET_CTRL = true;
end

%% ===================== guidance helpers (copied) =====================
function [s_nodes, s_total] = path_arclength(path)
    n = size(path, 1);
    s_nodes = zeros(n, 1);
    for i = 2:n
        s_nodes(i) = s_nodes(i-1) + norm(path(i,:) - path(i-1,:));
    end
    s_total = max(s_nodes(end), 1e-9);
end

function d = wrap_arc(ds, s_total)
    d = mod(ds + 0.5*s_total, s_total) - 0.5*s_total;
end

function [s_best, d_best] = project_on_path(p, path, s_nodes, s_lo, s_hi, is_closed)
    s_total = s_nodes(end);
    if is_closed && s_hi > s_total
        [s1, d1] = project_interval(p, path, s_nodes, s_lo, s_total);
        [s2, d2] = project_interval(p, path, s_nodes, 0, mod(s_hi, s_total));
        if d1 <= d2; s_best = s1; d_best = d1; else; s_best = s2; d_best = d2; end
    else
        [s_best, d_best] = project_interval(p, path, s_nodes, max(0,s_lo), min(s_total,s_hi));
    end
end

function [s_best, d_best] = project_interval(p, path, s_nodes, s_lo, s_hi)
    n = size(path, 1);
    d_best = inf; s_best = s_lo;
    i0 = max(1, find(s_nodes <= s_lo, 1, 'last'));
    i1 = min(n-1, find(s_nodes >= s_hi, 1, 'first'));
    if isempty(i0); i0 = 1; end
    if isempty(i1); i1 = n-1; end
    i0 = min(i0, n-1); i1 = max(i1, i0);
    for i = i0:i1
        a = path(i,:); b = path(i+1,:);
        ab = b - a; lab2 = sum(ab.^2);
        if lab2 < 1e-12; continue; end
        t = max(0, min(1, dot(p - a, ab) / lab2));
        proj = a + t * ab;
        dd = norm(p - proj);
        s = s_nodes(i) + t * (s_nodes(i+1) - s_nodes(i));
        if s < s_lo - 1e-9 || s > s_hi + 1e-9; continue; end
        if dd < d_best; d_best = dd; s_best = s; end
    end
end

function [p, t_hat] = sample_path(path, s_nodes, s, is_closed)
    n = size(path, 1); s_total = s_nodes(end);
    if is_closed; s = mod(s, s_total); else; s = max(0, min(s_total, s)); end
    i = max(1, min(n-1, find(s_nodes <= s, 1, 'last')));
    if isempty(i); i = 1; end
    ds = s_nodes(i+1) - s_nodes(i);
    if ds < 1e-12; t = 0; else; t = (s - s_nodes(i)) / ds; end
    p = path(i,:) + t * (path(i+1,:) - path(i,:));
    tang = path(i+1,:) - path(i,:);
    if norm(tang) < 1e-9
        if i > 1; tang = path(i,:) - path(i-1,:); else; tang = [1, 0, 0]; end
    end
    t_hat = tang / norm(tang);
end

function kappa = path_curvature_at(path, s_nodes, s, is_closed)
    s_total = s_nodes(end);
    ds = max(0.4, 0.05 * s_total);
    [~, t1] = sample_path(path, s_nodes, s - ds, is_closed);
    [~, t2] = sample_path(path, s_nodes, s + ds, is_closed);
    a = t1(1:2); b = t2(1:2);
    if norm(a) < 1e-9 || norm(b) < 1e-9; kappa = 0; return; end
    a = a / norm(a); b = b / norm(b);
    ang = atan2(a(1)*b(2) - a(2)*b(1), a(1)*b(1) + a(2)*b(2));
    kappa = ang / (2*ds);
end

%% ===================== plots =====================
function plot_x_diag(log, m, fpath, title_str)
    fig = figure('Color','w','Position',[60 60 1200 800], 'Visible','off');
    subplot(3,2,1);
    plot(log.t, rad2deg(log.pitch_ref_raw), 'Color',[0.85 0.4 0.1]); hold on;
    plot(log.t, rad2deg(log.pitch_ref), 'b', 'LineWidth', 1.2);
    plot(log.t, rad2deg(log.theta_phys), 'k', 'LineWidth', 1.0);
    grid on; ylabel('deg'); title(title_str);
    legend('pitch_{ref,raw}','pitch_{ref}','\theta_{phys}', 'Location','best');

    subplot(3,2,2);
    global delta_e_max
    plot(log.t, rad2deg(log.delta_e), 'b'); hold on;
    plot(log.t, rad2deg(log.delta_e_cmd), 'r--');
    plot(log.t, rad2deg(log.delta_e_unsat), 'Color',[0.6 0.6 0.6]);
    yline(rad2deg(delta_e_max), 'k:'); yline(-rad2deg(delta_e_max), 'k:');
    grid on; ylabel('deg'); title(sprintf('\\delta_e  mag-sat=%.1f%% slew-sat=%.1f%%', m.pct_de_mag_sat, m.pct_de_slew_sat));
    legend('\delta_e','cmd','unsat','Location','best');

    subplot(3,2,3);
    plot(log.t, rad2deg(log.theta_phys_dot), 'k'); hold on;
    plot(log.t, rad2deg(log.rate_filt), 'b', 'LineWidth', 1.2);
    grid on; ylabel('deg/s'); title(sprintf('rate vs filt  RMS(err)=%.3f deg/s', m.rms_rate_err_dps));
    legend('\theta_{phys}dot','rate_{filt}', 'Location','best');

    subplot(3,2,4);
    plot(log.t, rad2deg(log.theta_phys_dot - log.rate_filt), 'r');
    grid on; ylabel('deg/s'); title('rate - rate_{filt}');

    subplot(3,2,5);
    plot(log.t, rad2deg(log.pitch_ref_raw - log.pitch_ref), 'm');
    grid on; ylabel('deg'); xlabel('t (s)');
    title(sprintf('raw-ref  raw pp=%.2f°  ref pp=%.2f°', m.pitch_ref_raw_pp_deg, m.pitch_ref_pp_deg));

    subplot(3,2,6);
    plot(log.t, rad2deg(log.theta_phys), 'k'); hold on;
    plot(log.t, rad2deg(log.pitch_ref), 'b--');
    grid on; xlabel('t (s)'); ylabel('deg');
    title(sprintf('chatter=%.3f deg/s  \\theta pp=%.2f°', m.pitch_chatter_dps, m.theta_pp_deg));

    exportgraphics(fig, fpath, 'Resolution', 140);
    close(fig);
end

function plot_ablation_compare(logA, logB, mA, mB, fpath, title_str)
    fig = figure('Color','w','Position',[60 60 1100 700], 'Visible','off');
    subplot(2,2,1);
    plot(logA.t, rad2deg(logA.theta_phys), 'k'); hold on;
    plot(logB.t, rad2deg(logB.theta_phys), 'r');
    grid on; ylabel('deg'); title(title_str);
    legend(sprintf('A chatter=%.3f', mA.pitch_chatter_dps), ...
           sprintf('B chatter=%.3f', mB.pitch_chatter_dps), 'Location','best');

    subplot(2,2,2);
    plot(logA.t, rad2deg(logA.delta_e), 'k'); hold on;
    plot(logB.t, rad2deg(logB.delta_e), 'r');
    grid on; ylabel('deg'); title('\delta_e');
    legend(sprintf('A std=%.2f', mA.de_std_deg), sprintf('B std=%.2f', mB.de_std_deg), 'Location','best');

    subplot(2,2,3);
    plot(logA.t, rad2deg(logA.pitch_ref), 'k'); hold on;
    plot(logB.t, rad2deg(logB.pitch_ref), 'r');
    grid on; xlabel('t'); ylabel('deg'); title('pitch_{ref}');

    subplot(2,2,4);
    bar([mA.pitch_chatter_dps, mB.pitch_chatter_dps; mA.theta_pp_deg, mB.theta_pp_deg; mA.de_std_deg, mB.de_std_deg]');
    set(gca, 'XTickLabel', {'chatter deg/s','\theta pp deg','de std deg'});
    legend('A','B'); grid on; title('metrics');

    exportgraphics(fig, fpath, 'Resolution', 140);
    close(fig);
end

function plot_circle_diag(log, m, fpath)
    fig = figure('Color','w','Position',[60 60 1100 700], 'Visible','off');
    R = 5;
    uR = log.u / R;
    sgn = sign(median(log.r_ff(m.log_ss)));
    if sgn == 0; sgn = 1; end

    subplot(2,2,1);
    plot(log.t, rad2deg(log.r), 'b', 'LineWidth', 1.2); hold on;
    plot(log.t, rad2deg(log.r_ff), 'r--', 'LineWidth', 1.2);
    plot(log.t, rad2deg(sgn * abs(uR)), 'k:', 'LineWidth', 1.0);
    grid on; ylabel('deg/s'); title(sprintf('Circle yaw rate  r/r_{ff}=%.2f  r/(u/R)=%.2f', ...
        m.q6.ratio_r_over_rff, m.q6.ratio_r_over_uR));
    legend('r_{actual}','r_{ff}','u/R (signed)', 'Location','best');

    subplot(2,2,2);
    plot3(log.xyz(:,1), log.xyz(:,2), log.xyz(:,3), 'b'); hold on;
    th = linspace(0,2*pi,200);
    plot3(R*cos(th), R*sin(th), zeros(size(th)), 'k--');
    axis equal; grid on; title('XY path'); xlabel('x'); ylabel('y');

    subplot(2,2,3);
    plot(log.t, rad2deg(log.phi), 'b'); grid on;
    ylabel('deg'); title(sprintf('\\phi  mean=%.2f° max| |=%.2f°', m.q7.phi_mean_deg, m.q7.phi_max_abs_deg));

    subplot(2,2,4);
    beta = atan2(log.v, max(log.u, 0.35));
    plot(log.t, rad2deg(beta), 'r'); grid on;
    xlabel('t'); ylabel('deg');
    title(sprintf('\\beta  mean=%.2f° max| |=%.2f°', m.q7.beta_mean_deg, m.q7.beta_max_abs_deg));

    exportgraphics(fig, fpath, 'Resolution', 140);
    close(fig);
end

function plot_moments(log, mom, fpath)
    fig = figure('Color','w','Position',[60 60 1100 700], 'Visible','off');
    subplot(2,1,1);
    plot(log.t, log.M_elev, 'k', 'LineWidth', 1.3); hold on;
    plot(log.t, log.M_rest, 'r');
    plot(log.t, log.M_uw, 'b');
    plot(log.t, log.M_qq, 'm');
    plot(log.t, log.M_ww, 'g');
    grid on; ylabel('N·m');
    title(sprintf('Pitch moments  top opponent=%s (corr vs -M_{elev}=%.2f)', ...
        mom.top_opponent, mom.top_corr_opp));
    legend('M_{elev}','M_{rest}','M_{uw}','M_{qq}','M_{ww}', 'Location','best');

    subplot(2,1,2);
    names = {'rest','ww','qq','uw','uq','other'};
    vals = [mom.rms_M_rest, mom.rms_M_ww, mom.rms_M_qq, mom.rms_M_uw, mom.rms_M_uq, mom.rms_M_other];
    prods = [mom.mean_prod_rest, mom.mean_prod_ww, mom.mean_prod_qq, ...
             mom.mean_prod_uw, mom.mean_prod_uq, mom.mean_prod_other];
    yyaxis left; bar(vals); ylabel('RMS N·m');
    yyaxis right; plot(1:6, prods, 'ro-', 'LineWidth', 1.2); ylabel('mean(M_i * M_{elev})');
    set(gca, 'XTick', 1:6, 'XTickLabel', names);
    grid on; title(sprintf('RMS + opposition product (neg => opposes elev)  M_{elev} RMS=%.3f', mom.rms_M_elev));
    xlabel('component');

    exportgraphics(fig, fpath, 'Resolution', 140);
    close(fig);
end

%% ===================== markdown =====================
function write_answers_md(md_path, A)
    fid = fopen(md_path, 'w');
    fprintf(fid, '# DIAG_ANSWERS — Pitch Chatter / Circle Diagnostics\n\n');
    fprintf(fid, 'Generated by `diag_pitch_chatter.m` (instrumented copies; production `controller_law` / `guidance_law` unchanged).\n');
    fprintf(fid, 'dt baseline = 0.075 s. X-line T=18 s. Circle R=5 m, T=35 s.\n\n');

    % Q1
    q1 = A.q1;
    vibrates = q1.pitch_ref_raw_pp_deg > 0.3 || q1.pitch_ref_raw_hf_rms_deg > 0.05;
    fprintf(fid, '## 1. Does `pitch_ref_raw` vibrate/oscillate?\n\n');
    fprintf(fid, '**%s**\n\n', tern(vibrates, 'YES (mild)', 'NO / negligible'));
    fprintf(fid, '| Signal | std (deg) | peak-peak (deg) | HF RMS (deg) |\n|---|---:|---:|---:|\n');
    fprintf(fid, '| pitch_ref_raw | %.3f | %.3f | %.3f |\n', q1.pitch_ref_raw_std_deg, q1.pitch_ref_raw_pp_deg, q1.pitch_ref_raw_hf_rms_deg);
    fprintf(fid, '| pitch_ref (filt/rate-lim) | %.3f | %.3f | %.3f |\n\n', q1.pitch_ref_std_deg, q1.pitch_ref_pp_deg, q1.pitch_ref_hf_rms_deg);
    fprintf(fid, 'Interpretation: Raw depth-correction pitch command has pp=%.2f°; post-filter/rate-limit reduces HF to %.3f° RMS. ', ...
        q1.pitch_ref_raw_pp_deg, q1.pitch_ref_hf_rms_deg);
    if q1.pitch_ref_raw_pp_deg > q1.pitch_ref_pp_deg * 1.2
        fprintf(fid, 'Guidance filter/rate-limit is attenuating raw chatter.\n\n');
    else
        fprintf(fid, 'Filter does not drastically change amplitude (slow drift dominates pp).\n\n');
    end

    % Q2
    q2 = A.q2;
    hit_mag = q2.pct_mag_sat > 1.0;
    hit_slew = q2.pct_slew_sat > 1.0;
    fprintf(fid, '## 2. Elevator saturation / slew limits?\n\n');
    fprintf(fid, '**Mag sat: %s** | **Slew sat: %s**\n\n', tern(hit_mag,'YES','NO'), tern(hit_slew,'YES','NO'));
    fprintf(fid, '- delta_e_max = ±%.1f deg\n', q2.delta_e_max_deg);
    fprintf(fid, '- %% time |delta_e| >= 0.95*max: **%.2f%%**\n', q2.pct_mag_sat);
    fprintf(fid, '- %% time slew saturated: **%.2f%%**\n', q2.pct_slew_sat);
    fprintf(fid, '- max |delta_e|=%.2f°, |cmd|=%.2f°, |unsat|=%.2f°\n\n', ...
        q2.max_abs_de_deg, q2.max_abs_de_cmd_deg, q2.max_abs_de_unsat_deg);
    fprintf(fid, 'Interpretation: ');
    if ~hit_mag && ~hit_slew
        fprintf(fid, 'Elevator is mostly unsaturated; chatter is not from hard limit bang-bang.\n\n');
    elseif hit_slew && ~hit_mag
        fprintf(fid, 'Rate/slew limiting is active more than amplitude clips — command wants faster elevator moves than ±40°/s allow.\n\n');
    else
        fprintf(fid, 'Hard amplitude and/or slew limiting are engaged; can inject nonlinear chatter.\n\n');
    end

    % Q3
    q3 = A.q3;
    d_ang = 100*(q3.chatter_Ki_angle0 - q3.chatter_base)/max(q3.chatter_base,1e-9);
    d_rate = 100*(q3.chatter_Ki_rate0 - q3.chatter_base)/max(q3.chatter_base,1e-9);
    d_both = 100*(q3.chatter_both0 - q3.chatter_base)/max(q3.chatter_base,1e-9);
    fprintf(fid, '## 3. Does chatter decrease when Ki=0?\n\n');
    fprintf(fid, '| Case | pitch_chatter (deg/s) | θ pp (deg) | δe std (deg) | Δchatter %% |\n|---|---:|---:|---:|---:|\n');
    fprintf(fid, '| Baseline | %.4f | %.3f | %.3f | 0 |\n', q3.chatter_base, q3.theta_pp_base_deg, q3.de_std_base_deg);
    fprintf(fid, '| Ki_angle=0 | %.4f | %.3f | %.3f | %+.1f%% |\n', q3.chatter_Ki_angle0, q3.theta_pp_Ki_angle0_deg, q3.de_std_Ki_angle0_deg, d_ang);
    fprintf(fid, '| Ki_rate=0 | %.4f | %.3f | %.3f | %+.1f%% |\n', q3.chatter_Ki_rate0, q3.theta_pp_Ki_rate0_deg, q3.de_std_Ki_rate0_deg, d_rate);
    fprintf(fid, '| Both Ki=0 | %.4f | %.3f | %.3f | %+.1f%% |\n\n', q3.chatter_both0, q3.theta_pp_both0_deg, q3.de_std_both0_deg, d_both);
    fprintf(fid, '**Angle I off helps? %s.** **Rate I off helps? %s.** **Both? %s.**\n\n', ...
        tern(d_ang < -5, 'YES', 'NO'), tern(d_rate < -5, 'YES', 'NO'), tern(d_both < -5, 'YES', 'NO'));
    fprintf(fid, 'Interpretation: Negative Δ%% means less chatter. Integrators are %s primary chatter source.\n\n', ...
        tern(min([d_ang,d_rate,d_both]) < -10, 'a', 'not the'));

    % Q4
    q4 = A.q4;
    diverge = q4.rms_rate_minus_filt_dps > 0.5 || (~isnan(q4.lag_est_s) && abs(q4.lag_est_s) > 0.15);
    fprintf(fid, '## 4. Filter delay: θ̇_phys vs rate_filt diverge?\n\n');
    fprintf(fid, '**%s**\n\n', tern(diverge, 'YES (noticeable lag/error)', 'MILD / small'));
    fprintf(fid, '- RMS(θ̇_phys − rate_filt) = **%.3f deg/s**\n', q4.rms_rate_minus_filt_dps);
    fprintf(fid, '- peak |err| = **%.3f deg/s**\n', q4.peak_rate_minus_filt_dps);
    fprintf(fid, '- corr(rate, filt) = **%.3f**\n', q4.corr_rate_filt);
    fprintf(fid, '- estimated lag = **%.3f s** (LPF α=0.10 → τ≈0.71 s at dt=0.075)\n\n', q4.lag_est_s);
    fprintf(fid, 'Interpretation: The 0.9/0.1 rate LPF intentionally lags; inner loop sees delayed rate which can phase-shift damping.\n\n');

    % Q5
    q5 = A.q5;
    d_dt = 100*(q5.chatter_half - q5.chatter_base)/max(q5.chatter_base,1e-9);
    fprintf(fid, '## 5. Does chatter decrease when dt halved?\n\n');
    fprintf(fid, '**%s** (Δchatter = %+.1f%%)\n\n', tern(d_dt < -5, 'YES', 'NO'), d_dt);
    fprintf(fid, '| | dt=%.3f | dt=%.3f |\n|---|---:|---:|\n', q5.dt_base, q5.dt_half);
    fprintf(fid, '| chatter (deg/s) | %.4f | %.4f |\n', q5.chatter_base, q5.chatter_half);
    fprintf(fid, '| θ pp (deg) | %.3f | %.3f |\n', q5.theta_pp_base_deg, q5.theta_pp_half_deg);
    fprintf(fid, '| δe std (deg) | %.3f | %.3f |\n', q5.de_std_base_deg, q5.de_std_half_deg);
    fprintf(fid, '| %% slew sat | %.2f | %.2f |\n\n', q5.pct_slew_base, q5.pct_slew_half);
    fprintf(fid, 'Note: diag path uses consistent dt in guidance (`dt_nom`), controller, and ode step (production hard-codes 0.075).\n\n');

    % Q6
    q6 = A.q6;
    catchup = q6.ratio_r_over_uR >= 0.90 && q6.ratio_r_over_rff >= 0.85;
    fprintf(fid, '## 6. Circle: does r_actual catch up to u/R (and r_ff)?\n\n');
    fprintf(fid, '**%s**\n\n', tern(catchup, 'YES (mostly)', 'NO (lags)'));
    fprintf(fid, '- mean u (ss) = %.3f m/s\n', q6.mean_u_ss);
    fprintf(fid, '- mean r = **%.2f deg/s**\n', q6.mean_r_dps);
    fprintf(fid, '- mean r_ff = **%.2f deg/s**\n', q6.mean_r_ff_dps);
    fprintf(fid, '- mean u/R = **%.2f deg/s**\n', q6.mean_u_over_R_dps);
    fprintf(fid, '- mean u·κ = **%.2f deg/s**\n', q6.mean_r_geom_dps);
    fprintf(fid, '- r / r_ff = **%.2f**, r / (u/R) = **%.2f**\n', q6.ratio_r_over_rff, q6.ratio_r_over_uR);
    fprintf(fid, '- mean lag (r_ff−r) = **%.2f deg/s**, RMS err = **%.2f deg/s**\n\n', ...
        q6.mean_lag_rff_dps, q6.rms_err_rff_dps);
    fprintf(fid, 'Interpretation: Steady-state yaw-rate tracking vs geometric u/R and boosted r_ff=1.15·u_ref·κ.\n\n');

    % Q7
    q7 = A.q7;
    fprintf(fid, '## 7. How large are roll (φ) and sideslip (β)?\n\n');
    fprintf(fid, '| | mean | RMS | max\\|·\\| | peak-peak |\n|---|---:|---:|---:|---:|\n');
    fprintf(fid, '| φ (roll) | %.2f° | %.2f° | %.2f° | %.2f° |\n', ...
        q7.phi_mean_deg, q7.phi_rms_deg, q7.phi_max_abs_deg, q7.phi_pp_deg);
    fprintf(fid, '| β (sideslip) | %.2f° | %.2f° | %.2f° | %.2f° |\n\n', ...
        q7.beta_mean_deg, q7.beta_rms_deg, q7.beta_max_abs_deg, q7.beta_pp_deg);
    fprintf(fid, 'Interpretation: Steady circle window (last ~60%% after t≥8 s).\n\n');

    % Q8
    q8 = A.q8;
    fprintf(fid, '## 8. Which moment components oppose elevator periodically?\n\n');
    fprintf(fid, '**Primary opponent (by corr vs −M_elev): `%s`** (corr=%.3f, opp_frac=%.2f)\n\n', ...
        q8.top_opponent, q8.top_corr_opp, q8.top_opp_frac);
    fprintf(fid, '| Component | RMS (N·m) | mean(M_i·M_elev) | corr vs −M_elev |\n|---|---:|---:|---:|\n');
    fprintf(fid, '| M_elev | %.4f | — | — |\n', q8.rms_M_elev);
    fprintf(fid, '| M_rest | %.4f | %.4f | %.3f |\n', q8.rms_M_rest, q8.mean_prod_rest, q8.corr_rest_vs_neg_elev);
    fprintf(fid, '| M_ww | %.4f | %.4f | %.3f |\n', q8.rms_M_ww, q8.mean_prod_ww, q8.corr_ww_vs_neg_elev);
    fprintf(fid, '| M_qq | %.4f | %.4f | %.3f |\n', q8.rms_M_qq, q8.mean_prod_qq, q8.corr_qq_vs_neg_elev);
    fprintf(fid, '| M_uw | %.4f | %.4f | %.3f |\n', q8.rms_M_uw, q8.mean_prod_uw, q8.corr_uw_vs_neg_elev);
    fprintf(fid, '| M_uq | %.4f | %.4f | %.3f |\n', q8.rms_M_uq, q8.mean_prod_uq, q8.corr_uq_vs_neg_elev);
    fprintf(fid, '| M_other | %.4f | %.4f | %.3f |\n\n', q8.rms_M_other, q8.mean_prod_other, q8.corr_other_vs_neg_elev);
    fprintf(fid, 'Interpretation: Negative mean(M_i·M_elev) means that component tends to oppose elevator moment. ');
    fprintf(fid, 'Restoring (B>W / metacentric) and hydrodynamic Muw·u·w / Mqq·q|q| are the usual pitch fight terms.\n\n');

    fprintf(fid, '## Plots\n\n');
    fprintf(fid, '- `diag_x_baseline.png`\n');
    fprintf(fid, '- `diag_x_Ki0.png`\n');
    fprintf(fid, '- `diag_x_dt_half.png`\n');
    fprintf(fid, '- `diag_circle_yawrate.png`\n');
    fprintf(fid, '- `diag_moments.png`\n');
    fclose(fid);
end

function s = tern(c, a, b)
    if c; s = a; else; s = b; end
end
