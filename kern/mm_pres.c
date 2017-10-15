
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
int bad[NENV];

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
int page_in(struct page_info *pg_in){

	/* Code me */

	/*	
		We need to put the process that needs the page
		in SLEEPING state and awake it when the page is ready.
		This allow us not to have a blocking behaviour

		COW pages?
	*/
	return 1;
}
/*
	This function swaps out a page from the disk
*/
// void page_out(struct page_info* pg_out, struct tasklet* t){
int page_out(){

	/* Code me */
	/*
		We need a buffer page to swap the page progressively
		on the disk. This allow us not to have a blocking behaviour
		
		COW pages? 
	*/

	cprintf("[KTASK] page_out called!\n");

    int nsectors = PGSIZE/SECTSIZE;
    char buf[PGSIZE]; // get page backing pg_out

    // First invocation:
    if (t->count == 0){
        ide_start_write(1, nsectors);
    }

    // If the disk is ready, call another write:
    if (t->count < nsectors){
        if (ide_is_ready()){
            cprintf("[KTASK] Disk Ready!  writing sector %u...\n", t->count);
            ide_write_sector(buf + t->count * SECTSIZE);
            ++t->count;
            return 0;
        } else {
            cprintf("[KTASK] Disk Not ready, yielding...\n");
            return 0;
        }
    } else {
        // Done, can dequeue tasklet
        cprintf("[KTASK] No work left, Dequeuing tasklet...\n");
        return 1;
        //task_add(t, &t_flist, 1);
    }

	// return;
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
	if(lru_active_count >= MIN_ALRU_SZ){

		struct page_info * p;
		while((lru_active_count - MIN_ALRU_SZ) > (lru_inactive_count/MIN_ALRU_SZ)){
			/*	if p access bit  0	*/
			/*	move the element to the iactive list*/
			lru_ta_remove(&p);
			lru_ti_insert(p);
		}

	}
	return 1;
}
/*
	This function tries to reclaim a n amount of pages
	returns 1 if sucess, 0 if failure  
*/
int reclaim_pgs(struct env *e, int pg_n){

	/* Code me */

	/*	Swap enough inactive pages */

	/*	Compress pages?		*/
	/*		OR				*/
	/* Deduplicate pages	*/

	/* KILL KILL KILL */

	return 0;
}

/*		BONUSES			*/

void compress_pgs(){
	return;
}

void dedup_pages(){
	return;
}

