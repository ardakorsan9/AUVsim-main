function run_gate7_fdir_acceptance_criterion_repair()
%RUN_GATE7_FDIR_ACCEPTANCE_CRITERION_REPAIR
%  TASK_ID GATE7_FDIR_ACCEPTANCE_CRITERION_REPAIR_001
%
%  Gate 7, attempt 2. This driver repairs ONLY the acceptance semantics that
%  the prior PARTIAL run exposed. It does NOT change any method, scenario,
%  threshold, injection window, monitor, plant surrogate, or clock.
%
%  Two acceptance defects are repaired:
%    (1) HG8 compared a binary `expect_recover` flag against a `recovered`
%        observable that is trivially true for a case that never degrades.
%        The expectation becomes three-valued:
%          must_recover / must_not_recover / not_applicable_no_degradation
%        S01 NOMINAL and S14 CONFOUNDER_BENIGN are not_applicable and must
%        still show zero trips, zero episodes, zero degraded dwell.
%    (2) detect-to-action was "time to the NEXT mode change", which is wrong
%        when a higher-precedence response is already in force. It becomes
%        "time until the active response severity is >= the severity this
%        monitor requires"; an already-active higher-severity response counts
%        as an immediate (zero) action gap.
%
%  Everything else is re-executed identically and compared bit-for-bit
%  against the prior MAT: frozen case inputs, event schedule, thresholds,
%  output time series, per-case hashes, and every unaffected metric.
%
%  Evidence labels (unchanged):
%    IMPLEMENTED         - this harness (simulation) and its monitors
%    INTERFACE_SPECIFIED - the message contract / ICD fields it exercises
%    ASSUMED             - every numeric fault schedule / threshold placeholder
%    TO_BE_IDENTIFIED    - mission / nav / actuator-feedback rates
%    NOT_CERTIFIED       - all hardware / HIL claims
%
%  Sources (exactly 3, frozen, no repo scan):
%    run_gate7_mission_manager_fail_silent_sim.m
%    suite_results/GATE7_MISSION_MANAGER_FAIL_SILENT_SIM.mat
%    suite_results/GATE7_MISSION_MANAGER_FAIL_SILENT_SIM.md

t_host = tic;
TAG = 'GATE7_FDIR_ACCEPTANCE_CRITERION_REPAIR';
SR  = 'suite_results';
set(0,'DefaultFigureVisible','off');
logf = fullfile(SR,[TAG '_run.log']);
if exist(logf,'file'); delete(logf); end
diary(logf); diary on;
fprintf('=== TASK GATE7_FDIR_ACCEPTANCE_CRITERION_REPAIR_001 ===\n');
try
    g7r_main(TAG, SR, t_host);
catch ME
    fprintf(2,'\nFATAL ERROR: %s\n', ME.message);
    for ii = 1:numel(ME.stack)
        fprintf(2,'   in %s at line %d\n', ME.stack(ii).name, ME.stack(ii).line);
    end
    fid = fopen(fullfile(SR,[TAG '.md']),'w');
    if fid > 0
        fprintf(fid,'# %s\n\n**Verdict: FAIL (harness error, simulation-only)**\n\n', TAG);
        fprintf(fid,'Error: `%s`\n\nSee `%s` for the full trace.\n', ME.message, [TAG '_run.log']);
        fclose(fid);
    end
end
diary off;
end

% ======================================================================
function g7r_main(TAG, SR, t_host)

free_gib = NaN;
try
    free_gib = double(java.io.File(pwd).getFreeSpace())/2^30;
catch
end
fprintf('Gate0 preflight: free space %.3f GiB\n', free_gib);

R = struct();
R.task_id       = 'GATE7_FDIR_ACCEPTANCE_CRITERION_REPAIR_001';
R.gate          = 'Gate 7 attempt 2 (acceptance-criterion repair + identical re-run)';
R.created       = datestr(now,'yyyy-mm-dd HH:MM:SS');
R.certification = 'NOT_CERTIFIED (simulation-only; no HIL, no bench, no hardware)';
R.honesty       = 'IMPLEMENTED = this isolated harness only. Message contract = INTERFACE_SPECIFIED. Production untouched. Acceptance semantics repaired; no method/scenario/threshold/window/plant change.';
R.free_gib_at_start = free_gib;
R.prior_tag     = 'GATE7_MISSION_MANAGER_FAIL_SILENT_SIM';

%% ---------- 1. Exactly three sources ----------
src = { 'run_gate7_mission_manager_fail_silent_sim.m', ...
        fullfile(SR,'GATE7_MISSION_MANAGER_FAIL_SILENT_SIM.mat'), ...
        fullfile(SR,'GATE7_MISSION_MANAGER_FAIL_SILENT_SIM.md') };
R.sources = src;
R.src_fp  = cell(1,3);
for i = 1:3
    if ~exist(src{i},'file')
        error('missing frozen source: %s', src{i});
    end
    R.src_fp{i} = g7_fp_file(src{i});
    fprintf('source %d: %s  %s\n', i, src{i}, R.src_fp{i});
end

P0 = load(src{2});
if ~isfield(P0,'R'); error('prior mat has no result struct R'); end
R0 = P0.R;
R.prior = struct();
R.prior.task_id = R0.task_id;
R.prior.verdict = R0.verdict;
R.prior.created = R0.created;
R.prior.sources = R0.sources;
R.prior.src_fp  = R0.src_fp;
R.prior.gate6b  = R0.gate6b;
fprintf('prior run: %s verdict %s (created %s)\n', R0.task_id, R0.verdict, R0.created);
if ~strcmp(R0.task_id,'GATE7_MISSION_MANAGER_FAIL_SILENT_SIM_001')
    error('prior mat is not the Gate 7 attempt-1 result');
end

% md source binding: the repair scope must be the one the prior report named
mdtxt = fileread(src{3});
B = struct();
B.md_verdict_partial  = g7_has(mdtxt,'**PARTIAL** (14/15 hard gates)');
B.md_hg8_failed       = g7_has(mdtxt,'| HG8 |') && g7_has(mdtxt,'S01(rec 1/0 ep 0/0)');
B.md_names_repair     = g7_has(mdtxt,'gate7_fdir_acceptance_criterion_repair_and_rerun');
B.md_three_valued     = g7_has(mdtxt,'must_recover') && g7_has(mdtxt,'must_not_recover') && ...
                        g7_has(mdtxt,'not_applicable_no_degradation');
B.md_action_metric    = g7_has(mdtxt,'at least as severe as this monitor requires');
B.md_tex_banner       = g7_has(mdtxt,'underscores in the title render as TeX subscripts');
B.md_panel6_framing   = g7_has(mdtxt,'occupies a small part of the frame');
B.mat_has_cfg         = isfield(R0,'cfg') && isfield(R0,'scenarios') && isfield(R0,'per_case');
B.driver_has_sim      = g7_has(fileread(src{1}),'function O = g7_sim(C, sc)');
R.source_binding = B;
bf = fieldnames(B);
for i = 1:numel(bf)
    fprintf('bind %-20s : %d\n', bf{i}, B.(bf{i}));
end

%% ---------- 2. Production / CODEX fingerprints (pre) ----------
prod = { 'continuous_path_tracking.m', 'controller_law.m', 'guidance_law.m', ...
         'underwater777_vehicle_dynamics.m', 'compute_path_following_metrics.m', ...
         fullfile('suite_results','CODEX_VERTICAL_PLAN.md') };
R.prod_files = prod;
R.fp_pre = cell(1,numel(prod));
for i = 1:numel(prod)
    R.fp_pre{i} = g7_fp_file(prod{i});
end
% cross-reference against the prior Gate 7 recorded fingerprints (full triple)
R.fp_prior = R0.fp_post;
R.fp_prior_match = false(1,numel(prod));
for i = 1:numel(prod)
    R.fp_prior_match(i) = strcmp(R.fp_pre{i}, R.fp_prior{i});
end
% prior gate7 artifacts must be preserved: fingerprint them too
R.prior_artifacts = { src{1}, src{2}, src{3}, ...
                      fullfile(SR,'GATE7_MISSION_MANAGER_FAIL_SILENT_SIM.png') };
R.fp_prior_art_pre = cell(1,4);
for i = 1:4
    R.fp_prior_art_pre{i} = g7_fp_file(R.prior_artifacts{i});
end

%% ---------- 3. Frames / signs (inherited verbatim) ----------
R.frames = R0.frames;

%% ---------- 4. Configuration: inherited verbatim from the prior MAT ----------
C = R0.cfg;
% Re-derive every DERIVED threshold from the same primitives and require exact
% equality with what the prior run used. This proves no threshold/window change.
D = struct();
D.bnd_inj = [ C.deb_req(1)+2*C.T_wd, ...
              C.uv_debounce+2*C.T_wd, ...
              C.wd_consec*C.T_ctrl+2*C.T_wd, ...
              C.deb_req(4)+2*C.T_wd, ...
              C.imu_to+C.T_imu+2*C.T_wd, ...
              C.dvl_to+C.T_dvl+2*C.T_wd, ...
              C.dep_to+C.T_dep+2*C.T_wd, ...
              C.bus_to+C.T_link+C.bus_delay+C.bus_jitter+2*C.T_wd, ...
              C.stale_to+C.T_msn+C.bus_delay+C.bus_jitter+2*C.T_wd ];
D.bnd_cond      = C.deb_req + 2*C.T_wd;
D.act_gap_bound = 2*C.T_guid + 2*C.T_ctrl;
D.kappa_path    = g7_path_kappa(C.wp);
D.slope_path    = g7_path_slope(C.wp);
cfg_derived_ok = isequaln(D.bnd_inj, C.bnd_inj) && isequaln(D.bnd_cond, C.bnd_cond) && ...
                 isequaln(D.act_gap_bound, C.act_gap_bound) && ...
                 isequaln(D.kappa_path, C.kappa_path) && isequaln(D.slope_path, C.slope_path);
R.cfg = C;
R.cfg_derived_ok = cfg_derived_ok;
fprintf('config inherited verbatim; derived thresholds re-derived and matched: %d\n', cfg_derived_ok);

%% ---------- 5. Frozen scenario matrix: rebuilt identically, then compared ----------
SC = g7_scenarios(C);
nsc = numel(SC);
[sc_par_ok, sc_par_det] = g7r_cmp_structarray(SC, R0.scenarios, {});
fprintf('scenario matrix parity vs prior mat: %d (%s)\n', sc_par_ok, sc_par_det);

% ---- the ONLY acceptance change on the schedule: three-valued recovery class
CLASSES = {'must_recover','must_not_recover','not_applicable_no_degradation'};
class_map_ok = true;
for i = 1:nsc
    degrades = any(SC(i).expect) || (SC(i).expect_episodes > 0) || any(SC(i).W(:,2) > SC(i).W(:,1));
    if ~degrades
        SC(i).rec_class = 'not_applicable_no_degradation';
    elseif SC(i).expect_recover == 1
        SC(i).rec_class = 'must_recover';
    else
        SC(i).rec_class = 'must_not_recover';
    end
    if ~any(strcmp(SC(i).rec_class, CLASSES)); class_map_ok = false; end
    % the mapping must remain a pure function of the frozen prior expectation
    if degrades && ~strcmp(SC(i).rec_class, g7r_expected_class(SC(i).expect_recover))
        class_map_ok = false;
    end
end
R.scenarios = SC;
R.rec_classes = CLASSES;
R.class_map_ok = class_map_ok;
fprintf('\nfrozen scenario matrix (%d cases, unchanged) with repaired recovery classes:\n', nsc);
for i = 1:nsc
    fprintf('  %-2d %-6s %-34s expect=[%s] class=%s\n', i, SC(i).code, SC(i).name, ...
            num2str(find(SC(i).expect)), SC(i).rec_class);
end

%% ---------- 6. Identical re-run: pass A / pass B ----------
fprintf('\n--- pass A (forward order) ---\n');
A = cell(1,nsc);
for i = 1:nsc
    A{i} = g7_sim(C, SC(i));
    fprintf('  %-6s hash=%s trips=[%s] rej=%d mode_eps=%d\n', SC(i).code, A{i}.hash, ...
            num2str(find(A{i}.trip)), A{i}.n_reject, A{i}.episodes);
end
fprintf('--- pass B (reverse order, independent re-execution) ---\n');
hashB = cell(1,nsc);
for i = nsc:-1:1
    Bx = g7_sim(C, SC(i));
    hashB{i} = Bx.hash;
end
replay_ok = false(1,nsc);
for i = 1:nsc
    replay_ok(i) = strcmp(A{i}.hash, hashB{i});
end
R.replay_hash_A = cellfun(@(s) s.hash, A, 'UniformOutput', false);
R.replay_hash_B = hashB;
R.replay_ok = replay_ok;
fprintf('deterministic replay: %d/%d identical\n', sum(replay_ok), nsc);

%% ---------- 7. Aggregate metrics (identical code) ----------
M = g7_aggregate(C, SC, A);

%% ---------- 8. Parity against the prior MAT (raw behaviour must be exact) ----------
PC_raw = g7_strip(A);
PAR = struct();
PAR.hashA_ok   = isequal(R.replay_hash_A, R0.replay_hash_A);
PAR.hashB_ok   = isequal(R.replay_hash_B, R0.replay_hash_B);
PAR.replay_ok  = isequal(R.replay_ok, R0.replay_ok);
[PAR.percase_ok, PAR.percase_det] = g7r_cmp_structarray(PC_raw, R0.per_case, {});
[PAR.metrics_ok, PAR.metrics_det] = g7r_cmp_struct(M, R0.metrics, {});
PAR.scenarios_ok = sc_par_ok; PAR.scenarios_det = sc_par_det;
PAR.cfg_ok = isequaln(C, R0.cfg) && cfg_derived_ok;
PAR.n_cases = nsc;
% per-case time-series equality is already implied by hash + full field compare,
% but assert the logged matrices explicitly as well
ts_ok = true; ts_bad = {};
for i = 1:nsc
    if ~isequaln(single(A{i}.L), R0.per_case(i).L) || ~isequaln(A{i}.ACK, R0.per_case(i).ACK)
        ts_ok = false; ts_bad{end+1} = SC(i).code; %#ok<AGROW>
    end
end
PAR.timeseries_ok = ts_ok;
if isempty(ts_bad); PAR.timeseries_det = sprintf('%d/%d case log + ack matrices identical', nsc, nsc);
else; PAR.timeseries_det = ['differing: ' strjoin(ts_bad,',')]; end
PAR.all_ok = PAR.hashA_ok && PAR.hashB_ok && PAR.replay_ok && PAR.percase_ok && ...
             PAR.metrics_ok && PAR.scenarios_ok && PAR.cfg_ok && PAR.timeseries_ok;
R.parity = PAR;
fprintf('\nparity vs prior MAT: hashA=%d hashB=%d replay=%d per_case=%d metrics=%d scen=%d cfg=%d ts=%d -> ALL=%d\n', ...
    PAR.hashA_ok, PAR.hashB_ok, PAR.replay_ok, PAR.percase_ok, PAR.metrics_ok, ...
    PAR.scenarios_ok, PAR.cfg_ok, PAR.timeseries_ok, PAR.all_ok);

%% ---------- 9. Repaired derived field: severity-based detect-to-action ----------
GS = zeros(0,3); GS_lbl = {};
for i = 1:nsc
    a = A{i};
    a.act_req_mode = nan(1,9); a.t_action_sev = nan(1,9); a.act_gap_sev = nan(1,9);
    for m = find(SC(i).expect)
        if a.trip(m)
            [gp, rq, ta] = g7r_action_gap(C, a, m);
            a.act_req_mode(m) = rq; a.t_action_sev(m) = ta; a.act_gap_sev(m) = gp;
            GS(end+1,:) = [m gp C.act_gap_bound]; %#ok<AGROW>
            GS_lbl{end+1} = sprintf('%s/M%d', SC(i).code, m); %#ok<AGROW>
        end
    end
    A{i} = a;
end
M.act_gap_sev = GS;
M.act_gap_sev_labels = GS_lbl;
if isempty(GS); M.act_gap_sev_worst = NaN; else; M.act_gap_sev_worst = max(GS(:,2)); end
R.metrics = M;

% per-case store: prior fields untouched + declared additions only
PC = PC_raw;
for i = 1:nsc
    PC(i).act_req_mode = A{i}.act_req_mode;
    PC(i).t_action_sev = A{i}.t_action_sev;
    PC(i).act_gap_sev  = A{i}.act_gap_sev;
end
R.per_case = PC;

% criterion-scope bookkeeping: exactly which fields were added, nothing removed
ALLOW_PC  = {'act_req_mode','t_action_sev','act_gap_sev'};
ALLOW_M   = {'act_gap_sev','act_gap_sev_labels','act_gap_sev_worst'};
ALLOW_SC  = {'rec_class'};
SCOPE = struct();
[SCOPE.pc_added,  SCOPE.pc_removed]  = g7r_field_delta(fieldnames(PC),  fieldnames(R0.per_case));
[SCOPE.m_added,   SCOPE.m_removed]   = g7r_field_delta(fieldnames(M),   fieldnames(R0.metrics));
[SCOPE.sc_added,  SCOPE.sc_removed]  = g7r_field_delta(fieldnames(SC),  fieldnames(R0.scenarios));
SCOPE.pc_ok = isempty(SCOPE.pc_removed) && all(ismember(SCOPE.pc_added, ALLOW_PC));
SCOPE.m_ok  = isempty(SCOPE.m_removed)  && all(ismember(SCOPE.m_added,  ALLOW_M));
SCOPE.sc_ok = isempty(SCOPE.sc_removed) && all(ismember(SCOPE.sc_added, ALLOW_SC));
SCOPE.allow_pc = ALLOW_PC; SCOPE.allow_m = ALLOW_M; SCOPE.allow_sc = ALLOW_SC;
i1 = find(strcmp({SC.code},'S01')); i14 = find(strcmp({SC.code},'S14'));
SCOPE.s01_na = strcmp(SC(i1).rec_class,'not_applicable_no_degradation');
SCOPE.s14_na = strcmp(SC(i14).rec_class,'not_applicable_no_degradation');
SCOPE.class_map_ok = class_map_ok;
SCOPE.all_ok = SCOPE.pc_ok && SCOPE.m_ok && SCOPE.sc_ok && SCOPE.s01_na && ...
               SCOPE.s14_na && SCOPE.class_map_ok;
R.scope = SCOPE;
fprintf('criterion scope: pc_added={%s} m_added={%s} sc_added={%s} S01/S14 N/A=%d/%d -> ok=%d\n', ...
    strjoin(SCOPE.pc_added,','), strjoin(SCOPE.m_added,','), strjoin(SCOPE.sc_added,','), ...
    SCOPE.s01_na, SCOPE.s14_na, SCOPE.all_ok);

%% ---------- 10. Hard gates (15 original, HG8 repaired, + HG16 parity, HG17 scope) ----------
[G, verdict] = g7r_gates(C, SC, A, M, R, replay_ok, PAR, SCOPE);
R.gates = G;
R.verdict = verdict;

%% ---------- 11. Artifacts ----------
pngf = fullfile(SR,[TAG '.png']);
matf = fullfile(SR,[TAG '.mat']);

R.fp_post = cell(1,numel(prod));
for i = 1:numel(prod)
    R.fp_post{i} = g7_fp_file(prod{i});
end
R.fp_unchanged = all(strcmp(R.fp_pre, R.fp_post)) && all(R.fp_prior_match);
R.fp_prior_art_post = cell(1,4);
for i = 1:4
    R.fp_prior_art_post{i} = g7_fp_file(R.prior_artifacts{i});
end
R.prior_art_unchanged = all(strcmp(R.fp_prior_art_pre, R.fp_prior_art_post));
for i = 1:numel(G)
    if strcmp(G(i).id,'HG13')
        G(i).pass = double(R.fp_unchanged && R.prior_art_unchanged);
        G(i).detail = sprintf(['%d production/plan files fingerprinted, %d changed; ' ...
            'full-triple cross-match against the prior Gate 7 mat %d/%d; ' ...
            '4 prior Gate 7 artifacts preserved byte-identical: %s'], ...
            numel(prod), sum(~strcmp(R.fp_pre,R.fp_post)), sum(R.fp_prior_match), numel(prod), ...
            g7_yn(R.prior_art_unchanged));
    end
end
R.gates = G;
if all([G.pass]); R.verdict = 'PASS'; elseif any([G.pass]); R.verdict = 'PARTIAL'; else; R.verdict = 'FAIL'; end

g7r_plot(C, SC, A, M, G, R, pngf);
R.host_runtime_s = toc(t_host);
save(matf,'R','-v7');
d1 = dir(matf); d2 = dir(pngf);
R.mat_mib = d1.bytes/2^20; R.png_mib = d2.bytes/2^20;
for i = 1:numel(G)
    if strcmp(G(i).id,'HG14')
        tot = R.mat_mib + R.png_mib;
        G(i).pass = double(tot < 300);
        G(i).detail = sprintf('mat=%.2f MiB, png=%.2f MiB, total=%.2f MiB (< 300 MiB target)', R.mat_mib, R.png_mib, tot);
    end
end
R.gates = G;
if all([G.pass]); R.verdict = 'PASS'; elseif any([G.pass]); R.verdict = 'PARTIAL'; else; R.verdict = 'FAIL'; end
save(matf,'R','-v7');

g7r_report(TAG, SR, C, SC, A, M, R, G, R0);
g7r_append_logs(TAG, SR, R, G);

fprintf('\nVERDICT: %s   (%d/%d hard gates)\n', R.verdict, sum([G.pass]), numel(G));
fprintf('artifacts: %s.{md,mat,png}  mat=%.2f MiB png=%.2f MiB  runtime=%.1f s\n', ...
        TAG, R.mat_mib, R.png_mib, R.host_runtime_s);
end

% ======================================================================
%  repaired acceptance helpers
% ======================================================================
function c = g7r_expected_class(flag)
if flag == 1; c = 'must_recover'; else; c = 'must_not_recover'; end
end

function [gap, req, tact] = g7r_action_gap(C, O, m)
% Repaired detect-to-action: time until the ACTIVE response severity is at
% least the severity this monitor requires. If a higher-severity response is
% already in force at detection, the required action is already satisfied and
% the gap is zero (immediate), not "time to the next mode change".
det = O.det_t(m);
req = C.mon_mode(m);
gap = NaN; tact = NaN;
if isnan(det); return; end
L = O.L; tc = L(:,1); mc = L(:,4);
ip = find(tc <= det + 1e-9, 1, 'last');
if ~isempty(ip) && mc(ip) >= req
    gap = 0; tact = det; return;
end
j = find((tc >= det - 1e-9) & (mc >= req), 1, 'first');
if ~isempty(j)
    tact = tc(j); gap = max(0, tact - det);
end
end

% ======================================================================
%  parity helpers
% ======================================================================
function [ok, det] = g7r_cmp_struct(sNew, sOld, skip)
fn = fieldnames(sOld); bad = {};
fnN = fieldnames(sNew);
missing = setdiff(fn, fnN);
for i = 1:numel(fn)
    f = fn{i};
    if any(strcmp(f, skip)); continue; end
    if ~isfield(sNew, f); bad{end+1} = [f '(absent)']; continue; end %#ok<AGROW>
    if ~isequaln(sNew.(f), sOld.(f)); bad{end+1} = f; end %#ok<AGROW>
end
ok = isempty(bad) && isempty(missing);
if ok
    det = sprintf('%d/%d fields exactly equal', numel(fn), numel(fn));
else
    det = sprintf('%d/%d fields differ: %s', numel(bad), numel(fn), strjoin(bad,','));
end
end

function [ok, det] = g7r_cmp_structarray(aNew, aOld, skip)
ok = true; bad = {};
if numel(aNew) ~= numel(aOld)
    ok = false; det = sprintf('element count %d vs %d', numel(aNew), numel(aOld)); return;
end
fn = fieldnames(aOld);
for i = 1:numel(aNew)
    for j = 1:numel(fn)
        f = fn{j};
        if any(strcmp(f, skip)); continue; end
        if ~isfield(aNew(i), f)
            ok = false; bad{end+1} = sprintf('[%d]%s(absent)', i, f); continue; %#ok<AGROW>
        end
        if ~isequaln(aNew(i).(f), aOld(i).(f))
            ok = false; bad{end+1} = sprintf('[%d]%s', i, f); %#ok<AGROW>
        end
    end
end
if ok
    det = sprintf('%d elements x %d fields exactly equal', numel(aNew), numel(fn));
else
    det = sprintf('%d differing entries: %s', numel(bad), strjoin(bad,','));
end
end

function [added, removed] = g7r_field_delta(fnNew, fnOld)
added   = reshape(setdiff(fnNew, fnOld), 1, []);
removed = reshape(setdiff(fnOld, fnNew), 1, []);
end

% ======================================================================
%  FROZEN SCENARIO MATRIX  (identical to attempt 1, not re-tuned)
% ======================================================================
function SC = g7_scenarios(C) %#ok<INUSD>
S = struct('name','','code','','W',zeros(15,2),'conf',0,'expect',false(1,9), ...
           'inj_on',nan(1,9),'expect_recover',0,'expect_episodes',0,'note','');
k = 0;
k=k+1; SC(k)=S; SC(k).name='NOMINAL';                       SC(k).code='S01';
       SC(k).note='no fault; false-alarm reference';
k=k+1; SC(k)=S; SC(k).name='INVALID_SCHEMA_FRAME_INTEGRITY'; SC(k).code='S02';
       SC(k).W(1,:)=[12 24]; SC(k).W(2,:)=[12 24]; SC(k).W(3,:)=[12 24];
       SC(k).expect(9)=true; SC(k).inj_on(9)=12; SC(k).expect_recover=1; SC(k).expect_episodes=1;
       SC(k).note='one corruption type per mission tick, cycling; rejected uplink is not fresh uplink so mission goes stale';
k=k+1; SC(k)=S; SC(k).name='OUT_OF_ORDER_REPLAY';            SC(k).code='S03';
       SC(k).W(4,:)=[12 22]; SC(k).expect(9)=true; SC(k).inj_on(9)=12;
       SC(k).expect_recover=1; SC(k).expect_episodes=1;
k=k+1; SC(k)=S; SC(k).name='EXPIRED_SEGMENT';                SC(k).code='S04';
       SC(k).W(5,:)=[12 22]; SC(k).expect(9)=true; SC(k).inj_on(9)=12;
       SC(k).expect_recover=1; SC(k).expect_episodes=1;
k=k+1; SC(k)=S; SC(k).name='MISSION_HEARTBEAT_LOSS';         SC(k).code='S05';
       SC(k).W(6,:)=[12 24]; SC(k).expect(9)=true; SC(k).inj_on(9)=12;
       SC(k).expect_recover=1; SC(k).expect_episodes=1;
k=k+1; SC(k)=S; SC(k).name='BUS_TIMEOUT';                    SC(k).code='S06';
       SC(k).W(7,:)=[12 22]; SC(k).expect(8)=true; SC(k).expect(9)=true;
       SC(k).inj_on(8)=12; SC(k).inj_on(9)=12; SC(k).expect_recover=1; SC(k).expect_episodes=1;
k=k+1; SC(k)=S; SC(k).name='STALE_IMU';                      SC(k).code='S07';
       SC(k).W(8,:)=[12 18]; SC(k).expect(5)=true; SC(k).inj_on(5)=12;
       SC(k).expect_recover=1; SC(k).expect_episodes=1;
k=k+1; SC(k)=S; SC(k).name='STALE_DVL';                      SC(k).code='S08';
       SC(k).W(9,:)=[10 24]; SC(k).expect(6)=true; SC(k).inj_on(6)=10;
       SC(k).expect_recover=1; SC(k).expect_episodes=1;
       SC(k).note='DVL loss = CONSTRAIN then SAFE_HOLD after declared dead-reckoning budget';
k=k+1; SC(k)=S; SC(k).name='STALE_DEPTH';                    SC(k).code='S09';
       SC(k).W(10,:)=[12 20]; SC(k).expect(7)=true; SC(k).inj_on(7)=12;
       SC(k).expect_recover=1; SC(k).expect_episodes=1;
k=k+1; SC(k)=S; SC(k).name='ACTUATOR_STUCK_CURRENT';         SC(k).code='S10';
       SC(k).W(11,:)=[12 20]; SC(k).expect(4)=true; SC(k).inj_on(4)=12;
       SC(k).expect_recover=1; SC(k).expect_episodes=1;
k=k+1; SC(k)=S; SC(k).name='UNDERVOLTAGE';                   SC(k).code='S11';
       SC(k).W(12,:)=[12 16]; SC(k).expect(2)=true; SC(k).inj_on(2)=12;
       SC(k).expect_recover=1; SC(k).expect_episodes=1;
k=k+1; SC(k)=S; SC(k).name='LEAK';                           SC(k).code='S12';
       SC(k).W(13,:)=[18 19]; SC(k).expect(1)=true; SC(k).inj_on(1)=18;
       SC(k).expect_recover=0; SC(k).expect_episodes=1;
       SC(k).note='latching, no auto-clear, no auto-surface, no auto-accommodation';
k=k+1; SC(k)=S; SC(k).name='WATCHDOG_OVERRUN';               SC(k).code='S13';
       SC(k).W(14,:)=[12 17]; SC(k).expect(3)=true; SC(k).inj_on(3)=12;
       SC(k).expect_recover=1; SC(k).expect_episodes=1;
k=k+1; SC(k)=S; SC(k).name='CONFOUNDER_BENIGN';              SC(k).code='S14';
       SC(k).conf=1;
       SC(k).note='near-threshold but legal: jitter, sub-threshold sensor gaps, sag above V_bo, single miss, over-limit soft hints, burst';
k=k+1; SC(k)=S; SC(k).name='MULTI_FAULT_PRECEDENCE';         SC(k).code='S15';
       SC(k).W(6,:)=[10 30]; SC(k).W(12,:)=[14 18]; SC(k).W(13,:)=[22 23];
       SC(k).expect([1 2 9])=true; SC(k).inj_on(1)=22; SC(k).inj_on(2)=14; SC(k).inj_on(9)=10;
       SC(k).expect_recover=0; SC(k).expect_episodes=1;
       SC(k).note='precedence LEAK > UNDERVOLTAGE > MISSION_STALE; leak latches to end';
k=k+1; SC(k)=S; SC(k).name='FORBIDDEN_MISSION_COMMANDS';     SC(k).code='S16';
       SC(k).W(15,:)=[10 22]; SC(k).expect(9)=true; SC(k).inj_on(9)=10;
       SC(k).expect_recover=1; SC(k).expect_episodes=1;
       SC(k).note='surface request / direct-actuator field / accommodation request: rejected, never issued';
end

% ======================================================================
%  ISOLATED MISSION MANAGER + FDIR SIMULATION (byte-for-byte identical logic)
% ======================================================================
function O = g7_sim(C, sc)

rs  = g7_seed(sc.code);
nk  = round(C.T_end / C.dt_u);
nlog = round(C.T_end / C.T_ctrl);

x = C.wp(1,1); y = C.wp(1,2); z = C.z0; psi = 0; th = 0; u = C.u0;
de = 0; dr = 0; thr = 0.30; dr_app = 0; de_app = 0;
V = C.V_nom; I_proxy = 0.10;

gi = struct('seg',1,'z_hint',C.wp(2,3),'u_hint',1.2,'slope_hint',0,'valid',0, ...
            'mission_id',1,'segment_id',1,'seq',0,'t_mono',0);
gi_safe = gi;
yaw_ref = 0; pitch_ref = 0; u_ref = C.u0; depth_ref = C.z0;
mode = 0; mode_prev = 0;
sh_frozen = false; sh_depth = C.z0; sh_yaw = 0; sh_ref0 = C.z0;

maxmsg = 4*ceil(C.T_end/C.T_msn) + 32;
BUS = zeros(maxmsg,16); nmsg = 0;
seq_tx = 0; seq_rx_last = 0;
next_msn = 0; next_ctrl = 0; next_guid = 0; next_wd = 0;
next_imu = 0; next_dvl = 0; next_dep = 0; next_link = 0;
last_pub_imu = 0; last_pub_dvl = 0; last_pub_dep = 0;
last_rx_bus = 0; last_valid_msn = 0; link_arr = NaN;

raw = false(1,9); deb = zeros(1,9); act = false(1,9); clr = zeros(1,9);
cond_on = nan(1,9); det_t = nan(1,9); cond_at_det = nan(1,9);
act_since = nan(1,9); trip = false(1,9); mode_change_t = nan(1,9);
consec_miss = 0; n_ctrl_miss = 0; n_wd_miss = 0; leak = false;
nav_integrity = 1; act_health = 1;

L = zeros(nlog,30); nl = 0;
ACK = zeros(maxmsg,6); nack = 0;
seq_out = 0; t_last_out = -1;
mono_seq_ok = true; mono_time_ok = true;
clamp_events = 0; hint_unclamped = 0;
req_surface = 0; req_direct_act = 0; req_accom = 0;
iss_surface = 0; iss_direct_act = 0; iss_accom = 0;
mag_viol = 0; rate_viol = 0; bnd_viol = 0;
step_max = zeros(1,4);
cte_sum = 0; cte_n = 0; cte_max = 0;
depth_min = z; depth_max = z; depth_min_deg = Inf;
de_absmax = 0; dr_absmax = 0; thr_hi = 0; V_min = V;
mode_hist = zeros(nlog,1);
eps0 = 1e-9;

for k = 1:nk
    t = (k-1)*C.dt_u;

    if t >= next_link - eps0
        next_link = next_link + C.T_link;
        [uu,rs] = g7_lcg(rs);
        jit = C.bus_jitter*uu;
        if sc.conf; jit = C.bus_jitter; end
        arr = t + C.bus_delay + jit;
        if ~g7_in(arr, sc.W(7,:)); link_arr = arr; end
    end

    if t >= next_msn - eps0
        next_msn = next_msn + C.T_msn;
        nburst = 1;
        if sc.conf && abs(t-20) < 0.5*C.T_msn; nburst = 3; end
        for bb = 1:nburst
            segm = g7_nearest_seg(C.wp, [x y z]);
            m = zeros(1,16);
            m(1) = t; m(16) = 3;
            if mod(round(t/C.T_msn),5) == 0; m(16) = 1; end
            if t < 0.5*C.T_msn; m(16) = 2; end
            m(3) = C.schema_ok; m(4) = 1; m(5) = 1;
            seq_tx = seq_tx + 1; m(6) = seq_tx;
            m(7) = t + C.horizon_default;
            m(8) = segm;
            m(9) = C.wp(segm+1,3);
            m(10) = 1.2; m(11) = 0; m(12) = C.kappa_path(segm);
            m(13) = 0;
            if sc.conf
                m(10) = 4.0; m(11) = 40.0;
            end
            kk = mod(round(t/C.T_msn),3);
            if kk == 0 && g7_in(t,sc.W(1,:)); m(3) = 99; end
            if kk == 1 && g7_in(t,sc.W(2,:)); m(4) = 0;  end
            if kk == 2 && g7_in(t,sc.W(3,:)); m(5) = 0;  end
            if g7_in(t,sc.W(4,:)); m(6) = max(1,seq_rx_last - 2); end
            if g7_in(t,sc.W(5,:)); m(7) = t - 1.0; end
            if g7_in(t,sc.W(15,:))
                fc = 1 + mod(round(t/C.T_msn),3);
                m(13) = fc;
                if fc == 1; m(9) = -2.0; end
            end
            m(14) = g7_expect_code(C, m, seq_rx_last);
            if g7_in(t,sc.W(6,:)); continue; end
            [uu,rs] = g7_lcg(rs);
            jit = C.bus_jitter * uu;
            if sc.conf; jit = C.bus_jitter; end
            m(2) = t + C.bus_delay + jit + (bb-1)*0.004;
            if g7_in(m(2),sc.W(7,:)); continue; end
            nmsg = nmsg + 1; BUS(nmsg,:) = m;
            if m(13) == 1; req_surface = req_surface + 1; end
            if m(13) == 2; req_direct_act = req_direct_act + 1; end
            if m(13) == 3; req_accom = req_accom + 1; end
        end
    end

    if t >= next_imu - eps0
        next_imu = next_imu + C.T_imu;
        if ~g7_in(t,sc.W(8,:)); last_pub_imu = t; end
    end
    if t >= next_dvl - eps0
        stepd = C.T_dvl;
        if sc.conf; stepd = 0.8; end
        next_dvl = next_dvl + stepd;
        if ~g7_in(t,sc.W(9,:)); last_pub_dvl = t; end
    end
    if t >= next_dep - eps0
        stepp = C.T_dep;
        if sc.conf; stepp = 0.4; end
        next_dep = next_dep + stepp;
        if ~g7_in(t,sc.W(10,:)); last_pub_dep = t; end
    end

    is_ctrl = (t >= next_ctrl - eps0);
    if is_ctrl
        if ~isnan(link_arr) && link_arr <= t + eps0
            last_rx_bus = link_arr; link_arr = NaN;
        end
        for j = 1:nmsg
            if BUS(j,15) == 0 && BUS(j,2) <= t + eps0
                BUS(j,15) = 1;
                last_rx_bus = t;
                code = g7_validate(C, BUS(j,:), seq_rx_last);
                nack = nack + 1;
                ACK(nack,:) = [t BUS(j,6) BUS(j,16) BUS(j,14) code (t-BUS(j,2))];
                if code == 0
                    seq_rx_last = BUS(j,6);
                    last_valid_msn = t;
                    gi.seg = BUS(j,8);
                    zh = BUS(j,9); uh = BUS(j,10); sh = BUS(j,11);
                    zc = min(max(zh,C.depth_min),C.depth_max);
                    uc = min(max(uh,C.u_min),C.u_max);
                    sc2 = min(max(sh,-C.slope_max),C.slope_max);
                    if abs(zc-zh)>1e-9 || abs(uc-uh)>1e-9 || abs(sc2-sh)>1e-9
                        clamp_events = clamp_events + 1;
                    end
                    if abs(uc) > C.u_max + 1e-9 || abs(sc2) > C.slope_max + 1e-9 || ...
                       zc < C.depth_min - 1e-9 || zc > C.depth_max + 1e-9
                        hint_unclamped = hint_unclamped + 1;
                    end
                    gi.z_hint = zc; gi.u_hint = uc; gi.slope_hint = sc2;
                    gi.valid = 1; gi.mission_id = 1; gi.segment_id = BUS(j,8);
                    gi.seq = BUS(j,6); gi.t_mono = BUS(j,1);
                end
            end
        end
    end

    leak = g7_in(t,sc.W(13,:)) || (C.latching(1) && act(1));
    raw(1) = g7_in(t,sc.W(13,:));
    raw(2) = V < C.V_bo;
    raw(3) = consec_miss >= C.wd_consec;
    raw(4) = (abs(dr - dr_app) > C.act_resid_thr) || (I_proxy > C.act_cur_thr);
    raw(5) = (t - last_pub_imu) > C.imu_to;
    raw(6) = (t - last_pub_dvl) > C.dvl_to;
    raw(7) = (t - last_pub_dep) > C.dep_to;
    raw(8) = (t - last_rx_bus) > C.bus_to;
    raw(9) = (t - last_valid_msn) > C.stale_to;
    for m = 1:9
        if raw(m)
            if isnan(cond_on(m)); cond_on(m) = t; end
        elseif isnan(det_t(m))
            cond_on(m) = NaN;
        end
    end

    if t >= next_wd - eps0
        next_wd = next_wd + C.T_wd;
        for m = 1:9
            if raw(m)
                deb(m) = deb(m) + C.T_wd; clr(m) = 0;
                if deb(m) >= C.deb_req(m) - eps0
                    if ~act(m)
                        act(m) = true; act_since(m) = t;
                        if isnan(det_t(m))
                            det_t(m) = t; cond_at_det(m) = cond_on(m); trip(m) = true;
                        end
                    end
                end
            else
                deb(m) = 0;
                if act(m) && ~C.latching(m)
                    clr(m) = clr(m) + C.T_wd;
                    if clr(m) >= C.recov_hold - eps0
                        act(m) = false; act_since(m) = NaN; clr(m) = 0;
                    end
                end
            end
        end
        newmode = 0; topm = 0;
        for m = 1:9
            if act(m)
                mm = C.mon_mode(m);
                if ~isnan(act_since(m)) && (t - act_since(m)) >= C.mon_escalate(m); mm = 3; end
                if mm > newmode; newmode = mm; end
                if topm == 0; topm = m; end
            end
        end
        if newmode ~= mode
            for m = 1:9
                if act(m) && isnan(mode_change_t(m)) && newmode > 0
                    mode_change_t(m) = t;
                end
            end
            if newmode == 3 && mode ~= 3
                sh_frozen = true; sh_depth = z; sh_yaw = psi;
                sh_ref0 = min(depth_ref, z);
            elseif newmode ~= 3
                sh_frozen = false;
            end
            mode_prev = mode; mode = newmode;
        end
        nav_integrity = 1 - 0.3*double(act(5)) - 0.3*double(act(6)) - 0.3*double(act(7));
        act_health = 1 - 0.5*double(act(4));
    end

    if t >= next_guid - eps0
        next_guid = next_guid + C.T_guid;
        yaw_p = yaw_ref; pit_p = pitch_ref; u_p = u_ref; dep_p = depth_ref;
        if mode == 0 && gi.valid == 1
            gi_safe = gi;
        end
        gu = gi; if mode ~= 0; gu = gi_safe; end
        seg = min(max(round(gu.seg),1),C.nseg);
        tgt = C.wp(seg+1,:);
        dh = sqrt((tgt(1)-x)^2 + (tgt(2)-y)^2);
        switch mode
            case 0
                yaw_t = atan2(tgt(2)-y, tgt(1)-x) * 180/pi;
                pit_t = -atan2(gu.z_hint - z, max(dh,1.0)) * 180/pi;
                u_t = gu.u_hint; dep_t = gu.z_hint;
            case 1
                yaw_t = yaw_ref; pit_t = pitch_ref; u_t = u_ref; dep_t = depth_ref;
            case 2
                yaw_t = atan2(tgt(2)-y, tgt(1)-x) * 180/pi;
                pit_t = -atan2(gu.z_hint - z, max(dh,1.0)) * 180/pi;
                pit_t = min(max(pit_t,-0.5*C.pitch_ref_max),0.5*C.pitch_ref_max);
                u_t = min(gu.u_hint, 0.6*C.u_max); dep_t = gu.z_hint;
            otherwise
                yaw_t = sh_yaw*180/pi; pit_t = 0; u_t = C.u_min; dep_t = sh_depth;
        end
        pit_t = min(max(pit_t,-C.pitch_ref_max),C.pitch_ref_max);
        u_t   = min(max(u_t,C.u_min),C.u_max);
        dep_t = min(max(dep_t,C.depth_min),C.depth_max);
        pitch_ref = g7_rl(pitch_ref, pit_t, C.pitch_ref_rate_max*C.T_guid);
        u_ref     = g7_rl(u_ref,     u_t,   C.u_ref_rate*C.T_guid);
        depth_ref = g7_rl(depth_ref, dep_t, C.depth_ref_rate*C.T_guid);
        dyaw = g7_wrap180(yaw_t - yaw_ref);
        dyaw = min(max(dyaw,-C.yaw_ref_rate_max*C.T_guid),C.yaw_ref_rate_max*C.T_guid);
        yaw_ref = g7_wrap180(yaw_ref + dyaw);
        st = [abs(g7_wrap180(yaw_ref-yaw_p)) abs(pitch_ref-pit_p) abs(u_ref-u_p) abs(depth_ref-dep_p)];
        step_max = max(step_max, st);
        lim = [C.yaw_ref_rate_max C.pitch_ref_rate_max C.u_ref_rate C.depth_ref_rate]*C.T_guid;
        rate_viol = rate_viol + sum(st > lim + 1e-6);
        if abs(pitch_ref) > C.pitch_ref_max + 1e-6; mag_viol = mag_viol + 1; end
        if u_ref < C.u_min - 1e-6 || u_ref > C.u_max + 1e-6; mag_viol = mag_viol + 1; end
        if depth_ref < C.depth_min - 1e-6 || depth_ref > C.depth_max + 1e-6; bnd_viol = bnd_viol + 1; end
        if C.kappa_path(seg) > C.kappa_max + 1e-9; bnd_viol = bnd_viol + 1; end
    end

    if is_ctrl
        next_ctrl = next_ctrl + C.T_ctrl;
        exec = C.cnom_ctrl;
        if g7_in(t,sc.W(14,:)); exec = C.cnom_ctrl*C.wd_load; end
        if sc.conf && abs(t-15.0) < 0.5*C.T_ctrl; exec = C.cnom_ctrl*C.wd_load; end
        miss = exec > C.T_ctrl;
        if miss
            consec_miss = consec_miss + 1; n_ctrl_miss = n_ctrl_miss + 1;
        else
            consec_miss = 0;
        end
        src = 1;
        if mode == 3 && miss
            src = 0;
            de = g7_rl(de, 0, C.rate_max*C.T_ctrl);
            dr = g7_rl(dr, 0, C.rate_max*C.T_ctrl);
            thr = g7_rl(thr, 0.30, C.thr_rate*C.T_ctrl);
        elseif ~miss
            de_t = min(max(C.k_de*(pitch_ref - th*180/pi),-C.de_max),C.de_max);
            dr_t = min(max(C.k_dr*g7_wrap180(yaw_ref - psi*180/pi),-C.dr_max),C.dr_max);
            th_t = min(max(0.30 + 0.15*(u_ref - u),C.thr_min),C.thr_max);
            rmax = C.rate_max; if mode == 2; rmax = 0.5*C.rate_max; end
            de = g7_rl(de, de_t, rmax*C.T_ctrl);
            dr = g7_rl(dr, dr_t, rmax*C.T_ctrl);
            thr = g7_rl(thr, th_t, C.thr_rate*C.T_ctrl);
        end
        if g7_in(t,sc.W(11,:))
        else
            dr_app = dr;
        end
        de_app = de;
        I_proxy = 0.10 + 0.004*abs(dr_app) + 0.20*thr;
        if g7_in(t,sc.W(11,:)); I_proxy = I_proxy + 0.45; end
        if abs(de) > C.de_max + 1e-6 || abs(dr) > C.dr_max + 1e-6 || ...
           thr < C.thr_min - 1e-6 || thr > C.thr_max + 1e-6
            mag_viol = mag_viol + 1;
        end
        de_absmax = max(de_absmax,abs(de)); dr_absmax = max(dr_absmax,abs(dr));
        thr_hi = max(thr_hi,thr);
        seq_out = seq_out + 1;
        if t <= t_last_out; mono_time_ok = false; end
        t_last_out = t;
        r_eff = min(max(C.k_psi*0.01167*dr_app, -C.yaw_ref_rate_max*pi/180), C.yaw_ref_rate_max*pi/180);
        psi = psi + r_eff*C.T_ctrl;
        q_cmd = C.k_th*0.00778*de_app;
        q_cmd = min(max(q_cmd,-C.pitch_ref_rate_max*pi/180),C.pitch_ref_rate_max*pi/180);
        th = th + q_cmd*C.T_ctrl;
        th = min(max(th,-C.pitch_ref_max*pi/180),C.pitch_ref_max*pi/180);
        u = u + (u_ref - u)/C.tau_u*C.T_ctrl;
        x = x + u*cos(th)*cos(psi)*C.T_ctrl;
        y = y + u*cos(th)*sin(psi)*C.T_ctrl;
        z = z - u*sin(th)*C.T_ctrl;
        z = max(z, 0.2);
        P = C.P_idle + C.k_pw*thr^2;
        dip = 0;
        if g7_in(t,sc.W(12,:)); dip = 0.18; end
        if sc.conf && g7_in(t,[12 14]); dip = 0.08; end
        V = C.V_nom - C.k_ir*P - dip;
        V_min = min(V_min,V);
        depth_min = min(depth_min,z); depth_max = max(depth_max,z);
        if mode > 0; depth_min_deg = min(depth_min_deg,z); end
        if mode == 0
            seg = min(max(round(gi_safe.seg),1),C.nseg);
            e = g7_seg_dist([x y z], C.wp(seg,:), C.wp(seg+1,:));
            cte_sum = cte_sum + e; cte_n = cte_n + 1; cte_max = max(cte_max,e);
        end
        if depth_ref < C.depth_min - 1e-9; iss_surface = iss_surface + 1; end
        if sh_frozen && depth_ref < sh_ref0 - 0.5; iss_surface = iss_surface + 1; end
        nl = nl + 1;
        if nl <= nlog
            L(nl,:) = [t seq_out src mode topm_of(act) yaw_ref pitch_ref u_ref depth_ref ...
                       psi*180/pi th*180/pi u z de dr thr V (t-last_valid_msn) ...
                       nav_integrity act_health double(leak) double(act(2)) consec_miss ...
                       nack double(act(9)) double(act(8)) I_proxy abs(dr-dr_app) x y];
            mode_hist(nl) = mode;
        end
        if seq_out ~= nl; mono_seq_ok = false; end
    end
end

L = L(1:nl,:); ACK = ACK(1:nack,:);
if isinf(depth_min_deg); depth_min_deg = NaN; end

O = struct();
O.name = sc.name; O.code = sc.code;
O.L = L; O.Lcols = { 't_mono','seq_out','src(1=ctrl,0=watchdog)','mode', ...
    'top_monitor','yaw_ref_deg','pitch_ref_deg','u_ref','depth_ref','psi_deg','theta_deg', ...
    'u','depth','delta_e_deg','delta_r_deg','thrust_pu','V_pu','mission_age', ...
    'nav_integrity','act_health','leak','undervoltage','consec_ctrl_miss','n_ack', ...
    'mission_stale','bus_timeout','I_proxy','dr_residual_deg','x_ned','y_ned' };
O.ACK = ACK; O.ACKcols = { 't_ack','seq','msg_type','code_expected','code_actual','bus_latency' };
O.trip = trip; O.det_t = det_t;
O.lat_cond = det_t - cond_at_det;
O.lat_inj  = det_t - sc.inj_on;
O.mode_change_t = mode_change_t;
O.act_gap = mode_change_t - det_t;
O.n_msgs = nmsg; O.n_ack = nack;
O.n_accept = sum(ACK(:,5) == 0); O.n_reject = sum(ACK(:,5) ~= 0);
O.ack_mismatch = sum(ACK(:,4) ~= ACK(:,5));
O.reject_hist = zeros(1,9);
for cc = 0:8
    O.reject_hist(cc+1) = sum(ACK(:,5) == cc);
end
O.expect = sc.expect;
O.false_alarms = sum(trip & ~sc.expect);
O.missed = sum(~trip & sc.expect);
O.episodes = sum(diff([0; double(mode_hist(1:nl) > 0)]) > 0);
O.sh_dwell = sum(mode_hist(1:nl) == 3)*C.T_ctrl;
O.hls_dwell = sum(mode_hist(1:nl) == 1)*C.T_ctrl;
O.con_dwell = sum(mode_hist(1:nl) == 2)*C.T_ctrl;
O.deg_dwell = sum(mode_hist(1:nl) > 0)*C.T_ctrl;
tail = max(1,nl-round(C.min_dwell/C.T_ctrl));
O.recovered = double(all(mode_hist(tail:nl) == 0));
O.mode_changes = sum(diff(mode_hist(1:nl)) ~= 0);
O.step_max = step_max;
O.step_lim = [C.yaw_ref_rate_max C.pitch_ref_rate_max C.u_ref_rate C.depth_ref_rate]*C.T_guid;
O.mag_viol = mag_viol; O.rate_viol = rate_viol; O.bnd_viol = bnd_viol;
O.clamp_events = clamp_events; O.hint_unclamped = hint_unclamped;
O.req_surface = req_surface; O.req_direct_act = req_direct_act; O.req_accom = req_accom;
O.iss_surface = iss_surface; O.iss_direct_act = iss_direct_act; O.iss_accom = iss_accom;
O.n_ctrl_miss = n_ctrl_miss; O.n_wd_miss = n_wd_miss;
O.mono_seq_ok = mono_seq_ok; O.mono_time_ok = mono_time_ok;
O.depth_min = depth_min; O.depth_max = depth_max; O.depth_min_deg = depth_min_deg;
O.V_min = V_min; O.de_absmax = de_absmax; O.dr_absmax = dr_absmax; O.thr_max = thr_hi;
O.act_margin_de = 1 - de_absmax/C.de_max; O.act_margin_dr = 1 - dr_absmax/C.dr_max;
O.energy_proxy = mean(L(:,16).^2);
O.cte_mean = cte_sum/max(1,cte_n); O.cte_max = cte_max;
O.pitch_ref_absmax = max(abs(L(:,7)));
O.kappa_max_cmd = max(C.kappa_path); O.slope_max_cmd = max(abs(L(:,7)));
O.hash = g7_fp_num([L(:); ACK(:)]);
end

% ======================================================================
%  helpers (identical)
% ======================================================================
function m = topm_of(act)
m = 0;
for i = 1:9
    if act(i); m = i; return; end
end
end

function c = g7_expect_code(C, m, seq_last)
c = 0;
if m(5) == 0;                        c = 3; return; end
if m(3) ~= C.schema_ok;              c = 1; return; end
if m(4) ~= 1;                        c = 2; return; end
if m(13) ~= 0;                       c = 8; return; end
if m(6) <= seq_last;                 c = 4; return; end
if m(7) < m(1) || m(7) < m(2);       c = 5; return; end
if m(12) > C.kappa_max || m(8) < 1;  c = 6; return; end
end

function code = g7_validate(C, m, seq_last)
code = 0;
if m(5) == 0;                              code = 3; return; end
if m(3) ~= C.schema_ok;                    code = 1; return; end
if m(4) ~= 1;                              code = 2; return; end
if m(13) ~= 0;                             code = 8; return; end
if m(6) <= seq_last;                       code = 4; return; end
if m(7) < m(1) || m(7) < m(2);             code = 5; return; end
if m(12) > C.kappa_max || m(8) < 1;        code = 6; return; end
end

function tf = g7_in(t,w)
tf = (w(2) > w(1)) && (t >= w(1)) && (t < w(2));
end

function v = g7_rl(v0, vt, dmax)
d = vt - v0;
if d >  dmax; d =  dmax; end
if d < -dmax; d = -dmax; end
v = v0 + d;
end

function a = g7_wrap180(a)
a = mod(a + 180, 360) - 180;
end

function s = g7_seed(code)
s = mod(sum(double(code))*7919 + 12345, 4294967296);
end

function [u, s] = g7_lcg(s)
s = mod(1664525*s + 1013904223, 4294967296);
u = s/4294967296;
end

function seg = g7_nearest_seg(wp, p)
n = size(wp,1) - 1; best = Inf; seg = 1;
for i = 1:n
    d = g7_seg_dist(p, wp(i,:), wp(i+1,:));
    if d < best; best = d; seg = i; end
end
if norm(p(:)' - wp(seg+1,:)) < 8 && seg < n; seg = seg + 1; end
end

function d = g7_seg_dist(p, a, b)
p = p(:)'; a = a(:)'; b = b(:)';
ab = b - a; L2 = dot(ab,ab);
if L2 < 1e-12; d = norm(p-a); return; end
tt = min(max(dot(p-a,ab)/L2,0),1);
d = norm(p - (a + tt*ab));
end

function kap = g7_path_kappa(wp)
n = size(wp,1) - 1; kap = zeros(1,n);
for i = 1:n
    if i == 1 || i == n; kap(i) = 0; continue; end
    A = wp(i-1,:); Bp = wp(i,:); Cp = wp(i+1,:);
    a = norm(Bp-Cp); b = norm(A-Cp); c = norm(A-Bp);
    ar = 0.5*norm(cross(Bp-A, Cp-A));
    if ar < 1e-9; kap(i) = 0; else; kap(i) = 4*ar/(a*b*c); end
end
end

function sl = g7_path_slope(wp)
n = size(wp,1) - 1; sl = zeros(1,n);
for i = 1:n
    dh = norm(wp(i+1,1:2) - wp(i,1:2));
    dz = wp(i+1,3) - wp(i,3);
    sl(i) = abs(atan2(dz, max(dh,1e-9)))*180/pi;
end
end

function tf = g7_has(s, sub)
tf = ~isempty(strfind(s, sub)); %#ok<STREMP>
end

function s = g7_fp_file(p)
fid = fopen(p,'r');
if fid < 0; s = 'MISSING'; return; end
b = fread(fid, Inf, '*uint8'); fclose(fid);
d = double(b(:)); n = numel(d);
s1 = sum(d);
s2 = mod(sum(mod((1:n)'.*d, 4294967296)), 4294967296);
s = sprintf('n=%d.s1=%d.s2=%d', n, s1, s2);
end

function h = g7_fp_num(v)
v = v(:); v(~isfinite(v)) = -7.77;
q = round(v*1e6); n = numel(q);
s1 = mod(sum(abs(q)), 281474976710656);
s2 = mod(sum(mod((1:n)'.*q, 4294967296)), 4294967296);
h = sprintf('n=%d.s1=%.0f.s2=%.0f', n, s1, s2);
end

function P = g7_strip(A)
P = A;
for i = 1:numel(P)
    P{i}.L = single(P{i}.L);
end
P = [P{:}];
end

% ======================================================================
%  aggregation (identical)
% ======================================================================
function M = g7_aggregate(C, SC, A)
n = numel(A);
M = struct();
M.n_cases = n;
M.n_detect_expected = 0; M.n_detect_ok = 0; M.n_detect_late = 0; M.n_missed = 0;
M.n_false_alarm = 0; M.n_confounder_events = 0; M.n_isolation_ok = 0;
M.n_msgs = 0; M.n_accept = 0; M.n_reject = 0; M.n_ack_mismatch = 0;
M.reject_hist = zeros(1,9);
M.lat_inj = []; M.lat_cond = []; M.act_gap = [];
M.iss_surface = 0; M.iss_direct_act = 0; M.iss_accom = 0;
M.req_surface = 0; M.req_direct_act = 0; M.req_accom = 0;
M.mag_viol = 0; M.rate_viol = 0; M.bnd_viol = 0;
M.clamp_events = 0; M.hint_unclamped = 0;
M.mono_ok = true;
for i = 1:n
    a = A{i}; s = SC(i);
    M.n_msgs = M.n_msgs + a.n_msgs; M.n_accept = M.n_accept + a.n_accept;
    M.n_reject = M.n_reject + a.n_reject; M.n_ack_mismatch = M.n_ack_mismatch + a.ack_mismatch;
    M.reject_hist = M.reject_hist + a.reject_hist;
    M.n_false_alarm = M.n_false_alarm + a.false_alarms;
    M.n_missed = M.n_missed + a.missed;
    M.mag_viol = M.mag_viol + a.mag_viol; M.rate_viol = M.rate_viol + a.rate_viol;
    M.bnd_viol = M.bnd_viol + a.bnd_viol;
    M.clamp_events = M.clamp_events + a.clamp_events;
    M.hint_unclamped = M.hint_unclamped + a.hint_unclamped;
    M.iss_surface = M.iss_surface + a.iss_surface;
    M.iss_direct_act = M.iss_direct_act + a.iss_direct_act;
    M.iss_accom = M.iss_accom + a.iss_accom;
    M.req_surface = M.req_surface + a.req_surface;
    M.req_direct_act = M.req_direct_act + a.req_direct_act;
    M.req_accom = M.req_accom + a.req_accom;
    M.mono_ok = M.mono_ok && a.mono_seq_ok && a.mono_time_ok;
    ex = find(s.expect);
    for m = ex
        M.n_detect_expected = M.n_detect_expected + 1;
        if a.trip(m)
            li = a.lat_inj(m); lc = a.lat_cond(m);
            M.lat_inj = [M.lat_inj; m li C.bnd_inj(m)];
            M.lat_cond = [M.lat_cond; m lc C.bnd_cond(m)];
            M.act_gap = [M.act_gap; m a.act_gap(m) C.act_gap_bound];
            if (isnan(li) || li <= C.bnd_inj(m) + 1e-9) && (isnan(lc) || lc <= C.bnd_cond(m) + 1e-9)
                M.n_detect_ok = M.n_detect_ok + 1;
            else
                M.n_detect_late = M.n_detect_late + 1;
            end
        end
    end
    if isequal(a.trip, s.expect); M.n_isolation_ok = M.n_isolation_ok + 1; end
    if s.conf
        M.n_confounder_events = M.n_confounder_events + 7;
    end
end
if isempty(M.lat_inj); M.lat_inj = zeros(0,3); end
if isempty(M.lat_cond); M.lat_cond = zeros(0,3); end
if isempty(M.act_gap); M.act_gap = zeros(0,3); end
M.false_alarm_rate = M.n_false_alarm / max(1,M.n_cases);
M.detect_rate = M.n_detect_ok / max(1,M.n_detect_expected);
end

% ======================================================================
%  hard gates: 15 original (HG8 repaired) + HG16 parity + HG17 scope
% ======================================================================
function [G, verdict] = g7r_gates(C, SC, A, M, R, replay_ok, PAR, SCOPE)
G = struct('id',{},'req',{},'pass',{},'detail',{});

G = g7_add(G,'HG1','Deterministic replay: independent reverse-order re-execution reproduces every case hash bit-for-bit', ...
    all(replay_ok), sprintf('%d/%d case hashes identical', sum(replay_ok), numel(replay_ok)));

G = g7_add(G,'HG2','Monotonic logs: seq strictly +1 and t_mono strictly increasing on every emitted output, every case', ...
    M.mono_ok, sprintf('monotonic seq/t_mono on %d/%d cases', sum(cellfun(@(a) a.mono_seq_ok && a.mono_time_ok, A)), numel(A)));

i1 = find(strcmp({SC.code},'S01')); i14 = find(strcmp({SC.code},'S14'));
nofa = (sum(A{i1}.trip) == 0) && (sum(A{i14}.trip) == 0) && ...
       (A{i1}.deg_dwell == 0) && (A{i14}.deg_dwell == 0) && ...
       (A{i1}.n_reject == 0) && (A{i14}.n_reject == 0);
G = g7_add(G,'HG3','No false FDIR: NOMINAL and CONFOUNDER_BENIGN produce zero monitor trips, zero degraded dwell, zero rejects', ...
    nofa, sprintf('S01 trips=%d dwell=%.3f rej=%d | S14 trips=%d dwell=%.3f rej=%d (confounder events planted=%d)', ...
    sum(A{i1}.trip), A{i1}.deg_dwell, A{i1}.n_reject, sum(A{i14}.trip), A{i14}.deg_dwell, A{i14}.n_reject, M.n_confounder_events));

G = g7_add(G,'HG4','Every injected fault detected inside its declared bound (from fault onset AND from condition crossing)', ...
    (M.n_missed == 0) && (M.n_detect_late == 0) && (M.n_detect_ok == M.n_detect_expected), ...
    sprintf('detected %d/%d expected, late=%d, missed=%d, worst onset-latency margin %.4f s', ...
    M.n_detect_ok, M.n_detect_expected, M.n_detect_late, M.n_missed, g7_worst_margin(M.lat_inj)));

G = g7_add(G,'HG5','Zero false alarms across the whole matrix (no monitor trips outside its declared scenario)', ...
    M.n_false_alarm == 0, sprintf('false alarms=%d over %d cases', M.n_false_alarm, M.n_cases));

iso = M.n_isolation_ok == M.n_cases;
G = g7_add(G,'HG6','Correct isolation: the active-monitor set equals the declared expected set in every case', ...
    iso, sprintf('%d/%d cases with exact monitor-set match', M.n_isolation_ok, M.n_cases));

i15 = find(strcmp({SC.code},'S15'));
a15 = A{i15};
L15 = a15.L; topcol = L15(:,5);
t_leak = a15.det_t(1); t_uv = a15.det_t(2);
prec_ok = true;
if ~isnan(t_leak)
    prec_ok = prec_ok && all(topcol(L15(:,1) >= t_leak) == 1);
else
    prec_ok = false;
end
if ~isnan(t_uv) && ~isnan(t_leak)
    win = (L15(:,22) == 1) & (L15(:,1) >= t_uv) & (L15(:,1) < t_leak);
    prec_ok = prec_ok && any(win) && all(topcol(win) == 2);
    win9 = (L15(:,25) == 1) & (L15(:,22) == 0) & (L15(:,1) < t_leak);
    prec_ok = prec_ok && any(win9) && all(topcol(win9) == 9);
end
lat_ok = a15.recovered == 0 && a15.trip(1);
G = g7_add(G,'HG7','Precedence and latching: LEAK > UNDERVOLTAGE > MISSION_STALE, and LEAK latches (no auto-clear)', ...
    prec_ok && lat_ok, sprintf('S15 top-monitor precedence ok=%d, leak latched to horizon=%d (safe-hold dwell %.2f s)', ...
    prec_ok, lat_ok, a15.sh_dwell));

% ---------------- HG8, repaired acceptance semantics ----------------
rec_ok = true; rec_det = ''; cls_txt = '';
for i = 1:numel(A)
    cls = SC(i).rec_class;
    ep_ok = (A{i}.episodes == SC(i).expect_episodes);
    dw_ok = (A{i}.deg_dwell == 0) || (A{i}.deg_dwell >= C.min_dwell);
    switch cls
        case 'not_applicable_no_degradation'
            ok_i = (sum(A{i}.trip) == 0) && (A{i}.episodes == 0) && (A{i}.deg_dwell == 0);
        case 'must_recover'
            ok_i = (A{i}.recovered == 1) && ep_ok && dw_ok;
        otherwise
            ok_i = (A{i}.recovered == 0) && ep_ok && dw_ok;
    end
    if ~ok_i
        rec_ok = false;
        rec_det = [rec_det sprintf('%s[%s rec=%d ep %d/%d dwell %.2f] ', SC(i).code, cls, ...
            A{i}.recovered, A{i}.episodes, SC(i).expect_episodes, A{i}.deg_dwell)]; %#ok<AGROW>
    end
end
nmr = sum(strcmp({SC.rec_class},'must_recover'));
nmn = sum(strcmp({SC.rec_class},'must_not_recover'));
nna = sum(strcmp({SC.rec_class},'not_applicable_no_degradation'));
GS = M.act_gap_sev;
if isempty(GS)
    act_ok = true; gtxt = 'no detected monitors';
else
    act_ok = all(~isnan(GS(:,2))) && all(GS(:,2) <= GS(:,3) + 1e-9);
    gtxt = sprintf('worst severity-based detect-to-action %.4f s over %d detections (bound %.3f s), no NaN', ...
        max(GS(:,2)), size(GS,1), C.act_gap_bound);
end
if isempty(rec_det)
    cls_txt = sprintf('all %d cases meet their three-valued recovery expectation (%d must_recover, %d must_not_recover, %d not_applicable_no_degradation); min dwell %.1f s respected; %s', ...
        numel(A), nmr, nmn, nna, C.min_dwell, gtxt);
else
    cls_txt = sprintf('violations: %s| classes %d/%d/%d; %s', rec_det, nmr, nmn, nna, gtxt);
end
hg8_req = ['Recovery hysteresis without chatter under a REPAIRED three-valued expectation ' ...
    '{must_recover / must_not_recover / not_applicable_no_degradation}: one degraded episode per injected fault, ' ...
    'min dwell respected, recovery asserted only where degradation is expected; fault-free cases are not_applicable ' ...
    'and must instead show zero trips, zero episodes and zero degraded dwell; and the REPAIRED detect-to-action ' ...
    '(time until the active response severity reaches the severity this monitor requires, an already-active ' ...
    'higher-severity response counting as immediate) is inside its unchanged declared bound'];
G = g7_add(G,'HG8', hg8_req, rec_ok && act_ok, cls_txt);

sm = zeros(numel(A),4); ok_bl = true;
for i = 1:numel(A)
    sm(i,:) = A{i}.step_max;
    ok_bl = ok_bl && all(A{i}.step_max <= A{i}.step_lim + 1e-6);
end
G = g7_add(G,'HG9','Bumpless bounded output: no reference step beyond the local rate envelope at any tick, including mode transitions', ...
    ok_bl && M.rate_viol == 0 && M.mag_viol == 0, ...
    sprintf('rate violations=%d, magnitude violations=%d, worst step/limit ratio=%.4f', ...
    M.rate_viol, M.mag_viol, max(max(sm ./ repmat(A{1}.step_lim,numel(A),1)))));

G = g7_add(G,'HG10','Zero surface, zero automatic accommodation, zero direct-actuator mission commands issued', ...
    M.iss_surface == 0 && M.iss_accom == 0 && M.iss_direct_act == 0, ...
    sprintf('issued surface=%d accommodation=%d direct-actuator=%d (requested by mission and rejected: %d / %d / %d)', ...
    M.iss_surface, M.iss_accom, M.iss_direct_act, M.req_surface, M.req_accom, M.req_direct_act));

dmin = min(cellfun(@(a) a.depth_min, A));
dmax = max(cellfun(@(a) a.depth_max, A));
G = g7_add(G,'HG11','Path / reference governance: curvature, slope, rate and depth bounds respected; mission hints clamped, never obeyed raw', ...
    M.bnd_viol == 0 && M.hint_unclamped == 0 && dmin >= 0.2 && dmax <= C.depth_max, ...
    sprintf('bound violations=%d, clamp events=%d, unclamped hints=%d, kappa_max=%.4f/%.2f, slope_max=%.2f/%.1f deg, depth [%.2f %.2f] m', ...
    M.bnd_viol, M.clamp_events, M.hint_unclamped, max(C.kappa_path), C.kappa_max, ...
    max(cellfun(@(a) a.slope_max_cmd, A)), C.slope_max, dmin, dmax));

G = g7_add(G,'HG12','Ack / rejection codes exact: every invalid message rejected with the independently specified code, every valid message accepted', ...
    M.n_ack_mismatch == 0, sprintf('%d acks, %d accepted, %d rejected, %d code mismatches', ...
    M.n_msgs, M.n_accept, M.n_reject, M.n_ack_mismatch));

G = g7_add(G,'HG13','Production + CODEX_VERTICAL_PLAN byte-identical, and the prior Gate 7 artifacts preserved', ...
    true, 'evaluated after artifact write');

G = g7_add(G,'HG14','Artifacts written and total footprint < 300 MiB', true, 'evaluated after artifact write');

hon = ~isempty(strfind(C.rate_labels{4},'TO_BE_IDENTIFIED')) && ...
      ~isempty(strfind(C.rate_labels{5},'TO_BE_IDENTIFIED')) && ...
      ~isempty(strfind(R.certification,'NOT_CERTIFIED')) && ...
      ~isempty(strfind(R.honesty,'Production untouched'));
G = g7_add(G,'HG15','Label honesty: mission/nav/actuator-feedback rates remain TO_BE_IDENTIFIED, every fault number ASSUMED, hardware NOT_CERTIFIED', ...
    hon, 'mission/nav rates TO_BE_IDENTIFIED (ASSUMED sim placeholders); fault schedule ASSUMED and unchanged; verdict scope = simulation only');

G = g7_add(G,'HG16','Raw-behaviour parity: every frozen case input, event schedule, threshold, output time series and per-case hash, and every unaffected metric, is exactly equal to the prior Gate 7 MAT', ...
    PAR.all_ok, sprintf(['hashA=%s hashB=%s replay_flags=%s | per_case: %s | metrics: %s | scenarios: %s | ' ...
    'cfg inherited+derived-rechecked=%s | time series: %s'], ...
    g7_yn(PAR.hashA_ok), g7_yn(PAR.hashB_ok), g7_yn(PAR.replay_ok), PAR.percase_det, PAR.metrics_det, ...
    PAR.scenarios_det, g7_yn(PAR.cfg_ok), PAR.timeseries_det));

G = g7_add(G,'HG17','Criterion scope: the only changes are the three-valued recovery expectation and the severity-based detect-to-action field; no field removed, no undeclared field added, S01/S14 are not_applicable_no_degradation, and the class map is a pure function of the frozen prior expectation', ...
    SCOPE.all_ok, sprintf(['per-case added {%s} removed {%s}; metrics added {%s} removed {%s}; scenario added {%s} removed {%s}; ' ...
    'S01 N/A=%s, S14 N/A=%s, class map pure=%s'], ...
    strjoin(SCOPE.pc_added,','), strjoin(SCOPE.pc_removed,','), strjoin(SCOPE.m_added,','), strjoin(SCOPE.m_removed,','), ...
    strjoin(SCOPE.sc_added,','), strjoin(SCOPE.sc_removed,','), ...
    g7_yn(SCOPE.s01_na), g7_yn(SCOPE.s14_na), g7_yn(SCOPE.class_map_ok)));

if all([G.pass]); verdict = 'PASS'; elseif any([G.pass]); verdict = 'PARTIAL'; else; verdict = 'FAIL'; end
end

function G = g7_add(G, id, req, ps, det)
G(end+1) = struct('id',id,'req',req,'pass',double(ps),'detail',det);
end

function w = g7_worst_margin(T)
if isempty(T); w = NaN; return; end
w = min(T(:,3) - T(:,2));
end

% ======================================================================
%  plots (visual QA) - display fixes only, no data change
% ======================================================================
function g7r_plot(C, SC, A, M, G, R, pngf)
n = numel(A);
fh = figure('Visible','off','Color','w','Position',[40 40 1720 1040]);

% (1) mode timeline for the whole matrix
subplot(3,3,1);
dec = 8;
nt = floor(size(A{1}.L,1)/dec);
Mt = zeros(n,nt);
for i = 1:n
    Li = A{i}.L;
    Mt(i,:) = Li(1:dec:dec*nt,4)';
end
imagesc((1:nt)*dec*C.T_ctrl, 1:n, Mt); set(gca,'YDir','normal');
caxis([0 3]); colormap(gca, [0.85 0.92 0.85; 0.98 0.90 0.55; 0.98 0.70 0.35; 0.85 0.35 0.35]);
try
    cb = colorbar('Ticks',[0 1 2 3],'TickLabels',{'FOLLOW','HOLD-LAST','CONSTRAIN','SAFE-HOLD'});
    set(cb,'FontSize',7);
    try; set(cb,'TickLabelInterpreter','none'); catch; end
catch
    colorbar;
end
set(gca,'YTick',1:n,'YTickLabel',{SC.code},'FontSize',7);
try; set(gca,'TickLabelInterpreter','none'); catch; end
xlabel('t [s]'); title('FDIR response ladder, all 16 cases (sim)','FontSize',9);

% (2) S15 multi-fault precedence detail
i15 = find(strcmp({SC.code},'S15')); L = A{i15}.L;
subplot(3,3,2);
plot(L(:,1),L(:,4),'k-','LineWidth',1.3); hold on;
plot(L(:,1),L(:,5),'b--','LineWidth',1.0);
plot(L(:,1),L(:,17)*3,'g-','LineWidth',0.8);
grid on; ylim([-0.5 9.5]);
legend({'mode','top monitor','V_{pu} x3'},'Location','northwest','FontSize',7);
xlabel('t [s]'); title('S15 precedence: leak > undervoltage > mission stale','FontSize',9);

% (3) detection latency AND repaired severity-based action gap vs bounds
subplot(3,3,3);
T = M.lat_inj; GS = M.act_gap_sev;
if ~isempty(T)
    r1 = T(:,2)./max(T(:,3),eps);
    r2 = zeros(size(r1));
    if ~isempty(GS); r2 = GS(:,2)./max(GS(:,3),eps); end
    bar(1:size(T,1), [r1 r2], 1.0); hold on;
    plot([0 size(T,1)+1],[1 1],'r--','LineWidth',1.2);
    set(gca,'XTick',1:size(T,1),'XTickLabel',strrep(C.mon_name(T(:,1)),'_','-'),'FontSize',6);
    try; set(gca,'TickLabelInterpreter','none'); catch; end
    try; set(gca,'XTickLabelRotation',60); catch; end
    ylabel('value / declared bound'); ylim([0 1.3]); xlim([0.3 size(T,1)+0.7]);
    legend({'detect latency','action gap (repaired)'},'Location','northwest','FontSize',6);
end
grid on; title('detection latency and repaired action gap vs bounds','FontSize',9);

% (4) bounded refs and bumpless transfer, S05 heartbeat loss
i5 = find(strcmp({SC.code},'S05')); L = A{i5}.L;
subplot(3,3,4);
plot(L(:,1),L(:,7),'b-','LineWidth',1.1); hold on;
plot(L(:,1),L(:,11),'c--','LineWidth',0.9);
plot(L(:,1),[0;diff(L(:,7))]/C.T_guid,'m-','LineWidth',0.6);
plot([L(1,1) L(end,1)], [C.pitch_ref_max C.pitch_ref_max],'r--');
plot([L(1,1) L(end,1)],-[C.pitch_ref_max C.pitch_ref_max],'r--');
plot([L(1,1) L(end,1)], [C.pitch_ref_rate_max C.pitch_ref_rate_max],'r:');
grid on; xlabel('t [s]'); ylabel('deg, deg/s');
legend({'pitch_{ref}','theta','d/dt pitch_{ref}','mag limit','','rate limit'},'Location','southwest','FontSize',6);
title('S05 heartbeat loss: bounded + bumpless refs','FontSize',9);

% (5) depth / no-auto-surface evidence
subplot(3,3,5);
hold on;
for i = 1:n
    L = A{i}.L; plot(L(:,1),L(:,13),'-','LineWidth',0.7);
end
plot([0 C.T_end],[C.depth_min C.depth_min],'r--','LineWidth',1.2);
set(gca,'YDir','reverse'); grid on;
xlabel('t [s]'); ylabel('depth (+z down) [m]');
title(sprintf('depth, all cases: min %.2f m, no auto-surface', min(cellfun(@(a)a.depth_min,A))),'FontSize',9);

% (6) 3D mission geometry, framed to the traversed extent (fix: was under-filled)
subplot(3,3,6);
i1 = find(strcmp({SC.code},'S01')); L1 = A{i1}.L; L5 = A{i5}.L;
plot3(C.wp(:,1),C.wp(:,2),C.wp(:,3),'ks--','LineWidth',1.0,'MarkerFaceColor','y'); hold on;
plot3(L1(:,29),L1(:,30),L1(:,13),'b-','LineWidth',1.1);
plot3(L5(:,29),L5(:,30),L5(:,13),'r-','LineWidth',1.0);
idg = find(L5(:,4) > 0);
if ~isempty(idg)
    plot3(L5(idg,29),L5(idg,30),L5(idg,13),'m.','MarkerSize',4);
end
xlabel('N [m]'); ylabel('E [m]'); zlabel('D [m]');
set(gca,'ZDir','reverse'); grid on; view(-38,22);
legend({'waypoints','S01 nominal','S05','S05 degraded'},'Location','northeast','FontSize',6);
XX = [L1(:,29); L5(:,29); C.wp(1:2,1)];
YY = [L1(:,30); L5(:,30); C.wp(1:2,2)];
ZZ = [L1(:,13); L5(:,13); C.wp(1:2,3)];
xl = g7r_pad([min(XX) max(XX)]); yl = g7r_pad([min(YY) max(YY)]); zl = g7r_pad([min(ZZ) max(ZZ)]);
try
    xlim(xl); ylim(yl); zlim(zl);
catch
end
title('constrained-3D geometry (NED), zoomed to traversed extent','FontSize',9);

% (7) ack / reject histogram
subplot(3,3,7);
bar(0:8, M.reject_hist, 'FaceColor',[0.45 0.60 0.40]);
set(gca,'XTick',0:8,'XTickLabel',{'OK','SCHEMA','FRAME','INTEG','ORDER','EXPIRE','BOUNDS','LINK','FORBID'},'FontSize',6);
try; set(gca,'TickLabelInterpreter','none'); catch; end
try; set(gca,'XTickLabelRotation',60); catch; end
grid on; ylabel('messages'); title(sprintf('Ack codes (%d msgs, %d mismatch)', M.n_msgs, M.n_ack_mismatch),'FontSize',9);

% (8) dwell per case, annotated with the repaired three-valued class
subplot(3,3,8);
D = [cellfun(@(a)a.hls_dwell,A); cellfun(@(a)a.con_dwell,A); cellfun(@(a)a.sh_dwell,A)]';
bar(D,'stacked'); grid on; hold on;
lbl = cell(1,n);
for i = 1:n
    switch SC(i).rec_class
        case 'must_recover';  lbl{i} = [SC(i).code ' R'];
        case 'must_not_recover'; lbl{i} = [SC(i).code ' N'];
        otherwise; lbl{i} = [SC(i).code ' -'];
    end
end
set(gca,'XTick',1:n,'XTickLabel',lbl,'FontSize',6);
try; set(gca,'TickLabelInterpreter','none'); catch; end
try; set(gca,'XTickLabelRotation',60); catch; end
ylabel('dwell [s]'); legend({'hold-last-safe','constrain','safe-hold'},'Location','northwest','FontSize',6);
title('ladder dwell per case (R must recover, N must not, - N/A)','FontSize',9);

% (9) gate summary
subplot(3,3,9);
p = [G.pass];
barh(1:numel(p), p, 'FaceColor',[0.25 0.55 0.30]); hold on;
for i = 1:numel(p)
    if ~p(i); barh(i, 1, 'FaceColor',[0.80 0.25 0.25]); end
end
set(gca,'YTick',1:numel(p),'YTickLabel',{G.id},'FontSize',6,'YDir','reverse');
try; set(gca,'TickLabelInterpreter','none'); catch; end
xlim([0 1.15]); grid on;
title(sprintf('hard gates %d/%d  |  %s  |  NOT_CERTIFIED', sum(p), numel(p), R.verdict),'FontSize',9,'Interpreter','none');

try
    annotation(fh,'textbox',[0.005 0.963 0.99 0.035],'String', ...
        ['GATE7_FDIR_ACCEPTANCE_CRITERION_REPAIR_001  -  acceptance-criterion repair + identical re-run  -  ' ...
         'SIMULATION ONLY  -  production untouched  -  rates TO_BE_IDENTIFIED  -  fault schedule ASSUMED and unchanged  -  NOT_CERTIFIED'], ...
        'EdgeColor','none','FontSize',8,'FontWeight','bold','HorizontalAlignment','center', ...
        'Interpreter','none');
catch
end
print(fh,'-dpng','-r100',pngf);
close(fh);
end

function v = g7r_pad(v)
if ~isfinite(v(1)) || ~isfinite(v(2)); v = [0 1]; return; end
d = v(2) - v(1);
if d <= 1e-6; d = 1; end
v = [v(1)-0.08*d, v(2)+0.08*d];
end

% ======================================================================
%  report
% ======================================================================
function g7r_report(TAG, SR, C, SC, A, M, R, G, R0)
f = fopen(fullfile(SR,[TAG '.md']),'w');
w = @(varargin) fprintf(f, varargin{:});

w('# GATE7_FDIR_ACCEPTANCE_CRITERION_REPAIR - %s\n\n', R.task_id);
w('**Date:** %s  \n', R.created);
w('**Class:** Gate 7 attempt 2 - acceptance-criterion repair + bit-identical re-run of the frozen 16-case matrix  \n');
w('**MATLAB runs:** 1 (single invocation, no retry) - **production edits:** NO - **CODEX_VERTICAL_PLAN:** untouched - **prior Gate 7 artifacts:** preserved  \n');
w('**Physical / hardware readiness:** **NOT_CERTIFIED** (simulation-only; no HIL, no bench)  \n');
w('**Verdict:** **%s** (%d/%d hard gates)\n\n', R.verdict, sum([G.pass]), numel(G));

w('## 0. Scope of this task (what was and was not changed)\n\n');
w('| Item | Status |\n|---|---|\n');
w('| Monitor set, precedence, latching, hysteresis | **unchanged** (inherited verbatim) |\n');
w('| Thresholds, debounces, declared bounds | **unchanged** (inherited from the prior MAT and re-derived from the same primitives) |\n');
w('| Injection windows, scenario matrix, 16 cases | **unchanged** (rebuilt with identical code and compared element-by-element) |\n');
w('| Plant surrogate, clocks, envelopes, power model | **unchanged** |\n');
w('| Recovery acceptance criterion | **repaired**: binary `expect_recover` replaced by `{must_recover, must_not_recover, not_applicable_no_degradation}` |\n');
w('| Detect-to-action metric | **repaired**: time until the ACTIVE response severity reaches the severity the monitor requires |\n');
w('| Figure banner TeX underscores, panel-6 framing | **fixed** (display only, no data change) |\n');
w('| Tuning, promotion, production wiring | **none** |\n');

w('\n## Sources (strict, exactly 3)\n\n');
w('| # | Path | Role | Fingerprint |\n|---|------|------|-------------|\n');
rl = {'Attempt-1 driver: the exact simulation logic re-executed here (copied verbatim, not modified in place)', ...
      'Attempt-1 result MAT: frozen config, scenario matrix, per-case logs, hashes and metrics used as the parity oracle', ...
      'Attempt-1 report: the recorded PARTIAL verdict, the HG8 defect, the detect-to-action defect and the two cosmetic figure defects'};
for i = 1:3
    w('| %d | `%s` | %s | `%s` |\n', i, strrep(R.sources{i},'\','/'), rl{i}, R.src_fp{i});
end
w('\nUpstream frozen sources are **not** re-read here; they are carried forward from the prior MAT:\n\n');
w('| # | Path | Fingerprint recorded by attempt 1 |\n|---|---|---|\n');
for i = 1:numel(R.prior.sources)
    w('| %d | `%s` | `%s` |\n', i, strrep(R.prior.sources{i},'\','/'), R.prior.src_fp{i});
end
w('\nGate 6B precondition inherited through attempt 1: `%s` verdict **%s**.\n\n', R.prior.gate6b.task_id, R.prior.gate6b.verdict);

w('### Source-binding checks\n\n| Check | Result |\n|-------|--------|\n');
bf = fieldnames(R.source_binding);
for i = 1:numel(bf)
    w('| `%s` | %s |\n', bf{i}, g7_yn(R.source_binding.(bf{i})));
end

w('\n## 1. The two repaired acceptance definitions\n\n');
w('### 1.1 Three-valued recovery expectation\n\n');
w('Attempt 1 compared a binary flag `expect_recover` against an observable `recovered` defined as ');
w('"the last %.1f s of the run is in MISSION_FOLLOW". A case that never degrades satisfies that observable trivially, ');
w('so `S01 NOMINAL` and `S14 CONFOUNDER_BENIGN` failed a comparison that should never have been applied to them.\n\n', C.min_dwell);
w('| Class | Meaning | Assertion |\n|---|---|---|\n');
w('| `must_recover` | degradation is expected and the vehicle must return to MISSION_FOLLOW | `recovered == 1`, episode count matches, min dwell respected |\n');
w('| `must_not_recover` | degradation is expected and must persist to the horizon (latching leak) | `recovered == 0`, episode count matches, min dwell respected |\n');
w('| `not_applicable_no_degradation` | no fault is injected, so recovery is not a meaningful assertion | zero trips **and** zero episodes **and** zero degraded dwell; `recovered` is not consulted |\n');
w('\nThe class is a pure function of the frozen attempt-1 schedule: a case with no expected monitor, no injection window and ');
w('zero expected episodes is `not_applicable_no_degradation`; otherwise the class is `must_recover` when the frozen ');
w('`expect_recover` was 1 and `must_not_recover` when it was 0. No case changed its injected content.\n\n');
w('| Code | Scenario | Frozen expect_recover | Repaired class |\n|---|---|---|---|\n');
for i = 1:numel(SC)
    w('| %s | %s | %d | `%s` |\n', SC(i).code, SC(i).name, SC(i).expect_recover, SC(i).rec_class);
end

w('\n### 1.2 Severity-based detect-to-action\n\n');
w('Attempt 1 measured "time from detection to the next mode change". When a higher-precedence monitor has already ');
w('forced an equal or more severe response, there is no next mode change to observe and the metric either overstated ');
w('the delay (`S06`/`M9`: 0.2250 s against a 0.200 s bound) or returned `NaN` (`S15`/`M1`, `S15`/`M2`).\n\n');
w('Repaired definition: the required response severity of monitor `m` is its declared ladder level `mon_mode(m)` ');
w('(0 MISSION_FOLLOW, 1 HOLD_LAST_SAFE, 2 CONSTRAIN, 3 SAFE_HOLD). The action time is the first logged instant at or after ');
w('detection at which the active mode is **at least** that severe. If the active mode already satisfies the requirement at ');
w('detection, the gap is exactly 0 (the required response is already in force). Bound unchanged at %.3f s.\n\n', C.act_gap_bound);
w('| Case | Monitor | Required response | Detect [s] | Action [s] | Repaired gap [s] | Bound [s] | Attempt-1 gap [s] |\n');
w('|---|---|---|---|---|---|---|---|\n');
for i = 1:numel(A)
    a = A{i};
    for m = find(SC(i).expect)
        if a.trip(m)
            w('| %s | M%d %s | %s | %.4f | %.4f | %.4f | %.3f | %s |\n', a.code, m, C.mon_name{m}, ...
              g7r_mode_name(a.act_req_mode(m)), a.det_t(m), a.t_action_sev(m), a.act_gap_sev(m), ...
              C.act_gap_bound, g7r_num(a.act_gap(m)));
        end
    end
end

GSr = M.act_gap_sev;
if ~isempty(GSr) && all(GSr(:,2) == 0)
    w(['\nEvery repaired gap in the table above is exactly 0. That is a direct consequence of the frozen schedule, not a ' ...
       'favourable rounding: the watchdog/FDIR task and the controller share the same %.0f ms tick in this harness, so the ' ...
       'response-ladder level computed at the detecting watchdog tick is already present in the log sample emitted by that ' ...
       'same tick. The metric therefore has no resolution below one controller period here, and it is reported as a ' ...
       'consistency check on the ladder, not as a measured latency. A real system with asynchronous safety and control ' ...
       'tasks would show a non-zero gap; that remains `TO_BE_IDENTIFIED`.\n'], C.T_ctrl*1000);
else
    w(['\nThe repaired gap is bounded by one controller period by construction, because the watchdog/FDIR task and the ' ...
       'controller share the same %.0f ms tick in this harness.\n'], C.T_ctrl*1000);
end

w('\n## 2. Raw-behaviour parity against the prior MAT\n\n');
w('| Compared object | Requirement | Result |\n|---|---|---|\n');
w('| Per-case hash, pass A | exact equality with `R.replay_hash_A` | %s |\n', g7_yn(R.parity.hashA_ok));
w('| Per-case hash, pass B | exact equality with `R.replay_hash_B` | %s |\n', g7_yn(R.parity.hashB_ok));
w('| Replay flags | exact equality | %s |\n', g7_yn(R.parity.replay_ok));
w('| Per-case struct (all attempt-1 fields, incl. full log matrix and Ack matrix) | exact equality | %s - %s |\n', ...
  g7_yn(R.parity.percase_ok), R.parity.percase_det);
w('| Logged time series and Ack matrices, re-asserted directly | exact equality | %s - %s |\n', ...
  g7_yn(R.parity.timeseries_ok), R.parity.timeseries_det);
w('| Aggregate metrics (all attempt-1 fields) | exact equality | %s - %s |\n', ...
  g7_yn(R.parity.metrics_ok), R.parity.metrics_det);
w('| Scenario matrix (windows, expected monitors, injection onsets, confounder flag, episodes, notes) | exact equality | %s - %s |\n', ...
  g7_yn(R.parity.scenarios_ok), R.parity.scenarios_det);
w('| Configuration | inherited verbatim; every derived threshold re-derived from primitives and matched | %s |\n', g7_yn(R.parity.cfg_ok));
w('\nOnly the acceptance fields and the derived action-latency field differ, plus the regenerated display artifacts:\n\n');
w('| Object | Fields added | Fields removed |\n|---|---|---|\n');
w('| per-case | `%s` | %s |\n', strjoin(R.scope.pc_added,'`, `'), g7r_empty(R.scope.pc_removed));
w('| metrics | `%s` | %s |\n', strjoin(R.scope.m_added,'`, `'), g7r_empty(R.scope.m_removed));
w('| scenario | `%s` | %s |\n', strjoin(R.scope.sc_added,'`, `'), g7r_empty(R.scope.sc_removed));

w('\n## 3. Results (identical to attempt 1 by construction, re-reported)\n\n');
w('| Code | Msgs | Acc | Rej | Ack mismatch | Trips | Expected | FA | Missed | Episodes | HLS [s] | CONSTR [s] | SAFE_HOLD [s] | Recovered | Class | Class met | Replay |\n');
w('|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|\n');
for i = 1:numel(A)
    a = A{i};
    tr = 'none'; if any(a.trip); tr = strjoin(cellfun(@(k) sprintf('M%d',k), num2cell(find(a.trip)),'UniformOutput',false),','); end
    ex = 'none'; if any(SC(i).expect); ex = strjoin(cellfun(@(k) sprintf('M%d',k), num2cell(find(SC(i).expect)),'UniformOutput',false),','); end
    met = g7r_class_met(C, SC(i), a);
    rec_s = sprintf('%d', a.recovered);
    if strcmp(SC(i).rec_class,'not_applicable_no_degradation'); rec_s = sprintf('%d (N/A)', a.recovered); end
    w('| %s | %d | %d | %d | %d | %s | %s | %d | %d | %d | %.2f | %.2f | %.2f | %s | `%s` | %s | %s |\n', ...
      a.code, a.n_msgs, a.n_accept, a.n_reject, a.ack_mismatch, tr, ex, a.false_alarms, a.missed, ...
      a.episodes, a.hls_dwell, a.con_dwell, a.sh_dwell, rec_s, SC(i).rec_class, g7_yn(met), g7_yn(R.replay_ok(i)));
end

w('\n### Detection delays vs declared bounds (unchanged numbers)\n\n');
w('| Case | Monitor | Latency from fault onset [s] | Bound [s] | Margin [s] | Latency from condition crossing [s] | Bound [s] |\n');
w('|---|---|---|---|---|---|---|\n');
for i = 1:numel(A)
    a = A{i};
    for m = find(SC(i).expect)
        if a.trip(m)
            w('| %s | M%d %s | %.4f | %.3f | %+.4f | %.4f | %.3f |\n', a.code, m, C.mon_name{m}, ...
              a.lat_inj(m), C.bnd_inj(m), C.bnd_inj(m)-a.lat_inj(m), a.lat_cond(m), C.bnd_cond(m));
        else
            w('| %s | M%d %s | **NOT DETECTED** | %.3f | - | - | - |\n', a.code, m, C.mon_name{m}, C.bnd_inj(m));
        end
    end
end

w('\n### Counts\n\n| Quantity | Value |\n|---|---|\n');
w('| Scenarios | %d (x2 passes = %d deterministic executions) |\n', M.n_cases, 2*M.n_cases);
w('| Mission messages delivered / accepted / rejected | %d / %d / %d |\n', M.n_msgs, M.n_accept, M.n_reject);
w('| Ack code mismatches vs independently specified ground truth | %d |\n', M.n_ack_mismatch);
w('| Reject histogram [OK SCHEMA FRAME INTEG ORDER EXPIRE BOUNDS LINK FORBID] | [%s] |\n', num2str(M.reject_hist));
w('| Expected detections / detected in bound / late / missed | %d / %d / %d / %d |\n', ...
  M.n_detect_expected, M.n_detect_ok, M.n_detect_late, M.n_missed);
w('| Isolation exact (monitor set == expected set) | %d / %d cases |\n', M.n_isolation_ok, M.n_cases);
w('| False alarms | %d |\n', M.n_false_alarm);
w('| Benign confounder events planted (must not trip) | %d |\n', M.n_confounder_events);
w('| Mission hint clamp events / unclamped | %d / %d |\n', M.clamp_events, M.hint_unclamped);
w('| Surface commands requested by mission / issued | %d / **%d** |\n', M.req_surface, M.iss_surface);
w('| Direct-actuator commands requested / issued | %d / **%d** |\n', M.req_direct_act, M.iss_direct_act);
w('| Accommodation requests / automatic accommodations performed | %d / **%d** |\n', M.req_accom, M.iss_accom);
w('| Magnitude / rate / bound violations | %d / %d / %d |\n', M.mag_viol, M.rate_viol, M.bnd_viol);
w('| Monotonic seq and t_mono on every emission | %s |\n', g7_yn(M.mono_ok));
w('| Worst severity-based detect-to-action (repaired) | %.4f s (bound %.3f s) |\n', M.act_gap_sev_worst, C.act_gap_bound);
w('| Worst next-mode-change gap (attempt-1 definition, retained for comparison) | %.4f s |\n', g7_maxcol(M.act_gap));

w('\n## 4. Pareto tracking vector\n\n');
w('| Axis | Value | Note |\n|---|---|---|\n');
w('| Tracking | mean surrogate path error %.3f m, max %.3f m (MISSION_FOLLOW only) | surrogate geometry, **not** a production tracking metric |\n', ...
  mean(cellfun(@(a)a.cte_mean,A)), max(cellfun(@(a)a.cte_max,A)));
w('| Actuator margin | min elevator margin %.3f, min rudder margin %.3f of frozen envelope | envelopes %.0f/%.0f deg, %.0f deg/s inherited |\n', ...
  min(cellfun(@(a)a.act_margin_de,A)), min(cellfun(@(a)a.act_margin_dr,A)), C.de_max, C.dr_max, C.rate_max);
w('| Energy | mean thrust^2 proxy %.4f, max thrust %.3f pu | inherited power model, no re-measurement |\n', ...
  mean(cellfun(@(a)a.energy_proxy,A)), max(cellfun(@(a)a.thr_max,A)));
w('| Estimation | **N/A** | measured/estimated streams are `NOT_IMPLEMENTED` until Gate 5; no NEES claim |\n');
w('| Timing | controller deadline misses %d (injected), watchdog misses %d, **repaired** detect->action worst %.4f s (bound %.3f s) | Gate 6B budgets inherited, no new WCET claim |\n', ...
  sum(cellfun(@(a)a.n_ctrl_miss,A)), sum(cellfun(@(a)a.n_wd_miss,A)), M.act_gap_sev_worst, C.act_gap_bound);
w('| Safety | false alarms %d, missed detections %d, surface/accommodation/direct-actuator commands %d/%d/%d, min depth %.2f m | local safety authority always wins |\n', ...
  M.n_false_alarm, M.n_missed, M.iss_surface, M.iss_accom, M.iss_direct_act, min(cellfun(@(a)a.depth_min,A)));

w('\n## 5. Hard gates (15 original with HG8 repaired, plus HG16 parity and HG17 criterion scope)\n\n');
w('| ID | Requirement | Result | Detail |\n|---|---|---|---|\n');
for i = 1:numel(G)
    w('| %s | %s | %s | %s |\n', G(i).id, G(i).req, g7_pf(G(i).pass), G(i).detail);
end

w('\n## 6. Preservation\n\n');
w('### Production and plan\n\n| File | Fingerprint pre | Fingerprint post | Identical | Matches attempt-1 record |\n|---|---|---|---|---|\n');
for i = 1:numel(R.prod_files)
    w('| `%s` | `%s` | `%s` | %s | %s |\n', strrep(R.prod_files{i},'\','/'), R.fp_pre{i}, R.fp_post{i}, ...
      g7_yn(strcmp(R.fp_pre{i},R.fp_post{i})), g7_yn(R.fp_prior_match(i)));
end
w('\n### Prior Gate 7 artifacts (must survive untouched)\n\n| Artifact | Fingerprint pre | Fingerprint post | Identical |\n|---|---|---|---|\n');
for i = 1:numel(R.prior_artifacts)
    w('| `%s` | `%s` | `%s` | %s |\n', strrep(R.prior_artifacts{i},'\','/'), R.fp_prior_art_pre{i}, ...
      R.fp_prior_art_post{i}, g7_yn(strcmp(R.fp_prior_art_pre{i},R.fp_prior_art_post{i})));
end
w('\nThis task writes only `%s.{md,mat,png}` and `%s_run.log`, plus one marked append to each of the three running logs.\n', TAG, TAG);

w('\n## 7. Visual QA (regenerated 9-panel figure)\n\n');
w('| Panel | Content | Change vs attempt 1 |\n|---|---|---|\n');
w('| 1 response-ladder matrix | mode per case over time | colorbar labels de-underscored, tick interpreter set to `none` |\n');
w('| 2 S15 precedence | mode, top monitor, scaled bus voltage | unchanged |\n');
w('| 3 latency vs bound | now grouped bars: detection latency ratio **and** repaired action-gap ratio | new second series, monitor names de-underscored |\n');
w('| 4 S05 bounded/bumpless refs | pitch reference, theta, reference rate, limits | unchanged |\n');
w('| 5 depth, all cases | no-auto-surface evidence | unchanged |\n');
w('| 6 3D geometry | waypoint polyline plus S01/S05 trajectories | **framing fixed**: axes zoomed to the traversed extent with 8%% padding instead of the full waypoint bounding box, so the panel is filled; no data changed, unreached waypoints simply fall outside the view |\n');
w('| 7 Ack histogram | reject-code counts | tick interpreter set to `none` |\n');
w('| 8 ladder dwell | stacked dwell per case, annotated `R` / `N` / `-` for the three-valued class | class annotation added |\n');
w('| 9 gate summary | %d gates | now %d bars |\n', numel(G), numel(G));
w('| banner | task banner | **TeX defect fixed**: annotation drawn with `Interpreter` = `none`, so underscores render literally instead of as subscripts |\n');

w('\n## 8. Honest limits\n\n');
w('1. **Simulation only.** No HIL, no bench, no vehicle. `NOT_CERTIFIED`. This task changed an acceptance definition; it did not add physical evidence of any kind.\n');
w('2. **The vehicle response is an ASSUMED kinematic surrogate**, unchanged from attempt 1, deliberately not the production plant.\n');
w('3. **Every threshold, window and debounce is still ASSUMED** and is byte-identical to attempt 1. Nothing was widened, narrowed, added or removed.\n');
w('4. **Mission / navigation / actuator-feedback rates remain TO_BE_IDENTIFIED.**\n');
w('5. **Repairing an acceptance criterion is not the same as passing a harder test.** The repaired HG8 asserts *less* on `S01`/`S14` about recovery and *more* about their being fault-free; the 14 degrading cases are asserted exactly as before. The repaired detect-to-action asserts a weaker-looking but semantically correct property: it credits a response that is already at or above the required severity. Both changes were named in the attempt-1 report before this run.\n');
w('6. **HG16 is the guard against self-serving repair.** If the acceptance change had leaked into the simulation, the per-case hashes would differ and HG16 would fail. It does not fail, so the underlying behaviour reported here is literally the attempt-1 behaviour.\n');
w('7. **No transport, middleware or wire format** is selected or validated; the message set stays `INTERFACE_SPECIFIED`.\n');
w('8. **Single MATLAB invocation, no retry.** No tuning loop stands behind these numbers.\n');
w('9. **The upstream frozen sources were not re-read.** Their fingerprints are carried forward from the attempt-1 MAT, so this run inherits, rather than re-proves, the Gate 6B precondition and the policy/ICD bindings.\n');
w('10. **HG12 remains a self-consistency check, not an oracle**, exactly as recorded in attempt 1.\n');
w('11. **The repaired detect-to-action metric has one-controller-period resolution.** Watchdog/FDIR and controller run on the same %.0f ms tick here, so a correctly ladder-driven response is always visible in the same logged sample as its detection. The metric can therefore only catch a ladder that fails to escalate at all; it cannot measure sub-tick response latency, and no such latency is claimed.\n', C.T_ctrl*1000);

w('\n## 9. Verdict and next exact task\n\n');
w('**%s** - %d/%d hard gates.\n\n', R.verdict, sum([G.pass]), numel(G));
if strcmp(R.verdict,'PASS')
    w('All Gate 7 hard gates hold under the corrected acceptance semantics, and HG16 shows the underlying simulated behaviour is ');
    w('bit-identical to the attempt-1 run that produced PARTIAL. Zero false alarms, zero surface commands, zero automatic ');
    w('accommodations and zero direct-actuator commands remain. Gate 7 is **PASS at simulation scope only**; no hardware label is ');
    w('upgraded and no safe-mode behaviour is certified. **Gate 8 is unlocked.**\n\n');
    w('**Next exact task:** `gate8_monte_carlo_independent_priors_campaign` - Monte Carlo over the policy Gate 8 factor table ');
    w('(CG/CB +-2 cm per axis, buoyancy +-3%%, sensor bias/delay/dropout per the availability matrix, actuator lag/delay {0,15,30} ms ');
    w('+ jitter, battery/brownout envelopes from Gate 6B), independent draws, percentiles over means, no silent narrowing of priors.\n');
else
    w('Gate 7 is **not** PASS. The failing gates are reported as-is; no threshold was widened, no scenario removed, no metric ');
    w('redefined beyond the two acceptance repairs declared in section 0, and Gate 8 stays locked.\n\n');
    w('**Next exact task (structurally untried):** `gate7_fdir_monitor_observability_separation_audit` - an isolated audit that ');
    w('separates each failing monitor into (a) injection reachability, (b) observable residual, (c) declared bound, so a failure is ');
    w('attributed to schedule, observability or bound choice before any threshold is touched.\n');
end
w('\n**Do not edit:** `suite_results/CODEX_VERTICAL_PLAN.md` and the attempt-1 Gate 7 artifacts (all fingerprinted above).\n');

w('\n## 10. Artifacts\n\n');
w('| Artifact | Size |\n|---|---|\n');
w('| `suite_results/%s.md` | this report |\n', TAG);
w('| `suite_results/%s.mat` | %.2f MiB (config, frozen schedule with repaired classes, per-case logs, parity record, gates) |\n', TAG, R.mat_mib);
w('| `suite_results/%s.png` | %.2f MiB (9-panel visual QA, banner and framing fixed) |\n', TAG, R.png_mib);
w('| `suite_results/%s_run.log` | console transcript |\n', TAG);
w('\nHost runtime %.1f s, free space at start %.2f GiB, MATLAB invocations: 1.\n', R.host_runtime_s, R.free_gib_at_start);
fclose(f);
end

function s = g7r_mode_name(v)
if isnan(v); s = '-'; return; end
switch v
    case 0; s = 'MISSION_FOLLOW';
    case 1; s = 'HOLD_LAST_SAFE';
    case 2; s = 'CONSTRAIN';
    otherwise; s = 'SAFE_HOLD';
end
end

function s = g7r_num(v)
if isnan(v); s = 'NaN'; else; s = sprintf('%.4f', v); end
end

function s = g7r_empty(c)
if isempty(c); s = 'none'; else; s = ['`' strjoin(c,'`, `') '`']; end
end

function tf = g7r_class_met(C, sci, a)
ep_ok = (a.episodes == sci.expect_episodes);
dw_ok = (a.deg_dwell == 0) || (a.deg_dwell >= C.min_dwell);
switch sci.rec_class
    case 'not_applicable_no_degradation'
        tf = (sum(a.trip) == 0) && (a.episodes == 0) && (a.deg_dwell == 0);
    case 'must_recover'
        tf = (a.recovered == 1) && ep_ok && dw_ok;
    otherwise
        tf = (a.recovered == 0) && ep_ok && dw_ok;
end
end

function s = g7_yn(v)
if v; s = 'YES'; else; s = 'NO'; end
end
function s = g7_pf(v)
if v; s = '**PASS**'; else; s = '**FAIL**'; end
end
function v = g7_maxcol(T)
if isempty(T); v = NaN; else; v = max(T(:,2)); end
end

% ======================================================================
%  log appends (once each, marked)
% ======================================================================
function g7r_append_logs(TAG, SR, R, G)
MARK = '<!-- APPEND_MARKER:GATE7_FDIR_ACCEPTANCE_CRITERION_REPAIR_001 -->';
np = sum([G.pass]); ng = numel(G);
blk = sprintf(['\n---\n\n%s\n\n## Append: %s (%s)\n\n' ...
  '**Date:** %s - **Class:** Gate 7 attempt 2, acceptance-criterion repair + identical re-run (**simulation**) - **MATLAB runs:** 1 - **production:** byte-identical - **CODEX_VERTICAL_PLAN:** untouched - **attempt-1 artifacts:** preserved  \n' ...
  '**Verdict:** **%s** (%d/%d hard gates) - **Physical / hardware readiness: NOT_CERTIFIED**\n\n' ...
  '- Repaired exactly two acceptance definitions named by the attempt-1 report: the recovery expectation becomes three-valued (`must_recover` / `must_not_recover` / `not_applicable_no_degradation`, with `S01` and `S14` not applicable but still required to show zero trips, zero episodes and zero degraded dwell), and detect-to-action becomes the time until the active response severity reaches the severity the monitor requires, so an already-active higher-severity response counts as immediate.\n' ...
  '- The identical frozen 16-case matrix was re-executed twice; no method, scenario, threshold, injection window, monitor or plant surrogate changed. Raw-behaviour parity against the attempt-1 MAT is asserted as a hard gate (HG16): per-case hashes, full log and Ack matrices, every unaffected metric, the scenario matrix and the configuration all compare exactly equal (%s).\n' ...
  '- Criterion scope is itself gated (HG17): the only added fields are the three-valued class and the severity-based action-gap trio; nothing was removed.\n' ...
  '- Repaired worst detect-to-action %.4f s against the unchanged %.3f s bound; false alarms %d, missed detections %d, surface / accommodation / direct-actuator commands issued %d / %d / %d.\n' ...
  '- Labels unchanged: mission/nav/actuator-feedback rates `TO_BE_IDENTIFIED`; all fault numbers `ASSUMED`; message contract `INTERFACE_SPECIFIED`; harness `IMPLEMENTED` (simulation); hardware `NOT_CERTIFIED`.\n' ...
  '- Evidence: `suite_results/%s.{md,mat,png}`.\n'], ...
  MARK, R.task_id, R.verdict, R.created, R.verdict, np, ng, g7_yn(R.parity.all_ok), ...
  R.metrics.act_gap_sev_worst, R.cfg.act_gap_bound, R.metrics.n_false_alarm, R.metrics.n_missed, ...
  R.metrics.iss_surface, R.metrics.iss_accom, R.metrics.iss_direct_act, TAG);

tgt = { fullfile(SR,'AUV_REALIZATION_READINESS_PLAN.md'), ...
        fullfile(SR,'AUV_REALISM_AND_VISUAL_VALIDATION.md'), ...
        fullfile(SR,'PITCH_CONTROL_RESEARCH_LOG.md') };
extra = { sprintf('\n**Gate 7 status:** simulation-scope %s under corrected acceptance semantics with attempt-1 raw behaviour proven identical. Gate 8 unlocks only on Gate 7 PASS; hardware terminus unchanged (EXTERNAL after Gate 9).\n', R.verdict), ...
          sprintf('\n**Visual QA:** 9-panel `%s.png`. Two attempt-1 cosmetic defects fixed without touching data: the banner is now drawn with the TeX interpreter disabled so underscores render literally, and the 3D geometry panel is framed to the traversed extent instead of the full waypoint bounding box. Panel 3 additionally shows the repaired severity-based action gap next to the detection latency, and panel 8 annotates each case with its three-valued recovery class.\n', TAG), ...
          sprintf('\n**Research note:** the Gate 7 failure was an acceptance-criterion defect, not a monitor defect; correcting the criterion and re-running bit-identically separates "the test was wrong" from "the system was wrong". No pitch/depth controller was reopened, retuned or promoted by this task.\n') };
for i = 1:3
    prev = '';
    if exist(tgt{i},'file'); prev = fileread(tgt{i}); end
    if ~isempty(strfind(prev, MARK)) %#ok<STREMP>
        fprintf('append marker already present, skipped: %s\n', tgt{i});
        continue;
    end
    fid = fopen(tgt{i},'a');
    if fid < 0
        fprintf(2,'WARN: cannot append to %s\n', tgt{i});
        continue;
    end
    fprintf(fid,'%s%s', blk, extra{i});
    fclose(fid);
    fprintf('appended once (marked): %s\n', tgt{i});
end
end
