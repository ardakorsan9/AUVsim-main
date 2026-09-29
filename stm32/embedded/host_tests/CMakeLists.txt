cmake_minimum_required(VERSION 3.16)
project(auv_pure_logic_tests CXX C)

set(CMAKE_CXX_STANDARD 11)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

set(AUV_HOST_ENABLE_SANITIZERS "OFF" CACHE STRING
    "Enable AddressSanitizer and UndefinedBehaviorSanitizer (OFF, AUTO, ON)")
set_property(CACHE AUV_HOST_ENABLE_SANITIZERS PROPERTY STRINGS OFF AUTO ON)

if(NOT AUV_HOST_ENABLE_SANITIZERS MATCHES "^(OFF|AUTO|ON)$")
  message(FATAL_ERROR
    "AUV_HOST_ENABLE_SANITIZERS must be OFF, AUTO, or ON (got \"${AUV_HOST_ENABLE_SANITIZERS}\")")
endif()

set(FW_ROOT ${CMAKE_CURRENT_SOURCE_DIR}/..)

add_executable(auv_pure_logic_tests
  test_pure_logic.cpp
  ${FW_ROOT}/Src/auv_safety_fsm.cpp
  ${FW_ROOT}/Src/auv_pwm_mapper.cpp
  ${FW_ROOT}/Src/auv_telemetry.cpp
  ${FW_ROOT}/Src/auv_watchdog_policy.cpp
)

target_include_directories(auv_pure_logic_tests PRIVATE
  ${FW_ROOT}/Inc
  ${FW_ROOT}/generated/runtime/combined
)

target_compile_options(auv_pure_logic_tests PRIVATE
  -Wall
  -Wextra
  -Werror
)

if(NOT AUV_HOST_ENABLE_SANITIZERS STREQUAL "OFF")
  set(_auv_sanitizer_compile_flags
    -fsanitize=address
    -fsanitize=undefined
    -fno-omit-frame-pointer
  )
  set(_auv_sanitizer_link_flags
    -fsanitize=address
    -fsanitize=undefined
  )

  get_filename_component(_auv_cxx_bindir "${CMAKE_CXX_COMPILER}" DIRECTORY)
  get_filename_component(_auv_toolchain_root "${_auv_cxx_bindir}" DIRECTORY)
  file(GLOB_RECURSE _auv_asan_libs
    "${_auv_toolchain_root}/libasan.a"
    "${_auv_toolchain_root}/libasan.dll.a"
    "${_auv_toolchain_root}/libubsan.a"
    "${_auv_toolchain_root}/libubsan.dll.a"
  )

  set(_auv_sanitizer_link_dirs "")
  foreach(_auv_lib IN LISTS _auv_asan_libs)
    get_filename_component(_auv_lib_dir "${_auv_lib}" DIRECTORY)
    list(APPEND _auv_sanitizer_link_dirs "${_auv_lib_dir}")
  endforeach()
  if(_auv_sanitizer_link_dirs)
    list(REMOVE_DUPLICATES _auv_sanitizer_link_dirs)
  endif()

  include(CheckCXXSourceCompiles)
  set(CMAKE_REQUIRED_FLAGS ${_auv_sanitizer_compile_flags})
  set(CMAKE_REQUIRED_LINK_OPTIONS ${_auv_sanitizer_link_flags})
  if(_auv_sanitizer_link_dirs)
    set(CMAKE_REQUIRED_LINK_DIRECTORIES ${_auv_sanitizer_link_dirs})
  endif()

  set(_auv_sanitizer_probe_source [[
#if !defined(__SANITIZE_ADDRESS__) || !defined(__SANITIZE_UNDEFINED__)
#error sanitizer flags accepted but ASan/UBSan not active
#endif
int main() { return 0; }
]])

  check_cxx_source_compiles(
    "${_auv_sanitizer_probe_source}"
    AUV_HOST_SANITIZERS_SUPPORTED
  )
  unset(CMAKE_REQUIRED_FLAGS)
  unset(CMAKE_REQUIRED_LINK_OPTIONS)
  unset(CMAKE_REQUIRED_LINK_DIRECTORIES)

  if(AUV_HOST_SANITIZERS_SUPPORTED)
    target_compile_options(auv_pure_logic_tests PRIVATE ${_auv_sanitizer_compile_flags})
    target_link_options(auv_pure_logic_tests PRIVATE ${_auv_sanitizer_link_flags})
    if(_auv_sanitizer_link_dirs)
      target_link_directories(auv_pure_logic_tests PRIVATE ${_auv_sanitizer_link_dirs})
    endif()
    target_compile_definitions(auv_pure_logic_tests PRIVATE AUV_HOST_SANITIZERS_ENABLED=1)
    message(STATUS
      "AUV_HOST_ENABLE_SANITIZERS=${AUV_HOST_ENABLE_SANITIZERS}: ASan/UBSan enabled")
  elseif(AUV_HOST_ENABLE_SANITIZERS STREQUAL "ON")
    message(FATAL_ERROR
      "AUV_HOST_ENABLE_SANITIZERS=ON but toolchain rejected ASan/UBSan (missing runtime libraries or unsupported flags)")
  else()
    message(STATUS
      "AUV_HOST_ENABLE_SANITIZERS=AUTO: ASan/UBSan unavailable (missing runtime libraries or unsupported flags); continuing without sanitizers")
  endif()
endif()

add_custom_target(check
  COMMAND auv_pure_logic_tests
  DEPENDS auv_pure_logic_tests
  COMMENT "Running pure logic unit tests"
)
