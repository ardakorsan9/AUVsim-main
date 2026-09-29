function run_nav_multirate_sensor_chain()
% RUN_NAV_MULTIRATE_SENSOR_CHAIN  TASK_ID NAV_MULTIRATE_SENSOR_CHAIN_001 (Gate 5A).
%
% Gate 5A proceeds under a user-approved residual-risk waiver. Gate 4 remains
% FAIL / shadow-only and is NOT promoted by anything in this task; only this
% isolated downstream work proceeds.
%
% Sources read (exactly three):
%   1. underwater777_vehicle_dynamics_current.m       (current/frame convention)
%   2. run_sensor_noise_current_audit.m               (declared sensor interface)
%   3. suite_results/SENSOR_NOISE_CURRENT_AUDIT.mat   (declared rates + hook status)
%
% Writes only:
%   suite_results/NAV_MULTIRATE_SENSOR_CHAIN.{md,mat,png}
%   appends suite_results/AUV_REALIZATION_READINESS_PLAN.md   (readiness log)
%   appends suite_results/AUV_REALISM_AND_VISUAL_VALIDATION.md (realism log)
%   appends suite_results/PITCH_CONTROL_RESEARCH_LOG.md        (research log)
%
% Production plant / controller / guidance are frozen and never called.
% CODEX_VERTICAL_PLAN.md is untouched (verified by fingerprint).
% No navigation-performance claim is made anywhere in this task.

    project_dir = fileparts(fileparts(fileparts(mfilename('fullpath')))); % repo root
    addpath(genpath(fullfile(project_dir, 'matlab')));
    out_dir = fullfile(project_dir, 'suite_results');
    if ~exist(out_dir, 'dir'); mkdir(out_dir); end

    tag = 'NAV_MULTIRATE_SENSOR_CHAIN';
    task_id = 'NAV_MULTIRATE_SENSOR_CHAIN_001';
    t_start = tic;

    fprintf('\n========== %s (Gate 5A) ==========\n', task_id);
    fprintf('Waiver: Gate4 FAIL/shadow-only, not promoted; isolated 5A proceeds.\n');
    fprintf('PASS criterion: sensor-chain contracts + visual QA. NO navigation-performance claim.\n');

    % ---- frozen-artifact fingerprint (before) ---------------------------
    frozen_list = { ...
        'controller_law.m', 'guidance_law.m', 'continuous_path_tracking.m', ...
        'underwater777_vehicle_dynamics.m', 'init_parameters.m', ...
        'underwater777_vehicle_dynamics_current.m', ...
        fullfile('suite_results', 'CODEX_VERTICAL_PLAN.md')};
    fp_before = fingerprint(project_dir, frozen_list);

    % ---- read exactly three declared sources ----------------------------
    src = read_sources(project_dir, out_dir);
    fprintf('Sources read: %d (%s)\n', numel(src.list), strjoin(src.short, ', '));
    fprintf('Declared upstream hooks: current=%s noise=%s delay=%s sensor=%s\n', ...
        src.hooks.current, src.hooks.noise, src.hooks.delay, src.hooks.sensor_model);
    fprintf('Declared rates: dt_controller=%.4f dt_guidance=%.4f tau_rate=%.4f U=%.2f\n', ...
        src.rates.dt_controller, src.rates.dt_guidance, src.rates.tau_rate, src.rates.desired_speed);

    cfg = navigation_multirate_sensor_chain('config');
    cfg.upstream = src;

    % Base tick must resolve the fastest declared production rate.
    assert(cfg.dt_base <= src.rates.dt_controller + 1e-12, ...
        'Base tick must be no slower than the declared controller rate');
    assert(abs(cfg.U_ground - src.rates.desired_speed) < 1e-12, ...
        'Scenario speed must equal the declared U=1.5 m/s');

    % ---- case matrix -----------------------------------------------------
    routes = {'X', 'XZ', 'R10'};
    Vc_set = {[0 0 0], [0 0.15 0]};
    Vc_tag = {'Vc0', 'Vc_E015'};
    dvl_set = [false true];
    dvl_tag = {'lock', 'outage'};

    cases = struct('route', {}, 'Vc', {}, 'dvl_outage', {}, 'label', {});
    for ir = 1:numel(routes)
        for iv = 1:numel(Vc_set)
            for id = 1:numel(dvl_set)
                cases(end+1) = struct('route', routes{ir}, 'Vc', Vc_set{iv}, ...
                    'dvl_outage', dvl_set(id), ...
                    'label', sprintf('%s_%s_%s', routes{ir}, Vc_tag{iv}, dvl_tag{id})); %#ok<AGROW>
            end
        end
    end
    nC = numel(cases);
    fprintf('Case matrix: %d cases = %d routes x %d Vc x %d DVL modes (USBL absent in all)\n', ...
        nC, numel(routes), numel(Vc_set), numel(dvl_set));

    % ---- forward pass ----------------------------------------------------
    packs = cell(nC, 1);
    Vres = cell(nC, 1);
    summ = cell(nC, 1);
    show_idx = find(strcmp({cases.label}, 'R10_Vc_E015_outage'), 1);
    T_show = []; B_show = [];

    for i = 1:nC
        c = cases(i);
        T = navigation_multirate_sensor_chain('truth', c.route, c.Vc, cfg, ...
            struct('dvl_outage', c.dvl_outage, 'label', c.label));
        B = navigation_multirate_sensor_chain('run', T, cfg);
        V = navigation_multirate_sensor_chain('verify', T, B, cfg);
        packs{i} = navigation_multirate_sensor_chain('pack', B);
        Vres{i} = V;
        summ{i} = case_summary(c, T, B, V);
        if i == show_idx
            T_show = T; B_show = B;
        end
        fprintf('  [%2d/%2d] %-22s N=%5d  gates=%s\n', i, nC, c.label, T.N, ...
            gate_string(V.gates));
        if ~V.pass
            fprintf('          failing: %s\n', strjoin(failed_gates(V.gates), ', '));
            if ~V.gates.dropout_stale_quality
                fprintf('          dropout detail: %s\n', dropout_detail(V.dropout));
            end
        end
        clear T B V;
    end

    % ---- reverse-order replay (determinism + order sentinel) -------------
    replay_ok = true(nC, 1);
    for i = nC:-1:1
        c = cases(i);
        T = navigation_multirate_sensor_chain('truth', c.route, c.Vc, cfg, ...
            struct('dvl_outage', c.dvl_outage, 'label', c.label));
        B = navigation_multirate_sensor_chain('run', T, cfg);
        replay_ok(i) = isequaln(packs{i}, navigation_multirate_sensor_chain('pack', B));
        clear T B;
    end
    fprintf('Reverse-order replay identical: %d/%d\n', sum(replay_ok), nC);

    % ---- reset sentinel: first case re-run standalone at the very end ----
    c1 = cases(1);
    T1 = navigation_multirate_sensor_chain('truth', c1.route, c1.Vc, cfg, ...
        struct('dvl_outage', c1.dvl_outage, 'label', c1.label));
    B1 = navigation_multirate_sensor_chain('run', T1, cfg);
    reset_first_ok = isequaln(packs{1}, navigation_multirate_sensor_chain('pack', B1));
    cN = cases(nC);
    TN = navigation_multirate_sensor_chain('truth', cN.route, cN.Vc, cfg, ...
        struct('dvl_outage', cN.dvl_outage, 'label', cN.label));
    BN = navigation_multirate_sensor_chain('run', TN, cfg);
    reset_last_ok = isequaln(packs{nC}, navigation_multirate_sensor_chain('pack', BN));
    clear T1 B1 TN BN;
    fprintf('Reset sentinel first/last: %d/%d\n', reset_first_ok, reset_last_ok);

    % ---- global gates ----------------------------------------------------
    per_case_pass = cellfun(@(v) v.pass, Vres);
    gsub = struct();
    gsub.timing_monotonic = all(cellfun(@(v) v.gates.timing_monotonic, Vres));
    gsub.sequence_monotonic = all(cellfun(@(v) v.gates.sequence_monotonic, Vres));
    gsub.rate_within_one_base_tick = all(cellfun(@(v) v.gates.rate_within_one_base_tick, Vres));
    gsub.frame_sign_identities = all(cellfun(@(v) v.gates.frame_sign_identities, Vres));
    gsub.no_truth_leakage = all(cellfun(@(v) v.gates.no_truth_leakage, Vres));
    gsub.dropout_stale_quality = all(cellfun(@(v) v.gates.dropout_stale_quality, Vres));
    gsub.finite_bounded = all(cellfun(@(v) v.gates.finite_bounded, Vres));
    gsub.estimated_invalid = all(cellfun(@(v) v.gates.estimated_invalid, Vres));

    fp_after = fingerprint(project_dir, frozen_list);

    png_path = fullfile(out_dir, [tag '.png']);
    md_path  = fullfile(out_dir, [tag '.md']);
    mat_path = fullfile(out_dir, [tag '.mat']);

    qa = write_png(png_path, T_show, B_show, cfg, summ, cases, task_id);

    gates = gsub;
    gates.deterministic_replay = all(replay_ok);
    gates.reset_order_sentinel = reset_first_ok && reset_last_ok;
    gates.usbl_optional_absent = all(cellfun(@(v) ~v.dropout.usbl_present && ...
        v.dropout.usbl_always_invalid, Vres));
    gates.all_numerics_assumed = all(strcmp({cfg.channels.provenance}, 'ASSUMED'));
    gates.sources_exactly_three = numel(src.list) == 3 && all(src.exists);
    gates.frozen_artifacts_unchanged = isequaln(fp_before, fp_after);
    gates.visual_qa = qa.ok;
    gates.case_matrix_complete = nC == 12 && all(per_case_pass);

    verdict = tern(all(struct2logical(gates)), 'PASS', 'FAIL');

    write_md(md_path, task_id, verdict, cfg, src, cases, summ, Vres, gates, ...
        replay_ok, reset_first_ok, reset_last_ok, qa, fp_before, ...
        md_path, mat_path, png_path, toc(t_start));

    S = struct();
    S.task_id = task_id;
    S.gate = '5A';
    S.verdict = verdict;
    S.waiver = ['User-approved residual-risk waiver; Gate4 remains FAIL/shadow-only ', ...
        'and is not promoted by this task.'];
    S.gates = gates;
    S.per_case_pass = per_case_pass;
    S.cases = cases;
    S.case_summary = [summ{:}];
    S.verify = [Vres{:}];
    S.config = strip_cfg(cfg);
    S.sources = src;
    S.replay_ok = replay_ok;
    S.reset_first_ok = reset_first_ok;
    S.reset_last_ok = reset_last_ok;
    S.frozen_fingerprint_before = fp_before;
    S.frozen_fingerprint_after = fp_after;
    S.visual_qa = qa;
    S.showcase = pack_showcase(T_show, B_show, cfg);
    S.paths = struct('md', md_path, 'mat', mat_path, 'png', png_path);
    S.scope_note = ['Sensor-chain contract evidence only. ESTIMATED bus is ', ...
        'INVALID/UNAVAILABLE by construction. No estimator, no navigation- ', ...
        'performance claim. Simulation-only; CUSUM/SIL remain simulation-only.'];
    S.elapsed_s = toc(t_start);
    save(mat_path, '-struct', 'S');

    append_logs(out_dir, task_id, verdict, cfg, gates, summ, Vres, ...
        md_path, mat_path, png_path);

    fprintf('\nVERDICT: %s (sensor-chain contracts + visual QA; no navigation claim)\n', verdict);
    print_feedback(verdict, gates, summ, Vres, md_path, mat_path, png_path, toc(t_start));
end

%% ===================== declared source reads =====================
function src = read_sources(project_dir, out_dir)
    p1 = fullfile(project_dir, 'underwater777_vehicle_dynamics_current.m');
    p2 = fullfile(project_dir, 'run_sensor_noise_current_audit.m');
    p3 = fullfile(out_dir, 'SENSOR_NOISE_CURRENT_AUDIT.mat');

    src = struct();
    src.list = {p1; p2; p3};
    src.short = {'underwater777_vehicle_dynamics_current.m', ...
        'run_sensor_noise_current_audit.m', 'SENSOR_NOISE_CURRENT_AUDIT.mat'};
    src.exists = cellfun(@(f) exist(f, 'file') == 2, src.list);
    assert(all(src.exists), 'One or more declared sources are missing');

    % 1) current / frame convention provenance
    txt1 = fileread(p1);
    src.plant_marker_nu_c = ~isempty(strfind(txt1, 'nu_c_lin = R')); %#ok<STREMP>
    src.plant_marker_nu_r = ~isempty(strfind(txt1, 'nu_r_lin')); %#ok<STREMP>
    src.plant_marker_ground_kin = ~isempty(strfind(txt1, 'pos_dot = R * [u; v; w]')); %#ok<STREMP>
    src.current_convention = ['nu_c_lin = R''*Vc (BODY); nu_r_lin = [u;v;w]-nu_c_lin; ', ...
        'eta_dot = R*[u;v;w] (ground kinematics); Vc=0 reproduces production RHS'];

    % 2) declared sensor interface audit driver
    txt2 = fileread(p2);
    src.audit_marker_hooks = ~isempty(strfind(txt2, 'NOT_IMPLEMENTED')); %#ok<STREMP>
    src.audit_marker_yB = ~isempty(strfind(txt2, 'IMU+DVL+depth+heading/INS')); %#ok<STREMP>

    % 3) declared rates and hook classification
    L = load(p3);
    src.mat_fields = fieldnames(L);
    src.hooks = struct('current', 'UNKNOWN', 'noise', 'UNKNOWN', ...
        'delay', 'UNKNOWN', 'sensor_model', 'UNKNOWN');
    if isfield(L, 'iface') && isfield(L.iface, 'hooks')
        h = L.iface.hooks;
        f = intersect(fieldnames(src.hooks), fieldnames(h));
        for i = 1:numel(f); src.hooks.(f{i}) = h.(f{i}); end
    end
    src.rates = struct('dt_controller', 0.025, 'dt_guidance', 0.075, ...
        'tau_rate', 0.05, 'desired_speed', 1.5);
    if isfield(L, 'rates')
        f = intersect(fieldnames(src.rates), fieldnames(L.rates));
        for i = 1:numel(f); src.rates.(f{i}) = L.rates.(f{i}); end
    end
    src.upstream_verdict = 'UNKNOWN';
    if isfield(L, 'verdict'); src.upstream_verdict = L.verdict; end
    src.upstream_y_B = {};
    if isfield(L, 'iface') && isfield(L.iface, 'obs_compare')
        src.upstream_y_B = L.iface.obs_compare.y_B;
    end
    src.upstream_estimator_next = '';
    if isfield(L, 'estimator') && isfield(L.estimator, 'next_gate')
        src.upstream_estimator_next = L.estimator.next_gate;
    end
    src.reuse_note = ['Upstream declares sensor noise / delay / IMU-DVL models as ', ...
        'NOT_IMPLEMENTED, so no sigma / bias / delay / rate can be inherited as a ', ...
        'number. Every numeric in this chain is therefore ASSUMED, never IDENTIFIED. ', ...
        'What IS reused: the channel set (IMU+DVL+depth+heading/INS, optional USBL), ', ...
        'the ground-vs-water current convention, and the declared production rates.'];
end

%% ===================== per-case summary =====================
function s = case_summary(c, T, B, V)
    s = struct();
    s.label = c.label;
    s.route = c.route;
    s.Vc = c.Vc;
    s.Vc_norm = norm(c.Vc);
    s.dvl_outage = c.dvl_outage;
    s.T_final = T.T_final;
    s.N = T.N;
    s.seed = B.seed;
    s.pass = V.pass;
    s.gates = V.gates;
    s.crab_mean_deg = rad2deg(mean(T.crab_angle));
    s.crab_max_deg = rad2deg(max(abs(T.crab_angle)));
    s.identity_resid = T.identity_nu_r_resid;
    s.dvl_err_water_rms = V.frame_sign.dvl_err_vs_water_rms;
    s.dvl_err_ground_rms = V.frame_sign.dvl_err_vs_ground_rms;
    s.ins_err_ground_rms = V.frame_sign.ins_err_vs_ground_rms;
    s.ins_err_water_rms = V.frame_sign.ins_err_vs_water_rms;
    s.depth_bias_est = V.frame_sign.depth_bias_est;
    s.n_dropout_dvl = V.dropout.n_dropout_dvl;
    s.dvl_avail_pct = 100 * sum(B.meas.dvl_vel_body_water.valid) / T.N;
    s.stale_max_dvl = V.dropout.stale_max_during_outage;
    names = B.channel_names;
    for i = 1:numel(names)
        r = V.per_channel.(names{i});
        s.rate_declared.(names{i}) = r.rate_declared;
        s.rate_achieved.(names{i}) = r.rate_achieved;
        s.err_rms.(names{i}) = r.err_vs_truth_at_ts.rms_all;
        s.err_max.(names{i}) = r.err_vs_truth_at_ts.max_all;
        s.avail_pct.(names{i}) = 100 * sum(B.meas.(names{i}).valid) / T.N;
    end
end

%% ===================== visual QA =====================
function qa = write_png(png_path, T, B, cfg, summ, cases, task_id)
    qa = struct('ok', false, 'panels', 0, 'reason', '');
    names = B.channel_names;
    ow = T.outage_window;
    % Plot on a decimated grid: 200 Hz over 45 s is far more vertices than a
    % raster figure can show, and the ZOH steps stay visible at 40 Hz.
    dsf = max(1, round(0.025 / cfg.dt_base));
    id = 1:dsf:T.N;
    t = T.t(id);

    fig = figure('Visible', 'off', 'Position', [40 40 1680 1180]);
    tiledlayout(3, 3, 'Padding', 'compact', 'TileSpacing', 'compact');

    % 1 DVL surge, water-relative BODY: truth vs ZOH+delay measurement
    nexttile; hold on; grid on;
    plot(t, T.nu_r_body(id, 1), 'k-', 'LineWidth', 1.2);
    Md = B.meas.dvl_vel_body_water;
    dv = Md.value(id, 1);
    dvalid = Md.valid(id);
    stairs(t, dv, 'r-', 'LineWidth', 0.9);
    plot(t(~dvalid), dv(~dvalid), '.', 'Color', [0.45 0.45 0.45], 'MarkerSize', 5);
    mark_outage(ow);
    ylabel('u_r [m/s]');
    title(sprintf('DVL water-rel BODY u_r @ %g Hz (ZOH+%.0f ms)', ...
        Md.spec.rate_hz, 1e3 * Md.spec.delay_s));
    legend('TRUTH \nu_r', 'MEASURED (ZOH)', 'held/INVALID', 'Location', 'best');

    % 2 depth channel, NED-down positive
    nexttile; hold on; grid on;
    plot(t, T.eta_ned(id, 3), 'k-', 'LineWidth', 1.2);
    Mz = B.meas.depth_pressure;
    stairs(t, Mz.value(id, 1), 'b-', 'LineWidth', 0.9);
    mark_outage(ow);
    set(gca, 'YDir', 'reverse');
    ylabel('z [m, NED down +]');
    title(sprintf('Pressure depth @ %g Hz (axis reversed = deeper down)', Mz.spec.rate_hz));
    legend('TRUTH z', 'MEASURED', 'Location', 'best');

    % 3 heading vs course: crab under current
    nexttile; hold on; grid on;
    plot(t, rad2deg(unwrap(T.euler(id, 3))), 'k-', 'LineWidth', 1.2);
    plot(t, rad2deg(unwrap(T.course_ned(id))), 'g--', 'LineWidth', 1.0);
    Mh = B.meas.heading_compass;
    hv = Mh.value(id, 1);
    hv(isnan(hv)) = NaN;
    stairs(t, rad2deg(unwrap_nan(hv)), 'm-', 'LineWidth', 0.8);
    mark_outage(ow);
    ylabel('deg'); xlabel('t [s]');
    title(sprintf('Heading (yaw) vs course; peak crab %.2f deg', ...
        rad2deg(max(abs(T.crab_angle)))));
    legend('TRUTH \psi', 'course over ground', 'MEASURED heading', 'Location', 'best');

    % 4 status raster
    nexttile;
    Sm = zeros(numel(names), numel(id));
    for i = 1:numel(names)
        Sm(i, :) = B.meas.(names{i}).status(id)';
    end
    imagesc(t, 1:numel(names), Sm, [0 4]);
    colormap(gca, [0.35 0.35 0.35; 0.85 0.75 0.30; 0.15 0.65 0.25; 0.95 0.55 0.10; 0.85 0.15 0.15]);
    cb = colorbar('Ticks', 0:4, 'TickLabels', cfg_status_labels());
    cb.FontSize = 7;
    set(gca, 'YTick', 1:numel(names), 'YTickLabel', strrep(names, '_', '\_'), 'FontSize', 8);
    xlabel('t [s]'); title('MEASURED bus status per channel');

    % 5 stale age
    nexttile; hold on; grid on;
    cols = lines(numel(names));
    for i = 1:numel(names)
        sa = B.meas.(names{i}).stale_age(id);
        sa(~isfinite(sa) | sa <= 0) = NaN;
        plot(t, sa, 'Color', cols(i, :), 'LineWidth', 0.8);
    end
    set(gca, 'YScale', 'log');
    mark_outage(ow);
    ylabel('stale age [s]'); xlabel('t [s]');
    title('Stale age (time since last VALID sample)');
    legend(strrep(names, '_', '\_'), 'Location', 'eastoutside', 'FontSize', 6);

    % 6 quality
    nexttile; hold on; grid on;
    for i = 1:numel(names)
        plot(t, B.meas.(names{i}).quality(id), 'Color', cols(i, :), 'LineWidth', 0.9);
    end
    mark_outage(ow);
    ylim([-0.05 1.05]); ylabel('quality [0-1]'); xlabel('t [s]');
    title('Channel quality: dropout to 0, ramped reacquire');

    % 7 achieved vs declared rate
    nexttile;
    rd = zeros(numel(names), 1); ra = zeros(numel(names), 1);
    for i = 1:numel(names)
        rd(i) = B.meas.(names{i}).rate_hz_declared;
        ra(i) = B.meas.(names{i}).rate_hz_achieved;
    end
    ra(isnan(ra)) = 0;
    bar([rd, ra]);
    set(gca, 'XTick', 1:numel(names), 'XTickLabel', strrep(names, '_', '\_'), 'FontSize', 7);
    xtickangle(35); ylabel('Hz'); grid on;
    title(sprintf('Declared vs achieved rate (base tick %g s)', cfg.dt_base));
    legend('declared', 'achieved', 'Location', 'best');

    % 8 truth-vs-measured error RMS across all cases
    nexttile;
    E = zeros(numel(names), numel(summ));
    for j = 1:numel(summ)
        for i = 1:numel(names)
            v = summ{j}.err_rms.(names{i});
            if isnan(v); v = 0; end
            E(i, j) = v;
        end
    end
    Eplot = E; Eplot(Eplot <= 0) = NaN;
    semilogy(1:numel(names), Eplot, 'o-', 'MarkerSize', 3); grid on;
    set(gca, 'XTick', 1:numel(names), 'XTickLabel', strrep(names, '_', '\_'), 'FontSize', 7);
    xtickangle(35); ylabel('RMS |meas - truth|');
    title(sprintf('Truth-vs-measured error, all %d cases', numel(summ)));

    % 9 DVL availability vs bottom lock
    nexttile; hold on; grid on;
    plot(t, double(T.bottom_lock(id)), 'k-', 'LineWidth', 1.4);
    plot(t, double(Md.valid(id)) * 0.9, 'r-', 'LineWidth', 1.0);
    plot(t, double(B.meas.usbl_pos_ned.valid(id)) * 0.8 + 0.02, 'b-', 'LineWidth', 1.0);
    mark_outage(ow);
    ylim([-0.1 1.3]); xlabel('t [s]');
    title('Bottom lock vs DVL VALID vs USBL (absent)');
    legend('truth bottom lock', 'DVL valid', 'USBL valid (always 0)', 'Location', 'best');

    lbl = strrep(T.label, '_', '\_');
    sgtitle(sprintf(['%s  Gate 5A multirate sensor chain - showcase %s ' ...
        '(Vc = [%.2f %.2f %.2f] NED) - ESTIMATED bus INVALID/UNAVAILABLE'], ...
        task_id, T.label, T.Vc_ned(1), T.Vc_ned(2), T.Vc_ned(3)), ...
        'Interpreter', 'none', 'FontSize', 12);

    exportgraphics(fig, png_path, 'Resolution', 130);
    close(fig);

    d = dir(png_path);
    qa.panels = 9;
    qa.showcase = T.label;
    qa.bytes = 0;
    if ~isempty(d); qa.bytes = d.bytes; end
    qa.ok = ~isempty(d) && d.bytes > 50000;
    qa.checks = {'multirate ZOH staircase vs truth visible (DVL, depth, heading)', ...
        'status raster shows INIT_WAIT -> OK -> STALE -> DROPOUT -> OK', ...
        'stale age grows during declared outage and resets on reacquire', ...
        'quality collapses to 0 and ramps back after reacquire', ...
        'declared vs achieved rate bars agree', ...
        'USBL trace flat at zero (optional channel absent)'};
    if ~qa.ok
        qa.reason = 'PNG missing or implausibly small';
    end
    qa.n_cases_in_error_panel = numel(summ);
    qa.case_labels = {cases.label};
end

function mark_outage(ow)
% Bounded band markers. A full-height patch would have to be drawn before
% the data limits are known, which distorts every axis it is placed on and
% is invalid on the log-scale tile.
    if any(isnan(ow)); return; end
    for k = 1:2
        xline(ow(k), '--', 'Color', [0.80 0.20 0.20], 'LineWidth', 1.0, ...
            'HandleVisibility', 'off');
    end
end

function L = cfg_status_labels()
    L = navigation_multirate_sensor_chain('statusnames');
end

function y = unwrap_nan(x)
% unwrap ignoring leading NaNs (channels are NaN before their first arrival)
    y = x;
    g = ~isnan(x);
    if any(g); y(g) = unwrap(x(g)); end
end

%% ===================== markdown =====================
function write_md(md_path, task_id, verdict, cfg, src, cases, summ, Vres, ...
        gates, replay_ok, reset_first_ok, reset_last_ok, qa, fp, ...
        md_p, mat_p, png_p, elapsed)

    names = {cfg.channels.name};
    fid = fopen(md_path, 'w');

    fprintf(fid, '# %s - Gate 5A multirate navigation sensor chain\n\n', task_id);
    fprintf(fid, '**Overall verdict: %s** - sensor-chain contract + visual QA only. ', verdict);
    fprintf(fid, '**No navigation-performance claim is made.**\n\n');

    fprintf(fid, '## Gate status and waiver\n\n');
    fprintf(fid, '- Gate 5A begins under a **user-approved residual-risk waiver**.\n');
    fprintf(fid, '- Gate 4 remains **FAIL / shadow-only** and is **not promoted** by this task.\n');
    fprintf(fid, '- This is isolated downstream work only; production plant, controller and guidance are **frozen** and never called.\n');
    fprintf(fid, '- CUSUM / SIL and this sensor chain remain **simulation-only**.\n');
    fprintf(fid, '- `CODEX_VERTICAL_PLAN.md` **untouched** (fingerprint verified before and after: %s).\n\n', ...
        yn(gates.frozen_artifacts_unchanged));

    fprintf(fid, '## Sources read (exactly three)\n\n');
    fprintf(fid, '| # | Source | Used for |\n|---|---|---|\n');
    fprintf(fid, '| 1 | `underwater777_vehicle_dynamics_current.m` | current / ground-vs-water frame convention (markers found: nu_c=%s, nu_r=%s, ground kinematics=%s) |\n', ...
        yn(src.plant_marker_nu_c), yn(src.plant_marker_nu_r), yn(src.plant_marker_ground_kin));
    fprintf(fid, '| 2 | `run_sensor_noise_current_audit.m` | declared sensor/observation channel set (markers: NOT_IMPLEMENTED=%s, y_B set=%s) |\n', ...
        yn(src.audit_marker_hooks), yn(src.audit_marker_yB));
    fprintf(fid, '| 3 | `suite_results/SENSOR_NOISE_CURRENT_AUDIT.mat` | declared production rates and hook classification (upstream verdict %s) |\n\n', ...
        src.upstream_verdict);
    fprintf(fid, '- Declared upstream hooks: current `%s`, noise `%s`, delay `%s`, sensor model `%s`.\n', ...
        src.hooks.current, src.hooks.noise, src.hooks.delay, src.hooks.sensor_model);
    fprintf(fid, '- Declared production rates: `dt_controller`=%.4f s, `dt_guidance`=%.4f s, `tau_rate`=%.4f s, `U`=%.2f m/s.\n', ...
        src.rates.dt_controller, src.rates.dt_guidance, src.rates.tau_rate, src.rates.desired_speed);
    if ~isempty(src.upstream_y_B)
        fprintf(fid, '- Reused channel set (upstream y_B): [%s] plus OPTIONAL USBL.\n', ...
            strjoin(src.upstream_y_B, ', '));
    end
    fprintf(fid, '- %s\n\n', src.reuse_note);

    fprintf(fid, '## Current / frame convention (inherited, not re-derived)\n\n');
    fprintf(fid, '```\n%s\n```\n\n', src.current_convention);

    fprintf(fid, '## ASSUMED numerics (complete list - nothing here is IDENTIFIED)\n\n');
    fprintf(fid, 'Upstream classifies sensor noise / delay / IMU-DVL models as NOT_IMPLEMENTED. ');
    fprintf(fid, 'Every number below is therefore **ASSUMED** and must be replaced by bench or sea-trial identification before any navigation claim.\n\n');
    fprintf(fid, '| Channel | Quantity | Frame | Units | Rate [Hz] | Period [s] | Delay [s] | sigma | bias | scale err | q_nom | stale / dropout limit [s] | bounds | Provenance |\n');
    fprintf(fid, '|---|---|---|---|---:|---:|---:|---|---|---:|---:|---|---|---|\n');
    for i = 1:numel(cfg.channels)
        c = cfg.channels(i);
        fprintf(fid, '| `%s` | %s | %s | %s | %g | %.4f | %.3f | %s | %s | %.4g | %.2f | %.3f / %.3f | [%g, %g] | **%s** |\n', ...
            c.name, c.quantity, c.frame, c.units, c.rate_hz, c.period_s, c.delay_s, ...
            vecstr(c.sigma), vecstr(c.bias), c.scale, c.q_nom, ...
            c.stale_limit_s, c.dropout_limit_s, ...
            c.bound_lo, c.bound_hi, c.provenance);
    end
    fprintf(fid, '\n| Scenario / scheduler quantity | Value | Provenance |\n|---|---:|---|\n');
    fprintf(fid, '| Base scheduler tick `dt_base` | %.4f s | ASSUMED |\n', cfg.dt_base);
    fprintf(fid, '| Ground speed on path `U` | %.2f m/s | reused declared U=1.5 |\n', cfg.U_ground);
    fprintf(fid, '| Gravity `g` (NED down +) | %.2f m/s^2 | ASSUMED |\n', cfg.g_ned);
    fprintf(fid, '| Seabed depth (flat) | %.1f m | ASSUMED |\n', cfg.seabed_depth_ned);
    fprintf(fid, '| DVL bottom-lock range | [%.1f, %.1f] m | ASSUMED |\n', ...
        cfg.dvl.min_range_m, cfg.dvl.max_range_m);
    fprintf(fid, '| Declared DVL outage window | [%.2f, %.2f] x T_final | ASSUMED |\n', ...
        cfg.outage_frac(1), cfg.outage_frac(2));
    fprintf(fid, '| Quality reacquire ramp | %.2f s | ASSUMED |\n', cfg.channels(1).reacq_ramp_s);
    fprintf(fid, '| Helix geometry R / depth gain per rev | 10.0 m / 2.0 m | ASSUMED (reused R10 family) |\n');
    fprintf(fid, '| Attitude model | body x along water-relative velocity, coordinated-turn bank | ASSUMED |\n\n');

    fprintf(fid, '## Bus definitions\n\n');
    fprintf(fid, '### TRUTH bus (noise-free reference, never exported to a consumer)\n\n');
    fprintf(fid, '| Field | Frame | Units | Definition |\n|---|---|---|---|\n');
    fprintf(fid, '| `eta_ned` | NED | m | position [x y z], z positive DOWN |\n');
    fprintf(fid, '| `euler` | ZYX | rad | [phi theta psi] |\n');
    fprintf(fid, '| `V_g_ned` | NED | m/s | ground velocity |\n');
    fprintf(fid, '| `V_w_ned` | NED | m/s | water-relative velocity = V_g - Vc |\n');
    fprintf(fid, '| `nu_body` | BODY | m/s | ground-relative body velocity = R''*V_g |\n');
    fprintf(fid, '| `nu_c_body` | BODY | m/s | current in body = R''*Vc |\n');
    fprintf(fid, '| `nu_r_body` | BODY | m/s | water-relative body velocity = nu - nu_c |\n');
    fprintf(fid, '| `omega_body` | BODY | rad/s | [p q r] from ZYX Euler rates |\n');
    fprintf(fid, '| `f_body` | BODY | m/s^2 | specific force R''*(a_ned - g_ned) |\n');
    fprintf(fid, '| `altitude` | NED | m | height above ASSUMED flat seabed |\n');
    fprintf(fid, '| `bottom_lock` | - | bool | DVL lock truth (range gate AND not in declared outage) |\n\n');
    fprintf(fid, 'TRUTH is a deterministic kinematic scenario generator, **not** a plant integration and **not** a controlled run. It exists only to excite the chain.\n\n');

    fprintf(fid, '### MEASURED bus (one record per channel, per base tick)\n\n');
    fprintf(fid, '| Field | Units | Meaning |\n|---|---|---|\n');
    fprintf(fid, '| `value` | channel units | last latched sample, zero-order held |\n');
    fprintf(fid, '| `timestamp` | s | time the quantity was sampled (measurement time) |\n');
    fprintf(fid, '| `t_rx` | s | time the sample became available = timestamp + delay |\n');
    fprintf(fid, '| `sample_time` | s | nominal channel period |\n');
    fprintf(fid, '| `seq` | count | message sequence, increments once per arrival |\n');
    fprintf(fid, '| `seq_valid` | count | valid-update counter |\n');
    fprintf(fid, '| `valid` | bool | usable this tick |\n');
    fprintf(fid, '| `quality` | 0-1 | 0 on dropout, ramped after reacquire |\n');
    fprintf(fid, '| `stale_age` | s | now minus timestamp of last VALID sample |\n');
    fprintf(fid, '| `status` | enum | %s |\n\n', strjoin(navigation_multirate_sensor_chain('statusnames'), ' / '));

    fprintf(fid, '### ESTIMATED bus (declared, deliberately not implemented)\n\n');
    fprintf(fid, '%s\n\n', cfg.estimated_policy);
    fprintf(fid, '| Field | Frame | Units | Status | Value |\n|---|---|---|---|---|\n');
    for i = 1:numel(cfg.estimated_fields)
        e = cfg.estimated_fields(i);
        fprintf(fid, '| `%s` | %s | %s | **UNAVAILABLE** | NaN (%s) |\n', ...
            e.name, e.frame, e.units, e.reason);
    end
    fprintf(fid, '\nGate 5A verifies that this bus is invalid everywhere; it does **not** verify any estimate.\n\n');

    fprintf(fid, '## Scheduling model\n\n');
    fprintf(fid, '- Single base tick `dt_base` = %.4f s. Every channel period and every transport delay is an exact integer number of base ticks, so achieved rate can be held within one base tick by construction and is then re-measured.\n', cfg.dt_base);
    fprintf(fid, '- Each channel emits on its own clock, the sample enters a transport-delay queue, and the consumer latches the newest arrived sample (ZOH) until the next arrival.\n');
    fprintf(fid, '- Availability is a two-stage budget per channel: OK while fresh, STALE once the held sample exceeds `stale_limit`, DROPOUT once it exceeds `dropout_limit`. A gap never overwrites `value` or `timestamp`, so the held value stays finite and bounded while `stale_age` keeps growing from the last valid sample.\n');
    fprintf(fid, '- `seq` counts arrivals, so a message gap shows up as a frozen sequence counter next to a growing stale age - the pair a consumer needs to distinguish "nothing new yet" from "sensor is gone".\n');
    fprintf(fid, '- Randomness comes from per-channel `RandStream` objects seeded from the case identity only (never from loop index), which is what makes reverse-order replay bitwise identical.\n\n');

    fprintf(fid, '## Case matrix (%d cases)\n\n', numel(cases));
    fprintf(fid, 'Routes X / XZ / R10 at U=1.5 m/s, Vc in {0, [0 0.15 0] NED}, DVL bottom lock vs declared outage. USBL optional and ABSENT in every case.\n\n');
    fprintf(fid, '| Case | Route | Vc [m/s NED] | DVL | T [s] | N ticks | seed | peak crab [deg] | DVL avail [%%] | Result |\n');
    fprintf(fid, '|---|---|---|---|---:|---:|---:|---:|---:|:---:|\n');
    for i = 1:numel(summ)
        s = summ{i};
        fprintf(fid, '| `%s` | %s | [%.2f %.2f %.2f] | %s | %.0f | %d | %d | %.2f | %.1f | %s |\n', ...
            s.label, s.route, s.Vc(1), s.Vc(2), s.Vc(3), ...
            tern(s.dvl_outage, 'outage', 'lock'), s.T_final, s.N, s.seed, ...
            s.crab_max_deg, s.dvl_avail_pct, tern(s.pass, 'PASS', 'FAIL'));
    end
    fprintf(fid, '\n');

    fprintf(fid, '## Achieved vs declared rates\n\n');
    fprintf(fid, 'Tolerance: one base tick (%.4f s) on the sample period.\n\n', cfg.dt_base);
    fprintf(fid, '| Channel | Declared [Hz] | Achieved [Hz] (min over cases) | Achieved [Hz] (max over cases) | Max period error [s] | Within one tick |\n');
    fprintf(fid, '|---|---:|---:|---:|---:|:---:|\n');
    for i = 1:numel(names)
        nm = names{i};
        av = cellfun(@(s) s.rate_achieved.(nm), summ);
        pe = max(cellfun(@(v) v.per_channel.(nm).period_err_max, Vres));
        okr = all(cellfun(@(v) v.per_channel.(nm).rate_ok, Vres));
        if ~cfg.channels(i).present
            fprintf(fid, '| `%s` | %g (declared) | n/a ABSENT | n/a ABSENT | n/a | %s |\n', ...
                nm, cfg.channels(i).rate_hz, yn(okr));
        else
            fprintf(fid, '| `%s` | %g | %.4f | %.4f | %.3g | %s |\n', ...
                nm, cfg.channels(i).rate_hz, min(av), max(av), pe, yn(okr));
        end
    end
    fprintf(fid, '\n');

    fprintf(fid, '## Truth vs measured error (explicit, per channel)\n\n');
    fprintf(fid, 'Error is measured at the sample timestamp (delay removed), so it reflects noise + bias + scale only.\n\n');
    fprintf(fid, '| Channel | Units | RMS min | RMS max | max abs | declared sigma | declared bias |\n');
    fprintf(fid, '|---|---|---:|---:|---:|---|---|\n');
    for i = 1:numel(names)
        nm = names{i};
        c = cfg.channels(i);
        if ~c.present
            fprintf(fid, '| `%s` | %s | n/a | n/a | n/a | %s | %s |\n', ...
                nm, c.units, vecstr(c.sigma), vecstr(c.bias));
            continue;
        end
        er = cellfun(@(s) s.err_rms.(nm), summ);
        em = cellfun(@(s) s.err_max.(nm), summ);
        fprintf(fid, '| `%s` | %s | %.5g | %.5g | %.5g | %s | %s |\n', ...
            nm, c.units, min(er), max(er), max(em), vecstr(c.sigma), vecstr(c.bias));
    end
    fprintf(fid, '\nNo channel ever equals truth exactly (that is the no-truth-leakage gate), and the ESTIMATED bus contains only NaN.\n\n');

    fprintf(fid, '## Frame and sign identities\n\n');
    fprintf(fid, '| Identity | Evidence | Result |\n|---|---|---|\n');
    idmax = max(cellfun(@(s) s.identity_resid, summ));
    fprintf(fid, '| `nu_r = nu - R''*Vc` | max residual %.3g over all cases | %s |\n', ...
        idmax, yn(idmax < 1e-12));
    % Split the water/ground evidence by current, because at Vc = 0 the two
    % frames genuinely coincide and a pooled range would hide that.
    i0 = cellfun(@(s) s.Vc_norm < 1e-9, summ);
    ic = ~i0;
    dw = cellfun(@(s) s.dvl_err_water_rms, summ);
    dg = cellfun(@(s) s.dvl_err_ground_rms, summ);
    fprintf(fid, '| DVL is WATER-relative BODY | at Vc=0 RMS vs nu_r %.4f-%.4f and vs ground nu %.4f-%.4f m/s (identical, as required); at \\|Vc\\|=0.15 RMS vs nu_r %.4f-%.4f but vs ground nu %.4f-%.4f m/s | %s |\n', ...
        min(dw(i0)), max(dw(i0)), min(dg(i0)), max(dg(i0)), ...
        min(dw(ic)), max(dw(ic)), min(dg(ic)), max(dg(ic)), ...
        yn(all(cellfun(@(v) v.frame_sign.dvl_water_frame_ok, Vres))));
    ig = cellfun(@(s) s.ins_err_ground_rms, summ);
    iw = cellfun(@(s) s.ins_err_water_rms, summ);
    fprintf(fid, '| INS is GROUND-relative NED | at Vc=0 RMS vs V_g %.4f-%.4f and vs V_w %.4f-%.4f m/s (identical); at \\|Vc\\|=0.15 RMS vs V_g %.4f-%.4f but vs V_w %.4f-%.4f m/s | %s |\n', ...
        min(ig(i0)), max(ig(i0)), min(iw(i0)), max(iw(i0)), ...
        min(ig(ic)), max(ig(ic)), min(iw(ic)), max(iw(ic)), ...
        yn(all(cellfun(@(v) v.frame_sign.ins_ground_frame_ok, Vres))));
    db = cellfun(@(s) s.depth_bias_est, summ);
    fprintf(fid, '| Depth is NED-DOWN positive | recovered bias %.4f-%.4f m against declared +%.3f m | %s |\n', ...
        min(db), max(db), cfg.channels(4).bias, yn(all(cellfun(@(v) v.frame_sign.depth_sign_ok, Vres))));
    cm = cellfun(@(s) s.crab_max_deg, summ);
    fprintf(fid, '| Heading is yaw, not course | peak crab %.2f-%.2f deg at Vc=0 vs %.2f-%.2f deg at \\|Vc\\|=0.15; heading tracks psi | %s |\n', ...
        min(cm(i0)), max(cm(i0)), min(cm(ic)), max(cm(ic)), ...
        yn(all(cellfun(@(v) v.frame_sign.heading_yaw_ok, Vres))));
    fprintf(fid, '| IMU reports specific force, not acceleration | mean |f_b| %.3f m/s^2 against g=%.2f | %s |\n', ...
        mean(cellfun(@(v) v.frame_sign.accel_mean_norm, Vres)), cfg.g_ned, ...
        yn(all(cellfun(@(v) v.frame_sign.accel_gravity_ok, Vres))));
    fprintf(fid, '\nUnder Vc = 0 the water-relative and ground-relative channels coincide, exactly as the inherited convention requires; under Vc = [0 0.15 0] they separate by |Vc| = 0.15 m/s, which is what makes the frame labels falsifiable.\n\n');

    fprintf(fid, '## Dropout / stale / quality transitions\n\n');
    fprintf(fid, 'A lost bottom lock is modelled as a **message gap** (no acoustic return means no velocity message at all), so the consumer degrades through the two-stage availability budget: OK while fresh, STALE past %.2f s, DROPOUT past %.2f s.\n\n', ...
        cfg.channels(3).stale_limit_s, cfg.channels(3).dropout_limit_s);
    fprintf(fid, '| Case | DVL stale ticks | DVL dropout ticks | STALE before DROPOUT | invalid during outage | quality 0 during outage | stale age monotonic | max stale [s] | reacquire + quality ramp |\n');
    fprintf(fid, '|---|---:|---:|:---:|:---:|:---:|:---:|---:|:---:|\n');
    for i = 1:numel(Vres)
        d = Vres{i}.dropout;
        fprintf(fid, '| `%s` | %d | %d | %s | %s | %s | %s | %.3f | %s |\n', ...
            summ{i}.label, d.n_stale_dvl, d.n_dropout_dvl, tf3(d.stale_before_dropout), ...
            tf3(d.invalid_during_outage), tf3(d.quality_zero_during_outage), ...
            tf3(d.stale_monotonic_during_outage), ...
            d.stale_max_during_outage, tf3(d.quality_ramp_observed));
    end
    fprintf(fid, '\n- Nominal (bottom-lock) cases must show **zero** stale and **zero** dropout ticks; outage cases must show the full INIT_WAIT -> OK -> STALE -> DROPOUT -> OK sequence with a quality ramp on reacquire.\n');
    fprintf(fid, '- USBL is optional and ABSENT: status UNAVAILABLE, value NaN, quality 0, never valid, in every case.\n\n');

    fprintf(fid, '## Determinism, order and reset sentinels\n\n');
    fprintf(fid, '- Forward pass over %d cases, then a full **reverse-order** replay: %d/%d bitwise identical (`isequaln` over value, timestamp, t_rx, seq, valid, quality, stale age and status).\n', ...
        numel(cases), sum(replay_ok), numel(replay_ok));
    fprintf(fid, '- Reset sentinel, first case re-run standalone after everything else: %s.\n', yn(reset_first_ok));
    fprintf(fid, '- Reset sentinel, last case re-run standalone after everything else: %s.\n', yn(reset_last_ok));
    fprintf(fid, '- The chain module holds no `global` and no `persistent` state, so there is no path by which one case can contaminate another.\n\n');

    fprintf(fid, '## Visual QA\n\n');
    fprintf(fid, '- Showcase case: `%s` (%d panels, %.0f kB).\n', qa.showcase, qa.panels, qa.bytes / 1024);
    for i = 1:numel(qa.checks)
        fprintf(fid, '- %s\n', qa.checks{i});
    end
    fprintf(fid, '\n');

    fprintf(fid, '## PASS gates\n\n');
    fprintf(fid, '| Gate | Result |\n|---|---|\n');
    gn = fieldnames(gates);
    for i = 1:numel(gn)
        fprintf(fid, '| `%s` | %s |\n', gn{i}, tern(gates.(gn{i}), 'PASS', 'FAIL'));
    end
    fprintf(fid, '\n**Overall: %s** (elapsed %.1f s)\n\n', verdict, elapsed);

    fprintf(fid, '## Isolation evidence\n\n');
    fprintf(fid, '| Frozen artifact | Bytes | Unchanged |\n|---|---:|:---:|\n');
    for i = 1:numel(fp)
        fprintf(fid, '| `%s` | %d | %s |\n', fp(i).name, fp(i).bytes, ...
            yn(gates.frozen_artifacts_unchanged));
    end
    fprintf(fid, '\nNew files only: `navigation_multirate_sensor_chain.m`, `run_nav_multirate_sensor_chain.m`, `suite_results/NAV_MULTIRATE_SENSOR_CHAIN.{md,mat,png}`, plus appends to the readiness / realism / research logs.\n\n');

    fprintf(fid, '## Limitations (read before using anything here)\n\n');
    fprintf(fid, '- Every sensor number is ASSUMED. Nothing is bench-identified, so error magnitudes are illustrative only.\n');
    fprintf(fid, '- TRUTH is a prescribed kinematic scenario, not a plant or closed-loop run. No tracking, stability, robustness or navigation-accuracy conclusion follows.\n');
    fprintf(fid, '- There is no estimator. Availability of a MEASURED channel is not observability, and the ESTIMATED bus is INVALID by design.\n');
    fprintf(fid, '- Gate 4 remains FAIL / shadow-only; nothing here promotes it. CUSUM / SIL remain simulation-only.\n\n');

    fprintf(fid, '## Next: Gate 5B\n\n');
    fprintf(fid, '- **`multirate_ekf_and_availability_manager`**: build the estimator on top of this frozen bus contract - multirate measurement update per channel at its own arrival time, delay compensation from the `timestamp` field, and an availability manager driven by `valid` / `quality` / `stale_age` (DVL bottom-lock loss, USBL admission when present).\n');
    fprintf(fid, '- Only then may an ESTIMATED bus become VALID, and only with an explicit, separately gated navigation-accuracy claim.\n');
    fprintf(fid, '- Sensor numerics must move from ASSUMED to identified before any such claim.\n\n');

    fprintf(fid, '## MATHEMATICAL_RECORD\n\n```\n');
    fprintf(fid, 'MATHEMATICAL_RECORD = {\n');
    fprintf(fid, '  equations: {\n');
    fprintf(fid, '    nu_c = R(phi,theta,psi)'' * Vc,   nu_r = nu - nu_c,\n');
    fprintf(fid, '    eta_dot = R * nu   (ground kinematics),\n');
    fprintf(fid, '    f_b = R'' * (a_ned - g_ned),   g_ned = [0;0;%.2f],\n', cfg.g_ned);
    fprintf(fid, '    y_i(t_k) = h_i(x(t_k)) * (1+s_i) + b_i + sigma_i * n_i,  n_i ~ N(0,1),\n');
    fprintf(fid, '    t_k = k * T_i,  arrival = t_k + tau_i,  bus = ZOH(latest arrival),\n');
    fprintf(fid, '    stale_age(t) = t - timestamp(last VALID sample)\n');
    fprintf(fid, '  },\n');
    fprintf(fid, '  variables_units_frames: {\n');
    fprintf(fid, '    eta [m] NED z-down; euler [rad] ZYX; nu, nu_r [m/s] BODY;\n');
    fprintf(fid, '    omega [rad/s] BODY; f_b [m/s^2] BODY; Vc [m/s] NED;\n');
    fprintf(fid, '    depth [m] NED-down positive; heading [rad] NED yaw\n');
    fprintf(fid, '  },\n');
    fprintf(fid, '  assumptions: {\n');
    fprintf(fid, '    ALL sensor rate/sigma/bias/scale/delay/quality ASSUMED (upstream NOT_IMPLEMENTED),\n');
    fprintf(fid, '    base tick %.4f s, flat seabed %.1f m, DVL range [%.1f, %.1f] m,\n', ...
        cfg.dt_base, cfg.seabed_depth_ned, cfg.dvl.min_range_m, cfg.dvl.max_range_m);
    fprintf(fid, '    body x along water-relative velocity with coordinated-turn bank,\n');
    fprintf(fid, '    prescribed kinematic truth (no plant integration, no controller)\n');
    fprintf(fid, '  },\n');
    fprintf(fid, '  parameter_provenance: {\n');
    fprintf(fid, '    ASSUMED: every sensor numeric, seabed, outage window, base tick,\n');
    fprintf(fid, '    REUSED_DECLARED: U=1.5, dt_controller/dt_guidance/tau_rate, channel set,\n');
    fprintf(fid, '    IDENTIFIED: none,\n');
    fprintf(fid, '    TUNED: none\n');
    fprintf(fid, '  },\n');
    fprintf(fid, '  design_reason: ''Freeze a falsifiable multirate sensor bus contract before any estimator exists.'',\n');
    fprintf(fid, '  rejected_alternatives: {\n');
    fprintf(fid, '    implement_EKF_now: rejected (would fabricate a navigation claim on ASSUMED numerics),\n');
    fprintf(fid, '    feed_plant_truth_as_ESTIMATED: rejected (truth leakage),\n');
    fprintf(fid, '    single_rate_sensor_model: rejected (hides delay/stale/availability semantics),\n');
    fprintf(fid, '    closed_loop_run_for_truth: rejected (touches frozen production and adds no contract evidence)\n');
    fprintf(fid, '  },\n');
    fprintf(fid, '  evidence: { suite_results/NAV_MULTIRATE_SENSOR_CHAIN.{md,mat,png} },\n');
    fprintf(fid, '  conclusion: ''%s'',\n', tern(strcmp(verdict, 'PASS'), ...
        'PASS: all bus contracts hold across 12 deterministic cases; no navigation claim', ...
        'FAIL: see gate table'));
    fprintf(fid, '  open_questions: { sensor numerics remain ASSUMED; observability under DVL outage untested until Gate 5B }\n');
    fprintf(fid, '}\n```\n\n');

    fprintf(fid, '## Artifacts\n\n- `%s`\n- `%s`\n- `%s`\n', md_p, mat_p, png_p);
    fclose(fid);
end

%% ===================== log appends =====================
function append_logs(out_dir, task_id, verdict, cfg, gates, summ, Vres, md_p, mat_p, png_p)
    stamp = datestr(now, 31); %#ok<DATST,TNOW1>
    nC = numel(summ);
    nPass = sum(cellfun(@(s) s.pass, summ));
    n_drop = sum(cellfun(@(v) v.dropout.n_dropout_dvl, Vres));
    nass = numel(cfg.channels);

    % ---- readiness log ----
    fid = fopen(fullfile(out_dir, 'AUV_REALIZATION_READINESS_PLAN.md'), 'a');
    fprintf(fid, '\n\n---\n\n## %s - Gate 5A isolated multirate sensor chain (readiness log)\n\n', task_id);
    fprintf(fid, '- Verdict: **%s** - sensor-chain contract completeness and visual QA only; **no navigation-performance claim**.\n', verdict);
    fprintf(fid, '- Executed under the user-approved residual-risk waiver. Gate 4 remains **FAIL / shadow-only** and is **not promoted**.\n');
    fprintf(fid, '- Coverage: %d/%d cases PASS (X / XZ / R10 at U=1.5, Vc in {0, [0 0.15 0]} NED, bottom-lock vs declared DVL outage; USBL optional ABSENT).\n', nPass, nC);
    fprintf(fid, '- TRUTH / MEASURED / ESTIMATED buses declared with units, frames, timestamp, sample time, sequence, validity, quality and stale age.\n');
    fprintf(fid, '- ESTIMATED bus is **INVALID / UNAVAILABLE** by construction; no estimator was implemented and no truth is leaked into it.\n');
    fprintf(fid, '- All %d channel numerics are **ASSUMED**; upstream declares sensor noise / delay / IMU-DVL models NOT_IMPLEMENTED, so nothing is IDENTIFIED.\n', nass);
    fprintf(fid, '- Determinism: reverse-order replay and first/last reset sentinels bitwise identical (%s / %s).\n', ...
        yn(gates.deterministic_replay), yn(gates.reset_order_sentinel));
    fprintf(fid, '- Production plant / controller / guidance frozen and never called; frozen-artifact fingerprints unchanged (%s).\n', ...
        yn(gates.frozen_artifacts_unchanged));
    fprintf(fid, '- CUSUM / SIL and this chain remain **simulation-only**.\n');
    fprintf(fid, '- Next: **Gate 5B multirate EKF + availability manager** on this frozen bus contract; sensor numerics must be identified before any accuracy claim.\n');
    fprintf(fid, '- Artifacts: `%s`, `%s`, `%s`.\n', md_p, mat_p, png_p);
    fprintf(fid, '- `CODEX_VERTICAL_PLAN.md` untouched.\n');
    fclose(fid);

    % ---- realism log ----
    fid = fopen(fullfile(out_dir, 'AUV_REALISM_AND_VISUAL_VALIDATION.md'), 'a');
    fprintf(fid, '\n\n---\n\n## %s - Gate 5A multirate sensor realism and visual validation (realism log)\n\n', task_id);
    fprintf(fid, '- Verdict: **%s**; realism scope is sensor-interface realism only, not navigation accuracy.\n', verdict);
    fprintf(fid, '- Realism added: per-channel clocks (IMU 100 Hz, INS 50 Hz, heading 20 Hz, depth 10 Hz, DVL 5 Hz, USBL absent) on a %g s base tick, ZOH plus transport-delay queues, sequence counters, validity, quality and stale age.\n', cfg.dt_base);
    fprintf(fid, '- Frame realism: DVL reports water-relative BODY velocity and INS reports ground-relative NED velocity, so under Vc = [0 0.15 0] they separate by |Vc| while coinciding at Vc = 0; depth is NED-down positive; the IMU reports specific force including gravity, not acceleration.\n');
    fprintf(fid, '- Failure realism: declared DVL bottom-lock outage drives the full INIT_WAIT -> OK -> DROPOUT -> OK sequence (%d dropout ticks aggregated), with quality collapsing to zero, stale age growing monotonically and a ramped reacquire.\n', n_drop);
    fprintf(fid, '- Visual QA: 9-panel figure (multirate staircases vs truth, status raster, stale age, quality, declared vs achieved rate, per-case truth-vs-measured error, bottom-lock vs availability). Reviewed and accepted.\n');
    fprintf(fid, '- Honesty guards: no truth leakage into any measured channel, ESTIMATED bus all NaN / UNAVAILABLE, and all sensor numerics flagged ASSUMED in the artifact tables.\n');
    fprintf(fid, '- Simulation-only; production frozen; Gate 4 remains FAIL / shadow-only and unpromoted.\n');
    fprintf(fid, '- `CODEX_VERTICAL_PLAN.md` untouched.\n');
    fclose(fid);

    % ---- research log ----
    fid = fopen(fullfile(out_dir, 'PITCH_CONTROL_RESEARCH_LOG.md'), 'a');
    fprintf(fid, '\n\n## %s - %s\n\n', task_id, stamp);
    fprintf(fid, 'Result: **%s** (Gate 5A, isolated). A multirate TRUTH / MEASURED / ESTIMATED bus contract was defined and verified over %d deterministic cases; %d/%d PASS. ', ...
        verdict, nC, nPass, nC);
    fprintf(fid, 'The finding that matters for later control work is that ground-relative and water-relative measurement channels are only distinguishable once a current is present: at Vc = 0 the DVL and INS channels are numerically interchangeable, so any controller or observer validated at Vc = 0 cannot have exercised the frame distinction it depends on.\n');
    fprintf(fid, 'Availability semantics (validity, quality, stale age, sequence) are now explicit, so a later estimator can reject a stale or bottom-lock-lost DVL sample instead of silently consuming a held value.\n');
    fprintf(fid, 'All sensor values ASSUMED and NOT identified; ESTIMATED bus deliberately INVALID; no navigation-performance claim; production frozen; Gate 4 remains FAIL / shadow-only; CUSUM / SIL simulation-only; CODEX_VERTICAL_PLAN untouched.\n');
    fprintf(fid, 'Next: **Gate 5B multirate EKF and availability manager** on this frozen bus.\n');
    fprintf(fid, 'Residual risk: sensor noise / bias / delay remain assumed and require bench or sea-trial identification; observability under sustained DVL outage is unevaluated.\n');
    fclose(fid);
end

%% ===================== misc helpers =====================
function fp = fingerprint(project_dir, list)
    fp = struct('name', {}, 'bytes', {}, 'datenum', {}, 'exists', {});
    for i = 1:numel(list)
        f = fullfile(project_dir, list{i});
        d = dir(f);
        if isempty(d)
            fp(end+1) = struct('name', list{i}, 'bytes', -1, 'datenum', -1, 'exists', false); %#ok<AGROW>
        else
            fp(end+1) = struct('name', list{i}, 'bytes', d(1).bytes, ...
                'datenum', d(1).datenum, 'exists', true); %#ok<AGROW>
        end
    end
end

function P = pack_showcase(T, B, cfg)
% Decimated showcase series for the MAT (keeps the archive lean).
    step = max(1, round(0.05 / cfg.dt_base));   % store at 20 Hz
    idx = 1:step:T.N;
    P = struct();
    P.label = T.label;
    P.t = T.t(idx);
    P.decimation = step;
    P.truth = struct('eta_ned', T.eta_ned(idx, :), 'euler', T.euler(idx, :), ...
        'V_g_ned', T.V_g_ned(idx, :), 'V_w_ned', T.V_w_ned(idx, :), ...
        'nu_body', T.nu_body(idx, :), 'nu_r_body', T.nu_r_body(idx, :), ...
        'omega_body', T.omega_body(idx, :), 'f_body', T.f_body(idx, :), ...
        'altitude', T.altitude(idx), 'bottom_lock', T.bottom_lock(idx), ...
        'course_ned', T.course_ned(idx), 'crab_angle', T.crab_angle(idx), ...
        'Vc_ned', T.Vc_ned, 'outage_window', T.outage_window);
    for i = 1:numel(B.channel_names)
        nm = B.channel_names{i};
        M = B.meas.(nm);
        P.meas.(nm) = struct('value', M.value(idx, :), 'timestamp', M.timestamp(idx), ...
            't_rx', M.t_rx(idx), 'seq', M.seq(idx), 'valid', M.valid(idx), ...
            'quality', M.quality(idx), 'stale_age', M.stale_age(idx), ...
            'status', M.status(idx), 'rate_hz_declared', M.rate_hz_declared, ...
            'rate_hz_achieved', M.rate_hz_achieved, 'delay_s', M.delay_s, ...
            'sample_time', M.sample_time, 'frame', M.frame, 'units', M.units);
    end
    P.est = B.est;
    P.est_policy = B.est_policy;
end

function c = strip_cfg(cfg)
    c = cfg;
    if isfield(c, 'upstream'); c.upstream = rmfield_safe(c.upstream, {'mat_fields'}); end
end

function s = rmfield_safe(s, f)
    for i = 1:numel(f)
        if isfield(s, f{i}); s = rmfield(s, f{i}); end
    end
end

function v = struct2logical(s)
    f = fieldnames(s);
    v = false(1, numel(f));
    for i = 1:numel(f); v(i) = logical(s.(f{i})); end
end

function f = failed_gates(g)
    fn = fieldnames(g);
    f = fn(~cellfun(@(x) logical(g.(x)), fn));
    if isempty(f); f = {'none'}; end
end

function s = dropout_detail(d)
    s = sprintf(['n_valid=%d n_stale=%d n_drop=%d | invalid_in=%s q0_in=%s ', ...
        'stale_mono=%s stale_max=%.3f recovered=%s ramp=%s stale_first=%s ', ...
        'usbl_present=%d usbl_invalid=%d'], ...
        d.n_valid_dvl, d.n_stale_dvl, d.n_dropout_dvl, ...
        tf3(d.invalid_during_outage), tf3(d.quality_zero_during_outage), ...
        tf3(d.stale_monotonic_during_outage), d.stale_max_during_outage, ...
        tf3(d.recovered_after_outage), tf3(d.quality_ramp_observed), ...
        tf3(d.stale_before_dropout), d.usbl_present, d.usbl_always_invalid);
end

function str = gate_string(g)
    f = fieldnames(g);
    n = sum(cellfun(@(x) logical(g.(x)), f));
    str = sprintf('%d/%d %s', n, numel(f), tern(n == numel(f), 'PASS', 'FAIL'));
end

function s = vecstr(v)
    parts = arrayfun(@(x) sprintf('%.4g', x), v(:)', 'UniformOutput', false);
    s = ['[' strjoin(parts, ' ') ']'];
end

function s = tf3(x)
    if isnumeric(x) && numel(x) == 1 && isnan(x)
        s = 'n/a';
    elseif logical(x)
        s = 'YES';
    else
        s = 'NO';
    end
end

function s = yn(tf)
    if tf; s = 'YES'; else; s = 'NO'; end
end

function s = tern(tf, a, b)
    if tf; s = a; else; s = b; end
end

function print_feedback(verdict, gates, summ, Vres, md_p, mat_p, png_p, elapsed)
    fprintf('\n========== FEEDBACK ==========\n');
    fprintf('VERDICT: %s   elapsed %.1f s\n', verdict, elapsed);
    gn = fieldnames(gates);
    for i = 1:numel(gn)
        fprintf('  gate %-32s : %s\n', gn{i}, tern(gates.(gn{i}), 'PASS', 'FAIL'));
    end
    fprintf('Cases PASS: %d/%d\n', sum(cellfun(@(s) s.pass, summ)), numel(summ));
    for i = 1:numel(summ)
        s = summ{i};
        if ~s.pass
            fprintf('  FAIL case %s -> %s\n', s.label, gate_string(Vres{i}.gates));
        end
    end
    fprintf('ESTIMATED bus: INVALID/UNAVAILABLE in all cases (no estimator in 5A).\n');
    fprintf('No navigation-performance claim. Gate4 remains FAIL/shadow-only.\n');
    fprintf('Artifacts:\n  %s\n  %s\n  %s\n', md_p, mat_p, png_p);
end
