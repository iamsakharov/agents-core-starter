# `.claude/` — карта слоя agents-core

Здесь живёт весь слой целиком: правила, субагенты, skills и настройки Claude Code.
Дублей и обёрток нет — каждый файл является источником истины для своей сущности.

## Состав

| Что | Где | Как подключается |
|-----|-----|------------------|
| Правила (always-on) | `.claude/rules/*.md` | `@import` каждого правила в `../CLAUDE.md` |
| Индекс правил | `.claude/rules/INDEX.md` | справочник, не импортируется |
| Локальные правила проекта | `.claude/rules/local/*.md` | импорт в project-local секции `CLAUDE.md`; sync не трогает |
| Субагенты | `.claude/agents/*.md` | автодискавери по frontmatter (`name`, `description`, `tools`, `model`) |
| Skills | `.claude/skills/*/SKILL.md` | автодискавери по frontmatter (`name`, `description`) |
| Настройки и хуки | `.claude/settings.json` | `SessionStart`-хук печатает `roadmap/_status.md` |
| Личные настройки | `.claude/settings.local.json` | не коммитится: персональный allowlist, локальные пути |
| MCP | `../.mcp.json` | project-scope конфиг: context7, playwright, figma |
| Глобальный профиль | `.claude/global/` | шаблон `~/.claude/CLAUDE.md` + MCP для установки на машину |

## Протоколы поведения

Session / shell / edit / subagent / closure дисциплины живут секциями в `../CLAUDE.md` — как
always-on guidance. Хуки Claude Code — это shell-команды, а не prompt-инъекции, поэтому
поведенческие протоколы задаются текстом слоя, а не `hooks`.

## Модели субагентов

Сильные модели ведут планирование и review, младшие — рутину и статусы:
`plan-orchestrator`, `epic-master`, `roadmap-task-analyzer`, `reviewer` — opus;
`refinement-agent` — sonnet; `roadmap-task-status` — haiku. Детали — [../docs/model-tiering.md](../docs/model-tiering.md).

## Как поддерживать

Меняешь правило, агента или skill — правишь файл здесь, в `agents-core`. В проекты изменения
раздаются синком (`scripts/sync.sh`, GitHub Action). При добавлении нового правила:
положить `.md` в `rules/`, добавить строку `@.claude/rules/<имя>.md` в `../CLAUDE.md` и строку
в `rules/INDEX.md`. Проверка целостности — `bash scripts/check-layer.sh`.
