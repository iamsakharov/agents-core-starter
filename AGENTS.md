# AGENTS.md — agents-core

Этот проект несёт общий слой **agents-core**: единая operating model для Cursor и Claude Code
(planning → execution → review → refinement → closure). Источник истины слоя — папка `.cursor/`.

Ориентируйся по слою перед действием (он already-on; здесь — карта):

- **Правила** — `.cursor/rules/*.mdc` (alwaysApply: дисциплина исполнения, качество, security, tools,
  bootstrap). Индекс — `.cursor/rules/INDEX.md`.
- **Субагенты** — `.cursor/agents/*.md` (планирование, review, refinement, статус). Сильные модели ведут
  планирование/review, младшие — рутину.
- **Skills** — `.cursor/skills/*/SKILL.md` (plan-performer, architecture-review, release-summary и др.).
- **MCP** — `.cursor/mcp.json` (context7, playwright, figma); секреты через `${env:NAME}`.

Тот же набор правил и протоколы сессии для Claude Code продублированы в `CLAUDE.md` (идентичный контент).
Не дублируй правила сюда — редактируй их в `.cursor/` как единый источник. В проектах, вживлённых из
agents-core, слой обновляется через `bash .cursor/sync.sh`.
