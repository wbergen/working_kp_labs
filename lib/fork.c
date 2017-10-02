/* implement fork from user space */

#include <inc/string.h>
#include <inc/lib.h>

envid_t fork(void)
{
    /* LAB 5: Your code here. */
    envid_t i = sys_fork();
    if (i == 0){
    	thisenv = &envs[ENVX(sys_getenvid())];
    }
    cprintf("env: %x forked -> %x\n", thisenv->env_id, i);
    return i;
}
