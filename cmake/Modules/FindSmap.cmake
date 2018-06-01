#
#  Copyright (c) 2018 Anderson Toshiyuki Sasaki <ansasaki@redhat.com>
#
#  Redistribution and use is allowed according to the terms of the New
#  BSD license.
#  For details see the accompanying COPYING-CMAKE-SCRIPTS file.
#

#.rst:
# FindSmap
# --------
#
# This file provides functions to generate the symbol version script. It uses
# the ``smap`` tool to generate and update the linker script file. It can be
# installed by calling::
#
#   $ pip install symver-smap
#
# The ``function generate_map_file`` generates a symbol version script
# containing the provided symbols. It defines a custom command which sets
# ``target_name`` as its ``OUTPUT``.
#
# The experimental function ``extract_symbols()`` is provided as a simple
# parser to extract the symbols from C header files. It simply extracts symbols
# followed by an opening '``(``'. It is recommended to use a filter pattern to
# select the lines to be considered. It defines a custom command which sets
# ``target_name`` as its output.
#
# Functions provided
# ------------------
#
# ::
#
#   generate_map_file(target_name
#                     RELEASE_NAME_VERSION release_name
#                     SYMBOLS symbols_file
#                     [CURRENT_MAP cur_map]
#                     [FINAL]
#                     [BREAK_ABI]
#                    )
#
# ``target_name``:
#   Required, expects the name of the file to receive the generated symbol
#   version script. It should be added as a dependency for the library. Use the
#   linker option ``--version-script filename`` to add the version information
#   to the symbols when building the library.
#
# ``RELEASE_NAME_VERSION``:
#   Required, expects a string containing the name and version information to be
#   added to the symbols in the format ``lib_name_1_2_3``.
#
# ``SYMBOLS``:
#   Required, expects a file containing the list of symbols to be added to the
#   symbol version script.
#
# ``CURRENT_MAP``:
#   Optional. If given, the new set of symbols will be checked against the
#   ones contained in the ``cur_map`` file and updated properly. If an
#   incompatible change is detected and ``BREAK_ABI`` is not defined, the build
#   will fail.
#
# ``FINAL``:
#   Optional. If given, will provide the ``--final`` option to ``smap`` tool,
#   which will mark the modified release in the symbol version script with a
#   special comment, preventing later changes. This option should be set when
#   creating a library release and the resulting map file should be stored with
#   the source code.
#
# ``BREAK_ABI``:
#   Optional. If provided, will use ``smap`` ``--allow-abi-break`` option, which
#   accepts incompatible changes to the set of symbols. This is necessary if any
#   previously existing symbol were removed.
#
# Example:
#
# .. code-block:: cmake
#
#   find_package(Smap)
#   generate_map_file("lib.map"
#                     RELEASE_NAME_VERSION "lib_1_0_0"
#                     SYMBOLS "symbol1;symbol2"
#                    )
#
# This example would result in the symbol version script to be created in
# ``${CMAKE_CURRENT_BINARY_DIR}/lib.map`` containing the provided symbols.
#
# ::
#
#   extract_symbols(target_name
#                   HEADERS header1 [header2 ...]
#                   [FILTER_PATTERN pattern]
#                  )
#
# ``HEADERS``:
#   Required, expects a list of header files to be parsed.
#
# ``FILTER_PATTERN``:
#   Optional, expects a string. Only the lines containing the filter pattern
#   will be considered.
#
# This command extracts the symbols from the files provided in ``HEADERS`` and
# write it on the ``target_name`` file. If ``pattern`` is provided, then only
# the lines containing the string given in ``pattern`` will be considered.
# It is recommended to use a ``FILTER_PATTERN`` to mark the lines containing
# exported function declaration, since this function is experimental and can
# return wrong symbols when parsing the header files.
#
# Example:
#
# .. code-block:: cmake
#
#   find_package(Smap)
#   extract_symbols("lib.symbols"
#     HEADERS "header1.h;header2.h"
#     FILTER_PATTERN "API_FUNCTION"
#   )
#
# Where ``header1.h`` contains::
#
#   API_FUNCTION int exported_func1(int a, int b);
#
# ``header2.h`` contains::
#
#   API_FUNCTION int exported_func2(int a);
#
#   int private_func2(int b);
#
# Will result in a file ``lib.symbols`` containing::
#
#   ``exported_func1;exported_func2``
#

# Search for python which is required
find_package(PythonInterp REQUIRED)

# Search for smap tool used to generate the map files
find_program(SMAP_EXECUTABLE NAMES smap DOC "path to the smap executable")
mark_as_advanced(SMAP_EXECUTABLE)

if (NOT SMAP_EXECUTABLE)
    message(FATAL_ERROR "Could not find `smap` in PATH."
                        " It can be found in PyPI as `symver-smap`"
                        " (try `pip install symver-smap`)")
else ()
    set(SMAP_FOUND TRUE)
endif (NOT SMAP_EXECUTABLE)

# Define helper scripts
set(_EXTRACT_SYMBOLS_SCRIPT ${CMAKE_CURRENT_LIST_DIR}/ExtractSymbols.cmake)
set(_GENERATE_MAP_SCRIPT ${CMAKE_CURRENT_LIST_DIR}/GenerateMap.cmake)

function(extract_symbols _TARGET_NAME)

    set(one_value_arguments
      FILTER_PATTERN
    )

    set(multi_value_arguments
      HEADERS
    )

    cmake_parse_arguments(_extract_symbols
      ""
      "${one_value_arguments}"
      "${multi_value_arguments}"
      ${ARGN}
    )

    # The HEADERS argument is required
    if (NOT DEFINED _extract_symbols_HEADERS)
        message(FATAL_ERROR "No header files given. Provide a list of header"
                            " files containing exported symbols."
        )
    endif()

    # Set output path
    get_filename_component(_extract_symbols_OUTPUT_PATH
      "${CMAKE_CURRENT_BINARY_DIR}/${_TARGET_NAME}"
      ABSOLUTE
    )

    add_custom_command(
        OUTPUT ${_TARGET_NAME}
        COMMAND ${CMAKE_COMMAND}
          -DOUTPUT_PATH="${_extract_symbols_OUTPUT_PATH}"
          -DHEADERS="${_extract_symbols_HEADERS}"
          -DFILTER_PATTERN=${_extract_symbols_FILTER_PATTERN}
          -P ${_EXTRACT_SYMBOLS_SCRIPT}
        DEPENDS ${_extract_symbols_HEADERS}
        COMMENT
          "Extracting symbols from headers"
    )

endfunction()

function(generate_map_file _TARGET_NAME)

    set(options
        FINAL
        BREAK_ABI
    )

    set(one_value_arguments
        RELEASE_NAME_VERSION
        SYMBOLS
        CURRENT_MAP
    )

    set(multi_value_arguments
    )

    cmake_parse_arguments(_generate_map_file
      "${options}"
      "${one_value_arguments}"
      "${multi_value_arguments}"
      ${ARGN}
    )

    if (NOT DEFINED _generate_map_file_SYMBOLS)
        message(FATAL_ERROR "No symbols file provided."
        )
    endif()

    if (NOT DEFINED _generate_map_file_RELEASE_NAME_VERSION)
        message(FATAL_ERROR "Release name and version not provided."
          " (e.g. libname_1_0_0"
        )
    endif()

    # Set generated map file path
    get_filename_component(_generate_map_file_OUTPUT_PATH
      "${CMAKE_CURRENT_BINARY_DIR}/${_TARGET_NAME}"
      ABSOLUTE
    )

    add_custom_command(
        OUTPUT ${_TARGET_NAME}
        COMMAND ${CMAKE_COMMAND}
          -DSMAP_EXECUTABLE=${SMAP_EXECUTABLE}
          -DSYMBOLS="${_generate_map_file_SYMBOLS}"
          -DCURRENT_MAP=${_generate_map_file_CURRENT_MAP}
          -DOUTPUT_PATH="${_generate_map_file_OUTPUT_PATH}"
          -DFINAL=${_generate_map_file_FINAL}
          -DBREAK_ABI=${_generate_map_file_BREAK_ABI}
          -DRELEASE_NAME_VERSION=${_generate_map_file_RELEASE_NAME_VERSION}
          -P ${_GENERATE_MAP_SCRIPT}
        DEPENDS ${_generate_map_file_SYMBOLS}
        COMMENT "Generating the map ${_TARGET_NAME}"
    )
endfunction()
