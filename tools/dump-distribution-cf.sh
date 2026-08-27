#!/usr/bin/env bash
# Файл поставки конфигурации (.cf) из ИБ через конфигуратор.
#   1cv8 CONFIG … /CreateDistributionFiles -cffile <путь.cf>
# CFU не создаём. Имя: .tmp/<Version>_1Сv8.cf
# Канон версии: docs/ai/versioning.md
# Отключить из хука: SKIP_CF_DUMP=1 git commit …

set -euo pipefail

log() {
	local level="$1"
	local message="$2"
	local ts
	ts=$(date '+%Y-%m-%d %H:%M:%S')
	case "$level" in
		ERROR) echo "[$ts] ОШИБКА: $message" >&2 ;;
		WARN) echo "[$ts] ПРЕДУПРЕЖДЕНИЕ: $message" >&2 ;;
		*) echo "[$ts] $message" ;;
	esac
}

extract_base_dirname() {
	local path
	path=$(echo "$1" | tr -d '"' | sed -E 's|^[[:space:]]*/[FfSs][[:space:]]*||')
	echo "$path" | sed -E 's|.*[/\\]([^/\\]+)[/\\]?$|\1|' | xargs
}

run_1c_command() {
	if [[ "${PROJECT_OS}" == "linux" ]]; then
		export LANG="${LANG:-ru_RU.UTF-8}"
		export LC_ALL="${LC_ALL:-ru_RU.UTF-8}"
		if [[ "${USE_XVFB:-}" != "false" ]] && command -v xvfb-run >/dev/null 2>&1; then
			xvfb-run -a bash -c "$1"
		else
			eval "$1"
		fi
	else
		MSYS_NO_PATHCONV=1 MSYS2_ARG_CONV_EXCL="*" eval "$@"
	fi
}

ib_config_auth_suffix() {
	local u p
	u="${AGENT_IB_USER:-${IB_USER:-${WEB_TEST_USER:-}}}"
	p="${AGENT_IB_PASSWORD:-${IB_PASSWORD:-${WEB_TEST_PASSWORD:-}}}"
	IB_CONFIG_AUTH=""
	if [[ -n "$u" ]]; then
		IB_CONFIG_AUTH="/N${u}"
		[[ -n "$p" ]] && IB_CONFIG_AUTH+=" /P${p}"
	fi
	return 0
}

# Git Bash pwd = /c/foo → C:\foo. Простая замена слэшей даёт \c\foo — 1cv8 такое не ест.
to_1c_win_path() {
	local path="$1"
	if command -v cygpath >/dev/null 2>&1; then
		cygpath -w "$path"
		return
	fi
	path=$(win_to_unix_path "$path")
	if [[ "$path" =~ ^/([a-zA-Z])(/|$) ]]; then
		path="${BASH_REMATCH[1]^^}:${path:2}"
	fi
	unix_to_win_path "$path"
}

dump_designer_log() {
	local log_file="$1"
	[[ -s "$log_file" ]] || return 0
	local log_text=""
	if iconv -f UTF-8 -t UTF-8 "$log_file" >/dev/null 2>&1; then
		log_text=$(sed '1s/^\xEF\xBB\xBF//' "$log_file")
	elif iconv -f UTF-16LE -t UTF-8 "$log_file" >/dev/null 2>&1; then
		log_text=$(iconv -f UTF-16LE -t UTF-8 "$log_file" | sed '1s/^\xEF\xBB\xBF//')
	elif iconv -f CP1251 -t UTF-8 "$log_file" >/dev/null 2>&1; then
		log_text=$(iconv -f CP1251 -t UTF-8 "$log_file")
	else
		log_text=$(cat "$log_file")
	fi
	log "ERROR" "лог конфигуратора ($log_file):"
	while IFS= read -r line || [[ -n "$line" ]]; do
		[[ -z "${line//[[:space:]]/}" ]] && continue
		log "ERROR" "  $line"
	done <<<"$log_text"
}

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
cd "$REPO_ROOT"

# shellcheck source=tools/load-project-env.sh
source "${REPO_ROOT}/tools/load-project-env.sh"
load_project_env "$REPO_ROOT"
# shellcheck source=tools/os/detect.sh
source "${REPO_ROOT}/tools/os/detect.sh"
source "${REPO_ROOT}/tools/os/paths.sh"
source "${REPO_ROOT}/tools/os/process-1c.sh"

IB_CONNECTION="${IB_CONNECTION:?IB_CONNECTION не задан (см. .env)}"
DESIGNER_PATH="${DESIGNER_PATH:-$(resolve_designer_default)}"
AUTO_CLOSE_DESIGNER="${AUTO_CLOSE_DESIGNER:-true}"
OUT_DIR="${REPO_ROOT}/.tmp"
# С = кириллица (U+0421), маска <Version>_1Сv8.cf
CF_SUFFIX=$'1\u0421v8.cf'

_designer_unix=$(win_to_unix_path "$DESIGNER_PATH")
if [[ "${PROJECT_OS}" == "linux" ]]; then
	if [[ ! -x "$_designer_unix" ]]; then
		_linux_default=$(resolve_designer_default)
		if [[ -n "$_linux_default" && -x "$_linux_default" ]]; then
			DESIGNER_PATH="$_linux_default"
			_designer_unix="$DESIGNER_PATH"
		fi
	fi
	DESIGNER_CMD="$DESIGNER_PATH"
	IB_CONNECTION="${IB_CONNECTION//\"/}"
	IB_CONNECTION="${IB_CONNECTION//\\}"
else
	DESIGNER_CMD=$(to_1c_win_path "$_designer_unix")
fi

if [[ ! -x "$_designer_unix" && ! -f "$_designer_unix" ]]; then
	log "ERROR" "1cv8 не найден: $DESIGNER_PATH"
	exit 1
fi

version=$(sed -n 's/.*<Version>\([^<]*\)<\/Version>.*/\1/p' "src/cf/Configuration.xml" | head -n1)
if [[ -z "$version" ]]; then
	log "ERROR" "нет <Version> в src/cf/Configuration.xml"
	exit 1
fi

mkdir -p "$OUT_DIR"
cf_unix="${OUT_DIR}/${version}_${CF_SUFFIX}"
log_unix="${OUT_DIR}/dump-distribution-cf.log"
rm -f "$cf_unix"
: > "$log_unix"

if [[ "${PROJECT_OS}" == "linux" ]]; then
	cf_cmd="$cf_unix"
	log_cmd="$log_unix"
else
	cf_cmd=$(to_1c_win_path "$cf_unix")
	log_cmd=$(to_1c_win_path "$log_unix")
fi

run_designer_batch() {
	local label="$1"
	local batch="$2"
	COMMAND="\"$DESIGNER_CMD\" CONFIG $IB_CONNECTION $IB_CONFIG_AUTH $batch /Out \"$log_cmd\" /DisableStartupDialogs /DisableStartupMessages"
	log "INFO" "$label"
	: > "$log_unix"
	set +e
	run_1c_command "$COMMAND"
	exit_code=$?
	set -e
	if [[ $exit_code -ne 0 ]]; then
		log "ERROR" "$label — код $exit_code"
		dump_designer_log "$log_unix"
		return 1
	fi
	return 0
}

ib_config_auth_suffix

if [[ "$AUTO_CLOSE_DESIGNER" == "true" ]]; then
	# process-1c.sh: powershell pipeline + pipefail = ложный fail, если процессов нет
	set +e
	close_1c_designer
	set -e
fi

log "INFO" "поставка $version → $cf_unix"
# CreateDistributionFiles требует совпадения основной конфигурации и конфигурации БД
if ! run_designer_batch "UpdateDBCfg" "/UpdateDBCfg"; then
	exit 1
fi
if ! run_designer_batch "CreateDistributionFiles" "/CreateDistributionFiles -cffile \"$cf_cmd\""; then
	exit 1
fi
if [[ ! -s "$cf_unix" ]]; then
	log "ERROR" "поставка не собралась — нет файла $cf_unix"
	dump_designer_log "$log_unix"
	exit 1
fi

log "INFO" "готово: $cf_unix"
exit 0
