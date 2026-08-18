function run_trim_alpha_ff_rate_limit()
% TRIM_ALPHA_FF_RATE_LIMIT_001 — actuator-feasible rate-limit on alpha_ff only.
% Read-only: TRIM_ALPHA_FF_BENCHMARK.mat, TRIM_ALPHA_SCHEDULE_ID.mat,
%            guidance_law_trim_alpha_ff.m. One invocation; production untouched.
% Same schedule/gains as unshaped AFF; add persistent alpha_cmd(0)=0 with
%   |d alpha_cmd/dt|<=2deg/s; pitch_raw=gamma_path+pitch_corr+alpha_cmd (no LPF).
% Routes: X / XZ / R10. Compare P / A04 / unshaped AFF / shaped RL.
% Roll gate: own-speed empirical equilibrium. Artifacts: TRIM_ALPHA_FF_RATE_LIMIT.*.

    project_dir = fileparts(mfilename('fullpath'));
    addpath(project_dir);
    out_dir = fullfile(project_dir, 'suite_results');
    if ~exist(out_dir, 'dir'); mkdir(out_dir); end
    tag = 'TRIM_ALPHA_FF_RATE_LIMIT';
    task_id = 'TRIM_ALPHA_FF_RATE_LIMIT_001';

    sched_path = fullfile(out_dir, 'TRIM_ALPHA_SCHEDULE_ID.mat');
    aff_path   = fullfile(out_dir, 'TRIM_ALPHA_FF_BENCHMARK.mat');
    aff_guid   = fullfile(project_dir, 'guidance_law_trim_alpha_ff.m');
    cand_path  = fullfile(project_dir, 'guidance_law_trim_alpha_ff_rate_limit.m');
    prod_path  = fullfile(project_dir, 'guidance_law.m');
    assert(exist(sched_path, 'file') == 2, 'Missing %s', sched_path);
    assert(exist(aff_path, 'file') == 2, 'Missing %s', aff_path);
    assert(exist(aff_guid, 'file') == 2, 'Missing %s', aff_guid);
    assert(exist(cand_path, 'file') == 2, 'Missing %s', cand_path);

    SchedIn = load(sched_path);
    AffIn = load(aff_path);
    aff_txt = fileread(aff_guid);
    cand_txt = fileread(cand_path);
    prod_txt = fileread(prod_path);
    assert(~contains(prod_txt, 'alpha_ff_c0'), 'production must not reference alpha_ff_c0');
    assert(~contains(prod_txt, 'alpha_ff_rate_max'), 'production must not reference rate limit');
    assert(contains(aff_txt, 'pitch_raw = gamma_path + K_gamma * eg_f + pitch_corr + alpha_ff'), ...
        'unshaped AFF helper missing pitch_raw+alpha_ff');
    assert(~contains(aff_txt, 'alpha_cmd'), 'unshaped AFF must remain unshaped');
    assert(contains(cand_txt, 'alpha_ff = alpha_ff_c0 / max(u_ref, alpha_ff_u_min)^2'), ...
        'candidate missing trim alpha_ff schedule');
    assert(contains(cand_txt, 'pitch_raw = gamma_path + K_gamma * eg_f + pitch_corr + alpha_cmd'), ...
        'candidate missing pitch_raw=gamma_path+pitch_corr+alpha_cmd');
    assert(contains(cand_txt, 'alpha_ff_rate_max'), 'candidate missing alpha rate limit');
    assert(~contains(cand_txt, '0.98 * alpha_hat + 0.02'), 'candidate must not use measured alpha LPF');

    Sched = SchedIn.schedule;
    law = AffIn.law;
    assert(abs(law.kD - 1.694074) < 5e-6, 'kD mismatch');
    assert(abs(law.Kp - 25) < 1e-9, 'Kp mismatch');
    assert(abs(law.Ki - 13.8362) < 5e-4, 'Ki mismatch');
    assert(abs(law.Kaw - 0.553447) < 5e-6, 'Kaw mismatch');
    assert(abs(Sched.c0 - 7.5013943801e-02) < 1e-10, 'c0 mismatch vs ID');
    assert(abs(Sched.c_gamma - 4.7291247774e-02) < 1e-10, 'c_gamma mismatch vs ID');

    fprintf('\n========== %s ==========\n', task_id);
    fprintf('Read-only: TRIM_ALPHA_FF_BENCHMARK.mat | TRIM_ALPHA_SCHEDULE_ID.mat | guidance_law_trim_alpha_ff.m\n');
    fprintf('Shaping: alpha_cmd(0)=0; |d alpha_cmd/dt|<=2deg/s; pitch_raw=gamma_path+pitch_corr+alpha_cmd\n');
    fprintf('Routes: X / XZ / R10 | compare P/A04/AFF/RL | own-eq roll | production untouched\n');

    clear functions
    clear guidance_law guidance_law_trim_alpha_ff guidance_law_trim_alpha_ff_rate_limit controller_law
    clear global lambda_muw_ff trim_speed_table trim_elevator_table elevator_sign
    clear global K_zdot K_gamma enable_alpha_hat Ki_z_depth Kz_depth
    clear global alpha_ff_c0 alpha_ff_c_gamma alpha_ff_u_min alpha_ff_rate_max
    clear global last_guidance_U_h last_guidance_kappa last_r_ff
    clear global Kp_roll
    clear global last_alpha_hat last_gamma_actual last_gamma_path last_e_gamma last_alpha_eff
    clear global last_z_e_f last_z_e_i last_zd_e_f last_pitch_corr
    clear global last_corr_P last_corr_I last_corr_zd
    clear global last_alpha_ff last_alpha_cmd last_alpha_cmd_dot

    init_parameters();
    global lambda_muw_ff elevator_sign trim_speed_table trim_elevator_table
    global K_zdot K_gamma enable_alpha_hat Ki_z_depth Kz_depth
    global alpha_ff_c0 alpha_ff_c_gamma alpha_ff_u_min alpha_ff_rate_max
    global dt_controller delta_e_max delta_r_max
    global Kp_x thrust_trim thrust_max thrust_min desired_speed Kp_roll

    elevator_sign = 1;
    trim_speed_table = [0.8 1.0 1.5 2.0];
    trim_elevator_table = deg2rad([-9.18 -7.33 -4.62 -3.17]);
    K_gamma = 0; K_zdot = 0; enable_alpha_hat = false;
    Ki_z_depth = 0; Kz_depth = 0.040;
    alpha_ff_c0 = Sched.c0;
    alpha_ff_c_gamma = Sched.c_gamma;
    alpha_ff_u_min = Sched.u_min;
    alpha_ff_rate_max = deg2rad(2);  % TUNED: 1/3 of pitch_ref_rate_max=6deg/s
    if isfield(law, 'Kp_roll'); Kp_roll = law.Kp_roll; end
    desired_speed = 1.5;
    Kp_x = law.Kp;

    seed_used = 0;
    rng(seed_used, 'twister');

    if isfield(AffIn, 'limits')
        lim = AffIn.limits;
    else
        lim = struct('dr_max', delta_r_max, 'de_max', delta_e_max, ...
            'dr_rate', deg2rad(40), 'near_frac', 0.80, ...
            'thrust_max', thrust_max, 'thrust_min', thrust_min);
    end

    nX = 600; xX = linspace(0, 45, nX)';
    pathX = [xX, zeros(nX, 1), zeros(nX, 1)];
    nXZ = 900; xXZ = linspace(0, 42, nXZ)';
    pathXZ = [xXZ, zeros(nXZ, 1), 0.4 * xXZ];
    pathH = generate_balanced_helical_path(10.0, 2.0, 2, 500);

    routes = { ...
        struct('name','X',  'path',pathX,  'T',18, 'u0',1.5, 'win','first_hold', 'xz',false, 'R',0); ...
        struct('name','XZ', 'path',pathXZ, 'T',22, 'u0',1.5, 'win','persistent', 'xz',true,  'R',0); ...
        struct('name','H',  'path',pathH,  'T',45, 'u0',1.5, 'win','persistent', 'xz',false, 'R',10)};

    % Load P / U / A04 / unshaped AFF from prior AFF benchmark (identical windows)
    Res = struct();
    src_map = struct('P', 'production', 'U', 'uncorrected', 'A04', 'measured_A04', 'AFF', 'trim_alpha_ff');
    keys = {'P', 'U', 'A04', 'AFF'};
    for k = 1:numel(keys)
        key = keys{k};
        src = AffIn.(src_map.(key));
        for i = 1:numel(routes)
            r = routes{i};
            S = src.(r.name).S;
            M = analyze_route(S, r.path, r.win, lim, r.xz);
            Res.(key).(r.name).S = S;
            Res.(key).(r.name).M = M;
            fprintf('  [load %s/%s] uMAE=%.4f gMAE=%.4f cte=%.4f yaw=%.4f ownT=%.4f set=%.3f os=%.3f\n', ...
                key, r.name, M.speed.steady.mae, M.gamma.mae_deg, M.path.cte_ss_mean, ...
                M.yaw.mae_deg, M.own.tilde.rms_deg, M.settle.settling_s, M.settle.overshoot_deg);
        end
    end

    % Simulate rate-limited shaped candidate only
    cfgT = struct('key','RL', 'label','trim_alpha_ff_rate_limit', 'thrust','candidate', ...
        'alpha',true, 'guid','cand', 'Kz',0.040);
    fprintf('\n===== %s (thrust=%s, alpha_ff rate-limited 2deg/s, Kz=%.3f, no LPF) =====\n', ...
        cfgT.label, cfgT.thrust, cfgT.Kz);
    for i = 1:numel(routes)
        r = routes{i};
        fprintf('\n-- RL %s --\n', r.name);
        rng(seed_used, 'twister');
        [S, M] = sim_analyze(r, lim, cfgT, law);
        Res.RL.(r.name).S = S;
        Res.RL.(r.name).M = M;
        fprintf('  [RL] uMAE=%.4f uP95=%.4f gMAE=%.4f cte=%.4f yaw=%.4f ownT=%.4f set=%.3fos=%.3f\n', ...
            M.speed.steady.mae, M.speed.steady.p95, M.gamma.mae_deg, M.path.cte_ss_mean, ...
            M.yaw.mae_deg, M.own.tilde.rms_deg, M.settle.settling_s, M.settle.overshoot_deg);
    end

    [G, verdict, next_opt, next_detail] = score_all(Res, law, Sched);

    md_path  = fullfile(out_dir, [tag '.md']);
    mat_path = fullfile(out_dir, [tag '.mat']);
    png_path = fullfile(out_dir, [tag '.png']);

    write_png(png_path, Res, lim, task_id, verdict, law, Sched);
    write_md(md_path, task_id, verdict, law, Sched, Res, G, next_opt, next_detail, ...
        seed_used, sched_path, aff_path, aff_guid, cand_path, md_path, mat_path, png_path);
    append_ss_audit(out_dir, task_id, verdict, law, Sched, Res, G, next_opt, next_detail, ...
        md_path, mat_path, png_path);

    Out = struct();
    Out.task_id = task_id;
    Out.verdict = verdict;
    Out.law = law;
    Out.schedule = Sched;
    Out.eq_delta = struct( ...
        'unshaped', 'alpha_ff=c0/max(u_ref,.9)^2+c_gamma*gamma_path; pitch_raw=gamma_path+pitch_corr+alpha_ff', ...
        'shaped', ['alpha_ff=same; alpha_cmd(0)=0; |d alpha_cmd/dt|<=2deg/s; ', ...
                   'pitch_raw=gamma_path+pitch_corr+alpha_cmd (no LPF)'], ...
        'unchanged', 'schedule c0/c_gamma/u_min, Kz=.04, Ki_z=0, K_gamma=0, speed PI+FF, attitude/yaw/roll');
    Out.toggles = struct('K_gamma', 0, 'enable_alpha_hat', true, 'Ki_z_depth', 0, ...
        'Kz_depth', 0.040, 'alpha_lpf', 'NONE', 'alpha_clamp_deg', 8, ...
        'alpha_ff_rate_max_deg', 2, 'c0', Sched.c0, 'c_gamma', Sched.c_gamma, 'u_min', Sched.u_min);
    Out.production = Res.P;
    Out.uncorrected = Res.U;
    Out.measured_A04 = Res.A04;
    Out.trim_alpha_ff = Res.AFF;
    Out.trim_alpha_ff_rate_limit = Res.RL;
    Out.gates = G;
    Out.next_opt = next_opt;
    Out.next_detail = next_detail;
    Out.limits = lim;
    Out.seed_used = seed_used;
    Out.sources = {sched_path; aff_path; aff_guid; cand_path};
    Out.paths = struct('md', md_path, 'mat', mat_path, 'png', png_path);
    Out.production_edited = false;
    Out.note = ['Isolated alpha_ff rate-limit (2deg/s) shapes trim schedule command only; ', ...
        'no LPF; Kz=.04 Ki=0 K_gamma=0; own-eq roll gate'];
    save(mat_path, '-struct', 'Out');

    fprintf('\nVERDICT: %s | next=%s\n', verdict, next_opt);
    fprintf('Saved: %s\n%s\n%s\n', md_path, mat_path, png_path);
    print_feedback(verdict, law, Sched, Res, G, next_opt, next_detail, md_path, mat_path, png_path);
    assignin('base', 'TRIM_ALPHA_FF_RATE_LIMIT_PASS', strcmp(verdict, 'PASS'));
end

%% ===================== simulate =====================
function [S, M] = sim_analyze(route, lim, cfg, law)
    global dt_controller desired_speed lambda_muw_ff
    global K_gamma enable_alpha_hat Ki_z_depth Kz_depth

    K_gamma = 0;
    enable_alpha_hat = logical(cfg.alpha);
    Ki_z_depth = 0;
    Kz_depth = cfg.Kz;

    clear guidance_law guidance_law_trim_alpha_ff guidance_law_trim_alpha_ff_rate_limit controller_law
    clear global last_guidance_U_h last_guidance_kappa last_r_ff
    clear global last_delta_e last_delta_r last_dr_yaw last_dr_p last_dr_damp last_g_ac
    clear global last_int_angle last_int_rate last_de_fb last_de_trim last_de_uw_ff
    clear global last_alpha_hat last_gamma_actual last_gamma_path last_e_gamma last_alpha_eff
    clear global last_z_e_f last_z_e_i last_zd_e_f last_pitch_corr
    clear global last_corr_P last_corr_I last_corr_zd last_e_z last_e_zdot
    clear global last_alpha_ff last_alpha_cmd last_alpha_cmd_dot

    dt = dt_controller;
    path = route.path;
    state0 = zeros(12, 1);
    state0(1:3) = path(1, :)';
    d = path(2, :) - path(1, :);
    state0(5) = -atan2(d(3), norm(d(1:2)));
    state0(6) = atan2(d(2), d(1));
    state0(7) = route.u0;

    if route.R > 0
        lambda_muw_ff = 0.25;
    elseif route.xz
        lambda_muw_ff = 0.0;
    else
        lambda_muw_ff = 0.25;
    end
    desired_speed = 1.5;

    S = sim_loop(path, state0, dt, route.T, cfg, law);
    S.R = route.R; S.is_xz = route.xz; S.cfg = cfg; S.name = route.name;
    S.enable_alpha_hat = enable_alpha_hat; S.K_gamma = K_gamma;
    S.Ki_z_depth = Ki_z_depth; S.Kz_depth = Kz_depth;
    M = analyze_route(S, path, route.win, lim, route.xz);
end

function S = sim_loop(path, state, dt, T_final, cfg, law)
    init_parameters();
    global dt_controller dt_guidance
    global thrust_trim thrust_max thrust_min
    global last_delta_e last_delta_r last_dr_yaw last_dr_p last_dr_damp last_g_ac
    global suite_delta_e_log suite_delta_r_log
    global suite_dr_yaw_log suite_dr_p_log suite_dr_damp_log suite_g_ac_log
    global suite_u_log
    global last_alpha_hat last_gamma_actual last_gamma_path last_e_gamma last_alpha_eff
    global last_z_e_f last_z_e_i last_zd_e_f last_pitch_corr
    global last_corr_P last_corr_I last_corr_zd last_e_z
    global last_alpha_ff last_alpha_cmd last_alpha_cmd_dot
    dt_controller = dt;
    if isempty(dt_guidance); dt_guidance = dt; end

    n_steps = round(T_final / dt);
    vp = zeros(n_steps, 3); times = zeros(n_steps, 1);
    vel = zeros(n_steps, 3);
    rates = zeros(n_steps, 3); ori = zeros(n_steps, 3);
    yaw_refs = zeros(n_steps, 1); pitch_refs = zeros(n_steps, 1);
    u_refs = zeros(n_steps, 1); u_ctrl = zeros(n_steps, 1);
    thrust = zeros(n_steps, 1); Tunsat = zeros(n_steps, 1);
    Tff = zeros(n_steps, 1); Tp = zeros(n_steps, 1); Ti = zeros(n_steps, 1);
    de_log = zeros(n_steps, 1); dr_log = zeros(n_steps, 1);
    dry_log = zeros(n_steps, 1); drp_log = zeros(n_steps, 1);
    drd_log = zeros(n_steps, 1); gac_log = zeros(n_steps, 1);
    ahat_log = zeros(n_steps, 1); aeff_log = zeros(n_steps, 1);
    aff_tgt_log = zeros(n_steps, 1); acmd_log = zeros(n_steps, 1); acmd_dot_log = zeros(n_steps, 1);
    gact_g_log = zeros(n_steps, 1); gpath_g_log = zeros(n_steps, 1);
    eg_g_log = zeros(n_steps, 1);
    zef_log = zeros(n_steps, 1); zei_log = zeros(n_steps, 1);
    zdf_log = zeros(n_steps, 1); pcorr_log = zeros(n_steps, 1);
    cP_log = zeros(n_steps, 1); cI_log = zeros(n_steps, 1); cZd_log = zeros(n_steps, 1);

    I = 0;
    progress_index = 1;
    yaw_ref = 0; pitch_ref = 0; u_ref_g = 0; r_ff = 0; pitch_ref_dot = 0;
    guidance_period = max(1, round(dt_guidance / dt));
    total_time = 0;
    use_cand = strcmp(cfg.guid, 'cand');

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
            if use_cand
                [yaw_ref, pitch_ref, u_ref_g, progress_index, r_ff, pitch_ref_dot] = ...
                    guidance_law_trim_alpha_ff_rate_limit(current_position, path, progress_index, ...
                    current_u, current_v, U_h, zdot_inertial, theta_phys_now);
            else
                [yaw_ref, pitch_ref, u_ref_g, progress_index, r_ff, pitch_ref_dot] = ...
                    guidance_law(current_position, path, progress_index, current_u, ...
                    current_v, U_h, zdot_inertial, theta_phys_now);
            end
        end
        u_ref_eff = u_ref_g;

        [delta_r, delta_e, thr_prod] = controller_law(yaw_ref, pitch_ref, u_ref_eff, ...
            current_orientation(3), current_orientation(2), current_rates(3), ...
            current_rates(2), current_u, r_ff, pitch_ref_dot, ...
            current_orientation(1), current_w, current_rates(1));

        e = u_ref_eff - current_u;
        if strcmp(cfg.thrust, 'baseline')
            thr = thr_prod;
            t_un = thr_prod;
            t_ff = thrust_trim;
            t_p = thr - thrust_trim;
            t_i = 0;
        else
            t_ff = law.kD * u_ref_eff * abs(u_ref_eff);
            t_p = law.Kp * e;
            t_un = t_ff + t_p + I;
            thr = max(min(t_un, thrust_max), thrust_min);
            aw = thr - t_un;
            if abs(aw) > 1e-6 && (sign(e) == -sign(aw) || sign(e) == 0)
                I = I + law.Kaw * aw * dt;
            else
                I = I + law.Ki * e * dt + law.Kaw * aw * dt;
            end
            t_i = I;
        end

        controls.delta_r = delta_r;
        controls.delta_e = delta_e;
        controls.thrust = thr;

        [~, g] = ode45(@(t, gg) underwater777_vehicle_dynamics(t, gg, controls), ...
            [0 dt], state);
        state = g(end, :)';

        vp(idx, :) = state(1:3);
        vel(idx, :) = state(7:9);
        rates(idx, :) = state(10:12);
        ori(idx, :) = state(4:6);
        yaw_refs(idx) = yaw_ref;
        pitch_refs(idx) = pitch_ref;
        u_refs(idx) = u_ref_eff;
        u_ctrl(idx) = current_u;
        thrust(idx) = thr;
        Tunsat(idx) = t_un;
        Tff(idx) = t_ff; Tp(idx) = t_p; Ti(idx) = t_i;
        if isempty(last_delta_e); last_delta_e = delta_e; end
        if isempty(last_delta_r); last_delta_r = delta_r; end
        if isempty(last_dr_yaw); last_dr_yaw = 0; end
        if isempty(last_dr_p); last_dr_p = 0; end
        if isempty(last_dr_damp); last_dr_damp = 0; end
        if isempty(last_g_ac); last_g_ac = 1; end
        if isempty(last_alpha_hat); last_alpha_hat = 0; end
        if isempty(last_alpha_eff); last_alpha_eff = 0; end
        if isempty(last_gamma_actual); last_gamma_actual = 0; end
        if isempty(last_gamma_path); last_gamma_path = 0; end
        if isempty(last_e_gamma); last_e_gamma = 0; end
        if isempty(last_z_e_f); last_z_e_f = 0; end
        if isempty(last_z_e_i); last_z_e_i = 0; end
        if isempty(last_zd_e_f); last_zd_e_f = 0; end
        if isempty(last_pitch_corr); last_pitch_corr = 0; end
        if isempty(last_corr_P); last_corr_P = 0; end
        if isempty(last_corr_I); last_corr_I = 0; end
        if isempty(last_corr_zd); last_corr_zd = 0; end
        if isempty(last_e_z); last_e_z = 0; end
        if isempty(last_alpha_ff); last_alpha_ff = 0; end
        if isempty(last_alpha_cmd); last_alpha_cmd = 0; end
        if isempty(last_alpha_cmd_dot); last_alpha_cmd_dot = 0; end
        de_log(idx) = last_delta_e;
        dr_log(idx) = last_delta_r;
        dry_log(idx) = last_dr_yaw;
        drp_log(idx) = last_dr_p;
        drd_log(idx) = last_dr_damp;
        gac_log(idx) = last_g_ac;
        ahat_log(idx) = last_alpha_hat;
        aeff_log(idx) = last_alpha_eff;
        aff_tgt_log(idx) = last_alpha_ff;
        acmd_log(idx) = last_alpha_cmd;
        acmd_dot_log(idx) = last_alpha_cmd_dot;
        gact_g_log(idx) = last_gamma_actual;
        gpath_g_log(idx) = last_gamma_path;
        eg_g_log(idx) = last_e_gamma;
        zef_log(idx) = last_z_e_f;
        zei_log(idx) = last_z_e_i;
        zdf_log(idx) = last_zd_e_f;
        pcorr_log(idx) = last_pitch_corr;
        cP_log(idx) = last_corr_P;
        cI_log(idx) = last_corr_I;
        cZd_log(idx) = last_corr_zd;
        total_time = total_time + dt;
        times(idx) = total_time;
        if mod(idx, 200) == 0 || idx == n_steps
            fprintf('  %s sim %d/%d t=%.2f u=%.3f thr=%.1f a_tgt=%.2f a_cmd=%.2fdeg\n', ...
                cfg.key, idx, n_steps, total_time, current_u, thr, ...
                rad2deg(aff_tgt_log(idx)), rad2deg(acmd_log(idx)));
        end
    end

    suite_delta_e_log = de_log;
    suite_delta_r_log = dr_log;
    suite_dr_yaw_log = dry_log;
    suite_dr_p_log = drp_log;
    suite_dr_damp_log = drd_log;
    suite_g_ac_log = gac_log;
    suite_u_log = u_ctrl;

    S = struct();
    S.dt = dt; S.T_final = T_final; S.t = times(:);
    S.vp = vp; S.vel = vel; S.rates = rates; S.ori = ori;
    S.psi_ref = yaw_refs(:); S.theta_ref = pitch_refs(:);
    S.u_ref = u_refs(:); S.u_ctrl = u_ctrl(:);
    S.u_body = vel(:, 1); S.v_body = vel(:, 2); S.w_body = vel(:, 3);
    [S.Uh, S.Vtot] = speeds_from_state(ori, vel);
    S.thrust = thrust(:); S.thrust_unsat = Tunsat(:);
    S.Tff = Tff(:); S.Tp = Tp(:); S.Ti = Ti(:);
    S.delta_e = de_log(:); S.delta_r = dr_log(:);
    S.dr_yaw = dry_log(:); S.dr_p = drp_log(:);
    S.dr_damp = drd_log(:); S.g_ac = gac_log(:);
    S.alpha_hat = ahat_log(:);   % stores shaped alpha_cmd for candidate
    S.alpha_ff_target = aff_tgt_log(:);
    S.alpha_cmd = acmd_log(:);
    S.alpha_cmd_dot = acmd_dot_log(:);
    S.alpha_eff_guid = aeff_log(:);
    S.gamma_act_guid = gact_g_log(:);
    S.gamma_path_guid = gpath_g_log(:);
    S.e_gamma_guid = eg_g_log(:);
    S.z_e_f = zef_log(:); S.z_e_i = zei_log(:); S.zd_e_f = zdf_log(:);
    S.pitch_corr = pcorr_log(:);
    S.corr_P = cP_log(:); S.corr_I = cI_log(:); S.corr_zd = cZd_log(:);
end

function [Uh, Vtot] = speeds_from_state(ori, vel)
    n = size(vel, 1); Uh = zeros(n, 1); Vtot = zeros(n, 1);
    for i = 1:n
        [Uh(i), ~] = inertial_velocity_ned_local(ori(i, :), vel(i, 1), vel(i, 2), vel(i, 3));
        Vtot(i) = norm(vel(i, 1:3));
    end
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

%% ===================== metrics =====================
function M = analyze_route(S, path, win_mode, lim, is_xz)
    t = S.t(:); dt = S.dt;
    phi = S.ori(:, 1); theta = S.ori(:, 2); psi = S.ori(:, 3);
    theta_phys = -theta;
    p = S.rates(:, 1); q = S.rates(:, 2); r = S.rates(:, 3);
    de = S.delta_e(:); dr = S.delta_r(:);
    u = S.u_body(:); v = S.v_body(:); w = S.w_body(:);

    e_psi = wrapToPi(S.psi_ref(:) - psi);
    e_th = wrapToPi(S.theta_ref(:) - theta_phys);

    [VN, VE, VD, Uh] = ned_velocity(phi, theta, psi, u, v, w); %#ok<ASGLU>
    gamma_act = atan2(VD, max(Uh, 1e-9));
    alpha_body = atan2(w, u);
    alpha_neg = -alpha_body;
    resid = wrapToPi(gamma_act - (theta_phys + alpha_body));
    [gamma_ref, cte_perp, s_prog, s_total] = path_gamma_cte(path, S.vp);
    theta_cmd = wrapToPi(gamma_ref - alpha_body);
    e_gamma = wrapToPi(gamma_ref - gamma_act);
    e_theta_req = wrapToPi(theta_cmd - theta_phys);

    pm = compute_path_following_metrics(path, S.vp, S.vel, S.ori, ...
        S.psi_ref, S.theta_ref, dt, t);
    s = pm.s_prog(:);
    W = compute_pitch_window_metrics(t, e_th, s, s_total, 'mode', win_mode);
    mask_ss = W.mask_steady;
    if ~any(mask_ss); mask_ss = (t >= 5.0) & W.mask_before_end; end
    mask_yaw = (t >= 5.0) & W.mask_before_end;
    if ~any(mask_yaw); mask_yaw = t >= 5.0; end
    mask_acq = W.mask_acq;
    if ~any(mask_acq); mask_acq = (t < 5.0) & W.mask_before_end; end
    Udes = 1.5;
    mask_hold = mask_ss & (abs(S.u_ref - Udes) <= 0.08);
    if ~any(mask_hold); mask_hold = mask_ss; end

    % Own-speed empirical equilibrium (not frozen phi_eq)
    own_eq = identify_own_eq(phi, psi, t, mask_ss);
    tilde_own = phi - own_eq.phi_eq_rad;

    e_u = S.u_ref - S.u_ctrl;
    thr_dot = [0; diff(S.thrust)] / dt;
    de_dot = [0; diff(de)] / dt;
    dr_dot = [0; diff(dr)] / dt;

    M = struct();
    M.win_mode = win_mode; M.is_xz = is_xz; M.W = W;
    M.mask_ss = mask_ss; M.mask_hold = mask_hold; M.mask_acq = mask_acq;
    M.pitch = err_stats_deg(e_th, mask_ss);
    M.yaw = err_stats_deg(e_psi, mask_yaw);
    M.own = struct();
    M.own.phi_eq_rad = own_eq.phi_eq_rad;
    M.own.phi_eq_deg = rad2deg(own_eq.phi_eq_rad);
    M.own.estimator = own_eq.estimator;
    M.own.tilde = err_stats_deg(tilde_own, mask_ss);
    M.phi = err_stats_deg(phi, mask_ss);
    M.p = err_stats_deg(p, mask_ss); M.p.rms_dps = M.p.rms_deg;
    M.q = err_stats_deg(q, mask_ss); M.r = err_stats_deg(r, mask_ss);
    M.path = struct('mean_cte', pm.mean_cross_track, 'max_cte', pm.max_cross_track, ...
        'cte_ss_mean', mean_safe(cte_perp, mask_ss), 'cte_ss_rms', rms_safe(cte_perp, mask_ss));
    M.gamma = err_stats_deg(e_gamma, mask_ss);
    M.theta_req = err_stats_deg(e_theta_req, mask_ss);
    M.alpha = err_stats_deg(alpha_body, mask_ss);
    M.resid = err_stats_deg(resid, mask_ss);
    M.alpha_ff = err_stats_deg(S.alpha_hat, mask_ss);
    M.alpha_ff_vs_neg = err_stats_deg(wrapToPi(S.alpha_hat - alpha_neg), mask_ss);
    if isfield(S, 'alpha_ff_target')
        M.alpha_target = err_stats_deg(S.alpha_ff_target, mask_ss);
        M.alpha_cmd = err_stats_deg(S.alpha_cmd, mask_ss);
        M.alpha_cmd_rate = err_stats_deg(S.alpha_cmd_dot, mask_ss);  % deg/s via err_stats
        M.alpha_cmd_rate_rms_dps = rad2deg(rms_safe(S.alpha_cmd_dot, mask_ss));
        M.alpha_cmd_rate_max_dps = rad2deg(max_abs_safe(S.alpha_cmd_dot, true(size(S.alpha_cmd_dot))));
    else
        M.alpha_target = M.alpha_ff;
        M.alpha_cmd = M.alpha_ff;
        M.alpha_cmd_rate_rms_dps = NaN;
        M.alpha_cmd_rate_max_dps = NaN;
    end

    M.settle = struct();
    M.settle.settling_s = W.settling_s;
    M.settle.acq_time_s = W.acq_time_s;
    M.settle.overshoot_deg = W.acq.max_deg;  % acq |e_theta| peak
    M.settle.acq_mae_deg = W.acq.mae_deg;

    M.speed = struct();
    M.speed.frame = 'BODY_u_vs_u_ref_eff';
    M.speed.steady = speed_stats(e_u, mask_hold);
    M.speed.acq = speed_stats(e_u, mask_acq);
    M.speed.u_mean = mean_safe(S.u_ctrl, mask_hold);
    M.speed.u_ref_mean = mean_safe(S.u_ref, mask_hold);

    M.depth = struct();
    M.depth.z_e_f_mae = mean_abs_safe(S.z_e_f, mask_ss);
    M.depth.z_e_i_mean = mean_safe(S.z_e_i, mask_ss);
    M.depth.corr_P_mae_deg = rad2deg(mean_abs_safe(S.corr_P, mask_ss));
    M.depth.corr_I_mae_deg = rad2deg(mean_abs_safe(S.corr_I, mask_ss));
    M.depth.corr_zd_mae_deg = rad2deg(mean_abs_safe(S.corr_zd, mask_ss));
    M.depth.pitch_corr_mae_deg = rad2deg(mean_abs_safe(S.pitch_corr, mask_ss));

    M.thrust = struct();
    M.thrust.steady = thrust_stats(S, thr_dot, mask_hold, lim);
    M.thrust.full = thrust_stats(S, thr_dot, true(size(S.thrust)), lim);
    M.thrust.acq = thrust_stats(S, thr_dot, mask_acq, lim);

    I = S.Ti(:); Idot = [0; diff(I)] / dt;
    M.I = struct();
    M.I.mean = mean_safe(I, mask_hold);
    M.I.rms = rms_safe(I, mask_hold);
    M.I.max_abs = max_abs_safe(I, true(size(I)));
    M.I.rate_rms = rms_safe(Idot, mask_hold);
    M.I.chatter = false; M.I.flip_rate = NaN;
    if any(mask_hold)
        idh = Idot(mask_hold);
        flips = sum(idh(1:end-1) .* idh(2:end) < 0);
        M.I.flip_rate = flips / max(sum(mask_hold) - 1, 1);
        M.I.chatter = (M.I.flip_rate > 0.35) && (M.I.rate_rms > 5.0);
    end
    M.I.windup = (M.I.max_abs > 0.9 * lim.thrust_max) || ...
        (M.thrust.full.sat_pct > 1.0 && abs(M.I.mean) > 20);

    M.act = struct();
    M.act.de_sat_pct = sat_pct(de, mask_ss, 0.98 * lim.de_max);
    M.act.dr_sat_pct = sat_pct(dr, mask_ss, 0.98 * lim.dr_max);
    M.act.de_rate_rms = rms_safe(de_dot, mask_ss);
    M.act.dr_rate_rms = rms_safe(dr_dot, mask_ss);
    M.act.de_rate_acq = rms_safe(de_dot, mask_acq);
    M.act.dr_rate_acq = rms_safe(dr_dot, mask_acq);
    M.act.near_thrust = M.thrust.full.near_pct;
    M.act.sat_thrust = M.thrust.full.sat_pct;

    M.ts = struct('gamma_ref', gamma_ref, 'gamma_act', gamma_act, 'e_gamma', e_gamma, ...
        'theta_cmd', theta_cmd, 'theta_phys', theta_phys, 'e_th', e_th, ...
        'alpha_body', alpha_body, 'alpha_neg', alpha_neg, 'resid', resid, ...
        'cte_perp', cte_perp, 's_prog', s_prog, 's_total', s_total, ...
        'tilde_own', tilde_own);
end

function eq = identify_own_eq(phi, psi, t, mask) %#ok<INUSD>
    phi_m = phi(mask);
    if isempty(phi_m)
        eq = struct('phi_eq_rad', 0, 'estimator', 'empty_fallback');
        return;
    end
    psi_m = unwrap(psi(mask));
    mean_all = mean(phi_m);
    turn_idx = floor((psi_m - psi_m(1)) / (2 * pi)) + 1;
    n_turns = max(turn_idx);
    turn_mean = nan(n_turns, 1);
    for k = 1:n_turns
        ik = turn_idx == k;
        if nnz(ik) >= 8
            turn_mean(k) = mean(phi_m(ik));
        end
    end
    valid = isfinite(turn_mean);
    if any(valid)
        robust = median(turn_mean(valid));
        turn_spread = max(turn_mean(valid)) - min(turn_mean(valid));
        turn_stable = turn_spread <= deg2rad(0.35);
    else
        robust = mean_all;
        turn_stable = false;
    end
    n = numel(phi_m);
    mean1 = mean(phi_m(1:floor(n / 2)));
    mean2 = mean(phi_m(floor(n / 2) + 1:end));
    half_stable = abs(mean2 - mean1) <= deg2rad(0.25);
    phi_eq = mean_all;
    estimator = 'steady_mean';
    if ~half_stable && turn_stable
        phi_eq = robust;
        estimator = 'turn_robust';
    end
    eq = struct('phi_eq_rad', phi_eq, 'estimator', estimator);
end

function st = thrust_stats(S, tdot, mask, lim)
    st = struct('mean', NaN, 'rms', NaN, 'rate_rms', NaN, 'near_pct', NaN, ...
        'sat_pct', NaN, 'Tff_mean', NaN, 'Tp_mean', NaN, 'Ti_mean', NaN, 'n', 0);
    if ~any(mask); return; end
    v = S.thrust(mask); vd = tdot(mask);
    st.n = numel(v);
    st.mean = mean(v); st.rms = rms_local(v); st.rate_rms = rms_local(vd);
    st.near_pct = 100 * mean(abs(v) >= 0.80 * lim.thrust_max);
    st.sat_pct = 100 * mean((v >= 0.98 * lim.thrust_max) | ...
        (v <= lim.thrust_min + 0.02 * abs(lim.thrust_min)));
    st.Tff_mean = mean(S.Tff(mask));
    st.Tp_mean = mean(S.Tp(mask));
    st.Ti_mean = mean(S.Ti(mask));
end

function st = speed_stats(e, mask)
    st = struct('signed_mean', NaN, 'mae', NaN, 'rms', NaN, 'p95', NaN, 'max', NaN, 'n', 0);
    if ~any(mask); return; end
    v = e(mask); st.n = numel(v);
    st.signed_mean = mean(v); st.mae = mean(abs(v)); st.rms = rms_local(v);
    st.p95 = prctile_local(abs(v), 95); st.max = max(abs(v));
end

%% ===================== gates =====================
function [G, verdict, next_opt, next_detail] = score_all(Res, law, Sched) %#ok<INUSD>
    names = {'X', 'XZ', 'H'};
    labels = {'X', 'XZ', 'R10'};
    G = struct();
    G.u_ok = true; G.gamma_ok = true; G.cte_ok = true;
    G.yaw_roll_ok = true; G.act_ok = true; G.sat_chatter_ok = true;
    G.settle_ok = true; G.vs_aff_ok = true;
    G.rows = struct();

    for i = 1:3
        nm = names{i}; lbl = labels{i};
        P = Res.P.(nm).M; U = Res.U.(nm).M;
        A04 = Res.A04.(nm).M; AFF = Res.AFF.(nm).M; T = Res.RL.(nm).M;
        row = struct();
        row.label = lbl;
        % vectors: P / A04 / AFF / RL  (U kept for gamma/CTE baseline)
        row.u_mae = [P.speed.steady.mae, A04.speed.steady.mae, AFF.speed.steady.mae, T.speed.steady.mae];
        row.u_p95 = [P.speed.steady.p95, A04.speed.steady.p95, AFF.speed.steady.p95, T.speed.steady.p95];
        row.u_mae_U = U.speed.steady.mae;
        row.g_mae = [P.gamma.mae_deg, A04.gamma.mae_deg, AFF.gamma.mae_deg, T.gamma.mae_deg];
        row.g_mae_U = U.gamma.mae_deg;
        row.cte   = [P.path.cte_ss_mean, A04.path.cte_ss_mean, AFF.path.cte_ss_mean, T.path.cte_ss_mean];
        row.cte_U = U.path.cte_ss_mean;
        row.yaw   = [P.yaw.mae_deg, A04.yaw.mae_deg, AFF.yaw.mae_deg, T.yaw.mae_deg];
        row.own_t = [P.own.tilde.rms_deg, A04.own.tilde.rms_deg, AFF.own.tilde.rms_deg, T.own.tilde.rms_deg];
        row.own_eq = [P.own.phi_eq_deg, A04.own.phi_eq_deg, AFF.own.phi_eq_deg, T.own.phi_eq_deg];
        row.p_rms = [P.p.rms_dps, A04.p.rms_dps, AFF.p.rms_dps, T.p.rms_dps];
        row.q_rms = [P.q.rms_deg, A04.q.rms_deg, AFF.q.rms_deg, T.q.rms_deg];
        row.r_rms = [P.r.rms_deg, A04.r.rms_deg, AFF.r.rms_deg, T.r.rms_deg];
        row.de_sat = [P.act.de_sat_pct, A04.act.de_sat_pct, AFF.act.de_sat_pct, T.act.de_sat_pct];
        row.dr_sat = [P.act.dr_sat_pct, A04.act.dr_sat_pct, AFF.act.dr_sat_pct, T.act.dr_sat_pct];
        row.thr_sat = [P.act.sat_thrust, A04.act.sat_thrust, AFF.act.sat_thrust, T.act.sat_thrust];
        row.de_rate = [P.act.de_rate_rms, A04.act.de_rate_rms, AFF.act.de_rate_rms, T.act.de_rate_rms];
        row.dr_rate = [P.act.dr_rate_rms, A04.act.dr_rate_rms, AFF.act.dr_rate_rms, T.act.dr_rate_rms];
        row.de_rate_acq = [P.act.de_rate_acq, A04.act.de_rate_acq, AFF.act.de_rate_acq, T.act.de_rate_acq];
        row.dr_rate_acq = [P.act.dr_rate_acq, A04.act.dr_rate_acq, AFF.act.dr_rate_acq, T.act.dr_rate_acq];
        row.settle = [P.settle.settling_s, A04.settle.settling_s, AFF.settle.settling_s, T.settle.settling_s];
        row.os = [P.settle.overshoot_deg, A04.settle.overshoot_deg, AFF.settle.overshoot_deg, T.settle.overshoot_deg];
        row.aff_mae = T.alpha_ff.mae_deg;
        row.aff_vs_neg = T.alpha_ff_vs_neg.mae_deg;
        row.acmd_rate_max = T.alpha_cmd_rate_max_dps;

        row.u_gate = (T.speed.steady.mae <= 0.07) && (T.speed.steady.p95 <= 0.10);
        row.g_imp = improve_pct(U.gamma.mae_deg, T.gamma.mae_deg);
        row.cte_imp = improve_pct(U.path.cte_ss_mean, T.path.cte_ss_mean);
        row.g_gate = (T.gamma.mae_deg <= 0.90 * U.gamma.mae_deg + 1e-12);
        row.cte_gate = (T.path.cte_ss_mean <= 0.90 * U.path.cte_ss_mean + 1e-12);

        % Own-eq yaw/roll <=2% vs production
        row.yaw_ok = within_tol(T.yaw.mae_deg, P.yaw.mae_deg, 0.02, 1e-3);
        row.own_ok = within_tol(T.own.tilde.rms_deg, P.own.tilde.rms_deg, 0.02, 1e-3);
        row.p_ok = within_tol(T.p.rms_dps, P.p.rms_dps, 0.02, 1e-3);
        row.yaw_roll_ok = row.yaw_ok && row.own_ok && row.p_ok;

        % OS/settle improve >=10% vs unshaped AFF
        row.set_imp_aff = improve_pct(AFF.settle.settling_s, T.settle.settling_s);
        row.os_imp_aff = improve_pct(AFF.settle.overshoot_deg, T.settle.overshoot_deg);
        row.set_vs_aff = (T.settle.settling_s <= 0.90 * AFF.settle.settling_s + 1e-12);
        row.os_vs_aff = (T.settle.overshoot_deg <= 0.90 * AFF.settle.overshoot_deg + 1e-12);
        row.vs_aff_ok = row.set_vs_aff && row.os_vs_aff;

        % Do not worsen >2% vs production (settling/OS); rates no regress >2% vs P
        row.set_vs_P = within_tol(T.settle.settling_s, P.settle.settling_s, 0.02, 1e-3);
        row.os_vs_P = within_tol(T.settle.overshoot_deg, P.settle.overshoot_deg, 0.02, 1e-3);
        row.de_vs_P = within_tol(T.act.de_rate_rms, P.act.de_rate_rms, 0.02, 1e-6);
        row.dr_vs_P = within_tol(T.act.dr_rate_rms, P.act.dr_rate_rms, 0.02, 1e-6);
        row.de_acq_vs_P = within_tol(T.act.de_rate_acq, P.act.de_rate_acq, 0.02, 1e-6);
        row.dr_acq_vs_P = within_tol(T.act.dr_rate_acq, P.act.dr_rate_acq, 0.02, 1e-6);
        row.de_sat_ok = within_tol(T.act.de_sat_pct, P.act.de_sat_pct, 0.02, 0.05);
        row.dr_sat_ok = within_tol(T.act.dr_sat_pct, P.act.dr_sat_pct, 0.02, 0.05);
        row.thr_sat_ok = within_tol(T.act.sat_thrust, P.act.sat_thrust, 0.02, 0.05);
        row.settle_ok = row.set_vs_P && row.os_vs_P;
        row.act_ok = row.de_vs_P && row.dr_vs_P && row.de_acq_vs_P && row.dr_acq_vs_P && ...
            row.de_sat_ok && row.dr_sat_ok && row.thr_sat_ok;

        row.sat_chatter_ok = (T.act.sat_thrust <= 1.0) && ~T.I.chatter && ~T.I.windup && ...
            (T.act.de_sat_pct <= max(1.0, P.act.de_sat_pct + 0.05)) && ...
            (T.act.dr_sat_pct <= max(1.0, P.act.dr_sat_pct + 0.05));

        G.rows.(nm) = row;
        G.u_ok = G.u_ok && row.u_gate;
        G.gamma_ok = G.gamma_ok && row.g_gate;
        G.cte_ok = G.cte_ok && row.cte_gate;
        G.yaw_roll_ok = G.yaw_roll_ok && row.yaw_roll_ok;
        G.act_ok = G.act_ok && row.act_ok;
        G.settle_ok = G.settle_ok && row.settle_ok;
        G.vs_aff_ok = G.vs_aff_ok && row.vs_aff_ok;
        G.sat_chatter_ok = G.sat_chatter_ok && row.sat_chatter_ok;
    end

    G.pass = G.u_ok && G.gamma_ok && G.cte_ok && G.yaw_roll_ok && ...
        G.act_ok && G.settle_ok && G.vs_aff_ok && G.sat_chatter_ok;

    if G.pass
        verdict = 'PASS';
        next_opt = 'two_repeat_production_integration_rate_limited_trim_alpha_ff';
        next_detail = ['TRIM_ALPHA_FF_RATE_LIMIT PASS. alpha_cmd rate-limit 2deg/s clears ', ...
            'steady + acquisition gates vs AFF/P. Recommend SEPARATE two-repeat production integration.'];
    else
        verdict = 'FAIL';
        reasons = {};
        if ~G.u_ok; reasons{end+1} = 'u MAE/p95'; end %#ok<*AGROW>
        if ~G.gamma_ok; reasons{end+1} = 'gamma MAE <10% improve vs U'; end
        if ~G.cte_ok; reasons{end+1} = 'CTE <10% improve vs U'; end
        if ~G.yaw_roll_ok; reasons{end+1} = 'own-eq yaw/roll >2% vs prod'; end
        if ~G.act_ok; reasons{end+1} = 'elevator/rudder rates regress >2% vs prod'; end
        if ~G.settle_ok; reasons{end+1} = 'settle/OS worsen >2% vs prod'; end
        if ~G.vs_aff_ok; reasons{end+1} = 'settle/OS not improve >=10% vs unshaped AFF'; end
        if ~G.sat_chatter_ok; reasons{end+1} = 'sat/chatter'; end
        if ~G.vs_aff_ok && G.u_ok && G.gamma_ok && G.cte_ok
            next_opt = 'alpha_cmd_slew_with_soft_start_or_1deg_s';
        elseif ~G.settle_ok || ~G.act_ok
            next_opt = 'alpha_cmd_slew_with_soft_start_or_1deg_s';
        elseif ~G.yaw_roll_ok
            next_opt = 'helix_roll_v_aware_alpha_ff';
        else
            next_opt = 'retune_alpha_ff_c_gamma_or_depth_P';
        end
        next_detail = ['FAIL leave production unchanged. Fail: ', strjoin(reasons, ', '), ...
            '. Next: ', next_opt, '.'];
    end
end

function pct = improve_pct(base, cand)
    if ~(isfinite(base) && isfinite(cand)) || abs(base) < 1e-12
        pct = NaN; return;
    end
    pct = 100 * (base - cand) / abs(base);
end

function ok = within_tol(a, b, rel, abs_eps)
    if ~(isfinite(a) && isfinite(b)); ok = false; return; end
    if a <= b + max(abs_eps, rel * max(abs(b), abs_eps)); ok = true; return; end
    ok = false;
end

function ok = improves_or_eq(cand, base, abs_eps)
    % cand improves (lower better) or equals base; NaN base => pass if cand finite
    if ~isfinite(base)
        ok = isfinite(cand); return;
    end
    if ~isfinite(cand); ok = false; return; end
    ok = cand <= base + abs_eps;
end

%% ===================== kinematics helpers =====================
function [VN, VE, VD, Uh] = ned_velocity(phi, theta, psi, u, v, w)
    n = numel(u);
    VN = zeros(n, 1); VE = zeros(n, 1); VD = zeros(n, 1); Uh = zeros(n, 1);
    for i = 1:n
        R = Rzyx(phi(i), theta(i), psi(i));
        V = R * [u(i); v(i); w(i)];
        VN(i) = V(1); VE(i) = V(2); VD(i) = V(3);
        Uh(i) = hypot(V(1), V(2));
    end
end

function R = Rzyx(phi, theta, psi)
    R = [cos(psi)*cos(theta), ...
         cos(psi)*sin(theta)*sin(phi) - sin(psi)*cos(phi), ...
         cos(psi)*sin(theta)*cos(phi) + sin(psi)*sin(phi);
         sin(psi)*cos(theta), ...
         sin(psi)*sin(theta)*sin(phi) + cos(psi)*cos(phi), ...
         sin(psi)*sin(theta)*cos(phi) - cos(psi)*sin(phi);
         -sin(theta), cos(theta)*sin(phi), cos(theta)*cos(phi)];
end

function [gamma_ref, cte_perp, s_prog, s_total] = path_gamma_cte(path, vp)
    n = size(vp, 1);
    [s_nodes, s_total] = path_arclength_local(path);
    is_closed = norm(path(1,:) - path(end,:)) < 0.25;
    gamma_ref = zeros(n, 1); cte_perp = zeros(n, 1); s_prog = zeros(n, 1);
    s = 0; L = 1.25;
    for i = 1:n
        p = vp(i, :);
        if i == 1
            [s_near, ~] = project_on_path_local(p, path, s_nodes, 0, s_total, is_closed);
            s = s_near;
            if is_closed; s = mod(s, s_total); end
        else
            if is_closed
                win = max(3.0, 2.5*L);
                s_lo = mod(s - 0.15, s_total);
                [s_near, ~] = project_wrapped_local(p, path, s_nodes, s_lo, win, s_total);
                ds = wrap_arc_local(s_near - s, s_total);
                if ds >= -0.25
                    s = mod(s + max(ds, -0.05), s_total);
                end
            else
                s_lo = max(0, s - 0.15);
                s_hi = min(s_total, s + max(3.0, 2.5*L));
                [s_near, ~] = project_on_path_local(p, path, s_nodes, s_lo, s_hi, is_closed);
                if s_near >= s_total - 1e-6
                    s = s_total;
                else
                    s = max(s, s_near - 0.05);
                    s = min(s, s_total);
                end
            end
        end
        [p_d, t_hat] = sample_path_local(path, s_nodes, s, is_closed);
        th = t_hat(:);
        gamma_ref(i) = atan2(th(3), max(hypot(th(1), th(2)), 1e-9));
        dp = (p(:) - p_d(:));
        e_perp = (eye(3) - (th * th')) * dp;
        cte_perp(i) = norm(e_perp);
        s_prog(i) = s;
    end
end

function [s_nodes, s_total] = path_arclength_local(path)
    d = vecnorm(diff(path), 2, 2);
    s_nodes = [0; cumsum(d)];
    s_total = s_nodes(end);
    if s_total < 1e-9; s_total = 1e-9; end
end

function [p, t_hat] = sample_path_local(path, s_nodes, s, is_closed)
    s_total = s_nodes(end);
    if is_closed; s = mod(s, s_total); else; s = min(max(s, 0), s_total); end
    idx = find(s_nodes <= s, 1, 'last');
    if isempty(idx); idx = 1; end
    if idx >= numel(s_nodes)
        p = path(end, :); t_hat = path(end, :) - path(end-1, :);
    else
        ds = s_nodes(idx+1) - s_nodes(idx);
        if ds < 1e-12; a = 0; else; a = (s - s_nodes(idx)) / ds; end
        p = path(idx, :) + a * (path(idx+1, :) - path(idx, :));
        t_hat = path(idx+1, :) - path(idx, :);
    end
    if norm(t_hat) < 1e-9; t_hat = [1, 0, 0]; else; t_hat = t_hat / norm(t_hat); end
end

function [s_best, d_best] = project_on_path_local(p, path, s_nodes, s_lo, s_hi, is_closed) %#ok<INUSD>
    n = size(path, 1);
    d_best = inf; s_best = s_lo;
    i0 = max(1, find(s_nodes <= s_lo, 1, 'last'));
    i1 = min(n-1, find(s_nodes >= s_hi, 1, 'first'));
    if isempty(i0); i0 = 1; end
    if isempty(i1); i1 = n-1; end
    i0 = min(i0, n-1); i1 = max(i1, i0);
    for i = i0:i1
        a = path(i,:); b = path(i+1,:);
        ab = b - a; lab2 = sum(ab.^2);
        if lab2 < 1e-12; continue; end
        tt = max(0, min(1, dot(p - a, ab) / lab2));
        proj = a + tt * ab;
        d = norm(p - proj);
        ss = s_nodes(i) + tt * (s_nodes(i+1) - s_nodes(i));
        if ss < s_lo - 1e-9 || ss > s_hi + 1e-9; continue; end
        if d < d_best; d_best = d; s_best = ss; end
    end
end

function [s_best, d_best] = project_wrapped_local(p, path, s_nodes, s_lo, win, s_total)
    s_hi = s_lo + win;
    if s_hi <= s_total
        [s_best, d_best] = project_on_path_local(p, path, s_nodes, s_lo, s_hi, true);
    else
        [s1, d1] = project_on_path_local(p, path, s_nodes, s_lo, s_total, true);
        [s2, d2] = project_on_path_local(p, path, s_nodes, 0, mod(s_hi, s_total), true);
        if d1 <= d2; s_best = s1; d_best = d1; else; s_best = s2; d_best = d2; end
    end
end

function d = wrap_arc_local(ds, s_total)
    d = mod(ds + 0.5*s_total, s_total) - 0.5*s_total;
end

%% ===================== artifacts =====================
function write_png(png_path, Res, lim, task_id, verdict, law, Sched)
    fig = figure('Visible', 'off', 'Color', 'w', 'Position', [20 20 1700 1200]);
    try
        names = {'X', 'XZ', 'H'}; titles = {'X', 'XZ', 'R10'};
        for i = 1:3
            nm = names{i};
            P = Res.P.(nm); A04 = Res.A04.(nm); AFF = Res.AFF.(nm); T = Res.RL.(nm);
            Sp = P.S; Sa = A04.S; Sf = AFF.S; St = T.S;
            Mp = P.M; Ma = A04.M; Mf = AFF.M; Mt = T.M;
            subplot(4, 3, i);
            plot(St.t, rad2deg(Mt.ts.gamma_ref), 'k--', 'LineWidth', 1); hold on;
            plot(Sp.t, rad2deg(Mp.ts.gamma_act), 'b:');
            plot(Sa.t, rad2deg(Ma.ts.gamma_act), 'g');
            plot(Sf.t, rad2deg(Mf.ts.gamma_act), 'm');
            plot(St.t, rad2deg(Mt.ts.gamma_act), 'r', 'LineWidth', 1.1);
            grid on; ylabel('\gamma [deg]'); title(sprintf('%s | %s', titles{i}, verdict));
            if i == 1; legend('\gamma_{ref}','P','A04','AFF','RL','Location','best'); end
            subplot(4, 3, 3 + i);
            plot(St.t, rad2deg(St.theta_ref), 'k--'); hold on;
            plot(St.t, rad2deg(Mt.ts.theta_phys), 'r');
            if isfield(St, 'alpha_ff_target')
                plot(St.t, rad2deg(St.alpha_ff_target), 'c:');
                plot(St.t, rad2deg(St.alpha_cmd), 'b', 'LineWidth', 1.1);
            else
                plot(St.t, rad2deg(St.alpha_hat), 'b', 'LineWidth', 1.1);
            end
            plot(Sf.t, rad2deg(Sf.alpha_hat), 'm:');
            grid on; ylabel('\theta/\alpha [deg]');
            if i == 1; legend('\theta_{ref}','\theta_{phys}','\alpha_{tgt}','\alpha_{cmd}','\alpha_{AFF}','Location','best'); end
            subplot(4, 3, 6 + i);
            plot(Sp.t, Sp.u_body, 'b:'); hold on;
            plot(Sa.t, Sa.u_body, 'g');
            plot(Sf.t, Sf.u_body, 'm');
            plot(St.t, St.u_body, 'r', 'LineWidth', 1.1);
            plot(St.t, St.u_ref, 'k--');
            yyaxis right; plot(St.t, St.thrust, 'c:'); ylabel('T [N]');
            yyaxis left; ylabel('u [m/s]'); grid on;
            if i == 1; legend('u_P','u_A04','u_AFF','u_RL','u_{ref}','Location','best'); end
            subplot(4, 3, 9 + i);
            plot(Sp.t, Mp.ts.cte_perp, 'b:'); hold on;
            plot(Sa.t, Ma.ts.cte_perp, 'g');
            plot(Sf.t, Mf.ts.cte_perp, 'm');
            plot(St.t, Mt.ts.cte_perp, 'r');
            plot(St.t, rad2deg(St.rates(:,1)), 'c:');
            plot(St.t, rad2deg(St.delta_e), 'k');
            yline(rad2deg(lim.de_max), 'k--');
            grid on; ylabel('CTE[m]/p/de'); xlabel('t [s]');
            if i == 1; legend('CTE_P','CTE_A04','CTE_AFF','CTE_RL','p','de','Location','best'); end
        end
        sgtitle(sprintf('%s | %s | \\alpha_{cmd} rate\\leq2deg/s | c0=%.4g c_\\gamma=%.4g', ...
            task_id, verdict, Sched.c0, Sched.c_gamma), 'Interpreter', 'tex');
        exportgraphics(fig, png_path, 'Resolution', 130);
    catch ME
        fprintf('PNG warn: %s\n', ME.message);
    end
    close(fig);
end

function write_md(md_path, task_id, verdict, law, Sched, Res, G, next_opt, next_detail, ...
        seed, sched_path, aff_path, aff_guid, cand_path, md_out, mat_out, png_out)
    fid = fopen(md_path, 'w');
    assert(fid > 0);
    fprintf(fid, '# %s — Rate-limit shaping of trim alpha_ff (no LPF)\n\n', task_id);
    fprintf(fid, '**Overall verdict: %s**\n\n', verdict);
    fprintf(fid, '## Provenance\n\n');
    fprintf(fid, '- Read-only: `%s`, `%s`, `%s`\n', aff_path, sched_path, aff_guid);
    fprintf(fid, '- Isolated helper: `%s` (production guidance untouched)\n', cand_path);
    fprintf(fid, '- Driver: `run_trim_alpha_ff_rate_limit.m` (one invocation)\n');
    fprintf(fid, '- Artifacts: `%s`, `%s`, `%s`\n', md_out, mat_out, png_out);
    fprintf(fid, '- Seed: %d | P/A04/AFF loaded from TRIM_ALPHA_FF_BENCHMARK; RL simulated\n\n', seed);

    fprintf(fid, '## Exact shaping equation\n\n');
    fprintf(fid, '```\n');
    fprintf(fid, 'alpha_ff  = c0/max(u_ref,u_min)^2 + c_gamma*gamma_path; clamp +/-8deg\n');
    fprintf(fid, 'alpha_cmd(0) = 0\n');
    fprintf(fid, 'alpha_cmd(k) = alpha_cmd(k-1) + sat(alpha_ff-alpha_cmd(k-1), +/- rate_max*dt)\n');
    fprintf(fid, '  with |d alpha_cmd/dt| <= 2 deg/s  (=1/3 of pitch_ref_rate_max=6deg/s)\n');
    fprintf(fid, 'pitch_raw = gamma_path + pitch_corr + alpha_cmd   (NO LPF)\n');
    fprintf(fid, 'c0=%.12g  c_gamma=%.12g  u_min=%.1f  rate_max=2deg/s\n', ...
        Sched.c0, Sched.c_gamma, Sched.u_min);
    fprintf(fid, 'UNCHANGED: schedule, Kz=.040, Ki_z=0, K_gamma=0, depth filters/clamps,\n');
    fprintf(fid, '           speed PI+FF, all attitude/yaw/roll gains and actuator limits\n');
    fprintf(fid, 'Speed: kD=%.10f Kp=%.4g Ki=%.8f Kaw=%.8f\n', law.kD, law.Kp, law.Ki, law.Kaw);
    fprintf(fid, 'Roll gate: tilde_own = phi - phi_eq_own (per-speed empirical)\n');
    fprintf(fid, '```\n\n');

    fprintf(fid, '## Before / after (P / A04 / AFF / RL)\n\n');
    fprintf(fid, '| Route | uMAE P/A04/AFF/RL | uP95 RL | γMAE° P/A04/AFF/RL | γΔ%% U→RL | CTE P/A04/AFF/RL | CTEΔ%% | yaw° P→RL | ownT P→RL | pRMS P→RL |\n');
    fprintf(fid, '|-------|-----------------:|-------:|------------------:|---------:|-----------------:|------:|----------:|----------:|----------:|\n');
    names = {'X','XZ','H'};
    for i = 1:3
        r = G.rows.(names{i});
        fprintf(fid, '| %s | %.4f/%.4f/%.4f/%.4f | %.4f | %.3f/%.3f/%.3f/%.3f | %+.1f | %.4f/%.4f/%.4f/%.4f | %+.1f | %.4f→%.4f | %.4f→%.4f | %.4f→%.4f |\n', ...
            r.label, r.u_mae(1), r.u_mae(2), r.u_mae(3), r.u_mae(4), r.u_p95(4), ...
            r.g_mae(1), r.g_mae(2), r.g_mae(3), r.g_mae(4), r.g_imp, ...
            r.cte(1), r.cte(2), r.cte(3), r.cte(4), r.cte_imp, ...
            r.yaw(1), r.yaw(4), r.own_t(1), r.own_t(4), r.p_rms(1), r.p_rms(4));
    end

    fprintf(fid, '\n## Acquisition / rates (P / A04 / AFF / RL)\n\n');
    fprintf(fid, '| Route | settle[s] P/A04/AFF/RL | OS° P/A04/AFF/RL | setΔ%% AFF→RL | OSΔ%% AFF→RL | deRate P/AFF/RL | drRate P/AFF/RL |\n');
    fprintf(fid, '|-------|-----------------------:|-----------------:|-------------:|------------:|----------------:|----------------:|\n');
    for i = 1:3
        r = G.rows.(names{i});
        fprintf(fid, '| %s | %.3f/%.3f/%.3f/%.3f | %.3f/%.3f/%.3f/%.3f | %+.1f | %+.1f | %.4f/%.4f/%.4f | %.4f/%.4f/%.4f |\n', ...
            r.label, r.settle(1), r.settle(2), r.settle(3), r.settle(4), ...
            r.os(1), r.os(2), r.os(3), r.os(4), r.set_imp_aff, r.os_imp_aff, ...
            r.de_rate(1), r.de_rate(3), r.de_rate(4), r.dr_rate(1), r.dr_rate(3), r.dr_rate(4));
    end

    fprintf(fid, '\n## Own-eq roll / actuators / chatter / alpha rate\n\n');
    fprintf(fid, '| Route | phi_eq° P/A04/RL | ownT RMS P→RL | deSat%% P→RL | thrSat%% RL | I chatter | αcmd rate max°/s |\n');
    fprintf(fid, '|-------|-----------------:|--------------:|------------:|-----------:|----------:|-----------------:|\n');
    for i = 1:3
        nm = names{i}; r = G.rows.(nm); T = Res.RL.(nm).M;
        fprintf(fid, '| %s | %.3f/%.3f/%.3f | %.4f→%.4f | %.2f→%.2f | %.2f | %s | %.3f |\n', ...
            r.label, r.own_eq(1), r.own_eq(2), r.own_eq(4), r.own_t(1), r.own_t(4), ...
            r.de_sat(1), r.de_sat(4), r.thr_sat(4), yn(~T.I.chatter), r.acmd_rate_max);
    end

    fprintf(fid, '\n## Gate table (candidate = rate-limited AFF)\n\n');
    fprintf(fid, '| Gate | Result | Detail |\n');
    fprintf(fid, '|------|:------:|--------|\n');
    fprintf(fid, '| Comp u MAE≤0.07 p95≤0.10 | %s | X=%s XZ=%s H=%s |\n', ...
        yn(G.u_ok), yn(G.rows.X.u_gate), yn(G.rows.XZ.u_gate), yn(G.rows.H.u_gate));
    fprintf(fid, '| γ MAE improve ≥10%% vs U | %s | X=%+.1f%% XZ=%+.1f%% H=%+.1f%% |\n', ...
        yn(G.gamma_ok), G.rows.X.g_imp, G.rows.XZ.g_imp, G.rows.H.g_imp);
    fprintf(fid, '| CTE improve ≥10%% vs U | %s | X=%+.1f%% XZ=%+.1f%% H=%+.1f%% |\n', ...
        yn(G.cte_ok), G.rows.X.cte_imp, G.rows.XZ.cte_imp, G.rows.H.cte_imp);
    fprintf(fid, '| Settle/OS improve ≥10%% vs unshaped AFF | %s | set X/XZ/H=%+.1f/%+.1f/%+.1f OS=%+.1f/%+.1f/%+.1f |\n', ...
        yn(G.vs_aff_ok), G.rows.X.set_imp_aff, G.rows.XZ.set_imp_aff, G.rows.H.set_imp_aff, ...
        G.rows.X.os_imp_aff, G.rows.XZ.os_imp_aff, G.rows.H.os_imp_aff);
    fprintf(fid, '| Settle/OS regress ≤2%% vs production | %s | |\n', yn(G.settle_ok));
    fprintf(fid, '| Elevator/rudder rates regress ≤2%% vs production | %s | |\n', yn(G.act_ok));
    fprintf(fid, '| Own-eq yaw/roll ≤2%% vs production | %s | |\n', yn(G.yaw_roll_ok));
    fprintf(fid, '| Sat≤1%% / no chatter | %s | |\n', yn(G.sat_chatter_ok));

    fprintf(fid, '\n## Decision\n\n');
    fprintf(fid, '- Verdict: **%s**\n', verdict);
    fprintf(fid, '- Next: `%s`\n', next_opt);
    fprintf(fid, '- Detail: %s\n', next_detail);
    fprintf(fid, '- Production: untouched\n\n');

    fprintf(fid, '## Feedback\n\n');
    fprintf(fid, '- PASS/FAIL: **%s**\n', verdict);
    fprintf(fid, '- Shaping: `α_cmd(0)=0; |dα_cmd/dt|≤2°/s; pitch_raw=γ_path+pitch_corr+α_cmd`\n');
    fprintf(fid, '- γMAE° P/A04/AFF/RL: X %.3f/%.3f/%.3f/%.3f | XZ %.3f/%.3f/%.3f/%.3f | R10 %.3f/%.3f/%.3f/%.3f\n', ...
        G.rows.X.g_mae(1), G.rows.X.g_mae(2), G.rows.X.g_mae(3), G.rows.X.g_mae(4), ...
        G.rows.XZ.g_mae(1), G.rows.XZ.g_mae(2), G.rows.XZ.g_mae(3), G.rows.XZ.g_mae(4), ...
        G.rows.H.g_mae(1), G.rows.H.g_mae(2), G.rows.H.g_mae(3), G.rows.H.g_mae(4));
    fprintf(fid, '- Files: `%s` `%s` `%s`\n', md_out, mat_out, png_out);
    fprintf(fid, '- Next: `%s`\n', next_opt);
    fclose(fid);
end

function append_ss_audit(out_dir, task_id, verdict, law, Sched, Res, G, next_opt, next_detail, ...
        md_path, mat_path, png_path) %#ok<INUSD>
    audit_path = fullfile(out_dir, 'STATE_SPACE_MODEL_AUDIT.md');
    fid = fopen(audit_path, 'a');
    assert(fid > 0);
    fprintf(fid, '\n\n---\n\n');
    fprintf(fid, '## %s — %s\n\n', task_id, datestr(now, 'yyyy-mm-dd HH:MM:SS'));
    fprintf(fid, '### Provenance\n\n');
    fprintf(fid, '- Read-only: `TRIM_ALPHA_FF_BENCHMARK.mat`, `TRIM_ALPHA_SCHEDULE_ID.mat`, `guidance_law_trim_alpha_ff.m`\n');
    fprintf(fid, '- Isolated helper: `guidance_law_trim_alpha_ff_rate_limit.m` (production untouched)\n');
    fprintf(fid, '- Driver: `run_trim_alpha_ff_rate_limit.m` (one invocation)\n');
    fprintf(fid, '- Artifacts: `%s`, `%s`, `%s`\n\n', md_path, mat_path, png_path);

    fprintf(fid, '### Shaping equation\n\n');
    fprintf(fid, '```\n');
    fprintf(fid, 'alpha_ff=c0/max(u_ref,.9)^2+c_gamma*gamma_path; clamp +/-8deg\n');
    fprintf(fid, 'alpha_cmd(0)=0; |d alpha_cmd/dt|<=2deg/s; pitch_raw=gamma_path+pitch_corr+alpha_cmd (no LPF)\n');
    fprintf(fid, 'c0=%.12g c_gamma=%.12g | Kz=.04 Ki=0 K_gamma=0 | speed PI+FF kD=%.10f\n', ...
        Sched.c0, Sched.c_gamma, law.kD);
    fprintf(fid, 'Roll: own-eq tilde (not frozen phi_eq)\n');
    fprintf(fid, '```\n\n');

    fprintf(fid, '### Before/after (P / A04 / AFF / RL)\n\n');
    fprintf(fid, '| Route | uMAE | γMAE° | CTE | settle AFF→RL | OS AFF→RL | γΔ%% U→RL | CTEΔ%% |\n');
    fprintf(fid, '|-------|-----:|------:|----:|--------------:|----------:|---------:|------:|\n');
    names = {'X','XZ','H'};
    for i = 1:3
        r = G.rows.(names{i});
        fprintf(fid, '| %s | %.4f/%.4f/%.4f/%.4f | %.3f/%.3f/%.3f/%.3f | %.4f/%.4f/%.4f/%.4f | %.3f→%.3f (%+.1f%%) | %.3f→%.3f (%+.1f%%) | %+.1f | %+.1f |\n', ...
            r.label, r.u_mae(1), r.u_mae(2), r.u_mae(3), r.u_mae(4), ...
            r.g_mae(1), r.g_mae(2), r.g_mae(3), r.g_mae(4), ...
            r.cte(1), r.cte(2), r.cte(3), r.cte(4), ...
            r.settle(3), r.settle(4), r.set_imp_aff, r.os(3), r.os(4), r.os_imp_aff, ...
            r.g_imp, r.cte_imp);
    end

    fprintf(fid, '\n### Verdict / next\n\n');
    fprintf(fid, '- Verdict: **%s**\n', verdict);
    fprintf(fid, '- Gates u/γ/CTE/own-yr/act/settle/vsAFF/sat: %s/%s/%s/%s/%s/%s/%s/%s\n', ...
        yn(G.u_ok), yn(G.gamma_ok), yn(G.cte_ok), yn(G.yaw_roll_ok), ...
        yn(G.act_ok), yn(G.settle_ok), yn(G.vs_aff_ok), yn(G.sat_chatter_ok));
    fprintf(fid, '- Next: `%s` — %s\n', next_opt, next_detail);
    fprintf(fid, '- Production: untouched\n');

    fprintf(fid, '\n### Next\n\n');
    fprintf(fid, '- %s\n', next_opt);
    fclose(fid);
end

function print_feedback(verdict, law, Sched, Res, G, next_opt, next_detail, md, mat, png) %#ok<INUSD>
    fprintf('\n========== FEEDBACK ==========\n');
    fprintf('PASS/FAIL: %s\n', verdict);
    fprintf('Shaping: alpha_cmd(0)=0; |d alpha_cmd/dt|<=2deg/s; pitch_raw=gamma+corr+alpha_cmd | schedule c0=%.6g c_g=%.6g\n', ...
        Sched.c0, Sched.c_gamma);
    fprintf('γMAE° P/A04/AFF/RL: X %.3f/%.3f/%.3f/%.3f (%+.1f%% vs U) | XZ %.3f/%.3f/%.3f/%.3f (%+.1f%%) | R10 %.3f/%.3f/%.3f/%.3f (%+.1f%%)\n', ...
        G.rows.X.g_mae(1), G.rows.X.g_mae(2), G.rows.X.g_mae(3), G.rows.X.g_mae(4), G.rows.X.g_imp, ...
        G.rows.XZ.g_mae(1), G.rows.XZ.g_mae(2), G.rows.XZ.g_mae(3), G.rows.XZ.g_mae(4), G.rows.XZ.g_imp, ...
        G.rows.H.g_mae(1), G.rows.H.g_mae(2), G.rows.H.g_mae(3), G.rows.H.g_mae(4), G.rows.H.g_imp);
    fprintf('Settle AFF→RL: X %.3f→%.3f (%+.1f%%) | XZ %.3f→%.3f (%+.1f%%) | R10 %.3f→%.3f (%+.1f%%)\n', ...
        G.rows.X.settle(3), G.rows.X.settle(4), G.rows.X.set_imp_aff, ...
        G.rows.XZ.settle(3), G.rows.XZ.settle(4), G.rows.XZ.set_imp_aff, ...
        G.rows.H.settle(3), G.rows.H.settle(4), G.rows.H.set_imp_aff);
    fprintf('OS AFF→RL: X %.3f→%.3f (%+.1f%%) | XZ %.3f→%.3f (%+.1f%%) | R10 %.3f→%.3f (%+.1f%%)\n', ...
        G.rows.X.os(3), G.rows.X.os(4), G.rows.X.os_imp_aff, ...
        G.rows.XZ.os(3), G.rows.XZ.os(4), G.rows.XZ.os_imp_aff, ...
        G.rows.H.os(3), G.rows.H.os(4), G.rows.H.os_imp_aff);
    fprintf('uMAE RL: X %.4f XZ %.4f R10 %.4f | gates u/γ/CTE/yr/act/set/vsAFF/sat=%s/%s/%s/%s/%s/%s/%s/%s\n', ...
        G.rows.X.u_mae(4), G.rows.XZ.u_mae(4), G.rows.H.u_mae(4), ...
        yn(G.u_ok), yn(G.gamma_ok), yn(G.cte_ok), yn(G.yaw_roll_ok), ...
        yn(G.act_ok), yn(G.settle_ok), yn(G.vs_aff_ok), yn(G.sat_chatter_ok));
    fprintf('Files: %s | %s | %s\n', md, mat, png);
    fprintf('Next: %s — %s\n', next_opt, next_detail);
end

%% ===================== helpers =====================
function st = err_stats_deg(e, mask)
    st = struct('mae_deg', NaN, 'rms_deg', NaN, 'p95_deg', NaN, 'max_deg', NaN, ...
        'signed_mean_deg', NaN, 'n', 0);
    if ~any(mask); return; end
    v = e(mask); st.n = numel(v);
    st.signed_mean_deg = rad2deg(mean(v));
    st.mae_deg = rad2deg(mean(abs(v)));
    st.rms_deg = rad2deg(rms_local(v));
    st.p95_deg = rad2deg(prctile_local(abs(v), 95));
    st.max_deg = rad2deg(max(abs(v)));
end

function y = sat_pct(u, mask, thr)
    if ~any(mask); y = NaN; return; end
    y = 100 * mean(abs(u(mask)) >= thr);
end

function r = rms_local(x), x = x(:); r = sqrt(mean(x.^2)); end
function p = prctile_local(x, q)
    x = sort(x(:)); if isempty(x); p = NaN; return; end
    k = max(1, min(numel(x), round(q / 100 * numel(x)))); p = x(k);
end
function m = mean_safe(x, mask)
    if ~any(mask); m = NaN; return; end
    m = mean(x(mask));
end
function m = mean_abs_safe(x, mask)
    if ~any(mask); m = NaN; return; end
    m = mean(abs(x(mask)));
end
function m = rms_safe(x, mask)
    if ~any(mask); m = NaN; return; end
    m = rms_local(x(mask));
end
function m = max_abs_safe(x, mask)
    if ~any(mask); m = NaN; return; end
    m = max(abs(x(mask)));
end
function s = yn(tf)
    if tf; s = 'YES'; else; s = 'NO'; end
end
