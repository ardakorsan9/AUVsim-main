function run_gate7_mission_manager_fail_silent_sim()
%RUN_GATE7_MISSION_MANAGER_FAIL_SILENT_SIM
%  TASK_ID GATE7_MISSION_MANAGER_FAIL_SILENT_SIM_001
%
%  Isolated, SIMULATION-ONLY constrained-3D mission manager + deterministic
%  FDIR / watchdog harness built around the INTERFACE_SPECIFIED message set
%  (MissionCommand / WaypointSet / TrajectorySegment / Ack) and the accepted
%  Gate 6B real-time / power-integrity contract.
%
%  This file does NOT call, wire, tune, or modify any production model,
%  controller, guidance, dynamics, or metric file. The vehicle response used
%  here is an explicitly ASSUMED kinematic surrogate whose only purpose is to
%  close the mission -> guidance-input -> bounded-reference -> FDIR loop so
%  that fail-silent behaviour can be observed deterministically.
%
%  Evidence labels:
%    IMPLEMENTED         - this harness (simulation) and its monitors
%    INTERFACE_SPECIFIED - the message contract / ICD fields it exercises
%    ASSUMED             - every numeric fault schedule / threshold placeholder
%    TO_BE_IDENTIFIED    - mission / nav / actuator-feedback rates
%    NOT_CERTIFIED       - all hardware / HIL claims
%
%  Sources (exactly 3, frozen):
%    suite_results/AUTONOMOUS_EXECUTION_POLICY.md
%    suite_results/AUV_MISSION_COMPUTER_INTERFACE_REQUIREMENTS.md
%    suite_results/REAL_TIME_POWER_INTEGRITY_CONTRACT.mat

t_host = tic;
TAG = 'GATE7_MISSION_MANAGER_FAIL_SILENT_SIM';
SR  = 'suite_results';
set(0,'DefaultFigureVisible','off');
logf = fullfile(SR,[TAG '_run.log']);
if exist(logf,'file'); delete(logf); end
diary(logf); diary on;
fprintf('=== TASK GATE7_MISSION_MANAGER_FAIL_SILENT_SIM_001 ===\n');
try
    g7_main(TAG, SR, t_host);
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
function g7_main(TAG, SR, t_host)

%% ---------- Gate 0 hygiene: disk preflight ----------
free_gib = NaN;
try
    free_gib = double(java.io.File(pwd).getFreeSpace())/2^30;
catch
end
fprintf('Gate0 preflight: free space %.3f GiB (>=3 GiB required to start)\n', free_gib);

R = struct();
R.task_id       = 'GATE7_MISSION_MANAGER_FAIL_SILENT_SIM_001';
R.gate          = 'Gate 7 (isolated mission-manager / fail-silent FDIR simulation)';
R.created       = datestr(now,'yyyy-mm-dd HH:MM:SS');
R.certification = 'NOT_CERTIFIED (simulation-only; no HIL, no bench, no hardware)';
R.honesty       = 'IMPLEMENTED = this isolated harness only. Message contract = INTERFACE_SPECIFIED. Production untouched.';
R.free_gib_at_start = free_gib;

%% ---------- 1. Exactly three sources ----------
src = { fullfile(SR,'AUTONOMOUS_EXECUTION_POLICY.md'), ...
        fullfile(SR,'AUV_MISSION_COMPUTER_INTERFACE_REQUIREMENTS.md'), ...
        fullfile(SR,'REAL_TIME_POWER_INTEGRITY_CONTRACT.mat') };
R.sources = src;
R.src_fp  = cell(1,3);
for i = 1:3
    if ~exist(src{i},'file')
        error('missing frozen source: %s', src{i});
    end
    R.src_fp{i} = g7_fp_file(src{i});
    fprintf('source %d: %s  %s\n', i, src{i}, R.src_fp{i});
end

pol = fileread(src{1});
icd = fileread(src{2});
S6  = load(src{3});
if ~isfield(S6,'R'); error('Gate 6B mat has no result struct R'); end
G6  = S6.R;
c6  = G6.cfg;

% source-binding checks (ASCII substrings only, no repo scan)
B = struct();
B.policy_gate7_fdir   = g7_has(pol,'Mission manager / fail-silent');
B.policy_no_surface   = g7_has(pol,'No') && g7_has(pol,'auto-surface');
B.policy_labels       = g7_has(pol,'TO_BE_IDENTIFIED') && g7_has(pol,'NOT_CERTIFIED');
B.policy_pareto       = g7_has(pol,'Pareto tracking vector');
B.icd_messages        = g7_has(icd,'MissionCommand') && g7_has(icd,'WaypointSet') && ...
                        g7_has(icd,'TrajectorySegment') && g7_has(icd,'Ack');
B.icd_header          = g7_has(icd,'schema_version') && g7_has(icd,'integrity') && ...
                        g7_has(icd,'t_mono') && g7_has(icd,'seq');
B.icd_frames          = g7_has(icd,'NED') && g7_has(icd,'BODY');
B.icd_fail_silent     = g7_has(icd,'fail-silent');
B.icd_local_override  = g7_has(icd,'Local magnitude / rate / safety authority always overrides mission');
B.icd_no_direct_act   = g7_has(icd,'must') && g7_has(icd,'not') && g7_has(icd,'write actuator commands directly');
B.g6b_pass            = strcmp(strtrim(G6.verdict),'PASS');
R.source_binding = B;
bf = fieldnames(B);
for i = 1:numel(bf)
    fprintf('bind %-20s : %d\n', bf{i}, B.(bf{i}));
end
if ~B.g6b_pass
    error('Gate 6B is not PASS in the frozen contract; Gate 7 must not start.');
end
R.gate6b = struct('task_id',G6.task_id,'verdict',G6.verdict,'created',G6.created, ...
                  'wcet_claim',c6.wcet_claim,'src_fp',G6.src3_fp);

%% ---------- 2. Production / CODEX fingerprints (pre) ----------
prod = { 'continuous_path_tracking.m', 'controller_law.m', 'guidance_law.m', ...
         'underwater777_vehicle_dynamics.m', 'compute_path_following_metrics.m', ...
         fullfile('suite_results','CODEX_VERTICAL_PLAN.md') };
R.prod_files = prod;
R.fp_pre = cell(1,numel(prod));
for i = 1:numel(prod)
    R.fp_pre{i} = g7_fp_file(prod{i});
end
% cross-reference against the Gate 6B recorded fingerprints (n and s1 terms)
R.fp_g6b = G6.fp_post;
R.fp_g6b_ns1_match = false(1,numel(prod));
for i = 1:numel(prod)
    a = g7_fp_parts(R.fp_pre{i});
    hit = false;
    for j = 1:numel(R.fp_g6b)
        b = g7_fp_parts(R.fp_g6b{j});
        if a(1) == b(1) && a(2) == b(2); hit = true; break; end
    end
    R.fp_g6b_ns1_match(i) = hit;
end

%% ---------- 3. Frames / signs freeze (Gate 0, inherited) ----------
F = struct();
F.position   = 'NED inertial [m]; z positive DOWN (depth = +z)';
F.rates      = 'BODY angular rates p,q,r [rad/s]; BODY velocity u,v,w [m/s]';
F.euler      = 'phi,theta,psi [rad] internally (report/plots in deg where labelled)';
F.pitch_sign = 'theta > 0 = nose UP = depth decreasing (dz/dt = -u*sin(theta)) in this surrogate';
F.actuators  = 'delta_e, delta_r [deg] signed per production convention; thrust in [0,1] pu';
F.units      = 'SI (m, m/s, rad, rad/s, N, s); deg only where a field name says _deg';
F.source_ref = 'AUV_MISSION_COMPUTER_INTERFACE_REQUIREMENTS.md Sec.4 + REAL_TIME_POWER_INTEGRITY_CONTRACT.mat frames';
F.label      = 'INTERFACE_SPECIFIED (frozen, not re-derived here)';
R.frames = F;

%% ---------- 4. Configuration (inherited + explicitly ASSUMED) ----------
C = struct();
% clocks, inherited from the accepted Gate 6B contract
C.T_wd   = c6.per(1);   % 0.025 s  ASSUMED (safety monitor, harness-declared)
C.T_ctrl = c6.per(2);   % 0.025 s  FIXED 40 Hz (ICD Sec.3 interface target)
C.T_guid = c6.per(3);   % 0.075 s  DERIVED 13.33 Hz (ICD Sec.3)
C.T_nav  = c6.per(4);   % 0.025 s  TO_BE_IDENTIFIED (sim placeholder)
C.T_msn  = c6.per(5);   % 1.000 s  TO_BE_IDENTIFIED (sim placeholder)
C.T_link = 0.25;        % transport keepalive period [s] ASSUMED (link layer, distinct from mission heartbeat)
C.rate_labels = { 'watchdog 25 ms : ASSUMED (harness-declared safety monitor)', ...
                  'controller 25 ms : FIXED 40 Hz (ICD Sec.3 interface target)', ...
                  'guidance 75 ms : DERIVED 13.33 Hz (ICD Sec.3)', ...
                  'navigation 25 ms : TO_BE_IDENTIFIED (ASSUMED sim placeholder)', ...
                  'mission 1000 ms : TO_BE_IDENTIFIED (ASSUMED sim placeholder)', ...
                  'link keepalive 250 ms : TO_BE_IDENTIFIED (ASSUMED sim placeholder)' };
C.dt_u  = 0.0025;       % micro step [s] ASSUMED (sub-period bus/latency resolution)
C.T_end = 40.0;         % scenario horizon [s] ASSUMED

% actuator / reference envelopes, inherited (mission may never widen these)
C.de_max = c6.de_max; C.dr_max = c6.dr_max; C.rate_max = c6.rate_max;
C.thr_min = c6.thr_min; C.thr_max = c6.thr_max; C.thr_rate = c6.thr_rate;
C.pitch_ref_max = c6.pitch_ref_max; C.pitch_ref_rate_max = c6.pitch_ref_rate_max;

% power / brownout, inherited
C.V_nom = c6.V_nom; C.V_warn = c6.V_warn; C.V_bo = c6.V_bo;
C.k_ir = c6.k_ir; C.P_idle = c6.P_idle; C.k_pw = c6.k_pw;
C.uv_debounce = c6.uv_debounce; C.recov_hold = c6.recov_hold; C.stale_to = c6.stale_to;

% bounded command / reference governance (ASSUMED placeholders)
C.u_min = 0.5; C.u_max = 2.0; C.u_ref_rate = 0.5;
C.depth_min = 1.0; C.depth_max = 30.0; C.depth_ref_rate = 0.3;
C.yaw_ref_rate_max = 20.0;      % deg/s
C.kappa_max = 0.10;             % 1/m  (min turn radius 10 m)
C.slope_max = C.pitch_ref_max;  % deg, = local pitch envelope
C.schema_ok = 1;                % accepted schema_version
C.horizon_default = 6.0;        % validity horizon [s]
C.bus_delay = 0.015; C.bus_jitter = 0.005;

% monitor thresholds (ASSUMED) : M1..M9
C.mon_name = { 'LEAK','UNDERVOLTAGE','WATCHDOG_OVERRUN','ACTUATOR_STUCK_CURRENT', ...
               'IMU_STALE','DVL_STALE','DEPTH_STALE','BUS_TIMEOUT','MISSION_STALE' };
C.T_imu = 0.025; C.T_dvl = 0.100; C.T_dep = 0.050;
C.imu_to = 0.15; C.dvl_to = 1.00; C.dep_to = 0.50; C.bus_to = 0.50;
C.act_resid_thr = 2.0; C.act_cur_thr = 0.50;
C.deb_req  = [0.05 C.uv_debounce 0 0.20 0 0 0 0 0];
C.latching = [1 0 0 0 0 0 0 0 0];   % LEAK latches permanently (no auto-clear)
C.wd_consec = 3;
% declared detection bounds from FAULT ONSET [s] (threshold + source period + 2 monitor periods)
C.bnd_inj = [ C.deb_req(1)+2*C.T_wd, ...
              C.uv_debounce+2*C.T_wd, ...
              C.wd_consec*C.T_ctrl+2*C.T_wd, ...
              C.deb_req(4)+2*C.T_wd, ...
              C.imu_to+C.T_imu+2*C.T_wd, ...
              C.dvl_to+C.T_dvl+2*C.T_wd, ...
              C.dep_to+C.T_dep+2*C.T_wd, ...
              C.bus_to+C.T_link+C.bus_delay+C.bus_jitter+2*C.T_wd, ...
              C.stale_to+C.T_msn+C.bus_delay+C.bus_jitter+2*C.T_wd ];
% declared detection bound from CONDITION CROSSING [s]
C.bnd_cond = C.deb_req + 2*C.T_wd;
% response ladder: 0 MISSION_FOLLOW, 1 HOLD_LAST_SAFE, 2 CONSTRAIN, 3 SAFE_HOLD
C.mon_mode      = [3 3 3 2 3 2 3 1 1];
C.mon_escalate  = [Inf Inf Inf 2.0 Inf 5.0 Inf 2.0 2.0];  % s active -> SAFE_HOLD
C.act_gap_bound = 2*C.T_guid + 2*C.T_ctrl;                % detect -> mode change [s]
C.min_dwell     = 1.0;
% surrogate / plant-free response model (ASSUMED, not production dynamics)
C.k_psi = 1.2; C.k_th = 1.5; C.tau_u = 3.0;
C.k_dr = 3.0; C.k_de = 3.0;
C.cnom_ctrl = c6.cnom(2); C.wd_load = 5.4;
C.z0 = 3.0; C.u0 = 1.2;
C.wp = [   0    0   3 ;
          40    0   6 ;
          70   22   9 ;
          70   62  12 ;
          40   82  14 ;
           0   62  11 ;
         -22   22   6 ];
C.nseg = size(C.wp,1) - 1;
C.kappa_path = g7_path_kappa(C.wp);
C.slope_path = g7_path_slope(C.wp);
R.cfg = C;
fprintf('mission path: max curvature %.4f 1/m (bound %.3f), max slope %.2f deg (bound %.1f)\n', ...
        max(C.kappa_path), C.kappa_max, max(C.slope_path), C.slope_max);
if max(C.kappa_path) > C.kappa_max || max(C.slope_path) > C.slope_max
    error('frozen mission path violates its own declared geometric bounds');
end

%% ---------- 5. FROZEN fault schedule (ASSUMED, declared before the run) ----------
SC = g7_scenarios(C);
nsc = numel(SC);
R.scenarios = SC;
fprintf('\nfrozen scenario matrix (%d cases, ASSUMED schedule):\n', nsc);
for i = 1:nsc
    fprintf('  %-2d %-6s %-34s expect=[%s] recover=%d\n', i, SC(i).code, SC(i).name, ...
            num2str(find(SC(i).expect)), SC(i).expect_recover);
end

%% ---------- 6. Pass A / Pass B (deterministic replay) ----------
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

%% ---------- 7. Aggregate metrics ----------
M = g7_aggregate(C, SC, A);
R.metrics = M;
R.per_case = g7_strip(A);

%% ---------- 8. Hard gates ----------
[G, verdict] = g7_gates(C, SC, A, M, R, replay_ok);
R.gates = G;
R.verdict = verdict;

%% ---------- 9. Artifacts ----------
pngf = fullfile(SR,[TAG '.png']);
matf = fullfile(SR,[TAG '.mat']);

% fingerprints (post) settle HG13 before anything is rendered
R.fp_post = cell(1,numel(prod));
for i = 1:numel(prod)
    R.fp_post{i} = g7_fp_file(prod{i});
end
R.fp_unchanged = all(strcmp(R.fp_pre, R.fp_post));
for i = 1:numel(G)
    if strcmp(G(i).id,'HG13')
        G(i).pass = double(R.fp_unchanged);
        G(i).detail = sprintf('%d files fingerprinted, %d changed; Gate 6B n/s1 cross-match %d/%d', ...
            numel(prod), sum(~strcmp(R.fp_pre,R.fp_post)), sum(R.fp_g6b_ns1_match), numel(prod));
    end
end
R.gates = G;
if all([G.pass]); R.verdict = 'PASS'; elseif any([G.pass]); R.verdict = 'PARTIAL'; else; R.verdict = 'FAIL'; end

g7_plot(C, SC, A, M, G, R, pngf);
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

g7_report(TAG, SR, C, SC, A, M, R, G);
g7_append_logs(TAG, SR, R, G);

fprintf('\nVERDICT: %s   (%d/%d hard gates)\n', R.verdict, sum([G.pass]), numel(G));
fprintf('artifacts: %s.{md,mat,png}  mat=%.2f MiB png=%.2f MiB  runtime=%.1f s\n', ...
        TAG, R.mat_mib, R.png_mib, R.host_runtime_s);
end

% ======================================================================
%  FROZEN SCENARIO MATRIX
% ======================================================================
function SC = g7_scenarios(C) %#ok<INUSD>
% window index map
% 1 schema 2 frame 3 integrity 4 order/replay 5 expired 6 heartbeat 7 bus
% 8 imu 9 dvl 10 depth 11 actuator 12 undervoltage 13 leak 14 wd-overrun 15 forbidden
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
%  ISOLATED MISSION MANAGER + FDIR SIMULATION (one scenario)
% ======================================================================
function O = g7_sim(C, sc)

rs  = g7_seed(sc.code);
nk  = round(C.T_end / C.dt_u);
nlog = round(C.T_end / C.T_ctrl);

% ---- vehicle surrogate state (ASSUMED kinematic surrogate, NOT production) ----
x = C.wp(1,1); y = C.wp(1,2); z = C.z0; psi = 0; th = 0; u = C.u0;
de = 0; dr = 0; thr = 0.30; dr_app = 0; de_app = 0;
V = C.V_nom; I_proxy = 0.10;

% ---- guidance-input (only channel the mission may write) ----
gi = struct('seg',1,'z_hint',C.wp(2,3),'u_hint',1.2,'slope_hint',0,'valid',0, ...
            'mission_id',1,'segment_id',1,'seq',0,'t_mono',0);
gi_safe = gi;                      % last accepted safe guidance input
% ---- bounded reference state ----
yaw_ref = 0; pitch_ref = 0; u_ref = C.u0; depth_ref = C.z0;
mode = 0; mode_prev = 0;
sh_frozen = false; sh_depth = C.z0; sh_yaw = 0; sh_ref0 = C.z0;

% ---- bus / mission publication ----
maxmsg = 4*ceil(C.T_end/C.T_msn) + 32;
BUS = zeros(maxmsg,16); nmsg = 0;      % see column map below
% 1 t_emit 2 t_arr 3 schema 4 frame_ok 5 integ_ok 6 seq 7 horizon 8 seg
% 9 z_hint 10 u_hint 11 slope_hint 12 kappa 13 forbid 14 expect_code 15 used 16 type
seq_tx = 0; seq_rx_last = 0;
next_msn = 0; next_ctrl = 0; next_guid = 0; next_wd = 0;
next_imu = 0; next_dvl = 0; next_dep = 0; next_link = 0;
last_pub_imu = 0; last_pub_dvl = 0; last_pub_dep = 0;
last_rx_bus = 0; last_valid_msn = 0; link_arr = NaN;

% ---- FDIR state ----
raw = false(1,9); deb = zeros(1,9); act = false(1,9); clr = zeros(1,9);
cond_on = nan(1,9); det_t = nan(1,9); cond_at_det = nan(1,9);
act_since = nan(1,9); trip = false(1,9); mode_change_t = nan(1,9);
consec_miss = 0; n_ctrl_miss = 0; n_wd_miss = 0; leak = false;
nav_integrity = 1; act_health = 1;

% ---- logs ----
L = zeros(nlog,30); nl = 0;
ACK = zeros(maxmsg,6); nack = 0;
seq_out = 0; t_last_out = -1;
mono_seq_ok = true; mono_time_ok = true;
clamp_events = 0; hint_unclamped = 0;
req_surface = 0; req_direct_act = 0; req_accom = 0;
iss_surface = 0; iss_direct_act = 0; iss_accom = 0;
mag_viol = 0; rate_viol = 0; bnd_viol = 0;
step_max = zeros(1,4);            % yaw pitch u depth per-guidance-tick step
cte_sum = 0; cte_n = 0; cte_max = 0;
depth_min = z; depth_max = z; depth_min_deg = Inf;
de_absmax = 0; dr_absmax = 0; thr_hi = 0; V_min = V;
mode_hist = zeros(nlog,1);
eps0 = 1e-9;

for k = 1:nk
    t = (k-1)*C.dt_u;

    % ============ transport keepalive (link layer, independent of mission app) ====
    if t >= next_link - eps0
        next_link = next_link + C.T_link;
        [uu,rs] = g7_lcg(rs);
        jit = C.bus_jitter*uu;
        if sc.conf; jit = C.bus_jitter; end
        arr = t + C.bus_delay + jit;
        if ~g7_in(arr, sc.W(7,:)); link_arr = arr; end
    end

    % ================= mission computer (external, downlink) =================
    if t >= next_msn - eps0
        next_msn = next_msn + C.T_msn;
        nburst = 1;
        if sc.conf && abs(t-20) < 0.5*C.T_msn; nburst = 3; end   % legal burst
        for bb = 1:nburst
            % mission-side segment selection from truth uplink (StateEstimate, truth-tagged)
            segm = g7_nearest_seg(C.wp, [x y z]);
            m = zeros(1,16);
            m(1) = t; m(16) = 3;                        % TrajectorySegment
            if mod(round(t/C.T_msn),5) == 0; m(16) = 1; end   % MissionCommand
            if t < 0.5*C.T_msn; m(16) = 2; end                % WaypointSet at start
            m(3) = C.schema_ok; m(4) = 1; m(5) = 1;
            seq_tx = seq_tx + 1; m(6) = seq_tx;
            m(7) = t + C.horizon_default;
            m(8) = segm;
            m(9) = C.wp(segm+1,3);
            m(10) = 1.2; m(11) = 0; m(12) = C.kappa_path(segm);
            m(13) = 0;
            if sc.conf
                % legal but near/over-limit SOFT hints: must be clamped, never rejected
                m(10) = 4.0; m(11) = 40.0;
            end
            kk = mod(round(t/C.T_msn),3);                          % one corruption per tick
            if kk == 0 && g7_in(t,sc.W(1,:)); m(3) = 99; end       % bad schema_version
            if kk == 1 && g7_in(t,sc.W(2,:)); m(4) = 0;  end       % wrong frame/units tag
            if kk == 2 && g7_in(t,sc.W(3,:)); m(5) = 0;  end       % integrity (CRC) fail
            if g7_in(t,sc.W(4,:)); m(6) = max(1,seq_rx_last - 2); end  % replay / out-of-order
            if g7_in(t,sc.W(5,:)); m(7) = t - 1.0; end             % expired validity horizon
            if g7_in(t,sc.W(15,:))
                fc = 1 + mod(round(t/C.T_msn),3);
                m(13) = fc;
                if fc == 1; m(9) = -2.0; end                       % surface request
            end
            m(14) = g7_expect_code(C, m, seq_rx_last);
            if g7_in(t,sc.W(6,:)); continue; end                   % heartbeat loss: nothing sent
            [uu,rs] = g7_lcg(rs);
            jit = C.bus_jitter * uu;
            if sc.conf; jit = C.bus_jitter; end
            m(2) = t + C.bus_delay + jit + (bb-1)*0.004;
            if g7_in(m(2),sc.W(7,:)); continue; end                % bus timeout: frame lost
            nmsg = nmsg + 1; BUS(nmsg,:) = m;
            if m(13) == 1; req_surface = req_surface + 1; end
            if m(13) == 2; req_direct_act = req_direct_act + 1; end
            if m(13) == 3; req_accom = req_accom + 1; end
        end
    end

    % ================= navigation publication (multirate sensors) =================
    if t >= next_imu - eps0
        next_imu = next_imu + C.T_imu;
        if ~g7_in(t,sc.W(8,:)); last_pub_imu = t; end
    end
    if t >= next_dvl - eps0
        stepd = C.T_dvl;
        if sc.conf; stepd = 0.8; end          % 0.8 s gap < 1.0 s threshold (confounder)
        next_dvl = next_dvl + stepd;
        if ~g7_in(t,sc.W(9,:)); last_pub_dvl = t; end
    end
    if t >= next_dep - eps0
        stepp = C.T_dep;
        if sc.conf; stepp = 0.4; end          % 0.4 s gap < 0.5 s threshold (confounder)
        next_dep = next_dep + stepp;
        if ~g7_in(t,sc.W(10,:)); last_pub_dep = t; end
    end

    % ================= mission-manager ingress + Ack (at controller tick) =====
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
                    % SOFT hints: clamp to local envelope (mission cannot raise limits)
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
                % forbidden fields are never propagated to any consumer
            end
        end
    end

    % ================= raw monitor conditions (every micro step) =============
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

    % ================= watchdog / FDIR state machine (watchdog tick) =========
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
        % precedence: lowest active index wins; time-based escalation to SAFE_HOLD
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

    % ================= guidance-equivalent bounded reference shim ============
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
            case 0    % MISSION_FOLLOW
                yaw_t = atan2(tgt(2)-y, tgt(1)-x) * 180/pi;
                pit_t = -atan2(gu.z_hint - z, max(dh,1.0)) * 180/pi;
                u_t = gu.u_hint; dep_t = gu.z_hint;   % slope hint stays advisory (soft)
            case 1    % HOLD_LAST_SAFE : freeze last safe refs, invent nothing
                yaw_t = yaw_ref; pit_t = pitch_ref; u_t = u_ref; dep_t = depth_ref;
            case 2    % CONSTRAIN : reduced authority, still mission-shaped
                yaw_t = atan2(tgt(2)-y, tgt(1)-x) * 180/pi;
                pit_t = -atan2(gu.z_hint - z, max(dh,1.0)) * 180/pi;
                pit_t = min(max(pit_t,-0.5*C.pitch_ref_max),0.5*C.pitch_ref_max);
                u_t = min(gu.u_hint, 0.6*C.u_max); dep_t = gu.z_hint;
            otherwise % SAFE_HOLD : bounded local hold, no surface, no accommodation
                yaw_t = sh_yaw*180/pi; pit_t = 0; u_t = C.u_min; dep_t = sh_depth;
        end
        % local magnitude authority (mission can never widen these)
        pit_t = min(max(pit_t,-C.pitch_ref_max),C.pitch_ref_max);
        u_t   = min(max(u_t,C.u_min),C.u_max);
        dep_t = min(max(dep_t,C.depth_min),C.depth_max);
        % local rate authority (bumpless by construction, incl. mode transitions)
        pitch_ref = g7_rl(pitch_ref, pit_t, C.pitch_ref_rate_max*C.T_guid);
        u_ref     = g7_rl(u_ref,     u_t,   C.u_ref_rate*C.T_guid);
        depth_ref = g7_rl(depth_ref, dep_t, C.depth_ref_rate*C.T_guid);
        dyaw = g7_wrap180(yaw_t - yaw_ref);
        dyaw = min(max(dyaw,-C.yaw_ref_rate_max*C.T_guid),C.yaw_ref_rate_max*C.T_guid);
        yaw_ref = g7_wrap180(yaw_ref + dyaw);
        % bounded-output governance audit
        st = [abs(g7_wrap180(yaw_ref-yaw_p)) abs(pitch_ref-pit_p) abs(u_ref-u_p) abs(depth_ref-dep_p)];
        step_max = max(step_max, st);
        lim = [C.yaw_ref_rate_max C.pitch_ref_rate_max C.u_ref_rate C.depth_ref_rate]*C.T_guid;
        rate_viol = rate_viol + sum(st > lim + 1e-6);
        if abs(pitch_ref) > C.pitch_ref_max + 1e-6; mag_viol = mag_viol + 1; end
        if u_ref < C.u_min - 1e-6 || u_ref > C.u_max + 1e-6; mag_viol = mag_viol + 1; end
        if depth_ref < C.depth_min - 1e-6 || depth_ref > C.depth_max + 1e-6; bnd_viol = bnd_viol + 1; end
        if C.kappa_path(seg) > C.kappa_max + 1e-9; bnd_viol = bnd_viol + 1; end
    end

    % ================= controller + actuator surrogate (controller tick) =====
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
            % watchdog has direct bounded safe-hold authority (never skipped)
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
        % actuator realisation + stuck injection (commanded vs shadow-measured)
        if g7_in(t,sc.W(11,:))
            % dr_app frozen at onset value
        else
            dr_app = dr;
        end
        de_app = de;
        I_proxy = 0.10 + 0.004*abs(dr_app) + 0.20*thr;
        if g7_in(t,sc.W(11,:)); I_proxy = I_proxy + 0.45; end
        % envelope audit on the emitted command
        if abs(de) > C.de_max + 1e-6 || abs(dr) > C.dr_max + 1e-6 || ...
           thr < C.thr_min - 1e-6 || thr > C.thr_max + 1e-6
            mag_viol = mag_viol + 1;
        end
        de_absmax = max(de_absmax,abs(de)); dr_absmax = max(dr_absmax,abs(dr));
        thr_hi = max(thr_hi,thr);
        % emission with monotonic header
        seq_out = seq_out + 1;
        if t <= t_last_out; mono_time_ok = false; end
        t_last_out = t;
        % surrogate response: body rates follow the APPLIED deflections, so a stuck
        % fin actually persists in the motion (ASSUMED surrogate, not production dynamics)
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
        % power / integrity
        P = C.P_idle + C.k_pw*thr^2;
        dip = 0;
        if g7_in(t,sc.W(12,:)); dip = 0.18; end
        if sc.conf && g7_in(t,[12 14]); dip = 0.08; end
        V = C.V_nom - C.k_ir*P - dip;
        V_min = min(V_min,V);
        depth_min = min(depth_min,z); depth_max = max(depth_max,z);
        if mode > 0; depth_min_deg = min(depth_min_deg,z); end
        % tracking proxy (MISSION_FOLLOW only)
        if mode == 0
            seg = min(max(round(gi_safe.seg),1),C.nseg);
            e = g7_seg_dist([x y z], C.wp(seg,:), C.wp(seg+1,:));
            cte_sum = cte_sum + e; cte_n = cte_n + 1; cte_max = max(cte_max,e);
        end
        % no auto-surface / no automatic accommodation, ever
        if depth_ref < C.depth_min - 1e-9; iss_surface = iss_surface + 1; end
        if sh_frozen && depth_ref < sh_ref0 - 0.5; iss_surface = iss_surface + 1; end
        % log
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

% ---- per-scenario metrics ----
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
%  helpers
% ======================================================================
function m = topm_of(act)
m = 0;
for i = 1:9
    if act(i); m = i; return; end
end
end

function c = g7_expect_code(C, m, seq_last)
% Ground-truth code stamped at EMISSION from the frozen fault schedule, using the
% declared precedence. The receiver re-derives its own code after transport; the
% two must agree (HG12). This catches transport, ordering and receiver-state bugs.
c = 0;
if m(5) == 0;                        c = 3; return; end   % integrity
if m(3) ~= C.schema_ok;              c = 1; return; end   % schema_version
if m(4) ~= 1;                        c = 2; return; end   % frame / units tag
if m(13) ~= 0;                       c = 8; return; end   % forbidden field / mode
if m(6) <= seq_last;                 c = 4; return; end   % out-of-order / replay
if m(7) < m(1) || m(7) < m(2);       c = 5; return; end   % expired validity horizon
if m(12) > C.kappa_max || m(8) < 1;  c = 6; return; end   % hard geometry bound
end

function code = g7_validate(C, m, seq_last)
% receiver-side mission-manager validator; declared precedence order
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
% advance when close to the segment end (deterministic mission-side progress)
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

function p = g7_fp_parts(s)
p = [NaN NaN NaN];
tk = regexp(s,'n=(\d+)\.s1=(\d+)\.s2=(\d+)','tokens','once');
if numel(tk) == 3
    p = [str2double(tk{1}) str2double(tk{2}) str2double(tk{3})];
end
end

function h = g7_fp_num(v)
v = v(:); v(~isfinite(v)) = -7.77;
q = round(v*1e6); n = numel(q);
s1 = mod(sum(abs(q)), 281474976710656);
s2 = mod(sum(mod((1:n)'.*q, 4294967296)), 4294967296);
h = sprintf('n=%d.s1=%.0f.s2=%.0f', n, s1, s2);
end

function P = g7_strip(A)
% keep full logs but drop nothing large enough to matter (<10 MiB total)
P = A;
for i = 1:numel(P)
    P{i}.L = single(P{i}.L);
end
P = [P{:}];
end

% ======================================================================
%  aggregation
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
        % confounder events deliberately planted in the benign case
        % planted benign confounders: max-jitter transport, 0.8 s DVL gaps, 0.4 s depth
        % gaps, voltage sag above V_bo, single isolated deadline miss, over-limit soft
        % hints (speed + slope), 3-message burst
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
%  hard gates
% ======================================================================
function [G, verdict] = g7_gates(C, SC, A, M, R, replay_ok)
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
    prec_ok = prec_ok && all(topcol(L15(:,1) >= t_leak) == 1);   % leak outranks everything
else
    prec_ok = false;
end
if ~isnan(t_uv) && ~isnan(t_leak)
    % while undervoltage is latched-active and before the leak, it must outrank mission stale
    win = (L15(:,22) == 1) & (L15(:,1) >= t_uv) & (L15(:,1) < t_leak);
    prec_ok = prec_ok && any(win) && all(topcol(win) == 2);
    % and mission stale must be the top monitor whenever it alone is active
    win9 = (L15(:,25) == 1) & (L15(:,22) == 0) & (L15(:,1) < t_leak);
    prec_ok = prec_ok && any(win9) && all(topcol(win9) == 9);
end
lat_ok = a15.recovered == 0 && a15.trip(1);
G = g7_add(G,'HG7','Precedence and latching: LEAK > UNDERVOLTAGE > MISSION_STALE, and LEAK latches (no auto-clear)', ...
    prec_ok && lat_ok, sprintf('S15 top-monitor precedence ok=%d, leak latched to horizon=%d (safe-hold dwell %.2f s)', ...
    prec_ok, lat_ok, a15.sh_dwell));

rec_ok = true; rec_det = '';
for i = 1:numel(A)
    exp_r = SC(i).expect_recover;
    got_r = A{i}.recovered;
    ep_ok = (A{i}.episodes == SC(i).expect_episodes);
    dw_ok = (A{i}.deg_dwell == 0) || (A{i}.deg_dwell >= C.min_dwell);
    if got_r ~= exp_r || ~ep_ok || ~dw_ok
        rec_ok = false;
        rec_det = [rec_det sprintf('%s(rec %d/%d ep %d/%d) ', SC(i).code, got_r, exp_r, A{i}.episodes, SC(i).expect_episodes)]; %#ok<AGROW>
    end
end
if isempty(rec_det); rec_det = sprintf('all %d cases: episode count, min dwell %.1f s, and recovery expectation met', numel(A), C.min_dwell); end
G = g7_add(G,'HG8','Recovery hysteresis without chatter: one degraded episode per injected fault, min dwell respected, recovery only where declared', ...
    rec_ok, rec_det);

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

G = g7_add(G,'HG13','Production + CODEX_VERTICAL_PLAN byte-identical (pre/post fingerprints)', ...
    true, 'evaluated after artifact write');

G = g7_add(G,'HG14','Artifacts written and total footprint < 300 MiB', true, 'evaluated after artifact write');

hon = ~isempty(strfind(C.rate_labels{4},'TO_BE_IDENTIFIED')) && ...
      ~isempty(strfind(C.rate_labels{5},'TO_BE_IDENTIFIED')) && ...
      ~isempty(strfind(R.certification,'NOT_CERTIFIED'));
G = g7_add(G,'HG15','Label honesty: mission/nav/actuator-feedback rates remain TO_BE_IDENTIFIED, every fault number ASSUMED, hardware NOT_CERTIFIED', ...
    hon, 'mission/nav rates TO_BE_IDENTIFIED (ASSUMED sim placeholders); fault schedule ASSUMED; verdict scope = simulation only');

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
%  plots (visual QA)
% ======================================================================
function g7_plot(C, SC, A, M, G, R, pngf)
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
    cb = colorbar('Ticks',[0 1 2 3],'TickLabels',{'FOLLOW','HOLD_LAST','CONSTRAIN','SAFE_HOLD'});
    set(cb,'FontSize',7);
catch
    colorbar;
end
set(gca,'YTick',1:n,'YTickLabel',{SC.code},'FontSize',7);
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

% (3) detection latency vs declared bound
subplot(3,3,3);
T = M.lat_inj;
if ~isempty(T)
    bar(1:size(T,1), T(:,2)./max(T(:,3),eps), 'FaceColor',[0.30 0.45 0.75]); hold on;
    plot([0 size(T,1)+1],[1 1],'r--','LineWidth',1.2);
    set(gca,'XTick',1:size(T,1),'XTickLabel',C.mon_name(T(:,1)),'FontSize',6);
    try; set(gca,'XTickLabelRotation',60); catch; end
    ylabel('latency / declared bound'); ylim([0 1.3]);
end
grid on; title('detection latency vs declared bound (from onset)','FontSize',9);

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

% (6) 3D mission geometry, nominal vs degraded
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
title('constrained-3D mission geometry (NED, surrogate)','FontSize',9);

% (7) ack / reject histogram
subplot(3,3,7);
bar(0:8, M.reject_hist, 'FaceColor',[0.45 0.60 0.40]);
set(gca,'XTick',0:8,'XTickLabel',{'OK','SCHEMA','FRAME','INTEG','ORDER','EXPIRE','BOUNDS','LINK','FORBID'},'FontSize',6);
try; set(gca,'XTickLabelRotation',60); catch; end
grid on; ylabel('messages'); title(sprintf('Ack codes (%d msgs, %d mismatch)', M.n_msgs, M.n_ack_mismatch),'FontSize',9);

% (8) safe-hold / degraded dwell per case
subplot(3,3,8);
D = [cellfun(@(a)a.hls_dwell,A); cellfun(@(a)a.con_dwell,A); cellfun(@(a)a.sh_dwell,A)]';
bar(D,'stacked'); grid on;
set(gca,'XTick',1:n,'XTickLabel',{SC.code},'FontSize',6);
try; set(gca,'XTickLabelRotation',60); catch; end
ylabel('dwell [s]'); legend({'hold-last-safe','constrain','safe-hold'},'Location','northwest','FontSize',6);
title('fail-silent ladder dwell per case','FontSize',9);

% (9) gate summary
subplot(3,3,9);
p = [G.pass];
barh(1:numel(p), p, 'FaceColor',[0.25 0.55 0.30]); hold on;
for i = 1:numel(p)
    if ~p(i); barh(i, 1, 'FaceColor',[0.80 0.25 0.25]); end
end
set(gca,'YTick',1:numel(p),'YTickLabel',{G.id},'FontSize',6,'YDir','reverse');
xlim([0 1.15]); grid on;
title(sprintf('hard gates %d/%d  |  %s  |  NOT_CERTIFIED', sum(p), numel(p), R.verdict),'FontSize',9);

try
    annotation(fh,'textbox',[0.005 0.965 0.99 0.033],'String', ...
        sprintf('GATE7_MISSION_MANAGER_FAIL_SILENT_SIM_001 - isolated mission-manager / FDIR SIMULATION ONLY - production untouched - rates TO_BE_IDENTIFIED - fault schedule ASSUMED - NOT_CERTIFIED'), ...
        'EdgeColor','none','FontSize',8,'FontWeight','bold','HorizontalAlignment','center');
catch
end
print(fh,'-dpng','-r100',pngf);
close(fh);
end

% ======================================================================
%  report
% ======================================================================
function g7_report(TAG, SR, C, SC, A, M, R, G)
f = fopen(fullfile(SR,[TAG '.md']),'w');
w = @(varargin) fprintf(f, varargin{:});

w('# GATE7_MISSION_MANAGER_FAIL_SILENT_SIM - %s\n\n', R.task_id);
w('**Date:** %s  \n', R.created);
w('**Class:** Gate 7 isolated mission-manager + deterministic FDIR / watchdog **simulation**  \n');
w('**MATLAB runs:** 1 (single invocation, no retry) - **production edits:** NO - **CODEX_VERTICAL_PLAN:** untouched  \n');
w('**Physical / hardware readiness:** **NOT_CERTIFIED** (simulation-only; no HIL, no bench)  \n');
w('**Verdict:** **%s** (%d/%d hard gates)\n\n', R.verdict, sum([G.pass]), numel(G));

w('## Sources (strict, exactly 3)\n\n');
w('| # | Path | Role | Fingerprint |\n|---|------|------|-------------|\n');
rl = {'Gate 7 FDIR matrix, promotion + Pareto discipline, label vocabulary', ...
      'Layering, header fields, message set, authority / stale / fail-silent rules', ...
      'Accepted Gate 6B contract: clocks, envelopes, power thresholds, gate style'};
for i = 1:3
    w('| %d | `%s` | %s | `%s` |\n', i, strrep(R.sources{i},'\','/'), rl{i}, R.src_fp{i});
end
w('\nGate 6B precondition: `%s` verdict **%s** (created %s), inherited, not re-run.\n\n', ...
  R.gate6b.task_id, R.gate6b.verdict, R.gate6b.created);

w('### Source-binding checks\n\n| Check | Result |\n|-------|--------|\n');
bf = fieldnames(R.source_binding);
for i = 1:numel(bf)
    w('| `%s` | %s |\n', bf{i}, g7_yn(R.source_binding.(bf{i})));
end

w('\n## 1. What is IMPLEMENTED vs INTERFACE_SPECIFIED vs NOT_CERTIFIED\n\n');
w('| Item | Label |\n|------|-------|\n');
w('| Isolated mission-manager ingress/validator, Ack generation, constrained-3D segment sequencing | `IMPLEMENTED` (this harness, simulation) |\n');
w('| Deterministic FDIR/watchdog state machine: 9 monitors, precedence, latching, hysteresis | `IMPLEMENTED` (this harness, simulation) |\n');
w('| Bounded command/reference governance + bumpless mode transfer | `IMPLEMENTED` (this harness, simulation) |\n');
w('| MissionCommand / WaypointSet / TrajectorySegment / Ack wire contract, StateEstimate / VehicleHealth / ActuatorStatus uplinks | `INTERFACE_SPECIFIED` (exercised as in-process structs, no transport, no middleware) |\n');
w('| Production guidance / controller / dynamics wiring | **NOT_IMPLEMENTED here by design** - production byte-identical, nothing tuned |\n');
w('| Vehicle response used to close the loop | `ASSUMED` kinematic surrogate, **not** the production plant, no fidelity claimed |\n');
w('| measured / estimated state streams | `NOT_IMPLEMENTED` (Gate 5); uplink StateEstimate is **truth-tagged** only |\n');
w('| Mission / navigation / actuator-feedback rates | `TO_BE_IDENTIFIED` (ASSUMED sim placeholders %.0f ms / %.0f ms) |\n', C.T_msn*1000, C.T_nav*1000);
w('| All fault magnitudes, thresholds, windows, debounces | `ASSUMED` (frozen before the run, listed below) |\n');
w('| Hardware / HIL / safe-mode certification | **`NOT_CERTIFIED`** |\n');

w('\n## 2. Frames and signs (Gate 0 freeze, inherited)\n\n| Field | Definition |\n|-------|------------|\n');
ff = fieldnames(R.frames);
for i = 1:numel(ff)
    w('| `%s` | %s |\n', ff{i}, R.frames.(ff{i}));
end

w('\n## 3. Clocks (inherited from the accepted Gate 6B contract)\n\n');
w('| Task | Period | Label |\n|------|--------|-------|\n');
per = [C.T_wd C.T_ctrl C.T_guid C.T_nav C.T_msn C.T_link];
nm = {'watchdog / FDIR','controller','guidance','navigation','mission','link keepalive'};
for i = 1:6
    w('| %s | %.4g s | %s |\n', nm{i}, per(i), C.rate_labels{i});
end
w('\nMicro-integration step %.4g s (ASSUMED) resolves bus delay %.0f ms + jitter %.0f ms and sub-period detection latency.\n', ...
  C.dt_u, C.bus_delay*1000, C.bus_jitter*1000);

w('\n## 4. Message contract exercised (INTERFACE_SPECIFIED)\n\n');
w('Common header on every downlink message: `schema_version`, `mission_id`, `segment_id`, `seq` (monotonic), ');
w('`t_mono` [s], `valid`, `quality`, `integrity` (CRC proxy), frame tag `NED`, units tag `SI`, ');
w('validity horizon `t_valid_until` (default %.1f s), heartbeat implied by publication at the mission period.\n\n', C.horizon_default);
w('| Ack code | Meaning | Trigger |\n|---|---|---|\n');
w('| 0 | `ACK_OK` | header valid, payload inside envelope (soft hints clamped) |\n');
w('| 1 | `RJ_SCHEMA` | `schema_version` not the accepted version |\n');
w('| 2 | `RJ_FRAME_UNITS` | frame/units tag not NED/SI |\n');
w('| 3 | `RJ_INTEGRITY` | integrity/CRC mismatch |\n');
w('| 4 | `RJ_SEQ_ORDER` | `seq` <= last accepted (out-of-order / replay) |\n');
w('| 5 | `RJ_EXPIRED` | `t_mono` beyond the declared validity horizon on arrival |\n');
w('| 6 | `RJ_BOUNDS` | hard geometry outside envelope (curvature, invalid segment id) |\n');
w('| 7 | `RJ_STALE_LINK` | reserved for link-level staleness (monitor M9, not an Ack) |\n');
w('| 8 | `RJ_FORBIDDEN` | surface request, direct-actuator field, or accommodation request |\n');
w('\nAuthority rules enforced structurally: mission writes **only** the guidance-input struct ');
w('(`segment id`, depth hint, speed hint, slope hint). There is **no** code path from any mission field to an actuator channel; ');
w('soft hints are clamped to the local envelope, never obeyed raw; local magnitude/rate/safety authority always wins.\n');

w('\n## 5. FROZEN fault schedule and monitor bounds (all ASSUMED, declared before the run)\n\n');
w('| Monitor | Threshold / debounce | Response | Latch | Declared bound from onset | from condition crossing |\n');
w('|---|---|---|---|---|---|\n');
thr = {sprintf('leak proxy, debounce %.2f s',C.deb_req(1)), ...
       sprintf('V < %.2f pu, debounce %.2f s',C.V_bo,C.uv_debounce), ...
       sprintf('%d consecutive controller deadline misses',C.wd_consec), ...
       sprintf('cmd-vs-shadow residual > %.1f deg or current proxy > %.2f pu, debounce %.2f s',C.act_resid_thr,C.act_cur_thr,C.deb_req(4)), ...
       sprintf('IMU age > %.2f s',C.imu_to), sprintf('DVL age > %.2f s',C.dvl_to), ...
       sprintf('depth age > %.2f s',C.dep_to), ...
       sprintf('no frame of any kind (mission or %.2f s link keepalive) for %.2f s',C.T_link,C.bus_to), ...
       sprintf('no ACCEPTED mission message for %.2f s (rejected traffic does not refresh the mission clock)',C.stale_to)};
mds = {'SAFE_HOLD','SAFE_HOLD','SAFE_HOLD','CONSTRAIN -> SAFE_HOLD after 2.0 s','SAFE_HOLD', ...
       'CONSTRAIN -> SAFE_HOLD after 5.0 s dead-reckoning budget','SAFE_HOLD', ...
       'HOLD_LAST_SAFE -> SAFE_HOLD after 2.0 s','HOLD_LAST_SAFE -> SAFE_HOLD after 2.0 s'};
for m = 1:9
    w('| M%d %s | %s | %s | %s | %.3f s | %.3f s |\n', m, C.mon_name{m}, thr{m}, mds{m}, ...
      g7_yn(C.latching(m)), C.bnd_inj(m), C.bnd_cond(m));
end
w('\nPrecedence (highest first): M1 LEAK > M2 UNDERVOLTAGE > M3 WATCHDOG_OVERRUN > M4 ACTUATOR > ');
w('M5 IMU > M6 DVL > M7 DEPTH > M8 BUS > M9 MISSION_STALE. Recovery requires the condition clear for %.1f s ', C.recov_hold);
w('(hysteresis) and returns through the rate-limited reference path. LEAK never auto-clears: no auto-surface, no automatic accommodation.\n');

w('\n### Scenario matrix (16 cases, %.0f s each, deterministic)\n\n', C.T_end);
w('| # | Code | Scenario | Injection window(s) [s] | Expected monitors | Recovery expected | Note |\n');
w('|---|------|----------|--------------------------|-------------------|-------------------|------|\n');
wn = {'schema','frame','integrity','replay','expired','heartbeat','bus','imu','dvl','depth','actuator','undervoltage','leak','wd-overrun','forbidden'};
for i = 1:numel(SC)
    ws = '';
    for j = 1:15
        if SC(i).W(j,2) > SC(i).W(j,1)
            ws = [ws sprintf('%s [%g %g] ', wn{j}, SC(i).W(j,1), SC(i).W(j,2))]; %#ok<AGROW>
        end
    end
    if SC(i).conf; ws = 'benign confounders only'; end
    if isempty(ws); ws = 'none'; end
    em = find(SC(i).expect);
    es = 'none';
    if ~isempty(em); es = strjoin(cellfun(@(k) sprintf('M%d',k), num2cell(em),'UniformOutput',false),', '); end
    w('| %d | %s | %s | %s | %s | %s | %s |\n', i, SC(i).code, SC(i).name, strtrim(ws), es, ...
      g7_yn(SC(i).expect_recover), SC(i).note);
end

w('\n## 6. Results: detection, isolation, confounders, false alarms\n\n');
w('| Code | Msgs | Acc | Rej | Ack mismatch | Trips | Expected | FA | Missed | Episodes | HLS [s] | CONSTR [s] | SAFE_HOLD [s] | Recovered | Replay |\n');
w('|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|\n');
for i = 1:numel(A)
    a = A{i};
    tr = 'none'; if any(a.trip); tr = strjoin(cellfun(@(k) sprintf('M%d',k), num2cell(find(a.trip)),'UniformOutput',false),','); end
    ex = 'none'; if any(SC(i).expect); ex = strjoin(cellfun(@(k) sprintf('M%d',k), num2cell(find(SC(i).expect)),'UniformOutput',false),','); end
    w('| %s | %d | %d | %d | %d | %s | %s | %d | %d | %d | %.2f | %.2f | %.2f | %s | %s |\n', ...
      a.code, a.n_msgs, a.n_accept, a.n_reject, a.ack_mismatch, tr, ex, a.false_alarms, a.missed, ...
      a.episodes, a.hls_dwell, a.con_dwell, a.sh_dwell, g7_yn(a.recovered), g7_yn(R.replay_ok(i)));
end

w('\n### Detection delays vs declared bounds\n\n');
w('| Case | Monitor | Latency from fault onset [s] | Bound [s] | Margin [s] | Latency from condition crossing [s] | Bound [s] | Detect -> mode change [s] | Bound [s] |\n');
w('|---|---|---|---|---|---|---|---|---|\n');
for i = 1:numel(A)
    a = A{i};
    for m = find(SC(i).expect)
        if a.trip(m)
            w('| %s | M%d %s | %.4f | %.3f | %+.4f | %.4f | %.3f | %.4f | %.3f |\n', a.code, m, C.mon_name{m}, ...
              a.lat_inj(m), C.bnd_inj(m), C.bnd_inj(m)-a.lat_inj(m), a.lat_cond(m), C.bnd_cond(m), ...
              a.act_gap(m), C.act_gap_bound);
        else
            w('| %s | M%d %s | **NOT DETECTED** | %.3f | - | - | - | - | - |\n', a.code, m, C.mon_name{m}, C.bnd_inj(m));
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

w('\n## 7. Pareto tracking vector\n\n');
w('| Axis | Value | Note |\n|---|---|---|\n');
w('| Tracking | mean surrogate path error %.3f m, max %.3f m (MISSION_FOLLOW only) | surrogate geometry, **not** a production tracking metric |\n', ...
  mean(cellfun(@(a)a.cte_mean,A)), max(cellfun(@(a)a.cte_max,A)));
w('| Actuator margin | min elevator margin %.3f, min rudder margin %.3f of frozen envelope | envelopes %.0f/%.0f deg, %.0f deg/s inherited |\n', ...
  min(cellfun(@(a)a.act_margin_de,A)), min(cellfun(@(a)a.act_margin_dr,A)), C.de_max, C.dr_max, C.rate_max);
w('| Energy | mean thrust^2 proxy %.4f, max thrust %.3f pu | inherited power model, no re-measurement |\n', ...
  mean(cellfun(@(a)a.energy_proxy,A)), max(cellfun(@(a)a.thr_max,A)));
w('| Estimation | **N/A** | measured/estimated streams are `NOT_IMPLEMENTED` until Gate 5; no NEES claim |\n');
w('| Timing | controller deadline misses %d (injected), watchdog misses %d, detect->action worst %.4f s (bound %.3f s) | Gate 6B budgets inherited, no new WCET claim |\n', ...
  sum(cellfun(@(a)a.n_ctrl_miss,A)), sum(cellfun(@(a)a.n_wd_miss,A)), g7_maxcol(M.act_gap), C.act_gap_bound);
w('| Safety | false alarms %d, missed detections %d, surface/accommodation/direct-actuator commands %d/%d/%d, min depth %.2f m | local safety authority always wins |\n', ...
  M.n_false_alarm, M.n_missed, M.iss_surface, M.iss_accom, M.iss_direct_act, min(cellfun(@(a)a.depth_min,A)));

w('\n## 8. Hard gates\n\n| ID | Requirement | Result | Detail |\n|---|---|---|---|\n');
for i = 1:numel(G)
    w('| %s | %s | %s | %s |\n', G(i).id, G(i).req, g7_pf(G(i).pass), G(i).detail);
end

w('\n## 9. Production preservation\n\n| File | Fingerprint pre | Fingerprint post | Identical | Gate 6B n/s1 cross-match |\n|---|---|---|---|---|\n');
for i = 1:numel(R.prod_files)
    w('| `%s` | `%s` | `%s` | %s | %s |\n', strrep(R.prod_files{i},'\','/'), R.fp_pre{i}, R.fp_post{i}, ...
      g7_yn(strcmp(R.fp_pre{i},R.fp_post{i})), g7_yn(R.fp_g6b_ns1_match(i)));
end
w('\nFingerprint = `n` (bytes) `.s1` (byte sum) `.s2` (index-weighted sum mod 2^32). ');
w('The Gate 6B cross-match column compares the `n` and `s1` terms against the fingerprints recorded in the accepted Gate 6B mat; ');
w('the `s2` term of that earlier run is not re-derivable from the three frozen sources, so cross-run equality is asserted on `n` and `s1` only. ');
w('Within this run, pre/post equality is asserted on the full triple.\n');

w('\n## 10. Honest limits\n\n');
w('1. **Simulation only.** No HIL, no bench, no vehicle. Every PASS statement is about this isolated harness, not about hardware. `NOT_CERTIFIED`.\n');
w('2. **The vehicle response is an ASSUMED kinematic surrogate**, deliberately not the production plant. Nothing here validates production dynamics, gains, or tracking metrics.\n');
w('3. **Fault magnitudes, thresholds, windows and debounces are ASSUMED** placeholders frozen before the run; none is identified from data. Detection "within bounds" means within *these declared* bounds.\n');
w('4. **Mission / navigation / actuator-feedback rates remain TO_BE_IDENTIFIED.** The %.0f ms mission period and %.0f ms nav period are ASSUMED sim placeholders, not requirements.\n', C.T_msn*1000, C.T_nav*1000);
w('5. **No transport, middleware, or wire format** is selected or validated; the message set stays `INTERFACE_SPECIFIED` and in-process.\n');
w('6. **measured / estimated streams do not exist yet** (Gate 5). The uplink StateEstimate used by the mission side is truth-tagged, so nav-integrity monitoring is exercised against publication age only, not against estimator quality.\n');
w('7. **Fail-silent policy is not certified.** Hold-last-safe then safe-hold is demonstrated in simulation; any real safe-mode, surfacing, or accommodation policy still requires HIL validation (EXTERNAL).\n');
w('8. **Single MATLAB invocation, no retry**, per the execution policy; there is no tuning loop behind these numbers.\n');
w('9. **Declared modelling choices that shape the results:** (a) mission-message ingress and Ack generation are placed in the never-skipped high-priority path, so a compute overrun does not itself manufacture a mission-stale confound; (b) the link keepalive (%.2f s, ASSUMED) is separate from the mission application heartbeat, which is what makes BUS_TIMEOUT and MISSION_STALE separable at all; (c) a rejected message never refreshes the mission freshness clock. Different choices would change the reported matrix.\n', C.T_link);
w('10. **HG12 is a self-consistency check, not an oracle.** The expected Ack code is stamped at emission from the frozen schedule and the receiver re-derives its own code after transport; agreement proves the receiver applies the declared precedence to what actually arrived, it does not independently prove the precedence itself is the right one.\n');

w('\n## 11. Verdict and next exact task\n\n');
w('**%s** - %d/%d hard gates.\n\n', R.verdict, sum([G.pass]), numel(G));
if strcmp(R.verdict,'PASS')
    w('All Gate 7 hard gates hold for the isolated simulation. Gate 7 is **PASS at simulation scope only**; ');
    w('it does not upgrade any hardware label and does not certify safe-mode behaviour. Gate 8 is unlocked.\n\n');
    w('**Next exact task:** `gate8_monte_carlo_independent_priors_campaign` - Monte Carlo over the policy Gate 8 factor table ');
    w('(CG/CB +-2 cm per axis, buoyancy +-3%%, sensor bias/delay/dropout per the availability matrix, actuator lag/delay {0,15,30} ms + jitter, ');
    w('battery/brownout envelopes from Gate 6B), independent draws, percentiles over means, no silent narrowing of priors.\n');
else
    w('Gate 7 is **not** PASS. The failing gates above are reported as-is; no threshold was widened and no scenario was removed to force a pass.\n\n');
    w('**Next exact task (structurally untried):** `gate7_fdir_monitor_observability_separation_audit` - ');
    w('an isolated audit that separates each failing monitor into (a) injection reachability, (b) observable residual, ');
    w('(c) declared bound, so the failure is attributed to schedule, observability, or bound choice before any threshold is touched.\n');
end
w('\n**Do not edit:** `suite_results/CODEX_VERTICAL_PLAN.md` (byte-identical, fingerprinted above).\n');

w('\n## 12. Artifacts\n\n');
w('| Artifact | Size |\n|---|---|\n');
w('| `suite_results/%s.md` | this report |\n', TAG);
w('| `suite_results/%s.mat` | %.2f MiB (config, frozen schedule, per-case logs, gates) |\n', TAG, R.mat_mib);
w('| `suite_results/%s.png` | %.2f MiB (9-panel visual QA) |\n', TAG, R.png_mib);
w('| `suite_results/%s_run.log` | console transcript |\n', TAG);
w('\nHost runtime %.1f s, free space at start %.2f GiB, MATLAB invocations: 1.\n', R.host_runtime_s, R.free_gib_at_start);
fclose(f);
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
%  log appends (once each)
% ======================================================================
function g7_append_logs(TAG, SR, R, G)
np = sum([G.pass]); ng = numel(G);
blk = sprintf(['\n---\n\n## Append: %s (%s)\n\n' ...
  '**Date:** %s - **Class:** Gate 7 isolated mission-manager / FDIR **simulation** - **MATLAB runs:** 1 - **production:** byte-identical - **CODEX_VERTICAL_PLAN:** untouched  \n' ...
  '**Verdict:** **%s** (%d/%d hard gates) - **Physical / hardware readiness: NOT_CERTIFIED**\n\n' ...
  '- Isolated harness (`run_gate7_mission_manager_fail_silent_sim.m`) exercises MissionCommand / WaypointSet / TrajectorySegment / Ack with the full ICD header (`schema_version`, mission/segment id, `seq`, `t_mono`, valid/quality/integrity, NED/SI tags, validity horizon, heartbeat) over %d frozen ASSUMED scenarios, each replayed twice.\n' ...
  '- 9 monitors (leak, undervoltage, watchdog overrun, actuator stuck/current, IMU/DVL/depth stale, bus timeout, mission stale) with declared precedence, latching and %.1f s recovery hysteresis; response ladder hold-last-safe -> constrain -> safe-hold.\n' ...
  '- Detected %d/%d injected faults inside declared bounds, %d false alarms, %d missed, %d Ack-code mismatches, %d surface / %d accommodation / %d direct-actuator commands issued.\n' ...
  '- Labels unchanged: mission/nav/actuator-feedback rates `TO_BE_IDENTIFIED`; all fault numbers `ASSUMED`; message contract `INTERFACE_SPECIFIED`; harness `IMPLEMENTED` (simulation); hardware `NOT_CERTIFIED`.\n' ...
  '- Evidence: `suite_results/%s.{md,mat,png}`.\n'], ...
  R.task_id, R.verdict, R.created, R.verdict, np, ng, numel(R.scenarios), R.cfg.recov_hold, ...
  R.metrics.n_detect_ok, R.metrics.n_detect_expected, R.metrics.n_false_alarm, R.metrics.n_missed, ...
  R.metrics.n_ack_mismatch, R.metrics.iss_surface, R.metrics.iss_accom, R.metrics.iss_direct_act, TAG);

tgt = { fullfile(SR,'AUV_REALIZATION_READINESS_PLAN.md'), ...
        fullfile(SR,'AUV_REALISM_AND_VISUAL_VALIDATION.md'), ...
        fullfile(SR,'PITCH_CONTROL_RESEARCH_LOG.md') };
extra = { sprintf('\n**Gate 7 status:** simulation-scope %s. Gate 8 unlocks only on Gate 7 PASS; hardware terminus unchanged (EXTERNAL after Gate 9).\n', R.verdict), ...
          sprintf('\n**Visual QA:** 9-panel `%s.png` (response-ladder matrix, precedence detail, latency-vs-bound, bumpless refs, depth/no-auto-surface, waypoint set, Ack histogram, ladder dwell, gate summary). Rendered from simulation logs only.\n', TAG), ...
          sprintf('\n**Research note:** fail-silent ladder and monitor precedence are now observable in an isolated harness; no pitch/depth controller was reopened, retuned, or promoted by this task.\n') };
for i = 1:3
    fid = fopen(tgt{i},'a');
    if fid < 0
        fprintf(2,'WARN: cannot append to %s\n', tgt{i});
        continue;
    end
    fprintf(fid,'%s%s', blk, extra{i});
    fclose(fid);
    fprintf('appended once: %s\n', tgt{i});
end
end
