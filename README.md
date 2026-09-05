# agents-core

Готовый слой правил, субагентов и skills для **Claude Code**. Ставится один раз — и работает во всех
папках: задача не уходит в один гигантский прогон, а идёт по циклу
**planning → execution → review → refinement → closure**.

Слой ничего не знает про конкретный проект: это операционная дисциплина, а не бизнес-логика.
Внутри — 18 always-on правил, 6 субагентов и 8 skills, из которых главный — `plan-performer`.

---

## Быстрый старт

```bash
git clone <url-этого-репозитория> ~/Dev/agents-core
cd ~/Dev/agents-core
bash scripts/install-global.sh
```

Установщик идемпотентен и делает бэкап в `~/.claude/backups/`. Он:

- генерирует `~/.claude/CLAUDE.md` с импортом слоя (always-on во всех папках);
- кладёт субагентов и skills в `~/.claude/agents` и `~/.claude/skills`;
- вливает MCP-серверы (context7, playwright, figma) в `~/.claude.json`, не трогая остальное.

Перезапусти сессию Claude Code. Проверить, что всё встало:

```bash
bash scripts/check-layer.sh
```

Если ставишь репо в другую папку — передай путь: `AGENTS_CORE_SRC=/путь bash scripts/install-global.sh`.

---

## Как этим пользоваться

Опиши задачу словами — слой сам выберет режим. Полезно знать точки входа:

| Хочешь | Что вызвать |
|--------|-------------|
| Начать новую задачу с нуля | skill `quickstart` — соберёт структуру через `plan-orchestrator` |
| Провести большую задачу по этапам | skill `plan-performer` — этапы, отдельные prompts, review, refinement |
| Разобраться в баге | skill `bug-investigation` — дойти до причины, а не гадать |
| Проверить архитектуру решения | skill `architecture-review` |
| Довести UI-текст до релиза | skill `ux-copy-editor` |
| Подвести итог итерации | skill `release-summary` |
| Создать новый проект со слоем | «создай проект `<имя>` `[repo]`» (правило `project-bootstrap`) |

Субагенты (`plan-orchestrator`, `reviewer`, `refinement-agent`, `epic-master`,
`roadmap-task-analyzer`, `roadmap-task-status`) вызываются слоем сами по ходу цикла.

---

## Что внутри

```
.claude/
  rules/      ← 18 always-on правил: discipline, quality, security, tools, bootstrap, deploy
  agents/     ← субагенты: планирование, review, refinement, статус
  skills/     ← skills: plan-performer, release-summary, bug-investigation и др.
  global/     ← шаблон ~/.claude/CLAUDE.md + MCP для установки на машину
  settings.json ← baseline: SessionStart-хук печатает roadmap/_status.md
CLAUDE.md     ← always-on слой: протоколы сессии + импорт всех правил
.mcp.json     ← MCP: Context7, Playwright, Figma (ключи из env)
scripts/
  install-global.sh    ← поставить слой глобально в ~/.claude
  sync.sh              ← вендорить слой в репо проекта (идемпотентно)
  setup-new-project.sh ← sync + roadmap в существующей папке
  create-project.sh    ← новый проект: папка + git + слой + GitHub-репо + push
  check-layer.sh       ← проверка целостности слоя и отсутствия личных данных
  templates/           ← baseline settings.json, mcp.json, seed-шаблоны деплоя
roadmap/               ← живой артефакт статуса задач
projects.json          ← реестр проектов для Action-пропагации
.github/workflows/     ← propagate.yml: раздача обновлений в проекты (sync-PR)
```

Правила: `planning-first`, `execution-discipline`, `scope-control`, `review-before-done`,
`review-coordinator`, `roadmap-discipline`, `roadmap-maintenance`, `project-bootstrap`,
`engineering-quality`, `product-intent-first`, `ui-ux-baseline`, `admin-vs-user-flow-separation`,
`secrets-protection`, `git-release-discipline`, `deploy-discipline`,
`context7-reference-discipline`, `playwright-discipline`, `figma-discipline`.
Описания — в [.claude/rules/INDEX.md](.claude/rules/INDEX.md).

---

## Проекты на базе слоя

Слой можно не только держать глобально, но и **вживлять в репо проекта** — тогда он работает и у
облачных агентов (Claude Code web), которые видят только клон репо.

```bash
bash scripts/create-project.sh <имя> [<repo>]   # новый проект: папка + git + слой + GitHub
bash scripts/setup-new-project.sh <имя> <путь>  # слой + roadmap в существующей папке
bash .claude/sync.sh .                          # обновить слой в проекте
```

Переменные: `PROJECTS_DIR` (куда класть новые проекты, по умолчанию `~/Projects`),
`GH_OWNER` (владелец репо, по умолчанию логин `gh auth`), `VISIBILITY` (`private`/`public`).

### Архитектура распространения

- **Источник истины:** этот репо — правила, агенты и skills правятся только тут.
- **Раздача:** `sync.sh` кладёт слой физически в репо проекта. GitHub Action `propagate.yml`
  при изменении core открывает sync-PR в каждый проект из `projects.json`
  (нужен секрет `PROPAGATE_TOKEN` — PAT со scope `repo`).
- **managed / local:** managed-файлы принадлежат agents-core и перезаписываются синком; локальное
  (`.claude/rules/local/`, `.claude/settings.local.json`, project-local секция `CLAUDE.md`,
  `roadmap/`, код) sync не трогает.
- **Почему vendored, а не симлинки:** облачные агенты клонируют только репо проекта — симлинк
  на agents-core там мёртв.

---

## Личное и секреты

В репо не должно быть ни личных путей, ни ключей:

- персональный allowlist разрешений и локальные пути — в `.claude/settings.local.json` (в `.gitignore`);
- ключи MCP — из env (`CONTEXT7_API_KEY` и т.п.), в облаке — из секретов окружения;
- `bash scripts/check-layer.sh` отдельным шагом проверяет, что в репо не просочились
  домашние пути, токены и приватные ключи.
