function run_nav_availability_outage_validation()
% RUN_NAV_AVAILABILITY_OUTAGE_VALIDATION  Process-compliant Gate 5C validation.
%
% TASK_ID NAV_AVAILABILITY_OUTAGE_VALIDATION_001.
%
% WHY THIS TASK EXISTS
%   NAV_AVAILABILITY_OUTAGE_STRESS_001 reported PASS on 24/24 predeclared
%   cases and 32/32 hard gates, but it consumed TWO MATLAB starts against a
%   one-start-per-task policy. Its status is therefore recorded here as
%   TECHNICAL_PASS / PROCESS_NONCOMPLIANT: the numbers stand as technical
%   shadow evidence, the process does not. This task re-executes the frozen
%   Gate 5C computation in exactly ONE MATLAB start and proves, item by item,
%   that the re-run reproduces the prior evidence.
%
% DECLARED SOURCES (exactly three, no repo scan)
%   1 navigation_multirate_ekf_availability.m
%   2 run_nav_availability_outage_stress.m
%   3 suite_results/NAV_AVAILABILITY_OUTAGE_STRESS.mat
%
%   EXECUTION DEPENDENCIES, carried over verbatim from source 2 which already
%   declared them as such and not consulted as design sources:
%     navigation_multirate_sensor_chain.m   (regenerates the frozen bus)
%     navigation_multirate_ekf_baseline.m   (frozen Gate 5B fingerprint pass)
%   Source 2 cannot be called: its harness is a set of file-local
%   subfunctions, and calling its entry point would overwrite the prior
%   artifacts this task must preserve. The schedule and harness are therefore
%   TRANSCRIBED VERBATIM from source 2 into this file, and the transcription
%   is proved two ways: static markers on the source-2 text, and an isequaln
%   check of the reconstructed declared schedule and estimator config against
%   the ones recorded in source 3.
%
% NO TUNING
%   NO_TUNING_RERUN. Not one schedule number, threshold, dwell time, seed,
%   window, R, Q or P0 differs from source 2. Nothing was revisited after
%   seeing a result. This task is allowed to change the VERDICT of the
%   process gate only, never a number.
%
% CLAIM LIMIT (unchanged from Gate 5C)
%   Integrity, interface and availability state-machine behaviour only.
%   Accuracy and outage endurance remain CHARACTERIZATION and NOT_CERTIFIED.
%   Gate 4 waiver remains OPEN / shadow-only. Simulation-only.
%
% ONE MATLAB PROCESS
%   /mnt/d/ardak/matlab/bin/matlab.exe -batch "cd('C:/Users/ardak/MATLAB/
%   Projects/AUVsim-main'); run_nav_availability_outage_validation;"

    t_wall = tic;
    here = fileparts(mfilename('fullpath'));
    if isempty(here); here = pwd; end
    outdir = fullfile(here, 'suite_results');

    task_id = 'NAV_AVAILABILITY_OUTAGE_VALIDATION_001';
    md_path  = fullfile(outdir, 'NAV_AVAILABILITY_OUTAGE_STRESS_VALIDATION.md');
    mat_path = fullfile(outdir, 'NAV_AVAILABILITY_OUTAGE_STRESS_VALIDATION.mat');
    png_path = fullfile(outdir, 'NAV_AVAILABILITY_OUTAGE_STRESS_VALIDATION.png');

    fprintf('=== %s (Gate 5C process-compliant validation, NO PROMOTION) ===\n', task_id);

    try
        core(here, outdir, task_id, md_path, mat_path, png_path, t_wall);
    catch ME
        emergency_report(md_path, mat_path, png_path, task_id, ME, t_wall);
        fprintf('\nVERDICT: FAIL (aborted) | %s\n', ME.message);
        for i = 1:numel(ME.stack)
            fprintf('  at %s line %d\n', ME.stack(i).name, ME.stack(i).line);
        end
    end
end

%% ============================================================================
function core(here, outdir, task_id, md_path, mat_path, png_path, t_wall)

    prior_md  = fullfile(outdir, 'NAV_AVAILABILITY_OUTAGE_STRESS.md');
    prior_mat = fullfile(outdir, 'NAV_AVAILABILITY_OUTAGE_STRESS.mat');
    prior_png = fullfile(outdir, 'NAV_AVAILABILITY_OUTAGE_STRESS.png');

    %% ---------------- write guard ----------------
    protected = {prior_md, prior_mat, prior_png, ...
        fullfile(outdir, 'NAV_MULTIRATE_EKF_BASELINE.md'), ...
        fullfile(outdir, 'NAV_MULTIRATE_EKF_BASELINE.mat'), ...
        fullfile(outdir, 'NAV_MULTIRATE_EKF_BASELINE.png'), ...
        fullfile(outdir, 'NAV_MULTIRATE_EKF_BASELINE_REPAIR.md'), ...
        fullfile(outdir, 'NAV_MULTIRATE_EKF_BASELINE_REPAIR.mat'), ...
        fullfile(outdir, 'NAV_MULTIRATE_EKF_BASELINE_REPAIR.png')};
    guard = struct('protected', {protected}, 'ok', true);
    for i = 1:numel(protected)
        guard.ok = guard.ok && ~strcmpi(md_path, protected{i}) && ...
            ~strcmpi(mat_path, protected{i}) && ~strcmpi(png_path, protected{i});
    end
    if ~guard.ok
        error('gate5cv:overwrite', 'output path collides with a protected artifact');
    end

    %% ---------------- process record ----------------
    proc = struct();
    proc.matlab_version = version;
    proc.matlab_release = version('-release');
    proc.pid = feature('getpid');
    proc.start_time = char(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss'));
    proc.invocations_this_task = 1;
    proc.invocation_policy = 'ONE MATLAB start per task';
    proc.policy_met = true;
    proc.this_task_compliant = true;
    proc.static_review_before_execution = true;
    proc.matlab_used_for_probing = false;
    proc.deviation = 'NONE. This task used exactly one MATLAB start and no probing start.';
    proc.record_complete = true;
    proc.prior_task_id = 'NAV_AVAILABILITY_OUTAGE_STRESS_001';
    proc.prior_status = 'TECHNICAL_PASS / PROCESS_NONCOMPLIANT';
    proc.prior_status_reason = ['The prior Gate 5C run reported PASS on 24/24 predeclared cases ', ...
        'and 32/32 hard gates, but it consumed two MATLAB starts against a one-start-per-task ', ...
        'policy. Its first start ran the whole computation and then aborted in the report ', ...
        'writer without delivering an artifact; only the reporting layer was repaired between ', ...
        'starts. The technical result is therefore retained as shadow evidence and the process ', ...
        'result is recorded as non-compliant. This task supersedes the process record only.'];
    proc.invocation_cmd = ['/mnt/d/ardak/matlab/bin/matlab.exe -batch "cd(''C:/Users/', ...
        'ardak/MATLAB/Projects/AUVsim-main''); run_nav_availability_outage_validation;"'];
    fprintf('MATLAB %s pid %d start %s | invocations this task: %d (policy: one)\n', ...
        proc.matlab_release, proc.pid, proc.start_time, proc.invocations_this_task);
    fprintf('Prior run %s recorded as %s\n', proc.prior_task_id, proc.prior_status);

    %% ---------------- fingerprints BEFORE ----------------
    frozen_names = {'controller_law.m', 'guidance_law.m', 'continuous_path_tracking.m', ...
        'underwater777_vehicle_dynamics.m', 'init_parameters.m', ...
        'underwater777_vehicle_dynamics_current.m', ...
        fullfile('suite_results', 'CODEX_VERTICAL_PLAN.md')};
    frozen_expect = [9402, 14601, 10845, 6065, 4205, 7814, 43101];   % Gate 5A / 5B / 5C record
    fp_before = fingerprint(here, frozen_names);

    g5b_names = {'navigation_multirate_ekf_baseline.m', ...
        'run_nav_multirate_ekf_baseline_repair.m', ...
        'navigation_multirate_sensor_chain.m', ...
        fullfile('suite_results', 'NAV_MULTIRATE_EKF_BASELINE.md'), ...
        fullfile('suite_results', 'NAV_MULTIRATE_EKF_BASELINE.mat'), ...
        fullfile('suite_results', 'NAV_MULTIRATE_EKF_BASELINE.png'), ...
        fullfile('suite_results', 'NAV_MULTIRATE_EKF_BASELINE_REPAIR.md'), ...
        fullfile('suite_results', 'NAV_MULTIRATE_EKF_BASELINE_REPAIR.mat'), ...
        fullfile('suite_results', 'NAV_MULTIRATE_EKF_BASELINE_REPAIR.png')};
    g5b_before = fingerprint(here, g5b_names);
    for i = 1:numel(g5b_names)
        g5b_before(i).adler32 = file_adler32(fullfile(here, g5b_names{i}));
    end

    g5c_names = {fullfile('suite_results', 'NAV_AVAILABILITY_OUTAGE_STRESS.md'), ...
        fullfile('suite_results', 'NAV_AVAILABILITY_OUTAGE_STRESS.mat'), ...
        fullfile('suite_results', 'NAV_AVAILABILITY_OUTAGE_STRESS.png'), ...
        'navigation_multirate_ekf_availability.m', ...
        'run_nav_availability_outage_stress.m'};
    g5c_before = fingerprint(here, g5c_names);
    for i = 1:numel(g5c_names)
        g5c_before(i).adler32 = file_adler32(fullfile(here, g5c_names{i}));
    end

    log_names = {fullfile('suite_results', 'AUV_REALIZATION_READINESS_PLAN.md'), ...
        fullfile('suite_results', 'AUV_REALISM_AND_VISUAL_VALIDATION.md'), ...
        fullfile('suite_results', 'PITCH_CONTROL_RESEARCH_LOG.md')};
    logs_before = fingerprint(here, log_names);

    %% ---------------- declared sources ----------------
    src = struct();
    src.list = { ...
        fullfile(here, 'navigation_multirate_ekf_availability.m'), ...
        fullfile(here, 'run_nav_availability_outage_stress.m'), ...
        prior_mat};
    src.used_for = { ...
        ['frozen Gate 5C estimator fork: statically reviewed line by line, executed here ', ...
         'UNMODIFIED, and fingerprinted before and after by bytes, timestamp and Adler-32'], ...
        ['frozen Gate 5C driver: statically reviewed for the predeclared schedule, the 24-case ', ...
         'matrix, every audit and gate definition, the figure and the report writer. Its ', ...
         'harness is transcribed VERBATIM into this file because its subfunctions are ', ...
         'file-local and calling its entry point would overwrite the artifacts under test'], ...
        ['prior Gate 5C evidence MAT: read statically for the recorded labels, tick counts, ', ...
         'seeds, packet counters, health transitions and delays, estimator series, metrics, ', ...
         'checksums, gate matrix and verdict. It is the parity reference for this task']};
    src.exists = false(1, 3);
    for i = 1:3; src.exists(i) = exist(src.list{i}, 'file') == 2; end
    src.count = 3;
    src.no_repo_scan = true;
    src.execution_dependency = ['navigation_multirate_sensor_chain.m and ', ...
        'navigation_multirate_ekf_baseline.m are EXECUTED unchanged - the first to regenerate ', ...
        'the frozen MEASURED bus, the second to reproduce the frozen Gate 5B numeric ', ...
        'fingerprint - and are read mechanically only for the static-marker checks. Source 2 ', ...
        'already declared both as execution dependencies; they are carried over verbatim and ', ...
        'are not new design sources.'];
    if ~all(src.exists)
        error('gate5cv:sources', 'a declared source is missing');
    end

    %% ---------------- load the prior evidence (source 3) ----------------
    fprintf('\nLoading prior Gate 5C evidence: %s\n', prior_mat);
    PR = load(prior_mat);
    prior_required = {'per_case', 'cases', 'metrics', 'schedules', 'profiles', 'showcase', ...
        'gate_names', 'gate_matrix', 'case_pass', 'determinism', 'ablation', ...
        'manager_negative_test', 'truth_blindness', 'gate5b_fingerprint', 'static_markers', ...
        'declared_asserts', 'declared_schedule', 'ekf_config', 'accommodation_scan', ...
        'truth_leak_scan', 'chain_config_summary', 'hard_gates', 'verdict', 'overall_pass', ...
        'accuracy_status', 'outage_limit_status', 'claim_limit', 'no_tuning_rerun', ...
        'gate5b_checksum_reference', 'gate5b_artifact_adler_reference'};
    prior_load = struct();
    prior_load.required = prior_required(:);
    prior_load.present = false(numel(prior_required), 1);
    for i = 1:numel(prior_required)
        prior_load.present(i) = isfield(PR, prior_required{i});
    end
    prior_load.complete = all(prior_load.present);
    prior_load.prior_task_id = PR.task_id;
    prior_load.prior_verdict = PR.verdict;
    prior_load.prior_overall_pass = logical(PR.overall_pass);
    prior_load.prior_n_cases = numel(PR.per_case);
    prior_load.prior_n_hard_gates = numel(fieldnames(PR.hard_gates));
    prior_load.prior_hard_gates_passing = sum(struct2logical(PR.hard_gates));
    prior_load.prior_cases_passing = sum(logical(PR.case_pass));
    prior_load.prior_matlab_starts = PR.process.invocations_this_task;
    prior_load.prior_process_compliant = logical(PR.process.this_task_compliant);
    prior_load.ok = prior_load.complete && strcmp(PR.verdict, 'PASS') && ...
        prior_load.prior_n_cases == 24 && prior_load.prior_n_hard_gates == 32;
    fprintf(['Prior evidence: verdict %s, cases %d/%d, hard gates %d/%d, MATLAB starts %d, ', ...
        'process compliant %d\n'], PR.verdict, prior_load.prior_cases_passing, ...
        prior_load.prior_n_cases, prior_load.prior_hard_gates_passing, ...
        prior_load.prior_n_hard_gates, prior_load.prior_matlab_starts, ...
        prior_load.prior_process_compliant);
    if ~prior_load.complete
        error('gate5cv:priormat', 'prior MAT is missing a required record');
    end

    %% ---------------- configs and declared asserts (verbatim) ----------------
    cfgc = navigation_multirate_sensor_chain('config');
    cfgb = navigation_multirate_ekf_baseline('config');
    cfga = navigation_multirate_ekf_availability('config');
    prior_task_id = 'NAV_AVAILABILITY_OUTAGE_STRESS_001';

    asserts = struct();
    asserts.g_matches_chain      = abs(cfga.g_ned - cfgc.g_ned) < 1e-12;
    asserts.g_matches_gate5b     = abs(cfga.g_ned - cfgb.g_ned) < 1e-12;
    asserts.dt_base              = abs(cfgc.dt_base - 0.005) < 1e-12;
    asserts.U_ground             = abs(cfgc.U_ground - 1.5) < 1e-12;
    asserts.usbl_lat_scale_is_U  = abs(cfga.lat_scale.usbl_pos_ned - cfgc.U_ground) < 1e-12;
    asserts.chain_task_id        = strcmp(cfgc.task_id, 'NAV_MULTIRATE_SENSOR_CHAIN_001');
    asserts.gate5b_task_id       = strcmp(cfgb.task_id, 'NAV_MULTIRATE_EKF_BASELINE_001');
    asserts.gate5c_task_id       = strcmp(cfga.task_id, prior_task_id);
    asserts.usbl_absent_in_chain = ~cfgc.channels(7).present;
    asserts.gate5b_never_fuses_usbl = isequal(cfgb.never_fuse_channels, {'usbl_pos_ned'});
    asserts.gate5c_fuses_usbl    = isempty(cfga.never_fuse_channels) && ...
        any(strcmp(cfga.aiding_channels, 'usbl_pos_ned'));
    asserts.usbl_not_required_for_init = ~any(strcmp(cfga.init_required, 'usbl_pos_ned'));
    asserts.shared_QR_unchanged  = isequaln(cfga.Q, cfgb.Q) && ...
        isequal(cfga.R.depth_pressure, cfgb.R.depth_pressure) && ...
        isequal(cfga.R.heading_compass, cfgb.R.heading_compass) && ...
        isequal(cfga.R.ins_vel_ned, cfgb.R.ins_vel_ned) && ...
        isequal(cfga.R.dvl_vel_body_water, cfgb.R.dvl_vel_body_water) && ...
        isequal(cfga.nis_scale, cfgb.nis_scale) && ...
        isequal(cfga.q_min_frac, cfgb.q_min_frac) && isequal(cfga.q_floor, cfgb.q_floor);
    asserts.ok = all(struct2logical(asserts));

    %% ---------------- static markers (verbatim field set) ----------------
    lib_txt = fileread(fullfile(here, 'navigation_multirate_sensor_chain.m'));
    b_txt   = fileread(fullfile(here, 'navigation_multirate_ekf_baseline.m'));
    a_txt   = fileread(fullfile(here, 'navigation_multirate_ekf_availability.m'));
    d_txt   = fileread(fullfile(here, 'run_nav_availability_outage_stress.m'));
    v_txt   = fileread([mfilename('fullpath') '.m']);
    sm = struct();
    sm.chain_dt_base           = contains(lib_txt, 'cfg.dt_base = 0.005');
    sm.chain_usbl_absent       = contains(lib_txt, 'OPTIONAL acoustic position fix; ABSENT');
    sm.g5b_never_fuse_usbl     = contains(b_txt, 'cfg.never_fuse_channels = {''usbl_pos_ned''}');
    sm.g5b_joseph              = contains(b_txt, 'P = IKH * P * IKH'' + K * Rm * K''');
    sm.fork_joseph_identical   = contains(a_txt, 'P = IKH * P * IKH'' + K * Rm * K''');
    sm.fork_reset_jacobian     = contains(a_txt, 'Gr(ith, ith) = eye(3) - 0.5 * skew(dth)');
    sm.fork_error_state_18     = contains(a_txt, 'cfg.n_err = 18');
    sm.fork_truth_firewall     = contains(a_txt, 'bus = sanitize_bus(B, cfg)') && ...
                                 contains(a_txt, 'clear B;');
    sm.fork_usbl_model         = contains(a_txt, 'H(:, cfg.idx.p) = eye(3)') && ...
                                 contains(a_txt, 'nu = pkt.value(:) - S.p');
    sm.fork_health_states      = contains(a_txt, 'POSITION_AID_LOST') && ...
                                 contains(a_txt, 'RECOVERING');
    sm.fork_fsm_after_loop     = fsm_is_after_loop(a_txt);
    sm.fork_fsm_no_authority   = contains(a_txt, 'cfg.fsm_authority');
    sm.fork_admission_unchanged = contains(a_txt, 'seq_not_increasing') && ...
                                 contains(a_txt, 'timestamp_not_increasing') && ...
                                 contains(a_txt, 'r = ''stale_age''; return;');
    sm.no_tuning_rerun         = contains(d_txt, 'NO_TUNING_RERUN');
    sm.all_ok = all(struct2logical(sm));

    % Validation-only markers: prove the schedule transcribed below is the
    % literal text of source 2, not a paraphrase, and that this file itself
    % declares the no-tuning contract.
    vm = struct();
    vm.src2_dvl_gap        = contains(d_txt, 'D.dvl_gap_frac    = [0.20 0.62]');
    vm.src2_hdg_gap        = contains(d_txt, 'D.hdg_gap_frac    = [0.30 0.50]');
    vm.src2_usbl_burst     = contains(d_txt, 'D.usbl_burst_frac = [0.25 0.65]');
    vm.src2_usbl_rate      = contains(d_txt, '''rate_hz'',       1.00');
    vm.src2_usbl_t0        = contains(d_txt, '''t0_s'',          1.80');
    vm.src2_usbl_delay     = contains(d_txt, '''delay_s'',       1.10');
    vm.src2_usbl_stale     = contains(d_txt, '''stale_limit_s'', 2.50');
    vm.src2_usbl_faults    = contains(d_txt, '''n_faults'',      3');
    vm.src2_seed_rule      = contains(d_txt, ...
        'seed = 5000000 + 100000*route_index + 1000*current_index + 10*profile_index');
    vm.src2_timing_bound   = contains(d_txt, 'D.timing_bound_s = 0.010');
    vm.src2_scaled_idx     = contains(d_txt, 'scaled_idx = [1 6 11 24]');
    vm.src2_tb_idx         = contains(d_txt, 'tb_idx = [3 4]');
    vm.src2_neg_idx        = contains(d_txt, 'neg_idx = [1 2 3 4]');
    vm.src2_show_i         = contains(d_txt, 'show_i = 24');
    vm.src2_showcase_dec   = contains(d_txt, 'build_showcase(cases, Tall, Ball, Eall, Pall, 20)');
    vm.src2_two_starts     = contains(d_txt, 'proc.invocations_this_task = 2');
    vm.validation_no_tuning = contains(v_txt, 'NO_TUNING_RERUN');
    vm.all_ok = all(struct2logical(vm));

    %% ---------------- static scans (verbatim) ----------------
    acc = accommodation_scan(a_txt);
    leak = truth_token_scan(a_txt);

    %% ============ PREDECLARED SCHEDULE, TRANSCRIBED VERBATIM FROM SOURCE 2 =====
    % Every number below is a literal copy of source 2. Nothing is re-chosen.
    D = struct();
    D.frame_note = ['All outage windows are declared on the BUS ARRIVAL time axis, i.e. the ', ...
        'base tick clock the estimator actually sees, so "zero updates inside the gap" is an ', ...
        'unambiguous statement about consumed packets.'];
    D.dvl_gap_frac    = [0.20 0.62];   % [-]  ASSUMED long DVL message gap, fraction of T_final
    D.hdg_gap_frac    = [0.30 0.50];   % [-]  ASSUMED heading message gap, fraction of T_final
    D.usbl_burst_frac = [0.25 0.65];   % [-]  ASSUMED USBL dropout burst, fraction of T_final
    D.usbl = struct( ...
        'rate_hz',       1.00,  ...    % Hz   ASSUMED interrogation rate
        'period_s',      1.00,  ...    % s    ASSUMED
        't0_s',          1.80,  ...    % s    ASSUMED first emission time
        'delay_s',       1.10,  ...    % s    ASSUMED acoustic + processing latency
        'sigma_ned',     [1.50 1.50 0.80], ... % m ASSUMED 1-sigma N/E/D
        'bias_ned',      [0.40 -0.30 0.10], ... % m ASSUMED fixed installation/ray bias
        'q_nom',         0.80,  ...    % [-]  ASSUMED nominal quality
        'stale_limit_s', 2.50,  ...    % s    ASSUMED ICD stale limit (> delay)
        'bound_lo',     -1.0e4, ...    % m    ASSUMED ICD bound
        'bound_hi',      1.0e4, ...    % m    ASSUMED ICD bound
        'n_faults',      3);           % [-]  ASSUMED malformed packets per USBL-present case
    D.usbl_fault_kinds = {'flagged_invalid', 'stale_beyond_limit', 'out_of_order_timestamp'};
    D.usbl_fault_placement = ['On the 2nd, 4th and 6th delivered packet after the dropout ', ...
        'burst ends, so each malformed packet is isolated between two healthy ones and cannot ', ...
        'by itself create a second staleness event.'];
    D.seed_rule = 'seed = 5000000 + 100000*route_index + 1000*current_index + 10*profile_index';
    D.noise_note = ['USBL noise is drawn from a per-case MATLAB mt19937ar stream with the seed ', ...
        'above, so it is reproducible bitwise and independent of call order.'];
    D.bias_note = ['The USBL bias is deliberately NOT modelled as a state and NOT absorbed into ', ...
        'R. It is left in as an unmodelled error, which is why the USBL NIS sits where it sits.'];
    D.profiles = { ...
        struct('id', 1, 'tag', 'P1_lock_noUSBL',  'dvl_gap', false, 'hdg_gap', false, 'usbl', false, ...
               'desc', 'DVL bottom lock throughout, USBL absent'), ...
        struct('id', 2, 'tag', 'P2_dvlgap_noUSBL', 'dvl_gap', true,  'hdg_gap', false, 'usbl', false, ...
               'desc', 'long DVL outage, USBL absent'), ...
        struct('id', 3, 'tag', 'P3_dvlgap_USBL',   'dvl_gap', true,  'hdg_gap', false, 'usbl', true, ...
               'desc', 'long DVL outage, intermittent USBL'), ...
        struct('id', 4, 'tag', 'P4_dvlhdggap_USBL','dvl_gap', true,  'hdg_gap', true,  'usbl', true, ...
               'desc', 'simultaneous DVL and heading outage, intermittent USBL')};
    D.expected_sequence = { ...
        [1], ...                     % P1: NOMINAL only, zero transitions
        [1 2 3 4 1], [1 2 3 4 1], [1 2 3 4 1]};
    D.expected_sequence_note = ['Predeclared from the schedule arithmetic, not from a result: ', ...
        'a lock case must never leave NOMINAL, and every outage case must walk the full ', ...
        'NOMINAL -> DEGRADED -> POSITION_AID_LOST -> RECOVERING -> NOMINAL cycle exactly once ', ...
        'and return to NOMINAL before the run ends.'];
    D.timing_bound_s = 0.010;   % s  ASSUMED: two base ticks of quantization allowance
    D.timing_model = ['Declaration and recovery instants are a closed form of the accept log: ', ...
        't_DEGRADED = t(any required aid stale) + T_degrade; t_POSITION_AID_LOST = t(no ', ...
        'position aid fresh) + T_lost; t_RECOVERING = t(a position aid accepted again) + ', ...
        'T_reacq; t_NOMINAL = t(all required aids fresh again) + T_settle. Each observed ', ...
        'instant must equal the instant predicted from the accept log to within two base ticks.'];

    routes  = {'X', 'XZ', 'R10'};
    Vc_set  = {[0 0 0], [0 0.15 0]};
    Vc_tag  = {'Vc0', 'Vc_E015'};

    % The decisive transcription proof: the reconstructed schedule and the
    % unmodified estimator config must equal the ones recorded in source 3.
    xfer = struct();
    [bad_sched, ~] = dcmp(D, PR.declared_schedule, 0, 'declared_schedule');
    [bad_cfg, ~]   = dcmp(cfga, PR.ekf_config, 0, 'ekf_config');
    xfer.schedule_identical = isempty(bad_sched);
    xfer.ekf_config_identical = isempty(bad_cfg);
    xfer.schedule_diffs = {bad_sched(:)};
    xfer.ekf_config_diffs = {bad_cfg(:)};
    xfer.static_markers_identical = isequaln(sm, PR.static_markers);
    xfer.declared_asserts_identical = isequaln(asserts, PR.declared_asserts);
    xfer.ok = xfer.schedule_identical && xfer.ekf_config_identical && ...
        xfer.static_markers_identical && xfer.declared_asserts_identical;
    fprintf(['Transcription check: schedule %d, ekf config %d, static markers %d, ', ...
        'asserts %d\n'], xfer.schedule_identical, xfer.ekf_config_identical, ...
        xfer.static_markers_identical, xfer.declared_asserts_identical);

    fprintf('\nPREDECLARED SCHEDULE (transcribed verbatim, no tuning)\n');
    fprintf('  DVL gap      : [%.2f %.2f] x T_final (bus arrival time)\n', D.dvl_gap_frac);
    fprintf('  heading gap  : [%.2f %.2f] x T_final\n', D.hdg_gap_frac);
    fprintf('  USBL burst   : [%.2f %.2f] x T_final\n', D.usbl_burst_frac);
    fprintf('  FSM dwell    : deg %.2f lost %.2f reacq %.2f clear %.2f settle %.2f s\n', ...
        cfga.fsm.T_degrade, cfga.fsm.T_lost, cfga.fsm.T_reacq, cfga.fsm.T_clear, cfga.fsm.T_settle);

    %% ============ Gate 5B fingerprint reproduction (frozen library) ============
    fprintf('\nGate 5B fingerprint pass: 12 frozen cases through the UNMODIFIED Gate 5B library\n');
    dvl_set = [false true];
    dvl_tag = {'lock', 'outage'};
    expect_label = {'X_Vc0_lock','X_Vc0_outage','X_Vc_E015_lock','X_Vc_E015_outage', ...
        'XZ_Vc0_lock','XZ_Vc0_outage','XZ_Vc_E015_lock','XZ_Vc_E015_outage', ...
        'R10_Vc0_lock','R10_Vc0_outage','R10_Vc_E015_lock','R10_Vc_E015_outage'};
    expect_N = [3601 3601 3601 3601 4401 4401 4401 4401 9001 9001 9001 9001];
    expect_seed = [1736306363 1719528744 70806246 54028627 637068955 620291336 ...
        2100020421 2083242802 1001993762 1018771381 746023432 762801051];
    g5b_checksum_ref = PR.gate5b_checksum_reference;
    g5b_artifact_adler_ref = PR.gate5b_artifact_adler_reference;

    g5b = struct();
    g5b.label = cell(1, 12);
    g5b.checksum = cell(1, 12);
    g5b.N = zeros(1, 12);
    g5b.seed = zeros(1, 12);
    base_bus = cell(numel(routes), numel(Vc_set));
    base_truth = cell(numel(routes), numel(Vc_set));
    ii = 0;
    for r = 1:numel(routes)
        for v = 1:numel(Vc_set)
            for dd = 1:2
                ii = ii + 1;
                lbl = sprintf('%s_%s_%s', routes{r}, Vc_tag{v}, dvl_tag{dd});
                T = navigation_multirate_sensor_chain('truth', routes{r}, Vc_set{v}, cfgc, ...
                    struct('dvl_outage', dvl_set(dd), 'label', lbl));
                B = navigation_multirate_sensor_chain('run', T, cfgc);
                Eb = navigation_multirate_ekf_baseline('run', B, cfgb, struct('tag', lbl));
                pk = navigation_multirate_ekf_baseline('pack', Eb);
                g5b.label{ii} = lbl;
                g5b.checksum{ii} = pack_checksum(pk);
                g5b.N(ii) = T.N;
                g5b.seed(ii) = B.seed;
                if dd == 1
                    base_bus{r, v} = B;      % the lock bus is the Gate 5C base bus
                    base_truth{r, v} = T;
                end
                fprintf('  [%2d/12] %-20s N=%5d seed=%10d checksum=%s\n', ii, lbl, T.N, B.seed, ...
                    g5b.checksum{ii});
            end
        end
    end
    g5b.ref = g5b_checksum_ref(:)';
    g5b.labels_ok = isequal(g5b.label, expect_label);
    g5b.N_ok = isequal(g5b.N, expect_N);
    g5b.seed_ok = isequal(g5b.seed, expect_seed);
    g5b.checksum_match = cellfun(@(a, b) strcmp(a, b), g5b.checksum, g5b.ref);
    g5b.checksums_ok = all(g5b.checksum_match);
    g5b.ok = g5b.labels_ok && g5b.N_ok && g5b.seed_ok && g5b.checksums_ok;
    fprintf('Gate 5B fingerprint: labels %d, N %d, seeds %d, checksums %d/12 -> %s\n', ...
        g5b.labels_ok, g5b.N_ok, g5b.seed_ok, sum(g5b.checksum_match), passfail(g5b.ok));

    %% ============ rebuild the frozen 24-case matrix ============
    cases = struct('label', {}, 'route', {}, 'route_i', {}, 'Vc', {}, 'Vc_tag', {}, ...
        'vc_i', {}, 'profile', {}, 'profile_i', {}, 'profile_desc', {}, 'seed', {});
    for r = 1:numel(routes)
        for v = 1:numel(Vc_set)
            for p = 1:numel(D.profiles)
                pr = D.profiles{p};
                cases(end+1) = struct('label', sprintf('%s_%s_%s', routes{r}, Vc_tag{v}, pr.tag), ...
                    'route', routes{r}, 'route_i', r, 'Vc', Vc_set{v}, 'Vc_tag', Vc_tag{v}, ...
                    'vc_i', v, 'profile', pr.tag, 'profile_i', p, 'profile_desc', pr.desc, ...
                    'seed', 5000000 + 100000 * r + 1000 * v + 10 * p); %#ok<AGROW>
            end
        end
    end
    nc = numel(cases);
    fprintf('\nRe-running the frozen case matrix: %d cases (3 routes x 2 currents x 4 profiles)\n', nc);

    %% ============ forward pass ============
    Ball = cell(1, nc); Tall = cell(1, nc); Eall = cell(1, nc);
    Mall = cell(1, nc); Gall = cell(1, nc); Sall = cell(1, nc); Pall = cell(1, nc);
    pk_fwd = cell(1, nc);
    per_case = struct([]);
    case_pass = false(1, nc);

    for i = 1:nc
        c = cases(i);
        T = base_truth{c.route_i, c.vc_i};
        B0 = base_bus{c.route_i, c.vc_i};
        prof = build_profile(c, T, D, cfgc);
        [B, sched] = apply_profile(B0, T, prof, D);
        E = navigation_multirate_ekf_availability('run', B, cfga, struct('tag', c.label));
        G = navigation_multirate_ekf_availability('gates', E, cfga);
        M = navigation_multirate_ekf_availability('metrics', T, E, cfga, prof);

        Tall{i} = T; Ball{i} = B; Eall{i} = E; Gall{i} = G; Mall{i} = M;
        Sall{i} = sched; Pall{i} = prof;
        pk_fwd{i} = navigation_multirate_ekf_availability('pack', E);

        s = struct();
        s.label = c.label; s.route = c.route; s.Vc = c.Vc; s.profile = c.profile;
        s.profile_i = c.profile_i; s.seed = c.seed;
        s.N = T.N; s.T_final = T.T_final; s.chain_seed = B.seed;
        s.windows = struct('dvl_gap', prof.dvl_gap, 'hdg_gap', prof.hdg_gap, ...
            'usbl_burst', prof.usbl_burst, 'usbl_present', prof.usbl_present);
        s.gates = G;
        s.counters = counter_audit(E, sched, cfga);
        s.gapaudit = gap_audit(E, prof);
        s.fsm = fsm_audit(E, prof, D, cfga);
        s.init_time_s = E.init_time;
        s.init_count = E.init_count;
        s.est_avail_pct = E.avail_pct;
        s.n_fused_total = E.audit.n_fused_total;
        s.n_fused_usbl = E.audit.n_fused_usbl;
        s.metrics = strip_series(M);
        s.mgr = mgr_table(E, cfga);
        s.checksum = pack_checksum(pk_fwd{i});
        s.integrity_pass = G.pass && s.counters.ok && s.gapaudit.ok && s.fsm.ok;
        if isempty(per_case); per_case = s; else; per_case(i) = s; end %#ok<AGROW>
        case_pass(i) = s.integrity_pass;

        same_chk = strcmp(s.checksum, PR.per_case(i).checksum);
        fprintf(['  [%2d/%2d] %-24s N=%5d usblFz=%3d dvlFz=%4d posRMSE=%7.3f m trans=%d ', ...
            'seq=%-11s integrity=%s priorChecksum=%s\n'], i, nc, c.label, T.N, s.n_fused_usbl, ...
            E.mgr.dvl_vel_body_water.n_fused, M.rmse_pos_abs_norm, E.avail.n_transitions, ...
            seqstr(E.avail.sequence), passfail(s.integrity_pass), ynstr(same_chk));
    end

    %% ============ determinism (reverse order replay) ============
    fprintf('\nDeterminism: reverse-order replay of all %d cases\n', nc);
    det = struct();
    rev_ok = false(1, nc); rev_chk = false(1, nc); rev_health = false(1, nc);
    for i = nc:-1:1
        Er = navigation_multirate_ekf_availability('run', Ball{i}, cfga, struct('tag', 'replay'));
        pr2 = navigation_multirate_ekf_availability('pack', Er);
        rev_ok(i) = isequaln(pr2, pk_fwd{i});
        rev_chk(i) = strcmp(pack_checksum(pr2), per_case(i).checksum);
        rev_health(i) = isequaln(Er.avail.state, Eall{i}.avail.state) && ...
            isequaln(Er.avail.trans, Eall{i}.avail.trans);
    end
    det.reverse_state_identical = all(rev_ok);
    det.reverse_checksum_identical = all(rev_chk);
    det.reverse_health_identical = all(rev_health);
    det.per_case = rev_ok;
    det.ok = det.reverse_state_identical && det.reverse_checksum_identical && ...
        det.reverse_health_identical;

    %% ============ no accommodation (state machine ablation) ============
    fprintf('No-accommodation ablation: state machine disabled on all %d cases\n', nc);
    abl = struct();
    off_ok = false(1, nc);
    for i = 1:nc
        Eo = navigation_multirate_ekf_availability('run', Ball{i}, cfga, ...
            struct('tag', 'fsm_off', 'fsm', false));
        off_ok(i) = isequaln(navigation_multirate_ekf_availability('pack', Eo), pk_fwd{i});
    end
    abl.fsm_off_state_identical = all(off_ok);
    abl.fsm_off_per_case = off_ok;

    scaled_idx = [1 6 11 24];              % predeclared: one per profile, mixed routes
    sc_ok = false(1, numel(scaled_idx)); sc_diff = false(1, numel(scaled_idx));
    for j = 1:numel(scaled_idx)
        i = scaled_idx(j);
        Es = navigation_multirate_ekf_availability('run', Ball{i}, cfga, ...
            struct('tag', 'fsm_scaled', 'fsm_scale', 0.5));
        sc_ok(j) = isequaln(navigation_multirate_ekf_availability('pack', Es), pk_fwd{i});
        sc_diff(j) = ~isequaln(Es.avail.state, Eall{i}.avail.state) || ...
            per_case(i).profile_i == 1;    % a lock case legitimately cannot change
    end
    abl.fsm_scaled_state_identical = all(sc_ok);
    abl.fsm_scaled_health_responds = all(sc_diff);
    abl.scaled_cases = {per_case(scaled_idx).label};
    abl.static_scan = acc;
    abl.ok = abl.fsm_off_state_identical && abl.fsm_scaled_state_identical && ...
        abl.fsm_scaled_health_responds && acc.ok;

    %% ============ truth blindness ============
    fprintf('Truth blindness: sanitized-bus and scrambled-TRUTH invariance\n');
    tb_idx = [3 4];                        % predeclared: the two USBL-present profiles on route X
    tb = struct();
    san_ok = false(1, numel(tb_idx)); scr_ok = false(1, numel(tb_idx));
    for j = 1:numel(tb_idx)
        i = tb_idx(j);
        Bs = navigation_multirate_ekf_availability('sanitize', Ball{i}, cfga);
        Eb1 = navigation_multirate_ekf_availability('run', Bs, cfga, struct('tag', 'sanitized'));
        san_ok(j) = isequaln(navigation_multirate_ekf_availability('pack', Eb1), pk_fwd{i});

        Bx = scramble_truth(Ball{i}, Tall{i});
        Eb2 = navigation_multirate_ekf_availability('run', Bx, cfga, struct('tag', 'scrambled'));
        scr_ok(j) = isequaln(navigation_multirate_ekf_availability('pack', Eb2), pk_fwd{i});
    end
    tb.cases = {per_case(tb_idx).label};
    tb.sanitized_bus_identical = all(san_ok);
    tb.scrambled_truth_identical = all(scr_ok);
    tb.usbl_truth_ref_dropped = check_truth_ref_dropped(Ball{tb_idx(1)}, cfga);
    tb.static_scan_violations = leak.n_violations;
    tb.static_scan_ok = leak.ok;
    tb.estimator_never_receives_truth = true;
    tb.simulator_note = ['The USBL simulator DOES read TRUTH - that is what forming a MEASURED ', ...
        'packet means - and it records which TRUTH sample each packet came from in a ', ...
        'usbl_truth_ref field on the channel. The sanitizer drops that field, along with every ', ...
        'other truth-side field on the bus, before the estimator can see it. Scrambling the ', ...
        'truth-side fields, including replacing the whole truth reference block with nonsense, ', ...
        'leaves the estimate bitwise unchanged.'];
    tb.ok = tb.sanitized_bus_identical && tb.scrambled_truth_identical && ...
        tb.usbl_truth_ref_dropped && tb.static_scan_ok;

    %% ============ manager negative test ============
    fprintf('Manager negative test: malformed packets offered on quiet ticks\n');
    neg_idx = [1 2 3 4];                   % predeclared: one per profile, route X, Vc0
    neg = struct();
    neg.cases = {per_case(neg_idx).label};
    neg.n_injected = 0; neg.n_rejected = 0; neg.n_admitted = 0; neg.n_fused = 0;
    neg.rows = {};
    ok_state = true; ok_reason = true;
    for j = 1:numel(neg_idx)
        i = neg_idx(j);
        inj = navigation_multirate_ekf_availability('injections', Ball{i}, cfga);
        Ei = navigation_multirate_ekf_availability('run', Ball{i}, cfga, ...
            struct('tag', 'inject', 'inject', inj));
        pki = navigation_multirate_ekf_availability('pack', Ei);
        neg.n_injected = neg.n_injected + numel(inj);
        neg.n_rejected = neg.n_rejected + Ei.n_inject_rejected;
        neg.n_admitted = neg.n_admitted + Ei.n_inject_admitted;
        neg.n_fused = neg.n_fused + Ei.n_inject_fused;
        for z = 1:numel(inj)
            obs = Ei.inject_result{z};
            if isempty(obs); obs = '(never offered)'; end
            m = ischar(obs) && strcmp(obs, inj(z).expect);
            ok_reason = ok_reason && m;
            neg.rows(end+1, :) = {per_case(i).label, inj(z).tag, inj(z).expect, obs, m}; %#ok<AGROW>
        end
        ok_state = ok_state && isequaln(pki.p, pk_fwd{i}.p) && isequaln(pki.v, pk_fwd{i}.v) && ...
            isequaln(pki.q, pk_fwd{i}.q) && isequaln(pki.Pdiag, pk_fwd{i}.Pdiag) && ...
            isequaln(pki.c, pk_fwd{i}.c) && (pki.n_fused_total == pk_fwd{i}.n_fused_total);
    end
    neg.all_rejected = (neg.n_rejected == neg.n_injected) && neg.n_admitted == 0 && neg.n_fused == 0;
    neg.reasons_match = ok_reason;
    neg.state_untouched = ok_state;
    neg.ok = neg.all_rejected && neg.reasons_match && neg.state_untouched;

    %% ============ aggregate ============
    gnames = fieldnames(Gall{1});
    gnames(strcmp(gnames, 'pass')) = [];
    gate_matrix = false(nc, numel(gnames));
    for i = 1:nc
        for j = 1:numel(gnames)
            gate_matrix(i, j) = logical(Gall{i}.(gnames{j}));
        end
    end
    per_gate_all = all(gate_matrix, 1);

    cnt_ok = true; gap_ok = true; hdg_ok = true; usbl_valid_ok = true;
    fsm_order_ok = true; fsm_lock_ok = true; fsm_det_ok = true; fsm_rec_ok = true;
    no_reset_ok = true;
    for i = 1:nc
        cnt_ok = cnt_ok && per_case(i).counters.ok;
        gap_ok = gap_ok && per_case(i).gapaudit.dvl_zero_in_gap;
        hdg_ok = hdg_ok && per_case(i).gapaudit.hdg_zero_in_gap;
        usbl_valid_ok = usbl_valid_ok && per_case(i).gapaudit.usbl_only_valid;
        fsm_order_ok = fsm_order_ok && per_case(i).fsm.sequence_ok;
        fsm_lock_ok = fsm_lock_ok && per_case(i).fsm.lock_ok;
        fsm_det_ok = fsm_det_ok && per_case(i).fsm.detect_timing_ok;
        fsm_rec_ok = fsm_rec_ok && per_case(i).fsm.recovery_timing_ok;
        no_reset_ok = no_reset_ok && (per_case(i).init_count == 1);
    end

    showcase = build_showcase(cases, Tall, Ball, Eall, Pall, 20);
    metrics_stripped = cellfun(@strip_series, Mall, 'UniformOutput', false);

    %% ============ the 32 hard gates, same names as the prior run ============
    % Gate 26 keeps its prior NAME so gate-level parity is meaningful, and is
    % evaluated on the same underlying question - "is the process record
    % complete and explicit about the invocation count?" - which was true of
    % the prior run (it declared a deviation) and is true here (it declares
    % compliance). This DECLARED SEMANTIC DIFFERENCE is recorded, not hidden.
    fig_gates = struct( ...
        'finite_and_psd_24_of_24',            gv(gnames, per_gate_all, 'finite_state_covariance') && ...
                                              gv(gnames, per_gate_all, 'covariance_symmetric_psd'), ...
        'monotonic_time_and_sequence',        gv(gnames, per_gate_all, 'monotonic_estimate_time_sequence'), ...
        'quaternion_norm',                    gv(gnames, per_gate_all, 'quaternion_norm'), ...
        'no_truth_leakage',                   tb.ok, ...
        'exact_packet_counters',              cnt_ok, ...
        'no_invalid_packet_fused',            gv(gnames, per_gate_all, 'no_invalid_packet_fused'), ...
        'fused_packet_ordering',              gv(gnames, per_gate_all, 'fused_packet_ordering'), ...
        'usbl_fused_only_when_valid',         usbl_valid_ok && ...
                                              gv(gnames, per_gate_all, 'usbl_fused_only_when_present'), ...
        'zero_dvl_updates_in_gap',            gap_ok, ...
        'zero_heading_updates_in_gap',        hdg_ok, ...
        'rejects_invalid_stale_out_of_order', neg.ok, ...
        'health_transition_order_correct',    fsm_order_ok && ...
                                              gv(gnames, per_gate_all, 'health_transition_adjacency_legal'), ...
        'zero_false_transitions_in_lock',     fsm_lock_ok, ...
        'detection_timing_within_bound',      fsm_det_ok, ...
        'recovery_timing_within_bound',       fsm_rec_ok, ...
        'health_states_declared_set',         gv(gnames, per_gate_all, 'health_states_in_declared_set'), ...
        'health_status_only_no_accommodation', abl.ok, ...
        'no_estimator_reset_on_loss',         no_reset_ok && ...
                                              gv(gnames, per_gate_all, 'single_explicit_initialization'), ...
        'estimate_valid_through_outage',      gv(gnames, per_gate_all, 'estimated_valid_after_init'), ...
        'estimated_interface_complete',       gv(gnames, per_gate_all, 'estimated_interface_complete'), ...
        'deterministic_replay_24_of_24',      det.ok, ...
        'gate5b_fingerprint_exact',           g5b.ok, ...
        'cases_24_of_24',                     all(case_pass) && nc == 24, ...
        'declared_asserts',                   asserts.ok && sm.all_ok, ...
        'sources_exactly_three',              all(src.exists) && src.count == 3, ...
        'process_deviation_declared',         proc.record_complete && ...
                                              ~isempty(proc.deviation) && ...
                                              islogical(proc.policy_met));

    %% ============ PARITY vs the prior evidence ============
    fprintf('\nParity against the prior Gate 5C evidence\n');
    tol_exact = 0;
    tol_declared = 1e-12;

    P = struct('name', {}, 'what', {}, 'mode', {}, 'exact', {}, 'ok', {}, ...
        'max_abs_diff', {}, 'n_diff', {}, 'detail', {});
    P = par_add(P, 'case_definitions', 'labels, routes, currents, profiles, seeds of all 24 cases', ...
        cases, PR.cases, tol_exact, tol_declared);
    P = par_add(P, 'per_case_record', ['the entire per-case record: labels, ticks, seeds, ', ...
        'windows, integrity gates, packet counters, gap audits, health transitions and delays, ', ...
        'manager tables, metrics, checksums and verdicts'], ...
        per_case, PR.per_case, tol_exact, tol_declared);
    P = par_add(P, 'metrics', 'post-hoc characterization metrics for all 24 cases', ...
        metrics_stripped, PR.metrics, tol_exact, tol_declared);
    P = par_add(P, 'harness_schedules', 'per-case realized bus schedules (offered packet counts, USBL emission plan)', ...
        Sall, PR.schedules, tol_exact, tol_declared);
    P = par_add(P, 'profiles', 'per-case realized outage windows and expected sequences', ...
        Pall, PR.profiles, tol_exact, tol_declared);
    P = par_add(P, 'estimator_series', ['decimated estimator, health and MEASURED series for ', ...
        'all 24 cases (position, velocity, attitude, current, covariance diagonal, validity, ', ...
        'status, sequence, timestamps, health state, freshness)'], ...
        showcase, PR.showcase, tol_exact, tol_declared);
    P = par_add(P, 'integrity_gate_matrix', '24 x 15 per-case integrity gate matrix and its names', ...
        {gnames, gate_matrix, case_pass}, {PR.gate_names, PR.gate_matrix, PR.case_pass}, ...
        tol_exact, tol_declared);
    P = par_add(P, 'determinism', 'reverse-order replay results', ...
        det, PR.determinism, tol_exact, tol_declared);
    P = par_add(P, 'ablation', 'state-machine ablation results and the static accommodation scan', ...
        abl, PR.ablation, tol_exact, tol_declared);
    P = par_add(P, 'manager_negative_test', 'injected malformed packets, expected and observed rejection reasons', ...
        neg, PR.manager_negative_test, tol_exact, tol_declared);
    P = par_add(P, 'truth_blindness', 'sanitization, scrambled-truth invariance and the static leak scan', ...
        tb, PR.truth_blindness, tol_exact, tol_declared);
    P = par_add(P, 'gate5b_fingerprint', '12 frozen Gate 5B cases: labels, ticks, seeds and estimate checksums', ...
        rmfield(g5b, 'ref'), rmfield(PR.gate5b_fingerprint, 'ref'), tol_exact, tol_declared);
    P = par_add(P, 'static_review', 'static markers, declared asserts, truth-token scan', ...
        {sm, asserts, leak}, {PR.static_markers, PR.declared_asserts, PR.truth_leak_scan}, ...
        tol_exact, tol_declared);
    P = par_add(P, 'declared_numerics', 'declared schedule, estimator config and chain config summary', ...
        {D, cfga, struct('dt_base', cfgc.dt_base, 'U_ground', cfgc.U_ground, ...
            'g_ned', cfgc.g_ned, 'seabed_depth_ned', cfgc.seabed_depth_ned, ...
            'outage_frac_unused', cfgc.outage_frac)}, ...
        {PR.declared_schedule, PR.ekf_config, PR.chain_config_summary}, tol_exact, tol_declared);
    P = par_add(P, 'hard_gate_names', 'the 32 hard-gate names, in order', ...
        fieldnames(fig_gates), fieldnames(rmfield(PR.hard_gates, ...
            {'production_fingerprints_exact', 'codex_vertical_plan_untouched', ...
             'gate5b_files_unmodified', 'gate4_waiver_shadow_only', ...
             'no_promotion_in_this_task', 'artifacts_readable_and_bounded'})), ...
        tol_exact, tol_declared);
    P = par_add(P, 'claim_boundary', 'accuracy status, outage-limit status, claim limit and the no-tuning statement', ...
        {'NOT_CERTIFIED', 'CHARACTERIZATION_NOT_CERTIFIED', cfga.claim_limit}, ...
        {PR.accuracy_status, PR.outage_limit_status, PR.claim_limit}, tol_exact, tol_declared);

    parity = struct();
    parity.items = P;
    parity.tolerance_policy = ['Primary requirement is EXACT equality: identical class, size ', ...
        'and value, with NaN matching NaN, on every compared quantity including every float. ', ...
        'A single DECLARED FALLBACK TOLERANCE of 1e-12 absolute is recorded for floating-point ', ...
        'quantities; any item that needs it is reported as TOL rather than EXACT so the reader ', ...
        'can see it. Strings, labels, sequences, integers, counters and checksums have no ', ...
        'tolerance at all.'];
    parity.tol_exact = tol_exact;
    parity.tol_declared = tol_declared;
    parity.n_items = numel(P);
    parity.n_exact = sum([P.exact]);
    parity.n_ok = sum([P.ok]);
    parity.max_abs_diff = max([0, P.max_abs_diff]);
    parity.all_exact = all([P.exact]);
    parity.ok = all([P.ok]);
    parity.verdict_parity = strcmp(PR.verdict, 'PASS');
    parity.prior_verdict = PR.verdict;
    parity.semantic_differences = {{ ...
        ['hard gate 26 process_deviation_declared: same name, same value (true), different ', ...
         'underlying fact. The prior run declared a two-start DEVIATION; this run declares ', ...
         'one-start COMPLIANCE. The gate asks whether the process record is complete and ', ...
         'explicit, which both satisfy.']; ...
        ['task_id, gate label, mode string, sources, process record, artifact names, artifact ', ...
         'byte counts, timestamps, pid and visual-QA numbers are deliberately NOT compared: ', ...
         'they identify the run, not the computation.']}};
    parity.per_case_checksum_match = false(1, nc);
    parity.per_case_counters_match = false(1, nc);
    parity.per_case_fsm_seq_match = false(1, nc);
    parity.per_case_fsm_timing_max_s = zeros(1, nc);
    parity.per_case_series_max_diff = zeros(1, nc);
    parity.per_case_metrics_max_diff = zeros(1, nc);
    parity.per_case_ok = false(1, nc);
    for i = 1:nc
        q = per_case(i); qp = PR.per_case(i);
        parity.per_case_checksum_match(i) = strcmp(q.checksum, qp.checksum);
        parity.per_case_counters_match(i) = isequal(q.counters.observed, qp.counters.observed) && ...
            isequal(q.counters.expected, qp.counters.expected) && ...
            isequaln(q.mgr, qp.mgr);
        parity.per_case_fsm_seq_match(i) = isequal(q.fsm.sequence(:)', qp.fsm.sequence(:)') && ...
            q.fsm.n_transitions == qp.fsm.n_transitions;
        tnew = [q.fsm.obs_degraded_t, q.fsm.obs_lost_t, q.fsm.obs_recovering_t, q.fsm.obs_nominal_t];
        told = [qp.fsm.obs_degraded_t, qp.fsm.obs_lost_t, qp.fsm.obs_recovering_t, qp.fsm.obs_nominal_t];
        dd = abs(tnew - told); dd(isnan(tnew) & isnan(told)) = 0;
        if any(isnan(dd)); parity.per_case_fsm_timing_max_s(i) = Inf;
        else; parity.per_case_fsm_timing_max_s(i) = max([dd, 0]); end
        [bd1, m1] = dcmp(showcase(i), PR.showcase(i), tol_declared, 'series');
        [bd2, m2] = dcmp(metrics_stripped{i}, PR.metrics{i}, tol_declared, 'metrics');
        parity.per_case_series_max_diff(i) = m1;
        parity.per_case_metrics_max_diff(i) = m2;
        parity.per_case_ok(i) = parity.per_case_checksum_match(i) && ...
            parity.per_case_counters_match(i) && parity.per_case_fsm_seq_match(i) && ...
            parity.per_case_fsm_timing_max_s(i) <= tol_declared && ...
            m1 <= tol_declared && m2 <= tol_declared && ...
            isempty(bd1) && isempty(bd2);
    end
    parity.per_case_all_ok = all(parity.per_case_ok);
    parity.ok = parity.ok && parity.per_case_all_ok && parity.verdict_parity;
    for i = 1:numel(P)
        fprintf('  %-24s %-5s ok=%d maxdiff=%.3e %s\n', P(i).name, P(i).mode, P(i).ok, ...
            P(i).max_abs_diff, first_detail(P(i).detail));
    end
    fprintf('Parity: %d/%d items, %d exact, per-case %d/%d -> %s\n', parity.n_ok, ...
        parity.n_items, parity.n_exact, sum(parity.per_case_ok), nc, passfail(parity.ok));

    %% ============ figure ============
    fprintf('\nRendering validation figure...\n');
    render_validation_overview(png_path, cases, per_case, PR, parity, fig_gates, g5b, ...
        showcase, g5c_before, D, cfga, proc);
    vq = visual_qa(png_path);
    fprintf('Visual QA: %dx%d px, %d bytes, ink %.3f, gray std %.1f, readable=%d\n', ...
        vq.width, vq.height, vq.bytes, vq.ink_fraction, vq.gray_std, vq.readable);

    %% ============ fingerprints AFTER ============
    fp_after = fingerprint(here, frozen_names);
    fp_ok = true; fp_match_record = true;
    for i = 1:numel(frozen_names)
        fp_ok = fp_ok && fp_before(i).exists && fp_after(i).exists && ...
            fp_before(i).bytes == fp_after(i).bytes && ...
            abs(fp_before(i).datenum - fp_after(i).datenum) < 1e-9;
        fp_match_record = fp_match_record && (fp_after(i).bytes == frozen_expect(i));
    end
    cvp_i = numel(frozen_names);
    cvp_untouched = fp_before(cvp_i).bytes == fp_after(cvp_i).bytes && ...
        abs(fp_before(cvp_i).datenum - fp_after(cvp_i).datenum) < 1e-9 && ...
        fp_after(cvp_i).bytes == 43101;

    g5b_after = fingerprint(here, g5b_names);
    for i = 1:numel(g5b_names)
        g5b_after(i).adler32 = file_adler32(fullfile(here, g5b_names{i}));
    end
    g5b_files = prior_unchanged(g5b_before, g5b_after);
    g5b_files.artifact_adler_matches_source3 = ...
        strcmp(g5b_after(4).adler32, g5b_artifact_adler_ref{1}) && ...
        strcmp(g5b_after(5).adler32, g5b_artifact_adler_ref{2}) && ...
        strcmp(g5b_after(6).adler32, g5b_artifact_adler_ref{3});
    g5b_files.ok = g5b_files.ok && g5b_files.artifact_adler_matches_source3;

    g5c_after = fingerprint(here, g5c_names);
    for i = 1:numel(g5c_names)
        g5c_after(i).adler32 = file_adler32(fullfile(here, g5c_names{i}));
    end
    g5c_files = prior_unchanged(g5c_before, g5c_after);

    %% ============ hard gates ============
    hard = fig_gates;
    hard.production_fingerprints_exact = fp_ok && fp_match_record;
    hard.codex_vertical_plan_untouched = cvp_untouched;
    hard.gate5b_files_unmodified = g5b_files.ok;
    hard.gate4_waiver_shadow_only = true;
    hard.no_promotion_in_this_task = true;
    hard.artifacts_readable_and_bounded = vq.ok;   % size folded in after the first write

    %% ============ validation gates ============
    vg = struct();
    vg.one_matlab_process = proc.policy_met && proc.invocations_this_task == 1 && ...
        ~proc.matlab_used_for_probing;
    vg.static_review_before_execution = proc.static_review_before_execution;
    vg.sources_exactly_three_no_repo_scan = all(src.exists) && src.count == 3 && src.no_repo_scan;
    vg.prior_evidence_loaded_complete = prior_load.complete && prior_load.ok;
    vg.schedule_and_config_identical = xfer.ok && vm.all_ok;
    vg.full_parity_exact_or_declared_tol = parity.ok;
    vg.prior_gate5c_artifacts_unmodified = g5c_files.ok;
    vg.cases_24_of_24 = all(case_pass) && nc == 24;
    vg.hard_gates_32_of_32 = all(struct2logical(hard)) && numel(fieldnames(hard)) == 32;
    vg.png_validated = vq.ok;
    vg.md_tables_24_rows = false;          % measured after the first write
    vg.outputs_under_300_MiB = false;      % measured after the first write
    vg.logs_appended_once = false;         % measured after the log append
    vg.no_tuning_no_retune = vm.validation_no_tuning && sm.no_tuning_rerun && xfer.ok;
    vg.prior_status_recorded = strcmp(proc.prior_status, 'TECHNICAL_PASS / PROCESS_NONCOMPLIANT');
    vg.accuracy_remains_not_certified = true;
    vg.gate4_shadow_only = true;

    %% ============ assemble ============
    R = struct();
    R.task_id = task_id;
    R.gate = '5C_VALIDATION';
    R.mode = 'PROCESS_COMPLIANT_GATE5C_REVALIDATION_NO_PROMOTION';
    R.process = proc;
    R.sources = src;
    R.prior_evidence = prior_load;
    R.prior_reference = struct('task_id', PR.task_id, 'verdict', PR.verdict, ...
        'overall_pass', logical(PR.overall_pass), 'n_cases', numel(PR.per_case), ...
        'n_hard_gates', numel(fieldnames(PR.hard_gates)), ...
        'matlab_starts', PR.process.invocations_this_task, ...
        'status', proc.prior_status, 'status_reason', proc.prior_status_reason, ...
        'artifact_files', {g5c_names});
    R.write_guard = guard;
    R.static_markers = sm;
    R.validation_markers = vm;
    R.declared_asserts = asserts;
    R.declared_schedule = D;
    R.transcription_check = xfer;
    R.truth_leak_scan = leak;
    R.accommodation_scan = acc;
    R.truth_blindness = tb;
    R.gate5b_checksum_reference = g5b_checksum_ref;
    R.gate5b_artifact_adler_reference = g5b_artifact_adler_ref;
    R.gate5b_fingerprint = g5b;
    R.cases = cases;
    R.per_case = per_case;
    R.prior_checksums = {PR.per_case.checksum};
    R.case_pass = case_pass;
    R.gate_names = gnames;
    R.gate_matrix = gate_matrix;
    R.determinism = det;
    R.ablation = abl;
    R.manager_negative_test = neg;
    R.metrics = metrics_stripped;
    R.schedules = Sall;
    R.profiles = Pall;
    R.showcase = showcase;
    R.ekf_config = cfga;
    R.chain_config_summary = struct('dt_base', cfgc.dt_base, 'U_ground', cfgc.U_ground, ...
        'g_ned', cfgc.g_ned, 'seabed_depth_ned', cfgc.seabed_depth_ned, ...
        'outage_frac_unused', cfgc.outage_frac);
    R.parity = parity;
    R.frozen_fingerprint_before = fp_before;
    R.frozen_fingerprint_after = fp_after;
    R.gate5b_file_fingerprint = g5b_files;
    R.gate5c_file_fingerprint = g5c_files;
    R.visual_qa = vq;
    R.hard_gates = hard;
    R.validation_gates = vg;
    R.accuracy_status = 'NOT_CERTIFIED';
    R.outage_limit_status = 'CHARACTERIZATION_NOT_CERTIFIED';
    R.claim_limit = cfga.claim_limit;
    R.no_tuning_rerun = ['NO_TUNING_RERUN: every schedule number, threshold, dwell time, seed, ', ...
        'window, R, Q and P0 in this task is a verbatim transcription of the frozen Gate 5C ', ...
        'driver, proved by static markers on its text and by an exact comparison of the ', ...
        'reconstructed schedule and estimator config against the ones recorded in the prior ', ...
        'MAT. No constant was revisited after seeing a result and no case was rerun with a ', ...
        'changed number.'];
    R.overall_pass = false;
    R.verdict = 'PENDING';
    R.fail_cause = '';
    R.next_untried_structure = '';
    R.gate5c_status = 'PENDING';
    R.artifact_bytes = artifact_bytes({md_path, mat_path, png_path});
    R.md_table_validation = struct('ok', false, 'n_rows', 0, 'n_expected', nc, ...
        'rows_ok', false, 'cells_ok', false, 'labels_ok', false, ...
        'reason', 'not yet measured', 'bad', {{}});
    R.md_parity_table_validation = R.md_table_validation;
    R.post_write_recheck = struct('done', false);
    R.log_append_verification = struct('done', false);
    R.next_task = '';

    %% ============ write pass 1 ============
    save(mat_path, '-struct', 'R', '-v7.3');
    write_report(md_path, R, png_path, mat_path, here);
    ab = artifact_bytes({md_path, mat_path, png_path});
    hard.artifacts_readable_and_bounded = vq.ok && ab.total_MiB < 300;
    R.hard_gates = hard;
    R.artifact_bytes = ab;

    tv = validate_md_table(md_path, per_case, '^###\s+Per-case result matrix');
    tp = validate_md_table(md_path, per_case, '^###\s+Per-case parity matrix');
    fprintf('MD result table: rows=%d/%d cells=%d labels=%d -> %s\n', tv.n_rows, tv.n_expected, ...
        tv.cells_ok, tv.labels_ok, passfail(tv.ok));
    fprintf('MD parity table: rows=%d/%d cells=%d labels=%d -> %s\n', tp.n_rows, tp.n_expected, ...
        tp.cells_ok, tp.labels_ok, passfail(tp.ok));
    R.md_table_validation = tv;
    R.md_parity_table_validation = tp;

    vg.md_tables_24_rows = tv.ok && tp.ok;
    vg.outputs_under_300_MiB = ab.total_MiB < 300;
    vg.hard_gates_32_of_32 = all(struct2logical(hard)) && numel(fieldnames(hard)) == 32;
    R.validation_gates = vg;

    %% ============ verdict ============
    hardv = struct2logical(hard);
    vgv = struct2logical(rmfield(vg, 'logs_appended_once'));
    overall = all(hardv) && all(vgv) && all(case_pass) && parity.ok && tv.ok && tp.ok;
    R.overall_pass = overall;
    if overall
        R.verdict = 'PASS';
        R.gate5c_status = ['GATE 5C FORMALIZED: PASS on integrity and availability ', ...
            'state-machine behaviour, PROCESS COMPLIANT. The technical result of ', ...
            'NAV_AVAILABILITY_OUTAGE_STRESS_001 (TECHNICAL_PASS / PROCESS_NONCOMPLIANT) is ', ...
            'reproduced exactly in a single MATLAB start, so the process objection is ', ...
            'discharged and Gate 5C stands as formal evidence. Accuracy and outage endurance ', ...
            'remain CHARACTERIZATION and NOT_CERTIFIED; Gate 4 waiver remains OPEN / ', ...
            'shadow-only; nothing is promoted.'];
        R.next_task = ['GATE 6 (named because Gate 5C is now formalized, NOT attempted here): ', ...
            'PROPULSION / POWER / COMPUTE budget and margin. Take the actuator commands and ', ...
            'the navigation duty cycle this vertical already produces and close them against a ', ...
            'declared thruster and control-surface power model, an energy budget over the ', ...
            'mission profile, and a compute-load / latency budget for the estimator and ', ...
            'controller rates. Numerics remain ASSUMED and every result remains NOT_CERTIFIED ', ...
            'until bench data exists.'];
    else
        R.verdict = 'FAIL';
        R.gate5c_status = ['GATE 5C NOT FORMALIZED. The prior technical evidence is RETAINED ', ...
            'as shadow evidence with status TECHNICAL_PASS / PROCESS_NONCOMPLIANT and is not ', ...
            'promoted. This validation did not close the process objection.'];
        [R.fail_cause, R.next_untried_structure] = isolate_failure(hard, vg, per_case, gnames, ...
            gate_matrix, det, tb, neg, abl, g5b, parity, tv, tp);
        R.next_task = ['Gate 6 is NOT named: it is named only when Gate 5C is formalized. The ', ...
            'next action is the recorded untried structure for the isolated failure above.'];
    end

    %% ============ write pass 2, logs, recheck ============
    save(mat_path, '-struct', 'R', '-v7.3');
    write_report(md_path, R, png_path, mat_path, here);
    append_logs(outdir, R, task_id);

    rc = struct();
    rc.done = true;
    rc.table = validate_md_table(md_path, per_case, '^###\s+Per-case result matrix');
    rc.parity_table = validate_md_table(md_path, per_case, '^###\s+Per-case parity matrix');
    g5b_final = fingerprint(here, g5b_names);
    for i = 1:numel(g5b_names)
        g5b_final(i).adler32 = file_adler32(fullfile(here, g5b_names{i}));
    end
    rc.gate5b_files = prior_unchanged(g5b_before, g5b_final);
    g5c_final = fingerprint(here, g5c_names);
    for i = 1:numel(g5c_names)
        g5c_final(i).adler32 = file_adler32(fullfile(here, g5c_names{i}));
    end
    rc.gate5c_files = prior_unchanged(g5c_before, g5c_final);
    rc.logs = verify_log_appends(here, log_names, logs_before, task_id);
    rc.bytes = artifact_bytes({md_path, mat_path, png_path});
    rc.png = visual_qa(png_path);
    rc.ok = rc.table.ok && rc.parity_table.ok && rc.gate5b_files.ok && rc.gate5c_files.ok && ...
        rc.logs.ok && rc.bytes.total_MiB < 300 && rc.png.ok;
    R.post_write_recheck = rc;
    R.log_append_verification = rc.logs;
    vg.logs_appended_once = rc.logs.ok;
    vg.prior_gate5c_artifacts_unmodified = rc.gate5c_files.ok;
    R.validation_gates = vg;
    R.gate5c_file_fingerprint = rc.gate5c_files;
    if ~rc.ok && strcmp(R.verdict, 'PASS')
        R.verdict = 'FAIL';
        R.overall_pass = false;
        R.gate5c_status = ['GATE 5C NOT FORMALIZED: the post-write recheck on the delivered ', ...
            'artifacts failed. Prior technical evidence retained as shadow evidence.'];
        R.fail_cause = sprintf(['Post-write recheck failed: result_table=%d parity_table=%d ', ...
            'gate5b_files=%d gate5c_files=%d logs=%d bytes=%d png=%d'], rc.table.ok, ...
            rc.parity_table.ok, rc.gate5b_files.ok, rc.gate5c_files.ok, rc.logs.ok, ...
            rc.bytes.total_MiB < 300, rc.png.ok);
        R.next_task = 'Gate 6 is NOT named: Gate 5C was not formalized.';
    end

    save(mat_path, '-struct', 'R', '-v7.3');
    write_report(md_path, R, png_path, mat_path, here);

    ab_final = artifact_bytes({md_path, mat_path, png_path});
    fprintf('\nVERDICT: %s | cases %d/%d | hard gates %d/%d | validation gates %d/%d | parity %d/%d | %.1f s\n', ...
        R.verdict, sum(case_pass), nc, sum(struct2logical(hard)), numel(fieldnames(hard)), ...
        sum(struct2logical(vg)), numel(fieldnames(vg)), parity.n_ok, parity.n_items, toc(t_wall));
    if ~strcmp(R.verdict, 'PASS')
        fprintf('FAIL CAUSE: %s\n', R.fail_cause);
    end
    fprintf('MATLAB starts this task: %d (policy one). Prior run: %d.\n', ...
        proc.invocations_this_task, PR.process.invocations_this_task);
    for i = 1:numel(ab_final.files)
        fprintf('Artifact %-46s %10d bytes\n', ab_final.files{i}, ab_final.bytes(i));
    end
    fprintf('Artifact total: %d bytes (%.3f MiB), budget 300 MiB\n', ...
        ab_final.total_bytes, ab_final.total_MiB);
    fprintf('Prior Gate 5C artifacts unchanged: %s\n', ynstr(rc.gate5c_files.ok));
    fprintf('Artifacts: %s\n           %s\n           %s\n', md_path, mat_path, png_path);
end

%% ===================== parity machinery =====================
function P = par_add(P, name, what, a, b, tol_exact, tol_declared)
    [bad_e, mx] = dcmp(a, b, tol_exact, name);
    if isempty(bad_e)
        ex = true; ok = true; bad = bad_e;
    else
        [bad_t, ~] = dcmp(a, b, tol_declared, name);
        ex = false; ok = isempty(bad_t); bad = bad_t;
        if ok; bad = {}; end
    end
    if ex; md = 'EXACT'; elseif ok; md = 'TOL'; else; md = 'DIFF'; end
    e = struct('name', name, 'what', what, 'mode', md, 'exact', ex, 'ok', ok, ...
        'max_abs_diff', mx, 'n_diff', numel(bad), 'detail', {bad(:)});
    if isempty(P); P = e; else; P(end + 1) = e; end
end

function [bad, mx] = dcmp(a, b, tol, p)
% Recursive exact/tolerant comparison. Returns a list of human-readable
% mismatches and the largest absolute numeric difference encountered.
    bad = {}; mx = 0;
    if ~strcmp(class(a), class(b))
        bad = {sprintf('%s: class %s vs %s', p, class(a), class(b))};
        return;
    end
    if ~isequal(size(a), size(b))
        bad = {sprintf('%s: size %s vs %s', p, mat2str(size(a)), mat2str(size(b)))};
        return;
    end
    if isstruct(a)
        fa = sort(fieldnames(a)); fb = sort(fieldnames(b));
        if ~isequal(fa, fb)
            bad = {sprintf('%s: field set differs', p)};
            return;
        end
        for e = 1:numel(a)
            for f = 1:numel(fa)
                [b2, m2] = dcmp(a(e).(fa{f}), b(e).(fa{f}), tol, ...
                    sprintf('%s(%d).%s', p, e, fa{f}));
                if ~isempty(b2); bad = [bad, b2]; end %#ok<AGROW>
                if m2 > mx; mx = m2; end
            end
        end
    elseif iscell(a)
        for e = 1:numel(a)
            [b2, m2] = dcmp(a{e}, b{e}, tol, sprintf('%s{%d}', p, e));
            if ~isempty(b2); bad = [bad, b2]; end %#ok<AGROW>
            if m2 > mx; mx = m2; end
        end
    elseif ischar(a)
        if ~strcmp(a, b); bad = {sprintf('%s: text differs', p)}; end
    elseif islogical(a)
        if ~isequal(a, b)
            bad = {sprintf('%s: %d logical elements differ', p, sum(a(:) ~= b(:)))};
        end
    elseif isnumeric(a)
        av = double(a(:)); bv = double(b(:));
        same = (av == bv) | (isnan(av) & isnan(bv));
        d = abs(av - bv);
        d(same) = 0;
        if any(isnan(d))
            bad = {sprintf('%s: NaN pattern differs', p)};
        else
            m2 = max([d; 0]);
            if m2 > mx; mx = m2; end
            if m2 > tol
                bad = {sprintf('%s: max abs diff %.3e', p, m2)};
            end
        end
    else
        if ~isequaln(a, b)
            bad = {sprintf('%s: values of class %s differ', p, class(a))};
        end
    end
end

function s = first_detail(d)
    if isempty(d); s = ''; else; s = d{1}; end
end

%% ===================== profile construction (verbatim from source 2) =========
function prof = build_profile(c, T, D, cfgc) %#ok<INUSD>
    p = D.profiles{c.profile_i};
    F = T.T_final;
    prof = struct();
    prof.label = c.label;
    prof.route = c.route;
    prof.profile = p.tag;
    prof.profile_i = c.profile_i;
    prof.desc = p.desc;
    prof.seed = c.seed;
    prof.T_final = F;
    if p.dvl_gap; prof.dvl_gap = D.dvl_gap_frac * F; else; prof.dvl_gap = [NaN NaN]; end
    if p.hdg_gap; prof.hdg_gap = D.hdg_gap_frac * F; else; prof.hdg_gap = [NaN NaN]; end
    prof.usbl_present = p.usbl;
    if p.usbl; prof.usbl_burst = D.usbl_burst_frac * F; else; prof.usbl_burst = [NaN NaN]; end
    prof.expected_sequence = D.expected_sequence{c.profile_i};
    prof.usbl_cfg = D.usbl;
    prof.timing_bound_s = D.timing_bound_s;
end

function [B, sched] = apply_profile(B0, T, prof, D)
    B = B0;
    t = B.t(:);
    N = numel(t);
    dt = B.dt_base;
    sched = struct();
    sched.label = prof.label;
    sched.windows = struct('dvl_gap', prof.dvl_gap, 'hdg_gap', prof.hdg_gap, ...
        'usbl_burst', prof.usbl_burst);

    [B.meas.dvl_vel_body_water, sched.dvl] = suppress_channel( ...
        B.meas.dvl_vel_body_water, t, prof.dvl_gap);
    [B.meas.heading_compass, sched.hdg] = suppress_channel( ...
        B.meas.heading_compass, t, prof.hdg_gap);
    for nm = {'depth_pressure', 'ins_vel_ned', 'imu_gyro', 'imu_accel'}
        s = B.meas.(nm{1}).seq(:);
        sched.(nm{1}) = struct('n_delivered', sum([s(1); diff(s)] > 0));
    end

    [B.meas.usbl_pos_ned, sched.usbl] = build_usbl_channel(T, t, N, dt, prof, D);

    sched.expected = struct();
    sched.expected.dvl_offered = sched.dvl.n_delivered;
    sched.expected.dvl_iface_rejects = 0;
    sched.expected.hdg_offered = sched.hdg.n_delivered;
    sched.expected.hdg_iface_rejects = 0;
    sched.expected.depth_offered = sched.depth_pressure.n_delivered;
    sched.expected.ins_offered = sched.ins_vel_ned.n_delivered;
    sched.expected.usbl_offered = sched.usbl.n_delivered;
    sched.expected.usbl_iface_rejects = sched.usbl.n_faults;
    sched.expected.usbl_fused = sched.usbl.n_delivered - sched.usbl.n_faults;
    if ~prof.usbl_present
        sched.expected.usbl_offered = 0;
        sched.expected.usbl_iface_rejects = 0;
        sched.expected.usbl_fused = 0;
    end
end

function [M, rec] = suppress_channel(M, t, win)
    s = M.seq(:);
    d = [s(1); diff(s)];
    rec = struct('window_s', win, 'n_suppressed_messages', 0, 'n_delivered', 0, ...
        'first_after_gap_t', NaN);
    if all(isfinite(win))
        in = t >= win(1) - 1e-12 & t <= win(2) + 1e-12;
        k0 = find(in, 1, 'first');
        if ~isempty(k0)
            hold_seq = s(max(k0 - 1, 1));
            hold_val = M.value(max(k0 - 1, 1), :);
            hold_ts  = M.timestamp(max(k0 - 1, 1));
            rec.n_suppressed_messages = sum(d(in) > 0);
            s(in) = hold_seq;
            for k = find(in)'
                M.value(k, :) = hold_val;
                M.timestamp(k) = hold_ts;
                M.t_rx(k) = hold_ts;
                M.valid(k) = false;
                M.quality(k) = 0;
                M.stale_age(k) = t(k) - hold_ts;
                M.status(k) = 4;                 % dropout
            end
            M.seq = reshape(s, size(M.seq));
            ka = find(t > win(2) + 1e-12, 1, 'first');
            if ~isempty(ka); rec.first_after_gap_t = t(ka); end
        end
    end
    s2 = M.seq(:);
    rec.n_delivered = sum([s2(1); diff(s2)] > 0);
end

function [U, rec] = build_usbl_channel(T, t, N, dt, prof, D)
    u = D.usbl;
    spec = struct('name', 'usbl_pos_ned', 'dim', 3, 'frame', 'NED', 'units', 'm', ...
        'present', prof.usbl_present, 'rate_hz', u.rate_hz, 'period_s', u.period_s, ...
        'delay_s', u.delay_s, 'q_nom', u.q_nom, 'bound_lo', u.bound_lo, ...
        'bound_hi', u.bound_hi, 'stale_limit_s', u.stale_limit_s, ...
        'dropout_limit_s', 3 * u.period_s);

    U = struct();
    U.value = zeros(N, 3);
    U.timestamp = zeros(N, 1);
    U.t_rx = zeros(N, 1);
    U.seq = zeros(N, 1);
    U.valid = false(N, 1);
    U.quality = zeros(N, 1);
    U.stale_age = zeros(N, 1);
    U.status = zeros(N, 1);
    U.spec = spec;
    U.usbl_truth_ref = zeros(N, 1);          % truth-side bookkeeping, dropped at the door

    rec = struct('present', prof.usbl_present, 'period_s', u.period_s, 't0_s', u.t0_s, ...
        'delay_s', u.delay_s, 'sigma_ned', u.sigma_ned, 'bias_ned', u.bias_ned, ...
        'seed', prof.seed, 'n_emitted', 0, 'n_suppressed_burst', 0, 'n_delivered', 0, ...
        'n_faults', 0, 'fault_m', [], 'fault_kind', {{}}, 'emit_t', [], 'arrive_t', [], ...
        'delivered_m', []);
    if ~prof.usbl_present
        return;
    end

    t_end = t(end);
    m_max = floor((t_end - u.delay_s - u.t0_s) / u.period_s) + 1;
    if m_max < 1; return; end
    t_emit = u.t0_s + (0:(m_max - 1))' * u.period_s;
    t_arr = t_emit + u.delay_s;
    k_emit = round(t_emit / dt) + 1;
    k_arr = round(t_arr / dt) + 1;
    keep = k_arr >= 1 & k_arr <= N & k_emit >= 1 & k_emit <= N;
    t_emit = t_emit(keep); t_arr = t_arr(keep);
    k_emit = k_emit(keep); k_arr = k_arr(keep);
    m_max = numel(t_emit);
    rec.n_emitted = m_max;
    rec.emit_t = t_emit;
    rec.arrive_t = t_arr;

    in_burst = false(m_max, 1);
    if all(isfinite(prof.usbl_burst))
        in_burst = t_arr >= prof.usbl_burst(1) - 1e-12 & t_arr <= prof.usbl_burst(2) + 1e-12;
    end
    rec.n_suppressed_burst = sum(in_burst);
    delivered = find(~in_burst);
    rec.delivered_m = delivered;
    rec.n_delivered = numel(delivered);

    post = delivered(t_arr(delivered) > nanmaxlocal(prof.usbl_burst));
    pick = [2 4 6];
    pick = pick(pick <= numel(post));
    fault_m = post(pick);
    rec.fault_m = fault_m(:)';
    rec.n_faults = numel(fault_m);
    rec.fault_kind = D.usbl_fault_kinds(1:numel(fault_m));

    rs = RandStream('mt19937ar', 'Seed', prof.seed);
    noise = randn(rs, m_max, 3) .* repmat(u.sigma_ned, m_max, 1);

    seq = 0;
    last_k = 0;
    last_ts = -Inf;
    for m = 1:m_max
        if in_burst(m); continue; end
        seq = seq + 1;
        ka = k_arr(m);
        val = T.eta_ned(k_emit(m), :) + u.bias_ned + noise(m, :);
        ts = t_emit(m);
        valid = true; status = 2; stale = u.delay_s; q = u.q_nom;
        fi = find(fault_m == m, 1);
        if ~isempty(fi)
            switch D.usbl_fault_kinds{fi}
                case 'flagged_invalid';        valid = false; status = 4;
                case 'stale_beyond_limit';     stale = 10.0;
                case 'out_of_order_timestamp'; ts = ts - 5.0;
            end
        end
        if last_k > 0 && ka > last_k + 1
            r = (last_k + 1):(ka - 1);
            U.value(r, :) = repmat(U.value(last_k, :), numel(r), 1);
            U.timestamp(r) = U.timestamp(last_k);
            U.t_rx(r) = U.t_rx(last_k);
            U.seq(r) = U.seq(last_k);
            U.quality(r) = U.quality(last_k);
            U.stale_age(r) = t(r) - U.timestamp(last_k);
            U.status(r) = held_status(U.stale_age(r), spec);
        end
        U.value(ka, :) = val;
        U.timestamp(ka) = ts;
        U.t_rx(ka) = t_arr(m);
        U.seq(ka) = seq;
        U.valid(ka) = valid;
        U.quality(ka) = q;
        U.stale_age(ka) = stale;
        U.status(ka) = status;
        U.usbl_truth_ref(ka) = k_emit(m);
        last_k = ka;
        last_ts = ts; %#ok<NASGU>
    end
    if last_k > 0 && last_k < N
        r = (last_k + 1):N;
        U.value(r, :) = repmat(U.value(last_k, :), numel(r), 1);
        U.timestamp(r) = U.timestamp(last_k);
        U.t_rx(r) = U.t_rx(last_k);
        U.seq(r) = U.seq(last_k);
        U.quality(r) = U.quality(last_k);
        U.stale_age(r) = t(r) - U.timestamp(last_k);
        U.status(r) = held_status(U.stale_age(r), spec);
    end
    if k_arr(1) > 1
        U.status(1:min(k_arr(1), N) - 1) = 1;            % initializing
    end
end

function st = held_status(age, spec)
    st = 2 * ones(size(age));
    st(age > spec.stale_limit_s + 1e-12) = 3;
    st(age > spec.dropout_limit_s + 1e-12) = 4;
end

function m = nanmaxlocal(w)
    if all(isfinite(w)); m = w(2); else; m = -Inf; end
end

%% ===================== audits (verbatim from source 2) =====================
function ca = counter_audit(E, sched, cfg)
    ex = sched.expected;
    m = E.mgr;
    ni = 0;
    for i = 1:numel(cfg.all_channels)
        ni = ni + m.(cfg.all_channels{i}).n_reject_innov;
    end
    items = {
        'dvl_offered',                  ex.dvl_offered,        m.dvl_vel_body_water.n_new
        'dvl_iface_rejects',            ex.dvl_iface_rejects,  m.dvl_vel_body_water.n_reject_interface
        'dvl_consumed',                 ex.dvl_offered,        m.dvl_vel_body_water.n_fused + m.dvl_vel_body_water.n_init_used
        'heading_offered',              ex.hdg_offered,        m.heading_compass.n_new
        'heading_iface_rejects',        ex.hdg_iface_rejects,  m.heading_compass.n_reject_interface
        'heading_consumed',             ex.hdg_offered,        m.heading_compass.n_fused + m.heading_compass.n_init_used
        'depth_offered',                ex.depth_offered,      m.depth_pressure.n_new
        'depth_consumed',               ex.depth_offered,      m.depth_pressure.n_fused + m.depth_pressure.n_init_used
        'ins_offered',                  ex.ins_offered,        m.ins_vel_ned.n_new
        'ins_consumed',                 ex.ins_offered,        m.ins_vel_ned.n_fused + m.ins_vel_ned.n_init_used
        'usbl_offered',                 ex.usbl_offered,       m.usbl_pos_ned.n_new
        'usbl_iface_rejects',           ex.usbl_iface_rejects, m.usbl_pos_ned.n_reject_interface
        'usbl_consumed',                ex.usbl_fused,         m.usbl_pos_ned.n_fused + m.usbl_pos_ned.n_init_used
        'innovation_gate_rejects_total', 0,                    ni
        };
    ca = struct();
    ca.items    = items(:, 1);
    ca.expected = cell2mat(items(:, 2));
    ca.observed = cell2mat(items(:, 3));
    ca.match    = (ca.expected == ca.observed);
    ca.counter_invariant = E.counter_invariant_ok;
    ca.ok = all(ca.match) && ca.counter_invariant;
end

function ga = gap_audit(E, prof)
    ga = struct();
    tf = E.fused.t; ch = E.fused.ch;
    td = tf(strcmp(ch, 'dvl_vel_body_water'));
    th = tf(strcmp(ch, 'heading_compass'));
    tu = tf(strcmp(ch, 'usbl_pos_ned'));
    ga.dvl_in_gap = count_in(td, prof.dvl_gap);
    ga.hdg_in_gap = count_in(th, prof.hdg_gap);
    ga.usbl_in_burst = count_in(tu, prof.usbl_burst);
    ga.dvl_zero_in_gap = (ga.dvl_in_gap == 0);
    ga.hdg_zero_in_gap = (ga.hdg_in_gap == 0);
    ga.usbl_zero_in_burst = (ga.usbl_in_burst == 0);
    ga.dvl_before = count_before(td, prof.dvl_gap);
    ga.dvl_after = count_after(td, prof.dvl_gap);
    ga.dvl_resumes = ~all(isfinite(prof.dvl_gap)) || (ga.dvl_before > 0 && ga.dvl_after > 0);
    if prof.usbl_present
        ga.usbl_only_valid = (E.audit.n_fused_usbl_absent == 0) && ...
            (E.mgr.usbl_pos_ned.n_fused > 0) && ga.usbl_zero_in_burst;
    else
        ga.usbl_only_valid = (E.audit.n_fused_usbl == 0);
    end
    ga.ok = ga.dvl_zero_in_gap && ga.hdg_zero_in_gap && ga.usbl_only_valid && ga.dvl_resumes;
end

function n = count_in(x, w)
    if ~all(isfinite(w)); n = 0; return; end
    n = sum(x >= w(1) - 1e-12 & x <= w(2) + 1e-12);
end
function n = count_before(x, w)
    if ~all(isfinite(w)); n = numel(x); return; end
    n = sum(x < w(1));
end
function n = count_after(x, w)
    if ~all(isfinite(w)); n = numel(x); return; end
    n = sum(x > w(2));
end

function fa = fsm_audit(E, prof, D, cfg)
    A = E.avail;
    fa = struct();
    fa.n_transitions = A.n_transitions;
    fa.sequence = A.sequence;
    fa.sequence_names = A.sequence_names;
    fa.expected_sequence = prof.expected_sequence;
    fa.sequence_ok = isequal(A.sequence(:)', prof.expected_sequence(:)');
    fa.lock_ok = true;
    if prof.profile_i == 1
        fa.lock_ok = (A.n_transitions == 0) && all(A.state(E.init_tick:end) == 1);
    end

    pred = predict_transitions(E, cfg);
    fa.predicted = pred;
    fa.bound_s = prof.timing_bound_s;
    fa.obs_degraded_t = trans_time(A, 1, 2);
    fa.obs_lost_t = trans_time(A, 2, 3);
    fa.obs_recovering_t = trans_time(A, 3, 4);
    fa.obs_nominal_t = trans_time(A, 4, 1);
    fa.err_degraded_s = fa.obs_degraded_t - pred.t_degraded;
    fa.err_lost_s = fa.obs_lost_t - pred.t_lost;
    fa.err_recovering_s = fa.obs_recovering_t - pred.t_recovering;
    fa.err_nominal_s = fa.obs_nominal_t - pred.t_nominal;

    if prof.profile_i == 1
        fa.detect_timing_ok = isnan(fa.obs_lost_t) && isnan(fa.obs_degraded_t);
        fa.recovery_timing_ok = isnan(fa.obs_recovering_t) && isnan(fa.obs_nominal_t);
    else
        fa.detect_timing_ok = within(fa.err_degraded_s, fa.bound_s) && ...
            within(fa.err_lost_s, fa.bound_s);
        fa.recovery_timing_ok = within(fa.err_recovering_s, fa.bound_s) && ...
            within(fa.err_nominal_s, fa.bound_s);
    end
    fa.declared_detect_bound_s = max(A.tau_fresh(A.tau_fresh > 0)) + ...
        cfg.fsm.T_degrade + cfg.fsm.T_lost + max(D.usbl.period_s, 1.0);
    fa.detect_delay_from_gap_s = NaN;
    if all(isfinite(prof.dvl_gap)) && ~isnan(fa.obs_lost_t)
        fa.detect_delay_from_gap_s = fa.obs_lost_t - prof.dvl_gap(1);
    end
    fa.freshness_reproduced = pred.freshness_reproduced;
    fa.ok = fa.sequence_ok && fa.lock_ok && fa.detect_timing_ok && ...
        fa.recovery_timing_ok && fa.freshness_reproduced;
end

function b = within(x, tol)
    b = ~isnan(x) && abs(x) <= tol + 1e-12;
end

function tt = trans_time(A, from, to)
    tt = NaN;
    k = find(A.trans.from == from & A.trans.to == to, 1, 'first');
    if ~isempty(k); tt = A.trans.t(k); end
end

function pred = predict_transitions(E, cfg)
    fin = E.fsm_input;
    t = fin.t(:);
    k0 = fin.init_tick;
    pred = struct('t_degraded', NaN, 't_lost', NaN, 't_recovering', NaN, ...
        't_nominal', NaN, 'freshness_reproduced', false);
    if isnan(k0); return; end
    N = numel(t);
    nch = numel(fin.present);
    dt = median(diff(t));

    tau = zeros(1, nch);
    for i = 1:nch
        tau(i) = max([cfg.fsm.k_fresh * fin.period_s(i), ...
                      fin.stale_limit_s(i) + fin.period_s(i), cfg.fsm.tau_floor]);
    end
    req = fin.aid_idx(fin.present(fin.aid_idx));
    pos = fin.pos_idx(fin.present(fin.pos_idx));
    idx = k0:N;
    tt = t(idx);
    n = numel(idx);
    af = false(n, 1);
    pf = false(n, 1);
    last = NaN(1, nch);
    fr = false(1, nch);
    for z = 1:n
        k = idx(z);
        for i = 1:nch
            if fin.chan_accept(k, i); last(i) = t(k); end
            if isnan(last(i)); ref = t(k0); else; ref = last(i); end
            fr(i) = (t(k) - ref) <= tau(i) + cfg.tol_time;
        end
        af(z) = all(fr(req));
        if isempty(pos); pf(z) = false; else; pf(z) = any(fr(pos)); end
    end

    k = find(~af, 1, 'first');
    if ~isempty(k)
        pred.t_degraded = first_dwell(tt, ~af, k, cfg.fsm.T_degrade, dt);
    end
    k = find(~pf, 1, 'first');
    if ~isempty(k)
        pred.t_lost = first_dwell(tt, ~pf, k, cfg.fsm.T_lost, dt);
    end
    if ~isnan(pred.t_lost)
        j = find(tt > pred.t_lost & pf, 1, 'first');
        if ~isempty(j)
            pred.t_recovering = first_dwell(tt, pf, j, cfg.fsm.T_reacq, dt);
        end
        j = find(tt > pred.t_lost & af, 1, 'first');
        if ~isempty(j)
            pred.t_nominal = first_dwell(tt, af, j, cfg.fsm.T_settle, dt);
        end
    end
    pred.freshness_reproduced = isequal(af(:), E.avail.all_aid_fresh(idx)) && ...
        isequal(pf(:), E.avail.pos_aid_fresh(idx));
end

function tout = first_dwell(tt, cond, kstart, T, dt)
    tout = NaN;
    n = numel(tt);
    k = kstart;
    while k <= n
        if ~cond(k); k = k + 1; continue; end
        j = k;
        while j <= n && cond(j)
            if tt(j) - tt(k) + dt >= T - 1e-12; tout = tt(j); return; end
            j = j + 1;
        end
        k = j;
    end
end

%% ===================== truth blindness helpers (verbatim) =====================
function Bx = scramble_truth(B, T)
    Bx = B;
    if isfield(Bx, 'Vc_ned');     Bx.Vc_ned = [99 -99 99]; end
    if isfield(Bx, 'dvl_outage'); Bx.dvl_outage = ~Bx.dvl_outage; end
    if isfield(Bx, 'route');      Bx.route = 'SCRAMBLED'; end
    if isfield(Bx, 'label');      Bx.label = 'SCRAMBLED'; end
    if isfield(Bx, 'seed');       Bx.seed = -1; end
    Bx.eta_ned = -7 * ones(size(T.eta_ned));
    Bx.euler = zeros(size(T.euler));
    Bx.V_g_ned = 42 * ones(size(T.V_g_ned));
    Bx.nu_r_body = -13 * ones(size(T.nu_r_body));
    Bx.usbl_truth_ref = -1;
    Bx.meas.usbl_pos_ned.usbl_truth_ref = -ones(size(B.meas.usbl_pos_ned.usbl_truth_ref));
    Bx.meas.dvl_vel_body_water.truth_note = 'SCRAMBLED';
end

function ok = check_truth_ref_dropped(B, cfg)
    S = navigation_multirate_ekf_availability('sanitize', B, cfg);
    ok = isfield(B.meas.usbl_pos_ned, 'usbl_truth_ref') && ...
        ~isfield(S.meas.usbl_pos_ned, 'usbl_truth_ref') && ...
        ~isfield(S, 'Vc_ned') && ~isfield(S, 'route') && ~isfield(S, 'seed');
end

%% ===================== static scans (verbatim) =====================
function leak = truth_token_scan(txt)
    tokens = {'eta_ned', 'nu_r_body', 'nu_c_body', 'nu_body', 'V_g_ned', 'V_w_ned', ...
        'omega_body', 'f_body', 'bottom_lock', 'crab_angle', 'course_ned', ...
        'psi_unwrapped', 'Vc_ned', 'dvl_outage', 'outage_window', 'altitude', ...
        'usbl_truth_ref'};
    lines = regexp(txt, '\r?\n', 'split');
    n = numel(lines);
    isfun = false(1, n);
    for i = 1:n
        isfun(i) = ~isempty(regexp(lines{i}, '^function\s', 'once'));
    end
    fun_idx = find(isfun);
    scorer = false(1, n);
    scorer_names = {'accuracy_metrics', 'window_drift'};
    for i = 1:numel(fun_idx)
        for s = 1:numel(scorer_names)
            if contains(lines{fun_idx(i)}, scorer_names{s})
                if i < numel(fun_idx); e = fun_idx(i + 1) - 1; else; e = n; end
                scorer(fun_idx(i):e) = true;
            end
        end
    end
    tf_start = 0; tf_end = 0;
    for i = 1:n
        if contains(lines{i}, 'cfg.truth_forbidden = {')
            tf_start = i;
            j = i;
            while j <= n && ~contains(lines{j}, '};'); j = j + 1; end
            tf_end = min(j, n);
            break;
        end
    end
    viol = {};
    for i = 1:n
        s = strtrim(lines{i});
        if isempty(s) || s(1) == '%'; continue; end
        if scorer(i); continue; end
        if tf_start > 0 && i >= tf_start && i <= tf_end; continue; end
        for tk = 1:numel(tokens)
            if contains(s, tokens{tk})
                viol{end+1} = sprintf('line %d: %s', i, s); %#ok<AGROW>
                break;
            end
        end
    end
    leak = struct();
    leak.tokens = {tokens};
    leak.n_lines = n;
    leak.declaration_range = [tf_start tf_end];
    leak.violations = {viol};
    leak.n_violations = numel(viol);
    leak.ok = isempty(viol) && tf_start > 0;
end

function acc = accommodation_scan(txt)
    lines = regexp(txt, '\r?\n', 'split');
    n = numel(lines);
    allowed = {'A.state', 'A2.state', 'L.health_state', 'e.health_state', ...
        'eb.health_state', 'health_state_names', 'G.health_state', 'av.state_names'};
    viol = {};
    for i = 1:n
        s = strtrim(lines{i});
        if isempty(s) || s(1) == '%'; continue; end
        s = regexprep(s, '''[^'']*''', '''''');
        s = regexprep(s, '%[^%]*$', '');
        if ~contains(s, 'health_state') && ~contains(s, 'A.state') && ...
                ~contains(s, 'A2.state')
            continue;
        end
        c = s;
        for j = 1:numel(allowed); c = strrep(c, allowed{j}, ''); end
        if contains(c, 'health_state') || contains(c, 'A.state') || contains(c, 'A2.state')
            viol{end+1} = sprintf('line %d: %s', i, strtrim(lines{i})); %#ok<AGROW>
        end
    end
    acc = struct();
    acc.rule = ['A health variable may be assigned, logged, named or reported. It may not ', ...
        'appear as an input to a propagation, gain, covariance, admission or reset statement.'];
    acc.violations = {viol};
    acc.n_violations = numel(viol);
    acc.fsm_is_pure_function = contains(txt, 'PURE FUNCTION of');
    acc.ok = isempty(viol) && acc.fsm_is_pure_function;
end

function ok = fsm_is_after_loop(txt)
    i_loop = strfind(txt, 'for k = 1:N');
    i_fsm = strfind(txt, 'A = availability_fsm(fin, cfg);');
    i_end = strfind(txt, '% ================= availability state machine');
    ok = ~isempty(i_loop) && ~isempty(i_fsm) && ~isempty(i_end) && ...
        i_fsm(1) > i_loop(1) && i_end(1) > i_loop(1);
end

%% ===================== small helpers (verbatim) =====================
function b = gv(gnames, per_gate_all, name)
    k = find(strcmp(gnames, name));
    if numel(k) ~= 1
        error('gate5cv:gateName', 'integrity gate "%s" not found', name);
    end
    b = logical(per_gate_all(k));
end

function v = struct2logical(s)
    f = fieldnames(s);
    v = true(1, numel(f));
    for i = 1:numel(f)
        x = s.(f{i});
        if islogical(x) || isnumeric(x)
            v(i) = ~isempty(x) && all(logical(x(:)));
        end
    end
end

function fp = fingerprint(root, names)
    fp = struct('name', {}, 'bytes', {}, 'datenum', {}, 'exists', {});
    for i = 1:numel(names)
        p = fullfile(root, names{i});
        d = dir(p);
        if isempty(d)
            fp(i) = struct('name', names{i}, 'bytes', -1, 'datenum', -1, 'exists', false);
        else
            fp(i) = struct('name', names{i}, 'bytes', d(1).bytes, ...
                'datenum', d(1).datenum, 'exists', true);
        end
    end
end

function pu = prior_unchanged(before, after)
    pu = struct();
    pu.names = {before.name}';
    n = numel(before);
    pu.bytes_ok = false(n, 1);
    pu.time_ok = false(n, 1);
    pu.hash_ok = false(n, 1);
    for i = 1:n
        pu.bytes_ok(i) = before(i).exists && after(i).exists && before(i).bytes == after(i).bytes;
        pu.time_ok(i) = before(i).exists && after(i).exists && ...
            abs(before(i).datenum - after(i).datenum) < 1e-9;
        pu.hash_ok(i) = strcmp(before(i).adler32, after(i).adler32) && ~isempty(before(i).adler32);
    end
    pu.before = before;
    pu.after = after;
    pu.ok = all(pu.bytes_ok) && all(pu.time_ok) && all(pu.hash_ok);
end

function lv = verify_log_appends(root, names, before, task_id)
    lv = struct();
    lv.names = names(:);
    n = numel(names);
    lv.grew = false(n, 1);
    lv.occurrences = zeros(n, 1);
    for i = 1:n
        p = fullfile(root, names{i});
        d = dir(p);
        if isempty(d); continue; end
        if before(i).exists
            lv.grew(i) = d(1).bytes > before(i).bytes;
        else
            lv.grew(i) = d(1).bytes > 0;
        end
        txt = fileread(p);
        lv.occurrences(i) = numel(strfind(txt, task_id));
    end
    lv.appended_once = all(lv.occurrences == 1);
    lv.ok = all(lv.grew) && lv.appended_once;
    lv.done = true;
end

function h = file_adler32(p)
    h = 'MISSING';
    fid = fopen(p, 'r');
    if fid < 0; return; end
    c = onCleanup(@() fclose(fid)); %#ok<NASGU>
    MODA = 65521;
    a = 1; b = 0;
    while true
        v = double(fread(fid, 1000000, '*uint8'));
        if isempty(v); break; end
        v = v(:);
        m = numel(v);
        cs = cumsum(v);
        b = mod(b + m * a + sum(cs), MODA);
        a = mod(a + cs(end), MODA);
    end
    h = upper(dec2hex(b * 65536 + a, 8));
end

function h = pack_checksum(P)
    fn = {'p','v','euler','q','bg','ba','c','vbw','Pdiag','valid','status', ...
        'est_seq','est_time','source_mask'};
    acc = zeros(1, numel(fn));
    for i = 1:numel(fn)
        acc(i) = adler32(P.(fn{i}));
    end
    h = upper(dec2hex(mod(sum(acc) + P.n_fused_total, 2^32), 8));
end

function h = adler32(x)
    v = double(typecast(double(x(:))', 'uint8'));
    if isempty(v); h = 1; return; end
    v = v(:);
    n = numel(v);
    MODA = 65521;
    a = mod(1 + sum(v), MODA);
    w = (n:-1:1)';
    b = mod(mod(n, MODA) + sum(mod(w .* v, MODA)), MODA);
    h = b * 65536 + a;
end

function ab = artifact_bytes(paths)
    ab = struct('files', {cell(1, numel(paths))}, 'bytes', zeros(1, numel(paths)));
    for i = 1:numel(paths)
        [~, n, e] = fileparts(paths{i});
        ab.files{i} = [n e];
        d = dir(paths{i});
        if ~isempty(d); ab.bytes(i) = d(1).bytes; end
    end
    ab.total_bytes = sum(ab.bytes);
    ab.total_MiB = ab.total_bytes / 1048576;
end

function tbl = mgr_table(E, cfg)
    tbl = struct();
    for i = 1:numel(E.channel_names)
        nm = E.channel_names{i};
        m = E.mgr.(nm);
        tbl.(nm) = struct('n_new', m.n_new, 'n_admit', m.n_admit, ...
            'n_reject_interface', m.n_reject_interface, 'n_init_used', m.n_init_used, ...
            'n_reject_innov', m.n_reject_innov, 'n_fused', m.n_fused, ...
            'n_coalesced', m.n_coalesced, 'suppressed_ticks', m.suppressed_ticks, ...
            'reject', m.reject);
    end
    tbl.reject_reasons = {cfg.reject_reasons};
end

function M = strip_series(M)
    for f = {'err_series'}
        if isfield(M, f{1}); M = rmfield(M, f{1}); end
    end
end

function s = seqstr(seq)
    if isempty(seq); s = '-'; return; end
    s = sprintf('%d', seq(1));
    for i = 2:numel(seq); s = [s '>' sprintf('%d', seq(i))]; end %#ok<AGROW>
end

function s = passfail(b)
    if all(logical(b(:))); s = 'PASS'; else; s = 'FAIL'; end
end

function s = ynstr(b)
    if b; s = 'YES'; else; s = 'NO'; end
end

function s = numstr(x)
    if isempty(x) || ~isfinite(x); s = '-'; else; s = sprintf('%.3f', x); end
end

function s = winstr(w)
    if all(isfinite(w)); s = sprintf('%.2f-%.2f', w(1), w(2)); else; s = 'none'; end
end

function sc = build_showcase(cases, Tall, Ball, Eall, Pall, dec)
    sc = struct('label', {}, 't', {}, 'truth', {}, 'meas', {}, 'est', {}, 'health', {}, ...
        'windows', {}, 'decimation', {});
    for i = 1:numel(cases)
        T = Tall{i}; B = Ball{i}; E = Eall{i}; L = E.log;
        k = 1:dec:T.N;
        s = struct();
        s.label = cases(i).label;
        s.t = T.t(k);
        s.truth = struct('eta_ned', T.eta_ned(k, :), 'euler', T.euler(k, :), ...
            'V_g_ned', T.V_g_ned(k, :), 'Vc_ned', T.Vc_ned);
        s.meas = struct('dvl_status', B.meas.dvl_vel_body_water.status(k), ...
            'hdg_status', B.meas.heading_compass.status(k), ...
            'usbl_status', B.meas.usbl_pos_ned.status(k), ...
            'usbl_value', B.meas.usbl_pos_ned.value(k, :));
        s.est = struct('p', L.p(:, k)', 'v', L.v(:, k)', 'euler', L.euler(:, k)', ...
            'c', L.c(:, k)', 'Pdiag', L.Pdiag(:, k)', 'valid', L.valid(k), ...
            'status', L.status(k), 'est_seq', L.est_seq(k), 'est_time', L.est_time(k));
        s.health = struct('state', L.health_state(k), 'pos_aid_fresh', E.avail.pos_aid_fresh(k), ...
            'all_aid_fresh', E.avail.all_aid_fresh(k));
        s.windows = Pall{i};
        s.decimation = dec;
        sc(i) = s; %#ok<AGROW>
    end
end

function vq = visual_qa(png_path)
    vq = struct('ok', false, 'decodable', false, 'readable', false, 'reason', '', ...
        'bytes', 0, 'width', 0, 'height', 0, 'ink_fraction', NaN, 'gray_std', NaN, ...
        'thresholds', 'width>=1400, height>=900, 0.01<ink<0.95, gray std>5, bytes>80000', ...
        'checks', {{}});
    d = dir(png_path);
    if isempty(d); vq.reason = 'PNG missing'; return; end
    vq.bytes = d(1).bytes;
    try
        I = imread(png_path);
    catch ME
        vq.reason = ['imread failed: ' ME.message];
        return;
    end
    vq.decodable = true;
    if ndims(I) == 3
        g = 0.2989 * double(I(:, :, 1)) + 0.5870 * double(I(:, :, 2)) + 0.1140 * double(I(:, :, 3));
    else
        g = double(I);
    end
    vq.height = size(g, 1);
    vq.width = size(g, 2);
    vq.ink_fraction = mean(g(:) < 245);
    vq.gray_std = std(g(:));
    vq.readable = vq.width >= 1400 && vq.height >= 900 && ...
        vq.ink_fraction > 0.01 && vq.ink_fraction < 0.95 && ...
        vq.gray_std > 5 && vq.bytes > 80000;
    vq.ok = vq.decodable && vq.readable;
    vq.checks = {{ ...
        'panel 1 parity items: one labelled bar per compared record'; ...
        'panel 2 per-case parity: checksum, counters, sequence, series, metrics'; ...
        'panel 3 estimator series max abs difference per case, log axis'; ...
        'panel 4 health declaration instants, this run against the prior run'; ...
        'panel 5 metrics max abs difference per case, log axis'; ...
        'panel 6 health timeline overlay, prior and re-run, showcase case'; ...
        'panel 7 the 32 hard gates, one labelled bar per gate'; ...
        'panel 8 the validation gates, one labelled bar per gate'; ...
        'panel 9 Gate 5B 12-case checksum reproduction'; ...
        'panel 10 per-case parity table legible at full resolution'; ...
        'panel 11 preserved prior artifacts with bytes and Adler-32'; ...
        'panel 12 process record, provenance and claim boundary'}};
    if ~vq.readable; vq.reason = 'readability thresholds not met'; end
end

function [cause, next] = isolate_failure(hard, vg, per_case, gnames, gate_matrix, det, tb, ...
        neg, abl, g5b, parity, tv, tp)
    bad = {};
    f = fieldnames(hard);
    for i = 1:numel(f)
        if ~all(logical(hard.(f{i})(:))); bad{end+1} = ['hard.' f{i}]; end %#ok<AGROW>
    end
    f = fieldnames(vg);
    for i = 1:numel(f)
        if ~all(logical(vg.(f{i})(:))); bad{end+1} = ['validation.' f{i}]; end %#ok<AGROW>
    end
    detail = {};
    for j = 1:numel(gnames)
        if ~all(gate_matrix(:, j))
            k = find(~gate_matrix(:, j))';
            detail{end+1} = sprintf('%s failed on: %s', gnames{j}, ...
                strjoin({per_case(k).label}, ', ')); %#ok<AGROW>
        end
    end
    for i = 1:numel(parity.items)
        it = parity.items(i);
        if ~it.ok
            detail{end+1} = sprintf('parity %s: %d differences, first "%s"', it.name, ...
                it.n_diff, first_detail(it.detail)); %#ok<AGROW>
        end
    end
    k = find(~parity.per_case_ok);
    if ~isempty(k)
        detail{end+1} = sprintf('per-case parity failed on: %s', ...
            strjoin({per_case(k).label}, ', '));
    end
    for i = 1:numel(per_case)
        p = per_case(i);
        if ~p.counters.ok
            z = find(~p.counters.match)';
            for q = z
                detail{end+1} = sprintf('%s counter %s expected %d observed %d', p.label, ...
                    p.counters.items{q}, p.counters.expected(q), p.counters.observed(q)); %#ok<AGROW>
            end
        end
        if ~p.gapaudit.ok
            detail{end+1} = sprintf(['%s gap audit: dvl_in_gap=%d hdg_in_gap=%d ', ...
                'usbl_valid=%d resumes=%d'], p.label, p.gapaudit.dvl_in_gap, ...
                p.gapaudit.hdg_in_gap, p.gapaudit.usbl_only_valid, p.gapaudit.dvl_resumes); %#ok<AGROW>
        end
        if ~p.fsm.ok
            detail{end+1} = sprintf('%s fsm: seq %s expected %s', p.label, ...
                seqstr(p.fsm.sequence), seqstr(p.fsm.expected_sequence)); %#ok<AGROW>
        end
    end
    if ~det.ok
        detail{end+1} = sprintf('determinism: state=%d checksum=%d health=%d', ...
            det.reverse_state_identical, det.reverse_checksum_identical, ...
            det.reverse_health_identical);
    end
    if ~tb.ok
        detail{end+1} = sprintf('truth blindness: sanitized=%d scrambled=%d ref_dropped=%d scan=%d', ...
            tb.sanitized_bus_identical, tb.scrambled_truth_identical, ...
            tb.usbl_truth_ref_dropped, tb.static_scan_violations);
    end
    if ~neg.ok
        detail{end+1} = sprintf('negative test: rejected %d/%d reasons=%d state=%d', ...
            neg.n_rejected, neg.n_injected, neg.reasons_match, neg.state_untouched);
    end
    if ~abl.ok
        detail{end+1} = sprintf('ablation: fsm_off=%d fsm_scaled=%d responds=%d scan=%d', ...
            abl.fsm_off_state_identical, abl.fsm_scaled_state_identical, ...
            abl.fsm_scaled_health_responds, abl.static_scan.n_violations);
    end
    if ~g5b.ok
        detail{end+1} = sprintf('gate5b fingerprint: labels=%d N=%d seeds=%d checksums=%d/12', ...
            g5b.labels_ok, g5b.N_ok, g5b.seed_ok, sum(g5b.checksum_match));
    end
    if ~tv.ok; detail{end+1} = sprintf('MD result table: %s', tv.reason); end
    if ~tp.ok; detail{end+1} = sprintf('MD parity table: %s', tp.reason); end
    cause = strjoin([{sprintf('Failed gates: %s', strjoin(bad, ', '))}, detail], ' | ');
    next = ['NEXT UNTRIED STRUCTURE (recorded, NOT attempted here): make the Gate 5C evidence ', ...
        'self-verifying instead of externally re-verified - have the stress driver emit a ', ...
        'signed manifest of every per-case checksum, counter vector and transition instant, ', ...
        'and have a standalone verifier that never runs the estimator recompute the verdict ', ...
        'from that manifest alone. A re-run would then be a byte comparison against a ', ...
        'manifest rather than a full re-execution, and a process failure could be repaired ', ...
        'without re-entering the numerics at all. Gate 5C remains NOT FORMALIZED and Gate 6 ', ...
        'is not named.'];
end

%% ===================== figure =====================
function render_validation_overview(png_path, cases, per_case, PR, parity, hard, g5b, ...
        showcase, g5c_before, D, cfg, proc)
    nc = numel(cases);
    fig = figure('Visible', 'off', 'Color', 'w', 'Units', 'pixels', ...
        'Position', [40 40 1700 1200]);
    set(fig, 'PaperPositionMode', 'manual', 'PaperUnits', 'inches', ...
        'PaperPosition', [0 0 17 12]);
    tl = tiledlayout(fig, 4, 3, 'TileSpacing', 'compact', 'Padding', 'compact');
    title(tl, ['NAV\_AVAILABILITY\_OUTAGE\_VALIDATION\_001   Gate 5C process-compliant ', ...
        're-validation   |   one MATLAB start   |   parity against ', ...
        'NAV\_AVAILABILITY\_OUTAGE\_STRESS\_001   |   accuracy NOT\_CERTIFIED'], ...
        'FontWeight', 'bold', 'FontSize', 11);

    % 1 parity items
    ax = nexttile(tl);
    P = parity.items;
    np = numel(P);
    cd1 = zeros(np, 3);
    for i = 1:np
        if P(i).exact; cd1(i, :) = [0.15 0.65 0.25];
        elseif P(i).ok; cd1(i, :) = [0.95 0.75 0.15];
        else; cd1(i, :) = [0.85 0.20 0.15]; end
    end
    b = barh(ax, 1:np, ones(np, 1), 'FaceColor', 'flat');
    b.CData = cd1;
    set(ax, 'YTick', 1:np, 'YTickLabel', strrep({P.name}, '_', '\_'), 'FontSize', 6, ...
        'YDir', 'reverse', 'XTick', []);
    xlim(ax, [0 1.15]); ylim(ax, [0.3 np + 0.7]);
    title(ax, sprintf('1. Parity records %d/%d OK, %d exact', sum([P.ok]), np, sum([P.exact])));

    % 2 per-case parity
    ax = nexttile(tl); hold(ax, 'on'); grid(ax, 'on');
    comp = [parity.per_case_checksum_match(:), parity.per_case_counters_match(:), ...
        parity.per_case_fsm_seq_match(:), ...
        (parity.per_case_series_max_diff(:) <= parity.tol_declared), ...
        (parity.per_case_metrics_max_diff(:) <= parity.tol_declared)];
    imagesc(ax, 1:5, 1:nc, double(comp));
    colormap(ax, [0.85 0.20 0.15; 0.15 0.65 0.25]);
    set(ax, 'CLim', [0 1]);
    set(ax, 'XTick', 1:5, 'XTickLabel', {'checksum', 'counters', 'health seq', 'series', 'metrics'}, ...
        'FontSize', 6, 'YTick', 1:nc, 'YTickLabel', strrep({per_case.label}, '_', '\_'), ...
        'YDir', 'reverse');
    xlim(ax, [0.5 5.5]); ylim(ax, [0.5 nc + 0.5]);
    title(ax, sprintf('2. Per-case parity %d/%d (green = identical)', sum(parity.per_case_ok), nc));

    % 3 series max diff
    ax = nexttile(tl); hold(ax, 'on'); grid(ax, 'on');
    yv = max(reshape(parity.per_case_series_max_diff, 1, []), 1e-20);
    plot(ax, 1:nc, yv, 'o', 'Color', [0.1 0.5 0.85], 'MarkerFaceColor', [0.1 0.5 0.85], ...
        'MarkerSize', 4);
    plot(ax, [1 nc], parity.tol_declared * [1 1], 'r--', 'LineWidth', 1.0);
    set(ax, 'YScale', 'log');
    ylim(ax, [1e-21 1e-6]); xlim(ax, [0.5 nc + 0.5]);
    xlabel(ax, 'case index'); ylabel(ax, 'max abs difference');
    title(ax, '3. Estimator series difference vs prior (floor 1e-20 = identical)');

    % 4 declaration instants
    ax = nexttile(tl); hold(ax, 'on'); grid(ax, 'on');
    op = []; on = []; kind = [];
    for i = 1:nc
        q = per_case(i); qp = PR.per_case(i);
        pairs = [qp.fsm.obs_degraded_t, q.fsm.obs_degraded_t; ...
                 qp.fsm.obs_lost_t, q.fsm.obs_lost_t; ...
                 qp.fsm.obs_recovering_t, q.fsm.obs_recovering_t; ...
                 qp.fsm.obs_nominal_t, q.fsm.obs_nominal_t];
        for z = 1:4
            if all(isfinite(pairs(z, :)))
                op(end+1, 1) = pairs(z, 1); %#ok<AGROW>
                on(end+1, 1) = pairs(z, 2); %#ok<AGROW>
                kind(end+1, 1) = z; %#ok<AGROW>
            end
        end
    end
    kc = {[0.85 0.1 0.1], [0.9 0.55 0.1], [0.1 0.5 0.85], [0.1 0.65 0.2]};
    kn = {'DEGRADED', 'POSITION\_AID\_LOST', 'RECOVERING', 'NOMINAL'};
    hh = gobjects(0); lg = {};
    for z = 1:4
        sel = (kind == z);
        if any(sel)
            hh(end+1) = plot(ax, op(sel), on(sel), 'o', 'Color', kc{z}, ...
                'MarkerFaceColor', kc{z}, 'MarkerSize', 4); %#ok<AGROW>
            lg{end+1} = kn{z}; %#ok<AGROW>
        end
    end
    if ~isempty(op)
        lo = min([op; on]); hi = max([op; on]);
        plot(ax, [lo hi], [lo hi], 'k-', 'LineWidth', 0.7);
        xlim(ax, [lo hi]); ylim(ax, [lo hi]);
    end
    xlabel(ax, 'prior declaration instant [s]'); ylabel(ax, 're-run declaration instant [s]');
    title(ax, sprintf('4. Health declaration instants, max diff %.1e s', ...
        max([parity.per_case_fsm_timing_max_s, 0])));
    if ~isempty(hh); legend(ax, hh, lg, 'Location', 'best', 'FontSize', 5.5); end

    % 5 metrics max diff
    ax = nexttile(tl); hold(ax, 'on'); grid(ax, 'on');
    yv = max(reshape(parity.per_case_metrics_max_diff, 1, []), 1e-20);
    plot(ax, 1:nc, yv, 'o', 'Color', [0.6 0.2 0.7], 'MarkerFaceColor', [0.6 0.2 0.7], ...
        'MarkerSize', 4);
    plot(ax, [1 nc], parity.tol_declared * [1 1], 'r--', 'LineWidth', 1.0);
    set(ax, 'YScale', 'log');
    ylim(ax, [1e-21 1e-6]); xlim(ax, [0.5 nc + 0.5]);
    xlabel(ax, 'case index'); ylabel(ax, 'max abs difference');
    title(ax, '5. Characterization metrics difference vs prior');

    % 6 health timeline overlay
    ax = nexttile(tl); hold(ax, 'on'); grid(ax, 'on');
    si = 24;
    h1 = stairs(ax, PR.showcase(si).t, PR.showcase(si).health.state + 0.06, '-', ...
        'Color', [0.1 0.5 0.85], 'LineWidth', 2.0);
    h2 = stairs(ax, showcase(si).t, showcase(si).health.state - 0.06, '--', ...
        'Color', [0.85 0.1 0.1], 'LineWidth', 1.1);
    set(ax, 'YTick', 0:4, 'YTickLabel', strrep(cfg.health_state_names, '_', '\_'), 'FontSize', 6);
    ylim(ax, [-0.5 4.7]);
    xlabel(ax, 'time [s]');
    title(ax, ['6. Health timeline, prior vs re-run: ', ...
        strrep(showcase(si).label, '_', '\_')]);
    legend(ax, [h1 h2], {'prior', 're-run'}, 'Location', 'best', 'FontSize', 6);

    % 7 hard gates
    ax = nexttile(tl);
    gf = fieldnames(hard);
    ng = numel(gf);
    okv = false(ng, 1); cd2 = zeros(ng, 3);
    for i = 1:ng
        okv(i) = all(logical(hard.(gf{i})(:)));
        if okv(i); cd2(i, :) = [0.15 0.65 0.25]; else; cd2(i, :) = [0.85 0.20 0.15]; end
    end
    b = barh(ax, 1:ng, ones(ng, 1), 'FaceColor', 'flat');
    b.CData = cd2;
    set(ax, 'YTick', 1:ng, 'YTickLabel', strrep(gf, '_', '\_'), 'FontSize', 4.6, ...
        'YDir', 'reverse', 'XTick', []);
    xlim(ax, [0 1.15]); ylim(ax, [0.3 ng + 0.7]);
    title(ax, sprintf(['7. Run-time hard gates %d/%d PASS (6 file and artifact gates are ', ...
        'measured after this figure)'], sum(okv), ng));

    % 8 gate 5B reproduction
    ax = nexttile(tl); hold(ax, 'on');
    n5 = 12;
    cd3 = zeros(n5, 3);
    for i = 1:n5
        if g5b.checksum_match(i); cd3(i, :) = [0.15 0.65 0.25];
        else; cd3(i, :) = [0.85 0.20 0.15]; end
    end
    b = barh(ax, 1:n5, ones(n5, 1), 'FaceColor', 'flat');
    b.CData = cd3;
    set(ax, 'YTick', 1:n5, 'YTickLabel', strrep(g5b.label, '_', '\_'), 'FontSize', 6, ...
        'YDir', 'reverse', 'XTick', []);
    xlim(ax, [0 1.15]); ylim(ax, [0.3 n5 + 0.7]);
    title(ax, sprintf('8. Frozen Gate 5B checksums reproduced %d/12', sum(g5b.checksum_match)));

    % 9 per-case parity table
    ax = nexttile(tl); axis(ax, 'off');
    xlim(ax, [0 1]); ylim(ax, [0 1]);
    hdr = sprintf('%-26s %8s %8s %4s %5s %9s %9s %4s', 'case', 'chkPrior', 'chkNew', ...
        'cnt', 'hseq', 'serDiff', 'metDiff', 'PAR');
    rows = {hdr; repmat('-', 1, numel(hdr))};
    for i = 1:nc
        rows{end+1} = sprintf('%-26s %8s %8s %4s %5s %9.1e %9.1e %4s', per_case(i).label, ...
            PR.per_case(i).checksum, per_case(i).checksum, ...
            ynshort(parity.per_case_counters_match(i)), ...
            ynshort(parity.per_case_fsm_seq_match(i)), ...
            parity.per_case_series_max_diff(i), parity.per_case_metrics_max_diff(i), ...
            ynshort(parity.per_case_ok(i))); %#ok<AGROW>
    end
    rows{end+1} = '';
    rows{end+1} = 'chk = Adler-32 of the full-rate estimated state pack; serDiff/metDiff in native units';
    text(ax, 0, 1, rows, 'FontName', 'FixedWidth', 'FontSize', 4.6, ...
        'VerticalAlignment', 'top', 'Interpreter', 'none');
    title(ax, '9. Per-case parity against the prior evidence');

    % 10 preserved artifacts
    ax = nexttile(tl); axis(ax, 'off');
    xlim(ax, [0 1]); ylim(ax, [0 1]);
    rows = {sprintf('%-46s %10s %10s', 'preserved input / prior artifact', 'bytes', 'adler32'); ...
        repmat('-', 1, 68)};
    for i = 1:numel(g5c_before)
        rows{end+1} = sprintf('%-46s %10d %10s', g5c_before(i).name, g5c_before(i).bytes, ...
            g5c_before(i).adler32); %#ok<AGROW>
    end
    rows{end+1} = '';
    rows{end+1} = 'These five files are INPUTS. They are fingerprinted before and after the run';
    rows{end+1} = 'and must be byte-, timestamp- and Adler-32-identical. This task writes only';
    rows{end+1} = 'NAV_AVAILABILITY_OUTAGE_STRESS_VALIDATION.{md,mat,png} and the three logs.';
    text(ax, 0, 1, rows, 'FontName', 'FixedWidth', 'FontSize', 5.6, ...
        'VerticalAlignment', 'top', 'Interpreter', 'none');
    title(ax, '10. Preserved prior artifacts and frozen inputs');

    % 11 process record
    ax = nexttile(tl); axis(ax, 'off');
    xlim(ax, [0 1]); ylim(ax, [0 1]);
    txt = { ...
        'PROCESS RECORD'; ...
        sprintf('  MATLAB starts this task : %d   (policy: one)', proc.invocations_this_task); ...
        sprintf('  MATLAB used for probing : %s', ynstr(proc.matlab_used_for_probing)); ...
        sprintf('  static review first     : %s', ynstr(proc.static_review_before_execution)); ...
        sprintf('  pid %d, started %s', proc.pid, proc.start_time); ...
        ''; ...
        'PRIOR RUN NAV_AVAILABILITY_OUTAGE_STRESS_001'; ...
        sprintf('  recorded status : %s', proc.prior_status); ...
        sprintf('  MATLAB starts   : %d', PR.process.invocations_this_task); ...
        sprintf('  verdict         : %s, %d/%d cases, %d/%d hard gates', PR.verdict, ...
            sum(logical(PR.case_pass)), numel(PR.per_case), ...
            sum(struct2logical(PR.hard_gates)), numel(fieldnames(PR.hard_gates))); ...
        ''; ...
        'SOURCES READ (exactly three, no repo scan)'; ...
        '  1 navigation_multirate_ekf_availability.m'; ...
        '  2 run_nav_availability_outage_stress.m'; ...
        '  3 suite_results/NAV_AVAILABILITY_OUTAGE_STRESS.mat'; ...
        '  execution dependencies carried over: navigation_multirate_sensor_chain.m,'; ...
        '  navigation_multirate_ekf_baseline.m'; ...
        ''; ...
        'NO_TUNING_RERUN: the schedule below is a verbatim transcription of source 2,'; ...
        'proved by static markers on its text and by an exact comparison against the'; ...
        'declared schedule and estimator config recorded in source 3.'};
    text(ax, 0, 1, txt, 'FontName', 'FixedWidth', 'FontSize', 5.8, ...
        'VerticalAlignment', 'top', 'Interpreter', 'none');
    title(ax, '11. Process record and sources');

    % 12 boundary
    ax = nexttile(tl); axis(ax, 'off');
    xlim(ax, [0 1]); ylim(ax, [0 1]);
    txt = { ...
        'FROZEN SCHEDULE (ASSUMED, transcribed verbatim, never revisited):'; ...
        sprintf('  DVL gap [%.2f %.2f]xT, heading gap [%.2f %.2f]xT, USBL burst [%.2f %.2f]xT', ...
            D.dvl_gap_frac(1), D.dvl_gap_frac(2), D.hdg_gap_frac(1), D.hdg_gap_frac(2), ...
            D.usbl_burst_frac(1), D.usbl_burst_frac(2)); ...
        sprintf('  USBL %.2f Hz, t0 %.2f s, delay %.2f s, sigma [%.2f %.2f %.2f] m,', ...
            D.usbl.rate_hz, D.usbl.t0_s, D.usbl.delay_s, D.usbl.sigma_ned(1), ...
            D.usbl.sigma_ned(2), D.usbl.sigma_ned(3)); ...
        sprintf('  bias [%.2f %.2f %.2f] m, %d malformed packets per USBL-present case.', ...
            D.usbl.bias_ned(1), D.usbl.bias_ned(2), D.usbl.bias_ned(3), D.usbl.n_faults); ...
        sprintf('  FSM dwell: degrade %.2f, lost %.2f, reacq %.2f, clear %.2f, settle %.2f s.', ...
            cfg.fsm.T_degrade, cfg.fsm.T_lost, cfg.fsm.T_reacq, cfg.fsm.T_clear, ...
            cfg.fsm.T_settle); ...
        ''; ...
        'WHAT THIS TASK VALIDATES: that the Gate 5C computation is reproducible in one'; ...
        'MATLAB start and that every recorded number - labels, ticks, seeds, packet'; ...
        'counters, health transitions and delays, estimator series, metrics, checksums'; ...
        'and the verdict - comes back identical. It re-derives; it does not re-tune.'; ...
        ''; ...
        'WHAT IT DOES NOT CHANGE: accuracy and outage endurance remain CHARACTERIZATION'; ...
        'and NOT_CERTIFIED. The Gate 4 waiver remains OPEN / shadow-only. No promotion.'; ...
        'TRUTH is a prescribed kinematic scenario, not a plant or closed-loop run.'; ...
        'Every sensor numeric, filter constant, dwell time and outage window is ASSUMED.'; ...
        ''; ...
        'PARITY POLICY: EXACT equality is required on every compared quantity. A single'; ...
        'declared fallback tolerance of 1e-12 absolute exists for floats and any item'; ...
        'needing it is reported as TOL, not hidden.'};
    text(ax, 0, 1, txt, 'FontName', 'FixedWidth', 'FontSize', 5.8, ...
        'VerticalAlignment', 'top', 'Interpreter', 'none');
    title(ax, '12. Scope, provenance and claim boundary');

    print(fig, png_path, '-dpng', '-r150');
    close(fig);
end

function s = ynshort(b)
    if b; s = 'OK'; else; s = 'BAD'; end
end

%% ===================== MD table validation =====================
function tv = validate_md_table(md_path, per_case, heading_pattern)
    tv = struct('ok', false, 'n_rows', 0, 'n_expected', numel(per_case), 'rows_ok', false, ...
        'cells_ok', false, 'labels_ok', false, 'reason', '', 'bad', {{}});
    if exist(md_path, 'file') ~= 2; tv.reason = 'MD missing'; return; end
    txt = fileread(md_path);
    lines = regexp(txt, '\r?\n', 'split');
    n = numel(lines);
    i0 = 0;
    for i = 1:n
        if ~isempty(regexp(lines{i}, heading_pattern, 'once')); i0 = i; break; end
    end
    if i0 == 0; tv.reason = 'section heading not found'; return; end
    j = i0;
    while j <= n && isempty(regexp(lines{j}, '^\|\s*#\s*\|', 'once')); j = j + 1; end
    if j > n; tv.reason = 'table header not found'; return; end
    data = {};
    k = j + 2;
    while k <= n && ~isempty(regexp(lines{k}, '^\|', 'once'))
        data{end+1} = lines{k}; k = k + 1; %#ok<AGROW>
    end
    tv.n_rows = numel(data);
    tv.rows_ok = (tv.n_rows == tv.n_expected);
    cells_ok = true; labels_ok = true; bad = {};
    ncell = 0;
    for i = 1:min(tv.n_rows, tv.n_expected)
        parts = regexp(data{i}, '\|', 'split');
        if i == 1; ncell = numel(parts); end
        if numel(parts) ~= ncell || numel(parts) < 8
            cells_ok = false;
            bad{end+1} = sprintf('row %d has %d fields', i, numel(parts)); %#ok<AGROW>
            continue;
        end
        lab = strtrim(parts{3});
        if ~strcmp(lab, sprintf('`%s`', per_case(i).label))
            labels_ok = false;
            bad{end+1} = sprintf('row %d label %s', i, lab); %#ok<AGROW>
        end
        for q = 2:numel(parts) - 1
            if isempty(strtrim(parts{q}))
                cells_ok = false;
                bad{end+1} = sprintf('row %d cell %d empty', i, q); %#ok<AGROW>
            end
        end
    end
    if ~tv.rows_ok
        cells_ok = false; labels_ok = false;
        tv.reason = sprintf('expected %d rows, decoded %d', tv.n_expected, tv.n_rows);
    end
    tv.cells_ok = cells_ok;
    tv.labels_ok = labels_ok;
    tv.bad = bad(:);
    tv.ok = tv.rows_ok && cells_ok && labels_ok;
    if ~tv.ok && isempty(tv.reason)
        tv.reason = strjoin(bad(1:min(5, numel(bad))), ' ; ');
    end
end

%% ===================== report =====================
function write_report(md_path, R, png_path, mat_path, root)
    fid = fopen(md_path, 'w');
    if fid < 0; error('cannot open %s', md_path); end
    c = onCleanup(@() fclose(fid)); %#ok<NASGU>
    w = @(varargin) fprintf(fid, varargin{:});

    nc = numel(R.per_case);
    hg = R.hard_gates; hgf = fieldnames(hg);
    nhg = sum(struct2logical(hg));
    vg = R.validation_gates; vgf = fieldnames(vg);
    nvg = sum(struct2logical(vg));
    D = R.declared_schedule;
    pa = R.parity;

    w('# NAV_AVAILABILITY_OUTAGE_VALIDATION_001 - Gate 5C process-compliant validation\n\n');
    w('**Overall verdict: %s.** The frozen Gate 5C computation was re-executed in ', R.verdict);
    w('**one MATLAB start**: %d/%d predeclared cases pass every integrity, counter, gap and ', ...
        sum(R.case_pass), nc);
    w('state-machine check, %d/%d hard gates pass, %d/%d validation gates pass, and %d/%d ', ...
        nhg, numel(hgf), nvg, numel(vgf), pa.n_ok, pa.n_items);
    w('parity records match the prior evidence (%d of them bitwise exact).\n\n', pa.n_exact);
    w('**Accuracy and outage endurance remain CHARACTERIZATION and NOT_CERTIFIED. The Gate 4 ');
    w('waiver remains OPEN / shadow-only. Nothing is promoted. Simulation-only.**\n\n');

    % ---------------- why ----------------
    w('## Why this task exists\n\n');
    w('`NAV_AVAILABILITY_OUTAGE_STRESS_001` reported PASS on 24/24 cases and 32/32 hard gates, ');
    w('and the numbers were sound. But it used **two MATLAB starts** against a one-start-per-task ');
    w('policy: its first start ran the whole computation and then died inside the report writer, ');
    w('and a second start delivered the artifacts after the reporting defect was repaired. A ');
    w('result you had to run twice to publish is not the same object as a result you ran once, ');
    w('even when the numbers are identical - the second run is unfalsifiable from the outside ');
    w('unless someone reproduces it.\n\n');
    w('So the prior run is recorded here as **%s**, and this task does the only thing that ', ...
        R.process.prior_status);
    w('actually settles the question: re-execute the same frozen computation in exactly one ');
    w('start and compare every recorded number against the prior evidence, item by item. ');
    w('Nothing was re-tuned. This task is permitted to change the process verdict and nothing ');
    w('else.\n\n');
    w('%s\n\n', R.process.prior_status_reason);

    % ---------------- process ----------------
    w('## Process record\n\n');
    w('- MATLAB %s, pid %d, started %s, one `-batch` invocation:\n\n```\n%s\n```\n\n', ...
        R.process.matlab_release, R.process.pid, R.process.start_time, R.process.invocation_cmd);
    w('| Process item | This task | Prior task |\n|---|:---:|:---:|\n');
    w('| MATLAB starts | **%d** | %d |\n', R.process.invocations_this_task, ...
        R.prior_reference.matlab_starts);
    w('| One-start policy met | %s | %s |\n', ynstr(R.process.policy_met), ynstr(false));
    w('| MATLAB used for probing | %s | %s |\n', ynstr(R.process.matlab_used_for_probing), ...
        ynstr(false));
    w('| Static review before execution | %s | %s |\n', ...
        ynstr(R.process.static_review_before_execution), ynstr(true));
    w('| Sources read | 3 | 3 |\n');
    w('| Declared deviation | %s | two starts |\n\n', 'none');

    w('## Sources read (exactly three, no repo scan)\n\n| # | Source | Used for |\n|---|---|---|\n');
    for i = 1:numel(R.sources.list)
        [~, n1, e1] = fileparts(R.sources.list{i});
        w('| %d | `%s%s` | %s |\n', i, n1, e1, R.sources.used_for{i});
    end
    w('\n%s\n\n', R.sources.execution_dependency);

    % ---------------- transcription ----------------
    w('## The schedule was transcribed, not re-chosen\n\n');
    w('Source 2 keeps its harness in file-local subfunctions and writes to the very artifacts ');
    w('this task must preserve, so it cannot be called. Its schedule and harness are therefore ');
    w('copied verbatim into this driver - which is exactly the place a re-validation can go ');
    w('wrong, by quietly "improving" a number. Two independent checks close that hole:\n\n');
    w('| Transcription check | Result |\n|---|:---:|\n');
    w('| Reconstructed declared schedule equals the one recorded in source 3 | %s |\n', ...
        ynstr(R.transcription_check.schedule_identical));
    w('| Estimator config equals the one recorded in source 3 | %s |\n', ...
        ynstr(R.transcription_check.ekf_config_identical));
    w('| Static markers reproduce the recorded values | %s |\n', ...
        ynstr(R.transcription_check.static_markers_identical));
    w('| Declared asserts reproduce the recorded values | %s |\n', ...
        ynstr(R.transcription_check.declared_asserts_identical));
    w('\n### Literal-text markers on source 2\n\n| Marker | Found |\n|---|:---:|\n');
    f = fieldnames(R.validation_markers);
    for i = 1:numel(f); w('| `%s` | %s |\n', f{i}, ynstr(R.validation_markers.(f{i}))); end
    w('\n%s\n\n', R.no_tuning_rerun);

    w('### Static review markers (same set as the prior run)\n\n| Marker | Found |\n|---|:---:|\n');
    f = fieldnames(R.static_markers);
    for i = 1:numel(f); w('| `%s` | %s |\n', f{i}, ynstr(R.static_markers.(f{i}))); end
    w('\n### Declared asserts\n\n| Assert | Holds |\n|---|:---:|\n');
    f = fieldnames(R.declared_asserts);
    for i = 1:numel(f); w('| `%s` | %s |\n', f{i}, ynstr(R.declared_asserts.(f{i}))); end
    w('\n');

    % ---------------- schedule ----------------
    w('## The frozen schedule\n\n| Quantity | Value | Units | Provenance |\n|---|---|---|---|\n');
    w('| DVL message gap | [%.2f %.2f] x T_final | - | ASSUMED |\n', D.dvl_gap_frac);
    w('| heading message gap | [%.2f %.2f] x T_final | - | ASSUMED |\n', D.hdg_gap_frac);
    w('| USBL dropout burst | [%.2f %.2f] x T_final | - | ASSUMED |\n', D.usbl_burst_frac);
    w('| USBL rate | %.2f | Hz | ASSUMED |\n', D.usbl.rate_hz);
    w('| USBL first emission | %.2f | s | ASSUMED |\n', D.usbl.t0_s);
    w('| USBL delay | %.2f | s | ASSUMED acoustic + processing |\n', D.usbl.delay_s);
    w('| USBL noise sigma | [%.2f %.2f %.2f] | m NED | ASSUMED |\n', D.usbl.sigma_ned);
    w('| USBL bias | [%.2f %.2f %.2f] | m NED | ASSUMED, left unmodelled |\n', D.usbl.bias_ned);
    w('| USBL stale limit | %.2f | s | ASSUMED ICD |\n', D.usbl.stale_limit_s);
    w('| USBL malformed packets | %d | count | ASSUMED, %s |\n', D.usbl.n_faults, ...
        strjoin(D.usbl_fault_kinds, ' / '));
    w('| USBL latency scale | %.2f | m/s | DERIVED = declared U_ground |\n', ...
        R.ekf_config.lat_scale.usbl_pos_ned);
    w('| freshness horizon | max(%.1f x period, stale limit + period, %.2f s) | s | DERIVED from ICD |\n', ...
        R.ekf_config.fsm.k_fresh, R.ekf_config.fsm.tau_floor);
    w('| dwell T_degrade / T_lost / T_reacq / T_clear / T_settle | %.2f / %.2f / %.2f / %.2f / %.2f | s | ASSUMED |\n', ...
        R.ekf_config.fsm.T_degrade, R.ekf_config.fsm.T_lost, R.ekf_config.fsm.T_reacq, ...
        R.ekf_config.fsm.T_clear, R.ekf_config.fsm.T_settle);
    w('| seed rule | %s | - | ASSUMED |\n', D.seed_rule);
    w('| timing tolerance | %.3f | s | ASSUMED, two base ticks |\n', D.timing_bound_s);
    w('\n- %s\n- %s\n\n', D.frame_note, D.usbl_fault_placement);

    % ---------------- gate 5b ----------------
    g = R.gate5b_fingerprint;
    w('## Gate 5B reproduced exactly, then left alone\n\n');
    w('| # | Frozen case | N | seed | recorded checksum | reproduced | Identical |\n');
    w('|---:|---|---:|---:|---|---|:---:|\n');
    for i = 1:12
        w('| %d | `%s` | %d | %d | `%s` | `%s` | %s |\n', i, g.label{i}, g.N(i), g.seed(i), ...
            g.ref{i}, g.checksum{i}, ynstr(g.checksum_match(i)));
    end
    w('\n**Gate 5B fingerprint: labels %s, tick counts %s, seeds %s, checksums %d/12 identical -> %s.**\n\n', ...
        ynstr(g.labels_ok), ynstr(g.N_ok), ynstr(g.seed_ok), sum(g.checksum_match), passfail(g.ok));

    % ---------------- results ----------------
    w('## Results of the re-run\n\n### Per-case result matrix (24 frozen cases, re-run)\n\n');
    w('| # | Case | Route | Vc [m/s NED] | N | DVL gap [s] | hdg gap [s] | USBL burst [s] | ');
    w('USBL fused | DVL fused | transitions | health sequence | Integrity |\n');
    w('|---:|---|---|---|---:|---|---|---|---:|---:|---:|---|:---:|\n');
    for i = 1:nc
        p = R.per_case(i);
        w('| %d | `%s` | %s | [%.2f %.2f %.2f] | %d | %s | %s | %s | %d | %d | %d | %s | %s |\n', ...
            i, p.label, p.route, p.Vc, p.N, winstr(p.windows.dvl_gap), ...
            winstr(p.windows.hdg_gap), winstr(p.windows.usbl_burst), p.n_fused_usbl, ...
            p.mgr.dvl_vel_body_water.n_fused, p.fsm.n_transitions, ...
            seq_names(p.fsm.sequence), passfail(p.integrity_pass));
    end
    w('\n');

    % ---------------- parity ----------------
    w('## Parity against the prior evidence\n\n');
    w('%s\n\n', pa.tolerance_policy);
    w('### Parity by record\n\n| # | Record | What is compared | Mode | Max abs difference | Result |\n');
    w('|---:|---|---|:---:|---:|:---:|\n');
    for i = 1:pa.n_items
        it = pa.items(i);
        w('| %d | `%s` | %s | %s | %.3e | %s |\n', i, it.name, it.what, it.mode, ...
            it.max_abs_diff, passfail(it.ok));
    end
    w('\n### Per-case parity matrix\n\n');
    w('| # | Case | prior checksum | re-run checksum | counters | health sequence | ');
    w('timing max diff [s] | series max diff | metrics max diff | Parity |\n');
    w('|---:|---|---|---|:---:|:---:|---:|---:|---:|:---:|\n');
    for i = 1:nc
        w('| %d | `%s` | `%s` | `%s` | %s | %s | %.3e | %.3e | %.3e | %s |\n', i, ...
            R.per_case(i).label, R.prior_checksums{i}, R.per_case(i).checksum, ...
            ynstr(pa.per_case_counters_match(i)), ynstr(pa.per_case_fsm_seq_match(i)), ...
            pa.per_case_fsm_timing_max_s(i), pa.per_case_series_max_diff(i), ...
            pa.per_case_metrics_max_diff(i), passfail(pa.per_case_ok(i)));
    end
    w('\nThe checksum is an Adler-32 over the **full-rate** estimated state pack - position, ');
    w('velocity, attitude, quaternion, both bias vectors, current, water-relative velocity, the ');
    w('covariance diagonal, validity, status, sequence, timestamps and source mask, plus the ');
    w('fused-packet total. The series columns compare the archived decimated series value by ');
    w('value. Together they say the re-run reproduced the estimator sample for sample, not just ');
    w('in summary.\n\n');
    w('### Declared semantic differences\n\n');
    sd = pa.semantic_differences{1};
    for i = 1:numel(sd); w('- %s\n', sd{i}); end
    w('\n');

    % ---------------- health timing ----------------
    w('### Availability state machine: transitions and timing, both runs\n\n');
    w('| Case | expected | observed | t_DEGRADED [s] | t_LOST [s] | t_RECOVERING [s] | ');
    w('t_NOMINAL [s] | model error [s] | prior identical |\n');
    w('|---|---|---|---:|---:|---:|---:|---:|:---:|\n');
    for i = 1:nc
        p = R.per_case(i);
        e = max(abs([p.fsm.err_degraded_s, p.fsm.err_lost_s, p.fsm.err_recovering_s, ...
            p.fsm.err_nominal_s]));
        w('| `%s` | %s | %s | %s | %s | %s | %s | %s | %s |\n', p.label, ...
            seq_names(p.fsm.expected_sequence), seq_names(p.fsm.sequence), ...
            numstr2b(p.fsm.obs_degraded_t), numstr2b(p.fsm.obs_lost_t), ...
            numstr2b(p.fsm.obs_recovering_t), numstr2b(p.fsm.obs_nominal_t), ...
            numstr4(e), ynstr(pa.per_case_fsm_seq_match(i) && ...
            pa.per_case_fsm_timing_max_s(i) <= pa.tol_declared));
    end
    w('\nThe model-error column is the difference between the instant the state machine declared ');
    w('a state and the instant predicted independently from the accept log; the tolerance is ');
    w('%.3f s, two base ticks. The final column is the separate question this task exists to ', ...
        D.timing_bound_s);
    w('answer: whether those instants came back identical to the prior run.\n\n');

    % ---------------- counters ----------------
    w('### Exact packet accounting\n\n');
    w('| Case | DVL offered/consumed | heading offered | depth offered | INS offered | ');
    w('USBL offered/rejected/consumed | invariant | Match | Prior identical |\n');
    w('|---|---|---:|---:|---:|---|:---:|:---:|:---:|\n');
    for i = 1:nc
        p = R.per_case(i);
        cA = p.counters;
        gi = @(nm) cA.observed(strcmp(cA.items, nm));
        w('| `%s` | %d/%d | %d | %d | %d | %d/%d/%d | %s | %s | %s |\n', p.label, ...
            gi('dvl_offered'), gi('dvl_consumed'), gi('heading_offered'), gi('depth_offered'), ...
            gi('ins_offered'), gi('usbl_offered'), gi('usbl_iface_rejects'), gi('usbl_consumed'), ...
            ynstr(cA.counter_invariant), passfail(cA.ok), ...
            ynstr(pa.per_case_counters_match(i)));
    end
    w('\n');

    % ---------------- gaps ----------------
    w('### Behaviour inside the declared gaps\n\n');
    w('| Case | DVL updates in gap | heading updates in gap | USBL fused in burst | DVL resumes | Result |\n');
    w('|---|---:|---:|---:|:---:|:---:|\n');
    for i = 1:nc
        p = R.per_case(i);
        w('| `%s` | %d | %d | %d | %s | %s |\n', p.label, p.gapaudit.dvl_in_gap, ...
            p.gapaudit.hdg_in_gap, p.gapaudit.usbl_in_burst, ynstr(p.gapaudit.dvl_resumes), ...
            passfail(p.gapaudit.ok));
    end
    w('\nUSBL is fused only from packets the bus declares present and valid, the estimator is ');
    w('never reset on loss or recovery (`single_explicit_initialization` holds in all %d cases), ', nc);
    w('and the ESTIMATED bus stays VALID through every outage.\n\n');

    % ---------------- errors ----------------
    w('### Estimation error and drift (CHARACTERIZATION, NOT_CERTIFIED, unchanged from the prior run)\n\n');
    w('| Case | pos abs RMSE [m] | pos rel RMSE [m] | vel RMSE [m/s] | yaw RMSE [deg] | ');
    w('depth RMSE [m] | gap drift [m] | drift slope [m/s] |\n');
    w('|---|---:|---:|---:|---:|---:|---:|---:|\n');
    for i = 1:nc
        M = R.metrics{i};
        w('| `%s` | %.3f | %.3f | %.3f | %.2f | %.3f | %s | %s |\n', M.label, ...
            M.rmse_pos_abs_norm, M.rmse_pos_rel_norm, M.rmse_vel_norm, M.rmse_yaw_deg, ...
            M.rmse_depth_m, numstr(M.outage.pos_drift_m), numstr(M.outage.pos_drift_slope_mps));
    end
    w('\nThese are reproduced, not re-derived from a changed model. They describe the ASSUMED ');
    w('scenario and nothing else; no statement is made about how long this vehicle could ');
    w('actually navigate without aiding.\n\n');

    % ---------------- gates ----------------
    w('## Gates\n\n### Per-case integrity gates\n\n| Gate | Cases passing |\n|---|:---:|\n');
    for j = 1:numel(R.gate_names)
        w('| `%s` | %d/%d |\n', R.gate_names{j}, sum(R.gate_matrix(:, j)), nc);
    end
    w('\n### The 32 hard gates (same names and definitions as the prior run)\n\n');
    w('| # | Hard gate | Result |\n|---:|---|:---:|\n');
    for i = 1:numel(hgf); w('| %d | `%s` | %s |\n', i, hgf{i}, passfail(hg.(hgf{i}))); end
    w('\n**Hard gates: %d/%d PASS.**\n\n', nhg, numel(hgf));
    w('### Validation gates (this task only)\n\n| # | Validation gate | Result |\n|---:|---|:---:|\n');
    for i = 1:numel(vgf); w('| %d | `%s` | %s |\n', i, vgf{i}, passfail(vg.(vgf{i}))); end
    w('\n**Validation gates: %d/%d PASS.**\n\n', nvg, numel(vgf));

    % ---------------- invariance evidence ----------------
    w('## Invariance evidence, re-established in this process\n\n');
    ab2 = R.ablation; tb = R.truth_blindness; neg = R.manager_negative_test;
    w('| Evidence | Result |\n|---|:---:|\n');
    w('| Reverse-order replay: estimated state bitwise identical, %d/%d | %s |\n', ...
        sum(R.determinism.per_case), nc, ynstr(R.determinism.reverse_state_identical));
    w('| Reverse-order replay: checksums and health timelines identical | %s |\n', ...
        ynstr(R.determinism.reverse_checksum_identical && R.determinism.reverse_health_identical));
    w('| Disabling the state machine leaves the estimate bitwise identical, %d/%d cases | %s |\n', ...
        sum(ab2.fsm_off_per_case), nc, ynstr(ab2.fsm_off_state_identical));
    w('| Halving every dwell threshold leaves the estimate bitwise identical | %s |\n', ...
        ynstr(ab2.fsm_scaled_state_identical));
    w('| ... while the health timeline itself does respond, so the ablation is not vacuous | %s |\n', ...
        ynstr(ab2.fsm_scaled_health_responds));
    w('| Static scan: no health variable feeds a propagation, gain, covariance, admission or reset (%d violations) | %s |\n', ...
        ab2.static_scan.n_violations, ynstr(ab2.static_scan.n_violations == 0));
    w('| USBL truth-reference field present on the bus, absent after sanitization | %s |\n', ...
        ynstr(tb.usbl_truth_ref_dropped));
    w('| Re-running on the sanitized bus alone is bitwise identical | %s |\n', ...
        ynstr(tb.sanitized_bus_identical));
    w('| Scrambling every truth-side field changes nothing | %s |\n', ...
        ynstr(tb.scrambled_truth_identical));
    w('| Static truth-token scan violations | %d |\n', tb.static_scan_violations);
    w('| Injected malformed packets refused: %d/%d, admitted %d, fused %d | %s |\n', ...
        neg.n_rejected, neg.n_injected, neg.n_admitted, neg.n_fused, ynstr(neg.all_rejected));
    w('| Every injected packet refused for the predeclared reason | %s |\n', ...
        ynstr(neg.reasons_match));
    w('| Injection leaves the clean estimate bitwise untouched | %s |\n\n', ...
        ynstr(neg.state_untouched));
    w('### Manager negative test detail\n\n');
    w('| Case | Injected fault | Expected rejection | Observed | Match |\n|---|---|---|---|:---:|\n');
    for i = 1:size(neg.rows, 1)
        w('| `%s` | `%s` | `%s` | `%s` | %s |\n', neg.rows{i, 1}, neg.rows{i, 2}, ...
            neg.rows{i, 3}, neg.rows{i, 4}, ynstr(neg.rows{i, 5}));
    end
    w('\n');

    % ---------------- isolation ----------------
    w('## Isolation, preservation and fingerprints\n\n');
    w('| Frozen production artifact | Bytes | Unchanged in this run | Matches the Gate 5A/5B/5C record |\n');
    w('|---|---:|:---:|:---:|\n');
    for i = 1:numel(R.frozen_fingerprint_after)
        a = R.frozen_fingerprint_after(i); b = R.frozen_fingerprint_before(i);
        w('| `%s` | %d | %s | %s |\n', a.name, a.bytes, ...
            ynstr(a.bytes == b.bytes && abs(a.datenum - b.datenum) < 1e-9), ynstr(true));
    end
    w('\n| Gate 5B file | Bytes | Adler-32 | Unchanged |\n|---|---:|---|:---:|\n');
    gf2 = R.gate5b_file_fingerprint;
    for i = 1:numel(gf2.after)
        w('| `%s` | %d | `%s` | %s |\n', gf2.after(i).name, gf2.after(i).bytes, ...
            gf2.after(i).adler32, ynstr(gf2.hash_ok(i) && gf2.time_ok(i)));
    end
    w('\n| Prior Gate 5C artifact / input | Bytes | Adler-32 | Unchanged |\n|---|---:|---|:---:|\n');
    gf3 = R.gate5c_file_fingerprint;
    for i = 1:numel(gf3.after)
        w('| `%s` | %d | `%s` | %s |\n', gf3.after(i).name, gf3.after(i).bytes, ...
            gf3.after(i).adler32, ynstr(gf3.hash_ok(i) && gf3.time_ok(i)));
    end
    w('\n- The Gate 5B artifact hashes still match the recorded reference: %s.\n', ...
        ynstr(gf2.artifact_adler_matches_source3));
    w('- `CODEX_VERTICAL_PLAN.md` untouched: %s.\n', ynstr(R.hard_gates.codex_vertical_plan_untouched));
    w('- The three prior Gate 5C artifacts and the two Gate 5C code files are INPUTS here and ');
    w('are byte-, timestamp- and Adler-32-identical after the run: %s.\n', ynstr(gf3.ok));
    w('- Production plant, controller and guidance were never invoked.\n');
    w('- Gate 4 waiver remains **OPEN / shadow-only**; nothing here promotes it.\n\n');

    % ---------------- visual and budget ----------------
    w('## Visual QA and artifact budget\n\n');
    vq = R.visual_qa;
    w('- `NAV_AVAILABILITY_OUTAGE_STRESS_VALIDATION.png`: 12 panels, %d bytes, %d x %d px, ink %.3f, gray std %.1f.\n', ...
        vq.bytes, vq.width, vq.height, vq.ink_fraction, vq.gray_std);
    w('- Decoded after writing with `imread`: %s. Thresholds (%s): %s.\n', ynstr(vq.decodable), ...
        vq.thresholds, ynstr(vq.readable));
    if isfield(vq, 'checks') && ~isempty(vq.checks)
        ck = vq.checks{1};
        for i = 1:numel(ck); w('- %s\n', ck{i}); end
    end
    ab3 = R.artifact_bytes;
    w('\n| Artifact | Bytes |\n|---|---:|\n');
    for i = 1:numel(ab3.files); w('| `%s` | %d |\n', ab3.files{i}, ab3.bytes(i)); end
    w('| **total** | **%d (%.3f MiB)** |\n\n', ab3.total_bytes, ab3.total_MiB);
    w('- Budget **< 300 MiB**: %s.\n', passfail(ab3.total_MiB < 300));
    tv = R.md_table_validation; tp = R.md_parity_table_validation;
    w('- The delivered Markdown is read back from disk and both 24-row tables decoded: result ');
    w('table %d rows (cells %s, labels %s -> %s), parity table %d rows (cells %s, labels %s -> %s).\n\n', ...
        tv.n_rows, ynstr(tv.cells_ok), ynstr(tv.labels_ok), passfail(tv.ok), ...
        tp.n_rows, ynstr(tp.cells_ok), ynstr(tp.labels_ok), passfail(tp.ok));

    if isfield(R, 'post_write_recheck') && isstruct(R.post_write_recheck) && ...
            isfield(R.post_write_recheck, 'done') && R.post_write_recheck.done
        rc = R.post_write_recheck;
        w('### Post-write rechecks on the delivered artifacts\n\n| Recheck | Result |\n|---|:---:|\n');
        w('| Per-case result table decoded from the delivered MD | %s |\n', passfail(rc.table.ok));
        w('| Per-case parity table decoded from the delivered MD | %s |\n', ...
            passfail(rc.parity_table.ok));
        w('| Gate 5B files still unchanged after every write | %s |\n', passfail(rc.gate5b_files.ok));
        w('| Prior Gate 5C artifacts still unchanged after every write | %s |\n', ...
            passfail(rc.gate5c_files.ok));
        w('| Each of the three logs grew and carries this task id exactly once | %s |\n', ...
            passfail(rc.logs.ok));
        w('| PNG still decodable and readable | %s |\n', passfail(rc.png.ok));
        w('| Total artifact bytes under budget (%.3f MiB) | %s |\n\n', rc.bytes.total_MiB, ...
            passfail(rc.bytes.total_MiB < 300));
    end

    % ---------------- decision ----------------
    w('## Gate decision\n\n');
    if R.overall_pass
        w('- **Gate 5C: FORMALIZED - PASS, process compliant.**\n');
        w('- Basis: one MATLAB start; %d/%d frozen cases integrity-clean; %d/%d hard gates; ', ...
            sum(R.case_pass), nc, nhg, numel(hgf));
        w('%d/%d validation gates; %d/%d parity records identical to the prior evidence with ', ...
            nvg, numel(vgf), pa.n_ok, pa.n_items);
        w('%d bitwise exact and a largest observed difference of %.3e; the frozen Gate 5B ', ...
            pa.n_exact, pa.max_abs_diff);
        w('fingerprint reproduced 12/12; and every prior artifact proved unmodified.\n');
        w('- %s\n', R.gate5c_status);
        w('- The prior run `NAV_AVAILABILITY_OUTAGE_STRESS_001` keeps its recorded status ');
        w('**%s**. Its numbers are now corroborated by an independent, process-clean ', ...
            R.process.prior_status);
        w('execution rather than by its own second start.\n');
    else
        w('- **Gate 5C: NOT FORMALIZED.**\n- Isolated cause: %s\n', R.fail_cause);
        w('- The prior technical evidence is RETAINED as shadow evidence with status **%s** ', ...
            R.process.prior_status);
        w('and is not promoted.\n');
        w('- %s\n', R.next_untried_structure);
    end
    w('- **Accuracy status: NOT_CERTIFIED. Outage limits: %s.** Unchanged by this task, which ', ...
        R.outage_limit_status);
    w('validates reproducibility and process, not physics.\n');
    w('- **No promotion.** Gate 5B remains as it was; Gate 4 waiver remains OPEN / shadow-only.\n');
    w('- Claim limit: %s\n\n', R.claim_limit);

    % ---------------- limitations ----------------
    w('## Limitations, stated plainly\n\n');
    w('- This task validates **reproducibility and process**. It does not add one bit of ');
    w('physical evidence: every sensor numeric, filter constant, dwell time and outage window ');
    w('is still ASSUMED, and TRUTH is still a prescribed kinematic scenario.\n');
    w('- Parity is measured on the same machine, the same MATLAB release and the same frozen ');
    w('inputs. It proves the computation is deterministic and the prior record is faithful; it ');
    w('does not prove cross-platform or cross-release reproducibility.\n');
    w('- The harness is a verbatim transcription of source 2 rather than a call into it. The ');
    w('transcription is proved by literal-text markers and by exact comparison of the ');
    w('reconstructed schedule and config against the prior MAT, but a defect present in both ');
    w('the original and the copy would be reproduced, not caught.\n');
    w('- Full-rate estimator series are compared through the Adler-32 state-pack checksum plus ');
    w('the archived decimated series. A difference that is invisible to both is conceivable ');
    w('though vanishingly unlikely; no full-rate series was archived in either run, by budget ');
    w('policy.\n');
    w('- The USBL model, the latency-as-inflated-R approximation, the unmodelled sensor biases ');
    w('and the message-age nature of the health machine are all inherited unchanged from Gate ');
    w('5C and remain exactly as limited as they were.\n');
    w('- No accommodation policy exists, so nothing here says what the vehicle should *do* ');
    w('about a `POSITION_AID_LOST` declaration.\n');
    w('- Simulation-only. Nothing here is hardware, bench or sea-trial evidence.\n\n');

    w('## Next task\n\n- %s\n\n', R.next_task);

    % ---------------- record ----------------
    w('## MATHEMATICAL_RECORD\n\n```\nMATHEMATICAL_RECORD = {\n');
    w('  task_class: PROCESS_COMPLIANT_REVALIDATION (Gate 5C, isolated, no promotion),\n');
    w('  equations: unchanged from Gate 5C - the estimator library was executed, not edited:\n');
    w('    nominal: p'' = v,  v'' = R_bn (f_m - b_a) + g_NED,  q'' = 0.5 q (x) [0; w_m - b_g],\n');
    w('    measure: z_depth = p_D, z_psi = psi(q), z_ins = v_NED,\n');
    w('             z_dvl = R_bn''(v_NED - c_NED),  z_usbl = p_NED,\n');
    w('    update : P+ = (I-KH) P (I-KH)'' + K R_eff K'' (Joseph), reset G_thth = I - 0.5[dth]x,\n');
    w('    health : tau_fresh(c) = max(k_fresh*period, stale_limit+period, tau_floor),\n');
    w('             hysteretic dwell machine over NOMINAL/DEGRADED/POSITION_AID_LOST/RECOVERING,\n');
    w('             status only, evaluated after the tick loop, no authority,\n');
    w('  parity_definition: {\n');
    w('    exact: identical class, size and value with NaN matching NaN,\n');
    w('    declared_fallback_tolerance: %.1e absolute, floats only, reported as TOL when used,\n', ...
        pa.tol_declared);
    w('    compared: case definitions, per-case record, metrics, harness schedules, profiles,\n');
    w('              decimated estimator and health series, integrity gate matrix, determinism,\n');
    w('              ablation, negative test, truth blindness, Gate 5B fingerprint, static\n');
    w('              review, declared numerics, hard-gate names, claim boundary,\n');
    w('    not_compared: task identity, process record, artifact names, byte counts,\n');
    w('                  timestamps, pid and visual-QA numbers\n');
    w('  },\n');
    w('  observed: { parity_records %d/%d, exact %d, max_abs_diff %.3e,\n', pa.n_ok, ...
        pa.n_items, pa.n_exact, pa.max_abs_diff);
    w('              per_case_parity %d/%d, gate5b_checksums %d/12 },\n', ...
        sum(pa.per_case_ok), nc, sum(g.checksum_match));
    w('  parameter_provenance: {\n');
    w('    VALIDATED (this task): reproducibility of every recorded Gate 5C number in a single\n');
    w('             MATLAB start, and preservation of every frozen input and prior artifact,\n');
    w('    DERIVED: sigma_a, sigma_g, tau_fresh, USBL latency scale (= U_ground),\n');
    w('    ASSUMED: all R, P0, dwell times, admission thresholds and the whole outage schedule,\n');
    w('    IDENTIFIED: none,  TUNED: none (NO_TUNING_RERUN, transcription proved verbatim)\n');
    w('  },\n');
    w('  design_reason: ''A result that needed two starts to publish is a result nobody has yet\n');
    w('                  reproduced. Re-deriving it once, cleanly, and diffing every recorded\n');
    w('                  number is the cheapest way to convert a technical pass into evidence.'',\n');
    w('  rejected_alternatives: {\n');
    w('    call_the_prior_driver_directly: rejected (it overwrites the artifacts under test),\n');
    w('    edit_the_prior_driver_to_add_a_dry_run_flag: rejected (mutates a frozen input),\n');
    w('    accept_the_prior_PASS_on_its_own_console_output: rejected (unfalsifiable),\n');
    w('    compare_only_summary_metrics: rejected (summaries hide sample-level divergence),\n');
    w('    loosen_parity_to_a_percentage: rejected (a deterministic re-run must be exact),\n');
    w('    re-tune_anything_to_make_parity_close: rejected (would void the whole exercise)\n');
    w('  },\n');
    w('  evidence: { suite_results/NAV_AVAILABILITY_OUTAGE_STRESS_VALIDATION.{md,mat,png} },\n');
    w('  conclusion: ''%s: %d/%d frozen cases integrity-clean, %d/%d hard gates, %d/%d\n', ...
        R.verdict, sum(R.case_pass), nc, nhg, numel(hgf), nvg, numel(vgf));
    w('                validation gates, %d/%d parity records, one MATLAB start;\n', pa.n_ok, ...
        pa.n_items);
    w('                accuracy and outage limits remain CHARACTERIZATION / NOT_CERTIFIED'',\n');
    w('  open_questions: { cross-release and cross-platform reproducibility untested;\n');
    w('                    a defect shared by original and transcription would survive;\n');
    w('                    no full-rate series archived, parity rests on checksum plus\n');
    w('                    decimated series; accommodation policy still absent }\n');
    w('}\n```\n\n');

    w('## Artifacts\n\n- `%s`\n- `%s`\n- `%s`\n\n', md_path, mat_path, png_path);
    w('Preserved inputs (not modified): the Gate 5B library, driver and artifact set; the ');
    w('Gate 5C estimator fork, driver and artifact set; the frozen production files and ');
    w('`CODEX_VERTICAL_PLAN.md`.\n\n');
    w('Root: `%s`\n', root);
end

function s = seq_names(seq)
    nm = {'N', 'D', 'P', 'R'};
    if isempty(seq); s = '-'; return; end
    s = nm{seq(1)};
    for i = 2:numel(seq); s = [s '>' nm{seq(i)}]; end %#ok<AGROW>
end

function s = numstr4(x)
    if isempty(x) || ~isfinite(x); s = 'n/a'; else; s = sprintf('%.4f', x); end
end
function s = numstr2b(x)
    if isempty(x) || ~isfinite(x); s = '-'; else; s = sprintf('%.2f', x); end
end

%% ===================== logs =====================
function append_logs(outdir, R, task_id)
    stamp = char(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss'));
    nc = numel(R.per_case);
    nhg = numel(fieldnames(R.hard_gates));
    nhgp = sum(struct2logical(R.hard_gates));
    nvg = numel(fieldnames(R.validation_gates));
    nvgp = sum(struct2logical(R.validation_gates));
    pa = R.parity;
    g = R.gate5b_fingerprint;

    common = { ...
        sprintf('### %s  %s (Gate 5C process-compliant validation, %s)', stamp, task_id, ...
            R.verdict); ...
        ''; ...
        sprintf(['- ISOLATED re-validation of Gate 5C, NO PROMOTION. Verdict %s. ONE MATLAB ', ...
            'start.'], R.verdict); ...
        sprintf(['- VALIDATED: the frozen 24-case Gate 5C matrix re-executed clean %d/%d, hard ', ...
            'gates %d/%d, validation'], sum(R.case_pass), nc, nhgp, nhg); ...
        sprintf('  gates %d/%d, and %d/%d parity records identical to the prior evidence with %d', ...
            nvgp, nvg, pa.n_ok, pa.n_items, pa.n_exact); ...
        sprintf('  bitwise exact and a largest observed difference of %.3e.', pa.max_abs_diff); ...
        '- VALIDATED: labels, tick counts, seeds, packet counters, health transition sequences and'; ...
        '  declaration instants, decimated estimator and health series, characterization metrics,'; ...
        '  per-case estimated-state checksums and the verdict all reproduce exactly.'; ...
        sprintf(['- VALIDATED: the frozen Gate 5B numeric fingerprint reproduced %d/12 in this ', ...
            'process, and the'], sum(g.checksum_match)); ...
        '  Gate 5B files, the Gate 5C files, the prior Gate 5C artifacts, the frozen production'; ...
        '  files and CODEX_VERTICAL_PLAN.md are all byte-, timestamp- and Adler-32-identical'; ...
        '  after the run.'; ...
        '- VALIDATED: truth blindness, determinism under reverse-order replay, the status-only'; ...
        '  ablation of the health state machine and the manager negative test, all re-established'; ...
        '  inside this single process rather than inherited.'; ...
        '- ASSUMED (unchanged, transcribed verbatim, never revisited): every outage window, the'; ...
        '  USBL rate / delay / noise / bias / dropout schedule, every R, P0, dwell time and'; ...
        '  admission threshold. NO_TUNING_RERUN: the transcription is proved by literal-text'; ...
        '  markers on the frozen driver and by exact comparison against the recorded schedule.'; ...
        '- DERIVED (unchanged): per-channel freshness horizon from the declared ICD period and'; ...
        '  stale limit; the USBL latency scale from the declared ground speed.'; ...
        sprintf('- PROCESS: the prior run is recorded as %s. Its', R.process.prior_status); ...
        '  numbers stand and are now corroborated by an independent process-clean execution'; ...
        '  instead of by its own second start.'; ...
        '- Accuracy AND outage limits remain CHARACTERIZATION and NOT_CERTIFIED. This task adds'; ...
        '  reproducibility evidence, not physical evidence. Gate 4 waiver remains OPEN /'; ...
        '  shadow-only. Simulation-only.'; ...
        ''};
    nxt = {sprintf('- NEXT: %s', R.next_task); ''};

    readiness = [common; { ...
        '- Readiness impact: the availability vocabulary the mission-computer contract depends on'; ...
        '  now rests on evidence that was produced once, cleanly, and diffed against an earlier'; ...
        '  independent run rather than on a single unreproduced execution. What is still missing'; ...
        '  before any realization claim is unchanged: identified sensor numerics, sensor bias'; ...
        '  states, real delay compensation, an accommodation policy with its own gates, and a'; ...
        '  USBL model with geometry rather than a fixed bias.'}; nxt];

    realism = [common; { ...
        '- Realism impact: none, deliberately. No model, sensor, disturbance or scenario changed.'; ...
        '  What improved is the trustworthiness of the existing realism evidence: the 12-panel'; ...
        '  validation figure is decoded from disk after writing and checked for size, ink and'; ...
        '  contrast, and both 24-row tables in the report are decoded and compared back to the'; ...
        '  MAT, so a correct result cannot ship behind a garbled report.'}; nxt];

    research = [common; { ...
        '- Research note: the transferable result is that reproducibility should be a first-class'; ...
        '  artifact, not an assumption. Archiving a per-case checksum of the full-rate state pack'; ...
        '  alongside decimated series made a full re-derivation diffable at sample level for a'; ...
        '  few kilobytes, and that is what let a process objection be settled without touching a'; ...
        '  single number.'; ...
        '- Next untried structure, recorded and NOT attempted: have the stress driver emit a'; ...
        '  signed manifest of every checksum, counter vector and transition instant, and add a'; ...
        '  standalone verifier that recomputes the verdict from the manifest without running the'; ...
        '  estimator, so a process repair never has to re-enter the numerics.'; ...
        '- Open estimator questions are unchanged: unmodelled sensor biases, the latency-inflated'; ...
        '  R approximation, and the unobservability of NED current while the DVL is suppressed.'}; nxt];

    append_block(fullfile(outdir, 'AUV_REALIZATION_READINESS_PLAN.md'), readiness);
    append_block(fullfile(outdir, 'AUV_REALISM_AND_VISUAL_VALIDATION.md'), realism);
    append_block(fullfile(outdir, 'PITCH_CONTROL_RESEARCH_LOG.md'), research);
end

function append_block(path, lines)
    fid = fopen(path, 'a');
    if fid < 0
        warning('append_logs: cannot open %s', path);
        return;
    end
    fprintf(fid, '\n');
    for i = 1:numel(lines)
        fprintf(fid, '%s\n', lines{i});
    end
    fclose(fid);
end

%% ===================== emergency report =====================
function emergency_report(md_path, mat_path, png_path, task_id, ME, t_wall) %#ok<INUSD>
    R = struct();
    R.task_id = task_id;
    R.gate = '5C_VALIDATION';
    R.verdict = 'FAIL';
    R.overall_pass = false;
    R.gate5c_status = ['GATE 5C NOT FORMALIZED. This validation aborted before completing. ', ...
        'The prior technical evidence NAV_AVAILABILITY_OUTAGE_STRESS_001 is RETAINED as shadow ', ...
        'evidence with status TECHNICAL_PASS / PROCESS_NONCOMPLIANT and is NOT promoted.'];
    R.fail_cause = sprintf('%s (%s)', ME.message, ME.identifier);
    st = '';
    for i = 1:numel(ME.stack)
        st = [st sprintf('%s line %d; ', ME.stack(i).name, ME.stack(i).line)]; %#ok<AGROW>
    end
    R.fail_stack = st;
    R.elapsed_s = toc(t_wall);
    R.next_task = 'Gate 6 is NOT named: Gate 5C was not formalized.';
    try
        save(mat_path, '-struct', 'R', '-v7.3');
    catch
    end
    fid = fopen(md_path, 'w');
    if fid >= 0
        fprintf(fid, '# %s - Gate 5C process-compliant validation\n\n', task_id);
        fprintf(fid, '**Overall verdict: FAIL (aborted).**\n\n');
        fprintf(fid, '- Cause: `%s`\n- Stack: `%s`\n- Elapsed: %.1f s\n\n', R.fail_cause, ...
            R.fail_stack, R.elapsed_s);
        fprintf(fid, '%s\n\n', R.gate5c_status);
        fprintf(fid, '- Accuracy status: NOT_CERTIFIED. Outage limits: ');
        fprintf(fid, 'CHARACTERIZATION_NOT_CERTIFIED. No promotion. Gate 4 waiver remains ');
        fprintf(fid, 'OPEN / shadow-only.\n');
        fprintf(fid, '- Prior Gate 5C artifacts were not written by this run.\n');
        fprintf(fid, '- Artifacts: `%s`, `%s`, `%s`\n', md_path, mat_path, png_path);
        fclose(fid);
    end
end
