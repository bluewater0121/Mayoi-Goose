// The search view: the query, its options and filters, and what it found
// under the root, scanned a file at a time so a big folder cannot stall.
namespace chrome;

import std;
import os;
import app.state;
import ui.theme;
import ui.win;
import explore.tree;
import app.layout;

var search_rows: u8[>..] = [];   // newline separated "rel\tline\tsnippet"
var search_n: i32 = 0;
var seen_files: i32 = 0;
var queue: u8[>..] = [];         // "depth\tpath" per folder still to scan
var dirs_seen: i32 = 0;
var files_done: u8[>..] = [];    // "\rel\n" per file that matched

fn ends_with(s: const u8[:], ext: const u8[:]) -> bool {
    if s.len < ext.len { return false; }
    var i: i64 = 0;
    while i < ext.len {
        if s[s.len - ext.len + i] != ext[i] { return false; }
        i++;
    }
    return true;
}

// looks_text keeps the scan off pictures, archives and compiled objects;
// everything else is read and searched as text.
fn looks_text(s: const u8[:]) -> bool {
    if ends_with(s, ".png") { return false; }
    if ends_with(s, ".jpg") { return false; }
    if ends_with(s, ".jpeg") { return false; }
    if ends_with(s, ".gif") { return false; }
    if ends_with(s, ".ico") { return false; }
    if ends_with(s, ".icns") { return false; }
    if ends_with(s, ".bmp") { return false; }
    if ends_with(s, ".webp") { return false; }
    if ends_with(s, ".exe") { return false; }
    if ends_with(s, ".dll") { return false; }
    if ends_with(s, ".pdb") { return false; }
    if ends_with(s, ".obj") { return false; }
    if ends_with(s, ".lib") { return false; }
    if ends_with(s, ".so") { return false; }
    if ends_with(s, ".dylib") { return false; }
    if ends_with(s, ".zip") { return false; }
    if ends_with(s, ".gz") { return false; }
    if ends_with(s, ".7z") { return false; }
    if ends_with(s, ".rar") { return false; }
    if ends_with(s, ".xz") { return false; }
    if ends_with(s, ".pdf") { return false; }
    if ends_with(s, ".woff") { return false; }
    if ends_with(s, ".woff2") { return false; }
    if ends_with(s, ".ttf") { return false; }
    if ends_with(s, ".otf") { return false; }
    if ends_with(s, ".mp3") { return false; }
    if ends_with(s, ".mp4") { return false; }
    if ends_with(s, ".wav") { return false; }
    if ends_with(s, ".bin") { return false; }
    if ends_with(s, ".class") { return false; }
    if ends_with(s, ".jar") { return false; }
    if ends_with(s, ".pyc") { return false; }
    return true;
}

fn lower(c: u8) -> u8 {
    if c >= 'A' && c <= 'Z' { return c + 32; }
    return c;
}

fn wordc(c: u8) -> bool {
    if c >= 'a' && c <= 'z' { return true; }
    if c >= 'A' && c <= 'Z' { return true; }
    if c >= '0' && c <= '9' { return true; }
    if c == '_' { return true; }
    return false;
}

// match_at matches the query at i of text[a..b); it returns its length or -1.
fn match_at(text: const u8[:], i: i64, b: i64) -> i32 {
    let q = state::search_q;
    let qn = q.len;
    if qn == 0 { return -1; }
    if !state::search_regex {
        if i + qn > b { return -1; }
        var k: i64 = 0;
        while k < qn {
            let qc = q[k];
            let tc = text[i + k];
            if state::search_case {
                if qc != tc { return -1; }
            } else {
                if lower(qc) != lower(tc) { return -1; }
            }
            k++;
        }
        if state::search_word {
            if i > 0 && wordc(text[i - 1]) { return -1; }
            if i + qn < b && wordc(text[i + qn]) { return -1; }
        }
        return qn as i32;
    }
    var qi: i64 = 0;
    var ti = i;
    var star: i64 = -1;
    var star_t: i64 = 0;
    while ti < b && qi < qn {
        let qc = q[qi];
        if qc == '*' { star = qi; qi++; star_t = ti; continue; }
        let tc = text[ti];
        var ok = false;
        if qc == '.' { ok = true; }
        else if state::search_case { ok = qc == tc; }
        else { ok = lower(qc) == lower(tc); }
        if ok { qi++; ti++; continue; }
        if star >= 0 { qi = star + 1; star_t++; ti = star_t; continue; }
        return -1;
    }
    while qi < qn && q[qi] == '*' { qi++; }
    if qi < qn { return -1; }
    let n = ti - i;
    if state::search_word {
        if i > 0 && wordc(text[i - 1]) { return -1; }
        if ti < b && wordc(text[ti]) { return -1; }
    }
    return n as i32;
}

fn has_q(text: const u8[:], a: i64, b: i64) -> bool {
    if state::search_q.len == 0 { return false; }
    var i = a;
    while i < b {
        if match_at(text, i, b) > 0 { return true; }
        i++;
    }
    return false;
}

fn last_sep(s: const u8[:]) -> i64 {
    var i: i64 = s.len;
    while i > 0 {
        i--;
        if s[i] == '\\' || s[i] == '/' { return i; }
    }
    return -1;
}

// rel_path strips the root off a full path, so rows read "cmd/mayoi/view.go".
fn rel_path(path: const u8[:]) -> u8[>..] {
    var r: u8[>..] = [];
    let n = state::root.len;
    if n > 0 && path.len > n && (path[n] == '\\' || path[n] == '/') {
        var i: i64 = n + 1;
        while i < path.len { r.push(path[i]); i++; }
    } else {
        r.append(path);
    }
    return r;
}

fn base_of(path: const u8[:]) -> u8[>..] {
    let sep = last_sep(path);
    var b: u8[>..] = [];
    var i: i64 = if sep >= 0 { sep + 1 } else { 0 };
    while i < path.len { b.push(path[i]); i++; }
    return b;
}

// glob_one matches one pattern against a relative path, with * and ?.
fn glob_one(pat: const u8[:], path: const u8[:]) -> bool {
    var pi: i64 = 0;
    var si: i64 = 0;
    var star: i64 = -1;
    var star_s: i64 = 0;
    while si < path.len {
        var ok = false;
        if pi < pat.len {
            let pc = pat[pi];
            if pc == '*' { star = pi; star_s = si; pi++; continue; }
            if pc == '?' { ok = true; }
            else if state::search_case { ok = pc == path[si]; }
            else { ok = lower(pc) == lower(path[si]); }
        }
        if ok { pi++; si++; continue; }
        if star >= 0 { pi = star + 1; star_s++; si = star_s; continue; }
        return false;
    }
    while pi < pat.len && pat[pi] == '*' { pi++; }
    return pi >= pat.len;
}

fn glob_hit(globs: const u8[:], path: const u8[:], base: const u8[:]) -> bool {
    if globs.len == 0 { return false; }
    var start: i64 = 0;
    var i: i64 = 0;
    while i <= globs.len {
        if i == globs.len || globs[i] == ',' {
            var a = start;
            var b = i;
            while a < b && globs[a] == ' ' { a++; }
            while b > a && globs[b - 1] == ' ' { b--; }
            if b > a {
                let pat = globs[a..b];
                // a pattern with a slash reads against the path, one without
                // against the name
                var slash = false;
                var k = a;
                while k < b {
                    if globs[k] == '/' || globs[k] == '\\' { slash = true; break; }
                    k++;
                }
                if slash {
                    var norm: u8[..512] = [];
                    var t: i64 = 0;
                    while t < pat.len && norm.len < 500 {
                        norm.push(if pat[t] == '\\' { '/' } else { pat[t] });
                        t++;
                    }
                    var pp: u8[..512] = [];
                    t = 0;
                    while t < path.len && pp.len < 500 {
                        pp.push(if path[t] == '\\' { '/' } else { path[t] });
                        t++;
                    }
                    if glob_one(norm, pp) { return true; }
                    // "src/**" also covers "src" itself
                    let prefix_len = norm.len - 2;
                    if prefix_len > 0 && norm[prefix_len] == '/' {
                        var pre: u8[..512] = [];
                        t = 0;
                        while t < prefix_len && pre.len < 500 { pre.push(norm[t]); t++; }
                        if glob_one(pre, pp) { return true; }
                    }
                } else {
                    if glob_one(pat, base) { return true; }
                }
            }
            start = i + 1;
        }
        i++;
    }
    return false;
}

fn wanted(path: const u8[:]) -> bool {
    let rel = rel_path(path);
    let base = base_of(path);
    if state::search_inc.len > 0 && !glob_hit(state::search_inc, rel, base) { return false; }
    if state::search_exc.len > 0 && glob_hit(state::search_exc, rel, base) { return false; }
    return true;
}

// add_hit pushes "rel\tline\tsnippet" for the line a..b of the file at path.
fn add_hit(path: const u8[:], line: i32, text: const u8[:], a: i64, b: i64) {
    if search_n >= 200 { return; }
    var row: u8[>..] = [];
    let rel = rel_path(path);
    row.append(rel);
    row.push('\t');
    var num: u8[>..] = [];
    var d = line;
    if d == 0 { num.push('0'); }
    while d > 0 { num.push('0' + (d % 10) as u8); d = d / 10; }
    var r: i64 = num.len;
    while r > 0 { r--; row.push(num[r]); }
    row.push('\t');
    var i = a;
    while i < b && i < a + 90 {
        let c = text[i];
        if c == '\t' { row.push(' '); } else { row.push(c); }
        i++;
    }
    row.push('\n');
    search_rows.append(row);
    search_n++;
}

fn note_file(path: const u8[:]) {
    let rel = rel_path(path);
    files_done.push('\n');
    files_done.append(rel);
}

fn search_file(path: const u8[:]) {
    var buf: u8[>..] = [];
    if !read_file(path, buf) { return; }
    if buf.len > 400000 { return; }
    seen_files++;
    var found = false;
    var start: i64 = 0;
    var i: i64 = 0;
    var line: i32 = 1;
    while i <= buf.len && search_n < 200 {
        if i == buf.len || buf[i] == '\n' {
            if i > start {
                if has_q(buf, start, i) {
                    add_hit(path, line, buf, start, i);
                    found = true;
                }
            }
            start = i + 1;
            line++;
        }
        i++;
    }
    if found { note_file(path); }
}

fn push_dir(depth: i32, path: const u8[:]) {
    var r: u8[>..] = [];
    var d = depth;
    if d == 0 { r.push('0'); }
    while d > 0 { r.push('0' + (d % 10) as u8); d = d / 10; }
    r.push('\t');
    r.append(path);
    r.push('\n');
    queue.append(r);
}

fn scan_dir(depth: i32, dir: const u8[:]) {
    var names: u8[>..] = [];
    if !list_dir(dir, names) { return; }
    var start: i64 = 0;
    var i: i64 = 0;
    while i <= names.len {
        if i == names.len || names[i] == '\n' {
            if i > start && search_n < 200 && seen_files <= 600 && dirs_seen < 800 {
                let name = names[start..i];
                if name.len > 0 && name[0] != '.' {
                    let path = tree::child_path(dir, name);
                    if is_dir(path) {
                        if depth < 10 { dirs_seen++; push_dir(depth + 1, path); }
                    } else if looks_text(name) {
                        if wanted(path) { search_file(path); }
                    }
                }
            }
            start = i + 1;
        }
        i++;
    }
}

fn run_search() {
    search_rows.resize(0);
    files_done.resize(0);
    search_n = 0;
    seen_files = 0;
    queue.resize(0);
    dirs_seen = 0;
    if state::search_q.len == 0 { return; }
    var root: u8[>..] = [];
    if state::root.len > 0 { root.append(state::root); } else { root.append("."); }
    push_dir(0, root);
    var qi: i64 = 0;
    while qi < queue.len && search_n < 200 && seen_files <= 600 {
        if queue[qi] == '\n' { qi++; continue; }
        var depth: i32 = 0;
        while qi < queue.len && queue[qi] != '\t' {
            depth = depth * 10 + (queue[qi] as i32 - 48);
            qi++;
        }
        qi++;
        var dir: u8[>..] = [];
        while qi < queue.len && queue[qi] != '\n' { dir.push(queue[qi]); qi++; }
        scan_dir(depth, dir);
    }
}

// replace_one replaces every match of the query in buf with the replace text.
fn replace_one(buf: const u8[:], out: u8[>..]&) {
    var i: i64 = 0;
    let n = buf.len;
    while i < n {
        let m = match_at(buf, i, n);
        if m > 0 {
            out.append(state::search_rep);
            i = i + m as i64;
        } else {
            out.push(buf[i]);
            i++;
        }
    }
}

// replace_all rewrites the files of the results with the replacement text.
fn replace_all() {
    if state::search_q.len == 0 || state::search_rep.len == 0 { return; }
    var i: i64 = 0;
    var start: i64 = 0;
    while i <= files_done.len {
        if i == files_done.len || files_done[i] == '\n' {
            if i > start {
                var path: u8[>..] = [];
                if state::root.len > 0 { path.append(state::root); path.push('\\'); }
                var k = start;
                while k < i { path.push(files_done[k]); k++; }
                var buf: u8[>..] = [];
                if read_file(path, buf) && buf.len < 400000 {
                    var out: u8[>..] = [];
                    replace_one(buf, out);
                    if out.len != buf.len { write_file(path, out); }
                }
            }
            start = i + 1;
        }
        i++;
    }
    app::set_status("已替换全部");
    run_search();
}

// draw_fit draws text that stops with an ellipsis when it would overflow.
fn search_char(c: u16) {
    if c == 8 {
        if state::search_field == 0 && state::search_q.len > 0 { text::trim_utf8(&state::search_q); state::search_due = win::ticks() + 200; }
        else if state::search_field == 1 && state::search_rep.len > 0 { text::trim_utf8(&state::search_rep); }
        else if state::search_field == 2 && state::search_inc.len > 0 { text::trim_utf8(&state::search_inc); state::search_due = win::ticks() + 200; }
        else if state::search_field == 3 && state::search_exc.len > 0 { text::trim_utf8(&state::search_exc); state::search_due = win::ticks() + 200; }
        win::invalidate();
        return;
    }
    if c < 32 { return; }
    if state::search_field == 0 { text::push_char(&state::search_q, c); state::search_due = win::ticks() + 200; }
    else if state::search_field == 1 { text::push_char(&state::search_rep, c); }
    else if state::search_field == 2 { text::push_char(&state::search_inc, c); state::search_due = win::ticks() + 200; }
    else { text::push_char(&state::search_exc, c); state::search_due = win::ticks() + 200; }
    win::invalidate();
}

// open_search_row opens the file the hit at row i belongs to.
fn open_search_row(i: i32) {
    var k: i64 = 0;
    var start: i64 = 0;
    var idx: i32 = 0;
    while k <= search_rows.len {
        if k == search_rows.len || search_rows[k] == '\n' {
            if k > start && idx == i {
                var rel: u8[>..] = [];
                var q = start;
                while q < k && search_rows[q] != '\t' { rel.push(search_rows[q]); q++; }
                var path: u8[>..] = [];
                if rel.len > 1 && rel[1] == ':' {
                    path.append(rel);
                } else {
                    if state::root.len > 0 { path.append(state::root); path.push('\\'); }
                    path.append(rel);
                }
                app::open_path(path);
                return;
            }
            if k > start { idx++; }
            start = k + 1;
        }
        k++;
    }
}
