cmake_minimum_required(VERSION 3.15)
project(bcdeclib LANGUAGES CXX)

# Target definition
add_library(bcdeclib SHARED
    dllmain.cpp
)

# Standard and Properties
set_target_properties(bcdeclib PROPERTIES
    CXX_STANDARD 14
    CXX_STANDARD_REQUIRED YES
    CXX_EXTENSIONS NO
    # Let CMake handle LTCG/GL safely if supported
    INTERPROCEDURAL_OPTIMIZATION_RELEASE TRUE
    LINK_FLAGS "/SUBSYSTEM:WINDOWS"
)

# Includes
target_include_directories(bcdeclib PRIVATE
    ${CMAKE_CURRENT_SOURCE_DIR}
)

if (MSVC)
    # Compiler options
    target_compile_options(bcdeclib PRIVATE
        /EHsc 
        $<$<CONFIG:Release>:/O2 /Oi /Ot /GL>
    )

    # Linker options
    target_link_options(bcdeclib PRIVATE
        $<$<CONFIG:Release>:/LTCG /OPT:REF /OPT:ICF /INCREMENTAL:NO /DEBUG:NONE>
    )

    # Runtime Library (Flutter/Windows Standard)
    set_property(TARGET bcdeclib PROPERTY
        MSVC_RUNTIME_LIBRARY "MultiThreaded$<$<CONFIG:Debug>:Debug>DLL"
    )
endif()