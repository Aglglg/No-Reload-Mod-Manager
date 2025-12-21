cmake_minimum_required(VERSION 3.15)

project(xxmi_lib_ini_handler LANGUAGES CXX)

# Target

add_library(xxmi_lib_ini_handler SHARED
    CommandList.cpp
    IniHandler.cpp
    XXMILib-Ini-Handler.cpp
)

set_target_properties(xxmi_lib_ini_handler PROPERTIES
    OUTPUT_NAME "xxmi_lib_ini_handler"
    CXX_STANDARD 14
    CXX_STANDARD_REQUIRED YES
    CXX_EXTENSIONS NO

    # Enables /GL + /LTCG for Release
    INTERPROCEDURAL_OPTIMIZATION_RELEASE TRUE
)

# Includes

target_include_directories(xxmi_lib_ini_handler PRIVATE
    ${CMAKE_CURRENT_SOURCE_DIR}
    ${CMAKE_CURRENT_SOURCE_DIR}/pcre2
)

# Preprocessor definitions (exact VS parity)

target_compile_definitions(xxmi_lib_ini_handler PRIVATE
    NDEBUG
    _CONSOLE
    XXMILIB_INI_HANDLER_EXPORTS
    PCRE2_CODE_UNIT_WIDTH=8
    PCRE2_STATIC
)

# MSVC-specific compile options

if (MSVC)

    # Compiler optimizations (Release only)
    target_compile_options(xxmi_lib_ini_handler PRIVATE
        $<$<CONFIG:Release>:/O2>   # Max optimization
        $<$<CONFIG:Release>:/Oi>   # Intrinsics
        $<$<CONFIG:Release>:/Ot>   # Favor speed
        $<$<CONFIG:Release>:/GL>   # Whole program optimization
    )

    # Match VS "Conformance Mode = Default (Off)"
    # (omit /permissive- to keep legacy behavior)
    # target_compile_options(xxmi_lib_ini_handler PRIVATE /permissive-)

    # Exception model (safe default)
    target_compile_options(xxmi_lib_ini_handler PRIVATE /EHsc)

endif()

# Linker settings (THIS is what fixes DLL size)

if (MSVC)

    target_link_options(xxmi_lib_ini_handler PRIVATE
        $<$<CONFIG:Release>:/LTCG>
        $<$<CONFIG:Release>:/OPT:REF>
        $<$<CONFIG:Release>:/OPT:ICF>
        $<$<CONFIG:Release>:/INCREMENTAL:NO>
        $<$<CONFIG:Release>:/DEBUG:NONE>
    )

endif()

# Link PCRE2 static library

target_link_libraries(xxmi_lib_ini_handler PRIVATE
    ${CMAKE_CURRENT_SOURCE_DIR}/pcre2/pcre2-8-64.lib
)

# Ensures /MD in Release, /MDd in Debug (Flutter-compatible)

if (MSVC)
    set_property(TARGET xxmi_lib_ini_handler PROPERTY
        MSVC_RUNTIME_LIBRARY "MultiThreaded$<$<CONFIG:Debug>:Debug>DLL"
    )
endif()
