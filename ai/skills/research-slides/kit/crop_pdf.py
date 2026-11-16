"""Crop figure panels from PDF pages at 300 dpi, with safety checks.

Regions and masks are given in PDF points with the origin at the top-left
of the page, the same units Preview / Acrobat show.  Each region is
rendered at ``dpi`` (300 by default), optionally masked to white,
trimmed to its non-white content and saved as PNG.

Two checks guard against mistakes that have happened in practice:

* a crop edge that runs through dark pixels -- the panel is probably
  clipped, so widen the region;
* a mask that covers dark pixels -- the mask may be hiding an axis tick
  or a whole experimental group, so look before you trust the crop.

Usage as a module::

    from crop_pdf import crop
    crop("paper.pdf", 3, (196, 45, 545, 139.5), "figs/f1b.png",
         masks=[(300, 60, 330, 80)])

Usage from the shell::

    python crop_pdf.py paper.pdf figs spec.json

where ``spec.json`` is::

    {"dpi": 300,
     "regions": {"f1b": [3, 196, 45, 545, 139.5]},
     "masks":   {"f1b": [[300, 60, 330, 80]]}}
"""

from __future__ import annotations

import json
import sys
from collections.abc import Sequence
from pathlib import Path

import numpy as np
from PIL import Image

DPI = 300
DARK = 245


def render_page(pdf: str | Path, page: int, dpi: int = DPI) -> Image.Image:
    """Render one 1-based PDF page to an RGB Pillow image."""
    import pymupdf

    with pymupdf.open(str(pdf)) as doc:
        assert 1 <= page <= len(doc), f"page {page} outside 1..{len(doc)}"
        pix = doc[page - 1].get_pixmap(dpi=dpi)
    return Image.frombytes("RGB", (pix.width, pix.height), pix.samples)


def _px(value: float, dpi: int) -> int:
    return int(round(value * dpi / 72.0))


def _edge_warnings(
    img: Image.Image, name: str, dark: int
) -> list[str]:
    """Warn when dark pixels touch the requested crop boundary."""
    arr = np.asarray(img.convert("L"))
    h, w = arr.shape
    band = 2
    edges = {
        "top": arr[:band, :],
        "bottom": arr[h - band:, :],
        "left": arr[:, :band],
        "right": arr[:, w - band:],
    }
    out: list[str] = []
    for edge, strip in edges.items():
        count = int((strip < dark).sum())
        length = strip.size // band
        if count > max(4, int(length * 0.005)):
            out.append(
                f"{name}: crop edge {edge} cuts through dark pixels "
                f"({count} px); widen the box if content is clipped"
            )
    return out


def crop(
    pdf: str | Path,
    page: int,
    box: tuple[float, float, float, float],
    out: str | Path,
    *,
    masks: Sequence[tuple[float, float, float, float]] = (),
    dpi: int = DPI,
    trim: bool = True,
    pad: int = 4,
    dark: int = DARK,
    mask_warn: int = 25,
) -> list[str]:
    """Render, mask, trim and save one crop; return the warnings."""
    name = Path(out).stem
    page_img = render_page(pdf, page, dpi)
    scale = dpi / 72.0
    x0, y0, x1, y1 = box
    px = (
        max(0, _px(x0, dpi)),
        max(0, _px(y0, dpi)),
        min(page_img.width, _px(x1, dpi)),
        min(page_img.height, _px(y1, dpi)),
    )
    assert px[2] > px[0] and px[3] > px[1], f"{name}: empty crop box"
    img = page_img.crop(px)
    warnings: list[str] = []

    # Check masks before painting over anything.
    for m in masks:
        mx0, my0, mx1, my1 = (
            _px(m[0], dpi) - px[0], _px(m[1], dpi) - px[1],
            _px(m[2], dpi) - px[0], _px(m[3], dpi) - px[1],
        )
        cx0, cy0 = max(0, mx0), max(0, my0)
        cx1, cy1 = min(img.width, mx1), min(img.height, my1)
        if cx1 <= cx0 or cy1 <= cy0:
            warnings.append(
                f"{name}: mask {tuple(round(v, 1) for v in m)} lies "
                f"outside the crop"
            )
            continue
        area = np.asarray(img.convert("L"))[cy0:cy1, cx0:cx1]
        hidden = int((area < dark).sum())
        if hidden > mask_warn:
            warnings.append(
                f"{name}: mask {tuple(round(v, 1) for v in m)} hides "
                f"{hidden} dark px; check that it is not an axis tick or "
                f"a data group"
            )
        img.paste((255, 255, 255), (cx0, cy0, cx1, cy1))

    warnings.extend(_edge_warnings(img, name, dark))

    if trim:
        arr = np.asarray(img.convert("L"))
        ys, xs = np.where(arr < dark)
        if len(xs) == 0:
            warnings.append(f"{name}: crop is blank after masking")
        else:
            img = img.crop((
                max(0, int(xs.min()) - pad),
                max(0, int(ys.min()) - pad),
                min(img.width, int(xs.max()) + 1 + pad),
                min(img.height, int(ys.max()) + 1 + pad),
            ))

    out_path = Path(out)
    out_path.parent.mkdir(parents=True, exist_ok=True)
    img.save(out_path, dpi=(dpi, dpi))
    assert img.width > 0 and img.height > 0
    for warning in warnings:
        print("WARNING:", warning)
    return warnings


def main(argv: Sequence[str]) -> int:
    if len(argv) != 3:
        print("usage: python crop_pdf.py paper.pdf outdir spec.json")
        return 2
    pdf, outdir, spec_path = argv[0], Path(argv[1]), Path(argv[2])
    spec = json.loads(spec_path.read_text(encoding="utf-8"))
    dpi = int(spec.get("dpi", DPI))
    masks = spec.get("masks", {})
    all_warnings: list[str] = []
    for name, region in spec["regions"].items():
        page = int(region[0])
        box = tuple(float(v) for v in region[1:5])
        out = outdir / (name if name.endswith(".png") else name + ".png")
        all_warnings += crop(
            pdf, page, box, out,
            masks=[tuple(float(v) for v in m) for m in masks.get(name, [])],
            dpi=dpi,
        )
    print(f"cropped {len(spec['regions'])} panel(s), "
          f"{len(all_warnings)} warning(s)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
