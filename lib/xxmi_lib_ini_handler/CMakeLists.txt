cmake_minimum_required(VERSION 3.15)
project(xxmi_lib_ini_handler LANGUAGES CXX)

# Target definition
add_library(xxmi_lib_ini_handler SHARED
    CommandList.cpp
    IniHandler.cpp
    XXMILib-Ini-Handler.cpp
    ResourceHash.cpp
)

# Standard and Properties
set_target_properties(xxmi_lib_ini_handler PROPERTIES
    CXX_STANDARD 14
    CXX_STANDARD_REQUIRED YES
    CXX_EXTENSIONS NO
    # Let CMake handle LTCG/GL safely if supported
    INTERPROCEDURAL_OPTIMIZATION_RELEASE TRUE
)

# Includes
target_include_directories(xxmi_lib_ini_handler PRIVATE
    ${CMAKE_CURRENT_SOURCE_DIR}
    ${CMAKE_CURRENT_SOURCE_DIR}/pcre2
)

# Definitions
target_compile_definitions(xxmi_lib_ini_handler PRIVATE
    XXMILIB_INI_HANDLER_EXPORTS
    PCRE2_CODE_UNIT_WIDTH=8
    PCRE2_STATIC
)

if (MSVC)
    # Compiler options
    target_compile_options(xxmi_lib_ini_handler PRIVATE
        /EHsc 
        $<$<CONFIG:Release>:/O2 /Oi /Ot /GL>
    )

    # Linker options
    target_link_options(xxmi_lib_ini_handler PRIVATE
        $<$<CONFIG:Release>:/LTCG /OPT:REF /OPT:ICF /INCREMENTAL:NO /DEBUG:NONE>
    )

    # Runtime Library (Flutter/Windows Standard)
    set_property(TARGET xxmi_lib_ini_handler PROPERTY
        MSVC_RUNTIME_LIBRARY "MultiThreaded$<$<CONFIG:Debug>:Debug>DLL"
    )
endif()

# Link PCRE2 
target_link_libraries(xxmi_lib_ini_handler PRIVATE
    ${CMAKE_CURRENT_SOURCE_DIR}/pcre2/pcre2-8-64.lib
)