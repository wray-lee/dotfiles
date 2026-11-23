---
name: paper-orchestra
description: Write or revise a research paper in any field with the PaperOrchestra multi-agent flow (google-research/paper-orchestra) - raw materials, outline, verified literature with figure critique, section writing, then score-gated refinement with revert. Use when the user asks to draft, rewrite or run a revision round on a manuscript, or names PaperOrchestra.
---
# PaperOrchestra
Run this flow with Workflow agents in a paper directory holding a draft or notes and a build command. Project rules live in `<paper>/orchestra/process.md`. Follow [`reference.md`](reference.md), [`workflow-template.js`](workflow-template.js) and `draft_store.py` exactly. Workflow scripts use no filesystem; every on-disk fact comes from an agent's structured return. Every prompt passes single-quoted paths and returns JSON.
## Contract and knobs
The first step writes the contract when absent, then reads its fields; args fill gaps. An existing contract is read-only. Knobs: Storyline; Venue and build; Related work; Literature; Claim and evidence; Limitations; Citation coverage; Language rules; Placeholders; Reader-facing labels; Draft files; Argument sections; Ownership and limits; Blocker reviews; Agents. [`reference.md`](reference.md) is the single source for fields, paths, delivery, builds, checks, reports, scores and shell commands.
One invocation owns one run tag; `refine/<run>/` is history. Avoid concurrent runs on the same paper. Stage 2a and 2b dispatch (Related Work, empty figure plan, cutoff), the single NOT_RUN stop rule for any missing score or check result, reports, scores and build rules are defined once in [`reference.md`](reference.md).
## Stages
0. **Raw materials** → `orchestra/raw_materials/`: `idea.md`, `experimental_log.md`, `guidelines.md`, `storyline.md`.
1. **Outline** → `outline.json`: served sentences, planned figures and `citation_hints`.
2. **2a Literature / 2b Figures**: verified citations and venue sections; figure critique.
3. **Section writing.** Write from the outline, build, snapshot `write`, pass the label check. A stage-3-only run ends with the final gate.
4. **Refinement.** Score-gated rounds with revert, accepted snapshot, format, build and the one final gate. The storyline review uses `args.storyline_skill` or `<skill_dir>/../storyline-review/SKILL.md`. Agents stay inside their run. Stage 4 needs stage-0 materials even alone; stage 3 alone needs them plus an empty draft baseline.
## Running it
Call Workflow with `scriptPath` set to `workflow-template.js`. Required: `paper`, `orch`, `run`, `rules` (paper and orch absolute). Optional: `build`, `shell`, `stages`, `cutoff`, `storyline`, `context`, `draft_files`, `skill_dir`, `storyline_skill`, `blockers`, `review_keys`, `agents`, `outputs`, `output_dirs`, `source_outputs`, `intermediates`, `venue`. `run` is a safe tag name; use a new tag per invocation. Stages default to all; 0-2 need no build; 3-4 do. `skill_dir` is absolute or located by the first agent step. `draft_store.py` commands run in Bash, Git Bash on Windows.
