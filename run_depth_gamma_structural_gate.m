function run_depth_gamma_structural_gate()
% DEPTH_GAMMA_STRUCTURAL_GATE_001 — Gate-2 isolated structural vertical gate.
% Sources (exactly 3): suite_results/DEPTH_GAMMA_SPEED_SCHEDULED_ID.md,
%   controller_law.m, continuous_path_tracking.m.
% Design (DERIVED from Gate-1 U={1,1.5,2} level/climb maps):
%   (1) scheduled theta/alpha decoupling
%   (2) z/gamma/theta feasibility governor (elevator ±15deg, ±40deg/s, climb-FF)
%   (3) anti-windup from mag/rate residual
%   (4) bumpless state init/transfer
% Never retry: gamma INDI/PI/LADRC, depth PI/NDO, polyline shaper, gain hunting.
% Production controller/guidance/plant FROZEN. CODEX_VERTICAL_PLAN untouched.
% One MATLAB call. Artifacts: suite_results/DEPTH_GAMMA_STRUCTURAL_GATE.{md,mat,png}
% Artifact budget <250 MiB.

    project_dir = fileparts(mfilename('fullpath'));
    addpath(project_dir);
    out_dir = fullfile(project_dir, 'suite_results');
    if ~exist(out_dir, 'dir'); mkdir(out_dir); end
    tag = 'DEPTH_GAMMA_STRUCTURAL_GATE';
    task_id = 'DEPTH_GAMMA_STRUCTURAL_GATE_001';
    stamp = datestr(now, 31);

    % ---- Provenance / freeze checks ----
    src_md   = fullfile(out_dir, 'DEPTH_GAMMA_SPEED_SCHEDULED_ID.md');
    src_ctrl = fullfile(project_dir, 'controller_law.m');
    src_cpt  = fullfile(project_dir, 'continuous_path_tracking.m');
    cand_g   = fullfile(project_dir, 'guidance_law_depth_gamma_structural.m');
    prod_g   = fullfile(project_dir, 'guidance_law.m');
    plan     = fullfile(out_dir, 'AUV_REALIZATION_READINESS_PLAN.md');
    realism  = fullfile(out_dir, 'AUV_REALISM_AND_VISUAL_VALIDATION.md');
    research = fullfile(out_dir, 'PITCH_CONTROL_RESEARCH_LOG.md');
    assert(exist(src_md, 'file') == 2, 'Missing Gate-1 MD');
    assert(exist(src_ctrl, 'file') == 2, 'Missing controller_law.m');
    assert(exist(src_cpt, 'file') == 2, 'Missing continuous_path_tracking.m');
    assert(exist(cand_g, 'file') == 2, 'Missing structural guidance helper');
    assert(exist(prod_g, 'file') == 2, 'Missing production guidance');
    ctrl_txt = fileread(src_ctrl);
    prod_txt = fileread(prod_g);
    cand_txt = fileread(cand_g);
    assert(contains(ctrl_txt, 'k_gamma_climb = 0.1320695001'), 'climb FF missing');
    assert(contains(ctrl_txt, 'de_climb_lim = deg2rad(2.8793)'), 'climb-FF bound missing');
    assert(contains(ctrl_txt, 'max_de = deg2rad(40)'), 'elevator rate 40deg/s missing');
    assert(contains(prod_txt, 'pitch_corr = -0.050 * z_e_f - 0.006 * z_e_i'), ...
        'production depth P+I changed — abort');
    assert(contains(cand_txt, 'alpha_sched_level'), 'candidate missing scheduled alpha');
    assert(contains(cand_txt, 'feasibility_limits'), 'candidate missing governor');
    assert(~contains(prod_txt, 'alpha_sched_level'), 'production must not host structural maps');
    assert(~contains(lower(cand_txt), 'indi_scaffold') && ~contains(lower(cand_txt), 'ladrc_est'), ...
        'rejected gamma method detected');
    assert(contains(cand_txt, 'Never: gamma INDI/PI/LADRC') || contains(cand_txt, 'no gamma INDI'), ...
        'candidate must explicitly reject INDI/LADRC');

    % ============================================================
    % PRIMARY KPI (declared a priori, before any closed-loop run)
    % ============================================================
    PrimaryKPI = struct();
    PrimaryKPI.name = 'grid_mean_depth_MAE_m';
    PrimaryKPI.definition = [ ...
        'Mean over full grid {U=1,1.5,2}×{STEP_P2,STEP_M2,DEPTH_RAMP,X,XZ} of ', ...
        'steady-window depth MAE |z_veh-z_path| [m] (NED z-down). Lower is better.'];
    PrimaryKPI.improve_need_pct = 5.0;   % promotion: candidate ≥5% better
    PrimaryKPI.secondary_max_worse_pct = 2.0;
    PrimaryKPI.declared_before_run = true;
    fprintf('\n========== %s ==========\n', task_id);
    fprintf('PRIMARY KPI (a priori): %s\n', PrimaryKPI.name);
    fprintf('  %s\n', PrimaryKPI.definition);
    fprintf('  Promotion: >=%.1f%% better; secondary non-safety <=%.1f%% worse if abs gates PASS\n', ...
        PrimaryKPI.improve_need_pct, PrimaryKPI.secondary_max_worse_pct);
    fprintf('  Zero tolerance: instability / hard elev mag-rate-sat / depth failure\n');

    clear functions
    clear guidance_law guidance_law_depth_gamma_structural controller_law
    clear global lambda_muw_ff trim_speed_table trim_elevator_table elevator_sign
    clear global K_zdot K_gamma enable_alpha_hat Kp_roll
    clear global struct_de_mag_res struct_de_rate_res

    init_parameters();
    global lambda_muw_ff elevator_sign trim_speed_table trim_elevator_table
    global K_zdot K_gamma enable_alpha_hat
    global dt_controller dt_guidance delta_e_max delta_r_max
    global Kp_x thrust_trim thrust_max thrust_min desired_speed Kp_roll
    global pitch_ref_max pitch_ref_rate_max

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
        'thrust_max', thrust_max, 'thrust_min', thrust_min, ...
        'climb_ff_lim', deg2rad(2.8793), 'climb_ff_k', 0.1320695001);

    % Absolute hard gates (zero tolerance)
    Hard = struct('theta_max_deg', 80, 'rate_max_dps', 200, 'u_max', 5.0, ...
        'depth_abs_fail_m', 5.0, 'de_sat_hard_pct', 25.0, 'de_rate_util_hard', 1.05);

    Win = struct('settle_t0', 5.0, 'end_frac', 0.88, 'depth_band', 0.25, ...
        'step_post_hold', 3.0, 'hold_s', 1.0);
    z0 = 10.0;
    L_smooth = 15.0;
    U_list = [1.0, 1.5, 2.0];
    Scenarios = {'STEP_P2', 'STEP_M2', 'DEPTH_RAMP', 'X', 'XZ'};
    Tfin_base = [28, 28, 24, 18, 22];
    lambda0 = [0.25, 0.25, 0.25, 0.25, 0.0];
    win_mode = {'persistent', 'persistent', 'persistent', 'first_hold', 'persistent'};

    Design = build_design_note(lim);
    fprintf('Structural design: scheduled alpha + governor + residual AW + bumpless\n');
    fprintf('Production cascade+climbFF frozen | helper=%s\n', cand_g);

    nU = numel(U_list); nS = numel(Scenarios);
    CellB = repmat(empty_cell(), nU, nS);
    CellC = repmat(empty_cell(), nU, nS);
    TrimBank = repmat(struct('U', [], 'L', struct(), 'C', struct()), nU, 1);
    audit_complete = true;
    n_run = 0; n_tot = nU * nS * 2;

    for iu = 1:nU
        Uref = U_list(iu);
        desired_speed = Uref;
        seed_level = level_seed(Uref);
        seed_climb = climb_seed(Uref);
        x_scale = [10; 10; 10; 1; 1; 1; Uref; 0.3; 0.3; 0.2; 0.2; 0.2];
        nu_dot_scale = [1.0; 0.3; 0.3; 0.2; 0.2; 0.2];
        TrimL = solve_translating(Uref, 0.0, seed_level, nu_dot_scale, x_scale, 0.01, 'level');
        TrimC = solve_translating(Uref, 0.4, seed_climb, nu_dot_scale, x_scale, 0.01, 'climb');
        TrimBank(iu).U = Uref; TrimBank(iu).L = TrimL; TrimBank(iu).C = TrimC;
        Paths = build_paths(z0, L_smooth, Uref);
        fprintf('\n---- U=%.1f | trimL pass=%d n=%.2g | trimC pass=%d n=%.2g ----\n', ...
            Uref, TrimL.pass, TrimL.norm_dyn, TrimC.pass, TrimC.norm_dyn);

        for is = 1:nS
            name = Scenarios{is};
            meta = Paths.meta.(name);
            path = Paths.(name);
            Tfin = Tfin_base(is);
            if contains(name, 'XZ')
                Trim = TrimC;
            else
                Trim = TrimL;
            end
            lambda_muw_ff = lambda0(is);

            % --- Baseline (production continuous_path_tracking) ---
            n_run = n_run + 1;
            fprintf('  [%2d/%2d] BASE %s U=%.1f ...\n', n_run, n_tot, name, Uref);
            rng(seed_used, 'twister');
            try
                [Sb, Mb] = sim_baseline(path, Tfin, Uref, Trim, lim, Win, ...
                    win_mode{is}, name, meta);
                Mb.branch = 'baseline';
            catch ME
                Sb = struct('t', []); Mb = fail_metrics(name, Trim, ME.message);
                Mb.branch = 'baseline'; audit_complete = false;
                fprintf('    BASE ERROR: %s\n', ME.message);
            end
            Mb = score_hard(Mb, Hard, lim);
            CellB(iu, is) = pack_cell(name, Uref, Mb, Sb);

            % --- Candidate (structural guidance isolated loop) ---
            n_run = n_run + 1;
            fprintf('  [%2d/%2d] CAND %s U=%.1f ...\n', n_run, n_tot, name, Uref);
            rng(seed_used, 'twister');
            try
                [Sc, Mc] = sim_candidate(path, Tfin, Uref, Trim, lim, Win, ...
                    win_mode{is}, name, meta);
                Mc.branch = 'candidate';
            catch ME
                Sc = struct('t', []); Mc = fail_metrics(name, Trim, ME.message);
                Mc.branch = 'candidate'; audit_complete = false;
                fprintf('    CAND ERROR: %s\n', ME.message);
            end
            Mc = score_hard(Mc, Hard, lim);
            CellC(iu, is) = pack_cell(name, Uref, Mc, Sc);

            fprintf('    zMAE %.4f→%.4f | th %.3f→%.3f | g %.3f→%.3f | a %.3f→%.3f | deSat %.2f→%.2f | hard %s→%s\n', ...
                nz(Mb.depth.mae), nz(Mc.depth.mae), ...
                nz(Mb.theta.mae_deg), nz(Mc.theta.mae_deg), ...
                nz(Mb.gamma.mae_deg), nz(Mc.gamma.mae_deg), ...
                nz(Mb.alpha.mae_deg), nz(Mc.alpha.mae_deg), ...
                nz(Mb.act.de_sat_pct), nz(Mc.act.de_sat_pct), ...
                yn(~Mb.hard_fail), yn(~Mc.hard_fail));
        end
    end

    Comp = compare_grid(CellB, CellC, PrimaryKPI, Hard);
    if ~audit_complete
        verdict = 'FAIL';
        Comp.blocker = 'sim_exception';
    elseif Comp.pass
        verdict = 'PASS';
    elseif Comp.partial
        verdict = 'PARTIAL';
    else
        verdict = 'FAIL';
    end

    if strcmp(verdict, 'PASS')
        next_task = 'closed_loop_actuator_realism_gate';
        next_note = 'Gate-2 structural PASS → Gate 3 closed-loop actuator realism.';
        blocker = 'none';
    else
        next_task = 'depth_gamma_structural_gate_blocker_fix';
        next_note = sprintf('Gate-2 %s; preserve baseline; blocker=%s', verdict, Comp.blocker);
        blocker = Comp.blocker;
    end

    md_path  = fullfile(out_dir, [tag '.md']);
    mat_path = fullfile(out_dir, [tag '.mat']);
    png_path = fullfile(out_dir, [tag '.png']);

    write_png(png_path, CellB, CellC, U_list, Scenarios, task_id, verdict, Comp);
    write_md(md_path, task_id, stamp, verdict, PrimaryKPI, Design, Comp, ...
        CellB, CellC, U_list, Scenarios, TrimBank, lim, Hard, Win, ...
        src_md, src_ctrl, src_cpt, cand_g, next_task, next_note, blocker, ...
        md_path, mat_path, png_path, seed_used, z0, L_smooth);
    append_logs(plan, realism, research, task_id, stamp, verdict, Comp, ...
        next_task, blocker, md_path, mat_path, png_path);

    Out = struct();
    Out.task_id = task_id;
    Out.stamp = stamp;
    Out.verdict = verdict;
    Out.PrimaryKPI = PrimaryKPI;
    Out.Design = Design;
    Out.Comp = Comp;
    Out.CellB = CellB;
    Out.CellC = CellC;
    Out.TrimBank = TrimBank;
    Out.U_list = U_list;
    Out.Scenarios = Scenarios;
    Out.limits = lim;
    Out.Hard = Hard;
    Out.Win = Win;
    Out.next_task = next_task;
    Out.blocker = blocker;
    Out.production_edited = false;
    Out.artifact_budget_MiB = 250;
    Out.paths = struct('md', md_path, 'mat', mat_path, 'png', png_path);
    % Compact save (no raw high-rate duplicates beyond Cell*.S stubs)
    save(mat_path, '-struct', 'Out');
    bytes = dir(mat_path).bytes + dir(md_path).bytes + dir(png_path).bytes;
    fprintf('\nVERDICT: %s | primary_improve=%.2f%% | blocker=%s\n', ...
        verdict, Comp.primary_improve_pct, blocker);
    fprintf('Next: %s\n', next_task);
    fprintf('Artifacts (%.2f MiB): %s\n%s\n%s\n', bytes/1024/1024, md_path, mat_path, png_path);
    assert(bytes < 250*1024*1024, 'Artifact budget exceeded');
    assignin('base', 'DEPTH_GAMMA_STRUCTURAL_GATE_PASS', strcmp(verdict, 'PASS'));
end

%% ===================== design note =====================
function D = build_design_note(lim)
    D = struct();
    D.label = 'DERIVED from DEPTH_GAMMA_SPEED_SCHEDULED_ID level/climb U={1,1.5,2}';
    D.decoupling = [ ...
        'theta_cmd = gamma_cmd - alpha_sched(U,mode); alpha_sched = blend(alpha_level*, alpha_climb*) ', ...
        'IDENTIFIED; gamma = theta_phys + alpha (IMPLEMENTED convention)'];
    D.alpha_level = [-0.0742888, -0.0333395, -0.0188097];
    D.alpha_climb = [-0.10838, -0.0513342, -0.0296065];
    D.U_grid = [1.0, 1.5, 2.0];
    D.gamma_climb = 0.380506;
    D.governor = sprintf([ ...
        'Feasibility set from elevator |de|<=%.1fdeg, |de_dot|<=40deg/s, ', ...
        'climb-FF |de_ff|<=%.4fdeg (k=%.10f); Gfh theta/gamma←de DERIVED; ', ...
        'clips gamma/theta + rate'], rad2deg(lim.de_max), rad2deg(lim.climb_ff_lim), lim.climb_ff_k);
    D.anti_windup = [ ...
        'AW on depth-I bleed driven by struct_de_mag_res+struct_de_rate_res from ', ...
        'controller_law dbg (mag sat) and rate-limit residual; Kaw_struct=8 (TUNED isolated)'];
    D.bumpless = [ ...
        'Cold-start pitch_out=theta_cmd=gamma_path-alpha_sched; I=0; alpha_sched_f seeded; ', ...
        'production prev_delta_e:=de_trim (IMPLEMENTED)'];
    D.rejected = 'no gamma INDI/PI/LADRC; no depth PI/NDO replace; no polyline shaper; no gain hunting';
    D.production_gains_frozen = 'pitch_corr=-0.050*z_e_f-0.006*z_e_i; K_gamma=0; K_zdot=0';
end

%% ===================== paths =====================
function P = build_paths(z0, Lsm, Uref) %#ok<INUSD>
    P = struct(); P.meta = struct();
    [P.STEP_P2, meta_p] = depth_step_path(z0, +2.0, Lsm);
    P.meta.STEP_P2 = meta_p; P.meta.STEP_P2.class = 'step';
    [P.STEP_M2, meta_m] = depth_step_path(z0, -2.0, Lsm);
    P.meta.STEP_M2 = meta_m; P.meta.STEP_M2.class = 'step';

    % Depth ramp (gentle; distinct from XZ slope-0.4) — NOT a polyline shaper retry
    nR = 800; xR = linspace(0, 40, nR)';
    slope_r = 0.12;
    P.DEPTH_RAMP = [xR, zeros(nR, 1), z0 + slope_r * xR];
    P.meta.DEPTH_RAMP = struct('z_cmd', NaN, 'dz', NaN, 'x_trans0', 0, 'x_trans1', 40, ...
        'class', 'ramp', 'slope', slope_r, 'desc', sprintf('depth ramp slope=%.2f', slope_r));

    nX = 600; xX = linspace(0, 45, nX)';
    P.X = [xX, zeros(nX, 1), z0 * ones(nX, 1)];
    P.meta.X = struct('z_cmd', z0, 'dz', 0, 'x_trans0', NaN, 'x_trans1', NaN, ...
        'class', 'hold', 'desc', sprintf('X level z=%.1f', z0));

    nXZ = 900; xXZ = linspace(0, 42, nXZ)';
    P.XZ = [xXZ, zeros(nXZ, 1), z0 + 0.4 * xXZ];
    P.meta.XZ = struct('z_cmd', NaN, 'dz', NaN, 'x_trans0', 0, 'x_trans1', 42, ...
        'class', 'ramp', 'slope', 0.4, 'desc', 'XZ climb slope=0.4');
end

function [path, meta] = depth_step_path(z0, dz, Lsm)
    x_hold0 = 8.0; x_hold1 = 25.0;
    x_end = x_hold0 + Lsm + x_hold1;
    n = 900; x = linspace(0, x_end, n)'; z = zeros(n, 1);
    x0 = x_hold0; x1 = x_hold0 + Lsm;
    for i = 1:n
        if x(i) <= x0
            z(i) = z0;
        elseif x(i) >= x1
            z(i) = z0 + dz;
        else
            s = (x(i) - x0) / Lsm;
            z(i) = z0 + dz * 0.5 * (1 - cos(pi * s));
        end
    end
    path = [x, zeros(n, 1), z];
    meta = struct('z_cmd', z0 + dz, 'dz', dz, 'x_trans0', x0, 'x_trans1', x1, ...
        'L_smooth', Lsm, 'slope_max', abs(dz) * pi / (2 * Lsm));
end

%% ===================== seeds / trim =====================
function s = level_seed(U)
    switch sprintf('%.1f', U)
        case '1.0'
            s = struct('theta', -0.0742888, 'v', 0, 'w', -0.0744258, 'q', 0, ...
                'de', -0.221162, 'T', 1.9911, 'u', 1.0);
        case '1.5'
            s = struct('theta', -0.0333395, 'v', 0, 'w', -0.0500278, 'q', 0, ...
                'de', -0.116328, 'T', 3.81167, 'u', 1.5);
        otherwise
            s = struct('theta', -0.0188097, 'v', 0, 'w', -0.0376238, 'q', 0, ...
                'de', -0.0690247, 'T', 6.57404, 'u', 2.0);
    end
end

function s = climb_seed(U)
    switch sprintf('%.1f', U)
        case '1.0'
            s = struct('theta', -0.488887, 'v', 0, 'w', -0.108807, 'q', 0, ...
                'de', 0.0257758, 'T', 3.96822, 'u', 1.0);
        case '1.5'
            s = struct('theta', -0.431841, 'v', 0, 'w', -0.0770689, 'q', 0, ...
                'de', -0.0210529, 'T', 5.73772, 'u', 1.5);
        otherwise
            s = struct('theta', -0.410113, 'v', 0, 'w', -0.0592303, 'q', 0, ...
                'de', -0.0191344, 'T', 8.47356, 'u', 2.0);
    end
end

function P = solve_translating(Ufix, slope, seed, nu_dot_scale, x_scale, pass_tol, name) %#ok<INUSD>
    scale = (Ufix / max(seed.u, 0.5))^2;
    z0 = [seed.theta; seed.v; seed.w; seed.q; seed.de; seed.T * scale];
    [z, exitflag] = local_newton(@(zz) translating_cost(zz, Ufix, slope, nu_dot_scale), z0, 80);
    x = zeros(12, 1);
    x(5) = z(1); x(7) = Ufix; x(8) = z(2); x(9) = z(3); x(11) = z(4);
    u = [0; z(5); z(6)];
    f = underwater777_vehicle_dynamics(0, x, ustruct(u));
    nd = f(7:12) ./ nu_dot_scale;
    P = struct('name', name, 'pass', norm(nd) <= pass_tol, 'norm_dyn', norm(nd), ...
        'exitflag', exitflag, 'x_star', x, 'u_star', u, 'Treq', z(6), ...
        'theta', z(1), 'w', z(3), 'de', z(5));
end

function c = translating_cost(z, Ufix, slope, nu_dot_scale)
    x = zeros(12, 1);
    x(5) = z(1); x(7) = Ufix; x(8) = z(2); x(9) = z(3); x(11) = z(4);
    u = [0; z(5); z(6)];
    f = underwater777_vehicle_dynamics(0, x, ustruct(u));
    % Translating: nu_dot~0; match inertial slope via w/u kinematics approx
    th = z(1);
    % Fossen: zdot ≈ -u*sin(th)+w*cos(th) (phi=0); want zdot/U_h ≈ slope
    Uh = max(Ufix * cos(th), 0.2);
    zdot = -Ufix * sin(th) + z(3) * cos(th);
    slope_err = zdot / Uh - slope;
    c = [f(7:12) ./ nu_dot_scale; 10 * slope_err];
end

function [z, exitflag] = local_newton(fun, z0, maxit)
    z = z0; exitflag = 0;
    for k = 1:maxit
        c = fun(z);
        if norm(c) < 1e-10; exitflag = 1; return; end
        n = numel(z); J = zeros(numel(c), n);
        for j = 1:n
            h = 1e-6 * max(1, abs(z(j)));
            zp = z; zp(j) = zp(j) + h;
            J(:, j) = (fun(zp) - c) / h;
        end
        if rcond(J' * J) < 1e-14; exitflag = -1; return; end
        dz = -(J' * J) \ (J' * c);
        if any(~isfinite(dz)); exitflag = -2; return; end
        z = z + dz;
        if norm(dz) < 1e-10; exitflag = 1; return; end
    end
end

function ctr = ustruct(u)
    ctr = struct('delta_r', u(1), 'delta_e', u(2), 'thrust', u(3));
end

%% ===================== simulate =====================
function [S, M] = sim_baseline(path, T_final, Uref, Trim, lim, Win, win_mode, name, meta)
    global desired_speed
    desired_speed = Uref;
    state0 = build_state0(path, Uref, Trim, name);
    S = simulate_baseline_logged(path, T_final, state0);
    S.name = name; S.Uref = Uref; S.meta = meta; S.branch = 'baseline';
    [M, S] = analyze_scenario(S, path, Win, win_mode, lim, meta);
    M.struct_events = struct('gov', 0, 'aw', 0, 'bumpless', 0);
end

function [S, M] = sim_candidate(path, T_final, Uref, Trim, lim, Win, win_mode, name, meta)
    global desired_speed
    desired_speed = Uref;
    state0 = build_state0(path, Uref, Trim, name);
    S = simulate_candidate_logged(path, T_final, state0);
    S.name = name; S.Uref = Uref; S.meta = meta; S.branch = 'candidate';
    [M, S] = analyze_scenario(S, path, Win, win_mode, lim, meta);
end

function state0 = build_state0(path, Uref, Trim, name)
    state0 = zeros(12, 1);
    state0(1:3) = path(1, :);
    d = path(2, :) - path(1, :);
    state0(6) = atan2(d(2), d(1));
    state0(7) = Uref;
    if strcmp(name, 'XZ')
        state0(5) = -atan2(d(3), max(norm(d(1:2)), 1e-9));
        if isfield(Trim, 'x_star') && numel(Trim.x_star) >= 9
            state0(8) = Trim.x_star(8);
            state0(9) = Trim.x_star(9);
        end
    else
        state0(5) = Trim.x_star(5);
        state0(8) = Trim.x_star(8);
        state0(9) = Trim.x_star(9);
        state0(11) = Trim.x_star(11);
    end
end

function S = simulate_baseline_logged(path, T_final, state0)
    global dt_controller suite_delta_e_log suite_delta_r_log suite_u_log
    global suite_e_z_log suite_gamma_actual_log suite_gamma_path_log
    global suite_zdot_inertial_log suite_theta_phys_log suite_e_theta_log
    global suite_alpha_eff_log
    global Kp_x thrust_trim thrust_max thrust_min
    clear guidance_law controller_law
    reset_ctrl_globals();
    dt = dt_controller;
    [vp, times, vel, rates, ori, ~, yaw_refs, pitch_refs, u_refs] = ...
        continuous_path_tracking(path, state0, dt, T_final);
    n = numel(times);
    S = pack_S(times, vp, vel, rates, ori, yaw_refs, pitch_refs, u_refs, ...
        align_len(suite_u_log(:), n), align_len(suite_delta_e_log(:), n), ...
        align_len(suite_delta_r_log(:), n), ...
        reconstruct_thrust(u_refs(:), align_len(suite_u_log(:), n), ...
        thrust_trim, Kp_x, thrust_min, thrust_max), ...
        align_len(suite_e_z_log(:), n), align_len(suite_gamma_actual_log(:), n), ...
        align_len(suite_gamma_path_log(:), n), align_len(suite_zdot_inertial_log(:), n), ...
        align_len(suite_theta_phys_log(:), n), align_len(suite_e_theta_log(:), n), ...
        align_len(suite_alpha_eff_log(:), n), dt, T_final);
    S.gov = zeros(n, 1); S.aw = zeros(n, 1); S.bumpless = zeros(n, 1);
end

function S = simulate_candidate_logged(path, T_final, state0)
    global dt_controller dt_guidance
    global Kp_x thrust_trim thrust_max thrust_min
    global struct_de_mag_res struct_de_rate_res
    global last_delta_e last_e_theta last_theta_phys
    global last_gamma_actual last_gamma_path last_e_gamma last_e_z last_zdot_inertial
    global last_alpha_eff last_alpha_hat
    global last_struct_gov_clip last_struct_aw_event last_struct_bumpless
    clear guidance_law guidance_law_depth_gamma_structural controller_law
    reset_ctrl_globals();
    struct_de_mag_res = 0; struct_de_rate_res = 0;

    dt = dt_controller;
    if isempty(dt_guidance); dt_guidance = dt; end
    n_steps = round(T_final / dt);
    state = state0(:);
    vp = zeros(n_steps, 3); times = zeros(n_steps, 1);
    vel = zeros(n_steps, 3); rates = zeros(n_steps, 3); ori = zeros(n_steps, 3);
    yaw_refs = zeros(n_steps, 1); pitch_refs = zeros(n_steps, 1); u_refs = zeros(n_steps, 1);
    u_ctrl = zeros(n_steps, 1); de = zeros(n_steps, 1); dr = zeros(n_steps, 1);
    thrust = zeros(n_steps, 1);
    e_z_g = zeros(n_steps, 1); gact = zeros(n_steps, 1); gpath = zeros(n_steps, 1);
    zdot_l = zeros(n_steps, 1); thp = zeros(n_steps, 1); eth = zeros(n_steps, 1);
    aeff = zeros(n_steps, 1);
    gov = zeros(n_steps, 1); aw = zeros(n_steps, 1); bump = zeros(n_steps, 1);

    yaw_ref = 0; pitch_ref = 0; u_ref = 0; r_ff = 0; pitch_ref_dot = 0;
    progress_index = 1;
    guidance_period = max(1, round(dt_guidance / dt));
    total_time = 0;
    de_cmd_prev = 0;

    for idx = 1:n_steps
        current_position = state(1:3)';
        current_orientation = state(4:6)';
        current_rates = state(10:12)';
        current_u = state(7); current_v = state(8); current_w = state(9);
        [U_h, zdot_inertial] = inertial_velocity_ned_local(current_orientation, ...
            current_u, current_v, current_w);
        theta_phys_now = -current_orientation(2);

        if mod(idx - 1, guidance_period) == 0
            [yaw_ref, pitch_ref, u_ref, progress_index, r_ff, pitch_ref_dot] = ...
                guidance_law_depth_gamma_structural(current_position, path, progress_index, ...
                current_u, current_v, U_h, zdot_inertial, theta_phys_now);
        end

        [delta_r, delta_e, thr, dbg] = controller_law(yaw_ref, pitch_ref, u_ref, ...
            current_orientation(3), current_orientation(2), current_rates(3), ...
            current_rates(2), current_u, r_ff, pitch_ref_dot, current_orientation(1), ...
            current_w, current_rates(1));

        % Mag/rate residual for structural AW (next guidance tick)
        struct_de_mag_res = dbg.delta_e_cmd - dbg.delta_e_unsat;
        struct_de_rate_res = delta_e - dbg.delta_e_cmd;
        de_cmd_prev = dbg.delta_e_cmd; %#ok<NASGU>

        controls = struct('delta_r', delta_r, 'delta_e', delta_e, 'thrust', thr);
        [~, g] = ode45(@(t, gg) underwater777_vehicle_dynamics(t, gg, controls), [0 dt], state);
        state = g(end, :)';

        vp(idx, :) = state(1:3);
        vel(idx, :) = state(7:9);
        rates(idx, :) = state(10:12);
        ori(idx, :) = state(4:6);
        yaw_refs(idx) = yaw_ref; pitch_refs(idx) = pitch_ref; u_refs(idx) = u_ref;
        u_ctrl(idx) = current_u; de(idx) = delta_e; dr(idx) = delta_r; thrust(idx) = thr;
        if isempty(last_e_z); last_e_z = 0; end
        if isempty(last_gamma_actual); last_gamma_actual = 0; end
        if isempty(last_gamma_path); last_gamma_path = 0; end
        if isempty(last_zdot_inertial); last_zdot_inertial = zdot_inertial; end
        if isempty(last_theta_phys); last_theta_phys = theta_phys_now; end
        if isempty(last_e_theta); last_e_theta = 0; end
        if isempty(last_alpha_eff); last_alpha_eff = 0; end
        if isempty(last_struct_gov_clip); last_struct_gov_clip = 0; end
        if isempty(last_struct_aw_event); last_struct_aw_event = 0; end
        if isempty(last_struct_bumpless); last_struct_bumpless = 0; end
        e_z_g(idx) = last_e_z; gact(idx) = last_gamma_actual; gpath(idx) = last_gamma_path;
        zdot_l(idx) = last_zdot_inertial; thp(idx) = last_theta_phys; eth(idx) = last_e_theta;
        aeff(idx) = last_alpha_eff;
        gov(idx) = last_struct_gov_clip; aw(idx) = last_struct_aw_event;
        bump(idx) = last_struct_bumpless;
        total_time = total_time + dt; times(idx) = total_time;
    end

    S = pack_S(times, vp, vel, rates, ori, yaw_refs, pitch_refs, u_refs, ...
        u_ctrl, de, dr, thrust, e_z_g, gact, gpath, zdot_l, thp, eth, aeff, dt, T_final);
    S.gov = gov; S.aw = aw; S.bumpless = bump;
end

function S = pack_S(times, vp, vel, rates, ori, yaw_refs, pitch_refs, u_refs, ...
        u_ctrl, de, dr, thrust, e_z_g, gact, gpath, zdot_l, thp, eth, aeff, dt, T_final)
    S = struct();
    S.dt = dt; S.T_final = T_final; S.t = times(:); S.vp = vp; S.vel = vel;
    S.rates = rates; S.ori = ori; S.psi_ref = yaw_refs(:); S.theta_ref = pitch_refs(:);
    S.u_ref = u_refs(:); S.u_ctrl = u_ctrl(:); S.u_body = vel(:, 1);
    S.delta_e = de(:); S.delta_r = dr(:); S.thrust = thrust(:);
    S.e_z_guid = e_z_g(:); S.gamma_act_guid = gact(:); S.gamma_path_guid = gpath(:);
    S.zdot = zdot_l(:); S.theta_phys_log = thp(:); S.e_theta_log = eth(:);
    S.alpha_eff_log = aeff(:);
    [S.Uh, S.VD] = ned_speeds(ori, vel);
end

function reset_ctrl_globals()
    clear global last_guidance_U_h last_guidance_kappa last_r_ff
    clear global last_delta_e last_delta_r last_int_angle last_int_rate
    clear global last_e_z last_e_zdot last_zdot_inertial
    clear global last_gamma_actual last_gamma_path last_e_gamma last_alpha_eff last_alpha_hat
    clear global last_e_theta last_theta_phys last_de_fb last_de_trim last_de_uw_ff
    clear global last_struct_gov_clip last_struct_aw_event last_struct_bumpless
    clear global struct_de_mag_res struct_de_rate_res
    global last_guidance_U_h last_guidance_kappa last_r_ff
    global last_delta_e last_delta_r last_int_angle last_int_rate
    global last_e_z last_e_zdot last_zdot_inertial
    global last_gamma_actual last_gamma_path last_e_gamma last_alpha_eff last_alpha_hat
    global last_e_theta last_theta_phys
    global struct_de_mag_res struct_de_rate_res
    global last_struct_gov_clip last_struct_aw_event last_struct_bumpless
    last_guidance_U_h = []; last_guidance_kappa = []; last_r_ff = [];
    last_delta_e = []; last_delta_r = []; last_int_angle = []; last_int_rate = [];
    last_e_z = []; last_e_zdot = []; last_zdot_inertial = [];
    last_gamma_actual = []; last_gamma_path = []; last_e_gamma = [];
    last_alpha_eff = []; last_alpha_hat = []; last_e_theta = []; last_theta_phys = [];
    struct_de_mag_res = 0; struct_de_rate_res = 0;
    last_struct_gov_clip = 0; last_struct_aw_event = 0; last_struct_bumpless = 0;
end

function [Uh, VD] = ned_speeds(ori, vel)
    n = size(vel, 1); Uh = zeros(n, 1); VD = zeros(n, 1);
    for i = 1:n
        phi = ori(i, 1); th = ori(i, 2); psi = ori(i, 3);
        R = [cos(psi)*cos(th), cos(psi)*sin(th)*sin(phi)-sin(psi)*cos(phi), cos(psi)*sin(th)*cos(phi)+sin(psi)*sin(phi);
             sin(psi)*cos(th), sin(psi)*sin(th)*sin(phi)+cos(psi)*cos(phi), sin(psi)*sin(th)*cos(phi)-cos(psi)*sin(phi);
             -sin(th), cos(th)*sin(phi), cos(th)*cos(phi)];
        pd = R * vel(i, 1:3)';
        Uh(i) = hypot(pd(1), pd(2)); VD(i) = pd(3);
    end
end

function thrust = reconstruct_thrust(u_ref, u, trim, Kp, tmin, tmax)
    thrust = trim + Kp * (u_ref - u);
    thrust = max(min(thrust, tmax), tmin);
end

function y = align_len(x, n)
    x = x(:);
    if isempty(x); y = zeros(n, 1); return; end
    if numel(x) >= n; y = x(1:n); else; y = [x; zeros(n - numel(x), 1)]; end
end

%% ===================== analyze =====================
function [M, S] = analyze_scenario(S, path, Win, win_mode, lim, meta)
    t = S.t(:); dt = S.dt; n = numel(t); %#ok<NASGU>
    theta_phys = -S.ori(:, 2);
    phi = S.ori(:, 1); psi = S.ori(:, 3);
    p = S.rates(:, 1); de = S.delta_e(:); dr = S.delta_r(:);
    e_th = wrapToPi(S.theta_ref - theta_phys);
    e_psi = wrapToPi(S.psi_ref - psi);

    [z_path, s_prog, s_total] = path_z(path, S.vp);
    e_z = S.vp(:, 3) - z_path;
    S.e_z_path = e_z; S.z_path = z_path;
    gamma_act = atan2(S.VD, max(S.Uh, 1e-9));
    gamma_path = path_gamma(path, S.vp);
    e_gamma = wrapToPi(gamma_path - gamma_act);
    alpha_act = theta_phys - gamma_act;
    % alpha error vs scheduled: use guidance alpha_eff log if present
    if isfield(S, 'alpha_eff_log') && numel(S.alpha_eff_log) == n
        alpha_ref = S.alpha_eff_log; % actual AoA proxy
    else
        alpha_ref = alpha_act;
    end
    e_alpha = alpha_act - alpha_ref; % ~0 if same; keep for reporting rms AoA
    e_alpha = alpha_act; % report alpha magnitude as AoA channel proxy MAE about 0 trim bias stripped in stats

    mask_before_end = s_prog < Win.end_frac * s_total;
    [mask_ss, settle_s, persist_ok, overshoot] = depth_windows(t, e_z, s_prog, s_total, Win, meta, win_mode);
    if ~any(mask_ss); mask_ss = (t >= Win.settle_t0) & mask_before_end; end

    de_dot = [0; diff(de)] / dt;
    M = struct(); M.sim_ok = true; M.sim_err = '';
    M.depth = struct();
    M.depth.mae = mean_safe(abs(e_z), mask_ss);
    M.depth.p95 = prctile_safe(abs(e_z(mask_ss)), 95);
    M.depth.final_bias = mean_safe(e_z, mask_ss);
    M.depth.max_dev = max_safe(abs(e_z), mask_ss);
    M.depth.overshoot = overshoot;
    M.depth.settling_s = settle_s;
    M.depth.persistent_ok = persist_ok;
    M.theta = struct('mae_deg', rad2deg(mean_safe(abs(e_th), mask_ss)), ...
        'p95_deg', rad2deg(prctile_safe(abs(e_th(mask_ss)), 95)), ...
        'rms_deg', rad2deg(rms_safe(e_th(mask_ss))));
    M.gamma = struct('mae_deg', rad2deg(mean_safe(abs(e_gamma), mask_ss)), ...
        'p95_deg', rad2deg(prctile_safe(abs(e_gamma(mask_ss)), 95)));
    M.alpha = struct('mae_deg', rad2deg(mean_safe(abs(alpha_act), mask_ss)), ...
        'p95_deg', rad2deg(prctile_safe(abs(alpha_act(mask_ss)), 95)));
    M.yaw = struct('mae_deg', rad2deg(mean_safe(abs(e_psi), mask_ss)));
    M.roll = struct('mae_deg', rad2deg(mean_safe(abs(phi), mask_ss)));
    M.speed = struct('mae', mean_safe(abs(S.u_ref - S.u_ctrl), mask_ss), ...
        'u_mean', mean_safe(S.u_ctrl, mask_ss));
    M.act = struct();
    M.act.de_mag_util = mean_safe(abs(de), mask_ss) / lim.de_max;
    M.act.de_rate_util = rms_safe(de_dot(mask_ss)) / lim.de_rate;
    M.act.de_sat_pct = sat_pct(de, mask_ss, 0.98 * lim.de_max);
    M.act.de_rate_dwell_pct = 100 * mean(abs(de_dot(mask_ss)) >= 0.98 * lim.de_rate);
    M.act.dr_sat_pct = sat_pct(dr, mask_ss, 0.98 * lim.dr_max);
    M.act.chatter_dps = rad2deg(std(hf_local(detrend_safe(e_th(mask_ss)), dt)));
    M.bounded = all(isfinite([S.ori(:); S.vel(:); S.rates(:); S.thrust])) && ...
        all(abs(theta_phys) < deg2rad(80)) && all(abs(S.u_body) < 5.0) && ...
        all(abs(S.rates(:)) < deg2rad(200));
    M.persistent_ok = persist_ok;
    if isfield(S, 'gov')
        M.struct_events = struct( ...
            'gov', sum(S.gov > 0), 'aw', sum(S.aw > 0), 'bumpless', sum(S.bumpless > 0));
    else
        M.struct_events = struct('gov', 0, 'aw', 0, 'bumpless', 0);
    end
    M.mask_ss = mask_ss;
end

function M = score_hard(M, Hard, lim) %#ok<INUSD>
    M.hard_fail = false;
    M.hard_reason = '';
    if ~M.sim_ok
        M.hard_fail = true; M.hard_reason = 'sim_fail'; return;
    end
    if ~M.bounded
        M.hard_fail = true; M.hard_reason = 'unbounded'; return;
    end
    if isfinite(M.depth.max_dev) && M.depth.max_dev > Hard.depth_abs_fail_m
        M.hard_fail = true; M.hard_reason = sprintf('depth_abs(%.2f)', M.depth.max_dev); return;
    end
    if isfinite(M.act.de_sat_pct) && M.act.de_sat_pct > Hard.de_sat_hard_pct
        M.hard_fail = true; M.hard_reason = sprintf('de_sat(%.1f%%)', M.act.de_sat_pct); return;
    end
    if isfinite(M.act.de_rate_util) && M.act.de_rate_util > Hard.de_rate_util_hard
        M.hard_fail = true; M.hard_reason = sprintf('de_rate_util(%.2f)', M.act.de_rate_util); return;
    end
end

function [mask_ss, settle_s, persist_ok, overshoot] = depth_windows(t, e_z, s_prog, s_total, Win, meta, win_mode)
    mask_before_end = s_prog < Win.end_frac * s_total;
    band = Win.depth_band;
    overshoot = max(0, max(e_z) - abs(nz(meta_field(meta, 'dz', 0))));
    if strcmp(win_mode, 'first_hold')
        mask_ss = (t >= Win.settle_t0) & mask_before_end;
        settle_s = Win.settle_t0;
        persist_ok = all(abs(e_z(mask_ss)) <= band) || mean(abs(e_z(mask_ss))) <= band;
        return;
    end
    % Persistent settle: first time |e_z| stays in band for hold_s
    settle_s = NaN; persist_ok = false;
    dt = median(diff(t));
    n_hold = max(1, round(Win.hold_s / max(dt, eps)));
    inb = abs(e_z) <= band;
    for i = 1:(numel(t) - n_hold)
        if t(i) < Win.settle_t0; continue; end
        if all(inb(i:i+n_hold-1))
            settle_s = t(i); persist_ok = true; break;
        end
    end
    if persist_ok
        mask_ss = (t >= settle_s) & mask_before_end;
    else
        mask_ss = (t >= Win.settle_t0) & mask_before_end;
        % fallback settle estimate
        if any(inb & (t >= Win.settle_t0))
            settle_s = t(find(inb & (t >= Win.settle_t0), 1, 'first'));
        end
    end
    if isfield(meta, 'dz') && isfinite(meta.dz) && meta.dz ~= 0
        % overshoot relative to step command
        if meta.dz > 0
            overshoot = max(0, max(e_z) - 0); % positive excess dive
        else
            overshoot = max(0, max(-e_z));
        end
    end
end

function v = meta_field(meta, f, d)
    if isstruct(meta) && isfield(meta, f) && ~isempty(meta.(f)); v = meta.(f); else; v = d; end
end

function [z_path, s_prog, s_total] = path_z(path, vp)
    [s_nodes, s_total] = path_arclength(path);
    n = size(vp, 1); z_path = zeros(n, 1); s_prog = zeros(n, 1);
    s_cur = 0;
    for i = 1:n
        [s_cur, ~] = project_near(vp(i, :), path, s_nodes, s_cur, s_total);
        s_prog(i) = s_cur;
        [p, ~] = sample_path(path, s_nodes, s_cur, false);
        z_path(i) = p(3);
    end
end

function g = path_gamma(path, vp)
    [s_nodes, s_total] = path_arclength(path);
    n = size(vp, 1); g = zeros(n, 1); s_cur = 0;
    for i = 1:n
        [s_cur, ~] = project_near(vp(i, :), path, s_nodes, s_cur, s_total);
        [~, t_hat] = sample_path(path, s_nodes, s_cur, false);
        g(i) = atan2(t_hat(3), max(norm(t_hat(1:2)), 1e-9));
    end
end

function [s_nodes, s_total] = path_arclength(path)
    n = size(path, 1); s_nodes = zeros(n, 1);
    for i = 2:n; s_nodes(i) = s_nodes(i-1) + norm(path(i,:) - path(i-1,:)); end
    s_total = max(s_nodes(end), 1e-9);
end

function [s_best, d_best] = project_near(p, path, s_nodes, s_cur, s_total)
    s_lo = max(0, s_cur - 0.5); s_hi = min(s_total, s_cur + 3.0);
    d_best = inf; s_best = s_cur;
    i0 = max(1, find(s_nodes <= s_lo, 1, 'last'));
    i1 = min(size(path,1)-1, find(s_nodes >= s_hi, 1, 'first'));
    if isempty(i0); i0 = 1; end
    if isempty(i1); i1 = size(path,1)-1; end
    for i = i0:max(i0, i1)
        a = path(i,:); b = path(i+1,:); ab = b - a; lab2 = sum(ab.^2);
        if lab2 < 1e-12; continue; end
        tt = max(0, min(1, dot(p - a, ab) / lab2));
        proj = a + tt * ab; d = norm(p - proj);
        s = s_nodes(i) + tt * (s_nodes(i+1) - s_nodes(i));
        if d < d_best; d_best = d; s_best = s; end
    end
end

function [p, t_hat] = sample_path(path, s_nodes, s, is_closed) %#ok<INUSD>
    n = size(path, 1); s = max(0, min(s_nodes(end), s));
    i = max(1, min(n-1, find(s_nodes <= s, 1, 'last')));
    if isempty(i); i = 1; end
    ds = s_nodes(i+1) - s_nodes(i);
    if ds < 1e-12; tt = 0; else; tt = (s - s_nodes(i)) / ds; end
    p = path(i,:) + tt * (path(i+1,:) - path(i,:));
    tang = path(i+1,:) - path(i,:);
    if norm(tang) < 1e-9; tang = [1, 0, 0]; end
    t_hat = tang / norm(tang);
end

%% ===================== compare / pack =====================
function C = empty_cell()
    C = struct('name', '', 'U', NaN, 'M', struct(), 'S', struct(), ...
        'hard_fail', true, 'hard_reason', '');
end

function C = pack_cell(name, U, M, S)
    C = empty_cell();
    C.name = name; C.U = U; C.M = M; C.S = compact_S(S);
    C.hard_fail = M.hard_fail; C.hard_reason = M.hard_reason;
end

function Sc = compact_S(S)
    Sc = struct();
    if ~isfield(S, 't') || isempty(S.t); return; end
    % Downsample for artifact budget
    n = numel(S.t); step = max(1, floor(n / 200));
    idx = 1:step:n;
    keep = {'t','vp','theta_ref','delta_e','e_z_path','z_path','Uh','VD'};
    for i = 1:numel(keep)
        if isfield(S, keep{i})
            v = S.(keep{i});
            if size(v, 1) == n; Sc.(keep{i}) = v(idx, :); else; Sc.(keep{i}) = v; end
        end
    end
    if isfield(S, 'gov'); Sc.gov_count = sum(S.gov > 0); end
    if isfield(S, 'aw'); Sc.aw_count = sum(S.aw > 0); end
end

function M = fail_metrics(name, Trim, msg) %#ok<INUSL>
    M = struct(); M.name = name; M.trim = Trim; M.sim_ok = false; M.sim_err = msg;
    M.depth = struct('mae', NaN, 'p95', NaN, 'final_bias', NaN, 'max_dev', NaN, ...
        'overshoot', NaN, 'settling_s', NaN, 'persistent_ok', false);
    M.theta = struct('mae_deg', NaN, 'p95_deg', NaN, 'rms_deg', NaN);
    M.gamma = struct('mae_deg', NaN, 'p95_deg', NaN);
    M.alpha = struct('mae_deg', NaN, 'p95_deg', NaN);
    M.yaw = struct('mae_deg', NaN); M.roll = struct('mae_deg', NaN);
    M.speed = struct('mae', NaN, 'u_mean', NaN);
    M.act = struct('de_mag_util', NaN, 'de_rate_util', NaN, 'de_sat_pct', NaN, ...
        'de_rate_dwell_pct', NaN, 'dr_sat_pct', NaN, 'chatter_dps', NaN);
    M.bounded = false; M.persistent_ok = false;
    M.struct_events = struct('gov', 0, 'aw', 0, 'bumpless', 0);
    M.hard_fail = true; M.hard_reason = ['sim_exception:' msg];
end

function Comp = compare_grid(CellB, CellC, PrimaryKPI, Hard) %#ok<INUSD>
    [nU, nS] = size(CellB);
    maeB = nan(nU, nS); maeC = nan(nU, nS);
    hardB = false(nU, nS); hardC = false(nU, nS);
    thB = nan(nU, nS); thC = nan(nU, nS);
    gB = nan(nU, nS); gC = nan(nU, nS);
    aB = nan(nU, nS); aC = nan(nU, nS);
    satB = nan(nU, nS); satC = nan(nU, nS);
    osB = nan(nU, nS); osC = nan(nU, nS);
    stB = nan(nU, nS); stC = nan(nU, nS);
    govN = zeros(nU, nS); awN = zeros(nU, nS); bumpN = zeros(nU, nS);

    for iu = 1:nU
        for is = 1:nS
            Mb = CellB(iu, is).M; Mc = CellC(iu, is).M;
            maeB(iu, is) = nz(Mb.depth.mae); maeC(iu, is) = nz(Mc.depth.mae);
            hardB(iu, is) = Mb.hard_fail; hardC(iu, is) = Mc.hard_fail;
            thB(iu, is) = nz(Mb.theta.mae_deg); thC(iu, is) = nz(Mc.theta.mae_deg);
            gB(iu, is) = nz(Mb.gamma.mae_deg); gC(iu, is) = nz(Mc.gamma.mae_deg);
            aB(iu, is) = nz(Mb.alpha.mae_deg); aC(iu, is) = nz(Mc.alpha.mae_deg);
            satB(iu, is) = nz(Mb.act.de_sat_pct); satC(iu, is) = nz(Mc.act.de_sat_pct);
            osB(iu, is) = nz(Mb.depth.overshoot); osC(iu, is) = nz(Mc.depth.overshoot);
            stB(iu, is) = nz(Mb.depth.settling_s); stC(iu, is) = nz(Mc.depth.settling_s);
            govN(iu, is) = Mc.struct_events.gov;
            awN(iu, is) = Mc.struct_events.aw;
            bumpN(iu, is) = Mc.struct_events.bumpless;
        end
    end

    Comp = struct();
    Comp.grid_complete = all(arrayfun(@(c) c.M.sim_ok, CellB(:))) && ...
        all(arrayfun(@(c) c.M.sim_ok, CellC(:)));
    Comp.primary_B = mean(maeB(:), 'omitnan');
    Comp.primary_C = mean(maeC(:), 'omitnan');
    if Comp.primary_B > 0
        Comp.primary_improve_pct = 100 * (Comp.primary_B - Comp.primary_C) / Comp.primary_B;
    else
        Comp.primary_improve_pct = 0;
    end
    Comp.primary_pass = Comp.primary_improve_pct >= PrimaryKPI.improve_need_pct;

    % Secondary non-safety: theta/gamma/alpha MAE, chatter — allow ≤2% worse
    secB = [mean(thB(:),'omitnan'), mean(gB(:),'omitnan'), mean(aB(:),'omitnan')];
    secC = [mean(thC(:),'omitnan'), mean(gC(:),'omitnan'), mean(aC(:),'omitnan')];
    sec_worse = 100 * (secC - secB) ./ max(secB, 1e-6);
    Comp.secondary_worse_pct = sec_worse;
    Comp.secondary_ok = all(sec_worse <= PrimaryKPI.secondary_max_worse_pct | sec_worse <= 0);

    Comp.any_hard_C = any(hardC(:));
    Comp.any_hard_B = any(hardB(:));
    Comp.abs_gates_pass = ~Comp.any_hard_C;
    Comp.maeB = maeB; Comp.maeC = maeC;
    Comp.thB = thB; Comp.thC = thC; Comp.gB = gB; Comp.gC = gC;
    Comp.aB = aB; Comp.aC = aC; Comp.satB = satB; Comp.satC = satC;
    Comp.osB = osB; Comp.osC = osC; Comp.stB = stB; Comp.stC = stC;
    Comp.govN = govN; Comp.awN = awN; Comp.bumpN = bumpN;

    % Pareto vector
    Comp.Pareto = struct();
    Comp.Pareto.tracking = Comp.primary_improve_pct;
    Comp.Pareto.actuator_margin = 100 * (mean(satB(:),'omitnan') - mean(satC(:),'omitnan')) / ...
        max(mean(satB(:),'omitnan'), 1e-6);
    Comp.Pareto.energy = NaN; Comp.Pareto.energy_note = 'N/A (no power model this gate)';
    Comp.Pareto.estimation = NaN; Comp.Pareto.estimation_note = 'N/A (Gate 5)';
    Comp.Pareto.timing = NaN; Comp.Pareto.timing_note = 'N/A (Gate 6B)';
    Comp.Pareto.safety = double(Comp.abs_gates_pass);

    Comp.pass = Comp.grid_complete && Comp.primary_pass && Comp.abs_gates_pass && ...
        (Comp.secondary_ok || all(sec_worse <= 0));
    Comp.partial = Comp.grid_complete && Comp.abs_gates_pass && ~Comp.pass && ...
        (Comp.primary_improve_pct > 0);
    if ~Comp.grid_complete
        Comp.blocker = 'grid_incomplete_sim_failure';
    elseif Comp.any_hard_C
        [iu, is] = find(hardC, 1, 'first');
        Comp.blocker = sprintf('hard_fail U=%.1f %s:%s', CellC(iu,is).U, ...
            CellC(iu,is).name, CellC(iu,is).hard_reason);
    elseif ~Comp.primary_pass
        Comp.blocker = sprintf('primary_KPI_improve_%.2f%%_lt_%.1f%%', ...
            Comp.primary_improve_pct, PrimaryKPI.improve_need_pct);
    elseif ~Comp.secondary_ok
        Comp.blocker = sprintf('secondary_regression_max_%.2f%%', max(sec_worse));
    else
        Comp.blocker = 'none';
    end
end

%% ===================== writers =====================
function write_png(png_path, CellB, CellC, U_list, Scenarios, task_id, verdict, Comp)
    fig = figure('Visible', 'off', 'Color', 'w', 'Position', [40 40 1400 900]);
    % Pick representative cells: U=1.5 STEP_P2 and XZ
    iu = find(abs(U_list - 1.5) < 1e-9, 1);
    is_step = find(strcmp(Scenarios, 'STEP_P2'), 1);
    is_xz = find(strcmp(Scenarios, 'XZ'), 1);
    plot_pair(subplot(2, 3, 1), CellB(iu, is_step), CellC(iu, is_step), 'z', 'STEP_P2 U=1.5 z');
    plot_pair(subplot(2, 3, 2), CellB(iu, is_step), CellC(iu, is_step), 'th', 'STEP_P2 θ');
    plot_pair(subplot(2, 3, 3), CellB(iu, is_step), CellC(iu, is_step), 'de', 'STEP_P2 δe');
    plot_pair(subplot(2, 3, 4), CellB(iu, is_xz), CellC(iu, is_xz), 'z', 'XZ U=1.5 z');
    plot_pair(subplot(2, 3, 5), CellB(iu, is_xz), CellC(iu, is_xz), 'th', 'XZ θ');
    subplot(2, 3, 6); hold on; grid on;
    bar(1:2, [Comp.primary_B, Comp.primary_C]);
    set(gca, 'XTick', 1:2, 'XTickLabel', {'Base', 'Cand'});
    ylabel('grid mean depth MAE [m]');
    title(sprintf('Primary KPI \\Delta=%.2f%% | %s', Comp.primary_improve_pct, verdict));
    sgtitle(sprintf('%s | %s | blocker=%s', task_id, verdict, Comp.blocker), 'Interpreter', 'none');
    exportgraphics(fig, png_path, 'Resolution', 120);
    close(fig);
end

function plot_pair(ax, CB, CC, kind, ttl)
    axes(ax); hold on; grid on; %#ok<LAXES>
    if ~isfield(CB.S, 't') || isempty(CB.S.t); title(ttl); return; end
    switch kind
        case 'z'
            if isfield(CB.S, 'e_z_path')
                plot(CB.S.t, CB.S.e_z_path, 'b-', 'LineWidth', 1.0);
                plot(CC.S.t, CC.S.e_z_path, 'r-', 'LineWidth', 1.0);
                ylabel('e_z [m]');
            end
        case 'th'
            if isfield(CB.S, 'theta_ref')
                plot(CB.S.t, rad2deg(CB.S.theta_ref), 'b-', 'LineWidth', 1.0);
                plot(CC.S.t, rad2deg(CC.S.theta_ref), 'r-', 'LineWidth', 1.0);
                ylabel('\theta_{ref} [deg]');
            end
        case 'de'
            if isfield(CB.S, 'delta_e')
                plot(CB.S.t, rad2deg(CB.S.delta_e), 'b-', 'LineWidth', 1.0);
                plot(CC.S.t, rad2deg(CC.S.delta_e), 'r-', 'LineWidth', 1.0);
                ylabel('\delta_e [deg]');
            end
    end
    xlabel('t [s]'); title(ttl); legend({'B','C'}, 'Location', 'best');
end

function write_md(md_path, task_id, stamp, verdict, PrimaryKPI, Design, Comp, ...
        CellB, CellC, U_list, Scenarios, TrimBank, lim, Hard, Win, ...
        src_md, src_ctrl, src_cpt, cand_g, next_task, next_note, blocker, ...
        md_p, mat_p, png_p, seed_used, z0, L_smooth)
    fid = fopen(md_path, 'w');
    fprintf(fid, '# %s — Gate-2 structural depth/γ decoupling+governor+AW\n\n', task_id);
    fprintf(fid, '**Gate-2 verdict: %s**  \n', verdict);
    fprintf(fid, '**Stamp:** %s  \n', stamp);
    fprintf(fid, '**Blocker:** `%s`  \n', blocker);
    fprintf(fid, '**Next exact task:** `%s`\n\n', next_task);

    fprintf(fid, '## Provenance\n\n');
    fprintf(fid, '- Task sources (exactly 3): `%s`, `%s`, `%s`\n', src_md, src_ctrl, src_cpt);
    fprintf(fid, '- Isolated helper: `%s` (production `guidance_law.m` / `controller_law.m` / plant untouched)\n', cand_g);
    fprintf(fid, '- Driver: `run_depth_gamma_structural_gate.m` (one MATLAB call)\n');
    fprintf(fid, '- Artifacts: `%s`, `%s`, `%s`\n', md_p, mat_p, png_p);
    fprintf(fid, '- Seed: %d | Kp_roll=0.605072 | production depth P+I frozen\n', seed_used);
    fprintf(fid, '- CODEX_VERTICAL_PLAN.md: untouched\n\n');

    fprintf(fid, '## Primary KPI (declared a priori, before run)\n\n');
    fprintf(fid, '| Field | Value |\n|---|---|\n');
    fprintf(fid, '| Name | `%s` |\n', PrimaryKPI.name);
    fprintf(fid, '| Definition | %s |\n', PrimaryKPI.definition);
    fprintf(fid, '| Improve need | ≥%.1f%% |\n', PrimaryKPI.improve_need_pct);
    fprintf(fid, '| Secondary max worse | ≤%.1f%% (non-safety, only if abs gates PASS) |\n', ...
        PrimaryKPI.secondary_max_worse_pct);
    fprintf(fid, '| Declared before run | YES |\n\n');

    fprintf(fid, '## Structural design\n\n');
    fprintf(fid, '- Label: %s\n', Design.label);
    fprintf(fid, '- (1) Decoupling: %s\n', Design.decoupling);
    fprintf(fid, '- alpha_level*(U): [%s]\n', num2str(Design.alpha_level, '%.6g '));
    fprintf(fid, '- alpha_climb*(U): [%s]\n', num2str(Design.alpha_climb, '%.6g '));
    fprintf(fid, '- (2) Governor: %s\n', Design.governor);
    fprintf(fid, '- (3) AW: %s\n', Design.anti_windup);
    fprintf(fid, '- (4) Bumpless: %s\n', Design.bumpless);
    fprintf(fid, '- Rejected: %s\n', Design.rejected);
    fprintf(fid, '- Frozen: %s\n\n', Design.production_gains_frozen);

    fprintf(fid, '## Envelope / windows\n\n');
    fprintf(fid, '- Elevator |δe|≤%.1fdeg rate≤40deg/s; climb-FF ≤%.4fdeg\n', ...
        rad2deg(lim.de_max), rad2deg(lim.climb_ff_lim));
    fprintf(fid, '- Hard: theta<%.0fdeg rates<%.0fdeg/s |e_z|<%.1fm de_sat<%.0f%% de_rate_util<%.2f\n', ...
        Hard.theta_max_deg, Hard.rate_max_dps, Hard.depth_abs_fail_m, ...
        Hard.de_sat_hard_pct, Hard.de_rate_util_hard);
    fprintf(fid, '- Win: settle_t0=%.1fs end_frac=%.2f depth_band=±%.2fm z0=%.1f Lsm=%.1f\n\n', ...
        Win.settle_t0, Win.end_frac, Win.depth_band, z0, L_smooth);

    fprintf(fid, '## Grid results (baseline → candidate)\n\n');
    fprintf(fid, '| U | Scenario | zMAE B→C | OS B→C | settle B→C | thMAE | gMAE | aMAE | deSat | gov/AW/bump | hardC |\n');
    fprintf(fid, '|---:|---|---:|---:|---:|---:|---:|---:|---:|---|:---:|\n');
    for iu = 1:numel(U_list)
        for is = 1:numel(Scenarios)
            Mb = CellB(iu, is).M; Mc = CellC(iu, is).M;
            fprintf(fid, '| %.1f | %s | %.4f→%.4f | %.3f→%.3f | %.2f→%.2f | %.3f→%.3f | %.3f→%.3f | %.3f→%.3f | %.2f→%.2f | %d/%d/%d | %s |\n', ...
                U_list(iu), Scenarios{is}, ...
                nz(Mb.depth.mae), nz(Mc.depth.mae), ...
                nz(Mb.depth.overshoot), nz(Mc.depth.overshoot), ...
                nz(Mb.depth.settling_s), nz(Mc.depth.settling_s), ...
                nz(Mb.theta.mae_deg), nz(Mc.theta.mae_deg), ...
                nz(Mb.gamma.mae_deg), nz(Mc.gamma.mae_deg), ...
                nz(Mb.alpha.mae_deg), nz(Mc.alpha.mae_deg), ...
                nz(Mb.act.de_sat_pct), nz(Mc.act.de_sat_pct), ...
                Mc.struct_events.gov, Mc.struct_events.aw, Mc.struct_events.bumpless, ...
                yn(~Mc.hard_fail));
        end
    end
    fprintf(fid, '\n');

    fprintf(fid, '## Promotion / Pareto\n\n');
    fprintf(fid, '| Check | Value |\n|---|---|\n');
    fprintf(fid, '| Grid complete | %s |\n', yn(Comp.grid_complete));
    fprintf(fid, '| Primary B→C | %.6f → %.6f m |\n', Comp.primary_B, Comp.primary_C);
    fprintf(fid, '| Primary improve | %.2f%% (need ≥%.1f%%) | %s |\n', ...
        Comp.primary_improve_pct, PrimaryKPI.improve_need_pct, yn(Comp.primary_pass));
    fprintf(fid, '| Abs gates (cand) | %s |\n', yn(Comp.abs_gates_pass));
    fprintf(fid, '| Secondary worse %% [th,g,a] | [%s] ok=%s |\n', ...
        num2str(Comp.secondary_worse_pct, '%.2f '), yn(Comp.secondary_ok));
    fprintf(fid, '| Pareto tracking | %.2f%% |\n', Comp.Pareto.tracking);
    fprintf(fid, '| Pareto actuator_margin | %.2f%% |\n', Comp.Pareto.actuator_margin);
    fprintf(fid, '| Pareto energy | %s |\n', Comp.Pareto.energy_note);
    fprintf(fid, '| Pareto estimation | %s |\n', Comp.Pareto.estimation_note);
    fprintf(fid, '| Pareto timing | %s |\n', Comp.Pareto.timing_note);
    fprintf(fid, '| Pareto safety | %g |\n\n', Comp.Pareto.safety);

    fprintf(fid, '## Decision\n\n');
    fprintf(fid, '- Verdict: **%s**\n', verdict);
    fprintf(fid, '- Blocker: `%s`\n', blocker);
    fprintf(fid, '- Detail: %s\n', next_note);
    fprintf(fid, '- Production: untouched (baseline preserved)\n\n');

    fprintf(fid, '## Trims\n\n');
    for iu = 1:numel(TrimBank)
        T = TrimBank(iu);
        fprintf(fid, '- U=%.1f level pass=%s n=%.3g | climb pass=%s n=%.3g\n', ...
            T.U, yn(T.L.pass), T.L.norm_dyn, yn(T.C.pass), T.C.norm_dyn);
    end
    fprintf(fid, '\n## Next\n\n- Exact next task: `%s`\n', next_task);
    fclose(fid);
end

function append_logs(plan, realism, research, task_id, stamp, verdict, Comp, ...
        next_task, blocker, md_path, mat_path, png_path)
    % Readiness plan
    fid = fopen(plan, 'a');
    fprintf(fid, '\n\n---\n\n');
    fprintf(fid, '## Append — %s (%s)\n\n', task_id, stamp);
    fprintf(fid, '**Gate 2 result: %s**.\n\n', verdict);
    fprintf(fid, '- Isolated structural candidate only; production frozen; no rejected-method retry.\n');
    fprintf(fid, '- Primary KPI grid_mean_depth_MAE: %.6f→%.6f (%.2f%%).\n', ...
        Comp.primary_B, Comp.primary_C, Comp.primary_improve_pct);
    fprintf(fid, '- Blocker: `%s`. Artifacts: `suite_results/DEPTH_GAMMA_STRUCTURAL_GATE.{md,mat,png}`.\n', blocker);
    fprintf(fid, '- **Next exact task:** `%s`. CODEX_VERTICAL_PLAN untouched.\n', next_task);
    fclose(fid);

    fid = fopen(realism, 'a');
    fprintf(fid, '\n\n---\n\n');
    fprintf(fid, '## APPEND — %s — %s\n\n', task_id, stamp);
    fprintf(fid, '**Gate-2 structural depth/γ: %s**.\n\n', verdict);
    fprintf(fid, '- Scheduled alpha decoupling + feasibility governor + residual AW + bumpless; production frozen.\n');
    fprintf(fid, '- Primary improve %.2f%%; abs_gates=%s; blocker=`%s`.\n', ...
        Comp.primary_improve_pct, yn(Comp.abs_gates_pass), blocker);
    fprintf(fid, '- Artifacts: `suite_results/DEPTH_GAMMA_STRUCTURAL_GATE.{md,mat,png}`.\n');
    fprintf(fid, '- Next: **`%s`**. CODEX_VERTICAL_PLAN untouched.\n', next_task);
    fclose(fid);

    fid = fopen(research, 'a');
    fprintf(fid, '\n\n## %s — %s\n\n', task_id, stamp);
    fprintf(fid, '- Gate-2 structural decoupling/governor/AW/bumpless: **%s**.\n', verdict);
    fprintf(fid, '- Primary KPI (a priori) grid_mean_depth_MAE: %.6f→%.6f (Δ%.2f%%).\n', ...
        Comp.primary_B, Comp.primary_C, Comp.primary_improve_pct);
    fprintf(fid, '- Secondary worse%% [th,g,a]=[%s]; Pareto track=%.2f act=%.2f safety=%g.\n', ...
        num2str(Comp.secondary_worse_pct, '%.2f '), Comp.Pareto.tracking, ...
        Comp.Pareto.actuator_margin, Comp.Pareto.safety);
    fprintf(fid, '- Blocker: `%s`.\n', blocker);
    fprintf(fid, '- Artifacts: suite_results/DEPTH_GAMMA_STRUCTURAL_GATE.{md,mat,png}; helper `guidance_law_depth_gamma_structural.m`; driver `run_depth_gamma_structural_gate.m`.\n');
    fprintf(fid, '- Next: **`%s`**. CODEX_VERTICAL_PLAN untouched.\n', next_task);
    fclose(fid);
end

%% ===================== utils =====================
function y = yn(x)
    if x; y = 'YES'; else; y = 'NO'; end
end

function v = nz(x)
    if isempty(x) || ~isfinite(x); v = NaN; else; v = x; end
end

function m = mean_safe(x, mask)
    x = x(:);
    if nargin >= 2 && ~isempty(mask); x = x(mask); end
    x = x(isfinite(x));
    if isempty(x); m = NaN; else; m = mean(x); end
end

function m = max_safe(x, mask)
    x = x(:);
    if nargin >= 2 && ~isempty(mask); x = x(mask); end
    x = x(isfinite(x));
    if isempty(x); m = NaN; else; m = max(x); end
end

function m = rms_safe(x)
    x = x(:); x = x(isfinite(x));
    if isempty(x); m = NaN; else; m = sqrt(mean(x.^2)); end
end

function p = prctile_safe(x, q)
    x = x(:); x = x(isfinite(x));
    if isempty(x); p = NaN; return; end
    x = sort(x); k = max(1, min(numel(x), round(q/100 * numel(x))));
    p = x(k);
end

function s = sat_pct(u, mask, lim)
    u = u(mask); u = u(isfinite(u));
    if isempty(u); s = NaN; else; s = 100 * mean(abs(u) >= lim); end
end

function y = hf_local(x, dt)
    x = x(:);
    if numel(x) < 5; y = x; return; end
    % simple high-pass via detrend residual of moving average
    w = max(3, round(0.5 / max(dt, 1e-3)));
    k = ones(w, 1) / w;
    y = x - conv(x, k, 'same');
end

function y = detrend_safe(x)
    x = x(:);
    if numel(x) < 2; y = x; return; end
    n = numel(x); t = (0:n-1)';
    p = polyfit(t, x, 1);
    y = x - polyval(p, t);
end

function [U_h, zdot] = inertial_velocity_ned_local(ori, u, v, w)
    phi = ori(1); theta = ori(2); psi = ori(3);
    R = [cos(psi)*cos(theta), ...
         cos(psi)*sin(theta)*sin(phi) - sin(psi)*cos(phi), ...
         cos(psi)*sin(theta)*cos(phi) + sin(psi)*sin(phi);
         sin(psi)*cos(theta), ...
         sin(psi)*sin(theta)*sin(phi) + cos(psi)*cos(phi), ...
         sin(psi)*sin(theta)*cos(phi) - cos(psi)*sin(phi);
         -sin(theta), cos(theta)*sin(phi), cos(theta)*cos(phi)];
    pos_dot = R * [u; v; w];
    U_h = hypot(pos_dot(1), pos_dot(2));
    zdot = pos_dot(3);
end
