---
name: orchestrator-v2-lite
description: 主会话保留裁决权的轻量闭环：每轮一个 Workflow（修复含真实路径彩排 → 单 reviewer 闭环核查 → 放行候选才终审），阻断由主会话对照代码裁决。用户输入 /orchestrator-v2-lite 时使用。
disable-model-invocation: true
---

# orchestrator-v2-lite

orchestrator-v2 的骨架（单 reviewer、只有阻断消耗轮次、diff 审查、全新会话），但**裁决权不下放**：reviewer 和终审只给发现，哪些算阻断由主会话对照代码决定。不设 reviewer B，不做双盲，不每轮从零全面搜。

适合：已有 spec 或上一轮裁决清单，要把一批具体问题修到可放行（生产运行、发布、合并）。从零的新功能先走 v2 的 grill → spec → tickets，再用本 skill 收口。

## 项目合同（knob）

开工前读项目合同：项目 `CLAUDE.md` 指向的文件，或 `.claude/orchestrator-v2-lite.md`。缺项用默认值，并在首轮汇报里写明用了默认值。

| knob | 含义 | 默认 |
|---|---|---|
| `SPEC` | 追加裁决记录的文件 | 项目现有的 spec / 计划文件；没有则新建 `<任务>-spec.md` |
| `IMPL` | 实现 agent 的 model / effort | 省略 model，effort max |
| `REVIEWER` | 闭环核查的 model / effort / agentType | 比实现高一档，effort xhigh |
| `GATE` | 终审 model | 与 reviewer 不同家族的模型 |
| `BLOCKER` | 阻断定义 | 结果出错、记录损坏、数据泄露、过了不可逆提交点后崩溃 |
| `COMMIT_POINT` | 不可逆/高成本提交点（预约、发布、写账本） | 无则视为"交付" |
| `REHEARSAL` | 真实入口路径的彩排方式 | 按发布/启动命令原样在隔离副本上跑 |
| `TESTS` | 分档测试：focused / release | focused = 改动相关文件；release = 全量 |

非代码项目照同一结构填 knob：论文的 `REHEARSAL` 是全文编译加按审稿路径通读，`TESTS` 是引用/数字核对；`COMMIT_POINT` 是投稿或冻结。
| `RULES` | 写进每份任务书的硬约束 | 无 |

## 每轮

每轮是**一个** Workflow，三段串行（没有 Workflow 工具时，用 Agent 依次派三个 agent，顺序和任务书不变）：

1. **Fix**（`IMPL`）。任务书逐条列本轮已裁决阻断，每条带复现与期望行为，外加"范围外（待办，勿修）"清单和 `RULES`。实现 agent 一次修完整批：
   - 只跑 focused 测试，给每个阻断补一个能复现原故障的测试。
   - 收尾做 `REHEARSAL`：入口、配置、进程模型都走生产路径，只在最底层外部依赖（硬件探针、网络）换假；注入测试替身或走 smoke 分支的不算彩排。
   - 提交并回报：提交号、逐条改动 `file:line` 与测试名、测试计数、彩排输出、清理确认。
2. **Check**（`REVIEWER`，全新会话，schema `{verdict: ACCEPT|REJECT, blockers, backlog}`）。只审 `上轮提交..HEAD`：
   - 逐条复现原阻断，确认已关闭；
   - 改动行回归：是否触犯 `BLOCKER`；
   - 复用实现者的测试计数，只重跑存疑的。
   - 不做全范围搜索。
3. **Gate**（`GATE`，仅当 Check 为 ACCEPT 且本轮是放行候选）。全新会话，任务书不带我方结论，只列"之前发现并声称已修，请核实"。从入口到提交点端到端走一遍，只报 `BLOCKER`。已知待办写进任务书，注明"除非给出本次运行的具体失败，否则不重提"。

Workflow 返回后，主会话：

- **裁决**每条阻断：打开引用的代码行确认。成立的进下轮；防御性的（威胁不现实、合规调用不会触发、超出本轮范围）、发生在 `COMMIT_POINT` 之前的失败（不耗成本，执行时自然暴露）、纯呈现问题，一律降入待办。
- **记录**：向 `SPEC` 追加一节：轮次、提交、测试计数、每条阻断"接受 / 降级 + 理由"、待办、下一轮 run id。
- **体检**：确认没有残留进程、临时目录、多出来的 worktree 配置。
- **汇报**用户：1–3 段，写结论和下一步，不要求用户确认。

## 完成

Check 为 ACCEPT、Gate 为 GO（或 Gate 的阻断全部被裁为待办），并且主会话亲自读过放行路径的关键代码、跑过一次 release 档测试或彩排，才算可放行。此后执行提交点动作（启动、发布），把结果记入 `SPEC`。

## 规则

- 每轮只派一个 reviewer。轮次多是因为问题串行暴露，治法是在 Fix 阶段做 `REHEARSAL`，不是加审查员。
- 终审每个放行候选只跑一次；它的阻断按上面的裁决流程进入下一轮。
- 运行中的 workflow agent 不发消息；失败只补跑失败的那个 agent。
- 每份任务书都写明：只给本任务启动的进程发信号；不使用 SendMessage / ListAgents；临时文件的位置和收尾删除；git 身份。
- release 档长测试只在放行前、且改过共享代码时跑。

## Workflow 骨架

```js
export const meta = { name: '<task>-round-N', description: '<one line>',
  phases: [{ title: 'Fix' }, { title: 'Check' }, { title: 'Gate' }] }
const S = ok => ({ type: 'object', properties: { verdict: { type: 'string', enum: ok },
  blockers: { type: 'array', items: { type: 'string' } },
  backlog: { type: 'array', items: { type: 'string' } } }, required: ['verdict', 'blockers', 'backlog'] })
phase('Fix')
const fix = await agent(FIX, { label: 'fix', phase: 'Fix', effort: 'max' })
phase('Check')
const chk = await agent(CHECK(fix), { label: 'check', phase: 'Check', model: REVIEWER_MODEL,
  effort: 'xhigh', agentType: REVIEWER_TYPE, schema: S(['ACCEPT', 'REJECT']) })
if (!chk || chk.verdict !== 'ACCEPT' || !RELEASE_CANDIDATE) return { fix, chk, gate: null }
phase('Gate')
const gate = await agent(GATE_BRIEF(fix), { label: 'gate', phase: 'Gate', model: GATE_MODEL,
  effort: 'xhigh', schema: S(['GO', 'NO_GO']) })
return { fix, chk, gate }
```
