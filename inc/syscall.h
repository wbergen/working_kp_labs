#ifndef JOS_INC_SYSCALL_H
#define JOS_INC_SYSCALL_H

/* system call numbers */
enum {
    SYS_cputs = 0,
    SYS_cgetc,
    SYS_getenvid,
    SYS_env_destroy,
    SYS_vma_create,
    SYS_vma_destroy,
    SYS_vma_protect,
    SYS_vma_advise,
    NSYSCALLS
};

#endif /* !JOS_INC_SYSCALL_H */
