# `.claude/global/` — источник истины глобального профиля Claude Code

Здесь лежит то, что ставится в `~/.claude` и делает слой agents-core always-on **во всех папках**
на твоей машине — в отличие от вендоринга, который включает слой внутри конкретного репо проекта.

## Что здесь лежит

| Файл | Роль |
|------|------|
| `CLAUDE.md` | Шаблон `~/.claude/CLAUDE.md`. Плейсхолдер `__AGENTS_CORE_SRC__` подставляется установщиком на абсолютный путь твоего чекаута. |
| `mcp.json` | Набор MCP-серверов, вливаемый в `~/.claude.json` (user scope): context7, playwright, figma. |

## Установка

```bash
AGENTS_CORE_SRC="$(pwd)" bash scripts/install-global.sh
```

Скрипт идемпотентен и делает бэкап в `~/.claude/backups/` перед перезаписью. Он:

1. генерирует `~/.claude/CLAUDE.md` из шаблона с абсолютным путём репо;
2. копирует агентов и skills в `~/.claude/agents` и `~/.claude/skills`
   (managed-модель: чужие глобальные агенты и skills не трогаются);
3. вливает MCP-серверы в `~/.claude.json`, не теряя остальную конфигурацию.

После установки перезапусти сессию Claude Code. Проверка целостности — `bash scripts/check-layer.sh`.

## Локальное против коммитимого

Личное — allowlist разрешений, локальные пути, ключи — живёт в `~/.claude/settings.json` и
`.claude/settings.local.json` проекта. В репо коммитится только нейтральный baseline.
