/*
 * Fixed versioned status telemetry encoder.
 * PRETARGET DEPLOY_CANDIDATE / NOT_IN_PRODUCTION / NOT_CERTIFIED
 */

#include "auv_telemetry.h"

namespace {

constexpr size_t kOffsetSync0 = 0U;
constexpr size_t kOffsetSync1 = 1U;
constexpr size_t kOffsetVersion = 2U;
constexpr size_t kOffsetPayloadLength = 3U;
constexpr size_t kOffsetSequence = 5U;
constexpr size_t kOffsetSafetyState = 9U;
constexpr size_t kOffsetHealthFault = 10U;
constexpr size_t kOffsetTickOverrun = 11U;
constexpr size_t kOffsetRudderUs = 12U;
constexpr size_t kOffsetElevatorUs = 14U;
constexpr size_t kOffsetThrustUs = 16U;
constexpr size_t kOffsetCrc = 18U;

constexpr uint16_t kCrc16Init = 0xFFFFU;
constexpr uint16_t kCrc16Poly = 0x1021U;

void write_u16_le(uint8_t *buffer, size_t offset, uint16_t value)
{
  buffer[offset] = static_cast<uint8_t>(value & 0xFFU);
  buffer[offset + 1U] = static_cast<uint8_t>((value >> 8U) & 0xFFU);
}

void write_u32_le(uint8_t *buffer, size_t offset, uint32_t value)
{
  buffer[offset] = static_cast<uint8_t>(value & 0xFFU);
  buffer[offset + 1U] = static_cast<uint8_t>((value >> 8U) & 0xFFU);
  buffer[offset + 2U] = static_cast<uint8_t>((value >> 16U) & 0xFFU);
  buffer[offset + 3U] = static_cast<uint8_t>((value >> 24U) & 0xFFU);
}

uint16_t crc16_ccitt(const uint8_t *data, size_t length)
{
  uint16_t crc = kCrc16Init;

  for (size_t index = 0U; index < length; ++index) {
    crc ^= static_cast<uint16_t>(static_cast<uint16_t>(data[index]) << 8U);
    for (uint8_t bit = 0U; bit < 8U; ++bit) {
      if ((crc & 0x8000U) != 0U) {
        crc = static_cast<uint16_t>((crc << 1U) ^ kCrc16Poly);
      } else {
        crc = static_cast<uint16_t>(crc << 1U);
      }
    }
  }

  return crc;
}

uint8_t pack_health_fault_bits(const AuvTelemetryStatusInput *input)
{
  uint8_t bits = 0U;

  if (input->sample_valid) {
    bits |= AUV_TELEM_HEALTH_SAMPLE_VALID;
  }
  if (input->runtime_valid) {
    bits |= AUV_TELEM_HEALTH_RUNTIME_VALID;
  }
  if (input->config_valid) {
    bits |= AUV_TELEM_HEALTH_CONFIG_VALID;
  }
  if (input->critical_fault) {
    bits |= AUV_TELEM_HEALTH_CRITICAL_FAULT;
  }
  if (input->pwm_publish) {
    bits |= AUV_TELEM_HEALTH_PWM_PUBLISH;
  }
  if (input->rudder_clamped) {
    bits |= AUV_TELEM_HEALTH_RUDDER_CLAMPED;
  }
  if (input->elevator_clamped) {
    bits |= AUV_TELEM_HEALTH_ELEVATOR_CLAMPED;
  }
  if (input->thrust_clamped) {
    bits |= AUV_TELEM_HEALTH_THRUST_CLAMPED;
  }

  return bits;
}

uint8_t pack_tick_overrun_flags(const AuvTelemetryStatusInput *input)
{
  uint8_t flags = 0U;

  if (input->scheduler_overrun) {
    flags |= AUV_TELEM_TICK_SCHEDULER_OVERRUN;
  }
  if (input->mailbox_overrun) {
    flags |= AUV_TELEM_TICK_MAILBOX_OVERRUN;
  }

  return flags;
}

uint8_t encode_safety_state(AuvSafetyState state)
{
  switch (state) {
    case AUV_SAFETY_STATE_ARMED:
      return static_cast<uint8_t>(AUV_SAFETY_STATE_ARMED);
    case AUV_SAFETY_STATE_KILLED:
      return static_cast<uint8_t>(AUV_SAFETY_STATE_KILLED);
    case AUV_SAFETY_STATE_DISARMED:
    default:
      return static_cast<uint8_t>(AUV_SAFETY_STATE_DISARMED);
  }
}

}  // namespace

extern "C" size_t auv_telemetry_encode_status(const AuvTelemetryStatusInput *input,
                                              uint8_t *buffer,
                                              size_t buffer_len)
{
  if (input == 0 || buffer == 0 ||
      buffer_len < static_cast<size_t>(AUV_TELEMETRY_STATUS_FRAME_BYTES)) {
    return 0U;
  }

  buffer[kOffsetSync0] = AUV_TELEMETRY_SYNC_BYTE0;
  buffer[kOffsetSync1] = AUV_TELEMETRY_SYNC_BYTE1;
  buffer[kOffsetVersion] = AUV_TELEMETRY_VERSION;
  write_u16_le(buffer, kOffsetPayloadLength, AUV_TELEMETRY_STATUS_PAYLOAD_LENGTH);
  write_u32_le(buffer, kOffsetSequence, input->sequence);
  buffer[kOffsetSafetyState] = encode_safety_state(input->safety_state);
  buffer[kOffsetHealthFault] = pack_health_fault_bits(input);
  buffer[kOffsetTickOverrun] = pack_tick_overrun_flags(input);
  write_u16_le(buffer, kOffsetRudderUs, input->rudder_us);
  write_u16_le(buffer, kOffsetElevatorUs, input->elevator_us);
  write_u16_le(buffer, kOffsetThrustUs, input->thrust_us);

  const uint16_t crc =
      crc16_ccitt(buffer, static_cast<size_t>(AUV_TELEMETRY_STATUS_FRAME_BYTES) - 2U);
  write_u16_le(buffer, kOffsetCrc, crc);

  return static_cast<size_t>(AUV_TELEMETRY_STATUS_FRAME_BYTES);
}
