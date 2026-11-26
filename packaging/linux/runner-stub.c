/* Tray-free stand-in for the bundled dummy-game runner.
 *
 * The shipped data/src-win.exe creates a tray icon unconditionally and aborts
 * when that fails, which is what happens under Wine (Wine's explorer.exe, the
 * process that owns the notification area, does not survive here). Discord's
 * Linux client decides what you are "playing" from the process it sees in
 * /proc, so a process carrying the game executable's name is enough.
 *
 * Contract matches src-win: --title <name> sets the window title, --tray is
 * accepted and ignored, the process runs until it is killed or the window is
 * closed.
 *
 * The window is created but never shown. Under gamescope only one surface is
 * presented, and showing this window made gamescope switch away from the app's
 * own window, leaving a black screen behind a running game. Detection works on
 * the process, so a hidden window keeps the title available without stealing
 * the display. Pass --visible to show it when debugging.
 *
 * Build: x86_64-w64-mingw32-gcc -O2 -s -mwindows -o src-win.exe runner-stub.c -lshell32
 */
#define UNICODE
#define _UNICODE
#include <windows.h>
#include <shellapi.h>
#include <stdio.h>

static LRESULT CALLBACK WndProc(HWND hwnd, UINT msg, WPARAM wparam, LPARAM lparam)
{
    if (msg == WM_DESTROY) {
        PostQuitMessage(0);
        return 0;
    }
    return DefWindowProcW(hwnd, msg, wparam, lparam);
}

int WINAPI WinMain(HINSTANCE instance, HINSTANCE previous, LPSTR command_line, int show)
{
    (void)previous;
    (void)command_line;
    (void)show;

    WCHAR title[512] = L"Discord Quest App";
    int visible = 0;
    int argc = 0;
    LPWSTR *argv = CommandLineToArgvW(GetCommandLineW(), &argc);
    if (argv) {
        for (int i = 1; i < argc; i++) {
            if (wcscmp(argv[i], L"--title") == 0 && i + 1 < argc) {
                wcsncpy(title, argv[i + 1], 511);
                title[511] = 0;
                i++;
            } else if (wcscmp(argv[i], L"--visible") == 0) {
                visible = 1;
            }
        }
        LocalFree(argv);
    }

    WNDCLASSW wc;
    ZeroMemory(&wc, sizeof(wc));
    wc.lpfnWndProc = WndProc;
    wc.hInstance = instance;
    wc.hCursor = LoadCursorW(NULL, (LPCWSTR)IDC_ARROW);
    wc.hbrBackground = (HBRUSH)GetStockObject(BLACK_BRUSH);
    wc.lpszClassName = L"DiscordQuestWineRunner";
    if (!RegisterClassW(&wc) && GetLastError() != ERROR_CLASS_ALREADY_EXISTS) {
        fprintf(stderr, "RegisterClassW failed: %lu\n", GetLastError());
        return 1;
    }

    HWND hwnd = CreateWindowExW(
        0, wc.lpszClassName, title, WS_OVERLAPPEDWINDOW,
        CW_USEDEFAULT, CW_USEDEFAULT, 480, 360,
        NULL, NULL, instance, NULL);
    if (!hwnd) {
        fprintf(stderr, "CreateWindowExW failed: %lu\n", GetLastError());
        return 1;
    }

    if (visible) {
        ShowWindow(hwnd, SW_SHOW);
        UpdateWindow(hwnd);
    }
    fprintf(stderr, "runner ready title=%ls visible=%d\n", title, visible);
    fflush(stderr);

    MSG msg;
    while (GetMessageW(&msg, NULL, 0, 0) > 0) {
        TranslateMessage(&msg);
        DispatchMessageW(&msg);
    }
    return 0;
}
