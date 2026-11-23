// Icon names to masks, and the root folder's label.
namespace chrome;

import std;
import app.state;
import ui.theme;
import ui.win;
import editor.text;
import explore.tree;
fn icon_at(kind: i32, x: i32, y: i32, sz: i32, c: u32) {
    if sz <= 0 { return; }
    var i: i32 = -1;
    if kind == 1 { i = icons::MENU; }
    else if kind == 2 { i = icons::SIDEBAR; }
    else if kind == 3 { i = icons::FILES; }
    else if kind == 4 { i = icons::SEARCH; }
    else if kind == 5 { i = icons::BRANCH; }
    else if kind == 6 { i = icons::CLOCK; }
    else if kind == 7 { i = icons::CHEVRON_RIGHT; }
    else if kind == 8 { i = icons::CHEVRON_DOWN; }
    else if kind == 9 { i = icons::FILE; }
    else if kind == 10 { i = icons::FOLDER; }
    else if kind == 11 { i = icons::FOLDER_OPEN; }
    else if kind == 12 { i = icons::X; }
    else if kind == 13 { i = icons::PLUS; }
    else if kind == 14 { i = icons::REFRESH; }
    else if kind == 15 { i = icons::MORE; }
    else if kind == 16 { i = icons::TERMINAL; }
    else if kind == 17 { i = icons::SETTINGS; }
    else if kind == 18 { i = icons::CHEVRON_LEFT; }
    else if kind == 19 { i = icons::CHEVRONS_RIGHT; }
    else if kind == 20 { i = icons::CHEVRONS_LEFT; }
    else if kind == 21 { i = icons::TRASH; }
    else if kind == 22 { i = icons::MAXIMIZE; }
    else if kind == 23 { i = icons::MINIMIZE; }
    else if kind == 24 { i = icons::SPARKLES; }
    else if kind == 25 { i = icons::SEND; }
    else if kind == 26 { i = icons::STOP_SQUARE; }
    else if kind == 27 { i = icons::PENCIL; }
    else if kind == 28 { i = icons::MINUS; }
    else if kind == 29 { i = icons::LIST_TREE; }
    else if kind == 30 { i = icons::FILE_CODE; }
    else if kind == 31 { i = icons::FILE_TEXT; }
    else if kind == 32 { i = icons::FILE_JSON; }
    else if kind == 33 { i = icons::FILE_PLUS; }
    else if kind == 34 { i = icons::FOLDER_PLUS; }
    else if kind == 35 { i = icons::COMMAND; }
    else if kind == 36 { i = icons::WRAP; }
    else if kind == 37 { i = icons::HIGHLIGHT; }
    else if kind == 38 { i = icons::WHITESPACE; }
    else if kind == 39 { i = icons::TO_EDITOR; }
    else if kind == 40 { i = icons::INFO; }
    else if kind == 41 { i = icons::BUG; }
    else if kind == 42 { i = icons::CIRCLE_HELP; }
    else if kind == 43 { i = icons::CHECK; }
    else if kind == 44 { i = icons::UNDO; }
    else if kind == 45 { i = icons::OPEN_FILE; }
    else if kind == 46 { i = icons::FOLDER_GIT; }
    else if kind == 47 { i = icons::COPY; }
    else if kind == 48 { i = icons::EXTERNAL; }
    else if kind == 49 { i = icons::STAR; }
    else if kind == 50 { i = icons::KEYBOARD; }
    else if kind == 51 { i = icons::DIFF; }
    else if kind == 52 { i = icons::ROWS; }
    else if kind == 53 { i = icons::COLUMNS; }
    else if kind == 54 { i = icons::COLLAPSE; }
    else if kind == 55 { i = icons::UNFOLD; }
    else if kind == 56 { i = icons::COMMENT; }
    else if kind == 57 { i = icons::ACTIVITY; }
    else if kind == 58 { i = icons::POWER; }
    else if kind == 59 { i = icons::ARROW_UP; }
    else if kind == 60 { i = icons::ARROW_DOWN; }
    else if kind == 61 { i = icons::TAG; }
    else if kind == 62 { i = icons::BOX; }
    else if kind == 63 { i = icons::HASH; }
    else if kind == 64 { i = icons::TYPE; }
    else if kind == 65 { i = icons::BRACES; }
    else if kind == 66 { i = icons::BOX; }
    else if kind == 67 { i = icons::FUNCTION; }
    else if kind == 68 { i = icons::CONTEXT; }
    else if kind == 69 { i = icons::FILE_SEARCH; }
    else if kind == 70 { i = icons::WORD; }
    else if kind == 71 { i = icons::CASE; }
    else if kind == 72 { i = icons::REGEX; }
    else if kind == 73 { i = icons::REPLACE; }
    else if kind == 74 { i = icons::REPLACE_ALL; }
    else if kind == 75 { i = icons::LIST; }
    else if kind == 76 { i = icons::QUOTE; }
    else if kind == 77 { i = icons::MERGE; }
    else if kind == 78 { i = icons::COMMIT; }
    else if kind == 79 { i = icons::CHECKOUT; }
    else if kind == 80 { i = icons::CLOUD; }
    else if kind == 81 { i = icons::DOWNLOAD; }
    else if kind == 82 { i = icons::IMAGE; }
    else if kind == 83 { i = icons::PIN; }
    else if kind == 84 { i = icons::LOCK; }
    if i < 0 { return; }
    win::icon(i, x, y, sz, c);
}

fn root_caps() -> u8[>..] {
    var out: u8[>..] = [];
    var i: i64 = 0;
    while i < state::root_name.len {
        let c = state::root_name[i];
        if c >= 'a' && c <= 'z' { out.push(c - 32); } else { out.push(c); }
        i++;
    }
    return out;
}

