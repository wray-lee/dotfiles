---
name: paper-orchestra
description: Write or revise a research paper in any field with the PaperOrchestra multi-agent flow (google-research/paper-orchestra) - raw materials, outline, verified literature with figure critique, section writing, then score-gated refinement with revert. Use when the user asks to draft, rewrite or run a revision round on a manuscript, or names PaperOrchestra.
---

# PaperOrchestra

This skill runs Google's PaperOrchestra pipeline (arXiv 2604.05018, upstream code at
commit d9bae99) with Workflow agents. Every stage reads files and writes files, so any
stage can be rerun on its own.

Upstream targets ML conference papers. This skill keeps upstream's stage contracts and
moves every field-specific choice into a per-project contract, `<paper>/orchestra/process.md`.

Other files:
- [`reference.md`](reference.md): upstream rules with the ML assumptions removed, and
  the schemas.
- [`workflow-template.js`](workflow-template.js): runs the stages.

## Before starting: the project contract

Read `<paper>/orchestra/process.md`. If it is missing, or does not answer a knob below,
fill the gap first. Take the answer from the user's instructions, project docs and
memory; if those do not settle it, ask. The contract holds project rules only; the
stage logic stays in this skill.

| Knob | What the contract states | Upstream ML default |
|---|---|---|
| Storyline | the author's N storyline sentences (file and section) | none (upstream has no storyline check) |
| Venue and build | format, section list, budgets, front matter, build command | conference LaTeX template, page limit |
| Related work | separate section, or carried by the Introduction and Discussion | separate section |
| Literature scale | rough reference counts for context and for close neighbors | 10-20 and 30-50 |
| Bibliographic indexes | where candidates are verified | Semantic Scholar |
| Claim framing | what a result is compared against (baselines, prior estimates, registered hypotheses) | beats SOTA baselines |
| Evidence analysis | what results sections must dissect (ablations, controls, sensitivity, failure cases) | ablations |
| Limitations | where and how often they are stated | never stated |
| Citation coverage | how many collected papers must be cited | at least 90% |
| Language rules | style boundaries that count as blockers | dense ML-conference tone |
| Placeholders | how blinded or pending values are written | none |
| Reader-facing labels | labels the paper itself may define and use (e.g. "Experiment 1", "(T1)" introduced in the text); all other IDs stay internal | none; internal IDs never appear |
| Number sources | which files count as ground truth for `experimental_log.md` | the experimental log |
| Ownership | which sections and figures others own (requests only, no edits) | none |
| Data limits | files and directories agents must not read or write | none |
| Blocker reviews | reviews the final version must pass besides the score loop and the built-in storyline review and label check | none |
| Agents | worker effort, fallback models, reviewer model and effort | Gemini |

When writing the contract, name sections and requirements in words ("the section on
epistemic superiors"), not by internal ID ("the T2a section"). Writers copy the
vocabulary of their instructions into the paper; IDs belong in trace and gate files only.

## Stages

Each stage ends on its completion criterion. Stages 2a and 2b run in parallel; every
other stage waits for the one before it.

0. **Raw materials** → `<paper>/orchestra/raw_materials/`
   - `idea.md`: question, contributions, theory, equations, hypotheses.
   - `experimental_log.md`: every number the paper may print, one row each, with its
     source path. Values that are not yet known are written as the contract's
     placeholders.
   - `guidelines.md`: the venue knob, written out.
   - `storyline.md`: the author's storyline as numbered sentences S1..Sn, copied from
     the Storyline knob. If the contract names none, draft 3–5 sentences from the
     abstract and mark them INFERRED. List every pending result with its outcome
     branches.

   Done when:
   - every number in the current draft, if a draft exists, has a row or is listed as
     an orphan;
   - every claim maps to a storyline sentence or is listed as a side branch.
1. **Outline** → `outline.json` with the three upstream keys: `plotting_plan`,
   `intro_related_work_plan` and `section_plan`. Every subsection and figure
   entry carries a `serves` field that names its storyline sentences. The schema is in
   `reference.md`.
   Done when:
   - every storyline sentence is served by at least one subsection and one figure;
   - every figure the storyline needs has a `plotting_plan` entry;
   - every dataset, method, statistic, model, instrument and software package named
     in the raw materials has a `citation_hints` entry.
2. **In parallel:**
   - **2a Literature.**
     - Run the outline's search queries.
     - Verify each candidate in the contract's indexes by exact title, year and DOI.
       Drop what cannot be verified or is past the cutoff, then deduplicate.
     - Write `literature/citation_map.json` (key → title, authors, year, venue, DOI,
       abstract) and `literature/refs-verified.bib`, keeping existing bib keys.
     - Draft the Introduction (and Related Work, if the contract has one) into
       `orchestra/drafts/`, citing only citation_map keys.

     Done when every `citation_hints` entry resolves to a verified key or is listed
     as unresolved.
   - **2b Figures.** A critic checks each `plotting_plan` figure against its objective
     and source data, for up to 3 rounds. Regenerate figures the project owns from
     their code. For figures another party owns, write a request; do not edit them.
     Done when every entry is accepted or carries an open request.
3. **Section writing.** Write the remaining sections from `outline.json`:
   - numbers come only from `experimental_log.md`;
   - citations come only from the citation_map;
   - every figure is placed and cited in the text;
   - each results paragraph opens with the claim of the storyline sentence it serves;
   - each pending branch has one definite version in the abstract, the title and the
     concluding sentence;
   - no internal ID reaches the text: storyline numbers (S1..Sn), log row IDs, material
     or argument-map IDs, and the contract's own shorthands are pipeline bookkeeping. The
     paper refers to things by description or by a name it defines for the reader, and
     only the contract's reader-facing labels may be used.

   Then build. Done when:
   - the build has no undefined citations or references;
   - every printed number traces to a log row;
   - every storyline sentence is carried by a topic sentence;
   - the label scan finds no internal ID in the rendered text.
4. **Refinement.** Run up to 3 iterations:
   - A reviewer scores the build with the rubric in `reference.md`.
   - On the first iteration only, the `storyline-review` skill also reviews the
     starting version, and its breaks are added to that round's edits.
   - The author revises and writes a worklog entry.
   - The reviewer scores the revision.
   - Apply the accept/revert rule. A revert ends the loop.

   After the loop:
   - Run one formatting pass on the rendered pages.
   - Run the storyline review again, the built-in label check (no internal ID in the
     visible text, abstract, titles, captions and footnotes included), and the
     contract's other blocker reviews.

   Done when all blocker reviews pass on the accepted version.

The storyline is built into every stage because upstream has no step that checks the
line of argument. The `storyline-review` skill stays a separate skill, so it can still
review slide decks and run on its own.

## Running it

Call the Workflow tool with `scriptPath` set to
`C:/Users/Wray/.claude/skills/paper-orchestra/workflow-template.js`. Pass the `args`
documented at the top of that file:
- paths;
- the contract text as `rules`;
- the stages to run;
- the cutoff and the build command;
- the storyline source;
- any extra blocker reviews;
- the agent settings.

The template's defaults are neutral (inherited model, no fallbacks). Every project
preference arrives through `args`.

Stages 0-2 write only under `orchestra/`, so they can run while another revision of the
draft is open. Stages 3-4 back up the live draft and then edit it, so they wait for
that revision.

To rerun one stage, pass only that stage in `args.stages` (`'2a'` or `'2b'` runs one half of stage 2); it reuses the files earlier
stages left on disk. Resume also works. Do not restart the whole pipeline.
