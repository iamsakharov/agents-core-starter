#!/usr/bin/env bash
#
# install-cursor-global.sh — установить слой agents-core в ГЛОБАЛЬНЫЙ профиль Cursor (~/.cursor).
#
# В отличие от sync.sh (вендорит слой в РЕПО ПРОЕКТА для облачных агентов), этот скрипт активирует
# слой ЛОКАЛЬНО во всех папках этого Mac через ~/.cursor (симлинки на репо + User Rules).
#
# Источник истины — репо agents-core (.cursor/ + .cursor/global/USER-RULES.md).
# Идемпотентно, с бэкапом. Перезапускай после апдейтов репо.
#
# Usage:
#   bash scripts/install-cursor-global.sh
#
# Env:
#   AGENTS_CORE_SRC   путь к чекауту agents-core (по умолчанию — каталог этого репозитория,
#                     определяется автоматически по расположению скрипта)

set -euo pipefail

# по умолчанию источник — корень этого репозитория (scripts/..), без хардкода путей
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SRC="${AGENTS_CORE_SRC:-$REPO_ROOT}"
DEST="$HOME/.cursor"
STATE_DB="$HOME/Library/Application Support/Cursor/User/globalStorage/state.vscdb"

# ── проверки источника ──────────────────────────────────────────────────────
if [ ! -f "$SRC/.cursor/global/USER-RULES.md" ]; then
  echo "  ✗  не найден источник: $SRC/.cursor/global/USER-RULES.md" >&2
  echo "     задай AGENTS_CORE_SRC на чекаут agents-core" >&2
  exit 1
fi
SRC="$(cd "$SRC" && pwd)"

echo ""
echo "  agents-core → глобальный профиль Cursor"
echo "  from: $SRC/.cursor  (+ .cursor/global/USER-RULES.md)"
echo "  to:   $DEST"
echo ""

mkdir -p "$DEST"

# ── бэкап того, что перезапишем ─────────────────────────────────────────────
TS="$(date '+%Y%m%d-%H%M%S')"
BACKUP="$DEST/backups/pre-agents-core-$TS"
mkdir -p "$BACKUP"
for item in agents skills rules mcp.json hooks.json; do
  [ -e "$DEST/$item" ] && cp -RL "$DEST/$item" "$BACKUP/" 2>/dev/null || true
done
[ -f "$STATE_DB" ] && cp "$STATE_DB" "$BACKUP/state.vscdb" 2>/dev/null || true
echo "  ✓  бэкап → $BACKUP"

# ── 1. симлинки на канонический .cursor/ репо ───────────────────────────────
link_item() {
  local name="$1"
  local target="$SRC/.cursor/$name"
  local link="$DEST/$name"

  [ -e "$target" ] || { echo "  ✗  нет источника: $target" >&2; exit 1; }

  if [ -L "$link" ]; then
    rm "$link"
  elif [ -e "$link" ]; then
    rm -rf "$link"
  fi
  ln -s "$target" "$link"
  echo "  ✓  $link → $target"
}

link_item agents
link_item skills
link_item rules
link_item mcp.json
link_item hooks.json

# ── 2. User Rules (компактный always-on слой) ───────────────────────────────
# Cursor хранит UI User Rules в облаке; локально — legacy key aicontext.personalContext
# в state.vscdb (мигрируется в cloud при старте). Параллельно ~/.cursor/rules/ (симлинк)
# даёт полный набор .mdc глобально через file-rules.
python3 - "$SRC/.cursor/global/USER-RULES.md" "$STATE_DB" << 'PY'
import re, sqlite3, sys, os

src_path, db_path = sys.argv[1], sys.argv[2]

with open(src_path, "r", encoding="utf-8") as f:
    raw = f.read()

# Тело правил: после первого --- блока, без финальной служебной секции про вендоринг
body = raw.split("---", 1)[-1].strip()
body = re.sub(
    r"\n\*\*Внутри вендоренного проекта\*\*.*",
    "",
    body,
    flags=re.S,
).strip()

if not os.path.exists(db_path):
    print("  ⚠  state.vscdb не найден — User Rules не записаны (перезапусти Cursor и повтори)")
    sys.exit(0)

conn = sqlite3.connect(db_path)
cur = conn.cursor()
cur.execute(
    "INSERT OR REPLACE INTO ItemTable (key, value) VALUES (?, ?)",
    ("aicontext.personalContext", body),
)
conn.commit()
conn.close()
print("  ✓  User Rules → state.vscdb (aicontext.personalContext)")
print("     перезапусти Cursor, чтобы миграция подхватилась в Settings → Rules → User")
PY

# ── подсказка про ключ context7 ─────────────────────────────────────────────
if [ -z "${CONTEXT7_API_KEY:-}" ]; then
  echo "  ⚠  CONTEXT7_API_KEY не в env — context7 не заработает, пока не зададите его"
  echo "     (напр. export CONTEXT7_API_KEY=... в ~/.zshrc). playwright/figma работают без ключа."
fi

echo ""
echo "  Готово. Глобальный профиль Cursor обновлён."
echo "  Проверка: bash \"$SRC/scripts/check-parity.sh\""
echo "  Верификация вне проекта: открой произвольную папку — rules/skills/agents/MCP из ~/.cursor."
echo ""
