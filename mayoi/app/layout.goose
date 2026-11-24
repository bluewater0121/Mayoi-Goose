// The frame's measurements, its fonts, and the folder and document it shows.
namespace app;
import std;
import os;
import i18n;
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
var term_cwd: u8[>..] = [];     // where the next command of the panel runs
var output: u8[>..] = [];       // the Output channel: what commands told us
var term_input: u8[>..] = [];
var show_welcome: bool = true;

fn layout() {
    state::s = 1;
    state::title_h = state::px(28);   // the app menu bar under the native caption
    state::tab_h = state::px(42);
    state::crumb_h = state::px(41);
    state::status_h = state::px(30);
    state::panel_head = state::px(34);
    if state::panel_h == 0 { state::panel_h = state::px(240); }
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
    if projects_on() { proj_load(); }
    let li = prefs::index_of("locale");
    if li >= 0 {
        let lv = prefs::value(li);
        var l: i32 = 0;
        if lv.len == 2 && lv[0] == 'e' { l = 1; }
        if lv.len == 2 && lv[0] == 'j' { l = 2; }
        i18n::set_lang(l);
        prefs::reload();
    }
    let a = prefs::index_of("appearance");
    var light = false;
    if a >= 0 {
        let v = prefs::value(a);
        if v.len == 1 && v[0] == '1' { light = true; }
        if v.len == 5 && v[0] == 'l' { light = true; }
    }
    if light { theme::set_light(); } else { theme::set_dark(); }
    let ti = prefs::index_of("theme");
    if ti >= 0 {
        let tv = prefs::value(ti);
        if tv.len > 0 { theme::set_named(tv[0..tv.len]); }
    }
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
    let m = i18n::t(msg);
    state::status_msg.resize(0);
    var k: i64 = 0;
    while k < m.len { state::status_msg.push(m[k]); k++; }
    if output.len > 24000 { output.resize(0); }
    output.append(msg);
    output.push('\n');
    state::status_until = win::ticks() + 4000;
}

fn set_root(path: const u8[:]) {
    if projects_on() {
        let found = proj_find(path);
        if found >= 0 { state::pcur = found; }
        else {
            proj_push(path);
            state::pcur = state::pn - 1;
        }
    }
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
    prefs::store_load();
    prefs::folder_load();
    apply_settings();
}

// --- project tabs -------------------------------------------------------------

fn projects_on() -> bool {
    let i = prefs::index_of("projectTabs");
    if i < 0 { return false; }
    return prefs::is_true(i);
}

fn same(a: const u8[:], b: const u8[:]) -> bool {
    if a.len != b.len { return false; }
    var i: i64 = 0;
    while i < a.len { if a[i] != b[i] { return false; } i++; }
    return true;
}

fn proj_start(i: i32) -> i64 {
    var k: i64 = 0;
    var idx: i32 = 0;
    while idx < i {
        while k < state::pbuf.len && state::pbuf[k] != 0 { k++; }
        k++;
        idx++;
    }
    return k;
}

fn proj_len(i: i32) -> i32 {
    var k: i64 = proj_start(i);
    var n: i64 = 0;
    while k + n < state::pbuf.len && state::pbuf[k + n] != 0 { n++; }
    return n as i32;
}

fn proj_slice(i: i32) -> u8[:] {
    var a: i64 = proj_start(i);
    return state::pbuf[a..a + proj_len(i) as i64];
}

fn proj_find(path: const u8[:]) -> i32 {
    var i: i32 = 0;
    while i < state::pn {
        if proj_len(i) == (path.len as i32) {
            let a: i64 = proj_start(i);
            var k: i64 = 0;
            var same = true;
            while k < path.len {
                if state::pbuf[a + k] != path[k] { same = false; break; }
                k++;
            }
            if same { return i; }
        }
        i++;
    }
    return -1;
}

fn proj_push(path: const u8[:]) {
    if proj_find(path) >= 0 { return; }
    var k: i64 = 0;
    while k < path.len { state::pbuf.append(path[k..k+1]); k++; }
    let z: u8[1] = [0];
    state::pbuf.append(z[0..1]);
    state::pn++;
}

fn proj_switch(i: i32) {
    if i < 0 || i >= state::pn { return; }
    state::pcur = i;
    set_root(proj_slice(i));
    proj_save();
    win::invalidate();
}

// projects.txt under the config directory keeps one folder path a line, the
// way the reference remembers the folders of the window.
fn proj_file() -> u8[>..] {
    var d = prefs::app_data_dir();
    return prefs::join2(d[0..d.len], "\\projects.txt");
}

fn proj_save() {
    var out: u8[>..] = [];
    var i: i32 = 0;
    while i < state::pn {
        out.append(proj_slice(i));
        out.push('\n');
        i++;
    }
    write_file(proj_file()[0..proj_file().len], out[0..out.len]);
}

var projs_loaded = false;
fn proj_load() {
    if projs_loaded { return; }
    projs_loaded = true;
    var buf: u8[>..] = [];
    if !read_file(proj_file()[0..proj_file().len], buf) { return; }
    var start: i64 = 0;
    var k: i64 = 0;
    while k <= buf.len {
        if k == buf.len || buf[k] == '\n' {
            if k > start {
                let line = buf[start..k];
                if !same(line, state::root[0..state::root.len]) && proj_find(line) < 0 { proj_push(line); }
            }
            start = k + 1;
        }
        k++;
    }
    let ri = proj_find(state::root);
    if ri >= 0 { state::pcur = ri; }
}

fn open_folder(path: const u8[:]) {
    if projects_on() {
        let i = proj_find(path);
        if i >= 0 {
            state::pcur = i;
            set_root(path);
            return;
        }
        proj_push(path);
        state::pcur = state::pn - 1;
    }
    set_root(path);
}

