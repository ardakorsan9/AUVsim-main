# MATLAB — anlaşılır klasör düzeni

Önce repo kökünden bir kez:

```matlab
setup_auv_path
```

Sonra ana simülasyon:

```matlab
underwater777_vehicle_simulation
% veya
test_helix
test_straight_line
```

## Klasörler

| Klasör | Ne var | Bakılacak ilk dosyalar |
|---|---|---|
| **`cekirdek/`** | Araç dinamiği, guidance, kontrol, ana döngü | `underwater777_vehicle_simulation.m`, `guidance_law.m`, `controller_law.m`, `underwater777_vehicle_dynamics.m`, `init_parameters.m`, `continuous_path_tracking.m` |
| **`testler/`** | Hazır senaryo testleri | `test_straight_line.m`, `test_circle.m`, `test_helix.m`, `test_yaw_control.m`, `test_pitch_control.m` |
| **`yol_ve_cizim/`** | Yol üretimi, metrik, grafik | `generate_balanced_helical_path.m`, `plot_simulation_results.m` |
| **`codegen/`** | Gömülüye giden codegen sarmalayıcıları | `*_codegen_*.m` |
| **`deneyler/`** | Uzun `run_*` / gate / audit denemeleri (gelişmiş) | İhtiyaca göre; ilk okumada atlanabilir |

STM / tezgah kodları burada değil → [`../stm32/`](../stm32/).
