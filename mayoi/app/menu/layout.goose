// Where the menu panels sit, and how tall each of their rows is, so that the
// paint and the pointer agree without either asking the other.
namespace menu;

import ui.win;
import ui.theme;
import app.state;
import .model;

var row_h: i32 = 0;
var mpad: i32 = 0;
var pan_x: i32 = 0;
var pan_y: i32 = 0;
var pan_w: i32 = 0;
var p1_w: i32 = 0;
var p2_w: i32 = 0;
var sep_h: i32 = 0;
var p1_scroll: i32 = 0;
var p2_scroll: i32 = 0;

fn metrics() {
    menu::build();
    row_h = state::px(30);
    sep_h = state::px(9);
    mpad = state::px(6);
    pan_x = state::px(14);
    pan_y = state::title_h + state::px(2);
    var widest: i32 = 0;
    var i: i64 = 0;
    while i < menu::top.len {
        let w = win::measure(state::f_ui, menu::label_at(menu::top[i]));
        if w > widest { widest = w; }
        i++;
    }
    pan_w = state::px(14) + widest + state::px(16) + state::px(12);
    var w1: i32 = 0;
    var w2: i32 = 0;
    i = 0;
    while i < menu::items.len {
        let it = menu::items[i];
        if it.depth == 1 {
            var w = win::measure(state::f_ui, menu::label_at(i));
            if it.flags == menu::SUB { w = w + state::px(20); }
            if it.accel.len > 0 {
                w = w + state::px(32) + win::measure(state::f_small, menu::accel_at(i));
            }
            if w > w1 { w1 = w; }
        } else if it.depth == 2 {
            var w = win::measure(state::f_ui, menu::label_at(i));
            if it.accel.len > 0 {
                w = w + state::px(28) + win::measure(state::f_small, menu::accel_at(i));
            }
            if w > w2 { w2 = w; }
        }
        i++;
    }
    p1_w = w1 + state::px(24);
    if p1_w < state::px(210) { p1_w = state::px(210); }
    p2_w = w2 + state::px(24);
    if p2_w < state::px(170) { p2_w = state::px(170); }
}

fn pan_h() -> i32 {
    return mpad * 2 + (menu::top.len as i32) * row_h;
}

fn p1_x() -> i32 { return pan_x + pan_w - state::px(2); }
fn p2_x() -> i32 { return p1_x() + p1_w - state::px(2); }

fn group_of_top(t: i32) -> i64 { return menu::top[t]; }

fn row_height(it: const Item&) -> i32 {
    if it.flags == menu::SEPARATOR { return sep_h; }
    return row_h;
}

// The y of the row i of the panel that lists entries lo..hi-1, whose top is y0.
fn row_y(y0: i32, lo: i64, hi: i64, at: i64) -> i32 {
    var y = y0 + mpad;
    var i = lo;
    while i < at && i < hi {
        y += row_height(menu::items[i]);
        i++;
    }
    return y;
}

fn panel_h(lo: i64, hi: i64) -> i32 {
    var h = mpad * 2;
    var i = lo;
    while i < hi {
        h += row_height(menu::items[i]);
        i++;
    }
    return h;
}

// pane1: the group's entries; its top aligns with the hovered group row.
fn p1_y() -> i32 {
    if state::menu_sel < 0 { return pan_y; }
    var y = pan_y + mpad + (state::menu_sel * row_h) - state::px(4);
    if y < state::px(4) { y = state::px(4); }
    return y;
}

fn p1_lo() -> i64 {
    if state::menu_sel < 0 { return 0; }
    return menu::top[state::menu_sel] + 1;
}

fn p1_hi() -> i64 {
    if state::menu_sel < 0 { return 0; }
    return menu::group_end(menu::top[state::menu_sel]);
}

// pane2: the children of the pane1 row at menu_row, when it opens a submenu.
fn p2_lo() -> i64 { return state::menu_row + 1; }

fn p2_hi() -> i64 {
    var i = state::menu_row + 1;
    while i < menu::items.len && menu::items[i].depth == 2 { i++; }
    return i;
}

fn p2_y() -> i32 {
    var y = row_y(p1_y() + mpad - p1_scroll, p1_lo(), p1_hi(), state::menu_row) - mpad - state::px(4);
    if y < state::px(4) { y = state::px(4); }
    return y;
}

fn p1_view_h() -> i32 {
    let h = panel_h(p1_lo(), p1_hi());
    let room = state::H - state::px(8) - p1_y();
    if h > room { return room; }
    return h;
}

fn p2_view_h() -> i32 {
    let h = panel_h(p2_lo(), p2_hi());
    let room = state::H - state::px(8) - p2_y();
    if h > room { return room; }
    return h;
}

fn p1_max_scroll() -> i32 {
    let room = state::H - state::px(8) - p1_y();
    let h = panel_h(p1_lo(), p1_hi());
    if h - room > 0 { return h - room; }
    return 0;
}

fn p2_max_scroll() -> i32 {
    let room = state::H - state::px(8) - p2_y();
    let h = panel_h(p2_lo(), p2_hi());
    if h - room > 0 { return h - room; }
    return 0;
}

fn has_p2() -> bool {
    if state::menu_row < 0 { return false; }
    return menu::items[state::menu_row].flags == menu::SUB;
}
