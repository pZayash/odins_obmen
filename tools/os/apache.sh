#!/bin/bash
# Управление Apache: Windows-служба или Linux apachectl.
# Требует: detect.sh, log() из вызывающего скрипта.

_os_apache_is_service_mode() {
  [[ "${PROJECT_OS}" == "windows" && -n "${APACHE_SERVICE_NAME:-}" ]]
}

_os_apache_is_ctl_mode() {
  [[ "${PROJECT_OS}" == "linux" || "${APACHE_USE_CTL:-}" == "true" ]]
}

apache_is_running() {
  if _os_apache_is_ctl_mode; then
    if [[ "${PROJECT_OS}" == "linux" ]]; then
      /usr/sbin/service apache2 status >/dev/null 2>&1 || pgrep -x apache2 >/dev/null 2>&1
      return $?
    fi
    apachectl -k status >/dev/null 2>&1 || pgrep -x apache2 >/dev/null 2>&1
    return $?
  fi
  if _os_apache_is_service_mode; then
    local state
    state=$(powershell.exe -NoProfile -Command "(Get-Service -Name '$APACHE_SERVICE_NAME' -ErrorAction SilentlyContinue).Status" 2>/dev/null | tr -d '\r' | tr -d '\n')
    [[ "$state" == "Running" ]]
    return $?
  fi
  return 1
}

# Agent-slot: service apache2 stop без root часто exit 0, но worker'ы живы — нужен sudo -n.
_apache_linux_stop_apache2() {
  if sudo -n /usr/sbin/service apache2 stop 2>/dev/null \
    || /usr/sbin/service apache2 stop 2>/dev/null \
    || apache2ctl -k stop 2>/dev/null; then
    :
  elif pkill -x apache2 2>/dev/null; then
    sleep 1
  else
    return 1
  fi

  local i
  for ((i = 0; i < 30; i++)); do
    pgrep -x apache2 >/dev/null 2>&1 || break
    if [[ "$i" -eq 3 ]]; then
      log "WARN" "Apache workers не завершились — sudo/pkill"
      sudo -n /usr/sbin/service apache2 stop 2>/dev/null || true
      sudo -n pkill -x apache2 2>/dev/null || pkill -x apache2 2>/dev/null || true
    fi
    sleep 1
  done

  if pgrep -x apache2 >/dev/null 2>&1; then
    log "ERROR" "Не удалось остановить Apache (процессы apache2 остались)"
    return 1
  fi

  # ponytail: wsap отпускает lock 1Cv8.1CD не мгновенно после exit worker'а
  local settle="${APACHE_IB_LOCK_SETTLE_SECS:-3}"
  if [[ "$settle" =~ ^[0-9]+$ && "$settle" -gt 0 ]]; then
    log "INFO" "Пауза ${settle}s после stop Apache (release lock файловой ИБ)"
    sleep "$settle"
  fi
  return 0
}

_apache_linux_start_apache2() {
  if sudo -n /usr/sbin/service apache2 start 2>/dev/null \
    || /usr/sbin/service apache2 start 2>/dev/null \
    || apache2ctl -k start 2>/dev/null; then
    return 0
  fi
  return 1
}

apache_stop() {
  if _os_apache_is_ctl_mode; then
    log "INFO" "Останавливаю Apache — освобождение lock файловой ИБ"
    if [[ "${PROJECT_OS}" == "linux" ]]; then
      if _apache_linux_stop_apache2; then
        log "SUCCESS" "Apache остановлен"
        return 0
      fi
      log "ERROR" "Не удалось остановить Apache (service/apachectl/pkill)"
      return 1
    fi
    if apachectl -k stop 2>/dev/null; then
      log "SUCCESS" "Apache остановлен"
      return 0
    fi
    if pkill -x apache2 2>/dev/null; then
      sleep 1
      log "SUCCESS" "Apache остановлен (pkill)"
      return 0
    fi
    log "ERROR" "Не удалось остановить Apache (apachectl/pkill)"
    return 1
  fi
  if _os_apache_is_service_mode; then
    log "INFO" "Останавливаю Apache ($APACHE_SERVICE_NAME) — освобождаю lock файловой ИБ"
    local err
    err=$(powershell.exe -NoProfile -Command "Stop-Service -Name '$APACHE_SERVICE_NAME' -Force -ErrorAction Stop" 2>&1)
    local exit_code=$?
    if [[ $exit_code -ne 0 ]]; then
      log "ERROR" "Не удалось остановить Apache ($APACHE_SERVICE_NAME)"
      [[ -n "$err" ]] && log "ERROR" "  $err"
      return 1
    fi
    log "SUCCESS" "Apache остановлен"
    return 0
  fi
  return 0
}

apache_start() {
  if _os_apache_is_ctl_mode; then
    log "INFO" "Запускаю Apache"
    if [[ "${PROJECT_OS}" == "linux" ]]; then
      if _apache_linux_start_apache2; then
        log "SUCCESS" "Apache запущен (service apache2 start)"
        return 0
      fi
      log "ERROR" "Не удалось запустить Apache"
      return 1
    fi
    if apachectl -k start 2>/dev/null; then
      log "SUCCESS" "Apache запущен"
      return 0
    fi
    log "ERROR" "Не удалось запустить Apache"
    return 1
  fi
  if _os_apache_is_service_mode; then
    log "INFO" "Запускаю Apache ($APACHE_SERVICE_NAME)"
    local err
    err=$(powershell.exe -NoProfile -Command "Start-Service -Name '$APACHE_SERVICE_NAME' -ErrorAction Stop" 2>&1)
    local exit_code=$?
    if [[ $exit_code -ne 0 ]]; then
      log "ERROR" "Не удалось запустить Apache ($APACHE_SERVICE_NAME)"
      [[ -n "$err" ]] && log "ERROR" "  $err"
      return 1
    fi
    log "SUCCESS" "Apache запущен"
    return 0
  fi
  return 0
}
