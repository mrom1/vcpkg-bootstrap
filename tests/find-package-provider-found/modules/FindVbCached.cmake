# Test package found like pkg_check_modules(VbCached ...) finds one, as Qt's FindLibb2 does:
# pkg-config's _pkgconfig_set() removes the normal variable and stores <prefix>_FOUND in the
# cache, so from the second configure on VbCached_FOUND is a cache entry before this runs.
# The target is created on every configure.
unset(VbCached_FOUND)
set(VbCached_FOUND 1 CACHE INTERNAL "")
if(VbCached_FOUND AND NOT TARGET VbCached::VbCached)
  add_library(VbCached::VbCached INTERFACE IMPORTED)
endif()
