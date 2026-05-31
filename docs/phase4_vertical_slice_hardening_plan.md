# Phase 4 — Playable Vertical Slice Hardening

> 版本：v1.0
> 日期：2026-05-30
> 用途：把 Phase 3 交付的各模块整合成一个稳定可演示的 7 天切片

---

## 目标

Phase 4 不加新系统。重点：
- 稳定性（各模块串起来能跑通）
- 可演示性（3 分钟 demo route 可执行）
- 数值节奏（7 天每日任务奖励/惩罚合理）
- 错误恢复（边界条件不崩溃）
- 验收文档（每项检查可追溯）

---

## Phase 4 准入基线

当前已具备：
```
✓ RiskScorer 真实对话接入（smoke 10/10 PASS）
✓ CanarySimulator GDExtension（dylib loadable）
✓ staging evidence bundle（status=passed）
✓ 双轨 Profile 脚本幂等（marker 区块方案）
✓ HUD / Dashboard / QuestBoard / SettlementReportPanel
✓ 7 天内容种子（daily_quests.json 7 天覆盖）
✓ Debug / Calibration panels
✓ docs/demo/demo-route.md（3 分钟演示脚本）
```

---

## 四条 Track 概览

| Track | 目标 | 关键产出 |
|-------|------|---------|
| 4A — 7 天闭环 QA | 全流程可跑通 | `reports/qa/phase4_vertical_slice_report.md` |
| 4B — 任务与风险平衡 | 数值合理 | `data/quests/*.json` balance pass |
| 4C — 演示路径 | 稳定 demo | `docs/demo/vertical_slice_demo_script.md` |
| 4D — 资产与坐标校准 | NPC 就位 | `data/locations.json` + scene cleanup |

---

## Track 4A — 7 天闭环 QA

### 目标

验证从 Day 1 到 Day 7 全流程可跑通，不崩溃、不死锁、可追溯。

### 执行清单

#### A1. Headless Smoke Profile 验证

```bash
cd /Users/kevinzzz/Documents/database/gaokao-agent/game/metacampus-godot

# Profile A 幂等切换
./tools/switch_to_headless_smoke.sh
./tools/verify_profile.sh
# 期望：CONFIRMED: Profile A (Headless Smoke)

# 跑 smoke test（不依赖 C#）
~/Downloads/Godot.app/Contents/MacOS/Godot --headless --script gd_smoke_core.gd 2>&1 | tail -5
# 期望：exit 0，无 FATAL
```

#### A2. C# Runtime Profile 恢复验证

```bash
# Profile B 幂等切换
./tools/switch_to_csharp_runtime.sh
./tools/verify_profile.sh
# 期望：CONFIRMED: Profile B (C# Runtime)

# 验证 dotnet build 通过
dotnet build --nologo 2>&1 | tail -3
# 期望：Build succeeded
```

#### A3. Day 1-7 每日任务可接验证

```bash
# 检查每日任务覆盖
python3 -c "
import json
with open('data/quests/daily_quests.json') as f:
    data = json.load(f)
days = {}
for q in data['quests']:
    req = q.get('requirements', {})
    day = req.get('day_min', 1)
    days.setdefault(day, []).append(q['id'])
for d in range(1, 8):
    count = len(days.get(d, []))
    status = 'OK' if count > 0 else 'MISSING'
    print(f'Day {d}: {count} quests [{status}]')
"
# 期望：Day 1-7 每天至少 1 个 quest
```

#### A4. RiskScorer 高风险触发验证

```bash
# 检查 risk_dialogues.json 覆盖场景
python3 -c "
import json
with open('data/dialogues/risk_dialogues.json') as f:
    data = json.load(f)
scenarios = {d['id']: d.get('expected_risk_level','?') for d in data.get('dialogues', data)}
print('Risk scenarios:', json.dumps(scenarios, indent=2, ensure_ascii=False))
"
# 期望：至少覆盖 high/block 和 critical/block 各一个场景
```

#### A5. CanarySimulator 1%→5% 演示验证

```bash
# 检查 CanarySimulator service 存在
ls scripts/gdscript/canary/canary_simulator_service.gd
# 检查 CanaryConsole scene 存在
ls scenes/canary/CanaryConsole.tscn
# 检查 dylib 存在
ls ../bin/libmetacampus_native.macos.template_debug.framework/libmetacampus_native.macos.template_debug 2>/dev/null && echo "dylib OK"
```

#### A6. SettlementReportPanel 每日弹出验证

```bash
# 检查 settlement report 生成路径
ls reports/daily/ 2>/dev/null || echo "reports/daily/ not found (expected in headless)"
# 检查 quest 完成会触发 panel（代码检查）
grep -n "SettlementReportPanel\|daily_report" scenes/ scripts/gdscript/ -r 2>/dev/null | head -10
```

#### A7. Dashboard 数值一致性验证

```bash
# 检查 Dashboard 更新信号链
grep -n "all_metrics_updated\|choice_made" scripts/gdscript/ui/dashboard.gd 2>/dev/null | head -5
# 检查 metric_effects 单一来源（不重复应用）
grep -c "apply_effects\|_apply_reward\|_apply_penalty" scripts/gdscript/quest/quest_manager.gd 2>/dev/null
# 期望：apply_effects 调用存在，_apply_reward/_apply_penalty 应被注释或移除（防止重复）
```

#### A8. Evidence / Save / QA Report 可追溯

```bash
# 检查 evidence bundle 生成能力
ls Makefile && grep -n "shadow-evidence-bundle" Makefile
# 检查 staging report 存在
ls reports/staging/percentage-canary-1pct-latest.json && python3 -c "import json; d=json.load(open('reports/staging/percentage-canary-1pct-latest.json')); print('status:', d.get('status'))"
```

### 报告模板

```markdown
# Phase 4A — 7 天闭环 QA 报告

## 验收结果

| 检查项 | 结果 | 证据 |
|--------|------|------|
| A1. Headless Profile 切换 | PASS/FAIL | sha256 + verify output |
| A2. C# Runtime 恢复 | PASS/FAIL | dotnet build output |
| A3. Day 1-7 每日任务 | PASS/FAIL | quest count per day |
| A4. RiskScorer 高风险场景 | PASS/FAIL | scenario list |
| A5. CanarySimulator 演示就绪 | PASS/FAIL | dylib + scene existence |
| A6. SettlementReportPanel 触发 | PASS/FAIL | signal chain evidence |
| A7. Dashboard 数值一致 | PASS/FAIL | signal chain evidence |
| A8. Evidence 可追溯 | PASS/FAIL | report existence |

## 遗留问题

- [ ] ...
```

---

## Track 4B — 任务与风险平衡

### 目标

调整任务奖励、风险惩罚、AP/算力消耗，使 7 天节奏合理（Day 1 简单 → Day 7 有挑战）。

### 执行清单

#### B1. 奖励/惩罚数值检查

```bash
# 检查 7 天任务奖励梯度
python3 -c "
import json

with open('data/quests/daily_quests.json') as f:
    data = json.load(f)

# 按 day 分组，统计平均 reward budget
by_day = {}
for q in data['quests']:
    day = q.get('requirements', {}).get('day_min', 1)
    reward = q.get('rewards', {}).get('resources', {}).get('budget', 0)
    by_day.setdefault(day, []).append(reward)

for d in sorted(by_day):
    vals = by_day[d]
    print(f'Day {d}: {len(vals)} quests, avg budget={sum(vals)/len(vals):.0f}, range=[{min(vals)},{max(vals)}]')
"
# 期望：Day 1-2 低奖励，Day 5-7 高奖励（有增长梯度）
```

#### B2. 风险惩罚合理性检查

```bash
# 检查 critical risk 的惩罚是否足够大
python3 -c "
import json

with open('data/dialogues/risk_dialogues.json') as f:
    data = json.load(f)

for d in data.get('dialogues', data):
    level = d.get('expected_risk_level', '?')
    if level in ('high', 'critical'):
        print(f\"{d['id']}: {level} → compliance_delta={d.get('expected_compliance_delta','?')}, parent_trust_delta={d.get('expected_parent_trust_delta','?')}\")
"
# 期望：critical 的 compliance_delta 绝对值 > high
```

#### B3. T8 Canary 惩罚验证

```bash
# 检查 full_release_without_testing 的惩罚
grep -A5 "full_release_without_testing" data/dialogues/main_quests.json 2>/dev/null | head -20
# 检查 T8 Quest 的 fail_condition.action 与 dialogue action 一致
python3 -c "
import json
with open('data/quests/main_quests.json') as f:
    data = json.load(f)
for q in data['quests']:
    if 'canary' in q['id'].lower() or 't8' in q['id'].lower():
        print(f\"Quest: {q['id']}\")
        print(f\"  fail_condition: {q.get('fail_condition', {})}\")
        print(f\"  reward: {q.get('rewards', {})}\")
"
```

#### B4. 指标阈值合理性

```bash
# 检查初始值和危险阈值
grep -n "school_efficiency\|parent_trust\|compliance_safety\|system_stability" data/metrics/metrics.json 2>/dev/null | head -10
# 检查 RiskScorer block penalty（1.5x）和 revise penalty（0.5x）
grep -n "block.*penalty\|1\.5\|revise.*penalty\|0\.5" scripts/gdscript/risk/ -r 2>/dev/null | head -5
```

### 报告模板

```markdown
# Phase 4B — 任务与风险平衡报告

## 奖励梯度

| Day | Quests | Avg Budget | Range | 评估 |
|-----|--------|-----------|-------|------|
| 1   | x      | xx        | [x-x] | OK/TOO_HIGH/TOO_LOW |
| ... | ...    | ...       | ...   | ... |

## 风险惩罚

| Scenario | Level | Compliance Δ | Trust Δ | 评估 |
|----------|-------|-------------|---------|------|
| ...      | ...   | ...         | ...     | OK/INSUFFICIENT/OVERKILL |

## 遗留问题

- [ ] ...
```

---

## Track 4C — 演示路径

### 目标

固定一条 10-15 分钟 demo route，确保可重复执行。

### 执行清单

#### C1. Demo Route 就绪检查

```bash
# 检查 demo-route.md 的依赖是否全部满足
python3 -c "
import json, os

# 1. 检查 NPC assets
npcs = ['parent_representative', 'admissions_director', 'it_operator', 'logistics_manager']
missing = []
for npc in npcs:
    path = f'assets/npcs/{npc}/'
    if not os.path.exists(path):
        missing.append(npc)
        continue
    files = os.listdir(path)
    has_portrait = any('portrait' in f for f in files)
    has_sprite = any('sprite' in f for f in files)
    if not (has_portrait and has_sprite):
        missing.append(f'{npc} (missing portrait/sprite)')

if missing:
    print('MISSING NPC ASSETS:', missing)
else:
    print('NPC assets: OK')
"
# 期望：所有 NPC 资产就位
```

#### C2. Dialogue 文件完整性

```bash
# 检查 demo-route 依赖的 dialogue 文件
python3 -c "
import json
with open('data/dialogues.json') as f:
    data = json.load(f)
required = ['T1_admission_parent', 'T2_risk_parent_guarantee', 'T5_canteen_stats', 'T8_canary_release']
found = {d['id']: True for d in data.get('dialogues', [])}
for r in required:
    status = 'OK' if r in found else 'MISSING'
    print(f'{r}: {status}')
"
```

#### C3. Demo Route 预演（headless）

```bash
# 验证 demo 中关键场景的数据可用
python3 -c "
import json
with open('data/dialogues/risk_dialogues.json') as f:
    data = json.load(f)
for d in data.get('dialogues', data):
    lvl = d.get('expected_risk_level', '?')
    action = d.get('expected_recommended_action', '?')
    print(f\"{d['id']}: {lvl}/{action}\")
"
# 期望：至少 T2 高风险场景存在且 action=block
```

#### C4. 演示路径文档

根据 `docs/demo-route.md` 更新 `docs/demo/vertical_slice_demo_script.md`：

```markdown
# Phase 4C — Vertical Slice Demo Script

## 演示路线（10 分钟版）

### 开场（1 分钟）
- 启动 Godot（非 Mono headless 模式）
- 展示校门场景

### Day 1 任务演示（3 分钟）
1. 移动到 Admission Office
2. 与 parent_representative 对话（T1 知识库回答）
3. 展示 citation 来源
4. Quest 完成 + toast + SettlementReportPanel

### Day 2-3 风险演示（3 分钟）
1. 触发 T2 高风险对话（保证录取）
2. 选择错误分支 → 展示 compliance_safety -20
3. 选择正确分支 → 展示合规保护
4. RiskReviewPanel 触发

### Day 5-7 Canary 演示（2 分钟）
1. 移动到 AI 中枢
2. 打开 CanaryConsole
3. 演示 1%→5% 渐进发布
4. 演示 rollback（如果时间允许）

### 结局（1 分钟）
1. 展示 4 种结局触发条件
2. 展示最终指标 Dashboard
3. 停留 10 秒

## 检查清单

- [ ] Mock Mode 开启
- [ ] 存档在 Day 1 之前
- [ ] 所有 NPC 资产加载正常
- [ ] RiskScorer 响应正确
- [ ] CanaryConsole 可交互
- [ ] Dashboard 数值实时更新
- [ ] SettlementReportPanel 正常弹出
```

### 报告模板

```markdown
# Phase 4C — 演示路径报告

## 路线完整性

| 环节 | NPC/场景 | 对话 ID | 风险场景 | 评估 |
|------|---------|---------|---------|------|
| Day 1 | ... | ... | low | OK/MISSING |
| Day 2-3 | ... | ... | high/critical | OK/MISSING |
| Day 5-7 | ... | ... | T8 canary | OK/MISSING |

## 遗留问题

- [ ] ...
```

---

## Track 4D — 资产与坐标校准

### 目标

NPC 坐标、地图位置、占位 sprite 替换。

### 执行清单

#### D1. NPC 坐标检查

```bash
# 检查 locations.json 中的 NPC 位置
cat data/locations.json 2>/dev/null | python3 -c "
import json, sys
try:
    d = json.load(sys.stdin)
    for loc in d.get('locations', d):
        npcs = loc.get('npcs', [])
        pos = loc.get('position', {})
        print(f\"{loc['id']}: pos={pos}, npcs={npcs}\")
except:
    print('locations.json not found or invalid')
"
```

#### D2. 占位 sprite 替换检查

```bash
# 检查是否还有 placeholder 资源
find assets/npcs -name "*.png" | while read f; do
    size=$(identify "$f" 2>/dev/null | awk '{print $3}')
    if [[ "$size" == "1x1" ]]; then
        echo "PLACEHOLDER: $f"
    fi
done
# 期望：无 1x1 占位符
```

#### D3. Scene 路径一致性

```bash
# 检查 scenes/*.tscn 引用的 script 路径是否正确
grep -h "ext_resource.*path=" scenes/*.tscn 2>/dev/null | grep -v "^#" | head -20
# 检查无 .cs 引用在 headless profile 下（Profile A 应全部是 GDScript）
```

#### D4. animation_spec.json 完整性

```bash
# 检查 NPC 的 animation_spec.json
python3 -c "
import json, os
npcs = os.listdir('assets/npcs/')
for npc in npcs:
    spec = f'assets/npcs/{npc}/animation_spec.json'
    if os.path.exists(spec):
        with open(spec) as f:
            d = json.load(f)
        print(f'{npc}: {list(d.keys())}')
    else:
        print(f'{npc}: animation_spec.json MISSING')
"
```

### 报告模板

```markdown
# Phase 4D — 资产与坐标校准报告

## NPC 坐标

| NPC | Location | Position | Sprite | Portrait | Animation |
|-----|----------|----------|--------|----------|-----------|
| ... | ... | ... | OK/MISSING | OK/MISSING | OK/MISSING |

## 遗留问题

- [ ] ...
```

---

## 整体验收标准

Phase 4 完成后，以下检查必须全部 PASS：

```
4A-A1: headless profile 切换 + smoke exit 0
4A-A2: csharp profile 恢复 + dotnet build exit 0
4A-A3: Day 1-7 每天 ≥ 1 quest 可接
4A-A4: RiskScorer ≥ 1 high/block + ≥ 1 critical/block 场景
4A-A5: CanarySimulator dylib loadable, scene exists
4A-A6: SettlementReportPanel signal chain exists
4A-A7: Dashboard all_metrics_updated signal chain exists
4A-A8: staging 1% report status=passed

4B-B1: Day 1-2 avg reward < Day 5-7 avg reward（梯度合理）
4B-B2: critical compliance_delta 绝对值 > high
4B-B3: T8 fail_condition action 与 dialogue action 一致
4B-B4: 4 个指标阈值已设置

4C-C1: 所有 demo NPC 资产就位（portrait + sprite）
4C-C2: demo 依赖的 dialogue 文件存在
4C-C3: T2 risk dialogue action=block
4C-C4: vertical_slice_demo_script.md 已写入

4D-D1: locations.json NPC 坐标有效
4D-D2: 无 1x1 placeholder sprite
4D-D3: scene refs 不含 .cs（在 headless profile 下）
4D-D4: 所有 NPC 有 animation_spec.json
```

---

## 并行执行建议

4A 和 4B 可并行（互不依赖），4C 依赖 4A 和 4D 的结果，4D 可独立推进。

```
4A ──┐
4B ──┼──→ 4C
4D ──┘
```

---

## 风险项

| 风险 | 可能性 | 影响 | 应对 |
|------|--------|------|------|
| Godot headless 在 CI 环境挂起 | 中 | 高 | 用 Python smoke 脚本替代，参考 Phase 3.6 verify_profile.sh 模式 |
| T8 Quest fail_condition 与 dialogue action 不匹配 | 低 | 中 | 已在 AGENTS.md 中记录，B3 检查会捕获 |
| NPC sprite 缺失导致 scene 加载失败 | 中 | 中 | D2 检查会捕获，缺 sprite 时用 pixel-artist 补 |
| staging evidence report 不是 passed | 低 | 高 | PR-6E-live 阶段手动验证，当前 status 由 Phase 3.4 修复保证 |

---

*本文档为 Phase 4 执行清单，各 Track 完成后请更新对应报告模板。*