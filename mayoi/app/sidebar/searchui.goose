// The search view's controls and its result list. The scan itself lives in
// search.goose; this file is only what the panel draws.
namespace chrome;

import std;
import ui.win;
import ui.theme;
import app.state;
import app.layout;
import app.icons;

fn draw_fit(f: u64, x: i32, y: i32, text: const u8[:], maxw: i32, col: u32) {
    if text.len == 0 { return; }
    if win::measure(f, text) <= maxw {
        win::text_at(f, x, y, text, col);
        return;
    }
    var n: i64 = text.len;
    while n > 1 {
        if win::measure(f, text[0..n]) + state::px(8) <= maxw { break; }
        n--;
    }
    win::text_at(f, x, y, text[0..n], col);
    win::text_at(f, x + win::measure(f, text[0..n]), y, "…", col);
}

fn box(x: i32, y: i32, w: i32, h: i32, focused: bool) {
    let p = theme::pal;
    win::fill(x, y, w, h, p.surface);
    let c = if focused { p.accent } else { p.border };
    win::line(x, y, x + w - 1, y, c, 1);
    win::line(x, y + h - 1, x + w - 1, y + h - 1, c, 1);
    win::line(x, y, x, y + h - 1, c, 1);
    win::line(x + w - 1, y, x + w - 1, y + h - 1, c, 1);
}

// field_text draws a buffer or its placeholder into a box, with a caret.
fn field_text(x: i32, y: i32, w: i32, h: i32, buf: const u8[:], hint: const u8[:], caret: bool) {
    let p = theme::pal;
    let f = state::f_small;
    let ty = y + (h - win::th(f)) / 2;
    if buf.len == 0 {
        win::text_at(f, x + state::px(8), ty, hint, p.faint);
        return;
    }
    draw_fit(f, x + state::px(8), ty, buf, w - state::px(14), p.text);
    if caret {
        let qw = win::measure(f, buf);
        if qw < w - state::px(12) {
            win::fill(x + state::px(8) + qw + 1, y + state::px(5), 1, h - state::px(10), p.text);
        }
    }
}

fn opt_cell(kind: i32, bx: i32, by: i32, bh: i32, x: i32, on: bool) {
    let p = theme::pal;
    let sz = state::px(13);
    let ix = x + state::px(6);
    let iy = by + (bh - sz) / 2;
    if on { win::round_rect(x + state::px(2), by + state::px(3), state::px(20), bh - state::px(6),
        state::px(3), state::px(3), p.active); }
    icon_at(kind, ix, iy, sz, if on { p.accent } else { p.muted });
}

fn search_body(top: i32) {
    let p = theme::pal;
    let w = state::sidebar_w;
    let bh = state::px(26);
    let bx = state::px(44);
    let bw = w - state::px(44) - state::px(14);
    var fy = top + state::px(4);
    // the whole body belongs to the search view
    state::add_hit(state::HIT_SEARCH, 0, top, w, state::H - state::status_h - top, 0);
    box(bx, fy, bw, bh, state::search_field == 0);
    state::add_hit(state::HIT_SEARCH_FIELD, bx, fy, bw - state::px(90), bh, 0);
    field_text(bx, fy, bw - state::px(90), bh, state::search_q, "搜索",
        state::search_field == 0 && state::blink);
    opt_cell(71, bx, fy, bh, bx + bw - state::px(88), state::search_case);
    state::add_hit(state::HIT_SEARCH_OPT, bx + bw - state::px(88), fy, state::px(22), bh, 1);
    opt_cell(70, bx, fy, bh, bx + bw - state::px(64), state::search_word);
    state::add_hit(state::HIT_SEARCH_OPT, bx + bw - state::px(64), fy, state::px(22), bh, 2);
    opt_cell(72, bx, fy, bh, bx + bw - state::px(40), state::search_regex);
    state::add_hit(state::HIT_SEARCH_OPT, bx + bw - state::px(40), fy, state::px(22), bh, 3);
    fy = fy + bh + state::px(4);
    if state::search_replacing {
        state::add_hit(state::HIT_SEARCH_COLLAPSE, state::px(16), fy, state::px(22), state::px(24), 0);
        icon_at(8, state::px(20), fy + state::px(6), state::px(13), p.muted);
        box(bx, fy, bw, bh, state::search_field == 1);
        state::add_hit(state::HIT_SEARCH_FIELD, bx, fy, bw - state::px(34), bh, 1);
        field_text(bx, fy, bw - state::px(34), bh, state::search_rep, "替换",
            state::search_field == 1 && state::blink);
        icon_at(74, bx + bw - state::px(30), fy + (bh - state::px(15)) / 2, state::px(15), p.muted);
        state::add_hit(state::HIT_SEARCH_REPLACE_ALL, bx + bw - state::px(34), fy, state::px(34), bh, 0);
        fy = fy + bh + state::px(4);
    } else {
        // clicking the arrow at the left of the box opens the replace row
        state::add_hit(state::HIT_SEARCH_COLLAPSE, state::px(16), fy - bh - state::px(4), state::px(22), bh, 0);
        icon_at(7, state::px(20), fy - bh - state::px(4) + (bh - state::px(13)) / 2, state::px(13), p.muted);
    }
    // the "..." under the box's right corner unfolds the filters
    fy = fy + state::px(6);
    icon_at(15, bx + bw - state::px(20), fy, state::px(14),
        if state::search_details { p.text } else { p.muted });
    state::add_hit(state::HIT_SEARCH_DETAILS, bx + bw - state::px(26), fy - state::px(4), state::px(30), state::px(22), 0);
    fy = fy + state::px(24);
    if state::search_details {
        let ih = state::px(26);
        ch(state::f_small, state::px(42), fy + state::px(11), "包含的文件", p.muted);
        fy = fy + state::px(24);
        box(bx, fy, bw, ih, state::search_field == 2);
        state::add_hit(state::HIT_SEARCH_FIELD, bx, fy, bw, ih, 2);
        field_text(bx, fy, bw, ih, state::search_inc, "例如 *.go, src/**",
            state::search_field == 2 && state::blink);
        fy = fy + ih + state::px(6);
        ch(state::f_small, state::px(42), fy + state::px(11), "排除的文件", p.muted);
        fy = fy + state::px(24);
        box(bx, fy, bw, ih, state::search_field == 3);
        state::add_hit(state::HIT_SEARCH_FIELD, bx, fy, bw, ih, 3);
        field_text(bx, fy, bw, ih, state::search_exc, "例如 *.test.ts, testdata",
            state::search_field == 3 && state::blink);
        fy = fy + ih + state::px(14);
    }
    win::text_at(state::f_small, state::px(42), fy, "在文件夹的文件中查找文本。", p.muted);
    fy = fy + state::px(24);
    hint_row(state::px(42), fy, "1", "转到结果");
    fy = fy + state::px(26);
    hint_row(state::px(42), fy, "↵", "打开匹配项");
    fy = fy + state::px(26);
    hint_row(state::px(42), fy, "↑↓", "转到上一个结果");
    fy = fy + state::px(26);
    hint_row(state::px(42), fy, "Ctrl+Shift+H", "替换");
    fy = fy + state::px(30);
    if state::search_q.len > 0 {
        var head: u8[>..] = [];
        var num: u8[>..] = [];
        var d = search_n;
        if d == 0 { num.push('0'); }
        while d > 0 { num.push('0' + (d % 10) as u8); d = d / 10; }
        var q: i64 = num.len;
        while q > 0 { q--; head.push(num[q]); }
        head.append(" 个结果");
        win::text_at(state::f_small, state::px(14), fy, head, p.muted);
        fy = fy + state::px(20);
    }
    let rh = state::px(36);
    let avail = w - state::px(28);
    var i: i32 = 0;
    var k: i64 = 0;
    var start: i64 = 0;
    var cap = (state::H - state::status_h - fy) / rh;
    while k <= search_rows.len && i < cap {
        if k == search_rows.len || search_rows[k] == '\n' {
            if k > start {
                let line = search_rows[start..k];
                let y = fy + i * rh;
                var t1: i64 = -1;
                var t2: i64 = -1;
                var c: i64 = 0;
                while c < line.len {
                    if line[c] == '\t' {
                        if t1 < 0 { t1 = c; } else { t2 = c; break; }
                    }
                    c++;
                }
                let path = if t1 > 0 { line[0..t1] } else { line };
                let no = if t1 > 0 && t2 > t1 { line[t1 + 1..t2] } else { "" };
                let snip = if t2 > 0 { line[t2 + 1..] } else { "" };
                let sep = last_sep(path);
                var base = path;
                if sep >= 0 && sep + 1 < path.len { base = path[sep + 1..]; }
                state::add_hit(state::HIT_SCM_ROW, state::px(8), y, w - state::px(16), rh, i);
                draw_fit(state::f_small, state::px(14), y + state::px(2), base, avail, p.text);
                var wb = win::measure(state::f_small, base);
                if wb > avail { wb = avail; }
                var lx = state::px(14) + wb + state::px(4);
                win::text_at(state::f_small, lx, y + state::px(2), ":", p.faint);
                win::text_at(state::f_small, lx + state::px(4), y + state::px(2), no, p.faint);
                draw_fit(state::f_small, state::px(20), y + state::px(18), snip, avail - state::px(6), p.muted);
                i++;
            }
            start = k + 1;
        }
        k++;
    }
}

// hint_row is one shortcut: a chip with the key, then what it does.
fn hint_row(x: i32, y: i32, keys: const u8[:], what: const u8[:]) {
    let p = theme::pal;
    let f = state::f_small;
    var kw = win::measure(f, keys) + state::px(12);
    if kw < state::px(20) { kw = state::px(20); }
    win::round_rect(x, y, kw, state::px(20), state::px(4), state::px(4), p.surface);
    ch(f, x + (kw - win::measure(f, keys)) / 2, y + state::px(10), keys, p.muted);
    win::text_at(f, x + kw + state::px(10), y + state::px(2), what, p.faint);
}

// search_char types into whichever field has the keyboard.
