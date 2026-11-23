// The status bar: the folder, and the document's state.
namespace chrome;

import std;
import app.state;
import i18n;
import ui.theme;
import ui.win;
import editor.text;
import editor.vim;
import explore.tree;
// --- status bar --------------------------------------------------------------

fn right_item(rx: i32, s: const u8[:], c: u32) -> i32 {
    let y = state::H - state::status_h;
    let w = chw(state::f_small, s);
    ch(state::f_small, rx - w, y + state::status_h / 2, s, c);
    return rx - w - state::px(18);
}

fn right_item_f(rx: i32, s: const u8[:], c: u32, f: u64) -> i32 {
    let y = state::H - state::status_h;
    let w = chw(f, s);
    ch(f, rx - w, y + state::status_h / 2, s, c);
    return rx - w - state::px(18);
}

fn status_bar() {
    let p = theme::pal;
    let y = state::H - state::status_h;
    win::fill(0, y, state::W, state::status_h, p.status);
    win::fill(0, y, state::W, 1, p.border);
    icon_at(10, state::px(24), y + (state::status_h - state::px(16)) / 2, state::px(16), p.muted);
    let rootw = chw(state::f_small, state::root_name);
    ch(state::f_small, state::px(46), y + state::status_h / 2, state::root_name, p.text);
    if vim::on() && state::cur >= 0 && state::docs.len > 0 {
        let m = vim::mode_name();
        let mw = chw(state::f_small, m) + state::px(10);
        let mx = state::px(46) + rootw + state::px(12);
        let mh = state::px(17);
        var bg = win::mix(p.status, p.text, 90);
        var fg = p.status_fg;
        if vim::mode_of() == 1 { bg = p.accent; fg = p.chrome; }
        if vim::mode_of() == 2 || vim::mode_of() == 3 { bg = p.modified; fg = p.chrome; }
        win::round_rect(mx, y + (state::status_h - mh) / 2, mw, mh, state::px(4), state::px(4), bg);
        ch(state::f_small, mx + state::px(5), y + state::status_h / 2, m, fg);
        let pn = vim::pending_text();
        if pn.len > 0 { ch(state::f_small, mx + mw + state::px(8), y + state::status_h / 2, pn, p.status_fg); }
    }

    var rx = state::W - state::px(16);
    var lang = i18n::t("纯文本");
    if state::cur >= 0 && state::docs.len > 0 { lang = text::lang_name(state::docs[state::cur].lang); }
    rx = right_item(rx, lang, p.text);
    rx = right_item(rx, "LF", p.status_fg);
    rx = right_item(rx, "UTF-8", p.status_fg);
    rx = right_item_f(rx, i18n::t("制表符"), p.status_fg, state::f_cjk);
    if state::cur >= 0 && state::docs.len > 0 {
        let n = text::nlines();
        var lines: u8[>..] = [];
        var v: i64 = n;
        var num: u8[>..] = [];
        format(num, v);
        var k: i64 = 0;
        var cut = 0;
        while k < num.len {
            lines.push(num[k]);
            k++;
            cut++;
            if (num.len - k) % 3 == 0 && k < num.len { lines.push(44); }
        }
        lines.append(" 行");
        rx = right_item_f(rx, lines, p.status_fg, state::f_cjk);
        let d = state::docs[state::cur];
        let l, c = text::line_col(d.sel_b);
        var pos: u8[>..] = [];
        pos.append("行 ");
        num.resize(0);
        format(num, l + 1);
        k = 0;
        while k < num.len { pos.push(num[k]); k++; }
        pos.append(",  列  ");
        num.resize(0);
        format(num, c + 1);
        k = 0;
        while k < num.len { pos.push(num[k]); k++; }
        right_item_f(rx, pos, p.text, state::f_cjk);
    }
}








