#include <stdint.h>

/* Julia Union{T,Nothing} stores a non-zero sentinel for nothing (not address 0).
   Capture once from Julia via static_set_julia_nothing. */
static void *jg_julia_nothing = 0;
/* Type tag of boxed Ptr{Nothing}. Union{Mutable,Ptr{Nothing}}(C_NULL) boxes a
   fresh object each time (not a singleton), so compare typeof instead. */
static void *jg_ptr_nothing_type = 0;
