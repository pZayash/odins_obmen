# OS-абстракция CLI (generic)

Автовыбор ветки: `tools/os/detect.sh` → `PROJECT_OS=linux|windows`.

| Модуль | Назначение |
| --- | --- |
| [detect.sh](detect.sh) | детект ОС |
| [paths.sh](paths.sh) | пути `1cv8`, win/unix (`PLATFORM_BUILD` из env) |
| [apache.sh](apache.sh) | Apache: служба Windows / `apachectl` Linux |
| [process-1c.sh](process-1c.sh) | закрытие `1cv8` CONFIG/ENTERPRISE |

Подключается из [load-changed-files.sh](../../load-changed-files.sh) (через [load-project-env.sh](../load-project-env.sh)).
Web: [tools/web/linux_backend.py](../web/linux_backend.py) + ветки в `web-publish/stop/info`.

Project-specific (`.dt`, NetHASP, `cfe.xml`) — в `docker/agent-container/`, не здесь.
