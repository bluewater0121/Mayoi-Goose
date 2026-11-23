// The sidebar: its activity rail, then the view that is open, one module a view.
namespace chrome;

import std;
import app.state;
import ui.theme;
import ui.win;
import editor.text;
import explore.tree;
import app.sidebar.rail;
import app.sidebar.explorer;
import app.sidebar.search;
import app.sidebar.searchui;
import app.sidebar.scm;
import app.sidebar.scmui;
import app.sidebar.sessions;

fn sidebar() {
    if !state::sidebar_open { return; }
    let p = theme::pal;
    let w = state::sidebar_w;
    win::fill(0, state::title_h, w, state::H - state::title_h, p.chrome);
    win::fill(w - 1, state::title_h, 1, state::H - state::title_h, p.border);
    rail();
    let row1 = state::title_h;
    let row2 = row1 + state::px(42);
    if state::view == 1 {
        ch(state::f_ui, state::px(163), row1 + state::px(21), view_title(), p.text);
        let cy2 = row2 + state::px(15);
        ch(state::f_ui_b, state::px(28), cy2, root_caps(), p.text);
        explorer_body(row2 + state::px(30));
    } else if state::view == 2 {
        // the search view's title sits at the left, its actions at the right
        ch(state::f_ui, state::px(163), row1 + state::px(21), "搜索", p.text);
        let iy = row1 + state::px(13);
        icon_at(12, w - state::px(49), iy, state::px(15), p.muted);
        state::add_hit(state::HIT_SEARCH_CLEAR, w - state::px(55), row1 + state::px(4), state::px(26), state::px(30), 0);
        icon_at(14, w - state::px(82), iy, state::px(15), p.muted);
        state::add_hit(state::HIT_SEARCH_REFRESH, w - state::px(88), row1 + state::px(4), state::px(26), state::px(30), 0);
        search_body(row2 + state::px(2));
    } else if state::view == 3 {
        ch(state::f_ui, state::px(163), row1 + state::px(21), view_title(), p.text);
        scm_body(row2);
    } else {
        ch(state::f_ui, state::px(163), row1 + state::px(21), view_title(), p.text);
        sessions_body(row2);
    }
}

// A click inside a view that the views own rather than the editor.
fn sidebar_click(kind: i32, arg: i64) -> bool {
    if kind == state::HIT_SEARCH {
        state::focus = 1;
        win::invalidate();
        return true;
    }
    if kind == state::HIT_SEARCH_FIELD {
        state::focus = 1;
        state::search_field = arg as i32;
        win::invalidate();
        return true;
    }
    if kind == state::HIT_SEARCH_OPT {
        state::focus = 1;
        if arg == 1 { state::search_case = !state::search_case; }
        else if arg == 2 { state::search_word = !state::search_word; }
        else { state::search_regex = !state::search_regex; }
        run_search();
        win::invalidate();
        return true;
    }
    if kind == state::HIT_SEARCH_DETAILS {
        state::search_details = !state::search_details;
        win::invalidate();
        return true;
    }
    if kind == state::HIT_SEARCH_COLLAPSE {
        state::search_replacing = !state::search_replacing;
        state::search_field = 0;
        win::invalidate();
        return true;
    }
    if kind == state::HIT_SEARCH_REPLACE_ALL {
        replace_all();
        win::invalidate();
        return true;
    }
    if kind == state::HIT_SEARCH_REFRESH {
        run_search();
        win::invalidate();
        return true;
    }
    if kind == state::HIT_SEARCH_CLEAR {
        state::search_q.resize(0);
        search_rows.resize(0);
        search_n = 0;
        win::invalidate();
        return true;
    }
    if kind == state::HIT_SCM_INIT {
        scm_init();
        win::invalidate();
        return true;
    }
    if kind == state::HIT_SCM_COMMIT {
        if arg == 2 { scm_commit(); } else { state::focus = 1; state::scm_focus = 1; }
        win::invalidate();
        return true;
    }
    if kind == state::HIT_SCM_ROW {
        if state::view == 3 { open_scm_row(arg as i32); }
        else if state::view == 2 { open_search_row(arg as i32); }
        win::invalidate();
        return true;
    }
    return false;
}

fn sidebar_char(c: u16) {
    if state::view == 2 {
        search_char(c);
        return;
    }
    if state::view == 3 && state::scm_focus == 1 {
        if c == 8 {
            if state::scm_msg.len > 0 { state::scm_msg.resize(state::scm_msg.len - 1); }
        } else if c >= 32 {
            state::scm_msg.push(c as u8);
        }
        win::invalidate();
    }
}
