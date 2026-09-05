# AGENTS.md — agents-core

Этот проект несёт слой **agents-core**: operating model для Claude Code
(planning → execution → review → refinement → closure). Источник истины слоя — папка `.claude/`.

Ориентируйся по слою перед действием (он always-on; здесь — карта):

- **Правила** — `.claude/rules/*.md` (18 шт, все импортированы в `CLAUDE.md`: дисциплина исполнения,
  качество, security, tools, bootstrap, deploy). Индекс — `.claude/rules/INDEX.md`.
- **Субагенты** — `.claude/agents/*.md` (планирование, review, refinement, статус эпиков).
  Сильные модели ведут планирование и review, младшие — рутину.
- **Skills** — `.claude/skills/*/SKILL.md` (`plan-performer`, `architecture-review`,
  `release-summary`, `bug-investigation` и др.).
- **MCP** — `.mcp.json` (context7, playwright, figma); ключи через `${ENV_VAR}`, не в файле.
- **Статус работы** — `roadmap/_status.md`, эпики — `roadmap/epics/`.

Протоколы сессии (orient → structure → act, shell/edit/subagent/closure дисциплины) — в `CLAUDE.md`.
Не дублируй правила сюда — редактируй их в `.claude/rules/` как единый источник.
В проектах, вживлённых из agents-core, слой обновляется через `bash .claude/sync.sh .`.
