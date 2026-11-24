// A local control channel for the editor: JSON-RPC over a loopback socket,
// shaped like an MCP server, so a script can type, click, run a menu item and
// grab the editor area without guessing where the mouse is.
namespace mcp;

import std;
import json;
import ui.win;
import app.state;
import app.input;
import editor.text;
import editor.vim;
import app.menu.action;
import app.prefs.input;
import app.prefs.model;
import app.sidebar;
import app.overlay;

fn add_str(out: u8[>..]&, s: const u8[:]) { json::format_string(out, s); }

fn reply(out: u8[>..]&, id: i64, text: const u8[:], failed: bool) {
    out.append("{\"jsonrpc\":\"2.0\",\"id\":");
    json::format_int(out, id);
    out.append(",\"result\":{\"content\":[{\"type\":\"text\",\"text\":");
    add_str(out, text);
    out.append("}],\"isError\":");
    out.append(if failed { "true" } else { "false" });
    out.append("}}\n");
}

fn reply_plain(out: u8[>..]&, id: i64, body: const u8[:]) {
    out.append("{\"jsonrpc\":\"2.0\",\"id\":");
    json::format_int(out, id);
    out.append(",\"result\":");
    out.append(body);
    out.append("}\n");
}

fn reply_error(out: u8[>..]&, id: i64, msg: const u8[:]) {
    out.append("{\"jsonrpc\":\"2.0\",\"id\":");
    json::format_int(out, id);
    out.append(",\"error\":{\"code\":-32603,\"message\":");
    add_str(out, msg);
    out.append("}}\n");
}

fn type_char(c: u16) {
    if state::overlay != 0 { input::overlay_char(c); return; }
    if state::focus == 2 && state::panel_open && state::panel_tab == 2 {
        input::char_typed(c);
        return;
    }
    if state::ren_active { input::rename_char(c); return; }
    if state::view >= 2 && state::sidebar_open && state::focus == 1 {
        chrome::sidebar_char(c);
        return;
    }
    if prefs::open { prefs::typed(c); return; }
    input::char_typed(c);
}

fn type_bytes(b: const u8[:]) {
    if state::focus == 0 && state::cur >= 0 && vim::on() { vim::sync(); vim::set_mode(1); }
    input::ime_into_field(b);
}

fn key_vk(name: const u8[:], n: i64) -> i32 {
    if n > 0 { return n as i32; }
    if name.len == 0 { return 0; }
    if name == "backspace" { return 8; }
    if name == "tab" { return 9; }
    if name == "enter" { return 13; }
    if name == "escape" || name == "esc" { return 27; }
    if name == "space" { return 32; }
    if name == "left" { return 37; }
    if name == "up" { return 38; }
    if name == "right" { return 39; }
    if name == "down" { return 40; }
    if name == "delete" { return 46; }
    if name == "home" { return 36; }
    if name == "end" { return 35; }
    if name.len == 1 {
        let c = name[0];
        if c >= 'a' && c <= 'z' { return (c - 32) as i32; }
        if c >= 'A' && c <= 'Z' { return c as i32; }
    }
    return 0;
}

fn state_text(out: u8[>..]&) {
    out.append("{\"doc\":");
    json::format_int(out, state::cur);
    out.append(",\"docs\":");
    json::format_int(out, state::docs.len);
    out.append(",\"focus\":");
    json::format_int(out, state::focus);
    out.append(",\"w\":");
    json::format_int(out, state::W);
    out.append(",\"h\":");
    json::format_int(out, state::H);
    out.append(",\"bytes\":");
    var bytes: i64 = 0;
    if state::cur >= 0 && state::cur < state::docs.len as i32 { bytes = state::docs[state::cur].len; }
    json::format_int(out, bytes);
    out.append(",\"caret\":");
    var caret: i64 = 0;
    if state::cur >= 0 && state::cur < state::docs.len as i32 { caret = state::docs[state::cur].sel_b; }
    json::format_int(out, caret);
    out.append(",\"line\":");
    var line: i64 = 0;
    var col: i64 = 0;
    if state::cur >= 0 && state::cur < state::docs.len as i32 {
        let l2, c2 = text::line_col(state::docs[state::cur].sel_b);
        line = l2;
        col = text::col_cells(state::cur, state::docs[state::cur].sel_b) as i64;
    }
    json::format_int(out, line);
    out.append(",\"col\":");
    json::format_int(out, col);
    out.append(",\"vim\":");
    json::format_int(out, vim::mode_of());
    out.append(",\"menu\":");
    out.append(if state::menu_open { "true" } else { "false" });
    out.append("}");
}

fn call_tool(out: u8[>..]&, id: i64, name: const u8[:], args: json::Node?) {
    var text: u8[>..] = [];
    if name == "state" {
        state_text(text);
        reply(out, id, text, false);
        return;
    }
    if name == "type_text" {
        let t, ok = json::as_string(json::member(args, "text"));
        if !ok { reply(out, id, "missing text", true); return; }
        type_bytes(t);
        win::invalidate();
        reply(out, id, "ok", false);
        return;
    }
    if name == "key" {
        let kname, _ = json::as_string(json::member(args, "key"));
        let vkn, _ = json::as_i64(json::member(args, "vk"));
        let ctrl, _ = json::as_bool(json::member(args, "ctrl"));
        let shift, _ = json::as_bool(json::member(args, "shift"));
        let alt, _ = json::as_bool(json::member(args, "alt"));
        let vk = key_vk(kname, vkn);
        if vk <= 0 { reply(out, id, "unknown key", true); return; }
        let used = input::key(vk, ctrl, shift, alt);
        win::invalidate();
        reply(out, id, if used { "ok" } else { "ignored" }, false);
        return;
    }
    if name == "click" {
        let x, _ = json::as_i64(json::member(args, "x"));
        let y, _ = json::as_i64(json::member(args, "y"));
        input::mouse_down(x as i32, y as i32, 0);
        input::mouse_up(x as i32, y as i32);
        win::invalidate();
        reply(out, id, "ok", false);
        return;
    }
    if name == "menu" {
        let mid, _ = json::as_string(json::member(args, "id"));
        if mid.len == 0 { reply(out, id, "missing id", true); return; }
        let ok = menu::run_id(mid);
        win::invalidate();
        reply(out, id, if ok { "ok" } else { "unknown menu id" }, !ok);
        return;
    }
    if name == "screenshot" {
        let region, _ = json::as_string(json::member(args, "region"));
        var x: i32 = state::ed_left;
        var y: i32 = state::ed_top;
        var w: i32 = state::ed_right - state::ed_left;
        var h: i32 = state::ed_bot - state::ed_top;
        if region == "window" || region.len == 0 {
            if region != "editor" {
                x = 0; y = 0; w = 0; h = 0;
            }
        }
        if w <= 0 || h <= 0 { x = 0; y = 0; w = 0; h = 0; }
        var p: u8[..512] = [0; 512];
        let n = win::capture(p[0], 512, x as i64, y as i64, w as i64, h as i64);
        var pn: i64 = 0;
        while pn < 511 && p[pn] != 0 { pn++; }
        if n <= 0 { reply(out, id, "capture failed", true); return; }
        reply(out, id, p[0..pn], false);
        return;
    }
    if name == "doc_text" {
        var d: u8[>..] = [];
        if state::cur >= 0 && state::cur < state::docs.len as i32 {
            let doc = state::docs[state::cur];
            var k: i64 = 0;
            while k < doc.len { d.push(state::arena[doc.off + k]); k++; }
        }
        reply(out, id, d, false);
        return;
    }
    reply(out, id, "unknown tool", true);
}

fn tools(out: u8[>..]&) {
    out.append("[");
    out.append("{\"name\":\"state\",\"description\":\"Caret, document size and mode\",\"inputSchema\":{\"type\":\"object\",\"properties\":{}}},");
    out.append("{\"name\":\"type_text\",\"description\":\"Insert text at the caret, IME-free\",\"inputSchema\":{\"type\":\"object\",\"properties\":{\"text\":{\"type\":\"string\"}},\"required\":[\"text\"]}},");
    out.append("{\"name\":\"key\",\"description\":\"Send a key, e.g. backspace\",\"inputSchema\":{\"type\":\"object\",\"properties\":{\"key\":{\"type\":\"string\"},\"vk\":{\"type\":\"number\"},\"ctrl\":{\"type\":\"boolean\"},\"shift\":{\"type\":\"boolean\"},\"alt\":{\"type\":\"boolean\"}}}},");
    out.append("{\"name\":\"click\",\"description\":\"Click at app coordinates\",\"inputSchema\":{\"type\":\"object\",\"properties\":{\"x\":{\"type\":\"number\"},\"y\":{\"type\":\"number\"}},\"required\":[\"x\",\"y\"]}},");
    out.append("{\"name\":\"menu\",\"description\":\"Run a menu item by command id\",\"inputSchema\":{\"type\":\"object\",\"properties\":{\"id\":{\"type\":\"string\"}},\"required\":[\"id\"]}},");
    out.append("{\"name\":\"screenshot\",\"description\":\"Save a BMP of the editor area\",\"inputSchema\":{\"type\":\"object\",\"properties\":{\"region\":{\"type\":\"string\"}}}},");
    out.append("{\"name\":\"doc_text\",\"description\":\"Current document text\",\"inputSchema\":{\"type\":\"object\",\"properties\":{}}}");
    out.append("]");
}

fn serve(line: const u8[:], out: u8[>..]&) {
    var doc: json::Node[>..] = [];
    var decoded: u8[>..] = [];
    let root, err = json::parse(line, doc, decoded);
    if !root { reply_error(out, 0, err); return; }
    var id: i64 = -1;
    let idn, has_id = json::as_i64(json::member(root, "id"));
    if has_id { id = idn; }
    let method, _ = json::as_string(json::member(root, "method"));
    if method == "initialize" {
        reply_plain(out, id, "{\"protocolVersion\":\"2024-11-05\",\"capabilities\":{\"tools\":{}},\"serverInfo\":{\"name\":\"mayoi\",\"version\":\"0.1\"}}");
        return;
    }
    if method == "notifications/initialized" || method == "notifications/cancelled" { return; }
    if method == "ping" { reply_plain(out, id, "{}"); return; }
    if method == "tools/list" {
        var body: u8[>..] = [];
        body.append("{\"tools\":");
        tools(body);
        body.append("}");
        reply_plain(out, id, body);
        return;
    }
    if method == "tools/call" {
        let params = json::member(root, "params");
        let nm, _ = json::as_string(json::member(params, "name"));
        let args = json::member(params, "arguments");
        call_tool(out, id, nm, args);
        return;
    }
    reply_error(out, id, "unknown method");
}
