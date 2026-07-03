# Настройка облака и секретов

Как включить работу задач из iOS/облака и автоматическую раздачу правил.

---

## 1. Пропагация правил (Action `propagate.yml`)

Чтобы изменения agents-core сами разъезжались по проектам через sync-PR:

1. Создай GitHub PAT: **Settings → Developer settings → Tokens**.
   - classic: scope `repo`, либо
   - fine-grained: доступ к целевым репо + права `Contents: write`, `Pull requests: write`.
2. Добавь его в секреты репо agents-core: **Settings → Secrets and variables → Actions →
   New repository secret**, имя `PROPAGATE_TOKEN`.
3. Добавляй проекты в `projects.json` (или создавай через `create-project.sh` — он регистрирует сам).

При push в `main` (изменения в `.cursor/**`, `.claude/**`, `CLAUDE.md`, `scripts/**`) Action откроет
в каждом проекте PR `agents-core-sync`. Мержишь PR — проект обновлён.

---

## 2. Облачные агенты Cursor (iOS / web)

- Задача из приложения выполняется облачным агентом: он клонирует **репо проекта** в чистую VM.
- Весь слой agents-core уже лежит в репо (vendored) → правила, агенты, skills работают сразу.
- Настройка окружения проекта — `.cursor/environment.json` (создаётся seed'ом, кастомизируй под
  зависимости проекта: `install`, `terminals`, при необходимости `build.dockerfile`).

## 3. Claude Code web

- Аналогично: клонирует репо, читает `CLAUDE.md` + `.claude/` из репо. Отдельной настройки не нужно.
- **MCP для Claude:** Claude Code **не читает** `.cursor/mcp.json` (это конфиг Cursor). Поэтому сервера
  вендорятся отдельно в **`.mcp.json`** в корне проекта (из `scripts/templates/mcp.json`). Baseline
  `.claude/settings.json` содержит `enableAllProjectMcpServers: true`, чтобы Claude автоматически
  доверял этим серверам без ручного подтверждения.

---

## 4. Секреты MCP в облаке

`.cursor/mcp.json` (для Cursor) и `.mcp.json` (для Claude) используют переменные окружения
(`CONTEXT7_API_KEY` и т.п.). В облаке они **не передаются** с твоего диска. Чтобы MCP-инструменты
(Context7 и др.) работали в облачных агентах:

- задай ключи в секретах/переменных облачного окружения Cursor (dashboard облачных агентов) **и**
  Claude Code web (это разные окружения — ключ нужно задать в каждом, где хочешь MCP);
- без ключей соответствующий MCP-сервер в облаке будет недоступен — правила `*-discipline` это
  учитывают (используются точечно).

Playwright и figma по конфигу ключей в env не требуют (figma — по URL, playwright — npx).

Локально (этот Mac) сервера для Claude ставятся в `~/.claude.json` установщиком `scripts/install-global.sh`;
`CONTEXT7_API_KEY` должен быть в env (напр. `export` в `~/.zshrc`).
