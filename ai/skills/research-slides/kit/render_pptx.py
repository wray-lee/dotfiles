"""Approximate PNG renderer for a .pptx (no Office on this machine).

Reads the saved file itself, so what is checked is what was written: pictures,
text boxes (wrapped with real Arial metrics), rectangles, rounded rectangles,
straight connectors and groups.  It also reports text that overflows its box
or the slide.  Usage: python render_pptx.py deck.pptx outdir
"""

from __future__ import annotations

import io
import os
import sys

from PIL import Image, ImageDraw, ImageFont
from pptx import Presentation
from pptx.enum.shapes import MSO_SHAPE_TYPE
from pptx.util import Emu

DPI = 150
FONTS = {(False, False): "arial.ttf", (True, False): "arialbd.ttf",
         (False, True): "ariali.ttf", (True, True): "arialbi.ttf"}
_cache: dict = {}


def font(px: float, bold: bool, italic: bool) -> ImageFont.FreeTypeFont:
    key = (round(px), bold, italic)
    if key not in _cache:
        _cache[key] = ImageFont.truetype(os.path.join(r"C:\Windows\Fonts", FONTS[(bold, italic)]), max(4, round(px)))
    return _cache[key]


def px(emu: float) -> float:
    return emu / 914400 * DPI


def hexcol(c, default=(0, 0, 0)):
    try:
        if c is not None and c.type is not None and c.rgb is not None:
            return tuple(int(str(c.rgb)[i:i + 2], 16) for i in (0, 2, 4))
    except Exception:
        pass
    return default


def runs_of(p):
    out = []
    for r in p.runs:
        f = r.font
        sz = f.size.pt if f.size else 18
        out.append((r.text, sz, bool(f.bold), bool(f.italic), hexcol(f.color, (26, 26, 26))))
    return out


def layout_para(p, width_px):
    """Return list of lines; each line = list of (text, font, color)."""
    rs = runs_of(p)
    if not rs:
        return [[]], 18
    words = []
    for t, sz, b, i, col in rs:
        f = font(sz / 72 * DPI, b, i)
        for k, w in enumerate(t.replace("\n", " \n ").split(" ")):
            words.append((w, f, col))
    lines, cur, curw = [], [], 0.0
    for w, f, col in words:
        if w == "\n":
            lines.append(cur); cur, curw = [], 0.0
            continue
        ww = f.getlength(w + " ")
        if cur and curw + f.getlength(w) > width_px:
            lines.append(cur); cur, curw = [], 0.0
        cur.append((w + " ", f, col)); curw += ww
    lines.append(cur)
    return lines, max(sz for _, sz, *_ in rs)


def draw_text(d, sh, x, y, w, h, problems, sname):
    tf = sh.text_frame
    ml = px(tf.margin_left or 0); mr = px(tf.margin_right or 0)
    mt = px(tf.margin_top or 0); mb = px(tf.margin_bottom or 0)
    inner = w - ml - mr
    blocks = []
    total = 0.0
    for p in tf.paragraphs:
        pPr = p._p.pPr
        marL = int(pPr.get("marL", 0)) if pPr is not None else 0
        bullet = pPr is not None and pPr.find("{http://schemas.openxmlformats.org/drawingml/2006/main}buChar") is not None
        lines, sz = layout_para(p, inner - px(marL))
        ls = p.line_spacing if isinstance(p.line_spacing, float) else 1.0
        lh = sz / 72 * DPI * 1.2 * ls
        sb = (p.space_before.pt / 72 * DPI) if p.space_before is not None else 0
        blocks.append((lines, lh, sb if blocks else 0, px(marL), bullet, p.alignment))
        total += (sb if len(blocks) > 1 else 0) + lh * len(lines)
    anchor = str(tf.vertical_anchor) if tf.vertical_anchor is not None else "TOP"
    yy = y + mt
    if "MIDDLE" in anchor:
        yy = y + (h - total) / 2
    elif "BOTTOM" in anchor:
        yy = y + h - mb - total
    if total > h + 2 and sh.text_frame.text.strip():
        problems.append(f"{sname}: text overflows box by {(total - h) / DPI:.2f} in: "
                        f"{sh.text_frame.text[:50]!r}")
    for lines, lh, sb, ind, bullet, al in blocks:
        yy += sb
        for li, line in enumerate(lines):
            lw = sum(f.getlength(t) for t, f, _ in line)
            xx = x + ml + ind
            if al is not None and "CENTER" in str(al):
                xx = x + ml + (inner - lw) / 2
            elif al is not None and "RIGHT" in str(al):
                xx = x + w - mr - lw
            if bullet and li == 0 and line:
                d.text((xx - px(0.24 * 914400), yy), "•", font=line[0][1], fill=line[0][2])
            if xx + lw > 13.333 * DPI + 4:
                problems.append(f"{sname}: text past right slide edge: {''.join(t for t, *_ in line)[:40]!r}")
            for t, f, col in line:
                d.text((xx, yy + (lh - f.size * 1.2) / 2), t, font=f, fill=col)
                xx += f.getlength(t)
            yy += lh
    if yy > 7.5 * DPI + 2 and sh.text_frame.text.strip():
        problems.append(f"{sname}: text below slide bottom: {sh.text_frame.text[:40]!r}")


def fillcol(sh):
    try:
        if sh.fill.type == 1:
            return hexcol(sh.fill.fore_color, (200, 200, 200))
    except Exception:
        pass
    return None


def linecol(sh):
    try:
        if sh.line.fill.type == 1:
            return hexcol(sh.line.color, (0, 0, 0)), max(1, round((sh.line.width or 9525) / 12700 / 72 * DPI))
    except Exception:
        pass
    return None, 0


def render_shapes(img, d, shapes, tx, problems, sname):
    for sh in shapes:
        if sh.left is None:
            continue
        x, y = tx(sh.left, sh.top)
        x2, y2 = tx(sh.left + sh.width, sh.top + sh.height)
        w, h = x2 - x, y2 - y
        if sh.shape_type == MSO_SHAPE_TYPE.GROUP:
            xfrm = sh._element.grpSpPr.find("{http://schemas.openxmlformats.org/drawingml/2006/main}xfrm")
            ns = "{http://schemas.openxmlformats.org/drawingml/2006/main}"
            off, ext = xfrm.find(ns + "off"), xfrm.find(ns + "ext")
            choff, chext = xfrm.find(ns + "chOff"), xfrm.find(ns + "chExt")
            ox, oy, ex, ey = int(off.get("x")), int(off.get("y")), int(ext.get("cx")), int(ext.get("cy"))
            cx, cy = int(choff.get("x")), int(choff.get("y"))
            cex, cey = int(chext.get("cx")) or 1, int(chext.get("cy")) or 1

            def sub(a, b, ox=ox, oy=oy, ex=ex, ey=ey, cx=cx, cy=cy, cex=cex, cey=cey):
                return tx(ox + (a - cx) * ex / cex, oy + (b - cy) * ey / cey)

            render_shapes(img, d, sh.shapes, sub, problems, sname)
            continue
        if sh.shape_type == MSO_SHAPE_TYPE.PICTURE:
            try:
                im = Image.open(io.BytesIO(sh.image.blob)).convert("RGBA")
                im = im.resize((max(1, round(w)), max(1, round(h))), Image.LANCZOS)
                img.paste(im, (round(x), round(y)), im)
            except Exception as e:
                d.rectangle([x, y, x2, y2], outline=(255, 0, 0))
            if x2 > 13.333 * DPI + 3 or y2 > 7.5 * DPI + 3:
                problems.append(f"{sname}: picture past slide edge ({x2 / DPI:.2f}, {y2 / DPI:.2f}) in")
            continue
        if sh.shape_type == MSO_SHAPE_TYPE.LINE or sh._element.tag.endswith("cxnSp"):
            col, lw = linecol(sh)
            d.line([x, y, x2, y2], fill=col or (0, 0, 0), width=lw or 1)
            continue
        fc = fillcol(sh)
        lc, lw = linecol(sh)
        if fc or lc:
            name = sh._element.xpath(".//a:prstGeom/@prst")
            prst = name[0] if name else "rect"
            box = [x, y, x2, y2]
            if prst == "roundRect":
                d.rounded_rectangle(box, radius=min(w, h) / 2, fill=fc, outline=lc, width=lw)
            elif prst == "ellipse":
                d.ellipse(box, fill=fc, outline=lc, width=lw)
            else:
                d.rectangle(box, fill=fc, outline=lc, width=lw)
        if sh.has_text_frame and sh.text_frame.text.strip():
            draw_text(d, sh, x, y, w, h, problems, sname)


def render(path: str, outdir: str) -> list[str]:
    os.makedirs(outdir, exist_ok=True)
    prs = Presentation(path)
    problems: list[str] = []
    W, H = round(13.333 * DPI), round(7.5 * DPI)
    thumbs = []
    for i, s in enumerate(prs.slides, 1):
        img = Image.new("RGB", (W, H), "white")
        d = ImageDraw.Draw(img)
        render_shapes(img, d, s.shapes, lambda a, b: (px(a), px(b)), problems, f"slide {i}")
        img.save(os.path.join(outdir, f"s{i:02d}.png"))
        thumbs.append(img)
    cols = 4
    tw, th = W // 3, H // 3
    rows = (len(thumbs) + cols - 1) // cols
    sheet = Image.new("RGB", (cols * (tw + 12) + 12, rows * (th + 12) + 12), (225, 228, 232))
    for k, im in enumerate(thumbs):
        sheet.paste(im.resize((tw, th), Image.LANCZOS), (12 + (k % cols) * (tw + 12), 12 + (k // cols) * (th + 12)))
    sheet.save(os.path.join(outdir, "contact.png"))
    return problems


if __name__ == "__main__":
    probs = render(sys.argv[1], sys.argv[2])
    print("\n".join(probs) if probs else "no overflow detected")
