// The Plugins page of the settings window: the plugins installed, each
// with its switch and its removal, the card that installs another from a
// folder, and the settings the plugins keep.
namespace prefs;

import std;
import ui.win;
import ui.theme;
import app.state;
import app.icons;
import app.plugins.model;
import .model;
import .paint;

fn letter_of(name: const u8[:], out: u8[>..]&) {
    if name.len == 0 { out.push('?'); return; }
    var c = name[0];
    if c >= 'a' && c <= 'z' { c = c - 32; }
    out.push(c);
}

fn ghost(x: i32, y: i32, label: const u8[:], hit: i32) {
    let p = theme::pal;
    let f = state::f_prefs;
    let w = win::measure(f, label) + state::px(22);
    let h = state::px(24);
    win::round_rect(x, y, w, h, state::px(4), state::px(4), p.surface);
    pfit(f, x + state::px(11), y + (h - win::th(f)) / 2, label, w - state::px(16), p.text);
    state::add_hit(hit, x, y, w, h, 0);
}

fn mini_switch(x: i32, y: i32, on: bool) {
    let p = theme::pal;
    let bw = state::px(32);
    let bh = state::px(17);
    win::round_rect(x, y, bw, bh, bh / 2, bh / 2, if on { p.accent } else { p.surface_hover });
    let d = bh - state::px(4);
    let cx = if on { x + bw - bh / 2 } else { x + bh / 2 };
    win::round_rect(cx - d / 2, y + state::px(2), d, d, d / 2, d / 2, if on { p.text } else { p.muted });
}

fn section_label(x: i32, y: i32, text: const u8[:], n: i32) {
    let p = theme::pal;
    var buf: u8[>..] = [];
    buf.append(text);
    if n > 0 {
        buf.append(" · ");
        var nn = n;
        var dig: u8[>..] = [];
        while nn > 0 { dig.push(('0' + (nn % 10) as u8)); nn = nn / 10; }
        var q = dig.len;
        while q > 0 { q--; buf.push(dig[q]); }
    }
    pf(state::f_prefs, x, y, buf[0..buf.len], p.faint);
}

fn plugin_row(i: i32, x: i32, y: i32, w: i32) {
    let p = theme::pal;
    let h = state::px(58);
    if i > 0 { win::line(x + state::px(14), y, x + w - state::px(14), y, p.border, 1); }
    let tx = x + state::px(14);
    let ty = y + state::px(13);
    win::round_rect(tx, ty, state::px(32), state::px(32), state::px(6), state::px(6), p.surface_hover);
    var one: u8[>..] = [];
    letter_of(plug::title(i), one);
    let f = state::f_prefs_b;
    win::text_at(f, tx + (state::px(32) - win::measure(f, one[0..one.len])) / 2,
        ty + (state::px(32) - win::th(f)) / 2, one[0..one.len], p.accent);
    let nx = tx + state::px(44);
    pfit(state::f_prefs_b, nx, ty, plug::title(i), w - state::px(190), p.text);
    var sub: u8[>..] = [];
    if plug::ver(i).len > 0 { sub.append("v"); sub.append(plug::ver(i)); }
    if plug::author(i).len > 0 {
        if sub.len > 0 { sub.append(" · "); }
        sub.append(plug::author(i));
    }
    pfit(state::f_prefs, nx, ty + state::px(18), sub[0..sub.len], w - state::px(190), p.muted);
    pfit(state::f_prefs, nx, ty + state::px(35), plug::desc(i), w - state::px(190), p.faint);
    let sw = state::px(32);
    let sx = x + w - sw - state::px(44);
    mini_switch(sx, y + (h - state::px(17)) / 2, plug::enabled(i));
    state::add_hit(state::HIT_PREFS_PL_TOGGLE, sx - state::px(10), y + state::px(8), sw + state::px(20), state::px(34), i);
    let dx = x + w - state::px(30);
    chrome::icon_at(21, dx, y + (h - state::px(14)) / 2, state::px(14),
        if plug::confirm == i { p.modified } else { if prefs::hover == i { p.text } else { p.faint } });
    state::add_hit(state::HIT_PREFS_PL_REMOVE, dx - state::px(14), y + state::px(10), state::px(44), state::px(38), i);
    state::add_hit(state::HIT_PREFS_PL_CARD, x, y, w - state::px(150), h, i);
}

fn install_card(x: i32, y: i32, w: i32) {
    let p = theme::pal;
    let h = state::px(92);
    win::round_rect(x, y, w, h, state::px(6), state::px(6), p.surface);
    pf(state::f_prefs_b, x + state::px(16), y + state::px(13), "安装插件", p.text);
    draw_wrap(state::f_prefs, x + state::px(16), y + state::px(34),
        "选择插件文件夹，复制到 ~/.mayoi/plugins 并立即加载：文件夹里有 plugin.json。",
        w - state::px(160), state::px(17), p.muted);
    let label: const u8[:] = "选择文件夹…";
    let f = state::f_prefs;
    let bw = win::measure(f, label) + state::px(26);
    let bh = state::px(28);
    let bx = x + w - bw - state::px(16);
    let by = y + (h - bh) / 2;
    win::round_rect(bx, by, bw, bh, state::px(5), state::px(5), p.accent);
    pf(f, bx + state::px(13), by + (bh - win::th(f)) / 2, label, p.chrome);
    state::add_hit(state::HIT_PREFS_PL_INSTALL, bx, by, bw, bh, 0);
    if plug::note.len > 0 {
        pf(state::f_prefs, x + state::px(16), y + h - state::px(22), plug::note[0..plug::note.len], p.accent);
    }
}

// plugin_detail shows one plugin in place of the list, as a row of the
// list opens it: what it is, where it lives, whether it runs, and the
// settings it declares.
fn plugin_detail(i: i32) {
    let p = theme::pal;
    let x = prefs::card_x;
    let w = prefs::card_w;
    var y = prefs::rows_y - prefs::scroll;
    let top = prefs::rows_y;

    ghost(x, y, "‹ 插件", state::HIT_PREFS_PL_BACK);
    y = y + state::px(40);

    pf(state::f_prefs_b, x, y, plug::title(i), p.text);
    y = y + state::px(26);

    var sub: u8[>..] = [];
    if plug::ver(i).len > 0 { sub.append("v"); sub.append(plug::ver(i)); }
    if plug::author(i).len > 0 {
        if sub.len > 0 { sub.append(" · "); }
        sub.append(plug::author(i));
    }
    pf(state::f_prefs, x, y, sub[0..sub.len], p.muted);
    y = y + state::px(26);

    win::round_rect(x, y, w, state::px(96), state::px(6), state::px(6), p.surface);
    pf(state::f_prefs, x + state::px(16), y + state::px(12),
        if plug::enabled(i) { "已启用" } else { "已停用" },
        if plug::enabled(i) { p.text } else { p.muted });
    let sw = state::px(32);
    let sx = x + w - sw - state::px(24);
    mini_switch(sx, y + state::px(10), plug::enabled(i));
    state::add_hit(state::HIT_PREFS_PL_TOGGLE, sx - state::px(10), y + state::px(6),
        sw + state::px(20), state::px(34), i);
    let label2: const u8[:] = if plug::confirm == i { "再次点击删除" } else { "删除插件" };
    ghost(x + w - win::measure(state::f_prefs, label2) - state::px(22) - state::px(60), y + state::px(52),
        label2, state::HIT_PREFS_PL_REMOVE);
    pfit(state::f_prefs, x + state::px(16), y + state::px(40), plug::dir_of(i), w - state::px(28), p.faint);
    y = y + state::px(96) + state::px(22);

    section_label(x, y, "说明", 0);
    y = y + state::px(24);
    draw_wrap(state::f_prefs, x, y, plug::desc(i), w - state::px(24), state::px(19), p.muted);
    y = y + state::px(60) + state::px(18);

    section_label(x, y, "插件设置", 0);
    y = y + state::px(26);
    pf(state::f_prefs, x, y, "该插件的清单没有声明设置项。", p.faint);

    let content = y + prefs::scroll - top + state::px(20);
    prefs::total_rows = content;
    let view = prefs::rows_b - top;
    prefs::shown_rows = view;
    prefs::max_scroll = content - view;
    if prefs::max_scroll < 0 { prefs::max_scroll = 0; }
}

fn plugins_body() {
    if prefs::detail >= 0 { plugin_detail(prefs::detail); return; }
    let p = theme::pal;
    let x = prefs::card_x;
    let w = prefs::card_w;
    var y = prefs::rows_y - prefs::scroll;
    let top = prefs::rows_y;

    // actions of the page, right above the list
    var reload_label: const u8[:] = "重新加载";
    var folder_label: const u8[:] = "打开插件文件夹";
    let f = state::f_prefs;
    let fw = win::measure(f, folder_label) + state::px(22);
    let rw = win::measure(f, reload_label) + state::px(22);
    ghost(x + w - fw - rw - state::px(8), top, reload_label, state::HIT_PREFS_PL_RELOAD);
    ghost(x + w - fw, top, folder_label, state::HIT_PREFS_PL_FOLDER);
    section_label(x, top + state::px(6), "已安装", plug::count());
    y = top + state::px(34);

    let n = plug::count();
    var list_h = state::px(58) * n;
    if n == 0 { list_h = state::px(96); }
    win::round_rect(x, y, w, list_h, state::px(6), state::px(6), p.surface);
    if n == 0 {
        chrome::icon_at(66, x + w / 2 - state::px(13), y + state::px(22), state::px(26), p.faint);
        let msg: const u8[:] = "尚未安装插件";
        pf(state::f_prefs, x + (w - win::measure(state::f_prefs, msg)) / 2, y + state::px(58), msg, p.muted);
    }
    var i: i32 = 0;
    while i < n {
        plugin_row(i, x, y + state::px(58) * i, w);
        i++;
    }
    y = y + list_h + state::px(18);

    install_card(x, y, w);
    y = y + state::px(92) + state::px(22);

    section_label(x, y, "插件设置", 0);
    y = y + state::px(24);

    // the settings the plugins keep, without "plugins" itself, whose
    // switches are on the rows above
    var j: i32 = 0;
    while j < prefs::flds.len as i32 {
        if prefs::flds[j].sec == 8 && !prefs::same(prefs::flds[j].key[0..prefs::flds[j].key.len], "plugins") {
            y = y + field_row(j, y);
        }
        j++;
    }

    let content = y + prefs::scroll - top + state::px(20);
    let view = prefs::rows_b - top;
    prefs::total_rows = content;
    prefs::shown_rows = view;
    prefs::max_scroll = content - view;
    if prefs::max_scroll < 0 { prefs::max_scroll = 0; }
    if prefs::scroll > prefs::max_scroll { prefs::scroll = prefs::max_scroll; }
    if prefs::scroll < 0 { prefs::scroll = 0; }
}

