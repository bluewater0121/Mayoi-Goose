// The command palette and the rows it runs.
namespace input;

import std;
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
import editor.editor;
import app.layout;
import app.view;
import app.overlay;


fn command(idx: i32) {
    state::overlay = 0;
    if idx == 0 { input::new_file(); return; }
    if idx == 1 { input::open_file_dialog(); return; }
    if idx == 2 { input::open_folder_dialog(); return; }
    if idx == 3 { input::save_file(); return; }
    if idx == 4 { input::save_file(); return; }
    if idx == 5 { state::sidebar_open = !state::sidebar_open; win::invalidate(); return; }
    if idx == 6 { state::panel_open = !state::panel_open; win::invalidate(); return; }
    if idx == 7 { app::overlay_open(3); win::invalidate(); return; }
    if idx == 8 { app::overlay_open(3); win::invalidate(); return; }
    if idx == 9 { app::overlay_open(1); win::invalidate(); return; }
    if idx == 10 { theme::set_light(); win::invalidate(); return; }
    if idx == 11 { theme::set_dark(); win::invalidate(); return; }
    if idx == 12 { input::zoom(1); return; }
    if idx == 13 { input::zoom(-1); return; }
    if idx == 14 { input::zoom(0); return; }
    if idx == 15 { input::close_tab(state::cur); return; }
    if idx == 16 { win::invalidate(); return; }
}

fn zoom(dir: i32) {
    if dir > 0 {
        if state::s < 3 { state::s = state::s + 1; }
    } else if dir < 0 {
        if state::s > 1 { state::s = state::s - 1; }
    } else {
        state::s = 1;
    }
    app::layout();
    app::fonts();
    win::invalidate();
}

fn command_label(i: i32) -> u8[>..] {
    var out: u8[>..] = [];
    var idx: i32 = 0;
    var k: i64 = 0;
    var start: i64 = 0;
    while k <= app::commands.len {
        if k == app::commands.len || app::commands[k] == 0 {
            if k > start {
                if idx == i { out.append(app::commands[start..k]); return out; }
                idx++;
            }
            start = k + 1;
        }
        k++;
    }
    return out;
}

fn same(a: const u8[:], b: const u8[:]) -> bool {
    if a.len != b.len { return false; }
    var i: i64 = 0;
    while i < a.len {
        if a[i] != b[i] { return false; }
        i++;
    }
    return true;
}

fn open_row(idx: i32) {
    if idx < 0 || idx >= tree::rows.len as i32 { return; }
    let r = tree::rows[idx];
    if r.dir {
        tree::toggle(idx);
    } else {
        app::open_path(r.path);
    }
    win::invalidate();
}

fn overlay_char(c: u16) {
    if state::overlay == 0 { return; }
    if c < 32 { return; }
    text::push_char(&state::query, c);
    app::recompute();
    win::invalidate();
}

fn next_tab(dir: i32) {
    if state::docs.len == 0 { return; }
    var i = state::cur + dir;
    if i < 0 { i = 0; }
    if i >= state::docs.len as i32 { i = state::docs.len as i32 - 1; }
    state::cur = i;
    syntax::invalidate();
    text::reindex();
    win::invalidate();
}
