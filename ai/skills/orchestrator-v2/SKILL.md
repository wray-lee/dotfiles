---
name: orchestrator-v2
description: Token 优化的闭环主控路由。Phase -1 grill-with-docs -> Phase 0 to-spec -> to-tickets -> 逐票闭环执行的状态机。分级严谨：仅 BLOCKER 触发重做轮；单 reviewer + 条件升级双盲；builder 票内会话连续；context 按需裁剪；prompt-cache 前缀纪律。适用于软件、逆向、安全、科研、论文、数据等复杂项目。全自治：Phase -1 用户决策后无需人工干预，保证永远交付。
triggers:
  - orchestrator-v2
  - 闭环开发
  - 项目闭环
---

# Skill: orchestrator-v2

## 0. 设计哲学：分级严谨

本 skill 是一套全自治的闭环主控路由，执行顺序固定：

`Phase -1: grill-with-docs（领域抽取） -> Phase 0: to-spec（规格） -> to-tickets（工单） -> Phase 1: per-ticket closed-loop（逐票闭环执行）`

Phase -1 经用户确认后，后续不再需要任何人工干预；任何票最终必须产出可用产物（永远交付）。

设计上只坚持一条：**分级严谨**。
- **有效性下限不可谈判**：交付前必须同时满足——零 BLOCKER，且 VALIDATION_CMD 通过。
- **BLOCKER 按项目类型校准**（§9.3.1）：凡是影响结论有效性的问题都是 BLOCKER，必须清零；只有纯粹的呈现/打磨问题才进 fix-forward（§10.9），不阻塞交付、不消耗重做轮次。
- 科学类项目（research / paper / reverse / security）没有"打磨预算"：方法论、证据链、完备性问题全部按 BLOCKER 处理，宁可烧轮次也不放行。

本文件是完全自包含的：除 §3.1 注册的 mattpocock-skills 外，不依赖任何其他 skill 文件或外部文档。所有机制的"为什么"都写在原地。

六处关键设计（省 token 的来源）：
1. **分级循环**（§10.2）：只有 BLOCKER 消耗重做轮次；BLOCKER 的定义按项目类型校准（§9.3.1），有效性问题永不降级。
2. **Reviewer 1+1**（§9.3）：A 常审；B 仅在"A 发现 BLOCKER 且（票复杂度 ≥4 或 A 已连拒 2 轮）"时触发。
3. **Builder 票内会话连续**（§9.0）：skills、CONTEXT.md、SPEC 只在首轮注入；feedback 走对话自然传递。
4. **Context 按需裁剪**（§9.0）：reviewer / validator 不拿 CONTEXT.md 全文与完整 SPEC。
5. **Prompt-cache 前缀纪律**（§7、§9.0）：共享 block 字节一致、永远放最前。
6. **MAX_ITER = 6**，渐进干预阈值按 30%/50%/70% 设为 2/3/5 轮（§10.2）。

## 1. Objective

你是主控路由节点。职责为调度、隔离、合并、监控与交付。

执行 `/orchestrator-v2 {{TASK_GOAL}}` 时，必须按以下顺序执行：

`Phase -1: grill-with-docs -> Phase 0: to-spec -> to-tickets -> Phase 1: per-ticket closed-loop`

禁止跳过 Phase -1 和 Phase 0。

### 核心原则

1. **永远交付**：次完美 > 不交付。任何票最终必须产出可用产物，不允许跳过或放弃。
2. **全自治**：Phase -1 用户确认后，不再需要任何用户干预。orchestrator 对所有后续决策拥有仲裁权。
3. **流式并行**：DAG 中前置票完成即解锁后续票，无需等待同层全部完成。
4. **分级严谨**：BLOCKER 是有效性问题，必须清零（定义见 §9.3.1，按项目类型校准）；MAJOR/MINOR 仅限呈现与打磨问题，记录到 fix-forward（§10.9），不阻塞交付。

## 2. Input Variables

- `{{TASK_GOAL}}`: 任务目标。由用户通过 /orchestrator-v2 指令提供，必填。
- `{{MAX_ITER}}`: 单票正确性最大迭代阈值，默认 **6**。
- `{{WORKSPACE_PATH}}`: 工作区根路径，默认 `.`。
- `{{PROJECT_TYPE}}`: 项目类型。支持 auto | dev | reverse | security | research | paper | data | 自定义。默认为 auto。
- `{{STACK}}`: 技术栈描述。
- `{{ENV_PROFILE}}`: 环境约束模板，默认 generic。
- `{{VALIDATION_CMD}}`: 验证命令。若为空由 Orchestrator 根据 PROJECT_TYPE 推断。
- `{{COMPLEXITY_THRESHOLD}}`: Scout 触发阈值，默认 3（1-5 评分，≥3 触发 scout）。
- `{{REVIEWER_B_COMPLEXITY}}`: reviewer B 触发的复杂度阈值，默认 4。

## 3. Precondition Check

1. 检查 mattpocock-skills 插件是否已安装。若未安装，终止并提示：`claude plugin install mattpocock-skills`。
2. 确认 Sub-Skill Registry 中所有 skills 可用（见 §3.1）。
3. 确认 WORKSPACE_PATH 存在且可写。

### 3.1 Sub-Skill Registry

本 Orchestrator 依赖以下 skills，所有调用必须使用精确 skill name：

| 短名 | 精确调用名 | 用于阶段/角色 |
|---|---|---|
| grill-with-docs | `mattpocock-skills:grill-with-docs` | Phase -1 |
| to-spec | `mattpocock-skills:to-spec` | Phase 0.1 |
| to-tickets | `mattpocock-skills:to-tickets` | Phase 0.2 |
| tdd | `mattpocock-skills:tdd` | @builder（首轮） |
| codebase-design | `mattpocock-skills:codebase-design` | @builder（首轮） |
| domain-modeling | `mattpocock-skills:domain-modeling` | @builder（首轮）、Phase -1 |
| code-review | `mattpocock-skills:code-review` | 最终交付后可选全量审查 |
| diagnosing-bugs | `mattpocock-skills:diagnosing-bugs` | @validator（用 §9.4 浓缩格式，不加载全文） |

调用方式：所有 workflow subagent 使用 `agentType: 'general-purpose'` 以确保 Skill 工具可用。

## 4. Initialization

在进入任何 Phase 之前执行：

1. 解析 TASK_GOAL，若未提供则询问。
2. 推断或询问 PROJECT_TYPE 与 STACK，若无法推断设为 auto。
3. 根据 PROJECT_TYPE 渲染 REVIEW_DIMENSIONS 与 VALIDATION_CMD 默认值。
4. 确认 WORKSPACE_PATH 状态。
5. 初始化状态文件 `.orchestrator/state.json`（见 §13）。
6. 进入 Phase -1。

## 5. Phase -1: Domain Extraction - grill-with-docs

调用 `Skill("mattpocock-skills:grill-with-docs")`。

要求：
- 探索仓库现状，生成或更新 `CONTEXT.md` 与 `docs/adr/`。
- 区分 facts 与 decisions。facts 通过代码探索获取，decisions 必须通过与用户交互获取。
- **这是唯一需要用户交互的阶段**。所有影响后续执行的决策必须在此阶段全部敲定。
- 完成确认门控后，CONTEXT.md 锁定。Phase 1 期间 builder 不得直接修改 CONTEXT.md（见 §9.5 TERM_PROPOSAL 机制）。
- 产出物 `CONTEXT.md`：**全文只注入 @scout 与 @builder 首轮**；reviewer / validator 只拿 orchestrator 提炼的摘要（见 §9.0）。

**确认门控**：用户明确确认后方可进入 Phase 0。此后不再需要任何用户交互。

## 6. Phase 0: Specification and Ticketing

### 6.1 to-spec

调用 `Skill("mattpocock-skills:to-spec")`。

- 输入：Phase -1 的对话上下文、CONTEXT.md、ADRs。
- 要求：探索仓库、复用领域词汇、遵守 ADR、定义测试缝隙 seam。
- 产出：符合模板的 spec issue，包含 Problem Statement, Solution, User Stories, Implementation Decisions, Testing Decisions, Out of Scope, Further Notes。
- 动作：发布至 issue tracker，应用 triage 标签 `ready-for-agent`。
- **全自动**：无需用户确认，orchestrator 自行评估 spec 质量后继续。

### 6.2 to-tickets

调用 `Skill("mattpocock-skills:to-tickets")`。

要求：
- 拆分为垂直切片的 tracer-bullet tickets，每张票声明 blocking edges。
- **垂直切片约束**：同一拓扑层的票不得修改相同文件。违反时 orchestrator 检测并强制串行化。
- 支持原生 blocking link 或本地文件回退。
- 每张票必须携带 `acceptance_criteria`（3~8 条可检查的验收标准，从 spec 摘录）。reviewer 只读 ticket（含验收标准），不读完整 SPEC。
- 每张票附带 `affected_files`（声明预计修改的文件列表，用于冲突检测）。

产出：拓扑有序的 `TICKET_DAG`（非线性队列）。

**DAG 校验**：orchestrator 接收 TICKET_DAG 后执行拓扑排序验证：
- 若检测到环依赖：自动断开环中权重最低的边（blocking edge 最少指向的票），记录日志，继续。
- 若 DAG 为空（to-tickets 未产出任何票）：orchestrator 将整个 spec 作为单票直接进入闭环。

orchestrator 在 tickets 产出后为每张票计算 `complexity_score`（1-5），评估依据：ticket 涉及文件数、跨模块依赖数、是否涉及新概念引入。≥ COMPLEXITY_THRESHOLD 时触发 @scout。

## 7. ENV_CONSTRAINT - 全局强约束注入

```
[ENV_CONSTRAINT]
{{ENV_PROFILE preset + WORKSPACE_PATH}}

[DOMAIN_CONTEXT]
{{CONTEXT.md}}              # 仅 @scout / @builder 首轮为全文；reviewer/validator 见 §9.0

[REVIEW_DIMENSIONS]
{{REVIEW_DIMENSIONS}}
```

ENV_PROFILE 预设：
- `generic`: 在 WORKSPACE_PATH 内执行，所有命令需显式声明环境。
- `docker`: `docker exec -w /workspace {{CONTAINER}} bash -lc "<CMD>"`
- `security-lab`: 隔离沙箱执行，禁止联网，产出仅限 artifacts 目录。
- `paper`: 使用 latexmk 构建，禁止直接修改中间产物。

若用户提供自定义 ENV_PROFILE，原样注入。

**前缀纪律（prompt-cache）**：所有新开 agent 会话的 prompt，必须按以下 block 顺序组织：

`[DOMAIN_CONTEXT 或 TICKET_BRIEF] → [ENV_CONSTRAINT] → [REVIEW_DIMENSIONS（如有）] → [角色指令] → [本轮变量内容]`

共享前缀必须字节一致；禁止把每轮都变的东西（round number、时间戳、随机 id）塞进前缀。目的：让跨 agent 调用的共享前缀命中 prompt cache（cache read 计价远低于正常输入）。

## 8. Project Type Adapter

根据 PROJECT_TYPE 选择默认审查维度与验证策略，用户可在 Phase -1 中覆盖。

| PROJECT_TYPE | builder 产出类型 | reviewer 默认维度 | validator 默认行为 |
| :--- | :--- | :--- | :--- |
| dev | 代码 | 正确性、边界条件、性能、可维护性、安全性、是否符合 CONTEXT.md | 执行 VALIDATION_CMD 或等价测试命令 |
| reverse | 分析报告、注释、脚本 | 逻辑自洽性、证据链完整性、假设合理性、可复现性 | 运行 PoC 脚本复现结论 |
| security | PoC、规则、加固方案 | 可利用性、稳定性、隔离性、误伤评估、披露规范 | 沙箱中验证触发稳定性 |
| research / paper | 章节、公式、实验、图表 | 逻辑严谨性、数学一致性、可复现性、论据支撑度、写作规范 | LaTeX 编译、实验 smoke test、引用检查 |
| data | 脚本、模型、报告 | 数据泄露、方法合理性、指标有效性、鲁棒性 | 执行最小可复现单元 |
| auto | 由 orchestrator 推断 | **回退策略**：合并 dev 全部维度 + 逻辑自洽性、证据链完整性 | 执行 VALIDATION_CMD；若未设置则尝试 `npm test` / `pytest` / `make test`，全部不可用时仅做 lint |
## 9. Role Instantiation

### 9.0 会话与上下文策略（核心设计）

1. **Builder 票内会话连续**：同一 ticket 的所有 BUILD 轮次复用**同一个** builder 会话（正常的多轮对话）。SKILL.md（三件套）只在首轮注入；CONTEXT.md、SPEC 只在首轮注入；feedback 通过对话自然传递，不再每轮重新拼接注入。
   - Rationale：builder 是执行者不是裁判，不存在"判断污染"问题。多轮迭代本就该是连续对话。
2. **Reviewer 保持全新独立会话**：每轮 reviewer 都是 fresh session，A/B 双盲隔离保留（B 触发时见 §9.3）。
3. **Validator 复用 builder 会话**：validator 是机械执行（跑命令、读日志），无判断污染风险。VALIDATE 失败时，log_tail 直接作为下一轮 BUILD 的对话输入，零重新注入。
4. **Context 按需裁剪**：

| 角色 | CONTEXT.md | SPEC | Skill 注入 |
|---|---|---|---|
| @scout | 全文 | — | 无 |
| @builder | 全文（仅首轮） | 全文（仅首轮） | tdd + codebase-design + domain-modeling 全文（仅首轮）；续轮用 §9.2 的 condensed checklist |
| @reviewer_A/B | 摘要（≤500 字，orchestrator 从 CONTEXT.md 提炼，只含术语表与架构约束） | 仅当前 ticket（含 acceptance_criteria），不读完整 SPEC | §9.3.1 浓缩版 review rubric，不加载 domain-modeling 全文 |
| @validator | — | — | §9.4 浓缩版输出格式，不加载 diagnosing-bugs 全文 |

   Rationale：裁判只需要"票 + diff"就能判断"实现是否忠实于票"；领域圣经是执行者才需要的。

### 9.1 @scout

**触发条件**：当前 ticket 的 `complexity_score >= COMPLEXITY_THRESHOLD`。

职责：
- 读取 CONTEXT.md、ADR、当前 ticket，探索仓库现状。
- 输出：推荐实现路径 + 已识别的坑/死胡同/架构障碍预警。
- **不是设计方案**，是风险地图。
- **输出上限 1500 词**（注入 builder 的内容必须有界）。

强制输出格式：
```
[RECOMMENDED_PATH]
<简要推荐路径描述>

[PITFALLS]
- <坑 1: 描述 + 为什么是坑>
- <坑 2: ...>

[DEAD_ENDS]
- <死胡同 1: 描述 + 为什么不可行>
```

传递方式：首轮注入 @builder 会话，框定为：
> 以下是 @scout 的探路参考，你可以采纳或推翻，不构成强制指令。

### 9.2 @builder

职责：读取 CONTEXT.md、ADR 与当前 ticket，执行构建。**同一 ticket 内会话连续**（§9.0），多轮 BUILD 是同一会话的自然延续。

**首轮**必须依次加载以下 skills（全文注入）：
1. `Skill("mattpocock-skills:tdd")`
2. `Skill("mattpocock-skills:codebase-design")`
3. `Skill("mattpocock-skills:domain-modeling")`

**续轮**不再重新加载 skill 全文，orchestrator 在 feedback 前只追加以下 condensed checklist（约 120 词）：

```
[DISCIPLINE]
- 优先复用现有最高层 seam；red-green 循环，先失败测试后实现。
- 命名与 CONTEXT.md 术语一致；不引入新外部依赖（或说明理由）。
- 遵守 ENV_CONSTRAINT；只改 ticket.affected_files 声明的文件。
```

内核要求：
- 优先复用现有 seam，使用最高层 seam。
- 遵循 red-green 循环，先失败测试后实现。
- 遵循深模块原则。

强制输出格式：
```
[ARTIFACTS]
- <文件路径 1>: <变更摘要>
- <文件路径 2>: <变更摘要>

[CORE_CHANGES]
<核心改动摘要，3-5 句>

[DESIGN_RATIONALE]
<设计理由与权衡>

[SELF_CHECK]
- [ ] 所有新代码有对应测试
- [ ] 命名与 CONTEXT.md 术语一致
- [ ] 未引入新的外部依赖（或已说明理由）
- [ ] ENV_CONSTRAINT 已遵守

[VALIDATION_STEPS]
<验证命令与预期输出>

[TERM_PROPOSAL] (可选)
- <新术语>: <定义> — <为什么需要>
```

### 9.3 @reviewer_A / @reviewer_B

职责：独立审查 @builder 当前快照。**Diff-based 审查**：reviewer 审查的是 orchestrator 捕获的 git diff + builder 结构化报告的组合。

**B 条件触发**：每轮 reviewer_A 必跑；reviewer_B 仅在以下任一条件成立时触发：
- reviewer_A 发现了 BLOCKER，且 `ticket.complexity_score >= {{REVIEWER_B_COMPLEXITY}}`（默认 4）；或
- reviewer_A 已连续 2 轮拒绝（calibration check：防止单个 reviewer 标准漂移造成死循环）；或
- 抽查（防从宽漂移）：reviewer_A 连续 2 轮直接通过（无 BLOCKER），下一轮自动触发 B 独立复审；B 发现的 BLOCKER 同等有效，B 的 MAJOR/MINOR 进 fix-forward。

Reviewer 接收的 snapshot 包含：
1. **结构化报告**：builder 的 [ARTIFACTS] / [CORE_CHANGES] / [DESIGN_RATIONALE] / [SELF_CHECK] / [VALIDATION_STEPS]
2. **代码变更 diff**：orchestrator 在 BUILD→REVIEW 转换时捕获的 `git diff`（见 §10.4）

**不包含**：CONTEXT.md 全文、完整 SPEC。只含 §9.0 表中的摘要 + ticket（含 acceptance_criteria）。

双盲隔离协议（B 触发时）：
- A 与 B 必须全新独立 subagent 会话。
- 输入仅包含 TASK_GOAL（一行）、ticket（含验收标准）、snapshot（报告 + diff）、REVIEW_DIMENSIONS、CONTEXT 摘要。
- 禁止 A、B 间通信，禁止携带历史意见。

#### 9.3.1 浓缩版 Review Rubric（不加载 domain-modeling 全文）

```
[REVIEW_RUBRIC]
你是代码审查员，只做两件事：
1. Standards 轴：对照 ticket.acceptance_criteria 逐条检查；嗅出 Fowler 坏味道
   （Mysterious Name, Duplicated Code, Feature Envy, Shotgun Surgery,
    Divergent Change，其余按常识）。
2. Spec 轴：实现是否忠实于 ticket 范围——缺失需求、范围蔓延、实现偏差。
分级标准（严格执行，按 PROJECT_TYPE 校准——有效性问题永不降级为 MAJOR）：
- BLOCKER（出现即 is_accepted=FALSE，必须清零）：
  - 通用：验收标准未满足 / 测试会失败 / 引入安全或数据损坏风险。
  - 科学类（research / paper / reverse / security）追加：方法论缺陷（数据泄露、统计方法误用、不可复现的实验步骤）、断言缺乏证据支撑、结论与证据矛盾、完备性缺失（遗漏已知关键机制/约束/对照）。
  - dev 类追加：并发竞争、资源泄露、静默错误吞没等正确性问题（即使当前测试碰巧通过）。
- MAJOR：不影响结论有效性的改进点——呈现结构、写作表达、图表质量、代码效率与可读性。记录进 fix-forward，不阻塞、不消耗重做轮次。
- MINOR：命名、风格、排版。记录进 fix-forward，不阻塞。
禁止事项：不要重构 diff 之外的代码；不要对 CONTEXT.md 摘要之外的领域知识做假设；
"可以更好"且**不影响有效性**才是 MINOR；科学类项目禁止以"以后再补"为由放行任何有效性问题。
```

强制输出格式：
```
[is_accepted: TRUE|FALSE]

[BLOCKERS]
- <BLOCKER 1: 描述 + 修复建议>

[MAJORS]
- <MAJOR 1: 描述 + 修复建议>

[MINORS]
- <MINOR 1: 描述 + 优化建议>

[SCORE]
blocker_count: N
major_count: N
minor_count: N
weighted_score: <BLOCKER×3 + MAJOR×2 + MINOR×1>
```

`is_accepted` 语义：**仅当 BLOCKER 存在时才可为 FALSE**。只有 MAJOR/MINOR 时必须为 TRUE（它们走 fix-forward，不阻塞）。

#### 9.3.2 Reviewer 输出解析

orchestrator 接收 reviewer 文本产出后，解析为结构化对象：

```python
def parse_reviewer_output(raw_text) -> ReviewResult:
    return ReviewResult(
        is_accepted = parse_bool(extract_field(raw_text, "is_accepted")),
        blockers = extract_list(raw_text, "BLOCKERS"),
        majors = extract_list(raw_text, "MAJORS"),
        minors = extract_list(raw_text, "MINORS"),
        weighted_score = parse_int(extract_field(raw_text, "weighted_score")),
        # feedback = BLOCKERS + MAJORS + MINORS 的完整文本，用于 merge_lossless
        feedback = extract_section(raw_text, "BLOCKERS")
                 + extract_section(raw_text, "MAJORS")
                 + extract_section(raw_text, "MINORS")
    )
```

字段说明：
- `is_accepted`: 从 `[is_accepted: TRUE|FALSE]` 行解析布尔值。
- `blockers` / `majors` / `minors`: 对应段落下的条目列表。
- `feedback`: 三段原始文本拼接，作为 `merge_lossless` 的输入（merge_lossless 负责去重 MAJOR/MINOR）。
- `weighted_score`: 从 `[SCORE]` 段提取整数。

若解析失败（reviewer 未遵循格式），orchestrator 将整个输出视为：
```python
ReviewResult(
    is_accepted=False,
    blockers=["[FORMAT_ERROR] Reviewer 未遵循输出格式"],
    majors=[], minors=[],
    weighted_score=3,  # 视为 1 个 BLOCKER
    feedback=raw_text  # 全文作为 feedback
)
```
注意：`blockers` 非空确保渐进干预机制可正常运作。

### 9.4 @validator

**触发条件**：REVIEW 阶段无 BLOCKER（或 orchestrator 降级验收时）。

**复用 builder 会话**（§9.0）：validator 不是独立 agent，而是在 builder 会话内执行的一段机械流程。不加载 diagnosing-bugs 全文，只遵循以下浓缩格式：

```
[VALIDATOR]
1. 在票分支（orchestrator/{ticket_id}，即当前 worktree）执行 VALIDATION_CMD。
2. 成功：git commit（Conventional Commits 格式），输出 [STATUS: PASSED] + commit hash。
3. 失败：输出 [STATUS: FAILED] + stderr/stdout 尾部（≤80 行）+ 一句话复现路径。
   失败的 log_tail 自动成为下一轮 BUILD 的输入（同一会话，无需重新注入）。
```

**注意**：merge 回主干由外层调度器（§10.1）负责，validator 仅在票分支上 commit。

### 9.5 TERM_PROPOSAL 机制

当 @builder 输出包含 `[TERM_PROPOSAL]` 时：
1. Orchestrator 评估提案合理性（是否与现有术语冲突、是否真正需要）。
2. 合理：追加到 CONTEXT.md 并记录日志。
3. 不合理：忽略，不阻塞构建流程。
4. 此决策由 orchestrator 自主完成，不询问用户。

## 10. State Machine - Loop Engine

### 10.1 外层：DAG 流式调度

```python
# spec 和 CONTEXT 在 Phase 0/Phase -1 中已产出，作为闭包变量传入
TICKET_DAG = to_tickets(spec).build_dag()
active_tickets = {}  # ticket_id -> TicketState(coroutine, branch, ticket)
completed = set()
base_branch = git_current_branch()  # 记录主干分支
CONTEXT = read_file("CONTEXT.md")   # Phase -1 产出
SPEC = spec                          # Phase 0.1 产出的 spec 内容

while not all_completed(TICKET_DAG, completed):
    # 解锁所有前置已完成的票
    ready = [t for t in TICKET_DAG
             if t.id not in completed
             and t.id not in active_tickets
             and all(dep in completed for dep in t.blocking_deps)]

    # 文件冲突检测：基于 ticket.affected_files 声明，重叠票强制串行
    # 同时检查与 active_tickets 中正在运行票的 affected_files 是否重叠
    ready = resolve_file_conflicts(ready, active_tickets)

    for ticket in ready:
        # 每张并行票在独立分支上工作（见 §10.1.1 分支隔离）
        ticket.branch = create_ticket_branch(ticket.id, base_branch)
        # 本 skill：builder 会话在票内连续，只创建一次（见 §9.0）
        builder_session = launch_builder_session(ticket, CONTEXT, SPEC)
        coro = launch_closed_loop(ticket, builder_session)
        active_tickets[ticket.id] = TicketState(coro=coro, branch=ticket.branch, ticket=ticket)

    # 若无 ready 且无 active：说明存在不可解的依赖（理论上 DAG 校验已排除）
    if not ready and not active_tickets:
        report(type="DEADLOCK_UNRESOLVABLE", note="DAG 中存在无法解锁的票")
        break

    # 等待任一票完成（仅当 active_tickets 非空时）
    if active_tickets:
        finished_id, result = await any_complete(active_tickets)
        # 完成后 merge 回主干
        merge_ticket_branch(active_tickets[finished_id].branch, base_branch)
        completed.add(finished_id)
        del active_tickets[finished_id]
        persist_state()  # 断点恢复
```

#### 10.1.1 分支隔离策略

解决并行票共享 git 工作目录导致 `git add -A` 污染 diff 的问题：

1. **每张票创建独立分支 + worktree**：
   - 分支：`orchestrator/{ticket_id}`，基于当前 `base_branch` HEAD 创建。
   - Worktree：`git worktree add .orchestrator/worktrees/{ticket_id} orchestrator/{ticket_id}`。
   - Builder 会话的工作目录设为该 worktree 路径（非主工作目录）。
2. **capture_git_diff 安全性**：每个 worktree 是独立的文件系统视图，`git add -A` + `git diff --cached` 仅包含当前票的变更，不影响其他 worktree。
3. **基线一致性说明**：并行票各自基于创建时的 `base_branch` HEAD。先完成的票 merge 回主干后，正在运行的票不执行 rebase（会打断进行中的构建）。这是安全的，因为：
   - `affected_files` 不重叠保证文件级无冲突；
   - Git 3-way merge 在文件不重叠时总是干净合并；
   - 若后完成的票依赖先完成票的产出（有 blocking edge），DAG 已保证串行；
   - 万一出现意外冲突，第 4 点的冲突处理兜底。
4. **完成后合并 + 清理**：
   - validator 通过后在 worktree 内 commit。
   - 外层调度器执行：`git checkout {base_branch} && git merge orchestrator/{ticket_id} --no-ff`。
   - 清理：`git worktree remove .orchestrator/worktrees/{ticket_id} && git branch -d orchestrator/{ticket_id}`。
5. **冲突处理**：若 merge 产生冲突（理论上不应该，因为 affected_files 不重叠），执行以下策略：
   - 尝试 `git merge --abort`，然后对冲突票执行 rebase：`git rebase {base_branch}`。
   - 若 rebase 后冲突仍无法自动解决，标记该票为 DELIVERED_WITH_LIMITATIONS 并在 report 中记录冲突文件列表。
   - 绝不阻塞后续票的执行。
6. **串行票简化**：当同一时间只有一张票在执行时（无并行），可直接在 base_branch 上工作，跳过 worktree 创建。
7. **断点恢复**：worktree 路径记录在 state.json 中。恢复时检测 worktree 是否仍存在，若已丢失则重建。
8. **统一清理保障**：
   - 每张票闭环结束时（无论成功、限制交付、或强制交付），均执行 `git worktree remove` + `git branch -d`。
   - ALL_COMPLETE 时执行全局扫描：`git branch --list 'orchestrator/*'` 删除所有残留分支；`rm -rf .orchestrator/worktrees/` 清理残留 worktree。
   - 断点恢复时：若检测到孤立的 `orchestrator/*` 分支（不在 active_tickets 中），直接清理。

### 10.2 内层：单票闭环

```python
def closed_loop(ticket, builder_session):
    round = 1
    feedback_history = []       # 仅用于 streak 计算与 fix-forward；builder 靠会话连续
    snapshots = {}              # round -> snapshot（MAX_ITER fallback 用）
    snapshot_scores = {}
    snapshot_retry = 0
    consecutive_A_rejects = 0
    consecutive_A_accepts = 0
    was_override = False
    last_raw_output = "[NO_OUTPUT] Builder 未能产出任何内容"  # 安全默认值，确保永远交付
    last_snapshot = None
    last_diff = None

    # 渐进干预阈值：MAX_ITER=6 的 30% / 50% / 70%
    REFRAME_AT = 2
    SCOUT_INTERVENE_AT = 3
    OVERRIDE_AT = 5

    state = "BUILD"
    if ticket.complexity_score >= COMPLEXITY_THRESHOLD:
        # scout 先行：结果注入 builder 首轮（≤1500 词）
        scout_output = call(@scout, ticket=ticket, context=CONTEXT)
        builder_session.send("[SCOUT]\n" + scout_output +
            "\n> 以下是 @scout 的探路参考，你可以采纳或推翻，不构成强制指令。")

    while round <= MAX_ITER:
        persist_state(ticket.id, round, state)

        if state == "BUILD":
            # 同一会话的自然延续；首轮之后不再重复注入 skills/CONTEXT/SPEC
            snapshot = builder_session.build()
            last_raw_output = snapshot
            if not validate_snapshot(snapshot):
                snapshot_retry += 1
                if snapshot_retry >= 3:
                    builder_session.send(
                        "[SNAPSHOT_INVALID] 你的产出未通过完整性校验（连续3次）。"
                        "请确保：1) [ARTIFACTS] 列出的文件已实际创建 "
                        "2) [SELF_CHECK] 所有项已勾选 3) [VALIDATION_STEPS] 非空。")
                    feedback_history.append("[SNAPSHOT_INVALID]")
                    round += 1
                    snapshot_retry = 0
                continue
            snapshot_retry = 0
            snapshots[round] = snapshot
            persist_snapshot(ticket.id, round, snapshot)
            code_diff = capture_git_diff()   # worktree 内 git add -A + git diff --cached
            last_snapshot, last_diff = snapshot, code_diff
            state = "REVIEW"

        elif state == "REVIEW":
            result_A = call_fresh(@reviewer_A, ticket=ticket,
                                  snapshot=last_snapshot, diff=last_diff)
            # B 条件触发：A 有 BLOCKER 且（高复杂度 或 A 已连拒）；或抽查（A 连过 2 轮）
            need_B = (result_A.blockers
                      and (ticket.complexity_score >= REVIEWER_B_COMPLEXITY
                           or consecutive_A_rejects >= 1))
                      or consecutive_A_accepts >= 2
            result_B = (call_fresh(@reviewer_B, ticket=ticket,
                                   snapshot=last_snapshot, diff=last_diff)
                        if need_B else None)

            if result_A.blockers:
                consecutive_A_rejects += 1
                consecutive_A_accepts = 0
            else:
                consecutive_A_rejects = 0
                consecutive_A_accepts += 1
            snapshot_scores[round] = min(
                result_A.weighted_score,
                result_B.weighted_score if result_B else result_A.weighted_score)

            # 分级决策：只有 BLOCKER 能阻塞；MAJOR/MINOR 进 fix-forward
            blockers = result_A.blockers + (result_B.blockers if result_B else [])
            majors = result_A.majors + (result_B.majors if result_B else [])
            minors = result_A.minors + (result_B.minors if result_B else [])
            if majors or minors:
                append_fix_forward(ticket.id, round, majors, minors)  # §10.9，不阻塞

            if not blockers:
                was_override = False
                state = "VALIDATE"
            else:
                current_blocker = blockers[0]
                streak = count_consecutive_same_blocker(feedback_history, current_blocker)
                if streak >= OVERRIDE_AT:
                    # 降级验收：接受当前快照，带限制交付
                    was_override = True
                    report(type="OVERRIDE", ticket=ticket.id, round=round,
                           reason=f"同一 BLOCKER 连续 {streak} 轮未解决")
                    state = "VALIDATE"
                elif streak >= SCOUT_INTERVENE_AT:
                    scout_output = call(@scout, ticket=ticket,
                                        context=CONTEXT, focus=current_blocker)
                    fb = "[SCOUT_INTERVENTION]\n" + scout_output
                    feedback_history.append(fb)
                    builder_session.send(fb)
                    round += 1
                    state = "BUILD"
                elif streak >= REFRAME_AT:
                    fb = reframe_feedback(feedback_history, current_blocker)
                    feedback_history.append(fb)
                    builder_session.send(fb)
                    round += 1
                    state = "BUILD"
                else:
                    # 反馈只含 BLOCKER（有效性问题）；MAJOR/MINOR 已进 fix-forward，不进重做循环
                    fb = merge_lossless(blockers)
                    feedback_history.append(fb)
                    builder_session.send(fb + "\n" + DISCIPLINE_CHECKLIST)  # §9.2 condensed
                    round += 1
                    state = "BUILD"

        elif state == "VALIDATE":
            # validator 复用 builder 会话（§9.4）：机械执行，无需新开 agent
            vr = builder_session.validate(cmd=ticket.validation_cmd)
            if vr.status == "FAILED":
                if was_override:
                    # 已决定降级验收，validation 失败不阻塞交付
                    execute_delivery(last_snapshot, vr, force=True)
                    report(type="DELIVERED_WITH_LIMITATIONS", ticket=ticket.id,
                           round=round,
                           limitations=collect_unresolved(feedback_history),
                           validation_failure=vr.log_tail)
                    return
                else:
                    fb = "[VALIDATION_FAILED]\n" + vr.log_tail  # ≤80 行
                    feedback_history.append(fb)
                    builder_session.send(fb)  # 同一会话，零重新注入
                    round += 1
                    state = "BUILD"
            else:
                execute_delivery(last_snapshot, vr)
                if was_override:
                    report(type="DELIVERED_WITH_LIMITATIONS", ticket=ticket.id,
                           round=round, commit=vr.commit_hash,
                           limitations=collect_unresolved(feedback_history))
                else:
                    report(type="TICKET_SUCCESS", ticket=ticket.id,
                           round=round, commit=vr.commit_hash)
                return

    # MAX_ITER 到达：行使最终决定权，强制交付最佳历史 snapshot（不再过 validator）
    if snapshot_scores:
        best_round = min(snapshot_scores, key=snapshot_scores.get)
        best_snapshot = snapshots[best_round]
    else:
        # 所有轮次均未通过 validate_snapshot，无有效 snapshot
        # 永远交付原则：取最后一次 builder 的原始产出（即使未通过校验）强制交付
        best_snapshot, best_round = last_raw_output, round
    execute_delivery(best_snapshot, force=True)
    report(type="DELIVERED_WITH_LIMITATIONS", ticket=ticket.id, round=MAX_ITER,
           limitations=collect_all_unresolved(feedback_history),
           note=f"MAX_ITER reached, delivered best available (round {best_round}), validator skipped")
```

### 10.3 validate_snapshot 定义

校验 @builder 产出的完整性：
1. `[ARTIFACTS]` 非空且所有列出的文件确实存在。
2. `[SELF_CHECK]` 所有项已勾选。
3. `[VALIDATION_STEPS]` 非空。
4. 若以上任一不满足，返回 False。

### 10.4 capture_git_diff

在 BUILD→REVIEW 转换时执行，捕获 builder 的实际代码变更：
1. 确认当前在票的 worktree（`.orchestrator/worktrees/{ticket_id}`）中操作（见 §10.1.1）。
2. 执行 `git add -A` 将 builder 改动暂存（worktree 隔离保证仅含当前票的变更）。
3. 执行 `git diff --cached` 获取变更 diff。
4. 若 diff 为空（builder 声明了 ARTIFACTS 但无实际文件变更），标记为异常并回退到 validate_snapshot 失败路径。
5. diff 文本作为 `code_diff` 传入 reviewer。
6. 不执行 commit——commit 由 @validator 在验证通过后执行。

### 10.5 persist_snapshot

每轮 BUILD 通过 validate_snapshot 后，将 snapshot 内容写入 `.orchestrator/snapshots/{ticket_id}_round{N}.md`。用于：
- MAX_ITER 强制交付时取回最佳历史 snapshot。
- 断点恢复后水合 builder 会话（§13），无需从零重新执行。

### 10.6 resolve_file_conflicts

基于 `ticket.affected_files`（to-tickets 阶段声明）检测冲突：
1. 对 `ready` 列表中的票两两比较 `affected_files`。
2. **同时检查 `active_tickets` 中正在运行票的 `affected_files`**：若 ready 中的票与任何 active 票有文件重叠，推迟该 ready 票。
3. 若存在交集（ready 内部），保留拓扑序靠前的票进入并行，其余推迟到下一轮。
4. 若 builder 实际修改了声明外的文件，在 validate_snapshot 后更新 `affected_files`，下轮调度时生效。
5. **运行时碰撞检测**：即使 worktree 隔离了文件系统，merge 阶段仍可能因未声明的文件重叠产生冲突。当 merge 冲突涉及未在 `affected_files` 中声明的文件时，orchestrator 将该文件追加到两张票的 `affected_files`，并对后完成的票触发冲突处理流程（§10.1.1 第 5 点）。

### 10.7 merge_lossless / reframe_feedback / format_scout_intervention

**merge_lossless(blockers)**：
- 输入：BLOCKER 列表（字符串）。
- 规则：保留所有 BLOCKER；去重（相同文件 + 相同描述视为重复）；按严重度排序；不丢失可执行信息。
- 输出：合并后的 feedback 文本。
- MAJOR / MINOR 不进入本函数，它们只进 fix-forward（§10.9）。

**reframe_feedback(feedback_history, current_blocker)**：当同一 BLOCKER 连续出现 REFRAME_AT 轮时，orchestrator 分析历史尝试模式，生成替代切入角度：
- 列出已尝试的方法；
- 排除已失败路径；
- 建议全新方向；
- 返回格式化后的 feedback 字符串。

**format_scout_intervention(scout_output)**：将 @scout 的输出（[RECOMMENDED_PATH] + [PITFALLS] + [DEAD_ENDS]）转换为 builder 可消费的 feedback 格式：
- 前缀 `[SCOUT_INTERVENTION]`；
- 原样包含 scout 的推荐路径和预警；
- 返回格式化后的 feedback 字符串。

### 10.8 count_consecutive_same_blocker

计算当前 BLOCKER 在 `feedback_history` 末尾连续出现的次数：

```python
def is_similar(entry, target, threshold=0.6):
    """关键词重叠率相似度判定。
    提取两个字符串的关键词集合（去除停用词、标点），
    计算 Jaccard 相似度，>= threshold 视为相同 BLOCKER。
    """
    keywords_a = extract_keywords(entry)
    keywords_b = extract_keywords(target)
    if not keywords_b:
        return False
    overlap = len(keywords_a & keywords_b) / len(keywords_a | keywords_b)
    return overlap >= threshold

def count_consecutive_same_blocker(feedback_history, current_blocker):
    """从 feedback_history 末尾向前扫描，计算与 current_blocker 描述相似的连续条目数。
    相似度判定：current_blocker 的关键词（去除停用词后）与历史条目的关键词重叠率 >= 60%。
    """
    streak = 0
    for entry in reversed(feedback_history):
        if is_similar(entry, current_blocker, threshold=0.6):
            streak += 1
        else:
            break
    return streak
```

### 10.9 fix-forward 日志

MAJOR / MINOR 不阻塞交付，但**不丢失**：

- 路径：`.orchestrator/fix-forward/{ticket_id}.md`，每轮 REVIEW 后追加。
- 内容：轮次、MAJOR/MINOR 原文、所属文件。
- ALL_COMPLETE 时，orchestrator 在最终汇总中列出所有 fix-forward 项，并建议：转为新票（to-tickets 增量）或在最终 `code-review` 全量审查时一并处理。
- Rationale：呈现类打磨从"阻塞交付"降级为"排期处理"。注意：有效性问题永不进入 fix-forward——它们是 BLOCKER，必须在循环内清零（§9.3.1）。本 skill 的 token 节省来自会话连续、上下文裁剪与 cache 纪律，而非牺牲严谨。

### 10.10 票拆分（优化手段）

在 SCOUT_INTERVENE_AT 阶段，若 @scout 判断当前票过大或包含不可分割的架构冲突：
- Orchestrator 将该票拆为子票；
- 可完美交付的部分立即进入闭环；
- 有限制的部分标注后继续尝试；
- 目标：最大化完美交付比例。
## 11. Watchdog

监控机制通过 orchestrator 主循环内的超时竞赛实现（非独立进程）。

1. **Heartbeat Timeout**: 对每个 `agent()` 调用设置 120s 超时。超时判定失联。动作：Kill 并重建全新会话，重发任务，round 不增加。**最大重试次数：3**。超过 3 次连续超时视为该 agent 不可用，等同于 validate_snapshot 失败，round+1 并在 feedback 中记录 `[AGENT_UNAVAILABLE]`。
   - 重建 builder 会话时，用 §13 的水合流程恢复（last snapshot + merged feedback），而不是从零开始。
2. **Long Task Hang**: 检测到长耗时关键词（如大规模重构、全量测试）时，在 builder 首轮 prompt 中注入心跳要求，要求每 30s 输出进度标记。若最终产出无进度标记且耗时 > 60s，标记为可疑但不阻塞。
3. **Output Integrity**: 即 validate_snapshot（§10.3）。失败则不进入 REVIEW。连续 3 次失败时 round+1。

## 12. Reporting Protocol

### 12.1 事件类型

| 事件 | 内容 |
|---|---|
| REJECTED | 票 ID、轮次、A（/B）结果、BLOCKER 摘要。注意：只有 BLOCKER 能触发 REJECTED |
| VALIDATE_FAILED | 票 ID、轮次、VALIDATION_CMD、关键日志尾部 |
| OVERRIDE | 票 ID、轮次、override 原因、被覆盖的 BLOCKER 描述 |
| TICKET_SUCCESS | 票 ID、轮次、交付物 commit 或 artifact 路径 |
| DELIVERED_WITH_LIMITATIONS | 票 ID、轮次、已交付内容、未解决限制、建议后续 |
| FIX_FORWARD | 票 ID、轮次、未阻塞的 MAJOR/MINOR 清单（实时追加，不触发告警） |
| ALL_COMPLETE | Spec ID、总票数、完美交付数、带限制交付数、总迭代数、fix-forward 总数 |

### 12.2 输出位置

- **实时事件**：写入 `.orchestrator/report.md`（追加模式）。
- **主对话**：仅输出单行摘要（如 `✅ Ticket #3 delivered (round 2)` 或 `⚠️ Ticket #5 delivered with limitations`）。
- **最终汇总**：ALL_COMPLETE 时在主对话输出结构化摘要，含 fix-forward 清单（建议转为新票或在最终 code-review 时处理），详细内容指向 report.md。

## 13. Breakpoint Recovery

### 13.1 状态文件

路径：`.orchestrator/state.json`

```json
{
  "task_goal": "...",
  "phase": "PHASE_1",
  "base_branch": "main",
  "ticket_dag": { ... },
  "completed_tickets": ["T1", "T2"],
  "active_tickets": {
    "T3": { "round": 4, "state": "BUILD", "branch": "orchestrator/T3",
            "feedback_history": [...], "was_override": false,
            "consecutive_A_rejects": 1 }
  },
  "snapshot_scores": { "T3": { "1": 8, "2": 5, "3": 3 } },
  "context_md_hash": "sha256:..."
}
```

Snapshot 内容单独存储于 `.orchestrator/snapshots/` 目录（见 §10.5），state.json 仅记录元数据。

### 13.2 恢复逻辑

1. 检测 `.orchestrator/state.json` 是否存在。
2. 若存在且 `task_goal` 匹配当前 TASK_GOAL：
   - 跳过已完成的 Phase 和 tickets。
   - 从 `active_tickets` 中最后已知状态恢复闭环。
   - **Builder 会话水合**：LLM 会话无法持久化，因此为每张 active 票重建 builder 会话，水合包 = ticket + CONTEXT.md + SPEC + 三件套 skill 全文 + last snapshot + feedback_history 合并后的 merged feedback（去重、截断到 3000 词）。水合后 `state` 重置为 `"BUILD"`（安全选择：不恢复 DECISION / VALIDATE 等中间态，因为 `snapshot`、`code_diff`、`result_A`、`result_B` 等瞬态变量不持久化）。
   - 代价：一次水合 ≈ 一次首轮 builder 调用的量级，但只在断点恢复时发生一次。
3. 若 `task_goal` 不匹配：视为新任务，备份旧状态文件后重新开始。

### 13.3 持久化时机

每次状态转移（BUILD→REVIEW→VALIDATE）时写入。每张票完成时写入。

## 14. Glossary

| 术语 | 定义 |
|---|---|
| 流式并行 | DAG 中前置票完成即解锁后续票，不等待同层全部完成 |
| 降级验收 | orchestrator 判定 BLOCKER 不可解决，接受当前快照带限制交付 |
| 渐进干预 | 比例制（30%/50%/70% of MAX_ITER，即 2/3/5 轮）的逐步升级响应 |
| validate_snapshot | 校验 builder 产出完整性的门控函数 |
| persist_snapshot | 每轮 BUILD 成功后持久化 snapshot 到磁盘 |
| resolve_file_conflicts | 基于 affected_files 声明检测并行票文件冲突 |
| 分支隔离 | 每张并行票在独立 git 分支 `orchestrator/{ticket_id}` + worktree 上工作，防止 diff 污染 |
| capture_git_diff | 在票分支上执行 git add -A + git diff --cached，安全捕获当前票变更 |
| review_payload | 传入 reviewer 的数据包：结构化报告 + 代码 diff（不含 CONTEXT.md 全文） |
| parse_reviewer_output | 将 reviewer 文本产出解析为结构化 ReviewResult 对象 |
| TERM_PROPOSAL | builder 发现新领域术语时的提案机制 |
| 垂直切片 | 每张票修改独立的文件集合，不与同层票交叉 |
| same_blocker_streak | 同一 BLOCKER（按描述相似度判定）在 feedback_history 中连续出现的次数 |
| affected_files | to-tickets 阶段声明的每张票预计修改文件列表，用于并行冲突检测 |
| acceptance_criteria | 每张票携带的 3~8 条可检查验收标准，reviewer 只读 ticket 即得 |
| 分级严谨 | 仅 BLOCKER 阻塞交付（BLOCKER 定义按项目类型校准，有效性问题永不降级）；MAJOR/MINOR 仅限呈现与打磨，进 fix-forward |
| fix-forward | 未阻塞交付的呈现类 MAJOR/MINOR 日志，ALL_COMPLETE 时汇总建议转新票 |
| 会话连续 | builder 在同一 ticket 内复用同一会话，多轮 BUILD 为自然对话延续 |
| 前缀纪律 | 共享 prompt block 字节一致、置于最前，最大化 prompt cache 命中 |
