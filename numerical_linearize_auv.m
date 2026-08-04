function lin = numerical_linearize_auv(x0, u0, eps_x, eps_u)
    % Full nonlinear AUV modelini x0, u0 etrafında sayısal lineerleştirir.
    %
    % x0 : 12x1 trim state
    % u0 : struct with delta_r, delta_e, thrust
    % eps_x, eps_u : perturbation büyüklükleri

    if nargin < 3 || isempty(eps_x)
        eps_x = 1e-6;
    end
    if nargin < 4 || isempty(eps_u)
        eps_u = 1e-6;
    end

    n = length(x0);
    m = 3; % [delta_r, delta_e, thrust]

    A = zeros(n, n);
    B = zeros(n, m);

    f0 = underwater777_vehicle_dynamics(0, x0, u0);

    % State Jacobian
    for i = 1:n
        dx = zeros(n,1);
        dx(i) = eps_x;

        fp = underwater777_vehicle_dynamics(0, x0 + dx, u0);
        fm = underwater777_vehicle_dynamics(0, x0 - dx, u0);

        A(:, i) = (fp - fm) / (2 * eps_x);
    end

    % Input Jacobian
    % Input vector order: [delta_r, delta_e, thrust]
    for j = 1:m
        up = u0;
        um = u0;

        switch j
            case 1
                up.delta_r = up.delta_r + eps_u;
                um.delta_r = um.delta_r - eps_u;
            case 2
                up.delta_e = up.delta_e + eps_u;
                um.delta_e = um.delta_e - eps_u;
            case 3
                up.thrust = up.thrust + eps_u;
                um.thrust = um.thrust - eps_u;
        end

        fp = underwater777_vehicle_dynamics(0, x0, up);
        fm = underwater777_vehicle_dynamics(0, x0, um);

        B(:, j) = (fp - fm) / (2 * eps_u);
    end

    lin.A = A;
    lin.B = B;
    lin.f0 = f0;
    lin.x0 = x0;
    lin.u0 = u0;
end
