#pragma once

#ifdef XXMILIB_INI_HANDLER_EXPORTS
#define API __declspec(dllexport)
#else
#define API __declspec(dllimport)
#endif

extern "C" {
    struct ErroredLine_FFI {
        int32_t line_index;
        const wchar_t* file_path;
        const wchar_t* trimmed_line;
        const wchar_t* reason;
    };

    API ErroredLine_FFI* GetErroredFlowControlLines(
        const char* path,
        const char* base_path,
        const char** known_lib_namespaces,
        int32_t known_lib_namespaces_count,
        int32_t* out_count
    );

    API void FreeErroredFlowControlLinesSnapshot(
        ErroredLine_FFI* ptr,
        int32_t count
    );
}
