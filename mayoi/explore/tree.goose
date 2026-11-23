// The explorer: one flat list of rows rebuilt from the expanded folders.
namespace tree;

import std;
import os;
import app.state;
import ui.theme;
import ui.win;

struct Entry {
    path: u8[..1024], name: u8[..160], parent: u8[..1024],
    depth: i32, dir: bool, open: bool, lang: i32,
}
var rows: Entry[>..] = [];
var expanded: u8[>..] = [];      // "\path\n" for each open folder
var scan: u8[>..] = [];          // scratch for one directory listing
var focus_row: i32 = 0;

fn push_bytes(dst: u8[..1024]&, src: const u8[:]) {
    var k: i64 = 0;
    while k < src.len && dst.len < 1000 { dst.push(src[k]); k++; }
}

fn push_name(dst: u8[..160]&, src: const u8[:]) {
    var k: i64 = 0;
    while k < src.len && dst.len < 150 { dst.push(src[k]); k++; }
}

fn eqs(a: const u8[:], b: const u8[:]) -> bool {
    if a.len != b.len { return false; }
    var i: i64 = 0;
    while i < a.len { if a[i] != b[i] { return false; } i++; }
    return true;
}

fn is_open(path: const u8[:]) -> bool {
    var i: i64 = 0;
    var start: i64 = 0;
    while i <= expanded.len {
        if i == expanded.len || expanded[i] == '\n' {
            if i - start == path.len {
                var k: i64 = 0;
                var same = true;
                while k < path.len {
                    if expanded[start + k] != path[k] { same = false; break; }
                    k++;
                }
                if same { return true; }
            }
            start = i + 1;
        }
        i++;
    }
    return false;
}

fn set_open(path: const u8[:], open: bool) {
    if open {
        if is_open(path) { return; }
        var out: u8[>..] = [];
        var k: i64 = 0;
        while k < expanded.len { out.push(expanded[k]); k++; }
        out.push('\n');
        k = 0;
        while k < path.len { out.push(path[k]); k++; }
        expanded.resize(0);
        k = 0;
        while k < out.len { expanded.push(out[k]); k++; }
    } else {
        var i: i64 = 0;
        var start: i64 = 0;
        var out: u8[>..] = [];
        while i <= expanded.len {
            if i == expanded.len || expanded[i] == '\n' {
                if i > start && !(i - start == path.len && starts_with_at(start, path)) {
                    out.push('\n');
                    var k = start;
                    while k < i { out.push(expanded[k]); k++; }
                }
                start = i + 1;
            }
            i++;
        }
        expanded.resize(0);
        var k: i64 = 0;
        while k < out.len { expanded.push(out[k]); k++; }
    }
}

fn starts_with_at(start: i64, path: const u8[:]) -> bool {
    var k: i64 = 0;
    while k < path.len {
        if expanded[start + k] != path[k] { return false; }
        k++;
    }
    return true;
}

fn child_path(dir: const u8[:], name: const u8[:]) -> u8[..1024] {
    var c: u8[..1024] = [];
    var k: i64 = 0;
    while k < dir.len && c.len < 1000 { c.push(dir[k]); k++; }
    if dir.len > 0 {
        let last = dir[dir.len - 1];
        if last != '/' && last != '\\' && c.len < 1000 { c.push('/'); }
    }
    k = 0;
    while k < name.len && c.len < 1000 { c.push(name[k]); k++; }
    return c;
}

fn dir_of(path: const u8[:]) -> u8[>..] {
    var d: u8[>..] = [];
    var i: i64 = path.len;
    while i > 0 {
        i--;
        if path[i] == '/' || path[i] == '\\' { break; }
    }
    var k: i64 = 0;
    while k < i { d.push(path[k]); k++; }
    return d;
}

// add_level walks one folder: each entry goes into the rows in its place,
// and an open folder goes on with its own children right under it.
recursive fn add_level(dir: const u8[:], depth: i32) {
    scan.resize(0);
    if !list_dir(dir, scan) { return; }
    var names: u8[..16384] = [];
    var k: i64 = 0;
    while k < scan.len && k < 16000 { names.push(scan[k]); k++; }
    var start: i64 = 0;
    var i: i64 = 0;
    while i <= names.len {
        if i == names.len || names[i] == '\n' {
            if i > start {
                let name = names[start..i];
                if name.len > 0 {
                    let path = child_path(dir, name);
                    let isd = is_dir(path);
                    var e: Entry = Entry { .. };
                    push_bytes(e.path, path);
                    push_name(e.name, name);
                    push_bytes(e.parent, dir);
                    e.depth = depth;
                    e.dir = isd;
                    e.lang = 0;
                    if !isd { e.lang = lang_for(name); }
                    if isd { e.open = is_open(path); }
                    rows.push(e);
                    if isd && e.open { add_level(path, depth + 1); }
                }
            }
            start = i + 1;
        }
        i++;
    }
}

fn lang_for(name: const u8[:]) -> i32 {
    var rev: u8[..16] = [];
    var i: i64 = name.len;
    var dot = false;
    while i > 0 {
        i--;
        if name[i] == '.' { dot = true; break; }
        rev.push(name[i]);
    }
    if !dot { return 0; }
    var ext: u8[..16] = [];
    var k: i64 = rev.len;
    while k > 0 { k--; ext.push(rev[k]); }
    if eqs(ext, "go") { return 1; }
    if eqs(ext, "js") || eqs(ext, "ts") || eqs(ext, "jsx") || eqs(ext, "tsx") { return 2; }
    if eqs(ext, "py") { return 3; }
    if eqs(ext, "rs") { return 4; }
    if eqs(ext, "c") || eqs(ext, "h") || eqs(ext, "cpp") { return 5; }
    if eqs(ext, "json") { return 6; }
    if eqs(ext, "md") { return 7; }
    if eqs(ext, "sh") { return 8; }
    if eqs(ext, "html") || eqs(ext, "css") { return 9; }
    if eqs(ext, "yml") || eqs(ext, "yaml") || eqs(ext, "toml") { return 10; }
    return 0;
}

fn rebuild() {
    rows.resize(0);
    if state::root.len == 0 { return; }
    add_level(state::root, 0);
}

fn row_of(path: const u8[:]) -> i32 {
    var i: i64 = 0;
    while i < rows.len {
        if eqs(rows[i].path, path) { return i as i32; }
        i++;
    }
    return -1;
}

fn row_of_name(name: const u8[:]) -> i32 {
    var i: i64 = 0;
    while i < rows.len {
        if !rows[i].dir && eqs(rows[i].name, name) { return i as i32; }
        i++;
    }
    return -1;
}

fn toggle(i: i32) {
    if i < 0 || i >= rows.len as i32 { return; }
    let r = rows[i];
    if !r.dir { return; }
    let want = !r.open;
    set_open(r.path, want);
    rebuild();
    // keep the toggled row on screen after the list grew or shrank
    var at = row_of(r.path);
    if at < 0 { at = i; }
    focus_row = at;
    ensure_visible();
}

fn open_all_of(path: const u8[:]) {
    set_open(path, true);
    rebuild();
}

// ensure_visible keeps the focused row inside the visible window.
fn ensure_visible() {
    if state::tree_vis <= 0 { return; }
    if focus_row < state::tree_off {
        state::tree_off = focus_row;
    } else if focus_row >= state::tree_off + state::tree_vis {
        state::tree_off = focus_row - state::tree_vis + 1;
    }
    clamp_off();
}

fn clamp_off() {
    let max_off = rows.len as i32 - state::tree_vis;
    if max_off < 0 {
        state::tree_off = 0;
    } else if state::tree_off > max_off {
        state::tree_off = max_off;
    }
    if state::tree_off < 0 { state::tree_off = 0; }
}

fn color_for(lang: i32) -> u32 {
    if lang == 1 { return theme::hx(0x7d, 0xcf, 0xe0); }
    if lang == 2 { return theme::hx(0xe8, 0xc4, 0x7a); }
    if lang == 3 { return theme::hx(0x7a, 0xc4, 0x8f); }
    if lang == 4 { return theme::hx(0xe0, 0x92, 0x7a); }
    if lang == 5 { return theme::hx(0x8f, 0xb4, 0xff); }
    if lang == 6 { return theme::hx(0xe8, 0xc4, 0x7a); }
    if lang == 7 { return theme::hx(0xa9, 0xd4, 0x8f); }
    if lang == 8 { return theme::hx(0x9a, 0xd0, 0xb4); }
    if lang == 9 { return theme::hx(0xf5, 0x90, 0xa8); }
    return theme::pal.muted;
}
