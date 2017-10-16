
#define MIN_ALRU_SZ	0
#define	BL_LRU_RATIO 1
/*
	This function assign a badness score to each active process and kills the winner
	return 1 if a process is killed to free space, 0 if failure
*/
int oom_kill(struct env *e, int pgs_r);
/*
	This function swap in a page from the disk
*/
int page_in(struct tasklet * t);
/*
	This function swaps out a page from the disk
*/
int page_out(struct tasklet * t);
/*
	This function manage the active and inactive LRU lists 
*/
int lru_manager();
/*
	This function tries to reclaim a n amount of pages
	returns 1 if sucess, 0 if failure  
*/
int reclaim_pgs(struct env *e, int pg_n);