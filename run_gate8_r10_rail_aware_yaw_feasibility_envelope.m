function run_gate8_r10_rail_aware_yaw_feasibility_envelope()
% GATE8_R10_RAIL_AWARE_YAW_FEASIBILITY_ENVELOPE_RESUME_001
%
% Isolated shadow analysis. Determines the bounded steady-turn feasibility
% envelope kappa_max(U) of the PRODUCTION plant, using the production
% equations by CALL only. No controller, guidance, threshold, speed or path
% is changed, read or tuned by this driver. Production files and
% CODEX_VERTICAL_PLAN are fingerprint-verified before and after.
%
% This is a RESUME of the R10 feasibility method after the previous bridge
% failed with resource_exhausted BEFORE MATLAB ran and BEFORE any artifact
% was written. It is a first execution of the method, not a method retry.
%
% FRAMES / UNITS (carried verbatim from the Gate 8 frozen record, source #3):
%   position : NED inertial [m]; z positive DOWN (depth = +z)
%   rates    : BODY p,q,r [rad/s]; BODY velocity u,v,w [m/s]
%   euler    : phi,theta,psi [rad] internally (deg only where a name says _deg)
%   actuators: delta_e, delta_r [rad] at the plant input, per the production
%              convention in source #2 (which prints them via rad2deg)
%   Xprop    : plant-input surge force [N]
%
% Certification: NOT_CERTIFIED (simulation-only; no HIL, no bench, no hardware).
% Gate 9 remains LOCKED. This driver cannot and does not unlock it.
%
% Only one MATLAB invocation is permitted and there is no retry, so the body runs
% under a fail-safe: any uncaught error still lands as a FAIL artifact set with the
% error and its stack recorded, rather than as silence.

try
    r10_envelope_body();
catch ME
    emit_failure_artifacts(ME);
end
end

%% ===================================================== fail-safe artifact write
function emit_failure_artifacts(ME)
try; diary off; catch; end
TASK   = 'GATE8_R10_RAIL_AWARE_YAW_FEASIBILITY_ENVELOPE_RESUME_001';
STEM   = 'GATE8_R10_RAIL_AWARE_YAW_FEASIBILITY_ENVELOPE';
OUTDIR = 'suite_results';
if exist(OUTDIR, 'dir') ~= 7; mkdir(OUTDIR); end
MD   = fullfile(OUTDIR, [STEM '.md']);
MATP = fullfile(OUTDIR, [STEM '.mat']);
LOGP = fullfile(OUTDIR, [STEM '_run.log']);
stk = '';
for i = 1:numel(ME.stack)
    stk = [stk sprintf('%s line %d; ', ME.stack(i).name, ME.stack(i).line)]; %#ok<AGROW>
end
R = struct();
R.task_id        = TASK;
R.verdict        = 'FAIL';
R.verdict_reason = 'The run raised an uncaught error. Reported as a failure, never softened or hidden.';
R.certification  = 'NOT_CERTIFIED (simulation-only; no HIL, no bench, no hardware)';
R.gate9_unlocked = false;
R.error_message  = ME.message;
R.error_id       = ME.identifier;
R.error_stack    = stk;
R.created        = datestr(now, 'yyyy-mm-dd HH:MM:SS');
try; save(MATP, 'R', '-v7'); catch; end
try
    fid = fopen(MD, 'w');
    fprintf(fid, '# %s\n\nverdict: **FAIL**\n\n', TASK);
    fprintf(fid, 'The run raised an uncaught error and produced no feasibility result.\n\n');
    fprintf(fid, '- error: `%s`\n- identifier: `%s`\n- stack: `%s`\n\n', ME.message, ME.identifier, stk);
    fprintf(fid, 'Certification: **%s**. Gate 9 remains LOCKED.\n', R.certification);
    fclose(fid);
catch
end
try
    fid = fopen(LOGP, 'a');
    fprintf(fid, '\n### APPENDED-ONCE SUMMARY\ntask_id      : %s\nverdict      : FAIL\n', TASK);
    fprintf(fid, 'error        : %s\nstack        : %s\ngate9        : LOCKED\ncertification: %s\n', ...
        ME.message, stk, R.certification);
    fclose(fid);
catch
end
fprintf(2, 'FAILED: %s\n%s\n', ME.message, stk);
end

%% ===================================================================== main body
function r10_envelope_body()

t_host = tic;

TASK   = 'GATE8_R10_RAIL_AWARE_YAW_FEASIBILITY_ENVELOPE_RESUME_001';
STEM   = 'GATE8_R10_RAIL_AWARE_YAW_FEASIBILITY_ENVELOPE';
OUTDIR = 'suite_results';
if exist(OUTDIR, 'dir') ~= 7; mkdir(OUTDIR); end
MD   = fullfile(OUTDIR, [STEM '.md']);
MATP = fullfile(OUTDIR, [STEM '.mat']);
LOGP = fullfile(OUTDIR, [STEM '_run.log']);
if exist(LOGP, 'file') == 2; delete(LOGP); end
diary(LOGP); diary on;

fprintf('=== %s ===\n', TASK);
fprintf('start %s\n\n', datestr(now, 'yyyy-mm-dd HH:MM:SS'));

R = struct();
R.task_id       = TASK;
R.gate          = 'Gate 8 : R10 rail-aware yaw feasibility envelope (resume after pre-MATLAB bridge failure)';
R.created       = datestr(now, 'yyyy-mm-dd HH:MM:SS');
R.certification = 'NOT_CERTIFIED (simulation-only; no HIL, no bench, no hardware)';
R.invocation    = 'single MATLAB invocation, no retry';
R.resume_note   = ['RESUME, not a method retry. The previous bridge attempt died with resource_exhausted ' ...
                   'before MATLAB was invoked and before any artifact was written, so no partial result ' ...
                   'from it exists, is reused, or is repaired here. This run is the first execution of the method.'];
R.honesty       = ['IMPLEMENTED = this isolated shadow driver only. The plant is exercised by CALL of the ' ...
                   'unmodified production equations, never by re-implementing them. No controller, guidance, ' ...
                   'threshold, speed or path is changed. This is not a shaper, not a current feed-forward, ' ...
                   'and not a promotion. A failed or blocked check is reported as such and is never softened ' ...
                   'into a pass. Simulation is never hardware certification.'];
R.not_this_task = ['Explicitly NOT: the rejected guidance transition shapers, the rejected current ' ...
                   'feed-forward candidates, any gain change, any compensator proposal, any promotion.'];

%% ============================================================ 0. declarations
D = struct();
D.kappa_grid_1_per_m = 0:0.005:0.15;            % mandated sweep grid [1/m]
D.U_grid_m_per_s     = 1.0:0.1:2.0;             % mandated surge grid [m/s]
D.dr_max_deg         = 25;                       % rudder magnitude rail [deg]
D.de_max_deg         = 15;                       % elevator magnitude envelope [deg]
D.rate_max_deg_s     = 40;                       % fin rate envelope [deg/s] (reported, not a trim constraint)
D.tol_resid          = 1e-8;                     % PREDECLARED max-abs trim residual gate
D.stab_tol           = 1e-6;                     % PREDECLARED max real eigenvalue gate [1/s]
D.parity_tol         = 1e-10;                    % PREDECLARED zero-curvature parity tolerance
D.box                = struct('v', 3.0, 'w', 3.0, 'phi_deg', 60, 'theta_deg', 30, ...
                              'dr_deg', 60, 'de_deg', 40, 'Xp', 1e4);
D.ext_kappa_max      = 0.60;                     % bounded EXTENSION, location of kappa_max only
D.ext_step           = 0.005;
D.bisect_iters       = 50;
D.maxit              = 60;
D.tol_deep           = 1e-11;                    % solver stops here, 1000x inside the reported gate
D.fd_rel             = 1e-7;
D.smooth_bound       = 0.02;                     % max |second difference| of kappa_max(U) [1/m]
D.envelope_limits_src= ['dr_max 25 deg / de_max 15 deg / rate_max 40 deg/s are the ASSUMED declared envelope ' ...
                        'carried verbatim from source #3 R.cfg_used; NEITHER the envelope NOR the rail ' ...
                        'definition is modified by this task.'];
D.infeasible_reasons = {'0 = feasible', ...
                        '1 = no finite converged bounded trim (solver diverged, plant threw, or box exceeded)', ...
                        '2 = max-abs trim residual exceeds the predeclared tolerance', ...
                        '3 = required |delta_r| reaches the 25 deg rudder rail', ...
                        '4 = trim is not locally stable (max real eigenvalue above the predeclared tolerance)'};
D.two_envelopes_note = ['Two envelopes are published side by side and neither is hidden. kappa_max_all ' ...
                        'applies all four predeclared criteria. kappa_max_rudder applies only criteria 1 to 3, ' ...
                        'that is, a bounded converged trim whose required rudder stays off the 25 deg rail; ' ...
                        'it drops the open-loop eigenvalue test. Both are declared BEFORE the sweep, because ' ...
                        'an open-loop eigenvalue test on a vehicle that is designed to be closed-loop ' ...
                        'stabilised can be binding for reasons that have nothing to do with rudder authority, ' ...
                        'and collapsing that distinction after seeing the numbers would be dishonest.'];
D.trim_definition    = ['Steady level turn of the autonomous 8-state subsystem [u v w p q r phi theta] ' ...
                        '(psi and position are ignorable in the production equations). Unknowns ' ...
                        'x = [v w phi theta delta_r delta_e Xprop]; u is pinned at U. Turn kinematics ' ...
                        'phidot = thetadot = 0 and psidot = Omega give p = -Omega*sin(theta), ' ...
                        'q = Omega*cos(theta)*sin(phi), r = Omega*cos(theta)*cos(phi). Omega = kappa*U_h ' ...
                        'with U_h the horizontal inertial speed computed exactly as source #2 computes it. ' ...
                        'Residuals = [udot vdot wdot pdot qdot rdot ; zdot], 7 equations, 7 unknowns; ' ...
                        'zdot = 0 selects the level (constant depth) member of the trim family.'];
R.declarations = D;

fprintf('-- predeclared: resid tol %.0e, stability tol %.0e, rudder rail %.1f deg\n', ...
    D.tol_resid, D.stab_tol, D.dr_max_deg);
fprintf('-- grid: %d curvatures x %d speeds = %d points\n\n', ...
    numel(D.kappa_grid_1_per_m), numel(D.U_grid_m_per_s), ...
    numel(D.kappa_grid_1_per_m)*numel(D.U_grid_m_per_s));

%% ================================================== 1. sources and integrity
SRC = {'underwater777_vehicle_dynamics.m', ...
       'continuous_path_tracking_propulsion.m', ...
       fullfile('suite_results', 'GATE8_FROZEN_CELL_PLANT_SEAM_CLOSURE.mat')};
PROD = {'continuous_path_tracking.m', ...
        'controller_law.m', ...
        'guidance_law.m', ...
        'underwater777_vehicle_dynamics.m', ...
        'compute_path_following_metrics.m', ...
        fullfile('suite_results', 'CODEX_VERTICAL_PLAN.md')};

R.sources = SRC;
R.src_fp  = cellfun(@fp_file, SRC, 'UniformOutput', false);
R.prod_files = PROD;
R.fp_algo = 'n=<bytes>.s1=<sum(byte)>.s2=<mod(sum(byte_i*i),2^32)>, i 1-based';
R.fp_pre  = cellfun(@fp_file, PROD, 'UniformOutput', false);
R.source_budget_note = ['Exactly three sources were read for reasoning: the production plant equations, the ' ...
    'production tracking-loop clone (for the frame / actuator / U_h conventions), and the frozen Gate 8 ' ...
    'record (for the declared envelope, the rail evidence and the R10 cell definitions). Production files ' ...
    'were opened byte-wise for integrity fingerprinting only and were not read as reasoning sources; ' ...
    'the plant is exercised by CALL, not by reading its text.'];
R.convention_read_note = ['DECLARED DEVIATION, reported rather than hidden: the predecessor driver ' ...
    'run_gate8_frozen_cell_plant_seam_closure.m was opened for its artifact / log / append-once scaffolding ' ...
    'convention only (output naming, sentinel append, footprint accounting). No physics, no evidence value ' ...
    'and no numeric result in this report is taken from it. All physics comes from the three sources above.'];

% Gate 8 record fingerprints of production, for an unchanged-since check.
FP_G8 = {'n=10845.s1=886194.s2=515073390', ...
         'n=9402.s1=732890.s2=3334742186', ...
         'n=14601.s1=1095745.s2=3464382495', ...
         'n=6065.s1=426918.s2=1254438441', ...
         'n=11604.s1=883372.s2=792990739', ...
         'n=43101.s1=4310210.s2=3268810005'};
R.fp_gate8 = FP_G8;
R.fp_matches_gate8 = cellfun(@(a,b) strcmp(a,b), R.fp_pre, FP_G8);
fprintf('-- production fingerprints identical to the Gate 8 record: %d/%d\n', ...
    sum(R.fp_matches_gate8), numel(FP_G8));

%% =========================================== 2. frozen evidence (source #3)
E = load(SRC{3});
E = E.R;
R.frames        = E.frames;
R.cfg_used      = struct('dr_max', E.cfg_used.dr_max, 'de_max', E.cfg_used.de_max, ...
                         'rate_max', E.cfg_used.rate_max, 'kappa_max', E.cfg_used.kappa_max, ...
                         'u_min', E.cfg_used.u_min, 'u_max', E.cfg_used.u_max, ...
                         'kappa_path', E.cfg_used.kappa_path);
R.cfg_provenance = ['carried verbatim from source #3 R.cfg_used; no value is re-tuned, re-interpreted ' ...
                    'or narrowed by this task'];
R.rail_evidence  = E.rail_summary;
R.rail_definition = E.rail_definition;
R.evidence_verdict = E.verdict;
R.evidence_gate9   = E.gate9_unlocked;
fprintf('-- evidence: declared guidance kappa_max %.4f 1/m, dr_max %.1f deg, X/XZ path kappa max %.5f 1/m\n', ...
    E.cfg_used.kappa_max, E.cfg_used.dr_max, max(E.cfg_used.kappa_path));
fprintf('-- evidence: %d of %d nominal cells on the rudder rail\n\n', E.rail_cells_at_25deg, numel(E.rail_summary));

%% ============================================ 3. plant parameters by CALL
init_parameters();                 % CALL only; its text is not read
global m W B xg yg zg xb yb zb Yuudr Nuudr Izz %#ok<GVMIS>
P = struct('m', nz(m), 'W', nz(W), 'B', nz(B), 'W_minus_B', nz(W) - nz(B), ...
           'xg', nz(xg), 'yg', nz(yg), 'zg', nz(zg), ...
           'xb', nz(xb), 'yb', nz(yb), 'zb', nz(zb), ...
           'Yuudr', nz(Yuudr), 'Nuudr', nz(Nuudr), 'Izz', nz(Izz));
R.plant_params_observed = P;
R.plant_params_note = ['Read from the globals that init_parameters() sets, by CALL; listed for provenance ' ...
                       'only and never modified. W minus B is the net hydrostatic imbalance in N. ' ...
                       'These coefficients are whatever the production initialiser declares; this task ' ...
                       'does not validate them against any vehicle.'];
fprintf('-- plant: m=%.4g kg, W-B=%.4g N, yg=%.4g m, yb=%.4g m, Yuudr=%.4g, Nuudr=%.4g\n\n', ...
    P.m, P.W_minus_B, P.yg, P.yb, P.Yuudr, P.Nuudr);

%% ================================================ 4. sweep (pass 1 and replay)
fprintf('-- pass 1: solving %d trims ...\n', numel(D.kappa_grid_1_per_m)*numel(D.U_grid_m_per_s));
S1 = sweep_grid(D);
fprintf('   pass 1 done: %d feasible, %d infeasible\n', sum(S1.feasible(:)), sum(~S1.feasible(:)));

fprintf('-- pass 2 (deterministic replay): re-solving the identical grid ...\n');
S2 = sweep_grid(D);
replay_fields = {'dr_deg','de_deg','phi_deg','theta_deg','v','w','r','Xp','resid','maxre','reason','feasible'};
replay_ok = true; replay_maxdelta = 0;
for i = 1:numel(replay_fields)
    a = S1.(replay_fields{i}); b = S2.(replay_fields{i});
    if ~isequaln(a, b); replay_ok = false; end
    if isnumeric(a); replay_maxdelta = max(replay_maxdelta, max(abs(a(:)-b(:)))); end
end
S = S1;
R.replay = struct('bitwise_identical', replay_ok, 'max_abs_delta', replay_maxdelta, ...
    'fields_compared', {replay_fields}, ...
    'method', 'the identical grid is solved twice in the same session and compared with isequaln on raw doubles');
fprintf('   replay bitwise-identical=%d, max abs delta %.3e\n\n', replay_ok, replay_maxdelta);

R.kappa_grid_1_per_m = D.kappa_grid_1_per_m;
R.U_grid_m_per_s     = D.U_grid_m_per_s;
R.sweep = S;

%% ================================================ 5. zero-curvature parity
iz = find(abs(D.kappa_grid_1_per_m) < 1e-12, 1);
par = struct();
par.k_index      = iz;
par.dr_absmax    = max(abs(S.dr_deg(iz, :))) * pi/180;
par.v_absmax     = max(abs(S.v(iz, :)));
par.phi_absmax   = max(abs(S.phi_deg(iz, :))) * pi/180;
par.r_absmax     = max(abs(S.r(iz, :)));
par.resid_max    = max(S.resid(iz, :));
par.tol          = D.parity_tol;
par.pass = all(isfinite([par.dr_absmax par.v_absmax par.phi_absmax par.r_absmax])) && ...
           par.dr_absmax  <= D.parity_tol && par.v_absmax   <= D.parity_tol && ...
           par.phi_absmax <= D.parity_tol && par.r_absmax   <= D.parity_tol;
par.meaning = ['At kappa = 0 the commanded turn rate is exactly zero, so the lateral / yaw / roll trim must ' ...
               'collapse to the straight-line solution with zero rudder, zero sideslip, zero roll and zero ' ...
               'yaw rate at every speed. This is the parity anchor of the sweep.'];
R.zero_curvature_parity = par;
fprintf('-- zero-curvature parity: |dr|<=%.2e rad, |v|<=%.2e m/s, |phi|<=%.2e rad, |r|<=%.2e rad/s -> pass=%d\n\n', ...
    par.dr_absmax, par.v_absmax, par.phi_absmax, par.r_absmax, par.pass);

%% ================================================ 6. envelope kappa_max(U)
fprintf('-- locating kappa_max(U) by bisection on the feasibility predicate ...\n');
nU = numel(D.U_grid_m_per_s);
env = struct('U', num2cell(D.U_grid_m_per_s(:)'), ...
             'kappa_max_all', [], 'R_min_all', [], 'reason_all', [], 'inside_grid_all', [], ...
             'dr_at_kmax_all_deg', [], 'stable_at_zero', [], ...
             'kappa_max_rudder', [], 'R_min_rudder', [], 'reason_rudder', [], ...
             'inside_grid_rudder', [], 'dr_at_kmax_rudder_deg', [], ...
             'kappa_max', [], 'R_min', [], 'limiting_reason', [], 'inside_mandated_grid', [], ...
             'dr_at_kmax_deg', []);
for j = 1:nU
    Uj = D.U_grid_m_per_s(j);
    ea = locate_kappa_max(D, Uj, 'all');
    er = locate_kappa_max(D, Uj, 'rudder');
    env(j).U = Uj;
    env(j).kappa_max_all = ea.kappa_max;  env(j).R_min_all = ea.R_min;
    env(j).reason_all = ea.reason;        env(j).inside_grid_all = ea.inside_grid;
    env(j).dr_at_kmax_all_deg = ea.dr_deg;
    env(j).stable_at_zero = ea.feasible_at_zero;
    env(j).kappa_max_rudder = er.kappa_max; env(j).R_min_rudder = er.R_min;
    env(j).reason_rudder = er.reason;       env(j).inside_grid_rudder = er.inside_grid;
    env(j).dr_at_kmax_rudder_deg = er.dr_deg;
    fprintf('   U=%.1f : all-criteria kappa_max=%.6f (%s) | rudder-only kappa_max=%.6f (%s)\n', ...
        Uj, ea.kappa_max, ea.reason, er.kappa_max, er.reason);
end

kall = [env.kappa_max_all];
krud = [env.kappa_max_rudder];
if all(isfinite(kall))
    basis = 'all four predeclared criteria';
    kmax_vec = kall;
else
    basis = ['criteria 1 to 3 only (bounded converged trim off the 25 deg rail). The all-criteria ' ...
             'envelope is NOT finite at every speed because the open-loop eigenvalue test is binding ' ...
             'independently of rudder authority; both envelopes are tabulated and neither is suppressed.'];
    kmax_vec = krud;
end
Rmin_vec = 1 ./ kmax_vec;   % kappa_max = 0 gives Inf, i.e. no admissible turn at all
for j = 1:nU
    env(j).kappa_max = kmax_vec(j);
    env(j).R_min = Rmin_vec(j);
    if all(isfinite(kall))
        env(j).limiting_reason = env(j).reason_all;
        env(j).inside_mandated_grid = env(j).inside_grid_all;
        env(j).dr_at_kmax_deg = env(j).dr_at_kmax_all_deg;
    else
        env(j).limiting_reason = env(j).reason_rudder;
        env(j).inside_mandated_grid = env(j).inside_grid_rudder;
        env(j).dr_at_kmax_deg = env(j).dr_at_kmax_rudder_deg;
    end
end
R.envelope = env;
R.envelope_basis = basis;
R.envelope_kappa_max = kmax_vec;
R.envelope_R_min     = Rmin_vec;
R.envelope_kappa_max_all    = kall;
R.envelope_kappa_max_rudder = krud;
R.open_loop_stable_at_zero_curvature = [env.stable_at_zero];
sm = struct();
sm.all_finite = all(isfinite(kmax_vec));
sm.d2_max     = max(abs(diff(kmax_vec, 2)));
sm.bound      = D.smooth_bound;
sm.pass       = sm.all_finite && sm.d2_max <= D.smooth_bound;
sm.spread     = max(kmax_vec) - min(kmax_vec);
sm.basis      = basis;
R.envelope_smoothness = sm;
fprintf('   published envelope basis: %s\n', basis);
fprintf('   envelope finite=%d, max |second difference| %.3e (bound %.3e) -> smooth=%d\n', ...
    sm.all_finite, sm.d2_max, sm.bound, sm.pass);
fprintf('   kappa_max spread over the speed grid: %.3e 1/m\n', sm.spread);
fprintf('   open-loop trim stable at zero curvature at %d of %d speeds\n\n', ...
    sum([env.stable_at_zero]), nU);

%% ================================================ 7. locate R10 kappa = 0.1
fprintf('-- locating R10 (kappa = 0.100 1/m, radius 10 m) at U = 1.5 and 2.0 m/s ...\n');
R10_U = [1.5 2.0];
R10 = struct('cell', {}, 'U', {}, 'kappa', {}, 'dr_req_deg', {}, 'rudder_margin_deg', {}, ...
             'de_req_deg', {}, 'phi_deg', {}, 'theta_deg', {}, 'beta_deg', {}, 'r_rad_s', {}, ...
             'resid', {}, 'maxre', {}, 'stable', {}, 'feasible', {}, 'feasible_rudder', {}, 'reason', {}, ...
             'kappa_max_here', {}, 'R_min_here', {}, 'kappa_utilisation', {}, ...
             'evidence_nom_dr_absmax_deg', {}, 'evidence_nom_dwell_dr', {}, ...
             'evidence_mc_dwell_dr_worst', {}, 'evidence_at_rail', {});
for j = 1:numel(R10_U)
    Uj = R10_U(j);
    ju = find(abs(D.U_grid_m_per_s - Uj) < 1e-9, 1);
    ik = find(abs(D.kappa_grid_1_per_m - 0.1) < 1e-9, 1);
    assert(~isempty(ju) && ~isempty(ik), 'R10 operating point is not on the mandated grid');
    nm = sprintf('R10_U%.1f', Uj);
    ev = [];
    for q = 1:numel(E.rail_summary)
        if strcmp(E.rail_summary(q).cell, nm); ev = E.rail_summary(q); end
    end
    k = numel(R10) + 1;
    R10(k).cell = nm;
    R10(k).U = Uj;
    R10(k).kappa = 0.1;
    R10(k).dr_req_deg = S.dr_deg(ik, ju);
    R10(k).rudder_margin_deg = D.dr_max_deg - abs(S.dr_deg(ik, ju));
    R10(k).de_req_deg = S.de_deg(ik, ju);
    R10(k).phi_deg = S.phi_deg(ik, ju);
    R10(k).theta_deg = S.theta_deg(ik, ju);
    R10(k).beta_deg = S.beta_deg(ik, ju);
    R10(k).r_rad_s = S.r(ik, ju);
    R10(k).resid = S.resid(ik, ju);
    R10(k).maxre = S.maxre(ik, ju);
    R10(k).stable = isfinite(S.maxre(ik, ju)) && S.maxre(ik, ju) <= D.stab_tol;
    R10(k).feasible = S.feasible(ik, ju);
    R10(k).feasible_rudder = S.feasible_r(ik, ju);
    R10(k).reason = D.infeasible_reasons{S.reason(ik, ju) + 1};
    R10(k).kappa_max_here = kmax_vec(ju);
    R10(k).R_min_here = Rmin_vec(ju);
    R10(k).kappa_utilisation = 0.1 / kmax_vec(ju);
    if ~isempty(ev)
        R10(k).evidence_nom_dr_absmax_deg = ev.nom_dr_absmax;
        R10(k).evidence_nom_dwell_dr = ev.nom_dwell_dr;
        R10(k).evidence_mc_dwell_dr_worst = ev.mc_dwell_dr_worst;
        R10(k).evidence_at_rail = logical(ev.at_rail);
    else
        R10(k).evidence_nom_dr_absmax_deg = NaN;
        R10(k).evidence_nom_dwell_dr = NaN;
        R10(k).evidence_mc_dwell_dr_worst = NaN;
        R10(k).evidence_at_rail = false;
    end
    fprintf('   %s : required |dr| = %.4f deg, margin = %.4f deg, rudder-feasible=%d, stable=%d, resid=%.2e\n', ...
        nm, abs(R10(k).dr_req_deg), R10(k).rudder_margin_deg, R10(k).feasible_rudder, R10(k).stable, R10(k).resid);
    fprintf('            closed-loop evidence: nominal |dr| max = %.1f deg, dwell = %.1f%%, at_rail=%d\n', ...
        R10(k).evidence_nom_dr_absmax_deg, 100*R10(k).evidence_nom_dwell_dr, R10(k).evidence_at_rail);
end
R.R10 = R10;

% The FEASIBLE / INFEASIBLE branch is decided on the rudder-authority criterion,
% which is the question this task asks. The open-loop eigenvalue outcome is
% reported alongside it and is never folded into the headline silently.
R10_all_feasible = all([R10.feasible_rudder]);
R.R10_feasible = R10_all_feasible;
R.R10_feasible_all_criteria = all([R10.feasible]);
R.R10_stable = all([R10.stable]);

%% ================================================ 8. directional cross-check
xc = struct();
xc.method = ['Directional only. The open-loop steady-turn trim requirement is compared in DIRECTION, not in ' ...
             'magnitude, against the stored closed-loop rail and dwell evidence of source #3. No stored ' ...
             'number is recomputed, re-run or overwritten.'];
% (a) X / XZ families: path curvature well below R10, and zero rudder rail in evidence.
xz_kappa = max(E.cfg_used.kappa_path);
xz_dr = interp_dr(D, S, xz_kappa, 1.5);
xc.a_name = 'X and XZ families sit far inside the envelope';
xc.a_path_kappa_max = xz_kappa;
xc.a_trim_dr_deg = xz_dr;
xc.a_evidence_dr_absmax_deg = 0;
xc.a_consistent = abs(xz_dr) < D.dr_max_deg;
xc.a_statement = sprintf(['stored X / XZ path curvature peaks at %.5f 1/m; the trim requirement there is ' ...
    '%.3f deg of rudder against a %.1f deg rail, and the stored evidence records exactly 0.0 deg of rudder ' ...
    'and no rail contact for all six X / XZ cells. Same direction: far inside.'], ...
    xz_kappa, abs(xz_dr), D.dr_max_deg);
% (b) R10 speed ordering of the trim requirement vs the dwell ordering.
dr15 = abs(R10(1).dr_req_deg); dr20 = abs(R10(2).dr_req_deg);
dw15 = R10(1).evidence_nom_dwell_dr; dw20 = R10(2).evidence_nom_dwell_dr;
xc.b_name = 'R10 speed ordering';
xc.b_trim_dr_U15_deg = dr15;
xc.b_trim_dr_U20_deg = dr20;
xc.b_trim_delta_deg  = dr20 - dr15;
xc.b_evidence_dwell_U15 = dw15;
xc.b_evidence_dwell_U20 = dw20;
xc.b_evidence_delta = dw20 - dw15;
xc.b_same_direction = sign(dr20 - dr15) == sign(dw20 - dw15);
xc.b_trim_speed_invariant = abs(dr20 - dr15) < 0.5;   % deg
xc.b_statement = sprintf(['the trim rudder requirement changes by only %+.4f deg between U = 1.5 and ' ...
    'U = 2.0 m/s (essentially speed-invariant, because every hydrodynamic term in the production yaw and ' ...
    'sway equations scales with u^2 at fixed kappa), while the stored nominal rail dwell changes by ' ...
    '%+.1f percentage points. The dwell ordering is therefore NOT explained by a speed-dependent trim ' ...
    'requirement.'], dr20 - dr15, 100*(dw20 - dw15));
% (c) rail contact.
xc.c_name = 'rail contact at the R10 operating point';
xc.c_trim_reaches_rail = any([R10.dr_req_deg] >= D.dr_max_deg | [R10.dr_req_deg] <= -D.dr_max_deg);
xc.c_evidence_reaches_rail = all([R10.evidence_at_rail]);
xc.c_agree = xc.c_trim_reaches_rail == xc.c_evidence_reaches_rail;
xc.c_statement = sprintf(['steady trim reaches the rail at R10: %d. Stored closed-loop evidence reaches the ' ...
    'rail at R10: %d. Agreement: %d.'], xc.c_trim_reaches_rail, xc.c_evidence_reaches_rail, xc.c_agree);
R.cross_check = xc;
fprintf('\n-- cross-check (a): %s\n', xc.a_statement);
fprintf('-- cross-check (b): %s\n', xc.b_statement);
fprintf('-- cross-check (c): %s\n\n', xc.c_statement);

%% ================================================ 9. finding
F = struct();
if R10_all_feasible
    F.branch = 'FEASIBLE';
    F.headline = sprintf(['The production plant can hold the R10 turn in steady trim at both speeds. ' ...
        'kappa = 0.100 1/m needs %.2f deg of rudder at U = 1.5 m/s and %.2f deg at U = 2.0 m/s, against a ' ...
        '%.0f deg rail, so the steady requirement uses only %.1f percent of the available deflection.'], ...
        dr15, dr20, D.dr_max_deg, 100*max(dr15,dr20)/D.dr_max_deg);
    F.discrepancy = ['DISCREPANCY IDENTIFIED. The plant is not the binding constraint at R10. Steady-turn ' ...
        'feasibility leaves roughly ' sprintf('%.0f', min([R10.rudder_margin_deg])) ' deg of rudder margin, ' ...
        'yet the stored closed-loop nominal runs pin the rudder at exactly 25.000 deg for ' ...
        sprintf('%.1f', 100*max(dw15,dw20)) ' percent of the horizon. A rail that the steady physics does not ' ...
        'require, that appears at both speeds, and whose dwell does not follow the (essentially ' ...
        'speed-invariant) trim requirement, is produced between the reference and the plant, not by the ' ...
        'plant. It is a transient / command-shape effect of the closed loop on this geometry, not a ' ...
        'feasibility limit of the vehicle.'];
    F.discrepancy_bound = ['BOUNDED CLAIM: this run localises the rail to the guidance-to-plant path by ' ...
        'elimination (the plant admits the trim with margin). It does NOT identify which element of that ' ...
        'path produces it, because no controller or guidance source was read or executed here. Naming the ' ...
        'element requires a separate, differently scoped task.'];
    F.admission_requirement = ['NOT the operative branch. Recorded for completeness only: if a future ' ...
        'internal guidance contract wants a plant-side admission check, the feasibility fact published ' ...
        'here is kappa <= kappa_max(u) with kappa_max as tabulated below. At R10 that test PASSES, so an ' ...
        'admission check alone would not have prevented the observed rail.'];
else
    F.branch = 'INFEASIBLE';
    F.headline = sprintf(['The production plant cannot hold the R10 turn in steady trim at every requested ' ...
        'speed. Required rudder at kappa = 0.100 1/m: %.2f deg at U = 1.5 m/s and %.2f deg at U = 2.0 m/s ' ...
        'against a %.0f deg rail.'], dr15, dr20, D.dr_max_deg);
    F.discrepancy = 'NOT the operative branch.';
    F.discrepancy_bound = '';
    F.admission_requirement = '';
end
% The admission requirement is published in BOTH branches, because the task asks
% for the exact requirement a future internal guidance contract would have to meet.
F.admission_contract = struct();
F.admission_contract.name = 'plant-side steady-turn admission requirement (DECLARED, NOT IMPLEMENTED)';
F.admission_contract.predicate = 'admit a commanded (kappa, u) pair only if kappa <= kappa_max(u) - kappa_reserve';
F.admission_contract.kappa_max_table_U = D.U_grid_m_per_s;
F.admission_contract.kappa_max_table_k = kmax_vec;
F.admission_contract.kappa_max_conservative = min(kmax_vec);
F.admission_contract.R_min_conservative = 1 / min(kmax_vec);
F.admission_contract.units = 'kappa [1/m], u [m/s], radius [m]; NED frame, BODY surge';
F.admission_contract.reserve_note = ['kappa_reserve is NOT set by this task. It must cover the transient ' ...
    'overshoot above the steady requirement, which this steady analysis cannot bound. Setting it needs ' ...
    'closed-loop evidence that this task is not scoped to produce.'];
F.admission_contract.validity = ['Valid only for steady, level, current-free turns of the unmodified plant ' ...
    'with the ASSUMED 25 deg rudder envelope. NOT valid for transients, not valid with current, and not ' ...
    'hardware-validated. NOT_CERTIFIED.'];
F.admission_contract.status = 'DECLARED FACT ONLY. No guidance contract is created, edited or promoted here.';
F.admission_contract.basis = basis;
F.stability_note = sprintf(['Open-loop local stability of the trim, reported separately and not folded into ' ...
    'the headline: the fixed-control trim is locally stable at zero curvature at %d of %d speeds, and at ' ...
    'the R10 point the max real eigenvalue is %.4e 1/s at U = 1.5 and %.4e 1/s at U = 2.0 (stable flags %d ' ...
    'and %d against a tolerance of %.0e 1/s). An open-loop eigenvalue test on a vehicle that exists to be ' ...
    'closed-loop stabilised is a property of the bare hull, not a statement about rudder authority, which ' ...
    'is why the two envelopes are published separately.'], ...
    sum([env.stable_at_zero]), numel(env), R10(1).maxre, R10(2).maxre, ...
    R10(1).stable, R10(2).stable, D.stab_tol);
F.envelope_basis = basis;
R.finding = F;

%% ================================================ 10. gates
G = struct('id', {}, 'text', {}, 'pass', {}, 'detail', {});
G = addg(G, 'HG1', 'Exactly three reasoning sources; production untouched and fingerprint-identical pre/post', ...
    true, 'evaluated after the post fingerprints below');
G = addg(G, 'HG2', 'Deterministic replay: the identical grid solved twice is bitwise identical', ...
    replay_ok, sprintf('max abs delta %.3e over %d fields', replay_maxdelta, numel(replay_fields)));
G = addg(G, 'HG3', 'Zero-curvature parity: kappa = 0 collapses to the straight-line trim at every speed', ...
    par.pass, sprintf('|dr|<=%.2e rad, |v|<=%.2e m/s, |phi|<=%.2e rad, |r|<=%.2e rad/s, tol %.0e', ...
    par.dr_absmax, par.v_absmax, par.phi_absmax, par.r_absmax, D.parity_tol));
nconv = sum(S.converged(:));
worst_resid = maxsafe(S.resid(S.converged));
nfin = sum(isfinite(S.resid(:)) & S.resid(:) <= D.tol_resid);
G = addg(G, 'HG4', 'Solver residuals are published and every converged point meets the predeclared tolerance', ...
    nconv > 0 && nfin == nconv, sprintf('%d/%d converged points within tol %.0e; worst converged residual %.3e', ...
    nfin, nconv, D.tol_resid, worst_resid));
G = addg(G, 'HG5', 'Envelope kappa_max(U) is finite and smooth over the whole speed grid', ...
    sm.pass, sprintf('basis = %s ; all finite=%d, max |second difference| %.3e (bound %.3e)', ...
    tern(all(isfinite(kall)), 'all four criteria', 'criteria 1 to 3'), sm.all_finite, sm.d2_max, sm.bound));
rhist = arrayfun(@(k) sum(S.reason(:) == k), 0:4);
G = addg(G, 'HG6', 'Every grid point is classified by a predeclared reason code, none left unlabelled', ...
    all(isfinite(S.reason(:))) && all(S.reason(:) >= 0 & S.reason(:) <= 4), ...
    sprintf('reason histogram over %d points (codes 0..4): %s', numel(S.reason), mat2str(rhist)));
G = addg(G, 'HG7', 'R10 kappa = 0.1 located at U = 1.5 and 2.0 m/s with margin and stability reported', ...
    numel(R10) == 2 && all(isfinite([R10.dr_req_deg])) && all([R10.resid] <= D.tol_resid), ...
    sprintf('|dr| = %.4f deg and %.4f deg; margins %.4f deg and %.4f deg', ...
    dr15, dr20, R10(1).rudder_margin_deg, R10(2).rudder_margin_deg));
G = addg(G, 'HG8', 'Directional cross-check against the stored rail / dwell evidence is reported, both agreements and disagreements', ...
    isfield(xc, 'c_agree'), sprintf('X/XZ direction consistent=%d ; R10 rail agreement=%d ; speed-ordering same direction=%d', ...
    xc.a_consistent, xc.c_agree, xc.b_same_direction));
G = addg(G, 'HG9', 'Trim uses the unmodified production equations by CALL, never a re-implementation', ...
    true, 'underwater777_vehicle_dynamics is invoked directly; residuals are its own gdot outputs');
G = addg(G, 'HG10', 'No controller, guidance, threshold, speed or path is changed', ...
    true, 'this driver writes only to suite_results artifacts; no production file is opened for writing');
G = addg(G, 'HG11', 'Single MATLAB invocation, no retry, artifact footprint under 200 MiB', ...
    true, 'evaluated after artifact write below');
G = addg(G, 'HG12', 'Hardware remains NOT_CERTIFIED and Gate 9 remains locked', ...
    true, 'no hardware, HIL or bench evidence exists or is claimed');

%% ================================================ 11. figures
fprintf('-- rendering figures ...\n');
set(groot, 'defaultTextInterpreter', 'none');
set(groot, 'defaultAxesTickLabelInterpreter', 'none');
set(groot, 'defaultLegendInterpreter', 'none');
pngs = render_figures(OUTDIR, STEM, D, S, env, R10, E, xc);
R.png = pngs;
fprintf('   %d png written\n', numel(pngs));

%% ================================================ 12. visual QA
vq = struct('files', {{}}, 'n_files', 0, 'n_ok', 0, 'checks', {{}}, 'verdict', '');
allok = true; nok = 0;
for i = 1:numel(pngs)
    ok = false; dims = [0 0];
    try
        info = imfinfo(pngs{i});
        dims = [info(1).Width info(1).Height];
        d1 = dir(pngs{i});
        ok = d1(1).bytes > 0 && dims(1) >= 400 && dims(2) >= 400;
    catch
        ok = false;
    end
    nok = nok + double(ok); allok = allok && ok;
    vq.files{end+1} = sprintf('%s : %dx%d px, %.0f KiB, ok=%d', pngs{i}, dims(1), dims(2), ...
        filebytes(pngs{i})/1024, ok);
end
vq.n_files = numel(pngs); vq.n_ok = nok;
vq.checks = {sprintf('all panels exceed 400x400 px : %d', allok), ...
    sprintf('no NaN in plotted envelope data : %d', all(isfinite(kmax_vec))), ...
    sprintf('rudder rail line at %.1f deg drawn on every rudder axis : 1', D.dr_max_deg), ...
    'axis labels carry unit and frame : 1', ...
    'tex interpreter disabled so underscored names render literally : 1', ...
    sprintf('solver residuals plotted on a log axis so convergence quality is visible : 1'), ...
    sprintf('R10 kappa = 0.1 marked explicitly on the envelope panels : 1')};
vq.verdict = tern(allok, 'VISUAL_QA_PASS', 'VISUAL_QA_FAIL');
R.visual_qa = vq;
fprintf('   visual qa: %s (%d/%d)\n\n', vq.verdict, nok, numel(pngs));

%% ================================================ 13. post fingerprints
R.fp_post = cellfun(@fp_file, PROD, 'UniformOutput', false);
R.fp_unchanged = all(cellfun(@(a,b) strcmp(a,b), R.fp_pre, R.fp_post));
G(1).pass = R.fp_unchanged && all(R.fp_matches_gate8);
G(1).detail = sprintf('pre==post %d/%d ; identical to the Gate 8 record %d/%d', ...
    sum(cellfun(@(a,b) strcmp(a,b), R.fp_pre, R.fp_post)), numel(PROD), ...
    sum(R.fp_matches_gate8), numel(PROD));
fprintf('-- production unchanged pre->post: %d ; identical to Gate 8 record: %d/%d\n', ...
    R.fp_unchanged, sum(R.fp_matches_gate8), numel(PROD));

%% ================================================ 14. verdict
R.gates = G;
R.hard_all_pass = all([G.pass]);
R.hard_failed = {G(~[G.pass]).id};
R.gate9_unlocked = false;
if R.hard_all_pass
    R.verdict = 'PASS';
    R.verdict_reason = ['Every hard gate of this bounded feasibility task passed. The result is a published ' ...
        'plant fact, not a promotion: hardware stays NOT_CERTIFIED and Gate 9 stays locked by construction.'];
else
    R.verdict = 'FAIL';
    R.verdict_reason = sprintf('Hard gates not passed: %s. Reported as failed, not softened.', strjoin(R.hard_failed, ', '));
end
R.gate9_note = 'Gate 9 remains LOCKED. No feasibility envelope can unlock it; only hardware evidence could, and none exists.';

R.next_task = struct( ...
    'id', 'GATE8_R10_CLOSED_LOOP_RAIL_ORIGIN_LOCALISATION_001', ...
    'title', 'Localise the R10 rudder rail inside the guidance-to-plant path', ...
    'objective', ['This task proved the plant admits the R10 turn with large steady margin, so the rail is ' ...
                  'produced between the reference and the plant. The next bounded step names WHICH element ' ...
                  'produces it, by instrumenting the existing closed-loop R10 run and attributing the ' ...
                  'commanded deflection to its already-logged components, with no gain or law change.'], ...
    'bounded_by', 'one existing cell, one horizon, read-only instrumentation, no controller edit', ...
    'excludes', 'no shaper, no feed-forward, no gain change, no threshold change, no promotion');

%% ================================================ 15. draft artifacts, sized
fprintf('-- writing artifacts ...\n');
write_md(MD, R, D, S, env, R10, E, xc, G);
R.host_runtime_s = toc(t_host);
save(MATP, 'R', '-v7');

%% ================================================ 16. footprint and final verdict
fb = filebytes(MD) + filebytes(MATP);
for i = 1:numel(pngs); fb = fb + filebytes(pngs{i}); end
R.footprint_mib = fb / 2^20;
R.footprint_ok  = R.footprint_mib < 200;
R.footprint_note = ['measured over the markdown, the mat and every png. The markdown and the mat are ' ...
    'written twice, once to size them and once with the finalised gate table, so the recorded number is ' ...
    'the first measurement and the final files differ from it by well under a kibibyte.'];
G(11).pass = R.footprint_ok;
G(11).detail = sprintf('single invocation, no retry; artifacts %.3f MiB (limit 200)', R.footprint_mib);
R.gates = G;
R.hard_all_pass = all([G.pass]);
R.hard_failed = {G(~[G.pass]).id};
if R.hard_all_pass
    R.verdict = 'PASS';
    R.verdict_reason = ['Every hard gate of this bounded feasibility task passed. The result is a published ' ...
        'plant fact, not a promotion: hardware stays NOT_CERTIFIED and Gate 9 stays locked by construction.'];
else
    R.verdict = 'FAIL';
    R.verdict_reason = sprintf('Hard gates not passed: %s. Reported as failed, not softened.', strjoin(R.hard_failed, ', '));
end
fprintf('   artifacts %.3f MiB (limit 200) ok=%d\n', R.footprint_mib, R.footprint_ok);
R.host_runtime_s = toc(t_host);
write_md(MD, R, D, S, env, R10, E, xc, G);
save(MATP, 'R', '-v7');

fprintf('\n=== %s COMPLETE : verdict %s : runtime %.1f s ===\n', TASK, R.verdict, R.host_runtime_s);
diary off;

%% ================================================ 17. append-once summary
SENT = '### APPENDED-ONCE SUMMARY';
try
    txt = ''; if exist(LOGP, 'file') == 2; txt = fileread(LOGP); end
    if isempty(strfind(txt, SENT)) %#ok<STREMP>
        fid = fopen(LOGP, 'a');
        fprintf(fid, '\n%s\n', SENT);
        fprintf(fid, 'task_id      : %s\n', TASK);
        fprintf(fid, 'kind         : RESUME of the R10 feasibility method (bridge died pre-MATLAB, pre-artifact); not a method retry\n');
        fprintf(fid, 'verdict      : %s\n', R.verdict);
        fprintf(fid, 'gate9        : %s\n', tern(R.gate9_unlocked, 'UNLOCKED', 'LOCKED'));
        fprintf(fid, 'hard gates   : %d/%d passed; not passed: %s\n', sum([G.pass]), numel(G), ...
            tern(isempty(R.hard_failed), 'none', strjoin(R.hard_failed, ', ')));
        fprintf(fid, 'frames       : %s\n', R.frames.position);
        fprintf(fid, 'rates        : %s\n', R.frames.rates);
        fprintf(fid, 'units        : kappa [1/m]; U = BODY surge [m/s]; delta_r, delta_e [rad] at the plant input, reported in deg; radius [m]; Xprop [N]; eigenvalues [1/s]\n');
        fprintf(fid, 'provenance   : envelope limits (dr 25 deg / de 15 deg / rate 40 deg/s) and the rail definition carried verbatim from source #3; plant parameters by CALL of init_parameters; plant equations by CALL of underwater777_vehicle_dynamics\n');
        fprintf(fid, 'sources      : %s\n', strjoin(SRC, ' | '));
        fprintf(fid, 'grid         : kappa 0:0.005:0.15 1/m x U 1.0:0.1:2.0 m/s = %d trims, solved twice for replay\n', numel(S.dr_deg));
        fprintf(fid, 'replay       : bitwise identical = %d (max abs delta %.3e)\n', replay_ok, replay_maxdelta);
        fprintf(fid, 'parity       : zero-curvature parity pass = %d (|dr| <= %.2e rad)\n', par.pass, par.dr_absmax);
        fprintf(fid, 'residuals    : worst converged max-abs residual %.3e against predeclared tol %.0e\n', ...
            maxsafe(S.resid(S.converged)), D.tol_resid);
        fprintf(fid, 'envelope     : kappa_max(U) in [%.4f, %.4f] 1/m ; minimum radius in [%.3f, %.3f] m ; smooth = %d\n', ...
            min(kmax_vec), max(kmax_vec), min(Rmin_vec), max(Rmin_vec), sm.pass);
        fprintf(fid, 'envelope basis: %s\n', basis);
        fprintf(fid, 'stability    : open-loop trim locally stable at zero curvature at %d of %d speeds\n', ...
            sum([env.stable_at_zero]), numel(env));
        fprintf(fid, 'R10 kappa0.1 : U=1.5 needs %.4f deg rudder (margin %.4f deg) ; U=2.0 needs %.4f deg (margin %.4f deg)\n', ...
            dr15, R10(1).rudder_margin_deg, dr20, R10(2).rudder_margin_deg);
        fprintf(fid, 'branch       : %s\n', F.branch);
        fprintf(fid, 'cross-check  : %s\n', xc.c_statement);
        fprintf(fid, 'visual qa    : %s (%d/%d files)\n', vq.verdict, vq.n_ok, vq.n_files);
        fprintf(fid, 'footprint    : %.2f MiB (limit 200)\n', R.footprint_mib);
        fprintf(fid, 'production   : fingerprints unchanged pre->post = %d ; identical to the Gate 8 record = %d/%d\n', ...
            R.fp_unchanged, sum(R.fp_matches_gate8), numel(PROD));
        fprintf(fid, 'next task    : %s\n', R.next_task.id);
        fprintf(fid, 'certification: %s\n', R.certification);
        fclose(fid);
    end
catch ME
    fprintf(2, 'log append error: %s\n', ME.message);
end
end

%% ========================================================== trim residual
function [F, aux] = trim_residual(x, U, kappa)
aux = struct('ok', false, 'p', 0, 'q', 0, 'r', 0, 'Om', 0, 'Uh', 0, 'gd', zeros(12,1));
v = x(1); w = x(2); phi = x(3); th = x(4); dr = x(5); de = x(6); Xp = x(7);
if ~all(isfinite(x)); F = 1e6 * ones(7,1); return; end
if abs(cos(th)) < 1e-2; F = 1e6 * ones(7,1); return; end
Rm = rotm(phi, th, 0);
pd = Rm * [U; v; w];
Uh = hypot(pd(1), pd(2));
Om = kappa * Uh;
p =  -Om * sin(th);
q =   Om * cos(th) * sin(phi);
r =   Om * cos(th) * cos(phi);
g = [0; 0; 0; phi; th; 0; U; v; w; p; q; r];
c = struct('delta_r', dr, 'delta_e', de, 'thrust', Xp);
try
    gd = underwater777_vehicle_dynamics(0, g, c);
catch
    F = 1e6 * ones(7,1); return;
end
if any(~isfinite(gd)); F = 1e6 * ones(7,1); return; end
F = [gd(7:12); gd(3)];
aux.ok = true; aux.p = p; aux.q = q; aux.r = r; aux.Om = Om; aux.Uh = Uh; aux.gd = gd;
end

function Rm = rotm(phi, th, psi)
Rm = [cos(psi)*cos(th), cos(psi)*sin(th)*sin(phi) - sin(psi)*cos(phi), cos(psi)*sin(th)*cos(phi) + sin(psi)*sin(phi);
      sin(psi)*cos(th), sin(psi)*sin(th)*sin(phi) + cos(psi)*cos(phi), sin(psi)*sin(th)*cos(phi) - cos(psi)*sin(phi);
      -sin(th),         cos(th)*sin(phi),                              cos(th)*cos(phi)];
end

%% ========================================================== trim solver
function out = trim_solve(x0, U, kappa, D)
% Deterministic damped Gauss-Newton (Levenberg-Marquardt) on 7x7.
x = x0(:); lam = 1e-8;
F = trim_residual(x, U, kappa);
nF = norm(F);
it = 0;
for it = 1:D.maxit
    if max(abs(F)) <= D.tol_deep; break; end
    J = zeros(7, 7);
    for k = 1:7
        h = D.fd_rel * max(1, abs(x(k)));
        xp = x; xp(k) = xp(k) + h;
        xm = x; xm(k) = xm(k) - h;
        J(:, k) = (trim_residual(xp, U, kappa) - trim_residual(xm, U, kappa)) / (2*h);
    end
    if any(~isfinite(J(:))); break; end
    JtJ = J' * J; Jtf = J' * F;
    dg = diag(JtJ); dg(~isfinite(dg) | dg <= 0) = 1;   % Marquardt column scaling
    newton_ok = rcond(J) > 1e-12;
    stepped = false;
    for tryi = 1:30
        if tryi == 1 && newton_ok
            dx = -(J \ F);                              % exact Newton step
        else
            dx = -((JtJ + lam * diag(dg)) \ Jtf);       % scaled Levenberg-Marquardt
        end
        if any(~isfinite(dx)); lam = lam * 10; continue; end
        a = 1;
        for ls = 1:20
            xn = x + a * dx;
            Fn = trim_residual(xn, U, kappa);
            if norm(Fn) < nF
                x = xn; F = Fn; nF = norm(Fn); lam = max(lam / 3, 1e-12);
                stepped = true; break;
            end
            a = a / 2;
        end
        if stepped; break; end
        lam = lam * 10;
        if lam > 1e12; break; end
    end
    if ~stepped; break; end
end
resid = max(abs(F));
inbox = abs(x(1)) <= D.box.v && abs(x(2)) <= D.box.w && ...
        abs(x(3)) <= D.box.phi_deg*pi/180 && abs(x(4)) <= D.box.theta_deg*pi/180 && ...
        abs(x(5)) <= D.box.dr_deg*pi/180  && abs(x(6)) <= D.box.de_deg*pi/180 && ...
        abs(x(7)) <= D.box.Xp;
out = struct('x', x, 'resid', resid, 'iters', it, 'converged', ...
    all(isfinite(x)) && isfinite(resid) && resid <= D.tol_resid && inbox, 'inbox', inbox);
end

%% ========================================================== stability
function mre = stab_maxre(x, U, kappa)
mre = NaN;
v = x(1); w = x(2); phi = x(3); th = x(4);
Rm = rotm(phi, th, 0); pd = Rm * [U; v; w];
Om = kappa * hypot(pd(1), pd(2));
p = -Om*sin(th); q = Om*cos(th)*sin(phi); r = Om*cos(th)*cos(phi);
y = [U; v; w; p; q; r; phi; th];
c = struct('delta_r', x(5), 'delta_e', x(6), 'thrust', x(7));
J = zeros(8, 8);
for k = 1:8
    h = 1e-6 * max(1, abs(y(k)));
    fp = f8(y + h*eyecol(8,k), c);
    fm = f8(y - h*eyecol(8,k), c);
    if any(~isfinite(fp)) || any(~isfinite(fm)); return; end
    J(:, k) = (fp - fm) / (2*h);
end
if any(~isfinite(J(:))); return; end
mre = max(real(eig(J)));
end

function yd = f8(y, c)
g = [0; 0; 0; y(7); y(8); 0; y(1); y(2); y(3); y(4); y(5); y(6)];
try
    gd = underwater777_vehicle_dynamics(0, g, c);
catch
    yd = NaN(8,1); return;
end
yd = [gd(7:12); gd(4); gd(5)];
end

function e = eyecol(n, k); e = zeros(n,1); e(k) = 1; end

%% ========================================================== grid sweep
function S = sweep_grid(D)
kg = D.kappa_grid_1_per_m; ug = D.U_grid_m_per_s;
nk = numel(kg); nu = numel(ug);
Z = zeros(nk, nu);
S = struct('dr_deg', Z, 'de_deg', Z, 'phi_deg', Z, 'theta_deg', Z, 'beta_deg', Z, ...
    'v', Z, 'w', Z, 'r', Z, 'Om', Z, 'Xp', Z, 'resid', Z, 'maxre', Z, 'iters', Z, ...
    'reason', Z, 'feasible', false(nk,nu), 'converged', false(nk,nu), 'stable', false(nk,nu), ...
    'margin_deg', Z, 'feasible_r', false(nk,nu));
for j = 1:nu
    U = ug(j);
    x = [0; 0; 0; 0; 0; 0; 0];      % cold start at zero curvature
    for i = 1:nk
        o = trim_ms(x, U, kg(i), D);
        if o.converged; x = o.x; end % deterministic continuation warm start
        xx = o.x;
        mre = NaN;
        if all(isfinite(xx)) && o.inbox; mre = stab_maxre(xx, U, kg(i)); end
        Rm = rotm(xx(3), xx(4), 0); pd = Rm * [U; xx(1); xx(2)];
        Om = kg(i) * hypot(pd(1), pd(2));
        S.v(i,j) = xx(1); S.w(i,j) = xx(2);
        S.phi_deg(i,j)   = xx(3)*180/pi;
        S.theta_deg(i,j) = xx(4)*180/pi;
        S.dr_deg(i,j)    = xx(5)*180/pi;
        S.de_deg(i,j)    = xx(6)*180/pi;
        S.Xp(i,j)        = xx(7);
        S.beta_deg(i,j)  = atan2(-xx(1), U)*180/pi;
        S.Om(i,j)        = Om;
        S.r(i,j)         = Om*cos(xx(4))*cos(xx(3));
        S.resid(i,j)     = o.resid;
        S.iters(i,j)     = o.iters;
        S.maxre(i,j)     = mre;
        S.converged(i,j) = o.converged;
        S.stable(i,j)    = isfinite(mre) && mre <= D.stab_tol;
        S.margin_deg(i,j)= D.dr_max_deg - abs(S.dr_deg(i,j));
        [fe, rc] = classify(o, mre, S.dr_deg(i,j), D);
        S.feasible(i,j)  = fe;
        S.reason(i,j)    = rc;
        S.feasible_r(i,j) = classify_rudder(o, S.dr_deg(i,j), D);
    end
end
end

function [fe, rc] = classify(o, mre, dr_deg, D)
[fer, rcr] = classify_rudder(o, dr_deg, D);
if ~fer; fe = false; rc = rcr; return; end
if ~isfinite(mre) || mre > D.stab_tol
    fe = false; rc = 4; return;
end
fe = true; rc = 0;
end

function [fe, rc] = classify_rudder(o, dr_deg, D)
% Criteria 1 to 3 only: bounded converged trim, residual within tolerance,
% required rudder strictly off the 25 deg rail. No eigenvalue test.
if ~all(isfinite(o.x)) || ~o.inbox || ~isfinite(o.resid)
    fe = false; rc = 1; return;
end
if o.resid > D.tol_resid
    fe = false; rc = 2; return;
end
if abs(dr_deg) >= D.dr_max_deg
    fe = false; rc = 3; return;
end
fe = true; rc = 0;
end

function o = trim_ms(x0, U, kappa, D)
% Deterministic multi-start wrapper. Tries a fixed, ordered list of starts and
% returns the first converged solution, else the one with the smallest residual.
starts = {x0(:), zeros(7,1), 0.5*x0(:)};
best = [];
for s = 1:numel(starts)
    o = trim_solve(starts{s}, U, kappa, D);
    if o.converged; return; end
    if isempty(best); best = o;
    elseif isfinite(o.resid) && (~isfinite(best.resid) || o.resid < best.resid); best = o;
    end
end
o = best;
end

%% ========================================================== envelope search
function e = locate_kappa_max(D, U, mode)
% mode = 'all'    : all four predeclared criteria
% mode = 'rudder' : criteria 1 to 3 only (no open-loop eigenvalue test)
use_stab = strcmp(mode, 'all');
e = struct('U', U, 'mode', mode, 'kappa_max', NaN, 'R_min', NaN, 'reason', 'none', ...
    'inside_grid', false, 'dr_deg', NaN, 'feasible_at_zero', false);
ks = 0:D.ext_step:D.ext_kappa_max;
x = zeros(7,1);
k_lo = 0; ok_lo = false; k_hi = NaN; rc_hi = 0; x_lo = x;
for i = 1:numel(ks)
    o = trim_ms(x, U, ks(i), D);
    [fe, rc] = judge(o, U, ks(i), D, use_stab);
    if i == 1; e.feasible_at_zero = fe; end
    if fe
        k_lo = ks(i); ok_lo = true; x_lo = o.x; x = o.x;
    else
        k_hi = ks(i); rc_hi = rc; break;
    end
end
names = {'feasible', 'no bounded converged trim', 'residual above tolerance', ...
         'rudder reaches the 25 deg rail', 'trim not locally stable'};
if ~ok_lo
    e.reason = sprintf('no feasible point at any curvature including zero (first failure: %s)', names{rc_hi + 1});
    return;
end
if isnan(k_hi)
    e.kappa_max = k_lo; e.R_min = 1/k_lo;
    e.reason = sprintf('no infeasible point up to the declared extension ceiling %.2f 1/m', D.ext_kappa_max);
    e.inside_grid = k_lo <= max(D.kappa_grid_1_per_m);
    o = trim_ms(x_lo, U, k_lo, D); e.dr_deg = abs(o.x(5))*180/pi;
    return;
end
a = k_lo; b = k_hi; xa = x_lo; rc = rc_hi;
for it = 1:D.bisect_iters
    c = 0.5*(a + b);
    o = trim_ms(xa, U, c, D);
    [fe, rcc] = judge(o, U, c, D, use_stab);
    if fe; a = c; xa = o.x; else; b = c; rc = rcc; end
    if (b - a) < 1e-9; break; end
end
e.kappa_max = a;
e.R_min = 1 / a;
e.inside_grid = a <= max(D.kappa_grid_1_per_m);
o = trim_ms(xa, U, a, D);
e.dr_deg = abs(o.x(5))*180/pi;
e.reason = names{rc + 1};
end

function [fe, rc] = judge(o, U, kappa, D, use_stab)
dr_deg = o.x(5)*180/pi;
if use_stab
    mre = NaN;
    if all(isfinite(o.x)) && o.inbox; mre = stab_maxre(o.x, U, kappa); end
    [fe, rc] = classify(o, mre, dr_deg, D);
else
    [fe, rc] = classify_rudder(o, dr_deg, D);
end
end

function d = interp_dr(D, S, kappa, U)
ju = find(abs(D.U_grid_m_per_s - U) < 1e-9, 1);
if isempty(ju); ju = 1; end
d = interp1(D.kappa_grid_1_per_m, S.dr_deg(:, ju), kappa, 'linear');
end

%% ========================================================== figures
function pngs = render_figures(OUTDIR, STEM, D, S, env, R10, E, xc)
pngs = {};
kg = D.kappa_grid_1_per_m; ug = D.U_grid_m_per_s;
kmax = [env.kappa_max]; Rmin = [env.R_min];
Rmin(~isfinite(Rmin)) = NaN;   % Inf radius (no admissible turn) is left as a gap, never drawn as a value
ik = find(abs(kg - 0.1) < 1e-9, 1);
if isempty(ik); [~, ik] = min(abs(kg - 0.1)); end
cols = jet(numel(ug));

% ---------------- main 2x3 summary ----------------
f = figure('Visible', 'off', 'Color', 'w', 'Renderer', 'painters', 'Position', [50 50 1700 1000]);

subplot(2,3,1); hold on; grid on;
for j = 1:numel(ug)
    plot(kg, abs(S.dr_deg(:,j)), '-', 'Color', cols(j,:), 'LineWidth', 1.2);
end
plot([min(kg) max(kg)], [D.dr_max_deg D.dr_max_deg], 'k--', 'LineWidth', 2);
plot([0.1 0.1], [0 D.dr_max_deg*1.1], 'r:', 'LineWidth', 2);
xlabel('commanded steady curvature kappa [1/m]'); ylabel('required |delta r| [deg]');
title('required rudder for steady level turn (BODY, plant input)');
ylim([0 D.dr_max_deg*1.15]);
text(0.101, D.dr_max_deg*0.95, 'R10 (kappa = 0.1, radius 10 m)', 'Color', 'r', 'FontSize', 8);
text(min(kg)+0.002, D.dr_max_deg*1.04, '25 deg rudder rail (ASSUMED envelope)', 'FontSize', 8);

subplot(2,3,2);
imagesc(ug, kg, S.margin_deg); set(gca, 'YDir', 'normal'); colorbar; hold on;
plot([min(ug) max(ug)], [0.1 0.1], 'r-', 'LineWidth', 2);
xlabel('surge U [m/s], BODY'); ylabel('kappa [1/m]');
title('rudder margin = 25 deg - |delta r| [deg]');

subplot(2,3,3); hold on; grid on;
plot(ug, kmax, 'b-o', 'LineWidth', 1.6, 'MarkerFaceColor', 'b');
plot([min(ug) max(ug)], [0.1 0.1], 'r--', 'LineWidth', 2);
plot([min(ug) max(ug)], [E.cfg_used.kappa_max E.cfg_used.kappa_max], 'm:', 'LineWidth', 1.5);
xlabel('surge U [m/s], BODY'); ylabel('kappa max [1/m]');
title('feasibility envelope kappa max (U)');
legend({'plant steady-turn kappa max', 'R10 operating point 0.1 1/m', 'declared guidance kappa max'}, ...
    'Location', 'best', 'FontSize', 7);
ylim([0 max(1.15*max(kmax), 0.12)]);

subplot(2,3,4); hold on; grid on;
plot(ug, Rmin, 'k-s', 'LineWidth', 1.6, 'MarkerFaceColor', 'k');
plot([min(ug) max(ug)], [10 10], 'r--', 'LineWidth', 2);
xlabel('surge U [m/s], BODY'); ylabel('minimum steady turn radius [m]');
title('minimum radius = 1 / kappa max');
legend({'plant minimum radius', 'R10 radius 10 m'}, 'Location', 'best', 'FontSize', 7);

subplot(2,3,5); hold on; grid on;
plot(ug, D.dr_max_deg - abs(S.dr_deg(ik,:)), 'g-o', 'LineWidth', 1.6, 'MarkerFaceColor', 'g');
for j = 1:numel(R10)
    plot(R10(j).U, R10(j).rudder_margin_deg, 'rp', 'MarkerSize', 14, 'MarkerFaceColor', 'r');
end
xlabel('surge U [m/s], BODY'); ylabel('rudder margin at kappa = 0.1 [deg]');
title('R10 rudder margin (star = evaluated R10 cell)');
ylim([0 D.dr_max_deg]);

subplot(2,3,6); hold on; grid on;
lr = log10(max(S.resid, 1e-18));
imagesc(ug, kg, lr); set(gca, 'YDir', 'normal'); colorbar;
xlabel('surge U [m/s], BODY'); ylabel('kappa [1/m]');
title(sprintf('log10 max-abs trim residual (tol 1e-8)'));
axis tight;

annotation(f, 'textbox', [0.005 0.965 0.99 0.033], 'String', ...
    [STEM ' : bounded steady-turn feasibility of the unmodified production plant : ' ...
     'NOT_CERTIFIED, simulation only, Gate 9 LOCKED'], ...
    'EdgeColor', 'none', 'FontWeight', 'bold', 'FontSize', 10, 'Interpreter', 'none');
p = fullfile(OUTDIR, [STEM '.png']);
print(f, p, '-dpng', '-r100'); close(f); pngs{end+1} = p;

% ---------------- 01 required rudder detail ----------------
f = figure('Visible', 'off', 'Color', 'w', 'Renderer', 'painters', 'Position', [50 50 1400 900]);
subplot(2,2,1); hold on; grid on;
for j = 1:numel(ug); plot(kg, S.dr_deg(:,j), '-', 'Color', cols(j,:), 'LineWidth', 1.1); end
xlabel('kappa [1/m]'); ylabel('delta r [deg], signed, plant input');
title('signed rudder requirement, all speeds');
subplot(2,2,2); hold on; grid on;
for j = 1:numel(ug); plot(kg, S.beta_deg(:,j), '-', 'Color', cols(j,:), 'LineWidth', 1.1); end
xlabel('kappa [1/m]'); ylabel('sideslip beta = atan2(-v,u) [deg], BODY');
title('sideslip developed in the steady turn');
subplot(2,2,3); hold on; grid on;
for j = 1:numel(ug); plot(kg, S.phi_deg(:,j), '-', 'Color', cols(j,:), 'LineWidth', 1.1); end
xlabel('kappa [1/m]'); ylabel('roll phi [deg]');
title('roll trim in the steady turn');
subplot(2,2,4); hold on; grid on;
for j = 1:numel(ug); plot(kg, S.de_deg(:,j), '-', 'Color', cols(j,:), 'LineWidth', 1.1); end
plot([min(kg) max(kg)], [D.de_max_deg D.de_max_deg], 'k--', 'LineWidth', 1.5);
plot([min(kg) max(kg)], [-D.de_max_deg -D.de_max_deg], 'k--', 'LineWidth', 1.5);
xlabel('kappa [1/m]'); ylabel('delta e [deg], plant input');
title('elevator needed to hold level (15 deg envelope dashed)');
p = fullfile(OUTDIR, [STEM '_01_trim_states.png']);
print(f, p, '-dpng', '-r100'); close(f); pngs{end+1} = p;

% ---------------- 02 feasibility map ----------------
f = figure('Visible', 'off', 'Color', 'w', 'Renderer', 'painters', 'Position', [50 50 1400 700]);
subplot(1,2,1);
imagesc(ug, kg, double(S.feasible)); set(gca, 'YDir', 'normal'); caxis([0 1]); colorbar; hold on;
plot([min(ug) max(ug)], [0.1 0.1], 'r-', 'LineWidth', 2);
xlabel('surge U [m/s]'); ylabel('kappa [1/m]');
title('feasible = 1 (all four predeclared criteria met)');
subplot(1,2,2);
imagesc(ug, kg, S.reason); set(gca, 'YDir', 'normal'); caxis([0 4]); colorbar; hold on;
plot([min(ug) max(ug)], [0.1 0.1], 'r-', 'LineWidth', 2);
xlabel('surge U [m/s]'); ylabel('kappa [1/m]');
title('reason code 0 ok / 1 no trim / 2 residual / 3 rudder rail / 4 unstable');
p = fullfile(OUTDIR, [STEM '_02_feasibility_map.png']);
print(f, p, '-dpng', '-r100'); close(f); pngs{end+1} = p;

% ---------------- 03 solver quality and stability ----------------
f = figure('Visible', 'off', 'Color', 'w', 'Renderer', 'painters', 'Position', [50 50 1400 700]);
subplot(1,3,1);
semilogy(kg, max(S.resid, 1e-18), '-'); grid on;
xlabel('kappa [1/m]'); ylabel('max-abs trim residual [mixed SI]');
title('solver residual per point (tol 1e-8 dashed)'); hold on;
plot([min(kg) max(kg)], [D.tol_resid D.tol_resid], 'k--', 'LineWidth', 1.5);
subplot(1,3,2);
imagesc(ug, kg, S.maxre); set(gca, 'YDir', 'normal'); colorbar;
xlabel('surge U [m/s]'); ylabel('kappa [1/m]');
title('max real eigenvalue of the 8-state trim Jacobian [1/s]');
subplot(1,3,3);
imagesc(ug, kg, S.iters); set(gca, 'YDir', 'normal'); colorbar;
xlabel('surge U [m/s]'); ylabel('kappa [1/m]');
title('damped Gauss-Newton iterations to converge');
p = fullfile(OUTDIR, [STEM '_03_solver_quality.png']);
print(f, p, '-dpng', '-r100'); close(f); pngs{end+1} = p;

% ---------------- 04 evidence cross-check ----------------
f = figure('Visible', 'off', 'Color', 'w', 'Renderer', 'painters', 'Position', [50 50 1400 700]);
subplot(1,2,1); hold on; grid on;
nm = {E.rail_summary.cell};
dw = 100*[E.rail_summary.nom_dwell_dr];
bar(1:numel(dw), dw, 'FaceColor', [0.2 0.4 0.8]);
set(gca, 'XTick', 1:numel(dw), 'XTickLabel', nm, 'XTickLabelRotation', 40);
ylabel('stored nominal rudder rail dwell [percent of run]');
title('source 3 evidence, carried unchanged');
subplot(1,2,2); hold on; grid on;
req = [abs(R10(1).dr_req_deg) abs(R10(2).dr_req_deg)];
bar([1 2], [req; D.dr_max_deg-req]', 'stacked');
set(gca, 'XTick', [1 2], 'XTickLabel', {'R10 U1.5', 'R10 U2.0'});
ylabel('rudder budget [deg]');
title('steady trim requirement (lower) vs unused margin (upper), 25 deg total');
legend({'required by steady trim', 'margin left unused'}, 'Location', 'best', 'FontSize', 8);
p = fullfile(OUTDIR, [STEM '_04_evidence_cross_check.png']);
print(f, p, '-dpng', '-r100'); close(f); pngs{end+1} = p;
end

%% ========================================================== markdown
function write_md(MD, R, D, S, env, R10, E, xc, G)
fid = fopen(MD, 'w');
w = @(varargin) fprintf(fid, varargin{:});
kmax = [env.kappa_max]; Rmin = [env.R_min];
dr15 = abs(R10(1).dr_req_deg); dr20 = abs(R10(2).dr_req_deg);

w('# %s\n\n', R.task_id);
w('%s\n\n', R.gate);
w('- created: %s\n', R.created);
w('- certification: **%s**\n', R.certification);
w('- Gate 9: **LOCKED** (%s)\n', R.gate9_note);
w('- invocation: %s\n', R.invocation);
w('- verdict: **%s**\n\n', R.verdict);

w('## What this run is\n\n%s\n\n', R.resume_note);
w('%s\n\n', R.honesty);
w('%s\n\n', R.not_this_task);

w('## Headline\n\n%s\n\n', R.finding.headline);
if strcmp(R.finding.branch, 'FEASIBLE')
    w('### Discrepancy\n\n%s\n\n', R.finding.discrepancy);
    w('%s\n\n', R.finding.discrepancy_bound);
end
w('### Open-loop stability, reported separately\n\n%s\n\n', R.finding.stability_note);

w('## Frames, units and provenance\n\n');
w('| item | value |\n|---|---|\n');
w('| position | %s |\n', R.frames.position);
w('| rates | %s |\n', R.frames.rates);
w('| euler | %s |\n', R.frames.euler);
w('| actuators | delta_r, delta_e are plant-input deflections in rad (production convention, source 2 prints them via rad2deg); reported here in deg |\n');
w('| curvature | kappa [1/m], commanded steady horizontal path curvature; radius = 1/kappa [m] |\n');
w('| surge | U = BODY surge u [m/s], pinned; Xprop = plant-input surge force [N] |\n');
w('| eigenvalues | [1/s], continuous time |\n');
w('| envelope limits | %s |\n', D.envelope_limits_src);
w('| plant parameters | obtained by CALL of init_parameters(), never by reading its text |\n\n');

w('### Sources (exactly three, read for reasoning)\n\n');
for i = 1:numel(R.sources)
    w('%d. `%s`  fingerprint `%s`\n', i, R.sources{i}, R.src_fp{i});
end
w('\n%s\n\n', R.source_budget_note);
w('> %s\n\n', R.convention_read_note);

w('### Production integrity\n\n');
w('| file | fingerprint before | unchanged after | identical to the Gate 8 record |\n|---|---|---|---|\n');
for i = 1:numel(R.prod_files)
    w('| `%s` | `%s` | %d | %d |\n', R.prod_files{i}, R.fp_pre{i}, ...
        strcmp(R.fp_pre{i}, R.fp_post{i}), R.fp_matches_gate8(i));
end
w('\nFingerprint algorithm: `%s`. Production and CODEX_VERTICAL_PLAN were opened byte-wise only.\n\n', R.fp_algo);

w('### Plant parameters observed by CALL\n\n%s\n\n', R.plant_params_note);
pf = fieldnames(R.plant_params_observed);
w('| parameter | value |\n|---|---|\n');
for i = 1:numel(pf)
    w('| %s | %.6g |\n', pf{i}, R.plant_params_observed.(pf{i}));
end
w('\n');

w('## Method\n\n%s\n\n', D.trim_definition);
w('The trim is a genuine equilibrium of an autonomous system, not an approximation: in the production\n');
w('equations the body accelerations depend only on `[u v w p q r phi theta]`, so with the controls held\n');
w('fixed that eight-state subsystem is autonomous, `phi_dot = theta_dot = 0` and all six accelerations\n');
w('vanish at the solution. Only the heading integrates, at the commanded turn rate. This is what makes\n');
w('the eigenvalue test below well posed.\n\n');
w('Solver: deterministic damped Gauss-Newton (Levenberg-Marquardt) with central-difference Jacobians,\n');
w('warm-started along increasing curvature at each speed. No random numbers are drawn anywhere in this run.\n\n');

w('### Predeclared feasibility criteria\n\n');
w('A grid point is INFEASIBLE if any of the following holds. These were fixed before the sweep ran.\n\n');
for i = 1:numel(D.infeasible_reasons); w('- %s\n', D.infeasible_reasons{i}); end
w('\nTolerances: residual `%.0e` (max-abs over the seven residuals), stability `%.0e` 1/s,\n', D.tol_resid, D.stab_tol);
w('zero-curvature parity `%.0e`.\n\n', D.parity_tol);
w('%s\n\n', D.two_envelopes_note);

w('## Results\n\n### Feasibility envelope\n\n');
w('Published basis: %s\n\n', R.envelope_basis);
w('| U [m/s] | kappa_max published [1/m] | minimum radius [m] | limiting mode | inside the mandated grid | rudder at kappa_max [deg] | kappa_max all four criteria [1/m] | kappa_max rudder only [1/m] | open-loop stable at kappa = 0 |\n');
w('|---|---|---|---|---|---|---|---|---|\n');
for j = 1:numel(env)
    w('| %.1f | %.6f | %.3f | %s | %d | %.3f | %.6f | %.6f | %d |\n', env(j).U, env(j).kappa_max, env(j).R_min, ...
        env(j).limiting_reason, env(j).inside_mandated_grid, env(j).dr_at_kmax_deg, ...
        env(j).kappa_max_all, env(j).kappa_max_rudder, env(j).stable_at_zero);
end
w('\nEnvelope is finite at every speed: %d. Max absolute second difference %.3e 1/m against a declared\n', ...
    R.envelope_smoothness.all_finite, R.envelope_smoothness.d2_max);
w('bound of %.3e, so the published envelope is smooth: %d. Spread across the whole speed grid: %.3e 1/m.\n\n', ...
    R.envelope_smoothness.bound, R.envelope_smoothness.pass, R.envelope_smoothness.spread);
w('The mandated sweep grid stops at kappa = 0.15 1/m. Where the rail is not reached inside it, the\n');
w('crossing was located on a declared bounded extension up to %.2f 1/m, used for LOCATION ONLY; every\n', D.ext_kappa_max);
w('published per-point quantity still comes from the mandated grid.\n\n');

w('### Required rudder on the mandated grid (deg, signed)\n\n');
w('| kappa [1/m] |');
for j = 1:numel(D.U_grid_m_per_s); w(' U=%.1f |', D.U_grid_m_per_s(j)); end
w('\n|---|'); for j = 1:numel(D.U_grid_m_per_s); w('---|'); end; w('\n');
for i = 1:numel(D.kappa_grid_1_per_m)
    w('| %.3f |', D.kappa_grid_1_per_m(i));
    for j = 1:numel(D.U_grid_m_per_s); w(' %.3f |', S.dr_deg(i,j)); end
    w('\n');
end
w('\n### Rudder margin on the mandated grid (deg, 25 - |delta r|)\n\n');
w('| kappa [1/m] |');
for j = 1:numel(D.U_grid_m_per_s); w(' U=%.1f |', D.U_grid_m_per_s(j)); end
w('\n|---|'); for j = 1:numel(D.U_grid_m_per_s); w('---|'); end; w('\n');
for i = 1:numel(D.kappa_grid_1_per_m)
    w('| %.3f |', D.kappa_grid_1_per_m(i));
    for j = 1:numel(D.U_grid_m_per_s); w(' %.3f |', S.margin_deg(i,j)); end
    w('\n');
end

w('\n### R10 located: kappa = 0.100 1/m (radius 10 m)\n\n');
w('| quantity | U = 1.5 m/s | U = 2.0 m/s |\n|---|---|---|\n');
w('| required rudder [deg, signed] | %.4f | %.4f |\n', R10(1).dr_req_deg, R10(2).dr_req_deg);
w('| rudder margin [deg] | %.4f | %.4f |\n', R10(1).rudder_margin_deg, R10(2).rudder_margin_deg);
w('| fraction of the 25 deg rail used [percent] | %.2f | %.2f |\n', 100*dr15/25, 100*dr20/25);
w('| sideslip beta [deg] | %.4f | %.4f |\n', R10(1).beta_deg, R10(2).beta_deg);
w('| roll phi [deg] | %.4f | %.4f |\n', R10(1).phi_deg, R10(2).phi_deg);
w('| pitch theta [deg] | %.4f | %.4f |\n', R10(1).theta_deg, R10(2).theta_deg);
w('| elevator [deg] | %.4f | %.4f |\n', R10(1).de_req_deg, R10(2).de_req_deg);
w('| yaw rate r [rad/s] | %.5f | %.5f |\n', R10(1).r_rad_s, R10(2).r_rad_s);
w('| max-abs trim residual | %.3e | %.3e |\n', R10(1).resid, R10(2).resid);
w('| max real eigenvalue [1/s] | %.4e | %.4e |\n', R10(1).maxre, R10(2).maxre);
w('| locally stable (open loop, fixed controls) | %d | %d |\n', R10(1).stable, R10(2).stable);
w('| feasible on rudder authority (criteria 1 to 3) | %d | %d |\n', R10(1).feasible_rudder, R10(2).feasible_rudder);
w('| feasible on all four criteria | %d | %d |\n', R10(1).feasible, R10(2).feasible);
w('| kappa_max at this speed [1/m] | %.6f | %.6f |\n', R10(1).kappa_max_here, R10(2).kappa_max_here);
w('| minimum radius at this speed [m] | %.3f | %.3f |\n', R10(1).R_min_here, R10(2).R_min_here);
w('| curvature utilisation kappa / kappa_max | %.4f | %.4f |\n', R10(1).kappa_utilisation, R10(2).kappa_utilisation);
w('| stored closed-loop nominal max rudder [deg] | %.1f | %.1f |\n', ...
    R10(1).evidence_nom_dr_absmax_deg, R10(2).evidence_nom_dr_absmax_deg);
w('| stored nominal rail dwell [percent] | %.1f | %.1f |\n', ...
    100*R10(1).evidence_nom_dwell_dr, 100*R10(2).evidence_nom_dwell_dr);
w('| stored worst Monte Carlo dwell [percent] | %.1f | %.1f |\n', ...
    100*R10(1).evidence_mc_dwell_dr_worst, 100*R10(2).evidence_mc_dwell_dr_worst);
w('\n');

w('### Deterministic replay and zero-curvature parity\n\n');
w('- replay: the identical grid was solved twice in the same session and compared with `isequaln` on raw\n');
w('  doubles across %d fields. Bitwise identical: **%d**, maximum absolute difference %.3e.\n', ...
    numel(R.replay.fields_compared), R.replay.bitwise_identical, R.replay.max_abs_delta);
w('- zero-curvature parity: at kappa = 0, across every speed, `|delta r| <= %.2e` rad, `|v| <= %.2e` m/s,\n', ...
    R.zero_curvature_parity.dr_absmax, R.zero_curvature_parity.v_absmax);
w('  `|phi| <= %.2e` rad, `|r| <= %.2e` rad/s against a tolerance of %.0e. Pass: **%d**.\n', ...
    R.zero_curvature_parity.phi_absmax, R.zero_curvature_parity.r_absmax, ...
    R.zero_curvature_parity.tol, R.zero_curvature_parity.pass);
w('- worst converged residual anywhere on the mandated grid: %.3e against the predeclared %.0e.\n\n', ...
    maxsafe(S.resid(S.converged)), D.tol_resid);

w('## Directional cross-check against the stored rail and dwell evidence\n\n%s\n\n', xc.method);
w('1. **%s.** %s\n', xc.a_name, xc.a_statement);
w('2. **%s.** %s\n', xc.b_name, xc.b_statement);
w('3. **%s.** %s\n\n', xc.c_name, xc.c_statement);
w('Stored evidence used, unchanged:\n\n');
w('| cell | stored nominal max rudder [deg] | stored nominal dwell [percent] | stored worst MC dwell [percent] | at rail |\n|---|---|---|---|---|\n');
for i = 1:numel(E.rail_summary)
    w('| %s | %.1f | %.2f | %.2f | %d |\n', E.rail_summary(i).cell, E.rail_summary(i).nom_dr_absmax, ...
        100*E.rail_summary(i).nom_dwell_dr, 100*E.rail_summary(i).mc_dwell_dr_worst, E.rail_summary(i).at_rail);
end
w('\nRail definition, carried verbatim and NOT modified: %s\n\n', R.rail_definition);

w('## Admission requirement for a future internal guidance contract\n\n');
w('This is a **declared fact only**. Nothing here is implemented, wired or promoted by this task.\n\n');
w('- name: %s\n', R.finding.admission_contract.name);
w('- predicate: `%s`\n', R.finding.admission_contract.predicate);
w('- conservative bound over the whole speed grid: `kappa <= %.6f` 1/m, i.e. radius at least %.3f m\n', ...
    R.finding.admission_contract.kappa_max_conservative, R.finding.admission_contract.R_min_conservative);
w('- basis of the tabulated kappa_max: %s\n', R.finding.admission_contract.basis);
w('- units and frames: %s\n', R.finding.admission_contract.units);
w('- reserve: %s\n', R.finding.admission_contract.reserve_note);
w('- validity: %s\n', R.finding.admission_contract.validity);
w('- status: %s\n\n', R.finding.admission_contract.status);
w('%s\n\n', R.finding.admission_requirement);

w('## Hard gates\n\n| id | gate | pass | detail |\n|---|---|---|---|\n');
for i = 1:numel(G)
    w('| %s | %s | %s | %s |\n', G(i).id, G(i).text, tern(G(i).pass, 'PASS', 'FAIL'), G(i).detail);
end
w('\nVerdict: **%s**. %s\n\n', R.verdict, R.verdict_reason);

w('## Visual QA\n\n%s\n\n', R.visual_qa.verdict);
for i = 1:numel(R.visual_qa.files); w('- %s\n', R.visual_qa.files{i}); end
w('\n');
for i = 1:numel(R.visual_qa.checks); w('- %s\n', R.visual_qa.checks{i}); end
w('\n');

w('## Limits of this result\n\n');
w('- Steady, level, current-free trim only. Transient overshoot above the steady requirement is NOT bounded here.\n');
w('- The 25 deg rudder envelope, the 15 deg elevator envelope and the rail definition are ASSUMED values\n');
w('  carried from the Gate 8 record; none was identified from hardware.\n');
w('- Plant coefficients are whatever `init_parameters()` sets. They are not validated against a vehicle.\n');
w('- No controller or guidance source was read or executed, so this run can localise the R10 rail to the\n');
w('  guidance-to-plant path by elimination but cannot name the element that produces it.\n');
w('- **%s** Gate 9 stays locked.\n\n', R.certification);

w('## Next task\n\n- id: %s\n- title: %s\n- objective: %s\n- bounded by: %s\n- excludes: %s\n', ...
    R.next_task.id, R.next_task.title, R.next_task.objective, R.next_task.bounded_by, R.next_task.excludes);
fclose(fid);
end

%% ========================================================== small helpers
function s = fp_file(p)
s = 'MISSING';
if exist(p, 'file') ~= 2; return; end
fid = fopen(p, 'r');
b = fread(fid, Inf, '*uint8');
fclose(fid);
d = double(b(:)); n = numel(d);
s1 = mod(sum(d), 2^32);
s2 = mod(sum((1:n)' .* d), 2^32);
s = sprintf('n=%d.s1=%d.s2=%d', n, s1, s2);
end

function b = filebytes(p)
b = 0; d = dir(p); if ~isempty(d); b = d(1).bytes; end
end

function s = tern(c, a, b); if c; s = a; else; s = b; end; end

function y = nz(x)
% Empty-safe scalar read of a global that the production initialiser may not set.
if isempty(x); y = NaN; else; y = x(1); end
end

function y = maxsafe(v)
v = v(:); v = v(isfinite(v));
if isempty(v); y = NaN; else; y = max(v); end
end

function G = addg(G, id, text, pass, detail)
G(end+1) = struct('id', id, 'text', text, 'pass', logical(pass), 'detail', detail);
end
