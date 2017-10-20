/* Simple bitmap impl taken from: https://gist.github.com/gandaro/2218750 */
/* `x+1' if `x % 8' evaluates to `true' */
#define ARRAY_SIZE(x) (x/8+(!!(x%8))) 

char get_bit(char *array, int index);
void toggle_bit(char *array, int index);
void print_swapmap(char * array, int len);