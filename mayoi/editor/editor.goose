// The code area: gutter, current line, selection, spans, caret, and the
// welcome page shown while no document is open.
namespace editor;

import std;
import os;
import app.state;
import i18n;
import ui.theme;
import ui.win;
import editor.text;
import editor.syntax;
import explore.tree;
import app.draw;
import app.prefs.model;
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

fn u8_len(i: i32, p: i64) -> i64 {
    let c = state::arena[state::docs[i].off + p];
    if (c & 0xF8) == 0xF0 { return 4; }
    if (c & 0xF0) == 0xE0 { return 3; }
    if (c & 0xE0) == 0xC0 { return 2; }
    return 1;
}

fn u8_cells(i: i32, p: i64) -> i32 {
    let c = state::arena[state::docs[i].off + p];
    if c == '\t' { return 4; }
    if (c & 0xF8) == 0xF0 { return 2; }
    if (c & 0xF0) == 0xE0 { return 2; }
    return 1;
}

// paint_wrapped lays a logical line out over as many rows as it needs, breaking
// at spaces where it can and at the character that overflows where it cannot.
fn paint_wrapped(x0: i32, y0: i32, w: i32, h: i32) {
    let p = theme::pal;
    let d .= state::docs[state::cur];
    let total = text::nlines();
    let tx = x0 + state::px(102);
    let gx_right = x0 + state::px(56);
    let right = x0 + w - state::px(14);
    var maxcells = ((right - tx) * 9 / 10) / state::cell_w - 2;
    if maxcells < 8 { maxcells = 8; }
    let lh = state::line_h;
    let caret_line, caret_byte = text::line_col(d.sel_b);
    let caret_col = text::col_cells(state::cur, d.sel_b) as i64;
    var vis: i32 = 0;
    var line = d.scroll;
    if line < 0 { line = 0; }
    while line < total {
        let ls = text::line_start(line);
        let le = text::line_end(line);
        var seg = ls;
        var cells: i32 = 0;
        var last_space: i64 = -1;
        var i = ls;
        var col0: i32 = 0;
        var first = true;
        while i < le {
            let y = y0 + vis * lh;
            if y >= y0 + h { return; }
            let cwid = u8_cells(state::cur, i);
            if cells + cwid > maxcells && i > seg {
                var cut = i;
                if last_space > seg { cut = last_space; }
                while cut > seg && (state::arena[d.off + cut] & 0xC0) == 0x80 { cut--; }
                draw_wrap_row(x0, y0, w, h, line, vis, seg, cut, col0, cells, first, caret_line, caret_col, tx, gx_right, lh);
                vis++;
                var adv = cells;
                if cut == last_space { cut++; adv++; }
                seg = cut;
                i = cut;
                col0 = col0 + adv;
                cells = 0;
                last_space = -1;
                first = false;
                continue;
            }
            if state::arena[d.off + i] == ' ' { last_space = i; }
            cells = cells + cwid;
            i = i + u8_len(state::cur, i);
        }
        draw_wrap_row(x0, y0, w, h, line, vis, seg, le, col0, cells, first, caret_line, caret_col, tx, gx_right, lh);
        vis++;
        line++;
        if y0 + vis * lh >= y0 + h { return; }
    }
}

fn cells_between(i: i32, a: i64, b: i64) -> i32 {
    var n: i32 = 0;
    var p = a;
    while p < b {
        let c = state::arena[state::docs[i].off + p];
        if c == '\t' { n = n + 4; }
        else if (c & 0xF8) == 0xF0 { n = n + 2; }
        else if (c & 0xF0) == 0xE0 { n = n + 2; }
        else { n = n + 1; }
        p = p + u8_len(i, p);
    }
    return n;
}

fn draw_wrap_row(x0: i32, y0: i32, w: i32, h: i32, line: i32, vis: i32, a: i64, b: i64,
                 col0: i32, cells: i32, first: bool, caret_line: i32, caret_col: i64,
                 tx: i32, gx_right: i32, lh: i32) {
    let p = theme::pal;
    let d .= state::docs[state::cur];
    let y = y0 + vis * lh;
    var end = b;
    while end > a && state::arena[d.off + end - 1] == ' ' { end--; }
    if y + lh > y0 + h { return; }
    if line == caret_line {
        win::fill(x0 + state::px(101), y, x0 + w - x0 - state::px(101), lh, p.line);
    }
    if first {
        var num: u8[>..] = [];
        format(num, line + 1);
        let nw = num.len as i32 * state::cell_w;
        win::text_at(state::f_code, gx_right - nw, y + (lh - win::th(state::f_code)) / 2, num,
                     if line == caret_line { p.gutter_now } else { p.gutter });
    }
    if end > a {
        // keep the line's syntax colours inside each wrapped row
        let ls = text::line_start(line);
        let le = text::line_end(line);
        var spans: syntax::Span[>..] = [];
        let st = syntax::state_at(state::cur, line);
        syntax::lex_line(state::cur, ls, le, st, spans);
        var pos = a;
        var k: i64 = 0;
        while k < spans.len {
            let sp = spans[k];
            var sa = ls + sp.a as i64;
            var sb = ls + sp.b as i64;
            if sb > le { sb = le; }
            if sb <= a || sa >= end { k++; continue; }
            if sa < a { sa = a; }
            if sb > end { sb = end; }
            if sa > pos {
                draw_segment(state::cur, pos, sa, theme::PLAIN, tx,
                             y + (lh - win::th(state::f_code)) / 2, col0 + cells_between(state::cur, a, pos));
            }
            if sb > sa {
                draw_segment(state::cur, sa, sb, sp.k, tx,
                             y + (lh - win::th(state::f_code)) / 2, col0 + cells_between(state::cur, a, sa));
            }
            if sb > pos { pos = sb; }
            k++;
        }
        if end > pos {
            draw_segment(state::cur, pos, end, theme::PLAIN, tx,
                         y + (lh - win::th(state::f_code)) / 2, col0 + cells_between(state::cur, a, pos));
        }
        spans.resize(0);
    }
    if line == caret_line && caret_col >= col0 && caret_col <= col0 + cells {
        let cx = tx + (caret_col - col0) as i32 * state::cell_w;
        state::ime_x = cx;
        state::ime_y = y + lh;
        if state::focus == 0 && state::blink {
            win::fill(cx, y + state::px(2), state::px(2), lh - state::px(4), p.text);
        }
    }
}

var img_path: u8[>..] = [];
var img_handle: u64 = 0;

fn lower(c: u8) -> u8 { if c >= 'A' && c <= 'Z' { return c + 32; } return c; }

fn is_image(path: const u8[:]) -> bool {
    var dot: i64 = -1;
    var i: i64 = 0;
    while i < path.len {
        if path[i] == '.' { dot = i; }
        if path[i] == '/' || path[i] == '\\' { dot = -1; }
        i++;
    }
    if dot < 0 || dot + 1 >= path.len { return false; }
    let e = path[dot + 1..path.len];
    if e.len == 3 && lower(e[0]) == 'p' && lower(e[1]) == 'n' && lower(e[2]) == 'g' { return true; }
    if e.len == 3 && lower(e[0]) == 'j' && lower(e[1]) == 'p' && lower(e[2]) == 'g' { return true; }
    if e.len == 4 && lower(e[0]) == 'j' && lower(e[1]) == 'p' && lower(e[2]) == 'e' && lower(e[3]) == 'g' { return true; }
    if e.len == 3 && lower(e[0]) == 'g' && lower(e[1]) == 'i' && lower(e[2]) == 'f' { return true; }
    if e.len == 3 && lower(e[0]) == 'b' && lower(e[1]) == 'm' && lower(e[2]) == 'p' { return true; }
    if e.len == 4 && lower(e[0]) == 'w' && lower(e[1]) == 'e' && lower(e[2]) == 'b' && lower(e[3]) == 'p' { return true; }
    if e.len == 3 && lower(e[0]) == 'i' && lower(e[1]) == 'c' && lower(e[2]) == 'o' { return true; }
    return false;
}

fn same_path(a: const u8[:], b: const u8[:]) -> bool {
    if a.len != b.len { return false; }
    var i: i64 = 0;
    while i < a.len { if a[i] != b[i] { return false; } i++; }
    return true;
}

var jl_path: u8[>..] = [];
var jl_text: u8[>..] = [];
fn jl_mode_source() -> bool {
    let i = prefs::index_of("jsonlMode");
    if i < 0 { return false; }
    let v = prefs::value(i);
    return v.len > 0 && v[0] == 's';
}

fn is_jsonl(path: const u8[:]) -> bool {
    if path.len < 6 { return false; }
    let e = path[path.len - 6..path.len];
    if e.len == 6 && e[0] == '.' && lower(e[1]) == 'j' && lower(e[2]) == 's' && lower(e[3]) == 'o' && lower(e[4]) == 'n' && lower(e[5]) == 'l' { return true; }
    let e2 = path[path.len - 7..path.len];
    if e2.len == 7 && e2[0] == '.' && lower(e2[1]) == 'n' && lower(e2[2]) == 'd' && lower(e2[3]) == 'j' && lower(e2[4]) == 's' && lower(e2[5]) == 'o' && lower(e2[6]) == 'n' { return true; }
    return false;
}

fn jl_load(path: const u8[:]) {
    if same_path(jl_path[0..jl_path.len], path) { return; }
    jl_path.resize(0);
    jl_path.append(path);
    jl_text.resize(0);
    read_file(path, jl_text);
}

fn line_at(s: const u8[:], n: i32) -> i32, i64, i64 {
    var line: i32 = 0;
    var a: i64 = 0;
    var i: i64 = 0;
    while i < s.len {
        if s[i] == '\n' {
            if line == n { return line, a, i; }
            line++;
            a = i + 1;
        }
        i++;
    }
    return line, a, s.len;
}

fn jl_value(s: const u8[:], key: const u8[:]) -> u8[>..] {
    var out: u8[>..] = [];
    var i: i64 = 0;
    while i + key.len + 2 <= s.len {
        var hit = true;
        var k: i64 = 0;
        while k < key.len { if s[i + 1 + k] != key[k] { hit = false; break; } k++; }
        if hit && s[i] == '"' && s[i + 1 + key.len] == '"' {
            var j = i + key.len + 2;
            while j < s.len && (s[j] == ' ' || s[j] == ':') { j++; }
            if j < s.len && s[j] == '"' {
                j++;
                while j < s.len && s[j] != '"' { out.push(s[j]); j++; }
                return out;
            }
            while j < s.len && s[j] != ',' && s[j] != '}' { out.push(s[j]); j++; }
            return out;
        }
        i++;
    }
    return out;
}

// paint_jsonl is the Table view: a row a line, a key a column.
fn paint_jsonl(path: const u8[:], x0: i32, y0: i32, w: i32, h: i32, name: const u8[:]) {
    let p = theme::pal;
    jl_load(path);
    win::fill(x0, y0, w, h, p.editor);
    win::text_at(state::f_ui, x0 + state::px(16), y0 + state::px(8), name, p.muted);
    let top = y0 + state::px(30);
    let hh = state::px(28);
    let rowh = state::px(22);
    let s = jl_text[0..jl_text.len];
    // the keys of the first object are the columns
    var keys: u8[>..] = [];
    let l0, a0, b0 = line_at(s, 0);
    var i: i64 = a0;
    while i < b0 {
        if s[i] == '"' {
            var j = i + 1;
            var key: u8[>..] = [];
            while j < b0 && s[j] != '"' { key.push(s[j]); j++; }
            // a quoted string followed by a colon is a key
            var c = j + 1;
            while c < b0 && s[c] == ' ' { c++; }
            if c < b0 && s[c] == ':' {
                if keys.len > 0 { keys.push('\n'); }
                keys.append(key);
            }
            i = j + 1;
            continue;
        }
        i++;
    }
    var cols: i32 = 1;
    var k: i64 = 0;
    while k < keys.len { if keys[k] == '\n' { cols++; } k++; }
    let colw = (w - state::px(32)) / cols;
    win::fill(x0, top, w, hh, p.panel);
    win::fill(x0, top + hh, w, 1, p.border);
    var cx = x0 + state::px(16);
    var k0: i64 = 0;
    var kn: i64 = 0;
    var ci: i32 = 0;
    while kn <= keys.len {
        if kn == keys.len || keys[kn] == '\n' {
            if kn > k0 && ci < cols {
                let key = keys[k0..kn];
                win::text_at(state::f_code_small, cx + state::px(8), top + state::px(6), key, p.text);
                win::fill(cx, top, 1, hh, p.border);
            }
            k0 = kn + 1;
            cx = cx + colw;
            ci++;
        }
        kn++;
    }
    var y = top + hh + 1;
    var row: i32 = 0;
    while y + rowh <= y0 + h {
        let line, a, b = line_at(s, row);
        if line < row { break; }
        if b > a {
            var cx2 = x0 + state::px(16);
            var kk0: i64 = 0;
            var kk: i64 = 0;
            while kk <= keys.len {
                if kk == keys.len || keys[kk] == '\n' {
                    if kk > kk0 && cx2 < x0 + w - state::px(8) {
                        let v = jl_value(s[a..b], keys[kk0..kk]);
                        win::text_at(state::f_code_small, cx2 + state::px(8), y + state::px(3),
                                     v[0..v.len], p.text);
                    }
                    kk0 = kk + 1;
                    cx2 = cx2 + colw;
                    if cx2 > x0 + w { break; }
                }
                kk++;
            }
            win::fill(x0 + state::px(16), y + rowh, w - state::px(16), 1, p.line);
        }
        row++;
        y = y + rowh;
    }
}

fn paint_image(path: const u8[:], x0: i32, y0: i32, w: i32, h: i32, name: const u8[:]) {
    let p = theme::pal;
    if !same_path(img_path[0..img_path.len], path) {
        if img_handle != 0 { win::gs_img_free(img_handle); img_handle = 0; }
        img_path.resize(0);
        img_path.append(path);
        img_handle = win::gs_img_load(path[0], path.len as i64);
    }
    win::text_at(state::f_ui, x0 + state::px(16), y0 + state::px(8), name, p.muted);
    if img_handle == 0 {
        var msg: u8[>..] = [];
        msg.append("无法显示这张图片");
        win::text_at(state::f_ui, x0 + state::px(16), y0 + state::px(32), msg, p.muted);
        return;
    }
    let iw = win::gs_img_w(img_handle) as i32;
    let ih = win::gs_img_h(img_handle) as i32;
    if iw <= 0 || ih <= 0 { return; }
    let maxw = w - state::px(48);
    let maxh = h - state::px(60);
    var dw = iw;
    var dh = ih;
    if dw > maxw { dh = dh * maxw / dw; dw = maxw; }
    if dh > maxh { dw = dw * maxh / dh; dh = maxh; }
    if dw < 1 { dw = 1; }
    if dh < 1 { dh = 1; }
    let ix = x0 + (w - dw) / 2;
    let iy = y0 + state::px(30) + (h - state::px(34) - dh) / 2;
    win::draw_image(img_handle, ix, iy, dw, dh);
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
    if is_jsonl(d.path) && !jl_mode_source() {
        paint_jsonl(d.path[0..d.path.len], x0, y0, w, h, d.name[0..d.name.len]);
        return;
    }
    if state::wrap_enabled { paint_wrapped(x0, y0, w, h); return; }
    if is_image(d.path) {
        paint_image(d.path[0..d.path.len], x0, y0, w, h, d.name[0..d.name.len]);
        return;
    }
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
    let caret_line, caret_byte = text::line_col(d.sel_b);
    let caret_col = text::col_cells(state::cur, d.sel_b) as i64;
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
        state::ime_x = cx;
        state::ime_y = cy + state::line_h;
        if caret_line >= first && caret_line < first + count {
            win::fill(cx, cy + state::px(2), state::px(2), state::line_h - state::px(4), p.text);
        }
    }
    // the IME composition (pinyin before it turns into Chinese) sits inline at
    // the caret, the way the reference shows it, instead of only in the IME box
    if state::ime_comp.len > 0 && state::focus == 0 {
        win::text_at(state::f_code, state::ime_x, state::ime_y - state::line_h,
                     state::ime_comp, p.accent);
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
    sub.append(i18n::t("迷い · 小巧、快速的代码编辑器"));
    win::text_at(state::f_ui, lx + state::px(74), top + state::px(36), sub, p.muted);

    var y = top + state::px(110);
    var head: u8[>..] = [];
    head.append(i18n::t("开始"));
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
    win::text_at(state::f_ui, tx + state::px(30), y + state::px(6), i18n::t(label), p.text);
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














