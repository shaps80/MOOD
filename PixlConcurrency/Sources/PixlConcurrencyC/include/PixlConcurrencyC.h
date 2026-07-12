#ifndef PIXL_CONCURRENCY_C_H
#define PIXL_CONCURRENCY_C_H

#include <stddef.h>

typedef void *(*pixl_thread_entry_t)(void *context);

void *pixl_thread_create(
    pixl_thread_entry_t entry,
    void *context,
    int *error
);

int pixl_thread_join_and_destroy(void *thread);

#endif
