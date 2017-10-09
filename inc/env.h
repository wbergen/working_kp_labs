/* See COPYRIGHT for copyright information. */

#ifndef JOS_INC_ENV_H
#define JOS_INC_ENV_H

#include <inc/types.h>
#include <inc/trap.h>
#include <inc/memlayout.h>

typedef int32_t envid_t;

/*
 * An environment ID 'envid_t' has three parts:
 *
 * +1+---------------21-----------------+--------10--------+
 * |0|          Uniqueifier             |   Environment    |
 * | |                                  |      Index       |
 * +------------------------------------+------------------+
 *                                       \--- ENVX(eid) --/
 *
 * The environment index ENVX(eid) equals the environment's offset in the
 * 'envs[]' array.  The uniqueifier distinguishes environments that were
 * created at different times, but share the same environment index.
 *
 * All real environments are greater than 0 (so the sign bit is zero).
 * envid_ts less than 0 signify errors.  The envid_t == 0 is special, and
 * stands for the current environment.
 */

#define LOG2NENV        10
#define NENV            (1 << LOG2NENV)
#define ENVX(envid)     ((envid) & (NENV - 1))
#define NVMA            110        // preallocated vmas why 124? because they fit 
#define NKTHREADS   1
//Default Time Slice
#define TS_DEFAULT 100000000
#define ENV_IDX_MIN 0x1000
/* Anonymous VMAs are zero-initialized whereas binary VMAs
 * are filled-in from the ELF binary.
 */
enum {
    VMA_UNUSED,
    VMA_ANON,
    VMA_BINARY,
};

struct vma {
    int type;
    void *va;
    size_t len;
    int perm;
    /* LAB 4: You may add more fields here, if required. */
    struct vma *vma_link;   // Next VMAs pointer
    void *cpy_src;          // Copy source for binary vmas
    size_t src_sz;          // Copy source size (size on disk)
    size_t cpy_dst;         // Offset from Rounded va to copy at
    int hps;                // 1 if the vma based on huge pages
};

/* Values of env_status in struct env */
enum {
    ENV_FREE = 0,
    ENV_DYING,
    ENV_RUNNABLE,
    ENV_RUNNING,
    ENV_SLEEPING,
    ENV_NOT_RUNNABLE
};

/* Tasklet */
struct tasklet {
    int id;
    uint32_t *fptr;
    uint32_t count;
    int state;
    struct tasklet *t_next;
};

/* Tasklet state */
enum {
    T_FREE = 0,
    T_WORKING,
    T_DONE      //?
};


/* Special environment types */
enum env_type {
    ENV_TYPE_USER = 0,
    ENV_TYPE_IDLE,
    ENV_TYPE_KERNEL
};

struct env {
    struct trapframe env_tf;    /* Saved registers */
    struct env *env_link;       /* Next free env */
    envid_t env_id;             /* Unique environment identifier */
    envid_t env_parent_id;      /* env_id of this env's parent */
    enum env_type env_type;     /* Indicates special system environments */
    unsigned env_status;        /* Status of the environment */
    uint32_t env_runs;          /* Number of times environment has run */
    int env_cpunum;             /* The CPU that the env is running on */

    /*  VMA lists     */
    struct vma vmas[NVMA];       /* Array of preallocated VMAs */
    struct vma *free_vma_list;  /* List of free vmas */
    struct vma *alloc_vma_list; /* List of allocated VMAs */
    /* Address space */
    pde_t *env_pgdir;           /* Kernel virtual address of page dir */
    struct vma *env_vmas;       /* Virtual memory areas of this env. */

    /*Time Slice counter*/
    uint64_t time_slice;

    /* Wait pointer */
    envid_t wait_id;
};

#endif /* !JOS_INC_ENV_H */
