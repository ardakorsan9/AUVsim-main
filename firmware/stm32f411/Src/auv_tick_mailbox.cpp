/*
 * One-slot 40 Hz sequence mailbox with PRIMASK consumer and overrun latch.
 * PRETARGET DEPLOY_CANDIDATE / LOGICAL COMMANDS ONLY / NOT_IN_PRODUCTION / NOT_CERTIFIED
 * TASK_ID: STM32_RUNTIME_PORT_001
 *
 * ISR:  auv_tick_mailbox_isr_post — 40 Hz ISR producer; no PRIMASK, no I/O.
 * Main: auv_tick_mailbox_consume — PRIMASK critical section; clears slot.
 */

#include "auv_tick_mailbox.h"

#if defined(__ARM_ARCH) || defined(__ARM_ARCH_7EM__) || defined(__ARM_ARCH_7M__) || defined(STM32F411xx)
#define AUV_TICK_MAILBOX_HAS_PRIMASK 1
#else
#define AUV_TICK_MAILBOX_HAS_PRIMASK 0
#endif

namespace {

struct Mailbox {
    volatile uint32_t seq;
    volatile uint8_t pending;
    volatile uint8_t overrun;
};

Mailbox s_mbox;

uint32_t __get_PRIMASK(void)
{
#if AUV_TICK_MAILBOX_HAS_PRIMASK
    uint32_t primask;
    __asm volatile("mrs %0, primask" : "=r"(primask) :: "memory");
    return primask;
#else
    __asm volatile("" ::: "memory");
    return 0u;
#endif
}

void __set_PRIMASK(uint32_t primask)
{
#if AUV_TICK_MAILBOX_HAS_PRIMASK
    __asm volatile("msr primask, %0" :: "r"(primask) : "memory");
#else
    (void)primask;
    __asm volatile("" ::: "memory");
#endif
}

uint32_t primask_save_disable(void)
{
    const uint32_t primask = __get_PRIMASK();
    __set_PRIMASK(1u);
    return primask;
}

void primask_restore(uint32_t primask)
{
    __set_PRIMASK(primask);
}

}  // namespace

void auv_tick_mailbox_init(void)
{
    const uint32_t primask = primask_save_disable();
    s_mbox.seq = 0u;
    s_mbox.pending = 0u;
    s_mbox.overrun = 0u;
    primask_restore(primask);
}

void auv_tick_mailbox_isr_post(uint32_t seq)
{
    if (s_mbox.pending != 0u) {
        s_mbox.overrun = 1u;
    }
    s_mbox.seq = seq;
    __asm volatile("" ::: "memory");
    s_mbox.pending = 1u;
}

bool auv_tick_mailbox_consume(uint32_t *seq_out, bool *overrun_out)
{
    if (seq_out == 0) {
        return false;
    }

    const uint32_t primask = primask_save_disable();
    bool had = false;
    if (s_mbox.pending != 0u) {
        *seq_out = s_mbox.seq;
        const bool overrun = (s_mbox.overrun != 0u);
        if (overrun_out != 0) {
            *overrun_out = overrun;
        }
        s_mbox.pending = 0u;
        s_mbox.overrun = 0u;
        had = true;
    } else {
        *seq_out = 0u;
        if (overrun_out != 0) {
            *overrun_out = (s_mbox.overrun != 0u);
        }
    }
    primask_restore(primask);
    return had;
}
