# PaperOrchestra reference

Distilled from upstream commit d9bae99: `methods/prompts/*.py`,
`methods/agents/content_refinement_agent.py` and `autoraters/agent_review.py`. The ML
defaults have been removed. Wherever a rule says "per contract", the project's
`orchestra/process.md` supplies the value.

## Knowledge isolation (every writer and refiner)

Write only from the raw materials, the citation_map and the figures. Do not recall or
reconstruct a published version of this work. Do not infer author identities or
affiliations. Anonymize only if the contract asks for it.

## Outline (`outline.json`)

```json
{
  "plotting_plan": [
    {"figure_id": "fig_semantic_name", "title": "...", "plot_type": "plot|diagram",
     "data_source": "idea.md|experimental_log.md|both",
     "objective": "the claim this figure supports, and the chart type",
     "aspect_ratio": "1:1|3:2|4:3|16:9|...", "serves": ["S2"]}
  ],
  "intro_related_work_plan": {
    "introduction_strategy": {
      "hook_hypothesis": "broad context",
      "problem_gap_hypothesis": "gap scoped strictly to the data in experimental_log.md",
      "search_directions": ["3-5 queries: why the gap matters, reviews, foundational papers"]
    },
    "related_work_strategy": {
      "overview": "...",
      "subsections": [
        {"subsection_title": "...", "methodology_cluster": "an approach or line of evidence close to ours",
         "sota_investigation_mission": "recent work before the cutoff, for context",
         "limitation_hypothesis": "what this line leaves open, per idea.md",
         "limitation_search_queries": ["narrow queries"],
         "bridge_to_our_method": "how our result addresses it"}
      ]
    }
  },
  "section_plan": [
    {"section_title": "...", "subsections": [
      {"subsection_title": "...",
       "content_bullets": ["specific, pointing at source files, e.g. 'state Eq. 3 from idea.md'"],
       "citation_hints": ["Author (Exact Title)", "or: work introducing 'Exact Name'"],
       "serves": ["S1", "S3"]}
    ]}
  ]
}
```

Rules:
- The Introduction cites broad context. The related-work clusters (2-4) cite close
  neighbors. The two lists do not overlap.
  - Sizes are per contract.
  - If the contract has no Related Work section, the clusters still guide the
    search and feed the Introduction and Discussion.
- `serves` names storyline sentences from `storyline.md`. A subsection that serves none
  is setup a later sentence depends on (say which) or goes to Methods or the supplement.
  `serves` IDs, log row IDs and material IDs are internal: they stay in the outline,
  trace and gate files and never appear in the paper's text.
- No orphan subsections: if X.1 exists, X.2 must exist.
- Every citation hint names exactly one canonical work. If the author is not known
  for certain, use the "work introducing" form instead of guessing.
- Claim superiority or difference only against what `experimental_log.md` actually
  compares. Present other work as context. The comparison object is per contract.

## Section writing

- Keep sections that are already written. Change them only where consistency
  requires it.
- Tables carry exact log values.
- Place tables and figures as the venue requires.
- Use every planned figure. Use the exact filenames. Describe what each plot actually
  shows.
- Cite with exact citation_map keys. Use the abstract to write specific sentences
  about each cited work.
- Include equations only where the materials support them.
- Dissect the evidence the contract names: what holds, what does not, and why.

## Reviewer rubric (AgentReview)

The reviewer has expertise in the paper's field. It is responsible and benign, and
critical of technical flaws. It reads the build and returns:
- a THOUGHT section, then JSON with Summary, Strengths, Weaknesses and Questions;
- sub-scores: Originality, Quality, Clarity, Significance, Soundness, Presentation and
  Contribution (each 1-4);
- Overall (1-10), Confidence (1-5) and Decision (Accept or Reject).

Overall anchors:
- 10: top 2%; would fight for acceptance.
- 8: top 10%; all claims supported.
- 6: major claims supported; minor gaps.
- 5: main claims insufficiently supported; leaning reject.
- 3: marginal contribution.
- 1: not thorough enough, or not relevant to the venue.

## Refinement accept/revert rule

Compare the new review with the previous one. The sub-axes are the seven sub-scores;
Overall and Confidence are not among them.
- Overall up → accept and continue.
- Overall down → revert to the previous version and stop.
- Overall equal:
  - if the sum of sub-axis gains is at least the sum of drops → accept and continue;
  - otherwise → revert and stop.

Log every round to the worklog: plan, scores before, scores after, deltas, outcome.

The author's turn:
- Turn each weakness into an edit.
- Answer each question inside the paper, not in a response letter.
- Keep the listed strengths.
- Ignore requests for new experiments or data.
- Check every number against `experimental_log.md`.
- Follow the contract's limitation rule.

## Formatting pass

One pass after the loop, run on the rendered pages. Fix overflowing or misplaced
floats, unreadable figures and broken references. Change only the layout, never the
content.
