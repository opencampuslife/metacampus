#!/bin/bash
#
# verify_profile.sh
# 验证当前 Profile 状态
#
# 执行：cd game/metacampus-godot && ./tools/verify_profile.sh

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$PROJECT_ROOT"

echo "============================================"
echo "  MetaCampus Profile Verification"
echo "============================================"
echo ""

# --- 1. Features ---
FEATURES=$(grep '^config/features' project.godot 2>/dev/null || echo 'config/features=(not found)')
if echo "$FEATURES" | grep -q '"C#"'; then
    PROFILE="B: C# Runtime"
    HAS_CSHARP=true
else
    PROFILE="A: Headless Smoke"
    HAS_CSHARP=false
fi

echo "Profile:  $PROFILE"
echo "Features: $FEATURES"
echo ""

# --- 2. C# script status ---
CS_ACTIVE=$(find scripts/csharp -name '*.cs' ! -name '*.cs.bak' 2>/dev/null | wc -l | tr -d ' ')
CS_BAK=$(find scripts/csharp -name '*.cs.bak' 2>/dev/null | wc -l | tr -d ' ')
GD_STUBS=$(find scripts/csharp -name '*.gd' 2>/dev/null | wc -l | tr -d ' ')

echo "--- Scripts ---"
printf "  C# scripts (.cs active):    %3s\n" "$CS_ACTIVE"
printf "  C# scripts (.cs.bak):       %3s\n" "$CS_BAK"
printf "  GDScript stubs (.gd):       %3s\n" "$GD_STUBS"

# --- 3. Autoloads ---
# Detect profile from marker block state
C_COMMENTED=$(grep -c '^;[A-Z].*=' project.godot 2>/dev/null) || C_COMMENTED=0
C_COMMENTED=${C_COMMENTED:-0}
C_COMMENTED=$(echo "$C_COMMENTED" | tr -d ' \n')

MARKER_START=$(grep -n '; BEGIN PROFILE_MANAGED_AUTOLOADS' project.godot 2>/dev/null | head -1 | cut -d: -f1)
MARKER_END=$(grep -n '; END PROFILE_MANAGED_AUTOLOADS' project.godot 2>/dev/null | head -1 | cut -d: -f1)
if [ -n "$MARKER_START" ] && [ -n "$MARKER_END" ]; then
    MBLOCK=$((MARKER_END - MARKER_START + 1))
else
    MBLOCK=0
fi

echo ""
echo "--- Autoloads ---"
# List all autoloads with status
echo "  Active autoloads:"
grep '^[^;][A-Za-z]*=' project.godot 2>/dev/null | grep -v 'config/' | while read line; do
    echo "    $line"
done

echo ""
echo "  Commented autoloads (C# autoloads disabled): $C_COMMENTED"
if [ "$C_COMMENTED" -gt 0 ]; then
    echo "  Commented entries:"
    grep '^;' project.godot 2>/dev/null | while read line; do
        echo "    $line"
    done
fi

# --- 4. Scene script references ---
SCENE_CS=$(grep -l 'path="res://scripts/csharp/.*\.cs"' scenes/*.tscn 2>/dev/null | wc -l | tr -d ' ')
SCENE_GD=$(grep -l 'path="res://scripts/csharp/.*\.gd"' scenes/*.tscn 2>/dev/null | wc -l | tr -d ' ')

echo ""
echo "--- Scene Script References ---"
printf "  .cs refs in scenes:    %3s\n" "$SCENE_CS"
printf "  .gd refs in scenes:    %3s\n" "$SCENE_GD"

# --- 5. Main.tscn special check ---
if [ -f "scenes/Main.tscn" ]; then
    if grep -q 'NpcScheduleVisualizer' scenes/Main.tscn; then
        echo ""
        echo "--- Main.tscn ---"
        echo "  NpcScheduleVisualizer node: PRESENT (Profile B indicator)"
    fi
fi

# --- 6. Smoke test check ---
echo ""
echo "--- Smoke Readiness ---"
GODOT_BIN="/Applications/Godot.app/Contents/MacOS/Godot"
if [ -x "$GODOT_BIN" ]; then
    echo "  non-Mono Godot: available"
    if [ "$HAS_CSHARP" = "false" ]; then
        echo "  Headless smoke: READY"
        echo ""
        echo "  Run: $GODOT_BIN --headless --path . --quit"
    else
        echo "  Headless smoke: NOT RECOMMENDED (C# profile active)"
    fi
else
    echo "  non-Mono Godot: NOT FOUND at $GODOT_BIN"
fi

GODOT_MONO="/Users/kevinzzz/Applications/Godot_mono.app/Contents/MacOS/Godot"
if [ -x "$GODOT_MONO" ]; then
    echo "  Godot Mono: available"
    if [ "$HAS_CSHARP" = "true" ]; then
        echo "  C# Runtime: READY"
        echo ""
        echo "  Run: $GODOT_MONO --editor"
    else
        echo "  C# Runtime: NOT RECOMMENDED (Headless profile active)"
    fi
else
    echo "  Godot Mono: NOT FOUND"
fi

# --- 7. Summary ---
echo ""
echo "============================================"
echo "  Profile Detection"
echo "============================================"
if [ "$HAS_CSHARP" = "true" ] && [ "$CS_ACTIVE" -ge 8 ] && [ "$C_COMMENTED" -eq 0 ]; then
    echo "  CONFIRMED: Profile B (C# Runtime)"
    echo "  Actions: Use Godot Mono GUI to run the project"
elif [ "$HAS_CSHARP" = "false" ] && [ "$CS_BAK" -ge 8 ] && [ "$C_COMMENTED" -ge 8 ]; then
    echo "  CONFIRMED: Profile A (Headless Smoke)"
    echo "  Actions: Run headless smoke test with non-Mono Godot"
else
    echo "  AMBIGUOUS: state does not match either profile cleanly"
    echo "  C# active=$CS_ACTIVE, bak=$CS_BAK, commented=$C_COMMENTED, has_csharp=$HAS_CSHARP"
    echo "  Consider running switch script to align state."
fi
echo ""
echo "============================================"