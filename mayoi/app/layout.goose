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

fn fonts() {
    state::f_ui = win::font(state::px(16), 400, "Segoe UI");
    state::f_ui_b = win::font(state::px(16), 600, "Segoe UI");
    state::f_small = win::font(state::px(15), 400, "Segoe UI");
    state::f_small_b = win::font(state::px(15), 600, "Segoe UI");
    state::f_tree = win::font(state::px(13), 400, "Segoe UI");
    state::f_code = win::fontw(state::px(16), state::px(9), 400, "Consolas");
    state::f_title = win::font(state::px(30), 600, "Segoe UI");
    state::f_code_small = win::font(state::px(14), 400, "Consolas");
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
    return true;
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

