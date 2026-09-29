function results = diag_tur25_bias()
% DIAG_TUR25_BIAS  Tur 2.5 pitch tracking bias diagnostics (Tests A–D).
% Level-flight harness (guidance OFF) + production X-line compare.
% Uses production controller_law (optional 4th dbg) and frozen Tur12 timing.
% Writes: suite_results/T25_DIAG.md, suite_results/T25_*.png / .mat

    project_dir = fileparts(fileparts(fileparts(mfilename('fullpath')))); % repo root
    addpath(genpath(fullfile(project_dir, 'matlab')));
    out_dir = fullfile(project_dir, 'suite_results');
    if ~exist(out_dir, 'dir'); mkdir(out_dir); end

    clear guidance_law controller_law
    init_parameters();
    global elevator_sign trim_speed_table trim_elevator_table
    global Ki_angle Ki_rate dt_controller dt_guidance tau_rate
    global delta_e_max Kp_rate

    fprintf('\n========== TUR 2.5 BIAS DIAG ==========\n');
    fprintf('dt_c=%.4f  dt_g=%.4f  tau_rate=%.4f  Ki_rate=%.3f  Ki_angle=%.3f\n', ...
        dt_controller, dt_guidance, tau_rate, Ki_rate, Ki_angle);

    % Ensure cal / trim table present (no Muw-FF / circle / XZ changes)
    if isempty(elevator_sign) || isempty(trim_speed_table)
        fprintf('--- Calibration (elevator sign + trim) ---\n');
        sign_rep = test_elevator_sign();
        elevator_sign = sign_rep.delta_e_sign;
        build_pitch_trim_table();
    else
        fprintf('--- Reusing elevator_sign=%+d trim de_deg=[%s]\n', ...
            elevator_sign, num2str(rad2deg(trim_elevator_table),'%+.2f '));
    end

    results = struct();
    results.freeze = struct( ...
        'dt_controller', dt_controller, ...
        'dt_guidance', dt_guidance, ...
        'tau_rate', tau_rate, ...
        'Ki_rate', Ki_rate, ...
        'Ki_angle', Ki_angle, ...
        'trim_speed', trim_speed_table, ...
        'trim_de_deg', rad2deg(trim_elevator_table), ...
        'elevator_sign', elevator_sign);

    %% ===== Test A: Pure trim / level flight =====
    fprintf('\n--- Test A: Pure level (guidance OFF, pitch_ref=0) ---\n');
    speeds_A = [1.0, 1.5, 2.0];
    results.A = struct([]);
    for i = 1:numel(speeds_A)
        u = speeds_A(i);
        clear controller_law
        logA = run_level_flight(u, 0, 20);
        mA = metrics_settle(logA, 8.0);
        mA.u_req = u;
        results.A = [results.A, mA]; %#ok<AGROW>
        fprintf('  u=%.1f | mean e_th=%+.3f° | mean|e|=%.3f° | RMS=%.3f° | chatter=%.4f | I_ang=[%.3f,%.3f] | de_I=%.3f° | de_trim=%.3f°\n', ...
            u, mA.mean_e_theta_deg, mA.mean_abs_e_deg, mA.rms_e_deg, mA.pitch_chatter_dps, ...
            mA.angle_I_min, mA.angle_I_max, mA.mean_delta_e_angle_I_deg, mA.mean_de_trim_deg);
    end
    plot_test_A(results.A, fullfile(out_dir, 'T25_testA_level.png'));

    %% ===== Test B: Pitch ref symmetry @ u=2.0 =====
    fprintf('\n--- Test B: Pitch ref symmetry @ u=2.0 ---\n');
    prefs_B = deg2rad([-10, -5, 5, 10]);
    results.B = struct([]);
    for i = 1:numel(prefs_B)
        pr = prefs_B(i);
        clear controller_law
        logB = run_level_flight(2.0, pr, 22);
        mB = metrics_step_ref(logB, pr, 6.0);
        results.B = [results.B, mB]; %#ok<AGROW>
        fprintf('  pref=%+5.1f° | mean e=%+.3f° | settle≈%.2fs | OS=%.2f° | I_ss=%.3f | de_mean=%.3f° | chatter=%.4f\n', ...
            rad2deg(pr), mB.mean_e_theta_deg, mB.settle_s, mB.overshoot_deg, ...
            mB.angle_I_ss, mB.mean_delta_e_deg, mB.pitch_chatter_dps);
    end
    plot_test_B(results.B, fullfile(out_dir, 'T25_testB_symmetry.png'));

    %% ===== Test C: Ki_angle ablation @ level pitch_ref=0 =====
    fprintf('\n--- Test C: Ki_angle ablation (level, u=2.0) ---\n');
    Ki0 = Ki_angle;
    scales = [1.0, 0.5, 1.5];
    tags = {'C0_current', 'C1_0p5x', 'C2_1p5x'};
    results.C = struct([]);
    for i = 1:numel(scales)
        Ki_angle = Ki0 * scales(i);
        clear controller_law
        logC = run_level_flight(2.0, 0, 20);
        mC = metrics_settle(logC, 8.0);
        mC.tag = tags{i};
        mC.Ki_angle = Ki_angle;
        mC.scale = scales(i);
        results.C = [results.C, mC]; %#ok<AGROW>
        fprintf('  %s Ki=%.3f | mean e=%+.3f° | |e|=%.3f° | chatter=%.4f | I_maxabs=%.3f | de_I=%.3f°\n', ...
            tags{i}, Ki_angle, mC.mean_e_theta_deg, mC.mean_abs_e_deg, ...
            mC.pitch_chatter_dps, max(abs([mC.angle_I_min, mC.angle_I_max])), ...
            mC.mean_delta_e_angle_I_deg);
    end
    Ki_angle = Ki0;
    plot_test_C(results.C, fullfile(out_dir, 'T25_testC_Ki_ablation.png'));

    %% ===== Test D: Pure level vs production X-line =====
    fprintf('\n--- Test D: Pure level vs production X-line ---\n');
    clear controller_law guidance_law
    Ki_angle = Ki0;
    logD1 = run_level_flight(1.5, 0, 18);
    mD1 = metrics_settle(logD1, 6.0);
    mD1.tag = 'D1_pure_level';
    results.D1 = mD1;
    fprintf('  D1 pure | mean e=%+.3f° | |e|=%.3f° | chatter=%.4f | de_I=%.3f°\n', ...
        mD1.mean_e_theta_deg, mD1.mean_abs_e_deg, mD1.pitch_chatter_dps, mD1.mean_delta_e_angle_I_deg);

    clear controller_law guidance_law
    logD2 = run_xline_production(1.5, 18);
    mD2 = metrics_xline(logD2, 6.0);
    mD2.tag = 'D2_xline_guid';
    results.D2 = mD2;
    fprintf('  D2 X-line | mean e=%+.3f° | |e|=%.3f° | chatter=%.4f | CTE=%.3f | depth_e=%.3f | de_I=%.3f°\n', ...
        mD2.mean_e_theta_deg, mD2.mean_abs_e_deg, mD2.pitch_chatter_dps, ...
        mD2.mean_cte, mD2.mean_depth_err, mD2.mean_delta_e_angle_I_deg);

    plot_test_D(logD1, logD2, mD1, mD2, fullfile(out_dir, 'T25_testD_compare.png'));

    %% Decision tree
    results.decision = decide_tree(results);
    fprintf('\n--- Decision: %s ---\n%s\n', results.decision.branch, results.decision.rationale);

    md_path = fullfile(out_dir, 'T25_DIAG.md');
    write_diag_md(md_path, results);
    mat_path = fullfile(out_dir, 'T25_diag_results.mat');
    save(mat_path, 'results', 'logD1', 'logD2');
    fprintf('\nWrote %s\nWrote %s\n========== TUR 2.5 DIAG DONE ==========\n', md_path, mat_path);
end

%% ===================== level-flight harness =====================
function log = run_level_flight(u_des, pitch_ref, T_final)
% Guidance OFF, depth P/I OFF: fixed pitch_ref / yaw_ref, thrust speed hold.
    global dt_controller desired_speed thrust_trim Kp_x
    global last_int_angle last_delta_e last_de_trim last_delta_e_angle_I
    global last_e_theta last_theta_phys last_theta_phys_dot last_rate_filt
    global delta_e_max

    dt = dt_controller;
    if isempty(dt); dt = 0.025; end
    n = round(T_final / dt);

    state = zeros(12, 1);
    state(7) = u_des;
    % pitch≈0, yaw fixed at 0
    yaw_ref = 0;
    u_ref = u_des;
    desired_speed = u_des; %#ok<NASGU>

    log = alloc_level_log(n);
    for k = 1:n
        ori = state(4:6);
        rates = state(10:12);
        u = state(7); w = state(9);

        [delta_r, delta_e, thrust, dbg] = controller_law( ...
            yaw_ref, pitch_ref, u_ref, ori(3), ori(2), rates(3), rates(2), ...
            u, 0, 0, ori(1));

        controls = struct('delta_r', delta_r, 'delta_e', delta_e, 'thrust', thrust);
        try
            [~, g] = ode45(@(t, x) underwater777_vehicle_dynamics(t, x, controls), [0 dt], state);
            state = g(end, :)';
        catch ME
            fprintf(2, 'Level sim failed step %d: %s\n', k, ME.message);
            log = trim_log(log, k-1);
            return;
        end

        log.t(k) = k * dt;
        log.xyz(k,:) = state(1:3)';
        log.theta(k) = state(5);
        log.psi(k) = state(6);
        log.u(k) = state(7);
        log.w(k) = state(9);
        log.q(k) = state(11);
        log.pitch_ref(k) = pitch_ref;
        log.theta_phys(k) = dbg.theta_phys;
        log.e_theta(k) = dbg.e_theta;
        log.delta_e(k) = delta_e;
        log.de_trim(k) = dbg.de_trim;
        log.delta_e_angle_I(k) = dbg.delta_e_angle_I;
        log.int_angle(k) = dbg.int_angle;
        log.int_angle_max(k) = dbg.int_angle_max;
        log.theta_phys_dot(k) = dbg.theta_phys_dot;
        log.rate_filt(k) = dbg.rate_filt;
        log.mag_sat(k) = dbg.mag_sat;
        log.thrust(k) = thrust;
        log.delta_r(k) = delta_r;
        log.depth(k) = state(3);

        if mod(k, round(4/dt)) == 0 || k == n
            fprintf('    t=%.1f u=%.2f th=%.2f° e=%.2f° de=%.2f° I=%.3f\n', ...
                log.t(k), u, rad2deg(dbg.theta_phys), rad2deg(dbg.e_theta), ...
                rad2deg(delta_e), dbg.int_angle);
        end
    end
end

function log = run_xline_production(u0, T_final)
% Production multi-rate X-line with guidance depth P/I on.
    global dt_controller dt_guidance desired_speed
    global last_de_trim last_delta_e_angle_I last_e_theta last_theta_phys
    global last_int_angle last_theta_phys_dot last_rate_filt

    dt = dt_controller;
    n = round(T_final / dt);
    n_path = 400;
    x = linspace(0, 20, n_path)';
    path = [x, zeros(n_path,1), zeros(n_path,1)];
    state = zeros(12,1);
    state(1:3) = path(1,:)';
    state(6) = 0;
    state(7) = u0;
    desired_speed = 1.5;

    guidance_period = max(1, round(dt_guidance / dt));
    yaw_ref = 0; pitch_ref = 0; u_ref = u0; r_ff = 0; pitch_ref_dot = 0;
    progress_index = 1;

    log = alloc_level_log(n);
    log.pitch_ref_raw = zeros(n,1);
    log.z_e = zeros(n,1);
    log.cte = zeros(n,1);

    for k = 1:n
        pos = state(1:3)';
        ori = state(4:6);
        rates = state(10:12);
        u = state(7); v = state(8);

        if mod(k - 1, guidance_period) == 0
            [yaw_ref, pitch_ref, u_ref, progress_index, r_ff, pitch_ref_dot] = ...
                guidance_law(pos, path, progress_index, u, v);
        end

        [delta_r, delta_e, thrust, dbg] = controller_law( ...
            yaw_ref, pitch_ref, u_ref, ori(3), ori(2), rates(3), rates(2), ...
            u, r_ff, pitch_ref_dot, ori(1));

        controls = struct('delta_r', delta_r, 'delta_e', delta_e, 'thrust', thrust);
        try
            [~, g] = ode45(@(t, x) underwater777_vehicle_dynamics(t, x, controls), [0 dt], state);
            state = g(end, :)';
        catch ME
            fprintf(2, 'X-line sim failed step %d: %s\n', k, ME.message);
            log = trim_log(log, k-1);
            return;
        end

        % CTE / depth vs path
        d = vecnorm(path - state(1:3)', 2, 2);
        [cte, ix] = min(d);
        z_e = state(3) - path(ix, 3);

        log.t(k) = k * dt;
        log.xyz(k,:) = state(1:3)';
        log.theta(k) = state(5);
        log.psi(k) = state(6);
        log.u(k) = state(7);
        log.w(k) = state(9);
        log.q(k) = state(11);
        log.pitch_ref(k) = pitch_ref;
        log.theta_phys(k) = dbg.theta_phys;
        log.e_theta(k) = dbg.e_theta;
        log.delta_e(k) = delta_e;
        log.de_trim(k) = dbg.de_trim;
        log.delta_e_angle_I(k) = dbg.delta_e_angle_I;
        log.int_angle(k) = dbg.int_angle;
        log.int_angle_max(k) = dbg.int_angle_max;
        log.theta_phys_dot(k) = dbg.theta_phys_dot;
        log.rate_filt(k) = dbg.rate_filt;
        log.mag_sat(k) = dbg.mag_sat;
        log.thrust(k) = thrust;
        log.delta_r(k) = delta_r;
        log.depth(k) = state(3);
        log.cte(k) = cte;
        log.z_e(k) = z_e;
    end
end

function log = alloc_level_log(n)
    z = zeros(n,1);
    log = struct( ...
        't', z, 'xyz', zeros(n,3), ...
        'theta', z, 'psi', z, 'u', z, 'w', z, 'q', z, ...
        'pitch_ref', z, 'theta_phys', z, 'e_theta', z, ...
        'delta_e', z, 'de_trim', z, 'delta_e_angle_I', z, ...
        'int_angle', z, 'int_angle_max', z, ...
        'theta_phys_dot', z, 'rate_filt', z, ...
        'mag_sat', z, 'thrust', z, 'delta_r', z, 'depth', z);
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
function m = metrics_settle(log, t_settle)
    global delta_e_max Ki_angle
    dt = median(diff(log.t));
    i0 = find(log.t >= t_settle, 1, 'first');
    if isempty(i0); i0 = 1; end
    sl = i0:numel(log.t);

    e = log.e_theta(sl);
    th = log.theta_phys(sl);
    de = log.delta_e(sl);
    dth = [0; diff(th)] / dt;
    dth_hf = hf_signal(detrend(dth), dt);

    m.mean_e_theta_deg = rad2deg(mean(e));
    m.mean_abs_e_deg = rad2deg(mean(abs(e)));
    m.rms_e_deg = rad2deg(rms(e));
    m.theta_phys_mean_deg = rad2deg(mean(th));
    m.pitch_ref_mean_deg = rad2deg(mean(log.pitch_ref(sl)));
    m.mean_de_trim_deg = rad2deg(mean(log.de_trim(sl)));
    m.mean_delta_e_angle_I_deg = rad2deg(mean(log.delta_e_angle_I(sl)));
    m.mean_delta_e_deg = rad2deg(mean(de));
    m.rms_delta_e_deg = rad2deg(rms(de));
    m.angle_I_min = min(log.int_angle(sl));
    m.angle_I_max = max(log.int_angle(sl));
    m.angle_I_mean = mean(log.int_angle(sl));
    m.angle_I_pegged = mean(abs(log.int_angle(sl)) >= 0.98 * abs(log.int_angle_max(sl)));
    m.w_mean = mean(log.w(sl));
    m.pitch_chatter_dps = rad2deg(std(dth_hf(max(1,round(0.8/dt)):end)));
    m.pct_mag_sat = 100 * mean(log.mag_sat(sl) > 0.5);
    m.u_mean = mean(log.u(sl));
    % Suggested new trim: fold angle-I elevator into trim table
    m.suggested_de_trim_deg = rad2deg(mean(log.de_trim(sl) + log.delta_e_angle_I(sl)));
    m.Ki_angle = Ki_angle;
    m.delta_e_max_deg = rad2deg(delta_e_max);
end

function m = metrics_step_ref(log, pitch_ref, t_settle)
    m = metrics_settle(log, t_settle);
    m.pitch_ref_cmd_deg = rad2deg(pitch_ref);
    th = log.theta_phys;
    t = log.t;
    % Settling: |e| < 0.5° for 1 s
    e_abs = abs(log.e_theta);
    win = max(1, round(1.0 / median(diff(t))));
    settled = false(size(e_abs));
    for i = 1:(numel(e_abs)-win)
        if all(e_abs(i:i+win-1) < deg2rad(0.5))
            settled(i) = true;
        end
    end
    is = find(settled, 1, 'first');
    if isempty(is); m.settle_s = NaN; else; m.settle_s = t(is); end
    % Overshoot relative to final mean
    th_ss = mean(th(t >= t_settle));
    if pitch_ref >= 0
        m.overshoot_deg = rad2deg(max(0, max(th) - th_ss));
    else
        m.overshoot_deg = rad2deg(max(0, th_ss - min(th)));
    end
    m.angle_I_ss = mean(log.int_angle(t >= t_settle));
end

function m = metrics_xline(log, t_settle)
    m = metrics_settle(log, t_settle);
    i0 = find(log.t >= t_settle, 1, 'first');
    if isempty(i0); i0 = 1; end
    sl = i0:numel(log.t);
    m.mean_cte = mean(log.cte(sl));
    m.mean_depth_err = mean(log.z_e(sl));
    m.rms_depth_err = rms(log.z_e(sl));
    m.pitch_ref_pp_deg = rad2deg(max(log.pitch_ref(sl)) - min(log.pitch_ref(sl)));
end

function y = hf_signal(x, dt)
    n = max(3, round(0.8 / dt));
    b = ones(n,1) / n;
    lf = filter(b, 1, x(:));
    y = x(:) - lf;
    y(1:n) = 0;
end

%% ===================== decision tree =====================
function d = decide_tree(R)
% 2.5.1 trim fold-in if angle-I carries steady elevator at level
% 2.5.2 small Ki_angle tweak if residual bias + chatter OK
% 2.5.3 conditional trim adapt only if 1+2 insufficient
    A = R.A;
    % Use u=1.5 and u=2.0 as primary (X-line speed)
    idx15 = find([A.u_req] == 1.5, 1);
    idx20 = find([A.u_req] == 2.0, 1);
    a15 = A(idx15); a20 = A(idx20);

    bias15 = abs(a15.mean_e_theta_deg);
    bias20 = abs(a20.mean_e_theta_deg);
    deI15 = a15.mean_delta_e_angle_I_deg;
    deI20 = a20.mean_delta_e_angle_I_deg;
    chatter_ok = a15.pitch_chatter_dps <= 0.15 && a20.pitch_chatter_dps <= 0.15;

    % Compare D1 vs D2: if pure OK-ish but X worse -> guidance depth-I
    d1 = R.D1; d2 = R.D2;
    pure_bias = abs(d1.mean_e_theta_deg);
    x_bias = abs(d2.mean_e_theta_deg);

    % Trim mismatch evidence: nonzero steady angle-I elevator at level
    trim_mismatch = (abs(deI15) > 0.15) || (abs(deI20) > 0.15) || ...
        (bias15 > 0.3) || (bias20 > 0.3);

    C = R.C;
    % Does higher Ki reduce bias without killing chatter?
    c0 = C(1); c1 = C(2); c2 = C(3);
    ki_helps = abs(c2.mean_e_theta_deg) < abs(c0.mean_e_theta_deg) - 0.05 && ...
        c2.pitch_chatter_dps <= 0.15;

    d = struct();
    d.bias_u15 = a15.mean_e_theta_deg;
    d.bias_u20 = a20.mean_e_theta_deg;
    d.deI_u15 = deI15;
    d.deI_u20 = deI20;
    d.suggested_trim_u15 = a15.suggested_de_trim_deg;
    d.suggested_trim_u20 = a20.suggested_de_trim_deg;
    d.suggested_trim_u10 = A(find([A.u_req]==1.0,1)).suggested_de_trim_deg;
    d.pure_vs_x_bias = [pure_bias, x_bias];
    d.chatter_ok = chatter_ok;

    if trim_mismatch
        d.branch = '2.5.1_trim_recalibrate';
        d.rationale = sprintf([ ...
            'Level flight shows signed bias (u1.5=%+.2f°, u2=%+.2f°) with ' ...
            'steady angle-I elevator (%.2f° / %.2f°). Fold angle-I into trim table, ' ...
            'reset angle I, retest. Chatter OK=%d. Do NOT re-enable Ki_rate.'], ...
            a15.mean_e_theta_deg, a20.mean_e_theta_deg, deI15, deI20, chatter_ok);
        d.next = 'Apply new trim from suggested_de_trim at 1.0/1.5/2.0 (keep 0.8 via extrap/search).';
    elseif pure_bias < 0.3 && x_bias > 0.7
        d.branch = 'guidance_depth_I_cause';
        d.rationale = 'Pure level OK but X-line bias remains → guidance depth-I / pitch_ref, not pitch gains.';
        d.next = 'Document; optional mild depth-I detune only if clearly safe.';
    elseif abs(c0.mean_e_theta_deg) > 0.3 && ki_helps
        d.branch = '2.5.2_Ki_angle_tweak';
        d.rationale = sprintf('Residual bias with trim OK; C2 (1.5x Ki) helps (%.3f→%.3f°) chatter OK.', ...
            c0.mean_e_theta_deg, c2.mean_e_theta_deg);
        d.next = 'Small Ki_angle increase; retest A/D.';
    else
        d.branch = '2.5.1_trim_recalibrate';
        d.rationale = 'Default: recalibrate trim from steady elevator (trim+angle-I).';
        d.next = 'Fold suggested trim; reset I; retest.';
    end

    % Suggested table for 2.5.1 (include 0.8 from current + delta at 1.0)
    d.suggested_speeds = [0.8, 1.0, 1.5, 2.0];
    a10 = A(find([A.u_req]==1.0,1));
    % For 0.8: shift current by same delta as at 1.0
    global trim_speed_table trim_elevator_table
    de08 = interp1(trim_speed_table, trim_elevator_table, 0.8, 'linear', 'extrap');
    dde10 = deg2rad(a10.suggested_de_trim_deg) - interp1(trim_speed_table, trim_elevator_table, 1.0, 'linear', 'extrap');
    d.suggested_de_rad = [de08 + dde10, ...
        deg2rad(a10.suggested_de_trim_deg), ...
        deg2rad(a15.suggested_de_trim_deg), ...
        deg2rad(a20.suggested_de_trim_deg)];
end

%% ===================== plots =====================
function plot_test_A(A, fpath)
    fig = figure('Color','w','Position',[50 50 1000 600], 'Visible','off');
    u = [A.u_req];
    subplot(2,2,1);
    bar(u, [A.mean_e_theta_deg]); ylabel('mean e_\theta (deg)'); title('Test A signed bias'); grid on;
    subplot(2,2,2);
    bar(u, [A.mean_delta_e_angle_I_deg]); ylabel('mean \delta e_{angle I} (deg)'); title('Angle-I elevator'); grid on;
    subplot(2,2,3);
    bar(u, [[A.mean_de_trim_deg]; [A.suggested_de_trim_deg]]');
    ylabel('deg'); legend('current trim','suggested'); title('Trim vs suggested'); grid on;
    subplot(2,2,4);
    bar(u, [A.pitch_chatter_dps]); ylabel('deg/s'); title('Pitch chatter'); grid on;
    exportgraphics(fig, fpath, 'Resolution', 140); close(fig);
end

function plot_test_B(B, fpath)
    fig = figure('Color','w','Position',[50 50 900 500], 'Visible','off');
    pref = [B.pitch_ref_cmd_deg];
    subplot(1,2,1);
    bar(pref, [B.mean_e_theta_deg]); ylabel('mean e (deg)'); title('Test B signed error'); grid on;
    subplot(1,2,2);
    bar(pref, [B.angle_I_ss]); ylabel('angle I ss'); title('Angle-I steady'); grid on;
    exportgraphics(fig, fpath, 'Resolution', 140); close(fig);
end

function plot_test_C(C, fpath)
    fig = figure('Color','w','Position',[50 50 900 500], 'Visible','off');
    lab = {C.tag};
    subplot(1,3,1);
    bar([C.mean_e_theta_deg]); set(gca,'XTickLabel',lab); ylabel('mean e (deg)'); title('Bias'); grid on;
    subplot(1,3,2);
    bar([C.pitch_chatter_dps]); set(gca,'XTickLabel',lab); ylabel('deg/s'); title('Chatter'); grid on;
    subplot(1,3,3);
    bar(arrayfun(@(c) max(abs([c.angle_I_min,c.angle_I_max])), C));
    set(gca,'XTickLabel',lab); ylabel('|I|_{max}'); title('Integral growth'); grid on;
    exportgraphics(fig, fpath, 'Resolution', 140); close(fig);
end

function plot_test_D(log1, log2, m1, m2, fpath)
    fig = figure('Color','w','Position',[50 50 1100 800], 'Visible','off');
    subplot(3,2,1);
    plot(log1.t, rad2deg(log1.pitch_ref), 'b--'); hold on;
    plot(log1.t, rad2deg(log1.theta_phys), 'k');
    grid on; ylabel('deg'); title(sprintf('D1 pure  e=%+.2f° chatter=%.3f', m1.mean_e_theta_deg, m1.pitch_chatter_dps));
    legend('pitch_{ref}','\theta_{phys}');
    subplot(3,2,2);
    plot(log2.t, rad2deg(log2.pitch_ref), 'b--'); hold on;
    plot(log2.t, rad2deg(log2.theta_phys), 'k');
    grid on; ylabel('deg'); title(sprintf('D2 X-line  e=%+.2f° chatter=%.3f', m2.mean_e_theta_deg, m2.pitch_chatter_dps));
    legend('pitch_{ref}','\theta_{phys}');
    subplot(3,2,3);
    plot(log1.t, rad2deg(log1.e_theta), 'k'); hold on;
    plot(log2.t, rad2deg(log2.e_theta), 'r');
    grid on; ylabel('deg'); title('signed e_\theta'); legend('D1','D2');
    subplot(3,2,4);
    if isfield(log2, 'z_e')
        plot(log2.t, log2.z_e, 'b'); grid on; ylabel('m'); title(sprintf('D2 depth err mean=%.3f', m2.mean_depth_err));
    end
    subplot(3,2,5);
    plot(log1.t, log1.int_angle, 'k'); hold on;
    plot(log2.t, log2.int_angle, 'r');
    grid on; ylabel('rad·s'); title('angle-I'); legend('D1','D2');
    subplot(3,2,6);
    plot(log1.t, rad2deg(log1.de_trim), 'k'); hold on;
    plot(log2.t, rad2deg(log2.de_trim), 'r--');
    plot(log1.t, rad2deg(log1.delta_e_angle_I), 'b');
    plot(log2.t, rad2deg(log2.delta_e_angle_I), 'm');
    grid on; xlabel('t'); ylabel('deg'); title('\delta e_{trim} / \delta e_{angle I}');
    legend('trim D1','trim D2','I→de D1','I→de D2');
    exportgraphics(fig, fpath, 'Resolution', 140); close(fig);
end

%% ===================== markdown =====================
function write_diag_md(md_path, R)
    fid = fopen(md_path, 'w');
    fprintf(fid, '# T25_DIAG — Tur 2.5 Pitch Bias Decision Tree\n\n');
    fprintf(fid, 'Frozen: dt_c=%.4f, dt_g=%.4f, tau_rate=%.4f, Ki_rate=%.3f, NO Muw-FF / circle r_ff / XZ redesign.\n\n', ...
        R.freeze.dt_controller, R.freeze.dt_guidance, R.freeze.tau_rate, R.freeze.Ki_rate);
    fprintf(fid, 'Current trim u=[%s] de_deg=[%s]  elevator_sign=%+d  Ki_angle=%.3f\n\n', ...
        num2str(R.freeze.trim_speed,'%.1f '), num2str(R.freeze.trim_de_deg,'%+.2f '), ...
        R.freeze.elevator_sign, R.freeze.Ki_angle);

    fprintf(fid, '## Test A — Pure level (guidance OFF, pitch_ref=0)\n\n');
    fprintf(fid, '| u | mean eθ | mean\\|e\\| | RMS e | θ_phys | de_trim | de_angle_I | I min/max | w | chatter | suggested trim |\n');
    fprintf(fid, '|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|\n');
    for i = 1:numel(R.A)
        a = R.A(i);
        fprintf(fid, '| %.1f | %+.3f | %.3f | %.3f | %+.3f | %+.3f | %+.3f | %.3f / %.3f | %.4f | %.4f | %+.3f |\n', ...
            a.u_req, a.mean_e_theta_deg, a.mean_abs_e_deg, a.rms_e_deg, a.theta_phys_mean_deg, ...
            a.mean_de_trim_deg, a.mean_delta_e_angle_I_deg, a.angle_I_min, a.angle_I_max, ...
            a.w_mean, a.pitch_chatter_dps, a.suggested_de_trim_deg);
    end

    fprintf(fid, '\n## Test B — Pitch ref symmetry @ u=2.0\n\n');
    fprintf(fid, '| pref | mean e | settle s | OS | I_ss | mean de | chatter |\n|---:|---:|---:|---:|---:|---:|---:|\n');
    for i = 1:numel(R.B)
        b = R.B(i);
        fprintf(fid, '| %+.1f | %+.3f | %.2f | %.2f | %.3f | %+.3f | %.4f |\n', ...
            b.pitch_ref_cmd_deg, b.mean_e_theta_deg, b.settle_s, b.overshoot_deg, ...
            b.angle_I_ss, b.mean_delta_e_deg, b.pitch_chatter_dps);
    end

    fprintf(fid, '\n## Test C — Ki_angle ablation (level, u=2.0)\n\n');
    fprintf(fid, '| case | Ki | mean e | mean\\|e\\| | chatter | \\|I\\|_max | de_I |\n|---|---:|---:|---:|---:|---:|---:|\n');
    for i = 1:numel(R.C)
        c = R.C(i);
        fprintf(fid, '| %s | %.3f | %+.3f | %.3f | %.4f | %.3f | %+.3f |\n', ...
            c.tag, c.Ki_angle, c.mean_e_theta_deg, c.mean_abs_e_deg, c.pitch_chatter_dps, ...
            max(abs([c.angle_I_min, c.angle_I_max])), c.mean_delta_e_angle_I_deg);
    end

    fprintf(fid, '\n## Test D — Pure level vs production X-line\n\n');
    d1 = R.D1; d2 = R.D2;
    fprintf(fid, '| | mean eθ | mean\\|e\\| | chatter | de_I | notes |\n|---|---:|---:|---:|---:|---|\n');
    fprintf(fid, '| D1 pure level | %+.3f | %.3f | %.4f | %+.3f | depth-I OFF |\n', ...
        d1.mean_e_theta_deg, d1.mean_abs_e_deg, d1.pitch_chatter_dps, d1.mean_delta_e_angle_I_deg);
    fprintf(fid, '| D2 X-line | %+.3f | %.3f | %.4f | %+.3f | CTE=%.3f depth_e=%.3f pitch_ref_pp=%.2f° |\n', ...
        d2.mean_e_theta_deg, d2.mean_abs_e_deg, d2.pitch_chatter_dps, d2.mean_delta_e_angle_I_deg, ...
        d2.mean_cte, d2.mean_depth_err, d2.pitch_ref_pp_deg);

    fprintf(fid, '\n## Decision tree conclusion\n\n');
    fprintf(fid, '**Branch taken: `%s`**\n\n', R.decision.branch);
    fprintf(fid, '%s\n\n', R.decision.rationale);
    fprintf(fid, 'Next: %s\n\n', R.decision.next);
    fprintf(fid, 'Suggested trim table (deg) for 2.5.1:\n\n');
    fprintf(fid, '| u | current | suggested |\n|---:|---:|---:|\n');
    for i = 1:numel(R.decision.suggested_speeds)
        u = R.decision.suggested_speeds(i);
        cur = interp1(R.freeze.trim_speed, R.freeze.trim_de_deg, u, 'linear', 'extrap');
        fprintf(fid, '| %.1f | %+.3f | %+.3f |\n', u, cur, rad2deg(R.decision.suggested_de_rad(i)));
    end

    fprintf(fid, '\n### Acceptance targets\n\n');
    fprintf(fid, '- Pure level after settle: |mean eθ|<0.3°, mean|e|<0.5°, chatter≤0.15 °/s, no sat, I not pegged\n');
    fprintf(fid, '- X-line: mean|eθ|<0.7°, CTE worsen ≤5%%, chatter≤0.15\n');
    fprintf(fid, '- If pure OK but X bad → guidance depth-I cause; do NOT thrash pitch gains\n\n');
    fprintf(fid, '### Plots\n\n- `T25_testA_level.png`\n- `T25_testB_symmetry.png`\n- `T25_testC_Ki_ablation.png`\n- `T25_testD_compare.png`\n');
    fclose(fid);
end
