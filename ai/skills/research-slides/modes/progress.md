
# Progress-report slides

Use this skill when the user asks for a progress-report, group-meeting,
lab-meeting or project-update deck.  The look is fixed by
`assets/master_progress.pptx` (theme, master and layouts taken from the approved
July 2026 deck): Arial, ink `#1A1A1A`, muted grey `#6B7280`, blue accent
`#2B6CB0`, orange `#DD6B20`, red `#B83232`, white background, 16:9.

## Deck skeleton (progress report)

1. Title — project, one-line topic, date.
2. One-question opener — the single question the talk answers.
3. Definition / background — one or two **cited** literature figures; define
   the quantity under test before showing anything.
4. Purpose & framework — what will be measured, drawn as a schematic.
5. Methods & setup — device and design, one idea per slide.
6. Results — one assertion per slide.
7. Plan — what happens next, with dates.
8. Summary text page — three short assertions plus "Questions for the group".

Backup and appendix slides come after the summary; there the figure floor
relaxes to 1.8x.

## Style rules (from user feedback)

- Every figure taken from the literature gets its citation in 12 pt grey
  directly under it — `kit.fig(..., src="Author et al., 2019")` does this.
- Results slides: assertion title + figure + at most one short caption
  sentence.  No bullet lists on results slides.
- The summary is its own text page, never a figure.
- Body text >= 20 pt; captions, footers and page numbers >= 12 pt.
- Literature crops are placed at >= 2.3x their 300-dpi print size on main
  slides, >= 1.8x on backup slides.  `kit.fig` asserts this, so export
  crops at 300 dpi and keep the crop small (a 3.2 in crop becomes 7.4 in on
  the slide at 2.3x).
- Speaker notes on every content slide:
  - first sentence is the slide's conclusion;
  - never read out numbers already printed on a figure;
  - light on background, detailed on the user's own work;
  - end with an explicit transition into the next slide;
  - every promise made on one slide is kept on the next;
  - English first, then `【中文】` Chinese translation, with a one-line
    Chinese `【Cue】` on top (`kit.notes` writes this format).

## Workflow

1. Write a build script from `examples/progress_build.py`, in the project
   (`scripts/` or a scratch folder), importing the kit:

   ```python
   import sys
   sys.path.insert(0, r"C:/Users/Wray/.claude/skills/research-slides/kit")
   import deck_kit as kit
   ```

2. Draw schematics with matplotlib at final size (figsize in inches equals
   the inches on the slide, `dpi=300`, fonts at their slide pt) and place
   them with `kit.schem`.  Place literature crops with `kit.fig`, which
   prints and asserts the magnification and writes the citation.
3. Build with a Python that has python-pptx, Pillow and matplotlib
   (`pip install python-pptx pillow matplotlib` if missing).
4. Render every slide and look at every PNG:

   ```bash
   python kit/render_pptx.py deck.pptx renders/
   ```

   Fix overflow or cramped text, rebuild, re-render.  `contact.png` gives a
   contact sheet for the final overall check.
5. Keep `kit.self_check(prs)` in the build.  It asserts the 12 pt floor,
   the 20 pt body floor and the picture magnification floor, and reports
   note word counts and speaking time at 140 and 155 wpm.  A 10-minute talk
   is roughly 1350–1500 English words of notes.

## Files

- `assets/master_progress.pptx` — theme, master and layouts only; no slides.
- `kit/deck_kit.py` — `new_deck`, `blank`, `header`, `body`, `text`, `fig`,
  `schem`, `cite`, `foot`, `notes`, `booktab`, `self_check`, `set_figures`.
- `kit/render_pptx.py` — approximate PNG renderer; also reports text that
  overflows its box or the slide.
- `examples/progress_build.py` — six-slide demo deck; start from it.

## Gotchas

- `kit.blank(prs)` must be used for every slide; the master's layouts carry
  Chinese names, so do not pick layouts by name.
- Inline markup in `kit.text` / `kit.body`: `**bold**`, `{{red}}`,
  `[[blue]]`, `<<orange>>`.
- Magnification is computed from the image's own dpi metadata, falling back
  to 300 dpi; images without metadata are treated as 300-dpi crops.
- `kit.self_check` skips shapes named `SCHEM_*` (schematics are drawn at
  final size, so magnification does not apply to them).
- A dense References page is the one exception in the approved deck (9 pt
  bibliography); `kit.text` asserts 12 pt, so build that page with
  python-pptx directly and run `kit.self_check` before adding it (or pass a
  lower `min_font` for the final pass).
