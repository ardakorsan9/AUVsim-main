function run_cg2b_guidance_golden_parity_capture()
% RUN_CG2B_GUIDANCE_GOLDEN_PARITY_CAPTURE
% SIMULATION_ONLY — golden corpus capture for accepted guidance_law.
% Does NOT modify production call paths, gains, guidance_law.m, or init_parameters.m.
% No MEX / codegen / compiler. One-shot host capture + in-process determinism replay.
%
% TASK_ID: CG2B_GUIDANCE_GOLDEN_PARITY_CAPTURE_001

    task_id = 'CG2B_GUIDANCE_GOLDEN_PARITY_CAPTURE_001';
    corpus_id = 'CG2B_GUIDANCE_GOLDEN_V1';
    schema_version = 1;
    out_mat = fullfile('suite_results', 'CG2B_GUIDANCE_GOLDEN_V1.mat');
    out_json = fullfile('suite_results', 'CG2B_GUIDANCE_GOLDEN_V1.json');
    out_md = fullfile('suite_results', 'CG2B_GUIDANCE_GOLDEN_PARITY_CAPTURE.md');

    fprintf('[%s] start (SIMULATION_ONLY)\n', task_id);

    % ----- Source fingerprints (must be unchanged by this harness) -----
    src_guid = 'guidance_law.m';
    src_init = 'init_parameters.m';
    sha_guid_pre = local_sha256_file(src_guid);
    sha_init_pre = local_sha256_file(src_init);
    bytes_guid = local_file_bytes(src_guid);
    bytes_init = local_file_bytes(src_init);

    % ----- Accepted parameter setup (no production file edits) -----
    init_parameters();
    force_accepted_guidance_globals_();

    params = snapshot_guidance_params_();
    dt = params.dt_guidance;  % forced accepted fixed dt
    MAX_PATH_POINTS = params.MAX_PATH_POINTS;

    % ----- Fixed 8-input call corpus (valid finite only) + padded paths -----
    [U, path_pad, n_path, path_id, reset_before, case_id, step_id, case_table, ...
        input_names, units, frames, path_meta] = build_fixed_guidance_corpus_(dt, MAX_PATH_POINTS);
    N = size(U, 1);

    % ----- Replay A -----
    clear guidance_law
    [Ya, Dbga] = drive_guidance_sequence_(U, path_pad, n_path, path_id, reset_before);

    % ----- Replay B (identical resets; clear ONLY guidance_law) -----
    clear guidance_law
    [Yb, Dbgb] = drive_guidance_sequence_(U, path_pad, n_path, path_id, reset_before);

    % ----- Determinism (exact) -----
    det = struct();
    det.isequaln_inputs = isequaln(U, U);
    det.isequaln_outputs = isequaln(Ya, Yb);
    det.isequaln_diagnostics = isequaln(Dbga, Dbgb);
    det.isequaln_reset_before = isequaln(reset_before, reset_before);
    det.pass = det.isequaln_outputs && det.isequaln_diagnostics;
    Y = Ya;
    Dbg = Dbga;

    % ----- Finite / range / slew / progress checks -----
    checks = evaluate_guidance_checks_(U, Y, Dbg, path_pad, n_path, path_id, ...
        reset_before, params, dt);

    sha_guid_post = local_sha256_file(src_guid);
    sha_init_post = local_sha256_file(src_init);
    fingerprint_unchanged = strcmp(sha_guid_pre, sha_guid_post) && strcmp(sha_init_pre, sha_init_post);

    finite_ok = checks.all_outputs_finite && checks.all_diagnostics_finite && checks.all_inputs_finite;
    if det.pass && finite_ok && fingerprint_unchanged
        verdict = 'PASS';
        next_task = 'CG2B_GUIDANCE_EXPLICIT_STATE_PROTOTYPE_001';
    elseif fingerprint_unchanged && (det.pass || finite_ok)
        verdict = 'PARTIAL';
        next_task = 'CG2B_GUIDANCE_GOLDEN_PARITY_CAPTURE_REPAIR_001';
    else
        verdict = 'FAIL';
        next_task = 'CG2B_GUIDANCE_GOLDEN_PARITY_CAPTURE_REPAIR_001';
    end

    % ----- Lean versioned corpus -----
    corpus = struct();
    corpus.schema_version = schema_version;
    corpus.corpus_id = corpus_id;
    corpus.task_id = task_id;
    corpus.mode = 'SIMULATION_ONLY';
    corpus.cpp_parity_claimed = false;
    corpus.dt = dt;
    corpus.N_steps = N;
    corpus.N_inputs_call = 8;
    corpus.MAX_PATH_POINTS = MAX_PATH_POINTS;
    corpus.input_names = input_names;
    corpus.output_names = {'yaw_ref','pitch_ref','u_ref','next_progress_index','r_ff','pitch_ref_dot'};
    corpus.units = units;
    corpus.frames = frames;
    corpus.case_table = case_table;
    corpus.case_id = case_id;
    corpus.step_id = step_id;
    corpus.reset_before = reset_before;
    corpus.U = U;
    corpus.path_pad = path_pad;
    corpus.n_path = n_path;
    corpus.path_id = path_id;
    corpus.path_meta = path_meta;
    corpus.Y = Y;
    corpus.Diagnostics = Dbg;
    corpus.params_snapshot = params;
    corpus.determinism = det;
    corpus.checks = checks;
    corpus.source = struct( ...
        'guidance_law_bytes', bytes_guid, ...
        'guidance_law_sha256', sha_guid_pre, ...
        'guidance_law_sha256_post', sha_guid_post, ...
        'init_parameters_bytes', bytes_init, ...
        'init_parameters_sha256', sha_init_pre, ...
        'init_parameters_sha256_post', sha_init_post, ...
        'fingerprint_unchanged', fingerprint_unchanged);
    corpus.verdict = verdict;
    corpus.next_task = next_task;
    corpus.captured_utc = char(datetime('now', 'TimeZone', 'UTC', 'Format', 'yyyy-MM-dd''T''HH:mm:ss''Z'''));
    corpus.diagnostic_fieldnames = fieldnames(Dbg)';

    if ~exist('suite_results', 'dir'); mkdir('suite_results'); end
    save(out_mat, 'corpus', '-v7');
    write_json_metadata_(out_json, corpus);
    write_md_report_(out_md, corpus);

    fprintf('[%s] verdict=%s N=%d det=%d finite=%d fp=%d -> %s\n', ...
        task_id, verdict, N, det.pass, finite_ok, fingerprint_unchanged, out_mat);
    fprintf('[%s] next=%s\n', task_id, next_task);
end

% =====================================================================
function force_accepted_guidance_globals_()
% Force accepted production guidance config used by golden capture.
% Does not edit init_parameters.m / guidance_law.m sources.
    global dt_guidance dt_controller
    global lookahead_distance desired_speed
    global pitch_ref_max pitch_ref_rate_max
    global K_zdot K_gamma enable_alpha_hat

    % Accepted fixed guidance sample time (init_parameters production value)
    dt_guidance = 0.075;
    if isempty(dt_controller); dt_controller = 0.025; end

    % Reaffirm init_parameters guidance params (accepted frozen)
    if isempty(lookahead_distance); lookahead_distance = 1.25; end
    if isempty(desired_speed); desired_speed = 1.5; end
    if isempty(pitch_ref_max); pitch_ref_max = deg2rad(26); end
    if isempty(pitch_ref_rate_max); pitch_ref_rate_max = deg2rad(6); end

    % Accepted Tur5A/Tur5B production identity (init defaults)
    K_zdot = 0;
    K_gamma = 0;
    enable_alpha_hat = false;

    assert(abs(dt_guidance - 0.075) < 1e-15, 'dt_guidance must be accepted 0.075');
    assert(isfinite(lookahead_distance) && lookahead_distance > 0);
    assert(isfinite(desired_speed) && desired_speed > 0);
end

function P = snapshot_guidance_params_()
    global lookahead_distance desired_speed
    global pitch_ref_max pitch_ref_rate_max
    global dt_guidance dt_controller
    global K_zdot K_gamma enable_alpha_hat

    P = struct();
    P.MAX_PATH_POINTS = 32;
    P.lookahead_distance = lookahead_distance;
    P.desired_speed = desired_speed;
    P.pitch_ref_max = pitch_ref_max;
    P.pitch_ref_rate_max = pitch_ref_rate_max;
    P.dt_guidance = dt_guidance;
    P.dt_controller = dt_controller;
    P.K_zdot = K_zdot;
    P.K_gamma = K_gamma;
    P.enable_alpha_hat = logical(enable_alpha_hat);
    % Frozen literals from guidance_law (behaviour anchors; not globals)
    P.k_beta = 1.35;
    P.closed_eps = 0.25;
    P.near_end_margin = 0.3;
    P.mono_back_max = 0.05;
    P.s_back_tol = 0.15;
    P.yaw_slew_max_rad_s = deg2rad(40);
    P.r_ff_max_rad_s = deg2rad(40);
    P.pitch_corr_max = deg2rad(9);
    P.z_e_i_max = 25;
    P.alpha_hat_max = deg2rad(8);
end

function [U, path_pad, n_path, path_id_col, reset_before, case_id, step_id, case_table, ...
        input_names, units, frames, path_meta] = build_fixed_guidance_corpus_(dt, MAX_PATH_POINTS)
% Scalar/vector columns for call (path via path_id → active rows of padded buffer):
% pos_x,pos_y,pos_z, progress_index, u_body, v_body, U_h, zdot_inertial, theta_phys

    input_names = { ...
        'pos_x','pos_y','pos_z','progress_index','u_body','v_body', ...
        'U_h','zdot_inertial','theta_phys'};
    units = struct( ...
        'pos','m_NED', 'progress_index','1-based_index', ...
        'u_body','m/s_BODY', 'v_body','m/s_BODY', 'U_h','m/s_NED_horiz', ...
        'zdot_inertial','m/s_NED', 'theta_phys','rad_physical', ...
        'yaw_ref','rad_unwrapped_continuous', 'pitch_ref','rad', ...
        'u_ref','m/s', 'next_progress_index','1-based_index', ...
        'r_ff','rad/s', 'pitch_ref_dot','rad/s', 'dt','s', 'path','m_NED');
    frames = struct( ...
        'position','NED m (x North, y East, z Down-ish as in suite)', ...
        'path','NED waypoints; closed if ||p1-pend||<0.25 m', ...
        'body_speed','BODY surge/sway', ...
        'U_h','inertial horizontal speed (Tur4A)', ...
        'zdot_inertial','inertial vertical (Tur5A)', ...
        'theta_phys','physical pitch (Tur5B alpha)', ...
        'yaw_ref','guidance continuous unwrap (may leave (-pi,pi])');

    % ----- Path library (active rows only; padded later) -----
    paths = {};
    path_meta = struct('path_id', {}, 'name', {}, 'n_path', {}, 'is_closed', {}, 'note', {});

    % P1 open straight +X
    p = [0 0 5; 5 0 5; 10 0 5; 15 0 5; 20 0 5; 25 0 5; 30 0 5];
    paths{end+1} = p; %#ok<*AGROW>
    path_meta(end+1) = meta_(numel(paths), 'open_straight_x', size(p,1), false, 'cold/open straight');

    % P2 open multi-segment with curvature (polyline bend + climb)
    p = [0 0 5; 8 0 5; 14 4 4; 18 10 2; 20 18 0; 20 28 -1];
    paths{end+1} = p;
    path_meta(end+1) = meta_(numel(paths), 'open_curve_climb', size(p,1), false, 'multi-segment/curvature');

    % P3 closed square (seam at origin)
    p = [0 0 5; 10 0 5; 10 10 5; 0 10 5; 0 0 5];
    paths{end+1} = p;
    path_meta(end+1) = meta_(numel(paths), 'closed_square', size(p,1), true, 'closed-path seam');

    % P4 open short for near-end
    p = [0 0 5; 2 0 5; 4 0 5; 6 0 5; 8 0 5];
    paths{end+1} = p;
    path_meta(end+1) = meta_(numel(paths), 'open_short_end', size(p,1), false, 'near-end slowdown');

    % P5 heading ~+pi (travel -X)
    p = [0 0 5; -5 0 5; -10 0 5; -15 0 5; -20 0 5];
    paths{end+1} = p;
    path_meta(end+1) = meta_(numel(paths), 'open_neg_x_pi', size(p,1), false, 'course ~+pi');

    % P6 arc crossing +pi branch (CCW quarter through north)
    ang = linspace(0.15, pi - 0.15, 9)';
    p = [10*cos(ang), 10*sin(ang), 5*ones(size(ang))];
    paths{end+1} = p;
    path_meta(end+1) = meta_(numel(paths), 'arc_cross_pos_pi', size(p,1), false, 'yaw wrap +pi');

    % P7 arc crossing -pi branch (CW quarter through north)
    ang = linspace(-0.15, -(pi - 0.15), 9)';
    p = [10*cos(ang), 10*sin(ang), 5*ones(size(ang))];
    paths{end+1} = p;
    path_meta(end+1) = meta_(numel(paths), 'arc_cross_neg_pi', size(p,1), false, 'yaw wrap -pi');

    % P8 closed circle (curvature + Tur4A r_ff)
    ang = linspace(0, 2*pi, 17)';
    p = [10*cos(ang), 10*sin(ang), 5*ones(size(ang))];
    p(end,:) = p(1,:); % exact close
    paths{end+1} = p;
    path_meta(end+1) = meta_(numel(paths), 'closed_circle_r10', size(p,1), true, 'Tur4A curvature');

    Npaths = numel(paths);
    path_pad = zeros(MAX_PATH_POINTS, 3, Npaths);
    n_path = zeros(Npaths, 1);
    for i = 1:Npaths
        pi_ = paths{i};
        assert(size(pi_,1) <= MAX_PATH_POINTS, 'path %d exceeds MAX', i);
        assert(size(pi_,2) == 3);
        n_path(i) = size(pi_,1);
        path_pad(1:n_path(i), :, i) = pi_;
    end

    rows = {};
    pid_rows = {};
    rst_rows = {};
    cid = {};
    cases = {};

    function add_case(name, cover, pid, block, do_reset)
        % block: N x 9 [pos_x pos_y pos_z prog u v Uh zdot th]
        n = size(block, 1);
        cases(end+1, :) = {name, cover, n, pid}; %#ok<AGROW>
        for ii = 1:n
            rows{end+1,1} = block(ii,:); %#ok<AGROW>
            pid_rows{end+1,1} = pid; %#ok<AGROW>
            rst_rows{end+1,1} = (ii == 1) && do_reset; %#ok<AGROW>
            cid{end+1,1} = name; %#ok<AGROW>
        end
    end

    % --- C01 cold/open straight ---
    B = zeros(6, 9);
    B(:,1) = (0:5)' * 0.4;  % advance slowly along path
    B(:,3) = 5;
    B(:,4) = 1;
    B(:,5) = 1.5; B(:,6) = 0; B(:,7) = 1.5;
    add_case('C01_cold_open_straight', 'cold;open_straight', 1, B, true);

    % --- C02–C04 U_h / body speed {1.0,1.5,2.0} ---
    for uu = [1.0, 1.5, 2.0]
        B = zeros(4, 9);
        B(:,1) = (0:3)' * 0.5;
        B(:,3) = 5;
        B(:,4) = 1;
        B(:,5) = uu; B(:,6) = 0; B(:,7) = uu;
        add_case(sprintf('C_u_%g', uu), sprintf('U_h=u_body=%g', uu), 1, B, true);
    end

    % --- C05 + cross-track (vehicle North of East-going path => +y_e via n_h) ---
    B = zeros(5, 9);
    B(:,1) = (0:4)' * 0.6;
    B(:,2) = 2.0;   % +Y offset
    B(:,3) = 5;
    B(:,4) = 1;
    B(:,5) = 1.5; B(:,7) = 1.5;
    add_case('C05_cte_pos', 'positive_cross_track', 1, B, true);

    % --- C06 - cross-track ---
    B = zeros(5, 9);
    B(:,1) = (0:4)' * 0.6;
    B(:,2) = -2.0;
    B(:,3) = 5;
    B(:,4) = 1;
    B(:,5) = 1.5; B(:,7) = 1.5;
    add_case('C06_cte_neg', 'negative_cross_track', 1, B, true);

    % --- C07 + depth error (vehicle below path: z_veh > z_path if z down) ---
    % path z=5; vehicle z=7 => cte(3)=+2
    B = zeros(6, 9);
    B(:,1) = (0:5)' * 0.5;
    B(:,3) = 7.0;
    B(:,4) = 1;
    B(:,5) = 1.5; B(:,7) = 1.5;
    add_case('C07_depth_pos', 'positive_depth_error;vehicle_below', 1, B, true);

    % --- C08 - depth error (vehicle above path) ---
    B = zeros(6, 9);
    B(:,1) = (0:5)' * 0.5;
    B(:,3) = 3.0;
    B(:,4) = 1;
    B(:,5) = 1.5; B(:,7) = 1.5;
    add_case('C08_depth_neg', 'negative_depth_error;vehicle_above', 1, B, true);

    % --- C09 multi-segment / curvature ---
    B = zeros(8, 9);
    xy = [0 0; 2 0; 5 1; 8 3; 11 6; 14 10; 16 14; 17 18];
    B(:,1:2) = xy;
    B(:,3) = [5; 5; 4.5; 3.5; 2.5; 1.5; 0.5; 0];
    B(:,4) = 1;
    B(:,5) = 1.5; B(:,7) = 1.5;
    add_case('C09_multiseg_curve', 'multi_segment;curvature', 2, B, true);

    % --- C10 closed-path seam (near origin seam of square) ---
    B = zeros(8, 9);
    % approach seam from last leg (near (0,10)→(0,0)) then wrap
    B(:,1) = [0.2; 0.1; 0.05; 0.02; 0.3; 1.0; 2.0; 3.0];
    B(:,2) = [0.3; 0.15; 0.05; 0.02; 0.2; 0.1; 0.05; 0.0];
    B(:,3) = 5;
    B(:,4) = 1;
    B(:,5) = 1.5; B(:,7) = 1.5;
    add_case('C10_closed_seam', 'closed_path_seam', 3, B, true);

    % --- C11 near-end slowdown ---
    B = zeros(6, 9);
    B(:,1) = [6.5; 7.0; 7.4; 7.7; 7.9; 8.0];
    B(:,3) = 5;
    B(:,4) = 4;
    B(:,5) = 1.5; B(:,7) = 1.5;
    add_case('C11_near_end', 'near_end_slowdown', 4, B, true);

    % --- C12 progress advance then back-snap protection ---
    B = zeros(8, 9);
    B(1:4,1) = [2; 4; 6; 8];   % advance
    B(5:8,1) = [1; 0.5; 0.2; 0]; % try to snap back
    B(:,3) = 5;
    B(:,4) = 1;
    B(:,5) = 1.5; B(:,7) = 1.5;
    add_case('C12_progress_backsnap', 'progress_advance;back_snap_protect', 1, B, true);

    % --- C13 course/yaw wrap +pi ---
    B = zeros(8, 9);
    ang = linspace(0.4, pi - 0.2, 8)';
    B(:,1) = 10*cos(ang);
    B(:,2) = 10*sin(ang);
    B(:,3) = 5;
    B(:,4) = 1;
    B(:,5) = 1.5; B(:,7) = 1.5;
    add_case('C13_yaw_wrap_pos_pi', 'course_yaw_wrap_+pi', 6, B, true);

    % --- C14 course/yaw wrap -pi ---
    B = zeros(8, 9);
    ang = linspace(-0.4, -(pi - 0.2), 8)';
    B(:,1) = 10*cos(ang);
    B(:,2) = 10*sin(ang);
    B(:,3) = 5;
    B(:,4) = 1;
    B(:,5) = 1.5; B(:,7) = 1.5;
    add_case('C14_yaw_wrap_neg_pi', 'course_yaw_wrap_-pi', 7, B, true);

    % --- C15 nonzero sway beta ---
    B = zeros(6, 9);
    B(:,1) = (0:5)' * 0.5;
    B(:,3) = 5;
    B(:,4) = 1;
    B(:,5) = 1.5;
    B(:,6) = 0.45;   % nonzero v_body → beta
    B(:,7) = hypot(1.5, 0.45);
    add_case('C15_beta_sway', 'nonzero_sway_beta', 1, B, true);

    % --- C16 Tur4A/Tur5A/Tur5B inputs @ accepted gains (K_zdot=0,K_gamma=0,α̂ off) ---
    B = zeros(10, 9);
    ang = linspace(0, 1.2, 10)';
    B(:,1) = 10*cos(ang);
    B(:,2) = 10*sin(ang);
    B(:,3) = 5 - 0.15*ang;  % mild climb geometry mismatch
    B(:,4) = 1;
    B(:,5) = 1.5;
    B(:,6) = 0.10;
    B(:,7) = 1.5;
    B(:,8) = -0.20;                 % nonzero zdot_inertial (Tur5A path)
    B(:,9) = deg2rad(3.0);          % nonzero theta_phys (Tur5B alpha log)
    add_case('C16_tur4a5a5b', 'Tur4A_r_ff;Tur5A_zdot;Tur5B_theta_phys;accepted_gains', 8, B, true);

    U = cell2mat(rows);
    assert(all(isfinite(U(:))), 'corpus inputs must be finite');
    path_id_col = cell2mat(pid_rows);
    reset_before = cell2mat(rst_rows);
    case_id = string(cid);
    step_id = (1:size(U,1)).';
    case_table = cell2table(cases, 'VariableNames', {'case_id','coverage','n_steps','path_id'});
    assert(dt > 0);
end

function m = meta_(id, name, n, is_closed, note)
    m = struct('path_id', id, 'name', name, 'n_path', n, 'is_closed', is_closed, 'note', note);
end

function [Y, Dbg] = drive_guidance_sequence_(U, path_pad, n_path, path_id, reset_before)
    N = size(U, 1);
    Y = struct( ...
        'yaw_ref', zeros(N,1), ...
        'pitch_ref', zeros(N,1), ...
        'u_ref', zeros(N,1), ...
        'next_progress_index', zeros(N,1), ...
        'r_ff', zeros(N,1), ...
        'pitch_ref_dot', zeros(N,1));

    dbg0 = blank_diagnostics_();
    fn = fieldnames(dbg0);
    Dbg = dbg0;
    for k = 1:numel(fn)
        Dbg.(fn{k}) = zeros(N, 1);
    end

    for k = 1:N
        if reset_before(k)
            clear guidance_law
        end
        pid = path_id(k);
        np = n_path(pid);
        path_active = path_pad(1:np, :, pid);  % legacy call: active rows only

        pos = U(k, 1:3);
        prog = U(k, 4);
        u_b = U(k, 5);
        v_b = U(k, 6);
        Uh = U(k, 7);
        zd = U(k, 8);
        th = U(k, 9);

        [yaw_ref, pitch_ref, u_ref, next_prog, r_ff, pitch_ref_dot] = guidance_law( ...
            pos, path_active, prog, u_b, v_b, Uh, zd, th);

        Y.yaw_ref(k) = yaw_ref;
        Y.pitch_ref(k) = pitch_ref;
        Y.u_ref(k) = u_ref;
        Y.next_progress_index(k) = next_prog;
        Y.r_ff(k) = r_ff;
        Y.pitch_ref_dot(k) = pitch_ref_dot;

        d = snapshot_diagnostics_();
        for i = 1:numel(fn)
            Dbg.(fn{i})(k) = d.(fn{i});
        end
    end
end

function d = blank_diagnostics_()
% All last_guidance_* / last_* diagnostic globals written by guidance_law.
    d = struct( ...
        'last_guidance_U_h', 0, ...
        'last_guidance_kappa', 0, ...
        'last_r_ff', 0, ...
        'last_gamma_actual', 0, ...
        'last_gamma_path', 0, ...
        'last_alpha_eff', 0, ...
        'last_e_gamma', 0, ...
        'last_e_z', 0, ...
        'last_e_zdot', 0, ...
        'last_zdot_inertial', 0, ...
        'last_alpha_hat', 0);
end

function d = snapshot_diagnostics_()
    global last_guidance_U_h last_guidance_kappa last_r_ff
    global last_gamma_actual last_gamma_path last_alpha_eff last_e_gamma
    global last_e_z last_e_zdot last_zdot_inertial last_alpha_hat

    d = blank_diagnostics_();
    d.last_guidance_U_h = last_guidance_U_h;
    d.last_guidance_kappa = last_guidance_kappa;
    d.last_r_ff = last_r_ff;
    d.last_gamma_actual = last_gamma_actual;
    d.last_gamma_path = last_gamma_path;
    d.last_alpha_eff = last_alpha_eff;
    d.last_e_gamma = last_e_gamma;
    d.last_e_z = last_e_z;
    d.last_e_zdot = last_e_zdot;
    d.last_zdot_inertial = last_zdot_inertial;
    d.last_alpha_hat = last_alpha_hat;
end

function C = evaluate_guidance_checks_(U, Y, Dbg, path_pad, n_path, path_id, reset_before, params, dt)
    C = struct();
    C.all_inputs_finite = all(isfinite(U(:))) && all(isfinite(path_pad(:)));
    C.all_outputs_finite = all(isfinite(Y.yaw_ref)) && all(isfinite(Y.pitch_ref)) && ...
        all(isfinite(Y.u_ref)) && all(isfinite(Y.next_progress_index)) && ...
        all(isfinite(Y.r_ff)) && all(isfinite(Y.pitch_ref_dot));
    fn = fieldnames(Dbg);
    fin_dbg = true;
    for i = 1:numel(fn)
        fin_dbg = fin_dbg && all(isfinite(Dbg.(fn{i})));
    end
    C.all_diagnostics_finite = fin_dbg;

    % Pitch magnitude / rate limits
    C.pitch_within_mag = all(abs(Y.pitch_ref) <= params.pitch_ref_max + 1e-12);
    C.r_ff_within_mag = all(abs(Y.r_ff) <= params.r_ff_max_rad_s + 1e-12);
    dp = [Y.pitch_ref(1); diff(Y.pitch_ref)];
    % Slew check only within non-reset segments (reset may jump refs)
    slew_ok = true;
    max_abs_dp = 0;
    lim = params.pitch_ref_rate_max * dt + 1e-9;
    for k = 2:numel(Y.pitch_ref)
        if reset_before(k)
            continue;
        end
        dpk = abs(Y.pitch_ref(k) - Y.pitch_ref(k-1));
        max_abs_dp = max(max_abs_dp, dpk);
        if dpk > lim + 1e-9
            slew_ok = false;
        end
    end
    C.pitch_slew_ok = slew_ok;
    C.max_abs_dp_step = max_abs_dp;
    C.pitch_slew_limit_rad = params.pitch_ref_rate_max * dt;

    % Progress: open-path next_progress_index nondecreasing within non-reset segments
    prog_ok = true;
    for k = 2:numel(Y.next_progress_index)
        if reset_before(k); continue; end
        pid = path_id(k);
        p_active = path_pad(1:n_path(pid), :, pid);
        is_closed = norm(p_active(1,:) - p_active(end,:)) < 0.25;
        if ~is_closed
            if Y.next_progress_index(k) + 1e-12 < Y.next_progress_index(k-1)
                prog_ok = false;
            end
        end
    end
    C.progress_open_nondecreasing = prog_ok;

    % next_progress_index in [1, n_path]
    idx_ok = true;
    for k = 1:numel(Y.next_progress_index)
        np = n_path(path_id(k));
        v = Y.next_progress_index(k);
        if ~(v >= 1 && v <= np)
            idx_ok = false;
        end
    end
    C.progress_index_in_range = idx_ok;

    % Coverage probes
    C.cover_U_1 = any(abs(U(:,7) - 1.0) < 1e-15);
    C.cover_U_15 = any(abs(U(:,7) - 1.5) < 1e-15);
    C.cover_U_2 = any(abs(U(:,7) - 2.0) < 1e-15);
    C.cover_cte_pos = any(U(:,2) > 1.0);
    C.cover_cte_neg = any(U(:,2) < -1.0);
    C.cover_depth_pos = any(U(:,3) > 6.0);
    C.cover_depth_neg = any(U(:,3) < 4.0);
    C.cover_beta = any(abs(U(:,6)) > 0.2);
    C.cover_zdot = any(abs(U(:,8)) > 0.05);
    C.cover_theta_phys = any(abs(U(:,9)) > 0.01);
    C.cover_tur4a_rff = any(abs(Y.r_ff) > 1e-6) || any(abs(Dbg.last_guidance_kappa) > 1e-6);
    C.cover_near_end_uref = any(Y.u_ref < 0.75 * params.desired_speed + 1e-9);
    C.cover_reset_boundaries = any(reset_before);
    C.cover_yaw_wrap_span = (max(Y.yaw_ref) - min(Y.yaw_ref)) > 0.5;
    C.accepted_K_zdot = abs(params.K_zdot) < 1e-15;
    C.accepted_K_gamma = abs(params.K_gamma) < 1e-15;
    C.accepted_alpha_hat_off = ~params.enable_alpha_hat;

    C.pass_range = C.pitch_within_mag && C.r_ff_within_mag && C.progress_index_in_range;
    C.pass_slew = C.pitch_slew_ok;
    C.pass_progress = C.progress_open_nondecreasing;
end

function write_json_metadata_(path, corpus)
    meta = struct();
    meta.schema_version = corpus.schema_version;
    meta.corpus_id = corpus.corpus_id;
    meta.task_id = corpus.task_id;
    meta.verdict = corpus.verdict;
    meta.next_task = corpus.next_task;
    meta.dt = corpus.dt;
    meta.N_steps = corpus.N_steps;
    meta.N_inputs_call = corpus.N_inputs_call;
    meta.MAX_PATH_POINTS = corpus.MAX_PATH_POINTS;
    meta.input_names = corpus.input_names;
    meta.output_names = corpus.output_names;
    meta.diagnostic_fieldnames = corpus.diagnostic_fieldnames;
    meta.determinism = corpus.determinism;
    meta.source = corpus.source;
    meta.cpp_parity_claimed = corpus.cpp_parity_claimed;
    meta.params_snapshot = corpus.params_snapshot;
    meta.case_ids = cellstr(unique(corpus.case_id, 'stable'));
    meta.n_paths = numel(corpus.n_path);
    meta.n_path = corpus.n_path(:)';
    meta.path_names = {corpus.path_meta.name};
    meta.checks_summary = struct( ...
        'all_inputs_finite', corpus.checks.all_inputs_finite, ...
        'all_outputs_finite', corpus.checks.all_outputs_finite, ...
        'all_diagnostics_finite', corpus.checks.all_diagnostics_finite, ...
        'pass_range', corpus.checks.pass_range, ...
        'pass_slew', corpus.checks.pass_slew, ...
        'pass_progress', corpus.checks.pass_progress, ...
        'cover_U_1', corpus.checks.cover_U_1, ...
        'cover_U_15', corpus.checks.cover_U_15, ...
        'cover_U_2', corpus.checks.cover_U_2, ...
        'cover_cte_pos', corpus.checks.cover_cte_pos, ...
        'cover_cte_neg', corpus.checks.cover_cte_neg, ...
        'cover_depth_pos', corpus.checks.cover_depth_pos, ...
        'cover_depth_neg', corpus.checks.cover_depth_neg, ...
        'cover_beta', corpus.checks.cover_beta, ...
        'cover_zdot', corpus.checks.cover_zdot, ...
        'cover_theta_phys', corpus.checks.cover_theta_phys, ...
        'cover_tur4a_rff', corpus.checks.cover_tur4a_rff, ...
        'cover_near_end_uref', corpus.checks.cover_near_end_uref, ...
        'cover_yaw_wrap_span', corpus.checks.cover_yaw_wrap_span);
    meta.captured_utc = corpus.captured_utc;
    meta.units = corpus.units;
    meta.frames = corpus.frames;
    txt = jsonencode(meta);
    fid = fopen(path, 'w');
    assert(fid > 0, 'json open failed');
    fwrite(fid, txt, 'char');
    fclose(fid);
end

function write_md_report_(path, corpus)
    P = corpus.params_snapshot;
    C = corpus.checks;
    D = corpus.determinism;
    S = corpus.source;
    fid = fopen(path, 'w');
    assert(fid > 0);

    fprintf(fid, '# CG2B_GUIDANCE_GOLDEN_PARITY_CAPTURE\n\n');
    fprintf(fid, '**TASK_ID:** `%s`  \n', corpus.task_id);
    fprintf(fid, '**Corpus:** `%s` (schema_version=%d)  \n', corpus.corpus_id, corpus.schema_version);
    fprintf(fid, '**Mode:** SIMULATION_ONLY · MATLAB-only · no MEX/codegen/compiler  \n');
    fprintf(fid, '**Captured (UTC):** %s  \n', corpus.captured_utc);
    fprintf(fid, '**Hardware:** **NOT_CERTIFIED**  \n');
    fprintf(fid, '**Compiler:** deferred (CG_PRE0 PARTIAL carried)  \n');
    fprintf(fid, '**C++ parity:** **NOT CLAIMED**  \n');
    fprintf(fid, '**CODEX_VERTICAL_PLAN.md:** UNTOUCHED  \n\n');

    fprintf(fid, '> ### Verdict: **%s**\n\n', corpus.verdict);

    fprintf(fid, '| PASS gate | Required | Observed | Met? |\n');
    fprintf(fid, '|---|---|---|---|\n');
    fprintf(fid, '| Deterministic replay (`isequaln` Y+Diagnostics) | yes | outputs=%d diag=%d | %s |\n', ...
        D.isequaln_outputs, D.isequaln_diagnostics, tf(D.pass));
    fprintf(fid, '| Finite outputs (+ diagnostics/inputs) | yes | Y=%d Dbg=%d U=%d | %s |\n', ...
        C.all_outputs_finite, C.all_diagnostics_finite, C.all_inputs_finite, ...
        tf(C.all_outputs_finite && C.all_diagnostics_finite && C.all_inputs_finite));
    fprintf(fid, '| Source fingerprint unchanged | yes | guidance/init match pre=post | %s |\n', ...
        tf(S.fingerprint_unchanged));
    fprintf(fid, '\n**Next exact task (exactly one):** `%s`\n\n', corpus.next_task);

    fprintf(fid, '---\n\n## 1. Corpus dimensions\n\n');
    fprintf(fid, '| Field | Value |\n|---|---:|\n');
    fprintf(fid, '| N_steps | %d |\n', corpus.N_steps);
    fprintf(fid, '| N_inputs_call | %d (full guidance_law arity) |\n', corpus.N_inputs_call);
    fprintf(fid, '| MAX_PATH_POINTS | %d |\n', corpus.MAX_PATH_POINTS);
    fprintf(fid, '| N_paths | %d |\n', numel(corpus.n_path));
    fprintf(fid, '| dt_guidance (forced accepted) | %.6g s |\n', corpus.dt);
    fprintf(fid, '| Diagnostic fields recorded | %d |\n', numel(corpus.diagnostic_fieldnames));
    fprintf(fid, '| Cases | %d |\n', height(corpus.case_table));
    fprintf(fid, '| Replays | 2 (identical `reset_before` + `clear guidance_law`) |\n');
    fprintf(fid, '| MATLAB invocations | 1 |\n\n');

    fprintf(fid, '**Call signature (fixed 8 inputs → 6 outputs):**  \n');
    fprintf(fid, '`[yaw_ref,pitch_ref,u_ref,next_progress_index,r_ff,pitch_ref_dot]=guidance_law(pos,path,prog,u,v,U_h,zdot,theta_phys)`\n\n');
    fprintf(fid, '**Corpus U columns:**  \n`%s` + `path_id` (legacy call uses active `path_pad(1:n_path,:,id)` rows).\n\n', ...
        strjoin(corpus.input_names, ', '));
    fprintf(fid, '**Diagnostic globals recorded:**  \n`%s`\n\n', strjoin(corpus.diagnostic_fieldnames, ', '));

    fprintf(fid, '---\n\n## 2. Coverage matrix\n\n');
    fprintf(fid, '| Case ID | Steps | Path | Coverage tag |\n|---|---:|---:|---|\n');
    for i = 1:height(corpus.case_table)
        fprintf(fid, '| `%s` | %d | %d | %s |\n', ...
            corpus.case_table.case_id{i}, corpus.case_table.n_steps(i), ...
            corpus.case_table.path_id(i), corpus.case_table.coverage{i});
    end
    fprintf(fid, '\n| Probe | Result |\n|---|---|\n');
    fprintf(fid, '| U_h∈{1.0,1.5,2.0} | %d/%d/%d |\n', C.cover_U_1, C.cover_U_15, C.cover_U_2);
    fprintf(fid, '| ± cross-track | %d / %d |\n', C.cover_cte_pos, C.cover_cte_neg);
    fprintf(fid, '| ± depth error | %d / %d |\n', C.cover_depth_pos, C.cover_depth_neg);
    fprintf(fid, '| nonzero sway β | %d |\n', C.cover_beta);
    fprintf(fid, '| nonzero zdot / theta_phys | %d / %d |\n', C.cover_zdot, C.cover_theta_phys);
    fprintf(fid, '| Tur4A κ / r_ff activity | %d |\n', C.cover_tur4a_rff);
    fprintf(fid, '| near-end u_ref slowdown | %d |\n', C.cover_near_end_uref);
    fprintf(fid, '| yaw unwrap span | %d |\n', C.cover_yaw_wrap_span);
    fprintf(fid, '| reset_before boundaries | %d |\n', C.cover_reset_boundaries);
    fprintf(fid, '| accepted K_zdot=0 / K_gamma=0 / α̂ off | %d/%d/%d |\n', ...
        C.accepted_K_zdot, C.accepted_K_gamma, C.accepted_alpha_hat_off);

    fprintf(fid, '\n### Path library (padded MAX×3 + n_path)\n\n');
    fprintf(fid, '| path_id | name | n_path | closed | note |\n|---|---|---:|---|---|\n');
    for i = 1:numel(corpus.path_meta)
        pm = corpus.path_meta(i);
        fprintf(fid, '| %d | `%s` | %d | %d | %s |\n', pm.path_id, pm.name, pm.n_path, pm.is_closed, pm.note);
    end

    fprintf(fid, '\n---\n\n## 3. Source hashes\n\n');
    fprintf(fid, '| File | Bytes | SHA-256 (pre) | Post match |\n|---|---:|---|---|\n');
    fprintf(fid, '| `guidance_law.m` | %d | `%s` | %s |\n', ...
        S.guidance_law_bytes, S.guidance_law_sha256, tf(strcmp(S.guidance_law_sha256, S.guidance_law_sha256_post)));
    fprintf(fid, '| `init_parameters.m` | %d | `%s` | %s |\n', ...
        S.init_parameters_bytes, S.init_parameters_sha256, tf(strcmp(S.init_parameters_sha256, S.init_parameters_sha256_post)));

    fprintf(fid, '\n---\n\n## 4. Parameter snapshot (accepted)\n\n');
    fprintf(fid, '| Param | Value |\n|---|---:|\n');
    fprintf(fid, '| dt_guidance | %.12g |\n', P.dt_guidance);
    fprintf(fid, '| dt_controller | %.12g |\n', P.dt_controller);
    fprintf(fid, '| lookahead_distance | %.12g |\n', P.lookahead_distance);
    fprintf(fid, '| desired_speed | %.12g |\n', P.desired_speed);
    fprintf(fid, '| pitch_ref_max / rate_max [rad]/[rad/s] | %.12g / %.12g |\n', P.pitch_ref_max, P.pitch_ref_rate_max);
    fprintf(fid, '| K_zdot (accepted Tur5A) | %.12g |\n', P.K_zdot);
    fprintf(fid, '| K_gamma (accepted Tur5B) | %.12g |\n', P.K_gamma);
    fprintf(fid, '| enable_alpha_hat | %d |\n', P.enable_alpha_hat);
    fprintf(fid, '| k_beta (frozen literal) | %.12g |\n', P.k_beta);
    fprintf(fid, '| MAX_PATH_POINTS (corpus) | %d |\n', P.MAX_PATH_POINTS);

    fprintf(fid, '\n---\n\n## 5. Finite / range / slew / progress checks\n\n');
    fprintf(fid, '| Check | Pass |\n|---|---|\n');
    fprintf(fid, '| Inputs finite | %s |\n', tf(C.all_inputs_finite));
    fprintf(fid, '| Outputs finite | %s |\n', tf(C.all_outputs_finite));
    fprintf(fid, '| Diagnostics finite | %s |\n', tf(C.all_diagnostics_finite));
    fprintf(fid, '| |pitch_ref| ≤ pitch_ref_max | %s |\n', tf(C.pitch_within_mag));
    fprintf(fid, '| |r_ff| ≤ 40°/s | %s |\n', tf(C.r_ff_within_mag));
    fprintf(fid, '| pitch slew ≤ rate_max·dt (non-reset) | %s (max step %.6g vs lim %.6g) |\n', ...
        tf(C.pitch_slew_ok), C.max_abs_dp_step, C.pitch_slew_limit_rad);
    fprintf(fid, '| open-path progress nondecreasing | %s |\n', tf(C.progress_open_nondecreasing));
    fprintf(fid, '| next_progress_index ∈ [1,n_path] | %s |\n', tf(C.progress_index_in_range));

    fprintf(fid, '\n---\n\n## 6. Determinism\n\n');
    fprintf(fid, 'Within one MATLAB process: replay A with `clear guidance_law` at each `reset_before`, ');
    fprintf(fid, 'then `clear guidance_law` and replay B with identical resets on identical `U`/paths.\n\n');
    fprintf(fid, '| Item | `isequaln` |\n|---|---|\n');
    fprintf(fid, '| Outputs (6) | %s |\n', tf(D.isequaln_outputs));
    fprintf(fid, '| Diagnostics (all last_* globals) | %s |\n', tf(D.isequaln_diagnostics));
    fprintf(fid, '| Determinism PASS | %s |\n', tf(D.pass));

    fprintf(fid, '\n---\n\n## 7. Artifacts\n\n');
    fprintf(fid, '| Path | Role |\n|---|---|\n');
    fprintf(fid, '| `suite_results/CG2B_GUIDANCE_GOLDEN_V1.mat` | lean versioned corpus (U,paths,Y,Diagnostics,params,det,checks) |\n');
    fprintf(fid, '| `suite_results/CG2B_GUIDANCE_GOLDEN_V1.json` | schema/hashes/determinism metadata |\n');
    fprintf(fid, '| `run_cg2b_guidance_golden_parity_capture.m` | SIMULATION_ONLY harness |\n');
    fprintf(fid, '| `guidance_law.m` / `init_parameters.m` | **UNTOUCHED** |\n\n');

    fprintf(fid, '**Units/frames:** position/path m NED; speeds m/s BODY or NED-horiz as named; angles rad; ');
    fprintf(fid, '`yaw_ref` continuous unwrap; Tur4A `r_ff=U_h*κ`; Tur5A/B inputs exercised at accepted K_zdot=0, K_gamma=0, enable_alpha_hat=false.\n\n');
    fprintf(fid, 'Rejected methods remain closed (γ-structural / LADRC / INDI / crab-current-FF / polyline substitutes). ');
    fprintf(fid, 'No production call-path change. This capture is a MATLAB golden twin baseline — **not** C++ parity.\n\n');
    fprintf(fid, '---\n\n*End of CG2B_GUIDANCE_GOLDEN_PARITY_CAPTURE. Verdict: **%s**. Next: `%s`.*\n', ...
        corpus.verdict, corpus.next_task);
    fclose(fid);
end

function s = tf(b)
    if b; s = 'YES'; else; s = 'NO'; end
end

function h = local_sha256_file(path)
    if exist('java.security.MessageDigest', 'class')
        md = java.security.MessageDigest.getInstance('SHA-256');
        fid = fopen(path, 'r');
        assert(fid > 0, 'open failed: %s', path);
        cleaner = onCleanup(@() fclose(fid)); %#ok<NASGU>
        while true
            [buf, n] = fread(fid, 1024*1024, '*uint8');
            if n < 1; break; end
            md.update(buf);
        end
        h = sprintf('%02x', typecast(md.digest, 'uint8'));
    else
        [status, out] = system(sprintf('sha256sum %s', path));
        assert(status == 0, 'sha256 failed');
        h = strtok(out);
    end
end

function n = local_file_bytes(path)
    d = dir(path);
    assert(~isempty(d), 'missing %s', path);
    n = d(1).bytes;
end
