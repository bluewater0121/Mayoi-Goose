# Mayoi 克隆（goose + Win32 GDI）

用 [goose](https://github.com/sorrycc/goose) 语言写主体、Win32 GDI 绘制，对 Mayoi 0.23.3（Windows ARM64）编辑器做 1:1 克隆。
目标程序：`C:\bin\mayoi-0.23.3-windows-arm64\Mayoi.exe`；参照源码：`C:\work\prj\winhx\reference\Mayoi`。

## 构建

```powershell
cd C:\work\prj\winhx\mayoi
.\build.ps1            # 产出 build\MayoiGoose.exe（无控制台）
.\build.ps1 -Console   # 产出 build\MayoiDbg.exe（带控制台，便于看 stderr 诊断）
```

`build.ps1` 依次做四步：

1. 跑 `..\tools\mkicons.py`，从 `reference\Mayoi\cmd\mayoi\icons.go` 解析 109 个 Lucide 图标，生成 `assets\icons.h`（32bpp 缓存表）与 `icons.goose`（图标常量）。
2. `C:\bin\goose\goose.exe -o build\mayoi.c main.goose`。
3. 用 `vcvarsamd64_arm64.bat` + `cl /O2 /MT /utf-8` 编译 `build\mayoi.c`、`src\plat.c` 与 goose 运行时 obj。
4. 链接 `/SUBSYSTEM:WINDOWS`（`-Console` 时 CONSOLE），`/ENTRY:mainCRTStartup`。

**注意**：链接前必须先结束正在运行的 `build\*.exe`（否则 LNK1104）。`goose build` 在本机因 PATH 缺 System32 会静默失败，一律用 `build.ps1`。

## 结构

按 Mayoi 源码（`cmd/mayoi/*.go`、`internal/*`）的职责切分，目录对齐上游：

| 文件 | 内容 |
| --- | --- |
| `main.goose` | 入口：DPI 感知、消息循环（键盘/字符/IME/鼠标/滚轮/定时器/尺寸）、`dir [file]` 启动参数（相对路径按根解析） |
| `ui/win.goose` | Win32 绑定与绘图原语：`fill` / `round_rect` / `line` / `text_at` / `measure` / `icon` / `font` / `fontw`、双缓冲 `resize_frame` / `present`、文件与文件夹选择框 |
| `ui/theme.goose` | 深/浅两套调色板（逐色对齐 Mayoi dark/light 主题） |
| `ui/icons.goose` | 由 `cmd/mayoi/icons.go` 解析出的 109 个 Lucide 图标常量 |
| `app/state.goose` | 全局状态、文档数组、布局度量、命中区（`add_hit` / `find_hit`）与 `HIT_*` 常量 |
| `app/layout.goose` | 布局计算（标题 49 / 标签 42 / 面包屑 41 / 状态栏 30 / 行高 25 / 侧栏 319）、字体、`open_path`、`set_title`、`set_root` |
| `app/view.goose` | 整窗绘制编排：欢迎页、代码区、下方面板，末尾接菜单 |
| `app/draw.goose` | 中英混排的文字宽度/绘制辅助（`ch` / `chw`） |
| `app/icons.goose` | 图标 kind 到 Lucide 名称的映射（`icon_at`）与根目录大写标题（`root_caps`） |
| `app/titlebar.goose` | 标题栏：hamburger（`HIT_MENU`，展开时变 accent）、侧栏开关、命令中心、右侧窗口按钮 |
| `app/tabs.goose` | 标签条 + 面包屑 |
| `app/status.goose` | 状态栏：左侧根名、右侧「Go / LF / UTF-8 / 制表符 / 行数 / 行,列」 |
| `app/overlay.goose` | 命令面板与快速打开浮层：`refresh_commands` / `refresh_items` / `match_query` / `paint_overlay` / `open_overlay_row` |
| `app/menu/model.goose` | 菜单数据：271 条（`SUB/CHECKED/DISABLED/SEPARATOR` 标志 + 快捷键），`build` / `top` / `label_at` / `accel_at` / `id_at` |
| `app/menu/layout.goose` | 菜单几何：行高 30、分隔 9、三层面板宽度与滚动、`p1_y` / `p2_y` 定位与裁切 |
| `app/menu/paint.goose` | 菜单绘制：`backdrop` / `row_bg` / `sep_line` / `row_text` / `paint_top` / `paint_group` / `paint_children` |
| `app/menu/input.goose` | 菜单交互：`open` / `close` / `hover` / `press` / `key`（Esc 逐层退、↑↓→←、Enter）/ `wheel` |
| `app/menu/action.goose` | 菜单命令分发：文件/编辑/查看/转到/Git 已接，其余走 `unfilled()` 提示 |
| `app/input.goose` | 输入模块的聚合入口（`import` 下面七个） |
| `app/input/vk.goose` | 虚拟键码常量 |
| `app/input/edit.goose` | 键入、回车、退格、删除、光标移动（按行/列/词）、点击定位、滚轮、`ensure_visible` |
| `app/input/file.goose` | 新建、打开文件/文件夹、保存、关闭标签、打开树中选中项 |
| `app/input/palette.goose` | 命令面板执行、缩放、命令标签、浮层行打开、标签切换 |
| `app/input/keys.goose` | `key()` 快捷键表（Ctrl+S/O/N/P/F/A/C/X/V/Z/Y/G、方向键、Esc/Enter）、复制粘贴 |
| `app/input/mouse.goose` | `mouse_down` / `mouse_up` / `mouse_move`：命中分发、菜单优先级、侧栏钩子、拖拽与选择 |
| `app/sidebar.goose` | 侧栏调度：活动栏 + 标题 + 视图分发，`sidebar_click` / `search_char` |
| `app/sidebar/rail.goose` | 左侧活动栏 4 个图标（资源管理器/搜索/源代码管理/会话），各带 32×32 高亮底板 |
| `app/sidebar/explorer.goose` | 资源管理器：项目行 + 可折叠文件树、按可视区裁剪的行绘制、4px 滚动条（可拖动）、祖先引导线、行内重命名输入框 |
| `app/sidebar/search.goose` | 搜索的扫描层：匹配（大小写/整词/正则）、包含/排除过滤（逗号分隔 glob）、递归遍历（限额 800 目录 / 600 文件 / 200 命中）、`replace_one` / `replace_all` |
| `app/sidebar/searchui.goose` | 搜索的绘制层：搜索框与内嵌 Aa/ab/.* 开关、替换行与「替换全部」、「...」过滤区（包含/排除文件）、说明与快捷键芯片、结果两行式列表 |
| `app/sidebar/scm.goose` | 源代码管理的 Git 层：`.git` 探测、读 `HEAD` 分支、`git status` / `git init` / `git add -A && git commit`、无 Git 时降级 |
| `app/sidebar/scmui.goose` | 源代码管理的绘制层：非仓库空态（圆圈 branch 徽标 + 说明 + 初始化按钮）、分支行、提交消息框、更改列表 |
| `app/ctxmenu.goose` | 右键菜单模型：文件树 14 项、树空白区 12 项、编辑器 7 项；自适应宽度/夹取窗口、悬停与命中 |
| `app/input/ctx.goose` | 右键动作与文件操作：新建文件/文件夹、资源管理器显示、终端打开、复制路径、重命名、删除（确认框）、撤销/粘贴/全选、树滚动与拖拽滚动条 |
| `app/prefs/data.goose` | 设置窗口的内容表（由参考的 `internal/settings/schema.go` 与 `zh-Hans.json` 生成）：10 个分区 63 项设置的标题/说明/类型/范围/默认值，以及 48 条枚举选项的取值与中文标签 |
| `app/prefs/model.goose` | 设置模型：解析内容表、分区名与图标、按键查值/改值、布尔/数字/枚举换算、默认值与「已更改」判定、跨分区搜索、快捷键分区 |
| `app/prefs/paint.goose` | 设置窗口绘制：遮罩 + 940×690 窗体、标题栏与关闭、左侧搜索框/11 个分区/已更改徽标/settings.json 与 keybindings.json 链接、右侧分区标题与「用户」范围选择、逐项卡片（标题/说明/键名/控件）、开关/步进/下拉/文本框/列表、下拉浮层、滚动条 |
| `app/prefs/input.goose` | 设置窗口交互：分区切换、搜索输入、开关、加减、下拉选择、文本编辑与提交、恢复默认、Esc 关闭、滚轮滚动、悬停 |
| `app/sidebar/sessions.goose` | 会话视图：已打开文档列表，点击切换 |
| `editor/text.goose` | 文档模型：行索引、插入/删除/替换、选区、列/行换算 |
| `editor/syntax.goose` | Go 语法着色（关键字/字符串/注释/数字） |
| `editor/editor.goose` | 代码区绘制：行号槽、着色分段、当前行、光标、选择 |
| `explore/tree.goose` | 文件树：目录扫描、展开/折叠、点击打开 |
| `src/plat.c` | C 助手：窗口过程（无边框 + 5px 拖边 + 标题栏拖动 + `WM_NCCALCSIZE`）、32bpp premultiplied 图标缓存与 AlphaBlend、剪贴板、文件对话框、子进程管道 `gs_run_cmd`、路径与文件时间、`gs_setdpi` |
| `assets/` | `icons.h`（生成的图标表）、`icons/*.png`（109 个 mask 预览）、`lucide_icons_source.go`（原始图标 SVG 出处，从 Mayoi 拷贝） |
| `docs/` | `clone-1262x811.png` 与 `ref-1262x811.png`（同尺寸截图对照） |

## 已知还原点

- 窗口：无边框（`WM_NCCALCSIZE`），client 1262×811，8px 系统边框仍可拖拽缩放；标题栏空白区可拖动窗口。
- 顶栏：hamburger（点击展开菜单、展开时变 accent）+ 侧栏按钮 + 命令中心（524×30，1px 边框 + 居中「搜索图标 / 文件名 semibold / 文件夹名 faint」）+ 右侧终端/最小化/最大化/关闭。
- 菜单：点击 hamburger 弹出三层面板（顶层 9 组：文件/编辑/选择/查看/转到/Git/帮助/插件/窗口；每组级联子菜单 271 条），带悬停高亮、快捷键右对齐、勾选项、子菜单箭头、分隔线、禁用灰、滚轮滚动、键盘导航（Esc 逐层退、↑↓ 选择、→ 展开、← 收起、Enter 执行），点外部关闭；已接命令含新建/打开文件夹/保存/关闭/撤销/重做/查找/侧栏四视图/缩放/外观/快速打开/命令面板/标签切换/Git 刷新，其余项给出「尚未实现」提示。
- 侧栏：活动栏 4 个图标（资源管理器 / 搜索 / 源代码管理 / 会话），各自 32×32 高亮底板、点击切换，标题随视图变化。
  - 资源管理器：`MAYOI` 根标题 + 可折叠目录树，点击文件即打开。
  - 资源管理器：文件行高 35、缩进基准 39（每级 +13）、chevron 12px、16px 文件夹/文件图标、文字 13px；展开后在原行下方就地插入子项（不再「只展开最下面」）；可视区外的行不绘制，右侧 4px 滚动条随滚轮/拖动/展开自动夹取，行内可重命名；右键弹出 14 项菜单（新建文件…/新建文件夹…/在文件资源管理器中显示/在终端中打开/复制/粘贴(灰)/复制路径/复制相对路径/重命名…/删除）。
  - 搜索：标题 + ↻/✕；输入框内嵌 Aa（大小写）、ab（整词）、.*（正则）；框外「...」展开「包含的文件 / 排除的文件」（占位 `例如 *.go, src/**`、`例如 *.test.ts, testdata`）；Ctrl+Shift+H 或左侧箭头进入替换模式（替换框 + 替换全部），替换会按结果文件逐个读改写并重跑；结果两行式（`路径:行` + 片段），点击打开。扩展名黑名单（图片/压缩包/可执行）之外的文本都可命中。
  - 源代码管理：有 `.git` 时读 `HEAD` 显示分支，画提交消息框 + 「提交」（`git add -A && git commit -m`），下方「更改 N」列表；无仓库时画圆圈 branch 徽标 + 「没有 Git 仓库」+ 两行说明 + accent「初始化仓库」（`git init`）；未安装 Git 时以「未找到 Git」降级。
  - 会话：已打开文档列表，当前文档高亮，点击切换。
  - 会话：已打开文档列表，当前文档高亮，点击切换。
- 右键菜单：文件树行、树空白区、编辑器各一套；宽 = 最长项 + 56px，行 24、分隔 9，禁用项 faint，悬停高亮；编辑器菜单需先点进编辑区再右键（与参考一致：撤销/剪切/复制/删除灰、粘贴/全选可用）。
- 设置窗口（「文件 › 设置…」「文件 › 键盘快捷方式…」「插件 › 管理插件…」均可打开）：居中 940×690 模态窗口，左侧「搜索设置」+ 11 个分区（外观/字体/编辑器/Markdown/终端/差异与合并/Git/Vim/插件/通用/键盘快捷方式，各带图标与已更改计数）、底部 settings.json / keybindings.json 链接；右侧分区标题 + 「用户」范围选择；内容按参考的 schema 生成，共 63 项设置，每项一张卡片：标题、说明（按宽度折行）、键名（等宽小字），右侧是开关 / − 数值 + / 下拉（点开为浮层选项）/ 文本框；改动后标题旁出现 accent 圆点、侧栏分区出现计数、右下出现「恢复默认」，键盘快捷方式分区列出 271 条命令与其快捷键并可按名称/键位搜索。搜索框输入即在 10 个分区全部设置中匹配（标题、说明、键名），标题变为「找到 N 项设置」。
- 设置落盘：启动读 `%APPDATA%\Mayoi\settings.json`，改动后写回（只写变化过的键，布尔/数字/文本/枚举格式与参考一致）；键名与 `internal\settings\schema.go` 对齐，因此和真实 Mayoi 的配置可互读。
- Vim 模式（设置里打开 `vim`，或菜单「查看 › Vim 模式」）：状态栏显示 NORMAL / INSERT / VISUAL / V-LINE / EX 徽标（NORMAL 灰底、INSERT 紫、VISUAL 琥珀），并显示已敲的前缀键。支持 h j k l w b e 0 ^ $ gg G（带 count）、dd cc yy、d/c/y + 移动、x p P、i a I A o O、u / Ctrl+R、v / V、`:` 命令行（`:w` `:q` `:wq` `:x` `:<行号>`）、Esc 逐级退出；寄存器跨行保存，重切文档回到 NORMAL。（`docs/vim-normal.png`、`vim-insert.png`、`vim-visual.png`）
- 插件系统：读 `~/.mayoi/plugins` 下各文件夹的 `plugin.json`（name / displayName / version / description / author），设置「插件」分区列出已安装卡片（字母 tile、版本·作者、描述、启用开关、垃圾桶）、空态、安装卡片与「插件设置」4 项；启用状态写在 `settings.json` 的 `plugins` 键（`{"<name>": {"enabled": false}}`），支持重新加载、打开插件文件夹、选择文件夹安装（xcopy 复制）、两次点击删除（rmdir）。插件命令本身不执行（无 JS 运行时）。（`docs/plugins.png`、`plugins-off.png`、`plugins-empty.png`）
- 最小化恢复：`WM_SIZE` / `WM_ACTIVATE` / `WM_SHOWWINDOW` / `WM_DPICHANGED` 在窗口过程里被 `PostMessage` 转发进 goose 队列（`0x8002`…`0x8005`），恢复时 `SWP_FRAMECHANGED` + 重建 DIB + 重排 + 重绘，修复「最小化再恢复一片黑」。
- 标签条：42px 高，标签 42+label+42，活动标签 2px accent 顶边与 1px 右边框，图标 16px、关闭按钮 14px、脏标记。
- 面包屑：`cmd › mayoi › editor.go` 形式，末段为文件图标 + 文件名。
- 代码区：行高 25、单元格 9px（Consolas 16px + `lfWidth=9`，单次 `TextOut` 即可保持 9px 步进）、行号右缘 `x0+56`、正文起点 `x0+102`、当前行底纹 `#202025`。
- 状态栏：左侧根目录名 + 右侧「Go / LF / UTF-8 / 制表符 / 1,346 行 / 行 1, 列 1」，右侧中文项用 Microsoft YaHei UI 15 保持与参考同宽。
- 图标：全部 109 个 Lucide 图标由 `icons.go` 解析成 alpha mask，运行时按 (图标, 颜色, 尺寸) 缓存 1024 条并 AlphaBlend。
- 启动参数：`Mayoi.exe <目录> [文件]`；相对文件路径按根目录拼接后打开。
- 已验收交互：键入/删除（含语法着色实时更新）、Ctrl+S 落盘、滚轮滚动、侧栏折叠、标签切换与关闭、命中区点击、菜单点击执行命令、搜索输入与结果点击。

## 与参考的残差

同尺寸逐像素对比（`r1280.png` 裁 client 1262×811 vs 本程序截图）：

| 区域 | 差异率 |
| --- | --- |
| 整窗 | 7.16% |
| 标题栏 | 5.8% |
| 标签条 | 7.0% |
| 面包屑 | 4.6% |
| 侧栏树 | 9.6%（参考截图当时树处于滚动/展开状态，内容不同，非绘制差异） |
| 代码区 | 6.7% |
| 状态栏 | 6.9% |

残差绝大多数是**字形栅格化差异**：参考用 Skia 自然 advance 渲染系统 monospace，本程序用 GDI Consolas + 9px 格栅，单字形 ink 位置有 ±3px 出入，长行右侧会有几像素累积；颜色（`#18181d` 背景、`#a9d48f` 字符串、`#b99cf7` 关键字、`#747481` 注释等）已逐色调核对一致。侧栏 9.6% 主要来自参考截图当时文件树处于滚动状态（首行是 `.github`）而本程序从根部起始，属内容差异而非绘制差异。

性能：整窗重绘 + BitBlt 单缓冲，空闲（光标闪烁）CPU 约 0.8%（4 秒 31ms），工作集 25MB，exe 约 300KB。

## 未完成

- 下方面板（问题/输出/终端/调试）内容与终端命令执行仍为近似；markdown 预览未做。
- Vim 还差视觉模式的 `J` / `>` / `<` / 缩进等命令；缩进宽度等编辑器选项尚未反作用到渲染（`vimCtrlKeys` 已接：打开后 Ctrl+F/B/R/A/X 交回普通编辑）。
- 命令面板/全局查找/快速打开有浮层但结果列表与交互未完整跑通。
- 编辑器右侧滚动条（Mayoi 是滚动时浮现的 overlay 样式）未实现。
- 本机没有在 PATH 上的 `git.exe`（已下载 MinGit 2.56.1 到 `C:\bin\mingit`，未加入 PATH，程序也不会自行找它）：「初始化仓库」「提交」仍只能给出「未找到 Git」提示。
- 设置的 63 项已能落盘到 `settings.json`，但字号、主题等尚未反作用到编辑器；`keybindings.json` 底部链接仅作展示，`用户` 范围选择未接文件夹级设置。
- 插件只做清单、启停、安装/删除/重载、列表与详情页（点卡片进入：名称、版本·作者、启用开关、目录、说明、插件设置；`docs/plugin-detail.png`）：没有 JS 运行时，插件的命令、`contributes`、格式化/language server 均不执行。
- 树菜单的「粘贴」恒灰（文件剪贴板未实现）；「在终端中打开」目前仅调用系统终端打开目录。
- 侧栏/菜单字体用 Segoe UI，参考（Skia）字形更细，近邻放大仍有可见的笔画差异。
