function varargout = navigation_multirate_ekf_availability(action, varargin)
% NAVIGATION_MULTIRATE_EKF_AVAILABILITY  Isolated Gate 5C estimator fork.
%
% TASK_ID NAV_AVAILABILITY_OUTAGE_STRESS_001.
%
% WHAT THIS IS
%   A FORK of the frozen Gate 5B estimator library
%   navigation_multirate_ekf_baseline.m. The Gate 5B file is an INPUT and is
%   never modified. This fork adds exactly two things and changes nothing
%   else:
%
%     (1) an OPTIONAL USBL NED-position update, fused only when the bus
%         declares the channel present and the packet passes every interface
%         admission test that already governed the other channels;
%     (2) a HEALTH-ONLY availability state machine over
%         NOMINAL / DEGRADED / POSITION_AID_LOST / RECOVERING.
%
%   Everything else - the 18-state error-state formulation, propagation,
%   Joseph update, reset Jacobian, quaternion renormalisation, heading
%   wrapping, the truth firewall, the admission order and the manager
%   counters - is carried over verbatim from Gate 5B.
%
% HEALTH IS STATUS ONLY (hard contract)
%   The state machine is a PURE FUNCTION of the estimator's own accept log
%   and of the declared interface metadata, and it is evaluated AFTER the
%   tick loop has finished. It therefore cannot, by construction, alter one
%   propagation, one gain, one covariance entry or one admission decision.
%   No accommodation, no reconfiguration, no surface command, no reset. The
%   caller can disable it (opts.fsm = false) or perturb its thresholds
%   (opts.fsm_scale) and the estimated state pack is bitwise unchanged; the
%   driver executes both of those ablations as evidence.
%
% TRUTH BLINDNESS (unchanged hard contract)
%   'run' receives a MEASURED bus ONLY and sanitizes it at the door to an
%   explicit interface whitelist. The USBL simulator in the harness is
%   allowed to read TRUTH to FORM its MEASURED packets - that is what a
%   simulator is - but the packets handed here carry only value / timestamp /
%   t_rx / seq / valid / quality / stale_age / status plus ICD spec metadata.
%   Any truth-side field the harness attaches to the bus or to a channel is
%   dropped by sanitize_bus before an estimator statement can see it. TRUTH
%   is touched exclusively by 'metrics', which is post-hoc scoring.
%
% IMPLEMENTED
%   - 18 error states: dp(3) NED [m], dv(3) NED [m/s], dtheta(3) BODY [rad],
%     dbg(3) BODY [rad/s], dba(3) BODY [m/s^2], dc(3) NED [m/s].
%   - Aiding: depth [m], heading [rad], INS velocity NED [m/s], DVL BODY
%     water-relative [m/s], and NEW: USBL position NED [m], h = p_NED.
%   - Availability state machine with per-channel stale-age thresholds,
%     dwell timers and asymmetric entry/exit thresholds (hysteresis).
%
% DERIVED
%   sigma_a, sigma_g from the declared ASSUMED discrete sensor sigma and
%   rate. Per-channel freshness horizon tau_fresh from the declared ASSUMED
%   ICD period / stale limit and an ASSUMED multiplier.
%
% ASSUMED
%   Every Q, R, P0, admission threshold, latency scale, freshness multiplier
%   and state-machine dwell time. The upstream sensor numerics are themselves
%   ASSUMED, so nothing here can be IDENTIFIED and nothing is tuned per case.
%
% CLAIM LIMIT
%   Integrity, interface and state-machine behaviour only. Accuracy and
%   outage-drift numbers are CHARACTERIZATION and NOT_CERTIFIED.
%   Simulation-only. No promotion.
%
% Usage
%   cfg = navigation_multirate_ekf_availability('config');
%   E   = navigation_multirate_ekf_availability('run', B, cfg, opts);
%   G   = navigation_multirate_ekf_availability('gates', E, cfg);
%   M   = navigation_multirate_ekf_availability('metrics', T, E, cfg, prof);
%   P   = navigation_multirate_ekf_availability('pack', E);
%   I   = navigation_multirate_ekf_availability('injections', B, cfg);

    switch lower(action)
        case 'config';       varargout{1} = default_config();
        case 'sanitize';     varargout{1} = sanitize_bus(varargin{:});
        case 'run';          varargout{1} = run_filter(varargin{:});
        case 'gates';        varargout{1} = integrity_gates(varargin{:});
        case 'metrics';      varargout{1} = accuracy_metrics(varargin{:});
        case 'pack';         varargout{1} = pack_estimate(varargin{:});
        case 'injections';   varargout{1} = build_injections(varargin{:});
        case 'statusnames';  varargout{1} = est_status_names();
        case 'healthnames';  varargout{1} = health_state_names();
        case 'fsm';          varargout{1} = availability_fsm(varargin{:});
        otherwise
            error('navigation_multirate_ekf_availability: unknown action "%s"', action);
    end
end

%% ===================== configuration (predeclared, ASSUMED) =====================
function cfg = default_config()
    cfg = struct();
    cfg.task_id = 'NAV_AVAILABILITY_OUTAGE_STRESS_001';
    cfg.gate = '5C';
    cfg.forked_from = 'navigation_multirate_ekf_baseline.m (Gate 5B, frozen, unmodified)';
    cfg.n_err = 18;
    cfg.idx = struct('p', 1:3, 'v', 4:6, 'th', 7:9, 'bg', 10:12, 'ba', 13:15, 'c', 16:18);
    cfg.state_names = {'p_N','p_E','p_D','v_N','v_E','v_D', ...
        'th_x','th_y','th_z','bg_x','bg_y','bg_z','ba_x','ba_y','ba_z','c_N','c_E','c_D'};
    cfg.state_units = {'m','m','m','m/s','m/s','m/s','rad','rad','rad', ...
        'rad/s','rad/s','rad/s','m/s^2','m/s^2','m/s^2','m/s','m/s','m/s'};
    cfg.state_frames = {'NED','NED','NED','NED','NED','NED','BODY','BODY','BODY', ...
        'BODY','BODY','BODY','BODY','BODY','BODY','NED','NED','NED'};

    cfg.g_ned = 9.81;                       % m/s^2  ASSUMED (NED, down positive)

    % ---- channel roles ---------------------------------------------------
    cfg.imu_gyro_channel = 'imu_gyro';
    cfg.imu_accel_channel = 'imu_accel';
    cfg.update_order = {'depth_pressure', 'heading_compass', 'ins_vel_ned', ...
        'dvl_vel_body_water', 'usbl_pos_ned'};
    cfg.all_channels = [{cfg.imu_gyro_channel, cfg.imu_accel_channel}, cfg.update_order];
    % GATE 5C CHANGE: USBL is an OPTIONAL aiding channel instead of a
    % never-fuse channel. It is fused only when the bus declares it present.
    cfg.aiding_channels = {'depth_pressure', 'heading_compass', 'ins_vel_ned', ...
        'dvl_vel_body_water', 'usbl_pos_ned'};
    cfg.never_fuse_channels = {};
    cfg.optional_channels = {'usbl_pos_ned'};
    cfg.abs_position_channels = {'usbl_pos_ned'};
    cfg.init_required = {'imu_gyro', 'imu_accel', 'depth_pressure', ...
        'heading_compass', 'ins_vel_ned'};   % USBL is NEVER required for init

    % ---- process noise (unchanged from Gate 5B) --------------------------
    cfg.Q = struct( ...
        'sigma_p',  0.0,      ...  % m/sqrt(s)       ASSUMED
        'sigma_a',  2.0e-3,   ...  % m/s^2/sqrt(Hz)  DERIVED 0.020*sqrt(0.01)
        'sigma_g',  3.5e-4,   ...  % rad/s/sqrt(Hz)  DERIVED 0.0035*sqrt(0.01)
        'sigma_bg', 1.0e-5,   ...  % rad/s/sqrt(s)   ASSUMED
        'sigma_ba', 1.0e-4,   ...  % m/s^2/sqrt(s)   ASSUMED
        'sigma_c',  1.0e-3);       % m/s/sqrt(s)     ASSUMED
    cfg.Q_provenance = ['Identical to Gate 5B. sigma_a / sigma_g DERIVED from the declared ', ...
        'ASSUMED discrete sensor sigma and rate; sigma_bg / sigma_ba / sigma_c ASSUMED.'];

    % ---- measurement noise (ASSUMED, equal to the declared sensor sigma) --
    cfg.R = struct( ...
        'depth_pressure',      0.020^2, ...
        'heading_compass',     deg2rad(0.5)^2, ...
        'ins_vel_ned',         diag([0.020 0.020 0.030].^2), ...
        'dvl_vel_body_water',  diag([0.010 0.010 0.015].^2), ...
        'usbl_pos_ned',        diag([1.50 1.50 0.80].^2));
    cfg.R_provenance = ['ASSUMED, numerically equal to the declared ASSUMED sensor sigma of ', ...
        'each channel. The USBL R equals the declared USBL simulator sigma [1.50 1.50 0.80] m ', ...
        'NED and is NOT inflated to absorb the declared USBL bias, because inflating R until ', ...
        'NIS looks consistent would be tuning. Never case-specific.'];

    % Latency-aware R inflation: sigma = scale * residual age.
    cfg.lat_scale = struct( ...
        'depth_pressure',      0.60, ...   % m/s     ASSUMED vertical rate scale
        'heading_compass',     0.30, ...   % rad/s   ASSUMED yaw rate scale
        'ins_vel_ned',         0.50, ...   % m/s^2   ASSUMED acceleration scale
        'dvl_vel_body_water',  0.50, ...   % m/s^2   ASSUMED acceleration scale
        'usbl_pos_ned',        1.50);      % m/s     DERIVED = declared ASSUMED U_ground
    cfg.lat_scale_provenance = ['USBL latency scale is a SPEED because the residual of a ', ...
        'delayed position fix grows as speed x age. It is set to the declared ASSUMED chain ', ...
        'ground speed U_ground = 1.50 m/s; the driver asserts that equality.'];

    % ---- initial covariance (ASSUMED) ------------------------------------
    % GATE 5C CHANGE: horizontal position P0 is keyed to whether the bus
    % declares an ABSOLUTE position channel present. With no absolute fix the
    % estimator defines its own origin and P0 expresses conditioning of the
    % RELATIVE solution (the Gate 5B value). With USBL present the absolute
    % origin is genuinely unknown at initialization and P0 must say so, or
    % the first honest absolute fix would be thrown out by the divergence
    % guard. This is a structural switch on a declared INTERFACE field
    % (spec.present), predeclared and identical for every case, not a tuned
    % or result-dependent constant.
    cfg.P0 = struct( ...
        'p',      [0.10 0.10 0.50].^2, ...
        'p_abs',  100.0^2, ...
        'v',      [0.30 0.30 0.30].^2, ...
        'th',     deg2rad([2 2 3]).^2, ...
        'bg',     [0.010 0.010 0.010].^2, ...
        'ba',     [0.050 0.050 0.050].^2, ...
        'c',      [0.50 0.50 0.50].^2);
    cfg.P0_provenance = ['ASSUMED. p is the Gate 5B relative-solution conditioning term, used ', ...
        'for N/E when no absolute position channel is present. p_abs = (100 m)^2 is the ', ...
        'ASSUMED absolute-origin ignorance used for N/E when an absolute position channel IS ', ...
        'present. The vertical term is unchanged in both cases because depth is always aided.'];

    % ---- admission gates (ASSUMED thresholds, immutable across cases) -----
    cfg.q_min_frac = 0.20;
    cfg.q_floor = 0.20;
    cfg.nis_scale = 100;
    cfg.nis_note = ['Divergence guard only, deliberately loose, unchanged from Gate 5B: R is ', ...
        'ASSUMED and the declared sensor biases are unmodelled, so a tight chi-square gate ', ...
        'would reject structurally-biased-but-healthy packets and amount to tuning.'];
    cfg.dt_prop_max = 0.050;
    cfg.dt_prop_sub = 0.010;
    cfg.source_window_s = 2.0;
    cfg.reacq_gap_s = 1.0;
    cfg.tol_time = 1e-12;
    cfg.tol_pair = 1e-9;

    cfg.reject_reasons = {'channel_absent', 'not_valid', 'nonfinite_value', ...
        'out_of_bounds', 'low_quality', 'stale_age', 'seq_not_increasing', ...
        'timestamp_not_increasing', 'imu_pair_mismatch', 'not_initialized', ...
        'innovation_gate', 'never_fuse_policy'};

    % ---- availability state machine (predeclared, ASSUMED / DERIVED) -----
    % Freshness horizon per channel, DERIVED at run time from that channel's
    % declared ASSUMED ICD period and stale limit:
    %     tau_fresh = max(k_fresh * period, stale_limit + period, tau_floor)
    cfg.fsm = struct( ...
        'k_fresh',    4.0,  ...   % [-] ASSUMED periods of tolerated silence
        'tau_floor',  1.00, ...   % s   ASSUMED minimum freshness horizon
        'T_degrade',  0.50, ...   % s   ASSUMED dwell: any required aid stale -> DEGRADED
        'T_lost',     2.00, ...   % s   ASSUMED dwell: no position aid       -> POSITION_AID_LOST
        'T_reacq',    0.50, ...   % s   ASSUMED dwell: position aid back     -> RECOVERING
        'T_clear',    1.00, ...   % s   ASSUMED dwell: all aids fresh        -> DEGRADED to NOMINAL
        'T_settle',   3.00);      % s   ASSUMED dwell: all aids fresh        -> RECOVERING to NOMINAL
    cfg.fsm_policy = [ ...
        'Health states, deterministic and hysteretic. POSITION AID means a bottom- or ', ...
        'world-referenced position aid: DVL water/bottom-referenced velocity and USBL ', ...
        'absolute position. INS velocity is deliberately NOT counted as a position aid, ', ...
        'because it is an inertial mechanization output that drifts with the same errors ', ...
        'the position solution is accumulating. REQUIRED AID means every aiding channel the ', ...
        'bus declares present. Allowed transitions, and no others: NOMINAL->DEGRADED, ', ...
        'DEGRADED->POSITION_AID_LOST, DEGRADED->NOMINAL, POSITION_AID_LOST->RECOVERING, ', ...
        'RECOVERING->POSITION_AID_LOST, RECOVERING->NOMINAL. POSITION_AID_LOST is therefore ', ...
        'unreachable without passing through DEGRADED first, and NOMINAL is unreachable ', ...
        'after a loss without passing through RECOVERING first. Hysteresis is by asymmetric ', ...
        'dwell: 0.50 s of staleness to degrade against 1.00 s of freshness to clear; 2.00 s ', ...
        'of position-aid loss to declare against 0.50 s of position aid to start recovering ', ...
        'and 3.00 s of full freshness to settle. Output is STATUS ONLY.'];
    cfg.fsm_authority = ['NONE. The state machine emits status. It performs no accommodation, ', ...
        'no covariance inflation, no gain change, no channel reconfiguration, no filter reset ', ...
        'and no surface or abort command. It is evaluated after the tick loop as a pure ', ...
        'function of the accept log, so it cannot influence the estimate even in principle.'];
    cfg.health_state_names = health_state_names();

    cfg.est_status_names = est_status_names();
    cfg.est_fields = {'pos_ned', 'vel_ned', 'vel_body_water', 'euler', ...
        'gyro_bias', 'accel_bias', 'current_ned'};
    cfg.est_field_frames = {'NED', 'NED', 'BODY', 'EULER', 'BODY', 'BODY', 'NED'};
    cfg.est_field_units = {'m', 'm/s', 'm/s', 'rad', 'rad/s', 'm/s^2', 'm/s'};
    cfg.est_policy = ['Gate 5C ESTIMATED bus becomes VALID only after explicit initialization ', ...
        'from admitted MEASURED packets, and stays valid across every declared outage: loss ', ...
        'of aiding degrades the health state, it never invalidates or resets the estimate. ', ...
        'Accuracy is CHARACTERIZATION ONLY and NOT_CERTIFIED.'];
    cfg.claim_limit = ['Integrity, interface and availability state-machine behaviour only. ', ...
        'No navigation-accuracy and no outage-endurance claim. Simulation-only; nothing here ', ...
        'is bench or sea-trial validated.'];

    cfg.bus_whitelist = {'t', 'N', 'dt_base', 'channel_names', 'meas'};
    cfg.packet_whitelist = {'value', 'timestamp', 't_rx', 'seq', 'valid', ...
        'quality', 'stale_age', 'status'};
    cfg.spec_whitelist = {'name', 'dim', 'frame', 'units', 'present', ...
        'rate_hz', 'period_s', 'delay_s', 'q_nom', 'bound_lo', 'bound_hi', ...
        'stale_limit_s', 'dropout_limit_s'};
    cfg.truth_forbidden = {'Vc_ned', 'dvl_outage', 'seed', 'route', 'label', ...
        'eta_ned', 'euler', 'V_g_ned', 'V_w_ned', 'nu_body', 'nu_r_body', ...
        'nu_c_body', 'omega_body', 'f_body', 'a_ned', 'altitude', ...
        'bottom_lock', 'outage_window', 'crab_angle', 'course_ned', ...
        'psi_unwrapped', 'identity_nu_r_resid', 'usbl_truth_ref', 'profile', ...
        'gap_windows', 'usbl_schedule'};
end

function n = est_status_names()
    n = {'UNAVAILABLE', 'INIT_WAIT', 'OK', 'DEGRADED', 'DEAD_RECKONING'};
end

function n = health_state_names()
% Index = code + 1. Code 0 is pre-initialization and is not one of the four
% declared health states.
    n = {'UNINITIALIZED', 'NOMINAL', 'DEGRADED', 'POSITION_AID_LOST', 'RECOVERING'};
end

%% ===================== bus sanitisation (truth firewall) =====================
function S = sanitize_bus(B, cfg)
% Copy ONLY the consumer-visible interface fields. Everything the harness
% carries for bookkeeping - including anything the USBL simulator attaches
% to record which TRUTH sample a packet was formed from - is dropped here.
    S = struct();
    S.t = B.t(:);
    S.N = numel(S.t);
    S.dt_base = B.dt_base;
    S.channel_names = cfg.all_channels;
    meas = struct();
    for i = 1:numel(cfg.all_channels)
        nm = cfg.all_channels{i};
        if ~isfield(B.meas, nm)
            error('sanitize_bus: required channel %s missing from bus', nm);
        end
        M = B.meas.(nm);
        m = struct();
        for j = 1:numel(cfg.packet_whitelist)
            f = cfg.packet_whitelist{j};
            m.(f) = M.(f);
        end
        sp = struct();
        for j = 1:numel(cfg.spec_whitelist)
            f = cfg.spec_whitelist{j};
            sp.(f) = M.spec.(f);
        end
        m.spec = sp;
        meas.(nm) = m;
    end
    S.meas = meas;
    S.sanitized = true;
    S.dropped_truth_fields = cfg.truth_forbidden;
end

%% ===================== estimator =====================
function E = run_filter(B, cfg, opts)
    if nargin < 3 || isempty(opts); opts = struct(); end
    if ~isfield(opts, 'inject');    opts.inject = empty_inject(); end
    if ~isfield(opts, 'tag');       opts.tag = ''; end
    if ~isfield(opts, 'fsm');       opts.fsm = true; end
    if ~isfield(opts, 'fsm_scale'); opts.fsm_scale = 1.0; end

    % ---------------- TRUTH FIREWALL -------------------------------------
    bus = sanitize_bus(B, cfg);
    clear B;                       % the raw bus is unreachable from here on
    % ---------------------------------------------------------------------

    t = bus.t; N = bus.N;
    ip = cfg.idx.p; iv = cfg.idx.v; ith = cfg.idx.th;
    ibg = cfg.idx.bg; iba = cfg.idx.ba; icu = cfg.idx.c;
    nx = cfg.n_err;
    chans = cfg.all_channels;
    nch = numel(chans);
    nup = numel(cfg.update_order);

    gyro_nm = cfg.imu_gyro_channel;
    accel_nm = cfg.imu_accel_channel;
    i_gyro = find(strcmp(chans, gyro_nm), 1);
    i_accel = find(strcmp(chans, accel_nm), 1);
    MC = cell(1, nch);
    STATUS = zeros(N, nch);
    DSEQ = zeros(N, nch);
    present = false(1, nch);
    period_s = zeros(1, nch);
    stale_lim = zeros(1, nch);
    for i = 1:nch
        MC{i} = bus.meas.(chans{i});
        STATUS(:, i) = MC{i}.status(:);
        s = MC{i}.seq(:);
        DSEQ(:, i) = [s(1); diff(s)];
        present(i) = logical(MC{i}.spec.present);
        period_s(i) = MC{i}.spec.period_s;
        stale_lim(i) = MC{i}.spec.stale_limit_s;
    end
    up_idx = zeros(1, nup);
    up_spec = cell(1, nup);
    up_never = false(1, nup);
    for u = 1:nup
        up_idx(u) = find(strcmp(chans, cfg.update_order{u}), 1);
        up_spec{u} = MC{up_idx(u)}.spec;
        up_never(u) = any(strcmp(cfg.update_order{u}, cfg.never_fuse_channels));
    end
    spec_gyro = MC{i_gyro}.spec;
    spec_accel = MC{i_accel}.spec;
    aid_idx = zeros(1, numel(cfg.aiding_channels));
    for i = 1:numel(cfg.aiding_channels)
        aid_idx(i) = find(strcmp(chans, cfg.aiding_channels{i}), 1);
    end
    abs_idx = zeros(1, numel(cfg.abs_position_channels));
    for i = 1:numel(cfg.abs_position_channels)
        abs_idx(i) = find(strcmp(chans, cfg.abs_position_channels{i}), 1);
    end
    abs_present = any(present(abs_idx));

    % ---- manager state ---------------------------------------------------
    mgr = struct();
    for i = 1:nch
        m = struct();
        m.name = chans{i};
        m.present = present(i);
        m.last_seq = 0;
        m.last_ts = -Inf;
        m.n_new = 0;
        m.n_admit = 0;
        m.n_reject_interface = 0;
        m.n_init_used = 0;
        m.n_reject_innov = 0;
        m.n_fused = 0;
        m.n_coalesced = 0;
        m.last_accept_t = -Inf;
        m.suppressed_ticks = sum(STATUS(:, i) ~= 2);
        for r = 1:numel(cfg.reject_reasons)
            m.reject.(cfg.reject_reasons{r}) = 0;
        end
        mgr.(chans{i}) = m;
    end

    % ---- nominal state ---------------------------------------------------
    S = struct('p', NaN(3,1), 'v', NaN(3,1), 'q', NaN(4,1), ...
        'bg', NaN(3,1), 'ba', NaN(3,1), 'c', NaN(3,1));
    P = NaN(nx);
    initialized = false;
    init_count = 0; init_tick = NaN; init_time = NaN;
    t_imu_last = NaN;
    ib = struct('gyro', [], 'accel', [], 'depth', [], 'heading', [], 'ins', []);

    % ---- logs ------------------------------------------------------------
    L = struct();
    L.p = NaN(3, N); L.v = NaN(3, N); L.euler = NaN(3, N);
    L.bg = NaN(3, N); L.ba = NaN(3, N); L.c = NaN(3, N);
    L.vbw = NaN(3, N); L.q = NaN(4, N);
    L.Pdiag = NaN(nx, N);
    L.valid = false(N, 1);
    L.status = zeros(N, 1);
    L.health = zeros(N, 1);
    L.est_seq = zeros(N, 1);
    L.est_time = NaN(N, 1);
    L.source_mask = zeros(N, 1);
    L.qnorm = NaN(N, 1);
    L.n_fused_tick = zeros(N, 1);
    L.chan_status = STATUS;
    L.chan_accept = false(N, nch);

    innov = struct();
    for u = 1:nup
        innov.(cfg.update_order{u}) = struct('t', [], 'ts', [], 'nu', [], ...
            'nis', [], 'sigma', [], 'quality', [], 'age', [], 'accepted', []);
    end

    audit = struct('n_fused_total', 0, 'all_fused_valid', true, ...
        'all_fused_quality_ok', true, 'all_fused_stale_ok', true, ...
        'all_fused_finite', true, 'n_fused_usbl', 0, 'n_fused_usbl_absent', 0, ...
        'violations', {{}});
    fused = struct('t', [], 'ch', {{}}, 'ts', [], 'seq', [], 'nis', []);
    reacq = struct('t', [], 'ch', {{}}, 'gap_s', [], 'dp', [], 'dv', [], 'innov', []);
    first_abs_fix = struct('found', false, 't', NaN, 'dp', NaN, 'dv', NaN, 'innov', NaN);

    cov_sym_max = 0; cov_mineig_min = Inf; qnorm_err_max = 0;
    n_prop = 0; n_prop_substep = 0; nan_seen = false;

    inj = opts.inject;
    n_inj = numel(inj);
    if n_inj > 0; inj_tick = [inj.tick]; else; inj_tick = []; end
    n_inj_rejected = 0; n_inj_admitted = 0; n_inj_fused = 0;
    inj_result = cell(n_inj, 1);

    src_last = -Inf(1, nch);

    for k = 1:N
        % ---------- IMU pair: propagate ----------------------------------
        ng = DSEQ(k, i_gyro);
        na = DSEQ(k, i_accel);
        if ng > 0
            pg = make_packet(MC{i_gyro}, k, gyro_nm);
            mgr.(gyro_nm).n_new = mgr.(gyro_nm).n_new + 1;
            mgr.(gyro_nm).n_coalesced = mgr.(gyro_nm).n_coalesced + (ng - 1);
        else
            pg = null_packet(gyro_nm);
        end
        if na > 0
            pa = make_packet(MC{i_accel}, k, accel_nm);
            mgr.(accel_nm).n_new = mgr.(accel_nm).n_new + 1;
            mgr.(accel_nm).n_coalesced = mgr.(accel_nm).n_coalesced + (na - 1);
        else
            pa = null_packet(accel_nm);
        end

        if ng > 0 || na > 0
            rg = admit_reason(pg, mgr.(gyro_nm), spec_gyro, cfg, ng > 0);
            ra = admit_reason(pa, mgr.(accel_nm), spec_accel, cfg, na > 0);
            paired = isempty(rg) && isempty(ra) && ...
                abs(pg.timestamp - pa.timestamp) <= cfg.tol_pair;
            if paired
                mgr.(gyro_nm) = commit(mgr.(gyro_nm), pg);
                mgr.(accel_nm) = commit(mgr.(accel_nm), pa);
                w_m = pg.value(:); f_m = pa.value(:);
                if initialized
                    dtp = pg.timestamp - t_imu_last;
                    if dtp > 0
                        if dtp > cfg.dt_prop_max
                            nsub = ceil(dtp / cfg.dt_prop_sub);
                            n_prop_substep = n_prop_substep + 1;
                        else
                            nsub = 1;
                        end
                        for sstep = 1:nsub
                            [S, P] = propagate(S, P, w_m, f_m, dtp / nsub, cfg);
                        end
                        n_prop = n_prop + 1;
                    end
                    mgr.(gyro_nm).n_fused = mgr.(gyro_nm).n_fused + 1;
                    mgr.(accel_nm).n_fused = mgr.(accel_nm).n_fused + 1;
                else
                    mgr.(gyro_nm).n_init_used = mgr.(gyro_nm).n_init_used + 1;
                    mgr.(accel_nm).n_init_used = mgr.(accel_nm).n_init_used + 1;
                end
                t_imu_last = pg.timestamp;
                ib.gyro = w_m; ib.accel = f_m;
                src_last(i_gyro) = t(k); src_last(i_accel) = t(k);
                L.chan_accept(k, i_gyro) = true;
                L.chan_accept(k, i_accel) = true;
                mgr.(gyro_nm).last_accept_t = t(k);
                mgr.(accel_nm).last_accept_t = t(k);
            else
                if ng > 0
                    if isempty(rg); rg = 'imu_pair_mismatch'; end
                    mgr.(gyro_nm) = reject_iface(mgr.(gyro_nm), rg);
                end
                if na > 0
                    if isempty(ra); ra = 'imu_pair_mismatch'; end
                    mgr.(accel_nm) = reject_iface(mgr.(accel_nm), ra);
                end
            end
        end

        % ---------- aiding updates ---------------------------------------
        has_inj = ~isempty(inj_tick) && any(inj_tick == k);
        for u = 1:nup
            nm = cfg.update_order{u};
            ci = up_idx(u);
            spec = up_spec{u};
            nn = DSEQ(k, ci);
            if nn <= 0 && ~has_inj; continue; end
            np = 0; plist = cell(1, 1 + n_inj); pidx = zeros(1, 1 + n_inj);
            if nn > 0
                mgr.(nm).n_new = mgr.(nm).n_new + 1;
                mgr.(nm).n_coalesced = mgr.(nm).n_coalesced + (nn - 1);
                np = np + 1; plist{np} = make_packet(MC{ci}, k, nm); pidx(np) = 0;
            end
            if has_inj
                for z = 1:n_inj
                    if inj(z).tick == k && strcmp(inj(z).ch, nm)
                        np = np + 1; plist{np} = inj(z); pidx(np) = z;
                        mgr.(nm).n_new = mgr.(nm).n_new + 1;
                    end
                end
            end

            for z = 1:np
                pkt = plist{z};
                zi = pidx(z);
                r = admit_reason(pkt, mgr.(nm), spec, cfg, true);
                if isempty(r) && up_never(u); r = 'never_fuse_policy'; end
                if ~isempty(r)
                    mgr.(nm) = reject_iface(mgr.(nm), r);
                    if zi > 0
                        n_inj_rejected = n_inj_rejected + 1;
                        inj_result{zi} = r;
                    end
                    continue;
                end
                mgr.(nm) = commit(mgr.(nm), pkt);
                if zi > 0
                    n_inj_admitted = n_inj_admitted + 1;
                    inj_result{zi} = 'ADMITTED';
                end

                if ~initialized
                    mgr.(nm).n_init_used = mgr.(nm).n_init_used + 1;
                    mgr.(nm).reject.not_initialized = mgr.(nm).reject.not_initialized + 1;
                    switch nm
                        case 'depth_pressure';   ib.depth = pkt.value(1);
                        case 'heading_compass';  ib.heading = pkt.value(1);
                        case 'ins_vel_ned';      ib.ins = pkt.value(:);
                    end
                    continue;
                end

                age = max(0, t_imu_last - pkt.timestamp);
                [Hm, nu, Rm] = measurement_model(nm, S, pkt, cfg, age, spec);
                d = numel(nu);
                Sm = Hm * P * Hm' + Rm;
                Sm = 0.5 * (Sm + Sm');
                nis = nu' * (Sm \ nu);
                sg = sqrt(diag(Sm))';

                acc = isfinite(nis) && nis <= cfg.nis_scale * d;
                innov.(nm).t(end+1, 1) = t(k);
                innov.(nm).ts(end+1, 1) = pkt.timestamp;
                innov.(nm).nu(end+1, 1:d) = nu(:)';
                innov.(nm).nis(end+1, 1) = nis;
                innov.(nm).sigma(end+1, 1:d) = sg;
                innov.(nm).quality(end+1, 1) = pkt.quality;
                innov.(nm).age(end+1, 1) = age;
                innov.(nm).accepted(end+1, 1) = acc;

                if ~acc
                    mgr.(nm).n_reject_innov = mgr.(nm).n_reject_innov + 1;
                    mgr.(nm).reject.innovation_gate = mgr.(nm).reject.innovation_gate + 1;
                    if zi > 0; inj_result{zi} = 'innovation_gate'; end
                    continue;
                end

                p_before = S.p; v_before = S.v;
                K = (P * Hm') / Sm;
                dx = K * nu;
                IKH = eye(nx) - K * Hm;
                P = IKH * P * IKH' + K * Rm * K';
                P = 0.5 * (P + P');
                dth = dx(ith);
                S.p = S.p + dx(ip);
                S.v = S.v + dx(iv);
                S.q = quat_norm(quat_mul(S.q, quat_from_rotvec(dth)));
                S.bg = S.bg + dx(ibg);
                S.ba = S.ba + dx(iba);
                S.c = S.c + dx(icu);
                Gr = eye(nx);
                Gr(ith, ith) = eye(3) - 0.5 * skew(dth);
                P = Gr * P * Gr';
                P = 0.5 * (P + P');

                mgr.(nm).n_fused = mgr.(nm).n_fused + 1;
                gap = t(k) - mgr.(nm).last_accept_t;
                if isfinite(mgr.(nm).last_accept_t) && gap > cfg.reacq_gap_s
                    reacq.t(end+1, 1) = t(k);
                    reacq.ch{end+1, 1} = nm;
                    reacq.gap_s(end+1, 1) = gap;
                    reacq.dp(end+1, 1) = norm(S.p - p_before);
                    reacq.dv(end+1, 1) = norm(S.v - v_before);
                    reacq.innov(end+1, 1) = norm(nu);
                end
                if strcmp(nm, 'usbl_pos_ned') && ~first_abs_fix.found
                    first_abs_fix.found = true;
                    first_abs_fix.t = t(k);
                    first_abs_fix.dp = norm(S.p - p_before);
                    first_abs_fix.dv = norm(S.v - v_before);
                    first_abs_fix.innov = norm(nu);
                end
                mgr.(nm).last_accept_t = t(k);
                src_last(ci) = t(k);
                L.chan_accept(k, ci) = true;
                L.n_fused_tick(k) = L.n_fused_tick(k) + 1;

                audit.n_fused_total = audit.n_fused_total + 1;
                fused.t(end+1, 1) = t(k);
                fused.ch{end+1, 1} = nm;
                fused.ts(end+1, 1) = pkt.timestamp;
                fused.seq(end+1, 1) = pkt.seq;
                fused.nis(end+1, 1) = nis;
                if zi > 0
                    n_inj_fused = n_inj_fused + 1;
                    inj_result{zi} = 'FUSED';
                end
                if strcmp(nm, 'usbl_pos_ned')
                    audit.n_fused_usbl = audit.n_fused_usbl + 1;
                    if ~spec.present
                        audit.n_fused_usbl_absent = audit.n_fused_usbl_absent + 1;
                        audit.violations{end+1} = sprintf( ...
                            'usbl_pos_ned fused while declared ABSENT at t=%.4f s', t(k));
                    end
                end
                if ~pkt.valid || pkt.status ~= 2
                    audit.all_fused_valid = false;
                    audit.violations{end+1} = sprintf('%s fused with status %d at t=%.4f s', ...
                        nm, pkt.status, t(k));
                end
                if pkt.quality < cfg.q_min_frac * spec.q_nom - cfg.tol_time
                    audit.all_fused_quality_ok = false;
                    audit.violations{end+1} = sprintf('%s fused with quality %.4f at t=%.4f s', ...
                        nm, pkt.quality, t(k));
                end
                if pkt.stale_age > spec.stale_limit_s + cfg.tol_time
                    audit.all_fused_stale_ok = false;
                    audit.violations{end+1} = sprintf('%s fused with stale_age %.4f s at t=%.4f s', ...
                        nm, pkt.stale_age, t(k));
                end
                if ~all(isfinite(pkt.value)) || ~isfinite(pkt.timestamp)
                    audit.all_fused_finite = false;
                    audit.violations{end+1} = sprintf('%s fused with non-finite payload at t=%.4f s', ...
                        nm, t(k));
                end
            end
        end

        % ---------- explicit initialization ------------------------------
        if ~initialized && ~isempty(ib.gyro) && ~isempty(ib.accel) && ...
                ~isempty(ib.depth) && ~isempty(ib.heading) && ~isempty(ib.ins)
            f0 = ib.accel(:);
            th0 = asin(max(-1, min(1, f0(1) / cfg.g_ned)));
            ph0 = atan2(-f0(2), -f0(3));
            ps0 = wrap_pi(ib.heading);
            S.p = [0; 0; ib.depth];
            S.v = ib.ins(:);
            S.q = quat_norm(euler2quat(ph0, th0, ps0));
            S.bg = zeros(3, 1);
            S.ba = zeros(3, 1);
            S.c = zeros(3, 1);
            if abs_present
                p0p = [cfg.P0.p_abs, cfg.P0.p_abs, cfg.P0.p(3)];
            else
                p0p = cfg.P0.p;
            end
            P = diag([p0p, cfg.P0.v, cfg.P0.th, cfg.P0.bg, cfg.P0.ba, cfg.P0.c]);
            initialized = true;
            init_count = init_count + 1;
            init_tick = k;
            init_time = t(k);
        end

        % ---------- log ---------------------------------------------------
        if initialized
            Rbn = quat2rot(S.q);
            L.p(:, k) = S.p; L.v(:, k) = S.v; L.q(:, k) = S.q;
            L.bg(:, k) = S.bg; L.ba(:, k) = S.ba; L.c(:, k) = S.c;
            L.euler(:, k) = rot2euler(Rbn);
            L.vbw(:, k) = Rbn' * (S.v - S.c);
            L.Pdiag(:, k) = diag(P);
            L.valid(k) = true;
            L.est_seq(k) = (k - init_tick) + 1;
            L.est_time(k) = t_imu_last;
            L.qnorm(k) = norm(S.q);
            qnorm_err_max = max(qnorm_err_max, abs(L.qnorm(k) - 1));
            cov_sym_max = max(cov_sym_max, max(max(abs(P - P'))));
            if mod(k, 10) == 0 || k == N
                cov_mineig_min = min(cov_mineig_min, min(real(eig(0.5 * (P + P')))));
            end
            if ~all(isfinite([S.p; S.v; S.q; S.bg; S.ba; S.c])) || ~all(isfinite(P(:)))
                nan_seen = true;
            end
            mask = 0; naid = 0; nreq = 0;
            for i = 1:nch
                if t(k) - src_last(i) <= cfg.source_window_s
                    mask = mask + 2^(i - 1);
                end
            end
            for i = 1:numel(aid_idx)
                if ~present(aid_idx(i)); continue; end
                nreq = nreq + 1;
                if t(k) - src_last(aid_idx(i)) <= cfg.source_window_s
                    naid = naid + 1;
                end
            end
            L.source_mask(k) = mask;
            L.health(k) = naid;
            if naid >= nreq
                L.status(k) = 3;             % OK
            elseif naid >= 2
                L.status(k) = 4;             % DEGRADED
            else
                L.status(k) = 5;             % DEAD_RECKONING
            end
        else
            L.status(k) = 2;                 % INIT_WAIT
            L.valid(k) = false;
            L.est_seq(k) = 0;
        end
    end

    % ================= availability state machine =========================
    % Evaluated HERE, after the tick loop, from the accept log only. Nothing
    % below can reach back into S, P, mgr or any admission decision.
    fin = struct('t', t, 'chan_accept', L.chan_accept, 'present', present, ...
        'period_s', period_s, 'stale_limit_s', stale_lim, 'init_tick', init_tick, ...
        'chans', {chans}, 'aid_idx', aid_idx, ...
        'pos_idx', pos_aid_indices(chans), 'scale', opts.fsm_scale);
    if opts.fsm
        A = availability_fsm(fin, cfg);
    else
        A = empty_fsm(N, cfg);
    end
    L.health_state = A.state;
    L.health_name_of = cfg.health_state_names;

    % ---- assembly ---------------------------------------------------------
    E = struct();
    E.task_id = cfg.task_id;
    E.gate = cfg.gate;
    E.tag = opts.tag;
    E.fsm_enabled = opts.fsm;
    E.fsm_scale = opts.fsm_scale;
    E.t = t; E.N = N; E.dt_base = bus.dt_base;
    E.channel_names = chans;
    E.channel_present = present;
    E.abs_position_present = abs_present;
    E.log = L;
    E.innov = innov;
    E.mgr = mgr;
    E.audit = audit;
    E.fused = fused;
    E.reacq = reacq;
    E.first_abs_fix = first_abs_fix;
    E.avail = A;
    E.fsm_input = fin;
    E.initialized = initialized;
    E.init_count = init_count;
    E.init_tick = init_tick;
    E.init_time = init_time;
    E.n_prop = n_prop;
    E.n_prop_substep = n_prop_substep;
    E.n_inject = n_inj;
    E.n_inject_rejected = n_inj_rejected;
    E.n_inject_admitted = n_inj_admitted;
    E.n_inject_fused = n_inj_fused;
    E.inject_result = inj_result;
    E.cov_sym_max = cov_sym_max;
    E.cov_mineig_min = cov_mineig_min;
    E.qnorm_err_max = qnorm_err_max;
    E.nan_seen = nan_seen;
    E.est_status_names = cfg.est_status_names;
    E.health_state_names = cfg.health_state_names;
    E.est_policy = cfg.est_policy;
    E.claim_limit = cfg.claim_limit;
    E.bus_fields_used = cfg.bus_whitelist;
    E.truth_fields_dropped = cfg.truth_forbidden;

    st = L.est_time(L.valid);
    sq = L.est_seq(L.valid);
    E.est_time_monotonic = isempty(st) || all(diff(st) >= -cfg.tol_time);
    E.est_seq_monotonic = isempty(sq) || all(diff(sq) > 0);
    if initialized && init_tick > 1
        E.valid_before_init = any(L.valid(1:init_tick - 1));
    else
        E.valid_before_init = false;
    end
    E.n_valid_ticks = sum(L.valid);
    E.avail_pct = 100 * sum(L.valid) / N;

    ok_cnt = true;
    for i = 1:nch
        m = mgr.(chans{i});
        ok_cnt = ok_cnt && (m.n_new == m.n_admit + m.n_reject_interface) && ...
            (m.n_admit == m.n_fused + m.n_init_used + m.n_reject_innov);
    end
    E.counter_invariant_ok = ok_cnt;

    E.est = build_est_bus(S, P, L, cfg, initialized, N);
    E.est_fields = cfg.est_fields;
end

function idx = pos_aid_indices(chans)
% Position aids: bottom/water-referenced velocity and absolute position.
% INS velocity is deliberately excluded - see cfg.fsm_policy.
    nmz = {'dvl_vel_body_water', 'usbl_pos_ned'};
    idx = zeros(1, numel(nmz));
    for i = 1:numel(nmz); idx(i) = find(strcmp(chans, nmz{i}), 1); end
end

%% ===================== availability state machine =====================
function A = availability_fsm(fin, cfg)
% Deterministic, hysteretic, health-only availability state machine.
%
% PURE FUNCTION of: the base time vector, the per-tick accept log, the
% declared per-channel ICD period / stale limit / presence, the
% initialization tick, and the predeclared dwell constants. Same inputs ->
% same output, every time, in any call order.
%
% Codes: 0 UNINITIALIZED, 1 NOMINAL, 2 DEGRADED, 3 POSITION_AID_LOST,
%        4 RECOVERING.
    t = fin.t(:);
    N = numel(t);
    CA = fin.chan_accept;
    present = fin.present;
    nch = numel(present);
    sc = fin.scale;

    % ---- freshness horizons, DERIVED per channel -------------------------
    tau = zeros(1, nch);
    for i = 1:nch
        tau(i) = max([cfg.fsm.k_fresh * fin.period_s(i), ...
                      fin.stale_limit_s(i) + fin.period_s(i), ...
                      cfg.fsm.tau_floor]);
    end
    T_deg = cfg.fsm.T_degrade * sc;
    T_lost = cfg.fsm.T_lost * sc;
    T_reacq = cfg.fsm.T_reacq * sc;
    T_clear = cfg.fsm.T_clear * sc;
    T_settle = cfg.fsm.T_settle * sc;
    tol = cfg.tol_time;

    req_idx = fin.aid_idx(present(fin.aid_idx));
    pos_idx = fin.pos_idx(present(fin.pos_idx));

    A = struct();
    A.state = zeros(N, 1);
    A.pos_aid_fresh = false(N, 1);
    A.all_aid_fresh = false(N, 1);
    A.age = NaN(N, nch);
    A.fresh = false(N, nch);
    A.tau_fresh = tau;
    A.required_channels = {fin.chans{req_idx}};
    A.position_aid_channels = {fin.chans{pos_idx}};
    A.thresholds = struct('T_degrade', T_deg, 'T_lost', T_lost, 'T_reacq', T_reacq, ...
        'T_clear', T_clear, 'T_settle', T_settle, 'scale', sc);
    A.trans = struct('t', [], 'k', [], 'from', [], 'to', []);
    A.n_transitions = 0;
    A.state_names = cfg.health_state_names;
    A.authority = cfg.fsm_authority;

    k0 = fin.init_tick;
    if isnan(k0) || isempty(req_idx)
        A.dwell_s = zeros(1, 5);
        A.enabled = true;
        A.sequence = [];
        A.sequence_names = {};
        return;
    end

    last_acc = NaN(1, nch);
    deg_timer = 0; loss_timer = 0; posok_timer = 0; allok_timer = 0;
    state = 1;                                    % NOMINAL at initialization
    for k = k0:N
        for i = 1:nch
            if CA(k, i); last_acc(i) = t(k); end
        end
        if k > k0; dt = t(k) - t(k - 1); else; dt = 0; end
        for i = 1:nch
            if isnan(last_acc(i))
                ref = t(k0);                      % startup grace from initialization
            else
                ref = last_acc(i);
            end
            A.age(k, i) = t(k) - ref;
            A.fresh(k, i) = A.age(k, i) <= tau(i) + tol;
        end
        if isempty(pos_idx)
            pf = false;
        else
            pf = any(A.fresh(k, pos_idx));
        end
        af = all(A.fresh(k, req_idx));
        A.pos_aid_fresh(k) = pf;
        A.all_aid_fresh(k) = af;

        if pf; loss_timer = 0; posok_timer = posok_timer + dt;
        else;  loss_timer = loss_timer + dt; posok_timer = 0; end
        if af; allok_timer = allok_timer + dt; deg_timer = 0;
        else;  allok_timer = 0; deg_timer = deg_timer + dt; end

        prev = state;
        switch state
            case 1                                        % NOMINAL
                if deg_timer >= T_deg - tol; state = 2; end
            case 2                                        % DEGRADED
                if loss_timer >= T_lost - tol
                    state = 3;
                elseif allok_timer >= T_clear - tol
                    state = 1;
                end
            case 3                                        % POSITION_AID_LOST
                if posok_timer >= T_reacq - tol; state = 4; end
            case 4                                        % RECOVERING
                if loss_timer >= T_lost - tol
                    state = 3;
                elseif allok_timer >= T_settle - tol
                    state = 1;
                end
        end
        if state ~= prev
            A.n_transitions = A.n_transitions + 1;
            A.trans.t(end+1, 1) = t(k);
            A.trans.k(end+1, 1) = k;
            A.trans.from(end+1, 1) = prev;
            A.trans.to(end+1, 1) = state;
        end
        % Timers are NOT reset by a transition. They are reset only by their
        % own condition failing, which keeps every declaration time a closed
        % form of the accept log: an entry fires exactly one dwell after its
        % condition first held. Cascading is impossible because all_fresh
        % implies pos_aid_fresh, so the timer that would fire the next
        % transition is always the shorter one at the moment of the previous.
        A.state(k) = state;
    end

    A.dwell_s = zeros(1, 5);
    for s = 0:4
        A.dwell_s(s + 1) = sum(A.state == s) * mean(diff(t));
    end
    if isempty(A.trans.to)
        A.sequence = 1;
    else
        A.sequence = [A.trans.from(1); A.trans.to(:)]';
    end
    A.sequence_names = cfg.health_state_names(A.sequence + 1);
    A.enabled = true;
end

function A = empty_fsm(N, cfg)
    A = struct();
    A.state = zeros(N, 1);
    A.pos_aid_fresh = false(N, 1);
    A.all_aid_fresh = false(N, 1);
    A.age = NaN(N, numel(cfg.all_channels));
    A.fresh = false(N, numel(cfg.all_channels));
    A.tau_fresh = NaN(1, numel(cfg.all_channels));
    A.required_channels = {};
    A.position_aid_channels = {};
    A.thresholds = struct('T_degrade', NaN, 'T_lost', NaN, 'T_reacq', NaN, ...
        'T_clear', NaN, 'T_settle', NaN, 'scale', NaN);
    A.trans = struct('t', [], 'k', [], 'from', [], 'to', []);
    A.n_transitions = 0;
    A.state_names = cfg.health_state_names;
    A.authority = cfg.fsm_authority;
    A.dwell_s = zeros(1, 5);
    A.sequence = [];
    A.sequence_names = {};
    A.enabled = false;
end

%% ===================== estimated bus =====================
function eb = build_est_bus(S, P, L, cfg, initialized, N)
    eb = struct();
    ivv = cfg.idx.v; ith = cfg.idx.th; icc = cfg.idx.c;
    if initialized
        Rbn = quat2rot(S.q);
        eul = rot2euler(Rbn);
        wv = S.v - S.c;
        vals = {S.p(:)', S.v(:)', (Rbn' * wv)', eul(:)', S.bg(:)', S.ba(:)', S.c(:)'};
        cov = cell(1, 7);
        cov{1} = diag(P(cfg.idx.p, cfg.idx.p))';
        cov{2} = diag(P(ivv, ivv))';
        Jd = zeros(3, cfg.n_err);
        Jd(:, ivv) = Rbn';
        Jd(:, icc) = -Rbn';
        Jd(:, ith) = skew(Rbn' * wv);
        cov{3} = diag(Jd * P * Jd')';
        Je = euler_jacobian(eul(1), eul(2));
        cov{4} = diag(Je * P(ith, ith) * Je')';
        cov{5} = diag(P(cfg.idx.bg, cfg.idx.bg))';
        cov{6} = diag(P(cfg.idx.ba, cfg.idx.ba))';
        cov{7} = diag(P(icc, icc))';
        status = cfg.est_status_names{L.status(N)};
        health = cfg.health_state_names{L.health_state(N) + 1};
    else
        vals = repmat({NaN(1, 3)}, 1, 7);
        cov = repmat({NaN(1, 3)}, 1, 7);
        status = 'UNAVAILABLE';
        health = 'UNINITIALIZED';
    end
    for i = 1:numel(cfg.est_fields)
        e = struct();
        e.frame = cfg.est_field_frames{i};
        e.units = cfg.est_field_units{i};
        e.dim = 3;
        e.value = vals{i};
        e.timestamp = L.est_time(N);
        e.sequence = L.est_seq(N);
        e.covariance = cov{i};
        e.sigma = sqrt(max(cov{i}, 0));
        e.valid = initialized;
        e.status = status;
        e.health_state = health;
        e.source_mask = L.source_mask(N);
        e.health = L.health(N);
        e.valid_series = L.valid;
        if initialized
            e.reason = '';
        else
            e.reason = 'NOT_INITIALIZED';
        end
        eb.(cfg.est_fields{i}) = e;
    end
    eb.covariance_full = P;
    eb.source_mask_bits = cfg.all_channels;
    eb.status_names = cfg.est_status_names;
    eb.health_state_names = cfg.health_state_names;
    eb.health_series = L.health_state;
    eb.policy = cfg.est_policy;
end

function J = euler_jacobian(phi, theta)
    cth = cos(theta);
    if abs(cth) < 1e-6; cth = 1e-6 * sign_nz(cth); end
    tth = sin(theta) / cth;
    J = [1, sin(phi) * tth, cos(phi) * tth;
         0, cos(phi),      -sin(phi);
         0, sin(phi) / cth, cos(phi) / cth];
end

%% ===================== packet plumbing =====================
function pkt = make_packet(M, k, nm)
    pkt = struct('value', M.value(k, :), 'timestamp', M.timestamp(k), ...
        't_rx', M.t_rx(k), 'seq', M.seq(k), 'valid', logical(M.valid(k)), ...
        'quality', M.quality(k), 'stale_age', M.stale_age(k), ...
        'status', M.status(k), 'injected', false, 'ch', nm);
end

function pkt = null_packet(nm)
    pkt = struct('value', NaN, 'timestamp', NaN, 't_rx', NaN, 'seq', 0, ...
        'valid', false, 'quality', 0, 'stale_age', Inf, 'status', 0, ...
        'injected', false, 'ch', nm);
end

function r = admit_reason(pkt, m, spec, cfg, is_new)
% Interface admission. Test order is fixed so the reason is deterministic.
% Unchanged from Gate 5B, and it is what refuses invalid, stale and
% out-of-order USBL packets without any USBL-specific code.
    r = '';
    if ~is_new
        r = 'not_valid'; return;
    end
    if ~spec.present
        r = 'channel_absent'; return;
    end
    if ~pkt.valid || pkt.status ~= 2
        r = 'not_valid'; return;
    end
    if ~all(isfinite(pkt.value)) || ~isfinite(pkt.timestamp) || ~isfinite(pkt.quality)
        r = 'nonfinite_value'; return;
    end
    if any(pkt.value < spec.bound_lo - 1e-9) || any(pkt.value > spec.bound_hi + 1e-9)
        r = 'out_of_bounds'; return;
    end
    if pkt.quality < cfg.q_min_frac * spec.q_nom - cfg.tol_time
        r = 'low_quality'; return;
    end
    if pkt.stale_age > spec.stale_limit_s + cfg.tol_time
        r = 'stale_age'; return;
    end
    if pkt.seq <= m.last_seq
        r = 'seq_not_increasing'; return;
    end
    if pkt.timestamp <= m.last_ts + cfg.tol_time
        r = 'timestamp_not_increasing'; return;
    end
end

function m = commit(m, pkt)
    m.last_seq = pkt.seq;
    m.last_ts = pkt.timestamp;
    m.n_admit = m.n_admit + 1;
end

function m = reject_iface(m, reason)
    m.n_reject_interface = m.n_reject_interface + 1;
    m.reject.(reason) = m.reject.(reason) + 1;
end

function s = empty_inject()
    s = struct('tick', {}, 'ch', {}, 'value', {}, 'timestamp', {}, 't_rx', {}, ...
        'seq', {}, 'valid', {}, 'quality', {}, 'stale_age', {}, 'status', {}, ...
        'injected', {}, 'tag', {}, 'expect', {});
end

function inj = build_injections(B, cfg) %#ok<INUSD>
% Deterministic manager negative test, retargeted at the Gate 5C surface:
% malformed OPTIONAL-USBL packets and a stale DVL packet offered inside the
% declared DVL gap. Every one is offered on a tick where the genuine channel
% does NOT deliver, so a correct manager leaves the clean run bitwise
% untouched. When USBL is declared ABSENT the expected reason for every USBL
% item is 'channel_absent', which is itself the check that an absent optional
% channel refuses everything.
    Mu = B.meas.usbl_pos_ned;
    Md = B.meas.dvl_vel_body_water;
    N = numel(B.t);
    ab = ~Mu.spec.present;
    inj = empty_inject();

    k = quiet_tick(Mu, round(0.30 * N));
    inj(end+1) = mk(k, 'usbl_pos_ned', [10 20 5], B.t(k), 1, false, Mu.spec.q_nom, ...
        Mu.spec.delay_s, 4, 'usbl_flagged_invalid', ex_reason(ab, 'not_valid'));

    k = quiet_tick(Mu, round(0.36 * N));
    inj(end+1) = mk(k, 'usbl_pos_ned', [NaN 20 5], B.t(k), 100000, true, Mu.spec.q_nom, ...
        Mu.spec.delay_s, 2, 'usbl_nonfinite_payload', ex_reason(ab, 'nonfinite_value'));

    k = quiet_tick(Mu, round(0.42 * N));
    inj(end+1) = mk(k, 'usbl_pos_ned', [1e6 20 5], B.t(k), 100001, true, Mu.spec.q_nom, ...
        Mu.spec.delay_s, 2, 'usbl_out_of_icd_bounds', ex_reason(ab, 'out_of_bounds'));

    k = quiet_tick(Mu, round(0.48 * N));
    inj(end+1) = mk(k, 'usbl_pos_ned', [10 20 5], B.t(k), 100002, true, ...
        0.01 * Mu.spec.q_nom, Mu.spec.delay_s, 2, 'usbl_quality_below_admission', ...
        ex_reason(ab, 'low_quality'));

    k = quiet_tick(Mu, round(0.54 * N));
    inj(end+1) = mk(k, 'usbl_pos_ned', [10 20 5], B.t(k), 100003, true, Mu.spec.q_nom, ...
        20 * max(Mu.spec.stale_limit_s, 0.1), 2, 'usbl_stale_beyond_limit', ...
        ex_reason(ab, 'stale_age'));

    k = quiet_tick(Mu, round(0.60 * N));
    inj(end+1) = mk(k, 'usbl_pos_ned', [10 20 5], B.t(k), 1, true, Mu.spec.q_nom, ...
        Mu.spec.delay_s, 2, 'usbl_replayed_old_sequence', ...
        ex_reason(ab, 'seq_not_increasing'));

    k = quiet_tick(Mu, round(0.66 * N));
    inj(end+1) = mk(k, 'usbl_pos_ned', [10 20 5], B.t(k) - 100, 100004, true, ...
        Mu.spec.q_nom, Mu.spec.delay_s, 2, 'usbl_out_of_order_timestamp', ...
        ex_reason(ab, 'timestamp_not_increasing'));

    k = quiet_tick(Md, round(0.50 * N));
    inj(end+1) = mk(k, 'dvl_vel_body_water', Md.value(max(1, k - 1), :), B.t(k) + 500, ...
        Md.seq(k) + 50, true, Md.spec.q_nom, 20 * Md.spec.stale_limit_s, 2, ...
        'dvl_stale_packet_inside_gap', 'stale_age');
end

function e = ex_reason(absent, r)
% An ABSENT optional channel must refuse every packet with 'channel_absent'
% before any payload check runs; a PRESENT one must refuse with the specific
% ICD reason.
    if absent
        e = 'channel_absent';
    else
        e = r;
    end
end

function k = quiet_tick(M, k0)
    N = numel(M.seq);
    k = min(max(k0, 2), N);
    while k < N && M.seq(k) ~= M.seq(k - 1)
        k = k + 1;
    end
end

function s = mk(tick, ch, value, timestamp, seq, valid, quality, stale_age, status, tag, expect)
    s = struct('tick', tick, 'ch', ch, 'value', reshape(value, 1, []), ...
        'timestamp', timestamp, 't_rx', timestamp, 'seq', seq, 'valid', valid, ...
        'quality', quality, 'stale_age', stale_age, 'status', status, ...
        'injected', true, 'tag', tag, 'expect', expect);
end

%% ===================== EKF core =====================
function [S, P] = propagate(S, P, w_m, f_m, dt, cfg)
    ip = cfg.idx.p; iv = cfg.idx.v; ith = cfg.idx.th;
    ibg = cfg.idx.bg; iba = cfg.idx.ba;
    nx = cfg.n_err;

    w = w_m - S.bg;
    f = f_m - S.ba;
    R = quat2rot(S.q);
    a = R * f + [0; 0; cfg.g_ned];

    S.p = S.p + S.v * dt + 0.5 * a * dt^2;
    S.v = S.v + a * dt;
    S.q = quat_norm(quat_mul(S.q, quat_from_rotvec(w * dt)));

    F = zeros(nx);
    F(ip, iv) = eye(3);
    F(iv, ith) = -R * skew(f);
    F(iv, iba) = -R;
    F(ith, ith) = -skew(w);
    F(ith, ibg) = -eye(3);

    Fd = F * dt;
    Phi = eye(nx) + Fd + 0.5 * (Fd * Fd);

    qv = [repmat(cfg.Q.sigma_p^2, 1, 3), repmat(cfg.Q.sigma_a^2, 1, 3), ...
          repmat(cfg.Q.sigma_g^2, 1, 3), repmat(cfg.Q.sigma_bg^2, 1, 3), ...
          repmat(cfg.Q.sigma_ba^2, 1, 3), repmat(cfg.Q.sigma_c^2, 1, 3)];
    Qc = diag(qv);
    Qd = 0.5 * (Phi * Qc * Phi' + Qc) * dt;

    P = Phi * P * Phi' + Qd;
    P = 0.5 * (P + P');
end

function [H, nu, Rm] = measurement_model(nm, S, pkt, cfg, age, spec)
    nx = cfg.n_err;
    Rbn = quat2rot(S.q);
    qs = max(pkt.quality / max(spec.q_nom, eps), cfg.q_floor);
    switch nm
        case 'depth_pressure'
            H = zeros(1, nx);
            H(1, cfg.idx.p(3)) = 1;
            nu = pkt.value(1) - S.p(3);
            Rm = cfg.R.depth_pressure / qs + (cfg.lat_scale.depth_pressure * age)^2;
        case 'heading_compass'
            eul = rot2euler(Rbn);
            ph = eul(1); th = eul(2); ps = eul(3);
            cth = cos(th);
            if abs(cth) < 1e-6; cth = 1e-6 * sign_nz(cth); end
            H = zeros(1, nx);
            H(1, cfg.idx.th) = [0, sin(ph) / cth, cos(ph) / cth];
            nu = wrap_pi(pkt.value(1) - ps);
            Rm = cfg.R.heading_compass / qs + (cfg.lat_scale.heading_compass * age)^2;
        case 'ins_vel_ned'
            H = zeros(3, nx);
            H(:, cfg.idx.v) = eye(3);
            nu = pkt.value(:) - S.v;
            Rm = cfg.R.ins_vel_ned / qs + (cfg.lat_scale.ins_vel_ned * age)^2 * eye(3);
        case 'dvl_vel_body_water'
            wv = S.v - S.c;
            hx = Rbn' * wv;
            H = zeros(3, nx);
            H(:, cfg.idx.v) = Rbn';
            H(:, cfg.idx.c) = -Rbn';
            H(:, cfg.idx.th) = skew(hx);
            nu = pkt.value(:) - hx;
            Rm = cfg.R.dvl_vel_body_water / qs + (cfg.lat_scale.dvl_vel_body_water * age)^2 * eye(3);
        case 'usbl_pos_ned'
            % GATE 5C ADDITION. Absolute NED position fix, h(x) = p_NED.
            % Linear in position, so H is exact and no lever arm, ray bending
            % or transponder-geometry term is modelled - all declared absent.
            H = zeros(3, nx);
            H(:, cfg.idx.p) = eye(3);
            nu = pkt.value(:) - S.p;
            Rm = cfg.R.usbl_pos_ned / qs + (cfg.lat_scale.usbl_pos_ned * age)^2 * eye(3);
        otherwise
            error('measurement_model: channel %s is not fusible in Gate 5C', nm);
    end
    nu = nu(:);
    Rm = 0.5 * (Rm + Rm');
end

%% ===================== integrity gates (truth-free) =====================
function G = integrity_gates(E, cfg)
    L = E.log;
    vi = L.valid;
    G = struct();

    G.finite_state_covariance = ~E.nan_seen && ...
        all(isfinite(L.p(:, vi)), 'all') && all(isfinite(L.v(:, vi)), 'all') && ...
        all(isfinite(L.euler(:, vi)), 'all') && all(isfinite(L.bg(:, vi)), 'all') && ...
        all(isfinite(L.ba(:, vi)), 'all') && all(isfinite(L.c(:, vi)), 'all') && ...
        all(isfinite(L.vbw(:, vi)), 'all') && all(isfinite(L.Pdiag(:, vi)), 'all');

    G.covariance_symmetric_psd = (E.cov_sym_max <= 1e-9) && (E.cov_mineig_min >= -1e-9);
    G.monotonic_estimate_time_sequence = E.est_time_monotonic && E.est_seq_monotonic;
    G.quaternion_norm = E.qnorm_err_max <= 1e-9;

    G.no_invalid_packet_fused = E.audit.all_fused_valid && ...
        E.audit.all_fused_quality_ok && E.audit.all_fused_stale_ok && ...
        E.audit.all_fused_finite && isempty(E.audit.violations);

    seq_ok = true; ts_ok = true;
    if ~isempty(E.fused.t)
        for i = 1:numel(cfg.update_order)
            sel = strcmp(E.fused.ch, cfg.update_order{i});
            if any(sel)
                seq_ok = seq_ok && all(diff(E.fused.seq(sel)) > 0);
                ts_ok = ts_ok && all(diff(E.fused.ts(sel)) > 0);
            end
        end
    end
    G.fused_packet_ordering = seq_ok && ts_ok;

    % USBL is fused only when the bus declares it present; when absent, not
    % one packet reaches the state.
    if E.channel_present(strcmp(E.channel_names, 'usbl_pos_ned'))
        G.usbl_fused_only_when_present = (E.audit.n_fused_usbl_absent == 0);
    else
        G.usbl_fused_only_when_present = (E.audit.n_fused_usbl == 0) && ...
            (E.mgr.usbl_pos_ned.n_fused == 0);
    end

    G.estimated_invalid_before_init = ~E.valid_before_init;
    G.estimated_valid_after_init = E.initialized && ~isnan(E.init_tick) && ...
        all(L.valid(E.init_tick:end));
    G.single_explicit_initialization = (E.init_count == 1);
    G.manager_counter_invariant = E.counter_invariant_ok;

    ebok = true;
    for i = 1:numel(cfg.est_fields)
        e = E.est.(cfg.est_fields{i});
        ebok = ebok && isfield(e, 'timestamp') && isfield(e, 'sequence') && ...
            isfield(e, 'covariance') && isfield(e, 'status') && ...
            isfield(e, 'health_state') && isfield(e, 'source_mask') && ...
            isfield(e, 'health') && isfield(e, 'frame') && isfield(e, 'units') && ...
            e.valid && all(isfinite(e.value)) && all(isfinite(e.covariance)) && ...
            all(e.covariance >= -1e-12);
    end
    G.estimated_interface_complete = ebok;

    % ---- state-machine integrity ----------------------------------------
    A = E.avail;
    if A.enabled
        st = A.state(E.init_tick:end);
        pre_ok = true;
        if E.init_tick > 1; pre_ok = all(A.state(1:E.init_tick - 1) == 0); end
        G.health_states_in_declared_set = all(ismember(st, 1:4)) && pre_ok;
        allowed = [1 2; 2 3; 2 1; 3 4; 4 3; 4 1];
        okadj = true;
        for i = 1:A.n_transitions
            okadj = okadj && any(all(allowed == [A.trans.from(i), A.trans.to(i)], 2));
        end
        G.health_transition_adjacency_legal = okadj;
        A2 = availability_fsm(E.fsm_input, cfg);
        G.health_recompute_deterministic = isequaln(A2.state, A.state) && ...
            isequaln(A2.trans, A.trans);
    else
        G.health_states_in_declared_set = true;
        G.health_transition_adjacency_legal = true;
        G.health_recompute_deterministic = true;
    end

    G.pass = all(struct_logical_vals(G));
end

function v = struct_logical_vals(s)
    f = fieldnames(s);
    v = true(1, numel(f));
    for i = 1:numel(f)
        x = s.(f{i});
        if islogical(x) || isnumeric(x)
            v(i) = ~isempty(x) && all(logical(x(:)));
        end
    end
end

%% ===================== post-hoc characterization =====================
function M = accuracy_metrics(T, E, cfg, prof)
% POST-HOC SCORING ONLY. The only function that reads TRUTH. It is never
% called by, and can never influence, the estimator: 'run' does not receive T.
    L = E.log;
    t = E.t;
    vi = L.valid;
    k0 = E.init_tick;
    M = struct();
    M.label = prof.label;
    M.route = prof.route;
    M.profile = prof.profile;
    M.Vc_ned = T.Vc_ned;
    M.init_time_s = E.init_time;
    M.avail_pct = E.avail_pct;
    M.frames = struct('pos', 'NED [m], z down positive', 'vel', 'NED [m/s]', ...
        'att', 'ZYX Euler [deg]', 'vbw', 'BODY water-relative [m/s]', ...
        'cur', 'NED [m/s]', 'usbl', 'NED [m]');

    pe  = L.p - T.eta_ned';
    pre = (L.p - L.p(:, k0)) - (T.eta_ned - T.eta_ned(k0, :))';
    ve  = L.v - T.V_g_ned';
    ee  = wrap_pi(L.euler - T.euler');
    we  = L.vbw - T.nu_r_body';
    ce  = L.c - repmat(T.Vc_ned', 1, E.N);

    M.rmse_pos_abs_ned = rms_cols(pe(:, vi));
    M.rmse_pos_abs_norm = sqrt(mean(sum(pe(:, vi).^2, 1)));
    M.rmse_pos_rel_ned = rms_cols(pre(:, vi));
    M.rmse_pos_rel_norm = sqrt(mean(sum(pre(:, vi).^2, 1)));
    M.rmse_vel_ned = rms_cols(ve(:, vi));
    M.rmse_vel_norm = sqrt(mean(sum(ve(:, vi).^2, 1)));
    M.rmse_att_deg = rad2deg(rms_cols(ee(:, vi)));
    M.rmse_yaw_deg = M.rmse_att_deg(3);
    M.rmse_depth_m = sqrt(mean(pe(3, vi).^2));
    M.max_depth_err_m = max(abs(pe(3, vi)));
    M.rmse_vbw_body = rms_cols(we(:, vi));
    M.rmse_cur_ned = rms_cols(ce(:, vi));
    M.rmse_cur_norm = sqrt(mean(sum(ce(:, vi).^2, 1)));
    M.max_pos_rel_norm = max(sqrt(sum(pre(:, vi).^2, 1)));
    M.max_pos_abs_norm = max(sqrt(sum(pe(:, vi).^2, 1)));
    M.max_vel_norm = max(sqrt(sum(ve(:, vi).^2, 1)));
    M.max_att_deg = rad2deg(max(abs(ee(:, vi)), [], 2))';
    M.final_cur_err_ned = ce(:, end)';
    M.pos_metric_note = ['With USBL ABSENT the estimator defines its own navigation origin at ', ...
        'initialization, so displacement drift (rmse_pos_rel_*) is the meaningful position ', ...
        'metric and absolute error carries the origin offset. With USBL PRESENT the absolute ', ...
        'metric becomes meaningful and is the one to read.'];

    % ---- covariance summary ----------------------------------------------
    sp = sqrt(sum(L.Pdiag(cfg.idx.p, :), 1));
    sv = sqrt(sum(L.Pdiag(cfg.idx.v, :), 1));
    sc = sqrt(sum(L.Pdiag(cfg.idx.c, :), 1));
    M.sigma = struct('pos_final_m', sp(end), 'pos_max_m', max(sp(vi)), ...
        'vel_final_mps', sv(end), 'vel_max_mps', max(sv(vi)), ...
        'cur_final_mps', sc(end), 'cur_max_mps', max(sc(vi)), ...
        'units', 'trace-root of the NED position / velocity / current block');

    % ---- innovation / NIS -------------------------------------------------
    inn = struct();
    for i = 1:numel(cfg.update_order)
        nm = cfg.update_order{i};
        Sx = E.innov.(nm);
        r = struct();
        r.n = numel(Sx.nis);
        r.units = innov_units(nm);
        if r.n == 0
            r.dim = 0; r.mean = NaN; r.rms = NaN; r.max_abs = NaN;
            r.nis_mean = NaN; r.nis_median = NaN; r.chi2_95 = NaN;
            r.nis_frac_within_95 = NaN; r.age_mean_s = NaN;
        else
            nu = Sx.nu;
            r.dim = size(nu, 2);
            r.mean = mean(nu, 1);
            r.rms = sqrt(mean(nu.^2, 1));
            r.max_abs = max(abs(nu), [], 1);
            r.nis_mean = mean(Sx.nis);
            r.nis_median = median(Sx.nis);
            r.chi2_95 = chi2_95(r.dim);
            r.nis_frac_within_95 = mean(Sx.nis <= r.chi2_95);
            r.age_mean_s = mean(Sx.age);
            if strcmp(nm, 'heading_compass')
                r.mean_deg = rad2deg(r.mean);
                r.rms_deg = rad2deg(r.rms);
                r.max_abs_deg = rad2deg(r.max_abs);
            end
        end
        r.n_accepted = sum(Sx.accepted);
        r.n_rejected = r.n - r.n_accepted;
        inn.(nm) = r;
    end
    M.innovation = inn;

    % ---- outage drift over the declared DVL gap --------------------------
    M.outage = window_drift(t, vi, pre, ve, ce, ee, L, cfg, prof.dvl_gap, 'dvl_gap');
    M.heading_outage = window_drift(t, vi, pre, ve, ce, ee, L, cfg, prof.hdg_gap, 'heading_gap');
    M.usbl_outage = window_drift(t, vi, pre, ve, ce, ee, L, cfg, prof.usbl_burst, 'usbl_burst');

    % ---- recovery jump ----------------------------------------------------
    ra = struct('applicable', all(isfinite(prof.dvl_gap)), 'found', false, 'ch', '', ...
        't_s', NaN, 'latency_after_gap_s', NaN, 'gap_s', NaN, 'jump_pos_m', NaN, ...
        'jump_vel_mps', NaN, 'innovation_norm', NaN);
    if ra.applicable && ~isempty(E.reacq.t)
        sel = find(E.reacq.t > prof.dvl_gap(2) - cfg.tol_time, 1, 'first');
        if ~isempty(sel)
            ra.found = true;
            ra.ch = E.reacq.ch{sel};
            ra.t_s = E.reacq.t(sel);
            ra.latency_after_gap_s = E.reacq.t(sel) - prof.dvl_gap(2);
            ra.gap_s = E.reacq.gap_s(sel);
            ra.jump_pos_m = E.reacq.dp(sel);
            ra.jump_vel_mps = E.reacq.dv(sel);
            ra.innovation_norm = E.reacq.innov(sel);
        end
    end
    M.recovery = ra;
    M.first_abs_fix = E.first_abs_fix;

    % ---- availability timeline -------------------------------------------
    A = E.avail;
    dt = E.dt_base;
    av = struct();
    av.state_names = cfg.health_state_names;
    av.dwell_s = zeros(1, 5);
    for s = 0:4; av.dwell_s(s + 1) = sum(A.state == s) * dt; end
    av.dwell_pct = 100 * av.dwell_s / (E.N * dt);
    av.n_transitions = A.n_transitions;
    av.sequence = A.sequence;
    av.sequence_names = A.sequence_names;
    av.trans_t = A.trans.t;
    av.trans_from = A.trans.from;
    av.trans_to = A.trans.to;
    av.tau_fresh = A.tau_fresh;
    av.thresholds = A.thresholds;
    av.first_lost_t = first_entry_time(A, 3);
    av.first_recovering_t = first_entry_time(A, 4);
    av.return_nominal_t = return_to_nominal_time(A);
    M.availability = av;

    M.note = ['Accuracy, drift and outage endurance are CHARACTERIZATION only and ', ...
        'NOT_CERTIFIED: every sensor numeric, every filter constant, every outage window and ', ...
        'the whole USBL model are ASSUMED, and TRUTH is a prescribed kinematic scenario, not a ', ...
        'plant or closed-loop run. Only the integrity and state-machine gates decide PASS.'];
end

function w = window_drift(t, vi, pre, ve, ce, ee, L, cfg, win, name)
    w = struct('name', name, 'applicable', all(isfinite(win)), 'window_s', win);
    f = {'t_start_s','t_end_s','duration_s','pos_rel_err_start_m','pos_rel_err_end_m', ...
        'pos_drift_m','pos_drift_slope_mps','pos_drift_r2','vel_err_start_mps', ...
        'vel_err_end_mps','vel_drift_mps','cur_err_start_mps','cur_err_end_mps', ...
        'cur_drift_mps','att_drift_deg','sigma_pos_start_m','sigma_pos_end_m', ...
        'sigma_pos_slope_mps','sigma_cur_start_mps','sigma_cur_end_mps'};
    for i = 1:numel(f); w.(f{i}) = NaN; end
    if ~w.applicable; return; end
    i0 = find(t >= win(1) & vi, 1, 'first');
    i1 = find(t <= win(2) & vi, 1, 'last');
    if isempty(i0) || isempty(i1) || i1 <= i0; return; end
    w.t_start_s = t(i0); w.t_end_s = t(i1); w.duration_s = t(i1) - t(i0);
    idx = i0:i1;
    en = sqrt(sum(pre(:, idx).^2, 1));
    w.pos_rel_err_start_m = en(1);
    w.pos_rel_err_end_m = en(end);
    w.pos_drift_m = en(end) - en(1);
    [w.pos_drift_slope_mps, w.pos_drift_r2] = lin_slope(t(idx), en(:));
    w.vel_err_start_mps = norm(ve(:, i0));
    w.vel_err_end_mps = norm(ve(:, i1));
    w.vel_drift_mps = w.vel_err_end_mps - w.vel_err_start_mps;
    w.cur_err_start_mps = norm(ce(:, i0));
    w.cur_err_end_mps = norm(ce(:, i1));
    w.cur_drift_mps = w.cur_err_end_mps - w.cur_err_start_mps;
    w.att_drift_deg = rad2deg(norm(ee(:, i1)) - norm(ee(:, i0)));
    spv = sqrt(sum(L.Pdiag(cfg.idx.p, idx), 1));
    w.sigma_pos_start_m = spv(1);
    w.sigma_pos_end_m = spv(end);
    w.sigma_pos_slope_mps = lin_slope(t(idx), spv(:));
    w.sigma_cur_start_mps = sqrt(sum(L.Pdiag(cfg.idx.c, i0)));
    w.sigma_cur_end_mps = sqrt(sum(L.Pdiag(cfg.idx.c, i1)));
end

function [m, r2] = lin_slope(x, y)
    x = x(:); y = y(:);
    n = numel(x);
    if n < 2; m = NaN; r2 = NaN; return; end
    xm = mean(x); ym = mean(y);
    sxx = sum((x - xm).^2);
    if sxx <= 0; m = NaN; r2 = NaN; return; end
    m = sum((x - xm) .* (y - ym)) / sxx;
    yh = ym + m * (x - xm);
    sst = sum((y - ym).^2);
    if sst <= 0; r2 = 1; else; r2 = 1 - sum((y - yh).^2) / sst; end
end

function tt = first_entry_time(A, s)
    tt = NaN;
    k = find(A.trans.to == s, 1, 'first');
    if ~isempty(k); tt = A.trans.t(k); end
end

function tt = return_to_nominal_time(A)
    tt = NaN;
    k = find(A.trans.to == 1 & A.trans.from == 4, 1, 'first');
    if ~isempty(k); tt = A.trans.t(k); end
end

function u = innov_units(nm)
    switch nm
        case 'depth_pressure';      u = 'm (NED down)';
        case 'heading_compass';     u = 'rad (also reported in deg)';
        case 'ins_vel_ned';         u = 'm/s (NED)';
        case 'dvl_vel_body_water';  u = 'm/s (BODY, water-relative)';
        case 'usbl_pos_ned';        u = 'm (NED)';
        otherwise;                  u = '';
    end
end

function v = chi2_95(d)
    tab = [3.8415 5.9915 7.8147 9.4877 11.0705];
    if d >= 1 && d <= numel(tab); v = tab(d); else; v = NaN; end
end

function r = rms_cols(X)
    if isempty(X); r = NaN(1, 3); else; r = sqrt(mean(X.^2, 2))'; end
end

%% ===================== determinism pack =====================
function P = pack_estimate(E)
% The ESTIMATED STATE pack. It deliberately excludes the health timeline, so
% comparing packs across a state-machine ablation is a genuine test that
% health output cannot touch the estimate.
    L = E.log;
    P = struct();
    P.init_tick = E.init_tick;
    P.init_count = E.init_count;
    P.n_prop = E.n_prop;
    P.p = L.p; P.v = L.v; P.euler = L.euler; P.q = L.q;
    P.bg = L.bg; P.ba = L.ba; P.c = L.c; P.vbw = L.vbw;
    P.Pdiag = L.Pdiag;
    P.valid = L.valid; P.status = L.status; P.est_seq = L.est_seq;
    P.est_time = L.est_time; P.source_mask = L.source_mask;
    P.n_fused_total = E.audit.n_fused_total;
    for i = 1:numel(E.channel_names)
        m = E.mgr.(E.channel_names{i});
        P.mgr.(E.channel_names{i}) = [m.n_new, m.n_admit, m.n_reject_interface, ...
            m.n_init_used, m.n_reject_innov, m.n_fused];
    end
end

%% ===================== math helpers =====================
function S = skew(v)
    S = [0, -v(3), v(2); v(3), 0, -v(1); -v(2), v(1), 0];
end

function R = quat2rot(q)
    qw = q(1); qx = q(2); qy = q(3); qz = q(4);
    R = [1 - 2*(qy^2 + qz^2), 2*(qx*qy - qw*qz),   2*(qx*qz + qw*qy);
         2*(qx*qy + qw*qz),   1 - 2*(qx^2 + qz^2), 2*(qy*qz - qw*qx);
         2*(qx*qz - qw*qy),   2*(qy*qz + qw*qx),   1 - 2*(qx^2 + qy^2)];
end

function q = quat_mul(a, b)
    w1 = a(1); x1 = a(2); y1 = a(3); z1 = a(4);
    w2 = b(1); x2 = b(2); y2 = b(3); z2 = b(4);
    q = [w1*w2 - x1*x2 - y1*y2 - z1*z2;
         w1*x2 + x1*w2 + y1*z2 - z1*y2;
         w1*y2 - x1*z2 + y1*w2 + z1*x2;
         w1*z2 + x1*y2 - y1*x2 + z1*w2];
end

function q = quat_from_rotvec(v)
    n = norm(v);
    if n < 1e-12
        q = [1; 0.5 * v(1); 0.5 * v(2); 0.5 * v(3)];
    else
        q = [cos(n / 2); sin(n / 2) * v(:) / n];
    end
    q = q / norm(q);
end

function q = quat_norm(q)
    q = q / norm(q);
    if q(1) < 0; q = -q; end
end

function q = euler2quat(phi, theta, psi)
    cr = cos(phi / 2); sr = sin(phi / 2);
    cp = cos(theta / 2); sp = sin(theta / 2);
    cy = cos(psi / 2); sy = sin(psi / 2);
    q = [cr*cp*cy + sr*sp*sy;
         sr*cp*cy - cr*sp*sy;
         cr*sp*cy + sr*cp*sy;
         cr*cp*sy - sr*sp*cy];
end

function e = rot2euler(R)
    phi = atan2(R(3, 2), R(3, 3));
    theta = -asin(max(-1, min(1, R(3, 1))));
    psi = atan2(R(2, 1), R(1, 1));
    e = [phi; theta; psi];
end

function y = wrap_pi(x)
    y = mod(x + pi, 2 * pi) - pi;
    y(y == -pi & x > 0) = pi;
end

function s = sign_nz(x)
    s = sign(x);
    if s == 0; s = 1; end
end
