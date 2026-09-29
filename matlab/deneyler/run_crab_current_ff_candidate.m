function run_crab_current_ff_candidate()
% CRAB_CURRENT_FF_CANDIDATE_001 — ONE isolated crab-current yaw-ref feedforward.
% Read-only: guidance_law.m, run_combined_6dof_disturbance_baseline.m,
%   run_current_observer_bias_latency.m (+ COMBINED_6DOF_DISTURBANCE_BASELINE.mat).
% Combined Vc=[0,0.15,0] baseline FAIL only R10 rudder full-sat 6.06%.
% Production plant/controller/guidance FROZEN. No gain sweep.
%
% Candidate (isolated, NOT production):
%   At guidance ticks: th = path horiz unit tangent [tN,tE]
%   vw = Uref*th - Vhat_NE
%   dpsi = wrap(atan2(vw_E,vw_N) - atan2(th_E,th_N))
%   clamp ±8deg, rate 3deg/s, × half-cosine act 0→1 over first 5s
%   yaw_ref_ff = yaw_ref_prod + dpsi  (ONCE); beta/crab + r_ff preserved
%   Vhat = causal biased/noisy observer (wo=0.50, declared noise/bias/latency)
%
% Algebra (no double-count):
%   prod yaw = unwrap(chi_f + 0.75*chi_los - k_beta*beta); beta=atan2(v,u)
%     → body sideslip vs WATER velocity (hydrodynamic crab)
%   r_ff = U_h*kappa → curvature yaw-RATE FF (not a heading offset)
%   dpsi → WATER-track heading vs PATH tangent from estimated current
%     → ground-track crab from current; orthogonal to beta and r_ff
%
% Compare CURRENT baseline → candidate on X/XZ/R10 U=1.5, same hook/windows.
% PASS: all route hard gates; R10 rudder full-sat<=1% AND >=10% smoothness/sat
%   improve; tracking/yaw/pitch/gamma/CTE/other act RMS/p95 reg<=2%;
%   observer gates; bounded/no chatter.
% FAIL → reject; next guidance/mission baseline.
% PASS → next two-repeat isolated closure.
% Artifacts: suite_results/CRAB_CURRENT_FF_CANDIDATE.{md,mat,png}
% Appends suite_results/PITCH_CONTROL_RESEARCH_LOG.md
% Does NOT touch CODEX_VERTICAL_PLAN.md / production.

    project_dir = fileparts(fileparts(fileparts(mfilename('fullpath')))); % repo root
    addpath(genpath(fullfile(project_dir, 'matlab')));
    out_dir = fullfile(project_dir, 'suite_results');
    if ~exist(out_dir, 'dir'); mkdir(out_dir); end
    tag = 'CRAB_CURRENT_FF_CANDIDATE';
    task_id = 'CRAB_CURRENT_FF_CANDIDATE_001';

    base_mat = fullfile(out_dir, 'COMBINED_6DOF_DISTURBANCE_BASELINE.mat');
    guid_path = fullfile(project_dir, 'guidance_law.m');
    base_run = fullfile(project_dir, 'run_combined_6dof_disturbance_baseline.m');
    obs_run = fullfile(project_dir, 'run_current_observer_bias_latency.m');
    log_path = fullfile(out_dir, 'PITCH_CONTROL_RESEARCH_LOG.md');
    assert(exist(base_mat, 'file') == 2, 'Missing %s', base_mat);
    assert(exist(guid_path, 'file') == 2, 'Missing %s', guid_path);
    assert(exist(base_run, 'file') == 2, 'Missing %s', base_run);
    assert(exist(obs_run, 'file') == 2, 'Missing %s', obs_run);
    assert(exist(log_path, 'file') == 2, 'Missing %s', log_path);

    guid_txt = fileread(guid_path);
    assert(contains(guid_txt, 'yaw_raw = wrapToPi(chi_f + 0.75 * chi_los - k_beta * beta)'), ...
        'production yaw algebra changed — abort');
    assert(contains(guid_txt, 'r_ff = U_h * kappa_f'), 'production r_ff changed — abort');
    assert(~contains(guid_txt, 'crab_current_dpsi') && ~contains(guid_txt, 'Vhat_NE'), ...
        'production must not host crab-current FF');

    Base = load(base_mat);
    assert(strcmp(Base.verdict, 'FAIL'), 'Expected combined baseline FAIL');
    assert(contains(Base.first_limit, 'rudder_sat_full'), 'Expected R10 rudder sat fail');

    fprintf('\n========== %s ==========\n', task_id);
    fprintf('Isolated crab-current yaw FF via causal Vhat; production frozen.\n');
    fprintf('Baseline first_limit=%s\n', Base.first_limit);

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
    Vc_cross = [0; 0.15; 0];
    seed_plant = 0;
    seed_obs = 42;

    % Fixed crab FF (no sweep)
    ff = struct();
    ff.dpsi_max = deg2rad(8);
    ff.dpsi_rate = deg2rad(3);
    ff.act_T = 5.0;  % half-cosine 0→1
    ff.note = ['yaw_ref_ff=yaw_ref_prod+dpsi; beta/r_ff untouched; ', ...
        'dpsi=wrap(atan2(vw_E,vw_N)-atan2(th_E,th_N)); vw=Uref*th-Vhat_NE'];

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
    HG.reg_frac = 0.02;

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

    Algebra = document_algebra(ff);

    Results = struct();
    Results.task_id = task_id;
    Results.label = 'ISOLATED crab-current yaw-ref FF (causal Vhat; production untouched)';
    Results.Uref = Uref;
    Results.Vc_cross = Vc_cross;
    Results.seed_plant = seed_plant;
    Results.seed_obs = seed_obs;
    Results.ff = ff;
    Results.algebra = Algebra;
    Results.observer_cfg = obs;
    Results.production_untouched = true;
    Results.gain_sweep = false;
    Results.HG = HG;
    Results.baseline_first_limit = Base.first_limit;
    Results.routes = struct();

    OffB = Base.official;
    names = {'X','XZ','R10'};

    for i = 1:numel(routes)
        r = routes{i};
        nm = r.name;
        fprintf('\n---- Route %s (candidate) ----\n', nm);
        reset_all_persistents();
        rng(seed_plant, 'twister');
        Sc = sim_route_crab_ff(r, Uref, Vc_cross, obs, ff, seed_obs);
        Mc = analyze_route(Sc, r, lim, HG);
        Fc = score_feasible(Mc, r.key, HG, lim);

        Mb = OffB.routes.(nm).M_curr;
        Fb = OffB.routes.(nm).feas_curr;
        Reg = regression_vs_base(Mb, Mc, HG.reg_frac);
        Imp = sat_smooth_improve(Mb, Mc);

        RR = struct();
        RR.name = nm; RR.key = r.key;
        RR.S = pack_S(Sc);
        RR.M = Mc; RR.feas = Fc;
        RR.M_base = Mb; RR.feas_base = Fb;
        RR.reg_vs_base = Reg;
        RR.sat_smooth = Imp;
        RR.before_after = before_after(Mb, Mc);
        RR.traces = struct( ...
            't', Sc.t, ...
            'dpsi', Sc.dpsi, ...
            'dpsi_raw', Sc.dpsi_raw, ...
            'dpsi_act', Sc.dpsi_act, ...
            'Vhat', Sc.Vhat, ...
            'delta_r', Sc.delta_r, ...
            'th', Sc.th, ...
            'psi_ref_prod', Sc.psi_ref_prod, ...
            'psi_ref', Sc.psi_ref);
        Results.routes.(nm) = RR;

        fprintf('  BASE FEAS=%s first=%s | drSatF=%.2f%% chat=%.4f\n', ...
            yn(Fb.feasible), Fb.first_limit, nz(Mb.act.dr_sat_full_pct), nz(Mb.act.chatter_dps));
        fprintf('  CAND FEAS=%s first=%s | drSatF=%.2f%% chat=%.4f | reg=%s impSat=%.1f%%\n', ...
            yn(Fc.feasible), Fc.first_limit, nz(Mc.act.dr_sat_full_pct), nz(Mc.act.chatter_dps), ...
            yn(Reg.pass), 100*Imp.sat_improve_frac);
        fprintf('  dpsi max| | = %.2f deg  Vhat_E mean=%.3f\n', ...
            rad2deg(max(abs(Sc.dpsi))), mean(Sc.Vhat(:,2)));
    end

    % Observer gates on candidate (declared harness; Vhat already in-loop)
    Results.obs = struct();
    bias_max = 0; rmse_max = 0; p95_max = 0; fin_max = 0; hits_tot = 0;
    for i = 1:3
        nm = names{i};
        S = Results.routes.(nm).S;
        O = score_observer_from_trace(S, obs, Vc_cross);
        O.name = nm;
        Results.obs.(nm) = O;
        bias_max = max(bias_max, O.steady.bias_norm);
        rmse_max = max(rmse_max, O.steady.rmse_norm);
        p95_max = max(p95_max, O.steady.p95_norm);
        fin_max = max(fin_max, O.err_final_norm);
        hits_tot = hits_tot + O.bound_hits;
        fprintf('  obs %s: bias=%.3e rmse=%.3e p95=%.3e final=%.3e hits=%d\n', ...
            nm, O.steady.bias_norm, O.steady.rmse_norm, O.steady.p95_norm, ...
            O.err_final_norm, O.bound_hits);
    end
    Results.obs_summary = struct( ...
        'bias_norm_max_all', bias_max, 'rmse_norm_max_all', rmse_max, ...
        'p95_norm_max_all', p95_max, 'final_err_max_all', fin_max, ...
        'bound_hits_total', hits_tot);

    % ---- PASS gates ----
    gates = struct();
    gates.production_untouched = true;
    gates.no_gain_sweep = ~Results.gain_sweep;
    gates.states_bounded = true;
    gates.route_hard_all = true;
    gates.r10_rudder_sat_le_1pct = false;
    gates.r10_sat_or_smooth_improve_ge_10pct = false;
    gates.reg_le_2pct_all = true;
    gates.observer_prior = true;
    gates.bounded_no_chatter = true;

    first_limit = 'none';
    order = {};

    for i = 1:3
        nm = names{i}; rr = Results.routes.(nm);
        gates.states_bounded = gates.states_bounded && rr.M.bounded;
        order{end+1} = {rr.M.bounded, sprintf('%s:states_unbounded', nm)}; %#ok<AGROW>

        gates.route_hard_all = gates.route_hard_all && rr.feas.feasible;
        order{end+1} = {rr.feas.feasible, sprintf('%s:%s', nm, rr.feas.first_limit)}; %#ok<AGROW>

        gates.reg_le_2pct_all = gates.reg_le_2pct_all && rr.reg_vs_base.pass;
        if ~rr.reg_vs_base.pass
            order{end+1} = {false, sprintf('%s_reg:%s', nm, rr.reg_vs_base.first)}; %#ok<AGROW>
        else
            order{end+1} = {true, sprintf('%s_reg:ok', nm)}; %#ok<AGROW>
        end

        chat_ok = isnan(rr.M.act.chatter_dps) || (rr.M.act.chatter_dps <= HG.chatter);
        gates.bounded_no_chatter = gates.bounded_no_chatter && rr.M.bounded && chat_ok;
        order{end+1} = {chat_ok, sprintf('%s:chatter(%.4f>%.4f)', nm, ...
            nz(rr.M.act.chatter_dps), HG.chatter)}; %#ok<AGROW>
    end

    R10 = Results.routes.R10;
    gates.r10_rudder_sat_le_1pct = ~isnan(R10.M.act.dr_sat_full_pct) && ...
        (R10.M.act.dr_sat_full_pct <= 1.0 + 1e-9);
    order{end+1} = {gates.r10_rudder_sat_le_1pct, sprintf( ...
        'R10_rudder_sat_full(%.2f%%>1.00%%)', nz(R10.M.act.dr_sat_full_pct))};

    % >=10% improvement on sat OR smoothness (prefer sat; also accept combined)
    Imp = R10.sat_smooth;
    gates.r10_sat_or_smooth_improve_ge_10pct = Imp.pass_10pct;
    order{end+1} = {Imp.pass_10pct, sprintf( ...
        'R10_improve(sat=%.1f%% smooth=%.1f%% need>=10%%)', ...
        100*Imp.sat_improve_frac, 100*Imp.smooth_improve_frac)};

    obs_ok = (bias_max <= 0.030) && (rmse_max <= 0.035) && (p95_max <= 0.070) && ...
        (fin_max <= 0.050) && (hits_tot == 0);
    gates.observer_prior = obs_ok;
    order{end+1} = {obs_ok, sprintf('observer(bias=%.3e rmse=%.3e p95=%.3e final=%.3e hits=%d)', ...
        bias_max, rmse_max, p95_max, fin_max, hits_tot)};

    all_pass = true;
    for k = 1:numel(order)
        if ~order{k}{1}
            all_pass = false;
            if strcmp(first_limit, 'none')
                first_limit = order{k}{2};
            end
        end
    end
    % also require core gate struct
    all_pass = all_pass && gates.production_untouched && gates.no_gain_sweep && ...
        gates.states_bounded && gates.route_hard_all && gates.r10_rudder_sat_le_1pct && ...
        gates.r10_sat_or_smooth_improve_ge_10pct && gates.reg_le_2pct_all && ...
        gates.observer_prior && gates.bounded_no_chatter;

    if strcmp(first_limit, 'none') && ~all_pass
        first_limit = 'unknown_gate_fail';
    end

    verdict = tern(all_pass, 'PASS', 'FAIL');
    Results.gates = gates;
    Results.verdict = verdict;
    Results.first_limit = first_limit;

    if strcmp(verdict, 'PASS')
        Results.next = struct( ...
            'gate', 'two_repeat_isolated_closure', ...
            'detail', ['Crab-current yaw FF candidate PASS. Next: two-repeat ', ...
                'isolated closure (still not production).'], ...
            'architecture', 'crab_current_ff_closure');
    else
        Results.next = struct( ...
            'gate', 'guidance_mission_baseline', ...
            'detail', ['REJECT crab-current FF candidate (production untouched). ', ...
                'First fail=`' first_limit '`. Advance to guidance/mission baseline.'], ...
            'architecture', 'guidance_mission');
    end

    md_path  = fullfile(out_dir, [tag '.md']);
    mat_path = fullfile(out_dir, [tag '.mat']);
    png_path = fullfile(out_dir, [tag '.png']);
    Results.paths = struct('md', md_path, 'mat', mat_path, 'png', png_path);

    write_png(png_path, Results, task_id, verdict, Vc_cross);
    write_md(md_path, Results, lim);
    append_research_log(log_path, Results);
    save(mat_path, '-struct', 'Results', '-v7.3');

    fprintf('\nVERDICT: %s | first_limit=%s\n', verdict, first_limit);
    fprintf('Next: %s (%s)\n', Results.next.gate, Results.next.architecture);
    fprintf('Saved: %s\n%s\n%s\n', md_path, mat_path, png_path);
    print_feedback(Results);
end

%% ===================== algebra doc =====================
function A = document_algebra(ff)
    A = struct();
    A.production_yaw = 'yaw_raw = wrap(chi_f + 0.75*chi_los - k_beta*beta); beta=atan2(v,u)';
    A.production_r_ff = 'r_ff = U_h * kappa_f  (yaw-RATE curvature FF; unchanged)';
    A.candidate_dpsi = [ ...
        'th=[tN,tE] path horiz unit tangent; Vhat_NE=Vhat(1:2); ', ...
        'vw=Uref*th-Vhat_NE; ', ...
        'dpsi_raw=wrap(atan2(vw_E,vw_N)-atan2(th_E,th_N)); ', ...
        'dpsi=rate_limit(clamp(act*dpsi_raw,±8deg), 3deg/s); ', ...
        'act=0.5*(1-cos(pi*min(t,5)/5))'];
    A.compose = 'yaw_ref_ff = yaw_ref_prod + dpsi  (added ONCE)';
    A.no_double_count = [ ...
        'beta compensates BODY sideslip vs WATER velocity; ', ...
        'dpsi compensates WATER-track vs PATH tangent from estimated CURRENT; ', ...
        'r_ff is rate FF from curvature — not a heading bias. ', ...
        'Do NOT fold Vhat into beta or replace LOS; add dpsi once only.'];
    A.ff = ff;
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

%% ===================== simulate with crab FF =====================
function S = sim_route_crab_ff(r, Uref, Vc, obs, ff, seed_obs)
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
    yaw_ref_prod = 0;
    dpsi = 0; dpsi_raw = 0; dpsi_act = 0;
    th_hold = [1; 0];

    % Observer online state (causal biased/noisy)
    ObsSt = init_online_observer(obs, dt, n_steps, seed_obs);

    S = struct();
    S.dt = dt; S.T_final = T_final; S.u0 = Uref; S.R = r.R; S.is_xz = r.is_xz;
    S.Uref = Uref; S.Vc = Vc(:); S.lambda = r.lambda; S.win = r.win;
    S.t = zeros(n_steps, 1);
    S.vp = zeros(n_steps, 3); S.vel = zeros(n_steps, 3);
    S.rates = zeros(n_steps, 3); S.ori = zeros(n_steps, 3);
    S.psi_ref = zeros(n_steps, 1); S.psi_ref_prod = zeros(n_steps, 1);
    S.theta_ref = zeros(n_steps, 1);
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
    S.Vhat = zeros(n_steps, 3);
    S.dpsi = zeros(n_steps, 1); S.dpsi_raw = zeros(n_steps, 1); S.dpsi_act = zeros(n_steps, 1);
    S.th = zeros(n_steps, 2);
    S.obs_bound_hit = false(n_steps, 1);

    ok = true;
    plant_fn = @underwater777_vehicle_dynamics_current;
    for k = 1:n_steps
        t_now = (k - 1) * dt;
        pos = state(1:3)';
        ori = state(4:6)';
        rates = state(10:12)';
        u = state(7); v = state(8); w = state(9);
        [Uh, zdot, VD] = inertial_Uh_zdot_vd(ori, u, v, w);
        theta_phys_now = -ori(2);

        % --- guidance (production) then add crab dpsi once ---
        if mod(k - 1, guidance_period) == 0
            [yaw_ref_prod, pitch_ref, u_ref, pidx, r_ff, pitch_ref_dot] = ...
                guidance_law(pos, path, pidx, u, v, Uh, zdot, theta_phys_now);
            th_hold = path_horiz_tangent(path, pos);
            Vhat_now = ObsSt.v;
            [dpsi, dpsi_raw, dpsi_act] = crab_dpsi(th_hold, Vhat_now, Uref, t_now, dpsi, ff, dt_guidance);
            yaw_ref = wrapToPi(yaw_ref_prod + dpsi);
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

        % Plant logs for observer
        if isempty(plant_last_nu); plant_last_nu = state(7:12); end
        if isempty(plant_last_nu_c); plant_last_nu_c = zeros(6,1); end
        if isempty(plant_last_nu_r); plant_last_nu_r = plant_last_nu; end
        if isempty(plant_last_V_g_ned); plant_last_V_g_ned = zeros(3,1); end
        if isempty(plant_last_V_w_body); plant_last_V_w_body = state(7:9)'; end

        t_log = k * dt;
        ObsSt = step_online_observer(ObsSt, t_log, state, ...
            plant_last_V_g_ned(:), plant_last_V_w_body(:), obs);

        S.t(k) = t_log;
        S.vp(k, :) = state(1:3);
        S.vel(k, :) = state(7:9);
        S.rates(k, :) = state(10:12);
        S.ori(k, :) = state(4:6);
        S.psi_ref(k) = yaw_ref;
        S.psi_ref_prod(k) = yaw_ref_prod;
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

        S.nu(k, :) = plant_last_nu(:)';
        S.nu_c(k, :) = plant_last_nu_c(:)';
        S.nu_r(k, :) = plant_last_nu_r(:)';
        S.V_ground_ned(k, :) = plant_last_V_g_ned(:)';
        S.V_water_body(k, :) = plant_last_V_w_body(:)';
        S.Vhat(k, :) = ObsSt.v.';
        S.dpsi(k) = dpsi;
        S.dpsi_raw(k) = dpsi_raw;
        S.dpsi_act(k) = dpsi_act;
        S.th(k, :) = th_hold(:).';
        S.obs_bound_hit(k) = ObsSt.hit_now;
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
        elseif islogical(A) && numel(A) >= n_steps
            S.(fn{i}) = A(1:n_steps);
        end
    end
    S.ok = ok;
    S.finite = ok && all(isfinite(S.vp(:))) && all(isfinite(S.vel(:))) && all(isfinite(S.ori(:)));
    S.u_body = S.vel(:, 1); S.v_body = S.vel(:, 2); S.w_body = S.vel(:, 3);
    S.obs_bound_hits = sum(S.obs_bound_hit);
end

function th = path_horiz_tangent(path, pos)
    d = path - pos;
    [~, idx] = min(sum(d.^2, 2));
    idx = max(1, min(size(path, 1) - 1, idx));
    tang = path(idx + 1, :) - path(idx, :);
    th = tang(1:2)';
    nrm = norm(th);
    if nrm < 1e-9
        th = [1; 0];
    else
        th = th / nrm;
    end
end

function [dpsi, dpsi_raw, act] = crab_dpsi(th, Vhat, Uref, t_now, dpsi_prev, ff, dt_g)
    th = th(:);
    Vne = Vhat(1:2); Vne = Vne(:);
    vw = Uref * th - Vne;
    if norm(vw) < 1e-9
        dpsi_raw = 0;
    else
        chi_w = atan2(vw(2), vw(1));
        chi_t = atan2(th(2), th(1));
        dpsi_raw = wrapToPi(chi_w - chi_t);
    end
    % half-cosine activation 0→1 over [0, act_T]
    if t_now >= ff.act_T
        act = 1.0;
    elseif t_now <= 0
        act = 0.0;
    else
        act = 0.5 * (1 - cos(pi * t_now / ff.act_T));
    end
    dpsi_cmd = act * max(min(dpsi_raw, ff.dpsi_max), -ff.dpsi_max);
    % rate limit
    dd_max = ff.dpsi_rate * max(dt_g, 1e-6);
    dd = max(min(dpsi_cmd - dpsi_prev, dd_max), -dd_max);
    dpsi = dpsi_prev + dd;
end

%% ===================== online observer =====================
function St = init_online_observer(obs, dt, n_steps, seed_obs)
    St = struct();
    St.dt = dt;
    St.alpha = 1 - exp(-obs.wo * dt);
    St.v = obs.Vhat0(:);
    St.V_bound = obs.V_bound;
    St.hit_now = false;
    % Pre-generate ZOH noise streams (same construction as bias/latency audit)
    rng(seed_obs, 'twister');
    t = (1:n_steps)' * dt;
    [St.n_ins, ~] = zoh_white(t, obs.ins_fs, obs.ins_sigma, 3);
    [St.n_dvl, ~] = zoh_white(t, obs.dvl_fs, obs.dvl_sigma, 3);
    St.ins_bias = obs.ins_bias_ned(:);
    St.dvl_bias = obs.dvl_bias_body(:);
    St.ins_lat = obs.ins_latency_s;
    St.dvl_lat = obs.dvl_latency_s;
    % History buffers for causal delay
    max_lag = max(1, ceil(max(St.ins_lat, St.dvl_lat) / dt) + 5);
    St.buf_n = max_lag + 8;
    St.buf_t = -inf(St.buf_n, 1);
    St.buf_Vg = zeros(St.buf_n, 3);
    St.buf_Vw = zeros(St.buf_n, 3);
    St.buf_i = 0;
    St.k = 0;
end

function St = step_online_observer(St, t, state, Vg_true, Vw_body_true, obs) %#ok<INUSD>
    St.k = St.k + 1;
    k = min(St.k, size(St.n_ins, 1));
    Vg_c = Vg_true(:) + St.ins_bias + St.n_ins(k, :)';
    Vw_c = Vw_body_true(:) + St.dvl_bias + St.n_dvl(k, :)';

    % push buffer
    St.buf_i = St.buf_i + 1;
    idx = mod(St.buf_i - 1, St.buf_n) + 1;
    St.buf_t(idx) = t;
    St.buf_Vg(idx, :) = Vg_c.';
    St.buf_Vw(idx, :) = Vw_c.';

    Vg_del = causal_buf_lookup(St.buf_t, St.buf_Vg, t - St.ins_lat, St.buf_i, St.buf_n);
    Vw_del = causal_buf_lookup(St.buf_t, St.buf_Vw, t - St.dvl_lat, St.buf_i, St.buf_n);

    R = rotmat(state(4), state(5), state(6));
    yc = Vg_del(:) - R * Vw_del(:);
    St.v = St.v + St.alpha * (yc - St.v);
    pre = St.v;
    St.v = max(min(St.v, St.V_bound), -St.V_bound);
    St.hit_now = any(abs(pre) > St.V_bound + 1e-15);
end

function y = causal_buf_lookup(buf_t, buf_y, t_need, buf_i, buf_n)
    % Last sample with t_src <= t_need; startup hold earliest sample
    y = zeros(3, 1);
    best_t = -inf;
    tmin = inf; iimin = 1;
    n_fill = min(buf_i, buf_n);
    for j = 1:n_fill
        ii = mod(buf_i - j, buf_n) + 1;
        tj = buf_t(ii);
        if ~isfinite(tj); continue; end
        if tj < tmin
            tmin = tj; iimin = ii;
        end
        if tj <= t_need + 1e-15 && tj >= best_t
            best_t = tj;
            y = buf_y(ii, :).';
        end
    end
    if ~isfinite(best_t)
        y = buf_y(iimin, :).';
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
    % smoothness proxy: rudder rate util + chatter
    M.act.smooth_proxy = hypot(nz(M.act.dr_rate_util), nz(M.act.chatter_dps) / HG.chatter);

    st = [S.ori, S.vel, S.rates];
    M.bounded = all(isfinite(st(:))) && all(isfinite(S.thrust)) && ...
        all(abs(theta_phys) < deg2rad(80)) && all(abs(S.u_body) < 5.0) && ...
        all(abs(S.rates(:)) < deg2rad(200));
end

function M = fail_M(M)
    M.speed = struct('mae', NaN, 'p95', NaN, 'rms', NaN);
    M.theta = struct('mae_deg', NaN, 'p95_deg', NaN, 'rms_deg', NaN);
    M.gamma = struct('mae_deg', NaN, 'p95_deg', NaN, 'rms_deg', NaN);
    M.yaw = struct('mae_deg', NaN, 'p95_deg', NaN, 'rms_deg', NaN, ...
        'rudder_sat_ss_pct', NaN, 'rudder_sat_full_pct', NaN, ...
        'ratio_r_Uh_kappa', NaN, 'n_ratio_valid', 0);
    M.roll = struct('tilde_mae_deg', NaN, 'p_rms_dps', NaN);
    M.path = struct('mean_cte', NaN, 'max_cte', NaN);
    M.depth = struct('e_z_rms', NaN, 'e_z_mae', NaN, 'e_z_p95', NaN);
    M.act = struct('de_mag_util', NaN, 'dr_mag_util', NaN, 'thr_mag_util', NaN, ...
        'de_rate_util', NaN, 'dr_rate_util', NaN, 'thr_rate_util', NaN, ...
        'de_sat_pct', NaN, 'dr_sat_ss_pct', NaN, 'dr_sat_full_pct', NaN, ...
        'thr_sat_pct', NaN, 'chatter_dps', NaN, 'smooth_proxy', NaN);
    M.bounded = false;
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

function Reg = regression_vs_base(Mb, Mc, frac)
    % <=2% regression vs CURRENT baseline on tracking / yaw / pitch / gamma / CTE / acts
    Reg = struct('pass', true, 'first', 'none', 'items', {{}});
    checks = {
        'thMAE',  Mc.theta.mae_deg, Mb.theta.mae_deg
        'thP95',  Mc.theta.p95_deg, Mb.theta.p95_deg
        'thRMS',  getf(Mc.theta,'rms_deg'), getf(Mb.theta,'rms_deg')
        'gMAE',   Mc.gamma.mae_deg, Mb.gamma.mae_deg
        'gP95',   Mc.gamma.p95_deg, Mb.gamma.p95_deg
        'gRMS',   getf(Mc.gamma,'rms_deg'), getf(Mb.gamma,'rms_deg')
        'yawMAE', Mc.yaw.mae_deg, Mb.yaw.mae_deg
        'yawP95', Mc.yaw.p95_deg, Mb.yaw.p95_deg
        'yawRMS', getf(Mc.yaw,'rms_deg'), getf(Mb.yaw,'rms_deg')
        'CTE',    Mc.path.mean_cte, Mb.path.mean_cte
        'deSat',  Mc.act.de_sat_pct, Mb.act.de_sat_pct
        'deRate', Mc.act.de_rate_util, Mb.act.de_rate_util
        'drRate', Mc.act.dr_rate_util, Mb.act.dr_rate_util
        'thrSat', Mc.act.thr_sat_pct, Mb.act.thr_sat_pct
        'chat',   Mc.act.chatter_dps, Mb.act.chatter_dps
    };
    for i = 1:size(checks, 1)
        name = checks{i, 1}; val = checks{i, 2}; ref = checks{i, 3};
        if ~isfinite(val) || ~isfinite(ref)
            ok = isfinite(val) || (~isfinite(ref) && ~isfinite(val));
            limv = Inf;
        elseif abs(ref) < 1e-9
            ok = abs(val) <= max(1e-3, frac);
            limv = max(1e-3, frac);
        else
            limv = abs(ref) * (1 + frac);
            ok = val <= limv + 1e-9;
        end
        Reg.items{end+1} = struct('name', name, 'val', val, 'ref', ref, 'lim', limv, 'ok', ok); %#ok<AGROW>
        if ~ok
            Reg.pass = false;
            if strcmp(Reg.first, 'none')
                Reg.first = sprintf('%s(%.4g>%.4g=+2%%)', name, val, limv);
            end
        end
    end
end

function Imp = sat_smooth_improve(Mb, Mc)
    Imp = struct();
    sb = nz(Mb.act.dr_sat_full_pct); sc = nz(Mc.act.dr_sat_full_pct);
    if sb > 1e-9
        Imp.sat_improve_frac = (sb - sc) / sb;
    else
        Imp.sat_improve_frac = tern(sc <= sb, 1.0, -Inf);
    end
    % smoothness: lower chatter and/or rudder rate util is better
    cb = nz(Mb.act.chatter_dps); cc = nz(Mc.act.chatter_dps);
    rb = nz(Mb.act.dr_rate_util); rc = nz(Mc.act.dr_rate_util);
    sm_b = hypot(rb, cb);
    sm_c = hypot(rc, cc);
    if sm_b > 1e-9
        Imp.smooth_improve_frac = (sm_b - sm_c) / sm_b;
    else
        Imp.smooth_improve_frac = tern(sm_c <= sm_b, 1.0, -Inf);
    end
    Imp.pass_10pct = (Imp.sat_improve_frac >= 0.10) || (Imp.smooth_improve_frac >= 0.10);
    Imp.sat_base = sb; Imp.sat_cand = sc;
    Imp.smooth_base = sm_b; Imp.smooth_cand = sm_c;
end

function BA = before_after(Mb, Mc)
    BA = struct();
    BA.thMAE = [nz(Mb.theta.mae_deg), nz(Mc.theta.mae_deg)];
    BA.gMAE  = [nz(Mb.gamma.mae_deg), nz(Mc.gamma.mae_deg)];
    BA.yawMAE = [nz(Mb.yaw.mae_deg), nz(Mc.yaw.mae_deg)];
    BA.CTE = [nz(Mb.path.mean_cte), nz(Mc.path.mean_cte)];
    BA.e_z_rms = [nz(Mb.depth.e_z_rms), nz(Mc.depth.e_z_rms)];
    BA.de_sat = [nz(Mb.act.de_sat_pct), nz(Mc.act.de_sat_pct)];
    BA.dr_satF = [nz(Mb.act.dr_sat_full_pct), nz(Mc.act.dr_sat_full_pct)];
    BA.chat = [nz(Mb.act.chatter_dps), nz(Mc.act.chatter_dps)];
    BA.dr_rate = [nz(Mb.act.dr_rate_util), nz(Mc.act.dr_rate_util)];
end

function O = score_observer_from_trace(S, obs, Vc_true)
    n = numel(S.t);
    Vhat = S.Vhat;
    err = Vhat - repmat(Vc_true(:).', n, 1);
    err_norm = sqrt(sum(err.^2, 2));
    ss = S.t >= obs.steady_t0;
    if ~any(ss); ss = true(n, 1); end
    err_ss = err(ss, :); en_ss = err_norm(ss);
    bias = mean(err_ss, 1).';
    bias_norm = norm(bias);
    rmse_norm = sqrt(mean(en_ss.^2));
    p95_norm = percentile95(en_ss);
    O = struct();
    O.t = S.t; O.Vhat = Vhat; O.err = err; O.err_norm = err_norm;
    O.err_final_norm = err_norm(end);
    if isfield(S, 'obs_bound_hits'); O.bound_hits = S.obs_bound_hits;
    else; O.bound_hits = 0; end
    O.Vhat_max_abs = max(abs(Vhat), [], 'all');
    O.steady = struct('t0', obs.steady_t0, 'bias', bias, 'bias_norm', bias_norm, ...
        'rmse_norm', rmse_norm, 'p95_norm', p95_norm, 'max_norm', max(en_ss), 'n', sum(ss));
    O.pass_bias = bias_norm <= 0.030;
    O.pass_rmse = rmse_norm <= 0.035;
    O.pass_p95 = p95_norm <= 0.070;
    O.pass_final = O.err_final_norm <= 0.050;
    O.pass_bounded = O.Vhat_max_abs <= obs.V_bound + 1e-12;
    O.pass_no_hits = O.bound_hits == 0;
end

function p = percentile95(x)
    x = sort(x(:));
    if isempty(x); p = NaN; return; end
    idx = max(1, min(numel(x), ceil(0.95 * numel(x))));
    p = x(idx);
end

%% ===================== path / kinematics helpers =====================
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
    keep = {'t','vp','vel','rates','ori','psi_ref','psi_ref_prod','theta_ref','u_ref','u_ctrl', ...
        'u_body','thrust','delta_e','delta_r','Uh','VD','Uref','dt','R','is_xz', ...
        'Vc','lambda','e_z','nu','nu_c','nu_r','V_ground_ned','V_water_body', ...
        'U_h_guid','kappa','r','Vhat','dpsi','dpsi_raw','dpsi_act','th', ...
        'obs_bound_hit','obs_bound_hits','ok','finite'};
    P = struct();
    for i = 1:numel(keep)
        if isfield(S, keep{i}); P.(keep{i}) = S.(keep{i}); end
    end
end

%% ===================== outputs =====================
function write_png(png_path, R, task_id, verdict, Vc)
    fig = figure('Visible', 'off', 'Position', [40 40 1400 1000]);
    tiledlayout(3, 3, 'Padding', 'compact', 'TileSpacing', 'compact');
    names = {'X','XZ','R10'};
    for i = 1:3
        rr = R.routes.(names{i});
        tr = rr.traces;

        nexttile;
        plot(tr.t, rad2deg(tr.dpsi), 'b-'); hold on;
        plot(tr.t, rad2deg(tr.dpsi_raw), 'Color', [0.6 0.6 0.6]);
        grid on; ylabel('deg'); title(sprintf('%s dpsi / raw', names{i}));
        if i == 1; legend('dpsi','raw', 'Location', 'best'); end

        nexttile;
        plot(tr.t, tr.Vhat(:,2), 'b'); hold on;
        yline(Vc(2), 'r--');
        grid on; ylabel('m/s'); title(sprintf('%s Vhat_E', names{i}));

        nexttile;
        plot(tr.t, rad2deg(tr.delta_r), 'm'); hold on;
        grid on; ylabel('deg'); title(sprintf('%s rudder  satF=%.2f%%', names{i}, ...
            nz(rr.M.act.dr_sat_full_pct)));
    end
    sgtitle(sprintf('%s %s — crab-current yaw FF (isolated)', task_id, verdict), ...
        'Interpreter', 'none');
    exportgraphics(fig, png_path, 'Resolution', 150);
    close(fig);
end

function write_md(md_path, R, lim)
    fid = fopen(md_path, 'w');
    fprintf(fid, '# %s — Isolated crab-current yaw-ref feedforward\n\n', R.task_id);
    fprintf(fid, '**Overall verdict: %s**\n\n', R.verdict);

    fprintf(fid, '## Provenance\n\n');
    fprintf(fid, '- Read-only: `guidance_law.m`, `run_combined_6dof_disturbance_baseline.m`, `run_current_observer_bias_latency.m`\n');
    fprintf(fid, '- Prior: COMBINED_6DOF_DISTURBANCE_BASELINE FAIL first=`%s`\n', R.baseline_first_limit);
    fprintf(fid, '- Driver: `run_crab_current_ff_candidate.m` (one invocation)\n');
    fprintf(fid, '- Production plant/controller/guidance: **UNTOUCHED / FROZEN**\n');
    fprintf(fid, '- Gain sweep: **NO**\n');
    fprintf(fid, '- Artifacts: `%s`, `%s`, `%s`\n', R.paths.md, R.paths.mat, R.paths.png);
    fprintf(fid, '- Did **not** touch `CODEX_VERTICAL_PLAN.md`\n\n');

    fprintf(fid, '## Algebra (no double-count)\n\n');
    fprintf(fid, '```\n');
    fprintf(fid, 'PROD:  %s\n', R.algebra.production_yaw);
    fprintf(fid, 'PROD:  %s\n', R.algebra.production_r_ff);
    fprintf(fid, 'CAND:  %s\n', R.algebra.candidate_dpsi);
    fprintf(fid, 'COMPOSE: %s\n', R.algebra.compose);
    fprintf(fid, '```\n');
    fprintf(fid, '- %s\n\n', R.algebra.no_double_count);

    fprintf(fid, '## Setup\n\n');
    fprintf(fid, '- U=%.1f m/s; Vc=[%.2f, %.2f, %.2f] NED; routes X / XZ / R10\n', R.Uref, R.Vc_cross);
    fprintf(fid, '- Observer wo=%.2f; declared noise/bias/latency; seed_obs=%d; seed_plant=%d\n', ...
        R.observer_cfg.wo, R.seed_obs, R.seed_plant);
    fprintf(fid, '- dpsi clamp ±%.0f deg, rate %.0f deg/s, half-cosine act T=%.0f s\n', ...
        rad2deg(R.ff.dpsi_max), rad2deg(R.ff.dpsi_rate), R.ff.act_T);
    fprintf(fid, '- Act rate limit plant: %.0f deg/s elev/rudder\n\n', rad2deg(lim.de_rate));

    fprintf(fid, '## Before → after (CURRENT baseline → crab FF) @ U=1.5\n\n');
    fprintf(fid, '| Route | thMAE | gMAE | yawMAE | CTE | deSat%% | drSatF%% | chat | drRateU | FEAS | first |\n');
    fprintf(fid, '|---|---:|---:|---:|---:|---:|---:|---:|---:|:---:|---|\n');
    names = {'X','XZ','R10'};
    for i = 1:3
        rr = R.routes.(names{i}); BA = rr.before_after;
        fprintf(fid, '| %s | %.4f→%.4f | %.4f→%.4f | %.4f→%.4f | %.3f→%.3f | %.2f→%.2f | %.2f→%.2f | %.4f→%.4f | %.3f→%.3f | %s | %s |\n', ...
            names{i}, BA.thMAE(1), BA.thMAE(2), BA.gMAE(1), BA.gMAE(2), ...
            BA.yawMAE(1), BA.yawMAE(2), BA.CTE(1), BA.CTE(2), ...
            BA.de_sat(1), BA.de_sat(2), BA.dr_satF(1), BA.dr_satF(2), ...
            BA.chat(1), BA.chat(2), BA.dr_rate(1), BA.dr_rate(2), ...
            yn(rr.feas.feasible), sanitize(rr.feas.first_limit));
    end
    fprintf(fid, '\n');

    fprintf(fid, '## R10 sat / smoothness improvement\n\n');
    Imp = R.routes.R10.sat_smooth;
    fprintf(fid, '| Metric | Baseline | Candidate | Improve |\n|---|---:|---:|---:|\n');
    fprintf(fid, '| rudder full-sat %% | %.2f | %.2f | %.1f%% |\n', ...
        Imp.sat_base, Imp.sat_cand, 100*Imp.sat_improve_frac);
    fprintf(fid, '| smooth proxy (hypot rate,chat) | %.4f | %.4f | %.1f%% |\n', ...
        Imp.smooth_base, Imp.smooth_cand, 100*Imp.smooth_improve_frac);
    fprintf(fid, '| pass >=10%% | — | — | %s |\n\n', yn(Imp.pass_10pct));

    fprintf(fid, '## Regression vs CURRENT baseline (<=2%%)\n\n');
    fprintf(fid, '| Route | PASS | First |\n|---|:---:|---|\n');
    for i = 1:3
        rr = R.routes.(names{i});
        fprintf(fid, '| %s | %s | %s |\n', names{i}, yn(rr.reg_vs_base.pass), ...
            sanitize(rr.reg_vs_base.first));
    end
    fprintf(fid, '\n');

    fprintf(fid, '## Observer (in-loop causal Vhat; declared harness gates)\n\n');
    fprintf(fid, '| Route | bias||mean|| | RMSE_ss | p95_ss | final||err|| | hits | PASS |\n');
    fprintf(fid, '|---|---:|---:|---:|---:|---:|:---:|\n');
    for i = 1:3
        O = R.obs.(names{i});
        pok = O.pass_bias && O.pass_rmse && O.pass_p95 && O.pass_final && O.pass_bounded && O.pass_no_hits;
        fprintf(fid, '| %s | %.4e | %.4e | %.4e | %.4e | %d | %s |\n', ...
            names{i}, O.steady.bias_norm, O.steady.rmse_norm, O.steady.p95_norm, ...
            O.err_final_norm, O.bound_hits, yn(pok));
    end
    fprintf(fid, '\n');

    fprintf(fid, '## Traces saved\n\n');
    fprintf(fid, '- Per route in `.mat`: `traces.dpsi`, `traces.dpsi_raw`, `traces.dpsi_act`,\n');
    fprintf(fid, '  `traces.Vhat`, `traces.delta_r`, `traces.th`, `traces.psi_ref_prod`, `traces.psi_ref`\n\n');

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
    fprintf(fid, '- Do **not** promote to production. CODEX_VERTICAL_PLAN untouched.\n');
    fclose(fid);
end

function append_research_log(log_path, R)
    fid = fopen(log_path, 'a');
    fprintf(fid, '\n\n## %s — %s\n\n', R.task_id, datestr(now, 31));
    fprintf(fid, '- Verdict: **%s** — isolated crab-current yaw-ref FF (causal biased/noisy Vhat); production frozen; no sweep.\n', R.verdict);
    fprintf(fid, '- Law: vw=Uref*th-Vhat_NE; dpsi=wrap(atan2(vw_E,vw_N)-atan2(th_E,th_N)); clamp±8deg rate≤3deg/s × half-cosine 0→1/5s; yaw_ref+=dpsi once; beta+r_ff preserved.\n');
    fprintf(fid, '- Algebra: beta=body sideslip vs water; dpsi=water-track vs path from Vhat; r_ff=U_h*kappa rate FF — no double-count.\n');
    names = {'X','XZ','R10'};
    for i = 1:3
        rr = R.routes.(names{i}); BA = rr.before_after;
        fprintf(fid, '- %s before→after: thMAE %.4f→%.4f yawMAE %.4f→%.4f CTE %.3f→%.3f drSatF %.2f→%.2f chat %.4f→%.4f | FEAS=%s first=%s\n', ...
            names{i}, BA.thMAE(1), BA.thMAE(2), BA.yawMAE(1), BA.yawMAE(2), ...
            BA.CTE(1), BA.CTE(2), BA.dr_satF(1), BA.dr_satF(2), ...
            BA.chat(1), BA.chat(2), yn(rr.feas.feasible), rr.feas.first_limit);
    end
    Imp = R.routes.R10.sat_smooth;
    fprintf(fid, '- R10 sat improve=%.1f%% smooth improve=%.1f%% (need>=10%%); observer max bias/rmse/p95/final: %.3e / %.3e / %.3e / %.3e (hits=%d)\n', ...
        100*Imp.sat_improve_frac, 100*Imp.smooth_improve_frac, ...
        R.obs_summary.bias_norm_max_all, R.obs_summary.rmse_norm_max_all, ...
        R.obs_summary.p95_norm_max_all, R.obs_summary.final_err_max_all, ...
        R.obs_summary.bound_hits_total);
    fprintf(fid, '- First limit: `%s`\n', R.first_limit);
    fprintf(fid, '- Artifacts: suite_results/CRAB_CURRENT_FF_CANDIDATE.{md,mat,png}; driver `run_crab_current_ff_candidate.m`.\n');
    fprintf(fid, '- Next: **`%s`** — %s\n', R.next.gate, R.next.detail);
    fprintf(fid, '- CODEX_VERTICAL_PLAN untouched.\n');
    fclose(fid);
end

function print_feedback(R)
    fprintf('\n========== FEEDBACK ==========\n');
    fprintf('VERDICT: %s\n', R.verdict);
    fprintf('first_limit: %s\n', R.first_limit);
    names = {'X','XZ','R10'};
    for i = 1:3
        rr = R.routes.(names{i}); BA = rr.before_after;
        fprintf('%s: th %.4f→%.4f yaw %.4f→%.4f CTE %.3f→%.3f drSatF %.2f→%.2f FEAS=%s (%s)\n', ...
            names{i}, BA.thMAE(1), BA.thMAE(2), BA.yawMAE(1), BA.yawMAE(2), ...
            BA.CTE(1), BA.CTE(2), BA.dr_satF(1), BA.dr_satF(2), ...
            yn(rr.feas.feasible), rr.feas.first_limit);
    end
    Imp = R.routes.R10.sat_smooth;
    fprintf('R10 sat improve=%.1f%% smooth=%.1f%%\n', 100*Imp.sat_improve_frac, 100*Imp.smooth_improve_frac);
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

function v = getf(s, f)
    if isstruct(s) && isfield(s, f); v = s.(f); else; v = NaN; end
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
