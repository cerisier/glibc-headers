#include <sys/syscall.h>

#ifdef __cplusplus
#define CHECK static_assert
#else
#define CHECK _Static_assert
#endif

CHECK(SYS_read == __NR_read, "read syscall alias");

/* Consumers may use kernel headers older than those used to build glibc. */
#if defined(SYS_openat2) && !defined(__NR_openat2)
#error "SYS_openat2 requires __NR_openat2"
#endif
#ifdef SYS_openat2
CHECK(SYS_openat2 == __NR_openat2, "openat2 syscall alias");
#endif
