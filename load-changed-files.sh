#!/bin/bash
_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec bash "${_ROOT}/harness/tools/load-changed-files/load-changed-files.sh" "$@"
