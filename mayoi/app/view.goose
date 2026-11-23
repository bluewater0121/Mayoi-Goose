// The frame's paint: the chrome, the editor, and the panel at its foot.
namespace app;
import std;
import os;
import i18n;
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
import app.menu.paint;
import app.ctxmenu;
import app.prefs.paint;
import app.preview.preview;// --- frame -------------------------------------------------------------------

fn paint() {
    state::hits.resize(0);
    state::W = win::frame_w + win::ox;
    state::H = win::frame_h;
    let p = theme::pal;
    win::fill(0, 0, state::W, state::H, p.chrome);
    chrome::title_bar();
    if state::sidebar_open { chrome::sidebar(); }
    let x0 = state::right_x();
    let y0 = state::title_h;
    if state::docs.len > 0 && state::cur >= 0 { chrome::tabs(); chrome::crumbs(); }
    let top = if state::docs.len > 0 && state::cur >= 0 { state::top_y() } else { state::title_h };
    var bottom = state::H - state::status_h;
    if state::panel_open { bottom = bottom - state::panel_h; }
    if bottom < top + state::px(40) { bottom = top + state::px(40); }
    if state::docs.len == 0 || state::cur < 0 {
        win::fill(x0, state::title_h, state::W - x0, bottom - state::title_h, p.editor);
        editor::paint(x0, state::title_h, state::W - x0, bottom - state::title_h);
    } else if state::preview_open && state::preview_side {
        let pw = (state::W - x0) * 46 / 100;
        editor::paint(x0, top, state::W - x0 - pw - 1, bottom - top);
        win::fill(state::W - pw - 1, top, 1, bottom - top, p.border);
        preview::paint(state::W - pw, top, pw, bottom - top);
    } else if state::preview_open {
        preview::paint(x0, top, state::W - x0, bottom - top);
    } else {
        editor::paint(x0, top, state::W - x0, bottom - top);
    }
    if state::panel_open { paint_panel(x0, bottom, state::W - x0, state::panel_h); }
    if state::sidebar_open {
        win::fill(state::sidebar_w - 1, state::title_h, 1, state::H - state::title_h, p.border);
        state::add_hit(state::HIT_SPLITTER, state::sidebar_w - state::px(3), state::title_h, state::px(6), state::H - state::title_h - state::status_h, 1);
    }
    if state::panel_open {
        state::add_hit(state::HIT_SPLITTER, x0, bottom - state::px(3), state::W - x0, state::px(6), 2);
    }
    chrome::status_bar();
    if state::overlay != 0 { paint_overlay(); }
    menu::paint();
    chrome::ctx_paint();
    prefs::paint();
}

fn term_run() {
    var echo: u8[>..] = [];
    echo.append("PS> ");
    echo.append(term_input);
    echo.push('\n');
    term.append(echo);
    let cmd = copy(term_input);
    term_input.resize(0);
    if cmd.len == 0 { win::invalidate(); return; }
    var line: u8[>..] = [];
    line.append("cmd /c ");
    line.append(cmd);
    var buf: u8[>..] = [];
    buf.resize(65536, 0);
    var cwd: u8[>..] = [];
    if term_cwd.len > 0 { cwd.append(term_cwd); }
    else if state::root.len > 0 { cwd.append(state::root); } else { cwd.append("."); }
    let n = win::gs_run_cmd(line[0], line.len as i64, buf[0], 65536, cwd[0], cwd.len as i64);
    var j: i64 = 0;
    while j < n && j < 65000 {
        if buf[j] != 0 { term.push(buf[j]); }
        j++;
    }
    term.push('\n');
    win::invalidate();
}

fn paint_panel(x0: i32, y0: i32, w: i32, h: i32) {
    let p = theme::pal;
    win::fill(x0, y0, w, h, p.panel);
    win::fill(x0, y0, w, 1, p.border);
    win::fill(x0, y0 + state::panel_head - 1, w, 1, p.border);
    var tabs: u8[>..] = [];
    tabs.append("问题\0输出\0终端\0调试");
    var x = x0 + state::px(16);
    var labels: u8[>..] = [];
    labels.append(i18n::t("问题")); labels.push('\n');
    labels.append(i18n::t("输出")); labels.push('\n');
    labels.append(i18n::t("终端")); labels.push('\n');
    labels.append(i18n::t("调试"));
    var i: i32 = 0;
    var start: i64 = 0;
    var k: i64 = 0;
    while k <= labels.len {
        if k == labels.len || labels[k] == '\n' {
            if k > start {
                let label = labels[start..k];
                let tw = win::measure(state::f_ui, label) + state::px(24);
                let active = i == state::panel_tab;
                if active {
                    win::fill(x, y0 + state::px(6), tw, state::panel_head - state::px(6), p.panel);
                    win::fill(x, y0 + state::px(6), tw, state::px(2), p.accent);
                }
                win::text_at(state::f_ui, x + state::px(12), y0 + (state::panel_head - win::th(state::f_ui)) / 2, label,
                             if active { p.text } else { p.muted });
                state::add_hit(state::HIT_PANEL_TAB, x, y0, tw, state::panel_head, i as i64);
                x = x + tw;
            }
            start = k + 1;
            i++;
        }
        k++;
    }
    // actions at the right of the header
    var rx = x0 + w - state::px(28);
    let ic = state::px(14);
    chrome::icon_at(12, rx, y0 + (state::panel_head - ic) / 2, ic, p.muted);
    state::add_hit(state::HIT_CLOSE_PANEL, rx - state::px(4), y0, state::px(24), state::panel_head, 0);
    rx = rx - state::px(30);
    chrome::icon_at(22, rx, y0 + (state::panel_head - ic) / 2, ic, p.muted);
    rx = rx - state::px(30);
    chrome::icon_at(21, rx, y0 + (state::panel_head - ic) / 2, ic, p.muted);
    rx = rx - state::px(30);
    chrome::icon_at(13, rx, y0 + (state::panel_head - ic) / 2, ic, p.muted);

    // body follows the active tab: problems, output, terminal, debug
    var ty = y0 + state::panel_head + state::px(10);
    if state::panel_tab != 2 {
        if state::panel_tab == 1 {
            var oy = ty;
            var i3: i64 = 0;
            var s3: i64 = 0;
            while i3 <= output.len && oy < y0 + h - state::px(6) {
                if i3 == output.len || output[i3] == '\n' {
                    if i3 > s3 { win::text_at(state::f_code_small, x0 + state::px(16), oy, output[s3..i3], p.text); }
                    oy = oy + state::px(18);
                    s3 = i3 + 1;
                }
                i3++;
            }
            state::add_hit(state::HIT_CARET, x0, y0 + state::panel_head, w, h - state::panel_head, 1);
            return;
        }
        var text: u8[>..] = [];
        if state::panel_tab == 0 { text.append(i18n::t("未发现问题。")); }
        else { text.append(i18n::t("调试会话尚未启动，按 F5 开始调试。")); }
        win::text_at(state::f_ui, x0 + state::px(16), ty, text, p.muted);
        state::add_hit(state::HIT_CARET, x0, y0 + state::panel_head, w, h - state::panel_head, 1);
        return;
    }
    var line = 0;
    var i2: i64 = 0;
    var start2: i64 = 0;
    while i2 <= term.len && ty < y0 + h - state::px(6) {
        if i2 == term.len || term[i2] == '\n' {
            if i2 > start2 {
                win::text_at(state::f_code_small, x0 + state::px(16), ty, term[start2..i2], p.text);
                ty = ty + state::px(18);
            }
            start2 = i2 + 1;
            line++;
        }
        i2++;
    }
    // prompt
    var prompt: u8[>..] = [];
    prompt.append("PS ");
    if term_cwd.len > 0 { prompt.append(term_cwd); }
    else if state::root.len > 0 { prompt.append(state::root); }
    else { prompt.append("C:\\work"); }
    prompt.append("> ");
    win::text_at(state::f_code_small, x0 + state::px(16), ty, prompt, p.accent);
    let pw = win::measure(state::f_code_small, prompt);
    win::text_at(state::f_code_small, x0 + state::px(16) + pw, ty, term_input, p.text);
    state::add_hit(state::HIT_CARET, x0, y0 + state::panel_head, w, h - state::panel_head, 1);
}


