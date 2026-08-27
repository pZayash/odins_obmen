#!/bin/bash
# Детект ОС для CLI проекта (generic-слой).
# Экспорт: PROJECT_OS=linux|windows|unknown

detect_project_os() {
  case "$(uname -s)" in
    Linux*) PROJECT_OS=linux ;;
    MINGW*|MSYS*|CYGWIN*) PROJECT_OS=windows ;;
    *) PROJECT_OS=unknown ;;
  esac
  export PROJECT_OS
}

detect_project_os
