#!/bin/bash

# Безпечні налаштування
set -euo pipefail

# === Кольори та лог-функції ===
RED='\e[31m'; GREEN='\e[32m'; YELLOW='\e[33m'; BLUE='\e[34m'; NC='\e[0m'

log_info()  { echo -e "${BLUE}[INFO]${NC} $1"; }
log_ok()    { echo -e "${GREEN}[OK]${NC} $1"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# === Обробка помилок ===
trap 'log_error "Скрипт завершено з помилкою." && exit 1' ERR

log_info "Початок встановлення ionCube Loader..."

# === 1. Визначення архітектури ===
ARCH=$(uname -m)
log_info "Визначено архітектуру: $ARCH"

# === 2. Вибір посилання ===
URL=""
if [[ "$ARCH" == "x86_64" ]]; then
    URL="https://downloads.ioncube.com/loader_downloads/ioncube_loaders_lin_x86-64.tar.gz"
elif [[ "$ARCH" == "i686" || "$ARCH" == "i386" ]]; then
    URL="https://downloads.ioncube.com/loader_downloads/ioncube_loaders_lin_x86.tar.gz"
else
    log_error "Невідома архітектура: $ARCH"
    exit 1
fi

# === 3. Завантаження архіву ===
TMP_DIR="/tmp/ioncube_install"
mkdir -p "$TMP_DIR"
cd "$TMP_DIR"
log_info "Завантаження: $URL"
curl -sSLO "$URL"
log_ok "Архів завантажено"

# === 4. Розпаковка ===
tar -xf ioncube_loaders_lin_*.tar.gz
rm -f ioncube_loaders_lin_*.tar.gz
log_ok "Архів розпаковано"

# === 5. Визначення PHP-версії та директорії розширень ===
PHP_VERSION=$(php -r "echo PHP_MAJOR_VERSION.'.'.PHP_MINOR_VERSION;")
EXT_DIR=$(php -i | grep extension_dir | awk -F '=> ' '{print $2}' | head -n1 | xargs)
log_info "PHP версія: $PHP_VERSION"
log_info "Директорія розширень: $EXT_DIR"

# === 6. Копіювання ioncube_loader ===
LOADER_FILE="ioncube/ioncube_loader_lin_${PHP_VERSION}.so"
if [[ ! -f "$LOADER_FILE" ]]; then
    log_error "Не знайдено файл: $LOADER_FILE"
    exit 1
fi

cp "$LOADER_FILE" "$EXT_DIR/"
log_ok "ionCube loader скопійовано в $EXT_DIR"

# === 7. Додавання в php.ini CLI та FPM ===
for sapi in cli fpm; do
    INI_PATH="/etc/php/${PHP_VERSION}/${sapi}/php.ini"
    if [[ -f "$INI_PATH" ]]; then
        if grep -q "ioncube_loader_lin_${PHP_VERSION}.so" "$INI_PATH"; then
            log_warn "ionCube вже присутній в $INI_PATH"
        else
            echo "zend_extension=${EXT_DIR}/ioncube_loader_lin_${PHP_VERSION}.so" >> "$INI_PATH"
            log_ok "Додано в $INI_PATH"
        fi
    else
        log_warn "$INI_PATH не знайдено"
    fi
done

# === 8. Перезапуск служб (за потреби) ===
log_info "Перезапуск apache2, nginx, php-fpm..."
systemctl restart apache2 2>/dev/null || true
systemctl restart nginx 2>/dev/null || true
systemctl restart php${PHP_VERSION}-fpm 2>/dev/null || true
log_ok "Служби перезапущено"

# === 9. Перевірка успіху ===
if php -v | grep -qi "ioncube"; then
    log_ok "ionCube успішно встановлено!"
else
    log_error "ionCube НЕ знайдено в php -v!"
    exit 1
fi

# === 10. Прибирання ===
rm -rf "$TMP_DIR"
log_ok "Тимчасові файли видалено"

log_ok "Встановлення завершено успішно!"
