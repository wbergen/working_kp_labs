/* kernel task */

#include <inc/x86.h>
#include <inc/lib.h>

/*
1. runs in the kernel context
2. Checks global task list for run ct > 0 on current cpu
3. Calls tasklet's function if greater than 0
 - Tasklet interal counter incremented on run.. (or in thread?)
 - At completion return


*/


void umain(int argc, char **argv)
{
    binaryname = "ktask";

    while(1){
	    cprintf("t_list: %x\n", t_list);
	    cprintf("ktask printing...\n");
    	// Get task info

    	// Call task func

    	// Mark task as T_DONW

    	// Call sched
	    sys_yield();
    }

    // // }
    // if(tf->tf_cs == GD_KT){
    //     cprintf("ktask running in kernel mode!");
    // } else {
    //     cprintf("ktask not running kernel mode!");
    // }




}

