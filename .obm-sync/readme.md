# `.obm-sync` — очередь переноса из кпср_unf2020

Служебная папка репозитория **odins_obmen**. Сюда пишет скрипт
`tools/obm-sync/sync.py` из репо КПСР (`кпср_unf2020.dev.git`).
Разбор и коммиты — **здесь**, не в source-репо.

## Что делает sync (без LLM, без автокоммита)

1. Копирует объекты `обм_` / `общ_` из `conf/` source → `src/cf/` этого репо.
2. Патчит только `ChildObjects` в `src/cf/Configuration.xml` (весь файл не
   перезаписывает).
3. **Не** вызывает `git commit`.
4. Обновляет состояние и кладёт сводку в `pending/`.

Триггер в source: `post-commit` (после коммитов, тронувших `conf/…/обм_|общ_`).
Ручной запуск там же:

```bash
bash tools/sandbox/run.sh python tools/obm-sync/sync.py          # инкремент
bash tools/sandbox/run.sh python tools/obm-sync/sync.py --resync  # полный снимок
```

Target override: env `OBM_SYNC_TARGET` или `--target` (часто worktree
`.tmp/odins_obmen` в source-клоне).

## Содержимое папки

| Путь | В git? | Назначение |
| --- | --- | --- |
| `readme.md` | да | этот файл |
| `last-source-sha` | нет | последний отданный SHA коммита source |
| `pending/<ts>_<sha8>.md` | нет | сводка прогона: batch ≈ source-коммит |

Пачка `pending/*.md`: при повторном sync на грязном tree **дописывается**
новый файл, старые не затираются.

## Как разбирать (maintainer)

1. `git status` / `git diff -- src/cf` — что приехало в working tree.
   Истина = diff, не списки Files/Objects в pending: batch
   `obm-sync post-incremental drift` — дамп snapshot, шум.
2. Открыть свежий `pending/*.md`: batches, `Obm-Source`, subject/body
   исходного коммита. Сверить с diff: лишнее в pending отбросить,
   дыры в tree — заметить.
3. **Ревью до коммита** (обязательно). Смотреть смысл приехавшего кода,
   не только состав файлов: гонки, лишние удаления, сломанный API,
   «пустой набор по измерению» вместо точечного, `Если Следующий`
   вместо цикла. Ghost-dirty (`assume-unchanged`, hash = HEAD) в
   коммит не брать.
4. Дефект — **не коммитить**. Промпт на фикс агенту source-репо;
   правки живут там, сюда снова приедут sync. Параллельно не чинить
   в двух репо.
5. Ревью ок — разбить на логичные коммиты (вручную или агентом),
   сообщения свои. Опционально trailer `Obm-Source: <sha>` (для людей;
   скрипт опирается на `last-source-sha`, не на trailer).
6. После коммита: удалить или архивировать обработанные `pending/*.md`.
7. `last-source-sha` трогать не нужно — его ведёт sync. Если история
   source переписана / state потерян — в source снова `--resync`.

## Gitignore

В корневом `.gitignore`: игнор всего `.obm-sync/*`, исключение — `readme.md`.
State и pending остаются локальными артефактами переноса.
