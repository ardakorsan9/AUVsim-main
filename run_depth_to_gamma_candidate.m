function run_depth_to_gamma_candidate()
% DEPTH_TO_GAMMA_CANDIDATE_001 — one isolated model-derived depth→gamma PI.
% Read-only: run_depth_outer_baseline.m, controller_law.m,
% underwater777_vehicle_dynamics.m. Production cascade+climb FF frozen.
% FIXED wn=0.08, zeta=1, U=1.5, Gdc=0.9404 (no gain sweep).
% Helper: guidance_law_depth_to_gamma.m (production guidance_law untouched).
% Artifacts: suite_results/DEPTH_TO_GAMMA_CANDIDATE.{md,mat,png}
% Appends: suite_results/PITCH_CONTROL_RESEARCH_LOG.md
% Never touches CODEX_VERTICAL_PLAN.md.

    project_dir = fileparts(mfilename('fullpath'));
    addpath(project_dir);
    out_dir = fullfile(project_dir, 'suite_results');
    if ~exist(out_dir, 'dir'); mkdir(out_dir); end
    tag = 'DEPTH_TO_GAMMA_CANDIDATE';
    task_id = 'DEPTH_TO_GAMMA_CANDIDATE_001';

    base_mat  = fullfile(out_dir, 'DEPTH_OUTER_BASELINE.mat');
    base_md   = fullfile(out_dir, 'DEPTH_OUTER_BASELINE.md');
    ctrl_path = fullfile(project_dir, 'controller_law.m');
    dyn_path  = fullfile(project_dir, 'underwater777_vehicle_dynamics.m');
    base_run  = fullfile(project_dir, 'run_depth_outer_baseline.m');
    cand_guid = fullfile(project_dir, 'guidance_law_depth_to_gamma.m');
    guid_path = fullfile(project_dir, 'guidance_law.m');
    log_path  = fullfile(out_dir, 'PITCH_CONTROL_RESEARCH_LOG.md');
    assert(exist(base_mat, 'file') == 2, 'Missing %s', base_mat);
    assert(exist(ctrl_path, 'file') == 2, 'Missing %s', ctrl_path);
    assert(exist(dyn_path, 'file') == 2, 'Missing %s', dyn_path);
    assert(exist(base_run, 'file') == 2, 'Missing %s', base_run);
    assert(exist(cand_guid, 'file') == 2, 'Missing %s', cand_guid);
    assert(exist(guid_path, 'file') == 2, 'Missing %s', guid_path);
    assert(exist(log_path, 'file') == 2, 'Missing %s', log_path);

    ctrl_txt = fileread(ctrl_path);
    guid_txt = fileread(guid_path);
    cand_txt = fileread(cand_guid);
    assert(contains(ctrl_txt, 'k_gamma_climb = 0.1320695001'), 'climb FF missing');
    assert(contains(ctrl_txt, 'de_climb_ff'), 'climb FF term missing');
    assert(contains(ctrl_txt, 'theta_phys = -theta'), 'theta_phys convention missing');
    assert(contains(guid_txt, 'pitch_corr = -0.050 * z_e_f - 0.006 * z_e_i'), ...
        'production pitch_corr changed — abort');
    assert(contains(cand_txt, 'gamma_corr_raw = -Kp * e_z - Ki * I_z'), ...
        'candidate missing gamma_corr equation');
    assert(~contains(guid_txt, 'depth_to_gamma_Kp'), 'production must not host candidate gains');

    Base = load(base_mat);
    assert(isfield(Base, 'Cell') && numel(Base.Cell) == 4, 'baseline Cell missing');

    clear functions
    clear guidance_law guidance_law_depth_to_gamma controller_law
    clear global lambda_muw_ff trim_speed_table trim_elevator_table elevator_sign
    clear global K_zdot K_gamma enable_alpha_hat
    clear global last_guidance_U_h last_guidance_kappa last_r_ff
    clear global Kp_roll
    clear global depth_to_gamma_Kp depth_to_gamma_Ki depth_to_gamma_Kaw
    clear global depth_to_gamma_corr_max depth_to_gamma_rate_max
    clear global last_gamma_corr last_I_z last_gamma_corr_raw

    init_parameters();
    global lambda_muw_ff elevator_sign trim_speed_table trim_elevator_table
    global K_zdot K_gamma enable_alpha_hat
    global dt_controller dt_guidance delta_e_max delta_r_max
    global Kp_x thrust_trim thrust_max thrust_min desired_speed Kp_roll
    global pitch_ref_max pitch_ref_rate_max lookahead_distance
    global depth_to_gamma_Kp depth_to_gamma_Ki depth_to_gamma_Kaw
    global depth_to_gamma_corr_max depth_to_gamma_rate_max

    % Frozen production stack (no retune)
    elevator_sign = 1;
    trim_speed_table = [0.8 1.0 1.5 2.0];
    trim_elevator_table = deg2rad([-9.18 -7.33 -4.62 -3.17]);
    K_gamma = 0; K_zdot = 0; enable_alpha_hat = false;
    Kp_roll = 0.605072;
    Uref = 1.5;
    desired_speed = Uref;
    seed_used = 0;
    rng(seed_used, 'twister');

    % ---- Fixed model-derived gains (no sweep) ----
    Des = derive_depth_to_gamma(Uref);
    depth_to_gamma_Kp = Des.Kp;
    depth_to_gamma_Ki = Des.Ki;
    depth_to_gamma_Kaw = Des.Kaw;
    depth_to_gamma_corr_max = Des.corr_max;
    depth_to_gamma_rate_max = Des.rate_max;

    Doc = document_frames_and_equations(base_run, ctrl_path, dyn_path, ...
        delta_e_max, delta_r_max, thrust_max, thrust_min, pitch_ref_max, ...
        pitch_ref_rate_max, lookahead_distance, dt_controller, dt_guidance, ...
        thrust_trim, Kp_x, Kp_roll);
    Doc.candidate = Des;

    lim = struct( ...
        'dr_max', delta_r_max, 'de_max', delta_e_max, ...
        'dr_rate', deg2rad(40), 'de_rate', deg2rad(40), ...
        'thrust_max', thrust_max, 'thrust_min', thrust_min);

    % Same conservative gates as DEPTH_OUTER_BASELINE
    G = struct();
    G.hold = struct('depth_mae', 0.30, 'depth_p95', 0.50, 'depth_bias', 0.25, ...
        'depth_maxdev', 0.60, 'pitch_mae', 0.10, 'pitch_p95', 0.50, ...
        'gamma_mae', 0.50, 'gamma_p95', 1.00, 'cte', 0.50, ...
        'yaw_mae', 0.50, 'roll_mae', 1.00, 'elev_sat', 1.0, 'rud_sat', 1.0, ...
        'thr_sat', 1.0, 'chatter', 0.20, 'rate_util', 1.0, 'settle_max', 12.0);
    G.step = struct('depth_mae', 0.45, 'depth_p95', 0.80, 'depth_bias', 0.35, ...
        'depth_os', 0.60, 'depth_maxdev', 1.00, 'pitch_mae', 0.30, 'pitch_p95', 0.75, ...
        'gamma_mae', 1.00, 'gamma_p95', 2.00, 'cte', 0.75, ...
        'yaw_mae', 1.00, 'roll_mae', 2.00, 'elev_sat', 1.0, 'rud_sat', 1.0, ...
        'thr_sat', 1.0, 'chatter', 0.20, 'rate_util', 1.0, 'settle_max', 18.0);
    G.ramp = struct('depth_mae', 0.55, 'depth_p95', 0.80, 'depth_bias', 0.45, ...
        'depth_maxdev', 1.20, 'pitch_mae', 0.30, 'pitch_p95', 0.50, ...
        'gamma_mae', 1.00, 'gamma_p95', 1.50, 'cte', 0.60, ...
        'yaw_mae', 0.50, 'roll_mae', 1.00, 'elev_sat', 1.0, 'rud_sat', 1.0, ...
        'thr_sat', 1.0, 'chatter', 0.20, 'rate_util', 1.0, 'settle_max', 18.0);

    seed_level = struct('theta', -0.0333395, 'v', 0, 'w', -0.0500278, 'q', 0, ...
        'de', -0.116328, 'T', 3.81167, 'u', 1.5);
    seed_climb = struct('theta', -0.431841, 'v', 0, 'w', -0.0770689, 'q', 0, ...
        'de', -0.0210529, 'T', 5.73772, 'u', 1.5);
    x_scale = [10; 10; 10; 1; 1; 1; 1.5; 0.3; 0.3; 0.2; 0.2; 0.2];
    nu_dot_scale = [1.0; 0.3; 0.3; 0.2; 0.2; 0.2];
    TrimL = solve_translating(Uref, 0.0, seed_level, nu_dot_scale, x_scale, 0.01, 'level');
    TrimC = solve_translating(Uref, 0.4, seed_climb, nu_dot_scale, x_scale, 0.01, 'climb');

    Win = struct('settle_t0', 5.0, 'end_frac', 0.88, 'depth_band', 0.25, ...
        'step_post_hold', 3.0, 'hold_s', 1.0);

    z0 = 10.0;
    L_smooth = 15.0;
    Paths = build_paths(z0, L_smooth, Uref);
    Scenarios = {'HOLD', 'STEP_P2', 'STEP_M2', 'XZ_RAMP'};
    Tfin = [18, 30, 30, 22];
    lambda0 = [0.25, 0.25, 0.25, 0.0];
    gate_key = {'hold', 'step', 'step', 'ramp'};
    win_mode = {'first_hold', 'persistent', 'persistent', 'persistent'};
    Trims = {TrimL, TrimL, TrimL, TrimC};

    fprintf('\n========== %s ==========\n', task_id);
    fprintf('Uref=%.2f | FIXED wn=%.3g zeta=%.3g Gdc=%.4f\n', Uref, Des.wn, Des.zeta, Des.Gdc);
    fprintf('Kp=%.6g rad/m | Ki=%.6g rad/(m·s) | Kaw=%.6g 1/s | clamp±%.0fdeg rate≤%.0fdeg/s\n', ...
        Des.Kp, Des.Ki, Des.Kaw, rad2deg(Des.corr_max), rad2deg(Des.rate_max));
    fprintf('Poles (model): %.5g, %.5g | production cascade+climbFF frozen | no sweep\n', ...
        Des.poles(1), Des.poles(2));

    CellB = Base.Cell;   % identical baseline from DEPTH_OUTER_BASELINE_001
    CellC = repmat(struct('name', '', 'M', struct(), 'S', struct(), ...
        'gate_pass', false, 'first_fail', ''), 1, numel(Scenarios));
    audit_complete = true;

    for i = 1:numel(Scenarios)
        name = Scenarios{i};
        fprintf('\n---- CAND %s ----\n', name);
        rng(seed_used, 'twister');
        desired_speed = Uref;
        lambda_muw_ff = lambda0(i);
        try
            [S, M] = sim_scenario(Paths.(name), Tfin(i), Uref, Trims{i}, lim, ...
                Win, win_mode{i}, name, Paths.meta.(name));
            M.trim = Trims{i};
            M.name = name;
            M.sim_ok = true;
            M.sim_err = '';
        catch ME
            fprintf('  SIM ERROR: %s\n', ME.message);
            S = struct('t', [], 'name', name);
            M = fail_metrics(name, Trims{i}, ME.message);
            audit_complete = false;
        end
        [M.gate_pass, M.first_fail, M.gates] = score_gates(M, G.(gate_key{i}), lim);
        CellC(i).name = name;
        CellC(i).M = M;
        CellC(i).S = compact_S(S);
        CellC(i).gate_pass = M.gate_pass;
        CellC(i).first_fail = M.first_fail;
        Mb = CellB(i).M;
        fprintf('  gate=%s first=%s | zMAE %.4f→%.4f zp95 %.4f→%.4f zbias %.4f→%.4f settle %.2f→%.2f\n', ...
            yn(M.gate_pass), sanitize(M.first_fail), ...
            nz(Mb.depth.mae), nz(M.depth.mae), nz(Mb.depth.p95), nz(M.depth.p95), ...
            nz(Mb.depth.final_bias), nz(M.depth.final_bias), ...
            nz(Mb.depth.settling_s), nz(M.depth.settling_s));
        fprintf('  thMAE %.4f→%.4f gMAE %.4f→%.4f deSat %.2f→%.2f chat %.4f→%.4f\n', ...
            nz(Mb.theta.mae_deg), nz(M.theta.mae_deg), ...
            nz(Mb.gamma.mae_deg), nz(M.gamma.mae_deg), ...
            nz(Mb.act.de_sat_pct), nz(M.act.de_sat_pct), ...
            nz(Mb.act.chatter_dps), nz(M.act.chatter_dps));
    end

    Comp = compare_base_cand(CellB, CellC, G, gate_key, lim);
    all_depth_gates = Comp.all_depth_gates;
    if ~audit_complete
        verdict = 'FAIL';
        Comp.pass = false;
        Comp.first_fail = 'sim_exception';
    elseif Comp.pass
        verdict = 'PASS';
    else
        verdict = 'FAIL';
    end

    if strcmp(verdict, 'PASS')
        Next = struct('decision', 'ACCEPT_DEPTH_TO_GAMMA_CANDIDATE', ...
            'detail', ['Model depth→gamma PI accepted: all depth gates PASS, aggregate ', ...
            'depth MAE or persistent settle improved ≥10%, no >2% depth/attitude/actuator ', ...
            'regressions (unless absolute gates improve/pass), sat≤1%, bounded, no chatter/OS.']);
        alt = struct('name', '', 'detail', '');
    else
        Next = struct('decision', 'REJECT_DEPTH_TO_GAMMA_CANDIDATE', ...
            'detail', ['Reject/revert isolated candidate (production untouched). First fail: ', ...
            Comp.first_fail, '. Next bounded alternative (not a sweep): raised-cosine ', ...
            'depth-reference soft-start / command shaping on z_ref before the same PI, ', ...
            'or one NDO buoyancy-bias observer feeding gamma_corr (fixed b0 from Gdc).']);
        alt = struct('name', 'bounded_zref_raised_cosine_softstart_or_NDO_buoyancy', ...
            'detail', ['Prefer one bounded depth-reference raised-cosine soft-start ', ...
            '(shape z_ref transitions; keep FIXED Kp/Ki) OR one NDO estimating constant ', ...
            'buoyancy/trim depth bias with b0=U*Gdc, feeding gamma_corr — no gain sweep.']);
    end

    Det = struct();
    Det.seed = seed_used;
    Det.rng = 'twister';
    Det.second_run = false;
    Det.baseline_source = base_mat;
    Det.note = ['Candidate vs identical DEPTH_OUTER_BASELINE_001 Cell (same paths/IC/windows). ', ...
        'Plant/controller deterministic; production guidance/controller untouched.'];

    md_path  = fullfile(out_dir, [tag '.md']);
    mat_path = fullfile(out_dir, [tag '.mat']);
    png_path = fullfile(out_dir, [tag '.png']);

    write_png(png_path, CellC, Paths, task_id, verdict, Uref, z0);
    write_md(md_path, task_id, verdict, Doc, CellB, CellC, Comp, G, Win, TrimL, TrimC, ...
        Next, Det, Des, alt, lim, Uref, z0, L_smooth, seed_used, ...
        base_run, ctrl_path, dyn_path, cand_guid, base_mat, base_md, ...
        md_path, mat_path, png_path, thrust_trim, Kp_x, Kp_roll);
    append_research_log(log_path, task_id, verdict, CellB, CellC, Comp, Next, Des, alt, ...
        md_path, mat_path, png_path);

    Out = struct();
    Out.task_id = task_id;
    Out.verdict = verdict;
    Out.audit_complete = audit_complete;
    Out.all_depth_gates = all_depth_gates;
    Out.Comp = Comp;
    Out.Des = Des;
    Out.Uref = Uref;
    Out.z0 = z0;
    Out.L_smooth = L_smooth;
    Out.Doc = Doc;
    Out.Gates = G;
    Out.Win = Win;
    Out.TrimL = TrimL;
    Out.TrimC = TrimC;
    Out.CellB = CellB;
    Out.CellC = CellC;
    Out.Next = Next;
    Out.alt = alt;
    Out.Det = Det;
    Out.limits = lim;
    Out.seed_used = seed_used;
    Out.Kp_roll = Kp_roll;
    Out.thrust_trim = thrust_trim;
    Out.Kp_x = Kp_x;
    Out.production_edited = false;
    Out.sources = {base_run; ctrl_path; dyn_path; cand_guid; base_mat};
    Out.paths = struct('md', md_path, 'mat', mat_path, 'png', png_path);
    save(mat_path, '-struct', 'Out', '-v7.3');

    fprintf('\nVERDICT: %s | all_depth_gates=%s | first=%s\n', ...
        verdict, yn(all_depth_gates), sanitize(Comp.first_fail));
    fprintf('Next: %s\n', Next.decision);
    if ~isempty(alt.name); fprintf('Alt: %s\n', alt.name); end
    fprintf('Saved: %s\n%s\n%s\n', md_path, mat_path, png_path);
    assignin('base', 'DEPTH_TO_GAMMA_CANDIDATE_PASS', strcmp(verdict, 'PASS'));
end

%% ===================== design (fixed, no sweep) =====================
function Des = derive_depth_to_gamma(U)
    % Model: ė_z ≈ U*Gdc*gamma_corr; PI → (s+wn)^2 with zeta=1.
    % Kp = 2*zeta*wn/(U*Gdc) [rad/m]; Ki = wn^2/(U*Gdc) [rad/(m·s)].
    wn = 0.08;          % rad/s
    zeta = 1.0;
    Gdc = 0.9404;       % validated closed-inner T_gamma DC [rad/rad]
    Kp = 2 * zeta * wn / (U * Gdc);
    Ki = (wn^2) / (U * Gdc);
    Kaw = Ki / max(Kp, 1e-12);   % back-calc [1/s]
    poles = [-wn; -wn];          % critically damped desired depth poles
    Des = struct();
    Des.wn = wn;
    Des.zeta = zeta;
    Des.U = U;
    Des.Gdc = Gdc;
    Des.Kp = Kp;
    Des.Ki = Ki;
    Des.Kaw = Kaw;
    Des.corr_max = deg2rad(12);
    Des.rate_max = deg2rad(3);
    Des.poles = poles;
    Des.units = struct('Kp', 'rad/m', 'Ki', 'rad/(m·s)', 'Kaw', '1/s', ...
        'wn', 'rad/s', 'Gdc', 'rad/rad', 'e_z', 'm', 'gamma_corr', 'rad');
    Des.equations = { ...
        'e_z = z - z_ref  (NED down; = cte(3) = z_veh-z_path, filtered z_e_f)'; ...
        'ė_z ≈ U * Gdc * gamma_corr'; ...
        'Kp = 2*zeta*wn/(U*Gdc);  Ki = wn^2/(U*Gdc)'; ...
        'gamma_corr_raw = -Kp*e_z - Ki*I'; ...
        'gamma_corr = rate_limit(sat(gamma_corr_raw, ±12deg), 3deg/s)'; ...
        'conditional I + Kaw*aw back-calc on sat; bumpless I=0'; ...
        'pitch_raw = pitch_geom + gamma_corr  (thru frozen theta/q + climb FF)'};
    Des.provenance = ['Gdc=0.9404 from OUTER_GAMMA_* mean closed-inner T_gamma DC ', ...
        '(OUTER_GAMMA_ADRC_SCAFFOLD / OUTER_GAMMA_PI_SCAFFOLD / OUTER_GAMMA_INDI_AUDIT); ', ...
        'wn/zeta fixed by task; U=1.5 design speed; NED z-down kinematics.'];
    Des.frames = 'NED z↓; theta_phys=-theta; pitch_ref physical dive-positive';
end

%% ===================== compare / gates =====================
function Comp = compare_base_cand(CellB, CellC, G, gate_key, lim) %#ok<INUSD>
    n = numel(CellC);
    Comp = struct();
    Comp.first_fail = 'none';
    Comp.rows = repmat(struct('name', '', 'depth_gate', false, 'zmae_b', NaN, ...
        'zmae_c', NaN, 'zp95_b', NaN, 'zp95_c', NaN, 'settle_b', NaN, 'settle_c', NaN, ...
        'reg_ok', true, 'note', ''), 1, n);

    depth_mae_b = zeros(n, 1); depth_mae_c = zeros(n, 1);
    settle_ok_b = false(n, 1); settle_ok_c = false(n, 1);
    all_depth = true;
    worsen = 0.02;
    improve = 0.10;

    for i = 1:n
        Mb = CellB(i).M; Mc = CellC(i).M;
        gk = gate_key{i};
        [dg, first_d] = depth_gates_only(Mc, G.(gk));
        Comp.rows(i).name = CellC(i).name;
        Comp.rows(i).depth_gate = dg;
        Comp.rows(i).zmae_b = nz(Mb.depth.mae);
        Comp.rows(i).zmae_c = nz(Mc.depth.mae);
        Comp.rows(i).zp95_b = nz(Mb.depth.p95);
        Comp.rows(i).zp95_c = nz(Mc.depth.p95);
        Comp.rows(i).settle_b = nz(Mb.depth.settling_s);
        Comp.rows(i).settle_c = nz(Mc.depth.settling_s);
        Comp.rows(i).first_depth = first_d;
        depth_mae_b(i) = Mb.depth.mae;
        depth_mae_c(i) = Mc.depth.mae;
        settle_ok_b(i) = isfield(Mb.depth, 'persistent_ok') && Mb.depth.persistent_ok ...
            && ~isnan(Mb.depth.settling_s);
        settle_ok_c(i) = isfield(Mc.depth, 'persistent_ok') && Mc.depth.persistent_ok ...
            && ~isnan(Mc.depth.settling_s);
        if ~dg
            all_depth = false;
            if strcmp(Comp.first_fail, 'none')
                Comp.first_fail = sprintf('%s:%s', CellC(i).name, first_d);
            end
        end
    end
    Comp.all_depth_gates = all_depth;

    % Aggregate depth MAE improvement ≥10% OR persistent-settle improvement ≥10%
    agg_b = mean(depth_mae_b, 'omitnan');
    agg_c = mean(depth_mae_c, 'omitnan');
    Comp.agg_mae_b = agg_b;
    Comp.agg_mae_c = agg_c;
    Comp.agg_mae_improve = (agg_b - agg_c) / max(agg_b, eps);
    n_settle_b = nnz(settle_ok_b);
    n_settle_c = nnz(settle_ok_c);
    Comp.n_persist_b = n_settle_b;
    Comp.n_persist_c = n_settle_c;
    % settle improve: more scenarios persist, or mean settle time among those that settle
    settle_improve = false;
    if n_settle_c > n_settle_b
        settle_improve = true;
        Comp.settle_improve_frac = (n_settle_c - n_settle_b) / max(n, 1);
    elseif n_settle_c >= 1 && n_settle_b >= 1
        sb = [Comp.rows.settle_b]; sb = sb(settle_ok_b);
        sc = [Comp.rows.settle_c]; sc = sc(settle_ok_c);
        if mean(sc) <= (1 - improve) * mean(sb)
            settle_improve = true;
            Comp.settle_improve_frac = (mean(sb) - mean(sc)) / max(mean(sb), eps);
        else
            Comp.settle_improve_frac = (mean(sb) - mean(sc)) / max(mean(sb), eps);
        end
    else
        Comp.settle_improve_frac = (n_settle_c - n_settle_b) / max(n, 1);
    end
    Comp.mae_improve_ok = Comp.agg_mae_improve >= improve;
    Comp.settle_improve_ok = settle_improve && (Comp.settle_improve_frac >= improve || n_settle_c > n_settle_b);
    Comp.agg_improve_ok = Comp.mae_improve_ok || Comp.settle_improve_ok;
    if ~Comp.agg_improve_ok && strcmp(Comp.first_fail, 'none')
        Comp.first_fail = sprintf('agg_improve(mae=%.1f%% settle=%.1f%%)<10%%', ...
            100 * Comp.agg_mae_improve, 100 * Comp.settle_improve_frac);
    end

    % Per-scenario depth MAE/p95 no >2% regression
    Comp.depth_reg_ok = true;
    for i = 1:n
        zb = Comp.rows(i).zmae_b; zc = Comp.rows(i).zmae_c;
        pb = Comp.rows(i).zp95_b; pc = Comp.rows(i).zp95_c;
        ok = true;
        if isfinite(zb) && isfinite(zc) && zc > zb * (1 + worsen) + 1e-9
            ok = false;
            if strcmp(Comp.first_fail, 'none')
                Comp.first_fail = sprintf('%s:zMAE_regress(%.4f→%.4f)', Comp.rows(i).name, zb, zc);
            end
        end
        if isfinite(pb) && isfinite(pc) && pc > pb * (1 + worsen) + 1e-9
            ok = false;
            if strcmp(Comp.first_fail, 'none')
                Comp.first_fail = sprintf('%s:zp95_regress(%.4f→%.4f)', Comp.rows(i).name, pb, pc);
            end
        end
        Comp.rows(i).reg_ok = ok;
        Comp.depth_reg_ok = Comp.depth_reg_ok && ok;
    end

    % Attitude / actuator: no >2% regression unless absolute gates improve/pass
    Comp.att_act_ok = true;
    for i = 1:n
        Mb = CellB(i).M; Mc = CellC(i).M;
        gk = G.(gate_key{i});
        checks = { ...
            {'theta.mae_deg', 'pitch_mae'}; ...
            {'theta.p95_deg', 'pitch_p95'}; ...
            {'theta.rms_deg', ''}; ...
            {'gamma.mae_deg', 'gamma_mae'}; ...
            {'gamma.p95_deg', 'gamma_p95'}; ...
            {'gamma.rms_deg', ''}; ...
            {'yaw.mae_deg', 'yaw_mae'}; ...
            {'yaw.p95_deg', ''}; ...
            {'roll.tilde_mae_deg', 'roll_mae'}; ...
            {'act.de_sat_pct', 'elev_sat'}; ...
            {'act.dr_sat_pct', 'rud_sat'}; ...
            {'act.thr_sat_pct', 'thr_sat'}; ...
            {'act.chatter_dps', 'chatter'}; ...
            {'act.de_rate_util', 'rate_util'}; ...
            {'act.dr_rate_util', 'rate_util'}};
        for k = 1:numel(checks)
            path = checks{k}{1};
            gfield = checks{k}{2};
            vb = get_nested(Mb, path);
            vc = get_nested(Mc, path);
            if ~isfinite(vb) || ~isfinite(vc); continue; end
            if vc <= vb * (1 + worsen) + 1e-12; continue; end
            % regression allowed if absolute gate passes / improves
            abs_ok = false;
            if ~isempty(gfield) && isfield(gk, gfield)
                limv = gk.(gfield);
                abs_ok = (vc <= limv) && (vc <= vb + 1e-12 || Mc.gate_pass);
            end
            % sat special: must stay ≤1%
            if contains(path, 'sat_pct') && vc > 1.0 + 1e-9
                abs_ok = false;
            end
            if ~abs_ok
                Comp.att_act_ok = false;
                if strcmp(Comp.first_fail, 'none')
                    Comp.first_fail = sprintf('%s:%s_regress(%.4g→%.4g)', ...
                        Comp.rows(i).name, path, vb, vc);
                end
            end
        end
        % bounded / chatter / overshoot hard
        if ~Mc.bounded
            Comp.att_act_ok = false;
            if strcmp(Comp.first_fail, 'none'); Comp.first_fail = [Comp.rows(i).name ':unbounded']; end
        end
        if isfinite(Mc.act.de_sat_pct) && Mc.act.de_sat_pct > 1.0 + 1e-9
            Comp.att_act_ok = false;
            if strcmp(Comp.first_fail, 'none')
                Comp.first_fail = sprintf('%s:elev_sat(%.2f>1)', Comp.rows(i).name, Mc.act.de_sat_pct);
            end
        end
        if isfield(Mc.depth, 'overshoot') && isfinite(Mc.depth.overshoot) ...
                && isfield(gk, 'depth_os') && Mc.depth.overshoot > gk.depth_os
            Comp.att_act_ok = false;
            if strcmp(Comp.first_fail, 'none')
                Comp.first_fail = sprintf('%s:overshoot(%.3f)', Comp.rows(i).name, Mc.depth.overshoot);
            end
        end
    end

    Comp.pass = Comp.all_depth_gates && Comp.agg_improve_ok && Comp.depth_reg_ok && Comp.att_act_ok;
end

function [ok, first] = depth_gates_only(M, G)
    first = 'none';
    order = {};
    g_ok = isfield(M, 'sim_ok') && M.sim_ok;
    order{end+1} = {g_ok, 'sim_fail'}; %#ok<AGROW>
    g_b = isfield(M, 'bounded') && M.bounded;
    order{end+1} = {g_b, 'states_unbounded'}; %#ok<AGROW>
    g_zmae = ~isnan(M.depth.mae) && (M.depth.mae <= G.depth_mae);
    g_zp95 = ~isnan(M.depth.p95) && (M.depth.p95 <= G.depth_p95);
    g_zbias = ~isnan(M.depth.final_bias) && (abs(M.depth.final_bias) <= G.depth_bias);
    order{end+1} = {g_zmae, sprintf('depth_MAE(%.4f>%.4f)', nz(M.depth.mae), G.depth_mae)}; %#ok<AGROW>
    order{end+1} = {g_zp95, sprintf('depth_p95(%.4f>%.4f)', nz(M.depth.p95), G.depth_p95)}; %#ok<AGROW>
    order{end+1} = {g_zbias, sprintf('depth_bias(%.4f>%.4f)', nz(abs(M.depth.final_bias)), G.depth_bias)}; %#ok<AGROW>
    if isfield(G, 'depth_os')
        g_os = ~isnan(M.depth.overshoot) && (M.depth.overshoot <= G.depth_os);
        order{end+1} = {g_os, sprintf('depth_OS(%.4f>%.4f)', nz(M.depth.overshoot), G.depth_os)}; %#ok<AGROW>
    end
    if isfield(G, 'depth_maxdev')
        g_md = ~isnan(M.depth.max_dev) && (M.depth.max_dev <= G.depth_maxdev);
        order{end+1} = {g_md, sprintf('depth_maxdev(%.4f>%.4f)', nz(M.depth.max_dev), G.depth_maxdev)}; %#ok<AGROW>
    end
    if isfield(G, 'settle_max')
        if isnan(M.depth.settling_s)
            g_settle = false;
        else
            g_settle = M.depth.settling_s <= G.settle_max;
        end
        order{end+1} = {g_settle, sprintf('settle(%.2f>%.2f or NaN)', nz(M.depth.settling_s), G.settle_max)}; %#ok<AGROW>
    end
    ok = true;
    for k = 1:numel(order)
        if ~order{k}{1}
            ok = false; first = order{k}{2}; return;
        end
    end
end

function v = get_nested(S, path)
    v = NaN;
    parts = strsplit(path, '.');
    cur = S;
    for i = 1:numel(parts)
        if ~isstruct(cur) || ~isfield(cur, parts{i}); return; end
        cur = cur.(parts{i});
    end
    if isnumeric(cur) && isscalar(cur); v = cur; end
end

%% ===================== documentation =====================
function Doc = document_frames_and_equations(cpt, ctrl, dyn, de_max, dr_max, ...
        thr_max, thr_min, pr_max, pr_rate, L, dtc, dtg, Ttrim, Kpx, Kproll)
    Doc = struct();
    Doc.inertial_frame = 'NED (North-East-Down): x North, y East, z Down';
    Doc.body_frame = ['BODY: x forward, y starboard, z down; rates p,q,r about BODY; ', ...
        'Euler ZYX (psi,theta,phi) with ang_dot = JJ*[p;q;r]'];
    Doc.z_positive_down = true;
    Doc.depth_def = 'depth ≡ inertial z [m], positive down (NED); +depth step = dive';
    Doc.state_order = 'g = [x y z phi theta psi u v w p q r]';
    Doc.state_provenance = ['plant underwater777_vehicle_dynamics; integrated by ode45 ', ...
        'in continuous_path_tracking every dt_controller'];
    Doc.input_order = 'controls.delta_r, controls.delta_e, controls.thrust';
    Doc.input_provenance = ['controller_law(yaw_ref,pitch_ref,u_ref,...) → ', ...
        'rudder/elevator/thrust; guidance_law ZOH every dt_guidance'];
    Doc.R_body_to_ned = ['pos_dot = R(phi,theta,psi)*[u;v;w]; R row3=[-sin(theta), ', ...
        'cos(theta)sin(phi), cos(theta)cos(phi)] (Fossen NED)'];
    Doc.Uh_zdot = 'U_h=hypot(x_dot,y_dot); zdot=pos_dot(3)  [continuous_path_tracking]';
    Doc.theta_phys = 'theta_phys = -theta  [rad]; dive-positive matches atan2(dz,dx) with z down';
    Doc.theta_phys_dot = 'theta_phys_dot = -q*cos(phi) + r*sin(phi)';
    Doc.path_error = struct();
    Doc.path_error.cte_vec = 'cte = p_vehicle - p_path(s_prog)';
    Doc.path_error.y_e = 'y_e = dot(cte(1:2), n_h), n_h = [-t_h(2), t_h(1)]';
    Doc.path_error.z_e_f = 'z_e_f = 0.93*z_e_f + 0.07*cte(3);  cte(3)=z_veh-z_path';
    Doc.path_error.e_z_log = 'last_e_z = -z_e_f  (= z_path - z_veh, filtered)';
    Doc.path_error.pitch_corr = [ ...
        'pitch_corr = -0.050*z_e_f - 0.006*z_e_i - K_zdot*zd_e_f; ', ...
        'z_e_i += z_e_f*dt, |z_e_i|<=25; |pitch_corr|<=9deg; production K_zdot=0'];
    Doc.gamma = struct();
    Doc.gamma.actual = 'gamma_actual = atan2(zdot_inertial, max(U_h,0.05))';
    Doc.gamma.path = 'gamma_path = atan2(zdot_path, U_path_h), zdot_path=t_hat(3)*U_along';
    Doc.gamma.e = 'e_gamma = wrapToPi(gamma_path - gamma_actual); eg_f = 0.85*eg_f+0.15*e';
    Doc.gamma.cmd = [ ...
        'gamma_cmd = pitch_geom + K_gamma*eg_f + pitch_corr; ', ...
        'pitch_geom = 0.65*atan2(t_look_z,||t_look_h||)+0.35*atan2(t_now_z,||t_now_h||); ', ...
        'production K_gamma=0 → pitch_raw = pitch_geom + pitch_corr (alpha_hat OFF)'];
    Doc.pitch_limits = sprintf('|pitch_ref|<=%.1fdeg; |dpitch_ref/dt|<=%.1fdeg/s', ...
        rad2deg(pr_max), rad2deg(pr_rate));
    Doc.actuator_limits = sprintf( ...
        '|dr|<=%.1fdeg |de|<=%.1fdeg rate<=40deg/s; thrust in [%.0f,%.0f] N', ...
        rad2deg(dr_max), rad2deg(de_max), thr_min, thr_max);
    Doc.controller = [ ...
        'e_theta=pitch_ref-theta_phys; theta_rate_cmd=0.8*pitch_ref_dot+Kp*e+Ki*int; ', ...
        'de = de_trim + de_uw_ff + de_climb_ff + de_fb; ', ...
        'de_climb_ff=sat(0.1320695001*pitch_ref, ±2.8793deg); ', ...
        'thrust = thrust_trim + Kp_x*(u_ref-u)'];
    Doc.units = struct('pos', 'm', 'angles', 'rad (reported deg)', ...
        'rates', 'rad/s', 'speed', 'm/s', 'force', 'N', 'moment', 'N·m');
    Doc.timing = sprintf('dt_controller=%.4fs dt_guidance=%.4fs lookahead=%.2fm', ...
        dtc, dtg, L);
    Doc.production_gains = sprintf('Kp_x=%.0f thrust_trim=%.1fN Kp_roll=%.6fs Kγ=0 Kzdot=0', ...
        Kpx, Ttrim, Kproll);
    Doc.sources = {cpt; ctrl; dyn};
end

%% ===================== paths =====================
function P = build_paths(z0, Lsm, Uref) %#ok<INUSD>
    P = struct();
    P.meta = struct();

    % HOLD: constant depth
    n = 600; x = linspace(0, 45, n)';
    P.HOLD = [x, zeros(n, 1), z0 * ones(n, 1)];
    P.meta.HOLD = struct('z_cmd', z0, 'dz', 0, 'x_trans0', NaN, 'x_trans1', NaN, ...
        'class', 'hold', 'desc', sprintf('constant depth z=%.1f m', z0));

    % STEP +2m (dive) with cosine smoothing
    [P.STEP_P2, meta_p] = depth_step_path(z0, +2.0, Lsm);
    P.meta.STEP_P2 = meta_p;
    P.meta.STEP_P2.class = 'step';
    P.meta.STEP_P2.desc = sprintf('+2m dive z=%.1f→%.1f over L=%.1fm cosine', z0, z0+2, Lsm);

    % STEP -2m (ascend) with cosine smoothing
    [P.STEP_M2, meta_m] = depth_step_path(z0, -2.0, Lsm);
    P.meta.STEP_M2 = meta_m;
    P.meta.STEP_M2.class = 'step';
    P.meta.STEP_M2.desc = sprintf('-2m ascend z=%.1f→%.1f over L=%.1fm cosine', z0, z0-2, Lsm);

    % XZ depth-ramp (canonical production slope 0.4)
    nXZ = 900; xXZ = linspace(0, 42, nXZ)';
    P.XZ_RAMP = [xXZ, zeros(nXZ, 1), z0 + 0.4 * xXZ];
    P.meta.XZ_RAMP = struct('z_cmd', NaN, 'dz', NaN, 'x_trans0', 0, 'x_trans1', 42, ...
        'class', 'ramp', 'slope', 0.4, ...
        'desc', sprintf('XZ ramp z=z0+0.4*x, z0=%.1f (canonical)', z0));
end

function [path, meta] = depth_step_path(z0, dz, Lsm)
    % Hold → cosine ramp → hold. Horizontal length chosen for γ feasibility.
    x_hold0 = 8.0;
    x_hold1 = 25.0;
    x_end = x_hold0 + Lsm + x_hold1;
    n = 900;
    x = linspace(0, x_end, n)';
    z = zeros(n, 1);
    x0 = x_hold0;
    x1 = x_hold0 + Lsm;
    for i = 1:n
        if x(i) <= x0
            z(i) = z0;
        elseif x(i) >= x1
            z(i) = z0 + dz;
        else
            s = (x(i) - x0) / Lsm;                 % 0..1
            w = 0.5 * (1 - cos(pi * s));            % raised-cosine
            z(i) = z0 + dz * w;
        end
    end
    path = [x, zeros(n, 1), z];
    meta = struct('z_cmd', z0 + dz, 'dz', dz, 'x_trans0', x0, 'x_trans1', x1, ...
        'L_smooth', Lsm, 'slope_max', abs(dz) * pi / (2 * Lsm), ...
        'gamma_max_deg', rad2deg(atan(abs(dz) * pi / (2 * Lsm))));
end

%% ===================== trim =====================
function P = solve_translating(Ufix, slope, seed, nu_dot_scale, x_scale, pass_tol, name)
    scale = (Ufix / max(seed.u, 0.5))^2;
    z0 = [seed.theta; seed.v; seed.w; seed.q; seed.de; seed.T * scale];
    [z, exitflag] = local_newton(@(zz) translating_cost(zz, Ufix, slope, nu_dot_scale), z0, 120);
    x = zeros(12, 1);
    x(5) = z(1); x(7) = Ufix; x(8) = z(2); x(9) = z(3); x(11) = z(4);
    u = [0; z(5); z(6)];
    f = underwater777_vehicle_dynamics(0, x, ustruct(u));
    R = residual_pack(f, nu_dot_scale);
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
end

function R = residual_pack(f, nu_dot_scale)
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

%% ===================== simulate =====================
function [S, M] = sim_scenario(path, T_final, Uref, Trim, lim, Win, win_mode, name, meta)
    global desired_speed lambda_muw_ff
    desired_speed = Uref;

    state0 = build_state0(path, Uref, Trim, name);
    S = simulate_logged(path, T_final, Uref, state0);
    S.name = name; S.Uref = Uref; S.meta = meta;
    [M, S] = analyze_scenario(S, path, Win, win_mode, lim, Uref, meta);
end

function state0 = build_state0(path, Uref, Trim, name)
% Level-trim consistent IC for hold/steps; path-tangent + climb-trim body for XZ.
    state0 = zeros(12, 1);
    state0(1:3) = path(1, :)';
    d = path(2, :) - path(1, :);
    state0(6) = atan2(d(2), d(1));
    state0(7) = Uref;
    if contains(name, 'XZ')
        % Path-tangent pitch (Fossen theta = -atan2(dz,dx_h)) + climb body rates
        state0(5) = -atan2(d(3), max(norm(d(1:2)), 1e-9));
        if isfield(Trim, 'x_star') && numel(Trim.x_star) >= 9
            state0(8) = Trim.x_star(8);
            state0(9) = Trim.x_star(9);
        end
    else
        % Physically consistent level trim (exact-u plant solve)
        state0(5) = Trim.x_star(5);
        state0(8) = Trim.x_star(8);
        state0(9) = Trim.x_star(9);
        state0(11) = Trim.x_star(11);
    end
end

function S = simulate_logged(path, T_final, Uref, state0)
% Candidate path: same multi-rate loop as continuous_path_tracking but calls
% guidance_law_depth_to_gamma (production guidance_law untouched).
    global dt_controller dt_guidance suite_delta_e_log suite_delta_r_log suite_u_log
    global suite_e_z_log suite_gamma_actual_log suite_gamma_path_log
    global suite_zdot_inertial_log suite_theta_phys_log suite_e_theta_log
    global Kp_x thrust_trim thrust_max thrust_min
    global last_delta_e last_delta_r last_dr_yaw last_dr_p last_dr_damp last_g_ac
    global last_int_angle last_int_rate last_e_theta last_theta_phys
    global last_gamma_actual last_gamma_path last_e_gamma last_e_z last_zdot_inertial

    clear guidance_law guidance_law_depth_to_gamma controller_law
    reset_ctrl_globals();

    dt = dt_controller;
    if isempty(dt_guidance); dt_guidance = dt; end
    n_steps = round(T_final / dt);
    state = state0(:);
    vp = zeros(n_steps, 3); times = zeros(n_steps, 1);
    vel = zeros(n_steps, 3); rates = zeros(n_steps, 3); ori = zeros(n_steps, 3);
    yaw_refs = zeros(n_steps, 1); pitch_refs = zeros(n_steps, 1); u_refs = zeros(n_steps, 1);
    u_ctrl = zeros(n_steps, 1); de = zeros(n_steps, 1); dr = zeros(n_steps, 1);
    e_z_g = zeros(n_steps, 1); gact = zeros(n_steps, 1); gpath = zeros(n_steps, 1);
    zdot_l = zeros(n_steps, 1); thp = zeros(n_steps, 1); eth = zeros(n_steps, 1);

    yaw_ref = 0; pitch_ref = 0; u_ref = 0; r_ff = 0; pitch_ref_dot = 0;
    progress_index = 1;
    guidance_period = max(1, round(dt_guidance / dt));
    total_time = 0;

    for idx = 1:n_steps
        current_position = state(1:3)';
        current_orientation = state(4:6)';
        current_rates = state(10:12)';
        current_u = state(7);
        current_v = state(8);
        current_w = state(9);
        [U_h, zdot_inertial] = inertial_velocity_ned_local(current_orientation, ...
            current_u, current_v, current_w);
        theta_phys_now = -current_orientation(2);

        if mod(idx - 1, guidance_period) == 0
            [yaw_ref, pitch_ref, u_ref, progress_index, r_ff, pitch_ref_dot] = ...
                guidance_law_depth_to_gamma(current_position, path, progress_index, ...
                current_u, current_v, U_h, zdot_inertial, theta_phys_now);
        end

        [delta_r, delta_e, thrust] = controller_law(yaw_ref, pitch_ref, u_ref, ...
            current_orientation(3), current_orientation(2), current_rates(3), ...
            current_rates(2), current_u, r_ff, pitch_ref_dot, ...
            current_orientation(1), current_w, current_rates(1));

        controls = struct('delta_r', delta_r, 'delta_e', delta_e, 'thrust', thrust);
        [~, g] = ode45(@(t, gg) underwater777_vehicle_dynamics(t, gg, controls), ...
            [0 dt], state);
        state = g(end, :)';

        vp(idx, :) = state(1:3);
        vel(idx, :) = state(7:9);
        rates(idx, :) = state(10:12);
        ori(idx, :) = state(4:6);
        yaw_refs(idx) = yaw_ref;
        pitch_refs(idx) = pitch_ref;
        u_refs(idx) = u_ref;
        u_ctrl(idx) = current_u;
        if isempty(last_delta_e); last_delta_e = delta_e; end
        if isempty(last_delta_r); last_delta_r = delta_r; end
        if isempty(last_e_theta); last_e_theta = 0; end
        if isempty(last_theta_phys); last_theta_phys = theta_phys_now; end
        if isempty(last_gamma_actual); last_gamma_actual = 0; end
        if isempty(last_gamma_path); last_gamma_path = 0; end
        if isempty(last_e_z); last_e_z = 0; end
        if isempty(last_zdot_inertial); last_zdot_inertial = zdot_inertial; end
        de(idx) = last_delta_e;
        dr(idx) = last_delta_r;
        e_z_g(idx) = last_e_z;
        gact(idx) = last_gamma_actual;
        gpath(idx) = last_gamma_path;
        zdot_l(idx) = last_zdot_inertial;
        thp(idx) = last_theta_phys;
        eth(idx) = last_e_theta;
        total_time = total_time + dt;
        times(idx) = total_time;
    end

    suite_delta_e_log = de; suite_delta_r_log = dr; suite_u_log = u_ctrl;
    suite_e_z_log = e_z_g; suite_gamma_actual_log = gact; suite_gamma_path_log = gpath;
    suite_zdot_inertial_log = zdot_l; suite_theta_phys_log = thp; suite_e_theta_log = eth;

    thrust = reconstruct_thrust(u_refs(:), u_ctrl(:), thrust_trim, Kp_x, thrust_min, thrust_max);
    S = struct();
    S.dt = dt; S.T_final = T_final; S.u0 = Uref;
    S.t = times(:); S.vp = vp; S.vel = vel; S.rates = rates; S.ori = ori;
    S.psi_ref = yaw_refs(:); S.theta_ref = pitch_refs(:); S.u_ref = u_refs(:);
    S.u_ctrl = u_ctrl(:); S.u_body = vel(:, 1); S.v_body = vel(:, 2); S.w_body = vel(:, 3);
    [S.Uh, S.VD, S.Vtot] = ned_speeds(ori, vel);
    S.thrust = thrust(:); S.delta_e = de; S.delta_r = dr;
    S.e_z_guid = e_z_g; S.gamma_act_guid = gact; S.gamma_path_guid = gpath;
    S.zdot = zdot_l; S.theta_phys_log = thp; S.e_theta_log = eth;
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
    pd = R * [u; v; w];
    U_h = hypot(pd(1), pd(2));
    zdot = pd(3);
end

function reset_ctrl_globals()
    clear global last_guidance_U_h last_guidance_kappa last_r_ff
    clear global last_delta_e last_delta_r last_dr_yaw last_dr_p last_dr_damp last_g_ac
    clear global last_int_angle last_int_rate last_de_fb last_de_trim last_de_uw_ff
    clear global last_e_z last_e_zdot last_zdot_inertial
    clear global last_gamma_actual last_gamma_path last_e_gamma last_alpha_eff
    clear global last_gamma_corr last_I_z last_gamma_corr_raw
    global last_guidance_U_h last_guidance_kappa last_r_ff
    global last_delta_e last_delta_r last_dr_yaw last_dr_p last_dr_damp last_g_ac
    global last_int_angle last_int_rate last_de_fb last_de_trim last_de_uw_ff
    global last_e_z last_e_zdot last_zdot_inertial
    global last_gamma_actual last_gamma_path last_e_gamma last_alpha_eff
    global last_gamma_corr last_I_z last_gamma_corr_raw
    last_guidance_U_h = []; last_guidance_kappa = []; last_r_ff = [];
    last_delta_e = []; last_delta_r = [];
    last_dr_yaw = []; last_dr_p = []; last_dr_damp = []; last_g_ac = [];
    last_int_angle = []; last_int_rate = [];
    last_de_fb = []; last_de_trim = []; last_de_uw_ff = [];
    last_e_z = []; last_e_zdot = []; last_zdot_inertial = [];
    last_gamma_actual = []; last_gamma_path = []; last_e_gamma = []; last_alpha_eff = [];
    last_gamma_corr = []; last_I_z = []; last_gamma_corr_raw = [];
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
        'u_body','thrust','delta_e','delta_r','Uh','VD','Uref','dt','name','meta', ...
        'e_z_path','z_path','gamma_act','gamma_path'};
    for i = 1:numel(keep)
        if isfield(S, keep{i}); Sc.(keep{i}) = S.(keep{i}); end
    end
end

function M = fail_metrics(name, Trim, msg)
    M = struct();
    M.name = name; M.trim = Trim; M.sim_ok = false; M.sim_err = msg;
    M.depth = struct('mae', NaN, 'p95', NaN, 'final_bias', NaN, 'max_dev', NaN, ...
        'overshoot', NaN, 'settling_s', NaN, 'persistent_ok', false);
    M.speed = struct('mae', NaN, 'p95', NaN, 'signed_mean', NaN, 'u_mean', NaN);
    M.theta = struct('mae_deg', NaN, 'p95_deg', NaN);
    M.gamma = struct('mae_deg', NaN, 'p95_deg', NaN);
    M.yaw = struct('mae_deg', NaN, 'p95_deg', NaN);
    M.roll = struct('tilde_mae_deg', NaN, 'p_rms_dps', NaN);
    M.path = struct('mean_cte', NaN, 'max_cte', NaN);
    M.act = struct('de_mag_util', NaN, 'dr_mag_util', NaN, 'thr_mag_util', NaN, ...
        'de_rate_util', NaN, 'dr_rate_util', NaN, 'thr_rate_util', NaN, ...
        'de_sat_pct', NaN, 'dr_sat_pct', NaN, 'thr_sat_pct', NaN, 'chatter_dps', NaN);
    M.bounded = false; M.persistent_ok = false;
    M.W = struct(); M.gate_pass = false; M.first_fail = ['sim_exception:' msg];
    M.gates = struct();
end

%% ===================== analyze =====================
function [M, S] = analyze_scenario(S, path, Win, win_mode, lim, Uref, meta)
    t = S.t(:); dt = S.dt; n = numel(t); %#ok<NASGU>
    phi = S.ori(:, 1);
    theta_phys = -S.ori(:, 2);
    psi = S.ori(:, 3);
    p = S.rates(:, 1);
    de = S.delta_e(:); dr = S.delta_r(:);
    e_psi = wrapToPi(S.psi_ref - psi);
    e_th = wrapToPi(S.theta_ref - theta_phys);

    [z_path, s_prog, s_total, cte_perp] = path_z_cte(path, S.vp);
    e_z = S.vp(:, 3) - z_path;          % vehicle - path; + = deeper than path (NED)
    S.e_z_path = e_z; S.z_path = z_path;

    gamma_act = atan2(S.VD, max(S.Uh, 1e-9));
    gamma_path = path_gamma(path, S.vp);
    e_gamma = wrapToPi(gamma_path - gamma_act);
    S.gamma_act = gamma_act; S.gamma_path = gamma_path;

    pm = compute_path_following_metrics(path, S.vp, S.vel, S.ori, ...
        S.psi_ref, S.theta_ref, dt, t);
    Wth = compute_pitch_window_metrics(t, e_th, s_prog, s_total, 'mode', win_mode, ...
        'band_deg', 0.5, 'end_frac', Win.end_frac, 'settle_t0', Win.settle_t0);

    % Fixed depth windows
    mask_before_end = s_prog < Win.end_frac * s_total;
    [mask_acq, mask_ss, settle_s, persist_ok] = depth_windows(t, e_z, s_prog, s_total, ...
        Win, meta, win_mode);

    if ~any(mask_ss)
        mask_ss = (t >= Win.settle_t0) & mask_before_end;
    end

    de_dot = [0; diff(de)] / dt;
    dr_dot = [0; diff(dr)] / dt;
    thr_dot = [0; diff(S.thrust)] / dt;
    e_u = S.u_ref - S.u_ctrl;

    M = struct();
    M.sim_ok = true; M.sim_err = '';
    M.W = Wth; M.mask_acq = mask_acq; M.mask_ss = mask_ss; M.mask_before_end = mask_before_end;
    M.depth = depth_stats(e_z, t, mask_ss, mask_acq, meta, settle_s, persist_ok, Win.depth_band);
    M.speed = speed_stats(e_u, mask_ss);
    M.speed.u_mean = mean_safe(S.u_ctrl, mask_ss);
    M.speed.u_ref_mean = mean_safe(S.u_ref, mask_ss);
    M.theta = err_stats_deg(e_th, mask_ss);
    M.gamma = err_stats_deg(e_gamma, mask_ss);
    M.yaw = err_stats_deg(e_psi, mask_ss);
    M.roll = struct();
    M.roll.tilde_mae_deg = rad2deg(mean_safe(abs(phi), mask_ss));
    M.roll.p_rms_dps = rad2deg(rms_safe(p(mask_ss)));
    M.path = struct('mean_cte', mean_safe(abs(cte_perp), mask_ss), ...
        'max_cte', max_safe(abs(cte_perp), mask_ss), ...
        'pm_mean_cte', pm.mean_cross_track, ...
        'pm_mean_abs_ez', pm.mean_abs_ez);

    M.act = struct();
    M.act.de_mag_util = mean_safe(abs(de), mask_ss) / lim.de_max;
    M.act.dr_mag_util = mean_safe(abs(dr), mask_ss) / lim.dr_max;
    thr_span = max(abs([lim.thrust_min, lim.thrust_max]));
    M.act.thr_mag_util = mean_safe(abs(S.thrust), mask_ss) / thr_span;
    M.act.de_rate_util = rms_safe(de_dot(mask_ss)) / lim.de_rate;
    M.act.dr_rate_util = rms_safe(dr_dot(mask_ss)) / lim.dr_rate;
    M.act.thr_rate_util = rms_safe(thr_dot(mask_ss)) / max(thr_span, 1);
    M.act.de_sat_pct = sat_pct(de, mask_ss, 0.98 * lim.de_max);
    M.act.dr_sat_pct = sat_pct(dr, mask_ss, 0.98 * lim.dr_max);
    M.act.thr_sat_pct = 100 * mean(S.thrust(mask_ss) >= 0.98 * lim.thrust_max | ...
        S.thrust(mask_ss) <= lim.thrust_min + 0.02 * abs(lim.thrust_min));
    if any(mask_ss) && nnz(mask_ss) > 10
        M.act.chatter_dps = rad2deg(std(hf_local(detrend(e_th(mask_ss)), dt)));
    else
        M.act.chatter_dps = NaN;
    end

    st = [S.ori, S.vel, S.rates];
    M.bounded = all(isfinite(st(:))) && all(isfinite(S.thrust)) && ...
        all(abs(theta_phys) < deg2rad(80)) && all(abs(S.u_body) < 5.0) && ...
        all(abs(S.rates(:)) < deg2rad(200));
    M.persistent_ok = persist_ok;
    M.meta = meta;
    M.s_total = s_total;
    M.Uref = Uref;
end

function [mask_acq, mask_ss, settle_s, persist_ok] = depth_windows(t, e_z, s, s_total, Win, meta, win_mode)
    N = numel(t);
    mask_before_end = s < Win.end_frac * s_total;
    n_end = find(mask_before_end, 1, 'last');
    if isempty(n_end); n_end = N; end
    band = Win.depth_band;
    in_band = abs(e_z) <= band;

    if strcmp(meta.class, 'hold')
        % Prefer persistent |e_z|≤band; fallback fixed settle_t0
        settle_idx = NaN;
        for k = 1:n_end
            if all(in_band(k:n_end))
                settle_idx = k; break;
            end
        end
        if ~isnan(settle_idx)
            settle_s = t(settle_idx);
            persist_ok = true;
            mask_acq = (1:N)' < settle_idx;
            mask_ss = ((1:N)' >= settle_idx) & mask_before_end;
        else
            mask_acq = t < Win.settle_t0;
            mask_ss = (t >= Win.settle_t0) & mask_before_end;
            settle_s = Win.settle_t0;
            persist_ok = false;
        end
    elseif strcmp(meta.class, 'step')
        % Fixed: acq until x past transition + post_hold time; then steady
        x_trans1 = meta.x_trans1;
        % Approximate time via arc (x≈s for straight)
        t_cmd = NaN;
        for i = 1:N
            if s(i) >= x_trans1
                t_cmd = t(i); break;
            end
        end
        if isnan(t_cmd); t_cmd = Win.settle_t0; end
        t_ss0 = t_cmd + Win.step_post_hold;
        mask_acq = t < t_ss0;
        mask_ss = (t >= t_ss0) & mask_before_end;
        settle_idx = NaN;
        k0 = find(t >= t_cmd, 1, 'first');
        if isempty(k0); k0 = 1; end
        for k = k0:n_end
            if all(in_band(k:n_end))
                settle_idx = k; break;
            end
        end
        if ~isnan(settle_idx)
            settle_s = t(settle_idx);
            persist_ok = true;
        else
            settle_s = NaN;
            persist_ok = false;
        end
    else
        % RAMP: pitch-style persistent on depth, with settle_t0 floor
        settle_idx = NaN;
        for k = 1:n_end
            if all(in_band(k:n_end))
                settle_idx = k; break;
            end
        end
        if isnan(settle_idx)
            mask_acq = t < Win.settle_t0;
            mask_ss = (t >= Win.settle_t0) & mask_before_end;
            settle_s = NaN;
            persist_ok = false;
        else
            settle_s = t(settle_idx);
            persist_ok = true;
            mask_acq = (1:N)' < settle_idx;
            mask_ss = ((1:N)' >= settle_idx) & mask_before_end;
            if ~any(mask_ss)
                mask_ss = (t >= Win.settle_t0) & mask_before_end;
            end
        end
    end
    if ~any(mask_ss)
        mask_ss = mask_before_end & (t >= Win.settle_t0);
    end
    %#ok<INUSD> win_mode retained for API parity with pitch windows
end

function D = depth_stats(e_z, t, mask_ss, mask_acq, meta, settle_s, persist_ok, band)
    D = struct();
    D.mae = mean_safe(abs(e_z), mask_ss);
    D.p95 = prctile_local(abs(e_z(mask_ss)), 95);
    D.rms = rms_safe(e_z(mask_ss));
    if any(mask_ss)
        idx = find(mask_ss, 1, 'last');
        D.final_bias = e_z(idx);
    else
        D.final_bias = NaN;
    end
    D.max_dev = max_safe(abs(e_z), true(size(e_z)));
    D.max_dev_ss = max_safe(abs(e_z), mask_ss);
    D.settling_s = settle_s;
    D.persistent_ok = persist_ok;
    D.band = band;
    % Overshoot vs commanded step (only meaningful for steps)
    if strcmp(meta.class, 'step') && isfield(meta, 'dz') && isfinite(meta.dz) && meta.dz ~= 0
        % Overshoot: peak signed excursion beyond final depth in the direction of step
        % During/after transition: e_z = z - z_path; path already has command.
        % Use vehicle depth vs final commanded depth.
        z_final = meta.z_cmd; %#ok<NASGU>
        % Peak |e_z| during acquisition after command starts, beyond ss band
        if any(mask_acq)
            % signed overshoot relative to path during late acq
            ez_acq = e_z(mask_acq);
            if meta.dz > 0
                D.overshoot = max(0, max(ez_acq));   % overshoot dive (too deep)
            else
                D.overshoot = max(0, max(-ez_acq));  % overshoot ascend (too shallow)
            end
        else
            D.overshoot = NaN;
        end
    else
        D.overshoot = 0;
    end
    D.n_ss = nnz(mask_ss);
    D.n_acq = nnz(mask_acq);
end

function [z_path, s_prog, s_total, cte_perp] = path_z_cte(path, vp)
    [s_nodes, s_total] = path_arclength(path);
    n = size(vp, 1);
    z_path = zeros(n, 1);
    s_prog = zeros(n, 1);
    cte_perp = zeros(n, 1);
    s = 0;
    L = 1.25;
    for i = 1:n
        p = vp(i, :);
        if i == 1
            [s, ~] = project_on_path(p, path, s_nodes, 0, s_total, false);
        else
            s_lo = max(0, s - 0.15);
            s_hi = min(s_total, s + max(3.0, 2.5 * L));
            [s_near, ~] = project_on_path(p, path, s_nodes, s_lo, s_hi, false);
            s = max(s, s_near - 0.05);
            s = min(s, s_total);
        end
        [pd, th] = sample_path(path, s_nodes, s, false);
        z_path(i) = pd(3);
        s_prog(i) = s;
        e = (p - pd)';
        e_perp = (eye(3) - (th(:) * th(:)')) * e;
        cte_perp(i) = norm(e_perp);
    end
end

function gamma_path = path_gamma(path, vp)
    [s_nodes, s_total] = path_arclength(path);
    n = size(vp, 1);
    gamma_path = zeros(n, 1);
    s = 0; L = 1.25;
    for i = 1:n
        p = vp(i, :);
        if i == 1
            [s, ~] = project_on_path(p, path, s_nodes, 0, s_total, false);
        else
            s_lo = max(0, s - 0.15);
            s_hi = min(s_total, s + max(3.0, 2.5 * L));
            [s_near, ~] = project_on_path(p, path, s_nodes, s_lo, s_hi, false);
            s = max(s, s_near - 0.05); s = min(s, s_total);
        end
        [~, th] = sample_path(path, s_nodes, s, false);
        gamma_path(i) = atan2(th(3), max(norm(th(1:2)), 1e-9));
    end
end

function [s_nodes, s_total] = path_arclength(path)
    n = size(path, 1);
    s_nodes = zeros(n, 1);
    for i = 2:n
        s_nodes(i) = s_nodes(i - 1) + norm(path(i, :) - path(i - 1, :));
    end
    s_total = max(s_nodes(end), 1e-9);
end

function [s_best, d_best] = project_on_path(p, path, s_nodes, s_lo, s_hi, ~)
    n = size(path, 1);
    d_best = inf; s_best = s_lo;
    i0 = max(1, find(s_nodes <= s_lo, 1, 'last'));
    i1 = min(n - 1, find(s_nodes >= s_hi, 1, 'first'));
    if isempty(i0); i0 = 1; end
    if isempty(i1); i1 = n - 1; end
    i0 = min(i0, n - 1); i1 = max(i1, i0);
    for i = i0:i1
        a = path(i, :); b = path(i + 1, :);
        ab = b - a; lab2 = sum(ab.^2);
        if lab2 < 1e-12; continue; end
        tt = max(0, min(1, dot(p - a, ab) / lab2));
        proj = a + tt * ab;
        d = norm(p - proj);
        ss = s_nodes(i) + tt * (s_nodes(i + 1) - s_nodes(i));
        if ss < s_lo - 1e-9 || ss > s_hi + 1e-9; continue; end
        if d < d_best; d_best = d; s_best = ss; end
    end
end

function [p, t_hat] = sample_path(path, s_nodes, s, ~)
    n = size(path, 1);
    s = max(0, min(s_nodes(end), s));
    i = max(1, min(n - 1, find(s_nodes <= s, 1, 'last')));
    if isempty(i); i = 1; end
    ds = s_nodes(i + 1) - s_nodes(i);
    if ds < 1e-12; tt = 0; else; tt = (s - s_nodes(i)) / ds; end
    p = path(i, :) + tt * (path(i + 1, :) - path(i, :));
    tang = path(i + 1, :) - path(i, :);
    if norm(tang) < 1e-9
        if i > 1; tang = path(i, :) - path(i - 1, :); else; tang = [1, 0, 0]; end
    end
    t_hat = tang / norm(tang);
end

%% ===================== gates =====================
function [pass, first, gates] = score_gates(M, G, lim) %#ok<INUSD>
    gates = struct();
    first = 'none';
    order = {};

    g_ok = isfield(M, 'sim_ok') && M.sim_ok;
    gates.sim_ok = g_ok;
    order{end+1} = {g_ok, 'sim_fail'}; %#ok<AGROW>

    g_b = isfield(M, 'bounded') && M.bounded;
    gates.bounded = g_b;
    order{end+1} = {g_b, 'states_unbounded'}; %#ok<AGROW>

    g_zmae = ~isnan(M.depth.mae) && (M.depth.mae <= G.depth_mae);
    g_zp95 = ~isnan(M.depth.p95) && (M.depth.p95 <= G.depth_p95);
    g_zbias = ~isnan(M.depth.final_bias) && (abs(M.depth.final_bias) <= G.depth_bias);
    gates.depth_mae = g_zmae; gates.depth_p95 = g_zp95; gates.depth_bias = g_zbias;
    order{end+1} = {g_zmae, sprintf('depth_MAE(%.4f>%.4f)', nz(M.depth.mae), G.depth_mae)}; %#ok<AGROW>
    order{end+1} = {g_zp95, sprintf('depth_p95(%.4f>%.4f)', nz(M.depth.p95), G.depth_p95)}; %#ok<AGROW>
    order{end+1} = {g_zbias, sprintf('depth_bias(%.4f>%.4f)', nz(abs(M.depth.final_bias)), G.depth_bias)}; %#ok<AGROW>

    if isfield(G, 'depth_os')
        g_os = ~isnan(M.depth.overshoot) && (M.depth.overshoot <= G.depth_os);
        gates.depth_os = g_os;
        order{end+1} = {g_os, sprintf('depth_OS(%.4f>%.4f)', nz(M.depth.overshoot), G.depth_os)}; %#ok<AGROW>
    end
    if isfield(G, 'depth_maxdev')
        g_md = ~isnan(M.depth.max_dev) && (M.depth.max_dev <= G.depth_maxdev);
        gates.depth_maxdev = g_md;
        order{end+1} = {g_md, sprintf('depth_maxdev(%.4f>%.4f)', nz(M.depth.max_dev), G.depth_maxdev)}; %#ok<AGROW>
    end

    g_settle = true;
    if isfield(G, 'settle_max')
        if isnan(M.depth.settling_s)
            g_settle = false;
        else
            g_settle = M.depth.settling_s <= G.settle_max;
        end
        gates.settle = g_settle;
        order{end+1} = {g_settle, sprintf('settle(%.2f>%.2f or NaN)', nz(M.depth.settling_s), G.settle_max)}; %#ok<AGROW>
    end

    g_pm = ~isnan(M.theta.mae_deg) && (M.theta.mae_deg <= G.pitch_mae);
    g_pp = ~isnan(M.theta.p95_deg) && (M.theta.p95_deg <= G.pitch_p95);
    g_gm = ~isnan(M.gamma.mae_deg) && (M.gamma.mae_deg <= G.gamma_mae);
    g_gp = ~isnan(M.gamma.p95_deg) && (M.gamma.p95_deg <= G.gamma_p95);
    gates.pitch_mae = g_pm; gates.pitch_p95 = g_pp;
    gates.gamma_mae = g_gm; gates.gamma_p95 = g_gp;
    order{end+1} = {g_pm, sprintf('pitch_MAE(%.4f>%.4f)', nz(M.theta.mae_deg), G.pitch_mae)}; %#ok<AGROW>
    order{end+1} = {g_pp, sprintf('pitch_p95(%.4f>%.4f)', nz(M.theta.p95_deg), G.pitch_p95)}; %#ok<AGROW>
    order{end+1} = {g_gm, sprintf('gamma_MAE(%.4f>%.4f)', nz(M.gamma.mae_deg), G.gamma_mae)}; %#ok<AGROW>
    order{end+1} = {g_gp, sprintf('gamma_p95(%.4f>%.4f)', nz(M.gamma.p95_deg), G.gamma_p95)}; %#ok<AGROW>

    g_yaw = ~isnan(M.yaw.mae_deg) && (M.yaw.mae_deg <= G.yaw_mae);
    g_roll = ~isnan(M.roll.tilde_mae_deg) && (M.roll.tilde_mae_deg <= G.roll_mae);
    g_cte = ~isnan(M.path.mean_cte) && (M.path.mean_cte <= G.cte);
    gates.yaw = g_yaw; gates.roll = g_roll; gates.cte = g_cte;
    order{end+1} = {g_yaw, sprintf('yaw_MAE(%.4f>%.4f)', nz(M.yaw.mae_deg), G.yaw_mae)}; %#ok<AGROW>
    order{end+1} = {g_roll, sprintf('roll_MAE(%.4f>%.4f)', nz(M.roll.tilde_mae_deg), G.roll_mae)}; %#ok<AGROW>
    order{end+1} = {g_cte, sprintf('CTE(%.4f>%.4f)', nz(M.path.mean_cte), G.cte)}; %#ok<AGROW>

    g_es = ~isnan(M.act.de_sat_pct) && (M.act.de_sat_pct <= G.elev_sat);
    g_rs = ~isnan(M.act.dr_sat_pct) && (M.act.dr_sat_pct <= G.rud_sat);
    g_ts = ~isnan(M.act.thr_sat_pct) && (M.act.thr_sat_pct <= G.thr_sat);
    g_ch = ~isnan(M.act.chatter_dps) && (M.act.chatter_dps <= G.chatter);
    g_deu = ~isnan(M.act.de_rate_util) && (M.act.de_rate_util <= G.rate_util);
    g_dru = ~isnan(M.act.dr_rate_util) && (M.act.dr_rate_util <= G.rate_util);
    gates.elev_sat = g_es; gates.rud_sat = g_rs; gates.thr_sat = g_ts;
    gates.chatter = g_ch; gates.de_rate = g_deu; gates.dr_rate = g_dru;
    order{end+1} = {g_es, sprintf('elev_sat(%.2f%%>%.2f%%)', nz(M.act.de_sat_pct), G.elev_sat)}; %#ok<AGROW>
    order{end+1} = {g_rs, sprintf('rud_sat(%.2f%%>%.2f%%)', nz(M.act.dr_sat_pct), G.rud_sat)}; %#ok<AGROW>
    order{end+1} = {g_ts, sprintf('thr_sat(%.2f%%>%.2f%%)', nz(M.act.thr_sat_pct), G.thr_sat)}; %#ok<AGROW>
    order{end+1} = {g_ch, sprintf('chatter(%.4f>%.4f)', nz(M.act.chatter_dps), G.chatter)}; %#ok<AGROW>
    order{end+1} = {g_deu, sprintf('de_rate_util(%.3f>%.3f)', nz(M.act.de_rate_util), G.rate_util)}; %#ok<AGROW>
    order{end+1} = {g_dru, sprintf('dr_rate_util(%.3f>%.3f)', nz(M.act.dr_rate_util), G.rate_util)}; %#ok<AGROW>

    pass = true;
    for k = 1:numel(order)
        if ~order{k}{1}
            pass = false;
            first = order{k}{2};
            break;
        end
    end
end

%% ===================== write artifacts =====================
function write_png(png_path, Cell, Paths, task_id, verdict, Uref, z0)
    fig = figure('Visible', 'off', 'Color', 'w', 'Position', [40 40 1400 1000]);
    names = {Cell.name};
    for i = 1:4
        M = Cell(i).M; S = Cell(i).S;
        subplot(4, 3, (i - 1) * 3 + 1); hold on; grid on;
        if isfield(S, 't') && ~isempty(S.t)
            plot(S.t, S.vp(:, 3), 'b-', 'LineWidth', 1.1);
            if isfield(S, 'z_path') && ~isempty(S.z_path)
                plot(S.t, S.z_path, 'k--', 'LineWidth', 1.2);
            else
                % reconstruct from Paths
                pname = names{i};
                if isfield(Paths, pname)
                    [zp, ~, ~, ~] = path_z_cte(Paths.(pname), S.vp);
                    plot(S.t, zp, 'k--', 'LineWidth', 1.2);
                end
            end
            if isfield(M, 'mask_ss') && any(M.mask_ss)
                tss = S.t(find(M.mask_ss, 1, 'first'));
                xline(tss, 'r--', 'ss');
            end
        end
        ylabel('z [m ↓]'); xlabel('t [s]');
        title(sprintf('%s z (U=%.1f) gate=%s', names{i}, Uref, yn(Cell(i).gate_pass)));

        subplot(4, 3, (i - 1) * 3 + 2); hold on; grid on;
        if isfield(S, 't') && ~isempty(S.t)
            if isfield(S, 'e_z_path') && ~isempty(S.e_z_path)
                ez = S.e_z_path;
            else
                pname = names{i};
                [zp, ~, ~, ~] = path_z_cte(Paths.(pname), S.vp);
                ez = S.vp(:, 3) - zp;
            end
            plot(S.t, ez, 'b-', 'LineWidth', 1.0);
            yline(0.25, 'k--'); yline(-0.25, 'k--'); yline(0, 'k:');
        end
        ylabel('e_z [m]'); xlabel('t [s]');
        title(sprintf('e_z MAE=%.3f p95=%.3f bias=%.3f', ...
            nz(M.depth.mae), nz(M.depth.p95), nz(M.depth.final_bias)));

        subplot(4, 3, (i - 1) * 3 + 3); hold on; grid on;
        if isfield(S, 't') && ~isempty(S.t)
            plot(S.t, rad2deg(S.theta_ref), 'k-', 'LineWidth', 1.2);
            plot(S.t, rad2deg(-S.ori(:, 2)), 'b-', 'LineWidth', 1.0);
            if isfield(S, 'delta_e')
                yyaxis right;
                plot(S.t, rad2deg(S.delta_e), 'r-', 'LineWidth', 0.8);
                ylabel('\delta_e [deg]');
                yyaxis left;
            end
        end
        ylabel('\theta [deg]'); xlabel('t [s]');
        title(sprintf('\\theta MAE=%.3f°  \\gamma MAE=%.3f°', ...
            nz(M.theta.mae_deg), nz(M.gamma.mae_deg)));
    end
    sgtitle(sprintf('%s — %s | z0=%.1fm ↓ | depth→γ PI cand', task_id, verdict, z0), ...
        'FontWeight', 'bold');
    exportgraphics(fig, png_path, 'Resolution', 140);
    close(fig);
end

function write_md(md_path, task_id, verdict, Doc, CellB, CellC, Comp, G, Win, TrimL, TrimC, ...
        Next, Det, Des, alt, lim, Uref, z0, Lsm, seed, base_run, ctrl, dyn, cand_guid, ...
        base_mat, base_md, md_p, mat_p, png_p, Ttrim, Kpx, Kproll) %#ok<INUSD>
    fid = fopen(md_path, 'w');
    fprintf(fid, '# %s — Model depth→gamma PI candidate @ U=%.2f\n\n', task_id, Uref);
    fprintf(fid, '**Overall verdict: %s**\n\n', verdict);

    fprintf(fid, '## Provenance\n\n');
    fprintf(fid, '- Read-only: `%s`, `%s`, `%s`\n', base_run, ctrl, dyn);
    fprintf(fid, '- Isolated helper: `%s` (production `guidance_law.m` / `controller_law.m` untouched)\n', cand_guid);
    fprintf(fid, '- Baseline: `%s` / `%s` (DEPTH_OUTER_BASELINE_001 identical paths/IC/windows)\n', base_mat, base_md);
    fprintf(fid, '- Driver: `run_depth_to_gamma_candidate.m` (one invocation; no production edit)\n');
    fprintf(fid, '- Artifacts: `%s`, `%s`, `%s`\n', md_p, mat_p, png_p);
    fprintf(fid, '- Seed: %d | Kp_roll frozen=%.6f | Kp_x=%.0f | thrust_trim=%.1f N\n', ...
        seed, Kproll, Kpx, Ttrim);
    fprintf(fid, '- CODEX_VERTICAL_PLAN.md: untouched\n\n');

    fprintf(fid, '## Frames / units\n\n');
    fprintf(fid, '| Item | Definition |\n|------|------------|\n');
    fprintf(fid, '| Inertial | %s |\n', Doc.inertial_frame);
    fprintf(fid, '| Body | %s |\n', Doc.body_frame);
    fprintf(fid, '| z / depth positive down? | **YES** — depth ≡ z_NED [m] |\n');
    fprintf(fid, '| e_z | e_z = z − z_ref = cte(3) = z_veh−z_path (filtered z_e_f) [m] |\n');
    fprintf(fid, '| Kinematics | ė_z ≈ U · Gdc · gamma_corr |\n');
    fprintf(fid, '| theta_phys | %s |\n', Doc.theta_phys);
    fprintf(fid, '| Cascade | frozen theta/q + climb FF (`k_gamma_climb=0.1320695001`) |\n');
    fprintf(fid, '\n');

    fprintf(fid, '## Candidate equations / gains / poles\n\n');
    fprintf(fid, '```\n');
    for i = 1:numel(Des.equations)
        fprintf(fid, '%s\n', Des.equations{i});
    end
    fprintf(fid, '```\n\n');
    fprintf(fid, '| Symbol | Value | Units |\n|--------|------:|-------|\n');
    fprintf(fid, '| wn | %.4f | rad/s |\n', Des.wn);
    fprintf(fid, '| zeta | %.4f | — |\n', Des.zeta);
    fprintf(fid, '| U | %.4f | m/s |\n', Des.U);
    fprintf(fid, '| Gdc | %.4f | rad/rad |\n', Des.Gdc);
    fprintf(fid, '| Kp | %.8f | rad/m |\n', Des.Kp);
    fprintf(fid, '| Ki | %.8f | rad/(m·s) |\n', Des.Ki);
    fprintf(fid, '| Kaw | %.8f | 1/s |\n', Des.Kaw);
    fprintf(fid, '| |gamma_corr| clamp | ±%.1f | deg |\n', rad2deg(Des.corr_max));
    fprintf(fid, '| |d gamma_corr/dt| | ≤%.1f | deg/s |\n', rad2deg(Des.rate_max));
    fprintf(fid, '| Desired poles | %.5g, %.5g | rad/s |\n', Des.poles(1), Des.poles(2));
    fprintf(fid, '\nProvenance: %s\n\n', Des.provenance);

    fprintf(fid, '## Baseline → candidate (exact)\n\n');
    fprintf(fid, '| Scenario | GateB | GateC | zMAE B→C | zp95 B→C | zbias B→C | settle B→C | thMAE B→C | gMAE B→C | deSat B→C | chat B→C |\n');
    fprintf(fid, '|----------|:-----:|:-----:|---------:|---------:|----------:|-----------:|----------:|---------:|----------:|---------:|\n');
    for i = 1:numel(CellC)
        Mb = CellB(i).M; Mc = CellC(i).M;
        fprintf(fid, '| %s | %s | %s | %.4f→%.4f | %.4f→%.4f | %.4f→%.4f | %.2f→%.2f | %.4f→%.4f | %.4f→%.4f | %.2f→%.2f | %.4f→%.4f |\n', ...
            CellC(i).name, yn(CellB(i).gate_pass), yn(CellC(i).gate_pass), ...
            nz(Mb.depth.mae), nz(Mc.depth.mae), nz(Mb.depth.p95), nz(Mc.depth.p95), ...
            nz(Mb.depth.final_bias), nz(Mc.depth.final_bias), ...
            nz(Mb.depth.settling_s), nz(Mc.depth.settling_s), ...
            nz(Mb.theta.mae_deg), nz(Mc.theta.mae_deg), ...
            nz(Mb.gamma.mae_deg), nz(Mc.gamma.mae_deg), ...
            nz(Mb.act.de_sat_pct), nz(Mc.act.de_sat_pct), ...
            nz(Mb.act.chatter_dps), nz(Mc.act.chatter_dps));
    end
    fprintf(fid, '\n');
    fprintf(fid, '- Aggregate depth MAE: %.4f → %.4f (improve %.1f%%)\n', ...
        Comp.agg_mae_b, Comp.agg_mae_c, 100 * Comp.agg_mae_improve);
    fprintf(fid, '- Persistent settle count: %d → %d | settle_improve_frac=%.3f\n', ...
        Comp.n_persist_b, Comp.n_persist_c, Comp.settle_improve_frac);
    fprintf(fid, '- all_depth_gates=%s | agg_improve=%s | depth_reg=%s | att_act=%s\n', ...
        yn(Comp.all_depth_gates), yn(Comp.agg_improve_ok), yn(Comp.depth_reg_ok), yn(Comp.att_act_ok));
    fprintf(fid, '- First fail: `%s`\n\n', sanitize(Comp.first_fail));

    fprintf(fid, '## Fixed windows / gates (identical to baseline)\n\n');
    fprintf(fid, '- settle_t0=%.1fs end_frac=%.2f depth_band=±%.2fm step_post_hold=%.1fs L_smooth=%.1fm z0=%.1f\n', ...
        Win.settle_t0, Win.end_frac, Win.depth_band, Win.step_post_hold, Lsm, z0);
    fprintf(fid, '- HOLD/STEP/RAMP depth gates unchanged from DEPTH_OUTER_BASELINE\n');
    fprintf(fid, '- Level trim pass=%s ||ν̇||=%.3g; climb pass=%s ||ν̇||=%.3g\n\n', ...
        yn(TrimL.pass), TrimL.norm_dyn, yn(TrimC.pass), TrimC.norm_dyn);

    fprintf(fid, '## Decision\n\n');
    fprintf(fid, '- Verdict: **%s**\n', verdict);
    fprintf(fid, '- Next: **`%s`**\n', Next.decision);
    fprintf(fid, '- Detail: %s\n', Next.detail);
    if ~isempty(alt.name)
        fprintf(fid, '- Bounded alternative (not a sweep): **`%s`** — %s\n', alt.name, alt.detail);
    end
    fprintf(fid, '- Production: untouched\n\n');

    fprintf(fid, '## Feedback\n\n');
    fprintf(fid, '- PASS/FAIL: **%s**\n', verdict);
    fprintf(fid, '- Scenarios: ');
    for i = 1:numel(CellC)
        fprintf(fid, '%s=%s', CellC(i).name, yn(CellC(i).gate_pass));
        if i < numel(CellC); fprintf(fid, ' | '); end
    end
    fprintf(fid, '\n- Files: `%s` `%s` `%s`\n', md_p, mat_p, png_p);
    fclose(fid);
end

function append_research_log(log_path, task_id, verdict, CellB, CellC, Comp, Next, Des, alt, md_p, mat_p, png_p)
    fid = fopen(log_path, 'a');
    ts = datestr(now, 'yyyy-mm-dd HH:MM:SS');
    fprintf(fid, '\n## %s — %s\n\n', task_id, ts);
    fprintf(fid, '- Verdict: **%s** — isolated model depth→gamma PI (wn=%.3g zeta=%.3g Gdc=%.4f); production cascade+climbFF+guidance frozen; no sweep.\n', ...
        verdict, Des.wn, Des.zeta, Des.Gdc);
    fprintf(fid, '- Gains: Kp=%.6g rad/m Ki=%.6g rad/(m·s) Kaw=%.6g 1/s; clamp±12deg rate≤3deg/s; poles %.4g,%.4g; bumpless I=0 + conditional I + back-calc.\n', ...
        Des.Kp, Des.Ki, Des.Kaw, Des.poles(1), Des.poles(2));
    fprintf(fid, '- Eq: e_z=z−z_ref (NED↓); ė_z≈U·Gdc·γ_corr; γ_corr=−Kp e_z−Ki I; pitch_ref=pitch_geom+γ_corr.\n');
    fprintf(fid, '- Before→after zMAE: ');
    for i = 1:numel(CellC)
        fprintf(fid, '%s %.4f→%.4f', CellC(i).name, nz(CellB(i).M.depth.mae), nz(CellC(i).M.depth.mae));
        if i < numel(CellC); fprintf(fid, '; '); end
    end
    fprintf(fid, ' | agg %.4f→%.4f (%.1f%%).\n', Comp.agg_mae_b, Comp.agg_mae_c, 100*Comp.agg_mae_improve);
    fprintf(fid, '- Gates: all_depth=%s agg_improve=%s depth_reg=%s att_act=%s | first=`%s`.\n', ...
        yn(Comp.all_depth_gates), yn(Comp.agg_improve_ok), yn(Comp.depth_reg_ok), ...
        yn(Comp.att_act_ok), sanitize(Comp.first_fail));
    fprintf(fid, '- Next: **`%s`** — %s\n', Next.decision, Next.detail);
    if ~isempty(alt.name)
        fprintf(fid, '- Alt (bounded, not sweep): **`%s`** — %s\n', alt.name, alt.detail);
    end
    fprintf(fid, '- Artifacts: suite_results/DEPTH_TO_GAMMA_CANDIDATE.{md,mat,png}; helper `guidance_law_depth_to_gamma.m`; driver `run_depth_to_gamma_candidate.m`.\n');
    fprintf(fid, '- CODEX_VERTICAL_PLAN untouched.\n');
    fclose(fid);
end

%% ===================== numeric utils =====================
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

function y = align_len(x, n)
    x = x(:);
    if numel(x) >= n
        y = x(1:n);
    else
        y = [x; zeros(n - numel(x), 1)];
    end
end

function v = mean_safe(x, mask)
    x = x(:); mask = logical(mask(:));
    if ~any(mask); v = NaN; return; end
    v = mean(x(mask));
end

function v = max_safe(x, mask)
    x = x(:); mask = logical(mask(:));
    if ~any(mask); v = NaN; return; end
    v = max(x(mask));
end

function v = rms_safe(x)
    x = x(:); x = x(isfinite(x));
    if isempty(x); v = NaN; return; end
    v = sqrt(mean(x.^2));
end

function v = prctile_local(x, p)
    x = x(:); x = x(isfinite(x));
    x = sort(x);
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

function s = sanitize(s)
    if isempty(s); s = ''; return; end
    s = regexprep(char(s), '[|]', '/');
    if numel(s) > 60; s = [s(1:57) '...']; end
end
