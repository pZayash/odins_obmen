---
name: obm-sync
description: >-
  Разбор очереди переноса обм_/общ_ из кпср_unf2020 в odins_obmen:
  ревью diff, bump версии, загрузка в dev-ИБ, дым, коммит с хуками.
  Use when the user says obm-sync, «сделай obm-sync», «разбери pending»,
  last-source-sha, или просит перенести обмен из КПСР. Не путать с sync.py
  в source-репо.
---

# obm-sync

Канон папки: [`.obm-sync/readme.md`](../../../.obm-sync/readme.md).
Версия: [docs/ai/versioning.md](../../../docs/ai/versioning.md).
Load: скилл `load-changed-files` (`CONFIG_PATH=src/cf`).

## Когда вызывать

- `/obm-sync`, «сделай obm-sync», «разбери pending», «очередь из КПСР»
- Грязный `src/cf` + файлы `.obm-sync/pending/*.md`

Не вызывать вместо `load-changed-files` / обычного коммита правок **этого** репо.

## Два запуска

| Где | Команда | Делает |
| --- | --- | --- |
| КПСР | `sync.py` (хук или вручную) | копирует XML сюда, пишет `pending/` |
| **Этот** репо | этот скилл | ревью → bump → load → дым → коммит |

«Сделай obm-sync» **здесь** = колонка 2. `sync.py` — только если `pending/` пуст
и source HEAD впереди `.obm-sync/last-source-sha` по `обм_`/`общ_`.

Вручную в клоне КПСР:

```bash
export OBM_SYNC_TARGET="<корень odins_obmen>"
bash tools/sandbox/run.sh python tools/obm-sync/sync.py
# --resync — state потерян / история source переписана
```

Sync не коммитит, не грузит ИБ, не трогает `<Version>`.

## Запрещено

- `git commit` до успешного load `-U` и дыма
- `SKIP_VERSION_BUMP=1` (не «спасение» от грязного ChildObjects)
- `SKIP_CF_DUMP=1` на **последнем** коммите пачки после load
- Коммитить УНФ-регресс: `Configuration.УправлениеНебольшойФирмой`,
  `ДополнительныеОтчетыИОбработки`, `Role.Администрирование` — откатить к
  `odins_obmen`. В source не слать как дефект
- Чинить дефект обмена в двух репо сразу (фикс — в source, сюда снова sync)
- Трогать `last-source-sha`
- Коммитить ghost-dirty (`assume-unchanged`, hash = HEAD), `harness/`, kit

## Чеклист (этот репо)

Копировать и отмечать:

```text
- [ ] diff src/cf прочитан (истина = diff, не pending)
- [ ] drift-batch отброшен
- [ ] ревью кода; УНФ-имена откачены
- [ ] bump-version.py
- [ ] load-changed-files.sh -U --no-extensions — ок
- [ ] дым — ок
- [ ] commit без SKIP_VERSION_BUMP
- [ ] pending/*.md удалены
```

1. `git diff -- src/cf`. `pending/*.md` — подсказка (batches, `Obm-Source`).
   Batch `obm-sync post-incremental drift` — шум.
2. Ревью: гонки, лишние удаления, сломанный API, отбор «пустой набор по
   измерению», `Если Следующий` вместо цикла. Дефект обмена → стоп, промпт
   в source.
3. `python tools/bump-version.py`
4. `./load-changed-files.sh -U --no-extensions`
5. Дым: load / `UpdateDBCfg` без ошибки; открыть затронутые формы (дашборд,
   панель команд, списки очередей) — нет исключения на открытии и базовой
   команде. Автотестов в этой CF нет — не выдумывать `яя_тесты`.
6. `git commit` с хуками (`.githooks`). Trailer `Obm-Source: <sha>` по желанию.
   Дробить по смыслу — **после** дыма. Промежуточные: `SKIP_CF_DUMP=1`.
   Если хук поднял версию ещё раз — перед dump снова шаг 4.
   Pre-commit стейджит весь `Configuration.xml`: ChildObjects в коммит фичи
   или один коммит на пачку — не скип bump.
7. Удалить обработанные `.obm-sync/pending/*.md`.

## Антипаттерн

| Сделал | Надо |
| --- | --- |
| `SKIP_VERSION_BUMP=1` из-за грязного ChildObjects | bump + ChildObjects в коммит фичи |
| commit сразу после ревью | bump → load → дым → commit |
| `SKIP_CF_DUMP` на единственном коммите | dump: ИБ уже с XML после load |
| повтор `sync.py` при непустом pending | разбор очереди, не второй копир |

## Связанное

- [load-changed-files](../load-changed-files/SKILL.md) — шаг 4
- [dump-distribution-cf](../dump-distribution-cf/SKILL.md) — `.cf`
- [docs/ai/versioning.md](../../../docs/ai/versioning.md) —
  хуки, `SKIP_*` только amend
