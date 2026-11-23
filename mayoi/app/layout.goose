// The frame's measurements, its fonts, and the folder and document it shows.
namespace app;
import std;
import os;
import app.state;
import ui.theme;
import ui.win;
import editor.text;
import editor.syntax;
import explore.tree;
import app.draw;
import app.prefs.model;
import app.icons;
import app.titlebar;
import app.sidebar;
import app.tabs;
import app.status;
import editor.editor;var term: u8[>..] = [];
var term_input: u8[>..] = [];
var show_welcome: bool = true;

fn layout() {
    state::s = 1;
    state::title_h = state::px(49);
    state::tab_h = state::px(42);
    state::crumb_h = state::px(41);
    state::status_h = state::px(30);
    state::panel_head = state::px(34);
    state::row_h = state::px(35);
    state::line_h = state::px(25);
    state::sidebar_w = state::px(319);
    state::fs_ui = state::px(16);
    state::fs_small = state::px(15);
    state::fs_code = state::px(15);
}

fn setting_num(key: const u8[:], def: i32) -> i32 {
    let i = prefs::index_of(key);
    if i < 0 { return def; }
    let v = prefs::value(i);
    if v.len == 0 { return def; }
    var k: i64 = 0;
    var n: i32 = 0;
    var neg = false;
    if v[0] == '-' { neg = true; k = 1; }
    while k < v.len && v[k] >= '0' && v[k] <= '9' {
        n = n * 10 + (v[k] - '0') as i32;
        k++;
    }
    if neg { n = -n; }
    if k == (if neg { 1 } else { 0 }) { return def; }
    return n;
}

// apply_settings makes the window follow the settings that shape how it looks:
// the light or dark palette, the code font, its size and line height.
fn apply_settings() {
    let a = prefs::index_of("appearance");
    var light = false;
    if a >= 0 {
        let v = prefs::value(a);
        if v.len == 1 && v[0] == '1' { light = true; }
        if v.len == 5 && v[0] == 'l' { light = true; }
    }
    if light { theme::set_light(); } else { theme::set_dark(); }
    state::wrap_enabled = prefs::bool_of("wordWrap");
    fonts();
}

fn fonts() {
    var fs = setting_num("fontSize", 13);
    if fs >= 100 { fs = fs / 100; }
    if fs < 9 { fs = 9; }
    if fs > 28 { fs = 28; }
    var lhm = setting_num("lineHeight", 150);
    if lhm >= 10 { lhm = lhm; } else { lhm = 150; }
    if lhm < 100 { lhm = 100; }
    if lhm > 300 { lhm = 300; }
    var weight = setting_num("fontWeight", 400);
    if weight >= 1000 { weight = weight / 100; }
    if weight < 100 { weight = 400; }
    var fam: u8[>..] = [];
    let fi = prefs::index_of("fontFamily");
    if fi >= 0 {
        let fv = prefs::value(fi);
        var k: i64 = 0;
        while k < fv.len {
            let c = fv[k];
            if c == ',' { break; }
            if c != ' ' && c != '"' { fam.push(c); }
            k++;
        }
    }
    if fam.len == 0 { fam.append("Consolas"); }
    // "monospace" is the generic name the settings use; GDI has no such family
    if fam.len == 9 && fam[0] == 'm' && fam[1] == 'o' && fam[2] == 'n' { fam.resize(0); fam.append("Consolas"); }
    state::line_h = (state::px(fs * 100) * lhm) / 10000 * 1;
    if state::line_h < state::px(fs) { state::line_h = state::px(fs + 4); }
    state::f_ui = win::font(state::px(16), 400, "Segoe UI");
    state::f_ui_b = win::font(state::px(16), 600, "Segoe UI");
    state::f_small = win::font(state::px(15), 400, "Segoe UI");
    state::f_small_b = win::font(state::px(15), 600, "Segoe UI");
    state::f_tree = win::font(state::px(13), 400, "Segoe UI");
    state::f_code = win::fontw(state::px(fs), state::px(9), weight, fam[0..fam.len]);
    state::f_title = win::font(state::px(30), 600, "Segoe UI");
    state::f_prefs = win::font(state::px(12), 400, "Segoe UI");
    state::f_prefs_b = win::font(state::px(13), 600, "Segoe UI");
    state::f_prefs_k = win::fontw(state::px(11), state::px(6), 400, "Consolas");
    state::f_prefs_h = win::font(state::px(15), 600, "Segoe UI");
    state::f_code_small = win::font(state::px(fs - 2), 400, fam[0..fam.len]);
    state::f_cjk = win::font(state::px(15), 400, "Microsoft YaHei UI");
    state::cell_w = win::measure(state::f_code, "00000000000000000000") / 20;

    if state::cell_w < 4 { state::cell_w = state::px(10); }
}

fn open_path(path: const u8[:]) -> bool {
    let i = text::open_file(path);
    if i < 0 {
        var msg: u8[>..] = [];
        msg.append("无法打开 ");
        var k: i64 = 0;
        while k < path.len { msg.push(path[k]); k++; }
        set_status(msg);
        return false;
    }
    state::cur = i;
    syntax::invalidate();
    text::reindex();
    state::docs[i].scroll = 0;
    show_welcome = false;
    set_title(state::docs[i].name);
    // a Markdown file opens with the rendered preview beside the source, the
    // way the reference does, and keeps it in step with edits
    if is_markdown(path) {
        let mode = md_mode();
        if mode == 1 {
            state::preview_open = true;
            state::preview_side = true;
            state::preview_live = true;
        } else if mode == 2 {
            state::preview_open = true;
            state::preview_side = false;
            state::preview_live = true;
        }
        state::preview_scroll = 0;
    }
    return true;
}

// md_mode is the markdownMode setting: 0 source, 1 live preview, 2 reading.
fn md_mode() -> i32 {
    let i = prefs::index_of("markdownMode");
    if i < 0 { return 0; }
    let v = prefs::value(i);
    if v.len == 1 && v[0] >= '0' && v[0] <= '2' { return (v[0] - '0') as i32; }
    if v.len == 4 && v[0] == 'l' { return 1; }
    if v.len == 7 && v[0] == 'r' { return 2; }
    return 0;
}

fn is_markdown(path: const u8[:]) -> bool {
    let n = path.len;
    if n >= 3 {
        if path[n - 3] == '.' {
            let a = path[n - 2];
            let b = path[n - 1];
            if (a == 'm' || a == 'M') && (b == 'd' || b == 'D') { return true; }
        }
    }
    if n >= 9 {
        if path[n - 9] == '.' {
            if (path[n - 8] == 'm' || path[n - 8] == 'M') && (path[n - 7] == 'a' || path[n - 7] == 'A') &&
               (path[n - 6] == 'r' || path[n - 6] == 'R') && (path[n - 5] == 'k' || path[n - 5] == 'K') &&
               (path[n - 4] == 'd' || path[n - 4] == 'D') && (path[n - 3] == 'o' || path[n - 3] == 'O') &&
               (path[n - 2] == 'w' || path[n - 2] == 'W') && (path[n - 1] == 'n' || path[n - 1] == 'N') {
                return true;
            }
        }
    }
    return false;
}

fn set_title(name: const u8[:]) {
    var t: u8[>..] = [];
    var k: i64 = 0;
    while k < name.len { t.push(name[k]); k++; }
    t.append(" - Mayoi");
    win::set_window_text(win::hwnd, win::u16z(t)[0]);
}

fn set_status(msg: const u8[:]) {
    state::status_msg.resize(0);
    var k: i64 = 0;
    while k < msg.len { state::status_msg.push(msg[k]); k++; }
    state::status_until = win::ticks() + 4000;
}

fn set_root(path: const u8[:]) {
    state::root.resize(0);
    var k: i64 = 0;
    while k < path.len { state::root.push(path[k]); k++; }
    state::root_name.resize(0);
    var i: i64 = path.len;
    var start: i64 = 0;
    while i > 0 {
        if path[i-1] == '/' || path[i-1] == '\\' { start = i; break; }
        i--;
    }
    var j: i64 = start;
    while j < path.len { state::root_name.push(path[j]); j++; }
    if state::root_name.len == 0 { state::root_name.append("winhx"); }
    tree::rebuild();
}

