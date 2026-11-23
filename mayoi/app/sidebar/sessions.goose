// The sessions view: the documents this window has open, newest first.
namespace chrome;

import app.state;
import i18n;
import ui.theme;
import ui.win;

fn sessions_body(top: i32) {
    let p = theme::pal;
    let w = state::sidebar_w;
    let ry = top + state::px(10);
    let rh = state::px(30);
    if state::docs.len == 0 {
        win::text_at(state::f_small, state::px(16), ry + state::px(4), i18n::t("尚无会话"), p.faint);
        return;
    }
    var i: i32 = 0;
    var cap = (state::H - state::status_h - ry) / rh;
    while i < state::docs.len as i32 && i < cap {
        let d = state::docs[i];
        let y = ry + i * rh;
        state::add_hit(state::HIT_TREEROW, 0, y, w - 1, rh, -1 - i as i64);
        if i == state::cur { win::fill(0, y, w - 1, rh, p.hover); }
        icon_at(9, state::px(16), y + (rh - state::px(16)) / 2, state::px(16), p.muted);
        var name: u8[>..] = [];
        var k: i64 = 0;
        while k < d.name.len { name.push(d.name[k]); k++; }
        win::text_at(state::f_ui, state::px(42), y + (rh - win::th(state::f_ui)) / 2, name,
            if d.dirty { p.modified } else { p.text });
        i++;
    }
}
