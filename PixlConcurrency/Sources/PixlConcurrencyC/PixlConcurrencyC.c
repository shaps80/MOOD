#include "PixlConcurrencyC.h"

#if defined(__APPLE__) || defined(__linux__)
#include <pthread.h>
#include <stdlib.h>

typedef struct {
    pthread_t value;
} pixl_thread_t;

void *pixl_thread_create(
    pixl_thread_entry_t entry,
    void *context,
    int *error
) {
    pixl_thread_t *thread = malloc(sizeof(pixl_thread_t));
    if (thread == NULL) {
        if (error != NULL) *error = -1;
        return NULL;
    }

    const int status = pthread_create(&thread->value, NULL, entry, context);
    if (status != 0) {
        free(thread);
        if (error != NULL) *error = status;
        return NULL;
    }

    if (error != NULL) *error = 0;
    return thread;
}

int pixl_thread_join_and_destroy(void *raw_thread) {
    if (raw_thread == NULL) return 0;
    pixl_thread_t *thread = raw_thread;
    const int status = pthread_join(thread->value, NULL);
    free(thread);
    return status;
}

#else
void *pixl_thread_create(
    pixl_thread_entry_t entry,
    void *context,
    int *error
) {
    if (error != NULL) *error = -1;
    return NULL;
}

int pixl_thread_join_and_destroy(void *thread) {
    return -1;
}
#endif
