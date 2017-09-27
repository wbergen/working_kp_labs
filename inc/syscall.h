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
    SYS_yield,
    SYS_wait,
    SYS_fork,
    NSYSCALLS
};
/*	memory advise flags*/
enum {
	MADV_DONTNEED = 0,
	MADV_WILLNEED
	};

#endif /* !JOS_INC_SYSCALL_H */
