function pitch_lin = extract_pitch_subsystem(lin)
    % Full linear modelden reduced-order pitch subsystem çıkarır.
    % Reduced-order state: [w, q, theta]
    % Input: delta_e

    % Full state order:
    % [x y z phi theta psi u v w p q r]

    idx_w = 9;
    idx_q = 11;
    idx_theta = 5;

    idx_states = [idx_w, idx_q, idx_theta];

    % Inputs: [delta_r, delta_e, thrust]
    idx_delta_e = 2;

    Ap = lin.A(idx_states, idx_states);
    Bp = lin.B(idx_states, idx_delta_e);

    pitch_lin.Ap = Ap;
    pitch_lin.Bp = Bp;
    pitch_lin.state_order = {'w','q','theta'};
end
