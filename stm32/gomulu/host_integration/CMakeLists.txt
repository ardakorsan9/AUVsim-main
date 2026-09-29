cmake_minimum_required(VERSION 3.16)
project(auv_host_e2e_chain CXX C)

set(CMAKE_CXX_STANDARD 11)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

set(FW_ROOT ${CMAKE_CURRENT_SOURCE_DIR}/..)
get_filename_component(AUV_PROJECT_ROOT "${CMAKE_CURRENT_SOURCE_DIR}/../../.." ABSOLUTE)
set(CODEGEN_ROOT ${FW_ROOT}/generated/runtime/combined)

add_executable(auv_host_e2e_chain
  test_host_e2e_chain.cpp
  ${FW_ROOT}/Src/auv_runtime_port.cpp
  ${FW_ROOT}/Src/auv_runtime_adapter.cpp
  ${FW_ROOT}/Src/auv_safety_fsm.cpp
  ${FW_ROOT}/Src/auv_pwm_mapper.cpp
  ${FW_ROOT}/Src/auv_telemetry.cpp
  ${FW_ROOT}/Src/auv_watchdog_policy.cpp
  ${CODEGEN_ROOT}/auv_runtime_codegen_init.cpp
  ${CODEGEN_ROOT}/rt_nonfinite.cpp
  ${CODEGEN_ROOT}/rtGetInf.cpp
  ${CODEGEN_ROOT}/rtGetNaN.cpp
)

target_include_directories(auv_host_e2e_chain PRIVATE
  ${FW_ROOT}/Inc
  ${CODEGEN_ROOT}
)

target_compile_definitions(auv_host_e2e_chain PRIVATE
  AUV_SCHEDULER_PERIOD_MS=25
  AUV_PROJECT_ROOT="${AUV_PROJECT_ROOT}"
)

target_compile_options(auv_host_e2e_chain PRIVATE
  -Wall
  -Wextra
  -Werror
)

set_source_files_properties(
  ${CODEGEN_ROOT}/auv_runtime_codegen_init.cpp
  PROPERTIES COMPILE_OPTIONS "-Wno-error=maybe-uninitialized"
)

add_custom_target(check
  COMMAND auv_host_e2e_chain
  DEPENDS auv_host_e2e_chain
  COMMENT "Running host e2e chain integration test"
)
