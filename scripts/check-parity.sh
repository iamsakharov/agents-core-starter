#!/usr/bin/env bash
#
# check-parity.sh — проверка синхронности двух окружений (домов) agents-core:
#   .cursor/ (дом Cursor)  ↔  .claude/ (дом Claude)
#
# Проверяет:
#   1. у каждого агента .cursor/agents/*.md есть обёртка .claude/agents/*.md (и наоборот)
#   2. у каждого скила .cursor/skills/*/ есть обёртка .claude/skills/*/SKILL.md (и наоборот)
#   3. каждый .cursor/rules/*.mdc импортирован в CLAUDE.md
#   4. набор MCP-серверов совпадает: .cursor/mcp.json ≡ .claude/global/mcp.json ≡ scripts/templates/mcp.json
#   5. присутствуют оба дома global/: .claude/global и .cursor/global
#
# Код возврата ≠0 при любом расхождении. Запускают оба (Claude и Cursor).

set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
FAIL=0
fail() { echo "  ✗ $1"; FAIL=1; }
ok()   { echo "  ✓ $1"; }

echo ""
echo "  agents-core parity check"
echo "  root: $ROOT"
echo ""

# ── 1. agents ───────────────────────────────────────────────────────────────
echo "  [1] agents (.cursor ↔ .claude)"
for f in .cursor/agents/*.md; do
  [ -e "$f" ] || continue
  b="$(basename "$f")"
  [ -f ".claude/agents/$b" ] || fail "нет обёртки .claude/agents/$b"
done
for f in .claude/agents/*.md; do
  [ -e "$f" ] || continue
  b="$(basename "$f")"
  [ -f ".cursor/agents/$b" ] || fail "лишняя обёртка .claude/agents/$b (нет источника в .cursor)"
done
[ "$FAIL" = 0 ] && ok "агенты синхронны" || true

# ── 2. skills ───────────────────────────────────────────────────────────────
echo "  [2] skills (.cursor ↔ .claude)"
S_FAIL=0
for d in .cursor/skills/*/; do
  [ -e "$d" ] || continue
  n="$(basename "$d")"
  [ -f ".claude/skills/$n/SKILL.md" ] || { fail "нет обёртки .claude/skills/$n/SKILL.md"; S_FAIL=1; }
done
for d in .claude/skills/*/; do
  [ -e "$d" ] || continue
  n="$(basename "$d")"
  [ -d ".cursor/skills/$n" ] || { fail "лишний скил .claude/skills/$n (нет источника в .cursor)"; S_FAIL=1; }
done
[ "$S_FAIL" = 0 ] && ok "скилы синхронны" || true

# ── 3. rules imported in CLAUDE.md ──────────────────────────────────────────
echo "  [3] rules → импорт в CLAUDE.md"
R_FAIL=0
for f in .cursor/rules/*.mdc; do
  [ -e "$f" ] || continue
  b="$(basename "$f")"
  grep -qF "@.cursor/rules/$b" CLAUDE.md || { fail "правило $b не импортировано в CLAUDE.md"; R_FAIL=1; }
done
[ "$R_FAIL" = 0 ] && ok "все правила импортированы" || true

# ── 4. MCP server sets match ────────────────────────────────────────────────
echo "  [4] MCP-сервера (.cursor/mcp.json ≡ .claude/global/mcp.json ≡ templates/mcp.json)"
python3 - << 'PY'
import json, sys
files = {
    "cursor":   ".cursor/mcp.json",
    "claude":   ".claude/global/mcp.json",
    "template": "scripts/templates/mcp.json",
}
sets = {}
ok = True
for k, p in files.items():
    try:
        with open(p) as f:
            sets[k] = set(json.load(f).get("mcpServers", {}).keys())
    except Exception as e:
        print(f"  ✗ не прочитать {p}: {e}")
        ok = False
if ok:
    base = sets["cursor"]
    for k, s in sets.items():
        if s != base:
            print(f"  ✗ набор серверов в {files[k]} отличается: {sorted(s)} vs {sorted(base)}")
            ok = False
    if ok:
        print("  ✓ MCP-сервера совпадают: " + ", ".join(sorted(base)))
sys.exit(0 if ok else 1)
PY
[ $? -eq 0 ] || FAIL=1

# ── 5. both global homes present ────────────────────────────────────────────
echo "  [5] дома global/"
[ -f ".claude/global/CLAUDE.md" ] || fail "нет .claude/global/CLAUDE.md"
[ -f ".cursor/global/USER-RULES.md" ] || fail "нет .cursor/global/USER-RULES.md"
[ "$FAIL" = 0 ] && ok "оба дома global/ на месте" || true

echo ""
if [ "$FAIL" = 0 ]; then
  echo "  ✅ Паритет: окружения синхронны."
else
  echo "  ❌ Есть расхождения (см. ✗ выше)."
fi
echo ""
exit "$FAIL"
