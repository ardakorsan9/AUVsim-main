/*
 * Guarded one-slot AUV runtime port. Fail-closed. No heap. No I/O.
 * PRETARGET DEPLOY_CANDIDATE / LOGICAL COMMANDS ONLY / NOT_IN_PRODUCTION / NOT_CERTIFIED
 * TASK_ID: STM32_RUNTIME_PORT_ABI_REPAIR_001
 */

#include "auv_runtime_port.h"

#include "auv_runtime_codegen_init.h"

#include <string.h>

namespace {

struct0_T s_config;
struct5_T s_params;
struct9_T s_state;
bool s_initialized;

void zero_output(AuvRuntimeOut *out)
{
    if (out == 0) {
        return;
    }
    memset(out, 0, sizeof(*out));
}

}  // namespace

void auv_runtime_port_initialize(const AuvRuntimeConfig *cfg)
{
    if (cfg == 0) {
        s_initialized = false;
        return;
    }
    memcpy(&s_config, cfg, sizeof(s_config));
    auv_runtime_codegen_init_initialize();
    auv_runtime_codegen_init(&s_config, &s_params);
    auv_runtime_codegen_reset(&s_params, &s_state);
    s_initialized = true;
}

void auv_runtime_port_reset(void)
{
    if (!s_initialized) {
        return;
    }
    auv_runtime_codegen_reset(&s_params, &s_state);
}

bool auv_runtime_port_publish_allowed(const AuvRuntimeOut *out)
{
    if (out == 0) {
        return false;
    }
    if (!out->command_valid) {
        return false;
    }
    if (out->physical_io_written) {
        return false;
    }
    if (out->actuator_isolated) {
        return false;
    }
    if (out->abort_requested) {
        return false;
    }
    return true;
}

bool auv_runtime_port_step(const AuvRuntimeIn *in, AuvRuntimeOut *out)
{
    if (out == 0) {
        return false;
    }
    if ((!s_initialized) || (in == 0)) {
        zero_output(out);
        return false;
    }
    auv_runtime_codegen_step(&s_params, &s_state, in, out);
    if (!auv_runtime_port_publish_allowed(out)) {
        return false;
    }
    return true;
}
