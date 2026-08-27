#!/bin/bash
# Закрытие процессов 1cv8 по ИБ (generic + OS-ветки).
# Требует: detect.sh, extract_base_dirname(), log().

find_1c_designer_pids() {
  local base_id
  base_id=$(extract_base_dirname "$IB_CONNECTION")
  case "${PROJECT_OS}" in
    linux)
      pgrep -af "1cv8.*CONFIG.*${base_id}" 2>/dev/null | awk '{print $1}' || true
      ;;
    windows)
      powershell.exe -NoProfile -Command "[Console]::OutputEncoding = [System.Text.Encoding]::UTF8; Get-CimInstance Win32_Process | Where-Object { \$_.Name -eq '1cv8.exe' -and (\$_.CommandLine -like '*CONFIG*' -or \$_.CommandLine -like '*DESIGNER*') -and \$_.CommandLine -like '*$base_id*' } | Select-Object -ExpandProperty ProcessId" 2>/dev/null | tr -d '\r'
      ;;
  esac
}

find_1c_enterprise_pids() {
  local base_id
  base_id=$(extract_base_dirname "$IB_CONNECTION")
  case "${PROJECT_OS}" in
    linux)
      pgrep -af "1cv8.*ENTERPRISE.*${base_id}" 2>/dev/null | awk '{print $1}' || true
      ;;
    windows)
      powershell.exe -NoProfile -Command "[Console]::OutputEncoding = [System.Text.Encoding]::UTF8; Get-CimInstance Win32_Process | Where-Object { (\$_.Name -eq '1cv8.exe' -or \$_.Name -eq '1cv8c.exe') -and \$_.CommandLine -like '*ENTERPRISE*' -and \$_.CommandLine -like '*$base_id*' } | Select-Object -ExpandProperty ProcessId" 2>/dev/null | tr -d '\r'
      ;;
  esac
}

_kill_pids() {
  local label="$1"
  shift
  local pids="$*"
  [[ -z "${pids}" ]] && return 0
  case "${PROJECT_OS}" in
    linux)
      echo "${pids}" | xargs -r kill -TERM 2>/dev/null || true
      sleep 2
      echo "${pids}" | xargs -r kill -KILL 2>/dev/null || true
      ;;
    windows)
      local pid
      for pid in ${pids}; do
        MSYS_NO_PATHCONV=1 MSYS_ARG_CONV_EXCL="*" taskkill /F /PID "$pid" >/dev/null 2>&1 || true
      done
      sleep 2
      ;;
  esac
  log "SUCCESS" "${label} закрыт"
}

close_1c_designer() {
  log "INFO" "Проверка конфигуратора для базы: $IB_CONNECTION"
  local base_id designer_pid
  base_id=$(extract_base_dirname "$IB_CONNECTION")
  log "INFO" "Идентификатор базы: $base_id"
  designer_pid=$(find_1c_designer_pids)
  if [[ -z "$designer_pid" ]]; then
    log "INFO" "Конфигуратор не найден"
    return 0
  fi
  designer_pid=$(echo "$designer_pid" | head -n 1)
  log "INFO" "Закрытие конфигуратора PID: $designer_pid"
  _kill_pids "Конфигуратор" "$designer_pid"
}

close_1c_enterprise() {
  log "INFO" "Проверка клиента для базы: $IB_CONNECTION"
  local enterprise_pid
  enterprise_pid=$(find_1c_enterprise_pids)
  if [[ -z "$enterprise_pid" ]]; then
    log "INFO" "Клиент не найден"
    return 0
  fi
  enterprise_pid=$(echo "$enterprise_pid" | head -n 1)
  log "INFO" "Закрытие клиента PID: $enterprise_pid"
  _kill_pids "Клиент" "$enterprise_pid"
}
