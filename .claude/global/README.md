# `.claude/global/` — источник истины глобального окружения Claude

Это **дом Claude** для глобальной (машинной) конфигурации. Файлы отсюда установщик
[`scripts/install-global.sh`](../../scripts/install-global.sh) раскладывает в `~/.claude/` этого Mac,
чтобы правила/скилы/агенты применялись во **всех** папках, а не только внутри вендоренного проекта.

## Что здесь лежит

| Файл | Куда ставится | Роль |
|------|---------------|------|
| `CLAUDE.md` | `~/.claude/CLAUDE.md` | user-level memory: импортит канонический `CLAUDE.md` репо (протоколы + 17 правил) + точки входа. `__AGENTS_CORE_SRC__` установщик заменяет на абсолютный путь репо. |
| `mcp.json` | merge → `~/.claude.json` `mcpServers` | MCP-сервера (context7/playwright/figma) для локального Claude во всех папках. |

Агенты и скилы **не** дублируются здесь: установщик берёт обёртки из [`.claude/agents/`](../agents)
и [`.claude/skills/`](../skills), переписывая относительный `` `.cursor/…` `` на абсолютный путь репо,
и кладёт в `~/.claude/agents|skills`. Единый контент правил/скилов — в [`.cursor/`](../../.cursor).

## Как обновлять

1. Правишь файлы **здесь** (в репо), не установленную копию в `~/.claude`.
2. Прогоняешь `bash scripts/install-global.sh` — идемпотентно, с бэкапом в `~/.claude/backups/`.
3. Проверяешь `bash scripts/check-parity.sh`.

Парный дом Cursor — [`.cursor/global/`](../../.cursor/global). Оба должны быть синхронны (см. `check-parity.sh`).
