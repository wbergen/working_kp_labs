#include <inc/mmu.h>
#include <inc/x86.h>
#include <inc/assert.h>
#include <inc/string.h>

#include <kern/pmap.h>
#include <kern/trap.h>
#include <kern/console.h>
#include <kern/monitor.h>
#include <kern/env.h>
#include <kern/syscall.h>
#include <kern/sched.h>
#include <kern/kclock.h>
#include <kern/picirq.h>
#include <kern/cpu.h>
#include <kern/spinlock.h>

#include <kern/vma.h>

static struct taskstate ts;

/*
 * For debugging, so print_trapframe can distinguish between printing a saved
 * trapframe and printing the current trapframe and print some additional
 * information in the latter case.
 */
static struct trapframe *last_tf;

/*
 * Interrupt descriptor table.  (Must be built at run time because shifted
 * function addresses can't be represented in relocation records.)
 */
struct gatedesc idt[256] = { { 0 } };
struct pseudodesc idt_pd = {
    sizeof(idt) - 1, (uint32_t) idt
};


//Declare the trap handler functions
void trap_handler0_de();
void trap_handler1_db();
void trap_handler2_nmi();
void trap_handler3_bp();
void trap_handler4_of();
void trap_handler5_br();
void trap_handler6_ud();
void trap_handler7_nm();
void trap_handler8_df();
void trap_handler9_cso();
void trap_handler10_ts();
void trap_handler11_np();
void trap_handler12_ss();
void trap_handler13_gp();
void trap_handler14_pf();
void trap_handler15_res();
void trap_handler16_mf();
void trap_handler17_ac();
void trap_handler18_mc();
void trap_handler19_xm();
void trap_handler20_ve();

void trap_handler48_sc();

void irq_handler0();
void irq_handler1();
void irq_handler2();
void irq_handler3();
void irq_handler4();
void irq_handler5();
// void irq_handler6();
// void irq_handler7();
// void irq_handler8();
// void irq_handler9();
// void irq_handler10();
// void irq_handler11();
// void irq_handler12();
// void irq_handler13();
// void irq_handler14();
// void irq_handler15();



static const char *trapname(int trapno)
{
    static const char * const excnames[] = {
        "Divide error",
        "Debug",
        "Non-Maskable Interrupt",
        "Breakpoint",
        "Overflow",
        "BOUND Range Exceeded",
        "Invalid Opcode",
        "Device Not Available",
        "Double Fault",
        "Coprocessor Segment Overrun",
        "Invalid TSS",
        "Segment Not Present",
        "Stack Fault",
        "General Protection",
        "Page Fault",
        "(unknown trap)",
        "x87 FPU Floating-Point Error",
        "Alignment Check",
        "Machine-Check",
        "SIMD Floating-Point Exception"
    };

    if (trapno < sizeof(excnames)/sizeof(excnames[0]))
        return excnames[trapno];
    if (trapno == T_SYSCALL)
        return "System call";
    if (trapno >= IRQ_OFFSET && trapno < IRQ_OFFSET + 16)
        return "Hardware Interrupt";
    return "(unknown trap)";
}


void trap_init(void)
{
    extern struct segdesc gdt[];

    /* LAB 3: Your code here. */
    // #define SETGATE(gate, istrap, sel, off, dpl)
    SETGATE(idt[T_DIVIDE], 0, GD_KT, trap_handler0_de, 0);
    SETGATE(idt[T_DEBUG], 0, GD_KT, trap_handler1_db, 0);
    SETGATE(idt[T_NMI], 0, GD_KT, trap_handler2_nmi, 0);
    SETGATE(idt[T_BRKPT], 0, GD_KT, trap_handler3_bp, 3);
    SETGATE(idt[T_OFLOW], 0, GD_KT, trap_handler4_of, 0);
    SETGATE(idt[T_BOUND], 0, GD_KT, trap_handler5_br, 0);
    SETGATE(idt[T_ILLOP], 0, GD_KT, trap_handler6_ud, 0);
    SETGATE(idt[T_DEVICE], 0, GD_KT, trap_handler7_nm, 0);
    SETGATE(idt[T_DBLFLT], 0, GD_KT, trap_handler8_df, 0);  

    SETGATE(idt[T_TSS], 0, GD_KT, trap_handler10_ts, 0);
    SETGATE(idt[T_SEGNP], 0, GD_KT, trap_handler11_np, 0);
    SETGATE(idt[T_STACK], 0, GD_KT, trap_handler12_ss, 0);
    SETGATE(idt[T_GPFLT], 0, GD_KT, trap_handler13_gp, 0);
    SETGATE(idt[T_PGFLT], 0, GD_KT, trap_handler14_pf, 0);

    SETGATE(idt[T_FPERR], 0, GD_KT, trap_handler16_mf, 0);
    SETGATE(idt[T_ALIGN], 0, GD_KT, trap_handler17_ac, 0);
    SETGATE(idt[T_MCHK], 0, GD_KT, trap_handler18_mc, 0);
    SETGATE(idt[T_SIMDERR], 0, GD_KT, trap_handler19_xm, 0);

    SETGATE(idt[T_SYSCALL], 0, GD_KT, trap_handler48_sc, 3);

    /*
    IRQs:
    define IRQ_OFFSET  32 // IRQ 0 corresponds to int IRQ_OFFSET

    Hardware IRQ numbers. We receive these as (IRQ_OFFSET+IRQ_WHATEVER)
    #define IRQ_TIMER        0
    #define IRQ_KBD          1
    #define IRQ_SERIAL       4
    #define IRQ_SPURIOUS     7
    #define IRQ_IDE         14
    #define IRQ_ERROR       19
    */

    SETGATE(idt[IRQ_OFFSET], 0, GD_KT, irq_handler0, 0);
    SETGATE(idt[32+IRQ_KBD], 0, GD_KT, irq_handler1, 0);
    SETGATE(idt[32+IRQ_SERIAL], 0, GD_KT, irq_handler2, 0);
    SETGATE(idt[32+IRQ_SPURIOUS], 0, GD_KT, irq_handler3, 0);
    SETGATE(idt[32+IRQ_IDE], 0, GD_KT, irq_handler4, 0);
    SETGATE(idt[32+IRQ_ERROR], 0, GD_KT, irq_handler5, 0);
    // SETGATE(idt[T_IRQ_6], 0, GD_KT, irq_handler0, 0);
    // SETGATE(idt[T_IRQ_7], 0, GD_KT, irq_handler0, 0);
    // SETGATE(idt[T_IRQ_8], 0, GD_KT, irq_handler0, 0);
    // SETGATE(idt[T_IRQ_9], 0, GD_KT, irq_handler0, 0);
    // SETGATE(idt[T_IRQ_10], 0, GD_KT, irq_handler0, 0);
    // SETGATE(idt[T_IRQ_11], 0, GD_KT, irq_handler0, 0);
    // SETGATE(idt[T_IRQ_12], 0, GD_KT, irq_handler0, 0);
    // SETGATE(idt[T_IRQ_13], 0, GD_KT, irq_handler0, 0);
    // SETGATE(idt[T_IRQ_14], 0, GD_KT, irq_handler0, 0);
    // SETGATE(idt[T_IRQ_15], 0, GD_KT, irq_handler0, 0);

    /* Per-CPU setup */
    trap_init_percpu();
}

/* Initialize and load the per-CPU TSS and IDT. */
void trap_init_percpu(void)
{
    /* Setup a TSS so that we get the right stack when we trap to the kernel. */
    ts.ts_esp0 = KSTACKTOP;
    ts.ts_ss0 = GD_KD;

    /* Initialize the TSS slot of the gdt. */
    gdt[GD_TSS0 >> 3] = SEG16(STS_T32A, (uint32_t) (&ts),
                    sizeof(struct taskstate), 0);
    gdt[GD_TSS0 >> 3].sd_s = 0;

    /* Load the TSS selector (like other segment selectors, the bottom three
     * bits are special; we leave them 0). */
    ltr(GD_TSS0);

    /* Load the IDT. */
    lidt(&idt_pd);
}

void print_trapframe(struct trapframe *tf)
{
    cprintf("TRAP frame at %p from CPU %d\n", tf, cpunum());
    print_regs(&tf->tf_regs);
    cprintf("  es   0x----%04x\n", tf->tf_es);
    cprintf("  ds   0x----%04x\n", tf->tf_ds);
    cprintf("  trap 0x%08x %s\n", tf->tf_trapno, trapname(tf->tf_trapno));
    /* If this trap was a page fault that just happened (so %cr2 is meaningful),
     * print the faulting linear address. */
    if (tf == last_tf && tf->tf_trapno == T_PGFLT)
        cprintf("  cr2  0x%08x\n", rcr2());
    cprintf("  err  0x%08x", tf->tf_err);
    /* For page faults, print decoded fault error code:
     * U/K=fault occurred in user/kernel mode
     * W/R=a write/read caused the fault
     * PR=a protection violation caused the fault (NP=page not present). */
    if (tf->tf_trapno == T_PGFLT)
        cprintf(" [%s, %s, %s]\n",
            tf->tf_err & 4 ? "user" : "kernel",
            tf->tf_err & 2 ? "write" : "read",
            tf->tf_err & 1 ? "protection" : "not-present");
    else
        cprintf("\n");
    cprintf("  eip  0x%08x\n", tf->tf_eip);
    cprintf("  cs   0x----%04x\n", tf->tf_cs);
    cprintf("  flag 0x%08x\n", tf->tf_eflags);
    if ((tf->tf_cs & 3) != 0) {
        cprintf("  esp  0x%08x\n", tf->tf_esp);
        cprintf("  ss   0x----%04x\n", tf->tf_ss);
    }
}

void print_regs(struct pushregs *regs)
{
    cprintf("  edi  0x%08x\n", regs->reg_edi);
    cprintf("  esi  0x%08x\n", regs->reg_esi);
    cprintf("  ebp  0x%08x\n", regs->reg_ebp);
    cprintf("  oesp 0x%08x\n", regs->reg_oesp);
    cprintf("  ebx  0x%08x\n", regs->reg_ebx);
    cprintf("  edx  0x%08x\n", regs->reg_edx);
    cprintf("  ecx  0x%08x\n", regs->reg_ecx);
    cprintf("  eax  0x%08x\n", regs->reg_eax);
}

static void trap_dispatch(struct trapframe *tf)
{
    /* Handle processor exceptions. */
    /* LAB 3: Your code here. */

    /*
     * Handle spurious interrupts
     * The hardware sometimes raises these because of noise on the
     * IRQ line or other reasons. We don't care.
    */
    if (tf->tf_trapno == IRQ_OFFSET + IRQ_SPURIOUS) {
        cprintf("Spurious interrupt on irq 7\n");
        print_trapframe(tf);
        return;
    }

    // Syscall Ret:
    int ret;

    // Forward page faults to page_fault_handler:
    if (tf->tf_trapno == T_PGFLT){
        // print_trapframe(tf);
        page_fault_handler(tf);
        return;
    }

    // If breakpoint, call monitor:
    else if (tf->tf_trapno == T_BRKPT){
        print_trapframe(tf);
        monitor(tf);
    }

    /*
      DEF: int32_t syscall(uint32_t num, uint32_t a1, uint32_t a2, uint32_t a3, uint32_t a4, uint32_t a5);
      num: syscall number (eax)
      a1-5: args: five parameters in DX, CX, BX, DI, SI.
      return value -> trapframe's eax reg
    */

    // Syscall Functionality:
    else if (tf->tf_trapno == T_SYSCALL){
        
        // Make Grade Happy:
        // print_trapframe(tf);
        
        // Setup Args, syscall:
        ret = syscall(tf->tf_regs.reg_eax,
                    tf->tf_regs.reg_edx,
                    tf->tf_regs.reg_ecx,
                    tf->tf_regs.reg_ebx,
                    tf->tf_regs.reg_edi,
                    tf->tf_regs.reg_esi);

        tf->tf_regs.reg_eax = ret;
    }

/*
     * Handle clock interrupts. Don't forget to acknowledge the interrupt using
     * lapic_eoi() before calling the scheduler!
     * LAB 5: Your code here.
     */

    else if (tf->tf_trapno == IRQ_OFFSET) {
        cprintf("[KERN] got a timer interrupt!\n");
        lapic_eoi();
        sched_yield();
    }

    /* Unexpected trap: The user process or the kernel has a bug. */
    else if (tf->tf_cs == GD_KT) {
        print_trapframe(tf);
        panic("unhandled trap in kernel");
    } else {
        // Make Grade Happy:
        print_trapframe(tf);
        env_destroy(curenv);
        return;
    }
}

void trap(struct trapframe *tf)
{
    /* The environment may have set DF and some versions of GCC rely on DF being
     * clear. */
    asm volatile("cld" ::: "cc");

    /* Halt the CPU if some other CPU has called panic(). */
    extern char *panicstr;
    if (panicstr)
        asm volatile("hlt");

    /* Re-acqurie the big kernel lock if we were halted in sched_yield(). */
    if (xchg(&thiscpu->cpu_status, CPU_STARTED) == CPU_HALTED)
        lock_kernel();

    /* Check that interrupts are disabled.
     * If this assertion fails, DO NOT be tempted to fix it by inserting a "cli"
     * in the interrupt path. */
    assert(!(read_eflags() & FL_IF));

    cprintf("Incoming TRAP frame at %p\n", tf);

    if ((tf->tf_cs & 3) == 3) {
        /* Trapped from user mode. */
        /* Acquire the big kernel lock before doing any serious kernel work.
         * LAB 5: Your code here. */

        assert(curenv);

        /* Garbage collect if current enviroment is a zombie. */
        if (curenv->env_status == ENV_DYING) {
            env_free(curenv);
            curenv = NULL;
            sched_yield();
        }

        /* Copy trap frame (which is currently on the stack) into
         * 'curenv->env_tf', so that running the environment will restart at the
         * trap point. */
        curenv->env_tf = *tf;
        /* The trapframe on the stack should be ignored from here on. */
        tf = &curenv->env_tf;
    }

    /* Record that tf is the last real trapframe so print_trapframe can print
     * some additional information. */
    last_tf = tf;

    /* Dispatch based on what type of trap occurred */
    trap_dispatch(tf);

     /* If we made it to this point, then no other environment was scheduled, so
     * we should return to the current environment if doing so makes sense. */
    if (curenv && curenv->env_status == ENV_RUNNING)
        env_run(curenv);
    else
        sched_yield();
}

/*
 * Allocate len bytes of physical memory for environment env, and map it at
 * virtual address va in the environment's address space.
 * Does not zero or otherwise initialize the mapped pages in any way.
 * Pages should be writable by user and kernel.
 * Panic if any allocation attempt fails.
 */
int i;
static void region_alloc(void *va, size_t len, int perm)
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
    struct env *e = curenv;
    struct page_info *p; // the page to allocate
    void *va_ptr = ROUNDDOWN(va, PGSIZE); // address start
    uint32_t num_pages = (uint32_t) ROUNDUP( (len + (va - va_ptr)), PGSIZE) / PGSIZE; // number of pages to alloc

    // Check rounded out pages:
    for (i = 0; i < num_pages; ++i)
    {
        // allocate a phy page
        p = page_alloc(0);
        //if the page cannot be allocated panic
        if (p){
            //insert the page in the env_pgdir, if fails panic
            if(page_insert(e->env_pgdir, p, (va_ptr + (i*PGSIZE)), perm)){
                panic("region_alloc(): page_insert failure\n");
            }
        } else {
            panic("region_alloc(): page_alloc failure\n");

        }
    }
}

/* Destroy the environment that caused the fault. */
void kill_env(uint32_t fault_va, struct trapframe *tf){
    cprintf("[%08x] user fault va %08x ip %08x\n", curenv->env_id, fault_va, tf->tf_eip);
    print_trapframe(tf);
    env_destroy(curenv);
}

void alloc_page_after_fault(uint32_t fault_va, struct trapframe *tf){
    
    struct vma * vma_el;

    // Alignment debugging:
    cprintf("\nlooking for %x in vmas... env_id:%x\n", fault_va,curenv->env_id);
    print_all_vmas(curenv);
    cprintf("\n");



    vma_el = vma_lookup(curenv, (void *)fault_va);
    
    // Check for presence of a vma covering the faulting addr:
    if (vma_el){
       
        // If it's a binary allocate the enough pages to span all vma and copy from file
        if(vma_el->type == VMA_BINARY){

            cprintf("[KERN] page_fault_handler(): [BINARY] vma exists @ %x!  Allocating \"on demand\" page...\n", vma_el->va);

            region_alloc(vma_el->va, vma_el->len, vma_el->perm);

            memcpy(vma_el->va + vma_el->cpy_dst, vma_el->cpy_src ,vma_el->src_sz);

            // Write 0s to (filesz, memsz]:
            if (vma_el->src_sz != vma_el->len){
                memset(vma_el->va + vma_el->cpy_dst + vma_el->src_sz, 0, vma_el->len - vma_el->src_sz - vma_el->cpy_dst);
            }
        } else {

            // VMA exists, so page a page for the env:
            cprintf("[KERN] page_fault_handler(): [ANON] vma exists @ %x!  Allocating \"on demand\" page...\n", vma_el->va);

            // Allocate a physical frame, huge or not
            struct page_info * demand_page;
            if (vma_el->hps) {
                demand_page = page_alloc(ALLOC_ZERO | ALLOC_HUGE);
            } else {
                demand_page = page_alloc(ALLOC_ZERO);
            }
            if(!demand_page){
                panic("[KERN] page_fault_handler: WE ARE OUT OUT OF MEMORY\n");
            }
            //Insert the physical frame in the page directory
            int ret = page_insert(curenv->env_pgdir, demand_page, (void *)fault_va, vma_el->perm);
            if(ret != 0){

                // If Failure:
                cprintf("[KERN] page_fault_handler(): page_insert failed, impossible to insert the phy frame in the process page directory\n");
                kill_env(fault_va, tf);
            }
        }
    } else {

        // No vma covering addr:
        cprintf("[KERN] page_fault_handler(): Faulting addr not allocated in env's VMAs!\n");
        kill_env(fault_va, tf);
    }
}


void page_fault_handler(struct trapframe *tf)
{
    uint32_t fault_va;

    /* Read processor's CR2 register to find the faulting address */
    fault_va = rcr2();

    /* Handle kernel-mode page faults. */

    /* LAB 3: Your code here. */

    // If it's from the kernel, panic:
    if (!(tf->tf_err & 4)){
        if(fault_va > UTOP){
            //If  the kernel error is due to a print syscall must be checked
            panic("[KERN ]page_fault_handler(): kernel page fault!\n");
        }
        alloc_page_after_fault(fault_va, tf);
    }

    /* We've already handled kernel-mode exceptions, so if we get here, the page
     * fault happened in user mode. */


    // LAB 4 TEST AREA:
    // cprintf("curenv: %08x - fault_va: %08x\n", curenv, (void *)fault_va);
    /* So the page fault hander needs to...
        - is there an allocated for that?
            - There should be, so panic if lookup fails (right?)
            - walk the pgdir to retrieve the nonpresent pte
            - allocate w/ page_alloc() and write pa to the pte
    */ 

    // cprintf("page_fault_handler(): curenv == %x\n", curenv);

    // allocate the page 
    // print_trapframe(tf);

    // Check for protection fault:
    if(!(tf->tf_err & 1)) {
        alloc_page_after_fault(fault_va, tf);
    } else {
        struct vma* v = vma_lookup(curenv, (void *)fault_va);
        // if vma permission write we have a COW
        if(v && (v->perm & PTE_W)){
            if(!page_dedup(curenv, (void *)fault_va)){
                cprintf("[KERN]page_fault_handler: page dedup failed\n");
            }
            alloc_page_after_fault(fault_va, tf);
        }else{
            cprintf("[KERN] page_fault_handler(): write protection fault, killing env! addr: %08x\n", (void *)fault_va);
            kill_env(fault_va, tf);
        }
    }
}
