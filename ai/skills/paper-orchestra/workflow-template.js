export const meta = {
  name: 'paper-orchestra',
  description: 'PaperOrchestra flow: raw materials, outline, literature + figures, section writing, score-gated refinement',
  phases: [{ title: 'Materials' }, { title: 'Outline' }, { title: 'Lit+Fig' }, { title: 'Write' }, { title: 'Refine' }, { title: 'Gates' }],
}
const A=args, fail=(m)=>{throw new Error(`args: ${m}`)}, rel=(p)=>typeof p==='string'&&Boolean(p.trim())&&!/^[A-Za-z]:[\/]/.test(p)&&!p.startsWith('/')&&!/(^|[\/])\.\.([\/]|$)/.test(p)
if(!A||typeof A!=='object')fail('an object is required')
for(const k of ['paper','orch','run'])if(typeof A[k]!=='string'||!A[k].trim())fail(`${k} is required`)
for(const k of ['paper','orch'])if(!/^[A-Za-z]:[\\/]/.test(A[k])&&!A[k].startsWith('/'))fail(`${k} must be an absolute path`)
if(typeof A.rules!=='string'||!A.rules.trim())fail('rules is required')
for(const k of ['skill_dir','storyline_skill','storyline','build','shell'])if(A[k]!==undefined&&(typeof A[k]!=='string'||!A[k].trim()))fail(`${k} must be a string`)
const literal=(k,x)=>rel(x)&&!/[*?[]/.test(x)
for(const k of ['outputs','source_outputs','output_dirs','intermediates','draft_files'])if(A[k]!==undefined&&(!Array.isArray(A[k])||!A[k].every((x)=>literal(k,x))))fail(`${k} must be literal paths under the paper`)
if(A.venue!==undefined&&(!A.venue||typeof A.venue!=='object'||Array.isArray(A.venue)))fail('venue must be an object')
if(A.context!==undefined&&typeof A.context!=='string')fail('context must be a string')
if(!/^[A-Za-z0-9][A-Za-z0-9._-]*$/.test(A.run)||A.run.includes('..'))fail('run must be a safe tag name')
const BUILTIN_K = ['labels', 'contract', 'storyline', 'evidence', 'materials', 'outline', 'citations', 'figures', 'numbers', 'refs', 'language', 'review'];
const safeK = (k) => typeof k === 'string' && /^[A-Za-z][A-Za-z0-9_-]*$/.test(k)
if (A.review_keys !== undefined && (!Array.isArray(A.review_keys) || !A.review_keys.every(safeK))) fail('review_keys must be safe keys')
if (A.blockers !== undefined && (!Array.isArray(A.blockers) || A.blockers.some((b) => !b || typeof b !== 'object' || !safeK(b.k) || typeof b.prompt !== 'string'))) fail('blockers must be {k,prompt} with safe keys')
const BKEYS = (A.blockers || []).map((b) => b.k);
const custom = BKEYS.filter((k) => !BUILTIN_K.includes(k))
if (custom.length !== new Set(custom).size) fail('blocker keys must be unique')
if (A.agents !== undefined && (!A.agents || typeof A.agents !== 'object' || Array.isArray(A.agents))) fail('agents must be an object')
if (A.agents && A.agents.fallbacks !== undefined && (!Array.isArray(A.agents.fallbacks) || A.agents.fallbacks.some((f) => !f || typeof f !== 'object'))) fail('fallbacks must be objects')
const RAW = A.stages === undefined ? [0, 1, 2, 3, 4] : (Array.isArray(A.stages) ? A.stages : [A.stages])
const ST = new Set(RAW.map((s) => {
const v = String(s).trim(); if (!['0','1','2','2a','2b','3','4'].includes(v)) fail(`unknown stage ${JSON.stringify(s)}`); return v }))
if (!ST.size) fail('stages is empty')
const S2A = ST.has('2') || ST.has('2a'), S2B = ST.has('2') || ST.has('2b'), DRAFT = ST.has('3') || ST.has('4')
const SR = { '0': 0, '1': 1, '2': 2, '2a': 2.1, '2b': 2.2, '3': 3, '4': 4 }, LAST_STAGE = [...ST].sort((a, b) => SR[a] - SR[b]).pop(), LAST_STAGE_V = /^[0-4]$/.test(LAST_STAGE) ? Number(LAST_STAGE) : LAST_STAGE
const AG = A.agents || {}, FALL = AG.fallbacks || [], RV = AG.reviewer || {}
let EFFORT = AG.effort, REVIEWER = RV, FALLBACKS = FALL, PARALLEL_MAX = Number.isInteger(AG.max_parallel) && AG.max_parallel > 0 ? AG.max_parallel : 3
const pairRun = async (a, b) => {
  if (PARALLEL_MAX >= 2) return parallel([a, b])
const first = await a(); if (stopped) return [first, null]; return [first, await b()]
}
const O=String(A.orch).replace(/[\\/]+$/, ''),R=O+'/raw_materials',L=O+'/literature',D=O+'/drafts',F=O+'/refine/'+A.run, opt= (o) => Object.fromEntries(Object.entries(o).filter(([, v]) => v !== undefined)), norm = (p) => String(p).replace(/\\/g, '/'), slug = (s) => String(s).replace(/[^A-Za-z0-9_-]/g, '-')
const OREL = (norm(O).replace(/\/$/, '') + '/').startsWith(norm(A.paper).replace(/\/$/, '') + '/') ? norm(O).replace(/\/$/, '').slice(norm(A.paper).replace(/\/$/, '').length + 1) : 'orchestra'
const pReport = (k, t) => `${F}/check-${k}-${t}.md`, pScope = () => `${F}/scope.json`, pReceipt = (n) => `${F}/receipt-${slug(String(n).split('/').pop())}.json`, WORKLOG=`${F}/worklog.json`
const firstBaseOf = () => ST.has('3') ? 'pre-write' : 'pre-v0'
const logRound = (n, record) => `Append to ${WORKLOG} a record with round key "${n}": ${record}. If a record with that key already exists, replace it; never append a duplicate.`, tagOf = (n) => `${A.run}/${n}`
const AX=['Originality','Quality','Clarity','Significance','Soundness','Presentation','Contribution'],SKEYS=[...AX,'Overall','Confidence']
const strArr = { type: 'array', items: { type: 'string' } }, bool = { type: 'boolean' }, str = { type: 'string' }
const STORYLINE = {type:'object',properties:{file:str,section:str,sentences:strArr}}
const VENUE_SCHEMA = {type:'object',properties:{introduction:bool,figures:bool,related_work:bool}}
const AGENTS = {type:'object',properties:{effort:str,max_parallel:{type:'number'},fallbacks:{type:'array',items:{type:'object'}},reviewer:{type:'object',properties:{agentType:str,model:str,effort:str}}}}
const W={type:'object',properties:{done:bool,changed_files:strArr,verified:strArr,store_output:str,notes:strArr,open_items:strArr,no_change:bool,scope:{type:'object'},contract_reviews:strArr,ok:bool,build:str,shell:str,outputs:strArr,output_dirs:strArr,source_outputs:strArr,intermediates:strArr,draft_files:strArr,cutoff:str,venue:VENUE_SCHEMA,storyline:STORYLINE,agents:AGENTS,build_result:{type:'object',properties:{returncode:{type:'number'},started:{type:'number'},files:{type:'array',items:{type:'object',properties:{path:str,sha256:str,mtime:str},required:['path','sha256','mtime']}},verified:strArr,sources:strArr,written:strArr,deliverables:strArr,pre_digest:str,post_digest:str,digest:str},required:['returncode','files']}},required:['done','changed_files','notes','open_items']}
const jsonObjects = (t) => {
const src=String(t || ''), out=[]; let d=0, start=-1, str=false, esc=false; for (let i=0; i<src.length; i++) {
const c=src[i]; if (str) { if (esc) esc=false; else if (c === '\\') esc=true; else if (c === '"') str=false; continue } if (c === '"') { str=true; continue } if (c === '{') { if (d === 0) start=i; d++ } else if (c === '}' && start >= 0) { d--; if (d === 0) { try { out.push(JSON.parse(src.slice(start,i+1))) } catch (e) {} start=-1 } } } return out }
const storeOk = (s) => Boolean(s && s.ok === true), storeOks = (t) => {
const xs = jsonObjects(t); return xs.length > 0 && xs.some(storeOk) && xs.every((x) => x.ok !== false) }
const okWork = (x, need, store, prompt) => {
  if (!x || !x.done || x.ok === false) return false
const files = [...(x.changed_files || []), ...(x.verified || [])]
const missing = need.filter((n) => !files.some((f) => norm(f) === norm(n)))
  if (missing.length) return false
  return !store || storeOks(x.store_output)
}
const literalPath = (s) => typeof s === 'string' && s.trim().length > 0 && !/[*?[]/.test(s)
const listOf = (x) => Array.isArray(x) && x.every(literalPath)
const okScope = (x) => Boolean(x && x.scope && Array.isArray(x.scope.include) && x.scope.include.length && listOf(x.scope.include) && listOf(x.scope.exclude) && listOf(x.scope.owned))
const out = {}, seen = { reports: [], files: [], tags: [] }, openItems = [], tagReceipt = {}, tagDigest = {}
const noteFile = (p, kind) => { if (typeof p === 'string' && p.trim() && !seen.files.some((f) => f.path === p)) seen.files.push({ path: p, kind }) }
const knownTags = new Set()
const noteTag = (t) => { if (typeof t === 'string' && t.trim() && !seen.tags.includes(t)) seen.tags.push(t) }
const noteLive = (t) => { noteTag(t); currentTag = restorePoint = t }
const noteUnsnap = (t) => { noteTag(t); currentTag = null; if (typeof t === 'string' && t.trim() && knownTags.has(t)) restorePoint = t }
const noteReceipt = (n) => { tagReceipt[tagOf(n)] = pReceipt(n) }
const noteOpen = (xs) => { for (const x of Array.isArray(xs) ? xs : []) if (typeof x === 'string' && x.trim() && !openItems.includes(x)) openItems.push(x); out.open_items = openItems }
let stopped = null, skillDir = A.skill_dir || null, EMPTY_BASELINE = false
let REF = skillDir ? skillDir + '/reference.md' : ''
const stop = (stage, extra) => { if (!stopped) stopped = { status: 'STOPPED', stage, ...(extra || {}) }; else if (extra && String(extra.reason || '').startsWith('restore_failed')) stopped.restore = extra.reason; return stopped }
const finalState = () => ({ last_accepted_tag: acceptedTag, current_tag: currentTag,
  ...(revertTag ? { revert_tag: revertTag } : {}), ...(currentTag ? {} : restorePoint ? { restore_tag: restorePoint } : {}) })
const result = (status, extra = {}) => ({ status, ...(stopped ? { stage: stopped.stage, reason: stopped.reason, ...Object.fromEntries(Object.entries(stopped).filter(([k]) => !['status','stage','reason'].includes(k))) } : {}), ...extra, out, open_items: out.open_items || [], ...finalState() })
let acceptedTag = null, currentTag = null, revertTag = null, restorePoint = null, fmtTag = null
const reasonOf = (x) => (x && Array.isArray(x.notes) && x.notes.length && typeof x.notes[0] === 'string') ? x.notes[0] : 'no usable result'
const HITS = { type: 'array', items: { type: 'object', properties: { token: str, class: { type: 'string', enum: ['internal','unlisted_label','before_definition'] }, first_location: str, count: { type: 'number' }, quote: str }, required: ['token','class','first_location','count','quote'] } }
const VERDICT = { type: 'object', properties: { verdict: { type: 'string', enum: ['ACCEPT', 'REJECT', 'NOT_RUN'] }, report: str, blockers: strArr, hits: HITS, open_items: strArr, contract_reviews: strArr, store_output: str }, required: ['verdict', 'report', 'blockers'] }
const SCORE = { type: 'object', properties: Object.fromEntries(SKEYS.map((k) => [k, { type: 'number' }])), required: SKEYS }
const REVIEW = { type: 'object', properties: { THOUGHT: str, Summary: str, Strengths: strArr, Weaknesses: strArr, Questions: strArr, scores: SCORE, decision: { type: 'string', enum: ['Accept','Reject'] }, verdict: { type: 'string', enum: ['ACCEPT','REJECT','NOT_RUN'] }, report: str, blockers: strArr, open_items: strArr, store_output: str }, required: ['Summary','verdict','report','blockers'] }
const RULES = () => `\nRead ${O}/process.md and ${REF} first; project rules there override upstream. The contract is read-only after the first step; a contract question stays an open item for its owner. Project rules:\n${A.rules}\n${A.context ? 'Round context: ' + A.context + '\n' : ''}Internal IDs (storyline numbers, ticket codes, review items, material IDs, contract shorthands) stay in pipeline files, never in paper text. Rendered placeholders are printed text: describe pending values in words. Write only the files your stage names; return the complete, untruncated JSON printed by each draft store command in store_output; list every file you write in changed_files. Put findings and verdicts in the reports your prompts name. Checks read built outputs and never rebuild. Workflow agents work inside this run: use no SendMessage and no ListAgents. Checks and reviews are run by the workflow. Turn discipline: keep calling tools until your completion criterion holds; report done=true only when the named files are complete.`
const reportRule = (k, t) => `Write the report to exactly ${pReport(k, t)}. Its first line is "run ${A.run} | check ${k} | ${t}", its second "Verdict: ACCEPT|REJECT|NOT_RUN", its third "Blockers: <count>". Then one blocker line per declared blocker on its own line between the literal lines "BLOCKERS BEGIN" and "BLOCKERS END"; use "none" inside the block for zero. Tables, THOUGHT and score JSON may appear before the first marker or after the second. The count and verdict must equal the returned structure; substitute your returned verdict for <verdict> and your returned blocker count for <count>. Then run ${SHELL(checkReportCmd(pReport(k, t), k, t, '<verdict>', '<count>'))} and return its JSON in store_output. Return that path in report. A result without this report, or a store finding, is NOT_RUN.`
let lastResult = null
async function work(prompt, label, ph, stage, need = [], store = false, retry = true) {
const p = prompt + RULES()
const ok = (x) => okWork(x, need, store, p)
  let r = null
  try { r = await agent(p, opt({ label, phase: ph, schema: W, effort: EFFORT })) } catch (e) { log(`${label}: ${e}`) }
  for (const f of FALLBACKS) {
    if (!retry || !r || r.done === false || ok(r) || stopped) break
    try { r = await agent(p + '\nAn earlier attempt ended early; inspect the files and finish.', opt({ label: `${label}:${String(f.model).slice(0, 4)}`, phase: ph, schema: W, model: f.model, effort: f.effort, agentType: REVIEWER.agentType })) } catch (e) { log(`${label}:${f.model}: ${e}`) }
  }
  lastResult = r
  if (!ok(r)) {
const reason=r ? reasonOf(r) : 'agent_died'; log(`${label}: ${reason}`); stop(stage, { reason: r ? reason : 'agent_died' }); return null }
  if (need.includes(WORKLOG)) noteFile(WORKLOG, 'log')
  noteOpen(r.open_items)
  return r
}
// scoreNotRun: any NOT_RUN stops; no scoring, repair or restore.
const notRunReason = (k, x) => 'not_run: ' + k + (x && Array.isArray(x.blockers) && typeof x.blockers[0] === 'string' && x.blockers[0].trim() ? ': ' + x.blockers[0] : '')
const notRunStop = (k, x, stage) => { const res = { ...(x || {}), k, verdict: 'NOT_RUN', blockers: Array.isArray(x && x.blockers) ? x.blockers : [], open_items: (x && x.open_items) || [], report: (x && x.report) || '' };
  stop(stage, { reason: notRunReason(k, res) }); noteOpen(res.open_items); return res }
async function check(prompt, k, t, ph, stage, schema = VERDICT) {
const report = pReport(k, t), scored = schema === REVIEW, label = `check:${k}:${t}`
const p = prompt + ' ' + reportRule(k, t) + '\nWrite the report only to this exact path: ' + report + '\n' + RULES()
  let r = null
  try { r = await agent(p, opt({ label, phase: ph, schema, model: REVIEWER.model, effort: REVIEWER.effort, agentType: REVIEWER.agentType })) } catch (e) { log(`${label}: ${e}`) }
  for (const f of FALLBACKS) {
    if (!r || r.agent_died || r.verdict === 'NOT_RUN' || okCheck(r, report, scored, k, t) || stopped || (scored && (r.decision === 'Reject' || r.verdict === 'REJECT' || (Array.isArray(r.blockers) && r.blockers.length)))) break
    try { r = await agent(p + '\nAn earlier attempt ended early; finish the check and return its report path in report.', opt({ label: `${label}:${String(f.model).slice(0, 4)}`, phase: ph, schema, model: f.model, effort: f.effort, agentType: REVIEWER.agentType })) } catch (e) { log(`${label}:${f.model}: ${e}`) }
  }
  if (!r || r.agent_died) { stop(stage, { reason: 'agent_died' }); return { k, verdict: null, agent_died: true, report: '', blockers: [], open_items: [] } }
  if (!okReport(r, report, k, t)) {
    if (r.verdict === 'NOT_RUN' || (scored && (!r.scores || !SKEYS.every((x) => inScore(r.scores[x], x))))) return notRunStop(k, r, stage)
    stop(stage, { reason: 'no usable report: ' + k }); return { k, verdict: null, agent_died: true, report: '', blockers: [], open_items: [] }
  }
  if (r.verdict === 'NOT_RUN' || (scored && (!r.scores || !SKEYS.every((x) => inScore(r.scores[x], x))))) return notRunStop(k, r, stage)
const res = okCheck(r, report, scored, k, t) ? r : { ...r, verdict: 'REJECT', open_items: r.open_items || [] }
const prev = seen.reports.find((x) => x.path === report)
  if (prev) prev.verdict = res.verdict; else seen.reports.push({ path: report, verdict: res.verdict })
  noteOpen(res.open_items)
  return res
}
const rejected = (x) => Boolean(x && x.verdict !== 'NOT_RUN' && (x.verdict === 'REJECT' || x.decision === 'Reject' || (Array.isArray(x.blockers) && x.blockers.length)))
const runChecks = async (list) => {
const results = []
  for (let i = 0; i < list.length; i += PARALLEL_MAX) {
const batch = list.slice(i, i + PARALLEL_MAX)
const done = await parallel(batch.map((c) => async () => c.thunk()))
    results.push(...batch.map((c, i) => ({ k: c.k, ...(done[i] || { verdict: null, report: '', blockers: [], open_items: [] }) })))
const nr = results.find((x) => x.verdict === 'NOT_RUN')
    if (nr) stop('Gates', { reason: notRunReason(nr.k, nr) })
    if (stopped) break
  }
  return results
}
function inScore(v, k) { return typeof v === 'number' && Number.isFinite(v) && v >= 1 && v <= (k === 'Overall' ? 10 : k === 'Confidence' ? 5 : 4) }
function okReport(x, report, kind, tag) { if (!x || !['ACCEPT','REJECT','NOT_RUN'].includes(x.verdict) || norm(x.report) !== norm(report) || !x.store_output) return false; return jsonObjects(x.store_output).some((j) => j.ok === true && j.check_report === true && j.exists === true && Array.isArray(j.findings) && j.findings.length === 0 && norm(j.report || '') === norm(report) && j.kind === kind && j.tag === tag && j.run === A.run) }
function okCheck(x, report, scored, kind, tag) { return okReport(x, report, kind, tag) && (x.verdict === 'ACCEPT' ? !(x.hits && x.hits.length) && !(x.blockers && x.blockers.length) && (!scored || Boolean(x.scores) && SKEYS.every((k) => inScore(x.scores[k], k))) : x.verdict === 'NOT_RUN' || (Array.isArray(x.blockers) && x.blockers.length > 0)) }
const SQESC = String.fromCharCode(39,92,39,39), q = (s) => "'" + String(s).replace(/'/g, SQESC) + "'"
const sEsc = (s) => "'" + String(s).replace(/'/g, String.fromCharCode(39,92,39,39)) + "'"
const SHELL = (cmd) => `Run in Bash (Git Bash on Windows) with the python on PATH and single-quoted paths for that shell: ${cmd}. Return its complete JSON verbatim in store_output. A store command reports errors with ok=false; expected findings are ok=true with a findings array. Read findings and stop only when this step's rule names one. End done=false on an ok=false.`
const storeCmd = (c, extra = '') => `python ${q(skillDir + '/draft_store.py')} ${c} --paper ${q(A.paper)}${extra}`
const safeArg = (p) => sEsc(String(p).startsWith('-') ? './' + String(p) : p)
const resolveCmd = (paths) => `python ${q(skillDir + '/draft_store.py')} resolve-paths --paper ${q(A.paper)} --paths ${paths.map(safeArg).join(' ')}`
const beginCmd = (t, now) => storeCmd(`begin --scope ${safeArg(pScope())} --tag ${q(t)}${now === 'empty' ? ' --now empty' : ''}`)
const snapCmd = (t, empty = false) => storeCmd(`snap --scope ${safeArg(pScope())} --tag ${q(t)}${empty ? ' --now empty' : ''}`)
const verifyCmd = (t) => storeCmd(`verify --tag ${q(t)}`)
const auditCmd = (t) => storeCmd(`audit --tag ${q(t)}`)
const checkReportCmd = (path, kind, tag, verdict, count) => storeCmd(`check-report --report ${safeArg(path)} --kind ${q(kind)} --tag ${q(tag)} --run ${q(A.run)} --verdict ${q(verdict)} --count ${q(count)}`)
const recordDigestCmd = (path) => storeCmd(`record-digest --build-file ${safeArg(path)}`)
const restoreCmd = (t, e) => storeCmd(`restore --tag ${q(t)}${e ? ` --expect ${q(e)}` : ''}`)
const restorePendingCmd = (t) => storeCmd(`restore-pending --tag ${q(t)}`)
const digestCmd = () => storeCmd(`digest --scope ${safeArg(pScope())}`)
const inventoryCmd = () => storeCmd(`inventory --scope ${safeArg(pScope())} --run ${q(A.run)}`)
const preInvPath = (g) => `${F}/pre-inventory-${slug(g)}.json`
const checkInventoryCmd = (g) => storeCmd(`check-inventory --build ${q(slug(g))} --path ${q(preInvPath(g))} --scope ${safeArg(pScope())} --run ${q(A.run)}`)
const lastStore = (text) => jsonObjects(text).length ? JSON.stringify(jsonObjects(text)[jsonObjects(text).length - 1]) : ''
const storeResult = (r) => { try { return JSON.parse(lastStore(r ? r.store_output : '')) } catch (e) { return {} } }
const editRecord = (n) => `Write the JSON verbatim to ${pReceipt(n)} and return it in store_output. Change nothing else.`
const snapTag = async (n, ph, stage) => {
const empty = EMPTY_BASELINE
const r = await work(`${SHELL(snapCmd(tagOf(n), empty))} ${editRecord(n)}`, 'snap:' + n + (empty ? ':empty' : ''), ph, stage, [pReceipt(n)], true)
const j = storeResult(r)
  if (r && storeOk(j)) {
    noteReceipt(n); noteLive(tagOf(n)); noteFile(pReceipt(n), 'tag'); tagDigest[tagOf(n)] = j.digest; knownTags.add(tagOf(n))
  } else stop(stage, { reason: 'snapshot_failed: ' + tagOf(n) })
  return r
}
const enterTag = async (n, ph, stage) => {
  noteReceipt(n)
const r = await work(`${SHELL(beginCmd(tagOf(n), EMPTY_BASELINE ? 'empty' : ''))} ${editRecord(n)} If findings contain draft_changed_since_tag, return done=false with note draft_changed_since_tag and both digests; change no draft file.`, 'enter:' + n, ph, stage, [pReceipt(n)], true)
const j = storeResult(r || lastResult)
const startTag = tagOf(n)
  if (j.findings && j.findings.includes('draft_changed_since_tag')) { noteUnsnap(startTag); stop(stage, { reason: 'draft_changed_since_tag', live_digest: j.live_digest, tag_digest: j.tag_digest, action: 'enter' }); return false }
  if (r && storeOk(j)) {
    noteReceipt(n); noteFile(pReceipt(n), 'tag'); if (j.digest) tagDigest[tagOf(n)] = j.digest; knownTags.add(tagOf(n))
    noteLive(tagOf(n)); return true
  }
  stop(stage, { reason: 'snapshot_failed: ' + tagOf(n) }); return false
}
const restoreTag = async (n, ph, stage, expectedDigest) => {
const t = tagOf(n)
  noteReceipt(n)
const p = await work(`${SHELL(restorePendingCmd(t))} Return the JSON verbatim in store_output; change no file.`, 'restore-pending:' + n, ph, stage, [], true)
const pending = storeResult(p)
const r = await work(`${SHELL(restoreCmd(t, pending.findings && pending.findings.includes('restore_pending') ? '' : expectedDigest))} ${editRecord(n)} Every restore finding is an expected result: type_clash, draft_changed_since_tag, completed_record. Return the JSON verbatim, done=true, and change no draft file. End done=false only on an ok=false store error.`, 'restore:' + n, ph, stage, [pReceipt(n)], true)
const j = storeResult(r), findings = Array.isArray(j.findings) ? j.findings : []
const digests = { start_tag: t, start_digest: j.tag_digest || j.digest || '',
    live_digest: j.live_digest || '', ...(j.tag_digest ? { tag_digest: j.tag_digest } : {}) }
  if (findings.includes('type_clash')) { stop(stage, { reason: 'restore_type_clash', tag: t, restore_tag: t, conflicts: j.conflicts }); return null }
  if (findings.includes('draft_changed_since_tag')) { noteUnsnap(t); stop(stage, { reason: 'draft_changed_since_tag', live_digest: j.live_digest, tag_digest: j.tag_digest, action: 'restore', ...digests }); return null }
const cleaned = findings.every((f) => f === 'completed_record' || String(f).startsWith('completed_record: '))
  if (r && storeOk(j) && cleaned) {
    noteLive(t); noteFile(pReceipt(n), 'tag'); tagDigest[t] = j.digest; knownTags.add(t); return r
  }
  noteUnsnap(t); stop(stage, { reason: 'restore_failed: ' + t, restore_tag: t, findings, errors: j.errors,
    record: pending.record || j.record || '', next: `restore --tag ${t}` }); return null
}
const delta = async (n, ph, stage) => {
const path = F + `/delta-${slug(n)}.json`
const r = await work(`${SHELL(digestCmd())} Write two JSON objects in store_output: the digest JSON and {tag, no_change, pre_digest, post_digest}. Write the second object to ${path}; pre_digest is the digest in ${pReceipt(n)} and post_digest is the digest just computed; set no_change to that comparison. Change nothing else.`, 'delta:' + n, ph, stage, [path], true)
  if (!r) return null
  noteFile(path, 'delta')
const objs = jsonObjects(r.store_output), d = objs.length > 1 ? objs[1] : {}
const pre = d.pre_digest, post = d.post_digest || (objs[0] || {}).digest
  return { ...r, no_change: typeof pre === 'string' && typeof post === 'string' && pre === post }
}
const edit = (n, body, emptyStart = false) => `${SHELL(beginCmd(tagOf(n), emptyStart ? 'empty' : ''))} This is the first command of this call; run the begin command exactly as written, including any --now empty; run it before any write. If findings contain draft_changed_since_tag, return done=false with note draft_changed_since_tag and both digests; change no draft file and write no receipt. Otherwise ${editRecord(n)} If the result has action snapshot or current, continue. Then: ${body}`
const editStep = async (n, body, label, ph, stage) => {
const startTag = tagOf(n)
  noteReceipt(n); knownTags.add(startTag)
const emptyStart = n === 'pre-write' && EMPTY_BASELINE
  if (emptyStart) noteLive(tagOf(n))
const r = await work(edit(n, body, emptyStart), label, ph, stage, [], true, false)
const j = storeResult(r || lastResult)
  if (j.findings && j.findings.includes('draft_changed_since_tag')) {
    noteFile(pReceipt(n), 'tag'); noteUnsnap(startTag)
    stop(stage, { reason: 'draft_changed_since_tag', live_digest: j.live_digest, tag_digest: j.tag_digest, action: 'edit', start_tag: startTag, start_digest: j.tag_digest || '', restore_tag: restorePoint || startTag })
    Object.assign(stopped, { live_digest: j.live_digest, tag_digest: j.tag_digest, start_digest: j.tag_digest || '' })
    return null
  }
const digests = { start_tag: startTag, start_digest: j.tag_digest || '', live_digest: j.live_digest || j.digest || '', ...(j.tag_digest ? { tag_digest: j.tag_digest } : {}) }
  if (r && n === 'pre-write') digests.restore_tag = startTag
const changed = j.findings && j.findings.includes('draft_changed_since_tag')
  if (!r) {
    let d = null; try { d = await agent(`${SHELL(verifyCmd(startTag))} The live draft differs from the tag by construction: return that ok=false JSON verbatim in store_output only, done=true, and change no file.`, opt({ label: 'digests:' + startTag, phase: ph, schema: W, effort: EFFORT })) } catch (e) { log('digests: ' + e) }
const x = storeResult(d), okd = d && typeof x.live_digest === 'string' && typeof x.digest === 'string'
    noteUnsnap(startTag)
    Object.assign(stopped || {}, digests, okd ? { live_digest: x.live_digest, tag_digest: x.digest, start_digest: x.digest } : { live_digest: 'unavailable', tag_digest: 'unavailable', start_digest: 'unavailable', digest_error: d ? reasonOf(d) : 'agent_died' })
  }
  if (!r || stopped) return null
  noteUnsnap(startTag)
  return r
}
const readSet = () => [...new Set([...A.outputs.filter((o) => !A.source_outputs.includes(o)), ...A.output_dirs, ...A.source_outputs])]
const BOUND = {}
const buildRule = (t, buildPath) => `The build record ${buildPath} is fixed by its own digest and deliverable list; recompute both with ${SHELL(recordDigestCmd(buildPath))} and reject any later change to them. Read the build record ${buildPath} for version ${t}. The record lists deliverables: every declared output ${JSON.stringify(A.outputs)}, every source output ${JSON.stringify(A.source_outputs)} and every non-intermediate, non-owned file under the output directories ${JSON.stringify(A.output_dirs)}, rewritten by this build. Read every path in its deliverables list, including extra print versions, then the record itself; skip owned and intermediate paths without reading them. Read the union ${JSON.stringify(readSet())} directly. A readable deliverable that does not exist is NOT_RUN. No check rebuilds.`
const inputCmd = (g) => `python ${q(skillDir + '/draft_store.py')} check-input --paper ${q(A.paper)} --orch ${q(O)} --run ${q(A.run)} --build ${q(slug(g))} --digest <the pre_digest>`
const bpFor = (g) => `${F}/build-${slug(g)}.json`
const vcmdFor = (g) => `${storeCmd(`verify-build --build-file ${safeArg(bpFor(g))} --paths ${A.outputs.map(safeArg).join(' ')} --sources ${A.source_outputs.map(safeArg).join(' ')} --declared ${A.output_dirs.map(safeArg).join(' ')} --intermediates ${A.intermediates.map(safeArg).join(' ')}`)} --run ${q(A.run)} --scope ${safeArg(pScope())} --pre-inventory ${q(preInvPath(g))}`
const buildPrompt = (g) => `Run this build command in ${A.paper} using the contract's shell (${A.shell || 'bash on POSIX, the platform default elsewhere'}): ${A.build}. Run the build once. First run ${SHELL(digestCmd())} and call that digest pre_digest. Before the build command, substitute pre_digest for <the pre_digest> in this command and run it: ${inputCmd(g)}. The first attempt must commit the pre-build inventory with ${SHELL(checkInventoryCmd(g))} before any build command; on a resumed build this command returns the committed inventory and its build start time, which you must reuse. A missing inventory for a started build is done=false with note build_inventory_missing; do not run the build. If it reports input_digest_drift, return done=false with note "input_digest_drift" followed by the recoverable_snapshot tag it names; do not run the build. Then take an inventory: ${SHELL(inventoryCmd())} Keep that JSON as pre_inventory. Run the build command once; builds must be safe to rerun. Immediately after it run the same digest command and take the same inventory again; call the results post_digest and post_inventory. written is every path present in post_inventory and absent from pre_inventory or different in size or sha256; files holds one {path, sha256, mtime} entry for every written path and for every declared output, source output and file under an output directory listed in post_inventory; mtime is the exact st_mtime_ns from the inventory, written as a string of decimal digits. started is the integer epoch nanosecond build start time from the committed pre-build inventory. deliverables is every declared output [${JSON.stringify(A.outputs)}], every source output [${JSON.stringify(A.source_outputs)}], and every non-intermediate, non-owned file under an output directory [${A.output_dirs.join(', ')}] listed in post_inventory, rewritten by this build; every listed non-source deliverable must have a files entry with its live sha256 and exact st_mtime_ns. Every non-source deliverable must have an mtime no older than the newest draft file in the scope. Every source output needs existence and a recorded digest only. Deliverables must be non-empty. An output that is also a source output is checked for existence and digest only. A nonzero exit status, a missing deliverable, a written file that is neither a declared output, a source output, an intermediate nor under an output directory, a record without written and deliverables, or post_digest different from pre_digest is done=false with note "build_failed" or "build_changed_draft" respectively; a draft change stops the run with no replay. Record the changed draft paths in the stop note. Write {returncode, started, pre_digest, post_digest, files:[{path,sha256,mtime}], written:[paths], deliverables:[paths], verified:[declared outputs confirmed current], sources:[source outputs confirmed to exist], digest:post_digest} to ${bpFor(g)} and return it in build_result. Append the build record to ${WORKLOG}.`
const buildStep = async (g, ph, stage) => {
const preBuildTag = tagOf('pre-build-' + g)
  if (!await snapTag('pre-build-' + g, ph, stage)) return null
const r = await agent(buildPrompt(g), opt({ label: 'build:' + g, phase: ph, schema: W, effort: EFFORT }))
  if (!r) { stop(stage, { reason: 'agent_died' }); return null }
const note = (r.notes || []).find((x) => typeof x === 'string' && x.trim()) || ''
  if (note.startsWith('input_digest_drift')) {
const tag = note.split(/\s+/).slice(1).find((x) => x.includes('/')); noteUnsnap(tag || preBuildTag); stop(stage, { reason: note, restore_tag: tag || preBuildTag }); return null }
const rec = (r.build_result || {})
  if (note.startsWith('build_changed_draft') || (typeof rec.pre_digest === 'string' && typeof rec.post_digest === 'string' && rec.pre_digest !== rec.post_digest)) {
    noteUnsnap(preBuildTag)
    stop(stage, { reason: 'build_changed_draft', pre_build_tag: preBuildTag, restore_tag: preBuildTag, changed: (r.notes || []).filter((x) => x !== 'build_changed_draft') })
    return null
  }
  if (r.done !== true || rec.returncode !== 0) { stop(stage, { reason: 'build_failed' }); return null }
  if (!Array.isArray(rec.written) || !Array.isArray(rec.deliverables) || !rec.deliverables.length || !Array.isArray(rec.verified) || !Array.isArray(rec.sources) || typeof rec.pre_digest !== 'string' || typeof rec.post_digest !== 'string') { stop(stage, { reason: 'build_record_incomplete' }); return null }
const vcmd = `${storeCmd(`verify-build --build-file ${safeArg(bpFor(g))} --paths ${A.outputs.map(safeArg).join(' ')} --sources ${A.source_outputs.map(safeArg).join(' ')} --declared ${A.output_dirs.map(safeArg).join(' ')} --intermediates ${A.intermediates.map(safeArg).join(' ')}`)} --run ${q(A.run)} --scope ${safeArg(pScope())} --pre-inventory ${q(preInvPath(g))}`
const v = await work(`${SHELL(vcmd)} Return the JSON verbatim in store_output; change no file. If the JSON has ok=false, return done=false with notes ['store_failed'] and the complete store_output; change no file.`, 'build-verify:' + g, ph, stage, [], true)
const j = storeResult(v)
  if (!v || !j.ok) { stop(stage, { reason: 'build_failed', note: String(j.error || 'build verification failed') }); return null }
const findings = j.findings || []
  if (findings.some((f) => f === 'unlisted_output')) { stop(stage, { reason: 'unlisted_output', unlisted: j.unlisted }); return null }
  if (findings.length) { stop(stage, { reason: 'build_failed', findings }); return null }
const bd = storeResult(await work(`${SHELL(recordDigestCmd(bpFor(g)))} Return the JSON verbatim in store_output; change no file.`, 'build-digest:' + g, ph, stage, [], true))
  if (!bd.ok) { stop(stage, { reason: 'build_record_incomplete' }); return null }
  BOUND[bpFor(g)] = bd
  return r
}
const labelPrompt = (g, checkTag, buildPath) => `Reader label check of ${A.paper} (version ${g}) for tag ${checkTag}. Read ${REF}; apply only its Reader label check section. ${buildRule(checkTag, buildPath)} Read the contract's known internal-code list, the build-origin mapping named in the build record or a build-origin file under ${O}, and ${O}/process.md; when provenance affects a candidate's class and the mapping is missing, return NOT_RUN. Recompute the sha256 of ${O}/process.md against ${F}/contract.sha256; a difference is REJECT with a "contract_changed:" blocker. Read every text layer, including generated and bitmap text; return NOT_RUN for any area you cannot cover. Honour whether outputs form one document or stand alone. Report one entry per token; ACCEPT with empty hits when clear, else REJECT.`
const story = (t, g, buildPath, checkTag, ph = 'Refine', stage = 4) => check(`Storyline review of ${A.paper} (version ${t}). ${buildRule(checkTag, buildPath)} Read ${SLR}; storyline: ${R}/storyline.md. ${storyDesc}; report any difference from ${R}/storyline.md as a blocker. Apply Argument sections when extracting topic sentences. Check conclusion places only where the venue names them and something is pending. Read the body for the outcome branch the contract names and the declared branch sidecar for every other branch; each named place needs one clear version per outcome, and a version acceptable under both outcomes is a break. Check every claim points to substantive evidence the venue uses: a rendered figure, a table, a citation, or an in-text derivation, proof or argument. No evidence form is required by this check. Unreadable storyline skill is NOT_RUN. REJECT any break, unanswered branch or delivery blocker named by the storyline skill. Write the report to the exact path your report rule names and return that path in report; the skill's table belongs in the report, not only in chat.`, 'storyline', t, ph, stage)
const review = (v, g, buildPath, checkTag) => check(`Review the compiled paper (version ${v}) as the reviewer in ${REF}. ${buildRule(checkTag, buildPath)} Write the THOUGHT section and full JSON in the report, with seven sub-axes, Overall, Confidence, decision and verdict.`, 'review', v, 'Refine', 4, REVIEW)
const numberCheck = (t, g, buildPath, checkTag, ph, stage) => check(`Number trace check of ${A.paper} (version ${t}). ${buildRule(checkTag, buildPath)} Open ${R}/experimental_log.md and every rendered document: return NOT_RUN when a reader-visible area cannot be covered. Every research number in an argument (results, statistics, sample sizes, model or method parameters) traces to a log row or a source it names. Page numbers, section and figure numbering, dates and citation numbers are apparatus, not research numbers. ACCEPT when all trace, else REJECT with untraced numbers in blockers.`, 'numbers', t, ph, stage)
const refsCheck = (t, g, buildPath, checkTag, ph, stage) => check(`Citation check (version ${t}). ${buildRule(checkTag, buildPath)} Apply the build conventions: no unresolved reference or citation marker in any output. Citation coverage states how many collected papers must be cited; list shortfalls as blockers. ACCEPT when clear and coverage is met, else REJECT with each marker and location.`, 'refs', t, ph, stage)
const evidence = (t, tag, buildPath) => {
const path=pReport('evidence', t)
const reports = seen.reports.filter((x) => x.path !== path)
  if (!seen.reports.some((x) => x.path === path)) seen.reports.push({ path, verdict: 'NOT_RUN', own: true })
const rows = seen.tags.map((x) => ({ tag: x, receipt: tagReceipt[x] || '', command: x === tag ? verifyCmd(x) : auditCmd(x), signature: x === tag ? 'current' : '' }))
  return check(`Evidence audit. Write this report first. Reports (path, verdict): ${JSON.stringify(reports)}. The report ${path} is yours; judge the verdict you record there. For every other report: it exists, line 1 is "run ${A.run} | check <k> | <tag>" matching its path, line 2 is its recorded verdict, line 3 is "Blockers: <count>" followed by that many blockers (or "none"), and ACCEPT has no blockers. Each tag has a snapshot receipt with a receipt path; the receipt's tag and digest must agree with the command output and with the tag named here, matching its digest in all three ways. Read each receipt, run each command and require ok=true; audit checks snapshot integrity for a historical tag, verify checks the live draft for the current tag ${tag}:\n${rows.map((x) => `- tag ${x.tag}: receipt ${x.receipt || '(none)'}; command ${x.command}${x.signature ? '; signature ' + x.signature : ''}`).join('\n')}\nBuild outputs: run ${SHELL(buildPath ? recordDigestCmd(buildPath) : digestCmd())} and require its digest ${BOUND[buildPath] ? 'to equal ' + BOUND[buildPath].digest + ' and its deliverable set to equal ' + JSON.stringify(BOUND[buildPath].deliverables) : 'for the bound build record'}; any difference is build_output_drift. Read build record ${buildPath || '(none)'} and its exact deliverables list. Recompute the delivery set with ${SHELL(vcmdFor(buildPath ? buildPath.split('/').pop().replace(/^build-/, '').replace(/\.json$/, '') : 'final'))}; it must match the record's deliverable list. Then for each listed deliverable, recompute its sha256 and compare with the matching files entry; recompute size and mtime where the record stores them. Recompute the sha256 of ${O}/process.md against ${F}/contract.sha256 and stop with contract_digest_mismatch on a difference; the contract check cannot be reused from cache. Recompute the digest of tag ${tag} with ${SHELL(digestCmd())} and require it to equal the digest stored in ${pReceipt(tag)}; a difference stops with tag_digest_mismatch. Read the build record's pre_digest and digest and require both to equal the current tag digest; a difference stops with build_input_digest_mismatch. Stop on any difference, a missing deliverable, an added deliverable not listed, or an empty set. No check result cached before this verification may be reused if any deliverable drifted. Run the digest and contract commands but change no draft file. ACCEPT only if all pass, else REJECT with one blocker per failure; prefix every deliverable or record drift blocker with build_output_drift (tag, contract, receipt and input failures are plain blockers).`, 'evidence', t, 'Gates', GATE_STAGE)
}
const materialGuard = async (stage) => {
const r = await work(`Check that all four stage-0 material files exist: ${R}/idea.md, ${R}/experimental_log.md, ${R}/guidelines.md and ${R}/storyline.md. Return their paths in verified and change no file. If any is missing, return done=false with note "stage_0_materials_missing" naming the missing paths.`, 'materials:guard', 'Materials', stage)
  if (!r) { stop(stage, { reason: 'stage_0_materials_missing' }); return false }
  return true
}
const locateSkill = async () => {
  let r = null
  try { r = await agent(`Locate the installed paper-orchestra skill directory. Return its absolute path in changed_files, with no other file changes. It contains reference.md, workflow-template.js and draft_store.py.`, opt({ label: 'skill:locate', phase: 'Materials', schema: W, effort: EFFORT })) } catch (e) { log(`skill:locate: ${e}`) }
  if (!okWork(r, [], false) || typeof r.changed_files[0] !== 'string' || r.changed_files[0] === '~' || r.changed_files[0].startsWith('~/')) { stop('contract', { reason: 'skill_dir unresolved' }); return false }
  skillDir = r.changed_files[0]; return true
}
if (!skillDir && !await locateSkill()) return result('STOPPED')
const REF0 = skillDir + '/reference.md', SKILL0 = skillDir + '/SKILL.md'
REF = REF0
const contractRule = `Return build, shell, outputs, output_dirs, source_outputs, intermediates, draft_files, cutoff, venue, storyline and agents from the contract in every case. Use these exact field names; args fill only gaps. Venue carries introduction (bool), figures (bool) and related_work (bool), defaulting to false when absent. Return only Venue fields the contract writes; leave absent fields out. Storyline has file, section and sentences (the author's sentences written inline, used verbatim); a silent field means it is absent. Agents has effort, fallbacks, max_parallel and reviewer {agentType, model, effort}. Run this step with stages ${JSON.stringify(RAW)}.`
const contractRecord = await work(`First step. Read ${SKILL0} for its knobs and ${REF0} for the contract and store rules. ${contractRule} The Venue and build knob names one build command, the shell to run it in (shell defaults to bash on POSIX and to the platform default elsewhere), its outputs and output directories. If ${O}/process.md exists, first compare its sha256 with the lowercase hex line in ${F}/contract.sha256 when that file exists; a difference changes nothing and returns done=false with the first note beginning "contract_changed". Stages 0-2 alone need no build, outputs or venue flags; stages 3 and 4 need a build command and at least one declared output, source output or output directory, and a missing Draft files include is allowed only as a to-be-created empty baseline. Use this same predicate: outputs or source_outputs or output_dirs. Then write the current hash there as one lowercase hex line, list the Blocker reviews knob keys in contract_reviews, and return the fields. If the file is absent, write it from the caller's rules and notes with the knobs named in SKILL.md, write its hash, list the keys, and then read all fields back from the file you just wrote as for an existing contract. This is the only step that may write the contract.`, 'contract:record', 'Materials', 'contract', [F + '/contract.sha256'])
if (contractRecord) {
  noteFile(F + '/contract.sha256', 'contract')
const note = (contractRecord.notes || []).find((x) => typeof x === 'string' && x.trim())
  if (note && note.startsWith('contract_changed')) stop('contract', { reason: note })
}
const SLR = A.storyline_skill || skillDir + '/../storyline-review/SKILL.md'
const contractReviews = (contractRecord && contractRecord.contract_reviews) || []
if (contractReviews.some((k) => !safeK(k))) stop('contract', { reason: 'contract_review_key_unsafe' })

if (A.review_keys !== undefined && !A.review_keys.every((k) => contractReviews.includes(k) || BKEYS.includes(k))) stop('contract', { reason: 'review_keys_unknown' })
const C = contractRecord || {}, first = (k, fallback) => C[k] !== undefined ? C[k] : fallback
const AGENT = { ...AG, ...(C.agents || {}) }
EFFORT = AGENT.effort; REVIEWER = { ...RV, ...(AGENT.reviewer || {}) }; FALLBACKS = AGENT.fallbacks || FALL; PARALLEL_MAX = Number.isInteger(AGENT.max_parallel) && AGENT.max_parallel > 0 ? AGENT.max_parallel : 3
A.build = first('build', A.build)
A.shell = first('shell', A.shell || '')
if (DRAFT && (typeof A.build !== 'string' || !A.build.trim())) stop(ST.has('4') ? 4 : 3, { reason: 'contract_build_missing' })
const hasOutputs = (x) => Array.isArray(x) && x.length > 0
const arr = (k) => Array.isArray(first(k, A[k] || [])) ? first(k, A[k] || []) : []
const clean = (p) => norm(p).replace(/^\.\/+/, '')
A.outputs = arr('outputs').map(clean); A.output_dirs = arr('output_dirs').map(clean)
A.source_outputs = arr('source_outputs').map(clean); A.intermediates = arr('intermediates').map(clean)
A.draft_files = arr('draft_files').map(clean)
if (!stopped) {
const toResolve = [...A.outputs, ...A.source_outputs, ...A.output_dirs, ...A.intermediates, ...A.draft_files]
const r = await work(`${SHELL(resolveCmd([...new Set(toResolve)]))} Return the JSON verbatim in store_output. Change no file.`, 'paths:resolve', 'Materials', 'contract', [], true)
const j = (jsonObjects(r ? r.store_output : '').pop() || {})
  if (!r || j.ok !== true) stop('contract', { reason: 'contract_path_resolution_failed' })
  else {
const canon = new Map((j.paths || []).map((x) => [norm(x.input).replace(/^\.\//, ''), x.path]))
const cv = (x) => canon.get(norm(x).replace(/^\.\//, '')) || x
    A.outputs = A.outputs.map(cv); A.source_outputs = A.source_outputs.map(cv)
    A.output_dirs = A.output_dirs.map(cv); A.intermediates = A.intermediates.map(cv)
    A.draft_files = A.draft_files.map(cv)
  }
}
for (const k of ['outputs','source_outputs','output_dirs','intermediates','draft_files'])
  if (!A[k].every((x) => literalPath(x))) stop(3, { reason: 'contract_path_not_literal: ' + k })
if (!stopped && DRAFT && A.output_dirs.includes('.')) stop('contract', { reason: 'output_dir_overlaps_draft', blocker: 'the paper root cannot be an output dir' })
if (!stopped && DRAFT && A.output_dirs.some((d) => A.draft_files.some((f) => f === d || f.startsWith(d.replace(/\/$/, '') + '/') || d.startsWith(f.replace(/\/$/, '') + '/')))) stop('contract', { reason: 'output_dir_overlaps_draft', blocker: 'an output dir overlaps a declared Draft file' })
if (DRAFT && !stopped && ![A.outputs, A.source_outputs, A.output_dirs].some(hasOutputs)) stop('contract', { reason: 'contract_outputs_missing' })
const VENUE = { ...(A.venue || {}), ...(C.venue || {}) }
const storySpec = first('storyline', A.storyline || {}) || {}
const storyDesc = (Array.isArray(storySpec.sentences) && storySpec.sentences.length)
  ? `Use these author sentences verbatim: ${JSON.stringify(storySpec.sentences)}`
  : storySpec.file ? `Use the Storyline file ${storySpec.file}, section ${storySpec.section || ''}`
  : (typeof storySpec === 'string' && storySpec ? `Copy the author sentences verbatim from ${storySpec}` : 'Use inferred sentences')
const V = VENUE || {}
const HAS_INTRO = V.introduction === true, HAS_FIG = V.figures === true, HAS_REL = V.related_work === true
const SECTIONS = [HAS_INTRO ? 'introduction.md' : '', HAS_REL ? 'related-work.md' : ''].filter(Boolean)
const sFiles = SECTIONS.map((x) => `${D}/${x}`)
const CUTOFF = first('cutoff', A.cutoff || '')
const reviewKeys = [...new Set([...(A.review_keys || []), ...contractReviews])]; out.review_keys = reviewKeys
const dispatched = [...new Set([...reviewKeys.filter((k) => k !== 'evidence'), ...BKEYS.filter((k) => k !== 'evidence')])]
let GATE_STAGE = 4
const checkFor = (k, g, buildPath, checkTag) => BUILTIN_K.includes(k) ? ({
  labels: () => check(labelPrompt(g, checkTag, buildPath), 'labels', g, 'Gates', GATE_STAGE),
  storyline: () => story(g, g, buildPath, checkTag, 'Gates', GATE_STAGE),
  numbers: () => numberCheck(g, g, buildPath, checkTag, 'Gates', GATE_STAGE),
  refs: () => refsCheck(g, g, buildPath, checkTag, 'Gates', GATE_STAGE),
  language: () => check(`Language rules check (version ${g}, tag ${checkTag}). ${buildRule(checkTag, buildPath)} Apply the contract's Language rules knob to every rendered output. Each boundary it names is a blocker. ACCEPT when no boundary is crossed, otherwise REJECT with each location in blockers.`, 'language', g, 'Gates', GATE_STAGE),
  contract: () => check(`Contract integrity (version ${g}, tag ${checkTag}). ${buildRule(checkTag, buildPath)} Recompute the sha256 of ${O}/process.md, compare with ${F}/contract.sha256, and read the contract's Blocker reviews knob keys into contract_reviews. ACCEPT when the digests match and the contract's Blocker reviews keys are among the checks [${reviewKeys.join(', ')}] supplied by the contract and built-in reuse; otherwise REJECT with the difference in blockers.`, 'contract', g, 'Gates', GATE_STAGE),
  review: () => review(g, g, buildPath, checkTag),
  materials: () => check(`Materials recheck (version ${g}). Open the four stage-0 material files and confirm they still satisfy their checks.`, 'materials', g, 'Gates', GATE_STAGE),
  outline: () => check(`Outline recheck (version ${g}). Open ${O}/outline.json and confirm every sentence and planned figure is served.`, 'outline', g, 'Gates', GATE_STAGE),
  citations: () => check(`Citations recheck (version ${g}). Confirm every citation hint resolves to a verified key or is recorded as unresolved in ${L}/citation_map.json.`, 'citations', g, 'Gates', GATE_STAGE),
  figures: () => check(`Figure critic recheck (version ${g}). Confirm every planned figure is accepted or carries an open request; an empty plan passes.`, 'figures', g, 'Gates', GATE_STAGE),
})[k]() : check(`Contract blocker review ${k} (version ${g}, tag ${checkTag}). ${buildRule(checkTag, buildPath)} ${(A.blockers || []).find((b) => b.k === k) ? A.blockers.find((b) => b.k === k).prompt : 'Apply the review named by the contract Blocker reviews knob ' + k + '.'} ACCEPT when it passes, else REJECT with findings in blockers.`, k, g, 'Gates', GATE_STAGE)
const gateChecks = (g, buildPath, checkTag) => [...new Set(['contract', 'storyline', 'labels', 'numbers', 'language', 'refs', ...dispatched.filter((k) => k !== 'evidence')])].map((k) => ({ k, report: pReport(k, g), thunk: () => checkFor(k, g, buildPath, checkTag) }))
const finalChecks = async (buildPath0, checkTag0, stage) => {
  let buildPath = buildPath0, checkTag = checkTag0, results = null
  GATE_STAGE = stage
  for (let round = 0; !stopped; round++) {
const g = round ? 'final-r' + round : 'final'
    results = await runChecks(gateChecks(g, buildPath, checkTag))
    if (stopped || results.some((r) => r.verdict === 'NOT_RUN')) break
    if (!results.some((r) => r.verdict !== 'ACCEPT')) break
    if (round === 2) break
const gNew = 'final-r' + (round + 1), gBuildNew = bpFor(gNew)
const cites = results.filter((r) => r.verdict !== 'ACCEPT').map((r) => `${r.k}: ${JSON.stringify(r)}`).join('\n')
const repaired = await editStep('pre-repair-' + (round + 1), `Repair round ${round + 1} on ${A.paper}. Keep every write inside the resolved draft scope. Edit only what these checks cite; add only the content a named failure requires (definition, citation, branch answer, sentence) and run no score loop: ${cites}. The contract is read-only. Do not build here; the workflow runs the build next, then snapshots this version. `, 'repair:' + (round + 1), 'Gates', stage)
    if (!repaired || stopped) break
    if (!await buildStep(gNew, 'Gates', stage)) break
    await snapTag(gNew, 'Gates', stage)
    if (stopped) break
    buildPath = gBuildNew; checkTag = tagOf(gNew)
  }
  if (stopped || !results) return { results: results || [], auditTag: checkTag }
const ev = await evidence('final', checkTag, buildPath)
  if (stopped) return { results, auditTag: checkTag }
  results.push({ k: 'evidence', verdict: ev.verdict, report: ev.report, blockers: ev.blockers, open_items: [] })
const drift = (ev.blockers || []).filter((b) => String(b).startsWith('build_output_drift'))
  if (drift.length) stop(stage, { reason: 'build_output_drift', blocker: drift[0] })
  return { results, auditTag: checkTag }
}
const runGate = async (buildPath, checkTag, stage) => {
  phase('Gates')
const { results, auditTag } = await finalChecks(buildPath, checkTag, stage)
  out.blockers = results.map(({ k, verdict, report, blockers, hits, open_items }) => ({ k, verdict, ...(report ? { report } : {}), ...(hits && hits.length ? { hits } : {}), blockers: blockers || [], open_items: open_items || [] }))
  if (stopped) return result('STOPPED')
const open=results.filter((r) => r.verdict !== 'ACCEPT' || rejected(r))
  if (!open.length) acceptedTag = auditTag
  return result(open.length ? 'FAIL' : 'PASS', { remaining: open.map((r) => ({ k: r.k, verdict: r.verdict, blockers: r.blockers || [], open_items: r.open_items || [] })), ...finalState() })
}
const resolveScope = async () => {
const r = await work(`Resolve the draft scope once. Read ${O}/process.md: the contract's Draft files knob names the include paths; otherwise use ${A.draft_files && A.draft_files.length ? JSON.stringify(A.draft_files) : '["."]'}. A named Draft file may be absent here only when the paper has no draft files yet; author notes are not draft files. Return in verified a JSON object {"empty_baseline":true|false} where true only when the scope resolves to no draft file, including a default include holding only excluded author notes; when true, name every path to be created in the receipt's to_create list; when true, also take an explicit empty baseline with ${SHELL(storeCmd(`snap --scope ${safeArg(pScope())} --tag ${q(tagOf('pre-write'))} --now empty`))} The store JSON belongs in store_output: the empty-baseline receipt when true, otherwise run ${SHELL(digestCmd())} and return that digest JSON as the scope receipt. The exclude list holds ${JSON.stringify([...new Set([...A.outputs.filter((o) => !A.source_outputs.includes(o)), ...A.output_dirs.filter((d) => d !== '.' && !A.source_outputs.some((s) => s.startsWith(d.replace(/\/$/, '') + '/'))), ...(A.output_dirs.includes('.') ? [...A.outputs, ...A.intermediates].filter((x) => !A.source_outputs.includes(x)) : []), ...A.intermediates.filter((x) => !A.source_outputs.includes(x)), OREL + '/refine'])])}. A source_output under an output directory other than '.' or outside the draft scope is a contract error: return done=false with note "source_output_conflict". Every path is literal; a path containing *, ? or [ is an error; list any absent include and keep it only for an empty-draft baseline. Writes stay inside the resolved scope: a new draft file must lie under an included directory or be named in the empty-baseline receipt's to_create list. An empty result is allowed only for this empty baseline: create the scope, then snapshot and confirm the snapshot holds zero files. A scope that resolves to no files is an error otherwise. The store always protects the actual orchestra directory ${q(O)} and the fixed snapshot root <paper>/orchestra/snapshots from the draft scope, whatever the contract's orch; state the actual orch in the scope as "orch". The build inventory lists every readable non-owned file under the paper except that snapshot root and this run's records. owned lists every Ownership path (an empty list when the knob names none), and owned paths stay excluded even when the contract names Draft files. Write ${pScope()} as {"include":[...],"exclude":[...],"owned":[...],"orch":...} with paths relative to ${A.paper} and forward slashes, then return the scope object in scope and the store JSON in store_output. Change no other file.`, 'scope:set', 'Materials', 'contract', [pScope()], true)
  let parsed = {}
  try { parsed = JSON.parse(r ? r.store_output : '') } catch (e) { parsed = {} }
  let flag = false
  try { flag = JSON.parse((r.verified || []).find((x) => typeof x === 'string' && x.trim().startsWith('{"empty_baseline"')) || '{}').empty_baseline === true } catch (e) { flag = false }
  EMPTY_BASELINE = flag
  if (!r || !okScope(r) || (flag && !storeOk(parsed))) { stop('contract', { reason: 'draft scope unresolved' }); return }
  noteFile(pScope(), 'scope')
}
if (!stopped && DRAFT) await resolveScope()
if (!stopped && ST.has('0')) {
  phase('Materials')
const storyText = (Array.isArray(storySpec.sentences) && storySpec.sentences.length) ? `copy these author sentences verbatim, one per line, never INFERRED: ${JSON.stringify(storySpec.sentences)}` : storySpec.file ? `Copy the numbered sentences from ${storySpec.file}, section ${storySpec.section || ''}, never INFERRED` : (typeof storySpec === 'string' && storySpec ? `copied verbatim from ${storySpec}` : 'drafted from the abstract or notes, 3-5 sentences, marked INFERRED')
  out.materials = await pairRun(
    () => work(`Stage 0a. Write ${R}/idea.md (question, contributions, theory, equations, claims), ${R}/guidelines.md (venue sections, budgets, front matter) and ${R}/storyline.md (numbered sentences, ${storyText}; then every pending result with outcome branches) from the draft or notes in ${A.paper}. Every claim maps to an idea.md item and a storyline sentence or a side branch.`, 'materials:idea', 'Materials', 0, [R + '/idea.md', R + '/guidelines.md', R + '/storyline.md']),
    () => work(`Stage 0b. Write ${R}/experimental_log.md: every research number the paper may print (results, statistics, sample sizes and model or method parameters), one row each with value, unit, meaning and source path:line; unknown values use contract placeholders. Page numbers, section and figure numbering, dates and citation numbers are layout or reference apparatus, not research numbers. A paper printing no research numbers records one row saying so. Every research number in the draft or notes has a row or an Orphans entry.`, 'materials:log', 'Materials', 0, [R + '/experimental_log.md']),
  )
  if (!stopped) {
const m=await check(`Materials check. Open ${R}/idea.md, ${R}/guidelines.md, ${R}/storyline.md and ${R}/experimental_log.md: check the question, contributions, venue, numbered sentences (or INFERRED), whether they match ${storyDesc}, sentence by sentence when sentences are given, every pending branch and the log rows; a "no printed numbers" row passes when the materials state none. ACCEPT when all hold, else REJECT with findings in blockers.`, 'materials', '0', 'Materials', 0)
    out.materials_check = m
    if (m.verdict === 'NOT_RUN') stop(0, { reason: notRunReason('materials', m) })
    else if (m.verdict !== 'ACCEPT') stop(0, { reason: 'materials_rejected', blocker: m.blockers[0], blockers: m.blockers, out: { materials_check: m } })
  }
}
if (!stopped && ST.has('1')) {
  phase('Outline')
  await work(`Stage 1. Write ${O}/outline.json per ${REF}, synthesizing ${R} and any draft. Every subsection and figure has serves naming storyline sentences; plotting_plan may be empty. Every storyline sentence is served, every needed figure planned, and every dataset, method, statistic, model, instrument and package has a citation_hints entry.`, 'outline', 'Outline', 1, [O + '/outline.json'])
  if (!stopped) {
const m=await check(`Outline check. Open ${O}/outline.json${ST.has('0') ? ' and ' + R + '/storyline.md' : ''}: confirm the three upstream keys${ST.has('0') ? ', storyline' : ''}; every figure_id, title, plot_type, data_source, aspect_ratio, objective and serves; every subsection_title, content_bullets, citation_hints and serves; and citation_hints for every material item. ACCEPT when all hold, else REJECT with findings in blockers.`, 'outline', '1', 'Outline', 1)
    out.outline_check = m
    if (m.verdict === 'NOT_RUN') stop(1, { reason: notRunReason('outline', m) })
    else if (m.verdict !== 'ACCEPT') stop(1, { reason: 'outline_rejected', blocker: m.blockers[0], blockers: m.blockers, out: { outline_check: m } })
  }
}
if (!stopped && (S2A || S2B)) {
  if ((S2A || S2B) && !ST.has('1')) {
const guard = await work(`Check that ${O}/outline.json exists and parses before literature search. Return its path in verified and change no file. If it is missing, return done=false with note "outline_missing".`, 'outline:guard', 'Lit+Fig', '2a')
    if (!guard) stop('2a', { reason: 'outline_missing' })
  }
}
if (!stopped && (S2A || S2B)) {
  phase('Lit+Fig')
  let plan = null
  if (!stopped && S2A) {
const pr = await work(`Read ${O}/outline.json after stage 1. Return in notes a single JSON object with keys search (true when intro_related_work_plan has a query or section_plan has citation_hints), plan (the exact JSON you read), empty_map (true when search is false). Change no file.`, 'lit:plan', 'Lit+Fig', '2a')
    if (!pr) stop('2a', { reason: 'outline_missing' })
    else {
      try { plan = JSON.parse((pr.notes || []).find((x) => typeof x === 'string' && x.trim().startsWith('{')) || '{}') } catch (e) { plan = {} }
      if (plan.search && (typeof CUTOFF !== 'string' || !CUTOFF.trim())) stop('2a', { reason: 'cutoff_missing' })
    }
  }
  if (!stopped && S2A && !plan.search) {
const er = await work(`No outline query exists. Write ${L}/citation_map.json as {} and ${L}/search-log.md as "No hints or queries." and return both paths in changed_files. Change nothing else.`, 'lit:empty', 'Lit+Fig', '2a', [L + '/citation_map.json', L + '/search-log.md'])
    if (er) { noteFile(L + '/citation_map.json', 'citation'); noteFile(L + '/search-log.md', 'log') }
  }
const [lit, fig] = await pairRun(
    async () => {
      if (!S2A || stopped || !plan.search) return null
const found=await work(`Stage 2a search. Run every query in ${O}/outline.json with web and literature tools; send queries only. Verify candidates by exact title, year and the identifier the contract's index uses; drop unverifiable or post-${CUTOFF} work; keep existing bib keys. Write ${L}/citation_map.json, ${L}/search-log.md and, when the build reads BibTeX, ${L}/refs-verified.bib. Every citation_hints entry resolves or is listed unresolved.`, 'lit:search', 'Lit+Fig', '2a', [L + '/citation_map.json', L + '/search-log.md'])
      if (stopped) return { found }
      return { found }
    },
    () => !S2B ? null : work(`Stage 2b. Open ${O}/outline.json. When plotting_plan is empty, write ${O}/figure-critique.md saying the plan is empty and return. Otherwise critique each planned figure against its objective and source data for up to 3 rounds${HAS_FIG ? `, regenerate project-owned figures into ${D}/figures/ and request others` : `; the contract forbids figures, so report the conflict for every plan entry and create no figure`}. Write ${O}/figure-critique.md.`, 'figures', 'Lit+Fig', '2b', [O + '/figure-critique.md']),
  )
  if (!stopped && S2A && SECTIONS.length) {
const intro = await work(`Stage 2a write. Write ${HAS_INTRO ? `the Introduction into ${D}/introduction.md` : ''}${HAS_INTRO && HAS_REL ? ' and ' : ''}${HAS_REL ? `the Related Work into ${D}/related-work.md` : ''} from the outline plan, citing only ${L}/citation_map.json keys. Do not edit the live draft.`, 'lit:write', 'Lit+Fig', '2a', sFiles)
    if (lit) lit.intro = intro
  }
  out.lit = lit; out.fig = fig
  if (!stopped && S2A) {
const c=await check(`Citations check. Open ${L}/citation_map.json, ${SECTIONS.length ? sFiles.join(' and ') + ' and ' : ''}${O}/outline.json: every hint resolves to a verified key using the index's identifier rule or is unresolved${SECTIONS.length ? ', and the drafted section cites only map keys' : ''}. ACCEPT when all hold, else REJECT with findings in blockers.`, 'citations', '2a', 'Lit+Fig', '2a')
    out.citations_check = c
    if (c.verdict === 'NOT_RUN') stop('2a', { reason: notRunReason('citations', c) })
    else if (c.verdict !== 'ACCEPT') stop('2a', { reason: 'citations_rejected', blocker: c.blockers[0], blockers: c.blockers, out: { citations_check: c } })
  }
  if (!stopped && S2B) {
const c=await check(`Figure check. Open ${O}/figure-critique.md and the plotting_plan in ${O}/outline.json: an empty plan passes; otherwise every entry is accepted or carries an open request, and a contract forbidding figures conflicts with a non-empty plan. ACCEPT when all hold, else REJECT with findings in blockers.`, 'figures', '2b', 'Lit+Fig', '2b')
    out.figures_check = c
    if (c.verdict === 'NOT_RUN') stop('2b', { reason: notRunReason('figures', c) })
    else if (c.verdict !== 'ACCEPT') stop('2b', { reason: 'figures_rejected', blocker: c.blockers[0], blockers: c.blockers, out: { figures_check: c } })
  }
}
if (!stopped && ST.has('3')) {
  if (!await materialGuard(3)) return result('STOPPED')
  if (!stopped) {
const guard = await work(`Check that ${O}/outline.json exists and parses before stage 3. Then check the stage 2 products this draft needs: ${L}/citation_map.json, ${L}/search-log.md and ${O}/figure-critique.md. A product is needed only when the outline lists at least one entry for it: the citation map and search log for a non-empty citation_hints or query list, the figure critique for a non-empty plotting plan or figure list. An empty list or an absent key means not needed; then change no file. Related Work is ${V.related_work === true ? 'requested' : 'not requested'}; without it, empty citation hints do not need literature products. Return existing paths in verified. If a needed product is missing, return done=false with note "stage_2_outputs_missing" naming it; if the outline is missing, note "outline_missing".`, 'outline:guard', 'Write', 3)
    if (!guard) stop(3, { reason: (lastResult && Array.isArray(lastResult.notes) && lastResult.notes.some((x) => String(x).startsWith('stage_2_outputs_missing'))) ? 'stage_2_outputs_missing' : 'outline_missing' })
  }
  if (stopped) return result('STOPPED')
  phase('Write')
const wrote=await editStep('pre-write', `This is an editing step; keep every write inside the resolved draft scope and change Draft files here only. Stage 3. Write or revise all sections from ${O}/outline.json, ${SECTIONS.length ? 'merge ' + sFiles.map((f) => (f.endsWith('/introduction.md') ? 'the Introduction ' : 'the Related Work ') + f).join(' and ') + ' and ' : ''}${HAS_FIG ? D + '/figures/ and ' : ''}wire the citation source the build uses (a bibliography file only when the build uses one) so cited keys resolve. Numbers only from ${R}/experimental_log.md; cite only citation_map keys;${HAS_FIG ? ' place and cite every figure;' : ''} the first sentence of each paragraph in the contract's Argument sections carries the claim of the storyline sentence it serves. Where a named section draft is absent, create it from ${O}/outline.json. Resolve every pending branch from ${R}/storyline.md with the definite version for the outcome branch the contract names in the body, and put each other branch's title, abstract and concluding sentences in one declared branch sidecar named by the contract. Read the sidecar only when the contract names it. Do not build here; the workflow runs the build next. Completion: every printed research number traces to a log row, and every storyline sentence is carried.`, 'write', 'Write', 3)
  if (!wrote) stop(3, { reason: 'write_failed' })
  else if (await buildStep('write', 'Write', 3)) await snapTag('write', 'Write', 3)
  if (!stopped) {
const scan=await check(labelPrompt('write', tagOf('write'), bpFor('write')), 'labels', 'write', 'Write', 3)
    out.write_label = scan
    if (scan.verdict === 'NOT_RUN') stop(3, { reason: notRunReason('labels', scan) })
    else if (scan.verdict !== 'ACCEPT') stop(3, { reason: scan.agent_died ? 'agent_died' : scan.blockers && scan.blockers[0] || 'labels_rejected' })
  }
  if (wrote && !stopped) {
const d3 = await delta('pre-write', 'Write', 3)
    if (d3) out.stage3_delta = { no_change: d3.no_change === true }
  }
  if (!stopped && !ST.has('4')) return await runGate(bpFor('write'), tagOf('write'), 3)
}
if (!stopped && ST.has('4')) {
  if (!await materialGuard(4)) return result('STOPPED')
  phase('Refine')
  if (!ST.has('3')) {
    if (!stopped && !(await enterTag('pre-v0', 'Refine', 4))) stop(4, { reason: 'snapshot_failed: pre-v0' })
    if (!stopped) await buildStep('v0', 'Refine', 4)
    if (!stopped) await snapTag('v0', 'Refine', 4)
  }
  let cur = null, st0 = null, firstVersion = null
  if (!stopped) {
    firstVersion = ST.has('3') ? 'write' : 'v0'
const firstBuild = bpFor(firstVersion)
const pair=[() => review(firstVersion, firstVersion, firstBuild, tagOf(firstVersion)), () => story(firstVersion, firstVersion, firstBuild, tagOf(firstVersion))]
const firstPair = PARALLEL_MAX >= 2 ? await parallel(pair.slice(0, PARALLEL_MAX)) : []
    if (PARALLEL_MAX < 2) for (const th of pair) { if (stopped) break;
const v = await th(); firstPair.push(v) }
    while (firstPair.length < 2) firstPair.push(null)
    cur=firstPair[0]; st0=firstPair[1]
const nr = [cur, st0].find((x) => x && x.verdict === 'NOT_RUN')
    if (nr) { currentTag = tagOf(firstVersion); stop(4, { reason: notRunReason(nr.k || (nr === cur ? 'review' : 'storyline'), nr) }) }
    else if (!cur || !st0) stop(4, { reason: 'agent_died' })
    else if (rejected(cur)) stop(4, { reason: 'review_rejected', blocker: (cur.blockers || [])[0], out: { review: cur, storyline: st0 } })
    else if (rejected(st0)) stop(4, { reason: 'storyline_rejected', blocker: (st0.blockers || [])[0], out: { review: cur, storyline: st0 } })
    else revertTag = tagOf(firstVersion)
  }
const score=(r, k)=>Number(r.scores[k]), log4=[]
const firstBase = ST.has('3') ? 'write' : 'v0'
  for (let i=1; !stopped && i <= 3 && cur; i++) {
const base = i === 1 ? firstBase : 'v' + (i - 1), tag='v' + i
const plan=(cur.blockers || []).map((w) => `Fix: ${w}`).concat(i === 1 && st0 ? (st0.blockers || []).map((b) => `Repair storyline: ${b}`) : [])
const scored=await editStep(base, `Stage 4 round ${i}. Keep every write inside the resolved draft scope. Revise per ${REF}: ${JSON.stringify(cur)}. Plan: ${JSON.stringify(plan)}. Do not build here; the workflow runs the build next, then snapshots this version. `, 'revise:v' + i, 'Refine', 4)
    if (!scored || stopped) break
    if (!await buildStep(tag, 'Refine', 4)) break
    await snapTag(tag, 'Refine', 4)
    if (stopped) break
const dR=await delta(base, 'Refine', 4)
    if (!dR) break
    if (dR.no_change === true) {
      await work(logRound('v' + i, `plan ${JSON.stringify(plan)}, outcome NO_CHANGE and no scores`), 'worklog:v' + i, 'Refine', 4, [WORKLOG])
      log(`refine v${i}: NO_CHANGE`)
      break
    }
const nxt=await review(tag, tag, bpFor(tag), tagOf(tag))
    if (!nxt || nxt.agent_died || stopped) { stop(4, { reason: 'agent_died' }); break }
    if (nxt.verdict === 'NOT_RUN') { stop(4, { reason: notRunReason('review', nxt) }); break }
    if (!nxt.scores || !SKEYS.every((k) => inScore(nxt.scores[k], k))) { stop(4, { reason: notRunReason('review', nxt) }); break }
const d=AX.map((k) => score(nxt, k) - score(cur, k)), gain=d.filter((x) => x > 0).reduce((a,b)=>a+b,0), drop=-d.filter((x) => x < 0).reduce((a,b)=>a+b,0)
const accepted=score(nxt, 'Overall') > score(cur, 'Overall') || (score(nxt, 'Overall') === score(cur, 'Overall') && gain >= drop)
const outcome=accepted && !rejected(nxt) ? 'ACCEPT' : 'REVERT'
    log4.push({ round: i, plan, scores_before: cur.scores, scores_after: nxt.scores, deltas: d, gain, drop, outcome })
    if (outcome === 'ACCEPT') {
      await work(logRound('v' + i, `plan ${JSON.stringify(plan)}, scores before ${JSON.stringify(cur.scores)}, scores after ${JSON.stringify(nxt.scores)}, deltas ${JSON.stringify(d)}, gain ${gain}, drop ${drop}, outcome ${outcome}`), 'worklog:v' + i, 'Refine', 4, [WORKLOG])
      cur = nxt
      revertTag = tagOf(tag)
    } else {
const rr = await restoreTag(base, 'Refine', 4, tagDigest[tagOf(tag)])
      if (rr && !stopped) await work(logRound('v' + i, `plan ${JSON.stringify(plan)}, scores before ${JSON.stringify(cur.scores)}, scores after ${JSON.stringify(nxt.scores)}, deltas ${JSON.stringify(d)}, gain ${gain}, drop ${drop}, outcome ${outcome}`), 'worklog:v' + i, 'Refine', 4, [WORKLOG])
      break
    }
  }
  out.refine = log4
  if (!stopped) {
const current = revertTag || tagOf(ST.has('3') ? 'write' : 'v0')
    if (current !== tagOf(firstVersion) && !await restoreTag(current.slice(A.run.length + 1), 'Refine', 4, tagDigest[current])) stop(4, { reason: 'restore_failed: ' + current })
    else if (!await buildStep('preview-' + slug(current.split('/').pop()), 'Refine', 4)) stop(4, { reason: 'build_failed' })
    else fmtTag = current
  }
  if (!stopped) await snapTag('accepted', 'Refine', 4)
  if (!stopped) {
const formatted=await editStep('pre-format', `Formatting pass on ${A.paper}: keep every write inside the resolved draft scope; fix rendered layout only (pages or screens), never content. The restored snapshot is ${fmtTag} and its preview build record is ${bpFor('preview-' + slug(fmtTag.split('/').pop()))}; read any layout from that bound preview, not from an older render. Do not build here; the workflow runs the build next, then snapshots this version. `, 'format', 'Refine', 4)
    if (formatted && !stopped) {
const fd=await delta('pre-format', 'Refine', 4)
      if (fd) out.format_delta = { no_change: fd.no_change === true }
    }
    if (!stopped && formatted) {
      if (await buildStep('format', 'Refine', 4)) await snapTag('format', 'Refine', 4)
    }
  }
  if (!stopped) return await runGate(bpFor('format'), tagOf('format'), 4)
}
if (!stopped && !DRAFT) {
const path = pReport('evidence', 'pass')
  if (!seen.reports.some((x) => x.path === path)) seen.reports.push({ path, verdict: 'NOT_RUN', own: true })
const reports = seen.reports.filter((x) => x.path !== path)
const ev = await check(`Evidence report check. Write this report first. Reports (path, verdict): ${JSON.stringify(reports)}. The report ${path} is yours; judge the verdict you record there. For every other report: it exists, line 1 is "run ${A.run} | check <k> | <tag>" matching its path, line 2 is its recorded verdict, line 3 is "Blockers: <count>" followed by that many blockers (or "none"), and ACCEPT has no blockers. No draft tag exists for this run; check only the reports, recompute the sha256 of ${O}/process.md against ${F}/contract.sha256 and REJECT with contract_digest_mismatch on a difference, and change no file.`, 'evidence', 'pass', 'Gates', LAST_STAGE_V)
  out.run_evidence = ev
  if (ev.verdict === 'NOT_RUN') return result('STOPPED', { reason: notRunReason('evidence', ev), stage: LAST_STAGE_V, remaining: [{ k: 'evidence', verdict: ev.verdict, blockers: ev.blockers, open_items: [] }] })
  if (ev.verdict !== 'ACCEPT') return result(stopped ? 'STOPPED' : 'FAIL', { remaining: [{ k: 'evidence', verdict: ev.verdict, blockers: ev.blockers, open_items: [] }], ...(stopped ? { stage: stopped.stage } : {}), ...finalState() })
}
return result(stopped ? 'STOPPED' : 'STAGE_PASS', { ...(stopped ? { stage: stopped.stage, reason: stopped.reason } : {}), ...finalState() })
