// The overlay: the command palette and the quick open box.
namespace app;
import std;
import os;
import app.state;
import i18n;
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
import editor.editor;// --- overlay -----------------------------------------------------------------

var commands: u8[>..] = [];
var items: u8[>..] = [];       // newline separated results
var item_count: i32 = 0;

fn paint_overlay() {
    let p = theme::pal;
    let w = state::px(600);
    var x = (state::W - w) / 2;
    var y = state::px(90);
    if state::overlay == 3 {
        // find widget, at the top right of the editor
        x = state::W - w - state::px(40);
        y = state::top_y() + state::px(8);
    }
    let h = state::px(44);
    win::fill(x + state::px(4), y + state::px(4), w, h, p.shadow);
    win::fill(x, y, w, h, p.surface);
    win::fill(x, y, w, 1, p.surface_hover);
    win::fill(x, y + h - 1, w, 1, p.border);
    chrome::icon_at(4, x + state::px(12), y + (h - state::px(16)) / 2, state::px(16), p.faint);
    win::text_at(state::f_ui, x + state::px(36), y + (h - win::th(state::f_ui)) / 2, state::query, p.text);
    if state::blink {
        let qw = win::measure(state::f_ui, state::query);
        win::fill(x + state::px(36) + qw + state::px(1), y + state::px(12), state::px(2), h - state::px(24), p.text);
    }
    state::add_hit(state::HIT_OVERLAY, x, y, w, h, 0);
    if state::overlay == 3 { return; }
    // results list
    var ly = y + h + state::px(4);
    var rows = item_count;
    if rows > 10 { rows = 10; }
    if rows == 0 { return; }
    let lh = state::px(30);
    win::fill(x + state::px(4), ly + state::px(4), w, rows * lh, p.shadow);
    win::fill(x, ly, w, rows * lh, p.surface);
    var i: i32 = 0;
    var start: i64 = 0;
    var k: i64 = 0;
    var idx: i32 = 0;
    while k <= items.len && idx < rows {
        if k == items.len || items[k] == '\n' {
            if k > start {
                let it = items[start..k];
                if idx == state::overlay_sel { win::fill(x + state::px(4), ly + idx * lh, w - state::px(8), lh, p.surface_hover); }
                win::text_at(state::f_ui, x + state::px(14), ly + idx * lh + (lh - win::th(state::f_ui)) / 2, i18n::t(it), p.text);
                state::add_hit(state::HIT_OVERLAY, x + state::px(4), ly + idx * lh, w - state::px(8), lh, idx as i64 + 1);
                idx++;
            }
            start = k + 1;
        }
        k++;
    }
}

// --- state helpers -----------------------------------------------------------

fn overlay_open(kind: i32) {
    state::overlay = kind;
    state::query.resize(0);
    state::overlay_sel = 0;
    state::blink = true;
    if kind == 2 { refresh_items(); }
    if kind == 1 { refresh_commands(); }
}

import app.menu.action;

fn refresh_commands() {
    commands.resize(0);
    commands.append("新建文件\0打开文件夹…\0保存\0关闭标签页\0");
    commands.append("切换侧边栏\0切换终端\0查找\0转到行…\0");
    commands.append("浅色\0深色\0放大\0缩小\0重置缩放\0自动换行\0Vim 模式\0");
    compute_items(0);
}

fn refresh_items() {
    compute_items(1);
}

fn compute_items(kind: i32) {
    items.resize(0);
    item_count = 0;
    if kind == 0 {
        var i: i64 = 0;
        var start: i64 = 0;
        while i <= commands.len {
            if i == commands.len || commands[i] == 0 {
                if i > start {
                    let c = commands[start..i];
                    if match_query(c, state::query) {
                        var j: i64 = start;
                        while j < i { items.push(commands[j]); j++; }
                        items.push('\n');
                        item_count++;
                    }
                }
                start = i + 1;
            }
            i++;
        }
    } else {
        var i = 0;
        while i < tree::rows.len as i32 {
            let r = tree::rows[i];
            if !r.dir && match_query(r.path, state::query) {
                var k: i64 = 0;
                while k < r.name.len { items.push(r.name[k]); k++; }
                items.push('\n');
                item_count++;
            }
            i++;
        }
    }
    if state::overlay_sel >= item_count { state::overlay_sel = item_count - 1; }
    if state::overlay_sel < 0 { state::overlay_sel = 0; }
}

fn match_query(text: const u8[:], q: const u8[:]) -> bool {
    if q.len == 0 { return true; }
    var i: i64 = 0;
    var j: i64 = 0;
    while i < text.len && j < q.len {
        var a = text[i];
        var b = q[j];
        if a >= 'A' && a <= 'Z' { a = a + 32; }
        if b >= 'A' && b <= 'Z' { b = b + 32; }
        if a == b { j++; }
        i++;
    }
    return j == q.len;
}

fn recompute() {
    if state::overlay == 1 { compute_items(0); }
    else if state::overlay == 2 { compute_items(1); }
    else { item_count = 0; }
    win::invalidate();
}

fn item_at(idx: i32) -> u8[>..] {
    var out: u8[>..] = [];
    var i: i32 = 0;
    var k: i64 = 0;
    var start: i64 = 0;
    while k <= items.len {
        if k == items.len || items[k] == '\n' {
            if k > start {
                if i == idx {
                    var j: i64 = start;
                    while j < k { out.push(items[j]); j++; }
                    return out;
                }
                i++;
            }
            start = k + 1;
        }
        k++;
    }
    return out;
}

// open_overlay_row opens the result the quick open box shows at idx.
fn open_overlay_row(idx: i32) {
    if state::overlay == 1 {
        let name = item_at(idx);
        if name.len > 0 && menu::run_label(name[0..name.len]) {
            state::overlay = 0;
            win::invalidate();
            return;
        }
        state::overlay = 0;
        return;
    }
    var i: i32 = 0;
    var k: i64 = 0;
    var start: i64 = 0;
    while k <= items.len {
        if k == items.len || items[k] == '\n' {
            if k > start {
                if i == idx {
                    var name: u8[>..] = [];
                    var j: i64 = start;
                    while j < k { name.push(items[j]); j++; }
                    var r: i32 = 0;
                    while r < tree::rows.len as i32 {
                        let row = tree::rows[r];
                        var hit = false;
                        if !row.dir && row.name.len == name.len {
                            var q: i64 = 0;
                            hit = true;
                            while q < name.len {
                                if row.name[q] != name[q] { hit = false; break; }
                                q++;
                            }
                        }
                        if hit {
                            app::open_path(row.path);
                            state::overlay = 0;
                            return;
                        }
                        r++;
                    }
                    state::overlay = 0;
                    return;
                }
                i++;
            }
            start = k + 1;
        }
        k++;
    }
    state::overlay = 0;
}
















