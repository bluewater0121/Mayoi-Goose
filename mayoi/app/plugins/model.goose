// The plugins Mayoi has installed: their manifests read from
// ~/.mayoi/plugins, the enabled ones, and the folder they live in. The
// Plugins page of the settings window shows them, and their own settings
// are kept in settings.json under "plugins", as the reference keeps them.
namespace plug;

import std;
import os;
import ui.win;
import app.state;
import app.prefs.model;

struct P {
    name: u8[..64], title: u8[..96], ver: u8[..32], desc: u8[..420],
    author: u8[..64], dir: u8[..1024], enabled: bool,
}

var items: P[>..] = [];
var loaded = false;
var confirm: i32 = -1;     // the row waiting for a second click to remove
var note: u8[..160] = [];  // what the page says of the last action, "" for nothing

fn set_note(msg: const u8[:]) {
    note.resize(0);
    var i: i64 = 0;
    while i < msg.len && i < 150 { note.push(msg[i]); i++; }
}

fn join2(a: const u8[:], b: const u8[:]) -> u8[>..] {
    var s: u8[>..] = [];
    var i: i64 = 0;
    while i < a.len { s.push(a[i]); i++; }
    if s.len > 0 && s[s.len - 1] != '\\' && s[s.len - 1] != '/' { s.push('\\'); }
    var k: i64 = 0;
    while k < b.len { s.push(b[k]); k++; }
    return s;
}

fn home_dir() -> u8[>..] {
    var h: u8[>..] = [];
    if !env("USERPROFILE", h) { env("HOME", h); }
    return h;
}

fn dir_path() -> u8[>..] {
    var h = home_dir();
    var a = join2(h[0..h.len], ".mayoi");
    return join2(a[0..a.len], "plugins");
}

fn ensure_dir() {
    var d = dir_path();
    make_dir(d[0..d.len]);
}

fn fill(dst: u8[..1024]&, src: const u8[:]) {
    var i: i64 = 0;
    while i < src.len && dst.len < 1000 { dst.push(src[i]); i++; }
}

fn fill40(dst: u8[..420]&, src: const u8[:]) {
    var i: i64 = 0;
    while i < src.len && dst.len < 400 { dst.push(src[i]); i++; }
}

fn fill32(dst: u8[..32]&, src: const u8[:]) {
    var i: i64 = 0;
    while i < src.len && dst.len < 28 { dst.push(src[i]); i++; }
}

fn fill20(dst: u8[..96]&, src: const u8[:]) {
    var i: i64 = 0;
    while i < src.len && dst.len < 88 { dst.push(src[i]); i++; }
}

fn fill10(dst: u8[..64]&, src: const u8[:]) {
    var i: i64 = 0;
    while i < src.len && dst.len < 58 { dst.push(src[i]); i++; }
}

fn ws(c: u8) -> bool { return c == ' ' || c == '\t' || c == '\r' || c == '\n'; }

// field_str finds "key": "value" in a manifest, and appends the value.
fn field_str(src: const u8[:], key: const u8[:], out: u8[>..]&) -> bool {
    var i: i64 = 0;
    while i < src.len {
        if src[i] == '"' {
            var j = i + 1;
            var k: i64 = 0;
            var ok = true;
            while k < key.len {
                if j >= src.len || src[j] != key[k] { ok = false; break; }
                j++;
                k++;
            }
            if ok && j < src.len && src[j] == '"' {
                j++;
                while j < src.len && ws(src[j]) { j++; }
                if j < src.len && src[j] == ':' { j++; } else { i = j; continue; }
                while j < src.len && ws(src[j]) { j++; }
                if j < src.len && src[j] == '"' {
                    j++;
                    while j < src.len {
                        let c = src[j];
                        if c == '"' { return true; }
                        if c == '\\' && j + 1 < src.len {
                            j++;
                            let e = src[j];
                            if e == 'n' { out.push('\n'); } else { out.push(e); }
                            j++;
                            continue;
                        }
                        out.push(c);
                        j++;
                    }
                    return true;
                }
            }
        }
        i++;
    }
    return false;
}

fn field_bool(src: const u8[:], key: const u8[:], def: bool) -> bool {
    var i: i64 = 0;
    while i < src.len {
        if src[i] == '"' {
            var j = i + 1;
            var k: i64 = 0;
            var ok = true;
            while k < key.len {
                if j >= src.len || src[j] != key[k] { ok = false; break; }
                j++;
                k++;
            }
            if ok && j < src.len && src[j] == '"' {
                j++;
                while j < src.len && ws(src[j]) { j++; }
                if j < src.len && src[j] == ':' { j++; }
                while j < src.len && ws(src[j]) { j++; }
                if j + 4 <= src.len {
                    let t = src[j .. j + 4];
                    if t[0] == 't' && t[1] == 'r' && t[2] == 'u' && t[3] == 'e' { return true; }
                    if t[0] == 'f' && t[1] == 'a' && t[2] == 'l' && t[3] == 's' { return false; }
                }
            }
        }
        i++;
    }
    return def;
}

// settings_json is the "plugins" object of settings.json as it stands.
fn settings_json() -> const u8[:] {
    let i = prefs::index_of("plugins");
    if i < 0 { return ""; }
    return prefs::value(i);
}

fn false_at(j: const u8[:], from: i64) -> bool {
    var e = from;
    let stop = if from + 60 < j.len { from + 60 } else { j.len };
    while e + 5 <= stop {
        if j[e] == 'f' && j[e + 1] == 'a' && j[e + 2] == 'l' && j[e + 3] == 's'
            && j[e + 4] == 'e' { return true; }
        e++;
    }
    return false;
}

// disabled says the settings turn a plugin off: "name": { "enabled": false }.
fn disabled(name: const u8[:]) -> bool {
    let j = settings_json();
    var i: i64 = 0;
    while i + name.len + 3 <= j.len {
        if j[i] == '"' {
            var k = i + 1;
            var m: i64 = 0;
            var ok = true;
            while m < name.len {
                if k >= j.len || j[k] != name[m] { ok = false; break; }
                k++;
                m++;
            }
            if ok && k < j.len && j[k] == '"' {
                if false_at(j, k + 1) { return true; }
                return false;
            }
        }
        i++;
    }
    return false;
}

fn state_json() -> u8[>..] {
    var b: u8[>..] = [];
    b.append("{");
    var first = true;
    var i: i32 = 0;
    while i < items.len as i32 {
        if !items[i].enabled {
            if !first { b.append(", "); }
            first = false;
            b.push('"');
            var k: i64 = 0;
            while k < items[i].name.len { b.push(items[i].name[k]); k++; }
            b.append("\": {\"enabled\": false}");
        }
        i++;
    }
    b.append("}");
    return b;
}

fn save_state() {
    let pi = prefs::index_of("plugins");
    if pi >= 0 {
        var j = state_json();
        prefs::set(pi, j[0..j.len]);
    }
    prefs::store_save();
}

fn add_plugin(folder: const u8[:]) {
    var d = dir_path();
    var dir = join2(d[0..d.len], folder);
    if !is_dir(dir[0..dir.len]) { return; }
    var pj = join2(dir[0..dir.len], "plugin.json");
    var src: u8[>..] = [];
    if !read_file(pj[0..pj.len], src) { return; }
    var it: P = P { .. };
    var nm: u8[>..] = [];
    if !field_str(src[0..src.len], "name", nm) || nm.len == 0 {
        fill10(it.name, folder);
    } else {
        fill10(it.name, nm[0..nm.len]);
    }
    var ti: u8[>..] = [];
    if field_str(src[0..src.len], "displayName", ti) && ti.len > 0 {
        fill20(it.title, ti[0..ti.len]);
    } else {
        fill20(it.title, it.name[0..it.name.len]);
    }
    var ve: u8[>..] = [];
    if field_str(src[0..src.len], "version", ve) { fill32(it.ver, ve[0..ve.len]); }
    var de: u8[>..] = [];
    if field_str(src[0..src.len], "description", de) { fill40(it.desc, de[0..de.len]); }
    var au: u8[>..] = [];
    if field_str(src[0..src.len], "author", au) { fill10(it.author, au[0..au.len]); }
    fill(it.dir, dir[0..dir.len]);
    it.enabled = !disabled(it.name[0..it.name.len]);
    items.push(it);
}

fn load() {
    if loaded { return; }
    loaded = true;
    items.resize(0);
    ensure_dir();
    var d = dir_path();
    var nb: u8[>..] = [];
    if !list_dir(d[0..d.len], nb) { return; }
    var start: i64 = 0;
    var i: i64 = 0;
    while start <= nb.len {
        if i == nb.len || nb[i] == '\n' {
            if i > start { add_plugin(nb[start..i]); }
            start = i + 1;
        }
        i++;
    }
}

fn reload() {
    loaded = false;
    confirm = -1;
    load();
}

fn count() -> i32 { return items.len as i32; }
fn name(i: i32) -> const u8[:] { return items[i].name[0..items[i].name.len]; }
fn title(i: i32) -> const u8[:] { return items[i].title[0..items[i].title.len]; }
fn ver(i: i32) -> const u8[:] { return items[i].ver[0..items[i].ver.len]; }
fn desc(i: i32) -> const u8[:] { return items[i].desc[0..items[i].desc.len]; }
fn author(i: i32) -> const u8[:] { return items[i].author[0..items[i].author.len]; }
fn enabled(i: i32) -> bool { return items[i].enabled; }

fn toggle(i: i32) {
    items[i].enabled = !items[i].enabled;
    save_state();
    plug::set_note(if items[i].enabled { "插件已启用" } else { "插件已停用" });
}

// copy_from copies a folder's files, and the folders in it, over, as
// xcopy does: the tree of a plugin can be deep and wide, and a script
// handles it in one step.
fn copy_from(src: const u8[:], dst: const u8[:]) -> bool {
    var cmd: u8[>..] = [];
    cmd.append("cmd.exe /c xcopy /E /I /Y /Q \"");
    var i: i64 = 0;
    while i < src.len { cmd.push(src[i]); i++; }
    cmd.append("\" \"");
    var k: i64 = 0;
    while k < dst.len { cmd.push(dst[k]); k++; }
    cmd.push('"');
    win::run_silent(cmd[0..cmd.len]);
    return is_dir(dst);
}

fn base_name(p: const u8[:]) -> u8[>..] {
    var i = p.len;
    while i > 0 {
        i--;
        if p[i] == '\\' || p[i] == '/' {
            var out: u8[>..] = [];
            var k = i + 1;
            while k < p.len { out.push(p[k]); k++; }
            return out;
        }
    }
    var out2: u8[>..] = [];
    var k: i64 = 0;
    while k < p.len { out2.push(p[k]); k++; }
    return out2;
}

// install copies a plugin folder into the plugins folder, and lists it.
fn install(src: const u8[:]) -> bool {
    var pj = join2(src, "plugin.json");
    var man: u8[>..] = [];
    if !read_file(pj[0..pj.len], man) {
        plug::set_note("不是插件文件夹：没有 plugin.json");
        return false;
    }
    var nm: u8[>..] = [];
    if !field_str(man[0..man.len], "name", nm) || nm.len == 0 {
        nm = base_name(src);
    }
    var d = dir_path();
    var dest = join2(d[0..d.len], nm[0..nm.len]);
    if !copy_from(src, dest[0..dest.len]) {
        plug::set_note("无法安装插件");
        return false;
    }
    var label: u8[>..] = [];
    label.append("已安装插件 ");
    label.append(nm[0..nm.len]);
    plug::set_note(label[0..label.len]);
    reload();
    return true;
}

fn delete_tree(p: const u8[:]) -> bool {
    var cmd: u8[>..] = [];
    cmd.append("cmd.exe /c rmdir /S /Q \"");
    var i: i64 = 0;
    while i < p.len { cmd.push(p[i]); i++; }
    cmd.push('"');
    win::run_silent(cmd[0..cmd.len]);
    return !is_dir(p);
}

fn remove(i: i32) {
    if confirm != i { confirm = i; plug::set_note("再次点击删除该插件"); return; }
    confirm = -1;
    let d = items[i].dir[0..items[i].dir.len];
    if !delete_tree(d) { plug::set_note("无法删除插件"); return; }
    var k: i32 = i;
    while k + 1 < items.len as i32 { items[k] = items[k + 1]; k++; }
    items.resize(items.len - 1);
    save_state();
    plug::set_note("插件已删除");
}

fn open_folder() {
    ensure_dir();
    var d = dir_path();
    var cmd: u8[>..] = [];
    cmd.append("cmd.exe /c start \"\" \"");
    var k: i64 = 0;
    while k < d.len { cmd.push(d[k]); k++; }
    cmd.push('"');
    win::run_silent(cmd[0..cmd.len]);
}




