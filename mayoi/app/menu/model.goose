// The menus, as Mayoi's commands.go builds them: the same order, the same
// labels and the same accelerators, in one flat table of records.
namespace menu;

import i18n;

struct Item { depth: i32, flags: i32, id: u8[..40], label: u8[..64], accel: u8[..28] }

let SUB = 1; let CHECKED = 2; let DISABLED = 4; let SEPARATOR = 8;

var items: Item[>..] = [];
var built = false;
var top: i64[>..] = [];       // index of each top-level group

// The records: depth, flags, command, label, accelerator, tab separated.
let DATA = "0\t0\t\t文件\t\n1\t0\tfile.new\t新建文件\tCtrl+N\n1\t0\tfile.newWindow\t新建窗口\tShift+Ctrl+N\n1\t0\tfile.openFolder\t打开文件夹…\tCtrl+O\n1\t0\tfile.openFolderWindow\t在新窗口中打开文件夹…\tAlt+Ctrl+O\n1\t1\tmenu.openRecent\t打开最近的文件夹\t\n2\t0\tfile.openRecent\t更多…\t\n1\t8\t\t\t\n2\t0\tfile.clearRecent\t清除最近打开记录\t\n1\t1\tmenu.remote\t远程 SSH\t\n2\t0\tremote.connect\t连接到远程主机…\t\n2\t0\tremote.openFolder\t打开远程文件夹…\t\n2\t0\tremote.openConfig\t打开 SSH 配置…\t\n1\t8\t\t\t\n2\t4\tremote.reconnect\t重新连接\t\n2\t4\tremote.disconnect\t断开连接\t\n1\t8\t\t\t\n2\t4\tremote.forwardPort\t转发端口…\t\n1\t0\twsl.openFolder\t打开 WSL 文件夹…\t\n1\t8\t\t\t\n1\t0\tfile.save\t保存\tCtrl+S\n1\t0\tfile.saveAs\t另存为…\tShift+Ctrl+S\n1\t0\tfile.saveAll\t全部保存\tAlt+Ctrl+S\n1\t2\tfile.autoSave\t自动保存\t\n1\t8\t\t\t\n1\t0\tfile.settings\t设置…\tCtrl+,\n1\t0\tfile.settingsJSON\t打开设置 (JSON)\t\n1\t0\tfile.keybindings\t键盘快捷方式…\t\n1\t0\tfile.keybindingsJSON\t打开键盘快捷方式 (JSON)\t\n1\t0\tfile.folderSettings\t打开文件夹设置 (JSON)\t\n1\t8\t\t\t\n1\t0\tfile.close\t关闭标签页\tCtrl+W\n1\t0\tfile.reopenClosed\t重新打开已关闭的标签页\tShift+Ctrl+T\n1\t0\tfile.closeFolder\t关闭文件夹\t\n1\t0\tfile.closeProject\t关闭项目\t\n1\t8\t\t\t\n1\t0\tfile.installCLI\t安装 “mayoi” 命令\t\n1\t0\tfile.uninstallCLI\t卸载 “mayoi” 命令\t\n1\t0\tfile.addContextMenu\t添加到资源管理器右键菜单\t\n1\t0\tfile.removeContextMenu\t从资源管理器右键菜单移除\t\n0\t0\t\t编辑\t\n1\t0\tedit.undo\t撤销\t\n1\t0\tedit.redo\t重做\t\n1\t8\t\t\t\n1\t0\tedit.cut\t剪切\tCtrl+X\n1\t0\tedit.copy\t复制\tCtrl+C\n1\t0\tedit.paste\t粘贴\tCtrl+V\n1\t0\tedit.selectAll\t全选\tCtrl+A\n1\t8\t\t\t\n1\t0\tedit.find\t查找\tCtrl+F\n1\t0\tedit.replace\t替换\tAlt+Ctrl+F\n1\t0\tedit.findNext\t查找下一个\tCtrl+G\n1\t0\tedit.findPrev\t查找上一个\tShift+Ctrl+G\n1\t8\t\t\t\n1\t0\tedit.findInFiles\t在文件中查找\tShift+Ctrl+F\n1\t0\tedit.replaceInFiles\t在文件中替换\tShift+Ctrl+H\n1\t8\t\t\t\n1\t0\tedit.fold\t折叠\tAlt+Ctrl+[\n1\t0\tedit.unfold\t展开\tAlt+Ctrl+]\n1\t0\tedit.toggleFold\t切换折叠\t\n1\t0\tedit.foldAll\t全部折叠\t\n1\t0\tedit.unfoldAll\t全部展开\t\n1\t8\t\t\t\n1\t1\tmenu.markdown\tMarkdown\t\n2\t0\tmarkdown.toggleTask\t切换任务列表项\t\n2\t0\tmarkdown.toggleList\t切换列表\t\n2\t0\tmarkdown.toggleQuote\t切换引用块\t\n1\t8\t\t\t\n2\t0\tmarkdown.moveItemUp\t上移列表项\t\n2\t0\tmarkdown.moveItemDown\t下移列表项\t\n1\t8\t\t\t\n2\t0\tmarkdown.heading1\t一级标题\t\n2\t0\tmarkdown.heading2\t二级标题\t\n2\t0\tmarkdown.heading3\t三级标题\t\n2\t0\tmarkdown.heading4\t四级标题\t\n2\t0\tmarkdown.heading5\t五级标题\t\n2\t0\tmarkdown.heading6\t六级标题\t\n1\t8\t\t\t\n2\t0\tmarkdown.clearFormatting\t清除格式\t\n2\t0\tmarkdown.toggleEmbed\t切换嵌入\t\n0\t0\t\t选择\t\n1\t0\tsel.line\t选择行\tCtrl+L\n1\t8\t\t\t\n1\t0\tsel.addCursorAbove\t在上方添加光标\tAlt+Ctrl+Up\n1\t0\tsel.addCursorBelow\t在下方添加光标\tAlt+Ctrl+Down\n1\t0\tsel.addNextOccurrence\t添加下一个匹配项\tCtrl+Ctrl+G\n1\t0\tsel.selectAllOccurrences\t选择所有匹配项\tShift+Ctrl+L\n1\t8\t\t\t\n1\t0\tsel.comment\t切换行注释\tCtrl+/\n1\t0\tsel.indent\t缩进行\tCtrl+]\n1\t0\tsel.outdent\t减少行缩进\tCtrl+[\n1\t8\t\t\t\n1\t0\tsel.moveUp\t向上移动行\t\n1\t0\tsel.moveDown\t向下移动行\t\n1\t0\tsel.copyUp\t向上复制行\t\n1\t0\tsel.copyDown\t向下复制行\t\n1\t8\t\t\t\n1\t0\tsel.lineBelow\t在下方插入行\t\n1\t0\tsel.lineAbove\t在上方插入行\t\n1\t0\tsel.deleteLine\t删除行\tShift+Ctrl+K\n1\t0\tsel.joinLines\t连接行\t\n1\t8\t\t\t\n1\t0\tsel.sortAsc\t按升序排列行\t\n1\t0\tsel.sortDesc\t按降序排列行\t\n1\t0\tsel.camelCase\t转换为驼峰命名\t\n1\t8\t\t\t\n1\t0\tsel.format\t格式化代码\tShift+Alt+F\n1\t0\tsel.insertSnippet\t插入代码片段…\t\n1\t0\tsel.complete\t触发补全\t\n0\t0\t\t查看\t\n1\t0\tview.sidebar\t切换侧边栏\tCtrl+B\n1\t2\tview.sidebarRight\t侧边栏位于右侧\t\n1\t0\tview.explorer\t资源管理器\tShift+Ctrl+E\n1\t0\tview.search\t搜索\t\n1\t0\tview.scm\t源代码管理\tCtrl+Shift+G\n1\t0\tview.github\tGitHub\t\n1\t0\tview.sessions\t会话\t\n1\t0\tview.archivedSessions\t已归档的会话\t\n1\t8\t\t\t\n1\t2\tview.compactFolders\t压缩文件夹\t\n1\t8\t\t\t\n1\t0\tview.wordWrap\t自动换行\t\n1\t0\tview.wordWrapTab\t切换标签页的自动换行\tAlt+Z\n1\t0\tview.togglePreview\t切换预览\tShift+Ctrl+V\n1\t0\tview.toggleLivePreview\t切换实时预览\tAlt+Ctrl+V\n1\t0\tview.previewToSide\t在侧边打开预览\t\n1\t1\tmenu.mdopen\tMarkdown 打开方式\t\n2\t2\tview.markdownOpen.source\t源代码\t\n2\t0\tview.markdownOpen.live\t实时预览\t\n2\t0\tview.markdownOpen.reading\t阅读视图\t\n1\t1\tmenu.jsonlopen\tJSON Lines 打开方式\t\n2\t2\tview.jsonlOpen.table\t表格\t\n2\t0\tview.jsonlOpen.source\t源代码\t\n1\t8\t\t\t\n1\t0\tview.vim\tVim 模式\t\n1\t0\tview.projectTabs\t项目标签页\t\n1\t8\t\t\t\n1\t0\tview.splitRight\t向右拆分\tCtrl+\\n1\t0\tview.splitDown\t向下拆分\t\n1\t0\tview.newColumnRight\t向右新建栏\tCtrl+D\n1\t0\tview.newColumnDown\t向下新建栏\tShift+Ctrl+D\n1\t0\tview.nextColumn\t聚焦下一栏\tAlt+Ctrl+Right\n1\t0\tview.prevColumn\t聚焦上一栏\tAlt+Ctrl+Left\n1\t0\tview.moveTabNext\t将标签页移到下一栏\t\n1\t0\tview.moveTabPrev\t将标签页移到上一栏\t\n1\t8\t\t\t\n1\t0\tview.terminal\t切换终端\tCtrl+`\n1\t0\tview.newTerminal\t新建终端\tCtrl+Shift+`\n1\t1\tmenu.panelpos\t面板位置\t\n2\t2\tview.panelPosition.bottom\t将面板移到底部\t\n2\t0\tview.panelPosition.left\t将面板移到左侧\t\n2\t0\tview.panelPosition.right\t将面板移到右侧\t\n1\t8\t\t\t\n1\t0\tview.zoomIn\t放大\tCtrl+=\n1\t0\tview.zoomOut\t缩小\tCtrl+-\n1\t0\tview.zoomReset\t重置缩放\tCtrl+0\n1\t8\t\t\t\n1\t1\tmenu.theme\t主题\t\n2\t0\tview.selectTheme\t颜色主题…\t\n1\t8\t\t\t\n2\t2\tview.appearance.system\t跟随系统\t\n2\t0\tview.appearance.light\t浅色\t\n2\t0\tview.appearance.dark\t深色\t\n1\t8\t\t\t\n2\t2\tview.theme.mayoi\tMayoi\t\n2\t0\tview.theme.matrix\t黑客帝国\t\n2\t0\tview.theme.claude\tClaude\t\n2\t0\tview.theme.qoder\tQoder\t\n2\t0\tview.theme.grokbot\tGrokBot\t\n2\t0\tview.theme.cursor\tCursor\t\n2\t0\tview.theme.purplegold\t紫金\t\n2\t0\tview.theme.pumpkin\t南瓜灯\t\n2\t0\tview.theme.witchsbrew\t女巫魔药\t\n2\t0\tview.theme.bloodmoon\t血月\t\n2\t0\tview.theme.gtavi\tGTA VI\t\n1\t1\tmenu.language\t语言\t\n2\t2\tview.locale.system\t跟随系统语言\t\n2\t0\tview.locale.en\tEnglish\t\n2\t0\tview.locale.ja\t日本語\t\n2\t0\tview.locale.zh\t简体中文\t\n1\t8\t\t\t\n1\t0\tview.fullscreen\t切换全屏\t\n1\t4\tview.devtools\t切换开发工具\t\n0\t0\t\t转到\t\n1\t0\tgo.quickOpen\t快速打开…\tCtrl+P\n1\t0\tgo.commands\t命令面板…\tShift+Ctrl+P\n1\t0\tgo.symbol\t转到符号…\tShift+Ctrl+O\n1\t0\tgo.line\t转到行…\tCtrl+G\n1\t0\tgo.bracket\t转到括号\tShift+Ctrl+\\n1\t8\t\t\t\n1\t0\tgo.definition\t转到定义\tF12\n1\t0\tgo.typeDefinition\t转到类型定义\t\n1\t0\tgo.sourceDefinition\t转到源定义\t\n1\t0\tgo.implementation\t转到实现\tCtrl+F12\n1\t0\tgo.references\t转到引用\tShift+F12\n1\t0\tgo.hover\t显示悬停提示\t\n1\t8\t\t\t\n1\t0\tgo.back\t后退\tCtrl+-\n1\t0\tgo.forward\t前进\tCtrl+Shift+-\n1\t8\t\t\t\n1\t0\tgo.nextTab\t下一个标签页\tCtrl+Tab\n1\t0\tgo.prevTab\t上一个标签页\tCtrl+Shift+Tab\n1\t8\t\t\t\n1\t0\tgo.nextProject\t下一个项目\tShift+Ctrl+]\n1\t0\tgo.prevProject\t上一个项目\tShift+Ctrl+[\n0\t0\t\tGit\t\n1\t0\tgit.commit\t提交\t\n1\t0\tgit.commitPush\t提交并推送\t\n1\t0\tgit.amend\t修改上次提交\t\n1\t0\tgit.undoCommit\t撤销上次提交\t\n1\t8\t\t\t\n1\t0\tgit.openChanges\t打开更改\t\n1\t0\tgit.openAllChanges\t打开所有更改\t\n1\t0\tgit.compareFiles\t比较两个文件…\t\n1\t0\tgit.nextChange\t下一个更改\tAlt+F5\n1\t0\tgit.prevChange\t上一个更改\tShift+Alt+F5\n1\t0\tgit.nextFile\t下一个文件\t\n1\t0\tgit.prevFile\t上一个文件\t\n1\t0\tgit.collapseAllFiles\t收起差异中的所有文件\t\n1\t0\tgit.expandAllFiles\t展开差异中的所有文件\t\n1\t2\tgit.toggleCommitFiles\t显示提交的文件\t\n1\t8\t\t\t\n1\t0\tgit.showChange\t显示更改\t\n1\t0\tgit.revertChange\t还原更改\t\n1\t0\tgit.appendChange\t追加该更改的源行\t\n1\t0\tgit.stageChange\t暂存更改\t\n1\t8\t\t\t\n1\t0\tgit.stageFile\t暂存文件\t\n1\t0\tgit.unstageFile\t取消暂存文件\t\n1\t0\tgit.stageAll\t暂存所有更改\t\n1\t8\t\t\t\n1\t0\tgit.switchBranch\t切换分支…\t\n1\t0\tgit.switchWorktree\t切换工作树…\t\n1\t0\tgit.createBranch\t创建分支…\t\n1\t0\tgit.fetch\t抓取\t\n1\t0\tgit.pull\t拉取\t\n1\t0\tgit.push\t推送\t\n1\t8\t\t\t\n1\t0\tgit.stash\t储藏更改…\t\n1\t0\tgit.stashUntracked\t储藏更改（含未跟踪文件）…\t\n1\t0\tgit.stashes\t储藏列表…\t\n1\t8\t\t\t\n1\t4\tgit.openPullRequest\t打开拉取请求…\t\n1\t4\tgit.showPullRequestChecks\t显示拉取请求检查…\t\n1\t4\tgit.newIssue\t新建问题\t\n1\t8\t\t\t\n1\t0\tgit.blame\t行内追溯\t\n1\t4\tgit.openFileOnRemote\t在远程仓库中打开文件\t\n1\t4\tgit.copyPermalink\t复制永久链接\t\n1\t0\tgit.refresh\t刷新源代码管理\t\n1\t8\t\t\t\n1\t0\treview.comment\t添加审阅评论\tShift+Ctrl+M\n1\t4\treview.next\t下一条评论\t\n1\t4\treview.previous\t上一条评论\t\n1\t4\treview.copy\t复制评论\t\n1\t4\treview.send\t发送评论\t\n1\t4\treview.clear\t清除评论\t\n0\t0\t\t帮助\t\n1\t0\thelp.reportProblem\t报告问题…\t\n0\t0\t\t插件\t\n1\t0\tplugin.manage\t管理插件…\t\n1\t0\tplugin.install\t安装插件…\t\n1\t8\t\t\t\n1\t0\tplugin.reload\t重新加载插件\t\n0\t0\t\t窗口\t\n1\t0\twindow.minimize\t最小化\t\n1\t0\twindow.zoom\t缩放\t\n1\t0\twindow.close\t关闭\t\n1\t8\t\t\t\n1\t0\twindow.new\t新建窗口\t\n1\t0\twindow.next\t下一个窗口\t";

fn build() {
    if built { return; }
    built = true;
    var start: i64 = 0;
    var k: i64 = 0;
    while start <= DATA.len {
        if k == DATA.len || DATA[k] == '\n' {
            if k > start {
                add_record(start, k);
            }
            start = k + 1;
        }
        k++;
    }
}

fn add_record(a: i64, b: i64) {
    var it: Item = Item { .. };
    var field: i32 = 0;
    var k: i64 = a;
    while k < b {
        let c = DATA[k];
        if c == '\t' {
            field++;
        } else if field == 0 {
            it.depth = c as i32 - 48;
        } else if field == 1 {
            it.flags = it.flags * 10 + (c as i32 - 48);
        } else if field == 2 {
            it.id.push(c);
        } else if field == 3 {
            it.label.push(c);
        } else if field == 4 {
            it.accel.push(c);
        }
        k++;
    }
    if it.depth == 0 { top.push(items.len); }
    if it.accel.len == 0 && it.flags == 0 && it.label.len == 0 && it.id.len == 0 {
        it.flags = SEPARATOR;
    }
    items.push(it);
}


fn count() -> i32 { return items.len as i32; }

// entries of a top-level group, from its own index, to the next group's
fn group_end(g: i64) -> i64 {
    var i = g + 1;
    while i < items.len && items[i].depth != 0 { i++; }
    return i;
}

fn find_group(label: const u8[:]) -> i32 {
    var i: i64 = 0;
    while i < top.len {
        let t = top[i];
        if items[t].label.len == label.len {
            var k: i64 = 0;
            var same = true;
            while k < label.len {
                if items[t].label[k] != label[k] { same = false; break; }
                k++;
            }
            if same { return i as i32; }
        }
        i++;
    }
    return -1;
}

// The row of a submenu that a click at y lands on, in the panel opened from
// the row at index g, between the rows lo and hi.
fn row_at(lo: i64, hi: i64, y0: i32, y1: i32, rowh: i32) -> i64 {
    var i = lo;
    while i < hi {
        let d = items[i].depth;
        if d == 1 || d == 2 {
            let top_y = y0 + (i - lo) as i32 * rowh;
            if y1 >= top_y && y1 < top_y + rowh { return i; }
        }
        i++;
    }
    return -1;
}

fn label_at(i: i64) -> const u8[:] { return i18n::t(items[i].label[0..items[i].label.len]); }
fn accel_at(i: i64) -> const u8[:] { return items[i].accel[0..items[i].accel.len]; }
fn id_at(i: i64) -> const u8[:] { return items[i].id[0..items[i].id.len]; }
