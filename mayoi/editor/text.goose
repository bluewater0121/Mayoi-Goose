// Documents as one arena of bytes: offsets into `state::arena`, an index of
// line starts, and the edits that walk backwards.
namespace text;

import std;
import os;
import app.state;
import ui.win;

let MAXPAYLOAD = 33554432;   // 32 MB of undo history

struct Edit {
    doc: i32, pos: i64, del: i64, ins: i64,
    dstoff: i64, insoff: i64, at: i64, kind: i32,
}
var undo: Edit[>..<] = [];
var redo: Edit[>..<] = [];
var payload: u8[>..] = [];

fn docref(i: i32) -> state::Doc& { return state::docs[i]; }
fn curdoc() -> state::Doc& { return state::docs[state::cur]; }

fn empty() -> u8[>..] { var e: u8[>..] = []; return e; }
fn imin(a: i64, b: i64) -> i64 { if a < b { return a; } return b; }
fn imax(a: i64, b: i64) -> i64 { if a > b { return a; } return b; }

fn eqs(a: const u8[:], b: const u8[:]) -> bool {
    if a.len != b.len { return false; }
    var i: i64 = 0;
    while i < a.len { if a[i] != b[i] { return false; } i++; }
    return true;
}

fn has_nl(b: const u8[:]) -> bool {
    var i: i64 = 0;
    while i < b.len { if b[i] == '\n' { return true; } i++; }
    return false;
}

// --- allocation --------------------------------------------------------------

fn ensure(i: i32, need: i64) {
    let d .= state::docs[i];
    if d.cap >= need { return; }
    var cap = d.cap;
    if cap == 0 { cap = 65536; }
    while cap < need { cap = cap * 2; }
    let start = state::arena.len;
    var j: i64 = 0;
    while j < cap { state::arena.push(0); j++; }
    if d.len > 0 { win::gs_memmove(state::arena[start], state::arena[d.off], d.len); }
    d.off = start;
    d.cap = cap;
}

fn payload_add(b: const u8[:]) -> i64 {
    if payload.len + b.len > MAXPAYLOAD { payload.resize(0); }
    let at = payload.len;
    var k: i64 = 0;
    while k < b.len { payload.push(b[k]); k++; }
    return at;
}

// --- documents ---------------------------------------------------------------

fn lang_of(name: const u8[:]) -> i32 {
    var rev: u8[..16] = [];
    var i: i64 = name.len;
    var dot = false;
    while i > 0 {
        i--;
        if name[i] == '.' { dot = true; break; }
        rev.push(name[i]);
    }
    if dot {
        var ext: u8[..16] = [];
        var k: i64 = rev.len;
        while k > 0 { k--; ext.push(rev[k]); }
        if eqs(ext, "go") { return 1; }
        if eqs(ext, "js") || eqs(ext, "ts") || eqs(ext, "jsx") || eqs(ext, "tsx") { return 2; }
        if eqs(ext, "py") { return 3; }
        if eqs(ext, "rs") { return 4; }
        if eqs(ext, "c") || eqs(ext, "h") || eqs(ext, "cc") || eqs(ext, "cpp") || eqs(ext, "hpp") { return 5; }
        if eqs(ext, "json") { return 6; }
        if eqs(ext, "md") { return 7; }
        if eqs(ext, "sh") || eqs(ext, "bash") || eqs(ext, "zsh") { return 8; }
        if eqs(ext, "html") || eqs(ext, "htm") || eqs(ext, "css") { return 9; }
        if eqs(ext, "yml") || eqs(ext, "yaml") || eqs(ext, "toml") { return 10; }
        if eqs(ext, "mod") || eqs(ext, "sum") { return 11; }
    }
    if eqs(name, "Makefile") { return 8; }
    return 0;
}

fn lang_name(l: i32) -> const u8[:] {
    if l == 1 { return "Go"; }
    if l == 2 { return "JavaScript"; }
    if l == 3 { return "Python"; }
    if l == 4 { return "Rust"; }
    if l == 5 { return "C"; }
    if l == 6 { return "JSON"; }
    if l == 7 { return "Markdown"; }
    if l == 8 { return "Shell"; }
    if l == 9 { return "HTML"; }
    if l == 10 { return "YAML"; }
    return "Plain Text";
}

fn add_doc(path: const u8[:], contents: const u8[:]) -> i32 {
    var d: state::Doc = state::Doc { .. };
    var k: i64 = 0;
    while k < path.len && k < 1000 { d.path.push(path[k]); k++; }
    var nstart: i64 = 0;
    var j: i64 = path.len;
    while j > 0 {
        if path[j-1] == '/' || path[j-1] == '\\' { nstart = j; break; }
        j--;
    }
    var m: i64 = nstart;
    while m < path.len && d.name.len < 150 { d.name.push(path[m]); m++; }
    d.lang = lang_of(d.name);
    state::docs.push(d);
    let idx = state::docs.len - 1;
    ensure(idx as i32, contents.len + 131072);
    let dd .= state::docs[idx];
    var p: i64 = 0;
    while p < contents.len {
        if contents[p] != '\r' {
            state::arena[dd.off + dd.len] = contents[p];
            dd.len = dd.len + 1;
        }
        p++;
    }
    dd.sel_a = 0; dd.sel_b = 0;
    return idx as i32;
}

fn open_file(path: const u8[:]) -> i32 {
    var content: u8[>..] = [];
    let ok = read_file(path, content);
    guard ok else { return -1; }
    return add_doc(path, content);
}

fn untitled() -> i32 {
    var e: u8[>..] = [];
    return add_doc("", e);
}

// --- line index --------------------------------------------------------------

fn reindex() {
    if state::docs.len == 0 { return; }
    let d .= curdoc();
    state::lines.resize(0);
    state::lines.push(0);
    var p: i64 = 0;
    while p < d.len {
        if state::arena[d.off + p] == '\n' { state::lines.push(p + 1); }
        p++;
    }
    state::lines_doc = state::cur;
    state::lines_len = d.len;
}

fn nlines() -> i32 {
    if state::docs.len == 0 { return 0; }
    if state::lines_doc != state::cur || state::lines_len != curdoc().len { reindex(); }
    return state::lines.len as i32;
}

fn line_col(p: i64) -> i32, i64 {
    if state::docs.len == 0 { return 0, 0; }
    reindex();
    var lo: i64 = 0;
    var hi = state::lines.len - 1;
    var l: i64 = 0;
    while lo <= hi {
        let mid = lo + (hi - lo) / 2;
        let a = state::lines[mid];
        if a <= p { l = mid; lo = mid + 1; } else { hi = mid - 1; }
    }
    return l as i32, p - state::lines[l];
}

fn line_start(l: i32) -> i64 {
    if state::docs.len == 0 { return 0; }
    if l < 0 { return 0; }
    if l >= nlines() { return curdoc().len; }
    return state::lines[l];
}

fn line_end(l: i32) -> i64 {
    if state::docs.len == 0 { return 0; }
    let d .= curdoc();
    if l + 1 >= nlines() { return d.len; }
    return state::lines[l + 1] - 1;
}

fn after_edit(pos: i64, structural: bool) {
    if structural { reindex(); return; }
    let d .= curdoc();
    if state::lines_len != d.len { reindex(); }
    else { state::lines_len = d.len; }
}

// --- editing -----------------------------------------------------------------

fn record(i: i32, pos: i64, del: i64, ins: i64, dst: i64, ins_o: i64, kind: i32) {
    if redo.len > 0 { redo.resize(0); }
    if kind == 1 && undo.len > 0 {
        let e = undo[undo.len - 1];
        if e.doc == i && e.del == 0 && e.pos + e.ins == pos &&
           e.insoff + e.ins == payload.len && e.at + 700 > win::ticks() {
            undo[undo.len - 1] = Edit { e.doc, e.pos, 0, e.ins + ins, 0, e.insoff,
                                        win::ticks(), 1 };
            return;
        }
    }
    undo.push(Edit { i, pos, del, ins, dst, ins_o, win::ticks(), kind });
    if undo.len > 300 { undo.resize(0); payload.resize(0); }
}

fn replace(i: i32, a: i64, b: i64, ins: const u8[:], kind: i32) {
    var x = a; var y = b;
    if x > y { x = b; y = a; }
    let d .= state::docs[i];
    ensure(i, d.len + ins.len - (y - x) + 1);
    let nd .= state::docs[i];
    var del_nl = false;
    if y > x { del_nl = has_nl(state::arena[nd.off + x .. nd.off + y]); }
    let ins_nl = has_nl(ins);
    let tail = nd.len - y;
    var delpay: i64 = -1;
    var inspay: i64 = -1;
    if y > x { delpay = payload_add(state::arena[nd.off + x .. nd.off + y]); }
    if ins.len > 0 { inspay = payload_add(ins); }
    if tail > 0 {
        win::gs_memmove(state::arena[nd.off + x + ins.len], state::arena[nd.off + y], tail);
    }
    var k: i64 = 0;
    while k < ins.len { state::arena[nd.off + x + k] = ins[k]; k++; }
    nd.len = nd.len + ins.len - (y - x);
    if y > x || ins.len > 0 { record(i, x, y - x, ins.len, delpay, inspay, kind); }
    nd.dirty = true;
    after_edit(x, del_nl || ins_nl);
}

fn insert_at(i: i32, pos: i64, b: const u8[:], kind: i32) { replace(i, pos, pos, b, kind); }

fn delete_range(i: i32, a: i64, b: i64, kind: i32) {
    var e: u8[>..] = [];
    replace(i, a, b, e, kind);
}

fn undo_edit() {
    if undo.len == 0 { return; }
    let e = undo[undo.len - 1];
    undo.resize(undo.len - 1);
    let d .= state::docs[e.doc];
    let tail = d.len - (e.pos + e.ins);
    ensure(e.doc, e.pos + e.del + tail);
    let nd .= state::docs[e.doc];
    if tail > 0 {
        win::gs_memmove(state::arena[nd.off + e.pos + e.del], state::arena[nd.off + e.pos + e.ins], tail);
    }
    var k: i64 = 0;
    while k < e.del { state::arena[nd.off + e.pos + k] = payload[e.dstoff + k]; k++; }
    nd.len = nd.len - e.ins + e.del;
    nd.dirty = true;
    nd.sel_a = e.pos; nd.sel_b = e.pos + e.del;
    redo.push(e);
    reindex();
}

fn redo_edit() {
    if redo.len == 0 { return; }
    let e = redo[redo.len - 1];
    redo.resize(redo.len - 1);
    let d .= state::docs[e.doc];
    let tail = d.len - (e.pos + e.del);
    ensure(e.doc, e.pos + e.ins + tail);
    let nd .= state::docs[e.doc];
    if tail > 0 {
        win::gs_memmove(state::arena[nd.off + e.pos + e.ins], state::arena[nd.off + e.pos + e.del], tail);
    }
    var k: i64 = 0;
    while k < e.ins { state::arena[nd.off + e.pos + k] = payload[e.insoff + k]; k++; }
    nd.len = nd.len - e.del + e.ins;
    nd.dirty = true;
    nd.sel_a = e.pos; nd.sel_b = e.pos + e.ins;
    undo.push(e);
    reindex();
}

// --- caret -------------------------------------------------------------------

fn sel_min(i: i32) -> i64 { let d .= state::docs[i]; return imin(d.sel_a, d.sel_b); }
fn sel_max(i: i32) -> i64 { let d .= state::docs[i]; return imax(d.sel_a, d.sel_b); }

fn set_caret(i: i32, pos: i64, keep_anchor: bool) {
    let d .= state::docs[i];
    var q = pos;
    if q < 0 { q = 0; }
    if q > d.len { q = d.len; }
    if !keep_anchor { d.sel_a = q; }
    d.sel_b = q;
}

fn col_cells(i: i32, pos: i64) -> i32 {
    let d .= state::docs[i];
    let a = line_start(line_col(pos));
    var x: i64 = a;
    var cells: i32 = 0;
    while x < pos {
        let c = state::arena[d.off + x];
        if c == '\t' { cells = cells + (4 - cells % 4); x++; }
        else if (c & 0xE0) == 0xC0 { cells++; x += 2; }
        else if (c & 0xF0) == 0xE0 { cells += 2; x += 3; }
        else if (c & 0xF8) == 0xF0 { cells += 2; x += 4; }
        else { cells++; x++; }
    }
    return cells;
}

fn pos_at_col(i: i32, line: i32, col: i32) -> i64 {
    let d .= state::docs[i];
    let a = line_start(line);
    let b = line_end(line);
    var p = a;
    var c: i32 = 0;
    while p < b && c < col {
        let ch = state::arena[d.off + p];
        if ch == '\t' { c = c + (4 - c % 4); p++; }
        else if (ch & 0xE0) == 0xC0 { c++; p += 2; }
        else if (ch & 0xF0) == 0xE0 { c += 2; p += 3; }
        else if (ch & 0xF8) == 0xF0 { c += 2; p += 4; }
        else { c++; p++; }
    }
    return p;
}

fn save_doc(i: i32) -> bool {
    let d .= state::docs[i];
    if d.path.len == 0 { return false; }
    let ok = write_file(d.path, state::arena[d.off .. d.off + d.len]);
    if ok { d.dirty = false; }
    return ok;
}





