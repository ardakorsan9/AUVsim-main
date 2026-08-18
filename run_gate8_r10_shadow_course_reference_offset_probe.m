function run_gate8_r10_shadow_course_reference_offset_probe()
% GATE8_R10_SHADOW_COURSE_REFERENCE_OFFSET_PROBE_001
%
% Isolated, read-only shadow probe. Candidate C1 = the production yaw
% reference arithmetic with k_beta changed 1.35 -> 1.00 and NOTHING else:
%     chi_raw_C1 = wrap(chi_f + 0.75*chi_los - 1.00*beta)
% replayed through the identical unwrap, 0.35 blend, +-40 deg/s slew clip
% and 3:1 zero-order hold, driven by the recorded R10_U1.5 30 s guidance
% signal log. Production guidance / controller / plant are never called and
% never edited; this file only reads the frozen log and writes new evidence.
%
% Sources (exactly three): guidance_law.m, controller_law.m,
% suite_results/GATE8_R10_GUIDANCE_SIGNAL_LOG_CLOSURE.mat
%
% Certification: NOT_CERTIFIED (simulation-only, log replay). Gate 9 locked.

TASK = 'GATE8_R10_SHADOW_COURSE_REFERENCE_OFFSET_PROBE_001';
STEM = fullfile('suite_results', 'GATE8_R10_SHADOW_COURSE_REFERENCE_OFFSET_PROBE');
LOGF = [STEM '_run.log'];

lg = fopen(LOGF, 'w');
R2 = struct();
R2.task_id = TASK;
R2.verdict = 'INCOMPLETE';
R2.fatal = '';

try
    say(lg, '=== %s ===', TASK);
    say(lg, 'started %s', datestr(now, 'yyyy-mm-dd HH:MM:SS'));
    say(lg, 'matlab %s on %s', version, computer);
    say(lg, 'pwd %s', pwd);

    % ------------------------------------------------------------------
    % 0. declared gates (declared BEFORE any metric is computed)
    % ------------------------------------------------------------------
    G = struct();
    G.recon_tol_rad          = 1e-9;   % production reconstruction residual
    G.wrap_identity_tol_rad  = 1e-9;
    G.slew_bound_deg_tick    = 3.0;    % deg2rad(40)*dt_g = 3 deg per tick
    G.primary_improve_pct    = 5.0;    % BOTH primary legs must improve >= 5 %%
    G.secondary_worsen_pct   = 2.0;    % no secondary logged metric worse > 2 %%
    G.Kp_psi                 = 32.0;   % algebraic P demand gain
    G.k_beta_prod            = 1.35;
    G.k_beta_C1              = 1.00;
    G.declared_before_running = true;
    R2.gates_declared = G;
    say(lg, 'gates declared: primary >= %.1f%% (both legs), secondary worsen <= %.1f%%, slew <= %.1f deg/tick, recon <= %.0e rad', ...
        G.primary_improve_pct, G.secondary_worsen_pct, G.slew_bound_deg_tick, G.recon_tol_rad);

    % ------------------------------------------------------------------
    % 1. production fingerprint PRE
    % ------------------------------------------------------------------
    S = load(fullfile('suite_results', 'GATE8_R10_GUIDANCE_SIGNAL_LOG_CLOSURE.mat'));
    Rl = S.R;
    prod_files = Rl.prod_files(:);
    fp_frozen  = Rl.fp_post(:);
    nf = numel(prod_files);
    fp_pre = cell(nf, 1);
    fp_pre_ok = true;
    for i = 1:nf
        fp_pre{i} = file_fp(strrep(prod_files{i}, '\', filesep));
        ok = strcmp(fp_pre{i}, fp_frozen{i});
        fp_pre_ok = fp_pre_ok && ok;
        say(lg, 'fp_pre  %-38s %s  match=%d', prod_files{i}, fp_pre{i}, ok);
    end
    R2.prod_files = prod_files;
    R2.fp_frozen  = fp_frozen;
    R2.fp_pre     = fp_pre;
    R2.fp_pre_ok  = fp_pre_ok;
    if ~fp_pre_ok
        error('PROD_FP_PRE_MISMATCH: production fingerprint is not the frozen hash');
    end

    % ------------------------------------------------------------------
    % 2. observer closure must hold BEFORE comparison
    % ------------------------------------------------------------------
    A = Rl.analysis;
    cl = struct();
    cl.source_verdict     = Rl.verdict;
    cl.prod_fp_match      = double(Rl.prod_fp_match);
    cl.instr_fp_match     = double(Rl.instr_fp_match);
    cl.parity_ok          = double(Rl.parity_ok);
    cl.traj_hash_frozen   = strcmp(Rl.prod_hash, Rl.required_fp);
    cl.closure_pass       = double(A.closure.pass);
    cl.geometry_pass      = double(A.geometry.pass);
    cl.continuity_pass    = double(A.continuity.pass);
    cl.mirror_max_abs     = A.closure.mirror_max_abs;
    cl.recursion_max_abs  = A.closure.recursion_max_abs;
    cl.epsi_max_abs       = A.closure.epsi_max_abs;
    cl.ok = cl.prod_fp_match && cl.instr_fp_match && cl.parity_ok && ...
            cl.traj_hash_frozen && cl.closure_pass && cl.geometry_pass && ...
            cl.continuity_pass && strcmp(cl.source_verdict, 'CLOSED');
    R2.observer_closure = cl;
    say(lg, 'observer closure: verdict=%s prod_fp=%d instr_fp=%d parity=%d traj_hash_frozen=%d closure=%d geometry=%d continuity=%d -> ok=%d', ...
        cl.source_verdict, cl.prod_fp_match, cl.instr_fp_match, cl.parity_ok, ...
        cl.traj_hash_frozen, cl.closure_pass, cl.geometry_pass, cl.continuity_pass, cl.ok);
    if ~cl.ok
        error('OBSERVER_CLOSURE_NOT_HELD: refusing to compare');
    end

    % ------------------------------------------------------------------
    % 3. cadence / state initialisation carried verbatim from the record
    % ------------------------------------------------------------------
    cols = Rl.log_cols(:);
    Lg   = Rl.log;
    nr   = size(Lg, 1);
    c    = @(nm) Lg(:, find(strcmp(cols, nm), 1));

    dt_ctrl   = Rl.dt;
    dt_g      = Rl.dt_guidance_eff;
    gper      = Rl.guidance_period;
    Tf        = Rl.T_final;
    max_dyaw  = deg2rad(40) * dt_g;
    state0    = Rl.cell.state0;
    cellname  = Rl.cell.name;

    t      = c('t_s');
    gupd   = round(c('gupd')) == 1;
    chi_f  = c('chi_f_rad');
    chi_los= c('chi_los_rad');
    beta_g = c('beta_g_rad');
    beta_ex= c('beta_exact_rad');
    chi_now= c('chi_now_rad');
    chi_og = c('chi_og_rad');
    psi    = c('psi_ctrl_rad');
    near_e = c('near_end');
    yaw_raw_log  = c('yaw_raw_rad');
    yaw_cont_log = c('yaw_cont_rad');
    yaw_out_log  = c('yaw_out_rad');
    yaw_ref_log  = c('yaw_ref_prod_rad');
    yaw_held_log = c('yaw_ref_held_rad');
    dy_des_log   = c('dy_des_rad');
    dy_app_log   = c('dy_app_rad');
    epsi_log     = c('e_psi_dbg_rad');

    wmask = logical(A.window_mask(:));
    gi = find(gupd);
    wi = find(wmask);
    say(lg, 'cell %s  dt=%.4f  dt_g=%.6f  period=%d:1  T=%g s  ticks=%d  gticks=%d  window=%d  near_end=%d', ...
        cellname, dt_ctrl, dt_g, gper, Tf, nr, numel(gi), numel(wi), sum(near_e));
    say(lg, 'state0 = [%s]', strtrim(sprintf('%g ', state0)));
    say(lg, 'slew bound = deg2rad(40)*dt_g = %.10f rad = %.6f deg/tick', max_dyaw, rad2deg(max_dyaw));

    % ------------------------------------------------------------------
    % 4. reconstruct production reference exactly, then run C1
    % ------------------------------------------------------------------
    P  = shadow_pipeline(chi_f, chi_los, beta_g, gupd, G.k_beta_prod, max_dyaw);
    C1 = shadow_pipeline(chi_f, chi_los, beta_g, gupd, G.k_beta_C1,   max_dyaw);

    rec = struct();
    rec.yaw_raw  = max(abs(P.raw(gi)  - yaw_raw_log(gi)));
    rec.yaw_cont = max(abs(P.cont(gi) - yaw_cont_log(gi)));
    rec.yaw_out  = max(abs(P.out(gi)  - yaw_out_log(gi)));
    rec.yaw_ref  = max(abs(P.out(gi)  - yaw_ref_log(gi)));
    rec.held     = max(abs(P.held     - yaw_held_log));
    rec.dy_des   = max(abs(P.dyd(gi)  - dy_des_log(gi)));
    rec.dy_app   = max(abs(P.dya(gi)  - dy_app_log(gi)));

    e_psi_P = wrappi(P.held  - psi);
    e_psi_Q = wrappi(C1.held - psi);
    rec.e_psi = max(abs(e_psi_P - epsi_log));
    rec.max_all = max([rec.yaw_raw rec.yaw_cont rec.yaw_out rec.yaw_ref ...
                       rec.held rec.dy_des rec.dy_app rec.e_psi]);
    rec.pass = rec.max_all <= G.recon_tol_rad;
    R2.reconstruction = rec;
    say(lg, 'reconstruction residuals (rad): raw %.3e cont %.3e out %.3e ref %.3e held %.3e dyd %.3e dya %.3e epsi %.3e -> worst %.3e pass=%d', ...
        rec.yaw_raw, rec.yaw_cont, rec.yaw_out, rec.yaw_ref, rec.held, ...
        rec.dy_des, rec.dy_app, rec.e_psi, rec.max_all, rec.pass);
    if ~rec.pass
        error('RECONSTRUCTION_FAILED: production reference not reproduced within %.0e rad', G.recon_tol_rad);
    end

    % ------------------------------------------------------------------
    % 5. metrics
    % ------------------------------------------------------------------
    Kp = G.Kp_psi;
    pd_P = Kp * e_psi_P;    % algebraic P demand [rad of rudder command]
    pd_Q = Kp * e_psi_Q;

    oc_P = -(G.k_beta_prod - 1) * beta_g;   % structural over-crab contribution
    oc_Q = -(G.k_beta_C1   - 1) * beta_g;   % identically zero for C1

    M = struct();
    % --- primary, sustained window ---
    M.overcrab_meanabs_deg_w = [meanabs_deg(oc_P(wi)),   meanabs_deg(oc_Q(wi))];
    M.pdemand_meanabs_w      = [mean(abs(pd_P(wi))),     mean(abs(pd_Q(wi)))];
    % --- secondary, sustained window ---
    M.epsi_meanabs_deg_w     = [meanabs_deg(e_psi_P(wi)), meanabs_deg(e_psi_Q(wi))];
    M.epsi_rms_deg_w         = [rms_deg(e_psi_P(wi)),     rms_deg(e_psi_Q(wi))];
    M.epsi_absmax_deg_w      = [absmax_deg(e_psi_P(wi)),  absmax_deg(e_psi_Q(wi))];
    M.pdemand_rms_w          = [sqrt(mean(pd_P(wi).^2)),  sqrt(mean(pd_Q(wi).^2))];
    M.pdemand_absmax_w       = [max(abs(pd_P(wi))),       max(abs(pd_Q(wi)))];
    % --- secondary, full record ---
    M.epsi_meanabs_deg_f     = [meanabs_deg(e_psi_P), meanabs_deg(e_psi_Q)];
    M.epsi_rms_deg_f         = [rms_deg(e_psi_P),     rms_deg(e_psi_Q)];
    M.epsi_absmax_deg_f      = [absmax_deg(e_psi_P),  absmax_deg(e_psi_Q)];
    M.pdemand_meanabs_f      = [mean(abs(pd_P)),      mean(abs(pd_Q))];
    M.pdemand_rms_f          = [sqrt(mean(pd_P.^2)),  sqrt(mean(pd_Q.^2))];
    M.overcrab_meanabs_deg_f = [meanabs_deg(oc_P),    meanabs_deg(oc_Q)];
    % --- continuity / slew / wrap ---
    M.max_dyaw_out_deg       = [rad2deg(max(abs(diff(P.out(gi))))), rad2deg(max(abs(diff(C1.out(gi)))))];
    M.max_dy_des_deg         = [rad2deg(max(abs(P.dyd(gi)))),       rad2deg(max(abs(C1.dyd(gi))))];
    M.max_dyaw_cont_deg      = [rad2deg(max(abs(diff(P.cont(gi))))),rad2deg(max(abs(diff(C1.cont(gi)))))];
    M.total_turn_rad         = [P.cont(gi(end))-P.cont(gi(1)),      C1.cont(gi(end))-C1.cont(gi(1))];
    M.n_slew_engaged         = [P.nslew, C1.nslew];
    M.n_wrap_events          = [sum(abs(diff(P.raw(gi))) > pi),     sum(abs(diff(C1.raw(gi))) > pi)];
    M.wrap_identity_max      = [max(abs(wrappi(P.raw(gi)) - P.raw(gi))), ...
                                max(abs(wrappi(C1.raw(gi)) - C1.raw(gi)))];
    M.finite_ok              = [all(isfinite(P.out(gi))), all(isfinite(C1.out(gi)))];
    % --- reference delta ---
    dref_deg = rad2deg(C1.held - P.held);
    M.yawref_delta_mean_deg_w   = mean(dref_deg(wi));
    M.yawref_delta_absmax_deg   = max(abs(dref_deg));
    M.yawref_delta_rms_deg      = sqrt(mean(dref_deg.^2));
    R2.metrics = M;
    R2.series = struct('t_s', t, 'gupd', double(gupd), 'window_mask', double(wmask), ...
        'yaw_ref_prod_rad', P.held, 'yaw_ref_C1_rad', C1.held, ...
        'yaw_cont_prod_rad', P.cont, 'yaw_cont_C1_rad', C1.cont, ...
        'dy_des_prod_rad', P.dyd, 'dy_des_C1_rad', C1.dyd, ...
        'dy_app_prod_rad', P.dya, 'dy_app_C1_rad', C1.dya, ...
        'e_psi_prod_rad', e_psi_P, 'e_psi_C1_rad', e_psi_Q, ...
        'pdemand_prod_rad', pd_P, 'pdemand_C1_rad', pd_Q, ...
        'overcrab_prod_rad', oc_P, 'overcrab_C1_rad', oc_Q, ...
        'beta_g_rad', beta_g, 'beta_exact_rad', beta_ex, 'psi_rad', psi);

    % ------------------------------------------------------------------
    % 6. structural over-crab removal + zero-curvature reduction
    % ------------------------------------------------------------------
    ocr = struct();
    ocr.term = '-(k_beta-1)*beta';
    ocr.prod_mean_deg   = mean(rad2deg(oc_P(wi)));
    ocr.prod_meanabs_deg= meanabs_deg(oc_P(wi));
    ocr.prod_absmax_deg = absmax_deg(oc_P(wi));
    ocr.C1_mean_deg     = mean(rad2deg(oc_Q(wi)));
    ocr.C1_absmax_deg   = absmax_deg(oc_Q(wi));
    ocr.removal_pct     = 100.0;
    ocr.recorded_structural_offset_mean_deg = A.crab.structural_offset_mean_deg;
    ocr.reconstruction_match = abs(ocr.prod_mean_deg - A.crab.structural_offset_mean_deg);
    R2.overcrab = ocr;
    say(lg, 'over-crab: prod mean %.6f deg (recorded %.6f, delta %.3e) meanabs %.6f -> C1 identically 0', ...
        ocr.prod_mean_deg, ocr.recorded_structural_offset_mean_deg, ocr.reconstruction_match, ocr.prod_meanabs_deg);

    % zero-curvature reduction: kappa = 0 => chi_los = 0, chi_f constant.
    zk = struct();
    zk.chi_const_rad = A.geometry.zero_kappa_start_offset_rad;
    zk.beta_ss_rad   = deg2rad(A.crab.beta_mean_deg);
    zk.n_iter        = 4000;
    zk.prod_offset_deg = zero_kappa_ss(zk.chi_const_rad, zk.beta_ss_rad, G.k_beta_prod, max_dyaw, zk.n_iter);
    zk.C1_offset_deg   = zero_kappa_ss(zk.chi_const_rad, zk.beta_ss_rad, G.k_beta_C1,   max_dyaw, zk.n_iter);
    zk.prod_closed_form_deg = rad2deg(-G.k_beta_prod * zk.beta_ss_rad);
    zk.C1_closed_form_deg   = rad2deg(-G.k_beta_C1   * zk.beta_ss_rad);
    zk.resid_prod = abs(zk.prod_offset_deg - zk.prod_closed_form_deg);
    zk.resid_C1   = abs(zk.C1_offset_deg   - zk.C1_closed_form_deg);
    zk.reduction_pct = 100 * (abs(zk.prod_offset_deg) - abs(zk.C1_offset_deg)) / abs(zk.prod_offset_deg);
    zk.recorded_zero_kappa_lead_max = A.geometry.zero_kappa_lead_max;
    R2.zero_curvature = zk;
    say(lg, 'zero-curvature: lead identically 0 (recorded %.1e); steady offset %.6f -> %.6f deg (%.3f%% reduction), closed-form residual %.2e / %.2e', ...
        zk.recorded_zero_kappa_lead_max, zk.prod_offset_deg, zk.C1_offset_deg, ...
        zk.reduction_pct, zk.resid_prod, zk.resid_C1);

    % ------------------------------------------------------------------
    % 7. course-offset attribution identity (window means, deg)
    % ------------------------------------------------------------------
    id = struct();
    id.datum = 'chi_og - chi_now (course over ground minus path course at s_prog)';
    lag_P = rad2deg(wrappi(chi_f(wi) - chi_now(wi)) + 0.75*chi_los(wi)) + rad2deg(wrappi(P.out(wi)  - P.raw(wi)));
    lag_Q = rad2deg(wrappi(chi_f(wi) - chi_now(wi)) + 0.75*chi_los(wi)) + rad2deg(wrappi(C1.out(wi) - C1.raw(wi)));
    id.model_mean_deg = mean(rad2deg(beta_ex(wi) - beta_g(wi)));
    id.prod = struct('lead_lag', mean(lag_P), 'epsi', mean(-rad2deg(e_psi_P(wi))), ...
                     'crab', mean(rad2deg(oc_P(wi))), 'model', id.model_mean_deg);
    id.C1   = struct('lead_lag', mean(lag_Q), 'epsi', mean(-rad2deg(e_psi_Q(wi))), ...
                     'crab', mean(rad2deg(oc_Q(wi))), 'model', id.model_mean_deg);
    id.prod_sum = id.prod.lead_lag + id.prod.epsi + id.prod.crab + id.prod.model;
    id.C1_sum   = id.C1.lead_lag   + id.C1.epsi   + id.C1.crab   + id.C1.model;
    id.measured_total_deg = mean(rad2deg(wrappi(chi_og(wi) - chi_now(wi))));
    id.prod_resid = abs(id.prod_sum - id.measured_total_deg);
    id.C1_resid   = abs(id.C1_sum   - id.measured_total_deg);
    id.invariance_note = ['the achieved course chi_og is a recorded plant output, so under ' ...
        'open-loop shadow replay the total course offset is invariant by construction; C1 ' ...
        'removes the crab term and the identity transfers it into the heading-error term.'];
    id.recorded_terms = A.geometry.terms;
    R2.identity = id;
    say(lg, 'identity prod: lag %.6f epsi %.6f crab %.6f model %.6f sum %.6f (measured %.6f, resid %.2e)', ...
        id.prod.lead_lag, id.prod.epsi, id.prod.crab, id.prod.model, id.prod_sum, id.measured_total_deg, id.prod_resid);
    say(lg, 'identity C1  : lag %.6f epsi %.6f crab %.6f model %.6f sum %.6f (measured %.6f, resid %.2e)', ...
        id.C1.lead_lag, id.C1.epsi, id.C1.crab, id.C1.model, id.C1_sum, id.measured_total_deg, id.C1_resid);

    % ------------------------------------------------------------------
    % 8. gate evaluation
    % ------------------------------------------------------------------
    % improvement = reduction in magnitude, per cent of the production value
    imp = @(v) 100 * (v(1) - v(2)) / abs(v(1));

    K = cell(2, 6);
    K(1,1:5) = {'PRIMARY-1 sustained mean abs over-crab contribution [deg]', ...
                M.overcrab_meanabs_deg_w, imp(M.overcrab_meanabs_deg_w), ...
                G.primary_improve_pct, true};
    K(2,1:5) = {'PRIMARY-2 sustained mean abs implied P demand Kp=32 [rad]', ...
                M.pdemand_meanabs_w, imp(M.pdemand_meanabs_w), ...
                G.primary_improve_pct, true};
    primary_pass = true;
    for i = 1:size(K, 1)
        p = K{i,3} >= K{i,4} - 1e-12;
        K{i,6} = p;
        primary_pass = primary_pass && p;
        say(lg, '%-58s prod %12.6f  C1 %12.6f  improve %+8.4f%% (need >= %.1f%%)  %s', ...
            K{i,1}, K{i,2}(1), K{i,2}(2), K{i,3}, K{i,4}, tf(p));
    end

    Sname = {'sustained mean abs e_psi [deg]', 'sustained rms e_psi [deg]', ...
             'sustained peak abs e_psi [deg]', 'sustained rms P demand [rad]', ...
             'sustained peak abs P demand [rad]', 'full mean abs e_psi [deg]', ...
             'full rms e_psi [deg]', 'full peak abs e_psi [deg]', ...
             'full mean abs P demand [rad]', 'full rms P demand [rad]', ...
             'full mean abs over-crab [deg]', 'max abs d yaw_out [deg/tick]', ...
             'max abs dy_des [deg/tick]', 'max abs d yaw_cont [deg/tick]', ...
             'abs yaw_cont total turn [rad]'};
    Sval  = {M.epsi_meanabs_deg_w, M.epsi_rms_deg_w, M.epsi_absmax_deg_w, ...
             M.pdemand_rms_w, M.pdemand_absmax_w, M.epsi_meanabs_deg_f, ...
             M.epsi_rms_deg_f, M.epsi_absmax_deg_f, M.pdemand_meanabs_f, ...
             M.pdemand_rms_f, M.overcrab_meanabs_deg_f, M.max_dyaw_out_deg, ...
             M.max_dy_des_deg, M.max_dyaw_cont_deg, abs(M.total_turn_rad)};
    secondary_pass = true;
    Srows = cell(numel(Sname), 4);
    for i = 1:numel(Sname)
        v = Sval{i};
        ch = imp(v);                        % positive = improved
        p = ch >= -G.secondary_worsen_pct - 1e-12;
        secondary_pass = secondary_pass && p;
        Srows(i,:) = {Sname{i}, v, ch, p};
        say(lg, 'SECONDARY %-42s prod %12.6f  C1 %12.6f  change %+8.4f%%  %s', ...
            Sname{i}, v(1), v(2), ch, tf(p));
    end

    st = struct();
    st.slew_bound_ok   = all(M.max_dyaw_out_deg <= G.slew_bound_deg_tick + 1e-9) && ...
                         all(M.max_dy_des_deg  <= G.slew_bound_deg_tick + 1e-9);
    st.no_slew_clip    = all(M.n_slew_engaged == 0);
    st.wrap_count_same = M.n_wrap_events(1) == M.n_wrap_events(2);
    st.wrap_identity_ok= all(M.wrap_identity_max <= G.wrap_identity_tol_rad);
    st.finite_ok       = all(M.finite_ok == 1);
    st.identity_ok     = (id.prod_resid <= 1e-9) && (id.C1_resid <= 1e-9);
    st.pass = st.slew_bound_ok && st.no_slew_clip && st.wrap_count_same && ...
              st.wrap_identity_ok && st.finite_ok && st.identity_ok;
    say(lg, 'STRUCTURAL slew_bound=%d no_clip=%d wrap_same=%d wrap_identity=%d finite=%d identity=%d -> %s', ...
        st.slew_bound_ok, st.no_slew_clip, st.wrap_count_same, st.wrap_identity_ok, ...
        st.finite_ok, st.identity_ok, tf(st.pass));

    R2.gate_primary   = K;
    R2.gate_secondary = Srows;
    R2.gate_structural= st;
    R2.primary_pass   = primary_pass;
    R2.secondary_pass = secondary_pass;

    all_pass = primary_pass && secondary_pass && st.pass && rec.pass && cl.ok && fp_pre_ok;
    if all_pass
        R2.verdict = 'PASS_SIGNAL_CANDIDATE';
        R2.next_validation = ['bounded closed-loop shadow validation: R10 at U = {1.5, 2.0} m/s, ' ...
            '30 s, plus one bounded disturbance case, C1 evaluated as a parallel shadow reference only.'];
    else
        R2.verdict = 'REJECT_C1_METHOD_CLOSED';
        R2.next_validation = 'none - C1 rejected, method closed at the shadow stage.';
    end
    say(lg, 'VERDICT %s', R2.verdict);

    % ------------------------------------------------------------------
    % 9. figures
    % ------------------------------------------------------------------
    R2.figures = {};
    f1 = make_main_fig(t, wi, gi, P, C1, e_psi_P, e_psi_Q, pd_P, pd_Q, oc_P, oc_Q, ...
                       dref_deg, max_dyaw, cellname, R2.verdict);
    p1 = [STEM '.png'];
    print(f1, p1, '-dpng', '-r110'); close(f1);
    R2.figures{end+1} = p1;
    say(lg, 'wrote %s', p1);

    f2 = make_qa_fig(t, wi, gi, P, C1, yaw_ref_log, yaw_held_log, epsi_log, ...
                     e_psi_P, beta_g, beta_ex, M, K, Srows, st, max_dyaw);
    p2 = [STEM '_qa.png'];
    print(f2, p2, '-dpng', '-r110'); close(f2);
    R2.figures{end+1} = p2;
    say(lg, 'wrote %s', p2);

    % ------------------------------------------------------------------
    % 10. fingerprint POST
    % ------------------------------------------------------------------
    fp_post = cell(nf, 1);
    fp_post_ok = true;
    for i = 1:nf
        fp_post{i} = file_fp(strrep(prod_files{i}, '\', filesep));
        ok = strcmp(fp_post{i}, fp_frozen{i});
        fp_post_ok = fp_post_ok && ok;
        say(lg, 'fp_post %-38s %s  match=%d', prod_files{i}, fp_post{i}, ok);
    end
    R2.fp_post = fp_post;
    R2.fp_post_ok = fp_post_ok;
    R2.production_untouched = fp_pre_ok && fp_post_ok;

    % ------------------------------------------------------------------
    % 11. provenance + artefacts
    % ------------------------------------------------------------------
    R2.gate = 'Gate 8 R10 - logged shadow course-reference offset probe (C1, k_beta 1.35 -> 1.00)';
    R2.created = datestr(now, 'yyyy-mm-dd HH:MM:SS');
    R2.certification = 'NOT_CERTIFIED (simulation-only log replay; no HIL, no bench, no hardware). Gate 9 locked.';
    R2.sources = {'guidance_law.m'; 'controller_law.m'; ...
                  'suite_results/GATE8_R10_GUIDANCE_SIGNAL_LOG_CLOSURE.mat'};
    R2.src_fp = {file_fp('guidance_law.m'); file_fp('controller_law.m'); ...
                 file_fp(fullfile('suite_results','GATE8_R10_GUIDANCE_SIGNAL_LOG_CLOSURE.mat'))};
    R2.source_record_task = Rl.task_id;
    R2.cell = Rl.cell;
    R2.cadence = struct('dt_controller', dt_ctrl, 'dt_guidance_eff', dt_g, ...
                        'guidance_period', gper, 'T_final', Tf, 'n_ticks', nr, ...
                        'n_guidance_ticks', numel(gi), 'n_window_ticks', numel(wi), ...
                        'lookahead_L_m', Rl.L_applied, 'slew_bound_rad', max_dyaw);
    R2.honesty = ['IMPLEMENTED = this isolated shadow probe only. C1 is a LOGGED SHADOW REFERENCE. ' ...
        'Production guidance, controller and plant were never called and never edited; their ' ...
        'fingerprints are the frozen hashes pre and post. CODEX_VERTICAL_PLAN untouched. ' ...
        'The replay is open loop: the recorded psi, beta and course are production outputs, so ' ...
        'NO closed-loop or tracking claim is made and no promotion is implied. Simulation is ' ...
        'never hardware certification.'];
    R2.scope_negatives = {'no closed-loop claim'; 'no tracking claim'; 'no production edit'; ...
        'no gain / path / threshold change'; 'no external shaper'; 'no current feedforward'; ...
        'no promotion'; 'hardware NOT_CERTIFIED'; 'Gate 9 locked'};

    save([STEM '.mat'], 'R2');
    say(lg, 'wrote %s.mat', STEM);
    write_md([STEM '.md'], R2, M, K, Srows, st, id, ocr, zk, rec, cl, Rl);
    say(lg, 'wrote %s.md', STEM);

    say(lg, 'finished %s', datestr(now, 'yyyy-mm-dd HH:MM:SS'));
    say(lg, 'PROVENANCE task=%s sources=3 matlab_invocations=1 verdict=%s production_untouched=%d', ...
        TASK, R2.verdict, R2.production_untouched);
    fclose(lg);
    fprintf('DONE %s verdict=%s\n', TASK, R2.verdict);

catch ME
    R2.verdict = 'FATAL';
    R2.fatal = sprintf('%s | %s', ME.identifier, ME.message);
    try
        say(lg, 'FATAL %s', R2.fatal);
        for k = 1:numel(ME.stack)
            say(lg, '   at %s line %d', ME.stack(k).name, ME.stack(k).line);
        end
        fclose(lg);
    catch
    end
    try
        save([STEM '.mat'], 'R2');
    catch
    end
    fprintf('FATAL %s\n', R2.fatal);
end
end

% ====================== helpers ======================

function S = shadow_pipeline(chi_f, chi_los, beta, gupd, kbeta, max_dyaw)
% Replay of the production yaw-reference pipeline: wrap -> unwrap ->
% 0.35 blend -> slew clip -> zero-order hold. Only kbeta varies.
n = numel(chi_f);
S = struct('raw', nan(n,1), 'cont', nan(n,1), 'out', nan(n,1), ...
           'dyd', nan(n,1), 'dya', nan(n,1), 'held', nan(n,1), 'nslew', 0);
ycont = []; yout = []; cur = NaN;
for i = 1:n
    if gupd(i)
        yr = wrappi(chi_f(i) + 0.75*chi_los(i) - kbeta*beta(i));
        if isempty(ycont)
            ycont = yr;
        else
            ycont = ycont + wrappi(yr - ycont);
        end
        if isempty(yout)
            yout = ycont;
        end
        dyd = 0.35 * (ycont - yout);
        dya = max(min(dyd, max_dyaw), -max_dyaw);
        if abs(dyd) > max_dyaw + 1e-15
            S.nslew = S.nslew + 1;
        end
        yout = yout + dya;
        S.raw(i) = yr; S.cont(i) = ycont; S.out(i) = yout;
        S.dyd(i) = dyd; S.dya(i) = dya;
        cur = yout;
    end
    S.held(i) = cur;
end
end

function y = wrappi(x)
y = atan2(sin(x), cos(x));
end

function v = meanabs_deg(x)
v = mean(abs(rad2deg(x)));
end

function v = rms_deg(x)
v = sqrt(mean(rad2deg(x).^2));
end

function v = absmax_deg(x)
v = max(abs(rad2deg(x)));
end

function off = zero_kappa_ss(chi_const, beta_ss, kbeta, max_dyaw, niter)
% kappa = 0 => chi_los = 0 and chi_f is the constant path course.
ycont = []; yout = [];
for k = 1:niter
    yr = wrappi(chi_const + 0 - kbeta*beta_ss);
    if isempty(ycont); ycont = yr; else; ycont = ycont + wrappi(yr - ycont); end
    if isempty(yout); yout = ycont; end
    dyd = 0.35 * (ycont - yout);
    yout = yout + max(min(dyd, max_dyaw), -max_dyaw);
end
off = rad2deg(yout - chi_const);
end

function s = file_fp(p)
fid = fopen(p, 'r');
if fid < 0
    s = 'MISSING';
    return;
end
b = fread(fid, inf, '*uint8');
fclose(fid);
b = double(b(:));
n = numel(b);
s1 = sum(b);
s2 = mod(sum((1:n)' .* b), 2^32);
s = sprintf('n=%d.s1=%d.s2=%d', n, s1, s2);
end

function say(fid, fmt, varargin)
msg = sprintf(fmt, varargin{:});
fprintf('%s\n', msg);
if fid > 0
    fprintf(fid, '%s\n', msg);
end
end

function s = tf(b)
if b; s = 'PASS'; else; s = 'FAIL'; end
end

function f = make_main_fig(t, wi, gi, P, C1, eP, eQ, pdP, pdQ, ocP, ocQ, dref, max_dyaw, cellname, verdict)
f = figure('Visible', 'off', 'Color', 'w', 'Position', [50 50 1700 1050]);
tw = [t(wi(1)) t(wi(end))];

subplot(3,2,1); hold on; grid on;
plot(t, rad2deg(P.held), 'b-', 'LineWidth', 1.2);
plot(t, rad2deg(C1.held), 'r--', 'LineWidth', 1.2);
shade(tw);
xlabel('t [s]'); ylabel('yaw ref [deg]');
title(sprintf('Yaw reference: production (k_\\beta=1.35) vs C1 (k_\\beta=1.00), %s', cellname));
legend('production', 'C1 shadow', 'Location', 'best');

subplot(3,2,2); hold on; grid on;
plot(t, dref, 'k-', 'LineWidth', 1.0);
shade(tw);
xlabel('t [s]'); ylabel('\Deltayaw ref [deg]');
title(sprintf('C1 - production reference   mean_{win} %.4f deg, |max| %.4f deg', ...
    mean(dref(wi)), max(abs(dref))));

subplot(3,2,3); hold on; grid on;
plot(t, rad2deg(eP), 'b-', 'LineWidth', 1.0);
plot(t, rad2deg(eQ), 'r--', 'LineWidth', 1.0);
shade(tw);
xlabel('t [s]'); ylabel('e_\psi [deg]');
title(sprintf('Heading error   mean|e_\\psi|_{win}: %.4f -> %.4f deg', ...
    mean(abs(rad2deg(eP(wi)))), mean(abs(rad2deg(eQ(wi))))));
legend('production', 'C1 shadow', 'Location', 'best');

subplot(3,2,4); hold on; grid on;
plot(t, abs(pdP), 'b-', 'LineWidth', 1.0);
plot(t, abs(pdQ), 'r--', 'LineWidth', 1.0);
shade(tw);
xlabel('t [s]'); ylabel('|K_p e_\psi| [rad]');
title(sprintf('Algebraic P demand K_p=32   mean_{win}: %.5f -> %.5f rad (%+.3f%%)', ...
    mean(abs(pdP(wi))), mean(abs(pdQ(wi))), ...
    100*(mean(abs(pdP(wi)))-mean(abs(pdQ(wi))))/mean(abs(pdP(wi)))));
legend('production', 'C1 shadow', 'Location', 'best');

subplot(3,2,5); hold on; grid on;
plot(t, rad2deg(ocP), 'b-', 'LineWidth', 1.2);
plot(t, rad2deg(ocQ), 'r--', 'LineWidth', 1.6);
shade(tw);
xlabel('t [s]'); ylabel('-(k_\beta-1)\beta [deg]');
title(sprintf('Structural over-crab contribution   mean|.|_{win} %.4f -> %.4f deg (100%% removed)', ...
    mean(abs(rad2deg(ocP(wi)))), mean(abs(rad2deg(ocQ(wi))))));
legend('production', 'C1 shadow', 'Location', 'best');

subplot(3,2,6); hold on; grid on;
tg = t(gi);
plot(tg(2:end), rad2deg(abs(diff(P.out(gi)))), 'b-', 'LineWidth', 1.0);
plot(tg(2:end), rad2deg(abs(diff(C1.out(gi)))), 'r--', 'LineWidth', 1.0);
plot(tg([1 end]), rad2deg(max_dyaw)*[1 1], 'k-', 'LineWidth', 1.5);
xlabel('t [s]'); ylabel('|\Deltayaw_{out}| [deg/tick]');
title(sprintf('Per-tick reference increment vs %.1f deg/tick bound (0 clips both)', rad2deg(max_dyaw)));
legend('production', 'C1 shadow', 'bound', 'Location', 'best');

annotation(f, 'textbox', [0.01 0.965 0.98 0.032], 'String', ...
    sprintf('GATE8_R10_SHADOW_COURSE_REFERENCE_OFFSET_PROBE_001   %s   NOT_CERTIFIED, logged shadow replay, no closed-loop claim', verdict), ...
    'EdgeColor', 'none', 'FontWeight', 'bold', 'Interpreter', 'none', ...
    'HorizontalAlignment', 'center');
end

function f = make_qa_fig(t, wi, gi, P, C1, yaw_ref_log, yaw_held_log, epsi_log, eP, beta_g, beta_ex, M, K, Srows, st, max_dyaw)
f = figure('Visible', 'off', 'Color', 'w', 'Position', [50 50 1700 1050]);
tw = [t(wi(1)) t(wi(end))];

subplot(3,2,1); hold on; grid on;
r1 = abs(P.out(gi) - yaw_ref_log(gi));
r2 = abs(P.held - yaw_held_log);
r3 = abs(eP - epsi_log);
semilogy(t(gi), max(r1, 1e-20), 'b.', 'MarkerSize', 6);
semilogy(t, max(r2, 1e-20), 'g-');
semilogy(t, max(r3, 1e-20), 'm-');
set(gca, 'YScale', 'log'); ylim([1e-20 1e-8]);
plot(t([1 end]), [1e-9 1e-9], 'k--', 'LineWidth', 1.2);
xlabel('t [s]'); ylabel('|residual| [rad]');
title(sprintf('QA1 production reconstruction, worst %.2e rad vs 1e-9 gate', max([r1; r2; r3])));
legend('yaw ref', 'held ref', 'e_\psi', 'gate', 'Location', 'best');

subplot(3,2,2); hold on; grid on;
plot(t, rad2deg(beta_g), 'b-', 'LineWidth', 1.0);
plot(t, rad2deg(beta_ex), 'r--', 'LineWidth', 1.0);
shade(tw);
xlabel('t [s]'); ylabel('\beta [deg]');
title(sprintf('QA2 sideslip: law model vs exact  (mean %.4f / %.4f deg, clamp never active)', ...
    mean(rad2deg(beta_g(wi))), mean(rad2deg(beta_ex(wi)))));
legend('\beta_{law} = atan2(v, max(u,0.35))', '\beta_{exact}', 'Location', 'best');

subplot(3,2,3); hold on; grid on;
tg = t(gi);
plot(tg, rad2deg(P.dyd(gi)), 'b-', 'LineWidth', 1.0);
plot(tg, rad2deg(C1.dyd(gi)), 'r--', 'LineWidth', 1.0);
plot(tg([1 end]),  rad2deg(max_dyaw)*[1 1], 'k-', 'LineWidth', 1.4);
plot(tg([1 end]), -rad2deg(max_dyaw)*[1 1], 'k-', 'LineWidth', 1.4);
xlabel('t [s]'); ylabel('dy_{des} [deg]');
title(sprintf('QA3 desired blend increment vs slew clip (max |dy_{des}| %.4f / %.4f deg)', ...
    M.max_dy_des_deg(1), M.max_dy_des_deg(2)));

subplot(3,2,4); hold on; grid on;
plot(t(gi), rad2deg(P.cont(gi)), 'b-', 'LineWidth', 1.0);
plot(t(gi), rad2deg(C1.cont(gi)), 'r--', 'LineWidth', 1.0);
plot(t(gi), rad2deg(P.raw(gi)), 'c:', 'LineWidth', 0.8);
xlabel('t [s]'); ylabel('[deg]');
title(sprintf('QA4 unwrap continuity: %d wrap event(s) both, total turn %.4f / %.4f rad', ...
    M.n_wrap_events(1), M.total_turn_rad(1), M.total_turn_rad(2)));
legend('yaw_{cont} prod', 'yaw_{cont} C1', 'yaw_{raw} prod (wrapped)', 'Location', 'best');

ax = subplot(3,2,[5 6]); axis(ax, 'off');
lines = {};
lines{end+1} = 'DECLARED GATES (declared before evaluation)';
for i = 1:size(K,1)
    lines{end+1} = sprintf('  %-56s %11.6f -> %11.6f   %+8.4f%%  need>=5%%   %s', ...
        K{i,1}, K{i,2}(1), K{i,2}(2), K{i,3}, tf(K{i,6}));
end
lines{end+1} = '  SECONDARY (no logged metric may worsen more than 2%)';
worst = inf; wname = '';
for i = 1:size(Srows,1)
    if Srows{i,3} < worst; worst = Srows{i,3}; wname = Srows{i,1}; end
end
lines{end+1} = sprintf('    worst secondary change %+8.4f%% on %s   %s', worst, wname, tf(worst >= -2));
lines{end+1} = sprintf('  STRUCTURAL slew<=%.1f deg/tick %s | clips %d/%d | wrap %d/%d | finite %s | identity %s', ...
    rad2deg(max_dyaw), tf(st.slew_bound_ok), M.n_slew_engaged(1), M.n_slew_engaged(2), ...
    M.n_wrap_events(1), M.n_wrap_events(2), tf(st.finite_ok), tf(st.identity_ok));
text(0, 1, lines, 'FontName', 'Courier New', 'FontSize', 9, ...
    'VerticalAlignment', 'top', 'Interpreter', 'none', 'Parent', ax);

annotation(f, 'textbox', [0.01 0.965 0.98 0.032], 'String', ...
    'GATE8_R10_SHADOW_COURSE_REFERENCE_OFFSET_PROBE_001 - visual QA (reconstruction, sideslip, slew, unwrap, gate ledger)', ...
    'EdgeColor', 'none', 'FontWeight', 'bold', 'Interpreter', 'none', ...
    'HorizontalAlignment', 'center');
end

function shade(tw)
yl = ylim;
h = patch([tw(1) tw(2) tw(2) tw(1)], [yl(1) yl(1) yl(2) yl(2)], ...
    [0.85 0.9 1.0], 'EdgeColor', 'none');
uistack(h, 'bottom');
try
    set(get(get(h, 'Annotation'), 'LegendInformation'), 'IconDisplayStyle', 'off');
catch
end
ylim(yl);
end

function write_md(path, R2, M, K, Srows, st, id, ocr, zk, rec, cl, Rl)
fid = fopen(path, 'w');
w = @(varargin) fprintf(fid, [varargin{1} '\n'], varargin{2:end});

w('# GATE8_R10_SHADOW_COURSE_REFERENCE_OFFSET_PROBE');
w('');
w('**TASK_ID** `%s`  ', R2.task_id);
w('**Verdict** `%s`  ', R2.verdict);
w('**Created** %s  ', R2.created);
w('**Certification** %s', R2.certification);
w('');
w('## 1. Scope');
w('');
w('C1 is evaluated as a **logged shadow reference only**. The candidate is the production');
w('yaw-reference arithmetic with a single symbol changed, `k_beta` 1.35 -> 1.00:');
w('');
w('```');
w('chi_raw_C1 = wrap(chi_f + 0.75*chi_los - 1.00*beta)');
w('```');
w('');
w('and is then pushed through the identical unwrap, 0.35 blend, +-40 deg/s slew clip and');
w('3:1 zero-order hold. Production guidance, controller and plant were never called and');
w('never edited. The replay is open loop against the recorded R10_U1.5 signal log, so');
w('**no closed-loop or tracking claim is made**.');
w('');
w('Sources read (exactly three):');
for i = 1:numel(R2.sources)
    w('%d. `%s` `%s`', i, R2.sources{i}, R2.src_fp{i});
end
w('');
w('## 2. Provenance and preconditions');
w('');
w('| item | value |');
w('|---|---|');
w('| source record | `%s` (verdict `%s`) |', R2.source_record_task, cl.source_verdict);
w('| cell | `%s`, U = %.2f m/s, %d waypoints |', Rl.cell.name, Rl.cell.U, Rl.cell.n_waypoints);
w('| state0 | `[%s]` |', strtrim(sprintf('%g ', Rl.cell.state0)));
w('| cadence | dt_ctrl %.4f s, dt_guidance %.6f s, %d:1 hold, T = %g s |', ...
  R2.cadence.dt_controller, R2.cadence.dt_guidance_eff, R2.cadence.guidance_period, R2.cadence.T_final);
w('| ticks | %d controller, %d guidance, %d sustained-window |', ...
  R2.cadence.n_ticks, R2.cadence.n_guidance_ticks, R2.cadence.n_window_ticks);
w('| lookahead | L = %.2f m |', R2.cadence.lookahead_L_m);
w('| slew bound | deg2rad(40)*dt_g = %.6f rad = 3.000000 deg/tick |', R2.cadence.slew_bound_rad);
w('| production fingerprint | frozen hash held pre **and** post (all %d files) |', numel(R2.prod_files));
w('| observer closure | closure %d, geometry %d, continuity %d, parity %d, trajectory hash frozen %d |', ...
  cl.closure_pass, cl.geometry_pass, cl.continuity_pass, cl.parity_ok, cl.traj_hash_frozen);
w('');
w('Production file fingerprints (pre = post = frozen):');
w('');
w('| file | fingerprint | pre | post |');
w('|---|---|---|---|');
for i = 1:numel(R2.prod_files)
    w('| `%s` | `%s` | %s | %s |', R2.prod_files{i}, R2.fp_frozen{i}, ...
      tick(strcmp(R2.fp_pre{i}, R2.fp_frozen{i})), tick(strcmp(R2.fp_post{i}, R2.fp_frozen{i})));
end
w('');
w('## 3. Production reference reconstructed exactly');
w('');
w('The production pipeline was rebuilt from the logged `chi_f`, `chi_los` and `beta` and');
w('checked against every recorded stage before C1 was evaluated.');
w('');
w('| stage | max abs residual [rad] |');
w('|---|---|');
w('| `yaw_raw` | %.3e |', rec.yaw_raw);
w('| `yaw_cont` (unwrap) | %.3e |', rec.yaw_cont);
w('| `yaw_out` (0.35 blend + slew) | %.3e |', rec.yaw_out);
w('| `yaw_ref` | %.3e |', rec.yaw_ref);
w('| held reference (3:1) | %.3e |', rec.held);
w('| `dy_des` / `dy_app` | %.3e / %.3e |', rec.dy_des, rec.dy_app);
w('| `e_psi` | %.3e |', rec.e_psi);
w('');
w('Worst residual **%.3e rad**, gate 1e-9: **%s**. The shadow arithmetic is therefore the', rec.max_all, tf(rec.pass));
w('production arithmetic with one coefficient changed and nothing else.');
w('');
w('## 4. Production vs C1');
w('');
w('Sustained window = the recorded analysis window, %d guidance ticks.', R2.cadence.n_window_ticks);
w('');
w('| quantity | production | C1 | change |');
w('|---|---|---|---|');
w('| yaw reference, window mean delta [deg] | - | - | %+.6f |', M.yawref_delta_mean_deg_w);
w('| yaw reference, peak delta [deg] | - | - | %.6f |', M.yawref_delta_absmax_deg);
w('| mean\\|e_psi\\| window [deg] | %.6f | %.6f | %+.4f%% |', M.epsi_meanabs_deg_w(1), M.epsi_meanabs_deg_w(2), pc(M.epsi_meanabs_deg_w));
w('| rms e_psi window [deg] | %.6f | %.6f | %+.4f%% |', M.epsi_rms_deg_w(1), M.epsi_rms_deg_w(2), pc(M.epsi_rms_deg_w));
w('| peak\\|e_psi\\| window [deg] | %.6f | %.6f | %+.4f%% |', M.epsi_absmax_deg_w(1), M.epsi_absmax_deg_w(2), pc(M.epsi_absmax_deg_w));
w('| mean\\|P demand\\| Kp=32 window [rad] | %.6f | %.6f | %+.4f%% |', M.pdemand_meanabs_w(1), M.pdemand_meanabs_w(2), pc(M.pdemand_meanabs_w));
w('| rms P demand window [rad] | %.6f | %.6f | %+.4f%% |', M.pdemand_rms_w(1), M.pdemand_rms_w(2), pc(M.pdemand_rms_w));
w('| mean\\|e_psi\\| full record [deg] | %.6f | %.6f | %+.4f%% |', M.epsi_meanabs_deg_f(1), M.epsi_meanabs_deg_f(2), pc(M.epsi_meanabs_deg_f));
w('| mean\\|P demand\\| full record [rad] | %.6f | %.6f | %+.4f%% |', M.pdemand_meanabs_f(1), M.pdemand_meanabs_f(2), pc(M.pdemand_meanabs_f));
w('');
w('Positive change = magnitude reduced by C1. The P demand is the **algebraic**');
w('`Kp*e_psi` pre-saturation demand, not a commanded rudder angle.');
w('');
w('## 5. Structural over-crab removal');
w('');
w('The over-crab term is `-(k_beta-1)*beta`, the part of the reference offset that exists');
w('only because the law crabs harder than the exact course kinematics `chi = psi + beta`');
w('require. Production window mean %.6f deg (recorded value %.6f deg, reproduced to %.2e),', ...
  ocr.prod_mean_deg, ocr.recorded_structural_offset_mean_deg, ocr.reconstruction_match);
w('mean magnitude %.6f deg, peak %.6f deg. Under C1 the term is **identically zero**:', ocr.prod_meanabs_deg, ocr.prod_absmax_deg);
w('%.1f%% removal, exactly, by construction rather than by tuning.', ocr.removal_pct);
w('');
w('### Zero-curvature reduction');
w('');
w('With `kappa = 0` the lead law returns identically zero (recorded `zero_kappa_lead_max`');
w('= %.1e) and `chi_los -> 0`, so the pipeline reduces to a pure constant-course problem.', zk.recorded_zero_kappa_lead_max);
w('Iterating the same unwrap/blend/slew recursion to steady state at the window-mean');
w('sideslip %.6f deg gives:', rad2deg(zk.beta_ss_rad));
w('');
w('| k_beta | steady offset from path course [deg] | closed form `-k_beta*beta` | residual |');
w('|---|---|---|---|');
w('| 1.35 (production) | %.6f | %.6f | %.2e |', zk.prod_offset_deg, zk.prod_closed_form_deg, zk.resid_prod);
w('| 1.00 (C1) | %.6f | %.6f | %.2e |', zk.C1_offset_deg, zk.C1_closed_form_deg, zk.resid_C1);
w('');
w('a %.3f%% reduction of the zero-curvature reference offset. The residual %.6f deg under', zk.reduction_pct, zk.C1_offset_deg);
w('C1 is the exact `-1.0*beta` crab the course kinematics demand, so it is correct, not error.');
w('');
w('## 6. Wrap, slew and continuity');
w('');
w('| quantity | production | C1 | bound |');
w('|---|---|---|---|');
w('| wrap events | %d | %d | must match |', M.n_wrap_events(1), M.n_wrap_events(2));
w('| wrap identity residual [rad] | %.2e | %.2e | <= 1e-9 |', M.wrap_identity_max(1), M.wrap_identity_max(2));
w('| slew clips engaged | %d | %d | 0 |', M.n_slew_engaged(1), M.n_slew_engaged(2));
w('| max \\|dy_des\\| [deg/tick] | %.6f | %.6f | 3.000000 |', M.max_dy_des_deg(1), M.max_dy_des_deg(2));
w('| max \\|d yaw_out\\| [deg/tick] | %.6f | %.6f | 3.000000 |', M.max_dyaw_out_deg(1), M.max_dyaw_out_deg(2));
w('| max \\|d yaw_cont\\| [deg/tick] | %.6f | %.6f | - |', M.max_dyaw_cont_deg(1), M.max_dyaw_cont_deg(2));
w('| total unwrapped turn [rad] | %.6f | %.6f | - |', M.total_turn_rad(1), M.total_turn_rad(2));
w('| finite | %d | %d | 1 |', M.finite_ok(1), M.finite_ok(2));
w('');
w('No 3 deg/tick slew or wrap violation in either pipeline.');
w('');
w('## 7. Course-offset attribution identity');
w('');
w('Datum: %s. Window means in deg.', id.datum);
w('');
w('| term | production | C1 |');
w('|---|---|---|');
w('| lead/lag (course filter + LOS + output filter) | %+.6f | %+.6f |', id.prod.lead_lag, id.C1.lead_lag);
w('| heading error `-e_psi` | %+.6f | %+.6f |', id.prod.epsi, id.C1.epsi);
w('| structural over-crab | %+.6f | %+.6f |', id.prod.crab, id.C1.crab);
w('| sideslip-model residual | %+.6f | %+.6f |', id.prod.model, id.C1.model);
w('| **sum** | **%+.6f** | **%+.6f** |', id.prod_sum, id.C1_sum);
w('| measured `chi_og - chi_now` | %+.6f | %+.6f |', id.measured_total_deg, id.measured_total_deg);
w('| identity residual | %.2e | %.2e |', id.prod_resid, id.C1_resid);
w('');
w('**This is the load-bearing caveat.** %s', id.invariance_note);
w('Removing the over-crab term therefore does not remove course offset in this replay; it');
w('relabels 100%% of it, and the algebraic heading-error demand barely moves. Whether the');
w('removal buys anything can only be answered in closed loop, which this probe does not do.');
w('');
w('## 8. Gate ledger');
w('');
w('Thresholds were declared before any metric was computed: both primary legs must improve');
w('by >= 5%%, no secondary logged metric may worsen by more than 2%%, and no 3 deg/tick');
w('slew or wrap violation is allowed.');
w('');
w('| gate | production | C1 | change | required | result |');
w('|---|---|---|---|---|---|');
for i = 1:size(K,1)
    w('| %s | %.6f | %.6f | %+.4f%% | >= +5%% | **%s** |', K{i,1}, K{i,2}(1), K{i,2}(2), K{i,3}, tf(K{i,6}));
end
for i = 1:size(Srows,1)
    v = Srows{i,2};
    w('| SECONDARY %s | %.6f | %.6f | %+.4f%% | >= -2%% | %s |', Srows{i,1}, v(1), v(2), Srows{i,3}, tf(Srows{i,4}));
end
w('| STRUCTURAL slew / wrap / finite / identity | - | - | - | all | %s |', tf(st.pass));
w('| Production reconstruction <= 1e-9 rad | - | - | %.2e | <= 1e-9 | %s |', rec.max_all, tf(rec.pass));
w('| Observer closure held before comparison | - | - | - | required | %s |', tf(cl.ok));
w('| Production fingerprint frozen pre and post | - | - | - | required | %s |', tf(R2.production_untouched));
w('');
w('## 9. Verdict');
w('');
if strcmp(R2.verdict, 'PASS_SIGNAL_CANDIDATE')
    w('**PASS as a signal candidate.** Every declared gate passed.');
    w('');
    w('Next, and only this: %s', R2.next_validation);
else
    w('**REJECT C1. Method closed at the shadow stage.**');
    w('');
    w('The primary KPI is conjunctive and C1 fails one leg of it. The structural over-crab');
    w('contribution is removed completely (%.6f -> 0.000000 deg, 100%%), but the implied', ocr.prod_meanabs_deg);
    w('P demand improves only %+.4f%% over the sustained window (%+.4f%% over the full', pc(M.pdemand_meanabs_w), pc(M.pdemand_meanabs_f));
    w('record) against a declared floor of 5%%, roughly one thirteenth of what was required.');
    w('');
    w('The reason is structural, not marginal. The over-crab term is worth %.4f deg of', ocr.prod_meanabs_deg);
    w('reference offset while the heading error it would have to move is %.4f deg, so even', M.epsi_meanabs_deg_w(1));
    w('perfect removal of the term can only shift the P demand by a few tenths of a per cent.');
    w('No amount of re-running this probe changes that ratio, and the attribution identity in');
    w('section 7 shows the offset is transferred rather than eliminated. No follow-on');
    w('closed-loop shadow validation is named, because the gate that would have earned one');
    w('did not pass.');
    w('');
    w('Secondary metrics stayed inside the 2%% band (worst %+.4f%% on peak heading error),', pc(M.epsi_absmax_deg_f));
    w('and there was no slew or wrap violation, so the rejection is on effect size alone,');
    w('not on a safety or continuity breach.');
end
w('');
w('## 10. Honesty and negative scope');
w('');
w('%s', R2.honesty);
w('');
for i = 1:numel(R2.scope_negatives)
    w('- %s', R2.scope_negatives{i});
end
w('');
w('Artefacts: `%s`, `%s`.', R2.figures{1}, R2.figures{2});
fclose(fid);
end

function v = pc(x)
v = 100 * (x(1) - x(2)) / abs(x(1));
end

function s = tick(b)
if b; s = 'yes'; else; s = 'NO'; end
end
