# Настройка облака и секретов

Как включить автоматическую раздачу слоя по проектам и работу MCP у облачных агентов.

---

## 1. Пропагация слоя (Action `propagate.yml`)

Чтобы изменения agents-core сами разъезжались по проектам через sync-PR:

1. Создай fine-grained PAT: **Settings → Developer settings → Personal access tokens →
   Fine-grained tokens → Generate new token**.

   | Поле | Значение |
   |------|----------|
   | Token name | `agents-core-propagate` |
   | Resource owner | твой аккаунт |
   | Repository access | **All repositories** |
   | Contents | Read and write |
   | Pull requests | Read and write |

   **All repositories**, а не список: тогда проекты, созданные позже, попадают под токен
   автоматически — иначе каждый новый репо пришлось бы дописывать в токен руками.
   Прав всего два, так что доступ узкий: ни настроек, ни удаления, ни вебхуков.
   Токен видит только репозитории своего владельца — репо чужих организаций в область
   действия не попадают.

2. Добавь его в секреты репо agents-core под именем `PROPAGATE_TOKEN`:

   ```bash
   gh secret set PROPAGATE_TOKEN --repo <owner>/agents-core
   ```

   Команда спросит значение интерактивно — токен не попадёт в историю shell. Через UI:
   **Settings → Secrets and variables → Actions → New repository secret**.

3. Добавляй проекты в `projects.json` (или создавай через `create-project.sh` — он регистрирует
   сам). После регистрации нового проекта **закоммить и запушь agents-core**, иначе пропагация
   его не увидит.

При push в `main` (изменения в `.claude/**`, `CLAUDE.md`, `AGENTS.md`, `scripts/**`) Action откроет
в каждом проекте PR `agents-core-sync`. Мержишь PR — проект обновлён.

`GITHUB_TOKEN` по умолчанию не может писать в другие репозитории, поэтому PAT обязателен.
Classic-токен со scope `repo` тоже работает, но даёт полный доступ ко всем репозиториям —
для этой задачи избыточно.

**Срок жизни.** У fine-grained токена он ограничен. Когда токен истечёт, пропагация сломается
тихо: job `propagate` упадёт на шаге открытия PR. Проверить — `gh run list -R <owner>/agents-core`.
Обновление: сгенерировать токен заново и повторить `gh secret set`.

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
