# `.obm-sync` — очередь переноса из кпср_unf2020

Служебная папка репозитория **odins_obmen**. Сюда пишет скрипт
`tools/obm-sync/sync.py` из репо КПСР (`кпср_unf2020.dev.git`).
Разбор, загрузка в ИБ, дым и коммиты — **здесь**, не в source-репо.

Канон для агента: скилл [`obm-sync`](../.cursor/skills/obm-sync/SKILL.md).
Версия: [docs/ai/versioning.md](../docs/ai/versioning.md).

## Как запускать

Два разных запуска. Не путать.

### 1. Перенос XML (source, без LLM)

Триггер: `post-commit` в КПСР после коммитов, тронувших `conf/…/обм_|общ_`.

Вручную **в клоне КПСР**:

```bash
# цель = этот репо (или worktree .tmp/odins_obmen)
export OBM_SYNC_TARGET="C:/!Pavl0/Git/odins_obmen"
bash tools/sandbox/run.sh python tools/obm-sync/sync.py          # инкремент
bash tools/sandbox/run.sh python tools/obm-sync/sync.py --resync  # полный снимок
```

Override: env `OBM_SYNC_TARGET` или `--target`.

Sync **не** коммитит, **не** грузит ИБ, **не** трогает `<Version>`.

### 2. Разбор очереди (этот репо)

Команда «сделай obm-sync» = шаги ниже, не повтор `sync.py` (если `pending/`
уже есть и `last-source-sha` = нужный source SHA).

## Что делает sync (без LLM, без автокоммита)

1. Копирует объекты `обм_` / `общ_` из `conf/` source → `src/cf/` этого репо.
2. Патчит только `ChildObjects` в `src/cf/Configuration.xml` (весь файл не
   перезаписывает). `<Version>` не трогает и из source не копирует.
3. **Не** вызывает `git commit`.
4. Обновляет состояние и кладёт сводку в `pending/`.

## Содержимое папки

| Путь | В git? | Назначение |
| --- | --- | --- |
| `readme.md` | да | этот файл |
| `last-source-sha` | нет | последний отданный SHA коммита source |
| `pending/<ts>_<sha8>.md` | нет | сводка прогона: batch ≈ source-коммит |

Пачка `pending/*.md`: при повторном sync на грязном tree **дописывается**
новый файл, старые не затираются.

## Как разбирать (maintainer / агент)

Порядок **жёсткий**. Коммит до load+дыма — ошибка. `SKIP_VERSION_BUMP` на
obm-sync — ошибка (даже если ChildObjects грязный).

1. `git status` / `git diff -- src/cf` — что приехало. Истина = diff, не
   списки Files/Objects в pending: batch `obm-sync post-incremental drift` —
   дамп snapshot, шум.
2. Свежий `pending/*.md`: batches, `Obm-Source`, subject/body. Сверить с
   diff: лишнее отбросить, дыры в tree — заметить.
3. **Ревью.** Смысл кода, не только состав: гонки, лишние удаления, сломанный
   API, «пустой набор по измерению», `Если Следующий` вместо цикла.
   Ghost-dirty (`assume-unchanged`, hash = HEAD) в коммит не брать.
   Target-local: `Configuration.odins_obmen`, без объектов УНФ
   (`УправлениеНебольшойФирмой`, `ДополнительныеОтчетыИОбработки`,
   `Role.Администрирование`) — откатить, в source не слать как дефект.
4. Дефект **кода обмена** — не коммитить. Промпт в source-репо; сюда снова
   приедет sync. Параллельно не чинить в двух репо.
5. **Версия → ИБ → дым** (до `git commit`):
   - `python tools/bump-version.py`
   - `./load-changed-files.sh -U --no-extensions`
   - дым: загрузка/`UpdateDBCfg` без ошибки; открыть затронутые формы
     (дашборд, панель команд, списки очередей) — нет исключения при открытии
     и базовом действии (кнопка/команда из пачки). Автотестов в этой CF нет —
     не выдумывать `яя_тесты`. Провал дыма = стоп, не коммитить.
6. Коммит **с хуками**. Без `SKIP_VERSION_BUMP`. Без `SKIP_CF_DUMP` на
   последнем коммите пачки (ИБ уже с новым XML — поставка из ИБ валидна).
   Сообщения свои; опционально trailer `Obm-Source: <sha>`.
   Дробить по смыслу можно **после** дыма. Промежуточные коммиты:
   `SKIP_CF_DUMP=1`. Если хук поднял версию ещё раз — перед dump снова
   `./load-changed-files.sh -U --no-extensions`.
   ChildObjects грязный: не скип bump, а класть `Configuration.xml` в коммит
   той же фичи (или один коммит на пачку).
7. После коммита: удалить или архивировать обработанные `pending/*.md`.
8. `last-source-sha` не трогать — его ведёт sync. История source переписана /
   state потерян — в source снова `--resync`.

## Gitignore

В корневом `.gitignore`: игнор всего `.obm-sync/*`, исключение — `readme.md`.
State и pending остаются локальными артефактами переноса.
