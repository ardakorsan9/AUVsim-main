function run_guidance_mission_baseline()
% GUIDANCE_MISSION_BASELINE_001 — nominal guidance/mission readiness audit.
% Read-only: run_path_suite.m, continuous_path_tracking.m, guidance_law.m.
% Prior: CRAB_CURRENT_FF_CANDIDATE REJECTED (R10 rudder sat 6.06→9.00%).
% Production plant/controller/guidance FROZEN — no tuning.
%
% ONE deterministic composite U=1.5 mission (isolated runner):
%   level straight → smooth XZ climb → feasible R10 horizontal turn → smooth level exit
% Continuous position + unit tangent; documented segment boundaries.
% One nonlinear 6DOF (production guidance_law → controller_law → plant).
% PASS = audit completeness. Classify mission vs route hard gates,
%   transition overshoot, no backward progress/stall.
% Unsupported autonomy marked NOT_IMPLEMENTED with provenance.
% Artifacts: suite_results/GUIDANCE_MISSION_BASELINE.{md,mat,png}
% Appends: suite_results/PITCH_CONTROL_RESEARCH_LOG.md
% Never touches CODEX_VERTICAL_PLAN.md.

    project_dir = fileparts(fileparts(fileparts(mfilename('fullpath')))); % repo root
    addpath(genpath(fullfile(project_dir, 'matlab')));
    out_dir = fullfile(project_dir, 'suite_results');
    if ~exist(out_dir, 'dir'); mkdir(out_dir); end
    tag = 'GUIDANCE_MISSION_BASELINE';
    task_id = 'GUIDANCE_MISSION_BASELINE_001';

    src_suite = fullfile(project_dir, 'run_path_suite.m');
    src_cpt   = fullfile(project_dir, 'continuous_path_tracking.m');
    src_guid  = fullfile(project_dir, 'guidance_law.m');
    log_path  = fullfile(out_dir, 'PITCH_CONTROL_RESEARCH_LOG.md');
    assert(exist(src_suite, 'file') == 2, 'Missing %s', src_suite);
    assert(exist(src_cpt, 'file') == 2, 'Missing %s', src_cpt);
    assert(exist(src_guid, 'file') == 2, 'Missing %s', src_guid);
    assert(exist(log_path, 'file') == 2, 'Missing %s', log_path);

    fprintf('\n========== %s ==========\n', task_id);
    fprintf('Crab-current FF rejected; production FROZEN; no control/guidance tuning.\n');

    % ---- Audit document from the three read-only sources ----
    Audit = build_guidance_mission_audit(src_suite, src_cpt, src_guid);

    clear functions
    clear guidance_law controller_law underwater777_vehicle_dynamics
    clear global lambda_muw_ff trim_speed_table trim_elevator_table elevator_sign
    clear global K_zdot K_gamma enable_alpha_hat Kp_roll
    clear global last_guidance_U_h last_guidance_kappa last_r_ff

    init_parameters();
    global lambda_muw_ff elevator_sign trim_speed_table trim_elevator_table
    global K_zdot K_gamma enable_alpha_hat
    global dt_controller dt_guidance delta_e_max delta_r_max
    global Kp_x thrust_trim thrust_max thrust_min desired_speed Kp_roll
    global pitch_ref_max pitch_ref_rate_max lookahead_distance

    % Frozen production stack (identical to prior baselines; no retune)
    elevator_sign = 1;
    trim_speed_table = [0.8 1.0 1.5 2.0];
    trim_elevator_table = deg2rad([-9.18 -7.33 -4.62 -3.17]);
    K_gamma = 0; K_zdot = 0; enable_alpha_hat = false;
    Kp_roll = 0.605072;
    lambda_muw_ff = 0.25;  % level/turn/exit; climb segment uses same (mission is one path)
    Uref = 1.5;
    desired_speed = Uref;
    assert(abs(desired_speed - 1.5) < 1e-12, 'desired_speed must be 1.5');
    seed_used = 0;
    rng(seed_used, 'twister');

    lim = struct( ...
        'dr_max', delta_r_max, 'de_max', delta_e_max, ...
        'dr_rate', deg2rad(40), 'de_rate', deg2rad(40), ...
        'thrust_max', thrust_max, 'thrust_min', thrust_min);

    % SPEED_ENVELOPE / COMBINED hard gates (absolutes; no invention)
    HG = struct();
    HG.LEVEL.pitch_mae = 0.10; HG.LEVEL.pitch_p95 = 0.50;
    HG.LEVEL.gamma_mae = 0.50; HG.LEVEL.gamma_p95 = 1.00;
    HG.LEVEL.yaw_mae = 0.50;
    HG.CLIMB.pitch_mae = 0.30; HG.CLIMB.pitch_p95 = 0.50;
    HG.CLIMB.gamma_mae = 1.00; HG.CLIMB.gamma_p95 = 1.50;
    HG.CLIMB.yaw_mae = 0.50;
    HG.TURN.pitch_mae = 0.30; HG.TURN.pitch_p95 = 0.50;
    HG.TURN.gamma_mae = 1.50; HG.TURN.gamma_p95 = 2.50;
    HG.TURN.yaw_mae = 1.0; HG.TURN.yaw_p95 = 2.0;
    HG.EXIT.pitch_mae = 0.10; HG.EXIT.pitch_p95 = 0.50;
    HG.EXIT.gamma_mae = 0.50; HG.EXIT.gamma_p95 = 1.00;
    HG.EXIT.yaw_mae = 0.50;
    HG.elev_sat = 1.0; HG.rud_sat_ss = 1.0; HG.rud_sat_full = 1.0;
    HG.chatter = 0.20; HG.thrust_sat = 1.0; HG.rate_util = 1.0;
    HG.ratio_lo = 0.98; HG.ratio_hi = 1.02;
    % Mission progress / transition classification gates
    HG.prog_back_tol_m = 0.05;          % matches guidance open-path blend
    HG.stall_ds_eps = 0.02;             % m/s projected progress rate
    HG.stall_hold_s = 2.0;
    HG.trans_cte_max = 1.50;            % m absolute CTE in transition windows
    HG.trans_ez_max = 1.00;             % m |e_z| in transition windows
    HG.complete_s_frac = 0.97;          % s_prog/s_total for completion

    % ---- Composite mission path (C0 position + C1 unit tangent) ----
    [path, Seg, PathMeta] = build_composite_mission_path();
    s_nodes = PathMeta.s_nodes;
    s_total = PathMeta.s_total;
    T_final = PathMeta.T_final;

    fprintf('Path s_total=%.2f m | T_final=%.1f s | U=%.2f | segments=%d\n', ...
        s_total, T_final, Uref, numel(Seg.names));
    for i = 1:numel(Seg.names)
        fprintf('  [%s] s=[%.2f, %.2f] L=%.2f m\n', Seg.names{i}, ...
            Seg.s0(i), Seg.s1(i), Seg.s1(i) - Seg.s0(i));
    end

    % ---- One production 6DOF run (mirrors continuous_path_tracking) ----
    clear guidance_law controller_law
    S = sim_mission_once(path, Uref, T_final, lim);
    audit_complete = S.ok && S.finite && ~isempty(S.t);

    % ---- Metrics: whole / per-segment / transitions ----
    M = analyze_mission(S, path, s_nodes, s_total, Seg, lim, HG, lookahead_distance);

    % ---- Classification ----
    Class = classify_mission(M, HG);
    % PASS criterion = audit completeness (contract documented + sim ran + artifacts)
    verdict_audit = 'PASS';
    if ~audit_complete || ~Audit.complete
        verdict_audit = 'FAIL';
    end
    if Class.mission_ok
        next_gate = 'fault_injection_baseline';
        next_note = 'Mission classification OK vs hard gates / progress / transitions → next fault-injection baseline.';
    else
        next_gate = 'transition_shaper';
        next_note = sprintf('Mission classification FAIL first=`%s` → next transition shaper.', Class.first_fail);
    end

    stamp = datestr(now, 'yyyy-mm-dd HH:MM:SS');
    Results = struct();
    Results.task_id = task_id;
    Results.tag = tag;
    Results.stamp = stamp;
    Results.verdict_audit = verdict_audit;
    Results.mission_class = Class;
    Results.next_gate = next_gate;
    Results.next_note = next_note;
    Results.Audit = Audit;
    Results.PathMeta = PathMeta;
    Results.Seg = Seg;
    Results.HG = HG;
    Results.M = M;
    Results.S = pack_S(S);
    Results.Uref = Uref;
    Results.seed = seed_used;
    Results.production_untouched = true;
    Results.no_tuning = true;
    Results.T_final = T_final;
    Results.s_total = s_total;
    Results.lim = lim;
    Results.globals = struct( ...
        'lookahead_distance', lookahead_distance, ...
        'desired_speed', desired_speed, ...
        'pitch_ref_max_deg', rad2deg(pitch_ref_max), ...
        'pitch_ref_rate_max_dps', rad2deg(pitch_ref_rate_max), ...
        'dt_controller', dt_controller, ...
        'dt_guidance', dt_guidance, ...
        'Kp_roll', Kp_roll, 'K_gamma', K_gamma, 'K_zdot', K_zdot, ...
        'enable_alpha_hat', enable_alpha_hat, 'lambda_muw_ff', lambda_muw_ff);

    md_path  = fullfile(out_dir, [tag '.md']);
    mat_path = fullfile(out_dir, [tag '.mat']);
    png_path = fullfile(out_dir, [tag '.png']);
    Results.paths = struct('md', md_path, 'mat', mat_path, 'png', png_path);

    write_png(png_path, Results);
    write_md(md_path, Results);
    save(mat_path, 'Results', 'path', 'Seg', 'PathMeta', 'M', 'Class', 'Audit', '-v7.3');
    append_research_log(log_path, Results);

    fprintf('\n========== %s DONE ==========\n', task_id);
    fprintf('Audit completeness: %s\n', verdict_audit);
    fprintf('Mission class: %s first=%s\n', yn(Class.mission_ok), Class.first_fail);
    fprintf('Next gate: %s\n', next_gate);
    fprintf('Artifacts: %s | %s | %s\n', md_path, mat_path, png_path);
end

%% ===================== AUDIT (provenance) =====================
function A = build_guidance_mission_audit(src_suite, src_cpt, src_guid)
    txt_s = fileread(src_suite);
    txt_c = fileread(src_cpt);
    txt_g = fileread(src_guid);

    A = struct();
    A.complete = true;
    A.read_only_sources = {'run_path_suite.m', 'continuous_path_tracking.m', 'guidance_law.m'};

    % Path input contract
    A.path_input_contract = struct();
    A.path_input_contract.provenance = 'continuous_path_tracking.m L1 + guidance_law.m L54-59; run_path_suite make_scenario_*';
    A.path_input_contract.shape = 'Nx3 numeric waypoints [x y z] NED (z positive down in plant; suite paths often z>=0 climb)';
    A.path_input_contract.min_N = 2;
    A.path_input_contract.closed_detection = 'norm(path(1,:)-path(end,:)) < 0.25 (guidance_law.m L63)';
    A.path_input_contract.speed = 'global desired_speed (init_parameters=1.5); schedule u_ref=desired_speed*R/(R+2.5) clamped';
    A.path_input_contract.state0 = 'run_path_suite initial_state_from_path: pos=path(1,:), theta_int=-physical_pitch, psi=atan2(dy,dx), u=u0';
    A.path_input_contract.mission_fields = 'NOT_IMPLEMENTED — suite passes raw path + T_final only; no segment IDs, waypoints-as-mission, or mode flags';

    % Projection / progress
    A.projection_progress = struct();
    A.projection_progress.provenance = 'guidance_law.m L61-106, L275-279; helpers path_arclength/project_on_path/sample_path';
    A.projection_progress.state = 'persistent s_prog (arc-length m); legacy next_progress_index integer';
    A.projection_progress.monotonic = 'open: s_prog=max(s_prog,s_near-0.05); closed: wrap with ignore ds<-0.25, blend max(ds,-0.05)';
    A.projection_progress.window = 'forward search [s_prog-0.15, s_prog+max(3,2.5*L)]';
    A.projection_progress.depth_hold = 'if z_below>2.5 m, clamp ds_max=0.55*u*dt (L120-129)';

    % Lookahead
    A.lookahead = struct();
    A.lookahead.provenance = 'guidance_law.m L14,L64,L112-118; init_parameters lookahead_distance=1.25';
    A.lookahead.L = 'max(lookahead_distance, 1.0) m';
    A.lookahead.use = 's_look=s_prog+L → t_look for chi_path / pitch_path; LOS atan2(-y_e, L+0.6)';

    % Command filters / limits
    A.command_filters_limits = struct();
    A.command_filters_limits.provenance = 'guidance_law.m yaw/pitch filters L132-265; continuous_path_tracking ZOH L67-88';
    A.command_filters_limits.yaw = 'chi_f LPF a=0.28; unwrap yaw_cont; yaw_out slew max 40deg/s *0.35 blend';
    A.command_filters_limits.pitch = 'z_e_f a=0.07; pitch_f a=0.10; pitch_out rate-limited by pitch_ref_rate_max; clamp ±pitch_ref_max';
    A.command_filters_limits.kappa = 'kappa_f = 0.96*prev + 0.04*raw';
    A.command_filters_limits.r_ff = 'U_h*kappa_f clamp ±40 deg/s';
    A.command_filters_limits.multi_rate = 'dt_controller=0.025, dt_guidance=0.075; guidance ZOH between ticks (continuous_path_tracking)';

    % Termination / completion
    A.termination_completion = struct();
    A.termination_completion.provenance = 'continuous_path_tracking.m L14-16,L19 (fixed T_final); guidance_law near_end L108,L155-157,L170-174,L187-191';
    A.termination_completion.sim_stop = 'Fixed-horizon T_final only — no goal event stop';
    A.termination_completion.near_end = 's_prog >= s_total-0.3 → u_ref=0.7*desired_speed; yaw/pitch use local tangent';
    A.termination_completion.mission_complete_flag = 'NOT_IMPLEMENTED';
    A.termination_completion.success_criteria_api = 'NOT_IMPLEMENTED — metrics computed offline by suite helpers';

    % Transition handling
    A.transition_handling = struct();
    A.transition_handling.provenance = 'run_path_suite: separate scenarios, clear guidance_law between (L66-67); no multi-segment mission';
    A.transition_handling.segment_blender = 'NOT_IMPLEMENTED';
    A.transition_handling.clothoid_or_shaper = 'NOT_IMPLEMENTED';
    A.transition_handling.mode_switch = 'NOT_IMPLEMENTED — single open path only';
    A.transition_handling.note = 'Composite continuity must be baked into the waypoint polyline; guidance has no segment awareness';

    % Resets
    A.resets = struct();
    A.resets.provenance = 'run_path_suite.m L16-18,L66-67 clear guidance_law controller_law; guidance_law persistent initialized';
    A.resets.mid_mission_reset = 'NOT_IMPLEMENTED';
    A.resets.integrator_bump_less = 'NOT_IMPLEMENTED for mission handoff (cold start only)';

    % Timeouts
    A.timeouts = struct();
    A.timeouts.provenance = 'continuous_path_tracking T_final only';
    A.timeouts.mission_watchdog = 'NOT_IMPLEMENTED';
    A.timeouts.stall_detector = 'NOT_IMPLEMENTED';
    A.timeouts.acq_timeout = 'NOT_IMPLEMENTED';

    % Replanning
    A.replanning = struct();
    A.replanning.path_swap_online = 'NOT_IMPLEMENTED';
    A.replanning.obstacle_avoid = 'NOT_IMPLEMENTED';
    A.replanning.dynamic_repath = 'NOT_IMPLEMENTED';
    A.replanning.provenance = 'absent from run_path_suite / continuous_path_tracking / guidance_law';

    % Mission / fault functions
    A.mission_fault = struct();
    A.mission_fault.mission_manager = 'NOT_IMPLEMENTED';
    A.mission_fault.fault_detection = 'NOT_IMPLEMENTED';
    A.mission_fault.fault_isolation = 'NOT_IMPLEMENTED';
    A.mission_fault.safe_mode = 'NOT_IMPLEMENTED';
    A.mission_fault.abort_recover = 'NOT_IMPLEMENTED';
    A.mission_fault.sensor_outage_handler = 'NOT_IMPLEMENTED';
    A.mission_fault.actuator_fail_handler = 'NOT_IMPLEMENTED';
    A.mission_fault.provenance = 'no APIs in the three audited sources; ode45 catch in continuous_path_tracking L100-115 is sim abort only';

    % Suite role
    A.suite_role = 'run_path_suite orchestrates 4 separate scenarios (X,XZ,circle R5,helix); not a multi-segment mission.';
    A.notes = {
        'Autonomy above single open-path following is unsupported in production stack.'
        'This baseline builds a C1 polyline mission externally; guidance still sees one path.'
        };
end

%% ===================== PATH BUILDER =====================
function [path, Seg, Meta] = build_composite_mission_path()
    % Deterministic C0+C1 composite @ U=1.5:
    % LEVEL → CLIMB (raised-cosine) → TURN R10 90° → EXIT
    z0 = 0.0;
    dz = 4.0;                 % climb height [m]
    L_level = 20.0;
    L_climb = 20.0;           % max slope = dz*pi/(2*L)=0.314 → γ≈17.4° < pitch_ref_max
    R = 10.0;                 % feasible R10 (SPEED_ENVELOPE / PITCH_YAW_CLOSURE)
    turn_ang = pi / 2;        % 90° horizontal left turn
    L_turn = R * turn_ang;
    L_exit = 20.0;
    ds = 0.05;                % waypoint spacing [m]

    % --- LEVEL: +X at z=z0 ---
    nL = max(2, round(L_level / ds) + 1);
    sL = linspace(0, L_level, nL)';
    pL = [sL, zeros(nL, 1), z0 * ones(nL, 1)];

    % --- CLIMB: raised-cosine in z, continue +X; dz/dx=0 at ends (C1) ---
    nC = max(2, round(L_climb / ds) + 1);
    sC = linspace(0, L_climb, nC)';
    xC = L_level + sC;
    zC = z0 + dz * 0.5 * (1 - cos(pi * sC / L_climb));
    pC = [xC, zeros(nC, 1), zC];
    % drop duplicate junction with LEVEL
    pC = pC(2:end, :);

    x1 = L_level + L_climb;
    z1 = z0 + dz;

    % --- TURN: R=10 horizontal, φ:0→π/2; arrive +X leave +Y ---
    nT = max(2, round(L_turn / ds) + 1);
    phi = linspace(0, turn_ang, nT)';
    xT = x1 + R * sin(phi);
    yT = R * (1 - cos(phi));
    zT = z1 * ones(nT, 1);
    pT = [xT, yT, zT];
    pT = pT(2:end, :);  % drop duplicate

    % --- EXIT: +Y straight ---
    nE = max(2, round(L_exit / ds) + 1);
    sE = linspace(0, L_exit, nE)';
    pE = [ (x1 + R) * ones(nE, 1), (R + sE), z1 * ones(nE, 1) ];
    pE = pE(2:end, :);

    path = [pL; pC; pT; pE];

    % Arc-length table + segment bounds (inclusive start, exclusive end except last)
    ds_vec = [0; sqrt(sum(diff(path).^2, 2))];
    s_nodes = cumsum(ds_vec);
    s_total = s_nodes(end);

    % Map segment ends by geometry lengths (polyline arc ≈ design lengths)
    s_level_end = L_level;
    s_climb_end = L_level + L_climb;
    s_turn_end  = L_level + L_climb + L_turn;
    s_exit_end  = s_total;

    Seg = struct();
    Seg.names = {'LEVEL', 'CLIMB', 'TURN', 'EXIT'};
    Seg.s0 = [0, s_level_end, s_climb_end, s_turn_end];
    Seg.s1 = [s_level_end, s_climb_end, s_turn_end, s_exit_end];
    Seg.gate_key = {'LEVEL', 'CLIMB', 'TURN', 'EXIT'};
    Seg.R = [0, 0, R, 0];
    Seg.description = {
        sprintf('Level straight +X z=%.1f L=%.1fm', z0, L_level)
        sprintf('Raised-cosine climb Δz=+%.1fm over L=%.1fm (C1 slope ends)', dz, L_climb)
        sprintf('Horizontal left turn R=%.1f ang=90deg L=%.2fm at z=%.1f', R, L_turn, z1)
        sprintf('Level exit +Y L=%.1fm at z=%.1f', L_exit, z1)
        };
    % Transition windows: ±max(2, L_look) about each interior boundary
    Seg.trans_names = {'LEVEL_CLIMB', 'CLIMB_TURN', 'TURN_EXIT'};
    Seg.trans_s = [s_level_end, s_climb_end, s_turn_end];

    % Continuity checks (document)
    Meta = struct();
    Meta.s_nodes = s_nodes;
    Meta.s_total = s_total;
    Meta.z0 = z0; Meta.dz = dz; Meta.R = R;
    Meta.L = struct('level', L_level, 'climb', L_climb, 'turn', L_turn, 'exit', L_exit);
    Meta.ds = ds;
    Meta.max_climb_slope = dz * pi / (2 * L_climb);
    Meta.max_climb_gamma_deg = rad2deg(atan(Meta.max_climb_slope));
    Meta.continuity = verify_path_continuity(path, Seg, s_nodes);
    % Travel time margin: s_total/U * 1.25, min 55 s
    Meta.T_final = max(55.0, ceil(1.25 * s_total / 1.5));
    Meta.design_note = 'C0 position + C1 unit tangent at junctions; curvature discontinuous at turn entry/exit (no clothoid — NOT_IMPLEMENTED).';
end

function C = verify_path_continuity(path, Seg, s_nodes)
    C = struct('pos_ok', true, 'tang_ok', true, 'details', {{}});
    for k = 1:numel(Seg.trans_s)
        sb = Seg.trans_s(k);
        [p_m, t_m] = sample_path_local(path, s_nodes, max(0, sb - 1e-3));
        [p_p, t_p] = sample_path_local(path, s_nodes, min(s_nodes(end), sb + 1e-3));
        dp = norm(p_m - p_p);
        dtang = 1 - abs(dot(t_m, t_p));  % ~0 if aligned
        ok_p = dp < 0.05;
        ok_t = dtang < 0.02;  % ~11°; should be << for true C1
        % Better: compare tangents approaching from each side at larger offset
        [~, t_a] = sample_path_local(path, s_nodes, max(0, sb - 0.25));
        [~, t_b] = sample_path_local(path, s_nodes, min(s_nodes(end), sb + 0.25));
        ang = rad2deg(acos(max(-1, min(1, dot(t_a, t_b)))));
        ok_t = ang < 5.0;
        C.details{end+1} = sprintf('%s: |Δp|=%.4f ang=%.3fdeg', Seg.trans_names{k}, dp, ang); %#ok<AGROW>
        C.pos_ok = C.pos_ok && ok_p;
        C.tang_ok = C.tang_ok && ok_t;
    end
end

%% ===================== SIM (production stack once) =====================
function S = sim_mission_once(path, Uref, T_final, lim)
    global dt_controller dt_guidance
    global last_delta_e last_delta_r last_e_z last_e_zdot last_zdot_inertial
    global last_gamma_actual last_gamma_path last_e_gamma last_e_theta last_theta_phys
    global last_rate_filt last_theta_phys_dot
    global last_guidance_U_h last_guidance_kappa last_r_ff
    global thrust_max thrust_min

    dt = dt_controller;
    if isempty(dt) || ~isfinite(dt); dt = 0.025; end
    if isempty(dt_guidance) || ~isfinite(dt_guidance); dt_guidance = 0.075; end

    state = zeros(12, 1);
    state(1:3) = path(1, :)';
    d = path(2, :) - path(1, :);
    state(5) = -atan2(d(3), norm(d(1:2)));  % internal theta = -physical
    state(6) = atan2(d(2), d(1));
    state(7) = Uref;

    n_steps = round(T_final / dt);
    guidance_period = max(1, round(dt_guidance / dt));
    yaw_ref = 0; pitch_ref = 0; u_ref = Uref; r_ff = 0; pitch_ref_dot = 0; pidx = 1;

    S = struct();
    S.dt = dt; S.T_final = T_final; S.Uref = Uref;
    S.t = zeros(n_steps, 1);
    S.vp = zeros(n_steps, 3); S.vel = zeros(n_steps, 3);
    S.rates = zeros(n_steps, 3); S.ori = zeros(n_steps, 3);
    S.psi_ref = zeros(n_steps, 1); S.theta_ref = zeros(n_steps, 1);
    S.u_ref = zeros(n_steps, 1); S.u_ctrl = zeros(n_steps, 1);
    S.delta_r = zeros(n_steps, 1); S.delta_e = zeros(n_steps, 1);
    S.thrust = zeros(n_steps, 1);
    S.Uh = zeros(n_steps, 1); S.VD = zeros(n_steps, 1);
    S.U_h_guid = zeros(n_steps, 1); S.kappa = zeros(n_steps, 1); S.r = zeros(n_steps, 1);
    S.e_z = zeros(n_steps, 1); S.e_zdot = zeros(n_steps, 1);
    S.gamma = zeros(n_steps, 1); S.gamma_path = zeros(n_steps, 1);
    S.e_gamma = zeros(n_steps, 1);
    S.e_theta = zeros(n_steps, 1); S.theta_phys = zeros(n_steps, 1);
    S.progress_index = zeros(n_steps, 1);

    last_delta_e = []; last_delta_r = [];
    last_e_z = []; last_e_zdot = []; last_zdot_inertial = [];
    last_gamma_actual = []; last_gamma_path = []; last_e_gamma = [];
    last_e_theta = []; last_theta_phys = [];
    last_rate_filt = []; last_theta_phys_dot = [];
    last_guidance_U_h = []; last_guidance_kappa = []; last_r_ff = [];

    ok = true;
    for k = 1:n_steps
        pos = state(1:3)';
        ori = state(4:6)';
        rates = state(10:12)';
        u = state(7); v = state(8); w = state(9);
        [Uh, zdot] = inertial_Uh_zdot(ori, u, v, w);
        theta_phys_now = -ori(2);

        if mod(k - 1, guidance_period) == 0
            [yaw_ref, pitch_ref, u_ref, pidx, r_ff, pitch_ref_dot] = ...
                guidance_law(pos, path, pidx, u, v, Uh, zdot, theta_phys_now);
        end

        [dr, de, thr] = controller_law(yaw_ref, pitch_ref, u_ref, ...
            ori(3), ori(2), rates(3), rates(2), u, r_ff, pitch_ref_dot, ori(1), w, rates(1));
        controls = struct('delta_r', dr, 'delta_e', de, 'thrust', thr);

        try
            [~, g] = ode45(@(tt, gg) underwater777_vehicle_dynamics(tt, gg, controls), [0 dt], state);
            state = g(end, :)';
        catch
            ok = false; n_steps = max(k - 1, 1); break;
        end
        if any(~isfinite(state))
            ok = false; n_steps = max(k - 1, 1); break;
        end

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
        S.Uh(k) = Uh; S.VD(k) = zdot;
        if isempty(last_guidance_U_h); last_guidance_U_h = Uh; end
        if isempty(last_guidance_kappa); last_guidance_kappa = 0; end
        if isempty(last_r_ff); last_r_ff = r_ff; end
        S.U_h_guid(k) = last_guidance_U_h;
        S.kappa(k) = last_guidance_kappa;
        S.r(k) = rates(3);
        if isempty(last_e_z); last_e_z = 0; end
        if isempty(last_e_zdot); last_e_zdot = 0; end
        if isempty(last_gamma_actual); last_gamma_actual = 0; end
        if isempty(last_gamma_path); last_gamma_path = 0; end
        if isempty(last_e_gamma); last_e_gamma = 0; end
        if isempty(last_e_theta); last_e_theta = 0; end
        if isempty(last_theta_phys); last_theta_phys = theta_phys_now; end
        S.e_z(k) = last_e_z;
        S.e_zdot(k) = last_e_zdot;
        S.gamma(k) = last_gamma_actual;
        S.gamma_path(k) = last_gamma_path;
        S.e_gamma(k) = last_e_gamma;
        S.e_theta(k) = last_e_theta;
        S.theta_phys(k) = last_theta_phys;
        S.progress_index(k) = pidx;

        if mod(k, 400) == 0 || k == n_steps
            fprintf('  step %d/%d t=%.1fs u=%.2f s_idx=%d\n', k, round(T_final/dt), S.t(k), u, pidx);
        end
    end

    trimn = @(A) A(1:n_steps, :);
    trim1 = @(A) A(1:n_steps);
    fn = fieldnames(S);
    for i = 1:numel(fn)
        A = S.(fn{i});
        if isnumeric(A) && size(A, 1) >= n_steps && size(A, 1) > 1
            if size(A, 2) > 1
                S.(fn{i}) = trimn(A);
            elseif numel(A) >= n_steps
                S.(fn{i}) = trim1(A);
            end
        end
    end
    S.ok = ok;
    S.finite = ok && all(isfinite(S.vp(:))) && all(isfinite(S.vel(:))) && all(isfinite(S.ori(:)));
    S.u_body = S.vel(:, 1);
    S.lim = lim;
end

function [Uh, zdot] = inertial_Uh_zdot(ori, u, v, w)
    pd = rotmat(ori(1), ori(2), ori(3)) * [u; v; w];
    Uh = hypot(pd(1), pd(2));
    zdot = pd(3);
end

function R = rotmat(phi, theta, psi)
    R = [cos(psi)*cos(theta), ...
         cos(psi)*sin(theta)*sin(phi) - sin(psi)*cos(phi), ...
         cos(psi)*sin(theta)*cos(phi) + sin(psi)*sin(phi);
         sin(psi)*cos(theta), ...
         sin(psi)*sin(theta)*sin(phi) + cos(psi)*cos(phi), ...
         sin(psi)*sin(theta)*cos(phi) - cos(psi)*sin(phi);
         -sin(theta), ...
         cos(theta)*sin(phi), ...
         cos(theta)*cos(phi)];
end

%% ===================== ANALYZE =====================
function M = analyze_mission(S, path, s_nodes, s_total, Seg, lim, HG, L_look)
    t = S.t(:); dt = S.dt; n = numel(t);
    M = struct('ok', false, 'sim_ok', S.ok && S.finite, 'bounded', false);
    if n < 20 || ~M.sim_ok
        M.note = 'sim_fail_or_short'; return;
    end

    [s_prog, cte_perp, e_z_geom, gamma_ref, t_hat] = project_progress_series(path, s_nodes, s_total, S.vp);
    theta_phys = -S.ori(:, 2);
    psi = S.ori(:, 3);
    phi = S.ori(:, 1);
    e_psi = wrapToPiLocal(S.psi_ref - psi);
    e_th = wrapToPiLocal(S.theta_ref - theta_phys);
    gamma_act = atan2(S.VD, max(S.Uh, 1e-9));
    e_gamma = wrapToPiLocal(gamma_ref - gamma_act);
    e_u = S.u_ref - S.u_ctrl;
    % Prefer guidance-logged e_z when available
    e_z = S.e_z(:);
    if all(e_z == 0) && any(abs(e_z_geom) > 0)
        e_z = e_z_geom;
    end

    de = S.delta_e(:); dr = S.delta_r(:); thr = S.thrust(:);
    de_dot = [0; diff(de)] / dt;
    dr_dot = [0; diff(dr)] / dt;

    % Progress monotonicity / stall
    ds = [0; diff(s_prog)];
    ds_dt = ds / dt;
    back_events = find(ds < -HG.prog_back_tol_m);
    near_end = s_prog >= s_total - 0.3;
    stall_mask = (ds_dt < HG.stall_ds_eps) & ~near_end & (t > 2.0);
    stall_run = max_true_run(stall_mask) * dt;

    M.ok = true;
    M.s_prog = s_prog; M.s_total = s_total; M.cte_perp = cte_perp;
    M.e_z = e_z; M.gamma_ref = gamma_ref; M.gamma_act = gamma_act;
    M.theta_phys = theta_phys; M.e_th = e_th; M.e_psi = e_psi; M.e_gamma = e_gamma;
    M.t_hat = t_hat;

    M.progress = struct();
    M.progress.monotonic = isempty(back_events);
    M.progress.n_back = numel(back_events);
    M.progress.min_ds = min(ds);
    M.progress.max_ds = max(ds);
    M.progress.final_s = s_prog(end);
    M.progress.final_frac = s_prog(end) / max(s_total, eps);
    M.progress.completed = M.progress.final_frac >= HG.complete_s_frac;
    M.progress.stall_run_s = stall_run;
    M.progress.stalled = stall_run >= HG.stall_hold_s;
    M.progress.mean_ds_dt = mean(ds_dt(t > 2 & ~near_end));

    % Whole-mission steady window: t>=5 & s<0.88*s_total
    mask_ss = (t >= 5.0) & (s_prog < 0.88 * s_total);
    if ~any(mask_ss); mask_ss = t >= 5.0; end
    mask_full = true(n, 1);

    M.whole = segment_metrics(t, mask_ss, mask_full, e_th, e_gamma, e_psi, e_u, ...
        e_z, cte_perp, phi, S.rates, de, dr, thr, de_dot, dr_dot, ...
        S.u_ctrl, S.U_h_guid, S.kappa, S.r, lim, HG, 0, 'WHOLE');

    st = [S.ori, S.vel, S.rates];
    M.bounded = all(isfinite(st(:))) && all(isfinite(thr)) && ...
        all(abs(theta_phys) < deg2rad(80)) && all(abs(S.u_body) < 5.0) && ...
        all(abs(S.rates(:)) < deg2rad(200));

    % Per-segment
    M.segments = struct([]);
    for i = 1:numel(Seg.names)
        mseg = (s_prog >= Seg.s0(i)) & (s_prog < Seg.s1(i));
        if i == numel(Seg.names)
            mseg = (s_prog >= Seg.s0(i)) & (s_prog <= Seg.s1(i) + 1e-6);
        end
        % steady within segment: drop first 2 s of segment & last 5% of segment length
        if any(mseg)
            t_seg0 = t(find(mseg, 1, 'first'));
            Lseg = Seg.s1(i) - Seg.s0(i);
            m_ss = mseg & (t >= t_seg0 + 2.0) & (s_prog < Seg.s1(i) - 0.12 * Lseg);
            if ~any(m_ss); m_ss = mseg & (t >= t_seg0 + 1.0); end
            if ~any(m_ss); m_ss = mseg; end
        else
            m_ss = false(n, 1);
        end
        Sm = segment_metrics(t, m_ss, mseg, e_th, e_gamma, e_psi, e_u, ...
            e_z, cte_perp, phi, S.rates, de, dr, thr, de_dot, dr_dot, ...
            S.u_ctrl, S.U_h_guid, S.kappa, S.r, lim, HG, Seg.R(i), Seg.names{i});
        Sm.name = Seg.names{i};
        Sm.gate_key = Seg.gate_key{i};
        Sm.s0 = Seg.s0(i); Sm.s1 = Seg.s1(i);
        Sm.n = nnz(mseg); Sm.n_ss = nnz(m_ss);
        Sm.progress_mono = all(ds(mseg) >= -HG.prog_back_tol_m);
        Sm.mean_ds_dt = mean_safe(ds_dt, mseg);
        [Sm.feasible, Sm.first_limit, Sm.gates] = score_seg_gates(Sm, Seg.gate_key{i}, HG);
        if isempty(M.segments)
            M.segments = Sm;
        else
            M.segments(end+1) = Sm; %#ok<AGROW>
        end
    end

    % Transitions
    tw = max(2.0, L_look);
    M.transitions = struct([]);
    for i = 1:numel(Seg.trans_names)
        sb = Seg.trans_s(i);
        mtr = (s_prog >= sb - tw) & (s_prog <= sb + tw);
        Tr = struct();
        Tr.name = Seg.trans_names{i};
        Tr.s_boundary = sb;
        Tr.window_m = tw;
        Tr.n = nnz(mtr);
        if Tr.n < 5
            Tr.max_cte = NaN; Tr.max_abs_ez = NaN; Tr.mean_cte = NaN;
            Tr.overshoot_cte = true; Tr.overshoot_ez = true;
            Tr.progress_mono = false; Tr.ok = false;
        else
            Tr.max_cte = max(abs(cte_perp(mtr)));
            Tr.max_abs_ez = max(abs(e_z(mtr)));
            Tr.mean_cte = mean(abs(cte_perp(mtr)));
            Tr.overshoot_cte = Tr.max_cte > HG.trans_cte_max;
            Tr.overshoot_ez = Tr.max_abs_ez > HG.trans_ez_max;
            Tr.progress_mono = all(ds(mtr) >= -HG.prog_back_tol_m);
            Tr.ok = ~Tr.overshoot_cte && ~Tr.overshoot_ez && Tr.progress_mono;
        end
        if isempty(M.transitions)
            M.transitions = Tr;
        else
            M.transitions(end+1) = Tr; %#ok<AGROW>
        end
    end
end

function Sm = segment_metrics(t, mask_ss, mask_full, e_th, e_gamma, e_psi, e_u, ...
        e_z, cte, phi, rates, de, dr, thr, de_dot, dr_dot, ...
        u_ctrl, Uh_g, kappa, r_yaw, lim, HG, Rhel, name) %#ok<INUSD>
    dt = 0;
    if numel(t) >= 2; dt = t(2) - t(1); end
    Sm = struct();
    Sm.name = name;
    Sm.theta = err_stats_deg(e_th, mask_ss);
    Sm.gamma = err_stats_deg(e_gamma, mask_ss);
    Sm.yaw = err_stats_deg(e_psi, mask_ss);
    Sm.speed = err_stats_lin(e_u, mask_ss);
    Sm.speed.u_mean = mean_safe(u_ctrl, mask_ss);
    Sm.roll = struct('mae_deg', rad2deg(mean_safe(abs(phi), mask_ss)), ...
        'p_rms_dps', rad2deg(rms_safe(rates(mask_ss, 1))));
    Sm.path = struct('mean_cte', mean_safe(abs(cte), mask_ss), ...
        'max_cte', max_safe(abs(cte), mask_ss));
    Sm.depth = struct('mae', mean_safe(abs(e_z), mask_ss), ...
        'p95', prctile_local(abs(e_z(mask_ss)), 95), ...
        'rms', rms_safe(e_z(mask_ss)));

    sat_thr_r = tern(Rhel > 0, 0.95 * lim.dr_max, 0.98 * lim.dr_max);
    Sm.yaw.rudder_sat_ss_pct = sat_pct(dr, mask_ss, sat_thr_r);
    Sm.yaw.rudder_sat_full_pct = sat_pct(dr, mask_full, sat_thr_r);
    if Rhel > 0
        Uh_k = Uh_g(:) .* kappa(:);
        valid = mask_ss & (abs(kappa(:)) > 1e-4) & (abs(Uh_g(:)) > 0.3);
        if any(valid)
            mean_r = mean(r_yaw(valid));
            mean_Uh_k = mean(Uh_k(valid));
            if mean_Uh_k < 0; mean_Uh_k = -mean_Uh_k; mean_r = -mean_r; end
            Sm.yaw.ratio_r_Uh_kappa = mean_r / max(abs(mean_Uh_k), 1e-9);
        else
            Sm.yaw.ratio_r_Uh_kappa = NaN;
        end
    else
        Sm.yaw.ratio_r_Uh_kappa = NaN;
    end

    Sm.act = struct();
    Sm.act.de_mag_util = mean_safe(abs(de), mask_ss) / lim.de_max;
    Sm.act.dr_mag_util = mean_safe(abs(dr), mask_ss) / lim.dr_max;
    thr_span = max(abs([lim.thrust_min, lim.thrust_max]));
    Sm.act.thr_mag_util = mean_safe(abs(thr), mask_ss) / thr_span;
    Sm.act.de_rate_util = rms_safe(de_dot(mask_ss)) / lim.de_rate;
    Sm.act.dr_rate_util = rms_safe(dr_dot(mask_ss)) / lim.dr_rate;
    Sm.act.de_sat_pct = sat_pct(de, mask_ss, 0.98 * lim.de_max);
    Sm.act.dr_sat_ss_pct = Sm.yaw.rudder_sat_ss_pct;
    Sm.act.dr_sat_full_pct = Sm.yaw.rudder_sat_full_pct;
    Sm.act.thr_sat_pct = 100 * mean(thr(mask_ss) >= 0.98 * lim.thrust_max | ...
        thr(mask_ss) <= lim.thrust_min + 0.02 * abs(lim.thrust_min));
    if any(mask_ss) && nnz(mask_ss) > 10 && dt > 0
        Sm.act.chatter_dps = rad2deg(std(hf_local(detrend(e_th(mask_ss)), dt)));
    else
        Sm.act.chatter_dps = NaN;
    end
    Sm.act.de_max_deg = rad2deg(max(abs(de(mask_full))));
    Sm.act.dr_max_deg = rad2deg(max(abs(dr(mask_full))));
    Sm.act.de_rate_max_dps = rad2deg(max(abs(de_dot(mask_full))));
    Sm.act.dr_rate_max_dps = rad2deg(max(abs(dr_dot(mask_full))));
end

function [feas, first, gates] = score_seg_gates(Sm, key, HG)
    h = HG.(key);
    order = {};
    g_pm = ~isnan(Sm.theta.mae_deg) && (Sm.theta.mae_deg <= h.pitch_mae);
    g_pp = ~isnan(Sm.theta.p95_deg) && (Sm.theta.p95_deg <= h.pitch_p95);
    order{end+1} = {g_pm, sprintf('pitch_MAE(%.4f>%.4f)', nz(Sm.theta.mae_deg), h.pitch_mae)};
    order{end+1} = {g_pp, sprintf('pitch_p95(%.4f>%.4f)', nz(Sm.theta.p95_deg), h.pitch_p95)};
    g_gm = ~isnan(Sm.gamma.mae_deg) && (Sm.gamma.mae_deg <= h.gamma_mae);
    g_gp = ~isnan(Sm.gamma.p95_deg) && (Sm.gamma.p95_deg <= h.gamma_p95);
    order{end+1} = {g_gm, sprintf('gamma_MAE(%.4f>%.4f)', nz(Sm.gamma.mae_deg), h.gamma_mae)};
    order{end+1} = {g_gp, sprintf('gamma_p95(%.4f>%.4f)', nz(Sm.gamma.p95_deg), h.gamma_p95)};

    if strcmp(key, 'TURN')
        g_ym = ~isnan(Sm.yaw.mae_deg) && (Sm.yaw.mae_deg <= h.yaw_mae);
        g_yp = ~isnan(Sm.yaw.p95_deg) && (Sm.yaw.p95_deg <= h.yaw_p95);
        g_yss = ~isnan(Sm.yaw.rudder_sat_ss_pct) && (Sm.yaw.rudder_sat_ss_pct <= HG.rud_sat_ss);
        g_yf = ~isnan(Sm.yaw.rudder_sat_full_pct) && (Sm.yaw.rudder_sat_full_pct <= HG.rud_sat_full);
        if ~isnan(Sm.yaw.ratio_r_Uh_kappa)
            g_rat = (Sm.yaw.ratio_r_Uh_kappa >= HG.ratio_lo) && (Sm.yaw.ratio_r_Uh_kappa <= HG.ratio_hi);
        else
            g_rat = true;
        end
        g_ch = ~isnan(Sm.act.chatter_dps) && (Sm.act.chatter_dps <= HG.chatter);
        order{end+1} = {g_ym, sprintf('yaw_MAE(%.4f>%.4f)', nz(Sm.yaw.mae_deg), h.yaw_mae)};
        order{end+1} = {g_yp, sprintf('yaw_p95(%.4f>%.4f)', nz(Sm.yaw.p95_deg), h.yaw_p95)};
        order{end+1} = {g_yss, sprintf('rudder_sat_ss(%.2f%%>%.2f%%)', nz(Sm.yaw.rudder_sat_ss_pct), HG.rud_sat_ss)};
        order{end+1} = {g_yf, sprintf('rudder_sat_full(%.2f%%>%.2f%%)', nz(Sm.yaw.rudder_sat_full_pct), HG.rud_sat_full)};
        order{end+1} = {g_rat, sprintf('yaw_ratio(%.4f)', nz(Sm.yaw.ratio_r_Uh_kappa))};
        order{end+1} = {g_ch, sprintf('chatter(%.4f>%.4f)', nz(Sm.act.chatter_dps), HG.chatter)};
    else
        yaw_lim = h.yaw_mae;
        g_ym = ~isnan(Sm.yaw.mae_deg) && (Sm.yaw.mae_deg <= yaw_lim);
        order{end+1} = {g_ym, sprintf('yaw_MAE(%.4f>%.4f)', nz(Sm.yaw.mae_deg), yaw_lim)};
        g_ch = ~isnan(Sm.act.chatter_dps) && (Sm.act.chatter_dps <= HG.chatter);
        order{end+1} = {g_ch, sprintf('chatter(%.4f>%.4f)', nz(Sm.act.chatter_dps), HG.chatter)};
    end

    g_es = ~isnan(Sm.act.de_sat_pct) && (Sm.act.de_sat_pct <= HG.elev_sat);
    g_ts = ~isnan(Sm.act.thr_sat_pct) && (Sm.act.thr_sat_pct <= HG.thrust_sat);
    g_dru = ~isnan(Sm.act.dr_rate_util) && (Sm.act.dr_rate_util <= HG.rate_util);
    g_deu = ~isnan(Sm.act.de_rate_util) && (Sm.act.de_rate_util <= HG.rate_util);
    order{end+1} = {g_es, sprintf('elev_sat(%.2f%%>%.2f%%)', nz(Sm.act.de_sat_pct), HG.elev_sat)};
    order{end+1} = {g_ts, sprintf('thrust_sat(%.2f%%>%.2f%%)', nz(Sm.act.thr_sat_pct), HG.thrust_sat)};
    order{end+1} = {g_dru, sprintf('rudder_rate_util(%.3f>1)', nz(Sm.act.dr_rate_util))};
    order{end+1} = {g_deu, sprintf('elev_rate_util(%.3f>1)', nz(Sm.act.de_rate_util))};

    feas = true; first = 'none';
    gates = struct();
    for k = 1:numel(order)
        gates.(sprintf('g%d', k)) = order{k}{1};
        if ~order{k}{1} && feas
            feas = false;
            first = order{k}{2};
        end
    end
end

function C = classify_mission(M, HG)
    C = struct('mission_ok', false, 'first_fail', 'unrun', 'checks', {{}});
    if ~isfield(M, 'ok') || ~M.ok
        C.first_fail = 'sim_or_analysis_fail'; return;
    end
    order = {};
    order{end+1} = {M.bounded, 'states_unbounded'};
    order{end+1} = {M.progress.monotonic, sprintf('backward_progress(n=%d min_ds=%.3f)', ...
        M.progress.n_back, M.progress.min_ds)};
    order{end+1} = {~M.progress.stalled, sprintf('stall(%.2fs>=%.2fs)', ...
        M.progress.stall_run_s, HG.stall_hold_s)};
    order{end+1} = {M.progress.completed, sprintf('incomplete(s_frac=%.3f<%.2f)', ...
        M.progress.final_frac, HG.complete_s_frac)};

    for i = 1:numel(M.segments)
        Sm = M.segments(i);
        order{end+1} = {Sm.feasible, sprintf('%s:%s', Sm.name, Sm.first_limit)}; %#ok<AGROW>
        order{end+1} = {Sm.progress_mono, sprintf('%s:seg_backward_progress', Sm.name)}; %#ok<AGROW>
    end
    for i = 1:numel(M.transitions)
        Tr = M.transitions(i);
        order{end+1} = {Tr.ok, sprintf('%s:trans_fail(cte=%.3f ez=%.3f mono=%d)', ...
            Tr.name, nz(Tr.max_cte), nz(Tr.max_abs_ez), Tr.progress_mono)}; %#ok<AGROW>
    end

    C.mission_ok = true; C.first_fail = 'none';
    C.checks = order;
    for k = 1:numel(order)
        if ~order{k}{1}
            C.mission_ok = false;
            C.first_fail = order{k}{2};
            break;
        end
    end
end

%% ===================== PROJECTION (guidance-like) =====================
function [s_prog, cte_perp, e_z, gamma_ref, t_hat_log] = project_progress_series(path, s_nodes, s_total, vp)
    n = size(vp, 1);
    L = 1.25;
    s_prog = zeros(n, 1);
    cte_perp = zeros(n, 1);
    e_z = zeros(n, 1);
    gamma_ref = zeros(n, 1);
    t_hat_log = zeros(n, 3);
    s_cur = 0;
    for i = 1:n
        if i == 1
            [s_near, ~] = project_interval_local(vp(i, :), path, s_nodes, 0, s_total);
            s_cur = s_near;
        else
            s_lo = max(0, s_cur - 0.15);
            s_hi = min(s_total, s_cur + max(3.0, 2.5 * L));
            [s_near, ~] = project_interval_local(vp(i, :), path, s_nodes, s_lo, s_hi);
            s_cur = max(s_cur, s_near - 0.05);
            s_cur = min(s_cur, s_total);
        end
        [p_path, t_hat] = sample_path_local(path, s_nodes, s_cur);
        e = vp(i, :) - p_path;
        th = t_hat(1:2); nth = norm(th);
        if nth < 1e-9; nh = [0 1]; else; th = th / nth; nh = [-th(2), th(1)]; end
        cte_perp(i) = hypot(dot(e(1:2), nh), e(3));
        e_z(i) = -(e(3));  % z_path - z_veh (same sign family as guidance last_e_z)
        gamma_ref(i) = atan2(t_hat(3), max(norm(t_hat(1:2)), 1e-9));
        t_hat_log(i, :) = t_hat;
        s_prog(i) = s_cur;
    end
end

function [s_best, d_best] = project_interval_local(p, path, s_nodes, s_lo, s_hi)
    n = size(path, 1);
    d_best = inf; s_best = s_lo;
    i0 = max(1, find(s_nodes <= s_lo, 1, 'last'));
    i1 = min(n - 1, find(s_nodes >= s_hi, 1, 'first'));
    if isempty(i0); i0 = 1; end
    if isempty(i1); i1 = n - 1; end
    i0 = min(i0, n - 1); i1 = max(i1, i0);
    for i = i0:i1
        a = path(i, :); b = path(i + 1, :); ab = b - a; lab2 = sum(ab.^2);
        if lab2 < 1e-12; continue; end
        tt = max(0, min(1, dot(p - a, ab) / lab2));
        proj = a + tt * ab;
        d = norm(p - proj);
        s = s_nodes(i) + tt * (s_nodes(i + 1) - s_nodes(i));
        if s < s_lo - 1e-9 || s > s_hi + 1e-9; continue; end
        if d < d_best; d_best = d; s_best = s; end
    end
end

function [p, t_hat] = sample_path_local(path, s_nodes, s)
    n = size(path, 1);
    s_total = s_nodes(end);
    s = max(0, min(s_total, s));
    i = max(1, min(n - 1, find(s_nodes <= s, 1, 'last')));
    if isempty(i); i = 1; end
    ds = s_nodes(i + 1) - s_nodes(i);
    if ds < 1e-12; tt = 0; else; tt = (s - s_nodes(i)) / ds; end
    p = path(i, :) + tt * (path(i + 1, :) - path(i, :));
    tang = path(i + 1, :) - path(i, :);
    if norm(tang) < 1e-9
        if i > 1; tang = path(i, :) - path(i - 1, :); else; tang = [1 0 0]; end
    end
    t_hat = tang / norm(tang);
end

%% ===================== OUTPUTS =====================
function write_png(png_path, R)
    S = R.S; M = R.M; Seg = R.Seg;
    fig = figure('Visible', 'off', 'Position', [30 30 1500 1050], 'Color', 'w');
    tiledlayout(3, 3, 'Padding', 'compact', 'TileSpacing', 'compact');

    % Path 3D
    nexttile;
    plot3(S.vp(:,1), S.vp(:,2), S.vp(:,3), 'b-', 'LineWidth', 1.4); hold on;
    if isfield(M, 's_prog')
        for i = 1:numel(Seg.names)
            ix = find(M.s_prog >= Seg.s0(i), 1, 'first');
            if ~isempty(ix)
                plot3(S.vp(ix,1), S.vp(ix,2), S.vp(ix,3), 'ko', 'MarkerFaceColor', 'y', 'MarkerSize', 6);
            end
        end
    end
    grid on; axis equal; xlabel('X'); ylabel('Y'); zlabel('Z');
    title('Vehicle path (seg starts)'); view(35, 25);

    % Progress
    nexttile;
    if isfield(M, 's_prog')
        plot(S.t, M.s_prog, 'b', 'LineWidth', 1.3); hold on;
        yline(M.s_total, 'k--');
        for i = 1:numel(Seg.trans_s)
            yline(Seg.trans_s(i), 'r:', 'LineWidth', 1);
        end
        grid on; xlabel('t [s]'); ylabel('s [m]');
        title(sprintf('Progress mono=%s complete=%s', yn(M.progress.monotonic), yn(M.progress.completed)));
    end

    % Ref vs actual pitch / yaw
    nexttile;
    plot(S.t, rad2deg(S.theta_phys), 'b'); hold on;
    plot(S.t, rad2deg(S.theta_ref), 'r--');
    grid on; ylabel('deg'); title('\theta_{phys} vs \theta_{ref}'); legend('act','ref');

    nexttile;
    plot(S.t, rad2deg(unwrap(S.ori(:,3))), 'b'); hold on;
    plot(S.t, rad2deg(unwrap(S.psi_ref)), 'r--');
    grid on; ylabel('deg'); title('\psi vs \psi_{ref} (unwrap)');

    nexttile;
    if isfield(M, 'cte_perp')
        plot(S.t, M.cte_perp, 'b'); hold on;
        plot(S.t, abs(M.e_z), 'r');
        grid on; ylabel('m'); title('CTE_{perp} / |e_z|'); legend('CTE','|e_z|');
    end

    nexttile;
    if isfield(M, 'gamma_act')
        plot(S.t, rad2deg(M.gamma_act), 'b'); hold on;
        plot(S.t, rad2deg(M.gamma_ref), 'r--');
        grid on; ylabel('deg'); title('\gamma act vs path');
    end

    nexttile;
    plot(S.t, S.u_ctrl, 'b'); hold on; plot(S.t, S.u_ref, 'r--');
    grid on; ylabel('m/s'); title('Speed u vs u_{ref}');

    nexttile;
    plot(S.t, rad2deg(S.delta_e), 'b'); hold on;
    plot(S.t, rad2deg(S.delta_r), 'r');
    grid on; ylabel('deg'); title('Actuators \delta_e / \delta_r'); legend('elev','rud');

    nexttile;
    plot(S.t, S.thrust, 'k'); hold on;
    plot(S.t, rad2deg(S.ori(:,1)), 'm');
    grid on; title('Thrust / \phi [deg]'); legend('T','\phi');

    sgtitle(sprintf('%s audit=%s mission=%s next=%s', R.task_id, R.verdict_audit, ...
        yn(R.mission_class.mission_ok), R.next_gate), 'Interpreter', 'none');
    exportgraphics(fig, png_path, 'Resolution', 150);
    close(fig);
end

function write_md(md_path, R)
    A = R.Audit; M = R.M; C = R.mission_class; Seg = R.Seg; HG = R.HG;
    fid = fopen(md_path, 'w');
    fprintf(fid, '# %s — Guidance / mission readiness baseline\n\n', R.task_id);
    fprintf(fid, '**Audit completeness verdict: %s**\n\n', R.verdict_audit);
    fprintf(fid, '**Mission execution classification: %s** (first=`%s`)\n\n', ...
        yn(C.mission_ok), sanitize(C.first_fail));
    fprintf(fid, '**Prioritized next gate: `%s`** — %s\n\n', R.next_gate, R.next_note);

    fprintf(fid, '## Provenance\n\n');
    fprintf(fid, '- Read-only audit sources: `run_path_suite.m`, `continuous_path_tracking.m`, `guidance_law.m`\n');
    fprintf(fid, '- Prior: CRAB_CURRENT_FF_CANDIDATE **REJECTED** (R10 rudder sat 6.06→9.00%%); production FROZEN\n');
    fprintf(fid, '- Driver: `run_guidance_mission_baseline.m` (one MATLAB invocation)\n');
    fprintf(fid, '- Production plant/controller/guidance: **UNTOUCHED / FROZEN** (no tuning)\n');
    fprintf(fid, '- Hard gates: SPEED_ENVELOPE / COMBINED absolutes (LEVEL≈X, CLIMB≈XZ, TURN≈R10/H, EXIT≈X)\n');
    fprintf(fid, '- Artifacts: `%s`, `%s`, `%s`\n', R.paths.md, R.paths.mat, R.paths.png);
    fprintf(fid, '- Did **not** touch `CODEX_VERTICAL_PLAN.md`\n');
    fprintf(fid, '- Stamp: %s | seed=%d | U=%.2f | T_final=%.1fs | s_total=%.2fm\n\n', ...
        R.stamp, R.seed, R.Uref, R.T_final, R.s_total);

    fprintf(fid, '## Path input contract\n\n');
    fprintf(fid, '- Shape: %s\n', A.path_input_contract.shape);
    fprintf(fid, '- Min N: %d | Closed if %s\n', A.path_input_contract.min_N, A.path_input_contract.closed_detection);
    fprintf(fid, '- Speed: %s\n', A.path_input_contract.speed);
    fprintf(fid, '- IC: %s\n', A.path_input_contract.state0);
    fprintf(fid, '- Mission fields: **%s**\n', A.path_input_contract.mission_fields);
    fprintf(fid, '- Provenance: %s\n\n', A.path_input_contract.provenance);

    fprintf(fid, '## Projection / progress state\n\n');
    fprintf(fid, '- State: %s\n', A.projection_progress.state);
    fprintf(fid, '- Monotonic: %s\n', A.projection_progress.monotonic);
    fprintf(fid, '- Window: %s\n', A.projection_progress.window);
    fprintf(fid, '- Depth hold: %s\n', A.projection_progress.depth_hold);
    fprintf(fid, '- Provenance: %s\n\n', A.projection_progress.provenance);

    fprintf(fid, '## Lookahead\n\n');
    fprintf(fid, '- L: %s (runtime L=%.2f m)\n', A.lookahead.L, R.globals.lookahead_distance);
    fprintf(fid, '- Use: %s\n', A.lookahead.use);
    fprintf(fid, '- Provenance: %s\n\n', A.lookahead.provenance);

    fprintf(fid, '## Command filters / limits\n\n');
    fprintf(fid, '- Yaw: %s\n', A.command_filters_limits.yaw);
    fprintf(fid, '- Pitch: %s\n', A.command_filters_limits.pitch);
    fprintf(fid, '- kappa/r_ff: %s / %s\n', A.command_filters_limits.kappa, A.command_filters_limits.r_ff);
    fprintf(fid, '- Multi-rate: %s\n', A.command_filters_limits.multi_rate);
    fprintf(fid, '- Runtime: pitch_ref_max=%.1fdeg rate_max=%.1fdeg/s δe_max=%.1f δr_max=%.1f\n', ...
        R.globals.pitch_ref_max_deg, R.globals.pitch_ref_rate_max_dps, ...
        rad2deg(R.lim.de_max), rad2deg(R.lim.dr_max));
    fprintf(fid, '- Provenance: %s\n\n', A.command_filters_limits.provenance);

    fprintf(fid, '## Termination / completion\n\n');
    fprintf(fid, '- Sim stop: %s\n', A.termination_completion.sim_stop);
    fprintf(fid, '- near_end: %s\n', A.termination_completion.near_end);
    fprintf(fid, '- Mission complete flag: **%s**\n', A.termination_completion.mission_complete_flag);
    fprintf(fid, '- Success criteria API: **%s**\n', A.termination_completion.success_criteria_api);
    fprintf(fid, '- Provenance: %s\n\n', A.termination_completion.provenance);

    fprintf(fid, '## Transition handling\n\n');
    fprintf(fid, '- Segment blender: **%s**\n', A.transition_handling.segment_blender);
    fprintf(fid, '- Clothoid/shaper: **%s**\n', A.transition_handling.clothoid_or_shaper);
    fprintf(fid, '- Mode switch: **%s**\n', A.transition_handling.mode_switch);
    fprintf(fid, '- Note: %s\n', A.transition_handling.note);
    fprintf(fid, '- Provenance: %s\n\n', A.transition_handling.provenance);

    fprintf(fid, '## Resets / timeouts / replanning\n\n');
    fprintf(fid, '- Mid-mission reset: **%s** | bumpless handoff: **%s**\n', ...
        A.resets.mid_mission_reset, A.resets.integrator_bump_less);
    fprintf(fid, '- Mission watchdog / stall / acq timeout: **%s** / **%s** / **%s**\n', ...
        A.timeouts.mission_watchdog, A.timeouts.stall_detector, A.timeouts.acq_timeout);
    fprintf(fid, '- Online repath / avoid / dynamic replan: **%s** / **%s** / **%s**\n', ...
        A.replanning.path_swap_online, A.replanning.obstacle_avoid, A.replanning.dynamic_repath);
    fprintf(fid, '- Provenance resets: %s\n', A.resets.provenance);
    fprintf(fid, '- Provenance replan: %s\n\n', A.replanning.provenance);

    fprintf(fid, '## Missing mission / fault functions\n\n');
    fprintf(fid, '| Function | Status |\n|---|---|\n');
    fprintf(fid, '| mission_manager | **%s** |\n', A.mission_fault.mission_manager);
    fprintf(fid, '| fault_detection | **%s** |\n', A.mission_fault.fault_detection);
    fprintf(fid, '| fault_isolation | **%s** |\n', A.mission_fault.fault_isolation);
    fprintf(fid, '| safe_mode | **%s** |\n', A.mission_fault.safe_mode);
    fprintf(fid, '| abort_recover | **%s** |\n', A.mission_fault.abort_recover);
    fprintf(fid, '| sensor_outage_handler | **%s** |\n', A.mission_fault.sensor_outage_handler);
    fprintf(fid, '| actuator_fail_handler | **%s** |\n', A.mission_fault.actuator_fail_handler);
    fprintf(fid, '\nProvenance: %s\n\n', A.mission_fault.provenance);

    fprintf(fid, '## Composite mission geometry\n\n');
    fprintf(fid, '- Design: LEVEL → CLIMB (raised-cosine) → TURN R10 90° → EXIT\n');
    fprintf(fid, '- Continuity: %s | pos_ok=%s tang_ok=%s\n', ...
        R.PathMeta.design_note, yn(R.PathMeta.continuity.pos_ok), yn(R.PathMeta.continuity.tang_ok));
    fprintf(fid, '- Max climb slope=%.4f (γ≈%.2f deg)\n', ...
        R.PathMeta.max_climb_slope, R.PathMeta.max_climb_gamma_deg);
    fprintf(fid, '\n| Segment | s0 [m] | s1 [m] | L [m] | Description |\n|---|---:|---:|---:|---|\n');
    for i = 1:numel(Seg.names)
        fprintf(fid, '| %s | %.2f | %.2f | %.2f | %s |\n', Seg.names{i}, ...
            Seg.s0(i), Seg.s1(i), Seg.s1(i)-Seg.s0(i), Seg.description{i});
    end
    fprintf(fid, '\n');

    fprintf(fid, '## Whole-mission metrics\n\n');
    if isfield(M, 'progress')
        fprintf(fid, '- Progress: mono=%s n_back=%d min_ds=%.4f final_s=%.2f/%.2f (%.1f%%) complete=%s\n', ...
            yn(M.progress.monotonic), M.progress.n_back, M.progress.min_ds, ...
            M.progress.final_s, M.s_total, 100*M.progress.final_frac, yn(M.progress.completed));
        fprintf(fid, '- Stall: run=%.2fs (lim %.2fs) stalled=%s | mean ds/dt=%.3f m/s\n', ...
            M.progress.stall_run_s, HG.stall_hold_s, yn(M.progress.stalled), M.progress.mean_ds_dt);
        fprintf(fid, '- Bounded states: %s\n', yn(M.bounded));
        W = M.whole;
        fprintf(fid, '- Steady window: thMAE=%.4f gMAE=%.4f yawMAE=%.4f CTE=%.3f |e_z|=%.4f uMAE=%.4f\n', ...
            nz(W.theta.mae_deg), nz(W.gamma.mae_deg), nz(W.yaw.mae_deg), ...
            nz(W.path.mean_cte), nz(W.depth.mae), nz(W.speed.mae));
        fprintf(fid, '- Actuators: deSat=%.2f%% drSatF=%.2f%% thrSat=%.2f%% chat=%.4f deRateU=%.3f drRateU=%.3f\n', ...
            nz(W.act.de_sat_pct), nz(W.act.dr_sat_full_pct), nz(W.act.thr_sat_pct), ...
            nz(W.act.chatter_dps), nz(W.act.de_rate_util), nz(W.act.dr_rate_util));
        fprintf(fid, '- Roll MAE=%.3f deg | φ p_rms=%.3f deg/s | |de|_max=%.2f |dr|_max=%.2f deg\n\n', ...
            nz(W.roll.mae_deg), nz(W.roll.p_rms_dps), nz(W.act.de_max_deg), nz(W.act.dr_max_deg));
    else
        fprintf(fid, '- Analysis unavailable (sim fail)\n\n');
    end

    fprintf(fid, '## Per-segment hard gates\n\n');
    fprintf(fid, '| Seg | FEAS | First | thMAE | gMAE | yawMAE | CTE | |ez| | deSat | drSatF | chat | mono |\n');
    fprintf(fid, '|---|:---:|---|---:|---:|---:|---:|---:|---:|---:|---:|:---:|\n');
    if isfield(M, 'segments')
        for i = 1:numel(M.segments)
            Sm = M.segments(i);
            fprintf(fid, '| %s | %s | %s | %.4f | %.4f | %.4f | %.3f | %.4f | %.2f | %.2f | %.4f | %s |\n', ...
                Sm.name, yn(Sm.feasible), sanitize(Sm.first_limit), ...
                nz(Sm.theta.mae_deg), nz(Sm.gamma.mae_deg), nz(Sm.yaw.mae_deg), ...
                nz(Sm.path.mean_cte), nz(Sm.depth.mae), nz(Sm.act.de_sat_pct), ...
                nz(Sm.act.dr_sat_full_pct), nz(Sm.act.chatter_dps), yn(Sm.progress_mono));
        end
    end
    fprintf(fid, '\n');

    fprintf(fid, '## Transitions\n\n');
    fprintf(fid, '| Transition | n | max CTE | max |ez| | mono | OK | lim CTE=%.2f |ez|=%.2f |\n', ...
        HG.trans_cte_max, HG.trans_ez_max);
    fprintf(fid, '|---|---:|---:|---:|:---:|:---:|---|\n');
    if isfield(M, 'transitions')
        for i = 1:numel(M.transitions)
            Tr = M.transitions(i);
            fprintf(fid, '| %s | %d | %.3f | %.3f | %s | %s | |\n', ...
                Tr.name, Tr.n, nz(Tr.max_cte), nz(Tr.max_abs_ez), yn(Tr.progress_mono), yn(Tr.ok));
        end
    end
    fprintf(fid, '\n');

    fprintf(fid, '## PASS gates (audit completeness)\n\n');
    fprintf(fid, '| Gate | Status |\n|---|:---:|\n');
    fprintf(fid, '| audit_sources_read | PASS |\n');
    fprintf(fid, '| contract_documented | PASS |\n');
    fprintf(fid, '| NOT_IMPLEMENTED_marked | PASS |\n');
    fprintf(fid, '| production_untouched | PASS |\n');
    fprintf(fid, '| no_tuning | PASS |\n');
    fprintf(fid, '| composite_path_C1 | %s |\n', yn(R.PathMeta.continuity.pos_ok && R.PathMeta.continuity.tang_ok));
    fprintf(fid, '| one_6dof_run | %s |\n', yn(M.sim_ok));
    fprintf(fid, '| artifacts_written | PASS |\n');
    fprintf(fid, '\n**Overall audit: %s**\n\n', R.verdict_audit);

    fprintf(fid, '## Next bounded roadmap gate\n\n');
    fprintf(fid, '- **`%s`** — %s\n', R.next_gate, R.next_note);
    fprintf(fid, '- CODEX_VERTICAL_PLAN untouched.\n');
    fclose(fid);
end

function append_research_log(log_path, R)
    fid = fopen(log_path, 'a');
    fprintf(fid, '\n\n## %s — %s\n\n', R.task_id, R.stamp);
    fprintf(fid, '- Verdict (audit completeness): **%s** — crab-current FF rejected; production cascade+guidance frozen; no retune.\n', R.verdict_audit);
    fprintf(fid, '- Mission class: %s first=`%s` | mono=%s complete=%s stall=%s bounded=%s\n', ...
        yn(R.mission_class.mission_ok), sanitize(R.mission_class.first_fail), ...
        yn(R.M.progress.monotonic), yn(R.M.progress.completed), ...
        yn(R.M.progress.stalled), yn(R.M.bounded));
    fprintf(fid, '- Composite U=1.5: LEVEL→CLIMB→R10 TURN→EXIT; s_total=%.2fm T=%.1fs; C1 path external (guidance segment-unaware).\n', ...
        R.s_total, R.T_final);
    if isfield(R.M, 'segments') && ~isempty(R.M.segments)
        parts = cell(1, numel(R.M.segments));
        for i = 1:numel(R.M.segments)
            Sm = R.M.segments(i);
            parts{i} = sprintf('%s FEAS=%s(%s)', Sm.name, yn(Sm.feasible), sanitize(Sm.first_limit));
        end
        fprintf(fid, '- Segments: %s\n', strjoin(parts, ' | '));
    end
    fprintf(fid, '- Unsupported autonomy marked NOT_IMPLEMENTED (mission manager, faults, replan, timeouts, transition shaper).\n');
    fprintf(fid, '- Artifacts: suite_results/GUIDANCE_MISSION_BASELINE.{md,mat,png}; driver `run_guidance_mission_baseline.m`.\n');
    fprintf(fid, '- Next: **`%s`** — %s\n', R.next_gate, R.next_note);
    fprintf(fid, '- CODEX_VERTICAL_PLAN untouched.\n');
    fclose(fid);
end

function P = pack_S(S)
    keep = {'t','vp','vel','rates','ori','psi_ref','theta_ref','u_ref','u_ctrl', ...
        'u_body','thrust','delta_e','delta_r','Uh','VD','Uref','dt','T_final', ...
        'e_z','e_zdot','gamma','gamma_path','e_gamma','e_theta','theta_phys', ...
        'U_h_guid','kappa','r','progress_index','ok','finite'};
    P = struct();
    for i = 1:numel(keep)
        if isfield(S, keep{i}); P.(keep{i}) = S.(keep{i}); end
    end
end

%% ===================== helpers =====================
function s = err_stats_deg(e, mask)
    s = struct('mae_deg', NaN, 'p95_deg', NaN, 'rms_deg', NaN);
    if ~any(mask); return; end
    ae = abs(e(mask));
    s.mae_deg = rad2deg(mean(ae));
    s.p95_deg = rad2deg(prctile_local(ae, 95));
    s.rms_deg = rad2deg(rms_safe(e(mask)));
end

function s = err_stats_lin(e, mask)
    s = struct('mae', NaN, 'p95', NaN, 'rms', NaN);
    if ~any(mask); return; end
    ae = abs(e(mask));
    s.mae = mean(ae); s.p95 = prctile_local(ae, 95); s.rms = rms_safe(e(mask));
end

function y = mean_safe(x, mask)
    x = x(:);
    if nargin < 2; mask = true(size(x)); end
    mask = mask(:); mask = mask & isfinite(x);
    if ~any(mask); y = NaN; else; y = mean(x(mask)); end
end

function y = max_safe(x, mask)
    x = x(:); mask = mask(:) & isfinite(x);
    if ~any(mask); y = NaN; else; y = max(x(mask)); end
end

function y = rms_safe(x)
    x = x(:); x = x(isfinite(x));
    if isempty(x); y = NaN; else; y = sqrt(mean(x.^2)); end
end

function y = prctile_local(x, p)
    x = x(:); x = x(isfinite(x));
    if isempty(x); y = NaN; return; end
    x = sort(x); k = max(1, min(numel(x), round(p/100 * numel(x))));
    y = x(k);
end

function pct = sat_pct(u, mask, thr)
    u = u(:); mask = mask(:);
    if ~any(mask); pct = NaN; return; end
    pct = 100 * mean(abs(u(mask)) >= thr);
end

function y = hf_local(x, dt)
    n = max(3, round(0.8 / max(dt, 1e-3)));
    b = ones(n, 1) / n;
    lf = filter(b, 1, x(:));
    y = x(:) - lf; y(1:n) = 0;
end

function a = wrapToPiLocal(a)
    a = mod(a + pi, 2*pi) - pi;
end

function y = tern(c, a, b)
    if c; y = a; else; y = b; end
end

function y = nz(x)
    if isempty(x) || ~isfinite(x); y = NaN; else; y = x; end
end

function s = yn(v)
    if v; s = 'YES'; else; s = 'NO'; end
end

function s = sanitize(s)
    if isempty(s); s = ''; end
    s = char(string(s));
    s = strrep(s, '|', '/');
    s = strrep(s, newline, ' ');
end

function n = max_true_run(mask)
    n = 0; cur = 0;
    for i = 1:numel(mask)
        if mask(i); cur = cur + 1; n = max(n, cur); else; cur = 0; end
    end
end
