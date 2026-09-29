function g_dot = underwater777_vehicle_dynamics(t, g, desired_position)
    global m W B g_m % vehicle mass, weight, and buoyancy force
    global xg yg zg % center of mass coordinates on x,y,z axes
    global xb yb zb % center of buoyancy coordinates on x,y,z axes
    global Xuu Xwq Xqq Xvr Xrr % hydrodynamic coefficients in X direction.
    global Yvv Yrr Yuv Ywp Yur Ypq % hydrodynamic coefficients in Y direction.
    global Zww Zqq Zuw Zuq Zvp Zrp % hydrodynamic coefficients in Z direction.
    global Kpp % hydrodynamic coefficient for roll.
    global Mww Mqq Mrp Muq Muw Mvp % hydrodynamic coefficients for pitch.
    global Nvv Nrr Nuv Npq Nwp Nur % hydrodynamic coefficients for yaw motion
    global Ixx Iyy Izz % vehicle moments of inertia about x, y, z axes
    global Kp_psi Kd_psi Kp_theta Kd_theta Kp_x Kd_x Kp_y Kd_y Kd_phi Kp_phi
    global Xudot Yvdot Yrdot Zwdot Zqdot Kpdot Mwdot Mqdot Nvdot Nrdot
    global Yuudr Zuuds Muuds Nuudr
    global Xprop Kprop

    % Extract state variables
    x = g(1); y = g(2); z = g(3);
    phi = g(4); theta = g(5); psi = g(6);
    u = g(7); v = g(8); w = g(9);
    p = g(10); q = g(11); r = g(12);

    % Rotation matrix
    R = [cos(psi)*cos(theta), cos(psi)*sin(theta)*sin(phi) - sin(psi)*cos(phi), cos(psi)*sin(theta)*cos(phi) + sin(psi)*sin(phi);
         sin(psi)*cos(theta), sin(psi)*sin(theta)*sin(phi) + cos(psi)*cos(phi), sin(psi)*sin(theta)*cos(phi) - cos(psi)*sin(phi);
         -sin(theta), cos(theta)*sin(phi), cos(theta)*cos(phi)];

    % Position derivatives in world coordinates
    pos_dot = R * [u; v; w];
    x_dot = pos_dot(1);
    y_dot = pos_dot(2);
    z_dot = pos_dot(3);

    % Euler transformation matrix
    JJ = [1, sin(phi)*tan(theta), cos(phi)*tan(theta); 
          0, cos(phi), -sin(phi); 
          0, sin(phi)/cos(theta), cos(phi)/cos(theta)];

    % Angular rate derivatives
    ang_dot = JJ * [p; q; r];
    phi_dot = ang_dot(1);
    theta_dot = ang_dot(2);
    psi_dot = ang_dot(3);



    % Difference between current and desired position
    current_position = g(1:3);
    delta_pos = desired_position - current_position;

    % Angles and desired position
    theta_d = -atan2(delta_pos(3), norm(delta_pos(1:2))); % Pitch
    psi_d = atan2(delta_pos(2), delta_pos(1));          % Yaw
    x_d = desired_position(1);                          % X target


    % Control inputs
    e_x = x_d - x;
    Xprop = Kp_x * e_x + Kd_x * x_dot;

    % Pitch control
    e_theta = theta_d - theta;
    delta_s = -Kp_theta * e_theta + Kd_theta * theta_dot;

    % Yaw control
    e_psi = psi_d - psi;
    delta_r = -Kp_psi * e_psi + Kd_psi * psi_dot;

    % Forces and moments
    X = -(W-B)*sin(theta) + Xuu*u*abs(u) + (Xwq-m)*w*q + (Xqq + m*xg)*q^2 + (Xvr+m)*v*r + (Xrr + m*xg)*r^2 -m*yg*p*q - m*zg*p*r + Xprop;
 
    Y = (W-B)*cos(theta)*sin(phi) + Yvv*v*abs(v) + Yrr*r*abs(r) + Yuv*u*v + (Ywp+m)*w*p + (Yur-m)*u*r - (m*zg)*q*r + (Ypq - m*xg)*p*q + Yuudr*u^2*delta_r;

    Z = (W-B)*cos(theta)*cos(phi) + Zww*w*abs(w) + Zqq*q*abs(q)+ Zuw*u*w + (Zuq+m)*u*q + (Zvp-m)*v*p + (m*zg)*p^2 + (m*zg)*q^2 + (Zrp - m*xg)*r*p + Zuuds*u^2*delta_s;

    K = -(yg*W-yb*B)*cos(theta)*cos(phi) - (zg*W-zb*B)*cos(theta)*sin(phi) + Kpp*p*abs(p) - (Izz- Iyy)*q*r - (m*zg)*w*p + (m*zg)*u*r;

    M = -(zg*W-zb*B)*sin(theta) - (xg*W-xb*B)*cos(theta)*cos(phi) + Mww*w*abs(w) + Mqq*q*abs(q) + (Mrp - (Ixx-Izz))*r*p + (m*zg)*v*r - (m*zg)*w*q + (Muq - m*xg)*u*q + Muw*u*w + (Mvp + m*xg)*v*p  + Muuds*u^2*delta_s;

    N = -(xg*W-xb*B)*cos(theta)*sin(phi) - (yg*W-yb*B)*sin(theta) + Nvv*v*abs(v) + Nrr*r*abs(r) + Nuv*u*v + (Npq - (Iyy- Ixx))*p*q + (Nwp - m*xg)*w*p + (Nur + m*xg)*u*r + Nuudr*u^2*delta_r;
   
    % System dynamics matrix
    A = [m - Xudot, 0, 0, 0, m * zg, -m * yg;
         0, m - Yvdot, 0, -m * zg, 0, m * xg - Yrdot;
         0, 0, m - Zwdot, m * yg, -m * xg - Zqdot, 0;
         0, -m * zg, m * yg, Ixx - Kpdot, 0, 0;
         m * zg, 0, -m * xg - Mwdot, 0, Iyy - Mqdot, 0;
         -m * yg, m * xg - Nvdot, 0, 0, 0, Izz - Nrdot];

    J = [X; Y; Z; K; M; N];

    % Solve linear system
    C = A\J;

    % Update state derivatives
    g_dot = zeros(12, 1);
    g_dot(1:3) = pos_dot;      % Position derivatives
    g_dot(4:6) = ang_dot;      % Orientation derivatives
    g_dot(7:9) = C(1:3);       % Velocity derivatives
    g_dot(10:12) = C(4:6);     % Angular velocity derivatives
end
