# Test package with components: every requested component becomes the target VbParts::<Name>.
# Asked for one component per call, like Qt asks for XCB's components (XCB, CURSOR, GLX, ...).
foreach(_vb_component IN LISTS VbParts_FIND_COMPONENTS)
  if(NOT TARGET VbParts::${_vb_component})
    add_library(VbParts::${_vb_component} INTERFACE IMPORTED)
  endif()
  set(VbParts_${_vb_component}_FOUND TRUE)
endforeach()
unset(_vb_component)
set(VbParts_FOUND TRUE)
