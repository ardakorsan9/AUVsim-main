function run_rudder_monitor_noise_delay_stress()
% RUDDER_MONITOR_NOISE_DELAY_STRESS_001
% Stress frozen causal B2 monitor under synthetic async sensor corruption.
% Read-only provenance:
%   isolated_online_rudder_residual_monitor.m
%   suite_results/ISOLATED_ONLINE_RUDDER_RESIDUAL_MONITOR.mat
%   suite_results/CURRENT_OBSERVER_{NOISE,BIAS_LATENCY}.md (DVL assumptions)
% Replay streams (same provenance as isolated monitor; no NL rerun):
%   feasibility R.TN nominal + RUDDER_FAULT_BASELINE 50% fault logs.
% NO threshold retune. Production cascade+guidance+plant FROZEN.
% Never feed applied rudder / effectiveness / fault labels to monitor.
% Deployment remains NOT_CERTIFIED even if robustness PASS (single path/
%   speed/current/fault magnitude).
% Artifacts: suite_results/RUDDER_MONITOR_NOISE_DELAY_STRESS.{md,mat,png}
% Appends suite_results/PITCH_CONTROL_RESEARCH_LOG.md
% Does NOT touch CODEX_VERTICAL_PLAN.md.

    project_dir = fileparts(fileparts(fileparts(mfilename('fullpath')))); % repo root
    addpath(genpath(fullfile(project_dir, 'matlab')));
    out_dir = fullfile(project_dir, 'suite_results');
    if ~exist(out_dir, 'dir'); mkdir(out_dir); end
    tag = 'RUDDER_MONITOR_NOISE_DELAY_STRESS';
    task_id = 'RUDDER_MONITOR_NOISE_DELAY_STRESS_001';
    stamp = datestr(now, 'yyyy-mm-dd HH:MM:SS');

    mon_mat   = fullfile(out_dir, 'ISOLATED_ONLINE_RUDDER_RESIDUAL_MONITOR.mat');
    feas_mat  = fullfile(out_dir, 'RUDDER_RESIDUAL_DETECTOR_FEASIBILITY.mat');
    fault_mat = fullfile(out_dir, 'RUDDER_FAULT_BASELINE.mat');
    assert(exist(mon_mat, 'file') == 2, 'Missing %s', mon_mat);
    assert(exist(feas_mat, 'file') == 2, 'Missing %s', feas_mat);
    assert(exist(fault_mat, 'file') == 2, 'Missing %s', fault_mat);
    assert(exist('isolated_online_rudder_residual_monitor', 'file') == 2, ...
        'Missing isolated_online_rudder_residual_monitor.m');

    fprintf('\n========== %s ==========\n', task_id);
    fprintf('Frozen B2 noise/delay stress; no retune; production frozen.\n');

    Mon = load(mon_mat);
    Feas = load(feas_mat);
    Fault = load(fault_mat);
    assert(isfield(Mon, 'frozen') && isfield(Mon, 'score'), 'ISOLATED MAT incomplete');
    frozen = Mon.frozen;
    assert(~frozen.retuned, 'Frozen params must not be retuned');
    tf = Mon.score.t_fault_s;

    % ----- Replay streams (ASSUMED-direct plant truth → sensor map) -----
    TN = Feas.R.TN;
    SF = Fault.S;
    nom = struct('t', TN.t(:), 'delta_r_cmd', TN.dr_cmd(:), ...
        'r', TN.r(:), 'u', TN.u(:), 'source', 'feasibility.R.TN (HELIX_R10)');
    fault = struct('t', SF.t(:), 'delta_r_cmd', SF.delta_r_cmd(:), ...
        'r', SF.rates(:, 3), 'u', SF.vel(:, 1), ...
        't_fault_s', SF.t_fault_s, 'source', 'RUDDER_FAULT_BASELINE.mat');
    assert(abs(fault.t_fault_s - tf) < 1e-12, 't_fault mismatch vs ISOLATED MAT');
    assert(abs(frozen.dt - SF.dt) < 1e-12, 'dt mismatch');

    % =====================================================================
    % Sensor corruption envelopes
    % DVL: reuse CURRENT_OBSERVER_NOISE + BIAS_LATENCY exactly (surge axis)
    % IMU yaw-rate: ABSENT in CURRENT_OBSERVER docs → one ASSUMED envelope
    % =====================================================================
    sens = struct();
    sens.dvl_source = 'CURRENT_OBSERVER_NOISE + CURRENT_OBSERVER_BIAS_LATENCY (exact)';
    sens.dvl_sigma_mps = 0.010;          % m/s / axis @ 5 Hz ZOH
    sens.dvl_fs_hz = 5;
    sens.dvl_bias_mps = +0.005;          % BODY-x (surge) from [+0.005,0,-0.003]
    sens.dvl_latency_s = 0.200;          % 200 ms
    sens.dvl_note = [ ...
        'DVL Vw_BODY σ=0.010 m/s/axis @ 5 Hz ZOH; bias BODY-x=+0.005 m/s; ', ...
        'latency=200 ms; causal timestamp/ZOH (last update with t_u<=t-latency).'];

    sens.imu_status = 'ASSUMED';
    sens.imu_note = [ ...
        'ASSUMED stress envelope (NOT a hardware spec): IMU yaw-rate assumptions ', ...
        'absent from CURRENT_OBSERVER noise/bias/latency reports; one conservative ', ...
        'declared synthetic envelope for this stress only.'];
    sens.imu_sigma_degs = 0.20;          % deg/s white @ fs
    sens.imu_sigma_rads = deg2rad(sens.imu_sigma_degs);
    sens.imu_fs_hz = 100;
    sens.imu_bias_degs = +0.05;          % deg/s
    sens.imu_bias_rads = deg2rad(sens.imu_bias_degs);
    sens.imu_latency_s = 0.050;          % 50 ms
    sens.cmd_corrupt = false;            % delta_r_cmd is known command (clean)
    sens.delay_model = 'causal_timestamp_ZOH';
    sens.independent_channels = true;

    % Fixed published seeds (N=40 → binomial Pd/FA estimates)
    seeds = (1001:1040).';
    n_seeds = numel(seeds);
    sens.seeds = seeds;
    sens.n_seeds = n_seeds;
    sens.seed_policy = 'fixed published list 1001:1040 (twister)';

    % Robustness gates (frozen params)
    gates = struct();
    gates.Pd_min = 0.95;
    gates.delay_p95_max_s = 3.0;
    gates.FA_sample_max_pct = 1.0;   % aggregate nominal latched FA samples

    % =====================================================================
    % Multi-seed stress
    % =====================================================================
    per = repmat(struct( ...
        'seed', NaN, ...
        'nom_FA_latched_pct', NaN, ...
        'nom_FA_persist_pct', NaN, ...
        'nom_n_latched', NaN, ...
        'nom_n_post', NaN, ...
        'nom_resid_med', NaN, ...
        'nom_resid_p95', NaN, ...
        'detected', false, ...
        'missed', true, ...
        'alarm_before_fault', false, ...
        't_detect_s', NaN, ...
        'delay_s', NaN, ...
        'fault_resid_med_post', NaN, ...
        'fault_resid_p95_post', NaN), n_seeds, 1);

    % Aggregate residual pools (gated, post-warmup)
    resid_nom_all = [];
    resid_fault_post_all = [];
    n_latched_nom_tot = 0;
    n_post_nom_tot = 0;
    n_persist_nom_tot = 0;

    % Keep one example seed series for plot (first seed)
    ex = struct();

    for i = 1:n_seeds
        seed = seeds(i);
        rng(seed, 'twister');

        [uN, rN, metaN] = corrupt_sensors(nom.t, nom.u, nom.r, sens);
        [uF, rF, metaF] = corrupt_sensors(fault.t, fault.u, fault.r, sens);

        streamN = struct('t', nom.t, 'delta_r_cmd', nom.delta_r_cmd, ...
            'r', rN, 'u', uN);
        streamF = struct('t', fault.t, 'delta_r_cmd', fault.delta_r_cmd, ...
            'r', rF, 'u', uF);

        monN = isolated_online_rudder_residual_monitor('init', frozen);
        [logN, ~] = replay_stream(monN, streamN);
        monF = isolated_online_rudder_residual_monitor('init', frozen);
        [logF, ~] = replay_stream(monF, streamF);

        % --- Nominal FA (post-warmup samples) ---
        mask_w = logN.t > frozen.t_warmup_s;
        n_post = sum(mask_w);
        n_latched = sum(mask_w & logN.alarm);
        gate_N = mask_w & (abs(nom.delta_r_cmd) > frozen.eps_dr_rad);
        det_persist = persist_on((logN.residual > frozen.thr_B2) & gate_N, frozen.Np);
        n_persist = sum(mask_w & det_persist);
        resid_g = logN.residual(gate_N & isfinite(logN.residual));

        per(i).seed = seed;
        per(i).nom_n_post = n_post;
        per(i).nom_n_latched = n_latched;
        per(i).nom_FA_latched_pct = 100 * n_latched / max(n_post, 1);
        per(i).nom_FA_persist_pct = 100 * n_persist / max(n_post, 1);
        if ~isempty(resid_g)
            per(i).nom_resid_med = median(resid_g);
            per(i).nom_resid_p95 = prctile(resid_g, 95);
            resid_nom_all = [resid_nom_all; resid_g]; %#ok<AGROW>
        end
        n_latched_nom_tot = n_latched_nom_tot + n_latched;
        n_post_nom_tot = n_post_nom_tot + n_post;
        n_persist_nom_tot = n_persist_nom_tot + n_persist;

        % --- Fault detection (labels post-hoc only) ---
        before = logF.t < tf;
        after = logF.t >= tf;
        per(i).alarm_before_fault = any(logF.alarm(before));
        idx_det = find(logF.newly_alarmed & after, 1, 'first');
        if isempty(idx_det)
            % also accept already-latched crossing at/after fault
            idx_det = find(logF.alarm & after, 1, 'first');
        end
        if ~isempty(idx_det) && ~per(i).alarm_before_fault
            per(i).detected = true;
            per(i).missed = false;
            per(i).t_detect_s = logF.t(idx_det);
            per(i).delay_s = per(i).t_detect_s - tf;
        elseif per(i).alarm_before_fault
            % pre-fault latch counts as FA contamination; treat as miss for Pd
            per(i).detected = false;
            per(i).missed = true;
            per(i).t_detect_s = NaN;
            per(i).delay_s = NaN;
        else
            per(i).detected = false;
            per(i).missed = true;
            per(i).t_detect_s = NaN;
            per(i).delay_s = NaN;
        end

        gate_Fp = after & (abs(fault.delta_r_cmd) > frozen.eps_dr_rad) ...
            & isfinite(logF.residual);
        resid_fp = logF.residual(gate_Fp);
        if ~isempty(resid_fp)
            per(i).fault_resid_med_post = median(resid_fp);
            per(i).fault_resid_p95_post = prctile(resid_fp, 95);
            resid_fault_post_all = [resid_fault_post_all; resid_fp]; %#ok<AGROW>
        end

        if i == 1
            ex.seed = seed;
            ex.logN = logN;
            ex.logF = logF;
            ex.metaN = metaN;
            ex.metaF = metaF;
            ex.uN = uN; ex.rN = rN;
            ex.uF = uF; ex.rF = rF;
            ex.uN_truth = nom.u; ex.rN_truth = nom.r;
            ex.uF_truth = fault.u; ex.rF_truth = fault.r;
        end

        fprintf('  seed=%d  FA_latched=%.3f%%  detected=%d  delay=%s\n', ...
            seed, per(i).nom_FA_latched_pct, per(i).detected, ...
            tern(isfinite(per(i).delay_s), sprintf('%.3fs', per(i).delay_s), 'NaN'));
    end

    % =====================================================================
    % Aggregate
    % =====================================================================
    det_flags = [per.detected];
    miss_flags = [per.missed];
    delays = [per.delay_s];
    delays_ok = delays(det_flags & isfinite(delays));
    n_det = sum(det_flags);
    n_miss = sum(miss_flags);
    Pd = n_det / n_seeds;
    if isempty(delays_ok)
        delay_med = NaN;
        delay_p95 = NaN;
    else
        delay_med = median(delays_ok);
        delay_p95 = prctile(delays_ok, 95);
    end
    FA_agg_latched_pct = 100 * n_latched_nom_tot / max(n_post_nom_tot, 1);
    FA_agg_persist_pct = 100 * n_persist_nom_tot / max(n_post_nom_tot, 1);
    n_prefault_alarm = sum([per.alarm_before_fault]);

    resid_nom_stats = resid_stats(resid_nom_all);
    resid_fault_stats = resid_stats(resid_fault_post_all);

    g_Pd = (Pd >= gates.Pd_min);
    g_delay = isfinite(delay_p95) && (delay_p95 <= gates.delay_p95_max_s);
    g_FA = (FA_agg_latched_pct <= gates.FA_sample_max_pct);
    robustness_pass = g_Pd && g_delay && g_FA;
    if robustness_pass
        robustness_verdict = 'PASS';
    else
        robustness_verdict = 'FAIL';
    end

    % Deployment always NOT_CERTIFIED (single path/speed/current/fault mag)
    cert = struct();
    cert.status = 'NOT_CERTIFIED';
    cert.reasons = { ...
        'Single path only (HELIX_R10)'; ...
        'Single speed only (U≈1.5 m/s)'; ...
        'Single current condition (fault-baseline / feasibility traj)'; ...
        'Single fault magnitude only (eta_r:1→0.50)'; ...
        'IMU yaw-rate envelope ASSUMED (not hardware-validated)'; ...
        'Synthetic DVL corruption from CURRENT_OBSERVER docs (not hardware)'};
    if robustness_pass
        next_priority = 'fault_magnitude_speed_coverage';
        next_note = [ ...
            'Robustness PASS → next: fault-magnitude/speed coverage; ', ...
            'deployment still NOT_CERTIFIED.'];
    else
        next_priority = 'reject_B2_require_actuator_feedback_or_richer_ID';
        next_note = [ ...
            'Robustness FAIL → REJECT B2 monitor; require actuator feedback ', ...
            'and/or richer ID before further promotion.'];
    end

    % Clean-reference (seed-free truth) for residual context
    mon_cN = isolated_online_rudder_residual_monitor('init', frozen);
    [log_cN, ~] = replay_stream(mon_cN, nom);
    mon_cF = isolated_online_rudder_residual_monitor('init', frozen);
    [log_cF, ~] = replay_stream(mon_cF, fault);

    % =====================================================================
    % Pack results
    % =====================================================================
    R = struct();
    R.task_id = task_id;
    R.stamp = stamp;
    R.tag = tag;
    R.frozen = frozen;
    R.frozen_retuned = false;
    R.sensor = sens;
    R.seeds = seeds;
    R.per_seed = per;
    R.aggregate = struct( ...
        'n_seeds', n_seeds, ...
        'Pd', Pd, ...
        'n_detected', n_det, ...
        'n_missed', n_miss, ...
        'n_alarm_before_fault', n_prefault_alarm, ...
        'delay_median_s', delay_med, ...
        'delay_p95_s', delay_p95, ...
        'FA_agg_latched_pct', FA_agg_latched_pct, ...
        'FA_agg_persist_pct', FA_agg_persist_pct, ...
        'n_latched_nom_tot', n_latched_nom_tot, ...
        'n_post_nom_tot', n_post_nom_tot, ...
        'resid_nom', resid_nom_stats, ...
        'resid_fault_post', resid_fault_stats);
    R.gates = gates;
    R.G = struct( ...
        'g_Pd_ge_95', g_Pd, ...
        'g_delay_p95_le_3s', g_delay, ...
        'g_FA_agg_le_1pct', g_FA, ...
        'robustness_pass', robustness_pass, ...
        'robustness_verdict', robustness_verdict, ...
        'next_priority', next_priority, ...
        'next_note', next_note);
    R.cert = cert;
    R.verdict_robustness = robustness_verdict;
    R.verdict_deployment = 'NOT_CERTIFIED';
    R.verdict = robustness_verdict;
    R.t_fault_s = tf;
    R.example = ex;
    R.clean_ref = struct('logN', log_cN, 'logF', log_cF, ...
        'delay_s', Mon.score.delay_s, 'FA_latched_pct', Mon.score.FA_latched_pct);
    R.production_untouched = true;
    R.nonlinear_rerun = false;
    R.labels_fed_to_monitor = false;
    R.sources_read = { ...
        'isolated_online_rudder_residual_monitor.m'; ...
        'suite_results/ISOLATED_ONLINE_RUDDER_RESIDUAL_MONITOR.mat'; ...
        'suite_results/CURRENT_OBSERVER_NOISE.md + CURRENT_OBSERVER_BIAS_LATENCY.md'};
    R.stream_sources = {nom.source; fault.source};

    mat_path = fullfile(out_dir, [tag '.mat']);
    png_path = fullfile(out_dir, [tag '.png']);
    md_path  = fullfile(out_dir, [tag '.md']);
    save(mat_path, 'R', 'frozen', 'sens', 'per', 'gates', 'cert', '-v7.3');

    write_png(png_path, R, nom, fault, frozen);
    write_md(md_path, R);
    append_log(out_dir, R);

    fprintf('\n--- %s ---\n', task_id);
    fprintf('Robustness: %s | Deployment: NOT_CERTIFIED\n', robustness_verdict);
    fprintf('Pd=%.1f%% (%d/%d)  delay med/p95=%.3f/%.3f s  FA_agg_latched=%.4f%%\n', ...
        100*Pd, n_det, n_seeds, delay_med, delay_p95, FA_agg_latched_pct);
    fprintf('Gates: Pd>=95%%=%d  p95delay<=3s=%d  FA<=1%%=%d\n', g_Pd, g_delay, g_FA);
    fprintf('Next: %s\n', next_priority);
    fprintf('Saved %s\n', mat_path);
    fprintf('Saved %s\n', png_path);
    fprintf('Saved %s\n', md_path);
end

%% ========================================================================
function [u_out, r_out, meta] = corrupt_sensors(t, u_truth, r_truth, sens)
% Causal async ZOH noise+bias+latency on DVL surge and IMU yaw-rate.
% delta_r_cmd not corrupted (known command).
    t = t(:);
    u_truth = u_truth(:);
    r_truth = r_truth(:);

    [u_out, t_dvl_src, t_dvl_avail, n_dvl] = async_zoh_corrupt( ...
        t, u_truth, sens.dvl_fs_hz, sens.dvl_sigma_mps, ...
        sens.dvl_bias_mps, sens.dvl_latency_s);

    [r_out, t_imu_src, t_imu_avail, n_imu] = async_zoh_corrupt( ...
        t, r_truth, sens.imu_fs_hz, sens.imu_sigma_rads, ...
        sens.imu_bias_rads, sens.imu_latency_s);

    meta = struct();
    meta.t_dvl_src = t_dvl_src;
    meta.t_dvl_avail = t_dvl_avail;
    meta.n_dvl = n_dvl;
    meta.t_imu_src = t_imu_src;
    meta.t_imu_avail = t_imu_avail;
    meta.n_imu = n_imu;
end

function [y_hold, t_src, t_avail, n_upd] = async_zoh_corrupt(t, y_truth, fs, sigma, bias, latency_s)
% Native updates at fs; each sample = truth(t_src)+bias+sigma*randn.
% At consumer time t_k use last update with t_avail<=t_k where
% t_avail = t_src + latency (causal; no future).
    t = t(:);
    y_truth = y_truth(:);
    t0 = t(1);
    t1 = t(end);
    dt_u = 1 / fs;
    t_src = (t0:dt_u:t1).';
    if isempty(t_src) || t_src(end) < t1 - 1e-12
        % ensure coverage to end
        if isempty(t_src)
            t_src = t0;
        end
    end
    n_upd = numel(t_src);
    % Interpolate truth at native source times (causal: clamp to grid)
    y_src = interp1(t, y_truth, t_src, 'linear', 'extrap') + bias + sigma * randn(n_upd, 1);
    t_avail = t_src + latency_s;

    y_hold = nan(size(t));
    j = 0;  % last available index
    for k = 1:numel(t)
        while (j < n_upd) && (t_avail(j + 1) <= t(k) + 1e-15)
            j = j + 1;
        end
        if j >= 1
            y_hold(k) = y_src(j);
        else
            % before first packet available: hold first truth+bias (no noise peek)
            y_hold(k) = y_truth(1) + bias;
        end
    end
end

function [log, mon] = replay_stream(mon, stream)
    n = numel(stream.t);
    log = struct();
    log.t = nan(n, 1);
    log.residual = nan(n, 1);
    log.g_hat = nan(n, 1);
    log.valid = false(n, 1);
    log.warmed = false(n, 1);
    log.gated = false(n, 1);
    log.above = false(n, 1);
    log.persist_count = zeros(n, 1);
    log.alarm = false(n, 1);
    log.alarm_raw_persist = false(n, 1);
    log.newly_alarmed = false(n, 1);
    log.t_alarm_s = NaN;
    for k = 1:n
        sample = struct( ...
            't', stream.t(k), ...
            'delta_r_cmd', stream.delta_r_cmd(k), ...
            'r', stream.r(k), ...
            'u', stream.u(k));
        [mon, out] = isolated_online_rudder_residual_monitor('update', mon, sample);
        log.t(k) = out.t;
        log.residual(k) = out.residual;
        log.g_hat(k) = out.g_hat;
        log.valid(k) = out.valid;
        log.warmed(k) = out.warmed;
        log.gated(k) = out.gated;
        log.above(k) = out.above;
        log.persist_count(k) = out.persist_count;
        log.alarm(k) = out.alarm;
        log.alarm_raw_persist(k) = out.alarm_raw_persist;
        log.newly_alarmed(k) = out.newly_alarmed;
    end
    log.t_alarm_s = mon.t_alarm_s;
    log.alarm_latched_final = mon.alarm_latched;
end

function det = persist_on(above, Np)
    det = false(size(above));
    c = 0;
    for k = 1:numel(above)
        if above(k)
            c = c + 1;
        else
            c = 0;
        end
        det(k) = (c >= Np);
    end
end

function s = resid_stats(x)
    s = struct('n', 0, 'median', NaN, 'mean', NaN, 'p95', NaN, 'max', NaN);
    x = x(isfinite(x));
    s.n = numel(x);
    if s.n == 0; return; end
    s.median = median(x);
    s.mean = mean(x);
    s.p95 = prctile(x, 95);
    s.max = max(x);
end

function s = tern(c, a, b)
    if c; s = a; else; s = b; end
end

%% ========================================================================
function write_png(png_path, R, nom, fault, frozen)
    tf = R.t_fault_s;
    ex = R.example;
    fig = figure('Visible', 'off', 'Position', [80 60 1280 900]);

    subplot(3, 2, 1);
    plot(nom.t, nom.u, 'k-', 'LineWidth', 0.8); hold on;
    plot(nom.t, ex.uN, 'b-', 'LineWidth', 0.6);
    ylabel('u [m/s]'); title(sprintf('DVL surge (seed %d nominal)', ex.seed));
    legend('truth', 'corrupt ZOH', 'Location', 'best'); grid on;

    subplot(3, 2, 2);
    plot(nom.t, rad2deg(nom.r), 'k-', 'LineWidth', 0.8); hold on;
    plot(nom.t, rad2deg(ex.rN), 'r-', 'LineWidth', 0.6);
    ylabel('r [deg/s]'); title(sprintf('IMU yaw-rate ASSUMED (seed %d)', ex.seed));
    legend('truth', 'corrupt ZOH', 'Location', 'best'); grid on;

    subplot(3, 2, 3);
    plot(ex.logN.t, ex.logN.residual, 'b-'); hold on;
    plot(ex.logF.t, ex.logF.residual, 'r-');
    yline(frozen.thr_B2, 'k--');
    xline(tf, 'm-.');
    ylabel('r_{B2}'); title('Residual (example seed)'); grid on;
    legend('nom', 'fault', 'thr', 't_f', 'Location', 'best');

    subplot(3, 2, 4);
    plot(ex.logN.t, ex.logN.alarm, 'b-'); hold on;
    plot(ex.logF.t, double(ex.logF.alarm), 'r-');
    xline(tf, 'm-.');
    ylim([-0.05 1.05]); ylabel('alarm'); title('Latched alarm'); grid on;

    subplot(3, 2, 5);
    bar([R.per_seed.nom_FA_latched_pct], 0.8);
    hold on; yline(R.gates.FA_sample_max_pct, 'r--');
    xlabel('seed index'); ylabel('FA latched %');
    title(sprintf('Per-seed nominal FA (agg=%.3f%%)', R.aggregate.FA_agg_latched_pct));
    grid on;

    subplot(3, 2, 6);
    dly = [R.per_seed.delay_s];
    dly = dly(isfinite(dly));
    if isempty(dly); dly = nan; end
    histogram(dly, 12);
    hold on;
    xline(R.gates.delay_p95_max_s, 'r--');
    if isfinite(R.aggregate.delay_p95_s)
        xline(R.aggregate.delay_p95_s, 'g-', 'LineWidth', 1.2);
    end
    xlabel('delay [s]'); ylabel('count');
    title(sprintf('Detect delay (Pd=%.1f%% p95=%.3fs) [%s]', ...
        100*R.aggregate.Pd, R.aggregate.delay_p95_s, R.verdict_robustness));
    grid on;

    sgtitle(sprintf('%s — %s (deploy NOT_CERTIFIED)', R.task_id, R.verdict_robustness), ...
        'Interpreter', 'none');
    exportgraphics(fig, png_path, 'Resolution', 120);
    close(fig);
end

function write_md(md_path, R)
    fid = fopen(md_path, 'w');
    assert(fid > 0, 'Cannot write %s', md_path);
    fr = R.frozen;
    s = R.sensor;
    a = R.aggregate;

    fprintf(fid, '# RUDDER_MONITOR_NOISE_DELAY_STRESS\n\n');
    fprintf(fid, '**TASK_ID:** %s\n', R.task_id);
    fprintf(fid, '**Date:** %s\n', R.stamp);
    fprintf(fid, '**Robustness verdict:** **%s**\n', R.verdict_robustness);
    fprintf(fid, '**Deployment certification:** **NOT_CERTIFIED**\n\n');
    fprintf(fid, ['Stress frozen causal B2 monitor via async sensor sampling / ZOH / ', ...
        'noise / bias / latency replay. No nonlinear rerun. No threshold retune. ', ...
        'Production cascade+guidance+plant **frozen**.\n\n']);

    fprintf(fid, '## Sources (read-only)\n\n');
    fprintf(fid, '1. `isolated_online_rudder_residual_monitor.m`\n');
    fprintf(fid, '2. `suite_results/ISOLATED_ONLINE_RUDDER_RESIDUAL_MONITOR.mat`\n');
    fprintf(fid, '3. `suite_results/CURRENT_OBSERVER_NOISE.md` + `CURRENT_OBSERVER_BIAS_LATENCY.md`\n');
    fprintf(fid, 'Replay streams: `%s` | `%s`\n\n', R.stream_sources{1}, R.stream_sources{2});

    fprintf(fid, '## Frozen B2 parameters (NO retune)\n\n');
    fprintf(fid, '| Item | Value |\n|---|---:|\n');
    fprintf(fid, '| G_nom [1/(m^2·rad)] | %.6f |\n', fr.G_nom);
    fprintf(fid, '| thr_B2 [frac] | %.6f |\n', fr.thr_B2);
    fprintf(fid, '| \\|δr\\|_gate [deg] | %.1f |\n', rad2deg(fr.eps_dr_rad));
    fprintf(fid, '| u_floor [m/s] | %.2f |\n', fr.u_floor);
    fprintf(fid, '| Warmup | t > %.1f s |\n', fr.t_warmup_s);
    fprintf(fid, '| Persistence | %.2f s (Np=%d @ dt=%.3f) |\n', fr.persist_s, fr.Np, fr.dt);
    fprintf(fid, '| Retuned | NO |\n');
    fprintf(fid, '| Forbidden to monitor | δr_app / η_r / fault labels |\n\n');

    fprintf(fid, '## Input corruption parameters\n\n');
    fprintf(fid, '### DVL surge u (REUSED from CURRENT_OBSERVER — exact)\n\n');
    fprintf(fid, '```\n');
    fprintf(fid, 'DVL Vw_BODY-x: σ=%.3f m/s @ %.0f Hz ZOH\n', s.dvl_sigma_mps, s.dvl_fs_hz);
    fprintf(fid, 'bias = %+.3f m/s (BODY-x from [+0.005, 0, -0.003])\n', s.dvl_bias_mps);
    fprintf(fid, 'latency = %.0f ms\n', 1000*s.dvl_latency_s);
    fprintf(fid, 'Delay: causal timestamp/ZOH (last update with t_u <= t - latency)\n');
    fprintf(fid, '```\n\n');

    fprintf(fid, '### IMU yaw-rate r (**ASSUMED** stress envelope — NOT hardware spec)\n\n');
    fprintf(fid, '%s\n\n', s.imu_note);
    fprintf(fid, '```\n');
    fprintf(fid, 'IMU r: σ=%.2f deg/s (= %.6e rad/s) @ %.0f Hz ZOH\n', ...
        s.imu_sigma_degs, s.imu_sigma_rads, s.imu_fs_hz);
    fprintf(fid, 'bias = %+.2f deg/s (= %+.6e rad/s)\n', s.imu_bias_degs, s.imu_bias_rads);
    fprintf(fid, 'latency = %.0f ms\n', 1000*s.imu_latency_s);
    fprintf(fid, 'Delay: causal timestamp/ZOH (same model as DVL)\n');
    fprintf(fid, '```\n\n');
    fprintf(fid, '- `delta_r_cmd`: known command — **not** corrupted.\n');
    fprintf(fid, '- Channels independent; `%s`.\n', s.delay_model);
    fprintf(fid, '- Seeds: **%s** (N=%d).\n\n', s.seed_policy, s.n_seeds);

    fprintf(fid, '## Aggregate metrics\n\n');
    fprintf(fid, '| Metric | Value | Gate | Result |\n|--------|------:|------|:------:|\n');
    fprintf(fid, '| Detection probability Pd | %.1f%% (%d/%d) | ≥95%% | %s |\n', ...
        100*a.Pd, a.n_detected, a.n_seeds, yn(R.G.g_Pd_ge_95));
    fprintf(fid, '| Delay median [s] | %.3f | — | — |\n', a.delay_median_s);
    fprintf(fid, '| Delay p95 [s] | %.3f | ≤3.0 | %s |\n', ...
        a.delay_p95_s, yn(R.G.g_delay_p95_le_3s));
    fprintf(fid, '| Misses | %d | — | — |\n', a.n_missed);
    fprintf(fid, '| Prefault alarms (fault runs) | %d | — | — |\n', a.n_alarm_before_fault);
    fprintf(fid, '| Agg nominal FA latched samples | %.4f%% (%d/%d) | ≤1%% | %s |\n', ...
        a.FA_agg_latched_pct, a.n_latched_nom_tot, a.n_post_nom_tot, yn(R.G.g_FA_agg_le_1pct));
    fprintf(fid, '| Agg nominal FA persist samples | %.4f%% | report | — |\n', a.FA_agg_persist_pct);
    fprintf(fid, '| **Robustness** | **%s** | all three | **%s** |\n', ...
        R.verdict_robustness, yn(R.G.robustness_pass));
    fprintf(fid, '| **Deployment** | **NOT_CERTIFIED** | — | — |\n\n');

    fprintf(fid, '### Residual distributions (gated)\n\n');
    fprintf(fid, '| Pool | n | median | mean | p95 | max |\n|------|--:|-------:|-----:|----:|----:|\n');
    rn = a.resid_nom; rf = a.resid_fault_post;
    fprintf(fid, '| Nominal (all seeds) | %d | %.4f | %.4f | %.4f | %.4f |\n', ...
        rn.n, rn.median, rn.mean, rn.p95, rn.max);
    fprintf(fid, '| Fault post-t_f (all seeds) | %d | %.4f | %.4f | %.4f | %.4f |\n\n', ...
        rf.n, rf.median, rf.mean, rf.p95, rf.max);

    fprintf(fid, '## Per-seed table\n\n');
    fprintf(fid, '| seed | FA_latched%% | FA_persist%% | detected | delay[s] | miss | prefault | resid_nom_med | resid_f_post_med |\n');
    fprintf(fid, '|-----:|------------:|-------------:|:--------:|---------:|:----:|:--------:|--------------:|-----------------:|\n');
    for i = 1:numel(R.per_seed)
        p = R.per_seed(i);
        fprintf(fid, '| %d | %.3f | %.3f | %s | %s | %s | %s | %.4f | %.4f |\n', ...
            p.seed, p.nom_FA_latched_pct, p.nom_FA_persist_pct, ...
            yn(p.detected), num_or_nan(p.delay_s), yn(p.missed), yn(p.alarm_before_fault), ...
            p.nom_resid_med, p.fault_resid_med_post);
    end
    fprintf(fid, '\n');

    fprintf(fid, '## Clean reference (no corruption)\n\n');
    fprintf(fid, '- Isolated-monitor clean delay=%.3f s, FA_latched=%.3f%% (from prior MAT).\n\n', ...
        R.clean_ref.delay_s, R.clean_ref.FA_latched_pct);

    fprintf(fid, '## Deployment NOT_CERTIFIED reasons\n\n');
    for i = 1:numel(R.cert.reasons)
        fprintf(fid, '- %s\n', R.cert.reasons{i});
    end
    fprintf(fid, '\n');

    fprintf(fid, '## Next\n\n');
    fprintf(fid, '- **`%s`** — %s\n\n', R.G.next_priority, R.G.next_note);

    fprintf(fid, '## Files\n\n');
    fprintf(fid, '- `run_rudder_monitor_noise_delay_stress.m` (isolated runner)\n');
    fprintf(fid, '- `suite_results/RUDDER_MONITOR_NOISE_DELAY_STRESS.md`\n');
    fprintf(fid, '- `suite_results/RUDDER_MONITOR_NOISE_DELAY_STRESS.mat`\n');
    fprintf(fid, '- `suite_results/RUDDER_MONITOR_NOISE_DELAY_STRESS.png`\n');
    fprintf(fid, '- Monitor: `isolated_online_rudder_residual_monitor.m` (untouched)\n');
    fprintf(fid, '- Production: controller_law / guidance / plant **unchanged**; CODEX_VERTICAL_PLAN untouched.\n');
    fclose(fid);
end

function append_log(out_dir, R)
    log_path = fullfile(out_dir, 'PITCH_CONTROL_RESEARCH_LOG.md');
    fid = fopen(log_path, 'a');
    assert(fid > 0, 'Cannot append research log');
    a = R.aggregate;
    s = R.sensor;
    fprintf(fid, '\n\n## %s — %s\n\n', R.task_id, R.stamp);
    fprintf(fid, '- Robustness: **%s** — Deployment: **NOT_CERTIFIED** — frozen B2 noise/delay stress; production frozen; no NL rerun; no retune.\n', ...
        R.verdict_robustness);
    fprintf(fid, '- DVL reused: σ=%.3f m/s @ %.0f Hz ZOH, bias=%+.3f m/s, lat=%.0f ms (CURRENT_OBSERVER).\n', ...
        s.dvl_sigma_mps, s.dvl_fs_hz, s.dvl_bias_mps, 1000*s.dvl_latency_s);
    fprintf(fid, '- IMU ASSUMED: σ=%.2f deg/s @ %.0f Hz ZOH, bias=%+.2f deg/s, lat=%.0f ms (not hardware).\n', ...
        s.imu_sigma_degs, s.imu_fs_hz, s.imu_bias_degs, 1000*s.imu_latency_s);
    fprintf(fid, '- Seeds %d:%d (N=%d): Pd=%.1f%% (%d/%d) delay_med/p95=%.3f/%.3f s misses=%d FA_agg_latched=%.4f%%.\n', ...
        R.seeds(1), R.seeds(end), a.n_seeds, 100*a.Pd, a.n_detected, a.n_seeds, ...
        a.delay_median_s, a.delay_p95_s, a.n_missed, a.FA_agg_latched_pct);
    fprintf(fid, '- Gates: Pd>=95=%s p95delay<=3s=%s FA<=1%%=%s.\n', ...
        yn(R.G.g_Pd_ge_95), yn(R.G.g_delay_p95_le_3s), yn(R.G.g_FA_agg_le_1pct));
    fprintf(fid, '- Artifacts: suite_results/RUDDER_MONITOR_NOISE_DELAY_STRESS.{md,mat,png}; driver `run_rudder_monitor_noise_delay_stress.m`.\n');
    fprintf(fid, '- Next: **`%s`** — %s\n', R.G.next_priority, R.G.next_note);
    fprintf(fid, '- CODEX_VERTICAL_PLAN untouched.\n');
    fclose(fid);
end

function s = yn(v)
    if v; s = 'YES'; else; s = 'NO'; end
end

function s = num_or_nan(x)
    if isfinite(x); s = sprintf('%.3f', x); else; s = 'NaN'; end
end
