// The three panels of the menu: the groups, an open group, and a nested list.
namespace menu;

import ui.win;
import ui.theme;
import app.state;
import app.icons;
import .model;
import .layout;

fn backdrop(x: i32, y: i32, w: i32, h: i32) {
    let p = theme::pal;
    win::fill(x + state::px(3), y + state::px(3), (w - 3) as i64, h - 3, p.shadow);
    win::fill(x, y, w as i64, h, p.surface);
    win::line(x, y, x + w - 1, y, p.border, 1);
    win::line(x, y + h - 1, x + w - 1, y + h - 1, p.border, 1);
    win::line(x, y, x, y + h - 1, p.border, 1);
    win::line(x + w - 1, y, x + w - 1, y + h - 1, p.border, 1);
}

fn row_bg(x: i32, y: i32, w: i32, h: i32, hot: bool) {
    let p = theme::pal;
    if hot { win::fill(x + 1, y, (w - 2) as i64, h, p.active); }
}

fn sep_line(x: i32, y: i32, w: i32) {
    let p = theme::pal;
    win::line(x + state::px(12), y + state::px(4), x + w - state::px(12), y + state::px(4), p.border, 1);
}

// A label, its accelerator on the right, and a check mark or a submenu arrow.
fn row_text(x: i32, y: i32, w: i32, h: i32, i: i64) {
    let p = theme::pal;
    let it = menu::items[i];
    let col = if it.flags == menu::DISABLED { p.faint } else { p.text };
    if it.flags == menu::CHECKED {
        chrome::icon_at(43, x + state::px(4), y + (h - state::px(12)) / 2, state::px(12), col);
    }
    win::text_at(state::f_ui, x + state::px(14), y + (h - win::th(state::f_ui)) / 2, menu::label_at(i), col);
    if it.flags == menu::SUB {
        chrome::icon_at(7, x + w - state::px(18), y + (h - state::px(12)) / 2, state::px(12), p.muted);
    } else if it.accel.len > 0 {
        let aw = win::measure(state::f_small, menu::accel_at(i));
        win::text_at(state::f_small, x + w - state::px(12) - aw, y + (h - win::th(state::f_small)) / 2,
            menu::accel_at(i), p.faint);
    }
}

fn paint_top() {
    var i: i32 = 0;
    while i < menu::top.len as i32 {
        let y = pan_y + mpad + i * row_h;
        row_bg(pan_x, y, pan_w, row_h, i == state::menu_sel);
        let t = menu::top[i];
        win::text_at(state::f_ui, pan_x + state::px(14), y + (row_h - win::th(state::f_ui)) / 2,
            menu::label_at(t), theme::pal.text);
        chrome::icon_at(7, pan_x + pan_w - state::px(18), y + (row_h - state::px(12)) / 2, state::px(12),
            if i == state::menu_sel { theme::pal.text } else { theme::pal.muted });
        i++;
    }
}

fn paint_group() {
    if state::menu_sel < 0 { return; }
    let lo = p1_lo();
    let hi = p1_hi();
    let top = p1_y();
    let bottom = top + p1_view_h();
    var i = lo;
    var y = top + mpad - p1_scroll;
    while i < hi && y < bottom {
        let h = row_height(menu::items[i]);
        if y + h > top + 1 {
            if menu::items[i].flags == menu::SEPARATOR {
                if y >= top { sep_line(p1_x(), y, p1_w); }
            } else {
                row_bg(p1_x(), y, p1_w, h, i == state::menu_row);
                row_text(p1_x(), y, p1_w, h, i);
            }
        }
        y += h;
        i++;
    }
}

fn paint_children() {
    if !has_p2() { return; }
    let top = p2_y();
    let bottom = top + p2_view_h();
    var i = p2_lo();
    var y = top + mpad - p2_scroll;
    while i < p2_hi() && y < bottom {
        let h = row_height(menu::items[i]);
        if y + h > top + 1 {
            if menu::items[i].flags == menu::SEPARATOR {
                if y >= top { sep_line(p2_x(), y, p2_w); }
            } else {
                row_bg(p2_x(), y, p2_w, h, i == state::menu_p2);
                row_text(p2_x(), y, p2_w, h, i);
            }
        }
        y += h;
        i++;
    }
}

fn paint() {
    metrics();
    if !state::menu_open { return; }
    backdrop(pan_x, pan_y, pan_w, pan_h());
    paint_top();
    if state::menu_sel >= 0 {
        backdrop(p1_x(), p1_y(), p1_w, p1_view_h());
        paint_group();
        if has_p2() {
            backdrop(p2_x(), p2_y(), p2_w, p2_view_h());
            paint_children();
        }
    }
}
