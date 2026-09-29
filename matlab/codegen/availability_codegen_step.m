function [state, out] = availability_codegen_step(params, state, in)
%AVAILABILITY_CODEGEN_STEP Explicit-state Gate 5C availability step (fixed ABI).
% DEPLOY_CANDIDATE / HEALTH_STATUS_ONLY / NOT_IN_PRODUCTION / NOT_CERTIFIED
% Isolated health-only runtime. No estimator mutation, no actuator authority.
%
% Codes: 0 UNINITIALIZED, 1 NOMINAL, 2 DEGRADED, 3 POSITION_AID_LOST, 4 RECOVERING.
% Channels: 1 gyro, 2 accel, 3 depth, 4 heading, 5 INS vel, 6 DVL, 7 USBL.
% Required aids: present channels 3:7. Position aids: present channels 6:7.
%
% health_bits uint32: 1 CONFIG_INVALID, 2 INPUT_NONFINITE, 4 TIME_NONINCREASING,
% 8 NO_REQUIRED_AID, 16 STATE_NONFINITE. Nonzero => fail-silent, hold prior.
% Corrupt nonfinite state cold-recovers and emits bit 16.
%
% Authority flags are compile-time false: accommodation_requested,
% filter_reset_requested, abort_requested.
%
% TASK_ID: AVAILABILITY_RUNTIME_001

    if ~avail_state_is_finite(state)
        state = avail_cold_state();
        zage = zeros(7, 1);
        zfresh = false(7, 1);
        out = avail_fill_out(params, state, false, false, false, zage, zfresh, false, uint32(16));
        if ~avail_out_is_finite(out)
            state = avail_cold_state();
            out = avail_fill_out(params, state, false, false, false, zage, zfresh, false, uint32(16));
        end
        return;
    end

    t = in.t;
    init_done = logical(in.init_done);
    acc = false(7, 1);
    acc(1) = logical(in.accepted(1));
    acc(2) = logical(in.accepted(2));
    acc(3) = logical(in.accepted(3));
    acc(4) = logical(in.accepted(4));
    acc(5) = logical(in.accepted(5));
    acc(6) = logical(in.accepted(6));
    acc(7) = logical(in.accepted(7));

    hb = uint32(0);
    do_step = false;
    if ~params.config_valid
        hb = uint32(1);
    elseif ~isfinite(t)
        hb = uint32(2);
    elseif state.have_init && (~(t > state.last_t))
        hb = uint32(4);
    elseif (~avail_has_required(params)) && (init_done || state.have_init)
        hb = uint32(8);
    elseif state.have_init || init_done
        do_step = true;
    end

    if hb ~= uint32(0)
        if state.have_init && isfinite(state.last_t)
            [age, fresh, pf, af] = avail_freshness(params, state, state.last_t);
        else
            age = zeros(7, 1);
            fresh = false(7, 1);
            pf = false;
            af = false;
        end
        out = avail_fill_out(params, state, false, pf, af, age, fresh, false, hb);
    elseif do_step
        [state, age, fresh, pf, af, did_trans] = avail_run_step(params, state, t, acc);
        if ~avail_state_is_finite(state)
            state = avail_cold_state();
            zage = zeros(7, 1);
            zfresh = false(7, 1);
            out = avail_fill_out(params, state, false, false, false, zage, zfresh, false, uint32(16));
        else
            out = avail_fill_out(params, state, true, pf, af, age, fresh, did_trans, uint32(0));
        end
    else
        zage = zeros(7, 1);
        zfresh = false(7, 1);
        out = avail_fill_out(params, state, true, false, false, zage, zfresh, false, uint32(0));
    end

    if ~avail_out_is_finite(out)
        state = avail_cold_state();
        zage = zeros(7, 1);
        zfresh = false(7, 1);
        out = avail_fill_out(params, state, false, false, false, zage, zfresh, false, uint32(16));
    end
end

function [state, age, fresh, pf, af, did_trans] = avail_run_step(params, state, t, acc)
    if ~state.have_init
        state.have_init = true;
        state.init_time = t;
        state.code = uint8(1);
        dt = 0.0;
    else
        dt = t - state.last_t;
    end
    state.last_t = t;
    state.have_t = true;

    for i = 1:7
        if acc(i)
            state.last_accept_t(i) = t;
            state.have_accept(i) = true;
        end
    end

    [age, fresh, pf, af] = avail_freshness(params, state, t);

    if pf
        state.loss_timer = 0.0;
        state.posok_timer = state.posok_timer + dt;
    else
        state.loss_timer = state.loss_timer + dt;
        state.posok_timer = 0.0;
    end
    if af
        state.allok_timer = state.allok_timer + dt;
        state.deg_timer = 0.0;
    else
        state.allok_timer = 0.0;
        state.deg_timer = state.deg_timer + dt;
    end

    prev = state.code;
    tol = params.tol_time;
    if prev == uint8(1)
        if state.deg_timer >= (params.T_degrade - tol)
            state.code = uint8(2);
        end
    elseif prev == uint8(2)
        if state.loss_timer >= (params.T_lost - tol)
            state.code = uint8(3);
        elseif state.allok_timer >= (params.T_clear - tol)
            state.code = uint8(1);
        end
    elseif prev == uint8(3)
        if state.posok_timer >= (params.T_reacq - tol)
            state.code = uint8(4);
        end
    elseif prev == uint8(4)
        if state.loss_timer >= (params.T_lost - tol)
            state.code = uint8(3);
        elseif state.allok_timer >= (params.T_settle - tol)
            state.code = uint8(1);
        end
    end

    if state.code ~= prev
        state.trans_count = state.trans_count + uint32(1);
        state.trans_from = prev;
        state.trans_to = state.code;
        did_trans = true;
    else
        did_trans = false;
    end
end

function [age, fresh, pf, af] = avail_freshness(params, state, t)
    age = zeros(7, 1);
    fresh = false(7, 1);
    tol = params.tol_time;
    for i = 1:7
        if state.have_accept(i)
            ref = state.last_accept_t(i);
        else
            ref = state.init_time;
        end
        age(i) = t - ref;
        fresh(i) = (age(i) <= (params.tau_fresh(i) + tol));
    end

    pf = false;
    for i = 6:7
        if params.present(i)
            if fresh(i)
                pf = true;
            end
        end
    end

    af = true;
    saw = false;
    for i = 3:7
        if params.present(i)
            saw = true;
            if ~fresh(i)
                af = false;
            end
        end
    end
    if ~saw
        af = false;
    end
end

function ok = avail_has_required(params)
    ok = false;
    for i = 3:7
        if params.present(i)
            ok = true;
        end
    end
end

function out = avail_fill_out(params, state, valid, pf, af, age, fresh, did_trans, hb)
    tau = zeros(7, 1);
    age_o = zeros(7, 1);
    for i = 1:7
        ti = params.tau_fresh(i);
        if isfinite(ti)
            tau(i) = ti;
        else
            tau(i) = 0.0;
        end
        ai = age(i);
        if isfinite(ai)
            age_o(i) = ai;
        else
            age_o(i) = 0.0;
        end
    end

    code = state.code;
    if ~isfinite(code)
        code = uint8(0);
    end
    cnt = state.trans_count;
    if ~isfinite(cnt)
        cnt = uint32(0);
    end

    if did_trans
        fr = state.trans_from;
        to = state.trans_to;
    else
        fr = code;
        to = code;
    end
    if ~isfinite(fr)
        fr = uint8(0);
    end
    if ~isfinite(to)
        to = uint8(0);
    end

    out = struct();
    out.state = uint8(code);
    out.valid = logical(valid);
    out.pos_aid_fresh = logical(pf);
    out.all_aid_fresh = logical(af);
    out.age = age_o;
    out.fresh = fresh;
    out.tau_fresh = tau;
    out.transition = logical(did_trans);
    out.from = uint8(fr);
    out.to = uint8(to);
    out.count = uint32(cnt);
    out.health_bits = uint32(hb);
    out.accommodation_requested = false;
    out.filter_reset_requested = false;
    out.abort_requested = false;
end

function ok = avail_state_is_finite(state)
    ok = isfinite(state.code) && isfinite(state.deg_timer) && ...
        isfinite(state.loss_timer) && isfinite(state.posok_timer) && ...
        isfinite(state.allok_timer) && isfinite(state.init_time) && ...
        isfinite(state.last_t) && isfinite(state.trans_count) && ...
        isfinite(state.trans_from) && isfinite(state.trans_to) && ...
        isfinite(state.last_accept_t(1)) && isfinite(state.last_accept_t(2)) && ...
        isfinite(state.last_accept_t(3)) && isfinite(state.last_accept_t(4)) && ...
        isfinite(state.last_accept_t(5)) && isfinite(state.last_accept_t(6)) && ...
        isfinite(state.last_accept_t(7));
end

function ok = avail_out_is_finite(out)
    ok = isfinite(out.state) && isfinite(out.from) && isfinite(out.to) && ...
        isfinite(out.count) && ...
        isfinite(out.age(1)) && isfinite(out.age(2)) && isfinite(out.age(3)) && ...
        isfinite(out.age(4)) && isfinite(out.age(5)) && isfinite(out.age(6)) && ...
        isfinite(out.age(7)) && ...
        isfinite(out.tau_fresh(1)) && isfinite(out.tau_fresh(2)) && ...
        isfinite(out.tau_fresh(3)) && isfinite(out.tau_fresh(4)) && ...
        isfinite(out.tau_fresh(5)) && isfinite(out.tau_fresh(6)) && ...
        isfinite(out.tau_fresh(7));
end

function state = avail_cold_state()
    last_accept_t = zeros(7, 1);
    have_accept = false(7, 1);
    state = struct();
    state.code = uint8(0);
    state.deg_timer = 0.0;
    state.loss_timer = 0.0;
    state.posok_timer = 0.0;
    state.allok_timer = 0.0;
    state.last_accept_t = last_accept_t;
    state.have_accept = have_accept;
    state.init_time = 0.0;
    state.last_t = 0.0;
    state.have_init = false;
    state.have_t = false;
    state.trans_count = uint32(0);
    state.trans_from = uint8(0);
    state.trans_to = uint8(0);
end
