

# Such target should be added as a dependency for the final library binary.

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
