function [state, out] = nav_codegen_step(params, state, in)
%NAV_CODEGEN_STEP Explicit-state Gate 5C navigation step (fixed ABI).
% DEPLOY_CANDIDATE / NOT_IN_PRODUCTION / NOT_CERTIFIED
% Isolated runtime: initialize / paired-IMU propagate / one aiding update / output.
% Joseph form, ordered fail-silent admission, measured-only ABI.
%
% op uint8: 0 output, 1 initialize, 2 propagate, 3 aiding update. Other: BAD_OP.
%
% TASK_ID: NAV_RUNTIME_REPAIR_001

    hb = uint32(0);
    valid = false;
    fused = false;

    if ~nav_state_is_finite(state)
        state = nav_cold_state_local();
        out = nav_fill_out(state, false, false, uint32(65536));
        return;
    end

    op = uint8(in.op);

    if (op ~= uint8(0)) && (op ~= uint8(1)) && (op ~= uint8(2)) && (op ~= uint8(3))
        hb = uint32(1);
    elseif ~params.config_valid
        hb = uint32(4);
    elseif op == uint8(0)
        if ~state.initialized
            hb = uint32(2);
        else
            valid = true;
        end
    elseif op == uint8(1)
        [state, hb, valid] = nav_op_initialize(params, state, in);
    elseif op == uint8(2)
        [state, hb, valid] = nav_op_propagate(params, state, in);
    else
        [state, hb, valid, fused] = nav_op_update(params, state, in);
    end

    if ~nav_state_is_finite(state)
        state = nav_cold_state_local();
        valid = false;
        fused = false;
        hb = uint32(65536);
    end

    out = nav_fill_out(state, valid, fused, hb);
    if ~out_is_finite(out)
        state = nav_cold_state_local();
        out = nav_fill_out(state, false, false, uint32(65536));
    end
end

function [state, hb, valid] = nav_op_initialize(params, state, in)
    hb = uint32(0);
    valid = false;

    if ~in.sample_valid
        hb = uint32(8);
        return;
    end

    g1 = in.init_gyro(1); g2 = in.init_gyro(2); g3 = in.init_gyro(3);
    a1 = in.init_accel(1); a2 = in.init_accel(2); a3 = in.init_accel(3);
    d0 = in.init_depth;
    h0 = in.init_heading;
    v1 = in.init_ins_vel(1); v2 = in.init_ins_vel(2); v3 = in.init_ins_vel(3);
    ts1 = in.init_timestamp(1); ts2 = in.init_timestamp(2); ts3 = in.init_timestamp(3);
    ts4 = in.init_timestamp(4); ts5 = in.init_timestamp(5);
    tnow = in.t;

    if ~(isfinite(tnow) && isfinite(g1) && isfinite(g2) && isfinite(g3) && ...
            isfinite(a1) && isfinite(a2) && isfinite(a3) && isfinite(d0) && ...
            isfinite(h0) && isfinite(v1) && isfinite(v2) && isfinite(v3) && ...
            isfinite(ts1) && isfinite(ts2) && isfinite(ts3) && isfinite(ts4) && ...
            isfinite(ts5))
        hb = uint32(16);
        return;
    end

    s1 = uint32(in.init_seq(1)); s2 = uint32(in.init_seq(2));
    s3 = uint32(in.init_seq(3)); s4 = uint32(in.init_seq(4));
    s5 = uint32(in.init_seq(5));
    if (s1 == uint32(0)) || (s2 == uint32(0)) || (s3 == uint32(0)) || ...
            (s4 == uint32(0)) || (s5 == uint32(0))
        hb = uint32(2048);
        return;
    end

    dpair = ts1 - ts2;
    if dpair < 0.0
        dpair = -dpair;
    end
    if dpair > params.tol_pair
        hb = uint32(8192);
        return;
    end

    acc1 = a1 / params.g_ned;
    if acc1 > 1.0
        acc1 = 1.0;
    end
    if acc1 < -1.0
        acc1 = -1.0;
    end
    theta0 = asin(acc1);
    phi0 = atan2(-a2, -a3);
    psi0 = wrap_pi_local(h0);
    qn = quat_norm_local(euler2quat_local(phi0, theta0, psi0));

    p = zeros(3, 1);
    p(3) = d0;
    v = zeros(3, 1);
    v(1) = v1;
    v(2) = v2;
    v(3) = v3;
    bg = zeros(3, 1);
    ba = zeros(3, 1);
    c = zeros(3, 1);

    P = zeros(18, 18);
    if in.abs_position_present
        P(1, 1) = params.P0_p_abs;
        P(2, 2) = params.P0_p_abs;
    else
        P(1, 1) = params.P0_p(1);
        P(2, 2) = params.P0_p(2);
    end
    P(3, 3) = params.P0_p(3);
    P(4, 4) = params.P0_v(1);
    P(5, 5) = params.P0_v(2);
    P(6, 6) = params.P0_v(3);
    P(7, 7) = params.P0_th(1);
    P(8, 8) = params.P0_th(2);
    P(9, 9) = params.P0_th(3);
    P(10, 10) = params.P0_bg(1);
    P(11, 11) = params.P0_bg(2);
    P(12, 12) = params.P0_bg(3);
    P(13, 13) = params.P0_ba(1);
    P(14, 14) = params.P0_ba(2);
    P(15, 15) = params.P0_ba(3);
    P(16, 16) = params.P0_c(1);
    P(17, 17) = params.P0_c(2);
    P(18, 18) = params.P0_c(3);

    if ~(all_finite3(p) && all_finite3(v) && all_finite4(qn) && ...
            all_finite18x18(P))
        hb = uint32(65536);
        return;
    end

    last_seq = uint32(zeros(7, 1));
    have_seq = false(7, 1);
    last_ts = zeros(7, 1);
    have_ts = false(7, 1);
    last_accept_t = zeros(7, 1);
    have_accept_t = false(7, 1);

    last_seq(1) = s1; last_seq(2) = s2; last_seq(3) = s3;
    last_seq(4) = s4; last_seq(5) = s5;
    have_seq(1) = true; have_seq(2) = true; have_seq(3) = true;
    have_seq(4) = true; have_seq(5) = true;
    last_ts(1) = ts1; last_ts(2) = ts2; last_ts(3) = ts3;
    last_ts(4) = ts4; last_ts(5) = ts5;
    have_ts(1) = true; have_ts(2) = true; have_ts(3) = true;
    have_ts(4) = true; have_ts(5) = true;
    last_accept_t(1) = tnow; last_accept_t(2) = tnow; last_accept_t(3) = tnow;
    last_accept_t(4) = tnow; last_accept_t(5) = tnow;
    have_accept_t(1) = true; have_accept_t(2) = true; have_accept_t(3) = true;
    have_accept_t(4) = true; have_accept_t(5) = true;

    state.initialized = true;
    state.p = p;
    state.v = v;
    state.q = qn;
    state.bg = bg;
    state.ba = ba;
    state.c = c;
    state.P = P;
    state.last_seq = last_seq;
    state.have_seq = have_seq;
    state.last_ts = last_ts;
    state.have_ts = have_ts;
    state.last_accept_t = last_accept_t;
    state.have_accept_t = have_accept_t;
    state.est_seq = uint32(1);
    valid = true;
end

function [state, hb, valid] = nav_op_propagate(params, state, in)
    hb = uint32(0);
    valid = false;

    if ~state.initialized
        hb = uint32(2);
        return;
    end
    if ~in.sample_valid
        hb = uint32(8);
        return;
    end

    w1 = in.gyro(1); w2 = in.gyro(2); w3 = in.gyro(3);
    f1 = in.accel(1); f2 = in.accel(2); f3 = in.accel(3);
    tsg = in.gyro_timestamp;
    tsa = in.accel_timestamp;
    tnow = in.t;
    if ~(isfinite(tnow) && isfinite(w1) && isfinite(w2) && isfinite(w3) && ...
            isfinite(f1) && isfinite(f2) && isfinite(f3) && ...
            isfinite(tsg) && isfinite(tsa))
        hb = uint32(16);
        return;
    end

    sg = uint32(in.gyro_seq);
    sa = uint32(in.accel_seq);
    if (~state.have_seq(1)) || (~state.have_seq(2)) || ...
            (sg <= state.last_seq(1)) || (sa <= state.last_seq(2))
        hb = uint32(2048);
        return;
    end
    if (~state.have_ts(1)) || (~state.have_ts(2)) || ...
            (tsg <= state.last_ts(1) + params.tol_time) || ...
            (tsa <= state.last_ts(2) + params.tol_time)
        hb = uint32(4096);
        return;
    end

    dpair = tsg - tsa;
    if dpair < 0.0
        dpair = -dpair;
    end
    if dpair > params.tol_pair
        hb = uint32(8192);
        return;
    end

    dt = tsg - state.last_ts(1);
    if (dt <= 0.0) || (dt > params.dt_prop_max)
        hb = uint32(16384);
        return;
    end

    nsub = 1.0;
    if dt > params.dt_prop_sub
        nsub = ceil(dt / params.dt_prop_sub);
    end
    if nsub > params.n_sub_max
        hb = uint32(16384);
        return;
    end

    w_m = zeros(3, 1);
    w_m(1) = w1; w_m(2) = w2; w_m(3) = w3;
    f_m = zeros(3, 1);
    f_m(1) = f1; f_m(2) = f2; f_m(3) = f3;
    dt_sub = dt / nsub;

    p = state.p;
    v = state.v;
    q = state.q;
    bg = state.bg;
    ba = state.ba;
    c = state.c;
    P = state.P;

    for sstep = 1:5
        if sstep <= nsub
            [p, v, q, bg, ba, c, P] = nav_propagate_sub(params, p, v, q, bg, ba, c, P, w_m, f_m, dt_sub);
        end
    end

    if ~(all_finite3(p) && all_finite3(v) && all_finite4(q) && all_finite3(bg) && ...
            all_finite3(ba) && all_finite3(c) && all_finite18x18(P))
        hb = uint32(65536);
        return;
    end

    state.p = p;
    state.v = v;
    state.q = q;
    state.bg = bg;
    state.ba = ba;
    state.c = c;
    state.P = P;
    state.last_seq(1) = sg;
    state.last_seq(2) = sa;
    state.have_seq(1) = true;
    state.have_seq(2) = true;
    state.last_ts(1) = tsg;
    state.last_ts(2) = tsa;
    state.have_ts(1) = true;
    state.have_ts(2) = true;
    state.last_accept_t(1) = tnow;
    state.last_accept_t(2) = tnow;
    state.have_accept_t(1) = true;
    state.have_accept_t(2) = true;
    state.est_seq = state.est_seq + uint32(1);
    valid = true;
end

function [state, hb, valid, fused] = nav_op_update(params, state, in)
    hb = uint32(0);
    valid = false;
    fused = false;

    ch = uint8(in.channel);
    dim = uint8(in.dim);
    ch_ok = false;
    if (ch == uint8(3)) || (ch == uint8(4))
        ch_ok = (dim == uint8(1));
    elseif (ch == uint8(5)) || (ch == uint8(6)) || (ch == uint8(7))
        ch_ok = (dim == uint8(3));
    end
    if ~ch_ok
        hb = uint32(32);
        return;
    end
    if ~in.present
        hb = uint32(64);
        return;
    end
    if (~in.packet_valid) || (uint8(in.status) ~= uint8(2))
        hb = uint32(128);
        return;
    end

    z1 = in.value(1); z2 = in.value(2); z3 = in.value(3);
    ts = in.timestamp;
    qual = in.quality;
    stale = in.stale_age;
    lo1 = in.bound_lo(1); lo2 = in.bound_lo(2); lo3 = in.bound_lo(3);
    hi1 = in.bound_hi(1); hi2 = in.bound_hi(2); hi3 = in.bound_hi(3);
    q_nom_in = in.q_nom;
    slim = in.stale_limit_s;
    z_ok = isfinite(z1);
    if dim == uint8(3)
        z_ok = z_ok && isfinite(z2) && isfinite(z3);
    end
    bfin = isfinite(lo1) && isfinite(hi1);
    if dim == uint8(3)
        bfin = bfin && isfinite(lo2) && isfinite(hi2) && isfinite(lo3) && isfinite(hi3);
    end
    if ~(z_ok && isfinite(ts) && isfinite(qual) && isfinite(stale) && isfinite(in.t) && ...
            isfinite(q_nom_in) && isfinite(slim) && bfin)
        hb = uint32(16);
        return;
    end

    bmeta_ok = (lo1 <= hi1);
    if dim == uint8(3)
        bmeta_ok = bmeta_ok && (lo2 <= hi2) && (lo3 <= hi3);
    end
    if ~bmeta_ok
        hb = uint32(256);
        return;
    end
    out_b = (z1 < (lo1 - 1.0e-9)) || (z1 > (hi1 + 1.0e-9));
    if dim == uint8(3)
        out_b = out_b || (z2 < (lo2 - 1.0e-9)) || (z2 > (hi2 + 1.0e-9)) || ...
            (z3 < (lo3 - 1.0e-9)) || (z3 > (hi3 + 1.0e-9));
    end
    if out_b
        hb = uint32(256);
        return;
    end

    if q_nom_in <= 0.0
        hb = uint32(512);
        return;
    end
    if qual < (params.q_min_frac * q_nom_in - params.tol_time)
        hb = uint32(512);
        return;
    end
    if (slim < 0.0) || (stale < 0.0)
        hb = uint32(1024);
        return;
    end
    if stale > (slim + params.tol_time)
        hb = uint32(1024);
        return;
    end

    ci = int32(ch);
    seqn = uint32(in.seq);
    last_seq = uint32(0);
    if state.have_seq(ci)
        last_seq = state.last_seq(ci);
    end
    if seqn <= last_seq
        hb = uint32(2048);
        return;
    end
    if state.have_ts(ci)
        if ts <= (state.last_ts(ci) + params.tol_time)
            hb = uint32(4096);
            return;
        end
    end
    if ~state.initialized
        hb = uint32(2);
        return;
    end

    age = 0.0;
    if state.have_ts(1)
        age = state.last_ts(1) - ts;
        if age < 0.0
            age = 0.0;
        end
    end

    q_nom = in.q_nom;
    if ~(isfinite(q_nom) && (q_nom > 2.220446049250313e-16))
        q_nom = 2.220446049250313e-16;
    end
    qs = qual / q_nom;
    if qs < params.q_floor
        qs = params.q_floor;
    end

    H = zeros(3, 18);
    nu = zeros(3, 1);
    Rm = zeros(3, 3);
    dmeas = 1.0;

    Rbn = quat2rot_local(state.q);
    if ch == uint8(3)
        H(1, 3) = 1.0;
        nu(1) = z1 - state.p(3);
        Rm(1, 1) = params.R_depth / qs + (params.lat_depth * age) * (params.lat_depth * age);
        dmeas = 1.0;
    elseif ch == uint8(4)
        eul = rot2euler_local(Rbn);
        ph = eul(1);
        th = eul(2);
        ps = eul(3);
        cth = cos(th);
        if abs(cth) < 1.0e-6
            cth = 1.0e-6 * sign_nz_local(cth);
        end
        H(1, 8) = sin(ph) / cth;
        H(1, 9) = cos(ph) / cth;
        nu(1) = wrap_pi_local(z1 - ps);
        Rm(1, 1) = params.R_heading / qs + (params.lat_heading * age) * (params.lat_heading * age);
        dmeas = 1.0;
    elseif ch == uint8(5)
        H(1, 4) = 1.0; H(2, 5) = 1.0; H(3, 6) = 1.0;
        nu(1) = z1 - state.v(1);
        nu(2) = z2 - state.v(2);
        nu(3) = z3 - state.v(3);
        lat2 = (params.lat_ins * age) * (params.lat_ins * age);
        Rm(1, 1) = params.R_ins(1) / qs + lat2;
        Rm(2, 2) = params.R_ins(2) / qs + lat2;
        Rm(3, 3) = params.R_ins(3) / qs + lat2;
        dmeas = 3.0;
    elseif ch == uint8(6)
        wv = zeros(3, 1);
        wv(1) = state.v(1) - state.c(1);
        wv(2) = state.v(2) - state.c(2);
        wv(3) = state.v(3) - state.c(3);
        hx = Rbn' * wv;
        H(1:3, 4:6) = Rbn';
        H(1:3, 16:18) = -Rbn';
        H(1:3, 7:9) = skew_local(hx);
        nu(1) = z1 - hx(1);
        nu(2) = z2 - hx(2);
        nu(3) = z3 - hx(3);
        lat2 = (params.lat_dvl * age) * (params.lat_dvl * age);
        Rm(1, 1) = params.R_dvl(1) / qs + lat2;
        Rm(2, 2) = params.R_dvl(2) / qs + lat2;
        Rm(3, 3) = params.R_dvl(3) / qs + lat2;
        dmeas = 3.0;
    else
        H(1, 1) = 1.0; H(2, 2) = 1.0; H(3, 3) = 1.0;
        nu(1) = z1 - state.p(1);
        nu(2) = z2 - state.p(2);
        nu(3) = z3 - state.p(3);
        lat2 = (params.lat_usbl * age) * (params.lat_usbl * age);
        Rm(1, 1) = params.R_usbl(1) / qs + lat2;
        Rm(2, 2) = params.R_usbl(2) / qs + lat2;
        Rm(3, 3) = params.R_usbl(3) / qs + lat2;
        dmeas = 3.0;
    end

    P = state.P;
    dx = zeros(18, 1);
    nis = 0.0;
    math_ok = true;

    if dmeas < 1.5
        Ht = zeros(18, 1);
        for i = 1:18
            Ht(i) = H(1, i);
        end
        PH = P * Ht;
        Ssc = 0.0;
        for i = 1:18
            Ssc = Ssc + Ht(i) * PH(i);
        end
        Ssc = Ssc + Rm(1, 1);
        if ~(isfinite(Ssc) && (Ssc > 1.0e-18))
            hb = uint32(32768);
            return;
        end
        nis = (nu(1) * nu(1)) / Ssc;
        if ~(isfinite(nis) && (nis <= params.nis_scale * dmeas))
            hb = uint32(32768);
            return;
        end
        Ks = zeros(18, 1);
        for i = 1:18
            Ks(i) = PH(i) / Ssc;
        end
        dx = Ks * nu(1);
        IKH = eye(18) - Ks * Ht';
        P = IKH * P * IKH' + (Ks * Rm(1, 1)) * Ks';
    else
        H3 = H;
        S3 = H3 * P * H3' + Rm;
        S3 = 0.5 * (S3 + S3');
        if ~chol3_spd(S3)
            hb = uint32(32768);
            return;
        end
        [inv_ok, Sinv] = inv3_fixed(S3);
        if ~inv_ok
            hb = uint32(32768);
            return;
        end
        nis = nu' * (Sinv * nu);
        if ~(isfinite(nis) && (nis <= params.nis_scale * dmeas))
            hb = uint32(32768);
            return;
        end
        K = (P * H3') * Sinv;
        dx = K * nu;
        IKH = eye(18) - K * H3;
        P = IKH * P * IKH' + (K * Rm) * K';
    end

    P = 0.5 * (P + P');
    if ~(all_finite18(dx) && all_finite18x18(P))
        math_ok = false;
    end

    if math_ok
        p = state.p;
        v = state.v;
        q = state.q;
        bg = state.bg;
        ba = state.ba;
        c = state.c;
        p(1) = p(1) + dx(1);
        p(2) = p(2) + dx(2);
        p(3) = p(3) + dx(3);
        v(1) = v(1) + dx(4);
        v(2) = v(2) + dx(5);
        v(3) = v(3) + dx(6);
        dth = zeros(3, 1);
        dth(1) = dx(7);
        dth(2) = dx(8);
        dth(3) = dx(9);
        q = quat_norm_local(quat_mul_local(q, quat_from_rotvec_local(dth)));
        bg(1) = bg(1) + dx(10);
        bg(2) = bg(2) + dx(11);
        bg(3) = bg(3) + dx(12);
        ba(1) = ba(1) + dx(13);
        ba(2) = ba(2) + dx(14);
        ba(3) = ba(3) + dx(15);
        c(1) = c(1) + dx(16);
        c(2) = c(2) + dx(17);
        c(3) = c(3) + dx(18);
        Gr = eye(18);
        Gr(7:9, 7:9) = eye(3) - 0.5 * skew_local(dth);
        P = Gr * P * Gr';
        P = 0.5 * (P + P');
        if ~(all_finite3(p) && all_finite3(v) && all_finite4(q) && all_finite3(bg) && ...
                all_finite3(ba) && all_finite3(c) && all_finite18x18(P))
            math_ok = false;
        else
            state.p = p;
            state.v = v;
            state.q = q;
            state.bg = bg;
            state.ba = ba;
            state.c = c;
            state.P = P;
            state.last_seq(ci) = seqn;
            state.have_seq(ci) = true;
            state.last_ts(ci) = ts;
            state.have_ts(ci) = true;
            state.last_accept_t(ci) = in.t;
            state.have_accept_t(ci) = true;
            state.est_seq = state.est_seq + uint32(1);
            valid = true;
            fused = true;
        end
    end

    if ~math_ok
        hb = uint32(65536);
    end
end

function [p, v, q, bg, ba, c, P] = nav_propagate_sub(params, p, v, q, bg, ba, c, P, w_m, f_m, dt)
    w = zeros(3, 1);
    f = zeros(3, 1);
    w(1) = w_m(1) - bg(1);
    w(2) = w_m(2) - bg(2);
    w(3) = w_m(3) - bg(3);
    f(1) = f_m(1) - ba(1);
    f(2) = f_m(2) - ba(2);
    f(3) = f_m(3) - ba(3);
    R = quat2rot_local(q);
    a = R * f;
    a(3) = a(3) + params.g_ned;

    p = p + v * dt + 0.5 * a * (dt * dt);
    v = v + a * dt;
    q = quat_norm_local(quat_mul_local(q, quat_from_rotvec_local(w * dt)));

    F = zeros(18, 18);
    F(1:3, 4:6) = eye(3);
    F(4:6, 7:9) = -R * skew_local(f);
    F(4:6, 13:15) = -R;
    F(7:9, 7:9) = -skew_local(w);
    F(7:9, 10:12) = -eye(3);

    Fd = F * dt;
    Phi = eye(18) + Fd + 0.5 * (Fd * Fd);

    Qc = zeros(18, 18);
    sp2 = params.sigma_p * params.sigma_p;
    sa2 = params.sigma_a * params.sigma_a;
    sg2 = params.sigma_g * params.sigma_g;
    sbg2 = params.sigma_bg * params.sigma_bg;
    sba2 = params.sigma_ba * params.sigma_ba;
    sc2 = params.sigma_c * params.sigma_c;
    Qc(1, 1) = sp2; Qc(2, 2) = sp2; Qc(3, 3) = sp2;
    Qc(4, 4) = sa2; Qc(5, 5) = sa2; Qc(6, 6) = sa2;
    Qc(7, 7) = sg2; Qc(8, 8) = sg2; Qc(9, 9) = sg2;
    Qc(10, 10) = sbg2; Qc(11, 11) = sbg2; Qc(12, 12) = sbg2;
    Qc(13, 13) = sba2; Qc(14, 14) = sba2; Qc(15, 15) = sba2;
    Qc(16, 16) = sc2; Qc(17, 17) = sc2; Qc(18, 18) = sc2;
    Qd = 0.5 * (Phi * Qc * Phi' + Qc) * dt;

    P = Phi * P * Phi' + Qd;
    P = 0.5 * (P + P');
end

function out = nav_fill_out(state, valid, fused, hb)
    Rbn = quat2rot_local(state.q);
    eul = rot2euler_local(Rbn);
    wv = zeros(3, 1);
    wv(1) = state.v(1) - state.c(1);
    wv(2) = state.v(2) - state.c(2);
    wv(3) = state.v(3) - state.c(3);
    vbw = Rbn' * wv;
    Pdiag = zeros(18, 1);
    for i = 1:18
        Pdiag(i) = state.P(i, i);
    end
    sm = uint32(0);
    for i = 1:7
        if state.have_seq(i)
            sm = bitor(sm, bitshift(uint32(1), uint32(i - 1)));
        end
    end

    out = struct();
    out.p = state.p;
    out.v = state.v;
    out.q = state.q;
    out.bg = state.bg;
    out.ba = state.ba;
    out.c = state.c;
    out.Pdiag = Pdiag;
    out.euler = eul;
    out.vel_body_water = vbw;
    out.initialized = state.initialized;
    out.valid = valid;
    out.fused = fused;
    out.health_bits = hb;
    out.est_seq = state.est_seq;
    out.source_mask = sm;
end

function S = skew_local(v)
    S = zeros(3, 3);
    S(1, 2) = -v(3);
    S(1, 3) = v(2);
    S(2, 1) = v(3);
    S(2, 3) = -v(1);
    S(3, 1) = -v(2);
    S(3, 2) = v(1);
end

function R = quat2rot_local(q)
    qw = q(1); qx = q(2); qy = q(3); qz = q(4);
    R = zeros(3, 3);
    R(1, 1) = 1.0 - 2.0 * (qy * qy + qz * qz);
    R(1, 2) = 2.0 * (qx * qy - qw * qz);
    R(1, 3) = 2.0 * (qx * qz + qw * qy);
    R(2, 1) = 2.0 * (qx * qy + qw * qz);
    R(2, 2) = 1.0 - 2.0 * (qx * qx + qz * qz);
    R(2, 3) = 2.0 * (qy * qz - qw * qx);
    R(3, 1) = 2.0 * (qx * qz - qw * qy);
    R(3, 2) = 2.0 * (qy * qz + qw * qx);
    R(3, 3) = 1.0 - 2.0 * (qx * qx + qy * qy);
end

function q = quat_mul_local(a, b)
    w1 = a(1); x1 = a(2); y1 = a(3); z1 = a(4);
    w2 = b(1); x2 = b(2); y2 = b(3); z2 = b(4);
    q = zeros(4, 1);
    q(1) = w1 * w2 - x1 * x2 - y1 * y2 - z1 * z2;
    q(2) = w1 * x2 + x1 * w2 + y1 * z2 - z1 * y2;
    q(3) = w1 * y2 - x1 * z2 + y1 * w2 + z1 * x2;
    q(4) = w1 * z2 + x1 * y2 - y1 * x2 + z1 * w2;
end

function q = quat_from_rotvec_local(v)
    n = sqrt(v(1) * v(1) + v(2) * v(2) + v(3) * v(3));
    q = zeros(4, 1);
    if n < 1.0e-12
        q(1) = 1.0;
        q(2) = 0.5 * v(1);
        q(3) = 0.5 * v(2);
        q(4) = 0.5 * v(3);
    else
        q(1) = cos(n / 2.0);
        s = sin(n / 2.0) / n;
        q(2) = s * v(1);
        q(3) = s * v(2);
        q(4) = s * v(3);
    end
    nq = sqrt(q(1) * q(1) + q(2) * q(2) + q(3) * q(3) + q(4) * q(4));
    if nq > 1.0e-18
        q(1) = q(1) / nq;
        q(2) = q(2) / nq;
        q(3) = q(3) / nq;
        q(4) = q(4) / nq;
    else
        q(1) = 1.0;
        q(2) = 0.0;
        q(3) = 0.0;
        q(4) = 0.0;
    end
end

function q = quat_norm_local(q)
    nq = sqrt(q(1) * q(1) + q(2) * q(2) + q(3) * q(3) + q(4) * q(4));
    if nq > 1.0e-18
        q(1) = q(1) / nq;
        q(2) = q(2) / nq;
        q(3) = q(3) / nq;
        q(4) = q(4) / nq;
    else
        q(1) = 1.0;
        q(2) = 0.0;
        q(3) = 0.0;
        q(4) = 0.0;
    end
    if q(1) < 0.0
        q(1) = -q(1);
        q(2) = -q(2);
        q(3) = -q(3);
        q(4) = -q(4);
    end
end

function q = euler2quat_local(phi, theta, psi)
    cr = cos(phi / 2.0); sr = sin(phi / 2.0);
    cp = cos(theta / 2.0); sp = sin(theta / 2.0);
    cy = cos(psi / 2.0); sy = sin(psi / 2.0);
    q = zeros(4, 1);
    q(1) = cr * cp * cy + sr * sp * sy;
    q(2) = sr * cp * cy - cr * sp * sy;
    q(3) = cr * sp * cy + sr * cp * sy;
    q(4) = cr * cp * sy - sr * sp * cy;
end

function e = rot2euler_local(R)
    e = zeros(3, 1);
    r31 = R(3, 1);
    if r31 > 1.0
        r31 = 1.0;
    end
    if r31 < -1.0
        r31 = -1.0;
    end
    e(1) = atan2(R(3, 2), R(3, 3));
    e(2) = -asin(r31);
    e(3) = atan2(R(2, 1), R(1, 1));
end

function y = wrap_pi_local(x)
    y = mod(x + pi, 2.0 * pi) - pi;
    if (y == -pi) && (x > 0.0)
        y = pi;
    end
end

function s = sign_nz_local(x)
    if x > 0.0
        s = 1.0;
    elseif x < 0.0
        s = -1.0;
    else
        s = 1.0;
    end
end

function [ok, Ainv] = inv3_fixed(A)
    Ainv = zeros(3, 3);
    c11 = A(2, 2) * A(3, 3) - A(2, 3) * A(3, 2);
    c12 = A(2, 3) * A(3, 1) - A(2, 1) * A(3, 3);
    c13 = A(2, 1) * A(3, 2) - A(2, 2) * A(3, 1);
    c21 = A(1, 3) * A(3, 2) - A(1, 2) * A(3, 3);
    c22 = A(1, 1) * A(3, 3) - A(1, 3) * A(3, 1);
    c23 = A(1, 2) * A(3, 1) - A(1, 1) * A(3, 2);
    c31 = A(1, 2) * A(2, 3) - A(1, 3) * A(2, 2);
    c32 = A(1, 3) * A(2, 1) - A(1, 1) * A(2, 3);
    c33 = A(1, 1) * A(2, 2) - A(1, 2) * A(2, 1);
    detA = A(1, 1) * c11 + A(1, 2) * c12 + A(1, 3) * c13;
    ok = false;
    if isfinite(detA)
        adet = detA;
        if adet < 0.0
            adet = -adet;
        end
        if adet > 1.0e-18
            Ainv(1, 1) = c11 / detA;
            Ainv(1, 2) = c21 / detA;
            Ainv(1, 3) = c31 / detA;
            Ainv(2, 1) = c12 / detA;
            Ainv(2, 2) = c22 / detA;
            Ainv(2, 3) = c32 / detA;
            Ainv(3, 1) = c13 / detA;
            Ainv(3, 2) = c23 / detA;
            Ainv(3, 3) = c33 / detA;
            ok = isfinite(Ainv(1, 1)) && isfinite(Ainv(1, 2)) && isfinite(Ainv(1, 3)) && ...
                isfinite(Ainv(2, 1)) && isfinite(Ainv(2, 2)) && isfinite(Ainv(2, 3)) && ...
                isfinite(Ainv(3, 1)) && isfinite(Ainv(3, 2)) && isfinite(Ainv(3, 3));
        end
    end
end

function ok = chol3_spd(A)
    ok = false;
    a11 = A(1, 1); a21 = A(2, 1); a31 = A(3, 1);
    a22 = A(2, 2); a32 = A(3, 2); a33 = A(3, 3);
    if ~(isfinite(a11) && isfinite(a21) && isfinite(a31) && ...
            isfinite(a22) && isfinite(a32) && isfinite(a33) && ...
            isfinite(A(1, 2)) && isfinite(A(1, 3)) && isfinite(A(2, 3)))
        return;
    end
    if a11 <= 1.0e-18
        return;
    end
    l11 = sqrt(a11);
    l21 = a21 / l11;
    l31 = a31 / l11;
    t22 = a22 - l21 * l21;
    if ~(isfinite(t22) && (t22 > 1.0e-18))
        return;
    end
    l22 = sqrt(t22);
    l32 = (a32 - l31 * l21) / l22;
    t33 = a33 - l31 * l31 - l32 * l32;
    if ~(isfinite(l11) && isfinite(l21) && isfinite(l31) && ...
            isfinite(l22) && isfinite(l32) && isfinite(t33) && (t33 > 1.0e-18))
        return;
    end
    l33 = sqrt(t33);
    ok = isfinite(l33);
end

function ok = nav_state_is_finite(state)
    ok = all_finite3(state.p) && all_finite3(state.v) && all_finite4(state.q) && ...
        all_finite3(state.bg) && all_finite3(state.ba) && all_finite3(state.c) && ...
        all_finite18x18(state.P) && all_finite7(state.last_ts) && ...
        all_finite7(state.last_accept_t);
end

function state = nav_cold_state_local()
    q0 = zeros(4, 1);
    q0(1) = 1.0;
    seq0 = uint32(zeros(7, 1));
    state = struct();
    state.initialized = false;
    state.p = zeros(3, 1);
    state.v = zeros(3, 1);
    state.q = q0;
    state.bg = zeros(3, 1);
    state.ba = zeros(3, 1);
    state.c = zeros(3, 1);
    state.P = zeros(18, 18);
    state.last_seq = seq0;
    state.have_seq = false(7, 1);
    state.last_ts = zeros(7, 1);
    state.have_ts = false(7, 1);
    state.last_accept_t = zeros(7, 1);
    state.have_accept_t = false(7, 1);
    state.est_seq = uint32(0);
end

function ok = out_is_finite(out)
    ok = all_finite3(out.p) && all_finite3(out.v) && all_finite4(out.q) && ...
        all_finite3(out.bg) && all_finite3(out.ba) && all_finite3(out.c) && ...
        all_finite18(out.Pdiag) && all_finite3(out.euler) && all_finite3(out.vel_body_water);
end

function ok = all_finite7(x)
    ok = isfinite(x(1)) && isfinite(x(2)) && isfinite(x(3)) && isfinite(x(4)) && ...
        isfinite(x(5)) && isfinite(x(6)) && isfinite(x(7));
end

function ok = all_finite3(x)
    ok = isfinite(x(1)) && isfinite(x(2)) && isfinite(x(3));
end

function ok = all_finite4(x)
    ok = isfinite(x(1)) && isfinite(x(2)) && isfinite(x(3)) && isfinite(x(4));
end

function ok = all_finite18(x)
    ok = true;
    for i = 1:18
        if ~isfinite(x(i))
            ok = false;
        end
    end
end

function ok = all_finite18x18(A)
    ok = true;
    for i = 1:18
        for j = 1:18
            if ~isfinite(A(i, j))
                ok = false;
            end
        end
    end
end
