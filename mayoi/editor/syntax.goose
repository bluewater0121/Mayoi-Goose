// Line-at-a-time lexers, enough for the languages an editor shows first.
namespace syntax;

import std;
import app.state;
import editor.text;
import ui.theme;

let S_NONE = 0; let S_COMMENT = 1; let S_RAW = 2;

struct Span { a: i32, b: i32, k: i64 }

var states: i32[>..] = [];
var states_upto: i32 = 0;
var states_doc: i32 = -1;
var states_len: i64 = -1;

fn reset() {
    states.resize(0);
    states_upto = 0;
    states_doc = -1;
    states_len = -1;
}

fn is_word(c: u8) -> bool {
    return (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') || (c >= '0' && c <= '9') ||
           c == '_' || c == '$' || c >= 0x80;
}

fn is_digit(c: u8) -> bool { return c >= '0' && c <= '9'; }

fn eqc(s: const u8[:], i: i64, lit: const u8[:]) -> bool {
    if i + lit.len > s.len { return false; }
    var k: i64 = 0;
    while k < lit.len { if s[i + k] != lit[k] { return false; } k++; }
    return true;
}

fn kw(w: const u8[:], lang: i32) -> i32 {
    if lang == 1 {
        if w == "func" || w == "var" || w == "const" || w == "type" || w == "struct" ||
           w == "interface" || w == "map" || w == "chan" || w == "range" || w == "for" ||
           w == "if" || w == "else" || w == "return" || w == "go" || w == "defer" ||
           w == "select" || w == "case" || w == "default" || w == "switch" || w == "break" ||
           w == "continue" || w == "goto" || w == "package" || w == "import" || w == "fallthrough" {
            return theme::KEYWORD;
        }
        if w == "true" || w == "false" || w == "nil" || w == "iota" { return theme::CONST; }
        if w == "int" || w == "int64" || w == "int32" || w == "uint" || w == "byte" ||
           w == "string" || w == "bool" || w == "float64" || w == "float32" || w == "error" ||
           w == "any" || w == "rune" || w == "uint64" || w == "uint32" { return theme::TYPE; }
        if w == "append" || w == "make" || w == "len" || w == "cap" || w == "new" ||
           w == "copy" || w == "delete" || w == "panic" || w == "recover" || w == "print" ||
           w == "println" || w == "close" || w == "complex" || w == "real" || w == "imag" {
            return theme::BUILTIN;
        }
        return theme::PLAIN;
    }
    if lang == 2 {
        if w == "function" || w == "const" || w == "let" || w == "var" || w == "class" ||
           w == "extends" || w == "return" || w == "if" || w == "else" || w == "for" ||
           w == "while" || w == "do" || w == "switch" || w == "case" || w == "break" ||
           w == "continue" || w == "new" || w == "this" || w == "import" || w == "export" ||
           w == "from" || w == "default" || w == "try" || w == "catch" || w == "finally" ||
           w == "throw" || w == "async" || w == "await" || w == "typeof" || w == "instanceof" ||
           w == "of" || w == "in" || w == "yield" || w == "static" || w == "get" || w == "set" ||
           w == "interface" || w == "type" || w == "implements" || w == "enum" || w == "as" {
            return theme::KEYWORD;
        }
        if w == "true" || w == "false" || w == "null" || w == "undefined" || w == "NaN" {
            return theme::CONST;
        }
        if w == "console" || w == "JSON" || w == "Math" || w == "Promise" || w == "Array" ||
           w == "Object" || w == "String" || w == "Number" || w == "document" || w == "window" {
            return theme::BUILTIN;
        }
        return theme::PLAIN;
    }
    if lang == 3 {
        if w == "def" || w == "class" || w == "import" || w == "from" || w == "return" ||
           w == "if" || w == "elif" || w == "else" || w == "for" || w == "while" || w == "in" ||
           w == "not" || w == "and" || w == "or" || w == "is" || w == "with" || w == "as" ||
           w == "try" || w == "except" || w == "finally" || w == "raise" || w == "lambda" ||
           w == "yield" || w == "global" || w == "nonlocal" || w == "assert" || w == "del" ||
           w == "pass" || w == "async" || w == "await" { return theme::KEYWORD; }
        if w == "True" || w == "False" || w == "None" || w == "self" { return theme::CONST; }
        if w == "print" || w == "len" || w == "range" || w == "str" || w == "int" ||
           w == "list" || w == "dict" || w == "set" || w == "tuple" || w == "open" { return theme::BUILTIN; }
        return theme::PLAIN;
    }
    if lang == 4 {
        if w == "fn" || w == "let" || w == "mut" || w == "impl" || w == "struct" || w == "enum" ||
           w == "pub" || w == "use" || w == "mod" || w == "crate" || w == "return" || w == "if" ||
           w == "else" || w == "match" || w == "for" || w == "while" || w == "loop" || w == "in" ||
           w == "move" || w == "ref" || w == "where" || w == "trait" || w == "type" || w == "const" ||
           w == "static" || w == "as" || w == "dyn" || w == "async" || w == "await" || w == "unsafe" ||
           w == "break" || w == "continue" || w == "self" || w == "Self" { return theme::KEYWORD; }
        if w == "true" || w == "false" || w == "None" || w == "Some" || w == "Ok" || w == "Err" {
            return theme::CONST;
        }
        if w == "i32" || w == "i64" || w == "u8" || w == "u16" || w == "u32" || w == "u64" ||
           w == "f32" || w == "f64" || w == "usize" || w == "String" || w == "Vec" || w == "Option" ||
           w == "Result" || w == "Box" { return theme::TYPE; }
        return theme::PLAIN;
    }
    if lang == 5 {
        if w == "int" || w == "char" || w == "void" || w == "struct" || w == "union" ||
           w == "enum" || w == "typedef" || w == "const" || w == "static" || w == "unsigned" ||
           w == "signed" || w == "long" || w == "short" || w == "float" || w == "double" ||
           w == "return" || w == "if" || w == "else" || w == "for" || w == "while" || w == "do" ||
           w == "switch" || w == "case" || w == "break" || w == "continue" || w == "sizeof" ||
           w == "extern" || w == "inline" || w == "class" || w == "namespace" || w == "template" ||
           w == "auto" || w == "new" || w == "delete" || w == "public" || w == "private" ||
           w == "protected" || w == "virtual" || w == "override" || w == "using" || w == "nullptr" {
            return theme::KEYWORD;
        }
        if w == "NULL" || w == "true" || w == "false" { return theme::CONST; }
        if w == "size_t" || w == "uint8_t" || w == "uint16_t" || w == "uint32_t" ||
           w == "uint64_t" || w == "int32_t" || w == "int64_t" || w == "bool" || w == "string" {
            return theme::TYPE;
        }
        return theme::PLAIN;
    }
    if lang == 8 {
        if w == "if" || w == "then" || w == "else" || w == "fi" || w == "for" || w == "while" ||
           w == "do" || w == "done" || w == "case" || w == "esac" || w == "function" ||
           w == "export" || w == "local" || w == "return" || w == "in" { return theme::KEYWORD; }
        if w == "echo" || w == "cd" || w == "ls" || w == "cat" || w == "grep" || w == "sed" ||
           w == "awk" || w == "sudo" || w == "git" || w == "go" || w == "make" { return theme::BUILTIN; }
        return theme::PLAIN;
    }
    if lang == 10 {
        if w == "true" || w == "false" || w == "null" || w == "yes" || w == "no" { return theme::CONST; }
        return theme::PLAIN;
    }
    return theme::PLAIN;
}

fn cap_after(e: i32) -> bool { return e == theme::KEYWORD; }

fn scan_word(s: const u8[:], i: i64, b: i64) -> i64 {
    var k = i;
    while k < b && is_word(s[k]) { k++; }
    return k;
}

// lex_line appends spans for the line [a,b) of document i and returns the state
// the next line starts in.
fn lex_line(i: i32, a: i64, b: i64, st: i32, out: Span[>..]&) -> i32 {
    let d .= state::docs[i];
    let lang = d.lang;
    var p = a;
    var state = st;
    let base = a as i32;
    if lang == 7 { return lex_md(i, a, b, out); }
    if state == S_COMMENT {
        var e = p;
        while e < b {
            if e + 1 < b && state::arena[d.off + e] == '*' && state::arena[d.off + e + 1] == '/' {
                e += 2;
                out.push(Span { base, (e - a) as i32, theme::COMMENT });
                return S_NONE;
            }
            e++;
        }
        out.push(Span { base, (b - a) as i32, theme::COMMENT });
        return S_COMMENT;
    }
    if state == S_RAW {
        var e = p;
        while e < b {
            if state::arena[d.off + e] == '`' {
                e++;
                out.push(Span { base, (e - a) as i32, theme::STRING });
                return S_NONE;
            }
            e++;
        }
        out.push(Span { base, (b - a) as i32, theme::STRING });
        return S_RAW;
    }
    while p < b {
        let c = state::arena[d.off + p];
        if c == ' ' || c == '\t' { p++; }
        else if c == '/' && p + 1 < b && state::arena[d.off + p + 1] == '/' {
            out.push(Span { (p - a) as i32, (b - a) as i32, theme::COMMENT });
            return S_NONE;
        } else if c == '/' && p + 1 < b && state::arena[d.off + p + 1] == '*' {
            var e = p + 2;
            var closed = false;
            while e + 1 < b {
                if state::arena[d.off + e] == '*' && state::arena[d.off + e + 1] == '/' {
                    e += 2; closed = true; break;
                }
                e++;
            }
            if !closed { e = b; }
            out.push(Span { (p - a) as i32, (e - a) as i32, theme::COMMENT });
            if !closed { return S_COMMENT; }
            p = e;
        } else if c == '#' && (lang == 3 || lang == 8 || lang == 10) {
            out.push(Span { (p - a) as i32, (b - a) as i32, theme::COMMENT });
            return S_NONE;
        } else if c == '"' || c == '\'' || (c == '`' && lang == 1) {
            let q = c;
            var e = p + 1;
            var closed = false;
            while e < b {
                let ch = state::arena[d.off + e];
                if ch == '\\' { e += 2; continue; }
                if ch == q { e++; closed = true; break; }
                e++;
            }
            if !closed && q == '`' {
                out.push(Span { (p - a) as i32, (b - a) as i32, theme::STRING });
                return S_RAW;
            }
            if !closed { e = b; }
            out.push(Span { (p - a) as i32, (e - a) as i32, theme::STRING });
            p = e;
        } else if is_digit(c) || (c == '.' && p + 1 < b && is_digit(state::arena[d.off + p + 1])) {
            var e = p;
            var seen_e = false;
            while e < b {
                let ch = state::arena[d.off + e];
                if is_digit(ch) || ch == '_' || ch == '.' || (ch >= 'a' && ch <= 'f') ||
                   (ch >= 'A' && ch <= 'F') || ch == 'x' || ch == 'X' ||
                   (ch == 'e' && !seen_e) { if ch == 'e' { seen_e = true; } e++; }
                else if (ch == '+' || ch == '-') && e > p && (state::arena[d.off+e-1] == 'e') { e++; }
                else { break; }
            }
            out.push(Span { (p - a) as i32, (e - a) as i32, theme::NUMBER });
            p = e;
        } else if is_word(c) {
            let e = scan_word(state::arena[d.off .. d.off + b], p, b);
            let w = state::arena[d.off + p .. d.off + e];
            var k = kw(w, lang);
            var q = e;
            while q < b && (state::arena[d.off + q] == ' ' || state::arena[d.off + q] == '\t') { q++; }
            if k == theme::PLAIN && q < b && state::arena[d.off + q] == '(' && !is_digit(c) {
                k = theme::FUNC;
            }
            if k == theme::PLAIN && lang == 6 {
                if q < b && state::arena[d.off + q] == '"' { k = theme::ATTR; }
            }
            out.push(Span { (p - a) as i32, (e - a) as i32, k });
            p = e;
        } else if c == '<' && lang == 9 {
            var e = p;
            while e < b && state::arena[d.off + e] != '>' { e++; }
            if e < b { e++; }
            out.push(Span { (p - a) as i32, (e - a) as i32, theme::TAG });
            p = e;
        } else {
            let k = if c == '(' || c == ')' || c == '[' || c == ']' || c == '{' || c == '}' ||
                     c == ',' || c == ';' || c == ':' { theme::PUNCT } else { theme::OPERATOR };
            out.push(Span { (p - a) as i32, (p - a + 1) as i32, k });
            p++;
        }
    }
    return S_NONE;
}

// Markdown is line-shaped: headings, bullets, quotes, fences and inline marks.
fn lex_md(i: i32, a: i64, b: i64, out: Span[>..]&) -> i32 {
    let d .= state::docs[i];
    let base = a as i32;
    var p = a;
    while p < b && (state::arena[d.off + p] == ' ' || state::arena[d.off + p] == '\t') { p++; }
    if p < b && state::arena[d.off + p] == '#' {
        out.push(Span { base, (b - a) as i32, theme::HEADING });
        return S_NONE;
    }
    if p < b && state::arena[d.off + p] == '`' && p + 2 < b && state::arena[d.off + p + 1] == '`' {
        out.push(Span { base, (b - a) as i32, theme::COMMENT });
        return S_NONE;
    }
    var q = a;
    while q < b {
        let c = state::arena[d.off + q];
        if c == '-' && q == p { out.push(Span { (q - a) as i32, (q - a + 1) as i32, theme::KEYWORD }); q++; }
        else if c == '*' && q + 1 < b && state::arena[d.off + q + 1] == '*' {
            let e = find_close(i, q + 2, b, '*');
            out.push(Span { (q - a) as i32, (e - a) as i32, theme::CONST });
            q = e;
        }
        else if c == '`' {
            let e = find_close(i, q + 1, b, '`');
            out.push(Span { (q - a) as i32, (e - a) as i32, theme::STRING });
            q = e;
        }
        else if c == '[' {
            let e = find_close(i, q + 1, b, ']');
            out.push(Span { (q - a) as i32, (e - a) as i32, theme::FUNC });
            q = e;
        }
        else { q++; }
    }
    return S_NONE;
}

fn find_close(i: i32, from: i64, b: i64, ch: u8) -> i64 {
    let d .= state::docs[i];
    var k = from;
    while k < b {
        if state::arena[d.off + k] == ch { return k + 1; }
        k++;
    }
    return b;
}

fn state_at(i: i32, line: i32) -> i32 {
    let d .= state::docs[i];
    if states_doc != i || states_len != d.len {
        states.resize(0);
        states.push(0);
        states_upto = 1;
        states_doc = i;
        states_len = d.len;
    }
    var tmp: Span[>..] = [];
    while states_upto <= line {
        let l = states_upto - 1;
        let a = text::line_start(l);
        let b = text::line_end(l);
        let st = states[states_upto - 1];
        let next = lex_line(i, a, b, st, tmp);
        tmp.resize(0);
        states.push(next);
        states_upto++;
    }
    return states[line];
}

fn invalidate() {
    states_upto = 0;
    states.resize(0);
    states_doc = -1;
}


