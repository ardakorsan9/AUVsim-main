#ifndef AUV_TELEMETRY_H
#define AUV_TELEMETRY_H

/*
 * Heap-free fixed-layout status telemetry encoder (little-endian).
 * Heap-free encoder; explicit byte writes only; no UART driver calls.
 * PRETARGET DEPLOY_CANDIDATE / NOT_IN_PRODUCTION / NOT_CERTIFIED
 */

#include "auv_safety_fsm.h"

#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

#define AUV_TELEMETRY_SYNC_BYTE0 0xA5U
#define AUV_TELEMETRY_SYNC_BYTE1 0x55U
#define AUV_TELEMETRY_VERSION 1U
#define AUV_TELEMETRY_STATUS_PAYLOAD_LENGTH 13U
#define AUV_TELEMETRY_STATUS_FRAME_BYTES 20U

#define AUV_TELEM_HEALTH_SAMPLE_VALID 0x01U
#define AUV_TELEM_HEALTH_RUNTIME_VALID 0x02U
#define AUV_TELEM_HEALTH_CONFIG_VALID 0x04U
#define AUV_TELEM_HEALTH_CRITICAL_FAULT 0x08U
#define AUV_TELEM_HEALTH_PWM_PUBLISH 0x10U
#define AUV_TELEM_HEALTH_RUDDER_CLAMPED 0x20U
#define AUV_TELEM_HEALTH_ELEVATOR_CLAMPED 0x40U
#define AUV_TELEM_HEALTH_THRUST_CLAMPED 0x80U

#define AUV_TELEM_TICK_SCHEDULER_OVERRUN 0x01U
#define AUV_TELEM_TICK_MAILBOX_OVERRUN 0x02U

typedef struct {
  uint32_t sequence;
  AuvSafetyState safety_state;
  bool sample_valid;
  bool runtime_valid;
  bool config_valid;
  bool critical_fault;
  bool pwm_publish;
  bool rudder_clamped;
  bool elevator_clamped;
  bool thrust_clamped;
  bool scheduler_overrun;
  bool mailbox_overrun;
  uint16_t rudder_us;
  uint16_t elevator_us;
  uint16_t thrust_us;
} AuvTelemetryStatusInput;

size_t auv_telemetry_encode_status(const AuvTelemetryStatusInput *input,
                                   uint8_t *buffer,
                                   size_t buffer_len);

#ifdef __cplusplus
}
#endif

#endif
