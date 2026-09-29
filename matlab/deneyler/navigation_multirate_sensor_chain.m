function varargout = navigation_multirate_sensor_chain(action, varargin)
% NAVIGATION_MULTIRATE_SENSOR_CHAIN  Isolated Gate 5A multirate sensor chain.
%
% TASK_ID NAV_MULTIRATE_SENSOR_CHAIN_001.
%
% Scope / isolation
%   Pure library. No globals, no persistent state, no production call.
%   Production plant / controller / guidance remain frozen and are never
%   invoked from here. Every run is constructed from its own local state so
%   results are independent of call order (reset sentinel is verifiable).
%
% Buses (all defined here; see 'config' for full unit/frame declarations)
%   TRUTH     : noise-free kinematic reference (NED position, ZYX Euler,
%               ground BODY velocity nu, water-relative BODY velocity nu_r,
%               BODY rates, BODY specific force, NED current Vc, altitude).
%   MEASURED  : per-channel sensor bus sampled on its own clock with ZOH +
%               transport-delay queue, carrying value, timestamp, receive
%               time, nominal sample time, sequence, validity, quality and
%               stale age.
%   ESTIMATED : declared but explicitly INVALID / UNAVAILABLE in Gate 5A.
%               No estimator, no filter, no fusion is implemented. Values
%               are NaN by construction so nothing downstream can mistake
%               truth for an estimate.
%
% Current convention (provenance: underwater777_vehicle_dynamics_current.m)
%   nu_c_lin = R(phi,theta,psi)' * Vc        (BODY, linear only)
%   nu_r_lin = [u;v;w] - nu_c_lin            (water-relative BODY)
%   eta_dot  = R * [u;v;w]                   (ground kinematics)
%   Vc = 0 reproduces the ground-relative case exactly.
%
% Parameter provenance
%   Every sensor rate, sigma, bias, scale error, delay, quality and
%   bottom-lock number below is ASSUMED. The single declared upstream
%   source (SENSOR_NOISE_CURRENT_AUDIT) records sensor noise / delay /
%   IMU-DVL models as NOT_IMPLEMENTED, so nothing here can be IDENTIFIED.
%   No value in this file is calibrated, fitted or bench-derived.
%
% Usage
%   cfg = navigation_multirate_sensor_chain('config');
%   T   = navigation_multirate_sensor_chain('truth', route, Vc, cfg, opts);
%   B   = navigation_multirate_sensor_chain('run', T, cfg);
%   V   = navigation_multirate_sensor_chain('verify', T, B, cfg);
%   P   = navigation_multirate_sensor_chain('pack', B);

    switch lower(action)
        case 'config'
            varargout{1} = default_config();
        case 'truth'
            varargout{1} = build_truth(varargin{:});
        case 'run'
            varargout{1} = run_chain(varargin{:});
        case 'verify'
            varargout{1} = verify_contracts(varargin{:});
        case 'pack'
            varargout{1} = pack_compare(varargin{:});
        case 'statusnames'
            varargout{1} = status_names();
        otherwise
            error('navigation_multirate_sensor_chain: unknown action "%s"', action);
    end
end

%% ===================== configuration (all ASSUMED) =====================
function cfg = default_config()
    cfg = struct();
    cfg.task_id = 'NAV_MULTIRATE_SENSOR_CHAIN_001';
    cfg.gate = '5A';

    % Scheduler base tick. Every channel period and every transport delay is
    % an exact integer multiple of this tick, so achieved rates can be held
    % to within one base tick by construction and then re-verified.
    cfg.dt_base = 0.005;              % s   ASSUMED (200 Hz scheduler)
    cfg.U_ground = 1.5;               % m/s ASSUMED ground speed on the path
    cfg.g_ned = 9.81;                 % m/s^2 ASSUMED gravity, NED down +
    cfg.seabed_depth_ned = 30.0;      % m   ASSUMED flat seabed, NED down +
    cfg.outage_frac = [0.40 0.62];    % -   ASSUMED declared outage window

    cfg.frames = struct( ...
        'NED', 'North-East-Down inertial; z positive DOWN', ...
        'BODY', 'Fossen body axes x fwd / y stbd / z down', ...
        'EULER', 'ZYX roll-pitch-yaw phi/theta/psi [rad]');

    cfg.estimated_policy = ['Gate 5A declares the ESTIMATED bus but leaves ', ...
        'it INVALID/UNAVAILABLE. No EKF/UKF/complementary filter exists; ', ...
        'fabricating one would be an unjustified navigation claim.'];

    % ---- channel table -------------------------------------------------
    C = {};
    C{end+1} = chan('imu_gyro', 'angular rate', 'BODY', 'rad/s', 3, true, ...
        100, 0.005, [0.0035 0.0035 0.0035], [0.0020 -0.0015 0.0010], 0, ...
        0.95, -10, 10, 'invalid_message', ...
        'Strapdown MEMS gyro triad; constant turn-on bias + white noise.');
    C{end+1} = chan('imu_accel', 'specific force', 'BODY', 'm/s^2', 3, true, ...
        100, 0.005, [0.020 0.020 0.020], [0.010 -0.008 0.015], 0, ...
        0.95, -50, 50, 'invalid_message', ...
        'Specific force f_b = R''*(a_ned - g_ned); NOT acceleration.');
    C{end+1} = chan('dvl_vel_body_water', 'water-relative velocity', 'BODY', 'm/s', 3, true, ...
        5, 0.100, [0.010 0.010 0.015], [0.002 -0.002 0.003], 0.002, ...
        0.90, -10, 10, 'message_gap', ...
        'Janus DVL, water-relative BODY (nu_r). Loss of bottom lock means no acoustic return, so no message is emitted at all (message gap, not a flagged message).');
    C{end+1} = chan('depth_pressure', 'depth', 'NED', 'm', 1, true, ...
        10, 0.020, 0.020, 0.050, 0, ...
        0.98, -5, 500, 'invalid_message', ...
        'Pressure-derived depth, NED-down positive; sign matches truth z.');
    C{end+1} = chan('heading_compass', 'heading', 'NED', 'rad', 1, true, ...
        20, 0.040, deg2rad(0.5), deg2rad(1.0), 0, ...
        0.85, -pi, pi, 'invalid_message', ...
        'Magnetic/AHRS heading, wrapped to (-pi,pi]; yaw psi only.');
    C{end+1} = chan('ins_vel_ned', 'ground velocity', 'NED', 'm/s', 3, true, ...
        50, 0.030, [0.020 0.020 0.030], [0.005 0.004 -0.003], 0, ...
        0.92, -10, 10, 'invalid_message', ...
        'INS/aided ground velocity in NED; ground-relative, not water.');
    C{end+1} = chan('usbl_pos_ned', 'position fix', 'NED', 'm', 3, false, ...
        0.5, 1.200, [0.50 0.50 0.80], [0.10 -0.10 0.20], 0, ...
        0.70, -5000, 5000, 'message_gap', ...
        'OPTIONAL acoustic position fix; ABSENT in Gate 5A (never emits).');
    cfg.channels = [C{:}];

    % Derived integer scheduling; assert exact tick alignment.
    for i = 1:numel(cfg.channels)
        ch = cfg.channels(i);
        pt = ch.period_s / cfg.dt_base;
        dt_t = ch.delay_s / cfg.dt_base;
        if abs(pt - round(pt)) > 1e-9 || abs(dt_t - round(dt_t)) > 1e-9
            error('Channel %s period/delay not an integer multiple of dt_base', ch.name);
        end
        cfg.channels(i).period_ticks = round(pt);
        cfg.channels(i).delay_ticks = round(dt_t);
        % Two-stage availability budget (both ASSUMED): a held sample is
        % first declared STALE, then DROPOUT if nothing arrives at all.
        cfg.channels(i).stale_limit_s = ch.delay_s + 2.5 * ch.period_s;
        cfg.channels(i).dropout_limit_s = ch.delay_s + 6.0 * ch.period_s;
        cfg.channels(i).reacq_ramp_s = 1.0;      % s ASSUMED quality ramp
        cfg.channels(i).seed_offset = 1000 * i;
    end

    % DVL bottom-lock model (ASSUMED)
    cfg.dvl = struct( ...
        'max_range_m', 60.0, ...
        'min_range_m', 0.7, ...
        'lock_note', 'Bottom lock lost outside [min_range, max_range] or inside the declared outage window.');

    % ESTIMATED bus skeleton: declared fields, no implementation.
    E = {};
    E{end+1} = estfield('pos_ned', 'NED', 'm', 3);
    E{end+1} = estfield('vel_ned', 'NED', 'm/s', 3);
    E{end+1} = estfield('vel_body_water', 'BODY', 'm/s', 3);
    E{end+1} = estfield('euler', 'EULER', 'rad', 3);
    E{end+1} = estfield('gyro_bias', 'BODY', 'rad/s', 3);
    E{end+1} = estfield('current_ned', 'NED', 'm/s', 3);
    cfg.estimated_fields = [E{:}];

    cfg.assumed_note = ['ALL numeric sensor properties in this config are ', ...
        'ASSUMED (rate, sigma, bias, scale, delay, quality, bottom-lock ', ...
        'geometry, seabed depth, base tick). None is IDENTIFIED.'];
end

function s = chan(name, quantity, frame, units, dim, present, rate_hz, ...
        delay_s, sigma, bias, scale, q_nom, bound_lo, bound_hi, dropout_mode, notes)
    s = struct();
    s.name = name;
    s.quantity = quantity;
    s.frame = frame;
    s.units = units;
    s.dim = dim;
    s.present = present;
    s.rate_hz = rate_hz;
    s.period_s = 1 / rate_hz;
    s.delay_s = delay_s;
    s.sigma = reshape(sigma, 1, []);
    s.bias = reshape(bias, 1, []);
    s.scale = scale;                  % fractional scale-factor error
    s.q_nom = q_nom;
    s.bound_lo = bound_lo;
    s.bound_hi = bound_hi;
    s.dropout_mode = dropout_mode;
    s.notes = notes;
    s.provenance = 'ASSUMED';
    s.period_ticks = 0;
    s.delay_ticks = 0;
    s.stale_limit_s = 0;
    s.dropout_limit_s = 0;
    s.reacq_ramp_s = 0;
    s.seed_offset = 0;
    if numel(s.sigma) ~= dim || numel(s.bias) ~= dim
        error('chan %s: sigma/bias dimension mismatch', name);
    end
end

function s = estfield(name, frame, units, dim)
    s = struct('name', name, 'frame', frame, 'units', units, 'dim', dim, ...
        'status', 'UNAVAILABLE', 'reason', 'NO_ESTIMATOR_IN_GATE_5A');
end

function n = status_names()
    n = {'UNAVAILABLE', 'INIT_WAIT', 'OK', 'STALE', 'DROPOUT'};
end

%% ===================== TRUTH bus =====================
function T = build_truth(route, Vc, cfg, opts)
% Deterministic, closed-form kinematic TRUTH generator.
%
% This is a scenario generator, NOT a plant simulation and NOT a controlled
% run: it prescribes a ground trajectory along the declared geometry at a
% constant ground speed and derives a consistent attitude/rate/specific
% force set. It exists only to excite the sensor chain. No tracking,
% stability or navigation-performance conclusion may be drawn from it.
%
% Attitude assumption (ASSUMED): the body x-axis is aligned with the
% water-relative velocity (zero angle of attack and zero sideslip through
% the water), with a coordinated-turn bank. Under Vc ~= 0 this makes the
% vehicle crab, so heading differs from course over ground and DVL
% (water-relative) separates from INS (ground-relative).

    if nargin < 4 || isempty(opts); opts = struct(); end
    opts = setdef(opts, 'dvl_outage', false);
    opts = setdef(opts, 'label', route);

    Vc = reshape(Vc, 1, 3);
    dt = cfg.dt_base;
    g = cfg.g_ned;

    geo = route_geometry(route);
    t = (0:dt:geo.T_final)';
    N = numel(t);
    s = cfg.U_ground * t;                       % arc length along path [m]

    switch route
        case 'X'
            p = [s, zeros(N, 1), zeros(N, 1)];
            Vg = repmat([cfg.U_ground 0 0], N, 1);
        case 'XZ'
            d = geo.dir / norm(geo.dir);
            p = s * d;
            Vg = repmat(cfg.U_ground * d, N, 1);
        case 'R10'
            b = geo.h_per_rev / (2 * pi);
            c = sqrt(geo.R^2 + b^2);
            sig = s / c;
            p = [geo.R * cos(sig), geo.R * sin(sig), b * sig];
            sd = cfg.U_ground / c;
            Vg = [-geo.R * sin(sig) * sd, geo.R * cos(sig) * sd, repmat(b * sd, N, 1)];
        otherwise
            error('Unknown route "%s"', route);
    end

    Vw = Vg - repmat(Vc, N, 1);                 % water-relative velocity, NED
    Vw_h = hypot(Vw(:, 1), Vw(:, 2));
    Vw_n = sqrt(sum(Vw.^2, 2));
    if any(Vw_n < 1e-6)
        error('Water-relative speed collapses to zero; scenario ill-posed');
    end

    psi = unwrap(atan2(Vw(:, 2), Vw(:, 1)));
    theta = -asin(max(-1, min(1, Vw(:, 3) ./ Vw_n)));
    psi_dot = gradient(psi, dt);
    phi = atan2(Vw_h .* psi_dot, g);            % coordinated-turn bank (ASSUMED)
    phi_dot = gradient(phi, dt);
    theta_dot = gradient(theta, dt);

    % Body rates from ZYX Euler rates (inverse of the plant JJ matrix)
    omega = [phi_dot - psi_dot .* sin(theta), ...
             theta_dot .* cos(phi) + psi_dot .* cos(theta) .* sin(phi), ...
            -theta_dot .* sin(phi) + psi_dot .* cos(theta) .* cos(phi)];

    a_ned = [gradient(Vg(:, 1), dt), gradient(Vg(:, 2), dt), gradient(Vg(:, 3), dt)];

    nu = zeros(N, 3); nu_r = zeros(N, 3); nu_c = zeros(N, 3); f_b = zeros(N, 3);
    g_vec = [0 0 g];
    for k = 1:N
        R = rot_body2ned(phi(k), theta(k), psi(k));
        nu(k, :) = (R' * Vg(k, :)')';
        nu_c(k, :) = (R' * Vc')';
        nu_r(k, :) = (R' * Vw(k, :)')';
        f_b(k, :) = (R' * (a_ned(k, :) - g_vec)')';
    end

    altitude = cfg.seabed_depth_ned - p(:, 3);
    in_range = altitude <= cfg.dvl.max_range_m & altitude >= cfg.dvl.min_range_m;
    outage_mask = false(N, 1);
    outage_window = [NaN NaN];
    if opts.dvl_outage
        outage_window = cfg.outage_frac * geo.T_final;
        outage_mask = t >= outage_window(1) & t <= outage_window(2);
    end
    bottom_lock = in_range & ~outage_mask;

    T = struct();
    T.route = route;
    T.label = opts.label;
    T.dt = dt;
    T.T_final = geo.T_final;
    T.t = t;
    T.N = N;
    T.geometry = geo;
    T.Vc_ned = Vc;
    T.U_ground = cfg.U_ground;
    T.eta_ned = p;                    % [x y z] NED, z DOWN positive [m]
    T.euler = [phi, theta, wrap_pi(psi)];   % ZYX [rad]
    T.psi_unwrapped = psi;
    T.V_g_ned = Vg;                   % ground velocity NED [m/s]
    T.V_w_ned = Vw;                   % water-relative velocity NED [m/s]
    T.nu_body = nu;                   % ground-relative BODY [m/s]
    T.nu_c_body = nu_c;               % current in BODY [m/s]
    T.nu_r_body = nu_r;               % water-relative BODY [m/s]
    T.omega_body = omega;             % [p q r] BODY [rad/s]
    T.a_ned = a_ned;                  % NED acceleration [m/s^2]
    T.f_body = f_b;                   % BODY specific force [m/s^2]
    T.altitude = altitude;            % height above ASSUMED seabed [m]
    T.bottom_lock = bottom_lock;
    T.dvl_outage = opts.dvl_outage;
    T.outage_window = outage_window;
    T.course_ned = wrap_pi(atan2(Vg(:, 2), Vg(:, 1)));
    T.crab_angle = wrap_pi(T.euler(:, 3) - T.course_ned);
    T.units = struct('eta_ned', 'm', 'euler', 'rad', 'V_g_ned', 'm/s', ...
        'nu_body', 'm/s', 'nu_r_body', 'm/s', 'omega_body', 'rad/s', ...
        'f_body', 'm/s^2', 'altitude', 'm');
    T.note = ['Kinematic ASSUMED truth generator; no plant integration, ', ...
        'no controller, no navigation-performance meaning.'];

    % Frame/sign identity residual, checked here and re-checked in verify.
    T.identity_nu_r_resid = max(max(abs(nu_r - (nu - nu_c))));
end

function geo = route_geometry(route)
    switch route
        case 'X'
            geo = struct('name', 'X', 'T_final', 18, 'desc', ...
                'Straight run along +x_NED at constant depth', ...
                'dir', [1 0 0], 'R', NaN, 'h_per_rev', NaN);
        case 'XZ'
            geo = struct('name', 'XZ', 'T_final', 22, 'desc', ...
                'Straight descending run, NED slope dz/dx = 0.4', ...
                'dir', [1 0 0.4], 'R', NaN, 'h_per_rev', NaN);
        case 'R10'
            geo = struct('name', 'R10', 'T_final', 45, 'desc', ...
                'Descending helix, radius 10 m, 2.0 m depth gain per revolution', ...
                'dir', [NaN NaN NaN], 'R', 10.0, 'h_per_rev', 2.0);
        otherwise
            error('Unknown route "%s"', route);
    end
    geo.provenance = 'ASSUMED geometry reused from the declared X/XZ/R10 baseline family';
end

function R = rot_body2ned(phi, theta, psi)
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

%% ===================== MEASURED / ESTIMATED buses =====================
function B = run_chain(T, cfg, seed)
% Runs every channel on its own clock over the base-tick grid.
% All randomness comes from per-channel RandStream objects seeded from the
% case seed only, never from loop order, so the result is order-independent.

    if nargin < 3 || isempty(seed); seed = case_seed(T); end

    B = struct();
    B.task_id = cfg.task_id;
    B.route = T.route;
    B.label = T.label;
    B.Vc_ned = T.Vc_ned;
    B.dvl_outage = T.dvl_outage;
    B.seed = seed;
    B.dt_base = cfg.dt_base;
    B.t = T.t;
    B.N = T.N;
    B.status_names = status_names();

    names = cell(1, numel(cfg.channels));
    for i = 1:numel(cfg.channels)
        ch = cfg.channels(i);
        stream = RandStream('mt19937ar', 'Seed', seed + ch.seed_offset);
        M = run_channel(ch, T, cfg, stream);
        M.spec = ch;
        B.meas.(ch.name) = M;
        names{i} = ch.name;
    end
    B.channel_names = names;

    % ESTIMATED bus: declared, never populated.
    est = struct();
    for i = 1:numel(cfg.estimated_fields)
        f = cfg.estimated_fields(i);
        e = struct();
        e.frame = f.frame;
        e.units = f.units;
        e.dim = f.dim;
        e.value = NaN(1, f.dim);
        e.timestamp = NaN;
        e.sample_time = NaN;
        e.seq = 0;
        e.valid = false;
        e.valid_series = false(T.N, 1);
        e.quality = 0;
        e.stale_age = Inf;
        e.status = 'UNAVAILABLE';
        e.reason = f.reason;
        est.(f.name) = e;
    end
    B.est = est;
    B.est_fields = {cfg.estimated_fields.name};
    B.est_policy = cfg.estimated_policy;
end

function M = run_channel(ch, T, cfg, stream)
    N = T.N;
    t = T.t;
    D = ch.dim;

    M = struct();
    M.name = ch.name;
    M.frame = ch.frame;
    M.units = ch.units;
    M.dim = D;
    M.present = ch.present;
    M.rate_hz_declared = ch.rate_hz;
    M.sample_time = ch.period_s;
    M.delay_s = ch.delay_s;

    value = NaN(N, D);
    timestamp = NaN(N, 1);
    t_rx = NaN(N, 1);
    seq = zeros(N, 1);
    seq_valid = zeros(N, 1);
    valid = false(N, 1);
    quality = zeros(N, 1);
    stale_age = inf(N, 1);
    status = zeros(N, 1);

    if ~ch.present
        M.value = value; M.timestamp = timestamp; M.t_rx = t_rx;
        M.seq = seq; M.seq_valid = seq_valid; M.valid = valid;
        M.quality = quality; M.stale_age = stale_age; M.status = status;
        M.event_t = zeros(0, 1); M.event_ok = false(0, 1);
        M.event_t_sched = zeros(0, 1);
        M.event_value = zeros(0, D);
        M.rate_hz_achieved = 0;
        M.absent_reason = 'OPTIONAL_CHANNEL_ABSENT_IN_GATE_5A';
        return;
    end

    % ---- emit events on the channel clock -------------------------------
    ks_sched = (1:ch.period_ticks:N)';
    nS = numel(ks_sched);
    ev_val = NaN(nS, D);
    ev_ok = false(nS, 1);
    ev_t = t(ks_sched);
    for j = 1:nS
        [ev_val(j, :), ev_ok(j)] = sample_channel(ch, T, ks_sched(j), stream);
    end

    % A 'message_gap' channel simply emits nothing when it has no usable
    % return (a DVL with no bottom lock does not send a flagged velocity,
    % it sends nothing), so the consumer sees a hole in the sequence.
    ks = ks_sched;
    if strcmp(ch.dropout_mode, 'message_gap')
        keep = ev_ok;
        ks = ks_sched(keep);
        ev_t = ev_t(keep);
        ev_val = ev_val(keep, :);
        ev_ok = ev_ok(keep);
    end
    nE = numel(ks);

    % ---- ZOH + transport-delay queue, latch, availability ---------------
    last_val = NaN(1, D);
    last_ts = NaN;
    last_ok = false;
    msg = 0; nvalid = 0;
    t_reacq = NaN;
    j = 1;
    for k = 1:N
        while j <= nE && (ks(j) + ch.delay_ticks) <= k
            msg = msg + 1;
            % A channel is reacquiring if the consumer had already degraded
            % when this sample landed. That covers both failure styles: an
            % explicitly invalid message, and a message gap wide enough that
            % the held sample had gone stale.
            was_degraded = ~last_ok || ...
                (nvalid >= 1 && (t(k) - last_ts) > ch.stale_limit_s + 1e-12);
            if ev_ok(j)
                if was_degraded && nvalid >= 1
                    t_reacq = t(k);
                end
                last_val = ev_val(j, :);
                last_ts = ev_t(j);
                nvalid = nvalid + 1;
            end
            last_ok = ev_ok(j);
            j = j + 1;
        end

        seq(k) = msg;
        seq_valid(k) = nvalid;
        if msg == 0 || isnan(last_ts)
            status(k) = 1;                      % INIT_WAIT
            stale_age(k) = Inf;
            continue;
        end

        value(k, :) = last_val;
        timestamp(k) = last_ts;
        t_rx(k) = last_ts + ch.delay_s;
        stale_age(k) = t(k) - last_ts;

        if ~last_ok || stale_age(k) > ch.dropout_limit_s + 1e-12
            status(k) = 4;                      % DROPOUT
        elseif stale_age(k) > ch.stale_limit_s + 1e-12
            status(k) = 3;                      % STALE
        else
            status(k) = 2;                      % OK
            valid(k) = true;
            quality(k) = ch.q_nom;
            if ~isnan(t_reacq) && t(k) < t_reacq + ch.reacq_ramp_s
                frac = (t(k) - t_reacq) / ch.reacq_ramp_s;
                quality(k) = ch.q_nom * (0.25 + 0.75 * frac);
            end
        end
    end

    M.value = value;
    M.timestamp = timestamp;
    M.t_rx = t_rx;
    M.seq = seq;
    M.seq_valid = seq_valid;
    M.valid = valid;
    M.quality = quality;
    M.stale_age = stale_age;
    M.status = status;
    M.event_t = ev_t;
    M.event_ok = ev_ok;
    M.event_value = ev_val;
    M.event_t_sched = t(ks_sched);
    % Achieved rate is a property of the channel clock, so it is measured on
    % the scheduled events; a bottom-lock gap is an availability event, not
    % a rate change.
    if nS >= 2
        M.rate_hz_achieved = (nS - 1) / (M.event_t_sched(end) - M.event_t_sched(1));
    else
        M.rate_hz_achieved = NaN;
    end
    M.absent_reason = '';
end

function [y, ok] = sample_channel(ch, T, k, stream)
% One raw sensor sample of the truth state at base-tick index k.
% The noise draw happens unconditionally so the stream never depends on
% validity history (keeps replay bitwise reproducible).
    n = randn(stream, 1, ch.dim);
    ok = true;
    switch ch.name
        case 'imu_gyro'
            base = T.omega_body(k, :);
        case 'imu_accel'
            base = T.f_body(k, :);
        case 'dvl_vel_body_water'
            base = (1 + ch.scale) * T.nu_r_body(k, :);
            ok = T.bottom_lock(k);
        case 'depth_pressure'
            base = T.eta_ned(k, 3);
        case 'heading_compass'
            base = T.euler(k, 3);
        case 'ins_vel_ned'
            base = T.V_g_ned(k, :);
        case 'usbl_pos_ned'
            base = T.eta_ned(k, :);
            ok = false;
        otherwise
            error('sample_channel: unhandled channel %s', ch.name);
    end
    y = base + ch.bias + ch.sigma .* n;
    if strcmp(ch.name, 'heading_compass')
        y = wrap_pi(y);
    end
end

function s = case_seed(T)
% Deterministic seed from the case identity only (never from loop index),
% so forward, reverse and standalone execution give identical streams.
    key = sprintf('%s|Vc=%.6f,%.6f,%.6f|outage=%d', T.route, ...
        T.Vc_ned(1), T.Vc_ned(2), T.Vc_ned(3), T.dvl_outage);
    h = uint32(2166136261);
    b = uint32(double(key));
    for i = 1:numel(b)
        h = bitxor(h, b(i));
        h = mod(uint64(h) * uint64(16777619), uint64(4294967296));
        h = uint32(h);
    end
    s = double(mod(double(h), 2^31 - 1));
end

%% ===================== contract verification =====================
function V = verify_contracts(T, B, cfg)
    V = struct();
    V.route = T.route;
    V.label = T.label;
    V.Vc_ned = T.Vc_ned;
    V.dvl_outage = T.dvl_outage;
    dt = cfg.dt_base;
    t = T.t;
    names = B.channel_names;

    ok_timing = true; ok_rate = true; ok_finite = true;
    ok_leak = true; ok_seq = true;
    per = struct();

    for i = 1:numel(names)
        nm = names{i};
        M = B.meas.(nm);
        ch = M.spec;
        r = struct();
        r.name = nm;
        r.present = M.present;
        r.frame = M.frame;
        r.units = M.units;
        r.rate_declared = ch.rate_hz;
        r.rate_achieved = M.rate_hz_achieved;
        r.delay_s = ch.delay_s;
        r.sample_time = ch.period_s;

        if ~M.present
            r.status_final = 'UNAVAILABLE';
            r.always_invalid = ~any(M.valid);
            r.n_events = 0;
            r.n_events_scheduled = 0;
            r.period_err_max = NaN;
            r.timing_ok = true;
            r.rate_ok = true;
            r.finite_ok = true;
            r.leak_ok = true;
            r.seq_ok = all(M.seq == 0);
            r.err_vs_truth_at_ts = empty_stats();
            r.err_vs_truth_at_bus = empty_stats();
            ok_seq = ok_seq && r.seq_ok;
            per.(nm) = r;
            continue;
        end

        % --- monotonic timing -------------------------------------------
        ts = M.timestamp;
        fin = ~isnan(ts);
        d_ts = diff(ts(fin));
        r.timestamp_monotonic = isempty(d_ts) || all(d_ts >= -1e-12);
        rx_ok = all(M.t_rx(fin) >= ts(fin) - 1e-12);
        r.rx_after_timestamp = rx_ok;
        r.delay_exact = isempty(ts(fin)) || ...
            max(abs((M.t_rx(fin) - ts(fin)) - ch.delay_s)) < 1e-12;
        r.stale_nonneg = all(M.stale_age(fin) >= -1e-12);
        r.timing_ok = r.timestamp_monotonic && r.rx_after_timestamp && ...
            r.delay_exact && r.stale_nonneg;

        % --- sequence monotonic, unit increments -------------------------
        d_seq = diff(M.seq);
        r.seq_monotonic = all(d_seq >= 0);
        r.seq_unit_steps = all(ismember(unique(d_seq(:)'), [0 1]));
        r.seq_total = M.seq(end);
        r.seq_valid_total = M.seq_valid(end);
        r.seq_ok = r.seq_monotonic && r.seq_unit_steps && r.seq_total > 0;

        % --- achieved rate within one base tick --------------------------
        d_ev = diff(M.event_t_sched);
        r.n_events = numel(M.event_t);
        r.n_events_scheduled = numel(M.event_t_sched);
        if isempty(d_ev)
            r.period_err_max = Inf;
        else
            r.period_err_max = max(abs(d_ev - ch.period_s));
        end
        r.rate_ok = r.period_err_max <= dt + 1e-12 && ...
            abs(1 / M.rate_hz_achieved - ch.period_s) <= dt + 1e-12;

        % --- finite and bounded ------------------------------------------
        rows = any(~isnan(M.value), 2);
        Vv = M.value(rows, :);
        r.all_finite = all(isfinite(Vv(:)));
        r.within_bounds = isempty(Vv) || ...
            (min(Vv(:)) >= ch.bound_lo - 1e-9 && max(Vv(:)) <= ch.bound_hi + 1e-9);
        r.finite_ok = r.all_finite && r.within_bounds;
        r.value_min = min_or_nan(Vv);
        r.value_max = max_or_nan(Vv);

        % --- explicit truth vs measured errors ---------------------------
        truth = truth_for_channel(nm, T);
        idx_ts = round(ts / dt) + 1;
        good = fin & idx_ts >= 1 & idx_ts <= T.N;
        e_ts = M.value(good, :) - truth(idx_ts(good), :);
        e_bus = M.value(good, :) - truth(good, :);
        if strcmp(nm, 'heading_compass')
            e_ts = wrap_pi(e_ts);
            e_bus = wrap_pi(e_bus);
        end
        r.err_vs_truth_at_ts = err_stats(e_ts);
        r.err_vs_truth_at_bus = err_stats(e_bus);

        % --- no truth leakage: measurement never equals truth ------------
        r.n_exact_truth_matches = sum(all(abs(e_ts) < 1e-15, 2));
        r.min_abs_err = min_or_nan(abs(e_ts));
        r.leak_ok = r.n_exact_truth_matches == 0 && r.min_abs_err > 0;

        ok_timing = ok_timing && r.timing_ok;
        ok_rate = ok_rate && r.rate_ok;
        ok_finite = ok_finite && r.finite_ok;
        ok_leak = ok_leak && r.leak_ok;
        ok_seq = ok_seq && r.seq_ok;
        per.(nm) = r;
    end
    V.per_channel = per;

    % --- frame / sign identities -----------------------------------------
    fs = struct();
    fs.nu_r_identity_resid = T.identity_nu_r_resid;
    fs.nu_r_identity_ok = T.identity_nu_r_resid < 1e-12;

    Rres = 0;
    for k = 1:50:T.N
        R = rot_body2ned(T.euler(k, 1), T.euler(k, 2), T.euler(k, 3));
        Rres = max(Rres, max(abs(T.nu_r_body(k, :)' - R' * (T.V_g_ned(k, :) - T.Vc_ned)')));
    end
    fs.nu_r_vs_R_transpose_resid = Rres;
    fs.nu_r_frame_ok = Rres < 1e-9;

    % All identity checks below compare a latched sample against truth at
    % that sample's own timestamp, so transport delay and ZOH lag cannot be
    % mistaken for a frame or sign error.

    % Depth sign: NED-down positive, measurement tracks truth z with the
    % declared positive bias (never the negated sign).
    Md = B.meas.depth_pressure;
    [Yz, Xz] = aligned(Md, T.eta_ned(:, 3), T, dt);
    fs.depth_bias_est = mean(Yz - Xz);
    fs.depth_sign_ok = fs.depth_bias_est > 0 && ...
        abs(fs.depth_bias_est - Md.spec.bias) < 0.02;
    fs.depth_corr_sign = sign_corr(Yz, Xz);

    % DVL is water-relative: under Vc ~= 0 it must separate from ground BODY
    % velocity by ~|Vc| while staying close to nu_r.
    Mv = B.meas.dvl_vel_body_water;
    [Yv, Xvr, selv] = aligned(Mv, T.nu_r_body, T, dt);
    if any(selv)
        idxv = round(Mv.timestamp(selv) / dt) + 1;
        fs.dvl_err_vs_water_rms = rms_all(Yv - Xvr);
        fs.dvl_err_vs_ground_rms = rms_all(Yv - T.nu_body(idxv, :));
    else
        fs.dvl_err_vs_water_rms = NaN;
        fs.dvl_err_vs_ground_rms = NaN;
    end
    Vcn = norm(T.Vc_ned);
    if Vcn > 1e-9
        fs.dvl_water_frame_ok = fs.dvl_err_vs_ground_rms > 2.5 * fs.dvl_err_vs_water_rms;
        fs.dvl_separation_expected = Vcn;
    else
        fs.dvl_water_frame_ok = fs.dvl_err_vs_water_rms < 0.10;
        fs.dvl_separation_expected = 0;
    end

    % INS is ground-relative: it must track V_g_ned, not V_w_ned.
    Mi = B.meas.ins_vel_ned;
    [Yi, Xig, seli] = aligned(Mi, T.V_g_ned, T, dt);
    idxi = round(Mi.timestamp(seli) / dt) + 1;
    fs.ins_err_vs_ground_rms = rms_all(Yi - Xig);
    fs.ins_err_vs_water_rms = rms_all(Yi - T.V_w_ned(idxi, :));
    if Vcn > 1e-9
        fs.ins_ground_frame_ok = fs.ins_err_vs_water_rms > 2.5 * fs.ins_err_vs_ground_rms;
    else
        fs.ins_ground_frame_ok = fs.ins_err_vs_ground_rms < 0.15;
    end

    % Heading is yaw, not course; under current they must differ.
    Mh = B.meas.heading_compass;
    [Yh, Xh, selh] = aligned(Mh, T.euler(:, 3), T, dt);
    idxh = round(Mh.timestamp(selh) / dt) + 1;
    fs.heading_minus_yaw_mean = mean(wrap_pi(Yh - Xh));
    fs.heading_minus_course_mean = mean(wrap_pi(Yh - T.course_ned(idxh)));
    fs.crab_mean_deg = rad2deg(mean(T.crab_angle));
    fs.heading_yaw_ok = abs(fs.heading_minus_yaw_mean - Mh.spec.bias) < deg2rad(0.5);

    % IMU specific force must include gravity (never be raw acceleration).
    fs.accel_mean_norm = mean(sqrt(sum(T.f_body.^2, 2)));
    fs.accel_gravity_ok = abs(fs.accel_mean_norm - cfg.g_ned) < 0.5;

    fs.all_ok = fs.nu_r_identity_ok && fs.nu_r_frame_ok && fs.depth_sign_ok && ...
        fs.dvl_water_frame_ok && fs.ins_ground_frame_ok && fs.heading_yaw_ok && ...
        fs.accel_gravity_ok;
    V.frame_sign = fs;

    % --- dropout / stale / quality transitions ---------------------------
    dr = struct();
    dr.dvl_outage_declared = T.dvl_outage;
    dr.outage_window = T.outage_window;
    dr.n_valid_dvl = sum(Mv.valid);
    dr.n_dropout_dvl = sum(Mv.status == 4);
    dr.n_stale_dvl = sum(Mv.status == 3);
    dr.n_init_dvl = sum(Mv.status == 1);
    if T.dvl_outage
        w = t >= T.outage_window(1) & t <= T.outage_window(2);
        settle = Mv.spec.stale_limit_s + Mv.spec.period_s;
        w_in = w & t >= T.outage_window(1) + settle;
        dr.invalid_during_outage = ~any(Mv.valid(w_in));
        dr.quality_zero_during_outage = all(Mv.quality(w_in) == 0);
        sa = Mv.stale_age(w_in);
        dr.stale_monotonic_during_outage = all(diff(sa) >= -1e-12);
        dr.stale_max_during_outage = max(sa);
        post = t > T.outage_window(2) + Mv.spec.delay_s + 2 * Mv.spec.period_s;
        dr.recovered_after_outage = any(Mv.valid(post));
        qpost = Mv.quality(post & Mv.valid);
        dr.quality_ramp_observed = ~isempty(qpost) && min(qpost) < Mv.spec.q_nom - 1e-9 ...
            && max(qpost) >= Mv.spec.q_nom - 1e-9;
        dr.dropout_seen = dr.n_dropout_dvl > 0 && dr.n_stale_dvl > 0;
        % The availability state machine must degrade in order:
        % OK -> STALE -> DROPOUT, never straight to DROPOUT.
        t_stale = min(t(Mv.status == 3));
        t_drop = min(t(Mv.status == 4));
        dr.stale_before_dropout = ~isempty(t_stale) && ~isempty(t_drop) && t_stale < t_drop;
        dr.ok = dr.invalid_during_outage && dr.quality_zero_during_outage && ...
            dr.stale_monotonic_during_outage && dr.recovered_after_outage && ...
            dr.quality_ramp_observed && dr.dropout_seen && dr.stale_before_dropout;
    else
        dr.invalid_during_outage = NaN;
        dr.quality_zero_during_outage = NaN;
        dr.stale_monotonic_during_outage = NaN;
        dr.stale_max_during_outage = max(Mv.stale_age(isfinite(Mv.stale_age)));
        dr.recovered_after_outage = NaN;
        dr.quality_ramp_observed = NaN;
        dr.dropout_seen = dr.n_dropout_dvl > 0;
        dr.stale_before_dropout = NaN;
        % Nominal case contract: continuous bottom lock, no degradation.
        dr.ok = dr.n_dropout_dvl == 0 && dr.n_stale_dvl == 0 && ...
            dr.n_valid_dvl > 0 && ...
            max(Mv.stale_age(Mv.valid)) <= Mv.spec.stale_limit_s + 1e-12;
    end

    Mu = B.meas.usbl_pos_ned;
    dr.usbl_present = Mu.present;
    dr.usbl_always_invalid = ~any(Mu.valid) && all(Mu.quality == 0) && ...
        all(Mu.status == 0) && all(isnan(Mu.value(:)));
    dr.ok = dr.ok && ~dr.usbl_present && dr.usbl_always_invalid;
    V.dropout = dr;

    % --- ESTIMATED bus must stay invalid ---------------------------------
    eb = struct();
    fn = B.est_fields;
    all_nan = true; all_invalid = true; all_unavail = true;
    for i = 1:numel(fn)
        e = B.est.(fn{i});
        all_nan = all_nan && all(isnan(e.value));
        all_invalid = all_invalid && ~e.valid && ~any(e.valid_series) && e.quality == 0;
        all_unavail = all_unavail && strcmp(e.status, 'UNAVAILABLE');
    end
    eb.n_fields = numel(fn);
    eb.all_values_nan = all_nan;
    eb.all_invalid = all_invalid;
    eb.all_unavailable = all_unavail;
    eb.ok = all_nan && all_invalid && all_unavail;
    V.estimated = eb;

    V.gates = struct( ...
        'timing_monotonic', ok_timing, ...
        'sequence_monotonic', ok_seq, ...
        'rate_within_one_base_tick', ok_rate, ...
        'frame_sign_identities', fs.all_ok, ...
        'no_truth_leakage', ok_leak, ...
        'dropout_stale_quality', dr.ok, ...
        'finite_bounded', ok_finite, ...
        'estimated_invalid', eb.ok);
    V.pass = all(struct2array_logical(V.gates));
end

function [Y, X, sel] = aligned(M, truthMat, T, dt)
% Latched samples paired with truth at the sample's own timestamp.
    sel = M.valid & ~isnan(M.timestamp);
    idx = round(M.timestamp / dt) + 1;
    sel = sel & idx >= 1 & idx <= T.N;
    Y = M.value(sel, :);
    X = truthMat(idx(sel), :);
end

function truth = truth_for_channel(nm, T)
    switch nm
        case 'imu_gyro';            truth = T.omega_body;
        case 'imu_accel';           truth = T.f_body;
        case 'dvl_vel_body_water';  truth = T.nu_r_body;
        case 'depth_pressure';      truth = T.eta_ned(:, 3);
        case 'heading_compass';     truth = T.euler(:, 3);
        case 'ins_vel_ned';         truth = T.V_g_ned;
        case 'usbl_pos_ned';        truth = T.eta_ned;
        otherwise; error('truth_for_channel: unhandled %s', nm);
    end
end

%% ===================== compare pack (determinism) =====================
function P = pack_compare(B)
% Compact but complete numeric fingerprint of a run, used for the
% order/reset/replay sentinels via isequaln.
    P = struct();
    P.route = B.route;
    P.Vc_ned = B.Vc_ned;
    P.dvl_outage = B.dvl_outage;
    P.seed = B.seed;
    for i = 1:numel(B.channel_names)
        nm = B.channel_names{i};
        M = B.meas.(nm);
        P.ch.(nm) = struct('value', M.value, 'timestamp', M.timestamp, ...
            't_rx', M.t_rx, 'seq', M.seq, 'seq_valid', M.seq_valid, ...
            'valid', M.valid, 'quality', M.quality, ...
            'stale_age', M.stale_age, 'status', M.status);
    end
end

%% ===================== small helpers =====================
function s = setdef(s, f, v)
    if ~isfield(s, f) || isempty(s.(f)); s.(f) = v; end
end

function y = wrap_pi(x)
    y = mod(x + pi, 2 * pi) - pi;
    y(y == -pi & x > 0) = pi;
end

function st = err_stats(e)
    st = empty_stats();
    if isempty(e); return; end
    st.n = size(e, 1);
    st.mean = mean(e, 1);
    st.rms = sqrt(mean(e.^2, 1));
    st.max_abs = max(abs(e), [], 1);
    st.rms_all = sqrt(mean(e(:).^2));
    st.max_all = max(abs(e(:)));
end

function st = empty_stats()
    st = struct('n', 0, 'mean', NaN, 'rms', NaN, 'max_abs', NaN, ...
        'rms_all', NaN, 'max_all', NaN);
end

function v = rms_all(e)
    if isempty(e); v = NaN; else; v = sqrt(mean(e(:).^2)); end
end

function v = min_or_nan(x)
    if isempty(x); v = NaN; else; v = min(x(:)); end
end

function v = max_or_nan(x)
    if isempty(x); v = NaN; else; v = max(x(:)); end
end

function c = sign_corr(a, b)
    a = a(:) - mean(a(:));
    b = b(:) - mean(b(:));
    if isempty(a) || std(a) < 1e-12 || std(b) < 1e-12
        c = NaN;
    else
        c = sum(a .* b) / sqrt(sum(a.^2) * sum(b.^2));
    end
end

function v = struct2array_logical(s)
    f = fieldnames(s);
    v = false(1, numel(f));
    for i = 1:numel(f)
        v(i) = logical(s.(f{i}));
    end
end
