function run_current_observer_bias_latency()
% CURRENT_OBSERVER_BIAS_LATENCY_001 — offline INS/DVL bias+latency audit.
% Read-only: run_current_observer_noise.m, suite_results/CURRENT_OBSERVER_NOISE.mat,
%   suite_results/BOUNDED_CURRENT_HOOK.mat.
% Noise-only observer PASS; production plant/controller/guidance + hook FROZEN.
% Observer offline only — never fed to guidance/control; no production promote.
%
% Synthetic TEST ASSUMPTION (not hardware spec), ONE declared case:
%   Retain prior rng(42) additive noise (INS σ=0.020@20Hz ZOH, DVL σ=0.010@5Hz ZOH)
%   INS  Vg_NED  bias=[+0.010, -0.005, +0.005] m/s, latency=50 ms
%   DVL  Vw_BODY bias=[+0.005,  0.000, -0.003] m/s, latency=200 ms
% Causal timestamp/ZOH delay: at t use last native update with t_u <= t - latency.
% SIMPLIFYING ASSUMPTION: rotate delayed DVL BODY sample with CURRENT truth R
%   (not delayed attitude). Documented; not a hardware claim.
% Same observer (no tuning): dVhat/dt = wo*(y_c-Vhat), wo=0.50 rad/s, bound ±0.5
% Routes: X / XZ / R10 @ Vc=[0,0.15,0] using saved hook trajectories.
% PASS (this declared bias+latency case only): steady vector bias<=0.030,
%   RMSE<=0.035, p95<=0.070, final||err||<=0.050, bounded/no hits, all routes.
% Attitude error / misalignment / lever arm DEFERRED.
% Artifacts: suite_results/CURRENT_OBSERVER_BIAS_LATENCY.{md,mat,png}
% Appends suite_results/STATE_SPACE_MODEL_AUDIT.md
% Does NOT touch CODEX_VERTICAL_PLAN.md.

    project_dir = fileparts(mfilename('fullpath'));
    addpath(project_dir);
    out_dir = fullfile(project_dir, 'suite_results');
    if ~exist(out_dir, 'dir'); mkdir(out_dir); end
    tag = 'CURRENT_OBSERVER_BIAS_LATENCY';
    task_id = 'CURRENT_OBSERVER_BIAS_LATENCY_001';

    noise_mat = fullfile(out_dir, 'CURRENT_OBSERVER_NOISE.mat');
    hook_mat  = fullfile(out_dir, 'BOUNDED_CURRENT_HOOK.mat');
    noise_run = fullfile(project_dir, 'run_current_observer_noise.m');
    assert(exist(noise_mat, 'file') == 2, 'Missing %s', noise_mat);
    assert(exist(hook_mat, 'file') == 2, 'Missing %s', hook_mat);
    assert(exist(noise_run, 'file') == 2, 'Missing %s', noise_run);

    fprintf('\n========== %s ==========\n', task_id);
    fprintf('Offline INS/DVL bias+latency; same wo=0.50; no tuning.\n');
    fprintf('TEST ASSUMPTION only — not hardware spec; not production.\n');
    fprintf('SIMPLIFYING ASSUMPTION: delayed DVL BODY rotated by CURRENT truth R.\n');

    Noise = load(noise_mat);
    Hook  = load(hook_mat);
    assert(strcmp(Noise.verdict, 'PASS'), 'CURRENT_OBSERVER_NOISE must be PASS');
    assert(strcmp(Hook.verdict, 'PASS'), 'BOUNDED_CURRENT_HOOK must be PASS');
    assert(isfield(Hook, 'routes') && isfield(Noise, 'routes'), 'Missing routes');

    % ---- Fixed observer (identical to noise/ideal; no retune) ----
    wo = 0.50;
    Vhat0 = [0; 0; 0];
    V_bound = 0.5;
    Vc_true = [0; 0.15; 0];
    settle_frac = 0.02;
    names = {'X', 'XZ', 'R10'};

    % ---- Declared bias+latency case (synthetic; retain noise) ----
    sens = struct();
    sens.assumption = 'synthetic TEST ASSUMPTION — not hardware spec';
    sens.ins_sigma = 0.020;   % m/s / axis (same as noise)
    sens.ins_fs = 20;         % Hz ZOH
    sens.dvl_sigma = 0.010;   % m/s / axis
    sens.dvl_fs = 5;          % Hz ZOH
    sens.ins_bias_ned = [+0.010; -0.005; +0.005];  % m/s
    sens.ins_latency_s = 0.050;                    % 50 ms
    sens.dvl_bias_body = [+0.005; 0.000; -0.003];  % m/s
    sens.dvl_latency_s = 0.200;                    % 200 ms
    sens.independent = true;
    sens.seed = 42;           % retain prior rng(42) noise
    sens.delay_model = 'causal_timestamp_ZOH';
    sens.rotate_dvl_with = 'CURRENT_truth_R_on_delayed_BODY';
    sens.rotate_assumption = [ ...
        'SIMPLIFYING ASSUMPTION: delayed DVL BODY sample is rotated into NED ', ...
        'using the CURRENT truth attitude R(t), not R(t-latency). ', ...
        'This decouples attitude latency from DVL velocity latency for this ', ...
        'declared synthetic case only; not a hardware claim.'];
    sens.y_c = 'Vg_delayed_NED - R_current * Vw_delayed_BODY';

    steady_t0 = 10.0;   % after FO ~5τ (τ=1/wo=2s); post noise settle window

    Results = struct();
    Results.task_id = task_id;
    Results.convention = Noise.convention;
    Results.observer = struct('wo', wo, 'Vhat0', Vhat0, 'bound', V_bound, ...
        'form', 'dVhat/dt = wo*(y_c - Vhat); discrete exact FO; axis clamp ±bound', ...
        'tuning', 'NONE — identical to CURRENT_OBSERVER_NOISE / IDEAL');
    Results.Vc_true = Vc_true;
    Results.Uref = Hook.Uref;
    Results.seed_noise = sens.seed;
    Results.seed_hook = Hook.seed;
    Results.sensor = sens;
    Results.steady_t0 = steady_t0;
    Results.fed_to_control = false;
    Results.production_untouched = true;
    Results.hook_untouched = true;
    Results.noise_untouched = true;
    Results.gain_sweep = false;
    Results.routes = struct();
    Results.noise_ref = struct();

    rng(sens.seed, 'twister');

    all_pass = true;
    for i = 1:numel(names)
        nm = names{i};
        assert(isfield(Hook.routes, nm), 'Missing route %s in hook mat', nm);
        assert(isfield(Noise.routes, nm), 'Missing route %s in noise mat', nm);
        S = Hook.routes.(nm).curr;
        assert(max(abs(S.Vc(:) - Vc_true)) < 1e-12, 'Route %s Vc mismatch', nm);

        Nref = Noise.routes.(nm);
        Obs = run_bias_latency_observer(S, wo, Vhat0, V_bound, Vc_true, settle_frac, ...
            sens, steady_t0);
        Obs.name = nm;
        Obs.compare = compare_to_noise(Obs, Nref, steady_t0);
        Results.routes.(nm) = Obs;
        Results.noise_ref.(nm) = struct( ...
            'steady_bias', Nref.steady.bias, ...
            'steady_bias_norm', Nref.steady.bias_norm, ...
            'steady_rmse_norm', Nref.steady.rmse_norm, ...
            'steady_p95_norm', Nref.steady.p95_norm, ...
            'steady_max_norm', Nref.steady.max_norm, ...
            'err_final_norm', Nref.err_final_norm, ...
            'settle_time', Nref.settle_time, ...
            'bound_hits', Nref.bound_hits, ...
            'psi_range_deg', Nref.psi_range_deg, ...
            'theta_range_deg', Nref.theta_range_deg);

        fprintf('\n--- Route %s (bias+latency) ---\n', nm);
        fprintf('  bias vec ||mean(err)|| steady: %.4e  (gate<=0.030)\n', Obs.steady.bias_norm);
        fprintf('  RMSE ||err|| steady: %.4e  (gate<=0.035)\n', Obs.steady.rmse_norm);
        fprintf('  p95 ||err|| steady: %.4e  (gate<=0.070)\n', Obs.steady.p95_norm);
        fprintf('  final ||err||: %.4e  (gate<=0.050)\n', Obs.err_final_norm);
        fprintf('  settle 2%%: %.3f s  bound hits: %d  max|Vhat|: %.4f\n', ...
            Obs.settle_time, Obs.bound_hits, Obs.Vhat_max_abs);
        fprintf('  component bias [N,E,D]: [%.3e, %.3e, %.3e]\n', Obs.steady.bias);
        fprintf('  innov mean || ||: %.3e  lag1 acorr mean: %.3f\n', ...
            Obs.innov_stats.mean_norm, Obs.innov_stats.acorr_lag1_mean);
        fprintf('  noise→biaslat Δbias: %.3e  ΔRMSE: %.3e  Δfinal: %.3e\n', ...
            Obs.compare.delta_bias_norm, Obs.compare.delta_steady_rmse, ...
            Obs.compare.delta_final_norm);

        all_pass = all_pass && Obs.pass_bias && Obs.pass_rmse && Obs.pass_p95 && ...
            Obs.pass_final && Obs.pass_bounded && Obs.pass_no_hits;
    end

    % Cross-route summary
    bias_max = 0; rmse_max = 0; p95_max = 0; fin_max = 0; hits_tot = 0; set_max = 0;
    max_norm_max = 0;
    for i = 1:numel(names)
        O = Results.routes.(names{i});
        bias_max = max(bias_max, O.steady.bias_norm);
        rmse_max = max(rmse_max, O.steady.rmse_norm);
        p95_max = max(p95_max, O.steady.p95_norm);
        fin_max = max(fin_max, O.err_final_norm);
        hits_tot = hits_tot + O.bound_hits;
        set_max = max(set_max, O.settle_time);
        max_norm_max = max(max_norm_max, O.steady.max_norm);
    end
    Results.summary = struct( ...
        'bias_norm_max_all', bias_max, ...
        'rmse_norm_max_all', rmse_max, ...
        'p95_norm_max_all', p95_max, ...
        'max_norm_max_all', max_norm_max, ...
        'final_err_max_all', fin_max, ...
        'settle_max_all', set_max, ...
        'bound_hits_total', hits_tot);

    % R10 rotation sensitivity vs X/XZ
    OX = Results.routes.X;
    OXZ = Results.routes.XZ;
    OR10 = Results.routes.R10;
    Results.route_dependence = struct( ...
        'note', ['Delayed DVL BODY is rotated by CURRENT truth R → NED innovation ', ...
            'is attitude-dependent even with constant BODY bias. R10 (large ψ swing) ', ...
            'maps fixed BODY DVL bias through a rotating frame → time-varying NED ', ...
            'bias contribution; X/XZ nearly constant attitude → nearer to static ', ...
            'NED bias. INS NED bias is attitude-independent. Latency adds causal ', ...
            'phase lag on both channels.'], ...
        'rotate_assumption', sens.rotate_assumption, ...
        'attitude_affects_dvl_ned', true, ...
        'ins_ned_attitude_independent', true, ...
        'r10_vs_x_delta_bias', OR10.steady.bias_norm - OX.steady.bias_norm, ...
        'r10_vs_xz_delta_bias', OR10.steady.bias_norm - OXZ.steady.bias_norm, ...
        'r10_vs_x_delta_rmse', OR10.steady.rmse_norm - OX.steady.rmse_norm, ...
        'r10_vs_xz_delta_rmse', OR10.steady.rmse_norm - OXZ.steady.rmse_norm, ...
        'r10_psi_range_deg', OR10.psi_range_deg, ...
        'x_psi_range_deg', OX.psi_range_deg);

    Results.limitations = [ ...
        'Certifies THIS declared synthetic bias+latency case only ', ...
        '(INS bias=[+0.010,-0.005,+0.005]@50ms, DVL bias=[+0.005,0,-0.003]@200ms, ', ...
        'rng(42) noise retained, causal ZOH delay, CURRENT-truth-R on delayed DVL). ', ...
        'Attitude error, frame misalignment, and lever-arm are DEFERRED. ', ...
        'Not hardware validation. Observer never fed to guidance/control; ', ...
        'do not promote to production.'];

    % ---- PASS gates ----
    gates = struct();
    gates.steady_vector_bias_le_0p030 = bias_max <= 0.030;
    gates.steady_vector_rmse_le_0p035 = rmse_max <= 0.035;
    gates.p95_le_0p070 = p95_max <= 0.070;
    gates.final_err_le_0p050 = fin_max <= 0.050;
    gates.bounded_no_hits = hits_tot == 0;
    gates.all_routes = true;
    for i = 1:numel(names)
        O = Results.routes.(names{i});
        gates.all_routes = gates.all_routes && O.ok && O.pass_bias && O.pass_rmse && ...
            O.pass_p95 && O.pass_final && O.pass_bounded && O.pass_no_hits;
    end
    gates.offline_not_in_loop = ~Results.fed_to_control;
    gates.production_hook_untouched = Results.production_untouched && Results.hook_untouched;
    gates.same_wo_no_tuning = (wo == 0.50) && ~Results.gain_sweep;
    gates.noise_was_pass = strcmp(Noise.verdict, 'PASS');

    gn = fieldnames(gates);
    verdict_ok = true;
    for k = 1:numel(gn)
        verdict_ok = verdict_ok && logical(gates.(gn{k}));
    end
    verdict = tern(verdict_ok, 'PASS', 'FAIL');
    all_pass = all_pass && verdict_ok; %#ok<NASGU>

    md_path  = fullfile(out_dir, [tag '.md']);
    mat_path = fullfile(out_dir, [tag '.mat']);
    png_path = fullfile(out_dir, [tag '.png']);

    Results.gates = gates;
    Results.verdict = verdict;
    Results.paths = struct('md', md_path, 'mat', mat_path, 'png', png_path);
    Results.note = ['Certifies declared synthetic bias+latency case only; not hardware; ', ...
        'attitude error/misalignment/lever-arm deferred; observer never fed to control; ', ...
        'production + hook frozen; no CODEX_VERTICAL_PLAN touch'];

    if strcmp(verdict, 'PASS')
        Results.next = struct( ...
            'gate', 'combined_nonlinear_6dof_disturbance_regression_baseline', ...
            'detail', ['Bias/latency PASS → next bounded gate: combined nonlinear 6DOF ', ...
                'disturbance regression baseline (still offline / not production). ', ...
                'Never feed observer to control; never promote to production.']);
    else
        Results.next = struct( ...
            'gate', 'fixed_bias_augmented_observer_audit', ...
            'detail', ['Bias/latency FAIL → next bounded gate: fixed-bias augmented ', ...
                'observer audit (still offline). Never feed observer to control; ', ...
                'never promote to production.']);
    end

    write_png(png_path, Results, task_id, verdict, Vc_true);
    write_md(md_path, Results);
    append_audit(out_dir, Results);
    save(mat_path, '-struct', 'Results');

    fprintf('\nVERDICT: %s (declared bias+latency case only; not hardware)\n', verdict);
    fprintf('Saved: %s\n%s\n%s\n', md_path, mat_path, png_path);
    print_feedback(Results);
end

%% ===================== bias+latency observer =====================
function Obs = run_bias_latency_observer(S, wo, Vhat0, V_bound, Vc_true, settle_frac, sens, steady_t0)
    n = numel(S.t);
    Obs = struct('ok', false);
    if n < 10
        return;
    end
    dt = S.dt;
    if isempty(dt) || ~isfinite(dt) || dt <= 0
        dt = median(diff(S.t));
    end

    Vg_true = zeros(n, 3);
    Vw_body_true = zeros(n, 3);
    Vw_ned_true = zeros(n, 3);
    yc_ideal = zeros(n, 3);

    Vg_meas = zeros(n, 3);           % delayed INS NED
    Vw_body_meas = zeros(n, 3);      % delayed DVL BODY
    Vw_ned_meas = zeros(n, 3);       % R_current * delayed BODY
    yc = zeros(n, 3);
    innov = zeros(n, 3);
    Vhat = zeros(n, 3);
    bound_hit = false(n, 1);

    % Truth series on sim grid (for delay lookup of truth+noise+bias)
    Vg_inst = zeros(n, 3);
    Vw_b_inst = zeros(n, 3);
    for k = 1:n
        phi = S.ori(k, 1); theta = S.ori(k, 2); psi = S.ori(k, 3);
        R = rotmat(phi, theta, psi);
        nu_lin = S.nu(k, 1:3).';
        if isfield(S, 'V_water_body') && ~isempty(S.V_water_body)
            nu_r = S.V_water_body(k, :).';
        else
            nu_r = S.nu_r(k, 1:3).';
        end
        Vg_inst(k, :) = (R * nu_lin).';
        Vw_b_inst(k, :) = nu_r.';
        Vw_ned_true(k, :) = (R * nu_r).';
        yc_ideal(k, :) = Vg_inst(k, :) - Vw_ned_true(k, :);
        Vg_true(k, :) = Vg_inst(k, :);
        Vw_body_true(k, :) = Vw_b_inst(k, :);
    end

    % Native-rate white noise (same construction as noise run; shared rng stream)
    [n_ins_hold, t_ins] = zoh_white(S.t, sens.ins_fs, sens.ins_sigma, 3);
    [n_dvl_hold, t_dvl] = zoh_white(S.t, sens.dvl_fs, sens.dvl_sigma, 3);

    % Instantaneous corrupted measurements (pre-delay)
    Vg_corrupt = Vg_inst + repmat(sens.ins_bias_ned(:).', n, 1) + n_ins_hold;
    Vw_b_corrupt = Vw_b_inst + repmat(sens.dvl_bias_body(:).', n, 1) + n_dvl_hold;

    % Causal timestamp/ZOH delay: at t use last sample with origin <= t - latency
    [Vg_del, t_ins_src, t_ins_avail] = causal_zoh_delay(S.t, Vg_corrupt, sens.ins_latency_s);
    [Vw_b_del, t_dvl_src, t_dvl_avail] = causal_zoh_delay(S.t, Vw_b_corrupt, sens.dvl_latency_s);

    alpha = 1 - exp(-wo * dt);
    v = Vhat0(:);

    for k = 1:n
        phi = S.ori(k, 1); theta = S.ori(k, 2); psi = S.ori(k, 3);
        R = rotmat(phi, theta, psi);   % CURRENT truth R

        Vg_m = Vg_del(k, :).';
        Vw_bm = Vw_b_del(k, :).';
        % SIMPLIFYING ASSUMPTION: rotate delayed BODY with CURRENT R
        Vw_nm = R * Vw_bm;
        yc_k = Vg_m - Vw_nm;

        Vg_meas(k, :) = Vg_m.';
        Vw_body_meas(k, :) = Vw_bm.';
        Vw_ned_meas(k, :) = Vw_nm.';
        yc(k, :) = yc_k.';
        innov(k, :) = yc_k.';

        v = v + alpha * (yc_k - v);
        pre = v;
        v = max(min(v, V_bound), -V_bound);
        bound_hit(k) = any(abs(pre) > V_bound + 1e-15);
        Vhat(k, :) = v.';
    end

    err = Vhat - repmat(Vc_true(:).', n, 1);
    err_norm = sqrt(sum(err.^2, 2));
    band = settle_frac * norm(Vc_true);
    settle_t = settle_time_2pct(S.t, err_norm, band);

    ss = S.t >= steady_t0;
    if ~any(ss)
        ss = true(n, 1);
    end
    err_ss = err(ss, :);
    en_ss = err_norm(ss);
    bias = mean(err_ss, 1).';
    bias_norm = norm(bias);
    rmse_comp = sqrt(mean(err_ss.^2, 1)).';
    rmse_norm = sqrt(mean(en_ss.^2));
    p95_norm = percentile95(en_ss);
    max_norm_ss = max(en_ss);
    max_comp = max(abs(err_ss), [], 1).';

    % Innovation stats (steady): mean + lag-1 autocorrelation per axis
    innov_ss = innov(ss, :);
    innov_mean = mean(innov_ss, 1).';
    innov_mean_norm = norm(innov_mean);
    acorr = zeros(3, 1);
    for ax = 1:3
        acorr(ax) = lag1_acorr(innov_ss(:, ax));
    end

    Obs.ok = true;
    Obs.t = S.t;
    Obs.dt = dt;
    Obs.ori = S.ori;
    Obs.Vg_NED_true = Vg_true;
    Obs.Vw_BODY_true = Vw_body_true;
    Obs.Vw_NED_true = Vw_ned_true;
    Obs.y_c_ideal = yc_ideal;
    Obs.Vg_NED = Vg_meas;
    Obs.Vw_BODY = Vw_body_meas;
    Obs.Vw_NED = Vw_ned_meas;
    Obs.y_c = yc;
    Obs.innovation = innov;
    Obs.innovation_t = S.t;
    Obs.n_ins = n_ins_hold;
    Obs.n_dvl = n_dvl_hold;
    Obs.t_ins_updates = t_ins;
    Obs.t_dvl_updates = t_dvl;
    % Raw delayed timestamps (source origin + availability)
    Obs.t_ins_src = t_ins_src;
    Obs.t_ins_avail = t_ins_avail;
    Obs.t_dvl_src = t_dvl_src;
    Obs.t_dvl_avail = t_dvl_avail;
    Obs.ins_latency_s = sens.ins_latency_s;
    Obs.dvl_latency_s = sens.dvl_latency_s;
    Obs.ins_bias_ned = sens.ins_bias_ned(:).';
    Obs.dvl_bias_body = sens.dvl_bias_body(:).';
    Obs.rotate_assumption = sens.rotate_assumption;
    Obs.Vhat = Vhat;
    Obs.Vc_true = Vc_true(:).';
    Obs.err = err;
    Obs.err_norm = err_norm;
    Obs.err_final = err(end, :).';
    Obs.err_final_norm = err_norm(end);
    Obs.err_rms = sqrt(mean(err.^2, 1)).';
    Obs.err_rms_norm = sqrt(mean(err_norm.^2));
    Obs.err_max = max(abs(err), [], 1).';
    Obs.err_max_norm = max(err_norm);
    Obs.settle_band = band;
    Obs.settle_time = settle_t;
    Obs.bound_hits = sum(bound_hit);
    Obs.Vhat_max_abs = max(abs(Vhat), [], 'all');
    Obs.psi_range_deg = [rad2deg(min(S.ori(:,3))), rad2deg(max(S.ori(:,3)))];
    Obs.theta_range_deg = [rad2deg(min(S.ori(:,2))), rad2deg(max(S.ori(:,2)))];

    Obs.steady = struct( ...
        't0', steady_t0, ...
        'bias', bias, ...
        'bias_norm', bias_norm, ...
        'rms', rmse_comp, ...
        'rmse_norm', rmse_norm, ...
        'p95_norm', p95_norm, ...
        'max_norm', max_norm_ss, ...
        'max', max_comp, ...
        'n', sum(ss));

    Obs.innov_stats = struct( ...
        'mean', innov_mean, ...
        'mean_norm', innov_mean_norm, ...
        'acorr_lag1', acorr, ...
        'acorr_lag1_mean', mean(acorr), ...
        'note', 'steady-window innovation (= delayed y_c) mean and lag-1 autocorr');

    Obs.pass_bias = bias_norm <= 0.030;
    Obs.pass_rmse = rmse_norm <= 0.035;
    Obs.pass_p95 = p95_norm <= 0.070;
    Obs.pass_final = Obs.err_final_norm <= 0.050;
    Obs.pass_bounded = Obs.Vhat_max_abs <= V_bound + 1e-12;
    Obs.pass_no_hits = Obs.bound_hits == 0;
end

function [y_del, t_src, t_avail] = causal_zoh_delay(t, y, latency_s)
    % Causal ZOH delay: at t(k) use y at last index with t(j) <= t(k) - latency.
    % Before any sample is available, hold the first sample (startup ZOH).
    n = numel(t);
    y_del = zeros(size(y));
    t_src = zeros(n, 1);
    t_avail = zeros(n, 1);
    j = 1;
    for k = 1:n
        t_need = t(k) - latency_s;
        while j < n && t(j + 1) <= t_need + 1e-15
            j = j + 1;
        end
        if t(1) > t_need
            % no causal sample yet — hold first (documented startup)
            idx = 1;
        else
            idx = j;
        end
        y_del(k, :) = y(idx, :);
        t_src(k) = t(idx);
        t_avail(k) = t(idx) + latency_s;
    end
end

function [n_hold, t_upd] = zoh_white(t, fs, sigma, dim)
    % Additive white noise at fs, zero-order held onto simulation grid t.
    t0 = t(1);
    tend = t(end);
    t_upd = (t0:(1/fs):tend).';
    if isempty(t_upd) || t_upd(end) < tend - 1e-12
        t_upd = [t_upd; tend]; %#ok<AGROW>
    end
    n_upd = sigma * randn(numel(t_upd), dim);
    idx = floor((t - t0) * fs) + 1;
    idx = min(max(idx, 1), numel(t_upd));
    n_hold = n_upd(idx, :);
end

function C = compare_to_noise(Obs, Nref, steady_t0)
    ss = Nref.t >= steady_t0;
    if ~any(ss); ss = true(size(Nref.t)); end
    eN = Nref.err(ss, :);
    enN = Nref.err_norm(ss);
    bias_N = mean(eN, 1).';
    C = struct();
    C.noise_bias = bias_N;
    C.noise_bias_norm = norm(bias_N);
    C.noise_rmse_norm = sqrt(mean(enN.^2));
    C.noise_p95_norm = percentile95(enN);
    C.noise_max_norm = max(enN);
    C.noise_final_norm = Nref.err_final_norm;
    C.noise_settle = Nref.settle_time;
    C.noise_hits = Nref.bound_hits;
    C.biaslat_bias = Obs.steady.bias;
    C.biaslat_bias_norm = Obs.steady.bias_norm;
    C.biaslat_rmse_norm = Obs.steady.rmse_norm;
    C.biaslat_p95_norm = Obs.steady.p95_norm;
    C.biaslat_max_norm = Obs.steady.max_norm;
    C.biaslat_final_norm = Obs.err_final_norm;
    C.delta_bias = Obs.steady.bias - bias_N;
    C.delta_bias_norm = Obs.steady.bias_norm - C.noise_bias_norm;
    C.delta_steady_rmse = Obs.steady.rmse_norm - C.noise_rmse_norm;
    C.delta_p95 = Obs.steady.p95_norm - C.noise_p95_norm;
    C.delta_max = Obs.steady.max_norm - C.noise_max_norm;
    C.delta_final_norm = Obs.err_final_norm - C.noise_final_norm;
    C.delta_settle = Obs.settle_time - Nref.settle_time;
    C.comp_bias_noise = bias_N;
    C.comp_bias_biaslat = Obs.steady.bias;
end

function a = lag1_acorr(x)
    x = x(:);
    x = x - mean(x);
    if numel(x) < 3
        a = NaN;
        return;
    end
    d = sum(x.^2);
    if d < 1e-30
        a = NaN;
        return;
    end
    a = sum(x(1:end-1) .* x(2:end)) / d;
end

function ts = settle_time_2pct(t, e_norm, band)
    inside = e_norm <= band;
    ts = Inf;
    for k = 1:numel(t)
        if all(inside(k:end))
            ts = t(k);
            return;
        end
    end
end

function p = percentile95(x)
    x = sort(x(:));
    if isempty(x)
        p = NaN;
        return;
    end
    n = numel(x);
    idx = max(1, min(n, ceil(0.95 * n)));
    p = x(idx);
end

function R = rotmat(phi, theta, psi)
    R = [cos(psi)*cos(theta), ...
         cos(psi)*sin(theta)*sin(phi) - sin(psi)*cos(phi), ...
         cos(psi)*sin(theta)*cos(phi) + sin(psi)*sin(phi);
         sin(psi)*cos(theta), ...
         sin(psi)*sin(theta)*sin(phi) + cos(psi)*cos(phi), ...
         sin(psi)*sin(theta)*cos(phi) - cos(psi)*sin(phi);
         -sin(theta), ...
         cos(theta)*sin(phi), ...
         cos(theta)*cos(phi)];
end

%% ===================== outputs =====================
function write_png(png_path, R, task_id, verdict, Vc_true)
    fig = figure('Visible', 'off', 'Position', [40 40 1400 1000]);
    tiledlayout(3, 3, 'Padding', 'compact', 'TileSpacing', 'compact');
    names = {'X', 'XZ', 'R10'};
    for i = 1:3
        O = R.routes.(names{i});
        nexttile;
        plot(O.t, O.y_c_ideal(:,2), 'k:'); hold on;
        plot(O.t, O.y_c(:,2), 'Color', [0.6 0.6 0.6]);
        plot(O.t, O.Vhat(:,2), 'b-');
        yline(Vc_true(2), 'r--');
        xline(R.steady_t0, 'm--');
        grid on; ylabel('m/s');
        title(sprintf('%s East: ideal / delayed y_c / Vhat', names{i}));
        if i == 1
            legend('y_c id', 'y_c del', 'Vhat', 'Vc', 'ss', 'Location', 'best');
        end

        nexttile;
        plot(O.t, O.err(:,1), 'r'); hold on;
        plot(O.t, O.err(:,2), 'g');
        plot(O.t, O.err(:,3), 'b');
        xline(R.steady_t0, 'm--');
        grid on; ylabel('m/s');
        title(sprintf('%s Vhat−Vc (bias||||=%.3g)', names{i}, O.steady.bias_norm));
        if i == 1; legend('N','E','D','ss', 'Location', 'best'); end

        nexttile;
        plot(O.t, O.err_norm, 'm'); hold on;
        yline(0.035, 'k--'); yline(0.070, 'c--');
        xline(R.steady_t0, 'm--');
        grid on; ylabel('m/s'); xlabel('t [s]');
        title(sprintf('%s ||err|| rmse=%.3g p95=%.3g', names{i}, ...
            O.steady.rmse_norm, O.steady.p95_norm));
    end
    sgtitle(sprintf('%s %s — bias+latency INS−DVL (offline, wo=0.50)', ...
        task_id, verdict), 'Interpreter', 'none');
    exportgraphics(fig, png_path, 'Resolution', 150);
    close(fig);
end

function write_md(md_path, R)
    fid = fopen(md_path, 'w');
    fprintf(fid, '# %s — Offline INS/DVL bias+latency audit\n\n', R.task_id);
    fprintf(fid, '**Overall verdict: %s** (declared synthetic bias+latency case only; not hardware)\n\n', R.verdict);

    fprintf(fid, '## Provenance\n\n');
    fprintf(fid, '- Read-only: `run_current_observer_noise.m`, `suite_results/CURRENT_OBSERVER_NOISE.mat`, `suite_results/BOUNDED_CURRENT_HOOK.mat`\n');
    fprintf(fid, '- Noise-only observer: **PASS**; production + current hook: **FROZEN / UNTOUCHED**\n');
    fprintf(fid, '- Driver: `run_current_observer_bias_latency.m` (one invocation)\n');
    fprintf(fid, '- Observer fed to guidance/control: **NO** (offline only)\n');
    fprintf(fid, '- Artifacts: `%s`, `%s`, `%s`\n', R.paths.md, R.paths.mat, R.paths.png);
    fprintf(fid, '- Did **not** touch `CODEX_VERTICAL_PLAN.md`\n');
    fprintf(fid, '- Never claim hardware validation\n\n');

    fprintf(fid, '## Bias+latency case (TEST ASSUMPTION — not hardware spec)\n\n');
    fprintf(fid, '```\n');
    fprintf(fid, 'Noise retained: INS σ=%.3f @ %.0f Hz ZOH; DVL σ=%.3f @ %.0f Hz ZOH; rng(%d)\n', ...
        R.sensor.ins_sigma, R.sensor.ins_fs, R.sensor.dvl_sigma, R.sensor.dvl_fs, R.sensor.seed);
    fprintf(fid, 'INS  Vg_NED  bias=[%+.3f, %+.3f, %+.3f] m/s, latency=%.0f ms\n', ...
        R.sensor.ins_bias_ned, 1000*R.sensor.ins_latency_s);
    fprintf(fid, 'DVL  Vw_BODY bias=[%+.3f, %+.3f, %+.3f] m/s, latency=%.0f ms\n', ...
        R.sensor.dvl_bias_body, 1000*R.sensor.dvl_latency_s);
    fprintf(fid, 'Delay: causal timestamp/ZOH (use last update with t_u <= t - latency)\n');
    fprintf(fid, 'Rotate delayed DVL with CURRENT truth R (SIMPLIFYING ASSUMPTION)\n');
    fprintf(fid, 'y_c = Vg_delayed_NED - R_current * Vw_delayed_BODY\n');
    fprintf(fid, '```\n\n');

    fprintf(fid, '### SIMPLIFYING ASSUMPTION (documented)\n\n');
    fprintf(fid, '%s\n\n', R.sensor.rotate_assumption);

    fprintf(fid, '## Observer (unchanged)\n\n');
    fprintf(fid, '- wo=%.2f rad/s, Vhat(0)=0, bound ±%.1f m/s — **no tuning**\n', ...
        R.observer.wo, R.observer.bound);
    fprintf(fid, '- Steady window: t >= %.1f s (post ~5/wo)\n', R.steady_t0);
    fprintf(fid, '- True Vc = [%.2f, %.2f, %.2f] m/s NED; U=%.1f m/s\n\n', R.Vc_true, R.Uref);

    fprintf(fid, '## Per-route metrics (bias+latency vs noise-only)\n\n');
    fprintf(fid, '| Route | bias||mean|| | RMSE_ss | p95_ss | max_ss | final||err|| | settle [s] | hits | noise bias | Δbias | PASS |\n');
    fprintf(fid, '|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|:---:|\n');
    names = {'X','XZ','R10'};
    for i = 1:3
        O = R.routes.(names{i});
        C = O.compare;
        pass_r = O.pass_bias && O.pass_rmse && O.pass_p95 && O.pass_final && ...
            O.pass_bounded && O.pass_no_hits;
        fprintf(fid, '| %s | %.4e | %.4e | %.4e | %.4e | %.4e | %.3f | %d | %.3e | %.3e | %s |\n', ...
            names{i}, O.steady.bias_norm, O.steady.rmse_norm, O.steady.p95_norm, ...
            O.steady.max_norm, O.err_final_norm, O.settle_time, O.bound_hits, ...
            C.noise_bias_norm, C.delta_bias_norm, yn(pass_r));
    end
    fprintf(fid, '\n');

    fprintf(fid, '### Component steady bias (noise → bias+latency)\n\n');
    fprintf(fid, '| Route | bl_N | bl_E | bl_D | noise_N | noise_E | noise_D | ΔN | ΔE | ΔD |\n');
    fprintf(fid, '|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|\n');
    for i = 1:3
        O = R.routes.(names{i});
        C = O.compare;
        fprintf(fid, '| %s | %.3e | %.3e | %.3e | %.3e | %.3e | %.3e | %.3e | %.3e | %.3e |\n', ...
            names{i}, O.steady.bias(1), O.steady.bias(2), O.steady.bias(3), ...
            C.noise_bias(1), C.noise_bias(2), C.noise_bias(3), ...
            C.delta_bias(1), C.delta_bias(2), C.delta_bias(3));
    end
    fprintf(fid, '\n');

    fprintf(fid, '### Innovation mean / lag-1 autocorrelation (steady)\n\n');
    fprintf(fid, '| Route | innov||mean|| | mean_N | mean_E | mean_D | acorr_N | acorr_E | acorr_D |\n');
    fprintf(fid, '|---|---:|---:|---:|---:|---:|---:|---:|\n');
    for i = 1:3
        O = R.routes.(names{i});
        I = O.innov_stats;
        fprintf(fid, '| %s | %.3e | %.3e | %.3e | %.3e | %.3f | %.3f | %.3f |\n', ...
            names{i}, I.mean_norm, I.mean(1), I.mean(2), I.mean(3), ...
            I.acorr_lag1(1), I.acorr_lag1(2), I.acorr_lag1(3));
    end
    fprintf(fid, '\n');

    fprintf(fid, '## Attitude / R10 rotation sensitivity\n\n');
    fprintf(fid, '| Route | psi range [deg] | theta range [deg] | bias | RMSE |\n|---|---:|---:|---:|---:|\n');
    for i = 1:3
        O = R.routes.(names{i});
        fprintf(fid, '| %s | [%.2f, %.2f] | [%.2f, %.2f] | %.3e | %.3e |\n', names{i}, ...
            O.psi_range_deg(1), O.psi_range_deg(2), O.theta_range_deg(1), O.theta_range_deg(2), ...
            O.steady.bias_norm, O.steady.rmse_norm);
    end
    fprintf(fid, '\n- R10−X Δbias=%.3e, ΔRMSE=%.3e; R10−XZ Δbias=%.3e, ΔRMSE=%.3e\n', ...
        R.route_dependence.r10_vs_x_delta_bias, R.route_dependence.r10_vs_x_delta_rmse, ...
        R.route_dependence.r10_vs_xz_delta_bias, R.route_dependence.r10_vs_xz_delta_rmse);
    fprintf(fid, '- %s\n\n', R.route_dependence.note);

    fprintf(fid, '## Raw delayed timestamps / innovations saved\n\n');
    fprintf(fid, '- Per route in `.mat`: `innovation`, `innovation_t`,\n');
    fprintf(fid, '  `t_ins_src`, `t_ins_avail`, `t_dvl_src`, `t_dvl_avail`,\n');
    fprintf(fid, '  `t_ins_updates`, `t_dvl_updates`, `n_ins`, `n_dvl`\n\n');

    fprintf(fid, '## Limitations\n\n');
    fprintf(fid, '%s\n\n', R.limitations);

    fprintf(fid, '## PASS gates\n\n');
    fprintf(fid, '| Gate | Result |\n|---|---|\n');
    gn = fieldnames(R.gates);
    for i = 1:numel(gn)
        fprintf(fid, '| %s | %s |\n', gn{i}, tern(R.gates.(gn{i}), 'PASS', 'FAIL'));
    end
    fprintf(fid, '\n**Overall: %s**\n\n', R.verdict);

    fprintf(fid, '## Next bounded gate\n\n');
    fprintf(fid, '- **`%s`**\n', R.next.gate);
    fprintf(fid, '- %s\n', R.next.detail);
    fprintf(fid, '- Do **not** feed observer to control; do **not** promote to production.\n');
    fclose(fid);
end

function append_audit(out_dir, R)
    audit_path = fullfile(out_dir, 'STATE_SPACE_MODEL_AUDIT.md');
    fid = fopen(audit_path, 'a');
    fprintf(fid, '\n\n---\n\n');
    fprintf(fid, '## %s — %s\n\n', R.task_id, datestr(now, 31));
    fprintf(fid, '### Provenance\n\n');
    fprintf(fid, '- Read-only: `run_current_observer_noise.m`, `CURRENT_OBSERVER_NOISE.mat`, `BOUNDED_CURRENT_HOOK.mat`\n');
    fprintf(fid, '- Noise-only observer PASS; production + current hook untouched; offline only\n');
    fprintf(fid, '- Driver: `run_current_observer_bias_latency.m` (one invocation)\n');
    fprintf(fid, '- Artifacts: `%s`, `%s`, `%s`\n', R.paths.md, R.paths.mat, R.paths.png);
    fprintf(fid, '- Did not touch `CODEX_VERTICAL_PLAN.md`\n\n');
    fprintf(fid, '### Bias+latency case (TEST ASSUMPTION — not hardware)\n\n');
    fprintf(fid, '```\nNoise retained rng(%d); INS bias=[%+.3f,%+.3f,%+.3f]@%.0fms;\n', ...
        R.sensor.seed, R.sensor.ins_bias_ned, 1000*R.sensor.ins_latency_s);
    fprintf(fid, 'DVL bias=[%+.3f,%+.3f,%+.3f]@%.0fms; causal ZOH delay;\n', ...
        R.sensor.dvl_bias_body, 1000*R.sensor.dvl_latency_s);
    fprintf(fid, 'SIMPLIFYING: delayed DVL BODY × CURRENT truth R;\n');
    fprintf(fid, 'same observer wo=%.2f (no tuning); steady t>=%.1f s\n```\n\n', ...
        R.observer.wo, R.steady_t0);
    fprintf(fid, '### Verdict\n\n');
    fprintf(fid, '**%s** — declared synthetic bias+latency case only (not hardware; attitude/misalign/lever-arm deferred).\n\n', R.verdict);
    fprintf(fid, '### Key numbers\n\n');
    fprintf(fid, '| Item | Value |\n|---|---|\n');
    fprintf(fid, '| bias||mean|| max (all) | %.4e m/s |\n', R.summary.bias_norm_max_all);
    fprintf(fid, '| steady RMSE max (all) | %.4e m/s |\n', R.summary.rmse_norm_max_all);
    fprintf(fid, '| p95 max (all) | %.4e m/s |\n', R.summary.p95_norm_max_all);
    fprintf(fid, '| final ||err|| max (all) | %.4e m/s |\n', R.summary.final_err_max_all);
    fprintf(fid, '| bound hits total | %d |\n', R.summary.bound_hits_total);
    names = {'X','XZ','R10'};
    for i = 1:3
        O = R.routes.(names{i});
        fprintf(fid, '| %s bias/rmse/p95/final | %.3e / %.3e / %.3e / %.3e |\n', ...
            names{i}, O.steady.bias_norm, O.steady.rmse_norm, O.steady.p95_norm, O.err_final_norm);
    end
    fprintf(fid, '| R10−X Δbias / ΔRMSE | %.3e / %.3e |\n', ...
        R.route_dependence.r10_vs_x_delta_bias, R.route_dependence.r10_vs_x_delta_rmse);
    fprintf(fid, '\n### Route/attitude note\n\n');
    fprintf(fid, '%s\n\n', R.route_dependence.note);
    fprintf(fid, '### SIMPLIFYING ASSUMPTION\n\n');
    fprintf(fid, '%s\n\n', R.sensor.rotate_assumption);
    fprintf(fid, '### Next\n\n');
    fprintf(fid, '- `%s` — %s\n', R.next.gate, R.next.detail);
    fprintf(fid, '- Never feed observer to control; never promote to production.\n');
    fclose(fid);
end

function print_feedback(R)
    fprintf('\n========== FEEDBACK ==========\n');
    fprintf('VERDICT: %s (declared bias+latency case only)\n', R.verdict);
    fprintf('bias max: %.6e  RMSE max: %.6e  p95 max: %.6e  final max: %.6e\n', ...
        R.summary.bias_norm_max_all, R.summary.rmse_norm_max_all, ...
        R.summary.p95_norm_max_all, R.summary.final_err_max_all);
    fprintf('bound hits: %d\n', R.summary.bound_hits_total);
    names = {'X','XZ','R10'};
    for i = 1:3
        O = R.routes.(names{i});
        fprintf('%s: bias=%.3e rmse=%.3e p95=%.3e final=%.3e hits=%d innov_acorr=%.3f\n', ...
            names{i}, O.steady.bias_norm, O.steady.rmse_norm, O.steady.p95_norm, ...
            O.err_final_norm, O.bound_hits, O.innov_stats.acorr_lag1_mean);
    end
    gn = fieldnames(R.gates);
    for i = 1:numel(gn)
        fprintf('  gate %s: %s\n', gn{i}, tern(R.gates.(gn{i}), 'PASS', 'FAIL'));
    end
    fprintf('Next: %s\n', R.next.gate);
    fprintf('Artifacts:\n  %s\n  %s\n  %s\n', R.paths.md, R.paths.mat, R.paths.png);
end

function s = yn(tf)
    if tf; s = 'YES'; else; s = 'NO'; end
end

function s = tern(tf, a, b)
    if tf; s = a; else; s = b; end
end
