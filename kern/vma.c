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
#include <kern/pmap.h>

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

    cprintf("[VMA] vma_remove_head(): returning head of %x\n", list);
    struct vma * el;
    
    // check if the list is empty
    if(*list == NULL){
        return NULL;
    }

    // cprintf("[VMA] vma_remove_head(): list == %x\n", list);

    // Save old first element:
    el = *list;

    // Set the list pointer to first element's link:
    *list = el->vma_link;

    // Remove old first element's link:
    el->vma_link = NULL;

    // cprintf("[VMA] vma_remove_head(): el == %x\n", el);


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

    cprintf("[VMA] vma_insert(): inserting vma...\n");

    // Handling corner case list NULL -> insert the element in the head
    // Handling corener case  element < than the first element in the list
    if(!*list ||  (vma_i->va > el->va)){
        ordered=0;
    }

    if(ordered){
        // Ordered insert
        // We need to find the first vma with the va < new_el.va
        while(vma_i){
            // cprintf("vma_i->va: %x vma_i->vma_link: %x\n", vma_i->va, vma_i->vma_link);
            // If we find the first element with va < new_el.va break
            if(vma_i->va > el->va){
                //cprintf("to attach: %x old va: %x new va: %x\n",vma_old->va, vma_i->va,el->va);
                break;
            }
            vma_old = vma_i;
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
int vma_new(struct env * e, void *va, size_t len, int type, char * src, size_t filesize,size_t cpy_dst, int perm){

    struct vma * new;

    // Round up the vma len:
    len = ROUNDUP(len, PGSIZE);

    cprintf("[VMA] vma_new(): trying to allocate new vma @ %x\n", va);

    // Return fail if BINARY && no src:
    if ((type == VMA_BINARY) && ((src == NULL) || (filesize == 0))) {
        cprintf("[VMA] vma_new(): type is binary, but no src address set.\n");
        return -1;
    }

    // Return error if va it's not page alligned
    if(((uint32_t)va % PGSIZE) != 0){
        cprintf("vma_new(): the va is not page alligned\n");
        return -1;
    }



    // Remove a vma from the free list
    new = vma_remove_head(&e->free_vma_list);

    // If out of vma return 0
    if(!new){
        cprintf("[VMA] vma_new: out of memory, no more vmas available\n");
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
        new->cpy_dst = cpy_dst;


    // Insert the page in the alloc list
    vma_insert(new, &e->alloc_vma_list, 1);
    // vma_print(e);
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

        if(va >= vma_i->va && va < (vma_i->va + vma_i->len) ){
            return vma_i;
        }
        vma_i = vma_i->vma_link;
    }

    return NULL;

}


void print_all_vmas(struct env * e){
    struct vma * temp = e->alloc_vma_list;

    while (temp){
        cprintf("[0x%08x][%u][0x%08x <-> 0x%08x] (len: %u) -> [0x%08x] B:[cpy_src: %x, cp_size: %u]\n", \
         temp, temp->type, temp->va, temp->va+temp->len, temp->len, temp->vma_link, temp->cpy_src, temp->src_sz);
        temp = temp->vma_link;
    }
}

/*
    Remove vma from the alloc list
    Must maintain links in the list
    Must append the vma to the free list
    1 success, 0 failure

*/

int vma_remove_alloced(struct env *e, struct vma *vmad, int destroy_pages){
    // Find the vma in the list (to get the previous element)
    // struct vma * previous_vma = e->alloc_vma_list

    struct vma *vma_i = e->alloc_vma_list;
    struct vma *previous_vma = e->alloc_vma_list;
    int ct = 0;

    while(vma_i){

        // Check if vma is correct:
        if ((vma_i->va == vmad->va) && (vma_i->len == vmad->len)){

            if(destroy_pages){
                // Remove page entries:
                int i;
                for (i = 0; i < ROUNDUP(vma_i->len, PGSIZE)/PGSIZE; ++i){
                    // Need to check for the presence of a page...
                    pte_t * pte = pgdir_walk(e->env_pgdir, vma_i->va+i*PGSIZE, 0);

                    // Ensure a mapping:
                    if (!pte){
                        break;
                    }

                    // Only remove PTE_P pages:
                    if (*pte & PTE_P) {
                        page_remove(e->env_pgdir, vma_i->va+i*PGSIZE);
                    }
                }
            }

            // Check if it's the head of the list:
            if (ct == 0) {
                e->alloc_vma_list = vma_i->vma_link;
            }

            // Remove vma from list by linking previous to next:
            previous_vma->vma_link = vma_i->vma_link;

            
            // Default vma, and add to free list:
            vma_i->type = VMA_UNUSED;
            vma_i->va = 0;
            vma_i->len = 0;
            vma_i->perm = 0;

            // Add the found vma to the free list:
            // New head's link -> old head:
            vma_i->vma_link = e->free_vma_list;

            // Head -> newly freed vma:
            e->free_vma_list = vma_i;

            cprintf("[VMA] vma_remove_alloced(): Found and removed vma!\n");

            return 1;
        }


        // Save the current
        previous_vma = vma_i;
        vma_i = vma_i->vma_link;
        ct++;
        
    }
    return 0;
}
/*

    The function given a va and a size finds the right vma and,
    in case the va and the size lies inside a valid vma it split it in multiple vmas

    It returns 1 (vma_remove set) the splitted vma (vma_remove not set) if success, 
    null if errors or if no vma is found
*/
struct vma * vma_split_lookup(struct env *e, void *va, size_t size, int vma_remove){

    //lookup
    struct vma * vmad = vma_lookup(curenv, va);

    // If the lookup fails return null
    if(!vmad){
        return vmad;
    }

    // save splitting information:
    void * vmad_va = vmad->va;
    uint32_t vmad_len = vmad->len;
    int vmad_type = vmad->type;
    int vmad_perm = vmad->perm;


    //Round down the va and size
    //void * va_sup = va;
    //va = (void *) ROUNDDOWN((uint32_t)va, PGSIZE);
    //size += (size_t) (va_sup - va);
    //size = ROUNDUP(size,PGSIZE);

    // Check if it's a anon vma
    if(vmad->type != VMA_ANON){
        cprintf("[VMA] vma_split_lookup: this operation shouldn't be done for binary mappings\n");
        return NULL; 
    }
    // if it spans multiple vmas kill the process that initiated the operation
    if((size_t)va + size > (size_t)vmad_va + vmad->len){
        cprintf("[VMA] vma_split_lookup: the vma to split spans multiples vmas\n\n Killing the process...\n");
        // env_destroy(curenv);
        return NULL;
    }
    if(vma_remove){
        // Since we've saved the bookkeeping, remove now:
        if (vma_remove_alloced(e, vmad, 1) < 1){
            cprintf("[VMA] vma_split_lookup(): vma removal failed!\n");
            // print_all_vmas(e);
            // return NULL;
        }
    }

    // Case 1: if "va" is greater than "vmad->va" split the first part of the vma
    if((size_t)va > (size_t)vmad_va){

        void * va_t = vmad_va;
        size_t size_tem = ((size_t)va - (size_t)vmad_va);

        if(!vma_remove){
            //update the vma 
            vmad->va = va;
            vmad->len = vmad->len - size_tem;
        }

        //create a new vma from the splited part
        vma_new(e, va_t, size_tem, vmad_type, NULL, 0, 0, vmad_perm);
    }

    //Case 2: if va + size is grater than vmad->va + vmad->len split the second part of the vma
    if((size_t)(va + size) < (size_t)vmad_va + vmad_len){

        void * va_t = va + size;
        size_t size_tem = vmad_len - ( (size_t)va_t - (size_t)vmad_va );

        if(!vma_remove){
        //update the vma
            vmad->len = vmad->len - size_tem;
        }
        //create a new vma from the splited part    
        vma_new(e, va_t, size_tem, vmad_type, NULL, 0, 0, vmad_perm);
    }

    if(vma_remove){
        return (void *)1;
    }else{
        return vmad;
    }

}
/*
    This function change the permission of a vma and all of its allocated pages

    returns 1 if succes, 0 if errors (no 0 return for now)
*/
int vma_change_perm(struct vma *v, int perm){

    struct env * e = curenv;
    //first change the permission of the vma
    v->perm = perm;

    //second change the permission of all the allocated pages accordingly
    int i;
    for (i = 0; i < ROUNDUP(v->len, PGSIZE)/PGSIZE; ++i){

        // Need to check for the presence of a page...
        pte_t * pte = pgdir_walk(e->env_pgdir, v->va+i*PGSIZE, 0);
        struct page_info * pp;

        // Ensure a mapping:
        if (!pte){
            break;
        }

        // Only change perm PTE_P pages:
        if (*pte & PTE_P) {
            // find the page_info
            pp = page_lookup(e->env_pgdir, v->va+i*PGSIZE, NULL);
            if(!pp){
                cprintf("vma_change_perm: page lookup fail\n");
                break;
            }
            //use page insert to change permission (re inserting the same element)
            if(page_insert(e->env_pgdir, pp, v->va+i*PGSIZE, perm) != 0){
                cprintf("vma_change_perm: page insert fail\n");
            }
        }
    }

    //page_insert(pde_t *pgdir, struct page_info *pp, void *va, int perm)
    //struct page_info *page_lookup(pde_t *pgdir, void *va, pte_t **pte_store)
    return 1;

}
/*
    This function merge 2 vmas
    returns 0 if success -1 if errors occur
*/
int vma_merge(struct env * e, struct vma *v1, struct vma * v2){
    
    v1->len += v2->len;

    if(vma_remove_alloced(e, v2, 0)){
        return 0;
    }else{
        return -1;
    }


}

/*
    This function merge consecutive vma with the same permissions
    if presents in the alloc_vma_list

    return 0 if success, -1 if any errors occur
*/
int vma_list_merge(struct env * e){

    if(!e){
        return -1;
    }

    struct vma *vma_old = e->alloc_vma_list;

    // if the alloc_vma_list is null nothing to do
    if (!vma_old)
    {
        return 0;
    }
    struct vma * vma_i = vma_old->vma_link;

    // if also the second element in the alloc_vma_list is null nothing to do
    if(!vma_i){
        return 0;
    }

    // Iterate the list
    while(vma_i){
        // if two vma are consecutive and with the same permission and not BINARY merge
        if((vma_old->va + vma_old->len) == vma_i->va && vma_old->perm == vma_i->perm
            && vma_old->type != VMA_BINARY && vma_i->type != VMA_BINARY){

            if(vma_merge(e,vma_old,vma_i) != 0){
                return -1;
            }
        }

        // update pointers
        vma_old = vma_i;
        vma_i = vma_i->vma_link;
    }

    return 0;
}
