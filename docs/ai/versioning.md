# Версия подсистемы

Формат: `YYMMDD.XX`.

## Формат

`YYMMDD.XX`

| Часть | Смысл |
| --- | --- |
| `YY` | год |
| `MM` | месяц |
| `DD` | день |
| `XX` | порядковый номер правки **за этот день**, с `01` |

Правила номера:

- новая календарная дата → `XX = 01`
- ещё коммит в тот же день → инкремент `XX`
- было `260209.01`, сегодня 2026-08-27 → `260827.01`
- было `260827.01`, ещё коммит сегодня → `260827.02`

## Где лежит

Одно место: [`src/cf/Configuration.xml`](src/cf/Configuration.xml) → `<Version>`.

После загрузки в ИБ это `Метаданные.Версия` (уходит в пакеты обмена как
`обОтправителе.Версия`).

Не путать с версией **платформы** (`.env` / `PLATFORM_BUILD`) и с
`ВерсияДанных` объектов.

## Перед каждым коммитом

Версию поднимает скрипт, не руками.

```bash
python tools/bump-version.py           # записать следующий номер
python tools/bump-version.py --dry-run # показать, не писать
python tools/bump-version.py --print   # текущая в файле
python tools/bump-version.py --self-test
```

База счёта — версия в **HEAD**, не «на глаз». Если в working tree уже стоит
вычисленный следующий номер — скрипт ничего не пишет.

Автоматически: git hook [`.githooks/pre-commit`](.githooks/pre-commit)
вызывает скрипт и делает `git add src/cf/Configuration.xml`.

Включить хуки один раз (локальный git config, в репозиторий не коммитится):

```bash
git config core.hooksPath .githooks
```

Отключить на один коммит (amend, аварийно):

```bash
SKIP_VERSION_BUMP=1 git commit …
```

Хук **стейджит весь** `Configuration.xml`. Грязный ChildObjects от obm-sync
уедет в тот же коммит — либо сначала разбери sync, либо `SKIP_VERSION_BUMP`.

## Для агентов

- Не править `<Version>` вручную, если хук включён.
- Хук не включён → перед коммитом `python tools/bump-version.py`.
- Amend того же коммита без новой версии: `SKIP_VERSION_BUMP=1`.
