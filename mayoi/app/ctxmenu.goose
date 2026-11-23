// The context menus: the folder's file actions and the editor's edit actions.
namespace chrome;

import app.state;
import ui.theme;
import ui.win;
import explore.tree;

struct CtxItem { label: u8[..80], act: i32, enabled: bool, sep: bool, top: i32, h: i32 }

var ctx_open: bool = false;
var ctx_x: i32 = 0;
var ctx_y: i32 = 0;
var ctx_w: i32 = 0;
var ctx_h: i32 = 0;
var ctx_sel: i32 = -1;
var ctx_where: i32 = 0;          // 1 a tree row, 2 the tree's blank space, 3 the editor
var ctx_row: i32 = -1;
var ctx_path: u8[>..] = [];
var ctx_dir: u8[>..] = [];
var ctx_is_dir: bool = false;
var ctx_items: CtxItem[>..] = [];

fn ctx_close() {
    ctx_open = false;
    ctx_items.resize(0);
    ctx_sel = -1;
}

fn push_label(dst: u8[..80]&, src: const u8[:]) {
    var k: i64 = 0;
    while k < src.len && dst.len < 76 { dst.push(src[k]); k++; }
}

fn ctx_add(label: const u8[:], act: i32, enabled: bool) {
    var it: CtxItem = CtxItem { .. };
    push_label(it.label, label);
    it.act = act;
    it.enabled = enabled;
    it.sep = false;
    ctx_items.push(it);
}

fn ctx_sep() {
    var it: CtxItem = CtxItem { .. };
    it.act = 0;
    it.enabled = false;
    it.sep = true;
    ctx_items.push(it);
}

// ctx_place measures the menu and puts it at the click, kept inside the window.
fn ctx_place(x: i32, y: i32) {
    let f = state::f_tree;
    let rh = state::px(24);
    let sep_h = state::px(9);
    var maxw = state::px(64);
    var total = state::px(8);
    var i: i64 = 0;
    while i < ctx_items.len {
        let it = ctx_items[i];
        if it.sep {
            total = total + sep_h;
        } else {
            let w = win::measure(f, it.label) + state::px(56);
            if w > maxw { maxw = w; }
            total = total + rh;
        }
        i++;
    }
    total = total + state::px(6);
    ctx_w = maxw;
    ctx_h = total;
    ctx_x = x;
    ctx_y = y;
    if ctx_x + ctx_w > state::W - state::px(6) { ctx_x = state::W - ctx_w - state::px(6); }
    if ctx_y + ctx_h > state::H - state::px(6) { ctx_y = state::H - ctx_h - state::px(6); }
    if ctx_x < 0 { ctx_x = 0; }
    if ctx_y < 0 { ctx_y = 0; }
    // the rows' tops, for painting and hit tests alike
    var cy = ctx_y + state::px(4);
    i = 0;
    while i < ctx_items.len {
        ctx_items[i].top = cy;
        if ctx_items[i].sep { cy = cy + sep_h; } else { cy = cy + rh; }
        i++;
    }
    ctx_open = true;
}

fn ctx_open_tree(i: i32, x: i32, y: i32) {
    ctx_close();
    if i < 0 || i >= tree::rows.len as i32 { return; }
    let r = tree::rows[i];
    ctx_where = 1;
    ctx_row = i;
    ctx_path.resize(0);
    ctx_path.append(r.path);
    ctx_dir.resize(0);
    if r.dir { ctx_dir.append(r.path); } else { ctx_dir.append(tree::dir_of(r.path)); }
    ctx_is_dir = r.dir;
    ctx_add("新建文件…", 1, true);
    ctx_add("新建文件夹…", 2, true);
    ctx_sep();
    ctx_add("在文件资源管理器中显示", 3, true);
    ctx_add("在终端中打开", 4, true);
    ctx_sep();
    ctx_add("复制", 5, true);
    ctx_add("粘贴", 6, false);
    ctx_sep();
    ctx_add("复制路径", 7, true);
    ctx_add("复制相对路径", 8, true);
    ctx_sep();
    ctx_add("重命名…", 9, true);
    ctx_add("删除", 10, true);
    ctx_place(x, y);
}

fn ctx_open_tree_blank(x: i32, y: i32) {
    ctx_close();
    ctx_where = 2;
    ctx_row = -1;
    ctx_dir.resize(0);
    if state::root.len > 0 { ctx_dir.append(state::root); }
    ctx_is_dir = true;
    ctx_add("新建文件…", 1, true);
    ctx_add("新建文件夹…", 2, true);
    ctx_sep();
    ctx_add("在文件资源管理器中显示", 3, true);
    ctx_add("在终端中打开", 4, true);
    ctx_sep();
    ctx_add("复制", 5, true);
    ctx_add("粘贴", 6, false);
    ctx_sep();
    ctx_add("复制路径", 7, true);
    ctx_add("复制相对路径", 8, true);
    ctx_place(x, y);
}

fn ctx_open_editor(x: i32, y: i32) {
    ctx_close();
    ctx_where = 3;
    ctx_add("撤销", 20, false);
    ctx_sep();
    ctx_add("剪切", 21, false);
    ctx_add("复制", 22, false);
    ctx_add("粘贴", 23, true);
    ctx_add("删除", 24, false);
    ctx_sep();
    ctx_add("全选", 25, true);
    ctx_place(x, y);
}

fn ctx_hover(x: i32, y: i32) {
    if !ctx_open { return; }
    var i: i64 = 0;
    while i < ctx_items.len {
        let it = ctx_items[i];
        if !it.sep && it.enabled && x >= ctx_x && x < ctx_x + ctx_w && y >= it.top && y < it.top + state::px(24) {
            if ctx_sel != i as i32 { ctx_sel = i as i32; win::invalidate(); }
            return;
        }
        i++;
    }
    if ctx_sel != -1 { ctx_sel = -1; win::invalidate(); }
}

fn ctx_action_at(x: i32, y: i32) -> i32 {
    if !ctx_open { return -1; }
    var i: i64 = 0;
    while i < ctx_items.len {
        let it = ctx_items[i];
        if !it.sep && it.enabled && x >= ctx_x && x < ctx_x + ctx_w && y >= it.top && y < it.top + state::px(24) {
            return it.act;
        }
        i++;
    }
    return -1;
}

fn ctx_inside(x: i32, y: i32) -> bool {
    return ctx_open && x >= ctx_x && x <= ctx_x + ctx_w && y >= ctx_y && y <= ctx_y + ctx_h;
}

fn ctx_paint() {
    if !ctx_open { return; }
    let p = theme::pal;
    let f = state::f_tree;
    win::fill(ctx_x + state::px(3), ctx_y + state::px(3), ctx_w, ctx_h, p.shadow);
    win::fill(ctx_x + state::px(2), ctx_y + state::px(2), state::px(3), ctx_h - state::px(4), p.shadow);
    win::fill(ctx_x + state::px(3), ctx_y + ctx_h - state::px(1), ctx_w - state::px(1), state::px(2), p.shadow);
    win::fill(ctx_x, ctx_y, ctx_w as i64, ctx_h, p.surface);
    win::line(ctx_x, ctx_y, ctx_x + ctx_w - 1, ctx_y, p.border, 1);
    win::line(ctx_x, ctx_y + ctx_h - 1, ctx_x + ctx_w - 1, ctx_y + ctx_h - 1, p.border, 1);
    win::line(ctx_x, ctx_y, ctx_x, ctx_y + ctx_h - 1, p.border, 1);
    win::line(ctx_x + ctx_w - 1, ctx_y, ctx_x + ctx_w - 1, ctx_y + ctx_h - 1, p.border, 1);
    var i: i64 = 0;
    while i < ctx_items.len {
        let it = ctx_items[i];
        if it.sep {
            win::line(ctx_x + state::px(10), it.top + state::px(4), ctx_x + ctx_w - state::px(10),
                it.top + state::px(4), win::mix(p.surface, p.text, 180), 1);
        } else {
            if ctx_sel == i as i32 { win::fill(ctx_x + 1, it.top, ctx_w - 2, state::px(24), p.active); }
            let col = if it.enabled { p.text } else { p.faint };
            ch(f, ctx_x + state::px(12), it.top + state::px(12), it.label, col);
            state::add_hit(state::HIT_CTX_ROW, ctx_x, it.top, ctx_w, state::px(24), i);
        }
        i++;
    }
    state::add_hit(state::HIT_CTX, ctx_x, ctx_y, ctx_w, ctx_h, 0);
}
