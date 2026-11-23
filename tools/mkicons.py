#!/usr/bin/env python3
"""Rasterize the Lucide icons Mayoi draws from cmd/mayoi/icons.go.

The Go source keeps each icon as an inline SVG body.  We parse that, flatten
curves and arcs into polylines, and draw them with a 4x supersampled round
stroke into 16x16 alpha masks.  Outputs:

  assets/icons/<name>.png   one preview per icon (white on transparent)
  assets/icons.h            C table of masks, consumed by src/plat.c
  icons_k.goose             goose constants so the app can name an icon
"""
import os, re, sys
from PIL import Image, ImageDraw

ROOT = os.path.dirname(os.path.abspath(__file__))
SRC = os.path.join(ROOT, "..", "reference", "Mayoi", "cmd", "mayoi", "icons.go")
OUT = os.path.join(ROOT, "..", "mayoi", "assets")
SIZE = 16          # final mask size, pixels
SS = 4             # supersampling factor
VIEW = 24.0        # viewBox of every lucide icon
STROKE = 2.0       # stroke width in view units

NUM = re.compile(r"[-+]?(?:\d*\.\d+|\d+\.?)")

# --- path data ---------------------------------------------------------------

def tokens(d):
    out, i = [], 0
    while i < len(d):
        c = d[i]
        if c in "MmLlHhVvCcSsQqTtAaZz":
            out.append(c); i += 1
        elif c in " \t\r\n,":
            i += 1
        else:
            m = NUM.match(d, i)
            if not m:
                i += 1
                continue
            out.append(float(m.group(0))); i = m.end()
    return out

def arc_points(x0, y0, rx, ry, rot, large, sweep, x1, y1, steps=12):
    """Sample an SVG elliptical arc; radii are already 24-unit values."""
    if rx == 0 or ry == 0:
        return [(x1, y1)]
    rx, ry = abs(rx), abs(ry)
    phi = rot * 3.14159265358979 / 180.0
    dx, dy = (x0 - x1) / 2.0, (y0 - y1) / 2.0
    cp, sp = __import__("math").cos(phi), __import__("math").sin(phi)
    x1p = cp * dx + sp * dy
    y1p = -sp * dx + cp * dy
    lam = (x1p * x1p) / (rx * rx) + (y1p * y1p) / (ry * ry)
    if lam > 1:
        s = lam ** 0.5
        rx, ry = rx * s, ry * s
    den = rx * rx * y1p * y1p + ry * ry * x1p * x1p
    num = rx * rx * ry * ry - den
    co = (num / den) ** 0.5 if den != 0 and num > 0 else 0.0
    if large == sweep:
        co = -co
    cxp = co * rx * y1p / ry
    cyp = -co * ry * x1p / rx
    cx = cp * cxp - sp * cyp + (x0 + x1) / 2.0
    cy = sp * cxp + cp * cyp + (y0 + y1) / 2.0
    import math
    def ang(ux, uy, vx, vy):
        d = math.atan2(ux * vy - uy * vx, ux * vx + uy * vy)
        return d
    a0 = ang(1, 0, (x1p - cxp) / rx, (y1p - cyp) / ry)
    a1 = ang((x1p - cxp) / rx, (y1p - cyp) / ry, (-x1p - cxp) / rx, (-y1p - cyp) / ry)
    if not sweep and a1 > 0:
        a1 -= 2 * math.pi
    elif sweep and a1 < 0:
        a1 += 2 * math.pi
    pts = []
    for k in range(1, steps + 1):
        a = a0 + (a1 - a0) * k / steps
        ex = cx + rx * math.cos(a) * cp - ry * math.sin(a) * sp
        ey = cy + rx * math.cos(a) * sp + ry * math.sin(a) * cp
        pts.append((ex, ey))
    return pts

def flatten_path(d):
    """Turn one SVG path into a list of polylines [(x,y), ...]."""
    t = tokens(d)
    lines, cur = [], []
    x = y = 0.0
    px = py = 0.0            # previous control point
    cmd = None
    i = 0
    def add(pt):
        cur.append(pt)
    def num():
        nonlocal i
        v = t[i]; i += 1
        return v
    while i < len(t):
        if isinstance(t[i], str):
            cmd = t[i]; i += 1
            if cmd in "Zz":
                if cur:
                    cur.append((x, y))
                    lines.append(cur)
                    cur = []
                px, py = x, y
                continue
        rel = cmd.islower()
        c = cmd.upper()
        if c == "M":
            nx, ny = num(), num()
            if rel:
                nx, ny = x + nx, y + ny
            if cur:
                cur.append((x, y))
                lines.append(cur)
            cur = [(nx, ny)]
            x, y = nx, ny
            px, py = x, y
            cmd = "l" if rel else "L"
        elif c == "L":
            nx, ny = num(), num()
            if rel:
                nx, ny = x + nx, y + ny
            cur.append((nx, ny)); px, py = nx, ny; x, y = nx, ny
        elif c == "H":
            nx = num()
            if rel:
                nx = x + nx
            cur.append((nx, y)); x = nx; px, py = x, y
        elif c == "V":
            ny = num()
            if rel:
                ny = y + ny
            cur.append((x, ny)); y = ny; px, py = x, y
        elif c == "C":
            x1, y1, x2, y2, x3, y3 = (num() for _ in range(6))
            if rel:
                x1, y1 = x + x1, y + y1
                x2, y2 = x + x2, y + y2
                x3, y3 = x + x3, y + y3
            for k in range(1, 11):
                u = k / 10.0
                bx = (1-u)**3*x + 3*(1-u)**2*u*x1 + 3*(1-u)*u*u*x2 + u**3*x3
                by = (1-u)**3*y + 3*(1-u)**2*u*y1 + 3*(1-u)*u*u*y2 + u**3*y3
                cur.append((bx, by))
            px, py = x2, y2; x, y = x3, y3
        elif c == "S":
            x2, y2, x3, y3 = (num() for _ in range(4))
            if rel:
                x2, y2 = x + x2, y + y2
                x3, y3 = x + x3, y + y3
            x1, y1 = 2*x - px, 2*y - py
            for k in range(1, 11):
                u = k / 10.0
                bx = (1-u)**3*x + 3*(1-u)**2*u*x1 + 3*(1-u)*u*u*x2 + u**3*x3
                by = (1-u)**3*y + 3*(1-u)**2*u*y1 + 3*(1-u)*u*u*y2 + u**3*y3
                cur.append((bx, by))
            px, py = x2, y2; x, y = x3, y3
        elif c == "Q":
            x1, y1, x2, y2 = (num() for _ in range(4))
            if rel:
                x1, y1 = x + x1, y + y1
                x2, y2 = x + x2, y + y2
            for k in range(1, 9):
                u = k / 8.0
                bx = (1-u)**2*x + 2*(1-u)*u*x1 + u*u*x2
                by = (1-u)**2*y + 2*(1-u)*u*y1 + u*u*y2
                cur.append((bx, by))
            px, py = x1, y1; x, y = x2, y2
        elif c == "T":
            x2, y2 = num(), num()
            if rel:
                x2, y2 = x + x2, y + y2
            x1, y1 = 2*x - px, 2*y - py
            for k in range(1, 9):
                u = k / 8.0
                bx = (1-u)**2*x + 2*(1-u)*u*x1 + u*u*x2
                by = (1-u)**2*y + 2*(1-u)*u*y1 + u*u*y2
                cur.append((bx, by))
            px, py = x1, y1; x, y = x2, y2
        elif c == "A":
            rx, ry, rot, large, sweep, nx, ny = (num() for _ in range(7))
            if rel:
                nx, ny = x + nx, y + ny
            for pt in arc_points(x, y, rx, ry, rot, int(large), int(sweep), nx, ny):
                cur.append(pt)
            px, py = x, y; x, y = nx, ny
        else:
            i += 1
    if cur:
        lines.append(cur)
    return lines

def ellipse(cx, cy, rx, ry, steps=48):
    import math
    return [((cx + rx * math.cos(a * 2 * math.pi / steps),
              cy + ry * math.sin(a * 2 * math.pi / steps)), ) for a in range(steps)]

def circle_pts(cx, cy, r, steps=48):
    import math
    return [(cx + r * math.cos(a * 2 * math.pi / steps),
             cy + r * math.sin(a * 2 * math.pi / steps)) for a in range(steps + 1)]

def rounded_rect(x, y, w, h, r, steps=8):
    import math
    pts = []
    corners = [(x + w - r, y + h - r, -math.pi/2, 0),
               (x + w - r, y + r, 0, math.pi/2),
               (x + r, y + r, math.pi/2, math.pi),
               (x + r, y + h - r, math.pi, 1.5*math.pi)]
    for cx, cy, a0, a1 in corners:
        for k in range(steps + 1):
            a = a0 + (a1 - a0) * k / steps
            pts.append((cx + r * math.cos(a), cy + r * math.sin(a)))
    pts.append(pts[0])
    return pts

def attr(el, name, default=0.0):
    m = re.search(name + r'\s*=\s*"([^"]*)"', el)
    return float(m.group(1)) if m else default

def body_polylines(body):
    out = []
    for el in re.findall(r"<(path|circle|rect|line|polyline|polygon)\b[^>]*/?>", body):
        pass
    for el in re.findall(r"<(?:path|circle|rect|line|polyline|polygon)\b[^>]*>", body):
        tag = re.match(r"<(\w+)", el).group(1)
        if tag == "path":
            d = re.search(r'\bd\s*=\s*"([^"]*)"', el)
            if d:
                out += flatten_path(d.group(1))
        elif tag == "circle":
            out.append(circle_pts(attr(el, "cx"), attr(el, "cy"), attr(el, "r")))
        elif tag == "rect":
            rx = attr(el, "rx", 0.0) or attr(el, "ry", 0.0)
            out.append(rounded_rect(attr(el, "x"), attr(el, "y"),
                                    attr(el, "width"), attr(el, "height"), rx))
        elif tag == "line":
            out.append([(attr(el, "x1"), attr(el, "y1")), (attr(el, "x2"), attr(el, "y2"))])
        elif tag in ("polyline", "polygon"):
            pts = re.search(r'\bpoints\s*=\s*"([^"]*)"', el)
            if pts:
                v = [float(v) for v in NUM.findall(pts.group(1))]
                poly = [(v[k], v[k+1]) for k in range(0, len(v) - 1, 2)]
                if tag == "polygon" and poly:
                    poly.append(poly[0])
                out.append(poly)
    return out

# --- raster ------------------------------------------------------------------

def raster(polys):
    k = SIZE * SS / VIEW
    big = Image.new("L", (SIZE * SS, SIZE * SS), 0)
    dr = ImageDraw.Draw(big)
    wid = max(1, int(round(STROKE * k)))
    rad = wid / 2.0
    for poly in polys:
        pts = [(p[0] * k, p[1] * k) for p in poly]
        for a, b in zip(pts, pts[1:]):
            dr.line([a, b], fill=255, width=wid, joint="curve")
        for p in pts:
            dr.ellipse([p[0] - rad, p[1] - rad, p[0] + rad, p[1] + rad], fill=255)
    return big.resize((SIZE, SIZE), Image.LANCZOS)

def main():
    text = open(SRC, encoding="utf-8").read()
    icons = []
    for m in re.finditer(r'\n\s*(icon\w+)\s+= lucide(?:SVG)?\(`(.*?)`\)', text, re.S):
        name, body = m.group(1), m.group(2)
        polys = body_polylines(body)
        if not polys:
            print("no shapes:", name, file=sys.stderr)
            continue
        icons.append((name[len("icon"):], polys))
    os.makedirs(os.path.join(OUT, "icons"), exist_ok=True)

    def snake(s):
        return re.sub(r'(?<=[a-z0-9])(?=[A-Z])|(?<=[A-Z])(?=[A-Z][a-z])', '_', s).lower()

    entries = []
    for name, polys in icons:
        img = raster(polys)
        img.save(os.path.join(OUT, "icons", snake(name) + ".png"))
        entries.append((snake(name), img))

    with open(os.path.join(OUT, "icons.h"), "w", encoding="utf-8") as f:
        f.write("/* generated by tools/mkicons.py from cmd/mayoi/icons.go */\n")
        f.write("#define GS_ICON_COUNT %d\n" % len(entries))
        f.write("static const struct { const char *name; unsigned char a[%d]; } gs_icons[] = {\n"
                % (SIZE * SIZE))
        for name, img in entries:
            px = list(img.getdata())
            f.write('  {"%s", {' % name)
            f.write(",".join(str(v) for v in px))
            f.write("}},\n")
        f.write("};\n")

    with open(os.path.join(ROOT, "..", "mayoi", "ui", "icons.goose"), "w", encoding="utf-8") as f:
        f.write("// Generated by tools/mkicons.py: indices into the mask table in src/plat.c.\n")
        f.write("namespace icons;\n\n")
        for i, (name, _) in enumerate(entries):
            f.write("let %s = %d;\n" % (name.upper(), i))
        f.write("\nlet COUNT = %d;\n" % len(entries))
    print("icons: %d" % len(entries))

if __name__ == "__main__":
    main()



