#include <inc/mmu.h>
#include <inc/x86.h>
#include <inc/assert.h>

#include <kern/pmap.h>
#include <kern/trap.h>
#include <kern/console.h>
#include <kern/monitor.h>
#include <kern/env.h>
#include <kern/syscall.h>

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


//Declare thee trap handler functions
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

    /*XXX set all the handlers*/


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
    cprintf("TRAP frame at %p\n", tf);
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

    // Syscall Ret:
    int ret;

    // Forward page faults to page_fault_handler:
    if (tf->tf_trapno == T_PGFLT){
        page_fault_handler(tf);
        return;
    }

    // If breakpoint, call monitor:
    else if (tf->tf_trapno == T_BRKPT){
        monitor(tf);
    }

    /*
      DEF: int32_t syscall(uint32_t num, uint32_t a1, uint32_t a2, uint32_t a3, uint32_t a4, uint32_t a5);
      num: syscall number (eax)
      a1-5: args
      return value -> trapframe's eax reg
      ADD specifications!
    */

    // Syscall Functionality:
    else if (tf->tf_trapno == T_SYSCALL){
        
        // Setup Args, syscall:
        ret = syscall(tf->tf_regs.reg_eax,
                    tf->tf_regs.reg_edx,
                    tf->tf_regs.reg_ecx,
                    tf->tf_regs.reg_ebx,
                    tf->tf_regs.reg_edi,
                    tf->tf_regs.reg_esi);

        tf->tf_regs.reg_eax = ret;
    }

    /* Unexpected trap: The user process or the kernel has a bug. */
    else if (tf->tf_cs == GD_KT) {
        print_trapframe(tf);
        panic("unhandled trap in kernel");
    } else {
        env_destroy(curenv);
        return;
    }
}

void trap(struct trapframe *tf)
{
    /* The environment may have set DF and some versions of GCC rely on DF being
     * clear. */
    asm volatile("cld" ::: "cc");

    /* Check that interrupts are disabled.
     * If this assertion fails, DO NOT be tempted to fix it by inserting a "cli"
     * in the interrupt path. */
    assert(!(read_eflags() & FL_IF));

    cprintf("Incoming TRAP frame at %p\n", tf);

    if ((tf->tf_cs & 3) == 3) {
        /* Trapped from user mode. */
        assert(curenv);

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

    /* Return to the current environment, which should be running. */
    assert(curenv && curenv->env_status == ENV_RUNNING);
    env_run(curenv);
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
        panic("page_fault_handler(): kernel page fault!\n");
    }

    /* We've already handled kernel-mode exceptions, so if we get here, the page
     * fault happened in user mode. */

    /* Destroy the environment that caused the fault. */
    cprintf("[%08x] user fault va %08x ip %08x\n",
        curenv->env_id, fault_va, tf->tf_eip);
    print_trapframe(tf);
    env_destroy(curenv);
}
