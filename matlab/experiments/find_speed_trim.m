function trim = find_speed_trim(u_target, dt, T_final)
% Hedef surge hızı için yaklaşık thrust trim bulur.

    init_parameters();

    limits.theta_max_deg = 70;
    limits.q_max_deg = 80;
    limits.u_max = 20;

    thrust_candidates = 0:1:25;

    best_err = inf;
    best_thrust = thrust_candidates(1);
    best_result = [];

    state0 = zeros(12,1);

    fprintf('\n=== SPEED TRIM SEARCH ===\n');

    for T = thrust_candidates
        controls.delta_r = 0;
        controls.delta_e = 0;
        controls.thrust = T;

        sim = simulate_open_loop_constant_input(state0, controls, dt, T_final, limits);

        if isempty(sim.t)
            fprintf('thrust = %.1f N -> invalid (no data)\n', T);
            continue;
        end

        u_final = sim.final_state(7);
        err = abs(u_final - u_target);

        fprintf('thrust = %.1f N -> final u = %.3f m/s, err = %.3f\n', T, u_final, err);

        if sim.valid && err < best_err
            best_err = err;
            best_thrust = T;
            best_result = sim;
        end
    end

    trim.thrust_trim = best_thrust;
    trim.u_target = u_target;
    trim.u_final = best_result.final_state(7);
    trim.result = best_result;

    fprintf('Best thrust trim = %.3f N, final u = %.3f m/s\n', trim.thrust_trim, trim.u_final);
end
