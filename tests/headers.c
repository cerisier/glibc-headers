#include <features.h>
#include <stddef.h>
#include <stdint.h>
#include <inttypes.h>
#include <stdio.h>
#include <stdlib.h>
#include <pthread.h>
#include <sys/stat.h>
#include <sys/socket.h>
#include <sys/mman.h>
#include <sys/syscall.h>
#include <unistd.h>
#include <dlfcn.h>
#include <signal.h>
#include <math.h>
#include <wchar.h>
#include <endian.h>

#ifdef __cplusplus
#define CHECK static_assert
#else
#define CHECK _Static_assert
#endif

CHECK(__GLIBC__ == 2 && __GLIBC_MINOR__ == EXPECTED_GLIBC_MINOR, "glibc release");
CHECK(sizeof(size_t) == __SIZEOF_POINTER__, "size_t ABI");
CHECK(sizeof(ptrdiff_t) == __SIZEOF_POINTER__, "ptrdiff_t ABI");
CHECK(sizeof(uint64_t) == 8, "uint64_t ABI");
CHECK(sizeof(off_t) == 8, "large file ABI");
CHECK(__BYTE_ORDER == __BYTE_ORDER__, "byte order");
CHECK(UINT64_C(1) == 1 && UINT32_MAX == 4294967295U, "integer macros");
CHECK(SYS_read == __NR_read, "read syscall alias");
CHECK(SYS_getrandom == __NR_getrandom, "getrandom syscall alias");
#ifdef __x86_64__
CHECK(SYS_arch_prctl == __NR_arch_prctl, "x86 syscall alias");
#endif

pthread_mutex_t mutex = PTHREAD_MUTEX_INITIALIZER;
const char *format = "%" PRIx64;

int header_probe(pthread_t *thread) {
    printf("%s", format);
    return pthread_join(*thread, NULL);
}
