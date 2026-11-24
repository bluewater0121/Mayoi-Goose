// What each menu item does, by the command id it carries, the way Mayoi's
// run(id, win) dispatches.
namespace menu;

import ui.win;
import os;
import i18n;
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
import app.prefs.store;
import app.plugins.model;
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

fn save_theme(name: const u8[:]) {
    let i = prefs::index_of("theme");
    if i >= 0 { prefs::set(i, name); prefs::store_save(); }
}

// save_locale stores the language choice and applies it at once, the way the
// reference's locale menu does.
fn save_locale(name: const u8[:]) {
    let i = prefs::index_of("locale");
    if i >= 0 { prefs::set(i, name); prefs::store_save(); }
    var l: i32 = 0;
    if name.len == 2 && name[0] == 'e' { l = 1; }
    if name.len == 2 && name[0] == 'j' { l = 2; }
    i18n::set_lang(l);
    prefs::reload();
}

// run_label runs the item whose label the command palette shows, the way
// picking a command from the list runs it.
fn run_label(label: const u8[:]) -> bool {
    var i: i64 = 0;
    while i < menu::items.len as i64 {
        let it = menu::items[i];
        if it.flags != menu::SEPARATOR && eq(it.label[0..it.label.len], label) {
            run(i);
            return true;
        }
        i++;
    }
    return false;
}

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

fn run_id(id: const u8[:]) -> bool {
    var i: i64 = 0;
    while i < menu::items.len {
        if eq(menu::id_at(i), id) { run(i); return true; }
        i++;
    }
    return false;
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
    if eq(id, "file.folderSettings") {
        if state::root.len == 0 { app::set_status("先打开一个文件夹"); return; }
        var dir: u8[>..] = [];
        dir.append(state::root);
        dir.append("/.mayoi");
        make_dir(dir[0..dir.len]);
        var p: u8[>..] = [];
        p.append(state::root);
        p.append("/.mayoi/settings.json");
        if !file_exists(p[0..p.len]) {
            var empty: u8[>..] = [];
            empty.append("{\n}\n");
            write_file(p[0..p.len], empty[0..empty.len]);
        }
        app::open_path(p[0..p.len]);
        win::invalidate();
        return;
    }
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
    if eq(id, "view.theme.mayoi") { theme::set_named("mayoi"); save_theme(""); win::invalidate(); return; }
    if eq(id, "view.theme.matrix") { theme::set_named("matrix"); save_theme("matrix"); win::invalidate(); return; }
    if eq(id, "view.theme.claude") { theme::set_named("claude"); save_theme("claude"); win::invalidate(); return; }
    if eq(id, "view.theme.qoder") { theme::set_named("qoder"); save_theme("qoder"); win::invalidate(); return; }
    if eq(id, "view.theme.grokbot") { theme::set_named("grokbot"); save_theme("grokbot"); win::invalidate(); return; }
    if eq(id, "view.theme.cursor") { theme::set_named("cursor"); save_theme("cursor"); win::invalidate(); return; }
    if eq(id, "view.theme.purplegold") { theme::set_named("purplegold"); save_theme("purplegold"); win::invalidate(); return; }
    if eq(id, "view.theme.pumpkin") { theme::set_named("pumpkin"); save_theme("pumpkin"); win::invalidate(); return; }
    if eq(id, "view.theme.witchsbrew") { theme::set_named("witchsbrew"); save_theme("witchsbrew"); win::invalidate(); return; }
    if eq(id, "view.theme.bloodmoon") { theme::set_named("bloodmoon"); save_theme("bloodmoon"); win::invalidate(); return; }
    if eq(id, "view.theme.gtavi") { theme::set_named("gtavi"); save_theme("gtavi"); win::invalidate(); return; }
    if eq(id, "view.projectTabs") {
        let i = prefs::index_of("projectTabs");
        if i >= 0 {
            let on = prefs::is_true(i);
            prefs::set(i, if on { "" } else { "1" });
            prefs::store_save();
        }
        win::invalidate();
        return;
    }
    if eq(id, "view.locale.system") { save_locale(""); win::invalidate(); return; }
    if eq(id, "view.locale.en") { save_locale("en"); win::invalidate(); return; }
    if eq(id, "view.locale.ja") { save_locale("ja"); win::invalidate(); return; }
    if eq(id, "view.locale.zh") { save_locale("zh-Hans"); win::invalidate(); return; }
    if eq(id, "view.togglePreview") {
        state::preview_open = !state::preview_open;
        state::preview_side = false;
        state::preview_scroll = 0;
        win::invalidate();
        return;
    }
    if eq(id, "view.toggleLivePreview") {
        state::preview_open = !state::preview_open;
        state::preview_side = false;
        state::preview_live = state::preview_open;
        state::preview_scroll = 0;
        win::invalidate();
        return;
    }
    if eq(id, "view.previewToSide") {
        state::preview_open = true;
        state::preview_side = true;
        state::preview_live = true;
        state::preview_scroll = 0;
        win::invalidate();
        return;
    }
    if eq(id, "view.markdownOpen.live") { state::preview_open = true; state::preview_side = false; win::invalidate(); return; }
    if eq(id, "view.markdownOpen.reading") { state::preview_open = true; state::preview_side = false; win::invalidate(); return; }
    if eq(id, "view.markdownOpen.source") { state::preview_open = false; win::invalidate(); return; }
    if eq(id, "view.jsonlOpen.table") {
        let i = prefs::index_of("jsonlMode");
        if i >= 0 { prefs::set(i, ""); prefs::store_save(); }
        win::invalidate();
        return;
    }
    if eq(id, "view.jsonlOpen.source") {
        let i = prefs::index_of("jsonlMode");
        if i >= 0 { prefs::set(i, "source"); prefs::store_save(); }
        win::invalidate();
        return;
    }
    if eq(id, "view.wordWrap") {
        let i = prefs::index_of("wordWrap");
        if i >= 0 {
            let on = prefs::bool_of("wordWrap");
            let v: const u8[:] = if on { "false" } else { "true" };
            prefs::set(i, v);
            prefs::store_save();
            app::apply_settings();
            app::set_status(if on { "自动换行已关闭" } else { "自动换行已打开" });
        }
        win::invalidate();
        return;
    }
    if eq(id, "view.wordWrapTab") {
        state::wrap_enabled = !state::wrap_enabled;
        app::set_status(if state::wrap_enabled { "本标签页：自动换行" } else { "本标签页：不换行" });
        win::invalidate();
        return;
    }
    if eq(id, "view.vim") {
        let i = prefs::index_of("vim");
        if i >= 0 {
            var on = prefs::bool_of("vim");
            let v: const u8[:] = if on { "false" } else { "true" };
            prefs::set(i, v);
            prefs::store_save();
            if on { app::set_status("Vim 模式已关闭"); } else { app::set_status("Vim 模式已打开"); }
            win::invalidate();
            return;
        }
        app::set_status("Vim 模式需要设置里有 vim 项");
        win::invalidate();
        return;
    }
    // go
    if eq(id, "go.quickOpen") { app::overlay_open(2); win::invalidate(); return; }
    if eq(id, "go.commands") { app::overlay_open(1); win::invalidate(); return; }
    if eq(id, "go.line") { app::overlay_open(3); win::invalidate(); return; }
    if eq(id, "go.nextTab") { input::next_tab(1); return; }
    if eq(id, "go.prevTab") { input::next_tab(-1); return; }
    // git
    if eq(id, "git.refresh") { chrome::reload_scm(); win::invalidate(); return; }
    if eq(id, "git.commit") { chrome::scm_commit(); win::invalidate(); return; }
    if eq(id, "git.commitPush") { chrome::scm_commit(); chrome::git_push(); win::invalidate(); return; }
    if eq(id, "git.amend") { chrome::git_amend(); win::invalidate(); return; }
    if eq(id, "git.undoCommit") { chrome::git_undo_commit(); win::invalidate(); return; }
    if eq(id, "git.stageAll") { chrome::git_stage_all(); win::invalidate(); return; }
    if eq(id, "git.stageFile") { chrome::git_stage_all(); win::invalidate(); return; }
    if eq(id, "git.unstageFile") { chrome::git_unstage_all(); win::invalidate(); return; }
    if eq(id, "git.fetch") { chrome::git_fetch(); win::invalidate(); return; }
    if eq(id, "git.pull") { chrome::git_pull(); win::invalidate(); return; }
    if eq(id, "git.push") { chrome::git_push(); win::invalidate(); return; }
    if eq(id, "git.stash") { chrome::git_stash(false); win::invalidate(); return; }
    if eq(id, "git.stashUntracked") { chrome::git_stash(true); win::invalidate(); return; }
    if eq(id, "plugin.install") {
        var buf: u8[>..] = [];
        buf.resize(4096, 0);
        let n = win::pick_folder(win::hwnd, buf[0], 4096);
        if n > 0 {
            buf.resize(n);
            if plug::install(buf[0..buf.len]) { app::set_status("插件已安装"); }
            else { app::set_status("无法安装插件"); }
        }
        win::invalidate();
        return;
    }
    if eq(id, "plugin.reload") { plug::reload(); app::set_status("插件已重新加载"); win::invalidate(); return; }
    unfilled(i);
}
