function A = gate8_yaw_term_audit_core(R0)
% GATE8_YAW_TERM_AUDIT_CORE
% Isolated, read-only algebraic audit of the EXISTING yaw (rudder) command
% equation. Operates only on the stored log of
% GATE8_R10_CLOSED_LOOP_RAIL_ORIGIN_LOCALISATION.mat. No simulation, no plant
% call, no gain/law/path/threshold edit, no promotion.
%
% FRAMES / UNITS (declared, carried from R0.frames):
%   psi, yaw_ref, e_psi   : NED heading [rad] internally; logged in deg
%   r, r_ff, e_r          : BODY yaw rate [rad/s] internally; logged in deg/s
%   p                     : BODY roll rate [rad/s] internally; logged in deg/s
%   delta_r and every term: rudder deflection [rad] internally; logged in deg
%   kappa_f               : path curvature [1/m]; U_h [m/s]
%   dt_controller         : controller sample time [s]

    D2R = pi/180;  R2D = 180/pi;

    % ---------- log extraction ----------
    cols = R0.log_cols;
    if ~iscell(cols); cols = cellstr(cols); end
    cols = cols(:);
    L = R0.log;
    n = size(L, 1);
    C = struct();
    for j = 1:numel(cols)
        C.(matlab.lang.makeValidName(cols{j})) = L(:, j);
    end
    A.n = n;
    A.dt = R0.gains.dt_controller;
    A.dt_guid = R0.gains.dt_guidance;
    A.LIM = R0.gains.delta_r_max_deg;
    A.RATE_LIM = R0.gains.rate_limit_degs;

    % ---------- code coefficients (transcribed from controller_law.m / guidance_law.m) ----------
    A.code.Kp_psi   = R0.gains.Kp_psi;      % [-]   rad rudder per rad heading error
    A.code.Kd_psi   = R0.gains.Kd_psi;      % [s]   rad rudder per (rad/s) yaw-rate error
    A.code.Kp_roll  = R0.gains.Kp_roll;     % [s]   rad rudder per (rad/s) roll rate
    A.code.e_psi0   = deg2rad(3);           % [rad] g_ac heading-error corner
    A.code.e_r0     = deg2rad(8);           % [rad/s] g_ac rate-error corner (deg2rad used on a RATE)
    A.code.k_beta   = 1.35;                 % [-]   guidance crab over-compensation
    A.code.w_chi_los= 0.75;                 % [-]   guidance LOS weight
    A.code.L_floor  = 1.0;                  % [m]   L = max(lookahead_distance, 1.0)
    A.code.r_ff_clamp_degs = 40;            % deg2rad(40) applied to a rate [rad/s]
    A.code.Td       = A.code.Kd_psi / A.code.Kp_psi;   % [s] derivative time constant

    % ---------- symbolic reconstruction of the executed equation ----------
    A.equation = { ...
      'e_psi   = wrapToPi(yaw_ref - psi)                              [rad]  NED heading error, wrapped once, single application'
      'e_r     = r - r_ff                                             [rad/s] BODY yaw rate minus guidance rate FF'
      'r_ff    = clamp(U_h * kappa_f, +-deg2rad(40))                  [rad/s] = [m/s]*[1/m]; clamp constant is 40 deg/s'
      'dr_yaw  = Kp_psi*e_psi - Kd_psi*e_r                            [rad]  = Kp_psi*e_psi - Kd_psi*r + Kd_psi*r_ff'
      'g_ac    = 1/(1 + (e_psi/e_psi0)^2 + (e_r/e_r0)^2)              [-]    e_psi0=deg2rad(3), e_r0=deg2rad(8)'
      'dr_p    = -Kp_roll*p                                           [rad]  Kp_roll [s] * p [rad/s]'
      'dr_damp = g_ac * dr_p                                          [rad]'
      'dr_raw  = dr_yaw + dr_damp                                     [rad]  sum BEFORE any limiter'
      'dr_mag  = clamp(dr_raw, +-delta_r_max)                         [rad]  STAGE 1: magnitude'
      'delta_r = dr_prev + clamp(dr_mag - dr_prev, +-deg2rad(40)*dt)  [rad]  STAGE 2: rate, dt = dt_controller'
      'ORDER   = magnitude-then-rate, both after the roll damp is summed in'};

    A.term_names = {'P','D','FF','ROLLDAMP'};

    % ---------- G1: coefficient recovery from stored logs ----------
    % Each observed contribution divided by its source signal must reproduce the
    % code coefficient. Ratios are formed in logged units (deg/deg, deg/(deg/s)),
    % which is legitimate ONLY because numerator and denominator carry the same
    % angular conversion; that identity is itself the rad/deg audit.
    A.recov = gate8_ratio(C.term_P_deg,  C.e_psi_deg,   A.code.Kp_psi,  'term_P_deg / e_psi_deg',   '[-] rad/rad');
    A.recov(2) = gate8_ratio(C.term_D_deg,  C.r_body_degs, -A.code.Kd_psi, 'term_D_deg / r_body_degs',  '[s] rad/(rad/s)');
    A.recov(3) = gate8_ratio(C.term_FF_deg, C.r_ff_degs,    A.code.Kd_psi, 'term_FF_deg / r_ff_degs',   '[s] rad/(rad/s)');
    A.recov(4) = gate8_ratio(C.dr_p_deg,    C.p_body_degs, -A.code.Kp_roll,'dr_p_deg / p_body_degs',    '[s] rad/(rad/s)');
    A.recov_tol = 1e-9;
    A.recov_all_ok = all([A.recov.rel_err] <= A.recov_tol);

    % ---------- G2: structural / conversion / ordering residuals ----------
    K = 0;
    K=K+1; A.res(K) = gate8_res('dr_yaw - (P + D + FF)', C.dr_yaw_deg - (C.term_P_deg + C.term_D_deg + C.term_FF_deg), 'deg', ...
        'expansion of -Kd_psi*(r - r_ff) into two logged halves is exact');
    K=K+1; A.res(K) = gate8_res('e_r - (r - r_ff)', C.e_r_degs - (C.r_body_degs - C.r_ff_degs), 'deg/s', ...
        'rate error is a single subtraction in one frame (BODY), no conversion');
    K=K+1; A.res(K) = gate8_res('r_ff - U_h*kappa_f', C.r_ff_degs - (C.U_h_guid .* C.kappa_f_invm) * R2D, 'deg/s', ...
        'guidance FF chain: [m/s]*[1/m] = [rad/s]; exactly one rad->deg conversion in the log');
    K=K+1; A.res(K) = gate8_res('dr_damp - g_ac*dr_p', C.dr_damp_deg - C.g_ac_frac .* C.dr_p_deg, 'deg', ...
        'roll damp scheduled once by the dimensionless g_ac');
    g_ac_rec = 1 ./ (1 + (C.e_psi_deg/3).^2 + (C.e_r_degs/8).^2);
    K=K+1; A.res(K) = gate8_res('g_ac - 1/(1+(e_psi/3deg)^2+(e_r/8deg/s)^2)', C.g_ac_frac - g_ac_rec, '-', ...
        'g_ac reproduced with the corner constants read as 3 deg and 8 deg/s: deg2rad on a RATE is numerically correct');
    K=K+1; A.res(K) = gate8_res('dr_raw - (dr_yaw + dr_damp)', C.dr_raw_deg - (C.dr_yaw_deg + C.dr_damp_deg), 'deg', ...
        'roll damp is summed BEFORE the limiters, as the header comment states');
    K=K+1; A.res(K) = gate8_res('dr_postmag - clamp(dr_raw, +-25)', C.dr_postmag_deg - max(min(C.dr_raw_deg, A.LIM), -A.LIM), 'deg', ...
        'STAGE 1 limiter is a pure magnitude clamp on the raw sum');
    dr_rate_rec = zeros(n,1); prev = 0; lim_tick = A.RATE_LIM * A.dt;
    for i = 1:n
        dr_rate_rec(i) = prev + max(min(C.dr_postmag_deg(i) - prev, lim_tick), -lim_tick);
        prev = C.dr_postrate_deg(i);
    end
    K=K+1; A.res(K) = gate8_res('dr_postrate - rate_limit(dr_postmag)', C.dr_postrate_deg - dr_rate_rec, 'deg', ...
        sprintf('STAGE 2 limiter = %.6g deg/tick from deg2rad(%g)*dt with dt = %.6g s', lim_tick, A.RATE_LIM, A.dt));
    K=K+1; A.res(K) = gate8_res('dr_plant - dr_postrate', C.dr_plant_deg - C.dr_postrate_deg, 'deg', ...
        'plant input equals the controller return value: hooks-off nominal cell');
    A.res_tol = 1e-9;
    A.res_all_ok = all([A.res.maxabs] <= A.res_tol);
    A.rate_lim_tick_deg = lim_tick;

    % ---------- G3: leave-one-term-out attribution (algebraic, stored raw only) ----------
    terms  = [C.term_P_deg, C.term_D_deg, C.term_FF_deg, C.dr_damp_deg];
    RATEQ  = C.term_D_deg + C.term_FF_deg;      % the one physical rate-error term
    groups = [C.term_P_deg, RATEQ, C.dr_damp_deg];
    A.group_names = {'P','RATE_ERR','ROLLDAMP'};
    rail = C.rail_flag > 0.5;
    magsat = C.mag_sat_flag > 0.5;
    base_mag = max(min(C.dr_raw_deg, A.LIM), -A.LIM);

    A.loto_split = gate8_loto(terms, A.term_names, C.dr_raw_deg, base_mag, rail, A.LIM);
    A.loto_group = gate8_loto(groups, A.group_names, C.dr_raw_deg, base_mag, rail, A.LIM);
    A.group_completeness_maxabs = max(abs(C.dr_raw_deg - sum(groups,2)));

    % split-vs-grouped decomposition artifact
    A.decomp.D_medabs   = median(abs(C.term_D_deg));
    A.decomp.FF_medabs  = median(abs(C.term_FF_deg));
    A.decomp.RATE_medabs= median(abs(RATEQ));
    A.decomp.opposite_sign_frac = mean(C.term_D_deg .* C.term_FF_deg < 0);
    A.decomp.note = ['term_D and term_FF are the two halves of the single physical term -Kd_psi*(r - r_ff). ' ...
        'They oppose each other on ' sprintf('%.4f', A.decomp.opposite_sign_frac) ' of the horizon, so counting them ' ...
        'as two independent contributions inflates the number of terms that reach the envelope alone.'];

    % ---------- G4: envelope excess ledger ----------
    lab = [A.term_names, {'RAW_SUM'}];
    sig = [terms, C.dr_raw_deg];
    for k = 1:numel(lab)
        A.ledger(k).term = lab{k};
        A.ledger(k).absmax_deg = max(abs(sig(:,k)));
        A.ledger(k).medabs_deg = median(abs(sig(:,k)));
        A.ledger(k).excess_absmax = A.ledger(k).absmax_deg / A.LIM;
        A.ledger(k).excess_medabs = A.ledger(k).medabs_deg / A.LIM;
        A.ledger(k).reaches_env_alone = double(A.ledger(k).absmax_deg >= A.LIM);
    end

    % ---------- G5: coupled saturation of the roll-damp channel ----------
    A.coupled.magsat_dwell      = mean(magsat);
    % rate dwell must come from the rate flag, not from 1 - transmitted_frac:
    % transmitted_frac is a magnitude-limiter quantity and the two are not complements.
    A.coupled.ratesat_dwell     = mean(C.rate_sat_flag > 0.5);
    A.coupled.rail_dwell        = mean(rail);
    A.coupled.transmitted_frac  = mean(~magsat);
    A.coupled.n_transmitted     = sum(~magsat);
    A.coupled.g_ac_median       = median(C.g_ac_frac);
    A.coupled.g_ac_attenuation  = 1/median(C.g_ac_frac);
    A.coupled.effective_authority= median(C.g_ac_frac) * mean(~magsat);
    A.coupled.rolldamp_absmax   = max(abs(C.dr_damp_deg));
    A.coupled.loto_changed      = A.loto_split(4).n_changed_postmag;
    A.coupled.note = ['g_ac_median * transmitted_fraction = ' sprintf('%.6g', A.coupled.effective_authority) ...
        ': the roll-rate damp is attenuated ' sprintf('%.3gx', A.coupled.g_ac_attenuation) ' by its own scheduler and then ' ...
        'algebraically discarded by the magnitude limiter on ' sprintf('%.4f', A.coupled.magsat_dwell) ' of the horizon. ' ...
        'It is implemented exactly as the header comment declares (summed before the limiters) but its authority is ' ...
        'consumed by saturation created by the yaw terms.'];

    % ---------- G6: standing-error geometry (mechanism, not a defect claim) ----------
    beta_deg = atan2(C.v_body, max(C.u_body, 0.35)) * R2D;
    sus = C.t >= 10;
    A.geom.beta_absmax_deg   = max(abs(beta_deg));
    A.geom.beta_median_deg   = median(beta_deg(sus));
    A.geom.crab_over_comp_deg= -(A.code.k_beta - 1) * median(beta_deg(sus));
    A.geom.kappa_median      = median(C.kappa_f_invm(sus));
    A.geom.R_path_median     = 1/median(C.kappa_f_invm(sus));
    A.geom.e_psi_median_sus  = median(C.e_psi_deg(sus));
    A.geom.e_psi_absmax      = max(abs(C.e_psi_deg));
    A.geom.L_eff_m           = median(C.e_psi_deg(sus)*D2R ./ C.kappa_f_invm(sus));
    A.geom.L_eff_no_crab_m   = median((C.e_psi_deg(sus) + (A.code.k_beta-1)*beta_deg(sus))*D2R ./ C.kappa_f_invm(sus));
    A.geom.P_from_geometry   = A.code.Kp_psi * A.geom.e_psi_median_sus;
    A.geom.P_observed_median = median(C.term_P_deg(sus));
    A.geom.rate_pair_median  = median(RATEQ(sus));
    A.geom.r_body_mean_sus   = mean(C.r_body_degs(sus));
    A.geom.r_body_std_sus    = std(C.r_body_degs(sus));
    A.geom.Kd_times_ripple   = A.code.Kd_psi * std(C.r_body_degs(sus));
    A.geom.kinematic_r_degs  = median(C.U_h_guid(sus)) * median(C.kappa_f_invm(sus)) * R2D;
    A.geom.r_ff_median_degs  = median(C.r_ff_degs(sus));
    A.geom.trim_req_deg      = R0.plant_trim_requirement_deg;
    A.geom.dr_plant_medabs   = median(abs(C.dr_plant_deg(sus)));
    A.geom.cte_absmax_m      = max(abs(C.cte_signed_m));
    A.geom.cte_medabs_m      = median(abs(C.cte_signed_m));
    A.geom.note = ['On a constant-curvature path a lookahead course reference leads the achieved heading by ' ...
        'L_eff*kappa radians ([m]*[1/m] = [rad]); that offset is geometric and cannot be nulled by the rudder ' ...
        'channel, which carries no integral state. The recovered L_eff = ' sprintf('%.4g', A.geom.L_eff_m) ...
        ' m is consistent with the guidance floor L = max(lookahead_distance, 1.0) m attenuated by the chi_f course ' ...
        'filter; lookahead_distance itself is set outside the three permitted sources.'];

    % ---------- G7: multirate / sample-time audit ----------
    dyr = diff(C.yaw_ref_deg);
    upd = abs(dyr) > 1e-12;
    A.multirate.nonzero_increment_frac = mean(upd);
    A.multirate.expected_frac = A.dt / A.dt_guid;
    A.multirate.max_increment_deg = max(abs(dyr));
    A.multirate.apparent_rate_at_dt_ctrl = max(abs(dyr))/A.dt;
    A.multirate.true_rate_at_dt_guid     = max(abs(dyr))/A.dt_guid;
    A.multirate.guidance_cap_deg_per_call= 40 * A.dt_guid;
    A.multirate.guidance_cap_degs        = 40;
    A.multirate.stored_yaw_ref_rate_absmax_degs = R0.attrib.transient.yaw_ref_rate_absmax_degs;
    A.multirate.cfg_yaw_ref_rate_max_degs = R0.cfg_used.yaw_ref_rate_max;
    A.multirate.note = ['yaw_ref is republished every dt_guidance = ' sprintf('%.4g', A.dt_guid) ' s and held; the log ' ...
        'samples it every dt_controller = ' sprintf('%.4g', A.dt) ' s. Differencing the held signal at the controller ' ...
        'rate inflates the apparent reference rate by dt_guid/dt_ctrl = ' sprintf('%.4g', A.dt_guid/A.dt) 'x. The stored ' ...
        sprintf('%.6g', A.multirate.stored_yaw_ref_rate_absmax_degs) ' deg/s is therefore NOT comparable with the ' ...
        'guidance 40 deg/s slew cap; over the true dt_guidance interval the same increment is ' ...
        sprintf('%.6g', A.multirate.true_rate_at_dt_guid) ' deg/s, inside the cap.'];

    % ---------- G8: frame audit, BODY r versus Euler yaw rate ----------
    ph = C.phi_deg*D2R; th = C.theta_deg*D2R;
    fac = cos(ph)./cos(th);
    A.frame.max_rel_dev = max(abs(fac - 1));
    A.frame.max_D_error_deg = A.frame.max_rel_dev * max(abs(C.term_D_deg));
    A.frame.phi_range_deg = [min(C.phi_deg), max(C.phi_deg)];
    A.frame.theta_range_deg = [min(C.theta_deg), max(C.theta_deg)];
    A.frame.sin_phi_absmax = max(abs(sin(ph)));
    A.frame.q_available = false;
    A.frame.note = ['controller_law.m converts BODY rates to the physical PITCH rate explicitly ' ...
        '(theta_phys_dot = -q*cos(phi) + r*sin(phi)) but feeds BODY r straight into the yaw damping term, ' ...
        'where the Euler heading rate is psi_dot = (q*sin(phi) + r*cos(phi))/cos(theta). Both are [rad/s], so this ' ...
        'is a FRAME asymmetry, not a unit error. Bounded here at |cos(phi)/cos(theta) - 1| <= ' ...
        sprintf('%.4g', A.frame.max_rel_dev) ', i.e. <= ' sprintf('%.4g', A.frame.max_D_error_deg) ' deg on term_D. ' ...
        'The q*sin(phi)/cos(theta) cross term cannot be bounded: q is not in the stored log.'];

    % ---------- G9: duplicate-scaling / dimensional test battery ----------
    B = {};
    B{end+1} = {'DS1','term_P / e_psi returns Kp_psi with zero spread: no hidden rad<->deg factor on the P path', ...
        A.recov(1).rel_err <= A.recov_tol};
    B{end+1} = {'DS2','term_D / r returns -Kd_psi with zero spread: no duplicate conversion on the damping path', ...
        A.recov(2).rel_err <= A.recov_tol};
    B{end+1} = {'DS3','term_FF / r_ff returns +Kd_psi: the rate FF is applied exactly once, through Kd_psi only', ...
        A.recov(3).rel_err <= A.recov_tol};
    B{end+1} = {'DS4','dr_p / p returns -Kp_roll: roll coupling carries one gain and one schedule', ...
        A.recov(4).rel_err <= A.recov_tol};
    B{end+1} = {'DS5','r_ff = U_h*kappa_f exactly: no second speed factor, the retired 1.15*u_ref is absent', ...
        A.res(3).maxabs <= A.res_tol};
    B{end+1} = {'DS6','g_ac reproduced from 3 deg and 8 deg/s corners: deg2rad applied to a rate is numerically exact', ...
        A.res(5).maxabs <= A.res_tol};
    B{end+1} = {'DS7','limiter order magnitude-then-rate reproduced, roll damp inside both', ...
        (A.res(7).maxabs <= A.res_tol) && (A.res(8).maxabs <= A.res_tol)};
    B{end+1} = {'DS8','e_psi wrapped exactly once and used once', A.res(1).maxabs <= A.res_tol};
    for k = 1:numel(B)
        A.battery(k).id = B{k}{1};
        A.battery(k).statement = B{k}{2};
        A.battery(k).consistent = double(B{k}{3});
    end
    A.n_dimensional_defects_proved = sum(~[A.battery.consistent]);

    % ---------- G10: unit-conversion hypothesis, evaluated not assumed ----------
    A.hyp.s_unit  = D2R;                                  % 1/57.29578, a single rad->deg mis-scale
    A.hyp.s_env   = A.LIM / max(abs(C.dr_raw_deg));       % stored-raw headroom anchor
    A.hyp.s_med   = A.LIM / median(abs(C.dr_raw_deg));    % median-fit anchor
    A.hyp.s_dp    = A.LIM / (A.code.Kp_psi * 3);          % g_ac design-point anchor: Kp*e_psi0 = envelope
    A.hyp.raw_absmax_deg = max(abs(C.dr_raw_deg));
    A.hyp.raw_medabs_deg = median(abs(C.dr_raw_deg));
    A.hyp.unit_scaled_P_median = A.hyp.s_unit * median(C.term_P_deg(sus));
    A.hyp.unit_scaled_raw_absmax = A.hyp.s_unit * max(abs(C.dr_raw_deg));
    A.hyp.unit_scaled_raw_medabs = A.hyp.s_unit * median(abs(C.dr_raw_deg));
    A.hyp.verdict = ['ADMISSIBLE_BUT_UNPROVED. A single rad->deg de-scaling (' sprintf('%.6g', A.hyp.s_unit) ...
        ') satisfies the envelope test (raw absmax would be ' sprintf('%.4g', A.hyp.unit_scaled_raw_absmax) ' deg < ' ...
        sprintf('%g', A.LIM) ' deg) but drives the median proportional authority to ' ...
        sprintf('%.4g', A.hyp.unit_scaled_P_median) ' deg, BELOW the recorded plant steady-turn requirement of ' ...
        sprintf('%.4g', A.geom.trim_req_deg) ' deg. The stored data therefore neither proves nor refutes it. ' ...
        'The declared unit of Kp_psi and Kd_psi is set in continuous_path_tracking.m, outside the three permitted sources.'];
    A.hyp.Td_invariance = ['Kd_psi/Kp_psi = ' sprintf('%.9g', A.code.Td) ' s is a derivative time constant and is ' ...
        'invariant under any common mis-scaling of the pair, so the gain ratio cannot discriminate a units defect ' ...
        'from a tuning choice. This is why the ratio test is reported as non-discriminating rather than as evidence.'];

    % ---------- derived log, appended once, with units and provenance ----------
    A.derived_log = [C.t, C.e_psi_deg, C.term_P_deg, C.term_D_deg, C.term_FF_deg, RATEQ, ...
                     C.dr_damp_deg, C.dr_raw_deg, base_mag, C.dr_plant_deg, beta_deg, ...
                     C.kappa_f_invm, C.e_psi_deg*D2R./max(C.kappa_f_invm,1e-9), ...
                     double(magsat), double(rail)];
    A.derived_log_cols = {'t','e_psi_deg','term_P_deg','term_D_deg','term_FF_deg','term_RATE_ERR_deg', ...
        'dr_damp_deg','dr_raw_deg','dr_postmag_recon_deg','dr_plant_deg','beta_deg','kappa_f_invm', ...
        'L_eff_instant_m','mag_sat_flag','rail_flag'};
    A.derived_log_units = {'s','deg','deg','deg','deg','deg','deg','deg','deg','deg','deg','1/m','m','-','-'};
    A.derived_log_provenance = { ...
        'STORED_LOG | simulation time, copied unchanged'
        'STORED_LOG | CONTROLLER_PUBLISHED wrapped heading error, NED'
        'STORED_LOG | Kp_psi*e_psi, rudder deg'
        'STORED_LOG | -Kd_psi*r, rudder deg, BODY yaw rate'
        'STORED_LOG | +Kd_psi*r_ff, rudder deg, guidance rate FF'
        'AUDIT_DERIVED | term_D + term_FF = -Kd_psi*(r - r_ff), the single physical rate-error term'
        'STORED_LOG | g_ac*(-Kp_roll*p), rudder deg, BODY roll rate'
        'STORED_LOG | dr_yaw + dr_damp before any limiter, rudder deg'
        'AUDIT_DERIVED | magnitude clamp recomputed from dr_raw at the recorded 25 deg envelope'
        'STORED_LOG | HARNESS_OBSERVED value handed to the plant, rudder deg'
        'AUDIT_DERIVED | atan2(v_body, max(u_body,0.35)) from stored BODY velocities, the guidance definition'
        'STORED_LOG | GUIDANCE_PUBLISHED filtered path curvature'
        'AUDIT_DERIVED | e_psi[rad]/kappa, the implied lookahead lead; [rad]/[1/m] = [m]'
        'AUDIT_DERIVED | 1 when the magnitude limiter clipped, from the stored flag'
        'AUDIT_DERIVED | 1 when the plant input sits at the envelope, from the stored flag'};
    A.derived_log_appended_once = true;

    A.frames = R0.frames;
    A.frames.this_task_note = ['yaw command terms are rudder deflections in deg in every table; internally the ' ...
        'production law works in rad. Heading quantities are NED, rate quantities are BODY. Ratios are formed in ' ...
        'logged units only where numerator and denominator share the same conversion.'];
end

function s = gate8_ratio(num, den, code_coef, label, unit)
    thr = 1e-3 * max(abs(den));
    m = abs(den) > thr;
    r = num(m) ./ den(m);
    s.label = label;
    s.unit = unit;
    s.code_coefficient = code_coef;
    s.n_observable = sum(m);
    s.n_total = numel(den);
    s.min = min(r);
    s.max = max(r);
    s.median = median(r);
    s.spread = max(r) - min(r);
    s.abs_err = max(abs(r - code_coef));
    s.rel_err = s.abs_err / max(abs(code_coef), eps);
    s.observable = s.n_observable > 0;
end

function s = gate8_res(label, e, unit, note)
    s.label = label;
    s.unit = unit;
    s.maxabs = max(abs(e));
    s.rms = sqrt(mean(e.^2));
    s.note = note;
end

function S = gate8_loto(T, names, raw, base_mag, rail, LIM)
    for k = 1:numel(names)
        tv = T(:,k);
        alt_raw = raw - tv;
        alt_mag = max(min(alt_raw, LIM), -LIM);
        d = alt_mag - base_mag;
        S(k).term = names{k};
        S(k).absmax_deg = max(abs(tv));
        S(k).medabs_deg = median(abs(tv));
        S(k).reaches_env_alone = double(max(abs(tv)) >= LIM);
        S(k).n_at_env_alone = sum(abs(tv) >= LIM - 1e-9);
        S(k).raw_absmax_without = max(abs(alt_raw));
        S(k).n_sat_without = sum(abs(alt_raw) > LIM + 1e-9);
        S(k).n_sat_flips = sum((abs(raw) > LIM) ~= (abs(alt_raw) > LIM));
        S(k).n_changed_postmag = sum(abs(d) > 1e-12);
        S(k).frac_changed_postmag = mean(abs(d) > 1e-12);
        S(k).max_change_postmag_deg = max(abs(d));
        S(k).rms_change_postmag_deg = sqrt(mean(d.^2));
        if any(rail)
            sh = tv(rail) ./ raw(rail);
            sh = sh(isfinite(sh));
            S(k).signed_share_median_at_rail = median(sh);
        else
            S(k).signed_share_median_at_rail = NaN;
        end
        S(k).interpretation = '';
    end
end
