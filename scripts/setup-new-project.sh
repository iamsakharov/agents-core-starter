#!/usr/bin/env bash
#
# setup-new-project.sh — настроить agents-core в СУЩЕСТВУЮЩЕЙ папке проекта.
#
# Вживляет vendored-слой agents-core (через sync.sh) + создаёт roadmap-структуру
# и REFINEMENT-LOG. НЕ создаёт git-репо и не пушит — это делает create-project.sh.
#
# Usage:
#   bash /path/to/_agents-core/scripts/setup-new-project.sh [project-name] [target-dir]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET_DIR="${2:-$(pwd)}"
TARGET_DIR="$(cd "$TARGET_DIR" && pwd)"
PROJECT_NAME="${1:-$(basename "$TARGET_DIR")}"
TODAY="$(date '+%b %d, %Y')"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  agents-core setup: $PROJECT_NAME"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# 1) вживить слой agents-core (правила/агенты/skills/hooks/CLAUDE.md)
bash "$SCRIPT_DIR/sync.sh" "$TARGET_DIR"

# 2) roadmap-структура
if [ -d "$TARGET_DIR/roadmap" ]; then
  echo "  ✓  roadmap/         уже существует"
else
  mkdir -p "$TARGET_DIR/roadmap/epics" "$TARGET_DIR/roadmap/tasks"

  cat > "$TARGET_DIR/roadmap/_index.md" << ROADMAP_INDEX
# Roadmap — $PROJECT_NAME

## Цель проекта
<!-- Опиши главную цель проекта -->

---

## Текущий приоритет
<!-- Что активно прямо сейчас -->

---

## Активные эпики

| Эпик | Файл | Статус | Следующий шаг |
|------|------|--------|----------------|
|      |      |        |                |

## Завершённые эпики

| Эпик | Дата закрытия |
|------|---------------|
|      |               |
ROADMAP_INDEX

  cat > "$TARGET_DIR/roadmap/_status.md" << STATUS
# Текущий статус — $PROJECT_NAME

**Обновлено:** $TODAY

---

## Активно сейчас

| Задача | Эпик | Статус | Итерация |
|--------|------|--------|----------|
|        |      |        |          |

## На review

| Задача | Эпик | Что проверять |
|--------|------|----------------|
| —      | —    | —              |

## В refinement

| Задача | Эпик | Замечания |
|--------|------|-----------|
| —      | —    | —         |

## Заблокировано

| Задача | Эпик | Блокер |
|--------|------|--------|
| —      | —    | —      |
STATUS

  echo "  ✓  roadmap/         создан"
fi

# 3) REFINEMENT-LOG
if [ -f "$TARGET_DIR/REFINEMENT-LOG.md" ]; then
  echo "  ✓  REFINEMENT-LOG   уже существует"
else
  cat > "$TARGET_DIR/REFINEMENT-LOG.md" << 'REFLOG'
# Refinement Log

## Открытые замечания

*(нет открытых замечаний)*

---

## Закрытые refinement циклы

| Задача | Итерация | Дата | Результат |
|--------|----------|------|-----------|
REFLOG
  echo "  ✓  REFINEMENT-LOG.md создан"
fi

# 4) .gitignore — НЕ игнорируем правила (они должны коммититься для облака)
GITIGNORE="$TARGET_DIR/.gitignore"
touch "$GITIGNORE"
add_ignore() { grep -qxF "$1" "$GITIGNORE" 2>/dev/null || echo "$1" >> "$GITIGNORE"; }
add_ignore ".DS_Store"
add_ignore ".cursor/worktrees/"
echo "  ✓  .gitignore       обновлён"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Готово. Опиши задачу — оркестратор её разберёт."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
