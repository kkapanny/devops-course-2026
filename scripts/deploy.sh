#!/usr/bin/env bash
# Доставка статического ресурса на devops-vm
# Использование: scripts/deploy.sh [--dry-run]

set -euo pipefail

REMOTE="devops"
REMOTE_DIR="/var/www/devops-site"
SITE_URL="https://devops.local"
CA_CERT="${HOME}/devops.crt"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
LOCAL_DIR="${REPO_ROOT}/site/"

DRY_RUN=false

# 1. Разбор аргументов
if [[ $# -gt 1 ]]; then
    echo "Использование: scripts/deploy.sh [--dry-run]" >&2
    exit 1
fi

if [[ $# -eq 1 ]]; then
    if [[ "$1" == "--dry-run" ]]; then
        DRY_RUN=true
    else
        echo "Неизвестный аргумент: $1" >&2
        echo "Использование: scripts/deploy.sh [--dry-run]" >&2
        exit 1
    fi
fi

# 2. Проверка наличия главной страницы
if [[ ! -f "${LOCAL_DIR}index.html" ]]; then
    echo "Ошибка: файл site/index.html отсутствует" >&2
    exit 1
fi

# Проверка отсутствия незафиксированных изменений
if [[ -n "$(git -C "${REPO_ROOT}" status --porcelain)" ]]; then
    echo "Ошибка: в репозитории есть незафиксированные изменения" >&2
    exit 1
fi

# Проверка наличия сертификата
if [[ ! -f "${CA_CERT}" ]]; then
    echo "Ошибка: сертификат ${CA_CERT} не найден" >&2
    exit 1
fi

RSYNC_OPTIONS=(
    -avz
    --delete
    --chmod=Du=rwx,Dgo=rx,Fu=rw,Fgo=r
    -e "ssh -o BatchMode=yes -o ConnectTimeout=5"
)

if [[ "${DRY_RUN}" == true ]]; then
    RSYNC_OPTIONS+=(--dry-run)
fi

# 3. Синхронизация сайта — одно SSH-соединение
if ! rsync "${RSYNC_OPTIONS[@]}" \
    "${LOCAL_DIR}" \
    "${REMOTE}:${REMOTE_DIR}/"; then
    echo "Ошибка: rsync не смог выполнить доставку" >&2
    exit 1
fi

# 4. При пробном запуске проверка сайта не выполняется
if [[ "${DRY_RUN}" == true ]]; then
    echo "Пробный запуск завершён, сервер не изменён"
    exit 0
fi

# 5. Проверка доступности сайта с проверкой сертификата
if ! curl -fsS --cacert "${CA_CERT}" \
    "${SITE_URL}" -o /dev/null; then
    echo "Ошибка: ресурс ${SITE_URL} недоступен" >&2
    exit 1
fi

COMMIT_HASH="$(git -C "${REPO_ROOT}" rev-parse --short HEAD)"
echo "Деплой успешно выполнен, коммит: ${COMMIT_HASH}"
exit 0
