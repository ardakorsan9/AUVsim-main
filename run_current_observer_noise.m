function run_current_observer_noise()
% CURRENT_OBSERVER_NOISE_001 — offline additive INS/DVL velocity-noise hook.
% Read-only: run_current_observer_ideal.m, suite_results/CURRENT_OBSERVER_IDEAL.mat,
%   suite_results/BOUNDED_CURRENT_HOOK.mat.
% Ideal INS−DVL observer PASS; production plant/controller/guidance + current hook FROZEN.
% Observer offline only — never fed to guidance/control; no production promote.
%
% Synthetic TEST ASSUMPTION (not hardware spec), rng(42), zero bias/delay:
%   INS  Vg_NED  white noise sigma=0.020 m/s/axis @ 20 Hz ZOH
%   DVL  Vw_BODY white noise sigma=0.010 m/s/axis @  5 Hz ZOH
%   Independent channels; rotate noisy DVL with truth R; y_c = Vg - R*Vw
% Same observer (no tuning): dVhat/dt = wo*(y_c-Vhat), wo=0.50 rad/s, bound ±0.5
% Routes: X / XZ / R10 @ Vc=[0,0.15,0] using saved hook trajectories.
% PASS (this declared noise case only): mean vector bias<=0.010, steady RMSE<=0.025,
%   p95<=0.050, final||err||<=0.030, bounded/no hits, all routes.
% Bias / latency / misalignment DEFERRED.
% Artifacts: suite_results/CURRENT_OBSERVER_NOISE.{md,mat,png}
% Appends suite_results/STATE_SPACE_MODEL_AUDIT.md
% Does NOT touch CODEX_VERTICAL_PLAN.md.

    project_dir = fileparts(mfilename('fullpath'));
    addpath(project_dir);
    out_dir = fullfile(project_dir, 'suite_results');
    if ~exist(out_dir, 'dir'); mkdir(out_dir); end
    tag = 'CURRENT_OBSERVER_NOISE';
    task_id = 'CURRENT_OBSERVER_NOISE_001';

    ideal_mat = fullfile(out_dir, 'CURRENT_OBSERVER_IDEAL.mat');
    hook_mat  = fullfile(out_dir, 'BOUNDED_CURRENT_HOOK.mat');
    ideal_run = fullfile(project_dir, 'run_current_observer_ideal.m');
    assert(exist(ideal_mat, 'file') == 2, 'Missing %s', ideal_mat);
    assert(exist(hook_mat, 'file') == 2, 'Missing %s', hook_mat);
    assert(exist(ideal_run, 'file') == 2, 'Missing %s', ideal_run);

    fprintf('\n========== %s ==========\n', task_id);
    fprintf('Offline INS/DVL additive noise hook; same wo=0.50; no tuning.\n');
    fprintf('TEST ASSUMPTION only — not hardware spec; not production.\n');

    Ideal = load(ideal_mat);
    Hook  = load(hook_mat);
    assert(strcmp(Ideal.verdict, 'PASS'), 'CURRENT_OBSERVER_IDEAL must be PASS');
    assert(strcmp(Hook.verdict, 'PASS'), 'BOUNDED_CURRENT_HOOK must be PASS');
    assert(isfield(Hook, 'routes') && isfield(Ideal, 'routes'), 'Missing routes');

    % ---- Fixed observer (identical to ideal; no retune) ----
    wo = 0.50;
    Vhat0 = [0; 0; 0];
    V_bound = 0.5;
    Vc_true = [0; 0.15; 0];
    settle_frac = 0.02;
    names = {'X', 'XZ', 'R10'};

    % ---- Declared noise case (synthetic) ----
    noise = struct();
    noise.assumption = 'synthetic TEST ASSUMPTION — not hardware spec';
    noise.ins_sigma = 0.020;   % m/s / axis
    noise.ins_fs = 20;         % Hz ZOH
    noise.dvl_sigma = 0.010;   % m/s / axis
    noise.dvl_fs = 5;          % Hz ZOH
    noise.bias = [0; 0; 0];
    noise.delay_s = 0;
    noise.independent = true;
    noise.seed = 42;
    noise.rotate_dvl_with = 'truth_R';
    noise.y_c = 'Vg_noisy_NED - R_truth * Vw_noisy_BODY';

    steady_t0 = 10.0;   % after FO ~5τ (τ=1/wo=2s); post ideal 2% settle

    Results = struct();
    Results.task_id = task_id;
    Results.convention = Ideal.convention;
    Results.observer = struct('wo', wo, 'Vhat0', Vhat0, 'bound', V_bound, ...
        'form', 'dVhat/dt = wo*(y_c - Vhat); discrete exact FO; axis clamp ±bound', ...
        'tuning', 'NONE — identical to CURRENT_OBSERVER_IDEAL');
    Results.Vc_true = Vc_true;
    Results.Uref = Hook.Uref;
    Results.seed_noise = noise.seed;
    Results.seed_hook = Hook.seed;
    Results.noise = noise;
    Results.steady_t0 = steady_t0;
    Results.fed_to_control = false;
    Results.production_untouched = true;
    Results.hook_untouched = true;
    Results.ideal_untouched = true;
    Results.gain_sweep = false;
    Results.routes = struct();
    Results.ideal_ref = struct();

    rng(noise.seed, 'twister');

    all_pass = true;
    for i = 1:numel(names)
        nm = names{i};
        assert(isfield(Hook.routes, nm), 'Missing route %s in hook mat', nm);
        assert(isfield(Ideal.routes, nm), 'Missing route %s in ideal mat', nm);
        S = Hook.routes.(nm).curr;
        assert(max(abs(S.Vc(:) - Vc_true)) < 1e-12, 'Route %s Vc mismatch', nm);

        Iref = Ideal.routes.(nm);
        Obs = run_noisy_observer(S, wo, Vhat0, V_bound, Vc_true, settle_frac, ...
            noise, steady_t0);
        Obs.name = nm;
        Obs.compare = compare_to_ideal(Obs, Iref, steady_t0);
        Results.routes.(nm) = Obs;
        Results.ideal_ref.(nm) = struct( ...
            'err_final_norm', Iref.err_final_norm, ...
            'err_rms_norm', Iref.err_rms_norm, ...
            'err_max_norm', Iref.err_max_norm, ...
            'settle_time', Iref.settle_time, ...
            'bound_hits', Iref.bound_hits, ...
            'err_final', Iref.err_final, ...
            'psi_range_deg', Iref.psi_range_deg, ...
            'theta_range_deg', Iref.theta_range_deg);

        fprintf('\n--- Route %s (noisy) ---\n', nm);
        fprintf('  bias vec ||mean(err)|| steady: %.4e  (gate<=0.010)\n', Obs.steady.bias_norm);
        fprintf('  RMSE ||err|| steady: %.4e  (gate<=0.025)\n', Obs.steady.rmse_norm);
        fprintf('  p95 ||err|| steady: %.4e  (gate<=0.050)\n', Obs.steady.p95_norm);
        fprintf('  final ||err||: %.4e  (gate<=0.030)\n', Obs.err_final_norm);
        fprintf('  settle 2%%: %.3f s  bound hits: %d  max|Vhat|: %.4f\n', ...
            Obs.settle_time, Obs.bound_hits, Obs.Vhat_max_abs);
        fprintf('  component bias [N,E,D]: [%.3e, %.3e, %.3e]\n', Obs.steady.bias);
        fprintf('  ideal→noisy Δfinal: %.3e  ΔRMSE_ss: %.3e\n', ...
            Obs.compare.delta_final_norm, Obs.compare.delta_steady_rmse);

        all_pass = all_pass && Obs.pass_bias && Obs.pass_rmse && Obs.pass_p95 && ...
            Obs.pass_final && Obs.pass_bounded && Obs.pass_no_hits;
    end

    % Cross-route summary
    bias_max = 0; rmse_max = 0; p95_max = 0; fin_max = 0; hits_tot = 0; set_max = 0;
    for i = 1:numel(names)
        O = Results.routes.(names{i});
        bias_max = max(bias_max, O.steady.bias_norm);
        rmse_max = max(rmse_max, O.steady.rmse_norm);
        p95_max = max(p95_max, O.steady.p95_norm);
        fin_max = max(fin_max, O.err_final_norm);
        hits_tot = hits_tot + O.bound_hits;
        set_max = max(set_max, O.settle_time);
    end
    Results.summary = struct( ...
        'bias_norm_max_all', bias_max, ...
        'rmse_norm_max_all', rmse_max, ...
        'p95_norm_max_all', p95_max, ...
        'final_err_max_all', fin_max, ...
        'settle_max_all', set_max, ...
        'bound_hits_total', hits_tot);

    Results.route_dependence = struct( ...
        'note', ['DVL BODY noise rotated by truth R → NED innovation cov is ', ...
            'attitude-dependent; R10 (large ψ swing) should differ from X/XZ. ', ...
            'INS noise already in NED is attitude-independent. Ideal y_c≡Vc; ', ...
            'noisy y_c = Vc + n_ins - R*n_dvl (zero bias/delay case).'], ...
        'attitude_affects_dvl_ned', true, ...
        'ins_ned_attitude_independent', true);

    Results.limitations = [ ...
        'Certifies THIS declared synthetic noise case only (INS σ=0.020@20Hz ZOH, ', ...
        'DVL σ=0.010@5Hz ZOH, rng(42), zero bias/delay, truth-R rotation). ', ...
        'Sensor bias, latency, lever-arm, and frame misalignment are DEFERRED. ', ...
        'Not hardware validation. Observer never fed to guidance/control; ', ...
        'do not promote to production.'];

    % ---- PASS gates ----
    gates = struct();
    gates.mean_vector_bias_le_0p010 = bias_max <= 0.010;
    gates.steady_vector_rmse_le_0p025 = rmse_max <= 0.025;
    gates.p95_le_0p050 = p95_max <= 0.050;
    gates.final_err_le_0p030 = fin_max <= 0.030;
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
    gates.ideal_was_pass = strcmp(Ideal.verdict, 'PASS');

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
    Results.note = ['Certifies declared synthetic noise case only; not hardware; ', ...
        'bias/latency/misalignment deferred; observer never fed to control; ', ...
        'production + hook frozen; no CODEX_VERTICAL_PLAN touch'];

    if strcmp(verdict, 'PASS')
        Results.next = struct( ...
            'gate', 'bias_latency_audit_INS_DVL', ...
            'detail', ['Noise PASS → next bounded gate: ONE bias/latency audit on the ', ...
                'INS/DVL pair (still offline). Never feed observer to control; ', ...
                'never promote to production.']);
    else
        Results.next = struct( ...
            'gate', 'kalman_complementary_redesign_audit', ...
            'detail', ['Noise FAIL → next bounded gate: Kalman/complementary redesign ', ...
                'audit (still offline). Never feed observer to control; ', ...
                'never promote to production.']);
    end

    write_png(png_path, Results, task_id, verdict, Vc_true);
    write_md(md_path, Results);
    append_audit(out_dir, Results);
    save(mat_path, '-struct', 'Results');

    fprintf('\nVERDICT: %s (declared noise case only; not hardware)\n', verdict);
    fprintf('Saved: %s\n%s\n%s\n', md_path, mat_path, png_path);
    print_feedback(Results);
end

%% ===================== noisy observer =====================
function Obs = run_noisy_observer(S, wo, Vhat0, V_bound, Vc_true, settle_frac, noise, steady_t0)
    n = numel(S.t);
    Obs = struct('ok', false);
    if n < 10
        return;
    end
    dt = S.dt;
    if isempty(dt) || ~isfinite(dt) || dt <= 0
        dt = median(diff(S.t));
    end

    % Ideal truth signals + noisy measurements
    Vg_true = zeros(n, 3);
    Vw_body_true = zeros(n, 3);
    Vw_ned_true = zeros(n, 3);
    yc_ideal = zeros(n, 3);

    Vg_meas = zeros(n, 3);
    Vw_body_meas = zeros(n, 3);
    Vw_ned_meas = zeros(n, 3);
    yc = zeros(n, 3);
    innov = zeros(n, 3);   % raw y_c (noisy innovation)
    Vhat = zeros(n, 3);
    bound_hit = false(n, 1);
    n_ins = zeros(n, 3);
    n_dvl = zeros(n, 3);

    % ZOH white noise trains (independent; shared rng stream)
    [n_ins, t_ins] = zoh_white(S.t, noise.ins_fs, noise.ins_sigma, 3);
    [n_dvl, t_dvl] = zoh_white(S.t, noise.dvl_fs, noise.dvl_sigma, 3);

    alpha = 1 - exp(-wo * dt);
    v = Vhat0(:);

    for k = 1:n
        phi = S.ori(k, 1); theta = S.ori(k, 2); psi = S.ori(k, 3);
        R = rotmat(phi, theta, psi);
        nu_lin = S.nu(k, 1:3).';
        if isfield(S, 'V_water_body') && ~isempty(S.V_water_body)
            nu_r = S.V_water_body(k, :).';
        else
            nu_r = S.nu_r(k, 1:3).';
        end

        Vg_k = R * nu_lin;
        Vw_b = nu_r;
        Vw_n = R * Vw_b;
        yc_id = Vg_k - Vw_n;

        Vg_m = Vg_k + n_ins(k, :).';
        Vw_bm = Vw_b + n_dvl(k, :).';
        Vw_nm = R * Vw_bm;                 % truth R on noisy BODY DVL
        yc_k = Vg_m - Vw_nm;               % = yc_id + n_ins - R*n_dvl

        Vg_true(k, :) = Vg_k.';
        Vw_body_true(k, :) = Vw_b.';
        Vw_ned_true(k, :) = Vw_n.';
        yc_ideal(k, :) = yc_id.';

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
    Obs.innovation = innov;                 % raw innovations (noisy y_c)
    Obs.innovation_t = S.t;                 % sample timestamps (sim grid)
    Obs.n_ins = n_ins;
    Obs.n_dvl = n_dvl;
    Obs.t_ins_updates = t_ins;
    Obs.t_dvl_updates = t_dvl;
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

    Obs.pass_bias = bias_norm <= 0.010;
    Obs.pass_rmse = rmse_norm <= 0.025;
    Obs.pass_p95 = p95_norm <= 0.050;
    Obs.pass_final = Obs.err_final_norm <= 0.030;
    Obs.pass_bounded = Obs.Vhat_max_abs <= V_bound + 1e-12;
    Obs.pass_no_hits = Obs.bound_hits == 0;
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
    % Hold: index of last update at or before t(k)
    idx = floor((t - t0) * fs) + 1;
    idx = min(max(idx, 1), numel(t_upd));
    n_hold = n_upd(idx, :);
end

function C = compare_to_ideal(Obs, Iref, steady_t0)
    % Ideal steady metrics recomputed on ideal err for fair compare
    ss = Iref.t >= steady_t0;
    if ~any(ss); ss = true(size(Iref.t)); end
    eI = Iref.err(ss, :);
    enI = Iref.err_norm(ss);
    bias_I = mean(eI, 1).';
    C = struct();
    C.ideal_bias = bias_I;
    C.ideal_bias_norm = norm(bias_I);
    C.ideal_rmse_norm = sqrt(mean(enI.^2));
    C.ideal_p95_norm = percentile95(enI);
    C.ideal_final_norm = Iref.err_final_norm;
    C.ideal_settle = Iref.settle_time;
    C.ideal_hits = Iref.bound_hits;
    C.noisy_bias = Obs.steady.bias;
    C.noisy_bias_norm = Obs.steady.bias_norm;
    C.noisy_rmse_norm = Obs.steady.rmse_norm;
    C.noisy_p95_norm = Obs.steady.p95_norm;
    C.noisy_final_norm = Obs.err_final_norm;
    C.delta_bias_norm = Obs.steady.bias_norm - C.ideal_bias_norm;
    C.delta_steady_rmse = Obs.steady.rmse_norm - C.ideal_rmse_norm;
    C.delta_p95 = Obs.steady.p95_norm - C.ideal_p95_norm;
    C.delta_final_norm = Obs.err_final_norm - C.ideal_final_norm;
    C.delta_settle = Obs.settle_time - Iref.settle_time;
    C.comp_bias_ideal = bias_I;
    C.comp_bias_noisy = Obs.steady.bias;
    C.comp_rms_noisy = Obs.steady.rms;
    C.comp_p95_note = 'vector ||err|| p95; component max/rms in Obs.steady';
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
        title(sprintf('%s East: ideal y_c / noisy y_c / Vhat', names{i}));
        if i == 1
            legend('y_c id', 'y_c n', 'Vhat', 'Vc', 'ss', 'Location', 'best');
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
        yline(0.025, 'k--'); yline(0.050, 'c--');
        xline(R.steady_t0, 'm--');
        grid on; ylabel('m/s'); xlabel('t [s]');
        title(sprintf('%s ||err|| rmse=%.3g p95=%.3g', names{i}, ...
            O.steady.rmse_norm, O.steady.p95_norm));
    end
    sgtitle(sprintf('%s %s — noisy INS−DVL observer (offline, wo=0.50)', ...
        task_id, verdict), 'Interpreter', 'none');
    exportgraphics(fig, png_path, 'Resolution', 150);
    close(fig);
end

function write_md(md_path, R)
    fid = fopen(md_path, 'w');
    fprintf(fid, '# %s — Offline INS/DVL additive velocity-noise hook\n\n', R.task_id);
    fprintf(fid, '**Overall verdict: %s** (declared synthetic noise case only; not hardware)\n\n', R.verdict);

    fprintf(fid, '## Provenance\n\n');
    fprintf(fid, '- Read-only: `run_current_observer_ideal.m`, `suite_results/CURRENT_OBSERVER_IDEAL.mat`, `suite_results/BOUNDED_CURRENT_HOOK.mat`\n');
    fprintf(fid, '- Ideal observer: **PASS**; production + current hook: **FROZEN / UNTOUCHED**\n');
    fprintf(fid, '- Driver: `run_current_observer_noise.m` (one invocation)\n');
    fprintf(fid, '- Observer fed to guidance/control: **NO** (offline only)\n');
    fprintf(fid, '- Artifacts: `%s`, `%s`, `%s`\n', R.paths.md, R.paths.mat, R.paths.png);
    fprintf(fid, '- Did **not** touch `CODEX_VERTICAL_PLAN.md`\n');
    fprintf(fid, '- Never claim hardware validation\n\n');

    fprintf(fid, '## Noise case (TEST ASSUMPTION — not hardware spec)\n\n');
    fprintf(fid, '```\n');
    fprintf(fid, 'INS  Vg_NED  : white noise σ=%.3f m/s/axis @ %.0f Hz ZOH\n', ...
        R.noise.ins_sigma, R.noise.ins_fs);
    fprintf(fid, 'DVL  Vw_BODY : white noise σ=%.3f m/s/axis @ %.0f Hz ZOH\n', ...
        R.noise.dvl_sigma, R.noise.dvl_fs);
    fprintf(fid, 'Independent; bias=0; delay=0; rng(%d)\n', R.noise.seed);
    fprintf(fid, 'Rotate noisy DVL with truth R; y_c = Vg_noisy - R*Vw_noisy\n');
    fprintf(fid, '```\n\n');

    fprintf(fid, '## Observer (unchanged)\n\n');
    fprintf(fid, '- wo=%.2f rad/s, Vhat(0)=0, bound ±%.1f m/s — **no tuning**\n', ...
        R.observer.wo, R.observer.bound);
    fprintf(fid, '- Steady window: t >= %.1f s (post ~5/wo)\n', R.steady_t0);
    fprintf(fid, '- True Vc = [%.2f, %.2f, %.2f] m/s NED; U=%.1f m/s\n\n', R.Vc_true, R.Uref);

    fprintf(fid, '## Per-route metrics (noisy vs ideal)\n\n');
    fprintf(fid, '| Route | bias||mean|| | RMSE_ss | p95_ss | final||err|| | settle [s] | hits | ideal final | Δfinal | PASS |\n');
    fprintf(fid, '|---|---:|---:|---:|---:|---:|---:|---:|---:|:---:|\n');
    names = {'X','XZ','R10'};
    for i = 1:3
        O = R.routes.(names{i});
        C = O.compare;
        pass_r = O.pass_bias && O.pass_rmse && O.pass_p95 && O.pass_final && ...
            O.pass_bounded && O.pass_no_hits;
        fprintf(fid, '| %s | %.4e | %.4e | %.4e | %.4e | %.3f | %d | %.3e | %.3e | %s |\n', ...
            names{i}, O.steady.bias_norm, O.steady.rmse_norm, O.steady.p95_norm, ...
            O.err_final_norm, O.settle_time, O.bound_hits, C.ideal_final_norm, ...
            C.delta_final_norm, yn(pass_r));
    end
    fprintf(fid, '\n');

    fprintf(fid, '### Component steady bias / RMS / max (noisy)\n\n');
    fprintf(fid, '| Route | bias_N | bias_E | bias_D | rms_N | rms_E | rms_D | max_N | max_E | max_D |\n');
    fprintf(fid, '|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|\n');
    for i = 1:3
        O = R.routes.(names{i});
        fprintf(fid, '| %s | %.3e | %.3e | %.3e | %.3e | %.3e | %.3e | %.3e | %.3e | %.3e |\n', ...
            names{i}, O.steady.bias(1), O.steady.bias(2), O.steady.bias(3), ...
            O.steady.rms(1), O.steady.rms(2), O.steady.rms(3), ...
            O.steady.max(1), O.steady.max(2), O.steady.max(3));
    end
    fprintf(fid, '\n');

    fprintf(fid, '## Attitude / route dependence\n\n');
    fprintf(fid, '| Route | psi range [deg] | theta range [deg] |\n|---|---:|---:|\n');
    for i = 1:3
        O = R.routes.(names{i});
        fprintf(fid, '| %s | [%.2f, %.2f] | [%.2f, %.2f] |\n', names{i}, ...
            O.psi_range_deg(1), O.psi_range_deg(2), O.theta_range_deg(1), O.theta_range_deg(2));
    end
    fprintf(fid, '\n- %s\n\n', R.route_dependence.note);

    fprintf(fid, '## Raw innovations saved\n\n');
    fprintf(fid, '- Per route: `innovation` (= noisy y_c), `innovation_t` (sim timestamps),\n');
    fprintf(fid, '  `t_ins_updates`, `t_dvl_updates`, `n_ins`, `n_dvl` in `.mat`\n\n');

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
    fprintf(fid, '- Read-only: `run_current_observer_ideal.m`, `CURRENT_OBSERVER_IDEAL.mat`, `BOUNDED_CURRENT_HOOK.mat`\n');
    fprintf(fid, '- Ideal observer PASS; production + current hook untouched; offline only\n');
    fprintf(fid, '- Driver: `run_current_observer_noise.m` (one invocation)\n');
    fprintf(fid, '- Artifacts: `%s`, `%s`, `%s`\n', R.paths.md, R.paths.mat, R.paths.png);
    fprintf(fid, '- Did not touch `CODEX_VERTICAL_PLAN.md`\n\n');
    fprintf(fid, '### Noise case (TEST ASSUMPTION — not hardware)\n\n');
    fprintf(fid, '```\nINS σ=%.3f m/s @ %.0f Hz ZOH; DVL σ=%.3f m/s @ %.0f Hz ZOH;\n', ...
        R.noise.ins_sigma, R.noise.ins_fs, R.noise.dvl_sigma, R.noise.dvl_fs);
    fprintf(fid, 'independent, bias=0, delay=0, rng(%d); y_c=Vg-R*Vw (truth R);\n', R.noise.seed);
    fprintf(fid, 'same observer wo=%.2f (no tuning); steady t>=%.1f s\n```\n\n', ...
        R.observer.wo, R.steady_t0);
    fprintf(fid, '### Verdict\n\n');
    fprintf(fid, '**%s** — declared synthetic noise case only (not hardware; bias/latency deferred).\n\n', R.verdict);
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
    fprintf(fid, '\n### Route/attitude note\n\n');
    fprintf(fid, '%s\n\n', R.route_dependence.note);
    fprintf(fid, '### Next\n\n');
    fprintf(fid, '- `%s` — %s\n', R.next.gate, R.next.detail);
    fprintf(fid, '- Never feed observer to control; never promote to production.\n');
    fclose(fid);
end

function print_feedback(R)
    fprintf('\n========== FEEDBACK ==========\n');
    fprintf('VERDICT: %s (declared noise case only)\n', R.verdict);
    fprintf('bias max: %.6e  RMSE max: %.6e  p95 max: %.6e  final max: %.6e\n', ...
        R.summary.bias_norm_max_all, R.summary.rmse_norm_max_all, ...
        R.summary.p95_norm_max_all, R.summary.final_err_max_all);
    fprintf('bound hits: %d\n', R.summary.bound_hits_total);
    names = {'X','XZ','R10'};
    for i = 1:3
        O = R.routes.(names{i});
        fprintf('%s: bias=%.3e rmse=%.3e p95=%.3e final=%.3e hits=%d\n', ...
            names{i}, O.steady.bias_norm, O.steady.rmse_norm, O.steady.p95_norm, ...
            O.err_final_norm, O.bound_hits);
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
