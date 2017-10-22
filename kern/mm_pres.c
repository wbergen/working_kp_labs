
#include <inc/x86.h>
#include <inc/mmu.h>
#include <inc/error.h>
#include <inc/string.h>
#include <inc/assert.h>
#include <kern/ide.h>

#include <kern/env.h>
#include <kern/pmap.h>
#include <kern/trap.h>
#include <kern/sched.h>
#include <kern/cpu.h>
#include <kern/spinlock.h>

#include <kern/vma.h>
#include <kern/mm_pres.h>
#include <kern/bitmap.h>

int bad[NENV];
uint32_t f_sector = 1;

#define SIZE_SWAP_MAP (262144)					// 512*512 (128MB)

// Init one:
char swap_map[ARRAY_SIZE(SIZE_SWAP_MAP)] = {0};



/* END Bit "Map" impl. from https://gist.github.com/gandaro*/

/*
	This function assign a badness score to each active process and kills the winner
	return 1 if a process is killed to free space, 0 if failure
*/
int oom_kill(struct env *e, int pgs_r){

	struct env * kill = NULL;
	int i, theworst = 0;
	/* Code me */

	//initialize badness scores to 0
	for(i=0; i<NENV; i++){
		bad[i] = 0;
	}
	/*	Calculate the badness score for all the alloc process	*/
	/*
		b_score == (env_page_alloc/tot_pages)*100	+ (env_vma/tot_user_vma)*100 
		if env type is kernel score == 0
	*/
	for(i=0; i<NENV; i++){
		if( envs[i].env_type != ENV_TYPE_USER){
			bad[i] = 0;
		}else{
			bad[i] = (envs[i].env_alloc_pages / npages)*100;
		}
		if( bad[theworst] > bad[i]){
			theworst = i;
		} 	
	}
	if(bad[theworst] != 0 ){
		if(pgs_r > 0 && bad[theworst] >= pgs_r)
			kill = &envs[theworst];		
	}

	/*	Decide Who to kill*/
	if(kill && kill != e){
		/* The kernel god wants blood	*/
		lock_env();
		env_destroy(kill);
		unlock_env();
		return 1;
	}else{
		/* Killed nobody */
		return 0;
	}

}
/*
	This function swap in a page from the disk
*/
int page_in(struct tasklet *t){

	/*	
		We need to put the process that needs the page
		in SLEEPING state and awake it when the page is ready.
		This allow us not to have a blocking behaviour

		COW pages?

	// DONE AT TRAP:
	Will need pointer to env that faulted (for addr of pgdir)
	 - added pointer to env in tasklet; at tasklet creation, set to curenv
	On pagefault, we have a pte with NP set, and the value of sector_start in the entry
	 - Either reverse mappings, or walk everything...
	Sleep the caller (OR ANY ENV MAPPING THE PAGE, cow only, as cow is only time ref ct > 1)
	 - If a page in is required, sleep caller (should be done in trap.c)..
	alloc a page
	 - set the kva (page_alloc return) to tasklet's pi

	// DONE BY TASKLET ASYNC:
	Read a page starting at sector start into the addresss pointed to by page_alloc return


	// DONE AT TASKLET COMPLETION:
	Update the PTE in the faulting env's pg tables to new address, proper bits
	Wake the caller
	*/

	// cprintf("[KTASK] page_in called!\n");
    // char buf[PGSIZE]; // get page backing pg_out
    // buf is now a pointer (kva) to start of frame
    char * buf = (char *)page2kva(t->pi);


    // First invocation, set sector index:
    if (t->count == 0){
    	// Get the sector to start at from the PTE (here or in ktask.. sector_start must be set)
        cprintf("[KTASK] page_in(): STARTING. First sector to read == %u\n", t->sector_start);
        ide_start_read(t->sector_start, NSECTORS);
    }

    // If the disk is ready, call another write:
    if (t->count < NSECTORS){
        if (ide_is_ready()){
            cprintf("[KTASK] page_in(): READING.  Disk Ready!  Reading sector %u, toggling bit %u\n", t->count, t->sector_start + t->count);
            ide_read_sector(buf + t->count * SECTSIZE);

            // Remove the Bit Map bit representing this sector on disk
            toggle_bit(swap_map, t->sector_start + t->count);
            ++t->count;

            return 0;
        } else {
            cprintf("[KTASK] Disk Not ready, yielding...\n");
            return 0;
        }
    } else {
        // Done, can dequeue tasklet
        cprintf("[KTASK] page_in(): FINISHED. Read 8 sectors starting @ %u.\n", t->sector_start);
        
        // Update the PTE in requestor's pgdir
        /* !COW NB HERE! */
        
        pte_t * p = pgdir_walk(t->requestor_env->env_pgdir, t->fault_addr, 0);
        pte_t pre = *p;

        lru_ha_insert(t->pi);
        // Lookup VMA for correct pte perms:
        //struct vma * v = vma_lookup(t->requestor_env, t->fault_addr);
        // Setup correct PTE w/ vma perms:
        /* Reconstruct PTE */
        // Remove Global bit:
        *p ^= PTE_G;
    	// cprintf("[KTASK_PTE] PAGE IN. after REMOVING PTE_G: 0x%08x\n", *p);

        // Remove Available bit:
        *p ^= PTE_AVAIL;

    	// Set Present bit:
    	*p |= PTE_P;
    	// cprintf("[KTASK_PTE] PAGE IN. after SETTING PTE_P: 0x%08x\n", *p);

        // Clear high 20:
        *p &= 0x00000FFF;
		// cprintf("[KTASK_PTE] PAGE IN. after CLEARING high 20: 0x%08x\n", *p);

        // Set high 20 w/pa
        *p |= page2pa(t->pi);
        // cprintf("[KTASK_PTE] PAGE IN. after SETTING high 20: 0x%08x\n", *p);

        // COW:
        if (pre & PTE_AVAIL){
        	// For each env:
        	int i;
        	pte_t * found;
        	for (i = 0; i < NENV; ++i)
        	{
        		// Only Reasonable Envs:
		        if(envs[i].env_status == ENV_RUNNING || envs[i].env_status == ENV_RUNNABLE || envs[i].env_status == ENV_SLEEPING){
		        
		        	// If a match is found, update with new PA, flags:
		        	found = seek_pte(&pre, &envs[i]);
		        	if (found) {
		        		*found = *p;
		        	}
		        }
        	}
        }

   	    cprintf("[KTASK_PTE] PAGE IN DONE. PTE: 0x%08x -> 0x%08x\n", pre, *p);
       	cprintf("[KTASK] page_in(): reset pte: 0x%08x\n", *p);

       	t->requestor_env->env_status = ENV_RUNNABLE;


        // Return status indicates completed:
        return 1;
    }

    // Catch Bizzarities:
	return 1;
}


/*
	This function returns the index of first 0 in swap_map
	First 0 will represent first page sized hole (AS LONG AS all r/w are at page granularity)
	Will Return 0 on failure, index on success
*/
uint32_t find_swap_spot(){
	int i;
	for (i = 1; i < SIZE_SWAP_MAP; ++i)
	{
		if (get_bit(swap_map, i) == 0){
			return i;
		}
	}
	// Failure:
	cprintf("[KTASK] find_swap_spot() couldn't find a spot!\n");
	return 0;
}

/*
	This function swaps out a page from the disk
*/
int page_out(struct tasklet *t){

	/* Code me */
	/*
		We need a buffer page to swap the page progressively
		on the disk. This allow us not to have a blocking behaviour
		
		COW pages? 
	*/

   	// print_swapmap(swap_map, 128);

	// Can always set these the same:

    char * buf = (char *)page2kva(t->pi);

    // First invocation, set sector index:
    if (t->count == 0){
    	t->sector_start = find_swap_spot();
        ide_start_write(t->sector_start, NSECTORS);
        cprintf("[KTASK] page_out(): STARTING. swap_spot found @ %u\n", t->sector_start);
    }

    // While we have work to do, check ff the disk is ready & call another write:
    if (t->count < NSECTORS){
        if (ide_is_ready()){
            cprintf("[KTASK DB] page_out(): WRITING. Disk Ready!  writing sector %u... Toggling bit %u task %d\n", t->count, t->sector_start + t->count, t->id);
            ide_write_sector(buf + t->count * SECTSIZE);
            
            // Set the according bit in Bit Map
            toggle_bit(swap_map, t->sector_start + t->count);
            ++t->count;

            return 0;
        } else {
            cprintf("[KTASK] page_out(): Disk Not ready, yielding...\n");
            return 0;
        }
    } else {
        // All done writing:
        cprintf("[KTASK] page_out(): FINISHED. Wrote 8 sectors starting from sector %u.\n", t->sector_start);

        // Here, or in kTask need to change all PTEs to hold t->sector start
        /* Need to update the PTE of pi and save the sector_start value into it */
        // COW NOT GONNA WORK
        // The page has been free while swapping it out
		if(t->pi->pp_ref == 0){
			if (!(t->pi->page_flags & ALLOC)){
				toggle_bit(swap_map, t->sector_start);
				return 1;	
			} else {
	       		panic("page out finished but page with ref: %d and marked as alloc\n",t->pi->pp_ref);
			}
       	}

 
        pte_t * p = pgdir_walk(t->requestor_env->env_pgdir, t->fault_addr, 0);
        pte_t pre;
COW:
        pre = *p;
        if(p){
        	// *p &= 0x0;	// clear it
        	// cprintf("[KTASK_PTE] PAGE OUT. before REMOVING PTE_P: 0x%08x\n", *p);

        	// Remove Present Flag:
        	*p ^= PTE_P;
        	// cprintf("[KTASK_PTE] PAGE OUT. after REMOVING PTE_P: 0x%08x\n", *p);
        	// Clear high 20:
        	*p &= 0x00000FFF;
        	// cprintf("[KTASK_PTE] PAGE OUT. after clearing high 20: 0x%08x\n", *p);
        	// Set high 20 w/ sector offset:
      		*p |= ((t->sector_start << 12));
      		// cprintf("[KTASK_PTE] PAGE OUT. after SETTING high 20: 0x%08x\n", *p);
      		// Set Global Flag:
        	*p |= PTE_G;

	       	if(t->pi->pp_ref > 1){
	       		p = find_pte_all(t->pi, &t->requestor_env, t->fault_addr);
	       		goto COW;
	       	}else{
	       		t->pi->pp_ref--;
	       	}
        	// cprintf("[KTASK_PTE] PAGE OUT. after SETTING PTE_G: 0x%08x\n", *p);
        	page_free(t->pi);
		    cprintf("[KTASK_PTE] PAGE OUT QUEUED. PTE: 0x%08x -> 0x%08x\n", pre, *p);
     		
        }else{
        	//cprintf("panic pte: %x %x\n", *ppte, page2pa(t->pi));
        	panic("panic, CANNOT FIND THE PTE AFTER PAGEOUT %d ref:%x lru:%x link:%x\n",t->pi->pp_ref,t->pi->lru_link, t->pi->pp_link, t->pi);    	
        }

      	// print_swapmap(128);

      	// Return status indicating done!
        return 1;
    }

    // Catch Bizzarities:
	return 1;
}
/*
	This function manage the active and inactive LRU lists

	struct lru {
	    struct page_info * active;
	    struct page_info * inactive;
	    struct page_info * zswap; 
	};
	lru_lists is the structure tu use
*/
int lru_manager(){

	/* Code me */

	/*	
		GENERAL DOUBTS:
			Inactive pages become active on PF???
		ACTIVE LIST:
			all pages	

		INACTIVE LIST:


		WHEN TO MOVE:
			periodically lru_manager moves the entries in the tail of ACTIVE
			in INACTIVE list.
			When the active list is above a certain threshold start balancing the lists
			Lists Ratio? Pick un a fixed ration (1:1) (simple solution)

		SECOND CHANCE:
			Both lists managed FIFO.
			For each visited page in:
				○ If R=0 then replace page
				○ If R=1 then set R=0 and move page to tail

			which bit to use?
			1 bit to mark a page as READ
			1 bit to mark a page as Second Chance (MAYBE NOT)
			how to set them?
			SC bit set the first time we try to replace a page (MAYBE NOT)
			READ bit.... set by the MMU?
	*/
	// if the active list is 
	// cprintf("[LRU][ML] OUT active:%d inactive:%d \n",lru_active_count, lru_inactive_count);
	if(lru_active_count >= MIN_ALRU_SZ){

		struct page_info * p;
		// cprintf("[LRU][ML] B active:%d inactive:%d \n",lru_active_count, lru_inactive_count);
		lock_pagealloc();
		while((lru_active_count - MIN_ALRU_SZ) > (lru_inactive_count/BL_LRU_RATIO)){
			//cprintf("[LRU][ML] MOVING active:%d inactive:%d \n",lru_active_count, lru_inactive_count);
			/*	if p access bit  0	*/
			/*	move the element to the iactive list*/

			lru_ta_remove(&p);

			//print_lru_active();
			//print_lru_inactive();
			
			lru_ti_insert(p);
			//print_lru_active();
			//print_lru_inactive();
			//print_lru_inactive();
		}
		unlock_pagealloc();
	}
		cprintf("[USER]                                           A active:%d inactive:%d \n",lru_active_count, lru_inactive_count);
	return 1;
}
/*
	This function tries to reclaim a n amount of pages
	returns 0 if sucess or the number if the pages still to free  
*/
int reclaim_pgs(struct env *e, int pg_n){

	/* Code me */
	int pg_c = pg_n;
	struct page_info *pp;
	struct tasklet * t = NULL;
	
	/*	Swap enough inactive pages */
	//struct tasklet * task_get(struct tasklet ** list){
	//void task_add(struct tasklet *t, struct tasklet **list, int free){
	while(pg_c > 0){
		//cprintf("Remove page inactive count: %d \n", lru_inactive_count);
		lock_pagealloc();
		lru_hi_remove(&pp);
		unlock_pagealloc();
		if(pp != NULL){

			t = task_get_free();
			if(t){
				uint32_t fva = 0;
				find_pte_all(pp, &t->requestor_env, &fva);
				if(t->requestor_env == NULL || fva == 0){
					panic("OMG env %x fva: %x lookingfor: %x\n",t->requestor_env, fva, page2pa(pp));
				}
		        t->state = T_WORK;
		        t->fptr = (uint32_t *)page_out;
		        t->pi = pp;
		        t->fault_addr = (uint32_t *)fva;
	            // t->sector_start = f_sector;
	            t->count = 0;
	            // Decerement pages to swap
				cprintf("[KTASK DB] Work being prepared on task %d, faulting addr: %x\n",t->id,t->fault_addr);

	            task_add_alloc(t);
	            pg_c--;

		    }else{
		    	break;
		    }
		}

	}
	/*	Compress pages?		*/
	/*		OR				*/
	/* Deduplicate pages	*/

	/* KILL KILL KILL */
	if(pg_c > 0){
		if(oom_kill(e, pg_c))
			pg_c = 0;
	}
	return pg_c;
}

/*		BONUSES			*/

void compress_pgs(){
	return;
}

void dedup_pages(){
	return;
}

