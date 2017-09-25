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
    cprintf("[KERN] sys_cgetc(): called\n");
    return cons_getc();
}

/* Returns the current environment's envid. */
static envid_t sys_getenvid(void)
{
    cprintf("[KERN] sys_getenvid(): called\n");
    return curenv->env_id;
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
    cprintf("[KERN] sys_env_destroy(): called\n");
    int r;
    struct env *e;

    if ((r = envid2env(envid, &e, 1)) < 0)
        return r;
    if (e == curenv)
        cprintf("[%08x] exiting gracefully\n", curenv->env_id);
    else
        cprintf("[%08x] destroying %08x\n", curenv->env_id, e->env_id);
    env_destroy(e);
    return 0;
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
    cprintf("[KERN] sys_vma_create(): called w/ size ==  %u, perm == %u, flags == %u\n", size, perm, flags);

   /* Virtual Memory Area allocation */

   /* LAB 4: Your code here. */

    //align the size
    //size = ROUNDUP(size,PGSIZE);

    // va to map vma at:
    void * spot = (void *)0;

    // Bookkeeping:
    struct vma * temp = curenv->alloc_vma_list;
    uint32_t last_size = temp->len;
    void * last_addr = temp->va;
    uint32_t gap = 0;
    int vma_at_zero = 0;
    uint32_t total_area = 0;

    // Check for space under first element:
    if ((uint32_t)temp->va > size) {
        cprintf("[KERN] sys_vma_create(): spot should be: %08x\n", 0x0);
        spot = (void *)0x0;
        vma_at_zero = 1;

    } else {

        // No space before first element, iterate:
        while (temp){

            // Sum vma area already allocated:
            total_area = total_area + temp->len;

            // Handle last element case outside of loop
            if (!temp->vma_link){
                break;
            }

            // cprintf("[KERN] vma @ [%08x - %08x]\n", temp->va, temp->va + temp->len);

            temp = temp->vma_link;
            // gap = (uint32_t)temp->va - ROUNDUP(((uint32_t)&last_addr + last_size), PGSIZE);
            gap = (uint32_t)(temp->va - last_addr + last_addr);
            // cprintf("[KERN] gap: %u\n", gap);

            if (gap > size) {

                // Checking before acutally allowing an allocation for vm overrun works but...
                if ((uint32_t)(spot + size) > (UTOP - 0x00800000 - total_area)) {
                    cprintf("[KERN] sy]s_vma_create(): Not enough mem to accomodate vma!\n");
                    return (void *)-1;
                }

                cprintf("[KERN] spot should be: %08x\n",  (void *)(last_addr + last_size));
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
        cprintf("[KERN] sys_vma_create(): no gap found, checking remaining space...\n");

        // Set spot to beginning of remaining space:
        spot = (void *)(last_addr + last_size);
        // uint32_t max = ~0>>1;

        // Ensure we have enough remaining memory to accomodate create:
        if ((uint32_t)(spot + size) > (UTOP - 0x00800000 - total_area)) {
            cprintf("[KERN] sys_vma_create(): Not enough mem to accomodate vma!\n");
            return (void *)-1;
        }
    }

    
    // Debuggin:
    cprintf("[KERN] sys_vma_create(): new vma details: [spot:  %x, gap: %u, size: %u]\n", spot, gap, size);

    // Create a new vma:
    if (vma_new(curenv, spot, size, VMA_ANON, NULL, 0, perm | PTE_U) < 1) {
        cprintf("[KERN] sys_vma_create(): failed to create the vma!\n");
        return (void *)-1;
    }

    // MAP_POPULATE support - allocate pages now:
    if (flags & 0x1) { // MAP_POPULATE
        cprintf("[KERN] sys_vma_create(): MAP_POPULATE %x\n",curenv);
        struct page_info * populate_page = page_alloc(0);

        int i;
        for (i = 0; i < ROUNDUP(size, PGSIZE)/PGSIZE; ++i)
        {
            struct page_info * populate_page = page_alloc(0);
            if (page_insert(curenv->env_pgdir, populate_page, (void *)(spot+i*PGSIZE), perm | PTE_U)){
                
                // Page insert failure:
                cprintf("[KERN] sys_vma_create(): page_insert failed trying to fulfil MAP_POPULATE!\n");
                return (void *)-1;
            }
        }
    }

    cprintf("[KERN] sys_vma_create(): VMAs after create:\n");
    print_all_vmas(curenv);

   return spot;
}

/*
 * Unmaps the specified range of memory starting at 
 * virtual address 'va', 'size' bytes long.
 */
static int sys_vma_destroy(void *va, uint32_t size)
{
   /* Virtual Memory Area deallocation */

    cprintf("[KERN] sys_vma_destroy(): va ==  0x%08x, size == %u\n", va, size);

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

    struct vma * vmad = vma_split_lookup(curenv, va, size);
    // cprintf("[KERN] sys_vma_destroy(): vma found w/ va %x\n", vmad->va);

    cprintf("[KERN] sys_vma_destroy(): VMAs after destory:\n");
    print_all_vmas(curenv);

   /* LAB 4: Your code here. */
   return 0;
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

    // cprintf("syscall number: %x\n", syscallno);

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
            return sys_env_destroy((envid_t) curenv->env_id);
        case SYS_vma_create:
            // cprintf("a1: %u - a2: %u - a3: %u - a4: %u - a5: %u\n", a1, a2, a3, a4, a5);
            return (int32_t)sys_vma_create(a1, a2, a3);
        case SYS_vma_destroy:
            // cprintf("a1: %u - a2: %u - a3: %u - a4: %u - a5: %u\n", a1, a2, a3, a4, a5);
            return (int32_t)sys_vma_destroy((void*)a1, a2);
    default:
        return -E_NO_SYS;
    }
}

