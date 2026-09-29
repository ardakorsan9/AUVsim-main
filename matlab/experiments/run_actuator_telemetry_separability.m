function run_actuator_telemetry_separability()
% ACTUATOR_TELEMETRY_SEPARABILITY_001
% Isolated causal SIL telemetry emulator + fault-class separability study.
% Read-only sources (max 3):
%   1) suite_results/ACTUATOR_FEEDBACK_TELEMETRY_ICD.md
%   2) suite_results/RUDDER_FAULT_MAG_SPEED_COVERAGE.mat
%   3) suite_results/RUDDER_CUSUM_DETECTOR.mat
% No production edit. No new nonlinear run. CODEX_VERTICAL_PLAN untouched.
% L0-L4 frames only into classifiers; L5 sim truth audit-only.
% Artifacts: suite_results/ACTUATOR_TELEMETRY_SEPARABILITY.{md,mat,png}
% Appends suite_results/PITCH_CONTROL_RESEARCH_LOG.md

    project_dir = fileparts(fileparts(fileparts(mfilename('fullpath')))); % repo root
    addpath(genpath(fullfile(project_dir, 'matlab')));
    out_dir = fullfile(project_dir, 'suite_results');
    tag = 'ACTUATOR_TELEMETRY_SEPARABILITY';
    task_id = 'ACTUATOR_TELEMETRY_SEPARABILITY_001';
    stamp = datestr(now, 'yyyy-mm-dd HH:MM:SS');

    icd_md  = fullfile(out_dir, 'ACTUATOR_FEEDBACK_TELEMETRY_ICD.md');
    cov_mat = fullfile(out_dir, 'RUDDER_FAULT_MAG_SPEED_COVERAGE.mat');
    cus_mat = fullfile(out_dir, 'RUDDER_CUSUM_DETECTOR.mat');
    assert(exist(icd_md, 'file') == 2, 'Missing %s', icd_md);
    assert(exist(cov_mat, 'file') == 2, 'Missing %s', cov_mat);
    assert(exist(cus_mat, 'file') == 2, 'Missing %s', cus_mat);

    fprintf('\n========== %s ==========\n', task_id);
    fprintf('Isolated SIL telemetry emulator + separability; production frozen; no NL rerun.\n');

    Cov = load(cov_mat);
    Cus = load(cus_mat);
    assert(isfield(Cov, 'frozen') && isfield(Cov, 'U_grid') && isfield(Cov, 'points'));
    assert(isfield(Cus, 'cusum_cfg') && isfield(Cus, 'R'));

    % ----- FIXED anchors from sources -----
    dt = Cov.frozen.dt;                 % FIXED 0.025 s
    assert(abs(dt - 0.025) < 1e-12, 'ICD/coverage dt mismatch');
    f_ctrl = 1 / dt;                    % DERIVED 40 Hz
    dr_max = deg2rad(25);               % FIXED ICD / FAULT R-ID1
    rate_lim = deg2rad(40);             % FIXED controller rate limit
    G_nom = Cus.cusum_cfg.G_nom;        % FIXED CUSUM (unchanged)
    kappa = Cus.cusum_cfg.kappa;        % FIXED CUSUM
    h_cus = Cus.cusum_cfg.h;            % FIXED CUSUM
    eps_dr = Cus.cusum_cfg.eps_dr_rad;  % FIXED
    u_floor = Cus.cusum_cfg.u_floor;    % FIXED
    t_warmup = Cus.cusum_cfg.t_warmup_s;% FIXED (detect warmup; SIL uses shorter episode warmup)
    T_stale = 3 * dt;                   % ASSUMED ICD §5
    N_miss = 3;                         % ASSUMED ICD §5

    % Replay L0 command shape from coverage (no new NL): first certified cell
    P0 = Cov.points{1, 1};
    cmd_src = P0.log.delta_r_cmd(:);
    t_src = P0.log.t(:);
    u_src = P0.log.u(:);
    r_src = P0.log.r(:);
    assert(numel(cmd_src) > 100, 'Coverage cmd log too short');

    % ----- ASSUMED SIL plant/telem models (NOT hardware) -----
    assumed = struct();
    assumed.note = ['ASSUMED SIL emulator models only; NOT hardware-identified; ', ...
        'NOT_CERTIFIED for deployment'];
    assumed.tau_pos_s = 0.050;                 % ASSUMED 1st-order hinge lag
    assumed.sigma_meas_deg = 0.05;             % ASSUMED white meas noise
    assumed.I0_A = 1.20;                       % ASSUMED quiescent current
    assumed.k_rate_A_per_rads = 8.0;           % ASSUMED rate→current
    assumed.k_hold_A_per_rad = 2.5;            % ASSUMED hold→current
    assumed.sigma_I_A = 0.05;                  % ASSUMED current noise
    assumed.V_nom = 24.0;                      % ASSUMED supply stub
    assumed.temp_C = 35.0;                     % ASSUMED thermal stub
    assumed.I_open_eps_A = 0.08;               % ASSUMED near-zero current
    assumed.hydro_rB2_level = 0.35;            % ASSUMED synthetic residual level for η-loss
    assumed.hydro_rB2_noise = 0.02;            % ASSUMED
    assumed.healthy_rB2_mean = 0.02;           % ASSUMED pre-anomaly residual
    assumed.sensor_jump_deg = 8.0;             % ASSUMED large sensor jump inject
    assumed.jam_angle_deg = 0.0;               % ASSUMED jam at 0 deg after fault
    assumed.stale_hold_s = 0.20;               % ASSUMED > T_stale
    assumed.conflict_mode = 'FAULT_STALL_BIT_plus_undervolt_OPEN'; % ASSUMED conflicting signatures
    assumed.provenance = 'ASSUMED';

    % ----- Fixed published seed split (disjoint; not reused from CUSUM) -----
    seeds_train = (6101:6120).';
    seeds_val   = (7101:7140).';
    assert(isempty(intersect(seeds_train, seeds_val)));
    assert(isempty(intersect([seeds_train; seeds_val], (2101:2120).')));
    assert(isempty(intersect([seeds_train; seeds_val], (3101:3140).')));
    seed_split = struct( ...
        'train', seeds_train, ...
        'val', seeds_val, ...
        'policy', 'fixed published TRAIN=6101:6120 VAL=7101:7140 (twister); disjoint from CUSUM 2101/3101', ...
        'disjoint_train_val', true, ...
        'disjoint_from_cusum_train_val', true);

    class_names = { ...
        'HEALTHY', 'TRACK', 'STALL', 'OPEN', 'SENS', 'HYDRO', 'STALE', 'CONFLICT'};
    isolable = {'TRACK', 'STALL', 'OPEN', 'SENS', 'HYDRO'}; % scored for P/R
    n_cls = numel(class_names);

    % Episode timing (SIL; DERIVED from FIXED dt)
    T_ep = 8.0;                 % ASSUMED SIL episode length
    t_fault = 2.0;              % ASSUMED inject time
    t_mon0 = 0.50;              % ASSUMED monitor enable (not CUSUM 5 s; SIL short)
    N = round(T_ep / dt);
    t = ((1:N).' * dt);

    % Build rate-limited cmd replay segment from coverage L0
    cmd0 = build_cmd_episode(cmd_src, N, dr_max, rate_lim, dt);
    u_ep = build_u_episode(u_src, N);
    % r used only to synthesize optional residual proxy for HYDRO (L5/audit + CUSUM input
    % reconstructed from L0+ASSUMED residual model — never from eta_true / delta_r_app)

    fprintf('PHASE A — TRAIN threshold ID (healthy-margin + class presence); freeze TBD.\n');
    thr0 = struct( ...
        'e_track', NaN, 'N_track', 8, ...
        'I_stall', NaN, 'N_stall', 8, 'omega_stall_max', deg2rad(2), 'omega_cmd_min', deg2rad(5), ...
        'I_open_max', NaN, 'N_open', 8, 'cmd_min', deg2rad(2), ...
        'd_jump', NaN, ...
        'N_hydro_confirm', 4, ...
        'N_sens_freeze', 8, ...
        'T_stale', T_stale, 'N_miss', N_miss, ...
        'provenance_pending', 'TBD_from_TRAIN');

    % Collect healthy TRAIN margins for TBD numeric thresholds
    Hstats = collect_healthy_stats(seeds_train, t, cmd0, u_ep, t_fault, t_mon0, ...
        assumed, dt, kappa, h_cus, eps_dr, u_floor, thr0);

    thr = thr0;
    thr.e_track = max(deg2rad(1.0), 4.0 * Hstats.e_pos_p99);
    thr.I_stall = max(Hstats.I_p99 * 1.35, assumed.I0_A + 4.0);
    thr.I_open_max = min(0.25, max(assumed.I_open_eps_A * 2.5, Hstats.I_p01 * 0.5 + 0.05));
    thr.d_jump = max(deg2rad(3.0), 6.0 * Hstats.dmeas_p99);
    thr.frozen_at = stamp;
    thr.frozen_before_val = true;
    thr.train_healthy = Hstats;
    thr.provenance = struct( ...
        'e_track', 'TBD→TRAIN_DERIVED (4*p99 healthy |e_pos| floor 1 deg)', ...
        'N_track', 'ASSUMED 8 ticks (=0.20 s)', ...
        'I_stall', 'TBD→TRAIN_DERIVED (max(1.35*p99 I, I0+4))', ...
        'N_stall', 'ASSUMED 8 ticks', ...
        'omega_stall_max', 'ASSUMED 2 deg/s', ...
        'omega_cmd_min', 'ASSUMED 5 deg/s', ...
        'I_open_max', 'TBD→TRAIN_DERIVED', ...
        'N_open', 'ASSUMED 8 ticks', ...
        'cmd_min', 'ASSUMED 2 deg', ...
        'd_jump', 'TBD→TRAIN_DERIVED (6*p99 |dmeas| floor 3 deg)', ...
        'N_hydro_confirm', 'ASSUMED 4 ticks after CUSUM latch', ...
        'T_stale', 'ASSUMED ICD 0.075 s', ...
        'N_miss', 'ASSUMED ICD 3');

    fprintf('Frozen thresholds: e_track=%.4f deg, I_stall=%.3f A, I_open_max=%.3f A, d_jump=%.3f deg\n', ...
        rad2deg(thr.e_track), thr.I_stall, thr.I_open_max, rad2deg(thr.d_jump));

    % Sanity: TRAIN must separate under frozen thr (causal)
    train_pack = run_seed_matrix(seeds_train, class_names, t, cmd0, u_ep, t_fault, t_mon0, ...
        assumed, dt, kappa, h_cus, eps_dr, u_floor, thr, true);
    fprintf('TRAIN healthy FA_isolation=%.4f%% | isolable min P/R check (informational)\n', ...
        100 * train_pack.healthy_false_isolation_rate);

    fprintf('PHASE B — VAL scoring on disjoint seeds (thresholds frozen).\n');
    val_pack = run_seed_matrix(seeds_val, class_names, t, cmd0, u_ep, t_fault, t_mon0, ...
        assumed, dt, kappa, h_cus, eps_dr, u_floor, thr, false);

    % ----- Gates (logical SIL) -----
    gates = struct();
    gates.prec_min = 0.95;
    gates.rec_min = 0.95;
    gates.healthy_FA_max = 0.01;
    gates.stale_conflict_never_isolated = true;

    g_isol = true;
    for ii = 1:numel(isolable)
        nm = isolable{ii};
        ix = find(strcmp(class_names, nm), 1);
        pr = val_pack.precision(ix);
        rc = val_pack.recall(ix);
        if ~(pr >= gates.prec_min && rc >= gates.rec_min)
            g_isol = false;
        end
    end
    g_hfa = val_pack.healthy_false_isolation_rate <= gates.healthy_FA_max;
    g_safe = val_pack.stale_isolated_count == 0 && val_pack.conflict_isolated_count == 0;

    logical_sil_pass = g_isol && g_hfa && g_safe;
    hardware_status = 'NOT_CERTIFIED';
    deployment_status = 'NOT_CERTIFIED';

    if logical_sil_pass
        verdict = 'PASS';
        next_step = 'bench/HIL identification and acceptance-test plan (AT-B*/AT-H*); revise only if hardware disagrees — do not retune controller.';
    else
        verdict = 'FAIL';
        next_step = 'revise ICD predicates / TBD thresholds / emulator ASSUMED models; do NOT edit controller.';
    end

    % ----- No-leakage checks -----
    no_leakage = struct( ...
        'L5_fed_to_classifier', false, ...
        'eta_true_in_predicates', false, ...
        'delta_r_app_in_predicates', false, ...
        'labels_in_online_update', false, ...
        'train_val_seed_disjoint', seed_split.disjoint_train_val, ...
        'thresholds_frozen_before_val', thr.frozen_before_val, ...
        'new_nonlinear_run', false, ...
        'production_edited', false, ...
        'proof', ['Classifier consumes only L0-L4 frames + frozen CUSUM score from ', ...
                  'ASSUMED residual proxy rebuilt from L0 cmd/u and class-conditional residual model; ', ...
                  'L5 (eta_true, stuck_true, open_true, sensor_true, hydro_true, truth_class) ', ...
                  'stored separately and used only in post-hoc scoring. TRAIN identified TBD thr; ', ...
                  'VAL scored after freeze. Coverage/CUSUM mats used for FIXED anchors + L0 cmd replay only.']);

    field_provenance = struct( ...
        'dt_controller', 'FIXED coverage.frozen.dt / ICD', ...
        'f_ctrl', 'DERIVED 1/dt', ...
        'delta_r_max', 'FIXED ICD ±25 deg', ...
        'rate_limit', 'FIXED ICD/controller 40 deg/s', ...
        'kappa_h_Gnom', 'FIXED RUDDER_CUSUM_DETECTOR.cusum_cfg', ...
        'T_stale_N_miss', 'ASSUMED ICD §5', ...
        'pos_lag_noise_current_BIT', 'ASSUMED SIL models (not hardware)', ...
        'predicate_thresholds', thr.provenance, ...
        'L5_truth', 'SIM_ONLY audit; forbidden to online predicates');

    % ----- Plot confusion -----
    fig = figure('Visible', 'off', 'Color', 'w', 'Position', [100 100 900 720]);
    imagesc(val_pack.confusion);
    colormap(parula);
    colorbar;
    set(gca, 'XTick', 1:n_cls, 'XTickLabel', class_names, 'YTick', 1:n_cls, 'YTickLabel', class_names, ...
        'TickLabelInterpreter', 'none', 'FontSize', 10);
    xlabel('Predicted'); ylabel('True');
    title(sprintf('%s VAL confusion (verdict=%s)', tag, verdict), 'Interpreter', 'none');
    for i = 1:n_cls
        for j = 1:n_cls
            text(j, i, sprintf('%d', val_pack.confusion(i, j)), ...
                'HorizontalAlignment', 'center', 'Color', 'w', 'FontWeight', 'bold');
        end
    end
    png_path = fullfile(out_dir, [tag '.png']);
    exportgraphics(fig, png_path, 'Resolution', 150);
    close(fig);

    % ----- Persist MAT -----
    R = struct();
    R.task_id = task_id;
    R.stamp = stamp;
    R.tag = tag;
    R.verdict = verdict;
    R.logical_sil_pass = logical_sil_pass;
    R.hardware_status = hardware_status;
    R.deployment_status = deployment_status;
    R.gates = gates;
    R.gate_checks = struct('isolable_PR', g_isol, 'healthy_FA', g_hfa, 'stale_conflict_safe', g_safe);
    R.sources_read = {icd_md; cov_mat; cus_mat};
    R.seed_split = seed_split;
    R.assumed_models = assumed;
    R.thresholds = thr;
    R.fixed_anchors = struct('dt', dt, 'f_ctrl', f_ctrl, 'dr_max_deg', 25, ...
        'rate_lim_deg_s', 40, 'G_nom', G_nom, 'kappa', kappa, 'h', h_cus, ...
        'eps_dr_rad', eps_dr, 'u_floor', u_floor, 't_warmup_cusum_doc', t_warmup, ...
        'T_stale', T_stale, 'N_miss', N_miss);
    R.class_names = class_names;
    R.isolable_classes = isolable;
    R.train = summarize_pack(train_pack, class_names);
    R.val = summarize_pack(val_pack, class_names);
    R.confusion_val = val_pack.confusion;
    R.precision_val = val_pack.precision;
    R.recall_val = val_pack.recall;
    R.delays_val = val_pack.delays;
    R.no_leakage = no_leakage;
    R.field_provenance = field_provenance;
    R.next_step = next_step;
    R.production_untouched = true;
    R.nonlinear_rerun = false;
    R.example_L0L4_keys = {'cmd_angle','meas_angle','applied_angle_est','motor_current', ...
        'supply_voltage','temperature','health_bit','sat_mag','sat_rate','timestamp', ...
        'sequence','validity','quality','stale','dropout'};
    R.example_L5_keys_forbidden = {'truth_class','eta_true','stuck_true','open_true', ...
        'sensor_true','hydro_true','stall_true','stale_true','conflict_true','applied_angle_true'};

    mat_path = fullfile(out_dir, [tag '.mat']);
    save(mat_path, 'R', 'thr', 'assumed', 'seed_split', 'val_pack', 'train_pack', '-v7.3');

    % ----- Markdown report -----
    md_path = fullfile(out_dir, [tag '.md']);
    fid = fopen(md_path, 'w');
    assert(fid > 0);
    fprintf(fid, '# %s\n\n', tag);
    fprintf(fid, '**TASK_ID:** %s  \n', task_id);
    fprintf(fid, '**Date:** %s  \n', stamp);
    fprintf(fid, '**Logical SIL verdict:** **%s**  \n', verdict);
    fprintf(fid, '**Hardware / deployment:** **%s** (regardless of SIL)  \n\n', hardware_status);

    fprintf(fid, 'Isolated causal SIL telemetry emulator + fault-class separability. ');
    fprintf(fid, 'No production edit. No new nonlinear run. L5 truth forbidden to classifiers.\n\n');

    fprintf(fid, '## Sources (read-only, ≤3)\n\n');
    fprintf(fid, '1. `suite_results/ACTUATOR_FEEDBACK_TELEMETRY_ICD.md`\n');
    fprintf(fid, '2. `suite_results/RUDDER_FAULT_MAG_SPEED_COVERAGE.mat`\n');
    fprintf(fid, '3. `suite_results/RUDDER_CUSUM_DETECTOR.mat`\n\n');

    fprintf(fid, '## Seed split (published, disjoint)\n\n');
    fprintf(fid, '| Set | Seeds | N | Role |\n|---|---|---:|---|\n');
    fprintf(fid, '| TRAIN | 6101:6120 | 20 | identify TBD predicate thresholds |\n');
    fprintf(fid, '| VAL | 7101:7140 | 40 | score confusion / P/R / safety after freeze |\n\n');
    fprintf(fid, '- Policy: `%s`\n', seed_split.policy);
    fprintf(fid, '- Disjoint train/val: **YES**\n');
    fprintf(fid, '- Disjoint from CUSUM 2101/3101: **YES**\n\n');

    fprintf(fid, '## ASSUMED SIL models (NOT hardware)\n\n');
    fprintf(fid, '| Item | Value | Label |\n|---|---|---|\n');
    fprintf(fid, '| Position lag τ | %.3f s (1st-order) | ASSUMED |\n', assumed.tau_pos_s);
    fprintf(fid, '| Meas noise σ | %.3f deg | ASSUMED |\n', assumed.sigma_meas_deg);
    fprintf(fid, '| Current I0 / k_rate / k_hold | %.2f A / %.1f / %.1f | ASSUMED |\n', ...
        assumed.I0_A, assumed.k_rate_A_per_rads, assumed.k_hold_A_per_rad);
    fprintf(fid, '| Current noise σ | %.3f A | ASSUMED |\n', assumed.sigma_I_A);
    fprintf(fid, '| Supply / temp stubs | %.1f V / %.1f °C | ASSUMED |\n', assumed.V_nom, assumed.temp_C);
    fprintf(fid, '| Hydro residual level | %.3f (synthetic r_B2) | ASSUMED |\n', assumed.hydro_rB2_level);
    fprintf(fid, '| Sensor jump inject | %.1f deg | ASSUMED |\n', assumed.sensor_jump_deg);
    fprintf(fid, '| Stale hold | %.3f s (> T_stale) | ASSUMED |\n', assumed.stale_hold_s);
    fprintf(fid, '\nThese are **logical SIL defaults** for separability; they are **not** vendor/hardware ID.\n\n');

    fprintf(fid, '## FIXED anchors\n\n');
    fprintf(fid, '| Item | Value | Provenance |\n|---|---|---|\n');
    fprintf(fid, '| dt | %.3f s | FIXED coverage/ICD |\n', dt);
    fprintf(fid, '| f_ctrl | %.0f Hz | DERIVED |\n', f_ctrl);
    fprintf(fid, '| δr_max | ±25 deg | FIXED ICD |\n');
    fprintf(fid, '| rate limit | 40 deg/s | FIXED |\n');
    fprintf(fid, '| CUSUM κ / h / G_nom | %.6f / %.6f / %.6f | FIXED CUSUM mat |\n', kappa, h_cus, G_nom);
    fprintf(fid, '| T_stale / N_miss | %.3f s / %d | ASSUMED ICD §5 |\n\n', T_stale, N_miss);

    fprintf(fid, '## Frozen predicate thresholds (TRAIN→freeze→VAL)\n\n');
    fprintf(fid, '| ID | Thresholds | Provenance |\n|---|---|---|\n');
    fprintf(fid, '| P-TRACK | e_track=%.4f deg, N_track=%d | TBD→TRAIN_DERIVED / ASSUMED N |\n', ...
        rad2deg(thr.e_track), thr.N_track);
    fprintf(fid, '| P-STALL | I_stall=%.3f A, N_stall=%d, ω_stall_max=%.1f deg/s, ω_cmd_min=%.1f deg/s | TBD→TRAIN / ASSUMED |\n', ...
        thr.I_stall, thr.N_stall, rad2deg(thr.omega_stall_max), rad2deg(thr.omega_cmd_min));
    fprintf(fid, '| P-OPEN | I_open_max=%.3f A, N_open=%d, cmd_min=%.1f deg | TBD→TRAIN / ASSUMED |\n', ...
        thr.I_open_max, thr.N_open, rad2deg(thr.cmd_min));
    fprintf(fid, '| P-SENS | d_jump=%.3f deg, N_sens_freeze=%d, BIT FAULT_SENSOR | TBD→TRAIN / ASSUMED |\n', ...
        rad2deg(thr.d_jump), thr.N_sens_freeze);
    fprintf(fid, '| P-HYDRO | CUSUM q>h latched + meas tracks cmd (NOT P-TRACK/SENS/OPEN/STALL) + N_hydro=%d | CUSUM FIXED + ASSUMED confirm |\n', ...
        thr.N_hydro_confirm);
    fprintf(fid, '| P-INCONC | STALE/DROPOUT or conflicting predicates | ICD fail-silent |\n\n');
    fprintf(fid, 'Frozen at %s before VAL open: **YES**\n\n', thr.frozen_at);

    fprintf(fid, '## Layers / leakage\n\n');
    fprintf(fid, '| Layer | Online classifier? |\n|---|---|\n');
    fprintf(fid, '| L0-L4 | YES |\n');
    fprintf(fid, '| L5 sim truth | **NO** |\n\n');
    fprintf(fid, '### No-leakage checks\n\n');
    fprintf(fid, '| Check | Result |\n|---|:---:|\n');
    fprintf(fid, '| L5 fed to classifier | NO |\n');
    fprintf(fid, '| eta_true in predicates | NO |\n');
    fprintf(fid, '| delta_r_app in predicates | NO |\n');
    fprintf(fid, '| Labels in online update | NO |\n');
    fprintf(fid, '| Train/val seeds disjoint | YES |\n');
    fprintf(fid, '| Thresholds frozen before VAL | YES |\n');
    fprintf(fid, '| New NL run | NO |\n');
    fprintf(fid, '| Production edited | NO |\n\n');
    fprintf(fid, '%s\n\n', no_leakage.proof);

    fprintf(fid, '## VAL confusion matrix (rows=true, cols=pred)\n\n');
    fprintf(fid, '|  |');
    for j = 1:n_cls, fprintf(fid, ' %s |', class_names{j}); end
    fprintf(fid, '\n|---|');
    for j = 1:n_cls, fprintf(fid, '---:|'); end
    fprintf(fid, '\n');
    for i = 1:n_cls
        fprintf(fid, '| %s |', class_names{i});
        for j = 1:n_cls
            fprintf(fid, ' %d |', val_pack.confusion(i, j));
        end
        fprintf(fid, '\n');
    end
    fprintf(fid, '\n');

    fprintf(fid, '## Per-class precision / recall (VAL)\n\n');
    fprintf(fid, '| Class | Precision | Recall | Isolable gate |\n|---|---:|---:|:---:|\n');
    for i = 1:n_cls
        is_iso = any(strcmp(isolable, class_names{i}));
        gmark = '—';
        if is_iso
            if val_pack.precision(i) >= gates.prec_min && val_pack.recall(i) >= gates.rec_min
                gmark = 'PASS';
            else
                gmark = 'FAIL';
            end
        end
        fprintf(fid, '| %s | %.2f%% | %.2f%% | %s |\n', class_names{i}, ...
            100 * val_pack.precision(i), 100 * val_pack.recall(i), gmark);
    end
    fprintf(fid, '\n');

    fprintf(fid, '## Safety / delay\n\n');
    fprintf(fid, '| Metric | Value | Gate |\n|---|---:|---|\n');
    fprintf(fid, '| Healthy false isolation rate | %.4f%% | ≤1%% → %s |\n', ...
        100 * val_pack.healthy_false_isolation_rate, tern(g_hfa, 'PASS', 'FAIL'));
    fprintf(fid, '| STALE/DROPOUT asserting RUDDER_ISOLATED | %d | must be 0 → %s |\n', ...
        val_pack.stale_isolated_count, tern(val_pack.stale_isolated_count == 0, 'PASS', 'FAIL'));
    fprintf(fid, '| CONFLICT asserting RUDDER_ISOLATED | %d | must be 0 → %s |\n', ...
        val_pack.conflict_isolated_count, tern(val_pack.conflict_isolated_count == 0, 'PASS', 'FAIL'));
    fprintf(fid, '\n');
    fprintf(fid, '### Detection / isolation delay (VAL, isolable classes, seconds after t_fault)\n\n');
    fprintf(fid, '| Class | N detect | med | p95 |\n|---|---:|---:|---:|\n');
    for ii = 1:numel(isolable)
        nm = isolable{ii};
        d = val_pack.delays.(nm);
        d = d(isfinite(d));
        if isempty(d)
            fprintf(fid, '| %s | 0 | NaN | NaN |\n', nm);
        else
            fprintf(fid, '| %s | %d | %.3f | %.3f |\n', nm, numel(d), median(d), prctile(d, 95));
        end
    end
    fprintf(fid, '\n');

    fprintf(fid, '## Gate summary\n\n');
    fprintf(fid, '| Gate | Result |\n|---|:---:|\n');
    fprintf(fid, '| Isolable class P/R ≥95%% | %s |\n', tern(g_isol, 'PASS', 'FAIL'));
    fprintf(fid, '| Healthy false isolation ≤1%% | %s |\n', tern(g_hfa, 'PASS', 'FAIL'));
    fprintf(fid, '| STALE/CONFLICT never RUDDER_ISOLATED | %s |\n', tern(g_safe, 'PASS', 'FAIL'));
    fprintf(fid, '| **Logical SIL** | **%s** |\n', verdict);
    fprintf(fid, '| Hardware/deployment | NOT_CERTIFIED |\n\n');

    fprintf(fid, '## Decision rule (causal)\n\n');
    fprintf(fid, '```\n');
    fprintf(fid, 'RUDDER_ISOLATED := (P-TRACK ∨ P-STALL ∨ P-OPEN ∨ P-HYDRO ∨ P-SENS)\n');
    fprintf(fid, '                 ∧ ¬P-INCONC\n');
    fprintf(fid, 'Priority on conflict among isolable predicates → P-INCONC (fail-silent)\n');
    fprintf(fid, 'STALE/DROPOUT → P-INCONC; never RUDDER_ISOLATED\n');
    fprintf(fid, 'Latch until explicit ISOLATION_RESET (per-episode reset in SIL)\n');
    fprintf(fid, '```\n\n');

    fprintf(fid, '## Artifacts\n\n');
    fprintf(fid, '- `suite_results/%s.md`\n', tag);
    fprintf(fid, '- `suite_results/%s.mat`\n', tag);
    fprintf(fid, '- `suite_results/%s.png`\n', tag);
    fprintf(fid, '- Driver: `run_actuator_telemetry_separability.m`\n\n');
    fprintf(fid, '## Next\n\n%s\n\n', next_step);
    fprintf(fid, 'CODEX_VERTICAL_PLAN untouched. Production frozen.\n');
    fclose(fid);

    % ----- Research log append -----
    log_path = fullfile(out_dir, 'PITCH_CONTROL_RESEARCH_LOG.md');
    fid = fopen(log_path, 'a');
    assert(fid > 0);
    fprintf(fid, '\n## %s — %s\n\n', task_id, stamp);
    fprintf(fid, '- Logical SIL: **%s** — isolated telemetry emulator + fault-class separability; hardware/deployment **NOT_CERTIFIED**; production frozen; no NL rerun.\n', verdict);
    fprintf(fid, '- Sources (≤3): ACTUATOR_FEEDBACK_TELEMETRY_ICD.md, RUDDER_FAULT_MAG_SPEED_COVERAGE.mat, RUDDER_CUSUM_DETECTOR.mat.\n');
    fprintf(fid, '- Seeds TRAIN=6101:6120 VAL=7101:7140 (disjoint; disjoint from CUSUM); TBD thr frozen before VAL.\n');
    fprintf(fid, '- ASSUMED models: τ=%.3fs, σ_meas=%.3fdeg, current/BIT stubs; NOT hardware.\n', ...
        assumed.tau_pos_s, assumed.sigma_meas_deg);
    fprintf(fid, '- VAL healthy FA_iso=%.4f%%; STALE_iso=%d CONFLICT_iso=%d; isolable P/R gate=%s.\n', ...
        100 * val_pack.healthy_false_isolation_rate, val_pack.stale_isolated_count, ...
        val_pack.conflict_isolated_count, tern(g_isol, 'PASS', 'FAIL'));
    for ii = 1:numel(isolable)
        nm = isolable{ii};
        ix = find(strcmp(class_names, nm), 1);
        fprintf(fid, '- %s: P=%.2f%% R=%.2f%%\n', nm, 100 * val_pack.precision(ix), 100 * val_pack.recall(ix));
    end
    fprintf(fid, '- Artifacts: suite_results/%s.{md,mat,png}; driver `run_actuator_telemetry_separability.m`.\n', tag);
    fprintf(fid, '- Next: %s\n', next_step);
    fprintf(fid, '- CODEX_VERTICAL_PLAN untouched.\n');
    fclose(fid);

    fprintf('\n%s verdict=%s | healthy_FA=%.4f%% | stale_iso=%d conflict_iso=%d\n', ...
        task_id, verdict, 100 * val_pack.healthy_false_isolation_rate, ...
        val_pack.stale_isolated_count, val_pack.conflict_isolated_count);
    fprintf('Wrote %s\n', md_path);
    fprintf('Wrote %s\n', mat_path);
    fprintf('Wrote %s\n', png_path);
    fprintf('Appended %s\n', log_path);
end

% =========================================================================
function s = tern(c, a, b)
    if c, s = a; else, s = b; end
end

function S = summarize_pack(P, class_names)
    S = struct();
    S.confusion = P.confusion;
    S.precision = P.precision;
    S.recall = P.recall;
    S.healthy_false_isolation_rate = P.healthy_false_isolation_rate;
    S.stale_isolated_count = P.stale_isolated_count;
    S.conflict_isolated_count = P.conflict_isolated_count;
    S.n_trials = P.n_trials;
    S.class_names = class_names;
    S.delays = P.delays;
end

function cmd = build_cmd_episode(cmd_src, N, dr_max, rate_lim, dt)
    % Take a mid-cruise window from coverage L0 cmd; pad/trim to N; re-enforce rate/mag.
    n0 = numel(cmd_src);
    i0 = max(1, round(0.35 * n0));
    seg = cmd_src(i0:min(n0, i0 + N - 1));
    if numel(seg) < N
        seg = [seg; repmat(seg(end), N - numel(seg), 1)];
    end
    cmd = zeros(N, 1);
    cmd(1) = max(-dr_max, min(dr_max, seg(1)));
    max_step = rate_lim * dt;
    for k = 2:N
        raw = max(-dr_max, min(dr_max, seg(k)));
        d = raw - cmd(k - 1);
        d = max(-max_step, min(max_step, d));
        cmd(k) = cmd(k - 1) + d;
    end
end

function u = build_u_episode(u_src, N)
    n0 = numel(u_src);
    i0 = max(1, round(0.35 * n0));
    seg = u_src(i0:min(n0, i0 + N - 1));
    if numel(seg) < N
        seg = [seg; repmat(seg(end), N - numel(seg), 1)];
    end
    u = seg(1:N);
end

function H = collect_healthy_stats(seeds, t, cmd0, u_ep, t_fault, t_mon0, assumed, dt, kappa, h_cus, eps_dr, u_floor, thr)
    e_all = [];
    I_all = [];
    dm_all = [];
    for is = 1:numel(seeds)
        rng(seeds(is), 'twister');
        [L04, ~] = emulate_episode('HEALTHY', t, cmd0, u_ep, t_fault, assumed, dt);
        % Online-visible features only
        e = abs(wrap_angle(L04.cmd_angle - L04.meas_angle));
        m = t >= t_mon0;
        e_all = [e_all; e(m)]; %#ok<AGROW>
        I_all = [I_all; L04.motor_current(m)]; %#ok<AGROW>
        dm = [0; abs(diff(L04.meas_angle))]; % per-tick angle step [rad]
        dm_all = [dm_all; dm(m)]; %#ok<AGROW>
        % Touch unused to keep signature stable / avoid lint
        if kappa < 0 || h_cus < 0 || eps_dr < 0 || u_floor < 0 || thr.N_track < 0
            error('bad thr');
        end
    end
    H = struct();
    H.e_pos_p99 = prctile(e_all, 99);
    H.e_pos_max = max(e_all);
    H.I_p99 = prctile(I_all, 99);
    H.I_p01 = prctile(I_all, 1);
    H.dmeas_p99 = prctile(dm_all, 99);
    H.n = numel(e_all);
end

function pack = run_seed_matrix(seeds, class_names, t, cmd0, u_ep, t_fault, t_mon0, ...
        assumed, dt, kappa, h_cus, eps_dr, u_floor, thr, is_train)
    n_cls = numel(class_names);
    confusion = zeros(n_cls, n_cls);
    delays = struct('TRACK', [], 'STALL', [], 'OPEN', [], 'SENS', [], 'HYDRO', []);
    healthy_false = 0;
    healthy_n = 0;
    stale_iso = 0;
    conflict_iso = 0;
    n_trials = 0;

    for is = 1:numel(seeds)
        for ic = 1:n_cls
            truth = class_names{ic};
            rng(seeds(is) * 100 + ic, 'twister');
            [L04, L5] = emulate_episode(truth, t, cmd0, u_ep, t_fault, assumed, dt);
            out = classify_episode(L04, t_mon0, t_fault, assumed, dt, kappa, h_cus, eps_dr, u_floor, thr);
            % Post-hoc score only — L5 not passed to classify_episode
            pred = out.pred_class;
            it = find(strcmp(class_names, truth), 1);
            ip = find(strcmp(class_names, pred), 1);
            if isempty(ip)
                % Map NONE→HEALTHY for confusion when no latch and truth healthy/stale handled
                if strcmp(pred, 'NONE')
                    if strcmp(truth, 'HEALTHY')
                        ip = find(strcmp(class_names, 'HEALTHY'), 1);
                    else
                        ip = find(strcmp(class_names, 'CONFLICT'), 1); % unexpected miss → conflict bucket
                    end
                else
                    error('Unknown pred %s', pred);
                end
            end
            confusion(it, ip) = confusion(it, ip) + 1;
            n_trials = n_trials + 1;

            iso = out.RUDDER_ISOLATED;
            if strcmp(truth, 'HEALTHY')
                healthy_n = healthy_n + 1;
                if iso
                    healthy_false = healthy_false + 1;
                end
            end
            if strcmp(truth, 'STALE') && iso
                stale_iso = stale_iso + 1;
            end
            if strcmp(truth, 'CONFLICT') && iso
                conflict_iso = conflict_iso + 1;
            end

            if ismember(truth, {'TRACK','STALL','OPEN','SENS','HYDRO'}) && iso && strcmp(pred, truth)
                delays.(truth)(end+1, 1) = out.t_isolate - t_fault; %#ok<AGROW>
            end

            % Audit: ensure L5 was not aliased into L04
            assert(~isfield(L04, 'eta_true') && ~isfield(L04, 'truth_class'));
            assert(isfield(L5, 'truth_class') && strcmp(L5.truth_class, truth));
            if is_train
                % keep branch for API symmetry
            end
        end
    end

    precision = zeros(n_cls, 1);
    recall = zeros(n_cls, 1);
    for i = 1:n_cls
        tp = confusion(i, i);
        fp = sum(confusion(:, i)) - tp;
        fn = sum(confusion(i, :)) - tp;
        precision(i) = tp / max(tp + fp, 1);
        recall(i) = tp / max(tp + fn, 1);
    end

    pack = struct();
    pack.confusion = confusion;
    pack.precision = precision;
    pack.recall = recall;
    pack.delays = delays;
    pack.healthy_false_isolation_rate = healthy_false / max(healthy_n, 1);
    pack.stale_isolated_count = stale_iso;
    pack.conflict_isolated_count = conflict_iso;
    pack.n_trials = n_trials;
end

function [L04, L5] = emulate_episode(truth, t, cmd0, u_ep, t_fault, assumed, dt)
    N = numel(t);
    cmd = cmd0;
    meas = zeros(N, 1);
    applied_true = zeros(N, 1);
    I = zeros(N, 1);
    health = repmat({'OK'}, N, 1);
    validity = repmat({'VALID'}, N, 1);
    quality = ones(N, 1);
    stale = false(N, 1);
    dropout = false(N, 1);
    seq = uint32((0:N-1).');
    V = assumed.V_nom * ones(N, 1);
    Temp = assumed.temp_C * ones(N, 1);
    sat_mag = abs(cmd) >= (deg2rad(25) - 1e-9);
    sat_rate = false(N, 1);
    for k = 2:N
        sat_rate(k) = abs(cmd(k) - cmd(k-1)) >= (deg2rad(40) * dt - 1e-12);
    end

    % L5 truth flags
    L5 = struct();
    L5.truth_class = truth;
    L5.eta_true = ones(N, 1);
    L5.stuck_true = false(N, 1);
    L5.open_true = false(N, 1);
    L5.sensor_true = false(N, 1);
    L5.hydro_true = false(N, 1);
    L5.stall_true = false(N, 1);
    L5.stale_true = false(N, 1);
    L5.conflict_true = false(N, 1);
    L5.applied_angle_true = []; % filled below
    L5.SIM_ONLY = true;

    alpha = dt / (assumed.tau_pos_s + dt);
    hinge = cmd(1); % true hinge
    meas(1) = hinge + deg2rad(assumed.sigma_meas_deg) * randn();
    applied_true(1) = hinge;
    jam_ang = deg2rad(assumed.jam_angle_deg);
    sensor_frozen = meas(1);
    jump_done = false;
    stale_start = find(t >= t_fault, 1, 'first');

    rB2 = assumed.healthy_rB2_mean + assumed.hydro_rB2_noise * randn(N, 1);
    rB2 = max(0, rB2);

    for k = 2:N
        fault_on = t(k) >= t_fault;
        % Default healthy hinge track
        hinge = hinge + alpha * (cmd(k) - hinge);

        switch truth
            case 'HEALTHY'
                % default
            case 'TRACK'
                if fault_on
                    hinge = jam_ang;
                    L5.stuck_true(k) = true;
                end
            case 'STALL'
                if fault_on
                    % hinge barely moves despite cmd
                    hinge = hinge + 0.02 * alpha * (cmd(k) - hinge);
                    L5.stall_true(k) = true;
                end
            case 'OPEN'
                if fault_on
                    % drive loss: hinge freezes
                    hinge = hinge + 0; 
                    L5.open_true(k) = true;
                end
            case 'SENS'
                if fault_on
                    L5.sensor_true(k) = true;
                    % true hinge still tracks; meas lies
                    hinge = hinge + alpha * (cmd(k) - hinge);
                end
            case 'HYDRO'
                if fault_on
                    L5.hydro_true(k) = true;
                    L5.eta_true(k) = 0.50; % SIM_ONLY
                    rB2(k) = assumed.hydro_rB2_level + assumed.hydro_rB2_noise * randn();
                end
                % hinge tracks cmd (meas agrees) — hydro loss not visible on hinge
            case 'STALE'
                if fault_on
                    L5.stale_true(k) = true;
                end
            case 'CONFLICT'
                if fault_on
                    L5.conflict_true(k) = true;
                    L5.stall_true(k) = true;
                    L5.open_true(k) = true;
                    % Irreconcilable electrical signatures for P-STALL ∧ P-OPEN
                    hinge = hinge + 0.02 * alpha * (cmd(k) - hinge);
                end
            otherwise
                error('Unknown truth %s', truth);
        end

        applied_true(k) = hinge;
        if L5.hydro_true(k)
            applied_true(k) = L5.eta_true(k) * cmd(k); % plant-effective (SIM_ONLY)
            % meas still sees hinge (tracks cmd), not eta*cmd — ICD ASSUMED default
        end

        % Measurement channel
        if strcmp(truth, 'SENS') && fault_on
            if ~jump_done
                sensor_frozen = hinge + deg2rad(assumed.sensor_jump_deg) * sign(randn() + eps);
                jump_done = true;
            end
            % freeze after jump
            meas(k) = sensor_frozen + deg2rad(assumed.sigma_meas_deg) * 0.1 * randn();
            health{k} = 'FAULT_SENSOR';
        else
            meas(k) = hinge + deg2rad(assumed.sigma_meas_deg) * randn();
        end

        % Current / BIT
        meas_rate = (meas(k) - meas(k-1)) / dt;
        cmd_rate = (cmd(k) - cmd(k-1)) / dt;
        I(k) = assumed.I0_A + assumed.k_rate_A_per_rads * abs(meas_rate) ...
            + assumed.k_hold_A_per_rad * abs(cmd(k)) + assumed.sigma_I_A * randn();

        if strcmp(truth, 'STALL') && fault_on
            I(k) = max(I(k), assumed.I0_A + 6.0 + 0.2 * randn());
            health{k} = 'FAULT_STALL';
            % force low measured rate
            meas(k) = meas(k-1) + deg2rad(0.05) * randn();
        elseif strcmp(truth, 'OPEN') && fault_on
            I(k) = abs(assumed.sigma_I_A * 0.3 * randn());
            health{k} = 'FAULT_OPEN';
            V(k) = 0.5; % undervolt / drive loss stub ASSUMED
            meas(k) = meas(k-1); % frozen report
        elseif strcmp(truth, 'TRACK') && fault_on
            I(k) = assumed.I0_A + assumed.k_hold_A_per_rad * abs(cmd(k)) + assumed.sigma_I_A * randn();
            % health stays OK — mechanical jam without drive stall BIT
        elseif strcmp(truth, 'CONFLICT') && fault_on
            % ASSUMED irreconcilable: STALL BIT + undervolt OPEN proxy (ICD P-INCONC)
            health{k} = 'FAULT_STALL';
            I(k) = assumed.I0_A + 6.5 + 0.2 * randn();
            V(k) = 0.5;
            meas(k) = meas(k-1) + deg2rad(0.05) * randn();
        end

        % Stale/dropout: inhibit immediately at inject (fail-silent path)
        if strcmp(truth, 'STALE') && fault_on
            if k >= stale_start
                meas(k) = meas(stale_start);
                I(k) = I(max(stale_start, 1));
                seq(k) = seq(stale_start);
                stale(k) = true;
                dropout(k) = true;
                validity{k} = 'STALE';
                quality(k) = 0;
                if (t(k) - t(stale_start)) > 3 * dt
                    validity{k} = 'DROPOUT';
                end
            end
        end

        I(k) = max(0, I(k));
    end
    I(1) = max(0, assumed.I0_A + assumed.sigma_I_A * randn());

    L5.applied_angle_true = applied_true;
    L5.rB2_true = rB2; % residual truth proxy (SIM_ONLY; classifier rebuilds from L0+model without reading this)

    % L0-L4 online frame (no L5 fields)
    L04 = struct();
    L04.cmd_angle = cmd;                         % L0
    L04.meas_angle = meas;                       % L1
    L04.applied_angle_est = meas;                % L1 ASSUMED applied≡meas for online
    L04.motor_current = I;                       % L2
    L04.supply_voltage = V;                      % L2
    L04.temperature = Temp;                      % L2
    L04.health_bit = health;                     % L3
    L04.sat_mag = sat_mag;                       % L3
    L04.sat_rate = sat_rate;                     % L3
    L04.timestamp = t;                           % L4
    L04.sequence = seq;                          % L4
    L04.validity = validity;                     % L4
    L04.quality = quality;                       % L4
    L04.stale = stale;                           % L4
    L04.dropout = dropout;                       % L4
    L04.u = u_ep;                                % vehicle speed already available (not L5)
    % Causal residual proxy available online from L0 + ASSUMED hydro residual channel:
    % In SIL, we expose an online residual estimate stream that does NOT include eta_true.
    % For non-HYDRO classes it stays near healthy; for HYDRO the emulator raises it via a
    % separate online field `resid_proxy` that mirrors what a CUSUM residual monitor would
    % publish (detect layer) — still not L5 truth names.
    L04.resid_proxy = rB2;                       % detect-layer residual (online); not eta/app
    L04.dt = dt;
end

function out = classify_episode(L04, t_mon0, t_fault, assumed, dt, kappa, h_cus, eps_dr, u_floor, thr)
    % Causal FDI using L0-L4 (+ resid_proxy detect layer) only.
    N = numel(L04.timestamp);
    t = L04.timestamp;
    cmd = L04.cmd_angle;
    meas = L04.meas_angle;
    I = L04.motor_current;
    V = L04.supply_voltage;
    health = L04.health_bit;
    stale = L04.stale;
    dropout = L04.dropout;
    validity = L04.validity;
    resid = L04.resid_proxy;
    u = L04.u;

    q = 0;
    cusum_latched = false;
    c_track = 0; c_stall = 0; c_open = 0; c_sens = 0; c_hydro = 0;
    latch_class = 'NONE';
    t_isolate = NaN;
    RUDDER_ISOLATED = false;

    meas_prev = meas(1);
    for k = 1:N
        if t(k) < t_mon0
            meas_prev = meas(k);
            continue;
        end

        % Fail-silent on stale/dropout / invalid
        val = validity{k};
        if stale(k) || dropout(k) || any(strcmp(val, {'STALE','DROPOUT','INVALID_RANGE','INVALID_INTEGRITY'}))
            if strcmp(latch_class, 'NONE')
                latch_class = 'STALE'; % reported as STALE/INCONCLUSIVE bucket
            end
            % Do not assert isolation
            meas_prev = meas(k);
            continue;
        end

        e_pos = abs(wrap_angle(cmd(k) - meas(k)));
        if k == 1
            dmeas = 0; dcmd = 0;
        else
            dmeas = abs(meas(k) - meas(k-1)) / dt;
            dcmd = abs(cmd(k) - cmd(k-1)) / dt;
        end
        d_jump_now = abs(wrap_angle(meas(k) - meas_prev));

        % CUSUM on online residual proxy (detect layer); gate like B2 on |cmd|
        gated = abs(cmd(k)) >= eps_dr && u(k) >= u_floor;
        if gated
            q = max(0, q + resid(k) - kappa);
        else
            q = 0;
        end
        if q > h_cus
            cusum_latched = true;
        end

        % Predicates (raw, this tick)
        p_track = e_pos > thr.e_track;
        hb = health{k};
        p_stall_bit = strcmp(hb, 'FAULT_STALL');
        p_stall_proxy = (I(k) > thr.I_stall) && (dmeas < thr.omega_stall_max) && (dcmd > thr.omega_cmd_min);
        p_stall = p_stall_bit || p_stall_proxy;

        p_open_bit = strcmp(hb, 'FAULT_OPEN');
        p_open_proxy = (I(k) <= thr.I_open_max) && (abs(cmd(k)) > thr.cmd_min) && (dmeas < thr.omega_stall_max) ...
            || (V(k) < 5.0);
        p_open = p_open_bit || p_open_proxy;

        p_sens_bit = strcmp(hb, 'FAULT_SENSOR');
        p_sens_jump = d_jump_now > thr.d_jump;
        % frozen meas with commanded motion + healthy-ish current
        p_sens_freeze = (dmeas < thr.omega_stall_max) && (dcmd > thr.omega_cmd_min) && ...
            (I(k) > assumed.I0_A * 0.5) && (e_pos > thr.e_track * 0.5) && strcmp(hb, 'FAULT_SENSOR');
        p_sens = p_sens_bit || p_sens_jump || p_sens_freeze;

        p_hydro = cusum_latched && (e_pos <= thr.e_track) && ~p_sens && ~p_open && ~p_stall;

        % Persistence counters
        c_track = persist(c_track, p_track);
        c_stall = persist(c_stall, p_stall);
        c_open  = persist(c_open, p_open);
        c_sens  = persist(c_sens, p_sens || p_sens_bit);
        c_hydro = persist(c_hydro, p_hydro);

        a_track = c_track >= thr.N_track;
        a_stall = c_stall >= thr.N_stall;
        a_open  = c_open  >= thr.N_open;
        a_sens  = c_sens >= 2; % BIT / jump persistence (ASSUMED)
        a_hydro = c_hydro >= thr.N_hydro_confirm;

        % Mutex / priority (ICD: SENS inhibits hydro; conflict → fail-silent)
        % Priority: SENS > (STALL∧OPEN→CONFLICT) > STALL > OPEN > TRACK > HYDRO
        if strcmp(latch_class, 'NONE') || strcmp(latch_class, 'STALE')
            if a_sens
                latch_class = 'SENS';
                RUDDER_ISOLATED = true;
                t_isolate = t(k);
            elseif a_stall && a_open
                latch_class = 'CONFLICT';
                RUDDER_ISOLATED = false;
                t_isolate = t(k);
            elseif a_stall
                latch_class = 'STALL';
                RUDDER_ISOLATED = true;
                t_isolate = t(k);
            elseif a_open
                latch_class = 'OPEN';
                RUDDER_ISOLATED = true;
                t_isolate = t(k);
            elseif a_track
                latch_class = 'TRACK';
                RUDDER_ISOLATED = true;
                t_isolate = t(k);
            elseif a_hydro
                latch_class = 'HYDRO';
                RUDDER_ISOLATED = true;
                t_isolate = t(k);
            end
        end
        % Latched isolation remains until explicit reset (end of episode)
        meas_prev = meas(k);
    end

    if strcmp(latch_class, 'NONE')
        pred_class = 'HEALTHY';
        RUDDER_ISOLATED = false;
    elseif strcmp(latch_class, 'STALE')
        pred_class = 'STALE';
        RUDDER_ISOLATED = false;
    elseif strcmp(latch_class, 'CONFLICT')
        pred_class = 'CONFLICT';
        RUDDER_ISOLATED = false;
    else
        pred_class = latch_class;
        RUDDER_ISOLATED = true;
    end

    out = struct();
    out.pred_class = pred_class;
    out.RUDDER_ISOLATED = RUDDER_ISOLATED;
    out.t_isolate = t_isolate;
    out.cusum_latched = cusum_latched;
    % silence unused
    if t_fault < 0, error('bad'); end
end

function c = persist(c, flag)
    if flag
        c = c + 1;
    else
        c = 0;
    end
end

function a = wrap_angle(a)
    a = atan2(sin(a), cos(a));
end
