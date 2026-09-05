# Claude Code — рабочая конфигурация проекта

Этот файл — always-on слой для Claude Code: он грузится в каждой сессии и задаёт operating model
**planning → execution → review → refinement → closure**.

Единый источник истины слоя — папка [.claude/](.claude/): правила, субагенты, skills. Правила
подключаются импортом (`@`), поэтому дублирования нет — правишь файл правила, поведение меняется сразу.

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

## Правила (18) — импорт из `.claude/rules/`

Эти правила действуют всегда.

### Execution flow
@.claude/rules/planning-first.md
@.claude/rules/execution-discipline.md
@.claude/rules/scope-control.md
@.claude/rules/review-before-done.md
@.claude/rules/review-coordinator.md
@.claude/rules/roadmap-discipline.md
@.claude/rules/roadmap-maintenance.md
@.claude/rules/project-bootstrap.md

### Quality
@.claude/rules/engineering-quality.md
@.claude/rules/product-intent-first.md
@.claude/rules/ui-ux-baseline.md
@.claude/rules/admin-vs-user-flow-separation.md

### Security
@.claude/rules/secrets-protection.md

### Release
@.claude/rules/git-release-discipline.md
@.claude/rules/deploy-discipline.md

### Tool discipline
@.claude/rules/context7-reference-discipline.md
@.claude/rules/playwright-discipline.md
@.claude/rules/figma-discipline.md

Индекс правил: [.claude/rules/INDEX.md](.claude/rules/INDEX.md).

---

## Агенты и skills

- Субагенты — в [.claude/agents/](.claude/agents/): планирование, review, refinement, статус эпиков.
- Skills — в [.claude/skills/](.claude/skills/): `plan-performer`, `architecture-review`, `release-summary` и др.

Карта слоя — [.claude/README.md](.claude/README.md).

## MCP

MCP-серверы (context7, playwright, figma) описаны в `.mcp.json` в корне проекта — он вендорится
в каждый проект, чтобы облачные агенты видели конфиг в клоне. Ключи (`CONTEXT7_API_KEY` и т.п.)
в файле не хранятся: они подставляются из env, а в облаке — из секретов окружения.
Дисциплину использования задают правила `*-discipline` выше.

## Распространение слоя (vendored, не симлинки)

Слой agents-core лежит в каждом проекте **физически** (`.claude/` + `CLAUDE.md` + `.mcp.json`) —
это условие работы облачных агентов (Claude Code web), которые видят только клон репо.
Источник истины — репо `agents-core`; раздача — `scripts/sync.sh` + GitHub Action (sync-PR).
Обновить проект вручную: `bash .claude/sync.sh .`. Детали — правило `project-bootstrap`.
