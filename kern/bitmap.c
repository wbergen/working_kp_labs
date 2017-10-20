/* Simple bitmap impl taken from: https://gist.github.com/gandaro/2218750 */
#include <inc/lib.h>
#include <kern/bitmap.h>


// Toggle specific bit:
void toggle_bit(char *array, int index)
{
    array[index/8] ^= 1 << (index % 8);
}


// Return specific bit:
char get_bit(char *array, int index)
{
    return 1 & (array[index/8] >> (index % 8));
}

// This function prints the a bitmap
void print_swapmap(char *array, int len){
	int i;
	cprintf("[KTASK] [");
	for (i = 0; i < len; ++i)
	{
		cprintf("%u", get_bit(array, i));
	}
	cprintf("]\n");
}