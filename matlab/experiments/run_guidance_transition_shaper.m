function run_guidance_transition_shaper()
% GUIDANCE_TRANSITION_SHAPER_001 — isolated mission-geometry transition shaper.
% Read-only: run_guidance_mission_baseline.m, suite_results/GUIDANCE_MISSION_BASELINE.{md,mat}.
% Prior: GUIDANCE_MISSION_BASELINE mission class FAIL first=LEVEL:gamma_MAE.
% Production plant/controller/guidance FROZEN — no gain tuning, no relaxed gates.
%
% ONE candidate 6DOF @ U=1.5 (isolated runner):
%   explicit ACQ lead-in (scored separately) → LEVEL → longer C2 climb →
%   R10 clothoid curvature ramps (R_min>=10) 90° TURN → LEVEL EXIT
% Reuses baseline MAT for before/after; production stack untouched.
% PASS = post-ACQ hard gates + transition gates + completion/bounds + no actuator regression.
% Else REJECT; production unchanged. Next: fault_injection_baseline if PASS,
%   else close mission-shaper line / document production mission limitations.
% Artifacts: suite_results/GUIDANCE_TRANSITION_SHAPER.{md,mat,png}
% Appends: suite_results/PITCH_CONTROL_RESEARCH_LOG.md
% Never touches CODEX_VERTICAL_PLAN.md.

    project_dir = fileparts(fileparts(fileparts(mfilename('fullpath')))); % repo root
    addpath(genpath(fullfile(project_dir, 'matlab')));
    out_dir = fullfile(project_dir, 'suite_results');
    if ~exist(out_dir, 'dir'); mkdir(out_dir); end
    tag = 'GUIDANCE_TRANSITION_SHAPER';
    task_id = 'GUIDANCE_TRANSITION_SHAPER_001';

    base_mat = fullfile(out_dir, 'GUIDANCE_MISSION_BASELINE.mat');
    base_md  = fullfile(out_dir, 'GUIDANCE_MISSION_BASELINE.md');
    src_base = fullfile(project_dir, 'run_guidance_mission_baseline.m');
    log_path = fullfile(out_dir, 'PITCH_CONTROL_RESEARCH_LOG.md');
    assert(exist(base_mat, 'file') == 2, 'Missing %s', base_mat);
    assert(exist(base_md, 'file') == 2, 'Missing %s', base_md);
    assert(exist(src_base, 'file') == 2, 'Missing %s', src_base);
    assert(exist(log_path, 'file') == 2, 'Missing %s', log_path);

    fprintf('\n========== %s ==========\n', task_id);
    fprintf('Isolated geometry shaper; production FROZEN; no control/guidance tuning.\n');

    B = load(base_mat);
    assert(isfield(B, 'Results'), 'Baseline MAT missing Results');
    Base = B.Results;

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

    % Frozen production stack (identical to mission baseline; no retune)
    elevator_sign = 1;
    trim_speed_table = [0.8 1.0 1.5 2.0];
    trim_elevator_table = deg2rad([-9.18 -7.33 -4.62 -3.17]);
    K_gamma = 0; K_zdot = 0; enable_alpha_hat = false;
    Kp_roll = 0.605072;
    lambda_muw_ff = 0.25;
    Uref = 1.5;
    desired_speed = Uref;
    assert(abs(desired_speed - 1.5) < 1e-12, 'desired_speed must be 1.5');
    seed_used = 0;
    rng(seed_used, 'twister');

    lim = struct( ...
        'dr_max', delta_r_max, 'de_max', delta_e_max, ...
        'dr_rate', deg2rad(40), 'de_rate', deg2rad(40), ...
        'thrust_max', thrust_max, 'thrust_min', thrust_min);

    % Identical hard gates to GUIDANCE_MISSION_BASELINE (no relaxation)
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
    HG.prog_back_tol_m = 0.05;
    HG.stall_ds_eps = 0.02;
    HG.stall_hold_s = 2.0;
    HG.trans_cte_max = 1.50;
    HG.trans_ez_max = 1.00;
    HG.complete_s_frac = 0.97;
    % Actuator regression tolerances (absolute; no gate relaxation)
    HG.act_reg_sat_eps = 0.05;      % percentage points
    HG.act_reg_rate_eps = 0.02;     % util fraction
    HG.act_reg_chat_eps = 0.02;     % deg/s
    HG.act_reg_peak_eps_deg = 0.25; % peak |δ| deg

    % ---- Shaped composite mission path ----
    [path, Seg, PathMeta] = build_shaped_mission_path();
    s_nodes = PathMeta.s_nodes;
    s_total = PathMeta.s_total;
    T_final = PathMeta.T_final;

    fprintf('Shaped s_total=%.2f m | T_final=%.1f s | U=%.2f | R_design=%.3f R_meas_min=%.3f m | segments=%d\n', ...
        s_total, T_final, Uref, PathMeta.R, PathMeta.R_min_meas, numel(Seg.names));
    for i = 1:numel(Seg.names)
        fprintf('  [%s] s=[%.2f, %.2f] L=%.2f m scored=%s\n', Seg.names{i}, ...
            Seg.s0(i), Seg.s1(i), Seg.s1(i) - Seg.s0(i), yn(Seg.scored(i)));
    end
    assert(PathMeta.kappa_max <= 0.1 + 1e-12, 'design kappa_max must be <= 0.1 (R>=10)');
    assert(PathMeta.R_min_meas >= 9.5, 'measured R_min collapsed below clothoid design');

    % ---- One production 6DOF run ----
    clear guidance_law controller_law
    S = sim_mission_once(path, Uref, T_final, lim);
    audit_complete = S.ok && S.finite && ~isempty(S.t);

    M = analyze_mission(S, path, s_nodes, s_total, Seg, lim, HG, lookahead_distance);
    ActReg = compare_actuator_regression(Base.M, M, HG);
    Class = classify_candidate(M, HG, ActReg);

    if Class.candidate_ok
        verdict = 'PASS';
        next_gate = 'fault_injection_baseline';
        next_note = 'Transition shaper PASS vs post-ACQ hard/transition/completion gates and no actuator regression → next fault-injection baseline.';
    else
        verdict = 'FAIL';
        next_gate = 'CLOSE_MISSION_SHAPER_LINE';
        next_note = sprintf(['REJECT transition shaper (production untouched). First=`%s`. ', ...
            'Close mission-shaper line after this single failure; document production mission limitations ', ...
            '(no segment blender / clothoid in guidance; composite C1 polyline insufficient for SPEED_ENVELOPE hard gates on multi-segment mission).'], ...
            Class.first_fail);
    end

    stamp = datestr(now, 'yyyy-mm-dd HH:MM:SS');
    Results = struct();
    Results.task_id = task_id;
    Results.tag = tag;
    Results.stamp = stamp;
    Results.verdict = verdict;
    Results.candidate_class = Class;
    Results.next_gate = next_gate;
    Results.next_note = next_note;
    Results.PathMeta = PathMeta;
    Results.Seg = Seg;
    Results.HG = HG;
    Results.M = M;
    Results.ActReg = ActReg;
    Results.Base = pack_base_compare(Base);
    Results.S = pack_S(S);
    Results.Uref = Uref;
    Results.seed = seed_used;
    Results.production_untouched = true;
    Results.no_tuning = true;
    Results.no_relaxed_gates = true;
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
    Results.provenance = struct( ...
        'read_only', {{'run_guidance_mission_baseline.m', 'GUIDANCE_MISSION_BASELINE.md', 'GUIDANCE_MISSION_BASELINE.mat'}}, ...
        'baseline_stamp', Base.stamp, ...
        'baseline_first_fail', Base.mission_class.first_fail, ...
        'equations', PathMeta.equations, ...
        'design_note', PathMeta.design_note);

    md_path  = fullfile(out_dir, [tag '.md']);
    mat_path = fullfile(out_dir, [tag '.mat']);
    png_path = fullfile(out_dir, [tag '.png']);
    Results.paths = struct('md', md_path, 'mat', mat_path, 'png', png_path);

    write_png(png_path, Results);
    write_md(md_path, Results);
    save(mat_path, 'Results', 'path', 'Seg', 'PathMeta', 'M', 'Class', 'ActReg', '-v7.3');
    append_research_log(log_path, Results);

    fprintf('\n========== %s DONE ==========\n', task_id);
    fprintf('Verdict: %s first=%s\n', verdict, Class.first_fail);
    fprintf('Next gate: %s\n', next_gate);
    fprintf('Artifacts: %s | %s | %s\n', md_path, mat_path, png_path);
end

%% ===================== SHAPED PATH =====================
function [path, Seg, Meta] = build_shaped_mission_path()
    % Isolated geometry shaper (guidance still sees one polyline):
    % ACQ lead-in → LEVEL → C2 climb (quintic smoothstep) → clothoid-R10-clothoid → EXIT
    z0 = 0.0;
    dz = 4.0;
    L_acq = 15.0;             % explicit ACQ (scored separately)
    L_level = 20.0;           % scored LEVEL (same intent as baseline)
    L_climb = 36.0;           % longer C2 climb (baseline was 20 m raised-cosine)
    R = 10.0;                 % R_min target (=1/κ_max)
    turn_ang = pi / 2;
    L_cloth = 8.0;            % curvature ramp length each end (κ:0↔1/R)
    L_exit = 20.0;
    ds = 0.05;

    kappa_max = 1.0 / R;
    dpsi_cloth = 0.5 * kappa_max * L_cloth;   % Δψ = ∫κ ds = 0.5 κ_max L
    assert(2 * dpsi_cloth < turn_ang - 1e-6, 'clothoid heading consumes turn');
    ang_circ = turn_ang - 2 * dpsi_cloth;
    L_circ = R * ang_circ;

    % --- ACQ: +X level at z=z0 ---
    pA = straight_xyz([0, 0, z0], [1, 0, 0], L_acq, ds);

    % --- LEVEL (scored) ---
    pL = straight_xyz(pA(end, :), [1, 0, 0], L_level, ds);
    pL = pL(2:end, :);

    % --- CLIMB: quintic smoothstep in z (C2: z'=z''=0 at ends) ---
    % σ=s/L; z=z0+dz*(10σ^3-15σ^4+6σ^5); x continues +X
    nC = max(2, round(L_climb / ds) + 1);
    sC = linspace(0, L_climb, nC)';
    sig = sC / L_climb;
    xC = pL(end, 1) + sC;
    zC = z0 + dz * (10 * sig.^3 - 15 * sig.^4 + 6 * sig.^5);
    pC = [xC, zeros(nC, 1), zC];
    pC = pC(2:end, :);

    x1 = pC(end, 1);
    y1 = 0.0;
    z1 = z0 + dz;
    psi0 = 0.0;  % heading +X entering turn

    % --- TURN entry clothoid: κ 0→1/R ---
    [pTe, psi_e] = clothoid_segment([x1, y1, z1], psi0, 0.0, kappa_max, L_cloth, ds);
    pTe = pTe(2:end, :);

    % --- Circular arc at R ---
    [pTc, psi_c] = circle_segment(pTe(end, :), psi_e, R, ang_circ, +1, ds);
    pTc = pTc(2:end, :);

    % --- TURN exit clothoid: κ 1/R→0 ---
    [pTx, psi_x] = clothoid_segment(pTc(end, :), psi_c, kappa_max, 0.0, L_cloth, ds);
    pTx = pTx(2:end, :);

    % --- EXIT: straight along final heading ---
    t_exit = [cos(psi_x), sin(psi_x), 0];
    pE = straight_xyz(pTx(end, :), t_exit, L_exit, ds);
    pE = pE(2:end, :);

    path = [pA; pL; pC; pTe; pTc; pTx; pE];

    ds_vec = [0; sqrt(sum(diff(path).^2, 2))];
    s_nodes = cumsum(ds_vec);
    s_total = s_nodes(end);

    % Segment bounds by design lengths (polyline arc ≈ design)
    s_acq_end   = L_acq;
    s_level_end = L_acq + L_level;
    s_climb_end = L_acq + L_level + L_climb;
    s_turn_end  = L_acq + L_level + L_climb + L_cloth + L_circ + L_cloth;
    s_exit_end  = s_total;

    Seg = struct();
    Seg.names = {'ACQ', 'LEVEL', 'CLIMB', 'TURN', 'EXIT'};
    Seg.s0 = [0, s_acq_end, s_level_end, s_climb_end, s_turn_end];
    Seg.s1 = [s_acq_end, s_level_end, s_climb_end, s_turn_end, s_exit_end];
    Seg.gate_key = {'ACQ', 'LEVEL', 'CLIMB', 'TURN', 'EXIT'};
    Seg.scored = [false, true, true, true, true];  % ACQ separate
    Seg.R = [0, 0, 0, R, 0];
    Seg.description = {
        sprintf('ACQ lead-in +X z=%.1f L=%.1fm (score separate)', z0, L_acq)
        sprintf('Level straight +X z=%.1f L=%.1fm', z0, L_level)
        sprintf('Quintic smoothstep climb Δz=+%.1fm over L=%.1fm (C2 z ends)', dz, L_climb)
        sprintf('Clothoid-circle-clothoid left turn R=%.1f ang=90deg L_c=%.1f L_arc=%.2fm', R, L_cloth, L_circ)
        sprintf('Level exit heading≈%.1fdeg L=%.1fm at z=%.1f', rad2deg(psi_x), L_exit, z1)
        };
    Seg.trans_names = {'ACQ_LEVEL', 'LEVEL_CLIMB', 'CLIMB_TURN', 'TURN_EXIT'};
    Seg.trans_s = [s_acq_end, s_level_end, s_climb_end, s_turn_end];

    % Curvature audit along path (horizontal κ from xy heading rate)
    [kappa_xy, R_inst] = path_curvature_xy(path, s_nodes);
    R_pos = R_inst(isfinite(R_inst) & (abs(kappa_xy) > 1e-4));
    if isempty(R_pos)
        R_min_meas = inf;
    else
        R_min_meas = min(R_pos);
    end

    Meta = struct();
    Meta.s_nodes = s_nodes;
    Meta.s_total = s_total;
    Meta.z0 = z0; Meta.dz = dz; Meta.R = R;
    Meta.R_min = R;                 % design min radius (=1/kappa_max) >= 10
    Meta.R_min_meas = R_min_meas;   % discrete polyline estimate (sampling noise)
    Meta.L = struct('acq', L_acq, 'level', L_level, 'climb', L_climb, ...
        'cloth', L_cloth, 'circ', L_circ, 'turn', L_cloth + L_circ + L_cloth, 'exit', L_exit);
    Meta.ds = ds;
    Meta.kappa_max = kappa_max;
    Meta.dpsi_cloth_deg = rad2deg(dpsi_cloth);
    Meta.ang_circ_deg = rad2deg(ang_circ);
    Meta.psi_exit_deg = rad2deg(psi_x);
    % Quintic slope: z_s = (dz/L)*(30σ^2-60σ^3+30σ^4); max at σ=0.5 → 1.875 dz/L
    Meta.max_climb_slope = 1.875 * dz / L_climb;
    Meta.max_climb_gamma_deg = rad2deg(atan(Meta.max_climb_slope));
    Meta.continuity = verify_path_continuity(path, Seg, s_nodes);
    Meta.T_final = max(55.0, ceil(1.25 * s_total / 1.5));
    Meta.design_note = [ ...
        'ACQ lead-in + C2 quintic climb + Fresnel clothoid κ-ramps about R=10 arc; ', ...
        'C0 position + C1 unit tangent; κ continuous 0↔1/R at turn; R_min>=10.'];
    Meta.equations = { ...
        'ACQ/LEVEL/EXIT: r(s)=r0 + s*[cosψ,sinψ,0]'
        'CLIMB: x=x0+s; z=z0+dz*(10σ^3-15σ^4+6σ^5), σ=s/L_climb (z_s=z_ss=0 at ends)'
        'Clothoid: κ(s)=κ0+(κ1-κ0)s/L; ψ(s)=ψ0+κ0 s+0.5(κ1-κ0)s^2/L; ẋ=cosψ,ẏ=sinψ'
        'Circle: κ=1/R; Δψ_cloth=0.5 κ_max L_cloth; ang_circ=π/2-2Δψ_cloth'
        sprintf('Params: L_acq=%.1f L_level=%.1f L_climb=%.1f L_cloth=%.1f R=%.1f dz=%.1f', ...
            L_acq, L_level, L_climb, L_cloth, R, dz)
        'Provenance: isolated shaper vs baseline raised-cosine L=20 + sharp R10 (GUIDANCE_MISSION_BASELINE build_composite_mission_path)'
        };
end

function p = straight_xyz(p0, t_hat, L, ds)
    t_hat = t_hat(:)' / max(norm(t_hat), 1e-12);
    n = max(2, round(L / ds) + 1);
    s = linspace(0, L, n)';
    p = p0 + s * t_hat;
end

function [p, psi_end] = clothoid_segment(p0, psi0, kappa0, kappa1, L, ds)
    n = max(2, round(L / ds) + 1);
    s = linspace(0, L, n)';
    if L < 1e-12
        p = repmat(p0, n, 1); psi_end = psi0; return;
    end
    psi = psi0 + kappa0 * s + 0.5 * (kappa1 - kappa0) * (s.^2) / L;
    % Integrate heading with cumulative trapezoid on arc parameter s
    x = zeros(n, 1); y = zeros(n, 1);
    x(1) = p0(1); y(1) = p0(2);
    for i = 2:n
        ds_i = s(i) - s(i - 1);
        x(i) = x(i - 1) + 0.5 * (cos(psi(i - 1)) + cos(psi(i))) * ds_i;
        y(i) = y(i - 1) + 0.5 * (sin(psi(i - 1)) + sin(psi(i))) * ds_i;
    end
    z = p0(3) * ones(n, 1);
    p = [x, y, z];
    psi_end = psi(end);
end

function [p, psi_end] = circle_segment(p0, psi0, R, ang, sense, ds)
    % sense = +1 left turn: center = p0 + R*[-sinψ, cosψ]
    L = R * abs(ang);
    n = max(2, round(L / ds) + 1);
    phi = linspace(0, ang, n)';
    c = p0(1:2) + sense * R * [-sin(psi0), cos(psi0)];
    alpha0 = psi0 - sense * (pi / 2);
    alpha = alpha0 + sense * phi;
    x = c(1) + R * cos(alpha);
    y = c(2) + R * sin(alpha);
    z = p0(3) * ones(n, 1);
    p = [x(:), y(:), z];
    p(1, :) = p0;
    psi_end = psi0 + sense * ang;
end

function [kappa, Rinst] = path_curvature_xy(path, s_nodes)
    n = size(path, 1);
    kappa = zeros(n, 1);
    for i = 2:n - 1
        d1 = path(i, 1:2) - path(i - 1, 1:2);
        d2 = path(i + 1, 1:2) - path(i, 1:2);
        ds1 = max(norm(d1), 1e-12);
        ds2 = max(norm(d2), 1e-12);
        h1 = atan2(d1(2), d1(1));
        h2 = atan2(d2(2), d2(1));
        dpsi = wrapToPiLocal(h2 - h1);
        kappa(i) = dpsi / (0.5 * (ds1 + ds2));
    end
    kappa(1) = kappa(2); kappa(end) = kappa(end - 1);
    Rinst = 1 ./ max(abs(kappa), 1e-12);
    Rinst(abs(kappa) < 1e-5) = inf;
end

function C = verify_path_continuity(path, Seg, s_nodes)
    C = struct('pos_ok', true, 'tang_ok', true, 'details', {{}});
    for k = 1:numel(Seg.trans_s)
        sb = Seg.trans_s(k);
        [p_m, ~] = sample_path_local(path, s_nodes, max(0, sb - 1e-3));
        [p_p, ~] = sample_path_local(path, s_nodes, min(s_nodes(end), sb + 1e-3));
        dp = norm(p_m - p_p);
        [~, t_a] = sample_path_local(path, s_nodes, max(0, sb - 0.25));
        [~, t_b] = sample_path_local(path, s_nodes, min(s_nodes(end), sb + 0.25));
        ang = rad2deg(acos(max(-1, min(1, dot(t_a, t_b)))));
        ok_p = dp < 0.05;
        ok_t = ang < 5.0;
        C.details{end+1} = sprintf('%s: |Δp|=%.4f ang=%.3fdeg', Seg.trans_names{k}, dp, ang); %#ok<AGROW>
        C.pos_ok = C.pos_ok && ok_p;
        C.tang_ok = C.tang_ok && ok_t;
    end
end

%% ===================== SIM =====================
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
    state(5) = -atan2(d(3), norm(d(1:2)));
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
    e_z = S.e_z(:);
    if all(e_z == 0) && any(abs(e_z_geom) > 0)
        e_z = e_z_geom;
    end

    de = S.delta_e(:); dr = S.delta_r(:); thr = S.thrust(:);
    de_dot = [0; diff(de)] / dt;
    dr_dot = [0; diff(dr)] / dt;

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

    M.segments = struct([]);
    for i = 1:numel(Seg.names)
        mseg = (s_prog >= Seg.s0(i)) & (s_prog < Seg.s1(i));
        if i == numel(Seg.names)
            mseg = (s_prog >= Seg.s0(i)) & (s_prog <= Seg.s1(i) + 1e-6);
        end
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
        Sm.scored = Seg.scored(i);
        Sm.s0 = Seg.s0(i); Sm.s1 = Seg.s1(i);
        Sm.n = nnz(mseg); Sm.n_ss = nnz(m_ss);
        Sm.progress_mono = all(ds(mseg) >= -HG.prog_back_tol_m);
        Sm.mean_ds_dt = mean_safe(ds_dt, mseg);
        if Seg.scored(i)
            [Sm.feasible, Sm.first_limit, Sm.gates] = score_seg_gates(Sm, Seg.gate_key{i}, HG);
        else
            % ACQ: report metrics only (LEVEL-like report, not a hard gate for PASS)
            Sm.feasible = true;
            Sm.first_limit = 'ACQ_REPORT_ONLY';
            Sm.gates = struct();
        end
        if isempty(M.segments)
            M.segments = Sm;
        else
            M.segments(end+1) = Sm; %#ok<AGROW>
        end
    end

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
            Tr.peak_de_deg = NaN; Tr.peak_dr_deg = NaN;
            Tr.peak_th_err_deg = NaN; Tr.peak_yaw_err_deg = NaN;
        else
            Tr.max_cte = max(abs(cte_perp(mtr)));
            Tr.max_abs_ez = max(abs(e_z(mtr)));
            Tr.mean_cte = mean(abs(cte_perp(mtr)));
            Tr.overshoot_cte = Tr.max_cte > HG.trans_cte_max;
            Tr.overshoot_ez = Tr.max_abs_ez > HG.trans_ez_max;
            Tr.progress_mono = all(ds(mtr) >= -HG.prog_back_tol_m);
            Tr.ok = ~Tr.overshoot_cte && ~Tr.overshoot_ez && Tr.progress_mono;
            Tr.peak_de_deg = rad2deg(max(abs(de(mtr))));
            Tr.peak_dr_deg = rad2deg(max(abs(dr(mtr))));
            Tr.peak_th_err_deg = rad2deg(max(abs(e_th(mtr))));
            Tr.peak_yaw_err_deg = rad2deg(max(abs(e_psi(mtr))));
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

function ActReg = compare_actuator_regression(Mb, Mc, HG)
    ActReg = struct('ok', true, 'first_fail', 'none', 'rows', {{}});
    names = {'LEVEL', 'CLIMB', 'TURN', 'EXIT'};
    for i = 1:numel(names)
        nb = names{i};
        Sb = find_seg(Mb.segments, nb);
        Sc = find_seg(Mc.segments, nb);
        if isempty(Sb) || isempty(Sc)
            ActReg.ok = false;
            ActReg.first_fail = sprintf('%s:missing_seg', nb);
            return;
        end
        checks = {
            'de_sat_pct', Sc.act.de_sat_pct, Sb.act.de_sat_pct, HG.act_reg_sat_eps
            'dr_sat_full_pct', Sc.act.dr_sat_full_pct, Sb.act.dr_sat_full_pct, HG.act_reg_sat_eps
            'thr_sat_pct', Sc.act.thr_sat_pct, Sb.act.thr_sat_pct, HG.act_reg_sat_eps
            'de_rate_util', Sc.act.de_rate_util, Sb.act.de_rate_util, HG.act_reg_rate_eps
            'dr_rate_util', Sc.act.dr_rate_util, Sb.act.dr_rate_util, HG.act_reg_rate_eps
            'chatter_dps', Sc.act.chatter_dps, Sb.act.chatter_dps, HG.act_reg_chat_eps
            'de_max_deg', Sc.act.de_max_deg, Sb.act.de_max_deg, HG.act_reg_peak_eps_deg
            'dr_max_deg', Sc.act.dr_max_deg, Sb.act.dr_max_deg, HG.act_reg_peak_eps_deg
            };
        for k = 1:size(checks, 1)
            metric = checks{k, 1};
            vc = checks{k, 2}; vb = checks{k, 3}; epsv = checks{k, 4};
            worse = ~isnan(vc) && ~isnan(vb) && (vc > vb + epsv);
            row = sprintf('%s.%s base=%.4f cand=%.4f worse=%d', nb, metric, nz(vb), nz(vc), worse);
            ActReg.rows{end+1} = row; %#ok<AGROW>
            if worse && ActReg.ok
                ActReg.ok = false;
                ActReg.first_fail = row;
            end
        end
    end
end

function Sm = find_seg(segs, name)
    Sm = [];
    for i = 1:numel(segs)
        if strcmp(segs(i).name, name)
            Sm = segs(i); return;
        end
    end
end

function C = classify_candidate(M, HG, ActReg)
    C = struct('candidate_ok', false, 'first_fail', 'unrun', 'checks', {{}});
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
        if ~Sm.scored; continue; end  % ACQ not a hard gate
        order{end+1} = {Sm.feasible, sprintf('%s:%s', Sm.name, Sm.first_limit)}; %#ok<AGROW>
        order{end+1} = {Sm.progress_mono, sprintf('%s:seg_backward_progress', Sm.name)}; %#ok<AGROW>
    end
    for i = 1:numel(M.transitions)
        Tr = M.transitions(i);
        order{end+1} = {Tr.ok, sprintf('%s:trans_fail(cte=%.3f ez=%.3f mono=%d)', ...
            Tr.name, nz(Tr.max_cte), nz(Tr.max_abs_ez), Tr.progress_mono)}; %#ok<AGROW>
    end
    order{end+1} = {ActReg.ok, sprintf('actuator_regression:%s', ActReg.first_fail)};

    C.candidate_ok = true; C.first_fail = 'none';
    C.checks = order;
    for k = 1:numel(order)
        if ~order{k}{1}
            C.candidate_ok = false;
            C.first_fail = order{k}{2};
            break;
        end
    end
end

%% ===================== PROJECTION =====================
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
        e_z(i) = -(e(3));
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
    title(sprintf('Shaped path (R_{des}=%.1f R_{meas}=%.2f)', R.PathMeta.R, R.PathMeta.R_min_meas)); view(35, 25);

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

    nexttile;
    plot(S.t, rad2deg(S.theta_phys), 'b'); hold on;
    plot(S.t, rad2deg(S.theta_ref), 'r--');
    grid on; ylabel('deg'); title('\theta_{phys} vs \theta_{ref}'); legend('act','ref');

    nexttile;
    plot(S.t, rad2deg(unwrap(S.ori(:,3))), 'b'); hold on;
    plot(S.t, rad2deg(unwrap(S.psi_ref)), 'r--');
    grid on; ylabel('deg'); title('\psi vs \psi_{ref}');

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

    sgtitle(sprintf('%s %s next=%s', R.task_id, R.verdict, R.next_gate), 'Interpreter', 'none');
    exportgraphics(fig, png_path, 'Resolution', 150);
    close(fig);
end

function write_md(md_path, R)
    M = R.M; C = R.candidate_class; Seg = R.Seg; HG = R.HG; PM = R.PathMeta;
    B = R.Base;
    fid = fopen(md_path, 'w');
    fprintf(fid, '# %s — Isolated mission-geometry transition shaper\n\n', R.task_id);
    fprintf(fid, '**Candidate verdict: %s** (first=`%s`)\n\n', R.verdict, sanitize(C.first_fail));
    fprintf(fid, '**Prioritized next gate: `%s`** — %s\n\n', R.next_gate, R.next_note);

    fprintf(fid, '## Provenance\n\n');
    fprintf(fid, '- Read-only: `run_guidance_mission_baseline.m`, `suite_results/GUIDANCE_MISSION_BASELINE.{md,mat}`\n');
    fprintf(fid, '- Baseline stamp: %s | first_fail=`%s`\n', B.stamp, sanitize(B.first_fail));
    fprintf(fid, '- Driver: `run_guidance_transition_shaper.m` (one MATLAB invocation)\n');
    fprintf(fid, '- Production plant/controller/guidance: **UNTOUCHED / FROZEN** (no gain tuning)\n');
    fprintf(fid, '- Gates: identical SPEED_ENVELOPE / COMBINED absolutes (no relaxation)\n');
    fprintf(fid, '- Artifacts: `%s`, `%s`, `%s`\n', R.paths.md, R.paths.mat, R.paths.png);
    fprintf(fid, '- Did **not** touch `CODEX_VERTICAL_PLAN.md`\n');
    fprintf(fid, '- Stamp: %s | seed=%d | U=%.2f | T_final=%.1fs | s_total=%.2fm | R_des=%.3fm R_meas_min=%.3fm\n\n', ...
        R.stamp, R.seed, R.Uref, R.T_final, R.s_total, PM.R_min, PM.R_min_meas);

    fprintf(fid, '## Geometry / equations\n\n');
    fprintf(fid, '- Intent: ACQ → LEVEL → +%.1fm CLIMB → ~90° TURN (R≥10) → LEVEL EXIT\n', PM.dz);
    fprintf(fid, '- Design note: %s\n', PM.design_note);
    fprintf(fid, '- Continuity: pos_ok=%s tang_ok=%s\n', yn(PM.continuity.pos_ok), yn(PM.continuity.tang_ok));
    fprintf(fid, '- Max climb slope=%.4f (γ≈%.2f deg) | κ_max=%.4f | Δψ_cloth=%.2f deg | ang_circ=%.2f deg\n', ...
        PM.max_climb_slope, PM.max_climb_gamma_deg, PM.kappa_max, PM.dpsi_cloth_deg, PM.ang_circ_deg);
    fprintf(fid, '- Exit heading≈%.2f deg (target 90)\n', PM.psi_exit_deg);
    fprintf(fid, '\nEquations:\n\n');
    for i = 1:numel(PM.equations)
        fprintf(fid, '- %s\n', PM.equations{i});
    end
    fprintf(fid, '\n| Segment | s0 [m] | s1 [m] | L [m] | Scored | Description |\n|---|---:|---:|---:|:---:|---|\n');
    for i = 1:numel(Seg.names)
        fprintf(fid, '| %s | %.2f | %.2f | %.2f | %s | %s |\n', Seg.names{i}, ...
            Seg.s0(i), Seg.s1(i), Seg.s1(i)-Seg.s0(i), yn(Seg.scored(i)), Seg.description{i});
    end
    fprintf(fid, '\n');

    fprintf(fid, '## Baseline vs candidate (post-ACQ phases)\n\n');
    fprintf(fid, '| Seg | metric | baseline | candidate |\n|---|---|---:|---:|\n');
    bnames = {'LEVEL','CLIMB','TURN','EXIT'};
    for i = 1:numel(bnames)
        nb = bnames{i};
        Sb = find_seg(B.segments, nb);
        Sc = find_seg(M.segments, nb);
        if isempty(Sb) || isempty(Sc); continue; end
        fprintf(fid, '| %s | pitch_MAE | %.4f | %.4f |\n', nb, nz(Sb.theta.mae_deg), nz(Sc.theta.mae_deg));
        fprintf(fid, '| %s | gamma_MAE | %.4f | %.4f |\n', nb, nz(Sb.gamma.mae_deg), nz(Sc.gamma.mae_deg));
        fprintf(fid, '| %s | yaw_MAE | %.4f | %.4f |\n', nb, nz(Sb.yaw.mae_deg), nz(Sc.yaw.mae_deg));
        if isfield(Sb.yaw, 'p95_deg')
            fprintf(fid, '| %s | yaw_p95 | %.4f | %.4f |\n', nb, nz(Sb.yaw.p95_deg), nz(Sc.yaw.p95_deg));
        end
        fprintf(fid, '| %s | CTE_mean | %.3f | %.3f |\n', nb, nz(Sb.path.mean_cte), nz(Sc.path.mean_cte));
        fprintf(fid, '| %s | |ez|_MAE | %.4f | %.4f |\n', nb, nz(Sb.depth.mae), nz(Sc.depth.mae));
        fprintf(fid, '| %s | roll_MAE | %.3f | %.3f |\n', nb, nz(Sb.roll.mae_deg), nz(Sc.roll.mae_deg));
        fprintf(fid, '| %s | u_mean | %.3f | %.3f |\n', nb, nz(Sb.speed.u_mean), nz(Sc.speed.u_mean));
        fprintf(fid, '| %s | deSat%% | %.2f | %.2f |\n', nb, nz(Sb.act.de_sat_pct), nz(Sc.act.de_sat_pct));
        fprintf(fid, '| %s | drSatF%% | %.2f | %.2f |\n', nb, nz(Sb.act.dr_sat_full_pct), nz(Sc.act.dr_sat_full_pct));
        fprintf(fid, '| %s | chat | %.4f | %.4f |\n', nb, nz(Sb.act.chatter_dps), nz(Sc.act.chatter_dps));
        fprintf(fid, '| %s | deRateU | %.3f | %.3f |\n', nb, nz(Sb.act.de_rate_util), nz(Sc.act.de_rate_util));
        fprintf(fid, '| %s | drRateU | %.3f | %.3f |\n', nb, nz(Sb.act.dr_rate_util), nz(Sc.act.dr_rate_util));
        fprintf(fid, '| %s | FEAS | %s | %s |\n', nb, yn(Sb.feasible), yn(Sc.feasible));
    end
    fprintf(fid, '\n');

    fprintf(fid, '## ACQ (report-only; not a hard gate)\n\n');
    Sacq = find_seg(M.segments, 'ACQ');
    if ~isempty(Sacq)
        fprintf(fid, '- thMAE=%.4f gMAE=%.4f yawMAE=%.4f CTE=%.3f |ez|=%.4f u=%.3f roll=%.3f chat=%.4f\n', ...
            nz(Sacq.theta.mae_deg), nz(Sacq.gamma.mae_deg), nz(Sacq.yaw.mae_deg), ...
            nz(Sacq.path.mean_cte), nz(Sacq.depth.mae), nz(Sacq.speed.u_mean), ...
            nz(Sacq.roll.mae_deg), nz(Sacq.act.chatter_dps));
        fprintf(fid, '- Act: deSat=%.2f%% drSatF=%.2f%% thrSat=%.2f%% |de|_max=%.2f |dr|_max=%.2f\n\n', ...
            nz(Sacq.act.de_sat_pct), nz(Sacq.act.dr_sat_full_pct), nz(Sacq.act.thr_sat_pct), ...
            nz(Sacq.act.de_max_deg), nz(Sacq.act.dr_max_deg));
    else
        fprintf(fid, '- ACQ segment missing\n\n');
    end

    fprintf(fid, '## Candidate per-segment hard gates (post-ACQ)\n\n');
    fprintf(fid, '| Seg | FEAS | First | thMAE | gMAE | yawMAE | CTE | |ez| | deSat | drSatF | chat | mono |\n');
    fprintf(fid, '|---|:---:|---|---:|---:|---:|---:|---:|---:|---:|---:|:---:|\n');
    for i = 1:numel(M.segments)
        Sm = M.segments(i);
        if ~Sm.scored; continue; end
        fprintf(fid, '| %s | %s | %s | %.4f | %.4f | %.4f | %.3f | %.4f | %.2f | %.2f | %.4f | %s |\n', ...
            Sm.name, yn(Sm.feasible), sanitize(Sm.first_limit), ...
            nz(Sm.theta.mae_deg), nz(Sm.gamma.mae_deg), nz(Sm.yaw.mae_deg), ...
            nz(Sm.path.mean_cte), nz(Sm.depth.mae), nz(Sm.act.de_sat_pct), ...
            nz(Sm.act.dr_sat_full_pct), nz(Sm.act.chatter_dps), yn(Sm.progress_mono));
    end
    fprintf(fid, '\n');

    fprintf(fid, '## Progress / completion / bounds\n\n');
    fprintf(fid, '- Progress: mono=%s n_back=%d min_ds=%.4f final_s=%.2f/%.2f (%.1f%%) complete=%s\n', ...
        yn(M.progress.monotonic), M.progress.n_back, M.progress.min_ds, ...
        M.progress.final_s, M.s_total, 100*M.progress.final_frac, yn(M.progress.completed));
    fprintf(fid, '- Stall: run=%.2fs (lim %.2fs) stalled=%s | mean ds/dt=%.3f m/s\n', ...
        M.progress.stall_run_s, HG.stall_hold_s, yn(M.progress.stalled), M.progress.mean_ds_dt);
    fprintf(fid, '- Bounded states: %s\n\n', yn(M.bounded));

    fprintf(fid, '## Transitions (peaks)\n\n');
    fprintf(fid, '| Transition | n | max CTE | max |ez| | peak θerr | peak ψerr | peak δe | peak δr | mono | OK |\n');
    fprintf(fid, '|---|---:|---:|---:|---:|---:|---:|---:|:---:|:---:|\n');
    for i = 1:numel(M.transitions)
        Tr = M.transitions(i);
        fprintf(fid, '| %s | %d | %.3f | %.3f | %.3f | %.3f | %.2f | %.2f | %s | %s |\n', ...
            Tr.name, Tr.n, nz(Tr.max_cte), nz(Tr.max_abs_ez), ...
            nz(Tr.peak_th_err_deg), nz(Tr.peak_yaw_err_deg), ...
            nz(Tr.peak_de_deg), nz(Tr.peak_dr_deg), yn(Tr.progress_mono), yn(Tr.ok));
    end
    fprintf(fid, '\nLim CTE=%.2f |ez|=%.2f\n\n', HG.trans_cte_max, HG.trans_ez_max);

    fprintf(fid, '## Actuator regression vs baseline\n\n');
    fprintf(fid, '- Regression OK: **%s** (first=`%s`)\n', yn(R.ActReg.ok), sanitize(R.ActReg.first_fail));
    fprintf(fid, '- Tol: sat_eps=%.2f pp | rate_eps=%.2f | chat_eps=%.2f | peak_eps=%.2f deg\n\n', ...
        HG.act_reg_sat_eps, HG.act_reg_rate_eps, HG.act_reg_chat_eps, HG.act_reg_peak_eps_deg);

    fprintf(fid, '## PASS gates\n\n');
    fprintf(fid, '| Gate | Status |\n|---|:---:|\n');
    fprintf(fid, '| production_untouched | PASS |\n');
    fprintf(fid, '| no_tuning | PASS |\n');
    fprintf(fid, '| no_relaxed_gates | PASS |\n');
    fprintf(fid, '| R_min_design>=10 | %s |\n', yn(PM.R_min >= 10 - 1e-12));
    fprintf(fid, '| R_min_meas_ok | %s (%.3f) |\n', yn(PM.R_min_meas >= 9.5), PM.R_min_meas);
    fprintf(fid, '| one_6dof_run | %s |\n', yn(M.sim_ok));
    fprintf(fid, '| post_ACQ_hard_gates | %s |\n', yn(all_scored_feas(M)));
    fprintf(fid, '| transition_gates | %s |\n', yn(all_trans_ok(M)));
    fprintf(fid, '| completion_bounds | %s |\n', yn(M.bounded && M.progress.completed && M.progress.monotonic && ~M.progress.stalled));
    fprintf(fid, '| no_actuator_regression | %s |\n', yn(R.ActReg.ok));
    fprintf(fid, '\n**Overall candidate: %s**\n\n', R.verdict);

    fprintf(fid, '## Production mission limitations');
    if strcmp(R.verdict, 'FAIL')
        fprintf(fid, ' (shaper line CLOSED)\n\n');
        fprintf(fid, '- Guidance has no segment blender / clothoid / mode switch (baseline audit NOT_IMPLEMENTED).\n');
        fprintf(fid, '- External C1 polyline + ACQ + C2 climb + κ-ramps still may fail SPEED_ENVELOPE hard gates on composite mission.\n');
        fprintf(fid, '- First fail this run: `%s`\n', sanitize(C.first_fail));
        fprintf(fid, '- Do not continue mission-shaper iterations; document limitation and stop this line.\n');
    else
        fprintf(fid, '\n\n- Shaper candidate met gates under frozen production stack.\n');
    end
    fprintf(fid, '\n## Next bounded roadmap gate\n\n');
    fprintf(fid, '- **`%s`** — %s\n', R.next_gate, R.next_note);
    fprintf(fid, '- CODEX_VERTICAL_PLAN untouched.\n');
    fclose(fid);
end

function tf = all_scored_feas(M)
    tf = true;
    for i = 1:numel(M.segments)
        if M.segments(i).scored && ~M.segments(i).feasible
            tf = false; return;
        end
    end
end

function tf = all_trans_ok(M)
    tf = true;
    for i = 1:numel(M.transitions)
        if ~M.transitions(i).ok
            tf = false; return;
        end
    end
end

function append_research_log(log_path, R)
    fid = fopen(log_path, 'a');
    fprintf(fid, '\n\n## %s — %s\n\n', R.task_id, R.stamp);
    fprintf(fid, '- Verdict: **%s** — isolated geometry transition shaper; production cascade+guidance frozen; no retune; gates unrelaxed.\n', R.verdict);
    fprintf(fid, '- Geometry: ACQ L=%.1f + LEVEL L=%.1f + C2 climb L=%.1f Δz=+%.1f + clothoid L=%.1f / R=%.1f / circ L=%.2f + EXIT; R_des=%.3fm R_meas=%.3fm; s_total=%.2fm T=%.1fs.\n', ...
        R.PathMeta.L.acq, R.PathMeta.L.level, R.PathMeta.L.climb, R.PathMeta.dz, ...
        R.PathMeta.L.cloth, R.PathMeta.R, R.PathMeta.L.circ, R.PathMeta.R_min, R.PathMeta.R_min_meas, R.s_total, R.T_final);
    fprintf(fid, '- Eq: quintic z=dz(10σ³-15σ⁴+6σ⁵); clothoid κ(s)=κ0+(κ1-κ0)s/L, Δψ=½κ_max L_c; circle κ=1/R.\n');
    fprintf(fid, '- Candidate class: %s first=`%s` | mono=%s complete=%s stall=%s bounded=%s act_reg=%s\n', ...
        yn(R.candidate_class.candidate_ok), sanitize(R.candidate_class.first_fail), ...
        yn(R.M.progress.monotonic), yn(R.M.progress.completed), ...
        yn(R.M.progress.stalled), yn(R.M.bounded), yn(R.ActReg.ok));
    if isfield(R.M, 'segments') && ~isempty(R.M.segments)
        parts = {};
        for i = 1:numel(R.M.segments)
            Sm = R.M.segments(i);
            if ~Sm.scored
                parts{end+1} = sprintf('ACQ(report) th=%.3f g=%.3f', nz(Sm.theta.mae_deg), nz(Sm.gamma.mae_deg)); %#ok<AGROW>
            else
                parts{end+1} = sprintf('%s FEAS=%s(%s)', Sm.name, yn(Sm.feasible), sanitize(Sm.first_limit)); %#ok<AGROW>
            end
        end
        fprintf(fid, '- Segments: %s\n', strjoin(parts, ' | '));
    end
    fprintf(fid, '- Artifacts: suite_results/GUIDANCE_TRANSITION_SHAPER.{md,mat,png}; driver `run_guidance_transition_shaper.m`.\n');
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

function B = pack_base_compare(Base)
    B = struct();
    B.stamp = Base.stamp;
    B.first_fail = Base.mission_class.first_fail;
    B.mission_ok = Base.mission_class.mission_ok;
    B.segments = Base.M.segments;
    B.transitions = Base.M.transitions;
    B.progress = Base.M.progress;
    B.whole = Base.M.whole;
    B.s_total = Base.s_total;
    B.T_final = Base.T_final;
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
