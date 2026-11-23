// The window chrome: shared text helpers and the icon names.
namespace chrome;

import std;
import app.state;
import ui.theme;
import ui.win;
import editor.text;
import explore.tree;
fn ch(f: u64, x: i32, cy: i32, s: const u8[:], c: u32) {
    let h = win::th(f);
    win::text_at(f, x, cy - h / 2, s, c);
}

fn chw(f: u64, s: const u8[:]) -> i32 { return win::measure(f, s); }

