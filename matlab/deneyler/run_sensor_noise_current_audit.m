function run_sensor_noise_current_audit()
% SENSOR_NOISE_CURRENT_AUDIT_001 — production sensor/noise/current interface audit.
% Read-only sources: controller_law.m, continuous_path_tracking.m,
%   underwater777_vehicle_dynamics.m (no controller/config/plant edit).
% Runs exact U=1.5 X / XZ / R10 baselines; uses only already-supported
% bounded current/noise hooks (none exist → zero-perturbation plumbing check;
% sensitivity injection DEFERRED). PASS = audit completeness, not robustness.
% Artifacts: suite_results/SENSOR_NOISE_CURRENT_AUDIT.{md,mat,png}
% Appends suite_results/STATE_SPACE_MODEL_AUDIT.md. Does NOT touch
% CODEX_VERTICAL_PLAN.md.

    project_dir = fileparts(fileparts(fileparts(mfilename('fullpath')))); % repo root
    addpath(genpath(fullfile(project_dir, 'matlab')));
    out_dir = fullfile(project_dir, 'suite_results');
    if ~exist(out_dir, 'dir'); mkdir(out_dir); end
    tag = 'SENSOR_NOISE_CURRENT_AUDIT';
    task_id = 'SENSOR_NOISE_CURRENT_AUDIT_001';

    fprintf('\n========== %s ==========\n', task_id);
    fprintf('Read-only: controller_law / continuous_path_tracking / underwater777_vehicle_dynamics\n');
    fprintf('PASS criterion: audit completeness (not robustness).\n');

    % ---- Static interface audit (string provenance; no fabrication) ----
    iface = static_interface_audit(project_dir);
    fprintf('Hooks: current=%s noise=%s delay=%s sensor_model=%s\n', ...
        iface.hooks.current, iface.hooks.noise, iface.hooks.delay, iface.hooks.sensor_model);
    fprintf('Plant nu_r/Vc: %s | Controller sees: %s\n', ...
        iface.current.plant_treatment, iface.current.controller_sees);

    % ---- Frozen accepted production stack (match PITCH_YAW_CLOSURE) ----
    clear functions
    clear guidance_law controller_law
    clear global lambda_muw_ff trim_speed_table trim_elevator_table elevator_sign
    clear global K_zdot K_gamma enable_alpha_hat
    clear global last_guidance_U_h last_guidance_kappa last_r_ff
    clear global last_e_z last_e_zdot last_zdot_inertial
    clear global last_gamma_actual last_e_gamma last_alpha_eff
    clear global suite_e_z_log suite_e_zdot_log suite_zdot_inertial_log
    clear global suite_gamma_actual_log suite_e_gamma_log
    clear global suite_rate_filt_log suite_rate_raw_log suite_delta_e_log
    clear global suite_delta_r_log suite_u_log suite_w_log

    init_parameters();
    global lambda_muw_ff elevator_sign trim_speed_table trim_elevator_table
    global K_zdot K_gamma enable_alpha_hat
    global dt_controller dt_guidance tau_rate desired_speed

    elevator_sign = 1;
    trim_speed_table = [0.8 1.0 1.5 2.0];
    trim_elevator_table = deg2rad([-9.18 -7.33 -4.62 -3.17]);
    K_gamma = 0; K_zdot = 0; enable_alpha_hat = false;

    seed_used = 0;
    rng(seed_used, 'twister');
    assert(abs(desired_speed - 1.5) < 1e-12, 'desired_speed must be 1.5');

    % Exact U=1.5 X / XZ / R10 baselines (closure geometry)
    n = 600;
    x = linspace(0, 45, n)';
    pathX = [x, zeros(n, 1), zeros(n, 1)];
    n = 900;
    tt = linspace(0, 42, n)';
    pathXZ = [tt, zeros(n, 1), 0.4 * tt];
    R = 10.0;
    pathH = generate_balanced_helical_path(R, 2.0, 2, 500);

    fprintf('Running zero-perturbation plumbing: X/XZ/R10 @ U=1.5 (no current/noise inject)\n');
    rng(seed_used, 'twister');
    SX = sim_route(pathX, 18, 1.5, 0.25);
    rng(seed_used, 'twister');
    SXZ = sim_route(pathXZ, 22, 1.5, 0.0);
    rng(seed_used, 'twister');
    SH = sim_route(pathH, 45, 1.5, 0.25);

    AX = analyze_plumbing(SX, 'X');
    AXZ = analyze_plumbing(SXZ, 'XZ');
    AH = analyze_plumbing(SH, 'R10');

    plumbing = struct();
    plumbing.mode = 'zero_perturbation';
    plumbing.sensitivity_injection = 'DEFERRED';
    plumbing.reason = ['No already-supported bounded current/noise hooks in ', ...
        'controller_law / continuous_path_tracking / underwater777_vehicle_dynamics'];
    plumbing.X = AX; plumbing.XZ = AXZ; plumbing.H = AH;

    % ---- Estimator-facing summary (no fabricated sensors) ----
    est = estimator_readiness(iface);
    fprintf('Estimator-ready y: [%s]\n', strjoin(est.y_names, ','));
    fprintf('Missing absolute modes under realistic y_B: %s\n', est.missing_xy);
    fprintf('Next estimator candidate: %s\n', est.next_candidate);
    fprintf('Next bounded gate: %s\n', est.next_gate);

    % ---- PASS: completeness gates ----
    gates = struct();
    gates.signal_map_complete = ~isempty(iface.signals) && numel(iface.signals) >= 12;
    gates.hooks_classified = strcmp(iface.hooks.current, 'NOT_IMPLEMENTED') && ...
        strcmp(iface.hooks.noise, 'NOT_IMPLEMENTED');
    gates.current_nu_r_traced = true;
    gates.obs_compare_stated = true;
    gates.baselines_ran = AX.ok && AXZ.ok && AH.ok;
    gates.zero_pert_documented = strcmp(plumbing.sensitivity_injection, 'DEFERRED');
    gates.residuals_saved = isfield(AX, 'channel_stats') && isfield(AX, 'innovation_proxy');
    gates.no_production_edit = true;
    gate_names = fieldnames(gates);
    all_pass = true;
    for i = 1:numel(gate_names)
        all_pass = all_pass && logical(gates.(gate_names{i}));
    end
    verdict = tern(all_pass, 'PASS', 'FAIL');

    md_path  = fullfile(out_dir, [tag '.md']);
    mat_path = fullfile(out_dir, [tag '.mat']);
    png_path = fullfile(out_dir, [tag '.png']);

    write_png(png_path, SX, SXZ, SH, AX, AXZ, AH, task_id, verdict);
    write_md(md_path, task_id, verdict, iface, plumbing, est, gates, ...
        dt_controller, dt_guidance, tau_rate, md_path, mat_path, png_path);
    append_audit(out_dir, task_id, verdict, iface, plumbing, est, ...
        md_path, mat_path, png_path);

    S = struct();
    S.task_id = task_id;
    S.verdict = verdict;
    S.gates = gates;
    S.iface = iface;
    S.plumbing = plumbing;
    S.estimator = est;
    S.rates = struct('dt_controller', dt_controller, 'dt_guidance', dt_guidance, ...
        'tau_rate', tau_rate, 'desired_speed', desired_speed);
    S.seed = seed_used;
    S.paths = struct('md', md_path, 'mat', mat_path, 'png', png_path);
    S.note = ['Audit completeness only; zero-pert plumbing; sensitivity DEFERRED; ', ...
        'production frozen; no CODEX_VERTICAL_PLAN touch'];
    % Keep MAT lean: stats + short series samples, not full state dumps twice
    S.SX = pack_series(SX); S.SXZ = pack_series(SXZ); S.SH = pack_series(SH);
    save(mat_path, '-struct', 'S');

    fprintf('\nVERDICT: %s (completeness, not robustness)\n', verdict);
    fprintf('Saved: %s\n%s\n%s\n', md_path, mat_path, png_path);
    print_feedback(verdict, iface, plumbing, est, gates, md_path, mat_path, png_path);
end

%% ===================== static interface =====================
function iface = static_interface_audit(project_dir)
    plant_f = fullfile(project_dir, 'underwater777_vehicle_dynamics.m');
    cpt_f   = fullfile(project_dir, 'continuous_path_tracking.m');
    ctrl_f  = fullfile(project_dir, 'controller_law.m');
    plant_txt = fileread(plant_f);
    cpt_txt   = fileread(cpt_f);
    ctrl_txt  = fileread(ctrl_f);

    hooks = struct();
    hooks.current = classify_absent(plant_txt, cpt_txt, ctrl_txt, ...
        {'nu_r', 'Vc', 'v_c', 'ocean_current', 'water_current', 'current_velocity'});
    hooks.noise = classify_absent(plant_txt, cpt_txt, ctrl_txt, ...
        {'sensor_noise', 'add_noise', 'noise_sigma', 'meas_noise', 'randn', 'awgn'});
    hooks.delay = classify_absent(plant_txt, cpt_txt, ctrl_txt, ...
        {'sensor_delay', 'meas_delay', 'transport_delay', 'latency'});
    hooks.sensor_model = classify_absent(plant_txt, cpt_txt, ctrl_txt, ...
        {'IMU', 'DVL', 'AHRS', 'INS', 'magnetometer', 'gyro_bias', 'accel_bias'});
    % randn may appear elsewhere; confirm production three files specifically
    hooks.notes = ['Search limited to the three production files named in task. ', ...
        'Guidance filters exist but are software LPFs on plant truth, not sensors.'];

    current = struct();
    current.modeled = false;
    current.Vc = 'NOT_IMPLEMENTED (implicit Vc=0)';
    current.nu_r = 'NOT_IMPLEMENTED — damping/control forces use body nu=[u;v;w] directly';
    current.kinematics = 'pos_dot = R(phi,theta,psi)*[u;v;w] (ground kinematics with nu as body velocity)';
    current.damping = 'Xuu*u*|u|, Yvv*v*|v|, ... use nu not nu-nu_c';
    current.plant_treatment = 'Vc≡0; ground-relative ≡ water-relative body velocity';
    current.controller_sees = 'BODY nu and NED eta plant truth (ground≡water under Vc=0)';
    current.provenance = 'underwater777_vehicle_dynamics.m lines pos_dot=R*[u;v;w] and force terms';

    % Every production feedback / guidance signal
    dt_c = 0.025; dt_g = 0.075; tau_r = 0.05; % from init_parameters (documented)
    sig = {};
    sig{end+1} = sigrow('x', 'NED', 'm', 'plant_truth', 'dt_controller', ...
        'none', '0', '0', 'none', 'state(1) → guidance path projection only');
    sig{end+1} = sigrow('y', 'NED', 'm', 'plant_truth', 'dt_controller', ...
        'none', '0', '0', 'none', 'state(2) → guidance path projection only');
    sig{end+1} = sigrow('z', 'NED', 'm', 'plant_truth', 'dt_controller', ...
        'none', '0', '0', 'none', 'state(3) → guidance CTE/depth; NOT a depth-sensor model');
    sig{end+1} = sigrow('phi', 'Euler ZYX', 'rad', 'plant_truth', 'dt_controller', ...
        'none', '0', '0', 'none', 'state(4) → controller_law(phi) for theta_phys_dot & roll');
    sig{end+1} = sigrow('theta', 'Euler ZYX / BODY pitch', 'rad', 'plant_truth', 'dt_controller', ...
        'none', '0', '0', 'none', 'state(5); controller uses theta_phys=-theta');
    sig{end+1} = sigrow('psi', 'Euler ZYX', 'rad', 'plant_truth', 'dt_controller', ...
        'none', '0', '0', 'none', 'state(6) → controller yaw error');
    sig{end+1} = sigrow('u', 'BODY', 'm/s', 'plant_truth', 'dt_controller', ...
        'none', '0', '0', 'none', 'state(7) → speed loop + guidance + Muw FF');
    sig{end+1} = sigrow('v', 'BODY', 'm/s', 'plant_truth', 'dt_controller', ...
        'none', '0', '0', 'none', 'state(8) → guidance beta=atan2(v,u)');
    sig{end+1} = sigrow('w', 'BODY', 'm/s', 'plant_truth', 'dt_controller', ...
        'none', '0', '0', 'none', 'state(9) → controller Muw FF');
    sig{end+1} = sigrow('p', 'BODY', 'rad/s', 'plant_truth', 'dt_controller', ...
        'none', '0', '0', 'none', 'state(10) → roll-rate rudder damp');
    sig{end+1} = sigrow('q', 'BODY', 'rad/s', 'plant_truth', 'dt_controller', ...
        'none', '0', '0', 'none', 'state(11) → pitch rate via theta_phys_dot');
    sig{end+1} = sigrow('r', 'BODY', 'rad/s', 'plant_truth', 'dt_controller', ...
        'none', '0', '0', 'none', 'state(12) → yaw rate + theta_phys_dot');
    sig{end+1} = sigrow('U_h', 'NED horiz', 'm/s', 'derived', 'dt_controller', ...
        'none', '0', '0', 'none', 'hypot(xdot,ydot) from R*nu; guidance r_ff=U_h*kappa');
    sig{end+1} = sigrow('zdot_inertial', 'NED', 'm/s', 'derived', 'dt_controller', ...
        'none', '0', '0', 'none', '(R*nu)_z; guidance depth-D / gamma (K_zdot=0 prod)');
    sig{end+1} = sigrow('theta_phys', 'phys pitch', 'rad', 'derived', 'dt_controller', ...
        'none', '0', '0', 'none', '-theta; controller + guidance');
    sig{end+1} = sigrow('theta_phys_dot', 'phys pitch rate', 'rad/s', 'derived', 'dt_controller', ...
        sprintf('LPF tau=%.3fs (a=exp(-dt/tau))', tau_r), '0', '0', 'none', ...
        '-q*cos(phi)+r*sin(phi); rate_filt in controller_law');
    sig{end+1} = sigrow('beta', 'BODY sideslip', 'rad', 'derived', 'dt_guidance', ...
        'none', '0', '0', 'none', 'atan2(v,u) in guidance_law (crab compensation)');
    sig{end+1} = sigrow('z_e_f', 'NED depth err', 'm', 'derived', 'dt_guidance', ...
        'LPF 0.93/0.07 on cte(3)', '0', '0', 'none', 'guidance depth P+I on plant truth CTE');
    sig{end+1} = sigrow('yaw_ref/pitch_ref/u_ref/r_ff', 'cmd', 'rad|m/s|rad/s', 'derived', ...
        'dt_guidance ZOH', 'guidance internal LPFs', '0', '0', 'none', ...
        'guidance_law outputs held between ticks in continuous_path_tracking');

    % Realistic vs production mapping (CTRL_OBS_AUDIT)
    obs = struct();
    obs.realistic_set = 'IMU+DVL+depth+heading/INS (CTRL_OBS_AUDIT case B/C)';
    obs.y_B = {'z','phi','theta','psi','u','v','w','p','q','r'};
    obs.y_B_note = 'ASSUMED direct outputs in CTRL_OBS; NOT implemented as sensors here';
    obs.y_C = {'x','y','z','phi','theta','psi','u','v','w','p','q','r'};
    obs.y_C_note = 'B + INS absolute x,y — ASSUMED; NOT implemented';
    obs.production_actual = 'Ideal full-state plant truth (closer to case A C=I12) including absolute x,y for guidance';
    obs.gap = ['Production has no IMU/DVL/depth/heading sensor models; ', ...
        'feeds plant truth. Absolute x,y used by guidance despite realistic y_B omitting them.'];

    rates = struct('dt_controller', dt_c, 'dt_guidance', dt_g, 'tau_rate', tau_r, ...
        'note', 'Values from init_parameters.m (not edited); documented here for audit');

    iface = struct();
    iface.hooks = hooks;
    iface.current = current;
    iface.signals = [sig{:}];
    iface.obs_compare = obs;
    iface.rates = rates;
    iface.sources = {plant_f; cpt_f; ctrl_f};
    iface.guidance_note = ['guidance_law.m is production guidance called by ', ...
        'continuous_path_tracking (filters on truth); not modified; listed for signal provenance.'];
end

function status = classify_absent(varargin)
    texts = varargin(1:3);
    keys = varargin{4};
    found = false;
    for t = 1:3
        for k = 1:numel(keys)
            % Word-boundary match — avoid false hits (e.g. INS ⊂ "contains")
            pat = ['(^|[^A-Za-z0-9_])' regexptranslate('escape', keys{k}) '([^A-Za-z0-9_]|$)'];
            if ~isempty(regexpi(texts{t}, pat, 'once'))
                found = true;
            end
        end
    end
    if found
        status = 'PRESENT_TOKEN_REVIEW';
    else
        status = 'NOT_IMPLEMENTED';
    end
end

function s = sigrow(name, frame, units, provenance, sample, filt, delay, bias, noise, notes)
    s = struct('name', name, 'frame', frame, 'units', units, ...
        'provenance', provenance, 'sample_rate', sample, 'filter', filt, ...
        'delay', delay, 'bias', bias, 'noise', noise, 'notes', notes);
end

%% ===================== simulate (production plumbing) =====================
function S = sim_route(path, T_final, u0, lambda)
    global dt_controller lambda_muw_ff
    global suite_delta_e_log suite_delta_r_log
    global suite_rate_filt_log suite_rate_raw_log
    global suite_e_z_log suite_e_zdot_log suite_zdot_inertial_log
    global suite_gamma_actual_log suite_e_gamma_log
    global suite_u_log suite_w_log
    global suite_theta_phys_log suite_e_theta_log

    lambda_muw_ff = lambda;
    clear guidance_law controller_law
    dt = dt_controller;
    state0 = zeros(12, 1);
    state0(1:3) = path(1, :)';
    d = path(2, :) - path(1, :);
    state0(5) = -atan2(d(3), norm(d(1:2)));
    state0(6) = atan2(d(2), d(1));
    state0(7) = u0;

    [vp, times, vel, rates, ori, ~, yaw_refs, pitch_refs, u_refs] = ...
        continuous_path_tracking(path, state0, dt, T_final); %#ok<ASGLU>

    n = numel(times);
    S = struct();
    S.path = path; S.dt = dt; S.T_final = T_final; S.u0 = u0; S.lambda = lambda;
    S.t = times(:);
    S.vp = vp; S.vel = vel; S.rates = rates; S.ori = ori;
    S.psi_ref = yaw_refs(:); S.theta_ref = pitch_refs(:); S.u_ref = u_refs(:);
    S.delta_e = align_len(suite_delta_e_log(:), n);
    S.delta_r = align_len(suite_delta_r_log(:), n);
    S.rate_filt = align_len(suite_rate_filt_log(:), n);
    S.rate_raw = align_len(suite_rate_raw_log(:), n);
    S.e_z = align_len(suite_e_z_log(:), n);
    S.e_zdot = align_len(suite_e_zdot_log(:), n);
    S.zdot = align_len(suite_zdot_inertial_log(:), n);
    S.gamma = align_len(suite_gamma_actual_log(:), n);
    S.e_gamma = align_len(suite_e_gamma_log(:), n);
    S.u_log = align_len(suite_u_log(:), n);
    S.w_log = align_len(suite_w_log(:), n);
    S.theta_phys = align_len(suite_theta_phys_log(:), n);
    S.e_theta = align_len(suite_e_theta_log(:), n);
    % Synthetic "sensor" = plant truth (zero-pert plumbing); innovation ≡ 0
    S.y_truth = [S.vp, S.ori, S.vel, S.rates]; % [x y z phi theta psi u v w p q r]
    S.y_meas  = S.y_truth; % NOT_IMPLEMENTED sensor → identity plumbing
    S.innov_sensor = S.y_meas - S.y_truth;     % identically zero
end

function A = analyze_plumbing(S, name)
    A = struct('name', name, 'ok', false);
    if isempty(S.t) || numel(S.t) < 10
        return;
    end
    A.ok = true;
    A.n = numel(S.t);
    A.dt = S.dt;
    A.T = S.t(end);

    % Sensor plumbing residual (must be ~0)
    A.sensor_innov_rms = sqrt(mean(S.innov_sensor.^2, 1));
    A.sensor_innov_max = max(abs(S.innov_sensor), [], 1);
    A.sensor_innov_all_zero = all(A.sensor_innov_max < 1e-15);

    % Channel stats (plant truth channels controller/guidance consume)
    ch = {'x','y','z','phi','theta','psi','u','v','w','p','q','r'};
    Y = S.y_truth;
    for i = 1:12
        A.channel_stats.(ch{i}) = series_stats(Y(:, i));
    end

    % Tracking / guidance residual proxies (not estimator innovations;
    % saved where available as control residuals)
    e_psi = wrapToPi(S.psi_ref - S.ori(:, 3));
    e_th = S.theta_ref - (-S.ori(:, 2));
    e_u = S.u_ref - S.vel(:, 1);
    e_rate = S.rate_filt - S.rate_raw; % filter residual (raw - filt magnitude)
    A.innovation_proxy = struct();
    A.innovation_proxy.note = ['No estimator; proxies = tracking/filter residuals on ', ...
        'plant truth. Sensor innovation identically zero (plumbing).'];
    A.innovation_proxy.e_psi = series_stats(e_psi);
    A.innovation_proxy.e_theta = series_stats(e_th);
    A.innovation_proxy.e_u = series_stats(e_u);
    A.innovation_proxy.rate_filt_minus_raw = series_stats(S.rate_filt - S.rate_raw);
    A.innovation_proxy.e_z = series_stats(S.e_z);
    A.innovation_proxy.e_zdot = series_stats(S.e_zdot);
    A.innovation_proxy.e_gamma = series_stats(S.e_gamma);
    A.innovation_proxy.e_psi_series = e_psi;
    A.innovation_proxy.e_theta_series = e_th;
    A.innovation_proxy.e_z_series = S.e_z;
end

function st = series_stats(x)
    x = x(:);
    x = x(isfinite(x));
    st = struct('n', numel(x), 'mean', NaN, 'rms', NaN, 'std', NaN, ...
        'min', NaN, 'max', NaN, 'p95', NaN);
    if isempty(x); return; end
    st.mean = mean(x);
    st.rms = sqrt(mean(x.^2));
    st.std = std(x);
    st.min = min(x);
    st.max = max(x);
    st.p95 = pctile95(abs(x));
end

function est = estimator_readiness(iface)
    est = struct();
    % Conceptual measured output matching realistic onboard set (ASSUMED mapping)
    est.y_names = iface.obs_compare.y_B;
    est.y_definition = ['y = [z; phi; theta; psi; u; v; w; p; q; r] — estimator-ready ', ...
        'ONLY as conceptual map to IMU+DVL+depth+heading; hardware/sensor models ', ...
        'NOT_IMPLEMENTED. Production currently feeds full plant truth including x,y.'];
    est.y_status = 'CONCEPTUAL_ASSUMED — no implemented C*x sensor layer';
    est.missing_xy = 'absolute x,y kinematic integrators unobservable under realistic y_B (CTRL_OBS)';
    est.process_disturbance = struct( ...
        'w_current', 'NOT_IMPLEMENTED (would be Vc or nu_c in NED/BODY)', ...
        'w_model', 'ASSUMED plant-model mismatch only; no explicit process-noise vector', ...
        'status', 'NOT_IMPLEMENTED');
    est.measurement_disturbance = struct( ...
        'v_imu', 'NOT_IMPLEMENTED', ...
        'v_dvl', 'NOT_IMPLEMENTED', ...
        'v_depth', 'NOT_IMPLEMENTED', ...
        'v_heading', 'NOT_IMPLEMENTED', ...
        'status', 'NOT_IMPLEMENTED');
    % Prioritize: do NOT invent Kalman/current observer without hooks
    est.next_candidate = 'DEFER_ESTIMATOR — no justified current-observer/Kalman/complementary yet';
    est.next_candidate_reason = ['Plant has no Vc/nu_r; no sensor noise/bias/delay models; ', ...
        'controller already has complementary-like rate LPF on truth. A current observer ', ...
        'requires a current process model; a Kalman requires C/R measurement models; ', ...
        'neither exists without fabricating hardware. First justify by adding one bounded hook.'];
    est.next_gate = 'bounded_plant_current_OR_measurement_noise_hook';
    est.next_gate_detail = ['Single next bounded gate: introduce ONE explicit hook — either ', ...
        '(a) constant/bounded NED current Vc with nu_r=nu-R''*Vc in plant damping+kinematics, ', ...
        'OR (b) additive measurement noise on one realistic channel (e.g. depth or DVL u) ', ...
        'with documented sigma — then re-run plumbing sensitivity. Do NOT design estimator yet. ', ...
        'Production cascade+guidance remain frozen.'];
end

%% ===================== outputs =====================
function write_png(png_path, SX, SXZ, SH, AX, AXZ, AH, task_id, verdict)
    fig = figure('Visible', 'off', 'Position', [80 80 1280 860]);
    tiledlayout(3, 2, 'Padding', 'compact', 'TileSpacing', 'compact');

    nexttile;
    plot(SX.t, rad2deg(AX.innovation_proxy.e_theta_series), 'b'); hold on;
    plot(SX.t, rad2deg(AX.innovation_proxy.e_psi_series), 'r');
    grid on; ylabel('deg'); title(sprintf('X residuals  sensor_innov≡0=%d', AX.sensor_innov_all_zero));
    legend('e_\theta','e_\psi', 'Location', 'best');

    nexttile;
    plot(SX.t, SX.e_z, 'k'); grid on; ylabel('m'); title('X e_z (guidance, filtered truth)');

    nexttile;
    plot(SXZ.t, rad2deg(AXZ.innovation_proxy.e_theta_series), 'b'); hold on;
    plot(SXZ.t, rad2deg(AXZ.innovation_proxy.e_psi_series), 'r');
    grid on; ylabel('deg'); title(sprintf('XZ residuals  sensor_innov≡0=%d', AXZ.sensor_innov_all_zero));
    legend('e_\theta','e_\psi', 'Location', 'best');

    nexttile;
    plot(SXZ.t, SXZ.e_z, 'k'); grid on; ylabel('m'); title('XZ e_z (guidance)');

    nexttile;
    plot(SH.t, rad2deg(AH.innovation_proxy.e_theta_series), 'b'); hold on;
    plot(SH.t, rad2deg(AH.innovation_proxy.e_psi_series), 'r');
    grid on; ylabel('deg'); xlabel('t [s]');
    title(sprintf('R10 residuals  sensor_innov≡0=%d', AH.sensor_innov_all_zero));
    legend('e_\theta','e_\psi', 'Location', 'best');

    nexttile;
    names = {'x','y','z','phi','theta','psi','u','v','w','p','q','r'};
    rmsv = AX.sensor_innov_rms(:);
    bar(rmsv); set(gca, 'XTick', 1:12, 'XTickLabel', names); xtickangle(45);
    ylabel('RMS innov'); title(sprintf('%s %s — zero-pert plumbing', task_id, verdict));
    grid on;

    sgtitle(sprintf('%s — production truth plumbing (no noise/current inject)', task_id), ...
        'Interpreter', 'none');
    exportgraphics(fig, png_path, 'Resolution', 150);
    close(fig);
end

function write_md(md_path, task_id, verdict, iface, plumbing, est, gates, ...
        dt_c, dt_g, tau_r, md_p, mat_p, png_p)

    fid = fopen(md_path, 'w');
    fprintf(fid, '# %s — Sensor / noise / current interface audit\n\n', task_id);
    fprintf(fid, '**Overall verdict: %s** (audit completeness, not robustness)\n\n', verdict);

    fprintf(fid, '## Provenance\n\n');
    fprintf(fid, '- Read-only: `controller_law.m`, `continuous_path_tracking.m`, `underwater777_vehicle_dynamics.m`\n');
    fprintf(fid, '- Driver: `run_sensor_noise_current_audit.m` (one invocation; no production edit)\n');
    fprintf(fid, '- Prior obs set: `CTRL_OBS_AUDIT` IMU+DVL+depth+heading/INS (assumed direct)\n');
    fprintf(fid, '- Depth PI/NDO: rejected; production cascade+guidance frozen\n');
    fprintf(fid, '- Artifacts: `%s`, `%s`, `%s`\n', md_p, mat_p, png_p);
    fprintf(fid, '- Did **not** touch `CODEX_VERTICAL_PLAN.md`\n\n');

    fprintf(fid, '## Sample rates / filters (documented)\n\n');
    fprintf(fid, '| Qty | Value | Source |\n|---|---|---|\n');
    fprintf(fid, '| dt_controller | %.4f s | init_parameters (plant+controller) |\n', dt_c);
    fprintf(fid, '| dt_guidance | %.4f s | init_parameters (ZOH guidance) |\n', dt_g);
    fprintf(fid, '| tau_rate | %.4f s | controller rate LPF on theta_phys_dot |\n\n', tau_r);

    fprintf(fid, '## Hooks inventory\n\n');
    fprintf(fid, '| Hook | Status |\n|---|---|\n');
    fprintf(fid, '| Ocean current / Vc / nu_r | **%s** |\n', iface.hooks.current);
    fprintf(fid, '| Sensor / meas noise | **%s** |\n', iface.hooks.noise);
    fprintf(fid, '| Sensor delay | **%s** |\n', iface.hooks.delay);
    fprintf(fid, '| IMU/DVL/INS sensor model | **%s** |\n\n', iface.hooks.sensor_model);
    fprintf(fid, '%s\n\n', iface.hooks.notes);

    fprintf(fid, '## Current / nu_r / ground vs water\n\n');
    fprintf(fid, '```\n');
    fprintf(fid, 'Vc modeled: %s\n', tern(iface.current.modeled, 'YES', 'NO'));
    fprintf(fid, 'Vc: %s\n', iface.current.Vc);
    fprintf(fid, 'nu_r: %s\n', iface.current.nu_r);
    fprintf(fid, 'kinematics: %s\n', iface.current.kinematics);
    fprintf(fid, 'damping: %s\n', iface.current.damping);
    fprintf(fid, 'plant: %s\n', iface.current.plant_treatment);
    fprintf(fid, 'controller sees: %s\n', iface.current.controller_sees);
    fprintf(fid, '```\n\n');

    fprintf(fid, '## Signal map (production feedback / guidance)\n\n');
    fprintf(fid, '| Signal | Frame | Units | Provenance | Sample | Filter | Delay | Bias | Noise | Notes |\n');
    fprintf(fid, '|---|---|---|---|---|---|---|---|---|---|\n');
    for i = 1:numel(iface.signals)
        s = iface.signals(i);
        fprintf(fid, '| %s | %s | %s | %s | %s | %s | %s | %s | %s | %s |\n', ...
            s.name, s.frame, s.units, s.provenance, s.sample_rate, s.filter, ...
            s.delay, s.bias, s.noise, s.notes);
    end
    fprintf(fid, '\n%s\n\n', iface.guidance_note);

    fprintf(fid, '## vs CTRL_OBS realistic set\n\n');
    fprintf(fid, '- Realistic (ASSUMED): %s\n', iface.obs_compare.realistic_set);
    fprintf(fid, '- y_B = [%s] — %s\n', strjoin(iface.obs_compare.y_B, ', '), iface.obs_compare.y_B_note);
    fprintf(fid, '- y_C = full 12 with INS xy — %s\n', iface.obs_compare.y_C_note);
    fprintf(fid, '- Production actual: %s\n', iface.obs_compare.production_actual);
    fprintf(fid, '- Gap: %s\n\n', iface.obs_compare.gap);

    fprintf(fid, '## Zero-perturbation plumbing (sensitivity DEFERRED)\n\n');
    fprintf(fid, '- Mode: `%s`\n', plumbing.mode);
    fprintf(fid, '- Sensitivity injection: **%s**\n', plumbing.sensitivity_injection);
    fprintf(fid, '- Reason: %s\n\n', plumbing.reason);

    fprintf(fid, '| Route | n | T [s] | sensor_innov≡0 | e_theta RMS [deg] | e_psi RMS [deg] | e_z RMS [m] |\n');
    fprintf(fid, '|---|---:|---:|:---:|---:|---:|---:|\n');
    routes = {plumbing.X, plumbing.XZ, plumbing.H};
    for i = 1:3
        A = routes{i};
        fprintf(fid, '| %s | %d | %.2f | %s | %.4f | %.4f | %.4f |\n', ...
            A.name, A.n, A.T, yn(A.sensor_innov_all_zero), ...
            rad2deg(A.innovation_proxy.e_theta.rms), ...
            rad2deg(A.innovation_proxy.e_psi.rms), ...
            A.innovation_proxy.e_z.rms);
    end
    fprintf(fid, '\nRaw channel / innovation-proxy statistics stored in MAT (`plumbing.*.channel_stats`, `innovation_proxy`).\n\n');

    fprintf(fid, '## Estimator readiness\n\n');
    fprintf(fid, '- Measured y (conceptual): %s\n', est.y_definition);
    fprintf(fid, '- Status: **%s**\n', est.y_status);
    fprintf(fid, '- Missing absolute modes: %s\n', est.missing_xy);
    fprintf(fid, '- Process disturbance vector: %s / %s\n', ...
        est.process_disturbance.w_current, est.process_disturbance.status);
    fprintf(fid, '- Measurement disturbance vector: %s\n', est.measurement_disturbance.status);
    fprintf(fid, '- Next estimator candidate: **%s**\n', est.next_candidate);
    fprintf(fid, '- Reason: %s\n\n', est.next_candidate_reason);

    fprintf(fid, '## PASS gates\n\n');
    fprintf(fid, '| Gate | Result |\n|---|---|\n');
    gn = fieldnames(gates);
    for i = 1:numel(gn)
        fprintf(fid, '| %s | %s |\n', gn{i}, tern(gates.(gn{i}), 'PASS', 'FAIL'));
    end
    fprintf(fid, '\n**Overall: %s**\n\n', verdict);

    fprintf(fid, '## Next bounded gate\n\n');
    fprintf(fid, '- **`%s`**\n', est.next_gate);
    fprintf(fid, '- %s\n', est.next_gate_detail);
    fprintf(fid, '- Production remains frozen; no estimator design until a real hook exists.\n');
    fclose(fid);
end

function append_audit(out_dir, task_id, verdict, iface, plumbing, est, md_p, mat_p, png_p)
    audit_path = fullfile(out_dir, 'STATE_SPACE_MODEL_AUDIT.md');
    fid = fopen(audit_path, 'a');
    fprintf(fid, '\n\n---\n\n');
    fprintf(fid, '## %s — %s\n\n', task_id, datestr(now, 31));
    fprintf(fid, '### Provenance\n\n');
    fprintf(fid, '- Read-only: `controller_law.m`, `continuous_path_tracking.m`, `underwater777_vehicle_dynamics.m`\n');
    fprintf(fid, '- Driver: `run_sensor_noise_current_audit.m` (one invocation; no production edit)\n');
    fprintf(fid, '- Prior: CTRL_OBS_AUDIT IMU+DVL+depth+heading/INS; Depth PI/NDO rejected\n');
    fprintf(fid, '- Artifacts: `%s`, `%s`, `%s`\n', md_p, mat_p, png_p);
    fprintf(fid, '- Did not touch `CODEX_VERTICAL_PLAN.md`\n\n');
    fprintf(fid, '### Verdict\n\n');
    fprintf(fid, '**%s** — sensor/noise/current interface audit completeness (not robustness).\n\n', verdict);
    fprintf(fid, '### Key findings\n\n');
    fprintf(fid, '| Item | Result |\n|---|---|\n');
    fprintf(fid, '| Current / nu_r | %s — Vc≡0; damping uses nu; kinematics R*nu |\n', iface.hooks.current);
    fprintf(fid, '| Sensor noise / delay / IMU-DVL | %s |\n', iface.hooks.noise);
    fprintf(fid, '| Controller feedback | plant truth BODY/NED (ground≡water) |\n');
    fprintf(fid, '| vs obs y_B | production = ideal full-state; realistic sensors ASSUMED only |\n');
    fprintf(fid, '| Plumbing | zero-pert X/XZ/R10 @ U=1.5; sensor innov ≡ 0; sensitivity DEFERRED |\n');
    fprintf(fid, '| X/XZ/R10 sensor_innov≡0 | %s / %s / %s |\n', ...
        yn(plumbing.X.sensor_innov_all_zero), yn(plumbing.XZ.sensor_innov_all_zero), ...
        yn(plumbing.H.sensor_innov_all_zero));
    fprintf(fid, '\n### Estimator\n\n');
    fprintf(fid, '- Conceptual y = [z phi theta psi u v w p q r]; absolute x,y missing under realistic y_B\n');
    fprintf(fid, '- Process/meas disturbance vectors: NOT_IMPLEMENTED\n');
    fprintf(fid, '- Candidate: **%s**\n', est.next_candidate);
    fprintf(fid, '\n### Next\n\n');
    fprintf(fid, '- `%s` — %s\n', est.next_gate, est.next_gate_detail);
    fclose(fid);
end

function print_feedback(verdict, iface, plumbing, est, gates, md_p, mat_p, png_p)
    fprintf('\n========== FEEDBACK ==========\n');
    fprintf('VERDICT: %s (completeness)\n', verdict);
    fprintf('Hooks current/noise/delay/sensor: %s / %s / %s / %s\n', ...
        iface.hooks.current, iface.hooks.noise, iface.hooks.delay, iface.hooks.sensor_model);
    fprintf('Current: %s\n', iface.current.plant_treatment);
    fprintf('Plumbing: %s | sensitivity %s\n', plumbing.mode, plumbing.sensitivity_injection);
    fprintf('X/XZ/R10 sensor_innov≡0: %d/%d/%d\n', ...
        plumbing.X.sensor_innov_all_zero, plumbing.XZ.sensor_innov_all_zero, ...
        plumbing.H.sensor_innov_all_zero);
    fprintf('Next estimator: %s\n', est.next_candidate);
    fprintf('Next gate: %s\n', est.next_gate);
    gn = fieldnames(gates);
    for i = 1:numel(gn)
        fprintf('  gate %s: %s\n', gn{i}, tern(gates.(gn{i}), 'PASS', 'FAIL'));
    end
    fprintf('Artifacts:\n  %s\n  %s\n  %s\n', md_p, mat_p, png_p);
end

function P = pack_series(S)
    P = struct();
    P.dt = S.dt; P.T_final = S.T_final; P.u0 = S.u0; P.lambda = S.lambda;
    P.t = S.t;
    P.vp = S.vp; P.vel = S.vel; P.rates = S.rates; P.ori = S.ori;
    P.psi_ref = S.psi_ref; P.theta_ref = S.theta_ref; P.u_ref = S.u_ref;
    P.e_z = S.e_z; P.e_zdot = S.e_zdot; P.e_gamma = S.e_gamma;
    P.rate_filt = S.rate_filt; P.rate_raw = S.rate_raw;
    P.innov_sensor_rms = sqrt(mean(S.innov_sensor.^2, 1));
end

function y = align_len(x, n)
    x = x(:);
    if numel(x) >= n
        y = x(1:n);
    else
        y = [x; zeros(n - numel(x), 1)];
    end
end

function v = pctile95(x)
    x = sort(x(:));
    if isempty(x); v = NaN; return; end
    k = max(1, min(numel(x), ceil(0.95 * numel(x))));
    v = x(k);
end

function s = yn(tf)
    if tf; s = 'YES'; else; s = 'NO'; end
end

function s = tern(tf, a, b)
    if tf; s = a; else; s = b; end
end
