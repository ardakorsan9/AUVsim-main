# STM32 development status (public summary)

This note states how mature the STM code in this repo is, and that it is shared as **mid-development / WIP**.

## Short answer

STM side is about **40–50%**: bench and skeleton exist; closed-loop path following in water does not.

MATLAB simulation **does** closed-loop path tracking. Hardware must still close the loops with real sensors.

## Sensing reality check

| Need | Status / plan |
|---|---|
| **Depth** | Doable with pressure. Cheap DIY: internal sensor + tube + external balloon/bladder; or buy a waterproof depth sensor. Then depth / elevator closed loop. |
| **Attitude** | MPU6050 on the bench; needs stable calibration for control. |
| **Horizontal x,y** | **Main hard problem.** No GPS underwater. Dead reckoning drifts; DVL / acoustics are expensive. This — not depth — is the core navigation challenge. |

## Level table

| Level | Description | Folder |
|---|---|---|
| L0 Simulation | MATLAB path following + PID | `matlab/` |
| L1 Bench | Sensors/actuators one at a time | `stm32/bench/` |
| L2 Bringup | Disarm, PWM neutral | `stm32/embedded/App` |
| L3 Safety + mapper | FSM, PWM map | `stm32/embedded/Src` |
| L4 Sensor closed loop | IMU + pressure → control | **Not yet** |
| L5 Mission / path follow in water | Dive–go–surface (limited by no GPS) | **Not yet** |

Share point: **L1–L3 (WIP)** · tag `v0.3-wip-stm32`

## Contributing

- New bench sketch → `stm32/bench/NN_name/`  
- Embedded feature → `stm32/embedded/` + host test  
- Checklist: [stm32/README.md](../stm32/README.md)
