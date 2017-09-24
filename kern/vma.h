
#ifndef JOS_KERN_VMA_H
#define JOS_KERN_VMA_H
#ifndef JOS_KERNEL
# error "This is a JOS kernel header; user programs should not #include it"
#endif

#include <kern/vma.h>

/*
    Initialize Process VMAs
*/
void vma_proc_init(struct env *e);

/*
    Remove the fist element of a vma list
*/
struct vma * vma_remove_head(struct vma **list);

/*
    Insert an element in a vma list
        If ordered is set insert the vma in an ordered fashion (order by va)
        If ordered is not set add the element as new head of the list
*/
void vma_insert( struct vma * el, struct vma **list, int ordered);


/*
    Create a new VMA:
    Contraints:
        va need to be page alligned
        va + len doesn't need to be page alligned
        No physical frame is allocated by this function
        I suppose the va and the len is not mapped by any vma

    return 1 if success, 0 if out of memory, -1 for any errors
*/
int vma_new(struct env * e, void *va, size_t len, int type, char * src, size_t filesize, int perm);

/*
    Lookup in the allocated vma if the va is mapped

    return the vma if success, NULL if not
*/
struct vma * vma_lookup(struct env *e, void *va);

#endif  /* !JOS_INC_LIB_H */