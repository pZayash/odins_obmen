#!/bin/bash
# Параметры проекта: .env (приоритет) или .env.example (несекретные дефолты).
# Канон версии платформы — PLATFORM_VERSION / PLATFORM_BUILD / COMPATIBILITY_MODE в .env.example.

load_project_env() {
    local root="${1:-.}"
    if [[ -f "${root}/.env" ]]; then
        # shellcheck disable=SC1090
        source "${root}/.env"
    elif [[ -f "${root}/.env.example" ]]; then
        # shellcheck disable=SC1090
        source "${root}/.env.example"
    fi
}
