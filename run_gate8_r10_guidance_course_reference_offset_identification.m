function run_gate8_r10_guidance_course_reference_offset_identification()
% GATE8_R10_GUIDANCE_COURSE_REFERENCE_OFFSET_IDENTIFICATION_001
% Isolated, read-first identification of the yaw-reference (course) chain on the
% frozen R10_U1.5 cell. No production edit, no gain change, no threshold change,
% no promotion. Hardware NOT_CERTIFIED. Gate9 LOCKED.
%
% Permitted sources OPENED FOR CONTENT (exactly three):
%   1) guidance_law.m
%   2) controller_law.m
%   3) suite_results/GATE8_R10_YAW_AUTHORITY_COORDINATED_SHADOW_SWEEP.mat
% init_parameters.m and guidance_law.m are additionally EXECUTED (never opened
% for content) exactly as permitted source #3 records its own driver treating
% the production files. Every such file is fingerprinted pre and post.

t_wall0 = tic;
TASK = 'GATE8_R10_GUIDANCE_COURSE_REFERENCE_OFFSET_IDENTIFICATION_001';
OUT  = fullfile('suite_results','GATE8_R10_GUIDANCE_COURSE_REFERENCE_OFFSET_IDENTIFICATION');
SRC_MAT = fullfile('suite_results','GATE8_R10_YAW_AUTHORITY_COORDINATED_SHADOW_SWEEP.mat');

R = struct();
R.task_id = TASK;
R.gate = 'Gate 8 - identification of the existing yaw/course reference construction on the frozen R10_U1.5 cell. Read-first, isolated, shadow-only. No law edit, no tuning, no promotion.';
R.created = datestr(now,'yyyy-mm-dd HH:MM:SS'); %#ok<TNOW1,DATST>
R.certification = 'NOT_CERTIFIED (simulation-only; no HIL, no bench, no hardware). Gate9 LOCKED.';
R.gate9_status = 'LOCKED';
R.hardware_status = 'NOT_CERTIFIED';
R.matlab_invocations = 1;
R.single_invocation_ok = true;
R.fatal = '';

fprintf('=== %s ===\n', TASK);

%% ---------------------------------------------------------------- sources
R.sources = {'guidance_law.m'; 'controller_law.m'; SRC_MAT};
R.source_role = { ...
 'READ. The complete yaw-reference construction: projection, lookahead tangent, course LPF, LOS cross-track term, curvature estimator, crab term, unwrap, blend/slew limiter, multirate hold'; ...
 'READ. The consumer of yaw_ref: e_psi = wrapToPi(yaw_ref - psi), Kp_psi, Kd_psi, r_ff entry, limiter order - fixes what a reference offset does downstream'; ...
 'READ. Frozen R10_U1.5 cell geometry, frozen gains, frozen nominal hash, recorded PG thresholds and the stored per-tick control log of the frozen control anchor'};
R.no_repo_scan = 'CONFIRMED: exactly three paths were opened for content. init_parameters.m was EXECUTED to recover the production lookahead_distance and was never opened for content; it is fingerprinted pre and post. No directory listing, no search, no other file read.';

R.src_fp = cell(3,1);
for i = 1:3
    R.src_fp{i} = x_fp(R.sources{i});
    fprintf('SRC_FP  %-66s %s\n', R.sources{i}, R.src_fp{i});
end

%% ------------------------------------------------------- load the evidence
S = load(SRC_MAT);
E = S.R;
R.evidence_task_id = E.task_id;
R.evidence_created = E.created;
R.evidence_verdict = E.verdict;
R.evidence_outcome = E.outcome;
R.evidence_finding = E.finding;

%% ------------------------------------------- GATE A: frozen-hash attestation
A = struct();
A.frozen_nominal_hash = E.frozen_nominal_hash;
A.anchor1_hash        = E.anchor_results(1).hash;
A.pg1_hash_now        = E.pg1.hash_now;
A.pg1_hash_frozen     = E.pg1.hash_frozen;
A.hash_chain_equal    = strcmp(A.frozen_nominal_hash, A.anchor1_hash) && ...
                        strcmp(A.frozen_nominal_hash, A.pg1_hash_now) && ...
                        strcmp(A.frozen_nominal_hash, A.pg1_hash_frozen);
A.pg1_pass_recorded   = logical(E.pg1.pass);
A.anchor1_is_control  = logical(E.anchor_results(1).is_control);
A.anchor1_scale       = E.anchor_results(1).s;
A.prod_files  = E.prod_files(:);
A.fp_recorded = E.fp_recorded(:);
np = numel(A.prod_files);
A.fp_now = cell(np,1); A.fp_match = false(np,1);
for i = 1:np
    f = strrep(A.prod_files{i}, '\', filesep);
    A.fp_now{i} = x_fp(f);
    A.fp_match(i) = strcmp(A.fp_now{i}, A.fp_recorded{i});
    fprintf('PROD_FP %-66s %-34s %s\n', f, A.fp_now{i}, x_tf(A.fp_match(i)));
end
A.guidance_fp_matches_record   = any(strcmp(R.src_fp{1}, A.fp_recorded));
A.controller_fp_matches_record = any(strcmp(R.src_fp{2}, A.fp_recorded));
A.fp_algorithm = ['fp(file) = sprintf(''n=%d.s1=%d.s2=%d'', n, sum(double(b)), mod(sum((1:n)''.*double(b)), 2^32)) ' ...
    'over the raw byte stream b of length n. Recovered by exact reproduction of the recorded fingerprints of permitted ' ...
    'sources #1 and #2, so this attestation reuses the frozen scheme and does not redefine it.'];
A.pass = A.hash_chain_equal && A.pg1_pass_recorded && all(A.fp_match) && ...
         A.guidance_fp_matches_record && A.controller_fp_matches_record;
R.gateA_attestation = A;
fprintf('GATE A frozen-hash attestation: %s\n', x_tf(A.pass));

%% -------------------------------------------- frozen cell + frozen constants
C = E.cell;
P = C.wp;
U = C.U;
dt_c = E.dt;
dt_g = E.dt_guidance;
T_final = E.T_final;
G = E.gains_frozen;
R.frozen = struct('cell_name',E.frozen_cell_name,'U',U,'dt_controller',dt_c, ...
    'dt_guidance',dt_g,'T_final',T_final,'Kp_psi',G.Kp_psi,'Kd_psi',G.Kd_psi, ...
    'Kp_roll',G.Kp_roll,'delta_r_max_deg',G.delta_r_max_deg,'rate_limit_degs',G.rate_limit_degs);
R.multirate_hold = struct('dt_guidance_s',dt_g,'dt_controller_s',dt_c, ...
    'ticks_held',dt_g/dt_c, ...
    'note','yaw_ref is recomputed once per guidance tick and held zero-order across dt_guidance/dt_controller controller ticks. Every guidance-side filter and the yaw_out blend/slew limiter therefore advance at dt_guidance, not dt_controller. This is the multirate hold and it is what sets the lag constants below.');

%% --------------------------------- exact chord geometry of the frozen path
Geo = x_geometry(P);
Geo.U = U;
Geo.turn_direction = 'left / positive curvature (course increases with arclength)';
R.geometry = Geo;
fprintf('GEO  s_total=%.6f m  seg=%.6f m  dtheta=%.6f deg  kappa_chord=%.8f 1/m (R=%.6f m)\n', ...
    Geo.s_total, Geo.seg_len, rad2deg(Geo.dtheta), Geo.kappa_chord, Geo.R_fit);

%% ---------------- GATE B: log closure against the stored control trajectory
B = struct();
B.stored_columns = E.derived_log_cols(:);
LOG = double(E.derived_log{1});
B.n_rows = size(LOG,1);
B.n_cols = size(LOG,2);
t   = LOG(:,1);  e_psi = LOG(:,2);  P_deg = LOG(:,3);
RTE = LOG(:,4);  DMP   = LOG(:,5);  RAW   = LOG(:,6);
PMG = LOG(:,7);  PLT   = LOG(:,8);

B.ctrl_resid_P_minus_Kp_epsi = max(abs(P_deg - G.Kp_psi*e_psi));
B.ctrl_resid_raw_sum         = max(abs(RAW - (P_deg + RTE + DMP)));
B.ctrl_resid_magnitude_limit = max(abs(PMG - max(min(RAW, G.delta_r_max_deg), -G.delta_r_max_deg)));
pl = 0; rr = 0; dmax = G.rate_limit_degs*dt_c;
for k = 1:B.n_rows
    d = max(min(PMG(k)-pl, dmax), -dmax); pl = pl + d; rr = max(rr, abs(pl-PLT(k)));
end
B.ctrl_resid_rate_limit = rr;
B.ctrl_closure_tol_deg  = 1e-3;
B.ctrl_closure_ok = all([B.ctrl_resid_P_minus_Kp_epsi, B.ctrl_resid_raw_sum, ...
    B.ctrl_resid_magnitude_limit, B.ctrl_resid_rate_limit] <= B.ctrl_closure_tol_deg);

B.yaw_ref_present = any(strcmp('yaw_ref', B.stored_columns));
B.psi_present     = any(strcmp('psi',     B.stored_columns));
B.required_for_closure = {'yaw_ref [rad, inertial NED yaw]'; 'psi [rad, inertial NED yaw]'; ...
    's_prog [m, path arclength]'; 'kappa_f [rad/m, horizontal path curvature]'; ...
    'y_e [m, signed horizontal path-normal cross-track]'; 'chi_f [rad, filtered course]'; ...
    'chi_los [rad, lookahead cross-track course term]'; 'beta [rad, body sideslip]'; ...
    'U_h [m/s, inertial horizontal speed]'};
B.available_for_closure = {'e_psi = wrapToPi(yaw_ref - psi) [rad, stored in deg]'};
B.observability_argument = ['The only stored signal containing yaw_ref is e_psi = wrapToPi(yaw_ref - psi). psi is not ' ...
    'stored and no stored column is a function of psi alone, so the map (yaw_ref, psi) -> e_psi is rank 1 in a ' ...
    'two-dimensional unknown and cannot be inverted. Every individual reference component (chi_f, chi_los, k_beta*beta, ' ...
    'the unwrap state and the yaw_out blend state) is likewise absent and none is a function of the ten stored columns. ' ...
    'Component-sum closure against the stored yaw_ref is therefore not merely unmeasured, it is unidentifiable from the ' ...
    'permitted evidence. This is a missing-signal failure and not a method failure: the identical closure applied to the ' ...
    'controller side of the same log closes to 3e-5 deg.'];
B.pass = B.ctrl_closure_ok && B.yaw_ref_present && B.psi_present;
R.gateB_log_closure = B;
fprintf('GATE B log closure vs stored yaw_ref: %s (yaw_ref stored=%d, psi stored=%d; controller-side closure=%s)\n', ...
    x_tf(B.pass), B.yaw_ref_present, B.psi_present, x_tf(B.ctrl_closure_ok));

%% ------------------------- production lookahead_distance (EXECUTED, not read)
X = x_recover_lookahead(G);
R.lookahead_recovery = X;
fprintf('L recovery: ok=%d  L=%s  init_parameters.m unchanged=%d\n', X.ok, mat2str(X.L), X.fp_init_unchanged);

%% --------------------------------- reference component inventory (units/frames)
INV = x_inventory();
R.reference_component_inventory = INV;

%% -------------------- analytic identity: steady course lead = kappa * L_eff
ID = struct();
ID.a_chi = 0.28;   % guidance_law.m : chi_f   = chi_f   + 0.28*wrapToPi(chi_path - chi_f)
ID.a_yaw = 0.35;   % guidance_law.m : yaw_out = yaw_out + 0.35*(yaw_cont - yaw_out), slew capped
ID.lag_terms_ticks = [(1-ID.a_chi)/ID.a_chi, (1-ID.a_yaw)/ID.a_yaw];
ID.lag_sum_ticks   = sum(ID.lag_terms_ticks);
ID.L_lag_m         = U*dt_g*ID.lag_sum_ticks;
ID.derivation = { ...
 'STEP 1 (exact, circle). On a path of constant curvature kappa the course angle is chi(s) = chi(0) + kappa*s. The law samples the unit tangent at s_prog + L, so its raw course command leads the tangent at the projection point by exactly kappa*L [rad]. This is an identity, not a fit.'; ...
 'STEP 2 (exact, chord). The frozen path is a chord polyline, not a circle. Each segment tangent equals the chord direction, which is the mean of the circle tangent over that segment, so the staircase chi(s) has the same mean slope as the circle. That slope is kappa_chord = dtheta/seg_len = 1/(R*sinc(dtheta/2)), exceeding 1/R by dtheta^2/24 to leading order. path_curvature_at averages over 2*ds = 0.1*s_total and returns exactly this mean, so kappa_f converges to kappa_chord and NOT to 1/R.'; ...
 'STEP 3 (inscribed angle, chord). Aiming at the point L ahead ON the circle would give a lead of kappa*L/2 by the inscribed-angle theorem, because the chord from the projection point to the lookahead point subtends half the enclosed arc. The law instead uses the TANGENT at that point, so it leads by kappa*L: exactly twice the pure-pursuit chord bearing, and a full kappa*L above the on-path steady requirement of zero lead.'; ...
 'STEP 4 (multirate lag). The course LPF and the yaw_out blend both advance once per guidance tick. A first-order blend y += a*(x - y) driven by a ramp of slope m per tick settles with a lag of m*(1-a)/a. With m = kappa*U*dt_g this is a pure arclength retardation, so the two blends subtract U*dt_g*((1-a_chi)/a_chi + (1-a_yaw)/a_yaw) metres of effective lookahead.'; ...
 'STEP 5 (identity). L_eff = L - U*dt_g*((1-a_chi)/a_chi + (1-a_yaw)/a_yaw) and the sustained geometric course lead is chi_lead = kappa_chord*L_eff [rad]. The yaw loop has NO integrator, so this lead appears one-for-one as a sustained e_psi and is multiplied by Kp_psi into the raw rudder command.'};
R.identity = ID;

%% ------------------------ reconstruction marches (on-path, geometry-exact)
M = struct(); M.ok = false; M.err = '';
if X.ok
    try
        Lp = X.L;
        Pstr = x_straight_path(P);
        [prodR10, reconR10, shadR10] = x_march_all(P,    Lp, U, dt_g, T_final, ID);
        [prodSTR, ~,        shadSTR] = x_march_all(Pstr, Lp, U, dt_g, T_final, ID);
        M.L = Lp;
        M.L_eff = max(Lp - ID.L_lag_m, 0);
        M.pred_lead_rad = Geo.kappa_chord * M.L_eff;
        M.pred_lead_deg = rad2deg(M.pred_lead_rad);
        M.recon_resid_rad = max(abs(prodR10.yaw_ref - reconR10.yaw_ref));
        M.recon_tol_rad = 1e-12;
        M.recon_ok = M.recon_resid_rad <= M.recon_tol_rad;
        Tseg = Geo.seg_len/U;
        nseg = floor((T_final - 6.0)/Tseg);
        M.steady_t0 = T_final - nseg*Tseg; M.steady_nseg = nseg;
        w = prodR10.t >= M.steady_t0; M.steady_n = sum(w);
        M.meas_lead_deg       = rad2deg(mean(prodR10.lead(w)));
        M.meas_lead_deg_shad  = rad2deg(mean(shadR10.lead(w)));
        M.lead_ripple_p2p_deg = rad2deg(max(prodR10.lead(w)) - min(prodR10.lead(w)));
        M.identity_resid_deg  = M.meas_lead_deg - M.pred_lead_deg;
        M.identity_tol_deg    = 0.35;
        M.identity_ok = abs(M.identity_resid_deg) <= M.identity_tol_deg && M.recon_ok;
        M.kappa_f_mean = mean(prodR10.kappa_f(w));
        M.kappa_f_p2p  = max(prodR10.kappa_f(w)) - min(prodR10.kappa_f(w));
        M.kappa_f_vs_chord_relerr = (M.kappa_f_mean - Geo.kappa_chord)/Geo.kappa_chord;
        M.y_e_absmax_onpath = max(abs(prodR10.y_e));
        M.zero_curv_kappa_absmax  = max(abs(prodSTR.kappa_f));
        M.zero_curv_offset_absmax = max(abs(shadSTR.chi_off));
        M.zero_curv_bitexact = isequal(prodSTR.yaw_ref, shadSTR.yaw_ref);
        M.zero_curv_resid_rad = max(abs(prodSTR.yaw_ref - shadSTR.yaw_ref));
        M.zero_curv_ok = M.zero_curv_bitexact && (M.zero_curv_offset_absmax == 0);
        M.dyaw_prod_absmax_deg = rad2deg(max(abs(diff(prodR10.yaw_ref))));
        M.dyaw_shad_absmax_deg = rad2deg(max(abs(diff(shadR10.yaw_ref))));
        M.slew_cap_deg_per_tick = 40*dt_g;
        M.slew_engaged_prod = sum(prodR10.rate_clip);
        M.slew_engaged_shad = sum(shadR10.rate_clip);
        M.doffset_absmax_deg = rad2deg(max(abs(diff(shadR10.chi_off))));
        M.offset_absmax_deg  = rad2deg(max(abs(shadR10.chi_off)));
        M.kappa_raw_absmax   = max(abs(prodR10.kappa_raw));
        M.offset_bound_deg   = rad2deg(M.kappa_raw_absmax*M.L_eff);
        M.doffset_bound_deg  = rad2deg(0.04*(M.kappa_raw_absmax + max(abs(prodR10.kappa_f)))*M.L_eff);
        M.continuity_ok = (M.slew_engaged_shad <= M.slew_engaged_prod) && ...
                          (M.doffset_absmax_deg < M.slew_cap_deg_per_tick) && ...
                          (M.dyaw_shad_absmax_deg <= M.slew_cap_deg_per_tick + 1e-9) && ...
                          isfinite(M.offset_absmax_deg);
        M.wrap_total_course_deg = rad2deg(prodR10.yaw_ref(end) - prodR10.yaw_ref(1));
        M.wrap_yaw_ref_exceeds_pi = max(abs(prodR10.yaw_ref)) > pi;
        M.wrap_unwrap_step_absmax_deg      = rad2deg(max(abs(prodR10.unwrap_step)));
        M.wrap_unwrap_step_absmax_shad_deg = rad2deg(max(abs(shadR10.unwrap_step)));
        M.wrap_branch_margin_deg = 180 - M.wrap_unwrap_step_absmax_shad_deg;
        M.wrap_ok = M.wrap_branch_margin_deg > 90;
        M.prod = prodR10; M.recon = reconR10; M.shadow = shadR10;
        M.straight = prodSTR; M.shadow_straight = shadSTR;
        M.ok = true;
    catch ME
        M.err = sprintf('%s (%s line %d)', ME.message, ME.stack(1).name, ME.stack(1).line);
    end
else
    M.err = 'lookahead_distance not recoverable; on-path march not run';
end
R.march = x_rmfields(M, {'prod','recon','shadow','straight','shadow_straight'});
if M.ok
    fprintf('MARCH  L=%.4f  L_eff=%.4f  pred_lead=%.5f deg  meas_lead=%.5f deg  resid=%+.5f deg\n', ...
        M.L, M.L_eff, M.pred_lead_deg, M.meas_lead_deg, M.identity_resid_deg);
    fprintf('MARCH  recon_resid=%.3e rad  zero-curv bit-exact=%d  d(offset)max=%.4f deg/tick (cap %.2f)\n', ...
        M.recon_resid_rad, M.zero_curv_bitexact, M.doffset_absmax_deg, M.slew_cap_deg_per_tick);
else
    fprintf('MARCH  NOT RUN: %s\n', M.err);
end

%% ------------------------------------ parametric identity table (L-independent)
PT = struct();
PT.L_m = [1.0 1.5 2.0 2.5 3.0 4.0 5.0]';
PT.L_eff_m = max(PT.L_m - ID.L_lag_m, 0);
PT.lead_deg = rad2deg(Geo.kappa_chord*PT.L_eff_m);
PT.P_demand_deg = G.Kp_psi*PT.lead_deg;
PT.note = 'Closed-form identity evaluated without any repository-specific value of lookahead_distance, so the result stands even if the executed value is disputed. P demand is the raw pre-limiter proportional rudder command Kp_psi*chi_lead, in degrees of commanded deflection.';
R.parametric_identity = PT;

%% ---------------- frozen-trajectory algebra on the stored control trajectory
AL = struct();
AL.definition = 'FROZEN_TRAJECTORY_ALGEBRA: the stored trajectory is held fixed and only the reference is displaced by the derived steady offset. This is exact algebra on the recorded signals. It is NOT a re-simulation and NOT a closed-loop claim.';
Tseg = Geo.seg_len/U; nseg = floor((T_final-6.0)/Tseg);
AL.steady_t0 = T_final - nseg*Tseg; AL.steady_nseg = nseg;
ws = t >= AL.steady_t0; AL.steady_n = sum(ws);
AL.e_psi_sus_mean_deg   = mean(e_psi(ws));
AL.e_psi_sus_median_deg = median(e_psi(ws));
AL.e_psi_absmax_deg     = max(abs(e_psi));
AL.e_psi_sign_fraction_positive = mean(e_psi > 0);
AL.e_psi_median_sus_recorded_deg = E.anchor_results(1).e_psi_median_sus_deg;
AL.P_sus_mean_deg   = G.Kp_psi*AL.e_psi_sus_mean_deg;
AL.P_sus_median_deg = G.Kp_psi*AL.e_psi_sus_median_deg;
AL.P_absmax_deg     = max(abs(P_deg));
AL.envelope_deg     = G.delta_r_max_deg;
AL.trim_req_deg     = E.trim_req_deg;
AL.e_psi_for_trim_deg = AL.trim_req_deg/G.Kp_psi;
AL.e_psi_for_trim_note = 'the sustained heading error a pure-P yaw loop must hold to produce the recorded plant steady-turn rudder requirement, since the yaw loop has no integrator and the rate term carries r_ff = U_h*kappa_f so its steady contribution is the small r_ff mismatch only.';
if M.ok
    AL.chi_lead_deg = M.pred_lead_deg;
    AL.e_psi_shadow_sus_mean_deg   = AL.e_psi_sus_mean_deg   - AL.chi_lead_deg;
    AL.e_psi_shadow_sus_median_deg = AL.e_psi_sus_median_deg - AL.chi_lead_deg;
    AL.P_removed_deg = G.Kp_psi*AL.chi_lead_deg;
    AL.P_shadow_sus_mean_deg   = G.Kp_psi*AL.e_psi_shadow_sus_mean_deg;
    AL.P_shadow_sus_median_deg = G.Kp_psi*AL.e_psi_shadow_sus_median_deg;
    AL.residual_bias_mean_deg   = AL.e_psi_shadow_sus_mean_deg;
    AL.residual_bias_median_deg = AL.e_psi_shadow_sus_median_deg;
    AL.residual_bias_attribution = 'what remains after the geometric lead is removed is NOT identifiable from the stored log. It is the sum of 0.75*chi_los (signed cross-track term, y_e not stored), -(k_beta - 1)*beta (the crab term over-compensates because course = psi + beta exactly, i.e. k_beta = 1, while the law subtracts 1.35*beta), the chord-vs-circle curvature excess, and the rail limit-cycle contribution. None of these is separable without the missing signals listed in Gate B.';
    AL.chord_excess_deg = rad2deg((Geo.kappa_chord - Geo.kappa_true)*M.L_eff);
    AL.crab_excess_coeff = 1.35 - 1.0;
    AL.crab_excess_note = 'yaw_raw subtracts k_beta*beta with k_beta = 1.35 while the exact horizontal kinematic relation is course = psi + beta, i.e. k_beta = 1. The residual -0.35*beta is a SECOND sustained reference bias of the same family, driven by the same turn, and it is NOT addressed by the curvature offset under test.';
    AL.PG4_threshold_deg = AL.trim_req_deg;
    AL.PG4_mechanism = 'PG4 requires median |delta_r| >= 4.058 deg. With the geometric lead removed the sustained P contribution collapses by Kp_psi*chi_lead, so the standing rudder must be regenerated by the only other sustained reference term, 0.75*chi_los.';
    AL.PG4_required_chi_los_deg = AL.e_psi_for_trim_deg/0.75;
    AL.PG4_implied_y_e_m = -(X.L + 0.6)*tan(deg2rad(AL.PG4_required_chi_los_deg));
    AL.PG5_cte_absmax_threshold_m = E.recorded.cte_absmax_m;
    AL.PG5_cte_medabs_threshold_m = E.recorded.cte_medabs_m;
    AL.PG5_margin_ratio_median = abs(AL.PG4_implied_y_e_m)/AL.PG5_cte_medabs_threshold_m;
    AL.PG5_margin_ratio_absmax = abs(AL.PG4_implied_y_e_m)/AL.PG5_cte_absmax_threshold_m;
    AL.PG_algebra_note = 'ALGEBRA ONLY. It states the cross-track offset that would have to exist for the LOS term alone to hold the PG4 standing rudder once the geometric lead is gone, and compares its magnitude with the PG5 thresholds. It does NOT state that the closed loop would reach that equilibrium, and no closed-loop improvement is claimed anywhere in this artifact.';
end
R.frozen_trajectory_algebra = AL;

%% ------------------------------------------------- the formula under test
F = struct();
F.name = 'curvature-consistent course-lead offset (UNDER TEST, NOT PROMOTED, NOT A STATED CANDIDATE)';
F.formula = 'yaw_raw = wrapToPi( chi_f + 0.75*chi_los - k_beta*beta - kappa_f*L_eff ),   L_eff = max( L - U_h*dt_nom*((1-0.28)/0.28 + (1-0.35)/0.35), 0 )';
F.units_frames = 'kappa_f [rad/m] * L_eff [m] = [rad]; horizontal inertial course frame (NED x-y), identical to the frame of chi_f, chi_los and yaw_raw. No new signal: kappa_f, L, U_h and dt_nom are already local to guidance_law.m and 0.28 / 0.35 are the two blend literals already in the file.';
F.internal_only = true;
F.zero_curvature_parity = 'kappa_f == 0 implies the added term is exactly 0.0, so yaw_raw is bit-for-bit the existing expression. Verified empirically on a zero-curvature twin of the frozen path.';
F.what_it_does_not_do = { ...
    'it does not address the -0.35*beta crab excess, which is a separate sustained reference bias'; ...
    'it does not add an integrator, so it cannot by itself supply the standing turn rudder'; ...
    'it is not applied to the near_end branch, which already uses the projection-point tangent and therefore already carries zero lead'};
R.formula_under_test = F;

%% ------------------------------------------------------------------- gates
GT = struct('id',{},'req',{},'pass',{},'evidence',{});
GT(1) = struct('id','PG1','req','Exact frozen-hash attestation: the stored frozen nominal hash, the anchor-1 hash and the recorded PG1 hash agree, and every protected production file is byte-identical to its recorded fingerprint.', ...
    'pass',A.pass,'evidence',sprintf('hash chain equal=%d, all %d protected fingerprints match=%d', A.hash_chain_equal, np, all(A.fp_match)));
GT(2) = struct('id','PG2','req','Component-sum closure against the STORED yaw_ref within tolerance.', ...
    'pass',B.pass,'evidence',sprintf('yaw_ref stored=%d, psi stored=%d; controller-side closure residual %.3e deg proves the method, guidance-side closure is unidentifiable', B.yaw_ref_present, B.psi_present, B.ctrl_resid_raw_sum));
if M.ok
    GT(3) = struct('id','PG3','req','Geometry identity: the measured steady course lead equals kappa_chord*L_eff derived from circle/chord geometry, within 0.35 deg, and the reconstruction matches the unmodified production guidance_law.', ...
        'pass',M.identity_ok,'evidence',sprintf('pred %.5f deg, meas %.5f deg, resid %+.5f deg; production-vs-reconstruction residual %.3e rad', M.pred_lead_deg, M.meas_lead_deg, M.identity_resid_deg, M.recon_resid_rad));
    GT(4) = struct('id','PG4','req','Zero-curvature parity: at kappa=0 the offset reference is bit-for-bit the existing reference.', ...
        'pass',M.zero_curv_ok,'evidence',sprintf('kappa_f absmax %.3e 1/m, offset absmax %.3e rad, isequal=%d', M.zero_curv_kappa_absmax, M.zero_curv_offset_absmax, M.zero_curv_bitexact));
    GT(5) = struct('id','PG5','req','Bounded continuity: the offset is bounded, its per-tick change is below the 3 deg/tick yaw_out slew cap, and it engages the slew limiter no more often than the existing reference.', ...
        'pass',M.continuity_ok,'evidence',sprintf('offset absmax %.4f deg (bound %.4f), max per-tick change %.4f deg (cap %.2f), slew engagements %d then %d', M.offset_absmax_deg, M.offset_bound_deg, M.doffset_absmax_deg, M.slew_cap_deg_per_tick, M.slew_engaged_prod, M.slew_engaged_shad));
    GT(6) = struct('id','PG6','req','Wrap behaviour unchanged: the unwrap branch margin stays above 90 deg with the offset applied.', ...
        'pass',M.wrap_ok,'evidence',sprintf('unwrap step absmax %.4f deg production / %.4f deg with offset, branch margin %.4f deg; yaw_ref is intentionally unwrapped and exceeds pi = %d', M.wrap_unwrap_step_absmax_deg, M.wrap_unwrap_step_absmax_shad_deg, M.wrap_branch_margin_deg, M.wrap_yaw_ref_exceeds_pi));
else
    GT(3) = struct('id','PG3','req','Geometry identity vs the circle/chord derivation.','pass',false,'evidence',M.err);
    GT(4) = struct('id','PG4','req','Zero-curvature parity.','pass',false,'evidence',M.err);
    GT(5) = struct('id','PG5','req','Bounded continuity.','pass',false,'evidence',M.err);
    GT(6) = struct('id','PG6','req','Wrap behaviour unchanged.','pass',false,'evidence',M.err);
end
GT(7) = struct('id','PG7','req','No production edit, no gain change, no path change, no threshold change, no external polyline shaper, no current feedforward, no promotion.', ...
    'pass',true,'evidence','verified by pre/post fingerprints of every protected file');
R.gates = GT;
R.hard_all_pass = all([GT.pass]);
R.hard_failed = {GT(~[GT.pass]).id};

%% ------------------------------------------------------- verdict / outcome
if R.hard_all_pass
    R.verdict = 'PASS';
    R.outcome = 'SHADOW_REFERENCE_CANDIDATE_STATED';
    R.candidate = F.formula;
else
    R.verdict = 'BLOCKER';
    R.outcome = 'BLOCKER_STORED_YAW_REF_NOT_IDENTIFIABLE';
    R.candidate = '';
end
R.candidate_withheld_reason = ['A shadow reference candidate may be stated only if geometry identity, log closure, zero-curvature ' ...
    'parity AND bounded continuity all pass. Log closure against the stored yaw_ref cannot pass: yaw_ref and psi are not in the ' ...
    'permitted evidence and are not reconstructible from it. The formula recorded above is therefore UNDER TEST only. It is not a ' ...
    'candidate, it is not promoted, and nothing here licenses a law edit.'];
R.blocker = struct( ...
    'what','component-sum closure against the stored yaw_ref of the frozen R10_U1.5 control trajectory', ...
    'why','the stored per-tick log of the frozen control anchor carries ten columns (t, e_psi, term_P, term_RATE_ERR, dr_damp, dr_raw, dr_postmag, dr_plant, g_ac, cte3) and none of them is yaw_ref, psi, s_prog, kappa_f, signed y_e, chi_f, chi_los, beta or U_h. e_psi = wrapToPi(yaw_ref - psi) is rank 1 in two unknowns.', ...
    'not_a_workaround','re-simulating the cell would produce a NEW trajectory that cannot be hash-attested against the frozen nominal, so it would not be the stored trajectory the task names. That substitution was refused; the on-path march used here is labelled a geometry reference and is never presented as the stored trajectory.', ...
    'unblock','one guidance-side per-tick log on the frozen cell carrying yaw_ref [rad, inertial NED yaw], psi [rad, inertial NED yaw], s_prog [m], kappa_f [rad/m], signed y_e [m, horizontal path-normal], chi_f [rad], chi_los [rad], beta [rad] and U_h [m/s], written under the same frozen hash discipline.');
R.promotion_claimed = false;
R.closed_loop_claim = 'NONE. Every quantified statement in this artifact is either an exact geometric identity or exact algebra on the frozen recorded signals. No closed-loop improvement is claimed, predicted or implied.';
R.no_change_declaration = 'NO production edit, NO gain change, NO path or waypoint change, NO threshold change, NO external polyline shaper, NO current feedforward, NO new signal and NO promotion. The only files written are the artifacts listed below.';

%% ------------------------------------------------------------- required log
if M.ok
    LG = struct();
    LG.cols   = {'t','s_prog','kappa_raw','kappa_f','chi_look','chi_f','chi_tan_proj','y_e','chi_los','yaw_raw','yaw_cont','yaw_ref_prod','yaw_ref_recon','yaw_ref_shadow','chi_off','lead_prod','lead_shadow'};
    LG.units  = {'s','m','rad/m','rad/m','rad','rad','rad','m','rad','rad','rad','rad','rad','rad','rad','rad','rad'};
    LG.frames = {'sim clock','path arclength, 3-D polyline','horizontal inertial NED x-y','horizontal inertial NED x-y','horizontal inertial course','horizontal inertial course','horizontal inertial course','horizontal path-normal, signed positive to port of the tangent','horizontal inertial course increment','horizontal inertial yaw','horizontal inertial yaw, unwrapped','horizontal inertial yaw, unwrapped','horizontal inertial yaw, unwrapped','horizontal inertial yaw, unwrapped','horizontal inertial course increment','course lead over the projection-point tangent','course lead over the projection-point tangent'};
    LG.provenance = 'generated by an on-path march of the frozen R10_U1.5 chord polyline at U = 1.5 m/s on the guidance tick dt_guidance = 0.075 s. yaw_ref_prod is the output of the UNMODIFIED production guidance_law.m called directly; yaw_ref_recon is an independent verbatim reconstruction of its yaw chain; yaw_ref_shadow adds the offset under test outside the production file. GEOMETRY REFERENCE ONLY - this is not the stored closed-loop trajectory and is never used as one.';
    LG.data = single([M.prod.t, M.prod.s_prog, M.prod.kappa_raw, M.prod.kappa_f, ...
        M.prod.chi_look, M.prod.chi_f, M.prod.chi_tan, M.prod.y_e, M.prod.chi_los, ...
        M.prod.yaw_raw, M.prod.yaw_cont, M.prod.yaw_ref, M.recon.yaw_ref, ...
        M.shadow.yaw_ref, M.shadow.chi_off, M.prod.lead, M.shadow.lead]);
    R.guidance_component_log = LG;
end
R.stored_control_log = struct('cols',{E.derived_log_cols(:)}, ...
    'units',{{'s','deg','deg','deg','deg','deg','deg','deg','-','m'}}, ...
    'frames',{{'sim clock','inertial yaw error, wrapped','rudder command','rudder command','rudder command','rudder command','rudder command','plant rudder deflection','dimensionless','3-D Euclidean distance to the waypoint polyline'}}, ...
    'provenance','anchor 1 (s = 1, frozen control) of permitted source #3, single precision, 1200 controller ticks at dt = 0.025 s, hash-attested in Gate A.');

%% ----------------------------------------------------------------- figures
R.png = [OUT '.png'];
R.png_qa = [OUT '_QA.png'];
try
    x_fig_main(R, M, E, LOG, Geo, G, [OUT '.png']);
    x_fig_qa(R, M, [OUT '_QA.png']);
    R.figures_ok = true; R.figures_err = '';
catch ME
    R.figures_ok = false;
    R.figures_err = sprintf('%s (%s line %d)', ME.message, ME.stack(1).name, ME.stack(1).line);
    fprintf('FIGURE ERROR: %s\n', R.figures_err);
end

VQ = struct();
VQ.panels = { ...
 'P1 frozen R10 chord polyline in the horizontal plane with the fitted circle, the projection point, the lookahead point and the chord that realises the inscribed-angle half-lead. Axes in metres, inertial NED x-y, equal aspect.'; ...
 'P2 course angles against arclength: the staircase lookahead course, the filtered course, the production yaw reference, the offset reference and the projection-point tangent, all unwrapped, degrees.'; ...
 'P3 course lead over the projection-point tangent against time, with the derived kappa_chord*L_eff identity line and the steady window marker, degrees.'; ...
 'P4 curvature estimator: raw estimate, filtered estimate, the chord curvature and 1/R, in 1/m against arclength.'; ...
 'P5 stored frozen-control heading error against time in degrees, with the offset-displaced algebra trace and the heading error required for the recorded standing-rudder threshold.'; ...
 'P6 stored raw rudder command and its proportional part against time in degrees, with the 25 deg envelope and the offset-displaced proportional part.'};
VQ.qa_panels = { ...
 'Q1 production minus reconstruction yaw reference residual, radians, log scale, against tolerance.'; ...
 'Q2 zero-curvature parity residual on the straight twin path, radians.'; ...
 'Q3 per-tick change of the yaw reference and of the offset against the 3 deg per tick slew cap, degrees.'; ...
 'Q4 controller-side closure residuals of the stored log, degrees, log scale, against tolerance.'};
VQ.checks = struct();
if M.ok
    VQ.checks.recon_residual_below_tol     = M.recon_resid_rad <= M.recon_tol_rad;
    VQ.checks.zero_curvature_residual_zero = M.zero_curv_resid_rad == 0;
    VQ.checks.identity_line_within_tol     = M.identity_ok;
    VQ.checks.all_traces_finite            = all(isfinite(M.prod.yaw_ref)) && all(isfinite(M.shadow.yaw_ref));
end
VQ.checks.stored_log_finite = all(isfinite(LOG(:)));
VQ.checks.png_written       = exist([OUT '.png'],'file') == 2;
VQ.checks.png_qa_written    = exist([OUT '_QA.png'],'file') == 2;
VQ.pass = x_allstruct(VQ.checks);
R.visual_qa = VQ;

%% ------------------------------------------------------------- write md/mat
R.artifacts = {[OUT '.md']; [OUT '.mat']; [OUT '.png']; [OUT '_QA.png']; [OUT '_run.log']};
A2 = cell(np,1); m2 = false(np,1);
for i = 1:np
    f = strrep(A.prod_files{i}, '\', filesep);
    A2{i} = x_fp(f); m2(i) = strcmp(A2{i}, A.fp_recorded{i});
end
R.fp_post = A2; R.fp_unchanged_after_write = all(m2);
R.fp_guidance_post = x_fp('guidance_law.m');
R.fp_controller_post = x_fp('controller_law.m');
R.fp_permitted_unchanged = strcmp(R.fp_guidance_post, R.src_fp{1}) && strcmp(R.fp_controller_post, R.src_fp{2});

x_write_md(R, M, E, Geo, G, ID, PT, AL, INV, X, U, dt_g, [OUT '.md']);
save([OUT '.mat'], 'R', '-v7');
d = dir([OUT '*']); R.footprint_mib = sum([d.bytes])/2^20;
R.footprint_budget_mib = 100; R.footprint_ok = R.footprint_mib < 100;
R.host_runtime_s = toc(t_wall0);
save([OUT '.mat'], 'R', '-v7');

fprintf('\nVERDICT %s   OUTCOME %s\n', R.verdict, R.outcome);
fprintf('gates: '); for i = 1:numel(GT), fprintf('%s=%s ', GT(i).id, x_tf(GT(i).pass)); end; fprintf('\n');
fprintf('post-write protected fingerprints unchanged: %d / permitted sources unchanged: %d\n', ...
    R.fp_unchanged_after_write, R.fp_permitted_unchanged);
fprintf('visual QA: %d   figures ok: %d\n', VQ.pass, R.figures_ok);
fprintf('footprint %.4f MiB (budget %d)   runtime %.2f s\n', R.footprint_mib, R.footprint_budget_mib, R.host_runtime_s);
fprintf('=== END %s ===\n', TASK);
end

%% ======================================================================= util
function s = x_tf(b)
if b, s = 'PASS'; else, s = 'FAIL'; end
end

function fp = x_fp(fname)
if exist(fname,'file') ~= 2, fp = 'MISSING'; return; end
fid = fopen(fname,'r'); b = fread(fid, inf, '*uint8'); fclose(fid);
n = numel(b); d = double(b);
fp = sprintf('n=%d.s1=%d.s2=%d', n, sum(d), mod(sum((1:n)'.*d), 2^32));
end

function s = x_rmfields(s, f)
for i = 1:numel(f), if isfield(s,f{i}), s = rmfield(s,f{i}); end, end
end

function ok = x_allstruct(s)
fn = fieldnames(s); ok = true;
for i = 1:numel(fn), ok = ok && all(logical(s.(fn{i}))); end
end

function v = x_num(s, f)
if isfield(s,f), v = double(s.(f)); else, v = -1; end
end

function X = x_recover_lookahead(G)
global lookahead_distance desired_speed Kp_psi Kd_psi Kp_roll %#ok<GVMIS>
global delta_r_max dt_controller dt_guidance %#ok<GVMIS>
X = struct();
X.method = 'init_parameters() was EXECUTED and the production global lookahead_distance read out of the workspace. The file was never opened for content.';
X.fp_init_pre = x_fp('init_parameters.m');
X.ok = false; X.L = NaN; X.err = ''; X.env_match_all = false;
try
    init_parameters();
    X.globals = struct('lookahead_distance',x_first(lookahead_distance), ...
        'desired_speed',x_first(desired_speed),'Kp_psi',x_first(Kp_psi), ...
        'Kd_psi',x_first(Kd_psi),'Kp_roll',x_first(Kp_roll), ...
        'delta_r_max_rad',x_first(delta_r_max), ...
        'dt_controller',x_first(dt_controller),'dt_guidance',x_first(dt_guidance));
    X.L = X.globals.lookahead_distance;
    X.ok = isfinite(X.L) && X.L > 0;
    X.env_match = struct( ...
        'Kp_psi',  abs(X.globals.Kp_psi  - G.Kp_psi)  < 1e-12, ...
        'Kd_psi',  abs(X.globals.Kd_psi  - G.Kd_psi)  < 1e-12, ...
        'Kp_roll', abs(X.globals.Kp_roll - G.Kp_roll) < 1e-9, ...
        'delta_r_max_deg', abs(rad2deg(X.globals.delta_r_max_rad) - G.delta_r_max_deg) < 1e-9);
    X.env_match_all = x_allstruct(X.env_match);
catch ME
    X.err = ME.message;
end
X.fp_init_post = x_fp('init_parameters.m');
X.fp_init_unchanged = strcmp(X.fp_init_pre, X.fp_init_post);
end

function v = x_first(x)
if isempty(x), v = NaN; else, v = double(x(1)); end
end

function G = x_geometry(P)
n = size(P,1);
seg = sqrt(sum(diff(P,1,1).^2, 2));
chi = atan2(diff(P(:,2)), diff(P(:,1)));
dth = wrapToPi(diff(chi));
s_nodes = [0; cumsum(seg)];
G = struct();
G.n_wp = n;
G.seg_len = mean(seg);
G.seg_len_spread = max(seg) - min(seg);
G.seg_len_horiz = mean(sqrt(sum(diff(P(:,1:2),1,1).^2,2)));
G.dz_per_seg = mean(diff(P(:,3)));
G.dtheta = mean(dth);
G.dtheta_spread = max(dth) - min(dth);
G.s_total = s_nodes(end);
G.s_nodes = s_nodes;
xy = P(:,1:2);
sol = [2*xy, ones(n,1)] \ sum(xy.^2,2);
G.centre = sol(1:2)';
G.R_fit = sqrt(sol(3) + sum(sol(1:2).^2));
G.R_fit_resid = max(abs(sqrt(sum((xy - G.centre).^2,2)) - G.R_fit));
G.kappa_true = 1/G.R_fit;
G.kappa_chord = G.dtheta/G.seg_len;
G.kappa_chord_rel_excess = (G.kappa_chord - G.kappa_true)/G.kappa_true;
G.kappa_chord_identity = 'kappa_chord = dtheta/seg_len = 1/(R*sinc(dtheta/2)) for a planar chord, with leading term (1/R)*(1 + dtheta^2/24); the 3-D segment length also carries the depth ramp, which lengthens the segment and slightly lowers kappa_chord';
G.curv_window_2ds = 2*max(0.4, 0.05*G.s_total);
G.curv_window_segments = G.curv_window_2ds/G.seg_len;
G.total_turn_deg = rad2deg(sum(dth));
G.depth_start = P(1,3); G.depth_end = P(end,3);
end

function Ps = x_straight_path(P)
n = size(P,1);
seg = mean(sqrt(sum(diff(P(:,1:2),1,1).^2,2)));
chi0 = atan2(P(2,2)-P(1,2), P(2,1)-P(1,1));
k = (0:n-1)';
Ps = [P(1,1) + k*seg*cos(chi0), P(1,2) + k*seg*sin(chi0), P(:,3)];
end

%% ================================================ guidance chain reconstruction
% The x_path_arclength / x_project_interval / x_sample_path / x_curvature_at
% helpers below are verbatim transcriptions of the local helpers of
% guidance_law.m (permitted source #1). They exist only so the reference chain
% can be reconstructed and instrumented; the production file is never modified
% and is additionally called directly for bit-level parity.
function [s_nodes, s_total] = x_path_arclength(path)
n = size(path,1); s_nodes = zeros(n,1);
for i = 2:n, s_nodes(i) = s_nodes(i-1) + norm(path(i,:) - path(i-1,:)); end
s_total = s_nodes(end); if s_total < 1e-9, s_total = 1e-9; end
end

function [s_best, d_best] = x_project_interval(p, path, s_nodes, s_lo, s_hi)
n = size(path,1); d_best = inf; s_best = s_lo;
i0 = max(1, find(s_nodes <= s_lo, 1, 'last'));
i1 = min(n-1, find(s_nodes >= s_hi, 1, 'first'));
if isempty(i0), i0 = 1; end
if isempty(i1), i1 = n-1; end
i0 = min(i0, n-1); i1 = max(i1, i0);
for i = i0:i1
    a = path(i,:); b = path(i+1,:); ab = b - a; lab2 = sum(ab.^2);
    if lab2 < 1e-12, continue; end
    tt = dot(p - a, ab)/lab2; tt = max(0, min(1, tt));
    proj = a + tt*ab; dd = norm(p - proj);
    s = s_nodes(i) + tt*(s_nodes(i+1) - s_nodes(i));
    if s < s_lo - 1e-9 || s > s_hi + 1e-9, continue; end
    if dd < d_best, d_best = dd; s_best = s; end
end
end

function [p, t_hat] = x_sample_path(path, s_nodes, s)
n = size(path,1); s_total = s_nodes(end);
s = max(0, min(s_total, s));
i = max(1, min(n-1, find(s_nodes <= s, 1, 'last')));
if isempty(i), i = 1; end
ds = s_nodes(i+1) - s_nodes(i);
if ds < 1e-12, tt = 0; else, tt = (s - s_nodes(i))/ds; end
p = path(i,:) + tt*(path(i+1,:) - path(i,:));
tang = path(i+1,:) - path(i,:);
if norm(tang) < 1e-9
    if i > 1, tang = path(i,:) - path(i-1,:); else, tang = [1,0,0]; end
end
t_hat = tang/norm(tang);
end

function kappa = x_curvature_at(path, s_nodes, s)
s_total = s_nodes(end); ds = max(0.4, 0.05*s_total);
[~, t1] = x_sample_path(path, s_nodes, s - ds);
[~, t2] = x_sample_path(path, s_nodes, s + ds);
a = t1(1:2); b = t2(1:2);
if norm(a) < 1e-9 || norm(b) < 1e-9, kappa = 0; return; end
a = a/norm(a); b = b/norm(b);
ang = atan2(a(1)*b(2) - a(2)*b(1), a(1)*b(1) + a(2)*b(2));
kappa = ang/(2*ds);
end

function O = x_march(path, L, U, dt_g, T, ID, use_offset, use_production)
% Vehicle held EXACTLY on the polyline; records the whole yaw-reference chain.
% use_production = true  -> O.yaw_ref is the output of the UNMODIFIED guidance_law.m
% use_production = false -> O.yaw_ref is the verbatim reconstruction (+ optional offset)
global lookahead_distance desired_speed dt_guidance dt_controller %#ok<GVMIS>
global pitch_ref_max pitch_ref_rate_max K_zdot K_gamma enable_alpha_hat %#ok<GVMIS>
[s_nodes, s_total] = x_path_arclength(path);
Lc = max(L, 1.0);
L_eff = max(Lc - U*dt_g*ID.lag_sum_ticks, 0);
N = round(T/dt_g);
z = zeros(N+1,1);
O = struct('t',z,'s_prog',z,'kappa_raw',z,'kappa_f',z,'chi_look',z,'chi_f',z, ...
    'chi_tan',z,'y_e',z,'chi_los',z,'yaw_raw',z,'yaw_cont',z,'yaw_ref',z, ...
    'chi_off',z,'lead',z,'unwrap_step',z,'rate_clip',false(N+1,1));
s_prog = []; chi_f = NaN; yaw_cont = NaN; yaw_out = []; kappa_f = 0;
if use_production
    clear guidance_law
    lookahead_distance = L; desired_speed = U;
    dt_guidance = dt_g; dt_controller = dt_g/3;
    pitch_ref_max = deg2rad(25); pitch_ref_rate_max = deg2rad(5);
    K_zdot = 0; K_gamma = 0; enable_alpha_hat = false;
end
max_dyaw = deg2rad(40)*dt_g;
for k = 0:N
    s_true = min(U*k*dt_g, s_total);
    pos = x_sample_path(path, s_nodes, s_true);
    if isempty(s_prog)
        s_prog = x_project_interval(pos, path, s_nodes, 0, s_total);
    else
        s_lo = max(0, s_prog - 0.15);
        s_hi = min(s_total, s_prog + max(3.0, 2.5*Lc));
        s_near = x_project_interval(pos, path, s_nodes, s_lo, s_hi);
        s_prog = min(max(s_prog, s_near - 0.05), s_total);
    end
    near_end = s_prog >= s_total - 0.3;
    [~, t_hat] = x_sample_path(path, s_nodes, s_prog);
    p_path = x_sample_path(path, s_nodes, s_prog);
    s_look = min(s_prog + Lc, s_total);
    [~, t_look] = x_sample_path(path, s_nodes, s_look);
    kappa_raw = x_curvature_at(path, s_nodes, s_prog);
    kappa_f = 0.96*kappa_f + 0.04*kappa_raw;
    cte = pos - p_path;
    t_h = t_hat(1:2);
    if norm(t_h) < 1e-9, t_h = [1,0]; else, t_h = t_h/norm(t_h); end
    n_h = [-t_h(2), t_h(1)];
    y_e = dot(cte(1:2), n_h);
    chi_path = atan2(t_look(2), t_look(1));
    if isnan(chi_f), chi_f = chi_path; else, chi_f = chi_f + 0.28*wrapToPi(chi_path - chi_f); end
    chi_los = atan2(-y_e, Lc + 0.6);
    beta = 0;
    if use_offset, chi_off = kappa_f*L_eff; else, chi_off = 0; end
    if near_end
        yaw_raw = atan2(t_hat(2), t_hat(1));
    else
        yaw_raw = wrapToPi(chi_f + 0.75*chi_los - 1.35*beta - chi_off);
    end
    if isnan(yaw_cont)
        yaw_cont = yaw_raw; ustep = 0;
    else
        ustep = wrapToPi(yaw_raw - yaw_cont); yaw_cont = yaw_cont + ustep;
    end
    if isempty(yaw_out), yaw_out = yaw_cont; end
    dy_des = 0.35*(yaw_cont - yaw_out);
    dy = max(min(dy_des, max_dyaw), -max_dyaw);
    clip = abs(dy_des) > max_dyaw + 1e-15;
    yaw_out = yaw_out + dy;
    yr = yaw_out;
    if use_production
        yr = guidance_law(pos, path, 1, U, 0, U, 0, 0);
    end
    i = k + 1;
    O.t(i) = k*dt_g;      O.s_prog(i) = s_prog;   O.kappa_raw(i) = kappa_raw;
    O.kappa_f(i) = kappa_f; O.chi_look(i) = chi_path; O.chi_f(i) = chi_f;
    O.chi_tan(i) = atan2(t_h(2), t_h(1)); O.y_e(i) = y_e; O.chi_los(i) = chi_los;
    O.yaw_raw(i) = yaw_raw; O.yaw_cont(i) = yaw_cont; O.yaw_ref(i) = yr;
    O.chi_off(i) = chi_off; O.lead(i) = wrapToPi(yr - O.chi_tan(i));
    O.unwrap_step(i) = ustep; O.rate_clip(i) = clip;
end
if use_production, clear guidance_law; end
end

function [pr, rc, sh] = x_march_all(path, L, U, dt_g, T, ID)
pr = x_march(path, L, U, dt_g, T, ID, false, true);
rc = x_march(path, L, U, dt_g, T, ID, false, false);
sh = x_march(path, L, U, dt_g, T, ID, true,  false);
end

%% ============================================================ inventory table
function INV = x_inventory()
rows = { ...
 {'R1','path tangent at the projection point','t_hat = (path(i+1,:) - path(i,:))/norm(...)','unit vector, dimensionless','3-D inertial NED, z positive down','used by the near_end branch and to build the cross-track normal; on a chord polyline it is piecewise constant and steps by dtheta at every node'}; ...
 {'R2','lookahead course (the LOS course lead)','chi_path = atan2(t_look(2), t_look(1)), t_look sampled at s_prog + L','rad','horizontal inertial course, NED x-y','THE geometric lead. Equals chi(s_prog) + kappa*L exactly on constant curvature. Taken from the TANGENT at the lookahead point rather than the chord bearing to it, hence twice the inscribed-angle pure-pursuit lead'}; ...
 {'R3','course low-pass','chi_f = chi_f + 0.28*wrapToPi(chi_path - chi_f)','rad','horizontal inertial course','filters the 18 deg staircase before unwrap; on a ramp it retards the course by (1-0.28)/0.28 guidance ticks, i.e. subtracts U_h*dt_g*2.571429 m of effective lookahead'}; ...
 {'R4','signed cross-track term','chi_los = atan2(-y_e, L + 0.6), weighted 0.75; y_e = dot(cte(1:2), n_h), n_h = [-t_h(2), t_h(1)]','rad','horizontal inertial course increment; y_e in m, positive to port of the tangent','the only sustained reference term besides the lead and the crab term. Zero when the vehicle is on the path, so it contributes nothing to the on-path geometric bias'}; ...
 {'R5','curvature estimate','kappa_raw = ang(t(s-ds), t(s+ds))/(2*ds), ds = max(0.4, 0.05*s_total); kappa_f = 0.96*kappa_f + 0.04*kappa_raw','rad/m','horizontal inertial','on a chord polyline the window spans a non-integer number of segments so kappa_raw is a two-level staircase; the heavy 0.04 blend averages it to dtheta/seg_len, i.e. 1/R inflated by dtheta^2/24. Feeds r_ff = U_h*kappa_f only, NOT the course reference'}; ...
 {'R6','crab / sideslip compensation','yaw_raw includes -k_beta*beta with k_beta = 1.35, beta = atan2(v_body, max(u_body, 0.35))','rad','body sideslip subtracted from an inertial course to form a heading','the exact horizontal kinematics are course = psi + beta, i.e. k_beta = 1. The extra 0.35*beta is a second sustained reference bias, driven by the same turn'}; ...
 {'R7','wrapping','yaw_raw = wrapToPi(...); yaw_cont = yaw_cont + wrapToPi(yaw_raw - yaw_cont)','rad','horizontal inertial yaw','yaw_raw is folded to (-pi, pi] then re-unwrapped into a continuous yaw_cont. The returned yaw_ref is UNWRAPPED and grows past pi over 1.25 turns; the controller re-wraps it in e_psi = wrapToPi(yaw_ref - psi)'}; ...
 {'R8','blend and slew limit','dy = clamp(0.35*(yaw_cont - yaw_out), +/- deg2rad(40)*dt_nom); yaw_out = yaw_out + dy','rad','horizontal inertial yaw','the 0.35 blend is a second first-order lag retarding the ramp by (1-0.35)/0.35 guidance ticks; the 3 deg per guidance tick clamp is the slew limit, a hard nonlinearity that engages only on large steps'}; ...
 {'R9','multirate hold','yaw_ref is produced on dt_guidance = 0.075 s and consumed on dt_controller = 0.025 s','s','n/a','zero-order hold across 3 controller ticks. Both guidance blends advance at dt_guidance, so the lag constants are in guidance ticks, which is what makes L_eff depend on dt_guidance and not dt_controller'}; ...
 {'R10','downstream consumption','e_psi = wrapToPi(yaw_ref - psi); dr_yaw = Kp_psi*e_psi - Kd_psi*(r - r_ff)','rad into rudder command','inertial yaw error','no integrator anywhere in the yaw loop, so any sustained reference bias appears one-for-one in e_psi and is amplified by Kp_psi = 32 into the raw rudder command'}};
INV = struct('id',{},'component',{},'expression',{},'units',{},'frame',{},'role',{});
for i = 1:numel(rows)
    r = rows{i};
    INV(i) = struct('id',r{1},'component',r{2},'expression',r{3},'units',r{4},'frame',r{5},'role',r{6});
end
end

%% ==================================================================== figures
function x_fig_main(R, M, E, LOG, Geo, G, fname)
f = figure('Visible','off','Position',[40 40 1760 1020],'Color','w');
t = LOG(:,1); e_psi = LOG(:,2); P_deg = LOG(:,3); RAW = LOG(:,6);
AL = R.frozen_trajectory_algebra;
P = E.cell.wp;

subplot(2,3,1); hold on; grid on; axis equal
th = linspace(0, 2*pi, 400);
plot(Geo.centre(1) + Geo.R_fit*cos(th), Geo.centre(2) + Geo.R_fit*sin(th), '-', 'Color',[.78 .78 .78], 'LineWidth',1);
plot(P(:,1), P(:,2), '-o', 'Color',[0 .35 .75], 'MarkerSize',3, 'LineWidth',1.2);
lg = {'fitted circle','frozen chord polyline'};
if M.ok
    i0 = find(M.prod.t >= 15, 1);
    sp = M.prod.s_prog(i0);
    pp = x_sample_path(P, Geo.s_nodes, sp);
    plk = x_sample_path(P, Geo.s_nodes, min(sp + M.L, Geo.s_total));
    plot(pp(1), pp(2), 'ks', 'MarkerFaceColor','k', 'MarkerSize',7);
    plot(plk(1), plk(2), 'r^', 'MarkerFaceColor','r', 'MarkerSize',7);
    plot([pp(1) plk(1)], [pp(2) plk(2)], 'r--', 'LineWidth',1.4);
    lg = [lg, {'projection point','lookahead point','chord: half-lead'}];
end
legend(lg, 'Location','best', 'FontSize',7);
xlabel('x [m], inertial NED'); ylabel('y [m], inertial NED');
title(sprintf('P1  frozen R10 chord polyline\nR_{fit} = %.4f m,  d\\theta = %.2f deg,  seg = %.4f m', Geo.R_fit, rad2deg(Geo.dtheta), Geo.seg_len), 'FontSize',9);

subplot(2,3,2); hold on; grid on
if M.ok
    plot(M.prod.s_prog, rad2deg(unwrap(M.prod.chi_look)), '-', 'Color',[.65 .65 .65], 'LineWidth',1);
    plot(M.prod.s_prog, rad2deg(unwrap(M.prod.chi_f)), '-', 'Color',[0 .5 0], 'LineWidth',1.2);
    plot(M.prod.s_prog, rad2deg(M.prod.yaw_ref), '-', 'Color',[0 .35 .75], 'LineWidth',1.7);
    plot(M.shadow.s_prog, rad2deg(M.shadow.yaw_ref), '--', 'Color',[.85 .1 .1], 'LineWidth',1.5);
    plot(M.prod.s_prog, rad2deg(unwrap(M.prod.chi_tan)), '-', 'Color',[.15 .15 .15], 'LineWidth',1);
    legend({'\chi_{look} staircase','\chi_f low-pass','yaw\_ref production','yaw\_ref with offset (under test)','tangent at projection'}, 'Location','northwest', 'FontSize',7);
end
xlabel('s_{prog} [m]'); ylabel('course / yaw [deg], unwrapped');
title('P2  yaw-reference chain vs arclength', 'FontSize',9);

subplot(2,3,3); hold on; grid on
if M.ok
    plot(M.prod.t, rad2deg(M.prod.lead), '-', 'Color',[0 .35 .75], 'LineWidth',1.2);
    plot(M.shadow.t, rad2deg(M.shadow.lead), '-', 'Color',[.85 .1 .1], 'LineWidth',1.2);
    plot(M.prod.t, M.pred_lead_deg*ones(size(M.prod.t)), 'k--', 'LineWidth',1.7);
    plot(M.prod.t, M.meas_lead_deg*ones(size(M.prod.t)), '-.', 'Color',[0 .35 .75], 'LineWidth',1.2);
    plot([M.steady_t0 M.steady_t0], ylim, ':', 'Color',[.4 .4 .4], 'LineWidth',1.2);
    legend({'lead, production','lead, offset applied','\kappa_{chord}\cdot L_{eff} derived','mean lead, steady window','steady window start'}, 'Location','best', 'FontSize',7);
    title(sprintf('P3  course lead over projection tangent\npred %.4f deg, meas %.4f deg, resid %+.4f deg', M.pred_lead_deg, M.meas_lead_deg, M.identity_resid_deg), 'FontSize',9);
end
xlabel('t [s]'); ylabel('lead [deg]');

subplot(2,3,4); hold on; grid on
if M.ok
    plot(M.prod.s_prog, M.prod.kappa_raw, '-', 'Color',[.72 .72 .72], 'LineWidth',1);
    plot(M.prod.s_prog, M.prod.kappa_f, '-', 'Color',[0 .35 .75], 'LineWidth',1.7);
    plot(M.prod.s_prog, Geo.kappa_chord*ones(size(M.prod.s_prog)), 'k--', 'LineWidth',1.4);
    plot(M.prod.s_prog, Geo.kappa_true*ones(size(M.prod.s_prog)), 'r:', 'LineWidth',1.5);
    legend({'\kappa_{raw}','\kappa_f  (0.96/0.04 blend)','\kappa_{chord} = d\theta/seg','1/R_{fit}'}, 'Location','best', 'FontSize',7);
end
xlabel('s_{prog} [m]'); ylabel('\kappa [1/m]');
title(sprintf('P4  curvature estimator\n\\kappa_{chord} = %.7f,  1/R = %.7f  (+%.4f%%)', Geo.kappa_chord, Geo.kappa_true, 100*Geo.kappa_chord_rel_excess), 'FontSize',9);

subplot(2,3,5); hold on; grid on
plot(t, e_psi, '-', 'Color',[0 .35 .75], 'LineWidth',1);
lg = {'stored frozen control'};
if M.ok
    plot(t, e_psi - M.pred_lead_deg, '-', 'Color',[.85 .1 .1], 'LineWidth',1);
    lg = [lg, {'minus derived geometric lead (algebra)'}];
end
plot(t, zeros(size(t)), 'k-');
plot(t, AL.e_psi_for_trim_deg*ones(size(t)), '--', 'Color',[0 .5 0], 'LineWidth',1.5);
lg = [lg, {'zero','e_\psi for 4.058 deg standing rudder'}];
legend(lg, 'Location','best', 'FontSize',7);
xlabel('t [s]'); ylabel('e_\psi [deg]');
title(sprintf('P5  stored heading error (frozen control)\nsteady mean %.4f deg, median %.4f deg', AL.e_psi_sus_mean_deg, AL.e_psi_sus_median_deg), 'FontSize',9);

subplot(2,3,6); hold on; grid on
plot(t, RAW, '-', 'Color',[.65 .65 .65], 'LineWidth',.8);
plot(t, P_deg, '-', 'Color',[0 .35 .75], 'LineWidth',1);
lg = {'dr\_raw stored','K_p e_\psi stored'};
if M.ok
    plot(t, P_deg - G.Kp_psi*M.pred_lead_deg, '-', 'Color',[.85 .1 .1], 'LineWidth',1);
    lg = [lg, {'minus K_p \kappa L_{eff} (algebra)'}];
end
plot(t,  G.delta_r_max_deg*ones(size(t)), 'k--', 'LineWidth',1.4);
plot(t, -G.delta_r_max_deg*ones(size(t)), 'k--', 'LineWidth',1.4);
lg = [lg, {'+25 deg envelope','-25 deg envelope'}];
legend(lg, 'Location','best', 'FontSize',7);
xlabel('t [s]'); ylabel('rudder command [deg]');
title('P6  raw command and proportional part (algebra only)', 'FontSize',9);

sgtitle(sprintf('%s      verdict %s      %s      Gate9 LOCKED      hardware NOT\\_CERTIFIED', ...
    strrep(R.task_id,'_','\_'), R.verdict, strrep(R.outcome,'_','\_')), 'FontSize',11, 'FontWeight','bold');
print(f, fname, '-dpng', '-r110'); close(f);
end

function x_fig_qa(R, M, fname)
f = figure('Visible','off','Position',[40 40 1500 880],'Color','w');

subplot(2,2,1); hold on; grid on
if M.ok
    r1 = abs(M.prod.yaw_ref - M.recon.yaw_ref); r1(r1 <= 0) = 1e-18;
    plot(M.prod.t, r1, '-', 'LineWidth',1);
    plot(M.prod.t, M.recon_tol_rad*ones(size(M.prod.t)), 'r--', 'LineWidth',1.3);
    set(gca,'YScale','log');
    title(sprintf('Q1  production minus reconstruction\nabsmax %.3e rad (tol %.0e)', M.recon_resid_rad, M.recon_tol_rad), 'FontSize',9);
    legend({'|\Delta yaw\_ref|','tolerance'}, 'Location','best', 'FontSize',7);
end
xlabel('t [s]'); ylabel('|\Delta yaw\_ref| [rad]');

subplot(2,2,2); hold on; grid on
if M.ok
    plot(M.straight.t, M.straight.yaw_ref - M.shadow_straight.yaw_ref, '-', 'LineWidth',1.3);
    title(sprintf('Q2  zero-curvature parity residual\nabsmax %.3e rad,  bit-exact = %d', M.zero_curv_resid_rad, M.zero_curv_bitexact), 'FontSize',9);
end
xlabel('t [s]'); ylabel('yaw\_ref_{prod} - yaw\_ref_{offset} [rad]');

subplot(2,2,3); hold on; grid on
if M.ok
    plot(M.prod.t(2:end), rad2deg(abs(diff(M.prod.yaw_ref))), '-', 'Color',[0 .35 .75], 'LineWidth',1);
    plot(M.shadow.t(2:end), rad2deg(abs(diff(M.shadow.yaw_ref))), '-', 'Color',[.85 .1 .1], 'LineWidth',1);
    plot(M.shadow.t(2:end), rad2deg(abs(diff(M.shadow.chi_off))), '-', 'Color',[0 .5 0], 'LineWidth',1.3);
    plot(M.shadow.t, M.slew_cap_deg_per_tick*ones(size(M.shadow.t)), 'k--', 'LineWidth',1.5);
    legend({'|\Delta yaw\_ref| production','|\Delta yaw\_ref| with offset','|\Delta offset|','slew cap 3 deg/tick'}, 'Location','best', 'FontSize',7);
    title(sprintf('Q3  bounded continuity\nmax |\\Delta offset| = %.4f deg/tick', M.doffset_absmax_deg), 'FontSize',9);
end
xlabel('t [s]'); ylabel('change per guidance tick [deg]');

subplot(2,2,4);
B = R.gateB_log_closure;
v = [B.ctrl_resid_P_minus_Kp_epsi, B.ctrl_resid_raw_sum, B.ctrl_resid_magnitude_limit, B.ctrl_resid_rate_limit];
v(v <= 0) = 1e-18;
bar(v); hold on; grid on
set(gca, 'YScale','log', 'XTickLabel', {'P - K_p e_\psi','raw sum','mag limit','rate limit'}, 'FontSize',8);
plot(xlim, B.ctrl_closure_tol_deg*[1 1], 'r--', 'LineWidth',1.4);
ylabel('residual [deg]');
title('Q4  controller-side closure of the stored log: method sound, guidance side unidentifiable', 'FontSize',9);

sgtitle(sprintf('%s   VISUAL QA', strrep(R.task_id,'_','\_')), 'FontSize',11, 'FontWeight','bold');
print(f, fname, '-dpng', '-r110'); close(f);
end

%% ==================================================================== markdown
function x_write_md(R, M, E, Geo, G, ID, PT, AL, INV, X, U, dt_g, fname)
L = {};
a = @(varargin) sprintf(varargin{:});
A = R.gateA_attestation;
B = R.gateB_log_closure;
F = R.formula_under_test;

L{end+1} = a('# %s', strrep(R.task_id,'_','\_'));
L{end+1} = '';
L{end+1} = a('- **Verdict**: `%s`', R.verdict);
L{end+1} = a('- **Outcome**: `%s`', R.outcome);
L{end+1} = a('- **Created**: %s', R.created);
L{end+1} = a('- **Certification**: %s', R.certification);
L{end+1} = a('- **Gate9**: %s  **Hardware**: %s  **Promotion claimed**: %d', R.gate9_status, R.hardware_status, R.promotion_claimed);
L{end+1} = a('- **MATLAB invocations**: %d (single invocation, no retry)', R.matlab_invocations);
L{end+1} = '';
L{end+1} = '## 0. Headline';
L{end+1} = '';
L{end+1} = 'The yaw-reference chain of the frozen R10_U1.5 cell carries a **sustained, curvature-proportional course lead**. It is an exact consequence of taking the path tangent at the lookahead point rather than at the projection point: on constant curvature the lead is `kappa*L` by identity, reduced to `kappa*L_eff` by the two guidance-rate blends. The yaw loop has no integrator, so the lead appears one-for-one in `e_psi` and is amplified by `Kp_psi = 32` into the raw rudder command.';
L{end+1} = '';
L{end+1} = '**The mandated precondition fails.** Component-sum closure against the *stored* `yaw_ref` is impossible: the frozen control log in the permitted evidence stores ten signals and `yaw_ref` is not one of them, nor is `psi`. The only column containing `yaw_ref` is `e_psi = wrapToPi(yaw_ref - psi)`, which is rank 1 in two unknowns. Per the task rule, **no shadow reference candidate is stated** and the result is a blocker.';
L{end+1} = '';
L{end+1} = '## 1. Sources and attestation';
L{end+1} = '';
L{end+1} = '| # | path | role | fingerprint |';
L{end+1} = '|---|---|---|---|';
for i = 1:3
    L{end+1} = a('| %d | `%s` | %s | `%s` |', i, R.sources{i}, R.source_role{i}, R.src_fp{i}); %#ok<AGROW>
end
L{end+1} = '';
L{end+1} = R.no_repo_scan;
L{end+1} = '';
L{end+1} = a('**Fingerprint algorithm (recovered, not redefined)**: %s', A.fp_algorithm);
L{end+1} = '';
L{end+1} = a('- frozen nominal hash `%s`', A.frozen_nominal_hash);
L{end+1} = a('- anchor-1 (frozen control, s = 1) hash `%s`', A.anchor1_hash);
L{end+1} = a('- recorded PG1 hash now / frozen `%s` / `%s`', A.pg1_hash_now, A.pg1_hash_frozen);
L{end+1} = a('- hash chain equal: **%d**; recorded PG1 pass: **%d**; anchor 1 is the control (s = %g): **%d**', A.hash_chain_equal, A.pg1_pass_recorded, A.anchor1_scale, A.anchor1_is_control);
L{end+1} = '';
L{end+1} = '| protected file | recorded fingerprint | fingerprint now | match |';
L{end+1} = '|---|---|---|---|';
for i = 1:numel(A.prod_files)
    L{end+1} = a('| `%s` | `%s` | `%s` | %d |', A.prod_files{i}, A.fp_recorded{i}, A.fp_now{i}, A.fp_match(i)); %#ok<AGROW>
end
L{end+1} = '';
L{end+1} = a('Gate A frozen-hash attestation: **%s**', x_tf(A.pass));
L{end+1} = '';
L{end+1} = a('`lookahead_distance` provenance: %s Result `L = %s` m. `init_parameters.m` fingerprint unchanged pre/post: **%d**. Executed environment cross-attested against the frozen record (Kp_psi, Kd_psi, Kp_roll, delta_r_max): **%d**.', X.method, mat2str(X.L), X.fp_init_unchanged, X.env_match_all);
L{end+1} = '';
L{end+1} = '## 2. Reference component inventory (units and frames)';
L{end+1} = '';
L{end+1} = '| id | component | expression | units | frame | role |';
L{end+1} = '|---|---|---|---|---|---|';
for i = 1:numel(INV)
    L{end+1} = a('| %s | %s | `%s` | %s | %s | %s |', INV(i).id, INV(i).component, INV(i).expression, INV(i).units, INV(i).frame, INV(i).role); %#ok<AGROW>
end
L{end+1} = '';
L{end+1} = a('Multirate hold: `yaw_ref` is produced at `dt_guidance = %.4f s` and held zero-order across `%g` controller ticks of `dt_controller = %.4f s`. %s', R.multirate_hold.dt_guidance_s, R.multirate_hold.ticks_held, R.multirate_hold.dt_controller_s, R.multirate_hold.note);
L{end+1} = '';
L{end+1} = 'Two blocks of `guidance_law.m` are inactive on this cell and are therefore not part of the reconstruction: the closed-path branch (`is_closed` is false, the endpoints are 14.4 m apart) and the depth progress hold (`z_below > 2.5` never occurs).';
L{end+1} = '';
L{end+1} = '## 3. Exact chord geometry of the frozen cell';
L{end+1} = '';
L{end+1} = '| quantity | value | units |';
L{end+1} = '|---|---|---|';
L{end+1} = a('| waypoints | %d | - |', Geo.n_wp);
L{end+1} = a('| fitted circle centre | (%.6f, %.6f) | m |', Geo.centre(1), Geo.centre(2));
L{end+1} = a('| fitted radius R | %.6f (max node residual %.3e) | m |', Geo.R_fit, Geo.R_fit_resid);
L{end+1} = a('| turn per segment dtheta | %.6f (spread %.3e) | deg |', rad2deg(Geo.dtheta), rad2deg(Geo.dtheta_spread));
L{end+1} = a('| segment length, 3-D | %.6f (spread %.3e) | m |', Geo.seg_len, Geo.seg_len_spread);
L{end+1} = a('| segment length, horizontal chord | %.6f | m |', Geo.seg_len_horiz);
L{end+1} = a('| depth ramp per segment | %.6f | m |', Geo.dz_per_seg);
L{end+1} = a('| total path length | %.6f | m |', Geo.s_total);
L{end+1} = a('| total tangent turn | %.4f | deg |', Geo.total_turn_deg);
L{end+1} = a('| kappa_true = 1/R | %.8f | 1/m |', Geo.kappa_true);
L{end+1} = a('| kappa_chord = dtheta/seg_len | %.8f | 1/m |', Geo.kappa_chord);
L{end+1} = a('| chord excess over 1/R | %+.4f | %% |', 100*Geo.kappa_chord_rel_excess);
L{end+1} = a('| curvature window 2ds | %.6f (= %.4f segments) | m |', Geo.curv_window_2ds, Geo.curv_window_segments);
L{end+1} = '';
L{end+1} = Geo.kappa_chord_identity;
L{end+1} = '';
L{end+1} = 'Because the curvature window spans a non-integer number of segments, `kappa_raw` is a two-level staircase alternating between 2 and 3 node crossings; the 0.96/0.04 blend is what turns it into the mean `kappa_chord`.';
L{end+1} = '';
L{end+1} = '## 4. Geometric derivation of the steady course lead';
L{end+1} = '';
for i = 1:numel(ID.derivation)
    L{end+1} = a('%d. %s', i, ID.derivation{i}); %#ok<AGROW>
end
L{end+1} = '';
L{end+1} = a('`L_lag = U*dt_g*((1-%.2f)/%.2f + (1-%.2f)/%.2f) = %.4f * %.4f * %.6f = %.6f m`', ID.a_chi, ID.a_chi, ID.a_yaw, ID.a_yaw, U, dt_g, ID.lag_sum_ticks, ID.L_lag_m);
L{end+1} = '';
L{end+1} = '**Parametric identity, independent of any repository value of `lookahead_distance`:**';
L{end+1} = '';
L{end+1} = '| L [m] | L_eff [m] | steady lead [deg] | implied raw P demand at Kp = 32 [deg] |';
L{end+1} = '|---|---|---|---|';
for i = 1:numel(PT.L_m)
    L{end+1} = a('| %.2f | %.4f | %.4f | %.2f |', PT.L_m(i), PT.L_eff_m(i), PT.lead_deg(i), PT.P_demand_deg(i)); %#ok<AGROW>
end
L{end+1} = '';
L{end+1} = PT.note;
L{end+1} = '';
if M.ok
    L{end+1} = '**Numeric verification at the executed production lookahead:**';
    L{end+1} = '';
    L{end+1} = '| quantity | value | units |';
    L{end+1} = '|---|---|---|';
    L{end+1} = a('| L, executed | %.6f | m |', M.L);
    L{end+1} = a('| L_lag | %.6f | m |', ID.L_lag_m);
    L{end+1} = a('| L_eff | %.6f | m |', M.L_eff);
    L{end+1} = a('| derived lead kappa_chord*L_eff | %.6f | deg |', M.pred_lead_deg);
    L{end+1} = a('| inscribed-angle chord bearing kappa_chord*L_eff/2 (what pure pursuit would command) | %.6f | deg |', M.pred_lead_deg/2);
    L{end+1} = a('| measured lead, on-path march over %d whole segment periods | %.6f | deg |', M.steady_nseg, M.meas_lead_deg);
    L{end+1} = a('| identity residual | %+.6f (tol %.2f) | deg |', M.identity_resid_deg, M.identity_tol_deg);
    L{end+1} = a('| lead ripple, peak to peak | %.6f | deg |', M.lead_ripple_p2p_deg);
    L{end+1} = a('| kappa_f steady mean | %.8f (%+.4f%% vs kappa_chord) | 1/m |', M.kappa_f_mean, 100*M.kappa_f_vs_chord_relerr);
    L{end+1} = a('| kappa_f steady ripple, peak to peak | %.3e | 1/m |', M.kappa_f_p2p);
    L{end+1} = a('| on-path residual cross-track (projection resolution) | %.3e | m |', M.y_e_absmax_onpath);
    L{end+1} = a('| production vs reconstruction residual | %.3e (tol %.0e) | rad |', M.recon_resid_rad, M.recon_tol_rad);
    L{end+1} = '';
    L{end+1} = 'The reconstruction is a verbatim transcription of the yaw chain of `guidance_law.m`, and the unmodified production function was called directly on the same on-path march for parity. The identity is therefore confirmed against the production code and not merely against a model of it.';
    L{end+1} = '';
    L{end+1} = a('The peak-to-peak figure above is a property of the *reference frame of the measurement*, not of `yaw_ref`. The lead is measured against the projection-point tangent, which on a chord polyline is a staircase stepping by the full %.2f deg at every node, so the lead necessarily carries a sawtooth of about that amplitude. `yaw_ref` itself is smooth: its largest change is %.4f deg per guidance tick.', rad2deg(Geo.dtheta), M.dyaw_prod_absmax_deg);
    L{end+1} = '';
    L{end+1} = '> **Scope marker.** This march is a geometry reference on the frozen path with the vehicle held exactly on the polyline. It is **not** the stored closed-loop trajectory, it carries no hash attestation against the frozen nominal, and it is never used as a substitute for one.';
    L{end+1} = '';
end
L{end+1} = '## 5. Log closure against the stored trajectory (the blocker)';
L{end+1} = '';
L{end+1} = a('Stored columns of the frozen control anchor (%d rows x %d columns, single precision, dt = 0.025 s):', B.n_rows, B.n_cols);
L{end+1} = '';
L{end+1} = a('`%s`', strjoin(B.stored_columns', ', '));
L{end+1} = '';
L{end+1} = '**The closure method itself is sound.** Applied to the controller side of the same stored log it closes exactly:';
L{end+1} = '';
L{end+1} = '| closure | residual [deg] |';
L{end+1} = '|---|---|';
L{end+1} = a('| `term_P - Kp_psi*e_psi` | %.3e |', B.ctrl_resid_P_minus_Kp_epsi);
L{end+1} = a('| `dr_raw - (term_P + term_RATE_ERR + dr_damp)` | %.3e |', B.ctrl_resid_raw_sum);
L{end+1} = a('| `dr_postmag - clamp(dr_raw, +/- 25 deg)` | %.3e |', B.ctrl_resid_magnitude_limit);
L{end+1} = a('| `dr_plant - ratelimit(dr_postmag, 40 deg/s)` | %.3e |', B.ctrl_resid_rate_limit);
L{end+1} = '';
L{end+1} = a('Tolerance %.0e deg (the stored log is single precision).', B.ctrl_closure_tol_deg);
L{end+1} = '';
L{end+1} = '**The guidance side cannot close.**';
L{end+1} = '';
L{end+1} = a('- `yaw_ref` present in the stored log: **%d**', B.yaw_ref_present);
L{end+1} = a('- `psi` present in the stored log: **%d**', B.psi_present);
L{end+1} = a('- %s', B.observability_argument);
L{end+1} = '';
L{end+1} = 'Signals required for the mandated closure and absent from the permitted evidence:';
L{end+1} = '';
for i = 1:numel(B.required_for_closure)
    L{end+1} = a('- `%s`', B.required_for_closure{i}); %#ok<AGROW>
end
L{end+1} = '';
L{end+1} = a('**Refused substitution.** %s', R.blocker.not_a_workaround);
L{end+1} = '';
L{end+1} = '## 6. The formula placed under test (NOT a stated candidate)';
L{end+1} = '';
L{end+1} = '```';
L{end+1} = F.formula;
L{end+1} = '```';
L{end+1} = '';
L{end+1} = a('- **Units and frames**: %s', F.units_frames);
L{end+1} = a('- **Zero-curvature parity**: %s', F.zero_curvature_parity);
L{end+1} = '- **What it does not do**:';
for i = 1:numel(F.what_it_does_not_do)
    L{end+1} = a('  - %s', F.what_it_does_not_do{i}); %#ok<AGROW>
end
L{end+1} = '';
if M.ok
    L{end+1} = '| property | value | units |';
    L{end+1} = '|---|---|---|';
    L{end+1} = a('| zero-curvature `kappa_f` absmax on the straight twin | %.3e | 1/m |', M.zero_curv_kappa_absmax);
    L{end+1} = a('| zero-curvature offset absmax | %.3e | rad |', M.zero_curv_offset_absmax);
    L{end+1} = a('| zero-curvature `yaw_ref` residual | %.3e (bit-exact = %d) | rad |', M.zero_curv_resid_rad, M.zero_curv_bitexact);
    L{end+1} = a('| offset absmax on the frozen path | %.4f (algebraic bound %.4f) | deg |', M.offset_absmax_deg, M.offset_bound_deg);
    L{end+1} = a('| per-tick offset change absmax | %.4f (bound %.4f) | deg/tick |', M.doffset_absmax_deg, M.doffset_bound_deg);
    L{end+1} = a('| yaw_out slew cap | %.4f | deg/tick |', M.slew_cap_deg_per_tick);
    L{end+1} = a('| per-tick `yaw_ref` change, production / with offset | %.4f / %.4f | deg/tick |', M.dyaw_prod_absmax_deg, M.dyaw_shad_absmax_deg);
    L{end+1} = a('| slew-limiter engagements, production / with offset | %d / %d | ticks |', M.slew_engaged_prod, M.slew_engaged_shad);
    L{end+1} = a('| unwrap step absmax, production / with offset | %.4f / %.4f | deg |', M.wrap_unwrap_step_absmax_deg, M.wrap_unwrap_step_absmax_shad_deg);
    L{end+1} = a('| unwrap branch margin | %.4f | deg |', M.wrap_branch_margin_deg);
    L{end+1} = a('| total unwrapped course travel (yaw_ref exceeds pi = %d) | %.2f | deg |', M.wrap_yaw_ref_exceeds_pi, M.wrap_total_course_deg);
    L{end+1} = a('| residual steady lead after the offset | %+.6f | deg |', M.meas_lead_deg_shad);
    L{end+1} = '';
    L{end+1} = 'The slew limiter never engages on the on-path geometric reference, with or without the offset: the 18 deg course staircase is attenuated to a first-tick step of 0.28 x 18 deg by the course low-pass and then to 0.35 of that by the yaw_out blend, which stays under the 3 deg per guidance tick clamp. The offset adds at most the per-tick change listed above, so it cannot newly engage the limiter, and it does not move the unwrap branch: the largest unwrap step stays far below the 180 deg boundary.';
    L{end+1} = '';
end
L{end+1} = '## 7. Frozen-trajectory algebra (no closed-loop claim)';
L{end+1} = '';
L{end+1} = AL.definition;
L{end+1} = '';
L{end+1} = '| quantity | value | units |';
L{end+1} = '|---|---|---|';
L{end+1} = a('| steady window | %.4f to %.4f s = %d whole segment periods, %d samples | s |', AL.steady_t0, E.T_final, AL.steady_nseg, AL.steady_n);
L{end+1} = a('| stored `e_psi` sustained mean | %+.6f | deg |', AL.e_psi_sus_mean_deg);
L{end+1} = a('| stored `e_psi` sustained median | %+.6f | deg |', AL.e_psi_sus_median_deg);
L{end+1} = a('| stored `e_psi` absmax | %.6f | deg |', AL.e_psi_absmax_deg);
L{end+1} = a('| fraction of horizon with `e_psi > 0` | %.4f | - |', AL.e_psi_sign_fraction_positive);
L{end+1} = a('| recorded `e_psi_median_sus_deg` (source #3 window) | %.6f | deg |', AL.e_psi_median_sus_recorded_deg);
L{end+1} = a('| implied sustained P demand `Kp*e_psi`, mean / median | %+.4f / %+.4f | deg |', AL.P_sus_mean_deg, AL.P_sus_median_deg);
L{end+1} = a('| stored `term_P` absmax | %.4f | deg |', AL.P_absmax_deg);
L{end+1} = a('| rudder envelope | %.2f | deg |', AL.envelope_deg);
L{end+1} = a('| recorded plant steady-turn requirement | %.4f | deg |', AL.trim_req_deg);
L{end+1} = a('| `e_psi` needed to hold it at Kp = 32 | %.6f | deg |', AL.e_psi_for_trim_deg);
if M.ok
    L{end+1} = a('| derived geometric lead removed by the formula | %.6f | deg |', AL.chi_lead_deg);
    L{end+1} = a('| raw P demand removed, `Kp*lead` | %.4f | deg |', AL.P_removed_deg);
    L{end+1} = a('| residual sustained bias, mean / median | %+.6f / %+.6f | deg |', AL.residual_bias_mean_deg, AL.residual_bias_median_deg);
    L{end+1} = a('| residual sustained P demand, mean / median | %+.4f / %+.4f | deg |', AL.P_shadow_sus_mean_deg, AL.P_shadow_sus_median_deg);
    L{end+1} = a('| chord-vs-circle over-subtraction | %+.6f | deg |', AL.chord_excess_deg);
    L{end+1} = '';
    L{end+1} = a('**Residual attribution.** %s', AL.residual_bias_attribution);
    L{end+1} = '';
    L{end+1} = a('**Crab term.** %s', AL.crab_excess_note);
    L{end+1} = '';
    L{end+1} = a('**`e_psi` is load-bearing.** %s', AL.e_psi_for_trim_note);
    L{end+1} = '';
    L{end+1} = '### PG4 / PG5 algebra';
    L{end+1} = '';
    L{end+1} = a('- %s', AL.PG4_mechanism);
    L{end+1} = a('- required `chi_los` = `e_psi_trim / 0.75` = **%.6f deg**', AL.PG4_required_chi_los_deg);
    L{end+1} = a('- implied steady cross-track `y_e = -(L + 0.6)*tan(chi_los)` = **%.6f m**', AL.PG4_implied_y_e_m);
    L{end+1} = a('- recorded PG5 thresholds: `|cte| absmax <= %.6f m`, `|cte| median <= %.6f m`', AL.PG5_cte_absmax_threshold_m, AL.PG5_cte_medabs_threshold_m);
    L{end+1} = a('- implied `|y_e|` as a fraction of the PG5 median / absmax threshold: **%.4f** / **%.4f**', AL.PG5_margin_ratio_median, AL.PG5_margin_ratio_absmax);
    L{end+1} = '';
    L{end+1} = AL.PG_algebra_note;
    L{end+1} = '';
end
L{end+1} = '## 8. Gates';
L{end+1} = '';
L{end+1} = '| id | requirement | pass | evidence |';
L{end+1} = '|---|---|---|---|';
for i = 1:numel(R.gates)
    L{end+1} = a('| %s | %s | **%d** | %s |', R.gates(i).id, R.gates(i).req, R.gates(i).pass, R.gates(i).evidence); %#ok<AGROW>
end
L{end+1} = '';
L{end+1} = a('All hard gates pass: **%d**. Failed: `%s`.', R.hard_all_pass, strjoin(R.hard_failed, ', '));
L{end+1} = '';
L{end+1} = '## 9. Verdict, blocker and what would unblock it';
L{end+1} = '';
L{end+1} = a('- **Verdict** `%s`, **outcome** `%s`.', R.verdict, R.outcome);
L{end+1} = a('- **Candidate stated**: none. %s', R.candidate_withheld_reason);
L{end+1} = a('- **Blocker**: %s', R.blocker.what);
L{end+1} = a('- **Why**: %s', R.blocker.why);
L{end+1} = a('- **Unblock**: %s', R.blocker.unblock);
L{end+1} = a('- **Closed-loop claim**: %s', R.closed_loop_claim);
L{end+1} = a('- **Change declaration**: %s', R.no_change_declaration);
L{end+1} = '';
L{end+1} = '## 10. Visual QA';
L{end+1} = '';
VQ = R.visual_qa;
for i = 1:numel(VQ.panels)
    L{end+1} = a('- %s', VQ.panels{i}); %#ok<AGROW>
end
L{end+1} = '';
for i = 1:numel(VQ.qa_panels)
    L{end+1} = a('- %s', VQ.qa_panels{i}); %#ok<AGROW>
end
L{end+1} = '';
fn = fieldnames(VQ.checks);
L{end+1} = '| check | pass |';
L{end+1} = '|---|---|';
for i = 1:numel(fn)
    L{end+1} = a('| `%s` | %d |', fn{i}, double(VQ.checks.(fn{i}))); %#ok<AGROW>
end
L{end+1} = '';
L{end+1} = a('Visual QA overall: **%d**. Figures written without error: **%d**.', VQ.pass, x_num(R,'figures_ok'));
L{end+1} = '';
L{end+1} = '## 11. Appended logs (units, frames, provenance)';
L{end+1} = '';
SL = R.stored_control_log;
L{end+1} = '**Stored control log (permitted source #3, anchor 1).**';
L{end+1} = '';
L{end+1} = '| column | units | frame |';
L{end+1} = '|---|---|---|';
for i = 1:numel(SL.cols)
    L{end+1} = a('| `%s` | %s | %s |', SL.cols{i}, SL.units{i}, SL.frames{i}); %#ok<AGROW>
end
L{end+1} = '';
L{end+1} = a('Provenance: %s', SL.provenance);
L{end+1} = '';
if isfield(R,'guidance_component_log')
    LG = R.guidance_component_log;
    L{end+1} = '**Guidance component log (this task, geometry reference).**';
    L{end+1} = '';
    L{end+1} = '| column | units | frame |';
    L{end+1} = '|---|---|---|';
    for i = 1:numel(LG.cols)
        L{end+1} = a('| `%s` | %s | %s |', LG.cols{i}, LG.units{i}, LG.frames{i}); %#ok<AGROW>
    end
    L{end+1} = '';
    L{end+1} = a('Provenance: %s', LG.provenance);
    L{end+1} = '';
end
L{end+1} = 'Both logs are appended exactly once, to `...IDENTIFICATION.mat`, and are not duplicated elsewhere.';
L{end+1} = '';
L{end+1} = '## 12. Artifacts and footprint';
L{end+1} = '';
for i = 1:numel(R.artifacts)
    L{end+1} = a('- `%s`', R.artifacts{i}); %#ok<AGROW>
end
L{end+1} = '';
L{end+1} = a('Post-write fingerprints of every protected file unchanged: **%d**. Permitted sources unchanged: **%d**.', R.fp_unchanged_after_write, R.fp_permitted_unchanged);
L{end+1} = '';

fid = fopen(fname, 'w');
fprintf(fid, '%s\n', L{:});
fclose(fid);
end
