function g_dot = underwater777_vehicle_dynamics(t, g, controls)
    % State order: [x y z phi theta psi u v w p q r]
    % Orientation: phi = roll, theta = pitch, psi = yaw
    % Body rates: p = roll rate, q = pitch rate, r = yaw rate

    if nargin < 3
        error('underwater777_vehicle_dynamics requires 3 inputs: t, g, controls');
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

    % States
    phi   = g(4);
    theta = g(5);
    psi   = g(6);
    u     = g(7);
    v     = g(8);
    w     = g(9);
    p     = g(10);
    q     = g(11);
    r     = g(12);

    % DEBUG: State girişini kontrol et
    if any(~isfinite(g))
        error('State vector g contains NaN/Inf');
    end

    % Euler singularity guard - sıkılaştırılmış
    if abs(cos(theta)) < 1e-3
        error('Euler singularity risk: theta = %.3f deg', rad2deg(theta));
    end

    % DEBUG: Rotasyon matrisi öncesi açıları kontrol et
    if ~isfinite(phi) || ~isfinite(theta) || ~isfinite(psi)
        error('Angles contain NaN/Inf: phi=%.6f, theta=%.6f, psi=%.6f', phi, theta, psi);
    end

    % Rotation matrix
    R = [cos(psi)*cos(theta), ...
         cos(psi)*sin(theta)*sin(phi) - sin(psi)*cos(phi), ...
         cos(psi)*sin(theta)*cos(phi) + sin(psi)*sin(phi);

         sin(psi)*cos(theta), ...
         sin(psi)*sin(theta)*sin(phi) + cos(psi)*cos(phi), ...
         sin(psi)*sin(theta)*cos(phi) - cos(psi)*sin(phi);

         -sin(theta), ...
         cos(theta)*sin(phi), ...
         cos(theta)*cos(phi)];

    pos_dot = R * [u; v; w];

    % DEBUG: R ve pos_dot sonrası kontrol
    if any(~isfinite(R), 'all')
        error('Rotation matrix R contains NaN/Inf');
    end

    if any(~isfinite(pos_dot))
        error('pos_dot contains NaN/Inf');
    end

    % Euler transformation matrix
    JJ = [1, sin(phi)*tan(theta), cos(phi)*tan(theta);
          0, cos(phi),           -sin(phi);
          0, sin(phi)/cos(theta), cos(phi)/cos(theta)];

    ang_dot = JJ * [p; q; r];

    % DEBUG: JJ ve ang_dot sonrası kontrol
    if any(~isfinite(JJ), 'all')
        error('JJ contains NaN/Inf');
    end

    if any(~isfinite(ang_dot))
        error('ang_dot contains NaN/Inf');
    end

    % Inputs
    delta_r = controls.delta_r;
    delta_e = controls.delta_e;
    Xprop   = controls.thrust;

    % Forces and moments
    X = -(W-B)*sin(theta) ...
        + Xuu*u*abs(u) ...
        + (Xwq-m)*w*q ...
        + (Xqq + m*xg)*q^2 ...
        + (Xvr+m)*v*r ...
        + (Xrr + m*xg)*r^2 ...
        - m*yg*p*q ...
        - m*zg*p*r ...
        + Xprop;

    % DEBUG: X kontrolü
    if ~isfinite(X), error('X is NaN/Inf'); end

    Y = (W-B)*cos(theta)*sin(phi) ...
        + Yvv*v*abs(v) ...
        + Yrr*r*abs(r) ...
        + Yuv*u*v ...
        + (Ywp+m)*w*p ...
        + (Yur-m)*u*r ...
        - (m*zg)*q*r ...
        + (Ypq - m*xg)*p*q ...
        + Yuudr*u^2*delta_r;

    % DEBUG: Y kontrolü
    if ~isfinite(Y), error('Y is NaN/Inf'); end

    Z = (W-B)*cos(theta)*cos(phi) ...
        + Zww*w*abs(w) ...
        + Zqq*q*abs(q) ...
        + Zuw*u*w ...
        + (Zuq+m)*u*q ...
        + (Zvp-m)*v*p ...
        + (m*zg)*p^2 ...
        + (m*zg)*q^2 ...
        + (Zrp - m*xg)*r*p ...
        + Zuuds*u^2*delta_e;

    % DEBUG: Z kontrolü
    if ~isfinite(Z), error('Z is NaN/Inf'); end

    K = (yg*W-yb*B)*cos(theta)*cos(phi) ...
        - (zg*W-zb*B)*cos(theta)*sin(phi) ...
        + Kpp*p*abs(p) ...
        - (Izz-Iyy)*q*r ...
        - (m*zg)*w*p ...
        + (m*zg)*u*r;

    % DEBUG: K kontrolü
    if ~isfinite(K), error('K is NaN/Inf'); end

    M = -(zg*W-zb*B)*sin(theta) ...
        - (xg*W-xb*B)*cos(theta)*cos(phi) ...
        + Mww*w*abs(w) ...
        + Mqq*q*abs(q) ...
        + (Mrp - (Ixx-Izz))*r*p ...
        + (m*zg)*v*r ...
        - (m*zg)*w*q ...
        + (Muq - m*xg)*u*q ...
        + Muw*u*w ...
        + (Mvp + m*xg)*v*p ...
        + Muuds*u^2*delta_e;

    % DEBUG: M kontrolü
    if ~isfinite(M), error('M is NaN/Inf'); end

    N = (xg*W-xb*B)*cos(theta)*sin(phi) ...
        + (yg*W-yb*B)*sin(theta) ...
        + Nvv*v*abs(v) ...
        + Nrr*r*abs(r) ...
        + Nuv*u*v ...
        + (Npq - (Iyy-Ixx))*p*q ...
        + (Nwp + m*xg)*w*p ...
        + (Nur - m*xg)*u*r ...
        + Nuudr*u^2*delta_r;

    % DEBUG: N kontrolü
    if ~isfinite(N), error('N is NaN/Inf'); end

    % Mass / added-mass matrix
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
end