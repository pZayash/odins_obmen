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
SKIP_CF_DUMP=1 git commit …          # без файла поставки .cf
```

Хук **стейджит весь** `Configuration.xml`. Грязный ChildObjects от obm-sync
уедет в тот же коммит — либо сначала разбери sync, либо `SKIP_VERSION_BUMP`.

## После каждого коммита

Пост-коммит [`.githooks/post-commit`](.githooks/post-commit) собирает
**файл поставки** (полный дистрибутив `.cf`, без `.cfu`) из текущей ИБ
(`IB_CONNECTION` в `.env`):

```text
1cv8 CONFIG … /CreateDistributionFiles -cffile <путь>
```

Кладёт в `.tmp/` (каталог в `.gitignore`):

```text
.tmp/<Version>_1Сv8.cf
```

Содержимое CF = конфигурация **в ИБ**, не XML на диске. Перед поставкой
**надо обновить рабочую базу из репо** (`./load-changed-files.sh -U`), иначе
имя файла будет из XML, а внутри — старая `Метаданные.Версия`.

Скрипт dump делает `/UpdateDBCfg` (платформа не создаёт дистрибутив, пока
основная конфигурация не совпадает с конфигурацией БД). `/UpdateDBCfg` ≠
загрузка XML. Obm-sync грузит ИБ **до** коммита, поэтому post-commit dump
после пачки уже из обновлённой базы.

Рецепт агента: скилл `dump-distribution-cf` (bump → load → dump).

Вручную:

```bash
./load-changed-files.sh -U --no-extensions --force-configuration
bash tools/dump-distribution-cf.sh
```

Конфигуратор открыт — хук закроет его (`AUTO_CLOSE_DESIGNER`, по
умолчанию `true`). Коммит при ошибке сборки уже записан; хук только
печатает лог `.tmp/dump-distribution-cf.log`.

## Для агентов

- Не править `<Version>` вручную, если хук включён.
- Хук не включён → перед коммитом `python tools/bump-version.py`.
- Amend того же коммита без новой версии: `SKIP_VERSION_BUMP=1`.
- Amend без пересборки `.cf`: `SKIP_CF_DUMP=1`.
