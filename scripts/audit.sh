#!/usr/bin/env bash
set -uo pipefail

PASS=0
FAIL=0

check() {
    local desc="$1" expected="$2" actual="$3"

    if [[ "$actual" == "$expected" ]]; then
        echo " [OK]    $desc"
        ((PASS++))
    else
        echo " [FAIL] $desc (ожидалось: '$expected', получено: '$actual')"
        ((FAIL++))
    fi
}

echo "Аудит конфигурации: $(hostname -f), $(date '+%Y-%m-%d %H:%M')"

echo "[1] Служба SSH"

check "Вход от имени root запрещён" \
    "no" \
    "$(sudo sshd -T | awk '/^permitrootlogin/{print $2}')"

check "Парольная аутентификация отключена" \
    "no" \
    "$(sudo sshd -T | awk '/^passwordauthentication/{print $2}')"

# TODO 1: порт SSH должен отличаться от 22
SSH_PORT="$(sudo sshd -T | awk '/^port/{print $2; exit}')"

if [[ "$SSH_PORT" != "22" ]]; then
    echo " [OK]    Порт SSH отличается от 22"
    ((PASS++))
else
    echo " [FAIL] Порт SSH равен 22"
    ((FAIL++))
fi

# TODO 2: MaxAuthTries должен быть равен 3
check "MaxAuthTries равен 3" \
    "3" \
    "$(sudo sshd -T | awk '/^maxauthtries/{print $2}')"

echo "[2] Межсетевой экран"

check "Межсетевой экран активен" \
    "active" \
    "$(sudo ufw status | awk '/^Status:/{print $2}')"

# TODO 3: политика входящего трафика — deny
INCOMING_POLICY="$(sudo ufw status verbose | awk '/^Default:/{print $2}')"

check "Политика входящего трафика deny" \
    "deny" \
    "$INCOMING_POLICY"

echo "[3] Учётные записи"

awk -F: '$3>=1000 && $3<65534 {
    printf "              %s (uid=%s)\n",$1,$3
}' /etc/passwd

echo "[4] Веб-сервер"

check "Служба nginx активна" \
    "active" \
    "$(systemctl is-active nginx)"

NGINX_CONFIG_STATUS="error"

if sudo nginx -t > /dev/null 2>&1; then
    NGINX_CONFIG_STATUS="ok"
fi

check "Конфигурация nginx корректна" \
    "ok" \
    "$NGINX_CONFIG_STATUS"

CERT_CHECK_SECONDS=2592000
CERT_STATUS="expires-soon"

if openssl x509 \
    -checkend "$CERT_CHECK_SECONDS" \
    -noout \
    -in /etc/ssl/certs/devops.crt > /dev/null 2>&1; then
    CERT_STATUS="valid"
fi

check "Сертификат действителен не менее 30 дней" \
    "valid" \
    "$CERT_STATUS"

WORLD_WRITABLE="$(
    find /var/www/devops-site -type f -perm -o+w -print -quit
)"
KEY_MODE="$(
    sudo stat -c '%a' /etc/ssl/private/devops.key
)"
WEB_PERMISSIONS_STATUS="error"

if [[ -z "$WORLD_WRITABLE" && "$KEY_MODE" == "600" ]]; then
    WEB_PERMISSIONS_STATUS="ok"
fi

check "Файлы сайта защищены, права ключа равны 600" \
    "ok" \
    "$WEB_PERMISSIONS_STATUS"

echo "Пройдено: $PASS, не пройдено: $FAIL"

[[ $FAIL -eq 0 ]] && exit 0 || exit 1
