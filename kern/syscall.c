/* See COPYRIGHT for copyright information. */

#include <inc/x86.h>
#include <inc/error.h>
#include <inc/string.h>
#include <inc/assert.h>

#include <kern/env.h>
#include <kern/pmap.h>
#include <kern/trap.h>
#include <kern/syscall.h>
#include <kern/console.h>
#include <kern/sched.h>

#include <kern/spinlock.h>

#include <kern/vma.h>
#include <kern/pmap.h>
/*
 * Print a string to the system console.
 * The string is exactly 'len' characters long.
 * Destroys the environment on memory errors.
 */
static void sys_cputs(const char *s, size_t len)
{
    // cprintf("[KERN] sys_cputs(): called\n");
    // cprintf("[KERN] sys_cputs(): s: %s - len: %u\n", s, len);

    /* Check that the user has permission to read memory [s, s+len).
     * Destroy the environment if not. */

    /* LAB 3: Your code here. */
    // void user_mem_assert(struct env *env, const void *va, size_t len, int perm)
    // Ensure the memory access is user accessible:

    user_mem_assert(curenv, s, len, PTE_U);

    /* Print the string supplied by the user. */
    cprintf("%.*s", len, s);
}

/*
 * Read a character from the system console without blocking.
 * Returns the character, or 0 if there is no input waiting.
 */
static int sys_cgetc(void)
{
    DBB(cprintf("[KERN] sys_cgetc(): called\n"));
    lock_console();
    int ret = cons_getc();
    unlock_console();
    return ret;
}

/* Returns the current environment's envid. */
static envid_t sys_getenvid(void)
{
    DBB(cprintf("[KERN] sys_getenvid(): called\n"));
    lock_env();
    envid_t ret = curenv->env_id;
    unlock_env();
    return ret;
}

/*
 * Destroy a given environment (possibly the currently running environment).
 *
 * Returns 0 on success, < 0 on error.  Errors are:
 *  -E_BAD_ENV if environment envid doesn't currently exist,
 *      or the caller doesn't have permission to change envid.
 */
static int sys_env_destroy(envid_t envid)
{
    DBB(cprintf("[KERN] sys_env_destroy(): called on %08x\n", envid));
    int r;
    struct env *e;
    lock_env();
    if ((r = envid2env(envid, &e, 1)) < 0){
        unlock_env();
        return r;
    }
    if (e == curenv){
        DBB(cprintf("[%08x] exiting gracefully\n", curenv->env_id));
    }
    else{
        DBB(cprintf("[%08x] destroying %08x\n", curenv->env_id, e->env_id));
    }
    env_destroy(e);
    unlock_env();
    return 0;
}


void * vma_find_spot(uint32_t size, int * vma_at_zero, uint32_t * total_area){

    void * spot = (void *)-1;

    // Bookkeeping:
    struct vma * temp = curenv->alloc_vma_list;
    uint32_t last_size = temp->len;
    void * last_addr = temp->va;
    uint32_t gap = 0;

    // Check for space under first element:
    if ((uint32_t)temp->va > size) {
        DBB(cprintf("[KERN] sys_vma_create(): spot should be: %08x\n", 0x0));
        spot = (void *)0x0;
        *vma_at_zero = 1;

    } else {

        // No space before first element, iterate:
        while (temp){

            // Sum vma area already allocated:
            *total_area = *total_area + temp->len;
            
            // Handle last element case outside of loop
            if (!temp->vma_link){
                break;
            }

            temp = temp->vma_link;
            gap = (uint32_t)(temp->va - last_addr + last_size);

            if (gap > size) {

                // Checking before acutally allowing an allocation for vm overrun works but...
                if ((uint32_t)(spot + size) > (UTOP - 0x00800000 - *total_area)) {
                    DBB(cprintf("[KERN] sy]s_vma_create(): Not enough mem to accomodate vma!\n"));
                    return (void *)-1;
                }

                DBB(cprintf("[KERN] spot should be: %08x\n",  (void *)(last_addr + last_size)));
                spot = (void *)(last_addr + last_size);
                // spot = ROUNDUP(last_addr + last_size, PGSIZE);
                break;
            }

            last_size = temp->len;
            last_addr = temp->va;

        }
    }

    // Handle case where no gap is found:
    if (spot == 0 && !vma_at_zero){
        DBB(cprintf("[KERN] sys_vma_create(): no gap found, checking remaining space...\n"));

        // Set spot to beginning of remaining space:
        spot = (void *)(last_addr + last_size);

        // Ensure we have enough remaining memory to accomodate create:
        if ((uint32_t)(spot + size) > (UTOP - 0x00800000 - *total_area)) {
            DBB(cprintf("[KERN] sys_vma_create(): Not enough mem to accomodate vma!\n"));
            return (void *)-1;
        }
    }

    return spot;
}

/*
 * Creates a new anonymous mapping somewhere in the virtual address space.
 *
 * Supported flags: 
 *     MAP_POPULATE
 * 
 * Returns the address to the start of the new mapping, on success,
 * or -1 if request could not be satisfied.
 */
static void *sys_vma_create(uint32_t size, int perm, int flags)
{
    lock_env();
    DBB(cprintf("[KERN] sys_vma_create(): called w/ size ==  %u, perm == %u, flags == %u\n", size, perm, flags));

   /* Virtual Memory Area allocation */

   /* LAB 4: Your code here. */

    /* Find a spot to create the new  */

    // Va to map vma at:
    void * spot = (void *)0;

    // Bookkeeping:
    int vma_at_zero = 0;
    uint32_t total_area = 0;

    // MAP_HUGEPAGES support - ensure the size is a multiple of 4mb:
    if (flags & 0x2){ // MAP_HUGEPAGES
        if (size % (PGSIZE * 1024) != 0){
            // Size is NOT 4mb aligned:
            DBB(cprintf("[KERN] sys_vma_create(): MAP_HUGEPAGES, but size is not 4mb aligned!\n"));
            unlock_env();
            return (void *)-1;
        }
    }

    // Try to find a spot in the vma area where we can fit our new alloc at, or return if one can't be found
    spot = vma_find_spot(size, &vma_at_zero, &total_area);
    if (spot < 0){
        unlock_env();
        return (void *)-1;
    }

    DBB(cprintf("===== spot: %x ======\n", spot));

    /* Now we have spot, allocate! */
    // Create a new vma:
    struct vma * new;
    if (vma_new(curenv, spot, size, VMA_ANON, NULL, 0, 0, perm | PTE_U, &new) < 1) {
        DBB(cprintf("[KERN] sys_vma_create(): failed to create the vma!\n"));
        unlock_env();
        return (void *)-1;
    }

    // MAP_POPULATE support - allocate pages now:
    if (flags & 0x1 && !(flags & 0x2)) { // MAP_POPULATE
        lock_pagealloc();
        DBB(cprintf("[KERN] sys_vma_create(): MAP_POPULATE %x\n",curenv));
        if(!vma_populate(spot, size, perm, 0)){
            unlock_pagealloc();
            unlock_env();
            return (void *)-1;
        }
        unlock_pagealloc();
    } else if (flags & 0x1 & 0x2){ // MAP_POPULATE + MAP_HUGEPAGES
        DBB(cprintf("[KERN] sys_vma_create(): MAP_POPULATE + MAP_HUGEPAGES %x\n",curenv));
        lock_pagealloc();
        if(!vma_populate(spot, size, perm, 1)){
            unlock_pagealloc();
            unlock_env();
            return (void *)-1;
        }
        unlock_pagealloc();
        new->hps = 1;
    } else if (flags & 0x2) { // MAP_HUGEPAGES
        DBB(cprintf("[KERN] sys_vma_create(): MAP_HUGEPAGES %x\n",curenv));
        new->hps = 1;
    }

    DBB(cprintf("[KERN] sys_vma_create(): VMAs after create:\n"));
    print_all_vmas(curenv);
    unlock_env();
   return spot;
}

/*
 * Unmaps the specified range of memory starting at 
 * virtual address 'va', 'size' bytes long.
 */
static int sys_vma_destroy(void *va, uint32_t size)
{
   /* Virtual Memory Area deallocation */
    lock_env();
    DBB(cprintf("[KERN] sys_vma_destroy(): va ==  0x%08x, size == %u\n", va, size));

    struct vma * v = vma_lookup(curenv, va);
    if (v->hps){
        if (v->len != size || v->va != va){
            // huge problem
            DBB(cprintf("[KERN] sys_vma_destroy(): vma marked as huge, but destroy params don't span whole area!\n"));
            unlock_env();
            return -1;
        }
    }

    /*
    The sys_vma_destroy(void *va, size_t size) system call will unmap (part of) a VMA.
    
    Note that this must not only remove the VMA, but also the pages that might have already been mapped
     in (i.e., present in the page table and reserved in physical memory). This system call can be used on
     subregions of a VMA, and might lead to VMA splitting. For example, one could create a single VMA of
     3 pages using sys_vma_create, and then free the middle page. This would shrink the original VMA to
     only the first page, and create a new VMA for the last page. You do not need to support unmapping of
     ranges spanning multiple VMAs, or unmapping binary VMAs.

    */

    // Find the vma covering the range:
    // struct vma * vma_lookup(struct env *e, void *va);
    // gonna call split on 
    // print_all_vmas(curenv);

    if(vma_split_lookup(curenv, va, size, 1) == NULL){
        DBB(cprintf("[KERN]sys_vma_destroy: failed\n"));
        unlock_env();
        return -1;
    }
    // cprintf("[KERN] sys_vma_destroy(): vma found w/ va %x\n", vmad->va);
    DBB(cprintf("[KERN] sys_vma_destroy(): VMAs after destory:\n"));
    print_all_vmas(curenv);
    unlock_env();
   /* LAB 4: Your code here. */
   return 0;
}

/*
 * Deschedule current environment and pick a different one to run.
 */
static void sys_yield(void)
{
    DBB(cprintf("[KERN] sys_yield() called!\n"));
    //if the a process invoke sys yield tamper it's time slice to schedule another process
    //lock_env();
    invalidate_env_ts(curenv);
    lock_env();
    sched_yield();
}

static int sys_wait(envid_t envid)
{
    /* LAB 5: Your code here */
    DBB(cprintf("[KERN]sys_wait() called\n"));
    struct env *e;

    lock_env();
    // Look up the env
    envid2env(envid, &e, 0);

    if(!e){
        DBB(cprintf("[KERN]sys_wait(): no env with that id!\n"));
        unlock_env();
        return -1;
    }

    curenv->wait_id = envid;
    curenv->env_status = ENV_SLEEPING;
    
    sched_yield();
    return 0;
}

static int sys_fork(void)
{
    /* fork() that follows COW semantics */
    /* LAB 5: Your code here */
    lock_env();
    int32_t child_id = env_dup(curenv);
    if(!child_id){
        DBB(cprintf("sys_fork(): fork failed\n"));
        unlock_env();
        return -1;
    }
    else return child_id;
}   

/*
    returns 1 for success and 0 for failure
*/
static int sys_vma_protect(void *va, size_t size, int perm){

    lock_env();
    struct vma * v = vma_lookup(curenv, va);

    // if the vma doesn't exit return
    if(!v){
        DBB(cprintf("[KERN]sys_vma_protect: vma not found\n"));
        unlock_env();
        return 0;
    }
    //if the permission are the same nothing to do, return
    if(v->perm == perm){
        unlock_env();
        return 1;
    }

    //split the vma
    v = vma_split_lookup(curenv, va, size, 0);

    //return in case of split failure
    if(!v){
        DBB(cprintf("[KERN]sys_vma_protect: vma split failure\n"));
        unlock_env();        
        return 0;
    }
    //change the vma permission
    if(!vma_change_perm(v, perm)){
        DBB(cprintf("[KERN]sys_vma_protect: vma change perm failure\n"));
        unlock_env();
        return 0;
    }

    //merge vma if required
    if(vma_list_merge(curenv) != 0){
        DBB(cprintf("[KERN]sys_vma_protect: vma merge failure\n"));
        unlock_env();
        return 0;
    }
    unlock_env();
    return 1;
}
/*
    This function advise the kernel to execute ONE of the following operations:
        -MADV_DONTNEED:
            free the allocated pages in a vma
        -MADV_WILLNEED:
            populate the allocated pages in a vma

    it returns 1 if success, 0 if any errors occur
    cprintf("\n");
*/
int32_t sys_vma_advise(void *va, size_t size, int attr){

    lock_env();
    struct vma * v = vma_lookup(curenv, va);

    //check if the va is mapped in the vma
    if(!v){
        DBB(cprintf("[KERN] sys_vma_advise: vma lookup failed\n"));
        return 0;
    }

    //check if the va and size specified are correct
    if(!vma_size_check(va,size,v)){
        DBB(cprintf("[KERN] sys_vma_advise: va + size spans multiple vmas\n"));
        unlock_env();
        return 0;
    }

    //if MADV_DONTNEED remove the allocated pages
    if(attr == MADV_DONTNEED){
        if (!v->hps){
            lock_pagealloc();
            vma_remove_pages(curenv, va, size);
            unlock_pagealloc();
        }
    }
    //if MADV_WILLNEED populate the pages
    if (attr == MADV_WILLNEED){
        lock_pagealloc();
        vma_populate(va, size, v->perm, v->hps);
        unlock_pagealloc();
    }

    unlock_env();
    return 1;
}
/* Dispatches to the correct kernel function, passing the arguments. */
int32_t syscall(uint32_t syscallno, uint32_t a1, uint32_t a2, uint32_t a3,
        uint32_t a4, uint32_t a5)
{
    /*
     * Call the function corresponding to the 'syscallno' parameter.
     * Return any appropriate return value.
     * LAB 3: Your code here.
     */

    envid_t i;
    // Syscalls dispatch
    switch (syscallno) {
        case SYS_cputs:
            sys_cputs((char *)a1, a2);
            return 0;
        case SYS_cgetc:
            return sys_cgetc();
        case SYS_getenvid:
            return sys_getenvid();
        case SYS_env_destroy:
            return sys_env_destroy((envid_t) a1);
        case SYS_vma_create:
            return (int32_t)sys_vma_create(a1, a2, a3);
        case SYS_vma_destroy:
            return (int32_t)sys_vma_destroy((void*)a1, a2);
        case SYS_vma_protect:
            return sys_vma_protect((void *)a1, a2, a3);
        case SYS_vma_advise:
            return sys_vma_advise((void *)a1, a2, a3);
        case SYS_fork:
            i = sys_fork();
            return i;
        case SYS_yield:
            sys_yield();
        case SYS_wait:
            return sys_wait(a1);
    default:
        return -E_NO_SYS;
    }
}

