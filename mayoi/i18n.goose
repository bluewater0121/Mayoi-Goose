// The message translations: the reference's Chinese message, its English
// and Japanese, looked up by the Chinese text the clone draws. The catalog
// is data.goose, generated from locales/zh-Hans.json, en.json and ja.json.
namespace i18n;

import std;
import i18n_data;

var lang: i32 = 0;          // 0 zh-Hans, 1 en, 2 ja
var ready = false;

var zo: i32[>..] = [];      // where each row's Chinese starts, and how long
var zl: i32[>..] = [];
var eo: i32[>..] = [];
var el: i32[>..] = [];
var jo: i32[>..] = [];
var jl: i32[>..] = [];
var heads: i32[>..] = [];   // open addressing, 1 + row, 0 empty
let HBITS = 12;
let HSIZE = 4096;

fn hash(s: const u8[:]) -> u64 {
    var h: u64 = 1469598103934665603;
    var i: i64 = 0;
    while i < s.len {
        h = (h ^ s[i] as u64) * 1099511628211;
        i++;
    }
    return h;
}

fn eq(a: const u8[:], b: const u8[:]) -> bool {
    if a.len != b.len { return false; }
    var i: i64 = 0;
    while i < a.len { if a[i] != b[i] { return false; } i++; }
    return true;
}

fn at(off: i32, len: i32) -> const u8[:] {
    let a: i64 = off as i64;
    let b: i64 = a + len as i64;
    return i18n_data::DATA[a..b];
}

fn init() {
    if ready { return; }
    ready = true;
    heads.resize(HSIZE, 0);
    var line: i64 = 0;
    var k: i64 = 0;
    var f0: i64 = 0;
    var f1: i64 = -1;
    var f2: i64 = -1;
    var t0: i64 = 0;
    var t1: i64 = -1;
    var t2: i64 = -1;
    var row: i64 = 0;
    while k <= i18n_data::DATA.len {
        let end = k == i18n_data::DATA.len || i18n_data::DATA[k] == '\n';
        if !end && i18n_data::DATA[k] == '\t' {
            if f1 < 0 { f1 = k; t1 = k; } else { f2 = k; t2 = k; }
        }
        if end {
            if k > f0 {
                var a: i64 = f0;
                var b: i64 = if f1 >= 0 { f1 } else { k };
                zo.push(a as i32); zl.push((b - a) as i32);
                var c: i64 = if f1 >= 0 { f1 + 1 } else { k };
                var d: i64 = if f2 >= 0 { f2 } else { k };
                eo.push(c as i32); el.push((d - c) as i32);
                var e: i64 = if f2 >= 0 { f2 + 1 } else { k };
                jo.push(e as i32); jl.push((k - e) as i32);
                var h = hash(i18n_data::DATA[a..b]);
                var slot = (h & (HSIZE - 1)) as i64;
                while heads[slot] != 0 { slot = (slot + 1) & (HSIZE - 1); }
                heads[slot] = (row + 1) as i32;
                row++;
            }
            f0 = k + 1;
            f1 = -1;
            f2 = -1;
            line++;
        }
        k++;
    }
}

// find the row whose Chinese is s, or -1.
fn find(s: const u8[:]) -> i64 {
    var h = hash(s);
    var slot = (h & (HSIZE - 1)) as i64;
    while heads[slot] != 0 {
        let i = (heads[slot] - 1) as i64;
        if eq(at(zo[i], zl[i]), s) { return i; }
        slot = (slot + 1) & (HSIZE - 1);
    }
    return -1;
}

var buf: u8[..1200];

// t is the message in the language chosen, or the Chinese itself when the
// catalog has none. A label the clone draws with a trailing ellipsis is looked
// up without it, and the ellipsis put back on the translation.
fn t(s: const u8[:]) -> const u8[:] {
    if lang == 0 || s.len == 0 { return s; }
    init();
    let i = find(s);
    if i >= 0 {
        if lang == 2 { return at(jo[i], jl[i]); }
        return at(eo[i], el[i]);
    }
    if s.len > 3 && s[s.len - 3] == 0xE2 && s[s.len - 2] == 0x80 && s[s.len - 1] == 0xA6 {
        let base = s[0..s.len - 3];
        let j = find(base);
        if j >= 0 {
            let r = if lang == 2 { at(jo[j], jl[j]) } else { at(eo[j], el[j]) };
            buf.resize(0);
            var k: i64 = 0;
            while k < r.len { buf.push(r[k]); k++; }
            buf.push(0xE2); buf.push(0x80); buf.push(0xA6);
            return buf[0..buf.len];
        }
    }
    return s;
}

fn set_lang(i: i32) {
    if i < 0 || i > 2 { lang = 0; return; }
    lang = i;
}
