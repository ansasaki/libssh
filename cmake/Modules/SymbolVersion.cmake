# Generate symbol versioning map file (version script)
#
# Adds a symver target which gets all symbols marked with the modifier
# LIBSSH_API in the header files and generate a symbol versioning map file.
# The smap tool is used to generate and update the map file.

find_package(PythonInterp REQUIRED)

find_program(SMAP smap)
if (NOT SMAP)
    message(FATAL_ERROR "Could not find `smap` in PATH."
                        " It can be found in PyPI as `symver-smap`"
                        " (try `pip install symver-smap`)")
endif (NOT SMAP)

find_program(GREP grep)
if (NOT GREP)
    message(FATAL_ERROR "Could not find `grep` in PATH.")
endif (NOT GREP)

find_program(SED sed)
if (NOT SED)
    message(FATAL_ERROR "Could not find `sed` in PATH.")
endif (NOT SED)

find_program(AWK awk)
if (NOT AWK)
    message(FATAL_ERROR "Could not find `awk` in PATH.")
endif (NOT AWK)

if (WITH_ABI_BREAK)
    set (ABI_BREAK --allow-abi-break)
endif (WITH_ABI_BREAK)

if (EXISTS ${CMAKE_CURRENT_SOURCE_DIR}/src/${PROJECT_NAME}.map)
    set(SMAP_ARGS
        update ${ABI_BREAK} -r ${PROJECT_NAME}_${LIBRARY_VERSION} -o
        ${CMAKE_CURRENT_SOURCE_DIR}/src/${PROJECT_NAME}.map
        ${CMAKE_CURRENT_SOURCE_DIR}/src/${PROJECT_NAME}.map
    )
else ()
    set(SMAP_ARGS
        new -r ${PROJECT_NAME}_${LIBRARY_VERSION} -o
        ${CMAKE_CURRENT_SOURCE_DIR}/src/${PROJECT_NAME}.map
    )
endif (EXISTS ${CMAKE_CURRENT_SOURCE_DIR}/src/${PROJECT_NAME}.map)

file (GLOB ALL_HEADERS "${CMAKE_CURRENT_SOURCE_DIR}/include/libssh/*.h")

add_custom_target(symver ALL
    COMMAND
      ${GREP} -hri "LIBSSH_API" ${ALL_HEADERS} |
      ${GREP} -v "\#define" |
      ${SED} s/.*LIBSSH_API\ // |
      ${SED} s/\(.*// |
      ${AWK} {print\ $NF} |
      ${SED} s/*// |
      ${SED} s/\ // |
      ${SMAP} ${SMAP_ARGS}
    VERBATIM
    DEPENDS ${ALL_HEADERS}
    COMMENT "Generating symbol versioning map"
)
