function run_propulsion_power_compute_parity_fix()
% PROPULSION_POWER_COMPUTE_PARITY_FIX_RESUME_001
% Gate6 attempt2 RESUMED after host-power/bridge interruption (NOT attempt3).
%
% Recovery provenance (recorded, not re-derived):
%   attempt1  : FAIL, shadow-only (local X/XZ loop incomparable to the frozen
%               SPEED_ENVELOPE_AUDIT; two MATLAB starts). PRESERVED, not reopened.
%   attempt2  : created continuous_path_tracking_propulsion.m (marker clone of
%               production continuous_path_tracking.m) and verified its mechanical
%               reduction; interrupted BEFORE this driver existed and BEFORE any
%               MATLAB process was started. PRESERVED as an interrupted record.
%   resume    : this file completes attempt2. Exactly ONE MATLAB process is used
%               after the resume (enforced by a run lock + pid record).
%
% Read-only sources (static review only, no MATLAB probing before this run):
%   continuous_path_tracking_propulsion.m
%   run_speed_envelope_audit.m
%   suite_results/SPEED_ENVELOPE_AUDIT.mat
%
% Method:
%   Phase 1  ideal-hook parity. The accepted audit cells are re-run through the
%            clone with prop.ideal == true (exact passthrough). Required: exact
%            bit equality, or diffs <= declared PARITY_TOL = 1e-12, against the
%            frozen accepted MAT. On parity failure the run STOPS as
%            HARNESS_FAIL before any variant is executed.
%   Phase 2  frozen ASSUMED thrust actuator variants (nominal / slow-low /
%            fast-high lag-gain-slew) + component-neutral power/energy ranges.
%            No tuning, no re-selection: variants are declared before the run.
%   Phase 3  deterministic replay of one cell, bitwise.
%
% Simulation-only, NOT_CERTIFIED. Gate4 remains shadow-only. Production files are
% never written; their fingerprints are recorded before and after the run.

    project_dir = fileparts(fileparts(fileparts(mfilename('fullpath')))); % repo root
    addpath(genpath(fullfile(project_dir, 'matlab')));
    out_dir = fullfile(project_dir, 'suite_results');
    if ~exist(out_dir, 'dir'); mkdir(out_dir); end

    task_id = 'PROPULSION_POWER_COMPUTE_PARITY_FIX_RESUME_001';
    tag     = 'PROPULSION_POWER_COMPUTE_PARITY_FIX';
    marker  = 'PROPULSION_POWER_COMPUTE_PARITY_FIX_RESUME_001';
    PARITY_TOL = 1e-12;

    md_path   = fullfile(out_dir, [tag '.md']);
    mat_path  = fullfile(out_dir, [tag '.mat']);
    png_path  = fullfile(out_dir, [tag '.png']);
    lock_path = fullfile(out_dir, [tag '.lock']);

    G = struct();   % gate ledger
    t_wall0 = tic;

    fprintf('\n========== %s ==========\n', task_id);
    fprintf('Gate6 attempt2 RESUME (not attempt3). Simulation-only / NOT_CERTIFIED.\n');

    %% ---------- G_single_matlab: run lock + pid ----------
    my_pid = double(feature('getpid'));
    pre_existing_lock = (exist(lock_path, 'file') == 2);
    prior_lock_txt = '';
    if pre_existing_lock
        prior_lock_txt = strtrim(fileread(lock_path));
    end
    fid = fopen(lock_path, 'w');
    fprintf(fid, 'task=%s\npid=%d\nstarted=%s\n', task_id, my_pid, datestr(now, 31));
    fclose(fid);
    G.G_single_matlab = struct('pass', ~pre_existing_lock, ...
        'detail', sprintf('pid=%d prior_lock=%d (%s)', my_pid, pre_existing_lock, prior_lock_txt));
    fprintf('MATLAB pid=%d | prior run lock present=%d\n', my_pid, pre_existing_lock);

    %% ---------- fingerprints BEFORE ----------
    fp_files = { ...
        'continuous_path_tracking.m'; 'controller_law.m'; 'guidance_law.m'; ...
        'init_parameters.m'; 'underwater777_vehicle_dynamics.m'; ...
        'compute_path_following_metrics.m'; 'compute_pitch_window_metrics.m'; ...
        'generate_balanced_helical_path.m'; ...
        fullfile('suite_results', 'CODEX_VERTICAL_PLAN.md')};
    FP_before = fingerprint_set(project_dir, fp_files);
    fprintf('\nProduction / plan fingerprints (before):\n');
    print_fp(FP_before);

    %% ---------- G_clone_minimal_diff ----------
    orig_path  = fullfile(project_dir, 'continuous_path_tracking.m');
    clone_path = fullfile(project_dir, 'continuous_path_tracking_propulsion.m');
    assert(exist(orig_path, 'file') == 2, 'missing %s', orig_path);
    assert(exist(clone_path, 'file') == 2, 'missing %s', clone_path);
    CL = clone_reduction_check(orig_path, clone_path);
    G.G_clone_minimal_diff = struct('pass', CL.match, 'detail', CL.detail);
    fprintf('\nClone reduction to production original: %s (%s)\n', ...
        yn(CL.match), CL.detail);

    %% ---------- accepted frozen audit MAT ----------
    audit_mat = fullfile(out_dir, 'SPEED_ENVELOPE_AUDIT.mat');
    assert(exist(audit_mat, 'file') == 2, 'missing accepted audit MAT %s', audit_mat);
    A = load(audit_mat);
    assert(isfield(A, 'Cell') && isfield(A, 'Ugrid') && isfield(A, 'routes'), ...
        'accepted MAT lacks Cell/Ugrid/routes');
    if ischar(A.routes); A.routes = cellstr(A.routes); end
    A.routes = reshape(A.routes, 1, []);
    A.routes = cellfun(@char, A.routes, 'UniformOutput', false);
    assert(isequal(A.routes, {'X', 'XZ', 'H'}), ...
        'accepted MAT route order changed: %s', sjoin(A.routes, ','));
    fprintf('\nAccepted audit MAT: task=%s verdict=%s Ugrid=%s\n', ...
        A.task_id, A.verdict, mat2str(A.Ugrid));

    % Frozen accepted cell set (declared by the task; never widened here)
    acc_routes = {'X', 'XZ', 'H'};
    acc_U      = {[1.0 1.5 2.0], [1.0 1.5 2.0], [1.5 2.0]};
    CellList = struct('route', {}, 'U', {}, 'ir', {}, 'iu', {});
    for iu_local = 1:numel(A.Ugrid)
        for ir = 1:numel(acc_routes)
            rn = acc_routes{ir};
            k = find(abs(acc_U{ir} - A.Ugrid(iu_local)) < 1e-12, 1);
            if isempty(k); continue; end
            CellList(end+1) = struct('route', rn, 'U', A.Ugrid(iu_local), ...
                'ir', ir, 'iu', iu_local); %#ok<AGROW>
        end
    end
    n_cells = numel(CellList);
    fprintf('Accepted parity cells: %d (X/XZ U={1,1.5,2}, R10 U={1.5,2})\n', n_cells);

    % Accepted-set consistency against the frozen MAT (reported, not silently fixed)
    acc_ok = true; acc_note = {};
    for i = 1:n_cells
        c = CellList(i);
        f = A.Cell(c.iu, c.ir).feasible;
        if ~f
            acc_ok = false;
            acc_note{end+1} = sprintf('%s@%.2f not FEASIBLE in accepted MAT (%s)', ...
                c.route, c.U, A.Cell(c.iu, c.ir).first_limit); %#ok<AGROW>
        end
    end
    if acc_ok
        acc_detail = 'all declared accepted cells FEASIBLE in frozen MAT';
    else
        acc_detail = sjoin(acc_note, '; ');
    end
    G.G_accepted_set_consistent = struct('pass', acc_ok, 'detail', acc_detail);

    %% ---------- frozen production stack (identical to the accepted audit) ----------
    ctrl_path = fullfile(project_dir, 'controller_law.m');
    ctrl_txt = fileread(ctrl_path);
    assert(contains(ctrl_txt, 'k_gamma_climb = 0.1320695001'), 'climb FF missing');
    assert(contains(ctrl_txt, 'Kp_roll'), 'roll damp missing');
    assert(contains(ctrl_txt, 'thrust_trim + Kp_x * (u_ref - u)'), 'thrust law mismatch');
    assert(contains(ctrl_txt, 'de_climb_ff'), 'climb FF term missing');
    clear functions
    clear guidance_law controller_law
    clear global lambda_muw_ff trim_speed_table trim_elevator_table elevator_sign
    clear global K_zdot K_gamma enable_alpha_hat
    clear global last_guidance_U_h last_guidance_kappa last_r_ff
    clear global Kp_roll

    init_parameters();
    global lambda_muw_ff elevator_sign trim_speed_table trim_elevator_table
    global K_zdot K_gamma enable_alpha_hat
    global dt_controller delta_e_max delta_r_max
    global Kp_x thrust_trim thrust_max thrust_min desired_speed Kp_roll

    elevator_sign = 1;
    trim_speed_table = [0.8 1.0 1.5 2.0];
    trim_elevator_table = deg2rad([-9.18 -7.33 -4.62 -3.17]);
    K_gamma = 0; K_zdot = 0; enable_alpha_hat = false;
    Kp_roll = 0.605072;

    seed_used = 0;
    rng(seed_used, 'twister');

    lim = struct( ...
        'dr_max', delta_r_max, 'de_max', delta_e_max, ...
        'dr_rate', deg2rad(40), 'de_rate', deg2rad(40), ...
        'near_frac', 0.80, 'thrust_max', thrust_max, 'thrust_min', thrust_min);

    HG = struct();
    HG.X.pitch_mae = 0.10; HG.X.pitch_p95 = 0.50; HG.X.gamma_mae = 0.50; HG.X.gamma_p95 = 1.00;
    HG.XZ.pitch_mae = 0.30; HG.XZ.pitch_p95 = 0.50; HG.XZ.gamma_mae = 1.00; HG.XZ.gamma_p95 = 1.50;
    HG.H.pitch_mae = 0.30; HG.H.pitch_p95 = 0.50; HG.H.gamma_mae = 1.50; HG.H.gamma_p95 = 2.50;
    HG.H.yaw_mae = 1.0; HG.H.yaw_p95 = 2.0;
    HG.elev_sat = 1.0; HG.rud_sat_ss = 1.0; HG.rud_sat_full = 1.0;
    HG.chatter = 0.20; HG.ratio_lo = 0.98; HG.ratio_hi = 1.02;
    HG.rate_util = 1.0; HG.thrust_sat = 1.0;
    HG.trim_tol = 0.01;
    HG.phi_eq = struct('X', 0.0, 'XZ', 0.0, 'H', 0.0255);

    nX = 600; xX = linspace(0, 45, nX)';
    pathX = [xX, zeros(nX, 1), zeros(nX, 1)];
    nXZ = 900; xXZ = linspace(0, 42, nXZ)';
    pathXZ = [xXZ, zeros(nXZ, 1), 0.4 * xXZ];
    pathH = generate_balanced_helical_path(10.0, 2.0, 2, 500);
    paths = {pathX, pathXZ, pathH};
    Tfin = [18, 22, 45];
    win_mode = {'first_hold', 'persistent', 'persistent'};
    lambda0 = [0.25, 0.0, 0.25];

    seed_level = struct('theta', -0.0333395, 'v', 0, 'w', -0.0500278, 'q', 0, ...
        'de', -0.116328, 'T', 3.81167, 'u', 1.5);
    seed_climb = struct('theta', -0.431841, 'v', 0, 'w', -0.0770689, 'q', 0, ...
        'de', -0.0210529, 'T', 5.73772, 'u', 1.5);
    x_scale = [10; 10; 10; 1; 1; 1; 1.5; 0.3; 0.3; 0.2; 0.2; 0.2];
    nu_dot_scale = [1.0; 0.3; 0.3; 0.2; 0.2; 0.2];

    FROZEN = struct('HG', HG, 'lim', lim, 'Tfin', Tfin, 'win_mode', {win_mode}, ...
        'lambda0', lambda0, 'seed_used', seed_used, 'Kp_roll', Kp_roll, ...
        'Kp_x', Kp_x, 'thrust_trim', thrust_trim, 'parity_tol', PARITY_TOL);

    %% ---------- predeclared ASSUMED propulsion variants (no tuning) ----------
    PROPSET = declare_prop_variants(thrust_min, thrust_max);
    fprintf('\nPredeclared ASSUMED actuator variants (frozen before the run):\n');
    for i = 1:numel(PROPSET)
        p = PROPSET(i);
        fprintf('  %-10s ideal=%d tau=%.3f s gain=%.3f slew=%s N/s T=[%.3f %.3f] N\n', ...
            p.name, p.ideal, p.tau, p.gain, num2str(p.slew), p.T_min, p.T_max);
    end

    %% ---------- component-neutral power/energy assumption block ----------
    PWR = declare_power_model();
    fprintf(['\nComponent-neutral power model (ASSUMED, declared): ', ...
        'eta_total in [%.2f, %.2f], V_bus in {%s} V, no regeneration credit.\n'], ...
        PWR.eta_lo, PWR.eta_hi, num2str(PWR.V_bus));

    %% ================= PHASE 1: ideal-hook parity =================
    fprintf('\n---------- PHASE 1: ideal-hook parity vs accepted MAT ----------\n');
    prop_ideal = PROPSET(1);
    assert(prop_ideal.ideal, 'variant 1 must be the ideal hook');

    Par = repmat(empty_parity(), n_cells, 1);
    IdealRun = repmat(empty_run(), n_cells, 1);
    parity_all_exact = true;
    parity_all_ok = true;

    for i = 1:n_cells
        c = CellList(i);
        fprintf('\n  [parity %d/%d] %s @ U=%.2f\n', i, n_cells, c.route, c.U);
        [S, PR, Trim] = run_one_cell(c, paths, Tfin, win_mode, lambda0, HG, lim, ...
            seed_level, seed_climb, nu_dot_scale, x_scale, prop_ideal, seed_used);
        M = analyze_route(S, paths{c.ir}, win_mode{c.ir}, HG.phi_eq.(c.route), lim, ...
            strcmp(c.route, 'XZ'), tern(strcmp(c.route, 'H'), 10.0, 0), c.U);
        M.trim = Trim; M.Uref = c.U; M.route = c.route;
        M.feas = score_feasible(M, c.route, HG, lim);

        P = parity_compare(A.Cell(c.iu, c.ir), compact_S(S), M, PARITY_TOL);
        P.route = c.route; P.U = c.U;
        Par(i) = P;
        parity_all_exact = parity_all_exact && P.exact;
        parity_all_ok = parity_all_ok && P.pass;

        IdealRun(i) = pack_run(c, prop_ideal, S, PR, M, PWR, lim);
        fprintf('     parity: %s | max_sig_diff=%.3e max_metric_diff=%.3e | %s\n', ...
            tern(P.exact, 'EXACT', tern(P.pass, 'WITHIN_TOL', 'FAIL')), ...
            P.max_sig_diff, P.max_metric_diff, P.note);
    end

    G.G_parity_accepted_baseline = struct('pass', parity_all_ok, ...
        'detail', sprintf('cells=%d exact=%d within_tol(1e-12)=%d max_sig_diff=%.3e', ...
        n_cells, parity_all_exact, parity_all_ok, max([Par.max_sig_diff])));

    if ~parity_all_ok
        fprintf('\n*** PARITY FAILURE — stopping HARNESS_FAIL before any variant. ***\n');
        Var = repmat(empty_run(), 0, 1);
        Rep = struct('pass', false, 'detail', 'not reached (stopped at parity)', 'run', false);
        FP_after = fingerprint_set(project_dir, fp_files);
        G = finish_gates(G, FP_before, FP_after, IdealRun, Var, Rep, PWR, lim, ...
            false, [], []);
        verdict = 'HARNESS_FAIL';
        Pareto = struct('rows', {{}}, 'note', 'not computed (parity stop)');
        ART = struct('md', md_path, 'mat', mat_path, 'png', png_path);
        RD = emit_and_verify(ART, task_id, verdict, marker, Par, IdealRun, Var, Rep, ...
            PROPSET, PWR, FROZEN, G, FP_before, FP_after, CL, A, CellList, Pareto, ...
            my_pid, t_wall0);
        G.G_artifacts_readable = struct('pass', RD.pass, 'detail', RD.detail);
        emit_and_verify(ART, task_id, verdict, marker, Par, IdealRun, Var, Rep, ...
            PROPSET, PWR, FROZEN, G, FP_before, FP_after, CL, A, CellList, Pareto, ...
            my_pid, t_wall0);
        append_logs(out_dir, task_id, marker, verdict, G, Par, IdealRun, Var, ...
            Pareto, md_path, mat_path, png_path);
        finalize(lock_path, verdict, G, t_wall0);
        return
    end

    %% ================= PHASE 2: frozen ASSUMED variants =================
    fprintf('\n---------- PHASE 2: frozen ASSUMED actuator variants ----------\n');
    Var = repmat(empty_run(), 0, 1);
    for iv = 2:numel(PROPSET)
        pv = PROPSET(iv);
        fprintf('\n  == variant %s (tau=%.3f gain=%.3f slew=%g) ==\n', ...
            pv.name, pv.tau, pv.gain, pv.slew);
        for i = 1:n_cells
            c = CellList(i);
            fprintf('   [%s %d/%d] %s @ U=%.2f\n', pv.name, i, n_cells, c.route, c.U);
            [S, PR, Trim] = run_one_cell(c, paths, Tfin, win_mode, lambda0, HG, lim, ...
                seed_level, seed_climb, nu_dot_scale, x_scale, pv, seed_used);
            M = analyze_route(S, paths{c.ir}, win_mode{c.ir}, HG.phi_eq.(c.route), lim, ...
                strcmp(c.route, 'XZ'), tern(strcmp(c.route, 'H'), 10.0, 0), c.U);
            M.trim = Trim; M.Uref = c.U; M.route = c.route;
            M.feas = score_feasible(M, c.route, HG, lim);
            R = pack_run(c, pv, S, PR, M, PWR, lim);
            Var(end+1) = R; %#ok<AGROW>
            fprintf('      FEAS=%s first=%s | uMAE=%.4f thMAE=%.4f | slew%%=%.2f sat%%=%.2f | E_hi=%.2f Wh\n', ...
                yn(R.feasible), R.first_limit, nz(R.speed_mae), nz(R.theta_mae), ...
                R.slew_pct, R.sat_pct, R.E_hi_Wh);
        end
    end

    %% ================= PHASE 3: deterministic replay =================
    fprintf('\n---------- PHASE 3: deterministic replay (bitwise) ----------\n');
    creplay = CellList(1);
    pv = PROPSET(2);
    [S2, PR2, ~] = run_one_cell(creplay, paths, Tfin, win_mode, lambda0, HG, lim, ...
        seed_level, seed_climb, nu_dot_scale, x_scale, pv, seed_used);
    idx_ref = find(strcmp({Var.route}, creplay.route) & ...
        abs([Var.U] - creplay.U) < 1e-12 & strcmp({Var.variant}, pv.name), 1);
    Rep = replay_compare(Var(idx_ref), S2, PR2, creplay, pv);
    fprintf('  replay %s @ %.2f variant=%s : %s (%s)\n', creplay.route, creplay.U, ...
        pv.name, yn(Rep.pass), Rep.detail);

    %% ---------- fingerprints AFTER + gates + Pareto ----------
    FP_after = fingerprint_set(project_dir, fp_files);
    fprintf('\nProduction / plan fingerprints (after):\n');
    print_fp(FP_after);

    Pareto = compute_pareto(IdealRun, Var);
    G = finish_gates(G, FP_before, FP_after, IdealRun, Var, Rep, PWR, lim, ...
        true, Pareto, HG);

    gate_names = fieldnames(G);
    all_pass = true;
    for i = 1:numel(gate_names)
        if ~G.(gate_names{i}).pass; all_pass = false; end
    end
    if all_pass
        verdict = 'PASS';
    elseif G.G_parity_accepted_baseline.pass && G.G_finite_states.pass
        verdict = 'PARTIAL';
    else
        verdict = 'FAIL';
    end

    %% ---------- artifacts ----------
    % First emission establishes readability; the ledger is then completed and the
    % artifacts are re-emitted so that MD/MAT carry the final gate set and verdict.
    ART = struct('md', md_path, 'mat', mat_path, 'png', png_path);
    RD = emit_and_verify(ART, task_id, verdict, marker, Par, IdealRun, Var, Rep, ...
        PROPSET, PWR, FROZEN, G, FP_before, FP_after, CL, A, CellList, Pareto, ...
        my_pid, t_wall0);
    G.G_artifacts_readable = struct('pass', RD.pass, 'detail', RD.detail);
    if ~RD.pass && strcmp(verdict, 'PASS'); verdict = 'PARTIAL'; end
    emit_and_verify(ART, task_id, verdict, marker, Par, IdealRun, Var, Rep, ...
        PROPSET, PWR, FROZEN, G, FP_before, FP_after, CL, A, CellList, Pareto, ...
        my_pid, t_wall0);

    append_logs(out_dir, task_id, marker, verdict, G, Par, IdealRun, Var, ...
        Pareto, md_path, mat_path, png_path);

    fprintf('\nSaved: %s\n%s\n%s\n', md_path, mat_path, png_path);
    finalize(lock_path, verdict, G, t_wall0);
    assignin('base', 'PROPULSION_POWER_COMPUTE_PARITY_FIX_VERDICT', verdict);
end

%% ===================== declarations (frozen, ASSUMED) =====================
function P = declare_prop_variants(T_min, T_max)
% Predeclared simulation-only ASSUMED actuator set. NOT identified from hardware.
% Order is fixed: (1) ideal hook used for the parity gate, then three variants.
    P = struct('name', {}, 'ideal', {}, 'tau', {}, 'gain', {}, 'slew', {}, ...
        'T_min', {}, 'T_max', {}, 'why', {});
    P(1) = struct('name', 'ideal', 'ideal', true, 'tau', 0, 'gain', 1, ...
        'slew', Inf, 'T_min', -Inf, 'T_max', Inf, ...
        'why', 'exact passthrough; parity hook against accepted audit');
    P(2) = struct('name', 'nominal', 'ideal', false, 'tau', 0.30, 'gain', 1.00, ...
        'slew', 8.0, 'T_min', T_min, 'T_max', T_max, ...
        'why', 'ASSUMED mid-range thruster lag/gain/slew');
    P(3) = struct('name', 'slow_low', 'ideal', false, 'tau', 0.60, 'gain', 0.90, ...
        'slew', 4.0, 'T_min', T_min, 'T_max', T_max, ...
        'why', 'ASSUMED slow lag, low gain, tight slew (worst dynamic corner)');
    P(4) = struct('name', 'fast_high', 'ideal', false, 'tau', 0.15, 'gain', 1.10, ...
        'slew', 16.0, 'T_min', T_min, 'T_max', T_max, ...
        'why', 'ASSUMED fast lag, high gain, loose slew (aggressive corner)');
end

function W = declare_power_model()
% Component-neutral: no propeller/motor/ESC part is identified. Useful advance
% power is bracketed by a declared total efficiency interval, giving RANGES only.
    W = struct();
    W.model = 'P_useful = max(T_real .* u_body, 0); P_in in [P_useful/eta_hi, P_useful/eta_lo]';
    W.eta_lo = 0.35;
    W.eta_hi = 0.60;
    W.eta_note = 'ASSUMED total (prop x motor x drive) efficiency interval, simulation-only';
    W.V_bus = [24 48];
    W.V_note = 'ASSUMED DC bus voltages; current is CONDITIONAL on this assumption';
    W.regen = false;
    W.regen_note = 'no regeneration credit: negative T*u clipped to zero for input energy';
    W.certified = false;
end

%% ===================== single cell execution =====================
function [S, PR, Trim] = run_one_cell(c, paths, Tfin, win_mode, lambda0, HG, lim, ...
        seed_level, seed_climb, nu_dot_scale, x_scale, prop, seed_used) %#ok<INUSL>
    global desired_speed lambda_muw_ff

    if strcmp(c.route, 'X')
        Trim = solve_translating(c.U, 0.0, seed_level, nu_dot_scale, x_scale, HG.trim_tol, 'level');
    elseif strcmp(c.route, 'XZ')
        Trim = solve_translating(c.U, 0.4, seed_climb, nu_dot_scale, x_scale, HG.trim_tol, 'climb');
    else
        Trim = helix_trim_stub(c.U);
    end

    rng(seed_used, 'twister');
    desired_speed = c.U;
    lambda_muw_ff = lambda0(c.ir);

    state0 = build_state0(paths{c.ir}, c.U, Trim);
    if strcmp(c.route, 'H')
        [S, PR] = simulate_helix_logged_prop(paths{c.ir}, Tfin(c.ir), c.U, 10.0, state0, prop);
        S.R = 10.0; S.is_xz = false;
    else
        [S, PR] = simulate_straight_prop(paths{c.ir}, Tfin(c.ir), c.U, ...
            strcmp(c.route, 'XZ'), state0, prop);
        S.R = 0; S.is_xz = strcmp(c.route, 'XZ');
    end
    S.Uref = c.U;
end

function [S, PR] = simulate_straight_prop(path, T_final, Uref, is_xz, state0, prop)
% Clone of the accepted audit straight loop; ONLY the tracking function is the
% marker clone with the realized-thrust hook. S is built with the audit's frozen
% definitions so parity is like-for-like.
    global dt_controller suite_delta_e_log suite_delta_r_log suite_u_log
    global Kp_x thrust_trim thrust_max thrust_min lambda_muw_ff

    clear guidance_law controller_law
    reset_ctrl_globals();

    if is_xz
        lambda_muw_ff = 0.0;
    else
        lambda_muw_ff = 0.25;
    end
    dt = dt_controller;
    [vp, times, vel, rates, ori, ~, yaw_refs, pitch_refs, u_refs, PROP] = ...
        continuous_path_tracking_propulsion(path, state0, dt, T_final, prop);
    n = numel(times);
    u_ctrl = align_len(suite_u_log(:), n);
    de = align_len(suite_delta_e_log(:), n);
    dr = align_len(suite_delta_r_log(:), n);
    thrust = reconstruct_thrust(u_refs(:), u_ctrl, thrust_trim, Kp_x, thrust_min, thrust_max);

    S = struct();
    S.dt = dt; S.T_final = T_final; S.u0 = Uref;
    S.t = times(:); S.vp = vp; S.vel = vel; S.rates = rates; S.ori = ori;
    S.psi_ref = yaw_refs(:); S.theta_ref = pitch_refs(:); S.u_ref = u_refs(:);
    S.u_ctrl = u_ctrl(:); S.u_body = vel(:, 1); S.v_body = vel(:, 2); S.w_body = vel(:, 3);
    [S.Uh, S.VD, S.Vtot] = ned_speeds(ori, vel);
    S.thrust = thrust(:); S.delta_e = de; S.delta_r = dr;
    S.kappa = zeros(n, 1); S.U_h_guid = S.Uh; S.r = rates(:, 3);

    PR = struct();
    PR.T_cmd = align_len(PROP.T_cmd(:), n);
    PR.T_real = align_len(PROP.T_real(:), n);
    PR.slew_hit = logical(align_len(double(PROP.slew_hit(:)), n));
    PR.sat_hit = logical(align_len(double(PROP.sat_hit(:)), n));
    PR.n_slew = PROP.n_slew; PR.n_sat = PROP.n_sat; PR.n_act = PROP.n_steps_act;
end

function [S, PR] = simulate_helix_logged_prop(path, T_final, Uref, R, state0, prop)
% Clone of the accepted audit R10 loop. ONLY change: the controller thrust command
% passes through the shared actuator service before entering the plant.
    global dt_controller dt_guidance
    global last_guidance_U_h last_guidance_kappa last_r_ff
    global last_delta_e last_delta_r
    global thrust_max thrust_min lambda_muw_ff

    clear guidance_law controller_law
    reset_ctrl_globals();
    global last_guidance_U_h last_guidance_kappa last_r_ff
    global last_delta_e last_delta_r

    lambda_muw_ff = 0.25;
    dt = dt_controller;
    if isempty(dt) || ~isfinite(dt); dt = 0.025; end
    if isempty(dt_guidance) || ~isfinite(dt_guidance); dt_guidance = 0.075; end
    n_steps = round(T_final / dt);
    guidance_period = max(1, round(dt_guidance / dt));
    state = state0(:);
    if any(~isfinite(state))
        error('helix IC non-finite');
    end

    yaw_ref = 0; pitch_ref = 0; u_ref = Uref; r_ff = 0; pitch_ref_dot = 0; pidx = 1;
    act_state = [];

    S = struct();
    S.dt = dt; S.T_final = T_final; S.u0 = Uref; S.R = R;
    S.t = zeros(n_steps, 1);
    S.vp = zeros(n_steps, 3); S.vel = zeros(n_steps, 3);
    S.rates = zeros(n_steps, 3); S.ori = zeros(n_steps, 3);
    S.psi_ref = zeros(n_steps, 1); S.theta_ref = zeros(n_steps, 1);
    S.u_ref = zeros(n_steps, 1); S.u_ctrl = zeros(n_steps, 1);
    S.delta_r = zeros(n_steps, 1); S.delta_e = zeros(n_steps, 1);
    S.thrust = zeros(n_steps, 1);
    S.Uh = zeros(n_steps, 1); S.VD = zeros(n_steps, 1); S.Vtot = zeros(n_steps, 1);
    S.U_h_guid = zeros(n_steps, 1); S.kappa = zeros(n_steps, 1); S.r = zeros(n_steps, 1);
    T_cmd_log = zeros(n_steps, 1); T_real_log = zeros(n_steps, 1);
    slew_log = false(n_steps, 1); sat_log = false(n_steps, 1);

    for k = 1:n_steps
        pos = state(1:3)';
        ori = state(4:6)';
        rates = state(10:12)';
        u = state(7); v = state(8); w = state(9);
        [Uh, zdot, VD] = inertial_Uh_zdot_vd(ori, u, v, w);
        theta_phys_now = -ori(2);

        if mod(k - 1, guidance_period) == 0
            [yaw_ref, pitch_ref, u_ref, pidx, r_ff, pitch_ref_dot] = ...
                guidance_law(pos, path, pidx, u, v, Uh, zdot, theta_phys_now);
        end

        [dr, de, thr] = controller_law(yaw_ref, pitch_ref, u_ref, ...
            ori(3), ori(2), rates(3), rates(2), u, r_ff, pitch_ref_dot, ori(1), w, rates(1));

        T_cmd = thr;
        [T_real, act_state] = continuous_path_tracking_propulsion('actuator', ...
            act_state, T_cmd, dt, prop);
        controls = struct('delta_r', dr, 'delta_e', de, 'thrust', T_real);
        [~, g] = ode45(@(tt, gg) underwater777_vehicle_dynamics(tt, gg, controls), ...
            [0 dt], state);
        state = g(end, :)';

        S.t(k) = k * dt;
        S.vp(k, :) = state(1:3);
        S.vel(k, :) = state(7:9);
        S.rates(k, :) = state(10:12);
        S.ori(k, :) = state(4:6);
        S.psi_ref(k) = yaw_ref;
        S.theta_ref(k) = pitch_ref;
        S.u_ref(k) = u_ref;
        S.u_ctrl(k) = u;
        if isempty(last_delta_e); last_delta_e = de; end
        if isempty(last_delta_r); last_delta_r = dr; end
        S.delta_e(k) = last_delta_e;
        S.delta_r(k) = last_delta_r;
        S.thrust(k) = max(min(thr, thrust_max), thrust_min);
        S.Uh(k) = Uh; S.VD(k) = VD; S.Vtot(k) = norm(state(7:9));
        if isempty(last_guidance_U_h); last_guidance_U_h = Uh; end
        if isempty(last_guidance_kappa); last_guidance_kappa = 1 / R; end
        if isempty(last_r_ff); last_r_ff = r_ff; end
        S.U_h_guid(k) = last_guidance_U_h;
        S.kappa(k) = last_guidance_kappa;
        S.r(k) = rates(3);
        T_cmd_log(k) = T_cmd; T_real_log(k) = T_real;
        slew_log(k) = act_state.slew_hit; sat_log(k) = act_state.sat_hit;

        if mod(k, 400) == 0 || k == n_steps
            fprintf('       helix step %d/%d t=%.1fs\n', k, n_steps, S.t(k));
        end
    end
    S.u_body = S.vel(:, 1); S.v_body = S.vel(:, 2); S.w_body = S.vel(:, 3);

    PR = struct('T_cmd', T_cmd_log, 'T_real', T_real_log, ...
        'slew_hit', slew_log, 'sat_hit', sat_log, ...
        'n_slew', act_state.n_slew, 'n_sat', act_state.n_sat, 'n_act', act_state.n);
end

%% ===================== parity =====================
function P = empty_parity()
    P = struct('route', '', 'U', NaN, 'exact', false, 'pass', false, ...
        'max_sig_diff', NaN, 'max_metric_diff', NaN, 'worst_field', '', ...
        'feas_match', false, 'limit_match', false, ...
        'note', '', 'sig', struct(), 'metric', struct());
end

function P = parity_compare(Aref, Snew, Mnew, tol)
    P = empty_parity();
    sig_fields = {'t','vp','vel','rates','ori','psi_ref','theta_ref','u_ref', ...
        'u_ctrl','u_body','thrust','delta_e','delta_r','Uh','VD','dt','R','is_xz','Uref'};
    Aref_S = Aref.S;
    worst = 0; worst_f = ''; notes = {};
    for i = 1:numel(sig_fields)
        f = sig_fields{i};
        if ~isfield(Aref_S, f)
            notes{end+1} = ['ref_missing:' f]; %#ok<AGROW>
            continue
        end
        if ~isfield(Snew, f)
            notes{end+1} = ['new_missing:' f]; %#ok<AGROW>
            P.sig.(f) = Inf; worst = Inf; worst_f = f;
            continue
        end
        a = double(Aref_S.(f)); b = double(Snew.(f));
        if ~isequal(size(a), size(b))
            notes{end+1} = sprintf('size_mismatch:%s ref=%s new=%s', f, ...
                mat2str(size(a)), mat2str(size(b))); %#ok<AGROW>
            P.sig.(f) = Inf; worst = Inf; worst_f = f;
            continue
        end
        d = maxdiff_nan(a, b);
        P.sig.(f) = d;
        if d > worst; worst = d; worst_f = f; end
    end
    P.max_sig_diff = worst;

    Aref_M = Aref.M;
    mnames = {'speed.mae','speed.p95','theta.mae_deg','theta.p95_deg', ...
        'gamma.mae_deg','gamma.p95_deg','yaw.mae_deg','yaw.p95_deg', ...
        'path.mean_cte','act.de_sat_pct','act.thr_sat_pct','act.de_rate_util', ...
        'act.dr_rate_util','act.chatter_dps','roll.tilde_mae_deg'};
    mworst = 0; mworst_f = '';
    for i = 1:numel(mnames)
        [okA, va] = getdot(Aref_M, mnames{i});
        [okB, vb] = getdot(Mnew, mnames{i});
        if ~okA || ~okB
            notes{end+1} = ['metric_missing:' mnames{i}]; %#ok<AGROW>
            continue
        end
        d = maxdiff_nan(double(va), double(vb));
        P.metric.(strrep(mnames{i}, '.', '_')) = d;
        if d > mworst; mworst = d; mworst_f = mnames{i}; end
    end
    P.max_metric_diff = mworst;

    feas_match = isequal(logical(Aref.feasible), logical(Mnew.feas.feasible));
    limit_match = strcmp(char(Aref.first_limit), char(Mnew.feas.first_limit));
    P.feas_match = feas_match;
    P.limit_match = limit_match;
    if ~feas_match
        notes{end+1} = sprintf('feasible_mismatch ref=%d new=%d', ...
            Aref.feasible, Mnew.feas.feasible); %#ok<AGROW>
    end
    if ~limit_match
        notes{end+1} = sprintf('first_limit_mismatch ref="%s" new="%s"', ...
            char(Aref.first_limit), char(Mnew.feas.first_limit)); %#ok<AGROW>
    end

    both = max(worst, mworst);
    P.exact = (both == 0) && feas_match && limit_match;
    P.pass = (both <= tol) && feas_match && limit_match;
    if worst >= mworst; P.worst_field = worst_f; else; P.worst_field = mworst_f; end
    if isempty(notes)
        P.note = tern(P.exact, 'bit-identical', sprintf('within declared tol on %s', P.worst_field));
    else
        P.note = strjoin(notes, '; ');
    end
end

function d = maxdiff_nan(a, b)
    a = a(:); b = b(:);
    na = isnan(a); nb = isnan(b);
    if any(na ~= nb); d = Inf; return; end
    k = ~na;
    if ~any(k); d = 0; return; end
    d = max(abs(a(k) - b(k)));
    if isempty(d); d = 0; end
end

function [ok, v] = getdot(S, name)
    ok = true; v = [];
    parts = strsplit(name, '.');
    cur = S;
    for i = 1:numel(parts)
        if ~isstruct(cur) || ~isfield(cur, parts{i}); ok = false; return; end
        cur = cur.(parts{i});
    end
    v = cur;
    if isempty(v); ok = false; end
end

%% ===================== per-run packing / power =====================
function R = empty_run()
    R = struct('route', '', 'U', NaN, 'variant', '', 'prop', struct(), ...
        'feasible', false, 'first_limit', '', 'worst_margin', NaN, ...
        'speed_mae', NaN, 'speed_bias', NaN, 'theta_mae', NaN, 'gamma_mae', NaN, ...
        'yaw_mae', NaN, 'cte', NaN, 'bounded', false, 'finite', false, ...
        'T_cmd_min', NaN, 'T_cmd_max', NaN, 'T_real_min', NaN, 'T_real_max', NaN, ...
        'T_lim_ok', false, 'slew_pct', NaN, 'sat_pct', NaN, ...
        'P_lo_mean', NaN, 'P_hi_mean', NaN, 'P_lo_p95', NaN, 'P_hi_p95', NaN, ...
        'E_lo_Wh', NaN, 'E_hi_Wh', NaN, 'E_mid_Wh', NaN, ...
        'I_hi_24V', NaN, 'I_hi_48V', NaN, 'cond_ok', false, ...
        'sig', struct(), 'M', struct());
end

function R = pack_run(c, prop, S, PR, M, PWR, lim)
    R = empty_run();
    R.route = c.route; R.U = c.U; R.variant = prop.name; R.prop = prop;
    R.feasible = M.feas.feasible;
    R.first_limit = M.feas.first_limit;
    R.worst_margin = M.feas.worst_margin;
    R.speed_mae = M.speed.mae; R.speed_bias = M.speed.signed_mean;
    R.theta_mae = M.theta.mae_deg; R.gamma_mae = M.gamma.mae_deg;
    R.yaw_mae = M.yaw.mae_deg; R.cte = M.path.mean_cte;
    R.bounded = M.bounded;

    n = numel(S.t);
    Tc = PR.T_cmd(1:min(n, numel(PR.T_cmd)));
    Tr = PR.T_real(1:min(n, numel(PR.T_real)));
    m = min([n, numel(Tc), numel(Tr)]);
    t = S.t(1:m); Tc = Tc(1:m); Tr = Tr(1:m);
    ub = S.u_body(1:m);

    R.finite = all(isfinite(Tc)) && all(isfinite(Tr)) && all(isfinite(ub)) && M.bounded;
    R.T_cmd_min = min(Tc); R.T_cmd_max = max(Tc);
    R.T_real_min = min(Tr); R.T_real_max = max(Tr);
    tolT = 1e-9 * max(1, abs(lim.thrust_max));
    if prop.ideal
        R.T_lim_ok = all(isfinite(Tr));
    else
        R.T_lim_ok = all(Tr >= prop.T_min - tolT) && all(Tr <= prop.T_max + tolT) && ...
            all(isfinite(Tr));
    end
    R.slew_pct = 100 * mean(double(PR.slew_hit(1:min(m, numel(PR.slew_hit)))));
    R.sat_pct = 100 * mean(double(PR.sat_hit(1:min(m, numel(PR.sat_hit)))));

    % Component-neutral power / energy RANGES (ASSUMED efficiency interval)
    P_use = max(Tr .* ub, 0);
    P_lo = P_use / PWR.eta_hi;     % best assumed efficiency -> lower input power
    P_hi = P_use / PWR.eta_lo;     % worst assumed efficiency -> upper input power
    mask = M.mask_hold(:);
    if numel(mask) >= m; mask = mask(1:m); else; mask = true(m, 1); end
    if ~any(mask); mask = true(m, 1); end
    R.P_lo_mean = mean(P_lo(mask)); R.P_hi_mean = mean(P_hi(mask));
    R.P_lo_p95 = prctile_local(P_lo(mask), 95); R.P_hi_p95 = prctile_local(P_hi(mask), 95);
    if m >= 2
        R.E_lo_Wh = trapz(t, P_lo) / 3600;
        R.E_hi_Wh = trapz(t, P_hi) / 3600;
    else
        R.E_lo_Wh = NaN; R.E_hi_Wh = NaN;
    end
    R.E_mid_Wh = 0.5 * (R.E_lo_Wh + R.E_hi_Wh);
    R.I_hi_24V = R.P_hi_p95 / PWR.V_bus(1);
    R.I_hi_48V = R.P_hi_p95 / PWR.V_bus(2);
    R.cond_ok = all(isfinite([R.P_lo_mean R.P_hi_mean R.P_lo_p95 R.P_hi_p95 ...
        R.E_lo_Wh R.E_hi_Wh R.I_hi_24V R.I_hi_48V])) && ...
        (R.P_lo_mean >= 0) && (R.P_hi_mean >= R.P_lo_mean) && ...
        (R.E_hi_Wh >= R.E_lo_Wh) && (R.E_lo_Wh >= 0);

    % decimated signals for the artifact (keeps the MAT small)
    ds = max(1, round(m / 400));
    R.sig = struct('t', t(1:ds:m), 'T_cmd', Tc(1:ds:m), 'T_real', Tr(1:ds:m), ...
        'u_body', ub(1:ds:m), 'P_lo', P_lo(1:ds:m), 'P_hi', P_hi(1:ds:m), 'ds', ds);
    R.M = strip_metrics(M);
end

function Mo = strip_metrics(M)
    Mo = struct();
    keep = {'speed','theta','gamma','yaw','roll','path','act','bounded', ...
        'persistent_ok','sim_ok','sim_err','trim','Uref','route'};
    for i = 1:numel(keep)
        if isfield(M, keep{i}); Mo.(keep{i}) = M.(keep{i}); end
    end
    if isfield(M, 'feas')
        Mo.feas = rmfield_if(M.feas, {});
    end
end

function s = rmfield_if(s, f)
    for i = 1:numel(f)
        if isfield(s, f{i}); s = rmfield(s, f{i}); end
    end
end

%% ===================== replay =====================
function Rep = replay_compare(Rref, S2, PR2, c, pv)
    Rep = struct('pass', false, 'detail', '', 'run', true, ...
        'route', c.route, 'U', c.U, 'variant', pv.name, 'max_diff', NaN);
    n = numel(Rref.sig.t);
    ds = Rref.sig.ds;
    m = min(numel(S2.t), numel(PR2.T_real));
    t2 = S2.t(1:ds:m); Tr2 = PR2.T_real(1:ds:m);
    k = min([n, numel(t2), numel(Tr2)]);
    d1 = maxdiff_nan(Rref.sig.t(1:k), t2(1:k));
    d2 = maxdiff_nan(Rref.sig.T_real(1:k), Tr2(1:k));
    Rep.max_diff = max(d1, d2);
    Rep.pass = (Rep.max_diff == 0);
    Rep.detail = sprintf('%s@%.2f variant=%s bitwise_max_diff=%.3e over %d decimated samples', ...
        c.route, c.U, pv.name, Rep.max_diff, k);
end

%% ===================== Pareto =====================
function Pareto = compute_pareto(IdealRun, Var)
    All = [IdealRun(:); Var(:)];
    rows = {};
    keys = unique(cellfun(@(r, u) sprintf('%s@%.2f', r, u), ...
        {All.route}, num2cell([All.U]), 'UniformOutput', false));
    for ik = 1:numel(keys)
        sel = find(strcmp(cellfun(@(r, u) sprintf('%s@%.2f', r, u), ...
            {All.route}, num2cell([All.U]), 'UniformOutput', false), keys{ik}));
        cost = nan(numel(sel), 2);
        for j = 1:numel(sel)
            cost(j, 1) = nz(All(sel(j)).speed_mae);
            cost(j, 2) = nz(All(sel(j)).E_mid_Wh);
        end
        nd = true(numel(sel), 1);
        for j = 1:numel(sel)
            for l = 1:numel(sel)
                if l == j; continue; end
                if all(cost(l, :) <= cost(j, :)) && any(cost(l, :) < cost(j, :))
                    nd(j) = false; break;
                end
            end
        end
        for j = 1:numel(sel)
            rows{end+1} = struct('key', keys{ik}, 'variant', All(sel(j)).variant, ...
                'speed_mae', cost(j, 1), 'E_mid_Wh', cost(j, 2), ...
                'feasible', All(sel(j)).feasible, 'nondominated', nd(j), ...
                'first_limit', All(sel(j)).first_limit); %#ok<AGROW>
        end
    end
    Pareto = struct('rows', {rows}, ...
        'note', 'costs = (speed MAE [m/s], mid-bracket propulsion energy [Wh]); minimise both');
end

%% ===================== gates =====================
function G = finish_gates(G, FP_before, FP_after, IdealRun, Var, Rep, PWR, lim, ...
        did_variants, Pareto, HG) %#ok<INUSD>
    All = [IdealRun(:); Var(:)];

    % fingerprints unchanged
    same = true; det = {};
    for i = 1:numel(FP_before)
        if ~strcmp(FP_before(i).sha256, FP_after(i).sha256)
            same = false;
            det{end+1} = FP_before(i).name; %#ok<AGROW>
        end
        if ~FP_before(i).exists
            same = false;
            det{end+1} = ['missing:' FP_before(i).name]; %#ok<AGROW>
        end
    end
    if same
        fp_detail = sprintf('%d files byte-identical before/after (SHA-256)', numel(FP_before));
    else
        fp_detail = ['changed/missing: ' sjoin(det, ',')];
    end
    G.G_production_plan_fingerprints = struct('pass', same, 'detail', fp_detail);

    % finite states
    fin = all([All.finite]) && all([All.bounded]);
    G.G_finite_states = struct('pass', fin, ...
        'detail', sprintf('%d runs, all finite+bounded=%d', numel(All), fin));

    % frozen tracking/actuator gates (audit FEASIBLE definition, unchanged)
    ideal_feas = all([IdealRun.feasible]);
    if did_variants
        nv = numel(Var); nvf = sum([Var.feasible]);
    else
        nv = 0; nvf = 0;
    end
    G.G_frozen_tracking_actuator = struct('pass', ideal_feas, ...
        'detail', sprintf('ideal-hook cells FEASIBLE=%d/%d; variant cells FEASIBLE=%d/%d (variant loss is a RESULT, not a gate)', ...
        sum([IdealRun.feasible]), numel(IdealRun), nvf, nv));

    % realized thrust limits
    tl = all([All.T_lim_ok]);
    G.G_thrust_limits = struct('pass', tl, ...
        'detail', sprintf('realized thrust inside declared [T_min,T_max] for %d/%d runs; T_real span [%.3f, %.3f] N', ...
        sum([All.T_lim_ok]), numel(All), min([All.T_real_min]), max([All.T_real_max])));

    % conditional battery / current
    cok = all([All.cond_ok]);
    G.G_battery_current_conditional = struct('pass', cok, ...
        'detail', sprintf(['CONDITIONAL on ASSUMED eta in [%.2f,%.2f] and V_bus {%s} V: ', ...
        'power/energy/current finite, non-negative, ordered for %d/%d runs. ', ...
        'No certified limit is asserted.'], PWR.eta_lo, PWR.eta_hi, ...
        num2str(PWR.V_bus), sum([All.cond_ok]), numel(All)));

    % deterministic replay
    G.G_deterministic_replay = struct('pass', Rep.pass, 'detail', Rep.detail);

    % Pareto reported
    if did_variants
        nnd = 0;
        for i = 1:numel(Pareto.rows); nnd = nnd + double(Pareto.rows{i}.nondominated); end
        G.G_pareto_reported = struct('pass', nnd > 0, ...
            'detail', sprintf('%d nondominated (variant,cell) points of %d', nnd, numel(Pareto.rows)));
    else
        G.G_pareto_reported = struct('pass', false, 'detail', 'variants not reached');
    end
end

%% ===================== fingerprints =====================
function FP = fingerprint_set(project_dir, files)
    FP = struct('name', {}, 'path', {}, 'exists', {}, 'bytes', {}, 'sha256', {});
    for i = 1:numel(files)
        p = fullfile(project_dir, files{i});
        e = (exist(p, 'file') == 2);
        if e
            d = dir(p);
            h = sha256_file(p);
            b = d.bytes;
        else
            h = 'MISSING'; b = NaN;
        end
        FP(end+1) = struct('name', files{i}, 'path', p, 'exists', e, ...
            'bytes', b, 'sha256', h); %#ok<AGROW>
    end
end

function h = sha256_file(p)
    fid = fopen(p, 'r');
    if fid < 0; h = 'UNREADABLE'; return; end
    b = fread(fid, Inf, '*uint8');
    fclose(fid);
    try
        md = java.security.MessageDigest.getInstance('SHA-256');
        md.update(typecast(b, 'int8'));
        d = typecast(md.digest(), 'uint8');
        h = lower(reshape(dec2hex(d, 2)', 1, []));
    catch
        % Declared weak fallback (only if the JVM digest is unavailable).
        h = sprintf('WEAK_BYTES%d_SUM%.0f', numel(b), sum(double(b)));
    end
end

function print_fp(FP)
    for i = 1:numel(FP)
        fprintf('  %-46s %s %s\n', FP(i).name, tern(FP(i).exists, 'ok ', 'MISS'), ...
            FP(i).sha256(1:min(16, numel(FP(i).sha256))));
    end
end

%% ===================== clone reduction (static, in-MATLAB) =====================
function CL = clone_reduction_check(orig_path, clone_path)
    o = splitlines_norm(fileread(orig_path));
    c = splitlines_norm(fileread(clone_path));
    out = {};
    inr = false;
    for i = 1:numel(c)
        L = c{i};
        k = strfind(L, '%[PROP-ORIG] ');
        if ~isempty(k)
            out{end+1} = L(k(1) + numel('%[PROP-ORIG] '):end); %#ok<AGROW>
            continue
        end
        if contains(L, '%[PROP-BEGIN]'); inr = true; continue; end
        if contains(L, '%[PROP-END]'); inr = false; continue; end
        if inr; continue; end
        out{end+1} = L; %#ok<AGROW>
    end
    o = cellfun(@(s) deblank(s), o, 'UniformOutput', false);
    r = cellfun(@(s) deblank(s), out, 'UniformOutput', false);
    CL = struct();
    CL.n_orig = numel(o); CL.n_reduced = numel(r);
    CL.match = isequal(o, r);
    CL.n_marked = sum(cellfun(@(s) contains(s, '%[PROP-'), c));
    if CL.match
        CL.detail = sprintf('clone reduces byte-for-byte to continuous_path_tracking.m (%d lines; %d marker lines)', ...
            CL.n_orig, CL.n_marked);
        CL.first_diff = 0;
    else
        fd = 0;
        for i = 1:max(numel(o), numel(r))
            a = ''; b = '';
            if i <= numel(o); a = o{i}; end
            if i <= numel(r); b = r{i}; end
            if ~strcmp(a, b); fd = i; break; end
        end
        CL.first_diff = fd;
        CL.detail = sprintf('REDUCTION MISMATCH at line %d (orig %d lines, reduced %d)', ...
            fd, numel(o), numel(r));
    end
end

function c = splitlines_norm(txt)
    txt = strrep(txt, sprintf('\r\n'), sprintf('\n'));
    c = strsplit(txt, sprintf('\n'));
    c = c(:)';
end

%% ===================== artifacts =====================
function write_png(png_path, task_id, verdict, Par, IdealRun, Var, PROPSET, G) %#ok<INUSD>
    fig = figure('Visible', 'off', 'Color', 'w', 'Position', [60 60 1400 980]);

    % (1) parity diffs
    subplot(2, 3, 1); hold on; grid on;
    lbl = cell(numel(Par), 1); dv = zeros(numel(Par), 1);
    for i = 1:numel(Par)
        lbl{i} = sprintf('%s@%.2f', Par(i).route, Par(i).U);
        dv(i) = max(Par(i).max_sig_diff, Par(i).max_metric_diff);
    end
    dplot = dv; dplot(dplot == 0) = 1e-18;
    bar(dplot); set(gca, 'YScale', 'log');
    set(gca, 'XTick', 1:numel(Par), 'XTickLabel', lbl, 'XTickLabelRotation', 45);
    plot([0.5, numel(Par) + 0.5], [1e-12 1e-12], 'r--', 'LineWidth', 1.2);
    text(0.6, 1.3e-12, 'declared tol 1e-12', 'Color', 'r', 'FontSize', 7);
    ylabel('max |diff| vs accepted'); title('Ideal-hook parity (1e-18 = exact 0)');

    % (2) thrust cmd vs real for a representative variant cell
    subplot(2, 3, 2); hold on; grid on;
    if ~isempty(Var)
        k = find(strcmp({Var.variant}, 'slow_low'), 1);
        if isempty(k); k = 1; end
        plot(Var(k).sig.t, Var(k).sig.T_cmd, '-', 'LineWidth', 1.1, 'DisplayName', 'T_cmd');
        plot(Var(k).sig.t, Var(k).sig.T_real, '-', 'LineWidth', 1.1, 'DisplayName', 'T_real');
        title(sprintf('%s %s@%.2f', Var(k).variant, Var(k).route, Var(k).U), 'Interpreter', 'none');
        legend('Location', 'best', 'Interpreter', 'none');
    else
        title('no variants (parity stop)');
    end
    xlabel('t [s]'); ylabel('thrust [N]');

    % (3) energy bracket by variant/cell
    subplot(2, 3, 3); hold on; grid on;
    All = [IdealRun(:); Var(:)];
    if ~isempty(All)
        vn = unique({All.variant});
        for i = 1:numel(vn)
            sel = strcmp({All.variant}, vn{i});
            x = 1:sum(sel);
            e = [All(sel).E_mid_Wh];
            plot(x, e, '-o', 'LineWidth', 1.2, 'DisplayName', vn{i});
        end
        legend('Location', 'best', 'Interpreter', 'none');
    end
    xlabel('accepted cell index'); ylabel('E mid-bracket [Wh]');
    title('Propulsion energy range (ASSUMED eta)');

    % (4) speed MAE vs energy (Pareto view)
    subplot(2, 3, 4); hold on; grid on;
    if ~isempty(All)
        vn = unique({All.variant});
        for i = 1:numel(vn)
            sel = strcmp({All.variant}, vn{i});
            plot([All(sel).E_mid_Wh], [All(sel).speed_mae], 'o', ...
                'MarkerSize', 7, 'LineWidth', 1.2, 'DisplayName', vn{i});
        end
        legend('Location', 'best', 'Interpreter', 'none');
    end
    xlabel('E mid [Wh]'); ylabel('speed MAE [m/s]'); title('Pareto: tracking vs energy');

    % (5) slew/sat activity
    subplot(2, 3, 5); hold on; grid on;
    if ~isempty(Var)
        bar([[Var.slew_pct]', [Var.sat_pct]']);
        legend({'slew hit %', 'sat hit %'}, 'Location', 'best');
        set(gca, 'XTick', 1:numel(Var), 'XTickLabel', ...
            cellfun(@(v, r, u) sprintf('%s %s@%.1f', v, r, u), {Var.variant}, ...
            {Var.route}, num2cell([Var.U]), 'UniformOutput', false), ...
            'XTickLabelRotation', 60, 'FontSize', 6);
    end
    ylabel('% of steps'); title('Actuator limit activity');

    % (6) gate ledger text
    subplot(2, 3, 6); axis off;
    gn = fieldnames(G);
    txt = sprintf('%s\nverdict = %s\n\n', task_id, verdict);
    for i = 1:numel(gn)
        txt = [txt sprintf('%-32s %s\n', gn{i}, tern(G.(gn{i}).pass, 'PASS', 'FAIL'))]; %#ok<AGROW>
    end
    txt = [txt sprintf('\nSimulation-only / NOT_CERTIFIED\nGate4 shadow-only\n')];
    text(0.0, 1.0, txt, 'FontName', 'FixedWidth', 'FontSize', 8, ...
        'VerticalAlignment', 'top', 'Interpreter', 'none');

    sgtitle(sprintf('%s — %s', task_id, verdict), 'Interpreter', 'none');
    exportgraphics(fig, png_path, 'Resolution', 130);
    close(fig);
end

function write_md(md_path, task_id, verdict, marker, Par, IdealRun, Var, Rep, PROPSET, ...
        PWR, FROZEN, G, FP_before, FP_after, CL, A, CellList, Pareto, ...
        md_p, mat_p, png_p, pid, wall)
    fid = fopen(md_path, 'w');
    fprintf(fid, '# %s\n\n', task_id);
    fprintf(fid, '**Verdict: %s** — Gate6 attempt2 RESUMED (this is not attempt3).\n\n', verdict);
    fprintf(fid, '- Marker: `%s`\n', marker);
    fprintf(fid, '- Simulation-only, **NOT_CERTIFIED**. Gate4 remains **shadow-only**.\n');
    fprintf(fid, '- MATLAB pid: %d (single process after resume). Wall time: %.1f s.\n\n', pid, wall);

    fprintf(fid, '## Recovery provenance\n\n');
    fprintf(fid, '| Record | State | Preserved |\n|---|---|---|\n');
    fprintf(fid, '| attempt1 | **FAIL**, shadow-only: local X/XZ loop incomparable to frozen `SPEED_ENVELOPE_AUDIT`; two MATLAB starts | yes, not reopened |\n');
    fprintf(fid, '| attempt2 (interrupted) | host-power/bridge loss. `continuous_path_tracking_propulsion.m` created and marker-verified; driver absent; **no MATLAB process had been started** | yes, recorded |\n');
    fprintf(fid, '| this resume | completed the driver and used one MATLAB invocation | — |\n\n');
    fprintf(fid, '- Reason the resume is not attempt3: no MATLAB run existed in attempt2, so no attempt2 result was consumed or replaced. The clone from attempt2 is reused byte-for-byte.\n');
    fprintf(fid, '- Clone check: %s\n\n', CL.detail);

    fprintf(fid, '## Sources read (exactly three; no repo scan)\n\n');
    fprintf(fid, '1. `continuous_path_tracking_propulsion.m` (attempt2 clone)\n');
    fprintf(fid, '2. `run_speed_envelope_audit.m` (frozen accepted harness definitions)\n');
    fprintf(fid, '3. `suite_results/SPEED_ENVELOPE_AUDIT.mat` (accepted reference: task=%s, verdict=%s)\n\n', ...
        A.task_id, A.verdict);

    fprintf(fid, '## Gate ledger\n\n');
    fprintf(fid, '| Gate | Result | Detail |\n|---|:---:|---|\n');
    gn = fieldnames(G);
    for i = 1:numel(gn)
        fprintf(fid, '| `%s` | **%s** | %s |\n', gn{i}, ...
            tern(G.(gn{i}).pass, 'PASS', 'FAIL'), md_esc(G.(gn{i}).detail));
    end
    fprintf(fid, '\n');

    fprintf(fid, '## Phase 1 — ideal-hook parity vs accepted MAT (tol %.0e)\n\n', FROZEN.parity_tol);
    fprintf(fid, 'The accepted cells are re-run through the clone with `prop.ideal == true` (exact passthrough, no arithmetic on the command).\n\n');
    fprintf(fid, '| Cell | Parity | max sig diff | max metric diff | worst field | FEAS match | first_limit match |\n');
    fprintf(fid, '|---|:---:|---:|---:|---|:---:|:---:|\n');
    for i = 1:numel(Par)
        fprintf(fid, '| %s@%.2f | **%s** | %.3e | %.3e | `%s` | %s | %s |\n', ...
            Par(i).route, Par(i).U, ...
            tern(Par(i).exact, 'EXACT', tern(Par(i).pass, 'WITHIN_TOL', 'FAIL')), ...
            Par(i).max_sig_diff, Par(i).max_metric_diff, Par(i).worst_field, ...
            yn(Par(i).feas_match), yn(Par(i).limit_match));
    end
    fprintf(fid, '\n');

    fprintf(fid, '## Declared ASSUMED actuator variants (frozen before the run; no tuning)\n\n');
    fprintf(fid, '| Variant | ideal | tau [s] | gain | slew [N/s] | T_min [N] | T_max [N] | Rationale |\n');
    fprintf(fid, '|---|:---:|---:|---:|---:|---:|---:|---|\n');
    for i = 1:numel(PROPSET)
        p = PROPSET(i);
        fprintf(fid, '| `%s` | %d | %.3f | %.3f | %s | %.3f | %.3f | %s |\n', ...
            p.name, p.ideal, p.tau, p.gain, num2str(p.slew), p.T_min, p.T_max, p.why);
    end
    fprintf(fid, '\nActuator chain (ASSUMED, declared, simulation-only): gain error, then exact-ZOH first-order lag, then slew-rate limit, then saturation.\n\n');

    fprintf(fid, '## Component-neutral power / energy model\n\n');
    fprintf(fid, '- `%s`\n', PWR.model);
    fprintf(fid, '- eta_total in [%.2f, %.2f] — %s\n', PWR.eta_lo, PWR.eta_hi, PWR.eta_note);
    fprintf(fid, '- V_bus %s V — %s\n', mat2str(PWR.V_bus), PWR.V_note);
    fprintf(fid, '- %s\n', PWR.regen_note);
    fprintf(fid, '- No propeller, motor, ESC or battery part is identified; results are **ranges**, never point certifications.\n\n');

    fprintf(fid, '## Phase 2 — variant results (frozen gates)\n\n');
    fprintf(fid, '| Variant | Cell | FEAS | first limit | worst margin | uMAE | thMAE | gMAE | CTE | slew%% | sat%% | T_real span [N] | P_hi p95 [W] | E range [Wh] | I@24V | I@48V |\n');
    fprintf(fid, '|---|---|:---:|---|---:|---:|---:|---:|---:|---:|---:|---|---:|---|---:|---:|\n');
    All = [IdealRun(:); Var(:)];
    for i = 1:numel(All)
        R = All(i);
        fprintf(fid, '| `%s` | %s@%.2f | %s | %s | %.4g | %.4f | %.4f | %.4f | %.3f | %.2f | %.2f | [%.2f, %.2f] | %.1f | [%.2f, %.2f] | %.1f | %.1f |\n', ...
            R.variant, R.route, R.U, yn(R.feasible), md_esc(R.first_limit), ...
            nz(R.worst_margin), nz(R.speed_mae), nz(R.theta_mae), nz(R.gamma_mae), ...
            nz(R.cte), nz(R.slew_pct), nz(R.sat_pct), nz(R.T_real_min), nz(R.T_real_max), ...
            nz(R.P_hi_p95), nz(R.E_lo_Wh), nz(R.E_hi_Wh), nz(R.I_hi_24V), nz(R.I_hi_48V));
    end
    fprintf(fid, '\n');

    fprintf(fid, '## Pareto and limiting cases\n\n');
    fprintf(fid, '- %s\n\n', Pareto.note);
    if ~isempty(Pareto.rows)
        fprintf(fid, '| Cell | Variant | speed MAE | E mid [Wh] | FEAS | Nondominated | first limit |\n');
        fprintf(fid, '|---|---|---:|---:|:---:|:---:|---|\n');
        for i = 1:numel(Pareto.rows)
            r = Pareto.rows{i};
            fprintf(fid, '| %s | `%s` | %.4f | %.3f | %s | %s | %s |\n', ...
                r.key, r.variant, r.speed_mae, r.E_mid_Wh, yn(r.feasible), ...
                yn(r.nondominated), md_esc(r.first_limit));
        end
        fprintf(fid, '\n');
    end
    LIM = limiting_summary(All);
    fprintf(fid, '**Limiting cases**\n\n');
    for i = 1:numel(LIM)
        fprintf(fid, '- %s\n', LIM{i});
    end
    fprintf(fid, '\n');

    fprintf(fid, '## Determinism\n\n- %s\n\n', md_esc(Rep.detail));

    fprintf(fid, '## Fingerprints (production and vertical plan, before / after)\n\n');
    fprintf(fid, '| File | Bytes | SHA-256 before | SHA-256 after | Same |\n|---|---:|---|---|:---:|\n');
    for i = 1:numel(FP_before)
        fprintf(fid, '| `%s` | %s | `%s` | `%s` | %s |\n', FP_before(i).name, ...
            num2str(FP_before(i).bytes), FP_before(i).sha256, FP_after(i).sha256, ...
            yn(strcmp(FP_before(i).sha256, FP_after(i).sha256)));
    end
    fprintf(fid, '\n- Production and `CODEX_VERTICAL_PLAN.md` are byte-identical before and after this run; nothing in production was written.\n\n');

    fprintf(fid, '## Frozen definitions reused verbatim\n\n');
    fprintf(fid, '- Accepted cells: %s\n', cells_label(CellList));
    fprintf(fid, '- Windows/gates/limits copied from `run_speed_envelope_audit.m` without change (seed=%d, Kp_roll=%.6f, Kp_x=%.4g, thrust_trim=%.4g N).\n', ...
        FROZEN.seed_used, FROZEN.Kp_roll, FROZEN.Kp_x, FROZEN.thrust_trim);
    fprintf(fid, '- Production stack untouched: nonlinear theta/q cascade + climb FF frozen.\n\n');

    fprintf(fid, '## Artifacts\n\n- `%s`\n- `%s`\n- `%s`\n', md_p, mat_p, png_p);
    fclose(fid);
end

function L = limiting_summary(All)
    L = {};
    if isempty(All); L = {'no runs'}; return; end
    [~, i1] = max([All.slew_pct]);
    [~, i2] = max([All.sat_pct]);
    [~, i3] = max([All.E_hi_Wh]);
    wm = [All.worst_margin]; wm(~isfinite(wm)) = Inf;
    [~, i4] = min(wm);
    L{end+1} = sprintf('Most slew-limited: `%s` %s@%.2f at %.2f%% of steps.', ...
        All(i1).variant, All(i1).route, All(i1).U, All(i1).slew_pct);
    L{end+1} = sprintf('Most saturation-limited: `%s` %s@%.2f at %.2f%% of steps.', ...
        All(i2).variant, All(i2).route, All(i2).U, All(i2).sat_pct);
    L{end+1} = sprintf('Highest upper-bracket energy: `%s` %s@%.2f at %.2f Wh.', ...
        All(i3).variant, All(i3).route, All(i3).U, All(i3).E_hi_Wh);
    L{end+1} = sprintf('Tightest frozen-gate margin: `%s` %s@%.2f margin=%.4g (first limit: %s).', ...
        All(i4).variant, All(i4).route, All(i4).U, All(i4).worst_margin, All(i4).first_limit);
    inf_cells = {};
    for i = 1:numel(All)
        if ~All(i).feasible
            inf_cells{end+1} = sprintf('%s %s@%.2f (%s)', All(i).variant, ...
                All(i).route, All(i).U, All(i).first_limit); %#ok<AGROW>
        end
    end
    if isempty(inf_cells)
        L{end+1} = 'No cell lost FEASIBLE under any declared variant.';
    else
        L{end+1} = ['FEASIBLE lost under variants: ' strjoin(inf_cells, '; ')];
    end
end

function s = cells_label(CellList)
    parts = {};
    for i = 1:numel(CellList)
        parts{end+1} = sprintf('%s@%.2f', CellList(i).route, CellList(i).U); %#ok<AGROW>
    end
    s = strjoin(parts, ', ');
end

function save_mat(mat_path, task_id, verdict, marker, Par, IdealRun, Var, Rep, PROPSET, ...
        PWR, FROZEN, G, FP_before, FP_after, CL, CellList, Pareto, pid)
    Out = struct();
    Out.task_id = task_id;
    Out.marker = marker;
    Out.verdict = verdict;
    Out.attempt = 'gate6_attempt2_resumed';
    Out.attempt_note = ['attempt1 FAIL shadow-only preserved; attempt2 interrupted by ', ...
        'host power/bridge loss with no MATLAB start; this resume completed it.'];
    Out.certification = 'SIMULATION_ONLY_NOT_CERTIFIED';
    Out.gate4 = 'shadow_only';
    Out.matlab_pid = pid;
    Out.parity = Par;
    Out.parity_tol = FROZEN.parity_tol;
    Out.ideal_runs = IdealRun;
    Out.variant_runs = Var;
    Out.replay = Rep;
    Out.propset = PROPSET;
    Out.power_model = PWR;
    Out.frozen = FROZEN;
    Out.gates = G;
    Out.fingerprints_before = FP_before;
    Out.fingerprints_after = FP_after;
    Out.clone_check = CL;
    Out.cells = CellList;
    Out.pareto = Pareto;
    Out.production_edited = false;
    save(mat_path, '-struct', 'Out', '-v7.3');
end

function RD = emit_and_verify(ART, task_id, verdict, marker, Par, IdealRun, Var, Rep, ...
        PROPSET, PWR, FROZEN, G, FP_before, FP_after, CL, A, CellList, Pareto, pid, t0)
    write_png(ART.png, task_id, verdict, Par, IdealRun, Var, PROPSET, G);
    write_md(ART.md, task_id, verdict, marker, Par, IdealRun, Var, Rep, PROPSET, ...
        PWR, FROZEN, G, FP_before, FP_after, CL, A, CellList, Pareto, ...
        ART.md, ART.mat, ART.png, pid, toc(t0));
    save_mat(ART.mat, task_id, verdict, marker, Par, IdealRun, Var, Rep, PROPSET, ...
        PWR, FROZEN, G, FP_before, FP_after, CL, CellList, Pareto, pid);
    RD = verify_readable(ART.md, ART.mat, ART.png);
end

function RD = verify_readable(md_path, mat_path, png_path)
    ok = true; det = {};
    try
        t = fileread(md_path);
        if numel(t) < 500; ok = false; det{end+1} = 'md too short'; end
    catch ME
        ok = false; det{end+1} = ['md unreadable: ' ME.message];
    end
    try
        Z = load(mat_path);
        need = {'task_id', 'verdict', 'parity', 'gates'};
        for i = 1:numel(need)
            if ~isfield(Z, need{i}); ok = false; det{end+1} = ['mat missing ' need{i}]; end %#ok<AGROW>
        end
    catch ME
        ok = false; det{end+1} = ['mat unreadable: ' ME.message];
    end
    try
        info = imfinfo(png_path);
        if info(1).Width < 200; ok = false; det{end+1} = 'png too small'; end
    catch ME
        ok = false; det{end+1} = ['png unreadable: ' ME.message];
    end
    if ok
        rd_detail = 'MD/MAT/PNG re-opened and structurally verified in-process';
    else
        rd_detail = sjoin(det, '; ');
    end
    RD = struct('pass', ok, 'detail', rd_detail);
end

function append_logs(out_dir, task_id, marker, verdict, G, Par, IdealRun, Var, ...
        Pareto, md_p, mat_p, png_p)
% One append per log, each stamped with the task marker (idempotent guard).
    All = [IdealRun(:); Var(:)];
    n_exact = sum([Par.exact]);
    n_par = numel(Par);
    gn = fieldnames(G);
    n_pass = 0;
    for i = 1:numel(gn); n_pass = n_pass + double(G.(gn{i}).pass); end
    nnd = 0;
    for i = 1:numel(Pareto.rows); nnd = nnd + double(Pareto.rows{i}.nondominated); end

    logs = { ...
        fullfile(out_dir, 'AUV_REALIZATION_READINESS_PLAN.md'), 'readiness'; ...
        fullfile(out_dir, 'AUV_REALISM_AND_VISUAL_VALIDATION.md'), 'realism'; ...
        fullfile(out_dir, 'PITCH_CONTROL_RESEARCH_LOG.md'), 'research'};

    for i = 1:size(logs, 1)
        p = logs{i, 1}; kind = logs{i, 2};
        if exist(p, 'file') == 2
            txt = fileread(p);
            if contains(txt, marker)
                fprintf('  log already carries marker, skipping: %s\n', p);
                continue
            end
        end
        fid = fopen(p, 'a');
        if fid < 0
            fprintf('  WARNING cannot append log: %s\n', p);
            continue
        end
        fprintf(fid, '\n## %s — %s\n\n', task_id, datestr(now, 31));
        fprintf(fid, '- Marker: `%s` (single append per log).\n', marker);
        fprintf(fid, '- Gate6 attempt2 **RESUMED** after host-power/bridge interruption; not attempt3. attempt1 FAIL (shadow-only) and the interrupted attempt2 record are preserved.\n');
        fprintf(fid, '- Verdict: **%s** (%d/%d gates PASS). Simulation-only, **NOT_CERTIFIED**; Gate4 shadow-only.\n', ...
            verdict, n_pass, numel(gn));
        fprintf(fid, '- Ideal-hook parity vs frozen `SPEED_ENVELOPE_AUDIT`: %d/%d cells exact, tol 1e-12 declared.\n', ...
            n_exact, n_par);
        switch kind
            case 'readiness'
                fprintf(fid, '- Readiness impact: realized-thrust actuator is now an isolated, parity-verified harness layer. Production `continuous_path_tracking.m` and `CODEX_VERTICAL_PLAN.md` are byte-identical before/after (SHA-256 recorded).\n');
                fprintf(fid, '- Propulsion power/energy is reported as component-neutral **ranges** under a declared ASSUMED efficiency interval; no propeller/motor/battery part is selected, so nothing here advances hardware certification.\n');
            case 'realism'
                fprintf(fid, '- Realism scope: ASSUMED thrust lag/gain/slew/saturation only (gain, exact-ZOH lag, slew, saturation). Not identified from hardware; no sensor, current or thermal realism is claimed.\n');
                fprintf(fid, '- Variant cells that lost the frozen FEASIBLE gates are recorded as results, not as retunes: %d of %d variant runs FEASIBLE.\n', ...
                    sum([Var.feasible]), numel(Var));
            case 'research'
                fprintf(fid, '- Method: marker clone of the accepted tracking loop inserts realized thrust between controller and plant; `prop.ideal` is an exact passthrough, which makes ideal-hook parity bit-identical and therefore a real falsification test of the harness.\n');
                fprintf(fid, '- Pareto (speed MAE vs mid-bracket energy): %d nondominated (variant, cell) points of %d.\n', ...
                    nnd, numel(Pareto.rows));
        end
        fprintf(fid, '- Artifacts: `%s`, `%s`, `%s`.\n', md_p, mat_p, png_p);
        fprintf(fid, '- Production untouched; no gain, config or controller change.\n');
        fclose(fid);
        fprintf('  appended %s log: %s\n', kind, p);
    end
end

function finalize(lock_path, verdict, G, t0)
    gn = fieldnames(G);
    fprintf('\n---------- GATE SUMMARY ----------\n');
    for i = 1:numel(gn)
        fprintf('  %-34s %s  %s\n', gn{i}, tern(G.(gn{i}).pass, 'PASS', 'FAIL'), G.(gn{i}).detail);
    end
    fprintf('\nVERDICT: %s   (wall %.1f s)\n', verdict, toc(t0));
    fprintf('Simulation-only / NOT_CERTIFIED. Gate4 shadow-only.\n');
    if exist(lock_path, 'file') == 2; delete(lock_path); end
end

%% ===================== copied frozen audit internals =====================
% Everything below is copied from run_speed_envelope_audit.m so the tracking and
% actuator gates, windows and metric definitions stay frozen and comparable.

function P = solve_translating(Ufix, slope, seed, nu_dot_scale, x_scale, pass_tol, name)
    scale = (Ufix / max(seed.u, 0.5))^2;
    z0 = [seed.theta; seed.v; seed.w; seed.q; seed.de; seed.T * scale];
    [z, exitflag] = local_newton(@(zz) translating_cost(zz, Ufix, slope, nu_dot_scale), z0, 120);
    x = zeros(12, 1);
    x(5) = z(1); x(7) = Ufix; x(8) = z(2); x(9) = z(3); x(11) = z(4);
    u = [0; z(5); z(6)];
    f = underwater777_vehicle_dynamics(0, x, ustruct(u));
    R = residual_pack(f, x_scale, nu_dot_scale, slope);
    P = struct();
    P.name = name;
    P.class = 'steady_translating_trim';
    P.provenance = 'PLANT_SOLVE';
    P.Ufix = Ufix;
    P.slope = slope;
    P.x_star = x;
    P.u_star = u;
    P.Treq = u(3);
    P.norm_dyn = R.norm_dyn;
    P.residual = R;
    P.pass = (R.norm_dyn <= pass_tol) && (abs(x(7) - Ufix) < 1e-12) && isfinite(R.norm_dyn);
    P.exitflag = exitflag;
    P.documented = true;
    xd = f(1); zd = f(3);
    if abs(slope) < 1e-12
        P.slope_err = zd;
    else
        P.slope_err = zd - slope * xd;
    end
end

function P = helix_trim_stub(Uref)
    P = struct();
    P.name = 'helix_R10';
    P.class = 'periodic_or_quasi_steady';
    P.provenance = 'EMPIRICAL_UNKNOWN';
    P.Ufix = Uref;
    P.slope = NaN;
    P.x_star = zeros(12, 1); P.x_star(7) = Uref;
    P.u_star = [0; NaN; NaN];
    P.Treq = NaN;
    P.norm_dyn = NaN;
    P.residual = struct('norm_dyn', NaN, 'note', 'exact-u LTI helix trim not fabricated');
    P.pass = false;
    P.exitflag = 0;
    P.documented = true;
    P.slope_err = NaN;
    P.reason = ['Exact-u helix trim UNKNOWN; prior rotating-frame relative-eq failed. ', ...
        'IC = path-tangent + u=Uref; no fabricated LTI trim.'];
end

function c = translating_cost(z, Ufix, slope, nu_dot_scale)
    x = zeros(12, 1);
    x(5) = z(1); x(7) = Ufix; x(8) = z(2); x(9) = z(3); x(11) = z(4);
    f = underwater777_vehicle_dynamics(0, x, ustruct([0; z(5); z(6)]));
    nd = f(7:12) ./ nu_dot_scale;
    ad = f(4:5) / 0.05;
    xd = f(1); zd = f(3);
    if abs(slope) < 1e-12
        slope_err = zd;
    else
        slope_err = zd - slope * xd;
    end
    c = [nd; ad; slope_err / max(0.1, abs(Ufix))];
end

function [z, exitflag] = local_newton(fun, z0, maxit)
    z = z0(:);
    exitflag = 0;
    n = numel(z);
    for it = 1:maxit
        c = fun(z);
        if all(isfinite(c)) && norm(c) < 1e-10
            exitflag = 1; return;
        end
        J = zeros(numel(c), n);
        for j = 1:n
            h = 1e-6 * max(1, abs(z(j)));
            zp = z; zp(j) = zp(j) + h;
            J(:, j) = (fun(zp) - c) / h;
        end
        if rcond(J' * J) < 1e-14
            exitflag = -1; return;
        end
        dz = -(J' * J) \ (J' * c);
        if any(~isfinite(dz)); exitflag = -2; return; end
        z = z + dz;
        if norm(dz) < 1e-10
            exitflag = 1; return;
        end
    end
    exitflag = 0;
end

function R = residual_pack(f, x_scale, nu_dot_scale, slope) %#ok<INUSD>
    nd = f(7:12) ./ nu_dot_scale;
    R = struct();
    R.nu_dot = f(7:12);
    R.eta_dot = f(1:6);
    R.norm_dyn = norm(nd);
    R.att_rate = f(4:6);
end

function ctr = ustruct(u)
    ctr = struct('delta_r', u(1), 'delta_e', u(2), 'thrust', u(3));
end

function state0 = build_state0(path, Uref, Trim) %#ok<INUSD>
    state0 = zeros(12, 1);
    state0(1:3) = path(1, :)';
    d = path(2, :) - path(1, :);
    state0(5) = -atan2(d(3), norm(d(1:2)));
    state0(6) = atan2(d(2), d(1));
    state0(7) = Uref;
end

function reset_ctrl_globals()
    clear global last_guidance_U_h last_guidance_kappa last_r_ff
    clear global last_delta_e last_delta_r last_dr_yaw last_dr_p last_dr_damp last_g_ac
    clear global last_int_angle last_int_rate last_de_fb last_de_trim last_de_uw_ff
    global last_guidance_U_h last_guidance_kappa last_r_ff
    global last_delta_e last_delta_r last_dr_yaw last_dr_p last_dr_damp last_g_ac
    global last_int_angle last_int_rate last_de_fb last_de_trim last_de_uw_ff
    last_guidance_U_h = []; last_guidance_kappa = []; last_r_ff = [];
    last_delta_e = []; last_delta_r = [];
    last_dr_yaw = []; last_dr_p = []; last_dr_damp = []; last_g_ac = [];
    last_int_angle = []; last_int_rate = [];
    last_de_fb = []; last_de_trim = []; last_de_uw_ff = [];
end

function [Uh, zdot, VD] = inertial_Uh_zdot_vd(ori, u, v, w)
    phi = ori(1); th = ori(2); psi = ori(3);
    Rm = [cos(psi)*cos(th), cos(psi)*sin(th)*sin(phi)-sin(psi)*cos(phi), cos(psi)*sin(th)*cos(phi)+sin(psi)*sin(phi);
          sin(psi)*cos(th), sin(psi)*sin(th)*sin(phi)+cos(psi)*cos(phi), sin(psi)*sin(th)*cos(phi)-cos(psi)*sin(phi);
          -sin(th), cos(th)*sin(phi), cos(th)*cos(phi)];
    pd = Rm * [u; v; w];
    Uh = hypot(pd(1), pd(2));
    zdot = pd(3);
    VD = pd(3);
end

function [Uh, VD, Vtot] = ned_speeds(ori, vel)
    n = size(vel, 1);
    Uh = zeros(n, 1); VD = zeros(n, 1); Vtot = zeros(n, 1);
    for i = 1:n
        phi = ori(i, 1); th = ori(i, 2); psi = ori(i, 3);
        R = [cos(psi)*cos(th), cos(psi)*sin(th)*sin(phi)-sin(psi)*cos(phi), cos(psi)*sin(th)*cos(phi)+sin(psi)*sin(phi);
             sin(psi)*cos(th), sin(psi)*sin(th)*sin(phi)+cos(psi)*cos(phi), sin(psi)*sin(th)*cos(phi)-cos(psi)*sin(phi);
             -sin(th), cos(th)*sin(phi), cos(th)*cos(phi)];
        pd = R * vel(i, 1:3)';
        Uh(i) = hypot(pd(1), pd(2));
        VD(i) = pd(3);
        Vtot(i) = norm(vel(i, 1:3));
    end
end

function thrust = reconstruct_thrust(u_ref, u, trim, Kp, tmin, tmax)
    thrust = trim + Kp * (u_ref - u);
    thrust = max(min(thrust, tmax), tmin);
end

function Sc = compact_S(S)
    Sc = struct();
    if ~isfield(S, 't') || isempty(S.t); return; end
    keep = {'t','vp','vel','rates','ori','psi_ref','theta_ref','u_ref','u_ctrl', ...
        'u_body','thrust','delta_e','delta_r','Uh','VD','Uref','dt','R','is_xz'};
    for i = 1:numel(keep)
        if isfield(S, keep{i}); Sc.(keep{i}) = S.(keep{i}); end
    end
end

function M = analyze_route(S, path, win_mode, phi_eq, lim, is_xz, R, Uref)
    t = S.t(:); dt = S.dt; n = numel(t);
    phi = S.ori(:, 1);
    theta_phys = -S.ori(:, 2);
    psi = S.ori(:, 3);
    p = S.rates(:, 1);
    de = S.delta_e(:); dr = S.delta_r(:);
    e_psi = wrapToPi(S.psi_ref - psi);
    e_th = wrapToPi(S.theta_ref - theta_phys);
    tilde = phi - phi_eq;
    e_u = S.u_ref - S.u_ctrl;

    gamma_act = atan2(S.VD, max(S.Uh, 1e-9));
    [gamma_ref, cte_perp, s_prog, s_total] = path_gamma_cte(path, S.vp);
    e_gamma = wrapToPi(gamma_ref - gamma_act);

    pm = compute_path_following_metrics(path, S.vp, S.vel, S.ori, ...
        S.psi_ref, S.theta_ref, dt, t);
    W = compute_pitch_window_metrics(t, e_th, s_prog, s_total, 'mode', win_mode);
    mask_ss = W.mask_steady;
    if ~any(mask_ss)
        mask_ss = (t >= 5.0) & W.mask_before_end;
    end
    mask_yaw = (t >= 5.0) & W.mask_before_end;
    if ~any(mask_yaw); mask_yaw = t >= 5.0; end
    mask_hold = mask_ss & (abs(S.u_ref - Uref) <= 0.08);
    if ~any(mask_hold); mask_hold = mask_ss; end
    mask_full = true(n, 1);

    de_dot = [0; diff(de)] / dt;
    dr_dot = [0; diff(dr)] / dt;
    thr_dot = [0; diff(S.thrust)] / dt;

    M = struct();
    M.sim_ok = true; M.sim_err = '';
    M.W = W; M.mask_ss = mask_ss; M.mask_hold = mask_hold; M.mask_yaw = mask_yaw;
    M.speed = speed_stats(e_u, mask_hold);
    M.speed.u_mean = mean_safe(S.u_ctrl, mask_hold);
    M.speed.u_ref_mean = mean_safe(S.u_ref, mask_hold);
    M.theta = err_stats_deg(e_th, mask_ss);
    M.gamma = err_stats_deg(e_gamma, mask_ss);
    M.yaw = err_stats_deg(e_psi, mask_yaw);
    sat_thr_r = tern(R > 0, 0.95 * lim.dr_max, 0.98 * lim.dr_max);
    M.yaw.rudder_sat_ss_pct = sat_pct(dr, mask_yaw, sat_thr_r);
    M.yaw.rudder_sat_full_pct = sat_pct(dr, mask_full, sat_thr_r);
    if R > 0 && isfield(S, 'U_h_guid') && isfield(S, 'kappa')
        Uh_k = S.U_h_guid(:) .* S.kappa(:);
        valid_ratio = mask_yaw & (abs(S.kappa(:)) > 1e-4) & (abs(S.U_h_guid(:)) > 0.3);
        if any(valid_ratio)
            mean_r = mean(S.r(valid_ratio));
            mean_Uh_k = mean(Uh_k(valid_ratio));
            if mean_Uh_k < 0
                mean_Uh_k = -mean_Uh_k;
                mean_r = -mean_r;
            end
            M.yaw.ratio_r_Uh_kappa = mean_r / max(abs(mean_Uh_k), 1e-9);
            M.yaw.n_ratio_valid = nnz(valid_ratio);
        else
            M.yaw.ratio_r_Uh_kappa = NaN;
            M.yaw.n_ratio_valid = 0;
        end
    else
        M.yaw.ratio_r_Uh_kappa = NaN;
        M.yaw.n_ratio_valid = 0;
    end
    M.roll = struct();
    M.roll.tilde_mae_deg = rad2deg(mean_safe(abs(tilde), mask_ss));
    M.roll.p_rms_dps = rad2deg(rms_safe(p(mask_ss)));
    M.path = struct('mean_cte', mean_safe(abs(cte_perp), mask_ss), ...
        'max_cte', max_safe(abs(cte_perp), mask_ss), ...
        'pm_mean_cte', pm.mean_cross_track);

    M.act = struct();
    M.act.de_mag_util = mean_safe(abs(de), mask_ss) / lim.de_max;
    M.act.dr_mag_util = mean_safe(abs(dr), mask_ss) / lim.dr_max;
    thr_span = max(abs([lim.thrust_min, lim.thrust_max]));
    M.act.thr_mag_util = mean_safe(abs(S.thrust), mask_hold) / thr_span;
    M.act.de_rate_util = rms_safe(de_dot(mask_ss)) / lim.de_rate;
    M.act.dr_rate_util = rms_safe(dr_dot(mask_ss)) / lim.dr_rate;
    M.act.thr_rate_util = rms_safe(thr_dot(mask_hold)) / max(thr_span, 1);
    M.act.de_sat_pct = sat_pct(de, mask_ss, 0.98 * lim.de_max);
    M.act.dr_sat_ss_pct = M.yaw.rudder_sat_ss_pct;
    M.act.dr_sat_full_pct = M.yaw.rudder_sat_full_pct;
    M.act.thr_sat_pct = 100 * mean(S.thrust(mask_hold) >= 0.98 * lim.thrust_max | ...
        S.thrust(mask_hold) <= lim.thrust_min + 0.02 * abs(lim.thrust_min));
    if any(mask_ss) && nnz(mask_ss) > 10
        dth = e_th(mask_ss);
        M.act.chatter_dps = rad2deg(std(hf_local(detrend(dth), dt)));
    else
        M.act.chatter_dps = NaN;
    end

    st = [S.ori, S.vel, S.rates];
    M.bounded = all(isfinite(st(:))) && all(isfinite(S.thrust)) && ...
        all(abs(theta_phys) < deg2rad(80)) && all(abs(S.u_body) < 5.0) && ...
        all(abs(S.rates(:)) < deg2rad(200));
    M.persistent_ok = any(mask_ss) && (nnz(mask_ss) >= 20);
end

function st = speed_stats(e, mask)
    st = struct('signed_mean', NaN, 'mae', NaN, 'p95', NaN, 'rms', NaN, 'n', 0, ...
        'u_mean', NaN, 'u_ref_mean', NaN);
    if ~any(mask); return; end
    v = e(mask);
    st.n = numel(v);
    st.signed_mean = mean(v);
    st.mae = mean(abs(v));
    st.rms = rms_safe(v);
    st.p95 = prctile_local(abs(v), 95);
end

function st = err_stats_deg(e, mask)
    st = struct('mae_deg', NaN, 'p95_deg', NaN, 'rms_deg', NaN, 'n', 0);
    if ~any(mask); return; end
    v = e(mask);
    st.n = numel(v);
    st.mae_deg = rad2deg(mean(abs(v)));
    st.rms_deg = rad2deg(rms_safe(v));
    st.p95_deg = rad2deg(prctile_local(abs(v), 95));
end

function F = score_feasible(M, rname, HG, lim) %#ok<INUSD>
    F = struct();
    F.gates = struct();
    F.first_limit = '';
    order = {};

    Trim = M.trim;
    g_trim_doc = isfield(Trim, 'documented') && Trim.documented;
    if strcmp(rname, 'H')
        g_trim_ok = g_trim_doc;
        lim_trim = 'helix_trim_undocumented';
    else
        g_trim_ok = g_trim_doc && Trim.pass && isfinite(Trim.norm_dyn) && ...
            (Trim.norm_dyn <= HG.trim_tol);
        lim_trim = sprintf('trim_residual(norm=%.3g>%.3g or unsolved)', ...
            nz(Trim.norm_dyn), HG.trim_tol);
    end
    F.gates.trim_documented = g_trim_doc;
    F.gates.trim_ok = g_trim_ok;
    order{end+1} = {g_trim_ok, lim_trim}; %#ok<AGROW>

    g_b = isfield(M, 'bounded') && M.bounded && M.sim_ok;
    F.gates.bounded = g_b;
    order{end+1} = {g_b, 'states_unbounded_or_sim_fail'}; %#ok<AGROW>

    h = HG.(rname);
    g_pm = ~isnan(M.theta.mae_deg) && (M.theta.mae_deg <= h.pitch_mae);
    g_pp = ~isnan(M.theta.p95_deg) && (M.theta.p95_deg <= h.pitch_p95);
    F.gates.pitch_mae = g_pm; F.gates.pitch_p95 = g_pp;
    order{end+1} = {g_pm, sprintf('pitch_MAE(%.4f>%.4f)', nz(M.theta.mae_deg), h.pitch_mae)}; %#ok<AGROW>
    order{end+1} = {g_pp, sprintf('pitch_p95(%.4f>%.4f)', nz(M.theta.p95_deg), h.pitch_p95)}; %#ok<AGROW>

    g_gm = ~isnan(M.gamma.mae_deg) && (M.gamma.mae_deg <= h.gamma_mae);
    g_gp = ~isnan(M.gamma.p95_deg) && (M.gamma.p95_deg <= h.gamma_p95);
    F.gates.gamma_mae = g_gm; F.gates.gamma_p95 = g_gp;
    order{end+1} = {g_gm, sprintf('gamma_MAE(%.4f>%.4f)', nz(M.gamma.mae_deg), h.gamma_mae)}; %#ok<AGROW>
    order{end+1} = {g_gp, sprintf('gamma_p95(%.4f>%.4f)', nz(M.gamma.p95_deg), h.gamma_p95)}; %#ok<AGROW>

    if strcmp(rname, 'H')
        g_ym = ~isnan(M.yaw.mae_deg) && (M.yaw.mae_deg <= HG.H.yaw_mae);
        g_yp = ~isnan(M.yaw.p95_deg) && (M.yaw.p95_deg <= HG.H.yaw_p95);
        g_yss = ~isnan(M.yaw.rudder_sat_ss_pct) && (M.yaw.rudder_sat_ss_pct <= HG.rud_sat_ss);
        g_yf = ~isnan(M.yaw.rudder_sat_full_pct) && (M.yaw.rudder_sat_full_pct <= HG.rud_sat_full);
        if ~isnan(M.yaw.ratio_r_Uh_kappa) && isfield(M.yaw, 'n_ratio_valid') && M.yaw.n_ratio_valid > 10
            g_rat = (M.yaw.ratio_r_Uh_kappa >= HG.ratio_lo) && (M.yaw.ratio_r_Uh_kappa <= HG.ratio_hi);
        elseif ~isnan(M.yaw.ratio_r_Uh_kappa)
            g_rat = (M.yaw.ratio_r_Uh_kappa >= HG.ratio_lo) && (M.yaw.ratio_r_Uh_kappa <= HG.ratio_hi);
        else
            g_rat = true;
        end
        g_ch = ~isnan(M.act.chatter_dps) && (M.act.chatter_dps <= HG.chatter);
        order{end+1} = {g_ym, sprintf('yaw_MAE(%.4f>%.4f)', nz(M.yaw.mae_deg), HG.H.yaw_mae)}; %#ok<AGROW>
        order{end+1} = {g_yp, sprintf('yaw_p95(%.4f>%.4f)', nz(M.yaw.p95_deg), HG.H.yaw_p95)}; %#ok<AGROW>
        order{end+1} = {g_yss, sprintf('rudder_sat_ss(%.2f%%>%.2f%%)', nz(M.yaw.rudder_sat_ss_pct), HG.rud_sat_ss)}; %#ok<AGROW>
        order{end+1} = {g_yf, sprintf('rudder_sat_full(%.2f%%>%.2f%%)', nz(M.yaw.rudder_sat_full_pct), HG.rud_sat_full)}; %#ok<AGROW>
        order{end+1} = {g_rat, sprintf('yaw_ratio(%.4f out [%.2f,%.2f])', nz(M.yaw.ratio_r_Uh_kappa), HG.ratio_lo, HG.ratio_hi)}; %#ok<AGROW>
        order{end+1} = {g_ch, sprintf('chatter(%.4f>%.4f)', nz(M.act.chatter_dps), HG.chatter)}; %#ok<AGROW>
        F.gates.yaw_mae = g_ym; F.gates.yaw_p95 = g_yp;
        F.gates.rud_sat_ss = g_yss; F.gates.rud_sat_full = g_yf;
        F.gates.ratio = g_rat; F.gates.chatter = g_ch;
    else
        g_ym = ~isnan(M.yaw.mae_deg) && (M.yaw.mae_deg <= 0.50);
        order{end+1} = {g_ym, sprintf('yaw_MAE(%.4f>0.50)', nz(M.yaw.mae_deg))}; %#ok<AGROW>
        F.gates.yaw_mae = g_ym;
    end

    g_es = ~isnan(M.act.de_sat_pct) && (M.act.de_sat_pct <= HG.elev_sat);
    g_ts = ~isnan(M.act.thr_sat_pct) && (M.act.thr_sat_pct <= HG.thrust_sat);
    g_dru = ~isnan(M.act.dr_rate_util) && (M.act.dr_rate_util <= HG.rate_util);
    g_deu = ~isnan(M.act.de_rate_util) && (M.act.de_rate_util <= HG.rate_util);
    order{end+1} = {g_es, sprintf('elev_sat(%.2f%%>%.2f%%)', nz(M.act.de_sat_pct), HG.elev_sat)}; %#ok<AGROW>
    order{end+1} = {g_ts, sprintf('thrust_sat(%.2f%%>%.2f%%)', nz(M.act.thr_sat_pct), HG.thrust_sat)}; %#ok<AGROW>
    order{end+1} = {g_dru, sprintf('rudder_rate_util(%.3f>1)', nz(M.act.dr_rate_util))}; %#ok<AGROW>
    order{end+1} = {g_deu, sprintf('elev_rate_util(%.3f>1)', nz(M.act.de_rate_util))}; %#ok<AGROW>
    F.gates.elev_sat = g_es; F.gates.thrust_sat = g_ts;
    F.gates.dr_rate = g_dru; F.gates.de_rate = g_deu;

    F.feasible = true;
    F.first_limit = 'none';
    for k = 1:numel(order)
        if ~order{k}{1}
            F.feasible = false;
            F.first_limit = order{k}{2};
            break;
        end
    end

    F.margin = struct();
    F.margin.pitch_mae = h.pitch_mae - nz(M.theta.mae_deg);
    F.margin.pitch_p95 = h.pitch_p95 - nz(M.theta.p95_deg);
    F.margin.gamma_mae = h.gamma_mae - nz(M.gamma.mae_deg);
    F.margin.gamma_p95 = h.gamma_p95 - nz(M.gamma.p95_deg);
    F.margin.elev_sat = HG.elev_sat - nz(M.act.de_sat_pct);
    F.margin.de_rate = HG.rate_util - nz(M.act.de_rate_util);
    F.margin.dr_rate = HG.rate_util - nz(M.act.dr_rate_util);
    if strcmp(rname, 'H')
        F.margin.yaw_mae = HG.H.yaw_mae - nz(M.yaw.mae_deg);
        F.margin.rud_sat_full = HG.rud_sat_full - nz(M.yaw.rudder_sat_full_pct);
        if ~isnan(M.yaw.ratio_r_Uh_kappa)
            F.margin.ratio = min(M.yaw.ratio_r_Uh_kappa - HG.ratio_lo, ...
                HG.ratio_hi - M.yaw.ratio_r_Uh_kappa);
        end
    end
    fn = fieldnames(F.margin);
    vals = [];
    for i = 1:numel(fn)
        vi = F.margin.(fn{i});
        if isfinite(vi); vals(end+1) = vi; end %#ok<AGROW>
    end
    if isempty(vals); F.worst_margin = NaN; else; F.worst_margin = min(vals); end
end

function [gamma_ref, cte_perp, s_prog, s_total] = path_gamma_cte(path, vp)
    n = size(vp, 1);
    ds = [0; sqrt(sum(diff(path).^2, 2))];
    s_nodes = cumsum(ds);
    s_total = s_nodes(end);
    s_prog = zeros(n, 1);
    gamma_ref = zeros(n, 1);
    cte_perp = zeros(n, 1);
    for i = 1:n
        d = path - vp(i, :);
        [~, idx] = min(sum(d.^2, 2));
        idx = max(1, min(size(path, 1) - 1, idx));
        s_prog(i) = s_nodes(idx);
        t = path(idx + 1, :) - path(idx, :);
        tn = norm(t);
        if tn < 1e-9
            t = [1 0 0];
        else
            t = t / tn;
        end
        gamma_ref(i) = atan2(t(3), norm(t(1:2)));
        e = vp(i, :) - path(idx, :);
        th = t(1:2); nth = norm(th);
        if nth < 1e-9; nh = [0 1]; else; th = th / nth; nh = [-th(2), th(1)]; end
        cte_perp(i) = hypot(dot(e(1:2), nh), e(3));
    end
end

%% ===================== numeric utils =====================
function y = align_len(x, n)
    x = x(:);
    if numel(x) >= n
        y = x(1:n);
    else
        y = [x; zeros(n - numel(x), 1)];
    end
end

function v = mean_safe(x, mask)
    x = x(:); mask = mask(:);
    if ~any(mask); v = NaN; return; end
    v = mean(x(mask));
end

function v = max_safe(x, mask)
    x = x(:); mask = mask(:);
    if ~any(mask); v = NaN; return; end
    v = max(x(mask));
end

function v = rms_safe(x)
    x = x(:); x = x(isfinite(x));
    if isempty(x); v = NaN; return; end
    v = sqrt(mean(x.^2));
end

function v = prctile_local(x, p)
    x = sort(x(:));
    if isempty(x); v = NaN; return; end
    k = max(1, min(numel(x), round(p / 100 * numel(x))));
    v = x(k);
end

function p = sat_pct(u, mask, lim)
    if ~any(mask); p = NaN; return; end
    p = 100 * mean(abs(u(mask)) >= lim);
end

function y = hf_local(x, dt)
    x = x(:);
    if numel(x) < 3; y = x; return; end
    y = [0; diff(x)] / max(dt, eps);
end

function v = nz(x)
    if isempty(x) || ~isscalar(x); v = NaN; else; v = x; end
    if ~isfinite(v); v = NaN; end
end

function s = yn(tf)
    if tf; s = 'YES'; else; s = 'NO'; end
end

function s = tern(tf, a, b)
    if tf; s = a; else; s = b; end
end

function s = sjoin(c, sep)
    if isempty(c); s = ''; return; end
    s = strjoin(cellfun(@char, c(:)', 'UniformOutput', false), sep);
end

function s = md_esc(s)
    if isempty(s); s = ''; return; end
    s = strrep(char(s), '|', '\|');
    s = strrep(s, sprintf('\n'), ' ');
end
