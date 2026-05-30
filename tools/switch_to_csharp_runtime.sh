#!/bin/bash
#
# switch_to_csharp_runtime.sh
# 切换到 Profile B：C# 运行时环境
# 幂等设计：marker 区块方案，deterministic rewrite
#
# 执行：cd game/metacampus-godot && ./tools/switch_to_csharp_runtime.sh

set -e

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$PROJECT_ROOT"

echo "=== Profile B: C# Runtime ==="
echo "切换到 C# 运行时环境..."

# ---------- C# autoload list ----------
C_AUTOLOADS="TimeManager ResourceManager SkillManager EventManager SaveManager MetricManager NpcRegistry GameState QuestManager"

# ---------- 1. restore all C# scripts (.cs.bak → .cs) ----------
echo "[1/6] 恢复 C# 脚本：.cs.bak → .cs"
found=0
find scripts/csharp -name '*.cs.bak' -print 2>/dev/null | while read bak; do
    orig="${bak%.bak}"
    mv "$bak" "$orig" 2>/dev/null || true
    echo "  [restore] $(basename "$orig")"
    found=1
done
if [ "$found" = "0" ]; then
    echo "  [ok] no .cs.bak files to restore"
fi

# ---------- 2. update scene script refs: .gd → .cs (only where .cs exists) ----------
echo "[2/6] 更新 scene 引用：.gd → .cs（仅对存在的 .cs 文件）"
updated=0
for gd_file in $(find scripts/csharp -name '*.gd' -print 2>/dev/null); do
    gd_basename=$(basename "$gd_file")
    cs_basename="${gd_basename%.gd}.cs"
    cs_path="scripts/csharp/${cs_basename}"
    if [ -f "$cs_path" ]; then
        count=$(grep -l "path=\"res://${gd_file}\"" scenes/*.tscn 2>/dev/null | wc -l | tr -d ' ')
        if [ "$count" -gt 0 ]; then
            find scenes -name '*.tscn' -exec perl -pi -e \
                "s|path=\"res://${gd_file}\"|path=\"res://${cs_path}\"|g" {} \;
            echo "  [update] $gd_basename → $cs_basename ($count scene(s))"
            updated=1
        fi
    fi
done
if [ "$updated" = "0" ]; then
    echo "  [ok] no scene refs to update"
fi

# ---------- 3. restore Main.tscn from .bak ----------
echo "[3/6] 恢复 Main.tscn → .bak 版本（含 NpcScheduleVisualizer）"
if [ -f "scenes/Main.tscn.bak" ]; then
    cp "scenes/Main.tscn.bak" "scenes/Main.tscn"
    echo "  [restore] scenes/Main.tscn.bak → scenes/Main.tscn"
else
    echo "  [ok] scenes/Main.tscn.bak not found (may already be in C# state)"
fi

# ---------- 4. features: add "C#" ----------
echo "[4/6] project.godot: 添加 C# feature"
if grep -q 'PackedStringArray("4.6", "C#", "GL Compatibility")' project.godot; then
    echo "  [ok] C# already in features"
elif grep -q 'PackedStringArray("4.6", "GL Compatibility")' project.godot; then
    perl -pi -e 's|PackedStringArray\("4\.6", "GL Compatibility"\)|PackedStringArray("4.6", "C#", "GL Compatibility")|g' project.godot
    echo "  [patched] added C# to features"
else
    echo "  [WARN] features line not in expected format"
fi

# ---------- 5. project.godot: marker-block rewrite (csharp = active uncommented autoloads) ----------
echo "[5/6] project.godot: deterministic marker-block rewrite"
python3 - <<'PYEOF'
import sys

marker_start = '; BEGIN PROFILE_MANAGED_AUTOLOADS'
marker_end = '; END PROFILE_MANAGED_AUTOLOADS'

# Note: [autoload] header is NOT inside the managed block — it appears once outside markers.
# The marker block contains ONLY the managed entries (9 active C# autoloads).
managed_autoloads_content = '''TimeManager="*res://scripts/csharp/managers/TimeManager.cs"
ResourceManager="*res://scripts/csharp/managers/ResourceManager.cs"
SkillManager="*res://scripts/csharp/managers/SkillManager.cs"
EventManager="*res://scripts/csharp/managers/EventManager.cs"
SaveManager="*res://scripts/csharp/managers/SaveManager.cs"
MetricManager="*res://scripts/csharp/managers/MetricManager.cs"
NpcRegistry="*res://scripts/csharp/managers/NpcRegistry.cs"
GameState="*res://scripts/csharp/managers/GameState.cs"
QuestManager="*res://scripts/csharp/managers/QuestManager.cs"'''

with open('project.godot', 'r', encoding='utf-8') as f:
    content = f.read()

has_start = marker_start in content
has_end = marker_end in content

if has_start and has_end:
    # Replace the entire block including both markers and their newlines,
    # but NOT the blank line that follows the block (preserved as post-marker spacer).
    import re
    # [\s\S]*? = non-greedy: matches min text needed to find marker_end.
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

# ---------- 6. dotnet build ----------
echo "[6/6] dotnet build"
if [ -f "MetaCampus2D.csproj" ]; then
    set +e
    # Background dotnet build with 60s kill timer (avoid hanging indefinitely)
    DOTNET_PID=""
    dotnet build MetaCampus2D.csproj > /tmp/dotnet_build.log 2>&1 &
    DOTNET_PID=$!
    DOTNET_START=$(date +%s)
    while kill -0 $DOTNET_PID 2>/dev/null; do
        sleep 1
        ELAPSED=$(($(date +%s) - DOTNET_START))
        if [ $ELAPSED -ge 60 ]; then
            kill $DOTNET_PID 2>/dev/null
            wait $DOTNET_PID 2>/dev/null
            echo "  [SKIP] dotnet build timed out after 60s"
            DOTNET_PID=""
            break
        fi
    done
    if [ -n "$DOTNET_PID" ]; then
        wait $DOTNET_PID
        BUILD_EXIT=$?
        set -e
        if [ $BUILD_EXIT -eq 0 ]; then
            echo "  [PASS] dotnet build succeeded"
        else
            echo "  [WARN] dotnet build failed (exit $BUILD_EXIT)"
            tail -30 /tmp/dotnet_build.log
        fi
    fi
    set -e
else
    echo "  [SKIP] MetaCampus2D.csproj not found — run dotnet build manually"
fi

# ---------- verify ----------
echo ""
CS_ACTIVE=$(find scripts/csharp -name '*.cs' ! -name '*.cs.bak' -print 2>/dev/null | wc -l | tr -d ' ')
CS_BAK=$(find scripts/csharp -name '*.cs.bak' -print 2>/dev/null | wc -l | tr -d ' ')
GD_STUBS=$(find scripts/csharp -name '*.gd' -print 2>/dev/null | wc -l | tr -d ' ')
FEATURES=$(grep '^config/features' project.godot 2>/dev/null | tail -1 || echo "(not found)")
C_COMMENTED=$(grep -c '^;[A-Z].*=' project.godot 2>/dev/null | tr -d ' ' || echo "0")
C_ACTIVE=$(for name in $C_AUTOLOADS; do grep -c "^${name}=" project.godot 2>/dev/null; done | awk '{s+=$1}END{print s+0}')
SCENE_CS=$(grep -l 'path="res://scripts/csharp/.*\.cs"' scenes/*.tscn 2>/dev/null | wc -l | tr -d ' ')

echo "  Active C# scripts (.cs):       $CS_ACTIVE"
echo "  Backed up C# scripts (.cs.bak): $CS_BAK"
echo "  GDScript stubs (.gd):          $GD_STUBS"
echo "  config/features:              $FEATURES"
echo "  Active C# autoloads:           $C_ACTIVE"
echo "  Commented autoloads:           $C_COMMENTED"
echo "  Scene .cs refs:                $SCENE_CS"
echo ""
echo "=== Profile B ready ==="
echo ""
echo "建议在 Godot Mono GUI 中打开项目验证："
echo "  /Users/kevinzzz/Applications/Godot_mono.app/Contents/MacOS/Godot --editor"
echo ""
echo "或 headless（需验证 Mono headless 是否仍有问题）："
GODOT_MONO="/Users/kevinzzz/Applications/Godot_mono.app/Contents/MacOS/Godot"
if [ -x "$GODOT_MONO" ]; then
    echo "  $GODOT_MONO --headless --path . --quit"
fi