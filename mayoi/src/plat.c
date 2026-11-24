// The little C beside the program: pointer-level work the language cannot
// express (memory the OS owns, dialogs, a child process's pipes).
#include <winsock2.h>
#include <windows.h>
#include <shlobj.h>
#include <commdlg.h>
#include <shellapi.h>
#include <imm.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>
#include "shim.h"
#include "icons.h"

// The window procedure: client area covers the whole window (the app paints
// its own chrome), while the frame still offers the resize borders.
static LRESULT CALLBACK gs_proc(HWND h, UINT m, WPARAM wp, LPARAM lp) {

    if (m == WM_NCCALCSIZE && wp == TRUE) {
        // the client area is the whole window; resize is still offered by NCHITTEST
        NCCALCSIZE_PARAMS *ncp = (NCCALCSIZE_PARAMS *)lp;
        RECT wr;
        GetWindowRect(h, &wr);
        ncp->rgrc[0] = wr;
        return 0;
    }
    // WM_SIZE / WM_ACTIVATE / WM_SHOWWINDOW are sent straight to this proc, so
    // the Goose message loop would never see them: forward a copy onto the queue.
    if (m == WM_SIZE) { PostMessageW(h, WM_APP + 2, wp, lp); return 0; }
    if (m == WM_ACTIVATE) { PostMessageW(h, WM_APP + 3, wp, lp); return 0; }
    if (m == WM_SHOWWINDOW) { PostMessageW(h, WM_APP + 4, wp, lp); return 0; }
    if (m == WM_DPICHANGED) { PostMessageW(h, WM_APP + 5, wp, lp); return 0; }
    if (m == WM_NCHITTEST) {
        { static int shown=0; if(!shown){ shown=1; RECT cr; GetClientRect(h,&cr); fprintf(stderr,"client now=%ld,%ld,%ld,%ld\n",(long)cr.left,(long)cr.top,(long)cr.right,(long)cr.bottom);} }
        POINT pt;
        pt.x = (int)(short)LOWORD(lp);
        pt.y = (int)(short)HIWORD(lp);
        RECT rc;
        GetWindowRect(h, &rc);
        int b = 5;
        int left = pt.x < rc.left + b, right = pt.x >= rc.right - b;
        int top = pt.y < rc.top + b, bot = pt.y >= rc.bottom - b;
        if (top && left) return HTTOPLEFT;
        if (top && right) return HTTOPRIGHT;
        if (bot && left) return HTBOTTOMLEFT;
        if (bot && right) return HTBOTTOMRIGHT;
        if (top) return HTTOP;
        if (bot) return HTBOTTOM;
        if (left) return HTLEFT;
        if (right) return HTRIGHT;
        {   // drag by the empty parts of the title bar (not the buttons / command box)
            int cx = (int)(pt.x - rc.left), cy = (int)(pt.y - rc.top);
            int inCmd = (cx > 280 && cx < 810 && cy > 5 && cy < 42);
            int inBtn = cx > rc.right - 250;   // minimize / maximize / close
            if (cy >= 0 && cy < 48 && cx >= 92 && !inCmd && !inBtn) return HTCAPTION;
        }
        return HTCLIENT;
    }
    return DefWindowProcW(h, m, wp, lp);
}

int64_t gs_class_proc(void) { return (int64_t)(intptr_t)gs_proc; }


// per-monitor dpi awareness, so that every coordinate is a real pixel
int64_t gs_setdpi(void) {
    HMODULE u = GetModuleHandleA("user32.dll");
    if (!u) return 0;
    typedef BOOL (WINAPI *SetCtx)(HANDLE);
    SetCtx f = (SetCtx)GetProcAddress(u, "SetProcessDpiAwarenessContext");
    // per monitor v2; the window is laid out in real pixels, so asking for it
    // before any DC exists keeps Windows from scaling the frame by 0.8.
    if (f) {
        if (f((HANDLE)(-4))) return 1;
    }
    // older builds: system aware is still better than virtualized.
    typedef BOOL (WINAPI *SetAware)(void);
    SetAware g = (SetAware)GetProcAddress(u, "SetProcessDPIAware");
    if (g && g()) return 2;
    return 0;
}
void gs_memmove(uint8_t *dst, const uint8_t *src, int64_t n) {
    if (n > 0) memmove(dst, src, (size_t)n);
}

void gs_memset(uint8_t *dst, int64_t n, uint8_t v) {
    if (n > 0) memset(dst, v, (size_t)n);
}

static void utf8_to_wide(const char *s, size_t n, WCHAR *out, size_t cap) {
    size_t i = 0, o = 0;
    while (i < n && o + 5 < cap) {
        unsigned cp = (unsigned char)s[i];
        if (cp < 0x80) { out[o++] = (WCHAR)cp; i++; }
        else if ((cp & 0xE0) == 0xC0 && i + 1 < n) {
            out[o++] = (WCHAR)(((cp & 0x1F) << 6) | ((unsigned char)s[i+1] & 0x3F));
            i += 2;
        } else if ((cp & 0xF0) == 0xE0 && i + 2 < n) {
            out[o++] = (WCHAR)(((cp & 0x0F) << 12) | (((unsigned char)s[i+1] & 0x3F) << 6) |
                               ((unsigned char)s[i+2] & 0x3F));
            i += 3;
        } else if ((cp & 0xF8) == 0xF0 && i + 3 < n) {
            unsigned v = ((cp & 7) << 18) | (((unsigned char)s[i+1] & 0x3F) << 12) |
                         (((unsigned char)s[i+2] & 0x3F) << 6) | ((unsigned char)s[i+3] & 0x3F);
            v -= 0x10000;
            out[o++] = (WCHAR)(0xD800 + (v >> 10));
            if (o < cap) out[o++] = (WCHAR)(0xDC00 + (v & 0x3FF));
            i += 4;
        } else { out[o++] = L'?'; i++; }
    }
    out[o < cap ? o : cap - 1] = 0;
}

static int64_t wide_to_utf8(const WCHAR *w, size_t n, uint8_t *out, size_t cap) {
    size_t o = 0;
    for (size_t i = 0; i < n; i++) {
        unsigned c = (unsigned)w[i];
        if (c >= 0xD800 && c < 0xDC00 && i + 1 < n && w[i+1] >= 0xDC00 && w[i+1] < 0xE000) {
            c = 0x10000 + ((c - 0xD800) << 10) + ((unsigned)w[i+1] - 0xDC00);
            i++;
        }
        if (c < 0x80) { if (o + 1 > cap) break; out[o++] = (uint8_t)c; }
        else if (c < 0x800) { if (o + 2 > cap) break; out[o++] = (uint8_t)(0xC0 | (c >> 6)); out[o++] = (uint8_t)(0x80 | (c & 0x3F)); }
        else if (c < 0x10000) { if (o + 3 > cap) break; out[o++] = (uint8_t)(0xE0 | (c >> 12)); out[o++] = (uint8_t)(0x80 | ((c >> 6) & 0x3F)); out[o++] = (uint8_t)(0x80 | (c & 0x3F)); }
        else { if (o + 4 > cap) break; out[o++] = (uint8_t)(0xF0 | (c >> 18)); out[o++] = (uint8_t)(0x80 | ((c >> 12) & 0x3F)); out[o++] = (uint8_t)(0x80 | ((c >> 6) & 0x3F)); out[o++] = (uint8_t)(0x80 | (c & 0x3F)); }
    }
    return (int64_t)o;
}

int64_t gs_clip_get(uint8_t *out, int64_t cap) {
    if (!OpenClipboard(NULL)) return -1;
    int64_t n = -1;
    if (IsClipboardFormatAvailable(CF_UNICODETEXT)) {
        HANDLE h = GetClipboardData(CF_UNICODETEXT);
        if (h) {
            const WCHAR *w = (const WCHAR *)GlobalLock(h);
            if (w) {
                n = wide_to_utf8(w, wcslen(w), out, (size_t)cap);
                GlobalUnlock(h);
            }
        }
    }
    CloseClipboard();
    return n;
}

int64_t gs_clip_put(const uint8_t *data, int64_t len) {
    static WCHAR buf[65536];
    if (len <= 0 || len > 65535) return 0;
    utf8_to_wide((const char *)data, (size_t)len, buf, 65536);
    if (!OpenClipboard(NULL)) return 0;
    EmptyClipboard();
    size_t n = wcslen(buf) + 1;
    HGLOBAL g = GlobalAlloc(GMEM_MOVEABLE, n * sizeof(WCHAR));
    int64_t ok = 0;
    if (g) {
        WCHAR *p = (WCHAR *)GlobalLock(g);
        if (p) {
            memcpy(p, buf, n * sizeof(WCHAR));
            GlobalUnlock(g);
            if (SetClipboardData(CF_UNICODETEXT, g)) ok = 1;
        }
    }
    CloseClipboard();
    return ok;
}

int64_t gs_confirm(uint64_t hwnd, const uint8_t *text, int64_t len) {
    static WCHAR w[1024];
    utf8_to_wide((const char *)text, (size_t)len, w, 1024);
    return MessageBoxW((HWND)(uintptr_t)hwnd, w, L"\u5220\u9664", MB_YESNO | MB_ICONWARNING | MB_DEFBUTTON2) == IDYES;
}

int64_t gs_pick_folder(uint64_t hwnd, uint8_t *out, int64_t cap) {
    CoInitializeEx(NULL, COINIT_APARTMENTTHREADED);
    WCHAR tmp[MAX_PATH];
    BROWSEINFOW bi;
    memset(&bi, 0, sizeof bi);
    bi.hwndOwner = (HWND)(uintptr_t)hwnd;
    bi.lpszTitle = L"Select a folder";
    bi.ulFlags = BIF_RETURNONLYFSDIRS | BIF_NEWDIALOGSTYLE | BIF_USENEWUI;
    LPITEMIDLIST id = SHBrowseForFolderW(&bi);
    if (!id) return -1;
    int64_t n = -1;
    if (SHGetPathFromIDListW(id, tmp)) {
        n = wide_to_utf8(tmp, wcslen(tmp), out, (size_t)cap);
    }
    CoTaskMemFree(id);
    CoUninitialize();
    return n;
}

int64_t gs_ime_pos(uint64_t hwnd, int32_t x, int32_t y) {
    HIMC imc = ImmGetContext((HWND)(uintptr_t)hwnd);
    if (!imc) return 0;
    COMPOSITIONFORM cf;
    memset(&cf, 0, sizeof cf);
    cf.dwStyle = CFS_POINT;
    cf.ptCurrentPos.x = x;
    cf.ptCurrentPos.y = y;
    ImmSetCompositionWindow(imc, &cf);
    CANDIDATEFORM cd;
    memset(&cd, 0, sizeof cd);
    cd.dwIndex = 0;
    cd.dwStyle = CFS_CANDIDATEPOS;
    cd.ptCurrentPos.x = x;
    cd.ptCurrentPos.y = y;
    ImmSetCandidateWindow(imc, &cd);
    ImmReleaseContext((HWND)(uintptr_t)hwnd, imc);
    return 1;
}

int64_t gs_ime_result(uint64_t hwnd, uint8_t *out, int64_t cap) {
    HIMC imc = ImmGetContext((HWND)(uintptr_t)hwnd);
    if (!imc) return 0;
    LONG n = ImmGetCompositionStringW(imc, GCS_RESULTSTR, NULL, 0);
    int64_t r = 0;
    if (n > 0) {
        WCHAR *tmp = (WCHAR *)malloc((size_t)n + 2);
        if (tmp) {
            LONG m = ImmGetCompositionStringW(imc, GCS_RESULTSTR, tmp, n);
            if (m > 0) r = wide_to_utf8(tmp, (size_t)(m / 2), out, (size_t)cap);
            free(tmp);
        }
    }
    ImmReleaseContext((HWND)(uintptr_t)hwnd, imc);
    return r;
}


// --- a tiny local control server, so a script (or an MCP bridge) can drive the
// editor the way a person does: type, click, run menu items and grab a frame.
static SOCKET g_mcp_l = INVALID_SOCKET, g_mcp_c = INVALID_SOCKET;
static char g_mcp_in[65536];
static int g_mcp_inlen = 0;

int64_t gs_mcp_start(uint64_t hwnd, int64_t port) {
    WSADATA wsa;
    if (WSAStartup(MAKEWORD(2, 2), &wsa) != 0) return 0;
    g_mcp_l = socket(AF_INET, SOCK_STREAM, IPPROTO_TCP);
    if (g_mcp_l == INVALID_SOCKET) return 0;
    int one = 1;
    setsockopt(g_mcp_l, SOL_SOCKET, SO_REUSEADDR, (const char *)&one, sizeof(one));
    struct sockaddr_in a;
    memset(&a, 0, sizeof(a));
    a.sin_family = AF_INET;
    a.sin_port = htons((unsigned short)port);
    a.sin_addr.s_addr = inet_addr("127.0.0.1");
    if (bind(g_mcp_l, (struct sockaddr *)&a, sizeof(a)) != 0) return 0;
    if (listen(g_mcp_l, 2) != 0) return 0;
    u_long nb = 1;
    ioctlsocket(g_mcp_l, FIONBIO, &nb);
    SetTimer((HWND)(uintptr_t)hwnd, 7, 30, NULL);
    return 1;
}

int64_t gs_mcp_poll(uint8_t *out, int64_t cap) {
    if (g_mcp_l == INVALID_SOCKET) return 0;
    if (g_mcp_c == INVALID_SOCKET) {
        g_mcp_c = accept(g_mcp_l, NULL, NULL);
        if (g_mcp_c == INVALID_SOCKET) return 0;
        u_long nb = 1;
        ioctlsocket(g_mcp_c, FIONBIO, &nb);
        g_mcp_inlen = 0;
    }
    char tmp[4096];
    int got = recv(g_mcp_c, tmp, (int)sizeof(tmp), 0);
    if (got == 0) { closesocket(g_mcp_c); g_mcp_c = INVALID_SOCKET; return 0; }
    if (got > 0) {
        if (g_mcp_inlen + got < (int)sizeof(g_mcp_in) - 1) {
            memcpy(g_mcp_in + g_mcp_inlen, tmp, (size_t)got);
            g_mcp_inlen += got;
            g_mcp_in[g_mcp_inlen] = 0;
        }
    }
    // one request per line; anything after the newline waits for the next poll
    for (int i = 0; i < g_mcp_inlen; i++) {
        if (g_mcp_in[i] != '\n') continue;
        int n = i;
        if (n > 0 && g_mcp_in[n - 1] == '\r') n--;
        if (n > cap - 1) n = (int)cap - 1;
        memcpy(out, g_mcp_in, (size_t)n);
        out[n] = 0;
        memmove(g_mcp_in, g_mcp_in + i + 1, (size_t)(g_mcp_inlen - i - 1));
        g_mcp_inlen -= i + 1;
        return n;
    }
    return 0;
}

void gs_mcp_send(const uint8_t *s, int64_t n) {
    if (g_mcp_c == INVALID_SOCKET) return;
    while (n > 0) {
        int k = send(g_mcp_c, (const char *)s, (int)n, 0);
        if (k <= 0) { closesocket(g_mcp_c); g_mcp_c = INVALID_SOCKET; return; }
        s += k;
        n -= k;
    }
}

// A frame of the client area as a BMP; the caller names the rectangle in
// physical pixels and gets the number of bytes written.
int64_t gs_capture(uint64_t hwnd, int64_t x, int64_t y, int64_t w, int64_t h,
                   uint8_t *path, int64_t pcap) {
    HWND hw = (HWND)(uintptr_t)hwnd;
    RECT rc;
    GetClientRect(hw, &rc);
    if (w <= 0 || h <= 0) { x = 0; y = 0; w = rc.right; h = rc.bottom; }
    if (x + w > rc.right) w = rc.right - x;
    if (y + h > rc.bottom) h = rc.bottom - y;
    if (w <= 0 || h <= 0) return 0;
    HDC sdc = GetDC(hw);
    HDC mdc = CreateCompatibleDC(sdc);
    HBITMAP bmp = CreateCompatibleBitmap(sdc, (int)w, (int)h);
    HGDIOBJ old = SelectObject(mdc, bmp);
    BitBlt(mdc, 0, 0, (int)w, (int)h, sdc, (int)x, (int)y, SRCCOPY);
    BITMAPINFO bi;
    memset(&bi, 0, sizeof(bi));
    bi.bmiHeader.biSize = sizeof(BITMAPINFOHEADER);
    bi.bmiHeader.biWidth = (LONG)w;
    bi.bmiHeader.biHeight = -(LONG)h;
    bi.bmiHeader.biPlanes = 1;
    bi.bmiHeader.biBitCount = 32;
    bi.bmiHeader.biCompression = BI_RGB;
    int row = (int)w * 4;
    uint8_t *bits = (uint8_t *)malloc((size_t)(row * h));
    int64_t total = 0;
    if (bits && GetDIBits(mdc, bmp, 0, (UINT)h, bits, &bi, DIB_RGB_COLORS)) {
        WCHAR tmp[MAX_PATH], file[MAX_PATH];
        GetTempPathW(MAX_PATH, tmp);
        wcscpy(file, tmp);
        wcscat(file, L"mayoi_mcp_shot.bmp");
        HANDLE f = CreateFileW(file, GENERIC_WRITE, 0, NULL, CREATE_ALWAYS,
                               FILE_ATTRIBUTE_NORMAL, NULL);
        if (f != INVALID_HANDLE_VALUE) {
            BITMAPFILEHEADER fh;
            memset(&fh, 0, sizeof(fh));
            fh.bfType = 0x4D42;
            fh.bfOffBits = sizeof(fh) + sizeof(BITMAPINFOHEADER);
            fh.bfSize = fh.bfOffBits + row * (int)h;
            BITMAPINFOHEADER ih = bi.bmiHeader;
            ih.biSizeImage = row * (int)h;
            DWORD wr = 0;
            WriteFile(f, &fh, sizeof(fh), &wr, NULL);
            WriteFile(f, &ih, sizeof(ih), &wr, NULL);
            WriteFile(f, bits, (DWORD)(row * h), &wr, NULL);
            CloseHandle(f);
            total = fh.bfSize;
            int64_t n = wide_to_utf8(file, wcslen(file), path, (size_t)pcap);
            if (n > 0 && n < pcap) path[n] = 0;
        }
    }
    if (bits) free(bits);
    SelectObject(mdc, old);
    DeleteObject(bmp);
    DeleteDC(mdc);
    ReleaseDC(hw, sdc);
    return total;
}

int64_t gs_ime_comp(uint64_t hwnd, uint8_t *out, int64_t cap) {
    HIMC imc = ImmGetContext((HWND)(uintptr_t)hwnd);
    if (!imc) return 0;
    LONG n = ImmGetCompositionStringW(imc, GCS_COMPSTR, NULL, 0);
    int64_t r = 0;
    if (n > 0) {
        WCHAR *tmp = (WCHAR *)malloc((size_t)n + 2);
        if (tmp) {
            LONG m = ImmGetCompositionStringW(imc, GCS_COMPSTR, tmp, n);
            if (m > 0) r = wide_to_utf8(tmp, (size_t)(m / 2), out, (size_t)cap);
            free(tmp);
        }
    }
    ImmReleaseContext((HWND)(uintptr_t)hwnd, imc);
    return r;
}

int64_t gs_pick_file(uint64_t hwnd, uint8_t *out, int64_t cap) {
    WCHAR tmp[MAX_PATH * 2];
    tmp[0] = 0;
    OPENFILENAMEW ofn;
    memset(&ofn, 0, sizeof ofn);
    ofn.hwndOwner = (HWND)(uintptr_t)hwnd;
    ofn.lpstrFile = tmp;
    ofn.nMaxFile = MAX_PATH * 2;
    ofn.lpstrFilter = L"All Files\0*\0\0";
    ofn.Flags = OFN_FILEMUSTEXIST | OFN_NOCHANGEDIR | OFN_PATHMUSTEXIST;
    if (!GetOpenFileNameW(&ofn)) return -1;
    return wide_to_utf8(tmp, wcslen(tmp), out, (size_t)cap);
}

// Runs `cmd` through the shell with its stdout and stderr joined into `out`.
int64_t gs_run_cmd(const uint8_t *cmd, int64_t len, uint8_t *out, int64_t cap,
                   const uint8_t *cwd, int64_t cwdlen) {
    static WCHAR wcmd[8192];
    static WCHAR wcwd[1024];
    if (len <= 0 || len > 8000) return -1;
    utf8_to_wide((const char *)cmd, (size_t)len, wcmd, 8192);
    if (cwd && cwdlen > 0) utf8_to_wide((const char *)cwd, (size_t)cwdlen, wcwd, 1024);
    SECURITY_ATTRIBUTES sa;
    sa.nLength = sizeof sa;
    sa.lpSecurityDescriptor = NULL;
    sa.bInheritHandle = TRUE;
    HANDLE rd = NULL, wr = NULL;
    if (!CreatePipe(&rd, &wr, &sa, 0)) return -1;
    SetHandleInformation(rd, HANDLE_FLAG_INHERIT, 0);
    STARTUPINFOW si;
    memset(&si, 0, sizeof si);
    si.dwFlags = STARTF_USESHOWWINDOW | STARTF_USESTDHANDLES;
    si.wShowWindow = SW_HIDE;
    si.hStdOutput = wr;
    si.hStdError = wr;
    si.hStdInput = NULL;
    PROCESS_INFORMATION pi;
    memset(&pi, 0, sizeof pi);
    WCHAR full[8300];
    wsprintfW(full, L"cmd.exe /C %s", wcmd);
    BOOL ok = CreateProcessW(NULL, full, NULL, NULL, TRUE, CREATE_NO_WINDOW, NULL,
                             (cwd && cwdlen > 0) ? wcwd : NULL, &si, &pi);
    CloseHandle(wr);
    if (!ok) { CloseHandle(rd); return -1; }
    int64_t n = 0;
    DWORD got = 0;
    uint8_t chunk[4096];
    for (;;) {
        if (!ReadFile(rd, chunk, 4096, &got, NULL) || got == 0) break;
        for (DWORD i = 0; i < got && n < cap; i++) {
            uint8_t c = chunk[i];
            if (c == '\r') continue;
            out[n++] = c;
        }
        if (n >= cap) break;
    }
    WaitForSingleObject(pi.hProcess, 20000);
    CloseHandle(pi.hProcess);
    CloseHandle(pi.hThread);
    CloseHandle(rd);
    return n;
}

int64_t gs_path_join(const uint8_t *a, int64_t alen, const uint8_t *b, int64_t blen,
                     uint8_t *out, int64_t cap) {
    int64_t n = 0;
    for (int64_t i = 0; i < alen && n < cap; i++) out[n++] = a[i];
    if (alen > 0 && a[alen-1] != '/' && a[alen-1] != '\\' && n < cap) out[n++] = '/';
    for (int64_t i = 0; i < blen && n < cap; i++) out[n++] = b[i];
    return n;
}

int64_t gs_file_time(const uint8_t *path, int64_t len) {
    static WCHAR w[MAX_PATH * 2];
    utf8_to_wide((const char *)path, (size_t)len, w, MAX_PATH * 2);
    WIN32_FILE_ATTRIBUTE_DATA d;
    if (!GetFileAttributesExW(w, GetFileExInfoStandard, &d)) return 0;
    return (int64_t)d.ftLastWriteTime.dwLowDateTime;
}


// --- icons ---------------------------------------------------------------
// The masks come from tools/mkicons.py, which rasterizes the Lucide shapes in
// cmd/mayoi/icons.go. Each (icon, color, size) is tinted once into a 32bpp
// premultiplied bitmap and then blitted with AlphaBlend.
#define GS_ICON_CACHE 1024

typedef struct {
    int32_t idx, size;
    uint32_t color;
    HDC dc;
    HBITMAP bm;
    HGDIOBJ old;
    uint8_t *bits;
} GsIconEntry;

static GsIconEntry g_icons_cache[GS_ICON_CACHE];
static int32_t g_icons_used;

static float gs_sample_alpha(const uint8_t *a, int32_t size, int32_t px, int32_t py) {
    float sx = ((float)px + 0.5f) * 16.0f / (float)size - 0.5f;
    float sy = ((float)py + 0.5f) * 16.0f / (float)size - 0.5f;
    if (sx < 0) sx = 0; if (sy < 0) sy = 0;
    if (sx > 15) sx = 15; if (sy > 15) sy = 15;
    int32_t x0 = (int32_t)sx, y0 = (int32_t)sy;
    int32_t x1 = x0 < 15 ? x0 + 1 : 15, y1 = y0 < 15 ? y0 + 1 : 15;
    float fx = sx - (float)x0, fy = sy - (float)y0;
    float a00 = a[y0 * 16 + x0], a10 = a[y0 * 16 + x1];
    float a01 = a[y1 * 16 + x0], a11 = a[y1 * 16 + x1];
    float top = a00 + (a10 - a00) * fx;
    float bot = a01 + (a11 - a01) * fx;
    return top + (bot - top) * fy;
}

int64_t gs_icon_draw(uint64_t hdcv, int32_t idx, int32_t x, int32_t y, int32_t size, uint32_t color) {
    if (idx < 0 || idx >= GS_ICON_COUNT || size <= 0 || size > 512) return 0;
    int32_t i = 0;
    for (; i < g_icons_used; i++) {
        GsIconEntry *e = &g_icons_cache[i];
        if (e->idx == idx && e->size == size && e->color == color) break;
    }
    if (i == g_icons_used) {
        if (g_icons_used >= GS_ICON_CACHE) return 0;
        GsIconEntry *e = &g_icons_cache[g_icons_used];
        BITMAPINFO bi;
        memset(&bi, 0, sizeof bi);
        bi.bmiHeader.biSize = sizeof(BITMAPINFOHEADER);
        bi.bmiHeader.biWidth = size;
        bi.bmiHeader.biHeight = -size;
        bi.bmiHeader.biPlanes = 1;
        bi.bmiHeader.biBitCount = 32;
        bi.bmiHeader.biCompression = BI_RGB;
        void *bits = NULL;
        HBITMAP bm = CreateDIBSection(NULL, &bi, DIB_RGB_COLORS, &bits, NULL, 0);
        if (!bm) return 0;
        HDC mem = CreateCompatibleDC(NULL);
        if (!mem) { DeleteObject(bm); return 0; }
        e->old = SelectObject(mem, bm);
        e->idx = idx; e->size = size; e->color = color;
        e->dc = mem; e->bm = bm; e->bits = (uint8_t *)bits;
        g_icons_used++;
    }
    GsIconEntry *e = &g_icons_cache[i];
    const uint8_t *mask = gs_icons[idx].a;
    uint8_t *dst = e->bits;
    int32_t r = (int32_t)(color & 0xFF);
    int32_t g = (int32_t)((color >> 8) & 0xFF);
    int32_t b = (int32_t)((color >> 16) & 0xFF);
    for (int32_t py = 0; py < size; py++) {
        for (int32_t px = 0; px < size; px++) {
            float fa = gs_sample_alpha(mask, size, px, py);
            int32_t a = (int32_t)(fa + 0.5f);
            if (a < 0) a = 0; if (a > 255) a = 255;
            uint8_t *p = dst + ((size_t)py * size + px) * 4;
            p[0] = (uint8_t)((b * a) / 255);
            p[1] = (uint8_t)((g * a) / 255);
            p[2] = (uint8_t)((r * a) / 255);
            p[3] = (uint8_t)a;
        }
    }
    BLENDFUNCTION bf;
    bf.BlendOp = AC_SRC_OVER;
    bf.BlendFlags = 0;
    bf.SourceConstantAlpha = 255;
    bf.AlphaFormat = AC_SRC_ALPHA;
    AlphaBlend((HDC)hdcv, x, y, size, size, e->dc, 0, 0, size, size, bf);
    return 1;
}














uint64_t gsp16(uint16_t *p) { return (uint64_t)p; }
uint64_t gsp8(uint8_t *p) { return (uint64_t)p; }
uint64_t gsp32(uint32_t *p) { return (uint64_t)p; }
uint64_t gsp64(uint64_t *p) { return (uint64_t)p; }

// --- images -----------------------------------------------------------------
// GDI+ is loaded by name so the build keeps its plain gdi32.lib link line.
typedef struct { uint32_t ver; void *cb; int32_t suppress_bg; int32_t suppress_codecs; } GpStartupInput;
typedef int32_t (WINAPI *GpStartupFn)(uintptr_t *, GpStartupInput *, void *);
typedef int32_t (WINAPI *GpBitmapFromFileFn)(const WCHAR *, void **);
typedef int32_t (WINAPI *GpImageWidthFn)(void *, uint32_t *);
typedef int32_t (WINAPI *GpImageHeightFn)(void *, uint32_t *);
typedef int32_t (WINAPI *GpFromHdcFn)(HDC, void **);
typedef int32_t (WINAPI *GpDrawRectFn)(void *, void *, int32_t, int32_t, int32_t, int32_t);
typedef int32_t (WINAPI *GpDeleteGraphicsFn)(void *);
typedef int32_t (WINAPI *GpDisposeImageFn)(void *);

static HMODULE gp_mod;
static uintptr_t gp_token;
static GpBitmapFromFileFn gp_bitmap_from_file;
static GpImageWidthFn gp_image_width;
static GpImageHeightFn gp_image_height;
static GpFromHdcFn gp_from_hdc;
static GpDrawRectFn gp_draw_rect;
static GpDeleteGraphicsFn gp_delete_graphics;
static GpDisposeImageFn gp_dispose_image;

static int gp_ready(void) {
    if (gp_mod) return 1;
    gp_mod = LoadLibraryW(L"gdiplus.dll");
    if (!gp_mod) return 0;
    GpStartupFn startup = (GpStartupFn)GetProcAddress(gp_mod, "GdiplusStartup");
    gp_bitmap_from_file = (GpBitmapFromFileFn)GetProcAddress(gp_mod, "GdipCreateBitmapFromFile");
    gp_image_width = (GpImageWidthFn)GetProcAddress(gp_mod, "GdipGetImageWidth");
    gp_image_height = (GpImageHeightFn)GetProcAddress(gp_mod, "GdipGetImageHeight");
    gp_from_hdc = (GpFromHdcFn)GetProcAddress(gp_mod, "GdipCreateFromHDC");
    gp_draw_rect = (GpDrawRectFn)GetProcAddress(gp_mod, "GdipDrawImageRectI");
    gp_delete_graphics = (GpDeleteGraphicsFn)GetProcAddress(gp_mod, "GdipDeleteGraphics");
    gp_dispose_image = (GpDisposeImageFn)GetProcAddress(gp_mod, "GdipDisposeImage");
    if (!startup || !gp_bitmap_from_file) { return 0; }
    GpStartupInput in;
    in.ver = 1;
    in.cb = NULL;
    in.suppress_bg = 0;
    in.suppress_codecs = 0;
    if (startup(&gp_token, &in, NULL) != 0) return 0;
    return 1;
}

void *gs_img_load(const uint8_t *path, int64_t len) {
    static WCHAR wpath[1024];
    if (len <= 0 || len > 1000 || !gp_ready()) return NULL;
    utf8_to_wide((const char *)path, (size_t)len, wpath, 1024);
    void *img = NULL;
    if (gp_bitmap_from_file(wpath, &img) != 0) return NULL;
    return img;
}

void gs_img_size(void *img, int64_t *w, int64_t *h) {    uint32_t iw = 0, ih = 0;
    if (!img) return;
    if (gp_image_width) gp_image_width(img, &iw);
    if (gp_image_height) gp_image_height(img, &ih);
    if (w) *w = (int64_t)iw;
    if (h) *h = (int64_t)ih;
}

int64_t gs_img_w(void *img) {
    uint32_t iw = 0;
    if (img && gp_image_width) gp_image_width(img, &iw);
    return (int64_t)iw;
}

int64_t gs_img_h(void *img) {
    uint32_t ih = 0;
    if (img && gp_image_height) gp_image_height(img, &ih);
    return (int64_t)ih;
}

void gs_img_draw(void *img, void *hdcv, int64_t x, int64_t y, int64_t w, int64_t h) {
    void *g = NULL;
    if (!img || !gp_from_hdc || gp_from_hdc((HDC)hdcv, &g) != 0) return;
    gp_draw_rect(g, img, (int32_t)x, (int32_t)y, (int32_t)w, (int32_t)h);
    if (gp_delete_graphics) gp_delete_graphics(g);
}

void gs_img_free(void *img) {
    if (img && gp_dispose_image) gp_dispose_image(img);
}

