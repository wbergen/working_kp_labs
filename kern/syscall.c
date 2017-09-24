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
static void *sys_vma_create(size_t size, int perm, int flags)
{
    cprintf("[KERN] sys_vma_create(): called\n");
    cprintf("[KERN] sys_vma_create(): size ==  %u, perm == %u, flags == %u\n", size, perm, flags);

   /* Virtual Memory Area allocation */

   /* LAB 4: Your code here. */

    // Get some permission information:

    /*
        #define TILE_SIZE   (4096)
        #define SWEEP_SPACE (6 * TILE_SIZE)
        #define STRIPE_SPACE    (2 * TILE_SIZE)
        #define TILE(I)     (I * TILE_SIZE)
        va = sys_vma_create(SWEEP_SPACE, PERM_W, MAP_POPULATE)
    
        MAP_POPULATE == 0x1, no other flags, in lib.h though..?
         - only flag right now
    */



    if (flags & 0x1) { // MAP_POPULATE
        cprintf("[KERN] sys_vma_create(): MAP_POPULATE %x\n",curenv);

    }

    // cprintf("%x\n", flags);   
    cprintf("[KERN] sys_vma_create(): curenv's alloc_vma_list pointer: %x\n",&curenv->alloc_vma_list);

    // Get the next available spot on the list?
    // Naive, but should work for testing...
    void * vat = curenv->alloc_vma_list->va;
    size_t lent = curenv->alloc_vma_list->len;
    void * spot = ROUNDUP(vat + lent, PGSIZE);

    /*
    iterate over the allocated vmas:
    */
    struct vma * temp = curenv->alloc_vma_list;
    size_t last_size = temp->len;
    uint32_t * last_addr = temp->va;
    uint32_t gap = 0;

    while (temp){
        cprintf("vma @ [%08u - %08u]\n", temp->va, temp->va + temp->len);

        temp = temp->vma_link;
        gap = (uint32_t)temp->va - ROUNDUP(((uint32_t)last_addr + last_size), PGSIZE);
        cprintf("gap: %u\n", gap);

        if (gap > size) {
            cprintf("spot should be: %08u\n",  last_addr + last_size);
            spot = (void *)((uint32_t)last_addr + last_size);
            // spot = ROUNDUP(last_addr + last_size, PGSIZE);
            break;
        }

        last_size = temp->len;
        last_addr = temp->va;



    }

    cprintf("[KERN] sys_vma_create(): vat ==  %x, lent == %u, spot == %x\n", vat, lent, spot);


    // int vma_new(struct env * e, void *va, size_t len, int type, char * src, size_t filesize, int perm){
    // if (vma_new(e, va, msize, VMA_BINARY, ((char *)eh)+ph->p_offset, ph->p_filesz, PTE_U | PTE_W) < 1){
    int ret = vma_new(curenv, spot, size, VMA_ANON, NULL, 0, perm | PTE_U);
    cprintf("[KERN] sys_vma_create(): vma_new returned %u\n", ret);
    // int ret = 5;
    if (ret < 1) {
        cprintf("[KERN] sys_vma_create(): failed to create the vma!\n");
        return (void *)-1;
    }

    // cprintf("[DEV] sys_vma_create(): size ==  %x, perm == %x, flags == %u\n", size, perm, flags);
    // cprintf("[DEV] sys_vma_create() called!\n");
    // cprintf("[KERN] sys_vma_create(): curenv's free_vma_list pointer: %x\n", &curenv->alloc_vma_list);

   return spot;
}

/*
 * Unmaps the specified range of memory starting at 
 * virtual address 'va', 'size' bytes long.
 */
static int sys_vma_destroy(void *va, size_t size)
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
    //struct vma * vma_lookup(struct env *e, void *va);
    // struct vma * vmad = vma_lookup(curenv, va);
    // cprintf("[KERN] sys_vma_destroy(): vma found w/ va %x\n", vmad->va);

   /* LAB 4: Your code here. */
   return -1;
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
            cprintf("a1: %u - a2: %u - a3: %u - a4: %u - a5: %u\n", a1, a2, a3, a4, a5);
            return (int32_t)sys_vma_destroy((void*)a1, a2);
    default:
        return -E_NO_SYS;
    }
}

