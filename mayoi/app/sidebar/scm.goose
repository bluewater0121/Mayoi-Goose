// The source control view: the branch, the commit box, and what git status
// says about the root; a folder outside a work tree offers to become one.
namespace chrome;

import std;
import os;
import app.state;
import ui.theme;
import ui.win;
import app.layout;

var scm_rows: u8[>..] = [];     // newline separated "XY path"
var scm_n: i32 = 0;
var scm_err: bool = false;
var scm_repo: bool = false;
var scm_branch: u8[>..] = [];
var scm_looked: bool = false;

fn has_word(hay: const u8[:], needle: const u8[:]) -> bool {
    if needle.len == 0 || hay.len < needle.len { return false; }
    var i: i64 = 0;
    while i + needle.len as i64 <= hay.len {
        var k: i64 = 0;
        var hit = true;
        while k < needle.len {
            if hay[i + k] != needle[k] { hit = false; break; }
            k++;
        }
        if hit { return true; }
        i++;
    }
    return false;
}

fn valid_status(c: u8) -> bool {
    if c == 'M' || c == 'A' || c == 'D' || c == 'R' || c == 'C' { return true; }
    if c == '?' || c == '!' || c == 'U' { return true; }
    if c == ' ' { return true; }
    return false;
}

fn append_root(dst: u8[>..]&, tail: const u8[:]) {
    if state::root.len > 0 { dst.append(state::root); }
    dst.append(tail);
}

fn read_branch() {
    scm_branch.resize(0);
    var hp: u8[>..] = [];
    append_root(hp, "/.git/HEAD");
    var head: u8[>..] = [];
    if !read_file(hp, head) { return; }
    // "ref: refs/heads/main" when on a branch
    var start: i64 = 0;
    var i: i64 = 0;
    while i < head.len {
        if head[i] == ' ' { start = i + 1; }
        if head[i] == '\n' { break; }
        i++;
    }
    var k = start;
    var last: i64 = start;
    while k < i {
        if head[k] == '/' { last = k + 1; }
        k++;
    }
    k = last;
    while k < i && head[k] != '\n' && head[k] != '\r' { scm_branch.push(head[k]); k++; }
}

// git_exe is the Git to run. Mayoi does not need Git on PATH: this machine
// keeps it in C:\bin\mingit, so that copy is used when it is there.
fn git_exe() -> const u8[:] {
    if file_exists("C:\\bin\\mingit\\cmd\\git.exe") { return "\"C:\\bin\\mingit\\cmd\\git.exe\""; }
    return "git";
}

fn run_git(cmd: const u8[:]) -> i64 {
    var out: u8[>..] = [];
    out.resize(65536, 0);
    var cwd: u8[>..] = [];
    if state::root.len > 0 { cwd.append(state::root); } else { cwd.append("."); }
    return win::gs_run_cmd(cmd[0], cmd.len as i64, out[0], 65536, cwd[0], cwd.len as i64);
}

fn git_status_raw(out: u8[>..]&) {
    var cmd: u8[>..] = [];
    cmd.append(git_exe());
    cmd.append(" -c core.quotepath=false status --porcelain -uno");
    var buf: u8[>..] = [];
    buf.resize(65536, 0);
    var cwd: u8[>..] = [];
    if state::root.len > 0 { cwd.append(state::root); } else { cwd.append("."); }
    let n = win::gs_run_cmd(cmd[0], cmd.len as i64, buf[0], 65536, cwd[0], cwd.len as i64);
    var j: i64 = 0;
    while j < n && j < 65000 { out.push(buf[j]); j++; }
}

fn git_verb(args: const u8[:], done: const u8[:]) {
    var cmd: u8[>..] = [];
    cmd.append(git_exe());
    cmd.append(" ");
    cmd.append(args);
    let rc = run_git(cmd);
    reload_scm();
    if rc == 0 { app::set_status(done); } else { app::set_status("Git 命令失败，请查看输出面板"); }
}

fn git_stage_all() { git_verb("add -A", "已暂存所有更改"); }
fn git_unstage_all() { git_verb("-c core.quotepath=false reset", "已取消暂存"); }
fn git_fetch() { git_verb("fetch --all", "已抓取远程更新"); }
fn git_pull() { git_verb("pull --ff-only", "已拉取"); }
fn git_push() { git_verb("push", "已推送"); }
fn git_stash(untracked: bool) {
    if untracked { git_verb("stash -u", "已储藏（含未跟踪文件）"); }
    else { git_verb("stash", "已储藏更改"); }
}
fn git_amend() { git_verb("commit --amend --no-edit", "已修改上次提交"); }
fn git_undo_commit() { git_verb("reset --soft HEAD~1", "已撤销上次提交"); }

fn reload_scm() {
    scm_rows.resize(0);
    scm_n = 0;
    scm_err = false;
    scm_looked = true;
    var dotgit: u8[>..] = [];
    append_root(dotgit, "/.git");
    scm_repo = is_dir(dotgit);
    read_branch();
    if !scm_repo { return; }
    var raw: u8[>..] = [];
    git_status_raw(raw);
    if raw.len == 0 {
        // either a clean tree or no Git on this machine: ask HEAD's log
        scm_err = true;
        return;
    }
    if has_word(raw, "recognized") || has_word(raw, "not found") || has_word(raw, "不是内部") {
        scm_err = true;
        return;
    }
    scm_err = false;
    var start: i64 = 0;
    var i: i64 = 0;
    while i <= raw.len {
        if i == raw.len || raw[i] == '\n' {
            if i > start {
                let line = raw[start..i];
                if line.len > 3 && line[2] == ' ' && valid_status(line[0]) && valid_status(line[1]) {
                    scm_rows.append(line);
                    scm_rows.push('\n');
                    scm_n++;
                }
            }
            start = i + 1;
        }
        i++;
    }
}

fn scm_init() {
    var cmd: u8[>..] = [];
    cmd.append(git_exe());
    cmd.append(" init");
    let n = run_git(cmd);
    state::scm_loaded = false;
    reload_scm();
    app::set_status(if n > 0 { "已初始化仓库" } else { "未找到 Git" });
}

fn scm_commit() {
    if state::scm_msg.len == 0 { return; }
    var cmd: u8[>..] = [];
    cmd.append(git_exe());
    cmd.append(" add -A && ");
    cmd.append(git_exe());
    cmd.append(" commit -m \"");
    cmd.append(state::scm_msg);
    cmd.append("\"");
    let n = run_git(cmd);
    reload_scm();
    app::set_status(if n > 0 { "已提交" } else { "未找到 Git" });
}

fn open_scm_row(i: i32) {
    var k: i64 = 0;
    var start: i64 = 0;
    var idx: i32 = 0;
    while k <= scm_rows.len {
        if k == scm_rows.len || scm_rows[k] == '\n' {
            if k > start && idx == i {
                var p: u8[>..] = [];
                if state::root.len > 0 { p.append(state::root); p.push('/'); }
                var q: i64 = start + 3;
                while q < k {
                    let c = scm_rows[q];
                    p.push(if c == '\\' { '/' } else { c });
                    q++;
                }
                app::open_path(p);
                return;
            }
            if k > start { idx++; }
            start = k + 1;
        }
        k++;
    }
}
