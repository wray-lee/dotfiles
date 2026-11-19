export const meta = {
  name: 'paper-orchestra',
  description: 'PaperOrchestra flow: raw materials, outline, literature + figures, section writing, score-gated refinement',
  phases: [{ title: 'Materials' }, { title: 'Outline' }, { title: 'Lit+Fig' }, { title: 'Write' }, { title: 'Refine' }],
}
// args: {
//   paper: abs path of the paper dir, orch: abs path of <paper>/orchestra,
//   (stages also accepts '2a' or '2b' to run only literature or only figures)
//   rules: project rules from process.md (language, data limits, ownership, number sources),
//   stages: subset of [0,1,2,3,4] (default all), cutoff: 'YYYY-MM',
//   context: extra inputs for this round (review files, decisions), optional,
//   build: build command for the PDF, blockers: [{k, prompt}] extra final blocker reviews, optional (storyline review and label check are built in),
//   storyline: where the author's storyline sentences live (path or path + section), optional; inferred from the abstract if absent,
//   agents: {effort, fallbacks: [{model, effort}], reviewer: {model, effort, agentType}}, optional; omitted fields inherit session defaults
// }
const A = args
const O = A.orch, R = O + '/raw_materials', L = O + '/literature', D = O + '/drafts', F = O + '/refine'
const ST = new Set(A.stages || [0, 1, 2, 3, 4])
const REF = 'C:/Users/Wray/.claude/skills/paper-orchestra/reference.md'
const SLR = 'C:/Users/Wray/.claude/skills/storyline-review/SKILL.md'
const RULES = `\nRead ${O}/process.md and ${REF} first; the project rules there override upstream. Project rules:\n${A.rules}\n${A.context ? 'Round context: ' + A.context + '\n' : ''}Internal IDs (storyline S1..Sn, log row IDs, material or argument-map IDs, contract shorthands) are pipeline bookkeeping: never write them into the paper text; refer to things by description or by a reader-facing label the contract allows. Write only the files your stage names; other stages own the rest. Turn discipline: keep calling tools until your completion criterion holds; return done=true only if your files really changed.`
const W = { type: 'object', properties: { done: { type: 'boolean' }, changed_files: { type: 'array', items: { type: 'string' } }, notes: { type: 'array', items: { type: 'string' } }, open_items: { type: 'array', items: { type: 'string' } } }, required: ['done', 'changed_files', 'notes', 'open_items'] }
const AG = A.agents || {}
const FALL = AG.fallbacks || []
const opt = (o) => Object.fromEntries(Object.entries(o).filter(([, v]) => v !== undefined))
// need: output paths that must appear in changed_files for a result to count (a fallback that wrote other files does not)
async function work(prompt, label, phase, need = []) {
  let r = null
  const ok = (x) => x && x.done && x.changed_files.length && need.every(n => x.changed_files.some(f => f.replace(/\\/g, '/').endsWith(n)))
  const p = prompt + RULES
  try { r = await agent(p, opt({ label, phase, schema: W, effort: AG.effort })) } catch (e) { log(`${label}: ${e}`) }
  for (const f of FALL) {
    if (ok(r)) break
    try { r = await agent(p + '\nAn earlier attempt ended early; inspect the files and finish.', opt({ label: `${label}:${f.model.slice(0, 4)}`, phase, schema: W, model: f.model, effort: f.effort })) } catch (e) { log(`${label}:${f.model}: ${e}`) }
  }
  if (!ok(r)) log(`${label}: no attempt produced ${need.join(', ') || 'changed files'}`)
  return r
}
const out = {}

if (ST.has(0)) {
  phase('Materials')
  out.materials = await parallel([
    () => work(`Stage 0a. Write ${R}/idea.md (question, contributions, theory, equations, hypotheses), ${R}/guidelines.md (venue sections, budgets, front matter, legend limits) and ${R}/storyline.md (the author's storyline as numbered sentences S1..Sn, ${A.storyline ? 'copied verbatim from ' + A.storyline : 'drafted from the abstract, 3-5 sentences, marked INFERRED'}; then every pending result with its outcome branches) from the draft in ${A.paper} and its source records. Completion: every claim of the current draft maps to an idea.md item and to a storyline sentence or is listed as a side branch.`, 'materials:idea', 'Materials'),
    () => work(`Stage 0b. Write ${R}/experimental_log.md: every number the paper may print, one row each (value, unit, what it is, source path:line). Blinded or pending values as typed placeholders. Completion: every number in the current draft in ${A.paper} has a row or is listed as an orphan under "## Orphans".`, 'materials:log', 'Materials'),
  ])
}
if (ST.has(1)) {
  phase('Outline')
  out.outline = await work(`Stage 1. Write ${O}/outline.json per the outline schema and rules in ${REF}, synthesizing ${R}/*.md and the existing draft (if ${O}/outline.json exists, revise it in place rather than starting over). Every section_plan subsection and plotting_plan entry carries a serves field naming storyline sentences from ${R}/storyline.md. Completion: every storyline sentence is served by at least one subsection and one figure; every needed figure has a plotting_plan entry; every dataset, method, statistic, model and software package in the raw materials has a citation_hints entry.`, 'outline', 'Outline', ['/outline.json'])
}
const S2A = ST.has(2) || ST.has('2a'), S2B = ST.has(2) || ST.has('2b')
if (S2A || S2B) {
  phase('Lit+Fig')
  const [lit, fig] = await parallel([
    async () => {
      if (!S2A) return null
      const found = await work(`Stage 2a search. Run every query in ${O}/outline.json (intro search_directions, related-work limitation_search_queries, citation_hints). Search with the available web and literature search tools; send queries only, never manuscript text. Verify each candidate in the contract's bibliographic indexes (for example Semantic Scholar api.semanticscholar.org/graph/v1/paper/search, Crossref api.crossref.org/works?query.bibliographic=, PubMed E-utilities) by exact title, year and DOI; drop unverifiable ones and anything after ${A.cutoff}. Keep all existing bib keys of the paper. Write ${L}/citation_map.json (key -> title, authors, year, venue, doi, abstract, verified_by), ${L}/refs-verified.bib and ${L}/search-log.md. Completion: every citation_hints entry resolves to a key or is listed as unresolved.`, 'lit:search', 'Lit+Fig', ['/citation_map.json', '/refs-verified.bib', '/search-log.md'])
      const intro = await work(`Stage 2a write. Write the Introduction (and Related Work, if the venue has one) into ${D}/introduction.md following intro_related_work_plan in ${O}/outline.json, citing only keys in ${L}/citation_map.json and using their abstracts for specific sentences. Do not edit the live draft. Completion: every paragraph serves the plan and every cite key exists.`, 'lit:write', 'Lit+Fig', ['/introduction.md'])
      return { found, intro }
    },
    () => !S2B ? null : work(`Stage 2b. For each plotting_plan entry in ${O}/outline.json, critique the figure against its objective and source data (render it and look at it), up to 3 rounds. Regenerate figures the project owns from their code into ${D}/figures/; for figures another party owns, write requests. Write ${O}/figure-critique.md. Completion: every entry accepted or carrying an open request.`, 'figures', 'Lit+Fig'),
  ])
  out.lit = lit; out.fig = fig
}
if (ST.has(3)) {
  phase('Write')
  out.write = await work(`Stage 3. Back up the live draft in ${A.paper} to ${F}/v0/ first. Then write or revise all remaining sections from ${O}/outline.json, merge ${D}/introduction.md and ${D}/figures/, using numbers only from ${R}/experimental_log.md and cite keys only from ${L}/citation_map.json; place and cite every figure. Build with: ${A.build}. The first sentence of each results paragraph states the claim of the storyline sentence it serves; every pending branch in ${R}/storyline.md gets one definite version in the abstract, title and conclusion. Completion: build succeeds with no undefined citations or references, every printed number traces to a log row, and every storyline sentence is carried by a topic sentence.`, 'write', 'Write')
}
if (ST.has(4)) {
  phase('Refine')
  const RV = { type: 'object', properties: { Summary: { type: 'string' }, Strengths: { type: 'array', items: { type: 'string' } }, Weaknesses: { type: 'array', items: { type: 'string' } }, Questions: { type: 'array', items: { type: 'string' } }, Originality: { type: 'number' }, Quality: { type: 'number' }, Clarity: { type: 'number' }, Significance: { type: 'number' }, Soundness: { type: 'number' }, Presentation: { type: 'number' }, Contribution: { type: 'number' }, Overall: { type: 'number' }, Confidence: { type: 'number' }, Decision: { type: 'string', enum: ['Accept', 'Reject'] } }, required: ['Summary', 'Strengths', 'Weaknesses', 'Questions', 'Originality', 'Quality', 'Clarity', 'Significance', 'Soundness', 'Presentation', 'Contribution', 'Overall', 'Confidence', 'Decision'] }
  const rv = AG.reviewer || {}
  const review = (v) => agent(`Review the compiled paper in ${A.paper} (version ${v}) as the AgentReview reviewer in ${REF}. Read the PDF and sources; write ${F}/review-${v}.md (THOUGHT + JSON) and return the JSON.` + RULES, opt({ label: `review:${v}`, phase: 'Refine', schema: RV, model: rv.model, effort: rv.effort, agentType: rv.agentType }))
  const AX = ['Originality', 'Quality', 'Clarity', 'Significance', 'Soundness', 'Presentation', 'Contribution']
  const story = (v) => agent(`Storyline review of the compiled paper in ${A.paper} (version ${v}). Read ${SLR} and follow it exactly (read-only); storyline: ${R}/storyline.md. Write ${F}/storyline-${v}.md with the full table and return the verdict: REJECT if any break or pending branch without a definite answer remains.` + RULES, opt({ label: `storyline:${v}`, phase: 'Refine', schema: { type: 'object', properties: { verdict: { type: 'string', enum: ['ACCEPT', 'REJECT'] }, blockers: { type: 'array', items: { type: 'string' } } }, required: ['verdict', 'blockers'] }, model: rv.model, effort: rv.effort, agentType: rv.agentType }))
  const [cur0, st0] = await parallel([() => review('v0'), () => story('v0')])
  let cur = cur0, log4 = []
  for (let i = 1; i <= 3 && cur; i++) {
    await work(`Refinement round ${i}. Snapshot the live draft in ${A.paper} to ${F}/v${i - 1}/ (skip if present). Revise the paper to address this review per the author rules in ${REF}: ${JSON.stringify(cur)}.${i === 1 && st0 ? ' Also repair the storyline breaks in ' + F + '/storyline-v0.md: ' + JSON.stringify(st0.blockers) + '.' : ''} Append the worklog entry to ${F}/worklog.json. Rebuild with: ${A.build}.`, `revise:v${i}`, 'Refine')
    const nxt = await review(`v${i}`)
    if (!nxt) break
    const d = AX.map(k => (nxt[k] || 0) - (cur[k] || 0))
    const gain = d.filter(x => x > 0).reduce((a, b) => a + b, 0), drop = -d.filter(x => x < 0).reduce((a, b) => a + b, 0)
    const ok = nxt.Overall > cur.Overall || (nxt.Overall === cur.Overall && gain >= drop)
    log4.push({ round: i, before: cur.Overall, after: nxt.Overall, gain, drop, outcome: ok ? 'ACCEPT' : 'REVERT' })
    log(`refine v${i}: Overall ${cur.Overall} -> ${nxt.Overall}, gain ${gain}, drop ${drop}, ${ok ? 'accept' : 'revert'}`)
    if (!ok) { await work(`Restore the live draft in ${A.paper} from snapshot ${F}/v${i - 1}/ exactly (the v${i} revision lowered the review score) and rebuild with: ${A.build}. Record the revert in ${F}/worklog.json.`, `revert:v${i}`, 'Refine'); break }
    cur = nxt
  }
  out.refine = log4
  out.format = await work(`Formatting pass on the compiled PDF in ${A.paper}: render pages, fix overfull or misplaced floats, unreadable figures, broken references. layout only, no content change. Rebuild with: ${A.build}.`, 'format', 'Refine')
  const labels = () => agent(`Label check (read-only) of the paper in ${A.paper}: scan the visible text of the source (abstract, titles, body, captions, footnotes; ignore \\label{} and \\ref{} keys and comments) for internal IDs: storyline numbers S1..Sn from ${R}/storyline.md, row IDs from ${R}/experimental_log.md, and any other ID used in the raw materials or the contract. Labels the contract lists as reader-facing are allowed only if the paper defines them before first use. Return REJECT with each hit quoted (at most 15 words of context) if any remain.` + RULES, { label: 'blocker:labels', phase: 'Refine', schema: { type: 'object', properties: { verdict: { type: 'string', enum: ['ACCEPT', 'REJECT'] }, blockers: { type: 'array', items: { type: 'string' } } }, required: ['verdict', 'blockers'] }, ...opt({ model: rv.model, effort: rv.effort, agentType: rv.agentType }) })
  out.blockers = await parallel([() => story('final'), labels, ...(A.blockers || []).map(b => () => agent(b.prompt + RULES, { label: `blocker:${b.k}`, phase: 'Refine', schema: { type: 'object', properties: { verdict: { type: 'string', enum: ['ACCEPT', 'REJECT'] }, blockers: { type: 'array', items: { type: 'string' } } }, required: ['verdict', 'blockers'] }, ...opt({ model: rv.model, effort: rv.effort, agentType: rv.agentType }) }))])
}
return out
