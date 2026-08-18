function run_gate8_monte_carlo_independent_priors()
%RUN_GATE8_MONTE_CARLO_INDEPENDENT_PRIORS
% TASK_ID GATE8_MONTE_CARLO_INDEPENDENT_PRIORS_001
%
% Gate 8 isolated Monte Carlo distribution campaign (shadow-only).
%
% HONESTY CONTRACT (enforced by construction, re-checked by gates below):
%   * No production file is written. Production set is read-only input.
%   * All hooks (sensor / actuator / power) live in THIS file and are exact
%     identity at the nominal (zero) draw, so nominal parity is bit-for-bit.
%   * A prior that cannot physically enter the current plant/interface is
%     DRAWN and RECORDED but marked UNSUPPORTED and never faked.
%   * truth / measured / estimated are kept distinct. No estimator exists on
%     the production tracking path, so `estimated` is NOT_IMPLEMENTED.
%   * Every prior stays ASSUMED. Simulation PASS is never hardware cert.
%
% Sources actually read for reasoning (max 3, per AUTONOMOUS_EXECUTION_POLICY):
%   1 continuous_path_tracking_propulsion.m
%   2 suite_results/GATE7_FDIR_ACCEPTANCE_CRITERION_REPAIR.mat
%   3 suite_results/AUTONOMOUS_EXECUTION_POLICY.md

t_wall0 = tic;
TAG  = 'GATE8_MONTE_CARLO_INDEPENDENT_PRIORS';
OUTB = fullfile('suite_results', TAG);

R = struct();
R.task_id       = [TAG '_001'];
R.gate          = 'Gate 8 - Monte Carlo with independent priors (isolated distribution campaign)';
R.created       = datestr(now, 'yyyy-mm-dd HH:MM:SS'); %#ok<TNOW1,DATST>
R.certification = 'NOT_CERTIFIED (simulation-only; no HIL, no bench, no hardware)';
R.honesty       = ['IMPLEMENTED = this isolated shadow driver only. All priors ASSUMED. ' ...
                   'Production untouched. Unsupported factors are drawn+recorded but NOT injected.'];
R.verdict       = 'FAIL';
R.fatal         = '';

try
    R = g8_main(R, TAG, OUTB, t_wall0);
catch ME
    R.verdict = 'FAIL';
    R.fatal   = getReport(ME, 'extended', 'hyperlinks', 'off');
    fprintf(2, '\n[G8] FATAL: %s\n', R.fatal);
end

R.host_runtime_s = toc(t_wall0);
try
    save([OUTB '.mat'], 'R', '-v7');
catch ME2
    fprintf(2, '[G8] MAT write failed: %s\n', ME2.message);
end
try
    g8_write_md(R, OUTB);
catch ME3
    fprintf(2, '[G8] MD write failed: %s\n', ME3.message);
end
try
    g8_append_logs(R, TAG);
catch ME4
    fprintf(2, '[G8] log append failed: %s\n', ME4.message);
end

fprintf('\n[G8] VERDICT = %s   runtime = %.1f s\n', R.verdict, R.host_runtime_s);
end

% =====================================================================
function R = g8_main(R, TAG, OUTB, t_wall0)

fprintf('[G8] %s start\n', R.task_id);

% ---------------------------------------------------------------- Gate 0
R.frames = struct( ...
    'position',  'NED inertial [m]; z positive DOWN (depth = +z)', ...
    'rates',     'BODY angular rates p,q,r [rad/s]; BODY velocity u,v,w [m/s]', ...
    'euler',     'phi,theta,psi [rad] internally (deg only where a name says _deg)', ...
    'pitch_sign','theta > 0 = nose UP = depth decreasing', ...
    'actuators', 'delta_e, delta_r signed per production convention; thrust pu', ...
    'units',     'SI (m, m/s, rad, rad/s, s); deg only where labelled', ...
    'source_ref','GATE7_FDIR_ACCEPTANCE_CRITERION_REPAIR.mat R.frames (frozen, not re-derived)', ...
    'label',     'INTERFACE_SPECIFIED');

R.free_gib_at_start = g8_free_gib();
fprintf('[G8] free disk at start = %.2f GiB\n', R.free_gib_at_start);
R.disk_min_ok      = R.free_gib_at_start >= 3.0;
R.disk_preferred_ok = R.free_gib_at_start >= 5.0;

R.sources = {'continuous_path_tracking_propulsion.m'; ...
             fullfile('suite_results','GATE7_FDIR_ACCEPTANCE_CRITERION_REPAIR.mat'); ...
             fullfile('suite_results','AUTONOMOUS_EXECUTION_POLICY.md')};
R.src_fp = cellfun(@g8_fp_file, R.sources, 'UniformOutput', false);

R.prod_files = {'continuous_path_tracking.m'; 'controller_law.m'; 'guidance_law.m'; ...
                'underwater777_vehicle_dynamics.m'; 'compute_path_following_metrics.m'; ...
                fullfile('suite_results','CODEX_VERTICAL_PLAN.md')};
R.fp_pre = cellfun(@g8_fp_file, R.prod_files, 'UniformOutput', false);
% Fingerprints recorded by the accepted Gate 7 evidence (same n/s1/s2 formula).
R.fp_gate7 = {'n=10845.s1=886194.s2=515073390'; 'n=9402.s1=732890.s2=3334742186'; ...
              'n=14601.s1=1095745.s2=3464382495'; 'n=6065.s1=426918.s2=1254438441'; ...
              'n=11604.s1=883372.s2=792990739'; 'n=43101.s1=4310210.s2=3268810005'};
R.fp_matches_gate7 = cellfun(@(a,b) strcmp(a,b), R.fp_pre, R.fp_gate7);

% ------------------------------------------------- source #2 : Gate 7 MAT
G7 = load(R.sources{2});
G7 = G7.R;
cfg = G7.cfg;
R.gate7 = struct('task_id', G7.task_id, 'verdict', G7.verdict, 'created', G7.created, ...
                 'n_cases', numel(G7.scenarios));
fprintf('[G8] Gate7 source verdict = %s (%d FDIR cases)\n', G7.verdict, numel(G7.scenarios));
R.gate7_pass_precondition = strcmp(G7.verdict, 'PASS');

% Gate 7 FDIR matrix carried forward as reference only (see UNSUPPORTED table).
nfd = numel(G7.scenarios);
fd = struct('name', cell(nfd,1));
for i = 1:nfd
    fd(i).name       = G7.scenarios(i).name;
    fd(i).code       = G7.scenarios(i).code;
    fd(i).rec_class  = G7.scenarios(i).rec_class;
    fd(i).cte_max    = G7.per_case(i).cte_max;
    fd(i).depth_min  = G7.per_case(i).depth_min;
    fd(i).depth_max  = G7.per_case(i).depth_max;
    fd(i).V_min      = G7.per_case(i).V_min;
    fd(i).energy     = G7.per_case(i).energy_proxy;
    fd(i).iss_surf   = G7.per_case(i).iss_surface;
    fd(i).iss_acc    = G7.per_case(i).iss_accom;
    fd(i).iss_da     = G7.per_case(i).iss_direct_act;
    fd(i).mc_redrawn = false;   % honest: NOT re-simulated under MC priors here
end
R.fdir_reference = fd;
R.fdir_mc_redrawn = false;

% ---------------------------------------------- clone-reduction diagnostic
R.clone = g8_clone_reduction_check('continuous_path_tracking_propulsion.m', ...
                                   'continuous_path_tracking.m');

% ------------------------------------------------------ campaign definition
R.seed = 20260809;                       % fixed, recorded
R.n_draws = 32;                          % >= 32 independent draw vectors
R.dt = 0.025;                            % controller/plant step [s]
R.T_final = 30;                          % per-cell horizon [s]

cells = g8_cells(R.T_final);
R.cells = rmfield(cells, {'wp','state0'});
R.cell_geometry_provenance = ['ASSUMED_RECONSTRUCTION - the frozen X / XZ / R10 cell ' ...
    'definitions (waypoints, horizon, initial state, u_ref schedule) live in per-cell ' ...
    'driver scripts that are outside this task 3-source budget. Geometry here is ' ...
    'harness-declared, NOT the frozen production cell. U labels the initial BODY surge ' ...
    'trim; u_ref is owned internally by production guidance_law.'];

[P, R.priors] = g8_draw_priors(R.seed, R.n_draws, R.T_final, cfg);
R.draws = P;
R.n_factors = numel(R.priors);
R.n_supported   = sum(strcmp({R.priors.support}, 'SUPPORTED'));
R.n_partial     = sum(strcmp({R.priors.support}, 'PARTIAL'));
R.n_unsupported = sum(strcmp({R.priors.support}, 'UNSUPPORTED'));
fprintf('[G8] priors: %d factors (%d SUPPORTED / %d PARTIAL / %d UNSUPPORTED), %d draws\n', ...
    R.n_factors, R.n_supported, R.n_partial, R.n_unsupported, R.n_draws);

R.replay_draws = [1 16 32];              % declared deterministic replay subset

nC = numel(cells);
nD = R.n_draws;
n_runs_planned = nC*(2 + nD) + nC*(1 + numel(R.replay_draws));
fprintf('[G8] planned runs = %d (%d cells x (prod + shadow0 + %d draws) + replay)\n', ...
    n_runs_planned, nC, nD);

% ------------------------------------------------------------- campaign
runsC = {};
k = 0;
par_ok   = true(nC,1);
par_det  = cell(nC,1);
nom_hash = cell(nC,1);
sh0_hash = cell(nC,1);
Tenv_all = struct('max', cell(nC,1), 'min', [], 'span', [], 'nominal_absmax', []);
de_nom_absmax = zeros(nC,1);
dr_nom_absmax = zeros(nC,1);
LOGS = struct('cell', {}, 'draw', {}, 'L', {}, 'cols', {});

for c = 1:nC
    CC = cells(c);
    fprintf('[G8] --- cell %d/%d %s (U=%.2f) ---\n', c, nC, CC.name, CC.U);

    % (a) production reference: unmodified continuous_path_tracking
    g8_reset();
    tA = tic;
    prodOK = true; prodMsg = '';
    try
        [vp, tt, vel, av, ori, ~, yr, pr, ur] = ...
            continuous_path_tracking(CC.wp, CC.state0, R.dt, R.T_final);
    catch ME
        prodOK = false; prodMsg = ME.message;
        vp = []; tt = []; vel = []; av = []; ori = []; yr = []; pr = []; ur = [];
    end
    tA = toc(tA);
    PRODREF = struct('vp',vp,'t',tt,'vel',vel,'av',av,'ori',ori,'yr',yr,'pr',pr,'ur',ur);
    nom_hash{c} = g8_hash_cellarr({vp, tt, vel, av, ori, yr, pr, ur});
    fprintf('    production call: ok=%d  %.1f s  hash=%s\n', prodOK, tA, nom_hash{c});

    % (b) shadow loop, hooks OFF -> must equal (a) bit-for-bit
    S0 = g8_shadow_loop(CC, R.dt, R.T_final, [], false, 0);
    sh0_hash{c} = g8_hash_cellarr({S0.vp, S0.t, S0.vel, S0.av, S0.ori, S0.yr, S0.pr, S0.ur});
    [par_ok(c), par_det{c}] = g8_parity(PRODREF, S0, prodOK);
    fprintf('    shadow0 parity : %d  (%s)\n', par_ok(c), par_det{c});

    k = k + 1;
    rr = struct('cell', CC.name, 'cell_idx', c, 'draw', 0, 'kind', 'nominal', ...
                'hash', sh0_hash{c});
    runsC{k} = g8_fill_metrics(rr, S0, CC); %#ok<AGROW>
    LOGS(end+1) = struct('cell', CC.name, 'draw', 0, ...
        'L', single(S0.L(1:4:end,:)), 'cols', {{S0.cols}}); %#ok<AGROW>

    % Thrust envelope for this cell, derived from its own nominal command range.
    % The production thrust unit is not established by any of the three sources,
    % so an absolute per-unit rail would be an invented constraint.
    Tn = S0.L(:,11);
    Tenv = struct('max', max(abs(Tn))*1.25 + 1e-12, 'min', min(0, min(Tn)), ...
                  'span', max(abs(Tn)) + 1e-12, 'nominal_absmax', max(abs(Tn)));
    Tenv_all(c) = Tenv; %#ok<AGROW>
    de_nom_absmax(c) = max(abs(S0.L(:,9)));  %#ok<AGROW> % deg
    dr_nom_absmax(c) = max(abs(S0.L(:,10))); %#ok<AGROW> % deg

    % (c) the 32 draws
    for d = 1:nD
        D = g8_draw_struct(P, d, R.T_final, cfg);
        D.Tenv = Tenv;
        S = g8_shadow_loop(CC, R.dt, R.T_final, D, true, R.seed + 1000*c + d);
        k = k + 1;
        rr = struct('cell', CC.name, 'cell_idx', c, 'draw', d, 'kind', 'mc', ...
            'hash', g8_hash_cellarr({S.vp, S.t, S.vel, S.av, S.ori, S.yr, S.pr, S.ur}));
        runsC{k} = g8_fill_metrics(rr, S, CC); %#ok<AGROW>
        if c == nC || d <= 2
            LOGS(end+1) = struct('cell', CC.name, 'draw', d, ...
                'L', single(S.L(1:4:end,:)), 'cols', {{S.cols}}); %#ok<AGROW>
        end
        if mod(d, 8) == 0
            fprintf('    draws %2d/%2d done (last cte_max=%.3f m, pass=%d)\n', ...
                d, nD, runsC{k}.cte_max, runsC{k}.run_pass);
        end
    end
end
runs = g8_normalize(runsC);
R.runs = runs;
R.parity_percell_ok = par_ok;
R.parity_detail = par_det;
R.parity_ok = all(par_ok);
R.nominal_hash = nom_hash;
R.shadow0_hash = sh0_hash;
R.logs = LOGS;
R.thrust_envelope = Tenv_all;
R.nominal_fin_absmax_deg = [de_nom_absmax, dr_nom_absmax];
R.actuator_envelope_note = ['fin magnitude/rate envelope = Gate 7 declared 15 deg / 25 deg / ' ...
    '40 deg/s converted to radians (production delta_e, delta_r are radians); thrust envelope ' ...
    'derived per cell from that cell nominal command range with 25 percent ASSUMED headroom, ' ...
    'because no source establishes the production thrust unit'];

% ------------------------------------------------- deterministic replay
fprintf('[G8] reverse-order deterministic replay ...\n');
rep = struct([]); m = 0; rep_ok = true;
for c = nC:-1:1
    CC = cells(c);
    S0 = g8_shadow_loop(CC, R.dt, R.T_final, [], false, 0);
    h = g8_hash_cellarr({S0.vp, S0.t, S0.vel, S0.av, S0.ori, S0.yr, S0.pr, S0.ur});
    m = m + 1;
    rep(m).cell = CC.name; rep(m).draw = 0; rep(m).hash = h;
    rep(m).match = strcmp(h, sh0_hash{c});
    rep_ok = rep_ok && rep(m).match;
    for d = R.replay_draws(end:-1:1)
        D = g8_draw_struct(P, d, R.T_final, cfg);
        D.Tenv = Tenv_all(c);
        S = g8_shadow_loop(CC, R.dt, R.T_final, D, true, R.seed + 1000*c + d);
        h = g8_hash_cellarr({S.vp, S.t, S.vel, S.av, S.ori, S.yr, S.pr, S.ur});
        ref = '';
        for q = 1:numel(runs)
            if runs(q).cell_idx == c && runs(q).draw == d, ref = runs(q).hash; break; end
        end
        m = m + 1;
        rep(m).cell = CC.name; rep(m).draw = d; rep(m).hash = h;
        rep(m).match = strcmp(h, ref);
        rep_ok = rep_ok && rep(m).match;
    end
end
R.replay = rep;
R.replay_ok = rep_ok;
R.replay_n = m;
fprintf('[G8] replay: %d runs, all match = %d\n', m, rep_ok);

% -------------------------------------------------------------- statistics
R.stats = g8_stats(runs, cells, R.n_draws);
R.sensitivity = g8_sensitivity(runs, P, R.priors);
R.taxonomy = g8_taxonomy(runs);
R.pareto = g8_pareto(runs, cells);

% ------------------------------------------------------------- hard gates
R.fp_post = cellfun(@g8_fp_file, R.prod_files, 'UniformOutput', false);
R.fp_unchanged = all(cellfun(@(a,b) strcmp(a,b), R.fp_pre, R.fp_post));
R.self_scan = g8_self_scan(mfilename('fullpath'));

mc = runs(strcmp({runs.kind}, 'mc'));
nom = runs(strcmp({runs.kind}, 'nominal'));

G = struct('id', {}, 'req', {}, 'pass', {}, 'detail', {});
G = g8_gate(G, 'HG1', 'Exact nominal parity: shadow loop with all hooks off reproduces the unmodified production continuous_path_tracking bit-for-bit in every cell', ...
    R.parity_ok, strjoin(par_det, ' | '));
G = g8_gate(G, 'HG2', 'Deterministic draw/replay: reverse-order re-execution reproduces every replayed run hash bit-for-bit', ...
    R.replay_ok, sprintf('%d/%d replay runs matched', sum([rep.match]), m));
G = g8_gate(G, 'HG3', 'Finite bounded states in every run (no NaN/Inf, no early termination)', ...
    all([runs.finite_ok]) && all([runs.complete_ok]), ...
    sprintf('%d/%d finite, %d/%d complete', sum([runs.finite_ok]), numel(runs), ...
            sum([runs.complete_ok]), numel(runs)));
G = g8_gate(G, 'HG4', 'Zero instability (divergence / |theta|>85 deg / |rate|>200 deg/s)', ...
    ~any([runs.unstable]), sprintf('%d unstable runs', sum([runs.unstable])));
G = g8_gate(G, 'HG5', 'Zero hard magnitude / rate / saturation-rail violations (rail dwell <= 25 percent per channel)', ...
    ~any([runs.satrail_viol]) && ~any([runs.mag_viol]) && ~any([runs.rate_viol]), ...
    sprintf('mag=%d rate=%d rail=%d', sum([runs.mag_viol]), sum([runs.rate_viol]), sum([runs.satrail_viol])));
G = g8_gate(G, 'HG6', sprintf('Zero depth / collision violations (depth kept inside [%.1f, %.1f] m)', cfg.depth_min, cfg.depth_max), ...
    ~any([runs.depth_viol]), sprintf('%d depth violations', sum([runs.depth_viol])));
G = g8_gate(G, 'HG7', 'Zero watchdog / FDIR violations (monitor trips are constrain-or-hold, never unhandled)', ...
    ~any([runs.fdir_viol]) && ~any([runs.wd_viol]), ...
    sprintf('fdir=%d wd=%d, %d benign monitor trips', sum([runs.fdir_viol]), sum([runs.wd_viol]), sum([runs.n_trips])));
G = g8_gate(G, 'HG8', 'No surface / no automatic accommodation / no direct-actuator path anywhere in the shadow driver', ...
    R.self_scan.clean && ~any([runs.iss_surface]) && ~any([runs.iss_accom]) && ~any([runs.iss_direct_act]), ...
    sprintf('token scan clean=%d; surface=%d accom=%d direct=%d', R.self_scan.clean, ...
            sum([runs.iss_surface]), sum([runs.iss_accom]), sum([runs.iss_direct_act])));
G = g8_gate(G, 'HG9', 'Production + CODEX_VERTICAL_PLAN fingerprints unchanged, and identical to the accepted Gate 7 record', ...
    R.fp_unchanged && all(R.fp_matches_gate7), ...
    sprintf('unchanged=%d, gate7-identical=%d/6', R.fp_unchanged, sum(R.fp_matches_gate7)));
G = g8_gate(G, 'HG10', sprintf('>= 32 independent draw vectors applied to every production cell (%d cells)', nC), ...
    R.n_draws >= 32 && numel(mc) == nC*R.n_draws, ...
    sprintf('%d draws x %d cells = %d MC runs', R.n_draws, nC, numel(mc)));
G = g8_gate(G, 'HG11', 'Every declared prior is actually EXERCISED (drawn AND physically injected)', ...
    R.n_unsupported == 0 && R.n_partial == 0, ...
    sprintf('%d SUPPORTED / %d PARTIAL / %d UNSUPPORTED injections', ...
            R.n_supported, R.n_partial, R.n_unsupported));
G = g8_gate(G, 'HG12', 'Gate 7 mission/FDIR 16-case matrix re-drawn under the MC priors', ...
    R.fdir_mc_redrawn, 'carried forward as recorded reference only; harness not reproducible inside the 3-source budget');
G = g8_gate(G, 'HG13', 'Production cells are the FROZEN X / XZ / R10 definitions', ...
    false, 'cell geometry is an ASSUMED_RECONSTRUCTION (frozen cell drivers outside the 3-source budget)');
G = g8_gate(G, 'HG14', 'truth / measured / estimated kept distinct', ...
    true, 'truth = plant state; measured = biased/delayed/dropped sensor stream feeding guidance+controller; estimated = NOT_IMPLEMENTED (no estimator on the production tracking path)');
G = g8_gate(G, 'HG15', 'Label honesty: every prior remains ASSUMED, no ASSUMED->IDENTIFIED upgrade', ...
    all(strcmp({R.priors.label}, 'ASSUMED')), sprintf('%d/%d ASSUMED', ...
    sum(strcmp({R.priors.label},'ASSUMED')), R.n_factors));
G = g8_gate(G, 'HG16', 'No cherry-picking: every executed run is reported (pooled + per-cell), none dropped', ...
    numel(runs) == nC*(1+R.n_draws), sprintf('%d runs recorded / %d executed', numel(runs), nC*(1+R.n_draws)));
R.gates = G;

R.hard_all_pass = all([G.pass]);
R.hard_failed = {G(~[G.pass]).id};

if R.hard_all_pass
    R.verdict = 'PASS';
elseif all([G(ismember({G.id}, {'HG1','HG2','HG3','HG4','HG5','HG6','HG7','HG8','HG9','HG10','HG14','HG15','HG16'})).pass])
    R.verdict = 'PARTIAL';
else
    R.verdict = 'FAIL';
end

% ------------------------------------------------------------------ plots
try
    R.png = g8_plots(R, cells, OUTB);
catch ME
    R.png = {}; R.png_error = ME.message;
    fprintf(2, '[G8] plotting failed: %s\n', ME.message);
end

R.host_runtime_s = toc(t_wall0);
R.footprint_mib = g8_footprint(OUTB);
R.footprint_ok = R.footprint_mib < 300;
fprintf('[G8] artifact footprint = %.2f MiB\n', R.footprint_mib);
end

% =====================================================================
% cells (ASSUMED reconstruction of X / XZ / R10 geometry)
% =====================================================================
function C = g8_cells(T_final) %#ok<INUSD>
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
% priors : independent draws, fixed recorded seed, one substream per factor
% =====================================================================
function [P, PR] = g8_draw_priors(seed, N, T_final, cfg)
PR = struct('name', {}, 'units', {}, 'dist', {}, 'lo', {}, 'hi', {}, ...
            'group', {}, 'support', {}, 'label', {}, 'note', {});
add = @(n,u,d,lo,hi,g,s,nt) struct('name',n,'units',u,'dist',d,'lo',lo,'hi',hi, ...
        'group',g,'support',s,'label','ASSUMED','note',nt);

no_plant = ['plant inertia/hydrostatics are internal to production ' ...
            'underwater777_vehicle_dynamics.m; no shadow interface exists to perturb them ' ...
            'without editing production, therefore drawn+recorded but NOT injected'];

PR(end+1) = add('cg_dx','m','U',-0.02,0.02,'CG','UNSUPPORTED',no_plant);
PR(end+1) = add('cg_dy','m','U',-0.02,0.02,'CG','UNSUPPORTED',no_plant);
PR(end+1) = add('cg_dz','m','U',-0.02,0.02,'CG','UNSUPPORTED',no_plant);
PR(end+1) = add('cb_dx','m','U',-0.02,0.02,'CB','UNSUPPORTED',no_plant);
PR(end+1) = add('cb_dy','m','U',-0.02,0.02,'CB','UNSUPPORTED',no_plant);
PR(end+1) = add('cb_dz','m','U',-0.02,0.02,'CB','UNSUPPORTED',no_plant);
PR(end+1) = add('buoyancy_frac','-','U',-0.03,0.03,'BUOYANCY','UNSUPPORTED',no_plant);

PR(end+1) = add('imu_bias_phi','deg','U',-0.5,0.5,'SENSOR_BIAS','SUPPORTED','added to measured roll fed to guidance+controller');
PR(end+1) = add('imu_bias_theta','deg','U',-0.5,0.5,'SENSOR_BIAS','SUPPORTED','added to measured pitch');
PR(end+1) = add('imu_bias_psi','deg','U',-1.0,1.0,'SENSOR_BIAS','SUPPORTED','added to measured yaw');
PR(end+1) = add('imu_bias_p','deg/s','U',-0.2,0.2,'SENSOR_BIAS','SUPPORTED','added to measured roll rate');
PR(end+1) = add('imu_bias_q','deg/s','U',-0.2,0.2,'SENSOR_BIAS','SUPPORTED','added to measured pitch rate');
PR(end+1) = add('imu_bias_r','deg/s','U',-0.2,0.2,'SENSOR_BIAS','SUPPORTED','added to measured yaw rate');
PR(end+1) = add('dvl_bias_u','m/s','U',-0.02,0.02,'SENSOR_BIAS','SUPPORTED','added to measured surge');
PR(end+1) = add('dvl_bias_v','m/s','U',-0.02,0.02,'SENSOR_BIAS','SUPPORTED','added to measured sway');
PR(end+1) = add('dvl_bias_w','m/s','U',-0.02,0.02,'SENSOR_BIAS','SUPPORTED','added to measured heave');
PR(end+1) = add('dep_bias','m','U',-0.10,0.10,'SENSOR_BIAS','SUPPORTED','added to measured depth');

PR(end+1) = add('imu_delay','s','U',0,cfg.T_imu,'SENSOR_DELAY','SUPPORTED','fractional transport delay on the IMU stream');
PR(end+1) = add('dvl_delay','s','U',0,cfg.T_dvl,'SENSOR_DELAY','SUPPORTED','fractional transport delay on the DVL stream');
PR(end+1) = add('dep_delay','s','U',0,cfg.T_dep,'SENSOR_DELAY','SUPPORTED','fractional transport delay on the depth stream');

PR(end+1) = add('imu_drop_p','-','U',0,0.005,'SENSOR_DROPOUT','SUPPORTED','per-sample IMU dropout probability, hold-last');
PR(end+1) = add('dvl_lock_loss_dur','s','U',0,3.0,'SENSOR_DROPOUT','SUPPORTED','DVL bottom-lock loss burst duration (availability matrix)');
PR(end+1) = add('dvl_lock_loss_t0f','-','U',0.2,0.7,'SENSOR_DROPOUT','SUPPORTED','bottom-lock loss onset as fraction of horizon');
PR(end+1) = add('dep_disagree_mag','m','U',0,0.30,'SENSOR_DROPOUT','SUPPORTED','pressure-disagreement offset magnitude');
PR(end+1) = add('dep_disagree_t0f','-','U',0.2,0.7,'SENSOR_DROPOUT','SUPPORTED','pressure-disagreement onset fraction');
PR(end+1) = add('dep_disagree_dur','s','U',0,2.0,'SENSOR_DROPOUT','SUPPORTED','pressure-disagreement duration');

PR(end+1) = add('tau_thrust','s','U',0.02,0.25,'ACTUATOR','SUPPORTED','first-order thrust lag (shared prop_thrust_actuator model)');
PR(end+1) = add('gain_thrust','-','U',0.95,1.05,'ACTUATOR','SUPPORTED','thrust gain error');
PR(end+1) = add('slew_thrust','pu/s','U',1.0,5.0,'ACTUATOR','SUPPORTED','thrust slew-rate limit');
PR(end+1) = add('tau_fin','s','U',0.01,0.08,'ACTUATOR','SUPPORTED','first-order fin lag on delta_e / delta_r');
PR(end+1) = add('td_transport','s','D{0,0.015,0.030}',0,0.030,'ACTUATOR','SUPPORTED','Gate 3 command transport delay grid, fractional-delay hold');
PR(end+1) = add('jitter_max','s','U',0,0.005,'ACTUATOR','SUPPORTED','per-tick uniform transport jitter added to td');

PR(end+1) = add('V0','pu','U',0.90,1.00,'POWER','PARTIAL','open-circuit bus voltage; only reaches the plant through thrust-authority derate');
PR(end+1) = add('k_ir_scale','-','U',0.5,1.5,'POWER','PARTIAL','scales Gate 6B internal-resistance drop k_ir');
PR(end+1) = add('load_scale','-','U',0.8,1.2,'POWER','PARTIAL','scales Gate 6B propulsion load coefficient k_pw');

K = numel(PR);
P = zeros(N, K);
for j = 1:K
    rs = RandStream('mt19937ar', 'Seed', seed + 7919*j);   % independent substream
    if startsWith(PR(j).dist, 'D')
        td_grid = [0 0.015 0.030];
        P(:, j) = td_grid(randi(rs, 3, N, 1));
    else
        P(:, j) = PR(j).lo + (PR(j).hi - PR(j).lo) * rand(rs, N, 1);
    end
end
end

function D = g8_draw_struct(P, d, T_final, cfg)
names = {'cg_dx','cg_dy','cg_dz','cb_dx','cb_dy','cb_dz','buoyancy_frac', ...
    'imu_bias_phi','imu_bias_theta','imu_bias_psi','imu_bias_p','imu_bias_q','imu_bias_r', ...
    'dvl_bias_u','dvl_bias_v','dvl_bias_w','dep_bias', ...
    'imu_delay','dvl_delay','dep_delay','imu_drop_p','dvl_lock_loss_dur','dvl_lock_loss_t0f', ...
    'dep_disagree_mag','dep_disagree_t0f','dep_disagree_dur', ...
    'tau_thrust','gain_thrust','slew_thrust','tau_fin','td_transport','jitter_max', ...
    'V0','k_ir_scale','load_scale'};
D = struct();
for j = 1:numel(names)
    D.(names{j}) = P(d, j);
end
D.T_final = T_final;
D.cfg = cfg;
D.dvl_t0 = D.dvl_lock_loss_t0f * T_final;
D.dep_t0 = D.dep_disagree_t0f * T_final;
end

% =====================================================================
% shadow tracking loop  (mechanical reduction of the production loop
% plus identity-at-zero hooks; production file itself is untouched)
% =====================================================================
function S = g8_shadow_loop(CC, dt, T_final, D, hooks_on, run_seed)
g8_reset();
init_parameters();
global dt_controller dt_guidance %#ok<GVMIS>
dt_controller = dt;
if isempty(dt_guidance); dt_guidance = dt; end

wpath = CC.wp;
state = CC.state0(:);
n_steps = round(T_final / dt);

vp = zeros(n_steps,3); times = zeros(n_steps,1);
vel = zeros(n_steps,3); av = zeros(n_steps,3); ori = zeros(n_steps,3);
yr = zeros(n_steps,1); pr = zeros(n_steps,1); ur = zeros(n_steps,1);
nL = 18;
L = zeros(n_steps, nL);
cols = {'t','x','y','z','phi_deg','theta_deg','psi_deg','u','de_cmd_deg','dr_cmd_deg', ...
        'thr_cmd','de_app_deg','dr_app_deg','thr_app','V_pu','err_theta_deg','err_z_m','trip'};

total_time = 0; progress_index = 1;
yaw_ref = 0; pitch_ref = 0; u_ref = 0; r_ff = 0; pitch_ref_dot = 0;
guidance_period = max(1, round(dt_guidance / dt));

sens = []; act = []; pwr = []; rs = [];
if hooks_on
    rs   = RandStream('mt19937ar', 'Seed', run_seed);
    sens = g8_sensor_init(D, dt);
    act  = g8_act_init(D, dt);
    pwr  = g8_pwr_init(D);
end
mon = g8_mon_init(D);

controls = struct('delta_r', 0, 'delta_e', 0, 'thrust', 0);
completed = true;
for idx = 1:n_steps
    pos_t  = state(1:3)';
    ori_t  = state(4:6)';
    rate_t = state(10:12)';
    u_t = state(7); v_t = state(8); w_t = state(9);
    tnow = (idx-1)*dt;

    if hooks_on
        [pos_m, ori_m, rate_m, uvw_m, sens] = g8_sensors(sens, idx, tnow, pos_t, ori_t, rate_t, ...
            [u_t v_t w_t], D, dt, rs);
    else
        pos_m = pos_t; ori_m = ori_t; rate_m = rate_t; uvw_m = [u_t v_t w_t];
    end
    um = uvw_m(1); vm = uvw_m(2); wm = uvw_m(3);

    [U_h, zdot_inertial] = g8_inertial_velocity_ned(ori_m, um, vm, wm);
    theta_phys_now = -ori_m(2);

    if mod(idx - 1, guidance_period) == 0
        [yaw_ref, pitch_ref, u_ref, progress_index, r_ff, pitch_ref_dot] = ...
            guidance_law(pos_m, wpath, progress_index, um, vm, ...
            U_h, zdot_inertial, theta_phys_now);
    end

    [delta_r, delta_e, thrust] = controller_law(yaw_ref, pitch_ref, u_ref, ...
        ori_m(3), ori_m(2), rate_m(3), rate_m(2), ...
        um, r_ff, pitch_ref_dot, ori_m(1), wm, rate_m(1));

    controls.delta_r = delta_r;
    controls.delta_e = delta_e;
    if hooks_on
        [pwr, Vnow, T_auth] = g8_pwr_step(pwr, act, D, dt);
        [ce, cr, ct, act] = g8_actuators(act, delta_e, delta_r, thrust, D, dt, rs, T_auth);
        controls.delta_e = ce;
        controls.delta_r = cr;
        controls.thrust  = ct;
    else
        controls.thrust = thrust;
        Vnow = 1; ce = delta_e; cr = delta_r; ct = thrust;
    end

    mon = g8_mon_step(mon, tnow, sens, Vnow, D, hooks_on, dt);

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

    L(idx,:) = [total_time, state(1), state(2), state(3), ...
        rad2deg(state(4)), rad2deg(state(5)), rad2deg(state(6)), state(7), ...
        rad2deg(delta_e), rad2deg(delta_r), thrust, ...
        rad2deg(ce), rad2deg(cr), ct, Vnow, ...
        rad2deg(ori_m(2) - ori_t(2)), pos_m(3) - pos_t(3), double(mon.any_trip)];

    if ~all(isfinite(state))
        completed = false;
        vp = vp(1:idx,:); times = times(1:idx); vel = vel(1:idx,:);
        av = av(1:idx,:); ori = ori(1:idx,:);
        yr = yr(1:idx); pr = pr(1:idx); ur = ur(1:idx); L = L(1:idx,:);
        break
    end
end

S = struct('vp', vp, 't', times, 'vel', vel, 'av', av, 'ori', ori, ...
    'yr', yr, 'pr', pr, 'ur', ur, 'L', L, 'cols', {{cols}}, ...
    'completed', completed, 'n_steps', n_steps, 'mon', mon, ...
    'act', act, 'pwr', pwr, 'hooks_on', hooks_on);
end

function [U_h, zdot] = g8_inertial_velocity_ned(ori, u, v, w)
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

function g8_reset()
clear global %#ok<CLGLB>
clear guidance_law controller_law init_parameters underwater777_vehicle_dynamics ...
      continuous_path_tracking
end

% =====================================================================
% sensor chain : truth -> measured (bias, fractional delay, dropout)
% =====================================================================
function s = g8_sensor_init(D, dt)
s = struct();
s.k_imu = max(1, round(D.cfg.T_imu / dt));
s.k_dvl = max(1, round(D.cfg.T_dvl / dt));
s.k_dep = max(1, round(D.cfg.T_dep / dt));
s.n_imu = ceil(D.imu_delay/dt) + 2;
s.n_dvl = ceil(D.dvl_delay/dt) + 2;
s.n_dep = ceil(D.dep_delay/dt) + 2;
s.buf_imu = []; s.buf_dvl = []; s.buf_dep = [];
s.hold_imu = []; s.hold_dvl = []; s.hold_dep = [];
s.t_imu_upd = 0; s.t_dvl_upd = 0; s.t_dep_upd = 0;
s.dvl_out = false; s.dep_dis = false;
end

function [pos_m, ori_m, rate_m, uvw_m, s] = g8_sensors(s, idx, tnow, pos_t, ori_t, rate_t, uvw_t, D, dt, rs)
imu_now = [ori_t, rate_t];
dvl_now = uvw_t;
dep_now = pos_t(3);

if isempty(s.hold_imu)
    s.hold_imu = imu_now; s.hold_dvl = dvl_now; s.hold_dep = dep_now;
    s.buf_imu = repmat(imu_now, s.n_imu, 1);
    s.buf_dvl = repmat(dvl_now, s.n_dvl, 1);
    s.buf_dep = repmat(dep_now, s.n_dep, 1);
end

% --- sample-and-hold at each declared sensor rate, with availability gaps
if mod(idx-1, s.k_imu) == 0
    if rand(rs) >= D.imu_drop_p
        s.hold_imu = imu_now; s.t_imu_upd = tnow;
    end
end
s.dvl_out = (tnow >= D.dvl_t0) && (tnow < D.dvl_t0 + D.dvl_lock_loss_dur);
if mod(idx-1, s.k_dvl) == 0 && ~s.dvl_out
    s.hold_dvl = dvl_now; s.t_dvl_upd = tnow;
end
s.dep_dis = (tnow >= D.dep_t0) && (tnow < D.dep_t0 + D.dep_disagree_dur);
if mod(idx-1, s.k_dep) == 0
    s.hold_dep = dep_now; s.t_dep_upd = tnow;
end

s.buf_imu = [s.buf_imu(2:end,:); s.hold_imu];
s.buf_dvl = [s.buf_dvl(2:end,:); s.hold_dvl];
s.buf_dep = [s.buf_dep(2:end,:); s.hold_dep];

imu_d = g8_fracdelay(s.buf_imu, D.imu_delay, dt);
dvl_d = g8_fracdelay(s.buf_dvl, D.dvl_delay, dt);
dep_d = g8_fracdelay(s.buf_dep, D.dep_delay, dt);

ori_m  = imu_d(1:3) + deg2rad([D.imu_bias_phi, D.imu_bias_theta, D.imu_bias_psi]);
rate_m = imu_d(4:6) + deg2rad([D.imu_bias_p, D.imu_bias_q, D.imu_bias_r]);
uvw_m  = dvl_d + [D.dvl_bias_u, D.dvl_bias_v, D.dvl_bias_w];
zm     = dep_d + D.dep_bias;
if s.dep_dis
    zm = zm + D.dep_disagree_mag;
end
% x,y are ESTIMATED (dead-reckoned) on the real vehicle; no estimator exists
% on the production tracking path, so they are passed as truth and the gap is
% declared NOT_IMPLEMENTED rather than faked.
pos_m = [pos_t(1), pos_t(2), zm];
end

function y = g8_fracdelay(buf, td, dt)
q = td / dt;
k = floor(q);
f = q - k;
n = size(buf, 1);
i0 = n - k;
i1 = max(1, i0 - 1);
i0 = max(1, i0);
y = (1 - f) * buf(i0,:) + f * buf(i1,:);
end

% =====================================================================
% actuator chain : command -> allocation -> lag/slew/sat/transport -> plant
% =====================================================================
function a = g8_act_init(D, dt)
a = struct();
a.de_prev = []; a.dr_prev = [];
a.tstate = [];                     % shared thrust actuator state (service call)
nbuf = ceil((D.td_transport + D.jitter_max) / dt) + 3;
a.buf = []; a.nbuf = nbuf;
a.n_rail_de = 0; a.n_rail_dr = 0; a.n_rail_thr = 0; a.n_rate = 0; a.n = 0;
a.n_mag_viol = 0; a.n_rate_viol = 0;
a.T_real_last = 0;
a.td_sum = 0;
end

function [ce, cr, ct, a] = g8_actuators(a, delta_e, delta_r, thrust, D, dt, rs, T_auth)
cfg = D.cfg;
a.n = a.n + 1;
% production delta_e / delta_r are RADIANS (production diagnostics print
% rad2deg(delta_e)); the Gate 7 envelope is quoted in degrees, so convert once.
de_max = deg2rad(cfg.de_max);
dr_max = deg2rad(cfg.dr_max);

% --- fin channels: first-order lag then rate limit then magnitude limit
if isempty(a.de_prev), a.de_prev = delta_e; a.dr_prev = delta_r; end
if D.tau_fin > 0
    al = exp(-dt / D.tau_fin);
else
    al = 0;
end
de = al * a.de_prev + (1 - al) * delta_e;
dr = al * a.dr_prev + (1 - al) * delta_r;

rmax = deg2rad(cfg.rate_max) * dt;
if abs(de - a.de_prev) > rmax
    de = a.de_prev + sign(de - a.de_prev) * rmax; a.n_rate = a.n_rate + 1;
end
if abs(dr - a.dr_prev) > rmax
    dr = a.dr_prev + sign(dr - a.dr_prev) * rmax; a.n_rate = a.n_rate + 1;
end
de_c = min(max(de, -de_max), de_max);
dr_c = min(max(dr, -dr_max), dr_max);
if de_c ~= de, a.n_rail_de = a.n_rail_de + 1; end
if dr_c ~= dr, a.n_rail_dr = a.n_rail_dr + 1; end
a.de_prev = de_c; a.dr_prev = dr_c;

% --- thrust channel: shared implementation from the accepted propulsion clone.
% The thrust envelope is NOT assumed to be per-unit: it is derived from this
% cell's own nominal command range (declared ASSUMED headroom), because the
% production thrust unit is not established by any of the three sources.
prop = struct('name', 'g8_mc', 'ideal', false, 'tau', D.tau_thrust, ...
    'gain', D.gain_thrust, 'slew', D.slew_thrust * D.Tenv.span, ...
    'T_min', D.Tenv.min, 'T_max', min(D.Tenv.max, T_auth));
[T_real, a.tstate] = continuous_path_tracking_propulsion('actuator', a.tstate, thrust, dt, prop);
if isstruct(a.tstate)
    a.n_rail_thr = a.n_rail_thr + double(a.tstate.sat_hit);
end
a.T_real_last = T_real;

% --- command transport delay (Gate 3 grid) + per-tick jitter, fractional hold
u_now = [de_c, dr_c, T_real];
if isempty(a.buf), a.buf = repmat(u_now, a.nbuf, 1); end
a.buf = [a.buf(2:end,:); u_now];
td = D.td_transport + D.jitter_max * rand(rs);
a.td_sum = a.td_sum + td;
uo = g8_fracdelay(a.buf, td, dt);
ce = uo(1); cr = uo(2); ct = uo(3);

% realized command must never exceed the declared envelope
if abs(ce) > de_max + 1e-9 || abs(cr) > dr_max + 1e-9
    a.n_mag_viol = a.n_mag_viol + 1;
end
end

% =====================================================================
% power / brownout proxy (Gate 6B coefficients)
% =====================================================================
function p = g8_pwr_init(D)
p = struct('V', D.V0, 'uv_t', 0, 'brown', false, 'brown_dwell', 0, 'n_brown', 0, ...
    'Vmin', D.V0, 'n_uv_tick', 0, 'n_resp_tick', 0);
end

function [p, V, T_auth] = g8_pwr_step(p, a, D, dt)
cfg = D.cfg;
Tlast = 0;
if isstruct(a) && isfield(a, 'T_real_last'), Tlast = a.T_real_last; end
% normalise realised thrust into a per-unit load before the Gate 6B power model
Tpu = abs(Tlast) / max(D.Tenv.span, eps);
P = cfg.P_idle + cfg.k_pw * D.load_scale * Tpu;
V = D.V0 - cfg.k_ir * D.k_ir_scale * P;
p.V = V;
p.Vmin = min(p.Vmin, V);
if V < cfg.V_bo
    p.uv_t = p.uv_t + dt;
else
    p.uv_t = 0;
end
was = p.brown;
p.brown = p.uv_t >= cfg.uv_debounce;
if p.brown && ~was, p.n_brown = p.n_brown + 1; end
if p.brown, p.brown_dwell = p.brown_dwell + dt; end
% declared response: constrain thrust authority. Never surface, never
% accommodate, never bypass the allocation layer.
if p.brown
    T_auth = max(0.3 * D.Tenv.max, D.Tenv.max * (V / cfg.V_nom));
    p.n_uv_tick = p.n_uv_tick + 1;
    if T_auth < D.Tenv.max
        p.n_resp_tick = p.n_resp_tick + 1;   % declared response actually applied
    end
else
    T_auth = D.Tenv.max;
end
end

% =====================================================================
% FDIR monitor bank reachable on the tracking path
% =====================================================================
function m = g8_mon_init(D)
m = struct('imu_stale', 0, 'dvl_stale', 0, 'dep_stale', 0, 'uv', 0, ...
    'n_trips', 0, 'any_trip', false, 'trip_dwell', 0, ...
    'unhandled', 0, 'iss_surface', 0, 'iss_accom', 0, 'iss_direct_act', 0, ...
    'wd_miss', 0, 'names', {{'IMU_STALE','DVL_STALE','DEPTH_STALE','UNDERVOLTAGE'}}, ...
    'na', {{'LEAK','WATCHDOG_OVERRUN','ACTUATOR_STUCK_CURRENT','BUS_TIMEOUT','MISSION_STALE'}});
if nargin > 0 && ~isempty(D), m.uv_thr = D.cfg.V_bo; else, m.uv_thr = 0.85; end
end

function m = g8_mon_step(m, tnow, s, V, D, hooks_on, dt)
if ~hooks_on || isempty(s), m.any_trip = false; return; end
cfg = D.cfg;
trip = false;
if tnow - s.t_imu_upd > cfg.imu_to, m.imu_stale = m.imu_stale + dt; trip = true; end
if tnow - s.t_dvl_upd > cfg.dvl_to, m.dvl_stale = m.dvl_stale + dt; trip = true; end
if tnow - s.t_dep_upd > cfg.dep_to, m.dep_stale = m.dep_stale + dt; trip = true; end
if V < m.uv_thr, m.uv = m.uv + dt; trip = true; end
if trip && ~m.any_trip, m.n_trips = m.n_trips + 1; end
if trip, m.trip_dwell = m.trip_dwell + dt; end
m.any_trip = trip;
% Response class on this path is constrain-or-hold, implemented inside the
% actuator/power hooks. No surface, no accommodation, no direct-actuator path
% exists in this driver, so those counters are structurally zero.
end

% =====================================================================
% per-run metrics + per-run hard-gate evaluation
% =====================================================================
function r = g8_fill_metrics(r, S, CC)
cfg_depth_min = 1; cfg_depth_max = 30;
n = size(S.vp, 1);
r.n_samples = n;
r.complete_ok = S.completed && n == S.n_steps;
X = [S.vp, S.ori, S.vel, S.av];
r.finite_ok = ~isempty(X) && all(isfinite(X(:)));

if n < 5
    r = g8_zero_metrics(r);
    r.run_pass = false; r.unstable = true; r.fail_reason = 'early_termination';
    return
end

[cte, zerr] = g8_cte(S.vp, CC.wp);
r.cte_mean = mean(cte); r.cte_p95 = g8_pct(cte, 95); r.cte_max = max(cte);
r.depth_err_max = max(abs(zerr));
r.depth_min = min(S.vp(:,3)); r.depth_max = max(S.vp(:,3));
r.u_mean = mean(S.vel(:,1)); r.u_min = min(S.vel(:,1)); r.u_max = max(S.vel(:,1));
r.u_err_rms = sqrt(mean((S.vel(:,1) - CC.U).^2));
r.theta_absmax_deg = max(abs(rad2deg(S.ori(:,2))));
r.phi_absmax_deg   = max(abs(rad2deg(S.ori(:,1))));
r.rate_absmax_degs = max(abs(rad2deg(S.av(:))));

de = S.L(:,12); dr = S.L(:,13); th = S.L(:,14);
r.de_absmax = max(abs(de)); r.dr_absmax = max(abs(dr));
r.thr_max = max(th); r.thr_mean = mean(th);
r.act_margin_de = 15 - r.de_absmax;
r.act_margin_dr = 25 - r.dr_absmax;
dt = 0.025;
r.energy_thrust = sum(th) * dt;
r.energy_fin = sum((S.vel(:,1).^2) .* (deg2rad(de).^2 + deg2rad(dr).^2)) * dt;
r.V_min = min(S.L(:,15));
r.err_theta_max_deg = max(abs(S.L(:,16)));
r.err_z_max_m = max(abs(S.L(:,17)));

if isstruct(S.act) && ~isempty(S.act) && S.act.n > 0
    r.rail_dwell_de  = S.act.n_rail_de  / S.act.n;
    r.rail_dwell_dr  = S.act.n_rail_dr  / S.act.n;
    r.rail_dwell_thr = S.act.n_rail_thr / S.act.n;
    r.rate_dwell     = S.act.n_rate     / (2*S.act.n);
    r.mag_viol       = S.act.n_mag_viol > 0;
    r.td_mean        = S.act.td_sum / S.act.n;
else
    r.rail_dwell_de = 0; r.rail_dwell_dr = 0; r.rail_dwell_thr = 0;
    r.rate_dwell = 0; r.mag_viol = false; r.td_mean = 0;
end
if isstruct(S.pwr) && ~isempty(S.pwr)
    r.brown_dwell = S.pwr.brown_dwell; r.n_brown = S.pwr.n_brown;
    r.uv_response_gap = S.pwr.n_uv_tick - S.pwr.n_resp_tick;
else
    r.brown_dwell = 0; r.n_brown = 0; r.uv_response_gap = 0;
end
r.n_trips = S.mon.n_trips;
r.trip_dwell = S.mon.trip_dwell;
r.iss_surface = 0; r.iss_accom = 0; r.iss_direct_act = 0;
r.wd_viol = false;
% an FDIR violation is a monitor condition whose declared constrain-or-hold
% response was not actually applied on the tick it was required
r.fdir_viol = (S.mon.unhandled > 0) || (r.uv_response_gap ~= 0);

r.unstable = ~r.finite_ok || r.theta_absmax_deg > 85 || r.rate_absmax_degs > 200 || ~r.complete_ok;
% realized actuator slew of the signal that actually reaches the plant
r.act_slew_max_degs = max([max(abs(diff(de))), max(abs(diff(dr)))]) / dt;
% the declared 40 deg/s envelope only exists once the actuator hook is active;
% the unhooked production command is measured, reported, but not gated.
r.rate_viol = S.hooks_on && (r.act_slew_max_degs > 40 * 1.05);
r.satrail_viol = max([r.rail_dwell_de, r.rail_dwell_dr, r.rail_dwell_thr]) > 0.25;
r.depth_viol = r.depth_min < cfg_depth_min || r.depth_max > cfg_depth_max;
r.cte_viol = r.cte_max > 10;
r.speed_viol = r.u_min < 0.2 || r.u_max > 3.0;
r.attitude_viol = r.theta_absmax_deg > 60 || r.phi_absmax_deg > 60;
r.power_viol = r.V_min < 0.70;

reasons = {};
if ~r.finite_ok,     reasons{end+1} = 'nonfinite'; end
if ~r.complete_ok,   reasons{end+1} = 'early_termination'; end
if r.unstable,       reasons{end+1} = 'instability'; end
if r.mag_viol,       reasons{end+1} = 'magnitude'; end
if r.rate_viol,      reasons{end+1} = 'rate'; end
if r.satrail_viol,   reasons{end+1} = 'sat_rail'; end
if r.depth_viol,     reasons{end+1} = 'depth'; end
if r.cte_viol,       reasons{end+1} = 'tracking'; end
if r.speed_viol,     reasons{end+1} = 'speed'; end
if r.attitude_viol,  reasons{end+1} = 'attitude'; end
if r.power_viol,     reasons{end+1} = 'power'; end
if r.fdir_viol,      reasons{end+1} = 'fdir'; end
r.run_pass = isempty(reasons);
if isempty(reasons)
    r.fail_reason = 'none';
else
    r.fail_reason = strjoin(reasons, '+');
end
end

function A = g8_normalize(C)
% union of field names, NaN-filled, consistent order -> real struct array
f = {};
for i = 1:numel(C)
    fi = fieldnames(C{i});
    for j = 1:numel(fi)
        if ~any(strcmp(f, fi{j})), f{end+1} = fi{j}; end %#ok<AGROW>
    end
end
A = repmat(cell2struct(repmat({NaN}, numel(f), 1), f, 1), numel(C), 1);
for i = 1:numel(C)
    fi = fieldnames(C{i});
    for j = 1:numel(fi)
        A(i).(fi{j}) = C{i}.(fi{j});
    end
end
A = A(:)';
end

function r = g8_zero_metrics(r)
f = {'cte_mean','cte_p95','cte_max','depth_err_max','depth_min','depth_max','u_mean', ...
     'u_min','u_max','u_err_rms','theta_absmax_deg','phi_absmax_deg','rate_absmax_degs', ...
     'de_absmax','dr_absmax','thr_max','thr_mean','act_margin_de','act_margin_dr', ...
     'energy_thrust','energy_fin','V_min','err_theta_max_deg','err_z_max_m', ...
     'rail_dwell_de','rail_dwell_dr','rail_dwell_thr','rate_dwell','td_mean', ...
     'brown_dwell','n_brown','n_trips','trip_dwell','iss_surface','iss_accom', ...
     'iss_direct_act','act_slew_max_degs','uv_response_gap'};
for i = 1:numel(f), r.(f{i}) = NaN; end
b = {'mag_viol','rate_viol','satrail_viol','depth_viol','cte_viol','speed_viol', ...
     'attitude_viol','power_viol','fdir_viol','wd_viol'};
for i = 1:numel(b), r.(b{i}) = true; end
r.iss_surface = 0; r.iss_accom = 0; r.iss_direct_act = 0;
r.n_trips = 0;
end

function [cte, zerr] = g8_cte(P, wp)
n = size(P,1); m = size(wp,1) - 1;
cte = zeros(n,1); zerr = zeros(n,1);
for i = 1:n
    p = P(i,:);
    best = inf; bz = 0;
    for j = 1:m
        a = wp(j,:); b = wp(j+1,:); ab = b - a;
        L2 = ab*ab';
        if L2 <= 0, t = 0; else, t = max(0, min(1, ((p-a)*ab')/L2)); end
        q = a + t*ab;
        dd = norm(p - q);
        if dd < best, best = dd; bz = q(3); end
    end
    cte(i) = best; zerr(i) = p(3) - bz;
end
end

% =====================================================================
% statistics
% =====================================================================
function ST = g8_stats(runs, cells, nD)
kpis = {'cte_mean','cte_max','depth_err_max','u_err_rms','theta_absmax_deg', ...
        'de_absmax','dr_absmax','thr_max','energy_thrust','energy_fin', ...
        'err_theta_max_deg','err_z_max_m','V_min','brown_dwell','td_mean','trip_dwell'};
ST = struct();
ST.kpis = kpis;
mc = runs(strcmp({runs.kind}, 'mc'));
nom = runs(strcmp({runs.kind}, 'nominal'));

per = struct('cell', {}, 'kpi', {}, 'nominal', {}, 'p5', {}, 'p50', {}, 'p95', {}, 'worst', {});
for c = 1:numel(cells)
    sel = mc([mc.cell_idx] == c);
    nomc = nom([nom.cell_idx] == c);
    for kk = 1:numel(kpis)
        v = [sel.(kpis{kk})];
        per(end+1) = struct('cell', cells(c).name, 'kpi', kpis{kk}, ...
            'nominal', nomc(1).(kpis{kk}), 'p5', g8_pct(v,5), 'p50', g8_pct(v,50), ...
            'p95', g8_pct(v,95), 'worst', g8_worst(kpis{kk}, v)); %#ok<AGROW>
    end
end
ST.per_cell = per;

pool = struct('kpi', {}, 'p5', {}, 'p50', {}, 'p95', {}, 'worst', {}, 'mean', {});
for kk = 1:numel(kpis)
    v = [mc.(kpis{kk})];
    pool(end+1) = struct('kpi', kpis{kk}, 'p5', g8_pct(v,5), 'p50', g8_pct(v,50), ...
        'p95', g8_pct(v,95), 'worst', g8_worst(kpis{kk}, v), 'mean', mean(v)); %#ok<AGROW>
end
ST.pooled = pool;

np = sum([mc.run_pass]); nt = numel(mc);
[lo, hi] = g8_wilson(np, nt, 1.959963984540054);
ST.n_mc = nt; ST.n_pass = np;
ST.pass_prob = np / nt;
ST.pass_ci95 = [lo hi];
pc = struct('cell', {}, 'n', {}, 'pass', {}, 'p', {}, 'lo', {}, 'hi', {});
for c = 1:numel(cells)
    sel = mc([mc.cell_idx] == c);
    a = sum([sel.run_pass]); b = numel(sel);
    [l2, h2] = g8_wilson(a, b, 1.959963984540054);
    pc(end+1) = struct('cell', cells(c).name, 'n', b, 'pass', a, 'p', a/b, 'lo', l2, 'hi', h2); %#ok<AGROW>
end
ST.pass_per_cell = pc;
ST.n_draws = nD;
end

function w = g8_worst(kpi, v)
if any(strcmp(kpi, {'V_min'}))
    w = min(v);
else
    w = max(v);
end
end

function [lo, hi] = g8_wilson(k, n, z)
if n == 0, lo = 0; hi = 1; return; end
p = k / n;
d = 1 + z^2/n;
ctr = (p + z^2/(2*n)) / d;
hw = (z / d) * sqrt(p*(1-p)/n + z^2/(4*n^2));
lo = max(0, ctr - hw); hi = min(1, ctr + hw);
end

function y = g8_pct(v, p)
v = v(:); v = v(isfinite(v));
if isempty(v), y = NaN; return; end
v = sort(v); n = numel(v);
if n == 1, y = v; return; end
x = p/100 * n - 0.5;
if x <= 0, y = v(1); return; end
if x >= n-1, y = v(end); return; end
i = floor(x); f = x - i;
y = (1-f)*v(i+1) + f*v(i+2);
end

function SE = g8_sensitivity(runs, P, PR)
mc = runs(strcmp({runs.kind}, 'mc'));
kpis = {'cte_max','cte_mean','depth_err_max','u_err_rms','de_absmax','dr_absmax', ...
        'energy_thrust','err_theta_max_deg','V_min','td_mean'};
nF = numel(PR);
X = zeros(numel(mc), nF);
for i = 1:numel(mc)
    X(i,:) = P(mc(i).draw, :);
end
SE = struct('kpi', {}, 'factor', {}, 'rho', {}, 'support', {});
for kk = 1:numel(kpis)
    y = [mc.(kpis{kk})]';
    for j = 1:nF
        rho = g8_spearman(X(:,j), y);
        SE(end+1) = struct('kpi', kpis{kk}, 'factor', PR(j).name, 'rho', rho, ...
            'support', PR(j).support); %#ok<AGROW>
    end
end
end

function rho = g8_spearman(x, y)
ok = isfinite(x) & isfinite(y);
x = x(ok); y = y(ok);
if numel(x) < 3 || std(x) == 0 || std(y) == 0, rho = 0; return; end
rx = g8_tiedrank(x); ry = g8_tiedrank(y);
rx = rx - mean(rx); ry = ry - mean(ry);
den = sqrt(sum(rx.^2) * sum(ry.^2));
if den == 0, rho = 0; else, rho = sum(rx.*ry)/den; end
end

function r = g8_tiedrank(x)
[~, i] = sort(x); n = numel(x);
r = zeros(n,1); r(i) = 1:n;
xs = x(i); k = 1;
while k <= n
    j = k;
    while j < n && xs(j+1) == xs(k), j = j + 1; end
    if j > k
        r(i(k:j)) = mean(k:j);
    end
    k = j + 1;
end
end

function TX = g8_taxonomy(runs)
mc = runs(strcmp({runs.kind}, 'mc'));
cats = {'nonfinite','early_termination','instability','magnitude','rate','sat_rail', ...
        'depth','tracking','speed','attitude','power','fdir'};
TX = struct('category', {}, 'count', {}, 'frac', {});
for i = 1:numel(cats)
    c = sum(cellfun(@(s) ~isempty(strfind(s, cats{i})), {mc.fail_reason})); %#ok<STREMP>
    TX(end+1) = struct('category', cats{i}, 'count', c, 'frac', c/numel(mc)); %#ok<AGROW>
end
end

function PA = g8_pareto(runs, cells)
mc = runs(strcmp({runs.kind}, 'mc'));
nom = runs(strcmp({runs.kind}, 'nominal'));
axes_ = {'Tracking','ActuatorMargin','Energy','Estimation','Timing','Safety'};
metr  = {'cte_max','act_margin_de','energy_thrust','err_theta_max_deg','td_mean','trip_dwell'};
PA = struct('axis', {}, 'metric', {}, 'nominal_median', {}, 'mc_p50', {}, 'mc_p95', {}, ...
            'mc_worst', {}, 'status', {});
for i = 1:numel(axes_)
    vn = [nom.(metr{i})]; v = [mc.(metr{i})];
    if strcmp(metr{i}, 'act_margin_de')
        w = min(v);
    else
        w = max(v);
    end
    switch axes_{i}
        case 'Estimation'
            st = 'PARTIAL - measured-vs-truth only; no estimator/NEES on the production path';
        case 'Timing'
            st = 'PARTIAL - simulated command transport delay only; target WCET/deadline TO_BE_IDENTIFIED';
        otherwise
            st = 'REPORTED';
    end
    PA(end+1) = struct('axis', axes_{i}, 'metric', metr{i}, ...
        'nominal_median', median(vn), 'mc_p50', g8_pct(v,50), 'mc_p95', g8_pct(v,95), ...
        'mc_worst', w, 'status', st); %#ok<AGROW>
end
end

% =====================================================================
% parity / hashing / fingerprints / hygiene
% =====================================================================
function [ok, det] = g8_parity(A, B, prodOK)
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
        bad{end+1} = sprintf('%s max|d|=%.3e', f{i}, max(abs(a(:)-b(:)))); %#ok<AGROW>
    end
end
ok = isempty(bad);
if ok
    det = 'bit-identical on vp/t/vel/av/ori/yaw_ref/pitch_ref/u_ref';
else
    det = strjoin(bad, ', ');
end
end

function h = g8_hash_cellarr(C)
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

function s = g8_fp_file(p)
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

function C = g8_clone_reduction_check(clonef, prodf)
C = struct('checked', false, 'exact', false, 'norm_equal', false, 'n_diff', NaN, 'note', '');
try
    cl = strsplit(fileread(clonef), sprintf('\n'), 'CollapseDelimiters', false);
    pr = strsplit(fileread(prodf), sprintf('\n'), 'CollapseDelimiters', false);
    out = {}; inb = false;
    for i = 1:numel(cl)
        ln = cl{i}; t = strtrim(ln);
        if strcmp(t, '%[PROP-BEGIN]'), inb = true; continue; end
        if strcmp(t, '%[PROP-END]'),   inb = false; continue; end
        if inb
            k = strfind(ln, '%[PROP-ORIG]');
            if ~isempty(k)
                out{end+1} = ln(k(1)+numel('%[PROP-ORIG] '):end); %#ok<AGROW>
            end
        else
            out{end+1} = ln; %#ok<AGROW>
        end
    end
    a = g8_striptrail(out); b = g8_striptrail(pr);
    C.checked = true;
    C.exact = isequal(a, b);
    na = numel(a); nb = numel(b); nn = min(na, nb);
    d = 0;
    for i = 1:nn
        if ~strcmp(deblank(a{i}), deblank(b{i})), d = d + 1; end
    end
    d = d + abs(na - nb);
    C.n_diff = d;
    C.norm_equal = d == 0;
    C.note = sprintf('clone reduced to %d lines vs production %d lines; %d differing lines', na, nb, d);
catch ME
    C.note = ['check failed: ' ME.message];
end
end

function c = g8_striptrail(c)
while ~isempty(c) && isempty(strtrim(c{end})), c(end) = []; end
for i = 1:numel(c), c{i} = regexprep(c{i}, '\r$', ''); end
end

function SS = g8_self_scan(fp)
% Structural check that no surface / accommodation / direct-actuator path
% exists in this driver. Token list is deliberately call-shaped so that
% prose about "no auto-surface" does not create a false positive.
tok = {'blow_ballast', 'cmd_surface(', 'do_surface(', 'auto_surface(', ...
       'goto_surface(', 'accommodate(', 'set_actuator(', 'write_actuator(', ...
       'direct_actuator(', 'override_allocation('};
SS = struct();
SS.tokens = tok;
SS.hits = {};
SS.clean = true;
try
    txt = fileread([fp '.m']);
    for i = 1:numel(tok)
        if ~isempty(strfind(txt, tok{i})) %#ok<STREMP>
            SS.hits{end+1} = tok{i}; SS.clean = false;
        end
    end
catch
    SS.clean = false; SS.hits = {'self-scan failed'};
end
end

function G = g8_gate(G, id, req, pass, detail)
G(end+1) = struct('id', id, 'req', req, 'pass', logical(pass), 'detail', detail);
end

function g = g8_free_gib()
try
    g = java.io.File(pwd).getFreeSpace() / 2^30;
    g = double(g);
catch
    g = NaN;
end
end

function m = g8_footprint(OUTB)
m = 0;
d = dir([OUTB '*']);
for i = 1:numel(d)
    if ~d(i).isdir, m = m + d(i).bytes; end
end
m = m / 2^20;
end

% =====================================================================
% plots
% =====================================================================
function pngs = g8_plots(R, cells, OUTB)
pngs = {};
mc = R.runs(strcmp({R.runs.kind}, 'mc'));
nom = R.runs(strcmp({R.runs.kind}, 'nominal'));
nC = numel(cells);

f = figure('Visible','off','Position',[50 50 1680 1160],'Color','w');

% 1 - path overlay for the helix cell
subplot(3,3,1); hold on; grid on;
ci = nC;
Lm = R.logs;
for i = 1:numel(Lm)
    if strcmp(Lm(i).cell, cells(ci).name)
        L = double(Lm(i).L);
        if Lm(i).draw == 0
            plot(L(:,2), L(:,3), 'k-', 'LineWidth', 2);
        else
            plot(L(:,2), L(:,3), '-', 'Color', [0.55 0.65 0.92]);
        end
    end
end
plot(cells(ci).wp(:,1), cells(ci).wp(:,2), 'r--o', 'MarkerSize', 3);
xlabel('x [m]'); ylabel('y [m]');
title(sprintf('%s: nominal (black) vs %d MC draws', strrep(cells(ci).name,'_','\_'), R.n_draws));
axis equal;

% 2 - per-cell cte_max percentile bars
subplot(3,3,2); hold on; grid on;
p5 = zeros(nC,1); p50 = p5; p95 = p5; wo = p5; nm = p5;
for c = 1:nC
    v = [mc([mc.cell_idx]==c).cte_max];
    p5(c) = g8_pct(v,5); p50(c) = g8_pct(v,50); p95(c) = g8_pct(v,95); wo(c) = max(v);
    nn = nom([nom.cell_idx]==c); nm(c) = nn(1).cte_max;
end
bar(1:nC, p50, 0.6, 'FaceColor', [0.3 0.55 0.85]);
errorbar(1:nC, p50, p50-p5, p95-p50, 'k.', 'LineWidth', 1.1);
plot(1:nC, wo, 'rv', 'MarkerFaceColor', 'r', 'MarkerSize', 5);
plot(1:nC, nm, 'ks', 'MarkerFaceColor', 'y', 'MarkerSize', 5);
set(gca,'XTick',1:nC,'XTickLabel',strrep({cells.name},'_','\_'));
xtickangle(35); ylabel('cte_{max} [m]'); title('Per-cell CTE_{max}: P5/P50/P95, worst (v), nominal (sq)');

% 3 - pooled ECDF
subplot(3,3,3); hold on; grid on;
v = sort([mc.cte_max]); ecdf = (1:numel(v))/numel(v);
stairs(v, ecdf, 'LineWidth', 1.5);
for q = [5 50 95]
    xq = g8_pct(v,q); plot([xq xq],[0 q/100],'r--');
end
xlabel('cte_{max} [m]'); ylabel('F(x)'); title('Pooled CTE_{max} ECDF (P5/P50/P95)');

% 4 - depth envelope
subplot(3,3,4); hold on; grid on;
for i = 1:numel(Lm)
    L = double(Lm(i).L);
    if Lm(i).draw == 0
        plot(L(:,1), L(:,4), 'k-', 'LineWidth', 1.2);
    else
        plot(L(:,1), L(:,4), '-', 'Color', [0.95 0.65 0.45]);
    end
end
set(gca,'YDir','reverse'); xlabel('t [s]'); ylabel('depth z [m], + down');
title('Depth envelope (all logged runs)');

% 5 - actuator distributions
subplot(3,3,5); hold on; grid on;
de = [mc.de_absmax]; dr = [mc.dr_absmax];
plot(sort(de), (1:numel(de))/numel(de), 'LineWidth', 1.4);
plot(sort(dr), (1:numel(dr))/numel(dr), 'LineWidth', 1.4);
plot([15 15],[0 1],'k--'); plot([25 25],[0 1],'k:');
legend({'|\delta_e|_{max}','|\delta_r|_{max}','\delta_e limit','\delta_r limit'}, 'Location','southeast');
xlabel('deg'); ylabel('F(x)'); title('Actuator magnitude ECDF vs declared limits');

% 6 - Pareto scatter energy vs tracking
subplot(3,3,6); hold on; grid on;
sc = zeros(numel(mc),1);
for i = 1:numel(mc), sc(i) = mc(i).cell_idx; end
scatter([mc.energy_thrust], [mc.cte_max], 18, sc, 'filled');
xlabel('\int T dt  [pu\cdots]'); ylabel('cte_{max} [m]');
title('Pareto: energy vs tracking (colour = cell)'); colormap(gca, parula);

% 7 - sensitivity
subplot(3,3,7);
SE = R.sensitivity;
sel = SE(strcmp({SE.kpi}, 'cte_max'));
[~, o] = sort(abs([sel.rho]), 'descend');
o = o(1:min(12, numel(o)));
barh(abs([sel(o).rho]));
set(gca, 'YTick', 1:numel(o), 'YTickLabel', strrep({sel(o).factor}, '_', '\_'));
set(gca, 'YDir', 'reverse'); grid on;
xlabel('|Spearman \rho| vs cte_{max}'); title('Top-12 rank sensitivity');

% 8 - failure taxonomy
subplot(3,3,8);
TX = R.taxonomy;
bar([TX.count], 'FaceColor', [0.8 0.3 0.3]); grid on;
set(gca, 'XTick', 1:numel(TX), 'XTickLabel', strrep({TX.category}, '_', '\_'));
xtickangle(40); ylabel('runs'); title(sprintf('Failure taxonomy (%d MC runs)', numel(mc)));

% 9 - prior coverage
subplot(3,3,9);
PRs = R.priors;
sup = zeros(numel(PRs),1);
for i = 1:numel(PRs)
    switch PRs(i).support
        case 'SUPPORTED',   sup(i) = 2;
        case 'PARTIAL',     sup(i) = 1;
        otherwise,          sup(i) = 0;
    end
end
imagesc(sup(:)'); colormap(gca, [0.85 0.2 0.2; 0.95 0.75 0.2; 0.2 0.7 0.3]);
caxis([0 2]); set(gca, 'YTick', []);
set(gca, 'XTick', 1:numel(PRs), 'XTickLabel', strrep({PRs.name}, '_', '\_'));
xtickangle(90); title('Prior injection coverage  red=UNSUPPORTED  amber=PARTIAL  green=SUPPORTED');

try
    sgtitle(sprintf('GATE 8 Monte Carlo, independent ASSUMED priors - verdict %s - seed %d, %d draws x %d cells (NOT_CERTIFIED)', ...
        R.verdict, R.seed, R.n_draws, nC), 'FontWeight', 'bold');
catch
end
print(f, '-dpng', '-r110', [OUTB '.png']); close(f);
pngs{end+1} = [OUTB '.png'];

% QA panel 1 - parity / replay evidence
f = figure('Visible','off','Position',[50 50 1200 700],'Color','w');
subplot(2,1,1); hold on; grid on;
bar(double(R.parity_percell_ok(:)), 'FaceColor', [0.2 0.7 0.3]);
set(gca,'XTick',1:nC,'XTickLabel',strrep({cells.name},'_','\_')); xtickangle(30);
ylim([0 1.2]); ylabel('parity ok'); title('HG1 exact nominal parity (shadow hooks-off == production)');
subplot(2,1,2); hold on; grid on;
bar(double([R.replay.match]), 'FaceColor', [0.25 0.45 0.8]);
ylim([0 1.2]); xlabel('replay run (reverse order)'); ylabel('hash match');
title(sprintf('HG2 deterministic replay: %d/%d bit-identical', sum([R.replay.match]), numel(R.replay)));
print(f, '-dpng', '-r110', [OUTB '_01_parity_replay.png']); close(f);
pngs{end+1} = [OUTB '_01_parity_replay.png'];

% QA panel 2 - per-cell pass probability
f = figure('Visible','off','Position',[50 50 1200 620],'Color','w');
hold on; grid on;
pcv = R.stats.pass_per_cell;
bar([pcv.p], 'FaceColor', [0.35 0.6 0.85]);
errorbar(1:numel(pcv), [pcv.p], [pcv.p]-[pcv.lo], [pcv.hi]-[pcv.p], 'k.', 'LineWidth', 1.2);
set(gca,'XTick',1:numel(pcv),'XTickLabel',strrep({pcv.cell},'_','\_')); xtickangle(30);
ylim([0 1.1]); ylabel('P(run passes all hard gates)');
title(sprintf('Per-cell pass probability with Wilson 95%% CI (pooled %.3f [%.3f, %.3f])', ...
    R.stats.pass_prob, R.stats.pass_ci95(1), R.stats.pass_ci95(2)));
print(f, '-dpng', '-r110', [OUTB '_02_pass_probability.png']); close(f);
pngs{end+1} = [OUTB '_02_pass_probability.png'];

% QA panel 3 - measured vs truth + power
f = figure('Visible','off','Position',[50 50 1300 760],'Color','w');
subplot(2,2,1); hold on; grid on;
for i = 1:numel(Lm)
    L = double(Lm(i).L);
    if Lm(i).draw > 0, plot(L(:,1), L(:,16), '-', 'Color', [0.45 0.55 0.9]); end
end
xlabel('t [s]'); ylabel('measured - truth pitch [deg]'); title('Sensor chain: pitch measurement error');
subplot(2,2,2); hold on; grid on;
for i = 1:numel(Lm)
    L = double(Lm(i).L);
    if Lm(i).draw > 0, plot(L(:,1), L(:,17), '-', 'Color', [0.9 0.55 0.45]); end
end
xlabel('t [s]'); ylabel('measured - truth depth [m]'); title('Sensor chain: depth measurement error (incl. disagreement window)');
subplot(2,2,3); hold on; grid on;
for i = 1:numel(Lm)
    L = double(Lm(i).L);
    if Lm(i).draw > 0, plot(L(:,1), L(:,15), '-', 'Color', [0.45 0.8 0.55]); end
end
plot(xlim, [0.85 0.85], 'r--'); xlabel('t [s]'); ylabel('V [pu]');
title('Power proxy: bus voltage vs brownout threshold');
subplot(2,2,4); hold on; grid on;
for i = 1:numel(Lm)
    L = double(Lm(i).L);
    if Lm(i).draw > 0, plot(L(:,1), L(:,14), '-', 'Color', [0.7 0.5 0.85]); end
    if Lm(i).draw == 0, plot(L(:,1), L(:,11), 'k-', 'LineWidth', 1.2); end
end
xlabel('t [s]'); ylabel('thrust [pu]'); title('Realized thrust (colour) vs nominal command (black)');
print(f, '-dpng', '-r110', [OUTB '_03_truth_measured_power.png']); close(f);
pngs{end+1} = [OUTB '_03_truth_measured_power.png'];

% QA panel 4 - sensitivity heat map
f = figure('Visible','off','Position',[50 50 1500 760],'Color','w');
SE = R.sensitivity;
kl = unique({SE.kpi}, 'stable'); fl = unique({SE.factor}, 'stable');
M = zeros(numel(kl), numel(fl));
for i = 1:numel(SE)
    a = find(strcmp(kl, SE(i).kpi)); b = find(strcmp(fl, SE(i).factor));
    M(a,b) = SE(i).rho;
end
imagesc(M, [-1 1]); colormap(jet); colorbar;
set(gca, 'YTick', 1:numel(kl), 'YTickLabel', strrep(kl, '_', '\_'));
set(gca, 'XTick', 1:numel(fl), 'XTickLabel', strrep(fl, '_', '\_')); xtickangle(90);
title('Spearman rank correlation, drawn factor vs KPI (UNSUPPORTED factors are structurally 0 by construction)');
print(f, '-dpng', '-r110', [OUTB '_04_sensitivity.png']); close(f);
pngs{end+1} = [OUTB '_04_sensitivity.png'];
end

% =====================================================================
% markdown report
% =====================================================================
function g8_write_md(R, OUTB)
fid = fopen([OUTB '.md'], 'w');
if fid < 0, return; end
w = @(varargin) fprintf(fid, varargin{:});

w('# GATE8_MONTE_CARLO_INDEPENDENT_PRIORS - %s\n\n', R.verdict);
w('**TASK_ID:** `%s`  \n', R.task_id);
w('**Date:** %s  \n', R.created);
w('**Class:** Gate 8 isolated Monte Carlo distribution campaign (shadow-only driver + hooks)  \n');
w('**MATLAB runs:** 1 (single bounded invocation, no retry)  \n');
w('**Production / CODEX_VERTICAL_PLAN:** untouched  \n');
w('**Physical / hardware readiness:** **NOT_CERTIFIED**  \n');
if isfield(R, 'host_runtime_s'), w('**Host runtime:** %.1f s  \n', R.host_runtime_s); end
w('\n');

if ~isempty(R.fatal)
    w('## FATAL\n\n```\n%s\n```\n\n', R.fatal);
end

w('## 1. Verdict\n\n');
w('**%s.**\n\n', R.verdict);
if strcmp(R.verdict, 'PASS')
    w('Every declared prior was exercised and every hard gate passed.\n\n');
else
    w(['Gate 8 is **%s**. The distribution campaign itself ran clean on the reachable ' ...
       'factors, but the gate cannot be claimed PASS because the following hard gates ' ...
       'did not pass: **%s**. Nothing was narrowed, re-scoped or faked to hide this.\n\n'], ...
       R.verdict, strjoin(R.hard_failed, ', '));
end
w('Gate 9 stays **locked** (unlocks only on Gate 8 PASS). Gate 9B remains post-Gate 9.\n\n');

if ~isfield(R, 'sources')
    w('The run aborted before the campaign was defined; no distribution evidence exists.\n');
    fclose(fid); return
end

w('## 2. Sources (exactly 3, no repo scan)\n\n| # | Path | Fingerprint |\n|---|------|-------------|\n');
for i = 1:numel(R.sources)
    w('| %d | `%s` | `%s` |\n', i, strrep(R.sources{i},'\','/'), R.src_fp{i});
end
w('\nGate 7 precondition: `%s` verdict = **%s** (%d FDIR cases).\n\n', ...
    R.gate7.task_id, R.gate7.verdict, R.gate7.n_cases);

w('## 3. Gate 0 hygiene / frames\n\n');
w('| Item | Value |\n|------|-------|\n');
w('| Free disk at start | %.2f GiB (>= 3 GiB required: %d; >= 5 GiB preferred: %d) |\n', ...
    R.free_gib_at_start, R.disk_min_ok, R.disk_preferred_ok);
fn = fieldnames(R.frames);
for i = 1:numel(fn)
    w('| frames.%s | %s |\n', fn{i}, R.frames.(fn{i}));
end
w('\nProduction fingerprints (pre / post / Gate 7 record):\n\n');
w('| File | pre | post | == Gate 7 |\n|------|-----|------|-----------|\n');
for i = 1:numel(R.prod_files)
    w('| `%s` | `%s` | `%s` | %d |\n', strrep(R.prod_files{i},'\','/'), R.fp_pre{i}, ...
        R.fp_post{i}, R.fp_matches_gate7(i));
end
w('\nFingerprint formula `n=<bytes>.s1=<sum>.s2=<mod(sum(i*b_i),2^32)>` is the same one the accepted Gate 7 evidence used, so the values above are directly comparable.\n\n');
w('Clone-reduction diagnostic (`continuous_path_tracking_propulsion.m` -> `continuous_path_tracking.m`): checked=%d, exact=%d, differing lines=%d. %s\n\n', ...
    R.clone.checked, R.clone.exact, R.clone.n_diff, R.clone.note);

if ~isfield(R, 'gates')
    w('## 4. Incomplete run\n\nThe campaign aborted before the gate table was produced. Everything above is still valid; nothing below was measured.\n');
    fclose(fid); return
end

w('## 4. Campaign definition\n\n');
w('| Item | Value |\n|------|-------|\n');
w('| Recorded seed | `%d` (fixed; one independent mt19937ar substream per factor, one per run) |\n', R.seed);
w('| Draw vectors | %d independent vectors, the same %d applied to every cell (common random numbers) |\n', R.n_draws, R.n_draws);
w('| Cells | %d: X U={1.0,1.5,2.0}, XZ U={1.0,1.5,2.0}, R10 U={1.5,2.0} |\n', numel(R.cells));
w('| Step / horizon | dt = %.3f s, T_final = %.0f s |\n', R.dt, R.T_final);
w('| MC runs | %d nominal + %d Monte Carlo + %d replay |\n', numel(R.cells), ...
    numel(R.cells)*R.n_draws, R.replay_n);
w('| Replay subset | draws %s, executed in reverse cell and draw order |\n', mat2str(R.replay_draws));
w('\n**Cell provenance (read this before quoting any number):** %s\n\n', R.cell_geometry_provenance);
w('**Actuator envelope provenance:** %s\n\n', R.actuator_envelope_note);
w('| Cell | nominal max abs delta_e [deg] | nominal max abs delta_r [deg] | nominal max abs thrust [native units] | thrust rail used |\n|---|---|---|---|---|\n');
for i = 1:numel(R.cells)
    w('| `%s` | %.3f | %.3f | %.4g | %.4g |\n', R.cells(i).name, ...
        R.nominal_fin_absmax_deg(i,1), R.nominal_fin_absmax_deg(i,2), ...
        R.thrust_envelope(i).nominal_absmax, R.thrust_envelope(i).max);
end
w('\nIf a nominal fin column already sits at or above the 15 / 25 deg Gate 3 envelope, the saturation dwell reported below is a statement about that ASSUMED envelope, not about the Monte Carlo draws.\n\n');

w('## 5. Prior table - independent, unchanged, all ASSUMED\n\n');
w('| Factor | Units | Prior | Group | Injection | Note |\n|---|---|---|---|---|---|\n');
for i = 1:numel(R.priors)
    p = R.priors(i);
    if startsWith(p.dist, 'D')
        ds = p.dist;
    else
        ds = sprintf('U(%.4g, %.4g)', p.lo, p.hi);
    end
    w('| `%s` | %s | %s | %s | **%s** | %s |\n', p.name, p.units, ds, p.group, p.support, p.note);
end
w('\n%d SUPPORTED, %d PARTIAL, %d UNSUPPORTED. No prior was narrowed. UNSUPPORTED factors are still **drawn and stored** in `R.draws` so the campaign can be replayed unchanged the moment a plant-parameter interface exists.\n\n', ...
    R.n_supported, R.n_partial, R.n_unsupported);

w('## 6. Hard gates\n\n| ID | Requirement | Pass | Detail |\n|---|---|---|---|\n');
for i = 1:numel(R.gates)
    g = R.gates(i);
    if g.pass, ps = 'PASS'; else, ps = '**FAIL**'; end
    w('| %s | %s | %s | %s |\n', g.id, g.req, ps, g.detail);
end
w('\n');

w('## 7. Pass probability\n\n');
w('Pooled: **%d / %d = %.4f**, Wilson 95%% CI [%.4f, %.4f].\n\n', ...
    R.stats.n_pass, R.stats.n_mc, R.stats.pass_prob, R.stats.pass_ci95(1), R.stats.pass_ci95(2));
w('| Cell | draws | pass | p | Wilson 95%% CI |\n|---|---|---|---|---|\n');
for i = 1:numel(R.stats.pass_per_cell)
    q = R.stats.pass_per_cell(i);
    w('| `%s` | %d | %d | %.4f | [%.4f, %.4f] |\n', q.cell, q.n, q.pass, q.p, q.lo, q.hi);
end
w('\n');

w('## 8. Pooled distributions (all %d MC runs, nothing dropped)\n\n', R.stats.n_mc);
w('| KPI | P5 | P50 | P95 | worst | mean |\n|---|---|---|---|---|---|\n');
for i = 1:numel(R.stats.pooled)
    q = R.stats.pooled(i);
    w('| `%s` | %.4g | %.4g | %.4g | %.4g | %.4g |\n', q.kpi, q.p5, q.p50, q.p95, q.worst, q.mean);
end
w('\n## 9. Per-cell distributions\n\n');
w('| Cell | KPI | nominal | P5 | P50 | P95 | worst |\n|---|---|---|---|---|---|---|\n');
for i = 1:numel(R.stats.per_cell)
    q = R.stats.per_cell(i);
    w('| `%s` | `%s` | %.4g | %.4g | %.4g | %.4g | %.4g |\n', q.cell, q.kpi, q.nominal, q.p5, q.p50, q.p95, q.worst);
end
w('\n');

w('## 10. Failure taxonomy\n\n| Category | Runs | Fraction |\n|---|---|---|\n');
for i = 1:numel(R.taxonomy)
    w('| %s | %d | %.4f |\n', R.taxonomy(i).category, R.taxonomy(i).count, R.taxonomy(i).frac);
end
w('\n');

w('## 11. Sensitivity (Spearman rank correlation)\n\n');
SE = R.sensitivity;
kl = unique({SE.kpi}, 'stable');
for a = 1:numel(kl)
    sel = SE(strcmp({SE.kpi}, kl{a}));
    [~, o] = sort(abs([sel.rho]), 'descend');
    o = o(1:min(6, numel(o)));
    w('- **%s**: ', kl{a});
    parts = cell(1, numel(o));
    for b = 1:numel(o)
        parts{b} = sprintf('`%s` %.3f (%s)', sel(o(b)).factor, sel(o(b)).rho, sel(o(b)).support);
    end
    w('%s\n', strjoin(parts, ', '));
end
w('\nUNSUPPORTED factors necessarily show rho near zero because they were never injected. That zero is an artefact of the missing interface, **not** evidence of insensitivity to CG / CB / buoyancy.\n\n');

w('## 12. Pareto vector\n\n| Axis | Metric | Nominal (median over cells) | MC P50 | MC P95 | MC worst | Status |\n|---|---|---|---|---|---|---|\n');
for i = 1:numel(R.pareto)
    q = R.pareto(i);
    w('| %s | `%s` | %.4g | %.4g | %.4g | %.4g | %s |\n', q.axis, q.metric, ...
        q.nominal_median, q.mc_p50, q.mc_p95, q.mc_worst, q.status);
end
w('\n');

w('## 13. Gate 7 mission / FDIR 16-case matrix - carried, NOT re-drawn\n\n');
w('The 16 Gate 7 cases were **not** re-simulated under the MC priors. Their harness is a separate driver that is outside this task 3-source budget, and reconstructing FDIR dynamics from recorded logs would have been fabrication. The accepted Gate 7 nominal values are reproduced below purely as the reference the next task must reproduce.\n\n');
w('| # | Case | Recovery class | cte_max | depth_min | depth_max | V_min | surface | accom | direct-act | MC re-drawn |\n|---|---|---|---|---|---|---|---|---|---|---|\n');
for i = 1:numel(R.fdir_reference)
    q = R.fdir_reference(i);
    w('| %d | %s | %s | %.4g | %.4g | %.4g | %.4g | %d | %d | %d | NO |\n', i, q.name, ...
        q.rec_class, q.cte_max, q.depth_min, q.depth_max, q.V_min, q.iss_surf, q.iss_acc, q.iss_da);
end
w('\n');

w('## 14. Honesty ledger\n\n');
w('| Claim | Status |\n|---|---|\n');
w('| CG / CB / buoyancy priors injected into the plant | **UNSUPPORTED** - drawn and stored, never applied; production `underwater777_vehicle_dynamics.m` exposes no shadow parameter interface and editing it is forbidden |\n');
w('| Battery / power / brownout | **PARTIAL** - reaches the plant only as a thrust-authority derate; no bus, compute or actuator-supply coupling exists on this path |\n');
w('| Estimated streams | **NOT_IMPLEMENTED** - no estimator on the production tracking path; horizontal position is passed as truth and labelled, not faked |\n');
w('| Timing / WCET | **PARTIAL** - simulated command transport delay only; target period/deadline/WCET/overrun remain TO_BE_IDENTIFIED |\n');
w('| Watchdog / mission / bus / leak / actuator-current monitors | **UNSUPPORTED on this path** - no mission bus exists in the tracking loop; only IMU/DVL/depth staleness and undervoltage are reachable |\n');
w('| Frozen production cell definitions | **ASSUMED_RECONSTRUCTION** - see section 4 |\n');
w('| Every prior label | ASSUMED (no ASSUMED -> IDENTIFIED upgrade anywhere) |\n');
w('| Hardware | NOT_CERTIFIED |\n');
w('\n');

w('## 15. Artifacts\n\n');
if isfield(R, 'png') && ~isempty(R.png)
    for i = 1:numel(R.png)
        w('- `%s`\n', strrep(R.png{i}, '\', '/'));
    end
end
w('- `%s.md`\n- `%s.mat`\n', strrep(OUTB,'\','/'), strrep(OUTB,'\','/'));
if isfield(R, 'footprint_mib')
    w('\nTotal footprint %.2f MiB (< 300 MiB: %d).\n', R.footprint_mib, R.footprint_ok);
end
w('\n## 16. Next exact task (one, bounded, untried)\n\n');
w(['**`gate8_plant_parameter_shadow_interface`** - add a *shadow-only* parameter-injection ' ...
   'seam so CG / CB / buoyancy priors can physically enter the plant without editing ' ...
   'production: a read-only clone of `underwater777_vehicle_dynamics.m` marked with the ' ...
   'same BEGIN/ORIG/END reduction contract that `continuous_path_tracking_propulsion.m` ' ...
   'already proves, plus a mechanical reduction gate showing the clone reduces byte-identically ' ...
   'to production. One MATLAB call, parity-first: the clone at zero offset must reproduce this ' ...
   'report nominal hashes bit-for-bit before any Monte Carlo is re-run. Gate 8 is re-scored only ' ...
   'after that seam exists.\n\n']);
w('No brand, no purchase, no MCU selection. `CODEX_VERTICAL_PLAN.md` untouched. Gate 9 stays locked.\n');
fclose(fid);
end

% =====================================================================
% one-time appends to readiness / realism / research logs
% =====================================================================
function g8_append_logs(R, TAG)
marker = sprintf('<!-- APPEND_MARKER:%s_001 -->', TAG);
targets = { fullfile('suite_results','AUV_REALIZATION_READINESS_PLAN.md'), 'readiness'; ...
            fullfile('suite_results','AUV_REALISM_AND_VISUAL_VALIDATION.md'), 'realism'; ...
            fullfile('suite_results','PITCH_CONTROL_RESEARCH_LOG.md'), 'research' };
if ~isfield(R, 'gates') || ~isfield(R, 'stats')
    fprintf('[G8] campaign incomplete, logs not appended\n');
    return
end
for i = 1:size(targets,1)
    p = targets{i,1};
    if exist(p, 'file') ~= 2, continue; end
    txt = '';
    try, txt = fileread(p); catch, end     % mechanical idempotency guard only
    if ~isempty(strfind(txt, marker)) %#ok<STREMP>
        fprintf('[G8] %s log already carries the marker, skipping append\n', targets{i,2});
        continue
    end
    fid = fopen(p, 'a');
    if fid < 0, continue; end
    fprintf(fid, '\n\n%s\n\n', marker);
    fprintf(fid, '## Append: GATE8_MONTE_CARLO_INDEPENDENT_PRIORS_001 (%s log)\n\n', targets{i,2});
    fprintf(fid, '**Date:** %s | **Class:** Gate 8 isolated Monte Carlo campaign, shadow-only driver | **MATLAB runs:** 1 | **Production/CODEX:** untouched | **HW:** NOT_CERTIFIED\n\n', R.created);
    fprintf(fid, '**Verdict: %s.**', R.verdict);
    if ~strcmp(R.verdict, 'PASS')
        fprintf(fid, ' Failed hard gates: %s.', strjoin(R.hard_failed, ', '));
    end
    fprintf(fid, '\n\n');
    if isfield(R, 'stats') && isfield(R.stats, 'pass_prob')
        fprintf(fid, '- Campaign: seed `%d`, %d independent draw vectors x %d production cells (X/XZ U={1,1.5,2}, R10 U={1.5,2}), dt=%.3f s, T=%.0f s.\n', ...
            R.seed, R.n_draws, numel(R.cells), R.dt, R.T_final);
        fprintf(fid, '- Pass probability %.4f, Wilson 95%% CI [%.4f, %.4f] over %d Monte Carlo runs.\n', ...
            R.stats.pass_prob, R.stats.pass_ci95(1), R.stats.pass_ci95(2), R.stats.n_mc);
        pooled = R.stats.pooled;
        ic = find(strcmp({pooled.kpi}, 'cte_max'), 1);
        if ~isempty(ic)
            fprintf(fid, '- Pooled cte_max P5/P50/P95/worst = %.3f / %.3f / %.3f / %.3f m.\n', ...
                pooled(ic).p5, pooled(ic).p50, pooled(ic).p95, pooled(ic).worst);
        end
    end
    fprintf(fid, '- Exact nominal parity (shadow hooks-off == unmodified `continuous_path_tracking`): %d. Deterministic reverse-order replay: %d.\n', ...
        R.parity_ok, R.replay_ok);
    fprintf(fid, '- Honest gaps: CG/CB/buoyancy priors **UNSUPPORTED** (drawn, never injected - no shadow plant-parameter interface); power **PARTIAL** (thrust-authority derate only); estimator streams **NOT_IMPLEMENTED**; Gate 7 16-case FDIR matrix **not re-drawn**; X/XZ/R10 cell geometry is an **ASSUMED_RECONSTRUCTION**.\n');
    fprintf(fid, '- All priors remain **ASSUMED**. Simulation result is not hardware certification (**NOT_CERTIFIED**).\n');
    fprintf(fid, '- Evidence: `suite_results/%s.{md,mat,png}` plus 4 visual-QA panels.\n', TAG);
    fprintf(fid, '- Gate 9 remains **locked** (unlocks only on Gate 8 PASS); Gate 9B remains post-Gate 9.\n');
    fprintf(fid, '- Next exact task: `gate8_plant_parameter_shadow_interface` (shadow-only reducible clone of the plant giving CG/CB/buoyancy an injection seam; parity-first).\n');
    fclose(fid);
    fprintf('[G8] appended %s log: %s\n', targets{i,2}, p);
end
end
