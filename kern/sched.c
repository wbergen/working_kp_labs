#include <inc/assert.h>
#include <inc/x86.h>
#include <kern/spinlock.h>
#include <kern/env.h>
#include <kern/pmap.h>
#include <kern/monitor.h>

void sched_halt(void);

/*
 * Choose a user environment to run and run it.
 */
void sched_yield(void)
{
    struct env *idle;

    cprintf("[SCHED] sched_yield() called!\n");

    /*
     * Implement simple round-robin scheduling.
     *
     * Search through 'envs' for an ENV_RUNNABLE environment in
     * circular fashion starting just after the env this CPU was
     * last running.  Switch to the first such environment found.
     *
     * If no envs are runnable, but the environment previously
     * running on this CPU is still ENV_RUNNING, it's okay to
     * choose that environment.
     *
     * Never choose an environment that's currently running (on
     * another CPU, if we had, ie., env_status == ENV_RUNNING). 
     * If there are
     * no runnable environments, simply drop through to the code
     * below to halt the cpu.
     *
     * LAB 5: Your code here.
     */

    /*
    - Get current env
    - From current env in envs[], itterate over whole list looking for next w/ env_status == ENV_RUNNABLE
    - Run found env, or fall through to halt below
    */

    /*
    enum {
        ENV_FREE = 0,
        ENV_DYING,
        ENV_RUNNABLE,
        ENV_RUNNING,
        ENV_NOT_RUNNABLE
    };

    - From that index + 1, iterate over array looking for ENV_RUNNABLE
    - If found, run it
    - If end of list, reset i to begnining of list (to cover cur > next case)
    - If we iterate back to our current env, and its ENV_RUNNING, run it
    */

    // DEBUG:
    int j = 0;
    cprintf("\nENVS:\n");
    for (j; j < NENV; ++j)
    {
        if (envs[j].env_status != ENV_FREE){
            cprintf("[0x%08x] (id: %08x status: %d)\n", &envs[j], envs[j].env_id, envs[j].env_status);
        }
    }
    cprintf("\n");

    // Enviorment indexes:
    int i, last_idx;

    // At first call, curenv hasn't been setup
    if (curenv) {
        cprintf("[SCHED] curenv id: %08x\n", curenv->env_id);
        // Set next:
        i = (int)curenv->env_id - 0x1000 + 1;  // Convert id to index + 1
    } else {
        cprintf("[SCHED] first scheduling, setting env next index to 1.\n");
        i = 1;
    }
    
    // Save current index:
    last_idx = i - 1;


    for (i; i <= NENV; ++i)
    {
        // Debug:
        // cprintf("envs[%u]: %08x -- [status: %u]\n", i, envs[i].env_id, envs[i].env_status);

        // If end of list found, set i to beginning:
        if (i == (NENV)){
            i = 0;
        }

        // If runnable, run the new one:
        if (envs[i].env_status == ENV_RUNNABLE){
            cprintf("[SCHED] found a RUNNABLE env switching from %08x -> %08x\n", envs[last_idx].env_id, envs[i].env_id);
            // last = envs[i].env_id;
            env_run(&envs[i]);
        }

        // If current env found, and it's ENV_RUNNING, choose it, else drop to mon:
        if (envs[i].env_id == envs[last_idx].env_id) {
            cprintf("[SCHED] no others found, running current...\n");
            if (envs[i].env_status == ENV_RUNNING){
                // last = envs[i].env_id;
                cprintf("asdfasdf");
                env_run(&envs[i]);
            } else {
                break;
            }
        }
    }

    /* sched_halt never returns */
    sched_halt();
}

/*
 * Halt this CPU when there is nothing to do. Wait until the timer interrupt
 * wakes it up. This function never returns.
 */
void sched_halt(void)
{
    int i;

    /* For debugging and testing purposes, if there are no runnable
     * environments in the system, then drop into the kernel monitor. */
    for (i = 0; i < NENV; i++) {
        if ((envs[i].env_status == ENV_RUNNABLE ||
             envs[i].env_status == ENV_RUNNING ||
             envs[i].env_status == ENV_DYING))
            break;
    }
    if (i == NENV) {
        cprintf("No runnable environments in the system!\n");
        while (1)
            monitor(NULL);
    }

    /* Mark that no environment is running on this CPU */
    curenv = NULL;
    lcr3(PADDR(kern_pgdir));

    /* Mark that this CPU is in the HALT state, so that when
     * timer interupts come in, we know we should re-acquire the
     * big kernel lock */
    xchg(&thiscpu->cpu_status, CPU_HALTED);

    /* Release the big kernel lock as if we were "leaving" the kernel */
    unlock_kernel();

    /* Reset stack pointer, enable interrupts and then halt. */
    asm volatile (
        "movl $0, %%ebp\n"
        "movl %0, %%esp\n"
        "pushl $0\n"
        "pushl $0\n"
        "sti\n"
        "hlt\n"
    : : "a" (thiscpu->cpu_ts.ts_esp0));
}

