/* See COPYRIGHT for copyright information. */

#include <inc/x86.h>
#include <inc/mmu.h>
#include <inc/error.h>
#include <inc/string.h>
#include <inc/assert.h>
#include <inc/elf.h>

#include <kern/env.h>
#include <kern/pmap.h>
#include <kern/trap.h>
#include <kern/monitor.h>
#include <kern/sched.h>
#include <kern/cpu.h>
#include <kern/spinlock.h>
#include <kern/ide.h>

#include <kern/mm_pres.h>
#include <kern/vma.h>

struct env *envs = NULL;            /* All environments */
static struct env *env_free_list;   /* Free environment list */
                                    /* (linked by env->env_link) */
uintptr_t kesp; 
struct trapframe ktf;

#define ENVGENSHIFT 12      /* >= LOGNENV */

pde_t *env_pgdir;

int i;  // Index var

/*
 * Global descriptor table.
 *
 * Set up global descriptor table (GDT) with separate segments for
 * kernel mode and user mode.  Segments serve many purposes on the x86.
 * We don't use any of their memory-mapping capabilities, but we need
 * them to switch privilege levels.
 *
 * The kernel and user segments are identical except for the DPL.
 * To load the SS register, the CPL must equal the DPL.  Thus,
 * we must duplicate the segments for the user and the kernel.
 *
 * In particular, the last argument to the SEG macro used in the
 * definition of gdt specifies the Descriptor Privilege Level (DPL)
 * of that descriptor: 0 for kernel and 3 for user.
 */
struct segdesc gdt[NCPU + 5] =
{
    /* 0x0 - unused (always faults -- for trapping NULL far pointers) */
    SEG_NULL,

    /* 0x8 - kernel code segment */
    [GD_KT >> 3] = SEG(STA_X | STA_R, 0x0, 0xffffffff, 0),

    /* 0x10 - kernel data segment */
    [GD_KD >> 3] = SEG(STA_W, 0x0, 0xffffffff, 0),

    /* 0x18 - user code segment */
    [GD_UT >> 3] = SEG(STA_X | STA_R, 0x0, 0xffffffff, 3),

    /* 0x20 - user data segment */
    [GD_UD >> 3] = SEG(STA_W, 0x0, 0xffffffff, 3),

    /* 0x28 - Per-CPU TSS descriptors (starting from GD_TSS0) are initialized
     *        in trap_init_percpu() */
    [GD_TSS0 >> 3] = SEG_NULL
};

struct pseudodesc gdt_pd = {
    sizeof(gdt) - 1, (unsigned long) gdt
};

/*
 * Converts an envid to an env pointer.
 * If checkperm is set, the specified environment must be either the
 * current environment or an immediate child of the current environment.
 *
 * RETURNS
 *   0 on success, -E_BAD_ENV on error.
 *   On success, sets *env_store to the environment.
 *   On error, sets *env_store to NULL.
 */
int envid2env(envid_t envid, struct env **env_store, bool checkperm)
{
    struct env *e;

    assert_lock_env();

    /* If envid is zero, return the current environment. */
    if (envid == 0) {
        *env_store = curenv;
        return 0;
    }

    /*
     * Look up the env structure via the index part of the envid,
     * then check the env_id field in that struct env
     * to ensure that the envid is not stale
     * (i.e., does not refer to a _previous_ environment
     * that used the same slot in the envs[] array).
     */
    e = &envs[ENVX(envid)];
    if (e->env_status == ENV_FREE || e->env_id != envid) {
        *env_store = 0;
        return -E_BAD_ENV;
    }

    /*
     * Check that the calling environment has legitimate permission
     * to manipulate the specified environment.
     * If checkperm is set, the specified environment
     * must be either the current environment
     * or an immediate child of the current environment.
     */
    if (checkperm && e != curenv && e->env_parent_id != curenv->env_id) {
        *env_store = 0;
        return -E_BAD_ENV;
    }

    *env_store = e;
    return 0;
}

/*
 * Mark all environments in 'envs' as free, set their env_ids to 0,
 * and insert them into the env_free_list.
 * Make sure the environments are in the free list in the same order
 * they are in the envs array (i.e., so that the first call to
 * env_alloc() returns envs[0]).
 */
void env_init(void)
{
    /* Set up envs array. */
    /* LAB 3: Your code here. */

    // Count backwards to keep order == in envs:
    int i;
    for (i = NENV; i >= 0; i--) {

        envs[i].env_id = 0;
        envs[i].env_alloc_pages = 0;
        //Initialize the env vmas
        vma_proc_init(&envs[i]);
        envs[i].wait_id = -1;
        envs[i].env_link = env_free_list;
        env_free_list = &envs[i];

    }

    /* Per-CPU part of the initialization */
    env_init_percpu();
}

/* Load GDT and segment descriptors. */
void env_init_percpu(void)
{
    lgdt(&gdt_pd);
    /* The kernel never uses GS or FS, so we leave those set to the user data
     * segment. */
    asm volatile("movw %%ax,%%gs" :: "a" (GD_UD|3));
    asm volatile("movw %%ax,%%fs" :: "a" (GD_UD|3));
    /* The kernel does use ES, DS, and SS.  We'll change between the kernel and
     * user data segments as needed. */
    asm volatile("movw %%ax,%%es" :: "a" (GD_KD));
    asm volatile("movw %%ax,%%ds" :: "a" (GD_KD));
    asm volatile("movw %%ax,%%ss" :: "a" (GD_KD));
    /* Load the kernel text segment into CS. */
    asm volatile("ljmp %0,$1f\n 1:\n" :: "i" (GD_KT));
    /* For good measure, clear the local descriptor table (LDT), since we don't
     * use it. */
    lldt(0);
}

/*
 * Initialize the kernel virtual memory layout for environment e.
 * Allocate a page directory, set e->env_pgdir accordingly,
 * and initialize the kernel portion of the new environment's address space.
 * Do NOT (yet) map anything into the user portion
 * of the environment's virtual address space.
 *
 * Returns 0 on success, < 0 on error.  Errors include:
 *  -E_NO_MEM if page directory or table could not be allocated.
 */
static int env_setup_vm(struct env *e)
{
    int i;
    struct page_info *p = NULL;

    /* Allocate a page for the page directory */
    if (!(p = page_alloc(ALLOC_ZERO)))
        return -E_NO_MEM;

    /*
     * Now, set e->env_pgdir and initialize the page directory.
     *
     * Hint:
     *    - The VA space of all envs is identical above UTOP
     *  (except at UVPT, which we've set below).
     *  See inc/memlayout.h for permissions and layout.
     *  Can you use kern_pgdir as a template?  Hint: Yes.
     *  (Make sure you got the permissions right in Lab 2.)
     *    - The initial VA below UTOP is empty.
     *    - You do not need to make any more calls to page_alloc.
     *    - Note: In general, pp_ref is not maintained for physical pages mapped
     *      only above UTOP, but env_pgdir is an exception -- you need to
     *      increment env_pgdir's pp_ref for env_free to work correctly.
     *    - The functions in kern/pmap.h are handy.
     */

    /* LAB 3: Your code here. */
    // Increment pp_ref
    p->pp_ref ++;
    
    // Set the enviorment's pgdir to the kva of new page:
    // This is like boot_alloc(PGSIZE), but we already have a page, don't need to find one, so just cast:
    e->env_pgdir = (pde_t *) page2kva(p);

    // Initialize env_pgdir, using kern_pgdir as template (ie. copy?)
    // The copy provides the user page dir with kernel position information
    // we map everything above UTOP 
    for (i = PDX(UTOP); i < PGSIZE / sizeof(pde_t); i++)
    {
        e->env_pgdir[i] = kern_pgdir[i];
    }

    /* UVPT maps the env's own page table read-only.
     * Permissions: kernel R, user R */
    e->env_pgdir[PDX(UVPT)] = PADDR(e->env_pgdir) | PTE_P | PTE_U;

    return 0;
}

/*
    This function copies the trapframe of 1 environments and a tf
*/
void kenv_cpy_tf(struct trapframe *tfs, struct trapframe *tf){

    tf->tf_regs.reg_edi = tfs->tf_regs.reg_edi ;
    tf->tf_regs.reg_esi = tfs->tf_regs.reg_esi ;
    tf->tf_regs.reg_ebp = tfs->tf_regs.reg_ebp ;
    tf->tf_regs.reg_oesp = tfs->tf_regs.reg_oesp ;
    tf->tf_regs.reg_ebx = tfs->tf_regs.reg_ebx ;
    tf->tf_regs.reg_edx = tfs->tf_regs.reg_edx ;
    tf->tf_regs.reg_ecx = tfs->tf_regs.reg_ecx ;
    tf->tf_regs.reg_eax = tfs->tf_regs.reg_eax ;

    tf->tf_es = tfs->tf_es ;
    tf->tf_ds = tfs->tf_ds ;
    tf->tf_trapno = tfs->tf_trapno ;
    tf->tf_err = tfs->tf_err ;
    tf->tf_eip = tfs->tf_eip ;
    tf->tf_cs = tfs->tf_cs ;
    tf->tf_eflags = tfs->tf_eflags ;
    tf->tf_esp = tfs->tf_esp ;
    tf->tf_ss = tfs->tf_ss ;
}
   

/*
    This function copies the trapframe of 2 environments
*/
void env_cpy_tf(struct env *child, struct env *parent){

    child->env_tf.tf_regs.reg_edi = parent->env_tf.tf_regs.reg_edi ;
    child->env_tf.tf_regs.reg_esi = parent->env_tf.tf_regs.reg_esi ;
    child->env_tf.tf_regs.reg_ebp = parent->env_tf.tf_regs.reg_ebp ;
    child->env_tf.tf_regs.reg_oesp = parent->env_tf.tf_regs.reg_oesp ;
    child->env_tf.tf_regs.reg_ebx = parent->env_tf.tf_regs.reg_ebx ;
    child->env_tf.tf_regs.reg_edx = parent->env_tf.tf_regs.reg_edx ;
    child->env_tf.tf_regs.reg_ecx = parent->env_tf.tf_regs.reg_ecx ;
    child->env_tf.tf_regs.reg_eax = parent->env_tf.tf_regs.reg_eax ;

    child->env_tf.tf_es = parent->env_tf.tf_es ;
    child->env_tf.tf_ds = parent->env_tf.tf_ds ;
    child->env_tf.tf_trapno = parent->env_tf.tf_trapno ;
    child->env_tf.tf_err = parent->env_tf.tf_err ;
    child->env_tf.tf_eip = parent->env_tf.tf_eip ;
    child->env_tf.tf_cs = parent->env_tf.tf_cs ;
    child->env_tf.tf_eflags = parent->env_tf.tf_eflags ;
    child->env_tf.tf_esp = parent->env_tf.tf_esp ;
    child->env_tf.tf_ss = parent->env_tf.tf_ss ;

    //cprintf("p eip: %08x, c eip: %08x \n",parent->env_tf.tf_eip, child->env_tf.tf_eip);
}
/*
    This function copies the vmas of 2 environments

    returns 1 is success, 0 if errors
*/
int env_cpy_vmas(struct env *child, struct env *parent){

    struct vma * v = parent->alloc_vma_list;
    struct vma * n;

    //Iterate over the parent allocated vmas and create an identical one in the child
    while(v){

        //just to be sure
        vma_consistency_check(v, v->type);

        //create a new vma in the child
        if(!vma_new(child, v->va, v->len, v->type, v->cpy_src, v->src_sz, v->cpy_dst, v->perm, &n)){
            cprintf("[KERN]env_cpy_vmas(): vma new failed\n");
            return 0;
        }
        n->hps = v->hps;

        v = v->vma_link;
    }
    return 1;
}

/*
    Print all the memory of a vma 
*/
void print_vma_pages(struct env * e, struct vma * v){

    void *va;
    pte_t *pte;
    char * i;
    for(va = v->va; va < (v->va + v->len); va += PGSIZE){
        pte =  pgdir_walk(e->env_pgdir, va, 0);
            if(pte){
                cprintf("[DEBUGMYVMA] va: %08x\n", va);
                for(i = va; i < (char *)(va + PGSIZE); i++){
                    cprintf(" %08x",*i);
                }
                 cprintf("\n");
            }
    }
}

/*
    This function copies pgdir of two environments
    it also mark the allocated entries of both copy on write

    Returns 1, 0 if failure
*/
int env_cpy_pgdir_cow(struct env *child, struct env *parent){

    struct vma * vp = parent->alloc_vma_list;
    pde_t * p_pgdir =  parent->env_pgdir;
    pde_t * c_pgdir = child->env_pgdir;
    pte_t * pte_p, * pte_c;
    struct page_info *pg;
    void * va;

    while(vp){
        if(vp->type == VMA_ANON || vp->type == VMA_BINARY){
            // Copy the present entries
            for(va = vp->va; va < (vp->va + vp->len); va += PGSIZE){
                //Find the pte
                pte_p =  pgdir_walk(p_pgdir, va, 0);

                if(pte_p){
                    pte_c = pgdir_walk(c_pgdir, va, 1);
                    if(!pte_c){
                        return 0;
                    }
                    if(*pte_p & PTE_W){
                        *pte_p &= ~PTE_W;
                    }
                    *pte_c = *pte_p;
                    pg = pa2page(PTE_ADDR(*pte_p));
                    pg->pp_ref++;   
                }
            }
        }
        //print_vma_pages(child, vp);
        vp = vp->vma_link;
    }
    return 1;
}

/*
    this function duplicate two environments:
        It sets the allocated pages in both parent and child COW 
        It set the return values in both parent and child in eax

    It returns child id if success if success, 0 if failure
*/
int env_dup(struct env * parent){
    struct env * child;

    //Allocate a new enviroment
    if(env_alloc(&child, parent->env_id, parent->env_type) < 0){
        cprintf("[KERN]env_dup(): Impossible to allocate a new env\n");
        return 0;
    }
    child->env_alloc_pages = parent->env_alloc_pages;
    
    cprintf("[KERN] env_dup(): env allocated\n");

    cprintf("[KERN] env_dup(): eax modified\n");
    //Copy the VMAs
    if(!env_cpy_vmas(child, parent)){
        cprintf("[KERN]env_dup(): cpy_vmas failed\n");
        return 0;
    }
    cprintf("[KERN] env_dup(): vmas copied\n");

    //Copy the trapframe
    env_cpy_tf(child, parent);

    cprintf("[KERN] env_dup(): tf copied\n");

    //set the eax register with the return value for parent and child
    child->env_tf.tf_regs.reg_eax = 0;
    parent->env_tf.tf_regs.reg_eax = child->env_id;
    
    //Copy the page table entries COW
    if(!env_cpy_pgdir_cow(child, parent)){
        cprintf("[KERN]env_dup(): cpy_pgdir_cow failed\n");
        return 0;        
    }
    cprintf("[KERN] env_dup(): pgdir copied COW\n");

    //Sched the child
    invalidate_env_ts(parent);

    sched_yield();
    
    return child->env_id;


}
/*
 * Allocates and initializes a new environment.
 * On success, the new environment is stored in *newenv_store.
 *
 * Returns 0 on success, < 0 on failure.  Errors include:
 *  -E_NO_FREE_ENV if all NENVS environments are allocated
 *  -E_NO_MEM on memory exhaustion
 */
int env_alloc(struct env **newenv_store, envid_t parent_id, int type)
{

    cprintf("[ENV] env_alloc() called!\n");
    int32_t generation;
    int r;
    struct env *e;

    if (!(e = env_free_list))
        return -E_NO_FREE_ENV;

    /* Allocate and set up the page directory for this environment. */
    if ((r = env_setup_vm(e)) < 0)
        return r;

    /* Generate an env_id for this environment. */
    generation = (e->env_id + (1 << ENVGENSHIFT)) & ~(NENV - 1);
    if (generation <= 0)    /* Don't create a negative env_id. */
        generation = 1 << ENVGENSHIFT;
    e->env_id = generation | (e - envs);

    /* Set the basic status variables. */
    e->env_parent_id = parent_id;
    e->env_type = type;
    e->env_status = ENV_RUNNABLE;
    e->env_runs = 0;

    /*
     * Clear out all the saved register state, to prevent the register values of
     * a prior environment inhabiting this env structure from "leaking" into our
     * new environment.
     */
    memset(&e->env_tf, 0, sizeof(e->env_tf));

    /*
     * Set up appropriate initial values for the segment registers.
     * GD_UD is the user data segment selector in the GDT, and
     * GD_UT is the user text segment selector (see inc/memlayout.h).
     * The low 2 bits of each segment register contains the
     * Requestor Privilege Level (RPL); 3 means user mode.  When
     * we switch privilege levels, the hardware does various
     * checks involving the RPL and the Descriptor Privilege Level
     * (DPL) stored in the descriptors themselves.
     */

    /*
        #define GD_KT     0x08     kernel text
        #define GD_KD     0x10     kernel data
        #define GD_UT     0x18     user text
        #define GD_UD     0x20     user data
        #define GD_TSS0   0x28     Task segment selector for CPU 0
    */

    if (e->env_type == ENV_TYPE_KERNEL) {
        // cprintf("ktask setup\n");
        e->env_tf.tf_ds = GD_KD;
        e->env_tf.tf_es = GD_KD;
        e->env_tf.tf_ss = GD_KD;
        //e->env_tf.tf_esp = KSTACKTOP;
        e->env_tf.tf_cs = GD_KT;
        // e->env_tf.tf_eflags |= FL_IF;
    } else {
        e->env_tf.tf_ds = GD_UD | 3;
        e->env_tf.tf_es = GD_UD | 3;
        e->env_tf.tf_ss = GD_UD | 3;
        e->env_tf.tf_esp = USTACKTOP;
        e->env_tf.tf_cs = GD_UT | 3;
        e->env_tf.tf_eflags |= FL_IF;
    }
    /* You will set e->env_tf.tf_eip later. */

    /* Enable interrupts while in user mode.
     * LAB 5: Your code here. */


    /* commit the allocation */
    env_free_list = e->env_link;
    *newenv_store = e;

    cprintf("[ENV][%08x] new env %08x\n", curenv ? curenv->env_id : 0, e->env_id);
    return 0;
}

/*
 * Allocate len bytes of physical memory for environment env, and map it at
 * virtual address va in the environment's address space.
 * Does not zero or otherwise initialize the mapped pages in any way.
 * Pages should be writable by user and kernel.
 * Panic if any allocation attempt fails.
 */
static void region_alloc(struct env *e, void *va, size_t len)
{
    /*
     * LAB 3: Your code here.
     * (But only if you need it for load_icode.)
     *
     * Hint: It is easier to use region_alloc if the caller can pass
     *   'va' and 'len' values that are not page-aligned.
     *   You should round va down, and round (va + len) up.
     *   (Watch out for corner-cases!)
     */
}

/*
 * Set up the initial program binary, stack, and processor flags for a user
 * process.
 * This function is ONLY called during kernel initialization, before running the
 * first user-mode environment.
 *
 * This function loads all loadable segments from the ELF binary image into the
 * environment's user memory, starting at the appropriate virtual addresses
 * indicated in the ELF program header.
 * At the same time it clears to zero any portions of these segments that are
 * marked in the program header as being mapped but not actually present in the
 * ELF file - i.e., the program's bss section.
 *
 * All this is very similar to what our boot loader does, except the boot loader
 * also needs to read the code from disk. Take a look at boot/main.c to get
 * ideas.
 *
 * Finally, this function maps one page for the program's initial stack.
 *
 * load_icode panics if it encounters problems.
 *  - How might load_icode fail?  What might be wrong with the given input?
 */
static void load_icode(struct env *e, uint8_t *binary)
{
    /*
     * Hints:
     *  Load each program segment into virtual memory at the address specified
     *  in the ELF section header.
     *  You should only load segments with ph->p_type == ELF_PROG_LOAD.
     *  Each segment's virtual address can be found in ph->p_va and its size in
     *  memory can be found in ph->p_memsz.
     *  The ph->p_filesz bytes from the ELF binary, starting at 'binary +
     *  ph->p_offset', should be copied to virtual address ph->p_va.
     *  Any remaining memory bytes should be cleared to zero.
     *  (The ELF header should have ph->p_filesz <= ph->p_memsz.)
     *  Use functions from the previous lab to allocate and map pages.
     *
     *  All page protection bits should be user read/write for now.
     *  ELF segments are not necessarily page-aligned, but you can assume for
     *  this function that no two segments will touch the same virtual page.
     *
     *  You may find a function like region_alloc useful.
     *
     *  Loading the segments is much simpler if you can move data directly into
     *  the virtual addresses stored in the ELF binary.
     *  So which page directory should be in force during this function?
     *
     *  You must also do something with the program's entry point, to make sure
     *  that the environment starts executing there.
     *  What?  (See env_run() and env_pop_tf() below.)
     */

    /* LAB 3: Your code here. */

    /* Now map one page for the program's initial stack at virtual address
     * USTACKTOP - PGSIZE. */

    /* LAB 3: Your code here. */
/* obj/user/hello:
      Type           Offset   VirtAddr   PhysAddr   FileSiz MemSiz  Flg Align
      LOAD           0x001000 0x00200000 0x00200000 0x03e4f 0x03e4f RW  0x1000
      LOAD           0x005020 0x00800020 0x00800020 0x01130 0x01130 R E 0x1000
      LOAD           0x007000 0x00802000 0x00802000 0x00004 0x00008 RW  0x1000
      GNU_STACK      0x000000 0x00000000 0x00000000 0x00000 0x00000 RWE 0x10
    */
    size_t change_env_flag = 0;

    // Ensure that we're using the enviorment's pg_dir:
    if (e != curenv){
        change_env_flag = 1;
        lcr3(PADDR(e->env_pgdir));
    }

    // Structures:
    struct elf *eh;
    struct elf_proghdr *ph, *eph;


    // Cast binary as elf_header:
    eh = (struct elf *) binary;

    /* is this a valid ELF? */
    if (eh->e_magic != ELF_MAGIC)
        panic("load_icode(): Invalid ELF!\n");


    // Get Program Header:
    ph = (struct elf_proghdr *) ((uint8_t *) eh + eh->e_phoff);


    // Number of program headers:
    eph = ph + eh->e_phnum;

    // Segment info:
    uint32_t *va;
    size_t msize;
    for (; ph < eph; ph++)
    {   
        // If the segment is LOAD, map it:
        if (ph->p_type == ELF_PROG_LOAD){
            int perm = PTE_U;
            // Check size:
            if (ph->p_filesz > ph->p_memsz){
                panic("load_icode(): Segment's filesz > memsz!\n");
            }

            // Get the address to map @, and the size:
            va = (void *) ROUNDDOWN(ph->p_va, PGSIZE);
            // msize = (size_t) ROUNDUP( (ph->p_memsz + ((uint32_t *)ph->p_va - va)), PGSIZE);

            // cprintf("\nva: %x msize: %u\n", va, msize);
            // va = (void *) ph->p_va;
            msize = (size_t) ph->p_memsz + ((uint32_t *)ph->p_va - va);

            // cprintf("\nva: %x msize: %u\n", va, msize);
            // Map:
            // region_alloc(e, va, msize);

            //set the flags:
            if(ph->p_flags & ELF_PROG_FLAG_WRITE){
                
                perm |= PTE_W;  
            }
            //if(i != 0){
              //  perm |= PTE_W;
            //}
            // if ELF_PROG_FLAG_READ or LF_PROG_FLAG_EXEC do nothing
            // VMA Map:
            // int vma_new(struct env *e, void *va, size_t len, int perm, ...){
            // 1 success, 0 failure, -1 other errors...        
            if (vma_new(e, va, msize, VMA_BINARY, ((char *)eh)+ph->p_offset, ph->p_filesz, (ph->p_va-(uint32_t)va), perm, NULL) < 1){
                panic("load_icode(): vma creation failed!\n");
            }


        }
    }

    if ( change_env_flag ){
        lcr3(PADDR(kern_pgdir));
    }

    // Now map one page for the program's initial stack at virtual address
    // region_alloc(e, (void *) USTACKTOP-PGSIZE, PGSIZE);
    if (vma_new(e, (void*)USTACKTOP-PGSIZE, PGSIZE, VMA_ANON, NULL, 0, 0, PTE_U | PTE_W, NULL) < 1){
        panic("load_icode(): vma stack creation failed!\n");
    }

    // Set the enviorment's entry point (in the trapframe) to the elf's:
    e->env_tf.tf_eip = eh->e_entry;

    /* vmatest binary uses the following */
    /* 1. Map one RO page of VMA for UTEMP at virtual address UTEMP.
     * 2. Map one RW page of VMA for UTEMP+PGSIZE at virtual address UTEMP. */

    /* LAB 4: Your code here. */

    if (vma_new(e, (void*)UTEMP, PGSIZE, VMA_ANON, NULL, 0, 0, PTE_U, NULL) < 1){
        panic("load_icode(): vma stack creation failed!\n");
    }
    if (vma_new(e, (void*)UTEMP + PGSIZE, PGSIZE, VMA_ANON, NULL, 0, 0, PTE_U | PTE_W, NULL) < 1){
        panic("load_icode(): vma stack creation failed!\n");
    }
    // Attempt to debug the vma's we've allocated?
    // struct env *temp;
    // void * temp = e->free_vma_list->vma_link;
    // while (temp){
    //     cprintf("%x\n", e->free_vma_list);
    //     temp = (struct vma *)e->free_vma_list->vma_link;

    // }

    // cprintf("load_icode(): returning...\n");

}

/*
    Kernel Thread code
*/
void ktask(){
    asm ("movl %%esp, %0;" : "=r" ( kesp ));

    struct tasklet * t = t_list;
    int i, t_id, status = 0;

    // Look for work:
    lock_task();
    while(t){
        if(t->state == T_WORK){
            t->state = T_WORKING;
            t_id = t->id;
            break;
        }
        t = t->t_next;
    }
    unlock_task();
    
    cprintf("[KTASK] Tasklet To Run: [%08x, fptr: %08x, count: %u]\n", t->id, t->fptr, t->count);

    cprintf("[KTASK] Calling tasklet's function...\n");

    if(t->fptr == (uint32_t *)page_out){
        int (*f)();
        f = (int (*)(struct tasklet *))t->fptr;
        status = f(t);        
    } else if (t->fptr == (uint32_t *)page_in){
        int (*f)();
        f = (int (*)(struct tasklet *))t->fptr;
        status = f(t);
    } else {
        cprintf("[KTASK] Unknown function called!\n");
    }

    //Update the tasklet     
    lock_task();
    t = t_list;    
    //Update the tasklet     
    while(t){
        if(t->id == t_id){
            if(status){
                cprintf("[KTASK] Work done, Free the task\n");
                task_free(t->id);
            }else{
                cprintf("[KTASK] Work not done \n");
                t->state = T_WORK;                    
            }
            t_id = t->id;
            break;
        }
        t = t->t_next;
    }
    unlock_task();
    cprintf("[KTASK] Tasklet at end of ktask(): [%08x, fptr: %08x, count: %u] state: %u.\n", t->id, t->fptr, t->count, t->state);
    
    // ktask round done, schedule:
    lock_env();
    lock_kernel();
    
    curenv->env_status = ENV_RUNNABLE;
    
    sched_yield();
    // return;

}

static void load_kthread(struct env *e, void (*binary)()){

    //  Allocating a page for the stack
    struct page_info * pp = page_alloc(ALLOC_ZERO);
    // set the entry point to the 
    e->env_tf.tf_eip = (uintptr_t)binary;

    if(pp){
        kesp = (uintptr_t)(page2kva(pp) + (PGSIZE - 1) );
        e->env_tf.tf_esp = kesp;
        kenv_cpy_tf(&e->env_tf,&ktf);

    }else{
        panic("[INIT] FAILURE ALLOCATING KERNEL THREAD STACK\n");
    }

}
/*
 * Allocates a new env with env_alloc, loads the named elf binary into it with
 * load_icode, and sets its env_type.
 * This function is ONLY called during kernel initialization, before running the
 * first user-mode environment.
 * The new env's parent ID is set to 0.
 */
void env_create(uint8_t *binary, enum env_type type)
{
    /* LAB 3: Your code here. */

    struct env *e;
    int ret = env_alloc(&e,0, type);

    if(ret == -E_NO_MEM ){
        panic("env_create: OUT OF MEMORY\n");
    }
    if(ret == -E_NO_FREE_ENV ){
        panic("env_create: NO FREE ENV\n");
    }

    cprintf("[ENV] creating %08x, of type %08x\n", e->env_id, e->env_type);

    load_icode(e,binary);

}

void kenv_create(void (*binary)(), enum env_type type)
{
    /* LAB 3: Your code here. */

    struct env *e;
    int ret = env_alloc(&e, 0, type);

    if(ret == -E_NO_MEM ){
        panic("env_create: OUT OF MEMORY\n");
    }
    if(ret == -E_NO_FREE_ENV ){
        panic("env_create: NO FREE ENV\n");
    }

    cprintf("[ENV] creating %08x, of type %08x\n", e->env_id, e->env_type);

    load_kthread(e,binary);

}
/*
 * Frees env e and all memory it uses.
 */
void env_free(struct env *e)
{
    pte_t *pt;
    int i;
    uint32_t pdeno, pteno;
    physaddr_t pa;

    assert_lock_env();
    assert_lock_pagealloc();
    /* If freeing the current environment, switch to kern_pgdir
     * before freeing the page directory, just in case the page
     * gets reused. */
    //Notify wait process:
    for(i = 0; i < NENV; i++){
        if(envs[i].env_status == ENV_SLEEPING && envs[i].wait_id == e->env_id){
            envs[i].env_status = ENV_RUNNABLE;
            envs[i].wait_id = -1;
        }

    }
    if (e == curenv)
        lcr3(PADDR(kern_pgdir));

    /* Note the environment's demise. */
    cprintf("[%08x] free env %08x\n", curenv ? curenv->env_id : 0, e->env_id);

    /* Flush all mapped pages in the user portion of the address space */
    static_assert(UTOP % PTSIZE == 0);
    for (pdeno = 0; pdeno < PDX(UTOP); pdeno++) {

        /* Only look at mapped page tables */
        if (!(e->env_pgdir[pdeno] & PTE_P))
            continue;

        /* Find the pa and va of the page table */
        pa = PTE_ADDR(e->env_pgdir[pdeno]);
        pt = (pte_t*) KADDR(pa);

        /* Unmap all PTEs in this page table */
        for (pteno = 0; pteno <= PTX(~0); pteno++) {
            if (pt[pteno] & PTE_P)
                page_remove(e->env_pgdir, PGADDR(pdeno, pteno, 0));
        }

        /* Free the page table itself */
        e->env_pgdir[pdeno] = 0;
        page_decref(pa2page(pa));
    }

    /*  reinizialize the vma    */
    vma_proc_init(e);
    e->env_alloc_pages = 0;

    /* Free the page directory */
    pa = PADDR(e->env_pgdir);
    e->env_pgdir = 0;
    page_decref(pa2page(pa));

    /* Free VMA list. */
    // cprintf("e->env_vmas: %x\n", e->env_vmas);
    // I just changed this to be by ref.. and it fixed the multiprocessor issue, beware!
    pa = PADDR(&e->env_vmas);
    e->env_vmas = 0;
    page_decref(pa2page(pa));

    /* return the environment to the free list */
    e->env_status = ENV_FREE;
    e->env_link = env_free_list;
    env_free_list = e;
}

/*
 * Frees environment e.
 * If e was the current env, then runs a new environment (and does not return
 * to the caller).
 */
void env_destroy(struct env *e)
{
    assert_lock_env();
    /* If e is currently running on other CPUs, we change its state to
     * ENV_DYING. A zombie environment will be freed the next time
     * it traps to the kernel. */
    if (e->env_status == ENV_RUNNING && curenv != e) {
        e->env_status = ENV_DYING;
        return;
    }
    lock_pagealloc();
    #ifdef DEBUG_SPINLOCK
        cprintf("-----------------------------------[cpu:%d][%x][LOCK][PAGE]\n",cpunum(),curenv->env_id);
    #endif
    env_free(e);
    #ifdef DEBUG_SPINLOCK
        cprintf("-----------------------------------[cpu:%d][%x][UNLOCK][PAGE]\n",cpunum(),curenv->env_id);
    #endif
    unlock_pagealloc();
    if (curenv == e) {
        curenv = NULL;
        sched_yield();
    }
}

/*
 * Restores the register values in the trapframe with the 'iret' instruction.
 * This exits the kernel and starts executing some environment's code.
 *
 * This function does not return.
 */
void env_pop_tf(struct trapframe *tf)
{

    /*
    #define GD_KT     0x08     kernel text
    #define GD_KD     0x10     kernel data
    #define GD_UT     0x18     user text
    #define GD_UD     0x20     user data
    #define GD_TSS0   0x28     Task segment selector for CPU 0
    */

    // cprintf("tf's cs: 0x%08x\n", tf->tf_cs);
    // cprintf("tf's ss: 0x%08x\n", tf->tf_ss);
    // if (tf->tf_cs == GD_KT){
    //     cprintf("tf: ss == GD_KT\n");
    // }
    // if (tf->tf_cs == GD_UT){
    //     cprintf("tf: ss == GD_UT\n");
    // }
    /* Record the CPU we are running on for user-space debugging */
    curenv->env_cpunum = cpunum();

    __asm __volatile("movl %0,%%esp\n"
        "\tpopal\n"
        "\tpopl %%es\n"
        "\tpopl %%ds\n"
        "\taddl $0x8,%%esp\n" /* skip tf_+trapno and tf_errcode */
        "\tiret"
        : : "g" (tf) : "memory");
    panic("iret failed");  /* mostly to placate the compiler */
}

/*
 * Context switch from curenv to env e.
 * Note: if this is the first call to env_run, curenv is NULL.
 *
 * This function does not return.
 */
void env_run(struct env *e){
    /*
     * Step 1: If this is a context switch (a new environment is running):
     *     1. Set the current environment (if any) back to
     *        ENV_RUNNABLE if it is ENV_RUNNING (think about
     *        what other states it can be in),
     *     2. Set 'curenv' to the new environment,
     *     3. Set its status to ENV_RUNNING,
     *     4. Update its 'env_runs' counter,
     *     5. Use lcr3() to switch to its address space.
     * Step 2: Use env_pop_tf() to restore the environment's
     *     registers and drop into user mode in the
     *     environment.
     *
     * Hint: This function loads the new environment's state from
     *  e->env_tf.  Go back through the code you wrote above
     *  and make sure you have set the relevant parts of
     *  e->env_tf to sensible values.
     */

    //cprintf("[ENV] env_run type: %08x\n", e->env_type);
    struct env * old_e = curenv;
    // if (e->env_type == ENV_TYPE_KERNEL){
    //     cprintf("[ENV] RUNNING KERNEL THREAD[%08x]\n", e->env_id);
    //     cprintf("\t curenv: %08x\n", curenv);
    // } else {
    //     cprintf("[ENV] RUNNING USER THREAD[%08x]\n", e->env_id);
    // }

    #ifdef USE_BIG_KERNEL_LOCK
        if(lock_kernel_holding()){
            cprintf("ENV_RUN: LOCKED CPU:%d\n",cpunum());
        }else{
            cprintf("ENV_RUN: UNLOCKED CPU:%d\n",cpunum());
        }
    #endif
    assert_lock_env();

    /* LAB 3: Your code here. */
    if(curenv != e){
    
    /*
     *     1. Set the current environment (if any) back to
     *        ENV_RUNNABLE if it is ENV_RUNNING (think about
     *        what other states it can be in)
     */
    
        if(curenv != NULL){
            if(curenv->env_status == ENV_RUNNABLE ||
                curenv->env_status == ENV_FREE ||
                curenv->env_status == ENV_NOT_RUNNABLE){
                panic("env_run: ENV STATUS IS IN A INCONSISTENT STATE\n");
            }
            if(curenv->env_status == ENV_RUNNING){
                curenv->env_status = ENV_RUNNABLE;
                cprintf("should be now set to runnable... [%08x]'s status: %u\n", curenv->env_id, curenv->env_status);

            }
            //if the current env it's dying free it.
            if(curenv->env_status == ENV_DYING){
                lock_pagealloc();
                #ifdef DEBUG_SPINLOCK
                    cprintf("-----------------------------------[cpu:%d][%x][LOCK][PAGE]\n",cpunum(),curenv->env_id);
                #endif
                env_free(curenv);
                #ifdef DEBUG_SPINLOCK
                    cprintf("-----------------------------------[cpu:%d][%x][UNLOCK][PAGE]\n",cpunum(),curenv->env_id);
                #endif
                unlock_pagealloc();
            }
        }


        //2. Set 'curenv' to the new environment
        curenv = e;

        //3. Set its status to ENV_RUNNING
        curenv->env_status = ENV_RUNNING;
        //4. Update its 'env_runs' counter
        curenv->env_runs++;
        //5. Use lcr3() to switch to its address space.
        // cprintf("[%08x] pgdir: 0x%08x, type: %u\n", curenv->env_id, curenv->env_pgdir, curenv->env_type);
        lcr3(PADDR(curenv->env_pgdir));
    }
    #ifdef DEBUG_SPINLOCK
        cprintf("----------------------------env_run[cpu:%d][%x][UNLOCK][ENV]\n",cpunum(),curenv->env_id);
    #endif
    unlock_env();
    
    unlock_kernel();

    if(old_e && old_e->env_type == ENV_TYPE_KERNEL ){
        // cprintf("MOVING FROM KERNEL TO KERNEL. new esp: %x old esp: %x \n",e->env_tf.tf_esp,old_e->env_tf.tf_esp);
        kenv_cpy_tf(&ktf,&old_e->env_tf);

    }

    env_pop_tf(&e->env_tf);
    
}

