#!/bin/bash
# deploy.sh

set -e

# === НАСТРОЙКИ ===
REPO_URL="https://github.com/TotallyNotAdmin/hr_new.git"
DEFAULT_DIR="$HOME/hr-system"
TARGET_DIR="${1:-$DEFAULT_DIR}"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info()    { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[OK]${NC} $1"; }
log_warn()    { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error()   { echo -e "${RED}[ERROR]${NC} $1"; }

# Преобразуем ~/путь в /home/user/путь
expand_path() {
    local path="$1"
    if [[ "$path" == ~* ]]; then
        echo "${HOME}${path:1}"
    else
        echo "$path"
    fi
}

# === ОСНОВНОЙ СЦЕНАРИЙ ===
main() {
    echo -e "${GREEN}Загрузчик системы Штат-контроль${NC}"
    echo "================================"
    
    TARGET_DIR=$(expand_path "$TARGET_DIR")
    log_info "Целевая директория: $TARGET_DIR"
    
    mkdir -p "$(dirname "$TARGET_DIR")"
    
    # Клонирование или обновление
    if [ -d "$TARGET_DIR/.git" ]; then
        log_info "Обновление существующего репозитория..."
        cd "$TARGET_DIR"
        git fetch origin
        git reset --hard origin/main 2>/dev/null || git checkout -f origin/main
        git clean -fd
    else
        log_info "Клонирование репозитория..."
        # Удаляем, если есть пустая папка
        [ -d "$TARGET_DIR" ] && rmdir "$TARGET_DIR" 2>/dev/null || true
        git clone --depth 1 "$REPO_URL" "$TARGET_DIR"
        cd "$TARGET_DIR"
    fi
    
    # Проверка наличия install.sh
    if [ ! -f "install.sh" ]; then
        log_error "install.sh не найден в $TARGET_DIR"
        echo "Проверьте структуру репозитория или связь с веткой main"
        exit 1
    fi
    
    log_info "Запуск установки..."
    sudo chmod +x install.sh
    sudo chmod +x update.sh
    exec ./install.sh
}

main "$@"