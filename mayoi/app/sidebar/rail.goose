// The activity rail: the four views, each of them a button.
namespace chrome;

import app.state;
import i18n;
import ui.theme;
import ui.win;

fn rail() {
    let p = theme::pal;
    let row1 = state::title_h;
    let ic = state::px(16);
    let iy = row1 + state::px(21) - ic / 2;
    // files, search, source control, sessions
    if state::view == 1 { win::round_rect(state::px(20), row1 + state::px(5), state::px(32), state::px(32), state::px(8), state::px(8), p.active); }
    icon_at(3, state::px(28), iy, ic, if state::view == 1 { p.accent } else { p.muted });
    if state::view == 2 { win::round_rect(state::px(56), row1 + state::px(5), state::px(32), state::px(32), state::px(8), state::px(8), p.active); }
    icon_at(4, state::px(64), iy, ic, if state::view == 2 { p.accent } else { p.muted });
    if state::view == 3 { win::round_rect(state::px(88), row1 + state::px(5), state::px(32), state::px(32), state::px(8), state::px(8), p.active); }
    icon_at(5, state::px(95), iy - state::px(2), ic, if state::view == 3 { p.accent } else { p.muted });
    if state::view == 4 { win::round_rect(state::px(120), row1 + state::px(5), state::px(32), state::px(32), state::px(8), state::px(8), p.active); }
    icon_at(6, state::px(127), iy, ic, if state::view == 4 { p.accent } else { p.muted });
    state::add_hit(state::HIT_ACTIVITY, state::px(20), row1 + state::px(5), state::px(32), state::px(32), 1);
    state::add_hit(state::HIT_ACTIVITY, state::px(56), row1 + state::px(5), state::px(32), state::px(32), 2);
    state::add_hit(state::HIT_ACTIVITY, state::px(88), row1 + state::px(5), state::px(32), state::px(32), 3);
    state::add_hit(state::HIT_ACTIVITY, state::px(120), row1 + state::px(5), state::px(32), state::px(32), 4);
}

fn view_title() -> u8[>..] {
    var t: u8[>..] = [];
    if state::view == 1 { t.append(i18n::t("资源管理器")); }
    else if state::view == 2 { t.append(i18n::t("搜索")); }
    else if state::view == 3 { t.append(i18n::t("源代码管理")); }
    else { t.append(i18n::t("会话")); }
    return t;
}
