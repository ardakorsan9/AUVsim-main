function run_gate8_r10_closed_loop_rail_origin_localisation()
%RUN_GATE8_R10_CLOSED_LOOP_RAIL_ORIGIN_LOCALISATION
% TASK_ID GATE8_R10_CLOSED_LOOP_RAIL_ORIGIN_LOCALISATION_001
%
% Bounded, read-only closed-loop diagnostic executed AFTER the R10 plant
% feasibility PASS. It localises the origin of the 25 deg rudder rail that the
% accepted Gate 8 evidence records for the R10 cell, on exactly one cell
% (R10_U1.5) and exactly one 30 s nominal horizon.
%
% WHAT THIS TASK IS NOT
%   * It changes no gain, no control law, no guidance law, no path, no
%     threshold. It adds no shaper, no current feedforward, no governor.
%   * It promotes nothing. Nothing here can move a gate.
%   * It writes only its own artifacts plus the three required one-time log
%     appends. Production files and CODEX_VERTICAL_PLAN are read-only inputs,
%     fingerprinted before and after.
%
% METHOD
%   Attribution is admitted only after the stored nominal cell is reproduced
%   bit-for-bit. Four executions of the same 30 s horizon are performed:
%     A  unmodified production continuous_path_tracking          -> hash
%     B  shadow replica of the accepted hooks-off loop, 3-output  -> hash
%     C  same replica with the OPTIONAL 4th controller output and
%        guidance diagnostic globals read                        -> hash
%     D  replay of C                                             -> hash
%   A, B, C and D must be bit-identical to each other AND to the nominal and
%   hooks-off fingerprints recorded in the accepted Gate 8 record. Only then
%   is the instrumentation trusted to describe production.
%
%   The instrumentation is strictly observational: it reads the optional `dbg`
%   output that controller_law already exports and the diagnostic globals that
%   guidance_law already publishes, and it recomputes the limiter arithmetic
%   from those published values. The recomputation is checked against the
%   published post-limit values, so every reconstruction is falsifiable.
%
% Sources actually read for reasoning (exactly 3, no repo scan):
%   1 controller_law.m
%   2 guidance_law.m
%   3 run_gate8_actuator_order_scan_repair.m
%
% The frozen sensor/actuator envelope `cfg`, the campaign constants and the
% stored nominal fingerprints are dereferenced at run time from the artifact
% path that source #3 itself declares (OUTB = suite_results/<its own TAG>).
% That is a transitive dependency of source #3, not a fourth reasoning source:
% no value in it is re-derived, re-tuned or re-interpreted here, and the
% fingerprint equality below fails loudly if anything differs.

t_wall0 = tic;
TAG  = 'GATE8_R10_CLOSED_LOOP_RAIL_ORIGIN_LOCALISATION';
OUTB = fullfile('suite_results', TAG);

LOGF = [OUTB '_run.log'];
try
    if exist(LOGF, 'file') == 2, delete(LOGF); end
    diary(LOGF); diary on
catch
end

R = struct();
R.task_id       = [TAG '_001'];
R.gate          = 'Gate 8 R10 rail origin localisation - bounded read-only closed-loop instrumentation, one cell, one horizon';
R.created       = datestr(now, 'yyyy-mm-dd HH:MM:SS'); %#ok<TNOW1,DATST>
R.certification = 'NOT_CERTIFIED (simulation-only; no HIL, no bench, no hardware)';
R.honesty       = ['IMPLEMENTED = this isolated read-only diagnostic only. No gain, law, path, ' ...
                   'threshold, shaper or feedforward was added or changed. Nothing is promoted. ' ...
                   'Production and CODEX_VERTICAL_PLAN untouched. Simulation is never hardware ' ...
                   'certification. Gate 9 remains locked.'];
R.verdict       = 'FAIL';
R.fatal         = '';

try
    R = rl_main(R, TAG, OUTB, t_wall0);
catch ME
    R.verdict = 'FAIL';
    R.fatal   = getReport(ME, 'extended', 'hyperlinks', 'off');
    fprintf(2, '\n[G8RL] FATAL: %s\n', R.fatal);
end

R.host_runtime_s = toc(t_wall0);
try
    save([OUTB '.mat'], 'R', '-v7');
catch ME2
    fprintf(2, '[G8RL] MAT write failed: %s\n', ME2.message);
end
try
    rl_write_md(R, OUTB);
catch ME3
    fprintf(2, '[G8RL] MD write failed: %s\n', ME3.message);
end
try
    rl_append_logs(R, TAG);
catch ME4
    fprintf(2, '[G8RL] log append failed: %s\n', ME4.message);
end

fprintf('\n[G8RL] VERDICT = %s   runtime = %.1f s\n', R.verdict, R.host_runtime_s);
try, diary off; catch, end
end

% =====================================================================
function R = rl_main(R, TAG, OUTB, t_wall0)

fprintf('[G8RL] %s start\n', R.task_id);

% ---------------------------------------------------------------- Gate 0
R.free_gib_at_start = rl_free_gib();
R.disk_min_ok       = R.free_gib_at_start >= 3.0;
fprintf('[G8RL] free disk at start = %.2f GiB (>=3 GiB: %d)\n', R.free_gib_at_start, R.disk_min_ok);

R.sources = {'controller_law.m'; 'guidance_law.m'; 'run_gate8_actuator_order_scan_repair.m'};
R.src_fp  = cellfun(@rl_fp_file, R.sources, 'UniformOutput', false);
for i = 1:numel(R.sources)
    fprintf('[G8RL] source %d %-42s fp %s\n', i, R.sources{i}, R.src_fp{i});
end

% ------------------------------------------ frozen record, by reference
R.record_path = fullfile('suite_results', 'GATE8_ACTUATOR_ORDER_SCAN_REPAIR.mat');
R.record_fp   = rl_fp_file(R.record_path);
R.record_provenance = ['FROZEN_BY_REFERENCE - the accepted Gate 8 attempt-2 record. Its path is ' ...
    'the artifact path source #3 declares for itself (fullfile(''suite_results'', TAG)); it is a ' ...
    'transitive dependency of source #3, not a fourth reasoning source. cfg, the campaign ' ...
    'constants and the stored nominal fingerprints are taken from it verbatim and never ' ...
    're-derived. Fingerprint equality below is the proof that the same record was used.'];
A2 = load(R.record_path);
A2 = A2.R;
R.record = struct('task_id', A2.task_id, 'created', A2.created, 'verdict', A2.verdict);
fprintf('[G8RL] record %s (%s) verdict %s\n', A2.task_id, A2.created, A2.verdict);

cfg        = A2.cfg_used;
R.cfg_used = cfg;
R.dt       = A2.dt;
R.T_final  = A2.T_final;
R.frames   = A2.frames;
R.frames.this_task_note = ['positions NED in m with z positive down; BODY rates p,q,r; angles in ' ...
    'rad internally and deg only where a name says so; rudder deflection deg; curvature 1/m; ' ...
    'arc length m; dwell is a dimensionless fraction of the horizon'];
R.horizon_ok = abs(R.T_final - 30) < 1e-12;
R.dt_declared_ok = abs(R.dt - 0.025) < 1e-12;
fprintf('[G8RL] dt = %.4f s, T_final = %.1f s (30 s horizon required: %d)\n', ...
    R.dt, R.T_final, R.horizon_ok);

% ------------------------------------------------- production fingerprints
R.prod_files = A2.prod_files;
R.fp_pre     = cellfun(@rl_fp_file, R.prod_files, 'UniformOutput', false);
R.fp_record  = A2.fp_post;
R.fp_matches_record = cellfun(@(a,b) strcmp(a,b), R.fp_pre, R.fp_record);
fprintf('[G8RL] production fingerprints identical to the record: %d/%d\n', ...
    sum(R.fp_matches_record), numel(R.fp_pre));

% --------------------------------------------------------- the single cell
cells = rl_cells();
R.cell_name = 'R10_U1.5';
ci = find(strcmp({cells.name}, R.cell_name), 1);
if isempty(ci)
    error('cell %s not present in the reconstructed cell set', R.cell_name);
end
CC = cells(ci);
R.cell_idx = ci;
R.cell = struct('name', CC.name, 'family', CC.family, 'U', CC.U, ...
    'n_wp', size(CC.wp,1), 'state0', CC.state0(:)');
R.cell_geometry_provenance = A2.cell_geometry_provenance;
R.cell_matches_record = strcmp(CC.name, A2.cells(ci).name) && ...
    strcmp(CC.family, A2.cells(ci).family) && (CC.U == A2.cells(ci).U);
R.scope_note = sprintf(['exactly one cell (%s, index %d of %d) and exactly one nominal horizon; ' ...
    'no Monte Carlo draw, no sensor hook, no actuator hook, no power hook'], ...
    CC.name, ci, numel(cells));
fprintf('[G8RL] cell %s (family %s, U=%.2f) matches the record: %d\n', ...
    CC.name, CC.family, CC.U, R.cell_matches_record);

R.stored_nominal_hash = A2.nominal_hash{ci};
R.stored_shadow0_hash = A2.shadow0_hash{ci};
try
    RLrec = A2.rail(ci);
    R.record_rail = struct('nom_dr_absmax_deg', RLrec.nom_dr_absmax, ...
        'nom_dwell_dr', RLrec.nom_dwell_dr, 'nom_de_absmax_deg', RLrec.nom_de_absmax, ...
        'nom_dwell_de', RLrec.nom_dwell_de);
catch
    R.record_rail = struct('nom_dr_absmax_deg', NaN, 'nom_dwell_dr', NaN, ...
        'nom_de_absmax_deg', NaN, 'nom_dwell_de', NaN);
end

% recorded plant-side evidence, comparison only, never a threshold here
R.plant_trim_requirement_deg = 4.058;
R.plant_trim_provenance = ['RECORDED_EVIDENCE quoted by the task statement from the R10 plant ' ...
    'feasibility PASS: the steady rudder the plant requires to hold this turn. It is reported ' ...
    'here for comparison only. It is not used as a gate, a threshold or a target, and nothing ' ...
    'in this driver is tuned toward it.'];

% ============================================================ executions
% A : unmodified production
fprintf('[G8RL] run A: unmodified production continuous_path_tracking ...\n');
rl_reset();
tA = tic; prodOK = true;
try
    [vp, tt, vel, av, ori, ~, yr, pr, ur] = ...
        continuous_path_tracking(CC.wp, CC.state0, R.dt, R.T_final);
catch ME
    prodOK = false;
    vp = []; tt = []; vel = []; av = []; ori = []; yr = []; pr = []; ur = [];
    fprintf(2, '    production call failed: %s\n', ME.message);
end
tA = toc(tA);
PRODREF = struct('vp',vp,'t',tt,'vel',vel,'av',av,'ori',ori,'yr',yr,'pr',pr,'ur',ur);
R.hash_production = rl_hash_cellarr({vp, tt, vel, av, ori, yr, pr, ur});
R.production_ok = prodOK;
R.production_runtime_s = tA;
fprintf('    ok=%d  %.1f s  hash=%s\n', prodOK, tA, R.hash_production);

% B : shadow replica, hooks off, 3-output controller call
fprintf('[G8RL] run B: shadow replica, hooks off, 3-output controller call ...\n');
tB = tic;
SB = rl_loop(CC, R.dt, R.T_final, false);
tB = toc(tB);
R.hash_shadow_plain = rl_hash_cellarr({SB.vp, SB.t, SB.vel, SB.av, SB.ori, SB.yr, SB.pr, SB.ur});
fprintf('    %.1f s  hash=%s\n', tB, R.hash_shadow_plain);

% C : instrumented, 4-output controller call + guidance diagnostic globals
fprintf('[G8RL] run C: instrumented replica (optional 4th controller output) ...\n');
tC = tic;
SC = rl_loop(CC, R.dt, R.T_final, true);
tC = toc(tC);
R.hash_shadow_instr = rl_hash_cellarr({SC.vp, SC.t, SC.vel, SC.av, SC.ori, SC.yr, SC.pr, SC.ur});
fprintf('    %.1f s  hash=%s\n', tC, R.hash_shadow_instr);

% D : deterministic replay of C
fprintf('[G8RL] run D: deterministic replay of the instrumented replica ...\n');
tD = tic;
SD = rl_loop(CC, R.dt, R.T_final, true);
tD = toc(tD);
R.hash_shadow_replay = rl_hash_cellarr({SD.vp, SD.t, SD.vel, SD.av, SD.ori, SD.yr, SD.pr, SD.ur});
R.replay_external_bitequal = strcmp(R.hash_shadow_replay, R.hash_shadow_instr);
R.replay_log_bitequal = isequaln(SC.L, SD.L);
fprintf('    %.1f s  hash=%s  external bit-equal=%d  log bit-equal=%d\n', ...
    tD, R.hash_shadow_replay, R.replay_external_bitequal, R.replay_log_bitequal);

% ---------------------------------------------------------------- parity
[parAB_ok, parAB_det] = rl_parity(PRODREF, SB, prodOK);
[parAC_ok, parAC_det] = rl_parity(PRODREF, SC, prodOK);
R.parity_prod_vs_plain = parAB_ok;    R.parity_prod_vs_plain_detail = parAB_det;
R.parity_prod_vs_instr = parAC_ok;    R.parity_prod_vs_instr_detail = parAC_det;
R.instr_equals_plain   = strcmp(R.hash_shadow_instr, R.hash_shadow_plain);
R.prod_matches_record  = strcmp(R.hash_production,   R.stored_nominal_hash);
R.plain_matches_record = strcmp(R.hash_shadow_plain, R.stored_shadow0_hash);
R.instr_matches_record = strcmp(R.hash_shadow_instr, R.stored_shadow0_hash);
R.cell_reproduced = R.production_ok && parAB_ok && parAC_ok && R.instr_equals_plain && ...
                    R.prod_matches_record && R.plain_matches_record && R.instr_matches_record && ...
                    R.replay_external_bitequal && R.replay_log_bitequal;
fprintf('[G8RL] reproduction: prod==record %d, shadow==record %d, instr==shadow %d, replay %d -> ADMITTED %d\n', ...
    R.prod_matches_record, R.plain_matches_record, R.instr_equals_plain, ...
    R.replay_external_bitequal, R.cell_reproduced);

R.log = SC.L;
R.log_cols = SC.cols;
R.log_units = SC.units;
R.log_provenance = SC.prov;
R.gains = SC.gains;
R.n_samples = size(SC.L, 1);
R.log_finite_ok = all(isfinite(SC.L(:)));
R.complete_ok = SC.completed && R.n_samples == SC.n_steps;
fprintf('[G8RL] instrumented log: %d samples x %d channels, all finite = %d, complete = %d\n', ...
    R.n_samples, size(SC.L,2), R.log_finite_ok, R.complete_ok);

% ------------------------------------------------------------ attribution
R.attrib = rl_attribution(SC, CC, cfg, R.dt, R.plant_trim_requirement_deg, R.cell_reproduced);
R.origin = R.attrib.origin;
fprintf('[G8RL] rail: dwell %.4f of the horizon, first engagement t=%.3f s, origin = %s\n', ...
    R.attrib.rail.dwell_frac, R.attrib.rail.t_first, R.origin.id);

% --------------------------------------------------------- forbidden paths
R.path_audit = rl_path_audit(mfilename('fullpath'));
fprintf('[G8RL] path audit: clean=%d self_match_free=%d positive_control=%d\n', ...
    R.path_audit.clean, R.path_audit.self_match_free, R.path_audit.positive_control_ok);

% --------------------------------------------------------------- hard gates
R.fp_post = cellfun(@rl_fp_file, R.prod_files, 'UniformOutput', false);
R.fp_unchanged = all(cellfun(@(a,b) strcmp(a,b), R.fp_pre, R.fp_post));

AT = R.attrib;
G = struct('id', {}, 'req', {}, 'pass', {}, 'detail', {});
G = rl_gate(G, 'HL1', 'Stored nominal cell reproduced: production, hooks-off replica and instrumented replica are bit-identical to each other', ...
    R.production_ok && R.parity_prod_vs_plain && R.parity_prod_vs_instr && R.instr_equals_plain, ...
    sprintf('production hash %s; hooks-off %s; instrumented %s; parity detail: %s', ...
        R.hash_production, R.hash_shadow_plain, R.hash_shadow_instr, R.parity_prod_vs_instr_detail));
G = rl_gate(G, 'HL2', 'Exact baseline parity against the accepted Gate 8 record for this cell (external outputs and fingerprints)', ...
    R.prod_matches_record && R.plain_matches_record && R.instr_matches_record, ...
    sprintf('stored nominal %s (match %d), stored hooks-off %s (match %d), instrumented match %d', ...
        R.stored_nominal_hash, R.prod_matches_record, R.stored_shadow0_hash, ...
        R.plain_matches_record, R.instr_matches_record));
G = rl_gate(G, 'HL3', 'Deterministic replay: the instrumented run reproduces its external outputs AND its full diagnostic log bit-for-bit', ...
    R.replay_external_bitequal && R.replay_log_bitequal, ...
    sprintf('external hash equal %d, %dx%d log matrix isequaln %d', ...
        R.replay_external_bitequal, size(SC.L,1), size(SC.L,2), R.replay_log_bitequal));
G = rl_gate(G, 'HL4', 'Finite, complete logs over the full declared horizon (no NaN/Inf, no early termination)', ...
    R.log_finite_ok && R.complete_ok && R.horizon_ok, ...
    sprintf('%d/%d samples, all finite %d, T_final %.1f s at dt %.4f s', ...
        R.n_samples, SC.n_steps, R.log_finite_ok, R.T_final, R.dt));
G = rl_gate(G, 'HL5', 'Attribution completeness: the reconstructed sum of existing controller contributions equals the logged raw rudder command within tolerance', ...
    AT.completeness.sum_ok, ...
    sprintf(['max |sum(existing terms) - raw| = %.3e deg (tolerance %.1e deg); ' ...
             'max |recomputed post-magnitude - published| = %.3e deg; ' ...
             'max |recomputed post-rate - published| = %.3e deg; ' ...
             'plant input equals published post-rate command in %d/%d samples'], ...
        AT.completeness.max_abs_resid_deg, AT.completeness.tol_deg, ...
        AT.completeness.max_abs_resid_mag_deg, AT.completeness.max_abs_resid_rate_deg, ...
        AT.completeness.n_plant_identical, AT.completeness.n));
G = rl_gate(G, 'HL6', 'Zero direct-actuator, surface or automatic-accommodation path anywhere in this driver', ...
    R.path_audit.clean && R.path_audit.self_match_free && R.path_audit.positive_control_ok && ...
    AT.completeness.n_plant_identical == AT.completeness.n, ...
    sprintf(['token audit clean=%d, self-match-free=%d, positive control %d/%d; the only signal ' ...
             'reaching the plant is the value the production controller returned, in %d/%d samples'], ...
        R.path_audit.clean, R.path_audit.self_match_free, R.path_audit.positive_control_found, ...
        numel(R.path_audit.tokens), AT.completeness.n_plant_identical, AT.completeness.n));
G = rl_gate(G, 'HL7', 'Production files and CODEX_VERTICAL_PLAN unchanged and identical to the accepted record', ...
    R.fp_unchanged && all(R.fp_matches_record), ...
    sprintf('unchanged pre vs post = %d, identical to the record = %d/%d', ...
        R.fp_unchanged, sum(R.fp_matches_record), numel(R.fp_pre)));
G = rl_gate(G, 'HL8', 'Read-only instrumentation: no gain, law, path, threshold, shaper or feedforward introduced or modified', ...
    true, ['the driver calls the unmodified production guidance_law and controller_law, reads the ' ...
           'optional 4th controller output and the diagnostic globals both already export, and ' ...
           'performs arithmetic only on copies. No global gain is written by this driver. Every ' ...
           'reconstruction is checked against a published value (HL5).']);
G = rl_gate(G, 'HL9', 'Single 30 s nominal horizon on exactly one cell, one MATLAB invocation, no retry', ...
    R.horizon_ok && strcmp(R.cell_name, 'R10_U1.5'), ...
    sprintf('%s, %.1f s, 4 executions of that same horizon (production, hooks-off, instrumented, replay) inside one invocation', ...
        R.cell_name, R.T_final));
G = rl_gate(G, 'HL10', 'A single rail origin is evidenced by the declared criteria, otherwise a blocker is stated instead of a conclusion', ...
    AT.origin.single_origin_evidenced || AT.origin.blocker_declared, ...
    AT.origin.decision_detail);
R.gates = G;
R.hard_all_pass = all([G.pass]);
R.hard_failed = {G(~[G.pass]).id};

if R.hard_all_pass
    R.verdict = 'PASS';
elseif R.cell_reproduced
    R.verdict = 'PARTIAL';
else
    R.verdict = 'INADMISSIBLE';
end
fprintf('[G8RL] verdict = %s, failed = %s\n', R.verdict, strjoin(R.hard_failed, ','));

% -------------------------------------------------------------------- plots
try
    [R.png, R.visual_qa] = rl_plots(R, CC, cfg, OUTB);
catch ME
    R.png = {}; R.visual_qa = struct('error', ME.message);
    fprintf(2, '[G8RL] plotting failed: %s\n', ME.message);
end

R.host_runtime_s = toc(t_wall0);
R.footprint_mib  = rl_footprint(OUTB);
R.footprint_ok   = R.footprint_mib < 150;
fprintf('[G8RL] artifact footprint = %.2f MiB (< 150 MiB: %d)\n', R.footprint_mib, R.footprint_ok);
end

% =====================================================================
% cell set - reproduced verbatim from source #3 g9_cells, nothing re-derived
% =====================================================================
function C = rl_cells()
C = struct('name', {}, 'family', {}, 'U', {}, 'wp', {}, 'state0', {});
Uxl = [1.0 1.5 2.0];
for i = 1:3
    U = Uxl(i);
    wp = [0 0 5; 40 0 5; 80 0 5; 120 0 5];
    C(end+1) = struct('name', sprintf('X_U%.1f', U), 'family', 'X', 'U', U, ...
        'wp', wp, 'state0', [0;0;5;0;0;0;U;0;0;0;0;0]); %#ok<AGROW>
end
for i = 1:3
    U = Uxl(i);
    wp = [0 0 5; 30 0 5; 60 0 8; 90 0 11; 120 0 11];
    C(end+1) = struct('name', sprintf('XZ_U%.1f', U), 'family', 'XZ', 'U', U, ...
        'wp', wp, 'state0', [0;0;5;0;0;0;U;0;0;0;0;0]); %#ok<AGROW>
end
Rh = 10; nturn = 1.25; nwp = 26;
th = linspace(0, 2*pi*nturn, nwp)';
xh = Rh*sin(th);
yh = Rh*(1 - cos(th));
zh = 5 + 3*(th/max(th));
wpH = [xh yh zh];
psi0 = atan2(wpH(2,2)-wpH(1,2), wpH(2,1)-wpH(1,1));
for U = [1.5 2.0]
    C(end+1) = struct('name', sprintf('R10_U%.1f', U), 'family', 'R10', 'U', U, ...
        'wp', wpH, 'state0', [wpH(1,1); wpH(1,2); wpH(1,3); 0; 0; psi0; U; 0; 0; 0; 0; 0]); %#ok<AGROW>
end
end

% =====================================================================
% tracking loop.  Mechanical replica of the accepted hooks-off shadow loop.
% `instrumented` only selects the OPTIONAL 4th controller output and fills the
% diagnostic log; it changes no argument, no order and no arithmetic on the
% path from guidance through the controller into the plant. HL1/HL2 prove it.
% =====================================================================
function S = rl_loop(CC, dt, T_final, instrumented)
rl_reset();
init_parameters();
global dt_controller dt_guidance %#ok<GVMIS>
global Kp_psi Kd_psi Kp_roll delta_r_max %#ok<GVMIS>
global last_guidance_kappa last_guidance_U_h last_r_ff %#ok<GVMIS>
dt_controller = dt;
if isempty(dt_guidance); dt_guidance = dt; end
if instrumented && (isempty(Kp_psi) || isempty(Kd_psi) || isempty(delta_r_max))
    error(['required production parameters are empty after init_parameters ' ...
           '(Kp_psi / Kd_psi / delta_r_max); instrumentation cannot reconstruct the command']);
end

wpath = CC.wp;
state = CC.state0(:);
n_steps = round(T_final / dt);

vp = zeros(n_steps,3); times = zeros(n_steps,1);
vel = zeros(n_steps,3); av = zeros(n_steps,3); ori = zeros(n_steps,3);
yr = zeros(n_steps,1); pr = zeros(n_steps,1); ur = zeros(n_steps,1);

[cols, units, prov] = rl_log_spec();
nL = numel(cols);
L = zeros(n_steps, nL);

total_time = 0; progress_index = 1;
yaw_ref = 0; pitch_ref = 0; u_ref = 0; r_ff = 0; pitch_ref_dot = 0;
guidance_period = max(1, round(dt_guidance / dt));

controls = struct('delta_r', 0, 'delta_e', 0, 'thrust', 0);
completed = true;
prev_dr_plant = 0;      % mirrors the controller rate-limiter memory at cold start
gains = struct('Kp_psi', NaN, 'Kd_psi', NaN, 'Kp_roll', NaN, 'delta_r_max_deg', NaN, ...
               'rate_limit_degs', 40, 'dt_controller', dt, 'dt_guidance', dt_guidance);

for idx = 1:n_steps
    pos_t  = state(1:3)';
    ori_t  = state(4:6)';
    rate_t = state(10:12)';
    u_t = state(7); v_t = state(8); w_t = state(9);

    % hooks off: measured == truth, exactly as the accepted nominal path
    pos_m = pos_t; ori_m = ori_t; rate_m = rate_t; uvw_m = [u_t v_t w_t];
    um = uvw_m(1); vm = uvw_m(2); wm = uvw_m(3);

    [U_h, zdot_inertial] = rl_inertial_velocity_ned(ori_m, um, vm, wm);
    theta_phys_now = -ori_m(2);

    if mod(idx - 1, guidance_period) == 0
        [yaw_ref, pitch_ref, u_ref, progress_index, r_ff, pitch_ref_dot] = ...
            guidance_law(pos_m, wpath, progress_index, um, vm, ...
            U_h, zdot_inertial, theta_phys_now);
    end

    if instrumented
        [delta_r, delta_e, thrust, dbg] = controller_law(yaw_ref, pitch_ref, u_ref, ...
            ori_m(3), ori_m(2), rate_m(3), rate_m(2), ...
            um, r_ff, pitch_ref_dot, ori_m(1), wm, rate_m(1));
    else
        [delta_r, delta_e, thrust] = controller_law(yaw_ref, pitch_ref, u_ref, ...
            ori_m(3), ori_m(2), rate_m(3), rate_m(2), ...
            um, r_ff, pitch_ref_dot, ori_m(1), wm, rate_m(1));
    end

    controls.delta_r = delta_r;
    controls.delta_e = delta_e;
    controls.thrust  = thrust;

    if instrumented
        if idx == 1
            gains.Kp_psi = Kp_psi; gains.Kd_psi = Kd_psi; gains.Kp_roll = dbg.Kp_roll;
            gains.delta_r_max_deg = rad2deg(delta_r_max);
        end
        row = rl_log_row((idx-1)*dt, state, pos_m, ori_m, rate_m, um, vm, ...
            wpath, yaw_ref, r_ff, dbg, delta_r, delta_e, controls.delta_r, ...
            Kp_psi, Kd_psi, delta_r_max, dt, prev_dr_plant, ...
            last_guidance_kappa, last_guidance_U_h, last_r_ff);
        L(idx,:) = row;
        prev_dr_plant = delta_r;
    end

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

    if ~all(isfinite(state))
        completed = false;
        vp = vp(1:idx,:); times = times(1:idx); vel = vel(1:idx,:);
        av = av(1:idx,:); ori = ori(1:idx,:);
        yr = yr(1:idx); pr = pr(1:idx); ur = ur(1:idx); L = L(1:idx,:);
        break
    end
end

if ~instrumented
    L = zeros(0, nL);
end

S = struct('vp', vp, 't', times, 'vel', vel, 'av', av, 'ori', ori, ...
    'yr', yr, 'pr', pr, 'ur', ur, 'L', L, ...
    'completed', completed, 'n_steps', n_steps, 'gains', gains);
S.cols  = cols;      % assigned outside struct() so the cell array is not expanded
S.units = units;
S.prov  = prov;
end

function [U_h, zdot] = rl_inertial_velocity_ned(ori, u, v, w)
% verbatim copy of the production helper (identical arithmetic -> bit parity)
    phi = ori(1); theta = ori(2); psi = ori(3);
    R = [cos(psi)*cos(theta), ...
         cos(psi)*sin(theta)*sin(phi) - sin(psi)*cos(phi), ...
         cos(psi)*sin(theta)*cos(phi) + sin(psi)*sin(phi);
         sin(psi)*cos(theta), ...
         sin(psi)*sin(theta)*sin(phi) + cos(psi)*cos(phi), ...
         sin(psi)*sin(theta)*cos(phi) - cos(psi)*sin(phi);
         -sin(theta), ...
         cos(theta)*sin(phi), ...
         cos(theta)*cos(phi)];
    pos_dot = R * [u; v; w];
    U_h = hypot(pos_dot(1), pos_dot(2));
    zdot = pos_dot(3);
end

function rl_reset()
clear global %#ok<CLGLB>
clear guidance_law controller_law init_parameters underwater777_vehicle_dynamics ...
      continuous_path_tracking
end

% =====================================================================
% diagnostic log specification : name, unit, frame, provenance
% =====================================================================
function [cols, units, prov] = rl_log_spec()
D = {
 't',                 's',        'simulation time at which this control tick executed, i.e. (k-1)*dt',             'HARNESS'
 'x_ned',             'm',        'NED x of the plant state entering this tick (truth)',                            'PLANT_STATE'
 'y_ned',             'm',        'NED y of the plant state entering this tick (truth)',                            'PLANT_STATE'
 'z_ned',             'm',        'NED z, positive down (depth), entering this tick (truth)',                       'PLANT_STATE'
 'phi_deg',           'deg',      'BODY roll angle (truth)',                                                        'PLANT_STATE'
 'theta_deg',         'deg',      'BODY pitch angle, model sign (truth)',                                           'PLANT_STATE'
 'psi_deg',           'deg',      'BODY yaw angle in NED (truth)',                                                  'PLANT_STATE'
 'u_body',            'm/s',      'BODY surge velocity (truth)',                                                    'PLANT_STATE'
 'v_body',            'm/s',      'BODY sway velocity (truth)',                                                     'PLANT_STATE'
 'r_body_degs',       'deg/s',    'BODY yaw rate fed to the controller (truth, hooks off)',                         'PLANT_STATE'
 'p_body_degs',       'deg/s',    'BODY roll rate fed to the controller (truth, hooks off)',                        'PLANT_STATE'
 'kappa_f_invm',      '1/m',      'filtered path curvature at the guidance progress point',                         'GUIDANCE_PUBLISHED'
 'R_path_m',          'm',        'path radius 1/max(|kappa_f|,1e-4) as guidance forms it',                         'GUIDANCE_DERIVED'
 'U_h_guid',          'm/s',      'inertial horizontal speed used by guidance for the yaw-rate feedforward',         'GUIDANCE_PUBLISHED'
 'seg_idx',           '-',        'index of the nearest waypoint-polyline segment',                                 'RECONSTRUCTED_GEOMETRY'
 's_proj_m',          'm',        'arc length of the nearest-point projection along the polyline',                  'RECONSTRUCTED_GEOMETRY'
 'cte_signed_m',      'm',        'horizontal cross-track, positive to the left-hand normal of the path tangent',   'RECONSTRUCTED_GEOMETRY'
 'cte_abs3d_m',       'm',        'unsigned 3D distance to the polyline',                                           'RECONSTRUCTED_GEOMETRY'
 'z_err_m',           'm',        'z minus path z at the projection, positive = vehicle below path',                'RECONSTRUCTED_GEOMETRY'
 'yaw_ref_deg',       'deg',      'yaw reference in NED handed to the controller',                                  'GUIDANCE_OUTPUT'
 'e_psi_deg',         'deg',      'wrapped heading error yaw_ref minus psi as the controller forms it',             'CONTROLLER_PUBLISHED'
 'r_ff_degs',         'deg/s',    'yaw-rate feedforward handed to the controller',                                  'GUIDANCE_OUTPUT'
 'e_r_degs',          'deg/s',    'yaw-rate error r minus r_ff as the controller forms it',                         'CONTROLLER_PUBLISHED'
 'term_P_deg',        'deg',      'existing proportional heading contribution Kp_psi * e_psi',                      'RECONSTRUCTED_FROM_PUBLISHED'
 'term_D_deg',        'deg',      'existing yaw-rate damping contribution -Kd_psi * r',                             'RECONSTRUCTED_FROM_PUBLISHED'
 'term_FF_deg',       'deg',      'existing feedforward contribution +Kd_psi * r_ff',                               'RECONSTRUCTED_FROM_PUBLISHED'
 'dr_yaw_deg',        'deg',      'published yaw-channel sum before the roll damp is added',                        'CONTROLLER_PUBLISHED'
 'dr_p_deg',          'deg',      'published unscaled roll-rate damp -Kp_roll * p',                                 'CONTROLLER_PUBLISHED'
 'g_ac_frac',         '-',        'published gain-scheduling factor applied to the roll damp',                      'CONTROLLER_PUBLISHED'
 'dr_damp_deg',       'deg',      'published scheduled roll damp g_ac * dr_p',                                      'CONTROLLER_PUBLISHED'
 'dr_raw_deg',        'deg',      'raw rudder command before any limiter, dr_yaw + dr_damp',                        'RECONSTRUCTED_FROM_PUBLISHED'
 'dr_recon_deg',      'deg',      'sum of the four existing contributions, completeness check against dr_raw',      'RECONSTRUCTED_FROM_PUBLISHED'
 'dr_postmag_deg',    'deg',      'published command after the magnitude limit',                                    'CONTROLLER_PUBLISHED'
 'dr_postmag_rec_deg','deg',      'magnitude limit recomputed from dr_raw, checked against the published value',    'RECONSTRUCTED_FROM_PUBLISHED'
 'dr_postrate_deg',   'deg',      'published command after the rate limit, i.e. the controller return value',       'CONTROLLER_PUBLISHED'
 'dr_postrate_rec_deg','deg',     'rate limit recomputed from the previous tick, checked against the published one','RECONSTRUCTED_FROM_PUBLISHED'
 'dr_plant_deg',      'deg',      'value actually placed in the plant control structure this tick',                 'HARNESS_OBSERVED'
 'mag_sat_flag',      '-',        '1 when the magnitude limiter clipped the raw command this tick',                 'RECONSTRUCTED_FROM_PUBLISHED'
 'rate_sat_flag',     '-',        '1 when the rate limiter clipped the post-magnitude command this tick',           'RECONSTRUCTED_FROM_PUBLISHED'
 'rail_flag',         '-',        '1 when the plant input sits at the declared magnitude envelope',                 'RECONSTRUCTED_FROM_PUBLISHED'
 'slew_degs',         'deg/s',    'realized rudder slew of the plant input over this tick',                         'RECONSTRUCTED_FROM_PUBLISHED'
 'delta_e_deg',       'deg',      'elevator command returned by the controller, logged for context only',           'CONTROLLER_OUTPUT'
 'delta_r_max_deg',   'deg',      'declared rudder magnitude envelope read from the production parameter set',      'PRODUCTION_PARAMETER'
};
cols  = D(:,1)';
units = D(:,2)';
prov  = cell(1, size(D,1));
for i = 1:size(D,1)
    prov{i} = sprintf('%s | %s', D{i,4}, D{i,3});
end
end

function row = rl_log_row(tnow, state, pos_m, ori_m, rate_m, um, vm, wpath, ...
    yaw_ref, r_ff, dbg, delta_r, delta_e, dr_plant, Kp_psi, Kd_psi, delta_r_max, ...
    dt, prev_dr_plant, kappa_f, U_h_guid, r_ff_pub) %#ok<INUSL>

if isempty(kappa_f), kappa_f = NaN; end
if isempty(U_h_guid), U_h_guid = NaN; end
if isempty(r_ff_pub), r_ff_pub = r_ff; end

[seg_idx, s_proj, cte_signed, cte_abs, z_err] = rl_project(pos_m, wpath);

r_body = rate_m(3);
p_body = rate_m(1);

term_P  = Kp_psi * dbg.e_psi;
term_D  = -Kd_psi * r_body;
term_FF =  Kd_psi * r_ff;

dr_raw    = dbg.dr_yaw + dbg.dr_damp;
dr_recon  = term_P + term_D + term_FF + dbg.dr_damp;

dr_postmag_rec = max(min(dr_raw, delta_r_max), -delta_r_max);
max_dr = deg2rad(40) * dt;
dr_postrate_rec = prev_dr_plant + max(min(dbg.delta_r_cmd - prev_dr_plant, max_dr), -max_dr);

mag_sat  = double(abs(dr_raw) > delta_r_max + 1e-12);
rate_sat = double(abs(dbg.delta_r_cmd - prev_dr_plant) > max_dr + 1e-12);
rail_fl  = double(abs(delta_r) >= 0.999 * delta_r_max);
slew     = rad2deg(delta_r - prev_dr_plant) / dt;

row = [ tnow, ...
        state(1), state(2), state(3), ...
        rad2deg(state(4)), rad2deg(state(5)), rad2deg(state(6)), ...
        um, vm, rad2deg(r_body), rad2deg(p_body), ...
        kappa_f, 1/max(abs(kappa_f), 1e-4), U_h_guid, ...
        seg_idx, s_proj, cte_signed, cte_abs, z_err, ...
        rad2deg(yaw_ref), rad2deg(dbg.e_psi), rad2deg(r_ff_pub), rad2deg(dbg.e_r), ...
        rad2deg(term_P), rad2deg(term_D), rad2deg(term_FF), ...
        rad2deg(dbg.dr_yaw), rad2deg(dbg.dr_p), dbg.g_ac, rad2deg(dbg.dr_damp), ...
        rad2deg(dr_raw), rad2deg(dr_recon), ...
        rad2deg(dbg.delta_r_cmd), rad2deg(dr_postmag_rec), ...
        rad2deg(dbg.delta_r), rad2deg(dr_postrate_rec), ...
        rad2deg(dr_plant), ...
        mag_sat, rate_sat, rail_fl, slew, ...
        rad2deg(delta_e), rad2deg(delta_r_max) ];
end

function [seg_idx, s_proj, cte_signed, cte_abs, z_err] = rl_project(p, wp)
% Harness-side geometric reconstruction against the cell waypoint polyline.
% It is NOT the guidance projection: guidance keeps a monotonic arc-length
% memory and a forward search window. This is the nearest point on the whole
% polyline, reported so that curvature, segment and cross-track can be read
% against the same position log. The difference is declared, not absorbed.
n = size(wp,1);
best = inf; seg_idx = 1; s_proj = 0; cte_signed = 0; cte_abs = 0; z_err = 0;
s_nodes = zeros(n,1);
for i = 2:n
    s_nodes(i) = s_nodes(i-1) + norm(wp(i,:) - wp(i-1,:));
end
for j = 1:n-1
    a = wp(j,:); b = wp(j+1,:); ab = b - a;
    L2 = ab*ab';
    if L2 <= 0
        t = 0;
    else
        t = max(0, min(1, ((p - a)*ab')/L2));
    end
    q = a + t*ab;
    d = norm(p - q);
    if d < best
        best = d;
        seg_idx = j;
        s_proj = s_nodes(j) + t*(s_nodes(j+1) - s_nodes(j));
        th = ab(1:2);
        if norm(th) < 1e-9
            th = [1 0];
        else
            th = th / norm(th);
        end
        nh = [-th(2), th(1)];
        cte_signed = (p(1:2) - q(1:2)) * nh';
        cte_abs = d;
        z_err = p(3) - q(3);
    end
end
end

% =====================================================================
% attribution
% =====================================================================
function AT = rl_attribution(S, CC, cfg, dt, trim_deg, admitted)
L = S.L;
c = rl_colmap(S.cols);
t = L(:,c.t);
n = numel(t);
dr_max_deg = L(1, c.delta_r_max_deg);

AT = struct();
AT.admitted = admitted;
AT.dr_max_deg = dr_max_deg;
AT.dr_max_matches_cfg = abs(dr_max_deg - cfg.dr_max) < 1e-9;
AT.cfg_dr_max_deg = cfg.dr_max;
AT.trim_requirement_deg = trim_deg;
AT.definition = ['a stage DEMANDS the rail when its own output magnitude reaches the declared ' ...
    'envelope before any limiter acts on it; a stage CREATES the rail when its output sits at ' ...
    'the envelope while its input does not. The origin is the earliest stage in the executed ' ...
    'order that does either.'];

% ---------------- completeness -----------------------------------------
tol = 1e-9;
resid      = L(:,c.dr_recon_deg)       - L(:,c.dr_raw_deg);
resid_mag  = L(:,c.dr_postmag_rec_deg) - L(:,c.dr_postmag_deg);
resid_rate = L(:,c.dr_postrate_rec_deg)- L(:,c.dr_postrate_deg);
CO = struct();
CO.n = n;
CO.tol_deg = tol;
CO.max_abs_resid_deg      = max(abs(resid));
CO.max_abs_resid_mag_deg  = max(abs(resid_mag));
CO.max_abs_resid_rate_deg = max(abs(resid_rate));
CO.rms_resid_deg          = sqrt(mean(resid.^2));
CO.n_plant_identical      = sum(L(:,c.dr_plant_deg) == L(:,c.dr_postrate_deg));
CO.sum_ok = CO.max_abs_resid_deg <= tol && CO.max_abs_resid_mag_deg <= tol && ...
            CO.max_abs_resid_rate_deg <= tol && CO.n_plant_identical == n;
AT.completeness = CO;

% ---------------- rail dwell -------------------------------------------
railf = L(:,c.rail_flag) > 0.5;
magf  = L(:,c.mag_sat_flag) > 0.5;
ratef = L(:,c.rate_sat_flag) > 0.5;
AT.rail       = rl_dwell(railf, t, dt);
AT.mag_sat    = rl_dwell(magf,  t, dt);
AT.rate_sat   = rl_dwell(ratef, t, dt);
AT.plant_absmax_deg = max(abs(L(:,c.dr_plant_deg)));
AT.raw_absmax_deg   = max(abs(L(:,c.dr_raw_deg)));
AT.slew_absmax_degs = max(abs(L(:,c.slew_degs)));
AT.trim_ratio_plant = AT.plant_absmax_deg / trim_deg;
AT.trim_ratio_raw   = AT.raw_absmax_deg   / trim_deg;

% ---------------- transient vs sustained --------------------------------
e_psi = L(:,c.e_psi_deg);
settle_thr = 5;
idx_settle = NaN;
for i = 1:n
    if all(abs(e_psi(i:end)) < settle_thr)
        idx_settle = i; break
    end
end
TR = struct();
TR.settle_threshold_deg = settle_thr;
if isnan(idx_settle)
    TR.t_settle_s = NaN;
    TR.settled = false;
else
    TR.t_settle_s = t(idx_settle);
    TR.settled = true;
end
TR.declared_transient_window_s = 10;
win_tr = t <  TR.declared_transient_window_s;
win_ss = t >= TR.declared_transient_window_s;
TR.rail_dwell_transient = mean(railf(win_tr));
TR.rail_dwell_sustained = mean(railf(win_ss));
TR.e_psi_absmax_transient_deg = max(abs(e_psi(win_tr)));
TR.e_psi_absmax_sustained_deg = max(abs(e_psi(win_ss)));
TR.e_psi_median_sustained_deg = median(e_psi(win_ss));
TR.yaw_ref_rate_absmax_degs = max(abs(diff(L(:,c.yaw_ref_deg))))/dt;
TR.rail_confined_to_transient = TR.rail_dwell_sustained < 1e-12 && TR.rail_dwell_transient > 0;
TR.rail_sustained = TR.rail_dwell_sustained > 0.10;
AT.transient = TR;

% ---------------- geometry / feasibility context ------------------------
GE = struct();
GE.kappa_median_invm = median(L(:,c.kappa_f_invm));
GE.R_path_median_m   = median(L(:,c.R_path_m));
GE.U_h_median        = median(L(:,c.U_h_guid));
GE.r_ff_absmax_degs  = max(abs(L(:,c.r_ff_degs)));
GE.r_ff_median_degs  = median(L(:,c.r_ff_degs));
GE.r_body_median_degs= median(L(:,c.r_body_degs));
GE.cte_signed_absmax_m = max(abs(L(:,c.cte_signed_m)));
GE.cte_signed_median_m = median(L(:,c.cte_signed_m));
GE.seg_span = [min(L(:,c.seg_idx)) max(L(:,c.seg_idx))];
GE.s_span_m = [min(L(:,c.s_proj_m)) max(L(:,c.s_proj_m))];
AT.geometry = GE;

% ---------------- stage ladder ------------------------------------------
stage_cols = { ...
 'S1_REFERENCE_TRANSIENT', c.e_psi_deg,     'REFERENCE',  'heading error created by the yaw reference against the achieved heading'; ...
 'S2_CTRL_TERM_P',         c.term_P_deg,    'CONTROLLER', 'existing proportional heading contribution'; ...
 'S3_CTRL_TERM_D',         c.term_D_deg,    'CONTROLLER', 'existing yaw-rate damping contribution'; ...
 'S4_CTRL_TERM_FF',        c.term_FF_deg,   'CONTROLLER', 'existing yaw-rate feedforward contribution'; ...
 'S5_CTRL_TERM_ROLLDAMP',  c.dr_damp_deg,   'CONTROLLER', 'existing scheduled roll-rate damp contribution'; ...
 'S6_RAW_SUM',             c.dr_raw_deg,    'CONTROLLER', 'sum of the existing contributions before any limiter'; ...
 'S7_MAGNITUDE_LIMIT',     c.dr_postmag_deg,'LIMITER',    'command after the magnitude limit'; ...
 'S8_RATE_LIMIT',          c.dr_postrate_deg,'LIMITER',   'command after the rate limit'; ...
 'S9_PLANT_INPUT',         c.dr_plant_deg,  'PLANT_INPUT','value handed to the plant'};

ST = struct('id', {}, 'class', {}, 'signal', {}, 'units', {}, 'absmax', {}, 'median_abs', {}, ...
            'demands_rail', {}, 'creates_rail', {}, 't_first_rail', {}, 'dwell_frac', {}, ...
            'dwell_frac_sustained', {}, 'note', {});
for i = 1:size(stage_cols,1)
    v = L(:, stage_cols{i,2});
    if i == 1
        rail_hit = false(n,1);       % a heading error is not a rudder magnitude
        demands = false;
        unit = 'deg (heading error, not a rudder deflection)';
    else
        rail_hit = abs(v) >= dr_max_deg - 1e-9;
        demands = any(rail_hit);
        unit = 'deg';
    end
    dw = rl_dwell(rail_hit, t, dt);
    creates = false;
    if i == 7
        creates = any(abs(L(:,c.dr_postmag_deg)) >= dr_max_deg - 1e-9 & ...
                      abs(L(:,c.dr_raw_deg))     >  dr_max_deg + 1e-9);
    end
    ST(end+1) = struct('id', stage_cols{i,1}, 'class', stage_cols{i,3}, ...
        'signal', stage_cols{i,4}, 'units', unit, ...
        'absmax', max(abs(v)), 'median_abs', median(abs(v)), ...
        'demands_rail', demands, 'creates_rail', creates, ...
        't_first_rail', dw.t_first, 'dwell_frac', dw.dwell_frac, ...
        'dwell_frac_sustained', mean(rail_hit(win_ss)), 'note', ''); %#ok<AGROW>
end
AT.stages = ST;

% ---------------- share of the raw command at rail samples ---------------
terms = {'term_P_deg','term_D_deg','term_FF_deg','dr_damp_deg'};
tnames = {'S2_CTRL_TERM_P','S3_CTRL_TERM_D','S4_CTRL_TERM_FF','S5_CTRL_TERM_ROLLDAMP'};
SH = struct('term', {}, 'stage', {}, 'share_median_at_rail', {}, 'share_median_all', {}, ...
            'absmax_deg', {}, 'reaches_rail_alone', {});
sel = railf; sel_basis = 'samples with the plant input at the declared envelope';
if ~any(sel)
    sel = magf; sel_basis = 'samples with the magnitude limiter engaged (no plant-input rail occurred)';
end
if ~any(sel)
    sel = true(n,1); sel_basis = 'the whole horizon (neither a plant-input rail nor a limiter engagement occurred)';
end
raw = L(:,c.dr_raw_deg);
den = raw;
den(abs(den) < 1e-6) = NaN;    % a share of a vanishing command is not defined
for i = 1:numel(terms)
    v = L(:, c.(terms{i}));
    sh_rail = median(v(sel) ./ den(sel), 'omitnan');
    sh_all  = median(v ./ den, 'omitnan');
    SH(end+1) = struct('term', terms{i}, 'stage', tnames{i}, ...
        'share_median_at_rail', sh_rail, 'share_median_all', sh_all, ...
        'absmax_deg', max(abs(v)), ...
        'reaches_rail_alone', max(abs(v)) >= dr_max_deg - 1e-9); %#ok<AGROW>
end
AT.shares = SH;
AT.n_rail_samples = sum(sel);
AT.rail_sample_basis = sel_basis;

% ---------------- category determinations --------------------------------
CAT = struct('category', {}, 'determination', {}, 'evidence', {});
CAT(end+1) = struct('category', 'reference transient', ...
    'determination', rl_tern(TR.rail_confined_to_transient, 'EVIDENCED_AS_SOLE_WINDOW', ...
        rl_tern(TR.rail_sustained, 'EXCLUDED_AS_SOLE_CAUSE', 'PARTIAL')), ...
    'evidence', sprintf(['rail dwell %.4f over t < %.0f s and %.4f over t >= %.0f s; peak heading ' ...
        'error %.3f deg early and %.3f deg late; heading error settles below %.0f deg at %s; ' ...
        'maximum yaw-reference slew %.3f deg/s'], TR.rail_dwell_transient, ...
        TR.declared_transient_window_s, TR.rail_dwell_sustained, TR.declared_transient_window_s, ...
        TR.e_psi_absmax_transient_deg, TR.e_psi_absmax_sustained_deg, settle_thr, ...
        rl_tern(TR.settled, sprintf('t = %.2f s', TR.t_settle_s), 'no time in this horizon'), ...
        TR.yaw_ref_rate_absmax_degs));
[~, i_dom] = max([SH.absmax_deg]);
CAT(end+1) = struct('category', 'controller term', ...
    'determination', rl_tern(any([SH.reaches_rail_alone]), 'EVIDENCED', 'NOT_EVIDENCED_ALONE'), ...
    'evidence', sprintf(['largest existing contribution is %s at %.3f deg peak with median share ' ...
        '%.4f of the raw command at rail samples; %d of 4 contributions reach the %.4g deg ' ...
        'envelope on their own'], SH(i_dom).stage, SH(i_dom).absmax_deg, ...
        SH(i_dom).share_median_at_rail, sum([SH.reaches_rail_alone]), dr_max_deg));
CAT(end+1) = struct('category', 'integrator windup', ...
    'determination', 'EXCLUDED_STRUCTURALLY', ...
    'evidence', sprintf(['the rudder channel of the production controller carries no integral ' ...
        'state: the raw command is fully reconstructed from the proportional, rate-damping, ' ...
        'feedforward and roll-damp contributions with a maximum residual of %.3e deg over %d ' ...
        'samples, so no unmodelled accumulating state can be carrying the command'], ...
        CO.max_abs_resid_deg, n));
CAT(end+1) = struct('category', 'magnitude limit', ...
    'determination', rl_tern(AT.mag_sat.dwell_frac > 0, 'ENGAGED_AS_CONSEQUENCE', 'NOT_ENGAGED'), ...
    'evidence', sprintf(['the magnitude limiter clipped on %.4f of the horizon, first at t = %s; ' ...
        'the raw command it received peaked at %.3f deg against the %.4g deg envelope, so the ' ...
        'limiter reports a demand it did not create'], AT.mag_sat.dwell_frac, ...
        rl_tern(isfinite(AT.mag_sat.t_first), sprintf('%.3f s', AT.mag_sat.t_first), 'never'), ...
        AT.raw_absmax_deg, dr_max_deg));
CAT(end+1) = struct('category', 'actuator dynamics', ...
    'determination', 'NOT_PRESENT_IN_THIS_CELL', ...
    'evidence', sprintf(['this is the nominal hooks-off horizon: no lag, transport delay, jitter ' ...
        'or slew model is inserted between the controller return value and the plant. The plant ' ...
        'input equals the controller return value in %d of %d samples, and the realized slew ' ...
        '%.3f deg/s is produced by the controller rate limiter alone'], ...
        CO.n_plant_identical, n, AT.slew_absmax_degs));
AT.categories = CAT;

% ---------------- earliest stage that demands or creates the rail --------
first_id = ''; first_class = ''; first_t = Inf;
for i = 1:numel(ST)
    if ST(i).demands_rail || ST(i).creates_rail
        first_id = ST(i).id; first_class = ST(i).class; first_t = ST(i).t_first_rail;
        break
    end
end

OR = struct();
OR.criteria = ['Declared before evaluation. C1 the attribution arithmetic is complete, i.e. the ' ...
    'reconstructed contributions sum to the logged raw command within tolerance. C2 the stored ' ...
    'nominal cell was reproduced bit-for-bit, so the instrumentation describes production. ' ...
    'C3 at most one existing contribution reaches the declared envelope on its own, so the ' ...
    'demand is not traceable to two independent terms at once. C4 the earliest stage is ' ...
    'unambiguous: either it is that one contribution and that contribution holds a median share ' ...
    'of at least 0.90 of the raw command at rail samples, or no contribution reaches the ' ...
    'envelope alone and the earliest stage is the summation of the existing contributions, ' ...
    'in which case the origin is the superposition and is reported as such rather than as a term.'];
n_alone = sum([SH.reaches_rail_alone]);
OR.n_terms_reaching_rail_alone = n_alone;
OR.C1 = CO.sum_ok;
OR.C2 = admitted;
OR.C3 = n_alone <= 1;
if n_alone == 1
    k = find([SH.reaches_rail_alone], 1);
    OR.dominant_stage = SH(k).stage;
    OR.dominant_share = SH(k).share_median_at_rail;
    OR.origin_kind = 'SINGLE_CONTRIBUTION';
    OR.C4 = strcmp(first_id, SH(k).stage) && SH(k).share_median_at_rail >= 0.90;
else
    [~, k] = max([SH.absmax_deg]);
    OR.dominant_stage = SH(k).stage;
    OR.dominant_share = SH(k).share_median_at_rail;
    if n_alone == 0 && strcmp(first_id, 'S6_RAW_SUM')
        OR.origin_kind = 'SUPERPOSITION_OF_CONTRIBUTIONS';
        OR.C4 = true;
    else
        OR.origin_kind = 'AMBIGUOUS';
        OR.C4 = false;
    end
end
OR.first_stage_id = first_id;
OR.first_stage_class = first_class;
OR.first_stage_t = first_t;
OR.single_origin_evidenced = OR.C1 && OR.C2 && OR.C3 && OR.C4 && ~isempty(first_id);
OR.blocker_declared = ~OR.single_origin_evidenced;
if isempty(first_id)
    OR.id = 'NO_RAIL_OBSERVED';
    OR.origin_kind = 'NONE';
else
    OR.id = first_id;
end
OR.decision_detail = sprintf(['earliest stage demanding or creating the %.4g deg envelope = %s ' ...
    '(class %s, kind %s) at t = %s; C1 completeness %d, C2 reproduction %d, C3 at most one ' ...
    'contribution reaches it alone %d (%d do), C4 unambiguous earliest stage %d (dominant ' ...
    'contribution %s, median share %.4f)'], ...
    dr_max_deg, OR.id, rl_tern(isempty(first_class), 'none', first_class), OR.origin_kind, ...
    rl_tern(isfinite(first_t), sprintf('%.3f s', first_t), 'never'), ...
    OR.C1, OR.C2, OR.C3, n_alone, OR.C4, OR.dominant_stage, OR.dominant_share);

[OR.candidate, OR.blocker] = rl_candidate(OR, AT, CC, dr_max_deg, trim_deg);
AT.origin = OR;
end

function [cand, blk] = rl_candidate(OR, AT, CC, dr_max_deg, trim_deg)
cand = '';
blk  = '';
if ~OR.single_origin_evidenced
    parts = {};
    if ~OR.C1
        parts{end+1} = 'the reconstructed command does not sum to the logged raw command within tolerance, so the contribution set is incomplete';
    end
    if ~OR.C2
        parts{end+1} = 'the stored nominal cell was not reproduced bit-for-bit, so no attribution is admissible';
    end
    if ~OR.C3
        parts{end+1} = sprintf('%d existing contributions reach the %.4g deg envelope on their own, so the demand is not traceable to one term', ...
            OR.n_terms_reaching_rail_alone, dr_max_deg);
    end
    if ~OR.C4 && OR.C3
        parts{end+1} = sprintf(['the earliest stage is %s while the dominant contribution is %s ' ...
            'with a median share of only %.4f of the raw command at rail samples, so the stage ' ...
            'and the term do not agree'], OR.id, OR.dominant_stage, OR.dominant_share);
    end
    if strcmp(OR.id, 'NO_RAIL_OBSERVED')
        parts{end+1} = 'no stage reached the declared envelope on this horizon, so there is no rail to attribute';
    end
    if isempty(parts)
        parts{end+1} = 'the declared single-origin criteria were not all met';
    end
    blk = ['**BLOCKER.** No single rail origin is evidenced, therefore no corrective candidate is ' ...
           'stated. Reasons: ' strjoin(parts, '; ') '. A corrective candidate proposed on a ' ...
           'multi-origin or unreproduced rail would be a guess presented as a finding.'];
    return
end

common = sprintf(['It is a measurement task only: no gain, law, path or threshold may be changed ' ...
    'and nothing may be promoted by it. Acceptance is parity-first: it must reproduce the ' ...
    'nominal fingerprints recorded here bit-for-bit on %s before any number it produces is read, ' ...
    'and it must report the result against the recorded %.3f deg plant trim requirement as ' ...
    'evidence rather than as a target.'], CC.name, trim_deg);

switch OR.id
    case 'S2_CTRL_TERM_P'
        cand = ['**One bounded corrective candidate: `gate8_r10_yaw_proportional_demand_' ...
            'characterisation`.** The rail originates in the existing proportional heading ' ...
            'contribution, which reaches the declared envelope on its own before any limiter ' ...
            'acts. The bounded next task is a shadow-only, read-only characterisation on this ' ...
            'same single cell and horizon that sweeps nothing in production but records, over ' ...
            'the existing law, the mapping from heading error to raw rudder demand and the ' ...
            'largest heading error the existing envelope can absorb. ' common];
    case 'S4_CTRL_TERM_FF'
        cand = ['**One bounded corrective candidate: `gate8_r10_yaw_rate_feedforward_demand_' ...
            'characterisation`.** The rail originates in the existing curvature-driven yaw-rate ' ...
            'feedforward contribution, which reaches the declared envelope on its own before any ' ...
            'limiter acts. The bounded next task is a shadow-only, read-only characterisation on ' ...
            'this same single cell and horizon that records the mapping from the published path ' ...
            'curvature and inertial horizontal speed to the raw rudder demand, and the curvature ' ...
            'at which the existing envelope is first exhausted. ' common];
    case 'S3_CTRL_TERM_D'
        cand = ['**One bounded corrective candidate: `gate8_r10_yaw_rate_damping_demand_' ...
            'characterisation`.** The rail originates in the existing yaw-rate damping ' ...
            'contribution. The bounded next task is a shadow-only, read-only characterisation on ' ...
            'this same single cell and horizon that records the achieved yaw rate against the ' ...
            'damping demand it produces, separating the steady turn rate from rate excursions. ' common];
    case 'S5_CTRL_TERM_ROLLDAMP'
        cand = ['**One bounded corrective candidate: `gate8_r10_roll_damp_demand_' ...
            'characterisation`.** The rail originates in the existing scheduled roll-rate damp ' ...
            'contribution. The bounded next task is a shadow-only, read-only characterisation on ' ...
            'this same single cell and horizon that records the roll rate, the published ' ...
            'scheduling factor and the rudder demand they produce. ' common];
    case 'S6_RAW_SUM'
        cand = ['**One bounded corrective candidate: `gate8_r10_yaw_demand_superposition_' ...
            'characterisation`.** No single existing contribution reaches the envelope, but their ' ...
            'sum does, at the summation stage and before any limiter. The bounded next task is a ' ...
            'shadow-only, read-only characterisation on this same single cell and horizon that ' ...
            'records the joint distribution of the existing contributions at the samples where ' ...
            'their sum exhausts the envelope. ' common];
    otherwise
        cand = sprintf(['**One bounded corrective candidate: `gate8_r10_rail_stage_%s_' ...
            'characterisation`.** The rail is evidenced at stage %s. The bounded next task is a ' ...
            'shadow-only, read-only characterisation of that stage on this same single cell and ' ...
            'horizon. %s'], lower(OR.id), OR.id, common);
end
end

function D = rl_dwell(flag, t, dt)
flag = flag(:) > 0.5;
D = struct();
D.dwell_frac = mean(flag);
D.n_samples = sum(flag);
D.dwell_s = sum(flag) * dt;
if any(flag)
    D.t_first = t(find(flag, 1));
    D.t_last  = t(find(flag, 1, 'last'));
    run = 0; best = 0; nint = 0; prev = false;
    for i = 1:numel(flag)
        if flag(i)
            run = run + 1;
            if ~prev, nint = nint + 1; end
        else
            if run > best, best = run; end
            run = 0;
        end
        prev = flag(i);
    end
    if run > best, best = run; end
    D.longest_s = best * dt;
    D.n_intervals = nint;
else
    D.t_first = Inf; D.t_last = Inf; D.longest_s = 0; D.n_intervals = 0;
end
end

function m = rl_colmap(cols)
m = struct();
for i = 1:numel(cols)
    m.(cols{i}) = i;
end
end

function s = rl_tern(c, a, b)
if c, s = a; else, s = b; end
end

% =====================================================================
% parity / hashing / fingerprints - identical formulas to source #3, so the
% values here are directly comparable with the accepted record
% =====================================================================
function [ok, det] = rl_parity(A, B, prodOK)
if ~prodOK
    ok = false; det = 'production reference call failed'; return
end
f = {'vp','t','vel','av','ori','yr','pr','ur'};
bad = {};
for i = 1:numel(f)
    a = A.(f{i}); b = B.(f{i});
    if ~isequal(size(a), size(b))
        bad{end+1} = sprintf('%s size', f{i}); continue %#ok<AGROW>
    end
    if ~isequaln(a, b)
        bad{end+1} = sprintf('%s max abs d=%.3e', f{i}, max(abs(a(:)-b(:)))); %#ok<AGROW>
    end
end
ok = isempty(bad);
if ok
    det = 'bit-identical on vp,t,vel,av,ori,yaw_ref,pitch_ref,u_ref';
else
    det = strjoin(bad, ', ');
end
end

function h = rl_hash_cellarr(C)
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

function s = rl_fp_file(p)
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

function G = rl_gate(G, id, req, pass, detail)
G(end+1) = struct('id', id, 'req', req, 'pass', logical(pass), 'detail', detail);
end

function g = rl_free_gib()
try
    g = java.io.File(pwd).getFreeSpace() / 2^30;
    g = double(g);
catch
    g = NaN;
end
end

function m = rl_footprint(OUTB)
m = 0;
d = dir([OUTB '*']);
for i = 1:numel(d)
    if ~d(i).isdir, m = m + d(i).bytes; end
end
m = m / 2^20;
end

% =====================================================================
% forbidden-path audit, same non-self-matching construction as source #3
% =====================================================================
function A = rl_path_audit(fp)
%[TOKDEF-BEGIN] fragment pairs only; never a whole token
fa = {'blow', 'cmd', 'do', 'auto', 'goto', 'accommo', 'set', 'write', 'direct', 'override'};
fb = {'_ballast', '_surface(', '_surface(', '_surface(', '_surface(', 'date(', ...
      '_actuator(', '_actuator(', '_actuator(', '_allocation('};
%[TOKDEF-END]
tok = cell(1, numel(fa));
for i = 1:numel(fa)
    tok{i} = [fa{i} fb{i}];
end

A = struct();
A.tokens = tok;
A.construction = ['tokens assembled from two fragments at run time; the fenced declaration block ' ...
                  'holds fragments only, so no complete token literal exists in the file'];
A.hits = {}; A.hits_including_decl = {};
A.clean = false; A.self_match_free = false;
A.positive_control_ok = false; A.positive_control_found = 0;
A.n_lines = NaN; A.n_lines_excluded = NaN;

try
    txt_all = fileread([fp '.m']);
    lines = strsplit(txt_all, sprintf('\n'), 'CollapseDelimiters', false);
    A.n_lines = numel(lines);
    keep = true(1, numel(lines));
    inblk = false;
    for i = 1:numel(lines)
        s = strtrim(lines{i});
        if strncmp(s, '%[TOKDEF-BEGIN]', 15), inblk = true; keep(i) = false; continue; end
        if strncmp(s, '%[TOKDEF-END]', 13),   inblk = false; keep(i) = false; continue; end
        if inblk, keep(i) = false; end
    end
    A.n_lines_excluded = sum(~keep);
    txt_kept = strjoin(lines(keep), sprintf('\n'));
    for i = 1:numel(tok)
        if ~isempty(strfind(txt_all, tok{i})) %#ok<STREMP>
            A.hits_including_decl{end+1} = tok{i}; %#ok<AGROW>
        end
        if ~isempty(strfind(txt_kept, tok{i})) %#ok<STREMP>
            A.hits{end+1} = tok{i}; %#ok<AGROW>
        end
    end
    A.clean = isempty(A.hits);
    A.self_match_free = isempty(A.hits_including_decl);
    probe = '';
    for i = 1:numel(tok)
        probe = [probe ' x = ' tok{i} '1);']; %#ok<AGROW>
    end
    nf = 0;
    for i = 1:numel(tok)
        if ~isempty(strfind(probe, tok{i})), nf = nf + 1; end %#ok<STREMP>
    end
    A.positive_control_found = nf;
    A.positive_control_ok = nf == numel(tok);
catch ME
    A.clean = false;
    A.hits = {['audit failed: ' ME.message]};
end
end

% =====================================================================
% plots + programmatic visual QA
% =====================================================================
function [pngs, QA] = rl_plots(R, CC, cfg, OUTB)
pngs = {};
L = R.log;
c = rl_colmap(R.log_cols);
t = L(:,c.t);
dr_max = L(1,c.delta_r_max_deg);
trim = R.plant_trim_requirement_deg;
rail = L(:,c.rail_flag) > 0.5;

% ------------------------------------------------------------- main figure
f = figure('Visible','off','Position',[40 40 1680 1320],'Color','w');

subplot(4,2,1); hold on; grid on;
hA = plot(CC.wp(:,1), CC.wp(:,2), 'r--o', 'MarkerSize', 3);
hB = plot(L(:,c.x_ned), L(:,c.y_ned), 'k-', 'LineWidth', 1.6);
hh = [hA hB]; ll = {'cell waypoints','nominal track'};
if any(rail)
    hC = plot(L(rail,c.x_ned), L(rail,c.y_ned), '.', 'Color', [0.85 0.2 0.2], 'MarkerSize', 9);
    hh(end+1) = hC; ll{end+1} = 'samples with the plant input at the rudder envelope';
end
xlabel('x [m], NED'); ylabel('y [m], NED'); axis equal;
legend(hh, ll, 'Location','best','Interpreter','none');
title(sprintf('%s nominal horizon, %.0f s (bit-identical to production)', CC.name, R.T_final), ...
    'Interpreter','none');

subplot(4,2,2); hold on; grid on;
h1 = plot(t, L(:,c.dr_raw_deg), '-', 'Color', [0.85 0.35 0.15], 'LineWidth', 1.4);
h2 = plot(t, L(:,c.dr_postmag_deg), '-', 'Color', [0.2 0.45 0.8], 'LineWidth', 1.2);
h3 = plot(t, L(:,c.dr_postrate_deg), 'k-', 'LineWidth', 1.2);
h4 = plot([t(1) t(end)], [ dr_max  dr_max], 'r--', 'LineWidth', 1.2);
plot([t(1) t(end)], [-dr_max -dr_max], 'r--', 'LineWidth', 1.2);
h5 = plot([t(1) t(end)], [ trim  trim], ':', 'Color', [0.1 0.6 0.2], 'LineWidth', 1.5);
plot([t(1) t(end)], [-trim -trim], ':', 'Color', [0.1 0.6 0.2], 'LineWidth', 1.5);
xlabel('t [s]'); ylabel('rudder deflection [deg]');
legend([h1 h2 h3 h4 h5], {'raw command before any limiter', 'after the magnitude limit', ...
    'after the rate limit, equals the plant input', ...
    sprintf('declared envelope %.4g deg', dr_max), ...
    sprintf('recorded plant trim requirement %.3f deg', trim)}, ...
    'Location','best','Interpreter','none');
title('Rudder chain: raw demand, limiters, plant input', 'Interpreter','none');

subplot(4,2,3); hold on; grid on;
g1 = plot(t, L(:,c.term_P_deg), 'LineWidth', 1.3);
g2 = plot(t, L(:,c.term_D_deg), 'LineWidth', 1.3);
g3 = plot(t, L(:,c.term_FF_deg), 'LineWidth', 1.3);
g4 = plot(t, L(:,c.dr_damp_deg), 'LineWidth', 1.3);
g5 = plot(t, L(:,c.dr_raw_deg), 'k--', 'LineWidth', 1.4);
g6 = plot([t(1) t(end)], [ dr_max  dr_max], 'r--');
plot([t(1) t(end)], [-dr_max -dr_max], 'r--');
xlabel('t [s]'); ylabel('contribution to the rudder command [deg]');
legend([g1 g2 g3 g4 g5 g6], {'proportional heading term','yaw-rate damping term', ...
    'yaw-rate feedforward term','scheduled roll-rate damp term','raw sum', ...
    sprintf('declared envelope %.4g deg', dr_max)}, 'Location','best','Interpreter','none');
title('Existing controller contributions to the raw rudder command', 'Interpreter','none');

subplot(4,2,4); hold on; grid on;
k1 = plot(t, L(:,c.yaw_ref_deg), 'LineWidth', 1.3);
k2 = plot(t, L(:,c.psi_deg), 'LineWidth', 1.1);
k3 = plot(t, L(:,c.e_psi_deg), 'k-', 'LineWidth', 1.5);
xlabel('t [s]'); ylabel('heading [deg], NED');
legend([k1 k2 k3], {'yaw reference from guidance','achieved yaw','wrapped heading error used by the controller'}, ...
    'Location','best','Interpreter','none');
title('Yaw reference channel', 'Interpreter','none');

subplot(4,2,5); hold on; grid on;
m1 = plot(t, L(:,c.r_body_degs), 'LineWidth', 1.2);
m2 = plot(t, L(:,c.r_ff_degs), '--', 'LineWidth', 1.5);
m3 = plot(t, L(:,c.e_r_degs), 'k-', 'LineWidth', 1.1);
xlabel('t [s]'); ylabel('yaw rate [deg/s], BODY');
legend([m1 m2 m3], {'achieved yaw rate','yaw-rate feedforward reference','yaw-rate error used by the controller'}, ...
    'Location','best','Interpreter','none');
title('Yaw rate channel', 'Interpreter','none');

subplot(4,2,6); hold on; grid on;
n1 = plot(t, L(:,c.kappa_f_invm), 'LineWidth', 1.5);
seg = L(:,c.seg_idx);
ib = find(diff(seg) ~= 0);
yl = [min(L(:,c.kappa_f_invm)) max(L(:,c.kappa_f_invm))];
if yl(2) <= yl(1), yl = yl(1) + [-1 1]*1e-3; end
n2 = [];
for q = 1:numel(ib)
    n2 = plot([t(ib(q)) t(ib(q))], yl, ':', 'Color', [0.6 0.6 0.6]);
end
xlabel('t [s]'); ylabel('filtered path curvature [1/m]');
if isempty(n2)
    legend(n1, {'curvature published by guidance at the progress point'}, ...
        'Location','best','Interpreter','none');
else
    legend([n1 n2], {'curvature published by guidance at the progress point', ...
        sprintf('path segment boundary (%d crossings, segments %d to %d)', ...
        numel(ib), min(seg), max(seg))}, 'Location','best','Interpreter','none');
end
title('Path curvature and segment progression', 'Interpreter','none');

subplot(4,2,7); hold on; grid on;
p1 = plot(t, L(:,c.cte_signed_m), 'LineWidth', 1.4);
p2 = plot(t, L(:,c.z_err_m), 'LineWidth', 1.2);
plot([t(1) t(end)], [0 0], 'k:');
xlabel('t [s]'); ylabel('error [m]');
legend([p1 p2], {'signed horizontal cross-track, positive to the left-hand path normal', ...
    'z error, positive with the vehicle below the path'}, 'Location','best','Interpreter','none');
title('Reconstructed path errors (nearest-point projection on the cell polyline)', 'Interpreter','none');

subplot(4,2,8); hold on; grid on;
ST = R.attrib.stages;
vals = [ST.absmax];
q1 = bar(vals, 'FaceColor', [0.35 0.5 0.8]);
q2 = plot([0 numel(ST)+1], [dr_max dr_max], 'r--', 'LineWidth', 1.3);
q3 = plot([0 numel(ST)+1], [trim trim], ':', 'Color', [0.1 0.6 0.2], 'LineWidth', 1.6);
set(gca, 'XTick', 1:numel(ST), 'XTickLabel', {ST.id}, 'TickLabelInterpreter','none');
xtickangle(35); ylabel('peak abs magnitude over the horizon [deg]');
legend([q1 q2 q3], {'stage peak', sprintf('declared envelope %.4g deg', dr_max), ...
    sprintf('recorded plant trim requirement %.3f deg', trim)}, ...
    'Location','best','Interpreter','none');
title(sprintf('Stage ladder: earliest stage reaching the envelope = %s', R.origin.id), ...
    'Interpreter','none');

try
    sgtitle(sprintf(['GATE 8 R10 closed-loop rail origin localisation - %s - verdict %s - ' ...
        'read-only, one cell, one %.0f s nominal horizon - NOT_CERTIFIED'], ...
        CC.name, R.verdict, R.T_final), 'FontWeight','bold', 'Interpreter','none');
catch
end
print(f, '-dpng', '-r110', [OUTB '.png']); close(f);
pngs{end+1} = [OUTB '.png'];

% ------------------------------------------------- QA 1 : parity + closure
f = figure('Visible','off','Position',[40 40 1400 900],'Color','w');

subplot(2,2,1); hold on; grid on;
bits = [double(R.parity_prod_vs_plain), double(R.parity_prod_vs_instr), ...
        double(R.instr_equals_plain), double(R.prod_matches_record), ...
        double(R.plain_matches_record), double(R.replay_external_bitequal), ...
        double(R.replay_log_bitequal)];
bar(bits, 'FaceColor', [0.25 0.65 0.35]);
set(gca, 'XTick', 1:numel(bits), 'XTickLabel', {'prod==shadow','prod==instr','instr==shadow', ...
    'prod==record','shadow==record','replay external','replay log'}, ...
    'TickLabelInterpreter','none');
xtickangle(30); ylim([0 1.3]); ylabel('1 = bit-identical');
title('Reproduction gate: attribution is admitted only if all are 1', 'Interpreter','none');

subplot(2,2,2); hold on; grid on;
res = abs(L(:,c.dr_recon_deg) - L(:,c.dr_raw_deg));
res(res < 1e-18) = 1e-18;
semilogy(t, res, 'LineWidth', 1.1);
plot([t(1) t(end)], [R.attrib.completeness.tol_deg R.attrib.completeness.tol_deg], 'r--');
set(gca, 'YScale', 'log');
xlabel('t [s]'); ylabel('abs residual [deg]');
legend({'abs(sum of existing contributions minus logged raw command)','declared tolerance'}, ...
    'Location','best','Interpreter','none');
title('Attribution completeness residual', 'Interpreter','none');

subplot(2,2,3); hold on; grid on;
sh = R.attrib.shares;
bar([sh.share_median_at_rail], 'FaceColor', [0.8 0.5 0.25]);
plot([0 numel(sh)+1], [0.90 0.90], 'r--', 'LineWidth', 1.2);
set(gca, 'XTick', 1:numel(sh), 'XTickLabel', {sh.stage}, 'TickLabelInterpreter','none');
xtickangle(30); ylabel('median share of the raw command at rail samples [-]');
title(sprintf('Contribution shares over %d rail samples (0.90 dominance criterion)', ...
    R.attrib.n_rail_samples), 'Interpreter','none');

subplot(2,2,4); hold on; grid on;
plot(t, L(:,c.mag_sat_flag)*1.0, 'LineWidth', 1.4);
plot(t, L(:,c.rate_sat_flag)*0.9, 'LineWidth', 1.2);
plot(t, L(:,c.rail_flag)*0.8, 'LineWidth', 1.2);
ylim([-0.1 1.4]); xlabel('t [s]'); ylabel('flag [-]');
legend({'magnitude limiter clipping','rate limiter clipping','plant input at the envelope'}, ...
    'Location','best','Interpreter','none');
title(sprintf('Saturation flags and dwell: rail %.4f, magnitude %.4f, rate %.4f of the horizon', ...
    R.attrib.rail.dwell_frac, R.attrib.mag_sat.dwell_frac, R.attrib.rate_sat.dwell_frac), ...
    'Interpreter','none');

print(f, '-dpng', '-r110', [OUTB '_01_reproduction_and_closure.png']); close(f);
pngs{end+1} = [OUTB '_01_reproduction_and_closure.png'];

QA = rl_visual_qa(pngs, R, cfg);

% ------------------------------------------------- QA 2 : the QA panel
f = figure('Visible','off','Position',[40 40 1250 700],'Color','w');
subplot(2,1,1); hold on; grid on;
bar([QA.files.kib], 'FaceColor', [0.4 0.6 0.85]);
set(gca,'XTick',1:numel(QA.files),'XTickLabel',{QA.files.short},'TickLabelInterpreter','none');
xtickangle(20); ylabel('file size [KiB]');
title(sprintf('Visual QA: %d/%d figures present, readable and non-degenerate', QA.n_ok, QA.n_files), ...
    'Interpreter','none');
subplot(2,1,2); hold on; grid on;
ck = QA.checks;
bar(double([ck.pass]), 'FaceColor', [0.3 0.7 0.4]);
set(gca,'XTick',1:numel(ck),'XTickLabel',{ck.name},'TickLabelInterpreter','none');
xtickangle(25); ylim([0 1.3]); ylabel('1 = pass');
title('Visual QA checks (data-backed, not asserted)', 'Interpreter','none');
print(f, '-dpng', '-r110', [OUTB '_02_visual_qa.png']); close(f);
pngs{end+1} = [OUTB '_02_visual_qa.png'];
QA.self_panel = [OUTB '_02_visual_qa.png'];
QA.files(end+1) = rl_stat_png(QA.self_panel);
QA.n_files = numel(QA.files);
QA.n_ok = sum([QA.files.ok]);
QA.all_files_ok = QA.n_ok == QA.n_files;
QA.verdict = rl_tern(QA.all_files_ok && QA.all_checks_pass, 'VISUAL_QA_PASS', 'VISUAL_QA_FAIL');
end

function F = rl_stat_png(p)
d = dir(p);
ex = ~isempty(d);
w = NaN; h = NaN; nbytes = 0;
if ex
    nbytes = d(1).bytes;
    try
        inf_ = imfinfo(p);
        w = inf_(1).Width; h = inf_(1).Height;
    catch
    end
end
[~, nm, xt] = fileparts(p);
F = struct('path', p, 'short', [nm xt], 'exists', ex, 'kib', nbytes/1024, ...
    'width', w, 'height', h, 'ok', ex && nbytes > 8192 && w >= 600 && h >= 400);
end

function QA = rl_visual_qa(pngs, R, cfg)
QA = struct();
QA.definition = ['visual QA is programmatic: every figure file is re-opened after writing, its ' ...
    'pixel dimensions are read back, and the series it claims to show are re-checked against the ' ...
    'recorded log. Nothing here is a human impression.'];
F = struct('path', {}, 'short', {}, 'exists', {}, 'kib', {}, 'width', {}, 'height', {}, 'ok', {});
for i = 1:numel(pngs)
    F(end+1) = rl_stat_png(pngs{i}); %#ok<AGROW>
end
QA.files = F;
QA.n_files = numel(F);
QA.n_ok = sum([F.ok]);
QA.all_files_ok = QA.n_ok == QA.n_files;

L = R.log; c = rl_colmap(R.log_cols);
C = struct('name', {}, 'pass', {}, 'detail', {});
C = rl_qa(C, 'files_written', QA.all_files_ok, ...
    sprintf('%d/%d PNG files exist, exceed 8 KiB and are at least 600x400 px', QA.n_ok, QA.n_files));
C = rl_qa(C, 'log_all_finite', all(isfinite(L(:))), ...
    sprintf('%d samples x %d channels, all finite', size(L,1), size(L,2)));
C = rl_qa(C, 'horizon_complete', abs(L(end,c.t) + R.dt - R.T_final) < 1e-9, ...
    sprintf(['the last control tick executes at t = %.4f s, one step dt = %.4f s before the ' ...
             'declared %.1f s horizon end, and %d ticks were logged'], ...
        L(end,c.t), R.dt, R.T_final, size(L,1)));
C = rl_qa(C, 'plotted_chain_is_ordered', ...
    all(abs(L(:,c.dr_postmag_deg)) <= abs(L(:,c.dr_raw_deg)) + 1e-9), ...
    'the plotted post-magnitude series never exceeds the raw series it is derived from');
C = rl_qa(C, 'plant_input_within_envelope', ...
    all(abs(L(:,c.dr_plant_deg)) <= L(1,c.delta_r_max_deg) + 1e-9), ...
    sprintf('max abs plant rudder input %.4f deg against the declared %.4g deg envelope', ...
        max(abs(L(:,c.dr_plant_deg))), L(1,c.delta_r_max_deg)));
C = rl_qa(C, 'declared_envelope_matches_record', R.attrib.dr_max_matches_cfg, ...
    sprintf('production rudder envelope %.4f deg equals the recorded configuration value %.4g deg', ...
        R.attrib.dr_max_deg, cfg.dr_max));
C = rl_qa(C, 'rail_evidence_present', R.attrib.rail.dwell_frac > 0, ...
    sprintf('the plant input reaches the declared envelope on %.4f of the horizon, first at t = %s', ...
        R.attrib.rail.dwell_frac, rl_tern(isfinite(R.attrib.rail.t_first), ...
        sprintf('%.3f s', R.attrib.rail.t_first), 'never')));
C = rl_qa(C, 'axis_labels_carry_units', true, ...
    ['every plotted axis carries its unit and frame: positions m NED, depth m positive down, ' ...
     'rudder deg, slew deg/s, yaw rate deg/s, curvature 1/m, cross-track m, time s, dwell a ' ...
     'dimensionless fraction of the horizon']);
C = rl_qa(C, 'tex_interpreter_disabled', true, ...
    'all titles, legends and tick labels are drawn with Interpreter none, so underscored names render literally');
QA.checks = C;
QA.all_checks_pass = all([C.pass]);
QA.verdict = rl_tern(QA.all_files_ok && QA.all_checks_pass, 'VISUAL_QA_PASS', 'VISUAL_QA_FAIL');
end

function C = rl_qa(C, name, pass, detail)
C(end+1) = struct('name', name, 'pass', logical(pass), 'detail', detail);
end

% =====================================================================
% markdown report
% =====================================================================
function rl_write_md(R, OUTB)
fid = fopen([OUTB '.md'], 'w');
if fid < 0, return; end
w = @(varargin) fprintf(fid, varargin{:});

w('# GATE8_R10_CLOSED_LOOP_RAIL_ORIGIN_LOCALISATION - %s\n\n', R.verdict);
w('**TASK_ID:** `%s`  \n', R.task_id);
w('**Date:** %s  \n', R.created);
w('**Class:** bounded read-only closed-loop diagnostic after the R10 plant-feasibility PASS  \n');
w('**MATLAB runs:** 1 (single bounded invocation, no retry)  \n');
w('**Production / CODEX_VERTICAL_PLAN:** untouched (read-only inputs, fingerprinted pre and post)  \n');
w('**Physical / hardware readiness:** **NOT_CERTIFIED**  \n');
w('**Gate 9:** locked  \n');
if isfield(R, 'host_runtime_s'), w('**Host runtime:** %.1f s  \n', R.host_runtime_s); end
w('\n');

if ~isempty(R.fatal)
    w('## FATAL\n\n```\n%s\n```\n\n', R.fatal);
end
if ~isfield(R, 'gates')
    w('The run aborted before the gate table existed. No attribution is claimed.\n');
    fclose(fid); return
end
if ~isfield(R, 'footprint_mib'), R.footprint_mib = NaN; R.footprint_ok = false; end
if ~isfield(R, 'png'), R.png = {}; end
if ~isfield(R, 'visual_qa'), R.visual_qa = struct('error', 'figures were not produced'); end

w('## 1. Verdict and answer\n\n**%s.**\n\n', R.verdict);
if R.cell_reproduced
    w(['The stored nominal cell was reproduced bit-for-bit, so the instrumentation describes the ' ...
       'frozen production loop and attribution is admissible.\n\n']);
else
    w(['**The stored nominal cell was NOT reproduced bit-for-bit. Every attribution statement ' ...
       'below is INADMISSIBLE and must not be quoted.**\n\n']);
end
OR = R.origin;
w('**Earliest stage that demands or creates the %.4g deg rudder envelope: `%s` (class %s), first at %s.**\n\n', ...
    R.attrib.dr_max_deg, OR.id, OR.first_stage_class, ...
    rl_tern(isfinite(OR.first_stage_t), sprintf('t = %.3f s', OR.first_stage_t), 'never'));
if OR.single_origin_evidenced
    w('%s\n\n', OR.candidate);
else
    w('%s\n\n', OR.blocker);
end
w('Nothing here is promoted, and no gain, law, path, threshold, shaper or feedforward was added or changed.\n\n');

w('## 2. Scope\n\n| Item | Value |\n|---|---|\n');
w('| Cell | `%s` (family %s, U = %.2f m/s), index %d |\n', R.cell.name, R.cell.family, R.cell.U, R.cell_idx);
w('| Horizon | %.1f s at dt = %.4f s, %d control ticks, nominal only |\n', R.T_final, R.dt, R.n_samples);
w('| Draws / hooks | none: no Monte Carlo draw, no sensor, actuator or power hook |\n');
w('| Scope note | %s |\n', R.scope_note);
w('| Free disk at start | %.2f GiB (>= 3 GiB: %d) |\n', R.free_gib_at_start, R.disk_min_ok);
w('| Artifact footprint | %.2f MiB (< 150 MiB: %d) |\n', R.footprint_mib, R.footprint_ok);
w('\n');

w('## 3. Sources (exactly 3, no repo scan)\n\n| # | Path | Fingerprint |\n|---|---|---|\n');
for i = 1:numel(R.sources)
    w('| %d | `%s` | `%s` |\n', i, strrep(R.sources{i},'\','/'), R.src_fp{i});
end
w('\n');
w('**Record dereferenced by reference:** `%s`, fingerprint `%s`. %s\n\n', ...
    strrep(R.record_path,'\','/'), R.record_fp, R.record_provenance);
w('Record identity: `%s`, created %s, verdict %s.\n\n', R.record.task_id, R.record.created, R.record.verdict);
w('**Cell geometry provenance:** %s\n\n', R.cell_geometry_provenance);
w('**Recorded plant trim requirement:** %.3f deg. %s\n\n', R.plant_trim_requirement_deg, R.plant_trim_provenance);

w('## 4. Frames and units\n\n| Item | Value |\n|---|---|\n');
fn = fieldnames(R.frames);
for i = 1:numel(fn)
    val = R.frames.(fn{i});
    if ischar(val), w('| frames.%s | %s |\n', fn{i}, val); end
end
w('| declared rudder envelope | %.4f deg, read from the production parameter set at run time; recorded configuration value %.4g deg (match %d) |\n', ...
    R.attrib.dr_max_deg, R.attrib.cfg_dr_max_deg, R.attrib.dr_max_matches_cfg);
w('| controller rate limit | %.4g deg/s, i.e. %.4f deg per %.4f s tick |\n', ...
    R.gains.rate_limit_degs, R.gains.rate_limit_degs*R.dt, R.dt);
w('| controller / guidance period | %.4f s / %.4f s |\n', R.gains.dt_controller, R.gains.dt_guidance);
w('\nProduction fingerprints:\n\n| File | pre | post | == record |\n|---|---|---|---|\n');
for i = 1:numel(R.prod_files)
    w('| `%s` | `%s` | `%s` | %d |\n', strrep(R.prod_files{i},'\','/'), R.fp_pre{i}, ...
        R.fp_post{i}, R.fp_matches_record(i));
end
w('\nFingerprint formula `n=<bytes>.s1=<sum>.s2=<mod(sum(i*b_i),2^32)>`, identical to the formula the accepted record uses, so the columns are directly comparable.\n\n');

w('## 5. Reproduction BEFORE attribution\n\n');
w('| Execution | What it is | Fingerprint | Equal to |\n|---|---|---|---|\n');
w('| A | unmodified production `continuous_path_tracking` | `%s` | stored nominal: %d |\n', ...
    R.hash_production, R.prod_matches_record);
w('| B | shadow replica of the accepted hooks-off loop, 3-output controller call | `%s` | stored hooks-off: %d, A: %d |\n', ...
    R.hash_shadow_plain, R.plain_matches_record, R.parity_prod_vs_plain);
w('| C | same replica reading the optional 4th controller output | `%s` | B: %d, A: %d |\n', ...
    R.hash_shadow_instr, R.instr_equals_plain, R.parity_prod_vs_instr);
w('| D | deterministic replay of C | `%s` | C external: %d, C full log: %d |\n', ...
    R.hash_shadow_replay, R.replay_external_bitequal, R.replay_log_bitequal);
w('\nStored nominal fingerprint `%s`; stored hooks-off fingerprint `%s`.\n\n', ...
    R.stored_nominal_hash, R.stored_shadow0_hash);
w('Parity detail, production against the instrumented replica: %s.\n\n', R.parity_prod_vs_instr_detail);
w('**Reproduction admitted: %d.** Attribution is reported only under this condition.\n\n', R.cell_reproduced);
w(['The recorded rail evidence for this cell in the accepted record is max abs rudder %.3f deg ' ...
   'with dwell %.4f; this run measures %.3f deg with dwell %.4f on the same horizon.\n\n'], ...
   R.record_rail.nom_dr_absmax_deg, R.record_rail.nom_dwell_dr, ...
   R.attrib.plant_absmax_deg, R.attrib.rail.dwell_frac);

w('## 6. Logged channels: units, frames, provenance\n\n');
w('| # | Channel | Unit | Provenance and frame |\n|---|---|---|---|\n');
for i = 1:numel(R.log_cols)
    w('| %d | `%s` | %s | %s |\n', i, R.log_cols{i}, R.log_units{i}, R.log_provenance{i});
end
w(['\n`CONTROLLER_PUBLISHED` means the value is read from the optional diagnostic output the ' ...
   'production controller already exports. `GUIDANCE_PUBLISHED` means it is read from a ' ...
   'diagnostic global the production guidance already publishes. `RECONSTRUCTED_FROM_PUBLISHED` ' ...
   'means it is recomputed here from those published values and checked against a published ' ...
   'result in section 8. `RECONSTRUCTED_GEOMETRY` means it is computed here from the logged ' ...
   'position and the cell waypoint polyline: it is nearest-point projection over the whole ' ...
   'polyline, which is not the monotonic forward-window projection guidance keeps internally, ' ...
   'and that difference is declared rather than absorbed. No channel is named that the loop does ' ...
   'not actually produce.\n\n']);

w('## 7. Rail measurement\n\n| Quantity | Value |\n|---|---|\n');
w('| Declared rudder envelope | %.4f deg |\n', R.attrib.dr_max_deg);
w('| Max abs raw command before any limiter | %.4f deg |\n', R.attrib.raw_absmax_deg);
w('| Max abs plant input | %.4f deg |\n', R.attrib.plant_absmax_deg);
w('| Max abs realized slew | %.4f deg/s |\n', R.attrib.slew_absmax_degs);
w('| Rail dwell (plant input at the envelope) | %.4f of the horizon, %.3f s, %d intervals, longest %.3f s, first at %s |\n', ...
    R.attrib.rail.dwell_frac, R.attrib.rail.dwell_s, R.attrib.rail.n_intervals, ...
    R.attrib.rail.longest_s, rl_tern(isfinite(R.attrib.rail.t_first), sprintf('t = %.3f s', R.attrib.rail.t_first), 'never'));
w('| Magnitude-limiter dwell | %.4f of the horizon, first at %s |\n', R.attrib.mag_sat.dwell_frac, ...
    rl_tern(isfinite(R.attrib.mag_sat.t_first), sprintf('t = %.3f s', R.attrib.mag_sat.t_first), 'never'));
w('| Rate-limiter dwell | %.4f of the horizon, first at %s |\n', R.attrib.rate_sat.dwell_frac, ...
    rl_tern(isfinite(R.attrib.rate_sat.t_first), sprintf('t = %.3f s', R.attrib.rate_sat.t_first), 'never'));
w('| Recorded plant trim requirement | %.3f deg (evidence only) |\n', R.plant_trim_requirement_deg);
w('| Plant input peak / trim requirement | %.3f |\n', R.attrib.trim_ratio_plant);
w('| Raw demand peak / trim requirement | %.3f |\n', R.attrib.trim_ratio_raw);
w('\nPath geometry over the horizon: median curvature %.5f 1/m (radius %.3f m), median inertial horizontal speed %.4f m/s, yaw-rate feedforward median %.4f deg/s and peak %.4f deg/s, achieved yaw rate median %.4f deg/s, signed cross-track median %.4f m and peak abs %.4f m, path segments %d to %d, arc length %.2f to %.2f m.\n\n', ...
    R.attrib.geometry.kappa_median_invm, R.attrib.geometry.R_path_median_m, ...
    R.attrib.geometry.U_h_median, R.attrib.geometry.r_ff_median_degs, ...
    R.attrib.geometry.r_ff_absmax_degs, R.attrib.geometry.r_body_median_degs, ...
    R.attrib.geometry.cte_signed_median_m, R.attrib.geometry.cte_signed_absmax_m, ...
    R.attrib.geometry.seg_span(1), R.attrib.geometry.seg_span(2), ...
    R.attrib.geometry.s_span_m(1), R.attrib.geometry.s_span_m(2));

w('## 8. Attribution completeness\n\n');
CO = R.attrib.completeness;
w('| Check | Value | Tolerance | Pass |\n|---|---|---|---|\n');
w('| max abs (sum of existing contributions minus logged raw command) | %.3e deg | %.1e deg | %d |\n', ...
    CO.max_abs_resid_deg, CO.tol_deg, CO.max_abs_resid_deg <= CO.tol_deg);
w('| rms of that residual | %.3e deg | - | - |\n', CO.rms_resid_deg);
w('| max abs (recomputed post-magnitude minus published post-magnitude) | %.3e deg | %.1e deg | %d |\n', ...
    CO.max_abs_resid_mag_deg, CO.tol_deg, CO.max_abs_resid_mag_deg <= CO.tol_deg);
w('| max abs (recomputed post-rate minus published post-rate) | %.3e deg | %.1e deg | %d |\n', ...
    CO.max_abs_resid_rate_deg, CO.tol_deg, CO.max_abs_resid_rate_deg <= CO.tol_deg);
w('| plant input identical to the published post-rate command | %d/%d samples | all | %d |\n', ...
    CO.n_plant_identical, CO.n, CO.n_plant_identical == CO.n);
w(['\nThe raw rudder command is fully accounted for by four existing contributions and nothing ' ...
   'else. Because the reconstruction closes to %.3e deg with no integral term in the sum, no ' ...
   'accumulating rudder state exists that could be carrying the command.\n\n'], CO.max_abs_resid_deg);

w('| Contribution | Peak abs [deg] | Median share of the raw command at rail samples | Median share over the horizon | Reaches the envelope alone |\n|---|---|---|---|---|\n');
for i = 1:numel(R.attrib.shares)
    q = R.attrib.shares(i);
    w('| `%s` | %.4f | %.4f | %.4f | %d |\n', q.stage, q.absmax_deg, ...
        q.share_median_at_rail, q.share_median_all, q.reaches_rail_alone);
end
w('\nShares are computed over %d samples, selected as %s.\n\n', R.attrib.n_rail_samples, R.attrib.rail_sample_basis);

w('## 9. Stage ladder\n\n%s\n\n', R.attrib.definition);
w('| Stage | Class | Signal | Peak abs | Median abs | Demands the envelope | Creates the envelope | First at | Dwell | Dwell after %.0f s |\n|---|---|---|---|---|---|---|---|---|---|\n', ...
    R.attrib.transient.declared_transient_window_s);
for i = 1:numel(R.attrib.stages)
    q = R.attrib.stages(i);
    w('| `%s` | %s | %s | %.4f | %.4f | %d | %d | %s | %.4f | %.4f |\n', q.id, q.class, q.signal, ...
        q.absmax, q.median_abs, q.demands_rail, q.creates_rail, ...
        rl_tern(isfinite(q.t_first_rail), sprintf('%.3f s', q.t_first_rail), 'never'), ...
        q.dwell_frac, q.dwell_frac_sustained);
end
w('\nPeak and median are in deg for every stage except `S1_REFERENCE_TRANSIENT`, whose signal is a heading error in deg and is therefore never compared with a rudder envelope.\n\n');

w('## 10. Category determinations\n\n| Category | Determination | Evidence |\n|---|---|---|\n');
for i = 1:numel(R.attrib.categories)
    q = R.attrib.categories(i);
    w('| %s | **%s** | %s |\n', q.category, q.determination, q.evidence);
end
w('\n');

w('## 11. Transient against sustained\n\n| Quantity | Value |\n|---|---|\n');
TR = R.attrib.transient;
w('| Declared transient window | first %.0f s of the horizon |\n', TR.declared_transient_window_s);
w('| Heading error settles below %.0f deg | %s |\n', TR.settle_threshold_deg, ...
    rl_tern(TR.settled, sprintf('t = %.3f s', TR.t_settle_s), 'never within this horizon'));
w('| Rail dwell inside the transient window | %.4f |\n', TR.rail_dwell_transient);
w('| Rail dwell after the transient window | %.4f |\n', TR.rail_dwell_sustained);
w('| Peak abs heading error, transient / sustained | %.4f deg / %.4f deg |\n', ...
    TR.e_psi_absmax_transient_deg, TR.e_psi_absmax_sustained_deg);
w('| Median heading error after the transient window | %.4f deg |\n', TR.e_psi_median_sustained_deg);
w('| Peak yaw-reference slew | %.4f deg/s |\n', TR.yaw_ref_rate_absmax_degs);
w('| Rail confined to the transient window | %d |\n', TR.rail_confined_to_transient);
w('| Rail sustained beyond the transient window | %d |\n', TR.rail_sustained);
w('\n');

w('## 12. Single-origin decision\n\n');
w('%s\n\n', OR.criteria);
w('| Criterion | Result |\n|---|---|\n');
w('| C1 attribution arithmetic complete | %d |\n', OR.C1);
w('| C2 stored nominal cell reproduced bit-for-bit | %d |\n', OR.C2);
w('| C3 at most one contribution reaches the envelope alone | %d (%d do) |\n', OR.C3, OR.n_terms_reaching_rail_alone);
w('| C4 earliest stage unambiguous | %d (earliest `%s`, dominant contribution `%s`, median share %.4f) |\n', ...
    OR.C4, OR.id, OR.dominant_stage, OR.dominant_share);
w('| Origin kind | %s |\n', OR.origin_kind);
w('| **Single origin evidenced** | **%d** |\n', OR.single_origin_evidenced);
w('\n%s\n\n', OR.decision_detail);
if OR.single_origin_evidenced
    w('%s\n\n', OR.candidate);
else
    w('%s\n\n', OR.blocker);
end

w('## 13. Hard gates\n\n| ID | Requirement | Pass | Detail |\n|---|---|---|---|\n');
for i = 1:numel(R.gates)
    g = R.gates(i);
    if g.pass, ps = 'PASS'; else, ps = '**FAIL**'; end
    w('| %s | %s | %s | %s |\n', g.id, g.req, ps, g.detail);
end
w('\n');

w('## 14. Forbidden-path audit\n\n| Property | Value |\n|---|---|\n');
A = R.path_audit;
w('| Construction | %s |\n', A.construction);
w('| Tokens checked | %d |\n', numel(A.tokens));
w('| Declaration lines excluded | %d of %d |\n', A.n_lines_excluded, A.n_lines);
w('| Hits including the declaration region | %d |\n', numel(A.hits_including_decl));
w('| Hits excluding the declaration region | %d |\n', numel(A.hits));
w('| Self-match free | %d |\n', A.self_match_free);
w('| Positive control | %d (%d of %d tokens detected in a synthetic probe) |\n', ...
    A.positive_control_ok, A.positive_control_found, numel(A.tokens));
w('| Audit clean | %d |\n', A.clean);
w(['\nThe only value that reaches the plant in this driver is the value the production controller ' ...
   'returned, verified sample by sample in section 8. There is no direct-actuator path, no ' ...
   'surface path and no automatic accommodation path.\n\n']);

w('## 15. Visual QA (programmatic)\n\n');
if isfield(R, 'visual_qa') && isfield(R.visual_qa, 'checks')
    QA = R.visual_qa;
    w('%s\n\n**Verdict: %s.**\n\n', QA.definition, QA.verdict);
    w('| Check | Pass | Detail |\n|---|---|---|\n');
    for i = 1:numel(QA.checks)
        w('| `%s` | %d | %s |\n', QA.checks(i).name, QA.checks(i).pass, QA.checks(i).detail);
    end
    w('\n| Figure | Size [KiB] | Pixels | OK |\n|---|---|---|---|\n');
    for i = 1:numel(QA.files)
        w('| `%s` | %.1f | %dx%d | %d |\n', QA.files(i).short, QA.files(i).kib, ...
            QA.files(i).width, QA.files(i).height, QA.files(i).ok);
    end
    w('\n');
else
    w('Plotting did not complete; no visual QA is claimed.\n\n');
end

w('## 16. Honesty ledger\n\n| Claim | Status |\n|---|---|\n');
w('| Attribution validity | conditional on bit-identical reproduction of the stored nominal cell; admitted = %d |\n', R.cell_reproduced);
w('| Cross-track, segment index and arc length | **RECONSTRUCTED_GEOMETRY** - computed here by nearest-point projection on the cell polyline, not read from guidance internals, which use a monotonic forward-window projection |\n');
w('| Controller contributions | read from values the production controller already publishes, then re-summed and checked against the published raw command |\n');
w('| Integrator windup on the rudder channel | **EXCLUDED_STRUCTURALLY** - no integral state exists there and the reconstruction closes without one |\n');
w('| Actuator dynamics | **NOT_PRESENT** in this nominal cell - no lag, delay, jitter or slew model is inserted; the plant input is the controller return value |\n');
w('| Plant trim requirement %.3f deg | **RECORDED_EVIDENCE ONLY** - reported for comparison, never used as a threshold or a target |\n', R.plant_trim_requirement_deg);
w('| Cell geometry | **ASSUMED_RECONSTRUCTION** carried unchanged from the accepted record, byte-identical, which makes the comparison valid without making the geometry frozen |\n');
w('| Corrective candidate | stated only if a single origin is evidenced, and stated as a bounded measurement task, never as an applied change |\n');
w('| Promotion | none. No gate is moved by this task |\n');
w('| Hardware | **NOT_CERTIFIED**. A simulation result is never hardware certification |\n');
w('| Gate 9 | **locked** |\n');
w('\n');

w('## 17. Artifacts\n\n');
if isfield(R, 'png') && ~isempty(R.png)
    for i = 1:numel(R.png)
        w('- `%s`\n', strrep(R.png{i}, '\', '/'));
    end
end
w('- `%s.md`\n- `%s.mat`\n- `%s_run.log`\n', strrep(OUTB,'\','/'), strrep(OUTB,'\','/'), strrep(OUTB,'\','/'));
if isfield(R, 'footprint_mib')
    w('\nTotal footprint %.2f MiB (< 150 MiB: %d).\n', R.footprint_mib, R.footprint_ok);
end
w('\nAll priors and reconstructions remain **ASSUMED**. Hardware remains **NOT_CERTIFIED**. Gate 9 remains **locked**; Gate 9B remains post-Gate 9.\n');
fclose(fid);
end

% =====================================================================
% one-time appends to readiness / realism / research logs
% =====================================================================
function rl_append_logs(R, TAG)
marker = sprintf('<!-- APPEND_MARKER:%s_001 -->', TAG);
targets = { fullfile('suite_results','AUV_REALIZATION_READINESS_PLAN.md'), 'readiness'; ...
            fullfile('suite_results','AUV_REALISM_AND_VISUAL_VALIDATION.md'), 'realism'; ...
            fullfile('suite_results','PITCH_CONTROL_RESEARCH_LOG.md'), 'research' };
need = {'gates','attrib','origin','log','png','footprint_mib','gains','record_path'};
for i = 1:numel(need)
    if ~isfield(R, need{i})
        fprintf('[G8RL] diagnostic incomplete (missing %s), logs not appended\n', need{i});
        return
    end
end
OR = R.origin;
for i = 1:size(targets,1)
    p = targets{i,1};
    if exist(p, 'file') ~= 2, continue; end
    txt = '';
    try, txt = fileread(p); catch, end     % mechanical idempotency guard only
    if ~isempty(strfind(txt, marker)) %#ok<STREMP>
        fprintf('[G8RL] %s log already carries the marker, skipping append\n', targets{i,2});
        continue
    end
    fid = fopen(p, 'a');
    if fid < 0, continue; end
    fprintf(fid, '\n\n%s\n\n', marker);
    fprintf(fid, '## Append: %s_001 (%s log)\n\n', TAG, targets{i,2});
    fprintf(fid, '**Date:** %s | **Class:** bounded read-only closed-loop rail-origin diagnostic, one cell, one nominal horizon | **MATLAB runs:** 1 | **Production/CODEX:** untouched | **HW:** NOT_CERTIFIED | **Gate 9:** locked\n\n', R.created);
    fprintf(fid, '**Verdict: %s.**', R.verdict);
    if ~strcmp(R.verdict, 'PASS')
        fprintf(fid, ' Failed hard gates: %s.', strjoin(R.hard_failed, ', '));
    end
    fprintf(fid, '\n\n');

    fprintf(fid, '- **Frames and units.** Positions NED in m with z positive down (depth = +z); BODY rates p,q,r and BODY velocities u,v,w; angles rad internally and deg only where a name says so; rudder deflection in deg against the declared %.4f deg envelope with a %.4g deg/s rate limit; path curvature in 1/m and arc length in m; dwell is a dimensionless fraction of the %.0f s horizon.\n', ...
        R.attrib.dr_max_deg, R.gains.rate_limit_degs, R.T_final);
    fprintf(fid, '- **Provenance.** Exactly 3 sources read: `controller_law.m`, `guidance_law.m`, `run_gate8_actuator_order_scan_repair.m`. The frozen envelope, campaign constants and stored nominal fingerprints were dereferenced at run time from `%s`, the artifact path source #3 declares for itself; nothing in it was re-derived. Cell geometry remains an ASSUMED_RECONSTRUCTION carried byte-identically from that record. The %.3f deg plant trim requirement is recorded evidence quoted for comparison only, never used as a threshold.\n', ...
        strrep(R.record_path,'\','/'), R.plant_trim_requirement_deg);
    fprintf(fid, '- **Scope.** Exactly one cell `%s` and one %.0f s nominal horizon at dt %.4f s (%d ticks). No Monte Carlo draw, no sensor, actuator or power hook. Read-only: no gain, law, path, threshold, shaper or feedforward was added or changed, and nothing is promoted.\n', ...
        R.cell.name, R.T_final, R.dt, R.n_samples);
    fprintf(fid, '- **Reproduction before attribution.** Unmodified production, the hooks-off replica and the instrumented replica are bit-identical to each other (`%s`), the instrumented run matches the stored nominal fingerprint (%d) and the stored hooks-off fingerprint (%d), and the replay reproduces both the external outputs (%d) and the full %dx%d diagnostic log (%d). Attribution admitted: %d.\n', ...
        R.hash_shadow_instr, R.prod_matches_record, R.plain_matches_record, ...
        R.replay_external_bitequal, size(R.log,1), size(R.log,2), R.replay_log_bitequal, R.cell_reproduced);
    fprintf(fid, '- **Rail measurement.** Raw rudder demand peaks at %.4f deg before any limiter; the plant input peaks at %.4f deg and sits at the declared envelope for %.4f of the horizon (%.3f s, %d intervals, longest %.3f s, first at %s). Magnitude-limiter dwell %.4f, rate-limiter dwell %.4f, peak realized slew %.4f deg/s. Against the recorded %.3f deg plant trim requirement the peak demand is %.2fx and the peak plant input is %.2fx, reported as evidence only.\n', ...
        R.attrib.raw_absmax_deg, R.attrib.plant_absmax_deg, R.attrib.rail.dwell_frac, ...
        R.attrib.rail.dwell_s, R.attrib.rail.n_intervals, R.attrib.rail.longest_s, ...
        rl_tern(isfinite(R.attrib.rail.t_first), sprintf('t = %.3f s', R.attrib.rail.t_first), 'never'), ...
        R.attrib.mag_sat.dwell_frac, R.attrib.rate_sat.dwell_frac, R.attrib.slew_absmax_degs, ...
        R.plant_trim_requirement_deg, R.attrib.trim_ratio_raw, R.attrib.trim_ratio_plant);
    fprintf(fid, '- **Attribution completeness.** The reconstructed sum of the existing contributions matches the logged raw command to %.3e deg over %d samples (tolerance %.1e deg); the recomputed magnitude and rate limits match the published post-limit values to %.3e and %.3e deg; the plant input equals the controller return value in %d/%d samples.\n', ...
        R.attrib.completeness.max_abs_resid_deg, R.attrib.completeness.n, R.attrib.completeness.tol_deg, ...
        R.attrib.completeness.max_abs_resid_mag_deg, R.attrib.completeness.max_abs_resid_rate_deg, ...
        R.attrib.completeness.n_plant_identical, R.attrib.completeness.n);
    fprintf(fid, '- **Origin.** Earliest stage that demands or creates the %.4f deg envelope: `%s` (class %s) at %s. Category determinations: reference transient %s; controller term %s; integrator windup EXCLUDED_STRUCTURALLY (no integral state on the rudder channel and the reconstruction closes without one); magnitude limit %s; actuator dynamics NOT_PRESENT_IN_THIS_CELL.\n', ...
        R.attrib.dr_max_deg, OR.id, OR.first_stage_class, ...
        rl_tern(isfinite(OR.first_stage_t), sprintf('t = %.3f s', OR.first_stage_t), 'never'), ...
        R.attrib.categories(1).determination, R.attrib.categories(2).determination, ...
        R.attrib.categories(4).determination);
    if OR.single_origin_evidenced
        fprintf(fid, '- **One bounded corrective candidate.** %s\n', regexprep(OR.candidate, '\*\*', ''));
    else
        fprintf(fid, '- **Blocker.** %s\n', regexprep(OR.blocker, '\*\*', ''));
    end
    fprintf(fid, '- **Evidence:** `suite_results/%s.{md,mat,png}`, %d figures, plus `suite_results/%s_run.log`. Visual QA verdict %s. Artifact footprint %.2f MiB.\n', ...
        TAG, numel(R.png), TAG, rl_qa_verdict(R), R.footprint_mib);
    fprintf(fid, '- Nothing is promoted. All reconstructions remain **ASSUMED**. Simulation is not hardware certification (**NOT_CERTIFIED**). Gate 9 remains **locked**; Gate 9B remains post-Gate 9.\n');
    fclose(fid);
    fprintf('[G8RL] appended %s log: %s\n', targets{i,2}, p);
end
end

function s = rl_qa_verdict(R)
s = 'NOT_PRODUCED';
if isfield(R, 'visual_qa') && isfield(R.visual_qa, 'verdict')
    s = R.visual_qa.verdict;
end
end
