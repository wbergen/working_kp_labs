#include <inc/lib.h>
#include <inc/assert.h>
#include <inc/string.h>

#define MEM_BLOCK_SIZE  (55 *  1024 * 1024)
#define PRINT(...)      cprintf(__VA_ARGS__);


char * gigs;
void umain(int argc, char **argv)
{

    int i;
    gigs = sys_vma_create(MEM_BLOCK_SIZE, PTE_W, 0);

    for(i = 37; i < MEM_BLOCK_SIZE; i+= PGSIZE) {

        cprintf("USER pt.1: %d/%d\n", i, MEM_BLOCK_SIZE);
        *(gigs + i) = 'a';
        //assert(gigs[i] == (char) 0xd0);
    }

    for(i = 37; i < MEM_BLOCK_SIZE; i+= PGSIZE*PGSIZE) {

        cprintf("USER pt.2: %d/%d\n", i, MEM_BLOCK_SIZE);
        assert(gigs[i] == (char) 0x61);
    }
    
    PRINT("mempress successful.\n");
    return;
}