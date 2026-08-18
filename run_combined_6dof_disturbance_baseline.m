function run_combined_6dof_disturbance_baseline()
% COMBINED_6DOF_DISTURBANCE_BASELINE_001 — PLANT-DISTURBANCE + ESTIMATOR baseline.
% Read-only: run_bounded_current_hook.m, run_current_observer_bias_latency.m,
%   suite_results/SPEED_ENVELOPE_AUDIT.md (+ prior PASS mats).
% Current hook PASS; offline bias/latency observer PASS. Production FROZEN.
%
% Label: PLANT-DISTURBANCE + ESTIMATOR (observer offline ONLY — NOT sensor-in-loop).
% Controller/guidance always use plant truth; Vhat never fed to control.
%
% One nonlinear 6DOF @ U=1.5 on X / XZ / R10:
%   no-current production plant  vs  isolated Vc=[0,0.15,0] NED (current hook).
% Declared INS/DVL noise+bias+latency observer harness offline on current trajs.
% Two deterministic repeats (clear persistent + RNG); require identity.
% Absolute SPEED_ENVELOPE hard gates + <=2% regression vs SPEED_ENVELOPE U=1.5
%   on no-current (where applicable) + observer prior gates.
% PASS = repeats identical AND states bounded AND route/actuator hard gates on
%   CURRENT case AND observer prior gates. Else first limit + next architecture.
% No tuning / production edits. Does NOT touch CODEX_VERTICAL_PLAN.md.
% Artifacts: suite_results/COMBINED_6DOF_DISTURBANCE_BASELINE.{md,mat,png}
% Appends suite_results/PITCH_CONTROL_RESEARCH_LOG.md

    project_dir = fileparts(mfilename('fullpath'));
    addpath(project_dir);
    out_dir = fullfile(project_dir, 'suite_results');
    if ~exist(out_dir, 'dir'); mkdir(out_dir); end
    tag = 'COMBINED_6DOF_DISTURBANCE_BASELINE';
    task_id = 'COMBINED_6DOF_DISTURBANCE_BASELINE_001';

    hook_mat = fullfile(out_dir, 'BOUNDED_CURRENT_HOOK.mat');
    bl_mat   = fullfile(out_dir, 'CURRENT_OBSERVER_BIAS_LATENCY.mat');
    speed_md = fullfile(out_dir, 'SPEED_ENVELOPE_AUDIT.md');
    assert(exist(hook_mat, 'file') == 2, 'Missing %s', hook_mat);
    assert(exist(bl_mat, 'file') == 2, 'Missing %s', bl_mat);
    assert(exist(speed_md, 'file') == 2, 'Missing %s', speed_md);
    Hook = load(hook_mat);
    BiasLat = load(bl_mat);
    assert(strcmp(Hook.verdict, 'PASS'), 'BOUNDED_CURRENT_HOOK must be PASS');
    assert(strcmp(BiasLat.verdict, 'PASS'), 'CURRENT_OBSERVER_BIAS_LATENCY must be PASS');

    fprintf('\n========== %s ==========\n', task_id);
    fprintf('PLANT-DISTURBANCE + ESTIMATOR baseline (NOT sensor-in-loop).\n');
    fprintf('Vc=[0,0.15,0] NED; U=1.5; observer offline; production frozen.\n');

    clear functions
    clear guidance_law controller_law
    clear underwater777_vehicle_dynamics underwater777_vehicle_dynamics_current
    clear global lambda_muw_ff trim_speed_table trim_elevator_table elevator_sign
    clear global K_zdot K_gamma enable_alpha_hat Kp_roll
    clear global plant_Vc plant_last_nu plant_last_nu_c plant_last_nu_r
    clear global plant_last_V_g_ned plant_last_V_w_body plant_last_forces

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
    assert(abs(desired_speed - 1.5) < 1e-12, 'desired_speed must be 1.5');

    Uref = 1.5;
    Vc_zero = [0; 0; 0];
    Vc_cross = [0; 0.15; 0];
    seed_plant = 0;
    seed_obs = 42;

    lim = struct( ...
        'dr_max', delta_r_max, 'de_max', delta_e_max, ...
        'dr_rate', deg2rad(40), 'de_rate', deg2rad(40), ...
        'thrust_max', thrust_max, 'thrust_min', thrust_min);

    HG = struct();
    HG.X.pitch_mae = 0.10; HG.X.pitch_p95 = 0.50; HG.X.gamma_mae = 0.50; HG.X.gamma_p95 = 1.00;
    HG.XZ.pitch_mae = 0.30; HG.XZ.pitch_p95 = 0.50; HG.XZ.gamma_mae = 1.00; HG.XZ.gamma_p95 = 1.50;
    HG.H.pitch_mae = 0.30; HG.H.pitch_p95 = 0.50; HG.H.gamma_mae = 1.50; HG.H.gamma_p95 = 2.50;
    HG.H.yaw_mae = 1.0; HG.H.yaw_p95 = 2.0;
    HG.elev_sat = 1.0; HG.rud_sat_ss = 1.0; HG.rud_sat_full = 1.0;
    HG.chatter = 0.20; HG.ratio_lo = 0.98; HG.ratio_hi = 1.02;
    HG.rate_util = 1.0; HG.thrust_sat = 1.0;
    HG.phi_eq = struct('X', 0.0, 'XZ', 0.0, 'H', 0.0255);
    HG.reg_frac = 0.02;  % <=2% regression vs SPEED_ENVELOPE U=1.5 (no-current)

    % SPEED_ENVELOPE U=1.5 reference (from SPEED_ENVELOPE_AUDIT.md)
    Ref = struct();
    Ref.X  = struct('thMAE', 0.0110, 'thP95', 0.0419, 'gMAE', 0.3305, 'gP95', 0.7032, ...
        'yawMAE', 0.0000, 'CTE', 0.247, 'deSat', 0.00, 'drSatF', 0.00, 'chat', 0.1530);
    Ref.XZ = struct('thMAE', 0.1214, 'thP95', 0.4024, 'gMAE', 0.4182, 'gP95', 0.7273, ...
        'yawMAE', 0.0000, 'CTE', 0.372, 'deSat', 0.00, 'drSatF', 0.00, 'chat', 0.1955);
    Ref.H  = struct('thMAE', 0.0411, 'thP95', 0.0986, 'gMAE', 0.6584, 'gP95', 1.3785, ...
        'yawMAE', 0.1740, 'CTE', 0.269, 'deSat', 0.00, 'drSatF', 0.67, 'chat', 0.1501);

    n = 600; x = linspace(0, 45, n)'; pathX = [x, zeros(n,1), zeros(n,1)];
    n = 900; tt = linspace(0, 42, n)'; pathXZ = [tt, zeros(n,1), 0.4*tt];
    pathH = generate_balanced_helical_path(10.0, 2.0, 2, 500);
    routes = {
        struct('name','X',  'key','X',  'path',pathX,  'T',18, 'lambda',0.25, ...
            'win','first_hold', 'R',0,  'is_xz',false)
        struct('name','XZ', 'key','XZ', 'path',pathXZ, 'T',22, 'lambda',0.0,  ...
            'win','persistent', 'R',0,  'is_xz',true)
        struct('name','R10','key','H',  'path',pathH,  'T',45, 'lambda',0.25, ...
            'win','persistent', 'R',10, 'is_xz',false)
    };

    % Observer (identical declared bias+latency harness; no tuning)
    obs = struct();
    obs.wo = 0.50; obs.Vhat0 = [0;0;0]; obs.V_bound = 0.5;
    obs.settle_frac = 0.02; obs.steady_t0 = 10.0;
    obs.ins_sigma = 0.020; obs.ins_fs = 20;
    obs.dvl_sigma = 0.010; obs.dvl_fs = 5;
    obs.ins_bias_ned = [+0.010; -0.005; +0.005];
    obs.ins_latency_s = 0.050;
    obs.dvl_bias_body = [+0.005; 0.000; -0.003];
    obs.dvl_latency_s = 0.200;
    obs.seed = seed_obs;

    Results = struct();
    Results.task_id = task_id;
    Results.label = 'PLANT-DISTURBANCE + ESTIMATOR (offline observer; NOT sensor-in-loop)';
    Results.Uref = Uref;
    Results.Vc_cross = Vc_cross;
    Results.seed_plant = seed_plant;
    Results.seed_obs = seed_obs;
    Results.fed_to_control = false;
    Results.production_untouched = true;
    Results.HG = HG;
    Results.Ref_speed_envelope_U15 = Ref;
    Results.observer_cfg = obs;
    Results.repeats = cell(1, 2);

    for irep = 1:2
        fprintf('\n---- REPEAT %d/2 ----\n', irep);
        reset_all_persistents();
        rng(seed_plant, 'twister');

        Rep = struct();
        Rep.routes = struct();

        for i = 1:numel(routes)
            r = routes{i};
            fprintf('  Route %s: no-current + current...\n', r.name);
            rng(seed_plant, 'twister');
            Sp = sim_route(r, Uref, Vc_zero, @underwater777_vehicle_dynamics, false);
            rng(seed_plant, 'twister');
            Sc = sim_route(r, Uref, Vc_cross, @underwater777_vehicle_dynamics_current, true);

            Mp = analyze_route(Sp, r, lim, HG);
            Mc = analyze_route(Sc, r, lim, HG);
            Fp = score_feasible(Mp, r.key, HG, lim);
            Fc = score_feasible(Mc, r.key, HG, lim);
            Reg = regression_vs_ref(Mp, Ref.(r.key), HG.reg_frac);

            RR = struct();
            RR.name = r.name; RR.key = r.key;
            RR.prod = pack_S(Sp); RR.curr = pack_S(Sc);
            RR.M_prod = Mp; RR.M_curr = Mc;
            RR.feas_prod = Fp; RR.feas_curr = Fc;
            RR.reg_vs_speed_env = Reg;
            RR.before_after = before_after(Mp, Mc);
            Rep.routes.(r.name) = RR;

            fprintf('    prod FEAS=%s first=%s | thMAE=%.4f yawMAE=%.4f CTE=%.3f\n', ...
                yn(Fp.feasible), Fp.first_limit, nz(Mp.theta.mae_deg), nz(Mp.yaw.mae_deg), nz(Mp.path.mean_cte));
            fprintf('    curr FEAS=%s first=%s | thMAE=%.4f yawMAE=%.4f CTE=%.3f ez=%.4f\n', ...
                yn(Fc.feasible), Fc.first_limit, nz(Mc.theta.mae_deg), nz(Mc.yaw.mae_deg), ...
                nz(Mc.path.mean_cte), nz(Mc.depth.e_z_rms));
        end

        % Offline observer on CURRENT trajectories (declared harness)
        rng(seed_obs, 'twister');
        Rep.obs = struct();
        for i = 1:numel(routes)
            nm = routes{i}.name;
            S = Rep.routes.(nm).curr;
            O = run_bias_latency_observer(S, obs, Vc_cross);
            O.name = nm;
            Rep.obs.(nm) = O;
            fprintf('    obs %s: bias=%.3e rmse=%.3e p95=%.3e final=%.3e hits=%d\n', ...
                nm, O.steady.bias_norm, O.steady.rmse_norm, O.steady.p95_norm, ...
                O.err_final_norm, O.bound_hits);
        end
        Results.repeats{irep} = Rep;
    end

    % ---- Identity (rep1 vs rep2) ----
    Id = check_identity(Results.repeats{1}, Results.repeats{2}, routes);
    Results.identity = Id;
    fprintf('\nIdentity max|Δ| state=%.3e obs=%.3e pass=%d\n', ...
        Id.max_state, Id.max_obs, Id.pass);

    % Official = repeat 1
    Off = Results.repeats{1};
    Results.official = Off;

    % ---- Observer prior gates (declared bias+latency) ----
    names = {'X','XZ','R10'};
    bias_max = 0; rmse_max = 0; p95_max = 0; fin_max = 0; hits_tot = 0;
    for i = 1:3
        O = Off.obs.(names{i});
        bias_max = max(bias_max, O.steady.bias_norm);
        rmse_max = max(rmse_max, O.steady.rmse_norm);
        p95_max = max(p95_max, O.steady.p95_norm);
        fin_max = max(fin_max, O.err_final_norm);
        hits_tot = hits_tot + O.bound_hits;
    end
    Results.obs_summary = struct( ...
        'bias_norm_max_all', bias_max, 'rmse_norm_max_all', rmse_max, ...
        'p95_norm_max_all', p95_max, 'final_err_max_all', fin_max, ...
        'bound_hits_total', hits_tot);

    % ---- Aggregate gates ----
    gates = struct();
    gates.repeats_identical = Id.pass;
    gates.states_bounded = true;
    gates.route_actuator_hard_current = true;
    gates.no_current_hard = true;
    gates.no_current_reg_le_2pct = true;
    gates.observer_prior = true;
    gates.offline_not_in_loop = ~Results.fed_to_control;
    gates.production_untouched = true;

    first_limit = 'none';
    order = {};
    order{end+1} = {Id.pass, sprintf('repeat_identity(max|dS|=%.3e,max|dObs|=%.3e)', Id.max_state, Id.max_obs)};

    for i = 1:3
        nm = names{i}; rr = Off.routes.(nm);
        gates.states_bounded = gates.states_bounded && rr.M_prod.bounded && rr.M_curr.bounded;
        order{end+1} = {rr.M_curr.bounded, sprintf('%s:states_unbounded', nm)}; %#ok<AGROW>

        gates.route_actuator_hard_current = gates.route_actuator_hard_current && rr.feas_curr.feasible;
        if ~rr.feas_curr.feasible && strcmp(first_limit, 'none')
            first_limit = sprintf('%s_curr:%s', nm, rr.feas_curr.first_limit);
        end
        order{end+1} = {rr.feas_curr.feasible, sprintf('%s_curr:%s', nm, rr.feas_curr.first_limit)}; %#ok<AGROW>

        gates.no_current_hard = gates.no_current_hard && rr.feas_prod.feasible;
        order{end+1} = {rr.feas_prod.feasible, sprintf('%s_prod:%s', nm, rr.feas_prod.first_limit)}; %#ok<AGROW>

        gates.no_current_reg_le_2pct = gates.no_current_reg_le_2pct && rr.reg_vs_speed_env.pass;
        if ~rr.reg_vs_speed_env.pass
            order{end+1} = {false, sprintf('%s_prod_reg:%s', nm, rr.reg_vs_speed_env.first)}; %#ok<AGROW>
        else
            order{end+1} = {true, sprintf('%s_prod_reg:ok', nm)}; %#ok<AGROW>
        end
    end

    obs_ok = (bias_max <= 0.030) && (rmse_max <= 0.035) && (p95_max <= 0.070) && ...
        (fin_max <= 0.050) && (hits_tot == 0);
    gates.observer_prior = obs_ok;
    order{end+1} = {obs_ok, sprintf('observer(bias=%.3e rmse=%.3e p95=%.3e final=%.3e hits=%d)', ...
        bias_max, rmse_max, p95_max, fin_max, hits_tot)};

    % Fill first_limit from order if still none
    all_pass = true;
    for k = 1:numel(order)
        if ~order{k}{1}
            all_pass = false;
            if strcmp(first_limit, 'none')
                first_limit = order{k}{2};
            end
            break;
        end
    end
    % Also scan remaining for completeness of all_pass
    for k = 1:numel(order)
        all_pass = all_pass && logical(order{k}{1});
    end

    % Strict PASS per task: repeats identical + bounded + CURRENT hard + observer.
    % No-current hard + <=2% vs SPEED_ENVELOPE are applicable sanity guards (reported;
    % fail them only if they fail while still contributing first_limit priority after core).
    pass_core = gates.repeats_identical && gates.states_bounded && ...
        gates.route_actuator_hard_current && gates.observer_prior && ...
        gates.offline_not_in_loop && gates.production_untouched;
    pass_sanity = gates.no_current_hard && gates.no_current_reg_le_2pct;
    pass_full = pass_core && pass_sanity;

    % Rebuild first_limit with core priority, then sanity
    first_limit = 'none';
    core_order = {};
    core_order{end+1} = {gates.repeats_identical, sprintf('repeat_identity(max|dS|=%.3e,max|dObs|=%.3e)', Id.max_state, Id.max_obs)};
    for i = 1:3
        nm = names{i}; rr = Off.routes.(nm);
        core_order{end+1} = {rr.M_curr.bounded, sprintf('%s:states_unbounded', nm)}; %#ok<AGROW>
        core_order{end+1} = {rr.feas_curr.feasible, sprintf('%s_curr:%s', nm, rr.feas_curr.first_limit)}; %#ok<AGROW>
    end
    core_order{end+1} = {obs_ok, sprintf('observer(bias=%.3e rmse=%.3e p95=%.3e final=%.3e hits=%d)', ...
        bias_max, rmse_max, p95_max, fin_max, hits_tot)};
    for k = 1:numel(core_order)
        if ~core_order{k}{1}
            first_limit = core_order{k}{2};
            break;
        end
    end
    if strcmp(first_limit, 'none') && ~pass_sanity
        for i = 1:3
            nm = names{i}; rr = Off.routes.(nm);
            if ~rr.feas_prod.feasible
                first_limit = sprintf('%s_prod:%s', nm, rr.feas_prod.first_limit); break;
            end
            if ~rr.reg_vs_speed_env.pass
                first_limit = sprintf('%s_prod_reg:%s', nm, rr.reg_vs_speed_env.first); break;
            end
        end
    end

    verdict = tern(pass_full, 'PASS', 'FAIL');
    if strcmp(first_limit, 'none') && ~pass_full
        first_limit = 'unknown_gate_fail';
    end

    Results.gates = gates;
    Results.verdict = verdict;
    Results.first_limit = first_limit;
    Results.pass_core = pass_core;
    Results.pass_sanity = pass_sanity;
    Results.pass_full = pass_full;

    % Next roadmap
    if strcmp(verdict, 'PASS')
        Results.next = struct( ...
            'gate', 'guidance_mission_baseline', ...
            'detail', ['Combined PLANT-DISTURBANCE+ESTIMATOR baseline PASS. ', ...
                'Next bounded roadmap gate: guidance/mission baseline ', ...
                '(production frozen; observer remains offline).'], ...
            'architecture', 'guidance_mission');
    else
        % Classify: observer fail => sensor-in-loop arch; else crab/current FF
        is_obs = contains(lower(first_limit), 'observer') || ~gates.observer_prior;
        if is_obs && gates.route_actuator_hard_current
            Results.next = struct( ...
                'gate', 'sensor_in_loop_architecture_candidate', ...
                'detail', ['FAIL first=`' first_limit '`. Observer prior failed while ', ...
                    'plant hard gates held → next: one isolated sensor-in-loop architecture ', ...
                    'candidate (still not production).'], ...
                'architecture', 'sensor_in_loop');
        else
            Results.next = struct( ...
                'gate', 'isolated_current_compensation_candidate', ...
                'detail', ['FAIL first=`' first_limit '`. Plant tracking/actuator limit under ', ...
                    'Vc cross-current → next: ONE isolated crab/current feedforward ', ...
                    'compensation candidate (production frozen; observer stays offline).'], ...
                'architecture', 'crab_current_feedforward');
        end
    end

    md_path  = fullfile(out_dir, [tag '.md']);
    mat_path = fullfile(out_dir, [tag '.mat']);
    png_path = fullfile(out_dir, [tag '.png']);
    log_path = fullfile(out_dir, 'PITCH_CONTROL_RESEARCH_LOG.md');
    Results.paths = struct('md', md_path, 'mat', mat_path, 'png', png_path);

    write_png(png_path, Off, task_id, verdict, Vc_cross);
    write_md(md_path, Results, lim);
    append_research_log(log_path, Results);
    save(mat_path, '-struct', 'Results', '-v7.3');

    fprintf('\nVERDICT: %s | first_limit=%s\n', verdict, first_limit);
    fprintf('Next: %s (%s)\n', Results.next.gate, Results.next.architecture);
    fprintf('Saved: %s\n%s\n%s\n', md_path, mat_path, png_path);
    print_feedback(Results);
end

%% ===================== reset =====================
function reset_all_persistents()
    clear guidance_law controller_law
    clear underwater777_vehicle_dynamics underwater777_vehicle_dynamics_current
    clear global last_guidance_U_h last_guidance_kappa last_r_ff
    clear global last_delta_e last_delta_r last_dr_yaw last_dr_p last_dr_damp last_g_ac
    clear global last_int_angle last_int_rate last_rate_filt last_theta_phys_dot
    clear global last_de_uw_ff last_de_fb last_de_trim
    clear global last_M_uw last_M_elev last_M_e_ff last_G_de last_e_theta last_theta_phys
    clear global last_gamma_actual last_gamma_path last_alpha_eff last_e_gamma
    clear global last_e_z last_e_zdot last_zdot_inertial last_alpha_hat
    clear global plant_Vc plant_last_nu plant_last_nu_c plant_last_nu_r
    clear global plant_last_V_g_ned plant_last_V_w_body plant_last_forces
    clear global suite_delta_e_log suite_delta_r_log suite_u_log suite_w_log
    clear global suite_e_z_log suite_e_zdot_log suite_zdot_inertial_log
    clear global suite_gamma_actual_log suite_e_gamma_log
    clear global suite_rate_filt_log suite_rate_raw_log
    clear global suite_theta_phys_log suite_e_theta_log suite_pitch_refs_log
    global last_guidance_U_h last_guidance_kappa last_r_ff
    global last_delta_e last_delta_r last_dr_yaw last_dr_p last_dr_damp last_g_ac
    global last_int_angle last_int_rate last_de_fb last_de_trim last_de_uw_ff
    last_guidance_U_h = []; last_guidance_kappa = []; last_r_ff = [];
    last_delta_e = []; last_delta_r = [];
    last_dr_yaw = []; last_dr_p = []; last_dr_damp = []; last_g_ac = [];
    last_int_angle = []; last_int_rate = [];
    last_de_fb = []; last_de_trim = []; last_de_uw_ff = [];
end

%% ===================== simulate =====================
function S = sim_route(r, Uref, Vc, plant_fn, log_current)
    global dt_controller dt_guidance lambda_muw_ff plant_Vc
    global last_delta_e last_delta_r last_e_z last_e_zdot last_zdot_inertial
    global last_gamma_actual last_e_gamma last_e_theta last_theta_phys
    global last_rate_filt last_theta_phys_dot
    global last_guidance_U_h last_guidance_kappa last_r_ff
    global plant_last_nu plant_last_nu_c plant_last_nu_r
    global plant_last_V_g_ned plant_last_V_w_body
    global thrust_max thrust_min

    lambda_muw_ff = r.lambda;
    plant_Vc = Vc(:);
    clear guidance_law controller_law
    % re-declare after clear
    global last_delta_e last_delta_r last_e_z last_e_zdot last_zdot_inertial
    global last_gamma_actual last_e_gamma last_e_theta last_theta_phys
    global last_rate_filt last_theta_phys_dot
    global last_guidance_U_h last_guidance_kappa last_r_ff
    global plant_last_nu plant_last_nu_c plant_last_nu_r
    global plant_last_V_g_ned plant_last_V_w_body
    last_delta_e = []; last_delta_r = [];
    last_e_z = []; last_e_zdot = []; last_zdot_inertial = [];
    last_gamma_actual = []; last_e_gamma = [];
    last_e_theta = []; last_theta_phys = [];
    last_rate_filt = []; last_theta_phys_dot = [];
    last_guidance_U_h = []; last_guidance_kappa = []; last_r_ff = [];

    path = r.path;
    T_final = r.T;
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
    S.dt = dt; S.T_final = T_final; S.u0 = Uref; S.R = r.R; S.is_xz = r.is_xz;
    S.Uref = Uref; S.Vc = Vc(:)'; S.lambda = r.lambda; S.win = r.win;
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
    S.gamma = zeros(n_steps, 1); S.e_gamma = zeros(n_steps, 1);
    S.e_theta = zeros(n_steps, 1); S.theta_phys = zeros(n_steps, 1);
    S.nu = zeros(n_steps, 6); S.nu_c = zeros(n_steps, 6); S.nu_r = zeros(n_steps, 6);
    S.V_ground_ned = zeros(n_steps, 3); S.V_water_body = zeros(n_steps, 3);

    ok = true;
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
        controls = struct('delta_r', dr, 'delta_e', de, 'thrust', thr);

        try
            [~, g] = ode45(@(tt, gg) plant_fn(tt, gg, controls), [0 dt], state);
            state = g(end, :)';
        catch
            ok = false; n_steps = k - 1; break;
        end
        if any(~isfinite(state))
            ok = false; n_steps = k - 1; break;
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
        S.Uh(k) = Uh; S.VD(k) = VD;
        if isempty(last_guidance_U_h); last_guidance_U_h = Uh; end
        if isempty(last_guidance_kappa)
            if r.R > 0; last_guidance_kappa = 1 / r.R; else; last_guidance_kappa = 0; end
        end
        if isempty(last_r_ff); last_r_ff = r_ff; end
        S.U_h_guid(k) = last_guidance_U_h;
        S.kappa(k) = last_guidance_kappa;
        S.r(k) = rates(3);

        if isempty(last_e_z); last_e_z = 0; end
        if isempty(last_e_zdot); last_e_zdot = 0; end
        if isempty(last_gamma_actual); last_gamma_actual = 0; end
        if isempty(last_e_gamma); last_e_gamma = 0; end
        if isempty(last_e_theta); last_e_theta = 0; end
        if isempty(last_theta_phys); last_theta_phys = theta_phys_now; end
        S.e_z(k) = last_e_z;
        S.e_zdot(k) = last_e_zdot;
        S.gamma(k) = last_gamma_actual;
        S.e_gamma(k) = last_e_gamma;
        S.e_theta(k) = last_e_theta;
        S.theta_phys(k) = last_theta_phys;

        if log_current
            if isempty(plant_last_nu); plant_last_nu = state(7:12); end
            if isempty(plant_last_nu_c); plant_last_nu_c = zeros(6,1); end
            if isempty(plant_last_nu_r); plant_last_nu_r = plant_last_nu; end
            if isempty(plant_last_V_g_ned); plant_last_V_g_ned = zeros(3,1); end
            if isempty(plant_last_V_w_body); plant_last_V_w_body = state(7:9)'; end
            S.nu(k, :) = plant_last_nu(:)';
            S.nu_c(k, :) = plant_last_nu_c(:)';
            S.nu_r(k, :) = plant_last_nu_r(:)';
            S.V_ground_ned(k, :) = plant_last_V_g_ned(:)';
            S.V_water_body(k, :) = plant_last_V_w_body(:)';
        else
            S.nu(k, :) = state(7:12);
            S.nu_c(k, :) = 0;
            S.nu_r(k, :) = state(7:12);
            S.V_ground_ned(k, :) = (rotmat(state(4), state(5), state(6)) * state(7:9))';
            S.V_water_body(k, :) = state(7:9)';
        end
    end

    trim = @(A) A(1:n_steps, :);
    trim1 = @(A) A(1:n_steps);
    fn = fieldnames(S);
    for i = 1:numel(fn)
        A = S.(fn{i});
        if isnumeric(A) && size(A, 1) >= n_steps && size(A, 1) > 1
            if size(A, 2) > 1
                S.(fn{i}) = trim(A);
            elseif numel(A) >= n_steps
                S.(fn{i}) = trim1(A);
            end
        end
    end
    S.ok = ok;
    S.finite = ok && all(isfinite(S.vp(:))) && all(isfinite(S.vel(:))) && all(isfinite(S.ori(:)));
    S.u_body = S.vel(:, 1); S.v_body = S.vel(:, 2); S.w_body = S.vel(:, 3);
end

function [Uh, zdot, VD] = inertial_Uh_zdot_vd(ori, u, v, w)
    pd = rotmat(ori(1), ori(2), ori(3)) * [u; v; w];
    Uh = hypot(pd(1), pd(2));
    zdot = pd(3);
    VD = pd(3);
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

%% ===================== analyze / gates =====================
function M = analyze_route(S, r, lim, HG)
    t = S.t(:); dt = S.dt; n = numel(t);
    M = struct('ok', false, 'bounded', false, 'sim_ok', S.ok && S.finite);
    if n < 10 || ~S.finite
        M = fail_M(M); return;
    end
    phi = S.ori(:, 1);
    theta_phys = -S.ori(:, 2);
    psi = S.ori(:, 3);
    p = S.rates(:, 1);
    de = S.delta_e(:); dr = S.delta_r(:);
    e_psi = wrapToPi(S.psi_ref - psi);
    e_th = wrapToPi(S.theta_ref - theta_phys);
    phi_eq = HG.phi_eq.(r.key);
    tilde = phi - phi_eq;
    e_u = S.u_ref - S.u_ctrl;

    gamma_act = atan2(S.VD, max(S.Uh, 1e-9));
    [gamma_ref, cte_perp, s_prog, s_total] = path_gamma_cte(r.path, S.vp);
    e_gamma = wrapToPi(gamma_ref - gamma_act);

    W = compute_pitch_window_metrics(t, e_th, s_prog, s_total, 'mode', r.win);
    mask_ss = W.mask_steady;
    if ~any(mask_ss)
        mask_ss = (t >= 5.0) & W.mask_before_end;
    end
    mask_yaw = (t >= 5.0) & W.mask_before_end;
    if ~any(mask_yaw); mask_yaw = t >= 5.0; end
    mask_hold = mask_ss & (abs(S.u_ref - S.Uref) <= 0.08);
    if ~any(mask_hold); mask_hold = mask_ss; end
    mask_full = true(n, 1);

    de_dot = [0; diff(de)] / dt;
    dr_dot = [0; diff(dr)] / dt;
    thr_dot = [0; diff(S.thrust)] / dt;

    M.ok = true;
    M.W = W; M.mask_ss = mask_ss;
    M.speed = err_stats_lin(e_u, mask_hold);
    M.speed.u_mean = mean_safe(S.u_ctrl, mask_hold);
    M.theta = err_stats_deg(e_th, mask_ss);
    M.gamma = err_stats_deg(e_gamma, mask_ss);
    M.yaw = err_stats_deg(e_psi, mask_yaw);
    Rhel = r.R;
    sat_thr_r = tern(Rhel > 0, 0.95 * lim.dr_max, 0.98 * lim.dr_max);
    M.yaw.rudder_sat_ss_pct = sat_pct(dr, mask_yaw, sat_thr_r);
    M.yaw.rudder_sat_full_pct = sat_pct(dr, mask_full, sat_thr_r);
    if Rhel > 0
        Uh_k = S.U_h_guid(:) .* S.kappa(:);
        valid_ratio = mask_yaw & (abs(S.kappa(:)) > 1e-4) & (abs(S.U_h_guid(:)) > 0.3);
        if any(valid_ratio)
            mean_r = mean(S.r(valid_ratio));
            mean_Uh_k = mean(Uh_k(valid_ratio));
            if mean_Uh_k < 0; mean_Uh_k = -mean_Uh_k; mean_r = -mean_r; end
            M.yaw.ratio_r_Uh_kappa = mean_r / max(abs(mean_Uh_k), 1e-9);
            M.yaw.n_ratio_valid = nnz(valid_ratio);
        else
            M.yaw.ratio_r_Uh_kappa = NaN; M.yaw.n_ratio_valid = 0;
        end
    else
        M.yaw.ratio_r_Uh_kappa = NaN; M.yaw.n_ratio_valid = 0;
    end
    M.roll = struct('tilde_mae_deg', rad2deg(mean_safe(abs(tilde), mask_ss)), ...
        'p_rms_dps', rad2deg(rms_safe(p(mask_ss))));
    M.path = struct('mean_cte', mean_safe(abs(cte_perp), mask_ss), ...
        'max_cte', max_safe(abs(cte_perp), mask_ss));
    M.depth = struct( ...
        'e_z_rms', rms_safe(S.e_z(mask_ss)), ...
        'e_z_mae', mean_safe(abs(S.e_z), mask_ss), ...
        'e_z_p95', prctile_local(abs(S.e_z(mask_ss)), 95));

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
        M.act.chatter_dps = rad2deg(std(hf_local(detrend(e_th(mask_ss)), dt)));
    else
        M.act.chatter_dps = NaN;
    end

    st = [S.ori, S.vel, S.rates];
    M.bounded = all(isfinite(st(:))) && all(isfinite(S.thrust)) && ...
        all(abs(theta_phys) < deg2rad(80)) && all(abs(S.u_body) < 5.0) && ...
        all(abs(S.rates(:)) < deg2rad(200));
    M.trim = struct('documented', true, 'pass', true, 'norm_dyn', 0, ...
        'note', 'trim residual deferred; SPEED_ENVELOPE documented at U=1.5');
end

function M = fail_M(M)
    M.speed = struct('mae', NaN, 'p95', NaN);
    M.theta = struct('mae_deg', NaN, 'p95_deg', NaN);
    M.gamma = struct('mae_deg', NaN, 'p95_deg', NaN);
    M.yaw = struct('mae_deg', NaN, 'p95_deg', NaN, 'rudder_sat_ss_pct', NaN, ...
        'rudder_sat_full_pct', NaN, 'ratio_r_Uh_kappa', NaN, 'n_ratio_valid', 0);
    M.roll = struct('tilde_mae_deg', NaN, 'p_rms_dps', NaN);
    M.path = struct('mean_cte', NaN, 'max_cte', NaN);
    M.depth = struct('e_z_rms', NaN, 'e_z_mae', NaN, 'e_z_p95', NaN);
    M.act = struct('de_mag_util', NaN, 'dr_mag_util', NaN, 'thr_mag_util', NaN, ...
        'de_rate_util', NaN, 'dr_rate_util', NaN, 'thr_rate_util', NaN, ...
        'de_sat_pct', NaN, 'dr_sat_ss_pct', NaN, 'dr_sat_full_pct', NaN, ...
        'thr_sat_pct', NaN, 'chatter_dps', NaN);
    M.bounded = false;
    M.trim = struct('documented', true, 'pass', false, 'norm_dyn', Inf);
end

function F = score_feasible(M, rname, HG, lim) %#ok<INUSD>
    F = struct('feasible', false, 'first_limit', 'unrun', 'gates', struct());
    if ~isfield(M, 'sim_ok') || ~M.sim_ok
        F.first_limit = 'sim_fail'; return;
    end
    order = {};
    g_b = M.bounded;
    order{end+1} = {g_b, 'states_unbounded'};
    h = HG.(rname);
    g_pm = ~isnan(M.theta.mae_deg) && (M.theta.mae_deg <= h.pitch_mae);
    g_pp = ~isnan(M.theta.p95_deg) && (M.theta.p95_deg <= h.pitch_p95);
    order{end+1} = {g_pm, sprintf('pitch_MAE(%.4f>%.4f)', nz(M.theta.mae_deg), h.pitch_mae)};
    order{end+1} = {g_pp, sprintf('pitch_p95(%.4f>%.4f)', nz(M.theta.p95_deg), h.pitch_p95)};
    g_gm = ~isnan(M.gamma.mae_deg) && (M.gamma.mae_deg <= h.gamma_mae);
    g_gp = ~isnan(M.gamma.p95_deg) && (M.gamma.p95_deg <= h.gamma_p95);
    order{end+1} = {g_gm, sprintf('gamma_MAE(%.4f>%.4f)', nz(M.gamma.mae_deg), h.gamma_mae)};
    order{end+1} = {g_gp, sprintf('gamma_p95(%.4f>%.4f)', nz(M.gamma.p95_deg), h.gamma_p95)};

    if strcmp(rname, 'H')
        g_ym = ~isnan(M.yaw.mae_deg) && (M.yaw.mae_deg <= HG.H.yaw_mae);
        g_yp = ~isnan(M.yaw.p95_deg) && (M.yaw.p95_deg <= HG.H.yaw_p95);
        g_yss = ~isnan(M.yaw.rudder_sat_ss_pct) && (M.yaw.rudder_sat_ss_pct <= HG.rud_sat_ss);
        g_yf = ~isnan(M.yaw.rudder_sat_full_pct) && (M.yaw.rudder_sat_full_pct <= HG.rud_sat_full);
        if ~isnan(M.yaw.ratio_r_Uh_kappa)
            g_rat = (M.yaw.ratio_r_Uh_kappa >= HG.ratio_lo) && (M.yaw.ratio_r_Uh_kappa <= HG.ratio_hi);
        else
            g_rat = true;
        end
        g_ch = ~isnan(M.act.chatter_dps) && (M.act.chatter_dps <= HG.chatter);
        order{end+1} = {g_ym, sprintf('yaw_MAE(%.4f>%.4f)', nz(M.yaw.mae_deg), HG.H.yaw_mae)};
        order{end+1} = {g_yp, sprintf('yaw_p95(%.4f>%.4f)', nz(M.yaw.p95_deg), HG.H.yaw_p95)};
        order{end+1} = {g_yss, sprintf('rudder_sat_ss(%.2f%%>%.2f%%)', nz(M.yaw.rudder_sat_ss_pct), HG.rud_sat_ss)};
        order{end+1} = {g_yf, sprintf('rudder_sat_full(%.2f%%>%.2f%%)', nz(M.yaw.rudder_sat_full_pct), HG.rud_sat_full)};
        order{end+1} = {g_rat, sprintf('yaw_ratio(%.4f out [%.2f,%.2f])', nz(M.yaw.ratio_r_Uh_kappa), HG.ratio_lo, HG.ratio_hi)};
        order{end+1} = {g_ch, sprintf('chatter(%.4f>%.4f)', nz(M.act.chatter_dps), HG.chatter)};
    else
        g_ym = ~isnan(M.yaw.mae_deg) && (M.yaw.mae_deg <= 0.50);
        order{end+1} = {g_ym, sprintf('yaw_MAE(%.4f>0.50)', nz(M.yaw.mae_deg))};
    end

    g_es = ~isnan(M.act.de_sat_pct) && (M.act.de_sat_pct <= HG.elev_sat);
    g_ts = ~isnan(M.act.thr_sat_pct) && (M.act.thr_sat_pct <= HG.thrust_sat);
    g_dru = ~isnan(M.act.dr_rate_util) && (M.act.dr_rate_util <= HG.rate_util);
    g_deu = ~isnan(M.act.de_rate_util) && (M.act.de_rate_util <= HG.rate_util);
    order{end+1} = {g_es, sprintf('elev_sat(%.2f%%>%.2f%%)', nz(M.act.de_sat_pct), HG.elev_sat)};
    order{end+1} = {g_ts, sprintf('thrust_sat(%.2f%%>%.2f%%)', nz(M.act.thr_sat_pct), HG.thrust_sat)};
    order{end+1} = {g_dru, sprintf('rudder_rate_util(%.3f>1)', nz(M.act.dr_rate_util))};
    order{end+1} = {g_deu, sprintf('elev_rate_util(%.3f>1)', nz(M.act.de_rate_util))};

    F.feasible = true; F.first_limit = 'none';
    for k = 1:numel(order)
        if ~order{k}{1}
            F.feasible = false;
            F.first_limit = order{k}{2};
            break;
        end
    end
end

function Reg = regression_vs_ref(M, Ref, frac)
    % <=2% regression vs SPEED_ENVELOPE U=1.5 (no-current sanity)
    Reg = struct('pass', true, 'first', 'none', 'items', {{}});
    checks = {
        'thMAE', M.theta.mae_deg, Ref.thMAE
        'thP95', M.theta.p95_deg, Ref.thP95
        'gMAE',  M.gamma.mae_deg, Ref.gMAE
        'gP95',  M.gamma.p95_deg, Ref.gP95
        'yawMAE', M.yaw.mae_deg, Ref.yawMAE
        'CTE',   M.path.mean_cte, Ref.CTE
        'deSat', M.act.de_sat_pct, Ref.deSat
        'drSatF', M.act.dr_sat_full_pct, Ref.drSatF
        'chat',  M.act.chatter_dps, Ref.chat
    };
    for i = 1:size(checks, 1)
        name = checks{i, 1}; val = checks{i, 2}; ref = checks{i, 3};
        if ~isfinite(val) || ~isfinite(ref)
            ok = isfinite(val) || (~isfinite(ref) && ~isfinite(val));
            lim = Inf;
        elseif abs(ref) < 1e-9
            ok = abs(val) <= max(1e-3, frac);  % near-zero ref: absolute floor
            lim = max(1e-3, frac);
        else
            lim = abs(ref) * (1 + frac);
            ok = val <= lim + 1e-9;
        end
        Reg.items{end+1} = struct('name', name, 'val', val, 'ref', ref, 'lim', lim, 'ok', ok); %#ok<AGROW>
        if ~ok
            Reg.pass = false;
            if strcmp(Reg.first, 'none')
                Reg.first = sprintf('%s(%.4g>%.4g=+2%%)', name, val, lim);
            end
        end
    end
end

function BA = before_after(Mp, Mc)
    BA = struct();
    BA.thMAE = [nz(Mp.theta.mae_deg), nz(Mc.theta.mae_deg)];
    BA.gMAE  = [nz(Mp.gamma.mae_deg), nz(Mc.gamma.mae_deg)];
    BA.yawMAE = [nz(Mp.yaw.mae_deg), nz(Mc.yaw.mae_deg)];
    BA.CTE = [nz(Mp.path.mean_cte), nz(Mc.path.mean_cte)];
    BA.e_z_rms = [nz(Mp.depth.e_z_rms), nz(Mc.depth.e_z_rms)];
    BA.de_sat = [nz(Mp.act.de_sat_pct), nz(Mc.act.de_sat_pct)];
    BA.dr_satF = [nz(Mp.act.dr_sat_full_pct), nz(Mc.act.dr_sat_full_pct)];
    BA.chat = [nz(Mp.act.chatter_dps), nz(Mc.act.chatter_dps)];
    BA.uMAE = [nz(Mp.speed.mae), nz(Mc.speed.mae)];
    BA.roll_mae = [nz(Mp.roll.tilde_mae_deg), nz(Mc.roll.tilde_mae_deg)];
end

%% ===================== identity =====================
function Id = check_identity(A, B, routes)
    Id = struct('pass', true, 'max_state', 0, 'max_obs', 0, 'per_route', struct());
    for i = 1:numel(routes)
        nm = routes{i}.name;
        SpA = A.routes.(nm).prod; SpB = B.routes.(nm).prod;
        ScA = A.routes.(nm).curr; ScB = B.routes.(nm).curr;
        dp = max_abs_diff_S(SpA, SpB);
        dc = max_abs_diff_S(ScA, ScB);
        OA = A.obs.(nm); OB = B.obs.(nm);
        dobs = max([max(abs(OA.Vhat(:) - OB.Vhat(:))), max(abs(OA.err(:) - OB.err(:)))]);
        Id.per_route.(nm) = struct('prod', dp, 'curr', dc, 'obs', dobs);
        Id.max_state = max([Id.max_state, dp, dc]);
        Id.max_obs = max(Id.max_obs, dobs);
    end
    Id.pass = (Id.max_state < 1e-12) && (Id.max_obs < 1e-12);
    Id.note = tern(Id.pass, 'deterministic identity (bit-match after clear persistent/RNG)', ...
        sprintf('non-identical max|dS|=%.3e max|dObs|=%.3e', Id.max_state, Id.max_obs));
end

function d = max_abs_diff_S(A, B)
    n = min(size(A.vp, 1), size(B.vp, 1));
    if n < 2; d = Inf; return; end
    d = max([ ...
        max(abs(A.vp(1:n,:) - B.vp(1:n,:)), [], 'all'), ...
        max(abs(A.vel(1:n,:) - B.vel(1:n,:)), [], 'all'), ...
        max(abs(A.ori(1:n,:) - B.ori(1:n,:)), [], 'all'), ...
        max(abs(A.rates(1:n,:) - B.rates(1:n,:)), [], 'all'), ...
        max(abs(A.delta_e(1:n) - B.delta_e(1:n))), ...
        max(abs(A.delta_r(1:n) - B.delta_r(1:n))), ...
        max(abs(A.thrust(1:n) - B.thrust(1:n)))]);
end

%% ===================== offline observer =====================
function Obs = run_bias_latency_observer(S, sens, Vc_true)
    n = numel(S.t);
    Obs = struct('ok', false);
    if n < 10; return; end
    dt = S.dt;
    if isempty(dt) || ~isfinite(dt) || dt <= 0; dt = median(diff(S.t)); end

    Vg_inst = zeros(n, 3); Vw_b_inst = zeros(n, 3);
    yc_ideal = zeros(n, 3);
    for k = 1:n
        R = rotmat(S.ori(k,1), S.ori(k,2), S.ori(k,3));
        nu_lin = S.nu(k, 1:3).';
        nu_r = S.V_water_body(k, :).';
        Vg_inst(k, :) = (R * nu_lin).';
        Vw_b_inst(k, :) = nu_r.';
        yc_ideal(k, :) = Vg_inst(k, :) - (R * nu_r).';
    end

    [n_ins_hold, ~] = zoh_white(S.t, sens.ins_fs, sens.ins_sigma, 3);
    [n_dvl_hold, ~] = zoh_white(S.t, sens.dvl_fs, sens.dvl_sigma, 3);
    Vg_corrupt = Vg_inst + repmat(sens.ins_bias_ned(:).', n, 1) + n_ins_hold;
    Vw_b_corrupt = Vw_b_inst + repmat(sens.dvl_bias_body(:).', n, 1) + n_dvl_hold;
    Vg_del = causal_zoh_delay(S.t, Vg_corrupt, sens.ins_latency_s);
    Vw_b_del = causal_zoh_delay(S.t, Vw_b_corrupt, sens.dvl_latency_s);

    alpha = 1 - exp(-sens.wo * dt);
    v = sens.Vhat0(:);
    Vhat = zeros(n, 3); bound_hit = false(n, 1); yc = zeros(n, 3);
    for k = 1:n
        R = rotmat(S.ori(k,1), S.ori(k,2), S.ori(k,3));
        Vg_m = Vg_del(k, :).';
        Vw_nm = R * Vw_b_del(k, :).';
        yc_k = Vg_m - Vw_nm;
        yc(k, :) = yc_k.';
        v = v + alpha * (yc_k - v);
        pre = v;
        v = max(min(v, sens.V_bound), -sens.V_bound);
        bound_hit(k) = any(abs(pre) > sens.V_bound + 1e-15);
        Vhat(k, :) = v.';
    end

    err = Vhat - repmat(Vc_true(:).', n, 1);
    err_norm = sqrt(sum(err.^2, 2));
    ss = S.t >= sens.steady_t0;
    if ~any(ss); ss = true(n, 1); end
    err_ss = err(ss, :); en_ss = err_norm(ss);
    bias = mean(err_ss, 1).';
    bias_norm = norm(bias);
    rmse_norm = sqrt(mean(en_ss.^2));
    p95_norm = percentile95(en_ss);

    Obs.ok = true;
    Obs.t = S.t; Obs.Vhat = Vhat; Obs.err = err; Obs.err_norm = err_norm;
    Obs.y_c = yc; Obs.y_c_ideal = yc_ideal;
    Obs.err_final_norm = err_norm(end);
    Obs.bound_hits = sum(bound_hit);
    Obs.Vhat_max_abs = max(abs(Vhat), [], 'all');
    Obs.steady = struct('t0', sens.steady_t0, 'bias', bias, 'bias_norm', bias_norm, ...
        'rmse_norm', rmse_norm, 'p95_norm', p95_norm, 'max_norm', max(en_ss), 'n', sum(ss));
    Obs.pass_bias = bias_norm <= 0.030;
    Obs.pass_rmse = rmse_norm <= 0.035;
    Obs.pass_p95 = p95_norm <= 0.070;
    Obs.pass_final = Obs.err_final_norm <= 0.050;
    Obs.pass_bounded = Obs.Vhat_max_abs <= sens.V_bound + 1e-12;
    Obs.pass_no_hits = Obs.bound_hits == 0;
end

function [y_del, t_src, t_avail] = causal_zoh_delay(t, y, latency_s)
    n = numel(t);
    y_del = zeros(size(y));
    t_src = zeros(n, 1); t_avail = zeros(n, 1);
    j = 1;
    for k = 1:n
        t_need = t(k) - latency_s;
        while j < n && t(j + 1) <= t_need + 1e-15
            j = j + 1;
        end
        if t(1) > t_need; idx = 1; else; idx = j; end
        y_del(k, :) = y(idx, :);
        t_src(k) = t(idx); t_avail(k) = t(idx) + latency_s;
    end
end

function [n_hold, t_upd] = zoh_white(t, fs, sigma, dim)
    t0 = t(1); tend = t(end);
    t_upd = (t0:(1/fs):tend).';
    if isempty(t_upd) || t_upd(end) < tend - 1e-12
        t_upd = [t_upd; tend]; %#ok<AGROW>
    end
    n_upd = sigma * randn(numel(t_upd), dim);
    idx = floor((t - t0) * fs) + 1;
    idx = min(max(idx, 1), numel(t_upd));
    n_hold = n_upd(idx, :);
end

function p = percentile95(x)
    x = sort(x(:));
    if isempty(x); p = NaN; return; end
    idx = max(1, min(numel(x), ceil(0.95 * numel(x))));
    p = x(idx);
end

%% ===================== path helpers =====================
function [gamma_ref, cte_perp, s_prog, s_total] = path_gamma_cte(path, vp)
    n = size(vp, 1);
    ds = [0; sqrt(sum(diff(path).^2, 2))];
    s_nodes = cumsum(ds);
    s_total = s_nodes(end);
    s_prog = zeros(n, 1); gamma_ref = zeros(n, 1); cte_perp = zeros(n, 1);
    for i = 1:n
        d = path - vp(i, :);
        [~, idx] = min(sum(d.^2, 2));
        idx = max(1, min(size(path, 1) - 1, idx));
        s_prog(i) = s_nodes(idx);
        t = path(idx + 1, :) - path(idx, :);
        tn = norm(t);
        if tn < 1e-9; t = [1 0 0]; else; t = t / tn; end
        gamma_ref(i) = atan2(t(3), norm(t(1:2)));
        e = vp(i, :) - path(idx, :);
        th = t(1:2); nth = norm(th);
        if nth < 1e-9; nh = [0 1]; else; th = th / nth; nh = [-th(2), th(1)]; end
        cte_perp(i) = hypot(dot(e(1:2), nh), e(3));
    end
end

function P = pack_S(S)
    keep = {'t','vp','vel','rates','ori','psi_ref','theta_ref','u_ref','u_ctrl', ...
        'u_body','thrust','delta_e','delta_r','Uh','VD','Uref','dt','R','is_xz', ...
        'Vc','lambda','e_z','nu','nu_c','nu_r','V_ground_ned','V_water_body', ...
        'U_h_guid','kappa','r','ok','finite'};
    P = struct();
    for i = 1:numel(keep)
        if isfield(S, keep{i}); P.(keep{i}) = S.(keep{i}); end
    end
end

%% ===================== outputs =====================
function write_png(png_path, Off, task_id, verdict, Vc)
    fig = figure('Visible', 'off', 'Position', [40 40 1400 1000]);
    tiledlayout(3, 3, 'Padding', 'compact', 'TileSpacing', 'compact');
    names = {'X','XZ','R10'};
    for i = 1:3
        rr = Off.routes.(names{i});
        nexttile;
        plot(rr.prod.t, rr.prod.vp(:,2), 'k-'); hold on;
        plot(rr.curr.t, rr.curr.vp(:,2), 'r-');
        grid on; ylabel('y [m]'); title(sprintf('%s y prod→Vc', names{i}));
        if i == 1; legend('Vc=0','Vc=E0.15', 'Location', 'best'); end

        nexttile;
        O = Off.obs.(names{i});
        plot(O.t, O.Vhat(:,2), 'b'); hold on;
        yline(Vc(2), 'r--');
        grid on; ylabel('m/s'); title(sprintf('%s Vhat_E (offline)', names{i}));

        nexttile;
        plot(rr.prod.t, -rr.prod.ori(:,2)*180/pi, 'k'); hold on;
        plot(rr.curr.t, -rr.curr.ori(:,2)*180/pi, 'r');
        grid on; ylabel('θ_phys [deg]'); title(sprintf('%s theta', names{i}));
    end
    sgtitle(sprintf('%s %s — PLANT-DISTURBANCE+ESTIMATOR (offline)', task_id, verdict), ...
        'Interpreter', 'none');
    exportgraphics(fig, png_path, 'Resolution', 150);
    close(fig);
end

function write_md(md_path, R, lim)
    Off = R.official;
    fid = fopen(md_path, 'w');
    fprintf(fid, '# %s — Combined nonlinear 6DOF disturbance baseline\n\n', R.task_id);
    fprintf(fid, '**Overall verdict: %s**\n\n', R.verdict);
    fprintf(fid, '**Label: %s**\n\n', R.label);

    fprintf(fid, '## Provenance\n\n');
    fprintf(fid, '- Read-only: `run_bounded_current_hook.m`, `run_current_observer_bias_latency.m`, `suite_results/SPEED_ENVELOPE_AUDIT.md`\n');
    fprintf(fid, '- Priors: BOUNDED_CURRENT_HOOK=PASS; CURRENT_OBSERVER_BIAS_LATENCY=PASS\n');
    fprintf(fid, '- Driver: `run_combined_6dof_disturbance_baseline.m` (one invocation)\n');
    fprintf(fid, '- Production plant/controller/guidance: **UNTOUCHED / FROZEN**\n');
    fprintf(fid, '- Observer fed to control: **NO** (offline only; NOT sensor-in-loop)\n');
    fprintf(fid, '- Artifacts: `%s`, `%s`, `%s`\n', R.paths.md, R.paths.mat, R.paths.png);
    fprintf(fid, '- Did **not** touch `CODEX_VERTICAL_PLAN.md`\n\n');

    fprintf(fid, '## Setup\n\n');
    fprintf(fid, '- U=%.1f m/s; Vc=[%.2f, %.2f, %.2f] NED; routes X / XZ / R10\n', R.Uref, R.Vc_cross);
    fprintf(fid, '- Two repeats; plant seed=%d; observer seed=%d; identity required\n', ...
        R.seed_plant, R.seed_obs);
    fprintf(fid, '- Hard gates = SPEED_ENVELOPE absolutes; <=2%% regression vs SPEED_ENVELOPE U=1.5 on no-current\n');
    fprintf(fid, '- Observer gates = prior bias/latency (bias<=0.030 RMSE<=0.035 p95<=0.070 final<=0.050 no hits)\n');
    fprintf(fid, '- Act rate limit: %.0f deg/s elev/rudder\n\n', rad2deg(lim.de_rate));

    fprintf(fid, '## Identity\n\n');
    fprintf(fid, '- %s — max|Δstate|=%.3e max|Δobs|=%.3e\n\n', R.identity.note, ...
        R.identity.max_state, R.identity.max_obs);

    fprintf(fid, '## Before → after (no-current → Vc cross) @ U=1.5\n\n');
    fprintf(fid, '| Route | thMAE | gMAE | yawMAE | CTE | e_z_rms | uMAE | deSat%% | drSatF%% | chat | FEAS_c | first_c |\n');
    fprintf(fid, '|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|:---:|---|\n');
    names = {'X','XZ','R10'};
    for i = 1:3
        rr = Off.routes.(names{i});
        BA = rr.before_after;
        fprintf(fid, '| %s | %.4f→%.4f | %.4f→%.4f | %.4f→%.4f | %.3f→%.3f | %.4f→%.4f | %.4f→%.4f | %.2f→%.2f | %.2f→%.2f | %.4f→%.4f | %s | %s |\n', ...
            names{i}, BA.thMAE(1), BA.thMAE(2), BA.gMAE(1), BA.gMAE(2), ...
            BA.yawMAE(1), BA.yawMAE(2), BA.CTE(1), BA.CTE(2), ...
            BA.e_z_rms(1), BA.e_z_rms(2), BA.uMAE(1), BA.uMAE(2), ...
            BA.de_sat(1), BA.de_sat(2), BA.dr_satF(1), BA.dr_satF(2), ...
            BA.chat(1), BA.chat(2), yn(rr.feas_curr.feasible), sanitize(rr.feas_curr.first_limit));
    end
    fprintf(fid, '\n');

    fprintf(fid, '## No-current vs SPEED_ENVELOPE U=1.5 (<=2%% regression)\n\n');
    fprintf(fid, '| Route | PASS | First |\n|---|:---:|---|\n');
    for i = 1:3
        rr = Off.routes.(names{i});
        fprintf(fid, '| %s | %s | %s |\n', names{i}, yn(rr.reg_vs_speed_env.pass), ...
            sanitize(rr.reg_vs_speed_env.first));
    end
    fprintf(fid, '\n');

    fprintf(fid, '## Current-case hard gates (SPEED_ENVELOPE absolutes)\n\n');
    fprintf(fid, '| Route | FEAS | First limit | thMAE | gMAE | yawMAE | CTE | ez_rms | deSat | drSatF | deRateU | chat | bound |\n');
    fprintf(fid, '|---|:---:|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|:---:|\n');
    for i = 1:3
        rr = Off.routes.(names{i}); M = rr.M_curr;
        fprintf(fid, '| %s | %s | %s | %.4f | %.4f | %.4f | %.3f | %.4f | %.2f | %.2f | %.3f | %.4f | %s |\n', ...
            names{i}, yn(rr.feas_curr.feasible), sanitize(rr.feas_curr.first_limit), ...
            nz(M.theta.mae_deg), nz(M.gamma.mae_deg), nz(M.yaw.mae_deg), nz(M.path.mean_cte), ...
            nz(M.depth.e_z_rms), nz(M.act.de_sat_pct), nz(M.act.dr_sat_full_pct), ...
            nz(M.act.de_rate_util), nz(M.act.chatter_dps), yn(M.bounded));
    end
    fprintf(fid, '\n');

    fprintf(fid, '## Offline observer (declared bias+latency harness)\n\n');
    fprintf(fid, '| Route | bias||mean|| | RMSE_ss | p95_ss | final||err|| | hits | PASS |\n');
    fprintf(fid, '|---|---:|---:|---:|---:|---:|:---:|\n');
    for i = 1:3
        O = Off.obs.(names{i});
        pok = O.pass_bias && O.pass_rmse && O.pass_p95 && O.pass_final && O.pass_bounded && O.pass_no_hits;
        fprintf(fid, '| %s | %.4e | %.4e | %.4e | %.4e | %d | %s |\n', ...
            names{i}, O.steady.bias_norm, O.steady.rmse_norm, O.steady.p95_norm, ...
            O.err_final_norm, O.bound_hits, yn(pok));
    end
    fprintf(fid, '\n');

    fprintf(fid, '## PASS gates\n\n');
    fprintf(fid, '| Gate | Result |\n|---|---|\n');
    gn = fieldnames(R.gates);
    for i = 1:numel(gn)
        fprintf(fid, '| %s | %s |\n', gn{i}, tern(R.gates.(gn{i}), 'PASS', 'FAIL'));
    end
    fprintf(fid, '\n**Overall: %s** | first_limit=`%s`\n\n', R.verdict, R.first_limit);

    fprintf(fid, '## Next bounded roadmap gate\n\n');
    fprintf(fid, '- **`%s`** (%s)\n', R.next.gate, R.next.architecture);
    fprintf(fid, '- %s\n', R.next.detail);
    fprintf(fid, '- Do **not** feed observer to control; do **not** promote to production.\n');
    fprintf(fid, '- CODEX_VERTICAL_PLAN untouched.\n');
    fclose(fid);
end

function append_research_log(log_path, R)
    fid = fopen(log_path, 'a');
    fprintf(fid, '\n\n## %s — %s\n\n', R.task_id, datestr(now, 31));
    fprintf(fid, '- Verdict: **%s** — PLANT-DISTURBANCE + ESTIMATOR baseline (offline observer; NOT sensor-in-loop); production frozen.\n', R.verdict);
    fprintf(fid, '- Setup: U=1.5; Vc=[0,0.15,0] NED; X/XZ/R10; two repeats identity; controller uses plant truth only.\n');
    Off = R.official;
    names = {'X','XZ','R10'};
    for i = 1:3
        rr = Off.routes.(names{i}); BA = rr.before_after;
        fprintf(fid, '- %s before→after: thMAE %.4f→%.4f yawMAE %.4f→%.4f CTE %.3f→%.3f ez %.4f→%.4f | FEAS_c=%s first=%s\n', ...
            names{i}, BA.thMAE(1), BA.thMAE(2), BA.yawMAE(1), BA.yawMAE(2), ...
            BA.CTE(1), BA.CTE(2), BA.e_z_rms(1), BA.e_z_rms(2), ...
            yn(rr.feas_curr.feasible), rr.feas_curr.first_limit);
    end
    fprintf(fid, '- Observer max bias/rmse/p95/final: %.3e / %.3e / %.3e / %.3e (hits=%d)\n', ...
        R.obs_summary.bias_norm_max_all, R.obs_summary.rmse_norm_max_all, ...
        R.obs_summary.p95_norm_max_all, R.obs_summary.final_err_max_all, ...
        R.obs_summary.bound_hits_total);
    fprintf(fid, '- Identity: %s\n', R.identity.note);
    fprintf(fid, '- First limit: `%s`\n', R.first_limit);
    fprintf(fid, '- Artifacts: suite_results/COMBINED_6DOF_DISTURBANCE_BASELINE.{md,mat,png}; driver `run_combined_6dof_disturbance_baseline.m`.\n');
    fprintf(fid, '- Next: **`%s`** — %s\n', R.next.gate, R.next.detail);
    fprintf(fid, '- CODEX_VERTICAL_PLAN untouched.\n');
    fclose(fid);
end

function print_feedback(R)
    fprintf('\n========== FEEDBACK ==========\n');
    fprintf('VERDICT: %s\n', R.verdict);
    fprintf('first_limit: %s\n', R.first_limit);
    Off = R.official;
    names = {'X','XZ','R10'};
    for i = 1:3
        rr = Off.routes.(names{i}); BA = rr.before_after;
        fprintf('%s: th %.4f→%.4f yaw %.4f→%.4f CTE %.3f→%.3f FEAS_c=%s (%s)\n', ...
            names{i}, BA.thMAE(1), BA.thMAE(2), BA.yawMAE(1), BA.yawMAE(2), ...
            BA.CTE(1), BA.CTE(2), yn(rr.feas_curr.feasible), rr.feas_curr.first_limit);
    end
    fprintf('obs max bias/rmse/p95/final: %.3e/%.3e/%.3e/%.3e hits=%d\n', ...
        R.obs_summary.bias_norm_max_all, R.obs_summary.rmse_norm_max_all, ...
        R.obs_summary.p95_norm_max_all, R.obs_summary.final_err_max_all, ...
        R.obs_summary.bound_hits_total);
    fprintf('Next: %s (%s)\n', R.next.gate, R.next.architecture);
    fprintf('Artifacts:\n  %s\n  %s\n  %s\n', R.paths.md, R.paths.mat, R.paths.png);
end

%% ===================== utils =====================
function st = err_stats_lin(e, mask)
    st = struct('mae', NaN, 'p95', NaN, 'rms', NaN, 'n', 0);
    if ~any(mask); return; end
    v = e(mask);
    st.n = numel(v); st.mae = mean(abs(v)); st.rms = rms_safe(v);
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
    if isempty(x); v = NaN; else; v = sqrt(mean(x.^2)); end
end

function v = prctile_local(x, p)
    x = sort(x(:)); x = x(isfinite(x));
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
    if numel(s) > 70; s = [s(1:67) '...']; end
end
