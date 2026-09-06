#!/usr/bin/env bash
#
# create-project.sh — создать НОВЫЙ проект: папка + git + слой agents-core + GitHub-репо + push.
#
# Это исполнительная часть workflow «создай проект <имя> <repo>».
#
# Usage:
#   bash create-project.sh <name> [repo]
#
#   name  — имя проекта (папка создаётся как $PROJECTS_DIR/<name>)
#   repo  — GitHub-репо: полный URL, owner/name, или просто name.
#           если владелец не указан → $GH_OWNER
#           если репо уже существует → просто привяжется как origin
#
# Env:
#   PROJECTS_DIR   родитель для новых папок (default: ~/Dev)
#   GH_OWNER       владелец репо по умолчанию (default: логин текущего `gh auth`)
#   VISIBILITY     private|public (default: private)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECTS_DIR="${PROJECTS_DIR:-$HOME/Dev}"
GH_OWNER="${GH_OWNER:-$(gh api user --jq .login 2>/dev/null || true)}"
VISIBILITY="${VISIBILITY:-private}"

NAME="${1:-}"
REPO_ARG="${2:-}"

if [ -z "$NAME" ]; then
  echo "Usage: bash create-project.sh <name> [repo]" >&2
  exit 1
fi

# ── нормализовать repo → owner/name ─────────────────────────────────────────
if [ -z "$GH_OWNER" ] && { [ -z "$REPO_ARG" ] || [[ "$REPO_ARG" != */* ]]; }; then
  echo "  ✗  не определён владелец репо: задай GH_OWNER или укажи repo как owner/name" >&2
  echo "     (обычно достаточно \`gh auth login\`)" >&2
  exit 1
fi

if [ -z "$REPO_ARG" ]; then
  REPO_SLUG="$GH_OWNER/$NAME"
else
  case "$REPO_ARG" in
    https://* | http://*) REPO_SLUG="$(echo "$REPO_ARG" | sed -E 's#https?://[^/]+/##; s#\.git$##')" ;;
    git@*)                REPO_SLUG="$(echo "$REPO_ARG" | sed -E 's#.*:##; s#\.git$##')" ;;
    */*)                  REPO_SLUG="$REPO_ARG" ;;
    *)                    REPO_SLUG="$GH_OWNER/$REPO_ARG" ;;
  esac
fi
# нормализовать к owner/name (отбросить лишние сегменты вида /tree/main)
_owner="$(echo "$REPO_SLUG" | cut -d/ -f1)"
_name="$(echo "$REPO_SLUG" | cut -d/ -f2)"
if [ -z "$_owner" ] || [ -z "$_name" ]; then
  echo "  ✗  не удалось разобрать repo из '$REPO_ARG'" >&2
  exit 1
fi
REPO_SLUG="$_owner/$_name"
REPO_URL="https://github.com/${REPO_SLUG}.git"

# ── guard: не заводить проект со слоем в чужом владельце ────────────────────
# Слой несёт мою операционную модель и ссылки на мою инфраструктуру, поэтому
# вендорится только в мои репозитории. Для чужих и рабочих — слой из ~/.claude,
# в репо ничего не коммитится. Обход — AGENTS_CORE_ALLOW_FOREIGN=1.
ALLOWED_OWNERS="${AGENTS_CORE_ALLOWED_OWNERS:-$GH_OWNER}"
if [ -n "$ALLOWED_OWNERS" ] \
   && ! printf '%s' "$ALLOWED_OWNERS" | tr ',' ' ' | tr ' ' '\n' | grep -qxF "$_owner"; then
  if [ "${AGENTS_CORE_ALLOW_FOREIGN:-}" = "1" ]; then
    echo "  ⚠  владелец '$_owner' не в списке ($ALLOWED_OWNERS) — продолжаю по AGENTS_CORE_ALLOW_FOREIGN=1" >&2
  else
    echo "" >&2
    echo "  ✗  ОТКАЗ: репо '$REPO_SLUG' принадлежит '$_owner', разрешено — ($ALLOWED_OWNERS)" >&2
    echo "     Слой agents-core не вживляется в чужие и рабочие репозитории." >&2
    echo "     Там он работает из ~/.claude, а локальные файлы прячутся" >&2
    echo "     через .git/info/exclude, не через .gitignore репозитория." >&2
    echo "     Осознанный обход: AGENTS_CORE_ALLOW_FOREIGN=1" >&2
    echo "" >&2
    exit 1
  fi
fi

TARGET_DIR="$PROJECTS_DIR/$NAME"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  create-project: $NAME"
echo "  repo:   $REPO_SLUG ($VISIBILITY)"
echo "  path:   $TARGET_DIR"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# ── папка + git init ────────────────────────────────────────────────────────
if [ -d "$TARGET_DIR" ]; then
  echo "  •  папка уже существует — использую её"
else
  mkdir -p "$TARGET_DIR"
  echo "  ✓  папка создана"
fi
cd "$TARGET_DIR"
if [ ! -d .git ]; then
  git init -q
  git symbolic-ref HEAD refs/heads/main
  echo "  ✓  git init (branch main)"
fi

# ── вживить слой agents-core + roadmap ──────────────────────────────────────
bash "$SCRIPT_DIR/setup-new-project.sh" "$NAME" "$TARGET_DIR"

# ── README проекта, если нет ────────────────────────────────────────────────
if [ ! -f README.md ]; then
  cat > README.md << README
# $NAME

Проект на базе слоя **agents-core**.
Общие правила вживлены в \`.claude/rules/\`, локальные — в \`.claude/rules/local/\`.
Статус работы — в \`roadmap/_status.md\`.
README
  echo "  ✓  README.md создан"
fi

# ── initial commit ──────────────────────────────────────────────────────────
git add -A
if git diff --cached --quiet; then
  echo "  •  нет изменений для коммита"
else
  git commit -q -m "chore: bootstrap project from agents-core

Co-Authored-By: Claude <noreply@anthropic.com>"
  echo "  ✓  initial commit"
fi

# ── GitHub-репо ─────────────────────────────────────────────────────────────
if git remote get-url origin >/dev/null 2>&1; then
  echo "  •  origin уже настроен"
elif gh repo view "$REPO_SLUG" >/dev/null 2>&1; then
  git remote add origin "$REPO_URL"
  echo "  ✓  привязан существующий репо $REPO_SLUG"
else
  gh repo create "$REPO_SLUG" --"$VISIBILITY" --source . --remote origin
  echo "  ✓  создан репо $REPO_SLUG ($VISIBILITY)"
fi

# ── push ────────────────────────────────────────────────────────────────────
git push -u origin main
echo "  ✓  push → $REPO_SLUG"

# ── зарегистрировать проект в реестре agents-core (для Action-пропагации) ────
REGISTRY="$SCRIPT_DIR/../projects.json"
if [ -f "$REGISTRY" ] && command -v jq >/dev/null 2>&1; then
  if jq -e --arg r "$REPO_SLUG" '.projects | index($r)' "$REGISTRY" >/dev/null; then
    echo "  •  $REPO_SLUG уже в реестре"
  else
    tmp="$(mktemp)"
    jq --arg r "$REPO_SLUG" '.projects += [$r] | .projects |= unique' "$REGISTRY" > "$tmp" && mv "$tmp" "$REGISTRY"
    echo "  ✓  добавлен в projects.json — закоммить agents-core, чтобы пропагация его подхватила"
  fi
else
  echo "  ⚠  не удалось обновить реестр (нет jq/projects.json) — добавь $REPO_SLUG в projects.json вручную"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Проект готов: $TARGET_DIR"
echo "  Репо:        https://github.com/$REPO_SLUG"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
