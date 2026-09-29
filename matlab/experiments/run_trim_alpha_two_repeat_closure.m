function run_trim_alpha_two_repeat_closure()
% TRIM_ALPHA_TWO_REPEAT_CLOSURE_001 — two-repeat nonlinear 6DOF closure.
% Read-only: TRIM_ALPHA_FF_RATE_LIMIT.mat, TRIM_ALPHA_TRANSIENT_GATE_AUDIT.mat,
%            TRIM_ALPHA_SCHEDULE_ID.mat. One invocation; production untouched.
% Candidate: trim-alpha schedule + 2deg/s alpha slew, speed PI+FF, Kz=.04, depth-I=0
%   (isolated guidance_law_trim_alpha_ff_rate_limit.m).
% Corrected metrics: e_gamma=wrap(gamma_ref-gamma_act); persistent settle +/-0.5deg
%   through 88% path; acquisition = fixed first 5s (+ report persistent window);
%   steady = last valid path segment (t>=5 & s<0.88*s_total); OS vs mean(gamma_ref|ss);
%   attitude separate; actuators on identical fixed/steady masks; own-speed roll eq.
% Artifacts: suite_results/TRIM_ALPHA_TWO_REPEAT_CLOSURE.{md,mat,png}
% Appends STATE_SPACE_MODEL_AUDIT.md.

    project_dir = fileparts(fileparts(fileparts(mfilename('fullpath')))); % repo root
    addpath(genpath(fullfile(project_dir, 'matlab')));
    out_dir = fullfile(project_dir, 'suite_results');
    if ~exist(out_dir, 'dir'); mkdir(out_dir); end
    tag = 'TRIM_ALPHA_TWO_REPEAT_CLOSURE';
    task_id = 'TRIM_ALPHA_TWO_REPEAT_CLOSURE_001';

    rl_path    = fullfile(out_dir, 'TRIM_ALPHA_FF_RATE_LIMIT.mat');
    audit_path = fullfile(out_dir, 'TRIM_ALPHA_TRANSIENT_GATE_AUDIT.mat');
    sched_path = fullfile(out_dir, 'TRIM_ALPHA_SCHEDULE_ID.mat');
    cand_path  = fullfile(project_dir, 'guidance_law_trim_alpha_ff_rate_limit.m');
    prod_path  = fullfile(project_dir, 'guidance_law.m');
    assert(exist(rl_path, 'file') == 2, 'Missing %s', rl_path);
    assert(exist(audit_path, 'file') == 2, 'Missing %s', audit_path);
    assert(exist(sched_path, 'file') == 2, 'Missing %s', sched_path);
    assert(exist(cand_path, 'file') == 2, 'Missing %s', cand_path);

    RL = load(rl_path);
    Audit = load(audit_path); %#ok<NASGU>
    SchedIn = load(sched_path);
    Sched = SchedIn.schedule;
    law = RL.law;
    lim = RL.limits;

    cand_txt = fileread(cand_path);
    prod_txt = fileread(prod_path);
    assert(~contains(prod_txt, 'alpha_ff_c0'), 'production must not reference alpha_ff_c0');
    assert(~contains(prod_txt, 'alpha_ff_rate_max'), 'production must not reference rate limit');
    assert(contains(cand_txt, 'alpha_ff_rate_max'), 'candidate missing alpha rate limit');
    assert(contains(cand_txt, 'pitch_raw = gamma_path + K_gamma * eg_f + pitch_corr + alpha_cmd'), ...
        'candidate missing pitch_raw+alpha_cmd');
    assert(abs(law.kD - 1.694074) < 5e-6, 'kD mismatch');
    assert(abs(Sched.c0 - 7.5013943801e-02) < 1e-10, 'c0 mismatch');
    assert(abs(Sched.c_gamma - 4.7291247774e-02) < 1e-10, 'c_gamma mismatch');

    band_deg = 0.5;
    end_frac = 0.88;
    t_acq_fixed = 5.0;
    abs_eps_rate = 1e-6;
    abs_eps_ang = 1e-3;
    abs_eps_pct = 0.05;
    abs_eps_len = 1e-4;

    fprintf('\n========== %s ==========\n', task_id);
    fprintf('Read-only: TRIM_ALPHA_FF_RATE_LIMIT | TRIM_ALPHA_TRANSIENT_GATE_AUDIT | TRIM_ALPHA_SCHEDULE_ID\n');
    fprintf('Corrected e_gamma persistent settle +/-%.2fdeg; fixed acq t<%.1fs; own-eq roll\n', ...
        band_deg, t_acq_fixed);
    fprintf('Two-repeat X/XZ/R10 of isolated candidate; production untouched\n');

    clear functions
    clear guidance_law guidance_law_trim_alpha_ff_rate_limit controller_law
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
    alpha_ff_rate_max = deg2rad(2);
    if isfield(law, 'Kp_roll'); Kp_roll = law.Kp_roll; end
    desired_speed = 1.5;
    Kp_x = law.Kp;

    seed_used = 0;
    rng(seed_used, 'twister');

    nX = 600; xX = linspace(0, 45, nX)';
    pathX = [xX, zeros(nX, 1), zeros(nX, 1)];
    nXZ = 900; xXZ = linspace(0, 42, nXZ)';
    pathXZ = [xXZ, zeros(nXZ, 1), 0.4 * xXZ];
    pathH = generate_balanced_helical_path(10.0, 2.0, 2, 500);

    routes = { ...
        struct('name','X',  'path',pathX,  'T',18, 'u0',1.5, 'xz',false, 'R',0); ...
        struct('name','XZ', 'path',pathXZ, 'T',22, 'u0',1.5, 'xz',true,  'R',0); ...
        struct('name','H',  'path',pathH,  'T',45, 'u0',1.5, 'xz',false, 'R',10)};
    labels = struct('X','X','XZ','XZ','H','R10');

    % ---- Re-analyze production / uncorrected from RATE_LIMIT with corrected metrics ----
    Res = struct();
    src = { ...
        {'P', 'production'}; ...
        {'U', 'uncorrected'}; ...
        {'AFF', 'trim_alpha_ff'}};
    for is = 1:numel(src)
        key = src{is}{1}; fld = src{is}{2};
        for i = 1:numel(routes)
            r = routes{i};
            S = RL.(fld).(r.name).S;
            M = analyze_corrected(S, r.path, lim, band_deg, end_frac, t_acq_fixed);
            Res.(key).(r.name).S = S;
            Res.(key).(r.name).M = M;
            fprintf('  [load %s/%s] uMAE=%.4f gMAE=%.4f cte=%.4f set=%.3f acqMAE=%.3f OS=%.3f\n', ...
                key, labels.(r.name), M.speed.steady.mae, M.gamma.steady.mae_deg, ...
                M.path.cte_ss_mean, M.gamma.settling_s, M.gamma.acq.mae_deg, M.gamma.overshoot_deg);
        end
    end

    % ---- Two-repeat simulate isolated candidate ----
    cfgT = struct('key','C', 'label','trim_alpha_ff_rate_limit', 'thrust','candidate', ...
        'alpha',true, 'guid','cand', 'Kz',0.040);
    Rep = cell(1, 2);
    for rep = 1:2
        fprintf('\n===== REPEAT %d/%d candidate =====\n', rep, 2);
        Rep{rep} = struct();
        for i = 1:numel(routes)
            r = routes{i};
            fprintf('\n-- C%d %s --\n', rep, r.name);
            rng(seed_used, 'twister');
            [S, M] = sim_analyze(r, lim, cfgT, law, band_deg, end_frac, t_acq_fixed);
            Rep{rep}.(r.name).S = S;
            Rep{rep}.(r.name).M = M;
            fprintf('  [C%d] uMAE=%.4f gMAE=%.4f cte=%.4f set=%.3f acqMAE=%.3f OS=%.3f ownT=%.4f\n', ...
                rep, M.speed.steady.mae, M.gamma.steady.mae_deg, M.path.cte_ss_mean, ...
                M.gamma.settling_s, M.gamma.acq.mae_deg, M.gamma.overshoot_deg, M.own.tilde.rms_deg);
        end
    end

    % Determinism check
    Rdet = struct();
    Rdet.pass = true;
    Rdet.notes = {};
    for i = 1:numel(routes)
        nm = routes{i}.name;
        M1 = Rep{1}.(nm).M; M2 = Rep{2}.(nm).M;
        S1 = Rep{1}.(nm).S; S2 = Rep{2}.(nm).S;
        d_u = abs(M1.speed.steady.mae - M2.speed.steady.mae);
        d_g = abs(M1.gamma.steady.mae_deg - M2.gamma.steady.mae_deg);
        d_th = max(abs(S1.theta_ref(:) - S2.theta_ref(:)));
        d_de = max(abs(S1.delta_e(:) - S2.delta_e(:)));
        ok = (d_u < 1e-12) && (d_g < 1e-12) && (d_th < 1e-12) && (d_de < 1e-12);
        Rdet.(nm) = struct('ok', ok, 'd_u', d_u, 'd_g', d_g, 'd_th', d_th, 'd_de', d_de);
        Rdet.pass = Rdet.pass && ok;
        Rdet.notes{end+1} = sprintf('%s ok=%d d_u=%.3e d_g=%.3e d_th=%.3e d_de=%.3e', ...
            labels.(nm), ok, d_u, d_g, d_th, d_de); %#ok<AGROW>
    end
    fprintf('\nDeterminism: %s\n', tern(Rdet.pass, 'PASS', 'FAIL'));

    % Official metrics = repeat 1
    for i = 1:numel(routes)
        nm = routes{i}.name;
        Res.C.(nm) = Rep{1}.(nm);
    end

    [G, verdict, next_opt, next_detail, evidence] = score_all(Res, Rdet, ...
        abs_eps_rate, abs_eps_ang, abs_eps_pct, abs_eps_len);

    md_path  = fullfile(out_dir, [tag '.md']);
    mat_path = fullfile(out_dir, [tag '.mat']);
    png_path = fullfile(out_dir, [tag '.png']);

    write_png(png_path, Res, lim, task_id, verdict, band_deg);
    write_md(md_path, task_id, verdict, law, Sched, Res, G, Rdet, evidence, ...
        next_opt, next_detail, seed_used, band_deg, end_frac, t_acq_fixed, ...
        rl_path, audit_path, sched_path, cand_path, md_path, mat_path, png_path);
    append_ss_audit(out_dir, task_id, verdict, law, Sched, Res, G, Rdet, ...
        next_opt, next_detail, md_path, mat_path, png_path, band_deg);

    Out = struct();
    Out.task_id = task_id;
    Out.verdict = verdict;
    Out.law = law;
    Out.schedule = Sched;
    Out.defs = struct( ...
        'e_gamma', 'e_gamma=wrapToPi(gamma_ref-gamma_act); gamma_act=atan2(VD,Uh)', ...
        'settle', sprintf('persistent |e_gamma|<=+/-%.2fdeg through %.2f*s_total', band_deg, end_frac), ...
        'acq', sprintf('fixed first %.1fs & s<%.2f*s_total (+ persistent window reported)', t_acq_fixed, end_frac), ...
        'steady', sprintf('t>=%.1fs & s<%.2f*s_total (last valid path segment)', t_acq_fixed, end_frac), ...
        'OS', 'max(0, signed excursion of gamma_act past mean(gamma_ref|steady)) during fixed acq', ...
        'dip', 'opposite excursion vs final ref during first acq third', ...
        'actuators', 'identical fixed acq/steady masks across variants', ...
        'roll', 'own-speed empirical phi_eq');
    Out.production = Res.P;
    Out.uncorrected = Res.U;
    Out.trim_alpha_ff = Res.AFF;
    Out.candidate = Res.C;
    Out.repeats = Rep;
    Out.determinism = Rdet;
    Out.gates = G;
    Out.evidence = evidence;
    Out.next_opt = next_opt;
    Out.next_detail = next_detail;
    Out.limits = lim;
    Out.seed_used = seed_used;
    Out.sources = {rl_path; audit_path; sched_path; cand_path};
    Out.paths = struct('md', md_path, 'mat', mat_path, 'png', png_path);
    Out.production_edited = false;
    Out.note = ['Two-repeat closure of rate-limited trim-alpha with corrected e_gamma ', ...
        'persistent settle + fixed actuator windows; production untouched'];
    save(mat_path, '-struct', 'Out');

    fprintf('\nVERDICT: %s | next=%s\n', verdict, next_opt);
    fprintf('Saved: %s\n%s\n%s\n', md_path, mat_path, png_path);
    print_feedback(verdict, Res, G, Rdet, evidence, next_opt, next_detail, md_path, mat_path, png_path);
    assignin('base', 'TRIM_ALPHA_TWO_REPEAT_CLOSURE_PASS', strcmp(verdict, 'PASS'));
end

%% ===================== simulate =====================
function [S, M] = sim_analyze(route, lim, cfg, law, band_deg, end_frac, t_acq_fixed)
    global dt_controller desired_speed lambda_muw_ff
    global K_gamma enable_alpha_hat Ki_z_depth Kz_depth

    K_gamma = 0;
    enable_alpha_hat = logical(cfg.alpha);
    Ki_z_depth = 0;
    Kz_depth = cfg.Kz;

    clear guidance_law guidance_law_trim_alpha_ff_rate_limit controller_law
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
    M = analyze_corrected(S, path, lim, band_deg, end_frac, t_acq_fixed);
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
            thr = thr_prod; t_un = thr_prod; t_ff = thrust_trim; t_p = thr - thrust_trim; t_i = 0;
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
            fprintf('  %s sim %d/%d t=%.2f u=%.3f thr=%.1f a_cmd=%.2fdeg\n', ...
                cfg.key, idx, n_steps, total_time, current_u, thr, rad2deg(acmd_log(idx)));
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
    S.alpha_hat = ahat_log(:);
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

%% ===================== corrected metrics =====================
function M = analyze_corrected(S, path, lim, band_deg, end_frac, t_acq_fixed)
    t = S.t(:); dt = S.dt;
    phi = S.ori(:, 1); theta = S.ori(:, 2); psi = S.ori(:, 3);
    theta_phys = -theta;
    p = S.rates(:, 1); q = S.rates(:, 2); r = S.rates(:, 3);
    de = S.delta_e(:); dr = S.delta_r(:);
    u = S.u_body(:); v = S.v_body(:); w = S.w_body(:);

    e_psi = wrapToPi(S.psi_ref(:) - psi);
    e_th_att = wrapToPi(S.theta_ref(:) - theta_phys);

    [VN, VE, VD, Uh] = ned_velocity(phi, theta, psi, u, v, w); %#ok<ASGLU>
    gamma_act = atan2(VD, max(Uh, 1e-9));
    alpha_body = atan2(w, u);
    [gamma_ref, cte_perp, s_prog, s_total] = path_gamma_cte(path, S.vp);
    theta_cmd = wrapToPi(gamma_ref - alpha_body);
    e_gamma = wrapToPi(gamma_ref - gamma_act);
    e_th_req = wrapToPi(theta_cmd - theta_phys);

    % Persistent settle on true e_gamma
    Wg = compute_pitch_window_metrics(t, e_gamma, s_prog, s_total, ...
        'mode', 'persistent', 'band_deg', band_deg, 'end_frac', end_frac);
    Wa = compute_pitch_window_metrics(t, e_th_att, s_prog, s_total, ...
        'mode', 'persistent', 'band_deg', band_deg, 'end_frac', end_frac);

    mask_before = Wg.mask_before_end;
    % Identical fixed/steady time masks (for actuators + steady gates)
    mask_acq = (t < t_acq_fixed) & mask_before;
    mask_ss  = (t >= t_acq_fixed) & mask_before;
    if ~any(mask_acq); mask_acq = (t < t_acq_fixed); end
    if ~any(mask_ss);  mask_ss  = (t >= t_acq_fixed) & mask_before; end

    % Also persistent-window acq (reported)
    mask_acq_pers = Wg.mask_acq;
    if ~any(mask_acq_pers); mask_acq_pers = mask_acq; end

    Udes = 1.5;
    mask_hold = mask_ss & (abs(S.u_ref - Udes) <= 0.08);
    if ~any(mask_hold); mask_hold = mask_ss; end
    mask_yaw = mask_ss;

    own_eq = identify_own_eq(phi, psi, t, mask_ss);
    tilde_own = phi - own_eq.phi_eq_rad;

    e_u = S.u_ref - S.u_ctrl;
    thr_dot = [0; diff(S.thrust)] / dt;
    de_dot = [0; diff(de)] / dt;
    dr_dot = [0; diff(dr)] / dt;

    M = struct();
    M.band_deg = band_deg; M.end_frac = end_frac; M.t_acq_fixed = t_acq_fixed;
    M.Wg = Wg; M.Wa = Wa;
    M.mask_ss = mask_ss; M.mask_acq = mask_acq; M.mask_acq_pers = mask_acq_pers;
    M.mask_hold = mask_hold; M.mask_before = mask_before;

    M.gamma = struct();
    M.gamma.settling_s = Wg.settling_s;
    M.gamma.persistent_ok = Wg.persistent_ok;
    M.gamma.acq = err_stats_deg(e_gamma, mask_acq);
    M.gamma.acq_pers = err_stats_deg(e_gamma, mask_acq_pers);
    M.gamma.steady = err_stats_deg(e_gamma, mask_ss);
    M.gamma.overshoot_deg = overshoot_vs_final_ref(gamma_act, gamma_ref, mask_acq, mask_ss);
    M.gamma.initial_dip_deg = initial_dip_vs_final_ref(gamma_act, gamma_ref, mask_acq, mask_ss);

    M.theta_att = struct();
    M.theta_att.settling_s = Wa.settling_s;
    M.theta_att.acq = err_stats_deg(e_th_att, mask_acq);
    M.theta_att.steady = err_stats_deg(e_th_att, mask_ss);
    M.theta_att.overshoot_deg = overshoot_vs_final_ref(theta_phys, S.theta_ref(:), mask_acq, mask_ss);

    M.yaw = err_stats_deg(e_psi, mask_yaw);
    M.own = struct();
    M.own.phi_eq_rad = own_eq.phi_eq_rad;
    M.own.phi_eq_deg = rad2deg(own_eq.phi_eq_rad);
    M.own.estimator = own_eq.estimator;
    M.own.tilde = err_stats_deg(tilde_own, mask_ss);
    M.p = err_stats_deg(p, mask_ss); M.p.rms_dps = M.p.rms_deg;
    M.q = err_stats_deg(q, mask_ss); M.r = err_stats_deg(r, mask_ss);
    M.path = struct('cte_ss_mean', mean_safe(cte_perp, mask_ss), ...
        'cte_ss_rms', rms_safe(cte_perp, mask_ss), ...
        'cte_acq_mean', mean_safe(cte_perp, mask_acq));

    M.speed = struct();
    M.speed.steady = speed_stats(e_u, mask_hold);
    M.speed.acq = speed_stats(e_u, mask_acq);

    M.act = struct();
    M.act.de_sat_pct = sat_pct(de, mask_ss, 0.98 * lim.de_max);
    M.act.dr_sat_pct = sat_pct(dr, mask_ss, 0.98 * lim.dr_max);
    M.act.de_rms_ss = rms_safe(de, mask_ss);
    M.act.dr_rms_ss = rms_safe(dr, mask_ss);
    M.act.de_rms_acq = rms_safe(de, mask_acq);
    M.act.dr_rms_acq = rms_safe(dr, mask_acq);
    M.act.de_rate_rms = rms_safe(de_dot, mask_ss);
    M.act.dr_rate_rms = rms_safe(dr_dot, mask_ss);
    M.act.de_rate_acq = rms_safe(de_dot, mask_acq);
    M.act.dr_rate_acq = rms_safe(dr_dot, mask_acq);
    M.act.sat_thrust = thrust_sat_pct(S.thrust, true(size(S.thrust)), lim);

    I = S.Ti(:); Idot = [0; diff(I)] / dt;
    M.I = struct();
    M.I.mean = mean_safe(I, mask_hold);
    M.I.rms = rms_safe(I, mask_hold);
    M.I.rate_rms = rms_safe(Idot, mask_hold);
    M.I.chatter = false; M.I.flip_rate = NaN; M.I.windup = false;
    if any(mask_hold)
        idh = Idot(mask_hold);
        flips = sum(idh(1:end-1) .* idh(2:end) < 0);
        M.I.flip_rate = flips / max(sum(mask_hold) - 1, 1);
        M.I.chatter = (M.I.flip_rate > 0.35) && (M.I.rate_rms > 5.0);
    end
    M.I.windup = (max_abs_safe(I, true(size(I))) > 0.9 * lim.thrust_max) || ...
        (M.act.sat_thrust > 1.0 && abs(M.I.mean) > 20);

    if isfield(S, 'alpha_cmd')
        M.alpha_cmd_rate_max_dps = rad2deg(max_abs_safe(S.alpha_cmd_dot, true(size(S.alpha_cmd_dot))));
    else
        M.alpha_cmd_rate_max_dps = NaN;
    end

    M.ts = struct('gamma_ref', gamma_ref, 'gamma_act', gamma_act, 'e_gamma', e_gamma, ...
        'theta_cmd', theta_cmd, 'theta_phys', theta_phys, 'e_th_att', e_th_att, ...
        'e_th_req', e_th_req, 'alpha_body', alpha_body, ...
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

function os = overshoot_vs_final_ref(signal, ref, mask_acq, mask_ss)
    os = NaN;
    if ~any(mask_acq) || ~any(mask_ss); return; end
    final_ref = mean(ref(mask_ss));
    sig0 = signal(find(mask_acq, 1, 'first'));
    sa = signal(mask_acq);
    if final_ref >= sig0
        os = rad2deg(max(0, max(sa) - final_ref));
    else
        os = rad2deg(max(0, final_ref - min(sa)));
    end
end

function dip = initial_dip_vs_final_ref(signal, ref, mask_acq, mask_ss)
    dip = NaN;
    if ~any(mask_acq) || ~any(mask_ss); return; end
    final_ref = mean(ref(mask_ss));
    idx = find(mask_acq);
    n1 = max(1, floor(numel(idx) / 3));
    early = signal(idx(1:n1));
    sig0 = signal(idx(1));
    if final_ref >= sig0
        dip = rad2deg(max(0, sig0 - min(early)));
    else
        dip = rad2deg(max(0, max(early) - sig0));
    end
end

function st = speed_stats(e, mask)
    st = struct('signed_mean', NaN, 'mae', NaN, 'rms', NaN, 'p95', NaN, 'max', NaN, 'n', 0);
    if ~any(mask); return; end
    v = e(mask); st.n = numel(v);
    st.signed_mean = mean(v); st.mae = mean(abs(v)); st.rms = rms_local(v);
    st.p95 = prctile_local(abs(v), 95); st.max = max(abs(v));
end

function y = thrust_sat_pct(thr, mask, lim)
    if ~any(mask); y = NaN; return; end
    v = thr(mask);
    y = 100 * mean((v >= 0.98 * lim.thrust_max) | (v <= lim.thrust_min + 0.02 * abs(lim.thrust_min)));
end

%% ===================== gates =====================
function [G, verdict, next_opt, next_detail, evidence] = score_all(Res, Rdet, ...
        abs_eps_rate, abs_eps_ang, abs_eps_pct, abs_eps_len)

    names = {'X', 'XZ', 'H'};
    labels = {'X', 'XZ', 'R10'};
    G = struct();
    G.det_ok = Rdet.pass;
    G.u_ok = true; G.gamma_ok = true; G.cte_ok = true;
    G.settle_ok = true; G.acq_ok = true; G.peak_ok = true;
    G.act_ok = true; G.yaw_roll_ok = true; G.sat_chatter_ok = true;
    G.rows = struct();
    evidence = {};

    evidence{end+1} = sprintf('Determinism: %s', tern(Rdet.pass, 'PASS', 'FAIL')); %#ok<*AGROW>
    for k = 1:numel(Rdet.notes)
        evidence{end+1} = ['repeat: ', Rdet.notes{k}];
    end

    for i = 1:3
        nm = names{i}; lbl = labels{i};
        P = Res.P.(nm).M; U = Res.U.(nm).M; C = Res.C.(nm).M;
        row = struct(); row.label = lbl;

        % Vectors P / U / C
        row.u_mae = [P.speed.steady.mae, U.speed.steady.mae, C.speed.steady.mae];
        row.u_p95 = [P.speed.steady.p95, U.speed.steady.p95, C.speed.steady.p95];
        row.g_mae = [P.gamma.steady.mae_deg, U.gamma.steady.mae_deg, C.gamma.steady.mae_deg];
        row.cte   = [P.path.cte_ss_mean, U.path.cte_ss_mean, C.path.cte_ss_mean];
        row.settle = [P.gamma.settling_s, U.gamma.settling_s, C.gamma.settling_s];
        row.acq_mae = [P.gamma.acq.mae_deg, U.gamma.acq.mae_deg, C.gamma.acq.mae_deg];
        row.acq_rms = [P.gamma.acq.rms_deg, U.gamma.acq.rms_deg, C.gamma.acq.rms_deg];
        row.acq_p95 = [P.gamma.acq.p95_deg, U.gamma.acq.p95_deg, C.gamma.acq.p95_deg];
        row.acq_max = [P.gamma.acq.max_deg, U.gamma.acq.max_deg, C.gamma.acq.max_deg];
        row.acq_pers_mae = [P.gamma.acq_pers.mae_deg, U.gamma.acq_pers.mae_deg, C.gamma.acq_pers.mae_deg];
        row.os  = [P.gamma.overshoot_deg, U.gamma.overshoot_deg, C.gamma.overshoot_deg];
        row.dip = [P.gamma.initial_dip_deg, U.gamma.initial_dip_deg, C.gamma.initial_dip_deg];
        row.g_p95_ss = [P.gamma.steady.p95_deg, U.gamma.steady.p95_deg, C.gamma.steady.p95_deg];
        row.g_max_ss = [P.gamma.steady.max_deg, U.gamma.steady.max_deg, C.gamma.steady.max_deg];
        row.yaw = [P.yaw.mae_deg, U.yaw.mae_deg, C.yaw.mae_deg];
        row.own_t = [P.own.tilde.rms_deg, U.own.tilde.rms_deg, C.own.tilde.rms_deg];
        row.own_eq = [P.own.phi_eq_deg, U.own.phi_eq_deg, C.own.phi_eq_deg];
        row.p_rms = [P.p.rms_dps, U.p.rms_dps, C.p.rms_dps];
        row.de_rms_ss = [P.act.de_rms_ss, U.act.de_rms_ss, C.act.de_rms_ss];
        row.dr_rms_ss = [P.act.dr_rms_ss, U.act.dr_rms_ss, C.act.dr_rms_ss];
        row.de_rms_acq = [P.act.de_rms_acq, U.act.de_rms_acq, C.act.de_rms_acq];
        row.dr_rms_acq = [P.act.dr_rms_acq, U.act.dr_rms_acq, C.act.dr_rms_acq];
        row.de_rate = [P.act.de_rate_rms, U.act.de_rate_rms, C.act.de_rate_rms];
        row.dr_rate = [P.act.dr_rate_rms, U.act.dr_rate_rms, C.act.dr_rate_rms];
        row.de_rate_acq = [P.act.de_rate_acq, U.act.de_rate_acq, C.act.de_rate_acq];
        row.dr_rate_acq = [P.act.dr_rate_acq, U.act.dr_rate_acq, C.act.dr_rate_acq];
        row.de_sat = [P.act.de_sat_pct, U.act.de_sat_pct, C.act.de_sat_pct];
        row.dr_sat = [P.act.dr_sat_pct, U.act.dr_sat_pct, C.act.dr_sat_pct];
        row.thr_sat = [P.act.sat_thrust, U.act.sat_thrust, C.act.sat_thrust];
        row.th_set = [P.theta_att.settling_s, U.theta_att.settling_s, C.theta_att.settling_s];
        row.th_mae = [P.theta_att.steady.mae_deg, U.theta_att.steady.mae_deg, C.theta_att.steady.mae_deg];
        row.acmd_rate_max = C.alpha_cmd_rate_max_dps;

        % ---- Gates ----
        row.u_gate = (C.speed.steady.mae <= 0.07) && (C.speed.steady.p95 <= 0.10);

        row.g_imp_P = improve_pct(P.gamma.steady.mae_deg, C.gamma.steady.mae_deg, abs_eps_ang);
        row.g_imp_U = improve_pct(U.gamma.steady.mae_deg, C.gamma.steady.mae_deg, abs_eps_ang);
        row.cte_imp_P = improve_pct(P.path.cte_ss_mean, C.path.cte_ss_mean, abs_eps_len);
        row.cte_imp_U = improve_pct(U.path.cte_ss_mean, C.path.cte_ss_mean, abs_eps_len);
        row.g_vs_P = le_improve(C.gamma.steady.mae_deg, P.gamma.steady.mae_deg, 0.05, abs_eps_ang);
        row.g_vs_U = le_improve(C.gamma.steady.mae_deg, U.gamma.steady.mae_deg, 0.10, abs_eps_ang);
        row.cte_vs_P = le_improve(C.path.cte_ss_mean, P.path.cte_ss_mean, 0.05, abs_eps_len);
        row.cte_vs_U = le_improve(C.path.cte_ss_mean, U.path.cte_ss_mean, 0.10, abs_eps_len);
        row.g_gate = row.g_vs_P && row.g_vs_U;
        row.cte_gate = row.cte_vs_P && row.cte_vs_U;

        % Persistent settling / fixed-acq MAE improve on each route (vs P)
        row.set_imp_P = improve_pct(P.gamma.settling_s, C.gamma.settling_s, abs_eps_ang);
        row.acq_imp_P = improve_pct(P.gamma.acq.mae_deg, C.gamma.acq.mae_deg, abs_eps_ang);
        row.settle_improve = improves_or_eq(C.gamma.settling_s, P.gamma.settling_s, abs_eps_ang);
        row.acq_improve = improves_or_eq(C.gamma.acq.mae_deg, P.gamma.acq.mae_deg, abs_eps_ang);

        % dip / steady p95 / max not >2% worse vs P
        row.dip_ok = within_tol(C.gamma.initial_dip_deg, P.gamma.initial_dip_deg, 0.02, abs_eps_ang);
        row.p95_ok = within_tol(C.gamma.steady.p95_deg, P.gamma.steady.p95_deg, 0.02, abs_eps_ang);
        row.max_ok = within_tol(C.gamma.steady.max_deg, P.gamma.steady.max_deg, 0.02, abs_eps_ang);
        row.acq_p95_ok = within_tol(C.gamma.acq.p95_deg, P.gamma.acq.p95_deg, 0.02, abs_eps_ang);
        row.acq_max_ok = within_tol(C.gamma.acq.max_deg, P.gamma.acq.max_deg, 0.02, abs_eps_ang);
        row.peak_ok = row.dip_ok && row.p95_ok && row.max_ok && row.acq_p95_ok && row.acq_max_ok;

        % Actuator RMS/rate not >2% worse (fixed masks)
        row.de_rms_ss_ok = within_tol(C.act.de_rms_ss, P.act.de_rms_ss, 0.02, abs_eps_rate);
        row.dr_rms_ss_ok = within_tol(C.act.dr_rms_ss, P.act.dr_rms_ss, 0.02, abs_eps_rate);
        row.de_rms_acq_ok = within_tol(C.act.de_rms_acq, P.act.de_rms_acq, 0.02, abs_eps_rate);
        row.dr_rms_acq_ok = within_tol(C.act.dr_rms_acq, P.act.dr_rms_acq, 0.02, abs_eps_rate);
        row.de_rate_ok = within_tol(C.act.de_rate_rms, P.act.de_rate_rms, 0.02, abs_eps_rate);
        row.dr_rate_ok = within_tol(C.act.dr_rate_rms, P.act.dr_rate_rms, 0.02, abs_eps_rate);
        row.de_rate_acq_ok = within_tol(C.act.de_rate_acq, P.act.de_rate_acq, 0.02, abs_eps_rate);
        row.dr_rate_acq_ok = within_tol(C.act.dr_rate_acq, P.act.dr_rate_acq, 0.02, abs_eps_rate);
        row.act_ok = row.de_rms_ss_ok && row.dr_rms_ss_ok && row.de_rms_acq_ok && row.dr_rms_acq_ok && ...
            row.de_rate_ok && row.dr_rate_ok && row.de_rate_acq_ok && row.dr_rate_acq_ok;

        % Yaw / own-eq roll not >2% worse
        row.yaw_ok = within_tol(C.yaw.mae_deg, P.yaw.mae_deg, 0.02, abs_eps_ang);
        row.own_ok = within_tol(C.own.tilde.rms_deg, P.own.tilde.rms_deg, 0.02, abs_eps_ang);
        row.p_ok = within_tol(C.p.rms_dps, P.p.rms_dps, 0.02, abs_eps_ang);
        row.yaw_roll_ok = row.yaw_ok && row.own_ok && row.p_ok;

        row.sat_chatter_ok = (C.act.sat_thrust <= 1.0) && ~C.I.chatter && ~C.I.windup && ...
            (C.act.de_sat_pct <= max(1.0, P.act.de_sat_pct + abs_eps_pct)) && ...
            (C.act.dr_sat_pct <= max(1.0, P.act.dr_sat_pct + abs_eps_pct));

        G.rows.(nm) = row;
        G.u_ok = G.u_ok && row.u_gate;
        G.gamma_ok = G.gamma_ok && row.g_gate;
        G.cte_ok = G.cte_ok && row.cte_gate;
        G.settle_ok = G.settle_ok && row.settle_improve;
        G.acq_ok = G.acq_ok && row.acq_improve;
        G.peak_ok = G.peak_ok && row.peak_ok;
        G.act_ok = G.act_ok && row.act_ok;
        G.yaw_roll_ok = G.yaw_roll_ok && row.yaw_roll_ok;
        G.sat_chatter_ok = G.sat_chatter_ok && row.sat_chatter_ok;

        evidence{end+1} = sprintf(['%s uMAE=%.4f p95=%.4f | γMAE P/U/C=%.3f/%.3f/%.3f ', ...
            '(ΔP=%+.1f%% ΔU=%+.1f%%) | CTE P/U/C=%.4f/%.4f/%.4f (ΔP=%+.1f%% ΔU=%+.1f%%)'], ...
            lbl, C.speed.steady.mae, C.speed.steady.p95, ...
            row.g_mae(1), row.g_mae(2), row.g_mae(3), row.g_imp_P, row.g_imp_U, ...
            row.cte(1), row.cte(2), row.cte(3), row.cte_imp_P, row.cte_imp_U);
        evidence{end+1} = sprintf(['%s settle P→C %.3f→%.3f (%+.1f%%) acqMAE %.3f→%.3f (%+.1f%%) ', ...
            'dip %.3f→%.3f OS %.3f→%.3f'], lbl, ...
            row.settle(1), row.settle(3), row.set_imp_P, ...
            row.acq_mae(1), row.acq_mae(3), row.acq_imp_P, ...
            row.dip(1), row.dip(3), row.os(1), row.os(3));
        evidence{end+1} = sprintf(['%s act deR_ss %.4g→%.4g deR_acq %.4g→%.4g ', ...
            'drR_ss %.4g→%.4g | yaw %.4f→%.4f ownT %.4f→%.4f satT=%.2f%% chatter=%d'], ...
            lbl, row.de_rate(1), row.de_rate(3), row.de_rate_acq(1), row.de_rate_acq(3), ...
            row.dr_rate(1), row.dr_rate(3), row.yaw(1), row.yaw(3), ...
            row.own_t(1), row.own_t(3), row.thr_sat(3), C.I.chatter);
    end

    G.pass = G.det_ok && G.u_ok && G.gamma_ok && G.cte_ok && G.settle_ok && ...
        G.acq_ok && G.peak_ok && G.act_ok && G.yaw_roll_ok && G.sat_chatter_ok;

    if G.pass
        verdict = 'PASS';
        next_opt = 'two_repeat_production_integration_rate_limited_trim_alpha_ff';
        next_detail = ['PASS: corrected e_gamma gates clear on two deterministic repeats. ', ...
            'Recommend SEPARATE production integration of rate-limited trim-alpha (2deg/s).'];
    else
        verdict = 'FAIL';
        reasons = {};
        if ~G.det_ok; reasons{end+1} = 'repeats non-deterministic'; end
        if ~G.u_ok; reasons{end+1} = 'u MAE/p95'; end
        if ~G.gamma_ok; reasons{end+1} = 'steady gamma <5% vs P or <10% vs U'; end
        if ~G.cte_ok; reasons{end+1} = 'steady CTE <5% vs P or <10% vs U'; end
        if ~G.settle_ok; reasons{end+1} = 'persistent settling not improve vs P'; end
        if ~G.acq_ok; reasons{end+1} = 'acq MAE not improve vs P'; end
        if ~G.peak_ok; reasons{end+1} = 'dip/p95/max >2% worse vs P'; end
        if ~G.act_ok; reasons{end+1} = 'actuator RMS/rate >2% worse vs P'; end
        if ~G.yaw_roll_ok; reasons{end+1} = 'yaw/roll >2% worse vs P'; end
        if ~G.sat_chatter_ok; reasons{end+1} = 'sat/chatter'; end
        next_opt = 'alpha_cmd_soft_start_cosine_1deg_s';
        next_detail = ['FAIL leave production unchanged. Fail: ', strjoin(reasons, ', '), ...
            '. One final bounded reference shaper: alpha_cmd soft-start cosine envelope ', ...
            'with |dα/dt|≤1deg/s (half of current 2deg/s); hold schedule/gains fixed; stop further shaping.'];
    end
    evidence{end+1} = sprintf('gates det/u/γ/CTE/set/acq/peak/act/yr/sat=%d/%d/%d/%d/%d/%d/%d/%d/%d/%d', ...
        G.det_ok, G.u_ok, G.gamma_ok, G.cte_ok, G.settle_ok, G.acq_ok, G.peak_ok, ...
        G.act_ok, G.yaw_roll_ok, G.sat_chatter_ok);
end

%% ===================== numeric rules =====================
function ok = within_tol(cand, base, rel, abs_eps)
    if ~(isfinite(cand) && isfinite(base)); ok = false; return; end
    if abs(base) <= abs_eps
        ok = cand <= base + abs_eps;
        return;
    end
    ok = cand <= base + max(abs_eps, rel * abs(base));
end

function ok = le_improve(cand, base, frac, abs_eps)
    if ~(isfinite(cand) && isfinite(base)); ok = false; return; end
    if abs(base) <= abs_eps
        ok = cand <= base + abs_eps;
        return;
    end
    ok = cand <= (1 - frac) * base + 1e-12;
end

function ok = improves_or_eq(cand, base, abs_eps)
    if ~isfinite(base)
        ok = isfinite(cand); return;
    end
    if ~isfinite(cand); ok = false; return; end
    if abs(base) <= abs_eps
        ok = cand <= base + abs_eps; return;
    end
    ok = cand <= base + abs_eps;
end

function pct = improve_pct(base, cand, abs_eps)
    if ~(isfinite(base) && isfinite(cand)); pct = NaN; return; end
    if abs(base) <= abs_eps; pct = NaN; return; end
    pct = 100 * (base - cand) / abs(base);
end

%% ===================== PNG / MD / append =====================
function write_png(png_path, Res, lim, task_id, verdict, band_deg)
    fig = figure('Visible', 'off', 'Color', 'w', 'Position', [20 20 1700 1400]);
    try
        names = {'X', 'XZ', 'H'}; titles = {'X', 'XZ', 'R10'};
        for i = 1:3
            nm = names{i};
            P = Res.P.(nm); U = Res.U.(nm); C = Res.C.(nm);
            Sp = P.S; Su = U.S; Sc = C.S;
            Mp = P.M; Mu = U.M; Mc = C.M;

            % Row1: gamma ref/act
            subplot(5, 3, i);
            plot(Sc.t, rad2deg(Mc.ts.gamma_ref), 'k--', 'LineWidth', 1); hold on;
            plot(Sp.t, rad2deg(Mp.ts.gamma_act), 'b:');
            plot(Su.t, rad2deg(Mu.ts.gamma_act), 'm');
            plot(Sc.t, rad2deg(Mc.ts.gamma_act), 'r', 'LineWidth', 1.1);
            grid on; ylabel('\gamma [deg]');
            title(sprintf('%s | %s', titles{i}, verdict));
            if i == 1; legend('\gamma_{ref}','P','U','C','Location','best'); end

            % Row2: e_gamma + attitude error
            subplot(5, 3, 3 + i);
            plot(Sc.t, rad2deg(Mc.ts.e_gamma), 'r', 'LineWidth', 1.1); hold on;
            plot(Sp.t, rad2deg(Mp.ts.e_gamma), 'b:');
            plot(Sc.t, rad2deg(Mc.ts.e_th_att), 'g:');
            yline(band_deg, 'k--'); yline(-band_deg, 'k--');
            grid on; ylabel('err [deg]');
            title(sprintf('e_\\gamma / e_\\theta_{att} band\\pm%.1f', band_deg));
            if i == 1; legend('e_\gamma C','e_\gamma P','e_\theta C','Location','best'); end

            % Row3: speed u
            subplot(5, 3, 6 + i);
            plot(Sp.t, Sp.u_body, 'b:'); hold on;
            plot(Su.t, Su.u_body, 'm');
            plot(Sc.t, Sc.u_body, 'r', 'LineWidth', 1.1);
            plot(Sc.t, Sc.u_ref, 'k--');
            grid on; ylabel('u [m/s]');
            if i == 1; legend('u_P','u_U','u_C','u_{ref}','Location','best'); end

            % Row4: rates q/p/r + actuators
            subplot(5, 3, 9 + i);
            plot(Sc.t, rad2deg(Sc.rates(:,2)), 'r'); hold on;
            plot(Sc.t, rad2deg(Sc.rates(:,1)), 'b');
            plot(Sc.t, rad2deg(Sc.rates(:,3)), 'g');
            plot(Sc.t, rad2deg(Sc.delta_e), 'k', 'LineWidth', 1.0);
            plot(Sc.t, rad2deg(Sc.delta_r), 'm:');
            yline(rad2deg(lim.de_max), 'k--');
            grid on; ylabel('q/p/r/de/dr [deg]');
            if i == 1; legend('q','p','r','de','dr','Location','best'); end

            % Row5: path / CTE
            subplot(5, 3, 12 + i);
            plot(Sp.t, Mp.ts.cte_perp, 'b:'); hold on;
            plot(Su.t, Mu.ts.cte_perp, 'm');
            plot(Sc.t, Mc.ts.cte_perp, 'r', 'LineWidth', 1.1);
            if isfield(Sc, 'alpha_cmd')
                yyaxis right;
                plot(Sc.t, rad2deg(Sc.alpha_cmd), 'c');
                plot(Sc.t, rad2deg(Sc.alpha_ff_target), 'c:');
                ylabel('\alpha_{cmd/tgt} [deg]');
                yyaxis left;
            end
            ylabel('CTE [m]'); xlabel('t [s]'); grid on;
            if i == 1; legend('CTE_P','CTE_U','CTE_C','Location','best'); end
        end
        sgtitle(sprintf('%s — corrected e_\\gamma closure | %s', task_id, verdict), ...
            'Interpreter', 'none');
        exportgraphics(fig, png_path, 'Resolution', 140);
    catch ME
        fprintf('PNG warn: %s\n', ME.message);
    end
    close(fig);
end

function write_md(md_path, task_id, verdict, law, Sched, Res, G, Rdet, evidence, ...
        next_opt, next_detail, seed, band_deg, end_frac, t_acq, ...
        rl_path, audit_path, sched_path, cand_path, md_out, mat_out, png_out)

    fid = fopen(md_path, 'w');
    assert(fid > 0);
    fprintf(fid, '# %s — Two-repeat corrected e_gamma closure\n\n', task_id);
    fprintf(fid, '**Overall verdict: %s**\n\n', verdict);

    fprintf(fid, '## Provenance\n\n');
    fprintf(fid, '- Read-only: `%s`, `%s`, `%s`\n', rl_path, audit_path, sched_path);
    fprintf(fid, '- Isolated helper: `%s` (production guidance untouched)\n', cand_path);
    fprintf(fid, '- Driver: `run_trim_alpha_two_repeat_closure.m` (one invocation)\n');
    fprintf(fid, '- Artifacts: `%s`, `%s`, `%s`\n', md_out, mat_out, png_out);
    fprintf(fid, '- Seed: %d | two repeats | P/U loaded from RATE_LIMIT; candidate re-simulated\n\n', seed);

    fprintf(fid, '## Corrected definitions\n\n');
    fprintf(fid, '```\n');
    fprintf(fid, 'e_gamma = wrapToPi(gamma_ref - gamma_act); gamma_act=atan2(VD,Uh)\n');
    fprintf(fid, 'persistent settle: |e_gamma|<=+/-%.2fdeg through %.2f*s_total\n', band_deg, end_frac);
    fprintf(fid, 'acquisition: fixed first %.1fs & s<%.2f*s_total (+ persistent window reported)\n', t_acq, end_frac);
    fprintf(fid, 'steady: t>=%.1fs & s<%.2f*s_total (last valid path segment)\n', t_acq, end_frac);
    fprintf(fid, 'OS = signed excursion of gamma_act past mean(gamma_ref|ss) during fixed acq\n');
    fprintf(fid, 'dip = opposite early excursion; attitude e_theta reported separately\n');
    fprintf(fid, 'actuators: identical fixed acq/steady masks; roll: own-speed phi_eq\n');
    fprintf(fid, 'Candidate: alpha_ff=c0/u^2+c_g*gamma; |d alpha_cmd/dt|<=2deg/s; Kz=.04 Ki=0; speed PI+FF\n');
    fprintf(fid, 'c0=%.12g c_gamma=%.12g | kD=%.10f Kp=%.4g Ki=%.8f\n', ...
        Sched.c0, Sched.c_gamma, law.kD, law.Kp, law.Ki);
    fprintf(fid, 'Zeros: within_tol / improve use absolute eps — no %% on ~0 base\n');
    fprintf(fid, '```\n\n');

    fprintf(fid, '## Determinism\n\n');
    fprintf(fid, '| Route | ok | d_u | d_γMAE | d_θref | d_de |\n');
    fprintf(fid, '|-------|:--:|----:|-------:|-------:|-----:|\n');
    names = {'X','XZ','H'};
    for i = 1:3
        nm = names{i}; d = Rdet.(nm);
        fprintf(fid, '| %s | %s | %.3e | %.3e | %.3e | %.3e |\n', ...
            G.rows.(nm).label, yn(d.ok), d.d_u, d.d_g, d.d_th, d.d_de);
    end
    fprintf(fid, '\nOverall repeats: **%s**\n\n', tern(Rdet.pass, 'PASS', 'FAIL'));

    fprintf(fid, '## Corrected table — P / U / C (candidate)\n\n');
    fprintf(fid, '| Route | uMAE | uP95 | γMAE_ss° | γΔ%%P/U | CTE | CTEΔ%%P/U | settle[s] | acqMAE° | OS° | dip° | acq RMS/p95/max° |\n');
    fprintf(fid, '|-------|-----:|-----:|---------:|--------:|----:|---------:|----------:|--------:|----:|-----:|-----------------:|\n');
    for i = 1:3
        r = G.rows.(names{i});
        fprintf(fid, ['| %s | %.4f/%.4f/%.4f | %.4f | %.3f/%.3f/%.3f | %+.1f/%+.1f | ', ...
            '%.4f/%.4f/%.4f | %+.1f/%+.1f | %.3f/%.3f/%.3f | %.3f/%.3f/%.3f | ', ...
            '%.3f/%.3f/%.3f | %.3f/%.3f/%.3f | %.3f/%.3f/%.3f |\n'], ...
            r.label, r.u_mae(1), r.u_mae(2), r.u_mae(3), r.u_p95(3), ...
            r.g_mae(1), r.g_mae(2), r.g_mae(3), r.g_imp_P, r.g_imp_U, ...
            r.cte(1), r.cte(2), r.cte(3), r.cte_imp_P, r.cte_imp_U, ...
            r.settle(1), r.settle(2), r.settle(3), ...
            r.acq_mae(1), r.acq_mae(2), r.acq_mae(3), ...
            r.os(1), r.os(2), r.os(3), r.dip(1), r.dip(2), r.dip(3), ...
            r.acq_rms(3), r.acq_p95(3), r.acq_max(3));
    end

    fprintf(fid, '\n## Attitude (separate) / own-eq roll / actuators\n\n');
    fprintf(fid, '| Route | θsettle P/U/C | θMAE_ss | yaw P→C | ownT P→C | φeq° | deR_ss P→C | deR_acq | drR_ss | satT%% | chatter |\n');
    fprintf(fid, '|-------|--------------:|--------:|--------:|---------:|-----:|-----------:|--------:|-------:|------:|:-------:|\n');
    for i = 1:3
        nm = names{i}; r = G.rows.(nm); C = Res.C.(nm).M;
        fprintf(fid, '| %s | %.3f/%.3f/%.3f | %.3f/%.3f/%.3f | %.4f→%.4f | %.4f→%.4f | %.3f | %.4g→%.4g | %.4g→%.4g | %.4g→%.4g | %.2f | %s |\n', ...
            r.label, r.th_set(1), r.th_set(2), r.th_set(3), ...
            r.th_mae(1), r.th_mae(2), r.th_mae(3), ...
            r.yaw(1), r.yaw(3), r.own_t(1), r.own_t(3), r.own_eq(3), ...
            r.de_rate(1), r.de_rate(3), r.de_rate_acq(1), r.de_rate_acq(3), ...
            r.dr_rate(1), r.dr_rate(3), r.thr_sat(3), yn(~C.I.chatter));
    end

    fprintf(fid, '\n## Gate table\n\n');
    fprintf(fid, '| Gate | Result | Detail |\n');
    fprintf(fid, '|------|:------:|--------|\n');
    fprintf(fid, '| Repeats deterministic | %s | |\n', yn(G.det_ok));
    fprintf(fid, '| u MAE≤0.07 p95≤0.10 | %s | X=%s XZ=%s H=%s |\n', ...
        yn(G.u_ok), yn(G.rows.X.u_gate), yn(G.rows.XZ.u_gate), yn(G.rows.H.u_gate));
    fprintf(fid, '| Steady γ ≥5%% vs P and ≥10%% vs U | %s | X ΔP/U=%+.1f/%+.1f XZ=%+.1f/%+.1f H=%+.1f/%+.1f |\n', ...
        yn(G.gamma_ok), G.rows.X.g_imp_P, G.rows.X.g_imp_U, ...
        G.rows.XZ.g_imp_P, G.rows.XZ.g_imp_U, G.rows.H.g_imp_P, G.rows.H.g_imp_U);
    fprintf(fid, '| Steady CTE ≥5%% vs P and ≥10%% vs U | %s | X ΔP/U=%+.1f/%+.1f XZ=%+.1f/%+.1f H=%+.1f/%+.1f |\n', ...
        yn(G.cte_ok), G.rows.X.cte_imp_P, G.rows.X.cte_imp_U, ...
        G.rows.XZ.cte_imp_P, G.rows.XZ.cte_imp_U, G.rows.H.cte_imp_P, G.rows.H.cte_imp_U);
    fprintf(fid, '| Persistent settling improve each route | %s | X/XZ/H setΔ=%+.1f/%+.1f/%+.1f%% |\n', ...
        yn(G.settle_ok), G.rows.X.set_imp_P, G.rows.XZ.set_imp_P, G.rows.H.set_imp_P);
    fprintf(fid, '| Acq MAE improve each route | %s | X/XZ/H acqΔ=%+.1f/%+.1f/%+.1f%% |\n', ...
        yn(G.acq_ok), G.rows.X.acq_imp_P, G.rows.XZ.acq_imp_P, G.rows.H.acq_imp_P);
    fprintf(fid, '| dip/p95/max not >2%% worse vs P | %s | |\n', yn(G.peak_ok));
    fprintf(fid, '| Actuator RMS/rate not >2%% worse | %s | |\n', yn(G.act_ok));
    fprintf(fid, '| Yaw/roll not >2%% worse (own-eq) | %s | |\n', yn(G.yaw_roll_ok));
    fprintf(fid, '| Sat≤1%% / no chatter | %s | |\n', yn(G.sat_chatter_ok));

    fprintf(fid, '\n## Evidence\n\n');
    for k = 1:numel(evidence)
        fprintf(fid, '- %s\n', evidence{k});
    end

    fprintf(fid, '\n## Decision\n\n');
    fprintf(fid, '- Verdict: **%s**\n', verdict);
    fprintf(fid, '- Next: `%s`\n', next_opt);
    fprintf(fid, '- Detail: %s\n', next_detail);
    fprintf(fid, '- Production: untouched\n\n');

    fprintf(fid, '## Feedback\n\n');
    fprintf(fid, '- PASS/FAIL: **%s**\n', verdict);
    fprintf(fid, '- Corrected γMAE° P/U/C: X %.3f/%.3f/%.3f | XZ %.3f/%.3f/%.3f | R10 %.3f/%.3f/%.3f\n', ...
        G.rows.X.g_mae(1), G.rows.X.g_mae(2), G.rows.X.g_mae(3), ...
        G.rows.XZ.g_mae(1), G.rows.XZ.g_mae(2), G.rows.XZ.g_mae(3), ...
        G.rows.H.g_mae(1), G.rows.H.g_mae(2), G.rows.H.g_mae(3));
    fprintf(fid, '- Files: `%s` `%s` `%s`\n', md_out, mat_out, png_out);
    fprintf(fid, '- Next: `%s`\n', next_opt);
    fclose(fid);
end

function append_ss_audit(out_dir, task_id, verdict, law, Sched, Res, G, Rdet, ...
        next_opt, next_detail, md_path, mat_path, png_path, band_deg) %#ok<INUSD>
    audit_path = fullfile(out_dir, 'STATE_SPACE_MODEL_AUDIT.md');
    fid = fopen(audit_path, 'a');
    assert(fid > 0);
    fprintf(fid, '\n\n---\n\n');
    fprintf(fid, '## %s — %s\n\n', task_id, datestr(now, 'yyyy-mm-dd HH:MM:SS'));
    fprintf(fid, '### Provenance\n\n');
    fprintf(fid, '- Read-only: `TRIM_ALPHA_FF_RATE_LIMIT.mat`, `TRIM_ALPHA_TRANSIENT_GATE_AUDIT.mat`, `TRIM_ALPHA_SCHEDULE_ID.mat`\n');
    fprintf(fid, '- Isolated helper: `guidance_law_trim_alpha_ff_rate_limit.m` (production untouched)\n');
    fprintf(fid, '- Driver: `run_trim_alpha_two_repeat_closure.m` (one invocation)\n');
    fprintf(fid, '- Artifacts: `%s`, `%s`, `%s`\n\n', md_path, mat_path, png_path);

    fprintf(fid, '### Corrected metrics\n\n');
    fprintf(fid, '```\n');
    fprintf(fid, 'e_gamma persistent +/-%.2fdeg | fixed acq t<5s | steady t>=5 & s<0.88s_tot\n', band_deg);
    fprintf(fid, 'OS vs mean(gamma_ref|ss) | actuators identical fixed masks | own-eq roll\n');
    fprintf(fid, 'alpha_cmd |dα/dt|<=2deg/s | Kz=.04 Ki=0 | speed PI+FF kD=%.10f\n', law.kD);
    fprintf(fid, '```\n\n');

    fprintf(fid, '### Corrected table (P/U/C)\n\n');
    fprintf(fid, '| Route | uMAE | γMAE° | CTE | settle | acqMAE | OS | dip | γΔ%%P/U |\n');
    fprintf(fid, '|-------|-----:|------:|----:|-------:|-------:|---:|----:|--------:|\n');
    names = {'X','XZ','H'};
    for i = 1:3
        r = G.rows.(names{i});
        fprintf(fid, '| %s | %.4f/%.4f/%.4f | %.3f/%.3f/%.3f | %.4f/%.4f/%.4f | %.3f→%.3f | %.3f→%.3f | %.3f→%.3f | %.3f→%.3f | %+.1f/%+.1f |\n', ...
            r.label, r.u_mae(1), r.u_mae(2), r.u_mae(3), ...
            r.g_mae(1), r.g_mae(2), r.g_mae(3), ...
            r.cte(1), r.cte(2), r.cte(3), ...
            r.settle(1), r.settle(3), r.acq_mae(1), r.acq_mae(3), ...
            r.os(1), r.os(3), r.dip(1), r.dip(3), r.g_imp_P, r.g_imp_U);
    end

    fprintf(fid, '\n### Verdict / next\n\n');
    fprintf(fid, '- Verdict: **%s** | Determinism: **%s**\n', verdict, tern(Rdet.pass, 'PASS', 'FAIL'));
    fprintf(fid, '- Gates det/u/γ/CTE/set/acq/peak/act/yr/sat: %s/%s/%s/%s/%s/%s/%s/%s/%s/%s\n', ...
        yn(G.det_ok), yn(G.u_ok), yn(G.gamma_ok), yn(G.cte_ok), yn(G.settle_ok), ...
        yn(G.acq_ok), yn(G.peak_ok), yn(G.act_ok), yn(G.yaw_roll_ok), yn(G.sat_chatter_ok));
    fprintf(fid, '- Next: `%s` — %s\n', next_opt, next_detail);
    fprintf(fid, '- Production: untouched\n');

    fprintf(fid, '\n### Next\n\n');
    fprintf(fid, '- %s\n', next_opt);
    fclose(fid);
end

function print_feedback(verdict, Res, G, Rdet, evidence, next_opt, next_detail, md, mat, png) %#ok<INUSD>
    fprintf('\n========== FEEDBACK ==========\n');
    fprintf('PASS/FAIL: %s\n', verdict);
    fprintf('Determinism: %s\n', tern(Rdet.pass, 'PASS', 'FAIL'));
    fprintf('Corrected γMAE° P/U/C: X %.3f/%.3f/%.3f | XZ %.3f/%.3f/%.3f | R10 %.3f/%.3f/%.3f\n', ...
        G.rows.X.g_mae(1), G.rows.X.g_mae(2), G.rows.X.g_mae(3), ...
        G.rows.XZ.g_mae(1), G.rows.XZ.g_mae(2), G.rows.XZ.g_mae(3), ...
        G.rows.H.g_mae(1), G.rows.H.g_mae(2), G.rows.H.g_mae(3));
    fprintf('Settle P→C: X %.3f→%.3f | XZ %.3f→%.3f | R10 %.3f→%.3f\n', ...
        G.rows.X.settle(1), G.rows.X.settle(3), ...
        G.rows.XZ.settle(1), G.rows.XZ.settle(3), ...
        G.rows.H.settle(1), G.rows.H.settle(3));
    fprintf('AcqMAE P→C: X %.3f→%.3f | XZ %.3f→%.3f | R10 %.3f→%.3f\n', ...
        G.rows.X.acq_mae(1), G.rows.X.acq_mae(3), ...
        G.rows.XZ.acq_mae(1), G.rows.XZ.acq_mae(3), ...
        G.rows.H.acq_mae(1), G.rows.H.acq_mae(3));
    fprintf('uMAE C: X %.4f XZ %.4f R10 %.4f | gates det/u/γ/CTE/set/acq/peak/act/yr/sat=%s/%s/%s/%s/%s/%s/%s/%s/%s/%s\n', ...
        G.rows.X.u_mae(3), G.rows.XZ.u_mae(3), G.rows.H.u_mae(3), ...
        yn(G.det_ok), yn(G.u_ok), yn(G.gamma_ok), yn(G.cte_ok), yn(G.settle_ok), ...
        yn(G.acq_ok), yn(G.peak_ok), yn(G.act_ok), yn(G.yaw_roll_ok), yn(G.sat_chatter_ok));
    fprintf('Evidence[1]: %s\n', evidence{1});
    fprintf('Files: %s | %s | %s\n', md, mat, png);
    fprintf('Next: %s — %s\n', next_opt, next_detail);
end

%% ===================== kinematics / helpers =====================
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
function s = tern(tf, a, b)
    if tf; s = a; else; s = b; end
end
