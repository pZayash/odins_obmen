---
name: dump-distribution-cf
description: >-
  Сборка файла поставки подсистемы (.cf, без .cfu) в .tmp/<Version>_1Сv8.cf
  из dev-ИБ. Сначала bump версии, затем обязательно обновление рабочей базы
  из репо, потом CreateDistributionFiles. Use when the user says «собери
  поставку», dump-distribution, файл поставки, CreateDistributionFiles,
  или просит .cf в .tmp.
argument-hint: "[--no-bump]"
allowed-tools:
  - Bash
  - Read
  - Glob
---

# dump-distribution-cf

Канон версии: [docs/ai/versioning.md](../../../docs/ai/versioning.md).
Load: скилл `load-changed-files` (`CONFIG_PATH=src/cf`).

## Обязательно

Надо обновить рабочую базу из репо прежде чем собирать.

Имя `.cf` берётся из XML `<Version>`. Содержимое CF — конфигурация **в ИБ**,
не XML на диске. `/UpdateDBCfg` ≠ загрузка XML. Dump без load = чужая версия
внутри файла с правильным именем (уже было: файл `260828.01_1Сv8.cf`, внутри
`260209.01`).

## Чеклист

```text
- [ ] python tools/bump-version.py
- [ ] рабочая база обновлена из репо (load)
- [ ] bash tools/dump-distribution-cf.sh
- [ ] имя файла = <Version> XML = версия в ИБ
```

## Шаги

### Версия

```bash
python tools/bump-version.py
```

Пропуск bump — только если пользователь явно сказал не поднимать, или это
повторный dump сразу после load в этой же сессии (версия уже в ИБ).
Не ставить `SKIP_VERSION_BUMP` (это флаг коммита, не dump).

### Обновить рабочую базу из репо

Не пропускать.

```bash
./load-changed-files.sh -U --no-extensions --force-configuration
```

ИБ отстала от диска (в диалоге обновления версия ≠ XML, давно не грузили,
полный resync) — вместо этого:

```bash
./load-changed-files.sh -F --no-extensions
```

`-F` = полная загрузка `src/cf` + `/UpdateDBCfg`. Расширений в этой CF нет.

### Собрать

```bash
bash tools/dump-distribution-cf.sh
```

Результат: `.tmp/<Version>_1Сv8.cf` (`С` = кириллица U+0421).
Лог: `.tmp/dump-distribution-cf.log`.

Конфигуратор открыт — скрипт закроет (`AUTO_CLOSE_DESIGNER`).

## Запрещено

- `bash tools/dump-distribution-cf.sh` без шага load
- Путать с `db-dump-cf` (выгрузка `/DumpCfg`, не файл поставки)
- CFU / `-cfufile`
- Коммитить `.cf` (`.gitignore`)

## Post-commit

Хук [`.githooks/post-commit`](../../../.githooks/post-commit) вызывает тот же
скрипт. Имеет смысл только если load в ИБ уже был **до** коммита (obm-sync).
Иначе хук соберёт старую ИБ под новым именем. `SKIP_CF_DUMP=1` — промежуточный
коммит пачки.

## Связанное

- [load-changed-files](../load-changed-files/SKILL.md)
- [docs/ai/versioning.md](../../../docs/ai/versioning.md)
- [obm-sync](../obm-sync/SKILL.md) — bump → load → дым → commit (dump в хуке)
