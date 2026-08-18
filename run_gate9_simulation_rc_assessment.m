function run_gate9_simulation_rc_assessment()
%RUN_GATE9_SIMULATION_RC_ASSESSMENT  TASK_ID GATE9_SIMULATION_RC_ASSESSMENT_001
%
%   Bounded Gate 9 simulation release-candidate (RC) assessment.
%   READ-ONLY. Exactly three permitted sources are read as evidence:
%     1 suite_results/AUV_REALIZATION_READINESS_PLAN.md      (transcribed constants)
%     2 suite_results/PROPULSION_POWER_COMPUTE_PARITY_FIX.mat (loaded here)
%     3 suite_results/REAL_TIME_POWER_INTEGRITY_CONTRACT.mat  (loaded here)
%
%   No simulation campaign, no method retry, no promotion, no label upgrade,
%   no production edit, no CODEX_VERTICAL_PLAN edit, no vendor or part claim.
%   Simulation is not hardware certification: NOT_CERTIFIED.

TASK = 'GATE9_SIMULATION_RC_ASSESSMENT_001';
BASE = 'GATE9_SIMULATION_RC_ASSESSMENT';

ROOT = fileparts(mfilename('fullpath'));
if isempty(ROOT); ROOT = pwd; end
SR = fullfile(ROOT, 'suite_results');

LOGP = fullfile(SR, [BASE '_run.log']);
MDP  = fullfile(SR, [BASE '.md']);
MATP = fullfile(SR, [BASE '.mat']);
PNGP = fullfile(SR, [BASE '.png']);
QAP  = fullfile(SR, [BASE '_qa.png']);

if exist(LOGP, 'file'); delete(LOGP); end
diary(LOGP); diary on;

R = struct();
R.task = TASK;
R.t_start = datestr(now, 'yyyy-mm-dd HH:MM:SS'); %#ok<TNOW1,DATST>
R.matlab_pid = feature('getpid');
R.matlab_version = version();
R.fatal_error = '';

fprintf('==============================================================\n');
fprintf('%s\n', TASK);
fprintf('start   : %s\n', R.t_start);
fprintf('matlab  : %s  pid=%d\n', R.matlab_version, R.matlab_pid);
fprintf('root    : %s\n', ROOT);
fprintf('mode    : BOUNDED READ-ONLY ASSESSMENT (no campaign, no retry)\n');
fprintf('==============================================================\n\n');

try
    % ---------------------------------------------------------------- G0
    fprintf('[G0] artifact / disk preflight\n');
    R.g0 = preflight(ROOT);
    fprintf('     free on artifact volume : %.2f GiB\n', R.g0.free_gib);
    fprintf('     start threshold 3 GiB   : %s\n', tf(R.g0.start_ok));
    fprintf('     preferred reserve 5 GiB : %s\n', tf(R.g0.reserve_ok));
    fprintf('     artifact budget estimate: <= 3.0 MiB (md+mat+png+qa+log)\n\n');

    % ------------------------------------------------------- integrity pre
    R.integrity_files = { ...
        'continuous_path_tracking.m'; ...
        'controller_law.m'; ...
        'guidance_law.m'; ...
        fullfile('suite_results','CODEX_VERTICAL_PLAN.md')};
    R.source_files = { ...
        fullfile('suite_results','AUV_REALIZATION_READINESS_PLAN.md'); ...
        fullfile('suite_results','PROPULSION_POWER_COMPUTE_PARITY_FIX.mat'); ...
        fullfile('suite_results','REAL_TIME_POWER_INTEGRITY_CONTRACT.mat')};

    fprintf('[FP] frozen fingerprints BEFORE any write\n');
    R.fp_pre_integrity = fp_list(ROOT, R.integrity_files);
    R.fp_sources       = fp_list(ROOT, R.source_files);
    print_fp('     integrity ', R.fp_pre_integrity);
    print_fp('     source    ', R.fp_sources);
    fprintf('\n');

    % ------------------------------------------------------- load sources
    fprintf('[S2] load PROPULSION_POWER_COMPUTE_PARITY_FIX.mat\n');
    [R.s2, R.s2_err] = safe_load(fullfile(ROOT, R.source_files{2}));
    fprintf('     top-level variables: %d\n', numel(fieldnames(R.s2)));
    fprintf('[S3] load REAL_TIME_POWER_INTEGRITY_CONTRACT.mat\n');
    [R.s3, R.s3_err] = safe_load(fullfile(ROOT, R.source_files{3}));
    fprintf('     top-level variables: %d\n\n', numel(fieldnames(R.s3)));

    inv2 = flatten_any(R.s2, 'S2', {}, 0);
    inv3 = flatten_any(R.s3, 'S3', {}, 0);
    R.inventory = [inv2; inv3];
    if isempty(R.inventory); R.inventory = cell(0, 4); end
    fprintf('[INV] flattened leaf entries: S2=%d  S3=%d  total=%d\n', ...
        size(inv2,1), size(inv3,1), size(R.inventory,1));

    R.harvest = harvest(R.inventory);
    hk = fieldnames(R.harvest);
    fprintf('[HRV] harvest probes: %d\n', numel(hk));
    for i = 1:numel(hk)
        h = R.harvest.(hk{i});
        fprintf('      %-26s hits=%-4d %s\n', hk{i}, h.n, h.first);
    end
    fprintf('\n');

    % ----------------------------------------------- declared constants
    R.k = constants();
    R.rr = requirement_ranges(R.k);
    R.vm = verification_matrix(R.g0);
    R.rk = residual_risks();
    R.pv = pareto_vector();
    R.icd = icd_boundary();
    R.ext = external_stops();

    % ------------------------------------------------------- disposition
    R.disp = disposition(R.vm, R.rk);
    fprintf('[RC] Gate 9 disposition : %s\n', R.disp.verdict);
    fprintf('[RC] reason             : %s\n', R.disp.reason);
    fprintf('[RC] hardware readiness : NOT_CERTIFIED\n\n');

    % ------------------------------------------------------------ figures
    fprintf('[FIG] main evidence panel\n');
    make_main_figure(PNGP, R);
    fprintf('[FIG] visual QA panel\n');
    make_qa_figure(QAP, R, PNGP);
    R.visual_qa = visual_qa(PNGP, QAP);
    fprintf('      main png %dx%d px ink=%.3f  qa png %dx%d px ink=%.3f\n', ...
        R.visual_qa.main_w, R.visual_qa.main_h, R.visual_qa.main_ink, ...
        R.visual_qa.qa_w, R.visual_qa.qa_h, R.visual_qa.qa_ink);
    fprintf('      VISUAL QA VERDICT: %s\n\n', R.visual_qa.verdict);

    % ------------------------------------------- integrity after computation
    fprintf('\n[FP] frozen fingerprints AFTER computation and figure emission\n');
    R.fp_post_integrity = fp_list(ROOT, R.integrity_files);
    print_fp('     integrity ', R.fp_post_integrity);
    R.integrity_ok = true;
    for i = 1:size(R.fp_pre_integrity,1)
        same = strcmp(R.fp_pre_integrity{i,3}, R.fp_post_integrity{i,3});
        R.integrity_ok = R.integrity_ok && same;
        fprintf('     %-44s unchanged=%s\n', R.fp_pre_integrity{i,1}, tf(same));
    end
    fprintf('     PRODUCTION + CODEX_VERTICAL_PLAN UNTOUCHED: %s\n', tf(R.integrity_ok));

    % -------------------------------------------------------------- report
    fprintf('\n[MD] write %s\n', MDP);
    write_md(MDP, R);

    % -------------------------------------------------------------- appends
    fprintf('\n[APP] consistent summaries\n');
    R.appends = do_appends(SR, R);
    for i = 1:size(R.appends,1)
        fprintf('      %-52s %s\n', R.appends{i,1}, R.appends{i,2});
    end

    % --------------------------------------------- integrity after ALL writes
    fprintf('\n[FP] frozen fingerprints AFTER all writes including appends\n');
    R.fp_final_integrity = fp_list(ROOT, R.integrity_files);
    R.integrity_final_ok = true;
    for i = 1:size(R.fp_pre_integrity,1)
        same = strcmp(R.fp_pre_integrity{i,3}, R.fp_final_integrity{i,3});
        R.integrity_final_ok = R.integrity_final_ok && same;
        fprintf('     %-44s unchanged=%s  sha256=%s\n', R.fp_pre_integrity{i,1}, tf(same), ...
            short(R.fp_final_integrity{i,3}));
    end
    fprintf('     FINAL: PRODUCTION + CODEX_VERTICAL_PLAN UNTOUCHED: %s\n', tf(R.integrity_final_ok));

    fprintf('\n[MAT] write %s\n', MATP);
    Gate9 = R; %#ok<NASGU>
    save(MATP, 'Gate9', '-v7.3');

    R.fp_artifacts = fp_list(SR, {[BASE '.md'], [BASE '.mat'], [BASE '.png'], [BASE '_qa.png']});
    fprintf('\n[FP] emitted artifacts\n');
    print_fp('     artifact  ', R.fp_artifacts);

    fprintf('\n[CHANGED FILES]\n');
    cf = changed_files(BASE);
    for i = 1:numel(cf); fprintf('     %s\n', cf{i}); end

    fprintf('\n[NEXT] exactly one: GATE9B_FAST_WHOLE_CODE_EMBEDDED_GAP_AUDIT_001 (read-only)\n');
    fprintf('[STOP] STM32 adaptation FORBIDDEN pending exact part/board + blocker disposition\n');
    fprintf('\n%s COMPLETE  verdict=%s  visual=%s\n', TASK, R.disp.verdict, R.visual_qa.verdict);

catch ME
    R.fatal_error = getReport(ME, 'extended', 'hyperlinks', 'off');
    fprintf(2, '\n[FATAL] %s\n', R.fatal_error);
    try
        Gate9 = R; %#ok<NASGU>
        save(MATP, 'Gate9');
        fid = fopen(MDP, 'a', 'n', 'UTF-8');
        if fid > 0
            fprintf(fid, '\n\n## FATAL ERROR DURING ASSESSMENT\n\n```\n%s\n```\n', R.fatal_error);
            fclose(fid);
        end
    catch
    end
end

diary off;
end

% =====================================================================
% preflight
% =====================================================================
function g = preflight(ROOT)
g = struct('free_gib', NaN, 'start_ok', false, 'reserve_ok', false, 'volume', '');
try
    d = ROOT;
    while ~isempty(d) && ~exist(d, 'dir'); d = fileparts(d); end
    jf = java.io.File(d);
    g.free_gib = double(jf.getFreeSpace()) / 1024^3;
    g.volume = d;
catch
    g.free_gib = NaN;
end
g.start_ok = ~isnan(g.free_gib) && g.free_gib >= 3.0;
g.reserve_ok = ~isnan(g.free_gib) && g.free_gib >= 5.0;
end

% =====================================================================
% fingerprints
% =====================================================================
function out = fp_list(root, rel)
out = cell(numel(rel), 5);
for i = 1:numel(rel)
    p = fullfile(root, rel{i});
    out{i,1} = rel{i};
    if exist(p, 'file') == 2
        f = dir(p);
        b = [];
        fid = fopen(p, 'r');
        if fid > 0
            b = fread(fid, Inf, '*uint8');
            fclose(fid);
        end
        out{i,2} = f(1).bytes;
        out{i,3} = sha256(b);
        out{i,4} = adlerish(b);
        out{i,5} = f(1).date;
    else
        out{i,2} = -1; out{i,3} = 'MISSING'; out{i,4} = 'MISSING'; out{i,5} = '';
    end
end
end

function h = sha256(b)
h = 'UNAVAILABLE';
try
    md = java.security.MessageDigest.getInstance('SHA-256');
    d = typecast(md.digest(typecast(uint8(b(:)), 'int8')), 'uint8');
    h = lower(reshape(dec2hex(d, 2)', 1, []));
catch
end
end

function s = adlerish(b)
s = 'UNAVAILABLE';
try
    x = double(b(:));
    n = numel(x);
    s1 = mod(sum(x), 2^32);
    s2 = mod(sum(x .* (1:n)'), 2^32);
    s = sprintf('n=%d.s1=%d.s2=%d', n, s1, s2);
catch
end
end

function print_fp(tag, L)
for i = 1:size(L,1)
    fprintf('%s%-46s %10d B  sha256=%s\n', tag, L{i,1}, L{i,2}, short(L{i,3}));
end
end

function s = short(h)
if numel(h) > 16; s = [h(1:16) '...']; else; s = h; end
end

function s = tf(b)
if b; s = 'YES'; else; s = 'NO'; end
end

% =====================================================================
% load + flatten + harvest
% =====================================================================
function [s, err] = safe_load(p)
s = struct(); err = '';
try
    s = load(p);
catch ME
    err = ME.message;
end
end

function inv = flatten_any(v, name, inv, depth)
MAXD = 6; MAXROWS = 6000;
if size(inv,1) > MAXROWS; return; end
if depth > MAXD
    inv = [inv; {name, class(v), sizestr(v), '<depth-limited>'}];
    return;
end
if isstruct(v)
    if numel(v) == 1
        f = fieldnames(v);
        for i = 1:numel(f)
            inv = flatten_any(v.(f{i}), [name '.' f{i}], inv, depth+1);
        end
    else
        inv = [inv; {name, 'struct-array', sizestr(v), sprintf('%d elements', numel(v))}];
        nshow = min(numel(v), 40);
        f = fieldnames(v);
        for k = 1:nshow
            for i = 1:numel(f)
                inv = flatten_any(v(k).(f{i}), sprintf('%s(%d).%s', name, k, f{i}), inv, depth+1);
            end
        end
    end
elseif iscell(v)
    nshow = min(numel(v), 60);
    inv = [inv; {name, 'cell', sizestr(v), sprintf('%d elements', numel(v))}];
    for k = 1:nshow
        inv = flatten_any(v{k}, sprintf('%s{%d}', name, k), inv, depth+1);
    end
elseif ischar(v)
    inv = [inv; {name, 'char', sizestr(v), trunc(oneline(v), 160)}];
elseif isa(v, 'string')
    txt = '<string>';
    try
        if isempty(v)
            txt = '<empty string>';
        else
            parts = cellstr(v(:));
            txt = strjoin(parts(1:min(numel(parts), 8))', ' / ');
        end
    catch
    end
    inv = [inv; {name, 'string', sizestr(v), trunc(oneline(txt), 160)}];
elseif islogical(v) || isnumeric(v)
    inv = [inv; {name, class(v), sizestr(v), numsum(v)}];
else
    inv = [inv; {name, class(v), sizestr(v), '<unsupported>'}];
end
end

function s = sizestr(v)
d = size(v);
s = sprintf('%d', d(1));
for i = 2:numel(d); s = [s 'x' sprintf('%d', d(i))]; end %#ok<AGROW>
end

function s = numsum(v)
x = double(v(:));
if isempty(x); s = '<empty>'; return; end
if numel(x) <= 6
    s = strtrim(sprintf('%.6g ', x));
else
    fx = x(isfinite(x));
    if isempty(fx)
        s = sprintf('n=%d all-nonfinite', numel(x));
    else
        s = sprintf('n=%d min=%.6g max=%.6g mean=%.6g', numel(x), min(fx), max(fx), mean(fx));
    end
end
end

function s = oneline(c)
s = regexprep(c(:)', '\s+', ' ');
end

function s = trunc(c, n)
if numel(c) > n; s = [c(1:n) '...']; else; s = c; end
end

function H = harvest(inv)
probes = { ...
    'tau_lag',        '(tau|lag|time_?const)'; ...
    'thrust',         'thrust'; ...
    'current_amp',    '(current|amp|i_bus|ibus)'; ...
    'energy',         '(energy|wh|joule|watt)'; ...
    'voltage_pu',     '(volt|vbus|v_bus|brownout|undervolt|pu)'; ...
    'efficiency',     '(eff|eta)'; ...
    'period',         'period'; ...
    'deadline',       'deadline'; ...
    'wcet',           'wcet'; ...
    'jitter',         'jitter'; ...
    'overrun',        '(overrun|miss|deadline_miss)'; ...
    'priority',       'priorit'; ...
    'rate_hz',        '(_hz|freq|rate)'; ...
    'delay_ms',       'delay'; ...
    'margin',         'margin'; ...
    'seed',           'seed'; ...
    'dt_step',        '(^|\.)dt|dt_|step'; ...
    'gate_verdict',   '(gate|verdict|pass|fail)'; ...
    'deadband',       '(deadband|backlash|hyster)'; ...
    'sensor',         '(dvl|imu|gyro|accel|depth_sens|sigma|noise|bias|dropout)'; ...
    'safehold',       '(safe_?hold|fail_?silent|watchdog)'};
H = struct();
if isempty(inv); inv = cell(0, 4); end
names = inv(:,1);
for i = 1:size(probes,1)
    key = probes{i,1};
    m = ~cellfun('isempty', regexpi(names, probes{i,2}, 'once'));
    idx = find(m);
    rec = struct();
    rec.n = numel(idx);
    if isempty(idx)
        rec.first = '<none>';
        rec.rows = cell(0,4);
    else
        rec.first = trunc(sprintf('%s = %s', inv{idx(1),1}, inv{idx(1),4}), 110);
        rec.rows = inv(idx(1:min(numel(idx), 60)), :);
    end
    H.(key) = rec;
end
end

% =====================================================================
% declared constants transcribed from source #1 (readiness plan)
% =====================================================================
function k = constants()
k = struct();
% cadences (ICD)
k.Tc = 0.025;                 % s   controller period, FIXED 40 Hz
k.fc = 40.0;                  % Hz
k.Tg = 0.075;                 % s   guidance period, DERIVED 13.33 Hz
k.fg = 1/0.075;               % Hz
k.Tc_legacy = 0.0375;         % s   ASSUMED evidence-only, not promoted
% actuator envelope (FIXED)
k.elev_deg = 15.0;
k.rud_deg = 25.0;
k.rate_dps = 40.0;
% ASSUMED actuator grids
k.tau_grid = [0.05 0.10 0.20];
k.db_grid_deg = [0 0.10 0.25 0.50];
k.db_rmse_deg = [0.7063 0.7136 0.7499 0.8666];
k.db_pct = (k.db_rmse_deg / k.db_rmse_deg(1) - 1) * 100;
k.policy_secondary_pct = 2.0;      % promotion policy secondary tolerance
% ASSUMED transport delay cases exercised at Gate 6B
k.delay_ms_cases = [0 15 30];
% Gate 6 worst-corner budget
k.energy_whkm = 15.59;
k.current_a = 6.88;
k.thrust_n = 14.054;
k.fin_duty = 0.997;
k.energy_margin = 0.896;
k.current_margin = 0.541;
% Gate 6B power integrity
k.brownout_trigger_pu = 0.85;
k.brownout_min_pu = 0.803;
k.safehold_ms = 79;
k.miss_count = 200;
k.miss_consecutive = 3;
k.safehold_after_miss_ms = 3;
k.host_step_ms = 31.919;           % host mean, NOT WCET
k.controller_calls = 42000;
k.plant_rhs = 2564886;
% R10 rail measurement
k.rail_raw_deg = 466.6729;
k.rail_dwell = 0.2817;
k.mag_dwell = 0.8908;
k.rate_dwell = 0.6917;
k.peak_slew_dps = 40.0000;
k.rail_first_s = 1.825;
k.rail_total_s = 8.450;
% Gate 8 distribution
k.cte_p5 = 0.110; k.cte_p50 = 0.342; k.cte_p95 = 0.565; k.cte_worst = 0.826;
k.pass_prob = 0.8594; k.wilson_lo = 0.8115; k.wilson_hi = 0.8967;
k.seed = 20260809; k.draws = 32; k.cells = 8; k.mc_runs = 256;
k.dt_mc = 0.025; k.T_final = 30;
k.replay_draws = [1 16 32];
k.r10_fp = 'n=153600.s1=19094896.s2=2901292177';
% guidance closure
k.heading_err_deg = 3.8352;
k.overcrab_deg = 0.335019;
k.k_beta = 1.35;
k.depth_mae_m = 0.269528;
% dead-reckoning evaluation grid (ASSUMED)
k.T_dr_grid = [1 5 10 30];
% ASSUMED coverage factors
k.cov_cont = 1.20;
k.cov_peak = 1.50;
k.alloc_frac = 0.10;
k.util_max = 0.70;
end

% =====================================================================
% procurement-ready requirement RANGES
% every row: DERIVED from an ASSUMED or TO_BE_IDENTIFIED parent,
% carrying unit, frame/axis, source, limiting residual risk.
% component-neutral: no vendor, brand, part number or purchase claim.
% =====================================================================
function rr = requirement_ranges(k)
rr = {};
a = @(varargin) varargin;

% ---- servo / control surface
rr(end+1,:) = a('RR-01', 'Servo first-order response time constant tau (elevator and rudder)', ...
    's', 'actuator channel, per surface', ...
    sprintf('%.4f .. %.3f', 0.5*k.Tc, 4*k.Tc), ...
    sprintf(['DERIVED: lower = 0.5 x controller period Tc = %.4f s, below which servo bandwidth ' ...
    'exceeds the %.0f Hz command bandwidth and buys no closed-loop benefit; upper = 4 x Tc = %.3f s, ' ...
    'which is the ASSUMED tau grid point carrying recorded shadow evidence (rudder RMSE 0.7063 deg, ' ...
    'delay 0.0750 s, rate dwell 0.00 pct).'], 0.5*k.Tc, k.fc, 4*k.Tc), ...
    'ASSUMED', sprintf('ASSUMED tau grid {%.2f, %.2f, %.2f} s; FIXED Tc = %.3f s', k.tau_grid, k.Tc), ...
    'R7 (servo tau TO_BE_IDENTIFIED), R1 (no rate margin at the rail)');

rr(end+1,:) = a('RR-02', 'Servo no-load angular rate (elevator and rudder)', ...
    'deg/s', 'actuator channel, per surface', ...
    sprintf('%.0f .. %.0f (hard floor %.0f)', 2*k.rate_dps, 4*k.rate_dps, k.rate_dps), ...
    sprintf(['DERIVED: hard floor = the FIXED software rate limit %.0f deg/s; the required band is ' ...
    '2x..4x that floor because the R10 cell shows rate-limiter dwell %.4f and peak realized slew ' ...
    'exactly %.4f deg/s, i.e. ZERO rate margin at the software limit.'], ...
    k.rate_dps, k.rate_dwell, k.peak_slew_dps), ...
    'TO_BE_IDENTIFIED', 'servo no-load rate TO_BE_IDENTIFIED; FIXED software rate limit 40 deg/s', ...
    'R1 (R10 rudder rail unresolved, BLOCKER)');

rr(end+1,:) = a('RR-03', 'Servo total deadband + backlash (mechanical play referred to surface)', ...
    'deg', 'surface deflection, per surface', ...
    sprintf('0 .. %.2f accept; (%.2f .. %.2f] conditional on written waiver', ...
    k.db_grid_deg(2), k.db_grid_deg(2), k.db_grid_deg(3)), ...
    sprintf(['DERIVED: open-loop deadband sensitivity gives rudder RMSE degradation vs w=0 of ' ...
    '%.2f pct at %.2f deg, %.2f pct at %.2f deg and %.2f pct at %.2f deg. The promotion policy ' ...
    'admits at most %.1f pct secondary non-safety regression, so %.2f deg is the only grid width ' ...
    'inside policy.'], k.db_pct(2), k.db_grid_deg(2), k.db_pct(3), k.db_grid_deg(3), ...
    k.db_pct(4), k.db_grid_deg(4), k.policy_secondary_pct, k.db_grid_deg(2)), ...
    'ASSUMED', 'ASSUMED play-free deadband grid {0, 0.10, 0.25, 0.50} deg (open loop, not closed-loop limit cycle)', ...
    'R7 (deadband/hysteresis TO_BE_IDENTIFIED), R1');

rr(end+1,:) = a('RR-04', 'Servo command and feedback angular resolution', ...
    'deg', 'surface deflection, per surface', ...
    sprintf('<= %.3f', 0.2*k.db_grid_deg(2)), ...
    sprintf(['DERIVED: 0.2 x the RR-03 deadband ceiling %.2f deg, so quantisation cannot consume more ' ...
    'than one fifth of the admissible play budget.'], k.db_grid_deg(2)), ...
    'ASSUMED', 'child of RR-03 (ASSUMED deadband grid)', 'R7');

rr(end+1,:) = a('RR-05', 'Surface deflection envelope to be mechanically guaranteed', ...
    'deg', 'BODY, elevator / rudder', ...
    sprintf('elevator >= +/-%.0f ; rudder >= +/-%.0f', k.elev_deg, k.rud_deg), ...
    'DERIVED: the FIXED software magnitude envelope must be reachable mechanically without hard-stop contact; the R10 plant input pins at 25.0000 deg for 0.2817 of a 30 s horizon so the rudder stop is exercised continuously.', ...
    'ASSUMED', 'FIXED software envelope elevator 15 deg, rudder 25 deg (frozen production anchor)', ...
    'R1 (rail dwell), R4 (cell geometry ASSUMED_RECONSTRUCTION)');

% ---- propulsion
rr(end+1,:) = a('RR-06', 'Propulsion first-order thrust lag time constant tau_thr', ...
    's', 'BODY x (surge)', ...
    'BRACKET ONLY: [ideal .. slow-and-low-authority ASSUMED variant]; numeric upper UNRESOLVED_IN_PERMITTED_SOURCES', ...
    'DERIVED: the Gate 6 worst-corner budget was met across the whole ASSUMED thruster variant family (ideal, nominal lag-map, slow+low-authority, high-authority), all four of which are Pareto non-dominated, so the evidenced admissible bracket is the family span. The numeric tau of each variant is not quoted in the permitted sources, therefore no number is invented here.', ...
    'ASSUMED', 'ASSUMED thruster variant family {ideal, nominal lag-map, slow+low-authority, high-authority}', ...
    'R7 (thruster map TO_BE_IDENTIFIED), R6 (power coverage PARTIAL)');

rr(end+1,:) = a('RR-07', 'Continuous / peak axial thrust capability', ...
    'N', 'BODY x (surge)', ...
    sprintf('continuous >= %.3f ; peak >= %.3f', k.cov_cont*k.thrust_n, k.cov_peak*k.thrust_n), ...
    sprintf(['DERIVED: worst-corner peak realized thrust %.3f N scaled by the ASSUMED coverage factors ' ...
    '%.2f (continuous) and %.2f (peak). Coverage is required because buoyancy +/-3 pct and CG/CB +/-2 cm ' ...
    'were drawn but never injected, so the recorded corner does not bound the true worst case.'], ...
    k.thrust_n, k.cov_cont, k.cov_peak), ...
    'ASSUMED', sprintf('worst-corner peak realized thrust %.3f N under ASSUMED thruster family', k.thrust_n), ...
    'R2 (CG/CB/buoyancy UNSUPPORTED), R6');

% ---- power
rr(end+1,:) = a('RR-08', 'Bus current delivery capability', ...
    'A', 'electrical bus', ...
    sprintf('continuous >= %.3f ; peak >= %.3f', k.cov_cont*k.current_a, k.cov_peak*k.current_a), ...
    sprintf(['DERIVED: worst-corner peak bus current %.2f A (recorded current margin +%.3f) scaled by ' ...
    'the ASSUMED coverage factors %.2f and %.2f.'], k.current_a, k.current_margin, k.cov_cont, k.cov_peak), ...
    'ASSUMED', sprintf('worst-corner peak bus current %.2f A', k.current_a), 'R6, R2');

rr(end+1,:) = a('RR-09', 'Usable stored energy per kilometre of track', ...
    'Wh/km', 'mission profile', ...
    sprintf('%.3f .. %.3f', k.cov_cont*k.energy_whkm, k.cov_peak*k.energy_whkm), ...
    sprintf(['DERIVED: worst-corner %.2f Wh/km (recorded energy margin +%.3f) scaled by the ASSUMED ' ...
    'coverage factors %.2f and %.2f. Absolute pack energy needs the mission range, which is ' ...
    'TO_BE_IDENTIFIED, so only the per-km rate is specified.'], ...
    k.energy_whkm, k.energy_margin, k.cov_cont, k.cov_peak), ...
    'ASSUMED', sprintf('worst-corner %.2f Wh/km at the pessimistic ASSUMED corner', k.energy_whkm), 'R6');

rr(end+1,:) = a('RR-10', 'Bus source impedance under peak transient (power integrity)', ...
    'ohm per volt of nominal bus', 'electrical bus', ...
    sprintf('<= %.5f', (1 - k.brownout_trigger_pu) / (k.cov_peak * k.current_a)), ...
    sprintf(['DERIVED: the undervoltage trigger is %.2f pu, so the admissible sag is %.2f pu; dividing ' ...
    'by the RR-08 peak current %.3f A gives the normalised source-impedance ceiling. Expressed per volt ' ...
    'of nominal bus because the nominal bus voltage is TO_BE_IDENTIFIED. Observed brownout minimum in ' ...
    'the injected case was %.3f pu, which is a stimulus, not a supply property.'], ...
    k.brownout_trigger_pu, 1 - k.brownout_trigger_pu, k.cov_peak*k.current_a, k.brownout_min_pu), ...
    'TO_BE_IDENTIFIED', sprintf('nominal bus voltage TO_BE_IDENTIFIED; ASSUMED trigger %.2f pu', k.brownout_trigger_pu), ...
    'R6 (brownout branch never entered under MC)');

rr(end+1,:) = a('RR-11', 'Supply hold-up time through an undervoltage excursion', ...
    'ms', 'electrical bus', ...
    sprintf('>= %.0f', ceil(k.safehold_ms * 1.25 / 10) * 10), ...
    sprintf(['DERIVED: health declaration to safe-hold took %.0f ms in the brownout case; a %.2fx ' ...
    'ASSUMED margin rounded up to the next 10 ms gives the hold-up floor, so the bus must survive the ' ...
    'detection-to-safe-hold interval without loss of compute or state.'], k.safehold_ms, 1.25), ...
    'ASSUMED', sprintf('ASSUMED brownout case; safe-hold declared %.0f ms after trigger', k.safehold_ms), 'R6');

% ---- navigation sensing
for i = 1:numel(k.T_dr_grid)
    T = k.T_dr_grid(i);
    rr(end+1,:) = a(sprintf('RR-12.%d', i), ...
        sprintf('DVL velocity error (noise 1-sigma + residual bias, combined) at dead-reckoning horizon T_DR = %g s', T), ...
        'm/s', 'BODY u,v,w (bottom-lock)', ...
        sprintf('<= %.5f', k.alloc_frac * k.cte_p95 / T), ...
        sprintf(['DERIVED: allocate %.0f pct of the pooled cte_max P95 of %.3f m to navigation-induced ' ...
        'lateral error, i.e. %.4f m, and divide by the ASSUMED dead-reckoning horizon %g s.'], ...
        k.alloc_frac*100, k.cte_p95, k.alloc_frac*k.cte_p95, T), ...
        'ASSUMED', sprintf('ASSUMED T_DR grid {1,5,10,30} s; pooled cte_max P95 %.3f m from the waived Gate 8 campaign', k.cte_p95), ...
        'R5 (estimator streams NOT_IMPLEMENTED on the Gate 8 path)'); %#ok<AGROW>
end

for i = 1:numel(k.T_dr_grid)
    T = k.T_dr_grid(i);
    rr(end+1,:) = a(sprintf('RR-13.%d', i), ...
        sprintf('IMU gyro residual bias (post-calibration, in-run) at dead-reckoning horizon T_DR = %g s', T), ...
        'deg/s', 'BODY p,q,r', ...
        sprintf('<= %.5f', k.alloc_frac * k.heading_err_deg / T), ...
        sprintf(['DERIVED: allocate %.0f pct of the measured steady heading tracking error %.4f deg to ' ...
        'estimator bias drift, i.e. %.4f deg, and divide by the ASSUMED dead-reckoning horizon %g s.'], ...
        k.alloc_frac*100, k.heading_err_deg, k.alloc_frac*k.heading_err_deg, T), ...
        'ASSUMED', sprintf('ASSUMED T_DR grid; measured heading error %.4f deg from the guidance signal-log closure', k.heading_err_deg), ...
        'R5, R1 (heading error is the dominant rail contributor)'); %#ok<AGROW>
end

rr(end+1,:) = a('RR-14', 'IMU update rate', 'Hz', 'BODY', ...
    sprintf('>= %.0f floor ; %.0f .. %.0f preferred', k.fc, 4*k.fc, 10*k.fc), ...
    sprintf(['DERIVED: floor = one fresh sample per controller period (%.0f Hz FIXED); the preferred band ' ...
    'is 4x..10x that floor so that ZOH and aliasing margin exist inside the %.3f s tick.'], k.fc, k.Tc), ...
    'TO_BE_IDENTIFIED', 'IMU cadence TO_BE_IDENTIFIED; controller 40 Hz FIXED', 'R5');

rr(end+1,:) = a('RR-15', 'DVL update rate', 'Hz', 'BODY', ...
    sprintf('>= %.3f for gap-free use ; slower admissible only if RR-12 and RR-17 hold', k.fg), ...
    sprintf(['DERIVED: one fresh bottom-lock velocity per guidance period %.3f s (%.3f Hz DERIVED). ' ...
    'A slower sensor is admissible only when the resulting gap is covered by the RR-12 dead-reckoning row ' ...
    'and the RR-17 dropout limit.'], k.Tg, k.fg), ...
    'TO_BE_IDENTIFIED', 'DVL cadence TO_BE_IDENTIFIED; guidance 13.333 Hz DERIVED', 'R5');

rr(end+1,:) = a('RR-16', 'Sensor-to-controller transport delay (sense to actuate), any aiding channel', ...
    'ms', 'end to end', ...
    sprintf('<= %.0f hard ; <= %.0f preferred', k.delay_ms_cases(3), k.delay_ms_cases(2)), ...
    sprintf(['DERIVED: the real-time contract was exercised at %.0f, %.0f and %.0f ms transport delay ' ...
    'plus jitter and held its declared gates; the largest exercised value becomes the hard ceiling and ' ...
    'the middle value the preferred ceiling. No delay beyond the exercised set may be assumed safe.'], ...
    k.delay_ms_cases), ...
    'ASSUMED', 'ASSUMED transport-delay cases {0,15,30} ms + jitter at Gate 6B', 'R5, R7');

rr(end+1,:) = a('RR-17', 'Aiding-channel dropout (DVL bottom-lock loss, heading loss)', ...
    'dimensionless duty and s', 'per channel', ...
    sprintf('max contiguous <= selected T_DR from RR-12 ; cumulative duty <= %.2f', k.alloc_frac), ...
    sprintf(['DERIVED: the contiguous limit is exactly the dead-reckoning horizon that RR-12 and RR-13 ' ...
    'were solved for, so the two rows are consistent by construction; the cumulative duty ceiling is the ' ...
    'ASSUMED %.0f pct allocation used throughout this table.'], k.alloc_frac*100), ...
    'ASSUMED', 'ASSUMED outage profiles; availability manager is status-only and provably inert', 'R5, R3');

rr(end+1,:) = a('RR-18', 'Depth (pressure) sensing error, noise plus residual bias', 'm', 'NED z, positive down', ...
    sprintf('<= %.5f', k.alloc_frac * k.depth_mae_m), ...
    sprintf(['DERIVED: %.0f pct of the frozen baseline grid-mean depth MAE %.6f m, so depth sensing ' ...
    'cannot dominate the depth error the twin already carries.'], k.alloc_frac*100, k.depth_mae_m), ...
    'ASSUMED', sprintf('frozen baseline grid-mean depth MAE %.6f m', k.depth_mae_m), 'R5');

% ---- compute / real time
rr(end+1,:) = a('RR-19', 'Controller task period and relative deadline', 'ms', 'compute', ...
    sprintf('period = %.1f (FIXED) ; deadline <= %.1f', k.Tc*1000, k.Tc*1000), ...
    'DERIVED: transcribed from the frozen ICD clock, controller 40 Hz FIXED, with an implicit deadline equal to the period as declared by the real-time contract.', ...
    'ASSUMED', 'controller 25 ms / 40 Hz FIXED; legacy 37.5 ms is ASSUMED evidence-only and not promoted', 'R7');

rr(end+1,:) = a('RR-20', 'Controller task WCET budget (requirement, never a measurement)', 'ms', 'compute', ...
    sprintf('<= %.2f', 0.5*k.Tc*1000), ...
    sprintf(['DERIVED: half the %.1f ms controller period, leaving the other half for guidance, ' ...
    'navigation, FDIR and RTOS overhead. The host mean of %.3f ms per step is NOT a WCET and must ' ...
    'never be quoted as one.'], k.Tc*1000, k.host_step_ms), ...
    'TO_BE_IDENTIFIED', 'WCET on any target is TO_BE_IDENTIFIED; no timing claim on real silicon exists', ...
    'R7, and TARGET_DEPENDENT until an exact part and board are supplied');

rr(end+1,:) = a('RR-21', 'Guidance task period and WCET budget', 'ms', 'compute', ...
    sprintf('period = %.1f (DERIVED) ; WCET <= %.2f', k.Tg*1000, 0.5*k.Tg*1000), ...
    'DERIVED: guidance cadence 13.333 Hz is itself DERIVED from the frozen PSD marker; the WCET budget is half that period on the same half-period rule as RR-20.', ...
    'ASSUMED', 'guidance 75 ms / 13.333 Hz DERIVED', 'R7');

rr(end+1,:) = a('RR-22', 'Task release jitter', 'ms', 'compute', ...
    sprintf('controller <= %.2f ; guidance <= %.2f', 0.1*k.Tc*1000, 0.1*k.Tg*1000), ...
    'DERIVED: 10 pct of each task period, the same allocation fraction used for the sensing rows, so schedule noise cannot consume the WCET budget.', ...
    'ASSUMED', 'ASSUMED 10 pct allocation; jitter bounds declared per task in the real-time contract', 'R7');

rr(end+1,:) = a('RR-23', 'Deadline overrun handling', 'count and ms', 'compute', ...
    sprintf('every miss accounted ; safe-hold within %.0f ms of the %d-th consecutive miss', ...
    k.safehold_after_miss_ms, k.miss_consecutive), ...
    sprintf(['DERIVED: the overload burst produced %d controller misses, all accounted, with safe-hold ' ...
    'engaged %.0f ms after the %d-th consecutive miss. That observed behaviour becomes the requirement: ' ...
    'no silent miss, deterministic ladder, no auto-surface and no auto-accommodation.'], ...
    k.miss_count, k.safehold_after_miss_ms, k.miss_consecutive), ...
    'ASSUMED', 'ASSUMED overload burst case at Gate 6B', 'R3 (FDIR not re-drawn under MC), R7');

rr(end+1,:) = a('RR-24', 'Total processor utilisation across the declared task set', 'dimensionless', 'compute', ...
    sprintf('<= %.2f', k.util_max), ...
    'DERIVED: an ASSUMED scheduling headroom of 30 pct over the declared five-task set, so that the WCET budgets of RR-20 and RR-21 remain schedulable once mission, navigation and actuator-feedback rates are identified.', ...
    'TO_BE_IDENTIFIED', 'mission / navigation / actuator-feedback rates TO_BE_IDENTIFIED', 'R7, TARGET_DEPENDENT');

rr(end+1,:) = a('RR-25', 'Mission, navigation and actuator-feedback task rates', 'Hz', 'compute and bus', ...
    'TO_BE_IDENTIFIED - no range is issued', ...
    'NOT DERIVED ON PURPOSE: no evidence in the permitted sources constrains these three cadences. Issuing a number here would be manufacture, so the row is published empty and blocking.', ...
    'TO_BE_IDENTIFIED', 'declared TO_BE_IDENTIFIED at Gate 6B and unchanged since', 'R7, R3');
end

% =====================================================================
% verification matrix, Gates 0-8
% =====================================================================
function vm = verification_matrix(g0)
if g0.start_ok; g0s = 'PASS'; else; g0s = 'FAIL'; end
g0n = sprintf('free %.2f GiB on the artifact volume against a 3 GiB start threshold; preferred 5 GiB reserve %s; artifact budget under 3 MiB', ...
    g0.free_gib, ternary(g0.reserve_ok, 'met', 'NOT met, recorded as a note not a waiver'));
vm = { ...
 'Gate 0','artifact_disk_preflight_gate', g0s, g0n, 'this run log'; ...
 'Gate 1','depth_gamma_coupled_plant_identification_gate','PASS', ...
    'speed-scheduled sagittal ID at U={1.0,1.5,2.0}x{level,climb}; trim 6/6, jac 6/6, val 12/12; hydro CI NOT_CLAIMED, hydro coefficients and speed family remain TO_BE_IDENTIFIED', ...
    'DEPTH_GAMMA_SPEED_SCHEDULED_ID.{md,mat,png}'; ...
 'Gate 2','depth_gamma_structural_decoupling_governor_aw_gate','FAIL', ...
    'CLOSED_AFTER_3_ATTEMPTS; attempt 3 primary KPI -68.61 pct against a +5 pct floor; production frozen, acceptance would need an explicit waiver', ...
    'DEPTH_GAMMA_STRUCTURAL_ATTEMPT3.{md,mat,png}'; ...
 'Gate 3','closed_loop_actuator_realism_gate','FAIL', ...
    'CLOSED_AFTER_3_ATTEMPTS on an R10 accepted-baseline parity blocker; all actuator values remain ASSUMED', ...
    'CLOSED_LOOP_ACTUATOR_HARNESS_FINAL record'; ...
 'Gate 4','water_relative_current_feasibility_guidance_gate','WAIVED', ...
    '4A deterministic 32-case map PASS; 4B closed after 3 candidates and two authorised reruns, terminal FAIL on admitted_secondary_within_2pct for RESHAPE rows 22-24; the Gate 4 waiver is OPEN and shadow-only, never promoted', ...
    'WATER_CURRENT_* records'; ...
 'Gate 5','multirate_nav_truth_measured_estimated_ekf_gate','PASS', ...
    'INTERFACE AND INTEGRITY ONLY: 5A 12/12 cases and 22/22 validation gates, 5B 28/28 hard gates with proved truth blindness, 5C 24/24 cases and 32/32 hard gates with a status-only health machine; accuracy is CHARACTERIZATION and NOT_CERTIFIED, every sensor numeric stays ASSUMED', ...
    'NAV_MULTIRATE_* and NAV_AVAILABILITY_* records'; ...
 'Gate 6','propulsion_power_compute_realism_gate','PASS', ...
    'attempt 1 FAIL on tracking at the ideal actuator; the resumed parity fix passed 12/12 gates with 8/8 exact ideal-hook parity; power and energy are component-neutral ranges under an ASSUMED efficiency interval', ...
    'PROPULSION_POWER_COMPUTE_PARITY_FIX.{md,mat,png} (source #2)'; ...
 'Gate 6B','real_time_power_integrity_contract','PASS', ...
    '13/13 declared hard gates over 5 tasks; WCET is a declared budget and not a measurement; mission, navigation and actuator-feedback rates remain TO_BE_IDENTIFIED', ...
    'REAL_TIME_POWER_INTEGRITY_CONTRACT.{md,mat,png} (source #3)'; ...
 'Gate 7','mission_manager_watchdog_fail_silent_gate','PASS', ...
    'simulation scope 17/17 hard gates after the acceptance-criterion repair, with attempt-1 raw behaviour proved identical; 17/17 injected faults detected, 0 false alarms, 0 surface, 0 accommodation, 0 direct-actuator commands', ...
    'GATE7_FDIR_ACCEPTANCE_CRITERION_REPAIR.{md,mat,png}'; ...
 'Gate 8','monte_carlo_distribution_regression_gate','WAIVED', ...
    'WAIVED_WITH_RESIDUAL_RISK_FOR_GATE9_ASSESSMENT and never PASS: three closure attempts failed, HG5 (R10 rail), HG11 (no plant-parameter injection seam), HG12 (FDIR matrix not re-drawn), HG13 (cell geometry ASSUMED_RECONSTRUCTION) all remain open', ...
    'GATE8_* records and the Gate 8 waiver append'};
end

function s = ternary(c, a, b)
if c; s = a; else; s = b; end
end

% =====================================================================
% residual risk register R1-R8
% =====================================================================
function rk = residual_risks()
rk = { ...
 'R1','R10 production rudder rail unresolved','BLOCKER','OPEN', ...
   'Raw rudder demand peaks 466.6729 deg pre-limiter; the plant input pins at the 25.0000 deg envelope for 0.2817 of a 30 s horizon (8.450 s, 12 intervals, longest 2.300 s, first at t = 1.825 s); magnitude dwell 0.8908, rate dwell 0.6917, peak realized slew 40.0000 deg/s. Multi-origin: three contributions each reach the envelope alone, earliest S2_CTRL_TERM_P at t = 1.200 s; windup EXCLUDED_STRUCTURALLY.', ...
   'IMPLEMENTED measurement / unresolved defect','Zero actuator authority margin for current, servo lag, deadband or sensor noise. Directly limits RR-02 and RR-05.'; ...
 'R2','CG / CB / buoyancy priors drawn but never injected','HIGH','OPEN', ...
   'CG/CB +/-2 cm per axis and buoyancy +/-3 pct enter the campaign draw vector and are never applied because no shadow plant-parameter seam exists. HG11 open.', ...
   'ASSUMED prior, UNSUPPORTED','The recorded worst corner does not bound the true worst case, which is why RR-07 and RR-08 carry coverage factors.'; ...
 'R3','Gate 7 FDIR matrix not re-drawn inside Monte Carlo','HIGH','OPEN', ...
   'The 16-case mission-manager and fail-silent matrix that passed 17/17 hard gates was never re-driven through the Monte Carlo loop under the same draws. HG12 open.', ...
   'NOT_EVALUATED under MC','Fault detection, latching, hysteresis and the response ladder are unevidenced under distributed uncertainty. Limits RR-17 and RR-23.'; ...
 'R4','Cell geometry is an ASSUMED_RECONSTRUCTION','MEDIUM','OPEN', ...
   'The eight production cells (X and XZ at U = {1.0,1.5,2.0}, R10 at U = {1.5,2.0}) were reconstructed rather than bound to the frozen cell definitions. HG13 open.', ...
   'ASSUMED_RECONSTRUCTION','Every distributional statement inherits the reconstruction. Limits RR-05.'; ...
 'R5','Estimator streams absent on the Gate 8 path','HIGH','OPEN', ...
   'The Monte Carlo and R10 diagnostic loops run on truth x and y; the Gate 5B and 5C estimator and availability manager were never inserted, so no navigation error propagates into any Gate 8 distribution.', ...
   'NOT_IMPLEMENTED','Every navigation requirement range RR-12 to RR-18 is an allocation against a budget the twin has never actually spent.'; ...
 'R6','Power coverage PARTIAL','MEDIUM','OPEN', ...
   'Thrust-authority derate only; the brownout branch was never entered in any Monte Carlo run, so the real-time power-integrity contract is not distributionally exercised.', ...
   'PARTIAL','Limits RR-08 to RR-11: the power integrity numbers are single-case, not distributional.'; ...
 'R7','Hardware readiness NOT_CERTIFIED','BLOCKER for hardware claims','OPEN', ...
   'No bench, no HIL and no wet data anywhere in the chain. Servo tau, deadband, hysteresis, thruster map, sensor sigma / bias / delay and the mission, navigation and actuator-feedback rates all remain TO_BE_IDENTIFIED.', ...
   'NOT_CERTIFIED / TO_BE_IDENTIFIED','Every range in this document is a requirement to be met by future components, never a statement that any component meets it.'; ...
 'R8','Upstream gate debt carried forward','HIGH','OPEN', ...
   'The Gate 4 waiver remains OPEN and shadow-only; Gate 1 hydro coefficients and the speed family remain TO_BE_IDENTIFIED; Gate 2 and Gate 3 are CLOSED_AFTER_3_ATTEMPTS with actuator values ASSUMED.', ...
   'carried forward','Structural vertical control and closed-loop actuator realism were never closed, so the RC rests on a frozen cascade that three structural attempts failed to improve.'};
end

% =====================================================================
% Pareto vector
% =====================================================================
function pv = pareto_vector()
pv = { ...
 'tracking','pooled cte_max P5/P50/P95/worst = 0.110 / 0.342 / 0.565 / 0.826 m; R10 cell cte max 0.21262 m, median 0.10051 m; grid-mean depth MAE 0.269528 m frozen', ...
   'ACCEPTABLE (bounded, not divergent)','R4, R5'; ...
 'actuator margin','rudder rail dwell 0.2817, magnitude-limiter dwell 0.8908, rate-limiter dwell 0.6917, peak realized slew exactly 40.0000 deg/s, fin moving duty up to 99.7 pct', ...
   'CRITICAL - effectively zero margin','R1 (BLOCKER)'; ...
 'energy','worst-corner 15.59 Wh/km with energy margin +0.896 and peak bus current 6.88 A with current margin +0.541, under an ASSUMED efficiency interval', ...
   'ACCEPTABLE with coverage factors','R2, R6'; ...
 'estimation','interface and integrity only: 18-state error-state EKF with proved truth blindness and a status-only availability machine; accuracy is CHARACTERIZATION; the Gate 8 path used truth x and y', ...
   'OPEN - no accuracy claim exists','R5'; ...
 'timing','controller 25 ms FIXED, guidance 75 ms DERIVED, 13/13 real-time gates; 200 overload misses all accounted; safe-hold 3 ms after the third consecutive miss; host mean 31.919 ms/step is NOT a WCET', ...
   'PARTIAL - budgets declared, never measured on a target','R7, TARGET_DEPENDENT'; ...
 'safety','17/17 FDIR hard gates, 17/17 injected faults detected inside declared bounds, 0 false alarms, 0 missed, 0 surface, 0 accommodation, 0 direct-actuator commands; brownout to safe-hold in 79 ms', ...
   'PASS in simulation scope only','R3, R6'};
end

% =====================================================================
% ICD boundary
% =====================================================================
function icd = icd_boundary()
icd = { ...
 'Mission -> Guidance','MissionCommand / WaypointSet / TrajectorySegment','TO_BE_IDENTIFIED', ...
   'schema_version','t_mono','seq','valid + quality + integrity + validity horizon','heartbeat present, mission stale triggers fail-silent', ...
   'stale age vs declared stale limit','NED','SI (m, m/s, rad)','MISSION.cmd.*','INTERFACE_SPECIFIED, manager NOT_IMPLEMENTED on the runtime path'; ...
 'Guidance -> Controller','course / yaw and depth reference set','13.333 Hz DERIVED (75 ms)', ...
   'schema_version','t_mono','seq','valid + quality','heartbeat at the guidance tick', ...
   'held reference age <= one guidance period (ZOH)','NED course, BODY sideslip','SI (rad, m)','GUID.yaw_ref, GUID.chi_f, GUID.chi_los, GUID.beta', ...
   'IMPLEMENTED and signal-logged: observer vs production yaw_ref closes to 0.000e+00 rad'; ...
 'Navigation -> Controller','StateEstimate (ESTIMATED bus)','40 Hz consumer side; aiding channels multirate', ...
   'schema_version','t_mono','seq','status + source mask + health + covariance','per-channel heartbeat and admission counters', ...
   'per-channel stale age with entry / exit dwell hysteresis','NED position and velocity, BODY rates','SI (m, m/s, rad, rad/s)','EST.x, EST.P, EST.status, EST.health', ...
   'IMPLEMENTED at Gate 5B/5C but NOT_IMPLEMENTED on the Gate 8 path, which used truth x and y (R5)'; ...
 'Controller -> Actuator','FinCommand (elevator, rudder) + thrust demand','40 Hz FIXED (25 ms), ZOH', ...
   'schema_version','t_mono','seq','valid + saturation and rail flags','heartbeat at the controller tick', ...
   'command stale limit, hold-last-safe on expiry','BODY surface deflection','deg for surfaces, native production unit for thrust','CTRL.delta_e, CTRL.delta_r, CTRL.thrust', ...
   'IMPLEMENTED; local magnitude, rate and safety authority overrides mission'; ...
 'Actuator -> Controller (feedback)','ActuatorStatus (position, current, health)','TO_BE_IDENTIFIED', ...
   'schema_version','t_mono','seq','valid + stuck and overcurrent flags','heartbeat, bus timeout monitored', ...
   'stale age drives the actuator monitors','BODY surface deflection','deg, A','ACT.pos, ACT.current, ACT.health', ...
   'INTERFACE_SPECIFIED only; no feedback hardware exists, rate TO_BE_IDENTIFIED (R7)'};
end

% =====================================================================
% external stops
% =====================================================================
function e = external_stops()
e = { ...
 'CAD','Hull and mechanical CAD, fin geometry, servo mounting, pressure housing','NOT STARTED - forbidden before a Gate 9 range set exists, and this range set is issued under a FAIL disposition'; ...
 'PURCHASE','Any vendor selection, part number, quotation or purchase order','FORBIDDEN - this document names no vendor and no part; the ranges are requirements a component must satisfy, never a claim that one does'; ...
 'BENCH / HIL','Servo tau, deadband, hysteresis, current and thermal load; thruster map; processor WCET, memory and jitter on a real target','REQUIRED to convert RR-01 to RR-06 and RR-19 to RR-24 from DERIVED requirements into IDENTIFIED facts'; ...
 'WET','In-water trials, current exposure, bottom-lock behaviour, real disturbance spectra','REQUIRED to close R1 honestly and to replace the ASSUMED current profiles'; ...
 'REAL-DATA SYSTEM ID','Hydrodynamic coefficients, speed family, added mass, restoring, propulsion map, sensor sigma / bias / delay','REQUIRED to upgrade any ASSUMED or TO_BE_IDENTIFIED label to IDENTIFIED; no simulation run can do this'};
end

% =====================================================================
% disposition
% =====================================================================
function d = disposition(vm, rk)
d = struct();
nfail = 0; nwaived = 0;
for i = 1:size(vm,1)
    if strcmp(vm{i,3}, 'FAIL'); nfail = nfail + 1; end
    if strcmp(vm{i,3}, 'WAIVED'); nwaived = nwaived + 1; end
end
nblock = 0;
for i = 1:size(rk,1)
    if ~isempty(strfind(rk{i,3}, 'BLOCKER')) && strcmp(rk{i,4}, 'OPEN'); nblock = nblock + 1; end %#ok<STREMP>
end
d.n_fail = nfail; d.n_waived = nwaived; d.n_open_blockers = nblock;
d.verdict = 'FAIL';
d.rc_tag = 'RC_NOT_GRANTED';
d.reason = sprintf(['zero tolerance applied: %d declared gates are FAIL, %d are WAIVED and not PASS, ' ...
    'and %d residual-risk items are OPEN at BLOCKER severity (R1 R10 rudder rail; R7 hardware NOT_CERTIFIED). ' ...
    'HG11, HG12 and HG13 remain open, so Gate 9 PASS is unavailable by construction.'], nfail, nwaived, nblock);
d.deliverables = 'COMPLETE - the assessment, the manifest, the matrix, the register, the Pareto vector, the ICD boundary and the requirement ranges are all published; only the RC itself is refused.';
end

% =====================================================================
% figures
% =====================================================================
function make_main_figure(p, R)
% PaperPositionMode auto is required: without it print falls back to the
% default 8x6 inch paper and the emitted PNG is far smaller than the figure.
f = figure('Visible', 'off', 'Color', 'w', 'Position', [50 50 2200 1500], ...
    'PaperPositionMode', 'auto', 'InvertHardcopy', 'off');
try
    k = R.k;

    % panel 1 verification matrix
    try
    ax = subplot(3, 3, 1);
    vm = R.vm; n = size(vm, 1);
    val = zeros(n, 1); lbl = cell(n, 1);
    for i = 1:n
        lbl{i} = vm{i,1};
        if strcmp(vm{i,3}, 'PASS')
            val(i) = 3;
        elseif strcmp(vm{i,3}, 'PARTIAL')
            val(i) = 2;
        elseif strcmp(vm{i,3}, 'WAIVED')
            val(i) = 1;
        else
            val(i) = 0;
        end
    end
    b = barh(ax, val, 'FaceColor', 'flat');
    cmap = [0.75 0.15 0.15; 0.85 0.60 0.10; 0.30 0.45 0.80; 0.15 0.60 0.25];
    for i = 1:n; b.CData(i,:) = cmap(val(i)+1, :); end
    set(ax, 'YTick', 1:n, 'YTickLabel', lbl, 'YDir', 'reverse', 'XTick', 0:3, ...
        'XTickLabel', {'FAIL','WAIVED','PARTIAL','PASS'});
    xlim(ax, [0 3.3]); grid(ax, 'on');
    title(ax, 'Verification matrix Gates 0-8', 'FontWeight', 'bold');
    catch pe; fprintf(2, '[FIG p1] %s\n', pe.message); end

    % panel 2 residual risk
    try
    ax = subplot(3, 3, 2);
    rk = R.rk; m = size(rk, 1);
    sev = zeros(m, 1); rl = cell(m, 1);
    for i = 1:m
        rl{i} = rk{i,1};
        s = rk{i,3};
        if ~isempty(strfind(s, 'BLOCKER')); sev(i) = 3; %#ok<STREMP>
        elseif ~isempty(strfind(s, 'HIGH')); sev(i) = 2; %#ok<STREMP>
        else; sev(i) = 1; end
    end
    b = barh(ax, sev, 'FaceColor', 'flat');
    cm2 = [0.55 0.70 0.35; 0.85 0.60 0.10; 0.75 0.15 0.15];
    for i = 1:m; b.CData(i,:) = cm2(sev(i), :); end
    set(ax, 'YTick', 1:m, 'YTickLabel', rl, 'YDir', 'reverse', 'XTick', 1:3, ...
        'XTickLabel', {'MEDIUM','HIGH','BLOCKER'});
    xlim(ax, [0 3.3]); grid(ax, 'on');
    title(ax, 'Residual risk R1-R8 (all OPEN)', 'FontWeight', 'bold');
    catch pe; fprintf(2, '[FIG p2] %s\n', pe.message); end

    % panel 3 pareto
    try
    ax = subplot(3, 3, 3);
    pl = {'tracking','act margin','energy','estimation','timing','safety'};
    ps = [0.70 0.05 0.75 0.15 0.50 0.80];
    b = bar(ax, ps, 'FaceColor', 'flat');
    cm3 = zeros(6, 3);
    for i = 1:6
        if ps(i) < 0.25; cm3(i,:) = [0.75 0.15 0.15];
        elseif ps(i) < 0.60; cm3(i,:) = [0.85 0.60 0.10];
        else; cm3(i,:) = [0.15 0.60 0.25]; end
    end
    b.CData = cm3;
    set(ax, 'XTick', 1:6, 'XTickLabel', pl, 'XTickLabelRotation', 30);
    ylim(ax, [0 1]); grid(ax, 'on'); ylabel(ax, 'assessed adequacy (declared)');
    title(ax, 'Pareto vector (declared, not measured)', 'FontWeight', 'bold');
    catch pe; fprintf(2, '[FIG p3] %s\n', pe.message); end

    % panel 4 actuator dwell
    try
    ax = subplot(3, 3, 4);
    d = [k.mag_dwell k.rate_dwell k.rail_dwell k.fin_duty];
    b = bar(ax, d, 'FaceColor', 'flat');
    b.CData = repmat([0.75 0.15 0.15], 4, 1);
    set(ax, 'XTick', 1:4, 'XTickLabel', {'mag limiter','rate limiter','25 deg rail','fin duty'}, ...
        'XTickLabelRotation', 20);
    ylim(ax, [0 1.05]); grid(ax, 'on'); ylabel(ax, 'dwell fraction of horizon');
    title(ax, 'R1 actuator margin: dwell against the rails', 'FontWeight', 'bold');
    for i = 1:4
        text(ax, i, d(i)+0.03, sprintf('%.4f', d(i)), 'HorizontalAlignment', 'center', 'FontSize', 8);
    end
    catch pe; fprintf(2, '[FIG p4] %s\n', pe.message); end

    % panel 5 deadband derivation
    try
    ax = subplot(3, 3, 5);
    yyaxis(ax, 'left');
    plot(ax, k.db_grid_deg, k.db_rmse_deg, '-o', 'LineWidth', 1.6); ylabel(ax, 'rudder RMSE (deg)');
    yyaxis(ax, 'right');
    plot(ax, k.db_grid_deg, k.db_pct, '-s', 'LineWidth', 1.6); ylabel(ax, 'degradation vs w=0 (pct)');
    hold(ax, 'on');
    plot(ax, [0 max(k.db_grid_deg)], [k.policy_secondary_pct k.policy_secondary_pct], 'k--');
    hold(ax, 'off');
    xlabel(ax, 'ASSUMED deadband width (deg)'); grid(ax, 'on');
    title(ax, 'RR-03 derivation: 2 pct policy band -> <= 0.10 deg', 'FontWeight', 'bold');
    catch pe; fprintf(2, '[FIG p5] %s\n', pe.message); end

    % panel 6 dead reckoning allocations
    try
    ax = subplot(3, 3, 6);
    T = k.T_dr_grid;
    sv = k.alloc_frac * k.cte_p95 ./ T;
    gb = k.alloc_frac * k.heading_err_deg ./ T;
    loglog(ax, T, sv, '-o', 'LineWidth', 1.6); hold(ax, 'on');
    loglog(ax, T, gb, '-s', 'LineWidth', 1.6); hold(ax, 'off');
    grid(ax, 'on'); xlabel(ax, 'ASSUMED dead-reckoning horizon T\_DR (s)');
    legend(ax, {'DVL vel err (m/s)', 'gyro bias (deg/s)'}, 'Location', 'southwest', 'FontSize', 7);
    title(ax, 'RR-12 / RR-13 allocation ranges', 'FontWeight', 'bold');
    catch pe; fprintf(2, '[FIG p6] %s\n', pe.message); end

    % panel 7 power budget with coverage
    try
    ax = subplot(3, 3, 7);
    base = [k.thrust_n k.current_a k.energy_whkm];
    lo = k.cov_cont * base; hi = k.cov_peak * base;
    bb = bar(ax, [base; lo; hi]', 'grouped');
    bb(1).FaceColor = [0.35 0.50 0.75];
    bb(2).FaceColor = [0.85 0.60 0.10];
    bb(3).FaceColor = [0.75 0.15 0.15];
    set(ax, 'XTick', 1:3, 'XTickLabel', {'thrust (N)','current (A)','energy (Wh/km)'}, ...
        'XTickLabelRotation', 15);
    legend(ax, {'worst corner','x1.20 cont','x1.50 peak'}, 'Location', 'northwest', 'FontSize', 7);
    grid(ax, 'on');
    title(ax, 'RR-07 / RR-08 / RR-09 procurement ranges', 'FontWeight', 'bold');
    catch pe; fprintf(2, '[FIG p7] %s\n', pe.message); end

    % panel 8 timing budgets
    try
    ax = subplot(3, 3, 8);
    lblT = {'ctrl period','ctrl WCET','ctrl jitter','guid period','guid WCET','guid jitter','delay hard'};
    v = [k.Tc*1000, 0.5*k.Tc*1000, 0.1*k.Tc*1000, k.Tg*1000, 0.5*k.Tg*1000, 0.1*k.Tg*1000, k.delay_ms_cases(3)];
    b = barh(ax, v, 'FaceColor', [0.30 0.45 0.80]);
    set(ax, 'YTick', 1:numel(v), 'YTickLabel', lblT, 'YDir', 'reverse');
    xlabel(ax, 'ms'); grid(ax, 'on');
    for i = 1:numel(v)
        text(ax, v(i)+1, i, sprintf('%.2f', v(i)), 'FontSize', 7, 'VerticalAlignment', 'middle');
    end
    xlim(ax, [0 max(v)*1.25]);
    title(ax, 'RR-19..RR-22 compute budgets (requirements)', 'FontWeight', 'bold');
    catch pe; fprintf(2, '[FIG p8] %s\n', pe.message); end

    % panel 9 verdict text
    try
    ax = subplot(3, 3, 9); axis(ax, 'off');
    txt = { ...
      sprintf('GATE 9 DISPOSITION: %s  (%s)', R.disp.verdict, R.disp.rc_tag), ...
      '', ...
      sprintf('declared gates FAIL=%d  WAIVED=%d  open BLOCKERs=%d', ...
        R.disp.n_fail, R.disp.n_waived, R.disp.n_open_blockers), ...
      'R1 R10 rudder rail unresolved (BLOCKER)', ...
      'HG11 / HG12 / HG13 open -> Gate 8 WAIVED, never PASS', ...
      '', ...
      'PUBLISHED ANYWAY (deliverables complete):', ...
      '  provenance manifest, verification matrix G0-G8,', ...
      '  residual risk R1-R8, Pareto vector, ICD boundary,', ...
      sprintf('  %d procurement-ready requirement ranges', size(R.rr,1)), ...
      '', ...
      'Every range is DERIVED from an ASSUMED or', ...
      'TO_BE_IDENTIFIED parent. No vendor. No part.', ...
      'No purchase. No hardware certification.', ...
      '', ...
      'HARDWARE READINESS: NOT_CERTIFIED', ...
      '', ...
      'NEXT (exactly one, read-only):', ...
      '  GATE9B_FAST_WHOLE_CODE_EMBEDDED_GAP_AUDIT_001', ...
      'STM32 adaptation remains FORBIDDEN.'};
    text(ax, 0.0, 1.0, txt, 'VerticalAlignment', 'top', 'FontSize', 9, ...
        'FontName', 'Consolas', 'Interpreter', 'none');
    title(ax, 'Release-candidate disposition', 'FontWeight', 'bold');
    catch pe; fprintf(2, '[FIG p9] %s\n', pe.message); end

    annotation(f, 'textbox', [0.02 0.965 0.96 0.032], 'String', ...
        sprintf('GATE9_SIMULATION_RC_ASSESSMENT_001  -  bounded simulation RC assessment  -  %s  -  SIMULATION ONLY, NOT_CERTIFIED', R.t_start), ...
        'EdgeColor', 'none', 'FontWeight', 'bold', 'FontSize', 12, ...
        'HorizontalAlignment', 'center', 'Interpreter', 'none');

    print(f, p, '-dpng', '-r100');
catch ME
    fprintf(2, '[FIG main] %s\n', ME.message);
    try
        print(f, p, '-dpng', '-r100');
    catch
    end
end
close(f);
end

function make_qa_figure(p, R, mainpng)
f = figure('Visible', 'off', 'Color', 'w', 'Position', [50 50 1700 1100], ...
    'PaperPositionMode', 'auto', 'InvertHardcopy', 'off');
try
    ax = subplot(2, 2, 1); axis(ax, 'off');
    L = {'SOURCES READ (exactly 3, no repo scan)'};
    for i = 1:size(R.fp_sources, 1)
        L{end+1} = sprintf('%d %s', i, R.fp_sources{i,1}); %#ok<AGROW>
        L{end+1} = sprintf('   %d B  sha256 %s', R.fp_sources{i,2}, R.fp_sources{i,3}(1:min(32, end))); %#ok<AGROW>
    end
    L{end+1} = '';
    L{end+1} = 'FROZEN INTEGRITY SET (must not change)';
    for i = 1:size(R.fp_pre_integrity, 1)
        L{end+1} = sprintf('   %s  %d B', R.fp_pre_integrity{i,1}, R.fp_pre_integrity{i,2}); %#ok<AGROW>
    end
    text(ax, 0, 1, L, 'VerticalAlignment', 'top', 'FontSize', 8, 'FontName', 'Consolas', 'Interpreter', 'none');
    title(ax, 'QA1 provenance', 'FontWeight', 'bold');

    ax = subplot(2, 2, 2);
    hk = fieldnames(R.harvest);
    hv = zeros(numel(hk), 1);
    for i = 1:numel(hk); hv(i) = R.harvest.(hk{i}).n; end
    barh(ax, hv, 'FaceColor', [0.30 0.45 0.80]);
    set(ax, 'YTick', 1:numel(hk), 'YTickLabel', hk, 'YDir', 'reverse', 'FontSize', 7);
    xlabel(ax, 'matching leaf entries'); grid(ax, 'on');
    title(ax, 'QA2 harvest coverage of the two MAT records', 'FontWeight', 'bold');

    ax = subplot(2, 2, 3); axis(ax, 'off');
    M = {'REQUIREMENT RANGE PARENTAGE AUDIT', ''};
    na = 0; nt = 0;
    for i = 1:size(R.rr, 1)
        if strcmp(R.rr{i,7}, 'ASSUMED'); na = na + 1; end
        if strcmp(R.rr{i,7}, 'TO_BE_IDENTIFIED'); nt = nt + 1; end
    end
    M{end+1} = sprintf('rows total                      : %d', size(R.rr,1));
    M{end+1} = sprintf('parent ASSUMED                  : %d', na);
    M{end+1} = sprintf('parent TO_BE_IDENTIFIED         : %d', nt);
    M{end+1} = sprintf('rows with no admissible parent  : %d', size(R.rr,1) - na - nt);
    M{end+1} = '';
    M{end+1} = 'every row carries unit, frame, source and';
    M{end+1} = 'the residual-risk item that limits it.';
    M{end+1} = '';
    M{end+1} = 'vendor / brand / part-number tokens : 0';
    M{end+1} = 'purchase or certification claims    : 0';
    M{end+1} = '';
    M{end+1} = sprintf('disk preflight free  : %.2f GiB', R.g0.free_gib);
    M{end+1} = sprintf('start threshold 3GiB : %s', tf(R.g0.start_ok));
    M{end+1} = sprintf('reserve  5GiB        : %s', tf(R.g0.reserve_ok));
    text(ax, 0, 1, M, 'VerticalAlignment', 'top', 'FontSize', 9, 'FontName', 'Consolas', 'Interpreter', 'none');
    title(ax, 'QA3 range parentage and hygiene', 'FontWeight', 'bold');

    ax = subplot(2, 2, 4);
    try
        im = imread(mainpng);
        image(ax, im);
        axis(ax, 'image'); axis(ax, 'off');
        title(ax, sprintf('QA4 main panel decoded from disk (%dx%d px)', size(im,2), size(im,1)), 'FontWeight', 'bold');
    catch
        axis(ax, 'off');
        text(ax, 0, 0.5, 'main panel could not be decoded', 'Interpreter', 'none');
        title(ax, 'QA4 main panel decode FAILED', 'FontWeight', 'bold');
    end

    annotation(f, 'textbox', [0.02 0.96 0.96 0.035], 'String', ...
        'GATE9_SIMULATION_RC_ASSESSMENT_001 - visual QA - artifacts decoded from disk after writing', ...
        'EdgeColor', 'none', 'FontWeight', 'bold', 'FontSize', 11, ...
        'HorizontalAlignment', 'center', 'Interpreter', 'none');

    print(f, p, '-dpng', '-r100');
catch ME
    fprintf(2, '[FIG qa] %s\n', ME.message);
    try
        print(f, p, '-dpng', '-r100');
    catch
    end
end
close(f);
end

function q = visual_qa(mainp, qap)
q = struct('main_w', 0, 'main_h', 0, 'main_ink', 0, 'qa_w', 0, 'qa_h', 0, 'qa_ink', 0, 'verdict', 'VISUAL_QA_FAIL');
try
    a = imread(mainp);
    q.main_h = size(a, 1); q.main_w = size(a, 2);
    g = a; if ndims(a) == 3; g = rgb2gray_local(a); end
    q.main_ink = mean(double(g(:)) < 250);
    b = imread(qap);
    q.qa_h = size(b, 1); q.qa_w = size(b, 2);
    g2 = b; if ndims(b) == 3; g2 = rgb2gray_local(b); end
    q.qa_ink = mean(double(g2(:)) < 250);
    ok = q.main_w > 1200 && q.main_h > 800 && q.main_ink > 0.02 && q.main_ink < 0.85 && ...
         q.qa_w > 900 && q.qa_h > 600 && q.qa_ink > 0.02 && q.qa_ink < 0.85;
    if ok; q.verdict = 'VISUAL_QA_PASS'; end
catch ME
    q.verdict = ['VISUAL_QA_FAIL: ' ME.message];
end
end

function g = rgb2gray_local(a)
a = double(a);
g = uint8(0.299*a(:,:,1) + 0.587*a(:,:,2) + 0.114*a(:,:,3));
end

% =====================================================================
% markdown report
% =====================================================================
function write_md(p, R)
fid = fopen(p, 'w', 'n', 'UTF-8');
if fid < 0; error('cannot open %s', p); end
c = onCleanup(@() fclose(fid)); %#ok<NASGU>
% NOTE: the rendered text is emitted through %s so that content containing
% percent signs or backslashes can never be re-interpreted as a format.
w = @(varargin) fprintf(fid, '%s\n', sprintf(varargin{:}));
k = R.k;

w('# GATE9_SIMULATION_RC_ASSESSMENT - Gate 9 simulation release-candidate assessment');
w('');
w('**Task:** `GATE9_SIMULATION_RC_ASSESSMENT_001` | **Date:** %s | **Class:** bounded read-only evidence and range assembly | **MATLAB invocations:** 1 | **New simulation campaign:** NONE | **Method retry:** NONE | **Repo scan:** NONE', R.t_start);
w('');
w('## VERDICT');
w('');
w('**Gate 9 disposition: `%s` (`%s`).**', R.disp.verdict, R.disp.rc_tag);
w('');
w('%s', R.disp.reason);
w('');
w('**Deliverables:** %s', R.disp.deliverables);
w('');
w('**Physical / hardware readiness: `NOT_CERTIFIED`.** Nothing in this document certifies any component, any timing on any processor, or any wet behaviour. Every requirement range is a specification that a future component must be shown to meet; none of them is a statement that a component meets it. No vendor, brand, part number, quotation or purchase is named, implied or recommended anywhere.');
w('');
w('---');
w('');

% 1 provenance
w('## 1. Reproducibility and provenance manifest');
w('');
w('### 1.1 Sources read (exactly 3, no repo scan)');
w('');
w('| # | Path | Role | Bytes | SHA-256 | n.s1.s2 |');
w('|---|------|------|-------|---------|---------|');
roles = {'Gate order, waiver rule, full gate history, frozen production anchors (transcribed constants)', ...
         'Gate 6 propulsion / power / compute parity record (loaded and introspected in this run)', ...
         'Gate 6B real-time and power-integrity contract (loaded and introspected in this run)'};
for i = 1:size(R.fp_sources, 1)
    w('| %d | `%s` | %s | %d | `%s` | `%s` |', i, fwd(R.fp_sources{i,1}), roles{i}, ...
        R.fp_sources{i,2}, R.fp_sources{i,3}, R.fp_sources{i,4});
end
w('');
w('No other evidence file was opened for content. The four files in the integrity set below were opened **only to hash them**, before and after every write, to prove they were not modified.');
w('');
w('### 1.2 Frozen integrity set (production + CODEX), unchanged across this run');
w('');
w('| Path | Bytes | SHA-256 before | SHA-256 after | Unchanged |');
w('|------|-------|----------------|---------------|-----------|');
for i = 1:size(R.fp_pre_integrity, 1)
    same = strcmp(R.fp_pre_integrity{i,3}, R.fp_post_integrity{i,3});
    w('| `%s` | %d | `%s` | `%s` | **%s** |', fwd(R.fp_pre_integrity{i,1}), R.fp_pre_integrity{i,2}, ...
        short(R.fp_pre_integrity{i,3}), short(R.fp_post_integrity{i,3}), tf(same));
end
w('');
w('**Production and `CODEX_VERTICAL_PLAN.md` untouched: %s.** The hashes above are taken before any work and again after all computation and figure emission. A third verification is taken after the document appends and is recorded in `GATE9_SIMULATION_RC_ASSESSMENT_run.log`; the integrity set is disjoint from every file this task writes.', tf(R.integrity_ok));
w('');
w('### 1.3 Frozen seeds, solver and cadences');
w('');
w('| Item | Value | Label |');
w('|------|-------|-------|');
w('| Monte Carlo seed | `%d` | ASSUMED, frozen at the Gate 8 campaign |', k.seed);
w('| Draw vectors x cells | %d x %d = %d runs | ASSUMED |', k.draws, k.cells, k.mc_runs);
w('| Replay draws (determinism sentinels) | [%d %d %d] | IMPLEMENTED |', k.replay_draws);
w('| Integration step | dt = %.4f s, T_final = %g s, fixed step | ASSUMED |', k.dt_mc, k.T_final);
w('| Controller cadence | %.4f s / %.1f Hz | **FIXED** |', k.Tc, k.fc);
w('| Guidance cadence | %.4f s / %.3f Hz (PSD marker) | **DERIVED** |', k.Tg, k.fg);
w('| Legacy controller step | %.4f s | ASSUMED evidence-only, never promoted |', k.Tc_legacy);
w('| Mission / navigation / actuator-feedback cadence | not issued | **TO_BE_IDENTIFIED** |');
w('| Controller calls in the Gate 6 budget run | %d | IMPLEMENTED |', k.controller_calls);
w('| Plant RHS evaluations in the Gate 6 budget run | %d | IMPLEMENTED |', k.plant_rhs);
w('| R10 nominal reproduction fingerprint | `%s` | IMPLEMENTED, reproduced across production, hooks-off replica and instrumented replica |', k.r10_fp);
w('');
w('### 1.4 Reproducibility assessment (from accepted evidence, not re-run here)');
w('');
w('Bit-reproducibility is **evidenced** at every point where it was tested: exact nominal parity between the hooks-off shadow path and unmodified `continuous_path_tracking.m` in 8/8 cells; bitwise deterministic reverse-order replay and first/last reset sentinels in every Gate 5, 6, 7 and 8 record; the R10 cell reproducing the same fingerprint across three independent code paths; cross-process reproduction of the Gate 5B estimator; and 16/16 parity records identical with a largest observed difference of 0.000e+00 at the Gate 5C revalidation.');
w('');
w('That is necessary but not sufficient for a release candidate. Reproducibility proves the twin computes the same thing twice; it says nothing about whether what it computes is physically right. The physical question is answered by the residual-risk register in section 3, and the answer is that it is not yet answered.');
w('');
w('### 1.5 Introspection of the two loaded records');
w('');
w('| Record | Top-level variables | Flattened leaf entries |');
w('|--------|--------------------:|-----------------------:|');
f2 = fieldnames(R.s2); f3 = fieldnames(R.s3);
n2 = 0; n3 = 0;
for i = 1:size(R.inventory,1)
    if strncmp(R.inventory{i,1}, 'S2', 2); n2 = n2 + 1; else; n3 = n3 + 1; end
end
w('| `PROPULSION_POWER_COMPUTE_PARITY_FIX.mat` | %d | %d |', numel(f2), n2);
w('| `REAL_TIME_POWER_INTEGRITY_CONTRACT.mat` | %d | %d |', numel(f3), n3);
w('');
if ~isempty(R.s2_err); w('Load warning, source 2: `%s`', R.s2_err); w(''); end
if ~isempty(R.s3_err); w('Load warning, source 3: `%s`', R.s3_err); w(''); end
w('Harvest probe coverage over those leaves (used to check that a number quoted below actually exists in the records rather than only in prose):');
w('');
w('| Probe | Matching leaves | First match |');
w('|-------|----------------:|-------------|');
hk = fieldnames(R.harvest);
for i = 1:numel(hk)
    h = R.harvest.(hk{i});
    w('| `%s` | %d | `%s` |', hk{i}, h.n, md_escape(h.first));
end
w('');
w('---');
w('');

% 2 verification matrix
w('## 2. Verification matrix, Gates 0-8');
w('');
w('| Gate | ID | Status | Evidence summary | Evidence link |');
w('|------|----|--------|------------------|---------------|');
for i = 1:size(R.vm, 1)
    w('| **%s** | `%s` | **%s** | %s | `%s` |', R.vm{i,1}, R.vm{i,2}, R.vm{i,3}, ...
        md_escape(R.vm{i,4}), R.vm{i,5});
end
w('');
w('**Status vocabulary is exactly as declared upstream.** `WAIVED` is not `PASS` and is never to be transcribed as one. Gate 8 in particular is `WAIVED_WITH_RESIDUAL_RISK_FOR_GATE9_ASSESSMENT`: the waiver unlocked this bounded assessment and nothing else.');
w('');
w('---');
w('');

% 3 residual risk
w('## 3. Residual-risk register R1-R8 (first-class Gate 9 output)');
w('');
w('| # | Risk | Severity | State | Evidence | Label | Consequence for this RC |');
w('|---|------|----------|-------|----------|-------|--------------------------|');
for i = 1:size(R.rk, 1)
    w('| **%s** | %s | **%s** | %s | %s | `%s` | %s |', R.rk{i,1}, R.rk{i,2}, R.rk{i,3}, ...
        R.rk{i,4}, md_escape(R.rk{i,5}), R.rk{i,6}, md_escape(R.rk{i,7}));
end
w('');
w('---');
w('');

% 4 pareto
w('## 4. Pareto vector');
w('');
w('| Axis | Evidenced position | Assessment | Limiting risk |');
w('|------|--------------------|------------|---------------|');
for i = 1:size(R.pv, 1)
    w('| **%s** | %s | **%s** | %s |', R.pv{i,1}, md_escape(R.pv{i,2}), R.pv{i,3}, R.pv{i,4});
end
w('');
w('The vector is not balanced. Energy, safety and tracking sit in acceptable territory while actuator margin is effectively zero and estimation contributes nothing at all to the distribution. A release candidate declared on this shape would be a candidate whose only comfortable axes are the ones that were actually exercised.');
w('');
w('---');
w('');

% 5 ICD
w('## 5. ICD boundary: Mission -> Guidance -> Navigation -> Controller -> Actuator');
w('');
w('| Boundary | Message set | Cadence | Version key | Timestamp key | Sequence key | Validity keys | Heartbeat | Stale rule | Frame | Unit | Twin-log key | Maturity |');
w('|----------|-------------|---------|-------------|---------------|--------------|---------------|-----------|------------|-------|------|--------------|----------|');
for i = 1:size(R.icd, 1)
    w('| **%s** | %s | %s | `%s` | `%s` | `%s` | %s | %s | %s | %s | %s | `%s` | %s |', ...
        R.icd{i,1}, R.icd{i,2}, R.icd{i,3}, R.icd{i,4}, R.icd{i,5}, R.icd{i,6}, ...
        R.icd{i,7}, R.icd{i,8}, R.icd{i,9}, R.icd{i,10}, R.icd{i,11}, R.icd{i,12}, md_escape(R.icd{i,13}));
end
w('');
w('Two standing rules of this boundary are unchanged and are restated because the requirement ranges depend on them: local magnitude, rate and safety authority **overrides mission**, and a stale mission input results in **fail-silent**, never an automatic surface and never an automatic accommodation.');
w('');
w('---');
w('');

% 6 requirement ranges
w('## 6. Procurement-ready component requirement RANGES');
w('');
w('**Reading rule.** Each row is a requirement expressed as a range, `DERIVED` in this document from a parent that is either `ASSUMED` or `TO_BE_IDENTIFIED`. The parent column names that parent and the label column gives its provenance. No row names a vendor, a brand, a part number or a price, and no row asserts that any component satisfies it. A range is closed only by bench, HIL, wet or real-data identification, all of which are EXTERNAL to this plan.');
w('');
w('| ID | Parameter | Unit | Frame / axis | **Range** | Derivation | Parent label | Parent / source | Limiting risk |');
w('|----|-----------|------|--------------|-----------|------------|--------------|------------------|---------------|');
for i = 1:size(R.rr, 1)
    w('| `%s` | %s | %s | %s | **%s** | %s | `%s` | %s | %s |', ...
        R.rr{i,1}, md_escape(R.rr{i,2}), md_escape(R.rr{i,3}), md_escape(R.rr{i,4}), ...
        md_escape(R.rr{i,5}), md_escape(R.rr{i,6}), R.rr{i,7}, md_escape(R.rr{i,8}), md_escape(R.rr{i,9}));
end
w('');
na = 0; nt = 0;
for i = 1:size(R.rr,1)
    if strcmp(R.rr{i,7}, 'ASSUMED'); na = na + 1; end
    if strcmp(R.rr{i,7}, 'TO_BE_IDENTIFIED'); nt = nt + 1; end
end
w('**Parentage audit:** %d rows total, %d with an `ASSUMED` parent, %d with a `TO_BE_IDENTIFIED` parent, **%d rows with no admissible parent**. Two rows deliberately publish no number: `RR-06` because the thruster variant time constants are not quoted in the permitted sources, and `RR-25` because nothing in the permitted sources constrains the mission, navigation or actuator-feedback cadences. Inventing either would be manufacture.', ...
    size(R.rr,1), na, nt, size(R.rr,1) - na - nt);
w('');
w('---');
w('');

% 7 external stops
w('## 7. Explicit EXTERNAL stops');
w('');
w('| Stop | Scope | Status |');
w('|------|-------|--------|');
for i = 1:size(R.ext, 1)
    w('| **%s** | %s | %s |', R.ext{i,1}, md_escape(R.ext{i,2}), md_escape(R.ext{i,3}));
end
w('');
w('---');
w('');

% 8 hygiene
w('## 8. Task hygiene and claim boundary');
w('');
w('| Constraint | Result |');
w('|------------|--------|');
w('| Sources read | exactly 3, listed in section 1.1, no repo scan |');
w('| MATLAB invocations | 1 (this run), used only to read the two records and emit artifacts |');
w('| New simulation campaign | NONE |');
w('| Method retry | NONE; every closed method stays closed |');
w('| Production / controller / guidance edits | NONE, proved by hash before and after |');
w('| `CODEX_VERTICAL_PLAN.md` | untouched, proved by hash before and after |');
w('| Label upgrades | NONE |');
w('| Accepted evidence | preserved; nothing deleted, nothing overwritten |');
w('| Vendor / brand / part / purchase claims | NONE |');
w('| Hardware certification claims | NONE - `NOT_CERTIFIED` throughout |');
w('| Disk preflight | free %.2f GiB, 3 GiB start threshold %s, 5 GiB preferred reserve %s |', ...
    R.g0.free_gib, tf(R.g0.start_ok), tf(R.g0.reserve_ok));
w('| Visual QA | %s (main %dx%d px ink %.3f, QA %dx%d px ink %.3f, both decoded from disk after writing) |', ...
    R.visual_qa.verdict, R.visual_qa.main_w, R.visual_qa.main_h, R.visual_qa.main_ink, ...
    R.visual_qa.qa_w, R.visual_qa.qa_h, R.visual_qa.qa_ink);
w('');
w('### Why this is a FAIL and not a PARTIAL');
w('');
w('The zero-tolerance rule is explicit: an unresolved hard safety gate prevents a Gate 9 PASS, and the declared matrix must be reported exactly as it stands. Of the %d declared rows, %d are **FAIL** and %d are **WAIVED** and therefore not PASS, and the residual-risk register carries %d open **BLOCKER** items - R1, which removes essentially all actuator authority margin on one production cell, and R7, which is the standing hardware boundary. A PARTIAL would imply that the release candidate is partially granted. It is not granted at all. What is complete is the assessment, not the candidate.', ...
    size(R.vm,1), R.disp.n_fail, R.disp.n_waived, R.disp.n_open_blockers);
w('');
w('This is the outcome the Gate 8 waiver predicted in writing before the work began, and recording it honestly is the deliverable.');
w('');
w('### Files created or changed by this task');
w('');
cf = changed_files('GATE9_SIMULATION_RC_ASSESSMENT');
for i = 1:numel(cf)
    w('- `%s`', strtrim(cf{i}));
end
w('');
w('The four appended documents receive one marker-guarded append each and are never rewritten. Every other file in `suite_results/` is untouched.');
w('');
w('---');
w('');
w('## 9. Next task (exactly one)');
w('');
w('**`GATE9B_FAST_WHOLE_CODE_EMBEDDED_GAP_AUDIT_001`** - read-only fast whole-code embedded-readiness gap audit over checklist A1-A13. Evidence is read, never re-executed; closed dead-ends are read as evidence only. Every finding is classified `BLOCKER` / `TARGET_DEPENDENT` / `EXTERNAL_HIL` / `COSMETIC`. Its own PASS bar is unchanged and not relaxed, so an audit over a FAIL RC will normally report BLOCKERs and therefore not PASS Gate 9B.');
w('');
w('**STM32 adaptation remains FORBIDDEN.** The terminus `AWAIT_STM32_EXACT_PART_NUMBER` stands: target-specific work may begin only when the user supplies the exact part number and board **and** every unresolved blocker (R1-R8 plus any Gate 9B BLOCKER) is explicitly dispositioned as fixed, waived with written residual risk, `TARGET_DEPENDENT` or `EXTERNAL_HIL`. No processor is selected, guessed, recommended or implied.');
w('');
w('---');
w('');

% appendix inventory
w('## Appendix A - full leaf inventory of the two loaded records');
w('');
w('Published so that every number quoted above can be traced to a stored field, and so that the two rows that publish no number can be shown to have no stored source rather than an overlooked one.');
w('');
w('| Leaf | Class | Size | Summary |');
w('|------|-------|------|---------|');
nmax = min(size(R.inventory, 1), 1200);
for i = 1:nmax
    w('| `%s` | %s | %s | %s |', R.inventory{i,1}, R.inventory{i,2}, R.inventory{i,3}, ...
        md_escape(trunc(R.inventory{i,4}, 130)));
end
if size(R.inventory, 1) > nmax
    w('');
    w('*(%d further leaves omitted from the table; the complete inventory is stored in `%s.mat` under `Gate9.inventory`.)*', ...
        size(R.inventory,1) - nmax, 'GATE9_SIMULATION_RC_ASSESSMENT');
end
w('');
if ~isempty(R.fatal_error)
    w('## Appendix B - recorded error');
    w('');
    w('```');
    w('%s', R.fatal_error);
    w('```');
end
end

function s = md_escape(c)
if isnumeric(c) || islogical(c)
    c = num2str(c);
elseif ~ischar(c)
    c = char(c);
end
s = strrep(c, '|', '\|');
s = regexprep(s, '\s+', ' ');
end

function s = fwd(c)
s = strrep(c, '\', '/');
end

% =====================================================================
% appends
% =====================================================================
function out = do_appends(SR, R)
marker = 'APPEND_MARKER:GATE9_SIMULATION_RC_ASSESSMENT_001';
targets = { ...
    'AUV_REALIZATION_READINESS_PLAN.md',  'plan / readiness log'; ...
    'AUTONOMOUS_EXECUTION_POLICY.md',     'policy'; ...
    'AUV_REALISM_AND_VISUAL_VALIDATION.md','realism log'; ...
    'PITCH_CONTROL_RESEARCH_LOG.md',      'research log'};
out = cell(size(targets,1), 2);
body = append_body(R, marker);
for i = 1:size(targets,1)
    p = fullfile(SR, targets{i,1});
    out{i,1} = targets{i,1};
    if exist(p, 'file') ~= 2
        out{i,2} = 'SKIPPED (missing)';
        continue;
    end
    txt = fileread(p);
    if ~isempty(strfind(txt, marker)) %#ok<STREMP>
        out{i,2} = 'SKIPPED (marker already present, not appended twice)';
        continue;
    end
    fid = fopen(p, 'a', 'n', 'UTF-8');
    if fid < 0
        out{i,2} = 'FAILED (cannot open for append)';
        continue;
    end
    fprintf(fid, '%s', body);
    fclose(fid);
    out{i,2} = sprintf('APPENDED as %s', targets{i,2});
end
end

function s = append_body(R, marker)
k = R.k;
L = {};
L{end+1} = '';
L{end+1} = '';
L{end+1} = ['<!-- ' marker ' -->'];
L{end+1} = '';
L{end+1} = '## Append: GATE9_SIMULATION_RC_ASSESSMENT_001 (Gate 9 disposition)';
L{end+1} = '';
L{end+1} = sprintf('**Date:** %s | **Class:** bounded read-only Gate 9 RC assessment and evidence-range assembly | **MATLAB runs:** 1 | **New campaign:** NONE | **Method retry:** NONE | **Repo scan:** NONE | **Production/CODEX:** byte-identical | **HW:** **NOT_CERTIFIED**', R.t_start);
L{end+1} = '';
L{end+1} = sprintf('**Verdict: `%s` (`%s`). Gate 9 is NOT PASS and must never be transcribed as PASS.**', R.disp.verdict, R.disp.rc_tag);
L{end+1} = '';
L{end+1} = sprintf('- **Zero tolerance applied.** %s', R.disp.reason);
L{end+1} = '- **Sources read: exactly 3, no repo scan** - `suite_results/AUV_REALIZATION_READINESS_PLAN.md`, `suite_results/PROPULSION_POWER_COMPUTE_PARITY_FIX.mat`, `suite_results/REAL_TIME_POWER_INTEGRITY_CONTRACT.mat`. The two MAT records were loaded and introspected in this run; the plan supplied transcribed constants. Every other file named below is dereferenced from the plan record, not re-read and not re-run.';
L{end+1} = sprintf('- **Verification matrix Gates 0-8 as declared:** Gate 0 %s, Gate 1 PASS, Gate 2 FAIL (CLOSED_AFTER_3_ATTEMPTS), Gate 3 FAIL (CLOSED_AFTER_3_ATTEMPTS), Gate 4 WAIVED (4A PASS, 4B closed FAIL, shadow-only), Gate 5 PASS (interface and integrity only, accuracy CHARACTERIZATION), Gate 6 PASS, Gate 6B PASS, Gate 7 PASS (simulation scope), Gate 8 WAIVED_WITH_RESIDUAL_RISK_FOR_GATE9_ASSESSMENT and never PASS.', R.vm{1,3});
L{end+1} = '- **Residual risk R1-R8 published as a first-class output, all OPEN.** R1 R10 rudder rail (BLOCKER, raw demand 466.6729 deg, rail dwell 0.2817, magnitude dwell 0.8908, rate dwell 0.6917, peak slew 40.0000 deg/s) - R2 CG/CB and buoyancy priors drawn but never injected (HG11) - R3 Gate 7 FDIR matrix not re-drawn under MC (HG12) - R4 cell geometry ASSUMED_RECONSTRUCTION (HG13) - R5 estimator streams NOT_IMPLEMENTED on the Gate 8 path - R6 power coverage PARTIAL, brownout branch never entered - R7 hardware NOT_CERTIFIED, actuator and sensor numerics TO_BE_IDENTIFIED - R8 upstream gate debt (Gate 4 waiver open, Gates 2 and 3 closed after three attempts).';
L{end+1} = '- **Pareto vector:** tracking ACCEPTABLE (pooled cte_max P50 0.342 m, P95 0.565 m) - actuator margin **CRITICAL, effectively zero** - energy ACCEPTABLE with coverage factors (15.59 Wh/km, 6.88 A peak) - estimation **OPEN, no accuracy claim** - timing PARTIAL (budgets declared, never measured on a target) - safety PASS in simulation scope only (17/17 FDIR, 0 false alarms, 0 surface, 0 accommodation).';
L{end+1} = '- **ICD boundary Mission -> Guidance -> Navigation -> Controller -> Actuator** tabulated with version, timestamp, sequence, validity/quality/integrity, heartbeat, stale rule, frame, unit and twin-log key per boundary. Local magnitude, rate and safety authority overrides mission; stale mission means fail-silent, never auto-surface and never auto-accommodation.';
L{end+1} = sprintf('- **Procurement-ready requirement RANGES: %d rows**, covering servo tau / rate / deadband / resolution / envelope, thruster lag and thrust, bus current, energy per km, source impedance and hold-up, DVL and IMU error against an ASSUMED dead-reckoning horizon grid, sensor cadence, transport delay, dropout, depth sensing, and compute period / deadline / WCET / jitter / overrun / utilisation. Every row is `DERIVED` from an `ASSUMED` or `TO_BE_IDENTIFIED` parent and carries unit, frame, source and limiting risk. **No vendor, brand, part number or purchase claim appears anywhere.** Two rows publish no number on purpose: `RR-06` (thruster variant time constants are not quoted in the permitted sources) and `RR-25` (mission, navigation and actuator-feedback cadences are unconstrained by any permitted source).', size(R.rr,1));
L{end+1} = sprintf('- **Selected ranges, for the record.** Servo tau %.4f..%.3f s - servo rate %.0f..%.0f deg/s with a %.0f deg/s hard floor - deadband plus backlash 0..%.2f deg - continuous thrust >= %.3f N, peak >= %.3f N - bus current continuous >= %.3f A, peak >= %.3f A - energy %.3f..%.3f Wh/km - source impedance <= %.5f ohm per volt of nominal bus - hold-up >= %.0f ms - controller WCET <= %.2f ms, jitter <= %.2f ms - guidance WCET <= %.2f ms, jitter <= %.2f ms - transport delay <= %.0f ms hard.', ...
    0.5*k.Tc, 4*k.Tc, 2*k.rate_dps, 4*k.rate_dps, k.rate_dps, k.db_grid_deg(2), ...
    k.cov_cont*k.thrust_n, k.cov_peak*k.thrust_n, k.cov_cont*k.current_a, k.cov_peak*k.current_a, ...
    k.cov_cont*k.energy_whkm, k.cov_peak*k.energy_whkm, ...
    (1-k.brownout_trigger_pu)/(k.cov_peak*k.current_a), ceil(k.safehold_ms*1.25/10)*10, ...
    0.5*k.Tc*1000, 0.1*k.Tc*1000, 0.5*k.Tg*1000, 0.1*k.Tg*1000, k.delay_ms_cases(3));
L{end+1} = '- **Reproducibility is evidenced, physical validity is not.** Exact nominal parity in 8/8 cells, bitwise reverse-order replay everywhere it was tested, the R10 fingerprint `n=153600.s1=19094896.s2=2901292177` reproduced across three code paths, and cross-process reproduction of the Gate 5B estimator. That proves the twin computes the same thing twice; it says nothing about whether what it computes is physically right, which is precisely what R1-R8 leave open.';
L{end+1} = '- **EXTERNAL stops recorded explicitly:** hull and mechanical CAD NOT STARTED; vendor purchase FORBIDDEN; bench and HIL REQUIRED to convert the actuator, propulsion and compute rows into identified facts; wet trials REQUIRED to close R1 honestly; real-data system identification REQUIRED before any `ASSUMED` or `TO_BE_IDENTIFIED` label can become `IDENTIFIED`.';
L{end+1} = sprintf('- **Preserved.** Production `continuous_path_tracking.m`, `controller_law.m`, `guidance_law.m` and `CODEX_VERTICAL_PLAN.md` are byte- and SHA-256-identical before and after this run (%s). No accepted evidence artifact was deleted, overwritten or re-labelled. No gain, law, path, threshold, shaper or feedforward was touched. No closed method was retried.', tf(R.integrity_ok));
L{end+1} = sprintf('- **Evidence:** `suite_results/GATE9_SIMULATION_RC_ASSESSMENT.{md,mat,png}` plus `suite_results/GATE9_SIMULATION_RC_ASSESSMENT_qa.png` and `suite_results/GATE9_SIMULATION_RC_ASSESSMENT_run.log`. Visual QA verdict %s.', R.visual_qa.verdict);
L{end+1} = '- **Next exact task (exactly one):** `GATE9B_FAST_WHOLE_CODE_EMBEDDED_GAP_AUDIT_001` - read-only fast whole-code embedded-readiness gap audit over A1-A13, every finding classified BLOCKER / TARGET_DEPENDENT / EXTERNAL_HIL / COSMETIC, evidence read and never re-executed. Its PASS bar is unchanged, so an audit over a FAIL RC will normally report BLOCKERs and not PASS.';
L{end+1} = '- **STM32 adaptation remains FORBIDDEN** pending both the exact part number and board and an explicit disposition of every unresolved blocker. No processor is selected, guessed, recommended or implied. Simulation is not hardware certification (**NOT_CERTIFIED**).';
L{end+1} = '';
s = strjoin(L, sprintf('\n'));
end

function cf = changed_files(BASE)
cf = { ...
    ['suite_results/' BASE '.md            (created)']; ...
    ['suite_results/' BASE '.mat           (created)']; ...
    ['suite_results/' BASE '.png           (created)']; ...
    ['suite_results/' BASE '_qa.png        (created)']; ...
    ['suite_results/' BASE '_run.log       (created)']; ...
    'suite_results/AUV_REALIZATION_READINESS_PLAN.md   (appended)'; ...
    'suite_results/AUTONOMOUS_EXECUTION_POLICY.md      (appended)'; ...
    'suite_results/AUV_REALISM_AND_VISUAL_VALIDATION.md(appended)'; ...
    'suite_results/PITCH_CONTROL_RESEARCH_LOG.md       (appended)'; ...
    'run_gate9_simulation_rc_assessment.m              (created, this driver)'};
end
