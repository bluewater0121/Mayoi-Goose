// New files, dialogs, saving and closing: the file verbs.
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


fn new_file() {
    let i = text::untitled();
    state::cur = i;
    state::focus = 0;
    syntax::invalidate();
    text::reindex();
    app::set_title(state::docs[i].name);
    win::invalidate();
}

fn open_file_dialog() {
    var buf: u8[>..] = [];
    buf.resize(4096, 0);
    let n = win::pick_file(win::hwnd, buf[0], 4096);
    if n > 0 {
        buf.resize(n);
        app::open_path(buf);
    }
    win::invalidate();
}

fn open_folder_dialog() {
    var buf: u8[>..] = [];
    buf.resize(4096, 0);
    let n = win::pick_folder(win::hwnd, buf[0], 4096);
    if n > 0 {
        buf.resize(n);
        app::open_folder(buf);
        state::view = 1;
    }
    win::invalidate();
}

fn save_file() {
    if state::cur < 0 || state::docs.len == 0 { return; }
    if text::save_doc(state::cur) {
        state::docs[state::cur].dirty = false;
        app::set_status("已保存");
    } else {
        app::set_status("无法保存");
    }
    win::invalidate();
}

fn close_tab(i: i32) {
    if i < 0 || i >= state::docs.len as i32 { return; }
    var k: i32 = i;
    while k + 1 < state::docs.len as i32 {
        state::docs[k] = state::docs[k + 1];
        k++;
    }
    state::docs.resize(state::docs.len - 1);
    if state::cur >= state::docs.len as i32 { state::cur = state::docs.len as i32 - 1; }
    if state::cur < 0 { state::cur = 0; }
    if state::docs.len == 0 { state::cur = -1; }
    syntax::invalidate();
    text::reindex();
    win::invalidate();
}

fn open_selected() {
    if state::overlay == 2 {
        app::open_overlay_row(state::overlay_sel);
        return;
    }
    input::command(state::overlay_sel);
    state::overlay = 0;
    win::invalidate();
}
