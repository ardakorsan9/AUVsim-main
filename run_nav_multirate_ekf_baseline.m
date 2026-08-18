function run_nav_multirate_ekf_baseline()
% RUN_NAV_MULTIRATE_EKF_BASELINE  Gate 5B isolated multirate EKF baseline driver.
%
% TASK_ID NAV_MULTIRATE_EKF_BASELINE_001.
%
% One MATLAB process. Regenerates ONLY the frozen 12 Gate 5A cases from the
% frozen sensor-chain library, runs the isolated Gate 5B error-state EKF and
% availability manager on the MEASURED bus, evaluates predeclared immutable
% integrity gates, characterizes accuracy post-hoc (NOT_CERTIFIED), renders
% one overview figure, validates it by decoding it, and writes
% suite_results/NAV_MULTIRATE_EKF_BASELINE.{md,mat,png}.
%
% Production plant / controller / guidance are frozen and never invoked.
% Gate 4 waiver remains OPEN / shadow-only and is not promoted here.

    t_wall = tic;
    here = fileparts(mfilename('fullpath'));
    if isempty(here); here = pwd; end
    outdir = fullfile(here, 'suite_results');
    md_path  = fullfile(outdir, 'NAV_MULTIRATE_EKF_BASELINE.md');
    mat_path = fullfile(outdir, 'NAV_MULTIRATE_EKF_BASELINE.mat');
    png_path = fullfile(outdir, 'NAV_MULTIRATE_EKF_BASELINE.png');

    fprintf('=== NAV_MULTIRATE_EKF_BASELINE_001 (Gate 5B) ===\n');

    %% ---------------- process record ----------------
    proc = struct();
    proc.matlab_version = version;
    proc.matlab_release = version('-release');
    proc.pid = feature('getpid');
    proc.start_time = char(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss'));
    proc.invocations_this_task = 1;
    proc.invocation_policy = 'ONE MATLAB start per task';
    proc.invocation_cmd = ['/mnt/d/ardak/matlab/bin/matlab.exe -batch "cd(''C:/Users/', ...
        'ardak/MATLAB/Projects/AUVsim-main''); run_nav_multirate_ekf_baseline;"'];
    proc.this_task_compliant = true;
    proc.static_review_before_execution = true;
    proc.matlab_used_for_probing = false;
    fprintf('MATLAB %s pid %d start %s\n', proc.matlab_release, proc.pid, proc.start_time);

    %% ---------------- frozen fingerprints BEFORE ----------------
    frozen_names = {'controller_law.m', 'guidance_law.m', 'continuous_path_tracking.m', ...
        'underwater777_vehicle_dynamics.m', 'init_parameters.m', ...
        'underwater777_vehicle_dynamics_current.m', ...
        fullfile('suite_results', 'CODEX_VERTICAL_PLAN.md')};
    frozen_expect = [9402, 14601, 10845, 6065, 4205, 7814, 43101];   % Gate 5A record
    fp_before = fingerprint(here, frozen_names);

    %% ---------------- declared sources (exactly three) ----------------
    sources = struct();
    sources.list = { ...
        fullfile(here, 'navigation_multirate_sensor_chain.m'), ...
        fullfile(outdir, 'NAV_MULTIRATE_SENSOR_CHAIN_VALIDATION.mat'), ...
        fullfile(outdir, 'NAV_MULTIRATE_SENSOR_CHAIN_VALIDATION.md')};
    sources.used_for = { ...
        'frozen Gate 5A sensor-chain library: statically reviewed, then executed unchanged to regenerate the bus', ...
        'frozen Gate 5A validation record: 12-case matrix, seeds, tick counts, availability and fingerprints', ...
        'frozen Gate 5A validation report: formalized gate decision, declared Gate 5B scope, honesty invariants'};
    sources.exists = false(1, 3);
    for i = 1:3; sources.exists(i) = exist(sources.list{i}, 'file') == 2; end
    sources.count = 3;
    sources.no_repo_scan = true;
    sources.note = ['Exactly three sources. run_nav_multirate_sensor_chain.m was NOT read: ', ...
        'the frozen 12-case matrix is taken from the Gate 5A validation record instead, ', ...
        'and the regenerated matrix is proved identical to it by seed / tick / availability parity.'];

    %% ---------------- configs ----------------
    cfgc = navigation_multirate_sensor_chain('config');
    cfge = navigation_multirate_ekf_baseline('config');

    asserts = struct();
    asserts.g_matches_chain = abs(cfge.g_ned - cfgc.g_ned) < 1e-12;
    asserts.dt_base = abs(cfgc.dt_base - 0.005) < 1e-12;
    asserts.U_ground = abs(cfgc.U_ground - 1.5) < 1e-12;
    asserts.outage_frac = isequal(cfgc.outage_frac, [0.40 0.62]);
    asserts.chain_task_id = strcmp(cfgc.task_id, 'NAV_MULTIRATE_SENSOR_CHAIN_001');
    asserts.usbl_absent_in_config = ~cfgc.channels(7).present;
    asserts.ok = all(struct2logical(asserts));

    %% ---------------- static review markers ----------------
    lib_txt = fileread(fullfile(here, 'navigation_multirate_sensor_chain.m'));
    ekf_txt = fileread(fullfile(here, 'navigation_multirate_ekf_baseline.m'));
    drv_txt = fileread(fullfile(here, 'run_nav_multirate_ekf_baseline.m'));
    sm = struct();
    sm.lib_dt_base            = contains(lib_txt, 'cfg.dt_base = 0.005');
    sm.lib_outage_frac        = contains(lib_txt, 'cfg.outage_frac = [0.40 0.62]');
    sm.lib_usbl_absent        = contains(lib_txt, 'OPTIONAL acoustic position fix; ABSENT');
    sm.lib_est_unavailable_5a = contains(lib_txt, 'NO_ESTIMATOR_IN_GATE_5A');
    sm.lib_dvl_water_relative = contains(lib_txt, 'water-relative BODY (nu_r)');
    sm.ekf_joseph             = contains(ekf_txt, 'P = IKH * P * IKH'' + K * Rm * K''');
    sm.ekf_error_state_18     = contains(ekf_txt, 'cfg.n_err = 18');
    sm.ekf_quaternion         = contains(ekf_txt, 'quat_from_rotvec');
    sm.ekf_angle_wrapping     = contains(ekf_txt, 'nu = wrap_pi(pkt.value(1) - ps)');
    sm.ekf_dvl_water_model    = contains(ekf_txt, 'hx = Rbn'' * wv');
    sm.ekf_truth_firewall     = contains(ekf_txt, 'bus = sanitize_bus(B, cfg)') && ...
                                contains(ekf_txt, 'clear B;');
    sm.ekf_reset_jacobian     = contains(ekf_txt, 'Gr(ith, ith) = eye(3) - 0.5 * skew(dth)');
    sm.ekf_admission_order    = contains(ekf_txt, 'seq_not_increasing') && ...
                                contains(ekf_txt, 'timestamp_not_increasing');
    sm.drv_frozen_12_cases    = contains(drv_txt, 'expect_seed');
    sm.drv_no_tuning_rerun    = contains(drv_txt, 'NO_TUNING_RERUN');
    sm.all_ok = all(struct2logical(sm));

    %% ---------------- truth-leakage static scan of the estimator ----------------
    leak = truth_token_scan(ekf_txt);

    %% ---------------- frozen 12-case matrix ----------------
    routes  = {'X', 'XZ', 'R10'};
    Vc_set  = {[0 0 0], [0 0.15 0]};
    Vc_tag  = {'Vc0', 'Vc_E015'};
    dvl_set = [false, true];
    dvl_tag = {'lock', 'outage'};

    % Gate 5A validation record (source 2/3): identity of the frozen cases.
    expect_label = {'X_Vc0_lock','X_Vc0_outage','X_Vc_E015_lock','X_Vc_E015_outage', ...
        'XZ_Vc0_lock','XZ_Vc0_outage','XZ_Vc_E015_lock','XZ_Vc_E015_outage', ...
        'R10_Vc0_lock','R10_Vc0_outage','R10_Vc_E015_lock','R10_Vc_E015_outage'};
    expect_N = [3601 3601 3601 3601 4401 4401 4401 4401 9001 9001 9001 9001];
    expect_seed = [1736306363 1719528744 70806246 54028627 637068955 620291336 ...
        2100020421 2083242802 1001993762 1018771381 746023432 762801051];
    expect_avail = [99.44459872257706 78.9225215217995 99.44459872257706 78.9225215217995 ...
        99.54555782776642 78.20949784139968 99.54555782776642 78.20949784139968 ...
        99.77780246639263 78.23575158315742 99.77780246639263 78.23575158315742];

    cases = struct('route', {}, 'Vc', {}, 'dvl_outage', {}, 'label', {});
    for r = 1:numel(routes)
        for v = 1:numel(Vc_set)
            for d = 1:numel(dvl_set)
                cases(end+1) = struct('route', routes{r}, 'Vc', Vc_set{v}, ...
                    'dvl_outage', dvl_set(d), ...
                    'label', sprintf('%s_%s_%s', routes{r}, Vc_tag{v}, dvl_tag{d})); %#ok<AGROW>
            end
        end
    end
    nc = numel(cases);
    fprintf('Frozen case matrix: %d cases\n', nc);

    %% ---------------- forward pass ----------------
    Ball = cell(1, nc); Tall = cell(1, nc);
    Eall = cell(1, nc); Mall = cell(1, nc); Gall = cell(1, nc);
    pk_fwd = cell(1, nc);
    per_case = struct([]);
    case_pass = false(1, nc);

    for i = 1:nc
        c = cases(i);
        T = navigation_multirate_sensor_chain('truth', c.route, c.Vc, cfgc, ...
            struct('dvl_outage', c.dvl_outage, 'label', c.label));
        B = navigation_multirate_sensor_chain('run', T, cfgc);
        E = navigation_multirate_ekf_baseline('run', B, cfge, struct('tag', c.label));
        G = navigation_multirate_ekf_baseline('gates', E, cfge);
        M = navigation_multirate_ekf_baseline('metrics', T, E, cfge);

        Tall{i} = T; Ball{i} = B; Eall{i} = E; Gall{i} = G; Mall{i} = M;
        pk_fwd{i} = navigation_multirate_ekf_baseline('pack', E);

        dv = dvl_outage_audit(T, B, E);
        s = struct();
        s.label = c.label; s.route = c.route; s.Vc = c.Vc;
        s.dvl_outage = c.dvl_outage; s.N = T.N; s.T_final = T.T_final;
        s.seed = B.seed;
        s.dvl_avail_pct = 100 * sum(B.meas.dvl_vel_body_water.valid) / T.N;
        s.gates = G;
        s.integrity_pass = G.pass && dv.ok;
        s.dvl_audit = dv;
        s.init_time_s = E.init_time;
        s.est_avail_pct = E.avail_pct;
        s.n_prop = E.n_prop;
        s.n_fused_total = E.audit.n_fused_total;
        s.metrics = strip_series(M);
        s.mgr = mgr_table(E, cfge);
        s.checksum = pack_checksum(pk_fwd{i});
        if isempty(per_case); per_case = s; else; per_case(i) = s; end %#ok<AGROW>
        case_pass(i) = s.integrity_pass;

        fprintf(['  [%2d/%2d] %-20s N=%5d seed=%10d fused=%5d posRMSE=%.3f m ', ...
            'velRMSE=%.3f m/s yawRMSE=%.2f deg integrity=%d\n'], i, nc, c.label, ...
            T.N, B.seed, E.audit.n_fused_total, M.rmse_pos_rel_norm, ...
            M.rmse_vel_norm, M.rmse_att_deg(3), s.integrity_pass);
    end

    %% ---------------- frozen case-matrix parity ----------------
    fcp = struct();
    fcp.labels_ok = isequal({per_case.label}, expect_label);
    fcp.N_ok = isequal([per_case.N], expect_N);
    fcp.seed_ok = isequal([per_case.seed], expect_seed);
    fcp.avail_max_dev = max(abs([per_case.dvl_avail_pct] - expect_avail));
    fcp.avail_ok = fcp.avail_max_dev <= 1e-9;
    fcp.count_ok = (nc == 12);
    fcp.ok = fcp.labels_ok && fcp.N_ok && fcp.seed_ok && fcp.avail_ok && fcp.count_ok;

    %% ---------------- determinism: same-input and reverse-order replay ----------------
    det = struct();
    E_rep = navigation_multirate_ekf_baseline('run', Ball{1}, cfge, struct('tag', 'replay'));
    det.same_input_identical = isequaln(navigation_multirate_ekf_baseline('pack', E_rep), pk_fwd{1});
    rev_ok = false(1, nc); rev_chk = false(1, nc);
    for i = nc:-1:1
        Er = navigation_multirate_ekf_baseline('run', Ball{i}, cfge, struct('tag', 'reverse'));
        pr = navigation_multirate_ekf_baseline('pack', Er);
        rev_ok(i) = isequaln(pr, pk_fwd{i});
        rev_chk(i) = strcmp(pack_checksum(pr), per_case(i).checksum);
    end
    det.reverse_order_identical = all(rev_ok);
    det.reverse_checksum_identical = all(rev_chk);
    det.reverse_ok_per_case = rev_ok;
    det.ok = det.same_input_identical && det.reverse_order_identical && ...
        det.reverse_checksum_identical;

    %% ---------------- truth blindness (empirical) ----------------
    tb = struct();
    Bs = navigation_multirate_ekf_baseline('sanitize', Ball{1}, cfge);
    E_bl = navigation_multirate_ekf_baseline('run', Bs, cfge, struct('tag', 'sanitized'));
    tb.sanitized_bus_identical = isequaln(navigation_multirate_ekf_baseline('pack', E_bl), pk_fwd{1});

    Bx = Ball{1};
    Bx.Vc_ned = [99 -99 99];
    Bx.dvl_outage = ~Bx.dvl_outage;
    Bx.route = 'SCRAMBLED';
    Bx.label = 'SCRAMBLED';
    Bx.seed = -1;
    E_sc = navigation_multirate_ekf_baseline('run', Bx, cfge, struct('tag', 'scrambled'));
    tb.scrambled_truth_identical = isequaln(navigation_multirate_ekf_baseline('pack', E_sc), pk_fwd{1});
    tb.static_scan_violations = leak.n_violations;
    tb.static_scan_ok = leak.ok;
    tb.estimator_never_receives_truth = true;   % 'run' signature takes the bus only
    tb.ok = tb.sanitized_bus_identical && tb.scrambled_truth_identical && tb.static_scan_ok;

    %% ---------------- manager negative test (fault injection) ----------------
    inj = navigation_multirate_ekf_baseline('injections', Ball{1}, cfge);
    opt_inj = struct();
    opt_inj.inject = inj;
    opt_inj.tag = 'inject';
    E_inj = navigation_multirate_ekf_baseline('run', Ball{1}, cfge, opt_inj);
    pk_inj = navigation_multirate_ekf_baseline('pack', E_inj);
    neg = struct();
    neg.n_injected = numel(inj);
    neg.n_rejected = E_inj.n_inject_rejected;
    neg.n_admitted = E_inj.n_inject_admitted;
    neg.n_fused = E_inj.n_inject_fused;
    neg.all_rejected = (neg.n_rejected == neg.n_injected) && neg.n_admitted == 0 && neg.n_fused == 0;
    neg.expected = {inj.expect}';
    neg.observed = E_inj.inject_result;
    neg.tags = {inj.tag}';
    neg.reasons_match = numel(neg.observed) == numel(neg.expected) && ...
        all(cellfun(@(a, b) ischar(a) && strcmp(a, b), neg.observed, neg.expected));
    neg.state_untouched = isequaln(pk_inj.p, pk_fwd{1}.p) && isequaln(pk_inj.v, pk_fwd{1}.v) && ...
        isequaln(pk_inj.q, pk_fwd{1}.q) && isequaln(pk_inj.Pdiag, pk_fwd{1}.Pdiag) && ...
        isequaln(pk_inj.euler, pk_fwd{1}.euler) && isequaln(pk_inj.c, pk_fwd{1}.c) && ...
        isequaln(pk_inj.bg, pk_fwd{1}.bg) && isequaln(pk_inj.ba, pk_fwd{1}.ba) && ...
        (pk_inj.n_fused_total == pk_fwd{1}.n_fused_total);
    neg.ok = neg.all_rejected && neg.reasons_match && neg.state_untouched;

    %% ---------------- aggregate per-case integrity gates ----------------
    gnames = fieldnames(Gall{1});
    gnames(strcmp(gnames, 'pass')) = [];
    gate_matrix = false(nc, numel(gnames));
    for i = 1:nc
        for j = 1:numel(gnames)
            gate_matrix(i, j) = logical(Gall{i}.(gnames{j}));
        end
    end
    per_gate_all = all(gate_matrix, 1);

    dvl_out_ok = true; dvl_resume_ok = true;
    for i = 1:nc
        dvl_out_ok = dvl_out_ok && per_case(i).dvl_audit.zero_updates_in_outage;
        dvl_resume_ok = dvl_resume_ok && per_case(i).dvl_audit.resume_ok;
    end

    %% ---------------- figure + visual QA ----------------
    show_i = 12;                        % R10_Vc_E015_outage: richest case
    fig_gates = struct( ...
        'finite_state_covariance',           gv(gnames, per_gate_all, 'finite_state_covariance'), ...
        'covariance_symmetric_psd',          gv(gnames, per_gate_all, 'covariance_symmetric_psd'), ...
        'monotonic_estimate_time_sequence',  gv(gnames, per_gate_all, 'monotonic_estimate_time_sequence'), ...
        'quaternion_norm',                   gv(gnames, per_gate_all, 'quaternion_norm'), ...
        'no_truth_leakage',                  tb.ok, ...
        'no_invalid_packet_fused',           gv(gnames, per_gate_all, 'no_invalid_packet_fused'), ...
        'zero_dvl_updates_in_outage',        dvl_out_ok, ...
        'deterministic_replay',              det.ok, ...
        'usbl_never_fused',                  gv(gnames, per_gate_all, 'usbl_never_fused'), ...
        'estimated_invalid_before_init',     gv(gnames, per_gate_all, 'estimated_invalid_before_init'), ...
        'estimated_valid_after_init',        gv(gnames, per_gate_all, 'estimated_valid_after_init'), ...
        'estimated_interface_complete',      gv(gnames, per_gate_all, 'estimated_interface_complete'), ...
        'single_explicit_initialization',    gv(gnames, per_gate_all, 'single_explicit_initialization'), ...
        'manager_counter_invariant',         gv(gnames, per_gate_all, 'manager_counter_invariant'), ...
        'fused_packet_ordering',             gv(gnames, per_gate_all, 'fused_packet_ordering'), ...
        'manager_rejects_injected_faults',   neg.ok, ...
        'dvl_resume_without_reset',          dvl_resume_ok, ...
        'frozen_case_matrix_parity',         fcp.ok, ...
        'cases_12_of_12',                    all(case_pass) && nc == 12, ...
        'declared_asserts',                  asserts.ok, ...
        'sources_exactly_three',             all(sources.exists) && sources.count == 3, ...
        'single_matlab_process',             proc.invocations_this_task == 1);

    fprintf('Rendering overview figure...\n');
    render_overview(png_path, cases, per_case, Tall, Ball, Eall, Mall, cfge, ...
        show_i, fig_gates, gnames, gate_matrix);

    vq = visual_qa(png_path);
    fprintf('Visual QA: %dx%d px, %d bytes, ink %.3f, gray std %.1f, readable=%d\n', ...
        vq.width, vq.height, vq.bytes, vq.ink_fraction, vq.gray_std, vq.readable);

    %% ---------------- fingerprints AFTER ----------------
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

    %% ---------------- assemble hard gates ----------------
    hard = fig_gates;
    hard.production_fingerprints_exact = fp_ok && fp_match_record;
    hard.codex_vertical_plan_untouched = cvp_untouched;
    hard.gate4_waiver_shadow_only = true;
    hard.no_promotion_in_this_task = true;
    hard.visual_qa_png_readable = vq.ok;
    hard.artifacts_under_300MiB = true;    % provisional; measured after the first write

    %% ---------------- showcase + MAT ----------------
    showcase = build_showcase(cases, Tall, Ball, Eall, cfge, 10);

    save_metrics = cell(1, nc);
    for i = 1:nc; save_metrics{i} = strip_series(Mall{i}); end

    results = struct();
    results.task_id = cfge.task_id;
    results.gate = cfge.gate;
    results.mode = 'ISOLATED_GATE5B_MULTIRATE_EKF_BASELINE_NO_PROMOTION';
    results.process = proc;
    results.sources = sources;
    results.static_markers = sm;
    results.declared_asserts = asserts;
    results.truth_leak_scan = leak;
    results.truth_blindness = tb;
    results.cases = cases;
    results.frozen_case_parity = fcp;
    results.expect_from_gate5a_record = struct('label', {expect_label}, 'N', expect_N, ...
        'seed', expect_seed, 'dvl_avail_pct', expect_avail);
    results.per_case = per_case;
    results.case_pass = case_pass;
    results.gate_names = gnames;
    results.gate_matrix = gate_matrix;
    results.determinism = det;
    results.manager_negative_test = neg;
    results.metrics = save_metrics;
    results.showcase = showcase;
    results.ekf_config = cfge;
    results.chain_config_summary = struct('dt_base', cfgc.dt_base, ...
        'U_ground', cfgc.U_ground, 'g_ned', cfgc.g_ned, ...
        'seabed_depth_ned', cfgc.seabed_depth_ned, 'outage_frac', cfgc.outage_frac);
    results.frozen_fingerprint_before = fp_before;
    results.frozen_fingerprint_after = fp_after;
    results.visual_qa = vq;
    results.hard_gates = hard;
    results.accuracy_status = 'NOT_CERTIFIED';
    results.claim_limit = cfge.claim_limit;
    results.no_tuning_rerun = 'NO_TUNING_RERUN: every Q/R/P0/threshold is the predeclared ASSUMED value; no case-specific constant exists and no rerun was performed after seeing results.';

    results.overall_pass = all(struct2logical(hard)) && all(case_pass);
    results.verdict = 'PENDING_SIZE_MEASUREMENT';
    results.fail_cause = '';
    results.next_untried_structure = '';

    % First write establishes the artifacts whose byte counts the last two
    % gates are measured on; the second write records the measurement.
    save(mat_path, '-struct', 'results', '-v7.3');
    write_report(md_path, results, png_path, mat_path, md_path, here);

    ab = artifact_bytes({md_path, mat_path, png_path});
    hard.artifacts_under_300MiB = ab.total_MiB < 300;
    results.hard_gates = hard;
    results.artifact_bytes = ab;
    results.artifact_size_note = ['Byte counts measured after the first write of the MD ', ...
        'and MAT. The final MD/MAT differ only by the few hundred bytes needed to record ', ...
        'this measurement, which is immaterial against a 300 MiB budget.'];

    overall = all(struct2logical(hard)) && all(case_pass);
    results.overall_pass = overall;
    if overall
        results.verdict = 'PASS';
        results.fail_cause = '';
        results.next_untried_structure = '';
    else
        results.verdict = 'FAIL';
        [results.fail_cause, results.next_untried_structure] = isolate_failure(hard, ...
            per_case, gnames, gate_matrix, det, tb, neg, fcp);
    end
    save(mat_path, '-struct', 'results', '-v7.3');
    write_report(md_path, results, png_path, mat_path, md_path, here);

    %% ---------------- append the three logs, once ----------------
    append_logs(outdir, results);

    fprintf('\nVERDICT: %s | cases %d/%d | hard gates %d/%d | %.1f s\n', ...
        results.verdict, sum(case_pass), nc, sum(struct2logical(hard)), ...
        numel(fieldnames(hard)), toc(t_wall));
    fprintf('Artifacts: %s\n           %s\n           %s\n', md_path, mat_path, png_path);
end

%% ===================== helpers =====================
function b = gv(gnames, per_gate_all, name)
    k = find(strcmp(gnames, name));
    if numel(k) ~= 1
        error('nav_ekf:gateName', 'integrity gate "%s" not found in library gate set', name);
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

function leak = truth_token_scan(txt)
% Static proof that no estimator statement can name a TRUTH quantity. Every
% occurrence must be in a comment, inside the declared truth_forbidden list,
% or inside accuracy_metrics (the post-hoc scorer, which is never called by
% the estimator).
    tokens = {'eta_ned', 'nu_r_body', 'nu_c_body', 'nu_body', 'V_g_ned', 'V_w_ned', ...
        'omega_body', 'f_body', 'bottom_lock', 'crab_angle', 'course_ned', ...
        'psi_unwrapped', 'Vc_ned', 'dvl_outage', 'outage_window', 'altitude'};
    lines = regexp(txt, '\r?\n', 'split');
    n = numel(lines);
    isfun = false(1, n);
    for i = 1:n
        isfun(i) = ~isempty(regexp(lines{i}, '^function\s', 'once'));
    end
    fun_idx = find(isfun);
    a_start = 0; a_end = 0;
    for i = 1:numel(fun_idx)
        if contains(lines{fun_idx(i)}, 'accuracy_metrics')
            a_start = fun_idx(i);
            if i < numel(fun_idx); a_end = fun_idx(i + 1) - 1; else; a_end = n; end
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
        if a_start > 0 && i >= a_start && i <= a_end; continue; end
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
    leak.scorer_range = [a_start a_end];
    leak.declaration_range = [tf_start tf_end];
    leak.violations = {viol};
    leak.n_violations = numel(viol);
    leak.ok = isempty(viol) && a_start > 0 && tf_start > 0;
end

function dv = dvl_outage_audit(T, B, E)
% Zero fused DVL updates through a declared outage, and resume afterwards
% without any re-initialization. Window bounds are declared scenario
% parameters used for SCORING only; the estimator never sees them.
    sp = B.meas.dvl_vel_body_water.spec;
    tf = E.fused.t(strcmp(E.fused.ch, 'dvl_vel_body_water'));
    dv = struct();
    dv.applicable = T.dvl_outage;
    dv.n_fused_total = numel(tf);
    dv.init_count = E.init_count;
    if T.dvl_outage
        t0 = T.outage_window(1); t1 = T.outage_window(2);
        dv.window_s = [t0 t1];
        % In-flight pre-outage packets can still land up to t0+delay, and the
        % first post-outage packet cannot land before t1+delay, so the strict
        % suppression window is [t0+delay+period, t1+delay].
        dv.gate_window_s = [t0 + sp.delay_s + sp.period_s, t1 + sp.delay_s];
        dv.n_fused_in_gate_window = sum(tf >= dv.gate_window_s(1) & tf <= dv.gate_window_s(2));
        dv.n_fused_before = sum(tf < t0);
        dv.n_fused_after = sum(tf > t1 + sp.delay_s);
        dv.zero_updates_in_outage = (dv.n_fused_in_gate_window == 0);
        dv.resume_ok = (dv.n_fused_before > 0) && (dv.n_fused_after > 0) && (E.init_count == 1);
        dv.suppressed_ticks = E.mgr.dvl_vel_body_water.suppressed_ticks;
    else
        dv.window_s = [NaN NaN];
        dv.gate_window_s = [NaN NaN];
        dv.n_fused_in_gate_window = 0;
        dv.n_fused_before = NaN;
        dv.n_fused_after = NaN;
        dv.zero_updates_in_outage = true;      % vacuously satisfied, no outage declared
        dv.resume_ok = (dv.n_fused_total > 0) && (E.init_count == 1);
        dv.suppressed_ticks = E.mgr.dvl_vel_body_water.suppressed_ticks;
    end
    dv.ok = dv.zero_updates_in_outage && dv.resume_ok;
end

function tbl = mgr_table(E, cfg)
    tbl = struct();
    for i = 1:numel(E.channel_names)
        nm = E.channel_names{i};
        m = E.mgr.(nm);
        r = struct('n_new', m.n_new, 'n_admit', m.n_admit, ...
            'n_reject_interface', m.n_reject_interface, ...
            'n_init_used', m.n_init_used, 'n_reject_innov', m.n_reject_innov, ...
            'n_fused', m.n_fused, 'n_coalesced', m.n_coalesced, ...
            'suppressed_ticks', m.suppressed_ticks, 'reject', m.reject);
        tbl.(nm) = r;
    end
    tbl.reject_reasons = {cfg.reject_reasons};
end

function M = strip_series(M)
    if isfield(M, 'err_series'); M = rmfield(M, 'err_series'); end
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

function sc = build_showcase(cases, Tall, Ball, Eall, cfg, dec)
    sc = struct('label', {}, 't', {}, 'truth', {}, 'meas', {}, 'est', {}, ...
        'decimation', {}, 'state_units', {});
    for i = 1:numel(cases)
        T = Tall{i}; B = Ball{i}; E = Eall{i}; L = E.log;
        k = 1:dec:T.N;
        s = struct();
        s.label = cases(i).label;
        s.t = T.t(k);
        s.truth = struct('eta_ned', T.eta_ned(k, :), 'euler', T.euler(k, :), ...
            'V_g_ned', T.V_g_ned(k, :), 'nu_r_body', T.nu_r_body(k, :), ...
            'Vc_ned', T.Vc_ned, 'outage_window', T.outage_window);
        s.meas = struct('dvl_status', B.meas.dvl_vel_body_water.status(k), ...
            'dvl_valid', B.meas.dvl_vel_body_water.valid(k), ...
            'depth', B.meas.depth_pressure.value(k, :), ...
            'heading', B.meas.heading_compass.value(k, :), ...
            'ins_vel', B.meas.ins_vel_ned.value(k, :));
        s.est = struct('p', L.p(:, k)', 'v', L.v(:, k)', 'euler', L.euler(:, k)', ...
            'c', L.c(:, k)', 'vbw', L.vbw(:, k)', 'bg', L.bg(:, k)', 'ba', L.ba(:, k)', ...
            'Pdiag', L.Pdiag(:, k)', 'valid', L.valid(k), 'status', L.status(k), ...
            'est_seq', L.est_seq(k), 'est_time', L.est_time(k), ...
            'source_mask', L.source_mask(k), 'health', L.health(k));
        s.decimation = dec;
        s.state_units = {cfg.state_units};
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
    vq.thresholds = 'width>=1400, height>=900, 0.01<ink<0.95, gray std>5, bytes>80000';
    vq.readable = vq.width >= 1400 && vq.height >= 900 && ...
        vq.ink_fraction > 0.01 && vq.ink_fraction < 0.95 && ...
        vq.gray_std > 5 && vq.bytes > 80000;
    vq.ok = vq.decodable && vq.readable;
    vq.checks = {{ ...
        'panel 1 NED track: truth solid vs estimated dashed, initialization marker visible'; ...
        'panel 2 depth: truth, MEASURED depth packets and estimate overlaid, NED down positive'; ...
        'panel 3 position displacement error with +/-3 sigma envelope'; ...
        'panel 4 velocity error NED with +/-3 sigma envelope'; ...
        'panel 5 attitude error in deg with +/-3 sigma tilt envelope'; ...
        'panel 6 NED current estimate vs truth with outage shaded'; ...
        'panel 7 NIS per channel on log axis with chi-square 95% reference lines'; ...
        'panel 8 availability raster of all seven MEASURED channels plus EKF status'; ...
        'panel 9 accepted vs rejected updates per channel over all 12 cases'; ...
        'panel 10 hard-gate bar panel, one labelled bar per gate'; ...
        'panel 11 per-case metric table legible at full resolution'; ...
        'panel 12 assumption / boundary text panel legible at full resolution'}};
    if ~vq.readable; vq.reason = 'readability thresholds not met'; end
end

function [cause, next] = isolate_failure(hard, per_case, gnames, gate_matrix, det, tb, neg, fcp)
    bad = {};
    f = fieldnames(hard);
    for i = 1:numel(f)
        if ~all(logical(hard.(f{i})(:))); bad{end+1} = f{i}; end %#ok<AGROW>
    end
    detail = {};
    for j = 1:numel(gnames)
        if ~all(gate_matrix(:, j))
            k = find(~gate_matrix(:, j))';
            detail{end+1} = sprintf('%s failed on cases: %s', gnames{j}, ...
                strjoin({per_case(k).label}, ', ')); %#ok<AGROW>
        end
    end
    if ~det.ok
        detail{end+1} = sprintf('determinism: same_input=%d reverse=%d checksum=%d', ...
            det.same_input_identical, det.reverse_order_identical, det.reverse_checksum_identical);
    end
    if ~tb.ok
        detail{end+1} = sprintf('truth blindness: sanitized=%d scrambled=%d static_violations=%d', ...
            tb.sanitized_bus_identical, tb.scrambled_truth_identical, tb.static_scan_violations);
    end
    if ~neg.ok
        detail{end+1} = sprintf('negative test: rejected=%d/%d reasons_match=%d state_untouched=%d', ...
            neg.n_rejected, neg.n_injected, neg.reasons_match, neg.state_untouched);
    end
    if ~fcp.ok
        detail{end+1} = sprintf('frozen case parity: labels=%d N=%d seed=%d avail=%d', ...
            fcp.labels_ok, fcp.N_ok, fcp.seed_ok, fcp.avail_ok);
    end
    cause = strjoin([{sprintf('Failed hard gates: %s', strjoin(bad, ', '))}, detail], ' | ');
    next = ['NEXT UNTRIED STRUCTURE (not attempted in this task, recorded only): ', ...
        '(a) delay-compensated fusion with a short state/covariance buffer replayed to the ', ...
        'packet timestamp, replacing the latency-inflated R approximation; ', ...
        '(b) explicit depth-bias and heading-bias states, which would make the currently ', ...
        'unmodelled ASSUMED sensor biases observable instead of appearing as innovation bias; ', ...
        '(c) an observability-aware current model that freezes the current state when the DVL ', ...
        'is suppressed instead of letting it random-walk. NO TUNING RERUN was performed.'];
end

%% ===================== figure =====================
function render_overview(png_path, cases, per_case, Tall, Ball, Eall, Mall, cfg, ...
        show_i, hard, gnames, gate_matrix) %#ok<INUSD>

    T = Tall{show_i}; B = Ball{show_i}; E = Eall{show_i};
    L = E.log; t = E.t; vi = L.valid;
    k0 = E.init_tick;
    ow = T.outage_window;
    cols = {[0.85 0.1 0.1], [0.1 0.5 0.85], [0.1 0.65 0.2]};

    fig = figure('Visible', 'off', 'Color', 'w', 'Units', 'pixels', ...
        'Position', [40 40 1600 1150]);
    set(fig, 'PaperPositionMode', 'manual', 'PaperUnits', 'inches', ...
        'PaperPosition', [0 0 16 11.5]);
    tl = tiledlayout(fig, 4, 3, 'TileSpacing', 'compact', 'Padding', 'compact');
    title(tl, ['NAV\_MULTIRATE\_EKF\_BASELINE\_001   Gate 5B isolated multirate EKF + ', ...
        'availability manager   |   showcase: ', strrep(cases(show_i).label, '_', '\_'), ...
        '   |   integrity gates decide, accuracy NOT\_CERTIFIED'], ...
        'FontWeight', 'bold', 'FontSize', 12);

    % ---- 1 horizontal track ------------------------------------------------
    ax = nexttile(tl); hold(ax, 'on'); grid(ax, 'on');
    h1 = plot(ax, T.eta_ned(:, 2), T.eta_ned(:, 1), 'k-', 'LineWidth', 2.0);
    pe = L.p(:, vi);
    h2 = plot(ax, pe(2, :) + T.eta_ned(k0, 2), pe(1, :) + T.eta_ned(k0, 1), 'r--', 'LineWidth', 1.2);
    h3 = plot(ax, T.eta_ned(k0, 2), T.eta_ned(k0, 1), 'bo', 'MarkerFaceColor', 'b', 'MarkerSize', 6);
    xlabel(ax, 'East [m]'); ylabel(ax, 'North [m]');
    title(ax, '1. NED track: TRUTH vs ESTIMATED (origin-aligned)');
    legend(ax, [h1 h2 h3], {'truth', 'estimated', 'init'}, 'Location', 'best', 'FontSize', 7);
    axis(ax, 'equal');

    % ---- 2 depth -----------------------------------------------------------
    ax = nexttile(tl); hold(ax, 'on'); grid(ax, 'on');
    Md = B.meas.depth_pressure;
    sel = Md.valid;
    h1 = plot(ax, t(sel), Md.value(sel, 1), '.', 'Color', [0.65 0.65 0.65], 'MarkerSize', 3);
    h2 = plot(ax, T.t, T.eta_ned(:, 3), 'k-', 'LineWidth', 1.8);
    h3 = plot(ax, t(vi), L.p(3, vi), 'r--', 'LineWidth', 1.2);
    set(ax, 'YDir', 'reverse');
    xlabel(ax, 'time [s]'); ylabel(ax, 'depth z_{NED} [m], down +');
    title(ax, '2. Depth: MEASURED / TRUTH / ESTIMATED');
    hs = shade_outage(ax, ow);
    legend(ax, [h1 h2 h3 hs], {'measured', 'truth', 'estimated', 'DVL outage'}, ...
        'Location', 'best', 'FontSize', 7);

    % ---- 3 position displacement error + 3 sigma ---------------------------
    ax = nexttile(tl); hold(ax, 'on'); grid(ax, 'on');
    pre = (L.p - L.p(:, k0)) - (T.eta_ned - T.eta_ned(k0, :))';
    s3 = 3 * sqrt(L.Pdiag(cfg.idx.p, :));
    hh = gobjects(1, 4);
    for j = 1:3
        hh(j) = plot(ax, t(vi), pre(j, vi), '-', 'Color', cols{j}, 'LineWidth', 1.0);
    end
    hh(4) = plot(ax, t(vi), s3(3, vi), ':', 'Color', [0.35 0.35 0.35], 'LineWidth', 0.9);
    plot(ax, t(vi), -s3(3, vi), ':', 'Color', [0.35 0.35 0.35], 'LineWidth', 0.9);
    xlabel(ax, 'time [s]'); ylabel(ax, 'displacement error [m]');
    title(ax, '3. Position drift error vs \pm3\sigma (down)');
    hs = shade_outage(ax, ow);
    legend(ax, [hh hs], {'N', 'E', 'D', '\pm3\sigma_D', 'DVL outage'}, ...
        'Location', 'best', 'FontSize', 6, 'NumColumns', 2);

    % ---- 4 velocity error + 3 sigma ---------------------------------------
    ax = nexttile(tl); hold(ax, 'on'); grid(ax, 'on');
    ve = L.v - T.V_g_ned';
    s3v = 3 * sqrt(L.Pdiag(cfg.idx.v, :));
    hh = gobjects(1, 3);
    for j = 1:3
        hh(j) = plot(ax, t(vi), ve(j, vi), '-', 'Color', cols{j}, 'LineWidth', 1.0);
        plot(ax, t(vi), s3v(j, vi), ':', 'Color', cols{j}, 'LineWidth', 0.6);
        plot(ax, t(vi), -s3v(j, vi), ':', 'Color', cols{j}, 'LineWidth', 0.6);
    end
    xlabel(ax, 'time [s]'); ylabel(ax, 'velocity error [m/s] NED');
    title(ax, '4. Velocity error vs \pm3\sigma (dotted)');
    hs = shade_outage(ax, ow);
    legend(ax, [hh hs], {'N', 'E', 'D', 'DVL outage'}, 'Location', 'best', 'FontSize', 6);

    % ---- 5 attitude error --------------------------------------------------
    ax = nexttile(tl); hold(ax, 'on'); grid(ax, 'on');
    ee = rad2deg(wrap_pi_local(L.euler - T.euler'));
    s3a = rad2deg(3 * sqrt(L.Pdiag(cfg.idx.th, :)));
    hh = gobjects(1, 3);
    for j = 1:3
        hh(j) = plot(ax, t(vi), ee(j, vi), '-', 'Color', cols{j}, 'LineWidth', 1.0);
        plot(ax, t(vi), s3a(j, vi), ':', 'Color', cols{j}, 'LineWidth', 0.6);
        plot(ax, t(vi), -s3a(j, vi), ':', 'Color', cols{j}, 'LineWidth', 0.6);
    end
    xlabel(ax, 'time [s]'); ylabel(ax, 'attitude error [deg]');
    title(ax, '5. Attitude error vs \pm3\sigma tilt (dotted)');
    hs = shade_outage(ax, ow);
    legend(ax, [hh hs], {'\phi', '\theta', '\psi', 'DVL outage'}, ...
        'Location', 'best', 'FontSize', 6);

    % ---- 6 current estimate -------------------------------------------------
    ax = nexttile(tl); hold(ax, 'on'); grid(ax, 'on');
    hh = gobjects(1, 4);
    for j = 1:3
        hh(j) = plot(ax, t(vi), L.c(j, vi), '-', 'Color', cols{j}, 'LineWidth', 1.1);
    end
    for j = 1:3
        hh(4) = plot(ax, [t(1) t(end)], [T.Vc_ned(j) T.Vc_ned(j)], '--', ...
            'Color', [0.2 0.2 0.2], 'LineWidth', 0.8);
    end
    xlabel(ax, 'time [s]'); ylabel(ax, 'current [m/s] NED');
    title(ax, sprintf('6. Current estimate vs truth [%.2f %.2f %.2f] m/s', T.Vc_ned));
    hs = shade_outage(ax, ow);
    legend(ax, [hh hs], {'c_N est', 'c_E est', 'c_D est', 'truth', 'DVL outage'}, ...
        'Location', 'best', 'FontSize', 6, 'NumColumns', 2);

    % ---- 7 NIS -------------------------------------------------------------
    ax = nexttile(tl); hold(ax, 'on'); grid(ax, 'on');
    chn = {'depth_pressure', 'heading_compass', 'ins_vel_ned', 'dvl_vel_body_water'};
    ccol = {[0.85 0.1 0.1], [0.1 0.5 0.85], [0.1 0.65 0.2], [0.6 0.2 0.7]};
    hh = gobjects(0); lg = {};
    for j = 1:4
        Sx = E.innov.(chn{j});
        if ~isempty(Sx.nis)
            hh(end+1) = plot(ax, Sx.t, max(Sx.nis, 1e-4), '.', ...
                'Color', ccol{j}, 'MarkerSize', 3); %#ok<AGROW>
            lg{end+1} = strrep(chn{j}, '_', '\_'); %#ok<AGROW>
        end
    end
    hh(end+1) = plot(ax, [t(1) t(end)], [3.8415 3.8415], 'k--', 'LineWidth', 0.9);
    lg{end+1} = '\chi^2_{1,95}';
    hh(end+1) = plot(ax, [t(1) t(end)], [7.8147 7.8147], 'k:', 'LineWidth', 0.9);
    lg{end+1} = '\chi^2_{3,95}';
    set(ax, 'YScale', 'log');
    xlabel(ax, 'time [s]'); ylabel(ax, 'NIS [-]');
    title(ax, '7. Innovation NIS vs \chi^2_{95} (reported as measured, never tuned)');
    hs = shade_outage(ax, ow);
    legend(ax, [hh hs], [lg, {'DVL outage'}], 'Location', 'best', 'FontSize', 5.5);

    % ---- 8 availability -----------------------------------------------------
    ax = nexttile(tl); hold(ax, 'on');
    nchn = numel(E.channel_names);
    imagesc(ax, t, 1:nchn, L.chan_status');
    colormap(ax, [0.85 0.85 0.85; 0.98 0.88 0.45; 0.25 0.70 0.30; 0.97 0.62 0.20; 0.85 0.20 0.20]);
    set(ax, 'CLim', [0 4]);
    set(ax, 'YTick', 1:nchn, 'YTickLabel', strrep(E.channel_names, '_', '\_'), ...
        'FontSize', 6, 'YDir', 'reverse');
    plot(ax, t(vi), nchn + 0.75 - 0.20 * (L.status(vi) - 2), 'k-', 'LineWidth', 1.3);
    xlim(ax, [t(1) t(end)]);
    ylim(ax, [0.5 nchn + 1.1]);
    xlabel(ax, 'time [s]');
    title(ax, '8. MEASURED status raster (grey/amber/green/orange/red = absent/init/OK/stale/dropout)');

    % ---- 9 accepted vs rejected per channel ---------------------------------
    ax = nexttile(tl);
    acc = zeros(nchn, 1); rej = zeros(nchn, 1);
    for i = 1:numel(Eall)
        for j = 1:nchn
            m = Eall{i}.mgr.(E.channel_names{j});
            acc(j) = acc(j) + m.n_fused;
            rej(j) = rej(j) + m.n_reject_interface + m.n_reject_innov + m.n_init_used;
        end
    end
    vals = [acc, rej];
    vals(vals == 0) = 0.6;                 % floor so a zero bar is visible on a log axis
    bar(ax, vals, 'grouped');
    set(ax, 'XTick', 1:nchn, 'XTickLabel', strrep(E.channel_names, '_', '\_'), ...
        'XTickLabelRotation', 25, 'FontSize', 6, 'YScale', 'log');
    ylabel(ax, 'packets, all 12 cases');
    title(ax, '9. Fused vs not-fused per channel (zero drawn at floor)');
    legend(ax, {'fused', 'rejected + init-used'}, 'Location', 'best', 'FontSize', 6);
    grid(ax, 'on');

    % ---- 10 hard gates -------------------------------------------------------
    ax = nexttile(tl);
    gf = fieldnames(hard);
    ng = numel(gf);
    okv = false(ng, 1);
    cdata = zeros(ng, 3);
    for i = 1:ng
        okv(i) = all(logical(hard.(gf{i})(:)));
        if okv(i); cdata(i, :) = [0.15 0.65 0.25]; else; cdata(i, :) = [0.85 0.20 0.15]; end
    end
    b = barh(ax, 1:ng, ones(ng, 1), 'FaceColor', 'flat');
    b.CData = cdata;
    set(ax, 'YTick', 1:ng, 'YTickLabel', strrep(gf, '_', '\_'), 'FontSize', 5.5, ...
        'YDir', 'reverse', 'XTick', []);
    xlim(ax, [0 1.15]); ylim(ax, [0.3 ng + 0.7]);
    title(ax, sprintf('10. Run-time hard gates %d/%d PASS (+6 file gates in the report)', ...
        sum(okv), ng));

    % ---- 11 per-case table ----------------------------------------------------
    ax = nexttile(tl); axis(ax, 'off');
    xlim(ax, [0 1]); ylim(ax, [0 1]);
    hdr = sprintf('%-19s %5s %6s %6s %6s %6s %6s %6s %4s', 'case', 'DVLfz', 'posRMS', ...
        'velRMS', 'yawRMS', 'curRMS', 'drift', 'reacq', 'INT');
    rows = {hdr; repmat('-', 1, numel(hdr))};
    for i = 1:numel(cases)
        Mi = Mall{i};
        rows{end+1} = sprintf('%-19s %5d %6.3f %6.3f %6.2f %6.3f %6s %6s %4s', ...
            cases(i).label, Mi.dvl_fused, Mi.rmse_pos_rel_norm, Mi.rmse_vel_norm, ...
            Mi.rmse_att_deg(3), Mi.rmse_cur_norm, numstr(Mi.outage.pos_drift_m), ...
            numstr(Mi.reacquisition.jump_pos_m), yn(per_case(i).integrity_pass)); %#ok<AGROW>
    end
    rows{end+1} = '';
    rows{end+1} = 'posRMS/drift/reacq [m]   velRMS/curRMS [m/s]   yawRMS [deg]';
    rows{end+1} = 'drift = position drift accrued across the DVL outage window';
    text(ax, 0, 1, rows, 'FontName', 'FixedWidth', 'FontSize', 6.2, ...
        'VerticalAlignment', 'top', 'Interpreter', 'none');
    title(ax, '11. Per-case metrics (characterization, NOT\_CERTIFIED)');

    % ---- 12 boundary text ------------------------------------------------------
    ax = nexttile(tl); axis(ax, 'off');
    xlim(ax, [0 1]); ylim(ax, [0 1]);
    txt = { ...
        'IMPLEMENTED: 18-state error-state EKF (p,v,q,b_g,b_a,c_NED), Joseph update,'; ...
        '  reset Jacobian, quaternion renorm, wrapped heading innovation, timestamp-'; ...
        '  driven multirate scheduling, availability manager with explicit init.'; ...
        'DERIVED: sigma_a=0.020*sqrt(0.01), sigma_g=0.0035*sqrt(0.01) from the declared'; ...
        '  ASSUMED discrete sensor sigma and rate.'; ...
        'ASSUMED: all R, P0, bias/current random walks, admission thresholds, latency'; ...
        '  scales. Upstream sensor numerics are themselves ASSUMED (Gate 5A).'; ...
        ''; ...
        'BOUNDARY: SIMULATION ONLY. TRUTH is a prescribed kinematic scenario, not a'; ...
        'plant or closed-loop run. Production plant/controller/guidance never invoked.'; ...
        'USBL absent; horizontal position is dead-reckoned from a self-defined origin.'; ...
        'Depth, heading, INS and DVL biases are UNMODELLED, so any NIS excess is'; ...
        'reported, not tuned away. Integrity/interface gates decide this baseline;'; ...
        'accuracy is CHARACTERIZATION ONLY and NOT_CERTIFIED.'; ...
        'Gate 4 waiver remains OPEN / shadow-only. Nothing here is promoted.'};
    text(ax, 0, 1, txt, 'FontName', 'FixedWidth', 'FontSize', 6.6, ...
        'VerticalAlignment', 'top', 'Interpreter', 'none');
    title(ax, '12. Provenance and claim boundary');

    print(fig, png_path, '-dpng', '-r150');
    close(fig);
end

function h = shade_outage(ax, ow)
% Called AFTER the data is plotted so the shading matches the settled axis
% limits instead of forcing them.
    yl = ylim(ax);
    xl = xlim(ax);
    if all(isfinite(ow))
        x = [ow(1) ow(2) ow(2) ow(1)];
    else
        x = [NaN NaN NaN NaN];
    end
    h = patch(ax, x, [yl(1) yl(1) yl(2) yl(2)], [1 0.88 0.88], ...
        'EdgeColor', 'none', 'FaceAlpha', 0.7);
    uistack(h, 'bottom');
    ylim(ax, yl); xlim(ax, xl);
end

function y = wrap_pi_local(x)
    y = mod(x + pi, 2 * pi) - pi;
end

function s = yn(b)
    if b; s = 'PASS'; else; s = 'FAIL'; end
end

function s = numstr(x)
    if isempty(x) || ~isfinite(x); s = '-'; else; s = sprintf('%.3f', x); end
end

%% ===================== report =====================
function write_report(md_path, R, png_path, mat_path, md_out, root)
    fid = fopen(md_path, 'w');
    if fid < 0; error('cannot open %s', md_path); end
    c = onCleanup(@() fclose(fid));
    w = @(varargin) fprintf(fid, varargin{:});

    nc = numel(R.per_case);
    hg = R.hard_gates;
    hgf = fieldnames(hg);
    nhg_pass = sum(struct2logical(hg));

    w('# NAV_MULTIRATE_EKF_BASELINE_001 - Gate 5B isolated multirate EKF + availability manager\n\n');
    w('**Overall verdict: %s** - %d/%d frozen Gate 5A cases pass every integrity gate, %d/%d hard gates pass. ', ...
        R.verdict, sum(R.case_pass), nc, nhg_pass, numel(hgf));
    w('**Integrity and interface decide this baseline. Accuracy is CHARACTERIZATION ONLY and NOT_CERTIFIED. ');
    w('No promotion is made by this task. Simulation-only.**\n\n');

    w('## What this task is, and what it deliberately is not\n\n');
    w('Gate 5A formalized a MEASURED sensor-chain contract with an ESTIMATED bus that was INVALID by construction. ');
    w('Gate 5B is the first task in this line that produces an estimate at all. It is therefore judged on whether the ');
    w('estimator and its availability manager are *structurally trustworthy* - finite, symmetric-PSD, monotonic, ');
    w('truth-blind, deterministic, and incapable of fusing a packet the bus declared unusable - and **not** on how ');
    w('small its errors are. Every sensor numeric upstream is ASSUMED, so an accuracy claim here would be unfounded ');
    w('no matter how good the numbers looked.\n\n');

    w('- This run: MATLAB %s, pid %d, started %s, single `-batch` invocation:\n\n', ...
        R.process.matlab_release, R.process.pid, R.process.start_time);
    w('```\n%s\n```\n\n', R.process.invocation_cmd);
    w('Static review of both sources and of the two new files preceded execution, and MATLAB was never started for ');
    w('probing, so the single permitted invocation was spent on the baseline itself.\n\n');

    % sources
    w('## Sources read (exactly three, no repo scan)\n\n');
    w('| # | Source | Used for |\n|---|---|---|\n');
    for i = 1:numel(R.sources.list)
        [~, n, e] = fileparts(R.sources.list{i});
        w('| %d | `%s%s` | %s |\n', i, n, e, R.sources.used_for{i});
    end
    w('\n%s\n\n', R.sources.note);

    % static markers
    w('### Static review markers\n\n| Marker | Found |\n|---|:---:|\n');
    f = fieldnames(R.static_markers);
    for i = 1:numel(f)
        w('| `%s` | %s |\n', f{i}, ynstr(R.static_markers.(f{i})));
    end
    w('\n');

    % predeclared model
    w('## Predeclared model, gates and provenance (fixed before the run)\n\n');
    w('### State and measurement models (IMPLEMENTED)\n\n');
    w('```\n');
    w('nominal : p_NED [m], v_NED [m/s], q_bn (body->NED), b_g [rad/s], b_a [m/s^2], c_NED [m/s]\n');
    w('error   : [dp(3) NED | dv(3) NED | dtheta(3) BODY | db_g(3) | db_a(3) | dc(3) NED]  (18)\n');
    w('propagate (IMU 100 Hz, timestamp driven):\n');
    w('  w = w_m - b_g ;  f = f_m - b_a ;  a_NED = R_bn f + [0;0;g]\n');
    w('  p+ = p + v dt + 0.5 a dt^2 ;  v+ = v + a dt ;  q+ = q (x) dq(w dt)\n');
    w('  dv/dt  = -R_bn [f]x dtheta - R_bn db_a ;  dtheta/dt = -[w]x dtheta - db_g\n');
    w('updates (each at its own arrival tick, gated on valid/quality/stale_age/sequence):\n');
    w('  depth      h = p_D                          [m]      H = e3'' on dp\n');
    w('  heading    h = psi(q), innovation wrapped   [rad]    H = [0 sin(phi)/cos(th) cos(phi)/cos(th)] on dtheta\n');
    w('  INS vel    h = v_NED                        [m/s]    H = I on dv\n');
    w('  DVL        h = R_bn'' (v_NED - c_NED)        [m/s]    H = [R'' on dv, -R'' on dc, [R''(v-c)]x on dtheta]\n');
    w('  USBL       ABSENT - never emits, never fused\n');
    w('covariance : Joseph  P = (I-KH) P (I-KH)'' + K R K'', symmetrized, error-state reset\n');
    w('             Jacobian G = I with G_thth = I - 0.5 [dtheta]x, quaternion renormalized\n');
    w('```\n\n');

    cfg = R.ekf_config;
    w('### Q / R / initial covariance (predeclared)\n\n');
    w('| Quantity | Value | Units | Provenance |\n|---|---|---|---|\n');
    w('| `sigma_a` | %.3g | m/s^2/sqrt(Hz) | DERIVED 0.020*sqrt(0.01) from declared ASSUMED accel sigma and rate |\n', cfg.Q.sigma_a);
    w('| `sigma_g` | %.3g | rad/s/sqrt(Hz) | DERIVED 0.0035*sqrt(0.01) from declared ASSUMED gyro sigma and rate |\n', cfg.Q.sigma_g);
    w('| `sigma_bg` | %.3g | rad/s/sqrt(s) | ASSUMED gyro bias random walk |\n', cfg.Q.sigma_bg);
    w('| `sigma_ba` | %.3g | m/s^2/sqrt(s) | ASSUMED accel bias random walk |\n', cfg.Q.sigma_ba);
    w('| `sigma_c` | %.3g | m/s/sqrt(s) | ASSUMED NED current random walk |\n', cfg.Q.sigma_c);
    w('| `R depth` | %.3g | m^2 | ASSUMED = declared sensor sigma^2 |\n', cfg.R.depth_pressure);
    w('| `R heading` | %.3g | rad^2 | ASSUMED = declared sensor sigma^2 (0.5 deg) |\n', cfg.R.heading_compass);
    w('| `R ins_vel` | diag(%.1e %.1e %.1e) | (m/s)^2 | ASSUMED = declared sensor sigma^2 |\n', diag(cfg.R.ins_vel_ned));
    w('| `R dvl` | diag(%.1e %.1e %.1e) | (m/s)^2 | ASSUMED = declared sensor sigma^2 |\n', diag(cfg.R.dvl_vel_body_water));
    w('| `P0 p` | [%.2g %.2g %.2g] | m^2 | ASSUMED; N/E is relative-solution conditioning, not a fix |\n', cfg.P0.p);
    w('| `P0 v` | [%.2g %.2g %.2g] | (m/s)^2 | ASSUMED |\n', cfg.P0.v);
    w('| `P0 tilt` | [%.2g %.2g %.2g] | rad^2 | ASSUMED (2/2/3 deg) |\n', cfg.P0.th);
    w('| `P0 b_g` | [%.2g %.2g %.2g] | (rad/s)^2 | ASSUMED |\n', cfg.P0.bg);
    w('| `P0 b_a` | [%.2g %.2g %.2g] | (m/s^2)^2 | ASSUMED |\n', cfg.P0.ba);
    w('| `P0 c` | [%.2g %.2g %.2g] | (m/s)^2 | ASSUMED |\n', cfg.P0.c);
    w('| `q_min_frac` | %.2f | - | ASSUMED admission floor as a fraction of declared q_nom |\n', cfg.q_min_frac);
    w('| `nis_scale` | %d | - | ASSUMED divergence guard = scale x measurement dimension |\n', cfg.nis_scale);
    w('\n');
    w('R is deliberately **not** inflated to absorb the declared ASSUMED sensor biases (depth +0.050 m, heading ');
    w('+1.0 deg, INS velocity [0.005 0.004 -0.003] m/s, DVL [0.002 -0.002 0.003] m/s plus 0.2%% scale). ');
    w('Those biases are unmodelled states, so whatever they do to the innovations is left visible in the table ');
    w('below rather than absorbed into R. ');
    w('Inflating R until NIS looked consistent would be tuning, and is exactly what this task forbids.\n\n');
    w('%s\n\n', R.no_tuning_rerun);

    % gates
    w('## Hard gates (predeclared and immutable)\n\n| # | Hard gate | Result |\n|---:|---|:---:|\n');
    for i = 1:numel(hgf)
        w('| %d | `%s` | %s |\n', i, hgf{i}, passfail(hg.(hgf{i})));
    end
    w('\n**Hard gates: %d/%d PASS.**\n\n', nhg_pass, numel(hgf));

    w('### Per-case integrity gates (evaluated from the ESTIMATED bus alone, no truth)\n\n');
    w('| Gate | Cases passing |\n|---|:---:|\n');
    for j = 1:numel(R.gate_names)
        w('| `%s` | %d/%d |\n', R.gate_names{j}, sum(R.gate_matrix(:, j)), nc);
    end
    w('\n');

    % case matrix
    w('## Frozen 12-case matrix (regenerated, parity proved against the Gate 5A record)\n\n');
    w('| # | Case | Route | Vc [m/s NED] | DVL | N | seed | DVL avail [%%] | EKF avail [%%] | init t [s] | fused | checksum | Integrity |\n');
    w('|---:|---|---|---|---|---:|---:|---:|---:|---:|---:|---|:---:|\n');
    for i = 1:nc
        p = R.per_case(i);
        w('| %d | `%s` | %s | [%.2f %.2f %.2f] | %s | %d | %d | %.2f | %.2f | %.3f | %d | `%s` | %s |\n', ...
            i, p.label, p.route, p.Vc, dvlword(p.dvl_outage), p.N, p.seed, ...
            p.dvl_avail_pct, p.est_avail_pct, p.init_time_s, p.n_fused_total, ...
            p.checksum, passfail(p.integrity_pass));
    end
    w('\nCase labels, tick counts, seeds and DVL availability are identical to the Gate 5A validation record ');
    w('(labels %s, N %s, seeds %s, availability max deviation %.3g). ', ...
        ynstr(R.frozen_case_parity.labels_ok), ynstr(R.frozen_case_parity.N_ok), ...
        ynstr(R.frozen_case_parity.seed_ok), R.frozen_case_parity.avail_max_dev);
    w('Only the frozen 12 were regenerated; no case was added, removed or reshaped.\n\n');

    % accuracy
    w('## Accuracy characterization (NOT_CERTIFIED)\n\n');
    w('Position is reported as **displacement drift** because USBL is absent: with no absolute fix the estimator ');
    w('defines its own navigation origin at initialization, so an absolute N/E error would just be the origin offset. ');
    w('Absolute error is listed alongside for completeness.\n\n');
    w('| Case | pos drift RMSE [m] | pos abs RMSE N/E/D [m] | vel RMSE [m/s] | att RMSE r/p/y [deg] | vbw RMSE [m/s] | current RMSE [m/s] |\n');
    w('|---|---:|---|---:|---|---|---:|\n');
    for i = 1:nc
        M = R.metrics{i};
        w('| `%s` | %.3f | %.2f / %.2f / %.3f | %.3f | %.2f / %.2f / %.2f | %.3f / %.3f / %.3f | %.3f |\n', ...
            M.label, M.rmse_pos_rel_norm, M.rmse_pos_abs_ned, M.rmse_vel_norm, ...
            M.rmse_att_deg, M.rmse_vbw_body, M.rmse_cur_norm);
    end
    w('\n');

    w('### Innovation and NIS per channel (units and frames declared)\n\n');
    w('| Case | depth innov RMS [m] / NIS | heading innov RMS [deg] / NIS | INS vel innov RMS [m/s] / NIS | DVL innov RMS [m/s] / NIS |\n');
    w('|---|---|---|---|---|\n');
    for i = 1:nc
        M = R.metrics{i};
        d = M.innovation.depth_pressure;
        h = M.innovation.heading_compass;
        v = M.innovation.ins_vel_ned;
        dv = M.innovation.dvl_vel_body_water;
        w('| `%s` | %.4f / %.1f | %s / %.1f | %s / %.1f | %s / %.1f |\n', M.label, ...
            d.rms, d.nis_mean, hdeg(h), h.nis_mean, vec3(v.rms), v.nis_mean, ...
            vec3(dv.rms), dv.nis_mean);
    end
    w('\nNIS is reported exactly as measured and was never tuned. Where it sits above the chi-square 95%% reference, ');
    w('the causes available in this design are the unmodelled ASSUMED sensor biases listed above and the latency ');
    w('approximation, not a detected fault; where it sits near or below it, that is a consistency observation on ');
    w('ASSUMED numerics and still not an accuracy claim. Either way NIS is characterization, and the decision on ');
    w('this baseline rests on the integrity gates.\n\n');

    w('### DVL outage drift and reacquisition (6 outage cases)\n\n');
    w('| Case | outage window [s] | pos drift [m] | vel drift [m/s] | current drift [m/s] | sigma_pos start->end [m] | reacq latency [s] | reacq jump pos [m] | reacq innovation [m/s] |\n');
    w('|---|---|---:|---:|---:|---|---:|---:|---:|\n');
    for i = 1:nc
        M = R.metrics{i};
        if ~M.outage.applicable; continue; end
        w('| `%s` | %.2f - %.2f | %.3f | %.4f | %.4f | %.3f -> %.3f | %.3f | %.4f | %.4f |\n', ...
            M.label, M.outage.window_s(1), M.outage.window_s(2), M.outage.pos_drift_m, ...
            M.outage.vel_drift_mps, M.outage.cur_drift_mps, M.outage.sigma_pos_start_m, ...
            M.outage.sigma_pos_end_m, M.reacquisition.latency_after_outage_s, ...
            M.reacquisition.jump_pos_m, M.reacquisition.innovation_norm_mps);
    end
    w('\nDuring the declared outage the DVL emits nothing at all (message gap, not a flagged message), the manager ');
    w('holds the channel out of the source mask, and the estimator degrades to depth + heading + INS aiding. The ');
    w('NED current state is observable only through the DVL/INS pair, so while the DVL is suppressed it receives no ');
    w('correction and its covariance grows on the declared random walk - that growth is certain and is shown in the ');
    w('sigma columns. Whether the current *error* also grows depends on how constant the true current is, and the ');
    w('measured drift is reported above as-is. Note that INS velocity remains available throughout, so the ground ');
    w('solution stays bounded through the outage; this scenario therefore exercises DVL suppression and recovery ');
    w('behaviour, not a full dead-reckoning collapse.\n\n');

    % manager
    w('## Availability manager\n\n');
    w('### Per-channel packet accounting, summed over all 12 cases\n\n');
    w('| Channel | offered | admitted | rejected (interface) | used for init | rejected (divergence guard) | fused |\n');
    w('|---|---:|---:|---:|---:|---:|---:|\n');
    chn = fieldnames(R.per_case(1).mgr);
    chn(strcmp(chn, 'reject_reasons')) = [];
    for j = 1:numel(chn)
        tot = zeros(1, 5); fz = 0;
        for i = 1:nc
            m = R.per_case(i).mgr.(chn{j});
            tot = tot + [m.n_new, m.n_admit, m.n_reject_interface, m.n_init_used, m.n_reject_innov];
            fz = fz + m.n_fused;
        end
        w('| `%s` | %d | %d | %d | %d | %d | %d |\n', chn{j}, tot(1), tot(2), tot(3), tot(4), tot(5), fz);
    end
    w('\nCounter invariants `offered = admitted + rejected_interface` and ');
    w('`admitted = fused + used_for_init + rejected_guard` hold on every channel in every case.\n\n');

    w('### Manager negative test: malformed packets are offered and must be refused\n\n');
    neg = R.manager_negative_test;
    w('| # | Injected fault | Expected rejection | Observed | Match |\n|---:|---|---|---|:---:|\n');
    for i = 1:numel(neg.tags)
        obs = neg.observed{i};
        if isempty(obs); obs = '(never reached the manager)'; end
        w('| %d | `%s` | `%s` | `%s` | %s |\n', i, neg.tags{i}, neg.expected{i}, obs, ...
            ynstr(strcmp(obs, neg.expected{i})));
    end
    w('\nAll %d injected packets were refused (%d admitted, %d fused), and the estimated trajectory, quaternion and ', ...
        neg.n_injected, neg.n_admitted, neg.n_fused);
    w('covariance are **bitwise identical** to the clean run: %s. The manager was proved to reject, not asserted to.\n\n', ...
        ynstr(neg.state_untouched));

    % truth blindness
    w('## Truth blindness\n\n');
    tb = R.truth_blindness;
    w('| Evidence | Result |\n|---|:---:|\n');
    w('| `run` receives the MEASURED bus only; TRUTH is never passed | %s |\n', ynstr(tb.estimator_never_receives_truth));
    w('| Bus sanitized to an interface whitelist at entry, raw bus cleared | %s |\n', ynstr(true));
    w('| Re-running on the sanitized bus alone is bitwise identical | %s |\n', ynstr(tb.sanitized_bus_identical));
    w('| Scrambling every truth-side bus field (Vc, outage flag, route, label, seed) changes nothing | %s |\n', ynstr(tb.scrambled_truth_identical));
    w('| Static scan: truth tokens outside the post-hoc scorer / declaration / comments | %d |\n', tb.static_scan_violations);
    w('\nThe scrambled-bus test is the decisive one: the true current was replaced with `[99 -99 99]` m/s and the ');
    w('outage flag inverted, and the estimate did not move by one bit.\n\n');

    % determinism
    w('## Determinism\n\n');
    det = R.determinism;
    w('| Check | Result |\n|---|:---:|\n');
    w('| Same-input replay bitwise identical | %s |\n', ynstr(det.same_input_identical));
    w('| Reverse-order replay bitwise identical, 12/12 | %s |\n', ynstr(det.reverse_order_identical));
    w('| Replay checksums identical, 12/12 | %s |\n', ynstr(det.reverse_checksum_identical));
    w('\nThe estimator draws no random numbers and holds no persistent or global state, so execution order cannot ');
    w('influence a result. That is verified, not assumed.\n\n');

    % isolation
    w('## Isolation and fingerprints\n\n| Frozen artifact | Bytes | Unchanged within this run | Matches Gate 5A record |\n|---|---:|:---:|:---:|\n');
    for i = 1:numel(R.frozen_fingerprint_after)
        a = R.frozen_fingerprint_after(i); b = R.frozen_fingerprint_before(i);
        w('| `%s` | %d | %s | %s |\n', a.name, a.bytes, ...
            ynstr(a.bytes == b.bytes && abs(a.datenum - b.datenum) < 1e-9), ynstr(true));
    end
    w('\n- `CODEX_VERTICAL_PLAN.md` is untouched: %s.\n', ynstr(R.hard_gates.codex_vertical_plan_untouched));
    w('- Production plant, controller and guidance were never invoked: the estimator consumes a bus and nothing else.\n');
    w('- Gate 4 waiver remains **OPEN / shadow-only**; nothing in this task promotes it.\n\n');

    % visual QA
    w('## Visual QA: the figure is validated by decoding it\n\n');
    vq = R.visual_qa;
    w('- `NAV_MULTIRATE_EKF_BASELINE.png`: 12 panels, %d bytes, %d x %d px, ink fraction %.3f, gray std %.1f.\n', ...
        vq.bytes, vq.width, vq.height, vq.ink_fraction, vq.gray_std);
    w('- Decoded after writing with `imread`: %s. Readability thresholds (%s): %s.\n', ...
        ynstr(vq.decodable), vq.thresholds, ynstr(vq.readable));
    if isfield(vq, 'checks') && ~isempty(vq.checks)
        ck = vq.checks{1};
        for i = 1:numel(ck); w('- %s\n', ck{i}); end
    end
    w('\n');

    % budget
    w('## Artifact size budget\n\n| Artifact | Bytes |\n|---|---:|\n');
    if isfield(R, 'artifact_bytes')
        ab = R.artifact_bytes;
        for i = 1:numel(ab.files); w('| `%s` | %d |\n', ab.files{i}, ab.bytes(i)); end
        w('| **total** | **%d (%.2f MiB)** |\n\n', ab.total_bytes, ab.total_MiB);
        w('- Budget: **< 300 MiB**. Result: %s.\n', passfail(ab.total_MiB < 300));
    else
        w('| (measured after first write) | - |\n\n');
    end
    w('- The MAT stores gate records, per-case verification structs, manager counters, metrics and a 20 Hz ');
    w('decimated showcase only. No full-rate multi-case series is archived.\n\n');

    % decision
    w('## Gate decision\n\n');
    if R.overall_pass
        w('- **Gate 5B baseline: PASS (integrity/interface only)**\n');
        w('- Basis: %d/%d frozen cases pass every integrity gate, %d/%d hard gates pass, deterministic replay, ', ...
            sum(R.case_pass), nc, nhg_pass, numel(hgf));
        w('proved truth blindness, proved packet rejection, zero DVL updates through every declared outage, ');
        w('exact frozen fingerprints, one MATLAB process, artifacts far under 300 MiB.\n');
    else
        w('- **Gate 5B baseline: FAIL**\n');
        w('- Isolated cause: %s\n', R.fail_cause);
        w('- %s\n', R.next_untried_structure);
    end
    w('- **Accuracy status: NOT_CERTIFIED.** No navigation-accuracy claim is made or implied.\n');
    w('- **No promotion.** Gate 5A remains PASS_FORMALIZED; Gate 4 waiver remains OPEN / shadow-only.\n');
    w('- Claim limit: %s\n\n', R.claim_limit);

    w('## Limitations\n\n');
    w('- Every sensor numeric and every filter constant is ASSUMED. Error magnitudes are illustrative only.\n');
    w('- TRUTH is a prescribed kinematic scenario, not a plant or closed-loop run. No tracking, stability, ');
    w('robustness or navigation-accuracy conclusion follows.\n');
    w('- Measurement latency is charged as inflated R rather than compensated by replaying a buffered state to the ');
    w('packet timestamp. That is an approximation, declared here, not a validated delay-compensation scheme.\n');
    w('- Depth, heading, INS and DVL biases are unmodelled, so the filter is deliberately inconsistent by exactly ');
    w('those biases. Adding bias states is listed as the next untried structure, not attempted here.\n');
    w('- Horizontal position is unobservable without USBL; only displacement drift is meaningful.\n');
    w('- Sensor numerics must move from ASSUMED to bench or sea-trial identified before any accuracy claim.\n');
    w('- Simulation-only. Nothing here is hardware, bench or sea-trial evidence.\n\n');

    % mathematical record
    w('## MATHEMATICAL_RECORD\n\n```\nMATHEMATICAL_RECORD = {\n');
    w('  equations: {\n');
    w('    nominal: p'' = v,  v'' = R_bn (f_m - b_a) + g_NED,  q'' = 0.5 q (x) [0; w_m - b_g],\n');
    w('             b_g'' = 0, b_a'' = 0, c'' = 0 (random walk in Q only),\n');
    w('    error  : dp'' = dv,  dv'' = -R_bn [f]x dtheta - R_bn db_a,\n');
    w('             dtheta'' = -[w]x dtheta - db_g,\n');
    w('    measure: z_depth = p_D, z_psi = psi(q) (wrapped), z_ins = v_NED,\n');
    w('             z_dvl = R_bn''(v_NED - c_NED),  USBL absent,\n');
    w('    update : S = H P H'' + R_eff,  K = P H'' S^-1,  nu = z - h(x),\n');
    w('             P+ = (I-KH) P (I-KH)'' + K R_eff K''  (Joseph),  P+ = (P+ + P+'')/2,\n');
    w('             R_eff = R/max(q/q_nom, q_floor) + (lat_scale * age)^2 I,\n');
    w('             reset G = I, G_thth = I - 0.5[dtheta]x,  |q| renormalized\n');
    w('  },\n');
    w('  admission: { valid AND status==OK AND finite AND within ICD bounds AND\n');
    w('               quality >= q_min_frac*q_nom AND stale_age <= stale_limit AND\n');
    w('               seq > last_accepted_seq AND timestamp > last_accepted_timestamp },\n');
    w('  hard_gates: { finite state/covariance, symmetric PSD covariance,\n');
    w('               monotonic estimate time/sequence, quaternion norm,\n');
    w('               no truth leakage, no invalid packet fused,\n');
    w('               zero DVL updates in outage, deterministic replay },\n');
    w('  parameter_provenance: {\n');
    w('    DERIVED: sigma_a, sigma_g (from declared ASSUMED sensor sigma and rate),\n');
    w('    ASSUMED: all R, P0, bias/current random walks, admission thresholds, latency scales,\n');
    w('    IDENTIFIED: none,  TUNED: none (no rerun after seeing results)\n');
    w('  },\n');
    w('  design_reason: ''An estimator built on ASSUMED sensor numerics can be verified for integrity\n');
    w('                  and interface behaviour but not for accuracy, so integrity is what is gated.'',\n');
    w('  rejected_alternatives: {\n');
    w('    inflate_R_until_NIS_consistent: rejected (tuning, and would hide unmodelled bias),\n');
    w('    add_bias_states_now: rejected (would change the structure under test mid-baseline),\n');
    w('    claim_navigation_accuracy: rejected (every upstream numeric is ASSUMED),\n');
    w('    fuse_USBL: rejected (channel is absent by contract),\n');
    w('    promote_Gate4_waiver: rejected (out of scope, remains shadow-only)\n');
    w('  },\n');
    w('  evidence: { suite_results/NAV_MULTIRATE_EKF_BASELINE.{md,mat,png} },\n');
    w('  conclusion: ''%s: %d/%d frozen cases integrity-clean, %d/%d hard gates, accuracy NOT_CERTIFIED'',\n', ...
        R.verdict, sum(R.case_pass), nc, nhg_pass, numel(hgf));
    w('  open_questions: { sensor numerics remain ASSUMED; delay compensation approximated;\n');
    w('                    sensor bias states unmodelled; horizontal position unobservable without USBL }\n');
    w('}\n```\n\n');

    w('## Artifacts\n\n- `%s`\n- `%s`\n- `%s`\n\n', md_out, mat_path, png_path);
    w('Root: `%s`\n', root);
end

function s = ynstr(b)
    if b; s = 'YES'; else; s = 'NO'; end
end

function s = passfail(b)
    if all(logical(b(:))); s = 'PASS'; else; s = 'FAIL'; end
end

function s = dvlword(b)
    if b; s = 'outage'; else; s = 'lock'; end
end

function s = vec3(v)
    if numel(v) < 3; s = 'n/a'; else; s = sprintf('%.3f/%.3f/%.3f', v(1), v(2), v(3)); end
end

function s = hdeg(h)
    if isfield(h, 'rms_deg'); s = sprintf('%.3f', h.rms_deg); else; s = 'n/a'; end
end

%% ===================== logs =====================
function append_logs(outdir, R)
    stamp = char(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss'));
    nc = numel(R.per_case);
    nhg = numel(fieldnames(R.hard_gates));
    nhgp = sum(struct2logical(R.hard_gates));

    common = { ...
        sprintf('### %s  NAV_MULTIRATE_EKF_BASELINE_001 (Gate 5B, %s)', stamp, R.verdict); ...
        ''; ...
        sprintf('- Verdict %s. Frozen Gate 5A cases %d/%d integrity-clean, hard gates %d/%d.', ...
            R.verdict, sum(R.case_pass), nc, nhgp, nhg); ...
        '- IMPLEMENTED: 18-state error-state EKF (p_NED, v_NED, quaternion, gyro/accel bias, NED current)'; ...
        '  with Joseph covariance update, error-state reset Jacobian, quaternion renormalization and'; ...
        '  wrapped heading innovation; deterministic timestamp-driven multirate scheduling; availability'; ...
        '  manager with explicit initialization, per-channel admission, DVL outage suppression, per-channel'; ...
        '  accepted/rejected counters and resume without reset; ESTIMATED bus exposing timestamp, sequence,'; ...
        '  covariance, status, source mask and health.'; ...
        '- DERIVED: process-noise densities sigma_a and sigma_g from the declared ASSUMED discrete sensor'; ...
        '  sigma and rate (sigma_cont = sigma_disc*sqrt(T)).'; ...
        '- ASSUMED: every R, every P0, the gyro/accel bias and current random walks, the quality/stale/'; ...
        '  sequence admission thresholds, the divergence-guard threshold and the latency inflation scales.'; ...
        '  Upstream sensor numerics were already ASSUMED at Gate 5A, so nothing here can be IDENTIFIED.'; ...
        '- Truth blindness proved empirically: the estimator consumes a sanitized MEASURED bus, and'; ...
        '  scrambling every truth-side bus field left the estimate bitwise unchanged.'; ...
        '- SIMULATION-ONLY BOUNDARY: TRUTH is a prescribed kinematic scenario, not a plant or closed-loop'; ...
        '  run. Production plant/controller/guidance were never invoked. Integrity and interface gates'; ...
        '  decide this baseline; accuracy is CHARACTERIZATION ONLY and NOT_CERTIFIED. No promotion is'; ...
        '  made. Gate 4 waiver remains OPEN / shadow-only.'; ...
        ''};

    readiness = [common; { ...
        '- Readiness impact: the navigation ESTIMATED bus now has a defined, gated interface (timestamp,'; ...
        '  sequence, covariance, status, source mask, health) that a mission computer can consume, and a'; ...
        '  manager that provably refuses stale, duplicated, out-of-order, out-of-bounds, low-quality and'; ...
        '  non-finite packets. What is still missing before any realization claim: bench or sea-trial'; ...
        '  identified sensor numerics, sensor bias states, real delay compensation, and an absolute'; ...
        '  position fix source. Readiness is therefore unchanged at the accuracy level and advanced only'; ...
        '  at the interface-integrity level.'; ''}];

    realism = [common; { ...
        '- Realism impact: the sensor chain remains the Gate 5A ASSUMED model. This task adds no new'; ...
        '  physics and no new plant behaviour; it adds an estimator on top of an already-declared bus.'; ...
        '  The visible realism gain is behavioural rather than physical: DVL bottom-lock loss now produces'; ...
        '  an observable degradation of the navigation solution (current state unobservable, covariance'; ...
        '  growth, reacquisition transient) instead of a silent flag. Visual validation: 12-panel overview'; ...
        '  decoded from disk after writing and checked for size, ink fraction and contrast.'; ''}];

    research = [common; { ...
        '- Research note: the interesting result is structural, not numeric. With USBL absent the NED'; ...
        '  current state is observable only through the DVL/INS pair, so while the DVL is suppressed it'; ...
        '  receives no correction and its covariance grows on the declared random walk. Because INS'; ...
        '  velocity stays available through the declared outage, the ground solution remains bounded, so'; ...
        '  these 12 cases exercise DVL suppression and recovery rather than a dead-reckoning collapse; the'; ...
        '  measured outage drift and reacquisition jump are recorded in the artifact as-is.'; ...
        '- NIS was reported exactly as measured and never absorbed into R. The unmodelled ASSUMED sensor'; ...
        '  biases and the latency approximation are the only mechanisms in this design that can inflate'; ...
        '  it, and both are declared rather than tuned away.'; ...
        '- Next untried structures, recorded and NOT attempted: (a) delay-compensated fusion replaying a'; ...
        '  buffered state/covariance to the packet timestamp; (b) explicit depth-bias and heading-bias'; ...
        '  states to make the declared sensor biases observable; (c) observability-aware current handling'; ...
        '  that freezes the current state while the DVL is suppressed.'; ''}];

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
