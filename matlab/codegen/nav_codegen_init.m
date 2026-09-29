function params = nav_codegen_init()
%NAV_CODEGEN_INIT Frozen Gate 5C Params with config_valid.
% DEPLOY_CANDIDATE / NOT_IN_PRODUCTION / NOT_CERTIFIED
% Isolated explicit-state runtime. Constants remain ASSUMED and are not retuned.
%
% TASK_ID: NAV_RUNTIME_001

    g_ned = 9.81;

    sigma_p = 0.0;
    sigma_a = 2.0e-3;
    sigma_g = 3.5e-4;
    sigma_bg = 1.0e-5;
    sigma_ba = 1.0e-4;
    sigma_c = 1.0e-3;

    R_depth = 0.020 * 0.020;
    R_heading = (0.5 * pi / 180.0) * (0.5 * pi / 180.0);
    R_ins = zeros(3, 1);
    R_ins(1) = 0.020 * 0.020;
    R_ins(2) = 0.020 * 0.020;
    R_ins(3) = 0.030 * 0.030;
    R_dvl = zeros(3, 1);
    R_dvl(1) = 0.010 * 0.010;
    R_dvl(2) = 0.010 * 0.010;
    R_dvl(3) = 0.015 * 0.015;
    R_usbl = zeros(3, 1);
    R_usbl(1) = 1.50 * 1.50;
    R_usbl(2) = 1.50 * 1.50;
    R_usbl(3) = 0.80 * 0.80;

    lat_depth = 0.60;
    lat_heading = 0.30;
    lat_ins = 0.50;
    lat_dvl = 0.50;
    lat_usbl = 1.50;

    P0_p = zeros(3, 1);
    P0_p(1) = 0.10 * 0.10;
    P0_p(2) = 0.10 * 0.10;
    P0_p(3) = 0.50 * 0.50;
    P0_p_abs = 100.0 * 100.0;
    P0_v = zeros(3, 1);
    P0_v(1) = 0.30 * 0.30;
    P0_v(2) = 0.30 * 0.30;
    P0_v(3) = 0.30 * 0.30;
    P0_th = zeros(3, 1);
    P0_th(1) = (2.0 * pi / 180.0) * (2.0 * pi / 180.0);
    P0_th(2) = (2.0 * pi / 180.0) * (2.0 * pi / 180.0);
    P0_th(3) = (3.0 * pi / 180.0) * (3.0 * pi / 180.0);
    P0_bg = zeros(3, 1);
    P0_bg(1) = 0.010 * 0.010;
    P0_bg(2) = 0.010 * 0.010;
    P0_bg(3) = 0.010 * 0.010;
    P0_ba = zeros(3, 1);
    P0_ba(1) = 0.050 * 0.050;
    P0_ba(2) = 0.050 * 0.050;
    P0_ba(3) = 0.050 * 0.050;
    P0_c = zeros(3, 1);
    P0_c(1) = 0.50 * 0.50;
    P0_c(2) = 0.50 * 0.50;
    P0_c(3) = 0.50 * 0.50;

    q_min_frac = 0.20;
    q_floor = 0.20;
    nis_scale = 100.0;
    dt_prop_max = 0.050;
    dt_prop_sub = 0.010;
    n_sub_max = 5.0;
    tol_time = 1.0e-12;
    tol_pair = 1.0e-9;

    config_valid = isfinite(g_ned) && (g_ned > 0.0) && ...
        isfinite(sigma_p) && (sigma_p >= 0.0) && ...
        isfinite(sigma_a) && (sigma_a >= 0.0) && ...
        isfinite(sigma_g) && (sigma_g >= 0.0) && ...
        isfinite(sigma_bg) && (sigma_bg >= 0.0) && ...
        isfinite(sigma_ba) && (sigma_ba >= 0.0) && ...
        isfinite(sigma_c) && (sigma_c >= 0.0) && ...
        isfinite(R_depth) && (R_depth > 0.0) && ...
        isfinite(R_heading) && (R_heading > 0.0) && ...
        isfinite(R_ins(1)) && isfinite(R_ins(2)) && isfinite(R_ins(3)) && ...
        (R_ins(1) > 0.0) && (R_ins(2) > 0.0) && (R_ins(3) > 0.0) && ...
        isfinite(R_dvl(1)) && isfinite(R_dvl(2)) && isfinite(R_dvl(3)) && ...
        (R_dvl(1) > 0.0) && (R_dvl(2) > 0.0) && (R_dvl(3) > 0.0) && ...
        isfinite(R_usbl(1)) && isfinite(R_usbl(2)) && isfinite(R_usbl(3)) && ...
        (R_usbl(1) > 0.0) && (R_usbl(2) > 0.0) && (R_usbl(3) > 0.0) && ...
        isfinite(lat_depth) && (lat_depth >= 0.0) && ...
        isfinite(lat_heading) && (lat_heading >= 0.0) && ...
        isfinite(lat_ins) && (lat_ins >= 0.0) && ...
        isfinite(lat_dvl) && (lat_dvl >= 0.0) && ...
        isfinite(lat_usbl) && (lat_usbl >= 0.0) && ...
        isfinite(P0_p(1)) && isfinite(P0_p(2)) && isfinite(P0_p(3)) && ...
        (P0_p(1) > 0.0) && (P0_p(2) > 0.0) && (P0_p(3) > 0.0) && ...
        isfinite(P0_p_abs) && (P0_p_abs > 0.0) && ...
        isfinite(P0_v(1)) && isfinite(P0_v(2)) && isfinite(P0_v(3)) && ...
        (P0_v(1) > 0.0) && (P0_v(2) > 0.0) && (P0_v(3) > 0.0) && ...
        isfinite(P0_th(1)) && isfinite(P0_th(2)) && isfinite(P0_th(3)) && ...
        (P0_th(1) > 0.0) && (P0_th(2) > 0.0) && (P0_th(3) > 0.0) && ...
        isfinite(P0_bg(1)) && isfinite(P0_bg(2)) && isfinite(P0_bg(3)) && ...
        (P0_bg(1) > 0.0) && (P0_bg(2) > 0.0) && (P0_bg(3) > 0.0) && ...
        isfinite(P0_ba(1)) && isfinite(P0_ba(2)) && isfinite(P0_ba(3)) && ...
        (P0_ba(1) > 0.0) && (P0_ba(2) > 0.0) && (P0_ba(3) > 0.0) && ...
        isfinite(P0_c(1)) && isfinite(P0_c(2)) && isfinite(P0_c(3)) && ...
        (P0_c(1) > 0.0) && (P0_c(2) > 0.0) && (P0_c(3) > 0.0) && ...
        isfinite(q_min_frac) && (q_min_frac > 0.0) && ...
        isfinite(q_floor) && (q_floor > 0.0) && ...
        isfinite(nis_scale) && (nis_scale > 0.0) && ...
        isfinite(dt_prop_max) && (dt_prop_max > 0.0) && ...
        isfinite(dt_prop_sub) && (dt_prop_sub > 0.0) && ...
        isfinite(n_sub_max) && (n_sub_max >= 1.0) && ...
        isfinite(tol_time) && (tol_time > 0.0) && ...
        isfinite(tol_pair) && (tol_pair > 0.0);

    params = struct();
    params.g_ned = g_ned;
    params.sigma_p = sigma_p;
    params.sigma_a = sigma_a;
    params.sigma_g = sigma_g;
    params.sigma_bg = sigma_bg;
    params.sigma_ba = sigma_ba;
    params.sigma_c = sigma_c;
    params.R_depth = R_depth;
    params.R_heading = R_heading;
    params.R_ins = R_ins;
    params.R_dvl = R_dvl;
    params.R_usbl = R_usbl;
    params.lat_depth = lat_depth;
    params.lat_heading = lat_heading;
    params.lat_ins = lat_ins;
    params.lat_dvl = lat_dvl;
    params.lat_usbl = lat_usbl;
    params.P0_p = P0_p;
    params.P0_p_abs = P0_p_abs;
    params.P0_v = P0_v;
    params.P0_th = P0_th;
    params.P0_bg = P0_bg;
    params.P0_ba = P0_ba;
    params.P0_c = P0_c;
    params.q_min_frac = q_min_frac;
    params.q_floor = q_floor;
    params.nis_scale = nis_scale;
    params.dt_prop_max = dt_prop_max;
    params.dt_prop_sub = dt_prop_sub;
    params.n_sub_max = n_sub_max;
    params.tol_time = tol_time;
    params.tol_pair = tol_pair;
    params.config_valid = config_valid;
end
