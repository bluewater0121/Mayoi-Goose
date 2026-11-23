// Win32 through Goose's dynamic extern blocks: the window, the message queue,
// GDI drawing into one 32-bit DIB, and the fonts. No C of its own but for the
// sidecar helpers in src/plat.c.
namespace win;

extern "user32" {
    fn register_class(cls: const WndClassEx&) -> u16 = "RegisterClassExW";
    fn create_window(ex: u32, cls: const u16&, title: const u16&, style: u32, x: i32, y: i32,
                     w: i32, h: i32, parent: u64, menu: u64, inst: u64, param: u64) -> u64
                     = "CreateWindowExW";
    fn show_window(h: u64, cmd: i32) -> bool = "ShowWindow";
    fn update_window(h: u64) -> bool = "UpdateWindow";
    fn get_message(msg: Msg&, h: u64, lo: u32, hi: u32) -> i32 = "GetMessageW";
    fn peek_message(msg: Msg&, h: u64, lo: u32, hi: u32, remove: u32) -> bool = "PeekMessageW";
    fn translate_message(msg: const Msg&) -> bool = "TranslateMessage";
    fn dispatch_message(msg: const Msg&) -> i64 = "DispatchMessageW";
    fn def_window_proc(h: u64, m: u32, wp: u64, lp: i64) -> i64 = "DefWindowProcW";
    fn post_quit_message(code: i32) = "PostQuitMessage";
    fn post_message(h: u64, m: u32, wp: u64, lp: i64) -> bool = "PostMessageW";
    fn destroy_window(h: u64) -> bool = "DestroyWindow";
    fn get_dc(h: u64) -> u64 = "GetDC";
    fn release_dc(h: u64, dc: u64) -> i32 = "ReleaseDC";
    fn validate_rect(h: u64, r: u64) -> bool = "ValidateRect";
    fn invalidate_rect(h: u64, r: u64, erase: bool) -> bool = "InvalidateRect";
    fn get_client_rect(h: u64, r: Rect&) -> bool = "GetClientRect";
    fn get_window_rect(h: u64, r: Rect&) -> bool = "GetWindowRect";
    fn adjust_window_rect(r: Rect&, style: u32, menu: bool, ex: u32) -> bool = "AdjustWindowRectEx";
    fn set_window_text(h: u64, s: const u16&) -> bool = "SetWindowTextW";
    fn get_keystate(vk: i32) -> i16 = "GetKeyState";
    fn set_timer(h: u64, id: u64, ms: u32, proc: u64) -> u64 = "SetTimer";
    fn kill_timer(h: u64, id: u64) -> bool = "KillTimer";
    fn set_capture(h: u64) -> u64 = "SetCapture";
    fn release_capture() -> bool = "ReleaseCapture";
    fn load_cursor(inst: u64, name: u64) -> u64 = "LoadCursorW";
    fn set_cursor(c: u64) -> u64 = "SetCursor";
    fn message_box(h: u64, text: const u16&, caption: const u16&, flags: u32) -> i32 = "MessageBoxW";
    fn send_message(h: u64, m: u32, wp: u64, lp: i64) -> i64 = "SendMessageW";
    fn fill_rect(dc: u64, r: const Rect&, b: u64) -> i32 = "FillRect";
    fn get_system_metrics(i: i32) -> i32 = "GetSystemMetrics";
    fn set_window_pos(h: u64, after: u64, x: i32, y: i32, w: i32, ch: i32, flags: u32) -> bool
        = "SetWindowPos";
    fn open_clipboard(h: u64) -> bool = "OpenClipboard";
    fn dpi_aware() = "SetProcessDPIAware";
    fn get_dpi(h: u64) -> u32 = "GetDpiForWindow";
    fn get_dpi_for_system() -> u32 = "GetDpiForSystem";
    fn close_clipboard() -> bool = "CloseClipboard";
}
extern "kernel32" {
    fn get_module_handle(name: u64) -> u64 = "GetModuleHandleA";
    fn get_tick_count() -> u64 = "GetTickCount64";
    fn load_library(name: const u8&) -> u64 = "LoadLibraryA";
    fn get_proc_address(lib: u64, name: const u8&) -> u64 = "GetProcAddress";
}
extern "gdi32" {
    fn create_dc(dc: u64) -> u64 = "CreateCompatibleDC";
    fn delete_dc(dc: u64) -> bool = "DeleteDC";
    fn create_bitmap(dc: u64, w: i32, h: i32) -> u64 = "CreateCompatibleBitmap";
    fn create_dib(dc: u64, bmi: const Bmi&, usage: u32, bits: u64&, section: u64, offset: u32) -> u64
        = "CreateDIBSection";
    fn select_object(dc: u64, obj: u64) -> u64 = "SelectObject";
    fn delete_object(obj: u64) -> bool = "DeleteObject";
    fn bit_blt(dst: u64, x: i32, y: i32, w: i32, h: i32, src: u64, sx: i32, sy: i32, rop: u32) -> bool
        = "BitBlt";
    fn set_viewport_org(hdc: u64, x: i32, y: i32, old: u64) -> bool = "SetViewportOrgEx";
    fn set_text_color(dc: u64, c: u32) -> u32 = "SetTextColor";
    fn set_bk_color(dc: u64, c: u32) -> u32 = "SetBkColor";
    fn set_bk_mode(dc: u64, m: i32) -> i32 = "SetBkMode";
    fn text_out(dc: u64, x: i32, y: i32, s: const u16&, n: i32) -> bool = "TextOutW";
    fn ext_text_out(dc: u64, x: i32, y: i32, opts: u32, r: u64, s: const u16&, n: i32, dx: const i32&) -> bool
        = "ExtTextOutW";
    fn get_text_extent(dc: u64, s: const u16&, n: i32, sz: Size&) -> bool = "GetTextExtentPoint32W";
    fn create_font(h: i32, w: i32, esc: i32, orient: i32, weight: i32, italic: u32, under: u32,
                   strike: u32, charset: u32, outprec: u32, clipprec: u32, quality: u32,
                   pitch: u32, face: const u16&) -> u64 = "CreateFontW";
    fn create_solid_brush(c: u32) -> u64 = "CreateSolidBrush";
    fn create_pen(style: u32, w: i32, c: u32) -> u64 = "CreatePen";
    fn move_to_ex(dc: u64, x: i32, y: i32, prev: u64) -> bool = "MoveToEx";
    fn line_to(dc: u64, x: i32, y: i32) -> bool = "LineTo";
    fn ellipse(dc: u64, l: i32, t: i32, r: i32, b: i32) -> bool = "Ellipse";
    fn rectangle(dc: u64, l: i32, t: i32, r: i32, b: i32) -> bool = "Rectangle";
    fn gdi_round_rect(dc: u64, l: i32, t: i32, r: i32, b: i32, w: i32, h: i32) -> bool = "RoundRect";
    fn polyline(dc: u64, pts: const Point&, n: i32) -> bool = "Polyline";
    fn intersect_clip_rect(dc: u64, l: i32, t: i32, r: i32, b: i32) -> i32 = "IntersectClipRect";
    fn restore_dc(dc: u64, id: i32) -> bool = "RestoreDC";
    fn save_dc(dc: u64) -> i32 = "SaveDC";
    fn get_stock_object(i: i32) -> u64 = "GetStockObject";
    fn get_dibits(dc: u64, bmp: u64, start: u32, lines: u32, bits: u8&, bmi: const Bmi&, usage: u32) -> i32
        = "GetDIBits";
    fn set_pixel(dc: u64, x: i32, y: i32, c: u32) -> u32 = "SetPixel";
}
extern "dwmapi" {
    fn dwm_set_attribute(h: u64, attr: u32, value: const u32&, size: u32) -> i64 = "DwmSetWindowAttribute";
}

struct WndClassEx {
    cb: u32, style: u32, proc: u64, clsextra: i32, wndextra: i32, inst: u64,
    icon: u64, cursor: u64, brush: u64, menu: u64, name: u64, iconsm: u64,
}
struct Msg {
    hwnd: u64, m: u32, pad 4, wp: u64, lp: i64, time: u32, pad 4, x: i32, y: i32,
}
struct Rect { l: i32, t: i32, r: i32, b: i32 }
struct Size { cx: i32, cy: i32 }
struct Point { x: i32, y: i32 }
struct Bmi {
    size: u32, w: i32, h: i32, planes: u16, bits: u16, comp: u32, sizeimg: u32,
    xppm: i32, yppm: i32, used: u32, important: u32, colors: u32[3],
}

extern fn gsp16(p: u16&) -> u64;
extern fn gsp8(p: u8&) -> u64;
extern fn gs_memmove(dst: u8&, src: const u8&, n: i64);
extern fn gs_memset(dst: u8&, n: i64, v: u8);
extern fn gs_clip_get(out: u8&, cap: i64) -> i64;
extern fn gs_clip_put(data: const u8&, len: i64) -> i64;
extern fn gs_confirm(hwnd: u64, text: const u8&, len: i64) -> i64;
extern fn gs_pick_folder(hwnd: u64, out: u8&, cap: i64) -> i64;
extern fn gs_pick_file(hwnd: u64, out: u8&, cap: i64) -> i64;
extern fn gs_run_cmd(cmd: const u8&, len: i64, out: u8&, cap: i64, cwd: const u8&, cwdlen: i64) -> i64;
extern fn gs_file_time(path: const u8&, len: i64) -> i64;
extern fn gs_class_proc() -> i64;
extern fn gs_path_join(a: const u8&, alen: i64, b: const u8&, blen: i64, out: u8&, cap: i64) -> i64;
extern fn gs_setdpi() -> i32;
extern fn gs_icon_draw(hdc: u64, idx: i32, x: i32, y: i32, size: i32, color: u32) -> i64;

fn setdpi() -> i32 { return gs_setdpi(); }

fn icon(idx: i32, x: i32, y: i32, sz: i32, c: u32) {
    gs_icon_draw(dc, idx, x + dx, y + dy, sz, c);
}

var hwnd: u64 = 0;
var dc: u64 = 0;             // the memory DC of the frame
var dib: u64 = 0;
var dib_old: u64 = 0;
var dib_bits: u64 = 0;
var frame_w: i32 = 0;
var frame_h: i32 = 0;
var quit: bool = false;
var dpi: i32 = 96;

fn px(v: i32) -> i32 { return v; }

fn th(f: u64) -> i32 {
    let w = measure(f, "Ag");
    var sz: Size = Size { 0, 0 };
    var b: u16[>..] = [];
    utf16("Ag", b);
    let prev = select_object(dc, f);
    get_text_extent(dc, b[0], 2, sz);
    select_object(dc, prev);
    return sz.cy;
}

// --- text --------------------------------------------------------------------

fn utf16(s: const u8[:], out: u16[>..]&) {
    var i = 0;
    while i < s.len {
        let b = s[i];
        if b < 0x80 { out.push(b); i++; }
        else if (b & 0xE0) == 0xC0 && i + 1 < s.len {
            out.push((b & 0x1F) << 6 | (s[i+1] & 0x3F)); i += 2;
        } else if (b & 0xF0) == 0xE0 && i + 2 < s.len {
            out.push((((b & 0x0F) as u32) << 12 | ((s[i+1] & 0x3F) as u32) << 6 | ((s[i+2] & 0x3F) as u32)) as u16); i += 3;
        } else if (b & 0xF8) == 0xF0 && i + 3 < s.len {
            var cp = ((b & 0x07) as u32) << 18 | ((s[i+1] & 0x3F) as u32) << 12 |
                     ((s[i+2] & 0x3F) as u32) << 6 | ((s[i+3] & 0x3F) as u32);
            cp -= 0x10000;
            out.push((0xD800 | (cp >> 10)) as u16);
            out.push((0xDC00 | (cp & 0x3FF)) as u16);
            i += 4;
        } else { out.push('?'); i++; }
    }
}

fn u16z(s: const u8[:]) -> u16[>..] {
    var o: u16[>..] = [];
    utf16(s, o);
    o.push(0);
    return o;
}

// --- window ------------------------------------------------------------------

fn class_atom(name: const u8[:]) -> u16, u64 {
    let user32 = load_library("user32.dll\0"[0]);
    let proc = gs_class_proc() as u64;
    var cn = u16z(name);
    var cls: WndClassEx = WndClassEx { .. };
    cls.cb = 80;
    cls.style = 0x0020 | 0x0001 | 0x0002;   // CS_HREDRAW | CS_VREDRAW | CS_OWNDC? no: 20|1|2
    cls.proc = proc;
    cls.inst = get_module_handle(0);
    cls.cursor = load_cursor(0, 32512);
    cls.brush = 0;
    cls.name = gsp16(cn[0]);
    return register_class(cls), cls.inst;
}

fn open(title: const u8[:], w: i32, h: i32) -> bool {
    let atom, inst = class_atom("MayoiGooseWindow");
    guard atom != 0 else { return false; }
    var cn = u16z("MayoiGooseWindow");
    var tt = u16z(title);
    // Frameless (the app draws its own title bar) but still resizable.
    let style: u32 = 0x80040000 | 0x02000000 | 0x04000000 | 0x00020000 | 0x00010000;
    hwnd = create_window(0, cn[0], tt[0], style, 40, 30, w, h,
                         0, 0, inst, 0);
    guard hwnd != 0 else { return false; }
    // Dark title bar and frame, as the app's chrome.
    var on: u32 = 1;
    dwm_set_attribute(hwnd, 20, on, 4);
    dwm_set_attribute(hwnd, 19, on, 4);
    var d = get_dpi(hwnd);
    if d >= 72 { dpi = d as i32; }
    // the client still loses the border thickness; grow the window so the client hits w x h
    var rc2: Rect = Rect { 0, 0, 0, 0 };
    get_client_rect(hwnd, rc2);
    if rc2.r != w || rc2.b != h {
        var wr2: Rect = Rect { 0, 0, 0, 0 };
        get_window_rect(hwnd, wr2);
        let dw: i32 = (wr2.r - wr2.l) - rc2.r;
        let dh: i32 = (wr2.b - wr2.t) - rc2.b;
        set_window_pos(hwnd, 0, 40, 30, w + dw, h + dh, 0x0002 | 0x0004);
    }
    show_window(hwnd, 1);
    set_timer(hwnd, 1, 520, 0);
    return true;
}

fn invalidate() { if hwnd != 0 { invalidate_rect(hwnd, 0, false); } }

// reset_frame drops the back buffer: a window back from the taskbar may
// hold a surface the old DIB no longer draws into.
fn reset_frame() {
    if dc != 0 {
        select_object(dc, dib_old);
        delete_object(dib);
        delete_dc(dc);
        dc = 0; dib = 0;
    }
}

fn resize_frame(w: i32, h: i32) {
    if w < 1 || h < 1 { return; }
    if w == frame_w && h == frame_h && dc != 0 { return; }
    if dc != 0 {
        select_object(dc, dib_old);
        delete_object(dib);
        delete_dc(dc);
        dc = 0; dib = 0;
    }
    let screen = get_dc(0);
    dc = create_dc(screen);
    var bmi: Bmi = Bmi { .. };
    bmi.size = 40;
    bmi.w = w;
    bmi.h = -h;
    bmi.planes = 1;
    bmi.bits = 32;
    bmi.comp = 0;
    dib = create_dib(screen, bmi, 0, dib_bits, 0, 0);
    dib_old = select_object(dc, dib);
    // the ui is laid out in whole-window coordinates (the real window keeps a
    // 9px frame on the sides and 1px on top), so shift the drawing origin
    set_bk_mode(dc, 1);
    release_dc(0, screen);
    frame_w = w;
    frame_h = h;
}

fn ticks() -> i64 { return get_tick_count() as i64; }

// frame offsets: the layout constants were measured on a whole-window screenshot
// the layout constants come from a whole-window screenshot; the client is inset
var ox: i32 = 9;
var oy: i32 = 1;
var dx: i32 = 0 - 9;
var dy: i32 = 0;

fn mx(v: i32) -> i32 { return v + ox; }
fn my(v: i32) -> i32 { return v + oy; }

fn present(w: i32, h: i32) {
    let wdc = get_dc(hwnd);
    bit_blt(wdc, 0, 0, w, h, dc, 0, 0, 0x00CC0020);
    release_dc(hwnd, wdc);
    validate_rect(hwnd, 0);
}

// --- painting primitives -----------------------------------------------------

fn color(r: i32, g: i32, b: i32) -> u32 { ((r as u32) << 16 | ((g as u32) << 8) | (b as u32)) }
fn red(c: u32) -> i32 { ((c >> 16) & 0xFF) as i32 }
fn green(c: u32) -> i32 { ((c >> 8) & 0xFF) as i32 }
fn blue(c: u32) -> i32 { (c & 0xFF) as i32 }

fn mix(a: u32, b: u32, t: i32) -> u32 {
    let w = t;
    let k = 1000 - w;
    color((red(a) * k + red(b) * w) / 1000,
          (green(a) * k + green(b) * w) / 1000,
          (blue(a) * k + blue(b) * w) / 1000)
}

var brushes: u64[64] = [0; 64];
var brush_colors: u32[64] = [0; 64];
var brush_next: i32 = 0;

fn brush(c: u32) -> u64 {
    var i = 0;
    while i < 64 { if brush_colors[i] == c && brushes[i] != 0 { return brushes[i]; } i++; }
    let b = create_solid_brush(c);
    let slot = brush_next;
    brushes[slot] = b;
    brush_colors[slot] = c;
    brush_next = (slot + 1) % 64;
    if brushes[slot] != b { }  // the replaced brush leaks; 64 colors only
    return b;
}

fn fill(x: i32, y: i32, w: i64, h: i32, c: u32) {
    if w <= 0 || h <= 0 { return; }
    let r: Rect = Rect { x + dx, y + dy, x + (w as i32) + dx, y + h + dy };
    fill_rect(dc, r, brush(c));
}

fn round_rect(x: i32, y: i32, w: i32, h: i32, ew: i32, eh: i32, c: u32) {
    let null_pen = get_stock_object(8);    // NULL_PEN
    let op = select_object(dc, null_pen);
    let b = brush(c);
    select_object(dc, b);
    gdi_round_rect(dc, x + dx, y + dy, x + w + dx, y + h + dy, ew, eh);
    select_object(dc, op);
}

fn font(size: i32, weight: i32, face: const u8[:]) -> u64 {
    var f = u16z(face);
    return create_font(-size, 0, 0, 0, weight, 0, 0, 0, 0, 0, 0, 0, 0, f[0]);
}

// fontw builds a font whose cells are exactly w pixels wide, as the editor's are
fn fontw(size: i32, w: i32, weight: i32, face: const u8[:]) -> u64 {
    var f = u16z(face);
    return create_font(-size, w, 0, 0, weight, 0, 0, 0, 0, 0, 0, 0, 0, f[0]);
}

fn sel_font(f: u64) { select_object(dc, f); }

fn text_out_at(f: u64, x: i32, y: i32, s16: const u16[:], c: u32) {
    let prev = select_object(dc, f);
    set_text_color(dc, c);
    text_out(dc, x + dx, y + dy, s16[0], s16.len as i32);
    select_object(dc, prev);
}

fn text_at(f: u64, x: i32, y: i32, s: const u8[:], c: u32) {
    var b: u16[>..] = [];
    utf16(s, b);
    if b.len == 0 { return; }
    let prev = select_object(dc, f);
    set_text_color(dc, c);
    text_out(dc, x + dx, y + dy, b[0], b.len as i32);
    select_object(dc, prev);
}

// text_grid draws text on an exact cell grid, as the editor's monospaced columns
fn text_grid(f: u64, x: i32, y: i32, s: const u8[:], c: u32, cell: i32) {
    if s.len == 0 { return; }
    var b: u16[>..] = [];
    utf16(s, b);
    let n: i32 = b.len as i32;
    if n == 0 { return; }
    var i: i32 = 0;
    let prev = select_object(dc, f);
    set_text_color(dc, c);
    var cx: i32 = x + dx;
    i = 0;
    while i < n {
        let u: i32 = b[i] as i32;
        var w = cell;
        if (u >= 0x2E80 && u <= 0xA4CF) || (u >= 0xAC00 && u <= 0xD7A3) ||
           (u >= 0xF900 && u <= 0xFAFF) || (u >= 0xFF00 && u <= 0xFF60) ||
           (u >= 0xFFE0 && u <= 0xFFE6) { w = cell * 2; }
        if u >= 0xDC00 && u <= 0xDFFF { w = 0; }
        text_out(dc, cx, y + dy, b[i], 1);
        cx = cx + w;
        i++;
    }
    select_object(dc, prev);
}

fn measure(f: u64, s: const u8[:]) -> i32 {
    var b: u16[>..] = [];
    utf16(s, b);
    if b.len == 0 { return 0; }
    var sz: Size = Size { 0, 0 };
    let prev = select_object(dc, f);
    get_text_extent(dc, b[0], b.len as i32, sz);
    select_object(dc, prev);
    return sz.cx;
}

fn line(x1: i32, y1: i32, x2: i32, y2: i32, c: u32, wid: i32) {
    let pen = create_pen(0, wid, c);
    let old = select_object(dc, pen);
    move_to_ex(dc, x1 + dx, y1 + dy, 0);
    line_to(dc, x2 + dx, y2 + dy);
    select_object(dc, old);
    delete_object(pen);
}

fn circle(cx: i32, cy: i32, r: i32, c: u32, wid: i32) {
    let pen = create_pen(0, wid, c);
    let old = select_object(dc, pen);
    var null_brush = get_stock_object(5);   // NULL_BRUSH
    let ob = select_object(dc, null_brush);
    ellipse(dc, cx - r + dx, cy - r + dy, cx + r + dx, cy + r + dy);
    select_object(dc, ob);
    select_object(dc, old);
    delete_object(pen);
}

fn discard_font(f: u64) { delete_object(f); }

























fn dispatch(m: const Msg&) { dispatch_message(m); }





fn pick_file(h: u64, out: u8&, cap: i64) -> i64 { return gs_pick_file(h, out, cap); }
fn pick_folder(h: u64, out: u8&, cap: i64) -> i64 { return gs_pick_folder(h, out, cap); }
