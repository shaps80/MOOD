#include "PixlConcurrencyC.h"

#include <stdlib.h>

#if defined(_WIN32)

#include <windows.h>

typedef struct {
    HANDLE handle;
    pixl_thread_entry_t entry;
    void *context;
} pixl_thread_t;

struct pixl_condition {
    CRITICAL_SECTION mutex;
    CONDITION_VARIABLE condition;
};

static DWORD WINAPI pixl_thread_main(LPVOID raw_thread) {
    pixl_thread_t *thread = raw_thread;
    thread->entry(thread->context);
    return 0;
}

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

    thread->entry = entry;
    thread->context = context;
    thread->handle = CreateThread(NULL, 0, pixl_thread_main, thread, 0, NULL);
    if (thread->handle == NULL) {
        if (error != NULL) *error = (int)GetLastError();
        free(thread);
        return NULL;
    }

    SetThreadPriority(thread->handle, THREAD_PRIORITY_HIGHEST);
    if (error != NULL) *error = 0;
    return thread;
}

int pixl_thread_join_and_destroy(void *raw_thread) {
    if (raw_thread == NULL) return 0;
    pixl_thread_t *thread = raw_thread;
    const DWORD status = WaitForSingleObject(thread->handle, INFINITE);
    CloseHandle(thread->handle);
    free(thread);
    return status == WAIT_OBJECT_0 ? 0 : -1;
}

pixl_condition_t *pixl_condition_create(void) {
    pixl_condition_t *condition = malloc(sizeof(pixl_condition_t));
    if (condition == NULL) return NULL;
    InitializeCriticalSection(&condition->mutex);
    InitializeConditionVariable(&condition->condition);
    return condition;
}

void pixl_condition_destroy(pixl_condition_t *condition) {
    if (condition == NULL) return;
    DeleteCriticalSection(&condition->mutex);
    free(condition);
}

int pixl_condition_lock(pixl_condition_t *condition) {
    EnterCriticalSection(&condition->mutex);
    return 0;
}

int pixl_condition_unlock(pixl_condition_t *condition) {
    LeaveCriticalSection(&condition->mutex);
    return 0;
}

int pixl_condition_wait(pixl_condition_t *condition) {
    return SleepConditionVariableCS(
        &condition->condition,
        &condition->mutex,
        INFINITE
    ) ? 0 : -1;
}

int pixl_condition_signal(pixl_condition_t *condition) {
    WakeConditionVariable(&condition->condition);
    return 0;
}

int pixl_condition_broadcast(pixl_condition_t *condition) {
    WakeAllConditionVariable(&condition->condition);
    return 0;
}

void pixl_topology_query(int *available, int *performance) {
    DWORD count = GetActiveProcessorCount(ALL_PROCESSOR_GROUPS);
    *available = count > 0 ? (int)count : 1;
    *performance = 0;
}

#elif defined(__APPLE__) || defined(__linux__)

#include <pthread.h>
#include <unistd.h>

#if defined(__APPLE__)
#include <sys/sysctl.h>
#endif

typedef struct {
    pthread_t value;
    pixl_thread_entry_t entry;
    void *context;
} pixl_thread_t;

struct pixl_condition {
    pthread_mutex_t mutex;
    pthread_cond_t condition;
};

static void *pixl_thread_main(void *raw_thread) {
    pixl_thread_t *thread = raw_thread;
#if defined(__APPLE__)
    pthread_set_qos_class_self_np(QOS_CLASS_USER_INTERACTIVE, 0);
#endif
    return thread->entry(thread->context);
}

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

    thread->entry = entry;
    thread->context = context;
    const int status = pthread_create(
        &thread->value,
        NULL,
        pixl_thread_main,
        thread
    );
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

pixl_condition_t *pixl_condition_create(void) {
    pixl_condition_t *condition = malloc(sizeof(pixl_condition_t));
    if (condition == NULL) return NULL;
    if (pthread_mutex_init(&condition->mutex, NULL) != 0) {
        free(condition);
        return NULL;
    }
    if (pthread_cond_init(&condition->condition, NULL) != 0) {
        pthread_mutex_destroy(&condition->mutex);
        free(condition);
        return NULL;
    }
    return condition;
}

void pixl_condition_destroy(pixl_condition_t *condition) {
    if (condition == NULL) return;
    pthread_cond_destroy(&condition->condition);
    pthread_mutex_destroy(&condition->mutex);
    free(condition);
}

int pixl_condition_lock(pixl_condition_t *condition) {
    return pthread_mutex_lock(&condition->mutex);
}

int pixl_condition_unlock(pixl_condition_t *condition) {
    return pthread_mutex_unlock(&condition->mutex);
}

int pixl_condition_wait(pixl_condition_t *condition) {
    return pthread_cond_wait(&condition->condition, &condition->mutex);
}

int pixl_condition_signal(pixl_condition_t *condition) {
    return pthread_cond_signal(&condition->condition);
}

int pixl_condition_broadcast(pixl_condition_t *condition) {
    return pthread_cond_broadcast(&condition->condition);
}

#if defined(__APPLE__)
static int pixl_sysctl_integer(const char *name) {
    int value = 0;
    size_t size = sizeof(value);
    return sysctlbyname(name, &value, &size, NULL, 0) == 0 && value > 0
        ? value
        : 0;
}
#endif

void pixl_topology_query(int *available, int *performance) {
#if defined(__APPLE__)
    int count = pixl_sysctl_integer("hw.activecpu");
    if (count == 0) count = pixl_sysctl_integer("hw.logicalcpu");
    *available = count > 0 ? count : 1;

    const int performance_count = pixl_sysctl_integer(
        "hw.perflevel0.logicalcpu"
    );
    *performance = performance_count > 0 && performance_count <= *available
        ? performance_count
        : 0;
#else
    const long count = sysconf(_SC_NPROCESSORS_ONLN);
    *available = count > 0 ? (int)count : 1;
    *performance = 0;
#endif
}

#else

#error "PixlConcurrencyC does not support this platform"

#endif
