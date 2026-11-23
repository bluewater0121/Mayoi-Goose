// The explorer body: the folder's tree under the project row.
namespace chrome;

import app.state;
import ui.theme;
import ui.win;
import explore.tree;

fn explorer_body(top: i32) {
    let p = theme::pal;
    let w = state::sidebar_w;
    let rh = state::row_h;
    let ic = state::px(16);
    let avail = state::H - state::status_h - top;
    var cap = avail / rh;
    if cap < 0 { cap = 0; }
    state::tree_vis = cap;
    tree::clamp_off();
    // the space under the rows belongs to no file
    state::add_hit(state::HIT_TREEROW, 0, top, w, avail, -1);
    let n = tree::rows.len as i32;
    var k: i32 = 0;
    var i: i32 = state::tree_off;
    while i < n && k < cap {
        let r = tree::rows[i];
        let y = top + k * rh;
        state::add_hit(state::HIT_TREEROW, 0, y, w, rh, i as i64);
        if i == tree::focus_row && state::focus == 1 {
            win::fill(state::px(4), y + 1, w - state::px(10), rh - 2, p.active);
        }
        // the guides of the folders above this row
        var g: i32 = 0;
        while g < r.depth {
            let gx = state::px(25) + state::px(13) * g;
            win::fill(gx, y, 1, rh, p.guide);
            g++;
        }
        let ind = state::px(13) * r.depth + state::px(39);
        if r.dir {
            state::add_hit(state::HIT_CHEVRON, ind - state::px(17), y, state::px(17), rh, i as i64);
            icon_at(if r.open { 8 } else { 7 }, ind - state::px(17), y + (rh - state::px(12)) / 2,
                state::px(12), p.muted);
            icon_at(if r.open { 11 } else { 10 }, ind, y + (rh - ic) / 2, ic, p.accent);
        } else {
            icon_at(9, ind, y + (rh - ic) / 2, ic, tree::color_for(r.lang));
        }
        let tx = ind + state::px(26);
        if state::ren_active && tree::eqs(r.path, state::ren_path) {
            let bw = w - tx - state::px(10);
            win::fill(tx - state::px(3), y + state::px(4), bw, rh - state::px(8), p.surface);
            win::line(tx - state::px(3), y + state::px(4), tx - state::px(3) + bw - 1, y + state::px(4), p.accent, 1);
            win::line(tx - state::px(3), y + rh - state::px(5), tx - state::px(3) + bw - 1, y + rh - state::px(5), p.accent, 1);
            ch(state::f_tree, tx, y + rh / 2, state::ren_buf, p.text);
            if state::blink {
                let qw = win::measure(state::f_tree, state::ren_buf);
                win::fill(tx + qw + 1, y + state::px(7), 1, rh - state::px(14), p.text);
            }
        } else {
            ch(state::f_tree, tx, y + rh / 2, r.name, p.text);
        }
        i++;
        k++;
    }
    // the scrollbar, only when there is more than fits
    if n > cap && cap > 0 {
        let sbw = state::px(6);
        let sx = w - state::px(12);
        let track = avail;
        var thumb = track * cap / n;
        if thumb < state::px(36) { thumb = state::px(36); }
        var ty = top;
        if n > cap { ty = top + (track - thumb) * state::tree_off / (n - cap); }
        state::tree_ttop = top;
        state::tree_track = track;
        state::tree_thumb = thumb;
        win::fill(sx, top, sbw, track, win::mix(p.chrome, p.border, 140));
        win::round_rect(sx, ty, sbw, thumb, state::px(3), state::px(3),
            win::mix(p.scrollbar, p.text, 120));
        state::add_hit(state::HIT_TREE_SCROLL, sx - state::px(4), top, sbw + state::px(8), track, 0);
    }
}
