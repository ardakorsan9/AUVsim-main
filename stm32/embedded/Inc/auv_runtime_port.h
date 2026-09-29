#ifndef AUV_RUNTIME_PORT_H
#define AUV_RUNTIME_PORT_H

/*
 * Target ABI port for generated AUV runtime (STM32F411CEU6 pretarget).
 * PRETARGET DEPLOY_CANDIDATE / LOGICAL COMMANDS ONLY / NOT_IN_PRODUCTION / NOT_CERTIFIED
 * TASK_ID: STM32_RUNTIME_PORT_ABI_REPAIR_001
 *
 * Exact generated C++ ABI via auv_runtime_codegen_init_types.h.
 * Calls generated init_initialize/init/reset/step. Owns config, params,
 * and supervisor state in the translation unit. No heap, no physical I/O,
 * no GPIO/PWM/CAN/UART.
 * Null or uninitialized: zero output and deny publish.
 * Publish iff command_valid and physical_io_written, actuator_isolated,
 * and abort_requested are all false.
 */

#include "auv_runtime_codegen_init_types.h"

#include <stdbool.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct0_T AuvRuntimeConfig;
typedef struct15_T AuvRuntimeIn;
typedef struct17_T AuvRuntimeOut;

void auv_runtime_port_initialize(const AuvRuntimeConfig *cfg);
void auv_runtime_port_reset(void);
bool auv_runtime_port_step(const AuvRuntimeIn *in, AuvRuntimeOut *out);
bool auv_runtime_port_publish_allowed(const AuvRuntimeOut *out);

#ifdef __cplusplus
}
#endif

#endif
