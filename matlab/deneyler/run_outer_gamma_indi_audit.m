function run_outer_gamma_indi_audit()
% OUTER_GAMMA_INDI_AUDIT_001 — choose next vertical architecture from LTI evidence.
% Read-only: LOCAL_SS_LEVEL.mat, LOCAL_SS_CLIMB.mat, TRIM_ALPHA_TWO_REPEAT_CLOSURE.mat
% One MATLAB invocation. No controller / guidance / plant edits. No gain design/sweep.

    project_dir = fileparts(fileparts(fileparts(mfilename('fullpath')))); % repo root
    addpath(genpath(fullfile(project_dir, 'matlab')));
    out_dir = fullfile(project_dir, 'suite_results');
    tag = 'OUTER_GAMMA_INDI_AUDIT';
    task_id = 'OUTER_GAMMA_INDI_AUDIT_001';

    src_level = fullfile(out_dir, 'LOCAL_SS_LEVEL.mat');
    src_climb = fullfile(out_dir, 'LOCAL_SS_CLIMB.mat');
    src_trim  = fullfile(out_dir, 'TRIM_ALPHA_TWO_REPEAT_CLOSURE.mat');

    L = load(src_level);
    Cmb = load(src_climb);
    T = load(src_trim);

    % Frozen production cascade gains (INFERENCE — documented freeze; not from other mats)
    cascade = struct();
    cascade.Kp_angle = 1.25;      % [1/s]
    cascade.Ki_angle = 0.16;      % [1/s^2]
    cascade.Kp_rate  = 0.95;      % [s]
    cascade.Ki_rate  = 0.0;
    cascade.Kd_damp  = 0.80;      % [s]
    cascade.tau_rate = 0.05;      % [s]
    cascade.elevator_sign = 1;
    cascade.delta_e_max = deg2rad(15);
    cascade.source = ['INFERENCE from frozen production cascade ' ...
        '(AGENT_HANDOFF/init_parameters freeze: Kp_angle=1.25 Ki_angle=0.16 ' ...
        'Kp_rate=0.95 Kd_damp=0.80 tau_rate=0.05); not re-identified here'];

    fprintf('\n========== %s ==========\n', task_id);
    fprintf('Sources (read-only): LOCAL_SS_LEVEL / LOCAL_SS_CLIMB / TRIM_ALPHA_TWO_REPEAT_CLOSURE\n');
    fprintf('No controller edit; no gain sweep.\n');

    level = analyze_op('level', L, cascade);
    climb = analyze_op('climb', Cmb, cascade);
    cmp = compare_ops(level, climb);
    trim_ev = extract_trim_alpha_evidence(T);

    decision = decide_architecture(level, climb, cmp, trim_ev);
    verdict = decision.verdict;

    md_path  = fullfile(out_dir, [tag '.md']);
    mat_path = fullfile(out_dir, [tag '.mat']);
    png_path = fullfile(out_dir, [tag '.png']);

    write_png(png_path, level, climb, cmp, decision, task_id);
    write_md(md_path, task_id, verdict, decision, level, climb, cmp, trim_ev, ...
        cascade, src_level, src_climb, src_trim, md_path, mat_path, png_path);
    append_ss_audit(out_dir, task_id, verdict, decision, level, climb, cmp, ...
        md_path, mat_path, png_path);

    S = struct();
    S.task_id = task_id;
    S.verdict = verdict;
    S.decision = decision.choice;
    S.decision_struct = decision;
    S.level = level;
    S.climb = climb;
    S.compare = cmp;
    S.trim_alpha_evidence = trim_ev;
    S.cascade = cascade;
    S.literature = literature_block();
    S.sources = {src_level; src_climb; src_trim};
    S.paths = struct('md', md_path, 'mat', mat_path, 'png', png_path);
    S.note = ['Outer gamma architecture audit from reduced vertical LTI; ' ...
              'production unchanged; no gain design'];
    save(mat_path, '-struct', 'S');

    fprintf('\nVERDICT: %s\n', verdict);
    fprintf('DECISION: %s\n', decision.choice);
    fprintf('Saved: %s\n%s\n%s\n', md_path, mat_path, png_path);
    print_feedback(verdict, decision, level, climb, cmp, trim_ev, ...
        md_path, mat_path, png_path);
end

%% ===================== per-OP analysis =====================
function R = analyze_op(name, S, cascade)
    R.name = name;
    R.x0 = S.x0(:);
    R.u0 = S.u0(:);
    R.A = S.A;
    R.B = S.B;
    R.Av = S.A_vertical;
    R.Bv = S.B_vertical;
    R.ix_v = S.ix_vertical(:).';
    R.frame = char(S.frame);
    R.units_note = 'x NED+EulerZYX+BODY; u=[dr,de,thrust]; gamma [rad]';

    x = R.x0;
    u_b = x(7); w_b = x(9); th = x(5);
    alpha = atan2(w_b, u_b);
    theta_phys = -th;
    gamma_kin = theta_phys + alpha;
    R.trim = struct('u', u_b, 'w', w_b, 'theta', th, ...
        'theta_phys', theta_phys, 'alpha', alpha, 'gamma_kin', gamma_kin, ...
        'gamma_kin_deg', rad2deg(gamma_kin), 'de', R.u0(2), 'thrust', R.u0(3));

    den = u_b^2 + w_b^2;
    da_du = -w_b / den;
    da_dw =  u_b / den;
    R.Cgamma_full = zeros(1, 12);
    R.Cgamma_full(5) = -1;
    R.Cgamma_full(7) = da_du;
    R.Cgamma_full(9) = da_dw;
    R.Cgamma_v = [0, -1, da_du, da_dw, 0];
    R.dalpha = struct('du', da_du, 'dw', da_dw, 'den', den);

    Bde_v = R.Bv(:, 1);
    Bth_v = R.Bv(:, 2);

    [rd_de, markov_de] = relative_degree(R.Av, Bde_v, R.Cgamma_v, 1e-10);
    [rd_th, markov_th] = relative_degree(R.Av, Bth_v, R.Cgamma_v, 1e-10);
    R.reldeg_de = rd_de;
    R.reldeg_thrust = rd_th;
    R.markov_de = markov_de;
    R.markov_thrust = markov_th;
    R.G_delta = markov_de(1);
    R.G_delta_thrust = markov_th(1);

    sys = ss(R.Av, Bde_v, R.Cgamma_v, 0);
    R.poles = eig(R.Av);
    try
        R.zeros = tzero(sys);
    catch
        R.zeros = zeros(0, 1);
    end
    R.zeros = R.zeros(:);
    R.has_rhp_zero = any(real(R.zeros) > 1e-8);
    R.has_rhp_pole = any(real(R.poles) > 1e-8);

    ix_dyn = [2 3 4 5];
    Ad = R.Av(ix_dyn, ix_dyn);
    Bd = Bde_v(ix_dyn);
    Cd = R.Cgamma_v(ix_dyn);
    R.Ad = Ad; R.Bd = Bd; R.Cd = Cd;
    R.cond_Ad = cond(Ad);
    if rcond(Ad) > 1e-14
        R.Gdc_de = -Cd * (Ad \ Bd);
        Cthp = [ -1, 0, 0, 0];
        R.Gdc_theta_phys = -Cthp * (Ad \ Bd);
    else
        R.Gdc_de = NaN;
        R.Gdc_theta_phys = NaN;
    end

    wgrid = logspace(-2, 2, 400);
    [mag, ~, wout] = bode(sys, wgrid);
    mag = squeeze(mag);
    R.bode_w = wout(:);
    R.bode_mag = mag(:);
    R.bw_plant_gamma_de = bandwidth_from_mag(wout, mag, abs(R.Gdc_de));

    cl = closed_loop_theta_c(R.Av, R.Bv, R.Cgamma_v, cascade);
    R.cl = cl;
    R.bw_theta_cl = cl.bw_theta_cmd;
    R.bw_gamma_from_theta = cl.bw_gamma_cmd;
    R.Gdc_gamma_from_theta = cl.Gdc_gamma;
    % Design separation: outer candidate at bw_theta/3 (always 3x by construction)
    R.w_outer_candidate = cl.w_outer_candidate;
    R.sep_design = 3.0;
    R.outer_flat_ok = cl.outer_flat_ok;
    R.mag_ratio_at_outer = cl.mag_ratio_at_outer;
    R.phase_at_outer = cl.phase_at_outer;
    % Legacy ratio of -3dB bandwidths (informational; ~1 if gamma~theta)
    R.sep_ratio = R.bw_theta_cl / max(R.bw_gamma_from_theta, 1e-9);
    R.cl_stable = cl.stable;
    R.headroom_de = cascade.delta_e_max - abs(R.u0(2));
    R.sensor = struct( ...
        'gamma_recon', 'gamma=-theta+atan2(w,u) BODY (phi=v=0 exact); else atan2(VD,Uh) NED', ...
        'gamma_dot_indi', sprintf(['INDI needs filtered gamma_dot; ' ...
            'G_delta=Cgamma*B_de=%.6g (rad/s)/rad'], R.G_delta), ...
        'noise', ['diff/filter amplifies u,w noise — INDI needs LPF; ' ...
            'outer PI uses gamma only (lower sensor burden)']);
end

function cl = closed_loop_theta_c(Av, Bv, Cgamma_v, cas)
    A = Av; Bde = Bv(:, 1);
    Kp_a = cas.Kp_angle; Ki_a = cas.Ki_angle;
    Kp_r = cas.Kp_rate; Kd = cas.Kd_damp; tau = cas.tau_rate; sg = cas.elevator_sign;

    Acl = zeros(7);
    Acl(1:5, 1:5) = A;
    Acl(1:5, 2) = Acl(1:5, 2) + Bde * (sg * Kp_r * Kp_a);
    Acl(1:5, 5) = Acl(1:5, 5) + Bde * (sg * Kp_r);
    Acl(1:5, 6) = Acl(1:5, 6) + Bde * (sg * Kp_r * Ki_a);
    Acl(1:5, 7) = Acl(1:5, 7) + Bde * (-sg * Kd);
    Acl(6, 2) = 1;
    Acl(7, 5) = -1 / tau;
    Acl(7, 7) = -1 / tau;

    Bcl = zeros(7, 1);
    Bcl(1:5) = Bde * (sg * Kp_r * Kp_a);
    Bcl(6) = 1;

    C_thp = zeros(1, 7); C_thp(2) = -1;
    C_gam = zeros(1, 7); C_gam(1:5) = Cgamma_v;

    sys_th = ss(Acl, Bcl, C_thp, 0);
    sys_ga = ss(Acl, Bcl, C_gam, 0);

    cl.Acl = Acl; cl.Bcl = Bcl;
    cl.eig = eig(Acl);
    cl.stable = all(real(cl.eig) < 1e-7);

    if rcond(Acl) > 1e-12
        cl.Gdc_theta = -C_thp * (Acl \ Bcl);
        cl.Gdc_gamma = -C_gam * (Acl \ Bcl);
    else
        iy = [2 3 4 5 6 7];
        Adc = Acl(iy, iy); Bdc = Bcl(iy);
        if rcond(Adc) > 1e-12
            cl.Gdc_theta = -C_thp(iy) * (Adc \ Bdc);
            cl.Gdc_gamma = -C_gam(iy) * (Adc \ Bdc);
        else
            cl.Gdc_theta = NaN;
            cl.Gdc_gamma = NaN;
        end
    end

    wgrid = logspace(-2, 2, 500);
    [mag_th, ~, w] = bode(sys_th, wgrid); mag_th = squeeze(mag_th);
    [mag_ga, ~, ~] = bode(sys_ga, wgrid); mag_ga = squeeze(mag_ga);
    cl.bw_theta_cmd = bandwidth_from_mag(w, mag_th, abs(cl.Gdc_theta));
    cl.bw_gamma_cmd = bandwidth_from_mag(w, mag_ga, abs(cl.Gdc_gamma));
    cl.w = w(:); cl.mag_th = mag_th(:); cl.mag_ga = mag_ga(:);

    % Phase of T_gamma for outer-loop feasibility at omega_theta/3
    [mag_ga_c, ph_ga, w2] = bode(sys_ga, wgrid);
    mag_ga_c = squeeze(mag_ga_c); ph_ga = squeeze(ph_ga);
    cl.phase_ga = ph_ga(:);
    w_outer = cl.bw_theta_cmd / 3;
    if isfinite(w_outer) && w_outer > 0
        cl.mag_at_outer = interp1(w2, mag_ga_c, w_outer, 'linear', 'extrap');
        ph = interp1(w2, ph_ga, w_outer, 'linear', 'extrap');
        cl.phase_at_outer = mod(ph + 180, 360) - 180;
        cl.mag_ratio_at_outer = cl.mag_at_outer / max(abs(cl.Gdc_gamma), 1e-12);
    else
        cl.mag_at_outer = NaN;
        cl.phase_at_outer = NaN;
        cl.mag_ratio_at_outer = NaN;
    end
    cl.w_outer_candidate = w_outer;
    % Outer PI supported at 3x-slow if T_gamma near DC there
    cl.outer_flat_ok = isfinite(cl.mag_ratio_at_outer) && isfinite(cl.phase_at_outer) ...
        && (cl.mag_ratio_at_outer >= 1/sqrt(2)) && (cl.mag_ratio_at_outer <= sqrt(2)) ...
        && (cl.phase_at_outer > -60);
end

function [rd, markov] = relative_degree(A, B, C, tol)
    n = size(A, 1);
    markov = zeros(n, 1);
    rd = NaN;
    AkB = B;
    for k = 1:n
        markov(k) = C * AkB;
        if isnan(rd) && abs(markov(k)) > tol
            rd = k;
        end
        AkB = A * AkB;
    end
    if isnan(rd)
        rd = Inf;
    end
end

function bw = bandwidth_from_mag(w, mag, G0)
    if ~(isfinite(G0)) || G0 < 1e-14
        bw = NaN;
        return;
    end
    thr = abs(G0) / sqrt(2);
    mag = mag(:); w = w(:);
    idx0 = find(w >= 1e-2, 1, 'first');
    if isempty(idx0); idx0 = 1; end
    hit = find(w >= w(idx0) & mag < thr, 1, 'first');
    if isempty(hit)
        bw = w(end);
    else
        bw = w(hit);
    end
end

function cmp = compare_ops(L, C)
    cmp.dGdc_rel = abs(C.Gdc_de - L.Gdc_de) / max(abs(L.Gdc_de), 1e-12);
    cmp.dGdelta_rel = abs(C.G_delta - L.G_delta) / max(abs(L.G_delta), 1e-12);
    cmp.sign_Gdc_same = sign(L.Gdc_de) == sign(C.Gdc_de) && sign(L.Gdc_de) ~= 0;
    cmp.sign_Gdelta_same = sign(L.G_delta) == sign(C.G_delta) && sign(L.G_delta) ~= 0;
    cmp.sep_level = L.sep_ratio;
    cmp.sep_climb = C.sep_ratio;
    cmp.sep_min = min(L.sep_ratio, C.sep_ratio);
    cmp.outer_flat_level = L.outer_flat_ok;
    cmp.outer_flat_climb = C.outer_flat_ok;
    cmp.outer_flat_both = L.outer_flat_ok && C.outer_flat_ok;
    cmp.mag_ratio_level = L.mag_ratio_at_outer;
    cmp.mag_ratio_climb = C.mag_ratio_at_outer;
    cmp.phase_outer_level = L.phase_at_outer;
    cmp.phase_outer_climb = C.phase_at_outer;
    cmp.w_outer_level = L.w_outer_candidate;
    cmp.w_outer_climb = C.w_outer_candidate;
    cmp.bw_theta_level = L.bw_theta_cl;
    cmp.bw_theta_climb = C.bw_theta_cl;
    cmp.bw_gamma_level = L.bw_gamma_from_theta;
    cmp.bw_gamma_climb = C.bw_gamma_from_theta;
    cmp.rhp_zero_any = L.has_rhp_zero || C.has_rhp_zero;
    cmp.cl_stable_both = L.cl_stable && C.cl_stable;
    cmp.cond_max = max(L.cond_Ad, C.cond_Ad);
    cmp.headroom_min = min(L.headroom_de, C.headroom_de);
    cmp.Gdc_level = L.Gdc_de;
    cmp.Gdc_climb = C.Gdc_de;
    cmp.Gdelta_level = L.G_delta;
    cmp.Gdelta_climb = C.G_delta;
    cmp.reldeg_level = L.reldeg_de;
    cmp.reldeg_climb = C.reldeg_de;
end

function trim_ev = extract_trim_alpha_evidence(T)
    trim_ev.verdict = char(T.verdict);
    trim_ev.next_opt = '';
    if isfield(T, 'next_opt'); trim_ev.next_opt = char(T.next_opt); end
    trim_ev.gates = T.gates;
    trim_ev.steady_gamma_note = ['FACT from TRIM_ALPHA_TWO_REPEAT_CLOSURE: ' ...
        'steady γ/CTE potential proved; persistent settle + peak/actuator gates FAIL; ' ...
        'cosine soft-start also FAIL — feedforward shaping stopped'];
    trim_ev.gate_summary = sprintf('closure verdict=%s', trim_ev.verdict);
    trim_ev.rows = struct();
end

function D = decide_architecture(L, C, cmp, trim_ev)
    D.literature = literature_block();
    D.criteria = struct();

    sign_ok = cmp.sign_Gdc_same && cmp.sign_Gdelta_same ...
        && isfinite(cmp.Gdc_level) && isfinite(cmp.Gdc_climb) ...
        && abs(cmp.Gdc_level) > 1e-3 && abs(cmp.Gdc_climb) > 1e-3;
    D.criteria.sign_ok = sign_ok;
    D.criteria.sign_detail = sprintf(['sign(Gdc) L/C=%+d/%+d  sign(Gδ) L/C=%+d/%+d  ' ...
        'Gdc=%.4g/%.4g  Gδ=%.4g/%.4g'], ...
        sign(cmp.Gdc_level), sign(cmp.Gdc_climb), ...
        sign(cmp.Gdelta_level), sign(cmp.Gdelta_climb), ...
        cmp.Gdc_level, cmp.Gdc_climb, cmp.Gdelta_level, cmp.Gdelta_climb);

    auth_ok = (cmp.headroom_min > deg2rad(5)) ...
        && (abs(cmp.Gdelta_level) > 1e-3) && (abs(cmp.Gdelta_climb) > 1e-3) ...
        && (cmp.dGdelta_rel < 0.5) && (cmp.dGdc_rel < 0.5);
    D.criteria.authority_ok = auth_ok;
    D.criteria.authority_detail = sprintf(['|Gdelta| L/C=%.4g/%.4g  dGdelta=%.1f%%  ' ...
        'Gdc L/C=%.4g/%.4g dGdc=%.1f%%  de headroom min=%.2f deg  cond(Ad) max=%.3g'], ...
        abs(cmp.Gdelta_level), abs(cmp.Gdelta_climb), 100*cmp.dGdelta_rel, ...
        cmp.Gdc_level, cmp.Gdc_climb, 100*cmp.dGdc_rel, ...
        rad2deg(cmp.headroom_min), cmp.cond_max);

    % 3x separation supported if inner stable and T_gamma flat/phase-OK at bw_theta/3
    sep_ok = cmp.cl_stable_both && cmp.outer_flat_both ...
        && isfinite(cmp.bw_theta_level) && isfinite(cmp.bw_theta_climb) ...
        && (cmp.bw_theta_level > 0.05) && (cmp.bw_theta_climb > 0.05);
    D.criteria.sep_ok = sep_ok;
    D.criteria.sep_detail = sprintf(['design sep=3 at w_outer=bw_θ/3: L=%.3f C=%.3f rad/s; ' ...
        ' |Tγ|/|Gdc| L/C=%.3f/%.3f  phase L/C=%.1f/%.1f deg; flat_ok L/C=%d/%d; ' ...
        'bw_θ=%.3f/%.3f  bw_γ←θcmd=%.3f/%.3f  cl_stable=%d'], ...
        cmp.w_outer_level, cmp.w_outer_climb, ...
        cmp.mag_ratio_level, cmp.mag_ratio_climb, ...
        cmp.phase_outer_level, cmp.phase_outer_climb, ...
        cmp.outer_flat_level, cmp.outer_flat_climb, ...
        cmp.bw_theta_level, cmp.bw_theta_climb, ...
        cmp.bw_gamma_level, cmp.bw_gamma_climb, cmp.cl_stable_both);

    rd_ok = (cmp.reldeg_level == 1) && (cmp.reldeg_climb == 1);
    D.criteria.reldeg_ok = rd_ok;
    D.criteria.reldeg_detail = sprintf('reldeg(γ←δe) L/C=%g/%g (INDI Gδ=Markov1)', ...
        cmp.reldeg_level, cmp.reldeg_climb);
    D.criteria.rhp_zero = cmp.rhp_zero_any;

    complete = all(isfinite([cmp.Gdc_level, cmp.Gdc_climb, cmp.Gdelta_level, ...
        cmp.Gdelta_climb, cmp.sep_min, cmp.bw_theta_level, cmp.bw_theta_climb]));
    D.criteria.complete = complete;

    if ~complete
        D.choice = 'UNKNOWN';
        D.reason = 'Incomplete quantitative margins (NaN bandwidth/gain).';
    elseif sign_ok && auth_ok && sep_ok
        D.choice = 'OUTER_GAMMA_PI_FIRST';
        D.reason = ['Sign-consistent effectiveness, authority/headroom (Gdc & Gdelta OP variation <50%), ' ...
            'and T_gamma near-DC at bw_theta/3 support slow bumpless outer gamma PI on existing theta/q cascade.'];
        if cmp.rhp_zero_any
            D.reason = [D.reason ' NOTE: open-loop gamma<-de has RHP zero — keep outer bandwidth well below it.'];
        end
    else
        D.choice = 'INDI_FIRST';
        why = {};
        if ~sign_ok; why{end+1} = 'sign consistency weak'; end
        if ~auth_ok; why{end+1} = 'authority gate failed (Gdc/Gdelta OP variation or headroom)'; end
        if ~sep_ok; why{end+1} = 'T_gamma not flat/phase-OK at bw_theta/3 (3x sep unsupported)'; end
        if cmp.rhp_zero_any; why{end+1} = 'RHP zero in open-loop gamma<-de (NMP inverse response)'; end
        if isempty(why); why{end+1} = 'default to INDI when PI gates not all clear'; end
        D.reason = ['INDI_FIRST: ' strjoin(why, '; ') ...
            '. Reldeg-1 gives direct Gdelta=Cgamma*B_de (dGdelta small vs dGdc) for filtered-gamma_dot INDI.'];
    end

    supported = complete && rd_ok && sign_ok ...
        && (strcmp(D.choice, 'OUTER_GAMMA_PI_FIRST') || strcmp(D.choice, 'INDI_FIRST'));
    if supported
        D.verdict = 'PASS';
    elseif ~complete
        D.verdict = 'UNKNOWN';
    else
        D.verdict = 'FAIL';
    end

    D.trim_alpha = trim_ev.steady_gamma_note;
    D.next = next_after(D.choice);
    D.failure_modes = failure_modes(D.choice, cmp);
    D.pi_sketch = ['theta_cmd = gamma_path + Kpg*e_gamma + Kig*int(e_gamma) ' ...
        'with rate/angle/antiwindup limits (NO gains designed here)'];
    D.indi_sketch = ['de = de0 + Gdelta^+ (gamma_dot_ref_f - gamma_dot_f); needs filtered gamma_dot & Gdelta=Cgamma*B_de ' ...
        '(NO gains designed here)'];
end

function nxt = next_after(choice)
    switch choice
        case 'OUTER_GAMMA_PI_FIRST'
            nxt = 'implement_outer_gamma_PI_bumpless_scaffold';
        case 'INDI_FIRST'
            nxt = 'implement_incremental_gamma_INDI_scaffold';
        otherwise
            nxt = 'gather_missing_LTI_margins';
    end
end

function fm = failure_modes(choice, cmp)
    fm = {
        sprintf('Gdelta OP variation %.1f%% (schedule/mismatch risk)', 100*cmp.dGdelta_rel)
        'Helix: BODY alpha approx when phi/v nonzero — resid=gamma_NED-(theta_phys+alpha)'
        'Outer PI: integrator windup on elevator sat / rate limit during acquisition'
        'INDI: gamma_dot filter lag/noise -> chatter; bad Gdelta -> wrong increment'
        'Unmodeled thrust coupling on gamma (Gdelta_thrust nonzero)'
        sprintf('Open-loop RHP plant poles present; relies on inner cascade (stable=%d)', cmp.cl_stable_both)
        };
    if strcmp(choice, 'OUTER_GAMMA_PI_FIRST')
        fm{end+1} = 'If sep eroded by gain schedule, outer PI can fight inner theta loop';
    else
        fm{end+1} = 'INDI without reliable gamma_dot estimate fails on noisy BODY u,w';
    end
end

function lit = literature_block()
    lit = {
        struct('cite', 'Yu et al., Ocean Eng. 2022, DOI 10.1016/j.oceaneng.2022.112458', ...
               'use', 'INFERENCE: hierarchical ALOS + disturbance-rejection motivates outer path-angle layer with inner attitude — not copied as gains')
        struct('cite', 'Petrich & Stilwell, Ocean Eng. 2010, DOI 10.1016/j.oceaneng.2009.11.007', ...
               'use', 'INFERENCE: third-order AUV pitch model justifies reduced vertical [theta,w,q]-like dynamics; our 5-state vertical embeds that plus z,u')
        struct('cite', 'Smeur et al., INDI cascade, arXiv:1701.07254', ...
               'use', 'INFERENCE: incremental nonlinear dynamic inversion cascade pattern for filtered derivative + control-effectiveness inversion')
        };
end

function write_png(png_path, L, C, cmp, D, task_id)
    fig = figure('Visible', 'off', 'Color', 'w', 'Position', [100 100 1100 720]);

    subplot(2, 2, 1);
    loglog(L.bode_w, L.bode_mag, 'b-', 'LineWidth', 1.4); hold on;
    loglog(C.bode_w, C.bode_mag, 'r-', 'LineWidth', 1.4);
    grid on;
    xlabel('\omega [rad/s]'); ylabel('|G_{\gamma/\delta_e}|');
    title('Open-loop elevator to gamma (vertical reduced)', 'Interpreter','none');
    legend('level', 'climb', 'Location', 'southwest');

    subplot(2, 2, 2);
    loglog(L.cl.w, L.cl.mag_th, 'b-', 'LineWidth', 1.4); hold on;
    loglog(L.cl.w, L.cl.mag_ga, 'b--', 'LineWidth', 1.2);
    loglog(C.cl.w, C.cl.mag_th, 'r-', 'LineWidth', 1.4);
    loglog(C.cl.w, C.cl.mag_ga, 'r--', 'LineWidth', 1.2);
    grid on;
    xlabel('\omega [rad/s]'); ylabel('|T|');
    title('Closed-loop theta_phys/theta_cmd vs gamma/theta_cmd', 'Interpreter','none');
    legend('L \theta', 'L \gamma', 'C \theta', 'C \gamma', 'Location', 'southwest');

    subplot(2, 2, 3);
    bar([1 2 3 4], [cmp.mag_ratio_level, cmp.mag_ratio_climb, ...
        double(cmp.outer_flat_level), double(cmp.outer_flat_climb)], 0.6);
    hold on;
    yline(1, 'k--', 'LineWidth', 1.0);
    set(gca, 'XTick', [1 2 3 4], 'XTickLabel', {'|T|/Gdc L', '|T|/Gdc C', 'flat L', 'flat C'});
    ylabel('T_\gamma margin at \omega_\theta/3');
    title(sprintf('3x-sep plant test (flat need YES); both=%d', cmp.outer_flat_both));
    grid on;

    subplot(2, 2, 4);
    axis off;
    txt = {
        task_id
        sprintf('Decision: %s', D.choice)
        sprintf('Verdict: %s', D.verdict)
        sprintf('Gdc L/C: %.3g / %.3g', cmp.Gdc_level, cmp.Gdc_climb)
        sprintf('Gdelta L/C: %.3g / %.3g', cmp.Gdelta_level, cmp.Gdelta_climb)
        sprintf('reldeg L/C: %g / %g', cmp.reldeg_level, cmp.reldeg_climb)
        sprintf('3x flat_ok L/C: %d/%d', cmp.outer_flat_level, cmp.outer_flat_climb)
        sprintf('RHP zero: %s', tern(cmp.rhp_zero_any,'YES','NO'))
        };
    text(0.02, 0.95, txt, 'VerticalAlignment', 'top', 'FontName', 'FixedWidth', ...
        'FontSize', 10, 'Interpreter', 'none');

    exportgraphics(fig, png_path, 'Resolution', 140);
    close(fig);
end

function write_md(md_path, task_id, verdict, D, L, C, cmp, trim_ev, cascade, ...
        src_level, src_climb, src_trim, md_p, mat_p, png_p)

    fid = fopen(md_path, 'w');
    fprintf(fid, '# %s — Outer gamma PI vs INDI architecture audit\n\n', task_id);
    fprintf(fid, '**Overall verdict: %s**\n\n', verdict);
    fprintf(fid, '**Decision: `%s`**\n\n', D.choice);

    fprintf(fid, '## Provenance\n\n');
    fprintf(fid, '- Read-only: `%s`, `%s`, `%s`\n', src_level, src_climb, src_trim);
    fprintf(fid, '- Driver: `run_outer_gamma_indi_audit.m` (one invocation; production untouched)\n');
    fprintf(fid, '- Artifacts: `%s`, `%s`, `%s`\n', md_p, mat_p, png_p);
    fprintf(fid, '- No controller edit; no gain design/sweep\n\n');

    fprintf(fid, '## Literature (cite; distinguish inference)\n\n');
    for i = 1:numel(D.literature)
        fprintf(fid, '%d. **%s**\n', i, D.literature{i}.cite);
        fprintf(fid, '   - %s\n', D.literature{i}.use);
    end
    fprintf(fid, '\n');

    fprintf(fid, '## Units / frames / equations (FACT)\n\n');
    fprintf(fid, '```\n');
    fprintf(fid, 'State x=[x y z phi theta psi u v w p q r]: NED [m], Euler ZYX [rad], BODY vel/rates\n');
    fprintf(fid, 'Input u=[delta_r, delta_e, thrust]: rad, rad, N\n');
    fprintf(fid, 'theta_phys = -theta\n');
    fprintf(fid, 'gamma = theta_phys + atan2(w,u)     [phi=0,v=0 exact]\n');
    fprintf(fid, '      = -theta + atan2(w,u)\n');
    fprintf(fid, 'Linear: dgamma = -dtheta + ( -w/(u^2+w^2) ) du + ( u/(u^2+w^2) ) dw\n');
    fprintf(fid, 'Cgamma_full on x: [0 0 0 0 -1 0  da/du  0  da/dw  0 0 0]\n');
    fprintf(fid, 'Cgamma_v on [z theta u w q]\n');
    fprintf(fid, 'Plant signs (LOCAL_SS): de>0 -> +Z/+M (Zuuds/Muuds*u^2)\n');
    fprintf(fid, '```\n\n');

    fprintf(fid, '## Cascade context (INFERENCE gains + FACT plant)\n\n');
    fprintf(fid, '```\n%s\n', cascade.source);
    fprintf(fid, 'Inner: e_theta -> q_cmd (Kp_angle,Ki_angle) -> de (Kp_rate,Kd_damp)\n');
    fprintf(fid, 'Outer PI sketch: %s\n', D.pi_sketch);
    fprintf(fid, 'INDI sketch: %s\n', D.indi_sketch);
    fprintf(fid, '```\n\n');

    fprintf(fid, '## Trim kinematics (FACT from LOCAL_SS x*)\n\n');
    fprintf(fid, '| OP | u* | w* | theta_phys [deg] | alpha [deg] | gamma_kin [deg] | de* [deg] |\n');
    fprintf(fid, '|---|---:|---:|---:|---:|---:|---:|\n');
    fprintf(fid, '| level | %.5f | %.5f | %.4f | %.4f | %.4f | %.4f |\n', ...
        L.trim.u, L.trim.w, rad2deg(L.trim.theta_phys), rad2deg(L.trim.alpha), ...
        L.trim.gamma_kin_deg, rad2deg(L.trim.de));
    fprintf(fid, '| climb | %.5f | %.5f | %.4f | %.4f | %.4f | %.4f |\n\n', ...
        C.trim.u, C.trim.w, rad2deg(C.trim.theta_phys), rad2deg(C.trim.alpha), ...
        C.trim.gamma_kin_deg, rad2deg(C.trim.de));

    fprintf(fid, '## Cgamma (vertical)\n\n');
    fprintf(fid, '```\n');
    fprintf(fid, 'level Cgamma_v = [%s]\n', num2str(L.Cgamma_v, ' %.8g'));
    fprintf(fid, 'climb Cgamma_v = [%s]\n', num2str(C.Cgamma_v, ' %.8g'));
    fprintf(fid, '```\n\n');

    fprintf(fid, '## Elevator to gamma effectiveness / relative degree / poles-zeros\n\n');
    fprintf(fid, '| Qty | level | climb | drel |\n');
    fprintf(fid, '|---|---:|---:|---:|\n');
    fprintf(fid, '| reldeg(gamma<-de) | %g | %g | — |\n', L.reldeg_de, C.reldeg_de);
    fprintf(fid, '| G_delta=Cgamma*B_de [(rad/s)/rad] | %.6g | %.6g | %.1f%% |\n', ...
        L.G_delta, C.G_delta, 100*cmp.dGdelta_rel);
    fprintf(fid, '| Gdc gamma/de [rad/rad] | %.6g | %.6g | %.1f%% |\n', ...
        L.Gdc_de, C.Gdc_de, 100*cmp.dGdc_rel);
    fprintf(fid, '| Gdc theta_phys/de | %.6g | %.6g | — |\n', L.Gdc_theta_phys, C.Gdc_theta_phys);
    fprintf(fid, '| cond(Ad) [theta u w q] | %.3g | %.3g | — |\n', L.cond_Ad, C.cond_Ad);
    fprintf(fid, '| RHP zero? | %s | %s | — |\n', tern(L.has_rhp_zero,'YES','NO'), tern(C.has_rhp_zero,'YES','NO'));
    fprintf(fid, '| open-loop RHP pole? | %s | %s | — |\n', tern(L.has_rhp_pole,'YES','NO'), tern(C.has_rhp_pole,'YES','NO'));
    fprintf(fid, '| de headroom [deg] | %.2f | %.2f | — |\n\n', rad2deg(L.headroom_de), rad2deg(C.headroom_de));

    fprintf(fid, '### Poles (Av) / zeros (gamma<-de)\n\n');
    fprintf(fid, 'level poles: %s\n\n', fmt_cvec(L.poles));
    fprintf(fid, 'level zeros: %s\n\n', fmt_cvec(L.zeros));
    fprintf(fid, 'climb poles: %s\n\n', fmt_cvec(C.poles));
    fprintf(fid, 'climb zeros: %s\n\n', fmt_cvec(C.zeros));

    fprintf(fid, '## Inner theta/q cascade vs outer gamma bandwidth\n\n');
    fprintf(fid, '| Qty | level | climb |\n');
    fprintf(fid, '|---|---:|---:|\n');
    fprintf(fid, '| cl stable | %d | %d |\n', L.cl_stable, C.cl_stable);
    fprintf(fid, '| bw theta_phys/theta_cmd [rad/s] | %.4f | %.4f |\n', L.bw_theta_cl, C.bw_theta_cl);
    fprintf(fid, '| bw gamma/theta_cmd [rad/s] | %.4f | %.4f |\n', L.bw_gamma_from_theta, C.bw_gamma_from_theta);
    fprintf(fid, '| bw ratio (info) | %.3f | %.3f |\n', L.sep_ratio, C.sep_ratio);
    fprintf(fid, '| w_outer=bw_theta/3 [rad/s] | %.4f | %.4f |\n', L.w_outer_candidate, C.w_outer_candidate);
    fprintf(fid, '| |T_gamma|/|Gdc| at w_outer | %.4f | %.4f |\n', L.mag_ratio_at_outer, C.mag_ratio_at_outer);
    fprintf(fid, '| phase T_gamma at w_outer [deg] | %.2f | %.2f |\n', L.phase_at_outer, C.phase_at_outer);
    fprintf(fid, '| flat/phase OK for 3x sep | %d | %d |\n', L.outer_flat_ok, C.outer_flat_ok);
    fprintf(fid, '| Gdc gamma/theta_cmd | %.4f | %.4f |\n\n', L.Gdc_gamma_from_theta, C.Gdc_gamma_from_theta);
    fprintf(fid, 'Gate: T_gamma near-DC at bw_theta/3 (design 3x) -> %s\n\n', ...
        tern(cmp.outer_flat_both,'PASS','FAIL'));

    fprintf(fid, '## PI vs INDI comparison (no gains)\n\n');
    fprintf(fid, '| Topic | Outer gamma PI on theta cascade | Incremental gamma INDI |\n');
    fprintf(fid, '|---|---|---|\n');
    fprintf(fid, '| Sensors | gamma (recon or NED V) | gamma and filtered gamma_dot; Gdelta |\n');
    fprintf(fid, '| Noise | lower (no derivative) | higher (gamma_dot LPF critical) |\n');
    fprintf(fid, '| Conditioning | needs stable Gdc and sep>=3 | needs well-conditioned Gdelta (reldeg-1 here) |\n');
    fprintf(fid, '| Actuator | bumpless theta_cmd + AW/rate/angle limits | incremental de about trim/current |\n');
    fprintf(fid, '| OP variation | schedule Kpg/Kig if Gdc drifts | schedule/adapt Gdelta (drel=%.1f%%) |\n', 100*cmp.dGdelta_rel);
    fprintf(fid, '| Failure modes | windup; fights inner if sep lost | wrong Gdelta; filter lag chatter |\n\n');

    fprintf(fid, '## TRIM_ALPHA closure evidence (FACT)\n\n');
    fprintf(fid, '- %s\n', trim_ev.steady_gamma_note);
    fprintf(fid, '- Closure verdict: **%s**\n\n', trim_ev.verdict);

    fprintf(fid, '## Decision gates\n\n');
    fprintf(fid, '| Gate | Result | Detail |\n');
    fprintf(fid, '|---|:---:|---|\n');
    fprintf(fid, '| Complete margins | %s | finite Gdc/Gdelta/bw both OPs |\n', tern(D.criteria.complete,'YES','NO'));
    fprintf(fid, '| Sign consistent | %s | %s |\n', tern(D.criteria.sign_ok,'YES','NO'), D.criteria.sign_detail);
    fprintf(fid, '| Authority/headroom | %s | %s |\n', tern(D.criteria.authority_ok,'YES','NO'), D.criteria.authority_detail);
    fprintf(fid, '| BW sep >=3 | %s | %s |\n', tern(D.criteria.sep_ok,'YES','NO'), D.criteria.sep_detail);
    fprintf(fid, '| Reldeg-1 (INDI-ready) | %s | %s |\n', tern(D.criteria.reldeg_ok,'YES','NO'), D.criteria.reldeg_detail);
    fprintf(fid, '| RHP zero absent | %s | — |\n\n', tern(~D.criteria.rhp_zero,'YES','NO'));

    fprintf(fid, '## Decision\n\n');
    fprintf(fid, '- Verdict: **%s**\n', verdict);
    fprintf(fid, '- Choice: **`%s`**\n', D.choice);
    fprintf(fid, '- Reason: %s\n', D.reason);
    fprintf(fid, '- Next: `%s`\n', D.next);
    fprintf(fid, '- Production: untouched\n\n');

    fprintf(fid, '### Failure modes\n\n');
    for i = 1:numel(D.failure_modes)
        fprintf(fid, '- %s\n', D.failure_modes{i});
    end
    fprintf(fid, '\n');

    fprintf(fid, '## Feedback\n\n');
    fprintf(fid, '- PASS/FAIL: **%s**\n', verdict);
    fprintf(fid, '- Decision: **%s**\n', D.choice);
    fprintf(fid, '- Evidence: Gdc L/C=%.4g/%.4g; Gdelta L/C=%.4g/%.4g; 3x-flat L/C=%d/%d; reldeg=%g/%g\n', ...
        cmp.Gdc_level, cmp.Gdc_climb, cmp.Gdelta_level, cmp.Gdelta_climb, ...
        cmp.outer_flat_level, cmp.outer_flat_climb, cmp.reldeg_level, cmp.reldeg_climb);
    fprintf(fid, '- Files: `%s` `%s` `%s`\n', md_p, mat_p, png_p);
    fprintf(fid, '- Next: `%s`\n', D.next);
    fclose(fid);
end

function append_ss_audit(out_dir, task_id, verdict, D, L, C, cmp, md_p, mat_p, png_p)
    audit_path = fullfile(out_dir, 'STATE_SPACE_MODEL_AUDIT.md');
    fid = fopen(audit_path, 'a');
    fprintf(fid, '\n\n---\n\n');
    fprintf(fid, '## %s — %s\n\n', task_id, datestr(now, 31));
    fprintf(fid, '### Provenance\n\n');
    fprintf(fid, '- Read-only: `LOCAL_SS_LEVEL.mat`, `LOCAL_SS_CLIMB.mat`, `TRIM_ALPHA_TWO_REPEAT_CLOSURE.mat`\n');
    fprintf(fid, '- Driver: `run_outer_gamma_indi_audit.m` (one invocation; no controller edit)\n');
    fprintf(fid, '- Artifacts: `%s`, `%s`, `%s`\n\n', md_p, mat_p, png_p);
    fprintf(fid, '### Equations\n\n');
    fprintf(fid, '```\ngamma = -theta + atan2(w,u)\n');
    fprintf(fid, 'Cgamma_v=[0,-1,da/du,da/dw,0] on [z,theta,u,w,q]\n');
    fprintf(fid, 'G_delta = Cgamma*B_de  (reldeg-1 Markov)\n```\n\n');
    fprintf(fid, '### Key numbers\n\n');
    fprintf(fid, '| Qty | level | climb |\n|---|---:|---:|\n');
    fprintf(fid, '| Gdc gamma/de | %.6g | %.6g |\n', L.Gdc_de, C.Gdc_de);
    fprintf(fid, '| Gdelta | %.6g | %.6g |\n', L.G_delta, C.G_delta);
    fprintf(fid, '| reldeg | %g | %g |\n', L.reldeg_de, C.reldeg_de);
    fprintf(fid, '| |T_gamma|/Gdc at bw_th/3 | %.3f | %.3f |\n', L.mag_ratio_at_outer, C.mag_ratio_at_outer);
    fprintf(fid, '| 3x-flat OK | %d | %d |\n\n', L.outer_flat_ok, C.outer_flat_ok);
    fprintf(fid, '### Verdict / next\n\n');
    fprintf(fid, '- Verdict: **%s** | Decision: **`%s`**\n', verdict, D.choice);
    fprintf(fid, '- Reason: %s\n', D.reason);
    fprintf(fid, '- Next: `%s`\n', D.next);
    fprintf(fid, '- Production: untouched\n\n');
    fprintf(fid, '### Next\n\n');
    fprintf(fid, '- %s\n', D.next);
    fclose(fid);
end

function print_feedback(verdict, D, L, C, cmp, trim_ev, md_p, mat_p, png_p)
    fprintf('\n========== FEEDBACK ==========\n');
    fprintf('PASS/FAIL: %s\n', verdict);
    fprintf('decision: %s\n', D.choice);
    fprintf('evidence: Gdc L/C=%.4g/%.4g | Gdelta L/C=%.4g/%.4g | 3x-flat L/C=%d/%d | reldeg=%g/%g | RHP_z=%d\n', ...
        cmp.Gdc_level, cmp.Gdc_climb, cmp.Gdelta_level, cmp.Gdelta_climb, ...
        cmp.outer_flat_level, cmp.outer_flat_climb, cmp.reldeg_level, cmp.reldeg_climb, cmp.rhp_zero_any);
    fprintf('trim_alpha: %s\n', trim_ev.verdict);
    fprintf('next: %s\n', D.next);
    fprintf('files: %s | %s | %s\n', md_p, mat_p, png_p);
end

function s = fmt_cvec(v)
    if isempty(v)
        s = '(none)';
        return;
    end
    parts = cell(numel(v), 1);
    for i = 1:numel(v)
        parts{i} = sprintf('%.6g%+.6gi', real(v(i)), imag(v(i)));
    end
    s = strjoin(parts, ', ');
end

function s = tern(c, a, b)
    if c; s = a; else; s = b; end
end
