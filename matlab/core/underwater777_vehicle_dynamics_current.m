function g_dot = underwater777_vehicle_dynamics_current(t, g, controls)
% UNDERWATER777_VEHICLE_DYNAMICS_CURRENT  Isolated constant-current plant hook.
% Production underwater777_vehicle_dynamics.m is untouched.
%
% Convention (explicit):
%   nu  = [u;v;w;p;q;r]  ground-relative BODY velocity (state)
%   Vc  = constant NED current [m/s] via global plant_Vc (default [0;0;0])
%   nu_c_lin = R(phi,theta,psi)' * Vc     (BODY, linear only; omega_c = 0)
%   nu_r_lin = [u;v;w] - nu_c_lin
%   eta_dot  = R * [u;v;w]                (KEEP ground kinematics; not R*nu_r)
%
% Hydro damping / lift / control-surface speed terms use nu_r_lin.
% Coriolis / centripetal / added-mass cross terms that involve linear
% velocity also use nu_r_lin with absolute body rates (omega_c=0), matching
% Fossen's preferred form for constant irrotational ocean current:
%   M*nu_dot + C(nu_r)*nu_r + D(nu_r)*nu_r + g(eta) = tau
% so that Vc=0 => exact identity with production RHS.
% Restoring (W-B) and pure rate^2 / rate-product terms unchanged.
%
% Diagnostics (last RHS eval): plant_last_nu, plant_last_nu_c, plant_last_nu_r,
%   plant_last_V_g_ned, plant_last_V_w_body, plant_last_forces (X..N).

    if nargin < 3
        error('underwater777_vehicle_dynamics_current requires 3 inputs: t, g, controls');
    end
    if numel(g) < 12
        error('State vector g must have 12 elements');
    end

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
    global Xudot Yvdot Yrdot Zwdot Zqdot Kpdot Mwdot Mqdot Nvdot Nrdot
    global Yuudr Zuuds Muuds Nuudr
    global plant_Vc
    global plant_last_nu plant_last_nu_c plant_last_nu_r
    global plant_last_V_g_ned plant_last_V_w_body plant_last_forces

    % States (ground-relative BODY)
    phi   = g(4);
    theta = g(5);
    psi   = g(6);
    u     = g(7);
    v     = g(8);
    w     = g(9);
    p     = g(10);
    q     = g(11);
    r     = g(12);

    if any(~isfinite(g))
        error('State vector g contains NaN/Inf');
    end
    if abs(cos(theta)) < 1e-3
        error('Euler singularity risk: theta = %.3f deg', rad2deg(theta));
    end
    if ~isfinite(phi) || ~isfinite(theta) || ~isfinite(psi)
        error('Angles contain NaN/Inf: phi=%.6f, theta=%.6f, psi=%.6f', phi, theta, psi);
    end

    % Rotation matrix BODY->NED
    R = [cos(psi)*cos(theta), ...
         cos(psi)*sin(theta)*sin(phi) - sin(psi)*cos(phi), ...
         cos(psi)*sin(theta)*cos(phi) + sin(psi)*sin(phi);

         sin(psi)*cos(theta), ...
         sin(psi)*sin(theta)*sin(phi) + cos(psi)*cos(phi), ...
         sin(psi)*sin(theta)*cos(phi) - cos(psi)*sin(phi);

         -sin(theta), ...
         cos(theta)*sin(phi), ...
         cos(theta)*cos(phi)];

    % Constant NED current -> BODY; relative linear velocity
    if isempty(plant_Vc)
        Vc = [0; 0; 0];
    else
        Vc = plant_Vc(:);
        if numel(Vc) ~= 3
            error('plant_Vc must be 3x1 NED [m/s]');
        end
    end
    nu_c_lin = R' * Vc;                 % BODY [m/s]
    ur = u - nu_c_lin(1);
    vr = v - nu_c_lin(2);
    wr = w - nu_c_lin(3);

    % KEEP ground kinematics: eta_dot = R * nu (not R*nu_r)
    pos_dot = R * [u; v; w];

    if any(~isfinite(R), 'all')
        error('Rotation matrix R contains NaN/Inf');
    end
    if any(~isfinite(pos_dot))
        error('pos_dot contains NaN/Inf');
    end

    JJ = [1, sin(phi)*tan(theta), cos(phi)*tan(theta);
          0, cos(phi),           -sin(phi);
          0, sin(phi)/cos(theta), cos(phi)/cos(theta)];
    ang_dot = JJ * [p; q; r];

    if any(~isfinite(JJ), 'all')
        error('JJ contains NaN/Inf');
    end
    if any(~isfinite(ang_dot))
        error('ang_dot contains NaN/Inf');
    end

    delta_r = controls.delta_r;
    delta_e = controls.delta_e;
    Xprop   = controls.thrust;

    % Forces/moments: hydro damping/lift/control-surface + Coriolis linear
    % couplings use (ur,vr,wr); rates absolute; restoring unchanged.
    X = -(W-B)*sin(theta) ...
        + Xuu*ur*abs(ur) ...
        + (Xwq-m)*wr*q ...
        + (Xqq + m*xg)*q^2 ...
        + (Xvr+m)*vr*r ...
        + (Xrr + m*xg)*r^2 ...
        - m*yg*p*q ...
        - m*zg*p*r ...
        + Xprop;

    if ~isfinite(X), error('X is NaN/Inf'); end

    Y = (W-B)*cos(theta)*sin(phi) ...
        + Yvv*vr*abs(vr) ...
        + Yrr*r*abs(r) ...
        + Yuv*ur*vr ...
        + (Ywp+m)*wr*p ...
        + (Yur-m)*ur*r ...
        - (m*zg)*q*r ...
        + (Ypq - m*xg)*p*q ...
        + Yuudr*ur^2*delta_r;

    if ~isfinite(Y), error('Y is NaN/Inf'); end

    Z = (W-B)*cos(theta)*cos(phi) ...
        + Zww*wr*abs(wr) ...
        + Zqq*q*abs(q) ...
        + Zuw*ur*wr ...
        + (Zuq+m)*ur*q ...
        + (Zvp-m)*vr*p ...
        + (m*zg)*p^2 ...
        + (m*zg)*q^2 ...
        + (Zrp - m*xg)*r*p ...
        + Zuuds*ur^2*delta_e;

    if ~isfinite(Z), error('Z is NaN/Inf'); end

    K = (yg*W-yb*B)*cos(theta)*cos(phi) ...
        - (zg*W-zb*B)*cos(theta)*sin(phi) ...
        + Kpp*p*abs(p) ...
        - (Izz-Iyy)*q*r ...
        - (m*zg)*wr*p ...
        + (m*zg)*ur*r;

    if ~isfinite(K), error('K is NaN/Inf'); end

    M = -(zg*W-zb*B)*sin(theta) ...
        - (xg*W-xb*B)*cos(theta)*cos(phi) ...
        + Mww*wr*abs(wr) ...
        + Mqq*q*abs(q) ...
        + (Mrp - (Ixx-Izz))*r*p ...
        + (m*zg)*vr*r ...
        - (m*zg)*wr*q ...
        + (Muq - m*xg)*ur*q ...
        + Muw*ur*wr ...
        + (Mvp + m*xg)*vr*p ...
        + Muuds*ur^2*delta_e;

    global diag_muw_enable diag_last_M_uw diag_last_M_elev diag_last_G_de diag_last_M_total
    if ~isempty(diag_muw_enable) && diag_muw_enable
        diag_last_M_uw = Muw * ur * wr;
        diag_last_G_de = Muuds * ur * ur;
        diag_last_M_elev = diag_last_G_de * delta_e;
        diag_last_M_total = M;
    end

    if ~isfinite(M), error('M is NaN/Inf'); end

    N = (xg*W-xb*B)*cos(theta)*sin(phi) ...
        + (yg*W-yb*B)*sin(theta) ...
        + Nvv*vr*abs(vr) ...
        + Nrr*r*abs(r) ...
        + Nuv*ur*vr ...
        + (Npq - (Iyy-Ixx))*p*q ...
        + (Nwp + m*xg)*wr*p ...
        + (Nur - m*xg)*ur*r ...
        + Nuudr*ur^2*delta_r;

    if ~isfinite(N), error('N is NaN/Inf'); end

    A = [m - Xudot, 0, 0, 0, m*zg, -m*yg;
         0, m - Yvdot, 0, -m*zg, 0, m*xg - Yrdot;
         0, 0, m - Zwdot, m*yg, -m*xg - Zqdot, 0;
         0, -m*zg, m*yg, Ixx - Kpdot, 0, 0;
         m*zg, 0, -m*xg - Mwdot, 0, Iyy - Mqdot, 0;
         -m*yg, m*xg - Nvdot, 0, 0, 0, Izz - Nrdot];

    J = [X; Y; Z; K; M; N];

    if any(~isfinite(A), 'all')
        error('A matrix contains NaN/Inf');
    end
    if any(~isfinite(J))
        error('J vector contains NaN/Inf');
    end
    if rcond(A) < 1e-12
        error('A matrix is singular or ill-conditioned. rcond(A)=%.3e', rcond(A));
    end

    C = A \ J;

    if any(~isfinite(C))
        error('Solved acceleration vector C contains NaN/Inf');
    end

    g_dot = zeros(12,1);
    g_dot(1:3)   = pos_dot;
    g_dot(4:6)   = ang_dot;
    g_dot(7:9)   = C(1:3);
    g_dot(10:12) = C(4:6);

    % Diagnostics (last RHS)
    plant_last_nu = [u; v; w; p; q; r];
    plant_last_nu_c = [nu_c_lin; 0; 0; 0];
    plant_last_nu_r = [ur; vr; wr; p; q; r];
    plant_last_V_g_ned = pos_dot;                 % ground velocity NED
    plant_last_V_w_body = [ur; vr; wr];           % water-relative BODY
    plant_last_forces = J;                        % [X;Y;Z;K;M;N]
end
