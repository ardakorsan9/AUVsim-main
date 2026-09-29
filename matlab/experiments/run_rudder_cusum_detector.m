function run_rudder_cusum_detector()
% RUDDER_CUSUM_DETECTOR_001
% One-sided CUSUM / change detector on frozen B2 residual (sensor-only).
% Read-only sources (max 3):
%   1) suite_results/RUDDER_FAULT_MAG_SPEED_COVERAGE.mat
%   2) suite_results/SPEED_ENVELOPE_AUDIT.mat
%   3) suite_results/RUDDER_MONITOR_NOISE_DELAY_STRESS.md  (declared corruption)
% No NL rerun. Do not alter B2/G_nom. Never feed applied rudder / eta / labels
% into the detector (labels used only for post-hoc scoring after replay).
% Calibrate (kappa,h) on nominal R10 + synthetic corruption with TRAIN seeds;
% freeze before opening fault data. Validate FA + 9-cell noisy replay on
% disjoint VAL seeds.
% Coverage PASS iff every cell Pd>=95%, p95 delay<=3 s, agg unseen-nominal FA<=1%.
% Artifacts: suite_results/RUDDER_CUSUM_DETECTOR.{md,mat,png}
% Appends suite_results/PITCH_CONTROL_RESEARCH_LOG.md
% Does NOT touch CODEX_VERTICAL_PLAN.md. Production frozen.

    project_dir = fileparts(fileparts(fileparts(mfilename('fullpath')))); % repo root
    addpath(genpath(fullfile(project_dir, 'matlab')));
    out_dir = fullfile(project_dir, 'suite_results');
    tag = 'RUDDER_CUSUM_DETECTOR';
    task_id = 'RUDDER_CUSUM_DETECTOR_001';
    stamp = datestr(now, 'yyyy-mm-dd HH:MM:SS');

    cov_mat = fullfile(out_dir, 'RUDDER_FAULT_MAG_SPEED_COVERAGE.mat');
    env_mat = fullfile(out_dir, 'SPEED_ENVELOPE_AUDIT.mat');
    stress_md = fullfile(out_dir, 'RUDDER_MONITOR_NOISE_DELAY_STRESS.md');
    assert(exist(cov_mat, 'file') == 2, 'Missing %s', cov_mat);
    assert(exist(env_mat, 'file') == 2, 'Missing %s', env_mat);
    assert(exist(stress_md, 'file') == 2, 'Missing %s', stress_md);

    fprintf('\n========== %s ==========\n', task_id);
    fprintf('CUSUM on frozen B2 residual; calibrate on nominal only; no NL rerun.\n');

    Cov = load(cov_mat);
    Env = load(env_mat);
    assert(isfield(Cov, 'points') && isfield(Cov, 'frozen') && isfield(Cov, 'U_grid'), ...
        'Coverage MAT incomplete');
    assert(isfield(Env, 'Cert') && isfield(Env.Cert, 'intersection_U'), ...
        'SPEED_ENVELOPE_AUDIT incompatible');

    frozen = Cov.frozen;
    assert(~frozen.retuned, 'Frozen B2 must not be retuned');
    U_grid = Cov.U_grid(:).';
    eta_grid = Cov.eta_grid(:).';
    points = Cov.points;
    nU = numel(U_grid); nE = numel(eta_grid);
    assert(nU == 3 && nE == 3 && isequal(size(points), [nU, nE]));

    for iu = 1:nU
        assert(any(abs(Env.Cert.intersection_U(:) - U_grid(iu)) < 1e-9), ...
            'U=%.2f not in certified intersection', U_grid(iu));
    end

    % Declared synthetic corruption (from RUDDER_MONITOR_NOISE_DELAY_STRESS.md)
    sens = declared_sensor_envelope();
    sens.source_doc = 'suite_results/RUDDER_MONITOR_NOISE_DELAY_STRESS.md';

    % ----- Published disjoint seed split (twister) -----
    seeds_train = (2101:2120).';   % calibrate kappa,h ONLY
    seeds_val   = (3101:3140).';   % unseen nominal FA + fault replay
    assert(isempty(intersect(seeds_train, seeds_val)), 'Train/val seed leakage');
    seed_split = struct( ...
        'train', seeds_train, ...
        'val', seeds_val, ...
        'policy', 'fixed published TRAIN=2101:2120 VAL=3101:3140 (twister); disjoint', ...
        'disjoint_from_prior_stress_1001_1040', ...
            isempty(intersect([seeds_train; seeds_val], (1001:1040).')));

    gates = struct('Pd_min', 0.95, 'delay_p95_max_s', 3.0, 'FA_sample_max_pct', 1.0);

    % =====================================================================
    % PHASE A — NOMINAL ONLY (pre-fault R10). Do NOT open post-fault yet.
    % Nominal streams: all certified U pre-fault (eta-independent before inject).
    % =====================================================================
    noms = cell(nU, 1);
    for iu = 1:nU
        P_u = points{iu, 1};
        noms{iu} = truncate_prefault(P_u.log, P_u.S_meta.t_fault_s);
        noms{iu}.u0 = U_grid(iu);
        noms{iu}.source = sprintf('coverage U=%.2f pre-fault (t<%.2fs)', ...
            P_u.u0, P_u.S_meta.t_fault_s);
        fprintf('PHASE A nominal[%d]: %s | n=%d\n', iu, noms{iu}.source, numel(noms{iu}.t));
    end

    % --- Calibrate kappa,h on TRAIN seeds (all-U nominal + declared corruption) ---
    cal = calibrate_cusum(noms, frozen, sens, seeds_train, gates);
    fprintf('FROZEN CUSUM: kappa=%.6f  h=%.6f  (selected on TRAIN only)\n', ...
        cal.kappa, cal.h);
    fprintf('  selection: %s\n', cal.selection_rule);
    fprintf('  train FA_latched=%.4f%%  max_q_train=%.4f\n', ...
        cal.train_FA_latched_pct, cal.train_max_q);

    cusum_cfg = struct( ...
        'kappa', cal.kappa, ...
        'h', cal.h, ...
        'eps_dr_rad', frozen.eps_dr_rad, ...
        'u_floor', frozen.u_floor, ...
        't_warmup_s', frozen.t_warmup_s, ...
        'G_nom', frozen.G_nom, ...
        'dt', frozen.dt, ...
        'frozen_at', stamp, ...
        'frozen_before_fault_open', true);

    % --- Unseen-nominal FA on VAL seeds (still pre-fault only; all U) ---
    fprintf('PHASE A.2 unseen-nominal FA on VAL seeds (all U pre-fault)...\n');
    FA = struct();
    FA.n_latched_tot = 0;
    FA.n_post_tot = 0;
    FA.per_U = repmat(struct('u0', NaN, 'FA_latched_pct', NaN, ...
        'n_latched', 0, 'n_post', 0), nU, 1);
    FA.per_seed = [];
    for iu = 1:nU
        nom_u = noms{iu};
        n_lat_U = 0; n_post_U = 0;
        for is = 1:numel(seeds_val)
            seed = seeds_val(is);
            rng(seed, 'twister');
            [uC, rC] = corrupt_sensors(nom_u.t, nom_u.u, nom_u.r, sens);
            stream = struct('t', nom_u.t, 'delta_r_cmd', nom_u.delta_r_cmd, ...
                'r', rC, 'u', uC);
            logC = replay_cusum(stream, cusum_cfg);
            mask_w = logC.t > cusum_cfg.t_warmup_s;
            n_post = sum(mask_w);
            n_lat = sum(mask_w & logC.alarm);
            n_lat_U = n_lat_U + n_lat;
            n_post_U = n_post_U + n_post;
            FA.per_seed = [FA.per_seed; struct( ...
                'seed', seed, 'u0', U_grid(iu), ...
                'FA_latched_pct', 100 * n_lat / max(n_post, 1), ...
                'n_latched', n_lat, 'n_post', n_post)]; %#ok<AGROW>
        end
        FA.per_U(iu).u0 = U_grid(iu);
        FA.per_U(iu).n_latched = n_lat_U;
        FA.per_U(iu).n_post = n_post_U;
        FA.per_U(iu).FA_latched_pct = 100 * n_lat_U / max(n_post_U, 1);
        FA.n_latched_tot = FA.n_latched_tot + n_lat_U;
        FA.n_post_tot = FA.n_post_tot + n_post_U;
        fprintf('  U=%.2f VAL FA_latched=%.4f%% (%d/%d)\n', ...
            U_grid(iu), FA.per_U(iu).FA_latched_pct, n_lat_U, n_post_U);
    end
    FA.FA_agg_latched_pct = 100 * FA.n_latched_tot / max(FA.n_post_tot, 1);
    FA.g_FA = (FA.FA_agg_latched_pct <= gates.FA_sample_max_pct);
    fprintf('  AGG unseen-nominal FA=%.4f%%  gate<=1%% → %s\n', ...
        FA.FA_agg_latched_pct, tern(FA.g_FA, 'YES', 'NO'));

    no_leakage = struct();
    no_leakage.calibrated_on_fault_post = false;
    no_leakage.used_delta_r_app = false;
    no_leakage.used_eta_r_in_detector = false;
    no_leakage.labels_in_detector = false;
    no_leakage.train_val_seed_disjoint = true;
    no_leakage.kappa_h_frozen_before_fault_open = true;
    no_leakage.B2_G_nom_altered = false;
    no_leakage.proof = [ ...
        'PHASE A used only pre-fault (t<t_f) streams + TRAIN seeds to select ', ...
        '(kappa,h); cusum_cfg frozen; PHASE B then opened post-fault logs for ', ...
        'VAL-seed noisy replay; fault labels / eta / delta_r_app used only in ', ...
        'post-hoc scoring after replay; residual uses frozen G_nom unchanged.'];

    % =====================================================================
    % PHASE B — Open fault data. Noisy replay all 9 cells × VAL seeds.
    % =====================================================================
    fprintf('PHASE B: open fault data; VAL-seed noisy replay of 9 cells...\n');
    cells = cell(nU, nE);
    ex_mild = struct();  % example for plot: first miss-prone cell U1.5/eta0.75

    for iu = 1:nU
        for ie = 1:nE
            P = points{iu, ie};
            tf = P.S_meta.t_fault_s;
            truth = struct('t', P.log.t(:), 'delta_r_cmd', P.log.delta_r_cmd(:), ...
                'r', P.log.r(:), 'u', P.log.u(:), 't_fault_s', tf);
            % Clean reference residuals already in P.log.residual (B2 frozen)

            n_seeds = numel(seeds_val);
            per = repmat(empty_seed_row(), n_seeds, 1);
            per_B2 = per;

            for is = 1:n_seeds
                seed = seeds_val(is);
                rng(seed, 'twister');
                [uC, rC] = corrupt_sensors(truth.t, truth.u, truth.r, sens);
                stream = struct('t', truth.t, 'delta_r_cmd', truth.delta_r_cmd, ...
                    'r', rC, 'u', uC);

                % CUSUM detector (local)
                logC = replay_cusum(stream, cusum_cfg);
                per(is) = score_detection(logC, tf, seed);

                % Frozen B2 threshold+persist comparator (local; no retune)
                logB = replay_B2(stream, frozen);
                per_B2(is) = score_detection(logB, tf, seed);

                if iu == 1 && ie == 1 && is == 1
                    ex_mild.seed = seed;
                    ex_mild.u0 = P.u0;
                    ex_mild.eta = P.eta_post;
                    ex_mild.tf = tf;
                    ex_mild.logC = logC;
                    ex_mild.logB = logB;
                    ex_mild.stream = stream;
                    ex_mild.truth = truth;
                end
            end

            Ccell = aggregate_cell(per, gates);
            Bcell = aggregate_cell(per_B2, gates);
            Ccell.u0 = P.u0;
            Ccell.eta_post = P.eta_post;
            Ccell.loss_pct = P.loss_pct;
            Ccell.t_fault_s = tf;
            Ccell.B2_clean_detected = P.det.detected;
            Ccell.B2_clean_delay_s = P.det.delay_s;
            Ccell.per_seed = per;
            Ccell.B2 = Bcell;
            Ccell.B2.per_seed = per_B2;
            Ccell.cell_pass = (Ccell.Pd >= gates.Pd_min) && ...
                isfinite(Ccell.delay_p95_s) && (Ccell.delay_p95_s <= gates.delay_p95_max_s);
            cells{iu, ie} = Ccell;

            fprintf(['  U=%.2f eta=%.2f | CUSUM Pd=%.1f%% med/p95=%.3f/%.3f miss=%d ', ...
                'preFA=%d | B2 Pd=%.1f%% p95=%.3f | cell=%s\n'], ...
                P.u0, P.eta_post, 100*Ccell.Pd, Ccell.delay_median_s, Ccell.delay_p95_s, ...
                Ccell.n_missed, Ccell.n_prefault, 100*Bcell.Pd, Bcell.delay_p95_s, ...
                tern(Ccell.cell_pass, 'PASS', 'FAIL'));
        end
    end

    % ----- Aggregate coverage -----
    Pd_mat = nan(nU, nE);
    p95_mat = nan(nU, nE);
    med_mat = nan(nU, nE);
    miss_mat = nan(nU, nE);
    pre_mat = nan(nU, nE);
    pass_mat = false(nU, nE);
    B2_Pd = nan(nU, nE);
    B2_p95 = nan(nU, nE);
    for iu = 1:nU
        for ie = 1:nE
            C = cells{iu, ie};
            Pd_mat(iu, ie) = C.Pd;
            p95_mat(iu, ie) = C.delay_p95_s;
            med_mat(iu, ie) = C.delay_median_s;
            miss_mat(iu, ie) = C.n_missed;
            pre_mat(iu, ie) = C.n_prefault;
            pass_mat(iu, ie) = C.cell_pass;
            B2_Pd(iu, ie) = C.B2.Pd;
            B2_p95(iu, ie) = C.B2.delay_p95_s;
        end
    end
    cells_all_pass = all(pass_mat(:));
    coverage_pass = cells_all_pass && FA.g_FA;
    if coverage_pass
        coverage_verdict = 'PASS';
        next_priority = 'fault_isolation_safe_mode_requirements_audit';
        next_note = [ ...
            'Coverage PASS → next: fault-isolation / safe-mode requirements audit; ', ...
            'production remains frozen.'];
    else
        coverage_verdict = 'FAIL';
        next_priority = 'close_sensor_only_mild_loss_require_actuator_feedback_or_richer_ID';
        next_note = [ ...
            'Coverage FAIL → close sensor-only mild-loss line; require actuator ', ...
            'feedback and/or richer identification before further promotion.'];
    end

    eq = struct();
    eq.residual = 'r_B2 = max(0, 1 - r/(max(u,u_floor)^2 * delta_r_cmd) / G_nom)  [frac]';
    eq.cusum = 'q_k = max(0, q_{k-1} + r_B2,k - kappa) when gated; else q_k=0 (reset)';
    eq.alarm = 'alarm if q_k > h; latch until reset; warmup t<=t_warmup: no accumulate';
    eq.units = struct('r_B2', 'dimensionless frac-loss proxy', ...
        'kappa', 'same as r_B2 (frac)', 'h', 'CUSUM score (frac·samples)', ...
        'q', 'CUSUM score (frac·samples)', 'G_nom', '1/(m^2·rad)', ...
        'r', 'rad/s', 'u', 'm/s', 'delta_r_cmd', 'rad');

    R = struct();
    R.task_id = task_id;
    R.stamp = stamp;
    R.tag = tag;
    R.frozen_B2 = frozen;
    R.cusum_cfg = cusum_cfg;
    R.calibration = cal;
    R.seed_split = seed_split;
    R.sensor = sens;
    R.equations = eq;
    R.no_leakage = no_leakage;
    R.FA_nominal_val = FA;
    R.U_grid = U_grid;
    R.eta_grid = eta_grid;
    R.cells = cells;
    R.matrix = struct('Pd', Pd_mat, 'delay_median_s', med_mat, ...
        'delay_p95_s', p95_mat, 'n_missed', miss_mat, 'n_prefault', pre_mat, ...
        'cell_pass', pass_mat, 'B2_Pd', B2_Pd, 'B2_delay_p95_s', B2_p95);
    R.gates = gates;
    R.G = struct( ...
        'cells_all_pass', cells_all_pass, ...
        'g_FA_agg_le_1pct', FA.g_FA, ...
        'coverage_pass', coverage_pass, ...
        'coverage_verdict', coverage_verdict, ...
        'next_priority', next_priority, ...
        'next_note', next_note);
    R.verdict = coverage_verdict;
    R.example_mild = ex_mild;
    R.production_untouched = true;
    R.nonlinear_rerun = false;
    R.B2_altered = false;
    R.sources_read = { ...
        'suite_results/RUDDER_FAULT_MAG_SPEED_COVERAGE.mat'; ...
        'suite_results/SPEED_ENVELOPE_AUDIT.mat'; ...
        'suite_results/RUDDER_MONITOR_NOISE_DELAY_STRESS.md'};

    mat_path = fullfile(out_dir, [tag '.mat']);
    png_path = fullfile(out_dir, [tag '.png']);
    md_path  = fullfile(out_dir, [tag '.md']);
    save(mat_path, 'R', 'frozen', 'cusum_cfg', 'cal', 'FA', 'cells', 'gates', '-v7.3');
    write_png(png_path, R);
    write_md(md_path, R);
    append_log(out_dir, R);

    fprintf('\n--- %s ---\n', task_id);
    fprintf('Coverage: %s | cells_all=%s FA_agg=%.4f%%\n', ...
        coverage_verdict, tern(cells_all_pass, 'YES', 'NO'), FA.FA_agg_latched_pct);
    fprintf('Next: %s\n', next_priority);
    fprintf('Saved %s\n', mat_path);
    fprintf('Saved %s\n', png_path);
    fprintf('Saved %s\n', md_path);
end

%% ===================== calibration (nominal only) =====================
function cal = calibrate_cusum(noms, frozen, sens, seeds_train, gates)
% Select kappa,h on TRAIN-corrupt nominal only (all U pre-fault). No fault post.
    if ~iscell(noms); noms = {noms}; end
    n_tr = numel(seeds_train);
    n_nom = numel(noms);
    resid_pool = [];
    logs = {};  % one entry per (nom, seed)
    for iu = 1:n_nom
        nom = noms{iu};
        for i = 1:n_tr
            rng(seeds_train(i), 'twister');
            [uC, rC] = corrupt_sensors(nom.t, nom.u, nom.r, sens);
            stream = struct('t', nom.t, 'delta_r_cmd', nom.delta_r_cmd, 'r', rC, 'u', uC);
            logR = replay_residual_only(stream, frozen);
            logs{end+1} = struct('stream', stream, 'residual', logR.residual, ...
                'gated', logR.gated, 't', logR.t, 'u0', nom.u0); %#ok<AGROW>
            g = logR.gated & isfinite(logR.residual) & (logR.t > frozen.t_warmup_s);
            resid_pool = [resid_pool; logR.residual(g)]; %#ok<AGROW>
        end
    end
    assert(~isempty(resid_pool), 'Empty train residual pool');
    n_logs = numel(logs);

    mu0 = mean(resid_pool);
    sd0 = std(resid_pool);
    p80 = prctile(resid_pool, 80);
    p90 = prctile(resid_pool, 90);
    % Kappa grid in [mu0, p80] — Page allowance under H0; avoid kappa>~p90 (fragile tiny h)
    n_grid = 12;
    lo = max(mu0, 1e-4);
    hi = max(p80, lo + 1e-4);
    kappa_cands = unique([linspace(lo, hi, n_grid).'; mu0; mu0 + 0.5*sd0; ...
        prctile(resid_pool, [60 70 75 80]).']);
    kappa_cands = kappa_cands(isfinite(kappa_cands) & (kappa_cands >= lo - 1e-12) ...
        & (kappa_cands <= p90 + 1e-12));
    if isempty(kappa_cands)
        kappa_cands = lo;
    end

    % Recipe: h = 1.5*max_q_train + 0.25 (declared margin); require train FA gate
    % Among FA-safe, pick smallest kappa (sensitivity to mild positive mean shift).
    best = struct('score', Inf, 'kappa', NaN, 'h', NaN, 'FA', Inf, 'max_q', NaN);
    trials = [];
    for ik = 1:numel(kappa_cands)
        kappa = kappa_cands(ik);
        max_q_seeds = zeros(n_logs, 1);
        cfg0 = local_cusum_cfg(frozen, kappa, 1e9);
        for i = 1:n_logs
            logC = replay_cusum(logs{i}.stream, cfg0);
            mq = max(logC.q(isfinite(logC.q)));
            if ~isfinite(mq); mq = 0; end
            max_q_seeds(i) = mq;
        end
        q_peak = max(max_q_seeds);
        h = 1.5 * q_peak + 0.25;  % fixed declared margin recipe
        cfg = local_cusum_cfg(frozen, kappa, h);
        n_lat = 0; n_post = 0; n_any_alarm = 0;
        for i = 1:n_logs
            logC = replay_cusum(logs{i}.stream, cfg);
            mask_w = logC.t > frozen.t_warmup_s;
            n_post = n_post + sum(mask_w);
            n_lat = n_lat + sum(mask_w & logC.alarm);
            n_any_alarm = n_any_alarm + double(any(logC.alarm(mask_w)));
        end
        FA_pct = 100 * n_lat / max(n_post, 1);
        trial = struct('kappa', kappa, 'h', h, 'FA_pct', FA_pct, ...
            'max_q', q_peak, 'n_alarm_seeds', n_any_alarm);
        trials = [trials; trial]; %#ok<AGROW>
        if FA_pct > gates.FA_sample_max_pct
            continue;
        end
        % Prefer smallest kappa among FA-safe (mild-shift sensitivity)
        score = kappa;
        if score < best.score
            best.score = score;
            best.kappa = kappa;
            best.h = h;
            best.FA = FA_pct;
            best.max_q = q_peak;
        end
    end

    if ~isfinite(best.kappa)
        % Fallback: kappa = p80, h = 1.5*max_q + 0.25
        kappa = max(p80, lo);
        cfg0 = local_cusum_cfg(frozen, kappa, 1e9);
        mq = 0;
        for i = 1:n_logs
            logC = replay_cusum(logs{i}.stream, cfg0);
            mq = max(mq, max(logC.q(isfinite(logC.q))));
        end
        best.kappa = kappa;
        best.h = 1.5 * mq + 0.25;
        best.FA = NaN;
        best.max_q = mq;
        best.score = Inf;
    end

    % Final train FA with frozen pair
    cfg = local_cusum_cfg(frozen, best.kappa, best.h);
    n_lat = 0; n_post = 0;
    for i = 1:n_logs
        logC = replay_cusum(logs{i}.stream, cfg);
        mask_w = logC.t > frozen.t_warmup_s;
        n_post = n_post + sum(mask_w);
        n_lat = n_lat + sum(mask_w & logC.alarm);
    end

    cal = struct();
    cal.kappa = best.kappa;
    cal.h = best.h;
    cal.train_FA_latched_pct = 100 * n_lat / max(n_post, 1);
    cal.train_max_q = best.max_q;
    cal.resid_train = resid_stats(resid_pool);
    cal.mu0 = mu0;
    cal.sd0 = sd0;
    cal.p80 = p80;
    cal.kappa_candidates = kappa_cands;
    cal.n_trials = numel(trials);
    if isempty(trials)
        cal.n_trials_accepted = 0;
    else
        cal.n_trials_accepted = sum([trials.FA_pct] <= gates.FA_sample_max_pct);
    end
    cal.n_logs = n_logs;
    cal.selection_rule = [ ...
        'TRAIN only (all-U R10 pre-fault + declared corruption): ', ...
        'kappa ∈ [μ0, p80(r_B2_gated)] grid; h := 1.5·max_q_train + 0.25; ', ...
        'accept if train FA_latched_samples ≤ 1%; among accepted pick smallest kappa ', ...
        '(Page H0 allowance + mild-shift sensitivity). Freeze before post-fault open.'];
    cal.seeds_train = seeds_train;
    cal.nom_source = strjoin(cellfun(@(n) n.source, noms, 'uni', 0), ' | ');
end

function cfg = local_cusum_cfg(frozen, kappa, h)
    cfg = struct( ...
        'kappa', kappa, 'h', h, ...
        'eps_dr_rad', frozen.eps_dr_rad, ...
        'u_floor', frozen.u_floor, ...
        't_warmup_s', frozen.t_warmup_s, ...
        'G_nom', frozen.G_nom, ...
        'dt', frozen.dt);
end

%% ===================== streams / corruption =====================
function nom = truncate_prefault(log, tf)
    mask = log.t(:) < tf;
    nom = struct();
    nom.t = log.t(mask);
    nom.delta_r_cmd = log.delta_r_cmd(mask);
    nom.r = log.r(mask);
    nom.u = log.u(mask);
end

function sens = declared_sensor_envelope()
% Exact declared envelope from RUDDER_MONITOR_NOISE_DELAY_STRESS.md
    sens = struct();
    sens.dvl_sigma_mps = 0.010;
    sens.dvl_fs_hz = 5;
    sens.dvl_bias_mps = +0.005;
    sens.dvl_latency_s = 0.200;
    sens.imu_sigma_degs = 0.20;
    sens.imu_sigma_rads = deg2rad(sens.imu_sigma_degs);
    sens.imu_fs_hz = 100;
    sens.imu_bias_degs = +0.05;
    sens.imu_bias_rads = deg2rad(sens.imu_bias_degs);
    sens.imu_latency_s = 0.050;
    sens.imu_status = 'ASSUMED';
    sens.delay_model = 'causal_timestamp_ZOH';
    sens.note = [ ...
        'DVL: σ=0.010 m/s @ 5 Hz ZOH, bias=+0.005 m/s, lat=200 ms (CURRENT_OBSERVER). ', ...
        'IMU ASSUMED: σ=0.20 deg/s @ 100 Hz ZOH, bias=+0.05 deg/s, lat=50 ms.'];
end

function [u_out, r_out] = corrupt_sensors(t, u_truth, r_truth, sens)
    u_out = async_zoh_corrupt(t, u_truth, sens.dvl_fs_hz, sens.dvl_sigma_mps, ...
        sens.dvl_bias_mps, sens.dvl_latency_s);
    r_out = async_zoh_corrupt(t, r_truth, sens.imu_fs_hz, sens.imu_sigma_rads, ...
        sens.imu_bias_rads, sens.imu_latency_s);
end

function y_hold = async_zoh_corrupt(t, y_truth, fs, sigma, bias, latency_s)
    t = t(:); y_truth = y_truth(:);
    t0 = t(1); t1 = t(end);
    dt_u = 1 / fs;
    t_src = (t0:dt_u:t1).';
    if isempty(t_src); t_src = t0; end
    n_upd = numel(t_src);
    y_src = interp1(t, y_truth, t_src, 'linear', 'extrap') + bias + sigma * randn(n_upd, 1);
    t_avail = t_src + latency_s;
    y_hold = nan(size(t));
    j = 0;
    for k = 1:numel(t)
        while (j < n_upd) && (t_avail(j + 1) <= t(k) + 1e-15)
            j = j + 1;
        end
        if j >= 1
            y_hold(k) = y_src(j);
        else
            y_hold(k) = y_truth(1) + bias;
        end
    end
end

%% ===================== local residual + CUSUM + B2 =====================
function [residual, gated, g_hat] = compute_rB2(dr, r, u, cfg)
    residual = NaN; gated = false; g_hat = NaN;
    if ~(isfinite(dr) && isfinite(r) && isfinite(u)); return; end
    u_eff = max(u, cfg.u_floor);
    if abs(dr) > eps(1)
        g_hat = r / (u_eff^2 * dr);
        residual = max(0, 1 - g_hat / cfg.G_nom);
        if ~isfinite(residual); residual = 0; end
    else
        residual = 0;
    end
end

function log = replay_residual_only(stream, frozen)
    n = numel(stream.t);
    log = struct('t', stream.t(:), 'residual', nan(n,1), 'gated', false(n,1));
    cfg = frozen;
    for k = 1:n
        warmed = stream.t(k) > cfg.t_warmup_s;
        [res, ~, ~] = compute_rB2(stream.delta_r_cmd(k), stream.r(k), stream.u(k), cfg);
        valid = isfinite(stream.t(k)) && isfinite(stream.delta_r_cmd(k)) && ...
            isfinite(stream.r(k)) && isfinite(stream.u(k));
        gated = valid && warmed && (abs(stream.delta_r_cmd(k)) > cfg.eps_dr_rad);
        log.residual(k) = res;
        log.gated(k) = gated;
    end
end

function log = replay_cusum(stream, cfg)
% Local stateful one-sided CUSUM on frozen B2 residual.
% q_k = max(0, q_{k-1} + r_B2 - kappa) when gated & warmed & valid; else reset q=0.
% Alarm latch when q_k > h.
    n = numel(stream.t);
    log = struct();
    log.t = stream.t(:);
    log.residual = nan(n, 1);
    log.gated = false(n, 1);
    log.q = zeros(n, 1);
    log.alarm = false(n, 1);
    log.newly_alarmed = false(n, 1);
    q = 0;
    latched = false;
    t_alarm = NaN;
    for k = 1:n
        t = stream.t(k);
        dr = stream.delta_r_cmd(k);
        r = stream.r(k);
        u = stream.u(k);
        warmed = isfinite(t) && (t > cfg.t_warmup_s);
        valid = isfinite(t) && isfinite(dr) && isfinite(r) && isfinite(u);
        gated = valid && warmed && (abs(dr) > cfg.eps_dr_rad);
        [res, ~, ~] = compute_rB2(dr, r, u, cfg);
        log.residual(k) = res;
        log.gated(k) = gated;

        if gated && isfinite(res)
            q = max(0, q + res - cfg.kappa);
        else
            q = 0;  % reset on ungated / invalid / warmup
        end
        log.q(k) = q;

        newly = false;
        if (~latched) && (q > cfg.h)
            latched = true;
            t_alarm = t;
            newly = true;
        end
        log.alarm(k) = latched;
        log.newly_alarmed(k) = newly;
    end
    log.t_alarm_s = t_alarm;
    log.alarm_latched_final = latched;
end

function log = replay_B2(stream, frozen)
% Local frozen B2 threshold + persistence (comparator; no retune).
    n = numel(stream.t);
    log = struct();
    log.t = stream.t(:);
    log.residual = nan(n, 1);
    log.gated = false(n, 1);
    log.q = nan(n, 1);  % unused
    log.alarm = false(n, 1);
    log.newly_alarmed = false(n, 1);
    persist = 0;
    latched = false;
    t_alarm = NaN;
    for k = 1:n
        t = stream.t(k);
        dr = stream.delta_r_cmd(k);
        r = stream.r(k);
        u = stream.u(k);
        warmed = isfinite(t) && (t > frozen.t_warmup_s);
        valid = isfinite(t) && isfinite(dr) && isfinite(r) && isfinite(u);
        gated = valid && warmed && (abs(dr) > frozen.eps_dr_rad);
        [res, ~, ~] = compute_rB2(dr, r, u, frozen);
        log.residual(k) = res;
        log.gated(k) = gated;
        above = gated && isfinite(res) && (res > frozen.thr_B2);
        if above
            persist = persist + 1;
        else
            persist = 0;
        end
        newly = false;
        if (~latched) && (persist >= frozen.Np)
            latched = true;
            t_alarm = t;
            newly = true;
        end
        log.alarm(k) = latched;
        log.newly_alarmed(k) = newly;
    end
    log.t_alarm_s = t_alarm;
    log.alarm_latched_final = latched;
end

%% ===================== scoring =====================
function row = empty_seed_row()
    row = struct('seed', NaN, 'detected', false, 'missed', true, ...
        'alarm_before_fault', false, 't_detect_s', NaN, 'delay_s', NaN);
end

function row = score_detection(log, tf, seed)
% Fault labels used ONLY here (post-hoc after causal replay).
    row = empty_seed_row();
    row.seed = seed;
    before = log.t < tf;
    after = log.t >= tf;
    row.alarm_before_fault = any(log.alarm(before));
    idx = find(log.newly_alarmed & after, 1, 'first');
    if isempty(idx)
        idx = find(log.alarm & after, 1, 'first');
    end
    if ~isempty(idx) && ~row.alarm_before_fault
        row.detected = true;
        row.missed = false;
        row.t_detect_s = log.t(idx);
        row.delay_s = row.t_detect_s - tf;
    else
        row.detected = false;
        row.missed = true;
        row.t_detect_s = NaN;
        row.delay_s = NaN;
    end
end

function A = aggregate_cell(per, gates)
    det = [per.detected];
    delays = [per.delay_s];
    delays_ok = delays(det & isfinite(delays));
    A = struct();
    A.n_seeds = numel(per);
    A.n_detected = sum(det);
    A.n_missed = sum([per.missed]);
    A.n_prefault = sum([per.alarm_before_fault]);
    A.Pd = A.n_detected / max(A.n_seeds, 1);
    if isempty(delays_ok)
        A.delay_median_s = NaN;
        A.delay_p95_s = NaN;
    else
        A.delay_median_s = median(delays_ok);
        A.delay_p95_s = prctile(delays_ok, 95);
    end
    A.g_Pd = (A.Pd >= gates.Pd_min);
    A.g_delay = isfinite(A.delay_p95_s) && (A.delay_p95_s <= gates.delay_p95_max_s);
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

function s = yn(v)
    if v; s = 'YES'; else; s = 'NO'; end
end

function s = num_or_nan(x)
    if isfinite(x); s = sprintf('%.3f', x); else; s = 'NaN'; end
end

%% ===================== artifacts =====================
function write_png(png_path, R)
    fig = figure('Visible', 'off', 'Position', [60 40 1400 920]);
    U = R.U_grid; E = R.eta_grid;
    nU = numel(U); nE = numel(E);

    subplot(2, 3, 1);
    imagesc(1:nE, 1:nU, R.matrix.Pd * 100);
    colorbar; caxis([0 100]);
    set(gca, 'XTick', 1:nE, 'XTickLabel', arrayfun(@(x)sprintf('%.2f',x), E, 'uni', 0));
    set(gca, 'YTick', 1:nU, 'YTickLabel', arrayfun(@(x)sprintf('%.2f',x), U, 'uni', 0));
    xlabel('\eta'); ylabel('U [m/s]');
    title(sprintf('CUSUM Pd %% [%s]', R.verdict));
    for iu = 1:nU
        for ie = 1:nE
            text(ie, iu, sprintf('%.0f', 100*R.matrix.Pd(iu,ie)), ...
                'HorizontalAlignment', 'center', 'Color', 'w', 'FontWeight', 'bold');
        end
    end

    subplot(2, 3, 2);
    D = R.matrix.delay_p95_s;
    Dplot = D; Dplot(~isfinite(Dplot)) = NaN;
    imagesc(1:nE, 1:nU, Dplot);
    colorbar;
    set(gca, 'XTick', 1:nE, 'XTickLabel', arrayfun(@(x)sprintf('%.2f',x), E, 'uni', 0));
    set(gca, 'YTick', 1:nU, 'YTickLabel', arrayfun(@(x)sprintf('%.2f',x), U, 'uni', 0));
    xlabel('\eta'); ylabel('U [m/s]');
    title('CUSUM delay p95 [s]');
    for iu = 1:nU
        for ie = 1:nE
            if isfinite(D(iu,ie))
                txt = sprintf('%.2f', D(iu,ie));
            else
                txt = 'MISS';
            end
            text(ie, iu, txt, 'HorizontalAlignment', 'center', 'Color', 'w');
        end
    end

    subplot(2, 3, 3);
    imagesc(1:nE, 1:nU, R.matrix.B2_Pd * 100);
    colorbar; caxis([0 100]);
    set(gca, 'XTick', 1:nE, 'XTickLabel', arrayfun(@(x)sprintf('%.2f',x), E, 'uni', 0));
    set(gca, 'YTick', 1:nU, 'YTickLabel', arrayfun(@(x)sprintf('%.2f',x), U, 'uni', 0));
    xlabel('\eta'); ylabel('U [m/s]');
    title('Frozen B2 Pd %% (same VAL noise)');

    subplot(2, 3, 4);
    ex = R.example_mild;
    plot(ex.logC.t, ex.logC.residual, 'b-'); hold on;
    plot(ex.logC.t, ex.logC.q, 'r-');
    yline(R.cusum_cfg.kappa, 'k--');
    yline(R.cusum_cfg.h, 'm--');
    xline(ex.tf, 'g-.');
    xlabel('t [s]'); ylabel('r_{B2} / q');
    title(sprintf('Example U=%.2f \\eta=%.2f seed %d', ex.u0, ex.eta, ex.seed));
    legend('r_{B2}', 'q', '\kappa', 'h', 't_f', 'Location', 'best');
    grid on;

    subplot(2, 3, 5);
    plot(ex.logC.t, double(ex.logC.alarm), 'r-'); hold on;
    plot(ex.logB.t, double(ex.logB.alarm), 'b--');
    xline(ex.tf, 'g-.');
    ylim([-0.05 1.05]);
    xlabel('t [s]'); ylabel('alarm');
    title('Latch: CUSUM vs B2');
    legend('CUSUM', 'B2', 't_f', 'Location', 'best');
    grid on;

    subplot(2, 3, 6);
    fa_u = [R.FA_nominal_val.per_U.FA_latched_pct];
    bar(fa_u);
    hold on; yline(R.gates.FA_sample_max_pct, 'r--');
    set(gca, 'XTickLabel', arrayfun(@(x)sprintf('%.2f',x), U, 'uni', 0));
    xlabel('U [m/s]'); ylabel('FA latched %');
    title(sprintf('Unseen-nominal FA agg=%.3f%%', R.FA_nominal_val.FA_agg_latched_pct));
    grid on;

    sgtitle(sprintf('%s — %s | \\kappa=%.4f h=%.4f', R.task_id, R.verdict, ...
        R.cusum_cfg.kappa, R.cusum_cfg.h), 'Interpreter', 'none');
    exportgraphics(fig, png_path, 'Resolution', 120);
    close(fig);
end

function write_md(md_path, R)
    fid = fopen(md_path, 'w');
    assert(fid > 0);
    fr = R.frozen_B2;
    c = R.cusum_cfg;
    cal = R.calibration;
    FA = R.FA_nominal_val;
    U = R.U_grid; E = R.eta_grid;

    fprintf(fid, '# RUDDER_CUSUM_DETECTOR\n\n');
    fprintf(fid, '**TASK_ID:** %s\n', R.task_id);
    fprintf(fid, '**Date:** %s\n', R.stamp);
    fprintf(fid, '**Coverage verdict:** **%s**\n\n', R.verdict);
    fprintf(fid, ['One-sided CUSUM on frozen B2 residual. No NL rerun. ', ...
        'B2/G_nom **unchanged**. Production **frozen**. Applied rudder forbidden.\n\n']);

    fprintf(fid, '## Sources (read-only, ≤3)\n\n');
    for i = 1:numel(R.sources_read)
        fprintf(fid, '%d. `%s`\n', i, R.sources_read{i});
    end
    fprintf(fid, '\n');

    fprintf(fid, '## Seed split (published, disjoint)\n\n');
    fprintf(fid, '| Set | Seeds | N | Role |\n|---|---|---:|---|\n');
    fprintf(fid, '| TRAIN | %d:%d | %d | calibrate κ,h on nominal+corruption only |\n', ...
        R.seed_split.train(1), R.seed_split.train(end), numel(R.seed_split.train));
    fprintf(fid, '| VAL | %d:%d | %d | unseen-nominal FA + 9-cell noisy fault replay |\n', ...
        R.seed_split.val(1), R.seed_split.val(end), numel(R.seed_split.val));
    fprintf(fid, '\n- Policy: `%s`\n', R.seed_split.policy);
    fprintf(fid, '- Disjoint from prior stress 1001:1040: **%s**\n\n', ...
        yn(R.seed_split.disjoint_from_prior_stress_1001_1040));

    fprintf(fid, '## Equations / units\n\n');
    fprintf(fid, '```\n');
    fprintf(fid, '%s\n', R.equations.residual);
    fprintf(fid, '%s\n', R.equations.cusum);
    fprintf(fid, '%s\n', R.equations.alarm);
    fprintf(fid, '```\n\n');
    fprintf(fid, '| Symbol | Units |\n|---|---|\n');
    fprintf(fid, '| r_B2 | %s |\n', R.equations.units.r_B2);
    fprintf(fid, '| κ (kappa) | %s |\n', R.equations.units.kappa);
    fprintf(fid, '| h | %s |\n', R.equations.units.h);
    fprintf(fid, '| q | %s |\n', R.equations.units.q);
    fprintf(fid, '| G_nom | %s |\n', R.equations.units.G_nom);
    fprintf(fid, '| r, u, δr_cmd | %s, %s, %s |\n\n', ...
        R.equations.units.r, R.equations.units.u, R.equations.units.delta_r_cmd);

    fprintf(fid, '## Frozen B2 (unchanged) + calibrated CUSUM\n\n');
    fprintf(fid, '| Item | Value |\n|---|---:|\n');
    fprintf(fid, '| G_nom [1/(m^2·rad)] | %.6f |\n', fr.G_nom);
    fprintf(fid, '| thr_B2 [frac] (comparator only) | %.6f |\n', fr.thr_B2);
    fprintf(fid, '| \\|δr\\|_gate [deg] | %.1f |\n', rad2deg(fr.eps_dr_rad));
    fprintf(fid, '| u_floor [m/s] | %.2f |\n', fr.u_floor);
    fprintf(fid, '| Warmup | t > %.1f s |\n', fr.t_warmup_s);
    fprintf(fid, '| B2 Np (comparator) | %d |\n', fr.Np);
    fprintf(fid, '| **κ (CUSUM)** | **%.6f** |\n', c.kappa);
    fprintf(fid, '| **h (CUSUM)** | **%.6f** |\n', c.h);
    fprintf(fid, '| B2/G_nom altered | NO |\n');
    fprintf(fid, '| Retuned B2 | NO |\n\n');

    fprintf(fid, '### Selection rule (TRAIN only)\n\n');
    fprintf(fid, '%s\n\n', cal.selection_rule);
    fprintf(fid, '- Nominal source: `%s`\n', cal.nom_source);
    fprintf(fid, '- Train resid gated: n=%d med=%.4f mean=%.4f p95=%.4f max=%.4f\n', ...
        cal.resid_train.n, cal.resid_train.median, cal.resid_train.mean, ...
        cal.resid_train.p95, cal.resid_train.max);
    fprintf(fid, '- Train FA_latched after freeze: %.4f%% | train max q: %.4f\n', ...
        cal.train_FA_latched_pct, cal.train_max_q);
    fprintf(fid, '- Accepted (κ,h) trials: %d\n\n', cal.n_trials_accepted);

    fprintf(fid, '## No-leakage proof\n\n');
    fprintf(fid, '| Check | Result |\n|---|:---:|\n');
    fprintf(fid, '| Calibrated on fault post-t_f | %s |\n', yn(R.no_leakage.calibrated_on_fault_post));
    fprintf(fid, '| Used δr_app in detector | %s |\n', yn(R.no_leakage.used_delta_r_app));
    fprintf(fid, '| Used η_r in detector | %s |\n', yn(R.no_leakage.used_eta_r_in_detector));
    fprintf(fid, '| Labels in detector update | %s |\n', yn(R.no_leakage.labels_in_detector));
    fprintf(fid, '| Train/val seeds disjoint | %s |\n', yn(R.no_leakage.train_val_seed_disjoint));
    fprintf(fid, '| κ,h frozen before fault open | %s |\n', yn(R.no_leakage.kappa_h_frozen_before_fault_open));
    fprintf(fid, '| B2/G_nom altered | %s |\n\n', yn(R.no_leakage.B2_G_nom_altered));
    fprintf(fid, '%s\n\n', R.no_leakage.proof);

    fprintf(fid, '## Declared sensor corruption (VAL/TRAIN)\n\n');
    fprintf(fid, '%s\n\n', R.sensor.note);

    fprintf(fid, '## Unseen-nominal false alarms (VAL)\n\n');
    fprintf(fid, '| U | FA_latched%% | n_latched | n_post |\n|---:|---:|---:|---:|\n');
    for iu = 1:numel(FA.per_U)
        fprintf(fid, '| %.2f | %.4f | %d | %d |\n', ...
            FA.per_U(iu).u0, FA.per_U(iu).FA_latched_pct, ...
            FA.per_U(iu).n_latched, FA.per_U(iu).n_post);
    end
    fprintf(fid, '| **AGG** | **%.4f** | %d | %d |\n\n', ...
        FA.FA_agg_latched_pct, FA.n_latched_tot, FA.n_post_tot);
    fprintf(fid, 'Gate FA_agg ≤ 1%%: **%s**\n\n', yn(R.G.g_FA_agg_le_1pct));

    fprintf(fid, '## Per-cell CUSUM (VAL noisy replay)\n\n');
    fprintf(fid, '| U | η | loss%% | Pd | misses | med delay | p95 delay | preFA | cell |\n');
    fprintf(fid, '|---:|---:|---:|---:|---:|---:|---:|---:|:---:|\n');
    for iu = 1:numel(U)
        for ie = 1:numel(E)
            C = R.cells{iu, ie};
            fprintf(fid, '| %.2f | %.2f | %.0f | %.1f%% (%d/%d) | %d | %s | %s | %d | %s |\n', ...
                C.u0, C.eta_post, C.loss_pct, 100*C.Pd, C.n_detected, C.n_seeds, ...
                C.n_missed, num_or_nan(C.delay_median_s), num_or_nan(C.delay_p95_s), ...
                C.n_prefault, tern(C.cell_pass, 'PASS', 'FAIL'));
        end
    end
    fprintf(fid, '\n');

    fprintf(fid, '## B2 vs CUSUM (same VAL noise)\n\n');
    fprintf(fid, '| U | η | CUSUM Pd | CUSUM p95 | B2 Pd | B2 p95 | B2 clean delay |\n');
    fprintf(fid, '|---:|---:|---:|---:|---:|---:|---:|\n');
    for iu = 1:numel(U)
        for ie = 1:numel(E)
            C = R.cells{iu, ie};
            fprintf(fid, '| %.2f | %.2f | %.1f%% | %s | %.1f%% | %s | %s |\n', ...
                C.u0, C.eta_post, 100*C.Pd, num_or_nan(C.delay_p95_s), ...
                100*C.B2.Pd, num_or_nan(C.B2.delay_p95_s), num_or_nan(C.B2_clean_delay_s));
        end
    end
    fprintf(fid, '\n');

    fprintf(fid, '## Coverage gates\n\n');
    fprintf(fid, '| Gate | Result |\n|---|:---:|\n');
    fprintf(fid, '| Every cell Pd≥95%% and p95 delay≤3 s | %s |\n', yn(R.G.cells_all_pass));
    fprintf(fid, '| Agg unseen-nominal FA≤1%% | %s |\n', yn(R.G.g_FA_agg_le_1pct));
    fprintf(fid, '| **Coverage** | **%s** |\n\n', R.verdict);

    fprintf(fid, '## Next\n\n');
    fprintf(fid, '- **`%s`** — %s\n\n', R.G.next_priority, R.G.next_note);

    fprintf(fid, '## Files\n\n');
    fprintf(fid, '- `run_rudder_cusum_detector.m` (isolated runner + local stateful CUSUM)\n');
    fprintf(fid, '- `suite_results/RUDDER_CUSUM_DETECTOR.md`\n');
    fprintf(fid, '- `suite_results/RUDDER_CUSUM_DETECTOR.mat`\n');
    fprintf(fid, '- `suite_results/RUDDER_CUSUM_DETECTOR.png`\n');
    fprintf(fid, '- Production: controller_law / guidance / plant **unchanged**; CODEX_VERTICAL_PLAN untouched.\n');
    fclose(fid);
end

function append_log(out_dir, R)
    log_path = fullfile(out_dir, 'PITCH_CONTROL_RESEARCH_LOG.md');
    fid = fopen(log_path, 'a');
    assert(fid > 0);
    FA = R.FA_nominal_val;
    fprintf(fid, '\n\n## %s — %s\n\n', R.task_id, R.stamp);
    fprintf(fid, '- Coverage: **%s** — one-sided CUSUM on frozen B2 residual; production frozen; no NL rerun; B2/G_nom untouched.\n', ...
        R.verdict);
    fprintf(fid, '- Seeds TRAIN=%d:%d VAL=%d:%d (disjoint); κ=%.6f h=%.6f frozen before fault open.\n', ...
        R.seed_split.train(1), R.seed_split.train(end), ...
        R.seed_split.val(1), R.seed_split.val(end), R.cusum_cfg.kappa, R.cusum_cfg.h);
    fprintf(fid, '- Unseen-nominal FA_agg=%.4f%% (gate≤1%%=%s).\n', ...
        FA.FA_agg_latched_pct, yn(R.G.g_FA_agg_le_1pct));
    fprintf(fid, '- Cells all Pd≥95 & p95≤3s: %s.\n', yn(R.G.cells_all_pass));
    for iu = 1:numel(R.U_grid)
        for ie = 1:numel(R.eta_grid)
            C = R.cells{iu, ie};
            fprintf(fid, '- U=%.2f/η=%.2f: CUSUM Pd=%.1f%% med/p95=%s/%s miss=%d preFA=%d | B2 Pd=%.1f%% p95=%s.\n', ...
                C.u0, C.eta_post, 100*C.Pd, num_or_nan(C.delay_median_s), ...
                num_or_nan(C.delay_p95_s), C.n_missed, C.n_prefault, ...
                100*C.B2.Pd, num_or_nan(C.B2.delay_p95_s));
        end
    end
    fprintf(fid, '- Artifacts: suite_results/RUDDER_CUSUM_DETECTOR.{md,mat,png}; driver `run_rudder_cusum_detector.m`.\n');
    fprintf(fid, '- Next: **`%s`** — %s\n', R.G.next_priority, R.G.next_note);
    fprintf(fid, '- CODEX_VERTICAL_PLAN untouched.\n');
    fclose(fid);
end
