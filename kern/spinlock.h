#ifndef JOS_INC_SPINLOCK_H
#define JOS_INC_SPINLOCK_H

#include <inc/types.h>
#include <inc/assert.h>
#include <kern/cpu.h>

/* Comment this to disable spinlock debugging */
//#define DEBUG_SPINLOCK
#define DEBUG_SPINLOCK_1
/* Disable big kernel lock
 *
 * LAB 6: Comment out the following macro definition
 *        when you are ready to move to fine-grained locking.
 */
// #define USE_BIG_KERNEL_LOCK 1

/* Mutual exclusion lock. */
struct spinlock {
    unsigned locked;       /* Is the lock held? */




#ifdef DEBUG_SPINLOCK_1
    /* For debugging: */
    char *name;            /* Name of lock. */
    struct cpuinfo *cpu;   /* The CPU holding the lock. */
    uintptr_t pcs[10];     /* The call stack (an array of program counters) */
                           /* that locked the lock. */
#endif
};

void __spin_initlock(struct spinlock *lk, char *name);
void spin_lock(struct spinlock *lk);
void spin_unlock(struct spinlock *lk);
int holding_l(struct spinlock *lock);

#define spin_initlock(lock)   __spin_initlock(lock, #lock)

#ifdef USE_BIG_KERNEL_LOCK

extern struct spinlock kernel_lock;

static inline void lock_kernel(void)
{
    spin_lock(&kernel_lock);
}

static inline void unlock_kernel(void)
{
    spin_unlock(&kernel_lock);

    /*
     * Normally we wouldn't need to do this, but QEMU only runs one CPU at a
     * time and has a long time-slice.  Without the pause, this CPU is likely to
     * reacquire the lock before another CPU has even been given a chance to
     * acquire it.
     */
    asm volatile("pause");
}

static inline void lock_pagealloc(void) { }
static inline void unlock_pagealloc(void) { }
static inline void lock_env(void) { }
static inline void unlock_env(void) { }
static inline void lock_console(void) { }
static inline void unlock_console(void) { }
static inline void lock_task(void) { }
static inline void unlock_task(void) { }

static inline void assert_lock_env(void) { }
static inline void assert_lock_pagealloc(void) { }
static inline int lock_env_holding(void) { return 0; }
static inline int lock_pagealloc_holding(void) { return 0; }
static inline int lock_kernel_holding(void) { return holding_l(&kernel_lock); }
#else /* USE_BIG_KERNEL_LOCK */

extern struct spinlock pagealloc_lock;
extern struct spinlock env_lock;
extern struct spinlock console_lock;
extern struct spinlock task_lock;

static inline void lock_pagealloc(void) { spin_lock(&pagealloc_lock); }
static inline void unlock_pagealloc(void) { spin_unlock(&pagealloc_lock); asm volatile("pause"); }
static inline void lock_env(void) { spin_lock(&env_lock); }
static inline void unlock_env(void) { spin_unlock(&env_lock); asm volatile("pause"); }
static inline void lock_console(void) { spin_lock(&console_lock); }
static inline void unlock_console(void) { spin_unlock(&console_lock); asm volatile("pause"); }
static inline void lock_task(void) { spin_lock(&task_lock); }
static inline void unlock_task(void) { spin_unlock(&task_lock); asm volatile("pause"); }
static inline int lock_env_holding(void) { return holding_l(&env_lock); }
static inline int lock_pagealloc_holding(void) { return holding_l(&pagealloc_lock); }
static inline void lock_kernel(void) { }
static inline void unlock_kernel(void) { }
static inline int lock_kernel_holding(void) { return 0; }
#ifdef DEBUG_SPINLOCK_1
static __always_inline void assert_lock_env(void)
{
    assert(env_lock.locked && env_lock.cpu == thiscpu);
}
static __always_inline void assert_lock_pagealloc(void)
{
    assert(pagealloc_lock.locked && pagealloc_lock.cpu == thiscpu);
}
#else /* DEBUG_SPINLOCK */
static inline void assert_lock_env(void) { }
static inline void assert_lock_pagealloc(void) { }
#endif
#endif /* USE_BIG_KERNEL_LOCK */

#endif

//extern const int *ncpus;