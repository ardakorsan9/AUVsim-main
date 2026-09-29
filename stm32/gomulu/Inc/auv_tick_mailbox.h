#ifndef AUV_TICK_MAILBOX_H
#define AUV_TICK_MAILBOX_H

/*
 * One-slot 40 Hz tick mailbox (period 0.025 s).
 * PRETARGET DEPLOY_CANDIDATE / LOGICAL COMMANDS ONLY / NOT_IN_PRODUCTION / NOT_CERTIFIED
 * TASK_ID: STM32_RUNTIME_PORT_001
 *
 * ISR use:  auv_tick_mailbox_isr_post() from the 40 Hz timer ISR only.
 *           Holds one sequence. If the slot is still pending, latches overrun
 *           and overwrites the sequence. Never call from main/thread.
 * Main use: auv_tick_mailbox_consume() from main/thread only. Saves PRIMASK,
 *           copies the sequence, clears pending and the overrun latch, then
 *           restores PRIMASK. Never call from ISR.
 */

#include <stdbool.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

enum { AUV_TICK_MAILBOX_HZ = 40 };

void auv_tick_mailbox_init(void);
void auv_tick_mailbox_isr_post(uint32_t seq);
bool auv_tick_mailbox_consume(uint32_t *seq_out, bool *overrun_out);

#ifdef __cplusplus
}
#endif

#endif
