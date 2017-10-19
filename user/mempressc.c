#include <inc/lib.h>
#include <inc/assert.h>
#include <inc/string.h>

#define MEM_BLOCK_SIZE  (128 *  1024 * 1024)
#define PRINT(...)      cprintf(__VA_ARGS__);

//char gigs[MEM_BLOCK_SIZE];
char * gigs;
void umain(int argc, char **argv)
{

    int i;
    gigs = sys_vma_create(MEM_BLOCK_SIZE, PTE_W, 0);
    /* Write to all of available physical memory (and more) */
   /* memset(gigs, 0xd0, sizeof(char) * MEM_BLOCK_SIZE);
    assert(gigs[10] == (char) 0xd0);
    PRINT("Memory of size %d bytes set to: %x\n", MEM_BLOCK_SIZE, gigs[10]);*/

    /* Read every page so that they get swapped back again */
    for(i = 37; i < MEM_BLOCK_SIZE; i+= PGSIZE) {
        cprintf("L-USER lol! \n");
        *(gigs + i) = 'a';
        //assert(gigs[i] == (char) 0xd0);
    }

    PRINT("mempress successful.\n");
    return;
}