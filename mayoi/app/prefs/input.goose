// What the settings window answers to: its sections, its search, its
// fields and its choices.
namespace prefs;

import std;
import os;
import ui.win;
import ui.theme;
import app.state;
import app.layout;
import app.input.vk;
import app.plugins.model;
import .model;
import .paint;
import .store;

fn clamp_scroll() {
    var maxs = prefs::total_rows - prefs::shown_rows;
    if maxs < 0 { maxs = 0; }
    if prefs::scroll > maxs { prefs::scroll = maxs; }
    if prefs::scroll < 0 { prefs::scroll = 0; }
}

fn commit_edit() {
    if prefs::edit >= 0 {
        if prefs::flds[prefs::edit].kind == prefs::K_NUM {
            prefs::set_num(prefs::edit, prefs::parse_num(prefs::edit_buf[0..prefs::edit_buf.len]));
        } else {
            prefs::set(prefs::edit, prefs::edit_buf[0..prefs::edit_buf.len]);
        }
        prefs::edit = -1;
        prefs::store_save();
        app::apply_settings();
    }
}

fn pick_and_install() {
    var buf: u8[>..] = [];
    buf.resize(4096);
    let n = win::pick_folder(win::hwnd, buf[0], 4096);
    if n > 0 {
        buf.resize(n);
        plug::install(buf[0..buf.len]);
    }
}

fn click(x: i32, y: i32) {
    let hi = state::find_hit(x, y);
    if hi < 0 {
        commit_edit();
        prefs::store_save();
        prefs::close();
        return;
    }
    let h = state::hits[hi as i64];
    if prefs::edit >= 0 && !(h.kind == state::HIT_PREFS_TEXT && h.arg as i32 == prefs::edit) {
        commit_edit();
    }
    if prefs::combo >= 0 && h.kind != state::HIT_PREFS_OPT {
        prefs::combo = -1;
        if h.kind != state::HIT_PREFS_ENUM && h.kind != state::HIT_PREFS_TOGGLE
            && h.kind != state::HIT_PREFS_TEXT && h.kind != state::HIT_PREFS_STEP
            && h.kind != state::HIT_PREFS_RESET {
            return;
        }
    }
    let k = h.kind;
    if k == state::HIT_PREFS_CLOSE {
        prefs::store_save();
        prefs::close();
        return;
    }
    if k == state::HIT_PREFS_SCOPE {
        if prefs::scope == 0 {
            if state::root.len == 0 {
                app::set_status("文件夹设置需要先打开一个文件夹");
                return;
            }
            var dir: u8[>..] = [];
            dir.append(state::root);
            dir.append("/.mayoi");
            make_dir(dir[0..dir.len]);
            prefs::scope = 1;
        } else { prefs::scope = 0; }
        win::invalidate();
        return;
    }
    if k == state::HIT_PREFS_NAV {
        prefs::section = h.arg as i32;
        prefs::query.resize(0);
        prefs::scroll = 0;
        prefs::edit = -1;
        prefs::combo = -1;
        prefs::detail = -1;
        return;
    }
    if k == state::HIT_PREFS_SEARCH {
        prefs::edit = -2;
        return;
    }
    if k == state::HIT_PREFS_TOGGLE {
        prefs::toggle(h.arg as i32);
        app::apply_settings();
        return;
    }
    if k == state::HIT_PREFS_STEP {
        let i = (h.arg / 4) as i32;
        let dir: i32 = if h.arg % 4 == 1 { 1 } else { -1 };
        prefs::step_num(i, dir);
        app::apply_settings();
        return;
    }
    if k == state::HIT_PREFS_ENUM {
        let i = h.arg as i32;
        if prefs::combo == i { prefs::combo = -1; } else { prefs::combo = i; }
        return;
    }
    if k == state::HIT_PREFS_OPT {
        let opt = (h.arg % 1000) as i32;
        if prefs::combo >= 0 {
            prefs::set(prefs::combo, prefs::opt_raw(prefs::combo, opt));
            app::apply_settings();
        }
        prefs::combo = -1;
        return;
    }
    if k == state::HIT_PREFS_TEXT {
        let i = h.arg as i32;
        if prefs::edit != i {
            prefs::edit = i;
            prefs::edit_buf.resize(0);
            if prefs::flds[i].kind == prefs::K_NUM {
                let t = prefs::num_text(i);
                var j: i64 = 0;
                while j < t.len { prefs::edit_buf.push(t[j]); j++; }
            } else {
                let v = prefs::value(i);
                var j: i64 = 0;
                while j < v.len { prefs::edit_buf.push(v[j]); j++; }
            }
        }
        return;
    }
    if k == state::HIT_PREFS_RESET {
        prefs::reset(h.arg as i32);
        app::apply_settings();
        return;
    }
    if k == state::HIT_PREFS_PL_RELOAD {
        plug::reload();
        return;
    }
    if k == state::HIT_PREFS_PL_FOLDER {
        plug::open_folder();
        return;
    }
    if k == state::HIT_PREFS_PL_TOGGLE {
        plug::toggle(h.arg as i32);
        return;
    }
    if k == state::HIT_PREFS_PL_REMOVE {
        plug::remove(h.arg as i32);
        return;
    }
    if k == state::HIT_PREFS_PL_INSTALL {
        prefs::pick_and_install();
        return;
    }
    if k == state::HIT_PREFS_PL_CARD {
        prefs::detail = h.arg as i32;
        prefs::scroll = 0;
        return;
    }
    if k == state::HIT_PREFS_PL_BACK {
        prefs::detail = -1;
        prefs::scroll = 0;
        return;
    }
}

fn key(vk: i32, ctrl: bool, shift: bool, alt: bool) -> bool {
    if vk == input::VK_ESC {
        if prefs::combo >= 0 { prefs::combo = -1; return true; }
        if prefs::edit != -1 { prefs::edit = -1; return true; }
        if prefs::detail >= 0 { prefs::detail = -1; prefs::scroll = 0; return true; }
        prefs::store_save();
        prefs::close();
        return true;
    }
    if vk == input::VK_RET {
        commit_edit();
        return true;
    }
    if vk == input::VK_BACK {
        if prefs::edit == -2 {
            if prefs::query.len > 0 { text::trim_utf8(&prefs::query); prefs::scroll = 0; }
        } else if prefs::edit >= 0 {
            if prefs::edit_buf.len > 0 { text::trim_utf8(&prefs::edit_buf); }
        }
        return true;
    }
    if vk == input::VK_UP {
        prefs::scroll = prefs::scroll - 1;
        clamp_scroll();
        return true;
    }
    if vk == input::VK_DOWN {
        prefs::scroll = prefs::scroll + 1;
        clamp_scroll();
        return true;
    }
    if vk == input::VK_PGUP {
        prefs::scroll = prefs::scroll - prefs::shown_rows;
        clamp_scroll();
        return true;
    }
    if vk == input::VK_PGDN {
        prefs::scroll = prefs::scroll + prefs::shown_rows;
        clamp_scroll();
        return true;
    }
    if ctrl && vk == 70 {
        // Ctrl+F goes to the search, as the window of the reference does
        prefs::edit = -2;
        return true;
    }
    return true;
}

fn typed(cp: u16) {
    if cp < 32 { return; }
    if prefs::edit == -2 {
        prefs::query.push(cp as u8);
        prefs::scroll = 0;
        return;
    }
    if prefs::edit >= 0 {
        if prefs::flds[prefs::edit].kind == prefs::K_NUM {
            if (cp >= '0' && cp <= '9') || cp == '.' || cp == '-' { prefs::edit_buf.push(cp as u8); }
            return;
        }
        if prefs::edit_buf.len < 360 { prefs::edit_buf.push(cp as u8); }
    }
}

fn wheel(ticks: i32) {
    if prefs::edit == -2 { return; }
    if prefs::section == 8 && prefs::query.len == 0 {
        prefs::scroll = prefs::scroll - ticks * state::px(40);
        if prefs::scroll < 0 { prefs::scroll = 0; }
        if prefs::scroll > prefs::max_scroll { prefs::scroll = prefs::max_scroll; }
        return;
    }
    prefs::scroll = prefs::scroll - ticks * 3;
    clamp_scroll();
}

fn hover_at(x: i32, y: i32) {
    let hi = state::find_hit(x, y);
    if hi < 0 { return; }
    let h = state::hits[hi as i64];
    if h.kind == state::HIT_PREFS_TOGGLE || h.kind == state::HIT_PREFS_ENUM
        || h.kind == state::HIT_PREFS_TEXT || h.kind == state::HIT_PREFS_RESET
        || h.kind == state::HIT_PREFS_STEP {
        let i = if h.kind == state::HIT_PREFS_STEP { (h.arg / 4) as i32 } else { h.arg as i32 };
        if prefs::hover != i { prefs::hover = i; win::invalidate(); }
        return;
    }
    if prefs::hover != -1 { prefs::hover = -1; win::invalidate(); }
}

