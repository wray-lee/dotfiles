---
name: storyline-review
description: Read-only review of whether a paper draft or slide deck carries its storyline - topic-sentence chain against the author's N-sentence storyline, claim/figure cross-reference, a clear answer under every pending result branch, and side branches that dilute the line. Use before delivering a manuscript or deck, when the user asks "is the storyline coherent", or as a review dimension in a paper-review brief.
---

# Storyline review

Checks whether a manuscript or deck tells the story its author meant to
tell.  Sentence-level style (signposts, buzzwords, dashes) and code or
statistics review are other checks; this one is only about the line of
argument.

**Read-only.**  Never edit the manuscript or deck.  The output is a
break list with repair suggestions.

Why it exists: a talk on 2026-11-16 left claims half-argued because the
figure that bridged them was missing, and the NSMoR draft had the same
gap.  Its outline stated "the behavioral window alone cannot decide
convergence", but no paragraph said it, so a strong effect followed by a
race-consistent test read as a contradiction.

## Inputs

1. **The material**: `.tex` / `.md` sections in reading order, or a
   `.pptx`.  For LaTeX, follow `\input{}` from the main file so the
   order is the compiled order.
2. **The storyline**: N sentences (usually 3-5) written by the author,
   e.g. an outline's "main line" section.  If none exists, ask the author
   for it, or draft one from the abstract (one sentence per claim the
   abstract makes, 3-5 sentences) and report that it was inferred.  If
   N sentences cannot be written at all, that is the first finding.
   If two storyline texts exist, use the one the user named and report
   where the other diverges.
3. If several versions coexist (outline vs assembled draft, old vs new
   format, several deck copies), review the one the user named; if none
   was named, the newest, and report the gap to the others.

**Decks.**  The "topic sentence" of a slide is its title (the title
placeholder, or the largest bold text near the top; ignore the small
section eyebrow).  Review main slides only: the title slide, the summary
and backup slides (B1, B2 ...) are not in the chain, and material already
in backups counts as routed out (check 4).  A claim that appears only in
the speaker notes, not on the slide, is a buried claim.  Locations are
"slide n".

## The four checks

### 1. Topic-sentence chain

Extract the first sentence of every Results paragraph (for a deck, every
main slide's title) in order.  A paragraph is what the reader sees
rendered (in LaTeX, text between blank lines), not a source line.  First pass: read only that list, as a
skimming reader would, and map each one to the storyline sentence it
serves.  Second pass: open the paragraph (or slide body and notes) only
where the mapping fails, to locate the hidden claim or confirm the gap.

- A storyline sentence that no topic sentence carries is a **break**.
  This is the most important finding type.  Name what the missing
  paragraph must say.
- A topic sentence that serves no storyline sentence goes to check 4.
- A topic sentence that states a method or a number instead of a claim
  is a **buried claim**.  Quote the claim hidden later in the paragraph.
- Adjacent claims that look contradictory without a bridge (strong effect,
  then a null test) are a break even when each paragraph is correct.
  Test: would a reader who only saw the two titles ask "then how can
  both be true?"  If the answer sits only in Methods, notes or another
  section, the bridge is missing.

### 2. Claims and figures, both directions

- Every result claim points to a figure or panel.  A claim whose
  evidence is not shown is a break.  Name the figure that would carry it.
- Every figure panel is cited in the text at least once.  An uncited
  panel is either a missing sentence or a side branch.
- Placeholders, `[proposal]`, `PENDING` and undrawn panels are delivery
  blockers, not storyline breaks; they go in the same table, last.
- For LaTeX, build a per-panel table: one row per panel letter found in
  the real caption text (wherever the captions live; ignore placeholder
  floats), with the number of body citations.  Count all citation forms:
  `Figure 2C`, `Figures 2B and 2C`, `Figure 2B-2D` / `2B–D` ranges,
  `\ref{}`.  A panel with zero citations is a finding.  For decks, check the claim
  side only: every claim on a slide has its evidence on that slide or a
  cited neighbor.  Panel coverage of a presented paper is a separate,
  code-enforced check (`research-slides` journal-club `self_check`).

### 3. A clear answer under every pending branch

For every result not yet known (unblinding, a pending experiment, a
pending reviewer decision).  Skip this check, and say so in one line,
when nothing is pending (e.g. a talk on a published paper):

- The Summary or abstract, the title and the concluding sentence each
  need one version per outcome (for example positive and null; use the
  outcome list of the preregistration or plan when it has more than
  two).  A `PENDING` placeholder for a result value belongs here, not
  under delivery blockers.  The
  concluding sentence is the last sentence of the Summary / abstract and
  the last claim paragraph of the Discussion (not a limitations
  paragraph).  A placeholder such as `[AUTHOR: title]` counts as no
  version.
- Each version must give a clear answer.  A null branch states what the
  null shows ("the window is what independent competition predicts"),
  not a hedge ("was consistent with ... ; the circuit states where ...").
- A sentence that reads acceptably under both branches is usually
  answering neither.  Flag it.

### 4. Side branches

A paragraph, figure or section that serves no storyline sentence.  Setup
that a later storyline sentence depends on (e.g. single-channel
baselines that a test freezes) serves that sentence and is not a side
branch:

- Suggest moving it to Supplementary or Methods, or name the storyline
  sentence it could serve after one linking sentence.
- Also flag a model or extension section whose only link is "the same
  equation, rewritten".  It needs one sentence saying what it adds that
  the main result cannot (e.g. predictions that recordings could separate).
- Method detail inside Results paragraphs (fit counts, folds, solver
  settings) that hides the claim also goes here, with Methods as the
  destination.

## Output

Return everything in the final message; a narration of what you are
about to do is not a result.

1. A short header: the material and storyline used, whether the
   storyline was inferred, version gaps, checks skipped and why.
2. One table, ordered by impact on the storyline (breaks first, then
   pending-branch answers, buried claims, side branches, delivery
   blockers):

   | # | Check | Location (`file:line` or slide n) | Problem | Repair |

3. At most three sentences: whether the storyline holds, and the one
   repair to do first.  Write in the user's working language.  Quote the
manuscript exactly.  A repair names what the missing sentence must
answer and its shape (e.g. "null branch: say the window is what the
frozen channels predict, without convergence"), but never invents
results, numbers or figure content; mark those `[AUTHOR: ...]`.

## Using it as a review dimension

In a paper-review brief, name this skill as one dimension next to the
language and statistics reviews.  The reviewer returns the table only.
Fixing the breaks is the authors' writing task; this skill does not
write the paragraphs.
