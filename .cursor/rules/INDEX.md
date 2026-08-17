# Rules Index

Краткий индекс всех rules в `.cursor/rules/`. Всего: **18 rules**.

## Execution flow rules

- `planning-first` — структурировать средние и большие задачи перед исполнением.
- `execution-discipline` — выполнять задачи через цикл: понять → сделать → проверить → зафиксировать.
- `scope-control` — держать границы задачи, не допускать скрытого scope creep.
- `review-before-done` — не считать задачу завершённой без review и проверки качества.
- `review-coordinator` — матрица обязательных review слоёв по типу задачи.
- `roadmap-discipline` — связывать большие задачи с roadmap, эпиками, итерациями; итерационная дисциплина.
- `project-bootstrap` — по команде «создай проект» вживить слой agents-core, завести GitHub-репо и roadmap.
- `roadmap-maintenance` — когда и как обновлять файлы в `roadmap/`.

## Quality rules

- `engineering-quality` — предпочитать устойчивые, читаемые и масштабируемые решения.
- `product-intent-first` — учитывать продуктовый смысл, user/admin flow и полезность решения.
- `ui-ux-baseline` — поддерживать базовое UI/UX-качество: иерархия, читаемость, доступность, консистентность.
- `admin-vs-user-flow-separation` — не смешивать admin и user контуры логически и архитектурно.

## Security rules

- `secrets-protection` — жёсткое правило: не читать/не выводить/не отдавать секреты наружу; при чтении — немедленно сообщить и ротировать.

## Release rules

- `git-release-discipline` — после значимой итерации ясный итог, follow-up и явный user approval перед git-операциями.
- `deploy-discipline` — вывод в прод: на сервере по умолчанию read-only (мутации только с согласия), CI/CD, секреты деплоя в GitHub Secrets, PoC до деплоя.

## Tool discipline rules

- `context7-reference-discipline` — подключать Context7 точечно для актуального library/framework reference.
- `playwright-discipline` — использовать Playwright как browser validation layer, не exploration tool.
- `figma-discipline` — использовать Figma как design source-of-truth layer.
