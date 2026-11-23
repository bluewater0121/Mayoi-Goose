// The settings window, as the reference draws its own: a search and the
// sections on the left, the fields of the section chosen on the right.
namespace prefs;

import std;
import ui.win;
import ui.theme;
import app.state;
import app.icons;
import app.menu.model;
import .model;
import .plugbody;

var ox: i32 = 0;
var oy: i32 = 0;
var ow: i32 = 0;
var oh: i32 = 0;
var nav_w: i32 = 0;
var body_y: i32 = 0;
var body_b: i32 = 0;
var rows_y: i32 = 0;
var rows_b: i32 = 0;
var card_x: i32 = 0;
var card_w: i32 = 0;

fn pbox(x: i32, y: i32, w: i32, h: i32, focused: bool) {
    let p = theme::pal;
    win::fill(x, y, w as i64, h, p.surface);
    let c = if focused { p.accent } else { p.border };
    win::line(x, y, x + w - 1, y, c, 1);
    win::line(x, y + h - 1, x + w - 1, y + h - 1, c, 1);
    win::line(x, y, x, y + h - 1, c, 1);
    win::line(x + w - 1, y, x + w - 1, y + h - 1, c, 1);
}

fn pf(f: u64, x: i32, y: i32, s: const u8[:], c: u32) {
    win::text_at(f, x, y, s, c);
}

fn pfit(f: u64, x: i32, y: i32, s: const u8[:], maxw: i32, c: u32) {
    if s.len == 0 { return; }
    if win::measure(f, s) <= maxw { win::text_at(f, x, y, s, c); return; }
    var n: i64 = s.len;
    while n > 1 {
        if win::measure(f, s[0..n]) + state::px(8) <= maxw { break; }
        n--;
    }
    win::text_at(f, x, y, s[0..n], c);
    win::text_at(f, x + win::measure(f, s[0..n]), y, "…", c);
}

// wrap_bounds is where the first line of the text ends: the words of it, or
// a character when there is no room for a word.
fn wrap_bounds(s: const u8[:], start: i64, maxw: i32, tw: i32) -> i64 {
    let rem = s.len - start;
    var n: i64 = (rem * (maxw as i64)) / (tw as i64) + 1;
    if n > rem { n = rem; }
    if n < 1 { n = 1; }
    let f = state::f_prefs;
    while n > 1 && win::measure(f, s[start..start + n]) > maxw { n--; }
    var m: i64 = n;
    var found: i64 = -1;
    while m > 1 && m + 8 > n {
        if s[start + m - 1] == ' ' { found = m - 1; }
        m--;
    }
    if found > 0 && found < n { n = found; }
    if n <= 0 { n = 1; }
    return n;
}

fn draw_wrap(f: u64, x: i32, y: i32, s: const u8[:], maxw: i32, lh: i32, c: u32) -> i32 {
    if s.len == 0 { return 0; }
    let totalw = win::measure(f, s);
    if totalw <= maxw { win::text_at(f, x, y, s, c); return lh; }
    var start: i64 = 0;
    var line: i32 = 0;
    var tw = totalw;
    while start < s.len && line < 6 {
        let n = wrap_bounds(s, start, maxw, tw);
        win::text_at(f, x, y + line * lh, s[start..start + n], c);
        start = start + n;
        if start < s.len && s[start] == ' ' { start++; }
        line++;
        tw = win::measure(f, s[start..s.len]);
        if tw < 1 { break; }
    }
    return line * lh;
}

fn wrap_h(s: const u8[:], maxw: i32, lh: i32) -> i32 {
    if s.len == 0 { return 0; }
    let totalw = win::measure(state::f_prefs, s);
    if totalw <= maxw { return lh; }
    var start: i64 = 0;
    var lines: i32 = 0;
    var tw = totalw;
    while start < s.len && lines < 6 {
        let n = wrap_bounds(s, start, maxw, tw);
        start = start + n;
        if start < s.len && s[start] == ' ' { start++; }
        lines++;
        tw = win::measure(state::f_prefs, s[start..s.len]);
        if tw < 1 { break; }
    }
    return lines * lh;
}

fn wide_kind(i: i32) -> bool {
    let k = prefs::flds[i].kind;
    return k == prefs::K_LIST || k == prefs::K_JSON || k == prefs::K_STYLES;
}

fn ctrl_w(i: i32) -> i32 {
    let k = prefs::flds[i].kind;
    if k == prefs::K_BOOL { return state::px(40); }
    if k == prefs::K_ENUM { return state::px(150); }
    if k == prefs::K_NUM { return state::px(104); }
    if k == prefs::K_TEXT { return state::px(190); }
    return 0;
}

fn row_height(i: i32, textw: i32) -> i32 {
    let lh = state::px(17);
    var h = state::px(12) + state::px(18) + state::px(3);
    h = h + wrap_h(prefs::flds[i].desc[0..prefs::flds[i].desc.len], textw, lh);
    h = h + state::px(4) + state::px(14);
    if wide_kind(i) { h = h + state::px(34); }
    return h + state::px(12);
}

fn frame() {
    let p = theme::pal;
    let W = state::W;
    let H = state::H;
    win::fill(0, 0, W, H, win::mix(p.chrome, p.shadow, 620));
    var w = state::px(940);
    if w > W - state::px(24) { w = W - state::px(24); }
    var h = state::px(690);
    if h > H - state::px(24) { h = H - state::px(24); }
    prefs::ow = w;
    prefs::oh = h;
    prefs::ox = (W - w) / 2;
    prefs::oy = (H - h) / 2;
    win::fill(prefs::ox + state::px(6), prefs::oy + state::px(10), w as i64, h, p.shadow);
    win::fill(prefs::ox + state::px(3), prefs::oy + state::px(4), state::px(4), h - state::px(8), p.shadow);
    win::fill(prefs::ox, prefs::oy, w as i64, h, p.chrome);
    // the window swallows clicks on its own blank space; the controls added
    // after this sit above it
    state::add_hit(state::HIT_PREFS_WIN, prefs::ox, prefs::oy, w, h, 0);
    win::line(prefs::ox, prefs::oy, prefs::ox + w - 1, prefs::oy, p.border, 1);
    win::line(prefs::ox, prefs::oy + h - 1, prefs::ox + w - 1, prefs::oy + h - 1, p.border, 1);
    win::line(prefs::ox, prefs::oy, prefs::ox, prefs::oy + h - 1, p.border, 1);
    win::line(prefs::ox + w - 1, prefs::oy, prefs::ox + w - 1, prefs::oy + h - 1, p.border, 1);
    let th = state::px(40);
    win::fill(prefs::ox, prefs::oy, w as i64, th, p.panel);
    win::line(prefs::ox, prefs::oy + th, prefs::ox + w - 1, prefs::oy + th, p.border, 1);
    pf(state::f_prefs_h, prefs::ox + state::px(16), prefs::oy + (th - win::th(state::f_prefs_h)) / 2, "设置", p.text);
    let ic = state::px(14);
    chrome::icon_at(12, prefs::ox + w - state::px(30), prefs::oy + (th - ic) / 2, ic, p.muted);
    state::add_hit(state::HIT_PREFS_CLOSE, prefs::ox + w - state::px(38), prefs::oy, state::px(38), th, 0);
    prefs::body_y = prefs::oy + th;
    prefs::body_b = prefs::oy + h - state::px(1);
    prefs::nav_w = state::px(206);
}

fn sidebar() {
    let p = theme::pal;
    let x = prefs::ox;
    let w = prefs::nav_w;
    win::fill(x, prefs::body_y, w as i64, prefs::body_b - prefs::body_y, p.panel);
    win::fill(x + w - 1, prefs::body_y, 1, prefs::body_b - prefs::body_y, p.border);
    let sx = x + state::px(14);
    let sy = prefs::body_y + state::px(12);
    let sw = w - state::px(28);
    let sh = state::px(26);
    pbox(sx, sy, sw, sh, prefs::edit == -2);
    state::add_hit(state::HIT_PREFS_SEARCH, sx, sy, sw, sh, 0);
    chrome::icon_at(4, sx + state::px(7), sy + (sh - state::px(12)) / 2, state::px(12), p.faint);
    let f = state::f_prefs;
    if prefs::query.len == 0 {
        pf(f, sx + state::px(24), sy + (sh - win::th(f)) / 2, "搜索设置", p.faint);
    } else {
        pfit(f, sx + state::px(24), sy + (sh - win::th(f)) / 2, prefs::query[0..prefs::query.len], sw - state::px(30), p.text);
        if prefs::edit == -2 && state::blink {
            win::fill(sx + state::px(24) + win::measure(f, prefs::query[0..prefs::query.len]) + 1,
                sy + state::px(5), 1, sh - state::px(10), p.text);
        }
    }
    var y = sy + sh + state::px(10);
    var i: i32 = 0;
    while i < prefs::SEC_COUNT {
        let rh = state::px(31);
        if y + rh > prefs::body_b - state::px(74) { break; }
        let chosen = i == prefs::section && prefs::query.len == 0;
        if chosen {
            win::round_rect(sx - state::px(6), y, sw + state::px(12), rh, state::px(5), state::px(5), p.active);
        }
        let ic = state::px(14);
        chrome::icon_at(prefs::sec_icon(i), sx + state::px(4), y + (rh - ic) / 2, ic,
            if chosen { p.accent } else { p.muted });
        pf(state::f_prefs_b, sx + state::px(28), y + (rh - win::th(state::f_prefs_b)) / 2,
            prefs::sec_name(i), if chosen { p.text } else { p.muted });
        let n = prefs::changed_in(i);
        if n > 0 {
            var nb: u8[>..] = [];
            var d = n;
            while d > 0 { nb.push(('0' + (d % 10) as u8)); d = d / 10; }
            let bw = win::measure(state::f_prefs, nb[0..nb.len]) + state::px(12);
            let bx = sx + sw - bw - state::px(4);
            win::round_rect(bx, y + (rh - state::px(17)) / 2, bw, state::px(17), state::px(8), state::px(8), p.surface);
            pf(state::f_prefs, bx + state::px(6), y + (rh - win::th(state::f_prefs)) / 2, nb[0..nb.len], p.muted);
        }
        state::add_hit(state::HIT_PREFS_NAV, sx - state::px(6), y, sw + state::px(12), rh, i);
        y = y + rh;
        i++;
    }
    let fy = prefs::body_b - state::px(64);
    win::line(sx, fy - state::px(8), sx + sw - 1, fy - state::px(8), p.border, 1);
    link_row(sx, fy, "settings.json");
    link_row(sx, fy + state::px(26), "keybindings.json");
}

fn link_row(x: i32, y: i32, name: const u8[:]) {
    let p = theme::pal;
    let ic = state::px(14);
    chrome::icon_at(32, x + state::px(2), y + state::px(4), ic, p.faint);
    pf(state::f_prefs, x + state::px(22), y, name, p.muted);
}

fn count_all() -> i32 {
    var n: i32 = 0;
    var i: i32 = 0;
    while i < prefs::flds.len as i32 {
        if prefs::matches(i) { n++; }
        i++;
    }
    return n;
}

fn page_head() {
    let p = theme::pal;
    let x = prefs::ox + prefs::nav_w;
    let w = prefs::ow - prefs::nav_w;
    let hy = prefs::body_y;
    let hh = state::px(46);
    win::fill(x, hy, w as i64, hh, p.chrome);
    var ic = prefs::sec_icon(prefs::section);
    if prefs::query.len > 0 { ic = 4; }
    let sz = state::px(15);
    chrome::icon_at(ic, x + state::px(24), hy + (hh - sz) / 2, sz, p.muted);
    if prefs::query.len > 0 {
        var buf: u8[>..] = [];
        buf.append("找到 ");
        var d = count_all();
        var dig: u8[>..] = [];
        if d == 0 { dig.push('0'); }
        while d > 0 { dig.push(('0' + (d % 10) as u8)); d = d / 10; }
        var q = dig.len;
        while q > 0 { q--; buf.push(dig[q]); }
        buf.append(" 项设置");
        pf(state::f_prefs_h, x + state::px(48), hy + (hh - win::th(state::f_prefs_h)) / 2, buf[0..buf.len], p.text);
    } else {
        pf(state::f_prefs_h, x + state::px(48), hy + (hh - win::th(state::f_prefs_h)) / 2,
            prefs::sec_name(prefs::section), p.text);
    }
    let lw = win::measure(state::f_prefs, "用户") + state::px(34);
    let bx = x + w - lw - state::px(20);
    let by = hy + (hh - state::px(24)) / 2;
    pbox(bx, by, lw, state::px(24), false);
    pf(state::f_prefs, bx + state::px(8), by + (state::px(24) - win::th(state::f_prefs)) / 2, "用户", p.muted);
    chrome::icon_at(8, bx + lw - state::px(16), by + state::px(7), state::px(10), p.muted);
    win::line(x, hy + hh, x + w - 1, hy + hh, p.border, 1);
    prefs::rows_y = hy + hh + state::px(6);
    prefs::rows_b = prefs::body_b - state::px(6);
    prefs::card_x = x + state::px(28);
    var maxw = state::px(660);
    prefs::card_w = w - state::px(56);
    if prefs::card_w > maxw { prefs::card_w = maxw; }
}

var combo_x: i32 = 0;
var combo_y: i32 = 0;
var combo_w: i32 = 0;
var total_rows: i32 = 0;
var shown_rows: i32 = 0;

fn switch_ctrl(i: i32, x: i32, y: i32) {
    let p = theme::pal;
    let bw = state::px(34);
    let bh = state::px(18);
    let on = prefs::is_true(i);
    win::round_rect(x, y, bw, bh, bh / 2, bh / 2, if on { p.accent } else { p.surface_hover });
    let d = bh - state::px(4);
    let cx = if on { x + bw - bh / 2 } else { x + bh / 2 };
    win::round_rect(cx - d / 2, y + state::px(2), d, d, d / 2, d / 2, if on { p.text } else { p.muted });
}

fn enum_ctrl(i: i32, x: i32, y: i32, w: i32) {
    let p = theme::pal;
    let h = state::px(24);
    pbox(x, y, w, h, prefs::combo == i);
    pfit(state::f_prefs, x + state::px(8), y + (h - win::th(state::f_prefs)) / 2,
        prefs::value_label(i), w - state::px(26), p.text);
    chrome::icon_at(8, x + w - state::px(16), y + (h - state::px(9)) / 2, state::px(9), p.muted);
    prefs::combo_x = x;
    prefs::combo_y = y + h;
    prefs::combo_w = w;
}

fn num_ctrl(i: i32, x: i32, y: i32, w: i32) {
    let p = theme::pal;
    let h = state::px(24);
    let bw = state::px(26);
    win::round_rect(x, y, bw, h, state::px(4), state::px(4), p.surface);
    chrome::icon_at(28, x + (bw - state::px(11)) / 2, y + (h - state::px(11)) / 2, state::px(11), p.muted);
    pbox(x + bw, y, w - bw * 2, h, prefs::edit == i);
    var buf: u8[>..] = [];
    if prefs::edit == i {
        var k: i64 = 0;
        while k < prefs::edit_buf.len { buf.push(prefs::edit_buf[k]); k++; }
    } else {
        let vt = prefs::num_text(i);
        var k2: i64 = 0;
        while k2 < vt.len { buf.push(vt[k2]); k2++; }
    }
    pfit(state::f_prefs, x + bw + state::px(6), y + (h - win::th(state::f_prefs)) / 2, buf[0..buf.len],
        w - bw * 2 - state::px(12), p.text);
    state::add_hit(state::HIT_PREFS_TEXT, x + bw, y, w - bw * 2, h, i);
    if prefs::edit == i && state::blink {
        win::fill(x + bw + state::px(6) + win::measure(state::f_prefs, buf[0..buf.len]) + 1, y + state::px(5), 1, h - state::px(10), p.text);
    }
    let bx = x + w - bw;
    win::round_rect(bx, y, bw, h, state::px(4), state::px(4), p.surface);
    chrome::icon_at(13, bx + (bw - state::px(11)) / 2, y + (h - state::px(11)) / 2, state::px(11), p.muted);
    state::add_hit(state::HIT_PREFS_STEP, x, y, bw, h, i * 4 + 1);
    state::add_hit(state::HIT_PREFS_STEP, bx, y, bw, h, i * 4 + 2);
}

fn text_ctrl(i: i32, x: i32, y: i32, w: i32) {
    let p = theme::pal;
    let h = state::px(24);
    pbox(x, y, w, h, prefs::edit == i);
    var buf: u8[>..] = [];
    if prefs::edit == i {
        var k: i64 = 0;
        while k < prefs::edit_buf.len { buf.push(prefs::edit_buf[k]); k++; }
    } else {
        let v = prefs::value(i);
        var k: i64 = 0;
        while k < v.len { buf.push(v[k]); k++; }
    }
    if buf.len == 0 {
        pf(state::f_prefs, x + state::px(8), y + (h - win::th(state::f_prefs)) / 2, "默认", p.faint);
    } else {
        pfit(state::f_prefs, x + state::px(8), y + (h - win::th(state::f_prefs)) / 2, buf[0..buf.len], w - state::px(14), p.text);
    }
    if prefs::edit == i && state::blink {
        win::fill(x + state::px(8) + win::measure(state::f_prefs, buf[0..buf.len]) + 1, y + state::px(5), 1, h - state::px(10), p.text);
    }
}

fn wide_ctrl(i: i32, x: i32, y: i32, w: i32) {
    let p = theme::pal;
    let h = state::px(26);
    pbox(x, y, w, h, false);
    let v = prefs::value(i);
    var hint: const u8[:] = "[]";
    if prefs::flds[i].kind == prefs::K_JSON { hint = "{ }"; }
    if prefs::flds[i].kind == prefs::K_STYLES { hint = "按文件夹保存"; }
    if v.len == 0 {
        pf(state::f_prefs, x + state::px(8), y + (h - win::th(state::f_prefs)) / 2, hint, p.faint);
    } else {
        pfit(state::f_prefs_k, x + state::px(8), y + (h - win::th(state::f_prefs_k)) / 2, v, w - state::px(14), p.text);
    }
}

fn field_row(i: i32, y: i32) -> i32 {
    let p = theme::pal;
    let fdb = prefs::flds[i];
    let textw = prefs::card_w - state::px(32) - ctrl_w(i) - state::px(12);
    let h = row_height(i, textw);
    let rx = prefs::card_x;
    let rw = prefs::card_w;
    win::round_rect(rx, y, rw, h, state::px(6), state::px(6), p.surface);
    win::line(rx + state::px(6), y, rx + rw - state::px(6), y, win::mix(p.surface, p.border, 500), 1);
    let x = rx + state::px(16);
    let ty = y + state::px(12);
    pfit(state::f_prefs_b, x, ty, fdb.title[0..fdb.title.len], textw, p.text);
    if prefs::changed(i) {
        let tw = win::measure(state::f_prefs_b, fdb.title[0..fdb.title.len]);
        if tw < textw { win::round_rect(x + tw + state::px(8), ty + win::th(state::f_prefs_b) / 2 - state::px(3),
            state::px(6), state::px(6), state::px(3), state::px(3), p.accent); }
    }
    let dy = ty + state::px(18) + state::px(3);
    let dh = draw_wrap(state::f_prefs, x, dy, fdb.desc[0..fdb.desc.len], textw, state::px(17), p.muted);
    let ky = dy + dh + state::px(4);
    pfit(state::f_prefs_k, x, ky, fdb.key[0..fdb.key.len], textw, p.faint);
    if ctrl_w(i) > 0 {
        let cx = rx + rw - ctrl_w(i) - state::px(16);
        let cy = ty;
        if fdb.kind == prefs::K_BOOL {
            switch_ctrl(i, cx + state::px(6), cy);
            state::add_hit(state::HIT_PREFS_TOGGLE, cx, cy - state::px(4), ctrl_w(i), state::px(26), i);
        } else if fdb.kind == prefs::K_ENUM {
            enum_ctrl(i, cx, cy, ctrl_w(i));
            state::add_hit(state::HIT_PREFS_ENUM, cx, cy, ctrl_w(i), state::px(24), i);
        } else if fdb.kind == prefs::K_NUM {
            num_ctrl(i, cx, cy, ctrl_w(i));
        } else if fdb.kind == prefs::K_TEXT {
            text_ctrl(i, cx, cy, ctrl_w(i));
            state::add_hit(state::HIT_PREFS_TEXT, cx, cy, ctrl_w(i), state::px(24), i);
        }
        if prefs::changed(i) {
            let rbx = rx + rw - state::px(30);
            let rby = y + h - state::px(30);
            chrome::icon_at(44, rbx, rby, state::px(13), if prefs::hover == i { p.text } else { p.faint });
            state::add_hit(state::HIT_PREFS_RESET, rbx - state::px(4), rby - state::px(4), state::px(22), state::px(22), i);
        }
    } else {
        wide_ctrl(i, x, y + h - state::px(34), rw - state::px(32));
        state::add_hit(state::HIT_PREFS_TEXT, x, y + h - state::px(34), rw - state::px(32), state::px(26), i);
    }
    if prefs::hover == i { win::line(rx, y + h - 1, rx + rw - 1, y + h - 1, p.border, 1); }
    return h + state::px(8);
}

// fields_body draws the page from the first row of the scroll down, and
// works out how many rows it has and how many show.
fn fields_body() {
    var y = prefs::rows_y;
    var row: i32 = 0;
    var drawn: i32 = 0;
    var i: i32 = 0;
    prefs::total_rows = 0;
    prefs::shown_rows = 0;
    while i < prefs::flds.len as i32 {
        let f = prefs::flds[i];
        let in_sec = if prefs::query.len > 0 { true } else { f.sec == prefs::section };
        if in_sec && prefs::matches(i) {
            prefs::total_rows = prefs::total_rows + 1;
            if row >= prefs::scroll {
                let h = row_height(i, prefs::card_w - state::px(32) - ctrl_w(i) - state::px(12));
                if y + h <= prefs::rows_b {
                    y = y + field_row(i, y);
                    drawn++;
                    prefs::shown_rows = drawn;
                }
            }
            row++;
        }
        i++;
    }
}

fn shortcuts_body() {
    let p = theme::pal;
    var y = prefs::rows_y;
    var row: i32 = 0;
    var drawn: i32 = 0;
    prefs::total_rows = 0;
    prefs::shown_rows = 0;
    var i: i64 = 0;
    let rh = state::px(29);
    // the card behind the rows
    win::round_rect(prefs::card_x, y, prefs::card_w, prefs::rows_b - y, state::px(6), state::px(6), p.surface);
    while i < menu::items.len {
        let it = menu::items[i];
        if it.depth == 1 && it.flags != menu::SEPARATOR && it.label.len > 0 {
            let ok = if prefs::query.len == 0 { true } else {
                prefs::has(it.label[0..it.label.len]) || prefs::has(it.accel[0..it.accel.len]) || prefs::has(it.id[0..it.id.len])
            };
            if ok {
                prefs::total_rows = prefs::total_rows + 1;
                if row >= prefs::scroll && y + rh <= prefs::rows_b {
                    let x = prefs::card_x + state::px(16);
                    pfit(state::f_prefs, x, y + (rh - win::th(state::f_prefs)) / 2, it.label[0..it.label.len],
                        prefs::card_w - state::px(220), p.text);
                    var kk: const u8[:] = if it.accel.len > 0 { it.accel[0..it.accel.len] } else { "—" };
                    let kw = win::measure(state::f_prefs, kk) + state::px(14);
                    let kx = prefs::card_x + prefs::card_w - kw - state::px(14);
                    win::round_rect(kx, y + state::px(5), kw, state::px(19), state::px(4), state::px(4), p.chrome);
                    pfit(state::f_prefs, kx + state::px(7), y + (rh - win::th(state::f_prefs)) / 2, kk, kw - state::px(10), p.muted);
                    if row > prefs::scroll {
                        win::line(prefs::card_x + state::px(16), y, prefs::card_x + prefs::card_w - state::px(16), y, p.border, 1);
                    }
                    y = y + rh;
                    drawn++;
                    prefs::shown_rows = drawn;
                }
                row++;
            }
        }
        i++;
    }
}

fn scrollbar() {
    if prefs::total_rows <= prefs::shown_rows || prefs::shown_rows == 0 { return; }
    let p = theme::pal;
    let x = prefs::ox + prefs::ow - state::px(12);
    let ty = prefs::rows_y;
    let track = prefs::rows_b - prefs::rows_y;
    win::round_rect(x, ty, state::px(3), track, state::px(2), state::px(2), p.chrome);
    var th = track * prefs::shown_rows / prefs::total_rows;
    if th < state::px(28) { th = state::px(28); }
    var top = ty;
    if prefs::total_rows > prefs::shown_rows {
        top = ty + (track - th) * prefs::scroll / (prefs::total_rows - prefs::shown_rows);
    }
    win::round_rect(x, top, state::px(3), th, state::px(2), state::px(2), p.scrollbar);
}

fn draw_combo() {
    if prefs::combo < 0 { return; }
    let p = theme::pal;
    let i = prefs::combo;
    let n = prefs::opt_count(i);
    if n == 0 { return; }
    let rh = state::px(26);
    var w = prefs::combo_w;
    var k: i32 = 0;
    while k < n {
        let lw = win::measure(state::f_prefs, prefs::opt_label(i, k)) + state::px(26);
        if lw > w { w = lw; }
        k++;
    }
    var x = prefs::combo_x;
    var y = prefs::combo_y + state::px(2);
    let h = rh * n + state::px(6);
    if x + w > prefs::ox + prefs::ow - state::px(8) { x = prefs::ox + prefs::ow - w - state::px(8); }
    if y + h > prefs::body_b - state::px(6) { y = prefs::combo_y - h - state::px(26); }
    win::fill(x + state::px(3), y + state::px(3), w as i64, h, p.shadow);
    win::fill(x, y, w as i64, h, p.surface);
    win::line(x, y, x + w - 1, y, p.border, 1);
    win::line(x, y + h - 1, x + w - 1, y + h - 1, p.border, 1);
    win::line(x, y, x, y + h - 1, p.border, 1);
    win::line(x + w - 1, y, x + w - 1, y + h - 1, p.border, 1);
    let cur = prefs::opt_index(i);
    k = 0;
    while k < n {
        let ry = y + state::px(3) + rh * k;
        if k == cur { win::fill(x + 1, ry, w - 2, rh, p.active); }
        pfit(state::f_prefs, x + state::px(12), ry + (rh - win::th(state::f_prefs)) / 2,
            prefs::opt_label(i, k), w - state::px(20), if k == cur { p.text } else { p.muted });
        state::add_hit(state::HIT_PREFS_OPT, x, ry, w, rh, i * 1000 + k);
        k++;
    }
}

fn paint() {
    if !prefs::open { return; }
    prefs::init();
    frame();
    sidebar();
    page_head();
    if prefs::section == 10 && prefs::query.len == 0 {
        shortcuts_body();
    } else if prefs::section == 8 && prefs::query.len == 0 {
        plugins_body();
    } else {
        fields_body();
    }
    scrollbar();
    draw_combo();
}


