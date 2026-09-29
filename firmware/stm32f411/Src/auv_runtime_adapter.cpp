/*
 * Pure fail-closed runtime output -> logical command adapter.
 * PRETARGET DEPLOY_CANDIDATE / LOGICAL COMMANDS ONLY / NOT_IN_PRODUCTION / NOT_CERTIFIED
 */

#include "auv_runtime_adapter.h"

#include <cmath>

namespace {

bool all_finite(double delta_r, double delta_e, double thrust)
{
  return std::isfinite(delta_r) && std::isfinite(delta_e) && std::isfinite(thrust);
}

}  // namespace

void auv_runtime_adapter_zero(AuvRuntimeLogicalCmd *cmd)
{
  if (cmd == 0) {
    return;
  }
  cmd->delta_r = 0.0;
  cmd->delta_e = 0.0;
  cmd->thrust = 0.0;
  cmd->valid = false;
}

bool auv_runtime_adapter_update(const AuvRuntimeOut *out, AuvRuntimeLogicalCmd *cmd)
{
  if (cmd == 0) {
    return false;
  }

  auv_runtime_adapter_zero(cmd);

  if (out == 0) {
    return false;
  }
  if (!out->command_valid) {
    return false;
  }
  if (!out->ready) {
    return false;
  }
  if (!auv_runtime_port_publish_allowed(out)) {
    return false;
  }
  if (!all_finite(out->delta_r, out->delta_e, out->thrust)) {
    return false;
  }

  cmd->delta_r = out->delta_r;
  cmd->delta_e = out->delta_e;
  cmd->thrust = out->thrust;
  cmd->valid = true;
  return true;
}
