function path = generate_balanced_helical_path(radius, pitch, num_turns, num_points)


% t parameter represents the angular change of the helix
    t = linspace(0, num_turns * 2 * pi, num_points);  % Angular change

    % Helix in X and Y axes (radius from cos/sin of t)
        x = radius * cos(t);
    y = radius * sin(t);           % Y axis

    % Regular climb along the helix in the Z axis
    z = (pitch / (2 * pi)) * t;  
    path = [x', y', z'];  % Balanced path in X, Y, and Z axes


end
