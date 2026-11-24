// Everything the window knows: the open documents, the tree, the layout, the
// hits of the last frame.
namespace state;

import ui.win;

var arena: u8[>..] = [];         // all document text, offset-addressed
var docs: Doc[>..] = [];
var cur: i32 = -1;
var ime_x: i32 = 0;
var ime_y: i32 = 0;
var ime_skip_until: i64 = 0;
var ime_composing: bool = false;
var ime_comp: u8[>..] = [];
var lines: i64[>..] = [];        // line starts of the current document
var lines_doc: i32 = -1;
var lines_len: i64 = -1;

struct Doc {
    off: i64, len: i64, cap: i64,
    path: u8[..1024],
    name: u8[..160],
    lang: i32,
    sel_a: i64, sel_b: i64,
    want_col: i32,
    scroll: i32,
    scroll_x: i32,
    dirty: bool,
}

// layout, physical pixels
var s: i32 = 1;
var W: i32 = 0;
var H: i32 = 0;
var title_h: i32 = 0;
var tab_h: i32 = 0;
var crumb_h: i32 = 0;
var status_h: i32 = 0;
var panel_head: i32 = 0;
var sidebar_w: i32 = 0;
var row_h: i32 = 0;
var line_h: i32 = 0;
var cell_w: i32 = 0;
var code_x: i32 = 0;
var gutter_w: i32 = 0;
var fs_ui: i32 = 0;
var f_ui: u64 = 0;
var f_ui_b: u64 = 0;
var f_small: u64 = 0;
var f_small_b: u64 = 0;
var f_tree: u64 = 0;
var f_cjk: u64 = 0;
var f_code: u64 = 0;
var f_code_small: u64 = 0;
var f_title: u64 = 0;
var f_prefs: u64 = 0;
var f_prefs_b: u64 = 0;
var f_prefs_k: u64 = 0;
var f_prefs_h: u64 = 0;
var fs_small: i32 = 0;
var fs_code: i32 = 0;
var ed_top: i32 = 0;      // top of the text area
var ed_bot: i32 = 0;
var ed_left: i32 = 0;
var ed_right: i32 = 0;

// ui state
var sidebar_open: bool = true;
var panel_open: bool = false;
var panel_h: i32 = 0;
var view: i32 = 1;            // 1 explorer, 2 search, 3 source control, 4 recent
var focus: i32 = 0;           // 0 editor, 1 sidebar, 2 panel
var overlay: i32 = 0;         // 0 none, 1 palette, 2 quick open, 3 find
var query: u8[>..] = [];
var query_sel: i32 = 0;
var overlay_sel: i32 = 0;
var overlay_top: i32 = 0;
var panel_tab: i32 = 0;
var wrap_enabled: bool = false;   // wordWrap setting (or Alt+Z for this window)
var preview_open: bool = false;   // the markdown preview shows
var preview_side: bool = false;   // beside the editor rather than in its place
var preview_live: bool = false;   // updates as the text changes (it always does)
var preview_scroll: i32 = 0;
var pv_x0: i32 = 0; var pv_y0: i32 = 0; var pv_w: i32 = 0; var pv_h: i32 = 0;
var pv_total: i32 = 0; var pv_max: i32 = 0;
var blink: bool = true;
var status_msg: u8[>..] = [];
var status_until: i64 = 0;
var root: u8[>..] = [];
var root_name: u8[>..] = [];
// The folders open at once while project tabs are on: the rail badges, in
// the order they were opened, and the one shown.
var pbuf: u8[>..] = [];
var pn: i32 = 0;
var pcur: i32 = -1;
var hover_kind: i32 = 0;
var hover_arg: i64 = 0;
var drag: i32 = 0;            // 0 none, 1 text select, 2 scrollbar, 3 splitter
var drag_x0: i32 = 0;
var drag_y0: i32 = 0;
var drag_base: i32 = 0;
var scroll_focus: i32 = 0;
var clock: i64 = 0;
var menu_open: bool = false;
var menu_sel: i32 = -1;      // hovered top-level group
var menu_row: i32 = -1;      // hovered entry in the group panel
var menu_p2: i32 = -1;       // hovered entry in a nested panel
var menu_fresh: bool = false; // the menu opened on this click
var search_q: u8[>..] = [];
var search_hits: u8[>..] = [];
var search_rep: u8[>..] = [];
var search_inc: u8[>..] = [];
var search_exc: u8[>..] = [];
var search_case: bool = false;
var search_word: bool = false;
var search_regex: bool = false;
var search_details: bool = false;
var search_replacing: bool = false;
var search_field: i32 = 0;   // 0 query, 1 replace, 2 include, 3 exclude
var tree_off: i32 = 0;       // first explorer row on screen
var tree_vis: i32 = 0;       // rows that fit, set by the explorer each frame
var tree_ttop: i32 = 0;      // top of the explorer scroll track
var tree_track: i32 = 0;     // height of the explorer scroll track
var tree_thumb: i32 = 0;     // height of the explorer scroll thumb
var mx: i32 = 0;
var my: i32 = 0;
var ren_path: u8[>..] = [];
var ren_buf: u8[>..] = [];
var ren_active: bool = false;
var ren_is_new: bool = false;
var scm_text: u8[>..] = [];
var scm_loaded: bool = false;
var scm_msg: u8[>..] = [];   // the commit message box
var scm_focus: i32 = 0;      // 0 none, 1 commit box

// hit regions of the frame just drawn
var hits: Hit[>..] = [];

struct Hit { x: i32, y: i32, w: i32, h: i32, kind: i32, arg: i64 }

let HIT_NONE = 0; let HIT_ACTIVITY = 1; let HIT_TREEROW = 2; let HIT_CHEVRON = 3;
let HIT_TAB = 4; let HIT_TAB_CLOSE = 5; let HIT_TITLE = 6; let HIT_STATUS = 7;
let HIT_PANEL_TAB = 8; let HIT_CMD = 9; let HIT_TOGGLE_SIDEBAR = 10;
let HIT_TOGGLE_PANEL = 11; let HIT_TOGGLE_TERM = 12; let HIT_SPLITTER = 13;
let HIT_SIDEBAR_ACTION = 14; let HIT_CRUMB = 15; let HIT_OVERLAY = 16;
let HIT_CLOSE_PANEL = 17; let HIT_CARET = 18; let HIT_RULE = 19;
let HIT_MENU = 20; let HIT_MENU_ROW = 21; let HIT_SEARCH = 22; let HIT_SCM_ROW = 23;
let HIT_CTX_ROW = 24; let HIT_CTX = 25; let HIT_TREE_SCROLL = 26;
let HIT_SEARCH_OPT = 27; let HIT_SEARCH_DETAILS = 28; let HIT_SEARCH_REFRESH = 29;
let HIT_SEARCH_CLEAR = 30; let HIT_SEARCH_REPLACE_ALL = 31; let HIT_SEARCH_COLLAPSE = 32;
let HIT_SEARCH_FIELD = 33; let HIT_SCM_INIT = 34; let HIT_SCM_COMMIT = 35;
let HIT_PREFS_WIN = 36; let HIT_PREFS_CLOSE = 37; let HIT_PREFS_NAV = 38;
let HIT_PREFS_SEARCH = 39; let HIT_PREFS_TOGGLE = 40; let HIT_PREFS_STEP = 41;
let HIT_PREFS_ENUM = 42; let HIT_PREFS_OPT = 43; let HIT_PREFS_TEXT = 44;
let HIT_PREFS_RESET = 45;
let HIT_PREFS_PL_RELOAD = 46; let HIT_PREFS_PL_FOLDER = 47; let HIT_PREFS_PL_TOGGLE = 48;
let HIT_PREFS_PL_REMOVE = 49; let HIT_PREFS_PL_INSTALL = 50; let HIT_PREFS_PL_CARD = 51;
let HIT_PREFS_PL_BACK = 52;
let HIT_PREVIEW = 53; let HIT_PREFS_SCOPE = 54;
let HIT_PROJECT = 55;
let HIT_PROJECT_NEW = 56;

fn hit(kind: i32, x: i32, y: i32, w: i32, h: i32, arg: i64) -> Hit {
    return Hit { x, y, w, h, kind, arg };
}

fn add_hit(kind: i32, x: i32, y: i32, w: i32, h: i32, arg: i64) {
    hits.push(Hit { x, y, w, h, kind, arg });
}

fn find_hit(x: i32, y: i32) -> i32 {
    var i = hits.len - 1;
    while i >= 0 {
        let h = hits[i];
        if x >= h.x && x < h.x + h.w && y >= h.y && y < h.y + h.h { return i as i32; }
        i--;
    }
    return -1;
}

fn px(v: i32) -> i32 { return win::px(v); }

fn right_x() -> i32 {
    if sidebar_open { return sidebar_w; }
    return 0;
}

fn top_y() -> i32 { return title_h + tab_h + crumb_h; }
fn cell(v: i32) -> i32 { return v * cell_w; }








