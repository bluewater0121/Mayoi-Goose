// Vim mode: normal and insert modes, motions, operators, the unnamed
// register, visual mode and the few ex commands an editor needs. The
// reference keeps this in cmd/mayoi/vim.go; the states and the keys are
// the same, a subset of the commands it knows.
namespace vim;

import std;
import app.state;
import editor.text;
import editor.syntax;
import app.input.edit;
import app.input.file;
import app.input.vk;
import app.prefs.model;

let M_NORMAL = 0; let M_INSERT = 1; let M_VISUAL = 2; let M_VLINE = 3; let M_EX = 4;

var mode: i32 = 0;
var count: i32 = 0;
var op: i32 = 0;            // 1 delete, 2 change, 3 yank
var keys: u8[>..] = [];     // the keys of the command typed so far
var ex: u8[>..] = [];       // the command line after ':'
var reg: u8[>..] = [];      // the unnamed register
var reg_lines = false;
var anchor: i64 = 0;        // the fixed end of a visual selection
var awaiting_g = false;
var doc: i32 = -1;

fn on() -> bool { return prefs::bool_of("vim"); }

fn mode_of() -> i32 { return mode; }

fn mode_name() -> const u8[:] {
    if mode == M_INSERT { return "INSERT"; }
    if mode == M_VISUAL { return "VISUAL"; }
    if mode == M_VLINE { return "V-LINE"; }
    if mode == M_EX { return "EX"; }
    return "NORMAL";
}

fn pending_text() -> const u8[:] { return keys[0..keys.len]; }

fn sync() {
    if state::cur != doc {
        doc = state::cur;
        mode = M_NORMAL;
        count = 0;
        op = 0;
        keys.resize(0);
        ex.resize(0);
        awaiting_g = false;
    }
}

fn reset() {
    mode = M_NORMAL;
    count = 0;
    op = 0;
    keys.resize(0);
    ex.resize(0);
    awaiting_g = false;
}

fn same(a: const u8[:], b: const u8[:]) -> bool {
    if a.len != b.len { return false; }
    var i: i64 = 0;
    while i < a.len { if a[i] != b[i] { return false; } i++; }
    return true;
}

fn space(c: u8) -> bool { return c == ' ' || c == '\t' || c == '\n' || c == '\r'; }

fn wordc(c: u8) -> bool {
    return (c >= '0' && c <= '9') || (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z')
        || c == '_' || c >= 0x80;
}

fn line_of(p: i64) -> i32 {
    let l, c = text::line_col(p);
    return l;
}

fn first_nonspace(line: i32) -> i64 {
    let d = state::docs[state::cur];
    let a = text::line_start(line);
    let b = text::line_end(line);
    var p = a;
    while p < b && (state::arena[d.off + p] == ' ' || state::arena[d.off + p] == '\t') { p++; }
    return p;
}

fn prev_char(p: i64) -> i64 {
    if p <= 0 { return 0; }
    let d = state::docs[state::cur];
    var q = p - 1;
    while q > 0 && (state::arena[d.off + q] & 0xC0) == 0x80 { q--; }
    return q;
}

fn next_char(p: i64) -> i64 {
    let d = state::docs[state::cur];
    if p >= d.len { return d.len; }
    var q = p + 1;
    while q < d.len && (state::arena[d.off + q] & 0xC0) == 0x80 { q++; }
    return q;
}

fn word_fwd(p0: i64) -> i64 {
    let d = state::docs[state::cur];
    var p = p0;
    if p >= d.len { return d.len; }
    if wordc(state::arena[d.off + p]) {
        while p < d.len && wordc(state::arena[d.off + p]) { p++; }
    } else if !space(state::arena[d.off + p]) {
        while p < d.len && !space(state::arena[d.off + p]) && !wordc(state::arena[d.off + p]) { p++; }
    }
    while p < d.len && space(state::arena[d.off + p]) { p++; }
    return p;
}

fn word_back(p0: i64) -> i64 {
    let d = state::docs[state::cur];
    var p = p0;
    if p <= 0 { return 0; }
    p = prev_char(p);
    while p > 0 && space(state::arena[d.off + p]) { p = prev_char(p); }
    if wordc(state::arena[d.off + p]) {
        while p > 0 && wordc(state::arena[d.off + prev_char(p)]) { p = prev_char(p); }
    } else {
        while p > 0 && !space(state::arena[d.off + prev_char(p)])
            && !wordc(state::arena[d.off + prev_char(p)]) { p = prev_char(p); }
    }
    return p;
}

fn word_end(p0: i64) -> i64 {
    let d = state::docs[state::cur];
    var p = p0;
    if p >= d.len { return d.len - 1; }
    if p < d.len { p = next_char(p); }
    while p < d.len && space(state::arena[d.off + p]) { p = next_char(p); }
    while p + 1 < d.len && wordc(state::arena[d.off + p]) && wordc(state::arena[d.off + p + 1]) { p++; }
    if p >= d.len { return d.len - 1; }
    return p;
}

fn move(p: i64) {
    text::set_caret(state::cur, p, false);
    input::ensure_visible();
}

fn goto_line(n: i32) {
    var l = n - 1;
    if l < 0 { l = 0; }
    if l > text::nlines() - 1 { l = text::nlines() - 1; }
    move(first_nonspace(l));
}

fn set_mode(m: i32) {
    mode = m;
    count = 0;
    keys.resize(0);
    awaiting_g = false;
}

// --- the register ------------------------------------------------------------

fn yank(a: i64, b: i64, lines: bool) {
    reg.resize(0);
    reg_lines = lines;
    let d = state::docs[state::cur];
    var i = a;
    var e = b;
    if i < 0 { i = 0; }
    if e > d.len { e = d.len; }
    while i < e { reg.push(state::arena[d.off + i]); i++; }
}

fn after_change() {
    syntax::invalidate();
    input::ensure_visible();
}

fn delete_to(a: i64, b: i64, lines: bool, change: bool) {
    if b <= a { return; }
    yank(a, b, lines);
    text::delete_range(state::cur, a, b, 0);
    text::set_caret(state::cur, a, false);
    after_change();
}

// line_span is the lines n down (or up) from the line of p, whole.
fn line_span(p: i64, n: i32) -> i64, i64, bool {
    let line = line_of(p);
    var l2 = line + n - 1;
    if n <= 0 { l2 = line; }
    if l2 < 0 { l2 = 0; }
    if l2 > text::nlines() - 1 { l2 = text::nlines() - 1; }
    let a = text::line_start(line);
    var b = text::line_end(l2);
    if b < state::docs[state::cur].len { b++; }
    return a, b, true;
}

fn run_op(a: i64, b: i64, lines: bool) {
    if op == 3 {
        yank(a, b, lines);
        text::set_caret(state::cur, a, false);
        input::ensure_visible();
    } else if op == 1 {
        delete_to(a, b, lines, false);
    } else if op == 2 {
        delete_to(a, b, lines, true);
        mode = M_INSERT;
    }
    op = 0;
    count = 0;
    keys.resize(0);
}

fn apply_op(ch: u8) {
    let d = state::docs[state::cur];
    let p = d.sel_b;
    if ch == 'd' || ch == 'c' || ch == 'y' {
        let a, b, lines = line_span(p, if count > 0 { count } else { 1 });
        run_op(a, b, lines);
        return;
    }
    if ch == 'w' { run_op(p, word_fwd(p), false); return; }
    if ch == 'b' { run_op(word_back(p), p, false); return; }
    if ch == 'e' { run_op(p, word_end(p) + 1, false); return; }
    if ch == '0' { run_op(text::line_start(line_of(p)), p, false); return; }
    if ch == '$' { run_op(p, text::line_end(line_of(p)), false); return; }
    if ch == 'h' { if p > 0 { run_op(prev_char(p), p, false); } return; }
    if ch == 'l' { if p < d.len { run_op(p, next_char(p), false); } return; }
    if ch == 'j' {
        let line = line_of(p);
        let n = if count > 0 { count } else { 1 };
        let a, b, lines = line_span(p, n + 1);
        if count > 0 { run_op(a, b, true); } else { run_op(text::line_start(line), b, true); }
        return;
    }
    if ch == 'k' {
        let line = line_of(p);
        let n = if count > 0 { count } else { 1 };
        var l2 = line - n;
        if l2 < 0 { l2 = 0; }
        run_op(text::line_start(l2), if text::line_end(line) < d.len { text::line_end(line) + 1 } else { text::line_end(line) }, true);
        return;
    }
    if ch == 'g' {
        run_op(0, text::line_start(line_of(p)), true);
        return;
    }
    if ch == 'G' {
        let lastl = text::nlines() - 1;
        run_op(text::line_start(line_of(p)), if text::line_end(lastl) < d.len { text::line_end(lastl) + 1 } else { text::line_end(lastl) }, true);
        return;
    }
    op = 0;
    count = 0;
    keys.resize(0);
}

// --- normal mode -------------------------------------------------------------

fn paste(after: bool) {
    if reg.len == 0 { return; }
    let d = state::docs[state::cur];
    var at = d.sel_b;
    if reg_lines {
        let line = line_of(at);
        at = if after { text::line_end(line) } else { text::line_start(line) };
        if after && at < d.len { at++; }
    } else if after && at < d.len {
        at = next_char(at);
    }
    text::insert_at(state::cur, at, reg[0..reg.len], 0);
    text::set_caret(state::cur, at, false);
    after_change();
}

fn delete_char(n: i32) {
    let d = state::docs[state::cur];
    if d.sel_b >= d.len { return; }
    var b = d.sel_b;
    var i: i32 = 0;
    while i < n { b = next_char(b); i++; }
    yank(d.sel_b, b, false);
    text::delete_range(state::cur, d.sel_b, b, 0);
    after_change();
}

fn insert_at_caret(delta: i64) {
    let d = state::docs[state::cur];
    var p = d.sel_b + delta;
    if p < 0 { p = 0; }
    if p > d.len { p = d.len; }
    text::set_caret(state::cur, p, false);
    mode = M_INSERT;
    input::ensure_visible();
}

fn open_line(below: bool) {
    let d = state::docs[state::cur];
    var nl: u8[>..] = [];
    nl.push('\n');
    if below {
        let line = line_of(d.sel_b);
        let e = text::line_end(line);
        text::insert_at(state::cur, e, nl[0..nl.len], 0);
        text::set_caret(state::cur, e + 1, false);
    } else {
        let a = text::line_start(line_of(d.sel_b));
        text::insert_at(state::cur, a, nl[0..nl.len], 0);
        text::set_caret(state::cur, a, false);
    }
    mode = M_INSERT;
    after_change();
}

fn visual_start(lines: bool) {
    let d = state::docs[state::cur];
    anchor = d.sel_b;
    if lines {
        let line = line_of(d.sel_b);
        anchor = text::line_start(line);
        text::set_caret(state::cur, anchor, true);
        text::set_caret(state::cur, text::line_end(line), true);
        mode = M_VLINE;
    } else {
        text::set_caret(state::cur, anchor, true);
        mode = M_VISUAL;
    }
}

fn exec(ch: u8) {
    let d = state::docs[state::cur];
    let n = if count > 0 { count } else { 1 };
    count = 0;
    keys.resize(0);
    if ch == 'h' { var i: i32 = 0; while i < n { input::col_move(-1, false); i++; } return; }
    if ch == 'l' { var i2: i32 = 0; while i2 < n { input::col_move(1, false); i2++; } return; }
    if ch == 'j' { input::line_move(n, false); return; }
    if ch == 'k' { input::line_move(-n, false); return; }
    if ch == 'w' { var j: i32 = 0; while j < n { move(word_fwd(state::docs[state::cur].sel_b)); j++; } return; }
    if ch == 'b' { var k: i32 = 0; while k < n { move(word_back(state::docs[state::cur].sel_b)); k++; } return; }
    if ch == 'e' { var m: i32 = 0; while m < n { move(word_end(state::docs[state::cur].sel_b)); m++; } return; }
    if ch == '0' { move(text::line_start(line_of(d.sel_b))); return; }
    if ch == '^' { move(first_nonspace(line_of(d.sel_b))); return; }
    if ch == '$' { move(text::line_end(line_of(d.sel_b))); return; }
    if ch == 'G' { if n > 1 { goto_line(n); } else { goto_line(text::nlines()); } return; }
    if ch == 'x' { delete_char(n); return; }
    if ch == 'p' { paste(true); return; }
    if ch == 'P' { paste(false); return; }
    if ch == 'i' { insert_at_caret(0); return; }
    if ch == 'a' { insert_at_caret(1); return; }
    if ch == 'I' { text::set_caret(state::cur, first_nonspace(line_of(d.sel_b)), false); mode = M_INSERT; return; }
    if ch == 'A' { text::set_caret(state::cur, text::line_end(line_of(d.sel_b)), false); mode = M_INSERT; return; }
    if ch == 'o' { open_line(true); return; }
    if ch == 'O' { open_line(false); return; }
    if ch == 'u' { text::undo_edit(); after_change(); return; }
    if ch == 'v' { visual_start(false); return; }
    if ch == 'V' { visual_start(true); return; }
    if ch == ':' { mode = M_EX; ex.resize(0); keys.resize(0); return; }
}

fn normal_key(ch: u8) {
    if (ch >= '1' && ch <= '9') || (ch == '0' && count > 0) {
        count = count * 10 + (ch as i32 - 48);
        if keys.len < 16 { keys.push(ch); }
        return;
    }
    if op != 0 { if keys.len < 16 { keys.push(ch); } apply_op(ch); return; }
    if awaiting_g {
        awaiting_g = false;
        if ch == 'g' {
            if op == 0 && count > 0 { goto_line(count); } else { goto_line(1); }
            count = 0;
            keys.resize(0);
            return;
        }
        if keys.len < 16 { keys.push(ch); }
        apply_op(ch);
        return;
    }
    if ch == 'g' { awaiting_g = true; if keys.len < 16 { keys.push(ch); } return; }
    if ch == 'd' { op = 1; if keys.len < 16 { keys.push(ch); } return; }
    if ch == 'c' { op = 2; if keys.len < 16 { keys.push(ch); } return; }
    if ch == 'y' { op = 3; if keys.len < 16 { keys.push(ch); } return; }
    exec(ch);
}

// --- visual mode -------------------------------------------------------------

fn visual_key(ch: u8) {
    if ch == 'h' { input::col_move(-1, true); return; }
    if ch == 'l' { input::col_move(1, true); return; }
    if ch == 'j' { input::line_move(1, true); return; }
    if ch == 'k' { input::line_move(-1, true); return; }
    if ch == 'J' {
        let a = text::sel_min(state::cur);
        let b = text::sel_max(state::cur);
        let l1, c1 = text::line_col(a);
        let l2, c2 = text::line_col(b);
        var ln = l2;
        while ln > l1 {
            ln--;
            let e = text::line_end(ln);
            if e < state::docs[state::cur].len && state::arena[state::docs[state::cur].off + e] == '\n' {
                text::replace(state::cur, e, e + 1, " ", 0);
            }
        }
        text::set_caret(state::cur, a, false);
        after_change();
        reset();
        return;
    }
    if ch == '>' || ch == '<' {
        let a = text::sel_min(state::cur);
        let b = text::sel_max(state::cur);
        let l1, c1 = text::line_col(a);
        let l2, c2 = text::line_col(b);
        var ln = l2 + 1;
        while ln > l1 {
            ln--;
            let s = text::line_start(ln);
            if ch == '>' {
                text::insert_at(state::cur, s, "    ", 0);
            } else {
                var n: i64 = 0;
                while n < 4 && s + n < state::docs[state::cur].len &&
                      state::arena[state::docs[state::cur].off + s + n] == ' ' { n++; }
                if n > 0 { text::delete_range(state::cur, s, s + n, 0); }
            }
        }
        text::set_caret(state::cur, text::line_start(l1), false);
        after_change();
        reset();
        return;
    }
    if ch == 'd' || ch == 'y' || ch == 'c' {
        let a = text::sel_min(state::cur);
        var b = text::sel_max(state::cur);
        if b == a { b = next_char(b); }
        if ch == 'y' { yank(a, b, mode == M_VLINE); reset(); move(a); return; }
        yank(a, b, mode == M_VLINE);
        text::delete_range(state::cur, a, b, 0);
        text::set_caret(state::cur, a, false);
        after_change();
        if ch == 'c' { mode = M_INSERT; } else { reset(); }
        return;
    }
}

// --- the command line --------------------------------------------------------

fn run_ex() {
    var cmd: u8[>..] = [];
    var i: i64 = 0;
    while i < ex.len { if ex[i] != ' ' && ex[i] != '\t' { cmd.push(ex[i]); } i++; }
    let s = cmd[0..cmd.len];
    if same(s, "w") {
        input::save_file();
    } else if same(s, "q") {
        input::close_tab(state::cur);
    } else if same(s, "wq") || same(s, "x") {
        input::save_file();
        input::close_tab(state::cur);
    } else if s.len > 0 && s[0] >= '0' && s[0] <= '9' {
        var n: i32 = 0;
        var k: i64 = 0;
        while k < s.len { n = n * 10 + (s[k] as i32 - 48); k++; }
        goto_line(n);
    }
    reset();
}

// --- the keys ----------------------------------------------------------------

fn key(vk: i32, ctrl: bool, shift: bool, alt: bool) -> bool {
    if !on() { return false; }
    sync();
    if vk == input::VK_ESC {
        if mode == M_EX { reset(); return true; }
        if mode == M_INSERT {
            let d = state::docs[state::cur];
            if d.sel_b > 0 { text::set_caret(state::cur, prev_char(d.sel_b), false); }
            mode = M_NORMAL;
            input::ensure_visible();
            return true;
        }
        if mode == M_VISUAL || mode == M_VLINE {
            text::set_caret(state::cur, state::docs[state::cur].sel_b, false);
            reset();
            return true;
        }
        reset();
        return true;
    }
    if mode == M_EX {
        if vk == input::VK_RET { run_ex(); return true; }
        if vk == input::VK_BACK {
            if ex.len > 0 { ex.resize(ex.len - 1); }
            if keys.len > 0 { keys.resize(keys.len - 1); }
            return true;
        }
        return false;
    }
    if mode == M_INSERT { return false; }
    if ctrl {
        if prefs::bool_of("vimCtrlKeys") && (vk == 70 || vk == 66 || vk == 82 || vk == 65 || vk == 88) { return false; }
        if vk == 82 { text::redo_edit(); after_change(); return true; }
        return false;
    }
    if vk == input::VK_RET || vk == input::VK_BACK || vk == input::VK_TAB { return true; }
    return false;
}

fn char(c: u16) {
    if !on() { return; }
    sync();
    if c < 32 || c > 126 { return; }
    let ch = c as u8;
    if mode == M_EX {
        if ex.len < 120 { ex.push(ch); }
        if keys.len < 16 { keys.push(ch); }
        return;
    }
    if mode == M_VISUAL || mode == M_VLINE { visual_key(ch); return; }
    if mode == M_INSERT { return; }
    normal_key(ch);
}
