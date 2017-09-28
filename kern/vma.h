
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
int vma_new(struct env * e, void *va, size_t len, int type, char * src, size_t filesize, size_t cpy_dst, int perm, struct vma ** vma_store);

/*
    Lookup in the allocated vma if the va is mapped

    return the vma if success, NULL if not
*/
struct vma * vma_lookup(struct env *e, void *va);


/*
    This function removes all the allocated pages in a vma
*/
void vma_remove_pages(struct env *e, void * va, size_t size);

/*
    This function populate the pages spanning a vma

    return 1 if success, 0 if errors
*/

int vma_populate(void * va, size_t size, int perm, int hp);

/*
    Remove vma from the alloc list
    Must maintain links in the list
    Must append the vma to the free list

*/

/*
    the function checks if the va + size specified spans the vma;

    returns 1 if success, 0 if errors
*/
int vma_size_check(void * va, size_t size, struct vma * v);

int vma_remove_alloced(struct env *e, struct vma *vmad, int destroy_pages);

/*

    The function given a va and a size finds the right vma and,
    in case the va and the size lies inside a valid vma, it splits it in multiple vmas

    It returns the new vma or if nothing was splitted the looked up one.
    returns null in case of errors
*/
struct vma * vma_split_lookup(struct env *e, void *va, size_t size, int vma_remove);


/*
    This function merge 2 vmas
    return 0 if success -1 if errors occur
*/
int vma_merge(struct env * e, struct vma *v1, struct vma * v2);

/*
    This function merge consecutive vma with the same permissions
    if presents in the alloc_vma_list

    return 0 if success, -1 if any errors occur
*/
int vma_list_merge(struct env * e);

/*
    This function change the permission of a vma and all of its allocated pages

    returns 1 if succes, 0 if errors (no 0 return for now)
*/
int vma_change_perm(struct vma *v, int perm);

/*
    It applies a consistency check on a vma
*/
int vma_consistency_check(struct vma * v, int type);

/*
    Print the vma data
*/
void print_all_vmas(struct env *e);
#endif  /* !JOS_INC_LIB_H */