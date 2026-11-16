---
name: research-slides
description: Builds research slide decks in the user's house style with bilingual speaker notes. Argument picks the mode - `progress` (progress report / group meeting on the user's own work) or `journal-club` (presenting one published paper).
---

# Research slides

Pick the mode from the argument (`/research-slides progress` or
`/research-slides journal-club`).  No argument: a deck about one published
paper is `journal-club`; anything about the user's own work is `progress`.

Then read **only** that mode's file and follow it exactly:

| Mode | Rules and layouts | Kit | Master | Example |
| --- | --- | --- | --- | --- |
| `progress` | `modes/progress.md` | `kit/deck_kit.py` | `assets/master_progress.pptx` | `examples/progress_build.py` |
| `journal-club` | `modes/journal-club.md` | `kit/jc_kit.py` | `assets/master_journal_club.pptx` | `examples/journal_club_build.py` |

Shared by both modes: `kit/render_pptx.py` (approximate PNG render, no
Office needed: `python kit/render_pptx.py deck.pptx outdir`) and
`kit/crop_pdf.py` (300-dpi PDF panel crops with edge/mask warnings).

Body text size differs on purpose: `progress` slides carry many results
(tables, comparisons), so body is 22 pt (floor 20); `journal-club` slides
are figure-led with one sentence beside the figure, so body is 32 pt
(floor 28).  Do not unify them.

Rules common to both modes:
- Never overwrite a deck the user has edited by hand; write a new file name.
- Every literature figure carries its citation directly under it.
- Main slides: no bullet lists; the first sentence of each speaker note is
  the conclusion; notes never read out numbers already printed on a figure.
- Render every slide and look at it before reporting done.
