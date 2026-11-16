"""House-style kit for research progress-report decks (python-pptx).

Master theme, colours and typography come from the user's July 2026
progress-report deck (``assets/master_progress.pptx``, slides stripped): plain
Arial, near-black ink, one blue accent.  Every helper enforces the house
rules at creation time -- body text at least 20 pt, captions and page
furniture at least 12 pt, literature figures at least 2.3x their 300-dpi
print size -- and ``self_check`` re-audits the finished deck.

Typical build::

    import deck_kit as kit

    prs = kit.new_deck()
    s = kit.blank(prs)
    kit.header(s, "RESULTS", "Wind shortens latency only at early SOAs")
    kit.fig(s, "panel_a.png", 0.55, 1.30, 8.0, 4.9, "Evans et al., 2019")
    kit.body(s, 8.75, 1.30, 4.0, 4.9, "One sentence.")
    kit.foot(s)
    kit.notes(s, "早 SOA 才变快", "English ...", "中文 ...")
    prs.save("deck.pptx")
"""

from __future__ import annotations

import io
import os
import re
from collections.abc import Sequence
from pathlib import Path
from typing import Any

from lxml import etree
from PIL import Image as PILImage
from pptx import Presentation
from pptx.dml.color import RGBColor
from pptx.enum.shapes import MSO_CONNECTOR, MSO_SHAPE, MSO_SHAPE_TYPE
from pptx.enum.text import MSO_ANCHOR, MSO_AUTO_SIZE, PP_ALIGN
from pptx.oxml.ns import qn
from pptx.parts.image import Image as PptxImage
from pptx.shapes.autoshape import Shape
from pptx.shapes.connector import Connector
from pptx.shapes.picture import Picture
from pptx.slide import Slide
from pptx.util import Inches, Pt

# ----------------------------------------------------------------- palette
FONT = "Arial"
INK = "1A1A1A"
MUTED = "6B7280"
ACCENT = "2B6CB0"
WIND = "DD6B20"
ACC = "B83232"
RULE = "CBD2D9"
PALE = "F3F5F7"

L, W = 0.55, 12.23  # left margin and content width, inches
SLIDE_W, SLIDE_H = 13.333, 7.5

MASTER = Path(__file__).resolve().parents[1] / "assets" / "master_progress.pptx"
FIGURES: Path | None = None

_PAGE = [0]
_MAGS: list[tuple[str, float, float]] = []  # (name, magnification, floor)


def set_figures(path: str | os.PathLike[str] | None) -> None:
    """Directory used to resolve relative paths passed to fig()/schem()."""
    global FIGURES
    FIGURES = Path(path).resolve() if path is not None else None


# -------------------------------------------------------------- primitives
def _rgb(h: str) -> RGBColor:
    return RGBColor.from_string(h)


def _runs(text: str) -> list[tuple[str, bool, str | None]]:
    """**bold**, and {{red}} / [[blue]] / <<orange>> inline colour markup."""
    out: list[tuple[str, bool, str | None]] = []
    for tok in re.split(r"(\*\*.*?\*\*|\{\{.*?\}\}|\[\[.*?\]\]|<<.*?>>)", text):
        if not tok:
            continue
        if tok.startswith("**"):
            out.append((tok[2:-2], True, None))
        elif tok.startswith("{{"):
            out.append((tok[2:-2], True, ACC))
        elif tok.startswith("[["):
            out.append((tok[2:-2], True, ACCENT))
        elif tok.startswith("<<"):
            out.append((tok[2:-2], True, WIND))
        else:
            out.append((tok, False, None))
    return out


def text(slide: Slide, x: float, y: float, w: float, h: float,
         paras: str | Sequence[str], size: float = 16, color: str = INK,
         bold: bool = False, align: str = "left", anchor: str = "top",
         italic: bool = False, bullet: bool = False, space: float = 6,
         line: float = 1.08) -> Shape:
    """Add a text box; ``paras`` is a string or a list of paragraphs.

    Inline markup: ``**bold**``, ``{{red}}``, ``[[blue]]``, ``<<orange>>``.
    """
    assert size >= 12 - 1e-6, "captions and furniture must be at least 12 pt"
    if isinstance(paras, str):
        paras = [paras]
    tb = slide.shapes.add_textbox(Inches(x), Inches(y), Inches(w), Inches(h))
    tf = tb.text_frame
    tf.word_wrap = True
    tf.auto_size = MSO_AUTO_SIZE.NONE
    tf.vertical_anchor = {"top": MSO_ANCHOR.TOP, "middle": MSO_ANCHOR.MIDDLE,
                          "bottom": MSO_ANCHOR.BOTTOM}[anchor]
    for m in ("margin_left", "margin_right", "margin_top", "margin_bottom"):
        setattr(tf, m, Inches(0.0))
    for i, ptxt in enumerate(paras):
        p = tf.paragraphs[0] if i == 0 else tf.add_paragraph()
        p.alignment = {"left": PP_ALIGN.LEFT, "center": PP_ALIGN.CENTER,
                       "right": PP_ALIGN.RIGHT}[align]
        p.line_spacing = line
        if i:
            p.space_before = Pt(space)
        if bullet:
            pPr = p._p.get_or_add_pPr()
            pPr.set("marL", str(int(0.24 * 914400)))
            pPr.set("indent", str(int(-0.24 * 914400)))
            bf = etree.SubElement(pPr, qn("a:buFont"))
            bf.set("typeface", FONT)
            bc = etree.SubElement(pPr, qn("a:buChar"))
            bc.set("char", "•")
        for t, b, c in _runs(ptxt):
            r = p.add_run()
            r.text = t
            f = r.font
            f.name = FONT
            f.size = Pt(size)
            f.bold = bold or b
            f.italic = italic
            f.color.rgb = _rgb(c or color)
            rPr = r._r.get_or_add_rPr()
            for tagname in ("a:ea", "a:cs"):
                e = rPr.find(qn(tagname))
                if e is None:
                    e = etree.SubElement(rPr, qn(tagname))
                e.set("typeface", FONT)
    return tb


def rect(slide: Slide, x: float, y: float, w: float, h: float,
         fill: str | None = None, line: str | None = None,
         lw: float = 0.75) -> Shape:
    s = slide.shapes.add_shape(MSO_SHAPE.RECTANGLE, Inches(x), Inches(y),
                               Inches(w), Inches(h))
    if fill:
        s.fill.solid()
        s.fill.fore_color.rgb = _rgb(fill)
    else:
        s.fill.background()
    if line:
        s.line.color.rgb = _rgb(line)
        s.line.width = Pt(lw)
    else:
        s.line.fill.background()
    s.shadow.inherit = False
    return s


def hline(slide: Slide, x: float, y: float, w: float,
          color: str = RULE, lw: float = 0.75) -> Connector:
    c = slide.shapes.add_connector(MSO_CONNECTOR.STRAIGHT, Inches(x),
                                   Inches(y), Inches(x + w), Inches(y))
    c.line.color.rgb = _rgb(color)
    c.line.width = Pt(lw)
    return c


def pic(slide: Slide, path: str | os.PathLike[str], x: float, y: float,
        w: float | None = None, h: float | None = None) -> Picture:
    kw: dict[str, Any] = {}
    if w is not None:
        kw["width"] = Inches(w)
    if h is not None:
        kw["height"] = Inches(h)
    return slide.shapes.add_picture(str(path), Inches(x), Inches(y), **kw)


# ------------------------------------------------------------- image sizes
def _resolve(path: str | os.PathLike[str]) -> Path:
    p = Path(path)
    if p.is_absolute():
        return p
    return (FIGURES / p) if FIGURES is not None else Path.cwd() / p


def _pil_dpi(im: PILImage.Image) -> float:
    """Print resolution of a crop, defaulting to 300 dpi when unlabelled."""
    dpi = im.info.get("dpi")
    try:
        value = float(dpi[0])  # type: ignore[index]
    except (TypeError, ValueError, IndexError):
        return 300.0
    return value if 50.0 <= value <= 1200.0 else 300.0


def _pptx_dpi(img: PptxImage) -> float:
    with PILImage.open(io.BytesIO(img.blob)) as im:
        return _pil_dpi(im)


def _fit(path: Path, maxw: float, maxh: float,
         ) -> tuple[float, float, float, float]:
    """Return (width, height, pixel width, dpi) that fits the box."""
    with PILImage.open(path) as im:
        ar = im.width / im.height
        pxw = im.width
        dpi = _pil_dpi(im)
    w, h = maxw, maxw / ar
    if h > maxh:
        h, w = maxh, maxh * ar
    return w, h, pxw, dpi


def fig(slide: Slide, path: str | os.PathLike[str], x: float,
        y: float | None, maxw: float, maxh: float, src: str = "",
        minmag: float = 2.3, bottom: float | None = None,
        ) -> tuple[float, float, float, float]:
    """Place a literature crop, assert its magnification, cite it below.

    ``minmag`` is relative to the crop's print size at its stated dpi (300
    dpi for unlabelled crops): 2.3 for main slides, 1.8 for backups.
    ``bottom`` may replace ``y`` to place the figure so that its lower edge
    sits at that height.
    """
    p = _resolve(path)
    w, h, pxw, dpi = _fit(p, maxw, maxh)
    if bottom is not None:
        y = bottom - h
    assert y is not None, "give y or bottom"
    mag = w / (pxw / dpi)
    assert mag >= minmag - 1e-6, f"{p.name}: magnification {mag:.2f} < {minmag}"
    pic(slide, p, x, y, w=w, h=h)
    if src:
        cite(slide, x, y + h + 0.02, max(w, 2.8), src)
    print(f"  {p.name:28s} {w:5.2f} x {h:5.2f} in   mag {mag:.2f}")
    _MAGS.append((p.name, mag, minmag))
    return x, y, w, h


def schem(slide: Slide, path: str | os.PathLike[str], x: float, y: float,
          src: str = "") -> tuple[float, float, float, float]:
    """Place a schematic drawn at final size (its fonts already in slide pt)."""
    p = _resolve(path)
    with PILImage.open(p) as im:
        dpi = _pil_dpi(im)
        w, h = im.width / dpi, im.height / dpi
    picture = pic(slide, p, x, y, w=w, h=h)
    picture.name = "SCHEM_" + p.stem
    if src:
        cite(slide, x, y + h + 0.02, max(w, 3.5), src)
    return x, y, w, h


def cite(slide: Slide, x: float, y: float, w: float, text_: str) -> Shape:
    """A figure citation (12 pt muted), always under the figure itself."""
    return text(slide, x, y, w, 0.24, text_, size=12, color=MUTED)


# ---------------------------------------------------------------- frame
def new_deck(master: str | os.PathLike[str] = MASTER) -> Presentation:
    """Load the house master with all slides stripped; reset page numbers."""
    prs = Presentation(str(master))
    sld_ids = prs.slides._sldIdLst
    for sid in list(sld_ids):
        prs.part.drop_rel(sid.get(qn("r:id")))
        sld_ids.remove(sid)
    _PAGE[0] = 0
    _MAGS.clear()
    return prs


def blank(prs: Presentation) -> Slide:
    """Add an empty blank-layout slide and advance the page counter."""
    layout = next(
        (lay for lay in prs.slide_layouts if len(lay.placeholders) == 0),
        prs.slide_layouts[6],
    )
    s = prs.slides.add_slide(layout)
    _PAGE[0] += 1
    for sh in list(s.shapes):
        sh._element.getparent().remove(sh._element)
    return s


def header(slide: Slide, section: str, title: str) -> None:
    """Section label (12 pt accent caps) and title (28 pt bold)."""
    text(slide, L, 0.30, 8.0, 0.26, section.upper(), size=12, color=ACCENT,
         bold=True)
    text(slide, L, 0.55, W, 0.62, title, size=28, bold=True, anchor="top")


def body(slide: Slide, x: float, y: float, w: float, h: float,
         paras: str | Sequence[str], size: float = 22,
         **kw: Any) -> Shape:
    """Body text; asserts the 20 pt floor and tags the box for self_check."""
    assert size >= 20 - 1e-6, "body text must be at least 20 pt"
    tb = text(slide, x, y, w, h, paras, size=size, **kw)
    tb.name = "Body"
    return tb


def foot(slide: Slide, citation: str = "") -> None:
    """Page number bottom-right (automatic) and optional citation left."""
    if citation:
        text(slide, L, 7.06, 11.3, 0.26, citation, size=12, color=MUTED)
    text(slide, 12.18, 7.06, 0.60, 0.26, str(_PAGE[0]), size=12, color=MUTED,
         align="right")


def notes(slide: Slide, cue: str, en: str, zh: str) -> None:
    """Bilingual speaker notes: cue, English, then Chinese."""
    assert "\n" not in cue.strip(), "the cue is one line"
    slide.notes_slide.notes_text_frame.text = (
        "【Cue】" + cue.strip() + "\n\n" + en.strip()
        + "\n\n【中文】\n" + zh.strip()
    )


def booktab(slide: Slide, x: float, y: float, widths: Sequence[float],
            rows: Sequence[Sequence[str] | tuple[Sequence[str], float]],
            size: float = 14, rh: float = 0.42, head: bool = True,
            colors: dict[tuple[int, int], str] | None = None,
            ) -> float:
    """Three-rule table built from text boxes (editable, no chrome)."""
    tw = sum(widths)
    hline(slide, x, y, tw, color=INK, lw=1.25)
    yy = y + 0.06
    for i, row in enumerate(rows):
        h = rh if not isinstance(row, tuple) else row[1]
        cells = row if not isinstance(row, tuple) else row[0]
        xx = x
        for j, (cw, cell) in enumerate(zip(widths, cells)):
            col = INK
            if colors and (i, j) in colors:
                col = colors[(i, j)]
            text(slide, xx + 0.06, yy, cw - 0.12, h - 0.06, cell, size=size,
                 color=col, bold=(head and i == 0), anchor="middle")
            xx += cw
        yy += h
        if head and i == 0:
            hline(slide, x, yy, tw, color=INK, lw=0.75)
        elif i < len(rows) - 1:
            hline(slide, x, yy, tw, color=RULE, lw=0.5)
    hline(slide, x, yy + 0.02, tw, color=INK, lw=1.25)
    return yy


# ---------------------------------------------------------------- checks
def _english_note(text_: str) -> str:
    body_ = text_.split("【中文】")[0]
    if body_.lstrip().startswith("【Cue】"):
        body_ = body_.split("\n", 1)[1] if "\n" in body_ else ""
    return body_


def self_check(prs: Presentation, *, min_font: float = 12.0,
               min_mag: float = 1.8) -> None:
    """Audit font floors, figure magnification, note length and timing."""
    sizes: list[tuple[float, int]] = []
    body_sizes: list[tuple[float, int]] = []
    pics: list[tuple[float, int, str]] = []
    words = 0
    annotated = 0
    longest = (0, 0)
    for i, slide in enumerate(prs.slides, 1):
        for sh in slide.shapes:
            if sh.has_text_frame:
                for p in sh.text_frame.paragraphs:
                    for r in p.runs:
                        if r.font.size is None:
                            continue
                        pt = r.font.size.pt
                        sizes.append((pt, i))
                        if sh.name.startswith("Body"):
                            body_sizes.append((pt, i))
            if (sh.shape_type == MSO_SHAPE_TYPE.PICTURE
                    and not sh.name.startswith("SCHEM_")):
                mag = sh.width.inches / (sh.image.size[0] / _pptx_dpi(sh.image))
                pics.append((mag, i, sh.name))
        if slide.has_notes_slide:
            annotated += 1
            n = len(_english_note(slide.notes_slide.notes_text_frame.text).split())
            words += n
            if n > longest[0]:
                longest = (n, i)

    assert sizes, "no text in the deck"
    smallest = min(sizes)
    print(f"min font: {smallest[0]:.1f} pt (slide {smallest[1]})")
    assert smallest[0] >= min_font - 1e-6, f"font below {min_font} pt"
    if body_sizes:
        lo_body = min(body_sizes)
        print(f"min body font: {lo_body[0]:.1f} pt (slide {lo_body[1]})")
        assert lo_body[0] >= 20 - 1e-6, "body text below 20 pt"

    if pics:
        lo = min(pics)
        hi = max(pics)
        print(f"pictures: {len(pics)}, min mag {lo[0]:.2f} (slide {lo[1]}), "
              f"max {hi[0]:.2f}")
        assert lo[0] >= min_mag - 1e-6, f"picture magnification below {min_mag}"
    main_mags = [m for _, m, floor in _MAGS if floor >= 2.3]
    if main_mags:
        assert min(main_mags) >= 2.3 - 1e-6, "main figure below 2.3x"

    print(f"notes: {annotated}/{len(prs.slides)} slides, {words} English words; "
          f"speaking time {words / 140:.1f} min @140 wpm, "
          f"{words / 155:.1f} min @155 wpm")
    print(f"longest slide: {longest[0]} words (slide {longest[1]})")
