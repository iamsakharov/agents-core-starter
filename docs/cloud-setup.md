# Настройка облака и секретов

Как включить автоматическую раздачу слоя по проектам и работу MCP у облачных агентов.

---

## 1. Пропагация слоя (Action `propagate.yml`)

Чтобы изменения agents-core сами разъезжались по проектам через sync-PR:

1. Создай GitHub PAT: **Settings → Developer settings → Tokens**.
   - classic: scope `repo`, либо
   - fine-grained: доступ к целевым репо + права `Contents: write`, `Pull requests: write`.
2. Добавь его в секреты репо agents-core: **Settings → Secrets and variables → Actions →
   New repository secret**, имя `PROPAGATE_TOKEN`.
3. Добавляй проекты в `projects.json` (или создавай через `create-project.sh` — он регистрирует сам).

При push в `main` (изменения в `.claude/**`, `CLAUDE.md`, `AGENTS.md`, `scripts/**`) Action откроет
в каждом проекте PR `agents-core-sync`. Мержишь PR — проект обновлён.

`GITHUB_TOKEN` по умолчанию не может писать в другие репозитории, поэтому PAT обязателен.

---

## 2. Облачные агенты Claude Code (web)

- Облачный агент клонирует **репо проекта** в чистую VM: ни `~/.claude`, ни agents-core там нет.
- Весь слой уже лежит в репо (vendored) → `CLAUDE.md`, `.claude/rules`, агенты и skills
  работают сразу, без дополнительной настройки.
- Поэтому слой вендорится физически, а не симлинком.

---

## 3. Секреты MCP в облаке

`.mcp.json` использует переменные окружения (`CONTEXT7_API_KEY` и т.п.) — значения в файле не
хранятся и с твоего диска в облако **не передаются**. Чтобы MCP-инструменты работали у облачных агентов:

- задай ключи в секретах/переменных облачного окружения Claude Code web;
- без ключа соответствующий MCP-сервер в облаке будет недоступен — правила `*-discipline` это
  учитывают (инструменты используются точечно, а не по умолчанию).

Playwright и figma ключей не требуют (figma — по URL, playwright — через `npx`).

Baseline `.claude/settings.json` содержит `enableAllProjectMcpServers: true`, чтобы Claude
автоматически доверял серверам из `.mcp.json` без ручного подтверждения.

Локально сервера ставятся в `~/.claude.json` установщиком `scripts/install-global.sh`;
`CONTEXT7_API_KEY` должен быть в env (например, `export` в `~/.zshrc`).
