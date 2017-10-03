/* See COPYRIGHT for copyright information. */

#ifndef JOS_KERN_SCHED_H
#define JOS_KERN_SCHED_H
#ifndef JOS_KERNEL
# error "This is a JOS kernel header; user programs should not #include it"
#endif



/* This function does not return. */
void sched_yield(void) __attribute__((noreturn));

/*
    This function invalidate the time slide of a process
*/
void invalidate_env_ts( struct env * e);
#endif  /* !JOS_KERN_SCHED_H */
