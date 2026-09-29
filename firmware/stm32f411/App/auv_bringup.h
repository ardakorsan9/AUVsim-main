#ifndef AUV_BRINGUP_H
#define AUV_BRINGUP_H

#include <stdint.h>
#include <stdbool.h>

#ifdef __cplusplus
extern "C" {
#endif

#define AUV_PWM_FREQUENCY_HZ      50
#define AUV_RUDDER_NEUTRAL_US     1500
#define AUV_ELEVATOR_NEUTRAL_US   1500
#define AUV_ESC_IDLE_US           1500
#define AUV_SCHEDULER_PERIOD_MS   25
#define AUV_BOOT_DISARMED         1

typedef struct {
  bool armed;
  uint16_t rudder_us;
  uint16_t elevator_us;
  uint16_t esc_us;
} auv_bringup_state_t;

void auv_bringup_init(void);
void auv_bringup_apply_neutral(void);
void auv_bringup_systick_1ms(void);
void auv_bringup_scheduler_tick(void);
const auv_bringup_state_t *auv_bringup_state(void);

#ifdef __cplusplus
}
#endif

#endif /* AUV_BRINGUP_H */
