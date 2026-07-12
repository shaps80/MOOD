#ifndef PIXL_CONCURRENCY_C_H
#define PIXL_CONCURRENCY_C_H

#include <stddef.h>

typedef void *(*pixl_thread_entry_t)(void *context);

typedef struct pixl_condition pixl_condition_t;

void *pixl_thread_create(
    pixl_thread_entry_t entry,
    void *context,
    int *error
);

int pixl_thread_join_and_destroy(void *thread);

pixl_condition_t *pixl_condition_create(void);
void pixl_condition_destroy(pixl_condition_t *condition);
int pixl_condition_lock(pixl_condition_t *condition);
int pixl_condition_unlock(pixl_condition_t *condition);
int pixl_condition_wait(pixl_condition_t *condition);
int pixl_condition_broadcast(pixl_condition_t *condition);

void pixl_topology_query(
    int *available_processor_count,
    int *performance_processor_count
);

#endif
