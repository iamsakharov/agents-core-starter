#!/usr/bin/env bash
#
# install-global.sh — установить слой agents-core в ГЛОБАЛЬНЫЙ профиль Claude Code (~/.claude).
#
# В отличие от sync.sh (вендорит слой в РЕПО ПРОЕКТА для облачных агентов), этот скрипт активирует
# слой ЛОКАЛЬНО во всех папках этой машины через ~/.claude, ссылаясь на репо абсолютным путём.
#
# Источник истины — репо agents-core (.claude/global/ + .claude/agents + .claude/skills).
# Идемпотентно, с бэкапом. Перезапускай после апдейтов репо.
#
# Usage:
#   bash scripts/install-global.sh
#   AGENTS_CORE_SRC=/путь/к/agents-core bash scripts/install-global.sh
#
# Env:
#   AGENTS_CORE_SRC   путь к чекауту agents-core (default: корень этого репо)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC="${AGENTS_CORE_SRC:-$(cd "$SCRIPT_DIR/.." && pwd)}"
DEST="$HOME/.claude"

# ── проверки источника ──────────────────────────────────────────────────────
if [ ! -f "$SRC/.claude/global/CLAUDE.md" ]; then
  echo "  ✗  не найден источник: $SRC/.claude/global/CLAUDE.md" >&2
  echo "     задай AGENTS_CORE_SRC на чекаут agents-core" >&2
  exit 1
fi
SRC="$(cd "$SRC" && pwd)"

echo ""
echo "  agents-core → глобальный профиль Claude Code"
echo "  from: $SRC/.claude  (global, agents, skills)"
echo "  to:   $DEST"
echo ""

mkdir -p "$DEST/agents" "$DEST/skills"

# ── бэкап того, что перезапишем ─────────────────────────────────────────────
TS="$(date '+%Y%m%d-%H%M%S')"
BACKUP="$DEST/backups/pre-agents-core-$TS"
mkdir -p "$BACKUP"
for item in CLAUDE.md agents skills settings.json; do
  [ -e "$DEST/$item" ] && cp -R "$DEST/$item" "$BACKUP/" 2>/dev/null || true
done
[ -f "$HOME/.claude.json" ] && cp "$HOME/.claude.json" "$BACKUP/claude.json" 2>/dev/null || true
echo "  ✓  бэкап → $BACKUP"

# ── 1. ~/.claude/CLAUDE.md из шаблона (подстановка абсолютного пути) ─────────
sed "s#__AGENTS_CORE_SRC__#$SRC#g" "$SRC/.claude/global/CLAUDE.md" > "$DEST/CLAUDE.md"
echo "  ✓  ~/.claude/CLAUDE.md"

# ── 2. агенты и skills (managed-модель) ─────────────────────────────────────
# Манифест .agents-core-managed хранит имена, которыми владеет agents-core —
# так удаления в источнике распространяются, а чужие глобальные агенты/скилы не трогаются.
install_wrappers() {
  local kind="$1"          # agents | skills
  local tdir="$DEST/$kind"
  local mf="$tdir/.agents-core-managed"
  mkdir -p "$tdir"

  # снять прежние managed-записи
  if [ -f "$mf" ]; then
    while IFS= read -r e; do
      [ -n "$e" ] && rm -rf "${tdir:?}/$e"
    done < "$mf"
  fi
  : > "$mf"

  local n=0
  for entry in "$SRC/.claude/$kind"/*; do
    [ -e "$entry" ] || continue
    local base; base="$(basename "$entry")"
    rm -rf "$tdir/$base"
    cp -R "$entry" "$tdir/"
    printf '%s\n' "$base" >> "$mf"
    n=$((n + 1))
  done
  echo "  ✓  ~/.claude/$kind/ (managed: $n)"
}

install_wrappers agents
install_wrappers skills

# ── 3. MCP: merge серверов в ~/.claude.json (user-scope), без потери прочего ─
python3 - "$SRC/.claude/global/mcp.json" "$HOME/.claude.json" << 'PY'
import json, sys, os

mcp_src, target = sys.argv[1], sys.argv[2]

with open(mcp_src, "r") as f:
    servers = json.load(f).get("mcpServers", {})

data = {}
if os.path.exists(target):
    try:
        with open(target, "r") as f:
            data = json.load(f)
    except Exception:
        # не рискуем — если файл нечитаем, оставляем как есть и выходим с сообщением
        sys.stderr.write("  ⚠  ~/.claude.json нечитаем как JSON — MCP не влит, разберись вручную\n")
        sys.exit(0)

data.setdefault("mcpServers", {})
for name, cfg in servers.items():
    data["mcpServers"][name] = cfg

with open(target, "w") as f:
    json.dump(data, f, indent=2, ensure_ascii=False)
    f.write("\n")

print("  ✓  ~/.claude.json mcpServers: " + ", ".join(sorted(servers.keys())))
PY

# ── подсказка про ключ context7 ─────────────────────────────────────────────
if [ -z "${CONTEXT7_API_KEY:-}" ]; then
  echo "  ⚠  CONTEXT7_API_KEY не в env — context7 не заработает, пока не зададите его"
  echo "     (напр. export CONTEXT7_API_KEY=... в ~/.zshrc). playwright/figma работают без ключа."
fi

echo ""
echo "  Готово. Профиль обновлён. Перезапусти сессию Claude Code, чтобы подхватить."
echo "  Проверка слоя: bash \"$SRC/scripts/check-layer.sh\""
echo ""
