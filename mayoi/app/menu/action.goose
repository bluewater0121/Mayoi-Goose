// What each menu item does, by the command id it carries, the way Mayoi's
// run(id, win) dispatches.
namespace menu;

import ui.win;
import ui.theme;
import app.state;
import app.layout;
import app.overlay;
import app.input;
import app.sidebar;
import editor.text;
import editor.syntax;
import explore.tree;
import app.prefs.model;
import .model;

fn eq(a: const u8[:], b: const u8[:]) -> bool {
    if a.len != b.len { return false; }
    var i: i64 = 0;
    while i < a.len {
        if a[i] != b[i] { return false; }
        i++;
    }
    return true;
}

fn relay(cmd: const u8[:]) -> bool { return eq(cmd, "file.save"); }

// unfilled(i) says so, rather than pretending the command ran.
fn unfilled(i: i64) {
    var msg: u8[>..] = [];
    msg.append("尚未实现：");
    msg.append(menu::label_at(i));
    app::set_status(msg);
}

fn close_folder() {
    state::root.resize(0);
    state::root_name.resize(0);
    tree::rebuild();
    state::view = 1;
    app::layout();
    win::invalidate();
}

fn select_all() {
    if state::cur < 0 || state::docs.len == 0 { return; }
    let d .= state::docs[state::cur];
    d.sel_a = 0;
    d.sel_b = d.len;
    win::invalidate();
}

fn run(i: i64) {
    if i < 0 || i >= menu::items.len { return; }
    let it = menu::items[i];
    if it.flags == menu::SEPARATOR || it.flags == menu::DISABLED { return; }
    let id = menu::id_at(i);
    // file
    if eq(id, "file.new") { input::new_file(); return; }
    if eq(id, "file.openFolder") { input::open_folder_dialog(); return; }
    if eq(id, "file.openFolderWindow") { input::open_folder_dialog(); return; }
    if eq(id, "file.openRecent") { app::set_status("尚无最近打开的文件夹"); return; }
    if eq(id, "file.clearRecent") { app::set_status("最近打开记录已清除"); return; }
    if eq(id, "file.save") { input::save_file(); return; }
    if eq(id, "file.saveAs") { input::save_file(); return; }
    if eq(id, "file.saveAll") { input::save_file(); return; }
    if eq(id, "file.close") { input::close_tab(state::cur); return; }
    if eq(id, "file.closeFolder") { close_folder(); return; }
    if eq(id, "file.closeProject") { close_folder(); return; }
    if eq(id, "file.settings") { prefs::open_at(0); win::invalidate(); return; }
    if eq(id, "file.settingsJSON") { prefs::open_at(0); win::invalidate(); return; }
    if eq(id, "file.keybindings") { prefs::open_at(10); win::invalidate(); return; }
    if eq(id, "file.keybindingsJSON") { prefs::open_at(10); win::invalidate(); return; }
    if eq(id, "file.folderSettings") { prefs::open_at(0); win::invalidate(); return; }
    if eq(id, "plugin.manage") { prefs::open_at(8); win::invalidate(); return; }
    // edit
    if eq(id, "edit.undo") { text::undo_edit(); syntax::invalidate(); win::invalidate(); return; }
    if eq(id, "edit.redo") { text::redo_edit(); syntax::invalidate(); win::invalidate(); return; }
    if eq(id, "edit.copy") { input::copy(); return; }
    if eq(id, "edit.cut") { input::copy(); text::delete_range(state::cur, text::sel_min(state::cur), text::sel_max(state::cur), 0); win::invalidate(); return; }
    if eq(id, "edit.paste") { input::paste(); return; }
    if eq(id, "edit.selectAll") { select_all(); return; }
    if eq(id, "edit.find") { app::overlay_open(3); win::invalidate(); return; }
    if eq(id, "edit.replace") { app::overlay_open(3); win::invalidate(); return; }
    if eq(id, "edit.findNext") { app::overlay_open(3); win::invalidate(); return; }
    if eq(id, "edit.findPrev") { app::overlay_open(3); win::invalidate(); return; }
    // view
    if eq(id, "view.sidebar") { state::sidebar_open = !state::sidebar_open; app::layout(); win::invalidate(); return; }
    if eq(id, "view.explorer") { state::view = 1; state::sidebar_open = true; app::layout(); win::invalidate(); return; }
    if eq(id, "view.search") { state::view = 2; state::sidebar_open = true; app::layout(); win::invalidate(); return; }
    if eq(id, "view.scm") { state::view = 3; state::sidebar_open = true; app::layout(); win::invalidate(); return; }
    if eq(id, "view.sessions") { state::view = 4; state::sidebar_open = true; app::layout(); win::invalidate(); return; }
    if eq(id, "view.github") { state::view = 5; state::sidebar_open = true; app::layout(); win::invalidate(); return; }
    if eq(id, "view.terminal") { state::panel_open = !state::panel_open; app::layout(); win::invalidate(); return; }
    if eq(id, "view.newTerminal") { state::panel_open = true; app::layout(); win::invalidate(); return; }
    if eq(id, "view.zoomIn") { input::zoom(1); return; }
    if eq(id, "view.zoomOut") { input::zoom(-1); return; }
    if eq(id, "view.zoomReset") { input::zoom(0); return; }
    if eq(id, "view.appearance.light") { theme::set_light(); win::invalidate(); return; }
    if eq(id, "view.appearance.dark") { theme::set_dark(); win::invalidate(); return; }
    if eq(id, "view.appearance.system") { if theme::dark { theme::set_dark(); } else { theme::set_light(); } win::invalidate(); return; }
    if eq(id, "view.theme.mayoi") { theme::set_dark(); win::invalidate(); return; }
    // go
    if eq(id, "go.quickOpen") { app::overlay_open(2); win::invalidate(); return; }
    if eq(id, "go.commands") { app::overlay_open(1); win::invalidate(); return; }
    if eq(id, "go.line") { app::overlay_open(3); win::invalidate(); return; }
    if eq(id, "go.nextTab") { input::next_tab(1); return; }
    if eq(id, "go.prevTab") { input::next_tab(-1); return; }
    // git
    if eq(id, "git.refresh") { chrome::reload_scm(); win::invalidate(); return; }
    unfilled(i);
}
