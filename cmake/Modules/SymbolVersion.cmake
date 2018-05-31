#
#  Copyright (c) 2018 Anderson Toshiyuki Sasaki <ansasaki@redhat.com>
#
#  Redistribution and use is allowed according to the terms of the New
#  BSD license.
#  For details see the accompanying COPYING-CMAKE-SCRIPTS file.
#

#.rst:
# SymbolVersion
# -------------
#
# This file provides functions to generate the symbol version script. It uses the
# ``smap`` tool to generate and update the linker script file. It can be installed
# by calling::
#
#   $ pip install symver-smap
#
# The ``function generate_map_file`` generates a symbol version script containing
# the provided symbols. It defines a custom command which set ``target_name`` as
# its ``OUTPUT``.
#
# The experimental function ``extract_symbols()`` is provided as a simple parser
# to extract the symbols from C header files. It simply extracts symbols followed
# by an opening '``(``'. It is recommended to use a filter pattern to select the
# lines to be considered.
#
# ::
#
#   generate_map_file(target_name
#                     RELEASE_NAME_VERSION release_name
#                     SYMBOLS symbol [symbol2 ...]
#                     [OUTPUT_DIR dir]
#                     [OUTPUT_NAME name]
#                     [FINAL]
#                     [BREAK_ABI]
#                    )
#
# ``target_name``
#   Required, expects the name of the file to receive the generated symbol version
#   script. It should be added as a dependency for the library. Use the linker
#   option ``--version-script filename`` to add the version information to the
#   symbols when building the library.
#
# ``RELEASE_NAME_VERSION``
#   Required, expects a string containing the name and version information to be
#   added to the symbols in the format ``lib_name_1_2_3``.
#
# ``SYMBOLS``
#   Required, expects a list of symbols to be added to the symbol version script.
#
# ``OUTPUT_DIR``
#   Optional, expects the path to the directory where the generated symbol version
#   script will be stored. If omitted, ``CMAKE_CURRENT_BINARY_DIR`` will be used
#   instead.
#
# ``OUTPUT_NAME``
#   Optional, expects the name of the file to receive the generated symbol version
#   script. If omitted, ``target_name`` will be used instead.
#
# ``FINAL``
#   Optional. If given, will provide the ``--final`` option to ``smap`` tool,
#   which will mark the modified release in the symbol version script with a
#   special comment, preventing later changes. This option should be set when
#   creating a library release and the resulting map file should be stored with
#   the source code.
#
# ``BREAK_ABI``
#   Optional. If provided, will use ``smap`` ``--allow-abi-break`` option, which
#   accepts incompatible changes to the set of symbols. This is necessary if any
#   previously existing symbol were removed.
#
# Example:
#
# .. code-block:: cmake
#
#   include(SymbolVersion)
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
#   extract_symbols(HEADERS header1 [header2 ...]
#                   [FILTER_PATTERN pattern]
#                   [OUTPUT_VAR var]
#                  )
#
# ``HEADERS``:
#   Expects a list of header files to be parsed
#
# ``FILTER_PATTERN``:
#   Expects a string. Only the lines containing the filter pattern will be
#   considered
#
# ``OUTPUT_VAR``:
#   Expects the name of the variable to be set in ``PARENT_SCOPE`` containing the
#   obtained list of symbols.
#
# This command extracts the symbols from the files provided in ``HEADERS`` and put
# the obtained list in ``var``, which is declared in ``PARENT_SCOPE``. If
# ``pattern`` is provided, then only the lines containing the string given in
# ``pattern`` will be considered. If `var`` is not provided the variable
# ``EXTRACTED_SYMBOLS`` containing the obtained list will be defined in
# ``PARENT_SCOPE``. It is recommended to use a ``FILTER_PATTERN`` to mark the
# lines containing exported function declaration, since this function is
# experimental and can make mistakes when parsing the header files.
#
# Example:
#
# .. code-block:: cmake
#
#   include(SymbolVersion)
#   extract_symbols(
#     HEADERS "header1.h;header2.h"
#     FILTER_PATTERN "API_FUNCTION"
#     OUTPUT_VAR exported_symbols
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
# Will result in the variable ``exported_symbols`` to hold the list::
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
endif (NOT SMAP_EXECUTABLE)

function(extract_symbols)

    set(one_value_arguments
      FILTER_PATTERN
      OUTPUT_VAR
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

    # If OUTPUT_VAR is not given, set as "EXTRACTED_SYMBOLS"
    if (NOT DEFINED _extract_symbols_OUTPUT_VAR)
        set(_extract_symbols_OUTPUT_VAR EXTRACTED_SYMBOLS)
    endif()

    set(symbols)
    foreach(header ${_extract_symbols_HEADERS})
        # Filter only lines containing the FILTER_PATTERN
        file(STRINGS ${header} contain_filter
          REGEX "^.*${_extract_symbols_FILTER_PATTERN}.*[(]"
        )

        # Remove function-like macros
        foreach(line ${contain_filter})
            if (NOT ${line} MATCHES ".*#[ ]*define")
                list(APPEND not_macro ${line})
            endif()
        endforeach()

        set(functions)

        # Get only the function names followed by '('
        foreach(line ${not_macro})
            string(REGEX MATCHALL "[a-zA-Z0-9_]+[ ]*[(]" function ${line})
            list(APPEND functions ${function})
        endforeach()

        set(extracted_symbols)

        # Remove '('
        foreach(line ${functions})
            string(REGEX REPLACE "[(]" "" symbol ${line})
            list(APPEND extracted_symbols ${symbol})
        endforeach()

        list(APPEND symbols ${extracted_symbols})
    endforeach()
    list(REMOVE_DUPLICATES symbols)

    # Put the obtained list in the output variable in PARENT_SCOPE
    set(${_extract_symbols_OUTPUT_VAR} ${symbols} PARENT_SCOPE)
endfunction()

function(generate_map_file _TARGET_NAME)

    set(options
        FINAL
        BREAK_ABI
    )

    set(one_value_arguments
        RELEASE_NAME_VERSION
        OUTPUT_DIR
        OUTPUT_NAME
    )

    set(multi_value_arguments
        SYMBOLS
    )

    cmake_parse_arguments(_generate_map_file
      "${options}"
      "${one_value_arguments}"
      "${multi_value_arguments}"
      ${ARGN}
    )

    if (NOT DEFINED _generate_map_file_SYMBOLS)
        message(FATAL_ERROR "No symbols were given. Provide a list of exported symbols."
        )
    endif()

    if (NOT DEFINED _generate_map_file_RELEASE_NAME_VERSION)
        message(FATAL_ERROR "Release name and version not provided."
          " (e.g. libname_1_0_0"
        )
    endif()

    if (NOT DEFINED _generate_map_file_OUTPUT_NAME)
        set(_generate_map_file_OUTPUT_NAME "${_TARGET_NAME}")
    endif()

    if (NOT DEFINED _generate_map_file_OUTPUT_DIR)
      set(_generate_map_file_OUTPUT_DIR "${CMAKE_CURRENT_BINARY_DIR}")
    endif()

    # Set generated map file path
    get_filename_component(_SMAP_OUTPUT_PATH
      "${_generate_map_file_OUTPUT_DIR}/${_generate_map_file_OUTPUT_NAME}"
      ABSOLUTE
    )

    if (EXISTS ${_SMAP_OUTPUT_PATH})
        set(_SMAP_SUBCOMMAND update)
        set(_SMAP_UPDATED_MAP ${_SMAP_OUTPUT_PATH})
    else ()
        set(_SMAP_SUBCOMMAND new)
    endif()

    set(_SMAP_ARGS_LIST)

    if (_generate_map_file_FINAL)
        list(APPEND _SMAP_ARGS_LIST "--final")
    endif()

    if (_generate_map_file_BREAK_ABI)
        list(APPEND _SMAP_ARGS_LIST "--allow_abi-break")
    endif()

    string(REPLACE ";" " " _SMAP_ARGS "${_SMAP_ARGS_LIST}")

    set(_SMAP_COMMAND ${SMAP_EXECUTABLE} ${_SMAP_SUBCOMMAND} ${_SMAP_ARGS}
      -r ${_generate_map_file_RELEASE_NAME_VERSION}
      -o ${_SMAP_OUTPUT_PATH}
      ${_SMAP_UPDATED_MAP}
    )

    add_custom_command(
        OUTPUT ${_SMAP_OUTPUT_PATH}
        COMMAND
          echo ${_generate_map_file_SYMBOLS} | ${_SMAP_COMMAND}
        VERBATIM
        DEPENDS ${_generate_map_file_HEADERS}
        COMMENT "Generating the map ${_SMAP_OUTPUT_PATH}"
    )
endfunction()
