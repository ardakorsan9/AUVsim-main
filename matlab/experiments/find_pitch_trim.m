function trim = find_pitch_trim(thrust_trim, dt, T_final)
% Verilen thrust altında pitch trim elevator bulur.
% Önceki sonuçlara göre trim yaklaşık -4 ile 0 deg arasında aranır.

    init_parameters();

    limits.theta_max_deg = 70;
    limits.q_max_deg = 80;
    limits.u_max = 20;

    elevator_candidates_deg = -4:0.25:0;

    best_err = inf;
    best_delta_e = deg2rad(elevator_candidates_deg(1));
    best_result = [];

    state0 = zeros(12,1);

    fprintf('\n=== PITCH TRIM SEARCH ===\n');
    fprintf('Using thrust trim = %.3f N\n', thrust_trim);

    for de_deg = elevator_candidates_deg
        controls.delta_r = 0;
        controls.delta_e = deg2rad(de_deg);
        controls.thrust = thrust_trim;

        sim = simulate_open_loop_constant_input(state0, controls, dt, T_final, limits);

        if isempty(sim.t)
            fprintf('delta_e = %.2f deg -> invalid (no data)\n', de_deg);
            continue;
        end

        theta_final = sim.final_state(5);
        q_final = sim.final_state(11);

        % Son değer + drift benzeri basit hata kriteri
        if size(sim.x,1) >= 5
            theta_tail = sim.x(max(1,end-4):end, 5);
            theta_drift = abs(theta_tail(end) - theta_tail(1));
        else
            theta_drift = abs(theta_final);
        end

        if sim.valid
            err = abs(theta_final) + 0.75*abs(q_final) + 0.5*theta_drift;
        else
            err = 1e6; % patlayan adayları çok kötü say
        end

        fprintf('delta_e = %+5.2f deg -> theta = %+7.3f deg, q = %+7.3f deg/s, drift = %.3f deg, valid = %d\n', ...
            de_deg, rad2deg(theta_final), rad2deg(q_final), rad2deg(theta_drift), sim.valid);

        if sim.valid && err < best_err
            best_err = err;
            best_delta_e = controls.delta_e;
            best_result = sim;
        end
    end

    trim.delta_e_trim = best_delta_e;
    trim.theta_final = best_result.final_state(5);
    trim.q_final = best_result.final_state(11);
    trim.result = best_result;

    fprintf('\nBest delta_e trim = %.3f deg\n', rad2deg(trim.delta_e_trim));
    fprintf('Final theta = %.3f deg\n', rad2deg(trim.theta_final));
    fprintf('Final q = %.3f deg/s\n', rad2deg(trim.q_final));
end