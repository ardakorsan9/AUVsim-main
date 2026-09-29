function report = test_elevator_sign()
% Open-loop elevator sign test at fixed thrust / speed.
% Prints: +delta_e => theta_phys increases or decreases?

    init_parameters();
    global thrust_trim Muuds

    dt = 0.05;
    T = 8;
    thrust = thrust_trim;

    report = struct();
    for s = [+1, -1]
        de = s * deg2rad(3);
        state = zeros(12,1);
        state(7) = 1.5; % initial u
        th0 = 0;
        % brief settle with de=0
        c0 = struct('delta_r',0,'delta_e',0,'thrust',thrust);
        for k = 1:40
            [~,g] = ode45(@(t,x) underwater777_vehicle_dynamics(t,x,c0),[0 dt],state);
            state = g(end,:)';
        end
        th0 = -state(5); % physical

        c = struct('delta_r',0,'delta_e',de,'thrust',thrust);
        for k = 1:round(T/dt)
            [~,g] = ode45(@(t,x) underwater777_vehicle_dynamics(t,x,c),[0 dt],state);
            state = g(end,:)';
        end
        th1 = -state(5);
        dth = th1 - th0;

        if s > 0
            report.plus = struct('delta_e_deg', rad2deg(de), 'theta0_deg', rad2deg(th0), ...
                'theta1_deg', rad2deg(th1), 'dtheta_deg', rad2deg(dth), 'u_final', state(7));
        else
            report.minus = struct('delta_e_deg', rad2deg(de), 'theta0_deg', rad2deg(th0), ...
                'theta1_deg', rad2deg(th1), 'dtheta_deg', rad2deg(dth), 'u_final', state(7));
        end
        fprintf('delta_e = %+5.1f deg -> theta_phys %+6.2f -> %+6.2f (d=%+6.2f deg), u=%.2f | Muuds=%.2f\n', ...
            rad2deg(de), rad2deg(th0), rad2deg(th1), rad2deg(dth), state(7), Muuds);
    end

    % Convention we want for controller: +delta_e => +theta_phys (nose up)
    d_plus = report.plus.dtheta_deg;
    if d_plus > 0.5
        report.sign_ok = true;
        report.delta_e_sign = +1;
        fprintf('SIGN OK: +delta_e increases theta_phys. controller_sign = +1\n');
    elseif d_plus < -0.5
        report.sign_ok = false;
        report.delta_e_sign = -1;
        fprintf('SIGN FLIP NEEDED: +delta_e decreases theta_phys. Use controller_sign = -1\n');
    else
        report.sign_ok = false;
        report.delta_e_sign = +1;
        fprintf('SIGN UNCLEAR: small response (%.2f deg). Check speed/trim.\n', d_plus);
    end
end
