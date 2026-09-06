#!/usr/bin/env bash
#
# sync.sh — вендорит слой agents-core в репозиторий проекта (идемпотентно).
#
# Единственный источник истины: репо agents-core (локальный чекаут или git-remote).
# Кладёт правила/агентов/skills физически в репо проекта, чтобы облачные агенты
# (Claude Code web) видели их в клоне — без симлинков.
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
#   2) локальный дефолт ~/Dev/agents-core
#   3) клон/пул $AGENTS_CORE_REPO в ~/.cache/agents-core (сценарий облака)

set -euo pipefail

CORE_REPO="${AGENTS_CORE_REPO:-}"
LOCAL_DEFAULT="${AGENTS_CORE_HOME:-$HOME/Dev/agents-core}"
TARGET_DIR="${1:-$(pwd)}"

# ── resolve source (с наблюдаемостью для облачного сценария) ─────────────────
resolve_source() {
  if [ -n "${AGENTS_CORE_SRC:-}" ] && [ -d "$AGENTS_CORE_SRC/.claude/rules" ]; then
    echo "$AGENTS_CORE_SRC"; return
  fi
  if [ -d "$LOCAL_DEFAULT/.claude/rules" ]; then
    echo "$LOCAL_DEFAULT"; return
  fi
  local cache="${HOME}/.cache/agents-core"
  if [ -d "$cache/.git" ]; then
    if ! git -C "$cache" pull --quiet --ff-only >/dev/null 2>&1; then
      echo "  ⚠  не удалось обновить кэш agents-core (сеть?) — использую имеющуюся копию" >&2
    fi
  elif [ -n "$CORE_REPO" ]; then
    mkdir -p "$(dirname "$cache")"
    if ! git clone --quiet --depth 1 "$CORE_REPO" "$cache" >/dev/null 2>&1; then
      echo "  ✗  не удалось клонировать agents-core из $CORE_REPO" >&2
      echo "     проверь сеть и доступ к репо (для приватного нужен токен/креды git)" >&2
      return 1
    fi
  else
    echo "  ✗  не найден источник agents-core" >&2
    echo "     задай AGENTS_CORE_SRC=/путь/к/чекауту или AGENTS_CORE_REPO=<git-url>" >&2
    return 1
  fi
  echo "$cache"
}

SRC="$(resolve_source)" || exit 1
if [ ! -d "$SRC/.claude/rules" ]; then
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

# ── guard 0: явная метка репозитория (сильнее любых автопроверок) ───────────
# `bash repo-policy.sh shared|none|personal` ставит git config --local
# agents-core.policy. Метка локальная, в репо не коммитится. Она нужна для
# случаев, которые автопроверка увидеть не может: репо ещё мой и без
# коллабораторов, но завтра уезжает клиенту.
# `personal` ничего не ослабляет — автопроверки ниже всё равно отрабатывают.
TARGET_POLICY="$(git -C "$TARGET_DIR" config --local --get agents-core.policy 2>/dev/null || true)"
case "$TARGET_POLICY" in
  shared|none)
    if [ "${AGENTS_CORE_ALLOW_SHARED:-}" = "1" ]; then
      echo "  ⚠  репозиторий помечен как '$TARGET_POLICY' — продолжаю из-за AGENTS_CORE_ALLOW_SHARED=1" >&2
    else
      echo "" >&2
      echo "  ✗  ОТКАЗ: репозиторий помечен как '$TARGET_POLICY' — слой сюда не вендорится" >&2
      echo "" >&2
      echo "     Метку поставили явно: bash repo-policy.sh $TARGET_POLICY" >&2
      echo "     Слой здесь работает из ~/.claude и в git не попадает." >&2
      echo "     Снять метку: bash repo-policy.sh personal" >&2
      echo "     Разово обойти: AGENTS_CORE_ALLOW_SHARED=1 bash sync.sh $TARGET_DIR" >&2
      echo "" >&2
      exit 1
    fi
    ;;
esac

# ── guard: не вендорить слой в чужой репозиторий ────────────────────────────
# Слой — это среда разработчика, а не артефакт репозитория. Вендоринг нужен
# только там, где работают облачные агенты в МОИХ репо. В рабочих, зеркальных
# и чужих репозиториях слой приезжает из ~/.claude и в git не попадает.
#
# Разрешённые владельцы: $AGENTS_CORE_ALLOWED_OWNERS (через пробел/запятую),
# по умолчанию — владелец самого agents-core. Осознанный обход:
# AGENTS_CORE_ALLOW_FOREIGN=1.
owner_of_remote() {
  local url
  url="$(git -C "$1" remote get-url origin 2>/dev/null)" || return 1
  case "$url" in
    *:*/*) printf '%s\n' "$url" | sed -E 's#^.*[:/]([^/:]+)/[^/]+$#\1#' ;;
    *)     return 1 ;;
  esac
}

CORE_OWNER="$(owner_of_remote "$SRC" || true)"
ALLOWED="${AGENTS_CORE_ALLOWED_OWNERS:-$CORE_OWNER}"
TARGET_OWNER="$(owner_of_remote "$TARGET_DIR" || true)"

if [ -z "$TARGET_OWNER" ]; then
  # свежий git init без origin (сценарий create-project) — вендорить можно
  echo "  •  у target ещё нет origin — считаю его новым своим проектом"
elif [ -z "$ALLOWED" ]; then
  echo "  ✗  не удалось определить разрешённых владельцев (у agents-core нет origin)" >&2
  echo "     задай AGENTS_CORE_ALLOWED_OWNERS=<owner> явно" >&2
  exit 1
elif ! printf '%s' "$ALLOWED" | tr ',' ' ' | tr ' ' '\n' | grep -qxF "$TARGET_OWNER"; then
  if [ "${AGENTS_CORE_ALLOW_FOREIGN:-}" = "1" ]; then
    echo "  ⚠  target принадлежит '$TARGET_OWNER', а не ($ALLOWED)" >&2
    echo "     продолжаю только из-за AGENTS_CORE_ALLOW_FOREIGN=1" >&2
  else
    echo "" >&2
    echo "  ✗  ОТКАЗ: репозиторий принадлежит '$TARGET_OWNER', разрешено — ($ALLOWED)" >&2
    echo "" >&2
    echo "     Слой agents-core не вендорится в чужие и рабочие репозитории:" >&2
    echo "     он несёт мою личную операционную модель и ссылки на мою инфраструктуру." >&2
    echo "     В таких репо слой и так работает — он приезжает из ~/.claude" >&2
    echo "     и в git не попадает. Прятать локальные файлы там —" >&2
    echo "     .git/info/exclude, а не .gitignore репозитория." >&2
    echo "" >&2
    echo "     Если вендоринг всё-таки нужен осознанно:" >&2
    echo "       AGENTS_CORE_ALLOW_FOREIGN=1 bash sync.sh $TARGET_DIR" >&2
    echo "" >&2
    exit 1
  fi
fi

# ── guard: не вендорить слой в репозиторий, где работает кто-то ещё ─────────
# Владельца мало: репо может быть моим, но с коллабораторами. В git нет прав
# на уровне файлов — всё, что закоммичено, видно каждому, у кого есть доступ,
# вместе со всей историей. Поэтому в шареные репо слой не кладём: он работает
# из ~/.claude, а локальное прячется через .git/info/exclude.
# Осознанный обход: AGENTS_CORE_ALLOW_SHARED=1.
slug_of_remote() {
  local url
  url="$(git -C "$1" remote get-url origin 2>/dev/null)" || return 1
  printf '%s\n' "$url" | sed -E 's#\.git$##; s#^.*[:/]([^/:]+/[^/]+)$#\1#'
}

TARGET_SLUG="$(slug_of_remote "$TARGET_DIR" || true)"
if [ -n "$TARGET_SLUG" ] && [ "${AGENTS_CORE_ALLOW_SHARED:-}" != "1" ] && command -v gh >/dev/null 2>&1; then
  # при ошибке (нет прав, нет сети) gh печатает тело ошибки в stdout — берём вывод
  # только при нулевом коде возврата, иначе считаем список пустым
  people=""; invited=""
  if out="$(gh api "repos/$TARGET_SLUG/collaborators" --jq '.[].login' 2>/dev/null)"; then people="$out"; fi
  if out="$(gh api "repos/$TARGET_SLUG/invitations" --jq '.[].invitee.login' 2>/dev/null)"; then invited="$out"; fi
  # «другие» — все, кроме владельца репо и меня самого
  gh_me=""; if out="$(gh api user --jq .login 2>/dev/null)"; then gh_me="$out"; fi
  others="$(printf '%s\n%s\n' "$people" "$invited" \
    | grep -v '^$' \
    | grep -vxF "${TARGET_OWNER:-__none__}" \
    | grep -vxF "${gh_me:-__none__}" \
    | sort -u | tr '\n' ' ' || true)"
  if [ -n "$others" ]; then
    echo "" >&2
    echo "  ✗  ОТКАЗ: в репозитории есть другие люди — $others" >&2
    echo "" >&2
    echo "     Слой сюда не вендорится. В git нет прав на уровне файлов:" >&2
    echo "     всё закоммиченное видно каждому, у кого есть доступ, вместе" >&2
    echo "     со всей историей — удалить файлы позже уже не поможет." >&2
    echo "     Слой в этом репо и так работает: он приезжает из ~/.claude." >&2
    echo "     Локальное прятать через .git/info/exclude." >&2
    echo "" >&2
    echo "     Если слой здесь нужен осознанно (общий стандарт команды):" >&2
    echo "       AGENTS_CORE_ALLOW_SHARED=1 bash sync.sh $TARGET_DIR" >&2
    echo "" >&2
    exit 1
  fi
elif [ -n "$TARGET_SLUG" ] && [ "${AGENTS_CORE_ALLOW_SHARED:-}" != "1" ]; then
  echo "  ⚠  нет gh — не проверил, есть ли в репозитории другие люди" >&2
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

# ── managed dirs ────────────────────────────────────────────────────────────
sync_managed_dir ".claude/rules"     # 18 правил + INDEX.md, флэтом
sync_managed_dir ".claude/agents"
sync_managed_dir ".claude/skills"

# заготовка локальных правил проекта (sync её не трогает — не в .managed)
RULES_LOCAL="$TARGET_DIR/.claude/rules/local"
if [ ! -d "$RULES_LOCAL" ]; then
  mkdir -p "$RULES_LOCAL"
  cat > "$RULES_LOCAL/README.md" << 'LOCALREADME'
# Локальные правила проекта

Правила только для этого проекта. agents-core их не трогает при sync.

Формат — как у core-правил: `.md` с frontmatter (`description`).
Клади сюда `.md` и импортируй их в `CLAUDE.md` в блоке project-local.
LOCALREADME
  echo "  ✓  .claude/rules/local/ (заготовка)"
fi

# ── managed files ───────────────────────────────────────────────────────────
sync_file ".claude/README.md"
sync_file "AGENTS.md"

# settings.json — вендорим КУРИРУЕМЫЙ baseline, НЕ рабочую копию agents-core
# (личный allowlist и локальные пути живут в .claude/settings.local.json)
if [ -f "$SRC/scripts/templates/settings.baseline.json" ]; then
  mkdir -p "$TARGET_DIR/.claude"
  cp "$SRC/scripts/templates/settings.baseline.json" "$TARGET_DIR/.claude/settings.json"
  echo "  ✓  .claude/settings.json (baseline)"
fi

# ── .gitignore: гарантировать игнор личных файлов слоя ──────────────────────
# sync прилетает и в репо, вживлённые не через create-project.sh (например,
# по Action-пропагации) — там .gitignore может не знать про settings.local.json,
# и личный allowlist уезжает в git. Дописываем идемпотентно, ничего не переписывая.
ensure_layer_ignores() {
  local gi="$TARGET_DIR/.gitignore"
  local patterns=(".claude/settings.local.json" ".claude/worktrees/")
  local missing=()

  for p in "${patterns[@]}"; do
    if [ ! -f "$gi" ] || ! grep -qxF "$p" "$gi"; then
      missing+=("$p")
    fi
  done

  if [ "${#missing[@]}" -gt 0 ]; then
    { [ -s "$gi" ] && echo ""; echo "# agents-core: личные файлы слоя (не коммитятся)"
      printf '%s\n' "${missing[@]}"; } >> "$gi"
    echo "  ✓  .gitignore (+${#missing[@]}: ${missing[*]})"
  else
    echo "  •  .gitignore уже покрывает личные файлы слоя"
  fi

  # уже закоммиченный settings.local.json игнор не спасёт — предупреждаем явно
  if git -C "$TARGET_DIR" ls-files --error-unmatch .claude/settings.local.json >/dev/null 2>&1; then
    echo "  ⚠  .claude/settings.local.json уже в git — личный allowlist в истории репо" >&2
    echo "     убрать: git rm --cached .claude/settings.local.json && git commit" >&2
  fi
}
ensure_layer_ignores

# .mcp.json — project-scope MCP-конфиг, чтобы Claude Code web в клоне получал те же серверы.
# Ключи (CONTEXT7_API_KEY) НЕ здесь — они из env/облачных секретов через ${VAR}.
if [ -f "$SRC/scripts/templates/mcp.json" ]; then
  cp "$SRC/scripts/templates/mcp.json" "$TARGET_DIR/.mcp.json"
  echo "  ✓  .mcp.json (MCP для Claude)"
fi

# ── self-copy: проект носит собственный refresh-скрипт ──────────────────────
mkdir -p "$TARGET_DIR/.claude"
cp "$SRC/scripts/sync.sh" "$TARGET_DIR/.claude/sync.sh"
chmod +x "$TARGET_DIR/.claude/sync.sh"
echo "  ✓  .claude/sync.sh (self-refresh)"

# ── CLAUDE.md: managed-блок сверху + project-local ниже маркера ─────────────
# Распознавание маркера — по стабильному токену (устойчиво к правкам текста).
MARKER_TOKEN="AGENTS-CORE MANAGED"
# маркер из версии слоя до миграции на Claude-only: распознаём, чтобы не потерять
# project-local секцию в проектах, вживлённых раньше
LEGACY_TOKEN="CURSOR-CORE MANAGED"
MARKER_LINE="<!-- ==== AGENTS-CORE MANAGED (выше) | PROJECT-LOCAL (ниже) — sync не трогает ==== -->"
CLAUDE_TGT="$TARGET_DIR/CLAUDE.md"
LOCAL_PART=""
if [ -f "$CLAUDE_TGT" ]; then
  for token in "$MARKER_TOKEN" "$LEGACY_TOKEN"; do
    if grep -qF "$token" "$CLAUDE_TGT"; then
      LOCAL_PART="$(awk -v t="$token" 'f{print} index($0,t){f=1}' "$CLAUDE_TGT")"
      break
    fi
  done
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
    echo "<!-- Правила и заметки только этого проекта. Импортируй локальные правила так:"
    echo "     @.claude/rules/local/<имя>.md -->"
  fi
} > "$CLAUDE_TGT"
echo "  ✓  CLAUDE.md (managed + project-local сохранён)"

# ── манифест версии (пишем только при смене commit — без git-шума) ──────────
CORE_COMMIT="$(git -C "$SRC" rev-parse HEAD 2>/dev/null || echo unknown)"
CORE_ORIGIN="$(git -C "$SRC" remote get-url origin 2>/dev/null || echo "${CORE_REPO:-local}")"
MANIFEST="$TARGET_DIR/.agents-core.json"
OLD_COMMIT=""
if [ -f "$MANIFEST" ]; then
  OLD_COMMIT="$(grep -o '"commit"[^,]*' "$MANIFEST" | head -1 | sed -E 's/.*"([^"]*)"$/\1/')"
fi
if [ "$OLD_COMMIT" != "$CORE_COMMIT" ]; then
  rule_count="$(grep -c '^[^.].*\.md$' "$TARGET_DIR/.claude/rules/.managed" 2>/dev/null | head -1 || echo 0)"
  rule_count=$(( rule_count > 0 ? rule_count - 1 : 0 ))   # минус INDEX.md
  cat > "$MANIFEST" << MANIFEST_JSON
{
  "source": "$CORE_ORIGIN",
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
