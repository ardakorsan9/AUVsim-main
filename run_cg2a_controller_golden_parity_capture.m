function run_cg2a_controller_golden_parity_capture()
% RUN_CG2A_CONTROLLER_GOLDEN_PARITY_CAPTURE
% SIMULATION_ONLY — golden corpus capture for accepted controller_law.
% Does NOT modify production call paths, gains, controller_law.m, or init_parameters.m.
% No MEX / codegen / compiler. One-shot host capture + in-process determinism replay.
%
% TASK_ID: CG2A_CONTROLLER_GOLDEN_PARITY_CAPTURE_001

    task_id = 'CG2A_CONTROLLER_GOLDEN_PARITY_CAPTURE_001';
    corpus_id = 'CG2A_CONTROLLER_GOLDEN_V1';
    schema_version = 1;
    out_mat = fullfile('suite_results', 'CG2A_CONTROLLER_GOLDEN_V1.mat');
    out_json = fullfile('suite_results', 'CG2A_CONTROLLER_GOLDEN_V1.json');
    out_md = fullfile('suite_results', 'CG2A_CONTROLLER_GOLDEN_PARITY_CAPTURE.md');

    fprintf('[%s] start (SIMULATION_ONLY)\n', task_id);

    % ----- Source fingerprints (must be unchanged by this harness) -----
    src_ctrl = 'controller_law.m';
    src_init = 'init_parameters.m';
    sha_ctrl_pre = local_sha256_file(src_ctrl);
    sha_init_pre = local_sha256_file(src_init);
    bytes_ctrl = local_file_bytes(src_ctrl);
    bytes_init = local_file_bytes(src_init);

    % ----- Accepted parameter setup (no production file edits) -----
    init_parameters();
    force_accepted_controller_globals_();

    params = snapshot_controller_params_();
    dt = params.dt_controller;  % forced accepted fixed dt

    % ----- Fixed 13-input scalar sequences (valid finite only) -----
    [U, case_id, step_id, case_table, input_names, units, frames] = build_fixed_input_corpus_(dt);
    N = size(U, 1);

    % ----- Replay A -----
    clear controller_law
    [Ya, Dbga] = drive_controller_sequence_(U);

    % ----- Replay B (clear ONLY controller_law; globals/params preserved) -----
    clear controller_law
    [Yb, Dbgb] = drive_controller_sequence_(U);

    % ----- Determinism (exact) -----
    det = struct();
    det.isequaln_inputs = isequaln(U, U);  % identity anchor
    det.isequaln_outputs = isequaln(Ya, Yb);
    det.isequaln_debug = isequaln(Dbga, Dbgb);
    det.pass = det.isequaln_outputs && det.isequaln_debug;
    % Prefer A as canonical corpus (B only for equality)
    Y = Ya;
    Dbg = Dbga;

    % ----- Finite / bounds / slew checks on canonical replay -----
    checks = evaluate_corpus_checks_(U, Y, Dbg, params, dt);

    sha_ctrl_post = local_sha256_file(src_ctrl);
    sha_init_post = local_sha256_file(src_init);
    fingerprint_unchanged = strcmp(sha_ctrl_pre, sha_ctrl_post) && strcmp(sha_init_pre, sha_init_post);

    finite_ok = checks.all_outputs_finite && checks.all_debug_finite && checks.all_inputs_finite;
    if det.pass && finite_ok && fingerprint_unchanged
        verdict = 'PASS';
        next_task = 'CG2A_CONTROLLER_EXPLICIT_STATE_PROTOTYPE_001';
    elseif fingerprint_unchanged && (det.pass || finite_ok)
        verdict = 'PARTIAL';
        next_task = 'CG2A_CONTROLLER_GOLDEN_PARITY_CAPTURE_REPAIR_001';
    else
        verdict = 'FAIL';
        next_task = 'CG2A_CONTROLLER_GOLDEN_PARITY_CAPTURE_REPAIR_001';
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
    corpus.N_inputs = 13;
    corpus.input_names = input_names;
    corpus.units = units;
    corpus.frames = frames;
    corpus.case_table = case_table;
    corpus.case_id = case_id;
    corpus.step_id = step_id;
    corpus.U = U;
    corpus.Y = Y;
    corpus.Debug = Dbg;
    corpus.params_snapshot = params;
    corpus.determinism = det;
    corpus.checks = checks;
    corpus.source = struct( ...
        'controller_law_bytes', bytes_ctrl, ...
        'controller_law_sha256', sha_ctrl_pre, ...
        'controller_law_sha256_post', sha_ctrl_post, ...
        'init_parameters_bytes', bytes_init, ...
        'init_parameters_sha256', sha_init_pre, ...
        'init_parameters_sha256_post', sha_init_post, ...
        'fingerprint_unchanged', fingerprint_unchanged);
    corpus.verdict = verdict;
    corpus.next_task = next_task;
    corpus.captured_utc = char(datetime('now', 'TimeZone', 'UTC', 'Format', 'yyyy-MM-dd''T''HH:mm:ss''Z'''));
    corpus.debug_fieldnames = fieldnames(Dbg)';

    if ~exist('suite_results', 'dir'); mkdir('suite_results'); end
    save(out_mat, 'corpus', '-v7');
    write_json_metadata_(out_json, corpus);
    write_md_report_(out_md, corpus);

    fprintf('[%s] verdict=%s N=%d det=%d finite=%d fp=%d -> %s\n', ...
        task_id, verdict, N, det.pass, finite_ok, fingerprint_unchanged, out_mat);
    fprintf('[%s] next=%s\n', task_id, next_task);
end

% =====================================================================
function force_accepted_controller_globals_()
% Force accepted production controller config used by golden capture.
% Does not edit init_parameters.m / controller_law.m sources.
    global dt_controller tau_rate
    global Kp_roll
    global lambda_muw_ff muw_ff_u_min muw_ff_u_lo muw_ff_u_hi muw_ff_clamp_deg
    global Muw Muuds elevator_sign
    global trim_speed_table trim_elevator_table

    % Accepted fixed controller sample time (init_parameters production value)
    dt_controller = 0.025;

    % Accepted roll-rate damp (YAW_ROLL_DAMPING_BACKOFF PASS)
    Kp_roll = 0.605072;

    % Accepted Tur-3 Muw FF setting (production identity: λ=0 => FF off)
    lambda_muw_ff = 0;
    if isempty(muw_ff_u_min); muw_ff_u_min = 0.50; end
    if isempty(muw_ff_u_lo);  muw_ff_u_lo  = 0.70; end
    if isempty(muw_ff_u_hi);  muw_ff_u_hi  = 1.20; end
    if isempty(muw_ff_clamp_deg); muw_ff_clamp_deg = 4.0; end

    % Ensure hydro coeffs present (init_parameters sets these; reaffirm)
    if isempty(Muw); Muw = 24; end
    if isempty(Muuds); Muuds = -6.15; end
    if isempty(elevator_sign); elevator_sign = 1; end
    if isempty(trim_speed_table) || isempty(trim_elevator_table)
        trim_speed_table = [0.8 1.0 1.5 2.0];
        trim_elevator_table = deg2rad([-9.18 -7.33 -4.62 -3.17]);
    end

    % tau_rate left as set by init_parameters (accepted Tur12 = 0.05 s)
    assert(~isempty(tau_rate) && isfinite(tau_rate) && tau_rate > 0, 'tau_rate missing');
    assert(abs(dt_controller - 0.025) < 1e-15, 'dt_controller must be accepted 0.025');
end

function P = snapshot_controller_params_()
    global Kp_psi Kd_psi Kp_x Kp_roll
    global Kp_angle Ki_angle Kp_rate Ki_rate Kaw_pitch Kd_rate Kd_damp
    global delta_r_max delta_e_max thrust_max thrust_min thrust_trim
    global trim_speed_table trim_elevator_table elevator_sign
    global dt_controller tau_rate
    global Muw Muuds
    global lambda_muw_ff muw_ff_u_min muw_ff_u_lo muw_ff_u_hi muw_ff_clamp_deg
    global delta_e_trim

    P = struct();
    P.Kp_psi = Kp_psi; P.Kd_psi = Kd_psi; P.Kp_x = Kp_x;
    P.Kp_roll = Kp_roll;
    P.Kp_angle = Kp_angle; P.Ki_angle = Ki_angle;
    P.Kp_rate = Kp_rate; P.Ki_rate = Ki_rate;
    P.Kaw_pitch = Kaw_pitch; P.Kd_rate = Kd_rate; P.Kd_damp = Kd_damp;
    P.delta_r_max = delta_r_max; P.delta_e_max = delta_e_max;
    P.thrust_max = thrust_max; P.thrust_min = thrust_min; P.thrust_trim = thrust_trim;
    P.trim_speed_table = trim_speed_table(:).';
    P.trim_elevator_table = trim_elevator_table(:).';
    P.elevator_sign = elevator_sign;
    P.dt_controller = dt_controller;
    P.tau_rate = tau_rate;
    P.Muw = Muw; P.Muuds = Muuds;
    P.lambda_muw_ff = lambda_muw_ff;
    P.muw_ff_u_min = muw_ff_u_min;
    P.muw_ff_u_lo = muw_ff_u_lo;
    P.muw_ff_u_hi = muw_ff_u_hi;
    P.muw_ff_clamp_deg = muw_ff_clamp_deg;
    if ~isempty(delta_e_trim); P.delta_e_trim = delta_e_trim; else; P.delta_e_trim = NaN; end
    % Frozen literals from controller_law (behaviour anchors; not globals)
    P.k_gamma_climb = 0.1320695001;
    P.de_climb_lim = deg2rad(2.8793);
    P.slew_max_rad_s = deg2rad(40);
end

function [U, case_id, step_id, case_table, input_names, units, frames] = build_fixed_input_corpus_(dt)
% Columns: yaw_ref pitch_ref u_ref psi theta r q u r_ff pitch_ref_dot phi w p
    input_names = { ...
        'yaw_ref','pitch_ref','u_ref','psi','theta','r','q','u', ...
        'r_ff','pitch_ref_dot','phi','w','p'};
    units = struct( ...
        'yaw_ref','rad', 'pitch_ref','rad_physical', 'u_ref','m/s', ...
        'psi','rad', 'theta','rad_sim_convention', 'r','rad/s_BODY', ...
        'q','rad/s_BODY', 'u','m/s_BODY', 'r_ff','rad/s', ...
        'pitch_ref_dot','rad/s_physical', 'phi','rad', 'w','m/s_BODY', ...
        'p','rad/s_BODY', 'delta_r','rad', 'delta_e','rad', 'thrust','N', ...
        'dt','s');
    frames = struct( ...
        'attitude','BODY/NED as in controller_law comments', ...
        'theta_phys','theta_phys = -theta', ...
        'rates','BODY (p,q,r)', ...
        'surfaces','rudder/elevator rad, positive per elevator_sign');

    rows = {};
    cases = {};
    cid = {};
    % Helper to append a block
    function add_case(name, cover, block)
        n = size(block, 1);
        cases(end+1, :) = {name, cover, n}; %#ok<AGROW>
        for ii = 1:n
            rows{end+1,1} = block(ii,:); %#ok<AGROW>
            cid{end+1,1} = name; %#ok<AGROW>
        end
    end

    z = zeros(1, 13);

    % C01 cold nominal @ U=1.5
    B = repmat(z, 6, 1);
    B(:,3) = 1.5; B(:,8) = 1.5;
    add_case('C01_cold_nominal', 'cold_nominal;U=1.5', B);

    % C02–C04 trim/speed schedule U={1.0,1.5,2.0}
    for uu = [1.0, 1.5, 2.0]
        B = repmat(z, 4, 1);
        B(:,3) = uu; B(:,8) = uu;
        B(:,2) = deg2rad(1.0);           % small physical pitch ref
        B(:,5) = -deg2rad(0.5);          % theta => theta_phys=+0.5 deg
        add_case(sprintf('C_u_%g', uu), sprintf('U=%g;trim_lookup', uu), B);
    end

    % C05 yaw wrap +pi boundary (wrapToPi of error near +pi)
    B = repmat(z, 5, 1);
    B(:,3) = 1.5; B(:,8) = 1.5;
    B(:,1) = pi;                 % yaw_ref
    B(:,4) = -0.02;              % psi => raw err ≈ pi+0.02 → wraps negative
    B(:,6) = 0.05;               % mild r
    add_case('C05_yaw_wrap_pos_pi', 'yaw_wrap_+pi_boundary', B);

    % C06 yaw wrap -pi boundary
    B = repmat(z, 5, 1);
    B(:,3) = 1.5; B(:,8) = 1.5;
    B(:,1) = -pi;
    B(:,4) = 0.02;               % raw err ≈ -pi-0.02 → wraps positive
    B(:,6) = -0.05;
    add_case('C06_yaw_wrap_neg_pi', 'yaw_wrap_-pi_boundary', B);

    % C07 climb
    B = repmat(z, 8, 1);
    B(:,3) = 1.5; B(:,8) = 1.5;
    B(:,2) = deg2rad(12);        % physical climb pitch_ref
    B(:,5) = -deg2rad(2);        % theta_phys = +2 deg
    B(:,10) = deg2rad(2);        % pitch_ref_dot
    B(:,7) = deg2rad(-1);        % q (sim) → contributes to theta_phys_dot
    add_case('C07_climb', 'climb;pitch_ref>0;climb_ff', B);

    % C08 descent
    B = repmat(z, 8, 1);
    B(:,3) = 1.5; B(:,8) = 1.5;
    B(:,2) = deg2rad(-12);
    B(:,5) = deg2rad(2);         % theta_phys = -2 deg
    B(:,10) = deg2rad(-2);
    B(:,7) = deg2rad(1);
    add_case('C08_descent', 'descent;pitch_ref<0;climb_ff', B);

    % C09 rudder magnitude + 40 deg/s slew (large yaw error, cold-ish surfaces continue)
    B = repmat(z, 12, 1);
    B(:,3) = 1.5; B(:,8) = 1.5;
    B(:,1) = deg2rad(90);        % large heading error → mag + slew on rudder
    B(:,4) = 0;
    B(:,6) = 0;
    add_case('C09_rudder_mag_slew', 'rudder_magnitude;slew_40dps', B);

    % C10 elevator magnitude + 40 deg/s slew
    B = repmat(z, 12, 1);
    B(:,3) = 1.5; B(:,8) = 1.5;
    B(:,2) = deg2rad(25);        % large pitch demand
    B(:,5) = deg2rad(10);        % theta_phys = -10 deg → large e_theta
    B(:,10) = deg2rad(6);
    add_case('C10_elevator_mag_slew', 'elevator_magnitude;slew_40dps', B);

    % C11 pitch integrator / anti-windup memory
    % sustained angle error then hard saturation demand
    B = repmat(z, 16, 1);
    B(:,3) = 1.5; B(:,8) = 1.5;
    B(1:10, 2) = deg2rad(8);
    B(1:10, 5) = 0;
    B(11:16, 2) = deg2rad(26);
    B(11:16, 5) = deg2rad(15);   % theta_phys=-15 → large error + sat pressure
    add_case('C11_pitch_I_AW', 'pitch_integrator;anti_windup_memory', B);

    % C12 roll-rate damping (nonzero BODY p)
    B = repmat(z, 8, 1);
    B(:,3) = 1.5; B(:,8) = 1.5;
    B(:,1) = deg2rad(5);
    B(:,4) = 0;
    B(:,13) = deg2rad(20);       % p = 20 deg/s → dr_p = -Kp_roll*p
    B(:,6) = deg2rad(2);         % r for g_ac schedule
    add_case('C12_roll_rate_damp', 'roll_rate_damping;Kp_roll', B);

    % C13 nonzero w with accepted lambda_muw_ff (=0 production)
    B = repmat(z, 8, 1);
    B(:,3) = 1.5; B(:,8) = 1.5;  % u in band for b_u schedule
    B(:,12) = 0.35;              % nonzero heave
    B(:,2) = deg2rad(3);
    B(:,5) = -deg2rad(1);
    add_case('C13_muw_w_lambda0', 'nonzero_w;accepted_lambda_muw_ff=0', B);

    U = cell2mat(rows);
    assert(all(isfinite(U(:))), 'corpus inputs must be finite');
    case_id = string(cid);
    step_id = (1:size(U,1)).';
    case_table = cell2table(cases, 'VariableNames', {'case_id','coverage','n_steps'});

    % dt unused in builder except documentation of slew intent
    assert(dt > 0);
end

function [Y, Dbg] = drive_controller_sequence_(U)
    N = size(U, 1);
    Y = struct('delta_r', zeros(N,1), 'delta_e', zeros(N,1), 'thrust', zeros(N,1));
    % Pre-allocate debug from first-call field contract (fixed)
    dbg0 = blank_debug_();
    fn = fieldnames(dbg0);
    Dbg = dbg0;
    for k = 1:numel(fn)
        Dbg.(fn{k}) = zeros(N, 1);
    end

    for k = 1:N
        in = U(k, :);
        [dr, de, thr, dbg] = controller_law( ...
            in(1), in(2), in(3), in(4), in(5), in(6), in(7), in(8), ...
            in(9), in(10), in(11), in(12), in(13));
        Y.delta_r(k) = dr;
        Y.delta_e(k) = de;
        Y.thrust(k) = thr;
        for i = 1:numel(fn)
            Dbg.(fn{i})(k) = dbg.(fn{i});
        end
    end
end

function dbg = blank_debug_()
% Fixed Debug field set from controller_law nargout>=4 contract.
    dbg = struct( ...
        'e_theta', 0, ...
        'theta_phys', 0, ...
        'theta_phys_dot', 0, ...
        'int_angle', 0, ...
        'int_angle_max', 0, ...
        'int_rate', 0, ...
        'de_trim', 0, ...
        'de_uw_ff', 0, ...
        'de_fb', 0, ...
        'delta_e_angle_I', 0, ...
        'delta_e_cmd', 0, ...
        'delta_e_unsat', 0, ...
        'M_uw', 0, ...
        'M_elev', 0, ...
        'M_e_ff', 0, ...
        'G_de', 0, ...
        'b_u', 0, ...
        'rate_filt', 0, ...
        'theta_rate_cmd', 0, ...
        'mag_sat', 0, ...
        'p', 0, ...
        'e_psi', 0, ...
        'e_r', 0, ...
        'dr_yaw', 0, ...
        'dr_p', 0, ...
        'dr_damp', 0, ...
        'g_ac', 0, ...
        'delta_r_cmd', 0, ...
        'delta_r', 0, ...
        'Kp_roll', 0);
end

function C = evaluate_corpus_checks_(U, Y, Dbg, params, dt)
    C = struct();
    C.all_inputs_finite = all(isfinite(U(:)));
    C.all_outputs_finite = all(isfinite(Y.delta_r)) && all(isfinite(Y.delta_e)) && all(isfinite(Y.thrust));
    fn = fieldnames(Dbg);
    fin_dbg = true;
    for i = 1:numel(fn)
        fin_dbg = fin_dbg && all(isfinite(Dbg.(fn{i})));
    end
    C.all_debug_finite = fin_dbg;

    % Magnitude bounds (commanded surfaces after slew; thrust clamps)
    C.delta_r_within_mag = all(abs(Y.delta_r) <= params.delta_r_max + 1e-12);
    C.delta_e_within_mag = all(abs(Y.delta_e) <= params.delta_e_max + 1e-12);
    C.thrust_within_bounds = all(Y.thrust <= params.thrust_max + 1e-12) && ...
        all(Y.thrust >= params.thrust_min - 1e-12);

    % Slew: |Δcmd|/dt <= 40 deg/s + tiny tol (first step vs 0 cold)
    max_slew = deg2rad(40) * dt + 1e-12;
    dr = [Y.delta_r(1); diff(Y.delta_r)];
    de = [Y.delta_e(1); diff(Y.delta_e)];
    C.rudder_slew_ok = all(abs(dr) <= max_slew + 1e-9);
    C.elevator_slew_ok = all(abs(de) <= max_slew + 1e-9);
    C.max_abs_dr_step = max(abs(dr));
    C.max_abs_de_step = max(abs(de));
    C.slew_limit_rad = deg2rad(40) * dt;

    % Coverage probes (evidence that sequences exercised intended paths)
    C.cover_yaw_wrap = any(abs(abs(Dbg.e_psi) - pi) < 0.05) || any(abs(Dbg.e_psi) > 3.0);
    C.cover_climb = any(U(:,2) > deg2rad(5));
    C.cover_descent = any(U(:,2) < -deg2rad(5));
    C.cover_roll_damp = any(abs(U(:,13)) > 0) && any(abs(Dbg.dr_damp) > 0);
    C.cover_muw_w = any(abs(U(:,12)) > 0) && any(abs(Dbg.M_uw) > 0);
    C.cover_lambda_accepted = abs(params.lambda_muw_ff) < 1e-15;
    C.cover_muw_ff_identity = all(abs(Dbg.de_uw_ff) < 1e-15);  % λ=0
    C.cover_U_1 = any(abs(U(:,8) - 1.0) < 1e-15);
    C.cover_U_15 = any(abs(U(:,8) - 1.5) < 1e-15);
    C.cover_U_2 = any(abs(U(:,8) - 2.0) < 1e-15);
    C.cover_mag_or_slew_r = any(abs(Dbg.delta_r_cmd) >= params.delta_r_max - 1e-9) || ...
        any(abs(dr) >= deg2rad(40)*dt - 1e-9);
    C.cover_mag_or_slew_e = any(Dbg.mag_sat > 0.5) || ...
        any(abs(de) >= deg2rad(40)*dt - 1e-9);
    C.cover_pitch_I = any(abs(Dbg.int_angle) > 0);
    C.cover_AW = any(abs(Dbg.delta_e_cmd - Dbg.delta_e_unsat) > 1e-6);

    C.pass_bounds = C.delta_r_within_mag && C.delta_e_within_mag && C.thrust_within_bounds;
    C.pass_slew = C.rudder_slew_ok && C.elevator_slew_ok;
end

function write_json_metadata_(path, corpus)
% Lean JSON metadata (no full time series) for schema/hashes/determinism.
    meta = struct();
    meta.schema_version = corpus.schema_version;
    meta.corpus_id = corpus.corpus_id;
    meta.task_id = corpus.task_id;
    meta.verdict = corpus.verdict;
    meta.next_task = corpus.next_task;
    meta.dt = corpus.dt;
    meta.N_steps = corpus.N_steps;
    meta.N_inputs = corpus.N_inputs;
    meta.input_names = corpus.input_names;
    meta.debug_fieldnames = corpus.debug_fieldnames;
    meta.determinism = corpus.determinism;
    meta.source = corpus.source;
    meta.cpp_parity_claimed = corpus.cpp_parity_claimed;
    meta.params_snapshot = corpus.params_snapshot;
    meta.case_ids = cellstr(unique(corpus.case_id, 'stable'));
    meta.checks_summary = struct( ...
        'all_inputs_finite', corpus.checks.all_inputs_finite, ...
        'all_outputs_finite', corpus.checks.all_outputs_finite, ...
        'all_debug_finite', corpus.checks.all_debug_finite, ...
        'pass_bounds', corpus.checks.pass_bounds, ...
        'pass_slew', corpus.checks.pass_slew, ...
        'cover_yaw_wrap', corpus.checks.cover_yaw_wrap, ...
        'cover_climb', corpus.checks.cover_climb, ...
        'cover_descent', corpus.checks.cover_descent, ...
        'cover_roll_damp', corpus.checks.cover_roll_damp, ...
        'cover_muw_w', corpus.checks.cover_muw_w, ...
        'cover_pitch_I', corpus.checks.cover_pitch_I, ...
        'cover_AW', corpus.checks.cover_AW);
    meta.captured_utc = corpus.captured_utc;
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

    fprintf(fid, '# CG2A_CONTROLLER_GOLDEN_PARITY_CAPTURE\n\n');
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
    fprintf(fid, '| Deterministic replay (`isequaln` Y+Debug) | yes | outputs=%d debug=%d | %s |\n', ...
        D.isequaln_outputs, D.isequaln_debug, tf(D.pass));
    fprintf(fid, '| Finite outputs (+ debug/inputs) | yes | Y=%d Dbg=%d U=%d | %s |\n', ...
        C.all_outputs_finite, C.all_debug_finite, C.all_inputs_finite, ...
        tf(C.all_outputs_finite && C.all_debug_finite && C.all_inputs_finite));
    fprintf(fid, '| Source fingerprint unchanged | yes | ctrl/init match pre=post | %s |\n', ...
        tf(S.fingerprint_unchanged));
    fprintf(fid, '\n**Next exact task (exactly one):** `%s`\n\n', corpus.next_task);

    fprintf(fid, '---\n\n## 1. Corpus dimensions\n\n');
    fprintf(fid, '| Field | Value |\n|---|---:|\n');
    fprintf(fid, '| N_steps | %d |\n', corpus.N_steps);
    fprintf(fid, '| N_inputs | %d |\n', corpus.N_inputs);
    fprintf(fid, '| dt_controller (forced accepted) | %.6g s |\n', corpus.dt);
    fprintf(fid, '| Debug fields recorded | %d |\n', numel(corpus.debug_fieldnames));
    fprintf(fid, '| Cases | %d |\n', height(corpus.case_table));
    fprintf(fid, '| Replays | 2 (clear `controller_law` between) |\n');
    fprintf(fid, '| MATLAB invocations | 1 |\n\n');

    fprintf(fid, '**Input columns (fixed order):**  \n');
    fprintf(fid, '`%s`\n\n', strjoin(corpus.input_names, ', '));

    fprintf(fid, '**Debug fields (every fixed field):**  \n');
    fprintf(fid, '`%s`\n\n', strjoin(corpus.debug_fieldnames, ', '));

    fprintf(fid, '---\n\n## 2. Coverage matrix\n\n');
    fprintf(fid, '| Case ID | Steps | Coverage tag |\n|---|---:|---|\n');
    for i = 1:height(corpus.case_table)
        fprintf(fid, '| `%s` | %d | %s |\n', ...
            corpus.case_table.case_id{i}, corpus.case_table.n_steps(i), corpus.case_table.coverage{i});
    end
    fprintf(fid, '\n| Probe | Result |\n|---|---|\n');
    fprintf(fid, '| U∈{1.0,1.5,2.0} | %d/%d/%d |\n', C.cover_U_1, C.cover_U_15, C.cover_U_2);
    fprintf(fid, '| yaw wrap ±π | %d |\n', C.cover_yaw_wrap);
    fprintf(fid, '| climb / descent | %d / %d |\n', C.cover_climb, C.cover_descent);
    fprintf(fid, '| rudder mag/slew | %d |\n', C.cover_mag_or_slew_r);
    fprintf(fid, '| elevator mag/slew | %d |\n', C.cover_mag_or_slew_e);
    fprintf(fid, '| pitch I memory | %d |\n', C.cover_pitch_I);
    fprintf(fid, '| AW activity | %d |\n', C.cover_AW);
    fprintf(fid, '| roll-rate damp | %d |\n', C.cover_roll_damp);
    fprintf(fid, '| nonzero w + M_uw | %d |\n', C.cover_muw_w);
    fprintf(fid, '| accepted λ_muw_ff=0 | %d |\n', C.cover_lambda_accepted);
    fprintf(fid, '| de_uw_ff identity (λ=0) | %d |\n', C.cover_muw_ff_identity);

    fprintf(fid, '\n---\n\n## 3. Source hashes\n\n');
    fprintf(fid, '| File | Bytes | SHA-256 (pre) | Post match |\n|---|---:|---|---|\n');
    fprintf(fid, '| `controller_law.m` | %d | `%s` | %s |\n', ...
        S.controller_law_bytes, S.controller_law_sha256, tf(strcmp(S.controller_law_sha256, S.controller_law_sha256_post)));
    fprintf(fid, '| `init_parameters.m` | %d | `%s` | %s |\n', ...
        S.init_parameters_bytes, S.init_parameters_sha256, tf(strcmp(S.init_parameters_sha256, S.init_parameters_sha256_post)));

    fprintf(fid, '\n---\n\n## 4. Parameter snapshot (accepted)\n\n');
    fprintf(fid, '| Param | Value |\n|---|---:|\n');
    fprintf(fid, '| dt_controller | %.12g |\n', P.dt_controller);
    fprintf(fid, '| tau_rate | %.12g |\n', P.tau_rate);
    fprintf(fid, '| Kp_psi / Kd_psi / Kp_x | %.12g / %.12g / %.12g |\n', P.Kp_psi, P.Kd_psi, P.Kp_x);
    fprintf(fid, '| Kp_roll | %.12g |\n', P.Kp_roll);
    fprintf(fid, '| Kp_angle / Ki_angle | %.12g / %.12g |\n', P.Kp_angle, P.Ki_angle);
    fprintf(fid, '| Kp_rate / Ki_rate / Kaw_pitch | %.12g / %.12g / %.12g |\n', P.Kp_rate, P.Ki_rate, P.Kaw_pitch);
    fprintf(fid, '| Kd_rate / Kd_damp | %.12g / %.12g |\n', P.Kd_rate, P.Kd_damp);
    fprintf(fid, '| delta_r_max / delta_e_max [rad] | %.12g / %.12g |\n', P.delta_r_max, P.delta_e_max);
    fprintf(fid, '| thrust_trim / min / max | %.12g / %.12g / %.12g |\n', P.thrust_trim, P.thrust_min, P.thrust_max);
    fprintf(fid, '| elevator_sign | %.12g |\n', P.elevator_sign);
    fprintf(fid, '| Muw / Muuds | %.12g / %.12g |\n', P.Muw, P.Muuds);
    fprintf(fid, '| lambda_muw_ff (accepted) | %.12g |\n', P.lambda_muw_ff);
    fprintf(fid, '| trim_speed_table | [%s] |\n', sprintf('%.4g ', P.trim_speed_table));
    fprintf(fid, '| trim_elevator_table [rad] | [%s] |\n', sprintf('%.6g ', P.trim_elevator_table));
    fprintf(fid, '| k_gamma_climb / de_climb_lim | %.12g / %.12g |\n', P.k_gamma_climb, P.de_climb_lim);
    fprintf(fid, '| slew_max | 40 deg/s (%.12g rad/s) |\n', P.slew_max_rad_s);

    fprintf(fid, '\n---\n\n## 5. Finite / bounds / slew checks\n\n');
    fprintf(fid, '| Check | Pass |\n|---|---|\n');
    fprintf(fid, '| Inputs finite | %s |\n', tf(C.all_inputs_finite));
    fprintf(fid, '| Outputs finite | %s |\n', tf(C.all_outputs_finite));
    fprintf(fid, '| Debug finite | %s |\n', tf(C.all_debug_finite));
    fprintf(fid, '| |δr| ≤ delta_r_max | %s |\n', tf(C.delta_r_within_mag));
    fprintf(fid, '| |δe| ≤ delta_e_max | %s |\n', tf(C.delta_e_within_mag));
    fprintf(fid, '| thrust in [min,max] | %s |\n', tf(C.thrust_within_bounds));
    fprintf(fid, '| rudder slew ≤ 40°/s·dt | %s (max step %.6g rad vs lim %.6g) |\n', ...
        tf(C.rudder_slew_ok), C.max_abs_dr_step, C.slew_limit_rad);
    fprintf(fid, '| elevator slew ≤ 40°/s·dt | %s (max step %.6g rad vs lim %.6g) |\n', ...
        tf(C.elevator_slew_ok), C.max_abs_de_step, C.slew_limit_rad);

    fprintf(fid, '\n---\n\n## 6. Determinism\n\n');
    fprintf(fid, 'Within one MATLAB process: replay A, `clear controller_law`, replay B on identical `U`.\n\n');
    fprintf(fid, '| Item | `isequaln` |\n|---|---|\n');
    fprintf(fid, '| Outputs `(delta_r,delta_e,thrust)` | %s |\n', tf(D.isequaln_outputs));
    fprintf(fid, '| Debug (all fixed fields) | %s |\n', tf(D.isequaln_debug));
    fprintf(fid, '| Determinism PASS | %s |\n', tf(D.pass));

    fprintf(fid, '\n---\n\n## 7. Artifacts\n\n');
    fprintf(fid, '| Path | Role |\n|---|---|\n');
    fprintf(fid, '| `suite_results/CG2A_CONTROLLER_GOLDEN_V1.mat` | lean versioned corpus (U,Y,Debug,params,det,checks) |\n');
    fprintf(fid, '| `suite_results/CG2A_CONTROLLER_GOLDEN_V1.json` | schema/hashes/determinism metadata |\n');
    fprintf(fid, '| `run_cg2a_controller_golden_parity_capture.m` | SIMULATION_ONLY harness |\n');
    fprintf(fid, '| `controller_law.m` / `init_parameters.m` | **UNTOUCHED** |\n\n');

    fprintf(fid, '**Units/frames:** angles rad; rates rad/s BODY; surge/heave m/s BODY; thrust N; ');
    fprintf(fid, '`theta` sim convention with `theta_phys=-theta`; pitch_ref physical.\n\n');
    fprintf(fid, 'Rejected methods remain closed. No production call-path change. ');
    fprintf(fid, 'This capture is a MATLAB golden twin baseline — **not** C++ parity.\n\n');
    fprintf(fid, '---\n\n*End of CG2A_CONTROLLER_GOLDEN_PARITY_CAPTURE. Verdict: **%s**. Next: `%s`.*\n', ...
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
        % Fallback: ask host sha256sum if Java digest unavailable
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
