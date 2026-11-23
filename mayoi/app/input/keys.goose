// Keys: shortcuts, clipboard, and the editing verbs they fire.
namespace input;

import std;
import app.state;
import ui.theme;
import ui.win;
import editor.text;
import editor.syntax;
import editor.vim;
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
import app.ctxmenu;
import app.prefs.input;
import app.prefs.model;


fn key(vk: i32, ctrl: bool, shift: bool, alt: bool) -> bool {
    if prefs::open { return prefs::key(vk, ctrl, shift, alt); }
    if ctrl && vk == input::VK_COMMA {
        prefs::open_at(0);
        win::invalidate();
        return true;
    }
    if state::ren_active {
        if vk == input::VK_RET { input::commit_rename(); win::invalidate(); return true; }
        if vk == input::VK_ESC { input::cancel_rename(); win::invalidate(); return true; }
        if vk == input::VK_BACK { input::rename_char(8); return true; }
        return true;
    }
    if chrome::ctx_open {
        if vk == input::VK_ESC { chrome::ctx_close(); win::invalidate(); return true; }
        return true;
    }
    if state::overlay != 0 {
        if vk == input::VK_ESC { state::overlay = 0; win::invalidate(); return true; }
        if vk == input::VK_RET { input::open_selected(); win::invalidate(); return true; }
        if vk == input::VK_UP { if state::overlay_sel > 0 { state::overlay_sel--; win::invalidate(); } return true; }
        if vk == input::VK_DOWN { if state::overlay_sel < app::item_count - 1 { state::overlay_sel++; win::invalidate(); } return true; }
        if vk == input::VK_BACK {
            if state::query.len > 0 {
                state::query.resize(state::query.len - 1);
                app::recompute();
                win::invalidate();
            }
            return true;
        }
        return false;
    }
    if vim::on() && state::focus == 0 && state::cur >= 0 && state::overlay == 0 && !state::menu_open {
        if vim::key(vk, ctrl, shift, alt) { win::invalidate(); return true; }
    }
    if ctrl {
        if vk == input::VK_S { input::save_file(); return true; }
        if vk == input::VK_O { input::open_file_dialog(); return true; }
        if vk == input::VK_N { input::new_file(); return true; }
        if vk == input::VK_P { if shift { app::overlay_open(1); } else { app::overlay_open(2); } win::invalidate(); return true; }
        if vk == input::VK_F { app::overlay_open(3); win::invalidate(); return true; }
        if vk == input::VK_A { let d .= state::docs[state::cur]; d.sel_a = 0; d.sel_b = d.len; input::ensure_visible(); win::invalidate(); return true; }
        if vk == input::VK_C { input::copy(); return true; }
        if vk == input::VK_X { input::copy(); input::backspace(); return true; }
        if vk == input::VK_V { input::paste(); return true; }
        if vk == input::VK_Z { text::undo_edit(); syntax::invalidate(); input::ensure_visible(); win::invalidate(); return true; }
        if vk == input::VK_Y { text::redo_edit(); syntax::invalidate(); input::ensure_visible(); win::invalidate(); return true; }
        if vk == input::VK_G { app::overlay_open(1); win::invalidate(); return true; }
        if vk == input::VK_H && shift {
            state::view = 2;
            state::sidebar_open = true;
            state::focus = 1;
            state::search_replacing = true;
            state::search_field = 0;
            win::invalidate();
            return true;
        }
        return false;
    }
    if state::cur < 0 { return false; }
    if vk == input::VK_BACK { input::backspace(); win::invalidate(); return true; }
    if vk == input::VK_DEL { input::delete_forward(); win::invalidate(); return true; }
    if vk == input::VK_RET { input::newline(); win::invalidate(); return true; }
    if vk == input::VK_TAB {
        let d .= state::docs[state::cur];
        var t: u8[>..] = [];
        t.push('\t');
        input::typed(t);
        win::invalidate();
        return true;
    }
    if vk == input::VK_LEFT { if ctrl { input::word_move(-1, shift); } else { input::col_move(-1, shift); } win::invalidate(); return true; }
    if vk == input::VK_RIGHT { if ctrl { input::word_move(1, shift); } else { input::col_move(1, shift); } win::invalidate(); return true; }
    if vk == input::VK_UP { input::line_move(-1, shift); win::invalidate(); return true; }
    if vk == input::VK_DOWN { input::line_move(1, shift); win::invalidate(); return true; }
    if vk == input::VK_HOME {
        let d .= state::docs[state::cur];
        let line, col = text::line_col(d.sel_b);
        input::move_caret(text::line_start(line), shift);
        win::invalidate();
        return true;
    }
    if vk == input::VK_END {
        let d .= state::docs[state::cur];
        let line, col = text::line_col(d.sel_b);
        input::move_caret(text::line_end(line), shift);
        win::invalidate();
        return true;
    }
    if vk == input::VK_PGUP { input::line_move(-input::visible_rows(), shift); win::invalidate(); return true; }
    if vk == input::VK_PGDN { input::line_move(input::visible_rows(), shift); win::invalidate(); return true; }
    return false;
}

fn copy() {
    if state::cur < 0 { return; }
    let d .= state::docs[state::cur];
    let a = text::sel_min(state::cur);
    let e = text::sel_max(state::cur);
    if a == e { return; }
    let n = win::gs_clip_put(state::arena[d.off + a], e - a);
    if n > 0 { app::set_status("已复制"); }
}

fn paste() {
    if state::cur < 0 { return; }
    input::lexicographic_marker();
    var buf: u8[..65536] = [];
    var c: u8[..65536] = [];
    let n = win::gs_clip_get(c[0], 65535);
    if n <= 0 { return; }
    var k: i64 = 0;
    var t: u8[>..] = [];
    while k < n { t.push(c[k]); k++; }
    input::typed(t);
    app::set_status("");
    win::invalidate();
}
