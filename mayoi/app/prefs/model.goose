// The settings window's model: the fields of every section, their values,
// the section shown and the search over them. The window itself is painted
// in paint.goose, and what it answers to is in input.goose.
namespace prefs;

import std;
import ui.win;
import app.state;
import .data;

struct Fld { key: u8[..48], kind: i32, title: u8[..120], desc: u8[..720], minv: i32, maxv: i32,
             step: i32, def: u8[..80], sec: i32 }

struct Opt { key: u8[..48], idx: i32, label: u8[..64], raw: u8[..40] }

struct Val { key: u8[..48], v: u8[..400] }

let K_BOOL = 1; let K_ENUM = 2; let K_NUM = 3; let K_TEXT = 4;
let K_LIST = 5; let K_JSON = 6; let K_STYLES = 7;

var flds: Fld[>..] = [];
var opts: Opt[>..] = [];
var vals: Val[>..] = [];
var folder: Val[>..] = [];      // the keys the folder's .mayoi/settings.json chooses
var built = false;

// the window's own state
var open: bool = false;
var section: i32 = 0;
var query: u8[>..] = [];
var scroll: i32 = 0;
var max_scroll: i32 = 0;
var combo: i32 = -1;        // the field whose choices show, -1 for none
var edit: i32 = -1;         // the field whose text has the keyboard, -1 for none
var edit_buf: u8[>..] = [];
var hover: i32 = -1;        // the field under the pointer
var detail: i32 = -1;       // the plugin the Plugins page shows in detail, -1 for the list

let SEC_COUNT = 11;

fn sec_name(i: i32) -> const u8[:] {
    if i == 0 { return "外观"; }
    if i == 1 { return "字体"; }
    if i == 2 { return "编辑器"; }
    if i == 3 { return "Markdown"; }
    if i == 4 { return "终端"; }
    if i == 5 { return "差异与合并"; }
    if i == 6 { return "Git"; }
    if i == 7 { return "Vim"; }
    if i == 8 { return "插件"; }
    if i == 9 { return "通用"; }
    return "键盘快捷方式";
}

// sec_icon is the icon kind of app/icons for the section, as the reference
// has its own icon for each.
fn sec_icon(i: i32) -> i32 {
    if i == 0 { return 24; }
    if i == 1 { return 64; }
    if i == 2 { return 30; }
    if i == 3 { return 31; }
    if i == 4 { return 16; }
    if i == 5 { return 51; }
    if i == 6 { return 5; }
    if i == 7 { return 35; }
    if i == 8 { return 66; }
    if i == 9 { return 17; }
    return 50;
}

fn to_int(s: const u8[:]) -> i32 {
    var v: i32 = 0;
    var neg = false;
    var k: i64 = 0;
    if s.len > 0 && s[0] == '-' { neg = true; k = 1; }
    while k < s.len {
        let c = s[k];
        if c >= '0' && c <= '9' { v = v * 10 + (c as i32 - 48); }
        k++;
    }
    if neg { v = -v; }
    return v;
}

fn fill_key(dst: u8[..48]&, src: const u8[:]) {
    var k: i64 = 0;
    while k < src.len && dst.len < 44 { dst.push(src[k]); k++; }
}

fn fill_title(dst: u8[..120]&, src: const u8[:]) {
    var k: i64 = 0;
    while k < src.len && dst.len < 116 { dst.push(src[k]); k++; }
}

fn fill_desc(dst: u8[..720]&, src: const u8[:]) {
    var k: i64 = 0;
    while k < src.len && dst.len < 700 { dst.push(src[k]); k++; }
}

fn fill_label(dst: u8[..64]&, src: const u8[:]) {
    var k: i64 = 0;
    while k < src.len && dst.len < 60 { dst.push(src[k]); k++; }
}

fn fill_def(dst: u8[..80]&, src: const u8[:]) {
    var k: i64 = 0;
    while k < src.len && dst.len < 76 { dst.push(src[k]); k++; }
}

fn fill_raw(dst: u8[..40]&, src: const u8[:]) {
    var k: i64 = 0;
    while k < src.len && dst.len < 36 { dst.push(src[k]); k++; }
}

fn add_field(a: i64, b: i64) {
    var f: Fld = Fld { .. };
    var col: i32 = 0;
    var start: i64 = a;
    var k: i64 = a;
    while k <= b {
        if k == b || FIELDS[k] == '\t' {
            let piece = FIELDS[start..k];
            if col == 0 { fill_key(f.key, piece); }
            else if col == 1 { f.kind = to_int(piece); }
            else if col == 2 { fill_title(f.title, piece); }
            else if col == 3 { fill_desc(f.desc, piece); }
            else if col == 4 { f.minv = to_int(piece); }
            else if col == 5 { f.maxv = to_int(piece); }
            else if col == 6 { f.step = to_int(piece); }
            else if col == 7 { fill_def(f.def, piece); }
            else if col == 8 { f.sec = to_int(piece); }
            col++;
            start = k + 1;
        }
        k++;
    }
    flds.push(f);
}

fn add_opt(a: i64, b: i64) {
    var o: Opt = Opt { .. };
    var col: i32 = 0;
    var start: i64 = a;
    var k: i64 = a;
    while k <= b {
        if k == b || OPTS[k] == '\t' {
            let piece = OPTS[start..k];
            if col == 0 { fill_key(o.key, piece); }
            else if col == 1 { o.idx = to_int(piece); }
            else if col == 2 { fill_label(o.label, piece); }
            else if col == 3 { fill_raw(o.raw, piece); }
            col++;
            start = k + 1;
        }
        k++;
    }
    opts.push(o);
}

fn init() {
    if built { return; }
    built = true;
    var start: i64 = 0;
    var k: i64 = 0;
    while start <= FIELDS.len {
        if k == FIELDS.len || FIELDS[k] == '\n' {
            if k > start { add_field(start, k); }
            start = k + 1;
        }
        k++;
    }
    start = 0;
    k = 0;
    while start <= OPTS.len {
        if k == OPTS.len || OPTS[k] == '\n' {
            if k > start { add_opt(start, k); }
            start = k + 1;
        }
        k++;
    }
}

fn open_at(sec: i32) {
    init();
    open = true;
    section = sec;
    query.resize(0);
    scroll = 0;
    combo = -1;
    edit = -1;
    hover = -1;
    detail = -1;
}

fn close() {
    open = false;
    combo = -1;
    edit = -1;
    hover = -1;
    detail = -1;
}

fn same(a: const u8[:], b: const u8[:]) -> bool {
    if a.len != b.len { return false; }
    var k: i64 = 0;
    while k < a.len {
        if a[k] != b[k] { return false; }
        k++;
    }
    return true;
}

fn find_val(i: i32) -> i64 {
    var k: i64 = 0;
    let key = flds[i].key[0..flds[i].key.len];
    while k < vals.len {
        if same(vals[k].key[0..vals[k].key.len], key) { return k; }
        k++;
    }
    return -1;
}

// index_of is the field of a key, as settings.json names it, -1 for none.
fn index_of(key: const u8[:]) -> i32 {
    var i: i32 = 0;
    while i < flds.len as i32 {
        if same(flds[i].key[0..flds[i].key.len], key) { return i; }
        i++;
    }
    return -1;
}

fn bool_of(key: const u8[:]) -> bool {
    let i = index_of(key);
    if i < 0 { return false; }
    return is_true(i);
}

// folder_has says whether the folder's own settings.json chooses key.
fn folder_has(key: const u8[:]) -> bool {
    var k: i64 = 0;
    while k < folder.len {
        if same(folder[k].key[0..folder[k].key.len], key) { return true; }
        k++;
    }
    return false;
}

fn folder_mark(key: const u8[:], v: const u8[:]) {
    var k: i64 = 0;
    while k < folder.len {
        if same(folder[k].key[0..folder[k].key.len], key) {
            folder[k].v.resize(0);
            var j: i64 = 0;
            while j < v.len && j < 380 { folder[k].v.push(v[j]); j++; }
            return;
        }
        k++;
    }
    var n: Val = Val { .. };
    fill_key(n.key, key);
    var j: i64 = 0;
    while j < v.len && j < 380 { n.v.push(v[j]); j++; }
    folder.push(n);
}

fn folder_clear() { folder.resize(0); }

// value is what the field holds, or its default while nothing was chosen.
fn value(i: i32) -> const u8[:] {
    let k = find_val(i);
    if k >= 0 { return vals[k].v[0..vals[k].v.len]; }
    return flds[i].def[0..flds[i].def.len];
}

fn set(i: i32, v: const u8[:]) {
    let key = flds[i].key[0..flds[i].key.len];
    if folder_has(key) { folder_mark(key, v); }
    let k = find_val(i);
    if k >= 0 {
        vals[k].v.resize(0);
        var j: i64 = 0;
        while j < v.len && j < 380 { vals[k].v.push(v[j]); j++; }
        return;
    }
    var n: Val = Val { .. };
    fill_key(n.key, flds[i].key[0..flds[i].key.len]);
    var j: i64 = 0;
    while j < v.len && j < 380 { n.v.push(v[j]); j++; }
    vals.push(n);
}

fn set_num(i: i32, v: i32) {
    var buf: u8[>..] = [];
    var x = v;
    var neg = false;
    if x < 0 { neg = true; x = -x; }
    var ip = x / 100;
    var fp = x % 100;
    if ip == 0 { buf.push('0'); } else {
        var dig: u8[>..] = [];
        while ip > 0 { dig.push(('0' + (ip % 10) as u8)); ip = ip / 10; }
        var q = dig.len;
        while q > 0 { q--; buf.push(dig[q]); }
    }
    if fp > 0 {
        buf.push('.');
        if fp >= 10 { buf.push(('0' + (fp / 10) as u8)); } else { buf.push('0'); }
        let ones = fp % 10;
        if ones > 0 { buf.push(('0' + ones as u8)); }
    }
    if neg {
        var t: u8[>..] = [];
        t.push('-');
        var m: i64 = 0;
        while m < buf.len { t.push(buf[m]); m++; }
        set(i, t);
        return;
    }
    set(i, buf);
}

fn changed(i: i32) -> bool {
    let k = find_val(i);
    if k < 0 { return false; }
    return !same(vals[k].v[0..vals[k].v.len], flds[i].def[0..flds[i].def.len]);
}

fn reset(i: i32) {
    let k = find_val(i);
    if k >= 0 { vals[k].v.resize(0); }
}

fn is_true(i: i32) -> bool {
    let v = value(i);
    return same(v, "true");
}

fn toggle(i: i32) {
    if is_true(i) { set(i, "false"); } else { set(i, "true"); }
}

// num is the number of the field, in hundredths.
fn num(i: i32) -> i32 {
    let v = value(i);
    return parse_num(v);
}

fn parse_num(s: const u8[:]) -> i32 {
    var intpart: i32 = 0;
    var dec: i32 = 0;
    var neg = false;
    var k: i64 = 0;
    var dots = 0;
    if s.len > 0 && s[0] == '-' { neg = true; k = 1; }
    while k < s.len {
        let c = s[k];
        if c == '.' { dots = 1; }
        else if c >= '0' && c <= '9' {
            let d = c as i32 - 48;
            if dots == 0 { intpart = intpart * 10 + d; }
            else if dec == 0 { dec = d * 10; }
            else { dec = dec + d; }
        }
        k++;
    }
    var v = intpart * 100 + dec;
    if neg { v = -v; }
    return v;
}

// step_num moves the field's number by its step, kept between min and max.
fn step_num(i: i32, dir: i32) {
    var v = num(i);
    let st = if flds[i].step > 0 { flds[i].step } else { 100 };
    v = v + st * dir;
    if flds[i].minv != 0 || flds[i].maxv != 0 {
        if v < flds[i].minv { v = flds[i].minv; }
        if v > flds[i].maxv { v = flds[i].maxv; }
    }
    set_num(i, v);
}

// num_text is the field's number, as the box of it shows it.
var text_buf: u8[>..] = [];

fn num_text(i: i32) -> const u8[:] {
    text_buf.resize(0);
    var v = num(i);
    var neg = false;
    if v < 0 { neg = true; v = -v; }
    if neg { text_buf.push('-'); }
    var ip = v / 100;
    var fp = v % 100;
    if ip == 0 { text_buf.push('0'); } else {
        var dig: u8[>..] = [];
        while ip > 0 { dig.push(('0' + (ip % 10) as u8)); ip = ip / 10; }
        var q = dig.len;
        while q > 0 { q--; text_buf.push(dig[q]); }
    }
    if fp > 0 {
        text_buf.push('.');
        if fp >= 10 { text_buf.push(('0' + (fp / 10) as u8)); } else { text_buf.push('0'); }
        let ones = fp % 10;
        if ones > 0 { text_buf.push(('0' + ones as u8)); }
    }
    return text_buf[0..text_buf.len];
}

fn opt_count(i: i32) -> i32 {
    var n: i32 = 0;
    var k: i64 = 0;
    let key = flds[i].key[0..flds[i].key.len];
    while k < opts.len {
        if same(opts[k].key[0..opts[k].key.len], key) { n++; }
        k++;
    }
    return n;
}

fn opt_at(i: i32, idx: i32) -> i64 {
    var n: i32 = 0;
    var k: i64 = 0;
    let key = flds[i].key[0..flds[i].key.len];
    while k < opts.len {
        if same(opts[k].key[0..opts[k].key.len], key) {
            if n == idx { return k; }
            n++;
        }
        k++;
    }
    return -1;
}

fn opt_label(i: i32, idx: i32) -> const u8[:] {
    let k = opt_at(i, idx);
    if k < 0 { return ""; }
    return opts[k].label[0..opts[k].label.len];
}

fn opt_raw(i: i32, idx: i32) -> const u8[:] {
    let k = opt_at(i, idx);
    if k < 0 { return ""; }
    return opts[k].raw[0..opts[k].raw.len];
}

fn opt_index(i: i32) -> i32 {
    let v = value(i);
    var n: i32 = 0;
    var k: i64 = 0;
    let cnt = opt_count(i);
    while k < cnt as i64 {
        if same(opt_raw(i, n), v) { return n; }
        n++;
        k++;
    }
    return 0;
}

// label of the value the field holds right now.
fn value_label(i: i32) -> const u8[:] {
    if flds[i].kind == K_ENUM {
        return opt_label(i, opt_index(i));
    }
    return value(i);
}

// a field the search finds, by its title, its description and its key.
fn matches(i: i32) -> bool {
    if query.len == 0 { return true; }
    if has(flds[i].title[0..flds[i].title.len]) { return true; }
    if has(flds[i].desc[0..flds[i].desc.len]) { return true; }
    if has(flds[i].key[0..flds[i].key.len]) { return true; }
    return false;
}

fn has(hay: const u8[:]) -> bool {
    if hay.len < query.len { return false; }
    var a: i64 = 0;
    while a + query.len <= hay.len {
        var b: i64 = 0;
        var ok = true;
        while b < query.len {
            if low(hay[a + b]) != low(query[b]) { ok = false; break; }
            b++;
        }
        if ok { return true; }
        a++;
    }
    return false;
}

fn low(c: u8) -> u8 {
    if c >= 'A' && c <= 'Z' { return c + 32; }
    return c;
}

// count is how many fields of the section the search finds.
fn count(sec: i32) -> i32 {
    var n: i32 = 0;
    var i: i32 = 0;
    while i < flds.len as i32 {
        if flds[i].sec == sec && matches(i) { n++; }
        i++;
    }
    return n;
}

fn changed_in(sec: i32) -> i32 {
    var n: i32 = 0;
    var i: i32 = 0;
    while i < flds.len as i32 {
        if flds[i].sec == sec && changed(i) { n++; }
        i++;
    }
    return n;
}
