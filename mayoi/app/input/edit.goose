// Typing, the caret and the scroll that follows it.
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


fn lexicographic_marker() { }

fn visible_rows() -> i32 {
    let h = state::ed_bot - state::ed_top;
    return (h - state::px(12)) / state::line_h;
}

fn ensure_visible() {
    if state::cur < 0 { return; }
    let d .= state::docs[state::cur];
    let line, col = text::line_col(d.sel_b);
    let rows = input::visible_rows();
    if line < d.scroll { d.scroll = line; }
    if line >= d.scroll + rows { d.scroll = line - rows + 1; }
    let cells = text::col_cells(state::cur, d.sel_b);
    if cells < d.scroll_x { d.scroll_x = cells; }
    let width = (state::ed_right - state::code_x) / state::cell_w;
    if cells >= d.scroll_x + width { d.scroll_x = cells - width + 2; }
}

fn typed(b: const u8[:]) {
    if state::cur < 0 { return; }
    let d .= state::docs[state::cur];
    let a = text::sel_min(state::cur);
    let e = text::sel_max(state::cur);
    if a != e { text::replace(state::cur, a, e, b, 0); text::set_caret(state::cur, a, false); }
    else { text::insert_at(state::cur, d.sel_b, b, 1); text::set_caret(state::cur, d.sel_b + b.len, false); }
    syntax::invalidate();
    input::ensure_visible();
}

fn char_typed(c: u16) {
    if state::overlay != 0 { input::overlay_char(c); return; }
    if state::cur < 0 { return; }
    var b: u8[>..] = [];
    if c < 0x80 { b.push(c as u8); }
    else if c < 0x800 { b.push((0xC0 | (c >> 6)) as u8); b.push((0x80 | (c & 0x3F)) as u8); }
    else if c >= 0xD800 && c < 0xDC00 {
        // a lead surrogate; the trail arrives as the next WM_CHAR
        return;
    }
    else {
        b.push((0xE0 | (c >> 12)) as u8);
        b.push((0x80 | ((c >> 6) & 0x3F)) as u8);
        b.push((0x80 | (c & 0x3F)) as u8);
    }
    input::typed(b);
}

fn newline() {
    if state::cur < 0 { return; }
    let d .= state::docs[state::cur];
    let a = text::sel_min(state::cur);
    let e = text::sel_max(state::cur);
    var ins: u8[>..] = [];
    ins.push('\n');
    // keep the indentation of the line being left
    let line = text::line_col(d.sel_b);
    let ls = text::line_start(line);
    var q = ls;
    while q < d.sel_b {
        let c = state::arena[d.off + q];
        if c == ' ' || c == '\t' { ins.push(c); q++; } else { break; }
    }
    if a != e { text::replace(state::cur, a, e, ins, 0); text::set_caret(state::cur, a + ins.len, false); }
    else { text::insert_at(state::cur, d.sel_b, ins, 0); text::set_caret(state::cur, d.sel_b + ins.len, false); }
    syntax::invalidate();
    input::ensure_visible();
}

fn backspace() {
    if state::cur < 0 { return; }
    let d .= state::docs[state::cur];
    let a = text::sel_min(state::cur);
    let e = text::sel_max(state::cur);
    if a != e {
        text::delete_range(state::cur, a, e, 0);
        text::set_caret(state::cur, a, false);
    } else {
        if d.sel_b == 0 { return; }
        var p = d.sel_b - 1;
        while p > 0 {
            let c = state::arena[d.off + p];
            if (c & 0xC0) != 0x80 { break; }
            p--;
        }
        text::delete_range(state::cur, p, d.sel_b, 0);
        text::set_caret(state::cur, p, false);
    }
    syntax::invalidate();
    input::ensure_visible();
}

fn delete_forward() {
    if state::cur < 0 { return; }
    let d .= state::docs[state::cur];
    let a = text::sel_min(state::cur);
    let e = text::sel_max(state::cur);
    if a != e { text::delete_range(state::cur, a, e, 0); text::set_caret(state::cur, a, false); }
    else {
        if d.sel_b >= d.len { return; }
        var p = d.sel_b + 1;
        while p < d.len {
            if (state::arena[d.off + p] & 0xC0) != 0x80 { break; }
            p++;
        }
        text::delete_range(state::cur, d.sel_b, p, 0);
    }
    syntax::invalidate();
}

fn move_caret(to: i64, keep: bool) {
    text::set_caret(state::cur, to, keep);
    input::ensure_visible();
}

fn line_move(delta: i32, keep: bool) {
    let d .= state::docs[state::cur];
    let line, col = text::line_col(d.sel_b);
    let cells = text::col_cells(state::cur, d.sel_b);
    var nl = line + delta;
    if nl < 0 { nl = 0; }
    if nl > text::nlines() - 1 { nl = text::nlines() - 1; }
    let p = text::pos_at_col(state::cur, nl, cells);
    input::move_caret(p, keep);
}

fn col_move(delta: i32, keep: bool) {
    let d .= state::docs[state::cur];
    var dd = delta;
    var p = d.sel_b;
    if delta < 0 {
        if p == 0 { return; }
        var k = 0;
        while k < -dd {
            p--;
            while p > 0 {
                let c = state::arena[d.off + p];
                if (c & 0xC0) != 0x80 { break; }
                p--;
            }
            k++;
        }
    } else {
        while p < d.len && dd > 0 {
            p++;
            while p < d.len {
                if (state::arena[d.off + p] & 0xC0) != 0x80 { break; }
                p++;
            }
            dd--;
        }
    }
    input::move_caret(p, keep);
}

fn word_move(dir: i32, keep: bool) {
    let d .= state::docs[state::cur];
    var p = d.sel_b;
    if dir < 0 {
        while p > 0 {
            p--;
            let c = state::arena[d.off + p];
            if c == ' ' || c == '\t' || c == '\n' || c == '(' || c == ')' || c == ',' || c == '.' { break; }
        }
    } else {
        while p < d.len {
            let c = state::arena[d.off + p];
            if c == ' ' || c == '\t' || c == '\n' || c == '(' || c == ')' || c == ',' || c == '.' { p++; break; }
            p++;
        }
    }
    input::move_caret(p, keep);
}

fn click_editor(mx: i32, my: i32, keep: bool) {
    if state::cur < 0 { return; }
    let d .= state::docs[state::cur];
    var line = (my - state::ed_top - state::px(8)) / state::line_h + d.scroll;
    if line < 0 { line = 0; }
    if line > text::nlines() - 1 { line = text::nlines() - 1; }
    var col = (mx - state::code_x) / state::cell_w + d.scroll_x;
    if col < 0 { col = 0; }
    let p = text::pos_at_col(state::cur, line, col);
    input::move_caret(p, keep);
}

fn wheel(notches: i32) {
    if state::preview_open && state::mx >= state::pv_x0 && state::mx < state::pv_x0 + state::pv_w
        && state::my >= state::pv_y0 && state::my < state::pv_y0 + state::pv_h {
        var ps = state::preview_scroll - notches * 48;
        if ps < 0 { ps = 0; }
        if ps > state::pv_max { ps = state::pv_max; }
        state::preview_scroll = ps;
        win::invalidate();
        return;
    }
    if state::cur < 0 { return; }
    let d .= state::docs[state::cur];
    var s = d.scroll - notches * 3;
    if s < 0 { s = 0; }
    if s > text::nlines() - 1 { s = text::nlines() - 1; }
    d.scroll = s;
    win::invalidate();
}
