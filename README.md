# Autonomous Underwater Vehicle (AUV) — MATLAB + STM32

Student / prototype AUV stack: **MATLAB closed-loop path following in simulation**, plus **STM32F411 hardware bring-up (WIP)**.

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
% or: test_helix / test_straight_line / test_circle
```

In MATLAB the vehicle **does** closed-loop path tracking (guidance → controller → 6-DOF dynamics). That is the working reference. Hardware autonomy in water is still early.

More layout detail: [`matlab/README.md`](matlab/README.md)

---

## The hard problem: no GPS underwater

**Depth is the easy axis. Horizontal position is the hard one.**

| Quantity | Simulation | Real vehicle underwater |
|---|---|---|
| Depth `z` | Known exactly | Measurable via **pressure** (cheap or waterproof sensor) |
| Attitude | Known exactly | MPU6050 (IMU) — usable with calibration |
| Horizontal `x,y` | Known exactly | **No GPS.** This is the main unsolved problem |

Underwater GNSS does not work. Without a DVL (Doppler velocity log, expensive) or acoustic positioning, the vehicle must rely on **dead reckoning**: integrate speed / thrust / IMU over time. Drift grows. So the real autonomy bottleneck is **“where am I in the horizontal plane?”**, not depth hold.

Practical near-term approach: calibrate open-loop / dead-reckoning runs in a pool, accept limited accuracy, then optionally add ranging (sonar) or later a DVL if budget allows.

---

## Depth sensing (cheap vs proper)

Depth control on the real vehicle uses **water pressure → depth**. Two options:

### Option A — Cheap / DIY (balloon + external tube)

- Keep a **cheap pressure sensor** (e.g. MPS20N0040D + HX710) **inside** the dry hull.
- Route a thin **tube / pipe to the outside**, ending in a small **air balloon / bladder** exposed to water pressure (or an open water column that compresses the air).
- Outside water pressure compresses the air; the internal sensor reads that pressure → estimate depth → **closed-loop depth / pitch control**.

This is a **low-cost, simple** student solution. Care needed for leaks, air leaks in the tube, temperature, and calibration. Fine for pool depths; not a survey-grade sensor.

### Option B — Direct underwater pressure sensor

- Buy a **waterproof / submersible pressure (depth) sensor** rated for the target depth.
- Mount it with a sealed penetrator; read depth more directly and robustly.
- Better reliability and less plumbing; higher cost than Option A.

**Either way, depth closed-loop is achievable.** Horizontal navigation without GPS remains the harder open problem (see above).

Current bench wiring in this project assumes the cheap pressure chain (MPS20 + HX710 on PB12/PB13). A waterproof sensor can replace that chain later with the same “pressure → depth → elevator” control idea.

---

## 1. What is the vehicle?

Target platform: small **single-propeller** AUV with **two servos** (rudder + elevator).

| Feature | Description |
|---|---|
| Propulsion | A2212 ~930 KV + ESC 30A (bidirectional) |
| Yaw / pitch | 2× MG996R (PB4 / PB5) |
| Depth | Pressure → depth (DIY balloon/tube **or** underwater pressure sensor) |
| Attitude | MPU6050 |
| Leak | Leak / rain AO |
| Brain | STM32F411 BlackPill |
| Power | 3S LiPo → fuse → ESC + UBEC 5V (servos) |
| Bench | CP2102 UART, ST-Link SWD |

---

## 2. Electronics (summary)

STM32F411, ST-Link, CP2102, MPU6050, pressure chain (cheap MPS20 or later waterproof), leak, 2× servo, motor, ESC, UBEC, 3S LiPo, XT60, fuse, 470 µF / 100 nF / resistors, stripboard.

ESC BEC 5V is **not connected**. Servos use **UBEC 5V**.

Pin summary (current bench): ESC PB0 · servo PB4/PB5 · I2C PB6/PB7 · pressure PB12/PB13 · leak PA5 · UART PA9/PA10.

---

## 3. STM32 (WIP)

```
stm32/
  bench/       <- 01_blink ... 17_goto_222
  embedded/    <- CubeMX + App + Src + generated
```

Maturity: bench + bringup **medium**; closed-loop path follow in water **early**.  
Next hardware steps: reliable depth from pressure, then attitude hold, then limited dead-reckoning missions — remembering that **no GPS** limits horizontal accuracy.

Details: [stm32/README.md](stm32/README.md)

---

## 4. Repository map

```
AUVsim-main/
|-- README.md
|-- setup_auv_path.m
|-- matlab/
|   |-- core/                 <- main simulation (path following works here)
|   |-- tests/
|   |-- path_plot/
|   |-- codegen/
|   |-- experiments/
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

Student prototype. Propeller-off bench tests; observe LiPo safety. Seal and pressure plumbing carefully before any water test.
