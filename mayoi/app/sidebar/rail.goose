// The activity rail: the four views, each of them a button.
namespace chrome;

import app.state;
import app.layout;
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
    if app::projects_on() && state::pn > 0 {
        var i: i32 = 0;
        let by0 = state::H - state::px(24) - state::pn * state::px(38);
        var by = by0;
        while i < state::pn {
            let on = i == state::pcur;
            win::round_rect(state::px(20), by, state::px(32), state::px(32), state::px(8), state::px(8),
                if on { p.accent } else { p.surface_hover });
            let name = badge(i);
            let tw = win::measure(state::f_small_b, name);
            win::text_at(state::f_small_b, state::px(20) + (state::px(32) - tw) / 2,
                by + (state::px(32) - win::th(state::f_small_b)) / 2, name,
                if on { theme::hx(255, 255, 255) } else { p.text });
            state::add_hit(state::HIT_ACTIVITY, 0, by - state::px(6), state::px(60), state::px(44), 10 + i);
            by = by + state::px(38);
            i++;
        }
    }
}

fn view_title() -> u8[>..] {
    var t: u8[>..] = [];
    if state::view == 1 { t.append(i18n::t("资源管理器")); }
    else if state::view == 2 { t.append(i18n::t("搜索")); }
    else if state::view == 3 { t.append(i18n::t("源代码管理")); }
    else { t.append(i18n::t("会话")); }
    return t;
}

fn badge(pi: i32) -> u8[>..] {
    var path = app::proj_slice(pi);
    var i: i64 = path.len;
    var start: i64 = 0;
    while i > 0 {
        if path[i-1] == '/' || path[i-1] == '\\' { start = i; break; }
        i--;
    }
    var out: u8[>..] = [];
    var j: i64 = start;
    var take: i32 = 0;
    while j < path.len && take < 2 {
        let b = path[j];
        var n: i64 = 1;
        if b >= 0xF0 { n = 4; } else if b >= 0xE0 { n = 3; } else if b >= 0xC0 { n = 2; }
        var q: i64 = 0;
        while q < n && j < path.len { out.append(path[j..j+1]); j++; q++; }
        take++;
    }
    return out;
}
