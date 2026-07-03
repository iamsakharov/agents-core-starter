# Claude Code — рабочая конфигурация проекта

Этот файл — always-on слой для Claude Code. Он синхронизирован с настройками Cursor
в [.cursor/](.cursor/) и сделан так, чтобы Claude работал по **тем же правилам**, что и Cursor.

Принцип: **единый источник истины — `.cursor/`.** Правила, агенты и skills не дублируются,
а импортируются / ссылаются на оригиналы. Меняешь правило в Cursor — поведение Claude меняется автоматически.

---

## Session protocol (orient → structure → act)

В начале каждой сессии — сориентироваться до действий. Никогда не инвертируй этот порядок.

1. **Восстановить контекст.** Прочитать [roadmap/_status.md](roadmap/_status.md), если есть. Определить тип сессии: новая задача / продолжение / баг / review / refinement / release / архитектура. Если есть прежний план или контекст итерации — восстановить его до исполнения.
2. **Определить цель сессии.** Что должно быть продвинуто. Что считается done для этого куска. Не работать по инерции.
3. **Структурировать до исполнения.** Есть валидный план — следовать ему. Нет структуры у нетривиальной задачи — сначала создать структуру. Большие задачи декомпозировать, без гигантских one-shot прогонов. Выбрать режим: planning / exploration / implementation / review / refinement / release.
4. **Быстрый risk-check.** Неясный scope, скрытые зависимости, архитектурный риск, риск регрессии, пропущенное требование review.
5. **Закрытие с самого начала.** Каждая сессия сходится к: завершённый кусок / задокументированный блокер / явный следующий шаг / release-ready summary. Не останавливаться в размытом состоянии.

## Shell discipline (objective → risk → scope → run → interpret)

Перед любым shell-действием: нужен ли shell вообще (не решается ли чтением файлов/анализом)? Какова цель и ожидаемый результат? Read-only или мутирующее? Особая осторожность: delete, overwrite, mass edits, git-мутации, миграции, смена прав, установка зависимостей — требуют явного обоснования. После команды — интерпретировать вывод до продолжения. Не запускать команды по инерции.

## Edit discipline (правка ≠ прогресс)

После любой правки файла: что именно изменилось и какого типа. Двигает ли это исходную цель, не уполз ли scope. Не выросла ли сложность зря, не появился ли shortcut, осталась ли поддерживаемость. Затронуты ли соседние файлы / типы / тесты / импорты / конфиг, нет ли half-fixed состояния. Следующий шаг выбирать осознанно, не по инерции. Каждое изменение должно делать систему лучше, а не просто другой.

## Subagent verification (completion ≠ proof)

Когда субагент завершился — не принимать вывод автоматически. Понять, что он реально сделал и что осталось. Отделить заявления от доказательств: «готово» нужно проверить независимо. Проверить соответствие scope. Оценить качество. Явно выбрать маршрут: принять / на review / на refinement / отбросить как слабый результат.

## Closure discipline (stop требует closure)

Перед завершением сессии зафиксировать состояние: как сессия заканчивается (завершено / этап / частично / блокер / нужна следующая итерация / review / refinement). Отделить done от not-done — частичную работу не выдавать за завершённую. Проверить, не остался ли implementation без review. Обновить [roadmap/_status.md](roadmap/_status.md), если есть. Явно зафиксировать следующий шаг.

---

## Правила (alwaysApply) — импорт из `.cursor/rules/`

Эти правила действуют всегда. Источник — Cursor; здесь только импорт.

### Execution flow
@.cursor/rules/planning-first.mdc
@.cursor/rules/execution-discipline.mdc
@.cursor/rules/scope-control.mdc
@.cursor/rules/review-before-done.mdc
@.cursor/rules/review-coordinator.mdc
@.cursor/rules/roadmap-discipline.mdc
@.cursor/rules/roadmap-maintenance.mdc
@.cursor/rules/project-bootstrap.mdc

### Quality
@.cursor/rules/engineering-quality.mdc
@.cursor/rules/product-intent-first.mdc
@.cursor/rules/ui-ux-baseline.mdc
@.cursor/rules/admin-vs-user-flow-separation.mdc

### Security
@.cursor/rules/secrets-protection.mdc

### Release
@.cursor/rules/git-release-discipline.mdc

### Tool discipline
@.cursor/rules/context7-reference-discipline.mdc
@.cursor/rules/playwright-discipline.mdc
@.cursor/rules/figma-discipline.mdc

Индекс правил: [.cursor/rules/INDEX.md](.cursor/rules/INDEX.md).

---

## Агенты и skills

- Субагенты Claude — в [.claude/agents/](.claude/agents/). Каждый — тонкая обёртка, ссылающаяся на свой источник в [.cursor/agents/](.cursor/agents/).
- Skills Claude — в [.claude/skills/](.claude/skills/). Каждый ссылается на свой источник в [.cursor/skills/](.cursor/skills/).

Полная карта связки и соответствие сущностей Cursor ↔ Claude: [.claude/README.md](.claude/README.md).

## MCP

MCP-серверы (context7, playwright, figma) описаны в `.cursor/mcp.json` — он вендорится в каждый проект,
чтобы облачные агенты видели конфиг в клоне. Локально работают и глобальные настройки `~/.claude.json`.
Ключи (`CONTEXT7_API_KEY` и т.п.) в облаке НЕ передаются с диска — их надо задать в секретах облачного
окружения Cursor/Claude. Дисциплину использования задают правила `*-discipline` выше.

## Распространение слоя (vendored, не симлинки)

Слой agents-core лежит в каждом проекте **физически** (правила, агенты, skills, hooks, CLAUDE.md) —
это условие работы облачных агентов (Cursor iOS, Claude web), которые видят только клон репо.
Источник истины — репо `agents-core`; раздача — `scripts/sync.sh` + GitHub Action (sync-PR).
Обновить проект вручную: `bash .cursor/sync.sh .`. Детали — правило `project-bootstrap`.
