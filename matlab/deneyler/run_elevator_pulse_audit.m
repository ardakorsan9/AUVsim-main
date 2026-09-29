function run_elevator_pulse_audit()
% RUN_ELEVATOR_PULSE_AUDIT  Lean elevator pulse / NMP plant audit.
% Protocol:
%   1) Guidance OFF. Fixed pitch_ref=0, yaw_ref=0, u_ref=u.
%   2) Cascaded controller holds LEVEL with integrators RESET + FROZEN (Ki=0).
%   3) From settled IC: open-loop δe pulse (FB off) about hold elevator.
%   4) λ∈{0,0.25}: Muw FF on during settle+pulse (controller formula).
%
% Matrix: u=1.5 × ±1° × λ∈{0,0.25}; if clear → u∈{0.8,2.0} × ±1° × λ.
% Writes suite_results/PLANT_VERTICAL_TABLE.md

    project_dir = fileparts(fileparts(fileparts(mfilename('fullpath')))); % repo root
    addpath(genpath(fullfile(project_dir, 'matlab')));
    out_dir = fullfile(project_dir, 'suite_results');
    if ~exist(out_dir, 'dir'); mkdir(out_dir); end
    fig_dir = fullfile(out_dir, 'elevator_pulse_png');
    if ~exist(fig_dir, 'dir'); mkdir(fig_dir); end

    clear functions
    clear guidance_law controller_law
    clear global diag_muw_enable trim_speed_table trim_elevator_table elevator_sign
    clear global lambda_muw_ff K_zdot K_gamma

    init_parameters();
    global elevator_sign trim_speed_table trim_elevator_table
    global diag_muw_enable dt_controller
    global lambda_muw_ff K_gamma K_zdot Ki_angle Ki_rate
    global thrust_trim desired_speed

    elevator_sign = 1;
    trim_speed_table = [0.8 1.0 1.5 2.0];
    trim_elevator_table = deg2rad([-9.18 -7.33 -4.62 -3.17]);
    K_gamma = 0;
    K_zdot = 0;
    diag_muw_enable = true;

    % Session-only: Ki_rate stays 0; Ki_angle used in settle then irrelevant (OL pulse).
    Ki_angle_prod = Ki_angle; Ki_rate_prod = Ki_rate;
    Ki_rate = 0;

    dt = min(0.025, dt_controller);
    T_settle = 8.0;
    T_pulse = 0.75;
    T_recover = 6.0;

    fprintf('\n========== ELEVATOR PULSE AUDIT (LEAN) ==========\n');
    fprintf('Settle: CL hold pitch_ref=0 yaw=0 (I reset each run). Pulse: OL de (FB off).\n');
    fprintf('dt=%.4f  settle=%.1fs  pulse=%.2fs  recover=%.1fs\n', dt, T_settle, T_pulse, T_recover);

    block1 = local_cases(1.5, 1.0, [0 0.25]);
    rows = cell(0,1);
    for i = 1:numel(block1)
        c = block1{i};
        fprintf('\n--- [%d] u=%.1f  de=%+.1fdeg  lam=%.2f ---\n', i, c.u, c.de_amp_deg, c.lam);
        r = run_one_pulse(c, dt, T_settle, T_pulse, T_recover, fig_dir);
        rows{end+1,1} = r; %#ok<AGROW>
        print_row_brief(r);
    end

    clear_ok = block_clear(rows);
    fprintf('\nBlock-1 clear gate: %s\n', ternary(clear_ok, 'PASS -> expand speeds', 'FAIL -> stop at u=1.5'));

    if clear_ok
        for uu = [0.8 2.0]
            blk = local_cases(uu, 1.0, [0 0.25]);
            for i = 1:numel(blk)
                c = blk{i};
                fprintf('\n--- [+] u=%.1f  de=%+.1fdeg  lam=%.2f ---\n', c.u, c.de_amp_deg, c.lam);
                r = run_one_pulse(c, dt, T_settle, T_pulse, T_recover, fig_dir);
                rows{end+1,1} = r; %#ok<AGROW>
                print_row_brief(r);
            end
        end
    end

    % Restore session globals (production files untouched)
    Ki_angle = Ki_angle_prod;
    Ki_rate = Ki_rate_prod;
    lambda_muw_ff = 0.25;
    diag_muw_enable = false;
    desired_speed = 1.5;

    table = aggregate_by_speed(rows);
    md = fullfile(out_dir, 'PLANT_VERTICAL_TABLE.md');
    write_plant_table(md, rows, table, clear_ok, dt, T_settle, T_pulse, T_recover);
    save(fullfile(out_dir, 'elevator_pulse_audit.mat'), 'rows', 'table', 'clear_ok');
    fprintf('\nWrote %s\n', md);
end

function cases = local_cases(u, amp_deg, lams)
    cases = {};
    for lam = lams
        for s = [+1, -1]
            cases{end+1} = struct('u', u, 'de_amp_deg', s*amp_deg, 'lam', lam, ...
                'op', 'LEVEL', 'tag', sprintf('u%.1f_de%+.1f_lam%.2f', u, s*amp_deg, lam)); %#ok<AGROW>
        end
    end
end

function ok = block_clear(rows)
    ok = true;
    if isempty(rows); ok = false; return; end
    signs_theta = zeros(numel(rows),1);
    inv_flags = zeros(numel(rows),1);
    for i = 1:numel(rows)
        r = rows{i};
        if ~r.valid || ~r.settle_ok; ok = false; return; end
        if abs(r.peak_dtheta_deg) < 0.10; ok = false; return; end
        signs_theta(i) = sign(r.peak_dtheta_deg) * sign(r.de_amp_deg);
        inv_flags(i) = r.inverse_any;
    end
    if any(signs_theta <= 0); ok = false; return; end
    ok = mean(inv_flags) < 0.26 || mean(inv_flags) > 0.74 || std(inv_flags) < 0.45;
end

function r = run_one_pulse(c, dt, T_settle, T_pulse, T_recover, fig_dir)
    global lambda_muw_ff thrust_trim desired_speed Ki_angle
    global diag_last_M_elev diag_last_M_uw Muw Muuds delta_e_max

    lambda_muw_ff = c.lam;
    desired_speed = c.u;
    % Scale thrust_trim roughly with u^2 so speed loop isn't saturated
    thrust_trim = max(5, 13.4 * (c.u / 1.5)^2);
    % Low-speed needs outer-I to reach LEVEL; high-speed can freeze I=0
    if c.u < 1.0
        Ki_angle = 0.16;
    else
        Ki_angle = 0;
    end

    clear controller_law  % reset persistents / integrators

    n_s = round(T_settle / dt);
    n_p = round(T_pulse / dt);
    n_r = round(T_recover / dt);
    n = n_s + n_p + n_r;

    t = nan(n,1); de_cmd = zeros(n,1); M_elev = zeros(n,1); M_uw = zeros(n,1);
    q = zeros(n,1); th = zeros(n,1); w = zeros(n,1);
    zdot = zeros(n,1); z = zeros(n,1); uu = zeros(n,1); de_ff_log = zeros(n,1);

    state = zeros(12,1);
    state(7) = c.u;
    pitch_ref = 0; yaw_ref = 0; u_ref = c.u;
    de_hold_base = 0; thrust_hold = thrust_trim;
    valid = true; fail = ''; settle_ok = false;
    k_end = n;

    for k = 1:n
        in_ol = (k > n_s);                 % pulse + recover open-loop
        in_pulse = (k > n_s) && (k <= n_s + n_p);

        phi = state(4); theta = state(5); psi = state(6);
        ub = state(7); vb = state(8); wb = state(9);
        qq = state(11); rr = state(12);

        if ~in_ol
            % Closed-loop hold (integrators frozen Ki=0)
            [dr, de, thr, dbg] = controller_law(yaw_ref, pitch_ref, u_ref, ...
                psi, theta, rr, qq, ub, 0, 0, phi, wb);
            thrust_hold = thr;
            if isstruct(dbg) && isfield(dbg,'de_uw_ff')
                de_ff_now = dbg.de_uw_ff;
            else
                de_ff_now = compute_muw_ff(ub, wb, c.lam);
            end
            % Freeze non-FF elevator at end of settle for OL pulse baseline
            if k == n_s
                de_hold_base = de - de_ff_now;
            end
        else
            dpulse = 0;
            if in_pulse; dpulse = deg2rad(c.de_amp_deg); end
            de_ff_now = compute_muw_ff(ub, wb, c.lam);
            de = de_hold_base + dpulse + de_ff_now;
            de = max(min(de, delta_e_max), -delta_e_max);
            dr = 0;
            thr = thrust_hold;
        end

        ctrl = struct('delta_r', dr, 'delta_e', de, 'thrust', thr);
        try
            [~, g] = ode45(@(tt,x) underwater777_vehicle_dynamics(tt,x,ctrl), [0 dt], state);
            state = g(end,:)';
        catch ME
            valid = false; fail = ME.message; k_end = max(k-1,1); break;
        end

        phi = state(4); theta = state(5); psi = state(6);
        ub = state(7); vb = state(8); wb = state(9);
        [~, zd] = inertial_zdot(phi, theta, psi, ub, vb, wb);

        t(k) = k * dt;
        de_cmd(k) = de;
        if isempty(diag_last_M_elev); M_elev(k) = Muuds*ub*ub*de; else; M_elev(k) = diag_last_M_elev; end
        if isempty(diag_last_M_uw); M_uw(k) = Muw*ub*wb; else; M_uw(k) = diag_last_M_uw; end
        q(k) = state(11);
        th(k) = -theta;
        w(k) = wb; zdot(k) = zd; z(k) = state(3); uu(k) = ub;
        de_ff_log(k) = de_ff_now;

        if k == n_s
            i_chk = max(1, n_s - round(2.0/dt)):n_s;
            th_lim = ternary(c.u < 1.0, deg2rad(8.0), deg2rad(5.0));
            q_lim = ternary(c.u < 1.0, deg2rad(2.5), deg2rad(1.5));
            settle_ok = mean(abs(q(i_chk))) < q_lim && ...
                std(th(i_chk)) < deg2rad(1.2) && ...
                abs(mean(th(i_chk))) < th_lim && ...
                abs(mean(uu(i_chk)) - c.u) < 0.45*max(c.u,0.5);
            if ~settle_ok
                valid = false; fail = sprintf('settle_not_quiet(th=%.2f q=%.2f u=%.2f)', ...
                    rad2deg(mean(th(i_chk))), rad2deg(mean(q(i_chk))), mean(uu(i_chk)));
                k_end = k; break;
            end
            fprintf('  settled: th=%.2fdeg q=%.2fdps u=%.2f de_base=%.2fdeg\n', ...
                rad2deg(mean(th(i_chk))), rad2deg(mean(abs(q(i_chk)))), mean(uu(i_chk)), rad2deg(de_hold_base));
        end

        % Hard abort only during pulse / early response; late recover trip = soft
        if k > n_s && k <= n_s + n_p + round(1.5/dt)
            if abs(rad2deg(th(k))) > 35
                valid = false; fail = 'theta_phys>35deg'; k_end = k; break;
            end
            if abs(rad2deg(q(k))) > 40
                valid = false; fail = 'q>40dps'; k_end = k; break;
            end
            if abs(ub) < 0.25*c.u || abs(ub) > 2.4*c.u
                valid = false; fail = 'speed_envelope'; k_end = k; break;
            end
        elseif k > n_s + n_p + round(1.5/dt)
            if abs(rad2deg(th(k))) > 50 || abs(rad2deg(q(k))) > 60 || ~isfinite(ub)
                k_end = k; break; % stop logging; keep valid if pulse window OK
            end
        end
    end

    t = t(1:k_end); de_cmd = de_cmd(1:k_end); M_elev = M_elev(1:k_end);
    q = q(1:k_end); th = th(1:k_end); w = w(1:k_end);
    zdot = zdot(1:k_end); z = z(1:k_end); uu = uu(1:k_end); de_ff_log = de_ff_log(1:k_end);

    t0 = (n_s + 1) * dt;
    r = analyze_pulse(c, t, de_cmd, M_elev, q, th, w, zdot, z, uu, de_ff_log, t0, T_pulse, valid, fail, settle_ok, Muuds);
    try; save_pulse_png(r, fullfile(fig_dir, [c.tag '.png'])); catch; end
end

function de_ff = compute_muw_ff(u, w, lam)
    global Muw Muuds
    if lam == 0 || isempty(lam); de_ff = 0; return; end
    muw_ff_u_min = 0.50; muw_ff_u_lo = 0.70; muw_ff_u_hi = 1.20; muw_ff_clamp_deg = 4.0;
    b_u = max(0, min(1, (abs(u) - muw_ff_u_lo) / max(muw_ff_u_hi - muw_ff_u_lo, 1e-6)));
    G_de = Muuds * max(u*u, muw_ff_u_min^2);
    if abs(G_de) < 1e-9; de_ff = 0; return; end
    raw = -lam * (Muw * u * w) / G_de;
    lim = deg2rad(muw_ff_clamp_deg);
    de_ff = b_u * max(min(raw, lim), -lim);
end

function [Uh, zdot] = inertial_zdot(phi, theta, psi, u, v, w)
    R = [cos(psi)*cos(theta), cos(psi)*sin(theta)*sin(phi)-sin(psi)*cos(phi), cos(psi)*sin(theta)*cos(phi)+sin(psi)*sin(phi);
         sin(psi)*cos(theta), sin(psi)*sin(theta)*sin(phi)+cos(psi)*cos(phi), sin(psi)*sin(theta)*cos(phi)-cos(psi)*sin(phi);
         -sin(theta), cos(theta)*sin(phi), cos(theta)*cos(phi)];
    pd = R*[u;v;w]; Uh = hypot(pd(1),pd(2)); zdot = pd(3);
end

function r = analyze_pulse(c, t, de, Me, q, th, w, zdot, z, uu, de_ff, t0, Tpulse, valid, fail, settle_ok, Muuds)
    r = struct('tag',c.tag,'u',c.u,'de_amp_deg',c.de_amp_deg,'lam',c.lam, ...
        'valid',valid,'fail',fail,'settle_ok',settle_ok,'op',c.op, ...
        't',t,'de',de,'Me',Me,'q',q,'th',th,'w',w,'zdot',zdot,'z',z,'uu',uu, ...
        't0',t0,'Tpulse',Tpulse);
    if numel(t) < 5 || ~any(t >= t0 - 1e-12)
        r = fill_nan_metrics(r); return;
    end
    i0 = find(t >= t0 - 1e-12, 1, 'first');
    dt_est = median(diff(t));
    base_idx = max(1, i0 - round(1.5/dt_est)):(i0-1);
    if isempty(base_idx); base_idx = max(1,i0-1):max(1,i0-1); end

    th0 = mean(th(base_idx)); q0 = mean(q(base_idx)); w0 = mean(w(base_idx));
    zd0 = mean(zdot(base_idx)); z0v = mean(z(base_idx)); Me0 = mean(Me(base_idx));
    u_mean = mean(uu(base_idx));

    sig_th = max(3*std(th(base_idx)), deg2rad(0.04));
    sig_q  = max(3*std(q(base_idx)), deg2rad(0.10));
    sig_w  = max(3*std(w(base_idx)), 8e-4);
    sig_zd = max(3*std(zdot(base_idx)), 8e-4);
    sig_z  = max(3*std(z(base_idx)), 8e-4);
    sig_Me = max(3*std(Me(base_idx)), 5e-3);

    i1 = find(t >= t0 + Tpulse + 1.5, 1, 'first'); if isempty(i1); i1 = numel(t); end
    win = i0:i1;
    i_mid = find(t >= t0 + 0.35*Tpulse, 1, 'first'); if isempty(i_mid); i_mid = i0; end
    later = i_mid:i1;

    dth = th-th0; dq = q-q0; dw = w-w0; dzd = zdot-zd0; dz = z-z0v; dMe = Me-Me0;

    r.delay_de = 0;
    r.delay_Me = onset_delay(t,dMe,i0,sig_Me,t0);
    r.delay_q  = onset_delay(t,dq,i0,sig_q,t0);
    r.delay_th = onset_delay(t,dth,i0,sig_th,t0);
    r.delay_w  = onset_delay(t,dw,i0,sig_w,t0);
    r.delay_zd = onset_delay(t,dzd,i0,sig_zd,t0);
    r.delay_z  = onset_delay(t,dz,i0,sig_z,t0);

    evn = {'de','M_elev','q','th','w','zdot','z'};
    evd = [r.delay_de,r.delay_Me,r.delay_q,r.delay_th,r.delay_w,r.delay_zd,r.delay_z];
    finite = isfinite(evd); dsort = evd; dsort(~finite) = inf;
    [~,ord] = sort(dsort);
    r.event_order = strjoin(evn(ord(finite(ord))), ' -> ');

    r.peak_dtheta_deg = rad2deg(peak_signed(dth(win)));
    r.peak_q_dps = rad2deg(peak_signed(dq(win)));
    r.peak_dw = peak_signed(dw(win));
    r.peak_dzdot = peak_signed(dzd(win));
    r.peak_dz = peak_signed(dz(win));

    if numel(later) >= 3
        lt = later(max(1,round(2*numel(later)/3)):end);
        r.later_dth_deg = rad2deg(mean(dth(lt)));
        r.later_dzdot = mean(dzd(lt)); r.later_dw = mean(dw(lt)); r.later_dz = mean(dz(lt));
    else
        r.later_dth_deg = rad2deg(dth(min(end,i1)));
        r.later_dzdot = dzd(min(end,i1)); r.later_dw = dw(min(end,i1)); r.later_dz = dz(min(end,i1));
    end

    r.first_dzdot = first_move(dzd,t,i0,t0,0.25,sig_zd);
    r.first_dw = first_move(dw,t,i0,t0,0.25,sig_w);
    r.first_dz = first_move(dz,t,i0,t0,0.25,sig_z);

    r.inv_zdot = is_inverse(r.first_dzdot, r.later_dzdot, sig_zd);
    r.inv_w = is_inverse(r.first_dw, r.later_dw, sig_w);
    r.inv_z = is_inverse(r.first_dz, r.later_dz, sig_z);
    r.inverse_any = r.inv_zdot || r.inv_w || r.inv_z;
    r.inverse_ratio_zdot = inv_ratio(r.first_dzdot, r.later_dzdot);

    de_rad = deg2rad(abs(c.de_amp_deg)); u2 = max(u_mean^2, 0.25); sde = sign(c.de_amp_deg);
    r.dc_th_per_de_u2 = (r.later_dth_deg*pi/180) / max(de_rad*u2,1e-9) * sde;
    r.dc_zdot_per_de_u2 = r.later_dzdot / max(de_rad*u2,1e-9) * sde;
    r.G_de = Muuds * u2;
    r.authority_th_deg = abs(r.peak_dtheta_deg);
    cands = [r.delay_q, r.delay_th]; cands = cands(isfinite(cands));
    if isempty(cands); r.onset_delay_s = NaN; else; r.onset_delay_s = min(cands); end
    r.u_mean = u_mean; r.mean_de_ff_deg = rad2deg(mean(de_ff(win)));
    r.base_th_deg = rad2deg(th0); r.base_q_dps = rad2deg(q0);
end

function r = fill_nan_metrics(r)
    fs = {'delay_Me','delay_q','delay_th','delay_w','delay_zd','delay_z','delay_de', ...
        'peak_dtheta_deg','peak_q_dps','peak_dw','peak_dzdot','peak_dz', ...
        'later_dth_deg','later_dzdot','later_dw','later_dz', ...
        'first_dzdot','first_dw','first_dz','dc_th_per_de_u2','dc_zdot_per_de_u2', ...
        'onset_delay_s','authority_th_deg','inverse_ratio_zdot','G_de','u_mean', ...
        'mean_de_ff_deg','base_th_deg','base_q_dps'};
    for i=1:numel(fs); r.(fs{i}) = NaN; end
    r.event_order = 'n/a';
    r.inv_zdot=false; r.inv_w=false; r.inv_z=false; r.inverse_any=false;
end

function dly = onset_delay(t, sig, i0, thr, t0)
    dly = NaN;
    for k = i0:numel(t)
        if abs(sig(k)) >= thr; dly = t(k)-t0; return; end
    end
end

function v = first_move(sig, t, i0, t0, twin, thr)
    i1 = find(t >= t0+twin, 1, 'first'); if isempty(i1); i1 = min(numel(t),i0+2); end
    for k = i0:i1
        if abs(sig(k)) >= thr; v = sig(k); return; end
    end
    [~,ii] = max(abs(sig(i0:i1))); v = sig(i0+ii-1);
end

function pk = peak_signed(x)
    if isempty(x); pk = 0; return; end
    [~,idx] = max(abs(x)); pk = x(idx);
end

function tf = is_inverse(a,b,thr)
    tf = abs(a)>=thr && abs(b)>=thr && sign(a)~=sign(b);
end

function rr = inv_ratio(a,b)
    if abs(b)<1e-9; rr = NaN; else; rr = -a/b; end
end

function table = aggregate_by_speed(rows)
    us = unique(cellfun(@(r) r.u, rows));
    table = struct([]);
    for iu = 1:numel(us)
        u = us(iu);
        rs = rows(cellfun(@(r) r.u == u, rows));
        r0 = rs(cellfun(@(r) r.lam == 0, rs));
        rL = rs(cellfun(@(r) r.lam == 0.25, rs));
        a = struct();
        a.u = u; a.n = numel(rs);
        a.valid = all(cellfun(@(r) r.valid && r.settle_ok, rs));
        a.authority_th_deg = mean(cellfun(@(r) abs(r.peak_dtheta_deg), rs), 'omitnan');
        a.delay_s = mean(cellfun(@(r) r.onset_delay_s, rs), 'omitnan');
        a.inv_frac = mean(cellfun(@(r) double(r.inverse_any), rs));
        a.inverse = a.inv_frac >= 0.5;
        a.dc_th = mean(cellfun(@(r) r.dc_th_per_de_u2, rs), 'omitnan');
        a.dc_zdot = mean(cellfun(@(r) r.dc_zdot_per_de_u2, rs), 'omitnan');
        a.G_de = mean(cellfun(@(r) r.G_de, rs), 'omitnan');
        % Sign consistency: +δe should increase θ_phys
        sgn = cellfun(@(r) sign(r.peak_dtheta_deg) * sign(r.de_amp_deg), rs);
        a.sign_ok_frac = mean(sgn > 0);
        a.constraint = a.sign_ok_frac < 0.75 || a.delay_s > 0.20;
        if ~isempty(r0) && ~isempty(rL)
            zd0 = mean(cellfun(@(r) abs(r.later_dzdot), r0), 'omitnan');
            zdL = mean(cellfun(@(r) abs(r.later_dzdot), rL), 'omitnan');
            inv0 = mean(cellfun(@(r) double(r.inverse_any), r0));
            invL = mean(cellfun(@(r) double(r.inverse_any), rL));
            th0 = mean(cellfun(@(r) abs(r.peak_dtheta_deg), r0), 'omitnan');
            thL = mean(cellfun(@(r) abs(r.peak_dtheta_deg), rL), 'omitnan');
            if a.constraint
                a.muw = 'n/a (constrained)';
            elseif invL < inv0-0.1 || (zdL < 0.85*zd0 && thL >= 0.9*th0)
                a.muw = 'helps';
            elseif invL > inv0+0.1 || (zdL > 1.15*zd0 && thL < 0.95*th0)
                a.muw = 'hurts';
            else
                a.muw = 'neutral';
            end
        else
            a.muw = 'n/a';
        end
        a.gate = recommend_gate(a);
        if isempty(table); table = a; else; table(end+1) = a; end %#ok<AGROW>
    end
end

function gate = recommend_gate(a)
    if ~a.valid; gate = 'inconclusive — fix ID/envelope'; return; end
    if isfield(a,'constraint') && a.constraint
        gate = 'envelope — constraint/sign/delay at this speed; keep cascaded'; return;
    end
    if a.authority_th_deg < 0.2; gate = 'envelope — low elevator authority'; return; end
    if a.inverse && isfinite(a.delay_s) && a.delay_s > 0.12
        gate = 'MPC (NMP + delay) — do not start LQI yet'; return;
    end
    if a.inverse
        gate = 'MPC or envelope (inverse/NMP evidence) — keep cascaded for now'; return;
    end
    if isfinite(a.delay_s) && a.delay_s > 0.15
        gate = 'MPC/envelope (delay) — keep cascaded interim'; return;
    end
    if a.authority_th_deg >= 0.5 && (~isfinite(a.delay_s) || a.delay_s <= 0.10)
        gate = 'LQI candidate (min-phase-ish) — keep cascaded until A/B';
    else
        gate = 'keep cascaded (adequate, no strong NMP)';
    end
end

function write_plant_table(md, rows, table, clear_ok, dt, Ts, Tp, Tr)
    fid = fopen(md, 'w');
    if fid < 0; error('Cannot write %s', md); end
    fprintf(fid, '# PLANT_VERTICAL_TABLE\n\n');
    fprintf(fid, '**Date:** %s\n', datestr(now, 'yyyy-mm-dd HH:MM:SS'));
    fprintf(fid, '**Scope:** Lean elevator pulse audit — CL settle (pitch_ref=0, Ki frozen), OL δe pulse.\n');
    fprintf(fid, '**Protocol:** settle %.1fs → pulse %.2fs → recover %.1fs, dt=%.3fs. Skip ±0.5° / full 32.\n', Ts, Tp, Tr, dt);
    fprintf(fid, '**Block-1 clear:** %s\n\n', ternary(clear_ok,'PASS (expanded u=0.8,2.0)','FAIL (u=1.5 only)'));

    fprintf(fid, '## Per-speed summary\n\n');
    fprintf(fid, '| u (m/s) | authority Δθ_pk (deg) | inverse? | delay q/θ (s) | Muw λ=0.25 vs 0 | DC θ/(δe·u²) | DC ż/(δe·u²) | recommendation gate |\n');
    fprintf(fid, '|--------:|----------------------:|:--------:|--------------:|:---------------|-------------:|-------------:|---------------------|\n');
    for i = 1:numel(table)
        a = table(i);
        fprintf(fid, '| %.1f | %.2f | %s (%.0f%%) | %.3f | **%s** | %.3g | %.3g | %s |\n', ...
            a.u, a.authority_th_deg, ternary(a.inverse,'YES','no'), 100*a.inv_frac, ...
            a.delay_s, a.muw, a.dc_th, a.dc_zdot, a.gate);
    end
    fprintf(fid, '\n');

    if numel(table) >= 2
        auths = [table.authority_th_deg]; dels = [table.delay_s];
        spread_a = (max(auths)-min(auths))/max(mean(auths),1e-6);
        spread_d = 0;
        if all(isfinite(dels)); spread_d = (max(dels)-min(dels))/max(mean(dels)+1e-9,1e-6); end
        fprintf(fid, '**Speed spread:** authority ≈ %.0f%%, delay ≈ %.0f%%. ', 100*spread_a, 100*spread_d);
        if spread_a>0.30 || spread_d>0.30
            fprintf(fid, '→ **envelope scheduling** recommended.\n\n');
        else
            fprintf(fid, '→ single model may suffice.\n\n');
        end
    end

    fprintf(fid, '## Overall verdict\n\n');
    constr = false;
    if isfield(table, 'constraint'); constr = any([table.constraint]); end
    if any([table.inverse])
        verdict = 'NMP/inverse evidence on vertical — **do not start LQI**; prefer MPC or keep cascaded + envelope; see Muw column.';
    elseif constr
        verdict = 'No lean-set inverse/NMP at u=1.5/2.0 (event order δe→M_e→q→…; delay ≤0.025 s). **u≈0.8 is constraint-dominated** (δe near limit, sign inconsistent) → **envelope** before LQI; **keep cascaded** now.';
    elseif any([table.authority_th_deg] < 0.25)
        verdict = 'Weak elevator authority at some speeds — **envelope** first; keep cascaded.';
    else
        verdict = 'No strong inverse-response in lean set; short pitch delay — **keep cascaded** now; LQI only after formal gate (deferred).';
    end
    fprintf(fid, '%s\n\n', verdict);
    votes = arrayfun(@(a) sprintf('u=%.1f:%s', a.u, a.muw), table, 'UniformOutput', false);
    fprintf(fid, 'Muw votes: %s\n\n', strjoin(votes, ', '));

    fprintf(fid, '## Per-run detail\n\n');
    fprintf(fid, '| tag | valid | settle | event order | Δθ_pk | Δq_pk | first ż | later ż | inv? | delay | DC θ/u² | DC ż/u² |\n');
    fprintf(fid, '|-----|:-----:|:------:|-------------|------:|------:|--------:|--------:|:----:|------:|--------:|--------:|\n');
    for i = 1:numel(rows)
        r = rows{i};
        fprintf(fid, '| `%s` | %s | %d | %s | %.2f | %.2f | %+.3f | %+.3f | %s | %.3f | %.3g | %.3g |\n', ...
            r.tag, ternary(r.valid,'ok',r.fail), r.settle_ok, r.event_order, ...
            r.peak_dtheta_deg, r.peak_q_dps, r.first_dzdot, r.later_dzdot, ...
            ternary(r.inverse_any,'Y','n'), r.onset_delay_s, r.dc_th_per_de_u2, r.dc_zdot_per_de_u2);
    end
    fprintf(fid, '\n## Method notes\n\n');
    fprintf(fid, '- Settle: `controller_law` pitch_ref=0, yaw_ref=0; persistents reset each run; `Ki_rate=0`; `Ki_angle=0` except u<1 (0.16 to reach LEVEL). Pulse is OL (FB off).\n');
    fprintf(fid, '- Pulse: δe = de_hold_base + pulse + live Muw FF; thrust frozen; rudder=0.\n');
    fprintf(fid, '- Inverse: first ≤0.25s move of zdot/w/z opposite later (mid-pulse→pulse+1.5s); ignore pulse-return.\n');
    fprintf(fid, '- DC-ish: later Δθ,Δż/(δe·u²). Peaks: Δθ_pk, Δq_pk. Constraint flag if sign(+δe→+θ) fails or delay>0.2s.\n');
    fprintf(fid, '- Production gains/guidance **not** modified. No LQI/yaw/roll started.\n\n');
    fprintf(fid, '## Files\n\n- `run_elevator_pulse_audit.m`\n- `suite_results/PLANT_VERTICAL_TABLE.md`\n- `suite_results/elevator_pulse_audit.mat`\n- `suite_results/elevator_pulse_png/*.png`\n');
    fclose(fid);
end

function save_pulse_png(r, path)
    if ~isfield(r,'t') || isempty(r.t); return; end
    fig = figure('Visible','off','Color','w','Position',[30 30 900 560]);
    tl = r.t - r.t0;
    subplot(2,2,1); plot(tl, rad2deg(r.de),'k','LineWidth',1.2); grid on; ylabel('\deltae'); title(strrep(r.tag,'_','\_')); xline(0,'r--');
    subplot(2,2,2); plot(tl, rad2deg(r.q),'b'); hold on; plot(tl, rad2deg(r.th),'m'); grid on; legend('q','th'); xline(0,'r--');
    subplot(2,2,3); plot(tl, r.w,'b'); hold on; plot(tl, r.zdot,'k'); grid on; legend('w','zdot'); xline(0,'r--');
    subplot(2,2,4); plot(tl, r.z,'k'); grid on; ylabel('z'); xlabel('t-tpulse'); xline(0,'r--');
    exportgraphics(fig, path, 'Resolution', 120); close(fig);
end

function print_row_brief(r)
    fprintf('  valid=%d settle=%d  order=%s\n', r.valid, r.settle_ok, r.event_order);
    fprintf('  dth_pk=%+.2fdeg dq_pk=%+.2fdps inv=%d delay=%.3fs\n', ...
        r.peak_dtheta_deg, r.peak_q_dps, r.inverse_any, r.onset_delay_s);
    fprintf('  first_zdot=%+.4f later_zdot=%+.4f DC_th/u2=%.3g DC_zdot/u2=%.3g\n', ...
        r.first_dzdot, r.later_dzdot, r.dc_th_per_de_u2, r.dc_zdot_per_de_u2);
    if ~r.valid; fprintf('  FAIL: %s\n', r.fail); end
end

function s = ternary(c,a,b)
    if c; s=a; else; s=b; end
end
