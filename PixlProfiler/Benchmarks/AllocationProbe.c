// macOS-only measurement probe; never linked into production.
#include <stdlib.h>
#include <stdbool.h>
#include <stdint.h>
#include <malloc/malloc.h>
static _Thread_local bool measuring;
static _Thread_local uint64_t count;
void profile_allocations_begin(void) { count = 0; measuring = true; }
uint64_t profile_allocations_end(void) { measuring = false; return count; }
#define HIT() do { if (measuring) ++count; } while (0)
#define INTERPOSE(replacement, original) \
__attribute__((used)) static const struct { const void *a; const void *b; } pair_##original \
__attribute__((section("__DATA,__interpose"))) = { (const void *)&replacement, (const void *)&original };
static void *probe_malloc(size_t n) { HIT(); return malloc(n); }
static void *probe_calloc(size_t n, size_t s) { HIT(); return calloc(n,s); }
static void *probe_realloc(void *p, size_t s) { HIT(); return realloc(p,s); }
static void *probe_zone_malloc(malloc_zone_t *z, size_t n) { HIT(); return malloc_zone_malloc(z,n); }
static void *probe_zone_calloc(malloc_zone_t *z, size_t n, size_t s) { HIT(); return malloc_zone_calloc(z,n,s); }
static void *probe_zone_realloc(malloc_zone_t *z, void *p, size_t s) { HIT(); return malloc_zone_realloc(z,p,s); }
static void *probe_zone_memalign(malloc_zone_t *z, size_t a, size_t s) { HIT(); return malloc_zone_memalign(z,a,s); }
INTERPOSE(probe_malloc, malloc)
INTERPOSE(probe_calloc, calloc)
INTERPOSE(probe_realloc, realloc)
INTERPOSE(probe_zone_malloc, malloc_zone_malloc)
INTERPOSE(probe_zone_calloc, malloc_zone_calloc)
INTERPOSE(probe_zone_realloc, malloc_zone_realloc)
INTERPOSE(probe_zone_memalign, malloc_zone_memalign)
