// Markdown preview: the document's text laid out as headings, paragraphs,
// lists, quotes, code blocks and rules, the way the reference's preview pane
// shows it. It is drawn beside the editor or in its place, and scrolls on its
// own while the editor keeps its place.
namespace preview;

import std;
import app.state;
import ui.theme;
import ui.win;
import editor.text;

fn is_space(c: u8) -> bool { return c == ' ' || c == '\t'; }

fn trim_start(s: const u8[:]) -> i64 {
    var i: i64 = 0;
    while i < s.len && is_space(s[i]) { i++; }
    return i;
}

fn trim_end(s: const u8[:]) -> i64 {
    var j = s.len;
    while j > 0 && is_space(s[j - 1]) { j--; }
    return j;
}

fn has_at(s: const u8[:], i: i64, p: const u8[:]) -> bool {
    if i + p.len > s.len { return false; }
    var k: i64 = 0;
    while k < p.len { if s[i + k] != p[k] { return false; } k++; }
    return true;
}

fn heading_level(s: const u8[:]) -> i32 {
    let a = trim_start(s);
    if a >= s.len { return 0; }
    if s[a] != '#' { return 0; }
    var n: i32 = 0;
    var i = a;
    while i < s.len && s[i] == '#' { n++; i++; }
    if n > 6 { return 0; }
    if i < s.len && s[i] != ' ' { return 0; }
    return n;
}

fn is_rule(s: const u8[:]) -> bool {
    let a = trim_start(s);
    let b = trim_end(s);
    if b - a < 3 { return false; }
    var c = s[a];
    if c != '-' && c != '*' && c != '_' { return false; }
    var i = a;
    while i < b { if s[i] != c && s[i] != ' ' { return false; } i++; }
    return true;
}

fn is_quote(s: const u8[:]) -> bool {
    let a = trim_start(s);
    return a < s.len && s[a] == '>';
}

fn list_mark(s: const u8[:], out: i32&) -> bool {
    let a = trim_start(s);
    if a >= s.len { return false; }
    if (s[a] == '-' || s[a] == '*' || s[a] == '+') && a + 1 < s.len && s[a + 1] == ' ' { out = 0; return true; }
    var i = a;
    while i < s.len && s[i] >= '0' && s[i] <= '9' { i++; }
    if i > a && i + 1 < s.len && s[i] == '.' && s[i + 1] == ' ' { out = 1; return true; }
    return false;
}

fn blank(s: const u8[:]) -> bool { return trim_end(s) == 0; }

fn is_table_row(s: const u8[:]) -> bool {
    let a = trim_start(s);
    var b = trim_end(s);
    if a >= b || s[a] != '|' { return false; }
    return true;
}

// table_sep is the |---|---| line under a table header.
fn table_sep(s: const u8[:]) -> bool {
    if !is_table_row(s) { return false; }
    let a = trim_start(s);
    let b = trim_end(s);
    var dashes: i32 = 0;
    var i = a;
    while i < b {
        let c = s[i];
        if c == '-' { dashes++; }
        if c != '|' && c != '-' && c != ':' && c != ' ' && c != '\t' { return false; }
        i++;
    }
    return dashes >= 1;
}

fn bars(s: const u8[:]) -> i32 {
    let a = trim_start(s);
    let b = trim_end(s);
    var n: i32 = 0;
    var i = a;
    while i < b { if s[i] == '|' { n++; } i++; }
    return n;
}

// cell_range returns the [start,end) of cell idx in a | a | b | row.
fn cell_range(s: const u8[:], idx: i32, start: i64&, end: i64&) {
    var n: i32 = 0;
    var a = trim_start(s);
    var b = trim_end(s);
    var i = a + 1;
    var from = a + 1;
    while i < b {
        if s[i] == '|' {
            if n == idx { start = from; end = i; return; }
            n++;
            from = i + 1;
        }
        i++;
    }
    if n == idx { start = from; end = b; return; }
    start = 0;
    end = 0;
}

// fit draws s inside width w, cutting it at the last character that fits.
fn fit(f: u64, x: i32, y: i32, w: i32, s: const u8[:], c: u32) {
    var i: i64 = 0;
    var last: i64 = 0;
    while i < s.len {
        if win::measure(f, s[0..i + 1]) > w { break; }
        i++;
        last = i;
    }
    if last > 0 { win::text_at(f, x, y, s[0..last], c); }
}

// plain strips the inline marks of a line: **, *, `, [text](url) keeps text,
// and \ escapes the next character. What is left is what the width is
// measured against and what is drawn.
fn plain(s: const u8[:]) -> u8[>..] {
    var out: u8[>..] = [];
    var i: i64 = 0;
    while i < s.len {
        let c = s[i];
        if c == '\\' && i + 1 < s.len {
            let e = s[i + 1];
            if e == '*' || e == '_' || e == '`' || e == '[' || e == ']' || e == '\\' || e == '#' {
                out.push(e);
                i = i + 2;
                continue;
            }
        }
        if c == '*' {
            if i + 1 < s.len && s[i + 1] == '*' { i = i + 2; continue; }
            i++;
            continue;
        }
        if c == '`' { i++; continue; }
        if c == '[' {
            var j = i + 1;
            var inner: u8[>..] = [];
            while j < s.len && s[j] != ']' { inner.push(s[j]); j++; }
            if j < s.len && j + 1 < s.len && s[j + 1] == '(' {
                var k = j + 2;
                while k < s.len && s[k] != ')' { k++; }
                var q: i64 = 0;
                while q < inner.len { out.push(inner[q]); q++; }
                i = if k < s.len { k + 1 } else { j + 1 };
                continue;
            }
            out.push('[');
            var q2: i64 = 0;
            while q2 < inner.len { out.push(inner[q2]); q2++; }
            out.push(']');
            i = if j < s.len { j + 1 } else { j };
            continue;
        }
        out.push(c);
        i++;
    }
    return out;
}

fn line_text(line: i32) -> u8[>..] {
    var out: u8[>..] = [];
    if state::cur < 0 || state::docs.len == 0 { return out; }
    let d = state::docs[state::cur];
    let ls = text::line_start(line);
    let le = text::line_end(line);
    var p = ls;
    while p < le && p < d.len {
        let c = state::arena[d.off + p];
        if c == '\r' || c == '\n' { break; }
        out.push(c);
        p++;
    }
    return out;
}

fn ulen(s: const u8[:], i: i64) -> i64 {
    let c = s[i];
    if (c & 0xF8) == 0xF0 { return 4; }
    if (c & 0xF0) == 0xE0 { return 3; }
    if (c & 0xE0) == 0xC0 { return 2; }
    return 1;
}

// rich_line lays out one paragraph keeping its inline marks: **bold**, `code`
// (surface chip), and [text](url) drawn as a link. It breaks at spaces and at
// the character that overflows, like wrap does.
fn rich_line(x: i32, y: i32, w: i32, s: const u8[:], c: u32, lh: i32, top: i32, bot: i32) -> i32 {
    let p = theme::pal;
    if s.len == 0 { return y + lh; }
    let right = x + w - state::px(6);
    var i: i64 = 0;
    var cx = x;
    var cy = y;
    var bold = false;
    var code = false;
    var link_end: i64 = -1;
    var link_skip: i64 = -1;
    while i < s.len {
        if i == link_end {
            i = link_skip;
            link_end = -1;
            link_skip = -1;
            continue;
        }
        let c0 = s[i];
        if link_end < 0 {
            if c0 == '*' && i + 1 < s.len && s[i + 1] == '*' { bold = !bold; i = i + 2; continue; }
            if c0 == '`' { code = !code; i = i + 1; continue; }
            if c0 == '[' && !code {
                var j = i + 1;
                while j < s.len && s[j] != ']' { j++; }
                if j < s.len && j + 1 < s.len && s[j + 1] == '(' {
                    var k = j + 2;
                    while k < s.len && s[k] != ')' { k++; }
                    link_end = j;
                    link_skip = if k < s.len { k + 1 } else { j + 1 };
                    i = i + 1;
                    continue;
                }
                i = i + 1;
                continue;
            }
            if c0 == '\\' && i + 1 < s.len {
                let e = s[i + 1];
                if e == '*' || e == '_' || e == '`' || e == '[' || e == ']' { i = i + 1; }
            }
        }
        let n = ulen(s, i);
        let f = if code { state::f_code_small } else if bold { state::f_ui_b } else { state::f_ui };
        let ch = s[i..i + n];
        let wch = win::measure(f, ch);
        if cx + wch > right && cx > x {
            cy = cy + lh;
            cx = x;
            if ch[0] == ' ' { i = i + n; continue; }
        }
        let col = if link_end >= 0 { p.accent } else { c };
        if cy >= top && cy + lh <= bot {
            if code && ch[0] != ' ' {
                win::fill(cx, cy + state::px(2), wch, lh - state::px(4), p.surface);
            }
            win::text_at(f, cx, cy, ch, col);
        }
        cx = cx + wch;
        i = i + n;
    }
    return cy + lh;
}
fn wrap(f: u64, x: i32, y: i32, w: i32, s: const u8[:], c: u32, lh: i32, top: i32, bot: i32) -> i32 {
    if s.len == 0 { return y + lh; }
    var i: i64 = 0;
    var start: i64 = 0;
    var last_space: i64 = -1;
    var line_y = y;
    while i < s.len {
        if is_space(s[i]) { last_space = i; }
        if win::measure(f, s[start..i + 1]) > w {
            var cut = i;
            if last_space > start { cut = last_space; }
            // never split a UTF-8 sequence in the middle
            while cut > start && cut < s.len && (s[cut] & 0xC0) == 0x80 { cut--; }
            if cut > start {
                if line_y >= top && line_y + lh <= bot {
                    win::text_at(f, x, line_y, s[start..cut], c);
                }
                line_y = line_y + lh;
                start = if cut == last_space { cut + 1 } else { cut };
                last_space = -1;
                continue;
            }
        }
        i++;
    }
    if line_y >= top && line_y + lh <= bot {
        win::text_at(f, x, line_y, s[start..s.len], c);
    }
    return line_y + lh;
}

var pv_img_path: u8[>..] = [];
var pv_img: u64 = 0;

fn md_image_url(s: const u8[:]) -> u8[>..] {
    var out: u8[>..] = [];
    let t = trim_start(s);
    if t + 1 >= s.len || s[t] != '!' || s[t + 1] != '[' { return out; }
    var i = t + 2;
    while i < s.len && s[i] != ']' { i++; }
    if i + 1 >= s.len || s[i + 1] != '(' { return out; }
    i = i + 2;
    while i < s.len && s[i] != ')' { out.push(s[i]); i++; }
    return out;
}

fn join_dir(dir: const u8[:], tail: const u8[:]) -> u8[>..] {
    var out: u8[>..] = [];
    out.append(dir);
    out.push('/');
    out.append(tail);
    return out;
}

fn doc_dir() -> u8[>..] {
    var out: u8[>..] = [];
    if state::cur < 0 || state::docs.len == 0 { return out; }
    let p = state::docs[state::cur].path;
    var last: i64 = -1;
    var i: i64 = 0;
    while i < p.len {
        if p[i] == '/' || p[i] == '\\' { last = i; }
        i++;
    }
    if last >= 0 { i = 0; while i < last { out.push(p[i]); i++; } }
    return out;
}

// md_image draws the picture of a line that is only ![alt](path), and
// returns the y after it.
fn md_image(s: const u8[:], left: i32, y: i32, right: i32, y0: i32, h: i32) -> i32 {
    let p = theme::pal;
    let url = md_image_url(s);
    if url.len == 0 { return y; }
    if url.len > 4 && url[0] == 'h' && url[1] == 't' { return y; }
    var path: u8[>..] = [];
    if url[0] == '/' || (url.len > 2 && url[1] == ':') { path.append(url); }
    else { path = join_dir(doc_dir(), url[0..url.len]); }
    if !same_pv_path(pv_img_path[0..pv_img_path.len], path[0..path.len]) {
        if pv_img != 0 { win::gs_img_free(pv_img); pv_img = 0; }
        pv_img_path.resize(0);
        pv_img_path.append(path);
        pv_img = win::gs_img_load(path[0], path.len as i64);
    }
    if pv_img == 0 { return y; }
    let iw = win::gs_img_w(pv_img) as i32;
    let ih = win::gs_img_h(pv_img) as i32;
    if iw <= 0 || ih <= 0 { return y; }
    var dw = iw;
    var dh = ih;
    let avail = right - left;
    if dw > avail { dh = dh * avail / dw; dw = avail; }
    if dh > h * 2 / 3 { dw = dw * (h * 2 / 3) / dh; dh = h * 2 / 3; }
    if y >= y0 && y <= y0 + h && dw > 0 && dh > 0 {
        win::draw_image(pv_img, left, y, dw, dh);
    }
    return y + dh + state::px(10);
}

fn same_pv_path(a: const u8[:], b: const u8[:]) -> bool {
    if a.len != b.len { return false; }
    var i: i64 = 0;
    while i < a.len { if a[i] != b[i] { return false; } i++; }
    return true;
}


fn paint(x0: i32, y0: i32, w: i32, h: i32) {
    let p = theme::pal;
    win::fill(x0, y0, w, h, p.editor);
    state::pv_x0 = x0;
    state::pv_y0 = y0;
    state::pv_w = w;
    state::pv_h = h;
    state::add_hit(state::HIT_PREVIEW, x0, y0, w, h, 0);
    if state::cur < 0 || state::docs.len == 0 { return; }
    let padx = state::px(28);
    let pady = state::px(20);
    let left = x0 + padx;
    let right = x0 + w - padx;
    if right - left < state::px(80) { return; }
    let n = text::nlines();
    var line: i32 = 0;
    var y = y0 + pady - state::preview_scroll;
    var in_code = false;
    var after_blank = true;
    var prev_y = y;
    while line < n {
        let raw = line_text(line);
        let s = raw[0..raw.len];
        let a0 = trim_start(s);
        if a0 + 2 < s.len && s[a0] == '`' && s[a0 + 1] == '`' && s[a0 + 2] == '`' {
            if in_code {
                in_code = false;
                y = y + state::px(8);
            } else {
                in_code = true;
                y = y + state::px(6);
            }
            line++;
            after_blank = false;
            continue;
        }
        if in_code {
            let b = trim_end(s);
            let body = s[0..b];
            if y >= y0 && y + state::px(20) <= y0 + h {
                win::fill(left - state::px(10), y - state::px(2), w - padx * 2 + state::px(20), state::px(21), p.surface);
                win::text_at(state::f_code, left, y, s, p.text);
            }
            y = y + state::px(20);
            line++;
            continue;
        }
        let iu = md_image_url(s);
        if iu.len > 0 {
            y = md_image(s, left, y, right, y0, h);
            after_blank = false;
            line++;
            continue;
        }
        if blank(s) {
            if !after_blank { y = y + state::px(10); }
            after_blank = true;
            line++;
            continue;
        }
        after_blank = false;
        let lev = heading_level(s);
        if lev > 0 {
            var i = trim_start(s) + lev;
            while i < s.len && s[i] == ' ' { i++; }
            let body = plain(s[i..trim_end(s)]);
            y = y + state::px(if lev <= 2 { 10 } else { 6 });
            var f = state::f_ui;
            if lev == 1 { f = state::f_title; }
            if lev == 2 || lev == 3 { f = state::f_ui_b; }
            let color = if lev <= 3 { p.text } else { p.muted };
            let lh = win::th(f) + state::px(6);
            y = wrap(f, left, y, right - left, body[0..body.len], color, lh, y0, y0 + h);
            y = y + state::px(4);
            line++;
            continue;
        }
        if is_rule(s) {
            let fy = y + state::px(8);
            if fy >= y0 && fy <= y0 + h {
                win::line(left, fy, right, fy, p.border, 1);
            }
            y = y + state::px(18);
            line++;
            continue;
        }
        if is_quote(s) {
            var i = trim_start(s) + 1;
            while i < s.len && is_space(s[i]) { i++; }
            let body = plain(s[i..trim_end(s)]);
            let lh = win::th(state::f_ui) + state::px(5);
            let y_start = y;
            y = rich_line(left + state::px(16), y, right - left - state::px(16), s[i..trim_end(s)], p.muted, lh, y0, y0 + h);
            if y_start >= y0 && y_start <= y0 + h {
                win::fill(left + state::px(4), y_start, state::px(3), y - y_start - state::px(3), p.accent_dim);
            }
            y = y + state::px(4);
            line++;
            continue;
        }
        if is_table_row(s) && bars(s) >= 3 {
            let cols = bars(s) - 1;
            var rows: i32 = 0;
            while line + rows < n {
                let t = line_text(line + rows);
                if !is_table_row(t[0..t.len]) { break; }
                rows++;
            }
            var cw: i32[>..] = [];
            cw.resize(cols, 0);
            var rr: i32 = 0;
            while rr < rows {
                let t = line_text(line + rr);
                let ts = t[0..t.len];
                var cc: i32 = 0;
                while cc < cols {
                    var a: i64 = 0;
                    var b: i64 = 0;
                    cell_range(ts, cc, a, b);
                    if b < a { b = a; }
                    if b > ts.len { b = ts.len; }
                    if b > a {
                        let cell = plain(ts[a..b]);
                        let cwid = win::measure(state::f_ui, cell[0..cell.len]) + state::px(20);
                        if cwid > cw[cc] { cw[cc] = cwid; }
                    }
                    cc++;
                }
                rr++;
            }
            var total: i32 = 0;
            var cc: i32 = 0;
            while cc < cols { total = total + cw[cc]; cc++; }
            let avail = right - left;
            if total > avail {
                var acc: i32 = 0;
                cc = 0;
                while cc < cols {
                    cw[cc] = if cc == cols - 1 { avail - acc } else { (cw[cc] * avail) / total };
                    if cw[cc] < state::px(40) { cw[cc] = state::px(40); }
                    acc = acc + cw[cc];
                    cc++;
                }
                total = acc;
            }
            let lh = win::th(state::f_ui) + state::px(14);
            let ty = y;
            rr = 0;
            var drawn_row: i32 = 0;
            while rr < rows {
                let t = line_text(line + rr);
                let ts = t[0..t.len];
                if table_sep(ts) { rr++; continue; }
                let ry = ty + drawn_row * lh;
                drawn_row++;
                if ry >= y0 - lh && ry <= y0 + h {
                    if rr == 0 {
                        win::fill(left, ry, total, lh, p.surface);
                    }
                    var cx = left;
                    cc = 0;
                    while cc < cols {
                        var a: i64 = 0;
                        var b: i64 = 0;
                        cell_range(ts, cc, a, b);
                        if b < a { b = a; }
                        if b > ts.len { b = ts.len; }
                        let cell = plain(ts[a..b]);
                        var body = cell[0..cell.len];
                        // trim the cell's own spaces
                        var st: i64 = 0;
                        while st < body.len && is_space(body[st]) { st++; }
                        var en: i64 = body.len;
                        while en > st && is_space(body[en - 1]) { en--; }
                        body = body[st..en];
                        let fnt = if rr == 0 { state::f_ui_b } else { state::f_ui };
                        let col = if rr == 0 { p.text } else { p.text };
                        fit(fnt, cx + state::px(10), ry + state::px(7), cw[cc] - state::px(14), body[0..body.len], col);
                        if cc > 0 && ry >= y0 && ry <= y0 + h {
                            win::line(cx, ry, cx, ry + lh, p.border, 1);
                        }
                        cx = cx + cw[cc];
                        cc++;
                    }
                    if ry >= y0 && ry <= y0 + h {
                        win::line(left, ry + lh, left + total, ry + lh, p.border, 1);
                    }
                }
                rr++;
            }
            if ty >= y0 && ty <= y0 + h {
                win::line(left, ty, left + total, ty, p.border, 1);
            }
            y = ty + drawn_row * lh + state::px(10);
            line = line + rows;
            after_blank = false;
            continue;
        }
        var mk: i32 = 0;
        if list_mark(s, mk) {
            let a = trim_start(s);
            var i = a;
            if mk == 1 { while i < s.len && s[i] != ' ' { i++; } } else { i = a + 1; }
            while i < s.len && is_space(s[i]) { i++; }
            let raw = s[i..trim_end(s)];
            let body = plain(raw);
            let lh = win::th(state::f_ui) + state::px(5);
            if y >= y0 && y <= y0 + h {
                win::text_at(state::f_ui, left + state::px(4), y, "•", p.accent);
            }
            // a task list item: "- [ ] text" or "- [x] text"
            if raw.len >= 4 && raw[0] == '[' && raw[2] == ']' && (raw[3] == ' ' || raw[1] == 'x' || raw[1] == 'X') {
                let box = state::px(12);
                let by = y + (lh - box) / 2;
                if y >= y0 && y <= y0 + h {
                    win::fill(left + state::px(20), by, box, box, p.border);
                    win::fill(left + state::px(20) + 1, by + 1, box - 2, box - 2, p.editor);
                    if raw[1] == 'x' || raw[1] == 'X' {
                        win::fill(left + state::px(20) + 3, by + 3, box - 6, box - 6, p.accent);
                    }
                }
                var rest: i64 = 3;
                while rest < raw.len && is_space(raw[rest]) { rest++; }
                let label = plain(raw[rest..raw.len]);
                y = rich_line(left + state::px(20) + box + state::px(8), y, right - left - state::px(20) - box - state::px(12),
                              raw[rest..raw.len], p.text, lh, y0, y0 + h);
                line++;
                continue;
            }
            y = rich_line(left + state::px(20), y, right - left - state::px(24), raw, p.text, lh, y0, y0 + h);
            line++;
            continue;
        }
        let body = plain(s[trim_start(s)..trim_end(s)]);
        let lh = win::th(state::f_ui) + state::px(7);
        y = rich_line(left, y, right - left, s[trim_start(s)..trim_end(s)], p.text, lh, y0, y0 + h);
        line++;
    }
    state::pv_total = y - (y0 + pady) + state::preview_scroll;
    let maxs = state::pv_total - h + pady;
    state::pv_max = if maxs > 0 { maxs } else { 0 };
    if state::preview_scroll > state::pv_max { state::preview_scroll = state::pv_max; }
    if state::preview_scroll < 0 { state::preview_scroll = 0; }
    // a thin scrollbar at the right edge, as the editor's
    if state::pv_max > 0 {
        let track_h = h - state::px(8);
        let thumb_h = (track_h * h) / (state::pv_total + state::px(1));
        var th = thumb_h;
        if th < state::px(24) { th = state::px(24); }
        let ty = y0 + state::px(4) + ((track_h - th) * state::preview_scroll) / state::pv_max;
        win::round_rect(x0 + w - state::px(7), ty, state::px(4), th, state::px(2), state::px(2), p.scrollbar);
    }
}



