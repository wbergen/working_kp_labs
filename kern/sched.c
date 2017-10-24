#include <inc/assert.h>
#include <inc/x86.h>
#include <kern/spinlock.h>
#include <kern/env.h>
#include <kern/pmap.h>
#include <kern/monitor.h>
#include <kern/mm_pres.h>

int SCHED_DEBUG = 0;
uint64_t lru_check = LRU_DEFAULT;

void sched_halt(void);

/*
    This function invalidate the time slide of a process
*/

void invalidate_env_ts( struct env * e){
    e->time_slice = TS_DEFAULT *2;
}
/*
    This function calculates the delta to subtract to a env time slice
*/
uint64_t calulate_delta(uint64_t tick, uint64_t last_tick){

        if(tick > last_tick){
            return (tick - last_tick);
        }else{
            return (tick + ((uint64_t)0 - last_tick));
        }

}
/*
    this function checks if a process has the right to run again

    returns 1 in case it can, 0 otherwise
*/
int check_time_slice(){

        if( curenv->env_status == ENV_RUNNING && curenv->time_slice < TS_DEFAULT){            
            DBS(cprintf("[SCHED] positive time slice %u, reschedule process\n",curenv->time_slice));
            return 1;
        }else{
            DBS(cprintf("[SCHED] negative time slice, reschedule  new process\n"));
            return 0;
        }
}

/* 
    It looks for a runnable env

    returns the index of the env or -1 if no env can be runned
*/
int runnable_env_lookup(int i){

    if( i < NKTHREADS){
        i = NKTHREADS;
    }
    // Save current index:
    int last_idx = i - 1;

    if(last_idx == NKTHREADS - 1){
        last_idx = NENV - 1;
    }

    for (i; i <= NENV; ++i){
        // If end of list found, set i to beginning:
        if (i == NENV){
            i = NKTHREADS;
        }
        // If runnable, run the new one:
        if (envs[i].env_status == ENV_RUNNABLE && envs[i].env_type != ENV_TYPE_KERNEL){
            return i;
        }
        // If current env found, and it's ENV_RUNNING, choose it, else drop to mon:
        if (envs[i].env_id == envs[last_idx].env_id && envs[i].env_type != ENV_TYPE_KERNEL) {
            if (envs[i].env_status == ENV_RUNNING && envs[i].env_cpunum == cpunum()){
                return i;
            } else {
                return -1;
            }
        }
    }
    return -1;
}

int env2id(envid_t id){
    int i;

    for(i=0; i< NENV;i++){
        if(envs[i].env_id == id){
            return i;
        }
    }
    return -1;
}
/*
    This function resumes the work of sleeping processes due to direct reclaim
*/
void resume_env(){

    int i;
    for(i=0; i<NENV; i++){
        if(get_bit(drc_map, i) == 1){
            if(envs[i].env_status == ENV_SLEEPING){
                envs[i].env_status = ENV_RUNNABLE;
            }
            toggle_bit(drc_map, i);
        }
    }

}
/*
  Kernel work:
    - Keep the LRU lists balanced
    - Swap pages if we are in memory pressure
    - Dispatch work to kernel threads
*/

void check_work(){

    assert_lock_env();
    lock_task();
    struct tasklet * t = t_list;
    int i, pgs2swap = 0;
    //if (SCHED_DEBUG)

    DBS(cprintf("[SCHED] CHECK WORK \n"));
    if(lru_check > LRU_DEFAULT ){
        DBK(cprintf("[LRU] Managing lists\n"));
        lru_check = LRU_DEFAULT;
        lru_manager();
    }
    pgs2swap = (SWAP_TRESH - free_pages_count);
    if(pgs2swap > 0){
        DBK(cprintf("[LRU] Memory Pressure! Need to swap %d pages\n", pgs2swap));
        pgs2swap = reclaim_pgs(NULL, pgs2swap);
        DBK(cprintf("[LRU] Memory Pressure! Pages left to swap %d pages\n", pgs2swap));
    }else{
        resume_env();
    }

    while(t){
        if(t->state == T_WORK){
            //if (SCHED_DEBUG)
                DBS(cprintf("[SCHED] WORK FOUND!\n"));
            for(i = 0; i < NKTHREADS; i++){
                //if (SCHED_DEBUG)
                DBS(cprintf("[SCHED] kthreads's status: %u on cpu: %d. curr cpu:%d\n", envs[i].env_status, envs[i].env_cpunum, cpunum()));
                if (envs[i].env_status == ENV_RUNNABLE || (envs[i].env_status == ENV_RUNNING && envs[i].env_cpunum == cpunum())){
                    //if (SCHED_DEBUG)
                    DBS(cprintf("[SCHED] RUNNING KERN THREAD\n"));
                    DBK(print_lru_inactive();
                        print_lru_active();)
                    envs[i].time_slice = TS_DEFAULT*2;
                    unlock_task();
                    env_run(&envs[i]);
                }
            }
            break;
        }
        t = t->t_next;
    }
    unlock_task();
}
/*
 * Choose a user environment to run and run it.
 */
void sched_yield(void)
{
    static uint64_t last_tick;

    DBS(cprintf("[SCHED] sched_yield() called!\n"));

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
        need simple concept of cpu affinity
            - env property cpu, so that ktask is forced to schedule on same core

        if task required by:
            - new tasklet in list with run > 0 (if bookkeeping in tasklet)
            - passed from syscall/kern space on tasklet operations
        save the context of curenv (trap frame)
        ktask calls the function pointed to by the tasklet, a long function
        ktask has the core until the process is completed
            - ktask must be run only on cpu which scheduled (this cpu)
        schedule task
            - prioritize k threads?
        on ktask exit:
            - reset tf to original scheduler
            - run original env
                - w/e operation the process needed has no been completed
        
    */

    int i, last_idx;
    uint64_t tick = read_tsc();
    int e_run, order;
    assert_lock_env();

    // At first call, curenv hasn't been setup
    if (curenv) {
        // Set next:
        i = ENVX(curenv->env_id);  // Convert id to index + 1

        if(i < 0){
            panic("[SCHED] PROBLEM!\n");
        }
        //i = (int)curenv->env_id - ENV_IDX_MIN + 1;  // Convert id to index + 1

        DBS(cprintf("[SCHED] curenv id: %08x, i: %d nenvs %d CPU %d\n", curenv->env_id, i, NENV, cpunum()));
        if(curenv->env_status != ENV_SLEEPING){
            uint64_t delta = calulate_delta(tick, last_tick);
            //Update the current env time slice
            curenv->time_slice -= delta;
            lru_check -= delta;
            //update last tick
            last_tick = tick;

            if(check_time_slice()){
                env_run(curenv);
            }else{
                //If I was the kernel env do not check work, let a user env run
                if(curenv->env_type != ENV_TYPE_KERNEL)
                    check_work();
            }
        }

    } else {
        // No curenv, set iteratior to 1:
        DBS(cprintf("[SCHED] No curenv (first run?), setting env next index to 1.\n"));
        i = NKTHREADS;
        //initialize last tick
        last_tick = read_tsc();
    }

    //keep the last index
    last_idx = i - 1;
    if(last_idx == NKTHREADS - 1){
        last_idx = NENV - 1;
    }
    //look for a runnable env
    e_run = runnable_env_lookup(i);
    if(e_run >= 0){
        DBS(cprintf("[SCHED] found a RUNNABLE env switching from %08x -> %08x\n", envs[last_idx].env_id, envs[e_run].env_id));
        envs[e_run].time_slice = TS_DEFAULT;
        env_run(&envs[e_run]);
    }else{
        sched_halt();
    }
}

/*
 * Halt this CPU when there is nothing to do. Wait until the timer interrupt
 * wakes it up. This function never returns.
 */
void sched_halt(void)
{
    int i;
    assert_lock_env();
    /* For debugging and testing purposes, if there are no runnable
     * environments in the system, then drop into the kernel monitor. */
    for (i = NKTHREADS; i < NENV; i++) {
        if ((envs[i].env_status == ENV_RUNNABLE ||
             envs[i].env_status == ENV_RUNNING ||
             envs[i].env_status == ENV_SLEEPING || 
             envs[i].env_status == ENV_DYING)){
            break;
        }
    }

    if(curenv) DBS(cprintf("[SCHED] No work: halting... cpu %d %x %x\n",cpunum(), t_list, curenv));
    check_work();

    if (i == NENV) {
        DBB(cprintf("No runnable environments in the system!\n"));
        while (1)
            monitor(NULL);
    }

    if(curenv && ENVX(curenv->env_id) < NKTHREADS){
        kenv_cpy_tf(&ktf, &curenv->env_tf);
    }
    if(curenv) curenv->env_status = ENV_RUNNABLE;
    /* Mark that no environment is running on this CPU */
    curenv = NULL;
    lcr3(PADDR(kern_pgdir));

    /* Mark that this CPU is in the HALT state, so that when
     * timer interupts come in, we know we should re-acquire the
     * big kernel lock */

    xchg(&thiscpu->cpu_status, CPU_HALTED);

    /* Release the big kernel lock as if we were "leaving" the kernel */
    #ifdef DEBUG_SPINLOCK
        cprintf("-----------------------------------[cpu:%d][UNLOCK][ENV]\n",cpunum());
    #endif
    unlock_env();

    #ifdef USE_BIG_KERNEL_LOCK
        cprintf("Unlocking kernel halt.........\n");    
    #endif
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


