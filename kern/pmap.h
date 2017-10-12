/* See COPYRIGHT for copyright information. */

#ifndef JOS_KERN_PMAP_H
#define JOS_KERN_PMAP_H
#ifndef JOS_KERNEL
# error "This is a JOS kernel header; user programs should not #include it"
#endif

#include <inc/memlayout.h>
#include <inc/assert.h>

#define NTASKS 8
struct env;

extern char bootstacktop[], bootstack[];

extern struct page_info *pages;
extern size_t npages;
extern struct tasklet *t_list, *t_flist;
extern pde_t *kern_pgdir;


extern uint32_t free_pages_count;

/* This macro takes a kernel virtual address -- an address that points above
 * KERNBASE, where the machine's maximum 256MB of physical memory is mapped --
 * and returns the corresponding physical address.  It panics if you pass it a
 * non-kernel virtual address.
 */
#define PADDR(kva) _paddr(__FILE__, __LINE__, kva)

static inline physaddr_t _paddr(const char *file, int line, void *kva)
{
    if ((uint32_t)kva < KERNBASE)
        _panic(file, line, "PADDR called with invalid kva %08lx", kva);
    return (physaddr_t)kva - KERNBASE;
}

/* This macro takes a physical address and returns the corresponding kernel
 * virtual address.  It panics if you pass an invalid physical address. */
#define KADDR(pa) _kaddr(__FILE__, __LINE__, pa)

static inline void *_kaddr(const char *file, int line, physaddr_t pa)
{
    if (PGNUM(pa) >= npages)
        _panic(file, line, "KADDR called with invalid pa %08lx", pa);
    return (void *)(pa + KERNBASE);
}


enum {
    /* For page_alloc, zero the returned physical page. */
    ALLOC_ZERO = 1<<0,
    ALLOC_HUGE = 1<<1,
    ALLOC_PREMAPPED = 1<<2,
    ALLOC = 1<<4,
    POISON_AFTER_FREE = 1<<5,
};


enum {
    /* For pgdir_walk, tells whether to create normal page or huge page */
    CREATE_NORMAL = 1<<0,
    CREATE_HUGE   = 1<<1,
};

void mem_init(void);
void page_init(void);
struct page_info *page_alloc(int alloc_flags);
void page_free(struct page_info *pp);
int page_insert(pde_t *pgdir, struct page_info *pp, void *va, int perm);
void page_remove(pde_t *pgdir, void *va);
struct page_info *page_lookup(pde_t *pgdir, void *va, pte_t **pte_store);
void page_decref(struct page_info *pp);

void tlb_invalidate(pde_t *pgdir, void *va);

void *mmio_map_region(physaddr_t pa, size_t size);

int  user_mem_check(struct env *env, const void *va, size_t len, int perm);
void user_mem_assert(struct env *env, const void *va, size_t len, int perm);

void task_add(struct tasklet *t, struct tasklet **list, int free);
struct tasklet * task_get(struct tasklet ** list);
/*
    This function deduplicate if needed a physical page

    Returns 1 if succes, 0 if failure
*/
int page_dedup(struct env * e, void * va);

void task_add_free(struct tasklet *t);

static inline physaddr_t page2pa(struct page_info *pp)
{
    return (pp - pages) << PGSHIFT;
}

static inline struct page_info *pa2page(physaddr_t pa)
{   
    if (PGNUM(pa) >= npages)
        panic("pa2page called with invalid pa pg:%d max:%d", PGNUM(pa), npages);
    return &pages[PGNUM(pa)];
}

static inline void *page2kva(struct page_info *pp)
{
    return KADDR(page2pa(pp));
}

pte_t *pgdir_walk(pde_t *pgdir, const void *va, int create);

#endif /* !JOS_KERN_PMAP_H */
