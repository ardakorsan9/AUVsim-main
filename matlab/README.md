# MATLAB — folder layout

From the repo root, run once:

```matlab
setup_auv_path
```

Then the main simulation:

```matlab
underwater777_vehicle_simulation
% or
test_helix
test_straight_line
```

## Folders

| Folder | What is here | Start with |
|---|---|---|
| **`core/`** | Vehicle dynamics, guidance, control, main loop | `underwater777_vehicle_simulation.m`, `guidance_law.m`, `controller_law.m`, `underwater777_vehicle_dynamics.m`, `init_parameters.m`, `continuous_path_tracking.m` |
| **`tests/`** | Ready scenario tests | `test_straight_line.m`, `test_circle.m`, `test_helix.m`, `test_yaw_control.m`, `test_pitch_control.m` |
| **`path_plot/`** | Path generation, metrics, plots | `generate_balanced_helical_path.m`, `plot_simulation_results.m` |
| **`codegen/`** | Embedded codegen wrappers | `*_codegen_*.m` |
| **`experiments/`** | Long `run_*` / gate / audit experiments (advanced) | Skip on first read |

STM / bench code is not here → [`../stm32/`](../stm32/).
