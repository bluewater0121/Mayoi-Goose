// The code area: gutter, current line, selection, spans, caret, and the
// welcome page shown while no document is open.
namespace editor;

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

fn digits(n: i32) -> i32 {
    var d: i32 = 1;
    var v = n;
    while v >= 10 { v = v / 10; d++; }
    if d < 3 { d = 3; }
    return d;
}

fn draw_segment(i: i32, a: i64, b: i64, k: i64, tx: i32, row_y: i32, col0: i32) {
    let d .= state::docs[i];
    let base = tx + (col0 - d.scroll_x) * state::cell_w;
    var p = a;
    var col = col0;
    var run = a;
    var runcol = col0;
    while p < b {
        let c = state::arena[d.off + p];
        if c == '\t' {
            if p > run { win::text_at(state::f_code, tx + (runcol - d.scroll_x) * state::cell_w,
                                      row_y, state::arena[d.off + run .. d.off + p], theme::pal.syntax[k]); }
            col = col + (4 - col % 4);
            p++;
            run = p;
            runcol = col;
        } else {
            if (c & 0xF0) == 0xE0 { col += 2; p += 3; }
            else if (c & 0xF8) == 0xF0 { col += 2; p += 4; }
            else if (c & 0xE0) == 0xC0 { col++; p += 2; }
            else { col++; p++; }
        }
    }
    if p > run {
        win::text_at(state::f_code, tx + (runcol - d.scroll_x) * state::cell_w, row_y,
                     state::arena[d.off + run .. d.off + p], theme::pal.syntax[k]);
    }
}

fn paint(x0: i32, y0: i32, w: i32, h: i32) {
    let p = theme::pal;
    win::fill(x0, y0, w, h, p.editor);
    state::ed_left = x0;
    state::ed_right = x0 + w;
    state::ed_top = y0;
    state::ed_bot = y0 + h;
    if state::docs.len == 0 || state::cur < 0 { welcome(x0, y0, w, h); return; }
    let d .= state::docs[state::cur];
    let total = text::nlines();
    let tx = x0 + state::px(102);
    let gx_right = x0 + state::px(56);
    let gutter = tx - x0;
    state::gutter_w = gutter;
    state::code_x = tx;
    let lead: i32 = 0;
    let count = (h - state::px(4)) / state::line_h;
    var first = d.scroll;
    if first < 0 { first = 0; }
    if total > 0 && first > total - 1 { first = total - 1; }
    if d.scroll != first { d.scroll = first; }
    let line_no = p.gutter;
    let line_now = p.gutter_now;
    let caret_line, caret_col = text::line_col(d.sel_b);
    let sa = text::sel_min(state::cur);
    let sb = text::sel_max(state::cur);
    var spans: syntax::Span[>..] = [];
    var i: i32 = 0;
    while i < count {
        let line = first + i;
        if line >= total { break; }
        let y: i32 = y0 + lead + i * state::line_h;
        let ls = text::line_start(line);
        let le = text::line_end(line);
        if line == caret_line { win::fill(x0 + state::px(101), y, x0 + w - x0 - state::px(101), state::line_h, p.line); }
        // selection
        if sb > sa && sa < le + 1 && sb > ls {
            var a = sa;
            var b = sb;
            if a < ls { a = ls; }
            if b > le + 1 { b = le + 1; }
            if b > a {
                let c0 = text::col_cells(state::cur, a);
                let c1 = text::col_cells(state::cur, b);
                let sx = tx + (c0 - d.scroll_x) * state::cell_w;
                let sw = (c1 - c0) * state::cell_w;
                win::fill(sx, y, sw, state::line_h, p.selection);
            }
        }
        // the number
        var num: u8[>..] = [];
        format(num, line + 1);
        let nw = num.len as i32 * state::cell_w;
        win::text_at(state::f_code, gx_right - nw,
                     y + (state::line_h - win::th(state::f_code)) / 2, num,
                     if line == caret_line { line_now } else { line_no });
        // indent guides
        var col: i32 = 0;
        var q = ls;
        while q < le && q < ls + 256 {
            let c = state::arena[d.off + q];
            if c == ' ' { col++; q++; } else if c == '\t' { col = col + (4 - col % 4); q++; } else { break; }
        }
        var g: i32 = 4;
        while g < col {
            let gx: i32 = tx + (g - d.scroll_x) * state::cell_w;
            if gx >= tx { win::line(gx, y, gx, y + state::line_h, p.guide, 1); }
            g += 4;
        }
        // spans
        let st = syntax::state_at(state::cur, line);
        syntax::lex_line(state::cur, ls, le, st, spans);
        var row_y = y + (state::line_h - win::th(state::f_code)) / 2;
        var pos = ls;
        var k: i64 = 0;
        while k < spans.len {
            let sp = spans[k];
            var a = ls + sp.a as i64;
            var b = ls + sp.b as i64;
            if a > le { a = le; }
            if b > le { b = le; }
            if b < a { b = a; }
            if a > pos { draw_segment(state::cur, pos, a, theme::PLAIN, tx, row_y, text::col_cells(state::cur, pos)); }
            if b > a { draw_segment(state::cur, a, b, sp.k, tx, row_y, text::col_cells(state::cur, a)); }
            if b > pos { pos = b; }
            k++;
        }
        if le > pos { draw_segment(state::cur, pos, le, theme::PLAIN, tx, row_y, text::col_cells(state::cur, pos)); }
        spans.resize(0);
        i++;
    }
    // caret
    if state::focus == 0 && state::blink {
        let cx: i32 = tx + (caret_col as i32 - d.scroll_x) * state::cell_w;
        let cy = y0 + lead + (caret_line - first) * state::line_h;
        if caret_line >= first && caret_line < first + count {
            win::fill(cx, cy + state::px(2), state::px(2), state::line_h - state::px(4), p.text);
        }
    }
    // an overlay scrollbar at the right edge, only when the buffer runs past
    // the view, thin and rounded like the reference's
    if total > count && count > 0 {
        let track = h - state::px(8);
        var th = (track * count) / total;
        if th < state::px(24) { th = state::px(24); }
        let maxs = total - count;
        var ty = y0 + state::px(4);
        if maxs > 0 && d.scroll > 0 {
            let s = if d.scroll > maxs { maxs } else { d.scroll };
            ty = ty + ((track - th) * s) / maxs;
        }
        win::round_rect(x0 + w - state::px(7), ty, state::px(4), th, state::px(2), state::px(2), p.scrollbar);
    }
    state::add_hit(state::HIT_CARET, x0, y0, w, h, 0);
}

fn welcome(x0: i32, y0: i32, w: i32, h: i32) {
    let p = theme::pal;
    var top = y0 + state::px(60);
    let lx = x0 + w / 2 - state::px(300);
    // mark
    win::fill(lx, top, state::px(56), state::px(56), p.surface);
    win::fill(lx, top, state::px(56), state::px(2), p.accent);
    ch_center("M", lx, top, state::px(56), state::px(26), p.accent);
    var title: u8[>..] = [];
    title.append("Mayoi");
    win::text_at(state::f_title, lx + state::px(74), top + state::px(2), title, p.text);
    var sub: u8[>..] = [];
    sub.append("迷い · 小巧、快速的代码编辑器");
    win::text_at(state::f_ui, lx + state::px(74), top + state::px(36), sub, p.muted);

    var y = top + state::px(110);
    var head: u8[>..] = [];
    head.append("开始");
    win::text_at(state::f_small, lx, y, head, p.faint);
    y = y + state::px(26);
    row_button(lx, y, state::px(600), "新建文件", "Ctrl+N", 1); y = y + state::px(38);
    row_button(lx, y, state::px(600), "打开文件…", "Ctrl+O", 2); y = y + state::px(38);
    row_button(lx, y, state::px(600), "打开文件夹…", "", 3); y = y + state::px(38);
    row_button(lx, y, state::px(600), "快速打开…", "Ctrl+P", 4); y = y + state::px(38);
    row_button(lx, y, state::px(600), "命令面板…", "Ctrl+Shift+P", 5); y = y + state::px(38);
    row_button(lx, y, state::px(600), "在 GitHub 上加星", "", 6);
}

fn ch_center(s: const u8[:], x: i32, y: i32, w: i32, size: i32, c: u32) {
    let f = win::font(size, 600, "Segoe UI");
    let tw = win::measure(f, s);
    let th = win::th(f);
    win::text_at(f, x + (w - tw) / 2, y + (w - th) / 2, s, c);
    win::discard_font(f);
}

fn row_button(x: i32, y: i32, w: i32, label: const u8[:], key: const u8[:], act: i64) {
    let p = theme::pal;
    state::add_hit(state::HIT_RULE, x, y, w, state::px(32), act);
    var tx = x;
    var icon: i32 = 13;
    if act == 1 { icon = 13; } else if act == 2 { icon = 10; } else if act == 3 { icon = 10; }
    else if act == 4 { icon = 4; } else if act == 5 { icon = 17; } else { icon = 5; }
    icon_at(icon, tx + state::px(6), y + state::px(8), state::px(14), p.muted);
    win::text_at(state::f_ui, tx + state::px(30), y + state::px(6), label, p.text);
    if key.len > 0 {
        let kw = win::measure(state::f_small, key) + state::px(12);
        let kx = x + w - kw;
        win::fill(kx, y + state::px(4), kw, state::px(22), p.surface);
        win::text_at(state::f_small, kx + state::px(6), y + state::px(7), key, p.muted);
    }
}

fn icon_at(kind: i32, x: i32, y: i32, sz: i32, c: u32) {
    // reuse the chrome set
    chrome::icon_at(kind, x, y, sz, c);
}














