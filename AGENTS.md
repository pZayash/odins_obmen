# Агенты

Общие правила и tools — submodule [harness/](harness/README.md).

Специфика этого проекта (префикс, ИБ, платформа) — ниже.

## Проект

- `PROJECT_PREFIX`: `обм_`
- Layout: vanessa (`src/cf`)
- Платформа: ключи `.env` / `.env.example` (`PLATFORM_BUILD`); не дублировать
  `8.x.x.x` в доке
- Версия подсистемы `YYMMDD.XX`: [docs/ai/versioning.md](docs/ai/versioning.md);
  перед коммитом `python tools/bump-version.py` (хук `.githooks`).
  `SKIP_VERSION_BUMP` — только amend, не obm-sync.
  Поставка `.cf`: скилл `dump-distribution-cf` (сначала load ИБ из репо)
- Очередь из КПСР: скилл `obm-sync`, канон [`.obm-sync/readme.md`](.obm-sync/readme.md).
  Коммит только после bump → load в dev-ИБ → дым

## Запрещено

Коммитить файлы kit как обычные файлы проекта. Promote — skill
`harness-promote`.
`openspec init` и `rtk init` не запускать.
