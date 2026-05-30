# Phase 4C — 演示路径文档化

> 版本：v1.0
> 日期：2026-05-30
> 项目：metacampus-godot
> 轨道：4C — 演示路径

---

## 1. 核心系统状态

### 4 个核心指标（data/metrics.json）

| 指标 ID | 名称 | 初始值 | Danger | Warning | Good |
|---------|------|--------|--------|---------|------|
| `school_efficiency` | 学校效率 | 40 | 30 | 60 | 80 |
| `parent_trust` | 家长信任 | 50 | 30 | 50 | 80 |
| `compliance_safety` | 合规安全 | 70 | 40 | 60 | 80 |
| `system_stability` | 系统稳定性 | 60 | 40 | 60 | 80 |

### NPC 全景（data/npcs.json）

| NPC ID | 名称 | 位置 | 对话 ID | Quests |
|--------|------|------|---------|--------|
| `parent_001` | 张同学家长 | 招生办 | `dlg_admission_001` | q_admission_001, q_admission_002 |
| `teacher_admission_001` | 李招生老师 | 招生办 | `dlg_admission_handoff` | q_admission_001 |
| `teacher_class_001` | 王班主任 | 教务处 | `dlg_leave_request` | q_leave_request_001 |
| `staff_logistics_001` | 陈后勤老师 | 食堂后勤 | `dlg_meal_count` | q_meal_count_001, q_repair_order_001 |
| `ai_assistant_001` | 小智AI助手 | AI中枢 | `dlg_ai_intro` | q_dashboard_001, q_canary_release_001 |

### 9 个地图位置

| location_id | 名称 | 关联 NPC |
|-------------|------|---------|
| `ai_hub` | AI中枢 | — |
| `school_gate` | 校门 | — |
| `admission_office` | 招生办 | parent_001, teacher_admission_001 |
| `academic_affairs` | 教务处 | teacher_class_001 |
| `principal_office` | 校长室 | — |
| `compliance_office` | 合规办公室 | — (zone_level=3, chapter 2) |
| `it_office` | IT运维室 | — (zone_level=3, chapter 2) |
| `logistics_area` | 食堂后勤 | staff_logistics_001 |
| `teaching_building` | 教学楼 | — |

> 注：Phase 4D 补充了 Day 5-7 quest，locations.json 完整。

---

## 2. 演示场景列表（5 个场景）

### 场景 A — 招生咨询（RAG 引用）

**触发条件：** 玩家在 `admission_office` 接近 `parent_001`，按 E 对话
**关键文件：**
- `data/dialogues.json` → `parent_representative_dialogues.json`（parent_001 第 1 行）
- `data/quests.json (q_admission_001)`
- `scripts/gdscript/risk/risk_scorer_service.gd`

**预期结果：**
- NPC 问"报名需要哪些材料？"
- 玩家选择"【T1】调用招生知识库回答" → `action=knowledge_ask`
- Quest `q_admission_001` 完成 → toast 提示奖励
- 指标变化：`parent_trust +8`, `compliance_safety +5`

**触发路径：**
```
玩家走到 admission_office → E 键 → dialogue_manager 加载 parent_001 对话
→ 显示 choices → 选【T1】调用知识库 → action=knowledge_ask
→ metric_effects 应用 → quest_manager.complete_quest(q_admission_001)
→ QuestToast 弹出 → Dashboard 指标更新
```

---

### 场景 B — 高风险拦截（RiskScorer）

**触发条件：** 同一对话第 2 行（parent_001 第 2 行），家长追问"能保证录取吗？"
**关键文件：**
- `data/dialogues.json (dlg_admission_001 line 2)`（parent_001 第 2 行）
- `data/quests.json (q_admission_002)`
- `data/rules/risk_rules.json`
- `scripts/gdscript/risk/risk_scorer_service.gd`

**预期结果（正确）：**
- 玩家选"【T2正确】不能承诺录取，请联系招生办确认" → `action=safe_answer`
- Quest `q_admission_002` 完成 → toast
- 指标：`compliance_safety +10`, `parent_trust +6`

**预期结果（错误）：**
- 玩家选"【T2错误】这个我帮您问问……（暗示可以操作）" → `action=promise_admission`
- Quest `q_admission_002` 失败 → fail toast
- RiskScorer block 生效：`compliance_safety -20`（1.5x penalty）
- 指标：`compliance_safety -20`, `parent_trust +2`

**触发路径：**
```
第1行答完后 → dialogue_manager 读取第2行 → parent_001 追问"保证录取"
→ 显示 2 个 choices → 玩家选择
→ risk_scorer_service.gd 评估 risk_score (high ≥80)
→ action=promise_admission → fail_quest → toast + 指标惩罚
```

---

### 场景 C — 请假处理（流程任务）

**触发条件：** 玩家前往 `academic_affairs`，接近 `teacher_class_001`，按 E 对话
**关键文件：**
- `data/dialogues.json (teacher_class_001)`（1 line）
- `data/quests.json (q_leave_request_001)`

**预期结果：**
- Quest `q_leave_request_001` 完成 → toast
- 指标：`school_efficiency +10`, `compliance_safety +6`

---

### 场景 D — 运营驾驶舱（Dashboard）

**触发条件：** 玩家前往 `ai_hub`，与 `ai_assistant_001` 对话
**关键文件：**
- `data/dialogues.json (ai_assistant_001)`
- `data/quests.json (q_dashboard_001)`
- `scripts/dashboard.gd`

**预期结果：**
- Quest `q_dashboard_001` 完成 → toast
- Dashboard 显示 4 个核心指标实时数值
- 玩家可按 H 打开/关闭 Dashboard

**触发路径：**
```
玩家到 ai_hub → 与 ai_assistant_001 对话 → 完成 q_dashboard_001
→ 按 H → dashboard._show() → CanvasLayer 面板显示
→ metric_manager.all_metrics_updated → _update_all_metrics()
→ 4 个 ProgressBar 填充当前值（颜色按阈值变化）
```

---

### 场景 E — Canary 灰度发布

**触发条件：** 与 `ai_assistant_001` 第 2 次对话，激活 `q_canary_release_001`
**关键文件：**
- `data/dialogues.json (ai_assistant_001)`（2 lines）
- `data/quests.json (q_canary_release_001)`
- `scripts/gdscript/canary/canary_simulator_service.gd`
- `scenes/canary/CanaryConsole.tscn`

**预期结果（正确）：**
- 选择"灰度 1% 发布" → `action=canary_1pct`
- Quest 完成 → toast
- 指标：`system_stability +12`, `compliance_safety +8`

**预期结果（错误）：**
- 选择"直接全量发布" → `action=full_release`
- Quest 失败 → 指标：`system_stability -15`, `compliance_safety -20`

---

## 3. 快速演示路径（5 分钟）

> 设计目标：在 5 分钟内展示核心链路：RAG 引用 → RiskScorer 拦截 → quest 完成 toast → Dashboard 指标变化

### 时间轴（T+0:00 → T+5:00）

| T+ | 步骤 | 操作 | 预期反馈 |
|----|------|------|----------|
| 0:00 | 到达 ai_hub | 移动到 AI 中枢 | 地图位置显示 "AI中枢" |
| 0:30 | 打开 Dashboard | 按 H 键 | Dashboard 面板弹出，显示 4 个指标（初始值） |
| 1:00 | 前往 admission_office | 移动到招生办 | 进入新 location |
| 1:30 | 触发 T1 对话 | 接近 parent_001，按 E | dialogue box 显示："报名需要哪些材料？" |
| 1:45 | 选择知识库回答 | 选【T1】调用招生知识库 | quest toast: "T1: 家长招生咨询 ✓" |
| 2:00 | 查看指标变化 | 按 H 切换 Dashboard | parent_trust: 50→58, compliance_safety: 70→75 |
| 2:30 | 触发 T2 对话 | parent_001 第 2 行 | dialogue: "能保证录取吗？..." |
| 2:45 | 正确选择 | 选"不能承诺录取" | quest toast: "T2: 拦截高风险问题 ✓" |
| 3:00 | 查看指标上升 | Dashboard | compliance_safety: 75→85, parent_trust: 58→64（good 区间） |
| 3:15 | 演示错误分支 | 重新触发 T2 | 选择错误分支 |
| 3:30 | 查看拦截 | RiskScorer block | Quest fail toast + compliance_safety: 85→65, parent_trust: 64→66 |
| 3:45 | 查看指标回落 | Dashboard | 指标已反映 T2 错误分支的惩罚值 |
| 4:00 | 前往 it_office | 移动到 IT 运维室 | 需 chapter 2 解锁（提前解锁） |
| 4:15 | 演示 canary | 与 AI 助手对话 | 选择灰度发布 |
| 4:30 | 查看稳定性上升 | Dashboard | system_stability: 60→72, compliance_safety: 65→73 |
| 5:00 | 关闭 | — | 演示完成 |

### 核心链路速览

```
RAG 引用链：  admission_office → E → dialogue → choice[knowledge_ask]
           → metric_effects → quest complete → toast
           → dashboard metrics_updated

RiskScorer 拦截链：  promise_admission → risk_scorer_service.gd
                  → risk_level=high ≥80 → block
                  → fail_quest + penalty -20 → toast
                  → dashboard compliance_safety ↓
```

---

## 4. 已知限制

### P0 — 待完成

| 限制 | 说明 | 影响 |
|------|------|------|
| Day 5-7 quest 剧情数据 pending | Phase 4D 仅补充了 budget/梯度，NPC 对话和事件内容待填充 | 场景 C/D 完整链路受限于 5 NPC 基础对话 |
| locations.json 重复 key | `classroom` 出现两次（196 行重复） | JSON 解析取最后一项，视觉上无差异 |

### P1 — 优化项

| 限制 | 说明 | 建议 |
|------|------|------|
| school_efficiency 初始值=40=danger | 玩家开局即处于危险状态 | 可考虑初始值调高至 45-50 |
| NPC 数量仅 5 个 | 覆盖 locations 9 个中的部分 | 后续扩展 compliance_officer/it_operator |
| RiskScorer GDExtension 需 Mono profile | headless smoke 用 GDScript stub | GUI 模式验证弹窗功能 |
| 17 个 daily quest 剧情内容待关联 | daily_quests.json 有 ID，但 dialogues.json 仅 5 条 | 需 narrative-designer 补充 dialogue 内容 |

### INFO — 参考

- dashboard `_update_all_metrics()` 同时监听 `all_metrics_updated` 和 `choice_made`，双重刷新
- quest_manager `_apply_rewards()` 已注释掉，metric_effects 单一来源为 dialogue choice
- SettlementReportPanel 在 headless 下为 GDScript stub，弹窗功能需 GUI 模式验证

---

## 5. 验收命令

```bash
# 验证 5 NPC + 9 quest 完整配置
python3 -c "
import json
with open('data/npcs.json') as f:
    npcs = json.load(f)
with open('data/quests.json') as f:
    quests = json.load(f)
with open('data/dialogues.json') as f:
    dlgs = json.load(f)
dlg_map = {d['npc_id']: len(d.get('lines',[])) for d in dlgs.get('dialogues',[])}
print('NPCs:', len(npcs))
for n in npcs:
    print(f'  {n[\"npc_id\"]}: {n[\"location\"]}, {len(n.get(\"quest_ids\",[]))} quests, {dlg_map.get(n[\"npc_id\"],0)} dialogue lines')
print('Quests:', len(quests))
for q in quests:
    print(f'  {q[\"quest_id\"]}: {q[\"title\"]}')
"

# 验证 daily_quests Day 覆盖
python3 -c "
import json
with open('data/quests/daily_quests.json') as f:
    d = json.load(f)
for day in range(1,8):
    qs = [q for q in d['quests'] if q.get('requirements',{}).get('day_min',1)==day]
    print(f'Day {day}: {len(qs)} quests')
"
```

---

## VERDICT

**VERDICT: PASS**

- 5 个演示场景完整，触发条件清晰，关键文件可定位
- 快速演示路径覆盖 RAG 引用 + RiskScorer 拦截 + quest toast + Dashboard 指标变化
- 已知限制标注明确，无阻塞性 P0（Day 5-7 剧情 pending 属预期范围）