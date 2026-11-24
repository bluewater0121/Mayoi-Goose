# MCP control channel

Mayoi listens on `127.0.0.1:7788` for newline-delimited JSON-RPC 2.0 messages,
the same shape an MCP server speaks over stdio. One request per line, one reply
per line.

Methods: `initialize`, `tools/list`, `tools/call`, `ping`.

Tools:

| tool | arguments | what it does |
| --- | --- | --- |
| `state` | — | current document size, caret, line/column, focus, vim mode |
| `type_text` | `text` | insert UTF-8 text at the caret without an IME |
| `key` | `key` or `vk`, plus `ctrl`/`shift`/`alt` | send a key (`backspace`, `enter`, `tab`, `escape`, arrows, letters) |
| `click` | `x`, `y` | press and release at app coordinates |
| `menu` | `id` | run a menu command by id, e.g. `file.new`, `file.settings`, `view.terminal` |
| `screenshot` | `region` (`editor` or `window`) | write a BMP frame and return its path |
| `doc_text` | — | the current document as text |

Menu ids are the command strings in `app/menu/model.goose` (`file.openFolder`,
`edit.find`, `go.quickOpen`, …), so any menu item can be driven without opening
the popup first.

Example:

```powershell
$c = New-Object Net.Sockets.TcpClient("127.0.0.1", 7788)
$w = New-Object IO.StreamWriter($c.GetStream())
$r = New-Object IO.StreamReader($c.GetStream())
$w.Write('{"jsonrpc":"2.0","id":1,"method":"tools/call","params":{"name":"type_text","arguments":{"text":"中文"}}}' + "`n")
$w.Flush()
$r.ReadLine()
```
