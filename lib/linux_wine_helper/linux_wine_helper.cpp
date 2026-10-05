//x86_64-w64-mingw32-g++ linux_wine_helper.cpp -o wine_helper.exe -lws2_32 -O2 -s -static
#include <winsock2.h>
#include <windows.h>
#include <cstdint>
#include <cstdio>
#include <sstream>
#include <string>
#include <vector>

const int PORT = 38271;

// Keyboard and mouse

void PressKey(WORD key) {
    printf("[key] down: key=%d\n", key);

    INPUT input = {};
    input.type = INPUT_KEYBOARD;
    input.ki.wVk = key;
    input.ki.dwExtraInfo = GetMessageExtraInfo();
    UINT sent = SendInput(1, &input, sizeof(INPUT));

    printf("[key] down: sent=%u\n", sent);
}

void ReleaseKey(WORD key) {
    printf("[key] up: key=%d\n", key);

    INPUT input = {};
    input.type = INPUT_KEYBOARD;
    input.ki.wVk = key;
    input.ki.dwFlags = KEYEVENTF_KEYUP;
    input.ki.dwExtraInfo = GetMessageExtraInfo();
    UINT sent = SendInput(1, &input, sizeof(INPUT));

    printf("[key] up: sent=%u\n", sent);
}

void MoveCursor(int x, int y) {
    BOOL success = SetCursorPos(x, y);
    printf("[mouse] setcursor: x=%d y=%d success=%d\n", x, y, success);
}

// INI Handler DLL

struct ErroredLine {
    int32_t line_index;
    const wchar_t* file_path;
    const wchar_t* trimmed_line;
    const wchar_t* reason;
};

typedef ErroredLine* (*GetErrorsFunction)(const char*, const char*, const char**, int32_t, int32_t*);
typedef void (*FreeErrorsFunction)(ErroredLine*, int32_t);

// Wine's own path converters (exported by kernel32 under Wine)
typedef wchar_t* (*LinuxToWindowsFunction)(const char* linuxPath);
typedef char* (*WindowsToLinuxFunction)(const wchar_t* windowsPath);

std::string WideToUtf8(const wchar_t* text) {
    if (!text) return "";
    int size = WideCharToMultiByte(CP_UTF8, 0, text, -1, nullptr, 0, nullptr, nullptr);
    std::string result(size - 1, '\0');
    WideCharToMultiByte(CP_UTF8, 0, text, -1, &result[0], size, nullptr, nullptr);
    return result;
}

std::string EscapeForJson(const std::string& text) {
    std::string result;
    for (unsigned char letter : text) {
        if (letter == '"')       result += "\\\"";
        else if (letter == '\\') result += "\\\\";
        else if (letter == '\n') result += "\\n";
        else if (letter == '\r') result += "\\r";
        else if (letter == '\t') result += "\\t";
        else if (letter < 0x20)  result += ' ';
        else                     result += (char)letter;
    }
    return result;
}

std::string ErrorReply(const std::string& message) {
    printf("[inicheck] FAILED: %s\n", message.c_str());
    return "{\"error\":\"" + EscapeForJson(message) + "\"}\n";
}

// Linux path to Windows path (as UTF-8), or "" if conversion failed
std::string LinuxToWindowsPath(LinuxToWindowsFunction convert, const std::string& linuxPath) {
    wchar_t* windowsPath = convert(linuxPath.c_str());
    if (!windowsPath) return "";
    std::string result = WideToUtf8(windowsPath);
    HeapFree(GetProcessHeap(), 0, windowsPath);
    return result;
}

// Windows path (wide) to Linux path
std::string WindowsToLinuxPath(WindowsToLinuxFunction convert, const wchar_t* windowsPath) {
    char* linuxPath = convert(windowsPath);
    if (!linuxPath) return "";
    std::string result = linuxPath;
    HeapFree(GetProcessHeap(), 0, linuxPath);
    return result;
}

// fields: [0]="inicheck", [1]=ini path, [2]=base path, [3...]=known lib namespaces
// All paths are Linux paths
std::string RunIniCheck(const std::vector<std::string>& fields) {
    printf("[inicheck] start\n");
    if (fields.size() < 3) return ErrorReply("bad_command");

    printf("[inicheck] linux ini path : %s\n", fields[1].c_str());
    printf("[inicheck] linux base path: %s\n", fields[2].c_str());
    printf("[inicheck] namespaces     : %d\n", (int)fields.size() - 3);

    // Load everything once, reuse on every call
    static HMODULE dll = LoadLibraryA("xxmi_lib_ini_handler.dll");
    static HMODULE kernel = GetModuleHandleA("kernel32.dll");
    if (!dll) return ErrorReply("dll_not_found");

    static auto getErrors = (GetErrorsFunction)GetProcAddress(dll, "GetErroredFlowControlLines");
    static auto freeErrors = (FreeErrorsFunction)GetProcAddress(dll, "FreeErroredFlowControlLinesSnapshot");
    static auto toWindows = (LinuxToWindowsFunction)GetProcAddress(kernel, "wine_get_dos_file_name");
    static auto toLinux = (WindowsToLinuxFunction)GetProcAddress(kernel, "wine_get_unix_file_name");
    if (!getErrors || !freeErrors) return ErrorReply("dll_function_missing");
    if (!toWindows || !toLinux) return ErrorReply("not_running_under_wine");

    std::string iniPath = LinuxToWindowsPath(toWindows, fields[1]);
    std::string basePath = LinuxToWindowsPath(toWindows, fields[2]);
    if (iniPath.empty() || basePath.empty()) return ErrorReply("path_conversion_failed");

    printf("[inicheck] windows ini path : %s\n", iniPath.c_str());
    printf("[inicheck] windows base path: %s\n", basePath.c_str());

    // Wine had no drive letter for this path, so XXMI path code may misbehave
    if (iniPath.rfind("\\\\?\\unix\\", 0) == 0 || basePath.rfind("\\\\?\\unix\\", 0) == 0)
        return ErrorReply("no_drive_for_path");

    // Make sure Wine can really see the file (catches sandbox / unmounted disk)
    if (GetFileAttributesA(iniPath.c_str()) == INVALID_FILE_ATTRIBUTES)
        return ErrorReply("path_not_accessible");

    std::vector<const char*> namespaces;
    for (size_t i = 3; i < fields.size(); ++i) {
        printf("[inicheck] namespace: %s\n", fields[i].c_str());
        namespaces.push_back(fields[i].c_str());
    }

    ULONGLONG startTime = GetTickCount64();

    int32_t count = 0;
    ErroredLine* errors = getErrors(iniPath.c_str(), basePath.c_str(),
                                    namespaces.data(), (int32_t)namespaces.size(), &count);

    printf("[inicheck] dll finished in %llu ms, errors=%d\n",
           (unsigned long long)(GetTickCount64() - startTime), count);

    if (!errors) return ErrorReply("dll_call_failed");

    std::string reply = "{\"errors\":[";
    for (int i = 0; i < count; ++i) {
        std::string file = WindowsToLinuxPath(toLinux, errors[i].file_path);
        std::string text = WideToUtf8(errors[i].trimmed_line);
        std::string reason = WideToUtf8(errors[i].reason);

        printf("[inicheck] error %d: line=%d file=%s\n", i, errors[i].line_index, file.c_str());
        printf("[inicheck]          text=%s\n", text.c_str());
        printf("[inicheck]          reason=%s\n", reason.c_str());

        if (i > 0) reply += ",";
        reply += "{\"line\":" + std::to_string(errors[i].line_index)
               + ",\"file\":\""   + EscapeForJson(file) + "\""
               + ",\"text\":\""   + EscapeForJson(text) + "\""
               + ",\"reason\":\"" + EscapeForJson(reason) + "\"}";
    }
    reply += "]}\n";

    freeErrors(errors, count);

    printf("[inicheck] done, reply size=%d bytes\n", (int)reply.size());
    return reply;
}

// Commands and Network

std::vector<std::string> SplitByTab(const std::string& line) {
    std::vector<std::string> parts;
    std::stringstream stream(line);
    std::string part;
    while (std::getline(stream, part, '\t')) parts.push_back(part);
    return parts;
}

// Runs one command line, returns the reply line (ends with \n)
std::string HandleCommand(const std::string& line) {
    if (line.rfind("inicheck\t", 0) == 0)
        return RunIniCheck(SplitByTab(line));

    std::istringstream words(line);
    std::string command;
    words >> command;

    if (command == "keydown")        { int key; words >> key; PressKey((WORD)key); }
    else if (command == "keyup")     { int key; words >> key; ReleaseKey((WORD)key); }
    else if (command == "setcursor") { int x, y; words >> x >> y; MoveCursor(x, y); }
    else printf("[command] Bad command: %s\n", line.c_str());

    return "done\n";
}

void SendAll(SOCKET client, const std::string& text) {
    size_t sent = 0;
    while (sent < text.size()) {
        int result = send(client, text.c_str() + sent, (int)(text.size() - sent), 0);
        if (result <= 0) {
            printf("[network] send failed after %d of %d bytes\n", (int)sent, (int)text.size());
            return;
        }
        sent += result;
    }
}

void HandleClient(SOCKET client) {
    std::string pending;   // bytes received but not yet a full line
    char chunk[4096];

    for (;;) {
        int received = recv(client, chunk, sizeof(chunk), 0);
        if (received <= 0) break;
        pending.append(chunk, received);

        size_t lineEnd;
        while ((lineEnd = pending.find('\n')) != std::string::npos) {
            std::string line = pending.substr(0, lineEnd);
            pending.erase(0, lineEnd + 1);

            printf("[command] received: %s\n", line.c_str());
            SendAll(client, HandleCommand(line));
        }

        if (pending.size() > 1000000) {
            printf("[network] pending data too large, cleared\n");
            pending.clear();   // safety: ignore garbage
        }
    }
}

int main() {
    setvbuf(stdout, nullptr, _IONBF, 0);

    WSADATA wsaData;
    WSAStartup(MAKEWORD(2, 2), &wsaData);

    SOCKET server = socket(AF_INET, SOCK_STREAM, IPPROTO_TCP);

    int yes = 1;
    setsockopt(server, SOL_SOCKET, SO_REUSEADDR, (const char*)&yes, sizeof(yes));

    sockaddr_in address = {};
    address.sin_family = AF_INET;
    address.sin_addr.s_addr = inet_addr("127.0.0.1");
    address.sin_port = htons(PORT);

    if (bind(server, (sockaddr*)&address, sizeof(address)) != 0 || listen(server, 1) != 0) {
        printf("Could not listen on port %d\n", PORT);
        return 1;
    }
    printf("Wine helper listening on 127.0.0.1:%d\n", PORT);

    for (;;) {
        SOCKET client = accept(server, nullptr, nullptr);
        if (client == INVALID_SOCKET) continue;

        int noDelay = 1;
        setsockopt(client, IPPROTO_TCP, TCP_NODELAY, (const char*)&noDelay, sizeof(noDelay));

        printf("[network] Client connected\n");
        HandleClient(client);
        closesocket(client);
        printf("[network] Client disconnected\n");
    }
}