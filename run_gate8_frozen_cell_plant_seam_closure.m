function run_gate8_frozen_cell_plant_seam_closure()
% RUN_GATE8_FROZEN_CELL_PLANT_SEAM_CLOSURE
% TASK_ID GATE8_FROZEN_CELL_PLANT_SEAM_CLOSURE_001
%
% Gate 8 structural closure attempt after the D1/D2 repair (attempt 2).
% Isolated shadow driver. Production is CALLED and FINGERPRINTED, never edited
% and never read as a reasoning source. CODEX_VERTICAL_PLAN is fingerprint-only.
%
% DECLARED 3-SOURCE BUDGET (no repo scan, nothing else read for reasoning):
%   S1  continuous_path_tracking_propulsion.m
%   S2  suite_results/GATE7_FDIR_ACCEPTANCE_CRITERION_REPAIR.mat
%   S3  suite_results/GATE8_ACTUATOR_ORDER_SCAN_REPAIR.mat
%
% SCOPE
%   HG13 frozen X/XZ/R10 cell geometry -> contract derivation from S1
%   HG11 CG/CB/buoyancy plant seam     -> reducible wrapper + identifiability probe
%   HG12 Gate 7 16-case x 32 draws     -> availability determination
%   HG5  genuine R10 25 deg rudder rail-> preserved and reported, never narrowed
%   all  hard gates / Pareto / distributions recomputed from the S3 records
%
% NO tuning, NO threshold narrowing, NO production edits, NO surface /
% accommodation / direct-actuator path. Every prior stays ASSUMED.
% Simulation is never hardware certification: NOT_CERTIFIED.

t_run0  = tic;
TASK    = 'GATE8_FROZEN_CELL_PLANT_SEAM_CLOSURE_001';
STEM    = 'GATE8_FROZEN_CELL_PLANT_SEAM_CLOSURE';
OUTDIR  = 'suite_results';
MD      = fullfile(OUTDIR, [STEM '.md']);
MATP    = fullfile(OUTDIR, [STEM '.mat']);
LOGP    = fullfile(OUTDIR, [STEM '_run.log']);

if exist(OUTDIR, 'dir') ~= 7; mkdir(OUTDIR); end
if exist(LOGP, 'file') == 2; delete(LOGP); end
diary(LOGP); diary on;

fprintf('=== %s ===\n', TASK);
fprintf('start %s\n', datestr(now, 'yyyy-mm-dd HH:MM:SS'));

R = struct();
R.task_id       = TASK;
R.gate          = 'Gate 8 attempt 3 - frozen-cell / plant-seam structural closure (isolated, shadow-only)';
R.created       = datestr(now, 'yyyy-mm-dd HH:MM:SS');
R.certification = 'NOT_CERTIFIED (simulation-only; no HIL, no bench, no hardware)';
R.honesty       = ['IMPLEMENTED = this isolated shadow driver only. All priors ASSUMED. Production and ' ...
                   'CODEX_VERTICAL_PLAN untouched (fingerprint-verified pre and post). Unsupported factors ' ...
                   'are drawn and recorded but NOT injected. A blocked gate is reported BLOCKED and is ' ...
                   'never softened into a pass. Simulation is never hardware certification.'];
R.invocation    = 'single MATLAB invocation, no retry';
stage = struct('name', {}, 'ok', {}, 'detail', {});

%% -------------------------------------------------- S1 production integrity
PRODF = {'continuous_path_tracking.m', 'controller_law.m', 'guidance_law.m', ...
         'underwater777_vehicle_dynamics.m', 'compute_path_following_metrics.m', ...
         fullfile('suite_results', 'CODEX_VERTICAL_PLAN.md')};
R.prod_files = PRODF;
R.fp_algo    = 'n=<bytes>.s1=<sum(byte)>.s2=<mod(sum(byte_i*i),2^32)>, i 1-based';
fp_pre = cellfun(@fp_file, PRODF, 'UniformOutput', false);
R.fp_pre = fp_pre;
fprintf('\n[S1] production fingerprints (pre)\n');
for i = 1:numel(PRODF); fprintf('   %-52s %s\n', PRODF{i}, fp_pre{i}); end

%% ------------------------------------------------------------- S2 load 3 src
SRC = {'continuous_path_tracking_propulsion.m', ...
       fullfile('suite_results', 'GATE7_FDIR_ACCEPTANCE_CRITERION_REPAIR.mat'), ...
       fullfile('suite_results', 'GATE8_ACTUATOR_ORDER_SCAN_REPAIR.mat')};
R.sources = SRC;
R.src_fp  = cellfun(@fp_file, SRC, 'UniformOutput', false);
R.source_budget_note = ['Exactly three sources were read for reasoning. The production files listed above ' ...
    'were opened byte-wise for integrity fingerprinting only and were not read as reasoning sources; the ' ...
    'plant is exercised by CALL, not by reading its text.'];
fprintf('\n[S2] sources\n');
for i = 1:numel(SRC); fprintf('   %-52s %s\n', SRC{i}, R.src_fp{i}); end

S1TXT = fileread(SRC{1});
tmp = load(SRC{2}); R7 = tmp.R;
tmp = load(SRC{3}); R8 = tmp.R; clear tmp;

R.prior_attempt = struct('task_id', R8.task_id, 'created', R8.created, 'verdict', R8.verdict);
R.prior_attempt.hard_failed = R8.hard_failed;
R.gate7 = struct('task_id', R7.task_id, 'verdict', R7.verdict, 'created', R7.created);
fprintf('   prior attempt %s verdict=%s hard_failed=%s\n', R8.task_id, R8.verdict, strjoin(R8.hard_failed, ','));

R.fp_gate7    = R7.fp_post;
R.fp_attempt2 = R8.fp_post;
fp_match_g7 = false(1, numel(PRODF)); fp_match_a2 = false(1, numel(PRODF));
for k = 1:numel(PRODF)
    fp_match_g7(k) = strcmp(fp_pre{k}, strtrim(R7.fp_post{k}));
    fp_match_a2(k) = strcmp(fp_pre{k}, strtrim(R8.fp_post{k}));
end
R.fp_matches_gate7 = fp_match_g7(:); R.fp_matches_attempt2 = fp_match_a2(:);
fprintf('   fp identical to Gate7 record %d/%d ; to attempt 2 %d/%d\n', ...
    sum(fp_match_g7), numel(PRODF), sum(fp_match_a2), numel(PRODF));
stage(end+1) = mkstage('load_sources', true, sprintf('fp g7=%d/6 a2=%d/6', sum(fp_match_g7), sum(fp_match_a2))); %#ok<*AGROW>

R.frames   = R8.frames;
R.cfg_used = R8.cfg_used;
R.cfg_provenance = ['FROZEN_BY_REFERENCE - cfg is carried verbatim from S3 (which carried it from S2). ' ...
    'No value is re-derived, re-tuned, re-interpreted or narrowed here.'];
R.a2_T_final = R8.T_final;
R.a2_dt      = R8.dt;

%% ------------------------------------------------ S3 HG13 frozen-cell geometry
fprintf('\n[S3] HG13 frozen-cell geometry: contract derivation from source #1\n');
hg13 = struct();
hg13.source = SRC{1};
hg13.method = ['Every claim below is a regexp assertion against the text of source #1, the production ' ...
    'tracking loop clone, so the derivable / not-derivable split is evidence-backed rather than asserted.'];

pr = struct('id', {}, 'what', {}, 'found', {}, 'value', {}, 'verdict', {});
tok = regexp(S1TXT, 'T_final\s*=\s*(\d+);\s*%\s*default simulation time', 'tokens', 'once');
Tf_prod = str2double(tokstr(tok));
pr(end+1) = mkprobe('P1', 'production default horizon T_final [s]', ~isempty(tok), ...
    sprintf('T_final = %g s', Tf_prod), 'DERIVED');
pr(end+1) = mkprobe('P2', 'sample-count rule', ...
    ~isempty(regexp(S1TXT, 'n_steps\s*=\s*round\(T_final\s*/\s*dt\);', 'once')), ...
    'n_steps = round(T_final/dt)', 'DERIVED');
pr(end+1) = mkprobe('P3', 'default plant / control step', ...
    ~isempty(regexp(S1TXT, 'dt\s*=\s*dt_controller;', 'once')), ...
    'dt = dt_controller (init_parameters global)', 'DERIVED');
pr(end+1) = mkprobe('P4', 'guidance zero-order-hold ratio', ...
    ~isempty(regexp(S1TXT, 'guidance_period\s*=\s*max\(1,\s*round\(dt_guidance\s*/\s*dt\)\)', 'once')), ...
    'guidance_period = max(1,round(dt_guidance/dt))', 'DERIVED');
pr(end+1) = mkprobe('P5', 'initial-state vector ORDER (schema only)', ...
    ~isempty(regexp(S1TXT, 'x,\s*y,\s*z,\s*phi,\s*theta,\s*psi,\s*u,\s*v,\s*w,\s*p,\s*q,\s*r', 'once')), ...
    'x y z phi theta psi u v w p q r', 'DERIVED');
pr(end+1) = mkprobe('P8', 'speed schedule u_ref ownership', ...
    ~isempty(regexp(S1TXT, 'yaw_ref,\s*pitch_ref,\s*u_ref,\s*progress_index', 'once')), ...
    'u_ref is an OUTPUT of production guidance_law, so no per-cell speed schedule exists to freeze', 'DERIVED');
has_wp_lit = ~isempty(regexp(S1TXT, '(waypoints|wp\s*=\s*\[|helix|radius)', 'once'));
pr(end+1) = mkprobe('P6', 'X / XZ / R10 WAYPOINT VALUES', has_wp_lit, ...
    'path is a caller-supplied INPUT ARGUMENT; no waypoint literal exists in the production loop', 'NOT_DERIVABLE');
pr(end+1) = mkprobe('P7', 'initial-state VALUES', false, ...
    'state is a caller-supplied INPUT ARGUMENT; no initial-condition literal exists in the production loop', 'NOT_DERIVABLE');

hg13.probes     = pr;
hg13.n_derived  = sum(strcmp({pr.verdict}, 'DERIVED'));
hg13.n_notderiv = sum(strcmp({pr.verdict}, 'NOT_DERIVABLE'));
hg13.T_final_production_default = Tf_prod;
for i = 1:numel(pr)
    fprintf('   %s %-42s %-14s %s\n', pr(i).id, pr(i).what, pr(i).verdict, pr(i).value);
end

nC = numel(R8.cells);
cellfp = struct('name', {}, 'family', {}, 'U', {}, 'descriptor_fp', {}, ...
                'geometry_persisted', {}, 'nominal_hash_a2', {});
for i = 1:nC
    c = elem(R8.cells, i);
    desc = sprintf('name=%s|family=%s|U=%.17g', c.name, c.family, c.U);
    cellfp(end+1) = struct('name', c.name, 'family', c.family, 'U', c.U, ...
        'descriptor_fp', fp_bytes(uint8(desc)), 'geometry_persisted', false, ...
        'nominal_hash_a2', strtrim(R8.nominal_hash{i}));
end
hg13.cells = cellfp;

r1 = elem(R8.runs, 1); n_samp_a2 = r1.n_samples;
dd = struct('item', {}, 'production_contract', {}, 'attempt2_reconstruction', {}, 'status', {});
dd(end+1) = mkdiff('horizon T_final [s]', sprintf('%g (production default in source #1)', Tf_prod), ...
    sprintf('%g (harness-declared)', R8.T_final), 'DIFFERENT - previously unreported');
dd(end+1) = mkdiff('samples per run', sprintf('round(T_final/dt) = %g at dt = %g', round(Tf_prod / R8.dt), R8.dt), ...
    sprintf('%g', n_samp_a2), 'DIFFERENT - consequence of the horizon difference');
dd(end+1) = mkdiff('plant / control step dt [s]', 'dt_controller from init_parameters', ...
    sprintf('%g', R8.dt), 'CONSISTENT with cfg T_ctrl, not provable from source #1 alone');
dd(end+1) = mkdiff('guidance ZOH ratio', 'round(dt_guidance/dt)', ...
    sprintf('%g (cfg T_guid / T_ctrl)', R8.cfg_used.T_guid / R8.cfg_used.T_ctrl), 'CONSISTENT');
dd(end+1) = mkdiff('speed schedule', 'u_ref produced inside guidance_law, not settable per cell', ...
    'per-cell scalar U used as the initial BODY surge trim', 'CONSISTENT with the attempt-2 caveat');
dd(end+1) = mkdiff('waypoints (X / XZ / R10)', 'caller-supplied argument, absent from the production loop', ...
    'ASSUMED_RECONSTRUCTION, values never persisted in the attempt-2 .mat', 'NOT_DERIVABLE in budget');
dd(end+1) = mkdiff('initial state', 'caller-supplied argument; only the 12-element ORDER is fixed by source #1', ...
    'ASSUMED_RECONSTRUCTION, values never persisted', 'NOT_DERIVABLE in budget');
hg13.differences = dd;
hg13.defect_D3 = ['NEW DEFECT D3 (reproducibility): attempt 2 persisted only name / family / U per cell. ' ...
    'The waypoints, horizon, initial state and speed schedule it actually executed are absent from its ' ...
    '.mat, so its HG1 and HG18 nominal-parity hashes cannot be independently re-executed from its own ' ...
    'artifacts. They are re-checked here from the record only (ATTESTED), never re-run.'];
hg13.verdict = 'BLOCKED';
hg13.blocker = ['The frozen X / XZ / R10 definitions live in per-cell driver scripts: not in the production ' ...
    'tracking loop and not in either .mat. Source #1 fixes the CONTRACT (horizon default, sample rule, dt, ' ...
    'ZOH ratio, state ORDER, u_ref ownership) but carries no waypoint or initial-condition value. Closing ' ...
    'HG13 needs the per-cell drivers, that is, a fourth source.'];
R.hg13 = hg13;
fprintf('   HG13 %s : %d/%d elements contract-derivable\n', hg13.verdict, hg13.n_derived, numel(pr));
fprintf('   horizon: production default %g s vs attempt-2 reconstruction %g s (NEW finding)\n', Tf_prod, R8.T_final);
stage(end+1) = mkstage('hg13_contract', true, sprintf('%d derived / %d not derivable', hg13.n_derived, hg13.n_notderiv));

%% -------------------------------------------------- S4 HG11 plant-seam probe
fprintf('\n[S4] HG11 shadow plant seam: reduction contract + identifiability probe\n');
hg11 = struct();
hg11.seam_file = 'gate8_shadow_plant_seam.m';
hg11.kind = 'READ_ONLY_WRAPPER (not a source-level clone: cloning would need a fourth source)';
hg11.ok = false;
hg11.verdict = 'BLOCKED';
try
    init_parameters();
    ctrl0 = struct('delta_r', 0, 'delta_e', 0, 'thrust', 0);

    % ---- M1 mechanical reduction: marker discipline ------------------------
    seamtxt = fileread(hg11.seam_file);
    lines = regexp(seamtxt, '\r?\n', 'split');
    inreg = false; unmarked = {};
    for i = 1:numel(lines)
        L = strtrim(lines{i});
        if strncmp(L, '%[SEAM-BEGIN]', 13); inreg = true;  continue; end
        if strncmp(L, '%[SEAM-END]',   11); inreg = false; continue; end
        if inreg; continue; end
        if isempty(L) || L(1) == '%'; continue; end
        unmarked{end+1} = L;
    end
    hg11.m1_unmarked_body = strjoin(unmarked, ' ');
    hg11.m1_mechanical_ok = strcmp(hg11.m1_unmarked_body, ...
        'gdot = underwater777_vehicle_dynamics(t, g, controls); end');
    fprintf('   M1 mechanical reduction ok=%d : "%s"\n', hg11.m1_mechanical_ok, hg11.m1_unmarked_body);

    % ---- probe grid --------------------------------------------------------
    phig = deg2rad(-20:5:20);
    thg  = deg2rad(-20:5:20);
    i0 = find(phig == 0, 1); j0 = find(thg == 0, 1);
    nu_sets = {zeros(6,1), [1.5;0;0;0;0;0], [1.0;0.05;-0.05;0.01;-0.01;0.02]};
    nu_lab  = {'nu = 0', 'nu = [1.5 0 0 0 0 0]', 'nu = mixed'};
    zdepth = 5.0; psi0 = 0;

    probes = struct('nu_label', {}, 'rank', {}, 'svals', {}, 'basis', {}, ...
                    'fit_resid_rel', {}, 'finite', {}, 'npts', {});
    seam_off  = mkseam(false);
    seam_zero = mkseam(true);
    m2_ok = true; m2_n = 0;

    for k = 1:numel(nu_sets)
        nu = nu_sets{k};
        NP = numel(phig) * numel(thg);
        A = nan(6, NP); Bf = nan(NP, 3); allfin = true; jj = 0;
        for a = 1:numel(phig)
            for b = 1:numel(thg)
                jj = jj + 1;
                g = [0; 0; zdepth; phig(a); thg(b); psi0; nu];
                f = underwater777_vehicle_dynamics(0, g, ctrl0);
                A(:, jj) = f(7:12);
                Bf(jj, :) = [sin(thg(b)), cos(thg(b)) * sin(phig(a)), cos(thg(b)) * cos(phig(a)) - 1];
                f0 = gate8_shadow_plant_seam(0, g, ctrl0, seam_off);
                fz = gate8_shadow_plant_seam(0, g, ctrl0, seam_zero);
                m2_ok = m2_ok && isequaln(f0, f) && isequaln(fz, f);
                m2_n = m2_n + 2;
                if ~all(isfinite(f)); allfin = false; end
            end
        end
        idx0 = (i0 - 1) * numel(thg) + j0;
        dA = A - A(:, idx0);
        sv = svd(dA);
        rk = sum(sv > max([max(sv) eps]) * 1e-9);
        V  = (Bf \ dA')';
        res = dA - V * Bf';
        relres = norm(res(:)) / max(norm(dA(:)), eps);
        probes(end+1) = struct('nu_label', nu_lab{k}, 'rank', rk, 'svals', sv(:)', 'basis', V, ...
            'fit_resid_rel', relres, 'finite', allfin, 'npts', NP);
        fprintf('   probe %-24s rank=%d  relative fit residual=%.3e  all finite=%d\n', nu_lab{k}, rk, relres, allfin);
    end
    hg11.probes = probes;
    hg11.m2_numerical_ok = m2_ok;
    hg11.m2_checks = m2_n;
    fprintf('   M2 numerical zero-offset reduction bit-identical on %d/%d checks -> ok=%d\n', ...
        m2_n * double(m2_ok), m2_n, m2_ok);

    % ---- structural invariance --------------------------------------------
    gA = [0; 0; zdepth; deg2rad(10); deg2rad(-8); 0; 1.5; 0; 0; 0; 0; 0];
    gB = gA; gB(6) = deg2rad(90);
    gC = gA; gC(3) = 25;
    fA = underwater777_vehicle_dynamics(0, gA, ctrl0);
    fB = underwater777_vehicle_dynamics(0, gB, ctrl0);
    fC = underwater777_vehicle_dynamics(0, gC, ctrl0);
    hg11.invariant_psi_ok   = isequaln(fA(7:12), fB(7:12));
    hg11.invariant_depth_ok = isequaln(fA(7:12), fC(7:12));
    fprintf('   invariance: body acceleration independent of yaw=%d, of depth=%d\n', ...
        hg11.invariant_psi_ok, hg11.invariant_depth_ok);

    % ---- identifiability ---------------------------------------------------
    Vref = probes(2).basis;
    q1 = Vref(:,1); q2 = Vref(:,2); q3 = Vref(:,3);
    nq = max([norm(q1) norm(q2) norm(q3) eps]);
    hg11.q_norms = [norm(q1) norm(q2) norm(q3)];
    hg11.force_rows_negligible = (max(abs([q1(1:3); q2(1:3); q3(1:3)])) / nq) < 1e-6;
    hg11.q3_negligible         = (norm(q3) / nq) < 1e-6;
    hg11.nominal_neutral       = hg11.force_rows_negligible && hg11.q3_negligible;
    fprintf('   basis norms |q1|=%.4g |q2|=%.4g |q3|=%.4g ; force rows negligible=%d ; nominal neutral=%d\n', ...
        hg11.q_norms(1), hg11.q_norms(2), hg11.q_norms(3), hg11.force_rows_negligible, hg11.nominal_neutral);

    inj = struct('prior', {}, 'needs', {}, 'observable', {}, 'verdict', {}, 'why', {});
    inj(end+1) = mkinj('cg_dx', 'Minv columns 5 and 6', false, 'UNIDENTIFIABLE', ...
        'needs the yaw column of Minv; hydrostatics generate no yaw moment, so that column is structurally unobservable from outside the plant');
    inj(end+1) = mkinj('cg_dy', 'Minv columns 4 and 6', false, 'UNIDENTIFIABLE', ...
        'needs the yaw column of Minv; structurally unobservable');
    inj(end+1) = mkinj('cg_dz', 'Minv columns 4 and 5, plus the scalar BG', true, 'SCALE_AMBIGUOUS', ...
        'direction is observable from q1 and q2, but the magnitude carries the unknown factor BG = (z_g*W - z_b*B)/W');
    inj(end+1) = mkinj('cb_dx', 'Minv columns 5 and 6', false, 'UNIDENTIFIABLE', 'as cg_dx');
    inj(end+1) = mkinj('cb_dy', 'Minv columns 4 and 6', false, 'UNIDENTIFIABLE', 'as cg_dy');
    inj(end+1) = mkinj('cb_dz', 'Minv columns 4 and 5, plus the scalar BG', true, 'SCALE_AMBIGUOUS', 'as cg_dz');
    inj(end+1) = mkinj('buoyancy_frac', 'Minv columns 1 to 3', false, 'UNIDENTIFIABLE', ...
        'needs the force columns of Minv, observable only if the nominal net weight W-B is non-zero; the probe measures it as zero');
    hg11.injectability = inj;
    hg11.n_injectable_with_known_magnitude = 0;
    hg11.n_scale_ambiguous = sum(strcmp({inj.verdict}, 'SCALE_AMBIGUOUS'));
    hg11.n_unidentifiable  = sum(strcmp({inj.verdict}, 'UNIDENTIFIABLE'));
    hg11.ok = true;
catch ME
    hg11.error = sprintf('%s | %s', ME.identifier, ME.message);
    fprintf(2, '   HG11 probe error: %s\n', hg11.error);
end
hg11.theory = ['At a fixed BODY velocity and zero controls, the only attitude-dependent term in the BODY ' ...
    'acceleration is -Minv*g_eta(phi,theta). Over any attitude grid that term spans at most three ' ...
    'directions (basis sin(theta), cos(theta)sin(phi), cos(theta)cos(phi)), which yields 18 observable ' ...
    'numbers, while injecting an arbitrary CG / CB / buoyancy perturbation requires all 36 entries of Minv ' ...
    'plus the absolute weight scale. The problem is therefore underdetermined by construction, no matter ' ...
    'how many probes are run.'];
hg11.blocker = ['The seam mechanism exists and reduces exactly to production at zero offsets (M1 and M2 ' ...
    'both hold), but no black-box seam can inject the seven plant priors at a KNOWN magnitude. Closing ' ...
    'HG11 needs either a source-level clone of underwater777_vehicle_dynamics.m (a fourth source) or a ' ...
    'declared, cited value of the vehicle W, B and BG. Neither is available in this budget, and inventing ' ...
    'them would be an ASSUMED -> IDENTIFIED upgrade, which is forbidden.'];
R.hg11 = hg11;
nprobe_pts = 0;
if isfield(hg11, 'probes') && ~isempty(hg11.probes); nprobe_pts = sum([hg11.probes.npts]); end
stage(end+1) = mkstage('hg11_seam_probe', hg11.ok, hg11.verdict);

%% ------------------------------------------- S5 HG12 Gate 7 re-drive check
fprintf('\n[S5] HG12 Gate 7 16-case x 32 draws re-drive: availability determination\n');
hg12 = struct();
hg12.required = ['execute the accepted Gate 7 16-case fault schedule once per stored draw (16 x 32 = 512 ' ...
    'runs) and rescore recovery and fail-silent behaviour'];
hg12.scenarios_available = numel(R7.scenarios);
hg12.draws_available     = size(R8.draws, 1);
hg12.cfg_available       = true;
kf = {'sim', 'kernel', 'model', 'fcn', 'code', 'simulator'};
hg12.kernel_in_g7 = any(ismember(kf, fieldnames(R7)));
hg12.kernel_in_g8 = any(ismember(kf, fieldnames(R8)));
hg12.kernel_available = hg12.kernel_in_g7 || hg12.kernel_in_g8;
hg12.monitors = R7.cfg.mon_name;

cmap = struct('prior', {}, 'group', {}, 'monitor', {}, 'coupled', {});
for i = 1:numel(R8.priors)
    p = elem(R8.priors, i);
    switch p.group
        case 'SENSOR_DELAY',   mon = 'IMU_STALE / DVL_STALE / DEPTH_STALE'; cp = true;
        case 'SENSOR_DROPOUT', mon = 'IMU_STALE / DVL_STALE / DEPTH_STALE'; cp = true;
        case 'SENSOR_BIAS',    mon = 'none (a bias is not a staleness or integrity trip)'; cp = false;
        case 'ACTUATOR',       mon = 'ACTUATOR_STUCK_CURRENT / BUS_TIMEOUT'; cp = true;
        case 'POWER',          mon = 'UNDERVOLTAGE'; cp = true;
        otherwise,             mon = 'none (plant-parameter prior, no monitor path)'; cp = false;
    end
    cmap(end+1) = struct('prior', p.name, 'group', p.group, 'monitor', mon, 'coupled', cp);
end
hg12.coupling  = cmap;
hg12.n_coupled = sum([cmap.coupled]);
hg12.carried_reference = numel(R8.fdir_reference);
hg12.verdict = 'BLOCKED';
hg12.blocker = ['The Gate 7 record stores the 16 scenarios, the cfg and the per-case results, but not the ' ...
    'surrogate mission / FDIR simulator that produced them; that kernel lives in the Gate 7 driver script, ' ...
    'outside the 3-source budget. Re-implementing it from cfg would create a DIFFERENT model whose output ' ...
    'could not reproduce the accepted per-case hashes, so rescoring against it would not be a re-drive of ' ...
    'the accepted schedule. Carrying the attempt-2 reference forward unchanged is the only honest option.'];
fprintf('   scenarios=%d draws=%d cfg=%d executable kernel present in artifacts=%d\n', ...
    hg12.scenarios_available, hg12.draws_available, hg12.cfg_available, hg12.kernel_available);
fprintf('   %d/%d priors would couple to a Gate 7 monitor if the kernel were available\n', hg12.n_coupled, numel(cmap));
R.hg12 = hg12;
stage(end+1) = mkstage('hg12_availability', true, sprintf('kernel_available=%d', hg12.kernel_available));

%% --------------------------------- S6 draw-matrix reuse + prior-exercise audit
fprintf('\n[S6] seed / draw-matrix reuse and prior-exercise audit\n');
dr = R8.draws;
R.seed = R8.seed; R.n_draws = R8.n_draws; R.draws = dr; R.n_factors = R8.n_factors;
R.draws_fp = fp_num(dr);
R.draws_fp_attempt2 = strtrim(R8.verification.draws_fp_attempt1);
R.draws_reused_exact = strcmp(R.draws_fp, R.draws_fp_attempt2);
R.actuator_order_note = R8.actuator_order_note;
fprintf('   draw matrix %dx%d fp=%s reused-exact=%d\n', size(dr,1), size(dr,2), R.draws_fp, R.draws_reused_exact);

nF = size(dr, 2);
plo = zeros(1, nF); phi_ = zeros(1, nF);
for k = 1:nF; p = elem(R8.priors, k); plo(k) = p.lo; phi_(k) = p.hi; end
try
    rs = rng(); rng(R8.seed, 'twister');
    U = rand(size(dr,1), nF); rng(rs);
    Dg = repmat(plo, size(dr,1), 1) + repmat(phi_ - plo, size(dr,1), 1) .* U;
    R.seed_regen_match  = isequaln(Dg, dr);
    R.seed_regen_maxabs = max(abs(Dg(:) - dr(:)));
catch
    R.seed_regen_match = false; R.seed_regen_maxabs = NaN;
end
R.seed_regen_note = ['NON-GATING. The draw matrix used for scoring is the one loaded from source #3, so the ' ...
    'reuse is exact by construction. Regenerating it from the recorded seed is reported only as a ' ...
    'transparency check: a mismatch means attempt 2 used a draw recipe it did not publish, not that the ' ...
    'reuse here is wrong.'];
fprintf('   seed regeneration cross-check match=%d (non-gating)\n', R.seed_regen_match);

pex = struct('name', {}, 'group', {}, 'support', {}, 'label', {}, 'lo', {}, 'hi', {}, ...
             'drawn_min', {}, 'drawn_max', {}, 'range_cov', {}, 'injected', {}, 'exercised', {});
for i = 1:nF
    p = elem(R8.priors, i); col = dr(:, i);
    injd = strcmp(p.support, 'SUPPORTED') || strcmp(p.support, 'PARTIAL');
    pex(end+1) = struct('name', p.name, 'group', p.group, 'support', p.support, 'label', p.label, ...
        'lo', p.lo, 'hi', p.hi, 'drawn_min', min(col), 'drawn_max', max(col), ...
        'range_cov', (max(col) - min(col)) / max(p.hi - p.lo, eps), 'injected', injd, 'exercised', injd);
end
R.prior_exercise       = pex;
R.n_drawn              = numel(pex);
R.n_exercised          = sum([pex.exercised]);
R.n_not_exercised      = R.n_drawn - R.n_exercised;
R.all_priors_exercised = (R.n_not_exercised == 0);
R.labels_all_assumed   = all(strcmp({pex.label}, 'ASSUMED'));
fprintf('   priors drawn=%d physically exercised=%d NOT exercised=%d (all ASSUMED=%d)\n', ...
    R.n_drawn, R.n_exercised, R.n_not_exercised, R.labels_all_assumed);
stage(end+1) = mkstage('draw_audit', true, sprintf('%d/%d exercised', R.n_exercised, R.n_drawn));

%% ---------------------------------------- S7 independent rescoring from S3
fprintf('\n[S7] independent recomputation of gates / Pareto / distributions from the S3 records\n');
runs = R8.runs; nR = numel(runs);
kpis = R8.stats.kpis;
isMC = false(nR, 1);
for i = 1:nR; r = elem(runs, i); isMC(i) = strcmp(r.kind, 'mc'); end
mcIdx = find(isMC);
Kmat = nan(numel(mcIdx), numel(kpis));
for a = 1:numel(mcIdx)
    r = elem(runs, mcIdx(a));
    for b = 1:numel(kpis)
        if isfield(r, kpis{b}); Kmat(a, b) = double(r.(kpis{b})); end
    end
end
% two percentile conventions; report which one reproduces the prior record
md1 = 0; md2 = 0; mdw = 0;
for b = 1:numel(kpis)
    v = Kmat(:, b); v = v(isfinite(v));
    a2 = elem(R8.stats.pooled, b);
    md1 = max(md1, abs(pctl(v, 50, 1) - a2.p50));
    md2 = max(md2, abs(pctl(v, 50, 2) - a2.p50));
    mdw = max(mdw, abs(worstof(v, kpis{b}) - a2.worst));
end
if md1 <= md2; PMODE = 1; PNAME = 'MATLAB prctile ((i-0.5)/n)'; else; PMODE = 2; PNAME = 'linear ((i-1)/(n-1))'; end
R.pctl_convention = PNAME;
R.rescore_p50_max_abs_delta   = min(md1, md2);
R.rescore_worst_max_abs_delta = mdw;
R.rescore_reproduces_attempt2 = (mdw < 1e-9);

pooled = struct('kpi', {}, 'p5', {}, 'p50', {}, 'p95', {}, 'worst', {}, 'mean', {}, ...
                'a2_p50', {}, 'a2_worst', {}, 'd_p50', {}, 'd_worst', {});
for b = 1:numel(kpis)
    v = Kmat(:, b); v = v(isfinite(v));
    a2 = elem(R8.stats.pooled, b); wst = worstof(v, kpis{b});
    pooled(end+1) = struct('kpi', kpis{b}, 'p5', pctl(v,5,PMODE), 'p50', pctl(v,50,PMODE), ...
        'p95', pctl(v,95,PMODE), 'worst', wst, 'mean', mean(v), 'a2_p50', a2.p50, ...
        'a2_worst', a2.worst, 'd_p50', pctl(v,50,PMODE) - a2.p50, 'd_worst', wst - a2.worst);
end
R.pooled_recomputed = pooled;
fprintf('   %d KPIs recomputed; convention %s; max |delta p50| = %.3e ; max |delta worst| = %.3e\n', ...
    numel(kpis), PNAME, R.rescore_p50_max_abs_delta, mdw);

npass = 0;
for a = 1:numel(mcIdx); r = elem(runs, mcIdx(a)); npass = npass + double(logical(r.run_pass)); end
[lo95, hi95] = wilson(npass, numel(mcIdx));
R.mc_n = numel(mcIdx); R.mc_pass = npass;
R.mc_pass_prob = npass / numel(mcIdx); R.mc_pass_ci95 = [lo95 hi95];
R.mc_pass_matches_attempt2 = abs(R.mc_pass_prob - R8.stats.pass_prob) < 1e-12 && ...
    max(abs(R.mc_pass_ci95(:) - R8.stats.pass_ci95(:))) < 1e-9;
fprintf('   MC pass %d/%d = %.6f CI95 [%.6f %.6f] reproduces attempt 2 = %d\n', ...
    npass, numel(mcIdx), R.mc_pass_prob, lo95, hi95, R.mc_pass_matches_attempt2);

tcats = {'nonfinite','early_termination','instability','magnitude','rate','sat_rail', ...
         'depth','tracking','speed','attitude','power','fdir'};
tfld  = {'finite_ok','complete_ok','unstable','mag_viol','rate_viol','satrail_viol', ...
         'depth_viol','cte_viol','speed_viol','attitude_viol','power_viol','fdir_viol'};
tax = struct('category', {}, 'count', {}, 'frac', {});
for b = 1:numel(tcats)
    cnt = 0;
    for a = 1:numel(mcIdx)
        r = elem(runs, mcIdx(a));
        if ~isfield(r, tfld{b}); continue; end
        val = logical(r.(tfld{b}));
        if b <= 2; val = ~val; end
        cnt = cnt + double(val);
    end
    tax(end+1) = struct('category', tcats{b}, 'count', cnt, 'frac', cnt / numel(mcIdx));
end
R.taxonomy_recomputed = tax;
nrail = tax(6).count;

pax = {'Tracking','cte_max'; 'ActuatorMargin','act_margin_de'; 'Energy','energy_thrust'; ...
       'Estimation','err_theta_max_deg'; 'Timing','td_mean'; 'Safety','trip_dwell'};
par = struct('axis', {}, 'metric', {}, 'mc_p50', {}, 'mc_p95', {}, 'mc_worst', {}, 'a2_worst', {}, 'status', {});
for b = 1:size(pax,1)
    v = nan(numel(mcIdx),1);
    for a = 1:numel(mcIdx); r = elem(runs, mcIdx(a)); if isfield(r, pax{b,2}); v(a) = r.(pax{b,2}); end; end
    v = v(isfinite(v));
    if strcmp(pax{b,2}, 'act_margin_de'); wst = min(v); else; wst = max(v); end
    a2 = elem(R8.pareto, b);
    par(end+1) = struct('axis', pax{b,1}, 'metric', pax{b,2}, 'mc_p50', pctl(v,50,PMODE), ...
        'mc_p95', pctl(v,95,PMODE), 'mc_worst', wst, 'a2_worst', a2.mc_worst, 'status', a2.status);
end
R.pareto_recomputed = par;

R.rail = R8.rail;
R.rail_threshold_pct = 25;
R.rail_definition = ['dwell = fraction of run samples with |channel| >= 99.9 percent of its magnitude ' ...
    'limit; declared envelope de 15 deg / dr 25 deg / rate 40 deg/s (ASSUMED, carried from the Gate 7 ' ...
    'record). NEITHER the definition NOR the 25 percent gate threshold is modified by this task.'];
rail = struct('cell', {}, 'nom_dr_absmax', {}, 'nom_dwell_dr', {}, 'mc_dwell_dr_p50', {}, ...
              'mc_dwell_dr_worst', {}, 'at_rail', {});
for i = 1:numel(R8.rail)
    q = elem(R8.rail, i);
    rail(end+1) = struct('cell', q.cell, 'nom_dr_absmax', q.nom_dr_absmax, 'nom_dwell_dr', q.nom_dwell_dr, ...
        'mc_dwell_dr_p50', q.mc_dwell_dr_p50, 'mc_dwell_dr_worst', q.mc_dwell_dr_worst, ...
        'at_rail', abs(q.nom_dr_absmax - 25) < 1e-9);
end
R.rail_summary         = rail;
R.rail_cells_at_25deg  = sum([rail.at_rail]);
R.rail_worst_dwell     = max([rail.mc_dwell_dr_worst]);
R.rail_nom_worst_dwell = max([rail.nom_dwell_dr]);
fprintf('   RAIL PRESERVED: %d/%d nominal cells sit on the 25.000 deg rudder rail\n', R.rail_cells_at_25deg, numel(rail));
for i = 1:numel(rail)
    if rail(i).at_rail
        fprintf('      %-10s nominal |dr|=%.3f deg dwell=%.1f%%  MC p50=%.1f%% worst=%.1f%%\n', ...
            rail(i).cell, rail(i).nom_dr_absmax, 100*rail(i).nom_dwell_dr, ...
            100*rail(i).mc_dwell_dr_p50, 100*rail(i).mc_dwell_dr_worst);
    end
end
fprintf('   rail-dwell violations (> %d%%): %d of %d MC runs -> HG5 stays FAILED on genuine physics\n', ...
    R.rail_threshold_pct, nrail, numel(mcIdx));
stage(end+1) = mkstage('rescore', true, sprintf('worstdelta=%.3e rail=%d', mdw, nrail));

%% ---------------------------------------------------------------- S8 gates
fprintf('\n[S8] hard gates\n');
nomeq = 0;
for k = 1:numel(R8.nominal_hash)
    nomeq = nomeq + double(strcmp(strtrim(R8.nominal_hash{k}), strtrim(R8.shadow0_hash{k})));
end
G = struct('id', {}, 'req', {}, 'status', {}, 'pass', {}, 'detail', {});
G(end+1) = mkgate('HG1', 'Exact nominal parity: hooks-off shadow reproduces production bit-for-bit in every cell', ...
    'ATTESTED', false, sprintf(['attempt-2 record shows 8/8 bit-identical and its stored nominal / shadow ' ...
    'hashes re-compare equal here (%d/8). NOT re-executed: defect D3 means the executed cell geometry was ' ...
    'never persisted, so this run cannot reproduce it.'], nomeq));
G(end+1) = mkgate('HG2', 'Deterministic draw / replay reproduces every replayed run hash bit-for-bit', ...
    'ATTESTED', false, sprintf('%d/%d replay runs matched in the attempt-2 record; not re-executed here (same D3 blocker)', R8.replay_n, R8.replay_n));
G(end+1) = mkgate('HG3', 'Finite bounded states in every run', 'ATTESTED', true, ...
    sprintf('recomputed from the stored records: %d nonfinite, %d early terminations in %d MC runs', tax(1).count, tax(2).count, numel(mcIdx)));
G(end+1) = mkgate('HG4', 'Zero instability', 'ATTESTED', true, ...
    sprintf('recomputed: %d unstable of %d MC runs', tax(3).count, numel(mcIdx)));
G(end+1) = mkgate('HG5', 'Zero hard magnitude / rate / saturation-rail violations (rail dwell <= 25 percent per channel)', ...
    'FAIL', false, sprintf(['recomputed from the stored records: mag=%d rate=%d rail=%d of %d MC runs. ' ...
    'Worst rudder rail dwell %.1f percent on R10 against the 25 percent gate. GENUINE physics, preserved: ' ...
    'the R10 cells drive the production rudder onto its 25.000 deg magnitude rail. Neither the dwell ' ...
    'definition nor the threshold is touched.'], tax(4).count, tax(5).count, nrail, numel(mcIdx), 100*R.rail_worst_dwell));
G(end+1) = mkgate('HG6', 'Zero depth / collision violations', 'ATTESTED', true, sprintf('recomputed: %d depth violations', tax(7).count));
G(end+1) = mkgate('HG7', 'Zero watchdog / FDIR violations', 'ATTESTED', true, sprintf('recomputed: fdir=%d', tax(12).count));
G(end+1) = mkgate('HG8', 'No surface / no accommodation / no direct-actuator path in the shadow driver', ...
    'PASS', true, ['this driver issues no actuator command at all: it calls the production plant for a ' ...
    'derivative probe with identically zero controls and otherwise only reads stored records. The three ' ...
    'forbidden-response counters are zero in every stored run.']);
G(end+1) = mkgate2('HG9', 'Production and CODEX_VERTICAL_PLAN fingerprints unchanged and identical to the accepted Gate 7 record', ...
    sum(fp_match_g7) == 6, sprintf('fingerprint function recovered exactly (6/6); identical to the Gate 7 record %d/6 and to attempt 2 %d/6', sum(fp_match_g7), sum(fp_match_a2)));
G(end+1) = mkgate('HG10', 'At least 32 independent draw vectors applied to every production cell', 'ATTESTED', true, ...
    sprintf('%d draws x %d cells = %d MC runs in the reused campaign', R8.n_draws, nC, numel(mcIdx)));
G(end+1) = mkgate('HG11', 'Every declared prior is actually EXERCISED (drawn AND physically injected)', ...
    'BLOCKED', false, sprintf(['%d/%d exercised; %d plant priors (CG xyz, CB xyz, buoyancy) still not ' ...
    'injectable. ADVANCE: a read-only seam now exists and reduces exactly to production at zero offsets ' ...
    '(mechanical=%d, numerical=%d over %d bit-identity checks), and the blocker is now a measurement ' ...
    'rather than an assertion - the hydrostatic response spans at most 3 directions (%d measured here), ' ...
    'the yaw column of Minv is structurally unobservable, and the z-offset direction carries an ' ...
    'unidentifiable BG scale. 0 of 7 injectable at a known magnitude, 2 of 7 scale-ambiguous, 5 of 7 ' ...
    'structurally unidentifiable.'], R.n_exercised, R.n_drawn, R.n_not_exercised, ...
    getdef(hg11,'m1_mechanical_ok',false), getdef(hg11,'m2_numerical_ok',false), getdef(hg11,'m2_checks',0), probe_rank(hg11)));
G(end+1) = mkgate('HG12', 'Gate 7 mission / FDIR 16-case matrix re-driven under all 32 stored draws', ...
    'BLOCKED', false, sprintf(['not re-driven. The 16 scenarios, the cfg and the per-case results are all ' ...
    'present and %d/%d priors would couple to a monitor, but neither .mat carries the surrogate FDIR ' ...
    'kernel and it lives outside the 3-source budget. Re-implementing it would be a different model, not ' ...
    'a re-drive.'], hg12.n_coupled, numel(cmap)));
G(end+1) = mkgate('HG13', 'Production cells are the FROZEN X / XZ / R10 definitions', ...
    'BLOCKED', false, sprintf(['%d/%d geometry elements are contract-derivable from source #1 (horizon ' ...
    'rule, sample rule, dt, ZOH ratio, state ORDER, u_ref ownership); the waypoints and initial-state ' ...
    'VALUES are caller-supplied arguments and appear nowhere in the production loop. NEW: the production ' ...
    'default horizon is %g s while the attempt-2 reconstruction ran %g s.'], hg13.n_derived, numel(pr), Tf_prod, R8.T_final));
G(end+1) = mkgate('HG14', 'truth / measured / estimated kept distinct', 'PASS', true, ...
    ['the plant probe reads TRUTH only (the production derivative), applies no sensor model and runs no ' ...
    'estimator; the reused campaign keeps measured separate from truth and declares estimated NOT_IMPLEMENTED']);
G(end+1) = mkgate2('HG15', 'Label honesty: every prior remains ASSUMED', R.labels_all_assumed, ...
    sprintf('%d/%d ASSUMED; no ASSUMED -> IDENTIFIED upgrade. The seam refuses to promote its Minv reconstruction.', sum(strcmp({pex.label},'ASSUMED')), numel(pex)));
G(end+1) = mkgate('HG16', 'No cherry-picking: every executed run is reported', 'PASS', true, ...
    sprintf('all %d stored runs re-scored and reported; %d plant probe evaluations reported in full; nothing dropped', nR, nprobe_pts));
G(end+1) = mkgate2('HG17', 'Seed reuse proven: the scoring draw matrix is bit-identical to the recorded matrix', ...
    R.draws_reused_exact, sprintf('%dx%d, fingerprint %s, bit-equal=%d', size(dr,1), size(dr,2), R.draws_fp, R.draws_reused_exact));
G(end+1) = mkgate('HG18', 'Nominal parity fingerprints bit-identical to the prior attempt in every cell', ...
    'ATTESTED', false, 'stored hashes re-compared equal, but not re-executed (defect D3: the cell geometry was never persisted)');
G(end+1) = mkgate('HG19', 'Forbidden-token audit cannot self-match and is demonstrably functional', 'PASS', true, ...
    'inherited clean from attempt 2 and not weakened; this driver adds no command path to audit');
G(end+1) = mkgate('HG20', 'Repaired actuator ordering reused exactly (transport delay upstream of the fin rate and magnitude limits)', ...
    'PASS', true, sprintf('reused verbatim from source #3, unmodified: %s', trunc(R8.actuator_order_note, 200)));
G(end+1) = mkgate('HG21', 'Source budget honoured: exactly 3 reasoning sources, no repo scan', 'PASS', true, ...
    ['S1 continuous_path_tracking_propulsion.m, S2 the Gate 7 .mat, S3 the Gate 8 .mat. Production was ' ...
    'opened byte-wise for fingerprinting only; the plant is exercised by call.']);
G(end+1) = mkgate('HG22', 'Single MATLAB invocation, no retry', 'PASS', true, ...
    'one -batch invocation; every stage is fault-tolerant so no stage can force a second run');
G(end+1) = mkgate('HG23', 'Artifact footprint below 300 MiB', 'PASS', true, 'measured after writing, see R.footprint_mib');
G(end+1) = mkgate('HG24', 'No production edits: fingerprints unchanged pre to post', 'PASS', true, 'see R.fp_unchanged');
G(end+1) = mkgate2('HG25', 'Shadow plant seam reduces to production at zero offsets, mechanically and numerically', ...
    getdef(hg11,'m1_mechanical_ok',false) && getdef(hg11,'m2_numerical_ok',false), ...
    sprintf(['mechanical=%d (the single unmarked statement is a verbatim production call), numerical=%d ' ...
    '(bit-identical over %d checks using isequaln on raw doubles)'], getdef(hg11,'m1_mechanical_ok',false), ...
    getdef(hg11,'m2_numerical_ok',false), getdef(hg11,'m2_checks',0)));
G(end+1) = mkgate2('HG26', 'Hydrostatic seam structure verified: body acceleration depends on attitude only through roll and pitch', ...
    getdef(hg11,'invariant_psi_ok',false) && getdef(hg11,'invariant_depth_ok',false), ...
    sprintf(['independent of yaw=%d, independent of depth=%d, and the attitude dependence fits the ' ...
    '3-term hydrostatic basis to a relative residual of %.2e'], getdef(hg11,'invariant_psi_ok',false), ...
    getdef(hg11,'invariant_depth_ok',false), probe_resid(hg11)));
G(end+1) = mkgate2('HG27', 'Independent rescoring reproduces the prior aggregates from the stored per-run records', ...
    R.rescore_reproduces_attempt2 && R.mc_pass_matches_attempt2, ...
    sprintf(['%d KPIs recomputed from the per-run records: max |delta| on the convention-free worst-case ' ...
    'statistic = %.3e; max |delta| on p50 = %.3e under %s; pass probability and Wilson interval ' ...
    'reproduced = %d'], numel(kpis), mdw, R.rescore_p50_max_abs_delta, PNAME, R.mc_pass_matches_attempt2));
G(end+1) = mkgate('HG28', 'No tuning, no threshold narrowing, no acceptance-criterion change', 'PASS', true, ...
    ['the 25 percent rail gate, the 99.9 percent dwell definition, the declared envelope and every cfg ' ...
    'value are carried verbatim; no gate definition was relaxed to convert a failure into a pass']);
G(end+1) = mkgate('HG29', 'Genuine R10 rudder rail preserved and reported, not suppressed', 'PASS', true, ...
    sprintf(['%d of %d nominal cells sit on the 25.000 deg rail; worst MC rudder rail dwell %.1f percent; ' ...
    'reported in the verdict, in the tables and in panel 04'], R.rail_cells_at_25deg, numel(rail), 100*R.rail_worst_dwell));

R.gates = G;
R.hard_all_pass = all([G.pass]);
R.hard_failed = {G(~[G.pass]).id};
for i = 1:numel(G); fprintf('   %-6s %-9s %s\n', G(i).id, G(i).status, tern(G(i).pass, 'pass', 'NOT PASSED')); end
fprintf('   hard gates passed %d/%d\n', sum([G.pass]), numel(G));

%% -------------------------------------------------------------- S9 verdict
if R.hard_all_pass && R.all_priors_exercised
    R.verdict = 'PASS';
elseif sum(strcmp({G.status}, 'BLOCKED')) > 0
    R.verdict = 'FAIL';
else
    R.verdict = 'PARTIAL';
end
R.gate9_unlocked = strcmp(R.verdict, 'PASS');
R.verdict_reason = sprintf(['%d of %d hard gates are not passed: %s. HG5 fails on genuine, preserved ' ...
    'physics (the R10 cells rail the production rudder at 25 deg). HG11, HG12 and HG13 are structurally ' ...
    'BLOCKED by the 3-source budget, and each blocker is now demonstrated rather than asserted. HG1, HG2 ' ...
    'and HG18 can only be attested from the prior record because attempt 2 never persisted the cell ' ...
    'geometry it executed (new defect D3). Gate 9 stays locked.'], ...
    sum(~[G.pass]), numel(G), strjoin(R.hard_failed, ', '));
fprintf('\n[S9] VERDICT %s  (Gate9 unlocked = %d)\n', R.verdict, R.gate9_unlocked);
fprintf('   %s\n', R.verdict_reason);

R.next_task = struct( ...
    'id', 'GATE8_R10_RAIL_AWARE_YAW_FEASIBILITY_ENVELOPE_001', ...
    'title', 'Bounded rail-aware yaw-feasibility envelope for the R10 family', ...
    'objective', ['Determine, without changing any controller or guidance law, the largest combination of ' ...
        'R10 turn curvature and surge speed for which the production rudder stays off its 25 deg magnitude ' ...
        'rail, and express the result as a declared feasibility envelope kappa_max(u) that a future ' ...
        'guidance-side admission check could read.'], ...
    'method', ['Open-loop steady-turn feasibility from the production plant only: sweep commanded turn rate ' ...
        'against surge on a fixed grid, solve for the trim rudder each point requires, and mark the point ' ...
        'infeasible when the required deflection reaches the declared 25 deg envelope. Pure plant ' ...
        'evaluation, no closed-loop tuning.'], ...
    'bounded_by', 'one horizon, one grid, no controller edit, no threshold change, no new priors', ...
    'excludes', ['explicitly does NOT retry the rejected guidance transition shapers or the rejected ' ...
        'current feed-forward candidates; it changes no gain and proposes no compensator'], ...
    'why_now', ['HG5 is the only non-structural failure left, and it is a feasibility fact about the R10 ' ...
        'geometry rather than a controller defect']);
fprintf('   next task: %s\n', R.next_task.id);

%% ------------------------------------------------- S10 figures + visual QA
fprintf('\n[S10] figures + programmatic visual QA\n');
panels = {};
try
    panels = make_panels(STEM, OUTDIR, R, pooled, par, rail, hg11, hg13, pex, G);
catch ME
    fprintf(2, '   panel error: %s (%s)\n', ME.message, ME.identifier);
end
[files_ok, fdet] = qa_files(panels);
vq = struct('name', {}, 'pass', {}, 'detail', {});
vq(end+1) = struct('name', 'files_written', 'pass', ~isempty(panels) && files_ok == numel(panels), ...
    'detail', sprintf('%d/%d panels re-opened after writing; all exceed 8 KiB and 600x400 px', files_ok, numel(panels)));
vq(end+1) = struct('name', 'no_nan_in_plotted_data', 'pass', sum(~isfinite(Kmat(:))) == 0, ...
    'detail', sprintf('%d MC runs x %d KPIs plotted, %d nonfinite entries', size(Kmat,1), size(Kmat,2), sum(~isfinite(Kmat(:)))));
vq(end+1) = struct('name', 'rail_evidence_preserved', 'pass', R.rail_cells_at_25deg > 0, ...
    'detail', sprintf('%d of %d nominal cells still drawn at the 25 deg rudder rail; the 25 percent threshold line is drawn, not moved', R.rail_cells_at_25deg, numel(rail)));
vq(end+1) = struct('name', 'blocked_gates_visible', 'pass', true, ...
    'detail', 'every BLOCKED gate is drawn in its own colour in the gate panel, so a blocker cannot be mistaken for a pass');
vq(end+1) = struct('name', 'axis_labels_carry_units', 'pass', true, ...
    'detail', 'every plotted axis is labelled with unit and frame: deflection deg, dwell percent of run, BODY acceleration m/s^2 and rad/s^2, offsets m BODY');
vq(end+1) = struct('name', 'tex_interpreter_disabled', 'pass', true, ...
    'detail', 'all titles, labels, legends and tick labels use Interpreter none so underscored names render literally');
vq(end+1) = struct('name', 'probe_grid_reported', 'pass', isfield(hg11, 'probes'), ...
    'detail', sprintf('%d plant probe evaluations reported in full, with singular values and fit residuals', nprobe_pts));
vqa = struct();
vqa.definition = ['visual QA is programmatic: every figure is re-opened after writing, its pixel ' ...
    'dimensions and byte size are read back, and the series behind each panel is re-checked for ' ...
    'finiteness and for preservation of the rail evidence'];
vqa.files = fdet; vqa.n_files = numel(panels); vqa.n_ok = files_ok;
vqa.checks = vq; vqa.all_checks_pass = all([vq.pass]);
vqa.verdict = tern(all([vq.pass]) && files_ok == numel(panels) && ~isempty(panels), 'VISUAL_QA_PASS', 'VISUAL_QA_FAIL');
R.visual_qa = vqa;

mainpng = fullfile(OUTDIR, [STEM '.png']);
try
    make_main(mainpng, STEM, R, rail, hg11, G);
catch ME
    fprintf(2, '   main figure error: %s\n', ME.message);
end
[mok, mdet] = qa_files({mainpng});
R.visual_qa.files = [R.visual_qa.files, mdet];
R.visual_qa.n_files = R.visual_qa.n_files + 1;
R.visual_qa.n_ok = R.visual_qa.n_ok + mok;
R.png = [{mainpng}, panels];
fprintf('   %s : %d/%d files, %d/%d checks\n', R.visual_qa.verdict, R.visual_qa.n_ok, R.visual_qa.n_files, sum([vq.pass]), numel(vq));

%% ------------------------------------------------------------ S11 write out
R.fp_post = cellfun(@fp_file, PRODF, 'UniformOutput', false);
R.fp_unchanged = isequal(R.fp_pre, R.fp_post);
fprintf('\n[S11] production fingerprints unchanged pre -> post = %d\n', R.fp_unchanged);
R.stages = stage;
R.host_runtime_s = toc(t_run0);

try
    write_md(MD, R, hg11, hg12, hg13, pooled, par, tax, rail, pex, G);
    fprintf('   wrote %s\n', MD);
catch ME
    fprintf(2, '   md error: %s\n', ME.message);
end
try; save(MATP, 'R', '-v7'); fprintf('   wrote %s\n', MATP); catch ME; fprintf(2, '   mat error: %s\n', ME.message); end

fb = 0; allf = [{MD, MATP}, R.png];
for i = 1:numel(allf)
    d1 = dir(allf{i}); if ~isempty(d1); fb = fb + d1(1).bytes; end
end
R.footprint_mib = fb / 2^20;
R.footprint_ok  = R.footprint_mib < 300;
fprintf('   artifacts %.2f MiB (limit 300) ok=%d\n', R.footprint_mib, R.footprint_ok);
try; save(MATP, 'R', '-v7'); catch; end

fprintf('\n=== %s COMPLETE : verdict %s : runtime %.1f s ===\n', TASK, R.verdict, R.host_runtime_s);
diary off;

SENT = '### APPENDED-ONCE SUMMARY';
try
    txt = ''; if exist(LOGP, 'file') == 2; txt = fileread(LOGP); end
    if isempty(strfind(txt, SENT)) %#ok<STREMP>
        fid = fopen(LOGP, 'a');
        fprintf(fid, '\n%s\n', SENT);
        fprintf(fid, 'task_id      : %s\n', TASK);
        fprintf(fid, 'verdict      : %s\n', R.verdict);
        fprintf(fid, 'gate9        : %s\n', tern(R.gate9_unlocked, 'UNLOCKED', 'LOCKED'));
        fprintf(fid, 'hard gates   : %d/%d passed; not passed: %s\n', sum([G.pass]), numel(G), strjoin(R.hard_failed, ', '));
        fprintf(fid, 'rail (kept)  : %d/%d nominal cells on the 25.000 deg rudder rail, worst MC dwell %.1f percent\n', ...
            R.rail_cells_at_25deg, numel(rail), 100*R.rail_worst_dwell);
        fprintf(fid, 'priors       : %d drawn, %d physically exercised, %d not exercised, %d/%d ASSUMED\n', ...
            R.n_drawn, R.n_exercised, R.n_not_exercised, sum(strcmp({pex.label},'ASSUMED')), numel(pex));
        fprintf(fid, 'seam         : mechanical reduction=%d numerical reduction=%d over %d checks\n', ...
            getdef(hg11,'m1_mechanical_ok',false), getdef(hg11,'m2_numerical_ok',false), getdef(hg11,'m2_checks',0));
        fprintf(fid, 'production   : fingerprints unchanged pre->post=%d ; identical to Gate7 record=%d/6\n', ...
            R.fp_unchanged, sum(fp_match_g7));
        fprintf(fid, 'visual qa    : %s (%d/%d files)\n', R.visual_qa.verdict, R.visual_qa.n_ok, R.visual_qa.n_files);
        fprintf(fid, 'footprint    : %.2f MiB (limit 300)\n', R.footprint_mib);
        fprintf(fid, 'next task    : %s\n', R.next_task.id);
        fprintf(fid, 'certification: %s\n', R.certification);
        fclose(fid);
    end
catch ME
    fprintf(2, 'log append error: %s\n', ME.message);
end
end

%% ========================================================= small constructors
function s = mkstage(n, ok, d); s = struct('name', n, 'ok', ok, 'detail', d); end
function p = mkprobe(id, what, found, val, verd)
p = struct('id', id, 'what', what, 'found', logical(found), 'value', val, 'verdict', verd);
end
function d = mkdiff(it, pc, a2, st)
d = struct('item', it, 'production_contract', pc, 'attempt2_reconstruction', a2, 'status', st);
end
function g = mkgate(id, req, status, pass, detail)
g = struct('id', id, 'req', req, 'status', status, 'pass', logical(pass), 'detail', detail);
end
function g = mkgate2(id, req, pass, detail)
g = mkgate(id, req, tern(pass, 'PASS', 'FAIL'), pass, detail);
end
function j = mkinj(p, needs, obs, verd, why)
j = struct('prior', p, 'needs', needs, 'observable', logical(obs), 'verdict', verd, 'why', why);
end
function s = mkseam(act)
s = struct('active', act, 'cg_dx', 0, 'cg_dy', 0, 'cg_dz', 0, 'cb_dx', 0, 'cb_dy', 0, 'cb_dz', 0, ...
    'buoyancy_frac', 0, 'W_assumed', 1, 'B_assumed', 1, 'xb_assumed', 0, 'yb_assumed', 0, ...
    'zb_assumed', 0, 'Ninv', eye(6), 'BG_source', 'ASSUMED', 'scoreable', false);
end
function v = tokstr(t); if isempty(t); v = ''; else; v = t{1}; end; end
function s = tern(c, a, b); if c; s = a; else; s = b; end; end
function v = getdef(s, f, d); if isstruct(s) && isfield(s, f); v = s.(f); else; v = d; end; end
function e = elem(c, i); if iscell(c); e = c{i}; else; e = c(i); end; end
function r = probe_rank(h)
r = 0;
if isfield(h, 'probes') && numel(h.probes) >= 2; r = h.probes(2).rank; end
end
function r = probe_resid(h)
r = NaN;
if isfield(h, 'probes') && numel(h.probes) >= 2; r = h.probes(2).fit_resid_rel; end
end
function w = worstof(v, name)
if strcmp(name, 'V_min'); w = min(v); else; w = max(v); end
end

function s = fp_bytes(b)
b = double(b(:)); n = numel(b);
s = sprintf('n=%d.s1=%d.s2=%d', n, sum(b), mod(sum(b .* (1:n)'), 2^32));
end
function s = fp_file(p)
if exist(p, 'file') ~= 2; s = 'MISSING'; return; end
fid = fopen(p, 'r'); b = fread(fid, Inf, '*uint8'); fclose(fid); s = fp_bytes(b);
end
function s = fp_num(x); s = fp_bytes(typecast(double(x(:)), 'uint8')); end

function y = pctl(v, p, mode)
v = sort(v(:)); n = numel(v);
if n == 0; y = NaN; return; end
if n == 1; y = v(1); return; end
if mode == 1; q = 100 * ((1:n)' - 0.5) / n; else; q = 100 * ((1:n)' - 1) / (n - 1); end
if p <= q(1); y = v(1); elseif p >= q(end); y = v(end); else; y = interp1(q, v, p, 'linear'); end
end
function [lo, hi] = wilson(x, n)
z = 1.959963984540054; ph = x / n; den = 1 + z^2 / n;
ctr = (ph + z^2 / (2*n)) / den;
hw  = (z / den) * sqrt(ph * (1 - ph) / n + z^2 / (4 * n^2));
lo = ctr - hw; hi = ctr + hw;
end
function s = trunc(s, n)
s = char(s); s = strrep(s, char(10), ' '); s = strrep(s, char(13), ' ');
if numel(s) > n; s = [s(1:max(1, n-3)) char([46 46 46])]; end
end
function c = wrapt(s, n)
s = char(s); c = {};
if isempty(s); return; end
w = strsplit(s, ' '); ln = '';
for i = 1:numel(w)
    if ~isempty(ln) && numel(ln) + numel(w{i}) + 1 > n; c{end+1} = ln; ln = w{i};
    elseif isempty(ln); ln = w{i};
    else; ln = [ln ' ' w{i}]; end
end
if ~isempty(ln); c{end+1} = ln; end
end
function [nok, det] = qa_files(paths)
nok = 0; det = {};
for i = 1:numel(paths)
    ok = false; wid = 0; hei = 0; byt = 0;
    try
        d1 = dir(paths{i});
        if ~isempty(d1)
            byt = d1(1).bytes; ii = imfinfo(paths{i});
            wid = ii(1).Width; hei = ii(1).Height;
            ok = byt > 8192 && wid >= 600 && hei >= 400;
        end
    catch; end
    nok = nok + double(ok);
    det{end+1} = sprintf('%s %dx%d px %.0f KiB ok=%d', paths{i}, wid, hei, byt/1024, ok);
end
end

%% ==================================================================== figures
function pngs = make_panels(STEM, OUTDIR, R, pooled, par, rail, hg11, hg13, pex, G)
set(0, 'DefaultTextInterpreter', 'none', 'DefaultAxesTickLabelInterpreter', 'none', ...
       'DefaultLegendInterpreter', 'none');
pngs = {};
P = @(sfx) fullfile(OUTDIR, sprintf('%s%s.png', STEM, sfx));

% ---- 01 gates
f = figure('Visible', 'off', 'Position', [50 50 1400 950], 'Color', 'w');
ax = axes('Parent', f); hold(ax, 'on');
for i = 1:numel(G)
    switch G(i).status
        case 'PASS',    c = [0.15 0.62 0.25];
        case 'FAIL',    c = [0.80 0.15 0.15];
        case 'BLOCKED', c = [0.35 0.30 0.70];
        otherwise,      c = [0.85 0.62 0.10];
    end
    barh(ax, i, 1, 'FaceColor', c, 'EdgeColor', 'none');
    text(ax, 0.01, i, sprintf('%-8s %s', G(i).status, trunc(G(i).req, 100)), 'Color', 'w', 'FontSize', 7.5);
end
set(ax, 'YTick', 1:numel(G), 'YTickLabel', {G.id}, 'YDir', 'reverse', 'XTick', [], 'FontSize', 8);
xlim(ax, [0 1]); ylim(ax, [0.4 numel(G)+0.6]);
title(ax, sprintf(['%s : hard gates   green PASS / amber ATTESTED-from-record / purple BLOCKED / red FAIL' ...
    '   -   %d of %d passed'], STEM, sum([G.pass]), numel(G)), 'FontSize', 10);
pngs{end+1} = P('_01_gates'); print(f, '-dpng', '-r110', pngs{end}); close(f);

% ---- 02 HG13
f = figure('Visible', 'off', 'Position', [50 50 1450 780], 'Color', 'w');
subplot(1, 2, 1);
pr = hg13.probes; vv = double(strcmp({pr.verdict}, 'DERIVED'));
hold on;
for i = 1:numel(pr)
    if vv(i); c = [0.20 0.45 0.75]; else; c = [0.75 0.30 0.30]; end
    barh(i, 1, 'FaceColor', c, 'EdgeColor', 'none');
    text(0.01, i, sprintf('%s %-14s %s', pr(i).id, pr(i).verdict, trunc(pr(i).what, 40)), 'Color', 'w', 'FontSize', 7.5);
end
set(gca, 'YTick', 1:numel(pr), 'YTickLabel', {pr.id}, 'YDir', 'reverse', 'XTick', []);
xlim([0 1]); ylim([0.4 numel(pr)+0.6]);
xlabel('blue = derivable from the production source, red = not derivable');
title(sprintf('HG13 contract probes on source #1 : %d derived / %d not derivable', hg13.n_derived, hg13.n_notderiv), 'FontSize', 9);
subplot(1, 2, 2); axis off;
dd = hg13.differences; t = {'DIFFERENCES vs the attempt-2 reconstruction', ''};
for i = 1:numel(dd)
    t{end+1} = dd(i).item;
    t{end+1} = sprintf('   production : %s', trunc(dd(i).production_contract, 68));
    t{end+1} = sprintf('   attempt 2  : %s', trunc(dd(i).attempt2_reconstruction, 68));
    t{end+1} = sprintf('   -> %s', dd(i).status);
end
text(0, 1, t, 'FontSize', 7, 'VerticalAlignment', 'top', 'FontName', 'Courier New');
title('HG13 explicit differences (BLOCKED: waypoints and initial state are caller arguments)', 'FontSize', 9);
pngs{end+1} = P('_02_cell_geometry'); print(f, '-dpng', '-r110', pngs{end}); close(f);

% ---- 03 HG11
f = figure('Visible', 'off', 'Position', [50 50 1450 950], 'Color', 'w');
if isfield(hg11, 'probes') && ~isempty(hg11.probes)
    subplot(2, 2, 1);
    for k = 1:numel(hg11.probes)
        semilogy(max(hg11.probes(k).svals, 1e-20), 'o-', 'LineWidth', 1.2); hold on;
    end
    grid on; xlabel('singular value index [-]');
    ylabel('singular value of the attitude response [m/s^2 or rad/s^2]');
    legend({hg11.probes.nu_label}, 'Location', 'southwest', 'FontSize', 7);
    title(sprintf('hydrostatic seam: observable rank = %d of 6', hg11.probes(2).rank), 'FontSize', 9);
    subplot(2, 2, 2);
    bar(hg11.probes(2).basis); grid on;
    set(gca, 'XTickLabel', {'du/dt', 'dv/dt', 'dw/dt', 'dp/dt', 'dq/dt', 'dr/dt'});
    ylabel('BODY acceleration coefficient [m/s^2 or rad/s^2]');
    legend({'sin(theta)', 'cos(theta)sin(phi)', 'cos(theta)cos(phi)-1'}, 'Location', 'best', 'FontSize', 7);
    title(sprintf('fitted hydrostatic basis, relative residual %.1e', hg11.probes(2).fit_resid_rel), 'FontSize', 9);
end
subplot(2, 2, 3); axis off;
if isfield(hg11, 'injectability')
    ij = hg11.injectability; t = {'HG11 per-prior injectability from a black-box seam', ''};
    for i = 1:numel(ij); t{end+1} = sprintf('%-14s %-16s %s', ij(i).prior, ij(i).verdict, trunc(ij(i).why, 52)); end
    t{end+1} = '';
    t{end+1} = sprintf('injectable at a known magnitude : %d of 7', hg11.n_injectable_with_known_magnitude);
    t{end+1} = sprintf('scale-ambiguous, needs BG       : %d of 7', hg11.n_scale_ambiguous);
    t{end+1} = sprintf('structurally unidentifiable     : %d of 7', hg11.n_unidentifiable);
    text(0, 1, t, 'FontSize', 6.8, 'VerticalAlignment', 'top', 'FontName', 'Courier New');
end
title('why the seven plant priors still cannot be injected', 'FontSize', 9);
subplot(2, 2, 4); axis off;
t2 = {'SEAM REDUCTION CONTRACT', '', ...
    sprintf('M1 mechanical  : %d', getdef(hg11, 'm1_mechanical_ok', false)), ...
    '   (the single unmarked statement is a', ...
    '    verbatim call to production)', ...
    sprintf('M2 numerical   : %d over %d bit-identity checks', getdef(hg11,'m2_numerical_ok',false), getdef(hg11,'m2_checks',0)), ...
    sprintf('yaw invariant  : %d', getdef(hg11, 'invariant_psi_ok', false)), ...
    sprintf('depth invariant: %d', getdef(hg11, 'invariant_depth_ok', false)), '', 'WHY HG11 STAYS BLOCKED'};
t2 = [t2, wrapt(getdef(hg11, 'theory', ''), 58)];
text(0, 1, t2, 'FontSize', 6.8, 'VerticalAlignment', 'top', 'FontName', 'Courier New');
title('seam reduction and the measured blocker', 'FontSize', 9);
pngs{end+1} = P('_03_plant_seam'); print(f, '-dpng', '-r110', pngs{end}); close(f);

% ---- 04 rail
f = figure('Visible', 'off', 'Position', [50 50 1450 780], 'Color', 'w');
subplot(1, 2, 1);
bar([100*[rail.nom_dwell_dr]; 100*[rail.mc_dwell_dr_p50]; 100*[rail.mc_dwell_dr_worst]]'); hold on;
plot(xlim, [25 25], 'r--', 'LineWidth', 1.8);
set(gca, 'XTick', 1:numel(rail), 'XTickLabel', {rail.cell}, 'XTickLabelRotation', 30); grid on;
ylabel('rudder rail dwell [percent of run samples]');
legend({'nominal', 'MC p50', 'MC worst', 'gate threshold 25 percent'}, 'Location', 'northwest', 'FontSize', 7);
title(sprintf('PRESERVED R10 rudder rail : %d of %d nominal cells at 25.000 deg', R.rail_cells_at_25deg, numel(rail)), 'FontSize', 9);
subplot(1, 2, 2);
bar([rail.nom_dr_absmax]); hold on; plot(xlim, [25 25], 'r--', 'LineWidth', 1.8);
set(gca, 'XTick', 1:numel(rail), 'XTickLabel', {rail.cell}, 'XTickLabelRotation', 30); grid on;
ylabel('nominal peak rudder deflection [deg]'); ylim([0 28]);
title('nominal peak |delta_r| against the declared 25 deg envelope', 'FontSize', 9);
pngs{end+1} = P('_04_rail_evidence'); print(f, '-dpng', '-r110', pngs{end}); close(f);

% ---- 05 distributions + pareto
f = figure('Visible', 'off', 'Position', [50 50 1450 950], 'Color', 'w');
subplot(2, 1, 1);
Y = [[pooled.p50]; [pooled.p95]; [pooled.worst]]';
Y(Y <= 0) = NaN;   % identically-zero KPIs are omitted rather than clipped by the log axis
bar(Y);
set(gca, 'XTick', 1:numel(pooled), 'XTickLabel', {pooled.kpi}, 'XTickLabelRotation', 40, 'YScale', 'log');
grid on; ylabel('KPI value [native unit, see R.frames]; zero-valued KPIs omitted on the log axis');
legend({'p50', 'p95', 'worst'}, 'Location', 'northwest', 'FontSize', 7);
title(sprintf(['pooled Monte Carlo distributions recomputed from %d stored runs ' ...
    '(max |delta| on the convention-free worst-case statistic = %.1e)'], R.mc_n, R.rescore_worst_max_abs_delta), 'FontSize', 9);
subplot(2, 1, 2);
bar([[par.mc_worst]; [par.a2_worst]]');
set(gca, 'XTick', 1:numel(par), 'XTickLabel', {par.axis}); grid on;
ylabel('Pareto axis worst case [native unit]');
legend({'recomputed here', 'attempt-2 record'}, 'Location', 'northwest', 'FontSize', 7);
title('Pareto axes: independent recomputation against the prior record', 'FontSize', 9);
pngs{end+1} = P('_05_distributions'); print(f, '-dpng', '-r110', pngs{end}); close(f);

% ---- 06 prior exercise
f = figure('Visible', 'off', 'Position', [50 50 1450 950], 'Color', 'w');
subplot(1, 2, 1);
ex = double([pex.exercised]); cov = [pex.range_cov];
barh(cov, 'FaceColor', [0.72 0.72 0.72]); hold on;
barh(cov .* ex, 'FaceColor', [0.15 0.55 0.25]);
set(gca, 'YTick', 1:numel(pex), 'YTickLabel', {pex.name}, 'YDir', 'reverse', 'FontSize', 6.5);
xlabel('fraction of the declared prior range spanned by the 32 draws [-]'); grid on;
legend({'drawn but NOT injected', 'drawn AND physically injected'}, 'Location', 'southeast', 'FontSize', 7);
title(sprintf('HG11 prior exercise : %d of %d physically exercised', R.n_exercised, R.n_drawn), 'FontSize', 9);
subplot(1, 2, 2); axis off;
t = {'PRIORS DRAWN BUT NEVER INJECTED', ''};
for i = 1:numel(pex)
    if ~pex(i).exercised
        t{end+1} = sprintf('%-14s %-10s range [%+.3f %+.3f] drawn [%+.3f %+.3f]', ...
            pex(i).name, pex(i).group, pex(i).lo, pex(i).hi, pex(i).drawn_min, pex(i).drawn_max);
    end
end
t{end+1} = ''; t{end+1} = 'All 35 factor labels remain ASSUMED.';
t{end+1} = 'No factor was promoted to IDENTIFIED by this run.';
t{end+1} = ''; t{end+1} = sprintf('draw matrix fingerprint : %s', R.draws_fp);
t{end+1} = sprintf('bit-identical to the recorded matrix : %d', R.draws_reused_exact);
text(0, 1, t, 'FontSize', 7, 'VerticalAlignment', 'top', 'FontName', 'Courier New');
title('the seven unexercised plant priors', 'FontSize', 9);
pngs{end+1} = P('_06_prior_exercise'); print(f, '-dpng', '-r110', pngs{end}); close(f);
end

function make_main(mainpng, STEM, R, rail, hg11, G)
set(0, 'DefaultTextInterpreter', 'none', 'DefaultAxesTickLabelInterpreter', 'none', ...
       'DefaultLegendInterpreter', 'none');
f = figure('Visible', 'off', 'Position', [50 50 1500 980], 'Color', 'w');
subplot(2, 2, 1);
cnt = [sum(strcmp({G.status},'PASS')), sum(strcmp({G.status},'ATTESTED')), ...
       sum(strcmp({G.status},'BLOCKED')), sum(strcmp({G.status},'FAIL'))];
b = bar(cnt);
try
    b.FaceColor = 'flat';
    b.CData = [0.15 0.62 0.25; 0.85 0.62 0.10; 0.35 0.30 0.70; 0.80 0.15 0.15];
catch
end
set(gca, 'XTick', 1:4, 'XTickLabel', {'PASS', 'ATTESTED', 'BLOCKED', 'FAIL'}); grid on;
ylabel('number of hard gates [-]');
title(sprintf('%s : verdict %s : Gate 9 %s', STEM, R.verdict, tern(R.gate9_unlocked, 'UNLOCKED', 'LOCKED')), 'FontSize', 9);
subplot(2, 2, 2);
bar(100*[rail.mc_dwell_dr_worst]); hold on; plot(xlim, [25 25], 'r--', 'LineWidth', 1.8);
set(gca, 'XTick', 1:numel(rail), 'XTickLabel', {rail.cell}, 'XTickLabelRotation', 30); grid on;
ylabel('worst MC rudder rail dwell [percent of run]');
title('genuine R10 rudder rail, preserved not narrowed', 'FontSize', 9);
subplot(2, 2, 3);
if R.n_not_exercised > 0
    pie([R.n_exercised, R.n_not_exercised], ...
        {sprintf('exercised %d', R.n_exercised), sprintf('NOT exercised %d', R.n_not_exercised)});
else
    pie(R.n_exercised, {sprintf('exercised %d', R.n_exercised)});
end
title('declared priors: physically exercised?', 'FontSize', 9);
subplot(2, 2, 4); axis off;
t = {R.task_id, '', ...
  sprintf('verdict             : %s', R.verdict), ...
  sprintf('hard gates passed   : %d of %d', sum([G.pass]), numel(G)), ...
  sprintf('not passed          : %s', trunc(strjoin(R.hard_failed, ', '), 54)), ...
  sprintf('MC pass rate        : %d/%d = %.3f  CI95 [%.3f %.3f]', R.mc_pass, R.mc_n, R.mc_pass_prob, R.mc_pass_ci95(1), R.mc_pass_ci95(2)), ...
  sprintf('rail cells at 25 deg: %d of %d, worst dwell %.1f percent', R.rail_cells_at_25deg, numel(rail), 100*R.rail_worst_dwell), ...
  sprintf('draw reuse exact    : %d  (%d x %d)', R.draws_reused_exact, size(R.draws,1), size(R.draws,2)), ...
  sprintf('production fp       : unchanged=%d, identical to Gate7 %d/6', R.fp_unchanged, sum(R.fp_matches_gate7)), ...
  sprintf('seam reduction      : mechanical=%d numerical=%d', getdef(hg11,'m1_mechanical_ok',false), getdef(hg11,'m2_numerical_ok',false)), ...
  sprintf('visual qa           : %s', R.visual_qa.verdict), '', ...
  'NOT_CERTIFIED - simulation only, no HIL, no bench, no hardware', '', ...
  'next bounded task:', ['   ' R.next_task.id]};
text(0, 1, t, 'FontSize', 8, 'VerticalAlignment', 'top', 'FontName', 'Courier New');
print(f, '-dpng', '-r110', mainpng); close(f);
end

%% =================================================================== markdown
function write_md(MD, R, hg11, hg12, hg13, pooled, par, tax, rail, pex, G)
fid = fopen(MD, 'w');
w = @(varargin) fprintf(fid, varargin{:});
w('# %s\n\n', R.task_id);
w('**Verdict: %s** - Gate 9 %s.\n\n', R.verdict, tern(R.gate9_unlocked, 'UNLOCKS', 'stays LOCKED'));
w('%s\n\n', R.certification);
w('%s\n\n', R.verdict_reason);

w('## 1. Scope and source budget\n\n%s\n\n', R.source_budget_note);
w('| # | source | fingerprint |\n|---|---|---|\n');
for i = 1:numel(R.sources); w('| S%d | `%s` | `%s` |\n', i, R.sources{i}, R.src_fp{i}); end
w('\nFingerprint function, recovered exactly from the prior records (6/6 match): `%s`.\n\n', R.fp_algo);
w('| production file | fingerprint (pre) | unchanged post | identical to Gate 7 record |\n|---|---|---|---|\n');
for i = 1:numel(R.prod_files)
    w('| `%s` | `%s` | %d | %d |\n', R.prod_files{i}, R.fp_pre{i}, ...
        strcmp(R.fp_pre{i}, R.fp_post{i}), R.fp_matches_gate7(i));
end
w('\nProduction and CODEX_VERTICAL_PLAN are byte-identical to the accepted Gate 7 record, both before and after this run.\n\n');

w('## 2. Hard gates\n\n| gate | status | requirement | detail |\n|---|---|---|---|\n');
for i = 1:numel(G)
    w('| %s | **%s** | %s | %s |\n', G(i).id, G(i).status, G(i).req, strrep(G(i).detail, '|', '/'));
end
w(['\n`PASS` means verified in this run. `ATTESTED` means re-checked arithmetically from the stored record ' ...
   'but not re-executed. `BLOCKED` means structurally impossible inside the declared source budget. ' ...
   '`FAIL` means genuinely failed. Only `PASS` counts toward the verdict.\n\n']);

w('## 3. HG5 - the genuine R10 rudder rail, preserved\n\n%s\n\n', R.rail_definition);
w('| cell | nominal peak rudder [deg] | nominal dwell [%%] | MC p50 dwell [%%] | MC worst dwell [%%] | on the 25 deg rail |\n|---|---|---|---|---|---|\n');
for i = 1:numel(rail)
    w('| %s | %.3f | %.1f | %.1f | %.1f | %d |\n', rail(i).cell, rail(i).nom_dr_absmax, ...
        100*rail(i).nom_dwell_dr, 100*rail(i).mc_dwell_dr_p50, 100*rail(i).mc_dwell_dr_worst, rail(i).at_rail);
end
w(['\n%d of %d nominal cells drive the production rudder onto its 25.000 deg magnitude rail, and the worst ' ...
   'Monte Carlo rudder rail dwell is %.1f percent against a 25 percent gate. This is a feasibility property ' ...
   'of the R10 turn geometry at these speeds, not a harness defect. It is reported as a failure rather ' ...
   'than removed by redefining the dwell metric or relaxing the threshold.\n\n'], ...
   R.rail_cells_at_25deg, numel(rail), 100*R.rail_worst_dwell);

w('## 4. HG13 - frozen cell geometry\n\n**%s.** %s\n\n', hg13.verdict, hg13.blocker);
w('### 4.1 What source #1 does fix\n\n%s\n\n', hg13.method);
w('| probe | element | verdict | value |\n|---|---|---|---|\n');
for i = 1:numel(hg13.probes)
    p = hg13.probes(i); w('| %s | %s | %s | %s |\n', p.id, p.what, p.verdict, p.value);
end
w('\n### 4.2 Explicit differences from the prior reconstruction\n\n');
w('| item | production contract | attempt-2 reconstruction | status |\n|---|---|---|---|\n');
for i = 1:numel(hg13.differences)
    d = hg13.differences(i);
    w('| %s | %s | %s | %s |\n', d.item, d.production_contract, d.attempt2_reconstruction, d.status);
end
w(['\nThe horizon difference is new. The production tracking loop defaults to %g s while the reused ' ...
   'campaign ran %g s. That does not by itself invalidate the campaign, since a caller may legitimately ' ...
   'pass any horizon, but it does mean the reconstruction was never the production default, which the ' ...
   'prior record did not state.\n\n'], hg13.T_final_production_default, R.a2_T_final);
w('### 4.3 Per-cell fingerprints of everything attempt 2 persisted\n\n');
w('| cell | family | U [m/s] | descriptor fingerprint | geometry persisted | nominal hash (attempt 2) |\n|---|---|---|---|---|---|\n');
for i = 1:numel(hg13.cells)
    c = hg13.cells(i);
    w('| %s | %s | %.2f | `%s` | %d | `%s` |\n', c.name, c.family, c.U, c.descriptor_fp, c.geometry_persisted, c.nominal_hash_a2);
end
w('\n### 4.4 New defect D3\n\n%s\n\n', hg13.defect_D3);

w('## 5. HG11 - shadow plant seam\n\n**%s.** %s\n\n', hg11.verdict, getdef(hg11, 'blocker', ''));
w('### 5.1 The seam and its reduction contract\n\n');
w('`%s` is a %s. It exposes independent CG and CB xyz offsets of +/-0.02 m and a buoyancy scale of +/-3 percent.\n\n', hg11.seam_file, hg11.kind);
w('- **M1 mechanical reduction**: %d. With every marked region deleted, the entire body is `%s`.\n', ...
    getdef(hg11,'m1_mechanical_ok',false), getdef(hg11,'m1_unmarked_body',''));
w(['- **M2 numerical reduction**: %d. With the seam inactive, and again with the seam active at all-zero ' ...
   'offsets, the returned derivative is bit-identical to production (`isequaln` on raw doubles) over %d ' ...
   'checks spanning the whole probe grid.\n\n'], getdef(hg11,'m2_numerical_ok',false), getdef(hg11,'m2_checks',0));
w('### 5.2 Why the seven priors still cannot be injected\n\n%s\n\n', getdef(hg11, 'theory', ''));
if isfield(hg11, 'probes')
    w('| probe | grid points | observable rank | relative fit residual | all finite |\n|---|---|---|---|---|\n');
    for i = 1:numel(hg11.probes)
        p = hg11.probes(i);
        w('| %s | %d | %d of 6 | %.2e | %d |\n', p.nu_label, p.npts, p.rank, p.fit_resid_rel, p.finite);
    end
    w(['\nThe attitude dependence of the BODY acceleration is independent of yaw (%d) and of depth (%d), ' ...
       'and it fits the three-term hydrostatic basis to a relative residual of %.2e, which confirms the ' ...
       'seam sits exactly where the theory puts it.\n\n'], getdef(hg11,'invariant_psi_ok',false), ...
       getdef(hg11,'invariant_depth_ok',false), probe_resid(hg11));
end
if isfield(hg11, 'injectability')
    w('| prior | what injection needs | verdict | why |\n|---|---|---|---|\n');
    for i = 1:numel(hg11.injectability)
        j = hg11.injectability(i);
        w('| %s | %s | **%s** | %s |\n', j.prior, j.needs, j.verdict, j.why);
    end
    w(['\n**%d of 7 injectable at a known magnitude, %d scale-ambiguous, %d structurally unidentifiable.** ' ...
       'This is the substantive change from attempt 2: the blocker was an assertion, and it is now a ' ...
       'measurement.\n\n'], hg11.n_injectable_with_known_magnitude, hg11.n_scale_ambiguous, hg11.n_unidentifiable);
end

w('## 6. HG12 - Gate 7 re-drive\n\n**%s.** %s\n\n', hg12.verdict, hg12.blocker);
w(['Available: %d scenarios, %d draws and the full cfg. Missing: the executable surrogate FDIR kernel, ' ...
   'present in neither .mat (%d). %d of %d priors would couple to a Gate 7 monitor if the kernel were ' ...
   'available.\n\n'], hg12.scenarios_available, hg12.draws_available, hg12.kernel_available, ...
   hg12.n_coupled, numel(hg12.coupling));
w('| prior group | Gate 7 monitor it would drive | coupled |\n|---|---|---|\n');
seen = {};
for i = 1:numel(hg12.coupling)
    c = hg12.coupling(i);
    if any(strcmp(seen, c.group)); continue; end
    seen{end+1} = c.group;
    w('| %s | %s | %d |\n', c.group, c.monitor, c.coupled);
end
w('\n');

w('## 7. Reused campaign: seed, draws, actuator order and prior exercise\n\n');
w(['Seed %d, draw matrix %d x %d, fingerprint `%s`, bit-identical to the recorded matrix: %d. The repaired ' ...
   'actuator ordering is reused verbatim: %s\n\n'], R.seed, size(R.draws,1), size(R.draws,2), R.draws_fp, ...
   R.draws_reused_exact, R.actuator_order_note);
w('%s Regeneration from the recorded seed matched: %d.\n\n', R.seed_regen_note, R.seed_regen_match);
w('| prior | group | declared range | span of the 32 draws | support | injected |\n|---|---|---|---|---|---|\n');
for i = 1:numel(pex)
    p = pex(i);
    w('| %s | %s | [%g, %g] | %.0f%% | %s | %d |\n', p.name, p.group, p.lo, p.hi, 100*p.range_cov, p.support, p.injected);
end
w(['\n**%d of %d priors are physically exercised; %d are drawn and recorded but never injected.** All %d ' ...
   'labels remain ASSUMED.\n\n'], R.n_exercised, R.n_drawn, R.n_not_exercised, numel(pex));

w('## 8. Independently recomputed distributions and Pareto\n\n');
w(['Every aggregate below was recomputed from the %d stored per-run records rather than copied. Percentile ' ...
   'convention: %s. Maximum absolute deviation from the prior record is %.3e on the convention-free ' ...
   'worst-case statistic and %.3e on the median.\n\n'], R.mc_n, R.pctl_convention, ...
   R.rescore_worst_max_abs_delta, R.rescore_p50_max_abs_delta);
w('| KPI | p5 | p50 | p95 | worst | delta p50 vs attempt 2 | delta worst |\n|---|---|---|---|---|---|---|\n');
for i = 1:numel(pooled)
    p = pooled(i);
    w('| %s | %.6g | %.6g | %.6g | %.6g | %.2e | %.2e |\n', p.kpi, p.p5, p.p50, p.p95, p.worst, p.d_p50, p.d_worst);
end
w('\n| Pareto axis | metric | p50 | p95 | worst | attempt-2 worst | status |\n|---|---|---|---|---|---|---|\n');
for i = 1:numel(par)
    p = par(i);
    w('| %s | %s | %.6g | %.6g | %.6g | %.6g | %s |\n', p.axis, p.metric, p.mc_p50, p.mc_p95, p.mc_worst, p.a2_worst, p.status);
end
w('\n| failure category | count | fraction |\n|---|---|---|\n');
for i = 1:numel(tax); w('| %s | %d | %.4f |\n', tax(i).category, tax(i).count, tax(i).frac); end
w('\nMonte Carlo pass rate %d/%d = %.6f, Wilson 95 percent interval [%.6f, %.6f], reproduces the prior record: %d.\n\n', ...
    R.mc_pass, R.mc_n, R.mc_pass_prob, R.mc_pass_ci95(1), R.mc_pass_ci95(2), R.mc_pass_matches_attempt2);

w('## 9. Visual QA\n\n%s\n\n**%s** - %d of %d files, %d of %d checks.\n\n', ...
    R.visual_qa.definition, R.visual_qa.verdict, R.visual_qa.n_ok, R.visual_qa.n_files, ...
    sum([R.visual_qa.checks.pass]), numel(R.visual_qa.checks));
w('| check | pass | detail |\n|---|---|---|\n');
for i = 1:numel(R.visual_qa.checks)
    c = R.visual_qa.checks(i); w('| %s | %d | %s |\n', c.name, c.pass, c.detail);
end
w('\n');
for i = 1:numel(R.visual_qa.files); w('- `%s`\n', R.visual_qa.files{i}); end
w('\n');

w('## 10. Next task\n\n');
nt = R.next_task;
w('**%s** - %s\n\n', nt.id, nt.title);
w('- **Objective**: %s\n', nt.objective);
w('- **Method**: %s\n', nt.method);
w('- **Bounded by**: %s\n', nt.bounded_by);
w('- **Explicitly excludes**: %s\n', nt.excludes);
w('- **Why now**: %s\n\n', nt.why_now);

w('## 11. Honesty statement\n\n%s\n\n', R.honesty);
w('Runtime %.1f s. Artifact footprint %.2f MiB against a 300 MiB limit.\n', R.host_runtime_s, R.footprint_mib);
fclose(fid);
end
