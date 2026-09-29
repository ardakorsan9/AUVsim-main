# STM32 — WIP (about halfway; still evolving)

> Not finished flight software. Bench + embedded skeleton.

## Folders

| Folder | What |
|---|---|
| **`bench/`** | Arduino-cli sketches `01`…`17` — part-by-part hardware tests |
| **`embedded/`** | Main STM32F411 project: CubeMX, App bringup, safety, PWM mapper, MATLAB codegen |

## Maturity

- Bench: sensors / servo / ESC exercised  
- Embedded: disarm + PWM neutral + host tests  
- Closed-loop autonomy (in water): **not yet** → next work  

Details: [`../docs/STM32_DEVELOPMENT_STATUS.md`](../docs/STM32_DEVELOPMENT_STATUS.md)

## Development order

1. `bench/17_goto_222` sensor health  
2. Lock `embedded/cubemx` pins to the bench  
3. Move sensors into `embedded` bringup  
4. Feed safety + PWM mapper with real commands  
5. Pool depth hold → then combined mission  
