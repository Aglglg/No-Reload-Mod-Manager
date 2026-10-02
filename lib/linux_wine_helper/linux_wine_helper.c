// x86_64-w64-mingw32-gcc wine_input_helper.c -o wine_input_helper.exe -lws2_32 -O2 -s

#include <winsock2.h>
#include <windows.h>
#include <stdio.h>
#include <string.h>

#define PORT 38271

static void simulate_key_down(WORD virtualKey) {
    printf("simulate_key_down: key=%d\n", virtualKey);

    INPUT input = {0};
    input.type = INPUT_KEYBOARD;
    input.ki.wVk = virtualKey;
    input.ki.dwExtraInfo = GetMessageExtraInfo();
    SendInput(1, &input, sizeof(INPUT));
}

static void simulate_key_up(WORD virtualKey) {
    printf("simulate_key_up: key=%d\n", virtualKey);

    INPUT input = {0};
    input.type = INPUT_KEYBOARD;
    input.ki.wVk = virtualKey;
    input.ki.dwFlags = KEYEVENTF_KEYUP;
    input.ki.dwExtraInfo = GetMessageExtraInfo();
    SendInput(1, &input, sizeof(INPUT));
}

static void set_cursor_pos(int x, int y) {
    BOOL success = SetCursorPos(x, y);
    printf("set_cursor_pos: x=%d y=%d success=%d\n", x, y, success);
}

static void run_command(const char *line) {
    char command[16] = {0};
    int key = 0, x = 0, y = 0;

    if (sscanf(line, "%15s", command) != 1) return;

    if (strcmp(command, "keydown") == 0 && sscanf(line, "%*s %d", &key) == 1) {
        simulate_key_down((WORD)key);
    }
    else if (strcmp(command, "keyup") == 0 && sscanf(line, "%*s %d", &key) == 1) {
        simulate_key_up((WORD)key);
    }
    else if (strcmp(command, "setcursor") == 0 && sscanf(line, "%*s %d %d", &x, &y) == 2) {
        set_cursor_pos(x, y);
    }
    else {
        printf("Bad command: %s\n", line);
    }
}

static void handle_client(SOCKET client) {
    char buffer[512];
    int used = 0;

    for (;;) {
        int received = recv(client, buffer + used, (int)sizeof(buffer) - used - 1, 0);
        if (received <= 0) break;
        used += received;
        buffer[used] = '\0';

        char *lineStart = buffer;
        char *lineEnd;
        while ((lineEnd = strchr(lineStart, '\n')) != NULL) {
            *lineEnd = '\0';
            run_command(lineStart);
            send(client, "done\n", 5, 0);
            lineStart = lineEnd + 1;
        }
        used = (int)strlen(lineStart);
        memmove(buffer, lineStart, used + 1);

        if (used >= (int)sizeof(buffer) - 1) used = 0;
    }
}

int main(void) {
    setvbuf(stdout, NULL, _IONBF, 0);

    WSADATA wsaData;
    WSAStartup(MAKEWORD(2, 2), &wsaData);

    SOCKET server = socket(AF_INET, SOCK_STREAM, IPPROTO_TCP);

    int yes = 1;
    setsockopt(server, SOL_SOCKET, SO_REUSEADDR, (const char *)&yes, sizeof(yes));

    struct sockaddr_in address = {0};
    address.sin_family = AF_INET;
    address.sin_addr.s_addr = inet_addr("127.0.0.1");
    address.sin_port = htons(PORT);

    if (bind(server, (struct sockaddr *)&address, sizeof(address)) != 0 ||
        listen(server, 1) != 0) {
        printf("Could not listen on port %d\n", PORT);
        return 1;
    }

    printf("Wine input helper listening on 127.0.0.1:%d\n", PORT);

    for (;;) {
        SOCKET client = accept(server, NULL, NULL);
        if (client == INVALID_SOCKET) continue;

        printf("Client connected\n");

        int noDelay = 1;
        setsockopt(client, IPPROTO_TCP, TCP_NODELAY, (const char *)&noDelay, sizeof(noDelay));

        handle_client(client);
        closesocket(client);

        printf("Client disconnected\n");
    }
}
