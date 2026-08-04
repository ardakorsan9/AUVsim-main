function [delta_r, delta_e, thrust] = controller_law_trimmed(ref, meas, trim, gains)
    % Trim-offset controller
    %
    % ref.yaw_ref, ref.pitch_ref, ref.u_ref
    % meas.psi, meas.theta, meas.r, meas.q, meas.u
    % trim.delta_r_trim, trim.delta_e_trim, trim.thrust_trim
    % gains.Kp_psi, gains.Kd_psi, gains.Kp_theta, gains.Kd_theta, gains.Kp_u

    global delta_r_max delta_e_max thrust_max thrust_min

    e_psi = wrapToPi(ref.yaw_ref - meas.psi);
    e_theta = ref.pitch_ref - meas.theta;
    e_u = ref.u_ref - meas.u;

    % Yaw
    delta_r_cmd = gains.Kp_psi * e_psi - gains.Kd_psi * meas.r;

    % Pitch
    delta_e_cmd = gains.Kp_theta * e_theta - gains.Kd_theta * meas.q;

    % Speed
    thrust_cmd = gains.Kp_u * e_u;

    % Trim-offset
    delta_r = trim.delta_r_trim + delta_r_cmd;
    delta_e = trim.delta_e_trim + delta_e_cmd;
    thrust = trim.thrust_trim + thrust_cmd;

    % Saturation
    delta_r = max(min(delta_r, delta_r_max), -delta_r_max);
    delta_e = max(min(delta_e, delta_e_max), -delta_e_max);
    thrust = max(min(thrust, thrust_max), thrust_min);
end
