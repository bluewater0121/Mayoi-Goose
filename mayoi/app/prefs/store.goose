// The settings file: the same settings.json the reference keeps in its
// user data folder, written as fields change and read at the next start.
namespace prefs;

import std;
import os;
import app.state;
import .model;

fn join2(a: const u8[:], b: const u8[:]) -> u8[>..] {
    var s: u8[>..] = [];
    var i: i64 = 0;
    while i < a.len { s.push(a[i]); i++; }
    if s.len > 0 && s[s.len - 1] != '\\' && s[s.len - 1] != '/' { s.push('\\'); }
    var k: i64 = 0;
    while k < b.len { s.push(b[k]); k++; }
    return s;
}

fn app_data_dir() -> u8[>..] {
    var base: u8[>..] = [];
    if !env("APPDATA", base) || base.len == 0 {
        base.resize(0);
        env("USERPROFILE", base);
        var b2 = join2(base[0..base.len], "AppData\\Roaming");
        base = copy(b2);
    }
    return join2(base[0..base.len], "Mayoi");
}

fn store_path() -> u8[>..] {
    var d = app_data_dir();
    return join2(d[0..d.len], "settings.json");
}

fn ws(c: u8) -> bool { return c == ' ' || c == '\t' || c == '\r' || c == '\n'; }

fn skip_ws(s: const u8[:], from: i64) -> i64 {
    var i = from;
    while i < s.len && ws(s[i]) { i++; }
    return i;
}

// read_json_string reads the string at s[i] (its quote), unescaped into
// out, and answers where the closing quote ends.
fn read_json_string(s: const u8[:], i0: i64, out: u8[>..]&) -> i64 {
    var i = i0;
    if i < s.len && s[i] == '"' { i++; }
    while i < s.len {
        let c = s[i];
        if c == '"' { return i + 1; }
        if c == '\\' && i + 1 < s.len {
            i++;
            let e = s[i];
            if e == 'n' { out.push('\n'); }
            else if e == 't' { out.push('\t'); }
            else if e == 'r' { out.push('\r'); }
            else { out.push(e); }
            i++;
            continue;
        }
        out.push(c);
        i++;
    }
    return i;
}

// read_raw copies the object or array at s[i] as its own text, counted by
// nesting so the quotes inside do not end it.
fn read_raw(s: const u8[:], i0: i64, out: u8[>..]&) -> i64 {
    var i = i0;
    var depth: i32 = 0;
    var instr = false;
    while i < s.len {
        let c = s[i];
        out.push(c);
        if instr {
            if c == '\\' && i + 1 < s.len { i++; out.push(s[i]); }
            else if c == '"' { instr = false; }
        } else {
            if c == '"' { instr = true; }
            else if c == '{' || c == '[' { depth++; }
            else if c == '}' || c == ']' {
                depth--;
                if depth <= 0 { return i + 1; }
            }
        }
        i++;
    }
    return i;
}

fn read_token(s: const u8[:], i0: i64, out: u8[>..]&) -> i64 {
    var i = i0;
    while i < s.len && s[i] != ',' && s[i] != '}' && s[i] != ']' && !ws(s[i]) {
        out.push(s[i]);
        i++;
    }
    return i;
}

fn plain(i: i32) -> bool {
    let k = flds[i].kind;
    return k == K_BOOL || k == K_NUM || k == K_TEXT || k == K_ENUM;
}

fn apply_key(key: const u8[:], val: const u8[:]) {
    let i = index_of(key);
    if i < 0 { return; }
    set(i, val);
}

// store_load reads settings.json into the fields, over their defaults.
fn store_load() {
    init();
    var p = store_path();
    if !file_exists(p[0..p.len]) { return; }
    var src: u8[>..] = [];
    if !read_file(p[0..p.len], src) { return; }
    var i = skip_ws(src[0..src.len], 0);
    if i >= src.len || src[i] != '{' { return; }
    i++;
    while i < src.len {
        i = skip_ws(src[0..src.len], i);
        if i >= src.len || src[i] == '}' { return; }
        if src[i] != '"' { return; }
        var key: u8[>..] = [];
        i = read_json_string(src[0..src.len], i, key);
        i = skip_ws(src[0..src.len], i);
        if i >= src.len || src[i] != ':' { return; }
        i = skip_ws(src[0..src.len], i + 1);
        if i >= src.len { return; }
        var val: u8[>..] = [];
        if src[i] == '"' {
            i = read_json_string(src[0..src.len], i, val);
        } else if src[i] == '{' || src[i] == '[' {
            i = read_raw(src[0..src.len], i, val);
        } else {
            i = read_token(src[0..src.len], i, val);
        }
        apply_key(key[0..key.len], val[0..val.len]);
        i = skip_ws(src[0..src.len], i);
        if i < src.len && src[i] == ',' { i++; continue; }
        if i < src.len && src[i] == '}' { return; }
    }
}

fn quote(b: u8[>..]&, s: const u8[:]) {
    b.push('"');
    var i: i64 = 0;
    while i < s.len {
        let c = s[i];
        if c == '"' || c == '\\' { b.push('\\'); b.push(c); }
        else if c == '\n' { b.push('\\'); b.push('n'); }
        else if c == '\r' { b.push('\\'); b.push('r'); }
        else if c == '\t' { b.push('\\'); b.push('t'); }
        else { b.push(c); }
        i++;
    }
    b.push('"');
}

fn folder_path() -> u8[>..] {
    var p: u8[>..] = [];
    p.append(state::root);
    p.append("/.mayoi/settings.json");
    return p;
}

// folder_load reads the folder's own .mayoi/settings.json over the
// person's settings, and remembers the keys it chose, as the reference's
// folderPrefs does.
fn folder_load() {
    init();
    folder_clear();
    if state::root.len == 0 { return; }
    let p = folder_path();
    if !file_exists(p[0..p.len]) { return; }
    var src: u8[>..] = [];
    if !read_file(p[0..p.len], src) { return; }
    var i = skip_ws(src[0..src.len], 0);
    if i >= src.len || src[i] != '{' { return; }
    i++;
    while i < src.len {
        i = skip_ws(src[0..src.len], i);
        if i >= src.len || src[i] == '}' { return; }
        if src[i] != '"' { return; }
        var key: u8[>..] = [];
        i = read_json_string(src[0..src.len], i, key);
        i = skip_ws(src[0..src.len], i);
        if i >= src.len || src[i] != ':' { return; }
        i = skip_ws(src[0..src.len], i + 1);
        if i >= src.len { return; }
        var val: u8[>..] = [];
        if src[i] == '"' { i = read_json_string(src[0..src.len], i, val); }
        else if src[i] == '{' || src[i] == '[' { i = read_raw(src[0..src.len], i, val); }
        else { i = read_token(src[0..src.len], i, val); }
        apply_key(key[0..key.len], val[0..val.len]);
        folder_mark(key[0..key.len], val[0..val.len]);
        i = skip_ws(src[0..src.len], i);
        if i < src.len && src[i] == ',' { i++; continue; }
        if i < src.len && src[i] == '}' { return; }
    }
}

// folder_save writes the keys the folder chooses into its own file.
fn folder_save() {
    if state::root.len == 0 || folder.len == 0 { return; }
    var dir: u8[>..] = [];
    dir.append(state::root);
    dir.append("/.mayoi");
    make_dir(dir[0..dir.len]);
    var b: u8[>..] = [];
    b.append("{\n");
    var k: i64 = 0;
    while k < folder.len {
        if k > 0 { b.append(",\n"); }
        b.append("  ");
        quote(b, folder[k].key[0..folder[k].key.len]);
        b.append(": ");
        let v = folder[k].v[0..folder[k].v.len];
        let f = index_of(folder[k].key[0..folder[k].key.len]);
        if f >= 0 && plain(f) && (flds[f].kind == K_TEXT || flds[f].kind == K_ENUM) {
            quote(b, v);
        } else {
            var j: i64 = 0;
            while j < v.len { b.push(v[j]); j++; }
        }
        k++;
    }
    b.append("\n}\n");
    let p = folder_path();
    write_file(p[0..p.len], b[0..b.len]);
}

// store_save writes every setting that differs from its default, as the
// reference writes the preferences it changed.
fn store_save() {
    init();
    var dir = app_data_dir();
    make_dir(dir[0..dir.len]);
    var b: u8[>..] = [];
    b.append("{\n");
    var first = true;
    var i: i32 = 0;
    while i < flds.len as i32 {
        if changed(i) && !folder_has(flds[i].key[0..flds[i].key.len]) {
            let v = value(i);
            let kind = flds[i].kind;
            var skip = false;
            if kind == K_LIST || kind == K_JSON || kind == K_STYLES { if v.len == 0 { skip = true; } }
            if !skip {
                if !first { b.append(",\n"); }
                first = false;
                b.append("  ");
                quote(b, flds[i].key[0..flds[i].key.len]);
                b.append(": ");
                if plain(i) && (kind == K_TEXT || kind == K_ENUM) {
                    quote(b, v);
                } else {
                    var k: i64 = 0;
                    while k < v.len { b.push(v[k]); k++; }
                }
            }
        }
        i++;
    }
    if !first { b.push('\n'); }
    b.append("}\n");
    var p = store_path();
    write_file(p[0..p.len], b[0..b.len]);
    folder_save();
}

