function run_trim_alpha_transient_gate_audit()
% TRIM_ALPHA_TRANSIENT_GATE_AUDIT_001 — read-only raw-metric gate audit.
% Inputs (only): TRIM_ALPHA_FF_RATE_LIMIT.mat, TRIM_ALPHA_FF_BENCHMARK.mat,
%   PITCH_FLIGHTPATH_SEMANTICS_AUDIT.mat. One invocation; no sim / no prod edit.
% Recomputes P/A04/AFF/RL acquisition gates from raw series with true
%   e_gamma=gamma_ref-gamma_act, separate attitude error, persistent settling.
% Classifies METRIC_BUG | TRUE_TRANSIENT | UNKNOWN. Audit PASS does not promote.
% Artifacts: suite_results/TRIM_ALPHA_TRANSIENT_GATE_AUDIT.{md,mat,png}
% Appends STATE_SPACE_MODEL_AUDIT.md.

    project_dir = fileparts(fileparts(fileparts(mfilename('fullpath')))); % repo root
    addpath(genpath(fullfile(project_dir, 'matlab')));
    out_dir = fullfile(project_dir, 'suite_results');
    if ~exist(out_dir, 'dir'); mkdir(out_dir); end
    tag = 'TRIM_ALPHA_TRANSIENT_GATE_AUDIT';
    task_id = 'TRIM_ALPHA_TRANSIENT_GATE_AUDIT_001';

    rl_path   = fullfile(out_dir, 'TRIM_ALPHA_FF_RATE_LIMIT.mat');
    aff_path  = fullfile(out_dir, 'TRIM_ALPHA_FF_BENCHMARK.mat');
    sem_path  = fullfile(out_dir, 'PITCH_FLIGHTPATH_SEMANTICS_AUDIT.mat');
    assert(exist(rl_path, 'file') == 2, 'Missing %s', rl_path);
    assert(exist(aff_path, 'file') == 2, 'Missing %s', aff_path);
    assert(exist(sem_path, 'file') == 2, 'Missing %s', sem_path);

    RL = load(rl_path);
    AFFB = load(aff_path);
    Sem = load(sem_path);

    fprintf('\n========== %s ==========\n', task_id);
    fprintf('Read-only: TRIM_ALPHA_FF_RATE_LIMIT | TRIM_ALPHA_FF_BENCHMARK | PITCH_FLIGHTPATH_SEMANTICS_AUDIT\n');
    fprintf('Post-process only | no simulation | production untouched\n');

    % ---- Definitions (from semantics audit + explicit band) ----
    band_deg = 0.5;          % persistent settle band (stated)
    end_frac = 0.88;
    abs_eps_rate = 1e-6;     % absolute tol for near-zero rates
    abs_eps_ang = 1e-3;      % absolute tol for near-zero settle/OS [s or deg]
    abs_eps_pct = 0.05;      % absolute tol for near-zero sat %%
    valid_min = 0.95;

    defs = struct();
    defs.e_gamma = 'e_gamma = wrapToPi(gamma_ref - gamma_act); gamma_act=atan2(VD,Uh); gamma_ref=atan2(tz,||txy||)';
    defs.e_theta_att = 'e_theta_att = wrapToPi(theta_ref - theta_phys); attitude tracker error (legacy)';
    defs.e_theta_req = 'e_theta_req = wrapToPi((gamma_ref-alpha) - theta_phys); required-attitude error';
    defs.settle = sprintf(['persistent: earliest t_k s.t. |e|<=+/-%.2f deg for all samples ', ...
        'with s < %.2f*s_total from k..n_end (enter band and remain)'], band_deg, end_frac);
    defs.overshoot = 'OS = max(0, signed excursion of signal past mean(ref|steady)) during acq [deg]';
    defs.dip = 'initial_dip = max(0, opposite excursion vs final ref during first acq third) [deg]';
    defs.rise = 't10_90 = time for signal to traverse 10%%→90%% of (final_ref - start) [s]; lag=first enter band';
    defs.prior_bug = ['PRIOR RATE_LIMIT/AFF: settle/OS from compute_pitch_window_metrics(e_theta_att); ', ...
        'OS:=acq |e_theta| peak — mixes legacy attitude with gamma gates'];
    defs.band_deg = band_deg;
    defs.end_frac = end_frac;
    defs.semantics_task = '';
    if isfield(Sem, 'task_id'); defs.semantics_task = Sem.task_id; end

    % Paths (identical to prior AFF/RL drivers)
    nX = 600; xX = linspace(0, 45, nX)';
    pathX = [xX, zeros(nX, 1), zeros(nX, 1)];
    nXZ = 900; xXZ = linspace(0, 42, nXZ)';
    pathXZ = [xXZ, zeros(nXZ, 1), 0.4 * xXZ];
    pathH = generate_balanced_helical_path(10.0, 2.0, 2, 500);
    paths = struct('X', pathX, 'XZ', pathXZ, 'H', pathH);
    routes = {'X', 'XZ', 'H'};
    labels = struct('X', 'X', 'XZ', 'XZ', 'H', 'R10');
    % Prior win modes (for bug evidence only); audit uses persistent for all
    prior_win = struct('X', 'first_hold', 'XZ', 'persistent', 'H', 'persistent');

    variants = { ...
        struct('key', 'P',   'src', 'production',               'label', 'P'); ...
        struct('key', 'A04', 'src', 'measured_A04',             'label', 'A04'); ...
        struct('key', 'AFF', 'src', 'trim_alpha_ff',            'label', 'AFF'); ...
        struct('key', 'RL',  'src', 'trim_alpha_ff_rate_limit', 'label', 'RL')};

    Raw = struct();
    for iv = 1:numel(variants)
        v = variants{iv};
        assert(isfield(RL, v.src), 'RATE_LIMIT missing %s', v.src);
        for ir = 1:numel(routes)
            nm = routes{ir};
            S = RL.(v.src).(nm).S;
            Mprior = RL.(v.src).(nm).M;
            R = analyze_raw(S, paths.(nm), band_deg, end_frac, prior_win.(nm), Mprior);
            R.variant = v.label;
            R.route = labels.(nm);
            R.src_field = v.src;
            Raw.(v.key).(nm) = R;
            fprintf('  [%s/%s] γ_set=%.3fs θ_set=%.3fs γOS=%.3f° priorOS=%.3f° deR_ss=%.4g→corr %.4g valid=%.1f%%\n', ...
                v.label, labels.(nm), R.gamma.settling_s, R.theta_att.settling_s, ...
                R.gamma.overshoot_deg, R.prior.overshoot_deg, ...
                R.prior.de_rate_rms, R.act.steady.de_rate_rms, 100 * R.valid_frac);
        end
    end

    % Cross-check: AFF series identity vs BENCHMARK mat
    xcheck = struct();
    xcheck.aff_match = true;
    xcheck.notes = {};
    for ir = 1:numel(routes)
        nm = routes{ir};
        S_rl = RL.trim_alpha_ff.(nm).S;
        S_b  = AFFB.trim_alpha_ff.(nm).S;
        n = min(numel(S_rl.t), numel(S_b.t));
        d_th = max(abs(S_rl.theta_ref(1:n) - S_b.theta_ref(1:n)));
        d_de = max(abs(S_rl.delta_e(1:n) - S_b.delta_e(1:n)));
        ok = (d_th < 1e-9) && (d_de < 1e-9);
        xcheck.aff_match = xcheck.aff_match && ok;
        xcheck.notes{end+1} = sprintf('%s d_th=%.3e d_de=%.3e ok=%d', labels.(nm), d_th, d_de, ok); %#ok<AGROW>
    end

    [G, class_id, evidence, next_opt, next_detail, corrected] = ...
        score_and_classify(Raw, RL, band_deg, abs_eps_rate, abs_eps_ang, abs_eps_pct, valid_min, xcheck);

    verdict = tern(G.audit_pass, 'PASS', 'FAIL');

    md_path  = fullfile(out_dir, [tag '.md']);
    mat_path = fullfile(out_dir, [tag '.mat']);
    png_path = fullfile(out_dir, [tag '.png']);

    write_png(png_path, Raw, task_id, verdict, class_id, band_deg);
    write_md(md_path, task_id, verdict, class_id, defs, Raw, G, corrected, evidence, ...
        next_opt, next_detail, rl_path, aff_path, sem_path, md_path, mat_path, png_path, xcheck);
    append_ss_audit(out_dir, task_id, verdict, class_id, defs, Raw, G, corrected, ...
        evidence, next_opt, next_detail, md_path, mat_path, png_path);

    Out = struct();
    Out.task_id = task_id;
    Out.verdict = verdict;
    Out.class = class_id;
    Out.defs = defs;
    Out.raw = Raw;
    Out.gates = G;
    Out.corrected = corrected;
    Out.evidence = evidence;
    Out.next_opt = next_opt;
    Out.next_detail = next_detail;
    Out.xcheck = xcheck;
    Out.sources = {rl_path; aff_path; sem_path};
    Out.paths = struct('md', md_path, 'mat', mat_path, 'png', png_path);
    Out.production_edited = false;
    Out.note = ['Read-only recompute of acquisition gates from raw series; ', ...
        'audit PASS does not promote controller'];
    save(mat_path, '-struct', 'Out');

    fprintf('\nVERDICT: %s | class=%s | next=%s\n', verdict, class_id, next_opt);
    fprintf('Saved: %s\n%s\n%s\n', md_path, mat_path, png_path);
    print_feedback(verdict, class_id, corrected, evidence, next_opt, next_detail, ...
        md_path, mat_path, png_path, G);
    assignin('base', 'TRIM_ALPHA_TRANSIENT_GATE_AUDIT_PASS', strcmp(verdict, 'PASS'));
end

%% ===================== raw analysis =====================
function R = analyze_raw(S, path, band_deg, end_frac, prior_win_mode, Mprior)
    t = S.t(:); dt = S.dt;
    phi = S.ori(:, 1); theta = S.ori(:, 2); psi = S.ori(:, 3);
    theta_phys = -theta;
    u = S.u_body(:); v = S.v_body(:); w = S.w_body(:);
    de = S.delta_e(:); dr = S.delta_r(:);
    theta_ref = S.theta_ref(:);

    [VN, VE, VD, Uh] = ned_velocity(phi, theta, psi, u, v, w); %#ok<ASGLU>
    gamma_act = atan2(VD, max(Uh, 1e-9));
    alpha = atan2(w, u);
    [gamma_ref, cte_perp, s_prog, s_total] = path_gamma_cte(path, S.vp); %#ok<ASGLU>
    theta_cmd = wrapToPi(gamma_ref - alpha);

    e_gamma = wrapToPi(gamma_ref - gamma_act);
    e_th_att = wrapToPi(theta_ref - theta_phys);
    e_th_req = wrapToPi(theta_cmd - theta_phys);

    % Persistent settle on true gamma AND separately on attitude
    Wg = compute_pitch_window_metrics(t, e_gamma, s_prog, s_total, ...
        'mode', 'persistent', 'band_deg', band_deg, 'end_frac', end_frac);
    Wa = compute_pitch_window_metrics(t, e_th_att, s_prog, s_total, ...
        'mode', 'persistent', 'band_deg', band_deg, 'end_frac', end_frac);
    Wr = compute_pitch_window_metrics(t, e_th_req, s_prog, s_total, ...
        'mode', 'persistent', 'band_deg', band_deg, 'end_frac', end_frac);

    % Prior-style window (legacy e_theta + prior mode) for bug evidence
    Wp = compute_pitch_window_metrics(t, e_th_att, s_prog, s_total, ...
        'mode', prior_win_mode, 'band_deg', band_deg, 'end_frac', end_frac);

    mask_before = Wg.mask_before_end;
    n_valid = nnz(mask_before);
    n_finite = nnz(mask_before & isfinite(e_gamma) & isfinite(gamma_act) & isfinite(de));
    valid_frac = n_finite / max(n_valid, 1);

    % Acquisition / steady from gamma persistent windows (fallback t<5 / t>=5)
    mask_acq = Wg.mask_acq;
    mask_ss  = Wg.mask_steady;
    if ~any(mask_acq); mask_acq = (t < 5.0) & mask_before; end
    if ~any(mask_ss);  mask_ss  = (t >= 5.0) & mask_before; end

    de_dot = [0; diff(de)] / dt;
    dr_dot = [0; diff(dr)] / dt;

    R = struct();
    R.t = t; R.dt = dt;
    R.gamma_ref = gamma_ref; R.gamma_act = gamma_act; R.e_gamma = e_gamma;
    R.theta_ref = theta_ref; R.theta_phys = theta_phys; R.theta_cmd = theta_cmd;
    R.e_th_att = e_th_att; R.e_th_req = e_th_req; R.alpha = alpha;
    R.de = de; R.dr = dr; R.de_dot = de_dot; R.dr_dot = dr_dot;
    R.s_prog = s_prog; R.s_total = s_total;
    R.mask_acq = mask_acq; R.mask_ss = mask_ss; R.mask_before = mask_before;
    R.valid_frac = valid_frac; R.band_deg = band_deg; R.end_frac = end_frac;
    R.Wg = Wg; R.Wa = Wa; R.Wr = Wr; R.Wp = Wp;

    % Alpha target / cmd (if present)
    if isfield(S, 'alpha_ff_target')
        R.alpha_target = S.alpha_ff_target(:);
    elseif isfield(S, 'alpha_hat')
        R.alpha_target = S.alpha_hat(:);
    else
        R.alpha_target = zeros(size(t));
    end
    if isfield(S, 'alpha_cmd')
        R.alpha_cmd = S.alpha_cmd(:);
    elseif isfield(S, 'alpha_hat')
        R.alpha_cmd = S.alpha_hat(:);
    else
        R.alpha_cmd = zeros(size(t));
    end

    R.gamma = pack_error_channel(t, gamma_act, gamma_ref, e_gamma, Wg, mask_acq, mask_ss, band_deg);
    R.theta_att = pack_error_channel(t, theta_phys, theta_ref, e_th_att, Wa, Wa.mask_acq, Wa.mask_steady, band_deg);
    R.theta_req = pack_error_channel(t, theta_phys, theta_cmd, e_th_req, Wr, Wr.mask_acq, Wr.mask_steady, band_deg);

    % Actuators on gamma-derived windows
    R.act = struct();
    R.act.acq = act_pack(de, dr, de_dot, dr_dot, mask_acq);
    R.act.steady = act_pack(de, dr, de_dot, dr_dot, mask_ss);
    % Also on prior legacy windows (bug evidence)
    R.act_prior_win = struct();
    R.act_prior_win.acq = act_pack(de, dr, de_dot, dr_dot, Wp.mask_acq);
    R.act_prior_win.steady = act_pack(de, dr, de_dot, dr_dot, Wp.mask_steady);

    % Prior reported (from RATE_LIMIT M)
    R.prior = struct();
    R.prior.settling_s = Mprior.settle.settling_s;
    R.prior.overshoot_deg = Mprior.settle.overshoot_deg;
    R.prior.de_rate_rms = Mprior.act.de_rate_rms;
    R.prior.dr_rate_rms = Mprior.act.dr_rate_rms;
    R.prior.de_rate_acq = Mprior.act.de_rate_acq;
    R.prior.dr_rate_acq = Mprior.act.dr_rate_acq;
    R.prior.gamma_mae = Mprior.gamma.mae_deg;
    R.prior.win_mode = prior_win_mode;
    R.prior.os_is_eth_peak = true;
    R.prior.settle_from_eth = true;

    % Mismatch diagnostics
    R.bug = struct();
    R.bug.settle_gamma_vs_prior = R.gamma.settling_s - R.prior.settling_s;
    R.bug.settle_att_vs_prior = R.theta_att.settling_s - R.prior.settling_s;
    R.bug.os_gamma_vs_prior = R.gamma.overshoot_deg - R.prior.overshoot_deg;
    R.bug.os_prior_vs_att_peak = R.prior.overshoot_deg - Wa.acq.max_deg;
    R.bug.frames_mix = abs(R.bug.os_gamma_vs_prior) > 0.05 || ...
        (isfinite(R.prior.settling_s) && isfinite(R.gamma.settling_s) && ...
         abs(R.bug.settle_gamma_vs_prior) > 0.05);
end

function C = pack_error_channel(t, signal, ref, e, W, mask_acq, mask_ss, band_deg)
    C = struct();
    C.settling_s = W.settling_s;
    C.acq_time_s = W.acq_time_s;
    C.persistent_ok = W.persistent_ok;
    C.band_deg = band_deg;
    C.acq = err_stats(e, mask_acq);
    C.steady = err_stats(e, mask_ss);
    C.overshoot_deg = overshoot_vs_final_ref(signal, ref, mask_acq, mask_ss);
    C.initial_dip_deg = initial_dip_vs_final_ref(signal, ref, mask_acq, mask_ss);
    [C.rise_10_90_s, C.lag_s] = rise_lag_10_90(t, signal, ref, mask_acq, mask_ss, band_deg);
    C.peak_abs_err_acq_deg = local_max_abs_deg(e, mask_acq);
end

function st = err_stats(e, mask)
    st = struct('signed_deg', NaN, 'mae_deg', NaN, 'rms_deg', NaN, ...
        'p95_deg', NaN, 'max_deg', NaN, 'n', 0);
    if ~any(mask); return; end
    v = e(mask); v = v(isfinite(v));
    if isempty(v); return; end
    st.n = numel(v);
    st.signed_deg = rad2deg(mean(v));
    st.mae_deg = rad2deg(mean(abs(v)));
    st.rms_deg = rad2deg(sqrt(mean(v.^2)));
    st.p95_deg = rad2deg(local_pctile(abs(v), 95));
    st.max_deg = rad2deg(max(abs(v)));
end

function A = act_pack(de, dr, de_dot, dr_dot, mask)
    A = struct('de_rms', NaN, 'dr_rms', NaN, 'de_rate_rms', NaN, 'dr_rate_rms', NaN, 'n', 0);
    if ~any(mask); return; end
    A.n = nnz(mask);
    A.de_rms = rms_safe(de, mask);
    A.dr_rms = rms_safe(dr, mask);
    A.de_rate_rms = rms_safe(de_dot, mask);
    A.dr_rate_rms = rms_safe(dr_dot, mask);
end

function os = overshoot_vs_final_ref(signal, ref, mask_acq, mask_ss)
    os = NaN;
    if ~any(mask_acq) || ~any(mask_ss); return; end
    final_ref = mean(ref(mask_ss));
    sig0 = signal(find(mask_acq, 1, 'first'));
    sa = signal(mask_acq);
    if final_ref >= sig0
        os = rad2deg(max(0, max(sa) - final_ref));
    else
        os = rad2deg(max(0, final_ref - min(sa)));
    end
end

function dip = initial_dip_vs_final_ref(signal, ref, mask_acq, mask_ss)
    dip = NaN;
    if ~any(mask_acq) || ~any(mask_ss); return; end
    final_ref = mean(ref(mask_ss));
    idx = find(mask_acq);
    n1 = max(1, floor(numel(idx) / 3));
    early = signal(idx(1:n1));
    sig0 = signal(idx(1));
    if final_ref >= sig0
        dip = rad2deg(max(0, sig0 - min(early)));
    else
        dip = rad2deg(max(0, max(early) - sig0));
    end
end

function [t1090, lag] = rise_lag_10_90(t, signal, ref, mask_acq, mask_ss, band_deg)
    t1090 = NaN; lag = NaN;
    if ~any(mask_acq) || ~any(mask_ss); return; end
    final_ref = mean(ref(mask_ss));
    idx = find(mask_acq | mask_ss);
    if isempty(idx); return; end
    sig0 = signal(idx(1));
    amp = final_ref - sig0;
    if abs(amp) < deg2rad(1e-4)
        t1090 = 0; lag = 0; return;
    end
    lo = sig0 + 0.10 * amp;
    hi = sig0 + 0.90 * amp;
    t10 = NaN; t90 = NaN;
    for k = 1:numel(idx)
        s = signal(idx(k));
        if isnan(t10)
            if (amp > 0 && s >= lo) || (amp < 0 && s <= lo)
                t10 = t(idx(k));
            end
        end
        if ~isnan(t10) && isnan(t90)
            if (amp > 0 && s >= hi) || (amp < 0 && s <= hi)
                t90 = t(idx(k));
                break;
            end
        end
    end
    if isfinite(t10) && isfinite(t90)
        t1090 = t90 - t10;
    end
    band = deg2rad(band_deg);
    for k = 1:numel(idx)
        if abs(signal(idx(k)) - final_ref) <= band
            lag = t(idx(k)) - t(idx(1));
            break;
        end
    end
end

%% ===================== classify / gates =====================
function [G, class_id, evidence, next_opt, next_detail, corrected] = ...
        score_and_classify(Raw, RL, band_deg, abs_eps_rate, abs_eps_ang, abs_eps_pct, valid_min, xcheck)

    names = {'X', 'XZ', 'H'};
    labels = {'X', 'XZ', 'R10'};
    G = struct();
    G.valid_ok = true;
    G.defs_ok = true;
    G.bool_consistent = true;
    G.frames_ok = true;
    G.rows = struct();

    corrected = struct();
    evidence = {};

    % Semantics / definition checks
    G.defs_ok = G.defs_ok && (band_deg > 0) && xcheck.aff_match;
    evidence{end+1} = sprintf('AFF series identity RL.mat vs BENCHMARK.mat: %s', tern(xcheck.aff_match, 'MATCH', 'MISMATCH')); %#ok<*AGROW>
    evidence{end+1} = sprintf('Settle band stated: +/-%.2f deg persistent; end_frac=0.88', band_deg);
    evidence{end+1} = 'Prior OS = acq |e_theta_att| peak (not OS vs final gamma_ref)';
    evidence{end+1} = 'Prior settle/OS windows from e_theta_att (X:first_hold; XZ/H:persistent)';

    metric_bug_votes = 0;
    true_transient_votes = 0;
    unknown_votes = 0;

    for i = 1:3
        nm = names{i}; lbl = labels{i};
        P = Raw.P.(nm); A04 = Raw.A04.(nm); AFF = Raw.AFF.(nm); T = Raw.RL.(nm);
        row = struct(); row.label = lbl; row.band_deg = band_deg;

        % Valid samples
        row.valid = [P.valid_frac, A04.valid_frac, AFF.valid_frac, T.valid_frac];
        row.valid_ok = all(row.valid >= valid_min);
        G.valid_ok = G.valid_ok && row.valid_ok;

        % Corrected gamma transient (P/A04/AFF/RL)
        row.g_set = [P.gamma.settling_s, A04.gamma.settling_s, AFF.gamma.settling_s, T.gamma.settling_s];
        row.g_os  = [P.gamma.overshoot_deg, A04.gamma.overshoot_deg, AFF.gamma.overshoot_deg, T.gamma.overshoot_deg];
        row.g_dip = [P.gamma.initial_dip_deg, A04.gamma.initial_dip_deg, AFF.gamma.initial_dip_deg, T.gamma.initial_dip_deg];
        row.g_rise = [P.gamma.rise_10_90_s, A04.gamma.rise_10_90_s, AFF.gamma.rise_10_90_s, T.gamma.rise_10_90_s];
        row.g_lag  = [P.gamma.lag_s, A04.gamma.lag_s, AFF.gamma.lag_s, T.gamma.lag_s];
        row.g_mae_acq = [P.gamma.acq.mae_deg, A04.gamma.acq.mae_deg, AFF.gamma.acq.mae_deg, T.gamma.acq.mae_deg];
        row.g_mae_ss  = [P.gamma.steady.mae_deg, A04.gamma.steady.mae_deg, AFF.gamma.steady.mae_deg, T.gamma.steady.mae_deg];
        row.g_rms_ss  = [P.gamma.steady.rms_deg, A04.gamma.steady.rms_deg, AFF.gamma.steady.rms_deg, T.gamma.steady.rms_deg];
        row.g_p95_ss  = [P.gamma.steady.p95_deg, A04.gamma.steady.p95_deg, AFF.gamma.steady.p95_deg, T.gamma.steady.p95_deg];
        row.g_max_ss  = [P.gamma.steady.max_deg, A04.gamma.steady.max_deg, AFF.gamma.steady.max_deg, T.gamma.steady.max_deg];
        row.g_signed_ss = [P.gamma.steady.signed_deg, A04.gamma.steady.signed_deg, AFF.gamma.steady.signed_deg, T.gamma.steady.signed_deg];

        % Attitude separate
        row.th_set = [P.theta_att.settling_s, A04.theta_att.settling_s, AFF.theta_att.settling_s, T.theta_att.settling_s];
        row.th_os  = [P.theta_att.overshoot_deg, A04.theta_att.overshoot_deg, AFF.theta_att.overshoot_deg, T.theta_att.overshoot_deg];
        row.th_mae_ss = [P.theta_att.steady.mae_deg, A04.theta_att.steady.mae_deg, AFF.theta_att.steady.mae_deg, T.theta_att.steady.mae_deg];

        % Prior reported
        row.prior_set = [P.prior.settling_s, A04.prior.settling_s, AFF.prior.settling_s, T.prior.settling_s];
        row.prior_os  = [P.prior.overshoot_deg, A04.prior.overshoot_deg, AFF.prior.overshoot_deg, T.prior.overshoot_deg];

        % Actuators (corrected gamma windows)
        row.de_ss = [P.act.steady.de_rate_rms, A04.act.steady.de_rate_rms, AFF.act.steady.de_rate_rms, T.act.steady.de_rate_rms];
        row.dr_ss = [P.act.steady.dr_rate_rms, A04.act.steady.dr_rate_rms, AFF.act.steady.dr_rate_rms, T.act.steady.dr_rate_rms];
        row.de_acq = [P.act.acq.de_rate_rms, A04.act.acq.de_rate_rms, AFF.act.acq.de_rate_rms, T.act.acq.de_rate_rms];
        row.dr_acq = [P.act.acq.dr_rate_rms, A04.act.acq.dr_rate_rms, AFF.act.acq.dr_rate_rms, T.act.acq.dr_rate_rms];
        row.de_rms_ss = [P.act.steady.de_rms, A04.act.steady.de_rms, AFF.act.steady.de_rms, T.act.steady.de_rms];
        row.dr_rms_ss = [P.act.steady.dr_rms, A04.act.steady.dr_rms, AFF.act.steady.dr_rms, T.act.steady.dr_rms];
        row.de_rms_acq = [P.act.acq.de_rms, A04.act.acq.de_rms, AFF.act.acq.de_rms, T.act.acq.de_rms];
        row.dr_rms_acq = [P.act.acq.dr_rms, A04.act.acq.dr_rms, AFF.act.acq.dr_rms, T.act.acq.dr_rms];

        % Prior act (legacy windows) — what RATE_LIMIT gated on
        row.prior_de_ss = [P.prior.de_rate_rms, A04.prior.de_rate_rms, AFF.prior.de_rate_rms, T.prior.de_rate_rms];
        row.prior_de_acq = [P.prior.de_rate_acq, A04.prior.de_rate_acq, AFF.prior.de_rate_acq, T.prior.de_rate_acq];
        row.prior_dr_ss = [P.prior.dr_rate_rms, A04.prior.dr_rate_rms, AFF.prior.dr_rate_rms, T.prior.dr_rate_rms];
        row.prior_dr_acq = [P.prior.dr_rate_acq, A04.prior.dr_rate_acq, AFF.prior.dr_rate_acq, T.prior.dr_rate_acq];

        % ---- Recompute prior gate booleans numerically (legacy metrics) ----
        % Settle/OS improve >=10% vs AFF (prior defs)
        row.prior_set_imp = improve_pct(row.prior_set(3), row.prior_set(4), abs_eps_ang);
        row.prior_os_imp  = improve_pct(row.prior_os(3), row.prior_os(4), abs_eps_ang);
        row.prior_set_vs_aff = le_improve(row.prior_set(4), row.prior_set(3), 0.10, abs_eps_ang);
        row.prior_os_vs_aff  = le_improve(row.prior_os(4), row.prior_os(3), 0.10, abs_eps_ang);
        row.prior_vs_aff_ok = row.prior_set_vs_aff && row.prior_os_vs_aff;
        row.prior_set_vs_P = within_tol(row.prior_set(4), row.prior_set(1), 0.02, abs_eps_ang);
        row.prior_os_vs_P  = within_tol(row.prior_os(4), row.prior_os(1), 0.02, abs_eps_ang);
        row.prior_settle_ok = row.prior_set_vs_P && row.prior_os_vs_P;
        row.prior_de_ss_ok = within_tol(row.prior_de_ss(4), row.prior_de_ss(1), 0.02, abs_eps_rate);
        row.prior_dr_ss_ok = within_tol(row.prior_dr_ss(4), row.prior_dr_ss(1), 0.02, abs_eps_rate);
        row.prior_de_acq_ok = within_tol(row.prior_de_acq(4), row.prior_de_acq(1), 0.02, abs_eps_rate);
        row.prior_dr_acq_ok = within_tol(row.prior_dr_acq(4), row.prior_dr_acq(1), 0.02, abs_eps_rate);
        row.prior_act_ok = row.prior_de_ss_ok && row.prior_dr_ss_ok && ...
            row.prior_de_acq_ok && row.prior_dr_acq_ok;

        % Reported gates from RATE_LIMIT mat
        Gr = RL.gates.rows.(nm);
        row.reported_act_ok = Gr.act_ok;
        row.reported_settle_ok = Gr.settle_ok;
        row.reported_vs_aff_ok = Gr.vs_aff_ok;
        row.reported_de_vs_P = Gr.de_vs_P;
        row.reported_de_acq_vs_P = Gr.de_acq_vs_P;
        row.reported_dr_vs_P = Gr.dr_vs_P;
        row.reported_dr_acq_vs_P = Gr.dr_acq_vs_P;

        % Boolean consistency: recomputed prior numbers must match reported flags
        row.bool_act_match = (row.prior_act_ok == logical(row.reported_act_ok));
        row.bool_set_match = (row.prior_settle_ok == logical(row.reported_settle_ok));
        row.bool_aff_match = (row.prior_vs_aff_ok == logical(row.reported_vs_aff_ok));
        row.bool_ok = row.bool_act_match && row.bool_set_match && row.bool_aff_match;
        G.bool_consistent = G.bool_consistent && row.bool_ok;

        % Frame mix: prior OS/settle diverge from gamma definitions
        row.frame_mix = P.bug.frames_mix || AFF.bug.frames_mix || T.bug.frames_mix || ...
            abs(row.prior_os(4) - row.g_os(4)) > 0.05 || ...
            (isfinite(row.prior_set(4)) && isfinite(row.g_set(4)) && abs(row.prior_set(4) - row.g_set(4)) > 0.05);
        G.frames_ok = G.frames_ok && ~row.frame_mix;  % frames_ok means consistent corrected defs used

        % ---- Corrected gates (e_gamma persistent + OS vs final γ_ref) ----
        row.set_imp_aff = improve_pct(row.g_set(3), row.g_set(4), abs_eps_ang);
        row.os_imp_aff  = improve_pct(row.g_os(3), row.g_os(4), abs_eps_ang);
        row.set_vs_aff = le_improve(row.g_set(4), row.g_set(3), 0.10, abs_eps_ang);
        row.os_vs_aff  = le_improve(row.g_os(4), row.g_os(3), 0.10, abs_eps_ang);
        row.vs_aff_ok = row.set_vs_aff && row.os_vs_aff;
        row.set_vs_P = within_tol(row.g_set(4), row.g_set(1), 0.02, abs_eps_ang);
        row.os_vs_P  = within_tol(row.g_os(4), row.g_os(1), 0.02, abs_eps_ang);
        row.settle_ok = row.set_vs_P && row.os_vs_P;
        row.de_ss_ok = within_tol(row.de_ss(4), row.de_ss(1), 0.02, abs_eps_rate);
        row.dr_ss_ok = within_tol(row.dr_ss(4), row.dr_ss(1), 0.02, abs_eps_rate);
        row.de_acq_ok = within_tol(row.de_acq(4), row.de_acq(1), 0.02, abs_eps_rate);
        row.dr_acq_ok = within_tol(row.dr_acq(4), row.dr_acq(1), 0.02, abs_eps_rate);
        row.act_ok = row.de_ss_ok && row.dr_ss_ok && row.de_acq_ok && row.dr_acq_ok;

        % Steady rates display claim: RL < P?
        row.steady_de_lower_than_P = isfinite(row.de_ss(4)) && isfinite(row.de_ss(1)) && ...
            (row.de_ss(4) <= row.de_ss(1) + abs_eps_rate);
        row.prior_steady_de_lower = isfinite(row.prior_de_ss(4)) && isfinite(row.prior_de_ss(1)) && ...
            (row.prior_de_ss(4) <= row.prior_de_ss(1) + abs_eps_rate);

        % Act FAIL while steady rates improved → window/metric bug signal
        row.act_fail_despite_steady_improve = (~row.prior_act_ok) && row.prior_steady_de_lower && ...
            within_tol(row.prior_dr_ss(4), row.prior_dr_ss(1), 0.02, abs_eps_rate);

        % Classification votes for this route
        if row.frame_mix || row.act_fail_despite_steady_improve || ...
                (abs(row.prior_os(4) - T.Wp.acq.max_deg) < 1e-6 && abs(row.prior_os(4) - row.g_os(4)) > 0.1)
            metric_bug_votes = metric_bug_votes + 1;
        end
        % If corrected gates still fail settle/OS vs AFF/P with true gamma → true transient
        if row.valid_ok && ~row.vs_aff_ok && ~row.frame_mix
            true_transient_votes = true_transient_votes + 1;
        elseif row.valid_ok && ~row.settle_ok && ~row.frame_mix
            true_transient_votes = true_transient_votes + 1;
        end
        if ~row.valid_ok || (~row.bool_ok)
            unknown_votes = unknown_votes + 1;
        end

        evidence{end+1} = sprintf(['%s prior act_ok=%d (de_ss %d de_acq %d dr_ss %d dr_acq %d) ', ...
            'steady_de P→RL %.4g→%.4g acq_de %.4g→%.4g'], lbl, row.prior_act_ok, ...
            row.prior_de_ss_ok, row.prior_de_acq_ok, row.prior_dr_ss_ok, row.prior_dr_acq_ok, ...
            row.prior_de_ss(1), row.prior_de_ss(4), row.prior_de_acq(1), row.prior_de_acq(4));
        evidence{end+1} = sprintf(['%s prior set/OS AFF→RL %.3f→%.3f / %.3f→%.3f (imp %+.1f/%+.1f%%); ', ...
            'corr γ set/OS %.3f→%.3f / %.3f→%.3f (imp %+.1f/%+.1f%%)'], lbl, ...
            row.prior_set(3), row.prior_set(4), row.prior_os(3), row.prior_os(4), ...
            row.prior_set_imp, row.prior_os_imp, ...
            row.g_set(3), row.g_set(4), row.g_os(3), row.g_os(4), ...
            row.set_imp_aff, row.os_imp_aff);

        G.rows.(nm) = row;
        corrected.(nm) = row;
    end

    % Global classification
    % Strong METRIC_BUG if prior OS is eth peak AND differs from gamma OS, AND/OR
    % act FAIL with improved steady rates due to acq-window coupling to eth settle.
    all_os_are_eth_peak = true;
    any_frame_mix = false;
    any_act_paradox = false;
    corr_vs_aff_all = true;
    corr_settle_all = true;
    corr_act_all = true;
    for i = 1:3
        nm = names{i};
        r = G.rows.(nm);
        any_frame_mix = any_frame_mix || r.frame_mix;
        any_act_paradox = any_act_paradox || r.act_fail_despite_steady_improve;
        corr_vs_aff_all = corr_vs_aff_all && r.vs_aff_ok;
        corr_settle_all = corr_settle_all && r.settle_ok;
        corr_act_all = corr_act_all && r.act_ok;
        % eth peak identity
        T = Raw.RL.(nm);
        all_os_are_eth_peak = all_os_are_eth_peak && ...
            isfinite(T.prior.overshoot_deg) && isfinite(T.Wp.acq.max_deg) && ...
            abs(T.prior.overshoot_deg - T.Wp.acq.max_deg) < 1e-4;
    end

    if all_os_are_eth_peak && (any_frame_mix || any_act_paradox)
        class_id = 'METRIC_BUG';
        next_opt = 'two_repeat_closure_egamma_persistent_gates';
        next_detail = ['METRIC_BUG: prior settle/OS gated on legacy e_theta (OS=|e_θ| peak); ', ...
            'actuator acq windows coupled to e_θ settle so steady-rate improve still FAIL. ', ...
            'Corrected two-repeat closure: gate settle/OS on persistent |e_gamma|<=0.5deg; ', ...
            'OS vs mean(gamma_ref|steady); actuator rates on gamma-derived (or fixed) windows; ', ...
            'zeros use abs tol. Do not promote until two-repeat with corrected gates.'];
    elseif ~corr_vs_aff_all || ~corr_settle_all
        % Corrected gamma metrics still show transient fail
        if any_frame_mix
            class_id = 'UNKNOWN';
            next_opt = 'recompute_then_decide_shaper_or_closure';
            next_detail = ['UNKNOWN: frame mix present AND corrected gamma settle/OS still marginal. ', ...
                'First apply corrected e_gamma gates; if still FAIL name one bounded shaper.'];
        else
            class_id = 'TRUE_TRANSIENT';
            next_opt = 'alpha_cmd_soft_start_cosine_1deg_s';
            next_detail = ['TRUE_TRANSIENT: with e_gamma persistent settle + OS vs final γ_ref, ', ...
                'shaped RL still misses >=10% vs AFF and/or <=2% vs P. ', ...
                'One final bounded shaper: alpha_cmd soft-start cosine envelope with |dα/dt|≤1deg/s ', ...
                '(half of current 2deg/s), hold schedule/gains fixed; then stop shaping attempts.'];
        end
    elseif any_frame_mix || any_act_paradox
        class_id = 'METRIC_BUG';
        next_opt = 'two_repeat_closure_egamma_persistent_gates';
        next_detail = ['METRIC_BUG confirmed: definitions/windows inconsistent with gamma intent. ', ...
            'Corrected two-repeat closure with e_gamma persistent gates (audit does not promote).'];
    else
        class_id = 'UNKNOWN';
        next_opt = 'hold_production_recheck_gates';
        next_detail = 'UNKNOWN: insufficient separation between metric bug and true transient.';
    end

    % If METRIC_BUG but corrected gates all pass → still METRIC_BUG (false FAIL)
    if strcmp(class_id, 'METRIC_BUG') && corr_vs_aff_all && corr_settle_all && corr_act_all
        next_detail = [next_detail, ' Corrected table: settle/OS/act gates PASS — prior FAIL was metric.'];
    end
    if strcmp(class_id, 'METRIC_BUG') && (~corr_vs_aff_all || ~corr_settle_all)
        next_detail = [next_detail, ' Note: corrected gamma gates may still FAIL some settle/OS rows — ', ...
            'closure must report both; do not treat prior eth-OS as evidence of shaping need.'];
    end

    G.class = class_id;
    G.corr_vs_aff_all = corr_vs_aff_all;
    G.corr_settle_all = corr_settle_all;
    G.corr_act_all = corr_act_all;
    G.any_frame_mix = any_frame_mix;
    G.any_act_paradox = any_act_paradox;
    G.all_os_are_eth_peak = all_os_are_eth_peak;
    G.metric_bug_votes = metric_bug_votes;
    G.true_transient_votes = true_transient_votes;
    G.unknown_votes = unknown_votes;

    % Audit PASS: definitions/frames/windows + booleans internally consistent, >=95% valid
    % frames_ok for audit means we successfully separated frames (not that prior was correct)
    G.audit_pass = G.valid_ok && G.defs_ok && G.bool_consistent && ...
        ismember(class_id, {'METRIC_BUG', 'TRUE_TRANSIENT', 'UNKNOWN'});
    % Require classification evidence coherent
    if ~G.bool_consistent
        evidence{end+1} = 'WARN: recomputed prior booleans disagree with RATE_LIMIT reported flags';
    end
    evidence{end+1} = sprintf('class=%s | corr gates vsAFF/settle/act=%d/%d/%d | frame_mix=%d act_paradox=%d eth_peak_OS=%d', ...
        class_id, corr_vs_aff_all, corr_settle_all, corr_act_all, any_frame_mix, any_act_paradox, all_os_are_eth_peak);
end

%% ===================== numeric rules =====================
function ok = within_tol(cand, base, rel, abs_eps)
    % cand must not exceed base by >2% (or abs_eps when base≈0). Lower-is-better.
    if ~(isfinite(cand) && isfinite(base)); ok = false; return; end
    if abs(base) <= abs_eps
        ok = cand <= base + abs_eps;   % absolute only — no percent division
        return;
    end
    ok = cand <= base + max(abs_eps, rel * abs(base));
end

function ok = le_improve(cand, base, frac, abs_eps)
    % cand improves by >= frac (e.g. 0.10) vs base; zeros → absolute
    if ~(isfinite(cand) && isfinite(base)); ok = false; return; end
    if abs(base) <= abs_eps
        ok = cand <= base + abs_eps;
        return;
    end
    ok = cand <= (1 - frac) * base + 1e-12;
end

function pct = improve_pct(base, cand, abs_eps)
    if ~(isfinite(base) && isfinite(cand)); pct = NaN; return; end
    if abs(base) <= abs_eps
        pct = NaN;  % refuse percent on ~zero base
        return;
    end
    pct = 100 * (base - cand) / abs(base);
end

%% ===================== PNG / MD / append =====================
function write_png(png_path, Raw, task_id, verdict, class_id, band_deg)
    routes = {'X', 'XZ', 'H'};
    titles = {'X', 'XZ', 'R10'};
    fig = figure('Visible', 'off', 'Position', [40 40 1400 900]);
    for i = 1:3
        nm = routes{i};
        T = Raw.RL.(nm); P = Raw.P.(nm); AFF = Raw.AFF.(nm);
        % limit to acquisition (+ small pad)
        t_acq = T.t(T.mask_acq);
        if isempty(t_acq); tmax = min(8, max(T.t)); else; tmax = min(max(t_acq) + 1.0, max(T.t)); end
        m = T.t <= tmax;

        subplot(3, 4, (i-1)*4 + 1);
        plot(T.t(m), rad2deg(T.gamma_ref(m)), 'k--', 'LineWidth', 1); hold on;
        plot(P.t(P.t<=tmax), rad2deg(P.gamma_act(P.t<=tmax)), 'b:');
        plot(AFF.t(AFF.t<=tmax), rad2deg(AFF.gamma_act(AFF.t<=tmax)), 'm');
        plot(T.t(m), rad2deg(T.gamma_act(m)), 'r', 'LineWidth', 1.1);
        yline(band_deg, 'g:'); yline(-band_deg, 'g:');
        grid on; ylabel('\gamma [deg]');
        title(sprintf('%s \\gamma_{ref/act} (%s/%s)', titles{i}, verdict, class_id));
        if i == 1; legend('\gamma_{ref}','P','AFF','RL','Location','best'); end

        subplot(3, 4, (i-1)*4 + 2);
        plot(T.t(m), rad2deg(T.e_gamma(m)), 'r'); hold on;
        plot(P.t(P.t<=tmax), rad2deg(P.e_gamma(P.t<=tmax)), 'b:');
        plot(AFF.t(AFF.t<=tmax), rad2deg(AFF.e_gamma(AFF.t<=tmax)), 'm');
        yline(band_deg, 'k--'); yline(-band_deg, 'k--');
        grid on; ylabel('e_\gamma [deg]');
        title(sprintf('e_gamma band +/-%.1f deg', band_deg));

        subplot(3, 4, (i-1)*4 + 3);
        plot(T.t(m), rad2deg(T.theta_cmd(m)), 'k--'); hold on;
        plot(T.t(m), rad2deg(T.theta_ref(m)), 'c:');
        plot(T.t(m), rad2deg(T.theta_phys(m)), 'r');
        plot(T.t(m), rad2deg(T.alpha_target(m)), 'g:');
        plot(T.t(m), rad2deg(T.alpha_cmd(m)), 'b', 'LineWidth', 1.1);
        grid on; ylabel('[deg]');
        title('\theta_{cmd/ref/phys} \alpha_{tgt/cmd}');
        if i == 1; legend('\theta_{cmd}','\theta_{ref}','\theta_{phys}','\alpha_{tgt}','\alpha_{cmd}','Location','best'); end

        subplot(3, 4, (i-1)*4 + 4);
        yyaxis left;
        plot(T.t(m), rad2deg(T.de(m)), 'r'); hold on;
        plot(P.t(P.t<=tmax), rad2deg(P.de(P.t<=tmax)), 'b:');
        ylabel('\delta_e [deg]');
        yyaxis right;
        plot(T.t(m), rad2deg(T.dr(m)), 'k');
        ylabel('\delta_r [deg]');
        grid on; xlabel('t [s]');
        title('actuators (acq)');
        if i == 1; legend('de_{RL}','de_P','dr_{RL}','Location','best'); end
    end
    sgtitle(sprintf('%s — acq \gamma/\theta/\alpha/actuators', task_id), 'Interpreter', 'none');
    exportgraphics(fig, png_path, 'Resolution', 140);
    close(fig);
end

function write_md(md_path, task_id, verdict, class_id, defs, Raw, G, corrected, evidence, ...
        next_opt, next_detail, rl_path, aff_path, sem_path, md_out, mat_out, png_out, xcheck)

    fid = fopen(md_path, 'w');
    fprintf(fid, '# %s — Trim-alpha transient gate raw-metric audit\n\n', task_id);
    fprintf(fid, '**Overall verdict: %s** | **class: %s**\n\n', verdict, class_id);

    fprintf(fid, '## Provenance\n\n');
    fprintf(fid, '- Read-only: `%s`, `%s`, `%s`\n', rl_path, aff_path, sem_path);
    fprintf(fid, '- Driver: `run_trim_alpha_transient_gate_audit.m` (one invocation; no sim; production untouched)\n');
    fprintf(fid, '- Artifacts: `%s`, `%s`, `%s`\n', md_out, mat_out, png_out);
    fprintf(fid, '- AFF identity cross-check: %s\n\n', tern(xcheck.aff_match, 'MATCH', 'MISMATCH'));

    fprintf(fid, '## Definitions (stated)\n\n');
    fprintf(fid, '```\n');
    fprintf(fid, '%s\n', defs.e_gamma);
    fprintf(fid, '%s\n', defs.e_theta_att);
    fprintf(fid, '%s\n', defs.e_theta_req);
    fprintf(fid, '%s\n', defs.settle);
    fprintf(fid, '%s\n', defs.overshoot);
    fprintf(fid, '%s\n', defs.dip);
    fprintf(fid, '%s\n', defs.rise);
    fprintf(fid, 'PRIOR BUG: %s\n', defs.prior_bug);
    fprintf(fid, 'Zeros: within_tol / improve use absolute eps (rate 1e-6, ang 1e-3) — no %% on ~0 base\n');
    fprintf(fid, '```\n\n');

    fprintf(fid, '## Corrected table — e_gamma persistent (band ±%.2f°) P/A04/AFF/RL\n\n', defs.band_deg);
    fprintf(fid, '| Route | settle[s] | OS° vs γ_ref_ss | dip° | 10-90[s] | lag[s] | γMAE_ss° | γ signed/RMS/p95/max° |\n');
    fprintf(fid, '|-------|----------:|---------------:|-----:|---------:|-------:|---------:|----------------------:|\n');
    names = {'X', 'XZ', 'H'};
    for i = 1:3
        r = corrected.(names{i});
        fprintf(fid, '| %s | %.3f/%.3f/%.3f/%.3f | %.3f/%.3f/%.3f/%.3f | %.3f/%.3f/%.3f/%.3f | %.3f/%.3f/%.3f/%.3f | %.3f/%.3f/%.3f/%.3f | %.3f/%.3f/%.3f/%.3f | %.3f/%.3f/%.3f/%.3f |\n', ...
            r.label, r.g_set(1), r.g_set(2), r.g_set(3), r.g_set(4), ...
            r.g_os(1), r.g_os(2), r.g_os(3), r.g_os(4), ...
            r.g_dip(1), r.g_dip(2), r.g_dip(3), r.g_dip(4), ...
            r.g_rise(1), r.g_rise(2), r.g_rise(3), r.g_rise(4), ...
            r.g_lag(1), r.g_lag(2), r.g_lag(3), r.g_lag(4), ...
            r.g_mae_ss(1), r.g_mae_ss(2), r.g_mae_ss(3), r.g_mae_ss(4), ...
            r.g_signed_ss(4), r.g_rms_ss(4), r.g_p95_ss(4), r.g_max_ss(4));
    end

    fprintf(fid, '\n## Attitude error (separate) — persistent |e_θ_att|\n\n');
    fprintf(fid, '| Route | θ_settle[s] P/A04/AFF/RL | θ_OS° | θ_MAE_ss° | prior settle (eth) | prior OS=|eθ|peak |\n');
    fprintf(fid, '|-------|-------------------------:|------:|----------:|-------------------:|-------------------:|\n');
    for i = 1:3
        r = corrected.(names{i});
        fprintf(fid, '| %s | %.3f/%.3f/%.3f/%.3f | %.3f/%.3f/%.3f/%.3f | %.3f/%.3f/%.3f/%.3f | %.3f/%.3f/%.3f/%.3f | %.3f/%.3f/%.3f/%.3f |\n', ...
            r.label, r.th_set(1), r.th_set(2), r.th_set(3), r.th_set(4), ...
            r.th_os(1), r.th_os(2), r.th_os(3), r.th_os(4), ...
            r.th_mae_ss(1), r.th_mae_ss(2), r.th_mae_ss(3), r.th_mae_ss(4), ...
            r.prior_set(1), r.prior_set(2), r.prior_set(3), r.prior_set(4), ...
            r.prior_os(1), r.prior_os(2), r.prior_os(3), r.prior_os(4));
    end

    fprintf(fid, '\n## Actuators — elevator/rudder RMS & rate RMS (γ-windows)\n\n');
    fprintf(fid, '| Route | deRate_ss P/AFF/RL | deRate_acq P/AFF/RL | drRate_ss | drRate_acq | de_rms_ss | de_rms_acq |\n');
    fprintf(fid, '|-------|-------------------:|--------------------:|----------:|-----------:|----------:|-----------:|\n');
    for i = 1:3
        r = corrected.(names{i});
        fprintf(fid, '| %s | %.4g/%.4g/%.4g | %.4g/%.4g/%.4g | %.4g/%.4g/%.4g | %.4g/%.4g/%.4g | %.4g/%.4g/%.4g | %.4g/%.4g/%.4g |\n', ...
            r.label, r.de_ss(1), r.de_ss(3), r.de_ss(4), r.de_acq(1), r.de_acq(3), r.de_acq(4), ...
            r.dr_ss(1), r.dr_ss(3), r.dr_ss(4), r.dr_acq(1), r.dr_acq(3), r.dr_acq(4), ...
            r.de_rms_ss(1), r.de_rms_ss(3), r.de_rms_ss(4), r.de_rms_acq(1), r.de_rms_acq(3), r.de_rms_acq(4));
    end

    fprintf(fid, '\n## Gate boolean verification (≤2%% / ≥10%%; zeros→abs tol)\n\n');
    fprintf(fid, '| Route | prior vsAFF | prior settle≤2%%P | prior act≤2%%P | de_ss/acq/dr_ss/acq | corr vsAFF | corr settle | corr act | valid%% | bool match |\n');
    fprintf(fid, '|-------|:-----------:|:-----------------:|:--------------:|--------------------:|:----------:|:-----------:|:--------:|--------:|:----------:|\n');
    for i = 1:3
        r = corrected.(names{i});
        fprintf(fid, '| %s | %s (%+.1f/%+.1f%%) | %s | %s | %d/%d/%d/%d | %s (%+.1f/%+.1f%%) | %s | %s | %.1f | %s |\n', ...
            r.label, yn(r.prior_vs_aff_ok), r.prior_set_imp, r.prior_os_imp, ...
            yn(r.prior_settle_ok), yn(r.prior_act_ok), ...
            r.prior_de_ss_ok, r.prior_de_acq_ok, r.prior_dr_ss_ok, r.prior_dr_acq_ok, ...
            yn(r.vs_aff_ok), r.set_imp_aff, r.os_imp_aff, ...
            yn(r.settle_ok), yn(r.act_ok), 100*min(r.valid), yn(r.bool_ok));
    end

    fprintf(fid, '\n## Classification\n\n');
    fprintf(fid, '- Class: **%s**\n', class_id);
    fprintf(fid, '- eth-peak OS identity: %s | frame_mix: %s | act_FAIL despite steady improve: %s\n', ...
        yn(G.all_os_are_eth_peak), yn(G.any_frame_mix), yn(G.any_act_paradox));
    fprintf(fid, '- Corrected gates all vsAFF/settle/act: %s/%s/%s\n', ...
        yn(G.corr_vs_aff_all), yn(G.corr_settle_all), yn(G.corr_act_all));
    fprintf(fid, '- Audit PASS criteria: valid≥95%%, defs OK, booleans consistent with numeric rules; does **not** promote controller\n\n');

    fprintf(fid, '## Evidence\n\n');
    for k = 1:numel(evidence)
        fprintf(fid, '- %s\n', evidence{k});
    end

    fprintf(fid, '\n## Decision\n\n');
    fprintf(fid, '- Verdict: **%s**\n', verdict);
    fprintf(fid, '- Class: **%s**\n', class_id);
    fprintf(fid, '- Next: `%s`\n', next_opt);
    fprintf(fid, '- Detail: %s\n', next_detail);
    fprintf(fid, '- Production: untouched (audit does not promote)\n\n');

    fprintf(fid, '## Feedback\n\n');
    fprintf(fid, '- PASS/FAIL: **%s**\n', verdict);
    fprintf(fid, '- Class: **%s**\n', class_id);
    fprintf(fid, '- Next: `%s`\n', next_opt);
    fprintf(fid, '- Files: `%s` `%s` `%s`\n', md_out, mat_out, png_out);
    fclose(fid);
end

function append_ss_audit(out_dir, task_id, verdict, class_id, defs, Raw, G, corrected, ...
        evidence, next_opt, next_detail, md_path, mat_path, png_path)
    ss = fullfile(out_dir, 'STATE_SPACE_MODEL_AUDIT.md');
    fid = fopen(ss, 'a');
    fprintf(fid, '\n\n---\n\n');
    fprintf(fid, '## %s — %s\n\n', task_id, datestr(now, 'yyyy-mm-dd HH:MM:SS'));
    fprintf(fid, '### Provenance\n\n');
    fprintf(fid, '- Read-only: `TRIM_ALPHA_FF_RATE_LIMIT.mat`, `TRIM_ALPHA_FF_BENCHMARK.mat`, `PITCH_FLIGHTPATH_SEMANTICS_AUDIT.mat`\n');
    fprintf(fid, '- Driver: `run_trim_alpha_transient_gate_audit.m` (one invocation; no sim; production untouched)\n');
    fprintf(fid, '- Artifacts: `%s`, `%s`, `%s`\n\n', md_path, mat_path, png_path);
    fprintf(fid, '### Definitions\n\n');
    fprintf(fid, '```\nband=±%.2fdeg persistent | e_gamma=γ_ref-γ_act | OS vs mean(γ_ref|ss) | prior OS was |e_θ| peak\n```\n\n', defs.band_deg);
    fprintf(fid, '### Corrected γ settle / OS (AFF→RL) and prior eth settle / OS\n\n');
    fprintf(fid, '| Route | γ set AFF→RL | γ OS AFF→RL | prior set | prior OS | corr act | prior act |\n');
    fprintf(fid, '|-------|-------------:|------------:|----------:|---------:|:--------:|:---------:|\n');
    for nm = {'X', 'XZ', 'H'}
        r = corrected.(nm{1});
        fprintf(fid, '| %s | %.3f→%.3f (%+.1f%%) | %.3f→%.3f (%+.1f%%) | %.3f→%.3f | %.3f→%.3f | %s | %s |\n', ...
            r.label, r.g_set(3), r.g_set(4), r.set_imp_aff, r.g_os(3), r.g_os(4), r.os_imp_aff, ...
            r.prior_set(3), r.prior_set(4), r.prior_os(3), r.prior_os(4), yn(r.act_ok), yn(r.prior_act_ok));
    end
    fprintf(fid, '\n### Verdict / next\n\n');
    fprintf(fid, '- Verdict: **%s** | Class: **%s**\n', verdict, class_id);
    fprintf(fid, '- Audit gates valid/defs/bool: %s/%s/%s\n', yn(G.valid_ok), yn(G.defs_ok), yn(G.bool_consistent));
    fprintf(fid, '- Next: `%s` — %s\n', next_opt, next_detail);
    fprintf(fid, '- Production: untouched\n\n');
    fprintf(fid, '### Next\n\n');
    fprintf(fid, '- %s\n', next_opt);
    fclose(fid);
end

function print_feedback(verdict, class_id, corrected, evidence, next_opt, next_detail, md, mat, png, G)
    fprintf('\n----- FEEDBACK -----\n');
    fprintf('PASS/FAIL: %s\n', verdict);
    fprintf('Class: %s\n', class_id);
    fprintf('Corrected γ settle AFF→RL: X %.3f→%.3f | XZ %.3f→%.3f | R10 %.3f→%.3f\n', ...
        corrected.X.g_set(3), corrected.X.g_set(4), ...
        corrected.XZ.g_set(3), corrected.XZ.g_set(4), ...
        corrected.H.g_set(3), corrected.H.g_set(4));
    fprintf('Corrected γ OS AFF→RL: X %.3f→%.3f | XZ %.3f→%.3f | R10 %.3f→%.3f\n', ...
        corrected.X.g_os(3), corrected.X.g_os(4), ...
        corrected.XZ.g_os(3), corrected.XZ.g_os(4), ...
        corrected.H.g_os(3), corrected.H.g_os(4));
    fprintf('Prior act FAIL paradox (steady improve): %s | eth-peak OS: %s\n', ...
        yn(G.any_act_paradox), yn(G.all_os_are_eth_peak));
    fprintf('Evidence[1]: %s\n', evidence{1});
    fprintf('Files: %s\n%s\n%s\n', md, mat, png);
    fprintf('Next: %s\n%s\n', next_opt, next_detail);
end

%% ===================== kinematics (local copies) =====================
function [VN, VE, VD, Uh] = ned_velocity(phi, theta, psi, u, v, w)
    n = numel(u);
    VN = zeros(n, 1); VE = zeros(n, 1); VD = zeros(n, 1); Uh = zeros(n, 1);
    for i = 1:n
        R = [cos(psi(i))*cos(theta(i)), ...
             cos(psi(i))*sin(theta(i))*sin(phi(i)) - sin(psi(i))*cos(phi(i)), ...
             cos(psi(i))*sin(theta(i))*cos(phi(i)) + sin(psi(i))*sin(phi(i));
             sin(psi(i))*cos(theta(i)), ...
             sin(psi(i))*sin(theta(i))*sin(phi(i)) + cos(psi(i))*cos(phi(i)), ...
             sin(psi(i))*sin(theta(i))*cos(phi(i)) - cos(psi(i))*sin(phi(i));
             -sin(theta(i)), cos(theta(i))*sin(phi(i)), cos(theta(i))*cos(phi(i))];
        v_ned = R * [u(i); v(i); w(i)];
        VN(i) = v_ned(1); VE(i) = v_ned(2); VD(i) = v_ned(3);
        Uh(i) = hypot(VN(i), VE(i));
    end
end

function [gamma_ref, cte_perp, s_prog, s_total] = path_gamma_cte(path, vp)
    n = size(vp, 1);
    [s_nodes, s_total] = path_arclength_local(path);
    is_closed = norm(path(1,:) - path(end,:)) < 0.25;
    gamma_ref = zeros(n, 1); cte_perp = zeros(n, 1); s_prog = zeros(n, 1);
    s = 0; L = 1.25;
    for i = 1:n
        p = vp(i, :);
        if i == 1
            [s_near, ~] = project_on_path_local(p, path, s_nodes, 0, s_total, is_closed);
            s = s_near;
            if is_closed; s = mod(s, s_total); end
        else
            if is_closed
                win = max(3.0, 2.5*L);
                s_lo = mod(s - 0.15, s_total);
                [s_near, ~] = project_wrapped_local(p, path, s_nodes, s_lo, win, s_total);
                ds = wrap_arc_local(s_near - s, s_total);
                if ds >= -0.25
                    s = mod(s + max(ds, -0.05), s_total);
                end
            else
                s_lo = max(0, s - 0.15);
                s_hi = min(s_total, s + max(3.0, 2.5*L));
                [s_near, ~] = project_on_path_local(p, path, s_nodes, s_lo, s_hi, is_closed);
                if s_near >= s_total - 1e-6
                    s = s_total;
                else
                    s = max(s, s_near - 0.05);
                    s = min(s, s_total);
                end
            end
        end
        [p_d, t_hat] = sample_path_local(path, s_nodes, s, is_closed);
        th = t_hat(:);
        gamma_ref(i) = atan2(th(3), max(hypot(th(1), th(2)), 1e-9));
        dp = (p(:) - p_d(:));
        e_perp = (eye(3) - (th * th')) * dp;
        cte_perp(i) = norm(e_perp);
        s_prog(i) = s;
    end
end

function [s_nodes, s_total] = path_arclength_local(path)
    d = vecnorm(diff(path), 2, 2);
    s_nodes = [0; cumsum(d)];
    s_total = s_nodes(end);
    if s_total < 1e-9; s_total = 1e-9; end
end

function [p, t_hat] = sample_path_local(path, s_nodes, s, is_closed)
    s_total = s_nodes(end);
    if is_closed; s = mod(s, s_total); else; s = min(max(s, 0), s_total); end
    idx = find(s_nodes <= s, 1, 'last');
    if isempty(idx); idx = 1; end
    if idx >= numel(s_nodes)
        p = path(end, :); t_hat = path(end, :) - path(end-1, :);
    else
        ds = s_nodes(idx+1) - s_nodes(idx);
        if ds < 1e-12; a = 0; else; a = (s - s_nodes(idx)) / ds; end
        p = path(idx, :) + a * (path(idx+1, :) - path(idx, :));
        t_hat = path(idx+1, :) - path(idx, :);
    end
    if norm(t_hat) < 1e-9; t_hat = [1, 0, 0]; else; t_hat = t_hat / norm(t_hat); end
end

function [s_best, d_best] = project_on_path_local(p, path, s_nodes, s_lo, s_hi, is_closed) %#ok<INUSD>
    n = size(path, 1);
    d_best = inf; s_best = s_lo;
    i0 = max(1, find(s_nodes <= s_lo, 1, 'last'));
    i1 = min(n-1, find(s_nodes >= s_hi, 1, 'first'));
    if isempty(i0); i0 = 1; end
    if isempty(i1); i1 = n-1; end
    i0 = min(i0, n-1); i1 = max(i1, i0);
    for i = i0:i1
        a = path(i,:); b = path(i+1,:);
        ab = b - a; lab2 = sum(ab.^2);
        if lab2 < 1e-12; continue; end
        tt = max(0, min(1, dot(p - a, ab) / lab2));
        proj = a + tt * ab;
        d = norm(p - proj);
        if d < d_best
            d_best = d; s_best = s_nodes(i) + tt * (s_nodes(i+1) - s_nodes(i));
        end
    end
end

function [s_best, d_best] = project_wrapped_local(p, path, s_nodes, s_lo, win, s_total)
    d_best = inf; s_best = s_lo;
    n = size(path, 1);
    for k = 0:1
        if k == 0
            s_a = s_lo; s_b = min(s_total, s_lo + win);
        else
            s_a = 0; s_b = max(0, win - (s_total - s_lo));
            if s_b <= 0; continue; end
        end
        [ss, dd] = project_on_path_local(p, path, s_nodes, s_a, s_b, true);
        if dd < d_best; d_best = dd; s_best = ss; end
    end
    if ~isfinite(d_best); s_best = s_lo; d_best = inf; end
    %#ok<*NASGU>
    n = n; %#ok<NASGU>
end

function ds = wrap_arc_local(ds, s_total)
    while ds > s_total/2; ds = ds - s_total; end
    while ds < -s_total/2; ds = ds + s_total; end
end

function y = rms_safe(x, mask)
    if nargin < 2; mask = true(size(x)); end
    v = x(mask); v = v(isfinite(v));
    if isempty(v); y = NaN; else; y = sqrt(mean(v.^2)); end
end

function y = local_pctile(x, q)
    x = sort(x(:));
    if isempty(x); y = NaN; return; end
    k = max(1, min(numel(x), ceil(q / 100 * numel(x))));
    y = x(k);
end

function y = local_max_abs_deg(e, mask)
    if ~any(mask); y = NaN; return; end
    y = rad2deg(max(abs(e(mask))));
end

function s = yn(tf)
    if tf; s = 'YES'; else; s = 'NO'; end
end

function s = tern(tf, a, b)
    if tf; s = a; else; s = b; end
end
