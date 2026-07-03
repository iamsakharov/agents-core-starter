# Claude Code config — карта связки с Cursor

Конфигурация Claude Code зеркалит настройки Cursor из [../.cursor/](../.cursor/).
**Единый источник истины — `.cursor/`.** Claude не дублирует контент, а импортирует / ссылается на оригиналы,
чтобы при изменении правил Cursor поведение Claude обновлялось автоматически (без drift).

## Стратегия по типам сущностей

| Сущность | Cursor | Claude | Способ связки |
|----------|--------|--------|---------------|
| Правила (alwaysApply) | `.cursor/rules/*.mdc` | `../CLAUDE.md` | `@import` каждого правила в CLAUDE.md — нулевое дублирование |
| Хуки поведения | `.cursor/hooks.json` (prompt-хуки) | `../CLAUDE.md` (секции протоколов) | Перенесены как always-on guidance (Claude-хуки — это shell-команды, а не prompt-инъекции) |
| Хук статуса | `.cursor/hooks.json` → sessionStart | `.claude/settings.json` → `SessionStart` | Реальный shell-хук: выводит `roadmap/_status.md` при старте |
| Субагенты | `.cursor/agents/*.md` | `.claude/agents/*.md` | Тонкая обёртка: нативный frontmatter + ссылка на источник |
| Skills | `.cursor/skills/*/SKILL.md` | `.claude/skills/*/SKILL.md` | Тонкая обёртка: нативный frontmatter + ссылка на источник |
| MCP | `.cursor/mcp.json` | `~/.claude.json` (глобально) | Уже настроено глобально, проектный дубль не нужен |

## Почему обёртки, а не копии

Правила импортируются напрямую (`@path`) — Claude поддерживает import в memory-файлах, drift невозможен.

Агенты и skills Claude обязаны быть отдельными файлами (по ним идёт автодискавери и триггер по `description`),
поэтому они сделаны тонкими: локально — только frontmatter-метаданные для триггера, а полный operating prompt
читается из `.cursor/...` первым действием. Так тригеры работают нативно, а поведение остаётся единым с Cursor.

## Соответствие subagent types (Cursor → Claude)

`explore`→`Explore`, `generalPurpose`→`general-purpose`, `shell`→`general-purpose`+Bash,
остальные (`reviewer`, `refinement-agent`, `roadmap-task-analyzer`, `roadmap-task-status`, `epic-master`,
`plan-orchestrator`) — одноимённые. Детали — в [agents/plan-orchestrator.md](agents/plan-orchestrator.md).

## Как поддерживать

Меняешь правило/агента/skill — правишь **только** файл в `.cursor/`. Обёртки трогать нужно лишь если
изменился `description` (триггер), `name` или набор доступных tools. При добавлении нового правила в Cursor —
добавить строку `@import` в `../CLAUDE.md`.
