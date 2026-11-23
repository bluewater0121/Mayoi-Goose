// What the context menus do, and the inline rename the file ones start.
namespace input;

import std;
import os;
import app.state;
import ui.theme;
import ui.win;
import explore.tree;
import editor.text;
import editor.syntax;
import app.draw;
import app.sidebar;
import app.ctxmenu;

fn clip_put_text(s: const u8[:]) {
    if s.len == 0 { return; }
    win::gs_clip_put(s[0], s.len as i64);
}

fn path_join(dir: const u8[:], name: const u8[:]) -> u8[>..] {
    var p: u8[>..] = [];
    if dir.len > 0 { p.append(dir); p.push('/'); }
    p.append(name);
    return p;
}

fn unique_in(dir: const u8[:], base: const u8[:]) -> u8[>..] {
    var name: u8[>..] = [];
    name.append(base);
    var p = path_join(dir, name);
    var n: i32 = 0;
    while is_dir(p) || file_exists(p) {
        n++;
        name.resize(0);
        name.append(base);
        if n < 10 { name.push(' '); name.push('0' + n as u8); }
        else { name.push(' '); name.push('1'); name.push('0' + (n - 10) as u8); }
        p = path_join(dir, name);
    }
    return p;
}

fn base_name(path: const u8[:]) -> u8[>..] {
    var b: u8[>..] = [];
    var i: i64 = path.len;
    var start: i64 = 0;
    while i > 0 {
        i--;
        if path[i] == '/' || path[i] == '\\' { start = i + 1; break; }
    }
    var k = start;
    while k < path.len { b.push(path[k]); k++; }
    return b;
}

fn start_rename(path: const u8[:], is_new: bool) {
    state::ren_path.resize(0);
    state::ren_path.append(path);
    state::ren_buf.resize(0);
    let b = base_name(path);
    state::ren_buf.append(b);
    state::ren_active = true;
    state::ren_is_new = is_new;
    state::focus = 1;
}

fn commit_rename() {
    if !state::ren_active { return; }
    let path: u8[>..] = copy(state::ren_path);
    let name: u8[>..] = copy(state::ren_buf);
    if name.len > 0 {
        var to = path_join(tree::dir_of(path), name);
        if !tree::eqs(to, path) {
            if !file_exists(to) && !is_dir(to) { rename_file(path, to); }
        }
    }
    state::ren_active = false;
    state::ren_is_new = false;
    tree::rebuild();
    win::invalidate();
}

fn cancel_rename() {
    if !state::ren_active { return; }
    if state::ren_is_new {
        let path: u8[>..] = copy(state::ren_path);
        if !is_dir(path) { delete_file(path); }
    }
    state::ren_active = false;
    state::ren_is_new = false;
    tree::rebuild();
    win::invalidate();
}

fn rename_char(c: u16) {
    if !state::ren_active { return; }
    if c == 8 {
        if state::ren_buf.len > 0 { state::ren_buf.resize(state::ren_buf.len - 1); }
    } else if c >= 32 {
        state::ren_buf.push(c as u8);
    }
    win::invalidate();
}

fn confirm_delete(name: const u8[:]) -> bool {
    return win::gs_confirm(win::hwnd, name[0], name.len as i64) != 0;
}

fn ctx_run(act: i32) {
    let path: u8[>..] = copy(chrome::ctx_path);
    let dir: u8[>..] = copy(chrome::ctx_dir);
    if act == 1 {                       // new file
        let p = unique_in(dir, "untitled");
        var empty: u8[>..] = [];
        write_file(p, empty);
        chrome::ctx_close();
        tree::rebuild();
        start_rename(p, true);
        app::open_path(p);
        win::invalidate();
        return;
    }
    if act == 2 {                       // new folder
        let p = unique_in(dir, "新建文件夹");
        make_dir(p);
        chrome::ctx_close();
        tree::rebuild();
        start_rename(p, true);
        win::invalidate();
        return;
    }
    if act == 3 || act == 4 {           // reveal / terminal
        var cmd: u8[>..] = [];
        if act == 3 {
            cmd.append("explorer ");
            if chrome::ctx_is_dir || path.len == 0 { cmd.push('"'); cmd.append(dir); cmd.push('"'); }
            else { cmd.append("/select,\""); cmd.append(path); cmd.push('"'); }
        } else {
            cmd.append("start \"\" cmd /K cd /d \"");
            cmd.append(dir);
            cmd.push('"');
        }
        var out: u8[>..] = [];
        out.resize(1024, 0);
        var cwd: u8[>..] = [];
        cwd.append(".");
        win::gs_run_cmd(cmd[0], cmd.len as i64, out[0], 1024, cwd[0], 1);
        chrome::ctx_close();
        return;
    }
    if act == 5 || act == 7 || act == 8 {   // copy / copy path / copy relative path
        var t: u8[>..] = [];
        if act == 5 {
            let b = base_name(path);
            t.append(b);
            chrome::ctx_clip.resize(0);
            chrome::ctx_clip.append(path);
        } else if act == 7 {
            t.append(path);
        } else {
            var q: i64 = state::root.len;
            if path.len > q && (path[q] == '/' || path[q] == '\\') { q++; }
            while q < path.len { t.push(path[q]); q++; }
        }
        clip_put_text(t);
        app::set_status("已复制");
        chrome::ctx_close();
        return;
    }
    if act == 6 {                       // paste the copied file or folder
        if chrome::ctx_clip.len == 0 {
            app::set_status("没有可粘贴的文件");
            chrome::ctx_close();
            return;
        }
        var dst: u8[>..] = [];
        dst.append(dir);
        dst.push('/');
        dst.append(base_name(chrome::ctx_clip));
        var cmd: u8[>..] = [];
        if is_dir(chrome::ctx_clip) {
            cmd.append("xcopy /E /I /Y \"");
            cmd.append(chrome::ctx_clip);
            cmd.append("\" \"");
            cmd.append(dst);
            cmd.push('"');
        } else {
            cmd.append("copy /Y \"");
            cmd.append(chrome::ctx_clip);
            cmd.append("\" \"");
            cmd.append(dst);
            cmd.push('"');
        }
        var out: u8[>..] = [];
        out.resize(1024, 0);
        var cwd: u8[>..] = [];
        cwd.append(".");
        let rc = win::gs_run_cmd(cmd[0], cmd.len as i64, out[0], 1024, cwd[0], 1);
        chrome::ctx_close();
        tree::rebuild();
        if rc == 0 { app::set_status("已粘贴"); } else { app::set_status("粘贴失败，目标已存在同名文件"); }
        win::invalidate();
        return;
    }
    if act == 9 {                       // rename
        chrome::ctx_close();
        start_rename(path, false);
        win::invalidate();
        return;
    }
    if act == 10 {                      // delete
        let b = base_name(path);
        if confirm_delete(b) {
            if chrome::ctx_is_dir {
                var cmd: u8[>..] = [];
                cmd.append("rmdir /s /q \"");
                cmd.append(path);
                cmd.push('"');
                var out: u8[>..] = [];
                out.resize(1024, 0);
                var cwd: u8[>..] = [];
                cwd.append(".");
                win::gs_run_cmd(cmd[0], cmd.len as i64, out[0], 1024, cwd[0], 1);
            } else {
                delete_file(path);
            }
            tree::rebuild();
        }
        chrome::ctx_close();
        win::invalidate();
        return;
    }
    if act == 20 { text::undo_edit(); syntax::invalidate(); win::invalidate(); return; }
    if act == 23 { input::paste(); win::invalidate(); return; }
    if act == 25 {
        if state::cur >= 0 {
            let d .= state::docs[state::cur];
            d.sel_a = 0;
            d.sel_b = d.len;
            input::ensure_visible();
            win::invalidate();
        }
        return;
    }
}

fn right_down(x: i32, y: i32) {
    if state::ren_active { cancel_rename(); win::invalidate(); return; }
    if chrome::ctx_open {
        let act = chrome::ctx_action_at(x, y);
        chrome::ctx_close();
        if act >= 0 { ctx_run(act); }
        win::invalidate();
        return;
    }
    if !state::sidebar_open || x >= state::sidebar_w {
        // the editor: right click only shows its menu once it holds the keyboard
        if y >= state::title_h && state::docs.len > 0 && state::cur >= 0 {
            state::focus = 0;
            chrome::ctx_open_editor(x, y);
            win::invalidate();
        }
        return;
    }
    if state::view != 1 { return; }
    let hi = state::find_hit(x, y);
    if hi >= 0 {
        let h = state::hits[hi as i64];
        if h.kind == state::HIT_TREEROW {
            if h.arg >= 0 {
                state::focus = 1;
                tree::focus_row = h.arg as i32;
                chrome::ctx_open_tree(tree::focus_row, x, y);
            } else {
                chrome::ctx_open_tree_blank(x, y);
            }
            win::invalidate();
            return;
        }
    }
    chrome::ctx_open_tree_blank(x, y);
    win::invalidate();
}

fn wheel_sidebar(notches: i32) -> bool {
    if !state::sidebar_open || state::view != 1 { return false; }
    if state::mx >= state::sidebar_w { return false; }
    state::tree_off = state::tree_off - notches * 3;
    tree::clamp_off();
    win::invalidate();
    return true;
}
