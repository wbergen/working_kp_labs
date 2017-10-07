/* kernel task */

#include <inc/x86.h>
#include <inc/lib.h>
// //#include <kern/spinlock.h>


// int only_program(){
// 	int i, count = 0;

// 	for(i = 0; i < NENV; i++){
// 		if((envs[i].env_status == ENV_RUNNABLE || envs[i].env_status == ENV_RUNNING)
//          && envs[i].env_type != ENV_TYPE_IDLE){
// 			count++;
// 		}
// 	}
// 	if(count < 1){
// 		return 1;
// 	}else{
// 		return 0;
// 	}
// }
void umain(int argc, char **argv)
{
	//extern const int * ncpus;

    binaryname = "ktask";

    /* Loop forever, simply trying to yield to a different environment.
     * Instead of busy-waiting like this, a better way would be to use the
     * processor's HLT instruction to cause the processor to stop executing
     * until the next interrupt - doing so allows the processor to conserve
     * power more effectively. */
    // while (1) {

    // 	if(only_program()){
    // 		cprintf(" No user programs running, killing the Idle process [%x]\n", thisenv->env_id);
    // 		sys_env_destroy(thisenv->env_id);
    // 	}
    //    sys_yield();
    // }
    cprintf("ktask printing...\n");
}

