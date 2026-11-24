// The pointer: hits, clicks and drags.
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
import app.ctxmenu;
import app.prefs.input;
import app.prefs.model;


fn mouse_down(x: i32, y: i32, button: i32) {
    state::mx = x;
    state::my = y;
    if prefs::open {
        prefs::click(x, y);
        win::invalidate();
        return;
    }
    if state::ren_active {
        input::commit_rename();
        win::invalidate();
        return;
    }
    if chrome::ctx_open {
        let act = chrome::ctx_action_at(x, y);
        chrome::ctx_close();
        if act >= 0 { input::ctx_run(act); }
        win::invalidate();
        return;
    }
    var pj: i32 = -1;
    var jj = state::hits.len - 1;
    while jj >= 0 {
        let hh = state::hits[jj];
        if hh.kind == state::HIT_ACTIVITY && hh.arg >= 10 {
            if x >= hh.x && x < hh.x + hh.w && y >= hh.y && y < hh.y + hh.h {
                pj = jj as i32;
                break;
            }
        }
        jj--;
    }
    if pj >= 0 {
        app::proj_switch((state::hits[pj as i64].arg - 10) as i32);
        return;
    }
    let hi = state::find_hit(x, y);
    if hi < 0 { return; }
    let h = state::hits[hi as i64];
    if state::overlay == 0 && chrome::sidebar_click(h.kind, h.arg) { return; }
    if state::overlay != 0 {
        if h.kind == state::HIT_OVERLAY && h.arg > 0 {
            state::overlay_sel = (h.arg - 1) as i32;
            input::open_selected();
            win::invalidate();
            return;
        }
        if h.kind != state::HIT_OVERLAY { state::overlay = 0; }
    }
    if h.kind == state::HIT_CHEVRON {
        state::focus = 1;
        tree::focus_row = h.arg as i32;
        tree::toggle(h.arg as i32);
        win::invalidate();
        return;
    }
    if h.kind == state::HIT_TREE_SCROLL {
        state::drag = 4;
        state::drag_base = state::tree_off;
        state::drag_y0 = y;
        win::set_capture(win::hwnd);
        return;
    }
    if h.kind == state::HIT_TREEROW {
        state::focus = 1;
        if h.arg < 0 {
            state::cur = (-1 - h.arg) as i32;
            syntax::invalidate();
            text::reindex();
            win::invalidate();
            return;
        }
        tree::focus_row = h.arg as i32;
        input::open_row(tree::focus_row);
        return;
    }
    if h.kind == state::HIT_TAB {
        state::cur = h.arg as i32;
        syntax::invalidate();
        text::reindex();
        win::invalidate();
        return;
    }
    if h.kind == state::HIT_TAB_CLOSE { input::close_tab(h.arg as i32); win::invalidate(); return; }
    if h.kind == state::HIT_ACTIVITY {
        state::view = h.arg as i32;
        if !state::sidebar_open { state::sidebar_open = true; }
        win::invalidate();
        return;
    }
    if h.kind == state::HIT_TOGGLE_SIDEBAR { state::sidebar_open = !state::sidebar_open; win::invalidate(); return; }
    if h.kind == state::HIT_TOGGLE_TERM {
        state::panel_open = true;
        state::panel_tab = 2;
        state::focus = 2;
        win::invalidate();
        return;
    }
    if h.kind == state::HIT_CLOSE_PANEL { state::panel_open = false; win::invalidate(); return; }
    if h.kind == state::HIT_PANEL_TAB { state::panel_tab = h.arg as i32; win::invalidate(); return; }
    if h.kind == state::HIT_CMD { app::overlay_open(2); win::invalidate(); return; }
    if h.kind == state::HIT_SPLITTER {
        state::drag = 3;
        state::drag_base = if h.arg == 1 { state::sidebar_w } else { state::panel_h };
        state::drag_y0 = y;
        state::drag_x0 = x;
        win::set_capture(win::hwnd);
        return;
    }
    if h.kind == state::HIT_RULE {
        state::focus = 0;
        if h.arg == 1 { input::new_file(); }
        else if h.arg == 2 { input::open_file_dialog(); }
        else if h.arg == 3 { input::open_folder_dialog(); }
        else if h.arg == 4 { app::overlay_open(2); }
        else if h.arg == 5 { app::overlay_open(1); }
        else if h.arg == 10 { win::show_window(win::hwnd, 6); }
        else if h.arg == 11 {
            if win::is_zoomed(win::hwnd) { win::show_window(win::hwnd, 9); }
            else { win::show_window(win::hwnd, 3); }
        }
        else if h.arg == 12 { win::post_message(win::hwnd, 0x0010, 0, 0); }
        win::invalidate();
        return;
    }
    if h.kind == state::HIT_SIDEBAR_ACTION {
        if h.arg == 1 { input::new_file(); }
        else if h.arg == 2 { }
        else if h.arg == 3 { tree::rebuild(); }
        else if h.arg == 4 { state::sidebar_w = state::px(318); }
        win::invalidate();
        return;
    }
    if h.kind == state::HIT_CARET {
        if h.arg == 1 && state::panel_open && state::panel_tab == 2 {
            state::focus = 2;
            win::invalidate();
            return;
        }
        state::focus = 0;
        if h.arg == 0 {
            state::drag = 1;
            input::click_editor(x, y, false);
            win::set_capture(win::hwnd);
            win::invalidate();
        }
        return;
    }
    if h.kind == state::HIT_OVERLAY { return; }
}

fn mouse_up(x: i32, y: i32) {
    if state::drag == 1 { input::mouse_move(x, y); }
    state::drag = 0;
    win::invalidate();
}

fn mouse_move(x: i32, y: i32) {
    state::mx = x;
    state::my = y;
    if prefs::open {
        prefs::hover_at(x, y);
        return;
    }
    if chrome::ctx_open {
        chrome::ctx_hover(x, y);
        return;
    }
    if state::drag == 4 {
        let n = tree::rows.len as i32;
        if n > state::tree_vis && state::tree_vis > 0 {
            var range = state::tree_track - state::tree_thumb;
            if range < 1 { range = 1; }
            let d = (y - state::drag_y0) * (n - state::tree_vis) / range;
            state::tree_off = state::drag_base + d;
            tree::clamp_off();
            win::invalidate();
        }
        return;
    }
    if state::drag == 1 {
        input::click_editor(x, y, true);
        win::invalidate();
        return;
    }
    if state::drag == 3 {
        let h = state::hits[state::hits.len - 1];
        if state::drag_base == state::sidebar_w || h.arg == 1 {
            var w = state::drag_base + (x - state::drag_x0);
            if w < state::px(160) { w = state::px(160); }
            if w > state::W / 2 { w = state::W / 2; }
            state::sidebar_w = w;
        }
        // the panel splitter is hit by its own id
        var hh = state::panel_h - (y - state::drag_y0);
        if hh < state::px(80) { hh = state::px(80); }
        if hh > state::H / 2 { hh = state::H / 2; }
        state::panel_h = hh;
        win::invalidate();
        return;
    }
    let hi = state::find_hit(x, y);
    if hi >= 0 {
        let h = state::hits[hi as i64];
        if h.kind != state::hover_kind || h.arg != state::hover_arg {
            state::hover_kind = h.kind;
            state::hover_arg = h.arg;
            win::invalidate();
        }
    }
}
