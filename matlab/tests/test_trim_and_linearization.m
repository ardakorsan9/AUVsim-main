function test_trim_and_linearization()
    clc; clear; close all;

    init_parameters();

    dt = 0.05;
    T_speed = 20;
    T_pitch = 5;

    %% 1) Speed trim
    u_target = 2.0;
    speed_trim = find_speed_trim(u_target, dt, T_speed);

    fprintf('\n========== SPEED TRIM RESULTS ==========\n');
    fprintf('Estimated thrust trim for u=%.2f m/s: %.3f N\n', ...
        u_target, speed_trim.thrust_trim);
    fprintf('Achieved steady u: %.3f m/s\n', speed_trim.u_final);

    %% 2) Pitch trim
    pitch_trim = find_pitch_trim(speed_trim.thrust_trim, dt, T_pitch);

    fprintf('\n========== PITCH TRIM RESULTS ==========\n');
    fprintf('Estimated elevator trim: %.3f deg (%.4f rad)\n', ...
        rad2deg(pitch_trim.delta_e_trim), pitch_trim.delta_e_trim);
    fprintf('Final theta with pitch trim: %.3f deg\n', rad2deg(pitch_trim.theta_final));
    fprintf('Final q with pitch trim: %.3f deg/s\n', rad2deg(pitch_trim.q_final));

    %% 3) Trim quality check
    theta_ok = abs(pitch_trim.theta_final) < deg2rad(10);
    q_ok = abs(pitch_trim.q_final) < deg2rad(5);

    fprintf('\nTrim Quality Check:\n');
    fprintf('  Theta < 10°: %s\n', local_bool_str(theta_ok));
    fprintf('  q < 5°/s  : %s\n', local_bool_str(q_ok));

    trim_quality = "poor";
    if theta_ok && q_ok
        trim_quality = "acceptable";
        fprintf('\n✓ ACCEPTABLE TRIM\n');
    else
        fprintf('\n✗ POOR TRIM\n');
    end

    %% 4) Plot trim diagnostics
    figure('Name','Trim Search Diagnostics','NumberTitle','off');

    subplot(2,1,1);
    plot(speed_trim.result.t, speed_trim.result.x(:,7), 'LineWidth', 1.5);
    grid on;
    xlabel('Time (s)');
    ylabel('u (m/s)');
    title(sprintf('Speed Trim Response (thrust = %.1f N)', speed_trim.thrust_trim));

    subplot(2,1,2);
    plot(pitch_trim.result.t, rad2deg(pitch_trim.result.x(:,5)), 'LineWidth', 1.5);
    hold on;
    plot(pitch_trim.result.t, rad2deg(pitch_trim.result.x(:,11)), '--', 'LineWidth', 1.2);
    grid on;
    xlabel('Time (s)');
    ylabel('Angle / Rate');
    title(sprintf('Pitch Trim Response (delta_e = %.2f°)', rad2deg(pitch_trim.delta_e_trim)));
    legend('\theta (deg)', 'q (deg/s)');

    fprintf('\n========== TEST COMPLETE ==========\n');
    fprintf('Trim Quality: %s\n', trim_quality);

    %% 5) Jacobian only if trim is acceptable
    if ~(theta_ok && q_ok)
        fprintf('\nNOTE: Jacobian skipped because trim is poor.\n');
        fprintf('First improve trim, then compute linearization.\n');
        return;
    end

    fprintf('\n========== JACOBIAN LINEARIZATION ==========\n');

    % Approximate trim state selection
    x0 = zeros(12,1);
    x0(5) = pitch_trim.theta_final;  % theta0
    x0(6) = pi/4;                    % psi0
    x0(7) = speed_trim.u_final;      % u0
    x0(8) = 0;                       % v0
    x0(9) = 0;                       % w0
    x0(10) = 0;                      % p0
    x0(11) = 0;                      % q0
    x0(12) = 0;                      % r0

    u0.delta_r = 0;
    u0.delta_e = pitch_trim.delta_e_trim;
    u0.thrust = speed_trim.thrust_trim;

    lin = numerical_linearize_auv(x0, u0, 1e-6, 1e-6);
    pitch_lin = extract_pitch_subsystem(lin);

    fprintf('Full-model eigenvalues:\n');
    disp(eig(lin.A));

    fprintf('Pitch reduced-order Ap:\n');
    disp(pitch_lin.Ap);

    fprintf('Pitch reduced-order Bp:\n');
    disp(pitch_lin.Bp);

    fprintf('Pitch subsystem eigenvalues:\n');
    disp(eig(pitch_lin.Ap));
end

function s = local_bool_str(cond)
    if cond
        s = 'YES';
    else
        s = 'NO';
    end
end
