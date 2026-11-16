
# Journal-club slides

Use this skill when the user asks for a journal-club, paper-presentation or
group-meeting deck about **one published paper**.  The look is fixed by
`assets/master_journal_club.pptx`, taken from the user's hand-edited Steinfath et al.
2025 deck: Arial, ink `#1A1A1A`, muted grey `#6B7280`, blue accent
`#2B6CB0`, white background, 16:9 (13.333 x 7.5 in).

This skill is for presenting someone else's paper.  For progress reports
about the user's own work use mode `progress` instead.

## Deck skeleton (journal club)

1. **Title** — paper title, authors, journal/DOI; no separate subtitle.
2. **Background biology** — enough to follow the results: anatomy,
   physiology and behaviour, drawn as schematics with cited literature
   figures where needed.
3. **Known vs unknown** — what was mapped before, and the gap.
4. **Approach** — one row: record, perturb, model (or the paper's own
   three steps).
5. **Results** — one assertion per slide, at most two panels.
6. **Model** — the paper's computational model, if it has one.
7. **What is established vs open** — a diagram with the inferred parts
   highlighted (orange in the reference).
8. **Summary** — its own text-only page, 3-4 numbered assertions.
9. **Backups** — full statistics, methods, extra panels; after the
   summary, tagged B1, B2, ...

## Layout conventions (measured from the reference deck)

Slide 16:9, 13.333 x 7.5 in.  Left margin `L = 0.55`, content width
`W = 12.23`.  All text boxes have zero internal margins and line spacing
1.08.

| Element | Position (in) | Size | Type |
| :--- | :--- | :--- | :--- |
| Section eyebrow | (0.55, 0.30) | 9.00 x 0.26 | 12 pt bold, accent, UPPERCASE |
| Assertion title | (0.55, 0.55) | 12.23 x 0.62 | 28 pt bold, ink |
| Page number | (12.18, 7.06) | 0.60 x 0.26 | 12 pt grey, right |
| Backup tag B1 | (11.30, 7.06) | 0.70 x 0.26 | 12 pt grey, right |
| Figure citation | figure x, y = bottom + 0.02 | max(fig_w, 2.8) x 0.24 | 12 pt grey |
| Main body text | layout-specific | layout-specific | **32 pt** (floor 28) |
| Backup body text | layout-specific | layout-specific | 20 pt |
| Summary points | (0.90, 1.55) | 11.60 x 4.80 | 22 pt, numbered "1.  ..." |
| Summary credit | (0.90, 6.45) | 11.40 x 0.35 | 14 pt grey |

The user raised most main-slide body copy to **32 pt**.  Only the
full-width-figure intro (24 pt), approach-card descriptions (20 pt),
summary (22 pt) and backups (20 pt) sit lower.  Never put running body
copy below 28 pt on a main slide.

### Title slide
Eyebrow 14 pt bold accent at (0.90, 1.25, 11.6 x 0.35); paper title
44 pt bold at (0.90, 1.70, 11.6 x 1.05); authors 20 pt at (0.90, 3.80,
11.6 x 0.95); journal/DOI 16 pt grey at (0.90, 5.00, 11.6 x 0.80).
A long title wraps to a second line; there is no subtitle and no credit
line on this slide.

### Figure + side text (`slide_fig_side`)
Figure at (0.55, 1.30), fitted in 7.40 x 4.80; 32 pt text at (8.20, 2.30)
in 4.99 x 3.60 (the hand-edited deck widened this box from the old
4.55 in; it reaches almost to the slide edge).  For a narrow figure the
text starts further left (x 4.25-6.55, width 5.8-8.7), always 32 pt.

### Two figures + caption below (`slide_two_figs_caption`)
Left figure at x = 1.35, max 5.60 x 3.20; right figure at x = 7.45,
max 3.40 x 3.20; both bottom-aligned at y = 4.32, each with its 12 pt
citation directly under it (y = 4.34).  One 32 pt sentence block spans
the width at (0.58, 5.26) in 12.20 x 1.40.  A wider-left variant used on
one slide puts the figures at x = 0.65 (max 7.10) and x = 8.20
(max 4.40), bottom 4.55, with the body at y = 5.56.

### Full-width figure (`slide_wide_fig`)
Optional 24 pt intro line at (0.55, 1.35, 12.20 x 0.80); figure at
(0.55, 2.45), fitted in 12.20 x 3.30; citation under it; one 32 pt line
at (0.58, 6.35) in 12.20 x 0.60.

### Schematic + text (`slide_schematic_text`)
Left schematic at (0.55, 1.35), 5.60 x 5.30 final size, citation at
y = 6.67; 32 pt text at (6.67, 2.45) in 6.00 x 4.00.  For a big
behavioural cartoon use the wide variant seen on the background slide:
schematic at (0.18, 1.42), 8.20 x 4.70, citation at y = 6.14; text at
(8.53, 2.21) in 4.25 x 3.80.

### Approach row (`slide_approach`)
Three columns at x = 0.55, 4.70, 8.85, each 3.70 wide.  24 pt bold accent
label at y = 1.55 (height 0.50); schematic 3.70 x 2.70 at y = 2.15;
20 pt description at y = 5.00 (height 1.20).

### Backups (`slide_backup`)
Section "BACKUP · TOPIC"; figure at (0.60, 1.50) fitted in 7.60 x 2.30
(1.8x magnification floor), 20 pt text at (8.50, 1.60) in 4.10 x 3.00;
tag "B1" at bottom right.  A backup without a figure uses the full
content width at 20 pt.  The reference backs statistics with dotted
lists; pass `bullets=True` to `slide_backup` for that look (the
main-slide bullet ban does not apply to backups).

### Figures and magnification
Literature crops are exported at **300 dpi** and displayed at >= **2.3x**
their 300-dpi print size on main slides, >= **1.8x** in backups.
`kit.fig` asserts this; a 2.5-in-wide crop fills 6.5 in at 2.6x.  Drawn
schematics are exported at their **final size** (e.g. 8.2 x 4.7 in at
300 dpi) and placed without rescaling; `kit.schem` asserts the aspect
ratio so they are never stretched.

## Rules from user feedback

- **Talk only about the paper.**  No "relevance to my research" page,
  paragraph or note.  Discussion is about what the paper establishes and
  leaves open, not about the user's projects.
- **Every literature figure gets its citation** in 12 pt grey directly
  under it.  `kit.fig(..., src=...)` does this automatically.
- **Assertion title + figure + at most one caption sentence** per
  results slide.  The title states the claim, not the topic.
- **No bullet lists on main slides.**  Results and background slides use
  one prose block.  Numbered summary points are plain "1.  ..." text,
  not PowerPoint bullets.  Backups may use short separate lines.
- **Background must be sufficient**: include the physiology and anatomy
  needed to read the results (receptors, sensory organs, brain regions,
  descending pathways), not just one cartoon.
- **The summary is its own text-only page**, never a figure.
- **At most 1-2 panels per slide**, and crop tightly; never shrink a
  multi-panel figure until the axes are unreadable.
- **Never read numbers printed on a figure.**  Point to the comparison
  and say what it means; the audience reads the numbers.
- **First sentence of every note is the conclusion**, in both English
  and Chinese.  Then the evidence, then an explicit transition to the
  next slide ("We start with ...", "The next question is ...").
- **All facts checked against the paper text.**  Extract the PDF text
  first and verify every claim, number and figure panel against it; do
  not rely on memory or the abstract alone.
- **Never overwrite a deck the user has hand-edited.**  Write generated
  decks to a new filename (e.g. `*_generated.pptx`) and keep the edited
  file read-only.

## Speaker notes

`kit.notes(slide, cue, en, zh)` writes exactly:

```
【Cue】<one-line Chinese cue>

<English script>

【中文】
<Chinese script>
```

Main-slide notes run about 135-160 English words (about one minute at
140 wpm; measured 136-160 across the reference deck); backup notes run
20-55 words (about 15-25 s at 155 wpm).  `kit.self_check` reports word
counts and estimated minutes at 140/155 wpm.

## Workflow

1. **Extract the paper text** (PyMuPDF or the PMC XML) into a scratch
   file; read the results and figure legends.  Note panel letters and
   page numbers.
2. **Crop panels** with `kit/crop_pdf.py` at 300 dpi.  Read every warning:
   a crop edge cutting dark pixels means the panel is clipped; a mask
   hiding dark pixels may have erased an axis tick or a whole group.
3. **Build** with the layout functions.  Keep a stable filename for
   generated output; never write over the user's edited deck.
4. **Run `kit.self_check`**: minimum font, figure magnification, bullet
   lists, note words and minutes.  Fix every problem.
5. **Render and look**: `python kit/render_pptx.py deck.pptx pngs/`, then
   view every PNG.  Check overlap, clipped text, unreadable panels and
   empty space.
6. **Re-check facts** against the extracted paper text before delivery.

## Kit

```python
import sys
sys.path.insert(0, r"C:/Users/Wray/.claude/skills/research-slides/kit")
import jc_kit as kit

prs = kit.new_deck()
s = kit.slide_fig_side(
    prs, "RESULTS", "Vibration has its own statistics",
    "figs/f1d.png", "Smith et al., 2025, Fig. 1d",
    "Vibration intervals are several times longer than song pulses.",
)
kit.notes(s, "振动有自己的统计",
          "Vibration intervals are several times longer than song pulses. ...",
          "振动间隔比歌声脉冲间隔长好几倍。……")
kit.self_check(prs)
prs.save("deck_generated.pptx")
```

Available functions: `new_deck`, `blank`, `header`, `body`, `fig`,
`schem`, `notes`, `self_check`, `slide_title`, `slide_fig_side`,
`slide_two_figs_caption`, `slide_wide_fig`, `slide_schematic_text`,
`slide_approach`, `slide_summary`, `slide_backup`.

`kit/crop_pdf.py` crops PDF panels:

```bash
python crop_pdf.py paper.pdf figs spec.json
```

```json
{"dpi": 300,
 "regions": {"f1b": [3, 196, 45, 545, 139.5]},
 "masks":   {"f1b": [[300, 60, 330, 80]]}}
```

Region and mask units are PDF points, origin top-left.  The module API is
`crop(pdf, page, box, out, masks=..., trim=True)`; it returns the warning
list.

`kit/render_pptx.py` renders an approximate PNG of the saved deck without
Office: `python render_pptx.py deck.pptx outdir`.
