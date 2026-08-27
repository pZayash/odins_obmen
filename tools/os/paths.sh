#!/bin/bash
# Пути 1cv8 по ОС (generic).
# Требует: detect.sh (PROJECT_OS).

resolve_designer_default() {
  local ver="${PLATFORM_BUILD:-}"
  if [[ -z "$ver" ]]; then
    echo "resolve_designer_default: PLATFORM_BUILD не задан (см. .env.example)" >&2
    return 1
  fi
  case "${PROJECT_OS}" in
    linux)
      echo "/opt/1cv8/x86_64/${ver}/1cv8"
      ;;
    windows)
      echo "C:/Program Files/1cv8/${ver}/bin/1cv8.exe"
      ;;
    *)
      echo ""
      ;;
  esac
}

unix_to_win_path() {
  local path="$1"
  echo "$path" | sed 's|/|\\|g'
}

win_to_unix_path() {
  local path="$1"
  echo "$path" | sed 's|\\|/|g' | sed 's/^"\(.*\)"$/\1/'
}
