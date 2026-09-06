#!/usr/bin/env bash
#
# repo-policy.sh — явно пометить репозиторий как доступный другим и проверить,
# не уехало ли в него личное.
#
# Автопроверки в sync.sh угадывают по владельцу и списку коллабораторов, а это
# всегда отстаёт от реальности: ты можешь знать, что репо завтра уедет клиенту,
# а GitHub об этом ещё не знает. Явная метка снимает угадывание.
#
# Метка локальная: `git config --local agents-core.policy` живёт в .git/config,
# в репозиторий не коммитится, коллеги её не видят.
#
# Usage:
#   bash repo-policy.sh <команда> [dir]
#
#   shared     репо доступен другим → вендоринг слоя запрещён, слой прячется
#              в .git/info/exclude, запускается проверка
#   none       слой сюда не кладём вообще (то же, что shared, но про любые причины)
#   personal   мой единоличный репо → вендоринг разрешён (автопроверки остаются)
#   check      только проверить, ничего не менять
#   status     показать текущую метку
#
# Проверка ничего не удаляет и не коммитит: она печатает находки и команды,
# которыми это чинится. Часть файлов в общем репо может быть не твоей —
# решение, что убирать, остаётся за человеком.
#
# Код возврата: 0 — чисто, 1 — есть находки, 2 — ошибка вызова.

set -uo pipefail

CMD="${1:-check}"
DIR="${2:-$(pwd)}"

case "$CMD" in
  shared|none|personal|check|status) ;;
  -h|--help|help)
    sed -n '2,30p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
    exit 0 ;;
  *)
    echo "Неизвестная команда '$CMD'. Ожидается: shared | none | personal | check | status" >&2
    exit 2 ;;
esac

if ! git -C "$DIR" rev-parse --git-dir >/dev/null 2>&1; then
  echo "  ✗  '$DIR' — не git-репозиторий" >&2
  exit 2
fi
DIR="$(cd "$DIR" && pwd)"

FOUND=0
note()  { echo "  ✗ $1"; FOUND=1; }
ok()    { echo "  ✓ $1"; }
info()  { echo "  • $1"; }

# пути, которые считаются слоем
LAYER_RE='^(\.claude/|\.cursor/|CLAUDE\.md|AGENTS\.md|\.mcp\.json|\.agents-core\.json)'
LAYER_PATHS=(".claude/" ".cursor/" "CLAUDE.md" "AGENTS.md" ".mcp.json" ".agents-core.json")

slug="$(git -C "$DIR" remote get-url origin 2>/dev/null \
        | sed -E 's#\.git$##; s#^.*[:/]([^/:]+/[^/]+)$#\1#')"
owner="${slug%%/*}"

# ── что считать «личным»: выводим из окружения, а не хардкодим ──────────────
patterns=()
if command -v gh >/dev/null 2>&1; then
  if login="$(gh api user --jq .login 2>/dev/null)"; then [ -n "$login" ] && patterns+=("$login"); fi
fi
email="$(git config --global user.email 2>/dev/null || true)"
[ -n "$email" ] && patterns+=("$email")
patterns+=("$HOME" "agents-core")

echo ""
echo "  repo-policy: $DIR"
[ -n "$slug" ] && echo "  origin: $slug" || echo "  origin: нет"

# ── установка метки ─────────────────────────────────────────────────────────
if [ "$CMD" = "shared" ] || [ "$CMD" = "none" ] || [ "$CMD" = "personal" ]; then
  git -C "$DIR" config --local agents-core.policy "$CMD"
  echo "  метка: agents-core.policy = $CMD (локально, не коммитится)"
fi

POLICY="$(git -C "$DIR" config --local --get agents-core.policy 2>/dev/null || true)"

if [ "$CMD" = "status" ]; then
  echo "  метка: ${POLICY:-не задана (решают автопроверки sync.sh)}"
  echo ""
  exit 0
fi

# ── для общих репо: спрятать слой локально, чтобы он не попал в индекс ──────
if [ "$CMD" = "shared" ] || [ "$CMD" = "none" ]; then
  # --absolute-git-dir обязателен: обычный --git-dir отдаёт относительный путь,
  # и с -C он разрешился бы относительно cwd, а не целевого репозитория —
  # правки уехали бы в .git того репо, из которого запущен скрипт
  ex="$(git -C "$DIR" rev-parse --absolute-git-dir)/info/exclude"
  mkdir -p "$(dirname "$ex")"; touch "$ex"
  missing=()
  for p in "${LAYER_PATHS[@]}" ".claude/settings.local.json"; do
    grep -qxF "$p" "$ex" || missing+=("$p")
  done
  if [ "${#missing[@]}" -gt 0 ]; then
    { echo ""; echo "# agents-core: слой не коммитится в этот репозиторий"
      printf '%s\n' "${missing[@]}"; } >> "$ex"
    echo "  ✓ .git/info/exclude (+${#missing[@]}) — локальный ignore, коллегам не виден"
  else
    echo "  • .git/info/exclude уже покрывает слой"
  fi
fi

echo ""
echo "  ── кто имеет доступ ──"
if [ -n "$slug" ] && command -v gh >/dev/null 2>&1; then
  people=""; invited=""
  if out="$(gh api "repos/$slug/collaborators" --jq '.[].login' 2>/dev/null)"; then people="$out"; fi
  if out="$(gh api "repos/$slug/invitations" --jq '.[].invitee.login' 2>/dev/null)"; then invited="$out"; fi
  all="$(printf '%s\n%s\n' "$people" "$invited" | grep -v '^$' | sort -u | tr '\n' ' ' || true)"
  if [ -n "$all" ]; then info "аккаунты с доступом: $all"; else info "список недоступен (нужны права на репозиторий)"; fi
else
  info "нет gh или origin — проверить доступ не могу"
fi

echo ""
echo "  ── слой в текущем состоянии ──"
tracked="$(git -C "$DIR" ls-files | grep -E "$LAYER_RE" || true)"
if [ -n "$tracked" ]; then
  note "файлы слоя закоммичены ($(printf '%s\n' "$tracked" | wc -l | xargs) шт):"
  printf '%s\n' "$tracked" | head -8 | sed 's/^/       /'
  echo "       снять с трекинга (файлы останутся на диске):"
  echo "         git rm -r --cached .claude CLAUDE.md AGENTS.md .mcp.json .agents-core.json"
  echo "       но сначала проверь, нет ли среди них чужих — например .claude/launch.json коллеги"
else
  ok "файлов слоя в индексе нет"
fi

if git -C "$DIR" ls-files --error-unmatch .claude/settings.local.json >/dev/null 2>&1; then
  note ".claude/settings.local.json закоммичен — это личный allowlist"
  echo "       git rm --cached .claude/settings.local.json"
else
  ok "личные настройки Claude не в индексе"
fi

echo ""
echo "  ── личные следы в трекаемых файлах ──"
hits=0
for pat in "${patterns[@]}"; do
  out="$(git -C "$DIR" grep -nIF "$pat" -- . 2>/dev/null | head -3 || true)"
  if [ -n "$out" ]; then
    note "встречается «$pat»:"
    printf '%s\n' "$out" | cut -c1-120 | sed 's/^/       /'
    hits=1
  fi
done
[ "$hits" = 0 ] && ok "личных следов не найдено"

echo ""
echo "  ── история (её видит каждый, у кого есть доступ) ──"
ever="$(git -C "$DIR" log --all --pretty=format: --name-only 2>/dev/null \
        | sort -u | grep -E "$LAYER_RE" || true)"
if [ -n "$ever" ]; then
  note "слой присутствовал в истории ($(printf '%s\n' "$ever" | wc -l | xargs) путей) — удаление файлов сейчас его не спрячет"
  echo "       если репо уходит другим: передавать новый репозиторий с чистой историей"
  echo "       либо переписывать историю (git filter-repo) с force-push и перезаливкой клонов"
else
  ok "слоя в истории не было"
fi

hist=0
for pat in "${patterns[@]}"; do
  c="$(git -C "$DIR" log --all -S"$pat" --oneline 2>/dev/null | wc -l | xargs)"
  if [ "${c:-0}" != "0" ]; then
    note "«$pat» встречается в истории ($c коммитов)"
    hist=1
  fi
done
[ "$hist" = 0 ] && ok "личных следов в истории не найдено"

echo ""
if [ "$FOUND" = 0 ]; then
  echo "  ✅ Чисто: ничего личного в этом репозитории нет."
else
  echo "  ⚠️  Есть находки (см. ✗ выше). Ничего не изменено — решай, что убирать."
fi
echo "  метка: ${POLICY:-не задана (решают автопроверки sync.sh)}"
echo ""
exit "$FOUND"
