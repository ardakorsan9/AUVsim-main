function init_parameters()
    % Define global variables
    global m W B g_m
    global xg yg zg
    global xb yb zb
    global Xuu Xwq Xqq Xvr Xrr
    global Yvv Yrr Yuv Ywp Yur Ypq
    global Zww Zqq Zuw Zuq Zvp Zrp
    global Kpp
    global Mww Mqq Mrp Muq Muw Mvp
    global Nvv Nrr Nuv Npq Nwp Nur
    global Ixx Iyy Izz
    global Kp_psi Kd_psi Kp_theta Kd_theta Ki_theta Kp_x Kd_x
    global Kp_angle Ki_angle Kp_rate Ki_rate Kaw_pitch Kd_rate Kd_damp
    global Xudot Yvdot Yrdot Zwdot Zqdot Kpdot Mwdot Mqdot Nvdot Nrdot
    global Yuudr Zuuds Muuds Nuudr
    global elevator_sign
    global trim_speed_table trim_elevator_table

    g_m = 9.81;
    W = 3.05e2;
    B = 3.1e2;
    m = W / g_m;

    Ixx = 1.77e-1;
    Iyy = 3.45;
    Izz = 3.45;

    xg = 0.0; yg = 0.00; zg = 1.96e-2;
    xb = 0.0; yb = 0.00; zb = 0.0;

    Xuu = -1.62; Xwq = -3.55e1; Xqq = -1.93; Xvr = 3.55e1; Xrr = -1.93;
    Yvv = -1.31e3; Yrr = 6.32e-1; Yuv = -2.86e1; Ywp = 3.55e1; Yur = 5.22; Ypq = 1.93;
    Zww = -1.31e2; Zqq = -6.32e-1; Zuw = -2.86e1; Zuq = -5.22; Zvp = -3.55e1; Zrp = 1.93;
    Kpp = -1.3e-1;
    Mww = 3.18; Mqq = -1.88e2; Mrp = 4.86; Muq = -2; Muw = 2.40e1; Mvp = -1.93;
    Nvv = -3.18; Nrr = -9.40e1; Nuv = -2.40e1; Npq = -4.86; Nwp = -1.93; Nur = -2.00;

    Xudot = -9.30e-1; Yvdot = -3.55e1; Yrdot = 1.93; Zwdot = -3.55e1; Zqdot = -1.93;
    Kpdot = -7.04e-2; Mwdot = -1.93; Mqdot = -4.88; Nvdot = 1.93; Nrdot = -4.88;

    Yuudr = 9.64;
    Zuuds = -9.64;
    Muuds = -6.15;
    Nuudr = 6.15;

    % Legacy names (unused by cascaded pitch, kept for older scripts)
    Kp_theta = 5.5; Kd_theta = 12; Ki_theta = 0.35;

    % Sample periods (T1B multi-rate: fast rate loop, slow guidance + ZOH)
    % Legacy production used hard-coded dt=0.075 everywhere.
    global dt_controller dt_guidance tau_rate
    dt_controller = 0.025;   % rate/angle loop + plant step
    dt_guidance   = 0.075;   % guidance tick; outputs held (ZOH) between ticks
    % Rate LPF physical time constant: preserve a=0.90 at old dt=0.075
    %   rate_filt = 0.90*prev + 0.10*raw  =>  tau = -dt/ln(0.90)
    tau_rate = -0.075 / log(0.90);  % ≈ 0.712 s

    % Cascaded pitch: mid gains + rate damping
    Kp_angle = 1.25;   % [1/s]  e_theta -> rate cmd
    Ki_angle = 0.16;
    Kp_rate  = 0.95;   % [s]    e_rate -> elevator
    Ki_rate  = 0.0;   % T2A: disable pitch rate integrator
    Kaw_pitch = 1.2;
    Kd_rate = 0.0;     % e_rate derivative off
    Kd_damp = 0.80;    % physical-rate damping on elevator [s]

    Kp_psi = 32;
    Kd_psi = 13;
    Kp_x = 25;
    Kd_x = 5;

    global delta_r_max delta_e_max thrust_max thrust_min lookahead_distance desired_speed
    delta_r_max = deg2rad(25);
    delta_e_max = deg2rad(15);
    thrust_max = 300;
    thrust_min = -100;
    lookahead_distance = 1.25;
    desired_speed = 1.5;

    global delta_e_trim thrust_trim u_trim
    delta_e_trim = deg2rad(-3.0);
    thrust_trim = 13.4;
    u_trim = 1.5;

    % Default until test_elevator_sign / build_pitch_trim_table update them
    if isempty(elevator_sign); elevator_sign = 1; end
    if isempty(trim_speed_table)
        % From successful build_pitch_trim_table (level within ~1.5°)
        trim_speed_table = [0.8 1.0 1.5 2.0];
        trim_elevator_table = deg2rad([-2.75 -2.50 -1.75 -1.25]);
    end

    % Guidance pitch limits
    global pitch_ref_max pitch_ref_rate_max
    pitch_ref_max = deg2rad(26);
    pitch_ref_rate_max = deg2rad(6);
end
