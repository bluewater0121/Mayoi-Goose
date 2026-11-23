// The tab strip and the breadcrumbs under it.
namespace chrome;

import std;
import app.state;
import ui.theme;
import ui.win;
import editor.text;
import explore.tree;
// --- tab strip ---------------------------------------------------------------

fn tab_label(d: state::Doc&) -> u8[>..] {
    var label: u8[>..] = [];
    var k: i64 = 0;
    if d.name.len == 0 {
        label.append("untitled");
    } else {
        while k < d.name.len { label.push(d.name[k]); k++; }
    }
    return label;
}

fn tabs() {
    let p = theme::pal;
    let x0 = state::right_x();
    win::fill(x0, state::title_h, state::W - x0, state::tab_h, p.chrome);
    win::fill(x0, state::title_h + state::tab_h, state::W - x0, 1, p.border);
    var x = x0;
    var i: i32 = 0;
    while i < state::docs.len as i32 {
        let d = state::docs[i];
        let label = tab_label(d);
        let tw = state::px(42) + chw(state::f_small, label) + state::px(42);
        let active = i == state::cur;
        let y = state::title_h;
        let h = state::tab_h;
        if active {
            win::fill(x, y, tw, h, p.editor);
            win::fill(x, y, tw, state::px(2), p.accent);
            win::fill(x + tw, y, 1, h, p.border);
        }
        let ic = state::px(16);
        let ty = y + (h - ic) / 2;
        icon_at(9, x + state::px(17), ty, ic, tree::color_for(d.lang));
        let tx = x + state::px(42);
        ch(state::f_ui, tx, y + h / 2, label, if active { p.text } else { p.muted });
        if d.dirty {
            win::circle(x + tw - state::px(19), y + h / 2, state::px(4), p.modified, 1);
        } else {
            icon_at(12, x + tw - state::px(26), y + (h - state::px(14)) / 2, state::px(14), p.faint);
        }
        state::add_hit(state::HIT_TAB, x, y, tw, h, i as i64);
        state::add_hit(state::HIT_TAB_CLOSE, x + tw - state::px(28), y, state::px(28), h, i as i64);
        x = x + tw + 1;
        i++;
    }
    // the right panel toggle sits at the end of the strip
    icon_at(51, state::W - state::px(34), state::title_h + (state::tab_h - state::px(16)) / 2, state::px(16), p.muted);
    state::add_hit(state::HIT_TOGGLE_PANEL, state::W - state::px(42), state::title_h, state::px(34), state::tab_h, 0);
}

// --- breadcrumbs -------------------------------------------------------------

fn crumbs() {
    let p = theme::pal;
    let x0 = state::right_x();
    let y = state::title_h + state::tab_h + 1;
    win::fill(x0, y, state::W - x0, state::crumb_h, p.editor);
    var x = x0 + state::px(18);
    if state::cur < 0 || state::docs.len == 0 { return; }
    let d = state::docs[state::cur];
    var rel: u8[>..] = [];
    var k: i64 = 0;
    if state::root.len > 0 && d.path.len > state::root.len { k = state::root.len + 1; }
    while k < d.path.len { rel.push(d.path[k]); k++; }
    var start: i64 = 0;
    k = 0;
    let cy = y + state::crumb_h / 2;
    var last: i64 = 0;
    k = 0;
    while k < rel.len {
        if rel[k] == '/' || rel[k] == '\\' { last = k; }
        k++;
    }
    k = 0;
    while k <= rel.len {
        if k == rel.len || rel[k] == '/' || rel[k] == '\\' {
            if k > start && start < last {
                let part = rel[start..k];
                ch(state::f_ui, x, cy, part, p.muted);
                x = x + chw(state::f_ui, part) + state::px(10);
                icon_at(19, x, cy - state::px(6), state::px(12), p.faint);
                x = x + state::px(18);
            }
            start = k + 1;
        }
        k++;
    }
    icon_at(9, x, cy - state::px(8), state::px(16), tree::color_for(d.lang));
    x = x + state::px(26);
    ch(state::f_ui, x, cy, d.name, p.text);
}

