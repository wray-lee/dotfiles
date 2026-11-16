"""House-style kit for journal-club decks (python-pptx).

The look is taken from the user's hand-edited Steinfath 2025 deck: Arial,
ink ``#1A1A1A``, muted grey ``#6B7280``, blue accent ``#2B6CB0``, white
background, 16:9.  Layout numbers reproduce that deck's conventions:

* section eyebrow 12 pt bold blue at (0.55, 0.30); assertion title 28 pt
  bold at (0.55, 0.55), content width 12.23 in;
* running body copy 32 pt on main slides (never below 28 pt), 20 pt in
  backups; captions, page numbers and the backup tag 12 pt grey;
* literature crops are at least 2.3x their 300-dpi print size on main
  slides and 1.8x in backups, with a 12 pt grey citation 0.02 in below;
* drawn schematics are placed at their final size, never rescaled.

Typical build::

    import jc_kit as kit

    prs = kit.new_deck()
    s = kit.slide_fig_side(
        prs, "RESULTS", "Vibration has its own statistics",
        "figs/f1d.png", "Smith et al., 2025, Fig. 1d",
        "Vibration intervals are several times longer than song pulses.",
    )
    kit.notes(s, "振动有自己的统计", "English ...", "中文 ...")
    prs.save("deck.pptx")
"""

from __future__ import annotations

import math
import re
from collections.abc import Sequence
from pathlib import Path
from typing import Any

from PIL import Image as PILImage
from pptx import Presentation
from pptx.dml.color import RGBColor
from pptx.enum.text import MSO_ANCHOR, MSO_AUTO_SIZE, PP_ALIGN
from pptx.oxml import parse_xml
from pptx.oxml.ns import nsdecls
from pptx.shapes.autoshape import Shape
from pptx.slide import Slide
from pptx.util import Inches, Pt

# ------------------------------------------------------------------ palette
FONT = "Arial"
INK = "1A1A1A"
MUTED = "6B7280"
ACCENT = "2B6CB0"
ORANGE = "DD6B20"  # inferred / open parts in discussion schematics

L, W = 0.55, 12.23  # left margin and content width, inches
SLIDE_W, SLIDE_H = 13.333, 7.5

SECTION_PT = 12.0
TITLE_PT = 28.0
EYEBROW_PT = 14.0
BODY_PT = 32.0
BODY_FLOOR = 28.0
INTRO_PT = 24.0
CARD_PT = 20.0
SUMMARY_PT = 22.0
BACKUP_BODY_PT = 20.0
BACKUP_FLOOR = 20.0
CAPTION_PT = 12.0

FIG_MAG = 2.3
BACKUP_FIG_MAG = 1.8
CROP_DPI = 300.0

ASSETS = Path(__file__).resolve().parents[1] / "assets" / "master_journal_club.pptx"
_PAGE = [0]

_ALIGN = {"left": PP_ALIGN.LEFT, "center": PP_ALIGN.CENTER,
          "right": PP_ALIGN.RIGHT}
_ANCHOR = {"top": MSO_ANCHOR.TOP, "middle": MSO_ANCHOR.MIDDLE,
           "bottom": MSO_ANCHOR.BOTTOM}


# ------------------------------------------------------------------ helpers
def _paragraphs(paras: str | Sequence[str]) -> list[str]:
    """Normalise one string or a sequence of strings to a paragraph list."""
    if isinstance(paras, str):
        return paras.split("\n")
    assert all(isinstance(p, str) for p in paras), "paragraphs must be str"
    return list(paras)


def _text(
    slide: Slide,
    x: float,
    y: float,
    w: float,
    h: float,
    paras: str | Sequence[str],
    *,
    size: float,
    color: str = INK,
    bold: bool = False,
    align: str = "left",
    anchor: str = "top",
    space_before: float = 0.0,
    space_after: float = 0.0,
    bullets: bool = False,
) -> Shape:
    """Add a borderless text box with zero internal margins."""
    box = slide.shapes.add_textbox(Inches(x), Inches(y), Inches(w), Inches(h))
    tf = box.text_frame
    tf.word_wrap = True
    tf.auto_size = MSO_AUTO_SIZE.NONE
    tf.margin_left = tf.margin_right = 0
    tf.margin_top = tf.margin_bottom = 0
    tf.vertical_anchor = _ANCHOR[anchor]
    lines = _paragraphs(paras)
    for i, line in enumerate(lines):
        p = tf.paragraphs[0] if i == 0 else tf.add_paragraph()
        p.alignment = _ALIGN[align]
        p.line_spacing = 1.08
        if i > 0 and space_before:
            p.space_before = Pt(space_before)
        if space_after:
            p.space_after = Pt(space_after)
        if bullets:
            pPr = p._p.get_or_add_pPr()
            pPr.set("marL", str(int(0.24 * 914400)))
            pPr.set("indent", str(int(-0.24 * 914400)))
            pPr.append(parse_xml(
                f'<a:buFont {nsdecls("a")} typeface="{FONT}"/>'
            ))
            pPr.append(parse_xml(
                f'<a:buChar {nsdecls("a")} char="&#8226;"/>'
            ))
        run = p.add_run()
        run.text = line
        run.font.name = FONT
        run.font.size = Pt(size)
        run.font.bold = bold
        run.font.color.rgb = RGBColor.from_string(color)
    return box


def _image_size(path: str | Path) -> tuple[int, int]:
    with PILImage.open(path) as im:
        return im.size


def _caption(
    slide: Slide, x: float, y: float, w: float, text: str
) -> Shape:
    return _text(
        slide, x, y, max(w, 2.8), 0.24, text,
        size=CAPTION_PT, color=MUTED,
    )


def _page_number(slide: Slide, n: int) -> None:
    _text(
        slide, 12.18, 7.06, 0.6, 0.26, str(n),
        size=CAPTION_PT, color=MUTED, align="right",
    )


def _is_backup(slide: Slide) -> bool:
    for sh in slide.shapes:
        if sh.has_text_frame and sh.text_frame.text.upper().startswith("BACKUP"):
            return True
    return False


# ------------------------------------------------------------------- deck
def new_deck() -> Presentation:
    """Open the master (theme, master and layouts, no slides)."""
    prs = Presentation(str(ASSETS))
    assert len(prs.slides) == 0, "master must contain no slides"
    assert abs(prs.slide_width / 914400 - SLIDE_W) < 0.01
    assert abs(prs.slide_height / 914400 - SLIDE_H) < 0.01
    _PAGE[0] = 0
    return prs


def blank(prs: Presentation) -> Slide:
    """Add a blank slide and its automatic page number."""
    layout = next(
        (lay for lay in prs.slide_layouts if len(lay.placeholders) == 0),
        prs.slide_layouts[6],
    )
    slide = prs.slides.add_slide(layout)
    _PAGE[0] += 1
    for sh in list(slide.shapes):
        sh._element.getparent().remove(sh._element)
    _page_number(slide, _PAGE[0])
    return slide


def header(slide: Slide, section: str, title: str) -> None:
    """Section eyebrow and assertion title (28 pt)."""
    _text(
        slide, L, 0.30, 9.0, 0.26, section.upper(),
        size=SECTION_PT, color=ACCENT, bold=True,
    )
    _text(slide, L, 0.55, W, 0.62, title, size=TITLE_PT, bold=True)


def body(
    slide: Slide,
    x: float,
    y: float,
    w: float,
    h: float,
    paras: str | Sequence[str],
    *,
    size: float = BODY_PT,
    backup: bool = False,
    **kw: Any,
) -> Shape:
    """Running body copy; enforces 28 pt on main slides, 20 pt in backups."""
    floor = BACKUP_FLOOR if backup else BODY_FLOOR
    assert size >= floor, (
        f"body text {size} pt is below the {floor} pt floor"
        f"{' for backups' if backup else ' for main slides'}"
    )
    return _text(slide, x, y, w, h, paras, size=size, **kw)


# --------------------------------------------------------------- figures
def fig(
    slide: Slide,
    path: str | Path,
    x: float,
    y: float,
    maxw: float,
    maxh: float,
    src: str,
    *,
    minmag: float | None = None,
    backup: bool = False,
    bottom: float | None = None,
) -> tuple[float, float, float, float]:
    """Place a 300-dpi literature crop, assert magnification, cite it.

    The crop is fitted inside ``maxw x maxh`` without distortion.  When
    ``bottom`` is given the fitted image is bottom-aligned there.  The
    magnification is display inches over the crop's 300-dpi print width.
    ``minmag`` can only raise the house floor (2.3x main, 1.8x backup),
    never lower it.  Returns the placed ``(x, y, w, h)``.
    """
    iw, ih = _image_size(path)
    ar = iw / ih
    w, h = maxw, maxw / ar
    if h > maxh:
        w, h = maxh * ar, maxh
    if bottom is not None:
        y = bottom - h
    mag = w / (iw / CROP_DPI)
    floor = BACKUP_FIG_MAG if backup else FIG_MAG
    if minmag is not None:
        floor = max(floor, minmag)
    assert mag >= floor, (
        f"{Path(path).name}: {mag:.2f}x magnification is below the "
        f"{floor}x floor (crop {iw}x{ih} px at 300 dpi, shown {w:.2f} in "
        f"wide). Crop tighter or enlarge the frame."
    )
    pic = slide.shapes.add_picture(
        str(path), Inches(x), Inches(y), Inches(w), Inches(h)
    )
    pic.name = f"FIG_{Path(path).stem}"
    assert pic.width / 914400 == w or abs(pic.width / 914400 - w) < 0.01
    _caption(slide, x, y + h + 0.02, w, src)
    return x, y, w, h


def schem(
    slide: Slide,
    path: str | Path,
    x: float,
    y: float,
    w: float,
    h: float | None = None,
    *,
    src: str = "",
) -> tuple[float, float, float, float]:
    """Place a drawn schematic at its final size (aspect ratio preserved)."""
    iw, ih = _image_size(path)
    if h is None:
        h = w * ih / iw
    rel = abs((iw / ih) - (w / h)) / (iw / ih)
    assert rel < 0.02, (
        f"{Path(path).name}: image aspect {iw / ih:.3f} does not match the "
        f"target {w:.2f}x{h:.2f} in; draw the schematic at its final size"
    )
    pic = slide.shapes.add_picture(
        str(path), Inches(x), Inches(y), Inches(w), Inches(h)
    )
    pic.name = f"SCHEM_{Path(path).stem}"
    if src:
        _caption(slide, x, y + h + 0.02, w, src)
    return x, y, w, h


# ------------------------------------------------------------------ notes
def notes(slide: Slide, cue: str, en: str, zh: str) -> None:
    """Bilingual speaker notes: cue, English script, Chinese translation."""
    assert cue.strip() and "\n" not in cue.strip(), "cue must be one line"
    en, zh = en.strip(), zh.strip()
    assert en and zh, "both English and Chinese notes are required"
    tf = slide.notes_slide.notes_text_frame
    tf.text = f"【Cue】{cue.strip()}\n\n{en}\n\n【中文】\n{zh}"


# ------------------------------------------------------------- self-check
def self_check(
    prs: Presentation,
    *,
    wpm_main: float = 140.0,
    wpm_backup: float = 155.0,
    strict: bool = True,
) -> dict[str, Any]:
    """Audit fonts, figure magnification, bullets, notes length and timing.

    Returns a report dict.  With ``strict`` any problem raises.
    """
    problems: list[str] = []
    min_font = math.inf
    min_mag = math.inf
    words_main = words_backup = 0
    bullets: list[str] = []
    for n, slide in enumerate(prs.slides, 1):
        backup = _is_backup(slide)
        for sh in slide.shapes:
            if str(sh.shape_type).startswith("PICTURE") and not sh.name.startswith(
                "SCHEM_"
            ):
                iw = sh.image.size[0]
                mag = (sh.width / 914400) / (iw / CROP_DPI)
                min_mag = min(min_mag, mag)
                floor = BACKUP_FIG_MAG if backup else FIG_MAG
                if mag < floor:
                    problems.append(
                        f"slide {n}: {sh.name} at {mag:.2f}x < {floor}x"
                    )
            if not sh.has_text_frame:
                continue
            for p in sh.text_frame.paragraphs:
                pPr = p._p.pPr
                if not backup and (
                    (
                        pPr is not None
                        and (
                            pPr.find(
                                "{http://schemas.openxmlformats.org/"
                                "drawingml/2006/main}buChar"
                            )
                            is not None
                            or pPr.find(
                                "{http://schemas.openxmlformats.org/"
                                "drawingml/2006/main}buAutoNum"
                            )
                            is not None
                        )
                    )
                    or p.text.lstrip().startswith(("•", "- ", "* "))
                ):
                    bullets.append(f"slide {n}: {p.text[:40]!r}")
                for run in p.runs:
                    if run.font.size is not None:
                        min_font = min(min_font, run.font.size.pt)
                        if run.font.size.pt < CAPTION_PT:
                            problems.append(
                                f"slide {n}: {run.font.size.pt} pt text "
                                f"{run.text[:30]!r}"
                            )
        if slide.has_notes_slide:
            text = slide.notes_slide.notes_text_frame.text
            en = text.split("【中文】")[0]
            en = "\n".join(
                line for line in en.splitlines()
                if not line.startswith("【Cue】")
            )
            words = len(re.findall(r"[A-Za-z][A-Za-z'’-]*", en))
            if backup:
                words_backup += words
            else:
                words_main += words
    if bullets:
        problems.extend(f"bullet list on main slide: {b}" for b in bullets)
    minutes_main = words_main / wpm_main
    minutes_backup = words_backup / wpm_backup
    report: dict[str, Any] = {
        "slides": len(prs.slides),
        "min_font_pt": min_font,
        "min_mag": min_mag,
        "words_main": words_main,
        "words_backup": words_backup,
        "minutes_main": round(minutes_main, 1),
        "minutes_backup": round(minutes_backup, 1),
        "minutes_total": round(minutes_main + minutes_backup, 1),
        "problems": problems,
    }
    font_txt = "n/a" if math.isinf(min_font) else f"{min_font:g} pt"
    mag_txt = "n/a" if math.isinf(min_mag) else f"{min_mag:.2f}x"
    print(
        f"self-check: {len(prs.slides)} slides, min font {font_txt}, "
        f"min figure mag {mag_txt}, main {words_main} words "
        f"({minutes_main:.1f} min at {wpm_main:g} wpm), backup "
        f"{words_backup} words ({minutes_backup:.1f} min at "
        f"{wpm_backup:g} wpm)"
    )
    for p in problems:
        print("  PROBLEM:", p)
    if problems and strict:
        raise AssertionError(f"{len(problems)} self-check problem(s)")
    return report


# ---------------------------------------------------------------- layouts
def slide_title(
    prs: Presentation,
    eyebrow: str,
    title: str,
    authors: str,
    journal: str = "",
) -> Slide:
    """Title slide: eyebrow 14, paper title 44, authors 20, journal 16."""
    s = blank(prs)
    _text(s, 0.9, 1.25, 11.6, 0.35, eyebrow,
          size=EYEBROW_PT, color=ACCENT, bold=True)
    _text(s, 0.9, 1.70, 11.6, 1.05, title, size=44, bold=True)
    _text(s, 0.9, 3.80, 11.6, 0.95, authors, size=20)
    if journal:
        _text(s, 0.9, 5.00, 11.6, 0.80, journal, size=16, color=MUTED)
    return s


def slide_fig_side(
    prs: Presentation,
    section: str,
    title: str,
    fig_path: str | Path,
    src: str,
    text_paras: str | Sequence[str],
    *,
    fig_x: float = 0.55,
    fig_y: float = 1.30,
    fig_w: float = 7.40,
    fig_h: float = 4.80,
    text_x: float = 8.20,
    text_y: float = 2.30,
    text_w: float = 4.99,
    text_h: float = 3.60,
    size: float = BODY_PT,
    backup: bool = False,
) -> Slide:
    """Literature figure on the left, 32 pt body text on the right."""
    s = blank(prs)
    header(s, section, title)
    fig(s, fig_path, fig_x, fig_y, fig_w, fig_h, src, backup=backup)
    body(s, text_x, text_y, text_w, text_h, text_paras, size=size,
         backup=backup)
    return s


def slide_two_figs_caption(
    prs: Presentation,
    section: str,
    title: str,
    fig1: str | Path,
    src1: str,
    fig2: str | Path,
    src2: str,
    text_paras: str | Sequence[str],
    *,
    fig1_x: float = 1.35,
    fig1_w: float = 5.60,
    fig2_x: float = 7.45,
    fig2_w: float = 3.40,
    fig_h: float = 3.20,
    bottom: float = 4.32,
    body_x: float = 0.58,
    body_y: float = 5.26,
    body_w: float = 12.20,
    body_h: float = 1.40,
    size: float = BODY_PT,
    backup: bool = False,
) -> Slide:
    """Two figures side by side, captions below, full-width body under both."""
    s = blank(prs)
    header(s, section, title)
    fig(s, fig1, fig1_x, 1.30, fig1_w, fig_h, src1,
        backup=backup, bottom=bottom)
    fig(s, fig2, fig2_x, 1.30, fig2_w, fig_h, src2,
        backup=backup, bottom=bottom)
    body(s, body_x, body_y, body_w, body_h, text_paras, size=size,
         backup=backup)
    return s


def slide_wide_fig(
    prs: Presentation,
    section: str,
    title: str,
    fig_path: str | Path,
    src: str,
    text_paras: str | Sequence[str],
    *,
    intro: str | None = None,
    fig_x: float = 0.55,
    fig_y: float = 2.45,
    fig_w: float = 12.20,
    fig_h: float = 3.30,
    text_y: float = 6.35,
    text_h: float = 0.60,
    size: float = BODY_PT,
    backup: bool = False,
) -> Slide:
    """Full-width figure with an optional 24 pt intro line and 32 pt body."""
    s = blank(prs)
    header(s, section, title)
    if intro:
        _text(s, L, 1.35, 12.20, 0.80, intro, size=INTRO_PT)
    fig(s, fig_path, fig_x, fig_y, fig_w, fig_h, src, backup=backup)
    body(s, 0.58, text_y, 12.20, text_h, text_paras, size=size,
         backup=backup)
    return s


def slide_schematic_text(
    prs: Presentation,
    section: str,
    title: str,
    schem_path: str | Path,
    src: str,
    text_paras: str | Sequence[str],
    *,
    schem_x: float = 0.55,
    schem_y: float = 1.35,
    schem_w: float = 5.60,
    schem_h: float | None = 5.30,
    text_x: float = 6.67,
    text_y: float = 2.45,
    text_w: float = 6.00,
    text_h: float = 4.00,
    size: float = BODY_PT,
    backup: bool = False,
) -> Slide:
    """Drawn schematic on the left, 32 pt body text on the right."""
    s = blank(prs)
    header(s, section, title)
    schem(s, schem_path, schem_x, schem_y, schem_w, schem_h, src=src)
    body(s, text_x, text_y, text_w, text_h, text_paras, size=size,
         backup=backup)
    return s


def slide_approach(
    prs: Presentation,
    section: str,
    title: str,
    cards: Sequence[tuple[str, str | Path, str]],
) -> Slide:
    """One row of up to three schematics with a 24 pt label and 20 pt line."""
    assert 1 <= len(cards) <= 3, "use one to three approach cards"
    s = blank(prs)
    header(s, section, title)
    for i, (label, path, line) in enumerate(cards):
        x = 0.55 + i * 4.15
        _text(s, x, 1.55, 3.70, 0.50, label,
              size=INTRO_PT, bold=True, color=ACCENT)
        schem(s, path, x, 2.15, 3.70, 2.70)
        _text(s, x, 5.00, 3.70, 1.20, line, size=CARD_PT)
    return s


def slide_summary(
    prs: Presentation,
    section: str,
    title: str,
    points: Sequence[str],
    *,
    credit: str | None = None,
) -> Slide:
    """Text-only summary page: numbered 22 pt assertions, no bullets."""
    s = blank(prs)
    header(s, section, title)
    paras = [f"{i}.  {p}" for i, p in enumerate(points, 1)]
    _text(s, 0.90, 1.55, 11.60, 4.80, paras, size=SUMMARY_PT,
          space_before=18)
    if credit:
        _text(s, 0.90, 6.45, 11.40, 0.35, credit, size=14, color=MUTED)
    return s


def slide_backup(
    prs: Presentation,
    section: str,
    title: str,
    fig_path: str | Path | None,
    src: str,
    text_paras: str | Sequence[str],
    *,
    tag: str = "B1",
    fig_x: float = 0.60,
    fig_y: float = 1.50,
    fig_w: float = 7.60,
    fig_h: float = 2.30,
    text_x: float = 8.50,
    text_y: float = 1.60,
    text_w: float = 4.10,
    text_h: float = 3.00,
    size: float = BACKUP_BODY_PT,
    bullets: bool = False,
) -> Slide:
    """Backup slide: 1.8x figure floor, 20 pt text, B-tag at bottom right.

    Pass ``bullets=True`` for the reference deck's dotted backup lists;
    main slides must never use bullet lists.
    """
    s = blank(prs)
    header(s, section, title)
    if fig_path is not None:
        fig(s, fig_path, fig_x, fig_y, fig_w, fig_h, src, backup=True)
        body(s, text_x, text_y, text_w, text_h, text_paras,
             size=size, backup=True, space_before=6, bullets=bullets)
    else:
        body(s, 0.90, 1.55, 11.60, 4.80, text_paras, size=size,
             backup=True, space_before=6, bullets=bullets)
    _text(s, 11.30, 7.06, 0.70, 0.26, tag,
          size=CAPTION_PT, color=MUTED, align="right")
    return s
