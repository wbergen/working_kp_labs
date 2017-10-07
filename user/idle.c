/* idle loop */

#include <inc/x86.h>
#include <inc/lib.h>
//#include <kern/spinlock.h>

int ncpu = 0;
int only_program(){
	int i, count = 0;
	if(thisenv->env_cpunum > ncpu){
		ncpu = thisenv->env_cpunum;
	}
	for(i = 0; i < NENV; i++){
		if(envs[i].env_status == ENV_RUNNABLE || envs[i].env_status == ENV_RUNNING){
			count++;
		}
	}
	//cprintf("count = %d/%d\n",count, ncpu);
	if(count <= ncpu){
		return 1;
	}else{
		return 0;
	}
}
void umain(int argc, char **argv)
{
	//extern const int * ncpus;

    binaryname = "idle";

    /* Loop forever, simply trying to yield to a different environment.
     * Instead of busy-waiting like this, a better way would be to use the
     * processor's HLT instruction to cause the processor to stop executing
     * until the next interrupt - doing so allows the processor to conserve
     * power more effectively. */
    while (1) {
    	if(only_program()){
    		cprintf(" No user programs running, killing the Idle process %d\n", thisenv->env_id);
    		sys_env_destroy(thisenv->env_id);
    	}
       sys_yield();
    }
}

