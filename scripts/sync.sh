#!/usr/bin/env bash
#
# sync.sh — вендорит слой agents-core в репозиторий проекта (идемпотентно).
#
# Единственный источник истины: репо agents-core (локальный чекаут или GitHub).
# Кладёт правила/агентов/skills/hooks физически в репо проекта, чтобы облачные
# агенты (Cursor iOS, Claude web) видели их в клоне — без симлинков.
#
# Модель managed/local: каждая управляемая директория несёт свой манифест
# `.managed` (список top-level имён, которыми владеет agents-core). При sync
# удаляются только они — любые файлы, добавленные проектом, сохраняются.
# Так удаления в источнике корректно распространяются, а локальное не теряется.
#
# Usage:
#   bash sync.sh [TARGET_DIR]
#
# Источник agents-core определяется автоматически:
#   1) $AGENTS_CORE_SRC (если указан и валиден)
#   2) локальный дефолт $HOME/agents-core (переопредели через AGENTS_CORE_SRC)
#   3) клон/пул из $AGENTS_CORE_REPO в ~/.cache/agents-core (сценарий облака)
#
# Env:
#   AGENTS_CORE_SRC   путь к локальному чекауту agents-core (приоритетный источник)
#   AGENTS_CORE_REPO  git-URL вашей копии agents-core для облачного клона (напр.
#                     https://github.com/<ваш-логин>/agents-core.git)

set -euo pipefail

CORE_REPO="${AGENTS_CORE_REPO:-}"
LOCAL_DEFAULT="${AGENTS_CORE_SRC:-$HOME/agents-core}"
TARGET_DIR="${1:-$(pwd)}"

# ── resolve source (с наблюдаемостью для облачного сценария) ─────────────────
resolve_source() {
  if [ -n "${AGENTS_CORE_SRC:-}" ] && [ -d "$AGENTS_CORE_SRC/.cursor/rules" ]; then
    echo "$AGENTS_CORE_SRC"; return
  fi
  if [ -d "$LOCAL_DEFAULT/.cursor/rules" ]; then
    echo "$LOCAL_DEFAULT"; return
  fi
  local cache="${HOME}/.cache/agents-core"
  if [ -d "$cache/.git" ]; then
    if ! git -C "$cache" pull --quiet --ff-only >/dev/null 2>&1; then
      echo "  ⚠  не удалось обновить кэш agents-core (сеть?) — использую имеющуюся копию" >&2
    fi
  else
    if [ -z "$CORE_REPO" ]; then
      echo "  ✗  источник agents-core не найден: нет ни AGENTS_CORE_SRC, ни $LOCAL_DEFAULT," >&2
      echo "     а AGENTS_CORE_REPO не задан для облачного клона." >&2
      echo "     Задай AGENTS_CORE_SRC (локальный путь) или AGENTS_CORE_REPO (git-URL твоей копии)." >&2
      return 1
    fi
    mkdir -p "$(dirname "$cache")"
    if ! git clone --quiet --depth 1 "$CORE_REPO" "$cache" >/dev/null 2>&1; then
      echo "  ✗  не удалось клонировать agents-core из $CORE_REPO" >&2
      echo "     проверь сеть и доступ к репо (для приватного нужен токен/креды git)" >&2
      return 1
    fi
  fi
  echo "$cache"
}

SRC="$(resolve_source)" || exit 1
if [ ! -d "$SRC/.cursor/rules" ]; then
  echo "  ✗  не найден источник agents-core (SRC=$SRC)" >&2
  exit 1
fi
SRC="$(cd "$SRC" && pwd)"
TARGET_DIR="$(cd "$TARGET_DIR" && pwd)"

# ── guard: не дать снести чувствительные каталоги ───────────────────────────
case "$TARGET_DIR" in
  "$HOME" | "/" | "")
    echo "  ✗  небезопасный TARGET_DIR='$TARGET_DIR' — отказ" >&2
    exit 1
    ;;
esac
if [ "$SRC" = "$TARGET_DIR" ]; then
  echo "  ✗  target совпадает с источником agents-core — нечего вендорить" >&2
  exit 1
fi

echo ""
echo "  agents-core sync"
echo "  from: $SRC"
echo "  to:   $TARGET_DIR"
echo ""

# ── managed dir: перекопировать top-level entries, трекая их в .managed ─────
# Удаляет только прежде-managed entries (из .managed), сохраняя локальные.
# Обрабатывает и удаление всей папки из источника.
sync_managed_dir() {
  local rel="$1"
  local tdir="$TARGET_DIR/$rel"
  local mf="$tdir/.managed"

  # снять прежние managed entries (обрабатывает удаления в источнике)
  if [ -f "$mf" ]; then
    while IFS= read -r e; do
      [ -n "$e" ] && rm -rf "${tdir:?}/$e"
    done < "$mf"
    rm -f "$mf"
  fi

  if [ ! -d "$SRC/$rel" ]; then
    rmdir "$tdir" 2>/dev/null || true   # источник убрал папку целиком
    return
  fi

  mkdir -p "$tdir"
  : > "$mf"
  local n=0
  for entry in "$SRC/$rel"/*; do
    [ -e "$entry" ] || continue
    local base; base="$(basename "$entry")"
    rm -rf "$tdir/$base"
    cp -R "$entry" "$tdir/"
    printf '%s\n' "$base" >> "$mf"
    n=$((n + 1))
  done
  echo "  ✓  $rel/ (managed: $n)"
}

# управляемый одиночный файл
sync_file() {
  local rel="$1"
  if [ -f "$SRC/$rel" ]; then
    mkdir -p "$(dirname "$TARGET_DIR/$rel")"
    cp "$SRC/$rel" "$TARGET_DIR/$rel"
    echo "  ✓  $rel"
  fi
}

# ── managed dirs (единая модель для всех) ───────────────────────────────────
sync_managed_dir ".cursor/rules"     # 18 .mdc + INDEX.md, флэтом в корне
sync_managed_dir ".cursor/agents"
sync_managed_dir ".cursor/skills"
sync_managed_dir ".claude/agents"
sync_managed_dir ".claude/skills"

# заготовка локальных правил проекта (sync её не трогает — не в .managed)
RULES_LOCAL="$TARGET_DIR/.cursor/rules/local"
if [ ! -d "$RULES_LOCAL" ]; then
  mkdir -p "$RULES_LOCAL"
  cat > "$RULES_LOCAL/README.md" << 'LOCALREADME'
# Локальные правила проекта

Правила только для этого проекта. agents-core их не трогает при sync.

Формат — как у core-правил: `.mdc` с frontmatter (`description`, `alwaysApply`).
Клади сюда `.mdc` и импортируй их в `CLAUDE.md` в блоке project-local.
LOCALREADME
  echo "  ✓  .cursor/rules/local/ (заготовка)"
fi

# ── managed files ───────────────────────────────────────────────────────────
sync_file ".cursor/hooks.json"
sync_file ".cursor/mcp.json"
sync_file ".claude/README.md"
sync_file "AGENTS.md"

# settings.json — вендорим КУРИРУЕМЫЙ baseline, НЕ рабочую копию agents-core
# (в ней личный allowlist/пути — им не место в чужих репозиториях)
if [ -f "$SRC/scripts/templates/settings.baseline.json" ]; then
  mkdir -p "$TARGET_DIR/.claude"
  cp "$SRC/scripts/templates/settings.baseline.json" "$TARGET_DIR/.claude/settings.json"
  echo "  ✓  .claude/settings.json (baseline)"
fi

# .mcp.json — MCP-конфиг для Claude Code (Claude НЕ читает .cursor/mcp.json).
# Вендорим project-scope .mcp.json, чтобы Claude web в клоне получал те же серверы.
# Ключи (CONTEXT7_API_KEY) НЕ здесь — они из env/облачных секретов через ${VAR}.
if [ -f "$SRC/scripts/templates/mcp.json" ]; then
  cp "$SRC/scripts/templates/mcp.json" "$TARGET_DIR/.mcp.json"
  echo "  ✓  .mcp.json (MCP для Claude)"
fi

# ── environment.json: seed если отсутствует (проект его кастомизирует) ──────
# Не managed: проект вписывает сюда установку своих зависимостей для облака.
if [ ! -f "$TARGET_DIR/.cursor/environment.json" ] && [ -f "$SRC/scripts/templates/environment.json" ]; then
  mkdir -p "$TARGET_DIR/.cursor"
  cp "$SRC/scripts/templates/environment.json" "$TARGET_DIR/.cursor/environment.json"
  echo "  ✓  .cursor/environment.json (seed)"
fi

# ── self-copy: проект носит собственный refresh-скрипт ──────────────────────
mkdir -p "$TARGET_DIR/.cursor"
cp "$SRC/scripts/sync.sh" "$TARGET_DIR/.cursor/sync.sh"
chmod +x "$TARGET_DIR/.cursor/sync.sh"
echo "  ✓  .cursor/sync.sh (self-refresh)"

# ── CLAUDE.md: managed-блок сверху + project-local ниже маркера ─────────────
# Распознавание маркера — по стабильному токену (устойчиво к правкам текста).
MARKER_TOKEN="CURSOR-CORE MANAGED"
MARKER_LINE="<!-- ==== CURSOR-CORE MANAGED (выше) | PROJECT-LOCAL (ниже) — sync не трогает ==== -->"
CLAUDE_TGT="$TARGET_DIR/CLAUDE.md"
LOCAL_PART=""
if [ -f "$CLAUDE_TGT" ] && grep -qF "$MARKER_TOKEN" "$CLAUDE_TGT"; then
  LOCAL_PART="$(awk -v t="$MARKER_TOKEN" 'f{print} index($0,t){f=1}' "$CLAUDE_TGT")"
fi
{
  cat "$SRC/CLAUDE.md"
  echo ""
  echo "$MARKER_LINE"
  if [ -n "$LOCAL_PART" ]; then
    printf '%s\n' "$LOCAL_PART"
  else
    echo ""
    echo "## Project-local"
    echo ""
    echo "<!-- Правила и заметки только этого проекта. Импортируй локальные .mdc так:"
    echo "     @.cursor/rules/local/<имя>.mdc -->"
  fi
} > "$CLAUDE_TGT"
echo "  ✓  CLAUDE.md (managed + project-local сохранён)"

# ── манифест версии (пишем только при смене commit — без git-шума) ──────────
CORE_COMMIT="$(git -C "$SRC" rev-parse HEAD 2>/dev/null || echo unknown)"
MANIFEST="$TARGET_DIR/.agents-core.json"
OLD_COMMIT=""
if [ -f "$MANIFEST" ]; then
  OLD_COMMIT="$(grep -o '"commit"[^,]*' "$MANIFEST" | head -1 | sed -E 's/.*"([^"]*)"$/\1/')"
fi
if [ "$OLD_COMMIT" != "$CORE_COMMIT" ]; then
  rule_count="$(grep -c '\.mdc$' "$TARGET_DIR/.cursor/rules/.managed" 2>/dev/null || echo 0)"
  cat > "$MANIFEST" << MANIFEST_JSON
{
  "source": "$CORE_REPO",
  "commit": "$CORE_COMMIT",
  "syncedAt": "$(date '+%Y-%m-%dT%H:%M:%S%z')",
  "rules": $rule_count
}
MANIFEST_JSON
  echo "  ✓  .agents-core.json (commit ${CORE_COMMIT:0:7})"
else
  echo "  •  .agents-core.json без изменений (commit ${CORE_COMMIT:0:7})"
fi

echo ""
echo "  Готово. Слой agents-core вживлён в проект."
echo ""
