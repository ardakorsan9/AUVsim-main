# Autonomous Underwater Vehicle (AUV) - MATLAB + STM32

This repo is split into two clear top-level areas:

| Folder | Contents |
|---|---|
| [`matlab/`](matlab/) | Simulation, path following, PID / guidance / dynamics |
| [`stm32/`](stm32/) | Bench sketches + embedded skeleton (**WIP**) |
| [`docs/`](docs/) | PDF and status docs |
| [`tools/`](tools/) | Codegen / validation helpers |

**PDF:** [docs/underwater.pdf](docs/underwater.pdf)  
**STM WIP status:** [docs/STM32_DEVELOPMENT_STATUS.md](docs/STM32_DEVELOPMENT_STATUS.md)

---

## Quick start (MATLAB)

```matlab
cd('.../AUVsim-main')   % repo root
setup_auv_path          % adds matlab/* to the path
underwater777_vehicle_simulation
% or: test_helix / test_straight_line
```

MATLAB subfolders: [`matlab/README.md`](matlab/README.md)

---

## 1. What is the vehicle?

Target platform: small **single-propeller** AUV with **two servos** (rudder + elevator).

| Feature | Description |
|---|---|
| Propulsion | A2212 ~930 KV + ESC 30A (bidirectional) |
| Yaw / pitch | 2x MG996R (PB4 / PB5) |
| Depth | MPS20N0040D + HX710 |
| Attitude | MPU6050 |
| Leak | Leak / rain AO |
| Brain | STM32F411 BlackPill |
| Power | 3S LiPo -> fuse -> ESC + UBEC 5V (servos) |
| Bench | CP2102 UART, ST-Link SWD |

In simulation, x,y,z are fully known. On hardware **z ~ pressure**; horizontal distance uses calibrated dead reckoning (no GPS underwater).

---

## 2. Electronics (summary)

STM32F411, ST-Link, CP2102, MPU6050, MPS20, leak, 2x servo, motor, ESC, UBEC, 3S LiPo, XT60, fuse, 470 uF / 100 nF / resistors, stripboard.

ESC BEC 5V is **not connected**. Servos use **UBEC 5V**.

Pin summary: ESC PB0 · servo PB4/PB5 · I2C PB6/PB7 · pressure PB12/PB13 · leak PA5 · UART PA9/PA10.

---

## 3. STM32 (WIP)

```
stm32/
  bench/       <- 01_blink ... 17_goto_222
  embedded/    <- CubeMX + App + Src + generated
```

Maturity: bench + bringup **medium**; closed-loop in water **early**.  
Details: [stm32/README.md](stm32/README.md)

---

## 4. Repository map

```
AUVsim-main/
|-- README.md                 <- you are here
|-- setup_auv_path.m          <- MATLAB path helper
|-- matlab/
|   |-- core/                 <- main simulation
|   |-- tests/
|   |-- path_plot/
|   |-- codegen/
|   |-- experiments/          <- run_* experiments (advanced)
|-- stm32/
|   |-- bench/
|   |-- embedded/
|-- docs/
|   |-- underwater.pdf
|   |-- STM32_DEVELOPMENT_STATUS.md
|-- tools/
```

---

## License / safety

Student prototype. Propeller-off bench tests; observe LiPo safety.
