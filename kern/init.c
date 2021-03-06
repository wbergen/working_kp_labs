/* See COPYRIGHT for copyright information. */

#include <inc/stdio.h>
#include <inc/string.h>
#include <inc/assert.h>

#include <kern/monitor.h>
#include <kern/console.h>
#include <kern/pmap.h>
#include <kern/kclock.h>
#include <kern/env.h>
#include <kern/trap.h>
#include <kern/sched.h>
#include <kern/picirq.h>
#include <kern/cpu.h>
#include <kern/spinlock.h>
#include <kern/ide.h>

static void boot_aps(void);

//#define BUSY_WAIT

void i386_init(void)
{
    extern char edata[], end[];
    int i;
    /* Before doing anything else, complete the ELF loading process.
     * Clear the uninitialized global data (BSS) section of our program.
     * This ensures that all static/global variables start out zero. */
    memset(edata, 0, end - edata);

    /* Initialize the console.
     * Can't call cprintf until after we do this! */
    cons_init();

    /* Lab 1 and 2 memory management initialization functions. */
    mem_init();

    /* Lab 3 user environment initialization functions. */
    env_init();
    trap_init();

    /* Lab 5 and 6 multiprocessor initialization functions */
    mp_init();
    lapic_init();

    /* Lab 5 multitasking initialization functions */
    pic_init();

    ide_init();

    /* Acquire the big kernel lock before waking up APs.
     * LAB 6: Your code here: */
    lock_kernel();
    lock_env();
    #ifdef DEBUG_SPINLOCK
        cprintf("-----------------------------------[cpu:%d][LOCK][ENV]\n",cpunum());
    #endif
    /* Starting non-boot CPUs */
    boot_aps();

    DBB(cprintf("[%d] CPUS:  %d \n", cpunum(), ncpu));
    lock_pagealloc();
    #ifdef DEBUG_SPINLOCK
        cprintf("-----------------------------------[cpu:%d][LOCK][PAGE]\n",cpunum());
    #endif
    
    //create Kernel task threds
    for (i=0; i < NKTHREADS; i++){
        kenv_create(ktask, ENV_TYPE_KERNEL);
    }


#if defined(TEST)
    /* Don't touch -- used by grading script! */
    ENV_CREATE(TEST, ENV_TYPE_USER);
#else
    /* Touch all you want. */
    ENV_CREATE(user_yield, ENV_TYPE_USER);

#endif
    //create ncpu - 1 idle processes
    #ifdef BUSY_WAIT
    for (i=0; i < (ncpu - 1); i++){
        ENV_CREATE(user_idle, ENV_TYPE_IDLE);
    }
    #endif

    #ifdef DEBUG_SPINLOCK
        cprintf("-----------------------------------[cpu:%d][UNLOCK][PAGE]\n",cpunum());
    #endif
    unlock_pagealloc();

    /* Schedule and run the first user environment! */
    sched_yield();
}

/*
 * While boot_aps is booting a given CPU, it communicates the per-core
 * stack pointer that should be loaded by mpentry.S to that CPU in
 * this variable.
 */
void *mpentry_kstack;

/*
 * Start the non-boot (AP) processors.
 */
static void boot_aps(void)
{
    extern unsigned char mpentry_start[], mpentry_end[];
    void *code;
    struct cpuinfo *c;

    /* Write entry code to unused memory at MPENTRY_PADDR */
    code = KADDR(MPENTRY_PADDR);
    memmove(code, mpentry_start, mpentry_end - mpentry_start);

    /* Boot each AP one at a time */
    for (c = cpus; c < cpus + ncpu; c++) {
        if (c == cpus + cpunum())  /* We've started already. */
            continue;

        /* Tell mpentry.S what stack to use */
        mpentry_kstack = percpu_kstacks[c - cpus] + KSTKSIZE;
        /* Start the CPU at mpentry_start */
        lapic_startap(c->cpu_id, PADDR(code));
        /* Wait for the CPU to finish some basic setup in mp_main() */
        while(c->cpu_status != CPU_STARTED)
            ;
    }
}

/*
 * Setup code for APs.
 */
void mp_main(void)
{
    /* We are in high EIP now, safe to switch to kern_pgdir */
    lcr3(PADDR(kern_pgdir));
    DBB(cprintf("SMP: CPU %d starting\n", cpunum()));

    lapic_init();
    env_init_percpu();
    trap_init_percpu();
    xchg(&thiscpu->cpu_status, CPU_STARTED); /* tell boot_aps() we're up */
    /*
     * Now that we have finished some basic setup, call sched_yield()
     * to start running processes on this CPU.  But make sure that
     * only one CPU can enter the scheduler at a time!
     *
     * LAB 6: Your code here:
     */
    lock_kernel();
    lock_env();
    #ifdef DEBUG_SPINLOCK
        cprintf("-----------------------------------[cpu:%d][LOCK][ENV]\n",cpunum());
    #endif
    sched_yield();
    /* Remove this after you initialize per-CPU trap information */
}

/*
 * Variable panicstr contains argument to first call to panic; used as flag
 * to indicate that the kernel has already called panic.
 */
const char *panicstr;

/*
 * Panic is called on unresolvable fatal errors.
 * It prints "panic: mesg", and then enters the kernel monitor.
 */
void _panic(const char *file, int line, const char *fmt,...)
{
    va_list ap;

    if (panicstr)
        goto dead;
    panicstr = fmt;

    /* Be extra sure that the machine is in as reasonable state */
    __asm __volatile("cli; cld");

    va_start(ap, fmt);
    cprintf("kernel panic on CPU %d at %s:%d: ", cpunum(), file, line);
    vcprintf(fmt, ap);
    cprintf("\n");
    va_end(ap);

dead:
    /* break into the kernel monitor */
    while (1)
        monitor(NULL);
}

/* Like panic, but don't. */
void _warn(const char *file, int line, const char *fmt,...)
{
    va_list ap;

    va_start(ap, fmt);
    cprintf("kernel warning at %s:%d: ", file, line);
    vcprintf(fmt, ap);
    cprintf("\n");
    va_end(ap);
}
