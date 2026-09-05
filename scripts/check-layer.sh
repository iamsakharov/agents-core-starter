#!/usr/bin/env bash
#
# check-layer.sh — проверка целостности слоя agents-core.
#
# Проверяет:
#   1. каждое правило .claude/rules/*.md импортировано в CLAUDE.md (и наоборот)
#   2. у каждого субагента валидный frontmatter, name совпадает с именем файла
#   3. у каждого skill есть SKILL.md с валидным frontmatter, name совпадает с папкой
#   4. набор MCP-серверов совпадает: .mcp.json ≡ .claude/global/mcp.json ≡ templates/mcp.json
#   5. в репо нет личных данных и секретов (пути /Users/<имя>, ключи, токены)
#
# Код возврата ≠0 при любом расхождении.

set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
FAIL=0
fail() { echo "  ✗ $1"; FAIL=1; }
ok()   { echo "  ✓ $1"; }

echo ""
echo "  agents-core layer check"
echo "  root: $ROOT"
echo ""

# ── 1. rules ↔ CLAUDE.md ────────────────────────────────────────────────────
echo "  [1] правила → импорт в CLAUDE.md"
R_FAIL=0
for f in .claude/rules/*.md; do
  [ -e "$f" ] || continue
  b="$(basename "$f")"
  [ "$b" = "INDEX.md" ] && continue
  grep -qF "@.claude/rules/$b" CLAUDE.md || { fail "правило $b не импортировано в CLAUDE.md"; R_FAIL=1; }
done
while IFS= read -r imp; do
  [ -f "$imp" ] || { fail "CLAUDE.md импортирует несуществующее правило: $imp"; R_FAIL=1; }
done < <(grep -oE '@\.claude/rules/[A-Za-z0-9._-]+\.md' CLAUDE.md | sed 's/^@//' | sort -u)
[ "$R_FAIL" = 0 ] && ok "все правила импортированы и существуют" || true

# ── 2. агенты ───────────────────────────────────────────────────────────────
echo "  [2] субагенты (.claude/agents)"
A_FAIL=0
A_N=0
for f in .claude/agents/*.md; do
  [ -e "$f" ] || continue
  A_N=$((A_N + 1))
  b="$(basename "$f" .md)"
  head -1 "$f" | grep -qx -- '---' || { fail "$f: нет frontmatter"; A_FAIL=1; continue; }
  name="$(awk 'NR>1 && /^---$/{exit} /^name:/{sub(/^name:[[:space:]]*/,""); print; exit}' "$f")"
  desc="$(awk 'NR>1 && /^---$/{exit} /^description:/{print "y"; exit}' "$f")"
  [ "$name" = "$b" ] || { fail "$f: name='$name' ≠ имени файла '$b'"; A_FAIL=1; }
  [ -n "$desc" ] || { fail "$f: нет description (агент не будет триггериться)"; A_FAIL=1; }
  body="$(awk 'BEGIN{fm=0} /^---$/{fm++; next} fm>=2{print}' "$f" | tr -d '[:space:]' | wc -c)"
  [ "$body" -gt 200 ] || { fail "$f: тело промпта подозрительно короткое ($body симв.)"; A_FAIL=1; }
done
[ "$A_FAIL" = 0 ] && ok "агенты в порядке ($A_N шт)" || true

# ── 3. skills ───────────────────────────────────────────────────────────────
echo "  [3] skills (.claude/skills)"
S_FAIL=0
S_N=0
for d in .claude/skills/*/; do
  [ -e "$d" ] || continue
  S_N=$((S_N + 1))
  n="$(basename "$d")"
  f="$d/SKILL.md"
  [ -f "$f" ] || { fail "нет $f"; S_FAIL=1; continue; }
  name="$(awk 'NR>1 && /^---$/{exit} /^name:/{sub(/^name:[[:space:]]*/,""); print; exit}' "$f")"
  desc="$(awk 'NR>1 && /^---$/{exit} /^description:/{print "y"; exit}' "$f")"
  [ "$name" = "$n" ] || { fail "$f: name='$name' ≠ имени папки '$n'"; S_FAIL=1; }
  [ -n "$desc" ] || { fail "$f: нет description (skill не будет триггериться)"; S_FAIL=1; }
  body="$(awk 'BEGIN{fm=0} /^---$/{fm++; next} fm>=2{print}' "$f" | tr -d '[:space:]' | wc -c)"
  [ "$body" -gt 200 ] || { fail "$f: тело skill подозрительно короткое ($body симв.)"; S_FAIL=1; }
done
[ "$S_FAIL" = 0 ] && ok "skills в порядке ($S_N шт)" || true

# ── 4. MCP ──────────────────────────────────────────────────────────────────
echo "  [4] MCP-сервера (.mcp.json ≡ .claude/global/mcp.json ≡ templates/mcp.json)"
python3 - << 'PY'
import json, sys
files = {
    "project":  ".mcp.json",
    "global":   ".claude/global/mcp.json",
    "template": "scripts/templates/mcp.json",
}
sets, ok = {}, True
for k, p in files.items():
    try:
        with open(p) as f:
            sets[k] = set(json.load(f).get("mcpServers", {}).keys())
    except Exception as e:
        print(f"  ✗ не прочитать {p}: {e}")
        ok = False
if ok:
    base = sets["project"]
    for k, s in sets.items():
        if s != base:
            print(f"  ✗ набор серверов в {files[k]} отличается: {sorted(s)} vs {sorted(base)}")
            ok = False
    if ok:
        print("  ✓ MCP-сервера совпадают: " + ", ".join(sorted(base)))
sys.exit(0 if ok else 1)
PY
[ $? -eq 0 ] || FAIL=1

# ── 5. личные данные и секреты ──────────────────────────────────────────────
# В приватном репо часть личного лежит намеренно (allowlist, живой roadmap).
# Такие пути перечисляются в `.check-layer-ignore` — по одному pathspec на строку,
# пустые строки и `#`-комментарии игнорируются. В публичном репо файла нет,
# поэтому там скан строгий и покрывает всё.
echo "  [5] личные данные и секреты"
P_FAIL=0
PERSONAL='/Users/[A-Za-z0-9._-]+|/home/[A-Za-z0-9._-]+'
SECRETS='sk-[A-Za-z0-9_-]{16,}|gh[pousr]_[A-Za-z0-9]{20,}|AKIA[0-9A-Z]{12,}|-----BEGIN [A-Z ]*PRIVATE KEY'

EXCLUDES=(':!scripts/check-layer.sh')
if [ -f .check-layer-ignore ]; then
  while IFS= read -r line; do
    line="${line%%#*}"; line="$(echo "$line" | xargs)"
    [ -n "$line" ] && EXCLUDES+=(":!$line")
  done < .check-layer-ignore
  echo "      (исключено по .check-layer-ignore: $(( ${#EXCLUDES[@]} - 1 )) путей)"
fi

if hits="$(git grep -nIE "$PERSONAL" -- . "${EXCLUDES[@]}" 2>/dev/null)" && [ -n "$hits" ]; then
  echo "$hits" | head -10 | sed 's/^/      /'
  fail "найдены захардкоженные домашние пути — вынеси в переменные"
  P_FAIL=1
fi
if hits="$(git grep -nIE "$SECRETS" -- . "${EXCLUDES[@]}" 2>/dev/null)" && [ -n "$hits" ]; then
  echo "$hits" | head -10 | sed 's/^/      /'
  fail "найдены строки, похожие на секреты"
  P_FAIL=1
fi
if git ls-files --error-unmatch .claude/settings.local.json >/dev/null 2>&1; then
  fail ".claude/settings.local.json попал в git — он для личных настроек и не коммитится"
  P_FAIL=1
fi
[ "$P_FAIL" = 0 ] && ok "личных данных и секретов не найдено" || true

echo ""
if [ "$FAIL" = 0 ]; then
  echo "  ✅ Слой целостен."
else
  echo "  ❌ Есть расхождения (см. ✗ выше)."
fi
echo ""
exit "$FAIL"
