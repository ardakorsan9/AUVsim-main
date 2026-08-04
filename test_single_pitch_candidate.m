function test_single_pitch_candidate()
% Tek bir pitch trim adayı test eder - debug için
% delta_e = -2 deg, kısa süre

    init_parameters();

    % Önce speed trim bul
    u_target = 2.0;
    dt = 0.05;
    T_speed = 20;

    speed_trim = find_speed_trim(u_target, dt, T_speed);
    thrust_trim = speed_trim.thrust_trim;

    fprintf('\n=== SINGLE PITCH CANDIDATE TEST ===\n');
    fprintf('Thrust trim = %.3f N\n', thrust_trim);

    % Tek aday test et
    delta_e_deg = -2.0;
    T_pitch = 2.0;  % kısa süre

    limits.theta_max_deg = 70;
    limits.q_max_deg = 80;
    limits.u_max = 20;

    state0 = zeros(12,1);
    controls.delta_r = 0;
    controls.delta_e = deg2rad(delta_e_deg);
    controls.thrust = thrust_trim;

    fprintf('Testing delta_e = %.1f deg, T = %.1f s\n', delta_e_deg, T_pitch);

    try
        sim = simulate_open_loop_constant_input(state0, controls, dt, T_pitch, limits);

        fprintf('Simulation completed successfully!\n');
        fprintf('Final theta = %.3f deg\n', rad2deg(sim.final_state(5)));
        fprintf('Final q = %.3f deg/s\n', rad2deg(sim.final_state(11)));
        fprintf('Valid = %d\n', sim.valid);

        if ~sim.valid
            fprintf('Fail reason: %s\n', sim.fail_reason);
        end

    catch ME
        fprintf('ERROR in simulation: %s\n', ME.message);
        fprintf('Error ID: %s\n', ME.identifier);

        % Stack trace göster
        for k = 1:length(ME.stack)
            fprintf('  %s (line %d)\n', ME.stack(k).name, ME.stack(k).line);
        end
    end

    fprintf('\n=== TEST COMPLETE ===\n');
end