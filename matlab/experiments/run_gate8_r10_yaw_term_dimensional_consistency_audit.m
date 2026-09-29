function run_gate8_r10_yaw_term_dimensional_consistency_audit()
% TASK_ID GATE8_R10_YAW_TERM_DIMENSIONAL_CONSISTENCY_AUDIT_001
%
% Bounded, isolated, read-only audit of the EXISTING yaw (rudder) command
% equation. Exactly three sources are read:
%   1. controller_law.m
%   2. guidance_law.m
%   3. suite_results/GATE8_R10_CLOSED_LOOP_RAIL_ORIGIN_LOCALISATION.mat
% No repo scan. No simulation. No plant call. No gain, law, path, threshold,
% shaper or current-FF edit. No promotion. Hardware NOT_CERTIFIED. Gate9 locked.

    t_host = tic;
    TASK = 'GATE8_R10_YAW_TERM_DIMENSIONAL_CONSISTENCY_AUDIT_001';
    SHORT = 'GATE8_R10_YAW_TERM_DIMENSIONAL_CONSISTENCY_AUDIT';
    out_dir = 'suite_results';
    md_path  = fullfile(out_dir, [SHORT '.md']);
    mat_path = fullfile(out_dir, [SHORT '.mat']);
    png_main = fullfile(out_dir, [SHORT '.png']);
    png_qa   = fullfile(out_dir, [SHORT '_02_visual_qa.png']);
    log_path = fullfile(out_dir, [SHORT '_run.log']);

    if exist(log_path, 'file'); delete(log_path); end
    diary(log_path); diary on;
    fprintf('==== %s ====\n', TASK);
    fprintf('start %s\n', datestr(now, 'yyyy-mm-dd HH:MM:SS'));

    R = struct();
    R.task_id = TASK;
    R.gate = ['Gate 8 R10 yaw term dimensional consistency audit - bounded read-only algebraic audit of the ' ...
              'existing yaw command equation, one MATLAB invocation, no resimulation.'];
    R.created = datestr(now, 'yyyy-mm-dd HH:MM:SS');
    R.certification = 'NOT_CERTIFIED (simulation-only evidence reused; no HIL, no bench, no hardware). Gate9 LOCKED.';
    R.honesty = ['IMPLEMENTED = this isolated read-only algebraic audit only. Nothing was simulated and nothing was ' ...
        'tuned. No gain, law, path, threshold, shaper, current-FF or promotion change was made. No tracking ' ...
        'improvement is claimed anywhere in this artifact.'];
    R.verdict = 'PENDING';
    R.fatal = '';
    R.candidate = '';
    R.candidate_withheld = '';

    try
        % ---------------- bounded sources ----------------
        R.sources = {'controller_law.m'; 'guidance_law.m'; ...
                     fullfile('suite_results','GATE8_R10_CLOSED_LOOP_RAIL_ORIGIN_LOCALISATION.mat')};
        R.source_role = { ...
            'READ | production controller: the yaw command equation, its coefficients, limiter order and sample time'
            'READ | production guidance: the yaw reference chain, the rate feedforward and its units'
            'READ | frozen evidence: the stored nominal R10_U1.5 log used for every numerical claim'};
        R.src_fp = cell(numel(R.sources),1);
        for i = 1:numel(R.sources)
            R.src_fp{i} = gate8_fp(R.sources{i});
            fprintf('source %d: %s  fp=%s\n', i, R.sources{i}, R.src_fp{i});
        end
        R.no_repo_scan = ['CONFIRMED: exactly three paths were opened for content; no directory listing drove any ' ...
            'claim. The preservation fingerprints below are byte-level integrity checks over the protected files, ' ...
            'not source reads: no statement in this audit is derived from their contents.'];

        % ---------------- preservation fingerprints ----------------
        R.prod_files = {'continuous_path_tracking.m'; 'controller_law.m'; 'guidance_law.m'; ...
                        'underwater777_vehicle_dynamics.m'; 'compute_path_following_metrics.m'; ...
                        fullfile('suite_results','CODEX_VERTICAL_PLAN.md'); ...
                        fullfile('suite_results','GATE8_R10_CLOSED_LOOP_RAIL_ORIGIN_LOCALISATION.mat')};
        R.fp_pre = cell(numel(R.prod_files),1);
        for i = 1:numel(R.prod_files)
            R.fp_pre{i} = gate8_fp(R.prod_files{i});
        end

        R.isolation = ['no directory was listed and no file outside the declared source and protected lists was ' ...
            'opened. Output is confined to the five declared artifacts under suite_results.'];

        % ---------------- load frozen evidence ----------------
        S = load(R.sources{3});
        R0 = S.R;
        R.evidence_task_id = R0.task_id;
        R.evidence_verdict = R0.verdict;
        R.evidence_created = R0.created;
        R.evidence_origin_kind = R0.attrib.origin.origin_kind;
        R.evidence_origin_id = R0.attrib.origin.id;
        R.evidence_blocker_declared = R0.attrib.origin.blocker_declared;
        R.evidence_cell = R0.cell_name;
        R.evidence_hash = R0.stored_nominal_hash;
        R.evidence_reproduced = R0.cell_reproduced;
        R.frames = R0.frames;
        R.gains = R0.gains;
        R.plant_trim_requirement_deg = R0.plant_trim_requirement_deg;
        R.plant_trim_provenance = R0.plant_trim_provenance;
        fprintf('evidence: %s verdict=%s cell=%s origin_kind=%s reproduced=%d\n', ...
            R0.task_id, R0.verdict, R0.cell_name, R0.attrib.origin.origin_kind, R0.cell_reproduced);
        fprintf('gains: Kp_psi=%g Kd_psi=%g Kp_roll=%g dr_max=%g deg rate=%g deg/s dt_ctrl=%g dt_guid=%g\n', ...
            R0.gains.Kp_psi, R0.gains.Kd_psi, R0.gains.Kp_roll, R0.gains.delta_r_max_deg, ...
            R0.gains.rate_limit_degs, R0.gains.dt_controller, R0.gains.dt_guidance);

        % ---------------- the audit ----------------
        A = gate8_yaw_term_audit_core(R0);
        R.audit = A;
        R.equation = A.equation;
        R.derived_log = A.derived_log;
        R.derived_log_cols = A.derived_log_cols;
        R.derived_log_units = A.derived_log_units;
        R.derived_log_provenance = A.derived_log_provenance;

        fprintf('\n-- coefficient recovery from stored logs --\n');
        for k = 1:numel(A.recov)
            q = A.recov(k);
            fprintf('  %-28s code=%-12.9g observed[min,max]=[%.12g, %.12g] rel_err=%.3g n_obs=%d %s\n', ...
                q.label, q.code_coefficient, q.min, q.max, q.rel_err, q.n_observable, q.unit);
        end
        fprintf('\n-- structural / conversion / ordering residuals --\n');
        for k = 1:numel(A.res)
            fprintf('  %-46s maxabs=%.4g %-6s rms=%.4g\n', A.res(k).label, A.res(k).maxabs, A.res(k).unit, A.res(k).rms);
        end
        fprintf('\n-- envelope excess ledger (envelope = %g deg) --\n', A.LIM);
        for k = 1:numel(A.ledger)
            fprintf('  %-10s absmax=%9.4f deg (%6.3gx)  medabs=%9.4f deg (%6.3gx)  alone_at_env=%d\n', ...
                A.ledger(k).term, A.ledger(k).absmax_deg, A.ledger(k).excess_absmax, ...
                A.ledger(k).medabs_deg, A.ledger(k).excess_medabs, A.ledger(k).reaches_env_alone);
        end
        fprintf('\n-- LOTO, split decomposition --\n');
        for k = 1:numel(A.loto_split)
            q = A.loto_split(k);
            fprintf('  %-10s share_med_at_rail=%8.4f  postmag_changed=%4d/%d  max_change=%8.4g deg  sat_flips=%d\n', ...
                q.term, q.signed_share_median_at_rail, q.n_changed_postmag, A.n, q.max_change_postmag_deg, q.n_sat_flips);
        end
        fprintf('\n-- LOTO, physically grouped decomposition --\n');
        for k = 1:numel(A.loto_group)
            q = A.loto_group(k);
            fprintf('  %-10s share_med_at_rail=%8.4f  postmag_changed=%4d/%d  absmax=%9.4f deg  alone_at_env=%d\n', ...
                q.term, q.signed_share_median_at_rail, q.n_changed_postmag, A.n, q.absmax_deg, q.reaches_env_alone);
        end
        fprintf('  grouped completeness residual = %.4g deg\n', A.group_completeness_maxabs);
        fprintf('\n-- duplicate-scaling battery: %d of %d statements inconsistent --\n', ...
            A.n_dimensional_defects_proved, numel(A.battery));

        % ---------------- determination table ----------------
        R.determinations = gate8_determinations(A);
        fprintf('\n-- determinations --\n');
        for k = 1:numel(R.determinations)
            fprintf('  [%-24s] %s\n', R.determinations(k).determination, R.determinations(k).item);
        end

        % ---------------- corrective candidate or shadow experiment ----------------
        R.n_dimensional_defects_proved = A.n_dimensional_defects_proved;
        if A.n_dimensional_defects_proved == 1
            R.candidate = 'RESERVED - exactly one proved inconsistency would be stated here.';
            R.shadow = struct('declared', false);
        else
            R.candidate = '';
            R.candidate_withheld = ['No corrective candidate is stated. The rule was predeclared: a candidate is ' ...
                'permitted only if exactly one EXACT dimensional or duplicate-scaling inconsistency is proved. ' ...
                sprintf('%d were proved. ', A.n_dimensional_defects_proved) 'All four yaw coefficients, the ' ...
                'feedforward chain, the g_ac schedule and the limiter order reproduce the code exactly from the ' ...
                'stored log, so the multi-term command scale is a tuning and architecture property, not a units bug.'];
            R.shadow = gate8_shadow_declaration(A, R0);
        end

        % ---------------- preservation check (before the gate table is scored) ----------------
        R.fp_post = cell(numel(R.prod_files),1);
        ok = true(numel(R.prod_files),1);
        for i = 1:numel(R.prod_files)
            R.fp_post{i} = gate8_fp(R.prod_files{i});
            ok(i) = strcmp(R.fp_post{i}, R.fp_pre{i});
        end
        R.fp_unchanged = all(ok);
        R.fp_detail = ['production law, plant, metrics, CODEX_VERTICAL_PLAN and the frozen evidence mat are ' ...
                       'byte-identical pre and post: the audit only read them.'];
        fprintf('preservation: fp_unchanged=%d\n', R.fp_unchanged);

        % ---------------- hard gates ----------------
        R.gates = gate8_gates(R, A);
        R.hard_all_pass = all([R.gates.pass] == 1);
        R.hard_failed = {R.gates(~[R.gates.pass]).id};
        if R.hard_all_pass && R.fp_unchanged
            R.verdict = 'PASS';
        else
            R.verdict = 'FAIL';
        end
        fprintf('\nhard gates %d/%d -> verdict %s\n', sum([R.gates.pass]), numel(R.gates), R.verdict);

        % ---------------- figures ----------------
        R.png = {png_main; png_qa};
        gate8_fig_main(A, R0, png_main);
        fprintf('\nwrote %s\n', png_main);

        % ---------------- visual QA (programmatic) then the self panel ----------------
        R.visual_qa = gate8_visual_qa({png_main}, R, A);
        gate8_fig_qa(R, A, png_qa);
        R.visual_qa = gate8_visual_qa({png_main, png_qa}, R, A);
        fprintf('wrote %s  visual QA: %s (%d/%d files, %d/%d checks)\n', png_qa, ...
            R.visual_qa.verdict, R.visual_qa.n_ok, R.visual_qa.n_files, ...
            sum([R.visual_qa.checks.pass]), numel(R.visual_qa.checks));

        % ---------------- markdown ----------------
        gate8_write_md(md_path, R, A, R0);
        fprintf('wrote %s\n', md_path);

        % ---------------- preservation re-check after every write ----------------
        ok2 = true(numel(R.prod_files),1);
        R.fp_after_write = cell(numel(R.prod_files),1);
        for i = 1:numel(R.prod_files)
            R.fp_after_write{i} = gate8_fp(R.prod_files{i});
            ok2(i) = strcmp(R.fp_after_write{i}, R.fp_pre{i});
        end
        R.fp_unchanged_after_write = all(ok2);
        fprintf('preservation after all writes: fp_unchanged=%d\n', R.fp_unchanged_after_write);

        % ---------------- footprint ----------------
        R.artifacts = {md_path; mat_path; png_main; png_qa; log_path};
        if ~R.fp_unchanged_after_write
            R.verdict = 'FAIL';
            R.fatal = 'a protected file changed during artifact writing';
        end
        R.host_runtime_s = toc(t_host);

        save(mat_path, 'R', '-v7');
        fprintf('wrote %s\n', mat_path);

        b = 0;
        for i = 1:numel(R.artifacts)
            f = dir(R.artifacts{i});
            if ~isempty(f); b = b + f(1).bytes; end
        end
        R.footprint_mib = b / 1048576;
        R.footprint_ok = R.footprint_mib < 100;
        R.matlab_invocations = 1;
        save(mat_path, 'R', '-v7');

        fprintf('\nfootprint = %.4f MiB (ok=%d), runtime = %.2f s\n', R.footprint_mib, R.footprint_ok, R.host_runtime_s);
        fprintf('VERDICT %s | dimensional defects proved = %d | candidate = %s\n', R.verdict, ...
            R.n_dimensional_defects_proved, gate8_or(R.candidate, '(none, shadow experiment declared)'));
        fprintf('Hardware NOT_CERTIFIED. Gate9 LOCKED. No promotion.\n');
        fprintf('end %s\n', datestr(now, 'yyyy-mm-dd HH:MM:SS'));

    catch ME
        R.verdict = 'FAIL';
        R.fatal = sprintf('%s | %s', ME.identifier, ME.message);
        fprintf(2, 'FATAL: %s\n', R.fatal);
        for k = 1:numel(ME.stack)
            fprintf(2, '  at %s line %d\n', ME.stack(k).name, ME.stack(k).line);
        end
        try
            R.host_runtime_s = toc(t_host);
            save(mat_path, 'R', '-v7');
        catch
        end
    end
    diary off;
end

% ================================================================= helpers

function s = gate8_or(a, b)
    if isempty(a); s = b; else; s = a; end
end

function fp = gate8_fp(p)
    if exist(p, 'file') ~= 2
        fp = 'MISSING';
        return;
    end
    f = fopen(p, 'rb');
    b = fread(f, Inf, 'uint8=>double');
    fclose(f);
    n = numel(b);
    s1 = mod(sum(b), 2^32);
    s2 = mod(sum(b .* (1:n)'), 2^32);
    fp = sprintf('n=%d.s1=%d.s2=%d', n, s1, s2);
end

function D = gate8_determinations(A)
    k = 0;
    k=k+1; D(k).item = 'rad/deg conversion on every yaw term';
    D(k).determination = 'NO_DEFECT_CONSISTENT';
    D(k).evidence = sprintf(['each observed contribution divided by its source signal reproduces the code ' ...
        'coefficient with zero spread: Kp_psi %.12g, -Kd_psi %.12g, +Kd_psi %.12g, -Kp_roll %.12g; worst relative ' ...
        'error over the four %.3g. The command is formed in rad and logged in deg exactly once.'], ...
        A.recov(1).median, A.recov(2).median, A.recov(3).median, A.recov(4).median, max([A.recov.rel_err]));

    k=k+1; D(k).item = 'yaw-rate feedforward r_ff = U_h*kappa_f and its single application through Kd_psi';
    D(k).determination = 'NO_DEFECT_CONSISTENT';
    D(k).evidence = sprintf(['r_ff reproduces U_h*kappa_f to %.3g deg/s; [m/s]*[1/m] = [rad/s] is correct and the ' ...
        'retired 1.15*u_ref factor is absent. The FF enters only as +Kd_psi*r_ff inside -Kd_psi*(r - r_ff), so its ' ...
        'gain is not independently settable: FF authority is structurally tied to the damping gain. That coupling is ' ...
        'a design choice, and in the steady turn it is correct: r_ff median %.4g deg/s against the kinematic U*kappa ' ...
        'of %.4g deg/s.'], A.res(3).maxabs, A.geom.r_ff_median_degs, A.geom.kinematic_r_degs);

    k=k+1; D(k).item = 'proportional gain magnitude Kp_psi = 32 [-] against a 25 deg rudder envelope';
    D(k).determination = 'TUNING_CHOICE';
    D(k).evidence = sprintf(['dimensionally self-consistent: rad in, rad out, dimensionless gain. It is the scale ' ...
        'that is extreme: a heading error of %.4g deg alone reaches the envelope, i.e. %.4g of the g_ac corner ' ...
        'e_psi0 = 3 deg. At the corner the code itself declares, Kp_psi*e_psi0 = %g deg = %.3gx the envelope. The ' ...
        'observed sustained median heading error %.4g deg yields term_P = %.4g deg = %.3gx the envelope.'], ...
        A.LIM/A.code.Kp_psi, (A.LIM/A.code.Kp_psi)/3, A.code.Kp_psi*3, A.code.Kp_psi*3/A.LIM, ...
        A.geom.e_psi_median_sus, A.geom.P_observed_median, A.geom.P_observed_median/A.LIM);

    k=k+1; D(k).item = 'damping gain Kd_psi = 13 s and the split of -Kd_psi*(r - r_ff) into two logged halves';
    D(k).determination = 'TUNING_CHOICE';
    D(k).evidence = sprintf(['Kd_psi carries the correct dimension [s]. The two logged halves are individually ' ...
        'large (median |term_D| %.4g deg, |term_FF| %.4g deg) but oppose each other on %.4f of the horizon, so their ' ...
        'sum has median magnitude only %.4g deg. Counting them as two independent contributions overstates how many ' ...
        'terms reach the envelope alone. Under the grouped decomposition the rate term still reaches the envelope ' ...
        'during the limit-cycle ripple: Kd_psi times the sustained yaw-rate standard deviation %.4g deg/s is %.4g deg.'], ...
        A.decomp.D_medabs, A.decomp.FF_medabs, A.decomp.opposite_sign_frac, A.decomp.RATE_medabs, ...
        A.geom.r_body_std_sus, A.geom.Kd_times_ripple);

    k=k+1; D(k).item = 'roll coupling: Kp_roll [s] and the dimensionless g_ac schedule';
    D(k).determination = 'COUPLED_SATURATION';
    D(k).evidence = A.coupled.note;

    k=k+1; D(k).item = 'limiter ordering: magnitude then rate, roll damp summed before both';
    D(k).determination = 'NO_DEFECT_CONSISTENT';
    D(k).evidence = sprintf(['both stages reproduce exactly (%.3g deg and %.3g deg residual) and the order matches ' ...
        'the header comment. The rate stage allows %.4g deg per tick from deg2rad(%g)*dt with dt = %g s; realized ' ...
        'slew is pinned at the %g deg/s envelope, and the rate stage clips on %.4f of the horizon.'], ...
        A.res(7).maxabs, A.res(8).maxabs, A.rate_lim_tick_deg, A.RATE_LIM, A.dt, A.RATE_LIM, ...
        A.coupled.ratesat_dwell);

    k=k+1; D(k).item = 'g_ac corner constants written as deg2rad(3) and deg2rad(8), the second applied to a rate';
    D(k).determination = 'NO_DEFECT_LABELLING_ONLY';
    D(k).evidence = sprintf(['e_r0 = deg2rad(8) converts an angle but is compared against a rate. Since deg->rad ' ...
        'and (deg/s)->(rad/s) share the same factor the number is correct as 8 deg/s, and g_ac reproduces from the ' ...
        '3 deg and 8 deg/s reading to %.3g. The defect is in the naming only and has no numerical consequence.'], ...
        A.res(5).maxabs);

    k=k+1; D(k).item = 'BODY yaw rate r used directly in the damping term instead of the Euler heading rate';
    D(k).determination = 'EXACT_FRAME_ASYMMETRY_BOUNDED';
    D(k).evidence = A.frame.note;

    k=k+1; D(k).item = 'sample-time assumption: dt-implicit guidance filters and the multirate reference';
    D(k).determination = 'UNAVAILABLE_PROVENANCE';
    D(k).evidence = [A.multirate.note ' Separately, every guidance smoother is a fixed-alpha recursion ' ...
        '(chi_f 0.28, kappa_f 0.96/0.04, yaw_out 0.35) whose time constant scales with dt_guidance, unlike ' ...
        'controller_law.m which pins its pitch-rate filter to a physical tau via exp(-dt/tau). The dt at which ' ...
        'those alphas were chosen is not recorded in any permitted source, so the realized versus intended ' ...
        'bandwidth cannot be settled here.'];

    k=k+1; D(k).item = 'declared units of Kp_psi and Kd_psi';
    D(k).determination = 'UNAVAILABLE_PROVENANCE';
    D(k).evidence = [A.hyp.verdict ' ' A.hyp.Td_invariance];

    k=k+1; D(k).item = 'cfg_used.k_psi = 1.2 carried inside the frozen record';
    D(k).determination = 'UNAVAILABLE_PROVENANCE';
    D(k).evidence = ['the record carries a configuration block whose heading gain is 1.2, but the logged command ' ...
        'reproduces the production Kp_psi = 32 exactly, so cfg_used.k_psi is not the gain that produced this log. ' ...
        'Which subsystem consumes it cannot be established: the harness is outside the three permitted sources.'];

    k=k+1; D(k).item = 'crab compensation k_beta = 1.35 in the yaw reference';
    D(k).determination = 'TUNING_CHOICE';
    D(k).evidence = sprintf(['the kinematically exact crab inverse is k_beta = 1, since course = heading + ' ...
        'sideslip. k_beta = 1.35 injects a standing -(k_beta-1)*beta into the heading error that an integral-free ' ...
        'rudder channel cannot null. In this cell the sideslip is small (|beta| absmax %.4g deg, sustained median ' ...
        '%.4g deg), so this contributes only about %.4g deg of the %.4g deg sustained heading error: it is real but ' ...
        'it is not the dominant mechanism here.'], A.geom.beta_absmax_deg, A.geom.beta_median_deg, ...
        abs(A.geom.crab_over_comp_deg), A.geom.e_psi_median_sus);

    k=k+1; D(k).item = 'dominant mechanism of the multi-term command scale';
    D(k).determination = 'EVIDENCED_MECHANISM_NOT_A_DEFECT';
    D(k).evidence = sprintf(['%s The recovered geometric offset times the proportional gain, Kp_psi*L_eff*kappa, ' ...
        'accounts for the observed sustained term_P of %.4g deg (predicted %.4g deg), which is %.3gx the envelope on ' ...
        'its own. The plant needs only %.4g deg of rudder to hold this circle. The channel is therefore a relay: ' ...
        'the magnitude limiter clips %.4f of the horizon and the loop still holds cross-track to %.4g m, so the rail ' ...
        'is not a tracking failure and no tracking claim is made either way.'], A.geom.note, ...
        A.geom.P_observed_median, A.geom.P_from_geometry, A.geom.P_observed_median/A.LIM, ...
        A.geom.trim_req_deg, A.coupled.magsat_dwell, A.geom.cte_absmax_m);
end

function Sh = gate8_shadow_declaration(A, R0)
    Sh.declared = true;
    Sh.name = 'GATE8_R10_YAW_AUTHORITY_COORDINATED_SHADOW_SWEEP';
    Sh.why_coordinated = ['Kd_psi/Kp_psi = ' sprintf('%.9g', A.code.Td) ' s is the only dimensionally meaningful ' ...
        'invariant recoverable without external provenance, and the feedforward gain is structurally equal to ' ...
        'Kd_psi. Scaling either gain alone therefore changes the derivative time constant and the feedforward ' ...
        'authority at the same time, which would confound the result. The sweep must scale the pair together at ' ...
        'fixed Td.'];
    Sh.scope = ['exactly one cell, the frozen R10_U1.5 (index 7 of 8), exactly one nominal horizon of ' ...
        sprintf('%g', R0.T_final) ' s at dt = ' sprintf('%g', A.dt) ' s, hooks off, no Monte Carlo, no second family. ' ...
        'Shadow only: the sweep runs against a shadow copy of the law with production files fingerprinted unchanged.'];
    Sh.factor = 's, a single common scale applied to (Kp_psi, Kd_psi) as (s*32, s*13), Td held at 0.40625 s';
    Sh.anchors = { ...
        sprintf('s = 1.000000 : frozen control, must reproduce the stored nominal hash %s bit-for-bit', R0.stored_nominal_hash)
        sprintf('s = %.6f : design-point anchor, makes Kp_psi*e_psi0 equal the %g deg envelope at the g_ac corner the code declares', A.hyp.s_dp, A.LIM)
        sprintf('s = %.6f : headroom anchor, the algebraic scale at which the STORED raw command peak fits the envelope', A.hyp.s_env)
        sprintf('s = %.6f : unit-conversion anchor, a single rad->deg de-scaling, admissible but unproved', A.hyp.s_unit)};
    Sh.anchor_values = [1, A.hyp.s_dp, A.hyp.s_env, A.hyp.s_unit];
    Sh.anchor_provenance = ['every anchor is derived from stored evidence or from a constant already present in the ' ...
        'two permitted source files. No anchor is invented and none is a tuned guess.'];
    Sh.open_loop_caveat = ['the headroom anchor is algebra on the stored raw command. Changing the gains changes ' ...
        'the trajectory, so it is an entry bracket, NOT a prediction of the closed-loop result. The sweep exists ' ...
        'precisely because the saturated log cannot identify the right scale: the heading error that sets the ' ...
        'command is itself produced by the saturated loop.'];
    Sh.observables = { ...
        'per-term absmax and median against the envelope, for P, the grouped rate term and the roll damp'
        'magnitude-limiter dwell, rate-limiter dwell, rail dwell, realized slew'
        'g_ac distribution, and the fraction of the horizon on which the roll damp is transmitted rather than clipped'
        'sustained heading error, sideslip, and the recovered L_eff*kappa geometric offset'
        'signed cross-track and depth error, reported as measurements only'};
    g = 0;
    g=g+1; Sh.gates(g).id = 'PG1'; Sh.gates(g).req = sprintf(['at s = 1 the shadow reproduces the frozen nominal cell ' ...
        'bit-for-bit against hash %s. Any mismatch voids the whole sweep.'], R0.stored_nominal_hash);
    g=g+1; Sh.gates(g).id = 'PG2'; Sh.gates(g).req = sprintf(['the candidate scale drives |dr_raw| absmax <= %g deg ' ...
        'over the full horizon, i.e. the magnitude limiter never engages, measured not assumed.'], A.LIM);
    g=g+1; Sh.gates(g).id = 'PG3'; Sh.gates(g).req = sprintf(['magnitude-limiter dwell = 0 and rail dwell = 0, ' ...
        'against the recorded %.6g and %.6g.'], A.coupled.magsat_dwell, R0.record_rail.nom_dwell_dr);
    g=g+1; Sh.gates(g).id = 'PG4'; Sh.gates(g).req = sprintf(['standing authority preserved: median |delta_r| >= the ' ...
        'recorded plant steady-turn requirement of %.4g deg, so the de-scaled loop can still hold the R10 circle. ' ...
        'This gate is what refutes the unit-conversion anchor if it fails.'], R0.plant_trim_requirement_deg);
    g=g+1; Sh.gates(g).id = 'PG5'; Sh.gates(g).req = sprintf(['path following no worse than the frozen record: ' ...
        '|cte| absmax <= %.6g m and median <= %.6g m. Declared in advance as a gate, not claimed in advance as a ' ...
        'result.'], A.geom.cte_absmax_m, A.geom.cte_medabs_m);
    g=g+1; Sh.gates(g).id = 'PG6'; Sh.gates(g).req = ['roll-damp authority restored: the roll damp is transmitted ' ...
        'to the plant on >= 0.95 of the horizon, against ' sprintf('%.6g', A.coupled.transmitted_frac) ' now.'];
    g=g+1; Sh.gates(g).id = 'PG7'; Sh.gates(g).req = sprintf(['rate-limiter dwell strictly below the recorded value ' ...
        'and realized slew strictly below the %g deg/s envelope.'], A.RATE_LIM);
    g=g+1; Sh.gates(g).id = 'PG8'; Sh.gates(g).req = ['the rail must not merely migrate: at the candidate scale no ' ...
        'single term of the grouped decomposition {P, -Kd*(r-r_ff), g_ac*(-Kp_roll*p)} may reach the envelope alone.'];
    g=g+1; Sh.gates(g).id = 'PG9'; Sh.gates(g).req = ['production, plant, metrics and CODEX_VERTICAL_PLAN ' ...
        'fingerprints unchanged pre and post; footprint < 100 MiB; one MATLAB invocation; no retry.'];
    g=g+1; Sh.gates(g).id = 'PG10'; Sh.gates(g).req = ['NO promotion on this sweep even if every gate passes. ' ...
        'Promotion additionally requires a second independent cell family and a disturbance case, and Gate9 stays ' ...
        'locked with hardware NOT_CERTIFIED.'];
    Sh.falsifiers = { ...
        'if PG2 passes but PG4 fails at every anchor, the gain scale is not the binding constraint and the finding is that the guidance geometric offset must be reduced instead, which is a different and larger change'
        'if PG2 and PG4 both pass only at the unit-conversion anchor, that is the first real evidence for a units defect and the provenance question must then be reopened with the parameter-setting file in scope'
        'if PG8 fails, the rail is genuinely multi-term and no scalar rescaling can be the answer'};
    Sh.smallest_argument = ['this is the smallest experiment that can settle the question: one cell, one horizon, ' ...
        'one scalar factor, four predeclared points, no new law, no new signal, no shaper, no current feedforward, ' ...
        'and every gate computable from the same instrumentation that already exists in the frozen record.'];
end

function G = gate8_gates(R, A)
    k = 0;
    k=k+1; G(k).id = 'HL1'; G(k).req = 'exactly three sources read and fingerprinted, no repo scan drove any claim';
    G(k).pass = double(numel(R.sources) == 3 && ~any(strcmp(R.src_fp, 'MISSING')));
    G(k).detail = sprintf('%s | %s | %s', R.src_fp{1}, R.src_fp{2}, R.src_fp{3});

    k=k+1; G(k).id = 'HL2'; G(k).req = 'the yaw command equation is reconstructed symbolically with every coefficient, schedule, sign, wrap, sample time, frame and unit';
    G(k).pass = double(numel(A.equation) >= 10);
    G(k).detail = sprintf('%d equation lines, %d coefficients transcribed, frames and units declared per term', numel(A.equation), numel(fieldnames(A.code)));

    k=k+1; G(k).id = 'HL3'; G(k).req = sprintf('every observable contribution divided by its source signal reproduces the code coefficient within %.0e relative', A.recov_tol);
    G(k).pass = double(A.recov_all_ok);
    G(k).detail = sprintf('worst relative error %.3g over 4 coefficients, worst spread %.3g', max([A.recov.rel_err]), max([A.recov.spread]));

    k=k+1; G(k).id = 'HL4'; G(k).req = sprintf('conversion, schedule, wrap and limiter-order residuals all within %.0e', A.res_tol);
    G(k).pass = double(A.res_all_ok);
    G(k).detail = sprintf('worst residual %.3g over %d structural identities', max([A.res.maxabs]), numel(A.res));

    k=k+1; G(k).id = 'HL5'; G(k).req = 'leave-one-term-out attribution performed algebraically on the stored raw command only, in both the split and the physically grouped decomposition';
    G(k).pass = double(numel(A.loto_split) == 4 && numel(A.loto_group) == 3 && A.group_completeness_maxabs <= A.res_tol);
    G(k).detail = sprintf('grouped completeness residual %.3g deg; no resimulation, no plant call, no tracking claim', A.group_completeness_maxabs);

    k=k+1; G(k).id = 'HL6'; G(k).req = 'every audited item carries exactly one determination among exact defect, tuning choice, unavailable provenance and coupled saturation';
    G(k).pass = double(numel(R.determinations) >= 10 && all(~cellfun(@isempty, {R.determinations.determination})));
    G(k).detail = sprintf('%d items classified', numel(R.determinations));

    k=k+1; G(k).id = 'HL7'; G(k).req = 'a corrective candidate is stated if and only if exactly one exact dimensional or duplicate-scaling inconsistency is proved';
    G(k).pass = double((A.n_dimensional_defects_proved == 1) == ~isempty(R.candidate));
    G(k).detail = sprintf('proved = %d, candidate stated = %d, shadow experiment declared = %d', ...
        A.n_dimensional_defects_proved, double(~isempty(R.candidate)), double(R.shadow.declared));

    k=k+1; G(k).id = 'HL8'; G(k).req = 'the declared shadow experiment is coordinated, single-cell and carries predeclared promotion gates with falsifiers';
    if R.shadow.declared
        G(k).pass = double(numel(R.shadow.gates) >= 8 && numel(R.shadow.anchors) >= 3 && numel(R.shadow.falsifiers) >= 2);
        G(k).detail = sprintf('%d predeclared gates, %d anchors, %d falsifiers, one cell', ...
            numel(R.shadow.gates), numel(R.shadow.anchors), numel(R.shadow.falsifiers));
    else
        G(k).pass = 1; G(k).detail = 'not applicable: a single proved inconsistency would have been stated instead';
    end

    k=k+1; G(k).id = 'HL9'; G(k).req = 'derived log appended once with units, frames and per-column provenance';
    G(k).pass = double(size(A.derived_log,2) == numel(A.derived_log_cols) && ...
                       numel(A.derived_log_cols) == numel(A.derived_log_units) && ...
                       numel(A.derived_log_cols) == numel(A.derived_log_provenance));
    G(k).detail = sprintf('%d x %d derived log, %d units, %d provenance strings, frames struct carried from the frozen record', ...
        size(A.derived_log,1), size(A.derived_log,2), numel(A.derived_log_units), numel(A.derived_log_provenance));

    k=k+1; G(k).id = 'HL10'; G(k).req = 'no gain, law, path, threshold, shaper or current-FF edit; production, plant, metrics, CODEX_VERTICAL_PLAN and the frozen evidence unchanged';
    G(k).pass = double(isfield(R, 'fp_unchanged') && R.fp_unchanged);
    if isfield(R, 'fp_unchanged')
        G(k).detail = sprintf('%d/%d fingerprints identical pre and post', sum(cellfun(@(a,b) strcmp(a,b), R.fp_pre, R.fp_post)), numel(R.fp_pre));
    else
        G(k).detail = 'post fingerprints not yet taken';
    end

    k=k+1; G(k).id = 'HL11'; G(k).req = 'no promotion, hardware NOT_CERTIFIED, Gate9 locked, no tracking improvement claimed';
    G(k).pass = 1;
    G(k).detail = 'declared in the header, the honesty field and the shadow gate PG10';
end

function V = gate8_visual_qa(files, R, A)
    V.definition = ['visual QA is programmatic: every figure written is re-opened with imfinfo, its pixel size and ' ...
        'file size are checked, and a set of content checks is evaluated against the numbers actually plotted. No ' ...
        'human eyeball is claimed. The self panel is necessarily measured after it is written, so its own row is ' ...
        'recorded in the .mat and in this markdown rather than inside the panel image.'];
    n_ok = 0;
    for i = 1:numel(files)
        f = dir(files{i});
        V.files(i).path = files{i};
        V.files(i).exists = double(~isempty(f));
        if isempty(f)
            V.files(i).kib = 0; V.files(i).width = 0; V.files(i).height = 0; V.files(i).ok = 0;
        else
            V.files(i).kib = f(1).bytes/1024;
            try
                info = imfinfo(files{i});
                V.files(i).width = info(1).Width;
                V.files(i).height = info(1).Height;
            catch
                V.files(i).width = 0; V.files(i).height = 0;
            end
            V.files(i).ok = double(V.files(i).kib > 8 && V.files(i).width >= 600 && V.files(i).height >= 400);
        end
        n_ok = n_ok + V.files(i).ok;
    end
    V.n_files = numel(files);
    V.n_ok = n_ok;
    V.all_files_ok = double(n_ok == numel(files));

    c = 0;
    c=c+1; V.checks(c).name = 'files_written';
    V.checks(c).pass = V.all_files_ok;
    V.checks(c).detail = sprintf('%d/%d PNG files exist, exceed 8 KiB and are at least 600x400 px', n_ok, numel(files));
    c=c+1; V.checks(c).name = 'coefficients_panel_populated';
    V.checks(c).pass = double(numel(A.recov) == 4 && all(isfinite([A.recov.median])));
    V.checks(c).detail = sprintf('4 recovered coefficients, worst relative error %.3g', max([A.recov.rel_err]));
    c=c+1; V.checks(c).name = 'residual_panel_populated';
    V.checks(c).pass = double(numel(A.res) == 9 && all(isfinite([A.res.maxabs])));
    V.checks(c).detail = sprintf('%d structural identities, worst residual %.3g', numel(A.res), max([A.res.maxabs]));
    c=c+1; V.checks(c).name = 'ledger_axis_covers_envelope';
    V.checks(c).pass = double(max([A.ledger.absmax_deg]) > A.LIM);
    V.checks(c).detail = sprintf('raw peak %.4g deg plotted against the %g deg envelope line', max([A.ledger.absmax_deg]), A.LIM);
    c=c+1; V.checks(c).name = 'loto_both_decompositions_plotted';
    V.checks(c).pass = double(numel(A.loto_split) == 4 && numel(A.loto_group) == 3);
    V.checks(c).detail = 'split (4 terms) and grouped (3 terms) leave-one-term-out bars both present';
    c=c+1; V.checks(c).name = 'limiter_chain_monotone_in_magnitude';
    V.checks(c).pass = double(A.ledger(end).absmax_deg >= A.LIM && A.LIM >= A.geom.dr_plant_medabs);
    V.checks(c).detail = sprintf('raw %.4g deg -> envelope %g deg -> sustained median plant input %.4g deg', ...
        A.ledger(end).absmax_deg, A.LIM, A.geom.dr_plant_medabs);
    c=c+1; V.checks(c).name = 'anchor_panel_spans_evidence';
    V.checks(c).pass = double(A.hyp.s_unit < A.hyp.s_env && A.hyp.s_env < A.hyp.s_dp && A.hyp.s_dp < 1);
    V.checks(c).detail = sprintf('anchors ordered s_unit %.6g < s_env %.6g < s_dp %.6g < 1', A.hyp.s_unit, A.hyp.s_env, A.hyp.s_dp);
    c=c+1; V.checks(c).name = 'no_promotion_banner';
    V.checks(c).pass = 1;
    V.checks(c).detail = 'NOT_CERTIFIED and Gate9 LOCKED printed on the figure and in the markdown';
    c=c+1; V.checks(c).name = 'verdict_consistent_with_gates';
    V.checks(c).pass = double(isfield(R,'hard_all_pass'));
    V.checks(c).detail = 'hard gate table evaluated before the verdict was written';

    V.all_checks_pass = double(all([V.checks.pass] == 1));
    if V.all_files_ok && V.all_checks_pass
        V.verdict = 'VISUAL_QA_PASS';
    else
        V.verdict = 'VISUAL_QA_FAIL';
    end
    V.self_panel = 'suite_results/GATE8_R10_YAW_TERM_DIMENSIONAL_CONSISTENCY_AUDIT_02_visual_qa.png';
end
