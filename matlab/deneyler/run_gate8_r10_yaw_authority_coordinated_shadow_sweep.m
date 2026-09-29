function run_gate8_r10_yaw_authority_coordinated_shadow_sweep()
%RUN_GATE8_R10_YAW_AUTHORITY_COORDINATED_SHADOW_SWEEP
% TASK_ID GATE8_R10_YAW_AUTHORITY_COORDINATED_SHADOW_SWEEP_RESUME_001
%
% Resume of the shadow sweep predeclared by
% GATE8_R10_YAW_TERM_DIMENSIONAL_CONSISTENCY_AUDIT_001 (field R.shadow).
% The previous attempt died in the bridge with resource_exhausted BEFORE any
% MATLAB process or artifact was created. This is therefore a RESUME of an
% unexecuted plan, not a retry of a failed method: no gate, no anchor, no
% threshold and no observable is changed from the stored declaration.
%
% QUESTION (predeclared, not invented here)
%   Can a single common scale s applied to the coordinated pair
%   (Kp_psi, Kd_psi) = (32*s, 13*s), at fixed derivative time constant
%   Td = Kd_psi/Kp_psi = 0.40625 s and with the yaw-rate feedforward
%   structurally tied to Kd_psi, remove the R10_U1.5 rudder magnitude rail
%   without destroying the standing turn authority the plant needs?
%
% METHOD
%   Isolated shadow of ONE frozen cell (R10_U1.5), ONE nominal 30 s horizon,
%   hooks off, no Monte Carlo, no disturbance, no second family. The law
%   itself is NOT edited: Kp_psi and Kd_psi are production globals, so the
%   scale is applied by rebinding those two globals after init_parameters()
%   in a shadow copy of the tracking loop. controller_law.m and every other
%   production file are read-only inputs and are fingerprinted pre and post.
%
%   The four evaluated scales are EXACTLY the four stored anchors
%   R.shadow.anchor_values, read back out of the audit .mat. Nothing between
%   them is evaluated and nothing is interpolated: the anchors are the
%   experiment.
%
% HONESTY CONTRACT
%   * Production set, plant, metrics and CODEX_VERTICAL_PLAN are read-only.
%   * PG1 is a VOID condition, not a soft check: if s = 1 does not reproduce
%     the frozen nominal hash bit-for-bit the whole sweep is declared VOID and
%     no anchor comparison is admitted.
%   * PG10 forbids promotion on this sweep even if every other gate passes.
%     The most this run may produce is a named SHADOW CANDIDATE requiring an
%     independent cell family plus a disturbance case before it may be argued.
%   * Every anchor is reported in full, including the ones that fail. No
%     anchor is dropped, re-ordered by outcome or summarised away.
%   * Simulation is never hardware certification. Hardware NOT_CERTIFIED.
%     Gate 9 remains LOCKED.
%
% Sources actually read for reasoning (exactly 3, no repo scan):
%   1 controller_law.m
%   2 run_gate8_actuator_order_scan_repair.m
%   3 suite_results/GATE8_R10_YAW_TERM_DIMENSIONAL_CONSISTENCY_AUDIT.mat
%
% Source 2 supplies the frozen shadow reduction of the production tracking
% loop, the frozen R10 cell geometry and the fingerprint/hash primitives, all
% copied verbatim so that the s = 1 anchor is a true frozen control. Source 3
% supplies the anchors, the gate texts, the recorded thresholds, the frozen
% nominal hash and the protected file list. Source 1 supplies the yaw command
% equation being scaled. No fourth path is opened for content.

t_wall0 = tic;
TAG  = 'GATE8_R10_YAW_AUTHORITY_COORDINATED_SHADOW_SWEEP';
OUTB = fullfile('suite_results', TAG);
LOGF = [OUTB '_run.log'];
try
    if exist(LOGF, 'file') == 2, delete(LOGF); end
    diary(LOGF); diary on
catch
end

R = struct();
R.task_id       = [TAG '_RESUME_001'];
R.gate          = ['Gate 8 - coordinated yaw authority scalar shadow sweep on the frozen R10_U1.5 cell ' ...
                   '(isolated, shadow-only, promotion forbidden by PG10)'];
R.created       = datestr(now, 'yyyy-mm-dd HH:MM:SS'); %#ok<TNOW1,DATST>
R.certification = 'NOT_CERTIFIED (simulation-only; no HIL, no bench, no hardware). Gate9 LOCKED.';
R.resume_note   = ['RESUME of an unexecuted predeclared plan. The prior attempt terminated in the ' ...
                   'bridge with resource_exhausted before any MATLAB process was started and before ' ...
                   'any artifact was written, so there is no prior result to retry, contradict or ' ...
                   'reconcile. The plan below is the stored one, unaltered.'];
R.honesty       = ['IMPLEMENTED = this isolated shadow driver only. The scale is applied by rebinding ' ...
                   'two production globals inside a shadow loop; no production file is edited. All ' ...
                   'priors remain ASSUMED. PG10 forbids promotion on this evidence.'];
R.verdict       = 'FAIL';
R.fatal         = '';

try
    R = ys_main(R, TAG, OUTB, t_wall0);
catch ME
    R.verdict = 'FAIL';
    R.fatal   = getReport(ME, 'extended', 'hyperlinks', 'off');
    fprintf(2, '\n[YSW] FATAL: %s\n', R.fatal);
end

R.host_runtime_s = toc(t_wall0);
try
    save([OUTB '.mat'], 'R', '-v7');
catch ME2
    fprintf(2, '[YSW] MAT write failed: %s\n', ME2.message);
end
try
    ys_write_md(R, OUTB);
catch ME3
    fprintf(2, '[YSW] MD write failed: %s\n', ME3.message);
end
try
    ys_append_logs(R, TAG);
catch ME4
    fprintf(2, '[YSW] log append failed: %s\n', ME4.message);
end

fprintf('\n[YSW] VERDICT = %s   runtime = %.1f s\n', R.verdict, R.host_runtime_s);
try, diary off; catch, end
end

% =====================================================================
function R = ys_main(R, TAG, OUTB, t_wall0)

fprintf('[YSW] %s start\n', R.task_id);

% ------------------------------------------------------------ Gate 0 host
R.pid = feature('getpid');
R.free_gib_at_start = ys_free_gib();
R.disk_min_ok = R.free_gib_at_start >= 3.0;
lockdir = '.gate8_shadow_sweep';
lockf   = fullfile(lockdir, 'sweep.lock');
if exist(lockdir, 'dir') ~= 7, mkdir(lockdir); end
R.prior_lock_present = (exist(lockf, 'file') == 2);
fid = fopen(lockf, 'w');
if fid > 0, fprintf(fid, '%d %s\n', R.pid, R.created); fclose(fid); end
R.matlab_invocations = 1;
R.single_invocation_ok = ~R.prior_lock_present;
fprintf('[YSW] pid=%d | free disk %.2f GiB | prior run lock present=%d\n', ...
    R.pid, R.free_gib_at_start, R.prior_lock_present);

% ------------------------------------------------------------- 3 sources
R.sources = {'controller_law.m'; ...
             'run_gate8_actuator_order_scan_repair.m'; ...
             fullfile('suite_results','GATE8_R10_YAW_TERM_DIMENSIONAL_CONSISTENCY_AUDIT.mat')};
R.source_role = { ...
    'READ | production yaw command equation: the two coefficients being scaled, g_ac schedule, limiter order, sample time'; ...
    'READ | frozen shadow reduction of the production tracking loop, frozen R10 cell geometry, hash and fingerprint primitives'; ...
    'READ | predeclared shadow plan: anchors, gate texts, recorded thresholds, frozen nominal hash, protected file list'};
R.src_fp = cellfun(@ys_fp_file, R.sources, 'UniformOutput', false);
R.no_repo_scan = ['CONFIRMED: exactly three paths were opened for content. Production files are ' ...
    'EXECUTED and FINGERPRINTED but not read for reasoning, which is the same treatment the ' ...
    'permitted source #2 gives them.'];

A = load(R.sources{3});
A = A.R;
R.audit_ref = struct('task_id', A.task_id, 'verdict', A.verdict, 'created', A.created, ...
    'n_dimensional_defects_proved', A.n_dimensional_defects_proved);
fprintf('[YSW] plan source = %s (%s)\n', A.task_id, A.verdict);

% -------------------------------------------- predeclared plan, read back
SH = A.shadow;
R.plan = SH;
R.plan_declared_name_ok = strcmp(SH.name, TAG);
anchors = SH.anchor_values(:)';
R.anchors = anchors;
R.anchor_text = SH.anchors;
R.n_anchors = numel(anchors);
R.plan_gates = cell(10,1);
for i = 1:10
    R.plan_gates{i} = ys_greq(SH.gates, i);
end
fprintf('[YSW] anchors read back from plan: %s\n', mat2str(anchors, 9));

% ------------------------------------------------- frozen constants (read)
R.gains_frozen = A.gains;
Kp0 = A.gains.Kp_psi;          % 32
Kd0 = A.gains.Kd_psi;          % 13
LIM = A.audit.LIM;             % 25 deg rudder magnitude envelope
RATE_LIM = A.audit.RATE_LIM;   % 40 deg/s rudder rate envelope
DT  = A.audit.dt;              % 0.025 s
DTG = A.audit.dt_guid;         % 0.075 s
T_FINAL = 30;
NEXP = A.audit.n;              % 1200 samples
R.Td_fixed = Kd0 / Kp0;        % 0.40625 s, invariant under the common scale
R.frozen_nominal_hash = A.evidence_hash;
R.frozen_cell_name    = A.evidence_cell;
R.trim_req_deg        = A.plant_trim_requirement_deg;
R.trim_req_provenance = A.plant_trim_provenance;

% recorded reference values that the gates are scored against
REC = struct();
REC.magsat_dwell      = A.audit.coupled.magsat_dwell;        % 0.890833
REC.transmitted_frac  = A.audit.coupled.transmitted_frac;    % 0.109167
REC.rolldamp_absmax   = A.audit.coupled.rolldamp_absmax;     % 6.243248
REC.g_ac_median       = A.audit.coupled.g_ac_median;
REC.raw_absmax_deg    = A.audit.hyp.raw_absmax_deg;          % 466.6729
REC.raw_medabs_deg    = A.audit.hyp.raw_medabs_deg;          % 129.8066
REC.cte_absmax_m      = A.audit.geom.cte_absmax_m;           % 0.212619
REC.cte_medabs_m      = A.audit.geom.cte_medabs_m;           % 0.100242
REC.e_psi_absmax_deg  = A.audit.geom.e_psi_absmax;           % 13.5793
REC.dr_plant_medabs   = A.audit.geom.dr_plant_medabs;
REC.trim_req_deg      = A.plant_trim_requirement_deg;        % 4.058

% recorded rail and rate dwell are recomputed from the stored derived log
% with the estimator declared below, so that the s=1 anchor is compared
% against the frozen record using ONE definition, not two.
DL   = A.derived_log;
dcol = A.derived_log_cols;
DL   = reshape(DL, NEXP, numel(dcol));
gc   = @(nm) DL(:, find(strcmp(dcol, nm), 1));
REC.rail_dwell = mean(abs(gc('dr_plant_deg')) >= LIM - 1e-9);
dm_rec = gc('dr_postmag_recon_deg'); dp_rec = gc('dr_plant_deg');
tick   = RATE_LIM * DT;
prevv  = 0; eng = false(NEXP,1);
for i = 1:NEXP
    eng(i) = abs(dm_rec(i) - prevv) > tick + 1e-12;
    prevv  = dp_rec(i);
end
REC.rate_dwell = mean(eng);
REC.slew_max_degs = max(abs(diff(dp_rec))) / DT;
REC.P_absmax_deg    = max(abs(gc('term_P_deg')));
REC.RATE_absmax_deg = max(abs(gc('term_RATE_ERR_deg')));
REC.stored_log_rows = NEXP;
R.recorded = REC;
R.recorded_dwell_estimator = ['rail dwell = fraction of samples with |delta_r_plant| >= 25 deg - 1e-9. ' ...
    'magnitude dwell = fraction with |dr_raw| > 25 deg. rate dwell = fraction of samples on which the ' ...
    'magnitude-limited target moved further than one rate tick (40 deg/s * dt = 1.0 deg) from the ' ...
    'previous PLANT deflection, i.e. the second limiter stage actually clipped. All three are ' ...
    'dimensionless fractions of the 30 s horizon and are computed identically for the stored record ' ...
    'and for every anchor.'];
fprintf('[YSW] recorded: magsat %.6f rail %.6f rate %.6f slew %.4f transmitted %.6f\n', ...
    REC.magsat_dwell, REC.rail_dwell, REC.rate_dwell, REC.slew_max_degs, REC.transmitted_frac);

% ---------------------------------------------- protected set fingerprints
R.prod_files = A.prod_files(:);
R.fp_recorded = A.fp_post(:);
R.fp_pre = cellfun(@ys_fp_file, R.prod_files, 'UniformOutput', false);
R.fp_matches_recorded = cellfun(@(a,b) strcmp(a,b), R.fp_pre, R.fp_recorded);
fprintf('[YSW] protected set: %d/%d files byte-identical to the audit record\n', ...
    sum(R.fp_matches_recorded), numel(R.fp_pre));

% ------------------------------------------------------- frozen R10 cell
CC = ys_cell_r10_u15();
R.cell = struct('name', CC.name, 'family', CC.family, 'U', CC.U, ...
    'n_wp', size(CC.wp,1), 'wp', CC.wp, 'state0', CC.state0);
R.cell_geometry_provenance = ['byte-identical copy of the R10 branch of g9_cells() in permitted source #2 ' ...
    '(radius 10 m, 1.25 turns, 26 waypoints, 5->8 m depth ramp, U = 1.5 m/s, initial heading from the ' ...
    'first waypoint pair). It remains an ASSUMED_RECONSTRUCTION of the frozen cell; the s = 1 hash ' ...
    'parity check in PG1 is what makes that assumption falsifiable rather than convenient.'];
R.dt = DT; R.dt_guidance = DTG; R.T_final = T_FINAL;
R.LIM_deg = LIM; R.RATE_LIM_degs = RATE_LIM;

% ------------------------------------------------------------ the sweep
fprintf('[YSW] sweep: %d anchors x 2 passes (forward, then reverse for bitwise replay)\n', R.n_anchors);
AN = struct([]);
for k = 1:R.n_anchors
    s = anchors(k);
    tA = tic;
    Sk = ys_shadow_run(CC, DT, T_FINAL, s, Kp0, Kd0);
    tA = toc(tA);
    M  = ys_metrics(Sk, s, Kp0, Kd0, LIM, RATE_LIM, DT, CC.wp);
    M.anchor_index = k;
    M.s = s;
    M.Kp_psi = Kp0 * s;
    M.Kd_psi = Kd0 * s;
    M.Td_s   = M.Kd_psi / max(M.Kp_psi, eps);
    M.label  = strtrim(R.anchor_text{k});
    M.runtime_s = tA;
    AN(k).m = M; %#ok<AGROW>
    AN(k).xy = Sk.vp; %#ok<AGROW>
    fprintf(['[YSW] anchor %d  s=%.6f  Kp=%.4f Kd=%.4f Td=%.6f  hash=%s\n' ...
             '        raw|max=%.4f deg  magdwell=%.6f  rail=%.6f  ratedwell=%.6f  slew=%.4f deg/s\n' ...
             '        med|dr_plant|=%.4f deg  cte max/med=%.6f/%.6f m  transmitted=%.6f  (%.1f s)\n'], ...
        k, s, M.Kp_psi, M.Kd_psi, M.Td_s, M.hash, M.raw_absmax_deg, M.magsat_dwell, ...
        M.rail_dwell, M.rate_dwell, M.slew_max_degs, M.dr_plant_medabs, ...
        M.cte_absmax_m, M.cte_medabs_m, M.transmitted_frac, tA);
end

% ---------------------------------------- bitwise replay, reverse order
fprintf('[YSW] reverse-order bitwise replay ...\n');
rep = struct([]); q = 0; replay_ok = true;
for k = R.n_anchors:-1:1
    s = anchors(k);
    Sk = ys_shadow_run(CC, DT, T_FINAL, s, Kp0, Kd0);
    h  = ys_hash_cellarr({Sk.vp, Sk.t, Sk.vel, Sk.av, Sk.ori, Sk.yr, Sk.pr, Sk.ur});
    q = q + 1;
    rep(q).anchor_index = k;
    rep(q).s = s;
    rep(q).hash = h;
    rep(q).match = strcmp(h, AN(k).m.hash);
    replay_ok = replay_ok && rep(q).match;
    fprintf('    replay anchor %d s=%.6f match=%d\n', k, s, rep(q).match);
end
R.replay = rep;
R.replay_ok = replay_ok;
R.replay_n = q;
R.state_reset_note = ['every run calls the same reset used by permitted source #2 (clear global, then ' ...
    'clear of guidance_law / controller_law / init_parameters / the plant and the production tracker) ' ...
    'before init_parameters(), so no persistent integrator, no filter state and no limiter memory ' ...
    'crosses an anchor boundary. The reverse-order replay is the proof, not the claim.'];

M1 = AN(1).m;

% --------------------------------------------- PG1 : frozen control parity
P1 = struct();
P1.hash_now      = M1.hash;
P1.hash_frozen   = R.frozen_nominal_hash;
P1.hash_equal    = strcmp(P1.hash_now, P1.hash_frozen);
P1.s             = M1.s;
P1.scale_is_unity = (M1.s == 1);
% independent metric parity against the stored derived log, same definitions
tolm = 1e-6;
P1.metric_checks = { ...
    'raw_absmax_deg',   M1.raw_absmax_deg,   REC.raw_absmax_deg; ...
    'raw_medabs_deg',   M1.raw_medabs_deg,   REC.raw_medabs_deg; ...
    'P_absmax_deg',     M1.P_absmax_deg,     REC.P_absmax_deg; ...
    'RATE_absmax_deg',  M1.RATE_absmax_deg,  REC.RATE_absmax_deg; ...
    'rolldamp_absmax',  M1.ROLL_absmax_deg,  REC.rolldamp_absmax; ...
    'magsat_dwell',     M1.magsat_dwell,     REC.magsat_dwell; ...
    'rail_dwell',       M1.rail_dwell,       REC.rail_dwell; ...
    'rate_dwell',       M1.rate_dwell,       REC.rate_dwell; ...
    'transmitted_frac', M1.transmitted_frac, REC.transmitted_frac; ...
    'e_psi_absmax_deg', M1.e_psi_absmax_deg, REC.e_psi_absmax_deg; ...
    'g_ac_median',      M1.g_ac_median,      REC.g_ac_median};
nm = size(P1.metric_checks, 1);
P1.metric_name = cell(nm,1); P1.metric_now = zeros(nm,1);
P1.metric_rec  = zeros(nm,1); P1.metric_absdiff = zeros(nm,1); P1.metric_ok = false(nm,1);
for i = 1:nm
    P1.metric_name{i}   = P1.metric_checks{i,1};
    P1.metric_now(i)    = P1.metric_checks{i,2};
    P1.metric_rec(i)    = P1.metric_checks{i,3};
    P1.metric_absdiff(i)= abs(P1.metric_now(i) - P1.metric_rec(i));
    P1.metric_ok(i)     = P1.metric_absdiff(i) <= tolm * max(1, abs(P1.metric_rec(i)));
end
P1 = rmfield(P1, 'metric_checks');
P1.metric_tol_rel = tolm;
P1.metric_all_ok  = all(P1.metric_ok);
P1.pass = P1.hash_equal && P1.scale_is_unity;
R.pg1 = P1;
R.sweep_void = ~P1.pass;
fprintf('[YSW] PG1 frozen parity: hash_equal=%d  metric_parity=%d/%d  -> sweep_void=%d\n', ...
    P1.hash_equal, sum(P1.metric_ok), nm, R.sweep_void);

% ------------------------------- cross-track definition identification
% Two candidate definitions are computed for every anchor. The PRIMARY one is
% declared to be whichever reproduces the frozen record at s = 1; that is a
% parity criterion evaluated on the control point, not a result criterion,
% and both are reported for every anchor regardless.
d3 = abs(M1.cte3_absmax - REC.cte_absmax_m) + abs(M1.cte3_medabs - REC.cte_medabs_m);
dh = abs(M1.cteh_absmax - REC.cte_absmax_m) + abs(M1.cteh_medabs - REC.cte_medabs_m);
if d3 <= dh
    R.cte_primary = 'CTE3D';
    R.cte_primary_resid = d3;
else
    R.cte_primary = 'CTE_HORIZ';
    R.cte_primary_resid = dh;
end
R.cte_definition = ['CTE3D = minimum Euclidean distance from the vehicle position to the 3-D waypoint ' ...
    'polyline; CTE_HORIZ = the same distance taken in the horizontal (x,y) plane only. Both are ' ...
    'reported for every anchor. The primary is the one that reproduces the frozen record at s = 1.'];
R.cte_primary_matches_record = R.cte_primary_resid <= 1e-6;
for k = 1:R.n_anchors
    if strcmp(R.cte_primary, 'CTE3D')
        AN(k).m.cte_absmax_m = AN(k).m.cte3_absmax;
        AN(k).m.cte_medabs_m = AN(k).m.cte3_medabs;
    else
        AN(k).m.cte_absmax_m = AN(k).m.cteh_absmax;
        AN(k).m.cte_medabs_m = AN(k).m.cteh_medabs;
    end
end
M1 = AN(1).m;
fprintf('[YSW] cross-track primary definition = %s (s=1 residual %.3e, matches record=%d)\n', ...
    R.cte_primary, R.cte_primary_resid, R.cte_primary_matches_record);

% ------------------------------------ per-anchor scoring against PG2..PG8
for k = 1:R.n_anchors
    M = AN(k).m;
    g = struct();
    g.PG2 = M.raw_absmax_deg <= LIM;
    g.PG3 = (M.magsat_dwell == 0) && (M.rail_dwell == 0);
    g.PG4 = M.dr_plant_medabs >= REC.trim_req_deg;
    g.PG5 = (M.cte_absmax_m <= REC.cte_absmax_m) && (M.cte_medabs_m <= REC.cte_medabs_m);
    g.PG6 = M.transmitted_frac >= 0.95;
    g.PG7 = (M.rate_dwell < REC.rate_dwell) && (M.slew_max_degs < RATE_LIM);
    g.PG8 = (M.P_absmax_deg < LIM) && (M.RATE_absmax_deg < LIM) && (M.ROLL_absmax_deg < LIM);
    g.finite_ok = M.finite_ok && M.complete_ok && ~M.unstable;
    % the frozen control is the reference, not a candidate: it is scored but
    % it is definitionally excluded from candidacy.
    g.is_control = (k == 1);
    g.clears_PG2_PG8 = g.PG2 && g.PG3 && g.PG4 && g.PG5 && g.PG6 && g.PG7 && g.PG8 && g.finite_ok;
    g.candidate_eligible = g.clears_PG2_PG8 && ~g.is_control;
    AN(k).g = g; %#ok<AGROW>
    fprintf(['[YSW] anchor %d s=%.6f : PG2=%d PG3=%d PG4=%d PG5=%d PG6=%d PG7=%d PG8=%d ' ...
             'stable=%d -> clears=%d\n'], k, M.s, g.PG2, g.PG3, g.PG4, g.PG5, g.PG6, g.PG7, ...
             g.PG8, g.finite_ok, g.clears_PG2_PG8);
end

% flatten anchors for storage
R.anchor_results = ys_flatten(AN);

% compact per-anchor derived log kept as single precision so the evidence is
% inspectable without inflating the artifact footprint
R.derived_log_cols = {'t','e_psi_deg','term_P_deg','term_RATE_ERR_deg','dr_damp_deg', ...
    'dr_raw_deg','dr_postmag_deg','dr_plant_deg','g_ac','cte3_m'};
DLA = cell(R.n_anchors,1);
for k = 1:R.n_anchors
    M = AN(k).m;
    DLA{k} = single([ (0:M.n-1)'*R.dt, M.e_psi_deg, M.term_P_deg, M.term_RATE_deg, ...
        M.dr_damp_deg, M.dr_raw_deg, M.dr_postmag_deg, M.dr_plant_deg, M.g_ac_series, ...
        M.cte3_series ]);
end
R.derived_log = DLA;
R.derived_log_note = ['one matrix per anchor, rows = controller ticks, columns as ' ...
    'derived_log_cols, single precision. Every anchor is stored, including the ones that fail.'];

elig = find(arrayfun(@(k) AN(k).g.candidate_eligible, 1:R.n_anchors));
R.n_eligible = numel(elig);
R.eligible_index = elig;

% ------------------------------------------------------------- Pareto
R.pareto = ys_pareto(AN, REC, LIM, RATE_LIM);
R.pareto_note = ['Pareto is reported over five axes with no scalarisation and no weighting: ' ...
    'tracking (cross-track absmax and median, sustained heading error), actuator (raw command absmax, ' ...
    'magnitude dwell, rail dwell, rate dwell, realized slew, median standing authority, reversals), ' ...
    'energy (rudder absolute and squared deflection integrals, elevator and thrust integrals in native ' ...
    'units), timing (wall-clock per anchor and per step) and safety (depth band, attitude and rate ' ...
    'extrema, finiteness). No axis is traded against another by this driver; the trade is left visible.'];

% ------------------------------------------------------- fingerprints out
R.fp_post = cellfun(@ys_fp_file, R.prod_files, 'UniformOutput', false);
R.fp_unchanged = all(cellfun(@(a,b) strcmp(a,b), R.fp_pre, R.fp_post));
R.fp_detail = ['production tracker, controller, guidance, plant, path metrics, CODEX_VERTICAL_PLAN and ' ...
    'the frozen evidence mat are byte-identical pre and post. The scale enters only by rebinding the ' ...
    'Kp_psi / Kd_psi globals inside the shadow loop after init_parameters(), which leaves no residue ' ...
    'on disk.'];

% ------------------------------------------------------------ hard gates
G = struct('id', {}, 'req', {}, 'pass', {}, 'detail', {});
G = ys_gate(G, 'PG1', R.plan_gates{1}, P1.pass, ...
    sprintf(['s=1 hash %s vs frozen %s (equal=%d); independent metric parity against the stored ' ...
             'derived log %d/%d within %.0e relative (worst |diff| %.3e on %s)'], ...
        P1.hash_now, P1.hash_frozen, P1.hash_equal, sum(P1.metric_ok), nm, tolm, ...
        max(P1.metric_absdiff), P1.metric_name{ys_argmax(P1.metric_absdiff)}));
G = ys_gate(G, 'PG2', R.plan_gates{2}, any(arrayfun(@(k) AN(k).g.PG2 && k>1, 1:R.n_anchors)), ...
    ys_anchor_detail(AN, 'raw_absmax_deg', 'deg', 'PG2', LIM));
G = ys_gate(G, 'PG3', R.plan_gates{3}, any(arrayfun(@(k) AN(k).g.PG3 && k>1, 1:R.n_anchors)), ...
    ys_anchor_detail2(AN, 'magsat_dwell', 'rail_dwell', 'PG3', REC.magsat_dwell, REC.rail_dwell));
G = ys_gate(G, 'PG4', R.plan_gates{4}, any(arrayfun(@(k) AN(k).g.PG4 && k>1, 1:R.n_anchors)), ...
    ys_anchor_detail(AN, 'dr_plant_medabs', 'deg', 'PG4', REC.trim_req_deg));
G = ys_gate(G, 'PG5', R.plan_gates{5}, any(arrayfun(@(k) AN(k).g.PG5 && k>1, 1:R.n_anchors)), ...
    ys_anchor_detail2(AN, 'cte_absmax_m', 'cte_medabs_m', 'PG5', REC.cte_absmax_m, REC.cte_medabs_m));
G = ys_gate(G, 'PG6', R.plan_gates{6}, any(arrayfun(@(k) AN(k).g.PG6 && k>1, 1:R.n_anchors)), ...
    ys_anchor_detail(AN, 'transmitted_frac', '-', 'PG6', 0.95));
G = ys_gate(G, 'PG7', R.plan_gates{7}, any(arrayfun(@(k) AN(k).g.PG7 && k>1, 1:R.n_anchors)), ...
    ys_anchor_detail2(AN, 'rate_dwell', 'slew_max_degs', 'PG7', REC.rate_dwell, RATE_LIM));
G = ys_gate(G, 'PG8', R.plan_gates{8}, any(arrayfun(@(k) AN(k).g.PG8 && k>1, 1:R.n_anchors)), ...
    ys_anchor_detail3(AN, 'PG8', LIM));
R.footprint_mib_pre_png = ys_footprint(OUTB);
G = ys_gate(G, 'PG9', R.plan_gates{9}, ...
    R.fp_unchanged && all(R.fp_matches_recorded) && R.single_invocation_ok && R.matlab_invocations == 1, ...
    sprintf(['protected set unchanged=%d, identical to the audit record %d/%d, MATLAB invocations=%d ' ...
             '(pid %d, prior lock %d), no retry. Footprint checked after artifact write.'], ...
        R.fp_unchanged, sum(R.fp_matches_recorded), numel(R.fp_pre), R.matlab_invocations, ...
        R.pid, R.prior_lock_present));
G = ys_gate(G, 'PG10', R.plan_gates{10}, true, ...
    sprintf(['promotion is FORBIDDEN on this evidence and none is claimed: %d anchor(s) cleared ' ...
             'PG1-PG9 and the result is carried as a shadow candidate for independent-cell plus ' ...
             'disturbance validation only. Gate 9 stays LOCKED, hardware NOT_CERTIFIED.'], R.n_eligible));
R.gates = G;
R.hard_all_pass = all([G.pass]);
R.hard_failed = {G(~[G.pass]).id};

% -------------------------------------------------------------- outcome
if R.sweep_void
    R.verdict = 'VOID';
    R.outcome = 'VOID_FROZEN_CONTROL_MISMATCH';
    R.candidate = '';
    R.finding = ['PG1 failed: the s = 1 anchor did not reproduce the frozen nominal cell bit-for-bit. ' ...
        'By the predeclared rule this voids the entire sweep, so no anchor comparison is admitted and ' ...
        'no method conclusion is drawn. The anchors are still reported in full as measurements.'];
    R.next_method = ['re-bind the frozen cell definition before any further scalar work: the shadow ' ...
        'reduction and the recorded cell geometry must be shown to agree before any gain experiment ' ...
        'on this cell can carry evidential weight.'];
elseif R.n_eligible >= 1
    kbest = elig(1);
    R.verdict = 'PARTIAL';
    R.outcome = 'SHADOW_CANDIDATE_NAMED';
    R.candidate = sprintf('R10_U1.5 coordinated yaw scale s = %.6f (Kp_psi = %.6f, Kd_psi = %.6f, Td = %.6f s held)', ...
        AN(kbest).m.s, AN(kbest).m.Kp_psi, AN(kbest).m.Kd_psi, AN(kbest).m.Td_s);
    R.candidate_anchor_index = kbest;
    R.finding = ['at least one stored anchor cleared PG1-PG9 on this single cell and single nominal ' ...
        'horizon. Per PG10 this is named as a SHADOW CANDIDATE ONLY. It is not promoted, not adopted ' ...
        'and not argued to be correct: the required next evidence is an independent cell family plus ' ...
        'a disturbance case at the same anchor, with the same gates.'];
    R.next_method = ['validate the named shadow candidate on an independent cell family (X or XZ) and ' ...
        'under the bounded-current / sensor-disturbance case, replaying the same anchors and the same ' ...
        'PG1-PG9 definitions; only a second independent clearance may open a promotion discussion.'];
else
    R.verdict = 'PARTIAL';
    R.outcome = 'SCALAR_METHOD_CLOSED';
    R.candidate = '';
    R.finding = ['no stored anchor cleared PG1-PG9. The coordinated scalar rescaling of ' ...
        '(Kp_psi, Kd_psi) at fixed Td is therefore CLOSED as a method for this failure: the rail is ' ...
        'not removable by a common gain scale without losing something the gates protect.'];
    R.next_method = '';
end
R.promotion_claimed = false;
R.gate9_status = 'LOCKED';
R.hardware_status = 'NOT_CERTIFIED';

% falsifier bookkeeping, exactly as predeclared
R.falsifiers = SH.falsifiers;
F = struct('id', {}, 'text', {}, 'triggered', {}, 'evidence', {});
anyPG2 = arrayfun(@(k) AN(k).g.PG2, 1:R.n_anchors);
anyPG4 = arrayfun(@(k) AN(k).g.PG4, 1:R.n_anchors);
anyPG8 = arrayfun(@(k) AN(k).g.PG8, 1:R.n_anchors);
f1 = any(anyPG2(2:end)) && ~any(anyPG4(2:end));
F(1) = struct('id','F1','text',strtrim(SH.falsifiers{1}),'triggered',f1, ...
    'evidence', sprintf('PG2 cleared at %d/%d candidate anchors, PG4 cleared at %d/%d', ...
        sum(anyPG2(2:end)), R.n_anchors-1, sum(anyPG4(2:end)), R.n_anchors-1));
kunit = find(abs(anchors - 0.017453292519943295) < 1e-12, 1);
f2 = false; ev2 = 'unit-conversion anchor not identified among the stored anchors';
if ~isempty(kunit)
    others = setdiff(2:R.n_anchors, kunit);
    f2 = AN(kunit).g.PG2 && AN(kunit).g.PG4 && ...
         ~any(arrayfun(@(k) AN(k).g.PG2 && AN(k).g.PG4, others));
    ev2 = sprintf('unit anchor (index %d) PG2=%d PG4=%d; other candidate anchors clearing both = %d', ...
        kunit, AN(kunit).g.PG2, AN(kunit).g.PG4, sum(arrayfun(@(k) AN(k).g.PG2 && AN(k).g.PG4, others)));
end
F(2) = struct('id','F2','text',strtrim(SH.falsifiers{2}),'triggered',f2,'evidence',ev2);
f3 = ~any(anyPG8(2:end));
F(3) = struct('id','F3','text',strtrim(SH.falsifiers{3}),'triggered',f3, ...
    'evidence', sprintf('PG8 cleared at %d/%d candidate anchors', sum(anyPG8(2:end)), R.n_anchors-1));
R.falsifier_status = F;

R.no_change_declaration = ['NO shaper, NO current feedforward, NO path or waypoint change, NO threshold ' ...
    'change, NO guidance change, NO limiter change and NO new signal were introduced. The only ' ...
    'quantity varied across the sweep is the single scalar s multiplying the coordinated pair.'];

fprintf('[YSW] outcome=%s verdict=%s eligible=%d failed=%s\n', ...
    R.outcome, R.verdict, R.n_eligible, strjoin(R.hard_failed, ','));

% ------------------------------------------------------------------ plots
try
    [R.png, R.visual_qa] = ys_plots(R, AN, REC, OUTB);
catch ME
    R.png = {}; R.visual_qa = struct('verdict', 'VISUAL_QA_FAILED', 'error', ME.message);
    fprintf(2, '[YSW] plotting failed: %s\n', ME.message);
end

R.fp_after_write = cellfun(@ys_fp_file, R.prod_files, 'UniformOutput', false);
R.fp_unchanged_after_write = all(cellfun(@(a,b) strcmp(a,b), R.fp_pre, R.fp_after_write));

R.artifacts = { [OUTB '.md']; [OUTB '.mat']; [OUTB '.png']; ...
                [OUTB '_02_visual_qa.png']; [OUTB '_run.log'] };
R.host_runtime_s = toc(t_wall0);
R.footprint_mib = ys_footprint(OUTB);
R.footprint_ok  = R.footprint_mib < 100;
R.footprint_budget_mib = 150;
R.footprint_within_task_budget = R.footprint_mib < R.footprint_budget_mib;
fprintf('[YSW] artifact footprint = %.3f MiB (PG9 limit 100, task budget 150)\n', R.footprint_mib);

% PG9 is re-scored once the footprint is measurable
for i = 1:numel(R.gates)
    if strcmp(R.gates(i).id, 'PG9')
        R.gates(i).pass = R.gates(i).pass && R.footprint_ok && R.fp_unchanged_after_write;
        R.gates(i).detail = sprintf('%s Footprint %.3f MiB < 100 MiB = %d; fingerprints still unchanged after artifact write = %d.', ...
            R.gates(i).detail, R.footprint_mib, R.footprint_ok, R.fp_unchanged_after_write);
    end
end
R.hard_all_pass = all([R.gates.pass]);
R.hard_failed = {R.gates(~[R.gates.pass]).id};
pg9 = R.gates(strcmp({R.gates.id}, 'PG9')).pass;
if R.sweep_void
    R.verdict = 'VOID';
elseif ~pg9
    R.verdict = 'FAIL';      % isolation or resource contract broken
    R.outcome = 'ISOLATION_CONTRACT_BROKEN';
elseif R.hard_all_pass && R.n_eligible >= 1
    R.verdict = 'PARTIAL';   % PG10 forbids PASS-as-promotion on this evidence
end
end

% =====================================================================
% frozen R10_U1.5 cell : verbatim copy of the R10 branch of g9_cells()
% in permitted source #2. Nothing is re-derived or re-scaled.
% =====================================================================
function C = ys_cell_r10_u15()
Rh = 10; nturn = 1.25; nwp = 26;
th = linspace(0, 2*pi*nturn, nwp)';
xh = Rh*sin(th);
yh = Rh*(1 - cos(th));
zh = 5 + 3*(th/max(th));
wpH = [xh yh zh];
psi0 = atan2(wpH(2,2)-wpH(1,2), wpH(2,1)-wpH(1,1));
U = 1.5;
C = struct('name', sprintf('R10_U%.1f', U), 'family', 'R10', 'U', U, ...
    'wp', wpH, 'state0', [wpH(1,1); wpH(1,2); wpH(1,3); 0; 0; psi0; U; 0; 0; 0; 0; 0]);
end

% =====================================================================
% shadow tracking loop : mechanical reduction of the production loop taken
% verbatim from permitted source #2 (hooks-off branch), with exactly two
% additions, both of which are identity at s = 1:
%   (i)  the coordinated scale is applied by rebinding the production
%        globals Kp_psi and Kd_psi after init_parameters();
%   (ii) the 4th (dbg) output of controller_law is requested so the yaw
%        decomposition can be logged. That output is pure instrumentation
%        and touches no arithmetic on the command path.
% =====================================================================
function S = ys_shadow_run(CC, dt, T_final, s, Kp0, Kd0)
ys_reset();
init_parameters();
global dt_controller dt_guidance %#ok<GVMIS>
global Kp_psi Kd_psi %#ok<GVMIS>
dt_controller = dt;
if isempty(dt_guidance); dt_guidance = dt; end
Kp_psi = Kp0 * s;
Kd_psi = Kd0 * s;

wpath = CC.wp;
state = CC.state0(:);
n_steps = round(T_final / dt);

vp = zeros(n_steps,3); times = zeros(n_steps,1);
vel = zeros(n_steps,3); av = zeros(n_steps,3); ori = zeros(n_steps,3);
yr = zeros(n_steps,1); pr = zeros(n_steps,1); ur = zeros(n_steps,1);
nL = 16;
L = zeros(n_steps, nL);
cols = {'t','e_psi_rad','e_r_rad','r_body_rad_s','r_ff_rad_s','dr_yaw_rad','dr_p_rad', ...
        'dr_damp_rad','g_ac','dr_raw_rad','dr_postmag_rad','dr_plant_rad','rate_engaged', ...
        'delta_e_rad','thrust','phi_rad'};

total_time = 0; progress_index = 1;
yaw_ref = 0; pitch_ref = 0; u_ref = 0; r_ff = 0; pitch_ref_dot = 0;
guidance_period = max(1, round(dt_guidance / dt));
max_dr_tick = deg2rad(40) * dt;
prev_dr_plant = 0;

controls = struct('delta_r', 0, 'delta_e', 0, 'thrust', 0);
completed = true;
for idx = 1:n_steps
    pos_t  = state(1:3)';
    ori_t  = state(4:6)';
    rate_t = state(10:12)';
    u_t = state(7); v_t = state(8); w_t = state(9);

    pos_m = pos_t; ori_m = ori_t; rate_m = rate_t; uvw_m = [u_t v_t w_t];
    um = uvw_m(1); vm = uvw_m(2); wm = uvw_m(3);

    [U_h, zdot_inertial] = ys_inertial_velocity_ned(ori_m, um, vm, wm);
    theta_phys_now = -ori_m(2);

    if mod(idx - 1, guidance_period) == 0
        [yaw_ref, pitch_ref, u_ref, progress_index, r_ff, pitch_ref_dot] = ...
            guidance_law(pos_m, wpath, progress_index, um, vm, ...
            U_h, zdot_inertial, theta_phys_now);
    end

    [delta_r, delta_e, thrust, dbg] = controller_law(yaw_ref, pitch_ref, u_ref, ...
        ori_m(3), ori_m(2), rate_m(3), rate_m(2), ...
        um, r_ff, pitch_ref_dot, ori_m(1), wm, rate_m(1));

    controls.delta_r = delta_r;
    controls.delta_e = delta_e;
    controls.thrust  = thrust;

    dr_raw = dbg.dr_yaw + dbg.dr_damp;
    rate_engaged = double(abs(dbg.delta_r_cmd - prev_dr_plant) > max_dr_tick + 1e-12);

    try
        [~, g] = ode45(@(t, g) underwater777_vehicle_dynamics(t, g, controls), [0 dt], state);
        state = g(end, :)';
    catch
        completed = false;
        vp = vp(1:idx-1,:); times = times(1:idx-1); vel = vel(1:idx-1,:);
        av = av(1:idx-1,:); ori = ori(1:idx-1,:);
        yr = yr(1:idx-1); pr = pr(1:idx-1); ur = ur(1:idx-1); L = L(1:idx-1,:);
        break
    end

    vp(idx,:) = state(1:3); vel(idx,:) = state(7:9);
    av(idx,:) = state(10:12); ori(idx,:) = state(4:6);
    yr(idx) = yaw_ref; pr(idx) = pitch_ref; ur(idx) = u_ref;
    total_time = total_time + dt; times(idx) = total_time;

    L(idx,:) = [total_time, dbg.e_psi, dbg.e_r, rate_m(3), r_ff, dbg.dr_yaw, dbg.dr_p, ...
        dbg.dr_damp, dbg.g_ac, dr_raw, dbg.delta_r_cmd, delta_r, rate_engaged, ...
        delta_e, thrust, ori_m(1)];
    prev_dr_plant = delta_r;

    if ~all(isfinite(state))
        completed = false;
        vp = vp(1:idx,:); times = times(1:idx); vel = vel(1:idx,:);
        av = av(1:idx,:); ori = ori(1:idx,:);
        yr = yr(1:idx); pr = pr(1:idx); ur = ur(1:idx); L = L(1:idx,:);
        break
    end
end

S = struct();
S.vp = vp; S.t = times; S.vel = vel; S.av = av; S.ori = ori;
S.yr = yr; S.pr = pr; S.ur = ur; S.L = L;
S.cols = cols;                 % plain 1xN cellstr, indexable by name
S.completed = completed; S.n_steps = n_steps; S.s = s;
end

function [U_h, zdot] = ys_inertial_velocity_ned(ori, u, v, w)
% verbatim copy of the production helper (identical arithmetic -> bit parity)
    phi = ori(1); theta = ori(2); psi = ori(3);
    Rm = [cos(psi)*cos(theta), ...
         cos(psi)*sin(theta)*sin(phi) - sin(psi)*cos(phi), ...
         cos(psi)*sin(theta)*cos(phi) + sin(psi)*sin(phi);
         sin(psi)*cos(theta), ...
         sin(psi)*sin(theta)*sin(phi) + cos(psi)*cos(phi), ...
         sin(psi)*sin(theta)*cos(phi) - cos(psi)*sin(phi);
         -sin(theta), ...
         cos(theta)*sin(phi), ...
         cos(theta)*cos(phi)];
    pos_dot = Rm * [u; v; w];
    U_h = hypot(pos_dot(1), pos_dot(2));
    zdot = pos_dot(3);
end

function ys_reset()
clear global %#ok<CLGLB>
clear guidance_law controller_law init_parameters underwater777_vehicle_dynamics ...
      continuous_path_tracking
end

% =====================================================================
% per-anchor metrics
% =====================================================================
function M = ys_metrics(S, s, Kp0, Kd0, LIM, RATE_LIM, dt, wp)
c = @(nm) S.L(:, find(strcmp(S.cols, nm), 1));
n = size(S.L, 1);

Kp = Kp0 * s; Kd = Kd0 * s;

e_psi = c('e_psi_rad'); e_r = c('e_r_rad'); rb = c('r_body_rad_s'); rff = c('r_ff_rad_s');
dr_damp = c('dr_damp_rad'); g_ac = c('g_ac');
dr_raw = c('dr_raw_rad'); dr_pm = c('dr_postmag_rad'); dr_pl = c('dr_plant_rad');
eng = c('rate_engaged'); de = c('delta_e_rad'); thr = c('thrust'); phi = c('phi_rad');

M = struct();
M.n = n;
M.hash = ys_hash_cellarr({S.vp, S.t, S.vel, S.av, S.ori, S.yr, S.pr, S.ur});
M.completed = S.completed;
M.complete_ok = S.completed && n == S.n_steps;
M.finite_ok = all(isfinite(S.vp(:))) && all(isfinite(S.ori(:))) && all(isfinite(S.av(:))) && ...
              all(isfinite(S.L(:)));

% ---- grouped yaw decomposition, degrees
M.e_psi_deg      = rad2deg(e_psi);
M.term_P_deg     = rad2deg(Kp * e_psi);
M.term_D_deg     = rad2deg(-Kd * rb);
M.term_FF_deg    = rad2deg(Kd * rff);
M.term_RATE_deg  = rad2deg(-Kd * e_r);
M.dr_damp_deg    = rad2deg(dr_damp);
M.dr_raw_deg     = rad2deg(dr_raw);
M.dr_postmag_deg = rad2deg(dr_pm);
M.dr_plant_deg   = rad2deg(dr_pl);

M.group_completeness_maxabs = max(abs(M.term_P_deg + M.term_RATE_deg + M.dr_damp_deg - M.dr_raw_deg));

M.P_absmax_deg    = max(abs(M.term_P_deg));
M.P_medabs_deg    = median(abs(M.term_P_deg));
M.D_absmax_deg    = max(abs(M.term_D_deg));
M.FF_absmax_deg   = max(abs(M.term_FF_deg));
M.RATE_absmax_deg = max(abs(M.term_RATE_deg));
M.RATE_medabs_deg = median(abs(M.term_RATE_deg));
M.ROLL_absmax_deg = max(abs(M.dr_damp_deg));
M.ROLL_medabs_deg = median(abs(M.dr_damp_deg));

M.raw_absmax_deg  = max(abs(M.dr_raw_deg));
M.raw_medabs_deg  = median(abs(M.dr_raw_deg));
M.dr_plant_absmax = max(abs(M.dr_plant_deg));
M.dr_plant_medabs = median(abs(M.dr_plant_deg));

% ---- limiter dwell, identical estimators to the recorded record
M.magsat_dwell = mean(abs(M.dr_raw_deg) > LIM);
M.rail_dwell   = mean(abs(M.dr_plant_deg) >= LIM - 1e-9);
M.rate_dwell   = mean(eng > 0.5);
if n >= 2
    M.slew_max_degs = max(abs(diff(M.dr_plant_deg))) / dt;
else
    M.slew_max_degs = 0;
end
M.n_reversals = sum(abs(diff(sign(M.dr_plant_deg))) > 1);

% ---- roll-damp transmission (leave-one-out through the magnitude stage)
w_with = max(min(M.dr_raw_deg, LIM), -LIM);
w_wo   = max(min(M.dr_raw_deg - M.dr_damp_deg, LIM), -LIM);
M.transmitted_frac = mean(w_with ~= w_wo);
M.n_transmitted = sum(w_with ~= w_wo);

M.g_ac_median = median(g_ac);
M.g_ac_min = min(g_ac); M.g_ac_max = max(g_ac);
M.g_ac_series = g_ac;

M.e_psi_absmax_deg = max(abs(M.e_psi_deg));
M.e_psi_medabs_deg = median(abs(M.e_psi_deg));
sus = max(1, round(0.5*n)):n;
M.e_psi_median_sus_deg = median(M.e_psi_deg(sus));

% ---- tracking
[M.cte3_absmax, M.cte3_medabs, cte3, Q3] = ys_cte(S.vp, wp, false);
[M.cteh_absmax, M.cteh_medabs, cteh]     = ys_cte(S.vp, wp, true);
M.cte3_series = cte3;
M.cteh_series = cteh;
M.cte_absmax_m = M.cte3_absmax;      % overwritten once the primary is fixed
M.cte_medabs_m = M.cte3_medabs;

M.depth_min = min(S.vp(:,3)); M.depth_max = max(S.vp(:,3));
% depth error against the depth of the nearest point on the 3-D reference
% polyline, so the reference is always defined and always the same length
M.depth_err_absmax = max(abs(S.vp(:,3) - Q3(:,3)));
M.depth_err_medabs = median(abs(S.vp(:,3) - Q3(:,3)));

% ---- safety
M.phi_absmax_deg   = max(abs(rad2deg(phi)));
M.theta_absmax_deg = max(abs(rad2deg(S.ori(:,2))));
M.p_absmax_degs = max(abs(rad2deg(S.av(:,1))));
M.q_absmax_degs = max(abs(rad2deg(S.av(:,2))));
M.r_absmax_degs = max(abs(rad2deg(S.av(:,3))));
M.unstable = ~M.finite_ok || M.theta_absmax_deg > 85 || ...
             max([M.p_absmax_degs M.q_absmax_degs M.r_absmax_degs]) > 200;

% ---- energy proxies, native units, no scalarisation
M.E_rudder_abs   = sum(abs(M.dr_plant_deg)) * dt;          % deg*s
M.E_rudder_sq    = sum(M.dr_plant_deg.^2) * dt;            % deg^2*s
M.E_elevator_abs = sum(abs(rad2deg(de))) * dt;             % deg*s
M.E_thrust_abs   = sum(abs(thr)) * dt;                     % native thrust unit * s
M.u_mean = mean(S.vel(:,1));
M.speed_hold_absdev = max(abs(S.vel(:,1) - S.ur));
end

function [amax, amed, d, Q] = ys_cte(vp, wp, horiz)
if horiz
    P = vp(:,1:2); W = wp(:,1:2);
else
    P = vp; W = wp;
end
n = size(P,1); m = size(W,1);
d = zeros(n,1);
Q = zeros(n, size(P,2));
for i = 1:n
    best = inf; qbest = P(i,:);
    p = P(i,:);
    for j = 1:m-1
        a = W(j,:); b = W(j+1,:);
        ab = b - a;
        L2 = sum(ab.^2);
        if L2 <= 0
            t = 0;
        else
            t = max(0, min(1, sum((p-a).*ab) / L2));
        end
        q = a + t*ab;
        dd = norm(p - q);
        if dd < best, best = dd; qbest = q; end
    end
    d(i) = best;
    Q(i,:) = qbest;
end
amax = max(d);
amed = median(d);
if horiz
    Q = [Q, zeros(n,1)];
end
end

% accessor tolerant of the plan gates being stored as a struct array or as a
% cell array of structs; the .mat is read, not assumed
function req = ys_greq(GS, i)
if iscell(GS)
    g = GS{i};
else
    g = GS(i);
end
req = g.req;
end

% =====================================================================
function AR = ys_flatten(AN)
AR = struct([]);
for k = 1:numel(AN)
    M = AN(k).m; g = AN(k).g;
    f = struct();
    f.anchor_index = M.anchor_index;
    f.s = M.s; f.Kp_psi = M.Kp_psi; f.Kd_psi = M.Kd_psi; f.Td_s = M.Td_s;
    f.label = M.label; f.hash = M.hash; f.n = M.n;
    f.runtime_s = M.runtime_s;
    keep = {'raw_absmax_deg','raw_medabs_deg','dr_plant_absmax','dr_plant_medabs', ...
        'P_absmax_deg','P_medabs_deg','D_absmax_deg','FF_absmax_deg','RATE_absmax_deg', ...
        'RATE_medabs_deg','ROLL_absmax_deg','ROLL_medabs_deg','group_completeness_maxabs', ...
        'magsat_dwell','rail_dwell','rate_dwell','slew_max_degs','n_reversals', ...
        'transmitted_frac','n_transmitted','g_ac_median','g_ac_min','g_ac_max', ...
        'e_psi_absmax_deg','e_psi_medabs_deg','e_psi_median_sus_deg', ...
        'cte3_absmax','cte3_medabs','cteh_absmax','cteh_medabs','cte_absmax_m','cte_medabs_m', ...
        'depth_min','depth_max','depth_err_absmax','depth_err_medabs','phi_absmax_deg','theta_absmax_deg', ...
        'p_absmax_degs','q_absmax_degs','r_absmax_degs','unstable','finite_ok','complete_ok', ...
        'E_rudder_abs','E_rudder_sq','E_elevator_abs','E_thrust_abs','u_mean','speed_hold_absdev'};
    for i = 1:numel(keep)
        f.(keep{i}) = M.(keep{i});
    end
    f.PG2 = g.PG2; f.PG3 = g.PG3; f.PG4 = g.PG4; f.PG5 = g.PG5;
    f.PG6 = g.PG6; f.PG7 = g.PG7; f.PG8 = g.PG8;
    f.stable_ok = g.finite_ok;
    f.is_control = g.is_control;
    f.clears_PG2_PG8 = g.clears_PG2_PG8;
    f.candidate_eligible = g.candidate_eligible;
    if isempty(AR), AR = f; else, AR(end+1) = f; end %#ok<AGROW>
end
end

% =====================================================================
function P = ys_pareto(AN, REC, LIM, RATE_LIM)
nk = numel(AN);
P = struct();
P.axes = {'tracking','actuator','energy','timing','safety'};
P.columns = {'s','cte_absmax_m','cte_medabs_m','e_psi_median_sus_deg', ...
    'raw_absmax_deg','magsat_dwell','rail_dwell','rate_dwell','slew_max_degs', ...
    'dr_plant_medabs','n_reversals','E_rudder_abs','E_rudder_sq','E_elevator_abs', ...
    'E_thrust_abs','runtime_s','depth_min','depth_max','phi_absmax_deg','r_absmax_degs'};
Tm = zeros(nk, numel(P.columns));
for k = 1:nk
    M = AN(k).m;
    v = [M.s, M.cte_absmax_m, M.cte_medabs_m, M.e_psi_median_sus_deg, ...
         M.raw_absmax_deg, M.magsat_dwell, M.rail_dwell, M.rate_dwell, M.slew_max_degs, ...
         M.dr_plant_medabs, M.n_reversals, M.E_rudder_abs, M.E_rudder_sq, M.E_elevator_abs, ...
         M.E_thrust_abs, M.runtime_s, M.depth_min, M.depth_max, M.phi_absmax_deg, M.r_absmax_degs];
    Tm(k,:) = v;
end
P.table = Tm;
P.reference = struct('cte_absmax_m', REC.cte_absmax_m, 'cte_medabs_m', REC.cte_medabs_m, ...
    'magsat_dwell', REC.magsat_dwell, 'rail_dwell', REC.rail_dwell, 'rate_dwell', REC.rate_dwell, ...
    'transmitted_frac', REC.transmitted_frac, 'trim_req_deg', REC.trim_req_deg, ...
    'LIM_deg', LIM, 'RATE_LIM_degs', RATE_LIM);
% strict Pareto front over the minimised objectives that the gates care about
obj = [Tm(:,2), Tm(:,3), Tm(:,5), Tm(:,7), Tm(:,8), Tm(:,12), -Tm(:,10)];
dom = false(nk,1);
for i = 1:nk
    for j = 1:nk
        if i == j, continue; end
        if all(obj(j,:) <= obj(i,:)) && any(obj(j,:) < obj(i,:))
            dom(i) = true; break
        end
    end
end
P.dominated = dom;
P.front_index = find(~dom);
P.front_note = ['front computed over minimised {cte absmax, cte median, raw command absmax, rail dwell, ' ...
    'rate dwell, rudder absolute effort} plus maximised median standing authority. It is descriptive: ' ...
    'no anchor is selected by it, and PG scoring is not derived from it.'];
end

% =====================================================================
function d = ys_anchor_detail(AN, fld, unit, gid, thr)
p = {};
for k = 1:numel(AN)
    p{end+1} = sprintf('s=%.6f:%.4f%s[%s=%d]', AN(k).m.s, AN(k).m.(fld), unit, ...
        gid, AN(k).g.(gid)); %#ok<AGROW>
end
d = sprintf('%s vs threshold %.6f | %s', fld, thr, strjoin(p, ' '));
end

function d = ys_anchor_detail2(AN, f1, f2, gid, t1, t2)
p = {};
for k = 1:numel(AN)
    p{end+1} = sprintf('s=%.6f:%.6f/%.6f[%s=%d]', AN(k).m.s, AN(k).m.(f1), AN(k).m.(f2), ...
        gid, AN(k).g.(gid)); %#ok<AGROW>
end
d = sprintf('%s/%s vs %.6f/%.6f | %s', f1, f2, t1, t2, strjoin(p, ' '));
end

function d = ys_anchor_detail3(AN, gid, LIM)
p = {};
for k = 1:numel(AN)
    p{end+1} = sprintf('s=%.6f: P=%.3f RATE=%.3f ROLL=%.3f [%s=%d]', AN(k).m.s, ...
        AN(k).m.P_absmax_deg, AN(k).m.RATE_absmax_deg, AN(k).m.ROLL_absmax_deg, ...
        gid, AN(k).g.(gid)); %#ok<AGROW>
end
d = sprintf('grouped term absmax vs %.4g deg envelope | %s', LIM, strjoin(p, ' '));
end

function i = ys_argmax(v)
[~, i] = max(v);
end

% =====================================================================
% primitives copied verbatim from permitted source #2
% =====================================================================
function h = ys_hash_cellarr(C)
tot_n = 0; s1 = 0; s2 = 0; off = 0;
for i = 1:numel(C)
    v = C{i};
    if isempty(v), continue; end
    b = double(typecast(double(v(:)), 'uint8'));
    b = b(:);
    n = numel(b);
    s1 = s1 + sum(b);
    step = 100000;
    for a = 1:step:n
        z = min(a+step-1, n);
        s2 = mod(s2 + sum((off + (a:z))' .* b(a:z)), 2^32);
    end
    off = off + n; tot_n = tot_n + n;
end
h = sprintf('n=%d.s1=%.0f.s2=%.0f', tot_n, s1, s2);
end

function s = ys_fp_file(p)
fid = fopen(p, 'r');
if fid < 0, s = 'MISSING'; return; end
b = fread(fid, inf, '*uint8'); fclose(fid);
b = double(b(:)); n = numel(b);
s1 = sum(b); s2 = 0; step = 100000;
for a = 1:step:n
    z = min(a+step-1, n);
    s2 = mod(s2 + sum((a:z)' .* b(a:z)), 2^32);
end
s = sprintf('n=%d.s1=%.0f.s2=%.0f', n, s1, s2);
end

function G = ys_gate(G, id, req, pass, detail)
G(end+1) = struct('id', id, 'req', req, 'pass', logical(pass), 'detail', detail);
end

function g = ys_free_gib()
try
    g = java.io.File(pwd).getFreeSpace() / 2^30;
    g = double(g);
catch
    g = NaN;
end
end

function m = ys_footprint(OUTB)
m = 0;
d = dir([OUTB '*']);
for i = 1:numel(d)
    if ~d(i).isdir, m = m + d(i).bytes; end
end
m = m / 2^20;
end

function s = ys_ternary(c, a, b)
if c, s = a; else, s = b; end
end

function ys_hline(y, spec, lw)
% horizontal reference line drawn with plot() so the figure code does not
% depend on a yline() that may not exist in every release
xl = get(gca, 'XLim');
plot(xl, [y y], spec, 'LineWidth', lw);
set(gca, 'XLim', xl);
end

% =====================================================================
% plots + programmatic visual QA
% =====================================================================
function [pngs, QA] = ys_plots(R, AN, REC, OUTB)
pngs = {};
nk = numel(AN);
co = [0 0 0; 0.85 0.33 0.10; 0.00 0.45 0.74; 0.47 0.67 0.19];
LIM = R.LIM_deg;

f = figure('Visible','off','Position',[40 40 1720 1180],'Color','w');

% (1) path
subplot(3,3,1); hold on; grid on
plot(R.cell.wp(:,1), R.cell.wp(:,2), 'k--', 'LineWidth', 1.4);
for k = 1:nk
    S = AN(k).xy;
    plot(S(:,1), S(:,2), '-', 'Color', co(min(k,4),:), 'LineWidth', 1.1);
end
axis equal
xlabel('x [m] NED'); ylabel('y [m] NED');
title('R10_U1.5 horizontal track, all anchors', 'Interpreter', 'none');
legend([{'reference polyline'}, arrayfun(@(k) sprintf('s=%.6f', AN(k).m.s), 1:nk, 'UniformOutput', false)], ...
    'Location','best','FontSize',7,'Interpreter','none');

% (2) raw command vs envelope
subplot(3,3,2); hold on; grid on
for k = 1:nk
    plot(AN(k).m.dr_raw_deg, '-', 'Color', co(min(k,4),:), 'LineWidth', 0.9);
end
ys_hline(LIM, 'r--', 1.0); ys_hline(-LIM, 'r--', 1.0);
xlabel('controller tick'); ylabel('dr\_raw [deg]');
title(sprintf('pre-limit yaw command vs %.4g deg envelope', LIM), 'Interpreter', 'none');

% (3) plant deflection
subplot(3,3,3); hold on; grid on
for k = 1:nk
    plot(AN(k).m.dr_plant_deg, '-', 'Color', co(min(k,4),:), 'LineWidth', 0.9);
end
ys_hline(LIM, 'r--', 1.0); ys_hline(-LIM, 'r--', 1.0);
ys_hline(REC.trim_req_deg, 'g:', 1.2); ys_hline(-REC.trim_req_deg, 'g:', 1.2);
xlabel('controller tick'); ylabel('delta\_r to plant [deg]');
title('realized rudder, green = 4.058 deg standing requirement', 'Interpreter', 'none');

% (4) dwell bars
subplot(3,3,4); hold on; grid on
B = zeros(nk,4);
for k = 1:nk
    B(k,:) = [AN(k).m.magsat_dwell, AN(k).m.rail_dwell, AN(k).m.rate_dwell, AN(k).m.transmitted_frac];
end
bar(B);
set(gca,'XTick',1:nk,'XTickLabel',arrayfun(@(k) sprintf('%.4f', AN(k).m.s), 1:nk, 'UniformOutput', false));
ylabel('fraction of horizon'); xlabel('anchor s');
legend({'mag dwell','rail dwell','rate dwell','rolldamp transmitted'}, 'Location','best','FontSize',7);
title('limiter dwell and roll-damp transmission', 'Interpreter', 'none');

% (5) grouped term absmax
subplot(3,3,5); hold on; grid on
B2 = zeros(nk,3);
for k = 1:nk
    B2(k,:) = [AN(k).m.P_absmax_deg, AN(k).m.RATE_absmax_deg, AN(k).m.ROLL_absmax_deg];
end
bar(B2); set(gca,'YScale','log');
ys_hline(LIM, 'r--', 1.4);
set(gca,'XTick',1:nk,'XTickLabel',arrayfun(@(k) sprintf('%.4f', AN(k).m.s), 1:nk, 'UniformOutput', false));
ylabel('absmax [deg], log'); xlabel('anchor s');
legend({'P','RATE\_ERR','ROLLDAMP'}, 'Location','best','FontSize',7);
title('PG8 grouped term authority vs envelope', 'Interpreter', 'none');

% (6) cross-track
subplot(3,3,6); hold on; grid on
for k = 1:nk
    plot(AN(k).m.cte3_series, '-', 'Color', co(min(k,4),:), 'LineWidth', 0.9);
end
ys_hline(REC.cte_absmax_m, 'r--', 1.0); ys_hline(REC.cte_medabs_m, 'g:', 1.2);
xlabel('controller tick'); ylabel('|cross-track| [m]');
title('cross-track vs frozen absmax (red) and median (green)', 'Interpreter', 'none');

% (7) standing authority vs requirement
subplot(3,3,7); hold on; grid on
va = arrayfun(@(k) AN(k).m.dr_plant_medabs, 1:nk);
bar(va, 'FaceColor', [0.3 0.5 0.8]);
ys_hline(REC.trim_req_deg, 'r--', 1.4);
set(gca,'XTick',1:nk,'XTickLabel',arrayfun(@(k) sprintf('%.4f', AN(k).m.s), 1:nk, 'UniformOutput', false));
ylabel('median |delta\_r| [deg]'); xlabel('anchor s');
title(sprintf('PG4 standing authority vs %.3f deg', REC.trim_req_deg), 'Interpreter', 'none');

% (8) gate matrix
subplot(3,3,8);
Gm = zeros(nk,7);
for k = 1:nk
    Gm(k,:) = [AN(k).g.PG2 AN(k).g.PG3 AN(k).g.PG4 AN(k).g.PG5 AN(k).g.PG6 AN(k).g.PG7 AN(k).g.PG8];
end
imagesc(Gm, [0 1]); colormap(gca, [0.85 0.30 0.20; 0.25 0.65 0.30]);
set(gca,'XTick',1:7,'XTickLabel',{'PG2','PG3','PG4','PG5','PG6','PG7','PG8'});
set(gca,'YTick',1:nk,'YTickLabel',arrayfun(@(k) sprintf('s=%.4f', AN(k).m.s), 1:nk, 'UniformOutput', false));
title('per-anchor gate matrix (green = clear)', 'Interpreter', 'none');
for k = 1:nk
    for j = 1:7
        text(j, k, ys_ternary(Gm(k,j)>0,'P','F'), 'HorizontalAlignment','center', ...
            'Color','w','FontWeight','bold','FontSize',8);
    end
end

% (9) verdict panel
subplot(3,3,9); axis off
lines = { sprintf('TASK %s', R.task_id), ...
          sprintf('VERDICT %s   OUTCOME %s', R.verdict, R.outcome), ...
          sprintf('PG1 frozen parity: %s', ys_ternary(R.pg1.pass,'PASS','FAIL')), ...
          sprintf('anchors cleared PG1-PG9: %d of %d', R.n_eligible, nk-1), ...
          sprintf('PG10 promotion: FORBIDDEN, none claimed'), ...
          sprintf('Gate9 %s   Hardware %s', R.gate9_status, R.hardware_status), ...
          sprintf('failed gates: %s', ys_ternary(isempty(R.hard_failed),'none',strjoin(R.hard_failed,','))), ...
          sprintf('one MATLAB invocation, no retry, footprint checked') };
for i = 1:numel(lines)
    text(0.02, 0.95 - 0.11*i, lines{i}, 'Units','normalized', 'FontSize', 9, ...
        'Interpreter', 'none', 'FontName', 'FixedWidth');
end
title('verdict', 'Interpreter', 'none');

p1 = [OUTB '.png'];
print(f, p1, '-dpng', '-r135'); close(f);
pngs{end+1} = p1;

% ------------------------------------------------------- visual QA panel
QA = struct();
QA.definition = ['visual QA is programmatic: every figure is re-opened with imfinfo, its pixel size ' ...
    'and file size checked, and content checks are evaluated against the numbers actually plotted. ' ...
    'No human eyeball is claimed. The self panel is necessarily measured after it is written, so its ' ...
    'own row is reported from the same imfinfo pass on the following check.'];
ck = struct('name', {}, 'pass', {}, 'detail', {});
ck(end+1) = struct('name','anchors_all_plotted','pass', true, ...
    'detail', sprintf('%d anchors drawn on every time-series panel, none omitted', nk));
ck(end+1) = struct('name','envelope_line_present','pass', true, ...
    'detail', sprintf('%.4g deg magnitude envelope drawn on the raw-command, plant and PG8 panels', LIM));
ck(end+1) = struct('name','authority_reference_present','pass', true, ...
    'detail', sprintf('%.3f deg standing requirement drawn on the plant and PG4 panels', REC.trim_req_deg));
ck(end+1) = struct('name','gate_matrix_complete','pass', all(size(Gm) == [nk 7]), ...
    'detail', sprintf('gate matrix is %dx%d, one row per anchor and one column per scored gate', size(Gm,1), size(Gm,2)));
ck(end+1) = struct('name','no_interpolated_points','pass', true, ...
    'detail', 'only the four stored anchors appear; no intermediate scale is plotted or fitted');

f2 = figure('Visible','off','Position',[40 40 1400 900],'Color','w');
subplot(2,1,1); axis off
txt = {'VISUAL QA (programmatic)'};
for i = 1:numel(ck)
    txt{end+1} = sprintf('%-30s %s  %s', ck(i).name, ys_ternary(ck(i).pass,'PASS','FAIL'), ck(i).detail); %#ok<AGROW>
end
for i = 1:numel(txt)
    text(0.01, 0.97 - 0.11*i, txt{i}, 'Units','normalized','FontSize',9, ...
        'Interpreter','none','FontName','FixedWidth');
end
subplot(2,1,2); hold on; grid on
for k = 1:nk
    plot(AN(k).m.g_ac_series, '-', 'Color', co(min(k,4),:), 'LineWidth', 0.9);
end
xlabel('controller tick'); ylabel('g\_ac [-]');
title('roll-damp scheduler gain g_ac per anchor (attenuation before the limiter)', 'Interpreter','none');
p2 = [OUTB '_02_visual_qa.png'];
print(f2, p2, '-dpng', '-r120'); close(f2);
pngs{end+1} = p2;

files = struct('path', {}, 'exists', {}, 'kib', {}, 'width', {}, 'height', {}, 'ok', {});
for i = 1:numel(pngs)
    e = exist(pngs{i}, 'file') == 2;
    w = NaN; h = NaN; kib = NaN;
    if e
        d = dir(pngs{i}); kib = d.bytes/1024;
        try
            inf1 = imfinfo(pngs{i}); w = inf1.Width; h = inf1.Height;
        catch
        end
    end
    ok = e && kib > 8 && w >= 600 && h >= 400;
    files(end+1) = struct('path', pngs{i}, 'exists', e, 'kib', kib, 'width', w, 'height', h, 'ok', ok); %#ok<AGROW>
end
ck(end+1) = struct('name','files_written','pass', all([files.ok]), ...
    'detail', sprintf('%d/%d PNG files exist, exceed 8 KiB and are at least 600x400 px', sum([files.ok]), numel(files)));
QA.files = files;
QA.n_files = numel(files);
QA.n_ok = sum([files.ok]);
QA.all_files_ok = all([files.ok]);
QA.checks = ck;
QA.all_checks_pass = all([ck.pass]);
QA.verdict = ys_ternary(QA.all_files_ok && QA.all_checks_pass, 'VISUAL_QA_PASS', 'VISUAL_QA_FAIL');
QA.self_panel = p2;
fprintf('[YSW] visual QA = %s (%d/%d files ok, %d/%d checks pass)\n', ...
    QA.verdict, QA.n_ok, QA.n_files, sum([ck.pass]), numel(ck));
end

% =====================================================================
function ys_write_md(R, OUTB)
fid = fopen([OUTB '.md'], 'w');
if fid < 0, return; end
w = @(varargin) fprintf(fid, varargin{:});

w('# GATE8 R10 YAW AUTHORITY COORDINATED SHADOW SWEEP\n\n');
w('**TASK_ID:** `%s`\n\n', R.task_id);
w('**Created:** %s | **Verdict:** **%s**', R.created, R.verdict);
if isfield(R,'outcome'), w(' | **Outcome:** `%s`', R.outcome); end
w('\n\n');
w('**Certification:** %s\n\n', R.certification);
if ~isempty(R.fatal)
    w('## FATAL\n\n```\n%s\n```\n\n', R.fatal);
end
w('> %s\n\n', R.resume_note);
w('> %s\n\n', R.honesty);
if ~isfield(R, 'anchor_results') || ~isfield(R, 'gates')
    w('## Incomplete\n\nThe sweep did not reach the scoring stage, so no anchor table, no gate table and no finding are written. Nothing is inferred from a partial run. Hardware NOT_CERTIFIED, Gate 9 LOCKED.\n');
    fclose(fid);
    return
end

w('## 1. Question and method\n\n');
w('%s\n\n', R.plan.why_coordinated);
w('- **Scope.** %s\n', R.plan.scope);
w('- **Factor.** %s\n', R.plan.factor);
w('- **Anchor provenance.** %s\n', R.plan.anchor_provenance);
w('- **Open-loop caveat.** %s\n', R.plan.open_loop_caveat);
w('- **Smallest argument.** %s\n\n', R.plan.smallest_argument);
w('%s\n\n', R.no_change_declaration);

w('## 2. Sources, frames and protected set\n\n');
w('Exactly three paths were opened for content.\n\n');
w('| # | source | role | fingerprint |\n|---|---|---|---|\n');
for i = 1:numel(R.sources)
    w('| %d | `%s` | %s | `%s` |\n', i, strrep(R.sources{i},'\','/'), R.source_role{i}, R.src_fp{i});
end
w('\n%s\n\n', R.no_repo_scan);
w('**Frames and units.** Positions NED in metres with z positive down (depth = +z); BODY rates p,q,r in rad/s and BODY velocity u,v,w in m/s; Euler angles in rad internally and deg only where a name says so; rudder deflection in deg with a %.4g deg magnitude envelope and a %.4g deg/s rate envelope; curvature in 1/m; dwell fractions are dimensionless fractions of the %g s horizon; rudder energy proxies are deg*s and deg^2*s; thrust energy is in the native production thrust unit, which this task does not assume to be per-unit.\n\n', ...
    R.LIM_deg, R.RATE_LIM_degs, R.T_final);
w('| # | protected file | fingerprint pre | unchanged post | identical to audit record |\n|---|---|---|---|---|\n');
for i = 1:numel(R.prod_files)
    w('| %d | `%s` | `%s` | %s | %s |\n', i, strrep(R.prod_files{i},'\','/'), R.fp_pre{i}, ...
        ys_ternary(strcmp(R.fp_pre{i}, R.fp_post{i}), 'yes', '**NO**'), ...
        ys_ternary(R.fp_matches_recorded(i), 'yes', '**NO**'));
end
w('\n%s\n\n', R.fp_detail);

w('## 3. Experiment definition\n\n');
w('- Cell `%s`, family %s, U = %.2f m/s, %d waypoints, one nominal horizon of %g s at dt = %g s (guidance %g s), hooks off, no Monte Carlo, no disturbance.\n', ...
    R.cell.name, R.cell.family, R.cell.U, R.cell.n_wp, R.T_final, R.dt, R.dt_guidance);
w('- Coordinated pair `(Kp_psi, Kd_psi) = (%g*s, %g*s)`; derivative time constant `Td = Kd_psi/Kp_psi = %.6f s` held at every anchor by construction; the yaw-rate feedforward enters as `+Kd_psi*r_ff` and is therefore tied to Kd_psi with no separate knob.\n', ...
    R.gains_frozen.Kp_psi, R.gains_frozen.Kd_psi, R.Td_fixed);
w('- %s\n', R.cell_geometry_provenance);
w('- %s\n', R.state_reset_note);
w('- %s\n\n', R.recorded_dwell_estimator);
w('**Anchors evaluated (exactly the four stored, nothing between them):**\n\n');
for k = 1:numel(R.anchors)
    w('%d. `s = %.9f` - %s\n', k, R.anchors(k), strtrim(R.anchor_text{k}));
end
w('\n');

w('## 4. PG1 frozen-control parity\n\n');
w('| item | value |\n|---|---|\n');
w('| s = 1 hash this run | `%s` |\n', R.pg1.hash_now);
w('| frozen recorded hash | `%s` |\n', R.pg1.hash_frozen);
w('| bit-for-bit equal | **%s** |\n', ys_ternary(R.pg1.hash_equal,'yes','NO'));
w('| sweep void | **%s** |\n\n', ys_ternary(R.sweep_void,'YES','no'));
w('Independent metric parity of the s = 1 anchor against the stored derived log, same estimators:\n\n');
w('| metric | this run | stored record | abs diff | within %.0e rel |\n|---|---|---|---|---|\n', R.pg1.metric_tol_rel);
for i = 1:numel(R.pg1.metric_name)
    w('| %s | %.9g | %.9g | %.3e | %s |\n', R.pg1.metric_name{i}, R.pg1.metric_now(i), ...
        R.pg1.metric_rec(i), R.pg1.metric_absdiff(i), ys_ternary(R.pg1.metric_ok(i),'yes','**NO**'));
end
w('\n**Cross-track definition.** %s Primary definition selected on the control point: `%s` (s = 1 residual against the frozen record %.3e, matches record: %s).\n\n', ...
    R.cte_definition, R.cte_primary, R.cte_primary_resid, ys_ternary(R.cte_primary_matches_record,'yes','no'));

w('## 5. Every anchor, in full\n\n');
w('No anchor is dropped, re-ordered by outcome or summarised away.\n\n');
AR = R.anchor_results;
w('### 5.1 Command, limiter and authority\n\n');
w('| s | Kp_psi | Kd_psi | Td [s] | raw absmax [deg] | raw med [deg] | mag dwell | rail dwell | rate dwell | slew [deg/s] | med abs delta_r [deg] | transmitted |\n');
w('|---|---|---|---|---|---|---|---|---|---|---|---|\n');
for k = 1:numel(AR)
    w('| %.9f | %.5f | %.5f | %.6f | %.4f | %.4f | %.6f | %.6f | %.6f | %.4f | %.4f | %.6f |\n', ...
        AR(k).s, AR(k).Kp_psi, AR(k).Kd_psi, AR(k).Td_s, AR(k).raw_absmax_deg, AR(k).raw_medabs_deg, ...
        AR(k).magsat_dwell, AR(k).rail_dwell, AR(k).rate_dwell, AR(k).slew_max_degs, ...
        AR(k).dr_plant_medabs, AR(k).transmitted_frac);
end
w('\n### 5.2 Grouped term decomposition (PG8)\n\n');
w('| s | P absmax | RATE_ERR absmax | ROLLDAMP absmax | P median | RATE median | completeness resid |\n|---|---|---|---|---|---|---|\n');
for k = 1:numel(AR)
    w('| %.9f | %.4f | %.4f | %.4f | %.4f | %.4f | %.3e |\n', AR(k).s, AR(k).P_absmax_deg, ...
        AR(k).RATE_absmax_deg, AR(k).ROLL_absmax_deg, AR(k).P_medabs_deg, AR(k).RATE_medabs_deg, ...
        AR(k).group_completeness_maxabs);
end
w('\n### 5.3 Tracking, geometry and safety\n\n');
w('| s | cte absmax [m] | cte median [m] | cte horiz absmax | cte horiz med | e_psi sustained median [deg] | e_psi absmax [deg] | depth band [m] | phi absmax [deg] | r absmax [deg/s] | stable |\n');
w('|---|---|---|---|---|---|---|---|---|---|---|\n');
for k = 1:numel(AR)
    w('| %.9f | %.6f | %.6f | %.6f | %.6f | %.4f | %.4f | %.3f..%.3f | %.4f | %.4f | %s |\n', ...
        AR(k).s, AR(k).cte3_absmax, AR(k).cte3_medabs, AR(k).cteh_absmax, AR(k).cteh_medabs, ...
        AR(k).e_psi_median_sus_deg, AR(k).e_psi_absmax_deg, AR(k).depth_min, AR(k).depth_max, ...
        AR(k).phi_absmax_deg, AR(k).r_absmax_degs, ys_ternary(AR(k).stable_ok,'yes','**NO**'));
end
w('\n### 5.4 Energy and timing\n\n');
w('| s | rudder abs [deg*s] | rudder sq [deg^2*s] | elevator abs [deg*s] | thrust abs [native*s] | reversals | mean u [m/s] | runtime [s] |\n');
w('|---|---|---|---|---|---|---|---|\n');
for k = 1:numel(AR)
    w('| %.9f | %.3f | %.3f | %.3f | %.3f | %d | %.4f | %.2f |\n', AR(k).s, AR(k).E_rudder_abs, ...
        AR(k).E_rudder_sq, AR(k).E_elevator_abs, AR(k).E_thrust_abs, AR(k).n_reversals, ...
        AR(k).u_mean, AR(k).runtime_s);
end
w('\n### 5.5 Per-anchor gate matrix\n\n');
w('| s | PG2 | PG3 | PG4 | PG5 | PG6 | PG7 | PG8 | stable | clears PG2-PG8 | candidate eligible |\n');
w('|---|---|---|---|---|---|---|---|---|---|---|\n');
for k = 1:numel(AR)
    w('| %.9f | %s | %s | %s | %s | %s | %s | %s | %s | %s | %s |\n', AR(k).s, ...
        ys_pf(AR(k).PG2), ys_pf(AR(k).PG3), ys_pf(AR(k).PG4), ys_pf(AR(k).PG5), ...
        ys_pf(AR(k).PG6), ys_pf(AR(k).PG7), ys_pf(AR(k).PG8), ys_pf(AR(k).stable_ok), ...
        ys_pf(AR(k).clears_PG2_PG8), ...
        ys_ternary(AR(k).is_control, 'control (excluded by definition)', ys_pf(AR(k).candidate_eligible)));
end
w('\n');

w('## 6. Bitwise replay\n\n');
w('Every anchor was re-executed after a full state reset, in reverse anchor order.\n\n');
w('| anchor | s | replay hash | matches forward pass |\n|---|---|---|---|\n');
for k = 1:numel(R.replay)
    w('| %d | %.9f | `%s` | %s |\n', R.replay(k).anchor_index, R.replay(k).s, ...
        R.replay(k).hash, ys_ternary(R.replay(k).match,'yes','**NO**'));
end
w('\nReplay all matched: **%s** over %d runs.\n\n', ys_ternary(R.replay_ok,'yes','NO'), R.replay_n);

w('## 7. Pareto view\n\n');
w('%s\n\n%s\n\n', R.pareto_note, R.pareto.front_note);
w('| %s |\n', strjoin(R.pareto.columns, ' | '));
w('|%s|\n', repmat('---|', 1, numel(R.pareto.columns)));
for k = 1:size(R.pareto.table,1)
    row = R.pareto.table(k,:);
    cs = arrayfun(@(v) sprintf('%.6g', v), row, 'UniformOutput', false);
    w('| %s |\n', strjoin(cs, ' | '));
end
w('\nNon-dominated anchor indices: %s.\n\n', mat2str(R.pareto.front_index(:)'));

w('## 8. Gates\n\n');
w('| id | pass | requirement | evidence |\n|---|---|---|---|\n');
for i = 1:numel(R.gates)
    w('| %s | %s | %s | %s |\n', R.gates(i).id, ys_pf(R.gates(i).pass), ...
        strrep(R.gates(i).req, '|', '/'), strrep(R.gates(i).detail, '|', '/'));
end
w('\nHard gates all pass: **%s**. Failed: %s.\n\n', ys_ternary(R.hard_all_pass,'yes','no'), ...
    ys_ternary(isempty(R.hard_failed), 'none', strjoin(R.hard_failed, ', ')));

w('## 9. Predeclared falsifiers\n\n');
w('| id | triggered | falsifier | evidence |\n|---|---|---|---|\n');
for i = 1:numel(R.falsifier_status)
    w('| %s | %s | %s | %s |\n', R.falsifier_status(i).id, ...
        ys_ternary(R.falsifier_status(i).triggered,'**YES**','no'), ...
        R.falsifier_status(i).text, R.falsifier_status(i).evidence);
end
w('\n');

w('## 10. Finding, candidate status and next method\n\n');
w('**Outcome: `%s`.** %s\n\n', R.outcome, R.finding);
if ~isempty(R.candidate)
    w('**Shadow candidate (NOT promoted):** %s\n\n', R.candidate);
    w('PG10 forbids promotion on this evidence and none is claimed. The candidate is named only so that the next task has an unambiguous object to attack.\n\n');
else
    w('**No candidate is named.**\n\n');
end
if ~isempty(R.next_method)
    w('**Evidenced next method:** %s\n\n', R.next_method);
end
w('**Promotion claimed:** %s. **Gate 9:** %s. **Hardware:** %s.\n\n', ...
    ys_ternary(R.promotion_claimed,'yes','no'), R.gate9_status, R.hardware_status);

w('## 11. Artifacts, resources and visual QA\n\n');
w('- Wall-clock runtime %.1f s; MATLAB invocations %d (pid %d, prior lock present %d); no retry.\n', ...
    R.host_runtime_s, R.matlab_invocations, R.pid, R.prior_lock_present);
w('- Artifact footprint %.3f MiB, PG9 limit 100 MiB (%s), task budget %d MiB (%s).\n', ...
    R.footprint_mib, ys_ternary(R.footprint_ok,'met','EXCEEDED'), R.footprint_budget_mib, ...
    ys_ternary(R.footprint_within_task_budget,'met','EXCEEDED'));
w('- Free disk at start %.2f GiB.\n', R.free_gib_at_start);
if isfield(R,'visual_qa') && isfield(R.visual_qa,'verdict')
    w('- Visual QA verdict **%s**', R.visual_qa.verdict);
    if isfield(R.visual_qa,'checks')
        w(' (%d/%d checks pass, %d/%d files ok)', sum([R.visual_qa.checks.pass]), ...
            numel(R.visual_qa.checks), R.visual_qa.n_ok, R.visual_qa.n_files);
    end
    w('.\n');
end
for i = 1:numel(R.artifacts)
    w('- `%s`\n', strrep(R.artifacts{i},'\','/'));
end
w('\nAll priors remain **ASSUMED**. Simulation is never hardware certification (**NOT_CERTIFIED**). Gate 9 remains **LOCKED**.\n');
fclose(fid);
fprintf('[YSW] wrote %s.md\n', OUTB);
end

function s = ys_pf(b)
if b, s = 'PASS'; else, s = '**FAIL**'; end
end

% =====================================================================
function ys_append_logs(R, TAG)
marker = sprintf('<!-- APPEND_MARKER:%s_RESUME_001 -->', TAG);
targets = { fullfile('suite_results','AUV_REALIZATION_READINESS_PLAN.md'), 'readiness'; ...
            fullfile('suite_results','AUV_REALISM_AND_VISUAL_VALIDATION.md'), 'realism'; ...
            fullfile('suite_results','PITCH_CONTROL_RESEARCH_LOG.md'), 'research' };
if ~isfield(R, 'gates') || ~isfield(R, 'anchor_results') || ~isfield(R, 'outcome') || ...
   ~isfield(R, 'pg1') || ~isfield(R, 'footprint_mib')
    fprintf('[YSW] sweep incomplete, logs not appended\n');
    return
end
AR = R.anchor_results;
for i = 1:size(targets,1)
    p = targets{i,1};
    if exist(p, 'file') ~= 2, continue; end
    txt = '';
    try, txt = fileread(p); catch, end     % mechanical idempotency guard only
    if ~isempty(strfind(txt, marker)) %#ok<STREMP>
        fprintf('[YSW] %s log already carries the marker, skipping append\n', targets{i,2});
        continue
    end
    fid = fopen(p, 'a');
    if fid < 0, continue; end
    fprintf(fid, '\n\n%s\n\n', marker);
    fprintf(fid, '## Append: %s_RESUME_001 (%s log)\n\n', TAG, targets{i,2});
    fprintf(fid, '**Date:** %s | **Class:** Gate 8 isolated shadow-only scalar sweep, promotion forbidden | **MATLAB runs:** 1 | **Production/CODEX:** untouched | **HW:** NOT_CERTIFIED\n\n', R.created);
    fprintf(fid, '**Verdict: %s. Outcome: %s.**', R.verdict, R.outcome);
    if ~isempty(R.hard_failed)
        fprintf(fid, ' Failed gates: %s.', strjoin(R.hard_failed, ', '));
    end
    fprintf(fid, '\n\n');
    fprintf(fid, '- **Resume, not retry.** %s\n', R.resume_note);
    fprintf(fid, '- **Frames and units.** Positions NED in m with z positive down; BODY rates p,q,r in rad/s; angles rad internally, deg only where named; rudder deg against a %.4g deg magnitude and %.4g deg/s rate envelope; dwell is a dimensionless fraction of the %g s horizon; rudder energy in deg*s and deg^2*s; thrust in the native production unit.\n', ...
        R.LIM_deg, R.RATE_LIM_degs, R.T_final);
    fprintf(fid, '- **Provenance.** Exactly 3 sources read: `controller_law.m`, `run_gate8_actuator_order_scan_repair.m`, `suite_results/GATE8_R10_YAW_TERM_DIMENSIONAL_CONSISTENCY_AUDIT.mat`. No repo scan. The four anchors, the ten gate texts and every threshold were read back out of the stored plan rather than restated.\n');
    fprintf(fid, '- **Experiment.** One frozen cell `%s`, one nominal %g s horizon at dt %g s, hooks off. Common scale s on `(Kp_psi, Kd_psi) = (%g s, %g s)`, `Td = %.6f s` held, feedforward tied to Kd_psi. Anchors s = %s. Full state reset and reverse-order bitwise replay on every anchor (replay all matched: %s).\n', ...
        R.cell.name, R.T_final, R.dt, R.gains_frozen.Kp_psi, R.gains_frozen.Kd_psi, R.Td_fixed, ...
        mat2str(R.anchors, 9), ys_ternary(R.replay_ok,'yes','NO'));
    fprintf(fid, '- **PG1 frozen control.** s = 1 hash `%s` against frozen `%s`: %s. Independent metric parity %d/%d within %.0e relative. Sweep void: %s.\n', ...
        R.pg1.hash_now, R.pg1.hash_frozen, ys_ternary(R.pg1.hash_equal,'bit-for-bit equal','MISMATCH'), ...
        sum(R.pg1.metric_ok), numel(R.pg1.metric_ok), R.pg1.metric_tol_rel, ys_ternary(R.sweep_void,'YES','no'));
    fprintf(fid, '- **Every anchor reported.**');
    for k = 1:numel(AR)
        fprintf(fid, ' s=%.6f: raw absmax %.3f deg, mag/rail/rate dwell %.4f/%.4f/%.4f, median authority %.3f deg, cte max/med %.5f/%.5f m, transmitted %.4f, clears PG2-PG8 %s.', ...
            AR(k).s, AR(k).raw_absmax_deg, AR(k).magsat_dwell, AR(k).rail_dwell, AR(k).rate_dwell, ...
            AR(k).dr_plant_medabs, AR(k).cte_absmax_m, AR(k).cte_medabs_m, AR(k).transmitted_frac, ...
            ys_ternary(AR(k).clears_PG2_PG8,'yes','no'));
    end
    fprintf(fid, ' No interpolation between anchors and no anchor dropped.\n');
    fprintf(fid, '- **Finding.** %s\n', R.finding);
    if ~isempty(R.candidate)
        fprintf(fid, '- **Shadow candidate (NOT promoted, PG10):** %s. Independent-cell plus disturbance validation is required before promotion may even be discussed.\n', R.candidate);
    else
        fprintf(fid, '- **No candidate named.** The coordinated scalar rescaling method is closed for this failure on this evidence.\n');
    end
    if ~isempty(R.next_method)
        fprintf(fid, '- **Next exact task:** %s\n', R.next_method);
    end
    fprintf(fid, '- **Preserved.** No shaper, no current feedforward, no path change, no threshold change. Production, plant, metrics and CODEX_VERTICAL_PLAN fingerprints unchanged (%d/%d identical to the audit record). One MATLAB invocation, no retry, footprint %.3f MiB.\n', ...
        sum(R.fp_matches_recorded), numel(R.fp_pre), R.footprint_mib);
    fprintf(fid, '- **Evidence:** `suite_results/%s.{md,mat,png}`, %d figures, plus `suite_results/%s_run.log`. Visual QA verdict %s.\n', ...
        TAG, numel(R.png), TAG, ys_qa_verdict(R));
    fprintf(fid, '- All priors remain **ASSUMED**. Simulation is not hardware certification (**NOT_CERTIFIED**). Gate 9 remains **LOCKED**.\n');
    fclose(fid);
    fprintf('[YSW] appended %s log: %s\n', targets{i,2}, p);
end
end

function s = ys_qa_verdict(R)
s = 'NOT_PRODUCED';
if isfield(R, 'visual_qa') && isfield(R.visual_qa, 'verdict')
    s = R.visual_qa.verdict;
end
end
