import std;
import os;
import ui.win;
import app.state;
import app.layout;
import app.view;
import app.overlay;
import ui.theme;
import editor.text;
import editor.syntax;
import explore.tree;
import app.draw;
import app.icons;
import app.titlebar;
import app.sidebar;
import app.tabs;
import app.status;
import editor.editor;
import editor.vim;
import app.layout;
import app.view;
import app.overlay;
import app.input;
import app.menu.input;
import app.menu.paint;
import app.prefs.input;
import app.prefs.model;
import app.prefs.store;
import app.plugins.model;
import ui.icons;

fn main() {
    win::setdpi();
    let sys_dpi = win::get_dpi_for_system();
    if sys_dpi >= 72 { win::dpi = sys_dpi as i32; }
    theme::set_dark();
    guard win::open("Mayoi", state::px(1262), state::px(811)) else {
        return;
    }
    app::layout();
    var rc: win::Rect = win::Rect { 0, 0, 0, 0 };
    win::get_client_rect(win::hwnd, rc);
    var wrc: win::Rect = win::Rect { 0, 0, 0, 0 };
    win::get_window_rect(win::hwnd, wrc);
    win::resize_frame(rc.r, rc.b);
    prefs::init();
    prefs::store_load();
    app::apply_settings();
    plug::load();

    let argv = args();
    if argv.len > 1 {
        var a: u8[..1024] = [];
        var k: i64 = 0;
        while k < argv[1].len && k < 1000 { a.push(argv[1][k]); k++; }
        if is_dir(a) {
            app::set_root(a);
            if argv.len > 2 {
                var b: u8[..1024] = [];
                var j: i64 = 0;
                while j < argv[2].len && j < 1000 { b.push(argv[2][j]); j++; }
                var abs: u8[>..] = [];
                if b.len > 0 && (b[0] == '/' || b[0] == '\\' || (b.len > 1 && b[1] == ':')) {
                    abs.append(b);
                } else {
                    if state::root.len > 0 { abs.append(state::root); abs.push('/'); }
                    abs.append(b);
                }
                app::open_path(abs);
            }
        } else {
            app::open_path(a);
            var cut: i64 = 0;
            var j: i64 = a.len;
            while j > 0 {
                if a[j-1] == '/' || a[j-1] == '\\' { cut = j - 1; break; }
                j--;
            }
            if cut > 0 { app::set_root(a[0..cut]); }
        }
    } else {
        var cwd: u8[>..] = [];
        cwd.append("C:\\work\\prj\\winhx");
        app::set_root(cwd);
    }

    app::term.resize(0);
    app::term.append("PS C:\\work\\prj\\winhx> mayoi .\n");
    app::term.append("Mayoi 0.23.3 — 迷い\n");

    var msg: win::Msg = win::Msg { .. };
    while win::get_message(msg, 0, 0, 0) > 0 {
        if msg.m == 0x010D || msg.m == 0x010F { win::ime_pos(win::hwnd, state::ime_x, state::ime_y); }
        win::translate_message(msg);
        if msg.m == 0x0012 { break; }                  // WM_QUIT
        if msg.m == 0x0010 { win::quit = true; break; } // WM_CLOSE
        if msg.m == 0x8002 {                            // WM_SIZE (posted)
            let sw = (msg.lp & 0xFFFF) as i32;
            let sh = ((msg.lp >> 16) & 0xFFFF) as i32;
            // a minimized window reports 0x0; keeping the frame lets the
            // restore paint the layout again instead of a black surface
            if sw > 0 && sh > 0 {
                // back from the taskbar DWM needs the frame recomputed before it
                // will show anything again, otherwise the client stays black
                win::set_window_pos(win::hwnd, 0, 0, 0, 0, 0,
                    0x0002 | 0x0001 | 0x0004 | 0x0020);
                win::reset_frame();
                var cr2: win::Rect = win::Rect { 0, 0, 0, 0 };
                win::get_client_rect(win::hwnd, cr2);
                win::resize_frame(cr2.r, cr2.b);
                app::layout();
                app::paint();
                win::present(win::frame_w, win::frame_h);
            }
            win::invalidate();
            continue;
        }
        if msg.m == 0x8003 {                            // WM_ACTIVATE (posted)
            win::invalidate();
            continue;
        }
        if msg.m == 0x8004 {                            // WM_SHOWWINDOW (posted)
            win::invalidate();
            continue;
        }
        if msg.m == 0x8005 {                            // WM_DPICHANGED (posted)
            let nd = (msg.wp & 0xFFFF) as i32;
            if nd >= 72 { win::dpi = nd; }
            var cr3: win::Rect = win::Rect { 0, 0, 0, 0 };
            win::get_client_rect(win::hwnd, cr3);
            win::resize_frame(cr3.r, cr3.b);
            app::layout();
            win::invalidate();
            continue;
        }
        if msg.m == 0x000F {                            // WM_PAINT
            if win::dc == 0 {
                var cr: win::Rect = win::Rect { 0, 0, 0, 0 };
                win::get_client_rect(win::hwnd, cr);
                win::resize_frame(cr.r, cr.b);
            }
            app::paint();
            win::present(win::frame_w, win::frame_h);
            continue;
        }
        if msg.m == 0x0014 { continue; }                // WM_ERASEBKGND
        if msg.m == 0x0100 {                            // WM_KEYDOWN
            let vk = (msg.wp & 0xFFFF) as i32;
            let ctrl = ((win::get_keystate(0x11) as i32) & 0x8000) != 0;
            let shift = ((win::get_keystate(0x10) as i32) & 0x8000) != 0;
            let alt = ((win::get_keystate(0x12) as i32) & 0x8000) != 0;
            if menu::key(vk) { win::invalidate(); continue; }
            let used = input::key(vk, ctrl, shift, alt);
            if used { win::invalidate(); }
            continue;
        }
        if msg.m == 0x0102 {                            // WM_CHAR
            if state::ime_composing || win::ticks() < state::ime_skip_until { continue; }
            if (msg.wp as u16) < 32 { continue; }       // control keys, not text
            if prefs::open { prefs::typed(msg.wp as u16); win::invalidate(); continue; }
            if state::menu_open { continue; }
            if state::ren_active {
                input::rename_char(msg.wp as u16);
                win::invalidate();
                continue;
            }
            if state::view >= 2 && state::sidebar_open && state::focus == 1 {
                chrome::sidebar_char(msg.wp as u16);
                win::invalidate();
                continue;
            }
            if state::overlay != 0 {
                input::overlay_char(msg.wp as u16);
                win::invalidate();
                continue;
            }
            if vim::on() && state::focus == 0 && state::cur >= 0 && vim::mode_of() != 1 {
                vim::char(msg.wp as u16);
                win::invalidate();
                continue;
            }
            input::char_typed(msg.wp as u16);
            win::invalidate();
            continue;
        }
        if msg.m == 0x010F {                            // WM_IME_COMPOSITION
            var ib: u8[>..] = [];
            ib.resize(1024, 0);
            if (msg.lp & 0x800) != 0 {
                let n = win::ime_result(win::hwnd, ib[0], 1024);
                state::ime_composing = false;
                state::ime_comp.resize(0);
                if n > 0 { input::typed(ib[0..n]); }
                state::ime_skip_until = win::ticks() + 400;
                win::invalidate();
            } else if (msg.lp & 0x8) != 0 {
                let n = win::ime_comp(win::hwnd, ib[0], 1024);
                state::ime_composing = true;
                state::ime_comp.resize(0);
                var k: i64 = 0;
                while k < n { state::ime_comp.push(ib[k]); k++; }
                win::invalidate();
            }
        }
        if msg.m == 0x0286 {                            // WM_IME_CHAR
            // the composed text already arrives once as WM_IME_COMPOSITION's
            // GCS_RESULTSTR; taking this too would insert every Chinese twice
            continue;
        }
        if msg.m == 0x0200 {                            // WM_MOUSEMOVE
            let mx = win::mx((msg.lp & 0xFFFF) as i32);
            let my = win::my(((msg.lp >> 16) & 0xFFFF) as i32);
            if state::menu_open { menu::hover(mx, my); win::invalidate(); continue; }
            input::mouse_move(mx, my);
            continue;
        }
        if msg.m == 0x0201 {                            // WM_LBUTTONDOWN
            let mx = win::mx((msg.lp & 0xFFFF) as i32);
            let my = win::my(((msg.lp >> 16) & 0xFFFF) as i32);
            if state::menu_open { if menu::press(mx, my) { win::invalidate(); continue; } }
            if mx >= state::px(12) && mx < state::px(46) && my < state::title_h {
                menu::open();
                win::invalidate();
                continue;
            }
            input::mouse_down(mx, my, 0);
            win::invalidate();
            continue;
        }
        if msg.m == 0x0202 {                            // WM_LBUTTONUP
            input::mouse_up(win::mx((msg.lp & 0xFFFF) as i32), win::my(((msg.lp >> 16) & 0xFFFF) as i32));
            continue;
        }
        if msg.m == 0x0204 {                            // WM_RBUTTONDOWN
            input::right_down(win::mx((msg.lp & 0xFFFF) as i32), win::my(((msg.lp >> 16) & 0xFFFF) as i32));
            continue;
        }
        if msg.m == 0x020A {                            // WM_MOUSEWHEEL
            let delta = ((msg.wp >> 16) & 0xFFFF) as i32;
            let signed = if delta > 0x7FFF { delta - 0x10000 } else { delta };
            if prefs::open { prefs::wheel(signed / 120); win::invalidate(); continue; }
            if menu::wheel(signed / 120) { continue; }
            if input::wheel_sidebar(signed / 120) { continue; }
            input::wheel(signed / 120);
            continue;
        }
        if msg.m == 0x0113 {                            // WM_TIMER
            win::dispatch(msg);
            state::blink = !state::blink;
            win::invalidate();
            continue;
        }
        win::translate_message(msg);
        win::dispatch_message(msg);
    }
}


























