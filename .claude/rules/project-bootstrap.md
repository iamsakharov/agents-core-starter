---
description: Как заводить новый проект — по команде «создай проект» вживить слой agents-core, завести GitHub-репо и roadmap
---

# Project Bootstrap

Правило срабатывает, когда пользователь просит создать проект:
«создай проект», «заведи проект», «new project», с указанием имени и (опционально) репо.

## Триггер и разбор

Формат: **«создай проект `<имя>` [`<repo>`]»**.

- `<имя>` — имя проекта (папка `$PROJECTS_DIR/<имя>`, по умолчанию `~/Projects/<имя>`).
- `<repo>` — GitHub-репо: полный URL, `owner/name` или просто `name`.
  Если владелец не указан → `$GH_OWNER` (или owner текущего `gh auth`). Новые репо создаются **private**.

Если имя не задано — уточнить. Репо не задан — применить дефолт и сообщить об этом.

## Что делает создание проекта

Исполнитель — `scripts/create-project.sh` из agents-core. Он:

1. создаёт папку и `git init` (branch `main`);
2. **вживляет весь слой agents-core физически в репо** (`scripts/sync.sh`): правила в
   `.claude/rules/`, агенты и skills, `CLAUDE.md`, `.mcp.json`, `.claude/sync.sh`;
3. заводит `roadmap/` (`_index.md`, `_status.md`, `epics/`, `tasks/`) и `REFINEMENT-LOG.md`;
4. создаёт заготовку локальных правил `.claude/rules/local/`;
5. настраивает **secret-гигиену**: `.gitignore` с секрет-паттернами (`.env`, `*.key`, `*.pem`,
   `id_rsa*`, `*-auth*`) + `.env.example` с именами без значений;
6. initial commit → создаёт/привязывает GitHub-репо (`gh`) → `push`;
7. регистрирует проект в `projects.json` agents-core (для Action-пропагации).

## Secret-гигиена с первого коммита

Секреты дешевле не пустить в репо, чем потом вычищать из истории. При заведении проекта:

- реальные значения — только в `.env` (в `.gitignore`), в репо коммитится `.env.example` с именами;
- SSH-ключи живут в `~/.ssh`, **никогда** в репозитории проекта;
- секреты для CI/деплоя — в GitHub Secrets, не в файлах;
- личные allowlist'ы и локальные пути — в `.claude/settings.local.json` (он в `.gitignore`),
  а не в коммитимом `.claude/settings.json`;
- перед первым `push` убедиться, что в индексе нет `.env`, ключей и дампов конфигов.

Паттерны игнора должны быть точечными: слой `.claude/` обязан коммититься — без него облачные
агенты останутся без правил. Дополняет правило `secrets-protection` (оно про «не читать и не
светить» секреты, это — про «не пустить их в git»).

## Почему именно так (не симлинки)

Слой лежит в репо проекта **физически, а не симлинком**. Это обязательное условие для облачных
агентов (Claude Code web): они клонируют только репо проекта в чистую VM, где нет ни agents-core,
ни `~/.claude`. Симлинк там мёртв — правила бы не загрузились.

## Модель managed / local

- **managed** (владеет agents-core, перезаписывается синком): `.claude/rules/*.md`,
  `.claude/agents/`, `.claude/skills/`, `.claude/settings.json` (baseline), `.mcp.json`,
  managed-часть `CLAUDE.md`, `AGENTS.md`.
- **local** (проектное, sync не трогает): `.claude/rules/local/`, `.claude/settings.local.json`,
  project-local секция `CLAUDE.md` ниже маркера, `roadmap/`, `REFINEMENT-LOG.md`, код проекта.

Локальные правила проекта — только в `.claude/rules/local/`, импорт — в project-local секции
`CLAUDE.md`.

## После создания

- зафиксировать цель проекта в `roadmap/_index.md` и первый статус в `roadmap/_status.md`;
- если реестр `projects.json` изменился — **закоммитить и запушить agents-core**, иначе пропагация
  не подхватит новый проект (git-мутация agents-core — с явного согласия пользователя);
- дальше работать по обычному циклу: planning → execution → review → refinement → closure.

## Обновление правил в существующем проекте

Раздача из agents-core идёт автоматически (GitHub Action → sync-PR). Вручную обновить проект:

```bash
bash .claude/sync.sh .
```
