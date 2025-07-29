#!/bin/bash
set -euo pipefail
trap 'echo -e "\033[1;31m[ERROR]\033[0m Сталася помилка. Скрипт зупинено." >&2; exit 1' ERR

# ==== Кольорове логування ====
log() {
  local type="$1"; shift
  case "$type" in
    INFO)  echo -e "\033[1;34m[INFO]\033[0m $*";;
    OK)    echo -e "\033[1;32m[OK]\033[0m   $*";;
    ERROR) echo -e "\033[1;31m[ERROR]\033[0m $*" >&2;;
  esac
}

# ==== Інтерактивне введення даних ====
read -rp "Введи бажану версію PHP (наприклад, 8.2): " PHP_VER
read -rp "Введи ім’я користувача Hestia (наприклад, admin): " USER_NAME
read -rp "Введи домен (наприклад, site.com): " DOMAIN_NAME
read -rp "Введи повний шлях до Apache-конфігу (наприклад, /home/admin/conf/web/site.com/apache2.conf): " APACHE_CONF

# ==== Установка і перемикання PHP ====
log INFO "Встановлення PHP $PHP_VER через Hestia..."
v-add-web-php "$PHP_VER"

log INFO "Перемикання системної версії PHP на $PHP_VER..."
v-change-sys-php "$PHP_VER"

log INFO "Перезапуск php$PHP_VER-fpm..."
systemctl restart php${PHP_VER}-fpm

# ==== Ребілд сайту ====
log INFO "Ребілд конфігів сайту $DOMAIN_NAME..."
v-rebuild-web-domain "$USER_NAME" "$DOMAIN_NAME"

# ==== Оновлення шляху до сокета ====
SOCKET="/run/php/php${PHP_VER}-fpm-${DOMAIN_NAME}.sock"

log INFO "Бекап Apache-конфігу..."
cp "$APACHE_CONF" "${APACHE_CONF}.bak_$(date +%F_%H-%M-%S)"

log INFO "Оновлення шляху до PHP-FPM сокета в Apache конфіг-файлі..."
sed -i -E "s|/[^ ]*/php/php[0-9.]+-fpm-${DOMAIN_NAME}\.sock|$SOCKET|g" "$APACHE_CONF"

log INFO "Перезапуск Apache..."
systemctl reload apache2

log OK "Операція завершена. PHP $PHP_VER встановлено, сокет оновлено."
