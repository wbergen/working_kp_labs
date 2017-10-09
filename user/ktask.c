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

    // // }
    // if(tf->tf_cs == GD_KT){
    //     cprintf("ktask running in kernel mode!");
    // } else {
    //     cprintf("ktask not running kernel mode!");
    // }





    cprintf("ktask printing...\n");
    sys_yield();
}

