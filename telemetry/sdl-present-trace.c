/* Opt-in SDL 1.2 present-cadence tracer for the ARMv6 experiment.
 * Enable with LD_PRELOAD and PI286_SDL_PRESENT_STATS=/path/to/stats.tsv.
 * It writes one aggregate line per second, deliberately avoiding per-frame IO.
 */
#define _GNU_SOURCE
#include <SDL.h>
#include <dlfcn.h>
#include <fcntl.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <unistd.h>

typedef int (*flip_fn)(SDL_Surface *);
typedef void (*update_rects_fn)(SDL_Surface *, int, SDL_Rect *);
static flip_fn real_flip;
static update_rects_fn real_update_rects;
static int stats_fd = -1;
static __thread int in_flip;
static uint64_t last_present_ns, window_start_ns;
static uint32_t presents, min_interval_us, max_interval_us, max_call_us, over_33ms;

static uint64_t now_ns(void) {
    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC, &ts);
    return (uint64_t)ts.tv_sec * 1000000000ULL + (uint64_t)ts.tv_nsec;
}

static void flush_window(uint64_t now) {
    char line[192];
    int length;
    if (stats_fd < 0 || !window_start_ns || now - window_start_ns < 1000000000ULL) return;
    length = snprintf(line, sizeof(line), "%llu %u %u %u %u %u\n",
        (unsigned long long)(now / 1000000ULL), presents, min_interval_us,
        max_interval_us, max_call_us, over_33ms);
    if (length > 0) (void)write(stats_fd, line, (size_t)length);
    window_start_ns = now;
    presents = max_interval_us = max_call_us = over_33ms = 0;
    min_interval_us = UINT32_MAX;
}

static void record_present(uint64_t started_ns) {
    uint64_t now = now_ns(), elapsed = now - started_ns;
    uint32_t call_us = (uint32_t)(elapsed / 1000ULL);
    if (stats_fd < 0) return;
    if (!window_start_ns) { window_start_ns = now; min_interval_us = UINT32_MAX; }
    if (last_present_ns) {
        uint32_t interval_us = (uint32_t)((now - last_present_ns) / 1000ULL);
        if (interval_us < min_interval_us) min_interval_us = interval_us;
        if (interval_us > max_interval_us) max_interval_us = interval_us;
        if (interval_us > 33000) ++over_33ms;
    }
    last_present_ns = now;
    ++presents;
    if (call_us > max_call_us) max_call_us = call_us;
    flush_window(now);
}

static void ensure_started(void) {
    const char *path;
    if (stats_fd != -1) return;
    path = getenv("PI286_SDL_PRESENT_STATS");
    if (!path || !*path) { stats_fd = -2; return; }
    stats_fd = open(path, O_CREAT | O_WRONLY | O_TRUNC, 0600);
    if (stats_fd >= 0) {
        static const char header[] = "window_end_ms presents min_interval_us max_interval_us max_present_us gaps_over_33ms\n";
        (void)write(stats_fd, header, sizeof(header) - 1);
    }
}

int SDL_Flip(SDL_Surface *screen) {
    uint64_t started = now_ns();
    ensure_started();
    if (!real_flip) real_flip = (flip_fn)dlsym(RTLD_NEXT, "SDL_Flip");
    if (!real_flip) return -1;
    ++in_flip;
    int result = real_flip(screen);
    --in_flip;
    record_present(started);
    return result;
}

void SDL_UpdateRects(SDL_Surface *screen, int count, SDL_Rect *rects) {
    uint64_t started = now_ns();
    ensure_started();
    if (!real_update_rects) real_update_rects = (update_rects_fn)dlsym(RTLD_NEXT, "SDL_UpdateRects");
    if (!real_update_rects) return;
    real_update_rects(screen, count, rects);
    if (!in_flip) record_present(started);
}
