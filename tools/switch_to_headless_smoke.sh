#!/bin/bash
#
# switch_to_headless_smoke.sh
# 切换到 Profile A：非 Mono headless smoke 环境
# 幂等设计：marker 区块方案，deterministic rewrite
#
# 执行：cd game/metacampus-godot && ./tools/switch_to_headless_smoke.sh

set -e

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$PROJECT_ROOT"

echo "=== Profile A: Headless Smoke ==="
echo "切换到非 Mono Godot 测试环境..."

# ---------- 1. backup all C# scripts (.cs → .cs.bak) ----------
echo "[1/6] 备份所有 C# 脚本 → .cs.bak"
found=0
find scripts/csharp -name '*.cs' ! -name '*.cs.bak' -print 2>/dev/null | while read f; do
    mv "$f" "$f.bak" 2>/dev/null || true
    echo "  [backup] $(basename "$f")"
    found=1
done
if [ "$found" = "0" ]; then
    echo "  [ok] no .cs files to backup"
fi

# ---------- 2. restore scenes from .bak ----------
echo "[2/6] 恢复 scenes → .bak 版本（.gd stubs 引用）"
restored=0
for tscn_bak in scenes/*.tscn.bak; do
    if [ -f "$tscn_bak" ]; then
        tscn="${tscn_bak%.bak}"
        cp "$tscn_bak" "$tscn"
        echo "  [restore] $(basename "$tscn")"
        restored=1
    fi
done
if [ "$restored" = "0" ]; then
    echo "  [ok] no .tscn.bak files to restore"
fi

# ---------- 3. update scene script refs: .cs → .gd ----------
echo "[3/6] 更新 scene 引用：.cs → .gd"
cs_refs=$(grep -l 'path="res://scripts/csharp/.*\.cs"' scenes/*.tscn 2>/dev/null || true)
if [ -n "$cs_refs" ]; then
    find scenes -name '*.tscn' -exec perl -pi -e \
        's|path="res://scripts/csharp/(.*)\.cs"|path="res://scripts/csharp/$1.gd"|g' {} \;
    echo "  [updated] scene script refs (.cs → .gd)"
else
    echo "  [ok] no .cs scene refs to update"
fi

# ---------- 4. project.godot: marker-block rewrite (headless = commented C# autoloads) ----------
echo "[4/6] project.godot: deterministic marker-block rewrite"
python3 - <<'PYEOF'
import sys

marker_start = '; BEGIN PROFILE_MANAGED_AUTOLOADS'
marker_end = '; END PROFILE_MANAGED_AUTOLOADS'

# Note: [autoload] header is NOT inside the managed block — it appears once outside markers.
# The marker block contains ONLY the managed entries (9 commented C# autoloads).
managed_autoloads_content = ''';TimeManager="*res://scripts/csharp/managers/TimeManager.cs"
;ResourceManager="*res://scripts/csharp/managers/ResourceManager.cs"
;SkillManager="*res://scripts/csharp/managers/SkillManager.cs"
;EventManager="*res://scripts/csharp/managers/EventManager.cs"
;SaveManager="*res://scripts/csharp/managers/SaveManager.cs"
;MetricManager="*res://scripts/csharp/managers/MetricManager.cs"
;NpcRegistry="*res://scripts/csharp/managers/NpcRegistry.cs"
;GameState="*res://scripts/csharp/managers/GameState.cs"
;QuestManager="*res://scripts/csharp/managers/QuestManager.cs"'''

with open('project.godot', 'r', encoding='utf-8') as f:
    content = f.read()

has_start = marker_start in content
has_end = marker_end in content

if has_start and has_end:
    # Replace the entire block including both markers and their newlines,
    # but NOT the blank line that follows the block (preserved as post-marker spacer).
    import re
    # [\s\S]*? matches any char incl. newlines (non-greedy); \n at end = consume trailing newline.
    pattern = re.escape(marker_start) + r'[\s\S]*?' + re.escape(marker_end) + r'\n'
    replacement = (marker_start + '\n'
                 '[autoload]\n'
                 + managed_autoloads_content + '\n'
                 + marker_end + '\n')
    new_content, count = re.subn(pattern, replacement, content, count=1)
    with open('project.godot', 'w', encoding='utf-8') as f:
        f.write(new_content)
elif not has_start and not has_end:
    # First run: insert marker block after config/icon= line (exact string match)
    marker_block = '\n' + marker_start + '\n[autoload]\n' + managed_autoloads_content + '\n' + marker_end + '\n'
    marker_line = 'config/icon="res://icon.svg"'
    if marker_line in content:
        content = content.replace(marker_line, marker_line + marker_block, 1)
    else:
        sys.exit(1)
    with open('project.godot', 'w', encoding='utf-8') as f:
        f.write(content)
else:
    sys.exit(1)  # corrupted marker state
PYEOF
echo "  [ok] marker block rewritten"

# ---------- 5. features: remove "C#" ----------
echo "[5/6] project.godot: 移除 C# feature"
if grep -q 'PackedStringArray("4.6", "C#", "GL Compatibility")' project.godot; then
    perl -pi -e 's|PackedStringArray\("4\.6", "C#", "GL Compatibility"\)|PackedStringArray("4.6", "GL Compatibility")|g' project.godot
    echo "  [patched] removed C# from features"
else
    echo "  [ok] C# not in features (already headless state)"
fi

# ---------- 6. verify + smoke test ----------
echo "[6/6] 验证切换状态"
CS_ACTIVE=$(find scripts/csharp -name '*.cs' ! -name '*.cs.bak' -print 2>/dev/null | wc -l | tr -d ' ')
CS_BAK=$(find scripts/csharp -name '*.cs.bak' -print 2>/dev/null | wc -l | tr -d ' ')
GD_STUBS=$(find scripts/csharp -name '*.gd' -print 2>/dev/null | wc -l | tr -d ' ')
FEATURES=$(grep '^config/features' project.godot 2>/dev/null | tail -1 || echo "(not found)")
C_COMMENTED=$(grep -c '^;[A-Z].*=' project.godot 2>/dev/null | tr -d ' ' || echo "0")
SCENE_CS=$(grep -l 'path="res://scripts/csharp/.*\.cs"' scenes/*.tscn 2>/dev/null | wc -l | tr -d ' ')

echo ""
echo "  Active C# scripts (.cs):       $CS_ACTIVE"
echo "  Backed up C# scripts (.cs.bak): $CS_BAK"
echo "  GDScript stubs (.gd):          $GD_STUBS"
echo "  config/features:              $FEATURES"
echo "  Commented C# autoloads:       $C_COMMENTED"
echo "  Scene .cs refs remaining:       $SCENE_CS"
echo ""
echo "=== Profile A ready ==="
echo ""

echo "Running headless smoke test..."
GODOT_BIN="/Applications/Godot.app/Contents/MacOS/Godot"
if [ -x "$GODOT_BIN" ]; then
    set +e
    OUTPUT=$("$GODOT_BIN" --headless --path . --quit 2>&1)
    EXIT=$?
    set -e
    if [ $EXIT -eq 0 ]; then
        echo "[PASS] Godot headless loaded successfully"
    else
        echo "[WARN] Godot exit code: $EXIT"
        echo "$OUTPUT" | tail -20
    fi
else
    echo "[SKIP] Godot binary not found at $GODOT_BIN"
fi

echo ""
echo "运行手动 smoke："
echo "  $GODOT_BIN --headless --path . --quit"