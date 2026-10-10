/* Linux-only external SIGKILL injection. Never linked into either application. */
#define _GNU_SOURCE
#include <dlfcn.h>
#include <signal.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

static int scoped(const char *path) {
    const char *root = getenv("POKEAETHER_CRASH_ROOT");
    return root && path && !strncmp(path, root, strlen(root)) && path[strlen(root)] == '/';
}
static int point(const char *name) {
    const char *selected = getenv("POKEAETHER_CRASH_POINT");
    return selected && !strcmp(selected, name);
}
static void crash(const char *name) {
    static const char prefix[] = "INJECTED_SIGKILL ";
    write(STDERR_FILENO, prefix, sizeof(prefix) - 1);
    write(STDERR_FILENO, name, strlen(name));
    write(STDERR_FILENO, "\n", 1);
    kill(getpid(), SIGKILL);
    _exit(99);
}
int rename(const char *old, const char *next) {
    static int (*original)(const char *, const char *);
    if (!original) original = dlsym(RTLD_NEXT, "rename");
    int relevant = scoped(old) && scoped(next);
    if (relevant && strstr(old, ".install-") && point("staged")) crash("staged");
    int result = original(old, next);
    if (result == 0 && relevant) {
        if (strstr(next, ".replaced-") && point("quarantined")) crash("quarantined");
        if (strstr(old, ".install-") && point("published")) crash("published");
        if (strstr(old, "/.generation-") && point("generation")) crash("generation");
        if (strstr(next, "/active.previous.json") && point("previous")) crash("previous");
        if (strstr(old, "/.active-next-") && point("active")) crash("active");
    }
    return result;
}
size_t fwrite(const void *ptr, size_t size, size_t count, FILE *stream) {
    static size_t (*original)(const void *, size_t, size_t, FILE *);
    if (!original) original = dlsym(RTLD_NEXT, "fwrite");
    size_t result = original(ptr, size, count, stream);
    if (point("copy") && size * count >= 1048576) {
        char link[80], path[4096];
        snprintf(link, sizeof(link), "/proc/self/fd/%d", fileno(stream));
        ssize_t length = readlink(link, path, sizeof(path) - 1);
        if (length > 0) {
            path[length] = 0;
            if (scoped(path) && strstr(path, ".install-") && strstr(path, "/model-pair.pck")) crash("copy");
        }
    }
    return result;
}
