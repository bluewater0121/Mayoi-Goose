// The source control panel: the no-repo state, the branch row, the commit
// box and the list of changes. The git plumbing lives in scm.goose.
namespace chrome;

import std;
import app.state;
import i18n;
import ui.theme;
import ui.win;
import app.icons;
import app.layout;

fn scm_body(top: i32) {
    let p = theme::pal;
    let w = state::sidebar_w;
    if !state::scm_loaded {
        reload_scm();
        state::scm_loaded = true;
    }
    if !scm_repo {
        // the empty state: why, and the button that makes a work tree
        let cx = w / 2;
        let by = top + state::px(46);
        win::fill(cx - state::px(24), by, state::px(48), state::px(48), p.chrome);
        win::circle(cx, by + state::px(22), state::px(22), p.border, 1);
        icon_at(5, cx - state::px(10), by + state::px(12), state::px(20), p.muted);
        ch(state::f_small_b, cx - win::measure(state::f_small_b, i18n::t("没有 Git 仓库")) / 2, by + state::px(58), i18n::t("没有 Git 仓库"), p.text);
        let d1 = i18n::t("此文件夹不在 Git 仓库中。");
        let d2 = i18n::t("将其初始化为仓库以跟踪并提交更改。");
        let dy = by + state::px(78);
        ch(state::f_small, cx - win::measure(state::f_small, d1) / 2, dy, d1, p.muted);
        ch(state::f_small, cx - win::measure(state::f_small, d2) / 2, dy + state::px(18), d2, p.muted);
        let btnw = w - state::px(40);
        let btnx = state::px(20);
        let btny = dy + state::px(44);
        win::round_rect(btnx, btny, btnw, state::px(28), state::px(5), state::px(5), p.accent);
        ch(state::f_small_b, btnx + (btnw - win::measure(state::f_small_b, i18n::t("初始化仓库"))) / 2, btny + state::px(14), i18n::t("初始化仓库"), theme::hx(255, 255, 255));
        state::add_hit(state::HIT_SCM_INIT, btnx, btny, btnw, state::px(28), 0);
        return;
    }
    // the branch, over the box that writes the commit
    var by = top + state::px(10);
    icon_at(5, state::px(14), by, state::px(14), p.accent);
    var label: u8[>..] = [];
    if scm_branch.len > 0 { label.append(scm_branch); } else { label.append("HEAD"); }
    ch(state::f_small, state::px(34), by + state::px(7), label, p.text);
    // the "..." at the branch row opens the git actions, as the reference does
    let mx = w - state::px(30);
    let my = by - state::px(1);
    win::round_rect(mx, my, state::px(20), state::px(20), state::px(4), state::px(4), p.chrome);
    icon_at(15, mx + state::px(3), my + state::px(3), state::px(14), p.muted);
    state::add_hit(state::HIT_SCM_MORE, mx - state::px(4), my - state::px(3), state::px(28), state::px(26), 0);
    if scm_err {
        ch(state::f_small, w - state::px(14) - win::measure(state::f_small, i18n::t("未找到 Git")), by + state::px(7), i18n::t("未找到 Git"), p.faint);
    }
    let bx = state::px(12);
    let bw = w - state::px(24);
    let by2 = by + state::px(24);
    let bh = state::px(28);
    win::fill(bx, by2, bw, bh, p.surface);
    win::line(bx, by2, bx + bw - 1, by2, p.border, 1);
    win::line(bx, by2 + bh - 1, bx + bw - 1, by2 + bh - 1, p.border, 1);
    win::line(bx, by2, bx, by2 + bh - 1, p.border, 1);
    win::line(bx + bw - 1, by2, bx + bw - 1, by2 + bh - 1, p.border, 1);
    state::add_hit(state::HIT_SCM_COMMIT, bx, by2, bw, bh, 1);
    let ty = by2 + (bh - win::th(state::f_small)) / 2;
    if state::scm_msg.len == 0 {
        win::text_at(state::f_small, bx + state::px(8), ty, i18n::t("提交消息"), p.faint);
    } else {
        win::text_at(state::f_small, bx + state::px(8), ty, state::scm_msg, p.text);
        if state::scm_focus == 1 && state::blink {
            let mw = win::measure(state::f_small, state::scm_msg);
            win::fill(bx + state::px(8) + mw + 1, by2 + state::px(5), 1, bh - state::px(10), p.text);
            state::ime_x = bx + state::px(8) + mw;
            state::ime_y = by2 + bh;
            if state::ime_comp.len > 0 {
                win::text_at(state::f_small, bx + state::px(8) + mw, ty, state::ime_comp, p.accent);
            }
        }
    }
    let btny = by2 + bh + state::px(8);
    let bwid = w - state::px(24);
    win::round_rect(bx, btny, bwid, state::px(26), state::px(5), state::px(5), p.surface_hover);
    ch(state::f_small_b, bx + (bwid - win::measure(state::f_small_b, "提交")) / 2, btny + state::px(13), "提交",
        if state::scm_msg.len > 0 { p.text } else { p.faint });
    if state::scm_msg.len > 0 { state::add_hit(state::HIT_SCM_COMMIT, bx, btny, bwid, state::px(26), 2); }
    // the changed files
    var cy = btny + state::px(34);
    var head: u8[>..] = [];
    head.append("更改 ");
    var num: u8[>..] = [];
    var d = scm_n;
    if d == 0 { num.push('0'); } else { num.push('0' + (d % 10) as u8); }
    var q: i64 = num.len;
    while q > 0 { q--; head.push(num[q]); }
    ch(state::f_small_b, state::px(14), cy + state::px(7), head, p.text);
    cy = cy + state::px(22);
    if scm_err {
        ch(state::f_small, state::px(14), cy + state::px(8), i18n::t("未找到 Git，无法读取状态"), p.faint);
        return;
    }
    if scm_n == 0 {
        ch(state::f_small, state::px(14), cy + state::px(8), i18n::t("没有更改"), p.muted);
        return;
    }
    let rh = state::px(22);
    var cap = (state::H - state::status_h - cy) / rh;
    var i: i32 = 0;
    var k2: i64 = 0;
    var start: i64 = 0;
    while k2 <= scm_rows.len && i < cap {
        if k2 == scm_rows.len || scm_rows[k2] == '\n' {
            if k2 > start {
                let line = scm_rows[start..k2];
                let y = cy + i * rh;
                let st = line[0..2];
                let name = line[3..line.len];
                var col = p.muted;
                if st[0] == 'M' || st[1] == 'M' { col = p.modified; }
                if st[0] == 'A' || st[1] == 'A' || st[0] == '?' { col = p.added; }
                if st[0] == 'D' || st[1] == 'D' { col = p.removed; }
                var sep = name.len;
                var c: i64 = name.len;
                while c > 0 {
                    c--;
                    if name[c] == '/' || name[c] == '\\' { sep = c + 1; break; }
                }
                var base = name;
                if sep < name.len { base = name[sep..]; }
                win::text_at(state::f_small, state::px(14), y + (rh - win::th(state::f_small)) / 2, base, p.text);
                win::text_at(state::f_small, w - state::px(14) - win::measure(state::f_small, st),
                    y + (rh - win::th(state::f_small)) / 2, st, col);
                state::add_hit(state::HIT_SCM_ROW, 0, y, w - 1, rh, i as i64);
                i++;
            }
            start = k2 + 1;
        }
        k2++;
    }
}

