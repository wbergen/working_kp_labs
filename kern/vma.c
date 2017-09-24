#include <inc/x86.h>
#include <inc/mmu.h>
#include <inc/error.h>
#include <inc/string.h>
#include <inc/assert.h>
#include <inc/elf.h>

#include <kern/env.h>
#include <kern/pmap.h>
#include <kern/trap.h>
#include <kern/monitor.h>

#include <kern/vma.h>

/*
    Initialize Process VMAs
*/
void vma_proc_init(struct env *e){

    int i;

    // Initialize the vma list pointers
    e->free_vma_list = NULL;
    e->alloc_vma_list = NULL;

    //NVMA -1 or NVMA? 
    for (i = (NVMA - 1); i >= 0; i--) {
        //Mark the vma as VMA_UNUSED and 0 the remaining fields
        e->vmas[i].type = VMA_UNUSED;
        e->vmas[i].va = 0;
        e->vmas[i].len = 0;
        e->vmas[i].perm = 0;

        //Add the vma to the free_vma_list
        e->vmas[i].vma_link = e->free_vma_list;
        e->free_vma_list = &e->vmas[i];
    }

    // cprintf("vma_proc_init(): e's free list == %x\n", e->free_vma_list);
}

/*
    Remove the fist element of a vma list
*/
struct vma * vma_remove_head(struct vma **list){

    cprintf("[DEBUG] vma_remove_head(): INITAL ARG == %x\n", list);
    struct vma * el;
    
    // check if the list is empty
    if(*list == NULL){
        return NULL;
    }

    cprintf("[DEBUG] vma_remove_head(): list == %x\n", list);

    // Save old first element:
    el = *list;

    // Set the list pointer to first element's link:
    *list = el->vma_link;

    // Remove old first element's link:
    el->vma_link = NULL;

    cprintf("[DEBUG] vma_remove_head(): el == %x\n", el);


    return el;
}

/*
    Insert an element in a vma list
        If ordered is set insert the vma in an ordered fashion (order by va)
        If ordered is not set add the element as new head of the list
*/
void vma_insert( struct vma * el, struct vma **list, int ordered){

    struct vma * vma_i = *list;   // list iterator
    struct vma * vma_old = *list; // we append the new element to this one

    cprintf("vma_insert(): inserting vma!\n");

    // Handling corner case list NULL -> insert the element in the head 
    if(!*list){
        ordered=0;
    }

    if(ordered){
        // Ordered insert
        // We need to find the first vma with the va < new_el.va
        while(vma_i){

            vma_old = vma_i;
            // If we find the first element with va < new_el.va break
            if(vma_i->va < el->va){
                break;
            }

            vma_i = vma_i->vma_link;
        }

        // Insert the lement
        el->vma_link = vma_old->vma_link;
        vma_old->vma_link = el;

    }else{
        // Head insert
        el->vma_link = *list;
        *list = el;
    }
}


/*
    Create a new VMA:
    Contraints:
        va need to be page alligned
        va + len doesn't need to be page alligned
        No physical frame is allocated by this function
        I suppose the va and the len is not mapped by any vma

    return 1 if success, 0 if out of memory, -1 for any errors
*/
int vma_new(struct env * e, void *va, size_t len, int type, char * src, size_t filesize, int perm){

    struct vma * new;

    cprintf("trying to allocate new vma @ %x\n", va);

    // Return fail if BINARY && no src:
    if ((type == VMA_BINARY) && ((src == NULL) || (filesize == 0))) {
        cprintf("vma_new(): type is binary, but no src address set.\n");
        return -1;
    }

    // Return error if va it's not page alligned
    // if(((uint32_t)va % PGSIZE) != 0){
    //     cprintf("vma_new(): the va is not page alligned\n");
    //     return -1;
    // }

    // Remove a vma from the free list
    new = vma_remove_head(&e->free_vma_list);

    // If out of vma return 0
    if(!new){
        cprintf("vma_new: out of memory, no more vmas available\n");
        return 0;
    }

    // Initialize the new vma
    new->type = type;
    new->va = va;
    new->len = len;
    new->perm = perm;

    if (type == VMA_BINARY)
        new->cpy_src = src;
        new->src_sz = filesize;


    // Insert the page in the alloc list
    vma_insert(new, &e->alloc_vma_list, 1);

    // Success
    return 1;
}

/*
    Lookup in the allocated vma if the va is mapped

    return the vma if success, NULL if not
*/
struct vma * vma_lookup(struct env *e, void *va){

    struct vma *vma_i = e->alloc_vma_list;

    while(vma_i){

        if(va >= vma_i->va && va <= (vma_i->va + vma_i->len) ){
            return vma_i;
        }
        vma_i = vma_i->vma_link;
    }

    return NULL;

}