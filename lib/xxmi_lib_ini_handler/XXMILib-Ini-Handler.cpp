#include "IniHandler.h"
#include "XXMILib-Ini-Handler.h"
#include <Windows.h>
#include <string>
#include "Globals.h"

static std::wstring utf8_to_wstring(const char* utf8) {
    if (!utf8) return {};

    int size = MultiByteToWideChar(
        CP_UTF8,
        MB_ERR_INVALID_CHARS,
        utf8,
        -1,
        nullptr,
        0
    );

    if (size == 0)
        return {};

    std::wstring result(size - 1, L'\0');

    MultiByteToWideChar(
        CP_UTF8,
        MB_ERR_INVALID_CHARS,
        utf8,
        -1,
        &result[0],
        size
    );

    return result;
}

// CALL
ErroredLine_FFI* GetErroredFlowControlLines(
    const char* path,
    const char* base_path,
    const char** known_lib_namespaces,
    int32_t known_lib_namespaces_count,
    int32_t* out_count
)
{
    //PREPARATION

    std::wstring wpath = utf8_to_wstring(path); //full path d3dx.ini e.g: D:\WWMI\d3dx.ini
    std::wstring wbase_path = utf8_to_wstring(base_path); //base path of d3dx.ini e.g: "D:\WWMI\"
    //must end with "\"
    if (!wbase_path.empty())
    {
        wchar_t last = wbase_path.back();
        if (last != L'\\' && last != L'/')
        {
            wbase_path.push_back(L'\\');
        }
    }
    //Global variables as local variable, because real global variable would allocate so much memory that can never be freed when it's called from Dart FFI
    Globals G;

    for (int i = 0; i < known_lib_namespaces_count; ++i) {
        G.known_lib_namespaces.insert(utf8_to_wstring(known_lib_namespaces[i]));
    }
    
    
    //PROCESS
    
    LoadConfigFile(G, wpath, wbase_path);


    //OUTPUT

    *out_count = static_cast<int32_t>(G.errored_lines.size());
    if (*out_count == 0)
        return nullptr;

    auto* arr = static_cast<ErroredLine_FFI*>(
        calloc(*out_count, sizeof(ErroredLine_FFI))
        );

    if (arr == nullptr) {
        *out_count = 0;
        return nullptr;
    }

    int i = 0;
    for (const auto& e : G.errored_lines) {
        arr[i].line_index = e.line_index;
        arr[i].file_path = _wcsdup(e.file_path.c_str());
        arr[i].trimmed_line = _wcsdup(e.trimmed_line.c_str());
        arr[i].reason = _wcsdup(e.reason.c_str());
        ++i;
    }

    //Supposed to return:
    // - Lines that could crash XXMI
    // - Errored FlowControl lines
    //      (in sections: CustomShader, CommandList, ShaderOverride, ShaderRegex main, TextureOverride,
    //       Present, ClearRenderTargetView, ClearDepthStencilView, ClearUnorderedAccessViewUint, ClearUnorderedAccessViewFloat)
    // - Invalid condition expression in [Key] sections
    // - Duplicate sections informations in known lib namespaces such as RabbitFx or Orfix in GIMI, which mean user having multiple same libraries
    // - Missing known lib that was referenced in a mod
    return arr;
}

// FREE
void FreeErroredFlowControlLinesSnapshot(
    ErroredLine_FFI* ptr,
    int32_t count
)
{
    if (!ptr) return;

    for (int i = 0; i < count; ++i) {
        free((void*)ptr[i].file_path);
        free((void*)ptr[i].trimmed_line);
        free((void*)ptr[i].reason);
    }

    free(ptr);
}
