# AUV Path Following Simulation

This is an AUV simulation in MATLAB using 6-DOF dynamics.

## Files

- `underwater777_vehicle_simulation.m`: Main helical path simulation.
- `continuous_path_tracking.m`: Simulation loop.
- `guidance_law.m`: Generates references.
- `controller_law.m`: PD controller.
- `underwater777_vehicle_dynamics.m`: Vehicle dynamics.
- `generate_balanced_helical_path.m`: Generates helical path.
- `plot_simulation_results.m`: Plots results.
- `init_parameters.m`: Parameters.
- `test_yaw_control.m`: Yaw control test.
- `test_pitch_control.m`: Pitch control test.
- `test_speed_control.m`: Speed control test.
- `test_straight_line.m`: Straight line test.
- `test_circle.m`: Circle test.
- `test_helix.m`: Helix test.

## Usage

Run main: `underwater777_vehicle_simulation()`

Run tests: `test_yaw_control()`, `test_pitch_control()`, `test_speed_control()`, `test_straight_line()`, `test_circle()`, `test_helix()`

## Recent Updates

- Guidance improved with progress tracking to prevent backwards movement.
- Simulation time decoupled from path points.
- Real references logged and used in plots.
- Angle wrapping removed from dynamics, handled in plots.
