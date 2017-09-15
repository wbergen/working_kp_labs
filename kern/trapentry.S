/* See COPYRIGHT for copyright information. */

#include <inc/mmu.h>
#include <inc/memlayout.h>
#include <inc/trap.h>



###################################################################
# exceptions/interrupts
###################################################################

/* TRAPHANDLER defines a globally-visible function for handling a trap.
 * It pushes a trap number onto the stack, then jumps to _alltraps.
 * Use TRAPHANDLER for traps where the CPU automatically pushes an error code.
 *
 * You shouldn't call a TRAPHANDLER function from C, but you may
 * need to _declare_ one in C (for instance, to get a function pointer
 * during IDT setup).  You can declare the function with
 *   void NAME();
 * where NAME is the argument passed to TRAPHANDLER.
 */
#define TRAPHANDLER(name, num)                                                 \
    .globl name;            /* define global symbol for 'name' */              \
    .type name, @function;  /* symbol type is function */                      \
    .align 2;               /* align function definition */                    \
    name:                   /* function starts here */                         \
    pushl $(num);                                                              \
    jmp _alltraps

/* Use TRAPHANDLER_NOEC for traps where the CPU doesn't push an error code.
 * It pushes a 0 in place of the error code, so the trap frame has the same
 * format in either case.
 */
#define TRAPHANDLER_NOEC(name, num)                                            \
    .globl name;                                                               \
    .type name, @function;                                                     \
    .align 2;                                                                  \
    name:                                                                      \
    pushl $0;                                                                  \
    pushl $(num);                                                              \
    jmp _alltraps

.text

/*
 * Lab 3: Your code here for generating entry points for the different traps.
 */
/*

    0   DE no
    1   DB no
    2   NMI no
    3   BP no
    4   OF no
    5   BR no
    6   UD no
    7   NM no
    8   DF yes
    9   CSO no
    10  TS yes
    11  NP yes
    12  SS yes
    13  GP yes
    14  PF yes
    15  RES no
    16  MF no
    17  AC yes
    18  MC no
    19  XM no
    20  VE no
    21 - 31 res 
    32+ user defined
    48 system call no

*/
TRAPHANDLER_NOEC(trap_handler0_de,0);
TRAPHANDLER_NOEC(trap_handler1_db,1);
TRAPHANDLER_NOEC(trap_handler2_nmi,2);
TRAPHANDLER_NOEC(trap_handler3_bp,3);
TRAPHANDLER_NOEC(trap_handler4_of,4);
TRAPHANDLER_NOEC(trap_handler5_br,5);
TRAPHANDLER_NOEC(trap_handler6_ud,6);
TRAPHANDLER_NOEC(trap_handler7_nm,7);
TRAPHANDLER(trap_handler8_df,8);

TRAPHANDLER(trap_handler10_ts,10);
TRAPHANDLER(trap_handler11_np,11);
TRAPHANDLER(trap_handler12_ss,12);
TRAPHANDLER(trap_handler13_gp,13);
TRAPHANDLER(trap_handler14_pf,14);

TRAPHANDLER_NOEC(trap_handler16_mf,16);
TRAPHANDLER(trap_handler17_ac,17);
TRAPHANDLER_NOEC(trap_handler18_mc,18);
TRAPHANDLER_NOEC(trap_handler19_xm,19);


TRAPHANDLER_NOEC(trap_handler48_sc,48);

/*
 * Lab 3: Your code here for _alltraps
 */
_alltraps:
    pushl %ds
    pushl %es
    pushal

    push %eax
    movl $GD_KD, %eax
    mov %ax, %ds
    mov %ax, %es
    pop %eax

    push %esp
    call trap