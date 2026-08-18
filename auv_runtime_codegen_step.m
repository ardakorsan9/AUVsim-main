function [state, out] = auv_runtime_codegen_step(params, state, in)
%AUV_RUNTIME_CODEGEN_STEP Ordered supervisor step and logical safety interlock.
% PRETARGET DEPLOY_CANDIDATE / LOGICAL COMMANDS ONLY / NOT_IN_PRODUCTION / NOT_CERTIFIED
% Fixed-shape composition: validate, nav, availability, /3 guidance hold,
% controller, FDIR (status only), then arm/safe publish. No physical authority.
%
% TASK_ID: SUPERVISOR_NAV_READY_REPAIR_001

    tol_time = 1.0e-12;
    hb = uint32(0);

    t = in.t;
    seq_now = uint32(in.tick_seq);
    sample_valid = logical(in.sample_valid);
    arm_request = logical(in.arm_request);
    disarm_request = logical(in.disarm_request);
    kill_asserted = logical(in.kill_asserted);

    t_finite = isfinite(t);
    nav_t = in.nav.t;
    nav_t_finite = isfinite(nav_t);
    input_ok = t_finite && nav_t_finite && sample_valid;

    time_match = false;
    if t_finite && nav_t_finite
        dt_nav = t - nav_t;
        if dt_nav < 0.0
            dt_nav = -dt_nav;
        end
        time_match = (dt_nav <= tol_time);
    end

    seq_inc = true;
    t_inc = t_finite;
    if state.have_tick
        seq_inc = (seq_now > state.last_tick_seq);
        t_inc = false;
        if t_finite
            t_inc = (t > state.last_t);
        end
    end
    order_ok = seq_inc && t_inc && time_match;

    path_ok = path_is_valid(in.path_pad, in.n_path);
    br1 = in.body_rates(1);
    br2 = in.body_rates(2);
    br3 = in.body_rates(3);
    rates_ok = isfinite(br1) && isfinite(br2) && isfinite(br3);

    config_ok = logical(params.config_valid);
    if ~config_ok
        hb = bitor(hb, uint32(1));
    end
    if ~input_ok
        hb = bitor(hb, uint32(2));
    end
    if ~seq_inc
        hb = bitor(hb, uint32(4));
    end
    if (~t_inc) || (~time_match)
        hb = bitor(hb, uint32(8));
    end
    if ~path_ok
        hb = bitor(hb, uint32(16));
    end
    if ~rates_ok
        hb = bitor(hb, uint32(32));
    end

    guidance_due = false;
    if order_ok
        rem_div = mod(state.tick_count, params.guidance_divider);
        guidance_due = (rem_div == uint32(0));
        state.have_tick = true;
        state.last_tick_seq = seq_now;
        state.last_t = t;
        state.tick_count = state.tick_count + uint32(1);
    end

    % ----- 2. one navigation operation -----
    [state.navigation, nav_out] = nav_codegen_step(params.navigation, state.navigation, in.nav);

    nav_p = zeros(3, 1);
    nav_v = zeros(3, 1);
    nav_eul = zeros(3, 1);
    nav_vbw = zeros(3, 1);
    nav_p(1) = nav_out.p(1); nav_p(2) = nav_out.p(2); nav_p(3) = nav_out.p(3);
    nav_v(1) = nav_out.v(1); nav_v(2) = nav_out.v(2); nav_v(3) = nav_out.v(3);
    nav_eul(1) = nav_out.euler(1); nav_eul(2) = nav_out.euler(2); nav_eul(3) = nav_out.euler(3);
    nav_vbw(1) = nav_out.vel_body_water(1);
    nav_vbw(2) = nav_out.vel_body_water(2);
    nav_vbw(3) = nav_out.vel_body_water(3);
    nav_init = logical(nav_out.initialized);
    nav_valid = logical(nav_out.valid);
    nav_hb = uint32(nav_out.health_bits);
    nav_finite = all_finite3(nav_p) && all_finite3(nav_v) && ...
        all_finite3(nav_eul) && all_finite3(nav_vbw);
    nav_init_finite = nav_init && nav_finite;
    nav_critical = (bitand(nav_hb, uint32(4)) ~= uint32(0)) || ...
        (bitand(nav_hb, uint32(32768)) ~= uint32(0)) || ...
        (bitand(nav_hb, uint32(65536)) ~= uint32(0));
    if ~nav_init
        hb = bitor(hb, uint32(64));
    end
    if nav_critical
        hb = bitor(hb, uint32(128));
    end

    % ----- 3. availability every tick (status only) -----
    acc = false(7, 1);
    acc(1) = logical(in.accepted(1));
    acc(2) = logical(in.accepted(2));
    acc(3) = logical(in.accepted(3));
    acc(4) = logical(in.accepted(4));
    acc(5) = logical(in.accepted(5));
    acc(6) = logical(in.accepted(6));
    acc(7) = logical(in.accepted(7));
    av_in = struct();
    av_in.t = t;
    av_in.init_done = nav_init;
    av_in.accepted = acc;
    [state.availability, av_out] = availability_codegen_step(params.availability, state.availability, av_in);
    av_state = uint8(av_out.state);
    av_hb = uint32(av_out.health_bits);

    % ----- 4. guidance on /3 ticks, else exact hold -----
    refs_finite = isfinite(state.yaw) && isfinite(state.pitch) && isfinite(state.u) && ...
        isfinite(state.r_ff) && isfinite(state.pitch_dot) && isfinite(state.progress_index);
    refs_corrupt = ~refs_finite;
    if refs_corrupt
        hb = bitor(hb, uint32(512));
        state.yaw = 0.0;
        state.pitch = 0.0;
        state.u = 0.0;
        state.r_ff = 0.0;
        state.pitch_dot = 0.0;
        state.progress_index = 1.0;
        state.guidance_ready = false;
        refs_finite = false;
    end
    run_guidance = guidance_due && nav_init_finite && path_ok && rates_ok && ...
        config_ok && input_ok && (~refs_corrupt) && (~nav_critical);
    if run_guidance
        path_mat = path_unpad(in.path_pad);
        pos = zeros(1, 3);
        pos(1) = nav_p(1);
        pos(2) = nav_p(2);
        pos(3) = nav_p(3);
        u_body = nav_vbw(1);
        v_body = nav_vbw(2);
        U_h = hypot(nav_v(1), nav_v(2));
        zdot_inertial = nav_v(3);
        theta_phys = nav_eul(2);
        [yaw_ref, pitch_ref, u_ref, next_progress_index, r_ff, pitch_ref_dot, state.guidance] = ...
            guidance_codegen_step(pos, path_mat, in.n_path, state.progress_index, ...
            u_body, v_body, U_h, zdot_inertial, theta_phys, params.guidance, state.guidance);
        g_ok = isfinite(yaw_ref) && isfinite(pitch_ref) && isfinite(u_ref) && ...
            isfinite(next_progress_index) && isfinite(r_ff) && isfinite(pitch_ref_dot);
        if g_ok
            state.yaw = yaw_ref;
            state.pitch = pitch_ref;
            state.u = u_ref;
            state.r_ff = r_ff;
            state.pitch_dot = pitch_ref_dot;
            state.progress_index = next_progress_index;
            state.guidance_ready = true;
            refs_finite = true;
        end
    end
    if ~(isfinite(state.yaw) && isfinite(state.pitch) && isfinite(state.u) && ...
            isfinite(state.r_ff) && isfinite(state.pitch_dot) && isfinite(state.progress_index))
        state.yaw = 0.0;
        state.pitch = 0.0;
        state.u = 0.0;
        state.r_ff = 0.0;
        state.pitch_dot = 0.0;
        state.progress_index = 1.0;
        state.guidance_ready = false;
        refs_finite = false;
    end
    if ~state.guidance_ready
        hb = bitor(hb, uint32(256));
    end

    % ----- 5. controller every tick when refs finite and nav initialized -----
    ctrl_dr = 0.0;
    ctrl_de = 0.0;
    ctrl_th = 0.0;
    ctrl_finite = true;
    run_controller = refs_finite && nav_init_finite && rates_ok && config_ok && ...
        order_ok && input_ok && (~refs_corrupt) && (~nav_critical);
    if run_controller
        c_in = struct();
        c_in.yaw_ref = state.yaw;
        c_in.pitch_ref = state.pitch;
        c_in.u_ref = state.u;
        c_in.psi = nav_eul(3);
        c_in.theta = nav_eul(2);
        c_in.r = br3;
        c_in.q = br2;
        c_in.u = nav_vbw(1);
        c_in.r_ff = state.r_ff;
        c_in.pitch_ref_dot = state.pitch_dot;
        c_in.phi = nav_eul(1);
        c_in.w = nav_vbw(3);
        c_in.p = br1;
        [state.controller, c_out] = controller_codegen_step(params.controller, state.controller, c_in);
        ctrl_dr = c_out.delta_r;
        ctrl_de = c_out.delta_e;
        ctrl_th = c_out.thrust;
        ctrl_finite = isfinite(ctrl_dr) && isfinite(ctrl_de) && isfinite(ctrl_th);
        if ~ctrl_finite
            ctrl_dr = 0.0;
            ctrl_de = 0.0;
            ctrl_th = 0.0;
        end
    elseif ~refs_finite
        ctrl_finite = false;
    end
    if ~ctrl_finite
        hb = bitor(hb, uint32(512));
    end

    % ----- 6. FDIR every tick from logical rudder command (status only) -----
    fd_in = struct();
    fd_in.t = t;
    fd_in.delta_r_cmd = ctrl_dr;
    fd_in.r = br3;
    fd_in.u = nav_vbw(1);
    fd_in.sample_valid = sample_valid;
    fd_in.seq = seq_now;
    [state.fdir, fd_out] = rudder_fdir_codegen_step(params.fdir, state.fdir, fd_in);
    fd_res = fd_out.residual;
    if ~isfinite(fd_res)
        fd_res = 0.0;
    end
    fd_latched = logical(fd_out.anomaly_latched);
    fd_hb = uint32(fd_out.health_bits);

    if kill_asserted
        hb = bitor(hb, uint32(1024));
    end
    if fd_latched
        hb = bitor(hb, uint32(2048));
    end
    if av_state == uint8(3)
        hb = bitor(hb, uint32(4096));
    end

    ready = config_ok && input_ok && order_ok && path_ok && rates_ok && ...
        nav_init_finite && logical(state.guidance_ready) && ctrl_finite && ...
        (~kill_asserted) && (~nav_critical);

    % ----- 7. arm/safety interlock -----
    % Status-only bits 2048/4096 never grant/remove authority or latch.
    latch_src = bitand(hb, uint32(1791));
    if state.arm_state == uint8(0)
        if ready
            state.healthy_streak = state.healthy_streak + uint32(1);
        else
            state.healthy_streak = uint32(0);
        end
        if arm_request && (~disarm_request) && ...
                (state.healthy_streak >= params.arm_min_healthy_ticks)
            state.arm_state = uint8(1);
        end
    elseif state.arm_state == uint8(1)
        if (latch_src ~= uint32(0)) || kill_asserted || nav_critical
            state.arm_state = uint8(2);
            state.fault_bits_latched = bitor(state.fault_bits_latched, latch_src);
            state.fault_bits_latched = bitor(state.fault_bits_latched, uint32(8192));
            state.healthy_streak = uint32(0);
        elseif disarm_request
            state.arm_state = uint8(0);
            state.healthy_streak = uint32(0);
        end
    else
        state.healthy_streak = uint32(0);
        state.fault_bits_latched = bitor(state.fault_bits_latched, latch_src);
        state.fault_bits_latched = bitor(state.fault_bits_latched, uint32(8192));
    end
    if state.arm_state == uint8(2)
        hb = bitor(hb, uint32(8192));
    end

    safe_thrust = params.safe_thrust;
    if ~isfinite(safe_thrust)
        safe_thrust = 0.0;
    end

    armed = (state.arm_state == uint8(1));
    if armed && ready
        dr_max = params.controller.delta_r_max;
        de_max = params.controller.delta_e_max;
        th_max = params.controller.thrust_max;
        th_min = params.controller.thrust_min;
        pub_dr = ctrl_dr;
        pub_de = ctrl_de;
        pub_th = ctrl_th;
        if isfinite(dr_max)
            if pub_dr > dr_max
                pub_dr = dr_max;
            end
            if pub_dr < (-dr_max)
                pub_dr = -dr_max;
            end
        end
        if isfinite(de_max)
            if pub_de > de_max
                pub_de = de_max;
            end
            if pub_de < (-de_max)
                pub_de = -de_max;
            end
        end
        if isfinite(th_max) && (pub_th > th_max)
            pub_th = th_max;
        end
        if isfinite(th_min) && (pub_th < th_min)
            pub_th = th_min;
        end
        command_valid = true;
    else
        pub_dr = 0.0;
        pub_de = 0.0;
        pub_th = safe_thrust;
        command_valid = false;
    end

    out = struct();
    out.delta_r = pub_dr;
    out.delta_e = pub_de;
    out.thrust = pub_th;
    out.command_valid = command_valid;
    out.arm_state = uint8(state.arm_state);
    out.ready = logical(ready);
    out.healthy_streak = uint32(state.healthy_streak);
    out.health_bits = uint32(hb);
    out.fault_bits_latched = uint32(state.fault_bits_latched);
    out.tick_count = uint32(state.tick_count);
    out.yaw = state.yaw;
    out.pitch = state.pitch;
    out.u = state.u;
    out.r_ff = state.r_ff;
    out.pitch_dot = state.pitch_dot;
    out.progress_index = state.progress_index;
    out.guidance_due = logical(guidance_due);
    out.guidance_ready = logical(state.guidance_ready);
    out.nav_p = nav_p;
    out.nav_v = nav_v;
    out.nav_euler = nav_eul;
    out.nav_vel_body_water = nav_vbw;
    out.nav_valid = nav_valid;
    out.nav_initialized = nav_init;
    out.nav_health_bits = nav_hb;
    out.availability_state = av_state;
    out.availability_health_bits = av_hb;
    out.fdir_residual = fd_res;
    out.fdir_anomaly_latched = fd_latched;
    out.fdir_health_bits = fd_hb;
    out.ctrl_delta_r = ctrl_dr;
    out.ctrl_delta_e = ctrl_de;
    out.ctrl_thrust = ctrl_th;
    out.physical_io_written = false;
    out.actuator_isolated = false;
    out.abort_requested = false;
end

function ok = path_is_valid(path_pad, n_path)
    ok = false;
    if ~isfinite(n_path)
        return;
    end
    if (n_path < 2.0) || (n_path > 32.0)
        return;
    end
    if n_path ~= floor(n_path)
        return;
    end
    for i = 1:96
        if ~isfinite(path_pad(i))
            return;
        end
    end
    ok = true;
end

function path_mat = path_unpad(path_pad)
    path_mat = zeros(32, 3);
    k = 1;
    for j = 1:3
        for i = 1:32
            path_mat(i, j) = path_pad(k);
            k = k + 1;
        end
    end
end

function ok = all_finite3(x)
    ok = isfinite(x(1)) && isfinite(x(2)) && isfinite(x(3));
end
