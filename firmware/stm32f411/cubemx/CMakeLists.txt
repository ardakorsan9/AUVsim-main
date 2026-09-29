# STM32F411CEUx AUV skeleton (WeAct Black Pill V3.1 locked pins)
cmake_minimum_required(VERSION 3.22)
set(CMAKE_SYSTEM_NAME Generic)
set(CMAKE_SYSTEM_PROCESSOR arm)

project(auv_f411 C CXX ASM)

set(CMAKE_C_STANDARD 11)
set(CMAKE_C_STANDARD_REQUIRED ON)
set(CMAKE_CXX_STANDARD 11)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

add_executable(auv_f411
  Core/Src/main.c
  Core/Src/gpio.c
  Core/Src/tim.c
  Core/Src/usart.c
  Core/Src/stm32f4xx_it.c
  Core/Src/system_stm32f4xx.c
  Core/Src/syscalls.c
  Core/Src/sysmem.c
  startup_stm32f411ceux.s
  Drivers/STM32F4xx_HAL_Driver/Src/stm32f4xx_hal.c
  Drivers/STM32F4xx_HAL_Driver/Src/stm32f4xx_hal_cortex.c
  Drivers/STM32F4xx_HAL_Driver/Src/stm32f4xx_hal_rcc.c
  Drivers/STM32F4xx_HAL_Driver/Src/stm32f4xx_hal_rcc_ex.c
  Drivers/STM32F4xx_HAL_Driver/Src/stm32f4xx_hal_flash.c
  Drivers/STM32F4xx_HAL_Driver/Src/stm32f4xx_hal_flash_ex.c
  Drivers/STM32F4xx_HAL_Driver/Src/stm32f4xx_hal_gpio.c
  Drivers/STM32F4xx_HAL_Driver/Src/stm32f4xx_hal_pwr.c
  Drivers/STM32F4xx_HAL_Driver/Src/stm32f4xx_hal_pwr_ex.c
  Drivers/STM32F4xx_HAL_Driver/Src/stm32f4xx_hal_tim.c
  Drivers/STM32F4xx_HAL_Driver/Src/stm32f4xx_hal_tim_ex.c
  Drivers/STM32F4xx_HAL_Driver/Src/stm32f4xx_hal_uart.c
  Drivers/STM32F4xx_HAL_Driver/Src/stm32f4xx_hal_dma.c
  ../App/auv_bringup.c
  ../Src/auv_tick_mailbox.cpp
  ../Src/auv_runtime_port.cpp
  ../Src/auv_runtime_adapter.cpp
  ../Src/auv_safety_fsm.cpp
  ../Src/auv_watchdog_policy.cpp
  ../Src/auv_pwm_mapper.cpp
  ../Src/auv_telemetry.cpp
  ../generated/runtime/combined/auv_runtime_codegen_init.cpp
  ../generated/runtime/combined/rt_nonfinite.cpp
  ../generated/runtime/combined/rtGetInf.cpp
  ../generated/runtime/combined/rtGetNaN.cpp
)

target_include_directories(auv_f411 PRIVATE
  Core/Inc
  Drivers/STM32F4xx_HAL_Driver/Inc
  Drivers/STM32F4xx_HAL_Driver/Inc/Legacy
  Drivers/CMSIS/Device/ST/STM32F4xx/Include
  Drivers/CMSIS/Include
  ../App
  ../Inc
  ../generated/runtime/combined
)

target_compile_definitions(auv_f411 PRIVATE
  USE_HAL_DRIVER
  STM32F411xE
  HSE_VALUE=25000000U
)

target_compile_options(auv_f411 PRIVATE
  -Wall
  -Wextra
  -ffunction-sections
  -fdata-sections
  -fno-common
)

target_link_options(auv_f411 PRIVATE
  -T${CMAKE_CURRENT_SOURCE_DIR}/STM32F411CEUx_FLASH.ld
  -Wl,--gc-sections
  -Wl,-Map=$<TARGET_FILE_DIR:auv_f411>/auv_f411.map
  -specs=nano.specs
  -specs=nosys.specs
)

set_target_properties(auv_f411 PROPERTIES
  OUTPUT_NAME auv_f411
  SUFFIX .elf
)

add_custom_command(TARGET auv_f411 POST_BUILD
  COMMAND ${CMAKE_SIZE} $<TARGET_FILE:auv_f411>
  COMMENT "Firmware size"
)
