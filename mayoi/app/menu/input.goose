// Opening, hovering, clicking and the keys of the menu.
namespace menu;

import ui.win;
import app.state;
import .model;
import .layout;
import .paint;
import .action;

fn open() {
    metrics();
    state::menu_open = true;
    state::menu_sel = -1;
    state::menu_row = -1;
    state::menu_p2 = -1;
    state::menu_fresh = true;
}

fn close() {
    state::menu_open = false;
    state::menu_sel = -1;
    state::menu_row = -1;
    state::menu_p2 = -1;
    win::invalidate();
}

fn in_rect(x: i32, y: i32, rx: i32, ry: i32, w: i32, h: i32) -> bool {
    return x >= rx && x < rx + w && y >= ry && y < ry + h;
}

// The row of the list lo..hi whose band covers y, in a panel whose top is y0.
fn hit_row(y0: i32, lo: i64, hi: i64, scroll: i32, y: i32) -> i64 {
    var ry = y0 + mpad - scroll;
    var i = lo;
    while i < hi {
        let h = row_height(menu::items[i]);
        if y >= ry && y < ry + h { return i; }
        ry += h;
        i++;
    }
    return -1;
}

fn hover(x: i32, y: i32) {
    if !state::menu_open { return; }
    metrics();
    if in_rect(x, y, pan_x, pan_y, pan_w, pan_h()) {
        var i: i32 = 0;
        while i < menu::top.len as i32 {
            let ry = pan_y + mpad + i * row_h;
            if y >= ry && y < ry + row_h {
                if state::menu_sel != i { p1_scroll = 0; p2_scroll = 0; }
                state::menu_sel = i;
                state::menu_row = -1;
                state::menu_p2 = -1;
                return;
            }
            i++;
        }
        return;
    }
    if state::menu_sel >= 0 && in_rect(x, y, p1_x(), p1_y(), p1_w, panel_h(p1_lo(), p1_hi())) {
        let r = hit_row(p1_y(), p1_lo(), p1_hi(), p1_scroll, y);
        if r >= 0 && menu::items[r].flags != menu::SEPARATOR {
            if state::menu_row != r {
                state::menu_row = r as i32;
                state::menu_p2 = -1;
                p2_scroll = 0;
            }
        }
        return;
    }
    if has_p2() && in_rect(x, y, p2_x(), p2_y(), p2_w, panel_h(p2_lo(), p2_hi())) {
        let r = hit_row(p2_y(), p2_lo(), p2_hi(), p2_scroll, y);
        if r >= 0 && menu::items[r].flags != menu::SEPARATOR {
            state::menu_p2 = r as i32;
        }
        return;
    }
    // elsewhere: the panels but the top one fold away, the menu stays
    if !in_rect(x, y, pan_x, pan_y, pan_w, pan_h()) {
        state::menu_sel = -1;
        state::menu_row = -1;
        state::menu_p2 = -1;
    }
}

// press returns true when the menu took the click.
fn press(x: i32, y: i32) -> bool {
    if !state::menu_open { return false; }
    metrics();
    let fresh = state::menu_fresh;
    state::menu_fresh = false;
    hover(x, y);
    if in_rect(x, y, pan_x, pan_y, pan_w, pan_h()) {
        if !fresh && state::menu_sel >= 0 {
            // a second click on the group's own row closes what it opened
            var i: i32 = 0;
            while i < menu::top.len as i32 {
                let ry = pan_y + mpad + i * row_h;
                if y >= ry && y < ry + row_h && i == state::menu_sel && state::menu_row < 0 {
                    close();
                    return true;
                }
                i++;
            }
        }
        state::menu_row = -1;
        state::menu_p2 = -1;
        win::invalidate();
        return true;
    }
    if has_p2() && in_rect(x, y, p2_x(), p2_y(), p2_w, panel_h(p2_lo(), p2_hi())) {
        let r = hit_row(p2_y(), p2_lo(), p2_hi(), p2_scroll, y);
        if r >= 0 {
            let i = r;
            close();
            run(i);
            return true;
        }
        return true;
    }
    if state::menu_sel >= 0 && in_rect(x, y, p1_x(), p1_y(), p1_w, panel_h(p1_lo(), p1_hi())) {
        let r = hit_row(p1_y(), p1_lo(), p1_hi(), p1_scroll, y);
        if r >= 0 {
            if menu::items[r].flags == menu::SUB {
                state::menu_row = r as i32;
                state::menu_p2 = -1;
                win::invalidate();
                return true;
            }
            let i = r;
            close();
            run(i);
            return true;
        }
        return true;
    }
    // a click anywhere else closes the menu and is not taken
    close();
    return false;
}

fn first_row(lo: i64, hi: i64) -> i32 {
    var i = lo;
    while i < hi {
        if menu::items[i].flags != menu::SEPARATOR { return i as i32; }
        i++;
    }
    return -1;
}

fn step_row(lo: i64, hi: i64, from: i64, dir: i64) -> i64 {
    var i: i64 = from + dir;
    while i >= lo && i < hi {
        if menu::items[i].flags != menu::SEPARATOR { return i; }
        i = i + dir;
    }
    return from;
}

// key returns true when the menu took the key.
fn key(vk: i32) -> bool {
    if !state::menu_open { return false; }
    metrics();
    if vk == 27 {
        if state::menu_p2 >= 0 { state::menu_p2 = -1; win::invalidate(); return true; }
        if state::menu_row >= 0 { state::menu_row = -1; win::invalidate(); return true; }
        close();
        return true;
    }
    if vk == 40 || vk == 38 {
        let dir: i32 = if vk == 40 { 1 } else { -1 };
        if state::menu_p2 >= 0 {
            state::menu_p2 = step_row(p2_lo(), p2_hi(), state::menu_p2 as i64, dir as i64) as i32;
        } else if state::menu_row >= 0 {
            state::menu_row = step_row(p1_lo(), p1_hi(), state::menu_row as i64, dir as i64) as i32;
        } else {
            var s: i32 = state::menu_sel + dir;
            if s < 0 { s = 0; }
            if s >= menu::top.len as i32 { s = menu::top.len as i32 - 1; }
            state::menu_sel = s;
        }
        win::invalidate();
        return true;
    }
    if vk == 39 {
        if state::menu_row >= 0 && has_p2() { state::menu_p2 = first_row(p2_lo(), p2_hi()); }
        else if state::menu_row < 0 && state::menu_sel >= 0 { state::menu_row = first_row(p1_lo(), p1_hi()); }
        win::invalidate();
        return true;
    }
    if vk == 37 {
        if state::menu_p2 >= 0 { state::menu_p2 = -1; }
        else if state::menu_row >= 0 { state::menu_row = -1; }
        else { close(); return true; }
        win::invalidate();
        return true;
    }
    if vk == 13 || vk == 32 {
        if state::menu_p2 >= 0 { let i = state::menu_p2 as i64; close(); run(i); return true; }
        if state::menu_row >= 0 {
            let i = state::menu_row as i64;
            if has_p2() { state::menu_p2 = first_row(p2_lo(), p2_hi()); win::invalidate(); return true; }
            close();
            run(i);
            return true;
        }
        if state::menu_sel >= 0 { state::menu_row = first_row(p1_lo(), p1_hi()); win::invalidate(); return true; }
        return true;
    }
    return true;
}

fn wheel(delta: i32) -> bool {
    if !state::menu_open { return false; }
    metrics();
    if has_p2() {
        p2_scroll = p2_scroll - delta * row_h;
        if p2_scroll < 0 { p2_scroll = 0; }
        if p2_scroll > p2_max_scroll() { p2_scroll = p2_max_scroll(); }
    } else if state::menu_sel >= 0 {
        p1_scroll = p1_scroll - delta * row_h;
        if p1_scroll < 0 { p1_scroll = 0; }
        if p1_scroll > p1_max_scroll() { p1_scroll = p1_max_scroll(); }
    }
    win::invalidate();
    return true;
}
