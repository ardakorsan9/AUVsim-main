/**
 * @file auv_bringup.c
 * @brief STM32F411 locked-pin bring-up: 50 Hz PWM neutrals + 25 ms scheduler.
 */
#include "auv_bringup.h"

#include "auv_tick_mailbox.h"
#include "main.h"
#include "tim.h"

extern TIM_HandleTypeDef htim3;

static auv_bringup_state_t g_state;
static uint8_t g_systick_div;
static uint32_t g_mailbox_seq;

static uint16_t auv_us_to_compare(uint16_t pulse_us)
{
  /* Timer timebase is 1 MHz (1 tick = 1 us) for AUV_PWM_FREQUENCY_HZ PWM. */
  (void)AUV_PWM_FREQUENCY_HZ;
  return pulse_us;
}

void auv_bringup_apply_neutral(void)
{
  g_state.rudder_us = (uint16_t)AUV_RUDDER_NEUTRAL_US;
  g_state.elevator_us = (uint16_t)AUV_ELEVATOR_NEUTRAL_US;
  g_state.esc_us = (uint16_t)AUV_ESC_IDLE_US;

  __HAL_TIM_SET_COMPARE(&htim3, TIM_CHANNEL_1, auv_us_to_compare(g_state.rudder_us));
  __HAL_TIM_SET_COMPARE(&htim3, TIM_CHANNEL_2, auv_us_to_compare(g_state.elevator_us));
  __HAL_TIM_SET_COMPARE(&htim3, TIM_CHANNEL_3, auv_us_to_compare(g_state.esc_us));
}

void auv_bringup_init(void)
{
#if AUV_BOOT_DISARMED
  g_state.armed = false;
#else
  g_state.armed = true;
#endif
  g_systick_div = 0U;
  g_mailbox_seq = 0U;
  auv_tick_mailbox_init();

  auv_bringup_apply_neutral();

  (void)HAL_TIM_PWM_Start(&htim3, TIM_CHANNEL_1);
  (void)HAL_TIM_PWM_Start(&htim3, TIM_CHANNEL_2);
  (void)HAL_TIM_PWM_Start(&htim3, TIM_CHANNEL_3);
}

void auv_bringup_systick_1ms(void)
{
  g_systick_div++;
  if (g_systick_div < (uint8_t)AUV_SCHEDULER_PERIOD_MS) {
    return;
  }
  g_systick_div = 0U;
  g_mailbox_seq++;
  auv_tick_mailbox_isr_post(g_mailbox_seq);
}

void auv_bringup_scheduler_tick(void)
{
  uint32_t seq;
  bool overrun;

  (void)seq;
  if (!auv_tick_mailbox_consume(&seq, &overrun)) {
    return;
  }

  if (overrun) {
    g_state.armed = false;
    auv_bringup_apply_neutral();
  }

  /* Keep outputs at neutral while disarmed. */
  if (!g_state.armed) {
    auv_bringup_apply_neutral();
  }

  HAL_GPIO_TogglePin(LED_GPIO_Port, LED_Pin);
}

const auv_bringup_state_t *auv_bringup_state(void)
{
  return &g_state;
}
