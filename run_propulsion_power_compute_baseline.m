function run_propulsion_power_compute_baseline()
%RUN_PROPULSION_POWER_COMPUTE_BASELINE  Gate6 isolated propulsion/power/compute budget.
%
% TASK_ID PROPULSION_POWER_COMPUTE_BASELINE_001. NO PROMOTION.
% SIMULATION_ONLY / NOT_CERTIFIED. Gate4 evidence shadow-only.
%
% Read-only sources for this task (exactly three):
%   run_speed_envelope_audit.m, controller_law.m, underwater777_vehicle_dynamics.m
% Production files are FINGERPRINTED before and after the run and must be byte
% identical. Gains and limits are frozen; nothing is tuned in this task.
%
% Structure
%   1. freeze + fingerprint
%   2. prove ideal parity (bypass vs identity actuator, bitwise) on every case
%   3. X/XZ at U={1,1.5,2}, R10 at U={1.5,2}, four PREDECLARED ASSUMED thruster
%      variants; realized thrust (magnitude/rate/lag/deadband limited) is fed to
%      the nonlinear 6DOF plant
%   4. component-neutral energy budget (actuator-disk bound + efficiency range +
%      avionics + fin duty) over worst/nominal/best hardware corners
%   5. compute evidence: call rates/counts + host runtime (NOT WCET)
%   6. gate ledger -> PASS / PARTIAL / FAIL, Pareto vector, artifacts, logs
%
% Artifacts: suite_results/PROPULSION_POWER_COMPUTE_BASELINE.{md,mat,png}

    try
        ppc_main();
    catch ME
        ppc_emergency(ME);
    end
end

function ppc_main()
    t_wall0 = tic;
    project_dir = fileparts(mfilename('fullpath'));
    addpath(project_dir);
    out_dir = fullfile(project_dir, 'suite_results');
    if ~exist(out_dir, 'dir'); mkdir(out_dir); end
    tag     = 'PROPULSION_POWER_COMPUTE_BASELINE';
    task_id = 'PROPULSION_POWER_COMPUTE_BASELINE_001';

    fprintf('\n========== %s ==========\n', task_id);
    fprintf('Gate6 isolated propulsion/power/compute budget. NO PROMOTION.\n');
    fprintf('SIMULATION_ONLY / NOT_CERTIFIED. Gate4 shadow-only.\n');
    fprintf('Hardware numerics ASSUMED / TO_BE_IDENTIFIED (ranges only).\n');

    %% ---------- 1. sources, frozen-string checks, fingerprints ----------
    src = struct();
    src.audit = fullfile(project_dir, 'run_speed_envelope_audit.m');
    src.ctrl  = fullfile(project_dir, 'controller_law.m');
    src.dyn   = fullfile(project_dir, 'underwater777_vehicle_dynamics.m');
    fn = fieldnames(src);
    for i = 1:numel(fn)
        assert(exist(src.(fn{i}), 'file') == 2, 'Missing source %s', src.(fn{i}));
    end

    ctrl_txt = fileread(src.ctrl);
    dyn_txt  = fileread(src.dyn);
    frozen = struct('name', {}, 'needle', {}, 'ok', {});
    frozen(end+1) = struct('name','climb FF gain',      'needle','k_gamma_climb = 0.1320695001', 'ok', false);
    frozen(end+1) = struct('name','roll damp gain',     'needle','Kp_roll = 0.605072',           'ok', false);
    frozen(end+1) = struct('name','thrust law',         'needle','thrust_trim + Kp_x * (u_ref - u)', 'ok', false);
    frozen(end+1) = struct('name','thrust clamp',       'needle','max(min(thrust, thrust_max), thrust_min)', 'ok', false);
    frozen(end+1) = struct('name','fin rate limit',     'needle','max_de = deg2rad(40) * dt',    'ok', false);
    frozen(end+1) = struct('name','climb FF term',      'needle','de_climb_ff',                  'ok', false);
    for i = 1:numel(frozen)
        frozen(i).ok = contains(ctrl_txt, frozen(i).needle);
    end
    frozen(end+1) = struct('name','plant thrust input', 'needle','Xprop   = controls.thrust;', ...
        'ok', contains(dyn_txt, 'Xprop   = controls.thrust;'));
    frozen(end+1) = struct('name','plant elevator moment', 'needle','Muuds*u^2*delta_e', ...
        'ok', contains(dyn_txt, 'Muuds*u^2*delta_e'));
    frozen_ok = all([frozen.ok]);
    for i = 1:numel(frozen)
        assert(frozen(i).ok, 'FROZEN STRING MISSING: %s (%s)', frozen(i).name, frozen(i).needle);
    end
    fprintf('Frozen production strings verified: %d/%d\n', sum([frozen.ok]), numel(frozen));

    fp_list = {'controller_law.m'; 'underwater777_vehicle_dynamics.m'; 'guidance_law.m'; ...
               'continuous_path_tracking.m'; 'init_parameters.m'; ...
               'generate_balanced_helical_path.m'; 'run_speed_envelope_audit.m'; ...
               fullfile('suite_results', 'CODEX_VERTICAL_PLAN.md')};
    FP_pre = fingerprint_set(project_dir, fp_list);
    fprintf('Fingerprinted %d production/plan files (pre-run).\n', numel(FP_pre));

    %% ---------- 2. frozen production stack ----------
    C = propulsion_power_compute_case();

    clear functions %#ok<CLFUNC>
    clear guidance_law controller_law
    clear global lambda_muw_ff trim_speed_table trim_elevator_table elevator_sign
    clear global K_zdot K_gamma enable_alpha_hat
    clear global last_guidance_U_h last_guidance_kappa last_r_ff
    clear global Kp_roll

    init_parameters();
    C = propulsion_power_compute_case();   % re-bind handles after clear functions

    global lambda_muw_ff elevator_sign trim_speed_table trim_elevator_table %#ok<GVMIS>
    global K_zdot K_gamma enable_alpha_hat %#ok<GVMIS>
    global dt_controller dt_guidance delta_e_max delta_r_max %#ok<GVMIS>
    global Kp_x thrust_trim thrust_max thrust_min desired_speed Kp_roll %#ok<GVMIS>
    global PPC_RHS_COUNT %#ok<GVMIS>

    elevator_sign = 1;
    trim_speed_table = [0.8 1.0 1.5 2.0];
    trim_elevator_table = deg2rad([-9.18 -7.33 -4.62 -3.17]);
    K_gamma = 0; K_zdot = 0; enable_alpha_hat = false;
    Kp_roll = 0.605072;

    dt = dt_controller;
    if isempty(dt) || ~isfinite(dt); dt = 0.0375; end
    if isempty(dt_guidance) || ~isfinite(dt_guidance); dt_guidance = 0.075; end
    gper = max(1, round(dt_guidance / dt));

    lim = struct('dr_max', delta_r_max, 'de_max', delta_e_max, ...
                 'dr_rate', deg2rad(40), 'de_rate', deg2rad(40), ...
                 'thrust_max', thrust_max, 'thrust_min', thrust_min, ...
                 'thrust_trim', thrust_trim, 'Kp_x', Kp_x, 'Kp_roll', Kp_roll, ...
                 'dt_controller', dt, 'dt_guidance', dt_guidance, 'guidance_period', gper);
    fprintf(['Frozen limits: de_max=%.2fdeg dr_max=%.2fdeg thrust=[%.3f, %.3f] N ', ...
             'trim=%.4f N Kp_x=%.4g\n'], rad2deg(delta_e_max), rad2deg(delta_r_max), ...
             thrust_min, thrust_max, thrust_trim, Kp_x);
    fprintf('Rates: controller %.4g Hz (dt=%.4g s) | guidance %.4g Hz (every %d steps)\n', ...
            1/dt, dt, 1/(gper*dt), gper);

    %% ---------- 3. build case list ----------
    Rts = C.routes;
    paths = cell(numel(Rts), 1);
    nX = 600; xX = linspace(0, 45, nX)';
    paths{1} = [xX, zeros(nX, 1), zeros(nX, 1)];
    nXZ = 900; xXZ = linspace(0, 42, nXZ)';
    paths{2} = [xXZ, zeros(nXZ, 1), 0.4 * xXZ];
    ha = C.helix_args;
    paths{3} = generate_balanced_helical_path(ha(1), ha(2), ha(3), ha(4));

    Cases = struct('route', {}, 'gate_key', {}, 'ir', {}, 'U', {}, 'label', {});
    for ir = 1:numel(Rts)
        for iu = 1:numel(Rts(ir).U)
            Cases(end+1) = struct('route', Rts(ir).name, 'gate_key', Rts(ir).gate_key, ...
                'ir', ir, 'U', Rts(ir).U(iu), ...
                'label', sprintf('%s@%.2f', Rts(ir).name, Rts(ir).U(iu))); %#ok<AGROW>
        end
    end
    nC = numel(Cases);
    nV = numel(C.variants);
    fprintf('Cases: %d (X/XZ U={1,1.5,2}, R10 U={1.5,2}) x variants: %d + parity bypass\n', nC, nV);

    %% ---------- 4. simulate: bypass reference + variants ----------
    Kcor = C.fn.energy_corners(C.energy);
    Run  = repmat(empty_run(), nC, nV);
    Byp  = repmat(empty_run(), nC, 1);
    parity = struct('case', {}, 'max_abs_diff', {}, 'exact', {}, 'detail', {});

    for ic = 1:nC
        ir = Cases(ic).ir;
        Rt = Rts(ir);
        pth = paths{ir};
        Uref = Cases(ic).U;
        fprintf('\n---- case %d/%d : %s ----\n', ic, nC, Cases(ic).label);

        % 4a. parity bypass reference: controller thrust straight into the plant
        try
            Sb = sim_run(pth, Rt.T_final, Uref, Rt.lambda_muw_ff, Rt.R_helix, [], false, dt, gper, C);
            Byp(ic) = pack_run(Sb, Cases(ic), 'bypass', lim, C, Kcor, pth);
        catch ME
            fprintf(2, '   SIM ERROR %s/bypass: %s\n', Cases(ic).label, ME.message);
            Byp(ic) = failed_run(Cases(ic), 'bypass', ME.message, Kcor, dt);
        end

        for iv = 1:nV
            V = C.variants(iv);
            try
                A = C.fn.actuator_init(V, thrust_min, thrust_max, thrust_trim);
                Sv = sim_run(pth, Rt.T_final, Uref, Rt.lambda_muw_ff, Rt.R_helix, A, true, dt, gper, C);
                Run(ic, iv) = pack_run(Sv, Cases(ic), V.name, lim, C, Kcor, pth);
            catch ME
                fprintf(2, '   SIM ERROR %s/%s: %s\n', Cases(ic).label, V.name, ME.message);
                Run(ic, iv) = failed_run(Cases(ic), V.name, ME.message, Kcor, dt);
            end
            M = Run(ic, iv).M;
            fprintf(['   %-10s thMAE=%.4f gMAE=%.4f yawMAE=%.4f | uMAE=%.4f ', ...
                     'Tpk=%.3fN Tsat=%.2f%% | %.2f ms/step\n'], V.name, ...
                     nz(M.theta.mae_deg), nz(M.gamma.mae_deg), nz(M.yaw.mae_deg), ...
                     nz(M.speed.mae), nz(M.thrust.peak_abs), nz(M.thrust.sat_pct), ...
                     Run(ic, iv).timing.ms_mean);
        end

        iv_id = find(strcmp({C.variants.name}, C.parity_variant), 1);
        d = traj_diff(Byp(ic).S, Run(ic, iv_id).S);
        parity(end+1) = struct('case', Cases(ic).label, 'max_abs_diff', d.maxdiff, ...
            'exact', d.maxdiff <= C.gate_cfg.parity_tol, 'detail', d.worst_channel); %#ok<AGROW>
        fprintf('   parity(ideal vs bypass): max|diff| = %.3g  -> %s\n', ...
            d.maxdiff, tern(d.maxdiff <= C.gate_cfg.parity_tol, 'EXACT', 'NOT EXACT'));
    end

    %% ---------- 5. deterministic replay ----------
    ic_rep = find(strcmp({Cases.label}, 'X@1.50'), 1);
    if isempty(ic_rep); ic_rep = 1; end
    Rt = Rts(Cases(ic_rep).ir);
    try
        A_id = C.fn.actuator_init(C.variants(1), thrust_min, thrust_max, thrust_trim);
        S_rep = sim_run(paths{Cases(ic_rep).ir}, Rt.T_final, Cases(ic_rep).U, Rt.lambda_muw_ff, ...
            Rt.R_helix, A_id, true, dt, gper, C);
        drep = traj_diff(Run(ic_rep, 1).S, S_rep);
    catch ME
        fprintf(2, '   REPLAY ERROR: %s\n', ME.message);
        drep = struct('maxdiff', Inf, 'worst_channel', ['replay exception: ' ME.message]);
    end
    replay = struct('case', Cases(ic_rep).label, 'variant', 'ideal', ...
        'max_abs_diff', drep.maxdiff, 'exact', drep.maxdiff <= C.gate_cfg.replay_tol, ...
        'worst_channel', drep.worst_channel);
    fprintf('\nReplay %s (ideal): max|diff| = %.3g -> %s\n', replay.case, replay.max_abs_diff, ...
        tern(replay.exact, 'BITWISE IDENTICAL', 'NOT IDENTICAL'));

    %% ---------- 6. gates ----------
    Gres = evaluate_gates(C, Run, Byp, Cases, parity, replay, lim);

    %% ---------- 7. Pareto vector ----------
    Par = pareto_vector(C, Run, Cases);

    %% ---------- 8. compute evidence roll-up ----------
    Comp = compute_evidence(Run, Byp, lim, C);

    %% ---------- 9. fingerprints post ----------
    FP_post = fingerprint_set(project_dir, fp_list);
    [fp_ok, fp_detail] = fingerprint_compare(FP_pre, FP_post);
    Gres.G7.pass = fp_ok && frozen_ok;
    Gres.G7.detail = fp_detail;

    %% ---------- 10. verdict (core, pre artifact self-check) ----------
    ids_core  = {'G1','G2','G3','G3C','G4','G5','G6','G7'};
    ids_final = {'G1','G2','G3','G3C','G4','G5','G6','G7','G8'};
    core = core_verdict(C, Gres, ids_core);
    fprintf('\nCore verdict (all gates except post-write artifact self-check): %s\n', core.verdict);

    %% ---------- 11. artifacts ----------
    md_path  = fullfile(out_dir, [tag '.md']);
    mat_path = fullfile(out_dir, [tag '.mat']);
    png_path = fullfile(out_dir, [tag '.png']);

    try
        write_png(png_path, C, Run, Byp, Cases, Gres, Par, Comp, core, task_id);
    catch ME
        fprintf(2, 'PNG write failed: %s\n', ME.message);
    end
    png_info = check_artifact(png_path, C.gate_cfg.artifact_min_png_bytes);

    Lim = limiting_structure(C, Gres, Run, Cases, core);

    write_md(md_path, task_id, C, Cases, Run, Byp, lim, Gres, Par, Comp, core, Lim, ...
        parity, replay, FP_pre, FP_post, fp_detail, frozen, src, ...
        md_path, mat_path, png_path, png_info, Kcor);
    md_info = check_artifact(md_path, C.gate_cfg.artifact_min_md_bytes);
    md_info.has_sections = false;
    if md_info.exists
        mtxt = fileread(md_path);
        md_info.has_sections = contains(mtxt, '## Gate ledger') && ...
            contains(mtxt, '## Propulsion / power / energy budget') && ...
            contains(mtxt, '## Compute evidence');
    end

    Out = build_out(task_id, C, Cases, Run, Byp, lim, Gres, Par, Comp, core, Lim, ...
        parity, replay, FP_pre, FP_post, frozen, src, Kcor, md_path, mat_path, png_path);
    Out.artifact_png = png_info;
    Out.artifact_md  = md_info;
    save(mat_path, '-struct', 'Out', '-v7.3');
    mat_info = check_artifact(mat_path, 1000);
    mat_info.reloadable = false;
    try
        mf = matfile(mat_path);
        mat_info.reloadable = strcmp(mf.task_id, task_id);
    catch
        mat_info.reloadable = false;
    end

    art_ok = png_info.ok && md_info.ok && md_info.has_sections && mat_info.ok && mat_info.reloadable;
    Gres.G8.pass = art_ok;
    Gres.G8.detail = sprintf('png=%dB(%s) md=%dB(%s,sections=%s) mat=%dB(%s,reload=%s)', ...
        png_info.bytes, yn(png_info.ok), md_info.bytes, yn(md_info.ok), yn(md_info.has_sections), ...
        mat_info.bytes, yn(mat_info.ok), yn(mat_info.reloadable));
    final = core_verdict(C, Gres, ids_final);

    %% ---------- 12. memory + close-out ----------
    ws = whos;
    mem_workspace_MiB = sum([ws.bytes]) / 2^20;
    mem_matlab_MiB = NaN;
    try
        mem = memory; %#ok<MEMSIZ>
        mem_matlab_MiB = mem.MemUsedMATLAB / 2^20;
    catch
    end
    host_runtime_s = toc(t_wall0);

    fid = fopen(md_path, 'a');
    fprintf(fid, '\n## Artifact self-check (post-write) and FINAL VERDICT\n\n');
    fprintf(fid, '| Artifact | Bytes | Readable | Note |\n|---|--:|:--:|---|\n');
    fprintf(fid, '| `%s` | %d | %s | >= %d B required |\n', png_path, png_info.bytes, ...
        yn(png_info.ok), C.gate_cfg.artifact_min_png_bytes);
    fprintf(fid, '| `%s` | %d | %s | required sections present: %s |\n', md_path, md_info.bytes, ...
        yn(md_info.ok), yn(md_info.has_sections));
    fprintf(fid, '| `%s` | %d | %s | reloadable via matfile: %s |\n\n', mat_path, mat_info.bytes, ...
        yn(mat_info.ok), yn(mat_info.reloadable));
    fprintf(fid, '- G8 readable artifacts: **%s**\n', pf(Gres.G8.pass));
    fprintf(fid, '- Host runtime (whole task, one MATLAB invocation): **%.1f s**\n', host_runtime_s);
    fprintf(fid, ['- Task workspace footprint: **%.1f MiB** against the 300 MiB budget ', ...
        '(whole MATLAB process, including its own baseline, %.1f MiB)\n'], ...
        mem_workspace_MiB, mem_matlab_MiB);
    fprintf(fid, '\n### FINAL VERDICT: %s\n\n', final.verdict);
    fprintf(fid, '%s\n', final.reason);
    fprintf(fid, '\n- Promotion: **NONE** (Gate6 isolated budget study).\n');
    fprintf(fid, '- Status: **SIMULATION_ONLY / NOT_CERTIFIED**. Gate4 evidence shadow-only.\n');
    fprintf(fid, '- Next: `%s`\n', Lim.next_gate);
    fclose(fid);

    Out.final_verdict = final.verdict;
    Out.final_reason  = final.reason;
    Out.gates = Gres;
    Out.artifact_mat = mat_info;
    Out.host_runtime_s = host_runtime_s;
    Out.mem_workspace_MiB = mem_workspace_MiB;
    Out.mem_matlab_MiB = mem_matlab_MiB;
    save(mat_path, '-struct', 'Out', '-v7.3');

    try
        append_logs(out_dir, task_id, final, Gres, Par, Lim, Comp, Run, Cases, C, ...
            md_path, mat_path, png_path);
    catch ME
        fprintf(2, 'log append failed: %s\n', ME.message);
    end

    fprintf('\n================ %s ================\n', task_id);
    fprintf('FINAL VERDICT: %s\n', final.verdict);
    fprintf('%s\n', final.reason);
    fprintf('Limiting case: %s | next structure: %s\n', Lim.limiting_case, Lim.next_gate);
    fprintf('Host runtime %.1f s | workspace %.1f MiB | MATLAB %.1f MiB\n', ...
        host_runtime_s, mem_workspace_MiB, mem_matlab_MiB);
    fprintf('Saved:\n  %s\n  %s\n  %s\n', md_path, mat_path, png_path);
    fprintf('Promotion: NONE. SIMULATION_ONLY / NOT_CERTIFIED.\n');
    assignin('base', 'PROPULSION_POWER_COMPUTE_BASELINE_VERDICT', final.verdict);
end

function ppc_emergency(ME)
% One MATLAB invocation only: if anything escapes, still leave a readable,
% honest FAIL artifact instead of nothing.
    fclose('all');
    project_dir = fileparts(mfilename('fullpath'));
    out_dir = fullfile(project_dir, 'suite_results');
    if ~exist(out_dir, 'dir'); mkdir(out_dir); end
    task_id = 'PROPULSION_POWER_COMPUTE_BASELINE_001';
    md_path  = fullfile(out_dir, 'PROPULSION_POWER_COMPUTE_BASELINE.md');
    mat_path = fullfile(out_dir, 'PROPULSION_POWER_COMPUTE_BASELINE.mat');
    trace = '';
    for i = 1:numel(ME.stack)
        trace = [trace sprintf('  %s:%d (%s)\n', ME.stack(i).file, ME.stack(i).line, ME.stack(i).name)]; %#ok<AGROW>
    end
    fid = fopen(md_path, 'w');
    fprintf(fid, '# %s — ABORTED\n\n', task_id);
    fprintf(fid, '**FINAL VERDICT: FAIL (harness exception; no gate evidence produced)**\n\n');
    fprintf(fid, '- Exception: `%s`\n- Message: %s\n\n```\n%s```\n\n', ME.identifier, ME.message, trace);
    fprintf(fid, '- Promotion: NONE. SIMULATION_ONLY / NOT_CERTIFIED. Gate4 shadow-only.\n');
    fprintf(fid, '- Production untouched; no tuning, no rerun performed.\n');
    fprintf(fid, '- Next: repair the Gate6 harness in its own isolated task; Gate6B remains blocked.\n');
    fclose(fid);
    Out = struct('task_id', task_id, 'final_verdict', 'FAIL', ...
        'final_reason', ['harness exception: ' ME.message], 'exception_id', ME.identifier, ...
        'stack_text', trace, 'production_edited', false, 'tuning_performed', false, ...
        'rerun_performed', false);
    save(mat_path, '-struct', 'Out', '-v7.3');
    fprintf(2, '\n%s ABORTED: %s\n%s\n', task_id, ME.message, trace);
    fprintf('FINAL VERDICT: FAIL (harness exception). Artifacts: %s , %s\n', md_path, mat_path);
end

%% ===================== simulation =====================
function S = sim_run(path, T_final, Uref, lambda, R_helix, A, use_act, dt, gper, C) %#ok<INUSD>
% Fixed-step closed loop: guidance_law -> controller_law -> ASSUMED thruster
% actuator -> nonlinear 6DOF plant (ode45 per control step). Same loop shape as
% the established R10 logged loop in run_speed_envelope_audit.m, used for every
% route so that the actuator can be inserted between controller and plant
% without touching any production file.
    global desired_speed lambda_muw_ff %#ok<GVMIS>
    global last_guidance_U_h last_guidance_kappa last_r_ff %#ok<GVMIS>
    global last_delta_e last_delta_r %#ok<GVMIS>
    global PPC_RHS_COUNT %#ok<GVMIS>

    clear guidance_law controller_law
    reset_ctrl_globals();
    global last_guidance_U_h last_guidance_kappa last_r_ff %#ok<GVMIS,REDEF>
    global last_delta_e last_delta_r %#ok<GVMIS,REDEF>

    rng(0, 'twister');
    desired_speed = Uref;
    lambda_muw_ff = lambda;

    state = build_state0(path, Uref);
    assert(all(isfinite(state)), 'non-finite IC');
    n = round(T_final / dt);

    S = struct();
    S.dt = dt; S.T_final = T_final; S.Uref = Uref; S.R_helix = R_helix;
    S.t = zeros(n,1); S.vp = zeros(n,3); S.vel = zeros(n,3);
    S.rates = zeros(n,3); S.ori = zeros(n,3);
    S.psi_ref = zeros(n,1); S.theta_ref = zeros(n,1); S.u_ref = zeros(n,1);
    S.u_ctrl = zeros(n,1);
    S.thrust_cmd = zeros(n,1); S.thrust_out = zeros(n,1);
    S.delta_e = zeros(n,1); S.delta_r = zeros(n,1);
    S.Uh = zeros(n,1); S.VD = zeros(n,1);
    S.U_h_guid = zeros(n,1); S.kappa = zeros(n,1); S.r = zeros(n,1);
    S.step_s = zeros(n,1);

    yaw_ref = 0; pitch_ref = 0; u_ref = Uref; r_ff = 0; pitch_ref_dot = 0; pidx = 1;
    PPC_RHS_COUNT = 0;
    n_guid = 0; n_ctrl = 0; n_int = 0;

    for k = 1:n
        tk = tic;
        pos = state(1:3)'; ori = state(4:6)'; rates = state(10:12)';
        u = state(7); v = state(8); w = state(9);
        [Uh, zdot, VD] = inertial_Uh_zdot_vd(ori, u, v, w); %#ok<ASGLU>
        theta_phys_now = -ori(2);

        if mod(k - 1, gper) == 0
            [yaw_ref, pitch_ref, u_ref, pidx, r_ff, pitch_ref_dot] = ...
                guidance_law(pos, path, pidx, u, v, Uh, zdot, theta_phys_now);
            n_guid = n_guid + 1;
        end

        [dr, de, thr_cmd] = controller_law(yaw_ref, pitch_ref, u_ref, ...
            ori(3), ori(2), rates(3), rates(2), u, r_ff, pitch_ref_dot, ori(1), w, rates(1));
        n_ctrl = n_ctrl + 1;

        if use_act
            [thr_out, A] = C.fn.actuator_step(thr_cmd, A, dt);
        else
            thr_out = thr_cmd;
        end

        controls = struct('delta_r', dr, 'delta_e', de, 'thrust', thr_out);
        [~, g] = ode45(@(tt, gg) ppc_plant_rhs(tt, gg, controls), [0 dt], state);
        state = g(end, :)';
        n_int = n_int + 1;

        S.t(k) = k * dt;
        S.vp(k,:) = state(1:3); S.vel(k,:) = state(7:9);
        S.rates(k,:) = state(10:12); S.ori(k,:) = state(4:6);
        S.psi_ref(k) = yaw_ref; S.theta_ref(k) = pitch_ref; S.u_ref(k) = u_ref;
        S.u_ctrl(k) = u;
        S.thrust_cmd(k) = thr_cmd; S.thrust_out(k) = thr_out;
        if isempty(last_delta_e); last_delta_e = de; end
        if isempty(last_delta_r); last_delta_r = dr; end
        S.delta_e(k) = last_delta_e; S.delta_r(k) = last_delta_r;
        S.Uh(k) = Uh; S.VD(k) = VD;
        if isempty(last_guidance_U_h); last_guidance_U_h = Uh; end
        if isempty(last_guidance_kappa)
            if R_helix > 0; last_guidance_kappa = 1 / R_helix; else; last_guidance_kappa = 0; end
        end
        S.U_h_guid(k) = last_guidance_U_h; S.kappa(k) = last_guidance_kappa;
        S.r(k) = rates(3);
        S.step_s(k) = toc(tk);
    end
    S.u_body = S.vel(:,1);
    S.counts = struct('guidance_calls', n_guid, 'controller_calls', n_ctrl, ...
        'integrator_steps', n_int, 'plant_rhs_evals', PPC_RHS_COUNT);
end

function gd = ppc_plant_rhs(t, g, controls)
    global PPC_RHS_COUNT %#ok<GVMIS>
    PPC_RHS_COUNT = PPC_RHS_COUNT + 1;
    gd = underwater777_vehicle_dynamics(t, g, controls);
end

function state0 = build_state0(path, Uref)
    state0 = zeros(12,1);
    state0(1:3) = path(1,:)';
    d = path(2,:) - path(1,:);
    state0(5) = -atan2(d(3), norm(d(1:2)));
    state0(6) = atan2(d(2), d(1));
    state0(7) = Uref;
end

function reset_ctrl_globals()
    clear global last_guidance_U_h last_guidance_kappa last_r_ff
    clear global last_delta_e last_delta_r last_dr_yaw last_dr_p last_dr_damp last_g_ac
    clear global last_int_angle last_int_rate last_de_fb last_de_trim last_de_uw_ff
    global last_guidance_U_h last_guidance_kappa last_r_ff %#ok<GVMIS>
    global last_delta_e last_delta_r last_dr_yaw last_dr_p last_dr_damp last_g_ac %#ok<GVMIS>
    global last_int_angle last_int_rate last_de_fb last_de_trim last_de_uw_ff %#ok<GVMIS>
    last_guidance_U_h = []; last_guidance_kappa = []; last_r_ff = [];
    last_delta_e = []; last_delta_r = [];
    last_dr_yaw = []; last_dr_p = []; last_dr_damp = []; last_g_ac = [];
    last_int_angle = []; last_int_rate = [];
    last_de_fb = []; last_de_trim = []; last_de_uw_ff = [];
end

function [Uh, zdot, VD] = inertial_Uh_zdot_vd(ori, u, v, w)
    phi = ori(1); th = ori(2); psi = ori(3);
    Rm = [cos(psi)*cos(th), cos(psi)*sin(th)*sin(phi)-sin(psi)*cos(phi), cos(psi)*sin(th)*cos(phi)+sin(psi)*sin(phi);
          sin(psi)*cos(th), sin(psi)*sin(th)*sin(phi)+cos(psi)*cos(phi), sin(psi)*sin(th)*cos(phi)-cos(psi)*sin(phi);
          -sin(th),         cos(th)*sin(phi),                            cos(th)*cos(phi)];
    pd = Rm * [u; v; w];
    Uh = hypot(pd(1), pd(2));
    zdot = pd(3);
    VD = pd(3);
end

%% ===================== packing / metrics =====================
function r = empty_run()
    r = struct('label', '', 'route', '', 'gate_key', '', 'U', NaN, 'variant', '', ...
        'S', struct(), 'M', struct(), 'En', struct(), 'timing', struct(), 'counts', struct());
end

function r = failed_run(Cs, variant, msg, Kcor, dt)
% Placeholder with the same shape as a good run so that a single failing case
% cannot destroy the whole (single-invocation) evidence set. Every metric is
% NaN and every gate reads the run as not finite, not bounded, not fitting.
    r = empty_run();
    r.label = Cs.label; r.route = Cs.route; r.gate_key = Cs.gate_key;
    r.U = Cs.U; r.variant = variant;
    n = 2;
    r.S = struct('t', [0; dt], 'vp', nan(n,3), 'ori', nan(n,3), 'vel', nan(n,3), ...
        'rates', nan(n,3), 'u_ref', nan(n,1), 'u_ctrl', nan(n,1), 'u_body', nan(n,1), ...
        'thrust_cmd', nan(n,1), 'thrust_out', nan(n,1), 'delta_e', nan(n,1), ...
        'delta_r', nan(n,1), 'Uh', nan(n,1), 'VD', nan(n,1), 'psi_ref', nan(n,1), ...
        'theta_ref', nan(n,1), 'dt', dt, 'Uref', Cs.U, 'R_helix', NaN, ...
        'r', nan(n,1), 'kappa', nan(n,1), 'U_h_guid', nan(n,1));
    M = struct();
    M.error = msg;
    M.window = struct('mode', 'run failed', 'n_ss', 0, 'n_hold', 0);
    M.speed = struct('mae', NaN, 'p95', NaN, 'signed_mean', NaN, 'u_mean', NaN, 'u_ref_mean', NaN);
    ang = struct('mae_deg', NaN, 'p95_deg', NaN, 'rms_deg', NaN, 'n', 0);
    M.theta = ang; M.gamma = ang; M.yaw = ang;
    M.yaw.rudder_sat_ss_pct = NaN; M.yaw.rudder_sat_full_pct = NaN;
    M.yaw.ratio_r_Uh_kappa = NaN; M.yaw.n_ratio_valid = 0;
    M.roll = struct('tilde_mae_deg', NaN, 'p_rms_dps', NaN);
    M.path = struct('mean_cte', NaN, 'max_cte', NaN, 'distance_m', NaN);
    M.act = struct('de_mag_util', NaN, 'dr_mag_util', NaN, 'de_rate_util', NaN, ...
        'dr_rate_util', NaN, 'de_sat_pct', NaN, 'dr_sat_ss_pct', NaN, ...
        'dr_sat_full_pct', NaN, 'chatter_dps', NaN);
    M.fin = struct('moving_duty_pct', NaN, 'de_duty_pct', NaN, 'dr_duty_pct', NaN, ...
        'de_mag_util_pct', NaN, 'dr_mag_util_pct', NaN, 'moving_mask', false(n,1));
    M.thrust = struct('mean', NaN, 'mean_full', NaN, 'peak_abs', NaN, 'min', NaN, 'max', NaN, ...
        'cmd_peak_abs', NaN, 'track_rmse', NaN, 'mag_util', NaN, 'rate_peak', NaN, ...
        'rate_rms', NaN, 'sat_pct', NaN, 'sat_pct_full', NaN, 'margin_to_max', NaN, ...
        'within_mag', false);
    M.bounded = false; M.finite = false;
    r.M = M;
    En = struct();
    En.corner = struct('name', {}, 'P_bus_mean', {}, 'P_bus_peak', {}, ...
        'P_prop_mean', {}, 'P_hydro_mean', {}, 'P_fin_mean', {}, 'P_avi', {}, ...
        'Wh_run', {}, 'Wh_per_km', {}, 'Wh_mission', {}, 'I_mean', {}, 'I_peak', {}, ...
        'batt_Wh', {}, 'I_cont', {}, 'energy_margin', {}, 'current_margin', {}, ...
        'endurance_km', {}, 'endurance_h', {}, 'fits', {});
    for i = 1:numel(Kcor)
        e = struct('name', Kcor(i).name, 'P_bus_mean', NaN, 'P_bus_peak', NaN, ...
            'P_prop_mean', NaN, 'P_hydro_mean', NaN, 'P_fin_mean', NaN, 'P_avi', Kcor(i).P_avi, ...
            'Wh_run', NaN, 'Wh_per_km', NaN, 'Wh_mission', NaN, 'I_mean', NaN, 'I_peak', NaN, ...
            'batt_Wh', Kcor(i).batt_Wh, 'I_cont', Kcor(i).I_cont, 'energy_margin', NaN, ...
            'current_margin', NaN, 'endurance_km', NaN, 'endurance_h', NaN, 'fits', false);
        En.corner(end+1) = e; %#ok<AGROW>
    end
    En.worst = En.corner(1); En.nominal = En.corner(2); En.best = En.corner(3);
    En.P_bus_mean_range = [NaN NaN]; En.Wh_per_km_range = [NaN NaN]; En.I_peak_range = [NaN NaN];
    r.En = En;
    r.timing = struct('ms_mean', NaN, 'ms_p95', NaN, 'ms_max', NaN, 'loop_s', 0, 'host_duty', NaN);
    r.counts = struct('guidance_calls', 0, 'controller_calls', 0, ...
        'integrator_steps', 0, 'plant_rhs_evals', 0);
end

function r = pack_run(S, Cs, variant, lim, C, Kcor, path)
    r = empty_run();
    r.label = Cs.label; r.route = Cs.route; r.gate_key = Cs.gate_key;
    r.U = Cs.U; r.variant = variant;
    r.M = analyze_run(S, path, lim, C, Cs);
    r.En = energy_budget(S, C, Kcor, r.M);
    st = S.step_s;
    r.timing = struct('ms_mean', 1000*mean(st), 'ms_p95', 1000*pct_local(st, 95), ...
        'ms_max', 1000*max(st), 'loop_s', sum(st), ...
        'host_duty', mean(st) / S.dt);
    r.counts = S.counts;
    r.S = compact_S(S);
end

function Sc = compact_S(S)
    Sc = struct();
    keep = {'t','vp','ori','vel','rates','u_ref','u_ctrl','u_body','thrust_cmd', ...
            'thrust_out','delta_e','delta_r','Uh','VD','psi_ref','theta_ref', ...
            'dt','Uref','R_helix','r','kappa','U_h_guid'};
    for i = 1:numel(keep)
        if isfield(S, keep{i}); Sc.(keep{i}) = S.(keep{i}); end
    end
end

function M = analyze_run(S, path, lim, C, Cs)
    t = S.t(:); dt = S.dt; n = numel(t);
    phi = S.ori(:,1); theta_phys = -S.ori(:,2); psi = S.ori(:,3);
    p = S.rates(:,1);
    de = S.delta_e(:); dr = S.delta_r(:); T = S.thrust_out(:); Tc = S.thrust_cmd(:);
    e_psi = wrap_pi(S.psi_ref - psi);
    e_th  = wrap_pi(S.theta_ref - theta_phys);
    e_u   = S.u_ref - S.u_ctrl;
    gamma_act = atan2(S.VD, max(S.Uh, 1e-9));
    [gamma_ref, cte, s_prog, s_total] = path_gamma_cte(path, S.vp);
    e_gamma = wrap_pi(gamma_ref - gamma_act);

    before_end = s_prog <= 0.90 * s_total;
    mask_ss = (t >= 5.0) & before_end;
    if nnz(mask_ss) < 20; mask_ss = (t >= 5.0); end
    if nnz(mask_ss) < 20; mask_ss = true(n,1); end
    mask_hold = mask_ss & (abs(S.u_ref - Cs.U) <= 0.08);
    if nnz(mask_hold) < 10; mask_hold = mask_ss; end
    mask_full = true(n,1);

    de_dot = [0; diff(de)] / dt;
    dr_dot = [0; diff(dr)] / dt;
    T_dot  = [0; diff(T)]  / dt;

    M = struct();
    M.window = struct('mode', 't>=5s and path progress<=90%', ...
        'n_ss', nnz(mask_ss), 'n_hold', nnz(mask_hold));
    M.speed = struct('mae', mean_safe(abs(e_u), mask_hold), ...
        'p95', pct_masked(abs(e_u), mask_hold, 95), ...
        'signed_mean', mean_safe(e_u, mask_hold), ...
        'u_mean', mean_safe(S.u_ctrl, mask_hold), ...
        'u_ref_mean', mean_safe(S.u_ref, mask_hold));
    M.theta = err_deg(e_th, mask_ss);
    M.gamma = err_deg(e_gamma, mask_ss);
    M.yaw   = err_deg(e_psi, mask_ss);
    sat_thr_r = tern_num(S.R_helix > 0, 0.95 * lim.dr_max, 0.98 * lim.dr_max);
    M.yaw.rudder_sat_ss_pct   = sat_pct(dr, mask_ss, sat_thr_r);
    M.yaw.rudder_sat_full_pct = sat_pct(dr, mask_full, sat_thr_r);
    M.yaw.ratio_r_Uh_kappa = NaN; M.yaw.n_ratio_valid = 0;
    if S.R_helix > 0
        Uhk = S.U_h_guid(:) .* S.kappa(:);
        vr = mask_ss & (abs(S.kappa(:)) > 1e-4) & (abs(S.U_h_guid(:)) > 0.3);
        if any(vr)
            mr = mean(S.r(vr)); mk = mean(Uhk(vr));
            if mk < 0; mk = -mk; mr = -mr; end
            M.yaw.ratio_r_Uh_kappa = mr / max(abs(mk), 1e-9);
            M.yaw.n_ratio_valid = nnz(vr);
        end
    end
    M.roll = struct('tilde_mae_deg', rad2deg(mean_safe(abs(phi - C.HG.phi_eq.(Cs.gate_key)), mask_ss)), ...
        'p_rms_dps', rad2deg(rms_safe(p(mask_ss))));
    M.path = struct('mean_cte', mean_safe(abs(cte), mask_ss), 'max_cte', max_safe(abs(cte), mask_ss), ...
        'distance_m', sum(sqrt(sum(diff(S.vp).^2, 2))));

    M.act = struct();
    M.act.de_mag_util = mean_safe(abs(de), mask_ss) / lim.de_max;
    M.act.dr_mag_util = mean_safe(abs(dr), mask_ss) / lim.dr_max;
    M.act.de_rate_util = rms_safe(de_dot(mask_ss)) / lim.de_rate;
    M.act.dr_rate_util = rms_safe(dr_dot(mask_ss)) / lim.dr_rate;
    M.act.de_sat_pct = sat_pct(de, mask_ss, 0.98 * lim.de_max);
    M.act.dr_sat_ss_pct = M.yaw.rudder_sat_ss_pct;
    M.act.dr_sat_full_pct = M.yaw.rudder_sat_full_pct;
    if nnz(mask_ss) > 10
        M.act.chatter_dps = rad2deg(std([0; diff(detrend(e_th(mask_ss)))] / dt));
    else
        M.act.chatter_dps = NaN;
    end

    % fin duty (energy-relevant): moving fraction and holding load
    fmv = C.energy.fin_move_frac;
    moving = (abs(de_dot) > fmv * lim.de_rate) | (abs(dr_dot) > fmv * lim.dr_rate);
    M.fin = struct('moving_duty_pct', 100 * mean(moving), ...
        'de_duty_pct', 100 * mean(abs(de_dot) > fmv * lim.de_rate), ...
        'dr_duty_pct', 100 * mean(abs(dr_dot) > fmv * lim.dr_rate), ...
        'de_mag_util_pct', 100 * M.act.de_mag_util, ...
        'dr_mag_util_pct', 100 * M.act.dr_mag_util, ...
        'moving_mask', moving);

    % thrust channel
    thr_span = max(abs([lim.thrust_min, lim.thrust_max]));
    M.thrust = struct();
    M.thrust.mean = mean_safe(T, mask_hold);
    M.thrust.mean_full = mean(T);
    M.thrust.peak_abs = max(abs(T));
    M.thrust.min = min(T);
    M.thrust.max = max(T);
    M.thrust.cmd_peak_abs = max(abs(Tc));
    M.thrust.track_rmse = rms_safe(T - Tc);
    M.thrust.mag_util = M.thrust.peak_abs / max(thr_span, eps);
    M.thrust.rate_peak = max(abs(T_dot));
    M.thrust.rate_rms = rms_safe(T_dot);
    M.thrust.sat_pct = 100 * mean(T(mask_hold) >= 0.98 * lim.thrust_max | ...
        T(mask_hold) <= lim.thrust_min + 0.02 * abs(lim.thrust_min));
    M.thrust.sat_pct_full = 100 * mean(T >= 0.98 * lim.thrust_max | ...
        T <= lim.thrust_min + 0.02 * abs(lim.thrust_min));
    M.thrust.margin_to_max = 1 - M.thrust.peak_abs / max(abs(lim.thrust_max), eps);
    M.thrust.within_mag = all(T <= lim.thrust_max + C.gate_cfg.thrust_mag_tol) && ...
        all(T >= lim.thrust_min - C.gate_cfg.thrust_mag_tol);

    M.bounded = all(isfinite([S.ori(:); S.vel(:); S.rates(:); T; de; dr])) && ...
        all(abs(theta_phys) < deg2rad(80)) && all(abs(S.u_body) < 5.0) && ...
        all(abs(S.rates(:)) < deg2rad(200));
    M.finite = all(isfinite([S.vp(:); S.ori(:); S.vel(:); S.rates(:); T; Tc; de; dr]));
end

function st = err_deg(e, mask)
    st = struct('mae_deg', NaN, 'p95_deg', NaN, 'rms_deg', NaN, 'n', 0);
    if ~any(mask); return; end
    v = e(mask);
    st.n = numel(v);
    st.mae_deg = rad2deg(mean(abs(v)));
    st.rms_deg = rad2deg(rms_safe(v));
    st.p95_deg = rad2deg(pct_local(abs(v), 95));
end

function [gamma_ref, cte_perp, s_prog, s_total] = path_gamma_cte(path, vp)
    n = size(vp,1);
    ds = [0; sqrt(sum(diff(path).^2, 2))];
    s_nodes = cumsum(ds);
    s_total = s_nodes(end);
    s_prog = zeros(n,1); gamma_ref = zeros(n,1); cte_perp = zeros(n,1);
    for i = 1:n
        d = path - vp(i,:);
        [~, idx] = min(sum(d.^2, 2));
        idx = max(1, min(size(path,1) - 1, idx));
        s_prog(i) = s_nodes(idx);
        tv = path(idx+1,:) - path(idx,:);
        tn = norm(tv);
        if tn < 1e-9; tv = [1 0 0]; else; tv = tv / tn; end
        gamma_ref(i) = atan2(tv(3), norm(tv(1:2)));
        e = vp(i,:) - path(idx,:);
        th = tv(1:2); nth = norm(th);
        if nth < 1e-9; nh = [0 1]; else; th = th / nth; nh = [-th(2), th(1)]; end
        cte_perp(i) = hypot(dot(e(1:2), nh), e(3));
    end
end

%% ===================== energy budget =====================
function En = energy_budget(S, C, Kcor, M)
    t = S.t(:); T = S.thrust_out(:);
    U = max(S.u_body(:), 0);
    moving = M.fin.moving_mask(:);
    dist_m = max(M.path.distance_m, 1e-6);
    En = struct();
    En.corner = struct('name', {}, 'P_bus_mean', {}, 'P_bus_peak', {}, ...
        'P_prop_mean', {}, 'P_hydro_mean', {}, 'P_fin_mean', {}, 'P_avi', {}, ...
        'Wh_run', {}, 'Wh_per_km', {}, 'Wh_mission', {}, 'I_mean', {}, 'I_peak', {}, ...
        'batt_Wh', {}, 'I_cont', {}, 'energy_margin', {}, 'current_margin', {}, ...
        'endurance_km', {}, 'endurance_h', {}, 'fits', {});
    for i = 1:numel(Kcor)
        K = Kcor(i);
        P = C.fn.bus_power(T, U, moving, K);
        Wh_run = trapz(t, P.P_bus) / 3600;
        Wh_km  = Wh_run / (dist_m / 1000);
        Wh_mis = Wh_km * C.energy.mission_km;
        Ipk = max(P.I_bus); Imn = mean(P.I_bus);
        e = struct();
        e.name = K.name;
        e.P_bus_mean = mean(P.P_bus); e.P_bus_peak = max(P.P_bus);
        e.P_prop_mean = mean(P.P_prop_elec); e.P_hydro_mean = mean(P.P_hydro_ideal);
        e.P_fin_mean = mean(P.P_fin); e.P_avi = K.P_avi;
        e.Wh_run = Wh_run; e.Wh_per_km = Wh_km; e.Wh_mission = Wh_mis;
        e.I_mean = Imn; e.I_peak = Ipk;
        e.batt_Wh = K.batt_Wh; e.I_cont = K.I_cont;
        e.energy_margin = 1 - Wh_mis / K.batt_Wh;
        e.current_margin = 1 - Ipk / K.I_cont;
        e.endurance_km = K.batt_Wh / max(Wh_km, eps);
        e.endurance_h = (K.batt_Wh / max(e.P_bus_mean, eps));
        e.fits = (Wh_mis <= K.batt_Wh) && (Ipk <= K.I_cont);
        En.corner(end+1) = e; %#ok<AGROW>
    end
    En.worst = En.corner(1); En.nominal = En.corner(2); En.best = En.corner(3);
    En.P_bus_mean_range = [En.best.P_bus_mean, En.worst.P_bus_mean];
    En.Wh_per_km_range  = [En.best.Wh_per_km,  En.worst.Wh_per_km];
    En.I_peak_range     = [En.best.I_peak,     En.worst.I_peak];
end

%% ===================== gates =====================
function G = evaluate_gates(C, Run, Byp, Cases, parity, replay, lim)
    nC = numel(Cases); nV = numel(C.variants);
    G = struct();

    % G1 ideal parity
    G.G1 = struct('name', 'ideal parity (bitwise vs bypass)', 'class', 'MANDATORY', ...
        'pass', all([parity.exact]), ...
        'detail', sprintf('%d/%d cases bitwise identical; max|diff| over cases = %.3g', ...
            sum([parity.exact]), numel(parity), max([parity.max_abs_diff])));

    % G2 finite / bounded
    fin_ok = true; bnd_ok = true; bad = '';
    for ic = 1:nC
        if ~Byp(ic).M.finite || ~Byp(ic).M.bounded
            fin_ok = fin_ok && Byp(ic).M.finite; bnd_ok = bnd_ok && Byp(ic).M.bounded;
            bad = [bad sprintf('%s/bypass ', Cases(ic).label)]; %#ok<AGROW>
        end
        for iv = 1:nV
            M = Run(ic,iv).M;
            if ~M.finite || ~M.bounded
                fin_ok = fin_ok && M.finite; bnd_ok = bnd_ok && M.bounded;
                bad = [bad sprintf('%s/%s ', Cases(ic).label, Run(ic,iv).variant)]; %#ok<AGROW>
            end
        end
    end
    G.G2 = struct('name', 'finite / bounded states, all runs', 'class', 'MANDATORY', ...
        'pass', fin_ok && bnd_ok, ...
        'detail', tern(fin_ok && bnd_ok, sprintf('%d runs finite and bounded', nC*(nV+1)), ...
            ['violations: ' bad]));

    % G3 / G3C existing tracking + actuator gate set
    Score = repmat(struct('pass', false, 'first_limit', '', 'worst_margin', NaN), nC, nV);
    for ic = 1:nC
        for iv = 1:nV
            Score(ic,iv) = score_existing(Run(ic,iv).M, Cases(ic).gate_key, C.HG);
        end
    end
    iv_id = find(strcmp({C.variants.name}, 'ideal'), 1);
    id_pass = all([Score(:,iv_id).pass]);
    id_fail = ''; 
    for ic = 1:nC
        if ~Score(ic,iv_id).pass
            id_fail = [id_fail sprintf('%s:%s; ', Cases(ic).label, Score(ic,iv_id).first_limit)]; %#ok<AGROW>
        end
    end
    G.G3 = struct('name', 'existing pitch/gamma/yaw/actuator gates (ideal)', 'class', 'MANDATORY', ...
        'pass', id_pass, 'detail', tern(id_pass, ...
            sprintf('all %d ideal cases inside the frozen SPEED_ENVELOPE_AUDIT hard gates', nC), id_fail));

    oth = setdiff(1:nV, iv_id);
    c_pass = all(all([Score(:,oth).pass]));
    c_fail = '';
    for ic = 1:nC
        for iv = oth
            if ~Score(ic,iv).pass
                c_fail = [c_fail sprintf('%s/%s:%s; ', Cases(ic).label, C.variants(iv).name, ...
                    Score(ic,iv).first_limit)]; %#ok<AGROW>
            end
        end
    end
    G.G3C = struct('name', 'existing gates under ASSUMED variants', 'class', 'CONDITIONAL', ...
        'pass', c_pass, 'detail', tern(c_pass, 'all ASSUMED variants inside the frozen hard gates', c_fail));
    G.score = Score;

    % G4 thrust magnitude / rate compliance
    t_ok = true; t_detail = '';
    for ic = 1:nC
        for iv = 1:nV
            M = Run(ic,iv).M; V = C.variants(iv);
            mag_ok = M.thrust.within_mag;
            if isinf(V.rate_max_Nps)
                rate_ok = true;
            else
                rate_ok = M.thrust.rate_peak <= V.rate_max_Nps * (1 + C.gate_cfg.thrust_rate_tol) + 1e-9;
            end
            if ~(mag_ok && rate_ok)
                t_ok = false;
                t_detail = [t_detail sprintf('%s/%s(mag=%s,rate=%s) ', Cases(ic).label, ...
                    V.name, yn(mag_ok), yn(rate_ok))]; %#ok<AGROW>
            end
        end
    end
    G.G4 = struct('name', 'thrust magnitude/rate limit compliance', 'class', 'MANDATORY', ...
        'pass', t_ok, 'detail', tern(t_ok, sprintf(['realized thrust in [%.3f, %.3f] N and ', ...
            'within the declared slew limit for all %d runs'], lim.thrust_min, lim.thrust_max, nC*nV), t_detail));

    % G5 conditional battery / current envelope (worst corner)
    b_ok = true; b_detail = ''; worst_em = Inf; worst_cm = Inf; worst_lbl = '';
    for ic = 1:nC
        for iv = 1:nV
            e = Run(ic,iv).En.worst;
            if e.energy_margin < worst_em; worst_em = e.energy_margin; worst_lbl = sprintf('%s/%s', Cases(ic).label, C.variants(iv).name); end
            worst_cm = min(worst_cm, e.current_margin);
            if ~e.fits
                b_ok = false;
                b_detail = [b_detail sprintf('%s/%s(Wh=%.1f>%.0f or I=%.1f>%.0f) ', ...
                    Cases(ic).label, C.variants(iv).name, e.Wh_mission, e.batt_Wh, e.I_peak, e.I_cont)]; %#ok<AGROW>
            end
        end
    end
    G.G5 = struct('name', 'battery/current envelope (worst ASSUMED corner)', 'class', 'CONDITIONAL', ...
        'pass', b_ok, 'detail', sprintf(['worst-corner energy margin %.3f (%s), current margin %.3f; ', ...
            'CONDITIONAL on ASSUMED hardware ranges. %s'], worst_em, worst_lbl, worst_cm, b_detail));
    G.worst_energy_margin = worst_em;
    G.worst_current_margin = worst_cm;

    % G6 deterministic replay
    G.G6 = struct('name', 'deterministic replay (bitwise)', 'class', 'MANDATORY', ...
        'pass', replay.exact, 'detail', sprintf('%s ideal re-run: max|diff| = %.3g (%s)', ...
            replay.case, replay.max_abs_diff, replay.worst_channel));

    % G7 / G8 filled by the caller
    G.G7 = struct('name', 'exact production / CODEX_VERTICAL_PLAN fingerprints', ...
        'class', 'MANDATORY', 'pass', false, 'detail', 'pending');
    G.G8 = struct('name', 'readable artifacts (md/mat/png)', 'class', 'MANDATORY', ...
        'pass', false, 'detail', 'pending');
end

function F = score_existing(M, key, HG)
% Frozen SPEED_ENVELOPE_AUDIT_001 absolute hard-gate set, verbatim thresholds.
    h = HG.(key);
    order = {};
    order{end+1} = {M.bounded, 'states_unbounded'};
    order{end+1} = {~isnan(M.theta.mae_deg) && M.theta.mae_deg <= h.pitch_mae, ...
        sprintf('pitch_MAE(%.4f>%.2f)', nz(M.theta.mae_deg), h.pitch_mae)};
    order{end+1} = {~isnan(M.theta.p95_deg) && M.theta.p95_deg <= h.pitch_p95, ...
        sprintf('pitch_p95(%.4f>%.2f)', nz(M.theta.p95_deg), h.pitch_p95)};
    order{end+1} = {~isnan(M.gamma.mae_deg) && M.gamma.mae_deg <= h.gamma_mae, ...
        sprintf('gamma_MAE(%.4f>%.2f)', nz(M.gamma.mae_deg), h.gamma_mae)};
    order{end+1} = {~isnan(M.gamma.p95_deg) && M.gamma.p95_deg <= h.gamma_p95, ...
        sprintf('gamma_p95(%.4f>%.2f)', nz(M.gamma.p95_deg), h.gamma_p95)};
    if strcmp(key, 'H')
        order{end+1} = {~isnan(M.yaw.mae_deg) && M.yaw.mae_deg <= HG.H.yaw_mae, ...
            sprintf('yaw_MAE(%.4f>%.2f)', nz(M.yaw.mae_deg), HG.H.yaw_mae)};
        order{end+1} = {~isnan(M.yaw.p95_deg) && M.yaw.p95_deg <= HG.H.yaw_p95, ...
            sprintf('yaw_p95(%.4f>%.2f)', nz(M.yaw.p95_deg), HG.H.yaw_p95)};
        order{end+1} = {~isnan(M.yaw.rudder_sat_ss_pct) && M.yaw.rudder_sat_ss_pct <= HG.rud_sat_ss, ...
            sprintf('rudder_sat_ss(%.2f%%)', nz(M.yaw.rudder_sat_ss_pct))};
        order{end+1} = {~isnan(M.yaw.rudder_sat_full_pct) && M.yaw.rudder_sat_full_pct <= HG.rud_sat_full, ...
            sprintf('rudder_sat_full(%.2f%%)', nz(M.yaw.rudder_sat_full_pct))};
        if ~isnan(M.yaw.ratio_r_Uh_kappa)
            rat_ok = M.yaw.ratio_r_Uh_kappa >= HG.ratio_lo && M.yaw.ratio_r_Uh_kappa <= HG.ratio_hi;
        else
            rat_ok = true;
        end
        order{end+1} = {rat_ok, sprintf('yaw_ratio(%.4f out [%.2f,%.2f])', ...
            nz(M.yaw.ratio_r_Uh_kappa), HG.ratio_lo, HG.ratio_hi)};
        order{end+1} = {~isnan(M.act.chatter_dps) && M.act.chatter_dps <= HG.chatter, ...
            sprintf('chatter(%.4f>%.2f)', nz(M.act.chatter_dps), HG.chatter)};
    else
        order{end+1} = {~isnan(M.yaw.mae_deg) && M.yaw.mae_deg <= HG.X_yaw_mae, ...
            sprintf('yaw_MAE(%.4f>%.2f)', nz(M.yaw.mae_deg), HG.X_yaw_mae)};
    end
    order{end+1} = {~isnan(M.act.de_sat_pct) && M.act.de_sat_pct <= HG.elev_sat, ...
        sprintf('elev_sat(%.2f%%>%.0f%%)', nz(M.act.de_sat_pct), HG.elev_sat)};
    order{end+1} = {~isnan(M.thrust.sat_pct) && M.thrust.sat_pct <= HG.thrust_sat, ...
        sprintf('thrust_sat(%.2f%%>%.0f%%)', nz(M.thrust.sat_pct), HG.thrust_sat)};
    order{end+1} = {~isnan(M.act.de_rate_util) && M.act.de_rate_util <= HG.rate_util, ...
        sprintf('elev_rate_util(%.3f>1)', nz(M.act.de_rate_util))};
    order{end+1} = {~isnan(M.act.dr_rate_util) && M.act.dr_rate_util <= HG.rate_util, ...
        sprintf('rudder_rate_util(%.3f>1)', nz(M.act.dr_rate_util))};

    F = struct('pass', true, 'first_limit', 'none', 'worst_margin', NaN);
    for k = 1:numel(order)
        if ~order{k}{1}
            F.pass = false; F.first_limit = order{k}{2}; break;
        end
    end
    marg = [h.pitch_mae - nz(M.theta.mae_deg), h.pitch_p95 - nz(M.theta.p95_deg), ...
            h.gamma_mae - nz(M.gamma.mae_deg), h.gamma_p95 - nz(M.gamma.p95_deg), ...
            HG.elev_sat - nz(M.act.de_sat_pct), HG.thrust_sat - nz(M.thrust.sat_pct), ...
            HG.rate_util - nz(M.act.de_rate_util), HG.rate_util - nz(M.act.dr_rate_util)];
    marg = marg(isfinite(marg));
    if ~isempty(marg); F.worst_margin = min(marg); end
end

function core = core_verdict(C, G, ids)
    man_fail = {}; con_fail = {};
    for i = 1:numel(ids)
        g = G.(ids{i});
        if ~g.pass
            if strcmp(g.class, 'MANDATORY'); man_fail{end+1} = ids{i}; %#ok<AGROW>
            else; con_fail{end+1} = ids{i}; end %#ok<AGROW>
        end
    end
    core = struct();
    core.mandatory_failed = man_fail;
    core.conditional_failed = con_fail;
    if ~isempty(man_fail)
        core.verdict = 'FAIL';
        core.reason = sprintf(['FAIL: mandatory gate(s) %s not met. Conditional gate(s) not met: %s. ', ...
            'No rerun and no tuning performed in this task.'], strjoin(man_fail, ','), ...
            tern(isempty(con_fail), 'none', strjoin(con_fail, ',')));
    elseif ~isempty(con_fail)
        core.verdict = 'PARTIAL';
        core.reason = sprintf(['PARTIAL: every mandatory gate met; conditional gate(s) %s not met. ', ...
            'Conditional gates depend on ASSUMED / TO_BE_IDENTIFIED hardware numbers, so they ', ...
            'cannot promote or block by themselves. No rerun and no tuning performed.'], ...
            strjoin(con_fail, ','));
    else
        core.verdict = 'PASS';
        core.reason = ['PASS: every mandatory and conditional gate met under the predeclared ', ...
            'ASSUMED hardware ranges. Result is SIMULATION_ONLY / NOT_CERTIFIED and grants no promotion.'];
    end
    core.ids = ids;
    core.n_gates = numel(ids);
    core.ledger = C.gate_ledger;
end

%% ===================== Pareto / limiting structure =====================
function Par = pareto_vector(C, Run, Cases)
    nC = numel(Cases); nV = numel(C.variants);
    Par = struct();
    Par.objectives = {'max pitch MAE [deg]', 'peak thrust [N]', ...
        'worst-corner mission Wh [Wh/km-mission]', 'worst-corner peak bus current [A]', ...
        'fin moving duty [%]', 'host runtime [ms/step]'};
    Par.sense = 'all objectives minimized';
    J = zeros(nV, 6);
    for iv = 1:nV
        pm = 0; pt = 0; wh = 0; ip = 0; fd = 0; ms = 0;
        for ic = 1:nC
            M = Run(ic,iv).M; e = Run(ic,iv).En.worst;
            pm = max(pm, nz0(M.theta.mae_deg));
            pt = max(pt, nz0(M.thrust.peak_abs));
            wh = max(wh, nz0(e.Wh_mission));
            ip = max(ip, nz0(e.I_peak));
            fd = max(fd, nz0(M.fin.moving_duty_pct));
            ms = ms + Run(ic,iv).timing.ms_mean;
        end
        J(iv,:) = [pm, pt, wh, ip, fd, ms/nC];
    end
    Par.J = J;
    Par.variant = {C.variants.name};
    nd = true(nV,1);
    for a = 1:nV
        for b = 1:nV
            if a ~= b && all(J(b,:) <= J(a,:)) && any(J(b,:) < J(a,:))
                nd(a) = false; break;
            end
        end
    end
    Par.nondominated = nd;
    Par.nondominated_names = Par.variant(nd);
end

function L = limiting_structure(C, G, Run, Cases, core)
    L = struct();
    L.limiting_case = 'none (no gate limited)';
    L.limiting_gate = 'none';
    L.next_gate = 'GATE6B_PROPULSION_POWER_COMPUTE_STRESS (only on PASS)';
    L.next_structure = ['Gate6B: extend the same frozen stack with propulsor thrust-map ', ...
        'identification, bus-transient loading and duty-cycled compute, still isolated.'];
    if strcmp(core.verdict, 'PASS'); return; end

    ids = [core.mandatory_failed, core.conditional_failed];
    if isempty(ids); return; end
    L.limiting_gate = strjoin(ids, ',');
    first = ids{1};
    L.next_gate = 'BLOCKED (Gate6B requires PASS)';
    switch first
        case 'G3'
            worst = Inf; lbl = ''; fl = '';
            iv = find(strcmp({C.variants.name}, 'ideal'), 1);
            for ic = 1:numel(Cases)
                s = G.score(ic, iv);
                if ~s.pass && nz0(s.worst_margin) < worst
                    worst = nz0(s.worst_margin); lbl = Cases(ic).label; fl = s.first_limit;
                end
            end
            L.limiting_case = sprintf('%s / ideal (%s)', lbl, fl);
            L.next_structure = ['Tracking, not propulsion, is limiting at the ideal actuator. ', ...
                'The next bounded structure is a speed/route-scheduled reference governor for the ', ...
                'frozen cascade, evaluated in its own isolated gate before any power budget is reopened. ', ...
                'No rerun and no gain change in this task.'];
        case 'G3C'
            worst = Inf; lbl = '';
            for ic = 1:numel(Cases)
                for iv = 1:numel(C.variants)
                    s = G.score(ic, iv);
                    if ~s.pass && nz0(s.worst_margin) < worst
                        worst = nz0(s.worst_margin);
                        lbl = sprintf('%s / %s (%s)', Cases(ic).label, C.variants(iv).name, s.first_limit);
                    end
                end
            end
            L.limiting_case = lbl;
            L.next_structure = ['ASSUMED actuator realism, not the controller, is limiting. ', ...
                'The next bounded structure is thrust-map / lag identification on the real propulsor ', ...
                '(TO_BE_IDENTIFIED) plus a thrust-rate-aware speed reference shaper, each in its own gate.'];
        case 'G5'
            L.limiting_case = sprintf('worst hardware corner (energy margin %.3f, current margin %.3f)', ...
                G.worst_energy_margin, G.worst_current_margin);
            L.next_structure = ['The pessimistic ASSUMED corner does not close the battery/current ', ...
                'envelope. The next bounded structure is propulsor disk-area and efficiency ', ...
                'identification to narrow the range, then a bus-current-limited speed envelope. ', ...
                'No vendor selection is implied.'];
        case 'G4'
            L.limiting_case = 'thrust limit compliance';
            L.next_structure = 'Actuator model / production clamp reconciliation before any further budget work.';
        otherwise
            L.limiting_case = sprintf('gate %s', first);
            L.next_structure = ['Resolve the failing mandatory gate in its own isolated task; ', ...
                'no rerun performed here.'];
    end
end

%% ===================== compute evidence =====================
function K = compute_evidence(Run, Byp, lim, C)
    nC = size(Run,1); nV = size(Run,2);
    ms = []; ms95 = []; msmax = []; duty = [];
    n_g = 0; n_c = 0; n_r = 0; n_i = 0; loop = 0; nruns = 0;
    for ic = 1:nC
        R = Byp(ic);
        ms(end+1) = R.timing.ms_mean; ms95(end+1) = R.timing.ms_p95; %#ok<AGROW>
        msmax(end+1) = R.timing.ms_max; duty(end+1) = R.timing.host_duty; %#ok<AGROW>
        n_g = n_g + R.counts.guidance_calls; n_c = n_c + R.counts.controller_calls;
        n_r = n_r + R.counts.plant_rhs_evals; n_i = n_i + R.counts.integrator_steps;
        loop = loop + R.timing.loop_s; nruns = nruns + 1;
        for iv = 1:nV
            R = Run(ic,iv);
            ms(end+1) = R.timing.ms_mean; ms95(end+1) = R.timing.ms_p95; %#ok<AGROW>
            msmax(end+1) = R.timing.ms_max; duty(end+1) = R.timing.host_duty; %#ok<AGROW>
            n_g = n_g + R.counts.guidance_calls; n_c = n_c + R.counts.controller_calls;
            n_r = n_r + R.counts.plant_rhs_evals; n_i = n_i + R.counts.integrator_steps;
            loop = loop + R.timing.loop_s; nruns = nruns + 1;
        end
    end
    K = struct();
    K.controller_rate_Hz = 1 / lim.dt_controller;
    K.guidance_rate_Hz   = 1 / (lim.guidance_period * lim.dt_controller);
    K.guidance_period_steps = lim.guidance_period;
    K.n_runs = nruns;
    K.guidance_calls = n_g;
    K.controller_calls = n_c;
    K.integrator_steps = n_i;
    K.plant_rhs_evals = n_r;
    K.rhs_per_control_step = n_r / max(n_c, 1);
    K.ms_per_step_mean = mean(ms);
    K.ms_per_step_p95  = max(ms95);
    K.ms_per_step_max  = max(msmax);
    K.host_duty_mean   = mean(duty);
    K.host_duty_max    = max(duty);
    K.loop_total_s     = loop;
    K.disclaimer = C.compute.disclaimer;
    K.is_wcet = false;
end

%% ===================== fingerprints =====================
function FP = fingerprint_set(project_dir, files)
    FP = struct('file', {}, 'exists', {}, 'bytes', {}, 'sha256', {});
    for i = 1:numel(files)
        fp = fullfile(project_dir, files{i});
        e = struct('file', files{i}, 'exists', exist(fp, 'file') == 2, 'bytes', 0, 'sha256', 'MISSING');
        if e.exists
            d = dir(fp);
            e.bytes = d(1).bytes;
            e.sha256 = file_digest(fp);
        end
        FP(end+1) = e; %#ok<AGROW>
    end
end

function h = file_digest(fp)
    fid = fopen(fp, 'r');
    raw = fread(fid, Inf, '*uint8');
    fclose(fid);
    try
        md = java.security.MessageDigest.getInstance('SHA-256');
        md.update(typecast(raw(:), 'int8'));
        d = typecast(md.digest(), 'uint8');
        h = lower(reshape(dec2hex(d, 2)', 1, []));
    catch
        h = ['ADLER32+LEN:' adler32_hex(raw)];
    end
end

function h = adler32_hex(raw)
    a = 1; b = 0; MOD = 65521;
    x = double(raw(:));
    blk = 4000;
    for i = 1:blk:numel(x)
        c = x(i:min(i+blk-1, numel(x)));
        n = numel(c);
        b = mod(b + n * a + sum((n:-1:1)' .* c), MOD);
        a = mod(a + sum(c), MOD);
    end
    h = sprintf('%08x_%d', bitor(bitshift(uint32(b), 16), uint32(a)), numel(x));
end

function [ok, detail] = fingerprint_compare(A, B)
    ok = true; parts = {};
    for i = 1:numel(A)
        same = strcmp(A(i).sha256, B(i).sha256) && (A(i).bytes == B(i).bytes) && ...
            (A(i).exists == B(i).exists);
        ok = ok && same;
        if ~same
            parts{end+1} = sprintf('%s CHANGED', A(i).file); %#ok<AGROW>
        end
    end
    if ok
        detail = sprintf('%d files byte-identical pre/post run (production untouched)', numel(A));
    else
        detail = strjoin(parts, '; ');
    end
end

%% ===================== diffs =====================
function d = traj_diff(S1, S2)
    ch = {'vp','ori','vel','rates','thrust_out','thrust_cmd','delta_e','delta_r','u_ctrl'};
    d = struct('maxdiff', 0, 'worst_channel', 'none');
    if ~isfield(S1, 'thrust_out') || ~isfield(S2, 'thrust_out')
        d.maxdiff = Inf; d.worst_channel = 'missing log (run failed)'; return;
    end
    for i = 1:numel(ch)
        if ~isfield(S1, ch{i}) || ~isfield(S2, ch{i}); continue; end
        a = S1.(ch{i}); b = S2.(ch{i});
        if ~isequal(size(a), size(b))
            d.maxdiff = Inf; d.worst_channel = [ch{i} ':size']; return;
        end
        m = max(abs(a(:) - b(:)));
        if isempty(m); m = 0; end
        if m > d.maxdiff; d.maxdiff = m; d.worst_channel = ch{i}; end
    end
    if d.maxdiff == 0; d.worst_channel = 'all channels bitwise equal'; end
end

%% ===================== artifacts =====================
function info = check_artifact(fp, min_bytes)
    info = struct('path', fp, 'exists', false, 'bytes', 0, 'ok', false);
    if exist(fp, 'file') == 2
        d = dir(fp);
        info.exists = true;
        info.bytes = d(1).bytes;
        info.ok = info.bytes >= min_bytes;
    end
end

function write_png(png_path, C, Run, Byp, Cases, G, Par, Comp, core, task_id) %#ok<INUSL>
    nC = numel(Cases); nV = numel(C.variants);
    vn = {C.variants.name};
    fig = figure('Visible', 'off', 'Color', 'w', 'Position', [40 40 1680 1120]);

    irep = find(strcmp({Cases.label}, 'X@1.50'), 1);
    if isempty(irep); irep = 1; end

    subplot(3,3,1); hold on; grid on;
    plot(Run(irep,1).S.t, Run(irep,1).S.thrust_cmd, 'k--', 'LineWidth', 1.2, 'DisplayName', 'command');
    for iv = 1:nV
        plot(Run(irep,iv).S.t, Run(irep,iv).S.thrust_out, 'LineWidth', 1.1, 'DisplayName', vn{iv});
    end
    xlabel('t [s]'); ylabel('thrust [N]');
    title(sprintf('Realized thrust — %s', Cases(irep).label), 'Interpreter', 'none');
    legend('Location','best','Interpreter','none');

    subplot(3,3,2); hold on; grid on;
    plot(Run(irep,1).S.t, Run(irep,1).S.u_ref, 'k--', 'LineWidth', 1.2, 'DisplayName', 'u_{ref}');
    for iv = 1:nV
        plot(Run(irep,iv).S.t, Run(irep,iv).S.u_body, 'LineWidth', 1.1, 'DisplayName', vn{iv});
    end
    xlabel('t [s]'); ylabel('u [m/s]'); title('Surge speed'); legend('Location','best','Interpreter','none');

    subplot(3,3,3); hold on; grid on;
    Y = zeros(nC, nV);
    for ic = 1:nC; for iv = 1:nV; Y(ic,iv) = nz0(Run(ic,iv).M.theta.mae_deg); end; end
    bar(Y); set(gca, 'XTick', 1:nC, 'XTickLabel', {Cases.label}, 'XTickLabelRotation', 40);
    ylabel('pitch MAE [deg]'); title('Tracking vs gate'); legend(vn, 'Location','best','Interpreter','none');

    subplot(3,3,4); hold on; grid on;
    Y = zeros(nC, nV);
    for ic = 1:nC; for iv = 1:nV; Y(ic,iv) = nz0(Run(ic,iv).M.thrust.peak_abs); end; end
    bar(Y); set(gca, 'XTick', 1:nC, 'XTickLabel', {Cases.label}, 'XTickLabelRotation', 40);
    ylabel('peak |T| [N]'); title('Peak realized thrust');

    subplot(3,3,5); hold on; grid on;
    Yw = zeros(nC, nV); Yb = zeros(nC, nV);
    for ic = 1:nC
        for iv = 1:nV
            Yw(ic,iv) = nz0(Run(ic,iv).En.worst.Wh_per_km);
            Yb(ic,iv) = nz0(Run(ic,iv).En.best.Wh_per_km);
        end
    end
    bar(Yw); plot(1:nC, min(Yb, [], 2), 'k.-', 'LineWidth', 1.2, 'MarkerSize', 14);
    set(gca, 'XTick', 1:nC, 'XTickLabel', {Cases.label}, 'XTickLabelRotation', 40);
    ylabel('Wh / km'); title('Energy: worst corner (bars), best corner (line)');

    subplot(3,3,6); hold on; grid on;
    Y = zeros(nC, nV);
    for ic = 1:nC; for iv = 1:nV; Y(ic,iv) = nz0(Run(ic,iv).En.worst.I_peak); end; end
    bar(Y);
    yline(min(C.energy.I_cont_max_A), 'r--', 'I_{cont} low', 'LineWidth', 1.3);
    set(gca, 'XTick', 1:nC, 'XTickLabel', {Cases.label}, 'XTickLabelRotation', 40);
    ylabel('peak bus current [A]'); title('Worst-corner bus current');

    subplot(3,3,7); hold on; grid on;
    Y = zeros(nC, nV);
    for ic = 1:nC; for iv = 1:nV; Y(ic,iv) = nz0(Run(ic,iv).M.fin.moving_duty_pct); end; end
    bar(Y); set(gca, 'XTick', 1:nC, 'XTickLabel', {Cases.label}, 'XTickLabelRotation', 40);
    ylabel('fin moving duty [%]'); title('Fin duty (energy relevant)');

    subplot(3,3,8); hold on; grid on;
    Ym = zeros(1,nV); Yp = zeros(1,nV);
    for iv = 1:nV
        v = zeros(1,nC); w = zeros(1,nC);
        for ic = 1:nC; v(ic) = Run(ic,iv).timing.ms_mean; w(ic) = Run(ic,iv).timing.ms_p95; end
        Ym(iv) = mean(v); Yp(iv) = max(w);
    end
    bar([Ym; Yp]'); set(gca, 'XTick', 1:nV, 'XTickLabel', vn, 'XTickLabelRotation', 20);
    ylabel('host ms / control step'); title('Host runtime (NOT WCET)');
    legend({'mean','p95'}, 'Location','best');

    subplot(3,3,9); axis off;
    ids = {'G1','G2','G3','G3C','G4','G5','G6','G7','G8'};
    lines = sprintf('%s   verdict(core)=%s\n', task_id, core.verdict);
    for i = 1:numel(ids)
        g = G.(ids{i});
        lines = [lines sprintf('%-4s %-9s %-4s %s\n', ids{i}, g.class(1:min(9,end)), ...
            pf(g.pass), trunc(g.name, 42))]; %#ok<AGROW>
    end
    lines = [lines sprintf('\nPareto non-dominated: %s\n', strjoin(Par.nondominated_names, ', '))];
    lines = [lines sprintf('controller %.1f Hz | guidance %.1f Hz | %.2f ms/step host\n', ...
        Comp.controller_rate_Hz, Comp.guidance_rate_Hz, Comp.ms_per_step_mean)];
    lines = [lines sprintf('SIMULATION_ONLY / NOT_CERTIFIED | hardware ASSUMED / TO_BE_IDENTIFIED\n')];
    text(0.0, 1.0, lines, 'FontName', 'FixedWidth', 'FontSize', 9, ...
        'VerticalAlignment', 'top', 'Interpreter', 'none');

    sgtitle(sprintf('%s — isolated propulsion / power / compute budget (no promotion)', task_id), ...
        'Interpreter', 'none');
    exportgraphics(fig, png_path, 'Resolution', 130);
    close(fig);
end

function write_md(md_path, task_id, C, Cases, Run, Byp, lim, G, Par, Comp, core, L, ...
        parity, replay, FP_pre, FP_post, fp_detail, frozen, src, md_p, mat_p, png_p, png_info, Kcor) %#ok<INUSL>
    nC = numel(Cases); nV = numel(C.variants); vn = {C.variants.name};
    fid = fopen(md_path, 'w');

    fprintf(fid, '# %s — isolated propulsion / power / compute budget (Gate6)\n\n', task_id);
    fprintf(fid, '**Verdict (all gates except the post-write artifact self-check): %s**\n\n', core.verdict);
    fprintf(fid, '> %s\n\n', core.reason);
    fprintf(fid, '- Promotion: **NONE**. This is an isolated Gate6 budget study.\n');
    fprintf(fid, '- Status: **SIMULATION_ONLY / NOT_CERTIFIED**. Gate4 evidence is **shadow-only** here.\n');
    fprintf(fid, '- Hardware numerics: **ASSUMED / TO_BE_IDENTIFIED**, emitted as ranges. **No vendor selection.**\n');
    fprintf(fid, '- Compute evidence is call rates/counts and host runtime. **It is not WCET** and grants no real-time claim.\n');
    fprintf(fid, '- No tuning: every gain, limit and threshold was frozen before the run and verified byte-identical after it.\n\n');

    fprintf(fid, '## Provenance and freeze\n\n');
    fprintf(fid, '- Read-only sources (exactly three): `%s`, `%s`, `%s`\n', src.audit, src.ctrl, src.dyn);
    fprintf(fid, '- Declarations: `propulsion_power_compute_case.m` (frozen before the run)\n');
    fprintf(fid, '- Driver: `run_propulsion_power_compute_baseline.m` (one MATLAB invocation)\n');
    fprintf(fid, '- Artifacts: `%s`, `%s`, `%s`\n', md_p, mat_p, png_p);
    fprintf(fid, '- Seed %d (`rng(0,''twister'')` before every run) | controller dt = %.4g s | guidance dt = %.4g s\n', ...
        C.seed, lim.dt_controller, lim.dt_guidance);
    fprintf(fid, '- Frozen production values: `thrust_trim=%.6g N`, `Kp_x=%.6g`, `Kp_roll=%.6f`, ', ...
        lim.thrust_trim, lim.Kp_x, lim.Kp_roll);
    fprintf(fid, '`thrust in [%.4g, %.4g] N`, `delta_e_max=%.3f deg`, `delta_r_max=%.3f deg`, fin rate limit 40 deg/s\n\n', ...
        lim.thrust_min, lim.thrust_max, rad2deg(lim.de_max), rad2deg(lim.dr_max));

    fprintf(fid, '### Frozen-string checks (production not edited)\n\n');
    fprintf(fid, '| Check | Needle | Present |\n|---|---|:--:|\n');
    for i = 1:numel(frozen)
        fprintf(fid, '| %s | `%s` | %s |\n', frozen(i).name, frozen(i).needle, yn(frozen(i).ok));
    end
    fprintf(fid, '\n### Fingerprints (pre-run vs post-run)\n\n');
    fprintf(fid, '| File | Bytes | SHA-256 (pre) | Identical after run |\n|---|--:|---|:--:|\n');
    for i = 1:numel(FP_pre)
        fprintf(fid, '| `%s` | %d | `%s` | %s |\n', FP_pre(i).file, FP_pre(i).bytes, ...
            trunc(FP_pre(i).sha256, 64), yn(strcmp(FP_pre(i).sha256, FP_post(i).sha256)));
    end
    fprintf(fid, '\n- Fingerprint result: %s\n\n', fp_detail);

    fprintf(fid, '## Harness (documented deviation)\n\n');
    fprintf(fid, ['The actuator has to sit between `controller_law` and the plant, so every route is ', ...
        'run through one local fixed-step loop (`guidance_law` -> `controller_law` -> ASSUMED thruster ', ...
        '-> `ode45` on `underwater777_vehicle_dynamics`), which is the same loop shape already used for ', ...
        'the logged R10 route in `run_speed_envelope_audit.m`. No production file is called differently ', ...
        'and none is edited. Absolute tracking numbers on X / XZ can therefore differ slightly from ', ...
        'SPEED_ENVELOPE_AUDIT_001, which drives those two routes through `continuous_path_tracking`. ', ...
        'The steady window here is `t >= 5 s` and path progress `<= 90%%`.\n\n']);

    fprintf(fid, '## Predeclared ASSUMED thruster variants\n\n');
    fprintf(fid, '| Variant | Map gain [-] | Lag tau [s] | Slew [N/s] | Deadband [N] | Provenance | Note |\n');
    fprintf(fid, '|---|--:|--:|--:|--:|---|---|\n');
    for iv = 1:nV
        V = C.variants(iv);
        fprintf(fid, '| `%s` | %.2f | %.2f | %s | %.2f | %s | %s |\n', V.name, V.gain, V.tau_s, ...
            num2str(V.rate_max_Nps), V.deadband_N, V.provenance, V.note);
    end
    fprintf(fid, ['\nRealized thrust order of operations: map gain -> production magnitude clamp -> ', ...
        'command deadband -> slew limit -> first-order lag -> magnitude clamp. Fins keep the frozen ', ...
        'production magnitude and 40 deg/s rate limits inside `controller_law`; only the thrust ', ...
        'channel carries the ASSUMED realism.\n\n']);

    fprintf(fid, '## Ideal parity (identity proof)\n\n');
    fprintf(fid, ['The `ideal` variant has gain 1, no deadband, infinite slew and zero lag, so ', ...
        '`actuator_step` returns the production-clamped command through a structural identity branch ', ...
        'with no arithmetic. Empirically each case was run twice: once with the actuator bypassed ', ...
        'entirely and once through the identity actuator.\n\n']);
    fprintf(fid, '| Case | max abs trajectory difference | Bitwise exact |\n|---|--:|:--:|\n');
    for i = 1:numel(parity)
        fprintf(fid, '| %s | %.3g | %s |\n', parity(i).case, parity(i).max_abs_diff, yn(parity(i).exact));
    end
    fprintf(fid, '\n- Replay: %s / ideal re-run, max abs difference %.3g (%s)\n\n', ...
        replay.case, replay.max_abs_diff, replay.worst_channel);

    fprintf(fid, '## Tracking results (frozen hard gates)\n\n');
    fprintf(fid, ['Thresholds are the SPEED_ENVELOPE_AUDIT_001 absolute set, verbatim. The frozen ', ...
        'gate set contains **no speed-error gate**, so speed error is reported but not gated; ', ...
        'thrust saturation is the gated measure of speed authority.\n\n']);
    fprintf(fid, '| Case | Variant | pitch MAE | pitch p95 | gamma MAE | yaw MAE | CTE [m] | u MAE | u bias | elev sat%% | thr sat%% | gates | first limit |\n');
    fprintf(fid, '|---|---|--:|--:|--:|--:|--:|--:|--:|--:|--:|:--:|---|\n');
    for ic = 1:nC
        for iv = 1:nV
            M = Run(ic,iv).M; s = G.score(ic,iv);
            fprintf(fid, '| %s | `%s` | %.4f | %.4f | %.4f | %.4f | %.4f | %.4f | %+.4f | %.2f | %.2f | %s | %s |\n', ...
                Cases(ic).label, vn{iv}, nz(M.theta.mae_deg), nz(M.theta.p95_deg), nz(M.gamma.mae_deg), ...
                nz(M.yaw.mae_deg), nz(M.path.mean_cte), nz(M.speed.mae), nz(M.speed.signed_mean), ...
                nz(M.act.de_sat_pct), nz(M.thrust.sat_pct), pf(s.pass), s.first_limit);
        end
    end

    fprintf(fid, '\n## Thrust channel\n\n');
    fprintf(fid, '| Case | Variant | mean T [N] | peak abs T [N] | cmd-track RMSE [N] | peak dT/dt [N/s] | slew limit | sat%% (hold) | margin to T_max |\n');
    fprintf(fid, '|---|---|--:|--:|--:|--:|--:|--:|--:|\n');
    for ic = 1:nC
        for iv = 1:nV
            M = Run(ic,iv).M;
            fprintf(fid, '| %s | `%s` | %.4f | %.4f | %.4f | %.3f | %s | %.2f | %.4f |\n', ...
                Cases(ic).label, vn{iv}, nz(M.thrust.mean), nz(M.thrust.peak_abs), ...
                nz(M.thrust.track_rmse), nz(M.thrust.rate_peak), num2str(C.variants(iv).rate_max_Nps), ...
                nz(M.thrust.sat_pct), nz(M.thrust.margin_to_max));
        end
    end

    fprintf(fid, '\n## Propulsion / power / energy budget\n\n');
    fprintf(fid, '### Component-neutral model (ASSUMED / TO_BE_IDENTIFIED ranges)\n\n');
    E = C.energy;
    fprintf(fid, '| Quantity | Range | Status |\n|---|---|---|\n');
    fprintf(fid, '| seawater density | %.0f kg/m^3 | ASSUMED fixed |\n', E.rho_kgm3);
    fprintf(fid, '| propulsor disk diameter | %.3g – %.3g m | TO_BE_IDENTIFIED |\n', E.disk_D_m(1), E.disk_D_m(2));
    fprintf(fid, '| propeller efficiency | %.2f – %.2f | TO_BE_IDENTIFIED |\n', E.eta_prop(1), E.eta_prop(2));
    fprintf(fid, '| motor efficiency | %.2f – %.2f | TO_BE_IDENTIFIED |\n', E.eta_motor(1), E.eta_motor(2));
    fprintf(fid, '| drive/ESC efficiency | %.2f – %.2f | TO_BE_IDENTIFIED |\n', E.eta_esc(1), E.eta_esc(2));
    fprintf(fid, '| avionics + compute hotel load | %.0f – %.0f W | TO_BE_IDENTIFIED |\n', E.P_avionics_W(1), E.P_avionics_W(2));
    fprintf(fid, '| fin servo hold / slew | %.1f – %.1f W / %.1f – %.1f W | TO_BE_IDENTIFIED |\n', ...
        E.P_fin_hold_W(1), E.P_fin_hold_W(2), E.P_fin_move_W(1), E.P_fin_move_W(2));
    fprintf(fid, '| usable battery energy | %.0f – %.0f Wh | TO_BE_IDENTIFIED |\n', E.batt_usable_Wh(1), E.batt_usable_Wh(2));
    fprintf(fid, '| DC bus window | %.1f – %.1f V | TO_BE_IDENTIFIED |\n', E.V_bus_V(1), E.V_bus_V(2));
    fprintf(fid, '| continuous bus current limit | %.0f – %.0f A | TO_BE_IDENTIFIED |\n', E.I_cont_max_A(1), E.I_cont_max_A(2));
    fprintf(fid, '| reference mission distance | %.2f km | ASSUMED scaling basis |\n\n', E.mission_km);
    fprintf(fid, '%s\n\n', E.note);
    fprintf(fid, 'Hardware corners evaluated (worst / nominal / best):\n\n');
    fprintf(fid, '| Corner | disk area [m^2] | eta chain | avionics [W] | V bus [V] | usable [Wh] | I cont [A] |\n');
    fprintf(fid, '|---|--:|--:|--:|--:|--:|--:|\n');
    for i = 1:numel(Kcor)
        K = Kcor(i);
        fprintf(fid, '| %s | %.5f | %.4f | %.1f | %.1f | %.0f | %.0f |\n', K.name, K.A_disk, ...
            K.eta_tot, K.P_avi, K.V_bus, K.batt_Wh, K.I_cont);
    end

    fprintf(fid, '\n### Budget per case (worst corner unless stated)\n\n');
    fprintf(fid, '| Case | Variant | hydro ideal [W] | bus mean [W] | bus peak [W] | Wh/km worst | Wh/km best | mission Wh | I peak [A] | energy margin | current margin | endurance [km] |\n');
    fprintf(fid, '|---|---|--:|--:|--:|--:|--:|--:|--:|--:|--:|--:|\n');
    for ic = 1:nC
        for iv = 1:nV
            e = Run(ic,iv).En.worst; b = Run(ic,iv).En.best;
            fprintf(fid, '| %s | `%s` | %.2f | %.2f | %.2f | %.2f | %.2f | %.2f | %.2f | %+.3f | %+.3f | %.1f |\n', ...
                Cases(ic).label, vn{iv}, e.P_hydro_mean, e.P_bus_mean, e.P_bus_peak, ...
                e.Wh_per_km, b.Wh_per_km, e.Wh_mission, e.I_peak, e.energy_margin, ...
                e.current_margin, e.endurance_km);
        end
    end
    fprintf(fid, '\n- Worst-corner energy margin across all runs: **%+.3f** | worst-corner current margin: **%+.3f**\n', ...
        G.worst_energy_margin, G.worst_current_margin);
    fprintf(fid, '- Margins are conditional on the ASSUMED ranges above and certify no hardware.\n\n');

    fprintf(fid, '## Fin duty\n\n');
    fprintf(fid, '| Case | Variant | moving duty %% | elevator duty %% | rudder duty %% | elev mag util %% | rud mag util %% |\n');
    fprintf(fid, '|---|---|--:|--:|--:|--:|--:|\n');
    for ic = 1:nC
        for iv = 1:nV
            f = Run(ic,iv).M.fin;
            fprintf(fid, '| %s | `%s` | %.2f | %.2f | %.2f | %.2f | %.2f |\n', Cases(ic).label, vn{iv}, ...
                f.moving_duty_pct, f.de_duty_pct, f.dr_duty_pct, f.de_mag_util_pct, f.dr_mag_util_pct);
        end
    end
    fprintf(fid, '\n"Moving" means fin rate above %.0f%% of the frozen 40 deg/s slew limit.\n\n', ...
        100 * C.energy.fin_move_frac);

    fprintf(fid, '## Compute evidence\n\n');
    fprintf(fid, '| Quantity | Value |\n|---|--:|\n');
    fprintf(fid, '| controller call rate | %.4g Hz |\n', Comp.controller_rate_Hz);
    fprintf(fid, '| guidance call rate | %.4g Hz (every %d control steps) |\n', Comp.guidance_rate_Hz, Comp.guidance_period_steps);
    fprintf(fid, '| runs executed | %d |\n', Comp.n_runs);
    fprintf(fid, '| guidance calls | %d |\n', Comp.guidance_calls);
    fprintf(fid, '| controller calls | %d |\n', Comp.controller_calls);
    fprintf(fid, '| integrator steps | %d |\n', Comp.integrator_steps);
    fprintf(fid, '| plant RHS evaluations | %d |\n', Comp.plant_rhs_evals);
    fprintf(fid, '| plant RHS per control step | %.2f |\n', Comp.rhs_per_control_step);
    fprintf(fid, '| host runtime per control step, mean | %.3f ms |\n', Comp.ms_per_step_mean);
    fprintf(fid, '| host runtime per control step, p95 (worst run) | %.3f ms |\n', Comp.ms_per_step_p95);
    fprintf(fid, '| host runtime per control step, max | %.3f ms |\n', Comp.ms_per_step_max);
    fprintf(fid, '| host duty vs control period, mean / max | %.4f / %.4f |\n', Comp.host_duty_mean, Comp.host_duty_max);
    fprintf(fid, '| total in-loop host time | %.1f s |\n\n', Comp.loop_total_s);
    fprintf(fid, '**%s**\n\n', Comp.disclaimer);
    fprintf(fid, ['Note that the host figure includes the `ode45` plant integration, which is simulation ', ...
        'overhead and would not exist on the target. It is reported as measured and is deliberately ', ...
        'not decomposed into a flight-software estimate.\n\n']);

    fprintf(fid, '## Pareto vector (ASSUMED variants)\n\n');
    fprintf(fid, '| Variant | %s | %s | %s | %s | %s | %s | non-dominated |\n', Par.objectives{:});
    fprintf(fid, '|---|--:|--:|--:|--:|--:|--:|:--:|\n');
    for iv = 1:nV
        fprintf(fid, '| `%s` | %.4f | %.3f | %.2f | %.2f | %.2f | %.3f | %s |\n', vn{iv}, ...
            Par.J(iv,1), Par.J(iv,2), Par.J(iv,3), Par.J(iv,4), Par.J(iv,5), Par.J(iv,6), ...
            yn(Par.nondominated(iv)));
    end
    fprintf(fid, '\n- Sense: %s (worst case over all cases for each variant).\n', Par.sense);
    fprintf(fid, '- Non-dominated set: **%s**\n', strjoin(Par.nondominated_names, ', '));
    fprintf(fid, '- The Pareto set ranks ASSUMED variants against each other only. It selects no hardware.\n\n');

    fprintf(fid, '## Gate ledger\n\n');
    fprintf(fid, '| Gate | Class | Result | Detail |\n|---|---|:--:|---|\n');
    ids = {'G1','G2','G3','G3C','G4','G5','G6','G7','G8'};
    for i = 1:numel(ids)
        g = G.(ids{i});
        fprintf(fid, '| %s %s | %s | %s | %s |\n', ids{i}, g.name, g.class, pf(g.pass), sanitize(g.detail));
    end
    fprintf(fid, '\nRule: any MANDATORY gate failing gives FAIL. All mandatory met with a CONDITIONAL gate failing gives PARTIAL, because conditional gates rest on ASSUMED hardware numbers. All gates met gives PASS.\n\n');

    fprintf(fid, '## Decision\n\n');
    fprintf(fid, '- Verdict: **%s**\n', core.verdict);
    fprintf(fid, '- Limiting gate(s): %s\n', L.limiting_gate);
    fprintf(fid, '- Limiting case: %s\n', L.limiting_case);
    fprintf(fid, '- Next structure: %s\n', L.next_structure);
    fprintf(fid, '- Next gate: `%s`\n', L.next_gate);
    fprintf(fid, '- No rerun, no retune, no promotion. Gate6B is unlocked only by a PASS.\n');
    fclose(fid);
end

function Out = build_out(task_id, C, Cases, Run, Byp, lim, G, Par, Comp, core, L, ...
        parity, replay, FP_pre, FP_post, frozen, src, Kcor, md_p, mat_p, png_p)
    Out = struct();
    Out.task_id = task_id;
    Out.gate = C.gate;
    Out.promotion = C.promotion;
    Out.certification = C.certification;
    Out.gate4_status = C.gate4_status;
    Out.hardware_status = C.hardware;
    Out.compute_scope = C.compute_scope;
    Cdecl = C;
    Cdecl.fn = 'function handles not persisted; see propulsion_power_compute_case.m';
    Out.case_declaration = Cdecl;
    Out.cases = Cases;
    Out.runs = Run;
    Out.bypass = Byp;
    Out.limits = lim;
    Out.gates = G;
    Out.pareto = Par;
    Out.compute = Comp;
    Out.verdict_core = core;
    Out.limiting = L;
    Out.parity = parity;
    Out.replay = replay;
    Out.fingerprints_pre = FP_pre;
    Out.fingerprints_post = FP_post;
    Out.frozen_strings = frozen;
    Out.sources = src;
    Out.energy_corners = Kcor;
    Out.paths = struct('md', md_p, 'mat', mat_p, 'png', png_p);
    Out.production_edited = false;
    Out.tuning_performed = false;
    Out.rerun_performed = false;
end

%% ===================== logs =====================
function append_logs(out_dir, task_id, final, G, Par, L, Comp, Run, Cases, C, md_p, mat_p, png_p)
    entries = { ...
        'AUV_REALIZATION_READINESS_PLAN.md', 'readiness'; ...
        'AUV_REALISM_AND_VISUAL_VALIDATION.md', 'realism'; ...
        'PITCH_CONTROL_RESEARCH_LOG.md', 'research'};
    % worst-corner roll-up used in every log entry
    whmax = 0; ipmax = 0; tpk = 0; fdmax = 0;
    for ic = 1:numel(Cases)
        for iv = 1:numel(C.variants)
            e = Run(ic,iv).En.worst;
            whmax = max(whmax, e.Wh_per_km); ipmax = max(ipmax, e.I_peak);
            tpk = max(tpk, Run(ic,iv).M.thrust.peak_abs);
            fdmax = max(fdmax, Run(ic,iv).M.fin.moving_duty_pct);
        end
    end
    for i = 1:size(entries, 1)
        fp = fullfile(out_dir, entries{i,1});
        if exist(fp, 'file') ~= 2
            fprintf('log skipped (missing): %s\n', fp);
            continue;
        end
        txt = fileread(fp);
        if contains(txt, task_id)
            fprintf('log already contains %s, not appended twice: %s\n', task_id, fp);
            continue;
        end
        fid = fopen(fp, 'a');
        fprintf(fid, '\n## %s — %s (%s log)\n\n', task_id, datestr(now, 31), entries{i,2});
        fprintf(fid, '- Verdict: **%s**. Gate6 isolated propulsion/power/compute budget, **no promotion**.\n', final.verdict);
        fprintf(fid, '- Status: SIMULATION_ONLY / NOT_CERTIFIED; Gate4 evidence shadow-only; production untouched (fingerprints byte-identical pre/post).\n');
        fprintf(fid, '- Ideal parity across %d cases: %s (G1 %s). Deterministic replay: %s (G6 %s).\n', ...
            numel(Cases), tern(G.G1.pass, 'bitwise exact', 'NOT exact'), pf(G.G1.pass), ...
            tern(G.G6.pass, 'bitwise identical', 'NOT identical'), pf(G.G6.pass));
        fprintf(fid, '- Grid: X/XZ at U={1,1.5,2} m/s, R10 at U={1.5,2} m/s; ASSUMED thruster variants ideal / nominal lag-map / slow+low-authority / high-authority; no tuning.\n');
        fprintf(fid, '- Worst-corner budget: <= %.2f Wh/km, peak bus current <= %.2f A, peak realized thrust %.3f N, fin moving duty <= %.1f%%.\n', ...
            whmax, ipmax, tpk, fdmax);
        fprintf(fid, '- Energy margin %+.3f and current margin %+.3f at the pessimistic ASSUMED corner (hardware TO_BE_IDENTIFIED; ranges only, no vendor).\n', ...
            G.worst_energy_margin, G.worst_current_margin);
        fprintf(fid, '- Compute: controller %.4g Hz, guidance %.4g Hz, %d controller calls, %d plant RHS evaluations, %.3f ms/step host mean (NOT WCET).\n', ...
            Comp.controller_rate_Hz, Comp.guidance_rate_Hz, Comp.controller_calls, ...
            Comp.plant_rhs_evals, Comp.ms_per_step_mean);
        fprintf(fid, '- Pareto non-dominated ASSUMED variants: %s.\n', strjoin(Par.nondominated_names, ', '));
        fprintf(fid, '- Limiting gate(s): %s | limiting case: %s\n', L.limiting_gate, L.limiting_case);
        fprintf(fid, '- Next: %s — %s\n', L.next_gate, L.next_structure);
        fprintf(fid, '- Artifacts: `%s`, `%s`, `%s`; driver `run_propulsion_power_compute_baseline.m`, declarations `propulsion_power_compute_case.m`.\n', ...
            md_p, mat_p, png_p);
        fprintf(fid, '- CODEX_VERTICAL_PLAN untouched.\n');
        fclose(fid);
        fprintf('appended %s log: %s\n', entries{i,2}, fp);
    end
end

%% ===================== small utils =====================
function y = wrap_pi(x)
    y = atan2(sin(x), cos(x));
end

function v = mean_safe(x, mask)
    x = x(:); mask = mask(:);
    if ~any(mask); v = NaN; return; end
    v = mean(x(mask));
end

function v = max_safe(x, mask)
    x = x(:); mask = mask(:);
    if ~any(mask); v = NaN; return; end
    v = max(x(mask));
end

function v = rms_safe(x)
    x = x(:); x = x(isfinite(x));
    if isempty(x); v = NaN; return; end
    v = sqrt(mean(x.^2));
end

function v = pct_local(x, p)
    x = sort(x(:));
    if isempty(x); v = NaN; return; end
    k = max(1, min(numel(x), round(p / 100 * numel(x))));
    v = x(k);
end

function v = pct_masked(x, mask, p)
    x = x(:); mask = mask(:);
    if ~any(mask); v = NaN; return; end
    v = pct_local(x(mask), p);
end

function p = sat_pct(u, mask, lim)
    if ~any(mask); p = NaN; return; end
    p = 100 * mean(abs(u(mask)) >= lim);
end

function v = nz(x)
    if isempty(x) || ~isscalar(x); v = NaN; else; v = x; end
    if ~isfinite(v); v = NaN; end
end

function v = nz0(x)
    v = nz(x);
    if isnan(v); v = 0; end
end

function s = yn(tf)
    if tf; s = 'YES'; else; s = 'NO'; end
end

function s = pf(tf)
    if tf; s = 'PASS'; else; s = 'FAIL'; end
end

function s = tern(tf, a, b)
    if tf; s = a; else; s = b; end
end

function v = tern_num(tf, a, b)
    if tf; v = a; else; v = b; end
end

function s = trunc(s, n)
    s = char(s);
    if numel(s) > n; s = [s(1:max(1,n-3)) '...']; end
end

function s = sanitize(s)
    if isempty(s); s = ''; return; end
    s = regexprep(char(s), '[|]', '/');
    s = regexprep(s, '\s+', ' ');
    if numel(s) > 220; s = [s(1:217) '...']; end
end
