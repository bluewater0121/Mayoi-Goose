// The title bar: the window buttons, the sidebar's, and the command center.
namespace chrome;

import std;
import app.state;
import ui.theme;
import ui.win;
import editor.text;
import explore.tree;
// --- title bar ---------------------------------------------------------------

fn title_bar() {
    let p = theme::pal;
    win::fill(0, 0, state::W, state::title_h, p.chrome);
    win::fill(0, state::title_h - 1, state::W, 1, p.border);
    let ic = state::px(16);
    let iy = (state::title_h - ic) / 2;
    icon_at(1, state::px(29), iy, ic, if state::menu_open { p.text } else { p.muted });
    state::add_hit(state::HIT_MENU, state::px(12), 0, state::px(34), state::title_h, 0);
    icon_at(2, state::px(64), iy, ic, p.text);
    state::add_hit(state::HIT_TOGGLE_SIDEBAR, state::px(56), state::px(8), state::px(34), state::title_h - state::px(16), 0);

    let cw = state::px(524);
    let chh = state::px(30);
    var cx = (state::W - cw) / 2 - state::px(80);
    if cx < state::px(110) { cx = state::px(110); }
    let cy = (state::title_h - chh) / 2;
    win::fill(cx, cy, cw, chh, p.border);
    win::fill(cx + 1, cy + 1, cw - 2, chh - 2, p.surface);
    var label: u8[>..] = [];
    if state::cur >= 0 && state::docs.len > 0 {
        let d = state::docs[state::cur];
        var k: i64 = 0;
        while k < d.name.len { label.push(d.name[k]); k++; }
    }
    // the search icon, the document and the folder are one centred group
    let ic2 = state::px(15);
    let name_w = if label.len > 0 { chw(state::f_small_b, label) } else { 0 };
    let fold_w = chw(state::f_small, state::root_name);
    let gap_nf = if label.len > 0 { state::px(6) } else { 0 };
    let total = ic2 + state::px(22) + name_w + gap_nf + fold_w;
    var pos = cx + (cw - total) / 2;
    icon_at(4, pos, cy + (chh - ic2) / 2, ic2, p.faint);
    pos = pos + ic2 + state::px(22);
    if label.len > 0 {
        ch(state::f_small_b, pos, cy + chh / 2, label, p.text);
        pos = pos + name_w + gap_nf;
    }
    ch(state::f_small, pos, cy + chh / 2, state::root_name, p.faint);
    state::add_hit(state::HIT_CMD, cx, cy, cw, chh, 0);

    icon_at(16, state::W - state::px(211), iy, ic, p.muted);
    state::add_hit(state::HIT_TOGGLE_TERM, state::W - state::px(219), 0, state::px(34), state::title_h, 0);
    icon_at(28, state::W - state::px(163), iy, ic, p.muted);   // minimize
    // the maximize button is the plain square the usual window frame has
    let mw = state::px(10);
    let mx = state::W - state::px(111);
    let my = state::title_h / 2 - mw / 2;
    win::line(mx, my, mx + mw, my, p.muted, 1);
    win::line(mx + mw, my, mx + mw, my + mw, p.muted, 1);
    win::line(mx + mw, my + mw, mx, my + mw, p.muted, 1);
    win::line(mx, my + mw, mx, my, p.muted, 1);
    icon_at(12, state::W - state::px(47), iy, ic, p.muted);
    state::add_hit(state::HIT_RULE, state::W - state::px(179), 0, state::px(46), state::title_h, 10);
    state::add_hit(state::HIT_RULE, state::W - state::px(121), 0, state::px(46), state::title_h, 11);
    state::add_hit(state::HIT_RULE, state::W - state::px(63), 0, state::px(63), state::title_h, 12);
}

