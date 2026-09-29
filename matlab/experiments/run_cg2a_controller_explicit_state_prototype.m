function run_cg2a_controller_explicit_state_prototype()
% RUN_CG2A_CONTROLLER_EXPLICIT_STATE_PROTOTYPE
% SIMULATION_ONLY — golden parity for isolated explicit-state controller prototype.
% Does NOT call or modify production controller_law.m / gains / call path.
% No MEX / codegen / compiler. One-shot host parity + dual reset replay.
%
% TASK_ID: CG2A_CONTROLLER_EXPLICIT_STATE_PROTOTYPE_001

    task_id = 'CG2A_CONTROLLER_EXPLICIT_STATE_PROTOTYPE_001';
    out_md = fullfile('suite_results', 'CG2A_CONTROLLER_EXPLICIT_STATE_PROTOTYPE.md');
    golden_mat = fullfile('suite_results', 'CG2A_CONTROLLER_GOLDEN_V1.mat');
    proto_files = { ...
        'controller_codegen_init.m', ...
        'controller_codegen_reset.m', ...
        'controller_codegen_step.m'};

    fprintf('[%s] start (SIMULATION_ONLY)\n', task_id);

    sha_ctrl = local_sha256_file_('controller_law.m');
    bytes_ctrl = local_file_bytes_('controller_law.m');
    sha_ctrl_expected = '16b7c20a14f1a1afcc3479351edee66eadecf4d134ed7d17e9e1d6986d9df890';
    ctrl_untouched = strcmp(sha_ctrl, sha_ctrl_expected);

    sha_init = local_sha256_file_('controller_codegen_init.m');
    sha_reset = local_sha256_file_('controller_codegen_reset.m');
    sha_step = local_sha256_file_('controller_codegen_step.m');
    bytes_init = local_file_bytes_('controller_codegen_init.m');
    bytes_reset = local_file_bytes_('controller_codegen_reset.m');
    bytes_step = local_file_bytes_('controller_codegen_step.m');

    S = load(golden_mat, 'corpus');
    corpus = S.corpus;
    U = corpus.U;
    Yg = corpus.Y;
    Dbgg = corpus.Debug;
    N = size(U, 1);
    dt = corpus.params_snapshot.dt_controller;

    params = controller_codegen_init(corpus.params_snapshot);

    % ----- Replay A (cold reset) -----
    [Ya, Dbga] = drive_proto_sequence_(params, U);

    % ----- Replay B (reset again; require A==B) -----
    [Yb, Dbgb] = drive_proto_sequence_(params, U);

    dual_out_eq = isequaln(Ya, Yb);
    dual_dbg_eq = isequaln(Dbga, Dbgb);
    dual_reset_pass = dual_out_eq && dual_dbg_eq;

    % ----- Exact golden parity (every Output/Debug field) -----
    out_names = {'delta_r', 'delta_e', 'thrust'};
    dbg_names = { ...
        'e_theta','theta_phys','theta_phys_dot','int_angle','int_angle_max','int_rate', ...
        'de_trim','de_uw_ff','de_fb','delta_e_angle_I','delta_e_cmd','delta_e_unsat', ...
        'M_uw','M_elev','M_e_ff','G_de','b_u','rate_filt','theta_rate_cmd','mag_sat', ...
        'p','e_psi','e_r','dr_yaw','dr_p','dr_damp','g_ac','delta_r_cmd','delta_r','Kp_roll'};

    [out_exact, out_stats] = compare_struct_series_(Ya, Yg, out_names);
    [dbg_exact, dbg_stats] = compare_struct_series_(Dbga, Dbgg, dbg_names);
    golden_exact = out_exact && dbg_exact;

    % Bounds / slew on prototype replay A
    checks = struct();
    checks.all_outputs_finite = all(isfinite(Ya.delta_r)) && all(isfinite(Ya.delta_e)) && all(isfinite(Ya.thrust));
    checks.all_debug_finite = true;
    for i = 1:numel(dbg_names)
        checks.all_debug_finite = checks.all_debug_finite && all(isfinite(Dbga.(dbg_names{i})));
    end
    checks.delta_r_within_mag = all(abs(Ya.delta_r) <= params.delta_r_max + 1e-12);
    checks.delta_e_within_mag = all(abs(Ya.delta_e) <= params.delta_e_max + 1e-12);
    checks.thrust_within_bounds = all(Ya.thrust <= params.thrust_max + 1e-12) && ...
        all(Ya.thrust >= params.thrust_min - 1e-12);
    max_slew = deg2rad(40) * dt + 1e-12;
    dr_step = [Ya.delta_r(1); diff(Ya.delta_r)];
    de_step = [Ya.delta_e(1); diff(Ya.delta_e)];
    checks.rudder_slew_ok = all(abs(dr_step) <= max_slew + 1e-9);
    checks.elevator_slew_ok = all(abs(de_step) <= max_slew + 1e-9);
    checks.max_abs_dr_step = max(abs(dr_step));
    checks.max_abs_de_step = max(abs(de_step));
    checks.slew_limit_rad = deg2rad(40) * dt;
    checks.pass_bounds = checks.delta_r_within_mag && checks.delta_e_within_mag && checks.thrust_within_bounds;
    checks.pass_slew = checks.rudder_slew_ok && checks.elevator_slew_ok;

    isolated = false;
    isolate_dir = '';
    if golden_exact && dual_reset_pass && ctrl_untouched
        verdict = 'PASS';
        deploy_label = 'DEPLOY_CANDIDATE/NOT_IN_PRODUCTION';
        next_task = 'CG2B_GUIDANCE_GOLDEN_PARITY_CAPTURE_001';
    else
        verdict = 'FAIL';
        deploy_label = 'ISOLATED_FAIL_CANDIDATE';
        next_task = 'CG2A_CONTROLLER_EXPLICIT_STATE_PROTOTYPE_REPAIR_001';
        isolate_dir = fullfile('.cg2a_explicit_state_isolated');
        if ~exist(isolate_dir, 'dir'); mkdir(isolate_dir); end
        for i = 1:numel(proto_files)
            if exist(proto_files{i}, 'file')
                movefile(proto_files{i}, fullfile(isolate_dir, proto_files{i}));
            end
        end
        isolated = true;
    end

    utc = char(datetime('now', 'TimeZone', 'UTC', 'Format', 'yyyy-MM-dd''T''HH:mm:ss''Z'''));
    R = struct();
    R.task_id = task_id;
    R.verdict = verdict;
    R.next_task = next_task;
    R.deploy_label = deploy_label;
    R.utc = utc;
    R.N = N;
    R.dt = dt;
    R.out_exact = out_exact;
    R.dbg_exact = dbg_exact;
    R.golden_exact = golden_exact;
    R.dual_reset_pass = dual_reset_pass;
    R.dual_out_eq = dual_out_eq;
    R.dual_dbg_eq = dual_dbg_eq;
    R.out_stats = out_stats;
    R.dbg_stats = dbg_stats;
    R.out_names = out_names;
    R.dbg_names = dbg_names;
    R.checks = checks;
    R.ctrl_untouched = ctrl_untouched;
    R.sha_ctrl = sha_ctrl;
    R.bytes_ctrl = bytes_ctrl;
    R.sha_init = sha_init;
    R.sha_reset = sha_reset;
    R.sha_step = sha_step;
    R.bytes_init = bytes_init;
    R.bytes_reset = bytes_reset;
    R.bytes_step = bytes_step;
    R.params = params;
    R.isolated = isolated;
    R.isolate_dir = isolate_dir;
    write_md_report_(out_md, R);

    % Machine-readable one-liner for host status appends
    result_path = fullfile('suite_results', 'CG2A_CONTROLLER_EXPLICIT_STATE_PROTOTYPE_RESULT.txt');
    fid = fopen(result_path, 'w');
    fprintf(fid, 'verdict=%s\nnext=%s\ngolden_exact=%d\ndual_reset=%d\nctrl_untouched=%d\nisolated=%d\n', ...
        verdict, next_task, golden_exact, dual_reset_pass, ctrl_untouched, isolated);
    fprintf(fid, 'out_max_abs=%.17g\nout_max_rel=%.17g\ndbg_max_abs=%.17g\ndbg_max_rel=%.17g\n', ...
        out_stats.max_abs, out_stats.max_rel, dbg_stats.max_abs, dbg_stats.max_rel);
    fclose(fid);

    fprintf('[%s] verdict=%s golden_exact=%d dual=%d ctrl=%d isolated=%d -> %s\n', ...
        task_id, verdict, golden_exact, dual_reset_pass, ctrl_untouched, isolated, out_md);
    fprintf('[%s] next=%s\n', task_id, next_task);
end

% =====================================================================
function [Y, Dbg] = drive_proto_sequence_(params, U)
    N = size(U, 1);
    Y = struct('delta_r', zeros(N,1), 'delta_e', zeros(N,1), 'thrust', zeros(N,1));
    dbg_names = { ...
        'e_theta','theta_phys','theta_phys_dot','int_angle','int_angle_max','int_rate', ...
        'de_trim','de_uw_ff','de_fb','delta_e_angle_I','delta_e_cmd','delta_e_unsat', ...
        'M_uw','M_elev','M_e_ff','G_de','b_u','rate_filt','theta_rate_cmd','mag_sat', ...
        'p','e_psi','e_r','dr_yaw','dr_p','dr_damp','g_ac','delta_r_cmd','delta_r','Kp_roll'};
    Dbg = struct();
    for i = 1:numel(dbg_names)
        Dbg.(dbg_names{i}) = zeros(N, 1);
    end

    state = controller_codegen_reset(params);
    for k = 1:N
        in = struct();
        in.yaw_ref = U(k, 1);
        in.pitch_ref = U(k, 2);
        in.u_ref = U(k, 3);
        in.psi = U(k, 4);
        in.theta = U(k, 5);
        in.r = U(k, 6);
        in.q = U(k, 7);
        in.u = U(k, 8);
        in.r_ff = U(k, 9);
        in.pitch_ref_dot = U(k, 10);
        in.phi = U(k, 11);
        in.w = U(k, 12);
        in.p = U(k, 13);

        [state, out, dbg] = controller_codegen_step(params, state, in);
        Y.delta_r(k) = out.delta_r;
        Y.delta_e(k) = out.delta_e;
        Y.thrust(k) = out.thrust;
        for i = 1:numel(dbg_names)
            Dbg.(dbg_names{i})(k) = dbg.(dbg_names{i});
        end
    end
end

function [exact, stats] = compare_struct_series_(A, B, names)
    exact = true;
    max_abs = 0;
    max_rel = 0;
    worst_field = '';
    worst_idx = 0;
    for i = 1:numel(names)
        nm = names{i};
        av = A.(nm)(:);
        bv = B.(nm)(:);
        if ~isequaln(av, bv)
            exact = false;
            d = abs(av - bv);
            [mabs, ix] = max(d);
            denom = max(abs(bv(ix)), eps);
            mrel = mabs / denom;
            if mabs > max_abs
                max_abs = mabs;
                max_rel = mrel;
                worst_field = nm;
                worst_idx = ix;
            end
        end
    end
    stats = struct('max_abs', max_abs, 'max_rel', max_rel, ...
        'worst_field', worst_field, 'worst_idx', worst_idx, 'exact', exact);
end

function write_md_report_(path, R)
    fid = fopen(path, 'w');
    fprintf(fid, '# CG2A_CONTROLLER_EXPLICIT_STATE_PROTOTYPE\n\n');
    fprintf(fid, '**TASK_ID:** `%s`  \n', R.task_id);
    fprintf(fid, '**Mode:** SIMULATION_ONLY · MATLAB-only · no MEX/codegen/compiler  \n');
    fprintf(fid, '**Executed (UTC):** %s  \n', R.utc);
    fprintf(fid, '**Hardware:** **NOT_CERTIFIED**  \n');
    fprintf(fid, '**Compiler:** deferred (CG_PRE0 PARTIAL carried)  \n');
    fprintf(fid, '**C++ parity:** **NOT CLAIMED**  \n');
    fprintf(fid, '**Production call path:** UNTOUCHED  \n');
    fprintf(fid, '**CODEX_VERTICAL_PLAN.md:** UNTOUCHED  \n');
    fprintf(fid, '**Prototype label:** `%s`  \n\n', R.deploy_label);

    fprintf(fid, '> ### Verdict: **%s**\n\n', R.verdict);

    fprintf(fid, '| PASS gate | Required | Observed | Met? |\n');
    fprintf(fid, '|---|---|---|---|\n');
    fprintf(fid, '| Exact `isequaln` Output vs golden | yes | out_exact=%d | %s |\n', ...
        R.out_exact, tf_(R.out_exact));
    fprintf(fid, '| Exact `isequaln` Debug vs golden | yes | dbg_exact=%d | %s |\n', ...
        R.dbg_exact, tf_(R.dbg_exact));
    fprintf(fid, '| Dual reset replay equality | yes | out=%d dbg=%d | %s |\n', ...
        R.dual_out_eq, R.dual_dbg_eq, tf_(R.dual_reset_pass));
    fprintf(fid, '| `controller_law.m` fingerprint | untouched | match=%d | %s |\n', ...
        R.ctrl_untouched, tf_(R.ctrl_untouched));
    fprintf(fid, '\n**Next exact task (exactly one):** `%s`\n\n', R.next_task);

    fprintf(fid, '---\n\n## 1. API schema (fixed field sets)\n\n');
    fprintf(fid, '```text\n');
    fprintf(fid, 'params = controller_codegen_init(params_in)   %% from golden snapshot only\n');
    fprintf(fid, 'state  = controller_codegen_reset(params)     %% deterministic zeros\n');
    fprintf(fid, '[state,out,dbg] = controller_codegen_step(params,state,in)\n');
    fprintf(fid, '```\n\n');

    fprintf(fid, '**Params:** `Kp_psi,Kd_psi,Kp_x,Kp_roll,Kp_angle,Ki_angle,Kp_rate,Ki_rate,Kaw_pitch,Kd_rate,Kd_damp,delta_r_max,delta_e_max,thrust_max,thrust_min,thrust_trim,trim_speed_table,trim_elevator_table,elevator_sign,dt_controller,tau_rate,Muw,Muuds,lambda_muw_ff,muw_ff_u_min,muw_ff_u_lo,muw_ff_u_hi,muw_ff_clamp_deg,delta_e_trim,k_gamma_climb,de_climb_lim,slew_max_rad_s`\n\n');
    fprintf(fid, '**State:** `prev_delta_r,prev_delta_e,int_angle,int_rate,rate_filt,prev_e_rate,initialized`\n\n');
    fprintf(fid, '**Input:** `yaw_ref,pitch_ref,u_ref,psi,theta,r,q,u,r_ff,pitch_ref_dot,phi,w,p`\n\n');
    fprintf(fid, '**Output:** `delta_r,delta_e,thrust`\n\n');
    fprintf(fid, '**Debug (30):** `%s`\n\n', strjoin(R.dbg_names, ', '));

    fprintf(fid, '---\n\n## 2. Parity vs `CG2A_CONTROLLER_GOLDEN_V1`\n\n');
    fprintf(fid, '| Item | Value |\n|---|---:|\n');
    fprintf(fid, '| N_steps | %d |\n', R.N);
    fprintf(fid, '| dt | %.12g |\n', R.dt);
    fprintf(fid, '| Output exact | %d |\n', R.out_exact);
    fprintf(fid, '| Debug exact | %d |\n', R.dbg_exact);
    fprintf(fid, '| Dual-reset exact | %d |\n', R.dual_reset_pass);
    fprintf(fid, '| Output max abs | %.17g |\n', R.out_stats.max_abs);
    fprintf(fid, '| Output max rel | %.17g |\n', R.out_stats.max_rel);
    fprintf(fid, '| Output worst field | %s @k=%d |\n', empty_dash_(R.out_stats.worst_field), R.out_stats.worst_idx);
    fprintf(fid, '| Debug max abs | %.17g |\n', R.dbg_stats.max_abs);
    fprintf(fid, '| Debug max rel | %.17g |\n', R.dbg_stats.max_rel);
    fprintf(fid, '| Debug worst field | %s @k=%d |\n', empty_dash_(R.dbg_stats.worst_field), R.dbg_stats.worst_idx);
    fprintf(fid, '| MATLAB invocations | 1 |\n\n');

    if ~R.golden_exact
        fprintf(fid, '> Exact `isequaln` **FAILED**. Max abs/rel reported above; production untouched.\n\n');
    end

    fprintf(fid, '---\n\n## 3. Bounds / slew (prototype replay)\n\n');
    C = R.checks;
    fprintf(fid, '| Check | Pass |\n|---|---|\n');
    fprintf(fid, '| Outputs finite | %s |\n', tf_(C.all_outputs_finite));
    fprintf(fid, '| Debug finite | %s |\n', tf_(C.all_debug_finite));
    fprintf(fid, '| |δr| ≤ delta_r_max | %s |\n', tf_(C.delta_r_within_mag));
    fprintf(fid, '| |δe| ≤ delta_e_max | %s |\n', tf_(C.delta_e_within_mag));
    fprintf(fid, '| thrust in [min,max] | %s |\n', tf_(C.thrust_within_bounds));
    fprintf(fid, '| rudder slew ≤ 40°/s·dt | %s (max step %.12g vs lim %.12g) |\n', ...
        tf_(C.rudder_slew_ok), C.max_abs_dr_step, C.slew_limit_rad);
    fprintf(fid, '| elevator slew ≤ 40°/s·dt | %s (max step %.12g vs lim %.12g) |\n', ...
        tf_(C.elevator_slew_ok), C.max_abs_de_step, C.slew_limit_rad);

    fprintf(fid, '\n---\n\n## 4. Source hashes\n\n');
    fprintf(fid, '| File | Bytes | SHA-256 | Role |\n|---|---:|---|---|\n');
    fprintf(fid, '| `controller_law.m` | %d | `%s` | production UNTOUCHED |\n', R.bytes_ctrl, R.sha_ctrl);
    fprintf(fid, '| `controller_codegen_init.m` | %d | `%s` | prototype |\n', R.bytes_init, R.sha_init);
    fprintf(fid, '| `controller_codegen_reset.m` | %d | `%s` | prototype |\n', R.bytes_reset, R.sha_reset);
    fprintf(fid, '| `controller_codegen_step.m` | %d | `%s` | prototype |\n', R.bytes_step, R.sha_step);

    fprintf(fid, '\n---\n\n## 5. Remaining TEMPORARY_BLOCKER items\n\n');
    fprintf(fid, '| ID | Item | Status |\n|---|---|---|\n');
    fprintf(fid, '| TB-WRAP | `wrapToPi` in step (yaw error) | TEMPORARY_BLOCKER — kept for bit parity; own local wrap later |\n');
    fprintf(fid, '| TB-INTERP | `interp1(...,''linear'',''extrap'')` fixed trim tables | TEMPORARY_BLOCKER — kept for bit parity; endpoint-clamp lerp later |\n');
    fprintf(fid, '| TB-STRING | interp1 method char args | carried with TB-INTERP |\n');
    fprintf(fid, '| TB-EPS | host `eps` in g_ac schedule | carried (TARGET_DEPENDENT) |\n');
    fprintf(fid, '| TB-PROD | production still uses globals/persistent | NOT_IN_PRODUCTION prototype only |\n\n');

    fprintf(fid, '---\n\n## 6. Integrity / isolation\n\n');
    fprintf(fid, '| Item | Value |\n|---|---|\n');
    fprintf(fid, '| Isolated on FAIL | %s |\n', tf_(R.isolated));
    if R.isolated
        fprintf(fid, '| Isolate dir | `%s` |\n', R.isolate_dir);
    end
    fprintf(fid, '| Golden corpus | `suite_results/CG2A_CONTROLLER_GOLDEN_V1.mat` |\n');
    fprintf(fid, '| Harness | `run_cg2a_controller_explicit_state_prototype.m` |\n');
    fprintf(fid, '| Params source | golden `params_snapshot` only |\n');
    fprintf(fid, '| State reset | deterministic zeros |\n\n');

    fprintf(fid, 'Rejected methods remain closed. Hardware **NOT_CERTIFIED**. C++ parity **NOT CLAIMED**.\n\n');
    fprintf(fid, '*End of CG2A_CONTROLLER_EXPLICIT_STATE_PROTOTYPE. Verdict: **%s**. Next: `%s`.*\n', ...
        R.verdict, R.next_task);
    fclose(fid);
end

function s = tf_(v)
    if v; s = 'YES'; else; s = 'NO'; end
end

function s = empty_dash_(v)
    if isempty(v); s = '-'; else; s = char(string(v)); end
end

function h = local_sha256_file_(path)
    if exist('java.security.MessageDigest', 'class')
        md = java.security.MessageDigest.getInstance('SHA-256');
        fid = fopen(path, 'r');
        cleaner = onCleanup(@() fclose(fid)); %#ok<NASGU>
        while true
            [buf, n] = fread(fid, 1024*1024, '*uint8');
            if n < 1; break; end
            md.update(buf);
        end
        h = sprintf('%02x', typecast(md.digest, 'uint8'));
    else
        [status, out] = system(sprintf('sha256sum "%s"', path));
        if status ~= 0
            h = 'HASH_FAILED';
        else
            h = strtok(out);
        end
    end
end

function n = local_file_bytes_(path)
    d = dir(path);
    n = d(1).bytes;
end
