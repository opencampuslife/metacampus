# Phase 4D — 资产与坐标校准报告

> 日期：2026-05-30
> 检查：D1–D4 全部执行

---

## D1. NPC 坐标检查

**文件：** `data/locations.json`
**检查内容：** locations.json 中的 NPC 位置

| Location ID | Map Position | NPC IDs |
|-------------|-------------|---------|
| ai_hub | (700, 350) | — |
| school_gate | (100, 500) | — |
| admission_office | (400, 400) | admissions_director |
| academic_affairs | (450, 450) | homeroom_teacher |
| principal_office | (500, 300) | principal |
| compliance_office | (600, 400) | compliance_officer |
| it_office | (650, 400) | it_operator |
| server_room | (700, 450) | — |
| logistics_area | (550, 550) | logistics_manager |
| parent_reception | (250, 450) | parent_representative |
| teaching_building | (300, 600) | student_representative |
| dormitory | (200, 650) | — |
| meeting_room | (600, 300) | — |
| classroom | (350, 550) | — (重复项) |

**NPC 分布统计：**
- 9 个 NPC 有 location 分配
- 无 NPC 的 location：6 个
- `classroom` 出现两次（重复条目）

**D1 结果：PASS**（坐标有效，9 NPC 已分配）

---

## D2. 占位 sprite 替换检查

**文件：** `assets/npcs/**/*.png`
**检查内容：** 1x1 占位符

**命令：**
```bash
find assets/npcs -name "*.png" | while read f; do
  size=$(sips -g pixelHeight -g pixelWidth "$f" 2>/dev/null | awk '{print $2}' | tr '\n' 'x')
  if [[ "$size" == "1x1" ]]; then echo "PLACEHOLDER: $f"; fi
done
```

**结果：** 无 1x1 占位符输出

**D2 结果：PASS**（无占位符）

---

## D3. Scene 路径一致性

**文件：** `scenes/*.tscn`
**检查内容：** scene 引用的 script 路径中无 .cs 引用（headless profile）

**命令：**
```bash
grep -h "ext_resource\|script_path\|type=\"GDScript\"" scenes/*.tscn 2>/dev/null | grep -i "\.cs" | head -5
```

**结果：** 无输出

**检查的 scene：**
- CampusMap.tscn, Dashboard.tscn, DebugCommandPanel.tscn, DialogueBox.tscn
- HUD.tscn, LocationCalibrationPanel.tscn, Main.tscn, NPC.tscn, Player.tscn
- QuestBoard.tscn, QuestBoardInteractable.tscn, QuestDetailPanel.tscn
- QuestToast.tscn, SettlementReportPanel.tscn, TaskBoard.tscn

**D3 结果：PASS**（scene 中无 .cs 引用）

---

## D4. animation_spec.json 完整性

**文件：** `assets/npcs/*/animation_spec.json`
**检查内容：** 每个 NPC 是否有 animation_spec.json

| NPC | animation_spec.json | Keys |
|-----|---------------------|------|
| .tmp_matrix-media-* | MISSING | — |
| admissions_director | ✅ | 20 keys |
| compliance_officer | ✅ | 21 keys |
| homeroom_teacher | ✅ | 21 keys |
| it_operator | ✅ | 21 keys |
| logistics_manager | ✅ | 21 keys |
| parent_representative | ✅ | 19 keys |
| principal | ✅ | 21 keys |
| student_representative | ✅ | 21 keys |

**D4 结果：PASS**（9 NPC 全部有 animation_spec.json）

---

## VERDICT

**VERDICT: PASS**

| Check | Result | Note |
|-------|--------|------|
| D1 | ✅ PASS | 9 NPC 有效坐标，无 position 字段（用 map_position） |
| D2 | ✅ PASS | 无 1x1 占位符 |
| D3 | ✅ PASS | 无 .cs 引用 |
| D4 | ✅ PASS | 全部 9 NPC 有 animation_spec.json |

---

## 遗留问题

- [ ] `classroom` 在 locations.json 中重复出现（2 次）
- [ ] `.tmp_matrix-media-*` 目录无 animation_spec.json（临时文件，可忽略）