/* System call stubs. */

#include <inc/syscall.h>
#include <inc/lib.h>
#include <inc/error.h>

static inline int32_t syscall(int num, int check, uint32_t a1, uint32_t a2,
        uint32_t a3, uint32_t a4, uint32_t a5)
{
    int32_t ret;

    /*
     * Generic system call: pass system call number in AX,
     * up to five parameters in DX, CX, BX, DI, SI.
     * Interrupt kernel with T_SYSCALL.
     *
     * The "volatile" tells the assembler not to optimize
     * this instruction away just because we don't use the
     * return value.
     *
     * The last clause tells the assembler that this can
     * potentially change the condition codes and arbitrary
     * memory locations.
     */

    asm volatile("int %1\n"
        : "=a" (ret)
        : "i" (T_SYSCALL),
          "a" (num),
          "d" (a1),
          "c" (a2),
          "b" (a3),
          "D" (a4),
          "S" (a5)
        : "cc", "memory");

    if(check && ret > 0)
        panic("syscall %d returned %d (> 0)", num, ret);

    return ret;
}

void sys_cputs(const char *s, size_t len)
{
    syscall(SYS_cputs, 0, (uint32_t)s, len, 0, 0, 0);
}

int sys_cgetc(void)
{
    return syscall(SYS_cgetc, 0, 0, 0, 0, 0, 0);
}

int sys_env_destroy(envid_t envid)
{
    return syscall(SYS_env_destroy, 1, envid, 0, 0, 0, 0);
}

envid_t sys_getenvid(void)
{
     return syscall(SYS_getenvid, 0, 0, 0, 0, 0, 0);
}

void *sys_vma_create(uint32_t size, int perm, int flags)
{
    /* LAB 4: Your code here */
    // static void *sys_vma_create(size_t size, int perm, int flags)
    return (void *)syscall(SYS_vma_create, 0, size, perm, flags, 0, 0);

    // return NULL;
}

int sys_vma_destroy(void *va, size_t size)
{
    /* LAB 4: Your code here */
    //static int sys_vma_destroy(void *va, size_t size)
    return syscall(SYS_vma_destroy, 0, (uint32_t)va, size, 0, 0, 0);


    // return -E_NO_SYS;
}
